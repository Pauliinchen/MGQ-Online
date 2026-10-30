//----------------------------------------------------------------
//  ModTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Listed the scripts of the Patch folder without the parking
//      Paulinchen  2026-10-23: Shared the personal mods' keys with the parked mods
//                            - Handed the catalog to the mods check
//                            - Read a world's mods text
//                            - Handed out the mod catalog as plain values
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Mods;
using MGQParadox.Multiplayer.Mods;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// The bridge topics through which the scripts learn about the game's mods.
/// </summary>
internal static class ModTopics
{
    /// <summary>
    /// Lists every script in Patch, see <see cref="PatchScripts.List"/>: nothing in; an Array of
    /// [key, path relative to the game folder, name without ".rb"] out, nil when Patch could not be read.
    /// </summary>
    public const string Installed = "mods.installed";

    /// <summary>
    /// Hands out the relay's mod catalog as fetched with the world list, see <see cref="CatalogOf"/>:
    /// nothing in.
    /// </summary>
    public const string Catalog = "mods.catalog";

    /// <summary>
    /// Reads a world's mods as written, see <see cref="ModsText"/>: the text in; <c>names</c> (every mod
    /// without its mark, required ones first, then essential ones), <c>required</c> and <c>essential</c> out.
    /// </summary>
    public const string Text = "mods.text";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="scripts">Lists the scripts of the Patch folder once a topic is called.</param>
    /// <param name="directory">Gives the world directory, which holds the catalog, once a topic is called.</param>
    public static void Register(BridgeContext context, Func<IReadOnlyList<string>?> scripts, Func<WorldDirectory> directory)
    {
        context.Register(Installed, (_, _) => scripts() is { } found ? new RubyArray(found.Select(ScriptOf)) : null);
        context.Register(Catalog, (_, _) => CatalogOf(directory()));
        context.Register(Text, (_, request) => TextOf(request.IsNil ? null : request.AsText()));
    }

    /// <summary>
    /// Describes the relay's mod catalog for the game script.
    /// </summary>
    /// <param name="directory">The world directory, which fetched it.</param>
    /// <returns><c>state</c> ("loading", "ready", "failed" or "idle"), <c>error</c> (why it could not be fetched, nil while one is known), <c>mods</c> (each mod the relay could read, see <see cref="ModOf"/>, none before the first fetch) and <c>personal</c> (the keys of every mod the catalog marks personal and of their names).</returns>
    internal static RubyHash CatalogOf(WorldDirectory directory)
    {
        var (state, error, catalog) = directory.CatalogNow();
        IEnumerable<CatalogMod> readable = (catalog?.Mods ?? []).Where(IsReadable);
        IEnumerable<string> personal = catalog == null ? [] : PersonalKeys(catalog);

        return new RubyHash
        {
            { "state", state },
            { "error", error },
            { "mods", new RubyArray(readable.Select(ModOf)) },
            { "personal", new RubyArray(personal.Select(key => (RubyValue)key)) },
        };
    }

    /// <summary>
    /// Reads the catalog as the rules of MGQOnline.Game take it.
    /// </summary>
    /// <param name="catalog">The catalog.</param>
    /// <returns>The mods the relay could read and the keys of every personal mod and of its name.</returns>
    internal static (IReadOnlyList<CheckedMod> Mods, IReadOnlyList<string> Personal) Readable(ModCatalog catalog) =>
        ([.. catalog.Mods.Where(IsReadable).Select(CheckedOf)], [.. PersonalKeys(catalog)]);

    /// <summary>
    /// Tells whether the relay could read a mod of the catalog: a link it could not read yet has no
    /// version and no files and is listed for admins only.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <returns>Whether it could.</returns>
    private static bool IsReadable(CatalogMod mod) => mod.Version.Length > 0 && mod.Files.Count > 0;

    /// <summary>
    /// Lists the keys of every personal mod of the catalog and of its name.
    /// </summary>
    /// <param name="catalog">The catalog.</param>
    /// <returns>The keys, each once.</returns>
    internal static IEnumerable<string> PersonalKeys(ModCatalog catalog) =>
        catalog.Personal.SelectMany(mod => new[] { ModKey.Of(mod.Key), ModKey.Of(mod.Name) }).Where(key => key.Length > 0).Distinct(StringComparer.Ordinal);

    /// <summary>
    /// Takes a mod of the catalog as the check reads it.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <returns>The mod.</returns>
    private static CheckedMod CheckedOf(CatalogMod mod) => new(
        mod.Key,
        mod.Name,
        mod.ScriptKind,
        mod.Version,
        [.. mod.Files],
        [.. mod.Versions.Select(version => new KeyValuePair<string, IReadOnlyList<KeyValuePair<string, string>>>(version.Version, [.. version.Files]))],
        mod.OptionsVersion.Length > 0 ? mod.OptionsVersion : null);

    /// <summary>
    /// Answers <see cref="Text"/>.
    /// </summary>
    /// <param name="text">The mods as written, <see langword="null"/> for none.</param>
    /// <returns>The names, the required and the essential ones.</returns>
    internal static RubyHash TextOf(string? text) => new()
    {
        { "names", Texts(ModsText.Names(text)) },
        { "required", Texts(ModsText.Required(text)) },
        { "essential", Texts(ModsText.Essential(text)) },
    };

    /// <summary>
    /// Writes texts as an Array.
    /// </summary>
    /// <param name="texts">The texts.</param>
    /// <returns>The Array.</returns>
    internal static RubyArray Texts(IEnumerable<string> texts) => new(texts.Select(text => (RubyValue)text));

    /// <summary>
    /// Describes a mod of the catalog for the game script.
    /// </summary>
    /// <param name="mod">The mod.</param>
    /// <returns><c>key</c>, <c>name</c>, <c>kind</c> (see <see cref="CatalogMod.ScriptKind"/>), <c>version</c>, <c>files</c> (each current file's hash by its name or path), <c>versions</c> ([version, files] for each version the relay saw, newest first) and <c>options_version</c> (nil before an admin's game sent options).</returns>
    private static RubyValue ModOf(CatalogMod mod) => new RubyHash
    {
        { "key", mod.Key },
        { "name", mod.Name },
        { "kind", mod.ScriptKind },
        { "version", mod.Version },
        { "files", FilesOf(mod.Files) },
        { "versions", new RubyArray(mod.Versions.Select(version => (RubyValue)new RubyArray([version.Version, FilesOf(version.Files)]))) },
        { "options_version", mod.OptionsVersion.Length > 0 ? mod.OptionsVersion : null },
    };

    /// <summary>
    /// Writes files' hashes for the game script.
    /// </summary>
    /// <param name="files">Each file's hash by its name or path.</param>
    /// <returns>The hashes by name or path, in the catalog's order.</returns>
    private static RubyHash FilesOf(IReadOnlyDictionary<string, string> files)
    {
        RubyHash hashes = new();
        foreach (var (name, hash) in files)
        {
            hashes[name] = hash;
        }

        return hashes;
    }

    /// <summary>
    /// Describes an installed script for the game script.
    /// </summary>
    /// <param name="path">Its path relative to the game folder.</param>
    /// <returns>Its key, path and name.</returns>
    private static RubyValue ScriptOf(string path) =>
        new RubyArray([ModKey.Of(Path.GetFileName(path)), path, Path.GetFileNameWithoutExtension(path)]);
}
