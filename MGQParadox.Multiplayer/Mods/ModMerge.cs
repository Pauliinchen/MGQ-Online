//----------------------------------------------------------------
//  ModMerge.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Carried the website's thumbnail
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.RegularExpressions;

namespace MGQParadox.Multiplayer.Mods;

/// <summary>
/// Makes the mods the mod browser offers out of the website's list and the relay's catalog: the
/// entries whose latest versions ship the same code files are one mod, which the website's entry
/// names before a relay link's, and a relay link's before an upload's; two website mods stay two.
/// </summary>
/// <remarks>
/// Every merged entry's versions are known versions, since the website lists only the newest
/// version while the relay keeps the hashes of older ones.
/// </remarks>
internal static partial class ModMerge
{
    /// <summary>
    /// The most changelog lines kept per mod.
    /// </summary>
    public const int MaxNotes = 40;

    /// <summary>
    /// The folder of MGQ Online's own files inside Patch, which the mod browser never touches.
    /// </summary>
    private const string OwnFolder = "Multiplayer";

    /// <summary>
    /// MGQ Online's own script in Patch, which the mod browser never touches.
    /// </summary>
    private const string OwnScript = "Multiplayer.rb";

    /// <summary>
    /// Makes the mods.
    /// </summary>
    /// <param name="site">The website's mods; <see langword="null"/> when the list could not be had.</param>
    /// <param name="relay">The relay catalog's mods; <see langword="null"/> when it could not be had.</param>
    /// <returns>The mods, in no particular order.</returns>
    public static IReadOnlyList<BrowsedMod> Merge(IReadOnlyList<SiteMod>? site, IReadOnlyList<CatalogMod>? relay)
    {
        var entries = new List<(int Rank, BrowsedMod Mod)>();
        entries.AddRange((site ?? []).Select(FromSite).OfType<BrowsedMod>().Select(mod => (0, mod)));
        entries.AddRange((relay ?? []).Where(mod => mod.Kind != CatalogMod.NameKind).Select(FromRelay).OfType<BrowsedMod>().Select(mod => (mod.Install.IsUpload ? 2 : 1, mod)));
        entries.RemoveAll(entry => !Offered(entry.Mod));

        var group = Enumerable.Range(0, entries.Count).ToArray();
        var holdsSite = entries.Select(entry => entry.Rank == 0).ToArray();
        var owner = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);

        for (var index = 0; index < entries.Count; index++)
        {
            var code = CodeOf(entries[index].Mod);

            if (code.Length == 0)
            {
                continue;
            }

            if (owner.TryGetValue(code, out var other))
            {
                var mine = RootOf(group, index);
                var theirs = RootOf(group, other);

                if (mine != theirs && !(holdsSite[mine] && holdsSite[theirs]))
                {
                    group[mine] = theirs;
                    holdsSite[theirs] |= holdsSite[mine];
                }
            }
            else
            {
                owner[code] = index;
            }
        }

        return Enumerable.Range(0, entries.Count)
            .GroupBy(index => RootOf(group, index))
            .Select(members => Joined(members.Select(index => entries[index]).ToList()))
            .ToList();
    }

    /// <summary>
    /// Makes one mod of entries that share a path.
    /// </summary>
    /// <param name="members">The entries, each with its rank, in the order the sources list them.</param>
    /// <returns>The mod, named and installed after the entry of the lowest rank listed first, knowing every entry's versions.</returns>
    private static BrowsedMod Joined(List<(int Rank, BrowsedMod Mod)> members)
    {
        var winner = members.OrderBy(member => member.Rank).First().Mod;

        if (members.Count == 1)
        {
            return winner;
        }

        var latest = winner.Known[0];
        var others = new List<ModVersion>();

        foreach (var version in members.SelectMany(member => member.Mod.Known))
        {
            if (!others.Append(latest).Any(known => Same(known, version)))
            {
                others.Add(version);
            }
        }

        var older = others.OrderByDescending(version => VersionNumbers(version.Version), VersionComparer.Instance).ToList();
        Log.Write($"mod browser: {winner.Id} takes in {string.Join(", ", members.Select(member => member.Mod.Id).Where(id => id != winner.Id))}, which share its files; known versions {string.Join(", ", older.Prepend(latest).Select(version => version.Version))}");
        return winner with { Install = winner.Install with { Versions = older }, Known = [latest, .. older] };
    }

    /// <summary>
    /// Makes an entry of the website's mod out of its latest version.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <returns>The entry; <see langword="null"/> for a package that is neither a script nor a zip.</returns>
    private static BrowsedMod? FromSite(SiteMod mod)
    {
        var id = $"site:{mod.Slug}";
        var latest = mod.Versions[0];
        var files = InsidePatch(latest.Files);
        var zip = latest.Package.Name.EndsWith(".zip", StringComparison.OrdinalIgnoreCase);
        var script = latest.Package.Name.EndsWith(".rb", StringComparison.OrdinalIgnoreCase) && files.Count == 1;

        if (!zip && !script)
        {
            Log.Write($"mod browser leaves out {id}: its package {latest.Package.Name} is neither a zip nor a single script");
            return null;
        }

        var known = mod.Versions.Select(version => new ModVersion(version.Version, InsidePatch(version.Files))).ToList();
        var install = new CatalogMod(id, mod.Name, "link", latest.Version, files, known.Skip(1).ToList(), latest.Package.Url, Archive: zip);
        var changelog = latest.Changelog.TrimEnd();
        List<string> notes = changelog.Length > 0 ? changelog.Split('\n').Select(line => line.TrimEnd('\r')).Take(MaxNotes).ToList() : [];
        return new BrowsedMod(id, mod.Name, mod.Author, ModSource.Site, mod.Page, mod.Summary, notes, latest.Package.Size, install, zip ? string.Empty : $"Patch/{files.Keys.Single()}", latest.Package.Sha256, known, mod.Thumbnail);
    }

    /// <summary>
    /// Makes an entry of a mod of the relay's catalog.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <returns>The entry; <see langword="null"/> for a link to a script that names no single script.</returns>
    private static BrowsedMod? FromRelay(CatalogMod mod)
    {
        var id = $"relay:{mod.Key}";
        var files = InsidePatch(mod.Files);

        if (!mod.IsZip && files.Count != 1)
        {
            Log.Write($"mod browser leaves out {id}: it names no single script");
            return null;
        }

        var current = new ModVersion(mod.Version, files);
        var known = new List<ModVersion> { current };
        known.AddRange(mod.Versions.Select(version => new ModVersion(version.Version, InsidePatch(version.Files))).Where(version => !Same(version, current)));
        var page = !mod.IsUpload && RepositoryOf().Match(mod.FileUrl) is { Success: true } repository ? repository.Value : string.Empty;
        return new BrowsedMod(id, mod.Name, string.Empty, mod.IsUpload ? ModSource.Relay : ModSource.GitHub, page, string.Empty, [], 0,
            mod with { Files = files, Versions = known.Skip(1).ToList() }, mod.IsZip ? string.Empty : $"Patch/{files.Keys.Single()}", string.Empty, known);
    }

    /// <summary>
    /// Tells whether the mod browser may offer an entry, and logs why not.
    /// </summary>
    /// <param name="mod">The entry.</param>
    /// <returns>Whether it has files, none of them MGQ Online's own or outside Patch, in any known version.</returns>
    private static bool Offered(BrowsedMod mod)
    {
        if (mod.Install.Files.Count == 0)
        {
            Log.Write($"mod browser leaves out {mod.Id}: it has no files");
            return false;
        }

        foreach (var path in mod.Known.SelectMany(version => version.Files.Keys))
        {
            if (RefusalOf(path) is { } why)
            {
                Log.Write($"mod browser leaves out {mod.Id}: its file {path} {why}");
                return false;
            }
        }

        return true;
    }

    /// <summary>
    /// Tells why a path inside Patch may not be written.
    /// </summary>
    /// <param name="path">The path inside Patch, with forward slashes.</param>
    /// <returns>Why not, for the log; <see langword="null"/> when it may.</returns>
    internal static string? RefusalOf(string path)
    {
        var parts = path.Split('/');

        if (path.Contains(':', StringComparison.Ordinal) || parts.Any(part => part.Length == 0 || part.Trim().Trim('.').Length == 0))
        {
            return "would land outside the Patch folder";
        }

        // Windows drops a name's trailing dots and spaces, so "Multiplayer." is the same folder.
        return string.Equals(parts[0].TrimEnd('.', ' '), OwnFolder, StringComparison.OrdinalIgnoreCase) || string.Equals(parts[^1].TrimEnd('.', ' '), OwnScript, StringComparison.OrdinalIgnoreCase)
            ? "is MGQ Online's own"
            : null;
    }

    /// <summary>
    /// Reads files' paths as their paths inside Patch.
    /// </summary>
    /// <param name="files">Each file's hash by its path as a source names it.</param>
    /// <returns>Each file's hash by its path inside Patch.</returns>
    private static Dictionary<string, string> InsidePatch(IReadOnlyDictionary<string, string> files)
    {
        var inside = new Dictionary<string, string>(StringComparer.Ordinal);

        foreach (var (path, hash) in files)
        {
            inside[ModInstaller.PathInsidePatch(path)] = hash;
        }

        return inside;
    }

    /// <summary>
    /// Names the code files a mod's latest version ships, which tell one mod from another.
    /// </summary>
    /// <remarks>
    /// A README or a bundled copy of another mod's script is no sign of the same mod, so only the whole
    /// set of scripts and DLLs counts.
    /// </remarks>
    /// <param name="mod">The mod.</param>
    /// <returns>Its scripts' and DLLs' paths inside Patch, sorted and joined; empty for none.</returns>
    private static string CodeOf(BrowsedMod mod) =>
        string.Join('\n', mod.Install.Files.Keys
            .Where(path => path.EndsWith(".rb", StringComparison.OrdinalIgnoreCase) || path.EndsWith(".dll", StringComparison.OrdinalIgnoreCase))
            .Order(StringComparer.OrdinalIgnoreCase));

    /// <summary>
    /// Tells whether two versions are the same version with the same files.
    /// </summary>
    /// <param name="one">One version.</param>
    /// <param name="other">The other version.</param>
    /// <returns>Whether they are.</returns>
    private static bool Same(ModVersion one, ModVersion other) =>
        one.Version == other.Version && one.Files.Count == other.Files.Count
        && one.Files.All(file => other.Files.TryGetValue(file.Key, out var hash) && string.Equals(hash, file.Value, StringComparison.OrdinalIgnoreCase));

    /// <summary>
    /// Reads a version's leading numbers, such as 1, 5 and 2 of <c>v1.5.2</c>.
    /// </summary>
    /// <param name="version">The version.</param>
    /// <returns>The numbers; empty when it starts with none.</returns>
    private static int[] VersionNumbers(string version) =>
        LeadingNumbers().Match(version) is { Success: true } match
            ? match.Groups[1].Value.Split('.').Select(part => int.TryParse(part, NumberStyles.None, CultureInfo.InvariantCulture, out var number) ? number : int.MaxValue).ToArray()
            : [];

    /// <summary>
    /// Finds a group's representative, the entries of one mod sharing it.
    /// </summary>
    /// <param name="group">Each entry's link towards its representative.</param>
    /// <param name="index">The entry.</param>
    /// <returns>The representative's index.</returns>
    private static int RootOf(int[] group, int index)
    {
        while (group[index] != index)
        {
            index = group[index] = group[group[index]];
        }

        return index;
    }

    /// <summary>
    /// A version's leading numbers, after an optional "v".
    /// </summary>
    [GeneratedRegex(@"^\s*[vV]?(\d+(?:\.\d+)*)")]
    private static partial Regex LeadingNumbers();

    /// <summary>
    /// A GitHub repository's page at the start of a release file's address.
    /// </summary>
    [GeneratedRegex(@"^https://github\.com/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+", RegexOptions.IgnoreCase)]
    private static partial Regex RepositoryOf();

    /// <summary>
    /// Orders versions by their leading numbers, a missing number as 0, a version without numbers below every other.
    /// </summary>
    private sealed class VersionComparer : IComparer<int[]>
    {
        /// <summary>
        /// The comparer.
        /// </summary>
        public static VersionComparer Instance { get; } = new();

        /// <inheritdoc />
        public int Compare(int[]? x, int[]? y)
        {
            if (x is not { Length: > 0 } || y is not { Length: > 0 })
            {
                return (x?.Length > 0).CompareTo(y?.Length > 0);
            }

            for (var index = 0; index < Math.Max(x.Length, y.Length); index++)
            {
                var order = (index < x.Length ? x[index] : 0).CompareTo(index < y.Length ? y[index] : 0);

                if (order != 0)
                {
                    return order;
                }
            }

            return 0;
        }
    }
}
