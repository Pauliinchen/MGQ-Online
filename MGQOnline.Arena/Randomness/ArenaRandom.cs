//----------------------------------------------------------------
//  ArenaRandom.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Numerics;
using MGQOnline.Arena.Numerics;

namespace MGQOnline.Arena.Randomness;

/// <summary>
/// The arena's random generator: xoshiro128** on 32-bit words, seeded through SplitMix64, so a seed
/// gives the same values on win-x86 and linux-x64.
/// </summary>
/// <remarks>
/// Chances and picks use integers only, never doubles, so no platform's floating point can change a
/// battle.
/// </remarks>
public sealed class ArenaRandom
{
    /// <summary>
    /// The first word of the state.
    /// </summary>
    private uint _s0;

    /// <summary>
    /// The second word of the state.
    /// </summary>
    private uint _s1;

    /// <summary>
    /// The third word of the state.
    /// </summary>
    private uint _s2;

    /// <summary>
    /// The fourth word of the state.
    /// </summary>
    private uint _s3;

    /// <summary>
    /// Initializes a generator from a seed.
    /// </summary>
    /// <remarks>
    /// The two SplitMix64 draws are never both 0, since SplitMix64 gives 0 for one state only, so the
    /// state is never all zeros, the one state xoshiro cannot leave.
    /// </remarks>
    /// <param name="seed">The seed; the state's words are the low and high halves of its first two
    /// SplitMix64 draws.</param>
    public ArenaRandom(ulong seed)
    {
        ulong state = seed;
        ulong first = SplitMix64.Next(ref state);
        ulong second = SplitMix64.Next(ref state);
        _s0 = (uint)first;
        _s1 = (uint)(first >> 32);
        _s2 = (uint)second;
        _s3 = (uint)(second >> 32);
    }

    /// <summary>
    /// Initializes a generator from its four state words, as the reference vectors of xoshiro128** do.
    /// </summary>
    /// <param name="s0">The first word.</param>
    /// <param name="s1">The second word.</param>
    /// <param name="s2">The third word.</param>
    /// <param name="s3">The fourth word.</param>
    /// <exception cref="ArgumentException">All four words are 0.</exception>
    internal ArenaRandom(uint s0, uint s1, uint s2, uint s3)
    {
        if ((s0 | s1 | s2 | s3) == 0)
        {
            throw new ArgumentException("The state must not be all zeros.");
        }

        (_s0, _s1, _s2, _s3) = (s0, s1, s2, s3);
    }

    /// <summary>
    /// Draws the next 32 random bits.
    /// </summary>
    /// <returns>The next value.</returns>
    public uint NextUInt()
    {
        uint result = BitOperations.RotateLeft(_s1 * 5, 7) * 9;
        uint t = _s1 << 9;
        _s2 ^= _s0;
        _s3 ^= _s1;
        _s1 ^= _s2;
        _s0 ^= _s3;
        _s2 ^= t;
        _s3 = BitOperations.RotateLeft(_s3, 11);
        return result;
    }

    /// <summary>
    /// Draws an integer from 0 up to a limit, every value equally likely (Lemire's method).
    /// </summary>
    /// <param name="maxExclusive">The limit, at least 1.</param>
    /// <returns>A value from 0 to <paramref name="maxExclusive"/> - 1.</returns>
    /// <exception cref="ArgumentOutOfRangeException">The limit is below 1.</exception>
    public int NextInt(int maxExclusive)
    {
        ArgumentOutOfRangeException.ThrowIfLessThan(maxExclusive, 1);
        uint range = (uint)maxExclusive;
        ulong product = (ulong)NextUInt() * range;
        uint low = (uint)product;
        if (low < range)
        {
            uint threshold = (0u - range) % range;
            while (low < threshold)
            {
                product = (ulong)NextUInt() * range;
                low = (uint)product;
            }
        }

        return (int)(product >> 32);
    }

    /// <summary>
    /// Rolls a chance out of 10,000.
    /// </summary>
    /// <remarks>
    /// It always draws, also for a chance of never or certain, so changing a chance never shifts the
    /// draws that follow.
    /// </remarks>
    /// <param name="basisPoints">The chance in basis points; 0 or less never hits, 10,000 or more always.</param>
    /// <returns>Whether the roll hits.</returns>
    public bool Roll(int basisPoints) => NextInt(BasisPoints.Whole) < basisPoints;

    /// <summary>
    /// Picks an index, each with the chance of its weight out of the sum.
    /// </summary>
    /// <param name="weights">The weights; 0 never picks its index.</param>
    /// <returns>The index picked, -1 without drawing when every weight is 0.</returns>
    /// <exception cref="ArgumentOutOfRangeException">A weight is negative or the sum exceeds int.MaxValue.</exception>
    public int PickWeighted(ReadOnlySpan<int> weights)
    {
        long total = 0;
        foreach (int weight in weights)
        {
            ArgumentOutOfRangeException.ThrowIfNegative(weight, nameof(weights));
            total += weight;
        }

        if (total == 0)
        {
            return -1;
        }

        ArgumentOutOfRangeException.ThrowIfGreaterThan(total, int.MaxValue, nameof(weights));
        int roll = NextInt((int)total);
        for (int i = 0; i < weights.Length; i++)
        {
            roll -= weights[i];
            if (roll < 0)
            {
                return i;
            }
        }

        throw new InvalidOperationException("The roll fell outside the weights.");
    }
}
