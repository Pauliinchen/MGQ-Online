//----------------------------------------------------------------
//  CoopIntakeGoldenTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Read the "rbn" of the battle's state from the fields the topic tells
//      Paulinchen  2026-10-30: Registered the topics over a live session
//                            - Gave the placement's enemies their ids and the battle's id
//                            - Created
//
//----------------------------------------------------------------

using System.Linq;
using System.Text.Json;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Battles.Live;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Coop;

/// <summary>
/// Replays through the co-op topics what battles_coop_hotjoin.rbx and battles_coop_join.rbx answered
/// before the host's intake moved to C# (fixtures/coop, written by make_fixtures.rb there): the
/// places of an encounter's enemies, the troop's enemies a request carries, and the refusals, the
/// players taken in and the "rbn" of a running battle.
/// </summary>
public sealed class CoopIntakeGoldenTests
{
    /// <summary>
    /// The context the topics answer on.
    /// </summary>
    private readonly BridgeContext _context = new(1, new QuietLog());

    /// <summary>
    /// Registers the co-op topics.
    /// </summary>
    public CoopIntakeGoldenTests()
    {
        CoopTopics.Register(_context, new LiveSession());
    }

    /// <summary>
    /// Gives the name of every placement case.
    /// </summary>
    /// <returns>The names.</returns>
    public static TheoryData<string> PlacementCases() => Names("placement.json");

    /// <summary>
    /// Gives the name of every intake case.
    /// </summary>
    /// <returns>The names.</returns>
    public static TheoryData<string> IntakeCases() => Names("intake.json");

    /// <summary>
    /// Asserts that an encounter's enemies stand where the script placed them.
    /// </summary>
    /// <param name="name">The case.</param>
    [Theory]
    [MemberData(nameof(PlacementCases))]
    public void Place_PlacesAsTheScriptDid(string name)
    {
        JsonElement entry = Case("placement.json", name);
        var request = new RubyHash
        {
            { "bid", "b1" },
            { "troop", Rows(entry.GetProperty("troop"), troop => new RubyArray { 0, troop[0].GetInt32(), troop[1].GetInt32(), troop[2].GetBoolean(), troop[3].GetBoolean() }) },
            { "queued", Rows(entry.GetProperty("queued"), queued => new RubyArray { queued[0].GetInt32(), queued[1].GetInt32(), queued[2].GetInt32() }) },
            { "entries", Rows(entry.GetProperty("entries"), enemy => new RubyArray { enemy[0].GetInt32(), enemy[1].GetInt32(), enemy[2].GetInt32() }) },
            { "screen", entry.GetProperty("screen").GetInt32() },
        };

        Assert.Equal(Numbers(entry.GetProperty("placed")), Numbers(_context.Ask(CoopTopics.Place, request)!));
    }

    /// <summary>
    /// Asserts that the troop's enemies a request carries are written and read as the script did.
    /// </summary>
    [Fact]
    public void Entries_WriteAndReadAsTheScriptDid()
    {
        JsonElement cases = Fixtures.Read("coop", "entries.json");
        foreach (JsonElement read in cases.GetProperty("reads").EnumerateArray())
        {
            Assert.Equal(Numbers(read.GetProperty("entries")), Numbers(_context.Ask(CoopTopics.ReadEntries, read.GetProperty("text").GetString())!));
        }

        foreach (JsonElement write in cases.GetProperty("writes").EnumerateArray())
        {
            RubyArray entries = Rows(write.GetProperty("entries"), entry => new RubyArray(entry.EnumerateArray().Select(field => (RubyValue)field.GetInt64())));
            Assert.Equal(write.GetProperty("text").GetString(), _context.Ask(CoopTopics.WriteEntries, entries)!.AsText());
        }
    }

    /// <summary>
    /// Asserts that a request with an encounter and one by choice are refused or taken in, and the
    /// battle's room told, as the scripts did.
    /// </summary>
    /// <param name="name">The case.</param>
    [Theory]
    [MemberData(nameof(IntakeCases))]
    public void Intake_DecidesAsTheScriptsDid(string name)
    {
        JsonElement entry = Case("intake.json", name);
        RubyHash facts = FactsOf(entry.GetProperty("facts"));
        JsonElement asked = entry.GetProperty("request");
        RubyHash encounter = Ask("encounter", facts, asked);
        RubyHash choice = Ask("choice", facts, asked);

        Assert.Equal(Text(entry.GetProperty("hot")), encounter["refusal"].IsNil ? null : encounter["refusal"].AsArray()[1].AsText());
        Assert.Equal(Numbers(entry.GetProperty("kept")), Numbers(encounter["kept"]));
        Assert.Equal(Numbers(entry.GetProperty("left")), Numbers(encounter["left"]));
        Assert.Equal(entry.GetProperty("room").GetInt32(), encounter["room"].AsInt());
        Assert.Equal(Pair(entry.GetProperty("pick")), choice["refusal"].IsNil ? null : string.Join("|", choice["refusal"].AsArray().Select(part => part.AsText())));
        Assert.Equal(entry.GetProperty("rbn").GetInt32(), _context.Ask(CoopTopics.Room, facts)!.AsHash()["rbn"].AsInt());
    }

    /// <summary>
    /// Asks the intake about a case's request.
    /// </summary>
    /// <param name="kind">How the player asks.</param>
    /// <param name="facts">The battle's facts.</param>
    /// <param name="asked">The request.</param>
    /// <returns>The answer.</returns>
    private RubyHash Ask(string kind, RubyHash facts, JsonElement asked) => _context.Ask(CoopTopics.Intake, new RubyHash
    {
        { "kind", kind },
        { "facts", facts },
        { "seat", asked.GetProperty("seat").GetInt32() },
        { "bid", Text(asked.GetProperty("bid")) },
        { "map", Text(asked.GetProperty("map")) },
        { "troop", Text(asked.GetProperty("troop")) },
        { "boss_troop", asked.GetProperty("boss_troop").GetBoolean() },
        { "seats", Text(asked.GetProperty("seats")) },
    })!.AsHash();

    /// <summary>
    /// Writes a case's facts as the scripts hand them over.
    /// </summary>
    /// <param name="facts">The facts.</param>
    /// <returns>The Hash.</returns>
    private static RubyHash FactsOf(JsonElement facts)
    {
        var hash = new RubyHash();
        foreach (JsonProperty fact in facts.EnumerateObject())
        {
            hash.Add(fact.Name, fact.Value.ValueKind switch
            {
                JsonValueKind.Null => RubyNil.Value,
                JsonValueKind.True => true,
                JsonValueKind.False => false,
                JsonValueKind.String => fact.Value.GetString(),
                JsonValueKind.Number => fact.Value.GetInt64(),
                _ => new RubyArray(fact.Value.EnumerateArray().Select(seat => (RubyValue)seat.GetInt64())),
            });
        }

        return hash;
    }

    /// <summary>
    /// Reads a case by its name.
    /// </summary>
    /// <param name="file">The case file.</param>
    /// <param name="name">The case.</param>
    /// <returns>The case.</returns>
    private static JsonElement Case(string file, string name) =>
        Fixtures.Read("coop", file).GetProperty("cases").EnumerateArray().First(entry => entry.GetProperty("name").GetString() == name);

    /// <summary>
    /// Gives the name of every case of a file.
    /// </summary>
    /// <param name="file">The case file.</param>
    /// <returns>The names.</returns>
    private static TheoryData<string> Names(string file) =>
        new(Fixtures.Read("coop", file).GetProperty("cases").EnumerateArray().Select(entry => entry.GetProperty("name").GetString()!));

    /// <summary>
    /// Writes a list of a case as the scripts hand it over.
    /// </summary>
    /// <param name="rows">The rows.</param>
    /// <param name="row">Writes one row.</param>
    /// <returns>The list.</returns>
    private static RubyArray Rows(JsonElement rows, System.Func<JsonElement, RubyArray> row) => new(rows.EnumerateArray().Select(entry => (RubyValue)row(entry)));

    /// <summary>
    /// Writes a nested list of numbers for comparing.
    /// </summary>
    /// <param name="value">The list.</param>
    /// <returns>Its numbers, nested lists in brackets.</returns>
    private static string Numbers(JsonElement value) => value.ValueKind == JsonValueKind.Array
        ? "[" + string.Join(",", value.EnumerateArray().Select(Numbers)) + "]"
        : value.GetInt64().ToString(System.Globalization.CultureInfo.InvariantCulture);

    /// <summary>
    /// Writes a nested list of numbers the topics answered for comparing.
    /// </summary>
    /// <param name="value">The list.</param>
    /// <returns>Its numbers, nested lists in brackets.</returns>
    private static string Numbers(RubyValue value) => value is RubyArray list
        ? "[" + string.Join(",", list.Select(Numbers)) + "]"
        : value.AsLong().ToString(System.Globalization.CultureInfo.InvariantCulture);

    /// <summary>
    /// Reads a text of a case.
    /// </summary>
    /// <param name="value">The text, or null.</param>
    /// <returns>The text, <see langword="null"/> for null.</returns>
    private static string? Text(JsonElement value) => value.ValueKind == JsonValueKind.Null ? null : value.GetString();

    /// <summary>
    /// Writes a case's [code, reason] for comparing.
    /// </summary>
    /// <param name="value">The pair, or null.</param>
    /// <returns>"code|reason", <see langword="null"/> for null.</returns>
    private static string? Pair(JsonElement value) => value.ValueKind == JsonValueKind.Null ? null : string.Join("|", value.EnumerateArray().Select(part => part.GetString()));

    /// <summary>
    /// A log that keeps nothing.
    /// </summary>
    private sealed class QuietLog : IBridgeLog
    {
        /// <inheritdoc />
        public void Write(string line)
        {
        }
    }
}
