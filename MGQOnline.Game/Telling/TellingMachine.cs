//----------------------------------------------------------------
//  TellingMachine.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;

namespace MGQOnline.Game.Telling;

/// <summary>
/// How a story event that starts goes on with the telling: its next event in the frame its last
/// one ended keeps the telling, and so does an event that runs by itself on the map the telling
/// moved the player onto within <see cref="ContinueFrames"/>, since the game's transfer process
/// runs between them; any other story event is a new telling. A new telling in a Raid World takes
/// the relay's lock of its map and holds its first command until the relay answered, at most
/// <see cref="LockHoldFrames"/>; the lock follows the telling onto every map its transfers land on.
/// </summary>
/// <remarks>
/// A telling that moved the player is kept until the story's next event there or until the frames
/// passed, so the relay hears no end in between, which would let another game tell there.
/// </remarks>
public sealed class TellingMachine
{
    /// <summary>
    /// Frames after the telling moved the player onto another map in which the story's next event
    /// there, one that runs by itself, goes on with it: five seconds.
    /// </summary>
    public const int ContinueFrames = 300;

    /// <summary>
    /// Frames a new telling's first command waits at most for the relay's answer: three seconds.
    /// </summary>
    public const int LockHoldFrames = 180;

    /// <summary>
    /// What a site that no event of the map or common event tells starts with: the game itself.
    /// </summary>
    private const string GameSite = "game";

    /// <summary>
    /// The relay's lock.
    /// </summary>
    private readonly ITellingLock lockOf;

    /// <summary>
    /// Whether an event of the telling runs.
    /// </summary>
    private bool telling;

    /// <summary>
    /// Whether an event of the telling ran as the last frame ended, see <see cref="Step"/>.
    /// </summary>
    private bool toldLastFrame;

    /// <summary>
    /// The map the telling is told on.
    /// </summary>
    private int map;

    /// <summary>
    /// The site that started the telling, <see langword="null"/> for none.
    /// </summary>
    private string? site;

    /// <summary>
    /// The frame the telling moved the player at, <see langword="null"/> while it did not.
    /// </summary>
    private long? movedAt;

    /// <summary>
    /// The map the telling moved the player from.
    /// </summary>
    private int movedFrom;

    /// <summary>
    /// Whether the relay holds, or was asked for, the telling's lock.
    /// </summary>
    private bool requested;

    /// <summary>
    /// Whether the telling's first command waits for the lock's answer.
    /// </summary>
    private bool pending;

    /// <summary>
    /// The frame the telling's first command started to wait for the lock's answer at.
    /// </summary>
    private long heldSince;

    /// <summary>
    /// Initializes a machine over a lock.
    /// </summary>
    /// <param name="lockOf">The relay's lock.</param>
    public TellingMachine(ITellingLock lockOf)
    {
        this.lockOf = lockOf;
    }

    /// <summary>
    /// Gets whether an event of the telling runs.
    /// </summary>
    public bool Telling => telling;

    /// <summary>
    /// Gets the map the telling is told on, or was last told on.
    /// </summary>
    public int Map => map;

    /// <summary>
    /// Gets the seat of the game that tells on the map where the relay refused the telling's lock,
    /// as the last command ended the event; <see langword="null"/> while none did.
    /// </summary>
    public int? RefusedBy { get; private set; }

    /// <summary>
    /// Reports whether the telling goes on: an event of it runs, or it moved the player and the
    /// story's next event there may still go on with it.
    /// </summary>
    /// <param name="frame">The frame.</param>
    /// <returns>Whether it does.</returns>
    public bool TellingOrMoved(long frame) => telling || MovedBy(frame);

    /// <summary>
    /// Takes an event of the map's interpreter starting.
    /// </summary>
    /// <param name="tells">Whether the event is story the player tells.</param>
    /// <param name="byItself">Whether the event runs by itself: a map event that does, or a common event.</param>
    /// <param name="map">The map it starts on.</param>
    /// <param name="site">The site that starts it, <see langword="null"/> for none known.</param>
    /// <param name="frame">The frame.</param>
    /// <returns>How it goes on.</returns>
    public TellingStart Start(bool tells, bool byItself, int map, string? site, long frame)
    {
        if (!tells)
        {
            telling = false;
            pending = false;
            return new TellingStart(false, TellingContinued.None, this.map, false, false);
        }

        int from = this.map;
        TellingContinued continued;
        if (toldLastFrame)
        {
            continued = TellingContinued.SameFrame;
        }
        else if (byItself && MovedBy(frame))
        {
            continued = TellingContinued.Moved;
            from = movedFrom;
            MoveLock(map);
        }
        else
        {
            continued = TellingContinued.None;
            StartAnew(map, site, frame);
        }

        telling = true;
        movedAt = null;
        return new TellingStart(true, continued, from, pending, requested);
    }

    /// <summary>
    /// Takes the interpreter about to run a command of the telling: the first command of a new
    /// telling waits for the relay's answer, and ends the event once the relay refused the lock
    /// because another game tells on the map. It runs without the lock once the relay refused it
    /// for another reason, or did not answer within <see cref="LockHoldFrames"/> or while it cannot.
    /// </summary>
    /// <param name="frame">The frame.</param>
    /// <returns>What the command does.</returns>
    public TellingCommand Command(long frame)
    {
        if (!telling || !pending)
        {
            return TellingCommand.Go;
        }

        if (!lockOf.Locks)
        {
            pending = false;
            return TellingCommand.Go;
        }

        switch (lockOf.Granted)
        {
            case true:
                pending = false;
                return TellingCommand.Go;
            case false when lockOf.Holder is { } holder:
                pending = false;
                telling = false;
                requested = false;
                RefusedBy = holder;
                lockOf.Release();
                return TellingCommand.End;
            case false:
                pending = false;
                requested = false;
                lockOf.Release();
                return TellingCommand.Unlocked;
            default:
                if (lockOf.Answerable && GatherCalls.Within(heldSince, LockHoldFrames, frame))
                {
                    return TellingCommand.Hold;
                }

                pending = false;
                return TellingCommand.Unlocked;
        }
    }

    /// <summary>
    /// Takes the event of the telling ending. The lock stays until the frame ends without the
    /// story's next event, see <see cref="Step"/>.
    /// </summary>
    public void End()
    {
        telling = false;
        pending = false;
    }

    /// <summary>
    /// Takes the telling moving the player onto another map, as the story's transfer does, before
    /// the transfer.
    /// </summary>
    /// <param name="map">The map the player leaves.</param>
    /// <param name="frame">The frame.</param>
    public void Moving(int map, long frame)
    {
        if (!telling)
        {
            return;
        }

        movedAt = frame;
        movedFrom = map;
    }

    /// <summary>
    /// Takes the telling's transfer landing the player on another map while its event still runs,
    /// as the story's transfer does before the event's next commands: the lock moves there at once.
    /// </summary>
    /// <param name="map">The map the player arrived on.</param>
    public void Arrived(int map)
    {
        if (telling)
        {
            MoveLock(map);
        }
    }

    /// <summary>
    /// Ends the frame: notes whether the telling runs, which tells the story's next event from a
    /// new telling, and gives the lock back once the telling neither runs nor may go on after a
    /// move.
    /// </summary>
    /// <param name="frame">The frame that ends.</param>
    public void Step(long frame)
    {
        toldLastFrame = telling;
        if (telling || MovedBy(frame) || !requested)
        {
            return;
        }

        requested = false;
        lockOf.Release();
    }

    /// <summary>
    /// Forgets the telling, as the world closed.
    /// </summary>
    public void Forget()
    {
        telling = false;
        toldLastFrame = false;
        pending = false;
        requested = false;
        movedAt = null;
        site = null;
    }

    /// <summary>
    /// Starts a new telling: the one before gives its lock back, and the new one takes the lock
    /// of its map while a Raid World's story is open and an event of the map or a common event
    /// starts it.
    /// </summary>
    /// <param name="map">The map it starts on.</param>
    /// <param name="site">The site that starts it.</param>
    /// <param name="frame">The frame.</param>
    private void StartAnew(int map, string? site, long frame)
    {
        if (requested)
        {
            requested = false;
            lockOf.Release();
        }

        this.map = map;
        this.site = site;
        pending = false;
        RefusedBy = null;
        if (!lockOf.Locks || site is null || site.StartsWith(GameSite, StringComparison.Ordinal))
        {
            return;
        }

        lockOf.Request(site, map);
        requested = true;
        pending = true;
        heldSince = frame;
    }

    /// <summary>
    /// Moves the telling, and the lock it holds or asked for, onto another map.
    /// </summary>
    /// <param name="map">The map.</param>
    private void MoveLock(int map)
    {
        if (map == this.map)
        {
            return;
        }

        this.map = map;
        if (requested)
        {
            lockOf.Request(site!, map);
        }
    }

    /// <summary>
    /// Reports whether the telling moved the player within <see cref="ContinueFrames"/>, and no
    /// story event went on with it since.
    /// </summary>
    /// <param name="frame">The frame.</param>
    /// <returns>Whether it did.</returns>
    private bool MovedBy(long frame) => movedAt is { } at && frame >= at && frame - at < ContinueFrames;
}

/// <summary>
/// How a story event that starts goes on with the telling.
/// </summary>
public enum TellingContinued
{
    /// <summary>
    /// It starts a telling anew.
    /// </summary>
    None,

    /// <summary>
    /// It goes on with the telling whose last event ended in the same frame.
    /// </summary>
    SameFrame,

    /// <summary>
    /// It goes on with the telling that moved the player onto its map.
    /// </summary>
    Moved,
}

/// <summary>
/// What the first command of a telling does.
/// </summary>
public enum TellingCommand
{
    /// <summary>
    /// It runs.
    /// </summary>
    Go,

    /// <summary>
    /// It waits for the relay's answer.
    /// </summary>
    Hold,

    /// <summary>
    /// The event ends: another game tells the story on the map.
    /// </summary>
    End,

    /// <summary>
    /// It runs without the lock: the relay refused it while nobody tells on the map, or gave no
    /// answer in time.
    /// </summary>
    Unlocked,
}

/// <summary>
/// How an event that starts goes on with the telling.
/// </summary>
/// <param name="Telling">Whether the player tells the event as story.</param>
/// <param name="Continued">How it goes on with the telling before.</param>
/// <param name="From">The map the telling was told on before: the one it moved the player from, else its own.</param>
/// <param name="Hold">Whether the event's first command waits for the relay's answer.</param>
/// <param name="Locked">Whether the relay holds, or was asked for, the telling's lock.</param>
public readonly record struct TellingStart(bool Telling, TellingContinued Continued, int From, bool Hold, bool Locked);
