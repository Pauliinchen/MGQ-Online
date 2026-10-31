//----------------------------------------------------------------
//  KeyScopesTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Checked that a Classic party keeps its keys by the reviewed list
//                            - Created
//
//----------------------------------------------------------------

using System.Text.Json;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers who keeps each story key, read from the one reviewed list for both world types.
/// </summary>
public sealed class KeyScopesTests
{
    /// <summary>
    /// The reviewed list of the cases: a work variable, a personal, a shared and a whole-world
    /// variable, a chest switch, a party chest that is also a Raid world chest, and a party chest
    /// alone.
    /// </summary>
    private const string List = """
        {"rev": 3, "tables": {
          "keys": [{"key": "v57", "kind": "personal", "work": true}, {"key": "v1050", "kind": "personal"}, {"key": "v1001", "kind": "one_way"}, {"key": "v3005", "kind": "one_way", "wholeWorld": true},
                   {"key": "s2045", "kind": "chest"}, {"key": "s60", "kind": "shared", "work": true}, {"key": "s70", "kind": "shared"}],
          "events": [{"key": "ss215.*.*", "share": "shared"}],
          "party_chests": [{"key": "ss215.27.A"}, {"key": "ss588.9.A"}],
          "chests": [{"key": "ss588.9.A", "items": [606], "part": "1", "step": 7, "flags": [], "order": 10}]}, "index": null}
        """;

    /// <summary>
    /// Asserts that in a Classic party the list decides who keeps a key, not the Classic story's
    /// ranges: a key it keeps personal or leaves out stays each member's own, while its shared
    /// keys are the leader's story.
    /// </summary>
    [Fact]
    public void Classic_KeepsAKeyTheListKeepsPersonalEachMembersOwn()
    {
        KeyScopes scopes = KeyScopes.Classic(Read());

        Assert.Equal(
            [StoryScope.Player, StoryScope.Player, StoryScope.Work, StoryScope.World, StoryScope.World],
            new[] { scopes.ScopeOf(StoryKey.Variable(1050)), scopes.ScopeOf(StoryKey.Switch(1500)), scopes.ScopeOf(StoryKey.Variable(57)),
                scopes.ScopeOf(StoryKey.Variable(1001)), scopes.ScopeOf(StoryKey.SelfSwitch(215, 28, "A")) });
    }

    /// <summary>
    /// Asserts that a switch of kind <c>chest</c> is a party key in a Classic party.
    /// </summary>
    [Fact]
    public void Classic_MakesAChestSwitchAPartyKey()
    {
        Assert.Equal(StoryScope.Party, KeyScopes.Classic(Read()).ScopeOf(StoryKey.Switch(2045)));
    }

    /// <summary>
    /// Asserts that a chest both in <c>party_chests</c> and in the Raid World's <c>chests</c> is a
    /// party key in a Classic party, as is a party chest alone.
    /// </summary>
    [Fact]
    public void Classic_MakesAKeyInBothListsAPartyKey()
    {
        KeyScopes scopes = KeyScopes.Classic(Read());

        Assert.Equal(
            (StoryScope.Party, StoryScope.Party),
            (scopes.ScopeOf(StoryKey.SelfSwitch(588, 9, "A")), scopes.ScopeOf(StoryKey.SelfSwitch(215, 27, "A"))));
    }

    /// <summary>
    /// Asserts that a Raid World has no party: a chest is each player's own unless it is a world
    /// chest, and a whole-world value is told apart from the story's.
    /// </summary>
    [Fact]
    public void Raid_KeepsChestsEachPlayersOwnButTheWorldChests()
    {
        KeyScopes scopes = KeyScopes.Raid(Read());

        Assert.Equal(
            [StoryScope.Player, StoryScope.World, StoryScope.Player, StoryScope.Work, StoryScope.World, StoryScope.WholeWorld, StoryScope.World],
            new[] { scopes.ScopeOf(StoryKey.SelfSwitch(215, 27, "A")), scopes.ScopeOf(StoryKey.SelfSwitch(588, 9, "A")), scopes.ScopeOf(StoryKey.Switch(2045)),
                scopes.ScopeOf(StoryKey.Variable(57)), scopes.ScopeOf(StoryKey.Variable(1001)), scopes.ScopeOf(StoryKey.Variable(3005)), scopes.ScopeOf(StoryKey.SelfSwitch(215, 28, "A")) });
    }

    /// <summary>
    /// Asserts that only a personal row makes a work key, as the relay takes the option on no other.
    /// </summary>
    [Fact]
    public void Read_TakesWorkOnPersonalRowsOnly()
    {
        StoryTable table = Read();

        Assert.Equal((true, false), (table.Work.Contains(StoryKey.Variable(57)), table.Work.Contains(StoryKey.Switch(60))));
    }

    /// <summary>
    /// Reads the list of the cases.
    /// </summary>
    /// <returns>Its table.</returns>
    private static StoryTable Read()
    {
        using JsonDocument document = JsonDocument.Parse(List);
        return StoryMapping.Read(document.RootElement);
    }
}
