//----------------------------------------------------------------
//  EnterRulesTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Checked the warning of a game whose data differs in place of the data's golden cases
//                            - Left out the golden cases of a world entered with mods parked
//                            - Checked entering a world whose data scan has another format
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Worlds;

namespace MGQOnline.Game.Tests.Worlds;

/// <summary>
/// Covers the rules a world is entered by against what world_screen.rbx did (fixtures/entering/rules.json,
/// whose data cases record the question and the refusal that the warning replaced).
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
    /// Asserts that a game whose data differs is warned in plain words, the first parts by name, and
    /// that one that matches or cannot be compared is not.
    /// </summary>
    [Fact]
    public void DataWarning_NamesWhatDiffersAndNothingElse()
    {
        Assert.Equal("Your game differs from the creator's of Haven. Some things may not work as in their game.",
            EnterRules.DataWarning("Haven", ["skills", "items", "states", "maps", "troops"]));
        Assert.Null(EnterRules.DataWarning("Haven", []));
        Assert.Null(EnterRules.DataWarning("Haven", null));
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
