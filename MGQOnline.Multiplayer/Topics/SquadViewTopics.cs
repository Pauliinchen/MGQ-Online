//----------------------------------------------------------------
//  SquadViewTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Answered the squad only once it changed since the squad answered last
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Squads;
using MGQOnline.Game.World;

namespace MGQOnline.Multiplayer.Topics;

/// <summary>
/// The bridge topic of the player's squad over the party (<see cref="SquadView"/>), which the
/// scripts read once a frame.
/// </summary>
internal sealed class SquadViewTopics
{
    /// <summary>
    /// Reads the player's squad: {"max" (party_member_max), "own_mode" (the player's choice of
    /// followers), "raid", "raid_fight", "rules" (the Raid World's squad rules by their names, nil
    /// outside one)} in; {"share" ([front, bench], nil outside a party in a Classic world), "mode",
    /// "squads"} out, nil while it is the squad answered last.
    /// </summary>
    public const string ViewTopic = "squad.view";

    /// <summary>
    /// The room the party plays in.
    /// </summary>
    private readonly WorldRoom room;

    /// <summary>
    /// The squad answered last in the open world, <see langword="null"/> while no world is open.
    /// </summary>
    private SquadViewState? answered;

    /// <summary>
    /// Initializes the topic over a room.
    /// </summary>
    /// <param name="room">The room the party plays in.</param>
    private SquadViewTopics(WorldRoom room) => this.room = room;

    /// <summary>
    /// Registers the topic and the frame step on a context, over a room.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="room">The room the party plays in.</param>
    public static void Register(BridgeContext context, WorldRoom room)
    {
        var topics = new SquadViewTopics(room);
        context.Register(ViewTopic, (_, request) => topics.ViewOnceChanged(request.AsHash()));
        context.EveryFrame(_ => topics.ForgetOutsideWorld());
    }

    /// <summary>
    /// Forgets the squad answered last once no world is open, so the next world's first read answers it.
    /// </summary>
    private void ForgetOutsideWorld()
    {
        if (!room.InWorld)
        {
            answered = null;
        }
    }

    /// <summary>
    /// Reads the player's squad and answers it once it changed, see <see cref="ViewTopic"/>.
    /// </summary>
    /// <param name="request">What the scripts know of the player.</param>
    /// <returns>The squad, <see langword="null"/> while it is the squad answered last.</returns>
    private RubyHash? ViewOnceChanged(RubyHash request)
    {
        SquadRules rules = SquadRules.Default;
        if (request["rules"] is RubyHash named)
        {
            rules = new SquadRules(named["luka"].AsBool(), named["formation"].AsInt(), named["front"].AsInt(), named["raid_front"].AsInt());
        }

        SquadViewState view = SquadView.Of(room, request["max"].AsInt(), request["own_mode"].AsInt(), request["raid"].AsBool(), request["raid_fight"].AsBool(), rules);
        if (view == answered)
        {
            return null;
        }

        answered = view;
        return new RubyHash
        {
            { "share", view.Share is { } share ? new RubyArray { share.Front, share.Bench } : RubyNil.Value },
            { "mode", view.Mode },
            { "squads", view.Squads },
        };
    }
}
