//----------------------------------------------------------------
//  MessageTests.cs
//
//  Changelog:
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.IO;
using System.Text;
using MGQParadox.Multiplayer.Network;

namespace MGQParadox.Multiplayer.Tests;

/// <summary>
/// Covers the messages two games swap and the frames that carry them.
/// </summary>
public sealed class MessageTests
{
    /// <summary>
    /// Asserts that a message reads back with its headers and its team unchanged.
    /// </summary>
    [Fact]
    public void Encode_ReadsBack()
    {
        var headers = new KeyValuePair<string, string?>[] { new(Message.Player, "Guest"), new(Message.Game, "3.06") };
        var team = "member=1;50\nmember=2;48\n";

        var message = Message.Decode(new Message(headers, team).Encode());

        Assert.Equal("Guest", message[Message.Player]);
        Assert.Equal("3.06", message[Message.Game]);
        Assert.Equal(team, message.Team);
    }

    /// <summary>
    /// Asserts that a header value with a line break stays on its line, so it cannot add a header.
    /// </summary>
    [Fact]
    public void Encode_KeepsHeaderValuesOnTheirLine()
    {
        var headers = new KeyValuePair<string, string?>[] { new(Message.Player, "Guest\nrefused=no") };

        var message = Message.Decode(new Message(headers).Encode());

        Assert.Equal("Guest refused=no", message[Message.Player]);
        Assert.Equal(string.Empty, message[Message.Refused]);
    }

    /// <summary>
    /// Asserts that empty headers are left out and missing ones read as empty.
    /// </summary>
    [Fact]
    public void Encode_LeavesOutEmptyHeaders()
    {
        var headers = new KeyValuePair<string, string?>[] { new(Message.Player, null), new(Message.Game, "") };

        Assert.Equal("\n", new Message(headers).Encode());
        Assert.Equal(string.Empty, Message.Decode("\n")[Message.Player]);
    }

    /// <summary>
    /// Asserts that a frame carries its text through a stream.
    /// </summary>
    [Fact]
    public void Frame_CarriesTheText()
    {
        using var stream = new MemoryStream();

        Frame.Write(stream, "player=Guest\n\nmember=1");
        stream.Position = 0;

        Assert.Equal("player=Guest\n\nmember=1", Frame.Read(stream));
    }

    /// <summary>
    /// Asserts that anything without the frame's marker is dropped.
    /// </summary>
    [Fact]
    public void Frame_DropsForeignData()
    {
        using var stream = new MemoryStream(Encoding.ASCII.GetBytes("GET / HTTP/1.1\r\nHost: example.com\r\n\r\n"));

        Assert.Null(Frame.Read(stream));
    }

    /// <summary>
    /// Asserts that a frame claiming more than the limit is dropped before anything is read of it.
    /// </summary>
    [Fact]
    public void Frame_DropsOversizedFrames()
    {
        using var stream = new MemoryStream();
        stream.Write("MGQFB1"u8);
        stream.Write(System.BitConverter.GetBytes(Frame.MaxBodyBytes + 1));
        stream.Position = 0;

        Assert.Null(Frame.Read(stream));
    }

    /// <summary>
    /// Asserts that writing a text over the limit fails instead of sending it.
    /// </summary>
    [Fact]
    public void Frame_RefusesToWriteOversizedTexts()
    {
        using var stream = new MemoryStream();

        Assert.Throws<InvalidDataException>(() => Frame.Write(stream, new string('a', Frame.MaxBodyBytes + 1)));
    }
}
