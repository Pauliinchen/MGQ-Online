//----------------------------------------------------------------
//  EventTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Checked that the battlefuck events are read once and stay while the common events differ
//      Paulinchen  2026-10-30: Kept the database fingerprint format in the differing game data
//      Paulinchen  2026-10-28: Checked the command index of a map's pages at once
//                            - Sorted over the events database of a tiny game, by length and shape, and checked its gate
//                            - Handed the topics the event source alone
//                            - Read the events through an event source
//      Paulinchen  2026-10-23: Checked that a failed read ahead is logged
//                            - Checked the event command index
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Data.Events;
using MGQOnline.Game.Tests.Events;
using MGQParadox.Multiplayer.Tests.Network.World;
using MGQParadox.Multiplayer.Topics;
using static MGQOnline.Game.Tests.Events.TinyGame;

namespace MGQParadox.Multiplayer.Tests.Topics;

/// <summary>
/// Covers the event sorter's topics as the scripts call them, over the events database of a tiny
/// game: the values a sort names it needs, a page found only while the scripts hold it as the
/// database does, the gate of the game data's fingerprint, the map's pages at once, and a read
/// ahead that fails.
/// </summary>
public sealed class EventTopicsTests
{
    /// <summary>
    /// The tiny game: on map 1 event 2 a talk that turns switch 60 on, event 3 a talk that calls
    /// common event 40, which fights troop 71 and turns switch 61 on by a script.
    /// </summary>
    private readonly GameEvents _events = TinyEvents.Of(new TinyGame()
        .Event(2, C(101, "", 0, 0, 2), C(401, "Hello."), C(121, 60, 60, 0))
        .Event(3, C(101, "", 0, 0, 2), C(401, "Hello."), C(117, 40))
        .Common(40, C(301, 0, 71, false, false), C(355, "$game_switches[61] = true")));

    /// <summary>
    /// The topics under test, over the tiny game.
    /// </summary>
    private readonly TopicCaller _topics;

    /// <summary>
    /// Creates the topics over the tiny game, its fingerprint handed over.
    /// </summary>
    public EventTopicsTests()
    {
        _topics = new TopicCaller(context => EventTopics.Register(context, () => _events));
        _topics.Call(EventTopics.Open, new RubyHash { { "fingerprint", _events.Store.Meta!.Build.Fingerprint } });
    }

    /// <summary>
    /// Asserts that a sort names the values it reads and lacks, and sorts once they come: a story
    /// switch behind a branch on variable 1001, which holds at 7 only, and whose switch is no one's own.
    /// </summary>
    [Fact]
    public void Sort_NamesTheValuesItNeedsThenSorts()
    {
        RubyArray list =
        [
            Row(111, 0, [1, 1001, 0, 7, 0]), Row(121, 1, [60, 60, 0]), Row(0, 1, []), Row(412, 0, []), Row(101, 0, ["", 0, 0, 2]), Row(0, 0, []),
        ];

        RubyValue? first = _topics.Call(EventTopics.Sort, new RubyHash { { "list", list } });
        RubyValue? held = _topics.Call(EventTopics.Sort, new RubyHash { { "list", list }, { "values", Values(7) } });
        RubyValue? passed = _topics.Call(EventTopics.Sort, new RubyHash { { "list", list }, { "values", Values(12) } });

        Assert.Equal(new RubyHash { { "needs", new RubyHash { { "v", new RubyArray { 1001 } } } } }, first);
        Assert.Equal("story", held!.AsHash()["kind"].AsText());
        Assert.Equal("talk", passed!.AsHash()["kind"].AsText());
    }

    /// <summary>
    /// Asserts that a page the scripts hold as the database does sorts from it, and one of another
    /// shape, such as a translation that changed a branch, or one it lacks is unknown, so the
    /// scripts hand it over.
    /// </summary>
    [Fact]
    public void Sort_OfAPage_ReadsTheDatabaseOnlyWhileTheShapeMatches()
    {
        RubyHash page = TinyEvents.Page(_events, 1, 2);
        RubyHash changed = TinyEvents.Page(_events, 1, 2);
        changed["shape"] = page["shape"].AsLong() + 1;

        Assert.Equal("story", _topics.Call(EventTopics.Sort, With(page, "values", Values(0)))!.AsHash()["kind"].AsText());
        Assert.Equal(new RubyHash { { "unknown", true } }, _topics.Call(EventTopics.Sort, changed));
        Assert.Equal(new RubyHash { { "unknown", true } }, _topics.Call(EventTopics.Sort, new RubyHash { { "map", 1 }, { "event", 9 }, { "page", 0 }, { "size", 2 }, { "shape", 0 } }));
    }

    /// <summary>
    /// Asserts that asking for one command of a page finds it among the kept commands by its place in
    /// the list the game runs: the text line before it is not kept.
    /// </summary>
    [Fact]
    public void Sort_OfOneCommand_FindsItAmongTheKeptCommands()
    {
        RubyHash Command(int index) => With(With(TinyEvents.Page(_events, 1, 2), "values", Values(0)), "index", index);

        Assert.Equal(new RubyHash { { "story", false } }, _topics.Call(EventTopics.Sort, Command(1)));
        Assert.Equal(new RubyHash { { "story", true } }, _topics.Call(EventTopics.Sort, Command(2)));
    }

    /// <summary>
    /// Asserts that the common events of a game data that differs from the database's in them are
    /// unknown while its map pages still sort, and that without a fingerprint nothing is read.
    /// </summary>
    [Fact]
    public void Open_LeavesOutTheTablesOfTheDifferingParts()
    {
        string[] halves = _events.Store.Meta!.Build.Fingerprint.Split(':');
        string[] sums = halves[1].Split('.');
        sums[9] = "ffffffff";
        ListRow list = _events.Store.CommonList(40)!.Value;
        var common = new RubyHash { { "common", 40 }, { "size", list.CountAll }, { "shape", list.Shape } };

        RubyHash opened = _topics.Call(EventTopics.Open, new RubyHash { { "fingerprint", halves[0] + ":" + string.Join(".", sums) } })!.AsHash();

        Assert.Equal(new RubyHash { { "usable", true }, { "problem", RubyNil.Value }, { "differing", new RubyArray { "common events" } } }, opened);
        Assert.Equal(new RubyHash { { "unknown", true } }, _topics.Call(EventTopics.Sort, common));
        Assert.Equal("story", _topics.Call(EventTopics.Sort, With(TinyEvents.Page(_events, 1, 2), "values", Values(0)))!.AsHash()["kind"].AsText());

        _topics.Call(EventTopics.Open, new RubyHash { { "fingerprint", RubyNil.Value } });
        Assert.Equal(new RubyHash { { "unknown", true } }, _topics.Call(EventTopics.Sort, TinyEvents.Page(_events, 1, 2)));
    }

    /// <summary>
    /// Asserts that the battlefuck events the generator listed, the count of a win (6999) and a
    /// battlefucker's talk that calls it (7001), are read once for every sort, and that a page that
    /// calls the talk still plays alone while the game data differs in the common events, which
    /// leaves the common events themselves unknown.
    /// </summary>
    [Fact]
    public void Sort_ReadsTheBattlefuckEventsOnceWhateverTheGate()
    {
        GameEvents events = TinyEvents.Of(new TinyGame()
            .Event(4, C(101, "", 0, 0, 2), C(401, "Fight me."), C(121, 60, 60, 0), C(117, 7001))
            .Common(6999, C(121, 61, 61, 0))
            .Common(7001, C(117, 6999)));
        var topics = new TopicCaller(context => EventTopics.Register(context, () => events));
        string[] halves = events.Store.Meta!.Build.Fingerprint.Split(':');
        string[] sums = halves[1].Split('.');
        sums[9] = "ffffffff";
        topics.Call(EventTopics.Open, new RubyHash { { "fingerprint", halves[0] + ":" + string.Join(".", sums) } });

        string kind = topics.Call(EventTopics.Sort, With(TinyEvents.Page(events, 1, 4), "values", Values(0)))!.AsHash()["kind"].AsText();

        Assert.Equal("own", kind);
        Assert.Equal(new long[] { 6999, 7001 }, events.Source.Battlefucks.Order());
        Assert.Same(events.Source.Battlefucks, events.Source.Battlefucks);
        Assert.Empty(events.Source.CommonIds);
    }

    /// <summary>
    /// Asserts that a mod folder without the events database answers why, and still sorts the lists
    /// the scripts hand over.
    /// </summary>
    [Fact]
    public void Open_WithoutTheDatabase_SortsOnlyTheListsHandedOver()
    {
        using var folder = new TempFolder();
        var missing = new GameEvents(() => EventStore.Open(Path.Combine(folder.Path, EventSchema.GamePath)), () => new TinyGame().Files(), _ => { });
        var topics = new TopicCaller(context => EventTopics.Register(context, () => missing));

        RubyHash opened = topics.Call(EventTopics.Open, new RubyHash { { "fingerprint", "1:0.0.0.0.0.0.0.0.0.0.0" } })!.AsHash();

        Assert.False(opened["usable"].AsBool());
        Assert.StartsWith("no events database at ", opened["problem"].AsText(), StringComparison.Ordinal);
        Assert.Equal(new RubyHash { { "unknown", true } }, topics.Call(EventTopics.Sort, new RubyHash { { "map", 1 }, { "event", 2 }, { "page", 0 }, { "size", 4 }, { "shape", 1 } }));
        Assert.Equal("talk", topics.Call(EventTopics.Sort, new RubyHash { { "list", new RubyArray { Row(101, 0, ["", 0, 0, 2]), Row(0, 0, []) } } })!.AsHash()["kind"].AsText());
    }

    /// <summary>
    /// Asserts that a map's pages sort at once, a page held otherwise as none, and that the scripts
    /// sort such pages from their commands in the same topic.
    /// </summary>
    [Fact]
    public void Kinds_SortsThePagesHeldOtherwiseFromTheirCommands()
    {
        var pages = new RubyHash { { "map", 1 }, { "pages", new RubyArray { TinyEvents.Row(_events, 2), TinyEvents.Row(_events, 3, 1) } }, { "values", Values(0) } };
        var handed = new RubyHash
        {
            { "map", 1 }, { "pages", new RubyArray { new RubyArray { 3, 0, new RubyArray { Row(101, 0, ["", 0, 0, 2]), Row(0, 0, []) } } } }, { "values", Values(0) },
        };

        Assert.Equal(new RubyHash { { "kinds", new RubyArray { "story", RubyNil.Value } } }, _topics.Call(EventTopics.Kinds, pages));
        Assert.Equal(new RubyHash { { "kinds", new RubyArray { "talk" } } }, _topics.Call(EventTopics.Kinds, handed));
    }

    /// <summary>
    /// Asserts that the command index tells the troops a page fights and what it sets through the
    /// common event it calls, a script's write too, which the database keeps as the list's rows.
    /// </summary>
    [Fact]
    public void Index_TellsTheTroopsAndWritesThroughTheCommonEvents()
    {
        RubyHash answer = _topics.Call(EventTopics.Index, TinyEvents.Page(_events, 1, 3))!.AsHash();

        Assert.Equal(new RubyArray { 71 }, answer["troops"]);
        Assert.Equal(new RubyHash { { "s", new RubyArray { new RubyArray { 61, 61 } } }, { "v", new RubyArray() }, { "ss", new RubyArray() } }, answer["writes"]);
    }

    /// <summary>
    /// Asserts that the command index of a map's pages answers each page in one call, none for a page
    /// held otherwise, and a page the scripts hand over from its commands.
    /// </summary>
    [Fact]
    public void Index_OfAMapsPages_AnswersEachAtOnce()
    {
        var request = new RubyHash
        {
            { "map", 1 },
            { "pages", new RubyArray { TinyEvents.Row(_events, 3), TinyEvents.Row(_events, 2, 1), new RubyArray { 2, 0, new RubyArray { Row(301, 0, [0, 72, false, false]), Row(0, 0, []) } } } },
        };

        RubyArray indexes = _topics.Call(EventTopics.Index, request)!.AsHash()["indexes"].AsArray();

        Assert.Equal(new RubyArray { 71 }, indexes[0].AsHash()["troops"]);
        Assert.Equal(RubyNil.Value, indexes[1]);
        Assert.Equal(new RubyArray { 72 }, indexes[2].AsHash()["troops"]);
    }

    /// <summary>
    /// Asserts that a read ahead that fails is logged and goes no further, since an exception
    /// escaping the DLL's thread would end the game.
    /// </summary>
    [Fact]
    public void ReadAhead_ThatFails_IsLogged()
    {
        var lines = new List<string>();

        EventTopics.ReadAhead(() => throw new DllNotFoundException("e_sqlite3"), lines.Add);

        Assert.Equal(["events: could not open the events database: DllNotFoundException: e_sqlite3"], lines);
    }

    /// <summary>
    /// Writes a command as the scripts hand it over.
    /// </summary>
    /// <param name="code">The code.</param>
    /// <param name="indent">The indent.</param>
    /// <param name="parameters">The parameters.</param>
    /// <returns>[code, indent, parameters].</returns>
    private static RubyArray Row(int code, int indent, RubyArray parameters) => [code, indent, parameters];

    /// <summary>
    /// Adds a field to a request.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <param name="field">The field.</param>
    /// <param name="value">Its value.</param>
    /// <returns>The same request.</returns>
    private static RubyHash With(RubyHash request, string field, RubyValue value)
    {
        request[field] = value;
        return request;
    }

    /// <summary>
    /// Writes the values a sort of the tiny game names: variable 1001, and switches 60 and 61, no
    /// one's own.
    /// </summary>
    /// <param name="progress">Variable 1001.</param>
    /// <returns>The values.</returns>
    private static RubyHash Values(long progress) => new()
    {
        { "v", new RubyHash { { 1001, progress } } },
        { "ps", new RubyHash { { 60, false }, { 61, false } } },
    };
}
