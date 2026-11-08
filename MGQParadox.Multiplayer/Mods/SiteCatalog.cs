//----------------------------------------------------------------
//  SiteCatalog.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Mods;

namespace MGQParadox.Multiplayer.Mods;

/// <summary>
/// A mod of the website's catalog, as far as worlds need it.
/// </summary>
/// <param name="Slug">Its slug, which names it on the website.</param>
/// <param name="Name">Its name.</param>
/// <param name="Personal">Whether the website marks it personal, so a world that turns other mods off never turns it off.</param>
/// <param name="Versions">The files' hashes of each version, by their paths inside Patch.</param>
internal sealed record SiteMod(string Slug, string Name, bool Personal, IReadOnlyDictionary<string, IReadOnlyList<KeyValuePair<string, string>>> Versions);

/// <summary>
/// The website's mod catalog (<c>GET /api/mods</c>) as worlds read it: which mods are personal, and
/// the files of each version the battle server downloads.
/// </summary>
/// <param name="Mods">The mods.</param>
internal sealed record SiteCatalog(IReadOnlyList<SiteMod> Mods)
{
    /// <summary>
    /// The website: mgqonline.org, or the one the environment variable MGQ_MODS_SITE names, as the
    /// Mod Framework reads it.
    /// </summary>
    public static readonly Uri Website = new(Environment.GetEnvironmentVariable("MGQ_MODS_SITE") ?? "https://mgqonline.org");

    /// <summary>
    /// The platform whose packages the game and the battle server install.
    /// </summary>
    public const string Platform = "pc";

    /// <summary>
    /// The query that asks the catalog for the schema that lists each platform's package.
    /// </summary>
    public const string SchemaQuery = "?schema=3";

    /// <summary>
    /// The folder a package may hold its files in, read as Patch itself.
    /// </summary>
    private const string PatchPrefix = "Patch/";

    /// <summary>
    /// Lists the keys a world's mods name the personal mods by: each one's slug and name, and the
    /// names in Patch and for the player of the installed copies of them.
    /// </summary>
    /// <param name="installed">The mods the Mod Framework lists, <see langword="null"/> while unknown.</param>
    /// <returns>The keys, each once.</returns>
    public IReadOnlyList<string> PersonalKeys(IReadOnlyList<InstalledMod>? installed)
    {
        List<SiteMod> personal = [.. Mods.Where(mod => mod.Personal)];
        IEnumerable<string> own = personal.SelectMany(mod => new[] { mod.Slug, mod.Name });
        IEnumerable<string> copies = (installed ?? []).Where(mod => personal.Any(site => site.Slug == mod.Slug)).SelectMany(mod => new[] { mod.Name, mod.Title });
        return [.. own.Concat(copies).Select(ModKey.Of).Where(key => key.Length > 0).Distinct(StringComparer.Ordinal)];
    }

    /// <summary>
    /// Finds the files of a mod's version.
    /// </summary>
    /// <param name="slug">The mod's slug.</param>
    /// <param name="version">The version.</param>
    /// <returns>Each file's hash by its path inside Patch, <see langword="null"/> when the catalog lacks the version.</returns>
    public IReadOnlyList<KeyValuePair<string, string>>? FilesOf(string slug, string version) =>
        Mods.FirstOrDefault(mod => mod.Slug == slug) is { } mod && mod.Versions.TryGetValue(version, out var files) ? files : null;

    /// <summary>
    /// Reads the catalog's answer.
    /// </summary>
    /// <param name="root">The answer's root, with <c>mods</c>.</param>
    /// <returns>The catalog.</returns>
    /// <exception cref="KeyNotFoundException">The answer lists no mods.</exception>
    public static SiteCatalog Read(JsonElement root)
    {
        List<SiteMod> mods = [];
        foreach (JsonElement mod in root.GetProperty("mods").EnumerateArray())
        {
            if (mod.ValueKind != JsonValueKind.Object || Text(mod, "slug") is not { Length: > 0 } slug)
            {
                continue;
            }

            Dictionary<string, IReadOnlyList<KeyValuePair<string, string>>> versions = new(StringComparer.Ordinal);
            if (mod.TryGetProperty("versions", out JsonElement listed) && listed.ValueKind == JsonValueKind.Array)
            {
                foreach (JsonElement version in listed.EnumerateArray().Where(version => version.ValueKind == JsonValueKind.Object))
                {
                    versions[Text(version, "version")] = FilesOf(version);
                }
            }

            mods.Add(new SiteMod(slug, Text(mod, "name"), mod.TryGetProperty("personal", out JsonElement personal) && personal.ValueKind == JsonValueKind.True, versions));
        }

        return new SiteCatalog(mods);
    }

    /// <summary>
    /// Reads a version's files: those of its package for <see cref="Platform"/>, else of its one package.
    /// </summary>
    /// <param name="version">The version as listed.</param>
    /// <returns>Each file's hash by its path inside Patch, in the listed order.</returns>
    private static IReadOnlyList<KeyValuePair<string, string>> FilesOf(JsonElement version)
    {
        JsonElement files = default;
        if (version.TryGetProperty("packages", out JsonElement packages) && packages.ValueKind == JsonValueKind.Array)
        {
            JsonElement package = packages.EnumerateArray().FirstOrDefault(each => each.ValueKind == JsonValueKind.Object && Text(each, "platform") == Platform);
            files = package.ValueKind == JsonValueKind.Object && package.TryGetProperty("files", out JsonElement found) ? found : default;
        }
        else if (version.TryGetProperty("files", out JsonElement found))
        {
            files = found;
        }

        return files.ValueKind != JsonValueKind.Array ? []
            : [.. files.EnumerateArray().Where(file => file.ValueKind == JsonValueKind.Object)
                .Select(file => new KeyValuePair<string, string>(PathInsidePatch(Text(file, "path")), Text(file, "sha256").ToLowerInvariant()))];
    }

    /// <summary>
    /// Reads a package's path as the path inside Patch it goes to, as the Mod Framework installs it.
    /// </summary>
    /// <param name="path">The path in the package.</param>
    /// <returns>The path with forward slashes, without a leading Patch folder.</returns>
    private static string PathInsidePatch(string path)
    {
        string forward = path.Replace('\\', '/');
        return forward.StartsWith(PatchPrefix, StringComparison.OrdinalIgnoreCase) ? forward[PatchPrefix.Length..] : forward;
    }

    /// <summary>
    /// Reads a text field.
    /// </summary>
    /// <param name="element">The object.</param>
    /// <param name="name">The field.</param>
    /// <returns>The text, empty when missing or of another kind.</returns>
    private static string Text(JsonElement element, string name) =>
        element.TryGetProperty(name, out JsonElement value) && value.ValueKind == JsonValueKind.String ? value.GetString() ?? string.Empty : string.Empty;
}
