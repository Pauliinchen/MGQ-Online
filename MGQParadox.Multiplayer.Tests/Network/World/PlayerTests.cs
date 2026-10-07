//----------------------------------------------------------------
//  PlayerTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-07: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Tests.Network.World;

/// <summary>
/// Covers who plays in worlds: the key checked and the name cleaned.
/// </summary>
public sealed class PlayerTests
{
    /// <summary>
    /// A player's key as Player.ini keeps it.
    /// </summary>
    private static readonly string Key = string.Concat(Enumerable.Repeat("c0", 16));

    /// <summary>
    /// Asserts that a name loses its control characters and surrounding spaces, and is cut to 32 characters.
    /// </summary>
    [Fact]
    public void Set_CleansTheName()
    {
        Assert.True(Player.Set(Key, "  Lu\tka\r\nI\u0001 "));
        Assert.Equal("LukaI", Player.Name);

        Assert.True(Player.Set(Key, new string('a', 40)));
        Assert.Equal(new string('a', 32), Player.Name);
        Assert.Equal((Key, new string('a', 32)), Player.Current());
    }

    /// <summary>
    /// Asserts that a name with nothing left of it, or a key that is not 32 lowercase hexadecimal characters, is not taken.
    /// </summary>
    [Fact]
    public void Set_RefusesAnEmptyNameOrAMalformedKey()
    {
        Assert.False(Player.Set(Key, " \t\n "));
        Assert.False(Player.Set(Key[..31], "Luka"));
        Assert.False(Player.Set(Key.ToUpperInvariant(), "Luka"));
        Assert.False(Player.Set(Key[..30] + "zz", "Luka"));
    }

    /// <summary>
    /// Asserts that the cleaning every name goes through keeps a plain name as it is.
    /// </summary>
    [Fact]
    public void Cleaned_KeepsAPlainName()
    {
        Assert.Equal("Alice ♥", PlayerName.Cleaned("Alice ♥", 32));
        Assert.Equal(string.Empty, PlayerName.Cleaned(null, 32));
        Assert.Equal("Al", PlayerName.Cleaned("Alice", 2));
    }
}
