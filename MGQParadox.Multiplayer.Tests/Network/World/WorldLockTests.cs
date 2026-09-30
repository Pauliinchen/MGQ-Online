//----------------------------------------------------------------
//  WorldLockTests.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQParadox.Multiplayer.Network.Pvp;
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Tests.Network.World;

/// <summary>
/// Covers the lock around a world's token, and the keys and ids the relay checks, which must match
/// what Relay/core/directory.js makes.
/// </summary>
public sealed class WorldLockTests
{
    /// <summary>
    /// A world's token as <see cref="JoinCode.NewToken"/> makes them.
    /// </summary>
    private const string Token = "abcdefghjkmnpqrs";

    /// <summary>
    /// Iterations low enough for quick tests.
    /// </summary>
    private const int FewIterations = 1_000;

    /// <summary>
    /// Asserts that the password opens the lock, and that the lock keeps neither the token nor the password readable.
    /// </summary>
    [Fact]
    public void Password_OpensTheLock()
    {
        var worldLock = WorldLock.Close(Token, "Ilias ♥ 2", FewIterations);

        Assert.Matches("^[0-9a-f]{32}$", worldLock.Salt);
        Assert.Equal(FewIterations, worldLock.Iterations);
        Assert.DoesNotContain(WorldKeys.Hex(System.Text.Encoding.UTF8.GetBytes(Token)), worldLock.Box);
        Assert.Equal(Token, worldLock.Open("Ilias ♥ 2"));
    }

    /// <summary>
    /// Asserts that a wrong password, a damaged box or a damaged salt opens nothing.
    /// </summary>
    [Fact]
    public void WrongPasswordOrDamage_OpensNothing()
    {
        var worldLock = WorldLock.Close(Token, "secret", FewIterations);

        Assert.Null(worldLock.Open("Secret"));
        Assert.Null(worldLock.Open(string.Empty));
        Assert.Null((worldLock with { Box = worldLock.Box[..^2] + (worldLock.Box[^2..] == "00" ? "01" : "00") }).Open("secret"));
        Assert.Null((worldLock with { Box = "zz" }).Open("secret"));
        Assert.Null((worldLock with { Salt = "00" }).Open("secret"));
    }

    /// <summary>
    /// Asserts that two locks of the same token and password differ, since each has its own salt and nonce.
    /// </summary>
    [Fact]
    public void EveryLock_IsItsOwn()
    {
        Assert.NotEqual(WorldLock.Close(Token, "secret", FewIterations).Box, WorldLock.Close(Token, "secret", FewIterations).Box);
    }

    /// <summary>
    /// Asserts that a player's id and an auth key's hash come out as the relay makes them.
    /// </summary>
    [Fact]
    public void Ids_MatchTheRelay()
    {
        Assert.Equal("75003ab327000fc160598ed2390fa82d", WorldKeys.PlayerIdOf(string.Concat(Enumerable.Repeat("c0", 16))));
        Assert.Equal("271a413bd339c5709fdceaec41f14f11e9fbfb5042d72d331c65f32b284cd09a", WorldKeys.AuthHashOf(string.Concat(Enumerable.Repeat("ab", 32))));
    }

    /// <summary>
    /// Asserts that the auth key is stable per token, apart from the room id, and does not give the token away.
    /// </summary>
    [Fact]
    public void AuthKey_IsStableAndHidesTheToken()
    {
        var authKey = WorldKeys.AuthKeyOf(Token);

        Assert.Matches("^[0-9a-f]{64}$", authKey);
        Assert.Equal(authKey, WorldKeys.AuthKeyOf(Token));
        Assert.NotEqual(authKey, WorldKeys.AuthKeyOf("zzzzzzzzzzzzzzzz"));
        Assert.DoesNotContain(Relays.WorldRoomOf(Token), authKey);
    }
}
