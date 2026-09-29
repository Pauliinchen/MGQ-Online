//----------------------------------------------------------------
//  JoinCodeTests.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Covered version 2 of the join code, with its relay and longer token
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQParadox.Multiplayer.Network;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Covers the join code a guest needs to reach a hosting game, and the relay room it leads to.
/// </summary>
public sealed class JoinCodeTests
{
    /// <summary>
    /// A token as <see cref="JoinCode.NewToken"/> makes them.
    /// </summary>
    private const string Token = "abcdefghjkmnpqrs";

    /// <summary>
    /// Asserts that a written code reads back the same.
    /// </summary>
    [Fact]
    public void ToText_ReadsBack()
    {
        var code = new JoinCode(Token, 47625, "r1", new[] { "2001:db8::7", "203.0.113.7", "192.168.1.20" });

        var text = code.ToText();
        var parsed = JoinCode.Parse(text);

        Assert.Equal("mgqmp2;abcdefghjkmnpqrs;47625;r1;2001:db8::7,203.0.113.7,192.168.1.20", text);
        Assert.NotNull(parsed);
        Assert.Equal(Token, parsed.Token);
        Assert.Equal(47625, parsed.Port);
        Assert.Equal("r1", parsed.Relay);
        Assert.Equal(code.Addresses, parsed.Addresses);
    }

    /// <summary>
    /// Asserts that a code without any address reads back, since the relay alone can reach the host.
    /// </summary>
    [Fact]
    public void ToText_ReadsBackWithoutAddresses()
    {
        var text = new JoinCode(Token, 47625, "r1", []).ToText();

        Assert.Equal("mgqmp2;abcdefghjkmnpqrs;47625;r1;", text);
        Assert.Empty(JoinCode.Parse(text)!.Addresses);
    }

    /// <summary>
    /// Asserts that a code never outgrows Discord's join secret, leaving out the addresses that do
    /// not fit but keeping shorter ones after them.
    /// </summary>
    [Fact]
    public void ToText_FitsIntoAJoinSecret()
    {
        var addresses = Enumerable.Range(0, 3).Select(index => $"2001:db8:aaaa:bbbb:cccc:dddd:eeee:{index:x4}")
                                  .Append("10.0.0.1")
                                  .ToArray();

        var text = new JoinCode(Token, 47625, "r1", addresses).ToText();

        Assert.True(text.Length <= JoinCode.MaxLength);
        Assert.EndsWith(",10.0.0.1", text);
    }

    /// <summary>
    /// Asserts that anything but a version 2 join code is turned down, host names and codes of the
    /// earlier version included, so joining never looks a name up.
    /// </summary>
    /// <param name="text">The text.</param>
    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("hello")]
    [InlineData("mgqmp1;abcdefghjk;47625;203.0.113.7")]
    [InlineData("mgqmp2;abcdefghjkmnpqrs;0;r1;203.0.113.7")]
    [InlineData("mgqmp2;abcdefghjkmnpqrs;70000;r1;203.0.113.7")]
    [InlineData("mgqmp2;abcdefghjk;47625;r1;203.0.113.7")]
    [InlineData("mgqmp2;abcdefghjkmnpqrs;47625;r1;example.com")]
    [InlineData("mgqmp2;abcdefghjkmnpqrs;47625;;203.0.113.7")]
    [InlineData("mgqmp2;abcdefghjkmnpqrs;47625;R1;203.0.113.7")]
    [InlineData("mgqmp2;abcdefghjkmnpqrs;47625;relay/r1;203.0.113.7")]
    [InlineData("mgqmp2;abcdefghjkmnpqrs;47625;203.0.113.7")]
    public void Parse_TurnsDownAnythingElse(string? text) => Assert.Null(JoinCode.Parse(text));

    /// <summary>
    /// Asserts that a code pasted with white space around it still reads.
    /// </summary>
    [Fact]
    public void Parse_IgnoresSurroundingWhiteSpace() =>
        Assert.NotNull(JoinCode.Parse("  mgqmp2;abcdefghjkmnpqrs;47625;r1;203.0.113.7\r\n"));

    /// <summary>
    /// Asserts that new tokens read as tokens and differ.
    /// </summary>
    [Fact]
    public void NewToken_MakesReadableTokens()
    {
        var first = JoinCode.NewToken();
        var second = JoinCode.NewToken();

        Assert.NotEqual(first, second);
        Assert.NotNull(JoinCode.Parse($"mgqmp2;{first};47625;r1;203.0.113.7"));
    }

    /// <summary>
    /// Asserts that a token's relay room is the same on both sides, differs between tokens, and
    /// has the form the relay accepts.
    /// </summary>
    [Fact]
    public void RoomOf_IsStablePerToken()
    {
        var room = Relays.RoomOf(Token);

        Assert.Equal(room, Relays.RoomOf(Token));
        Assert.NotEqual(room, Relays.RoomOf("zzzzzzzzzzzzzzzz"));
        Assert.Matches("^[0-9a-f]{32}$", room);
    }

    /// <summary>
    /// Asserts that this version knows the relay it hosts on, and no relay it was never told of.
    /// </summary>
    [Fact]
    public void Relays_KnowTheCurrentOne()
    {
        Assert.Equal("wss", Relays.AddressOf(Relays.Current)!.Scheme);
        Assert.Null(Relays.AddressOf("r9"));
    }
}
