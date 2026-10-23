//----------------------------------------------------------------
//  WorldListsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Tests.Network.World;

/// <summary>
/// Covers the player's lists of worlds while a file cannot be read: the files of earlier versions
/// moved into Player.ini only once every file reads, and a favourite left as it was while Player.ini
/// cannot be read.
/// </summary>
public sealed class WorldListsTests : IDisposable
{
    /// <summary>
    /// The mod folder under test.
    /// </summary>
    private readonly TempFolder _mod = new();

    /// <summary>
    /// The bridge's frame the lists are told.
    /// </summary>
    private long _frame;

    /// <summary>
    /// Asserts that nothing moves while an old file cannot be read, nor again within a second, and
    /// that the next try after it moves both files and deletes them, Player.ini's own setting winning.
    /// </summary>
    [Fact]
    public void Merge_WaitsForEveryOldFile()
    {
        File.WriteAllText(Path.Combine(_mod.Path, PlayerIni.FileName), "favourite.w1=kept\n");
        File.WriteAllText(Path.Combine(_mod.Path, "Favourites.ini"), "w1=1\nw2=1\n");
        File.WriteAllText(Path.Combine(_mod.Path, "Added.ini"), "a1=1\n");
        WorldLists lists = new(new PlayerIni(Path.Combine(_mod.Path, PlayerIni.FileName)), _mod.Path, () => _frame);

        using (new FileStream(Path.Combine(_mod.Path, "Added.ini"), FileMode.Open, FileAccess.Read, FileShare.None))
        {
            Assert.Equal(["w1"], lists.Favourites());
        }

        _frame = WorldLists.RetryFrames - 1;
        Assert.Empty(lists.Added());
        _frame = WorldLists.RetryFrames;
        Assert.Equal(["a1"], lists.Added());
        Assert.Equal(["w1", "w2"], lists.Favourites());
        Assert.Contains("favourite.w1=kept", File.ReadAllText(Path.Combine(_mod.Path, PlayerIni.FileName)), StringComparison.Ordinal);
        Assert.False(File.Exists(Path.Combine(_mod.Path, "Favourites.ini")));
    }

    /// <summary>
    /// Asserts that a world stays as it was while Player.ini cannot be read.
    /// </summary>
    [Fact]
    public void Favour_LeavesAWorldWhilePlayerIniCannotBeRead()
    {
        string path = Path.Combine(_mod.Path, PlayerIni.FileName);
        File.WriteAllText(path, "name=Me\n");
        WorldLists lists = new(new PlayerIni(path), _mod.Path, () => _frame);

        using (new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.None))
        {
            Assert.Null(lists.Favour("w1", null));
        }

        Assert.True(lists.Favour("w1", null));
        Assert.False(lists.Favour("w1", null));
    }

    /// <inheritdoc />
    public void Dispose() => _mod.Dispose();
}
