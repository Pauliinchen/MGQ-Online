//----------------------------------------------------------------
//  WireScalars.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Numerics;

namespace MGQOnline.Game.Battles.Wire;

/// <summary>
/// Nil, the token "~", and what a token reads as that names nothing this game has.
/// </summary>
public sealed record WireNil : WireValue
{
    /// <summary>
    /// Initializes the one nil.
    /// </summary>
    private WireNil()
    {
    }

    /// <summary>
    /// Gets nil.
    /// </summary>
    public static WireNil Value { get; } = new();
}

/// <summary>
/// True ("+") or false ("-").
/// </summary>
public sealed record WireBool : WireValue
{
    /// <summary>
    /// Initializes a truth value.
    /// </summary>
    /// <param name="flag">The truth value.</param>
    private WireBool(bool flag) => Flag = flag;

    /// <summary>
    /// Gets true.
    /// </summary>
    public static WireBool True { get; } = new(true);

    /// <summary>
    /// Gets false.
    /// </summary>
    public static WireBool False { get; } = new(false);

    /// <summary>
    /// Gets the truth value.
    /// </summary>
    public bool Flag { get; }
}

/// <summary>
/// An Integer ("i42"), of any size, as Ruby's Integers are.
/// </summary>
/// <param name="Value">The number.</param>
public sealed record WireInteger(BigInteger Value) : WireValue;

/// <summary>
/// A Float ("f1.5"), written as Ruby's <c>Float#to_s</c> writes it.
/// </summary>
/// <param name="Value">The number, infinities and NaN included.</param>
public sealed record WireFloat(double Value) : WireValue;

/// <summary>
/// A Symbol (":count"), by its text.
/// </summary>
/// <param name="Text">The symbol's text without its colon.</param>
public sealed record WireSymbol(string Text) : WireValue;

/// <summary>
/// A String ("sText"), or the text of any other object Ruby writes as one.
/// </summary>
/// <param name="Text">The text.</param>
public sealed record WireString(string Text) : WireValue;
