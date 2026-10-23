//----------------------------------------------------------------
//  BridgeContext.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Let a handler ask another topic in-process
//                            - Ran what the scripts staged in a frame through the batch topic
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Buffers;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Text;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Bridge;

/// <summary>
/// Answers one topic's request.
/// </summary>
/// <param name="context">The context the topic is registered on.</param>
/// <param name="request">The request, a plain value; nil when the caller sent none.</param>
/// <returns>The value the caller gets, a plain value; <see langword="null"/> or nil for no reply.</returns>
public delegate RubyValue? BridgeHandler(BridgeContext context, RubyValue request);

/// <summary>
/// One opened bridge: its topic handlers, its event queue, its clock and its counters. All state of the
/// core hangs off a context, so a process may hold many.
/// </summary>
/// <remarks>
/// Its methods run on the game thread only and never throw: every failure becomes an error reply and a
/// log line, since an exception crossing into the game ends it.
/// </remarks>
public sealed class BridgeContext
{
    /// <summary>
    /// The frames between two logs of the counters, 10 minutes at 60 frames a second.
    /// </summary>
    public const long CountersEveryFrames = 36_000;

    /// <summary>
    /// The name the drain's counters go under.
    /// </summary>
    public const string DrainCounters = "(drain)";

    /// <summary>
    /// The topic every context has, which runs what the scripts staged during a frame in one call.
    /// </summary>
    public const string BatchTopic = "batch";

    /// <summary>
    /// The handlers by topic.
    /// </summary>
    private readonly Dictionary<string, BridgeHandler> _handlers = new(StringComparer.Ordinal);

    /// <summary>
    /// The topics in the order they were registered.
    /// </summary>
    private readonly List<string> _topics = [];

    /// <summary>
    /// What runs at each drain before the events are taken.
    /// </summary>
    private readonly List<Action<BridgeContext>> _frameSteps = [];

    /// <summary>
    /// The counters by topic, since they were last logged.
    /// </summary>
    private readonly Dictionary<string, TopicCounters> _counters = new(StringComparer.Ordinal);

    /// <summary>
    /// The failures logged since the counters were last logged, by topic and error code.
    /// </summary>
    private readonly HashSet<string> _loggedFailures = new(StringComparer.Ordinal);

    /// <summary>
    /// The buffer replies and drains are encoded into, reused by every call.
    /// </summary>
    private readonly ArrayBufferWriter<byte> _encoded = new();

    /// <summary>
    /// The reply of a call that did not fit the caller's buffer.
    /// </summary>
    private readonly ParkedReply _reply = new();

    /// <summary>
    /// The drained events that did not fit the caller's buffer.
    /// </summary>
    private readonly ParkedReply _drain = new();

    /// <summary>
    /// The topic of the parked reply.
    /// </summary>
    private string _parkedTopic = "";

    /// <summary>
    /// The frame the counters were last logged at; <see langword="null"/> before the first drain.
    /// </summary>
    private long? _countersSince;

    /// <summary>
    /// Creates a context with no topic but <see cref="BatchTopic"/>.
    /// </summary>
    /// <param name="id">The id the scripts name it by.</param>
    /// <param name="log">Where the bridge's lines go.</param>
    /// <param name="eventLimit">The most message events kept between two drains.</param>
    public BridgeContext(int id, IBridgeLog log, int eventLimit = BridgeEventQueue.DefaultLimit)
    {
        ArgumentNullException.ThrowIfNull(log);
        Id = id;
        Log = log;
        Events = new BridgeEventQueue(log, eventLimit);
        Register(BatchTopic, (_, request) => RunBatch(request));
    }

    /// <summary>
    /// Gets the id the scripts name the context by.
    /// </summary>
    public int Id { get; }

    /// <summary>
    /// Gets where the bridge's lines go.
    /// </summary>
    public IBridgeLog Log { get; }

    /// <summary>
    /// Gets the events the scripts take with the next drain.
    /// </summary>
    public BridgeEventQueue Events { get; }

    /// <summary>
    /// Gets the frame of the latest drain, the core's clock; rules read it instead of a wall clock.
    /// </summary>
    public long Frame { get; private set; }

    /// <summary>
    /// Gets the topics in the order they were registered.
    /// </summary>
    public IReadOnlyList<string> Topics => _topics;

    /// <summary>
    /// Gets the counters by topic since they were last logged, the drain's under <see cref="DrainCounters"/>.
    /// </summary>
    public IReadOnlyDictionary<string, TopicCounters> Counters => _counters;

    /// <summary>
    /// Registers a topic's handler.
    /// </summary>
    /// <param name="topic">The topic, such as "story.write".</param>
    /// <param name="handler">The handler.</param>
    /// <exception cref="ArgumentException">The topic has a handler already.</exception>
    public void Register(string topic, BridgeHandler handler)
    {
        ArgumentException.ThrowIfNullOrEmpty(topic);
        ArgumentNullException.ThrowIfNull(handler);
        if (!_handlers.TryAdd(topic, handler))
        {
            throw new ArgumentException($"The topic {topic} has a handler already.", nameof(topic));
        }

        _topics.Add(topic);
    }

    /// <summary>
    /// Runs another topic's handler in-process, for a handler that builds on the topics of other areas,
    /// such as the world screen's steps on the parking's.
    /// </summary>
    /// <remarks>
    /// The value is the handler's own, never wrapped in the envelope, and a failure throws to the asking
    /// handler, whose envelope then reports it.
    /// </remarks>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request, <see langword="null"/> for nil.</param>
    /// <returns>The value, <see langword="null"/> for none.</returns>
    /// <exception cref="BridgeRequestException">No handler answers the topic.</exception>
    public RubyValue? Ask(string topic, RubyValue? request = null)
    {
        BridgeHandler handler = _handlers.TryGetValue(topic, out BridgeHandler? found) ? found : throw new BridgeRequestException($"There is no topic {topic}.");
        RubyValue? value = handler(this, request ?? RubyNil.Value);
        return value is RubyNil ? null : value;
    }

    /// <summary>
    /// Adds a step that runs at each drain before the events are taken, such as folding in what the
    /// network threads queued or running timers on <see cref="Frame"/>.
    /// </summary>
    /// <param name="step">The step.</param>
    public void EveryFrame(Action<BridgeContext> step)
    {
        ArgumentNullException.ThrowIfNull(step);
        _frameSteps.Add(step);
    }

    /// <summary>
    /// Runs one topic's handler (mp_call).
    /// </summary>
    /// <param name="topic">The topic's name as UTF-8.</param>
    /// <param name="request">The request as Marshal; none means nil.</param>
    /// <param name="reply">The caller's buffer for the reply.</param>
    /// <returns>The reply's length, 0 for no reply, or the size needed negated when the reply was parked for <see cref="TakeReply"/>.</returns>
    public int Call(ReadOnlySpan<byte> topic, ReadOnlySpan<byte> request, Span<byte> reply)
    {
        if (_reply.IsParked)
        {
            Log.Write(string.Create(CultureInfo.InvariantCulture, $"Bridge topic {_parkedTopic}: its parked reply of {_reply.Size} bytes was never taken."));
            _reply.Drop();
        }

        string name = Encoding.UTF8.GetString(topic);
        long started = Stopwatch.GetTimestamp();
        RubyHash? answer = Answer(name, request);
        ReadOnlySpan<byte> encoded = Encode(name, ref answer);
        int written = _reply.Hand(encoded, reply);
        _parkedTopic = name;
        if (_handlers.ContainsKey(name))
        {
            CountersOf(name).Count(request.Length, encoded.Length, Stopwatch.GetElapsedTime(started), answer?["ok"] is RubyBool { Flag: false });
        }

        return written;
    }

    /// <summary>
    /// Hands out the reply a call parked (mp_reply).
    /// </summary>
    /// <param name="reply">The caller's buffer, now large enough.</param>
    /// <returns>The reply's length, 0 when none is parked, or the size needed negated when it still does not fit.</returns>
    public int TakeReply(Span<byte> reply) => _reply.Take(reply);

    /// <summary>
    /// Runs the frame steps and hands out every queued event as one Marshal Array
    /// [[topic, payload], ...] (mp_drain).
    /// </summary>
    /// <remarks>
    /// While a drain is parked, the next one only hands it out, so the steps of a frame never run twice.
    /// </remarks>
    /// <param name="frame">The game's frame, which becomes <see cref="Frame"/>.</param>
    /// <param name="buffer">The caller's buffer.</param>
    /// <returns>The length written, 0 for no events, or the size needed negated when the events were parked.</returns>
    public int Drain(long frame, Span<byte> buffer)
    {
        if (_drain.IsParked)
        {
            return _drain.Take(buffer);
        }

        long started = Stopwatch.GetTimestamp();
        Frame = frame;
        RunFrameSteps();
        LogCountersWhenDue();
        List<BridgeEvent> events = Events.TakeAll();
        if (events.Count == 0)
        {
            return 0;
        }

        var batch = new RubyArray(events.Count);
        foreach ((string topic, RubyValue payload) in events)
        {
            batch.Add(new RubyArray { topic, payload });
        }

        _encoded.ResetWrittenCount();
        try
        {
            RubyMarshal.Write(batch, _encoded);
        }
        catch (RubyValueException e)
        {
            LogFailure(DrainCounters, BridgeEnvelope.Internal, $"{events.Count} events were lost: {e.Message}", null);
            return 0;
        }

        CountersOf(DrainCounters).Count(0, _encoded.WrittenCount, Stopwatch.GetElapsedTime(started), failed: false);
        return _drain.Hand(_encoded.WrittenSpan, buffer);
    }

    /// <summary>
    /// Runs every [topic, payload] pair of a batch in order (<see cref="BatchTopic"/>); their replies are
    /// dropped, since what the scripts stage answers nothing.
    /// </summary>
    /// <remarks>
    /// Every pair is checked before the first runs, so a broken batch runs none of its entries.
    /// </remarks>
    /// <param name="request">The batch, an Array of [topic, payload] pairs.</param>
    /// <returns>The failed entries in order as {"topic"=>..., "error"=>code, "text"=>...}, <see langword="null"/> when every entry ran.</returns>
    /// <exception cref="BridgeRequestException">The batch is no Array of pairs, or it holds a batch.</exception>
    private RubyArray? RunBatch(RubyValue request)
    {
        RubyArray entries = request.AsArray();
        var pairs = new (string Topic, RubyValue Payload)[entries.Count];
        for (int index = 0; index < entries.Count; index++)
        {
            RubyArray pair = entries[index].AsArray();
            if (pair.Count != 2)
            {
                throw new BridgeRequestException(string.Create(CultureInfo.InvariantCulture, $"Batch entry {index} is no [topic, payload] pair."));
            }

            string topic = pair[0].AsText();
            pairs[index] = topic == BatchTopic ? throw new BridgeRequestException("A batch cannot hold a batch.") : (topic, pair[1]);
        }

        RubyArray? failed = null;
        foreach ((string topic, RubyValue payload) in pairs)
        {
            long started = Stopwatch.GetTimestamp();
            RubyHash? answer = Run(topic, payload);
            bool failure = answer?["ok"] is RubyBool { Flag: false };
            if (_handlers.ContainsKey(topic))
            {
                CountersOf(topic).Count(0, 0, Stopwatch.GetElapsedTime(started), failure);
            }

            if (failure)
            {
                failed ??= [];
                failed.Add(new RubyHash { { "topic", topic }, { "error", answer!["error"] }, { "text", answer["text"] } });
            }
        }

        return failed;
    }

    /// <summary>
    /// Reads a request and runs its topic's handler.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request as Marshal; none means nil.</param>
    /// <returns>The reply, <see langword="null"/> for no reply.</returns>
    private RubyHash? Answer(string topic, ReadOnlySpan<byte> request)
    {
        if (!_handlers.ContainsKey(topic))
        {
            return Fail(topic, BridgeEnvelope.UnknownTopic, $"There is no topic {topic}.", null);
        }

        RubyValue value;
        try
        {
            value = request.IsEmpty ? RubyNil.Value : RubyMarshal.Read(request);
        }
        catch (RubyValueException e)
        {
            return Fail(topic, BridgeEnvelope.BadRequest, e.Message, null);
        }

        return Run(topic, value);
    }

    /// <summary>
    /// Runs a topic's handler on a request already read and wraps its value in the envelope; holds the
    /// only catch of handlers.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request.</param>
    /// <returns>The reply, <see langword="null"/> for no reply.</returns>
    private RubyHash? Run(string topic, RubyValue request)
    {
        if (!_handlers.TryGetValue(topic, out BridgeHandler? handler))
        {
            return Fail(topic, BridgeEnvelope.UnknownTopic, $"There is no topic {topic}.", null);
        }

        try
        {
            RubyValue? result = handler(this, request);
            return result is null or RubyNil ? null : BridgeEnvelope.Ok(result);
        }
        catch (Exception e) when (e is RubyValueException or BridgeRequestException)
        {
            return Fail(topic, BridgeEnvelope.BadRequest, e.Message, null);
        }
        catch (Exception e)
        {
            return Fail(topic, BridgeEnvelope.Internal, e.Message, e);
        }
    }

    /// <summary>
    /// Encodes a reply into the shared buffer; a reply that cannot cross becomes an internal error.
    /// </summary>
    /// <param name="topic">The topic that answered.</param>
    /// <param name="answer">The reply, replaced by the error when it cannot cross.</param>
    /// <returns>The encoded reply, empty for no reply; valid until the next call.</returns>
    private ReadOnlySpan<byte> Encode(string topic, ref RubyHash? answer)
    {
        _encoded.ResetWrittenCount();
        if (answer is null)
        {
            return [];
        }

        try
        {
            RubyMarshal.Write(answer, _encoded);
        }
        catch (RubyValueException e)
        {
            answer = Fail(topic, BridgeEnvelope.Internal, "The reply cannot cross: " + e.Message, null);
            _encoded.ResetWrittenCount();
            RubyMarshal.Write(answer, _encoded);
        }

        return _encoded.WrittenSpan;
    }

    /// <summary>
    /// Makes an error reply, and logs the first of each topic and code until the counters are logged.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="code">The error code.</param>
    /// <param name="text">What went wrong.</param>
    /// <param name="exception">The exception of a failed handler, logged with its stack.</param>
    /// <returns>The error reply.</returns>
    private RubyHash Fail(string topic, string code, string text, Exception? exception)
    {
        LogFailure(topic, code, text, exception);
        return BridgeEnvelope.Error(code, text);
    }

    /// <summary>
    /// Logs the first failure of each topic and code until the counters are logged.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="code">The error code.</param>
    /// <param name="text">What went wrong.</param>
    /// <param name="exception">The exception, logged with its stack.</param>
    private void LogFailure(string topic, string code, string text, Exception? exception)
    {
        if (_loggedFailures.Add(topic + " " + code))
        {
            Log.Write($"Bridge topic {topic} answered {code}: {text}" + (exception is null ? "" : Environment.NewLine + exception));
        }
    }

    /// <summary>
    /// Runs the frame steps; a step that fails is logged and the others still run.
    /// </summary>
    private void RunFrameSteps()
    {
        for (int index = 0; index < _frameSteps.Count; index++)
        {
            try
            {
                _frameSteps[index](this);
            }
            catch (Exception e)
            {
                LogFailure(string.Create(CultureInfo.InvariantCulture, $"(frame step {index})"), BridgeEnvelope.Internal, e.Message, e);
            }
        }
    }

    /// <summary>
    /// Logs and resets the counters once <see cref="CountersEveryFrames"/> frames passed, or the clock went back.
    /// </summary>
    private void LogCountersWhenDue()
    {
        _countersSince ??= Frame;
        long passed = Frame - _countersSince.Value;
        if (passed is >= 0 and < CountersEveryFrames)
        {
            return;
        }

        foreach ((string topic, TopicCounters counters) in _counters)
        {
            Log.Write(counters.Describe(topic));
        }

        _counters.Clear();
        _loggedFailures.Clear();
        _countersSince = Frame;
    }

    /// <summary>
    /// Finds a topic's counters, made on its first call.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <returns>The counters.</returns>
    private TopicCounters CountersOf(string topic)
    {
        if (!_counters.TryGetValue(topic, out TopicCounters? counters))
        {
            counters = new TopicCounters();
            _counters[topic] = counters;
        }

        return counters;
    }
}
