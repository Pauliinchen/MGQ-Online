//----------------------------------------------------------------
//  BridgeHost.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Gave the export layer the host's log
//                            - Closed the older contexts at a new handshake
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Bridge;

/// <summary>
/// The bridge as the four exports reach it: the handshake that opens a context, and the calls,
/// parked replies and drains routed to a context by its id.
/// </summary>
/// <remarks>
/// The DLL and the battle server core each keep one host in their export layer; the host itself is an
/// ordinary object, so tests can hold many.
/// </remarks>
public sealed class BridgeHost
{
    /// <summary>
    /// The bridge's version, BRIDGE_VERSION in Multiplayer.rb; a handshake of another version is refused.
    /// </summary>
    public const int Version = 1;

    /// <summary>
    /// The open contexts by id.
    /// </summary>
    private readonly Dictionary<int, BridgeContext> _contexts = [];

    /// <summary>
    /// The handshake's reply that did not fit the caller's buffer.
    /// </summary>
    private readonly ParkedReply _handshake = new();

    /// <summary>
    /// The build the handshake names, such as "0.6.9".
    /// </summary>
    private readonly string _build;

    /// <summary>
    /// Registers the topics and frame steps of a new context.
    /// </summary>
    private readonly Action<BridgeContext> _setup;

    /// <summary>
    /// The context ids that were called but are not open, each logged once.
    /// </summary>
    private readonly HashSet<int> _unknownLogged = [];

    /// <summary>
    /// The id the next context gets.
    /// </summary>
    private int _nextId = 1;

    /// <summary>
    /// Creates a host with no context open.
    /// </summary>
    /// <param name="build">The build the handshake names, such as "0.6.9".</param>
    /// <param name="log">Where the bridge's lines go.</param>
    /// <param name="setup">Registers the topics and frame steps of each new context.</param>
    public BridgeHost(string build, IBridgeLog log, Action<BridgeContext> setup)
    {
        ArgumentNullException.ThrowIfNull(build);
        ArgumentNullException.ThrowIfNull(log);
        ArgumentNullException.ThrowIfNull(setup);
        _build = build;
        Log = log;
        _setup = setup;
    }

    /// <summary>
    /// Gets where the bridge's lines go.
    /// </summary>
    public IBridgeLog Log { get; }

    /// <summary>
    /// Opens a context when the scripts speak this bridge's version (mp_bridge_open).
    /// </summary>
    /// <remarks>
    /// The reply is {"bridge"=>N, "build"=>..., "context"=>id, "topics"=>[...]} in the envelope. A reply
    /// that does not fit is parked and handed out by the next handshake, which opens no second context.
    /// A handshake that opens a context closes the older ones, since F12 restarts the scripts, which
    /// shake hands again, but not the process.
    /// </remarks>
    /// <param name="version">The scripts' BRIDGE_VERSION.</param>
    /// <param name="reply">The caller's buffer.</param>
    /// <returns>The reply's length, or the size needed negated when it was parked.</returns>
    public int Open(int version, Span<byte> reply)
    {
        if (_handshake.IsParked)
        {
            return _handshake.Take(reply);
        }

        if (version != Version)
        {
            string text = string.Create(CultureInfo.InvariantCulture, $"The scripts speak bridge version {version}, the core version {Version}.");
            Log.Write("Bridge handshake refused: " + text);
            return _handshake.Hand(RubyMarshal.Write(BridgeEnvelope.Error(BridgeEnvelope.BadRequest, text)), reply);
        }

        var context = new BridgeContext(_nextId++, Log);
        try
        {
            _setup(context);
        }
        catch (Exception e)
        {
            Log.Write("Bridge handshake failed while setting up its topics:" + Environment.NewLine + e);
            return _handshake.Hand(RubyMarshal.Write(BridgeEnvelope.Error(BridgeEnvelope.Internal, e.Message)), reply);
        }

        foreach (int older in _contexts.Keys.ToArray())
        {
            Close(older);
        }

        _contexts[context.Id] = context;
        Log.Write(string.Create(CultureInfo.InvariantCulture, $"Bridge {Version} opened context {context.Id} with {context.Topics.Count} topics."));
        var value = new RubyHash
        {
            { "bridge", Version },
            { "build", _build },
            { "context", context.Id },
            { "topics", new RubyArray(context.Topics.Select(topic => (RubyValue)topic)) },
        };
        return _handshake.Hand(RubyMarshal.Write(BridgeEnvelope.Ok(value)), reply);
    }

    /// <summary>
    /// Runs a topic's handler on a context (mp_call).
    /// </summary>
    /// <param name="context">The context's id.</param>
    /// <param name="topic">The topic's name as UTF-8.</param>
    /// <param name="request">The request as Marshal; none means nil.</param>
    /// <param name="reply">The caller's buffer.</param>
    /// <returns>As <see cref="BridgeContext.Call"/>; for a context that is not open, its error when it fits, else 0.</returns>
    public int Call(int context, ReadOnlySpan<byte> topic, ReadOnlySpan<byte> request, Span<byte> reply)
    {
        if (Find(context) is BridgeContext open)
        {
            return open.Call(topic, request, reply);
        }

        byte[] error = RubyMarshal.Write(BridgeEnvelope.Error(BridgeEnvelope.BadRequest, string.Create(CultureInfo.InvariantCulture, $"There is no bridge context {context}.")));
        if (error.Length > reply.Length)
        {
            return 0;
        }

        error.CopyTo(reply);
        return error.Length;
    }

    /// <summary>
    /// Hands out a context's parked reply (mp_reply).
    /// </summary>
    /// <param name="context">The context's id.</param>
    /// <param name="reply">The caller's buffer.</param>
    /// <returns>As <see cref="BridgeContext.TakeReply"/>; 0 for a context that is not open.</returns>
    public int TakeReply(int context, Span<byte> reply) => Find(context)?.TakeReply(reply) ?? 0;

    /// <summary>
    /// Drains a context's events (mp_drain).
    /// </summary>
    /// <param name="context">The context's id.</param>
    /// <param name="frame">The game's frame.</param>
    /// <param name="buffer">The caller's buffer.</param>
    /// <returns>As <see cref="BridgeContext.Drain"/>; 0 for a context that is not open.</returns>
    public int Drain(int context, long frame, Span<byte> buffer) => Find(context)?.Drain(frame, buffer) ?? 0;

    /// <summary>
    /// Closes a context, such as when the game resets and its scripts open a new one.
    /// </summary>
    /// <param name="context">The context's id.</param>
    public void Close(int context)
    {
        if (_contexts.Remove(context))
        {
            Log.Write(string.Create(CultureInfo.InvariantCulture, $"Bridge closed context {context}."));
        }
    }

    /// <summary>
    /// Finds an open context, and logs the first call to each id that is not open.
    /// </summary>
    /// <param name="context">The context's id.</param>
    /// <returns>The context, <see langword="null"/> when it is not open.</returns>
    public BridgeContext? Find(int context)
    {
        if (_contexts.TryGetValue(context, out BridgeContext? open))
        {
            return open;
        }

        if (_unknownLogged.Add(context))
        {
            Log.Write(string.Create(CultureInfo.InvariantCulture, $"Bridge context {context} is not open."));
        }

        return null;
    }
}
