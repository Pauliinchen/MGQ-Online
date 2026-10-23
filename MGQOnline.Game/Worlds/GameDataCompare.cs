//----------------------------------------------------------------
//  GameDataCompare.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace MGQOnline.Game.Worlds;

/// <summary>
/// Compares two games' data by the fingerprints the scripts make (<c>MGQ_MpWorld::GameData</c>): a
/// format, a colon, then one checksum per part of the database separated by dots.
/// </summary>
public static class GameDataCompare
{
    /// <summary>
    /// What a fingerprint covers, in its order, as a difference is called.
    /// </summary>
    public static readonly IReadOnlyList<string> Parts = ["actors", "classes", "skills", "items", "weapons", "armors", "enemies", "states", "troops", "common events", "maps"];

    /// <summary>
    /// Most parts a text names before it counts the rest, unless the caller says otherwise.
    /// </summary>
    public const int NamedParts = 4;

    /// <summary>
    /// Lists what of one game's data differs from another's.
    /// </summary>
    /// <param name="mine">This game's fingerprint, empty when its data could not be read.</param>
    /// <param name="other">The other game's fingerprint, empty or <see langword="null"/> when unknown.</param>
    /// <returns>The parts that differ, none when the games match; <see langword="null"/> when they cannot be compared.</returns>
    public static IReadOnlyList<string>? Differing(string mine, string? other)
    {
        if (string.IsNullOrEmpty(other) || Split(mine) is not var (format, mineSums) || Split(other) is not var (otherFormat, otherSums) || format != otherFormat)
        {
            return null;
        }

        if (mineSums.Length != Parts.Count || otherSums.Length != Parts.Count)
        {
            return null;
        }

        return Enumerable.Range(0, Parts.Count).Where(index => mineSums[index] != otherSums[index]).Select(index => Parts[index]).ToList();
    }

    /// <summary>
    /// Names parts in a sentence, the first few by name.
    /// </summary>
    /// <param name="parts">The parts.</param>
    /// <param name="named">Most parts named before the rest is counted.</param>
    /// <returns>The text, such as "skills, items and 3 more".</returns>
    public static string Text(IReadOnlyList<string> parts, int named = NamedParts) =>
        parts.Count <= named
            ? string.Join(", ", parts)
            : string.Create(CultureInfo.InvariantCulture, $"{string.Join(", ", parts.Take(Math.Max(named, 0)))} and {parts.Count - named} more");

    /// <summary>
    /// Splits a fingerprint into its format and its checksums, as Ruby's <c>split</c> does.
    /// </summary>
    /// <param name="fingerprint">The fingerprint.</param>
    /// <returns>The format and the checksums, trailing empty ones left out; <see langword="null"/> without a colon.</returns>
    private static (string Format, string[] Sums)? Split(string fingerprint)
    {
        int colon = fingerprint.IndexOf(':', StringComparison.Ordinal);
        if (colon < 0)
        {
            return null;
        }

        List<string> sums = [.. fingerprint[(colon + 1)..].Split('.')];
        while (sums.Count > 0 && sums[^1].Length == 0)
        {
            sums.RemoveAt(sums.Count - 1);
        }

        return (fingerprint[..colon], sums.ToArray());
    }
}
