//----------------------------------------------------------------
//  NpcTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Took the events of a snapshot as [id, x, y, direction, page] each
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Npcs;
using MGQOnline.Game.World;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// The bridge topics of the NPCs players share on a map (<see cref="NpcSync"/>): the frame the
/// scripts hand over with who shares the map and its Map Owner, the Map Owner's events when the
/// frame asks for them, and the events the player's game follows.
/// </summary>
internal static class NpcTopics
{
    /// <summary>
    /// Runs a frame: {"map", "owner" (the Map Owner's seat, -1 for the player, nil while nobody
    /// shares the map), "arrivals" ({seat => when they came onto the map}, the others sharing it)} in;
    /// {"snapshot" (whether the Map Owner's events are needed now), "revision" (of the events
    /// followed)} out.
    /// </summary>
    public const string UpdateTopic = "npcs.update";

    /// <summary>
    /// Takes the Map Owner's events: {"map", "events" ("id:x,y,d,page" joined by ";")} in; {"turned"
    /// ([[id, page before, page now], ...], the pages that changed in what went to everyone)} out.
    /// </summary>
    public const string SnapshotTopic = "npcs.snapshot";

    /// <summary>
    /// Reads the events the player's game follows: {"revision", "whole" (whether a whole map came
    /// since the last read), "targets" ({id => [x, y, d, page]})} out.
    /// </summary>
    public const string TargetsTopic = "npcs.targets";

    /// <summary>
    /// Registers the topics on a context, over a room.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="room">The room the map is shared in.</param>
    /// <returns>The NPCs, for tests.</returns>
    public static NpcSync Register(BridgeContext context, WorldRoom room)
    {
        var npcs = new NpcSync(room);
        context.Register(UpdateTopic, (_, request) => UpdateOf(npcs, request.AsHash()));
        context.Register(SnapshotTopic, (_, request) => SnapshotOf(npcs, request.AsHash()));
        context.Register(TargetsTopic, (_, _) => TargetsOf(npcs));
        return npcs;
    }

    /// <summary>
    /// Runs a frame, see <see cref="UpdateTopic"/>.
    /// </summary>
    /// <param name="npcs">The NPCs.</param>
    /// <param name="request">The frame.</param>
    /// <returns>The answer.</returns>
    private static RubyHash UpdateOf(NpcSync npcs, RubyHash request)
    {
        int? owner = request["owner"].IsNil ? null : request["owner"].AsInt();
        var sharing = new List<(int Seat, string Since)>();
        if (!request["arrivals"].IsNil)
        {
            foreach (KeyValuePair<RubyValue, RubyValue> arrival in request["arrivals"].AsHash())
            {
                sharing.Add((arrival.Key.AsInt(), arrival.Value.AsText()));
            }
        }

        NpcFrame frame = npcs.Update(request["map"].AsLong(), owner, sharing);
        return new RubyHash { { "snapshot", frame.Snapshot }, { "revision", frame.Revision } };
    }

    /// <summary>
    /// Takes the Map Owner's events, see <see cref="SnapshotTopic"/>.
    /// </summary>
    /// <param name="npcs">The NPCs.</param>
    /// <param name="request">The map and the events.</param>
    /// <returns>The answer.</returns>
    private static RubyHash SnapshotOf(NpcSync npcs, RubyHash request)
    {
        List<(long, IReadOnlyList<long>)> events = [.. request["events"].AsArray().Select(entry => entry.AsArray())
            .Select(entry => (entry[0].AsLong(), (IReadOnlyList<long>)[.. entry.Skip(1).Select(value => value.AsLong())]))];
        IReadOnlyList<NpcTurn> turned = npcs.Snapshot(request["map"].AsLong(), events);
        return new RubyHash { { "turned", new RubyArray(turned.Select(turn => (RubyValue)new RubyArray { turn.Id, turn.From, turn.To })) } };
    }

    /// <summary>
    /// Reads the events followed, see <see cref="TargetsTopic"/>.
    /// </summary>
    /// <param name="npcs">The NPCs.</param>
    /// <returns>The answer.</returns>
    private static RubyHash TargetsOf(NpcSync npcs)
    {
        var targets = new RubyHash();
        foreach (KeyValuePair<long, long[]> target in npcs.Targets)
        {
            targets.Add(target.Key, new RubyArray(target.Value.Select(value => (RubyValue)value)));
        }

        return new RubyHash { { "revision", npcs.Revision }, { "whole", npcs.TakeWhole() }, { "targets", targets } };
    }
}
