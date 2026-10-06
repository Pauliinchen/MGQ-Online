//----------------------------------------------------------------
//  ModHashTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-06: Covered zips of a release
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Security.Cryptography;
using System.Text;
using MGQParadox.Multiplayer.Mods;

namespace MGQParadox.Multiplayer.Tests.Mods;

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

    /// <summary>
    /// Asserts that only release files of the admins' GitHub, scripts and zips, are downloaded, sent on only to GitHub's file hosts.
    /// </summary>
    [Fact]
    public void ReleaseDownload_TakesOnlyTheAdminsReleaseFiles()
    {
        Assert.True(ReleaseDownload.IsReleaseFile("https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/releases/download/v1.3.5/Level_Cap.rb"));
        Assert.False(ReleaseDownload.IsReleaseFile("https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/releases/latest/download/Level_Cap.rb"));
        Assert.False(ReleaseDownload.IsReleaseFile("https://github.com/Someone/Repo/releases/download/v1/Mod.rb"));
        Assert.False(ReleaseDownload.IsReleaseFile("http://github.com/Pauliinchen/Repo/releases/download/v1/Mod.rb"));
        Assert.False(ReleaseDownload.IsReleaseFile("https://github.com/Pauliinchen/Repo/releases/download/v1/Mod.exe"));
        Assert.True(ReleaseDownload.IsReleaseFile("https://github.com/Pauliinchen/MGQ-Paradox-Mod-Collection/releases/download/v1.4.0/Luka_Replacer.zip"));

        Assert.True(ReleaseDownload.IsFileHost(new Uri("https://release-assets.githubusercontent.com/x")));
        Assert.True(ReleaseDownload.IsFileHost(new Uri("https://objects.githubusercontent.com/x")));
        Assert.False(ReleaseDownload.IsFileHost(new Uri("http://objects.githubusercontent.com/x")));
        Assert.False(ReleaseDownload.IsFileHost(new Uri("https://example.com/x")));
        Assert.Throws<InvalidOperationException>(() => ReleaseDownload.Get("https://example.com/Mod.rb"));
    }

    /// <summary>
    /// Asserts that a catalog mod names the version a copy's hashes belong to.
    /// </summary>
    [Fact]
    public void CatalogMod_NamesTheVersionOfACopy()
    {
        var mod = new CatalogMod("levelcap", "Level Cap", "link", "1.4.0", Files("b"), [new ModVersion("1.4.0", Files("b")), new ModVersion("1.3.5", Files("a"))], string.Empty);

        Assert.Equal("1.3.5", mod.VersionOf(Files("a")));
        Assert.Equal("1.4.0", mod.VersionOf(Files("b")));
        Assert.Null(mod.VersionOf(Files("c")));
    }

    /// <summary>
    /// Makes the files of a single script with a given hash.
    /// </summary>
    /// <param name="hash">The hash.</param>
    /// <returns>The files.</returns>
    private static System.Collections.Generic.Dictionary<string, string> Files(string hash) => new() { ["Level_Cap.rb"] = hash };
}
