//----------------------------------------------------------------
//  IniFileTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Covers the key=value files: reading any encoding Notepad saves, writing in one step, and a file that cannot be read.
/// </summary>
public sealed class IniFileTests : IDisposable
{
    /// <summary>
    /// A folder of the test's own.
    /// </summary>
    private readonly string _folder = Path.Combine(Path.GetTempPath(), $"ini test {Guid.NewGuid():N}");

    /// <summary>
    /// Creates the test's folder.
    /// </summary>
    public IniFileTests() => Directory.CreateDirectory(_folder);

    /// <inheritdoc />
    public void Dispose() => Directory.Delete(_folder, true);

    /// <summary>
    /// Asserts that a byte order mark is skipped, ANSI reads as Latin-1, and UTF-16 either way round keeps an emoji.
    /// </summary>
    [Fact]
    public void Parse_ReadsEveryEncodingNotepadSaves()
    {
        Assert.Equal(Pairs(("id", "abc"), ("name", "X")), IniFile.Parse([0xEF, 0xBB, 0xBF, .. "id=abc\r\nname=X\r\n"u8]));
        Assert.Equal(Pairs(("id", "abc"), ("name", "Jörg")), IniFile.Parse([.. "id=abc\nname=J"u8, 0xF6, .. "rg\n"u8]));
        Assert.Equal(Pairs(("id", "abc"), ("name", "Jö😀")), IniFile.Parse([0xFF, 0xFE, .. Encoding.Unicode.GetBytes("id=abc\r\nname=Jö😀\r\n")]));
        Assert.Equal(Pairs(("id", "abc")), IniFile.Parse([0xFE, 0xFF, .. Encoding.BigEndianUnicode.GetBytes("id=abc\n")]));
    }

    /// <summary>
    /// Asserts that keys and values lose the spaces around them, a line without "=" is left out, a key that comes again keeps its place
    /// and takes the last value, and a lone surrogate reads as U+FFFD.
    /// </summary>
    [Fact]
    public void Parse_TakesTheLinesAsTheScriptsDid()
    {
        Assert.Equal(Pairs(("a", "1 = 2"), ("b", "3")), IniFile.Parse(" a = 1 = 2 \nno line\nb=x\r\na=1 = 2\nb=3"u8));
        Assert.Equal(Pairs(("n", "�")), IniFile.Parse([0xFF, 0xFE, .. Encoding.Unicode.GetBytes("n="), 0x00, 0xD8]));
    }

    /// <summary>
    /// Asserts that a write saves UTF-8 without a byte order mark, keeps each value on its line, leaves no file next to it, and that a
    /// file written reads back as it was.
    /// </summary>
    [Fact]
    public void Write_ReplacesTheFileInOneStep()
    {
        var path = Path.Combine(_folder, "Player.ini");
        File.WriteAllText(path, "old=1\n");

        Assert.True(IniFile.Write(path, "Player.ini", Pairs(("id", "abc"), ("name", "Jö\r\nrg"))));
        Assert.Equal("id=abc\nname=Jö  rg\n"u8.ToArray(), File.ReadAllBytes(path));
        Assert.False(File.Exists(path + IniFile.TempSuffix));
        Assert.Equal(Pairs(("id", "abc"), ("name", "Jö  rg")), IniFile.Load(path, "Player.ini", false));
    }

    /// <summary>
    /// Asserts that a missing file reads as empty, one that exists but cannot be read as nothing, and a write that cannot replace its file
    /// fails and leaves no file next to it.
    /// </summary>
    [Fact]
    public void LoadAndWrite_TellAFileThatCannotBeReadOrReplaced()
    {
        var blocked = Path.Combine(_folder, "Blocked");
        Directory.CreateDirectory(blocked);

        Assert.Empty(IniFile.Load(Path.Combine(_folder, "missing.ini"), "missing.ini", false)!);
        Assert.Null(IniFile.Load(blocked, "Blocked", true));
        Assert.False(IniFile.Write(blocked, "Blocked", Pairs(("a", "1"))));
        Assert.True(Directory.Exists(blocked));
        Assert.False(File.Exists(blocked + IniFile.TempSuffix));
    }

    /// <summary>
    /// Lists pairs as a file's values.
    /// </summary>
    /// <param name="pairs">The keys and values.</param>
    /// <returns>The values in order.</returns>
    private static List<KeyValuePair<string, string>> Pairs(params (string Key, string Value)[] pairs) =>
        pairs.Select(pair => new KeyValuePair<string, string>(pair.Key, pair.Value)).ToList();
}
