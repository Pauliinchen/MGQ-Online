//----------------------------------------------------------------
//  Rgss3aArchive.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Buffers.Binary;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace MGQOnline.Game.Events.Data;

/// <summary>
/// The files of an RGSS3 archive (Game.rgss3a), in which the untranslated game keeps its data.
/// </summary>
public sealed class Rgss3aArchive
{
    /// <summary>
    /// The bytes every RGSS archive starts with, followed by its version.
    /// </summary>
    private static readonly byte[] Magic = "RGSSAD\0"u8.ToArray();

    /// <summary>
    /// The archive version of RGSS3.
    /// </summary>
    private const byte Version = 3;

    /// <summary>
    /// The longest file name the archive's list may hold.
    /// </summary>
    private const int MaxNameLength = 1024;

    /// <summary>
    /// The most files the archive's list may hold.
    /// </summary>
    private const int MaxEntries = 500_000;

    /// <summary>
    /// The archive's file on disk.
    /// </summary>
    private readonly string _path;

    /// <summary>
    /// The archive's files by their path, with forward slashes, ignoring case as Windows does.
    /// </summary>
    private readonly Dictionary<string, Entry> _entries;

    /// <summary>
    /// Keeps an archive's file list.
    /// </summary>
    /// <param name="path">The archive's file.</param>
    /// <param name="entries">Its files.</param>
    private Rgss3aArchive(string path, Dictionary<string, Entry> entries)
    {
        _path = path;
        _entries = entries;
    }

    /// <summary>
    /// Opens an archive and reads its file list.
    /// </summary>
    /// <param name="path">The archive's file.</param>
    /// <returns>The archive.</returns>
    /// <exception cref="InvalidDataException">The file is no RGSS3 archive, or its list is damaged.</exception>
    public static Rgss3aArchive Open(string path)
    {
        using FileStream stream = File.OpenRead(path);
        using var reader = new BinaryReader(stream);
        byte[] header = reader.ReadBytes(Magic.Length + 1);
        if (header.Length != Magic.Length + 1 || !header.AsSpan(0, Magic.Length).SequenceEqual(Magic) || header[^1] != Version)
        {
            throw new InvalidDataException($"{path} is no RGSS3 archive.");
        }

        uint key = unchecked((reader.ReadUInt32() * 9) + 3);
        var entries = new Dictionary<string, Entry>(StringComparer.OrdinalIgnoreCase);
        while (true)
        {
            uint offset = reader.ReadUInt32() ^ key;
            if (offset == 0)
            {
                break;
            }

            uint size = reader.ReadUInt32() ^ key;
            uint fileKey = reader.ReadUInt32() ^ key;
            uint nameLength = reader.ReadUInt32() ^ key;
            if (nameLength is 0 or > MaxNameLength || offset + (long)size > stream.Length || entries.Count >= MaxEntries)
            {
                throw new InvalidDataException($"The file list of {path} is damaged.");
            }

            byte[] name = reader.ReadBytes((int)nameLength);
            for (int index = 0; index < name.Length; index++)
            {
                name[index] ^= (byte)(key >> (8 * (index % 4)));
            }

            entries[Normalize(Encoding.UTF8.GetString(name))] = new Entry(offset, (int)size, fileKey);
        }

        return new Rgss3aArchive(path, entries);
    }

    /// <summary>
    /// Tells whether the archive holds a file.
    /// </summary>
    /// <param name="path">The file's path in the game folder, such as "Data/System.rvdata2".</param>
    /// <returns>Whether it does.</returns>
    public bool Contains(string path) => _entries.ContainsKey(Normalize(path));

    /// <summary>
    /// Reads a file of the archive whole.
    /// </summary>
    /// <param name="path">The file's path in the game folder.</param>
    /// <returns>Its bytes.</returns>
    /// <exception cref="FileNotFoundException">The archive does not hold it.</exception>
    /// <exception cref="InvalidDataException">The archive ends inside it.</exception>
    public byte[] Read(string path)
    {
        if (!_entries.TryGetValue(Normalize(path), out Entry entry))
        {
            throw new FileNotFoundException($"{_path} holds no {path}.", path);
        }

        byte[] data = new byte[entry.Size];
        using (FileStream stream = File.OpenRead(_path))
        {
            stream.Position = entry.Offset;
            stream.ReadExactly(data);
        }

        Decrypt(data, entry.Key);
        return data;
    }

    /// <summary>
    /// Takes a file's bytes out of the archive's cipher: each 4 bytes are XORed with a key that
    /// moves on as <c>key * 7 + 3</c>.
    /// </summary>
    /// <param name="data">The bytes, changed in place.</param>
    /// <param name="key">The file's key.</param>
    private static void Decrypt(Span<byte> data, uint key)
    {
        int whole = data.Length & ~3;
        for (int index = 0; index < whole; index += 4)
        {
            Span<byte> word = data.Slice(index, 4);
            BinaryPrimitives.WriteUInt32LittleEndian(word, BinaryPrimitives.ReadUInt32LittleEndian(word) ^ key);
            key = unchecked((key * 7) + 3);
        }

        for (int index = whole; index < data.Length; index++)
        {
            data[index] ^= (byte)(key >> (8 * (index - whole)));
        }
    }

    /// <summary>
    /// Writes a path as the archive's list is keyed: forward slashes, no leading slash.
    /// </summary>
    /// <param name="path">The path.</param>
    /// <returns>The key.</returns>
    private static string Normalize(string path) => path.Replace('\\', '/').TrimStart('/');

    /// <summary>
    /// Where a file lies in the archive.
    /// </summary>
    /// <param name="Offset">Its first byte.</param>
    /// <param name="Size">Its bytes.</param>
    /// <param name="Key">The key its cipher starts with.</param>
    private readonly record struct Entry(long Offset, int Size, uint Key);
}
