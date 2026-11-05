//----------------------------------------------------------------
//  TellingMachineTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the checks that replayed recorded cases
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Game.Telling;

namespace MGQOnline.Game.Tests.Telling;

/// <summary>
/// Covers the telling machine: the relay's telling lock a new telling takes.
/// </summary>
public sealed class TellingMachineTests
{
    /// <summary>
    /// Asserts that a new telling in a Raid World takes the lock of its map and holds its first
    /// command until the relay granted it, and ends the event once the relay refused it, naming
    /// the teller though giving the lock back forgets the relay's answer.
    /// </summary>
    [Fact]
    public void Command_WaitsForTheLockAndEndsOnceRefused()
    {
        var lockOf = new Lock { Locks = true };
        var machine = new TellingMachine(lockOf);
        TellingStart start = machine.Start(true, false, 7, "map:7:39:1", 1);
        TellingCommand waiting = machine.Command(1);
        lockOf.Granted = true;
        TellingCommand granted = machine.Command(2);
        TellingCommand next = machine.Command(2);
        machine.End();
        machine.Step(2);
        var refused = new TellingMachine(lockOf);
        lockOf.Granted = null;
        refused.Start(true, false, 7, "map:7:40:1", 3);
        lockOf.Granted = false;
        lockOf.Holder = 4;
        TellingCommand ended = refused.Command(3);

        Assert.Equal((true, TellingContinued.None, true, true), (start.Telling, start.Continued, start.Hold, start.Locked));
        Assert.Equal([TellingCommand.Hold, TellingCommand.Go, TellingCommand.Go], [waiting, granted, next]);
        Assert.Equal([("request", "map:7:39:1", 7), ("release", "", 0), ("request", "map:7:40:1", 7), ("release", "", 0)], lockOf.Calls);
        Assert.Equal((TellingCommand.End, false, 4), (ended, refused.Telling, refused.RefusedBy));
    }

    /// <summary>
    /// Asserts that a new telling goes on without the lock once the relay refused it while nobody
    /// tells on the map, as for a game it has not placed yet, once it gave no answer within
    /// <see cref="TellingMachine.LockHoldFrames"/>, and at once while the world room is closed.
    /// </summary>
    [Fact]
    public void Command_GoesOnWithoutTheLockWhenNobodyHoldsItOrNoAnswerComes()
    {
        var lockOf = new Lock { Locks = true };
        var refused = new TellingMachine(lockOf);
        refused.Start(true, false, 7, "map:7:39:1", 1);
        lockOf.Granted = false;
        TellingCommand unheld = refused.Command(2);
        var unanswered = new TellingMachine(lockOf);
        unanswered.Start(true, false, 7, "map:7:40:1", 10);
        TellingCommand lastHeld = unanswered.Command(10 + TellingMachine.LockHoldFrames - 1);
        TellingCommand lapsed = unanswered.Command(10 + TellingMachine.LockHoldFrames);
        var closed = new TellingMachine(new Lock { Locks = true, Answerable = false });
        closed.Start(true, false, 7, "map:7:41:1", 20);

        Assert.Equal((TellingCommand.Unlocked, true), (unheld, refused.Telling));
        Assert.Equal(("release", "", 0), lockOf.Calls[1]);
        Assert.Equal([TellingCommand.Hold, TellingCommand.Unlocked], [lastHeld, lapsed]);
        Assert.Equal((TellingCommand.Unlocked, true), (closed.Command(20), closed.Telling));
    }

    /// <summary>
    /// Asserts that a telling that moved the player keeps its lock, which the story's next event on
    /// the new map moves there without a hold, and gives it back once the frames passed without one.
    /// </summary>
    [Fact]
    public void Step_KeepsTheLockWhileTheTellingMayGoOnAfterAMove()
    {
        var lockOf = new Lock { Locks = true, Granted = true };
        var machine = new TellingMachine(lockOf);
        machine.Start(true, false, 430, "map:430:5:1", 1);
        machine.Moving(430, 2);
        machine.End();
        machine.Step(2);
        int keptAfterEnd = lockOf.Calls.Count;
        TellingStart moved = machine.Start(true, true, 432, "map:432:1:1", 10);
        machine.Moving(432, 11);
        machine.End();
        for (long frame = 11; frame < 11 + TellingMachine.ContinueFrames; frame++)
        {
            machine.Step(frame);
        }

        int keptWhileMoved = lockOf.Calls.Count;
        machine.Step(11 + TellingMachine.ContinueFrames);

        Assert.Equal(1, keptAfterEnd);
        Assert.Equal((TellingContinued.Moved, 430, false, true), (moved.Continued, moved.From, moved.Hold, moved.Locked));
        Assert.Equal(2, keptWhileMoved);
        Assert.Equal([("request", "map:430:5:1", 430), ("request", "map:430:5:1", 432), ("release", "", 0)], lockOf.Calls);
    }

    /// <summary>
    /// Asserts that the lock moves to the new map as the telling's transfer lands while its event
    /// still runs, before the event ends, and that the story's next event there asks for it no more.
    /// </summary>
    [Fact]
    public void Arrived_MovesTheLockAsTheTransferLands()
    {
        var lockOf = new Lock { Locks = true, Granted = true };
        var machine = new TellingMachine(lockOf);
        machine.Start(true, false, 430, "map:430:5:1", 1);
        machine.Moving(430, 2);
        machine.Arrived(432);
        int requestsBeforeEnd = lockOf.Calls.Count;
        machine.End();
        machine.Step(3);
        TellingStart moved = machine.Start(true, true, 432, "map:432:1:1", 10);

        Assert.Equal(2, requestsBeforeEnd);
        Assert.Equal((TellingContinued.Moved, 430, 432), (moved.Continued, moved.From, machine.Map));
        Assert.Equal([("request", "map:430:5:1", 430), ("request", "map:430:5:1", 432)], lockOf.Calls);
    }

    /// <summary>
    /// Asserts that a Classic party's story takes no lock and holds nothing, and that a telling no
    /// event of the map or common event starts asks for none either.
    /// </summary>
    [Fact]
    public void Start_TakesNoLockOutsideARaidWorldOrForTheGamesOwnWrites()
    {
        var classic = new Lock { Locks = false };
        var classicMachine = new TellingMachine(classic);
        TellingStart led = classicMachine.Start(true, false, 7, "map:7:39:1", 1);
        var raid = new Lock { Locks = true };
        var raidMachine = new TellingMachine(raid);
        TellingStart own = raidMachine.Start(true, false, 7, "game:event", 1);

        Assert.Equal((true, false, false, TellingCommand.Go), (led.Telling, led.Hold, led.Locked, classicMachine.Command(1)));
        Assert.Equal((true, false, false, TellingCommand.Go), (own.Telling, own.Hold, own.Locked, raidMachine.Command(1)));
        Assert.Empty(classic.Calls);
        Assert.Empty(raid.Calls);
    }

    /// <summary>
    /// A lock that keeps what it was asked and, as the relay's, forgets its answer at each request
    /// and release.
    /// </summary>
    private sealed class Lock : ITellingLock
    {
        /// <summary>
        /// Gets the requests and releases, in order.
        /// </summary>
        public List<(string Call, string Site, int Map)> Calls { get; } = [];

        /// <inheritdoc />
        public bool Locks { get; set; }

        /// <inheritdoc />
        public bool Answerable { get; set; } = true;

        /// <inheritdoc />
        public bool? Granted { get; set; }

        /// <inheritdoc />
        public int? Holder { get; set; }

        /// <inheritdoc />
        public void Request(string site, int map)
        {
            Calls.Add(("request", site, map));
            Forget();
        }

        /// <inheritdoc />
        public void Release()
        {
            Calls.Add(("release", "", 0));
            Forget();
        }

        /// <summary>
        /// Forgets the answer.
        /// </summary>
        private void Forget()
        {
            Granted = null;
            Holder = null;
        }
    }
}
