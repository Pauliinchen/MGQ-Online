//----------------------------------------------------------------
//  TradeHarness.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Trade;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Tests.Trade;

/// <summary>
/// A trade played as the scripts played it: the player "me" on map 5 next to Friend ("friend",
/// seat 2), a world room fed with Friend's messages, the relay and the scripts standing in.
/// </summary>
internal sealed class TradeHarness : IWorldRoomHost, ITradeRelay, ITradeScripts
{
    /// <summary>
    /// The trade's id every trade of the harness gets.
    /// </summary>
    public const string TradeId = "0123456789abcdef01234567";

    /// <summary>
    /// The other player's seat.
    /// </summary>
    public const int FriendSeat = 2;

    /// <summary>
    /// The world's id in the directory.
    /// </summary>
    public const string World = "w1";

    /// <summary>
    /// The notices the room itself shows of players joining or leaving, which the trade does not.
    /// </summary>
    private static readonly string[] RoomNotices = [" joined the world.", " left the world."];

    /// <summary>
    /// Friend's state as their game tells it.
    /// </summary>
    private static readonly (string Key, string Value)[] FriendState =
        [("state", "1"), ("id", "friend"), ("name", "Friend"), ("sprite", "Actor2"), ("index", "0"), ("map", "5"), ("x", "4"), ("y", "4"), ("d", "2"), ("speed", "4"), ("hidden", "0"), ("scene", "map")];

    /// <summary>
    /// What waits in the room's inbox.
    /// </summary>
    private readonly Queue<InboxEntry> inbox = new();

    /// <summary>
    /// Initializes the harness: the world open and Friend in it.
    /// </summary>
    public TradeHarness()
    {
        Room = new WorldRoom(this, () => ("me", "Me"), () => 0, length => new string('0', length));
        var own = new WorldFields();
        own.Set("map", "5");
        own.Set("x", "3");
        own.Set("y", "4");
        Room.TakeOwn(true, own, false, null);
        Machine = new TradeMachine(Room, this, this, () => TradeId);
        Room.Take(TradeMachine.Field, RouteGate.None, Machine.Take);
        Machine.TakeFrame(Handed(null, false));
        inbox.Enqueue(new InboxEntry("seat", 0, new WorldFields(), string.Empty));
        inbox.Enqueue(new InboxEntry("in", FriendSeat, new WorldFields(), string.Empty));
        inbox.Enqueue(new InboxEntry("message", FriendSeat, new WorldFields(), FriendStateText()));
        Frames(1);
        Clear();
    }

    /// <summary>
    /// Gets the room.
    /// </summary>
    public WorldRoom Room { get; }

    /// <summary>
    /// Gets the trade.
    /// </summary>
    public TradeMachine Machine { get; }

    /// <summary>
    /// Gets the trade messages sent, each with its seat.
    /// </summary>
    public List<(int Seat, string Text)> Sent { get; } = [];

    /// <summary>
    /// Gets the notices of the trade.
    /// </summary>
    public List<string> Notices { get; } = [];

    /// <summary>
    /// Gets the calls to the relay: commits, cancels and trades done, with their arguments.
    /// </summary>
    public List<string[]> RelayCalls { get; } = [];

    /// <summary>
    /// Gets the trades the scripts were handed to apply: the id at the relay and both offers.
    /// </summary>
    public List<string[]> Applied { get; } = [];

    /// <summary>
    /// Gets the scripts' events other than the ones recorded apart, by name.
    /// </summary>
    public List<string> Events { get; } = [];

    /// <summary>
    /// Gets the lines the room and the trade logged.
    /// </summary>
    public List<string> Logged { get; } = [];

    /// <summary>
    /// Gets or sets a value indicating whether sending fails.
    /// </summary>
    public bool SendFails { get; set; }

    /// <summary>
    /// Gets or sets a value indicating whether the relay refuses commits.
    /// </summary>
    public bool CommitFails { get; set; }

    /// <summary>
    /// Gets or sets a value indicating whether the relay cannot be asked for the trades to recover.
    /// </summary>
    public bool FetchFails { get; set; }

    /// <summary>
    /// Gets or sets how the fetch of the trades to recover stands.
    /// </summary>
    public TradePendingState Pending { get; set; } = new("busy", []);

    /// <summary>
    /// Gets the trades the scripts were handed to recover, with the save they were asked for.
    /// </summary>
    public List<(long Save, IReadOnlyList<RecoveredTrade> Trades)> Recovered { get; } = [];

    /// <summary>
    /// Gets or sets how the relay's commit stands.
    /// </summary>
    public TradeCommitState? Commit { get; set; }

    /// <summary>
    /// Gets a value indicating whether the map opens the trade screen, as the scripts keep it.
    /// </summary>
    public bool OpenScreenWanted { get; private set; }

    /// <summary>
    /// Writes what the scripts hand over each frame.
    /// </summary>
    /// <param name="busy">Why the player may not open a trade.</param>
    /// <param name="inviting">Whether the player offers a trade.</param>
    /// <returns>The frame.</returns>
    public static TradeFrame Handed(string? busy, bool inviting) => new(busy, inviting, [], World);

    /// <summary>
    /// Writes a trade message of Friend's.
    /// </summary>
    /// <param name="kind">What it is.</param>
    /// <param name="fields">Its fields after "trade".</param>
    /// <returns>The message.</returns>
    public static string FromFriend(string kind, params (string Key, string Value)[] fields)
    {
        var message = new WorldFields();
        message.Set(TradeMachine.Field, kind);
        foreach ((string key, string value) in fields)
        {
            message.Set(key, value);
        }

        return message.Encode();
    }

    /// <summary>
    /// Has Friend's game send a message, which the room takes at the next frame.
    /// </summary>
    /// <param name="text">The message.</param>
    public void Message(string text) => inbox.Enqueue(new InboxEntry("message", FriendSeat, new WorldFields(), text));

    /// <summary>
    /// Has Friend's connection drop, which the room takes at the next frame.
    /// </summary>
    public void Out() => inbox.Enqueue(new InboxEntry("out", FriendSeat, new WorldFields(), string.Empty));

    /// <summary>
    /// Has Friend's game come back and tell its state, which the room takes at the next frame.
    /// </summary>
    public void Back()
    {
        inbox.Enqueue(new InboxEntry("in", FriendSeat, new WorldFields(), string.Empty));
        inbox.Enqueue(new InboxEntry("message", FriendSeat, new WorldFields(), FriendStateText()));
    }

    /// <summary>
    /// Runs frames as the DLL does: the room's step, then the trade's.
    /// </summary>
    /// <param name="count">How many.</param>
    public void Frames(int count)
    {
        for (int frame = 0; frame < count; frame++)
        {
            Room.Step(() => inbox.Count > 0 ? inbox.Dequeue() : null, () => new ConnectionStatus("open", 0, null, null));
            Machine.Step();
        }
    }

    /// <summary>
    /// Opens a trade as the player who offered it: Friend accepts the offer.
    /// </summary>
    public void Open()
    {
        Machine.TakeFrame(Handed(null, true));
        Message(FromFriend("accept"));
        Frames(1);
        Machine.TakeFrame(Handed(null, false));
    }

    /// <summary>
    /// Forgets what was recorded.
    /// </summary>
    public void Clear()
    {
        Sent.Clear();
        Notices.Clear();
        RelayCalls.Clear();
        Applied.Clear();
        Events.Clear();
    }

    /// <summary>
    /// Finds Friend.
    /// </summary>
    /// <returns>Friend.</returns>
    public Peer Friend() => Room.At(FriendSeat) ?? throw new InvalidOperationException("Friend is not in the world.");

    /// <summary>
    /// Lists the kinds of the trade messages sent.
    /// </summary>
    /// <returns>Each one's "trade" field.</returns>
    public List<string> SentKinds() => [.. Sent.Select(sent => WorldFields.Parse(sent.Text, out _).Text(TradeMachine.Field))];

    /// <inheritdoc />
    bool IWorldRoomHost.Send(int seat, string text)
    {
        if (!text.StartsWith("trade=", StringComparison.Ordinal))
        {
            return true;
        }

        Sent.Add((seat, text));
        return !SendFails;
    }

    /// <inheritdoc />
    void IWorldRoomHost.Log(string line) => Logged.Add(line);

    /// <inheritdoc />
    void IWorldRoomHost.Notice(string text)
    {
        if (!RoomNotices.Any(text.EndsWith))
        {
            Notices.Add(text);
        }
    }

    /// <inheritdoc />
    void IWorldRoomHost.PeerTold(Peer peer)
    {
    }

    /// <inheritdoc />
    void IWorldRoomHost.PeerAway(Peer peer)
    {
    }

    /// <inheritdoc />
    void IWorldRoomHost.PeerDisplaced(Peer peer)
    {
    }

    /// <inheritdoc />
    void IWorldRoomHost.PeerMoved(Peer peer, int from)
    {
    }

    /// <inheritdoc />
    void IWorldRoomHost.PeerLeft(Peer peer)
    {
    }

    /// <inheritdoc />
    void IWorldRoomHost.Routed(RoutedMessage message)
    {
    }

    /// <inheritdoc />
    bool ITradeRelay.Commit(string world, string trade, string partner, string offers)
    {
        RelayCalls.Add(["mp_trade_commit", world, trade, partner, offers]);
        if (CommitFails)
        {
            return false;
        }

        Commit = new TradeCommitState(trade, "sending");
        return true;
    }

    /// <inheritdoc />
    bool ITradeRelay.Cancel(string world, string trade)
    {
        RelayCalls.Add(["mp_trade_cancel", world, trade]);
        return true;
    }

    /// <inheritdoc />
    bool ITradeRelay.Done(string world, string trade)
    {
        RelayCalls.Add(["mp_trade_done", world, trade]);
        return true;
    }

    /// <inheritdoc />
    TradeCommitState? ITradeRelay.CommitNow() => Commit;

    /// <inheritdoc />
    bool ITradeRelay.FetchPending(string world)
    {
        RelayCalls.Add(["mp_trade_pending", world]);
        return !FetchFails;
    }

    /// <inheritdoc />
    TradePendingState ITradeRelay.PendingNow() => Pending;

    /// <inheritdoc />
    void ITradeScripts.OpenScreen(TradeSession session) => OpenScreenWanted = true;

    /// <inheritdoc />
    void ITradeScripts.TheirOffer(long revision, string offer) => Events.Add($"their_offer {revision} {offer}");

    /// <inheritdoc />
    void ITradeScripts.Note(string text) => Events.Add($"note {text}");

    /// <inheritdoc />
    void ITradeScripts.Closed() => OpenScreenWanted = false;

    /// <inheritdoc />
    void ITradeScripts.StopOffering() => Events.Add("stop_offering");

    /// <inheritdoc />
    void ITradeScripts.Declined(int seat, string partner, string reason, bool accepted) => Events.Add($"declined {seat} {partner} {reason} {accepted}");

    /// <inheritdoc />
    void ITradeScripts.Apply(string relayId, string name, string mine, string theirs)
    {
        Applied.Add([relayId, mine, theirs]);
        OpenScreenWanted = false;
    }

    /// <inheritdoc />
    void ITradeScripts.Recover(long save, IReadOnlyList<RecoveredTrade> trades) => Recovered.Add((save, trades));

    /// <summary>
    /// Writes Friend's state as their game tells it.
    /// </summary>
    /// <returns>The message.</returns>
    private static string FriendStateText()
    {
        var state = new WorldFields();
        foreach ((string key, string value) in FriendState)
        {
            state.Set(key, value);
        }

        return state.Encode();
    }
}
