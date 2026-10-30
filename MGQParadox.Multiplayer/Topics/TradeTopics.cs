//----------------------------------------------------------------
//  TradeTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Ids;
using MGQOnline.Game.Trade;
using MGQOnline.Game.World;
using MGQParadox.Multiplayer.Network.World;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// The bridge topics of trades between two players (<see cref="TradeMachine"/>): what the scripts
/// tell each frame and the trade screen's actions in, the trade's events and its view out. The
/// trade's messages come through the world room's route of the field "trade".
/// </summary>
internal sealed class TradeTopics : ITradeScripts
{
    /// <summary>
    /// The topic the scripts stage each frame's facts with, once they changed: {"busy" (why the
    /// player may not open a trade, nil while they may), "inviting", "targets", "world", "on_map",
    /// "save" (the loaded save as the scripts tell one apart)}.
    /// </summary>
    public const string TickTopic = "trade.tick";

    /// <summary>
    /// The topic that accepts another player's trade offer: their seat in, the view out.
    /// </summary>
    public const string AcceptTopic = "trade.accept";

    /// <summary>
    /// The topic that turns another player down: {"seat", "reason"} in, the view out.
    /// </summary>
    public const string DeclineTopic = "trade.decline";

    /// <summary>
    /// The topic of the player's offer after a change, as the scripts wrote it: the text in, the view out.
    /// </summary>
    public const string OfferTopic = "trade.offer";

    /// <summary>
    /// The topic that confirms both offers or takes the confirmation back: why the player's game
    /// cannot take the other player's offer (nil while it can) in, the view out.
    /// </summary>
    public const string ConfirmTopic = "trade.confirm";

    /// <summary>
    /// The topic that cancels the trade: the view out.
    /// </summary>
    public const string CancelTopic = "trade.cancel";

    /// <summary>
    /// The topic that tells the relay a save holds a trade the scripts applied: its id at the relay in.
    /// </summary>
    public const string DoneTopic = "trade.done";

    /// <summary>
    /// The topic of the trade's view, which is also the event of the view once it changed, see <see cref="ViewOf"/>.
    /// </summary>
    public const string ViewTopic = "trade.view";

    /// <summary>
    /// The event that has the map open the trade screen: {"id", "partner", "name"}.
    /// </summary>
    public const string OpenScreenEvent = "trade.open_screen";

    /// <summary>
    /// The event of the other player's offer: {"rev", "text"}.
    /// </summary>
    public const string TheirOfferEvent = "trade.their_offer";

    /// <summary>
    /// The event of a message for the trade screen: its text.
    /// </summary>
    public const string NoteEvent = "trade.note";

    /// <summary>
    /// The event of a trade that ended.
    /// </summary>
    public const string ClosedEvent = "trade.closed";

    /// <summary>
    /// The event that stops the player's own trade offer, as a trade opened.
    /// </summary>
    public const string StopOfferingEvent = "trade.stop_offering";

    /// <summary>
    /// The event of another player who could not trade: {"seat", "id", "reason", "accepted"}.
    /// </summary>
    public const string DeclinedEvent = "trade.declined";

    /// <summary>
    /// The event of a trade the relay committed, which the scripts apply: {"id" (at the relay), "name", "mine", "theirs"}.
    /// </summary>
    public const string ApplyEvent = "trade.apply";

    /// <summary>
    /// The event of the committed trades a save may lack: {"save" (the one they were asked for),
    /// "trades" ([[id at the relay, partner, mine, theirs], ...])}.
    /// </summary>
    public const string RecoverEvent = "trade.recover";

    /// <summary>
    /// The context the events go to.
    /// </summary>
    private readonly BridgeContext _context;

    /// <summary>
    /// The open world.
    /// </summary>
    private readonly WorldRoom _room;

    /// <summary>
    /// The view posted last.
    /// </summary>
    private RubyValue? _posted;

    /// <summary>
    /// Initializes the topics of a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="room">The open world.</param>
    /// <param name="relay">The relay's trades.</param>
    /// <param name="newId">Makes up a trade's id.</param>
    private TradeTopics(BridgeContext context, WorldRoom room, ITradeRelay relay, Func<string> newId)
    {
        _context = context;
        _room = room;
        Machine = new TradeMachine(room, relay, this, newId);
    }

    /// <summary>
    /// Gets the trade.
    /// </summary>
    internal TradeMachine Machine { get; }

    /// <summary>
    /// Registers the topics, the trade's route and its frame step on a context, over the game's trades at the relay.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="room">The open world, whose frame step the trade's follows.</param>
    public static void Register(BridgeContext context, WorldRoom room)
    {
        Random random = new();
        Register(context, room, WorldTrades.Current, () => RandomId.Of(random, 24, 16));
    }

    /// <summary>
    /// Registers the topics, the trade's route and its frame step on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="room">The open world, whose frame step the trade's follows.</param>
    /// <param name="relay">The relay's trades.</param>
    /// <param name="newId">Makes up a trade's id.</param>
    /// <returns>The topics, for tests.</returns>
    internal static TradeTopics Register(BridgeContext context, WorldRoom room, ITradeRelay relay, Func<string> newId)
    {
        var topics = new TradeTopics(context, room, relay, newId);
        TradeMachine machine = topics.Machine;
        room.Take(TradeMachine.Field, RouteGate.None, machine.Take);
        context.Register(TickTopic, (_, request) =>
        {
            machine.TakeFrame(FrameOf(request.AsHash()));
            return null;
        });
        context.Register(AcceptTopic, (_, request) => topics.Act(() => machine.Accept(topics.PeerAt(request))));
        context.Register(DeclineTopic, (_, request) => topics.Act(() =>
        {
            RubyHash decline = request.AsHash();
            machine.Decline(topics.PeerAt(decline["seat"]), decline["reason"].AsText());
        }));
        context.Register(OfferTopic, (_, request) => topics.Act(() => machine.Offer(ValidOffer(request.AsText()))));
        context.Register(ConfirmTopic, (_, request) => topics.Act(() => machine.ToggleConfirm(request.IsNil ? null : request.AsText())));
        context.Register(CancelTopic, (_, _) => topics.Act(machine.Cancel));
        context.Register(DoneTopic, (_, request) =>
        {
            machine.Done(request.AsText());
            return null;
        });
        context.Register(ViewTopic, (_, _) => topics.ViewOf());
        context.EveryFrame(_ =>
        {
            machine.Step();
            topics.FlushView();
        });
        return topics;
    }

    /// <inheritdoc />
    public void OpenScreen(TradeSession session) =>
        _context.Events.Post(OpenScreenEvent, new RubyHash { { "id", session.Id }, { "partner", session.Partner }, { "name", session.Name } });

    /// <inheritdoc />
    public void TheirOffer(long revision, string offer) => _context.Events.Post(TheirOfferEvent, new RubyHash { { "rev", revision }, { "text", offer } });

    /// <inheritdoc />
    public void Note(string text) => _context.Events.Post(NoteEvent, text);

    /// <inheritdoc />
    public void Closed() => _context.Events.Post(ClosedEvent, RubyNil.Value);

    /// <inheritdoc />
    public void StopOffering() => _context.Events.Post(StopOfferingEvent, RubyNil.Value);

    /// <inheritdoc />
    public void Declined(int seat, string partner, string reason, bool accepted) =>
        _context.Events.Post(DeclinedEvent, new RubyHash { { "seat", seat }, { "id", partner }, { "reason", reason }, { "accepted", accepted } });

    /// <inheritdoc />
    public void Apply(string relayId, string name, string mine, string theirs) =>
        _context.Events.Post(ApplyEvent, new RubyHash { { "id", relayId }, { "name", name }, { "mine", mine }, { "theirs", theirs } });

    /// <inheritdoc />
    public void Recover(long save, IReadOnlyList<RecoveredTrade> trades) => _context.Events.Post(RecoverEvent, new RubyHash
    {
        { "save", save },
        { "trades", new RubyArray(trades.Select(trade => (RubyValue)new RubyArray { trade.Id, trade.Partner, trade.Mine, trade.Theirs })) },
    });

    /// <summary>
    /// Reads what the scripts tell each frame.
    /// </summary>
    /// <param name="request">{"busy", "inviting", "targets", "world", "on_map", "save"}.</param>
    /// <returns>The frame.</returns>
    private static TradeFrame FrameOf(RubyHash request) => new(
        request["busy"].IsNil ? null : request["busy"].AsText(),
        request["inviting"] is RubyBool { Flag: true },
        [.. request["targets"].AsArray().Select(target => target.AsText())],
        request["world"].IsNil ? string.Empty : request["world"].AsText(),
        request["on_map"] is RubyBool { Flag: true },
        request["save"].IsNil ? 0 : request["save"].AsLong());

    /// <summary>
    /// Checks the player's offer as the scripts wrote it.
    /// </summary>
    /// <param name="offer">The offer.</param>
    /// <returns>The offer.</returns>
    /// <exception cref="BridgeRequestException">No game writes such an offer.</exception>
    private static string ValidOffer(string offer) =>
        TradeOffers.IsValid(offer) ? offer : throw new BridgeRequestException($"The offer {offer} is not one a game writes.");

    /// <summary>
    /// Finds the player an action names by their seat.
    /// </summary>
    /// <param name="request">The seat.</param>
    /// <returns>The player.</returns>
    /// <exception cref="BridgeRequestException">No player told a state from that seat.</exception>
    private Peer PeerAt(RubyValue request) =>
        _room.At(request.AsInt()) ?? throw new BridgeRequestException($"Nobody told a state from seat {request.AsInt()}.");

    /// <summary>
    /// Runs an action and answers the view afterwards.
    /// </summary>
    /// <param name="action">The action.</param>
    /// <returns>The view.</returns>
    private RubyValue Act(Action action)
    {
        action();
        FlushView();
        return ViewOf();
    }

    /// <summary>
    /// Posts the view when it changed since it was posted.
    /// </summary>
    private void FlushView()
    {
        RubyValue view = ViewOf();
        if (_posted is not null && _posted.Equals(view))
        {
            return;
        }

        _posted = view;
        _context.Events.Post(ViewTopic, view);
    }

    /// <summary>
    /// Describes the trade as the scripts read it many times a frame.
    /// </summary>
    /// <returns>{"session" (nil for none, else "id", "partner", "name", "stage" ("open" or
    /// "committing"), "my_rev", "their_rev", "confirmed", "their_confirmed", "relay_id", "leaving",
    /// "unsent" and "refusal", why the player cannot confirm as far as the trade goes), "accepted"
    /// (nil for none, else "id", "name" and "ends", the frame the wait runs out at)}.</returns>
    private RubyHash ViewOf()
    {
        TradeMachine machine = Machine;
        RubyValue session = RubyNil.Value;
        if (machine.Session is { } trade)
        {
            session = new RubyHash
            {
                { "id", trade.Id },
                { "partner", trade.Partner },
                { "name", trade.Name },
                { "stage", trade.StageName },
                { "my_rev", trade.MyRevision },
                { "their_rev", trade.TheirRevision },
                { "confirmed", trade.Confirmed },
                { "their_confirmed", trade.TheirConfirmed },
                { "relay_id", trade.RelayId },
                { "leaving", trade.Leaving },
                { "unsent", trade.Unsent is { } unsent ? unsent : RubyNil.Value },
                { "refusal", machine.ConfirmRefusal() },
            };
        }

        RubyValue accepted = RubyNil.Value;
        if (machine.Accepted is { } wait)
        {
            accepted = new RubyHash { { "id", wait.Id }, { "name", wait.Name }, { "ends", _context.Frame + TradeMachine.AnswerFrames - wait.Frames } };
        }

        return new RubyHash { { "session", session }, { "accepted", accepted } };
    }
}
