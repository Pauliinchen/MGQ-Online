//----------------------------------------------------------------
//  SquadMathTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Squads;

namespace MGQOnline.Game.Tests.Squads;

/// <summary>
/// Covers the squad math against the golden cases recorded from coop_squad.rbx and arrange of
/// battles_coop.rbx before the rules left them (fixtures/squad/squad.json).
/// </summary>
public sealed class SquadMathTests
{
    /// <summary>
    /// The golden cases.
    /// </summary>
    private readonly JsonElement _cases = Fixtures.Read("squad", "squad.json");

    /// <summary>
    /// Asserts that places split as the scripts split them, none for no player.
    /// </summary>
    [Fact]
    public void Split_SplitsAsTheScriptsDid()
    {
        foreach (JsonElement entry in Cases("split"))
        {
            Assert.Equal(Numbers(entry.GetProperty("places")), SquadMath.Split(entry.GetProperty("total").GetInt32(), entry.GetProperty("count").GetInt32()));
        }
    }

    /// <summary>
    /// Asserts that a party's players share the places as the scripts shared them.
    /// </summary>
    [Fact]
    public void Shares_ShareAsTheScriptsDid()
    {
        foreach (JsonElement entry in Cases("share"))
        {
            SquadShare share = SquadMath.Shares(entry.GetProperty("count").GetInt32(), entry.GetProperty("max").GetInt32())[entry.GetProperty("position").GetInt32()];

            Assert.Equal(Numbers(entry.GetProperty("share")), new[] { share.Front, share.Bench });
        }
    }

    /// <summary>
    /// Asserts that a Raid World's squads of both fights and the larger one are the scripts'.
    /// </summary>
    [Fact]
    public void RaidShare_SizesAsTheScriptsDid()
    {
        foreach (JsonElement entry in Cases("raid"))
        {
            SquadRules rules = RulesOf(entry.GetProperty("rules"))!.Value;
            int max = entry.GetProperty("max").GetInt32();
            SquadShare regular = SquadMath.RaidShare(rules, max, false);
            SquadShare raid = SquadMath.RaidShare(rules, max, true);

            Assert.Equal(Numbers(entry.GetProperty("regular")), new[] { regular.Front, regular.Bench });
            Assert.Equal(Numbers(entry.GetProperty("raid")), new[] { raid.Front, raid.Bench });
            Assert.Equal(entry.GetProperty("largest").GetInt32(), SquadMath.LargestSquad(rules, max));
        }
    }

    /// <summary>
    /// Asserts that players are ordered as the scripts ordered them, ids byte by byte.
    /// </summary>
    [Fact]
    public void Ranked_OrdersAsTheScriptsDid()
    {
        foreach (JsonElement entry in Cases("rank"))
        {
            (string Id, bool First)[] players = entry.GetProperty("players").EnumerateArray().Select(pair => (pair[0].GetString()!, pair[1].GetBoolean())).ToArray();

            Assert.Equal(entry.GetProperty("order").EnumerateArray().Select(id => id.GetString()), SquadMath.Ranked(players).Select(index => players[index].Id));
        }
    }

    /// <summary>
    /// Asserts that a battle's players are arranged as arrange of battles_coop.rbx arranged them.
    /// </summary>
    [Fact]
    public void Arrange_ArrangesAsTheScriptsDid()
    {
        foreach (JsonElement entry in Cases("arrange"))
        {
            SquadPlayer[] players = entry.GetProperty("players").EnumerateArray()
                .Select(fields => new SquadPlayer(fields[0].GetString()!, fields[1].GetBoolean(), fields[2].GetInt32(), fields[3].GetInt32())).ToArray();
            ArrangedPlayer[] arranged = SquadMath.Arrange(RulesOf(entry.GetProperty("rules")), entry.GetProperty("raid").GetBoolean(), entry.GetProperty("backline").GetBoolean(), players);

            Assert.Equal(
                entry.GetProperty("arranged").EnumerateArray().Select(Numbers),
                arranged.Select(player => new[] { player.Index, player.Share.Front, player.Share.Bench }));
        }
    }

    /// <summary>
    /// Asserts that a team past its cap leaves out the companions the scripts left out.
    /// </summary>
    [Fact]
    public void PastCap_LeavesOutAsTheScriptsDid()
    {
        foreach (JsonElement entry in Cases("past_cap"))
        {
            HashSet<int> luka = Numbers(entry.GetProperty("luka")).ToHashSet();

            Assert.Equal(
                Numbers(entry.GetProperty("standby")),
                SquadMath.PastCap(Numbers(entry.GetProperty("team")), luka, entry.GetProperty("cap").GetInt32(), entry.GetProperty("keep_luka").GetBoolean()));
        }
    }

    /// <summary>
    /// Lists the cases of a kind.
    /// </summary>
    /// <param name="kind">The kind, such as "split".</param>
    /// <returns>The cases.</returns>
    private IEnumerable<JsonElement> Cases(string kind) => _cases.GetProperty(kind).EnumerateArray();

    /// <summary>
    /// Reads a list of whole numbers.
    /// </summary>
    /// <param name="json">The list.</param>
    /// <returns>The numbers.</returns>
    private static int[] Numbers(JsonElement json) => json.EnumerateArray().Select(number => number.GetInt32()).ToArray();

    /// <summary>
    /// Reads squad rules by the names the scripts use.
    /// </summary>
    /// <param name="json">The rules, or null.</param>
    /// <returns>The rules, <see langword="null"/> for null.</returns>
    private static SquadRules? RulesOf(JsonElement json) => json.ValueKind == JsonValueKind.Null
        ? null
        : new SquadRules(json.GetProperty("luka").GetBoolean(), json.GetProperty("formation").GetInt32(), json.GetProperty("front").GetInt32(), json.GetProperty("raid_front").GetInt32());
}
