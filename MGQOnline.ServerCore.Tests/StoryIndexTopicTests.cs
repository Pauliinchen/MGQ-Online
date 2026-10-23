//----------------------------------------------------------------
//  StoryIndexTopicTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.ServerCore.Tests;

/// <summary>
/// Covers the topic that derives the story mapping's index for the relay, over the game folder
/// BATTLE_GAME_DIR names; without one the checks of real data are skipped.
/// </summary>
public sealed class StoryIndexTopicTests
{
    /// <summary>
    /// Asserts that the story's progress shares the self switches of the events that read it, that a
    /// map named personal as a whole keeps none, and that the names come along.
    /// </summary>
    [Fact]
    public void Derive_SharesTheEventsThatReadASharedKey()
    {
        GameData data = DataOrSkip();
        int map = data.Maps[0].Id;
        var request = new RubyHash
        {
            { "keys", new RubyArray { new RubyHash { { "key", "v1001" }, { "kind", "one_way" } }, new RubyHash { { "key", "s60" }, { "kind", "personal" } } } },
            { "events", new RubyArray { new RubyHash { { "key", $"ss{map}.*.*" }, { "share", "personal" } } } },
        };

        RubyHash answer = StoryIndexTopic.Derive(data, request);

        RubyArray events = answer["events"].AsArray();
        RubyHash names = answer["names"].AsHash();
        Assert.True(events.Count > 100);
        Assert.DoesNotContain(events, pair => pair.AsArray()[0].AsInt() == map);
        Assert.True(answer["commons"].AsArray().Count > 0);
        Assert.True(names["switches"].AsHash().Count > 0 && names["events"].AsHash().Count > 1000);
        Assert.Equal(data.ActorCount, names["companions"].AsInt());
    }

    /// <summary>
    /// Asserts that a row that names no key is refused as a bad request.
    /// </summary>
    [Fact]
    public void Derive_RefusesARowWithoutItsKey()
    {
        var request = new RubyHash { { "keys", new RubyArray { new RubyHash { { "kind", "shared" } } } } };

        Assert.Throws<BridgeRequestException>(() => StoryIndexTopic.Derive(new GameData(new NoFiles()), request));
    }

    /// <summary>
    /// Reads the game folder BATTLE_GAME_DIR names, or skips the test.
    /// </summary>
    /// <returns>Its data.</returns>
    private static GameData DataOrSkip()
    {
        string? folder = Environment.GetEnvironmentVariable("BATTLE_GAME_DIR");
        if (folder is not { Length: > 0 } || !(Directory.Exists(Path.Combine(folder, "Data")) || File.Exists(Path.Combine(folder, GameFolderFiles.ArchiveName))))
        {
            Assert.Skip("BATTLE_GAME_DIR names no game folder");
        }

        return GameData.OfFolder(folder);
    }

    /// <summary>
    /// A game folder without files.
    /// </summary>
    private sealed class NoFiles : IGameDataFiles
    {
        /// <inheritdoc />
        public bool Exists(string path) => false;

        /// <inheritdoc />
        public byte[] Read(string path) => throw new FileNotFoundException(path);
    }
}
