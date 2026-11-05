//----------------------------------------------------------------
//  OverviewRowsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Built its world instead of reading a recorded one
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Overview;
using MGQOnline.Game.Tests.Teleports;

namespace MGQOnline.Game.Tests.Overview;

/// <summary>
/// Covers the serial that tells the scripts a list of the World overview changed.
/// </summary>
public sealed class OverviewRowsTests
{
    /// <summary>
    /// Asserts that the lists are built once a frame and their serial moves only when they changed.
    /// </summary>
    [Fact]
    public void Serial_MovesOnlyWhenAListChanged()
    {
        (PartyWorld party, OverviewState state) = World();
        var feed = new OverviewFeed();

        long first = feed.Take(1, () => OverviewRows.All(party.Room, state, "Me")).Serial;
        long same = feed.Take(2, () => OverviewRows.All(party.Room, state, "Me")).Serial;
        party.Tell(5, ("lv", "8"));
        long held = feed.Take(2, () => OverviewRows.All(party.Room, state, "Me")).Serial;
        long changed = feed.Take(3, () => OverviewRows.All(party.Room, state, "Me")).Serial;

        Assert.Equal((first, first, first), (same, held, changed - 1));
    }

    /// <summary>
    /// Builds a Raid World with Granberia and Alma near the player, and what the player told the others.
    /// </summary>
    /// <returns>The room and the player's state.</returns>
    private static (PartyWorld Party, OverviewState State) World()
    {
        var party = new PartyWorld(true);
        party.Tell(1, ("id", "p0000001"), ("name", "Granberia"), ("map", "3"), ("lv", "61"), ("progress", "2:alice"), ("place", "Ilias Village"));
        party.Tell(5, ("id", "p0000005"), ("name", "Alma"), ("map", "3"), ("lv", "12"), ("progress", "1"), ("place", "Ilias Village"));
        var state = new OverviewState();
        state.Take(new OverviewReading(30, 28, "2:alice", false));
        state.Fields("Ilias Village", true);
        return (party, state);
    }
}
