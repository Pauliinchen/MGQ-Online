//----------------------------------------------------------------
//  SceneChecks.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Numerics;
using System.Text;
using MGQOnline.Game.Battles.Wire;
using MGQOnline.Game.Ruby;

namespace MGQOnline.Game.Scene;

/// <summary>
/// What a viewer refuses of another game's changes of the story's scene before the game's own facts
/// are asked, as coop_scene.rbx checked them: a change this game has no such change for, arguments
/// the game cannot take (it keeps them and uses them each frame, where a wrong one ends the game
/// outside every rescue), a name that is no plain file name, and a change bound to the teller's map
/// while the player is still on the way. Whether this game has the picture, the event, the tileset
/// or the sound named stays the script's.
/// </summary>
public static class SceneChecks
{
    /// <summary>
    /// The highest number of a picture the game's screens hold.
    /// </summary>
    public const int MaxPicture = 100;

    /// <summary>
    /// The largest place, zoom, opacity or turning speed of a picture, either way; a larger one or
    /// Infinity raises in the game's sprites every frame.
    /// </summary>
    public const int MostAmount = 100_000;

    /// <summary>
    /// The longest change of a picture or the screen, in frames: ten minutes.
    /// </summary>
    public const int MostFrames = 36_000;

    /// <summary>
    /// The strongest and fastest shake of the screen, the editor's own range.
    /// </summary>
    public const int MostShake = 9;

    /// <summary>
    /// The longest file name of a sound.
    /// </summary>
    public const int LongestFileName = 100;

    /// <summary>
    /// How much of a refused name a refusal shows.
    /// </summary>
    public const int NameShown = 40;

    /// <summary>
    /// The refusal of a change this game has no such change for.
    /// </summary>
    public const string NoSuchChange = "no such change";

    /// <summary>
    /// The refusal of a picture's change this game has no such change or picture for.
    /// </summary>
    public const string NoSuchPicture = "no such change or picture";

    /// <summary>
    /// The refusal of a screen's change this game has no such change for.
    /// </summary>
    public const string NoSuchScreenChange = "this game's screen has no such change";

    /// <summary>
    /// The refusal of arguments this game cannot take.
    /// </summary>
    public const string BadArguments = "arguments this game cannot take";

    /// <summary>
    /// The refusal of a sound call this game has no such call for.
    /// </summary>
    public const string NoSuchCall = "no such call";

    /// <summary>
    /// The refusal of a camera place that is none.
    /// </summary>
    public const string NoPlace = "no place";

    /// <summary>
    /// The refusal of a message of changes that holds more than <see cref="SceneQueue.MaxBatch"/>
    /// or anything but changes.
    /// </summary>
    public const string BadBatch = "more than 256 or not changes";

    /// <summary>
    /// The kinds of argument a change takes.
    /// </summary>
    private enum ArgKind
    {
        /// <summary>A text.</summary>
        Name,

        /// <summary>A whole origin.</summary>
        Origin,

        /// <summary>A finite number within <see cref="MostAmount"/> either way.</summary>
        Amount,

        /// <summary>A blend type of 0 to 2.</summary>
        Blend,

        /// <summary>Whole frames within <see cref="MostFrames"/>.</summary>
        Frames,

        /// <summary>A tone.</summary>
        Tone,

        /// <summary>A color.</summary>
        Color,

        /// <summary>A shake within <see cref="MostShake"/>.</summary>
        Shake,
    }

    /// <summary>
    /// The kinds of argument each change of a picture takes, after the picture's number.
    /// </summary>
    private static readonly Dictionary<string, ArgKind[]> PictureArgs = new()
    {
        ["show"] = [ArgKind.Name, ArgKind.Origin, ArgKind.Amount, ArgKind.Amount, ArgKind.Amount, ArgKind.Amount, ArgKind.Amount, ArgKind.Blend],
        ["move"] = [ArgKind.Origin, ArgKind.Amount, ArgKind.Amount, ArgKind.Amount, ArgKind.Amount, ArgKind.Amount, ArgKind.Blend, ArgKind.Frames],
        ["rotate"] = [ArgKind.Amount],
        ["start_tone_change"] = [ArgKind.Tone, ArgKind.Frames],
        ["erase"] = [],
    };

    /// <summary>
    /// The kinds of argument each change of the screen takes.
    /// </summary>
    private static readonly Dictionary<string, ArgKind[]> ScreenArgs = new()
    {
        ["start_fadeout"] = [ArgKind.Frames],
        ["start_fadein"] = [ArgKind.Frames],
        ["start_tone_change"] = [ArgKind.Tone, ArgKind.Frames],
        ["start_flash"] = [ArgKind.Color, ArgKind.Frames],
        ["start_shake"] = [ArgKind.Shake, ArgKind.Shake, ArgKind.Frames],
        ["od_fadein"] = [],
        ["od_fadeout"] = [],
    };

    /// <summary>
    /// What the story does to an event.
    /// </summary>
    private static readonly HashSet<string> EventMethods = ["route", "animation", "balloon", "erase"];

    /// <summary>
    /// The game's Audio calls the story reaches.
    /// </summary>
    private static readonly HashSet<string> AudioCalls = ["bgm_play", "bgm_stop", "bgm_fade", "bgs_play", "bgs_stop", "bgs_fade", "me_play", "me_stop", "me_fade", "se_play", "se_stop"];

    /// <summary>
    /// The changes of the map's look.
    /// </summary>
    private static readonly HashSet<string> MapLooks = ["tileset", "battleback", "parallax"];

    /// <summary>
    /// The characters a file name never holds.
    /// </summary>
    private static readonly HashSet<char> ForbiddenInFileName = ['/', '\\', ':', '*', '?', '"', '<', '>', '|'];

    /// <summary>
    /// Tells whether a change is bound to the teller's map and the player is still on the way
    /// there: an event is named by its id on that map, which another map's event may share, the
    /// camera's place and the map's look are that map's, and a fanfare or sound effect is over
    /// before the player arrives.
    /// </summary>
    /// <param name="kind">What changes.</param>
    /// <param name="map">The teller's map it happened on.</param>
    /// <param name="here">The player's map.</param>
    /// <returns>The refusal, <see langword="null"/> when the change reaches the player.</returns>
    public static string? OnTheWay(string kind, int map, int here)
    {
        ArgumentNullException.ThrowIfNull(kind);
        if (map == here)
        {
            return null;
        }

        bool bound = kind.StartsWith("event.", StringComparison.Ordinal) || kind == "map.camera" || MapLooks.Contains(WithoutMapPrefix(kind))
            || kind.StartsWith("audio.me_", StringComparison.Ordinal) || kind.StartsWith("audio.se_", StringComparison.Ordinal);
        return bound ? $"the player is still on the way, on map {here}" : null;
    }

    /// <summary>
    /// Tells what a viewer refuses of a change before the game's facts are asked.
    /// </summary>
    /// <param name="kind">What changes, such as "picture.show".</param>
    /// <param name="args">Its arguments.</param>
    /// <returns>The refusal, <see langword="null"/> when the change passes.</returns>
    public static string? Refusal(string kind, IReadOnlyList<WireValue> args)
    {
        ArgumentNullException.ThrowIfNull(kind);
        ArgumentNullException.ThrowIfNull(args);
        int dot = kind.IndexOf('.', StringComparison.Ordinal);
        string target = dot < 0 ? kind : kind[..dot];
        string? method = dot < 0 ? null : kind[(dot + 1)..];
        return target switch
        {
            "picture" => PictureRefusal(method, args),
            "screen" => ScreenRefusal(method, args),
            "player" => method == "transparent" ? null : NoSuchChange,
            "story" => method == "values" ? null : NoSuchChange,
            "event" => method is not null && EventMethods.Contains(method) ? null : NoSuchChange,
            "audio" => AudioRefusal(method, args),
            "map" => MapRefusal(method, args),
            _ => NoSuchChange,
        };
    }

    /// <summary>
    /// Tells what a viewer refuses of a picture's change: a change or a picture number the game has
    /// not, arguments it cannot take, or a name that is no picture's file name.
    /// </summary>
    /// <param name="method">What happens to the picture, such as "show".</param>
    /// <param name="args">The picture's number, then the method's arguments.</param>
    /// <returns>The refusal, <see langword="null"/> when the change passes.</returns>
    public static string? PictureRefusal(string? method, IReadOnlyList<WireValue> args)
    {
        ArgumentNullException.ThrowIfNull(args);
        if (method is null || !PictureArgs.TryGetValue(method, out ArgKind[]? kinds))
        {
            return NoSuchPicture;
        }

        BigInteger? number = ToI(args.Count > 0 ? args[0] : WireNil.Value);
        if (number is null || number <= 0 || number > MaxPicture)
        {
            return NoSuchPicture;
        }

        if (!ArgsFit(kinds, args.Skip(1).ToList()))
        {
            return BadArguments;
        }

        if (method == "show" && !IsPictureName(((WireString)args[1]).Text))
        {
            return $"'{Shown(((WireString)args[1]).Text)}' is no picture's file name";
        }

        return null;
    }

    /// <summary>
    /// Tells what a viewer refuses of a change of the screen: a change the game has not, or
    /// arguments it cannot take.
    /// </summary>
    /// <param name="method">What happens to the screen, such as "start_fadeout".</param>
    /// <param name="args">The method's arguments.</param>
    /// <returns>The refusal, <see langword="null"/> when the change passes.</returns>
    public static string? ScreenRefusal(string? method, IReadOnlyList<WireValue> args)
    {
        ArgumentNullException.ThrowIfNull(args);
        if (method is null || !ScreenArgs.TryGetValue(method, out ArgKind[]? kinds))
        {
            return NoSuchScreenChange;
        }

        return ArgsFit(kinds, args) ? null : BadArguments;
    }

    /// <summary>
    /// Reads a message of several changes.
    /// </summary>
    /// <param name="entries">The message's values.</param>
    /// <returns>Each change's kind and arguments; <see langword="null"/> for more than
    /// <see cref="SceneQueue.MaxBatch"/> or anything but changes, which a viewer drops whole.</returns>
    public static IReadOnlyList<(string Kind, IReadOnlyList<WireValue> Args)>? Batch(IReadOnlyList<WireValue> entries)
    {
        ArgumentNullException.ThrowIfNull(entries);
        if (entries.Count > SceneQueue.MaxBatch)
        {
            return null;
        }

        var changes = new List<(string Kind, IReadOnlyList<WireValue> Args)>();
        foreach (WireValue entry in entries)
        {
            if (entry is not WireList { Items: [WireString kind, WireList args] })
            {
                return null;
            }

            changes.Add((kind.Text, args.Items));
        }

        return changes;
    }

    /// <summary>
    /// Reports whether a text is a picture's file name: parts of ASCII word characters, hyphens and
    /// spaces, with single dots between them, such as "ev_aguni._hb1", and never a path.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>Whether it is.</returns>
    public static bool IsPictureName(string text)
    {
        ArgumentNullException.ThrowIfNull(text);
        return text.Split('.').All(part => part.Length > 0 && part.All(character => character == '-' || character == ' ' || (character < 128 && RubyAscii.IsWord((byte)character))));
    }

    /// <summary>
    /// Reports whether a text is a sound's file name: 1 to <see cref="LongestFileName"/> characters,
    /// no ".." and none of the characters a path or a device needs.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>Whether it is.</returns>
    public static bool IsFileName(string text)
    {
        ArgumentNullException.ThrowIfNull(text);
        int length = text.EnumerateRunes().Count();
        return length >= 1 && length <= LongestFileName && !text.Contains("..", StringComparison.Ordinal) && !text.Any(ForbiddenInFileName.Contains);
    }

    /// <summary>
    /// Tells what a viewer refuses of a sound: a call the game has not, or a name that is no sound's
    /// file name.
    /// </summary>
    /// <param name="call">The Audio call, such as "se_play".</param>
    /// <param name="args">Its arguments, the file first for a play.</param>
    /// <returns>The refusal, <see langword="null"/> when the call passes.</returns>
    private static string? AudioRefusal(string? call, IReadOnlyList<WireValue> args)
    {
        if (call is null || !AudioCalls.Contains(call))
        {
            return NoSuchCall;
        }

        if (!call.EndsWith("_play", StringComparison.Ordinal))
        {
            return null;
        }

        string name = args.Count > 0 ? TextOf(args[0]) : "";
        return IsFileName(name) ? null : $"'{Shown(name)}' is no sound's file name";
    }

    /// <summary>
    /// Tells what a viewer refuses of a change of the map: a camera place that is no two numbers, or
    /// a change the game has not; the map's look and zoom are the game's facts.
    /// </summary>
    /// <param name="method">What changes, such as "camera".</param>
    /// <param name="args">Its arguments.</param>
    /// <returns>The refusal, <see langword="null"/> when the change passes.</returns>
    private static string? MapRefusal(string? method, IReadOnlyList<WireValue> args)
    {
        if (method == "camera")
        {
            return args.Count == 2 && args.All(value => value is WireInteger or WireFloat) ? null : NoPlace;
        }

        return method is not null && (MapLooks.Contains(method) || method == "zoom") ? null : NoSuchChange;
    }

    /// <summary>
    /// Reports whether arguments are ones the game takes: as many as the change takes, each of its
    /// kind and within the limits.
    /// </summary>
    /// <param name="kinds">The kind of each argument.</param>
    /// <param name="args">The arguments.</param>
    /// <returns>Whether they are.</returns>
    private static bool ArgsFit(ArgKind[] kinds, IReadOnlyList<WireValue> args) => kinds.Length == args.Count && kinds.Zip(args).All(pair => ArgFits(pair.First, pair.Second));

    /// <summary>
    /// Reports whether one argument is of its kind and within the limits.
    /// </summary>
    /// <param name="kind">The kind.</param>
    /// <param name="value">The argument.</param>
    /// <returns>Whether it is.</returns>
    private static bool ArgFits(ArgKind kind, WireValue value) => kind switch
    {
        ArgKind.Amount => Number(value) is { } amount && Math.Abs(amount) <= MostAmount,
        ArgKind.Frames => Number(value) is { } frames && frames == Math.Floor(frames) && frames >= 0 && frames <= MostFrames,
        ArgKind.Origin => value is WireInteger,
        ArgKind.Blend => value is WireInteger { Value: var blend } && blend >= 0 && blend <= 2,
        ArgKind.Tone => value is WireTone,
        ArgKind.Color => value is WireColor,
        ArgKind.Shake => Number(value) is { } shake && shake >= 0 && shake <= MostShake,
        ArgKind.Name => value is WireString,
        _ => false,
    };

    /// <summary>
    /// Reads a whole or finite number.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The number, <see langword="null"/> for none; a whole number past a double's range
    /// reads as infinite.</returns>
    private static double? Number(WireValue value) => value switch
    {
        WireInteger integer => (double)integer.Value,
        WireFloat { Value: var number } when double.IsFinite(number) => number,
        _ => null,
    };

    /// <summary>
    /// Reads a value as Ruby's to_i does: a whole number as itself, a finite float cut to its whole
    /// part, a text as far as it starts with a number, nil as 0.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The number, <see langword="null"/> for a value that has no to_i.</returns>
    private static BigInteger? ToI(WireValue value) => value switch
    {
        WireInteger integer => integer.Value,
        WireFloat { Value: var number } when double.IsFinite(number) => new BigInteger(Math.Truncate(number)),
        WireString text => RubyNumbers.ToI(Encoding.UTF8.GetBytes(text.Text)),
        WireNil => BigInteger.Zero,
        _ => null,
    };

    /// <summary>
    /// Reads a value as Ruby's to_s does for a file name: a text as itself, a number as Ruby writes
    /// it, nil as "".
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The text; a list, tone, color or anything else gives a text no file is named.</returns>
    private static string TextOf(WireValue value) => value switch
    {
        WireString text => text.Text,
        WireInteger integer => integer.Value.ToString(),
        WireFloat number => RubyNumbers.FloatToS(number.Value),
        WireBool flag => flag.Flag ? "true" : "false",
        WireNil => "",
        _ => "..",
    };

    /// <summary>
    /// Cuts a refused name to what a refusal shows.
    /// </summary>
    /// <param name="name">The name.</param>
    /// <returns>Its first <see cref="NameShown"/> characters.</returns>
    private static string Shown(string name) => string.Concat(name.EnumerateRunes().Take(NameShown).Select(rune => rune.ToString()));

    /// <summary>
    /// Takes the first "map." out of a kind, as the script named the map's looks.
    /// </summary>
    /// <param name="kind">The kind.</param>
    /// <returns>The kind without it.</returns>
    private static string WithoutMapPrefix(string kind)
    {
        int at = kind.IndexOf("map.", StringComparison.Ordinal);
        return at < 0 ? kind : kind.Remove(at, 4);
    }
}
