//----------------------------------------------------------------
//  SettingsTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Shared the state of Player.ini with the lists of worlds
//                            - Took the Player.ini the other topics share
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
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
    /// <returns>{"values" => {setting => value}, the player key left out, "readable" => whether it was read or is missing, "notice" => what
    /// the notification box tells or nil, "name" => the name the others see or nil}.</returns>
    internal static RubyHash State(PlayerIni player)
    {
        var values = new RubyHash();
        foreach (var (key, value) in player.Settings)
        {
            values.Add(key, value);
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
    /// <param name="request">{setting => value, nil for one to remove}.</param>
    /// <returns>The changes in order.</returns>
    /// <exception cref="BridgeRequestException">A change names the player key, which only the DLL makes.</exception>
    private static List<KeyValuePair<string, string?>> ChangesOf(RubyValue request)
    {
        var changes = request.AsHash().Select(pair => new KeyValuePair<string, string?>(pair.Key.AsText(), pair.Value.IsNil ? null : pair.Value.AsText())).ToList();
        return changes.Any(change => change.Key == PlayerIni.KeySetting)
            ? throw new BridgeRequestException("The player key is kept by the DLL alone.")
            : changes;
    }

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
