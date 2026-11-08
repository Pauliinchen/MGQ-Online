//----------------------------------------------------------------
//  ModFolderTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-10-30: Checked the paths in one test
//      Paulinchen  2026-10-15: Checked the name of a day's log
//      Paulinchen  2026-10-07: Checked the name of a session's log
//      Paulinchen  2026-10-06: Checked that the DLL's log lands in the Logs folder
//      Paulinchen  2026-10-01: Created
//
//----------------------------------------------------------------

using System.IO;

namespace MGQOnline.Multiplayer.Tests;

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
    /// Asserts that a relative path starts at the game's folder, two folders above the mod folder, the
    /// DLL's log in its Logs folder, which every mod writes its logs to, and that a full path stays as it is.
    /// </summary>
    [Fact]
    public void GamePathOf_StartsARelativePathAtTheGameFolder()
    {
        var full = Path.Combine(Path.GetTempPath(), "Save01.rvdata2");

        Assert.Equal(@"C:\Games\MGQ\Save\Save01.rvdata2", ModFolder.GamePathOf("Save/Save01.rvdata2", ModFolderPath));
        Assert.Equal(@"C:\Games\MGQ\Patch\Multiplayer\Worlds\ab12", ModFolder.GamePathOf("Patch/Multiplayer/Worlds/ab12", ModFolderPath));
        Assert.Equal(@"C:\Games\MGQ\Logs\Multiplayer 2026-10-07.log", ModFolder.GamePathOf(Log.FileNameOf(new System.DateTime(2026, 10, 7, 18, 30, 5)), ModFolderPath));
        Assert.Equal(full, ModFolder.GamePathOf(full, ModFolderPath));
    }
}
