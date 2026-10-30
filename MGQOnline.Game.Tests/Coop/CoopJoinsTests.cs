//----------------------------------------------------------------
//  CoopJoinsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Battles.Live;
using MGQOnline.Game.Coop;

namespace MGQOnline.Game.Tests.Coop;

/// <summary>
/// Checks the joins of a co-op battle taken from the live battle's session: the host's gathering,
/// a guest's wait for the roster and the host's players taken into its running battle.
/// </summary>
public sealed class CoopJoinsTests
{
    /// <summary>
    /// The live battle's session the host's messages come to.
    /// </summary>
    private readonly LiveSession _session = new();

    /// <summary>
    /// The joins over the session.
    /// </summary>
    private readonly CoopJoins _joins;

    /// <summary>
    /// Initializes the joins of a host whose battle invited seats 2, 3 and 4.
    /// </summary>
    public CoopJoinsTests()
    {
        _session.Join("host", "b1", [2, 3, 4], "the players", "coop", false, false);
        _joins = new CoopJoins(_session);
    }

    /// <summary>
    /// Asserts that a gathering takes each invited player's join or decline and notes those who left
    /// the world, ending once all answered.
    /// </summary>
    [Fact]
    public void Gather_EveryPlayerAnswered_EndsWithTheirOutcomes()
    {
        _joins.StartGather([2, 3, 4], 360);
        _session.Receive(3, "join", "build", "P3");
        Assert.False(_joins.GatherFrame([]));

        _session.Receive(2, "decline", "", "P2");
        bool over = _joins.GatherFrame([4]);
        GatherEnd end = _joins.EndGather();

        Assert.True(over);
        Assert.Equal([new KeyValuePair<int, string>(3, "build")], end.Joined);
        Assert.Equal([(2, (string?)"declined"), (3, "joined (5 bytes)"), (4, "left the world")], end.Outcomes);
        Assert.Equal(2, end.Frames);
    }

    /// <summary>
    /// Asserts that a gathering ends once its frames ran out, a silent player without an outcome.
    /// </summary>
    [Fact]
    public void Gather_FramesRanOut_EndsWithoutTheSilent()
    {
        _joins.StartGather([2], 2);

        Assert.False(_joins.GatherFrame([]));
        Assert.True(_joins.GatherFrame([]));
        Assert.Equal([(2, (string?)null)], _joins.EndGather().Outcomes);
    }

    /// <summary>
    /// Asserts that a guest's wait for the roster takes it once it came, and runs late without it,
    /// also after it started anew for the battle server.
    /// </summary>
    [Fact]
    public void RosterFrame_TakesTheRosterOrRunsLate()
    {
        _joins.StartRoster(2);
        Assert.Equal(new RosterWait(null, false, 1), _joins.RosterFrame());
        Assert.Equal(new RosterWait(null, false, 0), _joins.RosterFrame(1));
        Assert.Equal(new RosterWait(null, true, 1), _joins.RosterFrame());

        _session.Receive(2, "roster", "line", "Host");
        Assert.Equal("line", _joins.RosterFrame().Roster);
    }

    /// <summary>
    /// Asserts that the players taken in are forgotten as they decline, leave the battle or the
    /// world, or wait too long, which alone tells them the battle is off; a requester's enemies go
    /// with them.
    /// </summary>
    [Fact]
    public void Expire_ForgetsThoseWhoAreDone()
    {
        _joins.TakeIn(2, [2, 3], [[50, 300, 300, 0]], 0);
        _joins.TakeIn(4, [4], [], 50_000);
        _session.Receive(2, "decline", "", "P2");
        _session.Receive(2, "join", "build", "P2");

        Assert.Equal([(2, "turned the invite down or stopped waiting", false), (3, "left the world", false)], _joins.Expire(1_000, [3]));
        Assert.Empty(_joins.TakeJoins());
        Assert.Equal([(4, "did not join within 60 s", true)], _joins.Expire(110_001, []));
        Assert.Equal(0, _joins.Count);
    }

    /// <summary>
    /// Asserts that the encounters whose player joined join the troop one after the other, each
    /// once, and the players who joined leave the list.
    /// </summary>
    [Fact]
    public void NextAdded_TakesTheJoinedEncountersInTurn()
    {
        _joins.TakeIn(2, [2], [[50, 300, 300, 0]], 0);
        _joins.TakeIn(3, [3], [[51, 400, 300, 0]], 0);
        _joins.TakeIn(4, [4], [[52, 500, 300, 0]], 0);
        _session.Receive(3, "join", "b3", "P3");
        _session.Receive(2, "join", "b2", "P2");
        List<(int Seat, string Body)> joined = _joins.TakeJoins();
        List<int> seats = [.. joined.Select(join => join.Seat)];

        Assert.Equal([(2, "b2"), (3, "b3")], joined);
        Assert.Equal(50, _joins.NextAdded(seats)![0][0]);
        Assert.Equal([[51L, 400, 300, 0], [52L, 500, 300, 0]], _joins.QueuedEnemies);
        Assert.Equal(51, _joins.NextAdded(seats)![0][0]);
        Assert.Null(_joins.NextAdded(seats));
        _joins.Remove(seats);
        Assert.Equal([4], _joins.PendingSeats);
    }

    /// <summary>
    /// Asserts that a requester whose encounter starts on its own is forgotten, as is a player who
    /// asks with their own encounter from the request that brought them.
    /// </summary>
    [Fact]
    public void TakeOff_AndRelease_ForgetTheirPlayers()
    {
        _joins.TakeIn(2, [2, 3], [], 0);

        Assert.False(_joins.TakeOff(3));
        Assert.Equal([(3, "they ask with their own encounter")], _joins.ReleaseCompanion(3));
        Assert.True(_joins.TakeOff(2));
        Assert.Empty(_joins.CallOff());
    }
}
