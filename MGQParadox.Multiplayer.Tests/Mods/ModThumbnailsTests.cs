//----------------------------------------------------------------
//  ModThumbnailsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Created
//
//----------------------------------------------------------------

using System;
using System.Buffers.Binary;
using System.Net;
using System.Net.Http;
using MGQParadox.Multiplayer.Mods;

namespace MGQParadox.Multiplayer.Tests.Mods;

/// <summary>
/// Covers the card images of the website's mods: only a PNG of a sane size is taken.
/// </summary>
public sealed class ModThumbnailsTests
{
    /// <summary>
    /// A card image's address as the list names it.
    /// </summary>
    private const string ImageUrl = "https://mgqonline.org/mods/level-cap/images/1/card.png";

    /// <summary>
    /// Asserts that a PNG of a sane size is taken, and a GIF or a PNG larger than the game takes is refused.
    /// </summary>
    [Fact]
    public void Download_TakesOnlyAPngOfASaneSize()
    {
        var png = Png(400, 225);
        var gif = "GIF89a............................"u8.ToArray();
        var huge = Png(4000, 225);

        Assert.Equal(png, ModThumbnails.Download(ImageUrl, Serving(png).Client()));
        Assert.Contains("no PNG", Assert.Throws<InvalidOperationException>(() => ModThumbnails.Download(ImageUrl, Serving(gif).Client())).Message);
        Assert.Contains("4000x225", Assert.Throws<InvalidOperationException>(() => ModThumbnails.Download(ImageUrl, Serving(huge).Client())).Message);
    }

    /// <summary>
    /// Makes the start of a PNG: its signature and its IHDR chunk.
    /// </summary>
    /// <param name="width">Its width in pixels.</param>
    /// <param name="height">Its height in pixels.</param>
    /// <returns>The bytes.</returns>
    internal static byte[] Png(int width, int height)
    {
        byte[] png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, .. "IHDR"u8, 0, 0, 0, 0, 0, 0, 0, 0, 8, 6, 0, 0, 0, 0, 0, 0, 0];
        BinaryPrimitives.WriteInt32BigEndian(png.AsSpan(16), width);
        BinaryPrimitives.WriteInt32BigEndian(png.AsSpan(20), height);
        return png;
    }

    /// <summary>
    /// Makes a website that serves a file at the image's address.
    /// </summary>
    /// <param name="bytes">The file.</param>
    /// <returns>The website.</returns>
    private static FakeWebsite Serving(byte[] bytes) => new() { [ImageUrl] = () => new HttpResponseMessage(HttpStatusCode.OK) { Content = new ByteArrayContent(bytes) } };
}
