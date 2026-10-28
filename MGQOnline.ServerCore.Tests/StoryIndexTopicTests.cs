//----------------------------------------------------------------
//  StoryIndexTopicTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Derived the index from an events database under a game folder
//                            - Covered the refusals of the database and its fingerprint
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Data.Events;
using MGQOnline.Data.Generator.Build;
using MGQOnline.Game.Events.Data;
using MGQOnline.Game.Worlds;

namespace MGQOnline.ServerCore.Tests;

/// <summary>
/// Covers the topic that derives the story mapping's index for the relay from the events database
/// of the battle server's game folder: over a tiny database written under a folder, and over the
/// database of the untranslated copy EVENTS_SOURCE_DIR names with the names and the fingerprint of
/// the game folder BATTLE_GAME_DIR names, skipped without them.
/// </summary>
public sealed class StoryIndexTopicTests : IDisposable
{
    /// <summary>
    /// The tiny database's fingerprint, one checksum per part.
    /// </summary>
    private const string Fingerprint = "1:00000000.00000001.00000002.00000003.00000004.00000005.00000006.00000007.00000008.00000009.0000000a";

    /// <summary>
    /// The tiny game's map.
    /// </summary>
    private const int Map = 1;

    /// <summary>
    /// The tiny game's common event, which reads variable 1001.
    /// </summary>
    private const int Common = 40;

    /// <summary>
    /// The game folder the tiny database lies in.
    /// </summary>
    private readonly string _folder = Directory.CreateTempSubdirectory("story-index-").FullName;

    /// <summary>
    /// The core's log lines.
    /// </summary>
    private readonly LogLines _log = new();

    /// <summary>
    /// The events made, whose databases are closed at the end.
    /// </summary>
    private readonly List<ServerEvents> _made = [];

    /// <summary>
    /// Writes the tiny database under the game folder.
    /// </summary>
    public StoryIndexTopicTests()
    {
        EventDatabaseWriter.Write(TinyRows(), Path.Combine(_folder, EventSchema.GamePath));
    }

    /// <summary>
    /// Asserts that the index shares the map events that read a shared key and those that call a
    /// common event that does, that a map named personal as a whole keeps none, and that the time
    /// it took is logged.
    /// </summary>
    [Fact]
    public void Derive_SharesTheEventsThatReadOrCallASharedKey()
    {
        ServerEvents events = EventsOf(Fingerprint);

        RubyHash shared = StoryIndexTopic.Derive(events.Store, events.Gate(), Request(), _log);
        RubyHash personal = StoryIndexTopic.Derive(events.Store, events.Gate(), Request($"ss{Map}.*.*"), _log);

        Assert.Equal(new RubyArray { new RubyArray { (long)Map, 2L }, new RubyArray { (long)Map, 3L } }, shared["events"]);
        Assert.Equal(new RubyArray { (long)Common }, shared["commons"]);
        Assert.Empty(personal["events"].AsArray());
        Assert.Contains(_log.Written, line => line.StartsWith("story.index: derived 2 map events and 1 common events", StringComparison.Ordinal) && line.EndsWith(" ms", StringComparison.Ordinal));
    }

    /// <summary>
    /// Asserts that the index is refused while the database differs from the game data in the maps
    /// or the common events, which it reads, and derived while it differs only in another part.
    /// </summary>
    [Fact]
    public void Derive_RefusesWhileTheEventPartsDiffer()
    {
        ServerEvents otherMaps = EventsOf(Fingerprint[..^8] + "ffffffff");
        ServerEvents otherActors = EventsOf("1:ffffffff" + Fingerprint[10..]);

        BridgeRequestException refused = Assert.Throws<BridgeRequestException>(() => StoryIndexTopic.Derive(otherMaps.Store, otherMaps.Gate(), Request(), _log));

        Assert.Contains("the game data's maps differ from the events database's", refused.Message, StringComparison.Ordinal);
        Assert.Equal(2, StoryIndexTopic.Derive(otherActors.Store, otherActors.Gate(), Request(), _log)["events"].AsArray().Count);
        Assert.Contains("events database: it differs from the game data in actors", _log.Written);
    }

    /// <summary>
    /// Asserts that the index is refused, saying why, without the events database or before the
    /// scripts handed over the game data's fingerprint.
    /// </summary>
    [Fact]
    public void Derive_RefusesWithoutTheDatabaseOrTheGameData()
    {
        ServerEvents missing = Made(new ServerEvents(() => Path.Combine(_folder, "elsewhere"), _log) { GameFingerprint = Fingerprint });
        ServerEvents unknown = EventsOf(null);

        BridgeRequestException noFile = Assert.Throws<BridgeRequestException>(() => StoryIndexTopic.Derive(missing.Store, missing.Gate(), Request(), _log));
        BridgeRequestException noData = Assert.Throws<BridgeRequestException>(() => StoryIndexTopic.Derive(unknown.Store, unknown.Gate(), Request(), _log));

        Assert.Contains("no events database at", noFile.Message, StringComparison.Ordinal);
        Assert.Contains("the game data's fingerprint is unknown", noData.Message, StringComparison.Ordinal);
    }

    /// <summary>
    /// Asserts that a row that names no key is refused as a bad request.
    /// </summary>
    [Fact]
    public void Derive_RefusesARowWithoutItsKey()
    {
        ServerEvents events = EventsOf(Fingerprint);
        var request = new RubyHash { { "keys", new RubyArray { new RubyHash { { "kind", "shared" } } } } };

        BridgeRequestException refused = Assert.Throws<BridgeRequestException>(() => StoryIndexTopic.Derive(events.Store, events.Gate(), request, _log));

        Assert.Equal("each row names its key", refused.Message);
    }

    /// <summary>
    /// Asserts that the database of the untranslated copy passes the gate of the installed game,
    /// translated or not, and that the story's progress shares the self switches of many events
    /// while a map named personal as a whole keeps none; and that the installed game's names come along.
    /// </summary>
    [Fact]
    public void Answer_OverTheUntranslatedDatabase_SharesTheEventsThatReadASharedKey()
    {
        string source = FolderOrSkip("EVENTS_SOURCE_DIR");
        string game = FolderOrSkip("BATTLE_GAME_DIR");
        string ini = Path.Combine(game, "Patch/Multiplayer/GameData.ini");
        if (!File.Exists(ini))
        {
            Assert.Skip($"{ini} is not there; start the game with the mod once");
        }

        using EventStore store = EventStore.Over(EventDatabaseWriter.Build(EventBuilder.Build(new GameFolderFiles(source), new BuildOptions())));
        string fingerprint = File.ReadLines(ini).Single(line => line.StartsWith("fingerprint=", StringComparison.Ordinal))["fingerprint=".Length..];
        int map = store.MapIds()[0];

        RubyHash answer = StoryIndexTopic.Derive(store, EventDataGate.Check(store, fingerprint), Request($"ss{map}.*.*"), _log);
        RubyHash names = StoryNamesTopic.Read(game);

        RubyArray events = answer["events"].AsArray();
        Assert.True(events.Count > 100);
        Assert.DoesNotContain(events, pair => pair.AsArray()[0].AsInt() == map);
        Assert.True(answer["commons"].AsArray().Count > 0);
        Assert.True(names["switches"].AsHash().Count > 0 && names["events"].AsHash().Count > 1000);
        Assert.Equal(GameData.OfFolder(game).ActorCount, names["companions"].AsInt());
    }

    /// <summary>
    /// Closes the databases and removes the game folder.
    /// </summary>
    public void Dispose()
    {
        _made.ForEach(events => events.Store.Dispose());
        Directory.Delete(_folder, true);
    }

    /// <summary>
    /// Makes the rows of the tiny game: map 1's event 2 reads variable 1001, its event 3 calls common
    /// event 40, which reads it too, and its event 4 reads switch 60 only.
    /// </summary>
    /// <returns>The rows.</returns>
    private static EventRows TinyRows()
    {
        var rows = new EventRows(new EventBuildInfo(1, "3.06", "untranslated", Fingerprint, string.Empty));
        string[] sums = Fingerprint[2..].Split('.');
        rows.FingerprintParts.AddRange(sums.Select((sum, index) => new FingerprintPart(index, GameDataCompare.Parts[index], sum, 1)));
        rows.Maps.Add(new MapRow(Map, 0, Map, 0, 1, true, false));
        rows.MapEvents.AddRange([new(Map, 2, 0, 0, 1), new(Map, 3, 0, 0, 1), new(Map, 4, 0, 0, 1)]);
        rows.Lists.AddRange(
        [
            new(0, ListKind.Page, Map, 2, 0, null, null, null, 3, 2, 0),
            new(1, ListKind.Page, Map, 3, 0, null, null, null, 2, 1, 0),
            new(2, ListKind.Page, Map, 4, 0, null, null, null, 3, 2, 0),
            new(3, ListKind.Common, null, null, null, Common, null, null, 3, 2, 0),
        ]);
        rows.CommonEvents.Add(new CommonEventRow(Common, 3, 0, 0, false, 0, false, false, false));
        rows.ListReads.AddRange([new(0, KeyKind.Variable, 1001, ReadSources.Branch), new(2, KeyKind.Switch, 60, ReadSources.Branch), new(3, KeyKind.Variable, 1001, ReadSources.Branch)]);
        rows.ListCalls.Add(new ListCallRow(1, 0, 0, Common));
        return rows;
    }

    /// <summary>
    /// Makes the rows of a request: the story's progress shared, switch 60 personal.
    /// </summary>
    /// <param name="personal">A row of <c>events</c> that names self switches personal, <see langword="null"/> for none.</param>
    /// <returns>The request.</returns>
    private static RubyHash Request(string? personal = null) => new()
    {
        { "keys", new RubyArray { new RubyHash { { "key", "v1001" }, { "kind", "one_way" } }, new RubyHash { { "key", "s60" }, { "kind", "personal" } } } },
        { "events", personal is null ? new RubyArray() : new RubyArray { new RubyHash { { "key", personal }, { "share", "personal" } } } },
    };

    /// <summary>
    /// Finds a game folder an environment setting names, or skips the test.
    /// </summary>
    /// <param name="setting">The setting.</param>
    /// <returns>The folder, which holds a Data folder or the game's archive.</returns>
    private static string FolderOrSkip(string setting)
    {
        string? folder = Environment.GetEnvironmentVariable(setting);
        if (folder is not { Length: > 0 } || !(Directory.Exists(Path.Combine(folder, "Data")) || File.Exists(Path.Combine(folder, GameFolderFiles.ArchiveName))))
        {
            Assert.Skip($"{setting} names no game folder");
        }

        return folder;
    }

    /// <summary>
    /// Makes the events of the tiny game folder with the game data's fingerprint handed over.
    /// </summary>
    /// <param name="fingerprint">The game data's fingerprint, <see langword="null"/> for none handed over.</param>
    /// <returns>The events.</returns>
    private ServerEvents EventsOf(string? fingerprint) => Made(new ServerEvents(() => _folder, _log) { GameFingerprint = fingerprint });

    /// <summary>
    /// Notes events made, whose database is closed at the end.
    /// </summary>
    /// <param name="events">The events.</param>
    /// <returns>The same events.</returns>
    private ServerEvents Made(ServerEvents events)
    {
        _made.Add(events);
        return events;
    }

    /// <summary>
    /// Keeps the lines the core logs.
    /// </summary>
    private sealed class LogLines : IBridgeLog
    {
        /// <summary>
        /// Gets the lines, oldest first.
        /// </summary>
        public List<string> Written { get; } = [];

        /// <inheritdoc />
        public void Write(string line) => Written.Add(line);
    }
}
