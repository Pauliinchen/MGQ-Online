//----------------------------------------------------------------
//  ModCheck.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Checked a world's required mods by the creator's versions of website mods and the Mod Framework's list
//                            - Served a website mod in a version the website's list lacks, for the battle server to read its files
//      Paulinchen  2026-10-31: Logged the creator's hashes the catalog makes unneeded
//      Paulinchen  2026-10-30: Offered the download of a world's mods without a restart
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Mods;

/// <summary>
/// An installed mod as the Mod Framework lists it (<c>Mods.state</c>).
/// </summary>
/// <param name="Name">Its name in the Patch folder, such as "Level_Cap".</param>
/// <param name="Title">Its name for the player, such as "Level Cap".</param>
/// <param name="Version">The version its files are, <see cref="ModCheck.ChangedCopy"/> for a changed copy and a mod the website does not know.</param>
/// <param name="Slug">Its slug on the website, <see langword="null"/> for a mod the website does not have.</param>
/// <param name="On">Whether it is on.</param>
public sealed record InstalledMod(string Name, string Title, string Version, string? Slug, bool On)
{
    /// <summary>
    /// Gets whether the website has the mod and its files are one of its versions.
    /// </summary>
    public bool KnownVersion => Slug != null && Version.Length > 0 && Version != ModCheck.ChangedCopy;

    /// <summary>
    /// Tells whether a world names the mod by a name.
    /// </summary>
    /// <param name="key">The name's key, as <see cref="ModKey"/> makes it.</param>
    /// <returns>Whether its name in Patch, its name for the player or its slug has that key.</returns>
    public bool Has(string key) => ModKey.Of(Name) == key || ModKey.Of(Title) == key || (Slug != null && ModKey.Of(Slug) == key);
}

/// <summary>
/// A required mod this game lacks, has turned off or has in another copy than the creator's.
/// </summary>
/// <param name="Name">The mod's name, as the world writes it.</param>
/// <param name="Yours">This game's copy: <see cref="ModCheck.NotInstalled"/>, <see cref="ModCheck.Off"/>, <see cref="ModCheck.Differs"/> or its version.</param>
/// <param name="Worlds">The version of the creator's copy, <see langword="null"/> when only the creator's hash tells it.</param>
public sealed record ModCheckRow(string Name, string Yours, string? Worlds)
{
    /// <summary>
    /// Gets the difference for the player, such as "Level Cap: yours 1.0.0, the world's 1.1.0".
    /// </summary>
    public string Text => (Yours, Worlds) switch
    {
        (ModCheck.Off, _) => $"{Name}: turned off",
        (ModCheck.Differs, null) => $"{Name}: yours differs from the world creator's copy",
        (ModCheck.Differs, _) => $"{Name}: yours differs from the world's {Worlds}",
        (ModCheck.NotInstalled, null) => $"{Name}: not installed",
        (ModCheck.NotInstalled, _) => $"{Name}: not installed, the world's {Worlds}",
        _ => $"{Name}: yours {Yours}, the world's {Worlds}",
    };
}

/// <summary>
/// A mod of the open world as the battle server runs it for a battle it hosts.
/// </summary>
/// <param name="Key">The website's slug of the mod, or its key for a copy the server cannot get.</param>
/// <param name="Kind"><see cref="ModCheck.SiteKind"/> for a mod the server downloads from the website; empty for a copy it cannot get.</param>
/// <param name="Version">Its version, empty when unknown.</param>
/// <param name="Files">Its files' hashes by their paths inside Patch as the website lists them; none for a copy the server cannot get, and none for a version the website's list lacks, whose files the server reads from the website's details of the mod.</param>
public sealed record ServedMod(string Key, string Kind, string Version, IReadOnlyList<KeyValuePair<string, string>> Files);

/// <summary>
/// The creator's copies of a world's required mods, which the world keeps: the version of each mod
/// the website has, the hash of each other one.
/// </summary>
/// <param name="Versions"><c>name=version</c> pairs separated by semicolons.</param>
/// <param name="Hashes"><c>name=hash</c> pairs separated by semicolons.</param>
public sealed record ModPins(string Versions, string Hashes);

/// <summary>
/// Checks a world's required mods against the mods the Mod Framework lists and the creator's copies,
/// as the world screen does before entering: a mod the website has must be the creator's version,
/// any other one the creator's copy by its hash.
/// </summary>
public sealed class ModCheck
{
    /// <summary>
    /// What a row says of a mod this game lacks.
    /// </summary>
    public const string NotInstalled = "not installed";

    /// <summary>
    /// What a row says of a mod this game has turned off.
    /// </summary>
    public const string Off = "off";

    /// <summary>
    /// What a row says of a copy that is not the creator's: a changed copy, or one whose hash differs.
    /// </summary>
    public const string Differs = "differs";

    /// <summary>
    /// The version the Mod Framework names for a changed copy and a mod the website does not know.
    /// </summary>
    public const string ChangedCopy = "?";

    /// <summary>
    /// The kind of a mod the battle server downloads from the website.
    /// </summary>
    public const string SiteKind = "site";

    /// <summary>
    /// The folder of the game the mods lie in.
    /// </summary>
    public const string PatchFolder = "Patch";

    /// <summary>
    /// Longest mod name the relay takes among the creator's hashes and versions.
    /// </summary>
    public const int MaxPinNameChars = 100;

    /// <summary>
    /// Most characters of the creator's hashes, as many as the relay takes.
    /// </summary>
    public const int MaxHashesChars = 64_000;

    /// <summary>
    /// Most characters of the creator's versions, as many as the relay takes.
    /// </summary>
    public const int MaxVersionsChars = 16_000;

    /// <summary>
    /// Longest version the relay takes among the creator's versions.
    /// </summary>
    private const int MaxVersionChars = 40;

    /// <summary>
    /// The mods the Mod Framework lists, <see langword="null"/> while unknown.
    /// </summary>
    private readonly IReadOnlyList<InstalledMod>? _mods;

    /// <summary>
    /// The scripts in Patch, <see langword="null"/> when the folder could not be read.
    /// </summary>
    private readonly IReadOnlyList<(string Key, string Path)>? _scripts;

    /// <summary>
    /// Hashes a file relative to the game folder, <see langword="null"/> when it is missing or cannot be read.
    /// </summary>
    private readonly Func<string, string?> _hash;

    /// <summary>
    /// Creates a check.
    /// </summary>
    /// <param name="mods">The mods the Mod Framework lists, <see langword="null"/> while unknown.</param>
    /// <param name="scripts">The scripts in Patch with their keys, <see langword="null"/> when the folder could not be read.</param>
    /// <param name="hash">Hashes a file relative to the game folder as the creator's hashes are made.</param>
    public ModCheck(IReadOnlyList<InstalledMod>? mods, IReadOnlyList<(string Key, string Path)>? scripts, Func<string, string?> hash)
    {
        _mods = mods;
        _scripts = scripts;
        _hash = hash;
    }

    /// <summary>
    /// Gets whether the Mod Framework told the installed mods, without which the creator's versions
    /// cannot be compared.
    /// </summary>
    public bool Known => _mods != null;

    /// <summary>
    /// Lists the required mods this game lacks, has turned off or has in another copy than the creator's.
    /// </summary>
    /// <param name="mods">The world's mods as written.</param>
    /// <param name="versions">The creator's versions, <c>name=version</c> pairs separated by semicolons.</param>
    /// <param name="hashes">The creator's hashes, <c>name=hash</c> pairs separated by semicolons.</param>
    /// <returns>A row per such mod, in the order written.</returns>
    public IReadOnlyList<ModCheckRow> Differing(string? mods, string? versions, string? hashes)
    {
        Dictionary<string, string> wanted = PairsOf(versions);
        Dictionary<string, string> creator = PairsOf(hashes);
        return ModsText.Required(mods).Select(name => RowFor(name, wanted, creator)).OfType<ModCheckRow>().ToList();
    }

    /// <summary>
    /// Writes the log line of a world's mod check.
    /// </summary>
    /// <param name="world">The world's name.</param>
    /// <param name="mods">The world's mods as written.</param>
    /// <param name="versions">The creator's versions.</param>
    /// <param name="hashes">The creator's hashes.</param>
    /// <param name="rows">The rows <see cref="Differing"/> found.</param>
    /// <returns>The line.</returns>
    public string CheckLine(string world, string? mods, string? versions, string? hashes, IReadOnlyList<ModCheckRow> rows)
    {
        IReadOnlyList<string> required = ModsText.Required(mods);
        if (required.Count == 0)
        {
            return $"mod check of {world}: no required mods (mods \"{mods}\")";
        }

        Dictionary<string, string> wanted = PairsOf(versions);
        Dictionary<string, string> creator = PairsOf(hashes);
        IEnumerable<string> results = required.Select(name =>
        {
            string key = ModKey.Of(name);
            return rows.FirstOrDefault(row => row.Name == name) is { } row ? row.Text
                : Known && wanted.TryGetValue(key, out string? version) ? $"{name}: matches {version}"
                : creator.ContainsKey(key) ? $"{name}: matches the creator's copy"
                : $"{name}: installed, not compared ({(Known ? "no creator's version or hash" : "the installed mods are unknown")})";
        });
        return $"mod check of {world}: {(rows.Count == 0 ? "all match" : $"{rows.Count} differ")}: {string.Join("; ", results)}";
    }

    /// <summary>
    /// Writes the creator's copies of a world's required mods: the version of each mod the website
    /// has in a version it knows, the hash of the script of each other one.
    /// </summary>
    /// <param name="mods">The world's mods as written.</param>
    /// <param name="log">Notes a mod left out, and why.</param>
    /// <returns>The versions and hashes, each empty for none.</returns>
    public ModPins CreatorPins(string? mods, Action<string> log)
    {
        List<string> versions = [];
        List<string> hashes = [];
        foreach (string name in ModsText.Required(mods))
        {
            if (name.Contains('=', StringComparison.Ordinal) || name.Contains(';', StringComparison.Ordinal) || CodePoints(name) > MaxPinNameChars)
            {
                log($"creator's copy of {name} left out: the relay takes no such name");
                continue;
            }

            if (ModNamed(name) is { KnownVersion: true } mod && IsVersionText(mod.Version))
            {
                versions.Add($"{name}={mod.Version}");
                continue;
            }

            string? path = ScriptPath(name);
            string? hash = path != null ? _hash(path) : null;
            if (hash == null)
            {
                log($"creator's copy of {name} left out: {(path != null ? "its script could not be read" : "no script of it here")}");
                continue;
            }

            hashes.Add($"{name}={hash}");
        }

        return new ModPins(Fit(versions, MaxVersionsChars, log), Fit(hashes, MaxHashesChars, log));
    }

    /// <summary>
    /// Keeps as many pairs as fit the characters the relay takes, in order.
    /// </summary>
    /// <param name="pairs">The pairs.</param>
    /// <param name="most">The most characters.</param>
    /// <param name="log">Notes a pair left out.</param>
    /// <returns>The pairs kept, separated by semicolons.</returns>
    public static string Fit(IEnumerable<string> pairs, int most, Action<string> log)
    {
        List<string> kept = [];
        foreach (string pair in pairs)
        {
            if (CodePoints(string.Join(";", kept.Append(pair))) > most)
            {
                log($"creator's copy of {pair.Split('=')[0]} left out: the world's mods would pass the {most} characters the relay takes");
                continue;
            }

            kept.Add(pair);
        }

        return string.Join(";", kept);
    }

    /// <summary>
    /// Lists the mods of the open world this game runs, which the battle server runs too for a battle
    /// it hosts: each mod the world names and this game has on, but the personal ones.
    /// </summary>
    /// <param name="mods">The world's mods as written.</param>
    /// <param name="personal">The keys of the personal mods.</param>
    /// <param name="files">Finds the files' hashes of a website mod's version by its slug and version, <see langword="null"/> for one the website's list lacks.</param>
    /// <returns>The mods; one the server cannot get from the website with no kind.</returns>
    public IReadOnlyList<ServedMod> Served(string? mods, IReadOnlyCollection<string> personal, Func<string, string, IReadOnlyList<KeyValuePair<string, string>>?> files)
    {
        List<ServedMod> served = [];
        foreach (string name in ModsText.Names(mods))
        {
            string key = ModKey.Of(name);
            if (personal.Contains(key) || !IsOn(name))
            {
                continue;
            }

            served.Add(ModNamed(name) is { KnownVersion: true } mod
                ? new ServedMod(mod.Slug!, SiteKind, mod.Version, files(mod.Slug!, mod.Version) ?? [])
                : new ServedMod(key, "", "", []));
        }

        return served;
    }

    /// <summary>
    /// Finds the installed mod a world names.
    /// </summary>
    /// <param name="name">The name as the world writes it.</param>
    /// <returns>The mod, <see langword="null"/> when none has that name or the mods are unknown.</returns>
    public InstalledMod? ModNamed(string name)
    {
        string key = ModKey.Of(name);
        return _mods?.FirstOrDefault(mod => mod.Has(key));
    }

    /// <summary>
    /// Reads <c>name=value</c> pairs separated by semicolons by the names' keys.
    /// </summary>
    /// <param name="text">The pairs, <see langword="null"/> for none.</param>
    /// <returns>Each value by its name's key.</returns>
    public static Dictionary<string, string> PairsOf(string? text)
    {
        Dictionary<string, string> pairs = new(StringComparer.Ordinal);
        foreach (string pair in RubySplit(text ?? "", ';'))
        {
            string[] parts = pair.Split('=', 2);
            if (parts.Length == 2)
            {
                pairs[ModKey.Of(parts[0])] = parts[1];
            }
        }

        return pairs;
    }

    /// <summary>
    /// Checks one required mod.
    /// </summary>
    /// <param name="name">Its name as the world writes it.</param>
    /// <param name="wanted">The creator's versions by key.</param>
    /// <param name="creator">The creator's hashes by key.</param>
    /// <returns>The row, <see langword="null"/> when this game's copy will do.</returns>
    private ModCheckRow? RowFor(string name, IReadOnlyDictionary<string, string> wanted, IReadOnlyDictionary<string, string> creator)
    {
        string key = ModKey.Of(name);
        string? version = wanted.GetValueOrDefault(key);
        InstalledMod? mod = ModNamed(name);
        if (Known ? mod == null : _scripts != null && ScriptPath(name) == null)
        {
            return new ModCheckRow(name, NotInstalled, version);
        }

        if (mod is { On: false })
        {
            return new ModCheckRow(name, Off, version);
        }

        if (version != null)
        {
            return mod == null || string.Equals(mod.Version, version, StringComparison.OrdinalIgnoreCase) ? null
                : new ModCheckRow(name, mod.KnownVersion ? mod.Version : Differs, version);
        }

        if (!creator.TryGetValue(key, out string? expected) || ScriptPath(name) is not { } path)
        {
            return null;
        }

        return _hash(path) == expected ? null : new ModCheckRow(name, Differs, null);
    }

    /// <summary>
    /// Tells whether this game has a mod a world names on: by the Mod Framework's list, or while it is
    /// unknown by the scripts in Patch.
    /// </summary>
    /// <param name="name">The name as the world writes it.</param>
    /// <returns>Whether it does; true while neither is known.</returns>
    private bool IsOn(string name) => Known ? ModNamed(name) is { On: true } : _scripts == null || ScriptPath(name) != null;

    /// <summary>
    /// Finds the script at the top of Patch of a mod a world names.
    /// </summary>
    /// <param name="name">The name as the world writes it.</param>
    /// <returns>Its path relative to the game folder, <see langword="null"/> for none.</returns>
    private string? ScriptPath(string name)
    {
        string key = ModKey.Of(name);
        string? own = ModNamed(name) is { } mod ? ModKey.Of(mod.Name) : null;
        return _scripts?.FirstOrDefault(script => script.Key == key || script.Key == own).Path;
    }

    /// <summary>
    /// Tells whether a version is one the relay keeps among the creator's versions.
    /// </summary>
    /// <param name="version">The version.</param>
    /// <returns>Whether it has 1 to 40 letters, digits and <c>.+_-</c>.</returns>
    private static bool IsVersionText(string version) =>
        version.Length is > 0 and <= MaxVersionChars && version.All(c => char.IsAsciiLetterOrDigit(c) || c is '.' or '+' or '_' or '-');

    /// <summary>
    /// Counts a text's characters as Ruby does, by code point.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The count.</returns>
    internal static int CodePoints(string text) => text.EnumerateRunes().Count();

    /// <summary>
    /// Splits a text as Ruby's <c>split</c> with a one-character separator does: trailing empty parts dropped.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="separator">The separator.</param>
    /// <returns>The parts.</returns>
    internal static IEnumerable<string> RubySplit(string text, char separator)
    {
        List<string> parts = [.. text.Split(separator)];
        while (parts.Count > 0 && parts[^1].Length == 0)
        {
            parts.RemoveAt(parts.Count - 1);
        }

        return parts;
    }
}
