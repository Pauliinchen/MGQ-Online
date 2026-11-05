//----------------------------------------------------------------
//  EventTableTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Expected the frozen fights' sites as plain values
//      Paulinchen  2026-11-01: Dropped the checks of troops' members and whether a file exists, whose topics are gone
//      Paulinchen  2026-10-28: Checked the rules the sites come with
//                            - Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Tests.Events;
using MGQParadox.Multiplayer.Topics;
using static MGQOnline.Game.Tests.Events.TinyGame;

namespace MGQParadox.Multiplayer.Tests.Topics;

/// <summary>
/// Covers the topics that read rows of the events database, over the database of a tiny game:
/// chests and page flags of a map, troops' members, the story's battle sites and whether a file of
/// the game exists.
/// </summary>
public sealed class EventTableTopicsTests
{
    /// <summary>
    /// The topics under test, over the game the test makes.
    /// </summary>
    private TopicCaller? _topics;

    /// <summary>
    /// The game's events the topics read.
    /// </summary>
    private GameEvents? _events;

    /// <summary>
    /// Asserts that a map's chest pages name their letter, any other page false, and one the scripts
    /// hold otherwise nil.
    /// </summary>
    [Fact]
    public void Chests_NameTheLettersOfTheChestPages()
    {
        Open(new TinyGame()
            .Event(1, C(126, 5, 0, 0, 1), C(123, "A", 0))
            .Event(2, C(101, "", 0, 0, 2), C(401, "Hello.")));

        RubyHash answer = Call(EventTableTopics.Chests, new RubyHash { { "map", 1 }, { "rows", new RubyArray { Row(1), Row(2), Row(1, 1) } } });

        Assert.Equal(new RubyHash { { "letters", new RubyArray { "A", false, RubyNil.Value } } }, answer);
    }

    /// <summary>
    /// Asserts that a map's pages tell what the generator found in them.
    /// </summary>
    [Fact]
    public void Pages_TellTheFlagsOfThePages()
    {
        Open(new TinyGame().Event(1, C(222)).Event(2, C(136, 1)));

        RubyArray pages = Call(EventTableTopics.Pages, new RubyHash { { "map", 1 }, { "rows", new RubyArray { Row(1), Row(2), Row(2, 1) } } })["pages"].AsArray();

        Assert.Equal(new RubyHash { { "scene_page", false }, { "runs_nothing", false }, { "fades_in", true }, { "sets_encounters", RubyNil.Value } }, pages[0]);
        Assert.True(pages[1].AsHash()["sets_encounters"].AsBool());
        Assert.Equal(RubyNil.Value, pages[2]);
    }

    /// <summary>
    /// Asserts that the story's battles against a troop are its sites, those of a page that turns on
    /// the Colosseum's switch and of a common event only such a page calls left out, and that a site in
    /// a common event names the pages that reach it.
    /// </summary>
    [Fact]
    public void Sites_NameWhereTheStoryFightsATroop()
    {
        Open(new TinyGame()
            .Event(1, C(301, 0, 12, false, false))
            .Event(2, C(121, 87, 87, 0), C(301, 0, 12, false, false), C(117, 41))
            .Event(3, C(117, 40))
            .Common(40, C(301, 0, 13, false, false))
            .Common(41, C(301, 0, 13, false, false)));

        RubyHash answer = Call(EventTableTopics.Sites, new RubyHash { { "troops", new RubyArray { 12, 13 } } });

        Assert.Equal(new RubyArray { new RubyArray { new RubyArray { "map", 1, 1, 1 }, 0, 0, 0, false, 0 } }, answer["sites"].AsHash()[12]);
        Assert.Equal([new RubyArray { "ce", 40 }], answer["sites"].AsHash()[13].AsArray().Select(site => site.AsArray()[0]));
        Assert.Equal(new RubyHash { { 40, new RubyArray { new RubyArray { "map", 1, 3, 1 } } } }, answer["callers"]);
        Assert.Equal(new RubyArray { 154, 576 }, answer["excluded_maps"]);
        Assert.Equal(new RubyArray { 132, 133, 283 }, answer["preamble_codes"]);
    }

    /// <summary>
    /// Makes the topics over a tiny game, its fingerprint handed over.
    /// </summary>
    /// <param name="game">The game.</param>
    private void Open(TinyGame game)
    {
        GameEvents events = TinyEvents.Of(game);
        events.Fingerprint = events.Store.Meta!.Build.Fingerprint;
        _events = events;
        _topics = new TopicCaller(context => EventTableTopics.Register(context, () => events));
    }

    /// <summary>
    /// Calls a topic that answers a Hash.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request.</param>
    /// <returns>The answer.</returns>
    private RubyHash Call(string topic, RubyHash request) => _topics!.Call(topic, request)!.AsHash();

    /// <summary>
    /// Names a page of map 1 as the scripts do.
    /// </summary>
    /// <param name="eventId">The event.</param>
    /// <param name="shapeOffset">What is added to the shape, not 0 for a page the scripts hold otherwise.</param>
    /// <returns>The row.</returns>
    private RubyArray Row(int eventId, int shapeOffset = 0) => TinyEvents.Row(_events!, eventId, shapeOffset);
}
