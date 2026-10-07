//----------------------------------------------------------------
//  Threads.cs
//
//  Changelog:
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
    /// <param name="name">The thread's name.</param>
    /// <param name="work">The work, which must catch everything itself.</param>
    public static void Start(string name, Action work) =>
        new Thread(() => work()) { IsBackground = true, Name = name }.Start();
}
