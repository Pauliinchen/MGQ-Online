//----------------------------------------------------------------
//  EnterRulesTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Checked entering a world whose data scan has another format
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Worlds;

namespace MGQOnline.Game.Tests.Worlds;

/// <summary>
/// Covers the rules a world is entered by against what world_screen.rbx did (fixtures/entering/rules.json).
/// </summary>
public sealed class EnterRulesTests
{
    /// <summary>
    /// The golden cases.
    /// </summary>
    private readonly JsonElement _cases = Fixtures.Read("entering", "rules.json");

    /// <summary>
    /// Asserts that a world being set up or full is refused as the screen refused it.
    /// </summary>
    [Fact]
    public void OpenNow_RefusesAsTheScreenDid()
    {
        foreach (JsonElement entry in _cases.GetProperty("open").EnumerateArray())
        {
            IReadOnlyList<EnterDone>? refused = EnterRules.OpenNow("Haven", entry.GetProperty("start").GetString()!, entry.GetProperty("online").GetInt32(), entry.GetProperty("seats").GetInt32(), entry.GetProperty("me_online").GetBoolean());

            Assert.Equal(entry.GetProperty("open").GetBoolean(), refused == null);
            Assert.Equal(Golden(entry), Recorded(refused ?? []));
        }
    }

    /// <summary>
    /// Asserts that differing game data lets in, asks or refuses as the screen did.
    /// </summary>
    [Fact]
    public void Data_DecidesAsTheScreenDid()
    {
        foreach (JsonElement entry in _cases.GetProperty("data").EnumerateArray())
        {
            JsonElement parts = entry.GetProperty("differing");
            IReadOnlyList<string>? differing = parts.ValueKind == JsonValueKind.Null ? null : [.. parts.EnumerateArray().Select(part => part.GetString()!)];
            (bool allowed, IReadOnlyList<EnterDone> did) = EnterRules.Data("Haven", differing, entry.GetProperty("strict").GetBoolean(), entry.GetProperty("mods").GetString(), entry.GetProperty("own").GetBoolean(), entry.GetProperty("parked").GetBoolean(), entry.GetProperty("accepted").GetBoolean(), "OWN DATA");

            Assert.Equal(entry.GetProperty("allowed").GetBoolean(), allowed);
            Assert.Equal(Golden(entry), Recorded(did));
        }
    }

    /// <summary>
    /// Asserts that a data scan of another format is told apart from an unknown one and from one
    /// that differs.
    /// </summary>
    [Fact]
    public void OtherFormat_TellsAScanOfAnotherFormat()
    {
        Assert.Equal([true, false, false, false], new[] { "1:a.b", "2:c.d", "", null }.Select(other => GameDataCompare.OtherFormat("2:a.b", other)));
        Assert.False(GameDataCompare.OtherFormat("", "1:a.b"));
    }

    /// <summary>
    /// Asserts that the creator of a world whose data scan has another format is asked to update it,
    /// and that other games are kept out only while the world is for the same data only.
    /// </summary>
    [Fact]
    public void OtherScan_AsksTheCreatorAndKeepsOthersOutOfAStrictWorld()
    {
        (bool ownAllowed, IReadOnlyList<EnterDone> own) = EnterRules.OtherScan("Haven", true, true);
        (bool strictAllowed, IReadOnlyList<EnterDone> strict) = EnterRules.OtherScan("Haven", true, false);
        (bool lenientAllowed, IReadOnlyList<EnterDone> lenient) = EnterRules.OtherScan("Haven", false, false);

        Assert.Equal((false, EnterRules.Confirm, "own_data"), (ownAllowed, own.Single().Kind, own.Single().What));
        Assert.False(strictAllowed);
        Assert.Equal([EnterRules.Buzz, EnterRules.Say, EnterRules.Back], strict.Select(done => done.Kind));
        Assert.Equal((true, 0), (lenientAllowed, lenient.Count));
    }

    /// <summary>
    /// Asserts that a player starts where the screen started them.
    /// </summary>
    [Fact]
    public void StartOf_StartsAsTheScreenDid()
    {
        foreach (JsonElement entry in _cases.GetProperty("start").EnumerateArray())
        {
            JsonElement choose = entry.GetProperty("choose");
            JsonElement start = entry.GetProperty("start");
            IReadOnlyList<EnterDone> did = EnterRules.StartOf("Haven", entry.GetProperty("raid").GetBoolean(), choose.ValueKind == JsonValueKind.Null ? null : choose.GetBoolean(), start.GetString(), entry.GetProperty("new_player").GetBoolean(), entry.GetProperty("own").GetBoolean());

            Assert.Equal(Golden(entry), Recorded(did));
        }
    }

    /// <summary>
    /// Writes what a case says the screen did, one line each.
    /// </summary>
    /// <param name="entry">The case.</param>
    /// <returns>The lines.</returns>
    private static List<string> Golden(JsonElement entry) =>
        [.. entry.GetProperty("did").EnumerateArray().Where(done => done[0].GetString() != "entered").Select(done => JsonSerializer.Serialize(done))];

    /// <summary>
    /// Writes what the rules did as the recorder wrote it.
    /// </summary>
    /// <param name="did">What they did.</param>
    /// <returns>The lines.</returns>
    private static List<string> Recorded(IReadOnlyList<EnterDone> did) => [.. did.Select(done => JsonSerializer.Serialize(done.Kind switch
    {
        EnterRules.Say => (object[])[done.Kind, done.Text!],
        EnterRules.Confirm => [done.Kind, done.What!, done.Text!, done.Yes!],
        EnterRules.Choices => [done.Kind, done.Offered!.Select(choice => choice.Answer).ToArray(), done.Offered!.Select(choice => choice.Label).ToArray()],
        _ => [done.Kind],
    }))];
}
