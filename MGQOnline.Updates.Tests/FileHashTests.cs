//----------------------------------------------------------------
//  FileHashTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Security.Cryptography;
using System.Threading.Tasks;
using MGQOnline.Updates.Tests.Support;

namespace MGQOnline.Updates.Tests;

/// <summary>
/// Tests hashing files and checking a staged download.
/// </summary>
public sealed class FileHashTests
{
    /// <summary>
    /// The bytes of the test download.
    /// </summary>
    private static readonly byte[] Download = RandomNumberGenerator.GetBytes(200_000);

    /// <summary>
    /// The download as the manifest lists it.
    /// </summary>
    private static readonly ManifestFile Expected =
        new("win-x64", "RaidDesigner-1.4.0-win-x64.exe", Download.Length, Convert.ToHexStringLower(SHA256.HashData(Download)));

    /// <summary>
    /// A file's SHA-256 is lowercase hex.
    /// </summary>
    [Fact]
    public void HashesAFile()
    {
        using var folder = new ScratchFolder();
        var path = folder.Write("abc.txt", "abc");

        Assert.Equal("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", FileHash.Sha256Of(path));
    }

    /// <summary>
    /// The running program's SHA-256 is readable.
    /// </summary>
    [Fact]
    public void HashesTheRunningProgram()
    {
        Assert.Equal(FileHash.Sha256Of(Environment.ProcessPath!), FileHash.Sha256OfRunningProgram());
    }

    /// <summary>
    /// A download with the listed length and SHA-256 is kept, replacing an earlier one.
    /// </summary>
    /// <returns>The test's task.</returns>
    [Fact]
    public async Task KeepsAMatchingDownload()
    {
        using var folder = new ScratchFolder();
        var path = folder.Write("RaidDesigner.exe.new", "an earlier, longer download that is replaced");

        await FileHash.SaveCheckedAsync(new MemoryStream(Download), path, Expected, TestContext.Current.CancellationToken);

        Assert.Equal(Download, File.ReadAllBytes(path));
    }

    /// <summary>
    /// A download that is too short, too long or has another SHA-256 is refused and deleted.
    /// </summary>
    /// <param name="change">What differs from the listed file.</param>
    /// <returns>The test's task.</returns>
    [Theory]
    [InlineData("short")]
    [InlineData("long")]
    [InlineData("sha")]
    public async Task RefusesAndDeletesAWrongDownload(string change)
    {
        using var folder = new ScratchFolder();
        var path = folder.File("RaidDesigner.exe.new");
        var bytes = (byte[])Download.Clone();

        switch (change)
        {
            case "short": bytes = bytes[..^1]; break;
            case "long": bytes = [.. bytes, 0]; break;
            case "sha": bytes[100] ^= 1; break;
        }

        await Assert.ThrowsAsync<UpdateRefusedException>(
            () => FileHash.SaveCheckedAsync(new MemoryStream(bytes), path, Expected, TestContext.Current.CancellationToken));
        Assert.False(File.Exists(path));
    }
}
