//----------------------------------------------------------------
//  WheelPointer.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;

namespace MGQOnline.Game.Ui.Wheels;

/// <summary>
/// The directions the arrows point a wheel to, clockwise from the top, as MGQ_MpWheel::DIRECTIONS
/// names them in the scripts.
/// </summary>
public enum WheelDirection
{
    /// <summary>Up.</summary>
    Up = 0,

    /// <summary>Up and right.</summary>
    UpRight = 1,

    /// <summary>Right.</summary>
    Right = 2,

    /// <summary>Down and right.</summary>
    DownRight = 3,

    /// <summary>Down.</summary>
    Down = 4,

    /// <summary>Down and left.</summary>
    DownLeft = 5,

    /// <summary>Left.</summary>
    Left = 6,

    /// <summary>Up and left.</summary>
    UpLeft = 7,
}

/// <summary>
/// The arrows held, as the scripts hand them over: a bit for up, down, left and right.
/// </summary>
[Flags]
public enum WheelArrows
{
    /// <summary>No arrow.</summary>
    None = 0,

    /// <summary>Up is held.</summary>
    Up = 1,

    /// <summary>Down is held.</summary>
    Down = 2,

    /// <summary>Left is held.</summary>
    Left = 4,

    /// <summary>Right is held.</summary>
    Right = 8,
}

/// <summary>
/// What the wheels share: the arrows held point like a joystick, one arrow to its side and two to
/// the diagonal between them, and nowhere while none is held, steadied so that letting go of a
/// diagonal's two arrows never lands on one of its sides.
/// </summary>
public sealed class WheelPointer
{
    /// <summary>
    /// Ticks one arrow of a diagonal must stay held alone before it points to its own side, about an
    /// eighth of a second, since two arrows let go together are seldom let go in the same frame.
    /// </summary>
    public const int GraceTicks = 8;

    /// <summary>
    /// The directions by the row and the column the arrows point to, from -1 (up, left) to 1
    /// (down, right).
    /// </summary>
    private static readonly Dictionary<(int Row, int Column), WheelDirection> Steps = new()
    {
        [(-1, 0)] = WheelDirection.Up,
        [(-1, 1)] = WheelDirection.UpRight,
        [(0, 1)] = WheelDirection.Right,
        [(1, 1)] = WheelDirection.DownRight,
        [(1, 0)] = WheelDirection.Down,
        [(1, -1)] = WheelDirection.DownLeft,
        [(0, -1)] = WheelDirection.Left,
        [(-1, -1)] = WheelDirection.UpLeft,
    };

    /// <summary>
    /// The direction the last tick pointed to.
    /// </summary>
    private WheelDirection? _steady;

    /// <summary>
    /// Ticks one side of that diagonal has been held alone.
    /// </summary>
    private int _waited;

    /// <summary>
    /// Finds the direction the arrows held point to.
    /// </summary>
    /// <param name="arrows">The arrows held.</param>
    /// <returns>The direction, null while no arrow is held or only opposite ones are.</returns>
    public static WheelDirection? Held(WheelArrows arrows)
    {
        int row = (arrows.HasFlag(WheelArrows.Down) ? 1 : 0) - (arrows.HasFlag(WheelArrows.Up) ? 1 : 0);
        int column = (arrows.HasFlag(WheelArrows.Right) ? 1 : 0) - (arrows.HasFlag(WheelArrows.Left) ? 1 : 0);
        return Steps.TryGetValue((row, column), out WheelDirection direction) ? direction : null;
    }

    /// <summary>
    /// Finds the direction the arrows held point to as steady as a wheel needs it: one arrow left of
    /// a diagonal still points to the diagonal for <see cref="GraceTicks"/>. Called once a tick by the
    /// wheel that is open.
    /// </summary>
    /// <param name="arrows">The arrows held.</param>
    /// <returns>The direction, null while no arrow is held or only opposite ones are.</returns>
    public WheelDirection? Steady(WheelArrows arrows)
    {
        WheelDirection? held = Held(arrows);
        if (held is { } side && IsSideOf(side, _steady) && ++_waited < GraceTicks)
        {
            return _steady;
        }

        _waited = 0;
        _steady = held;
        return held;
    }

    /// <summary>
    /// Forgets the direction pointed to, as a wheel opens.
    /// </summary>
    public void Reset()
    {
        _steady = null;
        _waited = 0;
    }

    /// <summary>
    /// Tells whether a direction is one of the two sides of a diagonal.
    /// </summary>
    /// <param name="side">The direction.</param>
    /// <param name="diagonal">The diagonal.</param>
    /// <returns>Whether it is.</returns>
    private static bool IsSideOf(WheelDirection side, WheelDirection? diagonal)
    {
        if (diagonal is not { } corner || side == corner)
        {
            return false;
        }

        (int row, int column) = StepOf(side);
        (int cornerRow, int cornerColumn) = StepOf(corner);
        return cornerRow != 0 && cornerColumn != 0 && (row == 0 ? column == cornerColumn : column == 0 && row == cornerRow);
    }

    /// <summary>
    /// Finds the row and the column of a direction.
    /// </summary>
    /// <param name="direction">The direction.</param>
    /// <returns>Its row and column, from -1 to 1.</returns>
    private static (int Row, int Column) StepOf(WheelDirection direction)
    {
        foreach (((int Row, int Column) step, WheelDirection value) in Steps)
        {
            if (value == direction)
            {
                return step;
            }
        }

        throw new ArgumentOutOfRangeException(nameof(direction), direction, "No step points to the direction.");
    }
}

/// <summary>
/// Spreads a wheel's choices evenly over the eight directions, clockwise from the top,
/// mirror-symmetric for every count.
/// </summary>
public static class WheelPlaces
{
    /// <summary>
    /// The directions a wheel has.
    /// </summary>
    public const int Directions = 8;

    /// <summary>
    /// Places a wheel's choices.
    /// </summary>
    /// <param name="count">How many choices the wheel has, at most <see cref="Directions"/>.</param>
    /// <returns>Each choice's direction, in the choices' order.</returns>
    public static WheelDirection[] Of(int count)
    {
        var places = new WheelDirection[Math.Clamp(count, 0, Directions)];
        for (int index = 0; index < places.Length; index++)
        {
            // Ruby's Float#round halves away from zero.
            places[index] = (WheelDirection)((int)Math.Round(index * (double)Directions / places.Length, MidpointRounding.AwayFromZero) % Directions);
        }

        return places;
    }
}
