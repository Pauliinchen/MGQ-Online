//----------------------------------------------------------------
//  DirectoryTickets.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-10-23: Dropped its topics, since only the DLL's own machines claim actions now
//                            - Created
//
//----------------------------------------------------------------

using System;

namespace MGQOnline.Multiplayer.Topics;

/// <summary>
/// Who an action of the world directory belongs to: the directory keeps one action's answer at a
/// time for the world screen and the world's mod settings alike, so each claims the action it
/// starts and takes only its own answer.
/// </summary>
/// <param name="action">Reads the state of the running or last action ("idle", "busy", "done" or "failed").</param>
/// <param name="clear">Forgets the last action's answer.</param>
internal sealed class DirectoryTickets(Func<string> action, Action clear)
{
    /// <summary>
    /// The ticket claimed last, 0 before the first.
    /// </summary>
    private int _claimed;

    /// <summary>
    /// Whether the answer of the action claimed last was given up on.
    /// </summary>
    private bool _released;

    /// <summary>
    /// Notes that the action just started belongs to its caller.
    /// </summary>
    /// <returns>The ticket that names it.</returns>
    public int Claim()
    {
        _released = false;
        return ++_claimed;
    }

    /// <summary>
    /// Tells whether the action started last is the one a ticket names, whose answer is its caller's.
    /// </summary>
    /// <param name="ticket">The ticket, <see langword="null"/> for none.</param>
    /// <returns>Whether it is.</returns>
    public bool Mine(int? ticket) => ticket != null && ticket == _claimed;

    /// <summary>
    /// Gives up on the answer of an action, which the next one may then drop.
    /// </summary>
    /// <param name="ticket">The action's ticket, <see langword="null"/> for none.</param>
    public void Release(int? ticket)
    {
        if (Mine(ticket))
        {
            _released = true;
        }
    }

    /// <summary>
    /// Tells whether an action may start without dropping an answer its caller still waits for: none
    /// ran, or the last one ended and was given up on, whose answer this forgets.
    /// </summary>
    /// <returns>Whether one may.</returns>
    public bool Free()
    {
        string state = action();
        if (state == "idle")
        {
            return true;
        }

        if (state == "busy" || !_released)
        {
            return false;
        }

        clear();
        return true;
    }
}
