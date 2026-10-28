//----------------------------------------------------------------
//  PartEnd.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using MGQOnline.Game.Events;

namespace MGQOnline.Game.Story;

/// <summary>
/// A write that moves a story out of its part, see <see cref="PartEnd.Leaving"/>.
/// </summary>
/// <param name="Variable">The variable the story's part follows.</param>
/// <param name="Value">The value written, <see langword="null"/> for one known only as the event runs.</param>
/// <param name="Part">The part left, <see langword="null"/> when it is not known.</param>
public sealed record PartLeave(long Variable, long? Value, string? Part)
{
    /// <summary>
    /// Tells why the event would leave the part, for the log.
    /// </summary>
    /// <returns>Such as "it sets variable 1001 to 19, which leaves Part 1".</returns>
    public string Why()
    {
        string what = Value is { } value ? $"to {value.ToString(CultureInfo.InvariantCulture)}" : "to a value known only as it runs";
        string part = Part is null ? "the part the relay has yet to name" : $"Part {Part}";
        return $"it sets variable {Variable.ToString(CultureInfo.InvariantCulture)} {what}, which leaves {part}";
    }
}

/// <summary>
/// Tells whether an event would move a player behind the world's story past the end of their part
/// (issue #48), which the relay refuses on their own track with the code "held"
/// (Relay/core/story_tracks.js <c>heldRefusal</c>): a write of a variable the part follows (1001
/// and the routes' 1141 to 1143) that puts the story in another part. Every other write runs.
/// </summary>
/// <remarks>
/// Every branch counts, so an event that may end the part on one branch is held on all of them.
/// </remarks>
public static class PartEnd
{
    /// <summary>
    /// The main story's progress, variable 1001.
    /// </summary>
    public const long MainProgress = 1001;

    /// <summary>
    /// The routes' variables in the order of <see cref="StoryParts.Routes"/>.
    /// </summary>
    public static readonly IReadOnlyList<long> RouteVariables = [1141, 1142, 1143];

    /// <summary>
    /// Every variable the part follows.
    /// </summary>
    private static readonly long[] PartVariables = [MainProgress, .. RouteVariables];

    /// <summary>
    /// Finds the first write of an event that moves a story out of its part.
    /// </summary>
    /// <param name="part">The part the player's track is in, see <see cref="StoryParts"/>; <see langword="null"/> or unknown, and any write of the part's variables leaves it.</param>
    /// <param name="sets">The variables the event and the chain it starts set, see <see cref="EventChain.VariableSetsOf"/>.</param>
    /// <param name="kept">Tells whether a variable is kept on the tracks; one each player keeps as their own never moves the part the relay holds.</param>
    /// <returns>The write, <see langword="null"/> when the event stays in the part.</returns>
    public static PartLeave? Leaving(string? part, IEnumerable<VariableSet> sets, Func<long, bool> kept)
    {
        ArgumentNullException.ThrowIfNull(sets);
        ArgumentNullException.ThrowIfNull(kept);
        string? known = part is not null && IndexOf(StoryParts.All, part) >= 0 ? part : null;
        foreach (VariableSet set in sets)
        {
            foreach (long variable in PartVariables)
            {
                if (set.From <= variable && variable <= set.To && kept(variable) && (known is null || set.Value is not { } value || Leaves(known, variable, value)))
                {
                    return new PartLeave(variable, set.Value, known);
                }
            }
        }

        return null;
    }

    /// <summary>
    /// Tells whether one value of a variable the part follows puts a story in another part, by the
    /// rule of <see cref="StoryParts.Of"/>: the first route under way, else the main story's progress.
    /// </summary>
    /// <param name="part">The story's part.</param>
    /// <param name="variable">The variable.</param>
    /// <param name="value">Its value.</param>
    /// <returns>Whether it does.</returns>
    private static bool Leaves(string part, long variable, long value)
    {
        int route = IndexOf(RouteVariables, variable);
        int current = IndexOf(StoryParts.Routes, part);
        if (current < 0)
        {
            return route < 0 ? StoryParts.Of(value, []) != part : value > 0;
        }

        return route >= 0 && (route < current ? value > 0 : route == current && value <= 0);
    }

    /// <summary>
    /// Finds an item in a list.
    /// </summary>
    /// <typeparam name="T">The items' type.</typeparam>
    /// <param name="list">The list.</param>
    /// <param name="item">The item.</param>
    /// <returns>Its place, -1 for none.</returns>
    private static int IndexOf<T>(IReadOnlyList<T> list, T item)
    {
        for (int at = 0; at < list.Count; at++)
        {
            if (EqualityComparer<T>.Default.Equals(list[at], item))
            {
                return at;
            }
        }

        return -1;
    }
}
