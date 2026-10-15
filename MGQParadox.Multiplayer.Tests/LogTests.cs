//----------------------------------------------------------------
//  LogTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-15: Checked the log named after the day the game started on
//      Paulinchen  2026-10-11: Checked cutting a log down to its newest lines
//      Paulinchen  2026-10-07: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Text;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Covers the DLL's log: the file of each day, the lines repeated, and the writer thread that keeps callers off the disk.
/// </summary>
public sealed class LogTests
{
    /// <summary>
    /// Asserts that the log is named after the day the game started on, as the game script's log of the same day is.
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
        Assert.Equal("10:00:03  (the line above came 2 more times)\r\n10:00:03  second\r\n", repeats.Take("10:00:03", "second"));
        Assert.Null(repeats.Take("10:00:04", "second"));
        Assert.Equal("10:00:05  (the line above came 1 more time)\r\n10:00:05  first\r\n", repeats.Take("10:00:05", "first"));
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
        Assert.True(between.Contains("(the line above came 1 more time)\r\n", StringComparison.Ordinal) || between.LastIndexOf(second, StringComparison.Ordinal) > 0, "the repeated line was neither counted nor written again");
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
