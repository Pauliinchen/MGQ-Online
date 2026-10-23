//----------------------------------------------------------------
//  BridgeContextTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Covered a topic asked in-process
//                            - Covered the batch topic and checked the unknown topic against its contract fixture
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Bridge.Tests;

/// <summary>
/// Covers the dispatcher: replies in their envelope, the errors it answers, and replies parked when
/// they do not fit the caller's buffer.
/// </summary>
public sealed class BridgeContextTests
{
    /// <summary>
    /// The log the context under test writes to.
    /// </summary>
    private readonly ListLog _log = new();

    /// <summary>
    /// The context under test, with an "echo" topic that answers its request.
    /// </summary>
    private readonly BridgeContext _context;

    /// <summary>
    /// Creates the context under test.
    /// </summary>
    public BridgeContextTests()
    {
        _context = new BridgeContext(1, _log);
        _context.Register("echo", (_, request) => request);
    }

    /// <summary>
    /// Asserts that a handler's value comes back in the envelope and the call is counted.
    /// </summary>
    [Fact]
    public void Call_AnswersTheValueInTheEnvelopeAndCountsTheCall()
    {
        var request = new RubyHash { { "seat", 2 } };
        byte[] dump = RubyMarshal.Write(request);

        RubyHash reply = Call("echo", dump);

        Assert.Equal(BridgeEnvelope.Ok(request), reply);
        Assert.Equal(1, _context.Counters["echo"].Calls);
        Assert.Equal(dump.Length, _context.Counters["echo"].BytesIn);
        Assert.Equal(RubyMarshal.Write(reply).Length, _context.Counters["echo"].BytesOut);
    }

    /// <summary>
    /// Asserts that a handler answering nil writes no reply.
    /// </summary>
    [Fact]
    public void Call_WritesNoReplyForNil()
    {
        byte[] buffer = new byte[256];

        Assert.Equal(0, _context.Call("echo"u8, [], buffer));
    }

    /// <summary>
    /// Asserts that a topic nobody registered answers unknown_topic, in the bytes the scripts expect.
    /// </summary>
    [Fact]
    public void Call_AnswersUnknownTopic()
    {
        byte[] reply = CallRaw("no.such.topic", Fixtures.Topic("envelope", "unknown_topic", "request"));

        Assert.Equal(Fixtures.Topic("envelope", "unknown_topic", "reply"), reply);
        Assert.Equal(BridgeEnvelope.Error(BridgeEnvelope.UnknownTopic, "There is no topic no.such.topic."), RubyMarshal.Read(reply));
    }

    /// <summary>
    /// Asserts that a batch runs its entries in order and, when all ran, answers nothing.
    /// </summary>
    [Fact]
    public void Batch_RunsEachEntryInOrder()
    {
        List<string> appended = RegisterAppend();

        byte[] reply = CallRaw(BridgeContext.BatchTopic, Fixtures.Topic("batch", "in_order", "request"));

        Assert.Empty(reply);
        Assert.Empty(Fixtures.Topic("batch", "in_order", "reply"));
        Assert.Equal(new[] { "a", "b", "c" }, appended);
        Assert.Equal(3, _context.Counters["test.append"].Calls);
    }

    /// <summary>
    /// Asserts that a batch runs the entries after one that failed and answers the failed ones.
    /// </summary>
    [Fact]
    public void Batch_AnswersTheEntriesThatFailed()
    {
        List<string> appended = RegisterAppend();

        byte[] reply = CallRaw(BridgeContext.BatchTopic, Fixtures.Topic("batch", "failed_entries", "request"));

        Assert.Equal(Fixtures.Topic("batch", "failed_entries", "reply"), reply);
        Assert.Equal(new[] { "a", "d" }, appended);
    }

    /// <summary>
    /// Asserts that a batch with an entry that is no pair runs none of its entries.
    /// </summary>
    [Fact]
    public void Batch_RunsNothingOfABrokenBatch()
    {
        List<string> appended = RegisterAppend();
        var batch = new RubyArray { new RubyArray { "test.append", "a" }, "test.append" };

        RubyHash reply = Call(BridgeContext.BatchTopic, RubyMarshal.Write(batch));

        Assert.Equal(BridgeEnvelope.Error(BridgeEnvelope.BadRequest, "Expected an Array, found a String."), reply);
        Assert.Empty(appended);
    }

    /// <summary>
    /// Asserts that a refused request and a handler that names what its request lacks answer bad_request.
    /// </summary>
    [Fact]
    public void Call_AnswersBadRequest()
    {
        _context.Register("seat", (_, request) => request.AsHash()["seat"].IsNil ? throw new BridgeRequestException("The seat is missing.") : null);

        RubyHash refused = Call("echo", Fixtures.Codec("object"));
        RubyHash missing = Call("seat", RubyMarshal.Write(new RubyHash()));

        Assert.Equal(BridgeEnvelope.Error(BridgeEnvelope.BadRequest, "RPG::Item cannot cross the bridge."), refused);
        Assert.Equal(BridgeEnvelope.Error(BridgeEnvelope.BadRequest, "The seat is missing."), missing);
    }

    /// <summary>
    /// Asserts that a handler that throws answers internal, logged once and counted each time.
    /// </summary>
    [Fact]
    public void Call_TurnsAnExceptionIntoAnInternalError()
    {
        _context.Register("broken", (_, _) => throw new InvalidOperationException("The model is gone."));

        RubyHash first = Call("broken", []);
        Call("broken", []);

        Assert.Equal(BridgeEnvelope.Error(BridgeEnvelope.Internal, "The model is gone."), first);
        Assert.Single(_log.Lines, line => line.StartsWith("Bridge topic broken answered internal", StringComparison.Ordinal));
        Assert.Equal(2, _context.Counters["broken"].Errors);
    }

    /// <summary>
    /// Asserts that a reply too large for the buffer is parked, handed out once a large enough buffer
    /// comes, and that its handler ran once.
    /// </summary>
    [Fact]
    public void Call_ParksAReplyThatDoesNotFitAndRunsTheHandlerOnce()
    {
        int runs = 0;
        _context.Register("big", (_, _) =>
        {
            runs++;
            return new string('x', 1000);
        });

        int needed = -_context.Call("big"u8, [], new byte[16]);
        int stillParked = _context.TakeReply(new byte[16]);
        byte[] buffer = new byte[needed];
        int written = _context.TakeReply(buffer);

        Assert.True(needed > 1000);
        Assert.Equal(-needed, stillParked);
        Assert.Equal(needed, written);
        Assert.Equal(new string('x', 1000), RubyMarshal.Read(buffer).AsHash()["value"].AsText());
        Assert.Equal(0, _context.TakeReply(buffer));
        Assert.Equal(1, runs);
    }

    /// <summary>
    /// Registers the contract fixtures' "test.append" topic, which collects the Strings it gets.
    /// </summary>
    /// <returns>The Strings it got, in order.</returns>
    private List<string> RegisterAppend()
    {
        List<string> appended = [];
        _context.Register("test.append", (_, request) =>
        {
            appended.Add(request.AsText());
            return null;
        });
        return appended;
    }

    /// <summary>
    /// Calls a topic with a large buffer.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request as Marshal.</param>
    /// <returns>The reply.</returns>
    private RubyHash Call(string topic, byte[] request)
    {
        byte[] reply = CallRaw(topic, request);
        Assert.True(reply.Length > 0, $"{topic} wrote no reply");
        return RubyMarshal.Read(reply).AsHash();
    }

    /// <summary>
    /// Calls a topic with a large buffer and keeps the reply's bytes.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request as Marshal.</param>
    /// <returns>The reply's bytes, none for no reply.</returns>
    private byte[] CallRaw(string topic, byte[] request)
    {
        byte[] buffer = new byte[4096];
        int written = _context.Call(System.Text.Encoding.UTF8.GetBytes(topic), request, buffer);
        Assert.True(written >= 0, $"{topic} parked its reply ({written})");
        return buffer[..written];
    }

    /// <summary>
    /// Asserts that a handler asks another topic in-process for its plain value, and that a topic
    /// without a handler throws.
    /// </summary>
    [Fact]
    public void Ask_RunsAnotherTopicInProcess()
    {
        _context.Register("double", (_, request) => request.AsInt() * 2);
        _context.Register("nothing", (_, _) => null);

        Assert.Equal(new RubyInteger(6), _context.Ask("double", 3));
        Assert.Null(_context.Ask("nothing"));
        Assert.Throws<BridgeRequestException>(() => _context.Ask("missing"));
    }
}
