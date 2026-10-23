//----------------------------------------------------------------
//  EventTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Checked the event command index
//                            - Created
//
//----------------------------------------------------------------

using System;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;
using MGQParadox.Multiplayer.Tests.Network.World;
using MGQParadox.Multiplayer.Topics;

namespace MGQParadox.Multiplayer.Tests.Topics;

/// <summary>
/// Covers the event sorter's topics as the scripts call them: the values a sort names it needs,
/// pages the DLL's data lacks, and the map's pages at once.
/// </summary>
public sealed class EventTopicsTests : IDisposable
{
    /// <summary>
    /// A game folder without data.
    /// </summary>
    private readonly TempFolder _game = new();

    /// <summary>
    /// The topics under test, over the empty folder.
    /// </summary>
    private readonly TopicCaller _topics;

    /// <summary>
    /// Creates the topics over a game folder without data.
    /// </summary>
    public EventTopicsTests()
    {
        var catalog = new EventCatalog(GameData.OfFolder(_game.Path));
        _topics = new TopicCaller(context => EventTopics.Register(context, () => catalog));
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
    /// Asserts that a page or a common event the DLL's data lacks is unknown, so the scripts hand the
    /// list over, and that a map's pages it lacks sort as none.
    /// </summary>
    [Fact]
    public void Sort_OfDataTheFolderLacks_IsUnknown()
    {
        var page = new RubyHash { { "map", 3 }, { "event", 5 }, { "page", 0 }, { "size", 2 } };
        var common = new RubyHash { { "common", 40 }, { "size", 2 } };
        var map = new RubyHash { { "map", 3 }, { "pages", new RubyArray { new RubyArray { 5, 0, 2 } } } };

        Assert.Equal(new RubyHash { { "unknown", true } }, _topics.Call(EventTopics.Sort, page));
        Assert.Equal(new RubyHash { { "unknown", true } }, _topics.Call(EventTopics.Sort, common));
        Assert.Equal(new RubyHash { { "kinds", new RubyArray { RubyNil.Value } } }, _topics.Call(EventTopics.Kinds, map));
    }

    /// <summary>
    /// Asserts that asking for one command answers whether it moves the story on.
    /// </summary>
    [Fact]
    public void Sort_OfOneCommand_AnswersItsStory()
    {
        RubyArray list = [Row(101, 0, ["", 0, 0, 2]), Row(123, 0, ["A", 0]), Row(0, 0, [])];

        Assert.Equal(new RubyHash { { "story", false } }, _topics.Call(EventTopics.Sort, new RubyHash { { "list", list }, { "index", 0 } }));
        Assert.Equal(new RubyHash { { "story", true } }, _topics.Call(EventTopics.Sort, new RubyHash { { "list", list }, { "index", 1 } }));
    }

    /// <summary>
    /// Asserts that the command index tells the troops a list fights and what it sets.
    /// </summary>
    [Fact]
    public void Index_TellsTheTroopsAndWrites()
    {
        RubyArray list = [Row(301, 0, [0, 71, 0, 0]), Row(121, 0, [60, 61, 0]), Row(123, 0, ["A", 0]), Row(0, 0, [])];

        RubyHash answer = _topics.Call(EventTopics.Index, new RubyHash { { "list", list } })!.AsHash();

        Assert.Equal(new RubyArray { 71 }, answer["troops"]);
        Assert.Equal(new RubyHash { { "s", new RubyArray { new RubyArray { 60, 61 } } }, { "v", new RubyArray() }, { "ss", new RubyArray { "A" } } }, answer["writes"]);
    }

    /// <inheritdoc />
    public void Dispose() => _game.Dispose();

    /// <summary>
    /// Writes a command as the scripts hand it over.
    /// </summary>
    /// <param name="code">The code.</param>
    /// <param name="indent">The indent.</param>
    /// <param name="parameters">The parameters.</param>
    /// <returns>[code, indent, parameters].</returns>
    private static RubyArray Row(int code, int indent, RubyArray parameters) => [code, indent, parameters];

    /// <summary>
    /// Writes the values the first sort named: variable 1001 and switch 60, no one's own.
    /// </summary>
    /// <param name="progress">Variable 1001.</param>
    /// <returns>The values.</returns>
    private static RubyHash Values(long progress) => new()
    {
        { "v", new RubyHash { { 1001, progress } } },
        { "ps", new RubyHash { { 60, false } } },
    };
}
