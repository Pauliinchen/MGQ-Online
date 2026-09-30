//----------------------------------------------------------------
//  JoinCodeTests.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Covered the join code of token and relay only, and telling codes of other versions
//                            - Covered version 2 of the join code, with its relay and longer token
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using MGQParadox.Multiplayer.Network.Pvp;
using MGQParadox.Multiplayer.Network.Relay;

namespace MGQParadox.Multiplayer.Tests.Network.Pvp;

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
        var code = new JoinCode(Token, "r1");

        var text = code.ToText();

        Assert.Equal("mgqmp2;abcdefghjkmnpqrs;r1", text);
        Assert.Equal(code, JoinCode.Parse(text));
    }

    /// <summary>
    /// Asserts that anything but a join code of this version is turned down, codes of earlier
    /// versions and of this version's first draft with port and addresses included.
    /// </summary>
    /// <param name="text">The text.</param>
    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("hello")]
    [InlineData("mgqmp1;abcdefghjk;47625;203.0.113.7")]
    [InlineData("mgqmp2;abcdefghjkmnpqrs;47625;r1;203.0.113.7")]
    [InlineData("mgqmp2;abcdefghjk;r1")]
    [InlineData("mgqmp2;ABCDEFGHJKMNPQRS;r1")]
    [InlineData("mgqmp2;abcdefghjkmnpqrs;")]
    [InlineData("mgqmp2;abcdefghjkmnpqrs;R1")]
    [InlineData("mgqmp2;abcdefghjkmnpqrs;relay/r1")]
    [InlineData("mgqmp2;abcdefghjkmnpqrs;relayfour")]
    public void Parse_TurnsDownAnythingElse(string? text) => Assert.Null(JoinCode.Parse(text));

    /// <summary>
    /// Asserts that a code pasted with white space around it still reads.
    /// </summary>
    [Fact]
    public void Parse_IgnoresSurroundingWhiteSpace() =>
        Assert.NotNull(JoinCode.Parse("  mgqmp2;abcdefghjkmnpqrs;r1\r\n"));

    /// <summary>
    /// Asserts that codes of every version count as join codes, and nothing else does.
    /// </summary>
    [Fact]
    public void IsOfAnyVersion_KnowsEveryVersion()
    {
        Assert.True(JoinCode.IsOfAnyVersion("mgqmp2;abcdefghjkmnpqrs;r1"));
        Assert.True(JoinCode.IsOfAnyVersion(" mgqmp1;abcdefghjk;47625;203.0.113.7"));
        Assert.True(JoinCode.IsOfAnyVersion("mgqmp9;anything"));
        Assert.False(JoinCode.IsOfAnyVersion("hello"));
        Assert.False(JoinCode.IsOfAnyVersion(null));
    }

    /// <summary>
    /// Asserts that new tokens read as tokens and differ.
    /// </summary>
    [Fact]
    public void NewToken_MakesReadableTokens()
    {
        var first = JoinCode.NewToken();
        var second = JoinCode.NewToken();

        Assert.NotEqual(first, second);
        Assert.NotNull(JoinCode.Parse($"mgqmp2;{first};r1"));
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
