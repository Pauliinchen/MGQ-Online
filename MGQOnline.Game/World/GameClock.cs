//----------------------------------------------------------------
//  GameClock.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.World;

/// <summary>
/// The one clock of every timer: the bridge's frame, which the scripts count once per
/// <c>Graphics.update</c> and hand over with every drain (<c>BridgeContext.Frame</c>).
/// </summary>
/// <remarks>
/// The game's own frame count goes back to the save's as a save loads; the bridge's never does.
/// </remarks>
public static class GameClock
{
    /// <summary>
    /// The frames the game runs a second.
    /// </summary>
    public const int FramesPerSecond = 60;

    /// <summary>
    /// Tells a frame of the clock in milliseconds, for the rules that count their waits in them.
    /// </summary>
    /// <param name="frame">The frame.</param>
    /// <returns>The milliseconds.</returns>
    public static long Milliseconds(long frame) => frame * 1000 / FramesPerSecond;
}
