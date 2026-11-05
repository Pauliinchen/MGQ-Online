//----------------------------------------------------------------
//  FlowGuardTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Covered what an early end, a move away, a watched scene's end and an event kept from starting put back beyond the reported cases
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using System.Text.Json;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Flow;

/// <summary>
/// Covers the one guard of the game's flow through its topics, as the scripts ask it: every
/// reported case of the flow left half done (fixtures/flow/cases.json) gets the plan that puts back
/// what the game's own flow would leave, the player's own scene stands while an ending's walk goes
/// on, and an early end, a move away, a watched scene's end and an event kept from starting put
/// back what they changed and nothing that came before them.
/// </summary>
public sealed class FlowGuardTests
{
    /// <summary>
    /// The context the topics answer on.
    /// </summary>
    private readonly TopicContext _topics = new();

    /// <summary>
    /// Registers the flow topics.
    /// </summary>
    public FlowGuardTests()
    {
        FlowTopics.Register(_topics.Context);
    }

    /// <summary>
    /// Asserts that each reported case gets its plan, a case whose event calls a common event first
    /// naming the common event the request lacks.
    /// </summary>
    [Fact]
    public void ReportedCases_PutBackWhatTheGameFlowWouldLeave()
    {
        foreach (JsonElement entry in Fixtures.Read("flow", "cases.json").GetProperty("cases").EnumerateArray())
        {
            string name = $"{entry.GetProperty("issue").GetString()}: {entry.GetProperty("name").GetString()}";
            RubyHash request = ValueOf(entry.GetProperty("request")).AsHash();
            if (entry.TryGetProperty("needs", out JsonElement needs))
            {
                RubyHash lacking = ValueOf(entry.GetProperty("request")).AsHash();
                lacking.Remove("commons");
                RubyHash asked = _topics.Value(FlowTopics.PlanTopic, lacking).AsHash();
                Assert.True(Same(ValueOf(needs), asked["needs"]), $"{name}: needs {asked["needs"]}");
            }

            RubyHash plan = _topics.Value(FlowTopics.PlanTopic, request).AsHash();
            foreach (JsonProperty part in entry.GetProperty("plan").EnumerateObject())
            {
                Assert.True(Same(ValueOf(part.Value), plan[part.Name]), $"{name}: {part.Name} is {plan[part.Name]}, expected {part.Value}");
            }
        }
    }

    /// <summary>
    /// Asserts that the player's own scene stands while its ending leaves them hidden in a temporary
    /// party, and while a CG it showed stays, as a frozen fight's resumed scene leaves it, and closes
    /// once nothing it changed stands.
    /// </summary>
    [Fact]
    public void OwnScene_StandsWhileItsEndingWalkOrItsPicturesGoOn()
    {
        RubyHash start = State(hidden: false, tempParty: false, pictures: 20);
        Assert.True(Stands(start, State(hidden: true, tempParty: true, pictures: 20)));
        Assert.True(Stands(start, State(hidden: false, tempParty: false, 5, 20)));
        Assert.False(Stands(start, State(hidden: false, tempParty: false, pictures: 20)));
    }

    /// <summary>
    /// Asserts that a talk the mod ends early erases the picture it showed and brings back the light,
    /// the tint and the music it began with, while a talk on an ending's walk leaves the walk's
    /// temporary party and hidden character, unless its rest ends the party itself.
    /// </summary>
    [Fact]
    public void Cut_PutsBackWhatTheEventChangedButNotWhatCameBefore()
    {
        RubyHash began = With(State(hidden: false, tempParty: false, pictures: 20), ("music", Music("Castle")));
        RubyHash now = With(State(hidden: false, tempParty: false, 5, 20), ("brightness", 0), ("tone", Tone(-68, -68, -68, 0)), ("music", Music("Sad")));
        RubyHash talk = Plan(Ask("cut", now, began, owned: [5], rest: [Command(121, 2001, 2001, 0), Command(0)]));

        Assert.Equal([5], Numbers(talk["erase"]));
        Assert.True(talk["fade_in"].AsBool());
        Assert.Equal([0, 0, 0, 0], Numbers(talk["tone"]));
        Assert.Equal("Castle", talk["music"].AsArray()[0].AsText());

        RubyHash walk = State(hidden: true, tempParty: true, 6);
        RubyHash villager = Plan(Ask("cut", walk, walk, owned: [6], rest: [Command(0)]));
        RubyHash farewell = Plan(Ask("cut", walk, walk, owned: [6], rest: [Command(355, "$game_party.release_temp_actors"), Command(0)]));

        Assert.Equal([6], Numbers(villager["erase"]));
        Assert.True(villager["hidden"].IsNil);
        Assert.False(villager["release_party"].AsBool());
        Assert.True(farewell["release_party"].AsBool());
    }

    /// <summary>
    /// Asserts that moving the player away with no scene of their own under way leaves their
    /// temporary party and hidden character, while leaving a scene a frozen fight's resume put back
    /// erases its CG and ends the party it began without.
    /// </summary>
    [Fact]
    public void Leave_TakesThePlayerOutOfTheirOwnSceneAlone()
    {
        RubyHash place = Plan(Ask("leave", State(hidden: true, tempParty: true), null, whole: false, elsewhere: false));
        RubyHash resumed = Plan(Ask("leave", State(hidden: false, tempParty: true, 7), State(hidden: false, tempParty: false), whole: false, elsewhere: true));

        Assert.True(place["hidden"].IsNil);
        Assert.False(place["release_party"].AsBool());
        Assert.Equal([7], Numbers(resumed["erase"]));
        Assert.True(resumed["release_party"].AsBool());
    }

    /// <summary>
    /// Asserts that a watched scene's end gives back the tint and the hidden character the player had
    /// on the map it began on, and on another map takes its tint off and shows the character, as an
    /// ending that still plays there in the teller's game would leave them.
    /// </summary>
    [Fact]
    public void Watched_PutsBackTheMapsOwnTintOrNoneOnAnotherMap()
    {
        RubyHash before = With(State(hidden: true, tempParty: false), ("tone", Tone(-34, -34, -34, 0)));
        RubyHash tinted = With(State(hidden: true, tempParty: false), ("tone", Tone(-68, -68, 0, 0)));
        RubyHash watch = new() { { "screen", true }, { "hidden", true }, { "route", false }, { "pictures", new RubyArray() } };

        RubyHash here = Plan(Ask("watched", tinted, before, watch: watch));
        RubyHash elsewhere = Plan(Ask("watched", With(tinted, ("map", 8)), before, watch: watch));

        Assert.Equal([-34, -34, -34, 0], Numbers(here["tone"]));
        Assert.True(here["hidden"].IsNil);
        Assert.Equal([0, 0, 0, 0], Numbers(elsewhere["tone"]));
        Assert.False(elsewhere["hidden"].AsBool());
    }

    /// <summary>
    /// Asserts that an event kept from starting lifts the bans its commands would lift, the escape
    /// spell's switch among them, and none they would set.
    /// </summary>
    [Fact]
    public void Skip_LiftsTheBansTheEventWouldLift()
    {
        RubyHash now = With(State(hidden: false, tempParty: false), ("bans", new RubyArray { "escape", "menu", "save" }));
        RubyHash plan = Plan(Ask("skip", now, null, rest: [Command(121, 90, 99, 1), Command(134, 1), Command(135, 0), Command(0)]));

        Assert.Equal(["escape", "save"], plan["lift"].AsArray().Select(ban => ban.AsText()));
    }

    /// <summary>
    /// Asks whether the player's own scene stands.
    /// </summary>
    /// <param name="start">The state the scene began from.</param>
    /// <param name="now">The state now.</param>
    /// <returns>The answer.</returns>
    private bool Stands(RubyHash start, RubyHash now) => _topics.Value(FlowTopics.StandsTopic, new RubyHash { { "start", start }, { "now", now } }).AsBool();

    /// <summary>
    /// Writes a state of the player on a lit map as the scripts read it.
    /// </summary>
    /// <param name="hidden">Whether the player's character is hidden.</param>
    /// <param name="tempParty">Whether a temporary party plays.</param>
    /// <param name="pictures">The pictures shown.</param>
    /// <returns>The state.</returns>
    private static RubyHash State(bool hidden, bool tempParty, params int[] pictures) => new()
    {
        { "map", 5 }, { "brightness", 255 }, { "fading_in", false }, { "tone", new RubyArray { 0, 0, 0, 0 } }, { "hidden", hidden },
        { "followers", true }, { "temp_party", tempParty }, { "music", RubyNil.Value }, { "bans", new RubyArray() }, { "route", false },
        { "pictures", new RubyArray(pictures.Select(number => (RubyValue)number)) },
    };

    /// <summary>
    /// Asks the guard for its plan.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The plan.</returns>
    private RubyHash Plan(RubyHash request) => _topics.Value(FlowTopics.PlanTopic, request).AsHash();

    /// <summary>
    /// Writes a request for a plan as the scripts write it.
    /// </summary>
    /// <param name="cut">How the mod interrupted the flow.</param>
    /// <param name="now">The state now.</param>
    /// <param name="before">The state before, <see langword="null"/> for none.</param>
    /// <param name="owned">The pictures the event showed.</param>
    /// <param name="rest">The commands the event would still run.</param>
    /// <param name="whole">Whether every scene of the player's own goes.</param>
    /// <param name="elsewhere">Whether the player goes to another map.</param>
    /// <param name="watch">What a watched scene shows, <see langword="null"/> for none.</param>
    /// <returns>The request.</returns>
    private static RubyHash Ask(string cut, RubyHash now, RubyHash? before, int[]? owned = null, RubyArray[]? rest = null, bool whole = false, bool elsewhere = false,
                                RubyHash? watch = null) => new()
    {
        { "cut", cut }, { "now", now }, { "before", before is null ? RubyNil.Value : before },
        { "owned", new RubyArray((owned ?? []).Select(number => (RubyValue)number)) }, { "rest", new RubyArray(rest ?? []) },
        { "whole", whole }, { "elsewhere", elsewhere }, { "watch", watch is null ? RubyNil.Value : watch },
    };

    /// <summary>
    /// Writes an event command as the scripts hand it: its code, no indent and its parameters.
    /// </summary>
    /// <param name="code">The command's code.</param>
    /// <param name="parameters">Its parameters, numbers or a script's text.</param>
    /// <returns>The command.</returns>
    private static RubyArray Command(int code, params RubyValue[] parameters) => [code, 0, new RubyArray(parameters)];

    /// <summary>
    /// Writes a tint as the scripts hand it.
    /// </summary>
    /// <param name="red">Its red.</param>
    /// <param name="green">Its green.</param>
    /// <param name="blue">Its blue.</param>
    /// <param name="gray">Its gray.</param>
    /// <returns>The tint.</returns>
    private static RubyArray Tone(int red, int green, int blue, int gray) => [red, green, blue, gray];

    /// <summary>
    /// Writes a piece of music playing as the scripts hand it.
    /// </summary>
    /// <param name="name">Its name.</param>
    /// <returns>The music at full volume and pitch.</returns>
    private static RubyArray Music(string name) => [name, 100, 100];

    /// <summary>
    /// Copies a state with some of its fields set otherwise.
    /// </summary>
    /// <param name="state">The state.</param>
    /// <param name="fields">The fields and their values.</param>
    /// <returns>The copy.</returns>
    private static RubyHash With(RubyHash state, params (string Name, RubyValue Value)[] fields)
    {
        var copy = new RubyHash();
        foreach (var pair in state)
        {
            copy[pair.Key] = pair.Value;
        }

        foreach ((string name, RubyValue value) in fields)
        {
            copy[name] = value;
        }

        return copy;
    }

    /// <summary>
    /// Reads a list of whole numbers.
    /// </summary>
    /// <param name="value">The list.</param>
    /// <returns>The numbers.</returns>
    private static int[] Numbers(RubyValue value) => [.. value.AsArray().Select(number => number.AsInt())];

    /// <summary>
    /// Compares an expected value with an answered one, numbers by their value whole or not.
    /// </summary>
    /// <param name="expected">The expected value.</param>
    /// <param name="actual">The answered value.</param>
    /// <returns>Whether they are the same.</returns>
    private static bool Same(RubyValue expected, RubyValue actual) => (expected, actual) switch
    {
        (RubyInteger or RubyFloat, RubyInteger or RubyFloat) => Math.Abs(Real(expected) - Real(actual)) < 1e-9,
        (RubyArray left, RubyArray right) => left.Count == right.Count && left.Zip(right).All(pair => Same(pair.First, pair.Second)),
        _ => expected.Equals(actual),
    };

    /// <summary>
    /// Reads a number.
    /// </summary>
    /// <param name="value">An Integer or a Float.</param>
    /// <returns>Its value.</returns>
    private static double Real(RubyValue value) => value is RubyFloat real ? real.Value : (double)((RubyInteger)value).Value;

    /// <summary>
    /// Reads a value of the cases: a Hash with keys that are no texts as {"#pairs": [[key, value], ...]}.
    /// </summary>
    /// <param name="json">The value.</param>
    /// <returns>The Ruby value.</returns>
    private static RubyValue ValueOf(JsonElement json) => json.ValueKind switch
    {
        JsonValueKind.Number => json.TryGetInt64(out long whole) ? whole : new RubyFloat(json.GetDouble()),
        JsonValueKind.String => json.GetString(),
        JsonValueKind.True => true,
        JsonValueKind.False => false,
        JsonValueKind.Array => new RubyArray(json.EnumerateArray().Select(ValueOf)),
        JsonValueKind.Object => HashOf(json),
        _ => RubyNil.Value,
    };

    /// <summary>
    /// Reads a Hash of the cases.
    /// </summary>
    /// <param name="json">The object.</param>
    /// <returns>The Hash.</returns>
    private static RubyHash HashOf(JsonElement json)
    {
        var hash = new RubyHash();
        if (json.TryGetProperty("#pairs", out JsonElement pairs))
        {
            foreach (JsonElement pair in pairs.EnumerateArray())
            {
                hash[ValueOf(pair[0])] = ValueOf(pair[1]);
            }

            return hash;
        }

        foreach (JsonProperty property in json.EnumerateObject())
        {
            hash[property.Name] = ValueOf(property.Value);
        }

        return hash;
    }
}
