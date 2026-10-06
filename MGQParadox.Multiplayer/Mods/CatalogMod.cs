//----------------------------------------------------------------
//  CatalogMod.cs
//
//  Changelog:
//      Paulinchen  2026-10-06: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;

namespace MGQParadox.Multiplayer.Mods;

/// <summary>
/// A mod of the relay's mod catalog, see Relay/README.md.
/// </summary>
/// <param name="Key">The mod's key: its name in lower case, without ".rb", spaces, underscores and hyphens.</param>
/// <param name="Name">The mod's name.</param>
/// <param name="Kind">"link" for a script the relay follows on GitHub, "upload" for a mod of several files an admin uploaded.</param>
/// <param name="Version">The current version.</param>
/// <param name="Files">The current files' hashes: a link mod's by the script's name, an upload's by each file's path inside Patch.</param>
/// <param name="Versions">The versions the relay saw, newest first, the current one among them.</param>
/// <param name="FileUrl">A link mod's release file on GitHub; empty for an upload.</param>
internal sealed record CatalogMod(string Key, string Name, string Kind, string Version, IReadOnlyDictionary<string, string> Files, IReadOnlyList<ModVersion> Versions, string FileUrl)
{
    /// <summary>
    /// Whether an admin uploaded the mod's files, which the relay hands out; else it is a script on GitHub.
    /// </summary>
    public bool IsUpload => Kind == "upload";

    /// <summary>
    /// Names the version whose files a copy's hashes are.
    /// </summary>
    /// <param name="hashes">The copy's hashes, by the same names as <see cref="Files"/>.</param>
    /// <returns>The version, <see langword="null"/> when the copy is none the relay saw.</returns>
    public string? VersionOf(IReadOnlyDictionary<string, string> hashes) =>
        Versions.FirstOrDefault(version => version.Files.Count == hashes.Count && version.Files.All(file => hashes.TryGetValue(file.Key, out var hash) && hash == file.Value))?.Version;
}

/// <summary>
/// A version of a mod as the relay saw it.
/// </summary>
/// <param name="Version">The version.</param>
/// <param name="Files">Its files' hashes.</param>
internal sealed record ModVersion(string Version, IReadOnlyDictionary<string, string> Files);
