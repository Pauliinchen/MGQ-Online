//----------------------------------------------------------------
//  BridgeHostTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Covered a second handshake closing the older context
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Bridge.Tests;

/// <summary>
/// Covers the handshake and the routing of calls to a context by its id.
/// </summary>
public sealed class BridgeHostTests
{
    /// <summary>
    /// The log the host under test writes to.
    /// </summary>
    private readonly ListLog _log = new();

    /// <summary>
    /// The host under test, whose contexts have a "ping" topic.
    /// </summary>
    private readonly BridgeHost _host;

    /// <summary>
    /// Creates the host under test.
    /// </summary>
    public BridgeHostTests()
    {
        _host = new BridgeHost("0.6.9", _log, context => context.Register("ping", (_, _) => "pong"));
    }

    /// <summary>
    /// Asserts that the handshake opens a context named by its id, which then answers calls.
    /// </summary>
    [Fact]
    public void Open_OpensAContextThatAnswersCalls()
    {
        RubyHash value = Open(BridgeHost.Version)["value"].AsHash();
        int context = value["context"].AsInt();
        byte[] buffer = new byte[256];
        int written = _host.Call(context, "ping"u8, [], buffer);

        Assert.Equal(BridgeHost.Version, value["bridge"].AsInt());
        Assert.Equal("0.6.9", value["build"].AsText());
        Assert.Equal(new[] { BridgeContext.BatchTopic, "ping" }, value["topics"].AsArray().Select(topic => topic.AsText()));
        Assert.Equal("pong", RubyMarshal.Read(buffer.AsSpan(0, written)).AsHash()["value"].AsText());
    }

    /// <summary>
    /// Asserts that a handshake of another version is refused and opens no context.
    /// </summary>
    [Fact]
    public void Open_RefusesAnotherVersion()
    {
        RubyHash reply = Open(BridgeHost.Version + 1);

        Assert.Equal(BridgeEnvelope.BadRequest, reply["error"].AsText());
        Assert.Contains("bridge version 2", reply["text"].AsText(), StringComparison.Ordinal);
        Assert.Null(_host.Find(1));
    }

    /// <summary>
    /// Asserts that a second handshake, as F12 makes the scripts send, closes the older context.
    /// </summary>
    [Fact]
    public void Open_ClosesTheOlderContexts()
    {
        int older = Open(BridgeHost.Version)["value"].AsHash()["context"].AsInt();
        int newer = Open(BridgeHost.Version)["value"].AsHash()["context"].AsInt();

        Assert.Null(_host.Find(older));
        Assert.NotNull(_host.Find(newer));
        Assert.Contains($"Bridge closed context {older}.", _log.Lines);
    }

    /// <summary>
    /// Runs the handshake with a large buffer.
    /// </summary>
    /// <param name="version">The version the scripts speak.</param>
    /// <returns>The reply.</returns>
    private RubyHash Open(int version)
    {
        byte[] buffer = new byte[1024];
        int written = _host.Open(version, buffer);
        return RubyMarshal.Read(buffer.AsSpan(0, written)).AsHash();
    }
}
