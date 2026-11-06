//----------------------------------------------------------------
//  WorldGatesTests.cs
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
/// Covers a Raid World's gated areas as world_gates.rbx asks them: the Central Tartarus stays shut
/// from outside until the world's story has its ten chains.
/// </summary>
public sealed class WorldGatesTests
{
    /// <summary>
    /// The map in front of the Central Tartarus.
    /// </summary>
    private const int Outside = 1287;

    /// <summary>
    /// The context the topics answer on.
    /// </summary>
    private readonly TopicContext _topics = new();

    /// <summary>
    /// Registers the topics.
    /// </summary>
    public WorldGatesTests()
    {
        GateTopics.Register(_topics.Context);
    }

    /// <summary>
    /// Asserts that a move into the Central Tartarus or its deepest map names every chain the
    /// world lacks, then only the one still missing, and goes once all ten are done; a player
    /// already inside and a move elsewhere go meanwhile.
    /// </summary>
    [Fact]
    public void CentralTartarus_OpensOnceTheWorldFinishedItsChains()
    {
        long[] reads = [.. _topics.Value(GateTopics.Reads).AsArray().Select(variable => variable.AsLong())];
        long[] none = new long[reads.Length];
        long[] done = [.. reads.Select(variable => WorldGates.Areas[0].Needs.First(need => need.Variable == variable).Value)];
        long[] koronShort = [.. done.Select((value, place) => reads[place] == 1345 ? value - 1 : value)];

        RubyHash entrance = Shut(1836, Outside, none).AsHash();
        Assert.Equal("Central Tartarus", entrance["area"].AsText());
        Assert.Equal(10, entrance["missing"].AsArray().Count);
        Assert.Equal(10, Shut(1752, Outside, none).AsHash()["missing"].AsArray().Count);
        Assert.Equal(["Koron"], Shut(1836, Outside, koronShort).AsHash()["missing"].AsArray().Select(name => name.AsText()));
        Assert.True(Shut(1836, Outside, done).IsNil);
        Assert.True(Shut(1951, 1938, none).IsNil);
        Assert.True(Shut(2, Outside, none).IsNil);
    }

    /// <summary>
    /// Asks the shut area of a move.
    /// </summary>
    /// <param name="to">The map the move goes to.</param>
    /// <param name="at">The player's map.</param>
    /// <param name="values">The values of the variables the gates read.</param>
    /// <returns>The area and what it lacks, nil when the move may go.</returns>
    private RubyValue Shut(int to, int at, long[] values) => _topics.Value(GateTopics.Shut, new RubyHash
    {
        { "to", to }, { "at", at }, { "v", new RubyArray(values.Select(value => (RubyValue)value)) },
    });
}
