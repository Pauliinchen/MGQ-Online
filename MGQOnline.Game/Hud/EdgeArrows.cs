//----------------------------------------------------------------
//  EdgeArrows.cs
//
//  Changelog:
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
/// An arrow's picture, its triangle's center at the picture's origin.
/// </summary>
/// <param name="Left">The picture's left, from the triangle's center.</param>
/// <param name="Top">The picture's top, from the triangle's center.</param>
/// <param name="Width">The picture's width.</param>
/// <param name="Height">The picture's height.</param>
/// <param name="PlateX">The plate's left in the picture.</param>
/// <param name="PlateY">The plate's top in the picture.</param>
/// <param name="SlideX">Pixels the arrow slides in from as it fades in, x.</param>
/// <param name="SlideY">Pixels the arrow slides in from as it fades in, y.</param>
/// <param name="Rows">The triangle's rows in the picture, each its x, y, width and whether it is
/// the fill (1) or one of the outline's passes (0), in the order they are drawn.</param>
public sealed record ArrowPicture(int Left, int Top, int Width, int Height, int PlateX, int PlateY, int SlideX, int SlideY, IReadOnlyList<(int X, int Y, int Width, int Fill)> Rows);

/// <summary>
/// The arrows at the screen's edge toward the players on the map whose ghost is off the screen:
/// party members always, everyone in a Raid World, the nearest <see cref="MaxArrows"/>; where each
/// sits and points, its picture, and the log of arrows coming and going.
/// </summary>
public sealed class EdgeArrows
{
    /// <summary>
    /// Most arrows at once: the nearest players.
    /// </summary>
    public const int MaxArrows = 8;

    /// <summary>
    /// Pixels between the screen's edge and an arrow's center, room for the triangle's reach.
    /// </summary>
    public const int Margin = 14;

    /// <summary>
    /// Pixels from a triangle's base to its tip.
    /// </summary>
    public const int Length = 14;

    /// <summary>
    /// Pixels across a triangle's base.
    /// </summary>
    public const int Width = 12;

    /// <summary>
    /// Degrees an arrow turns by at least before it is drawn anew.
    /// </summary>
    public const int AngleStep = 10;

    /// <summary>
    /// Height of the plate with the name and the tiles.
    /// </summary>
    public const int LabelHeight = 20;

    /// <summary>
    /// Pixels between the triangle and its plate.
    /// </summary>
    public const int LabelGap = 4;

    /// <summary>
    /// Pixels an arrow slides in from, toward the edge, as it fades in.
    /// </summary>
    public const int SlidePixels = 10;

    /// <summary>
    /// Pixels from a ghost's screen y, the bottom of its tile, up to the tile's middle.
    /// </summary>
    public const int HalfTile = 16;

    /// <summary>
    /// Pixels the outline reaches around the triangle.
    /// </summary>
    public const int OutlineReach = 1;

    /// <summary>
    /// What starts the arrows' lines in the log.
    /// </summary>
    private const string LogTag = "edge arrows: ";

    /// <summary>
    /// Degrees in a half turn.
    /// </summary>
    private const double HalfTurn = 180;

    /// <summary>
    /// Pixels the triangle reaches from its center at most, to a corner of its base.
    /// </summary>
    public static readonly int Reach = (int)Math.Ceiling(Math.Sqrt(Math.Pow(Length / 2.0, 2) + Math.Pow(Width / 2.0, 2)));

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
    /// Tells the rect the arrows' centers stay in: the screen less <see cref="Margin"/> on each side,
    /// and less the strip of the mod at the top.
    /// </summary>
    /// <param name="width">The screen's width.</param>
    /// <param name="height">The screen's height.</param>
    /// <param name="topRoom">The pixels the mod's strip takes at the top.</param>
    /// <returns>Left, top, right and bottom.</returns>
    public static (int Left, int Top, int Right, int Bottom) EdgeRect(int width, int height, int topRoom) =>
        (Margin, Margin + topRoom, width - Margin, height - Margin);

    /// <summary>
    /// Finds where an arrow sits and which way it points: where the line from one point of the
    /// screen to another crosses the edge's rect, kept inside it, and the line's angle.
    /// </summary>
    /// <param name="fromX">Where the line starts, x: the player's sprite.</param>
    /// <param name="fromY">Where the line starts, y.</param>
    /// <param name="toX">Where it points, x: the other player's ghost.</param>
    /// <param name="toY">Where it points, y.</param>
    /// <param name="edge">The rect, see <see cref="EdgeRect"/>.</param>
    /// <returns>The arrow's x and y, and the angle in degrees, 0 to the right and 90 down;
    /// <see langword="null"/> for two equal points.</returns>
    public static (int X, int Y, int Angle)? Point(int fromX, int fromY, int toX, int toY, (int Left, int Top, int Right, int Bottom) edge)
    {
        double dx = toX - fromX;
        double dy = toY - fromY;
        if (dx == 0 && dy == 0)
        {
            return null;
        }

        double reach = Math.Min(Math.Min(AxisReach(fromX, dx, edge.Left, edge.Right), AxisReach(fromY, dy, edge.Top, edge.Bottom)), 1.0);
        reach = reach < 0 ? 0.0 : reach;
        int x = Math.Clamp(Round(fromX + (dx * reach)), edge.Left, edge.Right);
        int y = Math.Clamp(Round(fromY + (dy * reach)), edge.Top, edge.Bottom);
        return (x, y, Round(Math.Atan2(dy, dx) * HalfTurn / Math.PI));
    }

    /// <summary>
    /// Rounds an angle to the nearest <see cref="AngleStep"/>, so the arrow is drawn anew only once
    /// it turned.
    /// </summary>
    /// <param name="angle">The angle in degrees.</param>
    /// <returns>The angle rounded.</returns>
    public static int StepAngle(int angle) => Round(angle / (double)AngleStep) * AngleStep;

    /// <summary>
    /// Lays out an arrow's picture: the triangle pointing along the angle around the picture's
    /// origin, its outline, and the plate on the side away from the edge, clear of the triangle by
    /// <see cref="LabelGap"/>.
    /// </summary>
    /// <param name="angle">The stepped angle in degrees.</param>
    /// <param name="plateWidth">The plate's width, its text measured with the padding.</param>
    /// <returns>The picture.</returns>
    public static ArrowPicture Picture(int angle, int plateWidth)
    {
        double radians = angle * Math.PI / HalfTurn;
        double ux = Math.Cos(radians);
        double uy = Math.Sin(radians);
        double halfWidth = plateWidth / 2.0;
        double halfHeight = LabelHeight / 2.0;
        double distance = PlateDistance(ux, uy, halfWidth, halfHeight);
        double plateLeft = (-ux * distance) - halfWidth;
        double plateTop = (-uy * distance) - halfHeight;
        int left = (int)Math.Floor(Math.Min(-Reach, plateLeft));
        int top = (int)Math.Floor(Math.Min(-Reach, plateTop));
        int right = (int)Math.Ceiling(Math.Max(Reach, plateLeft + plateWidth));
        int bottom = (int)Math.Ceiling(Math.Max(Reach, plateTop + LabelHeight));
        return new ArrowPicture(left, top, right - left, bottom - top, Round(plateLeft - left), Round(plateTop - top),
            Round(ux * SlidePixels), Round(uy * SlidePixels), TriangleRows(-left, -top, ux, uy));
    }

    /// <summary>
    /// Tells how far from the triangle's center, along the line and away from the edge, the plate's
    /// center lies so that the plate's nearest point clears the triangle by <see cref="LabelGap"/>:
    /// the plate's edge faces the triangle when the line meets the plate across its width or its
    /// height, else a corner does, which lies on the circle of the gap.
    /// </summary>
    /// <param name="ux">The angle's cosine.</param>
    /// <param name="uy">The angle's sine.</param>
    /// <param name="halfWidth">Half the plate's width.</param>
    /// <param name="halfHeight">Half the plate's height.</param>
    /// <returns>The distance in pixels.</returns>
    public static double PlateDistance(double ux, double uy, double halfWidth, double halfHeight)
    {
        double clear = Reach + LabelGap;
        double ax = Math.Abs(ux);
        double ay = Math.Abs(uy);
        if (ay > 0 && ax * ((clear + halfHeight) / ay) <= halfWidth)
        {
            return (clear + halfHeight) / ay;
        }

        if (ax > 0 && ay * ((clear + halfWidth) / ax) <= halfHeight)
        {
            return (clear + halfWidth) / ax;
        }

        double support = (ax * halfWidth) + (ay * halfHeight);
        return support + Math.Sqrt(Math.Max((support * support) - (halfWidth * halfWidth) - (halfHeight * halfHeight) + (clear * clear), 0));
    }

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
    /// Rounds as Ruby's <c>Float#round</c> does, halves away from zero.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The whole number.</returns>
    private static int Round(double value) => (int)Math.Round(value, MidpointRounding.AwayFromZero);

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
    /// Tells how far along a line, 1.0 for its whole length, it reaches one axis's bound.
    /// </summary>
    /// <param name="from">Where the line starts on the axis.</param>
    /// <param name="delta">How far it goes on the axis.</param>
    /// <param name="low">The lower bound.</param>
    /// <param name="high">The upper bound.</param>
    /// <returns>The share of the line, 1.0 for a line still on the axis.</returns>
    private static double AxisReach(int from, double delta, int low, int high)
    {
        if (delta == 0)
        {
            return 1.0;
        }

        return delta > 0 ? (high - from) / delta : (low - from) / delta;
    }

    /// <summary>
    /// Lists the rows of the triangle around a center: the outline's four passes, each shifted by
    /// <see cref="OutlineReach"/>, then the fill.
    /// </summary>
    /// <param name="cx">The center's x in the picture.</param>
    /// <param name="cy">The center's y in the picture.</param>
    /// <param name="ux">The angle's cosine.</param>
    /// <param name="uy">The angle's sine.</param>
    /// <returns>The rows.</returns>
    private static List<(int X, int Y, int Width, int Fill)> TriangleRows(int cx, int cy, double ux, double uy)
    {
        double halfLength = Length / 2.0;
        double halfWidth = Width / 2.0;
        (double X, double Y)[] corners =
        [
            (cx + (ux * halfLength), cy + (uy * halfLength)),
            (cx - (ux * halfLength) - (uy * halfWidth), cy - (uy * halfLength) + (ux * halfWidth)),
            (cx - (ux * halfLength) + (uy * halfWidth), cy - (uy * halfLength) - (ux * halfWidth)),
        ];
        var rows = new List<(int, int, int, int)>();
        foreach ((int dx, int dy) in new[] { (-OutlineReach, 0), (OutlineReach, 0), (0, -OutlineReach), (0, OutlineReach) })
        {
            FillRows(rows, [.. corners.Select(corner => (corner.X + dx, corner.Y + dy))], 0);
        }

        FillRows(rows, corners, 1);
        return rows;
    }

    /// <summary>
    /// Fills a triangle row by row, as a picture that draws only rects must.
    /// </summary>
    /// <param name="rows">The rows, added to.</param>
    /// <param name="points">The three corners.</param>
    /// <param name="fill">1 for the fill, 0 for the outline.</param>
    private static void FillRows(List<(int, int, int, int)> rows, (double X, double Y)[] points, int fill)
    {
        double lowest = points.Min(point => point.Y);
        double highest = points.Max(point => point.Y);
        for (int y = (int)Math.Floor(lowest); y <= (int)Math.Ceiling(highest); y++)
        {
            var crossings = new List<double>();
            for (int index = 0; index < points.Length; index++)
            {
                (double X, double Y) a = points[index];
                (double X, double Y) b = points[(index + 1) % points.Length];
                if (a.Y == b.Y || y < Math.Min(a.Y, b.Y) || y > Math.Max(a.Y, b.Y))
                {
                    continue;
                }

                crossings.Add(a.X + ((b.X - a.X) * (y - a.Y) / (b.Y - a.Y)));
            }

            if (crossings.Count == 0)
            {
                continue;
            }

            int left = (int)Math.Floor(crossings.Min());
            rows.Add((left, y, (int)Math.Ceiling(crossings.Max()) - left + 1, fill));
        }
    }

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
