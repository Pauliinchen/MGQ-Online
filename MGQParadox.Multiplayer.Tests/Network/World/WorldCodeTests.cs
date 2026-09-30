//----------------------------------------------------------------
//  WorldCodeTests.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using MGQParadox.Multiplayer.Network.Pvp;
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Tests.Network.World;

/// <summary>
/// Covers writing and reading world codes, and the world id made from one.
/// </summary>
public sealed class WorldCodeTests
{
    /// <summary>
    /// A token as <see cref="JoinCode.NewToken"/> makes them.
    /// </summary>
    private const string Token = "abcdefghjkmnpqrs";

    /// <summary>
    /// Asserts that a code reads back as written, and that it names nothing but token, relay and seats.
    /// </summary>
    [Fact]
    public void Code_ReadsBackAsWritten()
    {
        var code = new WorldCode(Token, "r1", 4);

        Assert.Equal("mgqmp2;abcdefghjkmnpqrs;r1;4", code.ToText());
        Assert.Equal(code, WorldCode.Parse(code.ToText()));
        Assert.Equal(code, WorldCode.Parse($"  {code.ToText()}\r\n"));
        Assert.Equal(32, WorldCode.Parse("mgqmp2;abcdefghjkmnpqrs;r1;32")!.Seats);
    }

    /// <summary>
    /// Asserts that join codes, seats out of range and damaged codes are no world codes.
    /// </summary>
    [Theory]
    [InlineData("mgqmp2;abcdefghjkmnpqrs;r1")]
    [InlineData("mgqmp2;abcdefghjkmnpqrs;r1;1")]
    [InlineData("mgqmp2;abcdefghjkmnpqrs;r1;33")]
    [InlineData("mgqmp2;abcdefghjkmnpqrs;r1;+4")]
    [InlineData("mgqmp2;abcdefghjkmnpqrs;r1;004")]
    [InlineData("mgqmp2;abcdefghjkmnpqrs;r1;")]
    [InlineData("mgqmp2;abcdefghjkmnpqr;r1;4")]
    [InlineData("mgqmp1;abcdefghjkmnpqrs;r1;4")]
    [InlineData("mgqmp2;abcdefghjkmnpqrs;R1;4")]
    [InlineData("")]
    [InlineData(null)]
    public void NoWorldCode_ReadsAsNone(string? text)
    {
        Assert.Null(WorldCode.Parse(text));
    }

    /// <summary>
    /// Asserts that a world id is stable, short, tells worlds apart and does not give the token away.
    /// </summary>
    [Fact]
    public void Id_IsStableAndHidesTheToken()
    {
        var id = WorldCode.IdOf(Token);

        Assert.Matches("^[0-9a-f]{12}$", id);
        Assert.Equal(id, WorldCode.IdOf(Token));
        Assert.NotEqual(id, WorldCode.IdOf("zzzzzzzzzzzzzzzz"));
        Assert.DoesNotContain(Token[..6], id);
    }

    /// <summary>
    /// Asserts that a world's room differs from the PvP room of the same token.
    /// </summary>
    [Fact]
    public void WorldRoom_DiffersFromTheRoomOfTheSameToken()
    {
        Assert.Matches("^[0-9a-f]{32}$", Relays.WorldRoomOf(Token));
        Assert.NotEqual(Relays.RoomOf(Token), Relays.WorldRoomOf(Token));
    }
}
