//----------------------------------------------------------------
//  PoolTopicsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Covered the fights' moments and the battle server's outbox
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Raid;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Raid;

/// <summary>
/// Covers the pools' topics both hosts answer: the pools as the scripts read them, the battle
/// server's feed of what the relay told and its outbox, a fight's moments, and the defeats and
/// resets a push told, posted once at a drain.
/// </summary>
public sealed class PoolTopicsTests
{
    /// <summary>
    /// The clock the ledger reads, in milliseconds.
    /// </summary>
    private long _now = 1_000_000;

    /// <summary>
    /// The battle server's way to the pools under the topics.
    /// </summary>
    private readonly PoolOutbox _outbox;

    /// <summary>
    /// The ledger under the topics.
    /// </summary>
    private readonly PoolLedger _ledger;

    /// <summary>
    /// The context the topics are registered on.
    /// </summary>
    private readonly BridgeContext _context = new(1, new QuietLog());

    /// <summary>
    /// Initializes the topics over an outbox and a ledger of the test's clock, as the battle server's core has them.
    /// </summary>
    public PoolTopicsTests()
    {
        _ledger = new PoolLedger(() => _now);
        _outbox = new PoolOutbox(_ledger);
        PoolTopics.Register(_context, _outbox);
    }

    /// <summary>
    /// Asserts that the pools read with every bit of their share, their max as a whole number and
    /// the world they belong to.
    /// </summary>
    [Fact]
    public void Pools_ReadAsTheScriptsTakeThem()
    {
        _ledger.Enter("w1");
        _ledger.Hear(new PoolWord("Sara", 1e-12, 900.5, false, string.Empty), PoolSource.Fetched);
        _ledger.Hear(new PoolWord("Ilias", 0, 4000, true, "Hero"), PoolSource.Fetched);

        RubyHash pools = _context.Ask(PoolTopics.Pools)!.AsHash();

        Assert.Equal(("w1", "0.03"), (pools["world"].AsText(), pools["regen"].AsText()));
        Assert.Equal(["Ilias|0|4000|True|Hero", "Sara|1E-09|901|False|"], Rows(pools["pools"].AsArray()));
    }

    /// <summary>
    /// Asserts that the battle server's feed keeps older word back while its own report waits and
    /// takes the relay's answer, a refused answer only ending the wait; the report waits in the
    /// outbox until the scripts take it.
    /// </summary>
    [Fact]
    public void ServerFeed_TakesWordAndAnswers()
    {
        Assert.True(Ask(PoolTopics.Heard, Word("Sara", "0.5", answer: false)));
        Assert.True(_outbox.Report(string.Empty, "Sara", "b1", "1\t0.1000000000\t900\t0"));
        Assert.False(Ask(PoolTopics.Heard, Word("Sara", "0.5", answer: false)));
        Assert.Equal(0.4, _ledger.Pools().Single().Left, 12);
        Assert.Equal(["|Sara|b1|1\t0.1000000000\t900\t0"], _context.Ask(PoolTopics.Reports)!.AsArray().Select(report => string.Join("|", report.AsArray().Select(field => field.AsText()))));

        Assert.True(Ask(PoolTopics.Heard, Word("Sara", "0.35", answer: true)));
        Assert.Equal(0.35, _ledger.Pools().Single().Left, 12);

        _outbox.Report(string.Empty, "Sara", "b1", "2\t0.1000000000\t900\t0");
        Assert.False(Ask(PoolTopics.Heard, Word("Sara", null, answer: true)));
        Assert.True(Ask(PoolTopics.Heard, Word("Sara", "0.3", answer: false)));
    }

    /// <summary>
    /// Asserts that a fight opened through the topics reports at its command phase, hands back the
    /// HP to set and ends with its end; without a fight a moment answers nothing.
    /// </summary>
    [Fact]
    public void Fight_RunsItsMomentsThroughTheTopics()
    {
        RubyHash Turn(string moment, string enemies) => _context.Ask(PoolTopics.FightTurn, new RubyHash { { "moment", moment }, { "reporter", true }, { "enemies", enemies } })!.AsHash();

        Assert.Null(_context.Ask(PoolTopics.FightTurn, new RubyHash { { "moment", "phase" }, { "reporter", true }, { "enemies", string.Empty } }));
        _ledger.Enter("w1");
        _ledger.Hear(new PoolWord("Sara", 0.5, 900, false, string.Empty), PoolSource.Fetched);
        _context.Ask(PoolTopics.FightOpen, new RubyHash { { "world", "w1" }, { "battle", "b1" }, { "keys", new RubyArray(["Sara"]) }, { "guest", false } });

        RubyHash start = Turn("start", "0:900:900:0:7");
        RubyHash phase = Turn("phase", "0:360:900:0:7");

        Assert.Equal("0:450", string.Join(",", start["actions"].AsArray().Select(action => $"{action.AsArray()[0].AsInt()}:{action.AsArray()[1].AsLong()}")));
        Assert.Equal((true, false, 2000L), (phase["reported"].AsBool(), phase["guest"].AsBool(), phase["report_in"].AsLong()));
        Assert.Equal(["w1|Sara|b1|1\t0.1000000000\t900\t0"], _context.Ask(PoolTopics.Reports)!.AsArray().Select(report => string.Join("|", report.AsArray().Select(field => field.AsText()))));
        Turn("end", "0:360:900:0:7");
        Assert.Null(_context.Ask(PoolTopics.FightTurn, new RubyHash { { "moment", "phase" }, { "reporter", true }, { "enemies", string.Empty } }));
    }

    /// <summary>
    /// Asserts that a push's defeat and reset reach the scripts once each, at the next drain.
    /// </summary>
    [Fact]
    public void Pushes_PostDefeatsAndResetsOnce()
    {
        _ledger.Hear(new PoolWord("Sara", 0, 900, true, "Hero"), PoolSource.Pushed);
        _ledger.Hear(new PoolWord("Sara", 0, 900, true, "Hero"), PoolSource.Pushed);
        _ledger.Hear(new PoolWord("Ilias", 0, 900, true, string.Empty), PoolSource.Fetched);
        Assert.Equal(["raid.boss_defeated Sara Hero"], Drain());

        _ledger.Hear(new PoolWord("Sara", 1, 900, false, string.Empty), PoolSource.Pushed);
        Assert.Equal(["raid.boss_back Sara"], Drain());
        Assert.Empty(Drain());
    }

    /// <summary>
    /// Writes the pools' rows as compact texts.
    /// </summary>
    /// <param name="rows">The rows.</param>
    /// <returns>Each row's fields joined by bars.</returns>
    private static List<string> Rows(RubyArray rows) =>
        rows.Select(row => row.AsArray()).Select(row => $"{row[0].AsText()}|{row[1].AsText()}|{row[2].AsLong()}|{row[3].AsBool()}|{row[4].AsText()}").ToList();

    /// <summary>
    /// Makes the battle server's word of a pool as the feed hands it over.
    /// </summary>
    /// <param name="key">The pool's key.</param>
    /// <param name="left">The share as text, <see langword="null"/> for a refused report's answer.</param>
    /// <param name="answer">Whether it answers one of the server's reports.</param>
    /// <returns>The request.</returns>
    private static RubyHash Word(string key, string? left, bool answer) => new()
    {
        { "world", string.Empty }, { "key", key }, { "left", left }, { "max", 900 }, { "defeated", false }, { "by", string.Empty }, { "answer", answer },
    };

    /// <summary>
    /// Asks a topic for its value.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request.</param>
    /// <returns>The value as a truth value.</returns>
    private bool Ask(string topic, RubyValue request) => _context.Ask(topic, request)!.AsBool();

    /// <summary>
    /// Takes the events of a drain.
    /// </summary>
    /// <returns>Each event's topic and payload as a text.</returns>
    private List<string> Drain()
    {
        byte[] buffer = new byte[4096];
        int length = _context.Drain(++_now, buffer);
        return length <= 0
            ? []
            : RubyMarshal.Read(buffer.AsSpan(0, length)).AsArray().Select(entry => entry.AsArray())
                .Select(entry => string.Join(" ", new[] { entry[0].AsText() }.Concat(entry[1].AsHash().Select(pair => pair.Value.AsText())))).ToList();
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
