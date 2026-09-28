//----------------------------------------------------------------
//  JoinCodeTests.cs
//
//  Changelog:
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQParadox.Multiplayer.Network;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Covers the join code a guest needs to reach a hosting game.
/// </summary>
public sealed class JoinCodeTests
{
    /// <summary>
    /// A token as <see cref="JoinCode.NewToken"/> makes them.
    /// </summary>
    private const string Token = "abcdefghjk";

    /// <summary>
    /// Asserts that a written code reads back the same.
    /// </summary>
    [Fact]
    public void ToText_ReadsBack()
    {
        var code = new JoinCode(Token, 47625, new[] { "2001:db8::7", "203.0.113.7", "192.168.1.20" });

        var text = code.ToText();
        var parsed = JoinCode.Parse(text);

        Assert.Equal("mgqfb1;abcdefghjk;47625;2001:db8::7,203.0.113.7,192.168.1.20", text);
        Assert.NotNull(parsed);
        Assert.Equal(Token, parsed.Token);
        Assert.Equal(47625, parsed.Port);
        Assert.Equal(code.Addresses, parsed.Addresses);
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

        var text = new JoinCode(Token, 47625, addresses).ToText();

        Assert.True(text.Length <= JoinCode.MaxLength);
        Assert.EndsWith(",10.0.0.1", text);
    }

    /// <summary>
    /// Asserts that anything but a join code is turned down, host names included, so joining never
    /// looks a name up.
    /// </summary>
    /// <param name="text">The text.</param>
    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("hello")]
    [InlineData("mgqfb1;abcdefghjk;47625;")]
    [InlineData("mgqfb1;abcdefghjk;0;203.0.113.7")]
    [InlineData("mgqfb1;abcdefghjk;70000;203.0.113.7")]
    [InlineData("mgqfb1;short;47625;203.0.113.7")]
    [InlineData("mgqfb1;abcdefghjk;47625;example.com")]
    [InlineData("mgqfb2;abcdefghjk;47625;203.0.113.7")]
    public void Parse_TurnsDownAnythingElse(string? text) => Assert.Null(JoinCode.Parse(text));

    /// <summary>
    /// Asserts that a code pasted with white space around it still reads.
    /// </summary>
    [Fact]
    public void Parse_IgnoresSurroundingWhiteSpace() =>
        Assert.NotNull(JoinCode.Parse("  mgqfb1;abcdefghjk;47625;203.0.113.7\r\n"));

    /// <summary>
    /// Asserts that new tokens read as tokens and differ.
    /// </summary>
    [Fact]
    public void NewToken_MakesReadableTokens()
    {
        var first = JoinCode.NewToken();
        var second = JoinCode.NewToken();

        Assert.NotEqual(first, second);
        Assert.NotNull(JoinCode.Parse($"mgqfb1;{first};47625;203.0.113.7"));
    }
}
