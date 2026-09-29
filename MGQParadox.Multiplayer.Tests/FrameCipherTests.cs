//----------------------------------------------------------------
//  FrameCipherTests.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System.Text;
using MGQParadox.Multiplayer.Network;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Covers the encryption of the frames between two games.
/// </summary>
public sealed class FrameCipherTests
{
    /// <summary>
    /// The join code token both sides share.
    /// </summary>
    private const string Token = "abcdefghjk";

    /// <summary>
    /// Asserts that frames pass both ways and in order, and that their text is not readable on the way.
    /// </summary>
    [Fact]
    public void Frames_PassBothWaysInOrder()
    {
        var host = new FrameCipher(Token, host: true);
        var guest = new FrameCipher(Token, host: false);

        var first = guest.Seal(Encoding.UTF8.GetBytes("player=Guest"));
        var second = guest.Seal(Encoding.UTF8.GetBytes("ready"));

        Assert.Equal("player=Guest".Length + FrameCipher.Overhead, first.Length);
        Assert.DoesNotContain("Guest", Encoding.UTF8.GetString(first));
        Assert.Equal("player=Guest", Encoding.UTF8.GetString(host.Open(first)!));
        Assert.Equal("ready", Encoding.UTF8.GetString(host.Open(second)!));
        Assert.Equal("turn", Encoding.UTF8.GetString(guest.Open(host.Seal(Encoding.UTF8.GetBytes("turn")))!));
    }

    /// <summary>
    /// Asserts that a frame made with another join code's token fails the check.
    /// </summary>
    [Fact]
    public void AnotherToken_FailsTheCheck()
    {
        var host = new FrameCipher(Token, host: true);
        var stranger = new FrameCipher("zzzzzzzzzz", host: false);

        Assert.Null(host.Open(stranger.Seal(Encoding.UTF8.GetBytes("ready"))));
    }

    /// <summary>
    /// Asserts that a frame changed on the way fails the check.
    /// </summary>
    [Fact]
    public void ChangedFrame_FailsTheCheck()
    {
        var host = new FrameCipher(Token, host: true);
        var frame = new FrameCipher(Token, host: false).Seal(Encoding.UTF8.GetBytes("ready"));

        frame[10] ^= 1;

        Assert.Null(host.Open(frame));
    }

    /// <summary>
    /// Asserts that a frame repeated or left out fails the check, since each must carry the next counter.
    /// </summary>
    [Fact]
    public void RepeatedOrMissingFrame_FailsTheCheck()
    {
        var host = new FrameCipher(Token, host: true);
        var guest = new FrameCipher(Token, host: false);
        var first = guest.Seal(Encoding.UTF8.GetBytes("one"));
        var second = guest.Seal(Encoding.UTF8.GetBytes("two"));
        var third = guest.Seal(Encoding.UTF8.GetBytes("three"));

        Assert.NotNull(host.Open(first));
        Assert.Null(host.Open(first));
        Assert.Null(host.Open(third));
        Assert.NotNull(host.Open(second));
    }

    /// <summary>
    /// Asserts that a frame sent back to its sender fails the check, since each direction has its own nonces.
    /// </summary>
    [Fact]
    public void FrameSentBack_FailsTheCheck()
    {
        var host = new FrameCipher(Token, host: true);

        Assert.Null(host.Open(host.Seal(Encoding.UTF8.GetBytes("ready"))));
    }

    /// <summary>
    /// Asserts that a frame too short to carry the counter and tag fails the check.
    /// </summary>
    [Fact]
    public void TooShortFrame_FailsTheCheck()
    {
        Assert.Null(new FrameCipher(Token, host: true).Open(new byte[FrameCipher.Overhead - 1]));
    }
}
