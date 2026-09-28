//----------------------------------------------------------------
//  Log.cs
//
//  Changelog:
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System;
using System.Globalization;
using System.IO;
using System.Text;

namespace MGQParadox.Multiplayer;

/// <summary>
/// Multiplayer.log in the mod folder, written by the DLL.
/// </summary>
/// <remarks>
/// Never throws, since a failing log must not take down the code writing it, least of all the game.
/// </remarks>
internal static class Log
{
    /// <summary>
    /// Full path of the log file.
    /// </summary>
    private static string FilePath => ModFolder.PathOf("Multiplayer.log");

    /// <summary>
    /// Appends a line, prefixed with the time of day.
    /// </summary>
    /// <param name="message">The line to append.</param>
    public static void Write(string message)
    {
        var time = DateTime.Now.ToString("HH:mm:ss", CultureInfo.InvariantCulture);

        try
        {
            File.AppendAllText(FilePath, $"{time}  {message}\r\n", Encoding.UTF8);
        }
        catch
        {
        }
    }

    /// <summary>
    /// Deletes the log once it has grown past a size, so it starts over.
    /// </summary>
    /// <param name="maxBytes">The size the log may reach.</param>
    public static void ClearIfLargerThan(long maxBytes)
    {
        try
        {
            if (File.Exists(FilePath) && new FileInfo(FilePath).Length > maxBytes)
            {
                File.Delete(FilePath);
            }
        }
        catch
        {
        }
    }
}
