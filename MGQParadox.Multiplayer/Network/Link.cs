//----------------------------------------------------------------
//  Link.cs
//
//  Changelog:
//      Paulinchen  2026-09-29: Carried encrypted frames over any frame channel instead of a TCP connection
//      Paulinchen  2026-09-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Text;
using System.Threading;

namespace MGQParadox.Multiplayer.Network;

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
    /// The game script's messages that arrived and wait to be taken.
    /// </summary>
    private readonly ConcurrentQueue<string> _inbox = new();

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

        StartThread("MultiplayerLinkRead", ReadAll);
        StartThread("MultiplayerLinkWrite", WriteAll);
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
        if (State != LinkState.Open || Encoding.UTF8.GetByteCount(text) > Frame.MaxBodyBytes - HeaderBytes - FrameCipher.Overhead)
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
    /// Catches everything, since an exception escaping this thread would end the whole game.
    /// </remarks>
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
    /// Catches everything, since an exception escaping this thread would end the whole game.
    /// </remarks>
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

    /// <summary>
    /// Runs work on a background thread, which ends with the game.
    /// </summary>
    /// <param name="name">The thread's name.</param>
    /// <param name="work">The work, which must catch everything itself.</param>
    private static void StartThread(string name, Action work) =>
        new Thread(() => work()) { IsBackground = true, Name = name }.Start();
}
