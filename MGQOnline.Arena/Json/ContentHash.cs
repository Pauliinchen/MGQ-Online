//----------------------------------------------------------------
//  ContentHash.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Security.Cryptography;

namespace MGQOnline.Arena.Json;

/// <summary>
/// Names content by its SHA-256.
/// </summary>
public static class ContentHash
{
    /// <summary>
    /// Hashes bytes.
    /// </summary>
    /// <param name="bytes">The bytes.</param>
    /// <returns>The SHA-256 as 64 lowercase hex characters.</returns>
    public static string Sha256Hex(ReadOnlySpan<byte> bytes) => Convert.ToHexStringLower(SHA256.HashData(bytes));
}
