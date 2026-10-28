//----------------------------------------------------------------
//  PartyRewardsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Text.Json;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Catchup;

namespace MGQOnline.Game.Tests.Catchup;

/// <summary>
/// Covers the rewards a party member of a Classic world catches up with, as the DLL hands them to
/// the scripts.
/// </summary>
public sealed class PartyRewardsTests
{
    /// <summary>
    /// Asserts that the generated tables give the scripts the constants of coop_story_rewards.rbx
    /// they replace (fixtures/catchup/party_rewards.json, written from the constants by
    /// Relay/seed/story/make_seed.rb).
    /// </summary>
    [Fact]
    public void Write_GivesTheConstantsTheTablesReplace()
    {
        using JsonDocument tables = JsonDocument.Parse(TableFiles.TablesText());
        JsonElement golden = Fixtures.Read("catchup", "party_rewards.json").GetProperty("rewards");

        RubyHash written = PartyRewards.Write(CatchupTables.Read(tables.RootElement));

        Assert.Equal(CatchupEngineTests.ValueOf(golden), written);
    }

    /// <summary>
    /// Asserts that tables without rows give the scripts empty lists.
    /// </summary>
    [Fact]
    public void Write_KeepsEveryListWithoutRows()
    {
        RubyHash written = PartyRewards.Write(CatchupTables.Empty);

        Assert.Equal((0, 0, 0), (written["skills"].AsArray().Count, written["groups"].AsArray().Count, written["chests"].AsArray().Count));
        Assert.Equal(new RubyHash { { "skills", new RubyArray() }, { "actors", new RubyArray() }, { "items", new RubyArray() } }, written["final"]);
    }
}
