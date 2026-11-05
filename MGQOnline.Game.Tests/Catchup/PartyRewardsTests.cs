//----------------------------------------------------------------
//  PartyRewardsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the checks that replayed recorded cases
//      Paulinchen  2026-10-31: Checked the party chests that gave a key item
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Data.Events;
using MGQOnline.Game.Catchup;
using MGQOnline.Game.Story;
using MGQOnline.Game.Tests.Events;
using static MGQOnline.Game.Tests.Events.TinyGame;

namespace MGQOnline.Game.Tests.Catchup;

/// <summary>
/// Covers the rewards a party member of a Classic world catches up with, as the DLL hands them to
/// the scripts.
/// </summary>
public sealed class PartyRewardsTests
{
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

    /// <summary>
    /// Asserts that the chests a member behind plays for the key items they lack are those open in
    /// the leader's story whose closing page gives one, through a common event too; never one still
    /// shut, nor one that gives other items.
    /// </summary>
    [Fact]
    public void KeyItemChests_NameTheOpenedChestsThatGaveAKeyItem()
    {
        using EventStore store = EventDatabases.Of(new TinyGame()
            .MapEvent(1, 7, 0, 0, new TinyPage([C(126, 700, 0, 0, 1), C(121, 2045, 2045, 0), C(123, "A", 0)]), new TinyPage([], SelfSwitch: "A"))
            .MapEvent(1, 8, 1, 0, new TinyPage([C(117, 20), C(123, "A", 0)]))
            .MapEvent(1, 9, 2, 0, new TinyPage([C(126, 5, 0, 0, 1), C(123, "A", 0)]))
            .MapEvent(2, 3, 0, 0, new TinyPage([C(126, 701, 0, 0, 1), C(123, "A", 0)]))
            .Common(20, C(126, 702, 0, 0, 1))
            .Files());
        StoryKey first = StoryKey.SelfSwitch(1, 7, "A");
        StoryKey second = StoryKey.SelfSwitch(1, 8, "A");

        IReadOnlyList<KeyItemChest> chests = PartyRewards.KeyItemChests(store, [first, second, StoryKey.SelfSwitch(1, 9, "A")], [700, 701, 702]);

        Assert.Equal([(ReplaySite.Page(1, 7, 0), first, "700"), (ReplaySite.Page(1, 8, 0), second, "702")],
            chests.Select(chest => (chest.Site, chest.Key, string.Join(",", chest.Items))));
    }
}
