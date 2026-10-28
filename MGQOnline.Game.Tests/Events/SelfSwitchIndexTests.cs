//----------------------------------------------------------------
//  SelfSwitchIndexTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Derived and walked over the events database
//                            - Checked the derive and the troops of the game against the walks of its lists
//                            - Classified the hand-made page
//                            - Derived over event sources
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;
using static MGQOnline.Game.Tests.Events.TinyGame;

namespace MGQOnline.Game.Tests.Events;

/// <summary>
/// Covers the derived index of the story mapping and the event command index over the events
/// database of a tiny game and of the game folder.
/// </summary>
public sealed class SelfSwitchIndexTests
{
    /// <summary>
    /// The mapping's keys of the cases: variable 1001 one-way, switch 60 shared, switch 61 personal.
    /// </summary>
    private static readonly StoryKeyRow[] Keys = [new("v1001", "one_way"), new("s60", "shared"), new("s61", "personal")];

    /// <summary>
    /// Asserts which events share their self switches: one that reads a shared key in a branch,
    /// sets one, or calls a common event that does, also through another; not one that touches only
    /// personal keys, or reaches a shared key only through the player's own transfer process.
    /// </summary>
    [Fact]
    public void Derive_SharesTheEventsThatReadOrWriteASharedKey()
    {
        TinyGame game = new TinyGame()
            .Event(1, C(111, 1, 1001, 0, 7, 0), At(123, 1, "A", 0), C(412))
            .Event(2, C(121, 55, 65, 0))
            .Event(3, C(117, 20))
            .Event(4, C(121, 61, 61, 0), C(123, "A", 0))
            .Event(5, C(117, 114))
            .Event(6, C(355, "$game_variables[1001] += 1"))
            .Common(20, C(117, 21))
            .Common(21, C(122, 1001, 1001, 1, 0, 1))
            .Common(114, C(111, 0, 60, 0));

        SelfSwitchIndex index = SelfSwitchIndex.Derive(EventDatabases.Of(game.Files()), Keys, []);

        Assert.Equal([(1, 1), (1, 2), (1, 3), (1, 6)], index.Events);
        Assert.Equal([20L, 21L], index.Commons);
    }

    /// <summary>
    /// Asserts that rows for whole maps, events and common events go against the rule, a map's
    /// before an event's, and that a row for one letter is left to whoever reads the rows.
    /// </summary>
    [Fact]
    public void Derive_AppliesTheRowsForWholeEvents()
    {
        TinyGame game = new TinyGame()
            .Event(1, C(121, 60, 60, 0))
            .Event(2, C(121, 60, 60, 0))
            .Event(3, C(101, "", 0, 0, 2))
            .Event(4, C(101, "", 0, 0, 2))
            .Common(20, C(121, 60, 60, 0));
        StoryEventRow[] rows = [new("ss1.*.*", "personal"), new("ss1.2.*", "shared"), new("ss1.4.A", "shared"), new("ce20.*", "personal"), new("ce30.*", "shared")];

        SelfSwitchIndex index = SelfSwitchIndex.Derive(EventDatabases.Of(game.Files()), Keys, rows);

        Assert.Equal([(1, 2)], index.Events);
        Assert.Equal([30L], index.Commons);
    }

    /// <summary>
    /// Asserts over the game folder that the index derived from the events database's rows shares
    /// the events and common events the walk of the game's lists shares, for the relay's seed rows.
    /// </summary>
    [Fact]
    public void Derive_OverTheDatabaseOfTheGame_SharesWhatTheWalkOfItsListsShares()
    {
        EventStore store = GameFolder.StoreOrSkip();
        StoryKeyRow[] keys = [.. SeedRows("keys.json").Select(row => new StoryKeyRow(row.GetProperty("key").GetString()!, row.GetProperty("kind").GetString()!))];
        StoryEventRow[] events = [.. SeedRows("events.json").Select(row => new StoryEventRow(row.GetProperty("key").GetString()!, row.GetProperty("share").GetString()!))];

        SelfSwitchIndex walked = SelfSwitchIndex.Derive(new GameDataSource(GameFolder.DataOrSkip()), keys, events);
        SelfSwitchIndex derived = SelfSwitchIndex.Derive(store, keys, events);

        Assert.True(walked.Events.Count > 100);
        Assert.Equal(walked.Events, derived.Events);
        Assert.Equal(walked.Commons, derived.Commons);
    }

    /// <summary>
    /// Asserts that the command index finds the troops a page fights through the common events it
    /// calls, in the order met, without the common events that turn a given switch on; for a page
    /// handed over and for one the database holds.
    /// </summary>
    [Fact]
    public void TroopsOf_FollowsTheCommonEventsInOrder()
    {
        EventStoreSource source = EventDatabases.SourceOf(new TinyGame()
            .Event(1, C(301, 0, 5, 0, 0), C(117, 20), C(117, 22), C(301, 0, 5, 0, 0))
            .Common(20, C(301, 0, 7, 0, 0), C(117, 21), C(117, 20))
            .Common(21, C(301, 0, 8, 0, 0))
            .Common(22, C(121, 900, 900, 0), C(301, 0, 9, 0, 0)));
        var index = new EventCommandIndex(source);
        EventCommand[] page = CommandClassifier.Classify([Command(301, 0, 5), Command(117, 20), Command(117, 22), Command(301, 0, 5)]);

        Assert.Equal([5L, 7L, 8L, 9L], index.TroopsOf(page));
        Assert.Equal([5L, 7L, 8L], index.TroopsOf(page, skipTurningOn: 900));
        Assert.Equal([5L, 7L, 8L, 9L], index.TroopsOf(source.PageKeys(1, 1, 0)!));
    }

    /// <summary>
    /// Asserts over the game folder that the command index walking the events database's rows meets
    /// the troops of every page and common event in the order the walk of the game's lists meets
    /// them, the Colosseum's common events left out or not.
    /// </summary>
    [Fact]
    public void TroopsOf_OverTheDatabaseOfTheGame_MeetsTheTroopsAsTheWalkOfItsLists()
    {
        GameData data = GameFolder.DataOrSkip();
        var rows = new EventStoreSource(GameFolder.StoreOrSkip());
        var byRows = new EventCommandIndex(rows);
        var byLists = new EventCommandIndex(new GameDataSource(data));
        var differing = new List<string>();
        int fighting = 0;
        void Compare(string site, IReadOnlyList<EventCommand> list, ListKeys? keys)
        {
            foreach (long? skip in new long?[] { null, RaidRules.ArenaSwitches[0] })
            {
                IReadOnlyList<long> walked = byLists.TroopsOf(list, skip);
                IReadOnlyList<long> found = keys is null ? [] : byRows.TroopsOf(keys, skip);
                fighting += walked.Count > 0 ? 1 : 0;
                if (!walked.SequenceEqual(found))
                {
                    differing.Add($"{site} skipping {skip}: [{string.Join(",", found)}], the list walk [{string.Join(",", walked)}]");
                }
            }
        }

        foreach (long id in Enumerable.Range(1, data.CommonEvents.Count - 1).Where(id => data.CommonEvents[id] is not null))
        {
            Compare($"ce:{id}", data.CommonEvent(id)!.List, rows.CommonKeys(id));
        }

        foreach (MapInfo map in data.Maps)
        {
            foreach ((int eventId, MapEvent mapEvent) in data.ReadMap(map.Id)?.Events ?? new Dictionary<int, MapEvent>())
            {
                for (int page = 0; page < mapEvent.Pages.Count; page++)
                {
                    Compare($"map:{map.Id}:{eventId}:{page + 1}", mapEvent.Pages[page].List, rows.PageKeys(map.Id, eventId, page));
                }
            }
        }

        Assert.True(fighting > 1000);
        Assert.Empty(differing);
    }

    /// <summary>
    /// Asserts that the command index finds what a page sets through the common events it calls.
    /// </summary>
    [Fact]
    public void WritesOf_FollowsTheCommonEvents()
    {
        var index = new EventCommandIndex(EventDatabases.SourceOf(new TinyGame().Common(20, C(122, 1075, 1075, 0, 0, 3), C(123, "B", 0))));
        EventCommand[] page = CommandClassifier.Classify([Command(121, 61, 62, 0), Command(117, 20), Command(123, "A", 1)]);

        (IReadOnlyList<KeyRange> keys, IReadOnlyList<string> selfSwitches) = index.WritesOf(page);

        Assert.Equal([new KeyRange(false, 61, 62), new KeyRange(true, 1075, 1075)], keys);
        Assert.Equal(["A", "B"], selfSwitches.Order());
    }

    /// <summary>
    /// Reads the rows a table of the relay's seed adds.
    /// </summary>
    /// <param name="file">The table's file, such as "keys.json".</param>
    /// <returns>The rows.</returns>
    private static IEnumerable<JsonElement> SeedRows(string file) =>
        Fixtures.Read("seed", file).EnumerateArray().Where(entry => entry.GetProperty("op").GetString() == "add").Select(entry => entry.GetProperty("row"));

    /// <summary>
    /// Writes a command of whole number and text parameters.
    /// </summary>
    /// <param name="code">The code.</param>
    /// <param name="parameters">Its parameters.</param>
    /// <returns>The command, as read.</returns>
    private static RawCommand Command(int code, params object[] parameters) =>
        new(code, 0, new MGQOnline.Bridge.Ruby.RubyArray(parameters.Select(value => value is string text ? (MGQOnline.Bridge.Ruby.RubyValue)text : (int)value)));
}
