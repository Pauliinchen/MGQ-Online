//----------------------------------------------------------------
//  Pbkdf2Sha256Tests.cs
//
//  Changelog:
//      Paulinchen  2026-10-08: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Tests.Network.World;

/// <summary>
/// Covers the DLL's own PBKDF2, which must give the bytes .NET's gives, or every existing world
/// lock would read as a wrong password.
/// </summary>
public sealed class Pbkdf2Sha256Tests
{
    /// <summary>
    /// Asserts the PBKDF2-HMAC-SHA256 test vectors of RFC 7914 section 11.
    /// </summary>
    [Fact]
    public void Rfc7914Vectors_Match()
    {
        Assert.Equal(
            "55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783",
            Hex(Pbkdf2Sha256.DeriveKey("passwd"u8, "salt"u8, 1, 64)));
        Assert.Equal(
            "4ddcd8f60b98be21830cee5ef22701f9641a4418d04c0414aeff08876b34ab56a1d425a1225833549adb841b51c9b3176a272bdebba1d078478f62b397f33c8d",
            Hex(Pbkdf2Sha256.DeriveKey("Password"u8, "NaCl"u8, 80_000, 64)));
    }

    /// <summary>
    /// Asserts the same key as .NET's PBKDF2 for passwords around the HMAC block size, which a key
    /// longer than a block is hashed first at, and for keys of partial and several blocks.
    /// </summary>
    /// <param name="passwordLength">The password's length in bytes.</param>
    /// <param name="keyLength">The key's length in bytes.</param>
    [Theory]
    [InlineData(0, 32)]
    [InlineData(1, 32)]
    [InlineData(55, 32)]
    [InlineData(63, 31)]
    [InlineData(64, 33)]
    [InlineData(65, 64)]
    [InlineData(100, 65)]
    [InlineData(200, 1)]
    public void AnyPassword_MatchesDotNet(int passwordLength, int keyLength)
    {
        var password = Enumerable.Range(0, passwordLength).Select(index => (byte)(index * 7 + 1)).ToArray();
        var salt = Convert.FromHexString("00112233445566778899aabbccddeeff");

        Assert.Equal(
            Rfc2898DeriveBytes.Pbkdf2(password, salt, 1_000, HashAlgorithmName.SHA256, keyLength),
            Pbkdf2Sha256.DeriveKey(password, salt, 1_000, keyLength));
    }

    /// <summary>
    /// Asserts the same key as .NET's PBKDF2 at the iteration counts world locks were made with, for
    /// a world without a password and one with a password outside ASCII.
    /// </summary>
    /// <param name="password">The password.</param>
    /// <param name="iterations">How often the password hashes.</param>
    [Theory]
    [InlineData("", 200_000)]
    [InlineData("", WorldLock.DefaultIterations)]
    [InlineData("Ilias ♥ 2", WorldLock.DefaultIterations)]
    public void WorldLockSettings_MatchDotNet(string password, int iterations)
    {
        var bytes = Encoding.UTF8.GetBytes(password);
        var salt = RandomNumberGenerator.GetBytes(16);

        Assert.Equal(
            Rfc2898DeriveBytes.Pbkdf2(bytes, salt, iterations, HashAlgorithmName.SHA256, SealedBox.KeyBytes),
            Pbkdf2Sha256.DeriveKey(bytes, salt, iterations, SealedBox.KeyBytes));
    }

    /// <summary>
    /// Asserts that no iterations or no key throw what WorldLock.Open turns into an unopened lock.
    /// </summary>
    [Fact]
    public void NothingToDerive_Throws()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => Pbkdf2Sha256.DeriveKey("a"u8, "b"u8, 0, 32));
        Assert.Throws<ArgumentOutOfRangeException>(() => Pbkdf2Sha256.DeriveKey("a"u8, "b"u8, 1, 0));
    }

    /// <summary>
    /// Writes bytes as lowercase hexadecimal.
    /// </summary>
    /// <param name="bytes">The bytes.</param>
    /// <returns>The hexadecimal text.</returns>
    private static string Hex(byte[] bytes) => Convert.ToHexStringLower(bytes);
}
