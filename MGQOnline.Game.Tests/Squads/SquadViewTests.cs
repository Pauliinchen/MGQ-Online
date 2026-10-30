//----------------------------------------------------------------
//  SquadViewTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using MGQOnline.Game.Squads;
using MGQOnline.Game.Tests.Teleports;

namespace MGQOnline.Game.Tests.Squads;

/// <summary>
/// Covers the player's squad over the party, which coop_squad.rbx read from the party itself before.
/// </summary>
public sealed class SquadViewTests
{
    /// <summary>
    /// Asserts that a member who does not lead a party of three gets the share of their rank, the
    /// leader first and then by id, and takes the leader's choice of followers over their own.
    /// </summary>
    [Fact]
    public void Of_GivesAMemberTheShareOfTheirRankAndTheLeadersFollowers()
    {
        var world = new PartyWorld();
        world.Tell(2, ("id", "leader01"), ("name", "Leader"), ("party", "leader01p1"), ("party_members", "me000001,aaaa0001"), ("follow", "1"));
        world.Room.Party.Join(world["leader01"]);
        world.Tell(3, ("id", "aaaa0001"), ("name", "Anna"), ("party", "leader01p1"));

        SquadViewState view = SquadView.Of(world.Room, 8, SquadView.ActiveFrontline, false, false, SquadRules.Default);

        Assert.Equal(new SquadViewState(new SquadShare(1, 1), SquadView.LeadersOnly, true), view);
    }

    /// <summary>
    /// Asserts that outside a party a Classic world cuts nobody and keeps the player's own choice,
    /// and that a Raid World sizes the squad by its rules for the fight, in a party or not.
    /// </summary>
    [Fact]
    public void Of_CutsNobodyOutsideAPartyAndSizesARaidWorldsSquadByItsRules()
    {
        var world = new PartyWorld();
        var rules = new SquadRules(false, 6, 2, 1);

        SquadViewState classic = SquadView.Of(world.Room, 8, SquadView.LeadersOnly, false, false, rules);
        SquadViewState regular = SquadView.Of(world.Room, 8, SquadView.ActiveFrontline, true, false, rules);
        SquadViewState raid = SquadView.Of(world.Room, 8, SquadView.ActiveFrontline, true, true, rules);

        Assert.Equal(new SquadViewState(null, SquadView.LeadersOnly, false), classic);
        Assert.Equal((new SquadShare(2, 3), true), (regular.Share, regular.Squads));
        Assert.Equal(new SquadShare(1, 4), raid.Share);
    }
}
