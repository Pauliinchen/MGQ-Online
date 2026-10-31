//----------------------------------------------------------------
//  WorldCodeTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Used the join code, which moved beside the world code, and checked the world room alone
//      Paulinchen  2026-10-30: Cut the texts that are no world codes to one of each rule
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

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
    /// <param name="text">The text.</param>
    [Theory]
    [InlineData("mgqmp2;abcdefghjkmnpqrs;r1")]
    [InlineData("mgqmp2;abcdefghjkmnpqrs;r1;1")]
    [InlineData("mgqmp2;abcdefghjkmnpqrs;r1;33")]
    [InlineData("mgqmp2;abcdefghjkmnpqrs;r1;+4")]
    [InlineData("mgqmp1;abcdefghjkmnpqrs;r1;4")]
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
    /// Asserts that a world's room is the same for every game of the world, differs between worlds,
    /// and has the form the relay accepts.
    /// </summary>
    [Fact]
    public void WorldRoom_IsStablePerToken()
    {
        Assert.Matches("^[0-9a-f]{32}$", Relays.WorldRoomOf(Token));
        Assert.Equal(Relays.WorldRoomOf(Token), Relays.WorldRoomOf(Token));
        Assert.NotEqual(Relays.WorldRoomOf(Token), Relays.WorldRoomOf("zzzzzzzzzzzzzzzz"));
    }
}
