//----------------------------------------------------------------
//  Log.cs
//
//  Changelog:
//      Paulinchen  2026-10-07: Wrote the file on a thread of the log's own, so no caller waits for the disk, flushed what is queued as the process exits, and exposed Flush for the tests
//                            - Wrote each game session into a log of its own, named after the game's start, without a size limit, and counted a line repeated as it is instead of writing it again
//      Paulinchen  2026-10-06: Wrote the log into the game folder's Logs folder
//      Paulinchen  2026-09-29: Kept the game and network threads from writing at once
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Text;
using System.Threading;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The DLL's log in the game folder's Logs folder, one file per game session, named after the
/// moment the game started, as the game script's log of the same session is. Lines are queued and
/// written by a thread of the log's own, so no caller waits for the disk.
/// </summary>
/// <remarks>
/// Never throws, since a failing log must not take down the code writing it, least of all the game.
/// </remarks>
internal static class Log
{
    /// <summary>
    /// How many characters of a long id the log keeps.
    /// </summary>
    private const int ShortIdLength = 12;

    /// <summary>
    /// How long a flush waits for the file, which the writer thread may hold while the process exits.
    /// </summary>
    private static readonly TimeSpan FlushTimeout = TimeSpan.FromSeconds(5);

    /// <summary>
    /// The log's path relative to the game's folder, named after the game's start.
    /// </summary>
    private static readonly string FileName = FileNameOf(GameStart());

    /// <summary>
    /// Guards <see cref="Queued"/> and <see cref="_writing"/>, and wakes the writer thread. Held only for a moment.
    /// </summary>
    private static readonly object Gate = new();

    /// <summary>
    /// Guards the file and <see cref="Repeated"/>: whoever holds it takes the queue and writes what it took, so the lines keep their order.
    /// </summary>
    private static readonly object FileGate = new();

    /// <summary>
    /// The lines not yet written, each with the time of day it was logged at.
    /// </summary>
    private static readonly Queue<(string Time, string Message)> Queued = new();

    /// <summary>
    /// Counts a line written again as it is.
    /// </summary>
    private static readonly Repeats Repeated = new();

    /// <summary>
    /// Whether the writer thread runs, started by the first line.
    /// </summary>
    private static bool _writing;

    /// <summary>
    /// Full path of the log file.
    /// </summary>
    internal static string FilePath => ModFolder.GamePathOf(FileName);

    /// <summary>
    /// Names the log of a game session.
    /// </summary>
    /// <param name="start">When the game started, in local time.</param>
    /// <returns>The path relative to the game's folder, such as <c>Logs\Multiplayer 2026-10-07 18-30-05.log</c>.</returns>
    public static string FileNameOf(DateTime start) =>
        $@"Logs\Multiplayer {start.ToString("yyyy-MM-dd HH-mm-ss", CultureInfo.InvariantCulture)}.log";

    /// <summary>
    /// Shortens a long id, such as a world's, a player's or a trade's, to what tells it apart in the log.
    /// </summary>
    /// <param name="id">The id.</param>
    /// <returns>Its first 12 characters, or "?" for none.</returns>
    public static string Short(string? id) => id is null ? "?" : id.Length > ShortIdLength ? id[..ShortIdLength] : id;

    /// <summary>
    /// Queues a line, prefixed with the time of day, for the writer thread; a line that repeats the one before is only counted.
    /// </summary>
    /// <param name="message">The line to append.</param>
    public static void Write(string message)
    {
        try
        {
            var time = DateTime.Now.ToString("HH:mm:ss", CultureInfo.InvariantCulture);

            lock (Gate)
            {
                Queued.Enqueue((time, message));

                if (!_writing)
                {
                    Threads.Start("MultiplayerLog", WriteAll);
                    AppDomain.CurrentDomain.ProcessExit += (_, _) => Flush();
                    _writing = true;
                }

                Monitor.PulseAll(Gate);
            }
        }
        catch
        {
        }
    }

    /// <summary>
    /// Writes every line queued so far on the calling thread, as far as the file can be had in time.
    /// </summary>
    internal static void Flush()
    {
        try
        {
            if (!Monitor.TryEnter(FileGate, FlushTimeout))
            {
                return;
            }

            try
            {
                Append(TakeQueued());
            }
            finally
            {
                Monitor.Exit(FileGate);
            }
        }
        catch
        {
        }
    }

    /// <summary>
    /// Writes the queued lines whenever some arrive, for as long as the game runs.
    /// </summary>
    private static void WriteAll()
    {
        while (true)
        {
            try
            {
                lock (Gate)
                {
                    while (Queued.Count == 0)
                    {
                        Monitor.Wait(Gate);
                    }
                }

                lock (FileGate)
                {
                    Append(TakeQueued());
                }
            }
            catch
            {
            }
        }
    }

    /// <summary>
    /// Takes every queued line. Called with <see cref="FileGate"/> held, so what is taken is written before what is taken next.
    /// </summary>
    /// <returns>The lines, oldest first.</returns>
    private static (string Time, string Message)[] TakeQueued()
    {
        lock (Gate)
        {
            var taken = Queued.ToArray();
            Queued.Clear();
            return taken;
        }
    }

    /// <summary>
    /// Appends lines to the file, those repeating the line before only counted. Called with <see cref="FileGate"/> held.
    /// </summary>
    /// <param name="lines">The lines, oldest first.</param>
    private static void Append((string Time, string Message)[] lines)
    {
        var text = new StringBuilder();

        foreach (var (time, message) in lines)
        {
            text.Append(Repeated.Take(time, message));
        }

        if (text.Length > 0)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
            File.AppendAllText(FilePath, text.ToString(), Encoding.UTF8);
        }
    }

    /// <summary>
    /// Reads when the game started, which names the log.
    /// </summary>
    /// <returns>The game process's start in local time, or now when Windows does not tell it.</returns>
    private static DateTime GameStart()
    {
        try
        {
            using var game = Process.GetCurrentProcess();
            return game.StartTime;
        }
        catch
        {
            return DateTime.Now;
        }
    }

    /// <summary>
    /// Turns lines into the text a log appends, counting a line that repeats the one before instead of writing it again.
    /// </summary>
    /// <remarks>
    /// The count is written once a different line follows, so a run of repeats at the very end of a session stays unwritten.
    /// </remarks>
    internal sealed class Repeats
    {
        /// <summary>
        /// The line written last, <see langword="null"/> before the first.
        /// </summary>
        private string? _last;

        /// <summary>
        /// How often the line written last came again since.
        /// </summary>
        private int _count;

        /// <summary>
        /// Takes a line.
        /// </summary>
        /// <param name="time">The time of day the line is stamped with.</param>
        /// <param name="message">The line.</param>
        /// <returns>The text to append, with the count of the repeats before it if there were any; <see langword="null"/> for a repeat.</returns>
        public string? Take(string time, string message)
        {
            if (message == _last)
            {
                _count++;
                return null;
            }

            var text = new StringBuilder();

            if (_count > 0)
            {
                text.Append(time).Append("  (the line above came ").Append(_count.ToString(CultureInfo.InvariantCulture)).Append(_count == 1 ? " more time)" : " more times)").Append("\r\n");
            }

            _last = message;
            _count = 0;
            return text.Append(time).Append("  ").Append(message).Append("\r\n").ToString();
        }
    }
}
