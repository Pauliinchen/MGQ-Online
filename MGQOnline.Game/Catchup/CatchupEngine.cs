//----------------------------------------------------------------
//  CatchupEngine.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Left the chest flags out of what a snapshot reads
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
/// A Raid World's catch-up as world_catchup.rbx decided it: what the story owes a player by its
/// place, over the relay's catch-up tables and the snapshot the scripts hand of the player's story,
/// party and items, answered as actions the scripts carry out with the game's own grants. It owns
/// the save's notes (the ledger), which the scripts hand it after a load and keep in the save
/// whenever an answer brings them. The golden cases of fixtures/catchup/engine.json were recorded
/// from the script's decisions (fixtures/catchup/engine.rb).
/// </summary>
public sealed class CatchupEngine
{
    /// <summary>
    /// The switches the engine reads besides the rows' marks: the sides, the warp ban and the routes'
    /// clear switches.
    /// </summary>
    private static readonly int[] EngineSwitches = [StoryValues.AliceChosen, StoryValues.IliasChosen, CatchupLook.WarpBan, .. StoryValues.ClearSwitches];

    /// <summary>
    /// The variables the engine reads besides the rows' marks: the main story, the playthrough and the
    /// routes.
    /// </summary>
    private static readonly int[] EngineVariables = [StoryValues.MainProgress, CatchupLook.Playthrough, .. StoryValues.RouteVariables];

    /// <summary>
    /// Gets or sets the save's notes, as the scripts handed them or the engine wrote them; nil before
    /// the first.
    /// </summary>
    public RubyValue Ledger { get; set; } = RubyNil.Value;

    /// <summary>
    /// Lists what the scripts hand the engine of the game: every switch, variable and self switch a
    /// row or rule reads, the items whose counts it reads, the Makina, the parts, the companion each
    /// side brings along and the orbs' event.
    /// </summary>
    /// <param name="tables">The tables.</param>
    /// <returns>{"switches", "variables", "selves" ([map, event, letter] each), "items" (each "i", "w" or "a" and the id), "makina", "parts" ([id, name, gate] each), "side_companions" ({"alice", "ilias"} or nil), "orb_event"}.</returns>
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
            { "side_companions", rules is { AliceCompanion: { } alice, IliasCompanion: { } ilias } ? new RubyHash { { "alice", alice }, { "ilias", ilias } } : RubyNil.Value },
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
    /// <returns>"actions", "ledger" (nil while unchanged), "visiting", and for a look every half second "ask_side", "growth", "sharable" and "orbs".</returns>
    public RubyHash Check(CatchupTables tables, RubyHash request) => new CatchupLook(this, tables, request).Check();

    /// <summary>
    /// Writes a note of the world's story into the save's notes: the checkpoint the player took
    /// (<c>checkpoint</c>, nil once the world's story was laid over theirs) or the gate a move on at a
    /// cap of another mod opened (<c>capped</c>).
    /// </summary>
    /// <param name="tables">The tables.</param>
    /// <param name="request">The note and the snapshot.</param>
    /// <returns>"actions" and "ledger".</returns>
    public RubyHash Note(CatchupTables tables, RubyHash request) => new CatchupLook(this, tables, request).Note();

    /// <summary>
    /// Answers whether a companion the player's own story event hands out waits for the gate of a
    /// join of theirs in the player's part.
    /// </summary>
    /// <param name="tables">The tables.</param>
    /// <param name="request">"actor" (the companion's main persona), "site" (the page that runs, nil for none) and the snapshot.</param>
    /// <returns>"gate" (nil when the game's own join goes ahead), "actions" and "ledger".</returns>
    public RubyHash HoldJoin(CatchupTables tables, RubyHash request) => new CatchupLook(this, tables, request).HoldJoin();

    /// <summary>
    /// Lists what the catch-up hands out by level that the world unlocked, for the World overview.
    /// </summary>
    /// <param name="tables">The tables.</param>
    /// <param name="request">The snapshot.</param>
    /// <returns>"unlocks", each [level, kind ("story", "companion" or "makina"), id, name, got, due, gains ([kind, id, amount] each)].</returns>
    public RubyHash Unlocks(CatchupTables tables, RubyHash request) => new CatchupLook(this, tables, request).Unlocks();
}
