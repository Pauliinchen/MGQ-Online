//----------------------------------------------------------------
//  WorldLock.cs
//
//  Changelog:
//      Paulinchen  2026-10-07: Sealed the token through SealedBox, shared with the trades and the starting save
//      Paulinchen  2026-10-06: Hashed new locks' passwords 600 000 times instead of 200 000
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System;
using System.Security.Cryptography;
using System.Text;

namespace MGQParadox.Multiplayer.Network.World;

/// <summary>
/// A world's token, locked with its password, as the directory keeps it for anyone to fetch: only
/// the password opens it.
/// </summary>
/// <remarks>
/// The password's key is slow to make on purpose (PBKDF2), since whoever fetches the lock may try
/// passwords against it for as long as they like.
/// </remarks>
/// <param name="Salt">The salt of the password's key, 32 lowercase hexadecimal characters.</param>
/// <param name="Iterations">How often PBKDF2 hashes the password.</param>
/// <param name="Box">The nonce, the encrypted token and the tag, as lowercase hexadecimal.</param>
internal sealed record WorldLock(string Salt, int Iterations, string Box)
{
    /// <summary>
    /// How often PBKDF2 hashes a new lock's password: a moment for the game, long for someone trying passwords.
    /// </summary>
    public const int DefaultIterations = 600_000;

    /// <summary>
    /// Size of the salt.
    /// </summary>
    private const int SaltBytes = 16;

    /// <summary>
    /// Locks a token with a password.
    /// </summary>
    /// <param name="token">The world's token.</param>
    /// <param name="password">The password.</param>
    /// <param name="iterations">How often PBKDF2 hashes the password.</param>
    /// <returns>The lock.</returns>
    public static WorldLock Close(string token, string password, int iterations = DefaultIterations)
    {
        var salt = RandomNumberGenerator.GetBytes(SaltBytes);
        var box = SealedBox.Seal(KeyOf(password, salt, iterations), Encoding.UTF8.GetBytes(token));
        return new WorldLock(WorldKeys.Hex(salt), iterations, WorldKeys.Hex(box));
    }

    /// <summary>
    /// Opens the lock with a password.
    /// </summary>
    /// <param name="password">The password.</param>
    /// <returns>The token, or <see langword="null"/> when the password is wrong or the lock is damaged.</returns>
    public string? Open(string password)
    {
        try
        {
            var salt = Convert.FromHexString(Salt);
            var box = Convert.FromHexString(Box);
            return SealedBox.Open(KeyOf(password, salt, Iterations), box) is { } plain ? Encoding.UTF8.GetString(plain) : null;
        }
        catch (Exception ex) when (ex is FormatException or ArgumentException)
        {
            return null;
        }
    }

    /// <summary>
    /// Makes the password's key.
    /// </summary>
    /// <param name="password">The password.</param>
    /// <param name="salt">The salt.</param>
    /// <param name="iterations">How often PBKDF2 hashes the password.</param>
    /// <returns>The key.</returns>
    private static byte[] KeyOf(string password, byte[] salt, int iterations) =>
        Rfc2898DeriveBytes.Pbkdf2(Encoding.UTF8.GetBytes(password), salt, iterations, HashAlgorithmName.SHA256, SealedBox.KeyBytes);
}
