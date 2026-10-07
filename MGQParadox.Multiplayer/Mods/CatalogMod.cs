//----------------------------------------------------------------
//  CatalogMod.cs
//
//  Changelog:
//      Paulinchen  2026-10-06: Removed VersionOf, which only the game script needs
//                            - Knew the version whose Mod Config options the relay keeps
//                            - Told a link to a zip of a release from a link to a script
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQParadox.Multiplayer.Mods;

/// <summary>
/// A mod of the relay's mod catalog, see Relay/README.md.
/// </summary>
/// <param name="Key">The mod's key: its name in lower case, without ".rb", spaces, underscores and hyphens.</param>
/// <param name="Name">The mod's name.</param>
/// <param name="Kind">"link" for a script or zip the relay follows on GitHub, "upload" for a mod of several files an admin uploaded.</param>
/// <param name="Version">The current version.</param>
/// <param name="Files">The current files' hashes: a script's by its name, a zip's or an upload's by each file's path inside Patch.</param>
/// <param name="Versions">The versions the relay saw, newest first, the current one among them.</param>
/// <param name="FileUrl">A link mod's release file on GitHub; empty for an upload.</param>
/// <param name="Archive">Whether a link mod's release file is a zip laid out as in Patch rather than a script.</param>
/// <param name="OptionsVersion">The version whose Mod Config options the relay keeps; empty before an admin's game sent any.</param>
internal sealed record CatalogMod(string Key, string Name, string Kind, string Version, IReadOnlyDictionary<string, string> Files, IReadOnlyList<ModVersion> Versions, string FileUrl, bool Archive = false, string OptionsVersion = "")
{
    /// <summary>
    /// Whether an admin uploaded the mod's files, which the relay hands out; else it is on GitHub.
    /// </summary>
    public bool IsUpload => Kind == "upload";

    /// <summary>
    /// Whether the mod comes as a zip whose files go to their paths inside Patch: an upload, or a link to a zip.
    /// </summary>
    public bool IsZip => IsUpload || Archive;

    /// <summary>
    /// The kind as the game script tells mods apart: "zip" for a link to a zip, else <see cref="Kind"/>.
    /// </summary>
    public string ScriptKind => !IsUpload && Archive ? "zip" : Kind;
}

/// <summary>
/// A version of a mod as the relay saw it.
/// </summary>
/// <param name="Version">The version.</param>
/// <param name="Files">Its files' hashes.</param>
internal sealed record ModVersion(string Version, IReadOnlyDictionary<string, string> Files);
