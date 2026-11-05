//----------------------------------------------------------------
//  MedalKingGift.cs
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

namespace MGQOnline.Game.Catchup;

/// <summary>
/// The Medal King's free gift, a named exception of the story replay ("Issue 73 chest effects.md",
/// E3): once any player of a world buys one of his one-of-a-kind items, every player whose story
/// holds its switch and who holds none of it gets it free. His run is never replayed, so the gift
/// is its one path, in a Raid World by the catch-up's look and in a Classic world by
/// <see cref="Answer"/>.
/// </summary>
public static class MedalKingGift
{
    /// <summary>
    /// The common event of the Medal King's exchanges.
    /// </summary>
    public const int CommonEvent = 140;

    /// <summary>
    /// Reports whether a run is the Medal King's: its page calls his common event.
    /// </summary>
    /// <param name="site">Where the run started.</param>
    /// <param name="match">The events database's pages.</param>
    /// <returns>Whether it is.</returns>
    public static bool IsRun(ReplaySite site, PageMatch match)
    {
        ArgumentNullException.ThrowIfNull(match);
        return match.Calls(site, CommonEvent);
    }

    /// <summary>
    /// Answers the topic of a Classic world's gift: {} in; {"switches" ([id, ...] the exchanges'
    /// switches), "items" (["w112", ...] their prizes)} out. Or {"story" (the player's story as the
    /// catch-up's snapshot holds it), "items" (how many of each prize the game has the player holds,
    /// in the bag, the storage or worn, by "i", "w" or "a" and the id), "handled" ([id, ...] the
    /// switches looked at before)} in; {"gifts" ([[kind, id, amount], ...]), "handled" ([id, ...])} out.
    /// </summary>
    /// <remarks>
    /// A switch counts as handled once the story holds it, gift or not, so a prize the player sold
    /// or used later is not given again.
    /// </remarks>
    /// <param name="tables">The catch-up's tables.</param>
    /// <param name="request">The request.</param>
    /// <returns>The answer.</returns>
    public static RubyHash Answer(CatchupTables tables, RubyHash request)
    {
        ArgumentNullException.ThrowIfNull(tables);
        ArgumentNullException.ThrowIfNull(request);
        CatchupReward[] rows = [.. tables.Rewards.Where(row => SwitchOf(row, tables) is not null)];
        if (CatchupLook.StoryOf(request["story"]) is not { } story)
        {
            return new RubyHash
            {
                { "switches", new RubyArray(tables.PrizeSwitches.Select(id => (RubyValue)id)) },
                { "items", new RubyArray(rows.Select(row => (RubyValue)(CatchupLook.KindOf(row) + row.Id)).Distinct()) },
            };
        }

        var items = new Dictionary<string, long>(StringComparer.Ordinal);
        if (request["items"] is RubyHash counts)
        {
            foreach ((RubyValue key, RubyValue count) in counts)
            {
                items[key.AsText()] = count.AsLong();
            }
        }

        var handled = new SortedSet<int>(request["handled"] is RubyArray before ? before.Select(id => id.AsInt()) : []);
        var gifts = new RubyArray();
        foreach (CatchupReward row in rows)
        {
            int prize = SwitchOf(row, tables)!.Value;
            if (handled.Contains(prize) || !StoryRows.Passed(row.Place, story, story, null, _ => false))
            {
                continue;
            }

            handled.Add(prize);
            if (Owed(row, tables, items.ContainsKey, item => items.GetValueOrDefault(item) > 0))
            {
                gifts.Add(new RubyArray { CatchupLook.KindOf(row), row.Id, row.Amount });
            }
        }

        return new RubyHash { { "gifts", gifts }, { "handled", new RubyArray(handled.Select(id => (RubyValue)id)) } };
    }

    /// <summary>
    /// Reports whether a reward row is a gift of the Medal King: a switch of his exchanges among its
    /// marks.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <param name="tables">The tables, which name the exchanges' switches.</param>
    /// <returns>Whether it is.</returns>
    public static bool IsGift(CatchupReward row, CatchupTables tables)
    {
        ArgumentNullException.ThrowIfNull(row);
        ArgumentNullException.ThrowIfNull(tables);
        return SwitchOf(row, tables) is not null;
    }

    /// <summary>
    /// Finds the exchange's switch among a reward row's marks.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <param name="tables">The tables, which name the exchanges' switches.</param>
    /// <returns>The switch, <see langword="null"/> for a row of no exchange or a skill.</returns>
    private static int? SwitchOf(CatchupReward row, CatchupTables tables) =>
        row.Kind == "skill" ? null : row.Place.Marks.Where(mark => mark.Key.Kind == StoryKeyKind.Switch && tables.PrizeSwitches.Contains(mark.Key.Id)).Select(mark => (int?)mark.Key.Id).FirstOrDefault();

    /// <summary>
    /// Reports whether a reward row the player's story passed is a gift they are owed: a switch of
    /// the exchanges among its marks, an item the game has, and none of it held.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <param name="tables">The tables, which name the exchanges' switches.</param>
    /// <param name="has">Tells whether the game has an item, such as "w4112".</param>
    /// <param name="held">Tells whether the party holds an item, in the bag or worn.</param>
    /// <returns>Whether they are.</returns>
    public static bool Owed(CatchupReward row, CatchupTables tables, Func<string, bool> has, Func<string, bool> held)
    {
        ArgumentNullException.ThrowIfNull(row);
        ArgumentNullException.ThrowIfNull(tables);
        ArgumentNullException.ThrowIfNull(has);
        ArgumentNullException.ThrowIfNull(held);
        if (SwitchOf(row, tables) is null)
        {
            return false;
        }

        string item = CatchupLook.KindOf(row) + row.Id;
        return has(item) && !held(item);
    }
}
