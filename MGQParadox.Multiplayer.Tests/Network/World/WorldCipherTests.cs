//----------------------------------------------------------------
//  WorldCipherTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-06: Covered the target seat each frame names, and a new salt per connection that keeps what the others sent
//      Paulinchen  2026-09-29: Created
//
//----------------------------------------------------------------

using System.Text;
using MGQParadox.Multiplayer.Network.Relay;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Tests.Network.World;

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
    /// The target seat of a frame for every other game.
    /// </summary>
    private const int Everyone = RelayWorldChannel.Everyone;

    /// <summary>
    /// Asserts that every game reads every other's frames, whose text is not readable on the way.
    /// </summary>
    [Fact]
    public void Frames_PassBetweenAnyGames()
    {
        var first = new WorldCipher(Token);
        var second = new WorldCipher(Token);
        var third = new WorldCipher(Token);

        var hello = first.Seal(0, Everyone, Bytes("hello=First"));

        Assert.Equal("hello=First".Length + WorldCipher.Overhead, hello.Length);
        Assert.DoesNotContain("First", Encoding.UTF8.GetString(hello));
        Assert.Equal("hello=First", Text(second.Open(0, 1, hello)));
        Assert.Equal("hello=First", Text(third.Open(0, 2, hello)));
        Assert.Equal("pos", Text(first.Open(2, 0, third.Seal(2, 0, Bytes("pos")))));
    }

    /// <summary>
    /// Asserts that a frame for one game is read by that game only, even when the target the relay reads is changed on the way.
    /// </summary>
    [Fact]
    public void FrameForOneGame_IsReadByThatGameOnly()
    {
        var sender = new WorldCipher(Token);
        var meant = new WorldCipher(Token);
        var other = new WorldCipher(Token);
        var frame = sender.Seal(0, 1, Bytes("secret"));

        Assert.Null(other.Open(0, 2, frame));

        var redirected = (byte[])frame.Clone();
        redirected[24] = Everyone;
        Assert.Null(other.Open(0, 2, redirected));

        Assert.Equal("secret", Text(meant.Open(0, 1, frame)));
    }

    /// <summary>
    /// Asserts that a sender's frames may skip counters, since some went to other seats only, but never go back.
    /// </summary>
    [Fact]
    public void Counters_MayGrowByMoreThanOneButNeverRepeat()
    {
        var sender = new WorldCipher(Token);
        var receiver = new WorldCipher(Token);

        var first = sender.Seal(1, Everyone, Bytes("a"));
        sender.Seal(1, 3, Bytes("for someone else"));
        var third = sender.Seal(1, Everyone, Bytes("c"));

        Assert.Equal("a", Text(receiver.Open(1, 0, first)));
        Assert.Equal("c", Text(receiver.Open(1, 0, third)));
        Assert.Null(receiver.Open(1, 0, third));
        Assert.Null(receiver.Open(1, 0, first));
    }

    /// <summary>
    /// Asserts that a frame passed on under another seat, changed on the way or made with another token fails the check.
    /// </summary>
    [Fact]
    public void WrongSeatChangeOrToken_FailsTheCheck()
    {
        var sender = new WorldCipher(Token);
        var receiver = new WorldCipher(Token);
        var frame = sender.Seal(1, Everyone, Bytes("pos"));

        Assert.Null(receiver.Open(2, 0, frame));

        var changed = (byte[])frame.Clone();
        changed[^1] ^= 1;
        Assert.Null(receiver.Open(1, 0, changed));

        Assert.Null(receiver.Open(1, 0, new WorldCipher("zzzzzzzzzzzzzzzz").Seal(1, Everyone, Bytes("pos"))));
        Assert.Null(receiver.Open(1, 0, new byte[WorldCipher.Overhead - 1]));
        Assert.Equal("pos", Text(receiver.Open(1, 0, frame)));
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
        var lateFrame = earlier.Seal(1, Everyone, Bytes("late"));

        Assert.Equal("first", Text(receiver.Open(1, 0, earlier.Seal(1, Everyone, Bytes("first")))));
        Assert.Equal("hello", Text(receiver.Open(1, 0, later.Seal(1, Everyone, Bytes("hello")))));
        Assert.Null(receiver.Open(1, 0, lateFrame));

        var leaving = new WorldCipher(Token);
        Assert.Equal("hi", Text(receiver.Open(3, 0, leaving.Seal(3, Everyone, Bytes("hi")))));
        var afterLeaving = leaving.Seal(3, Everyone, Bytes("gone"));
        receiver.Forget(3);
        Assert.Null(receiver.Open(3, 0, afterLeaving));
    }

    /// <summary>
    /// Asserts that a game's new connection sends under a new salt, which the others read like a new
    /// game's, while frames it read before are refused again.
    /// </summary>
    [Fact]
    public void Renew_StartsANewSenderButKeepsWhatWasRead()
    {
        var game = new WorldCipher(Token);
        var other = new WorldCipher(Token);
        var seen = other.Seal(1, Everyone, Bytes("before the break"));
        var before = game.Seal(0, Everyone, Bytes("old salt"));

        Assert.NotNull(game.Open(1, 0, seen));
        Assert.NotNull(other.Open(0, 1, before));

        game.Renew();
        Assert.Null(game.Open(1, 0, seen));

        other.Forget(0);
        Assert.Equal("new salt", Text(other.Open(0, 1, game.Seal(0, Everyone, Bytes("new salt")))));
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
