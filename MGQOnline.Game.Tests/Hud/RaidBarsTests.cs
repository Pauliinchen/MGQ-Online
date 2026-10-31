//----------------------------------------------------------------
//  RaidBarsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Hud;
using MGQOnline.Game.Raid;

namespace MGQOnline.Game.Tests.Hud;

/// <summary>
/// Covers the raid bars against the cases ui_raid_bar.rbx worked out before they moved to C#
/// (fixtures/hud/bars.json, written by make_bars_fixtures.rb there), the pools from a ledger that
/// holds what the script's pools held, and a share just short of the whole.
/// </summary>
public sealed class RaidBarsTests
{
    /// <summary>
    /// Asserts that every HP is written short as the script wrote it.
    /// </summary>
    [Fact]
    public void ShortNumbers_WritesEveryHpAsTheScriptDid()
    {
        foreach (JsonElement each in Cases().GetProperty("numbers").EnumerateArray())
        {
            Assert.Equal(each[2].GetString(), RaidBars.ShortNumbers(each[0].GetInt64(), each[1].GetInt64()));
        }
    }

    /// <summary>
    /// Asserts that every share left is written as the script's <c>format</c> wrote it, ties to the
    /// even tenth.
    /// </summary>
    [Fact]
    public void Percent_WritesEveryShareAsTheScriptDid()
    {
        foreach (JsonElement each in Cases().GetProperty("percents").EnumerateArray())
        {
            Assert.Equal(each[2].GetString(), RaidBars.Percent(each[0].GetInt64(), each[1].GetInt64()));
        }
    }

    /// <summary>
    /// Asserts that 99.95% of the HP left reads as the whole, as the share lies just above the tie.
    /// </summary>
    [Fact]
    public void Percent_ReadsNinetyNinePointNinetyFiveAsTheWhole() => Assert.Equal("100.0%", RaidBars.Percent(9995, 10_000));

    /// <summary>
    /// Asserts that repeated names are lettered as the script lettered them.
    /// </summary>
    [Fact]
    public void MapNames_LettersEveryTroopAsTheScriptDid()
    {
        foreach (JsonElement each in Cases().GetProperty("names").EnumerateArray())
        {
            List<string>? letters = each[1].ValueKind == JsonValueKind.Null ? null : [.. Texts(each[1])];
            Assert.Equal(Texts(each[2]), RaidBars.MapNames([.. Texts(each[0])], letters));
        }
    }

    /// <summary>
    /// Asserts that every battle shows the bar the script showed.
    /// </summary>
    [Fact]
    public void BattleBar_ShowsEveryBattleAsTheScriptDid()
    {
        foreach (JsonElement each in Cases().GetProperty("battles").EnumerateArray())
        {
            List<BattleEnemy> enemies = [.. each.GetProperty("enemies").EnumerateArray().Select(enemy => new BattleEnemy(
                enemy[0].GetString()!, enemy[1].GetInt64(), enemy[2].GetInt64(), enemy[3].GetBoolean(), enemy[4].GetString()))];
            RaidBar? bar = RaidBars.BattleBar(each.GetProperty("title").GetString()!, enemies, Ledger(each));
            Assert.Equal(Bar(each.GetProperty("bar")), Describe(bar));
        }
    }

    /// <summary>
    /// Asserts that every troop shows the map's bar the script showed.
    /// </summary>
    [Fact]
    public void MapBar_ShowsEveryTroopAsTheScriptDid()
    {
        JsonElement cases = Cases();
        Dictionary<string, long> own = cases.GetProperty("own_hp").EnumerateArray().ToDictionary(pair => pair[0].GetString()!, pair => pair[1].GetInt64());
        List<TroopEnemy> troop = [.. new[] { "Metatronne", "Metatronne", "Imp" }.Select(name => new TroopEnemy(name, own[name]))];
        foreach (JsonElement each in cases.GetProperty("maps").EnumerateArray())
        {
            List<string>? keys = each.GetProperty("kind").GetString() == "pools" ? [.. Texts(each.GetProperty("keys"))] : null;
            RaidBar bar = RaidBars.MapBar($"Boss {each.GetProperty("troop").GetInt32()}", keys, troop, each.GetProperty("factor").GetInt64(), null, Ledger(each));
            Assert.Equal(Bar(each.GetProperty("bar")), Describe(bar));
        }
    }

    /// <summary>
    /// Reads the cases.
    /// </summary>
    /// <returns>The cases.</returns>
    private static JsonElement Cases() => Fixtures.Read("hud", "bars.json");

    /// <summary>
    /// Reads texts.
    /// </summary>
    /// <param name="values">A JSON array of them.</param>
    /// <returns>The texts.</returns>
    private static IEnumerable<string> Texts(JsonElement values) => values.EnumerateArray().Select(value => value.GetString()!);

    /// <summary>
    /// Makes a ledger that holds the pools of a case, told at the moment the bars look at them.
    /// </summary>
    /// <param name="each">The case, its "pools" each [key, left, max, defeated].</param>
    /// <returns>The ledger.</returns>
    private static PoolLedger Ledger(JsonElement each)
    {
        var ledger = new PoolLedger(() => 0);
        foreach (JsonElement pool in each.GetProperty("pools").EnumerateArray())
        {
            ledger.Hear(new PoolWord(pool[0].GetString()!, pool[1].GetDouble(), pool[2].GetDouble(), pool[3].GetBoolean(), string.Empty), PoolSource.Fetched);
        }

        return ledger;
    }

    /// <summary>
    /// Writes a recorded bar as one line.
    /// </summary>
    /// <param name="bar">[title, [[name, hp, max], ...]] or null.</param>
    /// <returns>The line.</returns>
    private static string Bar(JsonElement bar) =>
        bar.ValueKind == JsonValueKind.Null ? "none" : bar[0].GetString() + ": " + string.Join("; ", bar[1].EnumerateArray().Select(gauge => $"{gauge[0].GetString()} {gauge[1].GetInt64()}/{gauge[2].GetInt64()}"));

    /// <summary>
    /// Writes a bar as one line.
    /// </summary>
    /// <param name="bar">The bar, <see langword="null"/> for none.</param>
    /// <returns>The line.</returns>
    private static string Describe(RaidBar? bar) =>
        bar is null ? "none" : bar.Title + ": " + string.Join("; ", bar.Gauges.Select(gauge => $"{gauge.Name} {gauge.Hp}/{gauge.Max}"));
}
