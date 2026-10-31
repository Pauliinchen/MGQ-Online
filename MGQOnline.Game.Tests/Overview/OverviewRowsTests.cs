//----------------------------------------------------------------
//  OverviewRowsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Overview;
using MGQOnline.Game.Tests.Teleports;

namespace MGQOnline.Game.Tests.Overview;

/// <summary>
/// Covers the World overview's lists of players: the golden world of fixtures/overview/rows.json,
/// 32 other players and the player in a party of four, as world_overview.rbx listed it in a Classic
/// world and a Raid World, and the serial that tells the scripts a list changed.
/// </summary>
public sealed class OverviewRowsTests
{
    /// <summary>
    /// The golden world.
    /// </summary>
    private readonly JsonElement golden = Fixtures.Read("overview", "rows.json");

    /// <summary>
    /// Asserts that every list holds the rows the script listed, in its order.
    /// </summary>
    /// <param name="world">"classic" or "raid".</param>
    [Theory]
    [InlineData("classic")]
    [InlineData("raid")]
    public void Lists_AreTheScripts(string world)
    {
        (PartyWorld party, OverviewState state) = World(world == "raid");
        JsonElement expected = golden.GetProperty(world);
        IReadOnlyList<OverviewRow> players = OverviewRows.Players(party.Room, state, "Me");

        Assert.Equal(Rows(expected.GetProperty("players")), players.Select(Describe));
        Assert.Equal(Lines(expected.GetProperty("lines")), OverviewRows.Lines(players).Select(line => line.Row is { } row ? $"player {row.Seat}" : $"place {line.Place}"));
        Assert.Equal(Rows(expected.GetProperty("party")), OverviewRows.Party(party.Room, state, "Me", false).Select(Describe));
        Assert.Equal(Rows(expected.GetProperty("raid_party")), OverviewRows.Party(party.Room, state, "Me", true).Select(Describe));
        Assert.Equal(Rows(expected.GetProperty("map")), OverviewRows.Map(party.Room, state, "Me").Select(Describe));
    }

    /// <summary>
    /// Asserts that the lists are built once a frame and their serial moves only when they changed.
    /// </summary>
    [Fact]
    public void Serial_MovesOnlyWhenAListChanged()
    {
        (PartyWorld party, OverviewState state) = World(true);
        var feed = new OverviewFeed();

        long first = feed.Take(1, () => OverviewRows.All(party.Room, state, "Me")).Serial;
        long same = feed.Take(2, () => OverviewRows.All(party.Room, state, "Me")).Serial;
        party.Tell(5, ("lv", "8"));
        long held = feed.Take(2, () => OverviewRows.All(party.Room, state, "Me")).Serial;
        long changed = feed.Take(3, () => OverviewRows.All(party.Room, state, "Me")).Serial;

        Assert.Equal((first, first, first), (same, held, changed - 1));
    }

    /// <summary>
    /// Builds the golden world: the room with every other player told and the player joined to
    /// Granberia's party, and what the player told the others.
    /// </summary>
    /// <param name="raid">Whether it is a Raid World.</param>
    /// <returns>The room and the player's state.</returns>
    private (PartyWorld Party, OverviewState State) World(bool raid)
    {
        var party = new PartyWorld(raid);
        foreach (JsonElement peer in golden.GetProperty("peers").EnumerateArray())
        {
            party.Tell(peer.GetProperty("seat").GetInt32(), [.. peer.GetProperty("state").EnumerateObject().Select(field => (field.Name, field.Value.GetString()!))]);
        }

        party.Room.Party.Join(party["p0000001"]);
        JsonElement own = golden.GetProperty("own");
        var state = new OverviewState();
        state.Take(new OverviewReading(own.GetProperty("level").GetInt32(), raid ? own.GetProperty("front").GetInt32() : null, own.GetProperty("story").GetString()!, false));
        state.Fields(own.GetProperty("place").GetString()!, raid);
        return (party, state);
    }

    /// <summary>
    /// Writes the rows the script listed as <see cref="Describe"/> does.
    /// </summary>
    /// <param name="rows">The rows.</param>
    /// <returns>Each row's text.</returns>
    private static IEnumerable<string> Rows(JsonElement rows) => rows.EnumerateArray().Select(row => JsonSerializer.Serialize(row, Options).Replace(" ", string.Empty, System.StringComparison.Ordinal));

    /// <summary>
    /// Writes the lines the script laid out.
    /// </summary>
    /// <param name="lines">The lines.</param>
    /// <returns>Each line's text.</returns>
    private static IEnumerable<string> Lines(JsonElement lines) => lines.EnumerateArray().Select(line => $"{line[0].GetString()} {(line[1].ValueKind == JsonValueKind.Number ? line[1].GetInt32().ToString(System.Globalization.CultureInfo.InvariantCulture) : line[1].GetString())}");

    /// <summary>
    /// Writes a row as the golden file holds it, without spaces.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>Its seat, name, place, level, story, ping, scene, whether it is a member, and its badge.</returns>
    private static string Describe(OverviewRow row) =>
        JsonSerializer.Serialize<object?[]>([row.Seat, row.Name, row.Place, row.Level, row.Story, Nil(row.Ping), Nil(row.Scene), row.Member,
            row.Badge is { } badge ? new object[] { badge.Text, badge.Leads } : null], Options).Replace(" ", string.Empty, System.StringComparison.Ordinal);

    /// <summary>
    /// Writes an empty text as the script's nil.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The text, <see langword="null"/> when empty.</returns>
    private static string? Nil(string text) => text.Length == 0 ? null : text;

    /// <summary>
    /// Writes texts as Ruby's JSON does, without escaping what needs none.
    /// </summary>
    private static readonly JsonSerializerOptions Options = new() { Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping };
}
