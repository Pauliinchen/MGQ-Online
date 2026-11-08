//----------------------------------------------------------------
//  PatchScriptsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-11-05: Checked that the scripts sort whatever their case
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.IO;
using MGQOnline.Multiplayer.Mods;
using MGQOnline.Multiplayer.Tests.Network.World;

namespace MGQOnline.Multiplayer.Tests.Mods;

/// <summary>
/// Covers the scripts of the Patch folder and the mods an older release left parked.
/// </summary>
public sealed class PatchScriptsTests
{
    /// <summary>
    /// Asserts that every script of Patch and its folders is listed, sorted whatever its case, but
    /// this mod's own and names that start with a dot.
    /// </summary>
    [Fact]
    public void List_NamesThePlayersScripts()
    {
        using var game = new TempFolder();
        Write(game, "Patch/Patch.rb", "Patch/apple.rb", "Patch/Level_Cap.rb", "Patch/Invasions/waves.rb", "Patch/Invasions/readme.txt", "Patch/Multiplayer/Scripts/x.rb", "Patch/.git/hook.rb", "Patch/ünïcode Mod.rb");

        Assert.Equal(["Patch/apple.rb", "Patch/Invasions/waves.rb", "Patch/Level_Cap.rb", "Patch/Patch.rb", "Patch/ünïcode Mod.rb"], PatchScripts.List(game.Path));
        Assert.Empty(PatchScripts.List(Path.Combine(game.Path, "nowhere"))!);
    }

    /// <summary>
    /// Asserts that parked mods come back into Patch, the folder going once nothing is left, and that
    /// a mod whose place another file took stays parked.
    /// </summary>
    [Fact]
    public void PutBack_ReturnsTheParkedModsAnOlderReleaseLeft()
    {
        using var game = new TempFolder();
        Write(game, "Parked mods/Parked.txt", "Parked mods/Patch/Invasions.rb", "Parked mods/Patch/Invasions/waves.rb");

        Assert.Equal(2, ParkedLeftovers.PutBack(game.Path));
        Assert.True(File.Exists(Path.Combine(game.Path, "Patch", "Invasions", "waves.rb")));
        Assert.False(Directory.Exists(Path.Combine(game.Path, ParkedLeftovers.FolderName)));

        Write(game, "Parked mods/Patch/Invasions.rb", "Parked mods/Patch/Level_Cap.rb");
        Assert.Equal(1, ParkedLeftovers.PutBack(game.Path));
        Assert.True(File.Exists(Path.Combine(game.Path, "Parked mods", "Patch", "Invasions.rb")));
        Assert.Equal(0, ParkedLeftovers.PutBack(Path.Combine(game.Path, "Patch")));
    }

    /// <summary>
    /// Writes files into the game folder.
    /// </summary>
    /// <param name="game">The game folder.</param>
    /// <param name="paths">Each file's path from the game folder.</param>
    private static void Write(TempFolder game, params string[] paths)
    {
        foreach (string path in paths)
        {
            string file = Path.Combine(game.Path, path);
            Directory.CreateDirectory(Path.GetDirectoryName(file)!);
            File.WriteAllText(file, path);
        }
    }
}
