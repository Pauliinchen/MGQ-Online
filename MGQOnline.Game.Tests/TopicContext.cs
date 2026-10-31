//----------------------------------------------------------------
//  TopicContext.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Game.Tests;

/// <summary>
/// A bridge context for the tests of topics: calls a topic as the scripts would, its request and
/// reply through Marshal, and keeps the log's lines.
/// </summary>
internal sealed class TopicContext
{
    /// <summary>
    /// The reply buffer.
    /// </summary>
    private readonly byte[] _reply = new byte[1 << 16];

    /// <summary>
    /// Initializes a new instance of the <see cref="TopicContext"/> class with no topic.
    /// </summary>
    public TopicContext()
    {
        Context = new BridgeContext(1, Log);
    }

    /// <summary>
    /// Gets the context the topics register on.
    /// </summary>
    public BridgeContext Context { get; }

    /// <summary>
    /// Gets the log's lines.
    /// </summary>
    public LineLog Log { get; } = new();

    /// <summary>
    /// Calls a topic.
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
    /// Calls a topic that must succeed and takes its value.
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
    /// The log's lines.
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
