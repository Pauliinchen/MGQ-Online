//----------------------------------------------------------------
//  RubyMarshal.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Buffers;

namespace MGQOnline.Bridge.Ruby;

/// <summary>
/// What a Marshal read takes.
/// </summary>
public enum MarshalMode
{
    /// <summary>
    /// Plain values only, as they cross the bridge; anything else is refused by name.
    /// </summary>
    Strict,

    /// <summary>
    /// Everything game data holds: objects, symbols, floats, and dumped classes such as Table as
    /// their bytes.
    /// </summary>
    Full,
}

/// <summary>
/// Reads and writes Ruby's Marshal format, version 4.8, which RGSS3's Ruby 1.9.2 and Ruby 3.3 both
/// write.
/// </summary>
public static class RubyMarshal
{
    /// <summary>
    /// The major version every Marshal dump starts with.
    /// </summary>
    internal const byte MajorVersion = 4;

    /// <summary>
    /// The minor version every Marshal dump starts with.
    /// </summary>
    internal const byte MinorVersion = 8;

    /// <summary>
    /// Reads one value.
    /// </summary>
    /// <param name="data">The Marshal dump, nothing after its value.</param>
    /// <param name="mode">Whether only plain values are taken.</param>
    /// <returns>The value.</returns>
    /// <exception cref="RubyValueException">The data is broken, or holds a value the mode refuses.</exception>
    public static RubyValue Read(ReadOnlySpan<byte> data, MarshalMode mode = MarshalMode.Strict)
    {
        var reader = new MarshalReader(data, mode == MarshalMode.Strict);
        return reader.ReadDump();
    }

    /// <summary>
    /// Writes a plain value.
    /// </summary>
    /// <param name="value">The value: nil, true, false, Integer, String, Array or Hash with String or Integer keys.</param>
    /// <returns>The Marshal dump.</returns>
    /// <exception cref="RubyValueException">The value holds something that cannot cross the bridge.</exception>
    public static byte[] Write(RubyValue value)
    {
        ArrayBufferWriter<byte> output = new();
        Write(value, output);
        return output.WrittenSpan.ToArray();
    }

    /// <summary>
    /// Writes a plain value into a buffer.
    /// </summary>
    /// <param name="value">The value: nil, true, false, Integer, String, Array or Hash with String or Integer keys.</param>
    /// <param name="output">Takes the Marshal dump.</param>
    /// <exception cref="RubyValueException">The value holds something that cannot cross the bridge; part of it may be written.</exception>
    public static void Write(RubyValue value, IBufferWriter<byte> output)
    {
        ArgumentNullException.ThrowIfNull(value);
        ArgumentNullException.ThrowIfNull(output);
        new MarshalWriter(output).WriteDump(value);
    }
}
