//----------------------------------------------------------------
//  CatchupEngine.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Answered the catch-up of a Classic party's member as one look in the Classic settings, with the closures of their own keys and the party chests that gave their key items
//                            - Left out of what the scripts read the companion each side brings, which the side's rule answers
//                            - Read the story's ids from StoryIds
//      Paulinchen  2026-11-01: Left out a join of a companion of the Alice and Ilias choice the player has no right to, and noted the side the player answered they take along
//      Paulinchen  2026-10-31: Left the warp ban out of what a snapshot reads
//                            - Left the chest flags out of what a snapshot reads
//      Paulinchen  2026-10-28: Read the switch of a world chest the game shuts by a switch
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Catchup;

/// <summary>
/// The one catch-up of both world types: what the story owes a player by its place, over the
/// relay's catch-up tables and the snapshot the scripts hand of the player's story, party and items,
/// answered as actions the scripts carry out with the game's own grants. A Raid World's catch-up
/// owns the save's notes (the ledger), which the scripts hand it after a load and keep in the save
/// whenever an answer brings them; a Classic party's member catches up in the engine's Classic
/// settings (<see cref="CatchupSettings.Classic"/>).
/// </summary>
public sealed class CatchupEngine
{
    /// <summary>
    /// The switches the engine reads besides the rows' marks: the sides and the routes' clear
    /// switches.
    /// </summary>
    private static readonly int[] EngineSwitches = [.. StoryIds.SideSwitches, .. StoryIds.ClearSwitches];

    /// <summary>
    /// The variables the engine reads besides the rows' marks: the main story, the playthrough and the
    /// routes.
    /// </summary>
    private static readonly int[] EngineVariables = [StoryIds.MainProgress, StoryIds.Playthrough, .. StoryIds.RouteVariables];

    /// <summary>
    /// Gets or sets the save's notes, as the scripts handed them or the engine wrote them; nil before
    /// the first.
    /// </summary>
    public RubyValue Ledger { get; set; } = RubyNil.Value;

    /// <summary>
    /// Lists what the scripts hand the engine of the game: every switch, variable and self switch a
    /// row or rule reads, the items whose counts it reads, the Makina, the parts and the orbs' event.
    /// </summary>
    /// <param name="tables">The tables.</param>
    /// <returns>{"switches", "variables", "selves" ([map, event, letter] each), "items" (each "i", "w" or "a" and the id), "makina", "parts" ([id, name, gate] each), "orb_event"}.</returns>
    public static RubyHash Keys(CatchupTables tables)
    {
        ArgumentNullException.ThrowIfNull(tables);
        var switches = new SortedSet<int>(EngineSwitches);
        var variables = new SortedSet<int>(EngineVariables);
        var selves = new HashSet<StoryKey>();
        IEnumerable<StoryPlace> places = tables.Joins.Select(row => row.Place).Concat(tables.Removals.Select(row => row.Place)).Concat(tables.KeyItems.Select(row => row.Place))
            .Concat(tables.Rewards.Select(row => row.Place)).Concat(tables.Lessons.Select(row => row.Place)).Concat(tables.ClassLevels.Select(row => row.Place))
            .Concat(tables.ActorChanges.Select(row => row.Place)).Concat(tables.Settings.Select(row => row.Place)).Concat(tables.Vehicles.Select(row => row.Place));
        foreach (StoryMark mark in places.SelectMany(place => place.Marks))
        {
            switch (mark.Key.Kind)
            {
                case StoryKeyKind.Switch:
                    switches.Add(mark.Key.Id);
                    break;
                case StoryKeyKind.Variable:
                    variables.Add(mark.Key.Id);
                    break;
                default:
                    selves.Add(mark.Key);
                    break;
            }
        }

        foreach (CatchupSetting setting in tables.Settings.Where(row => row.Kind != "encounters"))
        {
            variables.Add(setting.Id);
        }

        foreach (CatchupChest chest in tables.Chests)
        {
            if (chest.Key.Kind == StoryKeyKind.Switch)
            {
                switches.Add(chest.Key.Id);
            }
            else
            {
                selves.Add(chest.Key);
            }
        }

        foreach (CatchupCount count in tables.Counts)
        {
            variables.Add(count.Variable);
            if (count.SinceVariable is { } since)
            {
                variables.Add(since);
            }

            if (count.DoneSwitch is { } done)
            {
                switches.Add(done);
            }

            switches.UnionWith(count.Weights.Select(weight => weight.Switch));
        }

        variables.UnionWith(tables.CompanionValues.Select(value => value.Variable));
        var items = new SortedSet<string>(StringComparer.Ordinal);
        items.UnionWith(tables.KeyItems.Select(row => "i" + row.Item));
        items.UnionWith(tables.Chests.SelectMany(row => row.Items).Select(id => "i" + id));
        items.UnionWith(tables.Rewards.Where(row => row.Kind != "skill").Select(row => CatchupLook.KindOf(row) + row.Id));
        items.UnionWith(tables.Makina.Select(row => "i" + row.Item));
        items.UnionWith(tables.Rules.Orbs.Select(id => "i" + id));
        CatchupRules rules = tables.Rules;
        return new RubyHash
        {
            { "switches", new RubyArray(switches.Select(id => (RubyValue)id)) },
            { "variables", new RubyArray(variables.Select(id => (RubyValue)id)) },
            { "selves", new RubyArray(selves.OrderBy(key => key.Id).ThenBy(key => key.Event).ThenBy(key => key.Letter, StringComparer.Ordinal).Select(CatchupLook.SelfSwitchOf)) },
            { "items", new RubyArray(items.Select(key => (RubyValue)key)) },
            { "makina", new RubyArray(tables.Makina.Select(row => (RubyValue)row.Item)) },
            { "parts", new RubyArray(tables.Parts.Select(part => (RubyValue)new RubyArray { part.Id, part.Name, part.Gate })) },
            { "orb_event", rules.OrbEvent is { } orbEvent ? orbEvent : RubyNil.Value },
        };
    }

    /// <summary>
    /// Answers one look at the player's story: <c>look</c> "carried" with the story <c>before</c> a
    /// story was laid over theirs, else a look every half second (<c>audit</c>, <c>vehicles</c> and
    /// <c>growth</c> telling what else is due).
    /// </summary>
    /// <param name="tables">The tables.</param>
    /// <param name="request">The snapshot, see <see cref="CatchupLook"/>.</param>
    /// <returns>"actions", "ledger" (nil while unchanged), "visiting", and for a look every half second "ask_side", "growth", "sharable", "orbs", "got" (every item the save has held), "given" (the found items given, whose next gain adds nothing), "take" (the items another player's event used up, a copy each) and "spent" (every use of an item the save counted).</returns>
    public RubyHash Check(CatchupTables tables, RubyHash request) => new CatchupLook(this, tables, request).Check();

    /// <summary>
    /// Answers the one catch-up of a Classic party's member who starts keeping the leader's story from
    /// behind it, the leader's history from before the member followed it: the rows the leader's
    /// story is past and the member's own is not, of the member's own side and choices, the world
    /// chests the leader's story opened, the party chests that gave the key items the member lacks
    /// and the closures of the member's own keys, in the Classic settings, with notes of the
    /// catch-up's own, never the save's. A second look with those notes gives only what the first did
    /// not, such as the rows of a side or a choice the member answered since.
    /// </summary>
    /// <param name="tables">The tables.</param>
    /// <param name="request">"before" (the member's own story) and "leader" (the leader's), as the snapshot holds a story; "pick" (the save's note of the side the member took along: "alice", "ilias", "" for none of their own, nil while unknown), "roster", "items" (the counts the bag holds), "lent" ({id => count} of the key items the leader lent), "selves" ({"leader", "own"}, every self switch on in each story, [map, event, letter] each) and "ledger" (the notes the catch-up's last answer brought, nil for a first).</param>
    /// <param name="party">What the catch-up reads of the party beyond its tables.</param>
    /// <returns>"actions" (as <see cref="Check"/> answers them; a "replay" of a closure names the leader's "letters" of its event) and "ledger".</returns>
    public static RubyHash Classic(CatchupTables tables, RubyHash request, ClassicParty party) =>
        new CatchupLook(new CatchupEngine(), tables, request, CatchupSettings.Classic, party).Classic();

    /// <summary>
    /// Writes a note of the world's story into the save's notes: the checkpoint the player took
    /// (<c>checkpoint</c>, nil once the world's story was laid over theirs), the gate a move on at a
    /// cap of another mod opened (<c>capped</c>) or the side the player answered they take along
    /// (<c>side</c>).
    /// </summary>
    /// <param name="tables">The tables.</param>
    /// <param name="request">The note and the snapshot.</param>
    /// <returns>"actions" and "ledger".</returns>
    public RubyHash Note(CatchupTables tables, RubyHash request) => new CatchupLook(this, tables, request).Note();

    /// <summary>
    /// Answers whether a companion the player's game hands out is left out, as one of the Alice and
    /// Ilias choice the player has no right to (<see cref="CompanionScope.AllowsAt"/>), or waits for
    /// the gate of a join of theirs in the player's part, the latter only for the player's own story
    /// event and a replay that went the player's own way.
    /// </summary>
    /// <param name="tables">The tables.</param>
    /// <param name="request">"actor" (the companion's main persona), "site" (the page or common event that runs as <see cref="StoryPlain"/> names a site, nil for none), "scope_only" (true for a join no own story event of the player hands out, such as a replay's), "replay" (true for a replay's join), "own_way" (true for a replay the player answered their own way), "sharing", "start" and the snapshot.</param>
    /// <returns>"gate" (nil when the game's own join goes ahead), "refused" (true when it is left out), "actions" and "ledger".</returns>
    public RubyHash HoldJoin(CatchupTables tables, RubyHash request) => new CatchupLook(this, tables, request).HoldJoin();

    /// <summary>
    /// Lists what the catch-up hands out by level that the world unlocked, for the World overview.
    /// </summary>
    /// <param name="tables">The tables.</param>
    /// <param name="request">The snapshot.</param>
    /// <returns>"unlocks", each [level, kind ("story", "companion" or "makina"), id, name, got, due, gains ([kind, id, amount] each)].</returns>
    public RubyHash Unlocks(CatchupTables tables, RubyHash request) => new CatchupLook(this, tables, request).Unlocks();
}
