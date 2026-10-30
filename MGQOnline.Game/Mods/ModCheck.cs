//----------------------------------------------------------------
//  ModCheck.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Offered the download of a world's mods without a restart
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Mods;

/// <summary>
/// A mod of the relay's catalog, as far as the check reads it.
/// </summary>
/// <param name="Key">Its key, as <see cref="ModKey"/> makes it.</param>
/// <param name="Name">Its name.</param>
/// <param name="Kind">"link" for a script the relay follows on GitHub, "zip" for a zip of a release there, "upload" for a mod of several files an admin uploaded.</param>
/// <param name="Version">Its current version.</param>
/// <param name="Files">Its current files' hashes, a script's by its name, a zip's or an upload's by each path inside Patch, in the catalog's order.</param>
/// <param name="Versions">Each version the relay saw and its files' hashes, newest first.</param>
/// <param name="OptionsVersion">The version whose Mod Config options the relay keeps, <see langword="null"/> before an admin's game sent any.</param>
public sealed record CheckedMod(
    string Key,
    string Name,
    string Kind,
    string Version,
    IReadOnlyList<KeyValuePair<string, string>> Files,
    IReadOnlyList<KeyValuePair<string, IReadOnlyList<KeyValuePair<string, string>>>> Versions,
    string? OptionsVersion = null)
{
    /// <summary>
    /// Gets whether the mod comes as a zip whose files go to their paths inside Patch.
    /// </summary>
    public bool IsZip => Kind is "upload" or "zip";
}

/// <summary>
/// A required mod this game lacks or has in another version.
/// </summary>
/// <param name="Name">The mod's name, as the world writes it.</param>
/// <param name="Yours">This game's version: "not installed", the version, "unknown" or "differs".</param>
/// <param name="Worlds">The world's version, <see langword="null"/> when only the creator's hash tells it.</param>
/// <param name="Key">The catalog mod's key, which can be downloaded; <see langword="null"/> for a mod outside the catalog.</param>
/// <param name="Target">Where a link mod's script goes, relative to the game's folder.</param>
public sealed record ModCheckRow(string Name, string Yours, string? Worlds, string? Key, string? Target)
{
    /// <summary>
    /// Gets whether the world's version can be downloaded.
    /// </summary>
    public bool Downloadable => Key != null;

    /// <summary>
    /// Gets the difference for the player, such as "Level Cap: yours 1.0.0, the world's 1.1.0".
    /// </summary>
    public string Text => Worlds switch
    {
        null when Yours == ModCheck.Differs => $"{Name}: yours differs from the world creator's copy",
        null => $"{Name}: not installed",
        _ when Yours == ModCheck.NotInstalled => $"{Name}: not installed, the world's {Worlds}",
        _ => $"{Name}: yours {Yours}, the world's {Worlds}",
    };
}

/// <summary>
/// A mod of the open world as the battle server runs it for a battle it hosts.
/// </summary>
/// <param name="Key">The mod's key.</param>
/// <param name="Kind">Its kind as the catalog has it; empty for a copy the server cannot get.</param>
/// <param name="Version">Its version; this game's for a copy the server cannot get, empty when unknown.</param>
/// <param name="Files">Its files' hashes, none for a copy the server cannot get.</param>
public sealed record ServedMod(string Key, string Kind, string Version, IReadOnlyList<KeyValuePair<string, string>> Files);

/// <summary>
/// Checks a world's required mods against the relay's catalog, this game's copies and the hashes
/// of the creator's copies, as the world screen does before entering.
/// </summary>
public sealed class ModCheck
{
    /// <summary>
    /// What a row says of a mod this game lacks.
    /// </summary>
    public const string NotInstalled = "not installed";

    /// <summary>
    /// What a row says of a copy outside the catalog that differs from the creator's.
    /// </summary>
    public const string Differs = "differs";

    /// <summary>
    /// What a row says of a copy of no version the relay saw.
    /// </summary>
    public const string Unknown = "unknown";

    /// <summary>
    /// The folder of the game the mods lie in.
    /// </summary>
    public const string PatchFolder = "Patch";

    /// <summary>
    /// Longest mod name the relay takes among the creator's hashes.
    /// </summary>
    public const int MaxHashNameChars = 100;

    /// <summary>
    /// Most characters of the creator's hashes, as many as the relay takes.
    /// </summary>
    public const int MaxHashesChars = 64_000;

    /// <summary>
    /// The catalog's mods, <see langword="null"/> while the catalog is unknown.
    /// </summary>
    private readonly IReadOnlyList<CheckedMod>? _catalog;

    /// <summary>
    /// The scripts in Patch, <see langword="null"/> when the folder could not be read.
    /// </summary>
    private readonly IReadOnlyList<(string Key, string Path)>? _installed;

    /// <summary>
    /// Hashes a file relative to the game folder, <see langword="null"/> when it is missing or cannot be read.
    /// </summary>
    private readonly Func<string, string?> _hash;

    /// <summary>
    /// Creates a check.
    /// </summary>
    /// <param name="catalog">The catalog's mods, <see langword="null"/> while the catalog is unknown.</param>
    /// <param name="installed">The scripts in Patch with their keys, <see langword="null"/> when the folder could not be read.</param>
    /// <param name="hash">Hashes a file relative to the game folder as the catalog does.</param>
    public ModCheck(IReadOnlyList<CheckedMod>? catalog, IReadOnlyList<(string Key, string Path)>? installed, Func<string, string?> hash)
    {
        _catalog = catalog;
        _installed = installed;
        _hash = hash;
    }

    /// <summary>
    /// Gets whether the catalog is known.
    /// </summary>
    public bool CatalogKnown => _catalog != null;

    /// <summary>
    /// Lists the required mods of a world that this game lacks or has in another version.
    /// </summary>
    /// <param name="mods">The world's mods as written.</param>
    /// <param name="creatorHashes">The creator's hashes of mods outside the catalog, "name=hash" pairs separated by semicolons.</param>
    /// <returns>The mods, none when every one matches.</returns>
    public IReadOnlyList<ModCheckRow> Differing(string? mods, string? creatorHashes)
    {
        Dictionary<string, string> creator = HashesOf(creatorHashes);
        return ModsText.Required(mods).Select(name => RowFor(name, ModNamed(name), creator)).OfType<ModCheckRow>().ToList();
    }

    /// <summary>
    /// Describes how each required mod of a world compares with this game's, for the log.
    /// </summary>
    /// <param name="world">The world's name.</param>
    /// <param name="mods">The world's mods as written.</param>
    /// <param name="creatorHashes">The creator's hashes.</param>
    /// <param name="rows">The mods that differ, see <see cref="Differing"/>.</param>
    /// <returns>The line.</returns>
    public string CheckLine(string world, string? mods, string? creatorHashes, IReadOnlyList<ModCheckRow> rows)
    {
        IReadOnlyList<string> required = ModsText.Required(mods);
        if (required.Count == 0)
        {
            return $"mod check of {world}: no required mods (mods \"{mods}\")";
        }

        Dictionary<string, string> creator = HashesOf(creatorHashes);
        IEnumerable<string> results = required.Select(name =>
        {
            if (rows.FirstOrDefault(row => row.Name == name) is { } row)
            {
                return row.Text + (row.Downloadable ? ", downloadable" : ", from its author only");
            }

            return ModNamed(name) is { } mod ? $"{name}: matches {mod.Version}"
                : creator.ContainsKey(ModKey.Of(name)) ? $"{name}: matches the creator's copy"
                : $"{name}: installed, not compared (outside the catalog, no creator's hash)";
        });
        return $"mod check of {world}: {(rows.Count == 0 ? "all match" : $"{rows.Count} differ")}{(CatalogKnown ? "" : " (catalog unknown)")}: {string.Join("; ", results)}";
    }

    /// <summary>
    /// Writes the creator's hashes of the required mods outside the catalog, for a world being made
    /// or changed. A mod the creator's game lacks, or whose name the relay does not take, is left out,
    /// so it is only checked for being installed.
    /// </summary>
    /// <param name="mods">The mods as the creator wrote them.</param>
    /// <param name="log">Takes a line for each mod left out.</param>
    /// <returns>"name=hash" pairs separated by semicolons.</returns>
    public string CreatorHashes(string? mods, Action<string> log)
    {
        List<string> pairs = [];
        foreach (string name in ModsText.Required(mods))
        {
            if (ModNamed(name) != null || name.Contains('=', StringComparison.Ordinal) || name.Contains(';', StringComparison.Ordinal) || CodePoints(name) > MaxHashNameChars)
            {
                continue;
            }

            string? path = InstalledPath(name);
            string? hash = path != null ? _hash(path) : null;
            if (hash == null)
            {
                log($"creator's hash of {name} left out: {(path != null ? "it could not be read" : "not installed here")}");
                continue;
            }

            pairs.Add($"{name}={hash}");
        }

        return FitHashes(pairs, MaxHashesChars, log);
    }

    /// <summary>
    /// Joins the creator's hashes as long as they fit what the relay takes, leaving out the rest,
    /// whose mods then only need to be installed.
    /// </summary>
    /// <param name="pairs">Each mod's "name=hash".</param>
    /// <param name="most">The most characters the joined hashes take, counted as Ruby counts them.</param>
    /// <param name="log">Takes a line for each pair left out.</param>
    /// <returns>The hashes that fit, separated by semicolons.</returns>
    public static string FitHashes(IEnumerable<string> pairs, int most, Action<string> log)
    {
        List<string> kept = [];
        foreach (string pair in pairs)
        {
            if (CodePoints(string.Join(";", kept.Append(pair))) > most)
            {
                log($"creator's hash of {pair.Split('=')[0]} left out: the hashes would pass the {most} characters the relay takes");
                continue;
            }

            kept.Add(pair);
        }

        return string.Join(";", kept);
    }

    /// <summary>
    /// Tells the player what differs, in the world screen's lines.
    /// </summary>
    /// <param name="world">The world's name.</param>
    /// <param name="rows">The mods that differ.</param>
    /// <returns>The text.</returns>
    public static string Summary(string world, IReadOnlyList<ModCheckRow> rows)
    {
        IEnumerable<string> names = rows.Select(row => row.Downloadable ? row.Name : $"{row.Name} (get it from its author)");
        string action = rows.All(row => row.Downloadable) ? " Download them?" : "";
        return $"{world} needs mods that are missing or in another version here: {string.Join(", ", names)}.{action}";
    }

    /// <summary>
    /// Names the version of this game's copy of a catalog mod.
    /// </summary>
    /// <param name="mod">The catalog's mod.</param>
    /// <returns>The version; "" for a copy that matches no version the relay knows; <see langword="null"/> when the mod is not installed.</returns>
    public string? InstalledVersion(CheckedMod mod) => RowFor(mod.Name, mod, new Dictionary<string, string>()) switch
    {
        null => mod.Version,
        { Yours: NotInstalled } => null,
        { Yours: Unknown } => "",
        var row => row.Yours,
    };

    /// <summary>
    /// Lists the mods of a world this game runs, which the battle server runs too for a battle it
    /// hosts: each mod the world names and the player installed, but personal ones.
    /// </summary>
    /// <param name="mods">The world's mods as written.</param>
    /// <param name="personal">The keys of the catalog's personal mods, none while the catalog is unknown.</param>
    /// <returns>The mods; one the server cannot get, outside the catalog or of another version than its current one, without a kind.</returns>
    public IReadOnlyList<ServedMod> Served(string? mods, IReadOnlyCollection<string> personal)
    {
        List<ServedMod> served = [];
        foreach (string name in ModsText.Names(mods))
        {
            string key = ModKey.Of(name);
            if (personal.Contains(key) || !IsInstalled(name))
            {
                continue;
            }

            if (ModNamed(name) is not { } mod)
            {
                served.Add(new ServedMod(key, "", "", []));
                continue;
            }

            ModCheckRow? row = mod.IsZip ? ZipRow(name, mod) : LinkRow(name, mod);
            served.Add(row != null ? new ServedMod(key, "", row.Yours, []) : new ServedMod(mod.Key, mod.Kind, mod.Version, mod.Files));
        }

        return served;
    }

    /// <summary>
    /// Finds the catalog's mod for a name as a world writes it.
    /// </summary>
    /// <param name="name">The mod's name.</param>
    /// <returns>The mod, <see langword="null"/> when the catalog lacks it or is unknown.</returns>
    public CheckedMod? ModNamed(string name)
    {
        string key = ModKey.Of(name);
        return _catalog?.FirstOrDefault(mod => mod.Key == key);
    }

    /// <summary>
    /// Reads the creator's hashes of mods outside the catalog.
    /// </summary>
    /// <param name="text">"name=hash" pairs separated by semicolons.</param>
    /// <returns>The hashes by the mods' keys, a later pair winning.</returns>
    public static Dictionary<string, string> HashesOf(string? text)
    {
        Dictionary<string, string> hashes = new(StringComparer.Ordinal);
        foreach (string pair in RubySplit(text ?? "", ';'))
        {
            string[] parts = pair.Split('=', 2);
            if (parts.Length == 2)
            {
                hashes[ModKey.Of(parts[0])] = parts[1];
            }
        }

        return hashes;
    }

    /// <summary>
    /// Checks one required mod.
    /// </summary>
    /// <param name="name">The mod's name, as the world writes it.</param>
    /// <param name="mod">The catalog's mod, <see langword="null"/> when the catalog lacks it.</param>
    /// <param name="creator">The creator's hashes by key.</param>
    /// <returns>The difference, <see langword="null"/> when this game's copy matches.</returns>
    private ModCheckRow? RowFor(string name, CheckedMod? mod, IReadOnlyDictionary<string, string> creator)
    {
        if (mod != null)
        {
            return mod.IsZip ? ZipRow(name, mod) : LinkRow(name, mod);
        }

        if (!IsInstalled(name))
        {
            return new ModCheckRow(name, NotInstalled, null, null, null);
        }

        if (!creator.TryGetValue(ModKey.Of(name), out string? expected) || InstalledPath(name) is not { } path)
        {
            return null;
        }

        return _hash(path) == expected ? null : new ModCheckRow(name, Differs, null, null, null);
    }

    /// <summary>
    /// Checks a link mod's script.
    /// </summary>
    /// <param name="name">The mod's name, as the world writes it.</param>
    /// <param name="mod">The catalog's mod.</param>
    /// <returns>The difference, <see langword="null"/> when this game's script is the current one.</returns>
    private ModCheckRow? LinkRow(string name, CheckedMod mod)
    {
        (string file, string current) = mod.Files.Count > 0 ? (mod.Files[0].Key, mod.Files[0].Value) : ("", "");
        if (InstalledPath(name) is not { } path)
        {
            return new ModCheckRow(name, NotInstalled, mod.Version, mod.Key, $"{PatchFolder}/{file}");
        }

        string? hash = _hash(path);
        if (hash == current)
        {
            return null;
        }

        return new ModCheckRow(name, VersionOf(mod, [new KeyValuePair<string, string?>(file, hash)]) ?? Unknown, mod.Version, mod.Key, path);
    }

    /// <summary>
    /// Checks the files of a mod that comes as a zip.
    /// </summary>
    /// <param name="name">The mod's name, as the world writes it.</param>
    /// <param name="mod">The catalog's mod.</param>
    /// <returns>The difference, <see langword="null"/> when every file is the current one.</returns>
    private ModCheckRow? ZipRow(string name, CheckedMod mod)
    {
        List<KeyValuePair<string, string?>> hashes = mod.Files.Select(file => new KeyValuePair<string, string?>(file.Key, _hash($"{PatchFolder}/{file.Key}"))).ToList();
        if (Same(mod.Files, hashes))
        {
            return null;
        }

        return hashes.All(hash => hash.Value == null)
            ? new ModCheckRow(name, NotInstalled, mod.Version, mod.Key, null)
            : new ModCheckRow(name, VersionOf(mod, hashes) ?? Unknown, mod.Version, mod.Key, null);
    }

    /// <summary>
    /// Names the version whose files a copy's hashes are.
    /// </summary>
    /// <param name="mod">The catalog's mod.</param>
    /// <param name="hashes">The copy's hashes, a missing file's <see langword="null"/>.</param>
    /// <returns>The version, <see langword="null"/> when the relay never saw this copy.</returns>
    private static string? VersionOf(CheckedMod mod, IReadOnlyList<KeyValuePair<string, string?>> hashes) =>
        mod.Versions.FirstOrDefault(version => Same(version.Value, hashes)).Key;

    /// <summary>
    /// Tells whether hashes are those of a version's files, whatever their order, as Ruby compares two Hashes.
    /// </summary>
    /// <param name="files">The version's files' hashes.</param>
    /// <param name="hashes">The copy's hashes.</param>
    /// <returns>Whether both name the same files with the same hashes.</returns>
    private static bool Same(IReadOnlyList<KeyValuePair<string, string>> files, IReadOnlyList<KeyValuePair<string, string?>> hashes)
    {
        Dictionary<string, string?> mine = new(StringComparer.Ordinal);
        foreach (var (path, hash) in hashes)
        {
            mine[path] = hash;
        }

        Dictionary<string, string> theirs = new(StringComparer.Ordinal);
        foreach (var (path, hash) in files)
        {
            theirs[path] = hash;
        }

        return mine.Count == theirs.Count && theirs.All(file => mine.TryGetValue(file.Key, out string? hash) && hash == file.Value);
    }

    /// <summary>
    /// Tells whether a mod's script is installed; also when Patch could not be read, so nobody is
    /// kept out by mistake.
    /// </summary>
    /// <param name="name">The mod's name.</param>
    /// <returns>Whether it is.</returns>
    private bool IsInstalled(string name)
    {
        string key = ModKey.Of(name);
        return _installed == null || _installed.Any(script => script.Key == key);
    }

    /// <summary>
    /// Finds a mod's script in Patch.
    /// </summary>
    /// <param name="name">The mod's name.</param>
    /// <returns>Its path relative to the game folder, <see langword="null"/> when it is not installed or Patch could not be read.</returns>
    private string? InstalledPath(string name)
    {
        string key = ModKey.Of(name);
        return _installed?.FirstOrDefault(script => script.Key == key).Path;
    }

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
