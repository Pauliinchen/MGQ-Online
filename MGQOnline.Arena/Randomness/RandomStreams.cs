//----------------------------------------------------------------
//  RandomStreams.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;

namespace MGQOnline.Arena.Randomness;

/// <summary>
/// The independent random streams of one battle, all derived from the battle's seed.
/// </summary>
/// <remarks>
/// Each mechanic draws from its own stream, so a change in one mechanic never reshuffles the draws,
/// and the goldens, of another.
/// </remarks>
public sealed class RandomStreams
{
    /// <summary>
    /// The streams drawn from so far, by stream number.
    /// </summary>
    private readonly ArenaRandom?[] _streams = new ArenaRandom?[Enum.GetValues<RandomStream>().Length];

    /// <summary>
    /// Initializes the streams of a battle.
    /// </summary>
    /// <param name="battleSeed">The battle's seed.</param>
    public RandomStreams(ulong battleSeed) => BattleSeed = battleSeed;

    /// <summary>
    /// Gets the battle's seed.
    /// </summary>
    public ulong BattleSeed { get; }

    /// <summary>
    /// Gets a stream, created on its first use.
    /// </summary>
    /// <param name="stream">The stream.</param>
    /// <returns>The stream's generator, the same one on every call.</returns>
    public ArenaRandom Get(RandomStream stream) => _streams[(int)stream] ??= new ArenaRandom(SeedOf(BattleSeed, stream));

    /// <summary>
    /// Gives the seed of a stream: the SplitMix64 draw of the battle's seed numbered one past the stream's
    /// number.
    /// </summary>
    /// <param name="battleSeed">The battle's seed.</param>
    /// <param name="stream">The stream.</param>
    /// <returns>The stream's seed.</returns>
    public static ulong SeedOf(ulong battleSeed, RandomStream stream) => SplitMix64.At(battleSeed, (ulong)stream + 1);
}
