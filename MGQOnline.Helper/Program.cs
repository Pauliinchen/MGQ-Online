//----------------------------------------------------------------
//  Program.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using MGQParadox.Multiplayer;

namespace MGQOnline.Helper;

/// <summary>
/// Helper.exe, which runs what has to happen while the game is closed: the update, the restart and
/// the parked mods' watchdog. The DLL starts it, and Update.bat for an update by hand.
/// </summary>
internal static class Program
{
    /// <summary>
    /// What the helper ends with when its arguments make no sense.
    /// </summary>
    private const int UsageExitCode = 2;

    /// <summary>
    /// What the helper ends with when a mode failed with an error it did not expect.
    /// </summary>
    private const int FailedExitCode = 1;

    /// <summary>
    /// Runs the mode the arguments name.
    /// </summary>
    /// <param name="args">The mode, then pairs of an option and its value, see <see cref="HelperArguments.Usage"/>.</param>
    /// <returns>0 when the mode did its work, 1 when it failed, 2 for arguments that make no sense.</returns>
    private static int Main(string[] args)
    {
        if (HelperArguments.Parse(args, ModFolder.GamePathOf(".")) is not { } arguments)
        {
            Console.Error.WriteLine(HelperArguments.Usage);
            return UsageExitCode;
        }

        Log.Open(arguments.GameFolder);

        if (Environment.ProcessPath is { } exe)
        {
            SelfAside.Clean(exe);
        }

        try
        {
            return arguments.Mode switch
            {
                HelperMode.Update => new Updater(arguments).Run(),
                HelperMode.Restart => Restart.Run(arguments),
                _ => new Watchdog(arguments).Run(),
            };
        }
        catch (Exception ex)
        {
            // Nothing waits for the helper's answer, so the log is the only place a failure shows.
            Log.Write($"the helper failed in {arguments.Mode} mode: {ex.Message}");
            return FailedExitCode;
        }
    }
}
