//----------------------------------------------------------------
//  Log.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Globalization;
using System.IO;
using System.Text;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The helper's log in the game folder's Logs folder, which the code linked in from the DLL writes
/// to as it would to the DLL's log.
/// </summary>
/// <remarks>
/// Never throws, since a failing log must not end an update or the watchdog.
/// </remarks>
internal static class Log
{
    /// <summary>
    /// The log's name in the Logs folder.
    /// </summary>
    /// <remarks>
    /// The game script prunes only the logs named after a day, so this one stays and moves aside by size.
    /// </remarks>
    public const string FileName = "Multiplayer Helper.log";

    /// <summary>
    /// The name the log moves aside to once it grew past <see cref="MaxBytes"/>.
    /// </summary>
    public const string OldFileName = "Multiplayer Helper.old.log";

    /// <summary>
    /// The size the log moves aside at.
    /// </summary>
    public const long MaxBytes = 256 * 1024;

    /// <summary>
    /// How many characters of a long id the log keeps.
    /// </summary>
    private const int ShortIdLength = 12;

    /// <summary>
    /// Guards the file and <see cref="_last"/>.
    /// </summary>
    private static readonly object Gate = new();

    /// <summary>
    /// The Logs folder, <see langword="null"/> before <see cref="Open"/>, which writes nothing.
    /// </summary>
    private static string? _folder;

    /// <summary>
    /// The line written last, which a line that repeats it is not written again after.
    /// </summary>
    private static string? _last;

    /// <summary>
    /// Points the log at a game folder's Logs folder.
    /// </summary>
    /// <param name="gameFolder">The game folder.</param>
    public static void Open(string gameFolder) => _folder = Path.Combine(gameFolder, "Logs");

    /// <summary>
    /// Shortens a long id, such as a world's, to what tells it apart in the log.
    /// </summary>
    /// <param name="id">The id.</param>
    /// <returns>Its first 12 characters, or "?" for none.</returns>
    public static string Short(string? id) => id is null ? "?" : id.Length > ShortIdLength ? id[..ShortIdLength] : id;

    /// <summary>
    /// Appends a line, prefixed with the time and this process's id; a line that repeats the one
    /// before is left out.
    /// </summary>
    /// <param name="message">The line.</param>
    public static void Write(string message)
    {
        lock (Gate)
        {
            if (_folder == null || message == _last)
            {
                return;
            }

            _last = message;

            try
            {
                Directory.CreateDirectory(_folder);
                var path = Path.Combine(_folder, FileName);

                if (File.Exists(path) && new FileInfo(path).Length > MaxBytes)
                {
                    File.Move(path, Path.Combine(_folder, OldFileName), overwrite: true);
                }

                var line = string.Create(CultureInfo.InvariantCulture, $"{DateTime.Now:yyyy-MM-dd HH:mm:ss} [{Environment.ProcessId}] {message}\r\n");

                // Shared, since the updater and the watchdog may both run and write at once.
                using var stream = new FileStream(path, FileMode.Append, FileAccess.Write, FileShare.ReadWrite | FileShare.Delete);
                stream.Write(Encoding.UTF8.GetBytes(line));
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                // The line is lost, which must not end what the helper does.
            }
        }
    }
}
