//----------------------------------------------------------------
//  PngTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-11: Created
//
//----------------------------------------------------------------

using System;
using System.Buffers.Binary;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Text;
using MGQParadox.Multiplayer.Reports;

namespace MGQParadox.Multiplayer.Tests.Reports;

/// <summary>
/// Covers the PNG a bug report's screenshot is encoded into, read back chunk by chunk.
/// </summary>
public sealed class PngTests
{
    /// <summary>
    /// Asserts that the checksum is the standard CRC-32, by its check value and the IEND chunk's well-known one.
    /// </summary>
    [Fact]
    public void Crc32_MatchesTheStandardCheckValues()
    {
        Assert.Equal(0xCBF43926u, Png.Crc32("123456789"u8));
        Assert.Equal(0xAE426082u, Png.Crc32("IEND"u8));
        Assert.Equal(0u, Png.Crc32([]));
    }

    /// <summary>
    /// Asserts that a screenshot becomes a PNG of the signature, an 8-bit RGB IHDR, IDAT and IEND,
    /// every chunk with its CRC, whose rows are the pixels top row first, R, G, B, alpha dropped.
    /// </summary>
    [Fact]
    public void Encode_WritesAnRgbPngTopRowFirst()
    {
        const int width = 3;
        const int height = 2;

        // As the game keeps a bitmap: the bottom row first, each pixel B, G, R, A.
        byte[] pixels =
        [
            1, 2, 3, 255, 4, 5, 6, 0, 7, 8, 9, 128,
            10, 11, 12, 255, 13, 14, 15, 0, 16, 17, 18, 64,
        ];

        var png = Png.Encode(pixels, width, height);
        var chunks = Chunks(png);

        Assert.Equal(["IHDR", "IDAT", "IEND"], chunks.ConvertAll(chunk => chunk.Type));

        var header = chunks[0].Data;
        Assert.Equal(13, header.Length);
        Assert.Equal(width, BinaryPrimitives.ReadInt32BigEndian(header));
        Assert.Equal(height, BinaryPrimitives.ReadInt32BigEndian(header.AsSpan(4)));
        Assert.Equal([8, 2, 0, 0, 0], header[8..]);
        Assert.Empty(chunks[2].Data);

        byte[] rows =
        [
            0, 12, 11, 10, 15, 14, 13, 18, 17, 16,
            0, 3, 2, 1, 6, 5, 4, 9, 8, 7,
        ];
        Assert.Equal(rows, Inflate(chunks[1].Data));
    }

    /// <summary>
    /// Asserts that a screen-sized screenshot reads back pixel for pixel.
    /// </summary>
    [Fact]
    public void Encode_LargerScreenshot_ReadsBackPixelForPixel()
    {
        const int width = 544;
        const int height = 416;
        var pixels = new byte[width * height * 4];
        new Random(5).NextBytes(pixels);

        var rows = Inflate(Chunks(Png.Encode(pixels, width, height))[1].Data);

        Assert.Equal(height * (1 + (width * 3)), rows.Length);

        for (var y = 0; y < height; y += 37)
        {
            for (var x = 0; x < width; x += 13)
            {
                var source = (((height - 1 - y) * width) + x) * 4;
                var target = (y * (1 + (width * 3))) + 1 + (x * 3);
                Assert.Equal((pixels[source + 2], pixels[source + 1], pixels[source]), (rows[target], rows[target + 1], rows[target + 2]));
            }
        }
    }

    /// <summary>
    /// Asserts that pixels that do not match the size are refused.
    /// </summary>
    [Fact]
    public void Encode_PixelsOfAnotherSize_Throws()
    {
        Assert.Throws<ArgumentException>(() => Png.Encode(new byte[15], 2, 2));
        Assert.Throws<ArgumentException>(() => Png.Encode([], 0, 0));
    }

    /// <summary>
    /// Reads a PNG's chunks, asserting its signature and each chunk's CRC.
    /// </summary>
    /// <param name="png">The PNG.</param>
    /// <returns>Each chunk's type and data, in order.</returns>
    private static List<(string Type, byte[] Data)> Chunks(byte[] png)
    {
        Assert.Equal(Png.Signature.ToArray(), png[..8]);

        var chunks = new List<(string Type, byte[] Data)>();
        var at = 8;

        while (at < png.Length)
        {
            var length = BinaryPrimitives.ReadInt32BigEndian(png.AsSpan(at));
            var typeAndData = png.AsSpan(at + 4, 4 + length);
            Assert.Equal(Png.Crc32(typeAndData), BinaryPrimitives.ReadUInt32BigEndian(png.AsSpan(at + 8 + length)));
            chunks.Add((Encoding.ASCII.GetString(typeAndData[..4]), typeAndData[4..].ToArray()));
            at += 12 + length;
        }

        Assert.Equal(png.Length, at);
        return chunks;
    }

    /// <summary>
    /// Inflates an IDAT chunk's zlib stream.
    /// </summary>
    /// <param name="data">The chunk's data.</param>
    /// <returns>The rows.</returns>
    private static byte[] Inflate(byte[] data)
    {
        using var zlib = new ZLibStream(new MemoryStream(data), CompressionMode.Decompress);
        using var rows = new MemoryStream();
        zlib.CopyTo(rows);
        return rows.ToArray();
    }
}
