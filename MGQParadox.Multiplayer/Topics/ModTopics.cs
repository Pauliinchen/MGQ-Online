//----------------------------------------------------------------
//  ModTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Dropped the relay's mod catalog, which the website's replaced
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
    /// Reads a world's mods as written, see <see cref="ModsText"/>: the text in; <c>names</c> (every mod
    /// without its mark, required ones first, then essential ones), <c>required</c> and <c>essential</c> out.
    /// </summary>
    public const string Text = "mods.text";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="scripts">Lists the scripts of the Patch folder once a topic is called.</param>
    public static void Register(BridgeContext context, Func<IReadOnlyList<string>?> scripts)
    {
        context.Register(Installed, (_, _) => scripts() is { } found ? new RubyArray(found.Select(ScriptOf)) : null);
        context.Register(Text, (_, request) => TextOf(request.IsNil ? null : request.AsText()));
    }

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
    /// Describes an installed script for the game script.
    /// </summary>
    /// <param name="path">Its path relative to the game folder.</param>
    /// <returns>Its key, path and name.</returns>
    private static RubyValue ScriptOf(string path) =>
        new RubyArray([ModKey.Of(Path.GetFileName(path)), path, Path.GetFileNameWithoutExtension(path)]);
}
