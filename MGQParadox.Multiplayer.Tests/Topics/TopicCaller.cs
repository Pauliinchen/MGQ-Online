//----------------------------------------------------------------
//  TopicCaller.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;

namespace MGQParadox.Multiplayer.Tests.Topics;

/// <summary>
/// Calls the DLL's topics as the scripts do: the request through Marshal into a context, the reply
/// out of its envelope.
/// </summary>
internal sealed class TopicCaller
{
    /// <summary>
    /// The size of the reply buffer, larger than any reply of the topics under test.
    /// </summary>
    private const int ReplySize = 1 << 16;

    /// <summary>
    /// The context the topics are registered on.
    /// </summary>
    private readonly BridgeContext _context = new(1, new NoLog());

    /// <summary>
    /// Creates a caller with topics.
    /// </summary>
    /// <param name="register">Registers the topics, such as <c>RuleTopics.Register</c>.</param>
    public TopicCaller(Action<BridgeContext> register) => register(_context);

    /// <summary>
    /// Calls a topic that must answer.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request, <see langword="null"/> for none.</param>
    /// <returns>The value, <see langword="null"/> for no reply.</returns>
    /// <exception cref="InvalidOperationException">The topic answered an error.</exception>
    public RubyValue? Call(string topic, RubyValue? request = null)
    {
        RubyHash? envelope = Envelope(topic, request);
        if (envelope == null)
        {
            return null;
        }

        return envelope["ok"].AsBool() ? envelope["value"] : throw new InvalidOperationException($"{topic} answered {envelope["error"]}: {envelope["text"]}");
    }

    /// <summary>
    /// Calls a topic that must refuse the request.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request.</param>
    /// <returns>The error code, such as "bad_request".</returns>
    public string Refusal(string topic, RubyValue request)
    {
        RubyHash envelope = Envelope(topic, request) ?? throw new InvalidOperationException($"{topic} answered nothing");
        return !envelope["ok"].AsBool() ? envelope["error"].AsText() : throw new InvalidOperationException($"{topic} answered {envelope["value"]}");
    }

    /// <summary>
    /// Calls a topic and reads its envelope.
    /// </summary>
    /// <param name="topic">The topic.</param>
    /// <param name="request">The request, <see langword="null"/> for none.</param>
    /// <returns>The envelope, <see langword="null"/> for no reply.</returns>
    private RubyHash? Envelope(string topic, RubyValue? request)
    {
        byte[] reply = new byte[ReplySize];
        int length = _context.Call(System.Text.Encoding.UTF8.GetBytes(topic), request == null ? [] : RubyMarshal.Write(request), reply);
        return length == 0 ? null : RubyMarshal.Read(reply.AsSpan(0, length)).AsHash();
    }

    /// <summary>
    /// Keeps no log lines.
    /// </summary>
    private sealed class NoLog : IBridgeLog
    {
        /// <inheritdoc />
        public void Write(string line)
        {
        }
    }
}
