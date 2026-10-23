//----------------------------------------------------------------
//  GameRestart.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Started Helper.exe for the update, the restart and the watchdog, under Wine too
//                            - Read the release version through ReleaseVersion
//      Paulinchen  2026-10-22: Had the updater install the release offered, an older one too
//      Paulinchen  2026-10-09: Started the parked mods' watchdog
//      Paulinchen  2026-10-08: Started the mod's updater
//                            - Started neither the updater nor the restart under Wine
//                            - Started the game again through ProcessStartInfo instead of Start-Process
//      Paulinchen  2026-10-06: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;

namespace MGQParadox.Multiplayer.Mods;

/// <summary>
/// How starting the game again went, numbered as the exports answer the game script.
/// </summary>
internal enum RestartStart
{
    /// <summary>
    /// Nothing started, so the game must not close.
    /// </summary>
    Failed = 0,

    /// <summary>
    /// The helper waits for the game to close.
    /// </summary>
    Waiting = 1,
}

/// <summary>
/// Starts the game again once it closed, so new mods or a new release of this mod load: the game
/// reads its scripts only as it starts. Helper.exe in the mod folder does the waiting, a native
/// program that runs under Wine too.
/// </summary>
internal static class GameRestart
{
    /// <summary>
    /// The helper in the mod folder.
    /// </summary>
    internal const string HelperName = "Helper.exe";

    /// <summary>
    /// Has the helper wait in a console of its own for this game to close, install a release of the
    /// mod and start the game again.
    /// </summary>
    /// <param name="modFolder">The mod folder, which holds the helper.</param>
    /// <param name="version">The release to install, newer or older, like <c>0.6.8</c>; <see langword="null"/> for GitHub's latest.</param>
    /// <returns>Whether the helper started.</returns>
    public static RestartStart UpdateAfterExit(string modFolder, string? version = null)
    {
        var started = StartHelper(modFolder, UpdaterArguments(Environment.ProcessId, version), ProcessWindowStyle.Normal, "update");
        Log.Write(started == RestartStart.Waiting ? $"the updater waits for the game to close to install {version ?? "the latest release"}" : "update failed: the updater did not start");
        return started;
    }

    /// <summary>
    /// Writes the helper's arguments for an update.
    /// </summary>
    /// <param name="processId">This game's process id, which the helper waits for.</param>
    /// <param name="version">The release to install; <see langword="null"/> or anything but dotted numbers for GitHub's latest.</param>
    /// <returns>The arguments.</returns>
    internal static List<string> UpdaterArguments(int processId, string? version)
    {
        List<string> arguments = ["update", "--game", processId.ToString(CultureInfo.InvariantCulture)];

        if (ReleaseVersion.Parse(version) != null)
        {
            arguments.AddRange(["--version", version!]);
        }

        return arguments;
    }

    /// <summary>
    /// Has the helper wait hidden for this game to close and then start Game.exe again.
    /// </summary>
    /// <param name="modFolder">The mod folder, which holds the helper.</param>
    /// <returns>Whether the helper started.</returns>
    public static RestartStart AfterExit(string modFolder)
    {
        var gameFolder = ModFolder.GamePathOf(".", modFolder);
        var game = Path.Combine(gameFolder, "Game.exe");

        if (!File.Exists(game))
        {
            Log.Write($"restart failed: {game} does not exist");
            return RestartStart.Failed;
        }

        var started = StartHelper(modFolder, ["restart", "--game", Environment.ProcessId.ToString(CultureInfo.InvariantCulture), "--folder", gameFolder], ProcessWindowStyle.Hidden, "restart");
        Log.Write(started == RestartStart.Waiting ? "the game starts again once it closed" : "restart failed: the helper did not start");
        return started;
    }

    /// <summary>
    /// Has the helper wait hidden for this game to close, start it again into the world when it
    /// rejoins, and move the parked mods back once no game of the folder runs any more, whichever
    /// way the game closed.
    /// </summary>
    /// <param name="parking">The game's parking, whose journal the watchdog follows.</param>
    /// <param name="modFolder">The mod folder, which holds the helper.</param>
    /// <param name="world">The world the mods are parked for.</param>
    /// <param name="rejoin">Whether the watchdog starts the game again into the world; else it starts it to the title once the mods are back.</param>
    /// <returns>Whether the watchdog started.</returns>
    public static RestartStart WatchParked(ModParking parking, string modFolder, string world, bool rejoin)
    {
        var game = Path.Combine(parking.GameFolder, "Game.exe");
        var helper = Path.Combine(modFolder, HelperName);

        if (!File.Exists(game) || !File.Exists(helper))
        {
            Log.Write($"the parked mods' restart failed: {(File.Exists(game) ? helper : game)} does not exist");
            return RestartStart.Failed;
        }

        if (parking.PrepareWatch(world, rejoin) is not { } watch)
        {
            return RestartStart.Failed;
        }

        List<string> arguments = ["watch", "--game", Environment.ProcessId.ToString(CultureInfo.InvariantCulture), "--folder", parking.GameFolder, "--mode", rejoin ? "rejoin" : "title", "--watch", watch];
        var started = StartHelper(modFolder, arguments, ProcessWindowStyle.Hidden, "the parked mods' restart");
        Log.Write(started == RestartStart.Waiting ? $"the parked mods' watchdog waits for the game to close, then {(rejoin ? $"starts it again into world {Log.Short(world)}" : "brings the mods back and starts it to the title")}" : "the parked mods' restart failed: the helper did not start");
        return started;
    }

    /// <summary>
    /// Starts the helper through the shell, which hands it none of this game's handles, the parked
    /// mods' lock among them, that would outlive the game in it.
    /// </summary>
    /// <param name="modFolder">The mod folder, which holds the helper.</param>
    /// <param name="arguments">The helper's mode and options.</param>
    /// <param name="window">How its console window shows: only the update's is seen.</param>
    /// <param name="what">What it starts, for the log.</param>
    /// <returns>Whether it started.</returns>
    private static RestartStart StartHelper(string modFolder, IEnumerable<string> arguments, ProcessWindowStyle window, string what)
    {
        var helper = Path.Combine(modFolder, HelperName);

        if (!File.Exists(helper))
        {
            Log.Write($"{what} failed: {helper} does not exist");
            return RestartStart.Failed;
        }

        var start = new ProcessStartInfo(helper)
        {
            UseShellExecute = true,
            WindowStyle = window,
            WorkingDirectory = modFolder,
        };

        foreach (var argument in arguments)
        {
            start.ArgumentList.Add(argument);
        }

        using var process = Process.Start(start);
        return process != null ? RestartStart.Waiting : RestartStart.Failed;
    }
}
