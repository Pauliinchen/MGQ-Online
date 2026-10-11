//----------------------------------------------------------------
//  Png.cs
//
//  Changelog:
//      Paulinchen  2026-10-11: Created
//
//----------------------------------------------------------------

using System;
using System.Buffers.Binary;
using System.IO;
using System.IO.Compression;
using System.Text;

namespace MGQParadox.Multiplayer.Reports;

/// <summary>
/// Encodes a screenshot as the game keeps it into an 8-bit RGB PNG.
/// </summary>
internal static class Png
{
    /// <summary>
    /// The eight bytes every PNG starts with.
    /// </summary>
    public static ReadOnlySpan<byte> Signature => [0x89, (byte)'P', (byte)'N', (byte)'G', 0x0D, 0x0A, 0x1A, 0x0A];

    /// <summary>
    /// Bytes per pixel of the screenshot handed in: B, G, R and A.
    /// </summary>
    public const int SourcePixelBytes = 4;

    /// <summary>
    /// Bytes per pixel of the PNG: R, G and B.
    /// </summary>
    private const int PixelBytes = 3;

    /// <summary>
    /// The PNG color type of RGB without alpha.
    /// </summary>
    private const byte ColorTypeRgb = 2;

    /// <summary>
    /// The filter byte in front of every row: none.
    /// </summary>
    private const byte NoFilter = 0;

    /// <summary>
    /// The CRC-32 of every byte value, by the polynomial PNG and zip use.
    /// </summary>
    private static readonly uint[] CrcTable = BuildCrcTable();

    /// <summary>
    /// Encodes a screenshot.
    /// </summary>
    /// <param name="pixels">The pixels, <paramref name="width"/> times <paramref name="height"/> times B, G, R, A, the last row first.</param>
    /// <param name="width">The width in pixels.</param>
    /// <param name="height">The height in pixels.</param>
    /// <returns>The PNG, top row first, alpha dropped.</returns>
    /// <exception cref="ArgumentException">The pixels do not match the size.</exception>
    public static byte[] Encode(ReadOnlySpan<byte> pixels, int width, int height)
    {
        if (width <= 0 || height <= 0 || pixels.Length != (long)width * height * SourcePixelBytes)
        {
            throw new ArgumentException($"{pixels.Length} bytes are no {width} x {height} screenshot.", nameof(pixels));
        }

        using var png = new MemoryStream();
        png.Write(Signature);

        var header = new byte[13];
        BinaryPrimitives.WriteInt32BigEndian(header, width);
        BinaryPrimitives.WriteInt32BigEndian(header.AsSpan(4), height);
        header[8] = 8;
        header[9] = ColorTypeRgb;
        WriteChunk(png, "IHDR", header);
        WriteChunk(png, "IDAT", Compress(Rows(pixels, width, height)));
        WriteChunk(png, "IEND", []);
        return png.ToArray();
    }

    /// <summary>
    /// Computes the CRC-32 that PNG chunks and zip entries carry.
    /// </summary>
    /// <param name="bytes">The bytes.</param>
    /// <returns>The checksum.</returns>
    public static uint Crc32(ReadOnlySpan<byte> bytes)
    {
        var crc = 0xFFFFFFFFu;

        foreach (var value in bytes)
        {
            crc = CrcTable[(crc ^ value) & 0xFF] ^ (crc >> 8);
        }

        return crc ^ 0xFFFFFFFFu;
    }

    /// <summary>
    /// Lays the pixels out as PNG rows: the top row first, each behind its filter byte, R, G, B per pixel.
    /// </summary>
    /// <param name="pixels">The pixels, B, G, R, A, the last row first.</param>
    /// <param name="width">The width in pixels.</param>
    /// <param name="height">The height in pixels.</param>
    /// <returns>The rows.</returns>
    private static byte[] Rows(ReadOnlySpan<byte> pixels, int width, int height)
    {
        var stride = 1 + (width * PixelBytes);
        var rows = new byte[stride * height];

        for (var y = 0; y < height; y++)
        {
            var source = pixels.Slice((height - 1 - y) * width * SourcePixelBytes, width * SourcePixelBytes);
            var target = rows.AsSpan(y * stride, stride);
            target[0] = NoFilter;

            for (var x = 0; x < width; x++)
            {
                target[1 + (x * PixelBytes)] = source[(x * SourcePixelBytes) + 2];
                target[2 + (x * PixelBytes)] = source[(x * SourcePixelBytes) + 1];
                target[3 + (x * PixelBytes)] = source[x * SourcePixelBytes];
            }
        }

        return rows;
    }

    /// <summary>
    /// Compresses the rows into the zlib stream an IDAT chunk holds.
    /// </summary>
    /// <param name="rows">The rows.</param>
    /// <returns>The zlib stream.</returns>
    private static byte[] Compress(byte[] rows)
    {
        using var compressed = new MemoryStream();

        using (var zlib = new ZLibStream(compressed, CompressionLevel.Optimal, leaveOpen: true))
        {
            zlib.Write(rows);
        }

        return compressed.ToArray();
    }

    /// <summary>
    /// Writes a chunk: its length, type, data and the CRC-32 of type and data.
    /// </summary>
    /// <param name="png">The PNG so far.</param>
    /// <param name="type">The chunk's four-letter type.</param>
    /// <param name="data">The chunk's data.</param>
    private static void WriteChunk(Stream png, string type, byte[] data)
    {
        var chunk = new byte[4 + data.Length];
        Encoding.ASCII.GetBytes(type, chunk);
        data.CopyTo(chunk, 4);

        Span<byte> number = stackalloc byte[4];
        BinaryPrimitives.WriteInt32BigEndian(number, data.Length);
        png.Write(number);
        png.Write(chunk);
        BinaryPrimitives.WriteUInt32BigEndian(number, Crc32(chunk));
        png.Write(number);
    }

    /// <summary>
    /// Builds <see cref="CrcTable"/>.
    /// </summary>
    /// <returns>The CRC-32 of every byte value.</returns>
    private static uint[] BuildCrcTable()
    {
        var table = new uint[256];

        for (var n = 0u; n < table.Length; n++)
        {
            var crc = n;

            for (var bit = 0; bit < 8; bit++)
            {
                crc = (crc & 1) != 0 ? 0xEDB88320u ^ (crc >> 1) : crc >> 1;
            }

            table[n] = crc;
        }

        return table;
    }
}
