//----------------------------------------------------------------
//  Link.cs
//
//  Changelog:
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Net.Sockets;
using System.Text;
using System.Threading;

namespace MGQParadox.Multiplayer.Network;

/// <summary>
/// The connection between two games once their teams are swapped, which carries the game script's
/// messages of a live battle both ways.
/// </summary>
/// <remarks>
/// Threads of its own read and write, so the game never waits on the network. They also ping while
/// nothing else is sent, since a player may take long over a turn and silence means a lost friend.
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
    /// The connection.
    /// </summary>
    private readonly TcpClient _client;

    /// <summary>
    /// How long the writer waits for a message before it pings.
    /// </summary>
    private readonly TimeSpan _pingInterval;

    /// <summary>
    /// The game script's messages that arrived and wait to be taken.
    /// </summary>
    private readonly ConcurrentQueue<string> _inbox = new();

    /// <summary>
    /// The frames waiting for the writer.
    /// </summary>
    private readonly BlockingCollection<string> _outbox = new();

    /// <summary>
    /// The <see cref="LinkState"/>, as a number the threads can swap atomically.
    /// </summary>
    private int _state = (int)LinkState.Open;

    /// <summary>
    /// Takes over a connection and starts reading and writing on it.
    /// </summary>
    /// <param name="client">The connection, which the link closes when it ends.</param>
    /// <param name="pingInterval">How long the link stays quiet before it pings.</param>
    /// <param name="dropTimeout">How long the other game may stay silent before the link counts as dropped.</param>
    public Link(TcpClient client, TimeSpan pingInterval, TimeSpan dropTimeout)
    {
        _client = client;
        _pingInterval = pingInterval;
        client.ReceiveTimeout = (int)dropTimeout.TotalMilliseconds;
        client.SendTimeout = (int)dropTimeout.TotalMilliseconds;

        var stream = client.GetStream();
        StartThread("MultiplayerLinkRead", () => ReadAll(stream));
        StartThread("MultiplayerLinkWrite", () => WriteAll(stream));
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
        if (State != LinkState.Open || Encoding.UTF8.GetByteCount(text) > Frame.MaxBodyBytes - HeaderBytes)
        {
            return false;
        }

        try
        {
            _outbox.Add(Encode(GameKind, text));
            return true;
        }
        catch (InvalidOperationException)
        {
            return false;
        }
    }

    /// <summary>
    /// Looks at the oldest message that arrived, without taking it. Messages stay readable after the link ended.
    /// </summary>
    /// <returns>The message, or <see langword="null"/> while none waits.</returns>
    public string? Peek() => _inbox.TryPeek(out var text) ? text : null;

    /// <summary>
    /// Takes the oldest message that arrived.
    /// </summary>
    public void Take() => _inbox.TryDequeue(out _);

    /// <summary>
    /// Says goodbye to the other game and closes the connection once that is sent. Calling it again does nothing.
    /// </summary>
    public void Close()
    {
        if (Interlocked.CompareExchange(ref _state, (int)LinkState.Closed, (int)LinkState.Open) != (int)LinkState.Open)
        {
            return;
        }

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
    /// <remarks>
    /// Catches everything. An exception escaping this thread would end the whole game.
    /// </remarks>
    /// <param name="stream">The connection's stream.</param>
    private void ReadAll(NetworkStream stream)
    {
        try
        {
            while (State == LinkState.Open)
            {
                if (Frame.Read(stream) is not { } text)
                {
                    End(LinkState.Dropped, "the connection ended");
                    return;
                }

                var message = Message.Decode(text);

                switch (message[Message.Kind])
                {
                    case GameKind:
                        _inbox.Enqueue(message.Team);
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
    /// Writes the waiting frames, and a ping whenever none came for a while, until the link ends.
    /// </summary>
    /// <remarks>
    /// Catches everything. An exception escaping this thread would end the whole game.
    /// </remarks>
    /// <param name="stream">The connection's stream.</param>
    private void WriteAll(NetworkStream stream)
    {
        try
        {
            while (true)
            {
                if (_outbox.TryTake(out var frame, _pingInterval))
                {
                    Frame.Write(stream, frame);
                }
                else if (_outbox.IsCompleted)
                {
                    break;
                }
                else
                {
                    Frame.Write(stream, Encode(PingKind));
                }
            }
        }
        catch (Exception ex)
        {
            End(LinkState.Dropped, ex.Message);
        }
        finally
        {
            _client.Dispose();
        }
    }

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
        _client.Dispose();
    }

    /// <summary>
    /// Writes a frame's text.
    /// </summary>
    /// <param name="kind">The message's kind.</param>
    /// <param name="text">The game script's text, empty for the link's own messages.</param>
    /// <returns>The text.</returns>
    private static string Encode(string kind, string text = "") =>
        new Message(new KeyValuePair<string, string?>[] { new(Message.Kind, kind) }, text).Encode();

    /// <summary>
    /// Runs work on a background thread, which ends with the game.
    /// </summary>
    /// <param name="name">The thread's name.</param>
    /// <param name="work">The work, which must catch everything itself.</param>
    private static void StartThread(string name, Action work) =>
        new Thread(() => work()) { IsBackground = true, Name = name }.Start();
}
