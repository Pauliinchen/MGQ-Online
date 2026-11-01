//----------------------------------------------------------------
//  EdgeArrowsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-01: Kept the players picked and the log alone, the Mod Framework's markers placing the arrows
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Hud;

namespace MGQOnline.Game.Tests.Hud;

/// <summary>
/// Covers the edge arrows against the cases ui_edge_arrows.rbx pointed at and logged before its
/// rules moved to C# (fixtures/hud/arrows.json, written by make_arrows_fixtures.rb there), and
/// players at the same distance taken by their ids.
/// </summary>
public sealed class EdgeArrowsTests
{
    /// <summary>
    /// The screen's width in the cases.
    /// </summary>
    private const int ScreenWidth = 640;

    /// <summary>
    /// The screen's height in the cases.
    /// </summary>
    private const int ScreenHeight = 480;

    /// <summary>
    /// Asserts that every frame points at the players the script pointed at and logs its lines.
    /// </summary>
    [Fact]
    public void Note_PointsAndLogsEveryFrameAsTheScriptDid()
    {
        var logs = new List<string>();
        var arrows = new EdgeArrows(logs.Add);
        foreach (JsonElement frame in Cases().GetProperty("frames").EnumerateArray())
        {
            logs.Clear();
            bool raid = frame.GetProperty("raid").GetBoolean();
            List<ArrowCandidate> players = [.. frame.GetProperty("players").EnumerateArray().Select(Player)];
            string? reason = frame.TryGetProperty("reason", out JsonElement hidden) ? hidden.GetString() : null;
            List<ArrowCandidate> targets = reason is null ? EdgeArrows.Targets(players, raid, ScreenWidth, ScreenHeight) : [];
            arrows.Note(reason, targets, players, raid, ScreenWidth, ScreenHeight);

            Assert.Equal(
                frame.GetProperty("targets").EnumerateArray().Select(target => string.Join(",", Ints(target))),
                targets.Select(target => $"{target.Seat},{target.ScreenX},{target.MiddleY},{target.Tiles}"));
            Assert.Equal(frame.GetProperty("logs").EnumerateArray().Select(line => line.GetString()), logs);
        }
    }

    /// <summary>
    /// Asserts that of more players than arrows at the same distance the ones with the lower ids
    /// get one.
    /// </summary>
    [Fact]
    public void Targets_TakesPlayersAtTheSameDistanceByTheirIds()
    {
        List<ArrowCandidate> players = [.. Enumerable.Range(0, 10).Select(index => new ArrowCandidate(index, $"id{9 - index}", "Who", true, true, false, -10, 100, 5, "white"))];

        List<ArrowCandidate> targets = EdgeArrows.Targets(players, true, ScreenWidth, ScreenHeight);

        Assert.Equal(["id0", "id1", "id2", "id3", "id4", "id5", "id6", "id7"], targets.Select(target => target.Id));
    }

    /// <summary>
    /// Reads the cases.
    /// </summary>
    /// <returns>The cases.</returns>
    private static JsonElement Cases() => Fixtures.Read("hud", "arrows.json");

    /// <summary>
    /// Reads whole numbers.
    /// </summary>
    /// <param name="values">A JSON array of them.</param>
    /// <returns>The numbers.</returns>
    private static IEnumerable<int> Ints(JsonElement values) => values.EnumerateArray().Select(value => value.GetInt32());

    /// <summary>
    /// Reads a player of a frame as the script made them.
    /// </summary>
    /// <param name="each">[seat, id, {"x", "y", "tiles", "away", "map", "member", "color", "ghost"}].</param>
    /// <returns>The player.</returns>
    private static ArrowCandidate Player(JsonElement each)
    {
        int seat = each[0].GetInt32();
        string id = each[1].GetString()!;
        JsonElement fields = each[2];
        bool Flag(string name) => fields.TryGetProperty(name, out JsonElement value) && value.ValueKind == JsonValueKind.True;
        int Number(string name, int fallback) => fields.TryGetProperty(name, out JsonElement value) ? value.GetInt32() : fallback;
        bool ghost = !(fields.TryGetProperty("ghost", out JsonElement shown) && shown.ValueKind == JsonValueKind.False);
        string name = char.ToUpperInvariant(id[0]) + id[1..];
        string color = fields.TryGetProperty("color", out JsonElement named) ? named.GetString()! : "white";
        return new ArrowCandidate(seat, id, $"{name} (seat {seat})", !Flag("away"), ghost && Number("map", 5) == 5, Flag("member"), Number("x", 0), Number("y", 0), Number("tiles", 0), color);
    }
}
