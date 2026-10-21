//----------------------------------------------------------------
//  ExeSwapTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using MGQOnline.Updates.Tests.Support;

namespace MGQOnline.Updates.Tests;

/// <summary>
/// Tests the rename swap and its rollback in a scratch folder.
/// </summary>
public sealed class ExeSwapTests : IDisposable
{
    /// <summary>
    /// The folder the test's program lives in.
    /// </summary>
    private readonly ScratchFolder _folder = new();

    /// <summary>
    /// The test's program, holding the text "old".
    /// </summary>
    private readonly string _exe;

    /// <summary>
    /// Creates the old program and the staged new one.
    /// </summary>
    public ExeSwapTests()
    {
        _exe = _folder.Write("RaidDesigner.exe", "old");
        _folder.Write("RaidDesigner.exe.new", "new");
    }

    /// <inheritdoc />
    public void Dispose() => _folder.Dispose();

    /// <summary>
    /// The staged and kept files sit next to the program with their suffixes.
    /// </summary>
    [Fact]
    public void NamesTheStagedAndKeptFiles()
    {
        Assert.Equal(_folder.File("RaidDesigner.exe.new"), ExeSwap.NewPathOf(_exe));
        Assert.Equal(_folder.File("RaidDesigner.exe.old"), ExeSwap.OldPathOf(_exe));
    }

    /// <summary>
    /// The install moves the program to .old and the download in its place.
    /// </summary>
    [Fact]
    public void InstallsTheDownload()
    {
        ExeSwap.Install(_exe);

        Assert.Equal("new", File.ReadAllText(_exe));
        Assert.Equal("old", File.ReadAllText(ExeSwap.OldPathOf(_exe)));
        Assert.False(File.Exists(ExeSwap.NewPathOf(_exe)));
    }

    /// <summary>
    /// An .old left from an earlier update is replaced.
    /// </summary>
    [Fact]
    public void ReplacesAnEarlierOld()
    {
        _folder.Write("RaidDesigner.exe.old", "older");

        ExeSwap.Install(_exe);

        Assert.Equal("old", File.ReadAllText(ExeSwap.OldPathOf(_exe)));
    }

    /// <summary>
    /// Without a staged download nothing changes.
    /// </summary>
    [Fact]
    public void RefusesWithoutADownload()
    {
        File.Delete(ExeSwap.NewPathOf(_exe));

        Assert.Throws<UpdateRefusedException>(() => ExeSwap.Install(_exe));
        Assert.Equal("old", File.ReadAllText(_exe));
        Assert.False(File.Exists(ExeSwap.OldPathOf(_exe)));
    }

    /// <summary>
    /// When the download cannot take the program's name, the program is moved back.
    /// </summary>
    [Fact]
    public void PutsTheProgramBackWhenTheDownloadIsHeld()
    {
        Assert.SkipUnless(OperatingSystem.IsWindows(), "Only Windows refuses to move a file another handle holds.");

        using (new FileStream(ExeSwap.NewPathOf(_exe), FileMode.Open, FileAccess.Read, FileShare.None))
        {
            Assert.Throws<UpdateRefusedException>(() => ExeSwap.Install(_exe));
        }

        Assert.Equal("old", File.ReadAllText(_exe));
        Assert.False(File.Exists(ExeSwap.OldPathOf(_exe)));
        Assert.Equal("new", File.ReadAllText(ExeSwap.NewPathOf(_exe)));
    }

    /// <summary>
    /// The rollback puts the old program back and the installed download to .new again.
    /// </summary>
    [Fact]
    public void RollsBack()
    {
        ExeSwap.Install(_exe);

        ExeSwap.RollBack(_exe);

        Assert.Equal("old", File.ReadAllText(_exe));
        Assert.Equal("new", File.ReadAllText(ExeSwap.NewPathOf(_exe)));
        Assert.False(File.Exists(ExeSwap.OldPathOf(_exe)));
    }

    /// <summary>
    /// The rollback also works when the installed program is already gone.
    /// </summary>
    [Fact]
    public void RollsBackWithoutTheInstalledProgram()
    {
        ExeSwap.Install(_exe);
        File.Delete(_exe);

        ExeSwap.RollBack(_exe);

        Assert.Equal("old", File.ReadAllText(_exe));
    }

    /// <summary>
    /// Without an .old there is nothing to roll back, and the program stays.
    /// </summary>
    [Fact]
    public void RefusesARollbackWithoutOld()
    {
        Assert.Throws<UpdateRefusedException>(() => ExeSwap.RollBack(_exe));
        Assert.Equal("old", File.ReadAllText(_exe));
    }

    /// <summary>
    /// The .old is deleted once the new program runs, and a missing one counts as deleted.
    /// </summary>
    [Fact]
    public void DeletesTheOld()
    {
        ExeSwap.Install(_exe);

        Assert.True(ExeSwap.TryDeleteOld(_exe, 3, TimeSpan.Zero));
        Assert.False(File.Exists(ExeSwap.OldPathOf(_exe)));
        Assert.True(ExeSwap.TryDeleteOld(_exe, 1, TimeSpan.Zero));
        Assert.Equal("new", File.ReadAllText(_exe));
    }

    /// <summary>
    /// An .old another handle holds is reported as left after the tries.
    /// </summary>
    [Fact]
    public void ReportsAHeldOld()
    {
        Assert.SkipUnless(OperatingSystem.IsWindows(), "Only Windows refuses to delete a file another handle holds.");

        ExeSwap.Install(_exe);

        using (new FileStream(ExeSwap.OldPathOf(_exe), FileMode.Open, FileAccess.Read, FileShare.None))
        {
            Assert.False(ExeSwap.TryDeleteOld(_exe, 2, TimeSpan.FromMilliseconds(10)));
        }

        Assert.True(File.Exists(ExeSwap.OldPathOf(_exe)));
    }
}
