//----------------------------------------------------------------
//  ModThumbnails.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Created
//
//----------------------------------------------------------------

using System;
using System.Buffers.Binary;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;

namespace MGQParadox.Multiplayer.Mods;

/// <summary>
/// The card images of the website's mods: downloaded from the website only, taken only as a PNG of
/// a sane size, and kept in a cache folder inside the game's folder for the game script to load.
/// </summary>
internal static class ModThumbnails
{
    /// <summary>
    /// The cache folder, relative to the game's folder.
    /// </summary>
    public const string Folder = @"Patch\Multiplayer\Cache\Mods";

    /// <summary>
    /// The largest image taken.
    /// </summary>
    public const int MaxBytes = 2 * 1024 * 1024;

    /// <summary>
    /// The largest width and height taken, in pixels.
    /// </summary>
    public const int MaxSide = 1024;

    /// <summary>
    /// How many hex digits of the address's hash name a cached image.
    /// </summary>
    private const int NameLength = 16;

    /// <summary>
    /// The bytes every PNG starts with.
    /// </summary>
    private static readonly byte[] PngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

    /// <summary>
    /// Follows no redirect by itself, so each one is checked.
    /// </summary>
    private static readonly HttpClient Http = new(new HttpClientHandler { AllowAutoRedirect = false }) { Timeout = TimeSpan.FromSeconds(30) };

    /// <summary>
    /// Downloads an image.
    /// </summary>
    /// <param name="url">Its address, as the list names it.</param>
    /// <returns>The PNG.</returns>
    /// <exception cref="InvalidOperationException">The address or a redirect breaks the rules, the download failed, or it is no PNG of a sane size.</exception>
    public static byte[] Download(string url) => Download(url, Http);

    /// <summary>
    /// Downloads an image with a client of the caller's.
    /// </summary>
    /// <param name="url">Its address, as the list names it.</param>
    /// <param name="http">The client, which follows no redirect by itself.</param>
    /// <returns>The PNG.</returns>
    /// <exception cref="InvalidOperationException">The address or a redirect breaks the rules, the download failed, or it is no PNG of a sane size.</exception>
    internal static byte[] Download(string url, HttpClient http)
    {
        var bytes = SiteDownload.Fetch(url, "thumbnail", MaxBytes, http);

        if (RefusalOf(bytes) is { } why)
        {
            Log.Write($"thumbnail {url} refused: {why}");
            throw new InvalidOperationException($"The thumbnail {why}.");
        }

        Log.Write($"thumbnail {url} taken, {bytes.Length} bytes");
        return bytes;
    }

    /// <summary>
    /// Names the file an image is cached in.
    /// </summary>
    /// <param name="url">The image's address.</param>
    /// <returns>The path relative to the game's folder, with backslashes.</returns>
    public static string PathOf(string url) =>
        $@"{Folder}\{Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(url)))[..NameLength]}.png";

    /// <summary>
    /// Writes an image into the cache, to a temporary file first, so the game script never loads half of one.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="url">The image's address.</param>
    /// <param name="png">The image.</param>
    /// <returns>The path relative to the game's folder, with backslashes.</returns>
    public static string Store(string gameFolder, string url, byte[] png)
    {
        var path = PathOf(url);
        var full = Path.Combine(gameFolder, path);
        var temporary = full + ".tmp";
        Directory.CreateDirectory(Path.GetDirectoryName(full)!);
        File.WriteAllBytes(temporary, png);
        File.Move(temporary, full, overwrite: true);
        return path;
    }

    /// <summary>
    /// Deletes every file of the cache folder but the images of the addresses named.
    /// </summary>
    /// <param name="gameFolder">The game's folder.</param>
    /// <param name="urls">The addresses of the images to keep.</param>
    public static void Prune(string gameFolder, IEnumerable<string> urls)
    {
        var folder = Path.Combine(gameFolder, Folder);

        if (!Directory.Exists(folder))
        {
            return;
        }

        var kept = urls.Select(url => Path.GetFileName(PathOf(url))).ToHashSet(StringComparer.OrdinalIgnoreCase);

        foreach (var file in Directory.EnumerateFiles(folder).Where(file => !kept.Contains(Path.GetFileName(file))).ToList())
        {
            try
            {
                File.Delete(file);
                Log.Write($"thumbnail cache: deleted {Path.GetFileName(file)}, which no mod of the list shows");
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                Log.Write($"thumbnail cache: {Path.GetFileName(file)} could not be deleted: {ex.Message}");
            }
        }
    }

    /// <summary>
    /// Tells why a file is no image the game takes.
    /// </summary>
    /// <param name="bytes">The file.</param>
    /// <returns>Why not, ending without a period; <see langword="null"/> for a PNG of a sane size.</returns>
    internal static string? RefusalOf(byte[] bytes)
    {
        // A PNG's first chunk is IHDR: its length 13, its type, then the width and the height.
        if (bytes.Length < 24 || !bytes.AsSpan(0, PngSignature.Length).SequenceEqual(PngSignature) || !bytes.AsSpan(12, 4).SequenceEqual("IHDR"u8))
        {
            return "is no PNG";
        }

        var width = BinaryPrimitives.ReadUInt32BigEndian(bytes.AsSpan(16, 4));
        var height = BinaryPrimitives.ReadUInt32BigEndian(bytes.AsSpan(20, 4));
        return width is 0 or > MaxSide || height is 0 or > MaxSide ? $"is {width}x{height} pixels, not between 1x1 and {MaxSide}x{MaxSide}" : null;
    }
}
