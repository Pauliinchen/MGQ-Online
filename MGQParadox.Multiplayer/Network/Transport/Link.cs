//----------------------------------------------------------------
//  Link.cs
//
//  Changelog:
//      Paulinchen  2026-10-07: Logged each message of the game script sent, refused or received, and a link this game closed
//                            - Dropped the oldest message once the inbox is full, logged once, and took only the message the game script read
//      Paulinchen  2026-10-06: Started its threads through Threads, shared with the other connections
//      Paulinchen  2026-09-29: Measured messages against the frame channel's longest frame
//                            - Carried encrypted frames over any frame channel instead of a TCP connection
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Text;
using System.Threading;

namespace MGQParadox.Multiplayer.Network.Transport;

/// <summary>
/// The connection between two games once their teams are swapped, which carries the game script's
/// messages of a live battle both ways.
/// </summary>
/// <remarks>
/// Its threads ping while nothing else is sent, since a player may take long over a turn and
/// silence means a lost friend.
/// </remarks>
internal sealed class Link
{
    /// <summary>
    /// The kind of a message the game script sent.
    /// </summary>
    private const string GameKind = "game";

    /// <summary>
    /// The kind of a message that only keeps the connection alive.
    /// </summary>
    private const string PingKind = "ping";

    /// <summary>
    /// The kind of the last message of a game that leaves.
    /// </summary>
    private const string ByeKind = "bye";

    /// <summary>
    /// Bytes the headers of a game message take at most, which its text must leave room for.
    /// </summary>
    private const int HeaderBytes = 16;

    /// <summary>
    /// Most messages the inbox holds while the game script reads none; past it the oldest is dropped.
    /// </summary>
    private const int MaxInbox = 10_000;

    /// <summary>
    /// The connection, which the link owns.
    /// </summary>
    private readonly IFrameChannel _channel;

    /// <summary>
    /// Encrypts the frames going out and checks the frames coming in.
    /// </summary>
    private readonly FrameCipher _cipher;

    /// <summary>
    /// How long the writer waits for a message before it pings.
    /// </summary>
    private readonly TimeSpan _pingInterval;

    /// <summary>
    /// The game script's messages that arrived and wait to be taken, guarded by <see cref="_inboxGate"/>.
    /// </summary>
    private readonly Queue<string> _inbox = new();

    /// <summary>
    /// Guards <see cref="_inbox"/> and <see cref="_dropped"/>.
    /// </summary>
    private readonly object _inboxGate = new();

    /// <summary>
    /// How many messages the full inbox dropped since it last had room, logged once it has room again.
    /// </summary>
    private int _dropped;

    /// <summary>
    /// The frames waiting for the writer, not yet encrypted.
    /// </summary>
    /// <remarks>
    /// Only the writer thread encrypts, pings included, so frames go out in the order their counters say.
    /// </remarks>
    private readonly BlockingCollection<string> _outbox = new();

    /// <summary>
    /// The <see cref="LinkState"/>, as a number the threads can swap atomically.
    /// </summary>
    private int _state = (int)LinkState.Open;

    /// <summary>
    /// Takes over a connection and starts reading and writing on it.
    /// </summary>
    /// <param name="channel">The connection, which the link closes when it ends.</param>
    /// <param name="cipher">The cipher the team swap used, whose counters go on.</param>
    /// <param name="pingInterval">How long the link stays quiet before it pings.</param>
    /// <param name="dropTimeout">How long the other game may stay silent before the link counts as dropped.</param>
    public Link(IFrameChannel channel, FrameCipher cipher, TimeSpan pingInterval, TimeSpan dropTimeout)
    {
        _channel = channel;
        _cipher = cipher;
        _pingInterval = pingInterval;
        channel.SetTimeout(dropTimeout);

        Threads.Start("MultiplayerLinkRead", ReadAll);
        Threads.Start("MultiplayerLinkWrite", WriteAll);
    }

    /// <summary>
    /// Where the connection stands.
    /// </summary>
    public LinkState State => (LinkState)Volatile.Read(ref _state);

    /// <summary>
    /// Sends a message of the game script.
    /// </summary>
    /// <param name="text">The message.</param>
    /// <returns><see langword="false"/> when the link has ended or the message is too long for a frame.</returns>
    public bool Send(string text)
    {
        var bytes = Encoding.UTF8.GetByteCount(text);

        if (State != LinkState.Open || bytes > IFrameChannel.MaxFrameBytes - HeaderBytes - FrameCipher.Overhead)
        {
            Log.Write($"link message not sent: {(State != LinkState.Open ? $"the link is {State.ToString().ToLowerInvariant()}" : "too long")}, {Message.FirstFieldOf(text)}, {bytes} bytes");
            return false;
        }

        try
        {
            _outbox.Add(Encode(GameKind, text));
            Log.Write($"link message out: {Message.FirstFieldOf(text)}, {bytes} bytes");
            return true;
        }
        catch (InvalidOperationException)
        {
            Log.Write($"link message not sent: the link ended meanwhile, {Message.FirstFieldOf(text)}, {bytes} bytes");
            return false;
        }
    }

    /// <summary>
    /// Looks at the oldest message that arrived, without taking it. Messages stay readable after the link ended.
    /// </summary>
    /// <returns>The message, or <see langword="null"/> while none waits.</returns>
    public string? Peek()
    {
        lock (_inboxGate)
        {
            return _inbox.TryPeek(out var text) ? text : null;
        }
    }

    /// <summary>
    /// Takes the oldest message that arrived, if it is the one the game script read, since a full inbox may have dropped it meanwhile.
    /// </summary>
    /// <param name="message">The message <see cref="Peek"/> handed out.</param>
    public void Take(string message)
    {
        lock (_inboxGate)
        {
            if (_inbox.TryPeek(out var oldest) && ReferenceEquals(oldest, message))
            {
                _inbox.Dequeue();

                if (_dropped > 0)
                {
                    Log.Write($"link inbox has room again after dropping its {_dropped} oldest messages");
                    _dropped = 0;
                }
            }
        }
    }

    /// <summary>
    /// Says goodbye to the other game and closes the connection once that is sent. Calling it again does nothing.
    /// </summary>
    public void Close()
    {
        if (Interlocked.CompareExchange(ref _state, (int)LinkState.Closed, (int)LinkState.Open) != (int)LinkState.Open)
        {
            return;
        }

        Log.Write("link closed by this game, saying goodbye");

        try
        {
            _outbox.Add(Encode(ByeKind));
            _outbox.CompleteAdding();
        }
        catch (InvalidOperationException)
        {
        }
    }

    /// <summary>
    /// Reads frames until the link ends.
    /// </summary>
    private void ReadAll()
    {
        try
        {
            while (State == LinkState.Open)
            {
                if (_channel.Receive() is not { } frame)
                {
                    End(LinkState.Dropped, "the connection ended");
                    return;
                }

                if (_cipher.Open(frame) is not { } text)
                {
                    End(LinkState.Dropped, "a frame failed its check");
                    return;
                }

                var message = Message.Decode(Encoding.UTF8.GetString(text));

                switch (message[Message.Kind])
                {
                    case GameKind:
                        Enqueue(message.Team);
                        Log.Write($"link message in: {Message.FirstFieldOf(message.Team)}, {Encoding.UTF8.GetByteCount(message.Team)} bytes");
                        break;

                    case ByeKind:
                        End(LinkState.Closed, "your friend left");
                        return;
                }
            }
        }
        catch (Exception ex)
        {
            End(LinkState.Dropped, ex.Message);
        }
    }

    /// <summary>
    /// Adds a message to the inbox, dropping the oldest once it is full.
    /// </summary>
    /// <param name="message">The message.</param>
    private void Enqueue(string message)
    {
        lock (_inboxGate)
        {
            if (_inbox.Count >= MaxInbox)
            {
                _inbox.Dequeue();

                if (_dropped++ == 0)
                {
                    Log.Write($"link inbox full at {MaxInbox} messages, the game script reads none: dropping the oldest");
                }
            }

            _inbox.Enqueue(message);
        }
    }

    /// <summary>
    /// Writes the waiting frames, and a ping whenever none came for a while, until the link ends.
    /// </summary>
    private void WriteAll()
    {
        try
        {
            while (true)
            {
                if (_outbox.TryTake(out var frame, _pingInterval))
                {
                    Write(frame);
                }
                else if (_outbox.IsCompleted)
                {
                    break;
                }
                else
                {
                    Write(Encode(PingKind));
                }
            }
        }
        catch (Exception ex)
        {
            End(LinkState.Dropped, ex.Message);
        }
        finally
        {
            _channel.Dispose();
        }
    }

    /// <summary>
    /// Encrypts a frame and sends it. Called by the writer thread only.
    /// </summary>
    /// <param name="frame">The frame's text.</param>
    private void Write(string frame) => _channel.Send(_cipher.Seal(Encoding.UTF8.GetBytes(frame)));

    /// <summary>
    /// Ends the link from this side's threads and closes the connection. Only the first end counts.
    /// </summary>
    /// <param name="state">How it ended.</param>
    /// <param name="reason">Why, for the log.</param>
    private void End(LinkState state, string reason)
    {
        if (Interlocked.CompareExchange(ref _state, (int)state, (int)LinkState.Open) != (int)LinkState.Open)
        {
            return;
        }

        Log.Write($"link {state.ToString().ToLowerInvariant()}, {reason}");
        _outbox.CompleteAdding();
        _channel.Dispose();
    }

    /// <summary>
    /// Writes a frame's text.
    /// </summary>
    /// <param name="kind">The message's kind.</param>
    /// <param name="text">The game script's text, empty for the link's own messages.</param>
    /// <returns>The text.</returns>
    private static string Encode(string kind, string text = "") =>
        new Message(new KeyValuePair<string, string?>[] { new(Message.Kind, kind) }, text).Encode();
}
