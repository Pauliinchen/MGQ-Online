//----------------------------------------------------------------
//  MarshalWriter.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Wrote Integer Hash keys
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Buffers;
using System.Collections.Generic;
using System.Numerics;

namespace MGQOnline.Bridge.Ruby;

/// <summary>
/// Writes one plain value as a Marshal 4.8 dump, the way Ruby 3.3 on Windows writes it.
/// </summary>
/// <remarks>
/// A Hash key that repeats an earlier key is written as a link to it, since Ruby 3.3 interns String
/// keys and links them the same way; values are never linked.
/// </remarks>
internal sealed class MarshalWriter
{
    /// <summary>
    /// The smallest number written as a Fixnum, the smallest Fixnum of RGSS3's 32-bit Ruby 1.9.2.
    /// </summary>
    public const long FixnumMin = -(1L << 30);

    /// <summary>
    /// The largest number written as a Fixnum, the largest Fixnum of RGSS3's 32-bit Ruby 1.9.2.
    /// </summary>
    public const long FixnumMax = (1L << 30) - 1;

    /// <summary>
    /// The instance variable that marks a String as UTF-8 (true) or US-ASCII (false).
    /// </summary>
    private const string EncodingFlag = "E";

    /// <summary>
    /// The buffer the dump goes into.
    /// </summary>
    private readonly IBufferWriter<byte> _output;

    /// <summary>
    /// The symbols written so far by name, with their places in the symbol table.
    /// </summary>
    private readonly Dictionary<string, int> _symbols = new(StringComparer.Ordinal);

    /// <summary>
    /// The Hash keys written so far, with their places in the object table.
    /// </summary>
    private readonly Dictionary<RubyString, int> _keys = new(SameMarkedBytes.Instance);

    /// <summary>
    /// The objects written so far, which is the place the next one takes.
    /// </summary>
    private int _objects;

    /// <summary>
    /// The nesting of the value being written.
    /// </summary>
    private int _depth;

    /// <summary>
    /// Starts writing.
    /// </summary>
    /// <param name="output">The buffer the dump goes into.</param>
    public MarshalWriter(IBufferWriter<byte> output)
    {
        _output = output;
    }

    /// <summary>
    /// Writes the version and the value.
    /// </summary>
    /// <param name="value">The value.</param>
    public void WriteDump(RubyValue value)
    {
        WriteByte(RubyMarshal.MajorVersion);
        WriteByte(RubyMarshal.MinorVersion);
        WriteValue(value);
    }

    /// <summary>
    /// Writes the next value, one level deeper.
    /// </summary>
    /// <param name="value">The value.</param>
    private void WriteValue(RubyValue value)
    {
        if (++_depth > RubyValue.MaxDepth)
        {
            throw new RubyValueException(RubyValueException.TooDeep);
        }

        switch (value)
        {
            case RubyNil:
                WriteByte((byte)'0');
                break;
            case RubyBool flag:
                WriteByte((byte)(flag.Flag ? 'T' : 'F'));
                break;
            case RubyInteger number:
                WriteInteger(number.Value);
                break;
            case RubyString text:
                WriteString(text);
                break;
            case RubyArray array:
                WriteArray(array);
                break;
            case RubyHash hash:
                WriteHash(hash);
                break;
            default:
                throw new RubyValueException(value.FindRefusal(_depth) ?? RubyValue.Refusal(value.KindName));
        }

        _depth--;
    }

    /// <summary>
    /// Writes a whole number: a Fixnum where the 32-bit Ruby holds one, else a Bignum.
    /// </summary>
    /// <param name="number">The number.</param>
    private void WriteInteger(BigInteger number)
    {
        if (number >= FixnumMin && number <= FixnumMax)
        {
            WriteByte((byte)'i');
            WriteLong((long)number);
            return;
        }

        _objects++;
        WriteByte((byte)'l');
        WriteByte((byte)(number.Sign < 0 ? '-' : '+'));
        byte[] magnitude = BigInteger.Abs(number).ToByteArray(isUnsigned: true, isBigEndian: false);
        int shorts = (magnitude.Length + 1) / 2;
        WriteLong(shorts);
        WriteRaw(magnitude);
        if (magnitude.Length % 2 == 1)
        {
            WriteByte(0);
        }
    }

    /// <summary>
    /// Writes a String with its encoding as Ruby marks it.
    /// </summary>
    /// <param name="text">The string.</param>
    private void WriteString(RubyString text)
    {
        if (text.Encoding == RubyEncoding.Other)
        {
            throw new RubyValueException(RubyValue.Refusal(text.KindName));
        }

        _objects++;
        if (text.Encoding == RubyEncoding.Binary)
        {
            WriteByte((byte)'"');
            WriteBytes(text.Bytes.Span);
            return;
        }

        WriteByte((byte)'I');
        WriteByte((byte)'"');
        WriteBytes(text.Bytes.Span);
        WriteLong(1);
        WriteSymbol(EncodingFlag);
        WriteByte((byte)(text.Encoding == RubyEncoding.Utf8 ? 'T' : 'F'));
    }

    /// <summary>
    /// Writes an Array.
    /// </summary>
    /// <param name="array">The Array.</param>
    private void WriteArray(RubyArray array)
    {
        _objects++;
        WriteByte((byte)'[');
        WriteLong(array.Count);
        foreach (RubyValue item in array)
        {
            WriteValue(item);
        }
    }

    /// <summary>
    /// Writes a Hash with String or Integer keys.
    /// </summary>
    /// <param name="hash">The Hash.</param>
    private void WriteHash(RubyHash hash)
    {
        if (hash.Default is not null)
        {
            throw new RubyValueException(RubyValue.Refusal("a Hash with a default value"));
        }

        _objects++;
        WriteByte((byte)'{');
        WriteLong(hash.Count);
        foreach ((RubyValue key, RubyValue value) in hash)
        {
            switch (key)
            {
                case RubyString text:
                    WriteKey(text);
                    break;
                case RubyInteger number:
                    WriteInteger(number.Value);
                    break;
                default:
                    throw new RubyValueException(RubyValue.Refusal(key.KindName + " as a Hash key"));
            }

            WriteValue(value);
        }
    }

    /// <summary>
    /// Writes a String Hash key: a link to an earlier key of the same bytes and encoding, else the key itself.
    /// </summary>
    /// <param name="key">The key.</param>
    private void WriteKey(RubyString key)
    {
        if (_keys.TryGetValue(key, out int place))
        {
            WriteByte((byte)'@');
            WriteLong(place);
            return;
        }

        _keys[key] = _objects;
        WriteString(key);
    }

    /// <summary>
    /// Writes a symbol: its name the first time, a link to it after.
    /// </summary>
    /// <param name="name">The symbol's name, ASCII.</param>
    private void WriteSymbol(string name)
    {
        if (_symbols.TryGetValue(name, out int place))
        {
            WriteByte((byte)';');
            WriteLong(place);
            return;
        }

        _symbols[name] = _symbols.Count;
        WriteByte((byte)':');
        WriteBytes(System.Text.Encoding.ASCII.GetBytes(name));
    }

    /// <summary>
    /// Writes a length and the bytes.
    /// </summary>
    /// <param name="bytes">The bytes.</param>
    private void WriteBytes(ReadOnlySpan<byte> bytes)
    {
        WriteLong(bytes.Length);
        WriteRaw(bytes);
    }

    /// <summary>
    /// Writes a packed integer as Ruby's w_long does.
    /// </summary>
    /// <param name="number">The number, within 32 bits.</param>
    private void WriteLong(long number)
    {
        if (number == 0)
        {
            WriteByte(0);
            return;
        }

        if (number is > 0 and < 123)
        {
            WriteByte((byte)(number + 5));
            return;
        }

        if (number is > -124 and < 0)
        {
            WriteByte((byte)((number - 5) & 0xFF));
            return;
        }

        Span<byte> buffer = stackalloc byte[9];
        long rest = number;
        for (int index = 1; index < buffer.Length; index++)
        {
            buffer[index] = (byte)(rest & 0xFF);
            rest >>= 8;
            if (rest == 0 || rest == -1)
            {
                buffer[0] = (byte)(rest == 0 ? index : -index);
                WriteRaw(buffer[..(index + 1)]);
                return;
            }
        }
    }

    /// <summary>
    /// Writes one byte.
    /// </summary>
    /// <param name="value">The byte.</param>
    private void WriteByte(byte value)
    {
        _output.GetSpan(1)[0] = value;
        _output.Advance(1);
    }

    /// <summary>
    /// Writes bytes as they are.
    /// </summary>
    /// <param name="bytes">The bytes.</param>
    private void WriteRaw(ReadOnlySpan<byte> bytes)
    {
        bytes.CopyTo(_output.GetSpan(bytes.Length));
        _output.Advance(bytes.Length);
    }

    /// <summary>
    /// Compares Hash keys by their bytes and encoding, as Ruby 3.3 interns them.
    /// </summary>
    private sealed class SameMarkedBytes : IEqualityComparer<RubyString>
    {
        /// <summary>
        /// The one comparer; it holds no state.
        /// </summary>
        public static readonly SameMarkedBytes Instance = new();

        /// <inheritdoc />
        public bool Equals(RubyString? x, RubyString? y) =>
            x is not null && y is not null && x.Encoding == y.Encoding && x.Bytes.Span.SequenceEqual(y.Bytes.Span);

        /// <inheritdoc />
        public int GetHashCode(RubyString obj) => obj.GetHashCode();
    }
}
