//----------------------------------------------------------------
//  HudTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Worked out the raid bars of a battle and of the map from the raid pools
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Hud;
using MGQOnline.Game.Raid;
using MGQOnline.Game.World;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// The bridge topics of what the map and the battle show over the world: the arrows toward the
/// players off the screen (<see cref="EdgeArrows"/>) and the raid bosses' bars (<see cref="RaidBars"/>).
/// </summary>
internal sealed class HudTopics
{
    /// <summary>
    /// The topic that points the arrows for a frame: {"reason" (why none show, nil while they may),
    /// "screen" ([width, height]), "top_room", "from" ([x, y] of the player's sprite), "ghosts"
    /// ({seat => [screen x, screen y, tiles, color's name]} of the ghosts on the map)} in;
    /// [[seat, x, y, stepped angle], ...] out, nearest first.
    /// </summary>
    public const string ArrowsTopic = "hud.arrows";

    /// <summary>
    /// The topic that lays out an arrow's picture: [stepped angle, plate's width] in; [left, top,
    /// width, height, plate x, plate y, slide x, slide y, rows ([[x, y, width, fill], ...])] out.
    /// </summary>
    public const string PictureTopic = "hud.arrow_picture";

    /// <summary>
    /// The topic that forgets which arrows were logged, as the map's sprites go.
    /// </summary>
    public const string ForgetTopic = "hud.arrows_forget";

    /// <summary>
    /// The topic that works out the bar of the battle running: {"title", "enemies" ([[name, hp, max
    /// HP, dead, pool's key (nil at a tier)], ...])} in; the bar out, nil for none.
    /// </summary>
    public const string BattleBarTopic = "hud.battle_bar";

    /// <summary>
    /// The topic that works out a troop's bar on the map: {"title", "keys" (of its pools, nil at a
    /// tier), "enemies" ([[name, own max HP], ...] as its setup makes them), "factor" (of max HP, its
    /// tier's), "letters" (the game's for repeated names, nil for its own)} in; the bar out.
    /// </summary>
    public const string MapBarTopic = "hud.map_bar";

    /// <summary>
    /// The room whose players the arrows point at.
    /// </summary>
    private readonly WorldRoom room;

    /// <summary>
    /// The raid pools, which the bars read.
    /// </summary>
    private readonly PoolLedger pools;

    /// <summary>
    /// The arrows' log.
    /// </summary>
    private readonly EdgeArrows arrows = new(Log.Write);

    /// <summary>
    /// Initializes the topics over a room and the raid pools.
    /// </summary>
    /// <param name="room">The room.</param>
    /// <param name="pools">The raid pools.</param>
    private HudTopics(WorldRoom room, PoolLedger pools)
    {
        this.room = room;
        this.pools = pools;
    }

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="room">The world room.</param>
    /// <param name="pools">The raid pools, which the bars only read.</param>
    public static void Register(BridgeContext context, WorldRoom room, PoolLedger pools)
    {
        var topics = new HudTopics(room, pools);
        context.Register(ArrowsTopic, (_, request) => topics.Arrows(request.AsHash()));
        context.Register(PictureTopic, (_, request) => Picture(request.AsArray()));
        context.Register(ForgetTopic, (_, _) =>
        {
            topics.arrows.Forget();
            return null;
        });
        context.Register(BattleBarTopic, (_, request) => BarOf(RaidBars.BattleBar(request.AsHash()["title"].AsText(), BattleEnemies(request.AsHash()["enemies"]), topics.pools)));
        context.Register(MapBarTopic, (_, request) => BarOf(topics.MapBar(request.AsHash())));
    }

    /// <summary>
    /// Writes a bar for the scripts: its title and each gauge's name, HP, max HP, short numbers and
    /// share left.
    /// </summary>
    /// <param name="bar">The bar, <see langword="null"/> for none.</param>
    /// <returns>[title, [[name, hp, max, numbers, percent], ...]], nil for none.</returns>
    private static RubyValue BarOf(RaidBar? bar) => bar is null ? RubyNil.Value : new RubyArray(
    [
        bar.Title,
        new RubyArray(bar.Gauges.Select(gauge => (RubyValue)new RubyArray([gauge.Name, gauge.Hp, gauge.Max, RaidBars.ShortNumbers(gauge.Hp, gauge.Max), RaidBars.Percent(gauge.Hp, gauge.Max)]))),
    ]);

    /// <summary>
    /// Reads the battle's enemies.
    /// </summary>
    /// <param name="value">[[name, hp, max HP, dead, pool's key], ...].</param>
    /// <returns>The enemies.</returns>
    private static List<BattleEnemy> BattleEnemies(RubyValue value) =>
        [.. value.AsArray().Select(each => each.AsArray()).Select(enemy => new BattleEnemy(enemy[0].AsText(), enemy[1].AsLong(), enemy[2].AsLong(), enemy[3].AsBool(), enemy[4].IsNil ? null : enemy[4].AsText()))];

    /// <summary>
    /// Works out a troop's bar on the map.
    /// </summary>
    /// <param name="request">See <see cref="MapBarTopic"/>.</param>
    /// <returns>The bar.</returns>
    private RaidBar MapBar(RubyHash request)
    {
        List<string>? keys = request["keys"].IsNil ? null : [.. request["keys"].AsArray().Select(key => key.AsText())];
        List<TroopEnemy> enemies = [.. request["enemies"].AsArray().Select(each => each.AsArray()).Select(enemy => new TroopEnemy(enemy[0].AsText(), enemy[1].AsLong()))];
        List<string>? letters = request["letters"].IsNil ? null : [.. request["letters"].AsArray().Select(letter => letter.AsText())];
        return RaidBars.MapBar(request["title"].AsText(), keys, enemies, request["factor"].AsLong(), letters, pools);
    }

    /// <summary>
    /// Lays out an arrow's picture.
    /// </summary>
    /// <param name="request">[stepped angle, plate's width].</param>
    /// <returns>The picture, see <see cref="PictureTopic"/>.</returns>
    private static RubyArray Picture(RubyArray request)
    {
        ArrowPicture picture = EdgeArrows.Picture(request[0].AsInt(), request[1].AsInt());
        RubyArray rows = new(picture.Rows.Select(row => (RubyValue)new RubyArray([row.X, row.Y, row.Width, row.Fill])));
        return new RubyArray([picture.Left, picture.Top, picture.Width, picture.Height, picture.PlateX, picture.PlateY, picture.SlideX, picture.SlideY, rows]);
    }

    /// <summary>
    /// Points the arrows for a frame and logs those that came and went.
    /// </summary>
    /// <param name="request">See <see cref="ArrowsTopic"/>.</param>
    /// <returns>The arrows.</returns>
    private RubyArray Arrows(RubyHash request)
    {
        int width = request["screen"].AsArray()[0].AsInt();
        int height = request["screen"].AsArray()[1].AsInt();
        RubyHash ghosts = request["ghosts"].AsHash();
        List<ArrowCandidate> players = [.. room.Peers.Select(peer => Candidate(peer, ghosts))];
        string? reason = request["reason"].IsNil ? null : request["reason"].AsText();
        List<ArrowCandidate> targets = reason is null ? EdgeArrows.Targets(players, room.Raid, width, height) : [];
        arrows.Note(reason, targets, players, room.Raid, width, height);
        (int Left, int Top, int Right, int Bottom) edge = EdgeArrows.EdgeRect(width, height, request["top_room"].AsInt());
        int fromX = request["from"].AsArray()[0].AsInt();
        int fromY = request["from"].AsArray()[1].AsInt() - EdgeArrows.HalfTile;
        var shown = new RubyArray();
        foreach (ArrowCandidate target in targets)
        {
            if (EdgeArrows.Point(fromX, fromY, target.ScreenX, target.MiddleY, edge) is { } point)
            {
                shown.Add(new RubyArray([target.Seat, point.X, point.Y, EdgeArrows.StepAngle(point.Angle)]));
            }
        }

        return shown;
    }

    /// <summary>
    /// Describes a player of the room for the arrows, with their ghost when it stands on the map.
    /// </summary>
    /// <param name="peer">The player.</param>
    /// <param name="ghosts">The ghosts on the map by seat.</param>
    /// <returns>The player.</returns>
    private ArrowCandidate Candidate(Peer peer, RubyHash ghosts)
    {
        RubyValue ghost = ghosts[peer.Seat];
        bool onMap = !ghost.IsNil && WorldFields.ToI(peer.State["map"]) == room.OwnMap;
        RubyArray place = ghost.IsNil ? new RubyArray([0, 0, 0, string.Empty]) : ghost.AsArray();
        return new ArrowCandidate(peer.Seat, peer.Id, peer.ToString(), peer.Present, onMap, peer.Member, place[0].AsInt(), place[1].AsInt(), place[2].AsInt(), place[3].AsText());
    }
}
