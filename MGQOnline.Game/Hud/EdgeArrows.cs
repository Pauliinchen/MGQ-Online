//----------------------------------------------------------------
//  EdgeArrows.cs
//
//  Changelog:
//      Paulinchen  2026-11-01: Left placing and drawing the arrows to the Mod Framework's markers
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Hud;

/// <summary>
/// Another player as the arrows look at them.
/// </summary>
/// <param name="Seat">Their game's seat.</param>
/// <param name="Id">Their player id, which tells their arrow from the others.</param>
/// <param name="Who">Their name and seat, for the log.</param>
/// <param name="Present">Whether their connection stands.</param>
/// <param name="OnMap">Whether their ghost stands on the player's map.</param>
/// <param name="Member">Whether they are in the player's party.</param>
/// <param name="ScreenX">Their ghost's screen x.</param>
/// <param name="ScreenY">Their ghost's screen y, the bottom of its tile.</param>
/// <param name="Tiles">The tiles to walk to them, the map's loop taken into account.</param>
/// <param name="Color">The name of their color, for the log.</param>
public sealed record ArrowCandidate(int Seat, string Id, string Who, bool Present, bool OnMap, bool Member, int ScreenX, int ScreenY, int Tiles, string Color)
{
    /// <summary>
    /// Gets the middle of their ghost's tile on the screen, y.
    /// </summary>
    public int MiddleY => ScreenY - EdgeArrows.HalfTile;
}

/// <summary>
/// The arrows at the screen's edge toward the players on the map whose ghost is off the screen:
/// party members always, everyone in a Raid World, the nearest <see cref="MaxArrows"/>, and the log
/// of arrows coming and going. The Mod Framework's markers place and draw them.
/// </summary>
public sealed class EdgeArrows
{
    /// <summary>
    /// Most arrows at once: the nearest players.
    /// </summary>
    public const int MaxArrows = 8;

    /// <summary>
    /// Pixels from a ghost's screen y, the bottom of its tile, up to the tile's middle.
    /// </summary>
    public const int HalfTile = 16;

    /// <summary>
    /// What starts the arrows' lines in the log.
    /// </summary>
    private const string LogTag = "edge arrows: ";

    /// <summary>
    /// Writes a line into the log.
    /// </summary>
    private readonly Action<string> log;

    /// <summary>
    /// The players whose arrows were logged as shown, by their ids, with how the log named them.
    /// </summary>
    private Dictionary<string, string> shown = new(StringComparer.Ordinal);

    /// <summary>
    /// The reason that hid the arrows last frame, <see langword="null"/> while they showed.
    /// </summary>
    private string? hidden;

    /// <summary>
    /// Initializes the arrows' log.
    /// </summary>
    /// <param name="log">Writes a line into the log.</param>
    public EdgeArrows(Action<string> log) => this.log = log ?? throw new ArgumentNullException(nameof(log));

    /// <summary>
    /// Finds the players to point at: on the player's map with their ghost off the screen, party
    /// members and in a Raid World everyone, the nearest <see cref="MaxArrows"/> by tiles, ties by id.
    /// </summary>
    /// <param name="players">The other players.</param>
    /// <param name="raid">Whether the world is a Raid World.</param>
    /// <param name="width">The screen's width.</param>
    /// <param name="height">The screen's height.</param>
    /// <returns>The players, nearest first.</returns>
    public static List<ArrowCandidate> Targets(IEnumerable<ArrowCandidate> players, bool raid, int width, int height) =>
        [.. players.Where(player => Shown(player, raid) && OffScreen(player.ScreenX, player.MiddleY, width, height))
            .OrderBy(player => player.Tiles).ThenBy(player => player.Id, StringComparer.Ordinal).Take(MaxArrows)];

    /// <summary>
    /// Logs the arrows that appeared and went since the last frame, and a reason that hides them all
    /// once it starts and once it ends; the arrows kept while a reason hides them are not logged
    /// again when it ends.
    /// </summary>
    /// <param name="reason">Why no arrow shows, <see langword="null"/> while they may.</param>
    /// <param name="targets">The players pointed at.</param>
    /// <param name="players">Every other player, who tells why an arrow went.</param>
    /// <param name="raid">Whether the world is a Raid World.</param>
    /// <param name="width">The screen's width.</param>
    /// <param name="height">The screen's height.</param>
    public void Note(string? reason, IReadOnlyList<ArrowCandidate> targets, IReadOnlyList<ArrowCandidate> players, bool raid, int width, int height)
    {
        ArgumentNullException.ThrowIfNull(targets);
        ArgumentNullException.ThrowIfNull(players);
        if (reason != hidden)
        {
            log(LogTag + (reason is null ? "arrows shown again" : $"arrows hidden: {reason}"));
            hidden = reason;
        }

        if (reason is not null)
        {
            return;
        }

        var now = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (ArrowCandidate target in targets)
        {
            if (!shown.TryGetValue(target.Id, out string? who))
            {
                who = target.Who;
                log($"{LogTag}an arrow for {who} appeared, {target.Tiles} tiles away, in {target.Color}");
            }

            now[target.Id] = who;
        }

        foreach (KeyValuePair<string, string> gone in shown.Where(pair => !now.ContainsKey(pair.Key)))
        {
            log($"{LogTag}the arrow for {gone.Value} is gone: {GoneReason(gone.Key, players, raid, width, height)}");
        }

        shown = now;
    }

    /// <summary>
    /// Forgets which arrows were logged as shown, when the map's sprites go.
    /// </summary>
    public void Forget() => shown = new Dictionary<string, string>(StringComparer.Ordinal);

    /// <summary>
    /// Reports whether a player gets an arrow wherever they stand: their ghost on the map, a party
    /// member, or anyone in a Raid World.
    /// </summary>
    /// <param name="player">The player.</param>
    /// <param name="raid">Whether the world is a Raid World.</param>
    /// <returns>Whether they do.</returns>
    private static bool Shown(ArrowCandidate player, bool raid) => player.Present && player.OnMap && (player.Member || raid);

    /// <summary>
    /// Reports whether a point lies off the screen.
    /// </summary>
    /// <param name="x">The point's x.</param>
    /// <param name="y">The point's y.</param>
    /// <param name="width">The screen's width.</param>
    /// <param name="height">The screen's height.</param>
    /// <returns>Whether it does.</returns>
    private static bool OffScreen(int x, int y, int width, int height) => x < 0 || y < 0 || x >= width || y >= height;

    /// <summary>
    /// Tells why a player's arrow went.
    /// </summary>
    /// <param name="id">The player's id.</param>
    /// <param name="players">Every other player.</param>
    /// <param name="raid">Whether the world is a Raid World.</param>
    /// <param name="width">The screen's width.</param>
    /// <param name="height">The screen's height.</param>
    /// <returns>The reason.</returns>
    private static string GoneReason(string id, IReadOnlyList<ArrowCandidate> players, bool raid, int width, int height)
    {
        ArrowCandidate? player = players.FirstOrDefault(other => other.Id == id);
        if (player is null)
        {
            return "they left the world";
        }

        if (!player.Present)
        {
            return "their connection is down";
        }

        if (!player.OnMap)
        {
            return "they left the map";
        }

        if (!(player.Member || raid))
        {
            return "they are not in the party";
        }

        return OffScreen(player.ScreenX, player.MiddleY, width, height) ? "others are nearer" : "they are on the screen";
    }
}
