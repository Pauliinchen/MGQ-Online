//----------------------------------------------------------------
//  SettingsTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Handed the chat's size, the slot to resume and the switches as values, read from the texts every release wrote, and took a whole number or a switch to keep
//      Paulinchen  2026-10-23: Shared the state of Player.ini with the lists of worlds
//                            - Took the Player.ini the other topics share
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.World;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The bridge topics of the files the scripts keep settings in: Player.ini, which only the DLL reads and writes (<see cref="PlayerIni"/>),
/// and the other key=value files, such as a world's world.ini (<see cref="IniFile"/>).
/// </summary>
/// <remarks>
/// Every Player.ini topic answers the settings as they stand afterwards, which the scripts keep as their copy, since some read a
/// setting every frame.
/// </remarks>
internal static class SettingsTopics
{
    /// <summary>
    /// The topic that answers Player.ini's settings as they stand.
    /// </summary>
    public const string StateTopic = "player.state";

    /// <summary>
    /// The topic that keeps and removes settings, {setting => value or nil}.
    /// </summary>
    public const string ChangeTopic = "player.change";

    /// <summary>
    /// The topic that takes the name Discord tells.
    /// </summary>
    public const string DiscordTopic = "player.discord";

    /// <summary>
    /// The topic that takes the name the player chose, an empty one to forget it.
    /// </summary>
    public const string NameTopic = "player.name";

    /// <summary>
    /// The topic that tells the worlds who plays.
    /// </summary>
    public const string ShareTopic = "player.share";

    /// <summary>
    /// The topic that reads another key=value file, {"path" => path from the game folder, "quiet" => whether a failure goes unlogged}.
    /// </summary>
    public const string ReadTopic = "ini.read";

    /// <summary>
    /// The topic that writes another key=value file, {"path" => path from the game folder, "values" => {key => value}}.
    /// </summary>
    public const string WriteTopic = "ini.write";

    /// <summary>
    /// The settings the scripts read as values, by key, each read from the text Player.ini keeps.
    /// </summary>
    private static readonly Dictionary<string, Func<string, RubyValue>> Values = new(StringComparer.Ordinal)
    {
        ["chat_size"] = SizeOf,
        ["resume_slot"] = SlotOf,
        ["sp_raid_bosses"] = FlagOf,
        ["leader_hud"] = FlagOf,
        ["sp_leader_hud"] = FlagOf,
        ["party_box_small"] = FlagOf,
        ["raid_bar_small"] = FlagOf,
        ["raid_bar_map"] = FlagOf,
        ["raid_bar_battle"] = FlagOf,
    };

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="player">The Player.ini the topics read and write.</param>
    internal static void Register(BridgeContext context, PlayerIni player)
    {
        context.Register(StateTopic, (_, _) => State(player));
        context.Register(ChangeTopic, (_, request) =>
        {
            var written = player.Change(ChangesOf(request));
            return With(State(player), "written", written);
        });
        context.Register(DiscordTopic, (_, request) =>
        {
            player.TellDiscordName(request.AsText());
            return State(player);
        });
        context.Register(NameTopic, (_, request) =>
        {
            var shared = player.ChooseName(request.AsText());
            return With(State(player), "shared", shared);
        });
        context.Register(ShareTopic, (_, _) =>
        {
            var shared = player.Share();
            return With(State(player), "shared", shared);
        });
        context.Register(ReadTopic, (_, request) => Read(request.AsHash()));
        context.Register(WriteTopic, (_, request) => Write(request.AsHash()));
    }

    /// <summary>
    /// Describes Player.ini as it stands.
    /// </summary>
    /// <param name="player">The Player.ini.</param>
    /// <returns>{"values" => {setting => value, see <see cref="Values"/>}, the player key left out, "readable" => whether it was read or is missing, "notice" => what
    /// the notification box tells or nil, "name" => the name the others see or nil}.</returns>
    internal static RubyHash State(PlayerIni player)
    {
        var values = new RubyHash();
        foreach (var (key, value) in player.Settings)
        {
            values.Add(key, Values.TryGetValue(key, out Func<string, RubyValue>? read) ? read(value) : value);
        }

        return new RubyHash { { "values", values }, { "readable", player.Readable }, { "notice", player.Notice }, { "name", player.Name } };
    }

    /// <summary>
    /// Adds a field to a reply.
    /// </summary>
    /// <param name="reply">The reply.</param>
    /// <param name="key">The field.</param>
    /// <param name="value">Its value.</param>
    /// <returns>The reply.</returns>
    private static RubyHash With(RubyHash reply, string key, bool value)
    {
        reply.Add(key, value);
        return reply;
    }

    /// <summary>
    /// Reads the changes of Player.ini a request names.
    /// </summary>
    /// <param name="request">{setting => value, a text, a whole number or true or false (written as 1 or 0), nil for one to remove}.</param>
    /// <returns>The changes in order.</returns>
    /// <exception cref="BridgeRequestException">A change names the player key, which only the DLL makes.</exception>
    private static List<KeyValuePair<string, string?>> ChangesOf(RubyValue request)
    {
        var changes = request.AsHash().Select(pair => new KeyValuePair<string, string?>(pair.Key.AsText(), pair.Value.IsNil ? null : pair.Value switch
            {
                RubyBool flag => flag.Flag ? "1" : "0",
                RubyInteger number => number.Value.ToString(CultureInfo.InvariantCulture),
                _ => pair.Value.AsText(),
            })).ToList();
        return changes.Any(change => change.Key == PlayerIni.KeySetting)
            ? throw new BridgeRequestException("The player key is kept by the DLL alone.")
            : changes;
    }

    /// <summary>
    /// Reads a size as Player.ini keeps it, <c>&lt;width&gt;x&lt;height&gt;</c>.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>[width, height], nil for a text that names no size of both above 0.</returns>
    private static RubyValue SizeOf(string text)
    {
        string[] parts = text.Split('x');
        return parts.Length == 2 && WorldFields.ToI(parts[0]) is > 0 and var width && WorldFields.ToI(parts[1]) is > 0 and var height ? new RubyArray { width, height } : RubyNil.Value;
    }

    /// <summary>
    /// Reads the slot a game kept for a restart was last saved to or loaded from: a number for a
    /// save slot, the name of an autosave.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The slot's number, else the text.</returns>
    private static RubyValue SlotOf(string text) =>
        text.Length > 0 && text.All(char.IsAsciiDigit) && long.TryParse(text, NumberStyles.None, CultureInfo.InvariantCulture, out long slot) ? slot : text;

    /// <summary>
    /// Reads a switch as Player.ini keeps it, 1 or 0.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>True for 1, false for 0, nil for another text.</returns>
    private static RubyValue FlagOf(string text) => text switch
    {
        "1" => RubyBool.True,
        "0" => RubyBool.False,
        _ => RubyNil.Value,
    };

    /// <summary>
    /// Reads another key=value file.
    /// </summary>
    /// <param name="request">The path and whether a failure goes unlogged.</param>
    /// <returns>{key => value} in the file's order, empty when it is missing; nil when it exists but could not be read.</returns>
    private static RubyValue? Read(RubyHash request)
    {
        var path = PathOf(request);
        var quiet = request.TryGetValue("quiet", out var flag) && flag.AsBool();
        if (IniFile.Load(ModFolder.GamePathOf(path), path, quiet) is not { } values)
        {
            return null;
        }

        var reply = new RubyHash();
        foreach (var (key, value) in values)
        {
            reply.Add(key, value);
        }

        return reply;
    }

    /// <summary>
    /// Writes another key=value file.
    /// </summary>
    /// <param name="request">The path and the values.</param>
    /// <returns>Whether the file was written.</returns>
    private static RubyValue Write(RubyHash request)
    {
        var path = PathOf(request);
        if (!request.TryGetValue("values", out var values))
        {
            throw new BridgeRequestException("The values are missing.");
        }

        var lines = values.AsHash().Select(pair => new KeyValuePair<string, string>(pair.Key.AsText(), pair.Value.AsText())).ToList();
        return IniFile.Write(ModFolder.GamePathOf(path), path, lines);
    }

    /// <summary>
    /// Reads the path of a file a request names.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The path from the game folder, as the scripts name it.</returns>
    /// <exception cref="BridgeRequestException">The path is missing or empty.</exception>
    private static string PathOf(RubyHash request) =>
        request.TryGetValue("path", out var path) && path.AsText() is { Length: > 0 } text ? text : throw new BridgeRequestException("The path is missing.");
}
