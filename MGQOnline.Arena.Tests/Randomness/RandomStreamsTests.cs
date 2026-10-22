//----------------------------------------------------------------
//  RandomStreamsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Counted the start rest stream
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Arena.Tests.Randomness;

/// <summary>
/// Tests the random streams of a battle.
/// </summary>
public sealed class RandomStreamsTests
{
    /// <summary>
    /// Seeds each stream of seed 42 with its golden seed and draws its golden first values.
    /// </summary>
    /// <param name="stream">The stream.</param>
    /// <param name="seed">Its golden seed.</param>
    /// <param name="first">Its golden first value.</param>
    /// <param name="second">Its golden second value.</param>
    /// <param name="third">Its golden third value.</param>
    [Theory]
    [InlineData(RandomStream.Plan, 13679457532755275413, 1552505907u, 4113083374u, 3991650357u)]
    [InlineData(RandomStream.Cc, 2949826092126892291, 1961968943u, 694432402u, 714492553u)]
    [InlineData(RandomStream.Targeting, 5139283748462763858, 715138048u, 1651189038u, 2542066749u)]
    [InlineData(RandomStream.Side, 6349198060258255764, 3967443191u, 1566750581u, 1460294148u)]
    [InlineData(RandomStream.Rules, 701532786141963250, 744069827u, 3307185162u, 2906375248u)]
    [InlineData(RandomStream.Debris, 16015981125662989062, 1449061242u, 851904391u, 3190443842u)]
    [InlineData(RandomStream.Hits, 4028864712777624925, 2904486292u, 2135730884u, 3264005872u)]
    [InlineData(RandomStream.Party, 14769051326987775908, 2662588288u, 3001600309u, 1299064u)]
    public void DrawsTheGoldenStreams(RandomStream stream, ulong seed, uint first, uint second, uint third)
    {
        ArenaRandom random = new RandomStreams(42).Get(stream);

        Assert.Equal(seed, RandomStreams.SeedOf(42, stream));
        Assert.Equal([first, second, third], new[] { random.NextUInt(), random.NextUInt(), random.NextUInt() });
    }

    /// <summary>
    /// Seeds the stream numbered n with SplitMix64 draw n + 1 of the battle seed.
    /// </summary>
    [Fact]
    public void SeedsFromTheBattleSeedsDraws()
    {
        ulong state = 1234;
        ulong[] draws = Enumerable.Range(0, Enum.GetValues<RandomStream>().Length).Select(_ => SplitMix64.Next(ref state)).ToArray();

        Assert.Equal(draws, Enum.GetValues<RandomStream>().Select(stream => RandomStreams.SeedOf(1234, stream)));
    }

    /// <summary>
    /// Keeps a stream's draws apart from the draws of every other stream.
    /// </summary>
    [Fact]
    public void KeepsStreamsIndependent()
    {
        RandomStreams busy = new(99);
        RandomStreams quiet = new(99);
        for (int i = 0; i < 50; i++)
        {
            busy.Get(RandomStream.Plan).NextUInt();
            busy.Get(RandomStream.Debris).NextInt(6);
        }

        Assert.Equal(quiet.Get(RandomStream.Targeting).NextUInt(), busy.Get(RandomStream.Targeting).NextUInt());
        Assert.Same(busy.Get(RandomStream.Hits), busy.Get(RandomStream.Hits));
        Assert.Equal(99UL, busy.BattleSeed);
    }

    /// <summary>
    /// Gives every stream of a battle a seed of its own.
    /// </summary>
    [Fact]
    public void GivesEveryStreamItsOwnSeed() =>
        Assert.Equal(9, Enum.GetValues<RandomStream>().Select(stream => RandomStreams.SeedOf(0, stream)).Distinct().Count());
}
