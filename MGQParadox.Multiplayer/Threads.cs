//----------------------------------------------------------------
//  Threads.cs
//
//  Changelog:
//      Paulinchen  2026-10-07: Said once why every thread's work catches everything
//      Paulinchen  2026-10-06: Created
//
//----------------------------------------------------------------

using System;
using System.Threading;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The DLL's background threads, which talk to the relay while the game runs on.
/// </summary>
internal static class Threads
{
    /// <summary>
    /// Runs work on a background thread, which ends with the game.
    /// </summary>
    /// <remarks>
    /// The work catches everything itself, since an exception escaping a thread would end the whole game.
    /// </remarks>
    /// <param name="name">The thread's name.</param>
    /// <param name="work">The work, which catches everything itself.</param>
    public static void Start(string name, Action work) =>
        new Thread(() => work()) { IsBackground = true, Name = name }.Start();
}
