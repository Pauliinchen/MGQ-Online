//----------------------------------------------------------------
//  EnemyWidthsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Checked the widths of a served battle's troop its setup carries
//                            - Registered the topics over a live session
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Battles.Live;
using MGQOnline.Game.Coop;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Coop;

/// <summary>
/// Covers the widths the players who ask a running battle to take their encounters in measured,
/// which its host, such as the battle server measuring every picture as 32 pixels wide, places
/// their enemies by.
/// </summary>
public sealed class EnemyWidthsTests
{
    /// <summary>
    /// The width the battle server measures every picture as.
    /// </summary>
    private const int ServerWidth = 32;

    /// <summary>
    /// The context the topics answer on.
    /// </summary>
    private readonly BridgeContext _context = new(1, new QuietLog());

    /// <summary>
    /// Registers the co-op topics.
    /// </summary>
    public EnemyWidthsTests()
    {
        CoopTopics.Register(_context, new LiveSession());
    }

    /// <summary>
    /// Asserts that an enemy queued with the width its request told keeps the next encounter's enemy
    /// clear of its whole picture, where the server alone measured it as 32 pixels wide.
    /// </summary>
    [Fact]
    public void Place_QueuedEnemy_TakesTheWidthItsRequestTold()
    {
        RubyArray first = Place("b1", [], [(40, ServerWidth)], "40:300");
        RubyArray told = Place("b1", [(40, 320)], [(41, ServerWidth)], "41:100");
        RubyArray measured = Place("b2", [(40, 320)], [(41, 100)], null);

        Assert.Equal(318, first[0].AsArray()[1].AsInt());
        Assert.Equal(522, told[0].AsArray()[1].AsInt());
        Assert.Equal(386, measured[0].AsArray()[1].AsInt());
    }

    /// <summary>
    /// Asserts that the widths of the troop a served battle's setup carried stand for the 32 pixels the
    /// server measures, so an encounter's enemy keeps clear of a wide picture of the troop.
    /// </summary>
    [Fact]
    public void KeepWidths_PlacesByTheTroopsWidthsTheSetupCarried()
    {
        var request = new RubyHash
        {
            { "bid", "b1" },
            { "troop", new RubyArray { new RubyArray { 30, 320, ServerWidth, false, false } } },
            { "queued", new RubyArray() },
            { "entries", new RubyArray { new RubyArray { 41, 290, 100 } } },
            { "screen", 640 },
        };
        RubyArray measured = _context.Ask(CoopTopics.Place, request)!.AsArray();

        _context.Ask(CoopTopics.KeepWidths, new RubyHash { { "bid", "b1" }, { "widths", "30:300" } });
        RubyArray kept = _context.Ask(CoopTopics.Place, request)!.AsArray();

        Assert.Equal(386, measured[0].AsArray()[1].AsInt());
        Assert.Equal(522, kept[0].AsArray()[1].AsInt());
    }

    /// <summary>
    /// Asserts that the widths a request tells leave out an entry of another number of fields,
    /// without an id or of a width that is none.
    /// </summary>
    [Fact]
    public void Read_LeavesOutWhatIsNoWidth()
    {
        Dictionary<long, int> read = EnemyWidths.Read("31:160;x:5;32:0;33:70000;34:200:1;;35:120;31:170");

        Assert.Equal([(31L, 170), (35L, 120)], read.Select(pair => (pair.Key, pair.Value)).OrderBy(pair => pair.Key));
    }

    /// <summary>
    /// Asserts that the widths are written as a request tells them.
    /// </summary>
    [Fact]
    public void WriteWidths_WritesIdAndWidthPairs()
    {
        RubyArray widths = new() { new RubyArray { 31, 160 }, new RubyArray { 52, 600 } };

        Assert.Equal("31:160;52:600", _context.Ask(CoopTopics.WriteWidths, widths)!.AsText());
    }

    /// <summary>
    /// Places one encounter's enemies on a screen 640 pixels wide whose troop holds one fallen enemy.
    /// </summary>
    /// <param name="bid">The battle's id.</param>
    /// <param name="queued">The enemies queued before, id and x each, measured as the server does.</param>
    /// <param name="entries">The encounter's enemies, id and the width measured each.</param>
    /// <param name="widths">The widths the request tells, <see langword="null"/> for a placement without a request.</param>
    /// <returns>The enemies placed.</returns>
    private RubyArray Place(string bid, (int Id, int X)[] queued, (int Id, int Width)[] entries, string? widths)
    {
        var request = new RubyHash
        {
            { "bid", bid },
            { "troop", new RubyArray { new RubyArray { 31, 320, ServerWidth, false, true } } },
            { "queued", new RubyArray(queued.Select(enemy => (RubyValue)new RubyArray { enemy.Id, enemy.X, ServerWidth })) },
            { "entries", new RubyArray(entries.Select(enemy => (RubyValue)new RubyArray { enemy.Id, 290, enemy.Width })) },
            { "screen", 640 },
        };
        if (widths is not null)
        {
            request.Add("widths", widths);
        }

        return _context.Ask(CoopTopics.Place, request)!.AsArray();
    }

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
