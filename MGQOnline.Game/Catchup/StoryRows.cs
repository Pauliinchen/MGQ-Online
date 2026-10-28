//----------------------------------------------------------------
//  StoryRows.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Catchup;

/// <summary>
/// How the rows of the catch-up's tables stand against a story, as world_catchup.rbx decides it:
/// which rows a story is past, which key items a later row took back, which joins a removal takes
/// back again, which companions are on a visit, and where a player moves on to. The golden cases
/// of fixtures/catchup/rows.json were recorded from the script.
/// </summary>
public static class StoryRows
{
    /// <summary>
    /// Where a player moves on to once no part with a checkpoint is left: the world's own story.
    /// </summary>
    public const string WorldTrack = "world";

    /// <summary>
    /// The parts before the Great Decision, whose sides the player chose themselves.
    /// </summary>
    private static readonly string[] SidedParts = ["1", "2", "3"];

    /// <summary>
    /// Where each part stands in the story's order; the routes stand side by side.
    /// </summary>
    private static readonly Dictionary<string, int> Ranks = new(StringComparer.Ordinal)
    {
        ["1"] = 0, ["2"] = 1, ["3"] = 2, ["ad"] = 3, ["mr"] = 3, ["chaos"] = 3,
    };

    /// <summary>
    /// Reads where a part stands in the story's order.
    /// </summary>
    /// <param name="part">The part, <see langword="null"/> for side content.</param>
    /// <returns>Its rank, 0 for side content.</returns>
    public static int Rank(string? part) => part is not null && Ranks.TryGetValue(part, out int rank) ? rank : 0;

    /// <summary>
    /// Reports whether a story is past a row: the row's part is the story's or an earlier one and its
    /// marks hold, so an optional event nobody played is never past; a route's rows also once the
    /// route is finished, whose return clears its marks. Side content counts by its marks alone. The
    /// row's side and the choices' outcomes among its marks are the player's own, always read from
    /// their story.
    /// </summary>
    /// <param name="place">The row's place.</param>
    /// <param name="story">The story: the player's own, or the world's.</param>
    /// <param name="own">The player's own story, the same unless the story is the world's.</param>
    /// <param name="notedSide">The side the save notes the player chose before the Great Decision, <see langword="null"/> for none.</param>
    /// <param name="choiceKey">Tells whether a key is a choice's outcome, which only the player's own story holds.</param>
    /// <returns>Whether it is.</returns>
    public static bool Passed(StoryPlace place, StoryValues story, StoryValues own, string? notedSide, Func<StoryKey, bool> choiceKey)
    {
        ArgumentNullException.ThrowIfNull(place);
        ArgumentNullException.ThrowIfNull(story);
        ArgumentNullException.ThrowIfNull(own);
        ArgumentNullException.ThrowIfNull(choiceKey);
        bool finished = false;
        if (place.Part is { } part)
        {
            int rank = Rank(part);
            finished = rank == Rank("ad") && story.Cleared(part);
            if (!finished && rank >= Rank(story.Part) && story.Part != part)
            {
                return false;
            }
        }

        if (place.Side is not null && place.Side != SideFor(place, own, notedSide))
        {
            return false;
        }

        if (place.Marks.Any(mark => IsChoice(mark, choiceKey) && !own.Holds(mark)))
        {
            return false;
        }

        if (finished)
        {
            return true;
        }

        return place.Marks.Count > 0 && place.Marks.All(mark => (IsChoice(mark, choiceKey) ? own : story).Holds(mark));
    }

    /// <summary>
    /// Reports whether the player's story or the world's is past a row, see <see cref="Passed"/>.
    /// </summary>
    /// <param name="place">The row's place.</param>
    /// <param name="own">The player's story.</param>
    /// <param name="told">The world's story, <see langword="null"/> when it does not count.</param>
    /// <param name="notedSide">The side the save notes, <see langword="null"/> for none.</param>
    /// <param name="choiceKey">Tells whether a key is a choice's outcome.</param>
    /// <returns>Whether one is.</returns>
    public static bool PassedAny(StoryPlace place, StoryValues own, StoryValues? told, string? notedSide, Func<StoryKey, bool> choiceKey) =>
        Passed(place, own, own, notedSide, choiceKey) || (told is not null && Passed(place, told, own, notedSide, choiceKey));

    /// <summary>
    /// Finds the side a row asks for in the player's story: before the Great Decision the side they
    /// chose then, which the save notes, since the route sets it anew.
    /// </summary>
    /// <param name="place">The row's place.</param>
    /// <param name="own">The player's story.</param>
    /// <param name="notedSide">The side the save notes, <see langword="null"/> for none.</param>
    /// <returns><c>alice</c>, <c>ilias</c> or <see langword="null"/>.</returns>
    public static string? SideFor(StoryPlace place, StoryValues own, string? notedSide)
    {
        ArgumentNullException.ThrowIfNull(place);
        ArgumentNullException.ThrowIfNull(own);
        return place.Part is { } part && Array.IndexOf(SidedParts, part) >= 0 && notedSide is not null ? notedSide : own.Side;
    }

    /// <summary>
    /// Orders a row by its place in the story: part, then step.
    /// </summary>
    /// <param name="place">The row's place.</param>
    /// <returns>Its rank and step, compared left to right; a step not told counts as 0.</returns>
    public static (int Rank, long Step) PlaceOf(StoryPlace place)
    {
        ArgumentNullException.ThrowIfNull(place);
        return (Rank(place.Part), place.Step ?? 0);
    }

    /// <summary>
    /// Reports whether a row comes after another in the story: at a later place, or later in the
    /// same event's list.
    /// </summary>
    /// <param name="place">The one's place.</param>
    /// <param name="index">The one's command place in its list (see <see cref="CatchupJoin.Index"/>).</param>
    /// <param name="other">The other's place.</param>
    /// <param name="otherIndex">The other's command place.</param>
    /// <returns>Whether it does.</returns>
    public static bool After(StoryPlace place, int index, StoryPlace other, int otherIndex)
    {
        int order = PlaceOf(place).CompareTo(PlaceOf(other));
        return order != 0 ? order > 0 : place.Site == other.Site && index > otherIndex;
    }

    /// <summary>
    /// Reports whether two rows hold the same marks, in any order.
    /// </summary>
    /// <param name="place">The one's place.</param>
    /// <param name="other">The other's place.</param>
    /// <returns>Whether they do.</returns>
    public static bool SameMarks(StoryPlace place, StoryPlace other)
    {
        ArgumentNullException.ThrowIfNull(place);
        ArgumentNullException.ThrowIfNull(other);
        return place.Marks.Count == other.Marks.Count && place.Marks.Order(MarkOrder.Instance).SequenceEqual(other.Marks.Order(MarkOrder.Instance));
    }

    /// <summary>
    /// Reports whether a row's marks lie further than another's of the same step: each of the other's
    /// marks is the row's too, a variable's at least as high, and they differ.
    /// </summary>
    /// <param name="place">The one's place.</param>
    /// <param name="other">The other's place.</param>
    /// <returns>Whether they do.</returns>
    public static bool MarksBeyond(StoryPlace place, StoryPlace other)
    {
        if (SameMarks(place, other))
        {
            return false;
        }

        return other.Marks.All(mark => place.Marks.Any(own => own == mark || (own.Key.Kind == StoryKeyKind.Variable && mark.Key.Kind == StoryKeyKind.Variable && own.Key.Id == mark.Key.Id && own.AtLeast >= mark.AtLeast)));
    }

    /// <summary>
    /// Reports whether a removal takes a join's companion away again in the same step of the story:
    /// later in the same event, or in an event whose marks lie further, on the same side.
    /// </summary>
    /// <param name="removal">The removal.</param>
    /// <param name="join">The join.</param>
    /// <returns>Whether it does.</returns>
    public static bool TakesBack(CatchupRemoval removal, CatchupJoin join)
    {
        ArgumentNullException.ThrowIfNull(removal);
        ArgumentNullException.ThrowIfNull(join);
        if (removal.Actor != join.Actor || removal.Place.Part != join.Place.Part || removal.Place.Step != join.Place.Step)
        {
            return false;
        }

        if (removal.Place.Side is not null && join.Place.Side is not null && removal.Place.Side != join.Place.Side)
        {
            return false;
        }

        return removal.Place.Site == join.Place.Site ? removal.Index > join.Index : MarksBeyond(removal.Place, join.Place);
    }

    /// <summary>
    /// Lists the removals that take a join's companion away again, see <see cref="TakesBack"/>; none
    /// for a lasting companion, however the story takes them away again.
    /// </summary>
    /// <param name="tables">The tables, with the rules' lasting companions.</param>
    /// <param name="join">The join.</param>
    /// <returns>The removals.</returns>
    public static IReadOnlyList<CatchupRemoval> TakingBack(CatchupTables tables, CatchupJoin join)
    {
        ArgumentNullException.ThrowIfNull(tables);
        ArgumentNullException.ThrowIfNull(join);
        return tables.Rules.LastingCompanions.Contains(join.Actor) ? [] : [.. tables.Removals.Where(removal => TakesBack(removal, join))];
    }

    /// <summary>
    /// Reports whether a join only brings its companion along for a visit, see <see cref="TakingBack"/>.
    /// </summary>
    /// <param name="tables">The tables.</param>
    /// <param name="join">The join.</param>
    /// <returns>Whether it does.</returns>
    public static bool Temporary(CatchupTables tables, CatchupJoin join) => TakingBack(tables, join).Count > 0;

    /// <summary>
    /// Reports whether a story took a key item after a row gave it: a row of a later part, a later
    /// row of the same part, one of the same step whose marks lie further, or one of the same event
    /// and marks listed after it, that takes it. The routes share a rank, so a row of another route
    /// never counts as later.
    /// </summary>
    /// <param name="tables">The tables.</param>
    /// <param name="row">The row that gives it.</param>
    /// <param name="story">The story: the player's own, or the world's.</param>
    /// <param name="own">The player's own story.</param>
    /// <param name="notedSide">The side the save notes, <see langword="null"/> for none.</param>
    /// <param name="choiceKey">Tells whether a key is a choice's outcome.</param>
    /// <returns>Whether it did.</returns>
    public static bool TakenSince(CatchupTables tables, CatchupKeyItem row, StoryValues story, StoryValues own, string? notedSide, Func<StoryKey, bool> choiceKey)
    {
        ArgumentNullException.ThrowIfNull(tables);
        ArgumentNullException.ThrowIfNull(row);
        int at = IndexOf(tables.KeyItems, row);
        for (int index = 0; index < tables.KeyItems.Count; index++)
        {
            CatchupKeyItem other = tables.KeyItems[index];
            if (other.Item != row.Item || other.Amount >= 0 || other.Place.Part is null || row.Place.Part is null)
            {
                continue;
            }

            bool later = other.Place.Part != row.Place.Part ? Rank(other.Place.Part) > Rank(row.Place.Part)
                : (other.Place.Step ?? 0) != (row.Place.Step ?? 0) ? (other.Place.Step ?? 0) > (row.Place.Step ?? 0)
                : other.Place.Site == row.Place.Site && SameMarks(other.Place, row.Place) ? index > at
                : MarksBeyond(other.Place, row.Place);
            if (later && Passed(other.Place, story, own, notedSide, choiceKey))
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>
    /// Reports whether a companion is in the player's roster on a visit only: their own story passed a
    /// temporary join of theirs and none of the removals that take them away again yet.
    /// </summary>
    /// <param name="tables">The tables.</param>
    /// <param name="actor">The companion's main persona.</param>
    /// <param name="own">The player's story.</param>
    /// <param name="notedSide">The side the save notes, <see langword="null"/> for none.</param>
    /// <param name="choiceKey">Tells whether a key is a choice's outcome.</param>
    /// <returns>Whether they are.</returns>
    public static bool Visiting(CatchupTables tables, int actor, StoryValues own, string? notedSide, Func<StoryKey, bool> choiceKey)
    {
        ArgumentNullException.ThrowIfNull(tables);
        foreach (CatchupJoin join in tables.Joins)
        {
            if (join.Actor != actor || join.Place.Part is null)
            {
                continue;
            }

            IReadOnlyList<CatchupRemoval> back = TakingBack(tables, join);
            if (back.Count > 0 && Passed(join.Place, own, own, notedSide, choiceKey) && !back.Any(removal => Passed(removal.Place, own, own, notedSide, choiceKey)))
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>
    /// Lists the world's parts in the order the world played them: Parts 1 to 3, the routes it
    /// finished, and the route under way.
    /// </summary>
    /// <param name="worldPart">The world's part.</param>
    /// <param name="done">The routes the world finished.</param>
    /// <returns>The parts.</returns>
    public static IReadOnlyList<string> WorldParts(string worldPart, IEnumerable<string> done)
    {
        ArgumentNullException.ThrowIfNull(done);
        var parts = new List<string> { "1", "2", "3" };
        parts.AddRange(done);
        if (StoryParts.Routes.Contains(worldPart) && !parts.Contains(worldPart))
        {
            parts.Add(worldPart);
        }

        return parts;
    }

    /// <summary>
    /// Finds where a player moves on to from a part: the next of Parts 1 to 3 the world played that
    /// has a checkpoint, or the world's own story once that is the world's part or none is left. A
    /// route the world finished is never a next part, as the routes stand side by side; a player in
    /// the world's part goes to its story.
    /// </summary>
    /// <param name="from">The player's part.</param>
    /// <param name="worldPart">The world's part.</param>
    /// <param name="done">The routes the world finished.</param>
    /// <param name="checkpoints">The parts the world keeps a checkpoint of.</param>
    /// <returns>The part, or <see cref="WorldTrack"/>.</returns>
    public static string NextPart(string from, string worldPart, IEnumerable<string> done, IEnumerable<string> checkpoints)
    {
        ArgumentNullException.ThrowIfNull(checkpoints);
        if (from == worldPart)
        {
            return WorldTrack;
        }

        IReadOnlyList<string> parts = WorldParts(worldPart, done);
        int at = parts.ToList().IndexOf(from);
        if (at < 0)
        {
            return WorldTrack;
        }

        HashSet<string> kept = [.. checkpoints];
        for (int index = at + 1; index < parts.Count; index++)
        {
            string candidate = parts[index];
            if (candidate == worldPart)
            {
                return WorldTrack;
            }

            if (!StoryParts.Routes.Contains(candidate) && kept.Contains(candidate))
            {
                return candidate;
            }
        }

        return WorldTrack;
    }

    /// <summary>
    /// Reports whether a mark is a choice's outcome: a switch or variable the choices keep each
    /// player's own, never a self switch.
    /// </summary>
    /// <param name="mark">The mark.</param>
    /// <param name="choiceKey">Tells whether a key is a choice's outcome.</param>
    /// <returns>Whether it is.</returns>
    private static bool IsChoice(StoryMark mark, Func<StoryKey, bool> choiceKey) => mark.Key.Kind != StoryKeyKind.SelfSwitch && choiceKey(mark.Key);

    /// <summary>
    /// Finds a row's index in its table by identity.
    /// </summary>
    /// <typeparam name="T">The row.</typeparam>
    /// <param name="rows">The table.</param>
    /// <param name="row">The row.</param>
    /// <returns>Its index, -1 for a row of another table.</returns>
    private static int IndexOf<T>(IReadOnlyList<T> rows, T row)
        where T : class
    {
        for (int index = 0; index < rows.Count; index++)
        {
            if (ReferenceEquals(rows[index], row))
            {
                return index;
            }
        }

        return -1;
    }

    /// <summary>
    /// Orders marks for <see cref="SameMarks"/>: by kind, id, event, letter and least value.
    /// </summary>
    private sealed class MarkOrder : IComparer<StoryMark>
    {
        /// <summary>
        /// The one order.
        /// </summary>
        public static readonly MarkOrder Instance = new();

        /// <inheritdoc />
        public int Compare(StoryMark x, StoryMark y)
        {
            int order = x.Key.Kind.CompareTo(y.Key.Kind);
            order = order != 0 ? order : x.Key.Id.CompareTo(y.Key.Id);
            order = order != 0 ? order : x.Key.Event.CompareTo(y.Key.Event);
            order = order != 0 ? order : string.CompareOrdinal(x.Key.Letter, y.Key.Letter);
            return order != 0 ? order : x.AtLeast.CompareTo(y.AtLeast);
        }
    }
}
