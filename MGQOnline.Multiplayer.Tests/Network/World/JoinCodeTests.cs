//----------------------------------------------------------------
//  JoinCodeTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-10-31: Moved beside the world code's tests and dropped the checks of other versions' codes and the PvP relay room
//      Paulinchen  2026-10-30: Cut the codes turned down to one of each rule and dropped the relay check RelaysTests holds
//      Paulinchen  2026-09-29: Covered the join code of token and relay only and codes of other versions
//                            - Covered version 2 of the join code
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using MGQOnline.Multiplayer.Network.World;

namespace MGQOnline.Multiplayer.Tests.Network.World;

/// <summary>
/// Covers the join code a world code starts with: the world's token and its relay.
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
    /// versions, wrong case, a short token and a malformed relay included.
    /// </summary>
    /// <param name="text">The text.</param>
    [Theory]
    [InlineData(null)]
    [InlineData("hello")]
    [InlineData("mgqmp1;abcdefghjk;47625;203.0.113.7")]
    [InlineData("mgqmp2;ABCDEFGHJKMNPQRS;r1")]
    [InlineData("mgqmp2;abcdefghjk;r1")]
    [InlineData("mgqmp2;abcdefghjkmnpqrs;R1")]
    [InlineData("mgqmp2;abcdefghjkmnpqrs;relay/r1")]
    public void Parse_TurnsDownAnythingElse(string? text) => Assert.Null(JoinCode.Parse(text));

    /// <summary>
    /// Asserts that a code pasted with white space around it still reads.
    /// </summary>
    [Fact]
    public void Parse_IgnoresSurroundingWhiteSpace() =>
        Assert.NotNull(JoinCode.Parse("  mgqmp2;abcdefghjkmnpqrs;r1\r\n"));

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
}
