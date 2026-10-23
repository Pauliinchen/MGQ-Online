//----------------------------------------------------------------
//  WorldSaves.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;

namespace MGQOnline.Game.Worlds;

/// <summary>
/// A world's latest save.
/// </summary>
/// <param name="File">The save file's name.</param>
/// <param name="Slot">The save's index as the game's DataManager takes it, from 0; <see langword="null"/> for an autosave.</param>
/// <param name="AutoSlot">An autosave's two digits as DataManager takes them, such as "01"; <see langword="null"/> for a save.</param>
public sealed record LatestSave(string File, int? Slot, string? AutoSlot);

/// <summary>
/// Finds a world's latest save among the files of its Save folder.
/// </summary>
public static class WorldSaves
{
    /// <summary>
    /// What a save's file is named before its two digits.
    /// </summary>
    private const string SavePrefix = "Save";

    /// <summary>
    /// What an autosave's file is named before its two digits.
    /// </summary>
    private const string AutoSavePrefix = "AutoSave";

    /// <summary>
    /// What both end with.
    /// </summary>
    private const string Extension = ".rvdata2";

    /// <summary>
    /// Finds the latest save, an autosave included, by when its file was written.
    /// </summary>
    /// <param name="files">Each file's name and when it was written, in the folder's order; of two written at once the first wins.</param>
    /// <returns>The save, <see langword="null"/> without any.</returns>
    public static LatestSave? Latest(IEnumerable<(string Name, DateTime Written)> files)
    {
        LatestSave? latest = null;
        DateTime newest = DateTime.MinValue;
        foreach ((string name, DateTime written) in files)
        {
            if (Of(name) is { } save && (latest == null || written > newest))
            {
                latest = save;
                newest = written;
            }
        }

        return latest;
    }

    /// <summary>
    /// Reads a file's name as a save's, whatever its case.
    /// </summary>
    /// <param name="name">The file's name.</param>
    /// <returns>The save, <see langword="null"/> for a file that is none.</returns>
    public static LatestSave? Of(string name)
    {
        if (Digits(name, AutoSavePrefix) is { } auto)
        {
            return new LatestSave(name, null, auto);
        }

        return Digits(name, SavePrefix) is { } digits ? new LatestSave(name, int.Parse(digits, CultureInfo.InvariantCulture) - 1, null) : null;
    }

    /// <summary>
    /// Reads the two digits of a file named the prefix, two digits and the extension.
    /// </summary>
    /// <param name="name">The file's name.</param>
    /// <param name="prefix">The prefix.</param>
    /// <returns>The digits, <see langword="null"/> for a file named otherwise.</returns>
    private static string? Digits(string name, string prefix)
    {
        if (name.Length != prefix.Length + 2 + Extension.Length
            || !name.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)
            || !name.EndsWith(Extension, StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        string digits = name.Substring(prefix.Length, 2);
        return char.IsAsciiDigit(digits[0]) && char.IsAsciiDigit(digits[1]) ? digits : null;
    }
}
