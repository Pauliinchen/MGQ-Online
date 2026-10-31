//----------------------------------------------------------------
//  VersionHeaderTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Dropped the PvP room, which no game connects to any more
//      Paulinchen  2026-10-30: Checked the directory and both rooms in one test and dropped the check of the build constant
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
    /// Asserts that the directory requests and the world room connection name the version of this game.
    /// </summary>
    [Fact]
    public void RelayRequests_NameTheVersion()
    {
        using var relay = new TestRelay();
        var creator = WorldDirectoryTests.NewDirectory(relay, WorldDirectoryTests.CreatorKey, "Creator");
        var token = WorldCode.Parse(WorldDirectoryTests.Act(creator, directory => directory.Create("Iliasburg Crew", "secret", 4, false, false, []))["code"])!.Token;
        WorldDirectoryTests.List(creator);
        using var world = RelayWorldChannel.Connect(relay.Address, Relays.WorldRoomOf(token), WorldDirectoryTests.PlayerKey(7), "Guest", WorldKeys.AuthKeyOf(token), Patience, CancellationToken.None, out _, out _);

        Assert.NotNull(world);
        var requests = relay.Versions.ToArray();
        Assert.All(new[] { "/v1/worlds", "/v1/world/" }, path => Assert.Contains(requests, request => request.Path.StartsWith(path, StringComparison.Ordinal)));
        Assert.All(requests, request => Assert.Equal(UpdateCheck.ModVersion, request.Version));
    }
}
