//----------------------------------------------------------------
//  SelfAside.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Globalization;
using System.IO;

namespace MGQOnline.Helper;

/// <summary>
/// Moves the running helper's file aside before an update writes a new one in its place, since
/// Windows lets a running program's file be renamed but not overwritten.
/// </summary>
internal static class SelfAside
{
    /// <summary>
    /// What ends the name of a file moved aside.
    /// </summary>
    private const string Suffix = ".old";

    /// <summary>
    /// Moves a running program's file aside, next to where it was.
    /// </summary>
    /// <param name="exe">The file.</param>
    /// <returns>Where it went, such as <c>Helper.exe.1234.old</c>, named after this process so two updates never take one name.</returns>
    /// <exception cref="IOException">It could not be moved.</exception>
    /// <exception cref="UnauthorizedAccessException">It may not be moved.</exception>
    public static string MoveAside(string exe)
    {
        var aside = string.Create(CultureInfo.InvariantCulture, $"{exe}.{Environment.ProcessId}{Suffix}");
        File.Move(exe, aside, overwrite: true);
        return aside;
    }

    /// <summary>
    /// Moves a file moved aside back, unless another took its place meanwhile.
    /// </summary>
    /// <param name="exe">Where it was.</param>
    /// <param name="aside">Where it went.</param>
    public static void PutBack(string exe, string aside)
    {
        try
        {
            if (!File.Exists(exe) && File.Exists(aside))
            {
                File.Move(aside, exe);
            }
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            MGQParadox.Multiplayer.Log.Write($"{Path.GetFileName(exe)} could not be put back from {Path.GetFileName(aside)}: {ex.Message}");
        }
    }

    /// <summary>
    /// Deletes the files earlier updates moved aside; one whose program still runs stays for the next time.
    /// </summary>
    /// <param name="exe">The running program's file.</param>
    public static void Clean(string exe)
    {
        try
        {
            foreach (var old in Directory.EnumerateFiles(Path.GetDirectoryName(exe)!, Path.GetFileName(exe) + ".*" + Suffix))
            {
                try
                {
                    File.Delete(old);
                }
                catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
                {
                    // Still running, or held by a scanner for a moment.
                }
            }
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            // The folder cannot be listed, so the leftovers wait for the next time.
        }
    }
}
