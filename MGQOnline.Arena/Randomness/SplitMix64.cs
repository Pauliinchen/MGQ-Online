//----------------------------------------------------------------
//  SplitMix64.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Arena.Randomness;

/// <summary>
/// The SplitMix64 generator, which turns one seed into well-mixed seeds for the arena's generators.
/// </summary>
public static class SplitMix64
{
    /// <summary>
    /// The step the state advances by on each draw: 2^64 divided by the golden ratio, made odd.
    /// </summary>
    public const ulong Gamma = 0x9E3779B97F4A7C15;

    /// <summary>
    /// Advances a state and gives its next value.
    /// </summary>
    /// <param name="state">The state, advanced in place.</param>
    /// <returns>The next value.</returns>
    public static ulong Next(ref ulong state)
    {
        state += Gamma;
        return Mix(state);
    }

    /// <summary>
    /// Gives the value a state yields after a number of draws, without drawing the ones before.
    /// </summary>
    /// <param name="seed">The state before the first draw.</param>
    /// <param name="draw">Which draw, 1 for the first.</param>
    /// <returns>The value of that draw.</returns>
    public static ulong At(ulong seed, ulong draw) => Mix(seed + (Gamma * draw));

    /// <summary>
    /// Mixes the bits of a state into a value.
    /// </summary>
    /// <param name="z">The state.</param>
    /// <returns>The mixed value.</returns>
    private static ulong Mix(ulong z)
    {
        z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9;
        z = (z ^ (z >> 27)) * 0x94D049BB133111EB;
        return z ^ (z >> 31);
    }
}
