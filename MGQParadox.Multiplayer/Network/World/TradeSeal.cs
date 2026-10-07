//----------------------------------------------------------------
//  TradeSeal.cs
//
//  Changelog:
//      Paulinchen  2026-10-07: Sealed the offers through SealedBox, shared with the world's lock and the starting save
//      Paulinchen  2026-10-06: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;

namespace MGQParadox.Multiplayer.Network.World;

/// <summary>
/// The offers of a trade as the relay keeps them: encrypted with a key from the world's token, so
/// the relay cannot read them and any game in the world can, and bound to the trade's id.
/// </summary>
internal static class TradeSeal
{
    /// <summary>
    /// Most bytes the offers may have, in UTF-8.
    /// </summary>
    public const int MaxOffersBytes = 32 * 1024;

    /// <summary>
    /// Separates the trades' key from anything else ever derived from the same token.
    /// </summary>
    private static readonly byte[] KeyInfo = "mgqmp world trade v1"u8.ToArray();

    /// <summary>
    /// Hashes the offers, as both games of a trade must agree on them.
    /// </summary>
    /// <param name="offers">The offers.</param>
    /// <returns>The SHA-256 of their UTF-8 bytes, 64 lowercase hexadecimal characters.</returns>
    public static string HashOf(string offers) => WorldKeys.Hex(SHA256.HashData(Encoding.UTF8.GetBytes(offers)));

    /// <summary>
    /// Encrypts the offers of a trade.
    /// </summary>
    /// <param name="token">The world's token.</param>
    /// <param name="trade">The trade's id, which a sealed text only opens under.</param>
    /// <param name="offers">The offers.</param>
    /// <returns>The nonce, the encrypted offers and the tag, in base64.</returns>
    public static string Seal(string token, string trade, string offers) =>
        Convert.ToBase64String(SealedBox.Seal(KeyOf(token), Encoding.UTF8.GetBytes(offers), Encoding.UTF8.GetBytes(trade)));

    /// <summary>
    /// Decrypts the offers of a trade.
    /// </summary>
    /// <param name="token">The world's token.</param>
    /// <param name="trade">The trade's id.</param>
    /// <param name="sealedOffers">The offers as <see cref="Seal"/> made them.</param>
    /// <returns>The offers.</returns>
    /// <exception cref="InvalidDataException">The text is damaged, or belongs to another world or trade.</exception>
    public static string Open(string token, string trade, string sealedOffers)
    {
        byte[] box;

        try
        {
            box = Convert.FromBase64String(sealedOffers);
        }
        catch (FormatException)
        {
            throw new InvalidDataException("The sealed offers are no base64.");
        }

        if (box.Length < SealedBox.Overhead)
        {
            throw new InvalidDataException("The sealed offers are too short.");
        }

        var plain = SealedBox.Open(KeyOf(token), box, Encoding.UTF8.GetBytes(trade))
            ?? throw new InvalidDataException("The sealed offers are damaged, or belong to another world or trade.");

        return Encoding.UTF8.GetString(plain);
    }

    /// <summary>
    /// Makes the trades' key from the world's token.
    /// </summary>
    /// <param name="token">The world's token.</param>
    /// <returns>The key.</returns>
    private static byte[] KeyOf(string token) => SealedBox.KeyOf(token, KeyInfo);
}
