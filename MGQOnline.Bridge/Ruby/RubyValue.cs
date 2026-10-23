//----------------------------------------------------------------
//  RubyValue.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Numerics;

namespace MGQOnline.Bridge.Ruby;

/// <summary>
/// A value Ruby's Marshal holds: the plain ones that cross the bridge (nil, true, false, Integer,
/// String, Array, Hash) and, read from game data only, symbols, floats and objects.
/// </summary>
public abstract class RubyValue
{
    /// <summary>
    /// The deepest nesting the codec reads or writes; plain bridge values nest far less.
    /// </summary>
    public const int MaxDepth = 256;

    /// <summary>
    /// Gets what the value is, with its article, as messages name it, such as "an Integer".
    /// </summary>
    public abstract string KindName { get; }

    /// <summary>
    /// Gets whether the value is nil.
    /// </summary>
    public bool IsNil => this is RubyNil;

    /// <summary>
    /// Turns a text into a UTF-8 String.
    /// </summary>
    /// <param name="text">The text; <see langword="null"/> becomes nil.</param>
    public static implicit operator RubyValue(string? text) => text is null ? RubyNil.Value : RubyString.Utf8(text);

    /// <summary>
    /// Turns a whole number into an Integer.
    /// </summary>
    /// <param name="number">The number.</param>
    public static implicit operator RubyValue(long number) => new RubyInteger(number);

    /// <summary>
    /// Turns a big whole number into an Integer.
    /// </summary>
    /// <param name="number">The number.</param>
    public static implicit operator RubyValue(BigInteger number) => new RubyInteger(number);

    /// <summary>
    /// Turns a truth value into true or false.
    /// </summary>
    /// <param name="flag">The truth value.</param>
    public static implicit operator RubyValue(bool flag) => flag ? RubyBool.True : RubyBool.False;

    /// <summary>
    /// Reads the value as a whole number that fits 64 bits.
    /// </summary>
    /// <returns>The number.</returns>
    /// <exception cref="RubyValueException">The value is no Integer or does not fit.</exception>
    public long AsLong()
    {
        RubyInteger number = As<RubyInteger>("an Integer");
        return number.Value >= long.MinValue && number.Value <= long.MaxValue
            ? (long)number.Value
            : throw new RubyValueException($"The Integer {number.Value} does not fit 64 bits.");
    }

    /// <summary>
    /// Reads the value as a whole number that fits 32 bits.
    /// </summary>
    /// <returns>The number.</returns>
    /// <exception cref="RubyValueException">The value is no Integer or does not fit.</exception>
    public int AsInt()
    {
        long number = AsLong();
        return number is >= int.MinValue and <= int.MaxValue
            ? (int)number
            : throw new RubyValueException($"The Integer {number} does not fit 32 bits.");
    }

    /// <summary>
    /// Reads the value as true or false.
    /// </summary>
    /// <returns>The truth value.</returns>
    /// <exception cref="RubyValueException">The value is neither true nor false.</exception>
    public bool AsBool() => As<RubyBool>("true or false").Flag;

    /// <summary>
    /// Reads the value as a text String, one marked UTF-8 or US-ASCII.
    /// </summary>
    /// <returns>The text.</returns>
    /// <exception cref="RubyValueException">The value is no String, or a binary one.</exception>
    public string AsText()
    {
        RubyString text = As<RubyString>("a String");
        return text.Encoding is RubyEncoding.Utf8 or RubyEncoding.UsAscii
            ? text.Text
            : throw new RubyValueException($"Expected a text String, found {text.KindName}.");
    }

    /// <summary>
    /// Reads the value as the bytes of a String of any encoding.
    /// </summary>
    /// <returns>The bytes.</returns>
    /// <exception cref="RubyValueException">The value is no String.</exception>
    public ReadOnlyMemory<byte> AsBytes() => As<RubyString>("a String").Bytes;

    /// <summary>
    /// Reads the value as an Array.
    /// </summary>
    /// <returns>The Array.</returns>
    /// <exception cref="RubyValueException">The value is no Array.</exception>
    public RubyArray AsArray() => As<RubyArray>("an Array");

    /// <summary>
    /// Reads the value as a Hash.
    /// </summary>
    /// <returns>The Hash.</returns>
    /// <exception cref="RubyValueException">The value is no Hash.</exception>
    public RubyHash AsHash() => As<RubyHash>("a Hash");

    /// <summary>
    /// Tells whether the value can cross the bridge, and why not.
    /// </summary>
    /// <param name="refusal">Why the value cannot cross, such as "RPG::Item cannot cross the bridge."; <see langword="null"/> when it can.</param>
    /// <returns>Whether the value and everything in it is plain.</returns>
    public bool IsPlain(out string? refusal)
    {
        refusal = FindRefusal(0);
        return refusal is null;
    }

    /// <summary>
    /// Finds the first part of the value that cannot cross the bridge.
    /// </summary>
    /// <param name="depth">The nesting of this value.</param>
    /// <returns>The refusal's message, <see langword="null"/> when everything is plain.</returns>
    internal virtual string? FindRefusal(int depth) => depth > MaxDepth ? RubyValueException.TooDeep : null;

    /// <summary>
    /// Writes the message that refuses a value at the bridge.
    /// </summary>
    /// <param name="what">The value as the message names it, such as "RPG::Item" or "a Regexp".</param>
    /// <returns>Such as "RPG::Item cannot cross the bridge.", starting with a capital letter.</returns>
    internal static string Refusal(string what) => char.ToUpperInvariant(what[0]) + what[1..] + " cannot cross the bridge.";

    /// <summary>
    /// Casts the value to the kind a reader expects.
    /// </summary>
    /// <typeparam name="T">The kind expected.</typeparam>
    /// <param name="expected">The kind expected as a message names it.</param>
    /// <returns>The value as that kind.</returns>
    /// <exception cref="RubyValueException">The value is of another kind.</exception>
    private T As<T>(string expected)
        where T : RubyValue =>
        this as T ?? throw new RubyValueException($"Expected {expected}, found {KindName}.");
}
