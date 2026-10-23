//----------------------------------------------------------------
//  Watchdog.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Threading;
using MGQParadox.Multiplayer;
using MGQParadox.Multiplayer.Mods;

namespace MGQOnline.Helper;

/// <summary>
/// The parked mods' watchdog: waits for a game that parked mods for a world to close, starts it
/// again into the world when it rejoins, and brings the parked mods back by the DLL's rules once no
/// game of the folder runs any more, whichever way the game closed, a crash included.
/// </summary>
/// <param name="arguments">What the helper was started with.</param>
internal sealed class Watchdog(HelperArguments arguments)
{
    /// <summary>
    /// How often the watchdog polls, in milliseconds.
    /// </summary>
    private const int PollMilliseconds = 1000;

    /// <summary>
    /// The parking whose journal the watchdog reads; the lock is taken by one of its own for each try.
    /// </summary>
    private readonly ModParking _parking = new(arguments.GameFolder);

    /// <summary>
    /// Since when the journal could not be read, <see langword="null"/> while it can.
    /// </summary>
    private DateTime? _unreadableSince;

    /// <summary>
    /// Watches the game.
    /// </summary>
    /// <returns>0 once it is done, 1 without Game.exe or when the journal stayed unreadable.</returns>
    public int Run()
    {
        Log.Write($"watching game {arguments.Game} in {(arguments.Rejoin ? "rejoin" : "title")} mode, watchdog {arguments.Watch}");

        if (!File.Exists(arguments.GameExe))
        {
            Log.Write($"Game.exe is not in {arguments.GameFolder}, nothing to watch");
            return 1;
        }

        using (var game = GameProcesses.Take(arguments.Game, arguments.GameExe))
        {
            game?.WaitForExit();
            Log.Write(game != null ? "the game closed" : "the game had closed already");
        }

        if (arguments.Rejoin)
        {
            StartIntoWorld();
        }

        return BringModsBack();
    }

    /// <summary>
    /// Starts the game again into the world and waits for it to close, unless the journal cannot be
    /// read or belongs to a later watchdog, an update was asked for, or a game of the folder runs.
    /// </summary>
    private void StartIntoWorld()
    {
        if (!TryRead(_parking, out var state))
        {
            Log.Write("the game is not started again, since the journal could not be read");
        }
        else if (state != null && state.Watch != arguments.Watch)
        {
            Log.Write("the journal belongs to a later watchdog, which starts the game");
        }
        else if (UpdateAsked(state))
        {
            Log.Write("an update was asked for, whose updater starts the game");
        }
        else if (GameProcesses.AnyRunning(arguments.GameExe))
        {
            Log.Write("a game of this folder runs already");
        }
        else
        {
            WaitForGameStarted();
        }
    }

    /// <summary>
    /// Starts the game again into the world and waits for it to close.
    /// </summary>
    private void WaitForGameStarted()
    {
        using var started = StartGame();

        if (started == null)
        {
            Log.Write("the game did not start again");
            return;
        }

        Log.Write("started the game again into the world");
        started.WaitForExit();
        Log.Write("the game started into the world closed");
    }

    /// <summary>
    /// Waits until no game of the folder runs and the lock is free, then brings the mods of the
    /// journal back while it still names this watchdog, and starts the game to the title when the
    /// journal asks for it.
    /// </summary>
    /// <returns>0 once done, 1 when the journal stayed unreadable.</returns>
    private int BringModsBack()
    {
        var startTitle = false;

        while (true)
        {
            if (!TryRead(_parking, out var state))
            {
                if (!WaitWhileUnreadable())
                {
                    return 1;
                }

                continue;
            }

            if (state == null)
            {
                Log.Write("no mods are parked any more");
                break;
            }

            if (state.Watch != arguments.Watch)
            {
                Log.Write("the journal belongs to a later watchdog now");
                break;
            }

            if (GameProcesses.AnyRunning(arguments.GameExe))
            {
                Thread.Sleep(PollMilliseconds);
                continue;
            }

            bool read;

            using (var held = new ModParking(arguments.GameFolder))
            {
                if (!held.TakeLock())
                {
                    Thread.Sleep(PollMilliseconds);
                    continue;
                }

                // Read again under the lock, so no game can change the journal meanwhile.
                read = TryRead(held, out state);

                if (read && state != null && state.Watch == arguments.Watch)
                {
                    Log.Write($"bringing back {state.Files} mod(s) parked for world {Log.Short(state.World)}");
                    startTitle = held.Restore(state.AfterTitle) >= 0 && state.AfterTitle && !UpdateAsked(state);
                }
            }

            if (!read)
            {
                if (!WaitWhileUnreadable())
                {
                    return 1;
                }

                continue;
            }

            break;
        }

        if (startTitle && !GameProcesses.AnyRunning(arguments.GameExe))
        {
            using var started = StartGame();
            Log.Write(started != null ? "started the game again to the title" : "the game did not start again");
        }

        return 0;
    }

    /// <summary>
    /// Reads the journal in the poll loop, where a failure must not end the watchdog: it logs the
    /// first failure of a run of them.
    /// </summary>
    /// <param name="parking">The parking to read it through.</param>
    /// <param name="state">The journal, <see langword="null"/> when there is none or it could not be read.</param>
    /// <returns>Whether it could be read.</returns>
    private bool TryRead(ModParking parking, out ModParking.WatchState? state)
    {
        try
        {
            state = parking.ReadWatch();
            _unreadableSince = null;
            return true;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            if (_unreadableSince == null)
            {
                Log.Write($"the journal could not be read, trying again: {ex.Message}");
                _unreadableSince = DateTime.UtcNow;
            }

            state = null;
            return false;
        }
    }

    /// <summary>
    /// Waits one poll after the journal could not be read, unless it stayed unreadable for too long,
    /// so a journal that never becomes readable again keeps no hidden process alive.
    /// </summary>
    /// <returns><see langword="false"/> once the watchdog gives up and leaves the mods to the recovery at the next game start.</returns>
    private bool WaitWhileUnreadable()
    {
        if (_unreadableSince is { } since && (DateTime.UtcNow - since).TotalSeconds >= arguments.UnreadableSeconds)
        {
            Log.Write($"the journal stayed unreadable for {arguments.UnreadableSeconds} seconds, so the next game start brings the mods back");
            return false;
        }

        Thread.Sleep(PollMilliseconds);
        return true;
    }

    /// <summary>
    /// Tells whether an update was asked for, whose updater starts the game, which the watchdog then never does.
    /// </summary>
    /// <param name="state">The journal, <see langword="null"/> for none.</param>
    /// <returns>Whether the journal says so or an update of the folder runs.</returns>
    private bool UpdateAsked(ModParking.WatchState? state) => state is { Update: true } || UpdateMutex.Held(arguments.GameFolder);

    /// <summary>
    /// Starts the game.
    /// </summary>
    /// <returns>The game's process, which the caller disposes; <see langword="null"/> when it did not start.</returns>
    private Process? StartGame()
    {
        try
        {
            return GameProcesses.Start(arguments.GameExe);
        }
        catch (Exception ex) when (ex is Win32Exception or InvalidOperationException)
        {
            Log.Write($"starting the game failed: {ex.Message}");
            return null;
        }
    }
}
