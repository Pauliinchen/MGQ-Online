//----------------------------------------------------------------
//  StartingSave.cs
//
//  Changelog:
//      Paulinchen  2026-09-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

namespace MGQParadox.Multiplayer.Network;

/// <summary>
/// A world's starting save as the relay keeps it: the files new players start from, zipped and
/// encrypted with a key from the world's token, so only the world's players can read it.
/// </summary>
internal static partial class StartingSave
{
    /// <summary>
    /// Most files a starting save holds.
    /// </summary>
    public const int MaxFiles = 8;

    /// <summary>
    /// Most bytes its files may have together once unpacked.
    /// </summary>
    public const long MaxUnpackedBytes = 64L * 1024 * 1024;

    /// <summary>
    /// Size of the key.
    /// </summary>
    private const int KeyBytes = 32;

    /// <summary>
    /// Size of the AES-GCM nonce.
    /// </summary>
    private const int NonceBytes = 12;

    /// <summary>
    /// Size of the AES-GCM tag.
    /// </summary>
    private const int TagBytes = 16;

    /// <summary>
    /// Separates the starting save's key from anything else ever derived from the same token.
    /// </summary>
    private static readonly byte[] KeyInfo = "mgqmp world start v1"u8.ToArray();

    /// <summary>
    /// Zips and encrypts files for a world.
    /// </summary>
    /// <param name="token">The world's token.</param>
    /// <param name="files">Each file's name in the starting save, and where it is read from.</param>
    /// <returns>The nonce, the encrypted zip and the tag.</returns>
    /// <exception cref="ArgumentException">A name is no plain file name, or there are too many files.</exception>
    /// <exception cref="IOException">A file could not be read.</exception>
    public static byte[] Seal(string token, IReadOnlyList<(string Name, string Path)> files)
    {
        if (files.Count is 0 or > MaxFiles)
        {
            throw new ArgumentException($"A starting save holds 1 to {MaxFiles} files.", nameof(files));
        }

        using var zipped = new MemoryStream();

        using (var zip = new ZipArchive(zipped, ZipArchiveMode.Create, leaveOpen: true))
        {
            foreach (var (name, path) in files)
            {
                if (!IsPlainName(name))
                {
                    throw new ArgumentException($"{name} is no plain file name.", nameof(files));
                }

                using var entry = zip.CreateEntry(name, CompressionLevel.SmallestSize).Open();
                using var source = File.OpenRead(path);
                source.CopyTo(entry);
            }
        }

        var plain = zipped.ToArray();
        var box = new byte[NonceBytes + plain.Length + TagBytes];
        RandomNumberGenerator.Fill(box.AsSpan(0, NonceBytes));

        using var aes = new AesGcm(KeyOf(token), TagBytes);
        aes.Encrypt(box.AsSpan(0, NonceBytes), plain, box.AsSpan(NonceBytes, plain.Length), box.AsSpan(NonceBytes + plain.Length));
        return box;
    }

    /// <summary>
    /// Decrypts a world's starting save and writes its files into a folder.
    /// </summary>
    /// <param name="token">The world's token.</param>
    /// <param name="box">The starting save as the relay handed it out.</param>
    /// <param name="folder">The folder, made when missing.</param>
    /// <returns>The names of the files written.</returns>
    /// <exception cref="InvalidDataException">The starting save is damaged, not the world's, or unpacks into more than it may.</exception>
    public static IReadOnlyList<string> Open(string token, byte[] box, string folder)
    {
        if (box.Length < NonceBytes + TagBytes)
        {
            throw new InvalidDataException("The starting save is too short.");
        }

        var plain = new byte[box.Length - NonceBytes - TagBytes];

        try
        {
            using var aes = new AesGcm(KeyOf(token), TagBytes);
            aes.Decrypt(box.AsSpan(0, NonceBytes), box.AsSpan(NonceBytes, plain.Length), box.AsSpan(box.Length - TagBytes), plain);
        }
        catch (AuthenticationTagMismatchException)
        {
            throw new InvalidDataException("The starting save is damaged, or belongs to another world.");
        }

        using var zip = new ZipArchive(new MemoryStream(plain), ZipArchiveMode.Read);

        if (zip.Entries.Count is 0 or > MaxFiles)
        {
            throw new InvalidDataException($"The starting save holds {zip.Entries.Count} files.");
        }

        long total = 0;

        foreach (var entry in zip.Entries)
        {
            if (!IsPlainName(entry.FullName))
            {
                throw new InvalidDataException($"The starting save holds {entry.FullName}, which is no plain file name.");
            }

            total += entry.Length;
        }

        if (total > MaxUnpackedBytes)
        {
            throw new InvalidDataException("The starting save unpacks into more than it may.");
        }

        Directory.CreateDirectory(folder);
        var names = new List<string>();

        foreach (var entry in zip.Entries)
        {
            entry.ExtractToFile(Path.Combine(folder, entry.FullName), overwrite: true);
            names.Add(entry.FullName);
        }

        return names;
    }

    /// <summary>
    /// Tells whether a name is a plain file name, which can never reach outside the folder it is written into.
    /// </summary>
    /// <param name="name">The name.</param>
    /// <returns>Whether it is.</returns>
    private static bool IsPlainName(string name) => PlainName().IsMatch(name) && !name.StartsWith('.');

    /// <summary>
    /// Makes the starting save's key from the world's token.
    /// </summary>
    /// <param name="token">The world's token.</param>
    /// <returns>The key.</returns>
    private static byte[] KeyOf(string token) =>
        HKDF.DeriveKey(HashAlgorithmName.SHA256, Encoding.UTF8.GetBytes(token), KeyBytes, info: KeyInfo);

    /// <summary>
    /// Letters, digits, dots, dashes and underscores, at most 64.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex("^[A-Za-z0-9._-]{1,64}$")]
    private static partial Regex PlainName();
}
