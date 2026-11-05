//----------------------------------------------------------------
//  ClassicCatchup.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Story;
using MGQOnline.Game.Story.Choices;

namespace MGQOnline.Game.Catchup;

/// <summary>
/// The catch-up of a Classic party's member who starts keeping the leader's story from behind it:
/// the leader's history from before the log, by the frozen catch-up rows as a Raid World's history,
/// and the world chests the leader's story opened, played in the member's own game. Nothing is
/// copied from what the leader holds (user decision 2026-11-04).
/// </summary>
/// <remarks>
/// A row counts once the leader's story is past it and the member's own story is not, read with the
/// side the member took along, so a row of a side waits until they chose theirs; a world chest
/// counts once the leader's story opened it, and the member's is neither open nor past its step.
/// The Medal King's prizes come by <see cref="MedalKingGift"/> alone, so none comes twice.
/// </remarks>
public static class ClassicCatchup
{
    /// <summary>
    /// Answers the topic of the catch-up: {"own" and "leader" (stories as the Raid catch-up's
    /// snapshot holds them: "s", "v", "ss"), "side" ("alice", "ilias" or nil), "roster" ([main
    /// persona, ...]), "items" (counts by "i", "w" or "a" and the id), "routes" (the routes the
    /// member played), "sided" (true for the rows of a side alone, once the member chose it)} in;
    /// {"skills" ([id, ...]), "items" ([[kind, id, amount], ...]), "key_items" ([[id, amount], ...],
    /// the key items the member lacks), "joins" ([persona, ...]), "lessons" ([[actor, skill], ...]),
    /// "classes" ([[actor, class, level], ...]), "chests" ([key, ...] the leader's story opened)} out.
    /// </summary>
    /// <param name="tables">The catch-up's tables.</param>
    /// <param name="request">The request.</param>
    /// <returns>The answer.</returns>
    public static RubyHash Answer(CatchupTables tables, RubyHash request)
    {
        ArgumentNullException.ThrowIfNull(tables);
        ArgumentNullException.ThrowIfNull(request);
        StoryValues own = CatchupLook.StoryOf(request["own"]) ?? new StoryValues([], [], []);
        StoryValues leader = CatchupLook.StoryOf(request["leader"]) ?? new StoryValues([], [], []);
        string? side = request["side"] is RubyString { Text: "alice" or "ilias" } pick ? pick.Text : null;
        bool sidedOnly = request["sided"] is RubyBool { Flag: true };
        var roster = new HashSet<int>(request["roster"].IsNil ? [] : request["roster"].AsArray().Select(id => id.AsInt()));
        var items = new Dictionary<string, long>(StringComparer.Ordinal);
        if (request["items"] is RubyHash counts)
        {
            foreach ((RubyValue key, RubyValue count) in counts)
            {
                items[key.AsText()] = count.AsLong();
            }
        }

        HashSet<string> routes = request["routes"] is RubyArray played ? [.. played.Select(route => route.AsText())] : [];
        PersonalChoiceKeys choices = StoryChoices.Personal(false, null);
        bool ChoiceKey(StoryKey key) => key.Kind == StoryKeyKind.Switch ? choices.Switches.Contains(key.Id) : choices.Variables.Contains(key.Id);
        bool Due(StoryPlace place, bool ran) =>
            ran && (!sidedOnly || place.Side is not null) && StoryRows.Passed(place, leader, own, side, ChoiceKey) && !StoryRows.Passed(place, own, own, side, ChoiceKey);

        var answer = new RubyHash
        {
            { "skills", new RubyArray(tables.Rewards.Where(row => row.Kind == "skill" && Due(row.Place, row.Ran)).Select(row => row.Id).Distinct().Select(id => (RubyValue)id)) },
            { "items", new RubyArray(tables.Rewards.Where(row => row.Kind != "skill" && !MedalKingGift.IsGift(row, tables) && Due(row.Place, row.Ran)).Select(row => (RubyValue)new RubyArray { CatchupLook.KindOf(row), row.Id, row.Amount })) },
            { "key_items", KeyItems(tables, leader, own, side, sidedOnly, ChoiceKey, items) },
        };

        var joins = new List<int>();
        foreach (CatchupJoin row in tables.Index.StoryJoins)
        {
            if (Due(row.Place, row.Ran) && !roster.Contains(row.Actor) && !joins.Contains(row.Persona) && !ChoiceTable.ChoiceCompanions.Contains(row.Actor)
                && tables.Scope.Allows(row.Actor, CompanionPath.Own, CompanionScope.NoSharing, side, routes)
                && !tables.Removals.Any(removal => removal.Actor == row.Actor && StoryRows.After(removal.Place, removal.Index, row.Place, row.Index) && StoryRows.Passed(removal.Place, leader, own, side, ChoiceKey)))
            {
                joins.Add(row.Persona);
                roster.Add(row.Actor);
            }
        }

        answer["joins"] = new RubyArray(joins.Select(persona => (RubyValue)persona));
        answer["lessons"] = new RubyArray(tables.Lessons.Where(row => Due(row.Place, row.Ran) && roster.Contains(row.Actor))
            .Select(row => (RubyValue)new RubyArray { row.Actor, row.Skill }));
        answer["classes"] = new RubyArray(tables.ClassLevels.Where(row => Due(row.Place, row.Ran) && (row.Actor == CatchupLook.Hero || roster.Contains(row.Actor)))
            .Select(row => (RubyValue)new RubyArray { row.Actor, row.Class, row.Level }));
        answer["chests"] = new RubyArray(sidedOnly ? [] : tables.Chests.Where(row => leader.Holds(new StoryMark(row.Key)) && !own.Holds(new StoryMark(row.Key))
                && !(StepMark(row.Part, row.Step) is { } step && StoryRows.Passed(new StoryPlace(row.Key.ToString(), row.Part, row.Step, null, [step]), own, own, side, ChoiceKey)))
            .Select(row => (RubyValue)row.Key.ToString()));
        return answer;
    }

    /// <summary>
    /// Makes the mark of a step of a part: the main story's progress, or a route's.
    /// </summary>
    /// <param name="part">The part.</param>
    /// <param name="step">The step, <see langword="null"/> for none known.</param>
    /// <returns>The mark, <see langword="null"/> without a step.</returns>
    private static StoryMark? StepMark(string? part, long? step)
    {
        if (step is not { } at)
        {
            return null;
        }

        int route = part is null ? -1 : StoryParts.Routes.ToList().IndexOf(part);
        return new StoryMark(StoryKey.Variable(route < 0 ? StoryValues.MainProgress : StoryValues.RouteVariables[route]), at);
    }

    /// <summary>
    /// Finds the key items the leader's story owes and the member holds fewer of: of each key item a
    /// row the leader's story is past gives, and no later row took back, the most such a row gives,
    /// less what the member holds; once the member chose a side, of the rows of a side alone.
    /// </summary>
    /// <param name="tables">The tables.</param>
    /// <param name="leader">The leader's story.</param>
    /// <param name="own">The member's own story.</param>
    /// <param name="side">The side the member took along.</param>
    /// <param name="sidedOnly">Whether only the rows of a side count.</param>
    /// <param name="choiceKey">Tells whether a key is a choice's outcome.</param>
    /// <param name="items">The member's counts.</param>
    /// <returns>[[id, amount], ...].</returns>
    private static RubyArray KeyItems(CatchupTables tables, StoryValues leader, StoryValues own, string? side, bool sidedOnly, Func<StoryKey, bool> choiceKey, Dictionary<string, long> items)
    {
        var owed = new SortedDictionary<int, int>();
        foreach (CatchupKeyItem row in tables.KeyItems.Where(row => row.Amount > 0 && (!sidedOnly || row.Place.Side is not null) && StoryRows.Passed(row.Place, leader, own, side, choiceKey)
            && !StoryRows.TakenSince(tables, row, leader, own, side, choiceKey)))
        {
            owed[row.Item] = Math.Max(owed.GetValueOrDefault(row.Item), row.Amount);
        }

        return new RubyArray(owed.Select(pair => (Item: pair.Key, Missing: pair.Value - items.GetValueOrDefault("i" + pair.Key)))
            .Where(pair => pair.Missing > 0).Select(pair => (RubyValue)new RubyArray { pair.Item, pair.Missing }));
    }
}
