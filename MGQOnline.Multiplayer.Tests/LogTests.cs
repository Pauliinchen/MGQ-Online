//----------------------------------------------------------------
//  LogTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-10-23: Checked a flood told while it goes on, the scripts' lines and the logs of earlier days deleted
//      Paulinchen  2026-10-15: Checked the log named after the day the game started on
//      Paulinchen  2026-10-11: Checked cutting a log down to its newest lines
//      Paulinchen  2026-10-07: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Linq;
using System.Text;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Multiplayer.Tests;

/// <summary>
/// Covers the log: the file of each day, the lines repeated, the scripts' lines, the logs of earlier days, and the writer thread that keeps callers off the disk.
/// </summary>
public sealed class LogTests
{
    /// <summary>
    /// Asserts that the log is named after the day the game started on.
    /// </summary>
    [Fact]
    public void FileNameOf_NamesTheLogAfterTheDayTheGameStartedOn()
    {
        Assert.Equal(@"Logs\Multiplayer 2026-10-07.log", Log.FileNameOf(new DateTime(2026, 10, 7, 8, 5, 9)));
    }

    /// <summary>
    /// Asserts that a line repeated is counted, and the count written once another line follows.
    /// </summary>
    [Fact]
    public void Repeats_CountsALineRepeatedAndWritesTheCountBeforeTheNextLine()
    {
        var repeats = new Log.Repeats();

        Assert.Equal("10:00:00  first\r\n", repeats.Take("10:00:00", "first"));
        Assert.Null(repeats.Take("10:00:01", "first"));
        Assert.Null(repeats.Take("10:00:02", "first"));
        Assert.Equal("10:00:03  (the line above repeated 2 times in all)\r\n10:00:03  second\r\n", repeats.Take("10:00:03", "second"));
        Assert.Null(repeats.Take("10:00:04", "second"));
        Assert.Equal("10:00:05  (the line above repeated 1 time in all)\r\n10:00:05  first\r\n", repeats.Take("10:00:05", "first"));
    }

    /// <summary>
    /// Asserts that a line that keeps repeating says so while it goes on, and how often in all when the game closes.
    /// </summary>
    [Fact]
    public void Repeats_TellsAFloodWhileItGoesOnAndInAllAtTheEnd()
    {
        var repeats = new Log.Repeats();
        repeats.Take("10:00:00", "flood");

        var told = Enumerable.Range(1, 11).Select(_ => repeats.Take("10:00:01", "flood")).Where(text => text is not null).ToList();

        Assert.Equal(["10:00:01  (the line above repeated 10 times so far)\r\n"], told);
        Assert.Equal("10:00:02  (the line above repeated 11 times in all)\r\n", repeats.Finish("10:00:02"));
        Assert.Null(repeats.Finish("10:00:03"));
    }

    /// <summary>
    /// Asserts that a short id stays as it is and a long one is cut to 12 characters.
    /// </summary>
    [Fact]
    public void Short_CutsLongIds()
    {
        Assert.Equal("ab12", Log.Short("ab12"));
        Assert.Equal("0123456789ab", Log.Short("0123456789abcdef0123456789abcdef"));
        Assert.Equal("?", Log.Short(null));
    }

    /// <summary>
    /// Asserts that lines written are in the file once flushed, in the order they were written, with a repeat only counted.
    /// </summary>
    /// <remarks>
    /// Other tests log meanwhile, so a line of theirs may land between two of these, which then counts as no repeat.
    /// </remarks>
    [Fact]
    public void Write_ThenFlush_PutsTheLinesInTheFileInOrder()
    {
        var mark = Guid.NewGuid().ToString("N");
        var first = $"log test {mark} first";
        var second = $"log test {mark} second";
        var third = $"log test {mark} third";

        Log.Write(first);
        Log.Write(second);
        Log.Write(second);
        Log.Write(third);
        Log.Flush();

        var text = ReadLog();
        var atFirst = text.IndexOf(first, StringComparison.Ordinal);
        var atSecond = text.IndexOf(second, StringComparison.Ordinal);
        var atThird = text.IndexOf(third, StringComparison.Ordinal);

        Assert.True(atFirst >= 0, "the first line is missing");
        Assert.True(atSecond > atFirst, "the second line does not follow the first");
        Assert.True(atThird > atSecond, "the third line does not follow the second");

        var between = text[atSecond..atThird];
        Assert.True(between.Contains("(the line above repeated 1 time in all)\r\n", StringComparison.Ordinal) || between.LastIndexOf(second, StringComparison.Ordinal) > 0, "the repeated line was neither counted nor written again");
    }

    /// <summary>
    /// Asserts that a line the scripts hand over lands in the same file, marked as theirs, with the time they wrote it at, its bytes read as UTF-8.
    /// </summary>
    [Fact]
    public void ScriptLog_WritesTheScriptsLineMarkedWithItsTime()
    {
        var mark = Guid.NewGuid().ToString("N");
        var bytes = Encoding.UTF8.GetBytes($"world: joined {mark} ルカ").Concat(new byte[] { 0xFF }).ToArray();

        ScriptLog.Write(new RubyArray([RubyString.Utf8("01:02:03"), RubyString.Binary(bytes)]));
        Log.Flush();

        Assert.Contains($"01:02:03  [script] world: joined {mark} ルカ�\r\n", ReadLog(), StringComparison.Ordinal);
        Assert.Throws<BridgeRequestException>(() => ScriptLog.Write(new RubyArray([RubyString.Utf8("01:02:03")])));
    }

    /// <summary>
    /// Asserts that every log of the mod but the day's goes, older builds' scripts' logs and unstamped ones too, while other mods' logs stay and
    /// a folder of a log's name counts as one that could not be deleted.
    /// </summary>
    [Fact]
    public void DeleteOtherDays_KeepsTheDaysLogsAndOtherModsLogs()
    {
        var folder = Path.Combine(Path.GetTempPath(), $"log test {Guid.NewGuid():N}");
        Directory.CreateDirectory(folder);

        try
        {
            string[] kept = ["Multiplayer 2026-10-07.log", "Multiplayer InGame 2026-10-07.log", "Multiplayer Parking.log", "DiscordPresence 2026-01-01.log"];
            string[] gone = ["Multiplayer 2026-01-01.log", "Multiplayer InGame 2026-01-01.log", "Multiplayer InGame 2026-01-01 options dump.log", "Multiplayer 2026-10-07 10-00-00.log", "Multiplayer.log", "Multiplayer InGame.log"];

            foreach (var name in kept.Concat(gone))
            {
                File.WriteAllText(Path.Combine(folder, name), "x");
            }

            Directory.CreateDirectory(Path.Combine(folder, "Multiplayer InGame 2026-01-02.log"));

            Assert.Equal((gone.Length, 1), Log.DeleteOtherDays(folder, "2026-10-07"));
            Assert.Equal(kept.Append("Multiplayer InGame 2026-01-02.log").Order(StringComparer.Ordinal), Directory.EnumerateFileSystemEntries(folder).Select(Path.GetFileName).Order(StringComparer.Ordinal));
        }
        finally
        {
            Directory.Delete(folder, true);
        }
    }

    /// <summary>
    /// Asserts that a log cut down keeps its newest lines from a whole line on, behind the line that says so.
    /// </summary>
    [Fact]
    public void CutToNewest_KeepsTheNewestWholeLines()
    {
        var path = Path.Combine(Path.GetTempPath(), $"log test {Guid.NewGuid():N}.log");

        try
        {
            var text = new StringBuilder();

            for (var index = 0; index < 1000; index++)
            {
                text.Append($"12:00:00.000  line {index}\r\n");
            }

            File.WriteAllText(path, text.ToString());
            Log.CutToNewest(path, 100);

            var lines = File.ReadAllLines(path);
            Assert.Equal(Log.CutLine, lines[0]);
            Assert.Equal("12:00:00.000  line 999", lines[^1]);
            Assert.All(lines[1..], line => Assert.StartsWith("12:00:00.000  line ", line));
            Assert.True(lines.Length is > 2 and < 6, $"kept {lines.Length - 1} lines of about 25 bytes from 100 bytes");
        }
        finally
        {
            File.Delete(path);
        }
    }

    /// <summary>
    /// Reads the log file while the writer thread may still append to it.
    /// </summary>
    /// <returns>The log's text.</returns>
    private static string ReadLog()
    {
        using var file = new FileStream(Log.FilePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
        using var reader = new StreamReader(file, Encoding.UTF8);
        return reader.ReadToEnd();
    }
}
