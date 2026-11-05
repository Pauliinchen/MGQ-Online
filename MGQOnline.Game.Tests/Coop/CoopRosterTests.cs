//----------------------------------------------------------------
//  CoopRosterTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Renamed it for the checks that stayed and dropped the recorded cases
//      Paulinchen  2026-10-30: Registered the topics over a live session
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Battles.Live;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Coop;

/// <summary>
/// Covers through the co-op topics how a host repairs a guest's troop and what a host does once
/// players left.
/// </summary>
public sealed class CoopRosterTests
{
    /// <summary>
    /// The context the topics answer on.
    /// </summary>
    private readonly BridgeContext _context = new(1, new QuietLog());

    /// <summary>
    /// Registers the co-op topics.
    /// </summary>
    public CoopRosterTests()
    {
        CoopTopics.Register(_context, new LiveSession());
    }

    /// <summary>
    /// Asserts that enemies the scripts hand over as they parsed them repair as from a line: a field
    /// of another kind takes this game's place, an enemy that is no list keeps this game's troop.
    /// </summary>
    [Fact]
    public void Repair_PlainEnemies_RepairsAsFromALine()
    {
        RubyHash place = Repair(new RubyArray { new RubyArray { 31, "Float", 300 } });
        RubyHash kept = Repair(new RubyArray { new RubyArray { 31, 1, 2, 0 }, "Integer" });

        Assert.Equal("[[31,320,300,0]]", Text(place["enemies"]));
        Assert.Equal("[[x,Float,the host's enemy],[mark,NilClass,the host's enemy]]", Text(place["enemy_dropped"]));
        Assert.True(kept["enemies"].IsNil);
        Assert.Equal("[[enemy,Integer,the host's troop for its]]", Text(kept["enemy_dropped"]));
    }

    /// <summary>
    /// Asserts what a host does once players left: the others fight on, a host alone fights on with
    /// their own team, and the battle server keeps a battle for its last player and ends one every
    /// player left.
    /// </summary>
    [Fact]
    public void Settle_DecidesByWhoStays()
    {
        Assert.Equal("none", Settled([0, 2], [2], false)["outcome"].AsText());
        Assert.Equal("reform|[0,3]|[2]", Outcome(Settled([0, 2, 3], [3], false)));
        Assert.Equal("solo|[0]|[2]", Outcome(Settled([0, 2], [], false)));
        Assert.Equal("reform|[2]|[3]", Outcome(Settled([2, 3], [2], true)));
        Assert.Equal("abandon|[]|[2,3]", Outcome(Settled([2, 3], [], true)));
    }

    /// <summary>
    /// Repairs enemies as the scripts hand them over against a troop of one enemy at (320, 300).
    /// </summary>
    /// <param name="enemies">The enemies.</param>
    /// <returns>The answer.</returns>
    private RubyHash Repair(RubyArray enemies) => _context.Ask(CoopTopics.Repair, new RubyHash
    {
        { "enemies", enemies },
        { "own", new RubyArray { new RubyArray { 320, 300 } } },
        { "count", 100 },
    })!.AsHash();

    /// <summary>
    /// Asks what a host does once players left, its own seat 0.
    /// </summary>
    /// <param name="players">The battle's players.</param>
    /// <param name="guestsIn">The guests still in.</param>
    /// <param name="served">Whether the battle server hosts it.</param>
    /// <returns>The answer.</returns>
    private RubyHash Settled(int[] players, int[] guestsIn, bool served) => _context.Ask(CoopTopics.Settle, new RubyHash
    {
        { "players", new RubyArray(players.Select(seat => (RubyValue)seat)) },
        { "own", 0 },
        { "in", new RubyArray(guestsIn.Select(seat => (RubyValue)seat)) },
        { "served", served },
    })!.AsHash();

    /// <summary>
    /// Writes a decision for comparing.
    /// </summary>
    /// <param name="answer">The decision.</param>
    /// <returns>"outcome|staying|left".</returns>
    private static string Outcome(RubyHash answer) => $"{answer["outcome"].AsText()}|{Text(answer["staying"])}|{Text(answer["left"])}";

    /// <summary>
    /// Writes a value the topics answered for comparing.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>Its text, lists in brackets.</returns>
    private static string Text(RubyValue value) => value switch
    {
        RubyArray list => "[" + string.Join(",", list.Select(Text)) + "]",
        RubyNil => "nil",
        RubyInteger number => number.Value.ToString(CultureInfo.InvariantCulture),
        RubyString text => text.Text,
        _ => value.ToString() ?? string.Empty,
    };

    /// <summary>
    /// A log that keeps nothing.
    /// </summary>
    private sealed class QuietLog : IBridgeLog
    {
        /// <inheritdoc />
        public void Write(string line)
        {
        }
    }
}
