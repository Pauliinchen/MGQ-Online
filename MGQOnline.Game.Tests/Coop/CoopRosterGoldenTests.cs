//----------------------------------------------------------------
//  CoopRosterGoldenTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Registered the topics over a live session
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.Json;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Battles.Live;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Coop;

/// <summary>
/// Replays through the co-op topics what battles_coop.rbx and battles_coop_level_sync.rbx did before
/// the battle's level, its roster and party lines and the troop repair moved to C#
/// (fixtures/coop/roster.json): the level and its log line, the players read with the fields left
/// out logged, the host's troop repaired, and the lines the host writes.
/// </summary>
public sealed class CoopRosterGoldenTests
{
    /// <summary>
    /// The context the topics answer on.
    /// </summary>
    private readonly BridgeContext _context = new(1, new QuietLog());

    /// <summary>
    /// Registers the co-op topics.
    /// </summary>
    public CoopRosterGoldenTests()
    {
        CoopTopics.Register(_context, new LiveSession());
    }

    /// <summary>
    /// Gives the name of every roster case.
    /// </summary>
    /// <returns>The names.</returns>
    public static TheoryData<string> RosterCases() => new(Cases().GetProperty("rosters").EnumerateArray().Select(entry => entry.GetProperty("name").GetString()!));

    /// <summary>
    /// Asserts that the battle's level and its log line are the script's.
    /// </summary>
    [Fact]
    public void Level_IsTheScripts()
    {
        foreach (JsonElement entry in Cases().GetProperty("levels").EnumerateArray())
        {
            var players = new RubyArray();
            foreach (JsonElement player in entry.GetProperty("players").EnumerateArray())
            {
                players.Add(new RubyArray { player[0].GetInt32(), player[1].GetBoolean(), Plain(player[3]), Plain(player[2]) });
            }

            RubyHash answer = _context.Ask(CoopTopics.Level, new RubyHash { { "raid", entry.GetProperty("raid").GetBoolean() }, { "players", players } })!.AsHash();

            Assert.Equal(Text(entry.GetProperty("level")), Text(answer["level"]));
            Assert.Equal(entry.GetProperty("logs")[0].GetString(), "level sync: " + answer["log"].AsText());
        }
    }

    /// <summary>
    /// Asserts that a roster reads as the script read it: its players, the fields left out, the
    /// host's troop repaired against this game's, and its level and turn.
    /// </summary>
    /// <param name="name">The case.</param>
    [Theory]
    [MemberData(nameof(RosterCases))]
    public void ReadRoster_ReadsAsTheScriptDid(string name)
    {
        JsonElement entry = Cases().GetProperty("rosters").EnumerateArray().First(found => found.GetProperty("name").GetString() == name);
        RubyHash answer = _context.Ask(CoopTopics.ReadRoster, Request(entry))!.AsHash();

        Assert.Equal(Text(Normalized(entry.GetProperty("players"))), Text(answer["players"]));
        Assert.Equal(Lines(entry.GetProperty("player_logs")), Logged(answer["dropped"], null));
        Assert.Equal(Text(entry.GetProperty("repaired")), Text(answer["enemies"]));
        Assert.Equal(Lines(entry.GetProperty("repair_logs")), Logged(answer["enemy_dropped"], answer["lacking"]));
        Assert.Equal((Text(entry.GetProperty("level")), Text(entry.GetProperty("turn")), entry.GetProperty("enemies_size").GetInt32()),
            (Text(answer["level"]), Text(answer["turn"]), answer["size"].AsInt()));
    }

    /// <summary>
    /// Asserts that the troop a host tells once it changed reads as the script read it.
    /// </summary>
    [Fact]
    public void ReadTroop_ReadsAsTheScriptDid()
    {
        foreach (JsonElement entry in Cases().GetProperty("troops").EnumerateArray())
        {
            RubyHash answer = _context.Ask(CoopTopics.ReadTroop, Request(entry))!.AsHash();

            Assert.Equal(Text(entry.GetProperty("repaired")), Text(answer["enemies"]));
            Assert.Equal(Lines(entry.GetProperty("repair_logs")), Logged(answer["enemy_dropped"], answer["lacking"]));
            Assert.Equal(Text(entry.GetProperty("names")), Text(answer["names"]));
        }
    }

    /// <summary>
    /// Asserts that the host writes the roster, a late roster and the party byte for byte as the
    /// script did.
    /// </summary>
    [Fact]
    public void Write_WritesTheScriptsLines()
    {
        foreach (JsonElement entry in Cases().GetProperty("writes").EnumerateArray())
        {
            string kind = entry.GetProperty("kind").GetString()!;
            RubyValue written = kind == "party"
                ? _context.Ask(CoopTopics.WriteParty, Plain(entry.GetProperty("players")))!
                : _context.Ask(CoopTopics.WriteRoster, Roster(entry, kind == "late"))!;

            Assert.Equal(entry.GetProperty("line").GetString(), written.AsText());
        }
    }

    /// <summary>
    /// Asserts that enemies the scripts hand over as they parsed them repair as from a line: a field
    /// of another kind takes this game's place, an enemy that is no list keeps this game's troop.
    /// </summary>
    [Fact]
    public void Repair_PlainEnemies_RepairsAsFromALine()
    {
        RubyHash place = Repair(new RubyArray { new RubyArray { 31, "Float", 300 } });
        RubyHash kept = Repair(new RubyArray { new RubyArray { 31, 1, 2, 0 }, "Integer" });

        Assert.Equal("[[31,320,300,0]]", Text(place["enemies"]));
        Assert.Equal("[[x,Float,the host's enemy],[mark,NilClass,the host's enemy]]", Text(place["enemy_dropped"]));
        Assert.True(kept["enemies"].IsNil);
        Assert.Equal("[[enemy,Integer,the host's troop for its]]", Text(kept["enemy_dropped"]));
    }

    /// <summary>
    /// Asserts what a host does once players left: the others fight on, a host alone fights on with
    /// their own team, and the battle server keeps a battle for its last player and ends one every
    /// player left.
    /// </summary>
    [Fact]
    public void Settle_DecidesByWhoStays()
    {
        Assert.Equal("none", Settled([0, 2], [2], false)["outcome"].AsText());
        Assert.Equal("reform|[0,3]|[2]", Outcome(Settled([0, 2, 3], [3], false)));
        Assert.Equal("solo|[0]|[2]", Outcome(Settled([0, 2], [], false)));
        Assert.Equal("reform|[2]|[3]", Outcome(Settled([2, 3], [2], true)));
        Assert.Equal("abandon|[]|[2,3]", Outcome(Settled([2, 3], [], true)));
    }

    /// <summary>
    /// Reads the cases.
    /// </summary>
    /// <returns>The cases.</returns>
    private static JsonElement Cases() => Fixtures.Read("coop", "roster.json");

    /// <summary>
    /// Writes the request of a case that reads a line against this game's troop.
    /// </summary>
    /// <param name="entry">The case.</param>
    /// <returns>The request.</returns>
    private static RubyHash Request(JsonElement entry) => new()
    {
        { "line", entry.GetProperty("line").GetString() },
        { "own", Plain(entry.GetProperty("own")) },
        { "count", entry.GetProperty("count").GetInt32() },
    };

    /// <summary>
    /// Writes the request of a case that writes a roster.
    /// </summary>
    /// <param name="entry">The case.</param>
    /// <param name="late">Whether the roster is for players who join late.</param>
    /// <returns>The request.</returns>
    private static RubyHash Roster(JsonElement entry, bool late)
    {
        var request = new RubyHash { { "enemies", Plain(entry.GetProperty("enemies")) }, { "players", Plain(entry.GetProperty("players")) } };
        request.Add("level", late ? RubyNil.Value : entry.GetProperty("level").GetInt32());
        if (late)
        {
            request.Add("turn", entry.GetProperty("turn").GetInt32());
        }

        return request;
    }

    /// <summary>
    /// Repairs enemies as the scripts hand them over against a troop of one enemy at (320, 300).
    /// </summary>
    /// <param name="enemies">The enemies.</param>
    /// <returns>The answer.</returns>
    private RubyHash Repair(RubyArray enemies) => _context.Ask(CoopTopics.Repair, new RubyHash
    {
        { "enemies", enemies },
        { "own", new RubyArray { new RubyArray { 320, 300 } } },
        { "count", 100 },
    })!.AsHash();

    /// <summary>
    /// Asks what a host does once players left, its own seat 0.
    /// </summary>
    /// <param name="players">The battle's players.</param>
    /// <param name="guestsIn">The guests still in.</param>
    /// <param name="served">Whether the battle server hosts it.</param>
    /// <returns>The answer.</returns>
    private RubyHash Settled(int[] players, int[] guestsIn, bool served) => _context.Ask(CoopTopics.Settle, new RubyHash
    {
        { "players", new RubyArray(players.Select(seat => (RubyValue)seat)) },
        { "own", 0 },
        { "in", new RubyArray(guestsIn.Select(seat => (RubyValue)seat)) },
        { "served", served },
    })!.AsHash();

    /// <summary>
    /// Writes a decision for comparing.
    /// </summary>
    /// <param name="answer">The decision.</param>
    /// <returns>"outcome|staying|left".</returns>
    private static string Outcome(RubyHash answer) => $"{answer["outcome"].AsText()}|{Text(answer["staying"])}|{Text(answer["left"])}";

    /// <summary>
    /// Writes the log lines of fields left out as the scripts write them, each field and kind once,
    /// then the line of the enemies this game lacks.
    /// </summary>
    /// <param name="drops">[field, kind, owner] each.</param>
    /// <param name="lacking">The ids this game lacks, nil for none asked.</param>
    /// <returns>The lines.</returns>
    private static List<string> Logged(RubyValue drops, RubyValue? lacking)
    {
        List<string> lines = [.. drops.AsArray().Select(drop => drop.AsArray())
            .DistinctBy(drop => (drop[0].AsText(), drop[1].AsText()))
            .Select(drop => $"co-op battle: dropped {drop[2].AsText()} {drop[0].AsText()} another game sent as {drop[1].AsText()}")];
        if (lacking is RubyArray ids && ids.Count > 0)
        {
            lines.Add($"co-op battle: the host's troop holds enemies this game lacks ({string.Join(", ", ids.Select(id => id.AsLong()))}); it keeps its own");
        }

        return lines;
    }

    /// <summary>
    /// Reads log lines of a case.
    /// </summary>
    /// <param name="lines">The lines.</param>
    /// <returns>The lines.</returns>
    private static List<string> Lines(JsonElement lines) => [.. lines.EnumerateArray().Select(line => line.GetString()!)];

    /// <summary>
    /// Takes the players the script read with their HP and MP as the battle takes them: a list's
    /// whole numbers, a whole number alone as a list of it, anything else as none.
    /// </summary>
    /// <param name="players">The players.</param>
    /// <returns>The players, plain.</returns>
    private static RubyArray Normalized(JsonElement players) => new(players.EnumerateArray().Select(player =>
    {
        RubyArray fields = Plain(player).AsArray();
        var vitals = new RubyArray(fields[3].AsArray().Select<RubyValue, RubyValue>(entry => entry switch
        {
            RubyArray list => new RubyArray(list.Select(item => item is RubyInteger ? item : RubyNil.Value)),
            RubyInteger => new RubyArray { entry },
            _ => RubyNil.Value,
        }));
        return (RubyValue)new RubyArray(fields.Select((field, index) => index == 3 ? vitals : field));
    }));

    /// <summary>
    /// Writes a value of a case as the scripts hand it over.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The plain value.</returns>
    private static RubyValue Plain(JsonElement value) => value.ValueKind switch
    {
        JsonValueKind.Null => RubyNil.Value,
        JsonValueKind.True => true,
        JsonValueKind.False => false,
        JsonValueKind.Number => value.GetInt64(),
        JsonValueKind.String => value.GetString(),
        _ => new RubyArray(value.EnumerateArray().Select(Plain)),
    };

    /// <summary>
    /// Writes a value of a case for comparing.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>Its text, lists in brackets.</returns>
    private static string Text(JsonElement value) => Text(Plain(value));

    /// <summary>
    /// Writes a value the topics answered for comparing.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>Its text, lists in brackets.</returns>
    private static string Text(RubyValue value) => value switch
    {
        RubyArray list => "[" + string.Join(",", list.Select(Text)) + "]",
        RubyNil => "nil",
        RubyInteger number => number.Value.ToString(CultureInfo.InvariantCulture),
        RubyString text => text.Text,
        _ => value.ToString() ?? string.Empty,
    };

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
