//----------------------------------------------------------------
//  Restart.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.ComponentModel;
using System.IO;
using MGQParadox.Multiplayer;

namespace MGQOnline.Helper;

/// <summary>
/// The restart: waits for the game to close and starts it again, so the mods it installed or put
/// back load, since the game reads its scripts only as it starts.
/// </summary>
internal static class Restart
{
    /// <summary>
    /// Waits for the game and starts it again.
    /// </summary>
    /// <param name="arguments">What the helper was started with.</param>
    /// <returns>0 once the game started again, 1 when it did not.</returns>
    public static int Run(HelperArguments arguments)
    {
        Log.Write($"starting game {arguments.Game} in {arguments.GameFolder} again once it closed");

        using (var game = GameProcesses.Take(arguments.Game, arguments.GameExe))
        {
            game?.WaitForExit();
        }

        if (!File.Exists(arguments.GameExe))
        {
            Log.Write($"Game.exe is not in {arguments.GameFolder}, so the game does not start again");
            return 1;
        }

        try
        {
            using var started = GameProcesses.Start(arguments.GameExe);
            Log.Write("started the game again");
            return 0;
        }
        catch (Exception ex) when (ex is Win32Exception or InvalidOperationException)
        {
            Log.Write($"starting the game failed: {ex.Message}");
            return 1;
        }
    }
}
