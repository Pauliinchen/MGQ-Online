//----------------------------------------------------------------
//  BrowsedMod.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQParadox.Multiplayer.Mods;

/// <summary>
/// A mod the mod browser offers: the entries of the website and the relay that share a file made
/// one, named and installed after the entry that wins.
/// </summary>
/// <param name="Id">The mod's id: <c>site:</c> and the website's slug, or <c>relay:</c> and the relay's key.</param>
/// <param name="Name">The mod's name.</param>
/// <param name="Author">Who made it; empty for a mod of the relay.</param>
/// <param name="Source">Where it is installed from, see <see cref="ModSource"/>.</param>
/// <param name="Page">The mod's page on the website or its repository on GitHub; empty for none.</param>
/// <param name="Summary">What it does, in a sentence; empty for a mod of the relay.</param>
/// <param name="Notes">The lines of the latest version's changelog; none for a mod of the relay.</param>
/// <param name="Bytes">The size of the file it is downloaded as; 0 when unknown.</param>
/// <param name="Install">The latest version as <see cref="ModInstaller"/> installs it, every other known version among its versions.</param>
/// <param name="Target">Where a script goes, relative to the game's folder; empty for a zip.</param>
/// <param name="PackageHash">The SHA-256 of the file the website hands out; empty for a mod of the relay.</param>
/// <param name="Known">Every version known of the mod, the latest first, then the newest first, each with its files by their paths inside Patch.</param>
internal sealed record BrowsedMod(string Id, string Name, string Author, string Source, string Page, string Summary, IReadOnlyList<string> Notes, long Bytes, CatalogMod Install, string Target, string PackageHash, IReadOnlyList<ModVersion> Known)
{
    /// <summary>
    /// The latest version.
    /// </summary>
    public string Latest => Install.Version;
}

/// <summary>
/// Where a mod of the mod browser is installed from, as the game script reads it.
/// </summary>
internal static class ModSource
{
    /// <summary>
    /// The website.
    /// </summary>
    public const string Site = "site";

    /// <summary>
    /// A release on GitHub the relay's catalog links to.
    /// </summary>
    public const string GitHub = "github";

    /// <summary>
    /// A mod an admin uploaded to the relay.
    /// </summary>
    public const string Relay = "relay";
}

/// <summary>
/// How a mod of the mod browser stands in the game's Patch folder, as the game script reads it.
/// </summary>
internal static class ModStatus
{
    /// <summary>
    /// An older known version is installed.
    /// </summary>
    public const string Update = "update";

    /// <summary>
    /// The latest version is installed.
    /// </summary>
    public const string Current = "current";

    /// <summary>
    /// Some of its files are there, but no known version whole.
    /// </summary>
    public const string Changed = "changed";

    /// <summary>
    /// None of its files is there.
    /// </summary>
    public const string Available = "available";
}

/// <summary>
/// How a mod of the mod browser stands in the game's Patch folder.
/// </summary>
/// <param name="Status">See <see cref="ModStatus"/>.</param>
/// <param name="Installed">The known version installed whole; <see langword="null"/> when none is.</param>
internal sealed record ModState(string Status, ModVersion? Installed);
