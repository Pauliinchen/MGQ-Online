//----------------------------------------------------------------
//  CoopLevelTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Created
//
//----------------------------------------------------------------

using System.Globalization;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Battles.Live;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Coop;

/// <summary>
/// Covers the level sync of a co-op battle as its scripts ask it: the battle's level from the
/// party leader's characters in it, then each character's sync at that level.
/// </summary>
public sealed class CoopLevelTests
{
    /// <summary>
    /// The context the topics answer on.
    /// </summary>
    private readonly TopicContext _topics = new();

    /// <summary>
    /// Registers the co-op topics.
    /// </summary>
    public CoopLevelTests()
    {
        CoopTopics.Register(_topics.Context, new LiveSession());
    }

    /// <summary>
    /// Asserts that a Classic battle fights at the highest level of the leader's characters in it,
    /// that a member's stronger character drops to it with its equipment losing half as much as
    /// the level takes, and that a character at the level and a team duel's keep their own stats.
    /// </summary>
    [Fact]
    public void Classic_StrongerCharacterFightsAtTheLeadersLevel()
    {
        var players = new RubyArray
        {
            new RubyArray { 2, false, new RubyArray { 0, 1 }, new RubyArray() },
            new RubyArray { 0, true, new RubyArray { 0, 2 }, new RubyArray { 50, 80, 12 } },
        };
        long level = _topics.Value(CoopTopics.Level, new RubyHash { { "raid", false }, { "players", players } }).AsHash()["level"].AsLong();

        RubyHash member = Sync(level, "coop", 90, 900, 500);
        RubyHash even = Sync(level, "coop", 50, 500, 500);
        RubyHash duel = Sync(level, "pvp", 90, 900, 500);

        Assert.Equal(50, level);
        Assert.Equal(Enumerable.Repeat(0.5 + (0.5 * 500 / 900), 8), member["equipment"].AsArray().Select(share => double.Parse(share.AsText(), CultureInfo.InvariantCulture)));
        Assert.Equal("not synced: level 50 is at or below 50", even["why"].AsText());
        Assert.Equal("not synced in a pvp battle", duel["why"].AsText());
    }

    /// <summary>
    /// Asserts that a Raid World's battle has no level.
    /// </summary>
    [Fact]
    public void Raid_HasNoLevel()
    {
        RubyHash answer = _topics.Value(CoopTopics.Level, new RubyHash { { "raid", true }, { "players", new RubyArray() } }).AsHash();

        Assert.True(answer["level"].IsNil);
    }

    /// <summary>
    /// Asks a character's sync, every stat alike.
    /// </summary>
    /// <param name="level">The battle's level.</param>
    /// <param name="kind">The battle's kind.</param>
    /// <param name="ownLevel">The character's personal level.</param>
    /// <param name="own">Each stat at the character's level.</param>
    /// <param name="atLevel">Each stat at the battle's level.</param>
    /// <returns>The answer.</returns>
    private RubyHash Sync(long level, string kind, long ownLevel, long own, long atLevel) => _topics.Value(CoopTopics.Sync, new RubyHash
    {
        { "level", level },
        { "kind", kind },
        { "own_level", ownLevel },
        { "own", new RubyArray(Enumerable.Repeat((RubyValue)own.ToString(CultureInfo.InvariantCulture), 8)) },
        { "bases", new RubyArray(Enumerable.Repeat((RubyValue)atLevel.ToString(CultureInfo.InvariantCulture), 8)) },
    }).AsHash();
}
