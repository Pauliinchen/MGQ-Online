//----------------------------------------------------------------
//  RubyString.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Text;

namespace MGQOnline.Bridge.Ruby;

/// <summary>
/// The encoding a Ruby String is marked with, which Marshal keeps in its instance variables.
/// </summary>
public enum RubyEncoding
{
    /// <summary>
    /// ASCII-8BIT: bytes, not text; Marshal writes no instance variable.
    /// </summary>
    Binary,

    /// <summary>
    /// UTF-8, the "E" instance variable set to true.
    /// </summary>
    Utf8,

    /// <summary>
    /// US-ASCII, the "E" instance variable set to false, which Ruby gives such as Integer#to_s.
    /// </summary>
    UsAscii,

    /// <summary>
    /// Another encoding named by the "encoding" instance variable, such as Shift_JIS; read from game
    /// data only.
    /// </summary>
    Other,
}

/// <summary>
/// A Ruby String: its bytes and the encoding it is marked with.
/// </summary>
public sealed class RubyString : RubyValue
{
    /// <summary>
    /// The string's bytes, never changed after creation.
    /// </summary>
    private readonly byte[] _bytes;

    /// <summary>
    /// Creates a string.
    /// </summary>
    /// <param name="bytes">The bytes, kept as they are.</param>
    /// <param name="encoding">The encoding.</param>
    /// <param name="encodingName">The encoding's name for <see cref="RubyEncoding.Other"/>.</param>
    internal RubyString(byte[] bytes, RubyEncoding encoding, string? encodingName = null)
    {
        _bytes = bytes;
        Encoding = encoding;
        EncodingName = encodingName ?? encoding switch
        {
            RubyEncoding.Binary => "ASCII-8BIT",
            RubyEncoding.Utf8 => "UTF-8",
            RubyEncoding.UsAscii => "US-ASCII",
            _ => "?",
        };
    }

    /// <summary>
    /// Gets the encoding the string is marked with.
    /// </summary>
    public RubyEncoding Encoding { get; }

    /// <summary>
    /// Gets the encoding's name as Ruby calls it, such as "UTF-8" or "ASCII-8BIT".
    /// </summary>
    public string EncodingName { get; }

    /// <summary>
    /// Gets the string's bytes.
    /// </summary>
    public ReadOnlyMemory<byte> Bytes => _bytes;

    /// <summary>
    /// Gets the bytes read as UTF-8.
    /// </summary>
    public string Text => System.Text.Encoding.UTF8.GetString(_bytes);

    /// <inheritdoc />
    public override string KindName => Encoding switch
    {
        RubyEncoding.Binary => "a binary String",
        RubyEncoding.Other => "a String in " + EncodingName,
        _ => "a String",
    };

    /// <summary>
    /// Creates a UTF-8 string.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The string.</returns>
    public static RubyString Utf8(string text) => new(System.Text.Encoding.UTF8.GetBytes(text), RubyEncoding.Utf8);

    /// <summary>
    /// Creates a binary string.
    /// </summary>
    /// <param name="bytes">The bytes, copied.</param>
    /// <returns>The string.</returns>
    public static RubyString Binary(ReadOnlySpan<byte> bytes) => new(bytes.ToArray(), RubyEncoding.Binary);

    /// <summary>
    /// Makes the same bytes marked with another encoding.
    /// </summary>
    /// <param name="encoding">The encoding.</param>
    /// <param name="encodingName">The encoding's name for <see cref="RubyEncoding.Other"/>.</param>
    /// <returns>The marked string, sharing the bytes.</returns>
    internal RubyString Marked(RubyEncoding encoding, string? encodingName) => new(_bytes, encoding, encodingName);

    /// <summary>
    /// Compares as Ruby's eql? does: the same bytes, and the same encoding unless all of them are ASCII.
    /// </summary>
    /// <param name="obj">The other value.</param>
    /// <returns>Whether both are the same string.</returns>
    public override bool Equals(object? obj) =>
        obj is RubyString other
        && _bytes.AsSpan().SequenceEqual(other._bytes)
        && ((other.Encoding == Encoding && other.EncodingName == EncodingName) || Ascii.IsValid(_bytes));

    /// <inheritdoc />
    public override int GetHashCode()
    {
        HashCode hash = default;
        hash.AddBytes(_bytes);
        return hash.ToHashCode();
    }

    /// <inheritdoc />
    public override string ToString()
    {
        if (Encoding == RubyEncoding.Binary)
        {
            return $"<{_bytes.Length} bytes>";
        }

        StringBuilder text = new("\"");
        foreach (char c in Text)
        {
            text.Append(c switch
            {
                '"' => "\\\"",
                '\\' => "\\\\",
                '\n' => "\\n",
                < ' ' => $"\\x{(int)c:X2}",
                _ => c.ToString(),
            });
        }

        return text.Append('"').ToString();
    }

    /// <inheritdoc />
    internal override string? FindRefusal(int depth) =>
        Encoding == RubyEncoding.Other ? Refusal(KindName) : base.FindRefusal(depth);
}
