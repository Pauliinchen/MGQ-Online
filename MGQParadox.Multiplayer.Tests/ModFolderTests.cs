//----------------------------------------------------------------
//  ModFolderTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-06: Checked that the DLL's log lands in the game folder's Logs folder
//      Paulinchen  2026-10-01: Created
//
//----------------------------------------------------------------

using System.IO;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Covers the paths the game script names relative to the game's folder.
/// </summary>
public sealed class ModFolderTests
{
    /// <summary>
    /// The mod folder of a game installed in C:\Games\MGQ.
    /// </summary>
    private const string ModFolderPath = @"C:\Games\MGQ\Patch\Multiplayer";

    /// <summary>
    /// Asserts that a relative path starts at the game's folder, two folders above the mod folder.
    /// </summary>
    [Fact]
    public void GamePathOf_Relative_StartsAtTheGameFolder()
    {
        Assert.Equal(@"C:\Games\MGQ\Save\Save01.rvdata2", ModFolder.GamePathOf("Save/Save01.rvdata2", ModFolderPath));
        Assert.Equal(@"C:\Games\MGQ\Patch\Multiplayer\Worlds\ab12", ModFolder.GamePathOf("Patch/Multiplayer/Worlds/ab12", ModFolderPath));
    }

    /// <summary>
    /// Asserts that the DLL's log lands in the game folder's Logs folder, which every mod writes its logs to.
    /// </summary>
    [Fact]
    public void GamePathOf_Log_IsInTheLogsFolder()
    {
        Assert.Equal(@"C:\Games\MGQ\Logs\Multiplayer.log", ModFolder.GamePathOf(@"Logs\Multiplayer.log", ModFolderPath));
    }

    /// <summary>
    /// Asserts that a full path stays as it is.
    /// </summary>
    [Fact]
    public void GamePathOf_Full_StaysAsItIs()
    {
        var path = Path.Combine(Path.GetTempPath(), "Save01.rvdata2");

        Assert.Equal(path, ModFolder.GamePathOf(path, ModFolderPath));
    }
}
