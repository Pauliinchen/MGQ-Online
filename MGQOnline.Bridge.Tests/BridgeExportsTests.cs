//----------------------------------------------------------------
//  BridgeExportsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Bridge.Native;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Bridge.Tests;

/// <summary>
/// Covers the four exports as the scripts call them, through their unmanaged entry points, over a
/// host installed for each test.
/// </summary>
/// <remarks>
/// The exports share one host per process, so every test that installs one lives in this class,
/// whose tests run one at a time.
/// </remarks>
public sealed unsafe class BridgeExportsTests
{
    /// <summary>
    /// The size of the scripts' reply buffer in these tests.
    /// </summary>
    private const int ReplySize = 4096;

    /// <summary>
    /// mp_bridge_open as the scripts reach it.
    /// </summary>
    private static readonly delegate* unmanaged[Stdcall]<int, byte*, int, int> OpenExport = &BridgeExports.Open;

    /// <summary>
    /// mp_call as the scripts reach it.
    /// </summary>
    private static readonly delegate* unmanaged[Stdcall]<int, byte*, byte*, int, byte*, int, int> CallExport = &BridgeExports.Call;

    /// <summary>
    /// mp_reply as the scripts reach it.
    /// </summary>
    private static readonly delegate* unmanaged[Stdcall]<int, byte*, int, int> ReplyExport = &BridgeExports.Reply;

    /// <summary>
    /// mp_drain as the scripts reach it.
    /// </summary>
    private static readonly delegate* unmanaged[Stdcall]<int, int, byte*, int, int> DrainExport = &BridgeExports.Drain;

    /// <summary>
    /// The log the installed host writes to.
    /// </summary>
    private readonly ListLog _log = new();

    /// <summary>
    /// The Strings the "test.append" topic got, in order.
    /// </summary>
    private readonly List<string> _appended = [];

    /// <summary>
    /// How often the "big" topic ran.
    /// </summary>
    private int _bigRuns;

    /// <summary>
    /// Installs a host whose contexts have "test.append", "big", which answers more than the reply
    /// buffer holds, and a frame step that posts the frame it saw.
    /// </summary>
    public BridgeExportsTests()
    {
        BridgeExports.Install(new BridgeHost("0.6.9", _log, context =>
        {
            context.Register("test.append", (_, request) =>
            {
                _appended.Add(request.AsText());
                return null;
            });
            context.Register("big", (_, _) =>
            {
                _bigRuns++;
                return new string('x', ReplySize * 2);
            });
            context.EveryFrame(open => open.Events.Post("frame", open.Frame));
        }));
    }

    /// <summary>
    /// Asserts that a reply too large for the scripts' buffer is parked by mp_call, handed out by
    /// mp_reply into a larger one, and that its handler ran once.
    /// </summary>
    [Fact]
    public void Call_ParksAReplyThatMpReplyHandsOut()
    {
        int context = Open();
        byte[] small = new byte[ReplySize];

        int needed = -Call(context, "big", [], small);
        byte[] large = new byte[needed];
        int written;
        fixed (byte* buffer = large)
        {
            written = ReplyExport(context, buffer, large.Length);
        }

        Assert.True(needed > ReplySize);
        Assert.Equal(needed, written);
        Assert.Equal(new string('x', ReplySize * 2), RubyMarshal.Read(large).AsHash()["value"].AsText());
        Assert.Equal(1, _bigRuns);
    }

    /// <summary>
    /// Asserts that a second handshake, as after F12, closes the context of the first.
    /// </summary>
    [Fact]
    public void Open_ClosesTheContextOfTheHandshakeBefore()
    {
        int older = Open();
        int newer = Open();
        byte[] reply = new byte[ReplySize];

        int written = Call(older, "test.append", RubyMarshal.Write("lost"), reply);

        Assert.NotEqual(older, newer);
        Assert.Equal(BridgeEnvelope.BadRequest, RubyMarshal.Read(reply.AsSpan(0, written)).AsHash()["error"].AsText());
        Assert.Empty(_appended);
    }

    /// <summary>
    /// Asserts that the batch the scripts send once a frame runs its entries in order.
    /// </summary>
    [Fact]
    public void Call_RunsABatchInOrder()
    {
        int context = Open();

        int written = Call(context, BridgeContext.BatchTopic, Fixtures.Topic("batch", "in_order", "request"), new byte[ReplySize]);

        Assert.Equal(0, written);
        Assert.Equal(new[] { "a", "b", "c" }, _appended);
    }

    /// <summary>
    /// Asserts that mp_drain hands out the events of the frame the scripts passed.
    /// </summary>
    [Fact]
    public void Drain_HandsOutTheEventsOfTheFramePassed()
    {
        int context = Open();
        byte[] events = new byte[ReplySize];

        int written;
        fixed (byte* buffer = events)
        {
            written = DrainExport(context, 42, buffer, events.Length);
        }

        Assert.Equal(new RubyArray { new RubyArray { "frame", 42 } }, RubyMarshal.Read(events.AsSpan(0, written)));
    }

    /// <summary>
    /// Shakes hands through mp_bridge_open.
    /// </summary>
    /// <returns>The context's id.</returns>
    private static int Open()
    {
        byte[] reply = new byte[ReplySize];
        int written;
        fixed (byte* buffer = reply)
        {
            written = OpenExport(BridgeHost.Version, buffer, reply.Length);
        }

        return RubyMarshal.Read(reply.AsSpan(0, written)).AsHash()["value"].AsHash()["context"].AsInt();
    }

    /// <summary>
    /// Calls a topic through mp_call, its name null-terminated as the scripts pass it.
    /// </summary>
    /// <param name="context">The context's id.</param>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request as Marshal.</param>
    /// <param name="reply">The reply buffer.</param>
    /// <returns>What mp_call returned.</returns>
    private static int Call(int context, string topic, byte[] request, byte[] reply)
    {
        byte[] name = System.Text.Encoding.UTF8.GetBytes(topic + "\0");
        fixed (byte* namePointer = name, requestPointer = request, replyPointer = reply)
        {
            return CallExport(context, namePointer, requestPointer, request.Length, replyPointer, reply.Length);
        }
    }
}
