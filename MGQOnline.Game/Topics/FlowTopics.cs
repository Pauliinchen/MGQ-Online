//----------------------------------------------------------------
//  FlowTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Events.Data;
using MGQOnline.Game.Flow;

namespace MGQOnline.Game.Topics;

/// <summary>
/// The bridge topics of the one guard of the game's flow (<see cref="FlowGuard"/>), which coop_flow.rbx
/// asks at every place the mod cuts, skips, moves or ends a game event. A state crosses as a Hash:
/// <c>map</c>, <c>brightness</c>, <c>fading_in</c>, <c>tone</c> ([red, green, blue, gray]),
/// <c>hidden</c>, <c>followers</c>, <c>temp_party</c>, <c>music</c> ([file, volume, pitch] or nil),
/// <c>bans</c> (their names, see <see cref="FlowBans"/>), <c>route</c> and <c>pictures</c> (the
/// numbers shown). A command crosses as [code, indent, parameters], a tone among them as its four
/// values, each value a whole number, since no Float crosses the bridge.
/// </summary>
public static class FlowTopics
{
    /// <summary>
    /// Finds what to put back: <c>cut</c> (<c>cut</c>, <c>skip</c>, <c>leave</c>, <c>watched</c>,
    /// <c>refused</c> or <c>free</c>), <c>before</c> (a state or nil), <c>now</c> (a state),
    /// <c>owned</c> (picture numbers), <c>rest</c> (the commands the event would still run, a text
    /// only in scripts), <c>commons</c> (the commands of the common events they call, by id),
    /// <c>whole</c>, <c>elsewhere</c> and <c>watch</c> (<c>screen</c>, <c>hidden</c>, <c>route</c>
    /// and <c>pictures</c>, see <see cref="FlowWatch"/>) in, see
    /// <see cref="FlowAsk"/>. Answers <c>needs</c> (the common events whose commands the request
    /// lacks) while a call names one it lacks, else the plan:
    /// <c>erase</c>, <c>fade_in</c>, <c>tone</c>, <c>hidden</c>, <c>followers</c>,
    /// <c>release_party</c>, <c>music</c>, <c>lift</c>, <c>end_route</c>, <c>clear_effects</c> and
    /// <c>frames</c>, each part nil, empty or false when it stays as it is.
    /// </summary>
    public const string PlanTopic = "flow.plan";

    /// <summary>
    /// Tells whether the player's own scene still stands once none of its events runs (see
    /// <see cref="FlowGuard.Stands"/>): <c>start</c> and <c>now</c> (states) in, true or false out.
    /// </summary>
    public const string StandsTopic = "flow.stands";

    /// <summary>
    /// The cuts by the names the scripts give them.
    /// </summary>
    private static readonly (string Name, FlowCut Cut)[] Cuts =
        [("cut", FlowCut.Cut), ("skip", FlowCut.Skip), ("leave", FlowCut.Leave), ("watched", FlowCut.Watched), ("refused", FlowCut.Refused), ("free", FlowCut.Free)];

    /// <summary>
    /// The values of a tint.
    /// </summary>
    private const int ToneValues = 4;

    /// <summary>
    /// The values of a piece of music: its file, volume and pitch.
    /// </summary>
    private const int MusicValues = 3;

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        context.Register(PlanTopic, (_, request) => PlanOf(request.AsHash()));
        context.Register(StandsTopic, (_, request) => FlowGuard.Stands(StateOf(request.AsHash()["start"]), StateOf(request.AsHash()["now"])));
    }

    /// <summary>
    /// Answers <see cref="PlanTopic"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The plan, or the common events it needs.</returns>
    /// <exception cref="BridgeRequestException">The cut, a state or a command is malformed.</exception>
    internal static RubyHash PlanOf(RubyHash request)
    {
        string name = request["cut"].AsText();
        FlowCut cut = Cuts.FirstOrDefault(entry => entry.Name == name) is { Name: not null } found ? found.Cut : throw new BridgeRequestException($"No such cut of the flow: {name}.");
        Dictionary<int, IReadOnlyList<FlowCommand>> commons = [];
        if (request["commons"] is RubyHash given)
        {
            foreach (KeyValuePair<RubyValue, RubyValue> entry in given)
            {
                commons[entry.Key.AsInt()] = CommandsOf(entry.Value);
            }
        }

        FlowRest rest = FlowRest.Of(CommandsOf(request["rest"]), id => commons.TryGetValue(id, out IReadOnlyList<FlowCommand>? commands) ? commands : null);
        if (rest.Needs.Count > 0)
        {
            return new RubyHash { { "needs", new RubyArray(rest.Needs.Select(id => (RubyValue)id)) } };
        }

        FlowState? before = request["before"].IsNil ? null : StateOf(request["before"]);
        FlowWatch watch = request["watch"] is RubyHash shown
            ? new FlowWatch(Flag(shown["screen"]), Flag(shown["hidden"]), Flag(shown["route"]), NumbersOf(shown["pictures"]))
            : FlowWatch.None;
        FlowPlan plan = FlowGuard.Plan(new FlowAsk(
            cut, before, StateOf(request["now"]), NumbersOf(request["owned"]), rest, Flag(request["whole"]), Flag(request["elsewhere"]), watch));
        return PlanAnswer(plan);
    }

    /// <summary>
    /// Writes a plan for the scripts.
    /// </summary>
    /// <param name="plan">The plan.</param>
    /// <returns>Its fields.</returns>
    private static RubyHash PlanAnswer(FlowPlan plan) => new()
    {
        { "erase", new RubyArray(plan.Erase.Select(number => (RubyValue)number)) },
        { "fade_in", plan.FadeIn },
        { "tone", plan.Tone is { } tone ? new RubyArray { Whole(tone.Red), Whole(tone.Green), Whole(tone.Blue), Whole(tone.Gray) } : RubyNil.Value },
        { "hidden", plan.Hidden is { } hidden ? (RubyValue)hidden : RubyNil.Value },
        { "followers", plan.Followers is { } followers ? (RubyValue)followers : RubyNil.Value },
        { "release_party", plan.ReleaseParty },
        { "music", plan.Music is { } music ? new RubyArray { music.Name, music.Volume, music.Pitch } : RubyNil.Value },
        { "lift", new RubyArray(plan.Lift.Select(ban => (RubyValue)ban)) },
        { "end_route", plan.EndRoute },
        { "clear_effects", plan.ClearEffects },
        { "frames", FlowPlan.Frames },
    };

    /// <summary>
    /// Reads a state.
    /// </summary>
    /// <param name="value">The state's Hash.</param>
    /// <returns>The state.</returns>
    /// <exception cref="BridgeRequestException">A field is malformed.</exception>
    internal static FlowState StateOf(RubyValue value)
    {
        RubyHash state = value.AsHash();
        return new FlowState(
            Map: state["map"].AsInt(),
            Brightness: (int)Real(state["brightness"]),
            FadingIn: Flag(state["fading_in"]),
            Tone: ToneOf(state["tone"]) ?? FlowTone.None,
            Hidden: Flag(state["hidden"]),
            Followers: Flag(state["followers"]),
            TempParty: Flag(state["temp_party"]),
            Music: MusicOf(state["music"]),
            Bans: state["bans"] is RubyArray bans ? bans.Select(ban => ban.AsText()).ToHashSet(StringComparer.Ordinal) : [],
            Route: Flag(state["route"]),
            Pictures: state["pictures"] is RubyArray pictures ? pictures.Select(number => number.AsInt()).ToHashSet() : []);
    }

    /// <summary>
    /// Reads picture numbers a request may leave out.
    /// </summary>
    /// <param name="value">The numbers, nil for none.</param>
    /// <returns>The numbers.</returns>
    private static HashSet<int> NumbersOf(RubyValue value) => value is RubyArray numbers ? [.. numbers.Select(number => number.AsInt())] : [];

    /// <summary>
    /// Reads commands as [code, indent, parameters] each.
    /// </summary>
    /// <param name="value">The commands, nil for none.</param>
    /// <returns>The commands.</returns>
    private static IReadOnlyList<FlowCommand> CommandsOf(RubyValue value)
    {
        if (value.IsNil)
        {
            return [];
        }

        var commands = new List<FlowCommand>();
        foreach (RubyValue row in value.AsArray())
        {
            RubyArray fields = row.AsArray();
            if (fields.Count < 1)
            {
                throw new BridgeRequestException("A command is [code, indent, parameters].");
            }

            RubyArray parameters = fields.Count > 2 && fields[2] is RubyArray given ? given : [];
            commands.Add(new FlowCommand(
                (int)EventCommand.NumberOf(fields[0]),
                [.. parameters.Select(EventCommand.NumberOf)],
                parameters.OfType<RubyString>().FirstOrDefault()?.Text ?? string.Empty,
                parameters.Select(ToneOf).FirstOrDefault(tone => tone is not null)));
        }

        return commands;
    }

    /// <summary>
    /// Reads a tint: four numbers.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The tint, <see langword="null"/> for anything else.</returns>
    private static FlowTone? ToneOf(RubyValue value) =>
        value is RubyArray { Count: ToneValues } values && values.All(IsNumber)
            ? new FlowTone(Real(values[0]), Real(values[1]), Real(values[2]), Real(values[3]))
            : null;

    /// <summary>
    /// Reads a piece of music: its file, volume and pitch.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The music, <see langword="null"/> for none.</returns>
    private static FlowMusic? MusicOf(RubyValue value) =>
        value is RubyArray { Count: MusicValues } fields && fields[0] is RubyString file
            ? new FlowMusic(file.Text, (int)EventCommand.NumberOf(fields[1]), (int)EventCommand.NumberOf(fields[2]))
            : null;

    /// <summary>
    /// Writes a tint's value as the whole number that crosses the bridge, which takes no Float.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>It rounded.</returns>
    private static RubyValue Whole(double value) => (long)Math.Round(value, MidpointRounding.AwayFromZero);

    /// <summary>
    /// Tells whether a value is a number.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>Whether it is a whole number or a Float.</returns>
    private static bool IsNumber(RubyValue value) => value is RubyInteger or RubyFloat;

    /// <summary>
    /// Reads a number, whole or not.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The number, 0 for anything else.</returns>
    private static double Real(RubyValue value) => value is RubyFloat real ? real.Value : EventCommand.NumberOf(value);

    /// <summary>
    /// Reads a flag a script may leave out.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>Whether it is true.</returns>
    private static bool Flag(RubyValue value) => value is RubyBool { Flag: true };
}
