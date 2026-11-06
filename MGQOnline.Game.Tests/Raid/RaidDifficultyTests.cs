//----------------------------------------------------------------
//  RaidDifficultyTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Raid;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Raid;

/// <summary>
/// Covers a Raid World's difficulty as world_difficulty.rbx asks it: the world's difficulty waits
/// while a fight has values of its own, and is due once the map is quiet again.
/// </summary>
public sealed class RaidDifficultyTests
{
    /// <summary>
    /// The context the topics answer on.
    /// </summary>
    private readonly TopicContext _topics = new();

    /// <summary>
    /// Registers the topics.
    /// </summary>
    public RaidDifficultyTests()
    {
        DifficultyTopics.Register(_topics.Context);
    }

    /// <summary>
    /// Asserts that a Colosseum match on NORMAL keeps the world's HARD away, that a defeat there,
    /// which leaves only the Colosseum's switch on, lets it apply again, and that a special boss, the
    /// Labyrinth, a running event and a battle keep it waiting.
    /// </summary>
    [Fact]
    public void Colosseum_KeepsItsNormalOnlyDuringAMatch()
    {
        int[] reads = [.. _topics.Value(DifficultyTopics.Reads).AsArray().Select(id => id.AsInt())];

        RubyHash match = State(reads, [RaidDifficulty.Colosseum, RaidDifficulty.ColosseumMatch]);
        RubyHash defeat = State(reads, [RaidDifficulty.Colosseum]);

        Assert.Equal([true, false], new[] { match["own_values"].AsBool(), match["due"].AsBool() });
        Assert.Equal([false, true], new[] { defeat["own_values"].AsBool(), defeat["due"].AsBool() });
        Assert.True(State(reads, [RaidDifficulty.SpecialBoss])["own_values"].AsBool());
        Assert.True(State(reads, [RaidDifficulty.Labyrinth])["own_values"].AsBool());
        Assert.False(State(reads, [], quiet: false)["due"].AsBool());
        Assert.False(State(reads, [], battle: true)["due"].AsBool());
        Assert.False(State(reads, [], game: 1)["due"].AsBool());
    }

    /// <summary>
    /// Asks the state of a game on NORMAL in a world on HARD.
    /// </summary>
    /// <param name="reads">The switches the rules read.</param>
    /// <param name="on">The switches on.</param>
    /// <param name="game">The game's difficulty.</param>
    /// <param name="battle">Whether a battle runs.</param>
    /// <param name="quiet">Whether the map is quiet.</param>
    /// <returns>The answer.</returns>
    private RubyHash State(int[] reads, int[] on, long game = 0, bool battle = false, bool quiet = true) => _topics.Value(DifficultyTopics.State, new RubyHash
    {
        { "world", 1 }, { "game", game }, { "s", new RubyArray(reads.Select(id => (RubyValue)on.Contains(id))) }, { "battle", battle }, { "quiet", quiet },
    }).AsHash();
}
