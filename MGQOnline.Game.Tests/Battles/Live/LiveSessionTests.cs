//----------------------------------------------------------------
//  LiveSessionTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the checks that replayed recorded cases
//      Paulinchen  2026-11-05: Covered a battle the battle server hosts
//                            - Covered the command phase of a player who chooses again
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Battles.Live;

namespace MGQOnline.Game.Tests.Battles.Live;

/// <summary>
/// Covers the live battle's session: who it waits for, its command phase and a served battle's end.
/// </summary>
public sealed class LiveSessionTests
{
    /// <summary>
    /// Asserts that a guest falls behind once four sends of the host's stream wait.
    /// </summary>
    [Fact]
    public void Behind_FromFourSendsWaiting()
    {
        var session = new LiveSession();
        session.Join("guest", "b1", [0], "Host", "coop", false, false);
        for (int send = 0; send < 3; send++)
        {
            session.Receive(0, "events", "e", "Host");
        }

        bool before = session.Behind;
        session.Receive(0, "events", "e", "Host");

        Assert.False(before);
        Assert.True(session.Behind);
        session.Take(["events"]);
        Assert.False(session.Behind);
    }

    /// <summary>
    /// Asserts that a guest who leaves while the host waits for the commands is no longer waited for,
    /// and is taken out once.
    /// </summary>
    [Fact]
    public void GuestLeft_MidPhase_IsNoLongerWaitedFor()
    {
        var session = new LiveSession();
        session.Join("host", "p1", [2, 3], "the party", "coop", false, false);
        session.Start();
        session.OpenPhase();
        session.Answer(2);

        bool first = session.GuestLeft(3);
        bool again = session.GuestLeft(3);

        Assert.Equal((true, false), (first, again));
        Assert.Empty(session.Unanswered);
        Assert.Equal([2], session.GuestsIn);
    }

    /// <summary>
    /// Asserts that a command phase opens once, that the guests sent back to choose again owe their
    /// commands anew, and that the next phase owes every guest's.
    /// </summary>
    [Fact]
    public void CommandPhase_OpensOnce_AndOwesTheCommandsOfWhoChoosesAgain()
    {
        var session = new LiveSession();
        session.Join("host", "p2", [2, 3], "the party", "coop", false, false);
        session.Start();

        bool opened = session.OpenPhase();
        bool openedAgain = session.OpenPhase();
        session.Answer(2);
        session.Answer(3);
        List<int> answered = session.Unanswered;
        session.Unanswer([3]);
        List<int> chooseAgain = session.Unanswered;
        bool closed = session.ClosePhase();
        bool closedAgain = session.ClosePhase();
        session.OpenPhase();

        Assert.Equal((true, false), (opened, openedAgain));
        Assert.Empty(answered);
        Assert.Equal([3], chooseAgain);
        Assert.Equal((true, false), (closed, closedAgain));
        Assert.Equal([2, 3], session.Unanswered);
    }

    /// <summary>
    /// Asserts that a departure told twice is told once.
    /// </summary>
    [Fact]
    public void Tell_DepartureToldTwice_IsToldOnce()
    {
        var session = new LiveSession();
        session.Join("host", "d1", [2], "the party", "coop", false, false);

        Assert.Equal((true, false, true), (session.Tell(2, "left"), session.Tell(2, "left"), session.Tell(2, "joined")));
    }

    /// <summary>
    /// Asserts that a battle the server takes over runs on, that the server takes out each player the
    /// presence tells gone or who said they leave, and that a guest counts the battle as gone only
    /// once its channel closed.
    /// </summary>
    [Fact]
    public void Served_RunsOnAndEndsOnceItsPlayersAreGone()
    {
        var server = new LiveSession();
        server.Join("host", "s1", [2], "the party", "coop", false, false);
        server.Start();
        server.Join("host", "s1", [1, 2], "the players", "coop", false, true);
        var open = new LiveFacts(true, false);
        var departed = new List<(int Seat, int StillIn)>();

        bool first = server.ServedGone(open, departed);
        server.NoteGone([1]);
        bool second = server.ServedGone(open, departed);
        server.Receive(2, "leave", "", "Friend");
        bool third = server.ServedGone(open, departed);

        Assert.True(server.Live);
        Assert.Equal((false, false, true), (first, second, third));
        Assert.Equal([(1, 1), (2, 0)], departed);

        var guest = new LiveSession();
        guest.Join("guest", "s2", [250], "the server", "coop", false, true);
        Assert.False(guest.Live);
        Assert.Equal((false, true), (guest.ServedGone(open, departed), guest.ServedGone(new LiveFacts(true, true), departed)));
    }

    /// <summary>
    /// Writes the effects of an ending, the take over answered as given.
    /// </summary>
    /// <param name="end">The ending.</param>
    /// <param name="takeOver">Whether the battle's mode takes over.</param>
    /// <returns>The effects.</returns>
    private static List<string> Ended(LiveEnd end, bool takeOver)
    {
        if (end.Process != "take_over")
        {
            return [.. end.Message is null ? Array.Empty<string>() : [$"message {end.Message}"], $"process {end.Process}"];
        }

        return takeOver ? ["take_over"] : ["take_over", .. Ended(end.Otherwise!, false)];
    }

    /// <summary>
    /// Lists the lines an ending logs, the take over answered as given.
    /// </summary>
    /// <param name="end">The ending.</param>
    /// <param name="takeOver">Whether the battle's mode takes over.</param>
    /// <returns>The lines.</returns>
    private static IEnumerable<string> Logged(LiveEnd end, bool takeOver)
    {
        if (end.Process == "take_over")
        {
            return takeOver ? [] : Logged(end.Otherwise!, false);
        }

        return end.Log is null ? [] : [end.Log];
    }
}
