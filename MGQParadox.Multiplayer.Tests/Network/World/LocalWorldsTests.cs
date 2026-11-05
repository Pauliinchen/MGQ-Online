//----------------------------------------------------------------
//  LocalWorldsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the checks that replayed recorded cases
//      Paulinchen  2026-10-28: Expected a world described anew in its world.ini at once
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Tests.Network.World;

/// <summary>
/// Covers the worlds on this PC: a folder made and found, a world described and written, its latest
/// save and its deletion.
/// </summary>
public sealed class LocalWorldsTests : IDisposable
{
    /// <summary>
    /// A world code whose folder the tests make.
    /// </summary>
    private const string Code = "mgqmp2;abcdefghjkmnpqrs;r1;8";

    /// <summary>
    /// The folder of the worlds under test.
    /// </summary>
    private readonly TempFolder _folder = new();

    /// <summary>
    /// The time the worlds are told, in seconds since 1970.
    /// </summary>
    private long _now = 1_000;

    /// <summary>
    /// The worlds under test.
    /// </summary>
    private readonly LocalWorlds _worlds;

    /// <summary>
    /// Creates the worlds over an empty folder.
    /// </summary>
    public LocalWorldsTests() => _worlds = new LocalWorlds(_folder.Path, "Worlds", () => _now);

    /// <summary>
    /// Gets the folder's id of <see cref="Code"/>.
    /// </summary>
    private static string Id => WorldCode.IdOf(WorldCode.Parse(Code)!.Token);

    /// <summary>
    /// Asserts that a world's folder is made once, found again with what it holds, and listed.
    /// </summary>
    [Fact]
    public void Found_MakesTheFolderOnceAndFindsItAgain()
    {
        LocalWorld made = _worlds.Found(Code, About("First", "d1"))!;
        _now = 2_000;
        LocalWorld found = _worlds.Found(Code, About("Second", "d1"))!;

        Assert.Equal(Id, made.Id);
        Assert.Equal(1_000, found.Created);
        Assert.Equal("Second", found.Name);
        Assert.Equal(["Second"], _worlds.All().Select(world => world.Name));
        Assert.Null(_worlds.Found("no code", About("x", "d1")));
    }

    /// <summary>
    /// Asserts that what the directory told stays when the world is found again without it, and that
    /// the list's word replaces it on entry.
    /// </summary>
    [Fact]
    public void Found_KeepsWhatTheDirectoryToldUntilItTellsOtherwise()
    {
        _worlds.Found(Code, new LocalWorldAbout("Raid Night", "r1", null, WorldType.Raid, "story", -1, "1 0 3 4", true));
        LocalWorld again = _worlds.Found(Code, About("Raid Night", "r1"))!;
        Assert.Equal((WorldType.Raid, "story", (int?)-1, "1 0 3 4", true), (again.Type, again.Share, again.Difficulty, again.Squad, again.RaidBosses));

        _worlds.Describe(Id, About("Raid Night", "r1") with { Difficulty = 3, Squad = "0 7 1 2", RaidBosses = false });
        _worlds.Update(Id, world => world);
        string written = File.ReadAllText(Path.Combine(_folder.Path, Id, LocalWorld.FileName));
        Assert.Equal((3, "0 7 1 2", false), (_worlds.Find(Id)!.Difficulty, _worlds.Find(Id)!.Squad, written.Contains("raid_bosses", StringComparison.Ordinal)));
    }

    /// <summary>
    /// Asserts that a world.ini that exists but cannot be read is left as it is.
    /// </summary>
    [Fact]
    public void Found_LeavesAnUnreadableWorldIniAlone()
    {
        string folder = Path.Combine(_folder.Path, Id);
        Directory.CreateDirectory(folder);
        File.WriteAllText(Path.Combine(folder, LocalWorld.FileName), "name=Kept\n");
        using (new FileStream(Path.Combine(folder, LocalWorld.FileName), FileMode.Open, FileAccess.ReadWrite, FileShare.None))
        {
            Assert.Null(_worlds.Found(Code, About("Other", "d1")));
        }

        Assert.Equal("name=Kept\n", File.ReadAllText(Path.Combine(folder, LocalWorld.FileName)));
    }

    /// <summary>
    /// Asserts that a description is written into world.ini at once, seats changing the code, and
    /// that a world not on this PC or one whose world.ini cannot be written describes as nothing.
    /// </summary>
    [Fact]
    public void Describe_WritesWorldIniAtOnce()
    {
        _worlds.Found(Code, About("First", "d1"));
        LocalWorld described = _worlds.Describe(Id, About("Renamed", "d1") with { Seats = 12 })!;

        Assert.Equal(("Renamed", 12, "mgqmp2;abcdefghjkmnpqrs;r1;12"), (described.Name, described.Seats, described.Code));
        string written = File.ReadAllText(Path.Combine(_folder.Path, Id, LocalWorld.FileName));
        Assert.Contains("name=Renamed", written, StringComparison.Ordinal);
        Assert.Contains("code=mgqmp2;abcdefghjkmnpqrs;r1;12", written, StringComparison.Ordinal);
        Assert.Equal("Renamed", new LocalWorlds(_folder.Path, "Worlds", () => _now).Find(Id)!.Name);

        Assert.Null(_worlds.Describe("0123456789ab", About("Nowhere", "d2")));
        using (new FileStream(Path.Combine(_folder.Path, Id, LocalWorld.FileName), FileMode.Open, FileAccess.ReadWrite, FileShare.None))
        {
            Assert.Null(_worlds.Describe(Id, About("Locked", "d1")));
        }

        Assert.Equal("Renamed", _worlds.Find(Id)!.Name);
    }

    /// <summary>
    /// Asserts that the newest save is found by its file's time and the folder goes with its saves.
    /// </summary>
    [Fact]
    public void LatestSaveAndDelete_LookAtTheFiles()
    {
        _worlds.Found(Code, About("First", "d1"));
        string saves = Path.Combine(_folder.Path, Id, LocalWorlds.SaveFolder);
        Directory.CreateDirectory(saves);
        File.WriteAllText(Path.Combine(saves, "Save01.rvdata2"), "");
        File.WriteAllText(Path.Combine(saves, "AutoSave02.rvdata2"), "");
        File.SetLastWriteTimeUtc(Path.Combine(saves, "Save01.rvdata2"), new DateTime(2026, 1, 2, 0, 0, 0, DateTimeKind.Utc));
        File.SetLastWriteTimeUtc(Path.Combine(saves, "AutoSave02.rvdata2"), new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc));

        var latest = _worlds.LatestSave(Id)!.Value;
        Assert.Equal(0, latest.Save.Slot);
        Assert.Equal($"Worlds/{Id}/Save/Save01.rvdata2", latest.Path);

        Assert.True(_worlds.Delete(Id));
        Assert.False(Directory.Exists(Path.Combine(_folder.Path, Id)));
        Assert.Empty(_worlds.All());
        Assert.Null(_worlds.LatestSave(Id));
    }

    /// <inheritdoc />
    public void Dispose() => _folder.Dispose();

    /// <summary>
    /// Says what the directory says of a world.
    /// </summary>
    /// <param name="name">Its name.</param>
    /// <param name="directoryId">Its directory id.</param>
    /// <returns>What it says, keeping the rest.</returns>
    private static LocalWorldAbout About(string name, string directoryId) => new(name, directoryId, null, null, null, null, null, null);

    /// <summary>
    /// Reads a field that may be null.
    /// </summary>
    /// <typeparam name="T">Its kind.</typeparam>
    /// <param name="fields">The fields.</param>
    /// <param name="name">The field.</param>
    /// <param name="read">Reads a value.</param>
    /// <returns>The value, <see langword="null"/> for null.</returns>
    private static T? Optional<T>(JsonElement fields, string name, Func<JsonElement, T> read)
        where T : struct =>
        fields.GetProperty(name).ValueKind == JsonValueKind.Null ? null : read(fields.GetProperty(name));
}
