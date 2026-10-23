//----------------------------------------------------------------
//  RandomId.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;

namespace MGQOnline.Game.Ids;

/// <summary>
/// Ids of random digits the scripts make up, such as a battle's, a party's or a trade's.
/// </summary>
/// <remarks>
/// They come from C#'s own randomness: the game's <c>rand</c> stream drives the replay seeds of
/// battles, so an id drawn from it would shift every seed after it.
/// </remarks>
public static class RandomId
{
    /// <summary>
    /// The smallest base an id may be written in.
    /// </summary>
    public const int MinRadix = 2;

    /// <summary>
    /// The largest base an id may be written in, digits and lower-case letters.
    /// </summary>
    public const int MaxRadix = 36;

    /// <summary>
    /// The most digits an id may have.
    /// </summary>
    public const int MaxLength = 64;

    /// <summary>
    /// The digits of every base up to <see cref="MaxRadix"/>, as Ruby's <c>Integer#to_s</c> writes them.
    /// </summary>
    private const string Digits = "0123456789abcdefghijklmnopqrstuvwxyz";

    /// <summary>
    /// Makes up an id.
    /// </summary>
    /// <param name="random">The randomness to draw from.</param>
    /// <param name="length">How many digits, from 1 to <see cref="MaxLength"/>.</param>
    /// <param name="radix">The base, from <see cref="MinRadix"/> to <see cref="MaxRadix"/>.</param>
    /// <returns>Exactly <paramref name="length"/> digits, leading zeros kept, every id equally likely.</returns>
    /// <exception cref="ArgumentOutOfRangeException">The length or the base is out of range.</exception>
    public static string Of(Random random, int length, int radix)
    {
        ArgumentNullException.ThrowIfNull(random);
        ArgumentOutOfRangeException.ThrowIfLessThan(length, 1);
        ArgumentOutOfRangeException.ThrowIfGreaterThan(length, MaxLength);
        ArgumentOutOfRangeException.ThrowIfLessThan(radix, MinRadix);
        ArgumentOutOfRangeException.ThrowIfGreaterThan(radix, MaxRadix);

        return string.Create(length, (random, radix), static (digits, state) =>
        {
            for (int index = 0; index < digits.Length; index++)
            {
                digits[index] = Digits[state.random.Next(state.radix)];
            }
        });
    }
}
