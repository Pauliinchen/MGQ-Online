//----------------------------------------------------------------
//  ClassicMerge.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace MGQOnline.Game.Story;

/// <summary>
/// Decides how a Classic party leader's story and a member's game exchange it: what the leader's
/// story keeps of a member's write, as the relay takes a Raid World's writes, which of a member's
/// runs the story keeps, and which of the leader's changes a member who follows the story takes.
/// </summary>
public static class ClassicMerge
{
    /// <summary>
    /// Reports whether the leader's story takes a member's write: a key the reviewed list makes the
    /// story's takes the member's value, but a count, which each game counts of its own switches, and
    /// a one-way value set lower stay as the story holds them; every other key stays.
    /// </summary>
    /// <param name="scope">Who keeps the key in a Classic party.</param>
    /// <param name="kind">The key's class in the reviewed list.</param>
    /// <param name="held">The value the story holds, as the tracks write it.</param>
    /// <param name="value">The value the member wrote, as the tracks write it.</param>
    /// <returns>Whether it takes the member's value.</returns>
    public static bool Takes(StoryScope scope, StoryClass kind, string held, string value)
    {
        if (scope != StoryScope.World || kind.HasFlag(StoryClass.Count))
        {
            return false;
        }

        return !(kind.HasFlag(StoryClass.OneWay) && Number(value) is { } written && Number(held) is { } kept && written < kept);
    }

    /// <summary>
    /// Reports whether the leader's story keeps a member's run in its stream, which the party and the
    /// leader's own game then play: a run whose writes the story took, or one that holds a party key,
    /// which the member's own save changed. A run that changed nothing of it, as the second of two
    /// openers of a chest, goes to nobody.
    /// </summary>
    /// <param name="keys">The keys the run wrote.</param>
    /// <param name="changed">Tells whether the member's requests changed a key in the leader's story.</param>
    /// <param name="scopeOf">Who keeps a key in a Classic party, at the run's site.</param>
    /// <returns>Whether it keeps it.</returns>
    public static bool KeepsRun(IEnumerable<StoryKey> keys, Func<StoryKey, bool> changed, Func<StoryKey, StoryScope> scopeOf)
    {
        ArgumentNullException.ThrowIfNull(keys);
        ArgumentNullException.ThrowIfNull(changed);
        ArgumentNullException.ThrowIfNull(scopeOf);
        return keys.Any(key => changed(key) || scopeOf(key) == StoryScope.Party);
    }

    /// <summary>
    /// Reports whether a member who follows the leader's story takes a change of it: a key the
    /// reviewed list makes the story's, unless it is the outcome of a choice, which each member's own
    /// story decides.
    /// </summary>
    /// <param name="scope">Who keeps the key in a Classic party.</param>
    /// <param name="choice">Whether the key is a choice's outcome the member's own story keeps.</param>
    /// <returns>Whether they take it.</returns>
    public static bool Follows(StoryScope scope, bool choice) => scope == StoryScope.World && !choice;

    /// <summary>
    /// Reads a number the tracks write: "n" before a whole number, "f" before any other.
    /// </summary>
    /// <param name="text">The value as written.</param>
    /// <returns>The number, <see langword="null"/> for a value that is none.</returns>
    private static double? Number(string text) =>
        text.Length > 1 && text[0] is 'n' or 'f' && double.TryParse(text.AsSpan(1), NumberStyles.Float, CultureInfo.InvariantCulture, out double number) ? number : null;
}
