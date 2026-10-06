//----------------------------------------------------------------
//  ModOption.cs
//
//  Changelog:
//      Paulinchen  2026-10-06: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQParadox.Multiplayer.Mods;

/// <summary>
/// A Mod Config option a mod of the catalog offers, as an admin's game read it.
/// </summary>
/// <param name="Key">The option's key, the name of the Ruby symbol the game keeps its value under.</param>
/// <param name="Name">Its name in the menu.</param>
/// <param name="Type">Its value's type as a world's settings write it: i, f, b, y or s.</param>
/// <param name="Default">Its default value.</param>
/// <param name="Choices">The values the menu offers, each with its name; none for a free value.</param>
internal sealed record ModOption(string Key, string Name, string Type, string Default, IReadOnlyList<(string Value, string Name)> Choices)
{
    /// <summary>
    /// Reads the options the game script wrote, one per line: key, name, type, default, then each
    /// choice's value and name, separated by tabs.
    /// </summary>
    /// <param name="text">The lines.</param>
    /// <returns>The options; a line without a key, name, type and default is left out.</returns>
    public static IReadOnlyList<ModOption> Parse(string text) =>
        text.Split('\n', StringSplitOptions.RemoveEmptyEntries)
            .Select(line => line.TrimEnd('\r').Split('\t'))
            .Where(fields => fields.Length >= 4)
            .Select(fields => new ModOption(fields[0], fields[1], fields[2], fields[3],
                fields.Skip(4).Chunk(2).Where(pair => pair.Length == 2).Select(pair => (pair[0], pair[1])).ToList()))
            .ToList();
}
