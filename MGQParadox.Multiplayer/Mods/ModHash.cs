//----------------------------------------------------------------
//  ModHash.cs
//
//  Changelog:
//      Paulinchen  2026-10-06: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Security.Cryptography;

namespace MGQParadox.Multiplayer.Mods;

/// <summary>
/// Hashes a mod's files the way the relay's mod catalog does, so a game, the World Admin tool and
/// the relay agree on whether two copies are the same.
/// </summary>
/// <remarks>
/// A script is hashed without its carriage returns: Git checks scripts out with them on Windows,
/// while GitHub serves the release file without.
/// </remarks>
internal static class ModHash
{
    /// <summary>
    /// The byte a script's carriage returns are, which its hash leaves out.
    /// </summary>
    private const byte CarriageReturn = 13;

    /// <summary>
    /// Hashes a mod's file.
    /// </summary>
    /// <param name="name">The file's name or path, which tells a script from other files.</param>
    /// <param name="bytes">The file.</param>
    /// <returns>The SHA-256 as 64 lowercase hexadecimal characters.</returns>
    public static string Of(string name, ReadOnlySpan<byte> bytes)
    {
        if (!IsScript(name))
        {
            return Convert.ToHexStringLower(SHA256.HashData(bytes));
        }

        var kept = new byte[bytes.Length];
        var length = 0;

        foreach (var value in bytes)
        {
            if (value != CarriageReturn)
            {
                kept[length++] = value;
            }
        }

        return Convert.ToHexStringLower(SHA256.HashData(kept.AsSpan(0, length)));
    }

    /// <summary>
    /// Hashes a mod's file on disk.
    /// </summary>
    /// <param name="path">The file's full path.</param>
    /// <returns>The SHA-256 as 64 lowercase hexadecimal characters.</returns>
    /// <exception cref="IOException">The file could not be read.</exception>
    public static string OfFile(string path) => Of(path, File.ReadAllBytes(path));

    /// <summary>
    /// Tells a script from other files.
    /// </summary>
    /// <param name="name">The file's name or path.</param>
    /// <returns>Whether it is a Ruby script.</returns>
    private static bool IsScript(string name) => name.EndsWith(".rb", StringComparison.OrdinalIgnoreCase);
}
