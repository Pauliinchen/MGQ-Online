//----------------------------------------------------------------
//  WorldKeys.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System;
using System.Security.Cryptography;
using System.Text;

namespace MGQParadox.Multiplayer.Network.World;

/// <summary>
/// What a world's token and a player's key turn into for the relay, which must never learn either:
/// the auth key a game enters a world room with, the hash the directory checks it against, and the
/// id everyone sees for a player.
/// </summary>
internal static class WorldKeys
{
    /// <summary>
    /// Size of an auth key.
    /// </summary>
    private const int AuthKeyBytes = 32;

    /// <summary>
    /// Length of a player id, in hexadecimal characters.
    /// </summary>
    private const int PlayerIdLength = 32;

    /// <summary>
    /// Separates the auth key from anything else ever derived from the same token.
    /// </summary>
    private static readonly byte[] AuthInfo = "mgqmp world auth v1"u8.ToArray();

    /// <summary>
    /// Makes the key that proves to the relay a game holds a world's token, without giving the token away.
    /// </summary>
    /// <param name="token">The world's token.</param>
    /// <returns>64 lowercase hexadecimal characters.</returns>
    public static string AuthKeyOf(string token) =>
        Hex(HKDF.DeriveKey(HashAlgorithmName.SHA256, Encoding.UTF8.GetBytes(token), AuthKeyBytes, info: AuthInfo));

    /// <summary>
    /// Makes the hash the directory keeps of a world's auth key, as the relay makes it of the key it is sent.
    /// </summary>
    /// <param name="authKey">The auth key, see <see cref="AuthKeyOf"/>.</param>
    /// <returns>64 lowercase hexadecimal characters.</returns>
    public static string AuthHashOf(string authKey) => Hex(SHA256.HashData(Encoding.UTF8.GetBytes(authKey)));

    /// <summary>
    /// Makes the id everyone sees for a player, as the relay makes it from the player's key.
    /// </summary>
    /// <param name="playerKey">The player's key.</param>
    /// <returns>32 lowercase hexadecimal characters.</returns>
    public static string PlayerIdOf(string playerKey) =>
        Hex(SHA256.HashData(Encoding.UTF8.GetBytes($"mgqmp player {playerKey}")))[..PlayerIdLength];

    /// <summary>
    /// Writes bytes as lowercase hexadecimal.
    /// </summary>
    /// <param name="bytes">The bytes.</param>
    /// <returns>The hexadecimal text.</returns>
    public static string Hex(ReadOnlySpan<byte> bytes) => Convert.ToHexString(bytes).ToLowerInvariant();
}
