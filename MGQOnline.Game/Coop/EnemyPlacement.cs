//----------------------------------------------------------------
//  EnemyPlacement.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Coop;

/// <summary>
/// An enemy of a running battle's troop as the placement reads it.
/// </summary>
/// <param name="X">Its screen x, the middle of its picture.</param>
/// <param name="Width">Its picture's width.</param>
/// <param name="Hidden">Whether it is hidden.</param>
/// <param name="Fallen">Whether it fell, also one hidden after its defeat.</param>
public readonly record struct TroopSpot(int X, int Width, bool Hidden, bool Fallen);

/// <summary>
/// An enemy of an encounter taken in earlier that has not joined the troop yet, which keeps its
/// place.
/// </summary>
/// <param name="X">Its screen x.</param>
/// <param name="Width">Its picture's width.</param>
public readonly record struct QueuedSpot(int X, int Width);

/// <summary>
/// An enemy of an encounter to place in a running battle's troop.
/// </summary>
/// <param name="Id">Its enemy id.</param>
/// <param name="Y">Its screen y, which it keeps.</param>
/// <param name="Width">Its picture's width.</param>
public readonly record struct NewEnemy(int Id, int Y, int Width);

/// <summary>
/// An enemy placed in a running battle's troop.
/// </summary>
/// <param name="Id">Its enemy id.</param>
/// <param name="X">Its screen x.</param>
/// <param name="Y">Its screen y.</param>
public readonly record struct PlacedEnemy(int Id, int X, int Y);

/// <summary>
/// Finds places in a running battle's troop for the enemies of an encounter it takes in, as
/// battles_coop_hotjoin.rbx found them: within <see cref="TroopLimit"/> with every enemy of the
/// troop and those queued, and on the screen where at most <see cref="MaxOverlap"/> of each picture
/// hides behind another, the nearest to the middle among equals.
/// </summary>
/// <remarks>
/// Pictures as wide as the screen stand in its middle and count for no overlap, as the game's own
/// troops stack them there.
/// </remarks>
public static class EnemyPlacement
{
    /// <summary>
    /// The enemies a troop holds at most, standing, hidden or fallen: the game's own troops hold no
    /// more, and its window to pick an enemy shows as many without scrolling.
    /// </summary>
    public const int TroopLimit = 8;

    /// <summary>
    /// The share of the narrower of two enemies' pictures that may hide behind the other.
    /// </summary>
    public const double MaxOverlap = 0.5;

    /// <summary>
    /// The pixels between two places an added enemy may stand at.
    /// </summary>
    public const int PlaceStep = 8;

    /// <summary>
    /// Places the first of an encounter's enemies that still find a place, all of them when they
    /// fit: one fewer each time the troop has no room for the rest.
    /// </summary>
    /// <param name="troop">The troop's enemies.</param>
    /// <param name="queued">The enemies queued before.</param>
    /// <param name="entries">The encounter's enemies, in order.</param>
    /// <param name="screen">The battle screen's width.</param>
    /// <returns>The enemies placed, the first ones of <paramref name="entries"/>; none when none fits.</returns>
    public static List<PlacedEnemy> PlaceFirst(IReadOnlyList<TroopSpot> troop, IReadOnlyList<QueuedSpot> queued, IReadOnlyList<NewEnemy> entries, int screen)
    {
        ArgumentNullException.ThrowIfNull(entries);
        for (int count = entries.Count; count > 0; count--)
        {
            List<PlacedEnemy>? placed = Place(troop, queued, entries.Take(count).ToList(), screen);
            if (placed is not null)
            {
                return placed;
            }
        }

        return [];
    }

    /// <summary>
    /// Places every enemy of an encounter.
    /// </summary>
    /// <param name="troop">The troop's enemies.</param>
    /// <param name="queued">The enemies queued before.</param>
    /// <param name="entries">The encounter's enemies.</param>
    /// <param name="screen">The battle screen's width.</param>
    /// <returns>The enemies placed, <see langword="null"/> when one finds no place.</returns>
    public static List<PlacedEnemy>? Place(IReadOnlyList<TroopSpot> troop, IReadOnlyList<QueuedSpot> queued, IReadOnlyList<NewEnemy> entries, int screen)
    {
        ArgumentNullException.ThrowIfNull(troop);
        ArgumentNullException.ThrowIfNull(queued);
        ArgumentNullException.ThrowIfNull(entries);
        if (troop.Count + queued.Count + entries.Count > TroopLimit)
        {
            return null;
        }

        List<(int Left, int Right)> taken = troop.Where(enemy => !enemy.Fallen && !enemy.Hidden).Select(enemy => Span(enemy.X, enemy.Width))
            .Concat(queued.Select(enemy => Span(enemy.X, enemy.Width)))
            .Where(span => span.Right - span.Left < screen)
            .ToList();
        var placed = new List<PlacedEnemy>(entries.Count);
        foreach (NewEnemy entry in entries)
        {
            if (entry.Width >= screen)
            {
                placed.Add(new PlacedEnemy(entry.Id, RubyHalf(screen), entry.Y));
                continue;
            }

            int? x = FreeX(entry.Width, taken, screen);
            if (x is not { } free)
            {
                return null;
            }

            taken.Add(Span(free, entry.Width));
            placed.Add(new PlacedEnemy(entry.Id, free, entry.Y));
        }

        return placed;
    }

    /// <summary>
    /// Finds the place on the screen where a picture hides least behind the others, the nearest to
    /// the middle among equals.
    /// </summary>
    /// <param name="width">The picture's width.</param>
    /// <param name="taken">The others' left and right edges.</param>
    /// <param name="screen">The battle screen's width.</param>
    /// <returns>The picture's middle, <see langword="null"/> when every place hides more than <see cref="MaxOverlap"/>.</returns>
    public static int? FreeX(int width, IReadOnlyList<(int Left, int Right)> taken, int screen)
    {
        int half = RubyHalf(width);
        int? best = null;
        double bestCrowding = 0;
        int bestDistance = 0;
        for (int x = half; x <= screen - half; x += PlaceStep)
        {
            double crowding = Crowding(x - half, x + half, taken);
            int distance = Math.Abs(x - RubyHalf(screen));
            if (best is null || crowding < bestCrowding || (crowding == bestCrowding && distance < bestDistance))
            {
                best = x;
                bestCrowding = crowding;
                bestDistance = distance;
            }
        }

        return best is not null && bestCrowding <= MaxOverlap ? best : null;
    }

    /// <summary>
    /// Measures how much a picture hides behind others, or they behind it.
    /// </summary>
    /// <param name="left">The picture's left edge.</param>
    /// <param name="right">Its right edge.</param>
    /// <param name="taken">The others' left and right edges.</param>
    /// <returns>The largest share of the narrower of two pictures that the other covers.</returns>
    public static double Crowding(int left, int right, IReadOnlyList<(int Left, int Right)> taken)
    {
        ArgumentNullException.ThrowIfNull(taken);
        double most = 0.0;
        foreach ((int otherLeft, int otherRight) in taken)
        {
            int overlap = Math.Min(right, otherRight) - Math.Max(left, otherLeft);
            int narrower = Math.Min(right - left, otherRight - otherLeft);
            double share = overlap > 0 ? (double)overlap / Math.Max(narrower, 1) : 0.0;
            most = Math.Max(most, share);
        }

        return most;
    }

    /// <summary>
    /// Tells the left and right edges of a picture.
    /// </summary>
    /// <remarks>
    /// An odd width loses a pixel, as the scripts halved it.
    /// </remarks>
    /// <param name="x">Its middle.</param>
    /// <param name="width">Its width.</param>
    /// <returns>The edges.</returns>
    public static (int Left, int Right) Span(int x, int width) => (x - RubyHalf(width), x + RubyHalf(width));

    /// <summary>
    /// Halves a width as Ruby's integer division does, toward minus infinity.
    /// </summary>
    /// <param name="width">The width.</param>
    /// <returns>Half of it.</returns>
    private static int RubyHalf(int width) => width >= 0 ? width / 2 : (width - 1) / 2;
}
