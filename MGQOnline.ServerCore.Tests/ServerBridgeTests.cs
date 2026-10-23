//----------------------------------------------------------------
//  ServerBridgeTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Text;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Native;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.ServerCore.Tests;

/// <summary>
/// Covers the core as the battle server reaches it: the four exports over the host
/// <see cref="ServerBridge"/> installs, its log leaving as events, and its topics.
/// </summary>
/// <remarks>
/// The exports share one host per process, so every test lives in this class, whose tests run one
/// at a time, and each installs a host of its own.
/// </remarks>
public sealed unsafe class ServerBridgeTests
{
    /// <summary>
    /// The size of the scripts' buffers in these tests.
    /// </summary>
    private const int BufferSize = 4096;

    /// <summary>
    /// mp_bridge_open as the battle server reaches it.
    /// </summary>
    private static readonly delegate* unmanaged[Stdcall]<int, byte*, int, int> OpenExport = &BridgeExports.Open;

    /// <summary>
    /// mp_call as the battle server reaches it.
    /// </summary>
    private static readonly delegate* unmanaged[Stdcall]<int, byte*, byte*, int, byte*, int, int> CallExport = &BridgeExports.Call;

    /// <summary>
    /// mp_drain as the battle server reaches it.
    /// </summary>
    private static readonly delegate* unmanaged[Stdcall]<int, int, byte*, int, int> DrainExport = &BridgeExports.Drain;

    /// <summary>
    /// Installs a new host, as the core does as its runtime starts.
    /// </summary>
    public ServerBridgeTests()
    {
        ServerBridge.Install();
    }

    /// <summary>
    /// Asserts that the handshake names the core's build and topics, and that its log line comes
    /// out of the first drain as a log event.
    /// </summary>
    [Fact]
    public void Open_NamesTheBuildAndLogsThroughTheDrain()
    {
        RubyHash handshake = Open(BridgeHost.Version).AsHash()["value"].AsHash();
        int context = handshake["context"].AsInt();

        Assert.Equal("0.0.0-dev", handshake["build"].AsText());
        Assert.Contains((RubyValue)ServerBridge.RuntimeTopic, handshake["topics"].AsArray());
        Assert.Equal(new RubyArray { new RubyArray { EventLog.Topic, $"Bridge {BridgeHost.Version} opened context {context} with 2 topics." } }, Drain(context));
    }

    /// <summary>
    /// Asserts that a line logged while no context is open, such as a refused handshake's, comes out
    /// of the next context's first drain, before that handshake's own line.
    /// </summary>
    [Fact]
    public void Write_KeepsTheLinesBeforeTheFirstContextForIt()
    {
        Open(BridgeHost.Version + 1);
        int context = Open(BridgeHost.Version).AsHash()["value"].AsHash()["context"].AsInt();

        RubyArray events = Drain(context);

        Assert.Equal(2, events.Count);
        Assert.StartsWith("Bridge handshake refused", events[0].AsArray()[1].AsText(), StringComparison.Ordinal);
        Assert.StartsWith("Bridge 1 opened context", events[1].AsArray()[1].AsText(), StringComparison.Ordinal);
    }

    /// <summary>
    /// Asserts that core.runtime describes the GC with plain values.
    /// </summary>
    [Fact]
    public void Call_DescribesTheRuntime()
    {
        int context = Open(BridgeHost.Version).AsHash()["value"].AsHash()["context"].AsInt();
        byte[] reply = new byte[BufferSize];
        byte[] topic = Encoding.UTF8.GetBytes(ServerBridge.RuntimeTopic + "\0");
        int written;
        fixed (byte* topicPointer = topic, replyPointer = reply)
        {
            written = CallExport(context, topicPointer, null, 0, replyPointer, reply.Length);
        }

        RubyHash runtime = RubyMarshal.Read(reply.AsSpan(0, written)).AsHash()["value"].AsHash();

        Assert.True(runtime["heap_limit"].AsLong() > 0);
        Assert.False(runtime["server_gc"].AsBool());
        Assert.NotEmpty(runtime["latency"].AsText());
    }

    /// <summary>
    /// Shakes hands through mp_bridge_open.
    /// </summary>
    /// <param name="version">The bridge version the scripts speak.</param>
    /// <returns>The reply's envelope.</returns>
    private static RubyValue Open(int version)
    {
        byte[] reply = new byte[BufferSize];
        int written;
        fixed (byte* buffer = reply)
        {
            written = OpenExport(version, buffer, reply.Length);
        }

        return RubyMarshal.Read(reply.AsSpan(0, written));
    }

    /// <summary>
    /// Takes a context's events through mp_drain.
    /// </summary>
    /// <param name="context">The context's id.</param>
    /// <returns>The events as [[topic, payload], ...].</returns>
    private static RubyArray Drain(int context)
    {
        byte[] events = new byte[BufferSize];
        int written;
        fixed (byte* buffer = events)
        {
            written = DrainExport(context, 1, buffer, events.Length);
        }

        return RubyMarshal.Read(events.AsSpan(0, written)).AsArray();
    }
}
