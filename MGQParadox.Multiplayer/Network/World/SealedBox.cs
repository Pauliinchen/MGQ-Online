//----------------------------------------------------------------
//  SealedBox.cs
//
//  Changelog:
//      Paulinchen  2026-10-07: Created
//
//----------------------------------------------------------------

using System;
using System.Security.Cryptography;
using System.Text;

namespace MGQParadox.Multiplayer.Network.World;

/// <summary>
/// What a world's lock, a trade's offers and a starting save are sealed as: the nonce, the text
/// encrypted with AES-GCM, and the tag, under a key the caller made.
/// </summary>
internal static class SealedBox
{
    /// <summary>
    /// Size of a key.
    /// </summary>
    public const int KeyBytes = 32;

    /// <summary>
    /// Size of the nonce in front of the encrypted text.
    /// </summary>
    public const int NonceBytes = 12;

    /// <summary>
    /// Size of the tag behind the encrypted text.
    /// </summary>
    public const int TagBytes = 16;

    /// <summary>
    /// Bytes a box carries on top of its text.
    /// </summary>
    public const int Overhead = NonceBytes + TagBytes;

    /// <summary>
    /// Derives a key from a world's token for one use.
    /// </summary>
    /// <param name="token">The world's token.</param>
    /// <param name="info">What the key is for, which separates it from anything else ever derived from the same token.</param>
    /// <returns>The key.</returns>
    public static byte[] KeyOf(string token, byte[] info) =>
        HKDF.DeriveKey(HashAlgorithmName.SHA256, Encoding.UTF8.GetBytes(token), KeyBytes, info: info);

    /// <summary>
    /// Encrypts a text under a key, with a fresh nonce.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <param name="plain">The text.</param>
    /// <param name="associated">What the box is bound to and only opens under again, empty for nothing.</param>
    /// <returns>The nonce, the encrypted text and the tag.</returns>
    public static byte[] Seal(byte[] key, ReadOnlySpan<byte> plain, ReadOnlySpan<byte> associated = default)
    {
        var box = new byte[Overhead + plain.Length];
        RandomNumberGenerator.Fill(box.AsSpan(0, NonceBytes));

        using var aes = new AesGcm(key, TagBytes);
        aes.Encrypt(box.AsSpan(0, NonceBytes), plain, box.AsSpan(NonceBytes, plain.Length), box.AsSpan(NonceBytes + plain.Length), associated);
        return box;
    }

    /// <summary>
    /// Checks and decrypts a box.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <param name="box">The box as <see cref="Seal"/> made it.</param>
    /// <param name="associated">What the box was bound to, empty for nothing.</param>
    /// <returns>The text, or <see langword="null"/> when the box is too short, damaged, or was sealed under another key or binding.</returns>
    public static byte[]? Open(byte[] key, ReadOnlySpan<byte> box, ReadOnlySpan<byte> associated = default)
    {
        if (box.Length < Overhead)
        {
            return null;
        }

        var plain = new byte[box.Length - Overhead];

        try
        {
            using var aes = new AesGcm(key, TagBytes);
            aes.Decrypt(box[..NonceBytes], box.Slice(NonceBytes, plain.Length), box[^TagBytes..], plain, associated);
        }
        catch (AuthenticationTagMismatchException)
        {
            return null;
        }

        return plain;
    }
}
