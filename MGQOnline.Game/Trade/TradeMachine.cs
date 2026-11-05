//----------------------------------------------------------------
//  TradeMachine.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Waited for a player away as long as the grace of Sessions
//      Paulinchen  2026-10-31: Took the not confirmed state of a player who never confirmed as no change
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Trade;

/// <summary>
/// A trade between the player and another player on the same map, as the player's game takes part
/// in it: accepting, opening and declining, both offers and their confirmations, the messages that
/// go out again after the other player was away or a message could not go out, and the relay's
/// commit of the confirmed offers. The scripts keep the items, the bag, the save and the screen.
/// </summary>
/// <remarks>
/// Its timers count the frames <see cref="Step"/> is called with. Nothing changes hands until the
/// relay committed the trade in one step, so a game that drops halfway never keeps both sides.
/// </remarks>
public sealed class TradeMachine
{
    /// <summary>
    /// The field that marks a trade's messages.
    /// </summary>
    public const string Field = "trade";

    /// <summary>
    /// Frames an accepted trade waits for the other player's game to open it, six seconds.
    /// </summary>
    public const int AnswerFrames = 360;

    /// <summary>
    /// Frames a trade waits for the other player once their connection dropped, the world's grace.
    /// </summary>
    public const int AwayFrames = Sessions.GraceFrames;

    /// <summary>
    /// Frames between two tries to send the player's offer and confirmation state again.
    /// </summary>
    public const int PollFrames = 15;

    /// <summary>
    /// What the scripts hand over as the reason the player is busy when the map is not free.
    /// </summary>
    public const string MapNotFree = "the map is not free";

    /// <summary>
    /// What starts the trade's lines in the log.
    /// </summary>
    private const string LogTag = "trade: ";

    /// <summary>
    /// Characters of a trade's id.
    /// </summary>
    private const int IdLength = 24;

    /// <summary>
    /// The kinds of trade message a game answers with a cancel when it has no such trade, never a
    /// cancel itself, so two games never answer each other's cancels.
    /// </summary>
    private static readonly string[] AnsweredStrays = ["offer", "confirm", "unconfirm"];

    /// <summary>
    /// The open world.
    /// </summary>
    private readonly WorldRoom room;

    /// <summary>
    /// The relay's trades.
    /// </summary>
    private readonly ITradeRelay relay;

    /// <summary>
    /// The scripts.
    /// </summary>
    private readonly ITradeScripts scripts;

    /// <summary>
    /// Makes up a trade's id.
    /// </summary>
    private readonly Func<string> newId;

    /// <summary>
    /// The keys of the lines logged once.
    /// </summary>
    private readonly HashSet<string> loggedOnce = new(StringComparer.Ordinal);

    /// <summary>
    /// When the relay is asked for the committed trades the save lacks.
    /// </summary>
    private readonly TradeRecovery recovery;

    /// <summary>
    /// What the scripts handed over last.
    /// </summary>
    private TradeFrame frame = TradeFrame.Idle;

    /// <summary>
    /// Frames since the last try to send the player's offer and confirmation state again.
    /// </summary>
    private int resendPoll;

    /// <summary>
    /// Whether a failed send is logged, which the tries to send again after the first leave out.
    /// </summary>
    private bool quiet;

    /// <summary>
    /// How the relay's commit stood when it was logged last.
    /// </summary>
    private TradeCommitState? relaySeen;

    /// <summary>
    /// Whether the relay's commit was logged at all for the running commit.
    /// </summary>
    private bool relayLogged;

    /// <summary>
    /// Initializes a machine with no trade.
    /// </summary>
    /// <param name="room">The open world.</param>
    /// <param name="relay">The relay's trades.</param>
    /// <param name="scripts">The scripts.</param>
    /// <param name="newId">Makes up a trade's id, 24 hexadecimal characters.</param>
    public TradeMachine(WorldRoom room, ITradeRelay relay, ITradeScripts scripts, Func<string> newId)
    {
        this.room = room ?? throw new ArgumentNullException(nameof(room));
        this.relay = relay ?? throw new ArgumentNullException(nameof(relay));
        this.scripts = scripts ?? throw new ArgumentNullException(nameof(scripts));
        this.newId = newId ?? throw new ArgumentNullException(nameof(newId));
        recovery = new TradeRecovery(relay, scripts, Log);
    }

    /// <summary>
    /// Gets the trade the player takes part in, <see langword="null"/> while there is none.
    /// </summary>
    public TradeSession? Session { get; private set; }

    /// <summary>
    /// Gets the other player's trade the player accepted, waiting for it to open; <see langword="null"/> while none.
    /// </summary>
    public AcceptedTrade? Accepted { get; private set; }

    /// <summary>
    /// Takes what the scripts tell of the player this frame.
    /// </summary>
    /// <param name="next">What they tell.</param>
    public void TakeFrame(TradeFrame next) => frame = next ?? throw new ArgumentNullException(nameof(next));

    /// <summary>
    /// Runs one frame: lets an accepted trade run out, follows the other player and the relay's
    /// answer, and asks for the trades the save lacks. Outside a world it forgets every trade.
    /// </summary>
    public void Step()
    {
        if (!room.InWorld)
        {
            Reset();
            return;
        }

        if (Accepted is { } accepted && ++accepted.Frames > AnswerFrames)
        {
            Log($"{accepted.Name} did not open the trade within {AnswerFrames / 60} s, stopped waiting");
            room.Notice($"{accepted.Name} did not open the trade.");
            Accepted = null;
        }

        if (Session is { } session)
        {
            if (session.Stage == TradeStage.Committing)
            {
                FollowCommit(session);
            }
            else
            {
                FollowPartner(session);
            }
        }

        recovery.Step(room.OwnId, frame.OnMap && Session is null, frame.World, frame.Save);
    }

    /// <summary>
    /// Tells why the player may not open a trade now.
    /// </summary>
    /// <returns>The reason, <see langword="null"/> while they may.</returns>
    public string? BusyReason()
    {
        if (frame.Busy == MapNotFree)
        {
            return MapNotFree;
        }

        return Session is { } session ? $"already in trade {Short(session.Id)}" : frame.Busy;
    }

    /// <summary>
    /// Tells why the player cannot confirm the offers as they stand, the scripts' own reasons aside.
    /// </summary>
    /// <returns>The reason, <see langword="null"/> while they can as far as the trade goes.</returns>
    public string? ConfirmRefusal()
    {
        if (Session is not { } session)
        {
            return TradeTexts.NoTrade;
        }

        if (session.Stage != TradeStage.Open)
        {
            return TradeTexts.Deciding;
        }

        if (TradeOffers.IsEmpty(session.Mine) && TradeOffers.IsEmpty(session.Theirs))
        {
            return TradeTexts.BothEmpty;
        }

        if (TradeOffers.IsTooLarge(AgreedText(session)))
        {
            return TradeTexts.TooLarge;
        }

        return session.Theirs.Length > 0 && !TradeOffers.IsValid(session.Theirs) ? TradeTexts.NotValid(session.Name) : null;
    }

    /// <summary>
    /// Accepts another player's trade offer: tells them, and waits for their game to open the trade.
    /// The scripts checked first that the player is free and stopped an offer of their own.
    /// </summary>
    /// <param name="peer">The player who offered it.</param>
    public void Accept(Peer peer)
    {
        ArgumentNullException.ThrowIfNull(peer);
        var fields = new WorldFields();
        fields.Set(Field, "accept");
        SendMessage(peer, fields);
        Accepted = new AcceptedTrade(peer.Id, peer.Name);
        Log($"accepted {peer.Name}'s trade, waiting up to {AnswerFrames / 60} s for their game to open it");
        room.Notice($"You accepted {peer.Name}'s trade.");
    }

    /// <summary>
    /// Turns another player down, telling them why.
    /// </summary>
    /// <param name="peer">The other player.</param>
    /// <param name="reason">A key of <see cref="TradeTexts.Reasons"/>.</param>
    /// <param name="id">The trade's id, for a trade that was opened.</param>
    /// <param name="why">What led to it, for the log.</param>
    public void Decline(Peer peer, string reason, string? id = null, string? why = null)
    {
        ArgumentNullException.ThrowIfNull(peer);
        var fields = new WorldFields();
        fields.Set(Field, "decline");
        fields.Set("reason", reason);
        if (id is not null)
        {
            fields.Set("tid", id);
        }

        SendMessage(peer, fields);
        Log($"declined {peer.Name}: {reason}{(why is null ? string.Empty : $" ({why})")}");
    }

    /// <summary>
    /// Takes the player's offer as the scripts wrote it after a change, which takes back both
    /// confirmations and is told to the other player.
    /// </summary>
    /// <param name="offer">The offer, see <see cref="TradeOffers.IsValid"/>.</param>
    /// <returns>Whether the trade took it: one is open.</returns>
    public bool Offer(string offer)
    {
        if (Session is not { Stage: TradeStage.Open } session)
        {
            return false;
        }

        session.Mine = offer;
        OfferChanged(session);
        return true;
    }

    /// <summary>
    /// Confirms both offers as they stand, or takes the confirmation back. The trade goes to the relay
    /// once both players confirmed the same offers.
    /// </summary>
    /// <param name="receiveRefusal">Why the player's game cannot take the other player's offer, as
    /// the scripts tell from the bag; <see langword="null"/> while it can.</param>
    public void ToggleConfirm(string? receiveRefusal)
    {
        if (Session is not { Stage: TradeStage.Open } session)
        {
            return;
        }

        if (session.Confirmed)
        {
            session.Confirmed = false;
            Log("took back my confirmation");
            Tell("unconfirm");
            return;
        }

        if ((ConfirmRefusal() ?? receiveRefusal) is { } refusal)
        {
            Log($"not confirming: {refusal}");
            Say(refusal);
            return;
        }

        session.Confirmed = true;
        Log($"confirmed my r{session.MyRevision} and {session.Name}'s r{session.TheirRevision}{(session.TheirConfirmed ? ", as they did" : ", waiting for them")}");
        TellConfirmation(session);
        if (session.Agreed)
        {
            Commit(session);
        }
    }

    /// <summary>
    /// Cancels the trade: at once while it is open, through the relay while it decides, which still
    /// completes a trade both games committed already.
    /// </summary>
    public void Cancel()
    {
        if (Session is not { } session)
        {
            return;
        }

        if (session.Leaving is not null)
        {
            Log("cancel pressed again, still waiting for the relay");
            return;
        }

        bool committing = session.Stage == TradeStage.Committing;
        Log($"cancelling trade {Short(session.Id)}{(committing ? " while the relay decides, waiting for its answer" : string.Empty)}");
        Tell("cancel", ("reason", "off"));
        if (!committing)
        {
            Close(TradeTexts.Cancelled);
            return;
        }

        session.Leaving = TradeTexts.Cancelled;
        AbandonCommit(session, "the player cancelled");
    }

    /// <summary>
    /// Tells the relay that the save holds a trade the scripts applied.
    /// </summary>
    /// <param name="relayId">The trade's id at the relay.</param>
    public void Done(string relayId) => relay.Done(frame.World, relayId);

    /// <summary>
    /// Takes a trade message, past the room's gates.
    /// </summary>
    /// <param name="peer">Who sent it, <see langword="null"/> before their first state.</param>
    /// <param name="message">The message's fields.</param>
    /// <param name="body">What follows them.</param>
    public void Take(Peer? peer, WorldFields message, string body)
    {
        ArgumentNullException.ThrowIfNull(message);
        string kind = message.Text(Field);
        if (peer is null)
        {
            LogOnce($"no peer {kind}", $"ignored a trade {kind} from a seat with no player");
            return;
        }

        try
        {
            LogMessage("got", peer, message, body);
            switch (kind)
            {
                case "accept":
                    TakeAccept(peer);
                    break;
                case "open":
                    TakeOpen(peer, message.Text("tid"));
                    break;
                case "decline":
                    TakeDecline(peer, message.Text("reason"), message["tid"]);
                    break;
                default:
                    TakeInSession(peer, message, body);
                    break;
            }
        }
        catch (Exception ex) when (ex is not OutOfMemoryException)
        {
            Log($"taking a trade message failed: {ex.GetType().Name}: {ex.Message}");
        }
    }

    /// <summary>
    /// Shortens a trade's id for the log, enough to tell trades apart.
    /// </summary>
    /// <param name="id">The trade's id, or its id at the relay.</param>
    /// <returns>Its first eight characters.</returns>
    internal static string Short(string? id) => id is null ? string.Empty : id.Length <= 8 ? id : id[..8];

    /// <summary>
    /// Writes both offers of a trade as the relay compares them.
    /// </summary>
    /// <param name="session">The trade.</param>
    /// <returns>The text.</returns>
    private string AgreedText(TradeSession session) => TradeOffers.AgreedText(room.OwnId, session.Mine, session.Partner, session.Theirs);

    /// <summary>
    /// Forgets every trade, as when the world closes. A trade the relay is deciding is recovered the
    /// next time the world opens.
    /// </summary>
    private void Reset()
    {
        recovery.Reset();
        if (Session is { } session)
        {
            Log($"left the world: dropped trade {Short(session.Id)} with {session.Name} ({session.StageName})");
            Session = null;
            scripts.Closed();
        }

        if (Accepted is { } accepted)
        {
            Log($"left the world: stopped waiting for {accepted.Name} to open the trade");
            Accepted = null;
        }
    }

    /// <summary>
    /// Follows the other player of an open trade: their offer and confirmation state go out again
    /// once they are back or once messages go out again, and the trade ends once they stayed away
    /// longer than <see cref="AwayFrames"/>.
    /// </summary>
    /// <param name="session">The trade.</param>
    private void FollowPartner(TradeSession session)
    {
        int away = session.Away;
        session.Away = PartnerPeer() is { Present: true } ? 0 : away + 1;
        if (away == 0 && session.Away > 0)
        {
            Log($"{session.Name} is away, waiting up to {AwayFrames / 60} s");
        }

        if (away > 0 && session.Away == 0)
        {
            Log($"{session.Name} is back after {away} frames");
            ResendState(session, $"{session.Name} is back");
        }
        else if (session.Away == 0)
        {
            RetryUnsent(session);
        }

        if (session.Away > AwayFrames)
        {
            Close($"{session.Name} left.");
        }
    }

    /// <summary>
    /// Sends the other player the player's offer and confirmation again, since what was sent while
    /// they were away or while messages could not go out may be lost. The other game ignores an offer
    /// revision it has and a confirmation state it holds.
    /// </summary>
    /// <remarks>
    /// A lost "unconfirm" would let the other game commit on the player's old confirmation alone and
    /// wait for the relay to time it out.
    /// </remarks>
    /// <param name="session">The trade.</param>
    /// <param name="why">Why they go out again, for the log.</param>
    /// <returns>Whether every message went out, which clears the trade's mark of a message that could not.</returns>
    private bool ResendState(TradeSession session, string why)
    {
        if (session.Stage != TradeStage.Open)
        {
            return false;
        }

        bool? offer = session.MyRevision > 0 ? Tell("offer", session.Mine, ("rev", Text(session.MyRevision))) : true;
        bool? confirmation = TellConfirmation(session);
        if (offer != true || confirmation != true)
        {
            return false;
        }

        session.Unsent = null;
        Log($"sent my offer r{session.MyRevision} and my confirmation state ({(session.Confirmed ? "confirmed" : "not confirmed")}) again: {why}");
        return true;
    }

    /// <summary>
    /// Tells the other player whether the player confirmed the offers as they stand.
    /// </summary>
    /// <param name="session">The trade.</param>
    /// <returns>Whether it went out, <see langword="null"/> when the other player is not in the world.</returns>
    private bool? TellConfirmation(TradeSession session) =>
        session.Confirmed ? Tell("confirm", ("mine", Text(session.MyRevision)), ("yours", Text(session.TheirRevision))) : Tell("unconfirm");

    /// <summary>
    /// Marks the trade once a message to the other player could not go out, so the player's offer and
    /// confirmation state go out again once messages do.
    /// </summary>
    /// <param name="session">The trade.</param>
    private void MarkUnsent(TradeSession session)
    {
        if (session.Unsent is not null)
        {
            return;
        }

        session.Unsent = 0;
        Log($"trade {Short(session.Id)}: my offer and confirmation state go out again once messages to {session.Name} do");
    }

    /// <summary>
    /// Tries to send the player's offer and confirmation state again every <see cref="PollFrames"/>
    /// while the trade is marked for a message that could not go out, until they go out. Only the
    /// first failed try logs its messages, since the world's connection may stay down for long.
    /// </summary>
    /// <param name="session">The trade, open and with the other player in the world.</param>
    private void RetryUnsent(TradeSession session)
    {
        if (session.Unsent is not { } unsent || ++resendPoll < PollFrames)
        {
            return;
        }

        resendPoll = 0;
        int tries = unsent + 1;
        quiet = tries > 1;
        try
        {
            if (!ResendState(session, $"messages to {session.Name} go out again after {tries} {(tries == 1 ? "try" : "tries")}"))
            {
                session.Unsent = tries;
            }
        }
        finally
        {
            quiet = false;
        }
    }

    /// <summary>
    /// Finds the other player of the trade, who may have come back on another seat.
    /// </summary>
    /// <returns>The player, <see langword="null"/> while they are gone.</returns>
    private Peer? PartnerPeer() => Session is { } session ? room.Peers.FirstOrDefault(peer => peer.Id == session.Partner) : null;

    /// <summary>
    /// Sends a message of the trade to the other player.
    /// </summary>
    /// <param name="kind">What the message is.</param>
    /// <param name="fields">Its fields besides "trade" and "tid".</param>
    /// <returns>Whether it went out, <see langword="null"/> when the other player is not in the world.</returns>
    private bool? Tell(string kind, params (string Key, string Value)[] fields) => Tell(kind, string.Empty, fields);

    /// <summary>
    /// Sends a message of the trade to the other player.
    /// </summary>
    /// <param name="kind">What the message is.</param>
    /// <param name="body">What follows the fields.</param>
    /// <param name="fields">Its fields besides "trade" and "tid".</param>
    /// <returns>Whether it went out, <see langword="null"/> when the other player is not in the world.</returns>
    private bool? Tell(string kind, string body, params (string Key, string Value)[] fields)
    {
        if (PartnerPeer() is not { } peer || Session is not { } session)
        {
            Log($"not sent {kind}: {(Session is { } trade ? trade.Name + " is not in the world" : "there is no trade")}");
            return null;
        }

        var message = new WorldFields();
        message.Set(Field, kind);
        message.Set("tid", session.Id);
        foreach ((string key, string value) in fields)
        {
            message.Set(key, value);
        }

        bool sent = SendMessage(peer, message, body);
        if (!sent)
        {
            MarkUnsent(session);
        }

        return sent;
    }

    /// <summary>
    /// Sends a message to another player and logs it.
    /// </summary>
    /// <param name="peer">The other player.</param>
    /// <param name="fields">The message's fields.</param>
    /// <param name="body">What follows the fields.</param>
    /// <returns>Whether it went out.</returns>
    private bool SendMessage(Peer peer, WorldFields fields, string body = "")
    {
        bool sent = room.Send(peer.Seat, fields.Encode(body));
        if (sent)
        {
            LogMessage("sent", peer, fields, body);
        }
        else if (!quiet)
        {
            Log($"could not send {fields.Text(Field)} to {peer}: the world's connection is down");
        }

        return sent;
    }

    /// <summary>
    /// Logs a trade message sent or received, summarized: its kind, the player, the trade and the
    /// fields besides those, and the size of its body.
    /// </summary>
    /// <param name="verb">"sent" or "got".</param>
    /// <param name="peer">The other player.</param>
    /// <param name="fields">The message's fields.</param>
    /// <param name="body">What follows the fields.</param>
    private void LogMessage(string verb, Peer peer, WorldFields fields, string body)
    {
        List<string> rest = [.. fields.Where(pair => pair.Key is not Field and not "tid").Select(pair => $"{pair.Key}={pair.Value}")];
        if (body.Length > 0)
        {
            rest.Add($"{Encoding.UTF8.GetByteCount(body)} bytes");
        }

        string trade = fields["tid"] is { } tid ? $", trade {Short(tid)}" : string.Empty;
        Log($"{verb} {fields.Text(Field)} {(verb == "sent" ? "to" : "from")} {peer}{trade}{(rest.Count == 0 ? string.Empty : ": " + string.Join(", ", rest))}");
    }

    /// <summary>
    /// Takes a message of the running trade, from its other player; a message of a trade the game no
    /// longer has is answered with a cancel.
    /// </summary>
    /// <param name="peer">Who sent it.</param>
    /// <param name="message">The message's fields.</param>
    /// <param name="body">What follows them.</param>
    private void TakeInSession(Peer peer, WorldFields message, string body)
    {
        TradeSession? session = Session;
        string kind = message.Text(Field);
        string id = message.Text("tid");
        bool other = session is null || session.Id != id;
        string? stray = session is null ? "there is no trade"
            : session.Id != id ? $"it names trade {Short(id)}, not {Short(session.Id)}"
            : session.Partner != peer.Id ? $"{peer.Name} is not the other player of the trade"
            : null;
        if (stray is not null)
        {
            Log($"ignored {peer.Name}'s trade {kind}: {stray}");
            if (other)
            {
                AnswerStray(peer, kind, id);
            }

            return;
        }

        switch (kind)
        {
            case "offer":
                TakeOffer(session!, WorldFields.ToI(message["rev"]), body);
                break;
            case "confirm":
                TakeConfirm(session!, WorldFields.ToI(message["mine"]), WorldFields.ToI(message["yours"]));
                break;
            case "unconfirm":
                TakeUnconfirm(session!);
                break;
            case "cancel":
                TakeCancel(session!, message.Text("reason"));
                break;
            default:
                Log($"ignored {peer.Name}'s trade {kind}: unknown kind");
                break;
        }
    }

    /// <summary>
    /// Answers a message of a trade the player's game no longer has with a cancel, so the other
    /// player's trade closes instead of waiting for an answer that never comes.
    /// </summary>
    /// <param name="peer">Who sent it.</param>
    /// <param name="kind">What the message is.</param>
    /// <param name="id">The trade it names.</param>
    private void AnswerStray(Peer peer, string kind, string id)
    {
        if (id.Length == 0 || !AnsweredStrays.Contains(kind))
        {
            return;
        }

        Log($"answered {peer.Name}'s {kind} of trade {Short(id)} with a cancel: the player has no such trade");
        var fields = new WorldFields();
        fields.Set(Field, "cancel");
        fields.Set("tid", id);
        fields.Set("reason", "off");
        SendMessage(peer, fields);
    }

    /// <summary>
    /// As the player who offered the trade, opens it with the player who accepted.
    /// </summary>
    /// <param name="peer">The player who accepted.</param>
    private void TakeAccept(Peer peer)
    {
        bool covered = frame.Inviting && (room.Near(peer.State) || frame.Targets.Contains(peer.Id, StringComparer.Ordinal));
        if (!covered || !SameMap(peer))
        {
            Decline(peer, "gone", null, frame.Inviting ? "the offer does not reach them or they are not on the map" : "no trade offered");
            return;
        }

        if (BusyReason() is { } busy)
        {
            Decline(peer, "busy", null, busy);
            return;
        }

        frame = frame with { Inviting = false, Targets = [] };
        scripts.StopOffering();
        string id = newId();
        var fields = new WorldFields();
        fields.Set(Field, "open");
        fields.Set("tid", id);
        SendMessage(peer, fields);
        BeginSession(id, peer);
    }

    /// <summary>
    /// As the player who accepted, opens the trade the other player opened.
    /// </summary>
    /// <param name="peer">The player who offered it.</param>
    /// <param name="id">The trade's id.</param>
    private void TakeOpen(Peer peer, string id)
    {
        if (Accepted?.Id != peer.Id)
        {
            Log($"refused trade {Short(id)} from {peer.Name}: the player accepted no trade of theirs");
            var fields = new WorldFields();
            fields.Set(Field, "cancel");
            fields.Set("tid", id);
            fields.Set("reason", "busy");
            SendMessage(peer, fields);
            return;
        }

        Accepted = null;
        if (id.Length != IdLength || id.AsSpan().IndexOfAnyExcept("0123456789abcdef") >= 0)
        {
            room.Notice($"The trade with {peer.Name} could not open.");
            Decline(peer, "invalid", id, $"the trade id {ShortText(id, 30)} is not valid");
            return;
        }

        if (BusyReason() is { } busy)
        {
            // The player accepted it, so they wait for the screen, such as one who opened the menu meanwhile.
            room.Notice($"The trade with {peer.Name} could not open: finish what you are doing first.");
            Decline(peer, "busy", id, busy);
            return;
        }

        BeginSession(id, peer);
    }

    /// <summary>
    /// Starts a trade and has the map open its screen.
    /// </summary>
    /// <param name="id">The trade's id.</param>
    /// <param name="peer">The other player.</param>
    private void BeginSession(string id, Peer peer)
    {
        Session = new TradeSession(id, peer.Id, peer.Name);
        resendPoll = 0;
        scripts.OpenScreen(Session);
        Log($"trade {Short(id)} opened with {peer.Name} (seat {peer.Seat})");
    }

    /// <summary>
    /// Tells why the other player could not trade.
    /// </summary>
    /// <param name="peer">The other player.</param>
    /// <param name="reason">A key of <see cref="TradeTexts.Reasons"/>.</param>
    /// <param name="id">The trade's id, for a trade that was opened.</param>
    private void TakeDecline(Peer peer, string reason, string? id)
    {
        bool accepted = Accepted?.Id == peer.Id;
        if (accepted)
        {
            Accepted = null;
        }

        scripts.Declined(peer.Seat, peer.Id, reason, accepted);
        Log($"{peer.Name} {TradeTexts.Reasons.GetValueOrDefault(reason, TradeTexts.UnknownDecline)} ({reason}{(id is null ? string.Empty : $", trade {Short(id)}")})");
        string text = TradeTexts.Declined(peer.Name, reason);
        if (Session is { Stage: TradeStage.Open } session && id is not null && session.Id == id)
        {
            Close(text);
        }
        else
        {
            room.Notice(text);
        }
    }

    /// <summary>
    /// Takes the other player's offer as it stands now, which takes back both confirmations.
    /// </summary>
    /// <param name="session">The trade.</param>
    /// <param name="revision">How often they changed it.</param>
    /// <param name="offer">The offer as text.</param>
    private void TakeOffer(TradeSession session, long revision, string offer)
    {
        if (revision <= session.TheirRevision)
        {
            Log($"ignored {session.Name}'s offer revision {revision}: revision {session.TheirRevision} is newer");
            return;
        }

        AbandonCommit(session, $"{session.Name} changed their offer");
        session.TheirRevision = revision;
        session.Theirs = offer;
        session.TheirConfirm = null;
        session.Confirmed = false;
        scripts.TheirOffer(revision, offer);
    }

    /// <summary>
    /// Takes the other player's confirmation, and commits once both confirmed the same offers.
    /// </summary>
    /// <param name="session">The trade.</param>
    /// <param name="mine">The revision of their own offer they confirmed.</param>
    /// <param name="yours">The revision of the player's offer they confirmed.</param>
    private void TakeConfirm(TradeSession session, long mine, long yours)
    {
        session.TheirConfirm = (mine, yours);
        string current = session.TheirConfirmed ? "the offers as they stand" : $"older offers (now their r{session.TheirRevision}, mine r{session.MyRevision})";
        string waiting = session.Stage != TradeStage.Open ? $", the trade is {session.StageName}" : session.Confirmed ? string.Empty : ", waiting for my confirmation";
        Log($"{session.Name} confirmed their r{mine} and my r{yours}: {current}{waiting}");
        if (session.Stage == TradeStage.Open && session.Agreed)
        {
            Commit(session);
        }
    }

    /// <summary>
    /// Takes back the other player's confirmation, and a commit the relay has not decided, since the
    /// other game no longer stands by it. The state of a player who has not confirmed, which their
    /// game sends again after they were away, changes nothing.
    /// </summary>
    /// <param name="session">The trade.</param>
    private void TakeUnconfirm(TradeSession session)
    {
        if (session.TheirConfirm is null)
        {
            Log($"{session.Name} has not confirmed yet");
            return;
        }

        session.TheirConfirm = null;
        Log($"{session.Name} took back their confirmation");
        AbandonCommit(session, $"{session.Name} took back their confirmation");
    }

    /// <summary>
    /// Ends the trade the other player cancelled: at once while it is open, through the relay while it
    /// decides, which still completes a trade both games committed already.
    /// </summary>
    /// <param name="session">The trade.</param>
    /// <param name="reason">A key of <see cref="TradeTexts.Reasons"/>.</param>
    private void TakeCancel(TradeSession session, string reason)
    {
        string text = $"{session.Name} {TradeTexts.Reasons.GetValueOrDefault(reason, TradeTexts.UnknownCancel)}.";
        if (session.Stage != TradeStage.Committing)
        {
            Close(text);
            return;
        }

        Log($"{session.Name} cancelled ({reason}) while the relay decides, waiting for its answer");
        session.Leaving ??= text;
        AbandonCommit(session, $"{session.Name} cancelled");
    }

    /// <summary>
    /// Tells the other player the player's new offer, which takes back both confirmations.
    /// </summary>
    /// <param name="session">The trade.</param>
    private void OfferChanged(TradeSession session)
    {
        session.MyRevision++;
        session.Confirmed = false;
        session.TheirConfirm = null;
        Tell("offer", session.Mine, ("rev", Text(session.MyRevision)));
    }

    /// <summary>
    /// Shows a message about the trade as a notice and on the trade screen.
    /// </summary>
    /// <param name="text">The message.</param>
    private void Say(string text)
    {
        scripts.Note(text);
        room.Notice(text);
    }

    /// <summary>
    /// Ends the trade, with a notice, and closes its screen.
    /// </summary>
    /// <param name="text">The notice.</param>
    private void Close(string text)
    {
        Log($"trade {Short(Session?.Id)} closed: {text}");
        if (Session is { } session)
        {
            session.Stage = TradeStage.Closed;
        }

        Session = null;
        scripts.Closed();
        room.Notice(text);
    }

    /// <summary>
    /// Hands the confirmed offers to the relay, which commits them once the other game sent the same.
    /// </summary>
    /// <param name="session">The trade.</param>
    private void Commit(TradeSession session)
    {
        session.RelayId = TradeOffers.RelayId(session.Id, room.OwnId, session.MyRevision, session.Partner, session.TheirRevision);
        if (!relay.Commit(frame.World, session.RelayId, session.Partner, AgreedText(session)))
        {
            Log($"trade {Short(session.Id)} (my r{session.MyRevision}, their r{session.TheirRevision}) could not be handed to the relay, my confirmation taken back");
            session.Confirmed = false;
            Tell("unconfirm");
            Say(TradeTexts.Unreached);
            return;
        }

        session.Stage = TradeStage.Committing;
        relayLogged = false;
    }

    /// <summary>
    /// Takes back a commit the relay has not decided, as when the other player changed their offer.
    /// </summary>
    /// <param name="session">The trade.</param>
    /// <param name="why">What took it back, for the log.</param>
    private void AbandonCommit(TradeSession session, string why)
    {
        if (session.Stage != TradeStage.Committing)
        {
            return;
        }

        Log($"asking the relay to cancel the commit of trade {Short(session.Id)}: {why}");
        relay.Cancel(frame.World, session.RelayId!);
    }

    /// <summary>
    /// Follows the relay's answer to the commit.
    /// </summary>
    /// <param name="session">The trade.</param>
    private void FollowCommit(TradeSession session)
    {
        TradeCommitState? state = relay.CommitNow();
        LogRelayState(state, session);
        if (state is null || state.Trade != session.RelayId)
        {
            return;
        }

        switch (state.State)
        {
            case "committed":
                Complete(session);
                break;
            case "cancelled":
                if (session.Leaving is { } leaving)
                {
                    Close(leaving);
                }
                else
                {
                    Reopen(session, TradeTexts.RelayReasons.GetValueOrDefault(state.Reason ?? string.Empty, TradeTexts.RelayCancelled));
                }

                break;
            case "failed":
                GiveUp(session);
                break;
        }
    }

    /// <summary>
    /// Logs how the relay's commit stands, once each time it changes.
    /// </summary>
    /// <param name="state">The commit, <see langword="null"/> before the first.</param>
    /// <param name="session">The trade.</param>
    private void LogRelayState(TradeCommitState? state, TradeSession session)
    {
        if (relayLogged && state == relaySeen)
        {
            return;
        }

        relayLogged = true;
        relaySeen = state;
        string which = string.IsNullOrEmpty(state?.Trade) ? "no trade" : $"trade {Short(state.Trade)}";
        string other = state?.Trade == session.RelayId ? string.Empty : " (not this commit yet)";
        List<string> extra = [];
        if (state?.Reason is { } reason)
        {
            extra.Add($"reason {reason}");
        }

        if (state?.Error is { } error)
        {
            extra.Add($"error {(error.Length <= 160 ? error : error[..160])}");
        }

        Log($"relay: {which} {state?.State ?? "unknown"}{other}{(extra.Count == 0 ? string.Empty : ", " + string.Join(", ", extra))}");
    }

    /// <summary>
    /// Ends a trade whose commit failed: cancels it at the relay, so the other game cannot commit it
    /// alone later, tells the other player and asks the relay again for trades to recover.
    /// </summary>
    /// <param name="session">The trade.</param>
    private void GiveUp(TradeSession session)
    {
        Log($"the commit of trade {Short(session.Id)} failed, cancelling it at the relay and asking again for trades to recover");
        relay.Cancel(frame.World, session.RelayId!);
        Tell("cancel", ("reason", "relay"));
        recovery.CheckAgain();
        Close(TradeTexts.GaveUp);
    }

    /// <summary>
    /// Opens the trade again after the relay turned the commit down, with both confirmations taken
    /// back. The player's offer is told again under a new revision, since confirming the same
    /// revisions again would name the trade the relay cancelled.
    /// </summary>
    /// <param name="session">The trade.</param>
    /// <param name="text">Why, as a notice.</param>
    private void Reopen(TradeSession session, string text)
    {
        Log($"trade {Short(session.Id)} reopened: {text}");
        session.Stage = TradeStage.Open;
        session.RelayId = null;
        OfferChanged(session);
        Say(text);
    }

    /// <summary>
    /// Ends the trade the relay committed and has the scripts apply it.
    /// </summary>
    /// <param name="session">The trade.</param>
    private void Complete(TradeSession session)
    {
        Log($"the relay committed trade {Short(session.Id)} with {session.Name}, applying it");
        session.Stage = TradeStage.Closed;
        Session = null;
        scripts.Apply(session.RelayId!, session.Name, session.Mine, session.Theirs);
    }

    /// <summary>
    /// Reports whether another player stands on the player's map, their connection standing.
    /// </summary>
    /// <param name="peer">The other player.</param>
    /// <returns>Whether they do.</returns>
    private bool SameMap(Peer peer) => peer.Present && WorldFields.ToI(peer.State["map"]) == room.OwnMap;

    /// <summary>
    /// Writes a number as the messages carry it.
    /// </summary>
    /// <param name="number">The number.</param>
    /// <returns>The text.</returns>
    private static string Text(long number) => number.ToString(System.Globalization.CultureInfo.InvariantCulture);

    /// <summary>
    /// Shortens a text for a line of the log, keeping it on one line, as the scripts' log does.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="length">The most characters kept.</param>
    /// <returns>The text, cut with "..." when longer.</returns>
    private static string ShortText(string text, int length)
    {
        string line = Regex.Replace(text, "[\r\n]+", " ");
        return line.Length > length ? $"{line[..(length - 3)]}..." : line;
    }

    /// <summary>
    /// Writes a line of the trade into the log.
    /// </summary>
    /// <param name="line">The line.</param>
    private void Log(string line) => room.Log(LogTag + line);

    /// <summary>
    /// Writes a line into the log the first time its key comes.
    /// </summary>
    /// <param name="key">What tells the line apart.</param>
    /// <param name="line">The line.</param>
    private void LogOnce(string key, string line)
    {
        if (loggedOnce.Add(key))
        {
            Log(line);
        }
    }
}

/// <summary>
/// Another player's trade the player accepted, waiting for their game to open it.
/// </summary>
/// <param name="id">The other player's id.</param>
/// <param name="name">Their name.</param>
public sealed class AcceptedTrade(string id, string name)
{
    /// <summary>
    /// Gets the other player's id.
    /// </summary>
    public string Id { get; } = id;

    /// <summary>
    /// Gets the other player's name.
    /// </summary>
    public string Name { get; } = name;

    /// <summary>
    /// Gets the frames waited so far.
    /// </summary>
    public int Frames { get; internal set; }
}

/// <summary>
/// What the scripts tell of the player each frame, for trades.
/// </summary>
/// <param name="Busy">Why the player may not open a trade, the trade itself aside; <see langword="null"/> while they may.</param>
/// <param name="Inviting">Whether the player offers a trade.</param>
/// <param name="Targets">The ids of the players the offer names, besides those nearby.</param>
/// <param name="World">The open world's id in the directory, empty for a world made before the directory.</param>
/// <param name="OnMap">Whether the map is the scene.</param>
/// <param name="Save">The loaded save as the scripts tell one apart from another.</param>
public sealed record TradeFrame(string? Busy, bool Inviting, IReadOnlyList<string> Targets, string World, bool OnMap = false, long Save = 0)
{
    /// <summary>
    /// Gets what holds before the scripts told anything.
    /// </summary>
    public static TradeFrame Idle { get; } = new(null, false, [], string.Empty);
}
