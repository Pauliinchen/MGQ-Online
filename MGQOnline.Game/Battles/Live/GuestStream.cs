//----------------------------------------------------------------
//  GuestStream.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Let the host's changes of a guest's gold and items through as the bag event
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Numerics;
using System.Text;
using System.Text.RegularExpressions;
using MGQOnline.Game.Battles.Wire;
using MGQOnline.Game.Ruby;
using MGQOnline.Game.Scene;

namespace MGQOnline.Game.Battles.Live;

/// <summary>
/// The guest's intake of the host's stream, as battles_sync_playback.rbx took it: each send split
/// into its lines, a line that does not read left out, a line of a kind, method or arguments this
/// game refuses left out with its reason logged once, and the host's names swapped for the guest's
/// in the texts that still arrive as text. The script reads the lines left with its game's objects
/// and plays them.
/// </summary>
public sealed class GuestStream
{
    /// <summary>
    /// The longest wait taken from the host, in frames: 10 seconds.
    /// </summary>
    public const int MaxWait = 600;

    /// <summary>
    /// The longest fade of music taken from the host, in milliseconds: 10 seconds.
    /// </summary>
    public const int MaxFade = 10_000;

    /// <summary>
    /// How much of a kind, method or name a log line shows.
    /// </summary>
    private const int ShownName = 40;

    /// <summary>
    /// How much of a call's arguments a log line shows.
    /// </summary>
    private const int ShownArgs = 80;

    /// <summary>
    /// The scene's waits the host may have called with a duration.
    /// </summary>
    private static readonly HashSet<string> TimedWaits = new(["wait", "abs_wait"], StringComparer.Ordinal);

    /// <summary>
    /// The scene's waits the host may have called until something ends.
    /// </summary>
    private static readonly HashSet<string> OpenWaits = new(["wait_for_animation", "wait_for_effect", "wait_for_message"], StringComparer.Ordinal);

    /// <summary>
    /// The kinds the guest plays as they come, which the intake leaves as they are.
    /// </summary>
    private static readonly HashSet<string> PlainKinds = new(
        ["commands", "end", "emerge", "bag", "values", "time_stop", "turn", "battler.sprite_effect_type", "battler.animation_mirror"],
        StringComparer.Ordinal);

    /// <summary>
    /// A sound or piece of music the host may play: a path inside the game's Audio folder whose
    /// parts are plain names, so it never leads out of that folder.
    /// </summary>
    private static readonly Regex AudioFile = new(@"\AAudio/(?:[A-Za-z0-9_\- ]+/)+[A-Za-z0-9_\- ]+(?:\.[A-Za-z0-9_\- ]+)*\z", RegexOptions.CultureInvariant);

    /// <summary>
    /// What the guest knows of the game when it reads a line: nothing, since the checks read only
    /// kinds, numbers and texts.
    /// </summary>
    private static readonly WireGame NoGame = new([], [], new Dictionary<WireTable, int>());

    /// <summary>
    /// The guest's setup, empty before the first.
    /// </summary>
    private StreamSetup _setup = StreamSetup.Empty;

    /// <summary>
    /// The host's names and the guest's, nothing swapped before the host named any.
    /// </summary>
    private StreamNames _names = new(null, [], []);

    /// <summary>
    /// Takes what the guest checks the stream against for a battle, and the host's names when the
    /// host's battle is ready, which replace any taken before.
    /// </summary>
    /// <param name="setup">The setup.</param>
    /// <returns>The line the guest logs of the names, none without names.</returns>
    public IReadOnlyList<LiveLogLine> Setup(StreamSetup setup)
    {
        ArgumentNullException.ThrowIfNull(setup);
        _setup = setup;
        _names = new StreamNames(setup.HostNames is null ? null : WireReader.Parse(setup.HostNames, NoGame), setup.OwnParty, setup.OwnTroop);
        return setup.HostNames is null ? [] : [new LiveLogLine(null, _names.Summary())];
    }

    /// <summary>
    /// Swaps the host's names in a text, as the stream's texts are swapped.
    /// </summary>
    /// <param name="text">The host's text.</param>
    /// <returns>The guest's text.</returns>
    public string Swap(string text) => _names.Swap(text);

    /// <summary>
    /// Takes one send of the host's stream.
    /// </summary>
    /// <param name="body">The send: one line per event.</param>
    /// <param name="seat">The seat the battle knows the player by, which a choose again names.</param>
    /// <returns>The lines the guest plays, with what the intake counted and logged.</returns>
    public StreamTake Take(ReadOnlySpan<byte> body, int seat)
    {
        var lines = new List<string>();
        var logs = new List<LiveLogLine>();
        int events = 0;
        int unreadable = 0;
        int othersChoose = 0;
        foreach (byte[] line in Lines(body))
        {
            IReadOnlyList<WireValue>? values = WireReader.Parse(line, NoGame);
            if (values is not { Count: > 0 } || values[0] is not WireString kind)
            {
                unreadable++;
                logs.Add(new LiveLogLine("unreadable_event", $"left out an unreadable line of the host's stream ({CharactersOf(line)} characters)"));
                continue;
            }

            events++;
            string text = Encoding.UTF8.GetString(line);
            if (kind.Text == "choose_again" && !Names(values.Count > 1 ? values[1] : WireNil.Value, seat))
            {
                othersChoose++;
                continue;
            }

            string? kept = Checked(kind.Text, values.Skip(1).ToList(), text, logs);
            if (kept is not null)
            {
                lines.Add(kept);
            }
        }

        return new StreamTake(lines, events, unreadable, othersChoose, logs);
    }

    /// <summary>
    /// Splits a send into its lines as Ruby's split("\n") does, leaving out the empty lines at its end.
    /// </summary>
    /// <param name="body">The send.</param>
    /// <returns>The lines' bytes.</returns>
    private static List<byte[]> Lines(ReadOnlySpan<byte> body)
    {
        var lines = new List<byte[]>();
        int start = 0;
        for (int at = 0; at <= body.Length; at++)
        {
            if (at == body.Length || body[at] == (byte)'\n')
            {
                lines.Add(body[start..at].ToArray());
                start = at + 1;
            }
        }

        while (lines.Count > 0 && lines[^1].Length == 0)
        {
            lines.RemoveAt(lines.Count - 1);
        }

        return lines;
    }

    /// <summary>
    /// Counts a line's characters as Ruby counts a UTF-8 text's, each broken byte as one.
    /// </summary>
    /// <param name="line">The line.</param>
    /// <returns>Its characters.</returns>
    private static int CharactersOf(byte[] line)
    {
        int count = 0;
        for (ReadOnlySpan<byte> rest = line; !rest.IsEmpty; count++)
        {
            System.Buffers.OperationStatus status = Rune.DecodeFromUtf8(rest, out _, out int used);
            rest = rest[(status == System.Buffers.OperationStatus.Done ? used : 1)..];
        }

        return count;
    }

    /// <summary>
    /// Reports whether a choose again names a seat, as the script's Array(names).include?(seat) did.
    /// </summary>
    /// <param name="names">The seats it names.</param>
    /// <param name="seat">The seat.</param>
    /// <returns>Whether it names it.</returns>
    private static bool Names(WireValue names, int seat)
    {
        IEnumerable<WireValue> listed = names switch
        {
            WireList list => list.Items,
            WireNil => [],
            _ => [names],
        };
        return listed.Any(value => value switch
        {
            WireInteger number => number.Value == seat,
            WireFloat number => number.Value == seat,
            _ => false,
        });
    }

    /// <summary>
    /// Checks one event of the host's stream and swaps its names.
    /// </summary>
    /// <param name="kind">The event's kind.</param>
    /// <param name="args">Its values after the kind.</param>
    /// <param name="line">The line as it came.</param>
    /// <param name="logs">Where the reasons to leave it out go.</param>
    /// <returns>The line the guest plays, <see langword="null"/> to leave it out.</returns>
    private string? Checked(string kind, List<WireValue> args, string line, List<LiveLogLine> logs)
    {
        if (PlainKinds.Contains(kind) || kind == "choose_again")
        {
            return line;
        }

        string method = kind.Contains('.', StringComparison.Ordinal) ? kind[(kind.IndexOf('.', StringComparison.Ordinal) + 1)..] : "";
        switch (kind)
        {
            case "call":
                return CallChecked(args, line, logs);
            case "popup":
                return Swapped(line, args, 0, _names.Swap);
            case "message":
                return args.Count == 6 ? Swapped(line, args, 5, text => _setup.NameBox ? _names.SwapMessage(text) : StreamNames.Readable(_names.SwapMessage(text))) : line;
            case "skill_name":
                return Swapped(line, args, 1, _names.Swap);
            case "animation":
                return args.Count == 3 && ToI(args[2]) is { } shown && shown >= 0 && !IsAnimation(shown) ? null : line;
            case "battler.animation_id":
                return args.Count == 2 && ToI(args[1]) is { } started && !IsAnimation(started) ? null : line;
        }

        if (kind.StartsWith("log.", StringComparison.Ordinal))
        {
            return _setup.LogMethods.Contains(method) ? SwappedAll(line, args) : null;
        }

        if (kind.StartsWith("picture.", StringComparison.Ordinal))
        {
            string? refusal = _setup.PictureMethods.Contains(method) ? SceneChecks.Refusal(kind, args) : SceneChecks.NoSuchChange;
            return refusal is null ? line : Refused(logs, $"picture\t{RubyText.First(method, ShownName)}\t{refusal}",
                $"left out the host's picture call {RubyText.First(method, ShownName)} with the arguments {RubyText.First(RubyText.Inspect(args), ShownArgs)}: {refusal}");
        }

        if (kind.StartsWith("screen.", StringComparison.Ordinal))
        {
            string? refusal = _setup.ScreenMethods.Contains(method) ? SceneChecks.Refusal(kind, args) : null;
            return !_setup.ScreenMethods.Contains(method) ? null
                : refusal is null ? line
                : Refused(logs, $"screen_args\t{method}\t{refusal}", $"left out the host's screen call {method} with the arguments {RubyText.First(RubyText.Inspect(args), ShownArgs)}: {refusal}");
        }

        if (kind.StartsWith("audio.", StringComparison.Ordinal))
        {
            return !_setup.AudioMethods.Contains(method) ? null
                : AudioArgs(method, args) ? line
                : Refused(logs, $"audio_args\t{method}", $"left out the host's audio call {method} with the arguments {RubyText.First(RubyText.Inspect(args), ShownArgs)}");
        }

        if (kind.StartsWith("scene.", StringComparison.Ordinal))
        {
            return Wait(kind, method, args);
        }

        string shownKind = RubyText.First(kind, ShownName);
        return Refused(logs, $"unknown_event\t{shownKind}", $"left out the host's event {shownKind}, which this game does not know");
    }

    /// <summary>
    /// Checks a call the guest makes itself: only the battle log's calls its hooks list and the
    /// battle's own calls.
    /// </summary>
    /// <param name="args">The receiver, the method, the seed, who acts, the results, then the method's arguments.</param>
    /// <param name="line">The line.</param>
    /// <param name="logs">Where the reason to leave it out goes.</param>
    /// <returns>The line, <see langword="null"/> to leave it out.</returns>
    private string? CallChecked(List<WireValue> args, string line, List<LiveLogLine> logs)
    {
        // A call short of its fields fails in the script, as it did before.
        if (args.Count < 5)
        {
            return line;
        }

        bool callable = (args[0], args[1]) switch
        {
            (WireString { Text: "log" }, WireString name) => _setup.LogCalls.Contains(name.Text),
            (WireString { Text: "scene" }, WireString name) => _setup.SceneCalls.Contains(name.Text),
            _ => false,
        };
        if (callable)
        {
            return line;
        }

        string receiver = RubyText.ToS(args[0]);
        string method = RubyText.First(RubyText.ToS(args[1]), ShownName);
        return Refused(logs, $"left_out\t{receiver}\t{method}", $"left out the host's {receiver} call {method}");
    }

    /// <summary>
    /// Checks one of the scene's waits: a timed one at most <see cref="MaxWait"/> frames, as a whole
    /// number, an open one without arguments.
    /// </summary>
    /// <param name="kind">The event's kind.</param>
    /// <param name="method">The wait.</param>
    /// <param name="args">Its arguments.</param>
    /// <returns>The line the guest plays, <see langword="null"/> to leave it out.</returns>
    private static string? Wait(string kind, string method, List<WireValue> args)
    {
        if (OpenWaits.Contains(method))
        {
            return WireWriter.Line(kind);
        }

        if (!TimedWaits.Contains(method) || ToI(args.Count > 0 ? args[0] : WireNil.Value) is not { } frames)
        {
            return null;
        }

        return WireWriter.Line(kind, BigInteger.Min(frames, MaxWait));
    }

    /// <summary>
    /// Reports whether the arguments of one of the host's audio calls read as the game's own: a play
    /// names a file with a volume, a pitch and, for music, a position, a stop takes nothing, a fade
    /// its milliseconds, and the game's own over drive calls only plain values.
    /// </summary>
    /// <param name="method">What the host called of Audio.</param>
    /// <param name="args">The call's arguments.</param>
    /// <returns>Whether they do.</returns>
    private static bool AudioArgs(string method, List<WireValue> args)
    {
        if (method.EndsWith("_play", StringComparison.Ordinal))
        {
            WireValue At(int index) => index < args.Count ? args[index] : WireNil.Value;
            return args.Count <= 4 && At(0) is WireString name && AudioFile.IsMatch(name.Text)
                && Bounded(At(1), 0, 100) && Bounded(At(2), 50, 150)
                && (At(3) is WireNil || (method.StartsWith("bg", StringComparison.Ordinal) && At(3) is WireInteger { Value.Sign: >= 0 }));
        }

        if (method.EndsWith("_stop", StringComparison.Ordinal))
        {
            return args.Count == 0;
        }

        if (method.EndsWith("_fade", StringComparison.Ordinal))
        {
            return args.Count == 1 && Bounded(args[0], 0, MaxFade);
        }

        return args.All(arg => arg is WireNil or WireBool or WireInteger or WireFloat);
    }

    /// <summary>
    /// Reports whether an optional number of an audio call lies within what the game accepts.
    /// </summary>
    /// <param name="value">The number, nil when the call leaves it to the game.</param>
    /// <param name="least">The least it accepts.</param>
    /// <param name="most">The most it accepts.</param>
    /// <returns>Whether it does.</returns>
    private static bool Bounded(WireValue value, int least, int most) =>
        value is WireNil || (value is WireInteger number && number.Value >= least && number.Value <= most);

    /// <summary>
    /// Reports whether this game has an animation, as $data_animations[id] tells, counting from its
    /// end below 0.
    /// </summary>
    /// <param name="id">The animation's id.</param>
    /// <returns>Whether it has.</returns>
    private bool IsAnimation(BigInteger id) =>
        (id >= 1 && id < _setup.Animations) || (id < 0 && -id <= _setup.Animations - 1);

    /// <summary>
    /// Reads a value as Ruby's to_i does.
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
    /// Notes why a line is left out.
    /// </summary>
    /// <param name="logs">Where the reasons go.</param>
    /// <param name="key">What tells the reason from others, logged once per game.</param>
    /// <param name="text">The reason's line.</param>
    /// <returns><see langword="null"/>, so the line is left out.</returns>
    private static string? Refused(List<LiveLogLine> logs, string key, string text)
    {
        logs.Add(new LiveLogLine(key, text));
        return null;
    }

    /// <summary>
    /// Swaps the names of one text of a line, leaving every other token as it came.
    /// </summary>
    /// <param name="line">The line.</param>
    /// <param name="args">Its values after the kind.</param>
    /// <param name="index">The text's place among them.</param>
    /// <param name="swap">How the text changes.</param>
    /// <returns>The line.</returns>
    private static string Swapped(string line, List<WireValue> args, int index, Func<string, string> swap) =>
        index < args.Count && args[index] is WireString text ? Replaced(line, new Dictionary<int, string> { [index + 1] = swap(text.Text) }) : line;

    /// <summary>
    /// Swaps the names of every text of a line.
    /// </summary>
    /// <param name="line">The line.</param>
    /// <param name="args">Its values after the kind.</param>
    /// <returns>The line.</returns>
    private string SwappedAll(string line, List<WireValue> args)
    {
        var texts = new Dictionary<int, string>();
        for (int index = 0; index < args.Count; index++)
        {
            if (args[index] is WireString text)
            {
                texts[index + 1] = _names.Swap(text.Text);
            }
        }

        return Replaced(line, texts);
    }

    /// <summary>
    /// Writes a line anew with some of its texts changed, every other token as it came.
    /// </summary>
    /// <param name="line">The line.</param>
    /// <param name="texts">The new texts by their value's place, the kind's 0.</param>
    /// <returns>The line.</returns>
    private static string Replaced(string line, Dictionary<int, string> texts)
    {
        string[] tokens = line.Split('\t');
        int value = 0;
        int depth = 0;
        for (int at = 0; at < tokens.Length; at++)
        {
            string token = tokens[at];
            if (depth == 0 && texts.TryGetValue(value, out string? text) && token.StartsWith('s'))
            {
                tokens[at] = "s" + WireFormat.Escape(text);
            }

            depth += token is "[" or "{" ? 1 : token is "]" or "}" ? -1 : 0;
            if (depth == 0)
            {
                value++;
            }
        }

        return string.Join('\t', tokens);
    }
}
