//----------------------------------------------------------------
//  VersionHeaderTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-12: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using System.Threading;
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.World;
using MGQParadox.Multiplayer.Tests.Network.World;

namespace MGQParadox.Multiplayer.Tests.Network.Relay;

/// <summary>
/// Covers the X-MGQ-Version header, which every request of this game to the relay carries.
/// </summary>
public sealed class VersionHeaderTests
{
    /// <summary>
    /// How long a test waits for the relay.
    /// </summary>
    private static readonly TimeSpan Patience = TimeSpan.FromSeconds(10);

    /// <summary>
    /// Asserts that the tests run a development build, which names its development stamp.
    /// </summary>
    [Fact]
    public void ModVersion_OfTheTestBuild_IsTheDevelopmentStamp() => Assert.Equal("0.0.0-dev", UpdateCheck.ModVersion);

    /// <summary>
    /// Asserts that every directory request names the version of this game.
    /// </summary>
    [Fact]
    public void DirectoryRequests_NameTheVersion()
    {
        using var relay = new TestRelay();
        var creator = WorldDirectoryTests.NewDirectory(relay, WorldDirectoryTests.CreatorKey, "Creator");

        Assert.Equal("done", WorldDirectoryTests.Act(creator, directory => directory.Create("Iliasburg Crew", "secret", 4, false, false, []))["state"]);
        WorldDirectoryTests.List(creator);

        var requests = relay.Versions.Where(request => request.Path.StartsWith("/v1/worlds", StringComparison.Ordinal)).ToArray();
        Assert.NotEmpty(requests);
        Assert.All(requests, request => Assert.Equal(UpdateCheck.ModVersion, request.Version));
    }

    /// <summary>
    /// Asserts that a world room connection names the version of this game.
    /// </summary>
    [Fact]
    public void WorldRoom_NamesTheVersion()
    {
        using var relay = new TestRelay();
        var creator = WorldDirectoryTests.NewDirectory(relay, WorldDirectoryTests.CreatorKey, "Creator");
        var token = WorldCode.Parse(WorldDirectoryTests.Act(creator, directory => directory.Create("Iliasburg Crew", "secret", 4, false, false, []))["code"])!.Token;
        using var channel = RelayWorldChannel.Connect(relay.Address, Relays.WorldRoomOf(token), WorldDirectoryTests.PlayerKey(7), "Guest", WorldKeys.AuthKeyOf(token), Patience, CancellationToken.None, out _, out _);

        Assert.NotNull(channel);
        Assert.Equal(UpdateCheck.ModVersion, relay.Versions.Single(request => request.Path.StartsWith("/v1/world/", StringComparison.Ordinal)).Version);
    }

    /// <summary>
    /// Asserts that a PvP room connection names the version of this game.
    /// </summary>
    [Fact]
    public void PvpRoom_NamesTheVersion()
    {
        using var relay = new TestRelay();
        using var channel = RelayFrameChannel.Connect(relay.Address, Relays.RoomOf("abcdefghjk"), host: true, Patience);

        Assert.Equal(UpdateCheck.ModVersion, relay.Versions.Single(request => request.Path.StartsWith("/v1/room/", StringComparison.Ordinal)).Version);
    }
}
