//----------------------------------------------------------------
//  SquadViewTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Squads;
using MGQOnline.Game.World;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// The bridge topic of the player's squad over the party (<see cref="SquadView"/>), which the
/// scripts read once a frame.
/// </summary>
internal static class SquadViewTopics
{
    /// <summary>
    /// Reads the player's squad: {"max" (party_member_max), "own_mode" (the player's choice of
    /// followers), "raid", "raid_fight", "rules" (the Raid World's squad rules by their names, nil
    /// outside one)} in; {"share" ([front, bench], nil outside a party in a Classic world), "mode",
    /// "squads"} out.
    /// </summary>
    public const string ViewTopic = "squad.view";

    /// <summary>
    /// Registers the topic on a context, over a room.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="room">The room the party plays in.</param>
    public static void Register(BridgeContext context, WorldRoom room) =>
        context.Register(ViewTopic, (_, request) => ViewOf(room, request.AsHash()));

    /// <summary>
    /// Reads the player's squad, see <see cref="ViewTopic"/>.
    /// </summary>
    /// <param name="room">The room the party plays in.</param>
    /// <param name="request">What the scripts know of the player.</param>
    /// <returns>The squad.</returns>
    private static RubyHash ViewOf(WorldRoom room, RubyHash request)
    {
        SquadRules rules = SquadRules.Default;
        if (request["rules"] is RubyHash named)
        {
            rules = new SquadRules(named["luka"].AsBool(), named["formation"].AsInt(), named["front"].AsInt(), named["raid_front"].AsInt());
        }

        SquadViewState view = SquadView.Of(room, request["max"].AsInt(), request["own_mode"].AsInt(), request["raid"].AsBool(), request["raid_fight"].AsBool(), rules);
        return new RubyHash
        {
            { "share", view.Share is { } share ? new RubyArray { share.Front, share.Bench } : RubyNil.Value },
            { "mode", view.Mode },
            { "squads", view.Squads },
        };
    }
}
