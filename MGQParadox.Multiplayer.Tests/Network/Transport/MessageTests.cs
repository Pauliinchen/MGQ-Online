//----------------------------------------------------------------
//  MessageTests.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Dropped the frame tests, which went with the direct connection
//                            - Covered frames of bytes, and dropping frames of the earlier exchange
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQParadox.Multiplayer.Network.Transport;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Tests.Network.Transport;

/// <summary>
/// Covers the messages two games swap.
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
}
