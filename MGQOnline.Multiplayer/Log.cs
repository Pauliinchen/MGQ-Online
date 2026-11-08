//----------------------------------------------------------------
//  Log.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-10-23: Took the scripts' lines with the time they were written at
//                            - Told a line that keeps repeating at 10, 100, 1000 and 10000 repeats and in all on a flush
//                            - Deleted the logs of earlier days
//      Paulinchen  2026-10-15: Wrote one log per day
//      Paulinchen  2026-10-11: Cut the session's log to its newest 2 MB once it passes 4 MB
//      Paulinchen  2026-10-07: Wrote the file on a thread of the log's own and flushed the queue on exit
//                            - Wrote each game session into a log of its own and counted repeated lines
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
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;

namespace MGQOnline.Multiplayer;

/// <summary>
/// The mod's log in the game folder's Logs folder, one file per day, named after the day the game
/// started on, with the DLL's lines and the game scripts' in one timeline. Lines are queued and
/// written by a thread of the log's own, so no caller waits for the disk.
/// </summary>
/// <remarks>
/// Never throws, since a failing log must not take down the code writing it, least of all the game.
/// </remarks>
internal static partial class Log
{
    /// <summary>
    /// How many characters of a long id the log keeps.
    /// </summary>
    private const int ShortIdLength = 12;

    /// <summary>
    /// Bytes a day's log may reach before its oldest lines are cut.
    /// </summary>
    internal const long MaxBytes = 4 * 1024 * 1024;

    /// <summary>
    /// Bytes of its newest lines a log keeps when it is cut, so it is cut again only after as many more were written.
    /// </summary>
    internal const int KeptBytes = 2 * 1024 * 1024;

    /// <summary>
    /// The line a cut log starts with.
    /// </summary>
    internal const string CutLine = "(earlier lines were cut, the log keeps its newest lines only)";

    /// <summary>
    /// How the time of day starts each line.
    /// </summary>
    private const string TimeFormat = "HH:mm:ss";

    /// <summary>
    /// How the day the game started on shows in the file name.
    /// </summary>
    private const string DayFormat = "yyyy-MM-dd";

    /// <summary>
    /// How long a flush waits for the file, which the writer thread may hold while the process exits.
    /// </summary>
    private static readonly TimeSpan FlushTimeout = TimeSpan.FromSeconds(5);

    /// <summary>
    /// The day the game started on, which names the log.
    /// </summary>
    private static readonly DateTime StartDay = GameStart();

    /// <summary>
    /// The log's path relative to the game's folder, named after the day the game started on.
    /// </summary>
    private static readonly string FileName = FileNameOf(StartDay);

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
    /// Names the log of the day a game started on.
    /// </summary>
    /// <param name="start">When the game started, in local time.</param>
    /// <returns>The path relative to the game's folder, such as <c>Logs\Multiplayer 2026-10-07.log</c>.</returns>
    public static string FileNameOf(DateTime start) =>
        $@"Logs\Multiplayer {start.ToString(DayFormat, CultureInfo.InvariantCulture)}.log";

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
            WriteAt(DateTime.Now.ToString(TimeFormat, CultureInfo.InvariantCulture), message);
        }
        catch
        {
        }
    }

    /// <summary>
    /// Queues a line written at another moment, such as a line the game scripts handed over at the end of their frame.
    /// </summary>
    /// <param name="time">The time of day it was written at, such as "18:30:05".</param>
    /// <param name="message">The line to append.</param>
    public static void WriteAt(string time, string message)
    {
        try
        {
            lock (Gate)
            {
                Queued.Enqueue((time, message));

                if (!_writing)
                {
                    Threads.Start("MultiplayerLog", WriteAll);
                    AppDomain.CurrentDomain.ProcessExit += (_, _) => FlushAtClose();
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
    internal static void Flush() => Flush(false);

    /// <summary>
    /// Writes every line queued so far and how often the last one repeated, as the game closes or stops on an error.
    /// </summary>
    internal static void FlushAtClose() => Flush(true);

    /// <summary>
    /// Writes every line queued so far on the calling thread, as far as the file can be had in time.
    /// </summary>
    /// <param name="closing">Whether the game closes, which also writes how often the last line repeated.</param>
    private static void Flush(bool closing)
    {
        try
        {
            if (!Monitor.TryEnter(FileGate, FlushTimeout))
            {
                return;
            }

            try
            {
                Append(TakeQueued(), closing ? DateTime.Now.ToString(TimeFormat, CultureInfo.InvariantCulture) : null);
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
    /// Deletes every log of this mod but those of the day the game started on, since nothing else ever removes them, and logs how many went.
    /// </summary>
    internal static void DeleteOtherDays()
    {
        try
        {
            var (deleted, kept) = DeleteOtherDays(Path.GetDirectoryName(FilePath)!, StartDay.ToString(DayFormat, CultureInfo.InvariantCulture));

            if (deleted > 0)
            {
                Write($"deleted {deleted} log(s) of earlier days");
            }

            if (kept > 0)
            {
                Write($"could not delete {kept} old log(s)");
            }
        }
        catch (Exception ex)
        {
            Write($"deleting old logs failed: {ex.GetType().Name}: {ex.Message}");
        }
    }

    /// <summary>
    /// Deletes every log of this mod in a folder but those of a day: those of earlier days, the per-session logs of older builds, the
    /// unstamped ones of the oldest and the options dump's logs of older builds, the scripts' own logs of older builds among them.
    /// </summary>
    /// <param name="folder">The Logs folder.</param>
    /// <param name="day">The day whose logs stay, such as "2026-10-07".</param>
    /// <returns>How many logs were deleted, and how many could not be.</returns>
    internal static (int Deleted, int Failed) DeleteOtherDays(string folder, string day)
    {
        if (!Directory.Exists(folder))
        {
            return (0, 0);
        }

        var gone = Directory.EnumerateFileSystemEntries(folder)
            .Where(path => OwnLog().IsMatch(Path.GetFileName(path)) && DayLog().Match(Path.GetFileName(path)) is var match && !(match.Success && match.Groups[1].Value == day))
            .ToList();
        var deleted = gone.Count(TryDelete);
        return (deleted, gone.Count - deleted);
    }

    /// <summary>
    /// Matches a log of this mod, the scripts' or the DLL's, named after a day, after a session's start as older builds named them, or
    /// without a stamp as the oldest did, also the options dump's log older builds wrote.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"\AMultiplayer(?: InGame)?(?: \d{4}-\d{2}-\d{2}(?: \d{2}-\d{2}-\d{2})?)?(?: options dump)?\.log\z", RegexOptions.CultureInvariant)]
    private static partial Regex OwnLog();

    /// <summary>
    /// Matches a log of this mod named after a day, the day its first group.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"\AMultiplayer(?: InGame)? (\d{4}-\d{2}-\d{2})(?: options dump)?\.log\z", RegexOptions.CultureInvariant)]
    private static partial Regex DayLog();

    /// <summary>
    /// Deletes a file.
    /// </summary>
    /// <param name="path">The file.</param>
    /// <returns>Whether it is gone; a folder of a log's name or a file held open stays.</returns>
    private static bool TryDelete(string path)
    {
        try
        {
            if (!File.Exists(path))
            {
                return false;
            }

            File.Delete(path);
            return true;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            return false;
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
                    Append(TakeQueued(), null);
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
    /// <param name="closing">The time of day the game closes at, which writes how often the last line repeated; <see langword="null"/> while it runs.</param>
    private static void Append((string Time, string Message)[] lines, string? closing)
    {
        var text = new StringBuilder();

        foreach (var (time, message) in lines)
        {
            text.Append(Repeated.Take(time, message));
        }

        if (closing is not null)
        {
            text.Append(Repeated.Finish(closing));
        }

        if (text.Length > 0)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
            long length;

            // Another game started the same day appends to the same file.
            using (var file = new FileStream(FilePath, FileMode.Append, FileAccess.Write, FileShare.ReadWrite | FileShare.Delete))
            {
                file.Write(Encoding.UTF8.GetBytes(text.ToString()));
                length = file.Length;
            }

            if (length > MaxBytes)
            {
                CutToNewest(FilePath, KeptBytes);
            }
        }
    }

    /// <summary>
    /// Cuts a log down to its newest lines, from a whole line on, behind <see cref="CutLine"/>.
    /// </summary>
    /// <remarks>
    /// A bug report sends the newest lines, so the oldest are the ones to lose.
    /// </remarks>
    /// <param name="path">The log.</param>
    /// <param name="kept">The most bytes of its end it keeps.</param>
    internal static void CutToNewest(string path, int kept)
    {
        byte[] tail;

        using (var file = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
        {
            tail = new byte[(int)Math.Min(kept, file.Length)];
            file.Seek(-tail.Length, SeekOrigin.End);
            file.ReadExactly(tail);
        }

        var start = Array.IndexOf(tail, (byte)'\n') + 1;
        using var output = new FileStream(path, FileMode.Create, FileAccess.Write, FileShare.Read | FileShare.Delete);
        output.Write(Encoding.UTF8.GetBytes(CutLine + "\r\n"));
        output.Write(tail, start, tail.Length - start);
    }

    /// <summary>
    /// Reads when the game started, whose day names the log.
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
    /// The count is also written while the repeats go on, at <see cref="Reports"/>, so a flood shows even when the game never closes cleanly.
    /// </remarks>
    internal sealed class Repeats
    {
        /// <summary>
        /// The repeats at which the log tells that a line still repeats.
        /// </summary>
        private static readonly int[] Reports = [10, 100, 1000, 10_000];

        /// <summary>
        /// The line written last, <see langword="null"/> before the first.
        /// </summary>
        private string? _last;

        /// <summary>
        /// How often the line written last came again since.
        /// </summary>
        private int _streak;

        /// <summary>
        /// The repeats of the line written last that the log told already.
        /// </summary>
        private int _told;

        /// <summary>
        /// Takes a line.
        /// </summary>
        /// <param name="time">The time of day the line is stamped with.</param>
        /// <param name="message">The line.</param>
        /// <returns>The text to append, with the count of the repeats before it if there were any; <see langword="null"/> for a repeat the log does not tell yet.</returns>
        public string? Take(string time, string message)
        {
            if (message == _last)
            {
                _streak++;

                if (Array.IndexOf(Reports, _streak) < 0)
                {
                    return null;
                }

                _told = _streak;
                return Line(time, $"(the line above repeated {Times(_streak)} so far)");
            }

            var text = Finish(time);
            _last = message;
            return text + Line(time, message);
        }

        /// <summary>
        /// Ends the repeats of the line written last, as another line comes or the game closes.
        /// </summary>
        /// <param name="time">The time of day the count is stamped with.</param>
        /// <returns>How often the line repeated in all, <see langword="null"/> when the log told it already.</returns>
        public string? Finish(string time)
        {
            var text = _streak > _told ? Line(time, $"(the line above repeated {Times(_streak)} in all)") : null;
            _streak = 0;
            _told = 0;
            return text;
        }

        /// <summary>
        /// Writes a line of the log.
        /// </summary>
        /// <param name="time">The time of day.</param>
        /// <param name="message">The line.</param>
        /// <returns>The line with its time and line break.</returns>
        private static string Line(string time, string message) => $"{time}  {message}\r\n";

        /// <summary>
        /// Writes a count of repeats.
        /// </summary>
        /// <param name="count">The count.</param>
        /// <returns>Such as "1 time" or "12 times".</returns>
        private static string Times(int count) => count == 1 ? "1 time" : $"{count.ToString(CultureInfo.InvariantCulture)} times";
    }
}
