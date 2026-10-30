//----------------------------------------------------------------
//  CoopText.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.Coop;

/// <summary>
/// Reads the texts of the co-op battles' messages as the scripts read them.
/// </summary>
public static class CoopText
{
    /// <summary>
    /// Splits a text as Ruby's <c>split</c> does, which drops the empty items at its end.
    /// </summary>
    /// <param name="text">The text, <see langword="null"/> for none.</param>
    /// <param name="separator">What separates its items.</param>
    /// <returns>The items.</returns>
    public static List<string> Split(string? text, char separator)
    {
        List<string> items = [.. (text ?? string.Empty).Split(separator)];
        while (items.Count > 0 && items[^1].Length == 0)
        {
            items.RemoveAt(items.Count - 1);
        }

        return items;
    }
}
