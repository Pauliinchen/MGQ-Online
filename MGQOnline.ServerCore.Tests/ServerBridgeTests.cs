//----------------------------------------------------------------
//  ServerBridgeTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Covered a battle's players arranged by the core
//                            - Covered the squad rules the core answers
//                            - Covered the topics both hosts answer
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Text;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Native;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Topics;

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
        Assert.Equal(new RubyArray { new RubyArray { EventLog.Topic, $"Bridge {BridgeHost.Version} opened context {context} with {handshake["topics"].AsArray().Count} topics." } }, Drain(context));
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

        RubyHash runtime = Call(context, ServerBridge.RuntimeTopic, null).AsHash()["value"].AsHash();

        Assert.True(runtime["heap_limit"].AsLong() > 0);
        Assert.False(runtime["server_gc"].AsBool());
        Assert.NotEmpty(runtime["latency"].AsText());
    }

    /// <summary>
    /// Asserts that the core answers the topics both hosts answer, such as the ids the battle
    /// server's scripts make up, the squad rules and a battle's players arranged.
    /// </summary>
    [Fact]
    public void Call_AnswersTheSharedTopics()
    {
        int context = Open(BridgeHost.Version).AsHash()["value"].AsHash()["context"].AsInt();

        RubyValue id = Call(context, SharedTopics.RandomIdTopic, new RubyHash { { "length", 8L }, { "radix", 36L } }).AsHash()["value"];

        RubyValue squad = Call(context, SquadTopics.Default, null).AsHash()["value"];
        RubyHash arrange = new()
        {
            { "rules", squad },
            { "raid", false },
            { "backline", true },
            { "players", new RubyArray { new RubyArray { "b", false, 4L, 3L }, new RubyArray { "a", true, 4L, 3L } } },
        };
        RubyValue arranged = Call(context, SquadTopics.Arrange, arrange).AsHash()["value"];

        Assert.Matches("^[0-9a-z]{8}$", id.AsText());
        Assert.Equal(4, squad.AsHash()["formation"].AsInt());
        Assert.Equal(new RubyArray { new RubyArray { 1L, 1L, 2L }, new RubyArray { 0L, 1L, 2L } }, arranged);
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
    /// Calls a topic through mp_call.
    /// </summary>
    /// <param name="context">The context's id.</param>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request, <see langword="null"/> for none.</param>
    /// <returns>The reply's envelope.</returns>
    private static RubyValue Call(int context, string topic, RubyValue? request)
    {
        byte[] reply = new byte[BufferSize];
        byte[] name = Encoding.UTF8.GetBytes(topic + "\0");
        byte[] dump = request == null ? [] : RubyMarshal.Write(request);
        int written;
        fixed (byte* namePointer = name, dumpPointer = dump, replyPointer = reply)
        {
            written = CallExport(context, namePointer, dumpPointer, dump.Length, replyPointer, reply.Length);
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
