//----------------------------------------------------------------
//  WorldTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Checked the squad settings and world codes with own values instead of recorded ones
//      Paulinchen  2026-10-23: Took the values of the golden cases from JsonValues
//                            - Read and wrote squad settings through the topics both hosts answer
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Topics;
using MGQParadox.Multiplayer.Topics;

namespace MGQParadox.Multiplayer.Tests.Topics;

/// <summary>
/// Covers the topics of a world's rules: squad settings and world codes.
/// </summary>
public sealed class WorldTopicsTests
{
    /// <summary>
    /// The topics under test.
    /// </summary>
    private readonly TopicCaller _topics = new(context =>
    {
        WorldTopics.Register(context);
        SharedTopics.Register(context);
    });

    /// <summary>
    /// Asserts that a world's squad settings read from their text and write back the same text, and
    /// that a text out of range reads as none.
    /// </summary>
    [Fact]
    public void Squad_ReadsAndWritesTheSettings()
    {
        RubyValue? read = _topics.Call(SquadTopics.Read, "1 6 2 3");

        Assert.Equal(new RubyHash { { "luka", true }, { "formation", 6 }, { "front", 2 }, { "raid_front", 3 } }, read);
        Assert.Equal(RubyString.Utf8("1 6 2 3"), _topics.Call(SquadTopics.Write, read!));
        Assert.Null(_topics.Call(SquadTopics.Read, "0 4 1 5"));
    }

    /// <summary>
    /// Asserts that settings out of range write no text.
    /// </summary>
    [Fact]
    public void SquadWrite_AnswersNothingForSettingsOutOfRange() =>
        Assert.Null(_topics.Call(SquadTopics.Write, new RubyHash { { "luka", false }, { "formation", 3L }, { "front", 1L }, { "raid_front", 1L } }));

    /// <summary>
    /// Asserts that a world code tells its seats, changes them, and keeps them when asked for more
    /// than a world holds.
    /// </summary>
    [Fact]
    public void Code_TellsAndChangesTheSeats()
    {
        RubyValue? Ask(string code, RubyValue seats) => _topics.Call(WorldTopics.Code, new RubyHash { { "code", code }, { "seats", seats } });

        Assert.Equal(new RubyHash { { "code", "mgqmp2;abcdefghjkmnpqrs;r1;8" }, { "seats", 8 } }, Ask("mgqmp2;abcdefghjkmnpqrs;r1;8", RubyNil.Value));
        Assert.Equal(new RubyHash { { "code", "mgqmp2;abcdefghjkmnpqrs;r1;12" }, { "seats", 12 } }, Ask("mgqmp2;abcdefghjkmnpqrs;r1;4", 12));
        Assert.Equal(new RubyHash { { "code", "mgqmp2;abcdefghjkmnpqrs;r1;4" }, { "seats", 4 } }, Ask("mgqmp2;abcdefghjkmnpqrs;r1;4", 99));
    }
}
