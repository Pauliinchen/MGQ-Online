//----------------------------------------------------------------
//  WireValue.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Numerics;

namespace MGQOnline.Game.Battles.Wire;

/// <summary>
/// A value of a live battle's message line (battles_sync_wire.rbx): what one token or one bracketed
/// group of tokens holds.
/// </summary>
public abstract record WireValue
{
    /// <summary>
    /// Gets whether the value is nil.
    /// </summary>
    public bool IsNil => this is WireNil;

    /// <summary>
    /// Turns a whole number into an Integer.
    /// </summary>
    /// <param name="number">The number.</param>
    public static implicit operator WireValue(long number) => new WireInteger(number);

    /// <summary>
    /// Turns a big whole number into an Integer.
    /// </summary>
    /// <param name="number">The number.</param>
    public static implicit operator WireValue(BigInteger number) => new WireInteger(number);

    /// <summary>
    /// Turns a text into a String.
    /// </summary>
    /// <param name="text">The text; <see langword="null"/> becomes nil.</param>
    public static implicit operator WireValue(string? text) => text is null ? WireNil.Value : new WireString(text);

    /// <summary>
    /// Turns a truth value into true or false.
    /// </summary>
    /// <param name="flag">The truth value.</param>
    public static implicit operator WireValue(bool flag) => flag ? WireBool.True : WireBool.False;
}
