//----------------------------------------------------------------
//  CoopModeTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Coop;

/// <summary>
/// Checks what the live battle's topics decide for a co-op battle, which its mode no longer
/// answers itself, and the joins they hand the co-op topics.
/// </summary>
public sealed class CoopModeTests
{
    /// <summary>
    /// The context the topics are registered on, both hosts' shared topics.
    /// </summary>
    private readonly BridgeContext _context = new(1, new QuietLog());

    /// <summary>
    /// Registers the shared topics and joins a co-op battle as its host with the guests 2 and 3.
    /// </summary>
    public CoopModeTests()
    {
        SharedTopics.Register(_context);
        _context.Ask(LiveTopics.Join, new RubyHash
        {
            { "role", "host" }, { "bid", "b1" }, { "seats", new RubyArray { 2, 3 } }, { "player", "the party" }, { "kind", "coop" }, { "team", false }, { "served", false },
        });
    }

    /// <summary>
    /// Asserts that every guest of a co-op battle stands on the host's side and that the battle's own
    /// messages in the stream are its party and troop.
    /// </summary>
    [Fact]
    public void Mode_OfACoopBattle_AnswersItsSideAndKinds()
    {
        Assert.True(_context.Ask(LiveTopics.Mode, new RubyHash { { "op", "same_side" }, { "seat", 3 } })!.AsBool());
        Assert.Equal(["coop_party", "coop_troop"], _context.Ask(LiveTopics.Mode, new RubyHash { { "op", "kinds" } })!.AsArray().Select(kind => kind.AsText()));
    }

    /// <summary>
    /// Asserts that the gathering takes a join that came over the live battle's session.
    /// </summary>
    [Fact]
    public void Gather_TakesAJoinTheSessionReceived()
    {
        _context.Ask(LiveTopics.Receive, new RubyHash { { "seat", 2 }, { "kind", "join" }, { "body", "build" }, { "who", "P2" } });
        _context.Ask(CoopTopics.Gather, new RubyHash { { "op", "start" }, { "seats", new RubyArray { 2 } }, { "limit", 360 } });

        Assert.True(_context.Ask(CoopTopics.Gather, new RubyHash { { "op", "frame" }, { "gone", new RubyArray() } })!.AsBool());
        RubyHash end = _context.Ask(CoopTopics.Gather, new RubyHash { { "op", "end" } })!.AsHash();
        Assert.Equal("build", end["joined"].AsArray()[0].AsArray()[1].AsText());
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
