//----------------------------------------------------------------
//  CrashEventsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using MGQParadox.Multiplayer.Windows;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Covers reading the game's crashes from the events Windows records.
/// </summary>
public sealed class CrashEventsTests
{
    /// <summary>
    /// The game's file name.
    /// </summary>
    private const string Game = "Game.exe";

    /// <summary>
    /// Windows' event of a crash of the game, as Windows 10 and 11 render it.
    /// </summary>
    private const string GameCrash =
        "<Event xmlns='http://schemas.microsoft.com/win/2004/08/events/event'><System><Provider Name='Application Error' Guid='{a0e9b465-b939-57d7-b27d-95d8e925ff57}'/>" +
        "<EventID>1000</EventID><Level>2</Level><TimeCreated SystemTime='2026-10-22T19:04:11.2930487Z'/><EventRecordID>25618</EventRecordID><Channel>Application</Channel></System>" +
        "<EventData><Data Name='AppName'>Game.exe</Data><Data Name='AppVersion'>1.0.2.0</Data><Data Name='AppTimeStamp'>4f2b6d51</Data><Data Name='ModuleName'>RGSS301.dll</Data>" +
        "<Data Name='ModuleVersion'>1.0.1.0</Data><Data Name='ModuleTimeStamp'>4f2b6d4c</Data><Data Name='ExceptionCode'>c0000005</Data><Data Name='FaultingOffset'>0001a2b3</Data>" +
        "<Data Name='ProcessId'>0x7d18</Data><Data Name='AppPath'>C:\\Games\\MGQ\\Game.exe</Data><Data Name='ModulePath'>C:\\Games\\MGQ\\System\\RGSS301.dll</Data><Data Name='PackageFullName'></Data></EventData></Event>";

    /// <summary>
    /// Asserts that Windows' event of a crash of the game gives the faulting module, the exception code and the offset.
    /// </summary>
    [Fact]
    public void Parse_GameCrash_ReadsModuleCodeAndOffset()
    {
        var crash = CrashEvents.Parse(GameCrash, Game);

        Assert.NotNull(crash);
        Assert.Equal(new DateTime(2026, 10, 22, 19, 4, 11, DateTimeKind.Utc).AddTicks(2_930_487), crash.Time);
        Assert.Equal(("RGSS301.dll", "1.0.1.0", "c0000005", "0001a2b3"), (crash.Module, crash.ModuleVersion, crash.ExceptionCode, crash.Offset));
        Assert.EndsWith(": faulting module RGSS301.dll 1.0.1.0, exception code 0xc0000005, offset 0x0001a2b3", CrashEvents.Describe(crash));
    }

    /// <summary>
    /// Asserts that another program's crash does not count, whatever case the game's name is in.
    /// </summary>
    [Fact]
    public void Parse_OtherProgram_IsNoCrashOfTheGame()
    {
        Assert.Null(CrashEvents.Parse(GameCrash.Replace(">Game.exe<", ">Editor.exe<"), Game));
        Assert.NotNull(CrashEvents.Parse(GameCrash, "GAME.EXE"));
    }

    /// <summary>
    /// Asserts that the values of an older Windows, which have no names, are read by their places.
    /// </summary>
    [Fact]
    public void Parse_UnnamedValues_ReadsThemByTheirPlaces()
    {
        var xml = "<Event><System><Provider Name='Application Error'/><EventID Qualifiers='0'>1000</EventID><TimeCreated SystemTime='2026-10-22T19:04:11.000Z'/></System>" +
            "<EventData><Data>Game.exe</Data><Data>1.0.2.0</Data><Data>4f2b6d51</Data><Data>ntdll.dll</Data><Data>6.1.7601.24545</Data><Data>5e0eb6bd</Data>" +
            "<Data>c0000374</Data><Data>000ce653</Data></EventData></Event>";

        var crash = CrashEvents.Parse(xml, Game);

        Assert.NotNull(crash);
        Assert.Equal(("ntdll.dll", "c0000374", "000ce653"), (crash.Module, crash.ExceptionCode, crash.Offset));
    }

    /// <summary>
    /// Asserts that a crash in .NET code gives its exception, its entities decoded.
    /// </summary>
    [Fact]
    public void Parse_DotNetCrash_ReadsTheException()
    {
        var xml = "<Event><System><Provider Name='.NET Runtime'/><EventID Qualifiers='0'>1026</EventID><TimeCreated SystemTime='2026-10-22T19:04:11.000Z'/></System>" +
            "<EventData><Data>Application: Game.exe\nCoreCLR Version: 10.0.1326.50504\nDescription: The process was terminated due to an unhandled exception.\n" +
            "Exception Info: System.InvalidOperationException: a &lt;b&gt; &amp; c\n   at Somewhere()\n</Data></EventData></Event>";

        var crash = CrashEvents.Parse(xml, Game);

        Assert.NotNull(crash);
        Assert.Equal("System.InvalidOperationException: a <b> & c", crash.DotNetException);
        Assert.EndsWith(" in .NET code: System.InvalidOperationException: a <b> & c", CrashEvents.Describe(crash));
    }

    /// <summary>
    /// Asserts that the mark of the previous start reads back in UTC, and that a missing mark is none.
    /// </summary>
    [Fact]
    public void ReadMark_WrittenTime_ReadsBackInUtc()
    {
        var path = Path.Combine(Path.GetTempPath(), $"crash-mark-{Guid.NewGuid():N}.dat");

        try
        {
            Assert.Null(CrashEvents.ReadMark(path));
            File.WriteAllText(path, "2026-10-22T19:04:11.250Z");
            Assert.Equal(new DateTime(2026, 10, 22, 19, 4, 11, 250, DateTimeKind.Utc), CrashEvents.ReadMark(path));
            Assert.Equal(DateTimeKind.Utc, CrashEvents.ReadMark(path)!.Value.Kind);
        }
        finally
        {
            File.Delete(path);
        }
    }
}
