//----------------------------------------------------------------
//  ReportFiles.cs
//
//  Changelog:
//      Paulinchen  2026-10-11: Left a file out of mods.txt that is gone by the time it is read
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Text;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Reports;

/// <summary>
/// Puts a bug report's files together as the relay commits them, each readable on its own:
/// <c>report.md</c> as their index, the screenshot, and on request the session's logs,
/// <c>errors.txt</c> and <c>mods.txt</c>, a list of the Patch folder. Text files go gzipped.
/// </summary>
internal static class ReportFiles
{
    /// <summary>
    /// The game folder's file the game writes a crash into.
    /// </summary>
    public const string ErrorsFile = "errors.txt";

    /// <summary>
    /// The list of the Patch folder.
    /// </summary>
    public const string ModsFile = "mods.txt";

    /// <summary>
    /// The folder of the logs in a report, as in the game folder.
    /// </summary>
    private const string LogsFolder = "Logs";

    /// <summary>
    /// The longest name of a file the relay takes, its folder included.
    /// </summary>
    private const int MaxNameLength = 120;

    /// <summary>
    /// The room a cut file keeps for the line that says how much was cut, so it stays within its limit.
    /// </summary>
    private const int CutNoteRoom = 128;

    /// <summary>
    /// The least of a log kept while cutting logs to fit; a log at it is left out next.
    /// </summary>
    private const int MinKeptBytes = 4 * 1024;

    /// <summary>
    /// How much of a cut file's start is searched for a line break to start the kept part at.
    /// </summary>
    private const int LineSearchBytes = 4 * 1024;

    /// <summary>
    /// Writes the time stamps of <c>mods.txt</c>.
    /// </summary>
    private const string TimeFormat = "yyyy-MM-dd HH:mm:ss";

    /// <summary>
    /// Puts the files together, cutting the largest logs from their start and leaving the oldest
    /// out until they fit the limits; <c>report.md</c> says what was cut or left out.
    /// </summary>
    /// <param name="page">What <c>report.md</c> tells besides the files.</param>
    /// <param name="screenshot">The screenshot's PNG, <see langword="null"/> for none.</param>
    /// <param name="gameFolder">The game folder whose logs, <c>errors.txt</c> and Patch folder go in; <see langword="null"/> without logs.</param>
    /// <param name="since">The logs and <c>errors.txt</c> go in when written at or after it, in UTC.</param>
    /// <param name="limits">The limits; <see langword="null"/> for the relay's.</param>
    /// <returns>The files in the order the body carries them: <c>report.md</c>, the screenshot, the logs, <c>errors.txt</c>, <c>mods.txt</c>.</returns>
    public static IReadOnlyList<ReportFile> Build(ReportPage page, byte[]? screenshot, string? gameFolder, DateTime since, ReportLimits? limits = null)
    {
        limits ??= ReportLimits.Relay;
        var parts = new List<Part>();
        var leftOut = new List<(string Name, string Why)>();

        if (gameFolder != null)
        {
            var errors = Path.Combine(gameFolder, ErrorsFile);
            var hasErrors = File.Exists(errors) && File.GetLastWriteTimeUtc(errors) >= since;
            var room = limits.Files - 2 - (screenshot != null ? 1 : 0) - (hasErrors ? 1 : 0);
            var logs = RecentLogs(Path.Combine(gameFolder, LogsFolder), since);

            foreach (var log in logs.Skip(Math.Max(0, room)))
            {
                leftOut.Add((LogName(log, []), $"left out, a report carries at most {limits.Files} files"));
            }

            var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            foreach (var log in logs.Take(Math.Max(0, room)).OrderBy(Path.GetFileName, StringComparer.OrdinalIgnoreCase))
            {
                AddFile(parts, leftOut, LogName(log, names), log, File.GetLastWriteTimeUtc(log), limits);
            }

            if (hasErrors)
            {
                AddFile(parts, leftOut, ErrorsFile, errors, DateTime.MaxValue, limits);
            }

            parts.Add(Part.Of(ModsFile, Encoding.UTF8.GetBytes(ModsList(Path.Combine(gameFolder, "Patch"))), DateTime.MaxValue, limits));
        }

        while (true)
        {
            var pageBytes = Encoding.UTF8.GetBytes(Page(page, screenshot != null, gameFolder != null, parts, leftOut));
            var text = pageBytes.Length + parts.Sum(part => (long)part.Rendered.Length);
            var files = new List<ReportFile> { new(DirectoryClient.ReportPageFile, Gzip(pageBytes), true) };

            if (screenshot != null)
            {
                files.Add(new ReportFile(DirectoryClient.ScreenshotFile, screenshot));
            }

            files.AddRange(parts.Select(part => new ReportFile(part.Name, part.Packed, true)));

            if (text <= limits.AllText && DirectoryClient.ReportBodyLength(page.Report, files) <= limits.Body)
            {
                if (DirectoryClient.ReportHeader(page.Report, files.Select(file => (file.Name, file.Base64Length, file.Gzip))).Length <= DirectoryClient.MaxReportHeaderBytes
                    || parts.Where(part => part.Name.StartsWith($"{LogsFolder}/", StringComparison.Ordinal)).MinBy(part => part.Written) is not { } oldest)
                {
                    return files;
                }

                parts.Remove(oldest);
                leftOut.Add((oldest.Name, "left out, the report names more files than its header has room for"));
                continue;
            }

            if (parts.MaxBy(part => part.Kept) is not { } largest)
            {
                return files;
            }

            if (largest.Kept > MinKeptBytes)
            {
                largest.Keep = Math.Max(MinKeptBytes, largest.Kept / 2);
            }
            else
            {
                parts.Remove(largest);
                leftOut.Add((largest.Name, "left out, the report is too large even with every log cut"));
                Log.Write($"bug report left {largest.Name} out, the report is too large even with every log cut");
            }
        }
    }

    /// <summary>
    /// Writes <c>report.md</c>.
    /// </summary>
    /// <param name="page">What it tells besides the files.</param>
    /// <param name="screenshot">Whether the screenshot goes along.</param>
    /// <param name="logs">Whether the logs were asked for.</param>
    /// <param name="parts">The text files that go along.</param>
    /// <param name="leftOut">The files left out, each with why.</param>
    /// <returns>The page.</returns>
    private static string Page(ReportPage page, bool screenshot, bool logs, IReadOnlyList<Part> parts, IReadOnlyList<(string Name, string Why)> leftOut)
    {
        var text = new StringBuilder();
        text.Append("# ").Append(page.Report.Title).Append("\n\n");
        text.Append(page.Report.Text.Replace("\r\n", "\n")).Append("\n\n");

        text.Append("## Facts\n");
        AppendTable(text, page.Report.Facts);
        text.Append('\n');

        text.Append("## Details\n");
        AppendTable(text, [
            new ReportFact("Sent", page.Sent.ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", CultureInfo.InvariantCulture)),
            new ReportFact("Mod build", page.Build),
            new ReportFact("Development build", page.DevelopmentBuild ? "yes" : "no"),
            .. page.Details,
        ]);
        text.Append('\n');

        text.Append("## Screenshot\n");
        text.Append(screenshot ? $"![Screenshot]({DirectoryClient.ScreenshotFile})" : page.ScreenshotNote ?? "No screenshot attached.").Append("\n\n");

        text.Append("## Files\n");

        if (!logs)
        {
            text.Append("Logs not attached.\n");
        }

        foreach (var part in parts)
        {
            text.Append("- [").Append(part.Name).Append("](").Append(LinkOf(part.Name)).Append(") - ").Append(SizeOf(part)).Append('\n');
        }

        foreach (var (name, why) in leftOut)
        {
            text.Append("- ").Append(name).Append(" - ").Append(why).Append('\n');
        }

        return text.ToString();
    }

    /// <summary>
    /// Lists every file under the Patch folder, for <c>mods.txt</c>.
    /// </summary>
    /// <param name="patch">The Patch folder.</param>
    /// <returns>One line per file: its path relative to the Patch folder, its size in bytes and its last write in UTC, separated by tabs.</returns>
    public static string ModsList(string patch)
    {
        if (!Directory.Exists(patch))
        {
            return "The game folder has no Patch folder.\r\n";
        }

        var text = new StringBuilder();
        var options = new EnumerationOptions { RecurseSubdirectories = true, IgnoreInaccessible = true };

        foreach (var file in Directory.EnumerateFiles(patch, "*", options).Order(StringComparer.OrdinalIgnoreCase))
        {
            text.Append(ModsLine(patch, file));
        }

        return text.ToString();
    }

    /// <summary>
    /// Writes one file's line of <c>mods.txt</c>.
    /// </summary>
    /// <remarks>A file listed may be gone when it is read, as the world autosave's SaveTemp.rvdata2, which the game renames into place.</remarks>
    /// <param name="patch">The Patch folder.</param>
    /// <param name="file">The file.</param>
    /// <returns>Its path relative to the Patch folder, its size in bytes and its last write in UTC, separated by tabs; empty for a file gone or out of reach.</returns>
    public static string ModsLine(string patch, string file)
    {
        try
        {
            var info = new FileInfo(file);
            return $"{Path.GetRelativePath(patch, file)}\t{info.Length.ToString(CultureInfo.InvariantCulture)}\t" +
                   $"{info.LastWriteTimeUtc.ToString(TimeFormat, CultureInfo.InvariantCulture)}\r\n";
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            return "";
        }
    }

    /// <summary>
    /// Keeps the end of a file, starting with a line that says how much was cut.
    /// </summary>
    /// <param name="tail">The end of the file as read.</param>
    /// <param name="length">The file's whole length in bytes.</param>
    /// <param name="keep">The most of the end to keep.</param>
    /// <returns>The file as it is when nothing is cut, else the cut line and the end, from the first line that starts within it.</returns>
    public static byte[] Cut(byte[] tail, long length, int keep)
    {
        if (tail.Length == length && length <= keep)
        {
            return tail;
        }

        var start = Math.Max(0, tail.Length - keep);
        var atLineStart = start > 0 ? tail[start - 1] == '\n' : tail.Length == length;

        if (!atLineStart)
        {
            var lineBreak = Array.IndexOf(tail, (byte)'\n', start, Math.Min(LineSearchBytes, tail.Length - start));

            if (lineBreak >= 0)
            {
                start = lineBreak + 1;
            }
            else
            {
                // Never start in the middle of a UTF-8 character.
                while (start < tail.Length && (tail[start] & 0xC0) == 0x80)
                {
                    start++;
                }
            }
        }

        var cut = length - (tail.Length - start);
        var note = Encoding.UTF8.GetBytes($"[{cut.ToString(CultureInfo.InvariantCulture)} bytes were cut from the start of this file]\r\n");
        return [.. note, .. tail.AsSpan(start)];
    }

    /// <summary>
    /// Names a log in the report: in the Logs folder, its name cleaned to what the relay takes and made unique.
    /// </summary>
    /// <param name="path">The log's path.</param>
    /// <param name="taken">The names given so far, compared regardless of case; the name is added.</param>
    /// <returns>The name, such as <c>Logs/Multiplayer 2026-10-11 20-19-33.log</c>.</returns>
    internal static string LogName(string path, HashSet<string> taken)
    {
        var extension = Path.GetExtension(path).ToLowerInvariant();
        var stem = new string(Path.GetFileNameWithoutExtension(path).Select(character => char.IsAsciiLetterOrDigit(character) || character is ' ' or '.' or '_' or '(' or ')' or '+' or '-' ? character : '_').ToArray());

        if (stem.Length == 0 || !char.IsAsciiLetterOrDigit(stem[0]))
        {
            stem = $"log{stem}";
        }

        var room = MaxNameLength - LogsFolder.Length - 1 - extension.Length;

        for (var number = 1; ; number++)
        {
            var suffix = number == 1 ? string.Empty : $" ({number.ToString(CultureInfo.InvariantCulture)})";
            var name = $"{LogsFolder}/{stem[..Math.Min(stem.Length, room - suffix.Length)]}{suffix}{extension}";

            if (taken.Add(name))
            {
                return name;
            }
        }
    }

    /// <summary>
    /// Describes a file's size in <c>report.md</c>.
    /// </summary>
    /// <param name="part">The file.</param>
    /// <returns>Its size, such as "812 KB", or what was kept of how much, such as "last 8 MiB of 9.3 MiB".</returns>
    private static string SizeOf(Part part) =>
        part.Length > part.Kept ? $"last {Bytes(part.Rendered.Length)} of {Bytes(part.Length)}" : Bytes(part.Length);

    /// <summary>
    /// Writes a number of bytes the way people read it.
    /// </summary>
    /// <param name="bytes">The number of bytes.</param>
    /// <returns>Whole KB below a MiB, at least 1, else MiB with one decimal unless it is whole.</returns>
    internal static string Bytes(long bytes) =>
        bytes < 1024 * 1024
            ? $"{Math.Max(1, (long)Math.Round(bytes / 1024.0)).ToString(CultureInfo.InvariantCulture)} KB"
            : $"{(Math.Round(bytes / (1024.0 * 1024.0), 1)).ToString("0.#", CultureInfo.InvariantCulture)} MiB";

    /// <summary>
    /// Builds a relative link to a file of the report.
    /// </summary>
    /// <param name="name">The file's name, its folder included.</param>
    /// <returns>Each segment escaped, joined by <c>/</c>.</returns>
    private static string LinkOf(string name) => string.Join('/', name.Split('/').Select(Uri.EscapeDataString));

    /// <summary>
    /// Appends a two-column table, each cell on one line with <c>|</c> escaped.
    /// </summary>
    /// <param name="text">The page so far.</param>
    /// <param name="rows">The rows.</param>
    private static void AppendTable(StringBuilder text, IEnumerable<ReportFact> rows)
    {
        text.Append("| | |\n| --- | --- |\n");

        foreach (var row in rows)
        {
            text.Append("| ").Append(Cell(row.Label)).Append(" | ").Append(Cell(row.Value)).Append(" |\n");
        }
    }

    /// <summary>
    /// Makes a text fit a table cell.
    /// </summary>
    /// <param name="value">The text.</param>
    /// <returns>The text on one line, <c>|</c> escaped.</returns>
    private static string Cell(string value) => value.Replace("\r", " ").Replace("\n", " ").Replace("|", "\\|");

    /// <summary>
    /// Lists the logs of a folder written at or after a moment, the newest first.
    /// </summary>
    /// <param name="folder">The folder; its subfolders are left out.</param>
    /// <param name="since">The moment, in UTC.</param>
    /// <returns>The paths of its <c>*.log</c> and <c>*.txt</c> files, none when the folder is missing.</returns>
    private static List<string> RecentLogs(string folder, DateTime since) =>
        Directory.Exists(folder)
            ? Directory.EnumerateFiles(folder)
                .Where(file => Path.GetExtension(file).ToLowerInvariant() is ".log" or ".txt" && File.GetLastWriteTimeUtc(file) >= since)
                .OrderByDescending(File.GetLastWriteTimeUtc)
                .ToList()
            : [];

    /// <summary>
    /// Reads the end of a file into the parts, while another program may write or delete it; a file that cannot be read is left out.
    /// </summary>
    /// <param name="parts">The text files so far.</param>
    /// <param name="leftOut">The files left out so far.</param>
    /// <param name="name">The file's name in the report.</param>
    /// <param name="path">The file.</param>
    /// <param name="written">When it was last written, in UTC, which orders the logs left out first.</param>
    /// <param name="limits">The limits.</param>
    private static void AddFile(List<Part> parts, List<(string Name, string Why)> leftOut, string name, string path, DateTime written, ReportLimits limits)
    {
        try
        {
            using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
            var length = stream.Length;
            var start = Math.Max(0, length - limits.TextFile);
            stream.Seek(start, SeekOrigin.Begin);

            var tail = new byte[length - start];
            var read = stream.ReadAtLeast(tail, tail.Length, throwOnEndOfStream: false);
            parts.Add(Part.Of(name, tail[..read], written, limits, start + read));
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            leftOut.Add((name, "left out, it could not be read"));
            Log.Write($"bug report left {name} out: {ex.Message}");
        }
    }

    /// <summary>
    /// Gzips a text file.
    /// </summary>
    /// <param name="bytes">The file.</param>
    /// <returns>The gzip stream.</returns>
    private static byte[] Gzip(byte[] bytes)
    {
        using var packed = new MemoryStream();

        using (var gzip = new GZipStream(packed, CompressionLevel.Optimal, leaveOpen: true))
        {
            gzip.Write(bytes);
        }

        return packed.ToArray();
    }

    /// <summary>
    /// A text file of the report.
    /// </summary>
    /// <param name="name">Its name in the report.</param>
    /// <param name="data">Its bytes, for a file read the end as read.</param>
    /// <param name="length">The whole file's length in bytes, of which <paramref name="data"/> is the end.</param>
    /// <param name="written">When it was last written, in UTC.</param>
    /// <param name="keep">The most of its end kept.</param>
    private sealed class Part(string name, byte[] data, long length, DateTime written, int keep)
    {
        /// <summary>
        /// The <see cref="Keep"/> <see cref="_rendered"/> and <see cref="_packed"/> were made with, -1 before.
        /// </summary>
        private int _madeWith = -1;

        /// <summary>
        /// The file as sent, unpacked.
        /// </summary>
        private byte[] _rendered = [];

        /// <summary>
        /// The file as sent, gzipped.
        /// </summary>
        private byte[] _packed = [];

        /// <summary>
        /// Its name in the report.
        /// </summary>
        public string Name { get; } = name;

        /// <summary>
        /// The whole file's length in bytes.
        /// </summary>
        public long Length { get; } = length;

        /// <summary>
        /// When it was last written, in UTC.
        /// </summary>
        public DateTime Written { get; } = written;

        /// <summary>
        /// The most of its end kept.
        /// </summary>
        public int Keep { get; set; } = keep;

        /// <summary>
        /// How much of its end is kept now, at most what was read.
        /// </summary>
        public int Kept => Math.Min(Keep, data.Length);

        /// <summary>
        /// The file as sent, unpacked: cut to what it keeps.
        /// </summary>
        public byte[] Rendered
        {
            get
            {
                Make();
                return _rendered;
            }
        }

        /// <summary>
        /// The file as sent, gzipped.
        /// </summary>
        public byte[] Packed
        {
            get
            {
                Make();
                return _packed;
            }
        }

        /// <summary>
        /// Makes a part of a file, keeping as much as the limit for a text file lets with room for the cut line.
        /// </summary>
        /// <param name="name">Its name in the report.</param>
        /// <param name="data">Its bytes, for a file read the end as read.</param>
        /// <param name="written">When it was last written, in UTC.</param>
        /// <param name="limits">The limits.</param>
        /// <param name="length">The whole file's length, <see langword="null"/> when <paramref name="data"/> is all of it.</param>
        /// <returns>The part.</returns>
        public static Part Of(string name, byte[] data, DateTime written, ReportLimits limits, long? length = null)
        {
            var whole = length ?? data.Length;
            return new Part(name, data, whole, written, whole <= limits.TextFile ? limits.TextFile : limits.TextFile - CutNoteRoom);
        }

        /// <summary>
        /// Cuts and gzips the file once per <see cref="Keep"/>.
        /// </summary>
        private void Make()
        {
            if (_madeWith == Keep)
            {
                return;
            }

            _rendered = Cut(data, Length, Keep);
            _packed = Gzip(_rendered);
            _madeWith = Keep;
        }
    }
}

/// <summary>
/// What <c>report.md</c> tells besides the files.
/// </summary>
/// <param name="Report">The title, text and public facts.</param>
/// <param name="Details">The private details.</param>
/// <param name="Sent">When the report was sent, in UTC.</param>
/// <param name="Build">The mod's version as the build stamped it, with its commit.</param>
/// <param name="DevelopmentBuild">Whether the mod is a development build.</param>
/// <param name="ScreenshotNote">What the screenshot section says without a screenshot, <see langword="null"/> for "No screenshot attached.".</param>
internal sealed record ReportPage(BugReport Report, IReadOnlyList<ReportFact> Details, DateTime Sent, string Build, bool DevelopmentBuild, string? ScreenshotNote = null);

/// <summary>
/// The limits a report's files are cut to.
/// </summary>
/// <param name="TextFile">The most bytes of one text file, unpacked.</param>
/// <param name="AllText">The most bytes of all text files together, unpacked.</param>
/// <param name="Body">The most bytes of the whole body.</param>
/// <param name="Files">The most files.</param>
internal sealed record ReportLimits(int TextFile, int AllText, int Body, int Files)
{
    /// <summary>
    /// The relay's limits.
    /// </summary>
    public static ReportLimits Relay { get; } = new(8 * 1024 * 1024, 24 * 1024 * 1024, 15 * 1024 * 1024, 32);
}
