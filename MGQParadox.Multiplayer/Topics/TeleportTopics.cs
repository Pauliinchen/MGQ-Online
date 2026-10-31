//----------------------------------------------------------------
//  TeleportTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Stopped carrying the warp ban of the member's place along
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Linq;
using System.Security.Cryptography;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Teleports;
using MGQOnline.Game.World;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// The bridge topics of the teleports between party members (<see cref="TeleportRequests"/>): the
/// player's actions, each answering the view the scripts read, the view itself with the player's
/// place, and the teleports' events.
/// </summary>
internal sealed class TeleportTopics : ITeleportHost
{
    /// <summary>
    /// Asks to teleport to a member: their seat in, the view out.
    /// </summary>
    public const string AskTopic = "tp.ask";

    /// <summary>
    /// Lets a member come: {"seat", "place" (the place fields, see <see cref="ViewTopic"/>)} in, the
    /// view out.
    /// </summary>
    public const string AllowTopic = "tp.allow";

    /// <summary>
    /// Declines a member's request: their seat in, the view out.
    /// </summary>
    public const string DeclineTopic = "tp.decline";

    /// <summary>
    /// Takes the player's request back: the reason in, the view out.
    /// </summary>
    public const string StopTopic = "tp.stop";

    /// <summary>
    /// Forgets the request and the requests answered, as a loaded save does: the reason in, the view out.
    /// </summary>
    public const string ForgetTopic = "tp.forget";

    /// <summary>
    /// Takes where the player stands and answers the view, once a frame: {"map", "x", "y", "d"}
    /// in; {"tpask" (the state's field), "doing" ({"text", "ends"}, the frame
    /// it lapses at; nil), "own" (the own row's choices) and "members" ({seat => {"text", "refusal",
    /// "request", "allow", "call", "notice", "action"}}, the texts of a request nil while none
    /// reaches the player)} out, nil while it is the view answered last.
    /// </summary>
    public const string ViewTopic = "tp.view";

    /// <summary>
    /// The event of a member letting the player come: {"name", "map", "x", "y", "d"}.
    /// </summary>
    public const string AllowedEvent = "tp.allowed";

    /// <summary>
    /// The event of a notice for the bottom left of the map: its text.
    /// </summary>
    public const string NoticeEvent = "tp.notice";

    /// <summary>
    /// The letters a request's number is made of.
    /// </summary>
    private const string NonceLetters = "0123456789abcdefghijklmnopqrstuvwxyz";

    /// <summary>
    /// The context the events go to.
    /// </summary>
    private readonly BridgeContext context;

    /// <summary>
    /// The room the party plays in.
    /// </summary>
    private readonly WorldRoom room;

    /// <summary>
    /// The view answered last in the open world, <see langword="null"/> while no world is open.
    /// </summary>
    private RubyHash? answered;

    /// <summary>
    /// Initializes the topics of a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="room">The room the party plays in.</param>
    private TeleportTopics(BridgeContext context, WorldRoom room)
    {
        this.context = context;
        this.room = room;
        Requests = new TeleportRequests(room, this, length => RandomNumberGenerator.GetString(NonceLetters, length));
    }

    /// <summary>
    /// Gets the teleports.
    /// </summary>
    public TeleportRequests Requests { get; }

    /// <summary>
    /// Registers the topics and the frame step on a context, after the room's own step.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="room">The room the party plays in.</param>
    /// <returns>The topics, for tests.</returns>
    public static TeleportTopics Register(BridgeContext context, WorldRoom room)
    {
        var topics = new TeleportTopics(context, room);
        TeleportRequests requests = topics.Requests;
        context.Register(AskTopic, (host, request) => topics.Act(() => requests.Ask(topics.PeerAt(request), host.Frame)));
        context.Register(AllowTopic, (_, request) => topics.Act(() => requests.Allow(topics.PeerAt(request.AsHash()["seat"]), PlaceOf(request.AsHash()["place"].AsHash()))));
        context.Register(DeclineTopic, (_, request) => topics.Act(() => requests.Decline(topics.PeerAt(request))));
        context.Register(StopTopic, (_, request) => topics.Act(() => requests.StopAsking(request.AsText())));
        context.Register(ForgetTopic, (_, request) => topics.Act(() => requests.Forget(request.AsText())));
        context.Register(ViewTopic, (_, request) => topics.ViewOnceChanged(PlaceOf(request.AsHash())));
        context.EveryFrame(host => topics.Step(host.Frame));
        return topics;
    }

    /// <inheritdoc />
    public void Allowed(string name, TeleportPlace place) => context.Events.Post(AllowedEvent, new RubyHash
    {
        { "name", name },
        { "map", place.Map },
        { "x", place.X },
        { "y", place.Y },
        { "d", place.Direction },
    });

    /// <inheritdoc />
    public void Notice(string text) => context.Events.Post(NoticeEvent, text);

    /// <summary>
    /// Reads a place as the scripts write it.
    /// </summary>
    /// <param name="fields">{"map", "x", "y", "d"}.</param>
    /// <returns>The place.</returns>
    private static TeleportPlace PlaceOf(RubyHash fields) =>
        new(fields["map"].AsLong(), fields["x"].AsLong(), fields["y"].AsLong(), fields["d"].AsLong());

    /// <summary>
    /// Runs the frame: the leader lets waiting members come, and the request runs out or goes with
    /// the world.
    /// </summary>
    /// <param name="frame">The drain's frame.</param>
    private void Step(long frame)
    {
        if (room.InWorld)
        {
            Requests.AllowWaiting();
        }
        else
        {
            answered = null;
        }

        Requests.Tick(room.InWorld, frame);
    }

    /// <summary>
    /// Takes where the player stands and answers the view once it changed, see <see cref="ViewTopic"/>.
    /// </summary>
    /// <param name="place">Where the player stands.</param>
    /// <returns>The view, <see langword="null"/> while it is the view answered last.</returns>
    private RubyHash? ViewOnceChanged(TeleportPlace place)
    {
        Requests.Place = place;
        RubyHash view = View();
        if (view.Equals(answered))
        {
            return null;
        }

        answered = view;
        return view;
    }

    /// <summary>
    /// Finds the player an action names by their seat.
    /// </summary>
    /// <param name="request">The seat.</param>
    /// <returns>The player.</returns>
    /// <exception cref="BridgeRequestException">No player told a state from that seat.</exception>
    private Peer PeerAt(RubyValue request) =>
        room.At(request.AsInt()) ?? throw new BridgeRequestException($"Nobody told a state from seat {request.AsInt()}.");

    /// <summary>
    /// Runs an action and answers the view afterwards.
    /// </summary>
    /// <param name="action">The action.</param>
    /// <returns>The view, see <see cref="ViewTopic"/>.</returns>
    private RubyHash Act(System.Action action)
    {
        action();
        return answered = View();
    }

    /// <summary>
    /// Describes the teleports as the scripts read them, see <see cref="ViewTopic"/>.
    /// </summary>
    /// <returns>The view.</returns>
    private RubyHash View()
    {
        var members = new RubyHash();
        foreach (Peer peer in room.Peers)
        {
            if (Requests.OfferOf(peer) is not { } offer)
            {
                continue;
            }

            bool request = offer.Request is not null;
            members.Add(peer.Seat, new RubyHash
            {
                { "text", offer.Text },
                { "refusal", offer.Refusal },
                { "request", offer.Request },
                { "allow", request ? TeleportRequests.AllowText : null },
                { "call", request ? TeleportRequests.CallText : null },
                { "notice", request ? TeleportRequests.NoticeOf(peer) : null },
                { "action", request ? TeleportRequests.NoticeAction : null },
            });
        }

        (string Text, long Ends)? doing = Requests.Doing;
        return new RubyHash
        {
            { "tpask", Requests.StateField },
            { "doing", doing is { } now ? new RubyHash { { "text", now.Text }, { "ends", now.Ends } } : RubyNil.Value },
            { "own", new RubyArray(Requests.OwnOptions.Select(text => (RubyValue)text)) },
            { "members", members },
        };
    }
}
