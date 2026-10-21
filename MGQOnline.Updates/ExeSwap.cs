//----------------------------------------------------------------
//  ExeSwap.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Threading;

namespace MGQOnline.Updates;

/// <summary>
/// Puts a downloaded program in place of the running one by renaming, and takes it back on failure.
/// </summary>
/// <remarks>
/// A running exe cannot be overwritten or deleted on Windows, but it can be renamed, so the running
/// file moves aside to <c>.old</c> and the download takes its name.
/// </remarks>
public static class ExeSwap
{
    /// <summary>
    /// The suffix of the downloaded program before it is installed.
    /// </summary>
    public const string NewSuffix = ".new";

    /// <summary>
    /// The suffix of the replaced program until the new one has started.
    /// </summary>
    public const string OldSuffix = ".old";

    /// <summary>
    /// Names the file a download is staged in.
    /// </summary>
    /// <param name="exePath">The program's path.</param>
    /// <returns>The path with <see cref="NewSuffix"/>, like <c>RaidDesigner.exe.new</c>.</returns>
    public static string NewPathOf(string exePath) => exePath + NewSuffix;

    /// <summary>
    /// Names the file the replaced program is kept in.
    /// </summary>
    /// <param name="exePath">The program's path.</param>
    /// <returns>The path with <see cref="OldSuffix"/>, like <c>RaidDesigner.exe.old</c>.</returns>
    public static string OldPathOf(string exePath) => exePath + OldSuffix;

    /// <summary>
    /// Renames the program to <c>.old</c> and the staged download to the program's name.
    /// </summary>
    /// <remarks>
    /// Outside Windows the download takes the program's file mode, so it stays executable.
    /// </remarks>
    /// <param name="exePath">The program's path.</param>
    /// <exception cref="UpdateRefusedException">
    /// The swap failed; the program is back in place, or the message names the file it was left in.
    /// </exception>
    public static void Install(string exePath)
    {
        var newPath = NewPathOf(exePath);
        var oldPath = OldPathOf(exePath);

        if (!File.Exists(newPath))
        {
            throw new UpdateRefusedException($"No download waits at {newPath}.");
        }

        try
        {
            if (!OperatingSystem.IsWindows() && File.Exists(exePath))
            {
                File.SetUnixFileMode(newPath, File.GetUnixFileMode(exePath));
            }

            File.Move(exePath, oldPath, overwrite: true);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            throw new UpdateRefusedException($"The program could not be moved aside: {ex.Message}", ex);
        }

        try
        {
            File.Move(newPath, exePath);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            throw Undo(oldPath, exePath, $"The download could not take the program's place: {ex.Message}", ex);
        }
    }

    /// <summary>
    /// Puts the replaced program back, moving the installed download to <c>.new</c> again.
    /// </summary>
    /// <param name="exePath">The program's path.</param>
    /// <exception cref="UpdateRefusedException">
    /// There is no <c>.old</c>, or it could not be put back; the message names a file left moved aside.
    /// </exception>
    public static void RollBack(string exePath)
    {
        var newPath = NewPathOf(exePath);
        var oldPath = OldPathOf(exePath);

        if (!File.Exists(oldPath))
        {
            throw new UpdateRefusedException($"No replaced program waits at {oldPath}.");
        }

        var movedAside = false;

        try
        {
            if (File.Exists(exePath))
            {
                File.Move(exePath, newPath, overwrite: true);
                movedAside = true;
            }

            File.Move(oldPath, exePath);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            var failure = $"The replaced program could not be put back: {ex.Message}";

            throw movedAside ? Undo(newPath, exePath, failure, ex) : new UpdateRefusedException(failure, ex);
        }
    }

    /// <summary>
    /// Moves a file back to the name it had before a failed step.
    /// </summary>
    /// <param name="movedPath">Where the file was moved to.</param>
    /// <param name="originalPath">Where the file was before.</param>
    /// <param name="failure">What failed.</param>
    /// <param name="cause">The error of the failed step.</param>
    /// <returns>The refusal to throw, naming the moved file when it could not be moved back.</returns>
    private static UpdateRefusedException Undo(string movedPath, string originalPath, string failure, Exception cause)
    {
        try
        {
            File.Move(movedPath, originalPath);
            return new UpdateRefusedException(failure, cause);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            return new UpdateRefusedException($"{failure} The program stays at {movedPath}: {ex.Message}", cause);
        }
    }

    /// <summary>
    /// Deletes the replaced program once the new one runs.
    /// </summary>
    /// <remarks>
    /// Windows may hold the file for a moment after its process ended, so the delete is retried.
    /// </remarks>
    /// <param name="exePath">The program's path.</param>
    /// <param name="attempts">How often the delete is tried, at least once.</param>
    /// <param name="pause">How long to wait between two tries.</param>
    /// <returns>True when no <c>.old</c> is left.</returns>
    public static bool TryDeleteOld(string exePath, int attempts, TimeSpan pause)
    {
        var oldPath = OldPathOf(exePath);

        for (var attempt = 1; ; attempt++)
        {
            try
            {
                File.Delete(oldPath);
                return true;
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                if (attempt >= attempts)
                {
                    return false;
                }
            }

            Thread.Sleep(pause);
        }
    }
}
