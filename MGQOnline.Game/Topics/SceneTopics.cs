//----------------------------------------------------------------
//  SceneTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Battles.Wire;
using MGQOnline.Game.Scene;

namespace MGQOnline.Game.Topics;

/// <summary>
/// The bridge topics of the story's scene (<see cref="SceneQueue"/> and <see cref="SceneChecks"/>),
/// which both hosts answer through <see cref="SharedTopics"/>, since coop_scene.rbx loads on the
/// battle server too. A change's arguments cross as the line the battle line codec writes of them
/// (<see cref="WireWriter"/>), which the DLL reads back with no game facts: a scene names no battler,
/// symbol or database entry.
/// </summary>
public static class SceneTopics
{
    /// <summary>
    /// Keeps a change of the teller's scene: <c>kind</c>, <c>line</c> (its arguments), <c>map</c>,
    /// <c>logged</c> and <c>skip</c> (whether the player holds the game's skip) in; whether the
    /// line read out.
    /// </summary>
    public const string Change = "scene.change";

    /// <summary>
    /// Takes the changes waiting as their messages once they are due (<see cref="SceneQueue.Due"/>):
    /// <c>skip</c> and <c>playing</c> (whether the story plays on the map screen) in, or nil for
    /// at once; each {<c>map</c>, <c>kind</c>, <c>args</c>, <c>changes</c> ([kind, text, logged]
    /// each)} out, false while they wait for their time, nil while nothing waits.
    /// </summary>
    public const string Flush = "scene.flush";

    /// <summary>
    /// Forgets the changes waiting.
    /// </summary>
    public const string Clear = "scene.clear";

    /// <summary>
    /// Checks a message of the teller's scene for a viewer: <c>kind</c>, <c>line</c>, <c>map</c>
    /// (the teller's) and <c>here</c> (the player's) in; a text refusing the whole message, else the
    /// refusal of each change in its order (nil for one that passes) out; nil when the line does
    /// not read.
    /// </summary>
    public const string Take = "scene.take";

    /// <summary>
    /// Checks one change of a picture or the screen for a battle's playback: <c>kind</c> and
    /// <c>line</c> in; the refusal or nil out.
    /// </summary>
    public const string Check = "scene.check";

    /// <summary>
    /// How much of a change's line the teller's log shows.
    /// </summary>
    public const int LoggedChars = 120;

    /// <summary>
    /// What the DLL knows of the game when it reads a scene's line: nothing, since a scene names no
    /// battler, symbol or database entry.
    /// </summary>
    private static readonly WireGame NoGame = new([], [], new Dictionary<WireTable, int>());

    /// <summary>
    /// Registers the topics on a context, over a queue of the context's own.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        var queue = new SceneQueue();
        context.Register(Change, (_, request) =>
        {
            RubyHash fields = request.AsHash();
            if (Parse(fields["line"]) is not { } args)
            {
                return false;
            }

            queue.Add(fields["kind"].AsText(), args, fields["map"].AsInt(), fields["logged"].AsBool(), fields["skip"].AsBool());
            return true;
        });
        context.Register(Flush, (host, request) => FlushOf(queue, request, host.Frame));
        context.Register(Clear, (_, _) =>
        {
            queue.Clear();
            return null;
        });
        context.Register(Take, (_, request) => TakeOf(request.AsHash()));
        context.Register(Check, (_, request) =>
        {
            RubyHash fields = request.AsHash();
            string? refusal = Parse(fields["line"]) is { } args ? SceneChecks.Refusal(fields["kind"].AsText(), args) : SceneChecks.BadArguments;
            return refusal;
        });
    }

    /// <summary>
    /// Answers <see cref="Flush"/>.
    /// </summary>
    /// <param name="queue">The queue.</param>
    /// <param name="request">The request.</param>
    /// <param name="frame">The frame now.</param>
    /// <returns>The messages, false or nil.</returns>
    private static RubyValue? FlushOf(SceneQueue queue, RubyValue request, long frame)
    {
        if (queue.Count == 0)
        {
            return null;
        }

        if (!request.IsNil && !queue.Due(frame, Flag(request.AsHash()["skip"]), Flag(request.AsHash()["playing"])))
        {
            return false;
        }

        IReadOnlyList<SceneMessage> messages = queue.Flush(frame);
        if (messages.Count == 0)
        {
            return null;
        }

        return new RubyArray(messages.Select(message => (RubyValue)new RubyHash
        {
            { "map", message.Map },
            { "kind", message.Kind },
            { "args", message.Args },
            { "changes", new RubyArray(message.Changes.Select(change => (RubyValue)new RubyArray { change.Kind, Shown(WireWriter.Line(change.Args)), change.Logged })) },
        }));
    }

    /// <summary>
    /// Answers <see cref="Take"/>.
    /// </summary>
    /// <param name="fields">The request.</param>
    /// <returns>The refusals.</returns>
    private static RubyValue? TakeOf(RubyHash fields)
    {
        if (Parse(fields["line"]) is not { } values)
        {
            return null;
        }

        string kind = fields["kind"].AsText();
        int map = fields["map"].AsInt();
        int here = fields["here"].AsInt();
        if (kind != SceneQueue.BatchKind)
        {
            return new RubyArray { Verdict(kind, values, map, here) };
        }

        if (SceneChecks.Batch(values) is not { } changes)
        {
            return SceneChecks.BadBatch;
        }

        return new RubyArray(changes.Select(change => Verdict(change.Kind, change.Args, map, here)));
    }

    /// <summary>
    /// Tells what a viewer refuses of one change.
    /// </summary>
    /// <param name="kind">What changes.</param>
    /// <param name="args">Its arguments.</param>
    /// <param name="map">The teller's map.</param>
    /// <param name="here">The player's map.</param>
    /// <returns>The refusal, or nil.</returns>
    private static RubyValue Verdict(string kind, IReadOnlyList<WireValue> args, int map, int here)
    {
        string? refusal = SceneChecks.OnTheWay(kind, map, here) ?? SceneChecks.Refusal(kind, args);
        return refusal is null ? RubyNil.Value : refusal;
    }

    /// <summary>
    /// Reads a flag of a request, which a script may leave out.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>Whether it is true.</returns>
    private static bool Flag(RubyValue value) => value is RubyBool { Flag: true };

    /// <summary>
    /// Reads a line of arguments.
    /// </summary>
    /// <param name="line">The line.</param>
    /// <returns>The arguments, <see langword="null"/> when the line does not read.</returns>
    private static IReadOnlyList<WireValue>? Parse(RubyValue line) => WireReader.Parse(line.AsBytes().Span, NoGame);

    /// <summary>
    /// Cuts a line to what the log shows.
    /// </summary>
    /// <param name="line">The line.</param>
    /// <returns>Its first <see cref="LoggedChars"/> characters.</returns>
    private static string Shown(string line) => string.Concat(line.EnumerateRunes().Take(LoggedChars).Select(rune => rune.ToString()));
}
