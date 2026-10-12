//----------------------------------------------------------------
//  MouseWheel.cs
//
//  Changelog:
//      Paulinchen  2026-10-12: Created
//
//----------------------------------------------------------------

namespace MGQParadox.Multiplayer.Windows;

/// <summary>
/// The mouse wheel turned over the game's window, gathered until the game script takes it, since
/// RGSS itself knows no wheel.
/// </summary>
internal sealed class MouseWheel
{
    /// <summary>
    /// The wheel's turn of one notch, WHEEL_DELTA.
    /// </summary>
    public const int Notch = 120;

    /// <summary>
    /// Guards <see cref="turned"/>.
    /// </summary>
    private readonly object gate = new();

    /// <summary>
    /// The wheel's turn not yet handed out, positive away from the player.
    /// </summary>
    private int turned;

    /// <summary>
    /// Adds a turn of the wheel.
    /// </summary>
    /// <param name="delta">The turn, positive away from the player, as WM_MOUSEWHEEL tells it.</param>
    public void Turn(int delta)
    {
        lock (gate)
        {
            turned += delta;
        }
    }

    /// <summary>
    /// Hands out the whole notches turned since the last take and keeps the rest of a notch.
    /// </summary>
    /// <remarks>
    /// A wheel without notches turns in parts of one, which add up over several messages.
    /// </remarks>
    /// <returns>The notches, positive away from the player.</returns>
    public int Take()
    {
        lock (gate)
        {
            var notches = turned / Notch;
            turned -= notches * Notch;
            return notches;
        }
    }
}
