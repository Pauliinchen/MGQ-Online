//----------------------------------------------------------------
//  UpdaterTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

extern alias helper;

using System;
using System.IO;
using System.IO.Compression;
using helper::MGQOnline.Helper;

namespace MGQParadox.Multiplayer.Tests.Helper;

/// <summary>
/// Covers the helper's update without GitHub: which release it installs, the files it removes, the
/// zip it extracts, the arguments it takes and the mutex that tells the watchdog it runs.
/// </summary>
public sealed class UpdaterTests : IDisposable
{
    /// <summary>
    /// A folder of the test's own, which holds the game folder <see cref="_game"/>.
    /// </summary>
    private readonly string _root = Directory.CreateTempSubdirectory("mgqmp-update-").FullName;

    /// <summary>
    /// The game folder in <see cref="_root"/>.
    /// </summary>
    private readonly string _game;

    /// <summary>
    /// Creates the test's game folder.
    /// </summary>
    public UpdaterTests() => _game = Directory.CreateDirectory(Path.Combine(_root, "Game [EN]")).FullName;

    /// <summary>
    /// Asserts that the latest release never steps back from a newer install, a release named by
    /// its version does, and an install of unknown version always updates.
    /// </summary>
    [Fact]
    public void StepOf_OnlyANamedReleaseStepsBack()
    {
        var wanted = new Version(0, 6, 8, 0);

        Assert.Equal(UpdateStep.Installed, Updater.StepOf(new Version(0, 6, 8), wanted, named: false));
        Assert.Equal(UpdateStep.Installed, Updater.StepOf(new Version(0, 6, 9), wanted, named: false));
        Assert.Equal(UpdateStep.StepBack, Updater.StepOf(new Version(0, 6, 9), wanted, named: true));
        Assert.Equal(UpdateStep.Update, Updater.StepOf(new Version(0, 6, 7, 7), wanted, named: false));
        Assert.Equal(UpdateStep.Update, Updater.StepOf(null, wanted, named: false));
    }

    /// <summary>
    /// Asserts that only the files the new release dropped go, read-only ones too, and only in the
    /// folders a release ships to, whatever case the manifests use.
    /// </summary>
    [Fact]
    public void RemoveStaleFiles_RemovesOnlyWhatTheNewReleaseDropped()
    {
        WriteFile(@"Patch\Multiplayer\Scripts\gone.rbx");
        WriteFile(@"Patch\Multiplayer\Scripts\kept.rbx");
        WriteFile(@"Multiplayer\Multiplayer.dll");
        WriteFile("Game.exe");
        File.SetAttributes(Path.Combine(_game, @"Patch\Multiplayer\Scripts\gone.rbx"), FileAttributes.ReadOnly);
        File.WriteAllText(Path.Combine(_root, "outside.txt"), string.Empty);
        string[] old = [@"Patch\Multiplayer\Scripts\gone.rbx", "Patch/Multiplayer/Scripts/kept.rbx", @"Multiplayer\Multiplayer.dll", "Game.exe", @"Patch\..\..\outside.txt"];

        Assert.Equal(2, Updater.RemoveStaleFiles(_game, old, [@"patch\multiplayer\scripts\KEPT.rbx"]));

        Assert.False(File.Exists(Path.Combine(_game, @"Patch\Multiplayer\Scripts\gone.rbx")));
        Assert.False(File.Exists(Path.Combine(_game, @"Multiplayer\Multiplayer.dll")));
        Assert.True(File.Exists(Path.Combine(_game, @"Patch\Multiplayer\Scripts\kept.rbx")));
        Assert.True(File.Exists(Path.Combine(_game, "Game.exe")));
        Assert.True(File.Exists(Path.Combine(_root, "outside.txt")));
    }

    /// <summary>
    /// Asserts that a release's zip replaces the files it holds, in a folder whose name has brackets.
    /// </summary>
    [Fact]
    public void Extract_ReplacesTheFilesTheZipHolds()
    {
        WriteFile(@"Patch\Multiplayer\Update.bat", "old");

        Updater.Extract(Zip(("Patch/", null), ("Patch/Multiplayer/Update.bat", "new"), ("Patch/Multiplayer.rb", "# loader")), _game);

        Assert.Equal("new", File.ReadAllText(Path.Combine(_game, @"Patch\Multiplayer\Update.bat")));
        Assert.Equal("# loader", File.ReadAllText(Path.Combine(_game, @"Patch\Multiplayer.rb")));
    }

    /// <summary>
    /// Asserts that a zip with a file outside the game folder writes nothing at all.
    /// </summary>
    [Fact]
    public void Extract_AFileOutsideTheFolder_WritesNothing()
    {
        var zip = Zip(("Patch/Multiplayer.rb", "# loader"), ("../outside.txt", "evil"));

        Assert.Throws<InvalidDataException>(() => Updater.Extract(zip, _game));

        Assert.False(File.Exists(Path.Combine(_game, @"Patch\Multiplayer.rb")));
        Assert.False(File.Exists(Path.Combine(_root, "outside.txt")));
    }

    /// <summary>
    /// Asserts that each mode takes the options it needs and no others.
    /// </summary>
    [Fact]
    public void Arguments_TakeWhatEachModeNeeds()
    {
        var watch = HelperArguments.Parse(["watch", "--game", "12", "--mode", "rejoin", "--watch", "ab", "--folder", _game + "\\"], _root)!;
        Assert.Equal((HelperMode.Watch, 12, true, "ab", _game), (watch.Mode, watch.Game, watch.Rejoin, watch.Watch, watch.GameFolder));

        var update = HelperArguments.Parse(["update", "--version", "0.6.8"], _game)!;
        Assert.Equal((0, "0.6.8", _game), (update.Game, update.Version, update.GameFolder));

        Assert.Null(HelperArguments.Parse(["watch", "--game", "12", "--mode", "rejoin"], _root));
        Assert.Null(HelperArguments.Parse(["restart"], _root));
        Assert.Null(HelperArguments.Parse(["update", "--mode", "title"], _root));
        Assert.Null(HelperArguments.Parse(["update", "--game"], _root));
        Assert.Null(HelperArguments.Parse(["restart", "--game", "-5"], _root));
    }

    /// <summary>
    /// Asserts that the update's mutex is held for its game folder however the folder is spelled,
    /// by one update at a time, and gone once that one ends.
    /// </summary>
    [Fact]
    public void UpdateMutex_IsHeldWhileOneUpdateRuns()
    {
        using (var mutex = UpdateMutex.Take(_game))
        {
            Assert.NotNull(mutex);
            Assert.True(UpdateMutex.Held(_game.ToUpperInvariant() + "\\"));
            Assert.False(UpdateMutex.Held(_root));
            Assert.Null(UpdateMutex.Take(_game));
        }

        Assert.False(UpdateMutex.Held(_game));
    }

    /// <inheritdoc />
    public void Dispose()
    {
        foreach (var file in Directory.EnumerateFiles(_root, "*", SearchOption.AllDirectories))
        {
            File.SetAttributes(file, FileAttributes.Normal);
        }

        Directory.Delete(_root, true);
    }

    /// <summary>
    /// Builds a zip.
    /// </summary>
    /// <param name="entries">Each entry's path, and its text; <see langword="null"/> for a folder's entry.</param>
    /// <returns>The zip.</returns>
    private static byte[] Zip(params (string Path, string? Text)[] entries)
    {
        using var stream = new MemoryStream();

        using (var archive = new ZipArchive(stream, ZipArchiveMode.Create))
        {
            foreach (var (path, text) in entries)
            {
                var entry = archive.CreateEntry(path);

                if (text != null)
                {
                    using var writer = new StreamWriter(entry.Open());
                    writer.Write(text);
                }
            }
        }

        return stream.ToArray();
    }

    /// <summary>
    /// Writes a file into the test's game folder.
    /// </summary>
    /// <param name="relative">Its path relative to the game folder.</param>
    /// <param name="text">Its text.</param>
    private void WriteFile(string relative, string text = "")
    {
        var path = Path.Combine(_game, relative);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, text);
    }
}
