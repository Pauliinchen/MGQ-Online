//----------------------------------------------------------------
//  UiContext.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Game.Tests.Ui;

/// <summary>
/// A bridge context for the interface's tests, with the tick and drain the scripts would run.
/// </summary>
internal sealed class UiContext
{
    /// <summary>
    /// The drain buffer, larger than any test's events.
    /// </summary>
    private readonly byte[] _drain = new byte[1 << 16];

    /// <summary>
    /// The reply buffer.
    /// </summary>
    private readonly byte[] _reply = new byte[1 << 16];

    /// <summary>
    /// Creates a context with nothing registered.
    /// </summary>
    public UiContext()
    {
        Context = new BridgeContext(1, Log);
    }

    /// <summary>
    /// Gets the context.
    /// </summary>
    public BridgeContext Context { get; }

    /// <summary>
    /// Gets the log the context writes.
    /// </summary>
    public LineLog Log { get; } = new();

    /// <summary>
    /// Gets the last drain's frame.
    /// </summary>
    public long Frame { get; private set; }

    /// <summary>
    /// Calls a topic as the scripts do, through Marshal both ways.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request, null for none.</param>
    /// <returns>The reply's envelope, null for no reply.</returns>
    public RubyHash? Call(string topic, RubyValue? request = null)
    {
        byte[] bytes = request is null ? [] : RubyMarshal.Write(request);
        int length = Context.Call(System.Text.Encoding.UTF8.GetBytes(topic), bytes, _reply);
        return length > 0 ? RubyMarshal.Read(_reply.AsSpan(0, length)).AsHash() : null;
    }

    /// <summary>
    /// Calls a topic and takes its value, failing the test on an error reply.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request, null for none.</param>
    /// <returns>The value, nil for no reply.</returns>
    public RubyValue Value(string topic, RubyValue? request = null)
    {
        RubyHash? answer = Call(topic, request);
        if (answer is null)
        {
            return RubyNil.Value;
        }

        Assert.True(answer["ok"] is RubyBool { Flag: true }, $"{topic} answered {answer}");
        return answer["value"];
    }

    /// <summary>
    /// Ends a frame: drains the events with the next frame's number.
    /// </summary>
    /// <returns>Each event as its topic and payload.</returns>
    public List<(string Topic, RubyValue Payload)> Drain()
    {
        Frame++;
        int length = Context.Drain(Frame, _drain);
        return length <= 0
            ? []
            : RubyMarshal.Read(_drain.AsSpan(0, length)).AsArray().Select(pair => (pair.AsArray()[0].AsText(), pair.AsArray()[1])).ToList();
    }

    /// <summary>
    /// Runs a frame's tick, then drains.
    /// </summary>
    /// <param name="inputs">Each model's name and input.</param>
    /// <returns>The frame's events.</returns>
    public List<(string Topic, RubyValue Payload)> Tick(RubyHash inputs)
    {
        RubyHash? answer = Call(UiHostTopic, inputs);
        Assert.Null(answer);
        return Drain();
    }

    /// <summary>
    /// The tick's topic.
    /// </summary>
    private const string UiHostTopic = Game.Ui.UiHost.TickTopic;

    /// <summary>
    /// A log that keeps its lines.
    /// </summary>
    internal sealed class LineLog : IBridgeLog
    {
        /// <summary>
        /// Gets the lines written.
        /// </summary>
        public List<string> Lines { get; } = [];

        /// <inheritdoc />
        public void Write(string line) => Lines.Add(line);
    }
}
