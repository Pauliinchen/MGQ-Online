//----------------------------------------------------------------
//  RubyScalars.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Globalization;
using System.Numerics;

namespace MGQOnline.Bridge.Ruby;

/// <summary>
/// Ruby's nil.
/// </summary>
public sealed class RubyNil : RubyValue
{
    /// <summary>
    /// The one nil.
    /// </summary>
    public static readonly RubyNil Value = new();

    /// <summary>
    /// Creates the one nil.
    /// </summary>
    private RubyNil()
    {
    }

    /// <inheritdoc />
    public override string KindName => "nil";

    /// <inheritdoc />
    public override string ToString() => "nil";
}

/// <summary>
/// Ruby's true or false.
/// </summary>
public sealed class RubyBool : RubyValue
{
    /// <summary>
    /// The one true.
    /// </summary>
    public static readonly RubyBool True = new(true);

    /// <summary>
    /// The one false.
    /// </summary>
    public static readonly RubyBool False = new(false);

    /// <summary>
    /// Creates true or false.
    /// </summary>
    /// <param name="flag">Which one.</param>
    private RubyBool(bool flag)
    {
        Flag = flag;
    }

    /// <summary>
    /// Gets whether this is true.
    /// </summary>
    public bool Flag { get; }

    /// <inheritdoc />
    public override string KindName => Flag ? "true" : "false";

    /// <inheritdoc />
    public override string ToString() => KindName;
}

/// <summary>
/// A Ruby Integer of any size, a Fixnum or a Bignum alike.
/// </summary>
/// <param name="value">The number.</param>
public sealed class RubyInteger(BigInteger value) : RubyValue
{
    /// <summary>
    /// Gets the number.
    /// </summary>
    public BigInteger Value { get; } = value;

    /// <inheritdoc />
    public override string KindName => "an Integer";

    /// <inheritdoc />
    public override bool Equals(object? obj) => obj is RubyInteger other && other.Value == Value;

    /// <inheritdoc />
    public override int GetHashCode() => Value.GetHashCode();

    /// <inheritdoc />
    public override string ToString() => Value.ToString(CultureInfo.InvariantCulture);
}
