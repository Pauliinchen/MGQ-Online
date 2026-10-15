//----------------------------------------------------------------
//  ReportFilesTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-15: Checked that only the newest log of each type goes along
//      Paulinchen  2026-10-11: Checked that mods.txt skips a vanished file
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Text;
using MGQParadox.Multiplayer.Network.World;
using MGQParadox.Multiplayer.Reports;

namespace MGQParadox.Multiplayer.Tests.Reports;

/// <summary>
/// Covers a bug report's files, built from a game folder in a temporary folder: report.md as their
/// index, what goes in, how the files are named, and how large files and a large report are cut.
/// </summary>
public sealed class ReportFilesTests : IDisposable
{
    /// <summary>
    /// When the game started in these tests, in UTC.
    /// </summary>
    private static readonly DateTime Since = new(2026, 10, 11, 12, 0, 0, DateTimeKind.Utc);

    /// <summary>
    /// What report.md tells besides the files in these tests.
    /// </summary>
    private static readonly ReportPage Page = new(
        new BugReport("Formation stays shut", "It stays | shut.\r\nEvery time.", "0.6.3", [new ReportFact("Mod", "0.6.3"), new ReportFact("Where", "Scene|Map\n154")]),
        [new ReportFact("Player", "<Player>")],
        new DateTime(2026, 10, 11, 13, 4, 5, DateTimeKind.Utc),
        "0.6.3+abc",
        false);

    /// <summary>
    /// The game folder of the test.
    /// </summary>
    private readonly string _game = Path.Combine(Path.GetTempPath(), $"mgqmp-report-{Guid.NewGuid():N}");

    /// <summary>
    /// Creates the game folder.
    /// </summary>
    public ReportFilesTests() => Directory.CreateDirectory(_game);

    /// <inheritdoc />
    public void Dispose() => Directory.Delete(_game, true);

    /// <summary>
    /// Asserts that report.md lays the report out as title, text, the facts and details as
    /// tables with each cell on one line and | escaped, the screenshot section and the files section.
    /// </summary>
    [Fact]
    public void Build_WithoutLogs_SendsReportMdAlone()
    {
        var files = ReportFiles.Build(Page, null, null, Since);

        var page = Assert.Single(files);
        Assert.Equal(("report.md", true), (page.Name, page.Gzip));
        Assert.Equal(
            "# Formation stays shut\n\nIt stays | shut.\nEvery time.\n\n"
            + "## Facts\n| | |\n| --- | --- |\n| Mod | 0.6.3 |\n| Where | Scene\\|Map 154 |\n\n"
            + "## Details\n| | |\n| --- | --- |\n| Sent | 2026-10-11T13:04:05Z |\n| Mod build | 0.6.3+abc |\n| Development build | no |\n| Player | <Player> |\n\n"
            + "## Screenshot\nNo screenshot attached.\n\n"
            + "## Files\nLogs not attached.\n",
            Unpack(page));
    }

    /// <summary>
    /// Asserts that a screenshot left out names why in its section.
    /// </summary>
    [Fact]
    public void Build_ScreenshotLeftOut_SaysWhy()
    {
        var files = ReportFiles.Build(Page with { ScreenshotNote = "The screenshot was left out." }, null, null, Since);

        Assert.Contains("## Screenshot\nThe screenshot was left out.\n", Unpack(files[0]));
    }

    /// <summary>
    /// Asserts that with the screenshot and the logs the report carries report.md, the PNG as it is,
    /// the session's *.log and *.txt logs, the newest of each type, errors.txt and mods.txt, every text gzipped and linked
    /// from report.md with its size, while older, nested and other files stay out.
    /// </summary>
    [Fact]
    public void Build_WithScreenshotAndLogs_CarriesEveryFile()
    {
        Write(@"Logs\Multiplayer InGame 2026-10-11 20-19-33.log", "new line\r\n", Since.AddMinutes(5));
        Write(@"Logs\Game.txt", "game line\r\n", Since.AddSeconds(1));
        Write(@"Logs\Multiplayer old.log", "old line\r\n", Since.AddDays(-1));
        Write(@"Logs\state.dat", "binary\r\n", Since.AddMinutes(5));
        Write(@"Logs\Nested\inner.log", "inner\r\n", Since.AddMinutes(5));
        Write("errors.txt", "crash\r\n", Since.AddMinutes(6));
        Write(@"Patch\Multiplayer.rb", "12345", new DateTime(2026, 10, 1, 8, 0, 0, DateTimeKind.Utc));
        Write(@"Patch\Multiplayer\Scripts\ui.rbx", "1", new DateTime(2026, 10, 2, 9, 30, 0, DateTimeKind.Utc));
        byte[] png = [137, 80, 78, 71];

        var files = ReportFiles.Build(Page, png, _game, Since);

        Assert.Equal(
            [("report.md", true), ("screenshot.png", false), ("Logs/Game.txt", true), ("Logs/Multiplayer InGame 2026-10-11 20-19-33.log", true), ("errors.txt", true), ("mods.txt", true)],
            files.Select(file => (file.Name, file.Gzip)));
        Assert.Equal(png, files[1].Data);
        Assert.Equal("new line\r\n", Unpack(files[3]));
        Assert.Equal("crash\r\n", Unpack(files[4]));
        Assert.Equal("Multiplayer.rb\t5\t2026-10-01 08:00:00\r\nMultiplayer\\Scripts\\ui.rbx\t1\t2026-10-02 09:30:00\r\n", Unpack(files[5]));
        Assert.EndsWith(
            "## Screenshot\n![Screenshot](screenshot.png)\n\n## Files\n"
            + "- [Logs/Game.txt](Logs/Game.txt) - 1 KB\n"
            + "- [Logs/Multiplayer InGame 2026-10-11 20-19-33.log](Logs/Multiplayer%20InGame%202026-10-11%2020-19-33.log) - 1 KB\n"
            + "- [errors.txt](errors.txt) - 1 KB\n"
            + "- [mods.txt](mods.txt) - 1 KB\n",
            Unpack(files[0]),
            StringComparison.Ordinal);
    }

    /// <summary>
    /// Asserts that an errors.txt from before the game started stays out, and that a missing Patch folder is said in mods.txt.
    /// </summary>
    [Fact]
    public void Build_LeavesAnOldErrorsFileOut()
    {
        Write("errors.txt", "old crash\r\n", Since.AddHours(-2));

        var files = ReportFiles.Build(Page, null, _game, Since);

        Assert.Equal(["report.md", "mods.txt"], files.Select(file => file.Name));
        Assert.Equal("The game folder has no Patch folder.\r\n", Unpack(files[1]));
    }

    /// <summary>
    /// Asserts that a log another program holds open for writing is still read.
    /// </summary>
    [Fact]
    public void Build_ReadsALogHeldOpenForWriting()
    {
        var path = Write(@"Logs\Multiplayer open.log", "held\r\n", DateTime.UtcNow);

        using (new FileStream(path, FileMode.Open, FileAccess.ReadWrite, FileShare.ReadWrite | FileShare.Delete))
        {
            Assert.Equal("held\r\n", Unpack(ReportFiles.Build(Page, null, _game, Since).Single(file => file.Name == "Logs/Multiplayer open.log")));
        }
    }

    /// <summary>
    /// Asserts that a file over its limit keeps only its end, from a whole line on, behind a line
    /// saying how much was cut, within the limit, and that report.md says what was kept of how much.
    /// </summary>
    [Fact]
    public void Build_KeepsTheEndOfALargeLog()
    {
        var line = "0123456789 abcdefghijklmnopqrstuvwxyz\r\n";
        var lines = Enumerable.Range(0, 4000).Select(number => $"{number:D8} {line}").ToList();
        var whole = string.Concat(lines);
        Write(@"Logs\Multiplayer big.log", whole, Since.AddMinutes(1));
        var limits = new ReportLimits(64 * 1024, 1024 * 1024, 1024 * 1024, 32);

        var files = ReportFiles.Build(Page, null, _game, Since, limits);
        var kept = Unpack(files.Single(file => file.Name == "Logs/Multiplayer big.log"));
        var firstBreak = kept.IndexOf("\r\n", StringComparison.Ordinal);
        var rest = kept[(firstBreak + 2)..];

        Assert.True(Encoding.UTF8.GetByteCount(kept) <= limits.TextFile);
        Assert.True(Encoding.UTF8.GetByteCount(rest) > limits.TextFile - 256);
        Assert.EndsWith(rest, whole, StringComparison.Ordinal);
        Assert.Contains(rest[..(rest.IndexOf("\r\n", StringComparison.Ordinal) + 2)], lines);
        Assert.Equal($"[{Encoding.UTF8.GetByteCount(whole) - Encoding.UTF8.GetByteCount(rest)} bytes were cut from the start of this file]", kept[..firstBreak]);
        Assert.Contains("(Logs/Multiplayer%20big.log) - last 64 KB of 188 KB\n", Unpack(files[0]));
    }

    /// <summary>
    /// Asserts that all text files together are cut to their limit, the largest log first.
    /// </summary>
    [Fact]
    public void Build_CutsTheLargestLogsUntilAllTextFits()
    {
        Write(@"Logs\a.log", Lines(60 * 1024), Since.AddMinutes(1));
        Write(@"Logs\b.log", Lines(50 * 1024), Since.AddMinutes(1));
        Write(@"Logs\c.log", Lines(10 * 1024), Since.AddMinutes(1));
        var limits = new ReportLimits(64 * 1024, 80 * 1024, 1024 * 1024, 32);

        var files = ReportFiles.Build(Page, null, _game, Since, limits);

        Assert.True(files.Sum(file => (long)Encoding.UTF8.GetByteCount(Unpack(file))) <= limits.AllText);
        Assert.Equal(Lines(10 * 1024), Unpack(files.Single(file => file.Name == "Logs/c.log")));
        Assert.StartsWith("[", Unpack(files.Single(file => file.Name == "Logs/a.log")), StringComparison.Ordinal);
        Assert.Contains("(Logs/a.log) - last ", Unpack(files[0]));
    }

    /// <summary>
    /// Asserts that a body over its limit has its largest logs cut until it fits, the report itself kept whole.
    /// </summary>
    [Fact]
    public void Build_CutsTheLargestLogsUntilTheBodyFits()
    {
        WriteBytes(@"Logs\Multiplayer noise.log", Noise(1536 * 1024, 1), Since.AddMinutes(1));
        WriteBytes(@"Logs\Game noise.log", Noise(512 * 1024, 2), Since.AddMinutes(1));
        Write(@"Logs\Small.log", "small\r\n", Since.AddMinutes(1));
        var limits = new ReportLimits(8 * 1024 * 1024, 24 * 1024 * 1024, 600 * 1024, 32);

        var files = ReportFiles.Build(Page, null, _game, Since, limits);

        Assert.True(DirectoryClient.ReportBodyLength(Page.Report, files) <= limits.Body);
        Assert.Equal("small\r\n", Unpack(files.Single(file => file.Name == "Logs/Small.log")));
        Assert.StartsWith("[", Unpack(files.Single(file => file.Name == "Logs/Multiplayer noise.log")), StringComparison.Ordinal);
    }

    /// <summary>
    /// Asserts that logs are left out only as a last resort, each named in report.md.
    /// </summary>
    [Fact]
    public void Build_LeavesLogsOutAsALastResort()
    {
        WriteBytes(@"Logs\Multiplayer noise.log", Noise(64 * 1024, 1), Since.AddMinutes(1));
        WriteBytes(@"Logs\Game noise.log", Noise(64 * 1024, 2), Since.AddMinutes(1));
        var limits = new ReportLimits(8 * 1024 * 1024, 24 * 1024 * 1024, 4 * 1024, 32);

        var files = ReportFiles.Build(Page, null, _game, Since, limits);
        var page = Unpack(files[0]);

        Assert.DoesNotContain(files, file => file.Name.StartsWith("Logs/", StringComparison.Ordinal));
        Assert.Contains("- Logs/Multiplayer noise.log - left out, the report is too large even with every log cut\n", page);
        Assert.Contains("- Logs/Game noise.log - left out, the report is too large even with every log cut\n", page);
    }

    /// <summary>
    /// Asserts that past the most files the oldest logs are left out and named in report.md.
    /// </summary>
    [Fact]
    public void Build_TooManyFiles_LeavesTheOldestLogsOut()
    {
        for (var number = 1; number <= 5; number++)
        {
            Write($@"Logs\{number}.log", $"log {number}\r\n", Since.AddMinutes(number));
        }

        var files = ReportFiles.Build(Page, [1, 2, 3, 4], _game, Since, new ReportLimits(8 * 1024 * 1024, 24 * 1024 * 1024, 15 * 1024 * 1024, 6));
        var page = Unpack(files[0]);

        Assert.Equal(["report.md", "screenshot.png", "Logs/3.log", "Logs/4.log", "Logs/5.log", "mods.txt"], files.Select(file => file.Name));
        Assert.Contains("- Logs/2.log - left out, a report carries at most 6 files\n", page);
        Assert.Contains("- Logs/1.log - left out, a report carries at most 6 files\n", page);
    }

    /// <summary>
    /// Asserts that of the logs of one type, which differ only by the day or session start in their names, only the newest goes along.
    /// </summary>
    [Fact]
    public void Build_TakesTheNewestLogOfEachType()
    {
        Write(@"Logs\Multiplayer InGame 2026-10-11 12-00-10.log", "first session\r\n", Since.AddMinutes(1));
        Write(@"Logs\Multiplayer InGame 2026-10-11 12-00-40.log", "second session\r\n", Since.AddMinutes(2));
        Write(@"Logs\Multiplayer InGame 2026-10-11.log", "day\r\n", Since.AddMinutes(3));
        Write(@"Logs\Multiplayer 2026-10-11.log", "connection\r\n", Since.AddMinutes(1));
        Write(@"Logs\Multiplayer 2026-10-10.log", "yesterday\r\n", Since.AddSeconds(30));
        Write(@"Logs\Multiplayer Parking.log", "parking\r\n", Since.AddMinutes(1));

        var files = ReportFiles.Build(Page, null, _game, Since);

        Assert.Equal(
            ["report.md", "Logs/Multiplayer 2026-10-11.log", "Logs/Multiplayer InGame 2026-10-11.log", "Logs/Multiplayer Parking.log", "mods.txt"],
            files.Select(file => file.Name));
        Assert.Equal("Multiplayer InGame.log", ReportFiles.LogType(@"C:\Games\MGQ\Logs\Multiplayer InGame 2026-10-15 20-38-51.log"));
    }

    /// <summary>
    /// Asserts that a log is named by its file name cleaned to the characters the relay takes, starting with a letter or digit, at most 120 characters with its folder, and unique regardless of case.
    /// </summary>
    [Fact]
    public void LogName_CleansAndKeepsNamesUnique()
    {
        var taken = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        Assert.Equal("Logs/Multiplayer __1 (a).log", ReportFiles.LogName(@"C:\Game\Logs\Multiplayer ä#1 (a).LOG", taken));
        Assert.Equal("Logs/log_hidden.txt", ReportFiles.LogName(@"C:\Game\Logs\_hidden.txt", taken));
        Assert.Equal("Logs/multiplayer __1 (a) (2).log", ReportFiles.LogName(@"C:\Game\Logs\multiplayer ä#1 (a).log", taken));

        var longName = ReportFiles.LogName($@"C:\Game\Logs\{new string('x', 200)}.log", taken);
        Assert.Equal(120, longName.Length);
        Assert.EndsWith("x.log", longName, StringComparison.Ordinal);
    }

    /// <summary>
    /// Asserts that mods.txt lists a file with its size and leaves one out that is gone by the time it is read, as a world autosave's SaveTemp.rvdata2 renamed into place.
    /// </summary>
    [Fact]
    public void ModsLine_ListsAFileAndSkipsOneGone()
    {
        var patch = Path.Combine(_game, "Patch");
        var save = Path.Combine(patch, "Multiplayer", "Worlds", "w", "Save");
        Directory.CreateDirectory(save);
        File.WriteAllText(Path.Combine(save, "Save01.rvdata2"), "abc");

        Assert.StartsWith($"Multiplayer{Path.DirectorySeparatorChar}Worlds{Path.DirectorySeparatorChar}w{Path.DirectorySeparatorChar}Save{Path.DirectorySeparatorChar}Save01.rvdata2\t3\t",
            ReportFiles.ModsLine(patch, Path.Combine(save, "Save01.rvdata2")), StringComparison.Ordinal);
        Assert.Equal("", ReportFiles.ModsLine(patch, Path.Combine(save, "SaveTemp.rvdata2")));
    }

    /// <summary>
    /// Asserts how sizes read in report.md.
    /// </summary>
    [Fact]
    public void Bytes_ReadsAsKbOrMib()
    {
        Assert.Equal("1 KB", ReportFiles.Bytes(10));
        Assert.Equal("812 KB", ReportFiles.Bytes(812 * 1024));
        Assert.Equal("8 MiB", ReportFiles.Bytes(8 * 1024 * 1024));
        Assert.Equal("9.3 MiB", ReportFiles.Bytes((long)(9.3 * 1024 * 1024)));
    }

    /// <summary>
    /// Asserts that a file within its limit is kept as it is, and one cut further starts behind a note on a whole line.
    /// </summary>
    [Fact]
    public void Cut_KeepsSmallFilesAndStartsCutOnesAtALine()
    {
        var bytes = Encoding.UTF8.GetBytes("first\nsecond\nthird\n");

        Assert.Same(bytes, ReportFiles.Cut(bytes, bytes.Length, 100));
        Assert.Equal("[13 bytes were cut from the start of this file]\r\nthird\n", Encoding.UTF8.GetString(ReportFiles.Cut(bytes, bytes.Length, 9)));
        Assert.Equal("[6 bytes were cut from the start of this file]\r\nsecond\nthird\n", Encoding.UTF8.GetString(ReportFiles.Cut(bytes, bytes.Length, 13)));
    }

    /// <summary>
    /// Asserts that a cut through a line without a break never starts in the middle of a UTF-8 character.
    /// </summary>
    [Fact]
    public void Cut_WithoutALineBreak_StartsAtAWholeCharacter()
    {
        var bytes = Encoding.UTF8.GetBytes("アリスアリス");

        Assert.Equal("[9 bytes were cut from the start of this file]\r\nアリス", Encoding.UTF8.GetString(ReportFiles.Cut(bytes, bytes.Length, 10)));
    }

    /// <summary>
    /// Reads a text file of a report as the relay does.
    /// </summary>
    /// <param name="file">The file.</param>
    /// <returns>Its text, gunzipped when it says so.</returns>
    internal static string Unpack(ReportFile file)
    {
        if (!file.Gzip)
        {
            return Encoding.UTF8.GetString(file.Data);
        }

        using var gzip = new GZipStream(new MemoryStream(file.Data), CompressionMode.Decompress);
        using var reader = new StreamReader(gzip, Encoding.UTF8);
        return reader.ReadToEnd();
    }

    /// <summary>
    /// Makes numbered lines of about a size.
    /// </summary>
    /// <param name="bytes">The size wanted.</param>
    /// <returns>The lines.</returns>
    private static string Lines(int bytes) =>
        string.Concat(Enumerable.Range(0, bytes / 32).Select(number => $"{number:D8} line of the log ......\r\n"));

    /// <summary>
    /// Writes a text file into the game folder.
    /// </summary>
    /// <param name="path">The path relative to the game folder.</param>
    /// <param name="text">The text.</param>
    /// <param name="written">Its last write in UTC.</param>
    /// <returns>The full path.</returns>
    private string Write(string path, string text, DateTime written) => WriteBytes(path, Encoding.UTF8.GetBytes(text), written);

    /// <summary>
    /// Writes a file into the game folder.
    /// </summary>
    /// <param name="path">The path relative to the game folder.</param>
    /// <param name="bytes">The bytes.</param>
    /// <param name="written">Its last write in UTC.</param>
    /// <returns>The full path.</returns>
    private string WriteBytes(string path, byte[] bytes, DateTime written)
    {
        var full = Path.Combine(_game, path);
        Directory.CreateDirectory(Path.GetDirectoryName(full)!);
        File.WriteAllBytes(full, bytes);
        File.SetLastWriteTimeUtc(full, written);
        return full;
    }

    /// <summary>
    /// Makes bytes that hardly compress, as lines of random letters.
    /// </summary>
    /// <param name="length">How many bytes.</param>
    /// <param name="seed">The random seed.</param>
    /// <returns>The bytes.</returns>
    private static byte[] Noise(int length, int seed)
    {
        var random = new Random(seed);
        var bytes = new byte[length];

        for (var i = 0; i < length; i++)
        {
            bytes[i] = i % 80 == 79 ? (byte)'\n' : (byte)random.Next(33, 127);
        }

        return bytes;
    }
}
