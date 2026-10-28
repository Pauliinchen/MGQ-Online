//----------------------------------------------------------------
//  PartyRewards.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Catchup;

/// <summary>
/// The rewards of the game's events a party member of a Classic world catches up with
/// (coop_story.rbx), written from the catch-up's tables as the scripts read them, in the shapes the
/// constants of coop_story_rewards.rbx had.
/// </summary>
public static class PartyRewards
{
    /// <summary>
    /// The item kinds by the letter the scripts name an item with.
    /// </summary>
    private static readonly Dictionary<string, string> ItemLetters = new(StringComparer.Ordinal) { ["item"] = "i", ["weapon"] = "w", ["armor"] = "a" };

    /// <summary>
    /// Writes the rewards.
    /// </summary>
    /// <param name="tables">The tables.</param>
    /// <returns>{"skills", "actors", "items" (the most of each by "i", "w" or "a" and the id), "sided" and "route" ({"skills", "actors"}), "final" ({"skills", "actors", "items"}), "groups" ([{"site", "alice", "ilias" (each {"skills", "actors"}), "choice", "marks" (one list of marks per page, each ["s", switch], ["v", variable, at least] or ["ss", map, event, letter])}, ...]), "chests" ([map, event, letter] each), "chest_flags"}.</returns>
    public static RubyHash Write(CatchupTables tables)
    {
        ArgumentNullException.ThrowIfNull(tables);
        IReadOnlyList<EventReward> rewards = tables.EventRewards;
        var items = new RubyHash();
        foreach (EventReward reward in rewards.Where(reward => ItemLetters.ContainsKey(reward.Kind)))
        {
            items[ItemKey(reward)] = reward.Most ?? 0;
        }

        return new RubyHash
        {
            { "skills", Ids(rewards, "skill", _ => true) },
            { "actors", Ids(rewards, "companion", _ => true) },
            { "items", items },
            { "sided", new RubyHash { { "skills", Ids(rewards, "skill", reward => reward.Sided) }, { "actors", Ids(rewards, "companion", reward => reward.Sided) } } },
            { "route", new RubyHash { { "skills", Ids(rewards, "skill", reward => reward.Route) }, { "actors", Ids(rewards, "companion", reward => reward.Route) } } },
            {
                "final", new RubyHash
                {
                    { "skills", Ids(rewards, "skill", reward => reward.Final) },
                    { "actors", Ids(rewards, "companion", reward => reward.Final) },
                    { "items", new RubyArray(rewards.Where(reward => reward.Final && ItemLetters.ContainsKey(reward.Kind)).Select(reward => (RubyValue)ItemKey(reward))) },
                }
            },
            { "groups", new RubyArray(tables.SideEvents.Select(GroupOf)) },
            { "chests", new RubyArray(tables.PartyChests.Select(CatchupLook.SelfSwitchOf)) },
            { "chest_flags", new RubyArray(tables.ChestFlags.Select(id => (RubyValue)id)) },
        };
    }

    /// <summary>
    /// Names an item reward as the scripts do.
    /// </summary>
    /// <param name="reward">The reward.</param>
    /// <returns>Such as "i501".</returns>
    private static string ItemKey(EventReward reward) => ItemLetters[reward.Kind] + reward.Id.ToString(CultureInfo.InvariantCulture);

    /// <summary>
    /// Lists the ids of the rewards of a kind that pass a test.
    /// </summary>
    /// <param name="rewards">The rewards.</param>
    /// <param name="kind">"skill" or "companion".</param>
    /// <param name="test">The test.</param>
    /// <returns>The ids, in the table's order.</returns>
    private static RubyArray Ids(IReadOnlyList<EventReward> rewards, string kind, Func<EventReward, bool> test) =>
        new(rewards.Where(reward => reward.Kind == kind && test(reward)).Select(reward => (RubyValue)reward.Id));

    /// <summary>
    /// Writes a side event as the scripts read it.
    /// </summary>
    /// <param name="side">The side event.</param>
    /// <returns>Its hash.</returns>
    private static RubyValue GroupOf(SideEvent side) => new RubyHash
    {
        { "site", side.Site },
        { "alice", SideOf(side.Alice) },
        { "ilias", SideOf(side.Ilias) },
        { "choice", side.Choice },
        { "marks", new RubyArray(side.Marks.Select(page => (RubyValue)new RubyArray(page.Select(MarkOf)))) },
    };

    /// <summary>
    /// Writes what one side of a side event gives.
    /// </summary>
    /// <param name="side">The side's rewards.</param>
    /// <returns>{"skills", "actors"}.</returns>
    private static RubyHash SideOf(SideRewards side) => new()
    {
        { "skills", new RubyArray(side.Skills.Select(id => (RubyValue)id)) },
        { "actors", new RubyArray(side.Companions.Select(id => (RubyValue)id)) },
    };

    /// <summary>
    /// Writes a mark as the scripts read it.
    /// </summary>
    /// <param name="mark">The mark.</param>
    /// <returns>["s", switch], ["v", variable, at least] or ["ss", map, event, letter].</returns>
    private static RubyValue MarkOf(StoryMark mark) => mark.Key.Kind switch
    {
        StoryKeyKind.Switch => new RubyArray { "s", mark.Key.Id },
        StoryKeyKind.Variable => new RubyArray { "v", mark.Key.Id, mark.AtLeast },
        _ => new RubyArray { "ss", mark.Key.Id, mark.Key.Event, mark.Key.Letter },
    };
}
