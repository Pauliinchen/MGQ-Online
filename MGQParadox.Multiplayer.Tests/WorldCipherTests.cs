//----------------------------------------------------------------
//  WorldCipherTests.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System.Text;
using MGQParadox.Multiplayer.Network;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Covers the encryption of the frames between the games of a world.
/// </summary>
public sealed class WorldCipherTests
{
    /// <summary>
    /// The world's token every game shares.
    /// </summary>
    private const string Token = "abcdefghjkmnpqrs";

    /// <summary>
    /// Asserts that every game reads every other's frames, whose text is not readable on the way.
    /// </summary>
    [Fact]
    public void Frames_PassBetweenAnyGames()
    {
        var first = new WorldCipher(Token);
        var second = new WorldCipher(Token);
        var third = new WorldCipher(Token);

        var hello = first.Seal(0, Bytes("hello=First"));

        Assert.Equal("hello=First".Length + WorldCipher.Overhead, hello.Length);
        Assert.DoesNotContain("First", Encoding.UTF8.GetString(hello));
        Assert.Equal("hello=First", Text(second.Open(0, hello)));
        Assert.Equal("hello=First", Text(third.Open(0, hello)));
        Assert.Equal("pos", Text(first.Open(2, third.Seal(2, Bytes("pos")))));
    }

    /// <summary>
    /// Asserts that a sender's frames may skip counters, since some went to other seats only, but never go back.
    /// </summary>
    [Fact]
    public void Counters_MayGrowByMoreThanOneButNeverRepeat()
    {
        var sender = new WorldCipher(Token);
        var receiver = new WorldCipher(Token);

        var first = sender.Seal(1, Bytes("a"));
        sender.Seal(1, Bytes("for someone else"));
        var third = sender.Seal(1, Bytes("c"));

        Assert.Equal("a", Text(receiver.Open(1, first)));
        Assert.Equal("c", Text(receiver.Open(1, third)));
        Assert.Null(receiver.Open(1, third));
        Assert.Null(receiver.Open(1, first));
    }

    /// <summary>
    /// Asserts that a frame passed on under another seat, changed on the way or made with another token fails the check.
    /// </summary>
    [Fact]
    public void WrongSeatChangeOrToken_FailsTheCheck()
    {
        var sender = new WorldCipher(Token);
        var receiver = new WorldCipher(Token);
        var frame = sender.Seal(1, Bytes("pos"));

        Assert.Null(receiver.Open(2, frame));

        var changed = (byte[])frame.Clone();
        changed[^1] ^= 1;
        Assert.Null(receiver.Open(1, changed));

        Assert.Null(receiver.Open(1, new WorldCipher("zzzzzzzzzzzzzzzz").Seal(1, Bytes("pos"))));
        Assert.Null(receiver.Open(1, new byte[WorldCipher.Overhead - 1]));
        Assert.Equal("pos", Text(receiver.Open(1, frame)));
    }

    /// <summary>
    /// Asserts that a seat taken by another game starts over with that game's key, and that the
    /// earlier game's frames are refused from then on, also after the seat was given up.
    /// </summary>
    [Fact]
    public void NewGameOnASeat_RetiresTheEarlierOne()
    {
        var receiver = new WorldCipher(Token);
        var earlier = new WorldCipher(Token);
        var later = new WorldCipher(Token);
        var lateFrame = earlier.Seal(1, Bytes("late"));

        Assert.Equal("first", Text(receiver.Open(1, earlier.Seal(1, Bytes("first")))));
        Assert.Equal("hello", Text(receiver.Open(1, later.Seal(1, Bytes("hello")))));
        Assert.Null(receiver.Open(1, lateFrame));

        var leaving = new WorldCipher(Token);
        Assert.Equal("hi", Text(receiver.Open(3, leaving.Seal(3, Bytes("hi")))));
        var afterLeaving = leaving.Seal(3, Bytes("gone"));
        receiver.Forget(3);
        Assert.Null(receiver.Open(3, afterLeaving));
    }

    /// <summary>
    /// Turns a text into bytes.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>Its UTF-8 bytes.</returns>
    private static byte[] Bytes(string text) => Encoding.UTF8.GetBytes(text);

    /// <summary>
    /// Turns bytes into a text.
    /// </summary>
    /// <param name="bytes">The bytes, or <see langword="null"/>.</param>
    /// <returns>The text, or <see langword="null"/>.</returns>
    private static string? Text(byte[]? bytes) => bytes == null ? null : Encoding.UTF8.GetString(bytes);
}
