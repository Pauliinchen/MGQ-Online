//----------------------------------------------------------------
//  ArenaRandomTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using System.Security.Cryptography;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Arena.Tests.Randomness;

/// <summary>
/// Tests the arena's random generator against the published reference values and its own goldens.
/// </summary>
public sealed class ArenaRandomTests
{
    /// <summary>
    /// Draws what the reference implementation of xoshiro128** draws from the state 1, 2, 3, 4.
    /// </summary>
    [Fact]
    public void MatchesTheXoshiroReference()
    {
        ArenaRandom random = new(1, 2, 3, 4);
        uint[] expected = [11520, 0, 5927040, 70819200, 2031721883, 1637235492, 1287239034, 3734860849, 3729100597, 4258142804];

        Assert.Equal(expected, expected.Select(_ => random.NextUInt()).ToArray());
    }

    /// <summary>
    /// Draws what the reference implementation of SplitMix64 draws from the seed 0.
    /// </summary>
    [Fact]
    public void MatchesTheSplitMixReference()
    {
        ulong state = 0;
        ulong[] drawn = [SplitMix64.Next(ref state), SplitMix64.Next(ref state), SplitMix64.Next(ref state)];

        Assert.Equal([0xE220A8397B1DCDAF, 0x6E789E6AA1B965F4, 0x06C45D188009454F], drawn);
        Assert.Equal(drawn[2], SplitMix64.At(0, 3));
    }

    /// <summary>
    /// Draws the golden first 1,000 values for seed 42.
    /// </summary>
    [Fact]
    public void DrawsTheGoldenValues()
    {
        ArenaRandom random = new(ArenaRandomReference.Seed);
        uint[] drawn = new uint[ArenaRandomReference.First1000.Length];
        for (int i = 0; i < drawn.Length; i++)
        {
            drawn[i] = random.NextUInt();
        }

        Assert.Equal(ArenaRandomReference.First1000, drawn);
        byte[] bytes = new byte[drawn.Length * sizeof(uint)];
        for (int i = 0; i < drawn.Length; i++)
        {
            System.Buffers.Binary.BinaryPrimitives.WriteUInt32LittleEndian(bytes.AsSpan(i * sizeof(uint)), drawn[i]);
        }

        Assert.Equal(ArenaRandomReference.Sha256, Convert.ToHexStringLower(SHA256.HashData(bytes)));
    }

    /// <summary>
    /// Seeds the state from the low and high halves of the seed's first two SplitMix64 draws.
    /// </summary>
    [Fact]
    public void SeedsThroughSplitMix()
    {
        ulong first = SplitMix64.At(42, 1);
        ulong second = SplitMix64.At(42, 2);
        ArenaRandom fromWords = new((uint)first, (uint)(first >> 32), (uint)second, (uint)(second >> 32));
        ArenaRandom fromSeed = new(42);

        Assert.Equal(Enumerable.Range(0, 8).Select(_ => fromWords.NextUInt()), Enumerable.Range(0, 8).Select(_ => fromSeed.NextUInt()));
    }

    /// <summary>
    /// Refuses the all-zero state, which xoshiro never leaves.
    /// </summary>
    [Fact]
    public void RefusesTheZeroState() => Assert.Throws<ArgumentException>(() => new ArenaRandom(0, 0, 0, 0));

    /// <summary>
    /// Draws the golden integers below 10,000 for seed 42.
    /// </summary>
    [Fact]
    public void DrawsTheGoldenIntegers()
    {
        ArenaRandom random = new(42);

        Assert.Equal([4137, 9697, 39, 5395, 6500, 5947, 6846, 5226, 8306, 6818], Enumerable.Range(0, 10).Select(_ => random.NextInt(10_000)));
    }

    /// <summary>
    /// Keeps every integer below the limit and reaches each of them.
    /// </summary>
    /// <param name="limit">The limit.</param>
    [Theory]
    [InlineData(1)]
    [InlineData(2)]
    [InlineData(3)]
    [InlineData(7)]
    [InlineData(100)]
    public void DrawsEveryIntegerBelowTheLimit(int limit)
    {
        ArenaRandom random = new(7);
        int[] counts = new int[limit];
        for (int i = 0; i < limit * 200; i++)
        {
            counts[random.NextInt(limit)]++;
        }

        Assert.All(counts, count => Assert.InRange(count, 100, 300));
    }

    /// <summary>
    /// Draws below the largest limit, where the rejection of Lemire's method matters most.
    /// </summary>
    [Fact]
    public void DrawsBelowTheLargestLimit()
    {
        ArenaRandom random = new(9);

        Assert.All(Enumerable.Range(0, 1000).Select(_ => random.NextInt(int.MaxValue)), value => Assert.InRange(value, 0, int.MaxValue - 1));
    }

    /// <summary>
    /// Refuses a limit below 1.
    /// </summary>
    /// <param name="limit">The limit.</param>
    [Theory]
    [InlineData(0)]
    [InlineData(-5)]
    public void RefusesALimitBelowOne(int limit) =>
        Assert.Throws<ArgumentOutOfRangeException>(() => new ArenaRandom(1).NextInt(limit));

    /// <summary>
    /// Never hits a chance of 0 or less, always one of 10,000 or more, and draws once for either.
    /// </summary>
    [Fact]
    public void RollsTheEdgesAndAlwaysDraws()
    {
        ArenaRandom rolled = new(3);
        ArenaRandom drawn = new(3);
        for (int i = 0; i < 500; i++)
        {
            Assert.False(rolled.Roll(i % 2 == 0 ? 0 : -10));
            Assert.True(rolled.Roll(i % 2 == 0 ? 10_000 : 20_000));
            drawn.NextInt(10_000);
            drawn.NextInt(10_000);
        }

        Assert.Equal(drawn.NextUInt(), rolled.NextUInt());
    }

    /// <summary>
    /// Hits a chance as often as its basis points say, within the noise of the sample.
    /// </summary>
    [Fact]
    public void RollsAboutTheChance()
    {
        ArenaRandom random = new(11);

        int hits = Enumerable.Range(0, 20_000).Count(_ => random.Roll(2_500));

        Assert.InRange(hits, 4_700, 5_300);
    }

    /// <summary>
    /// Picks the golden indexes for seed 42 and never an index of weight 0.
    /// </summary>
    [Fact]
    public void PicksTheGoldenIndexes()
    {
        ArenaRandom random = new(42);
        int[] weights = [1024, 0, 3072, 512];

        Assert.Equal([2, 3, 0, 2, 2, 2, 2, 2, 2, 2], Enumerable.Range(0, 10).Select(_ => random.PickWeighted(weights)));
        Assert.DoesNotContain(1, Enumerable.Range(0, 2000).Select(_ => random.PickWeighted(weights)));
    }

    /// <summary>
    /// Picks each index about as often as its weight says.
    /// </summary>
    [Fact]
    public void PicksAboutTheWeights()
    {
        ArenaRandom random = new(5);
        int[] counts = new int[3];
        for (int i = 0; i < 30_000; i++)
        {
            counts[random.PickWeighted([1, 2, 3])]++;
        }

        Assert.InRange(counts[0], 4_500, 5_500);
        Assert.InRange(counts[1], 9_400, 10_600);
        Assert.InRange(counts[2], 14_300, 15_700);
    }

    /// <summary>
    /// Picks nothing and draws nothing when every weight is 0.
    /// </summary>
    [Fact]
    public void PicksNothingWithoutWeight()
    {
        ArenaRandom picked = new(8);
        ArenaRandom untouched = new(8);

        Assert.Equal(-1, picked.PickWeighted([0, 0]));
        Assert.Equal(-1, picked.PickWeighted([]));
        Assert.Equal(untouched.NextUInt(), picked.NextUInt());
    }

    /// <summary>
    /// Refuses negative weights and sums an int cannot hold.
    /// </summary>
    [Fact]
    public void RefusesBadWeights()
    {
        ArenaRandom random = new(1);

        Assert.Throws<ArgumentOutOfRangeException>(() => random.PickWeighted([3, -1]));
        Assert.Throws<ArgumentOutOfRangeException>(() => random.PickWeighted([int.MaxValue, 1]));
    }
}
