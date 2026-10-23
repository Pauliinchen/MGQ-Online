//----------------------------------------------------------------
//  ModPick.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Named the states and their colours
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Game.Mods;

namespace MGQOnline.Game.Worlds;

/// <summary>
/// How the mod picker names a mod in a world's mods.
/// </summary>
public enum ModPickState
{
    /// <summary>
    /// Not named.
    /// </summary>
    Unlisted,

    /// <summary>
    /// Named without a mark.
    /// </summary>
    Listed,

    /// <summary>
    /// Named with "!", so a game needs its script to enter.
    /// </summary>
    Required,

    /// <summary>
    /// Named with "?", so it stands out without a script looked for.
    /// </summary>
    Essential,
}

/// <summary>
/// What the mod picker shows of how a mod is named.
/// </summary>
public static class ModPickStates
{
    /// <summary>
    /// Names a state, as the right end of a mod's row says it.
    /// </summary>
    /// <param name="state">The state.</param>
    /// <returns>"unlisted", "listed", "required" or "essential".</returns>
    public static string NameOf(ModPickState state) => state switch
    {
        ModPickState.Listed => "listed",
        ModPickState.Required => "required",
        ModPickState.Essential => "essential",
        _ => "unlisted",
    };

    /// <summary>
    /// Names the colour of a mod's row: a required one red and an essential one gold, near the red
    /// and orange of its buttons.
    /// </summary>
    /// <param name="state">The state.</param>
    /// <returns>"grey", "plain", "bad" or "gold".</returns>
    public static string ColorOf(ModPickState state) => state switch
    {
        ModPickState.Listed => "plain",
        ModPickState.Required => "bad",
        ModPickState.Essential => "gold",
        _ => "grey",
    };
}

/// <summary>
/// A mod of the picker.
/// </summary>
/// <param name="Name">Its name, the script's file name for an installed one.</param>
/// <param name="State">How it is named.</param>
/// <param name="Installed">Whether the Patch folder holds it.</param>
public sealed record ModPickEntry(string Name, ModPickState State, bool Installed);

/// <summary>
/// The mods of a world as the mod picker shows them: every mod the Patch folder holds, each
/// unlisted, listed, required or essential, then the mods added by name, which this game lacks.
/// </summary>
public sealed class ModPick
{
    /// <summary>
    /// Longest text that names a world's mods, in characters, as long as the relay takes.
    /// </summary>
    public const int MaxChars = 16_000;

    /// <summary>
    /// What a change answers when the text would grow past <see cref="MaxChars"/>.
    /// </summary>
    public static readonly string TooLong = string.Create(CultureInfo.InvariantCulture, $"The mods may take {MaxChars} characters at most.");

    /// <summary>
    /// The mods, the installed ones first.
    /// </summary>
    private readonly List<ModPickEntry> _entries;

    /// <summary>
    /// Makes the key mods are compared by.
    /// </summary>
    private readonly Func<string, string> _keyOf;

    /// <summary>
    /// Reads the mods a world names into the player's installed ones; a named mod the player lacks
    /// follows them as added.
    /// </summary>
    /// <param name="text">The mods as written, see <see cref="ModsText"/>.</param>
    /// <param name="installed">The installed mods' names.</param>
    /// <param name="keyOf">Makes the key mods are compared by, such as <see cref="ModKey.Of"/>.</param>
    public ModPick(string? text, IEnumerable<string> installed, Func<string, string> keyOf)
    {
        _keyOf = keyOf;
        _entries = [.. installed.Select(name => new ModPickEntry(name, ModPickState.Unlisted, true))];
        IReadOnlyList<string> required = ModsText.Required(text);
        IReadOnlyList<string> essential = ModsText.Essential(text);
        foreach (string name in ModsText.Names(text))
        {
            ModPickState state = required.Contains(name, StringComparer.Ordinal) ? ModPickState.Required
                : essential.Contains(name, StringComparer.Ordinal) ? ModPickState.Essential : ModPickState.Listed;
            int found = Find(name);
            if (found >= 0)
            {
                _entries[found] = _entries[found] with { State = state };
            }
            else
            {
                _entries.Add(new ModPickEntry(name, state, false));
            }
        }
    }

    /// <summary>
    /// Gets the mods, the installed ones first.
    /// </summary>
    public IReadOnlyList<ModPickEntry> Entries => _entries;

    /// <summary>
    /// Gets whether every installed mod is named; also when none is installed.
    /// </summary>
    public bool AllListed => _entries.All(entry => !entry.Installed || entry.State != ModPickState.Unlisted);

    /// <summary>
    /// Writes the mods named, the way a world keeps them.
    /// </summary>
    /// <returns>Each named mod with its mark, separated by semicolons.</returns>
    public string Text() =>
        string.Join("; ", _entries.Where(entry => entry.State != ModPickState.Unlisted).Select(entry => MarkOf(entry.State) + entry.Name));

    /// <summary>
    /// Names a mod another way. An added mod unlisted stays in the picker, but out of the text.
    /// </summary>
    /// <param name="index">The mod's index in <see cref="Entries"/>.</param>
    /// <param name="state">How to name it.</param>
    /// <returns>Why it cannot, <see langword="null"/> when it was done.</returns>
    public string? Set(int index, ModPickState state)
    {
        ModPickEntry before = _entries[index];
        _entries[index] = before with { State = state };
        if (CharsOf(Text()) <= MaxChars)
        {
            return null;
        }

        _entries[index] = before;
        return TooLong;
    }

    /// <summary>
    /// Lists an unlisted mod, or unlists a named one.
    /// </summary>
    /// <param name="index">The mod's index in <see cref="Entries"/>.</param>
    /// <returns>Why it cannot, <see langword="null"/> when it was done.</returns>
    public string? Toggle(int index) => Set(index, _entries[index].State == ModPickState.Unlisted ? ModPickState.Listed : ModPickState.Unlisted);

    /// <summary>
    /// Makes a mod required or essential, or only listed again when it is so already.
    /// </summary>
    /// <param name="index">The mod's index in <see cref="Entries"/>.</param>
    /// <param name="state"><see cref="ModPickState.Required"/> or <see cref="ModPickState.Essential"/>.</param>
    /// <returns>Why it cannot, <see langword="null"/> when it was done.</returns>
    public string? Mark(int index, ModPickState state) => Set(index, _entries[index].State == state ? ModPickState.Listed : state);

    /// <summary>
    /// Takes a mod added by name out of the picker. An installed mod stays, since the Patch folder holds it.
    /// </summary>
    /// <param name="index">The mod's index in <see cref="Entries"/>.</param>
    /// <returns>Whether it was taken out.</returns>
    public bool Remove(int index)
    {
        if (_entries[index].Installed)
        {
            return false;
        }

        _entries.RemoveAt(index);
        return true;
    }

    /// <summary>
    /// Lists every unlisted installed mod, in order, until the text would grow too long.
    /// </summary>
    /// <returns>Why the rest could not be listed, <see langword="null"/> when all were.</returns>
    public string? ListAll()
    {
        for (int index = 0; index < _entries.Count; index++)
        {
            if (_entries[index].Installed && _entries[index].State == ModPickState.Unlisted && Set(index, ModPickState.Listed) is { } error)
            {
                return error;
            }
        }

        return null;
    }

    /// <summary>
    /// Unlists every installed mod; the mods added by name stay.
    /// </summary>
    public void UnlistAll()
    {
        for (int index = 0; index < _entries.Count; index++)
        {
            if (_entries[index].Installed)
            {
                _entries[index] = _entries[index] with { State = ModPickState.Unlisted };
            }
        }
    }

    /// <summary>
    /// Adds a mod the player lacks by its name, listed.
    /// </summary>
    /// <param name="written">The name as typed.</param>
    /// <returns>Why it cannot, <see langword="null"/> when it was added.</returns>
    public string? Add(string written)
    {
        string name = ModsText.NameOf(written);
        if (name.Length == 0)
        {
            return "A mod's name cannot be empty.";
        }

        if (name.Contains(';', StringComparison.Ordinal))
        {
            return "A mod's name cannot hold a semicolon.";
        }

        if (Find(name) is var found and >= 0)
        {
            return $"{_entries[found].Name} is in the list already.";
        }

        _entries.Add(new ModPickEntry(name, ModPickState.Listed, false));
        if (CharsOf(Text()) <= MaxChars)
        {
            return null;
        }

        _entries.RemoveAt(_entries.Count - 1);
        return TooLong;
    }

    /// <summary>
    /// Counts a text's characters as Ruby and the relay count them, by code point.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>Its characters.</returns>
    public static int CharsOf(string text) => text.EnumerateRunes().Count();

    /// <summary>
    /// Finds a mod by its name, whatever its case, spaces, underscores and hyphens.
    /// </summary>
    /// <param name="name">The name.</param>
    /// <returns>The mod's index, -1 when the picker has none of that name.</returns>
    private int Find(string name)
    {
        string key = _keyOf(name);
        return _entries.FindIndex(entry => _keyOf(entry.Name) == key);
    }

    /// <summary>
    /// Names the mark of a state.
    /// </summary>
    /// <param name="state">The state.</param>
    /// <returns>"!", "?" or nothing.</returns>
    private static string MarkOf(ModPickState state) => state switch
    {
        ModPickState.Required => "!",
        ModPickState.Essential => "?",
        _ => "",
    };
}
