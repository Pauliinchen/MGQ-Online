//----------------------------------------------------------------
//  ModPickTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-10-30: Listed the scripts of the Patch folder without the parking
//      Paulinchen  2026-10-23: Named each mod's label and colour
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Mods;
using MGQOnline.Game.Worlds;

namespace MGQOnline.Multiplayer.Topics;

/// <summary>
/// The bridge topics of the mod picker, see <see cref="ModPick"/>: the DLL keeps the picker that is
/// open, the scripts its cursor and drawing.
/// </summary>
internal static class ModPickTopics
{
    /// <summary>
    /// Opens the picker on a world's mods and the scripts in Patch: <c>text</c> (the mods as written)
    /// in; the picker out, see <see cref="ViewOf"/>.
    /// </summary>
    public const string Open = "modpick.open";

    /// <summary>
    /// Changes the open picker: <c>do</c> (<c>toggle</c>, <c>mark</c>, <c>set</c>, <c>remove</c>,
    /// <c>add</c>, <c>list_all</c> or <c>unlist_all</c>) with <c>index</c>, <c>state</c> or <c>name</c>
    /// as it needs in; <c>answer</c> (why it cannot, nil when it was done; true or false for
    /// <c>remove</c>) and <c>pick</c> out, nil while none is open.
    /// </summary>
    public const string Act = "modpick.act";

    /// <summary>
    /// Closes the picker: nothing in, nothing out.
    /// </summary>
    public const string Close = "modpick.close";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="scripts">Lists the scripts of the Patch folder.</param>
    public static void Register(BridgeContext context, Func<IReadOnlyList<string>?> scripts)
    {
        ModPick? pick = null;
        context.Register(Open, (_, request) =>
        {
            pick = new ModPick(request.AsHash()["text"].IsNil ? null : request.AsHash()["text"].AsText(), InstalledNames(scripts()), ModKey.Of);
            return ViewOf(pick);
        });
        context.Register(Act, (_, request) => pick == null ? null : new RubyHash { { "answer", Run(pick, request.AsHash()) }, { "pick", ViewOf(pick) } });
        context.Register(Close, (_, _) =>
        {
            pick = null;
            return null;
        });
    }

    /// <summary>
    /// Lists the mods the Patch folder holds for the picker: each script once by its file's name,
    /// without the scripts every player has.
    /// </summary>
    /// <param name="scripts">The scripts' paths relative to the game folder, <see langword="null"/> when the folder could not be read.</param>
    /// <returns>The names, sorted by their ASCII letters in lower case; none when the folder could not be read.</returns>
    internal static IReadOnlyList<string> InstalledNames(IReadOnlyList<string>? scripts) =>
        [.. (scripts ?? [])
            .Select(path => Path.GetFileName(path))
            .Where(file => !SessionMods.SharedKeys.Contains(ModKey.Of(file)))
            .DistinctBy(ModKey.Of, StringComparer.Ordinal)
            .Select(Path.GetFileNameWithoutExtension)
            .OfType<string>()
            .OrderBy(name => Encoding.UTF8.GetBytes(WorldEntries.AsciiLower(name)), Comparer<byte[]>.Create((x, y) => ((ReadOnlySpan<byte>)x).SequenceCompareTo(y)))];

    /// <summary>
    /// Describes the picker for the scripts.
    /// </summary>
    /// <param name="pick">The picker.</param>
    /// <returns><c>entries</c> ([name, state, installed, label, color] each, the state and the label one of
    /// "unlisted", "listed", "required" and "essential", see <see cref="ModPickStates"/>), <c>text</c> (the mods as a world keeps them) and <c>all_listed</c>.</returns>
    internal static RubyHash ViewOf(ModPick pick) => new()
    {
        { "entries", new RubyArray(pick.Entries.Select(entry => (RubyValue)new RubyArray([entry.Name, ModPickStates.NameOf(entry.State), entry.Installed, ModPickStates.NameOf(entry.State), ModPickStates.ColorOf(entry.State)]))) },
        { "text", pick.Text() },
        { "all_listed", pick.AllListed },
    };

    /// <summary>
    /// Runs one change of the picker.
    /// </summary>
    /// <param name="pick">The picker.</param>
    /// <param name="request">The change.</param>
    /// <returns>Its answer.</returns>
    /// <exception cref="BridgeRequestException">The change is unknown or names a mod the picker lacks.</exception>
    private static RubyValue Run(ModPick pick, RubyHash request)
    {
        string action = request["do"].AsText();
        int index = request["index"].IsNil ? -1 : request["index"].AsInt();
        if (action is "toggle" or "mark" or "set" or "remove" && (index < 0 || index >= pick.Entries.Count))
        {
            throw new BridgeRequestException($"The picker has no mod {index}.");
        }

        return action switch
        {
            "toggle" => pick.Toggle(index),
            "mark" => pick.Mark(index, StateOf(request["state"].AsText())),
            "set" => pick.Set(index, StateOf(request["state"].AsText())),
            "remove" => pick.Remove(index),
            "add" => pick.Add(request["name"].AsText()),
            "list_all" => pick.ListAll(),
            "unlist_all" => Unlisted(pick),
            _ => throw new BridgeRequestException($"The picker cannot {action}."),
        };
    }

    /// <summary>
    /// Unlists every installed mod, which always fits.
    /// </summary>
    /// <param name="pick">The picker.</param>
    /// <returns>Nil.</returns>
    private static RubyValue Unlisted(ModPick pick)
    {
        pick.UnlistAll();
        return RubyNil.Value;
    }

    /// <summary>
    /// Reads a state the scripts name.
    /// </summary>
    /// <param name="name">Its name.</param>
    /// <returns>The state.</returns>
    /// <exception cref="BridgeRequestException">No state has that name.</exception>
    private static ModPickState StateOf(string name) => name switch
    {
        "unlisted" => ModPickState.Unlisted,
        "listed" => ModPickState.Listed,
        "required" => ModPickState.Required,
        "essential" => ModPickState.Essential,
        _ => throw new BridgeRequestException($"There is no state {name}."),
    };
}
