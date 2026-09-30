//----------------------------------------------------------------
//  StartingSaveTests.cs
//
//  Changelog:
//      Paulinchen  2026-09-30: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using MGQParadox.Multiplayer.Network.Pvp;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Tests.Network.World;

/// <summary>
/// Covers sealing a starting save for a world and opening it again.
/// </summary>
public sealed class StartingSaveTests
{
    /// <summary>
    /// Asserts that the world's token opens a sealed starting save into the same files, under their new names.
    /// </summary>
    [Fact]
    public void SealThenOpen_WritesTheSameFiles()
    {
        using var folder = new TempFolder();
        var save = folder.Write("Save05.rvdata2", 100_000);
        var token = JoinCode.NewToken();

        var box = StartingSave.Seal(token, [("Save01.rvdata2", save)]);
        var names = StartingSave.Open(token, box, Path.Combine(folder.Path, "out"));

        Assert.Equal(["Save01.rvdata2"], names);
        Assert.Equal(File.ReadAllBytes(save), File.ReadAllBytes(Path.Combine(folder.Path, "out", "Save01.rvdata2")));
    }

    /// <summary>
    /// Asserts that another world's token, or a changed byte, cannot open a starting save.
    /// </summary>
    [Fact]
    public void Open_WithOtherTokenOrChangedByte_Fails()
    {
        using var folder = new TempFolder();
        var token = JoinCode.NewToken();
        var box = StartingSave.Seal(token, [("Save01.rvdata2", folder.Write("Save01.rvdata2", 1_000))]);

        Assert.Throws<InvalidDataException>(() => StartingSave.Open(JoinCode.NewToken(), box, folder.Path));

        box[^1] ^= 1;
        Assert.Throws<InvalidDataException>(() => StartingSave.Open(token, box, folder.Path));
    }

    /// <summary>
    /// Asserts that a name which could reach outside the folder, or no file at all, is refused.
    /// </summary>
    [Fact]
    public void Seal_RefusesPathsAndEmptySaves()
    {
        using var folder = new TempFolder();
        var file = folder.Write("Save01.rvdata2", 10);
        var token = JoinCode.NewToken();

        Assert.Throws<ArgumentException>(() => StartingSave.Seal(token, [("../Save01.rvdata2", file)]));
        Assert.Throws<ArgumentException>(() => StartingSave.Seal(token, [("Save/Save01.rvdata2", file)]));
        Assert.Throws<ArgumentException>(() => StartingSave.Seal(token, [("..", file)]));
        Assert.Throws<ArgumentException>(() => StartingSave.Seal(token, []));
    }
}

/// <summary>
/// A folder of its own below the temporary folder, deleted with everything in it once disposed.
/// </summary>
internal sealed class TempFolder : IDisposable
{
    /// <summary>
    /// The folder's full path.
    /// </summary>
    public string Path { get; } = Directory.CreateTempSubdirectory("mgqmp-test-").FullName;

    /// <summary>
    /// Writes a file of pseudo-random bytes into the folder, the same bytes for the same size.
    /// </summary>
    /// <param name="name">The file's name.</param>
    /// <param name="size">Its size in bytes.</param>
    /// <returns>The file's full path.</returns>
    public string Write(string name, int size)
    {
        var bytes = new byte[size];
        new Random(size).NextBytes(bytes);
        var path = System.IO.Path.Combine(Path, name);
        File.WriteAllBytes(path, bytes);
        return path;
    }

    /// <summary>
    /// Deletes the folder.
    /// </summary>
    public void Dispose()
    {
        try
        {
            Directory.Delete(Path, recursive: true);
        }
        catch (IOException)
        {
            // A file still open elsewhere keeps the folder; the system's clean-up removes it later.
        }
    }
}
