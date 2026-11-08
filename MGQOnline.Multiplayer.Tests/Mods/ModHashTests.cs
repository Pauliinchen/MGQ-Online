//----------------------------------------------------------------
//  ModHashTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-10-30: Dropped the release downloads, which the Mod Framework makes
//      Paulinchen  2026-10-06: Removed the check of CatalogMod.VersionOf
//                            - Covered zips of a release
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Security.Cryptography;
using System.Text;
using MGQOnline.Multiplayer.Mods;

namespace MGQOnline.Multiplayer.Tests.Mods;

/// <summary>
/// Covers how mod files are hashed and which release addresses a game downloads from.
/// </summary>
public sealed class ModHashTests
{
    /// <summary>
    /// Asserts that a script hashes the same with Windows and Unix line ends, as the relay hashes it.
    /// </summary>
    [Fact]
    public void Script_HashesWithoutCarriageReturns()
    {
        var unix = Encoding.UTF8.GetBytes("# cap\nputs 1\n");
        var windows = Encoding.UTF8.GetBytes("# cap\r\nputs 1\r\n");

        Assert.Equal(Convert.ToHexStringLower(SHA256.HashData(unix)), ModHash.Of("Level_Cap.rb", windows));
        Assert.Equal(ModHash.Of("Level_Cap.rb", unix), ModHash.Of("LEVEL_CAP.RB", windows));
    }

    /// <summary>
    /// Asserts that any other file hashes as it is.
    /// </summary>
    [Fact]
    public void OtherFile_HashesAsItIs()
    {
        var bytes = Encoding.UTF8.GetBytes("a\r\nb");
        Assert.Equal(Convert.ToHexStringLower(SHA256.HashData(bytes)), ModHash.Of("Heroes/cecil.luka", bytes));
    }
}
