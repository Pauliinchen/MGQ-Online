//----------------------------------------------------------------
//  TurnSchedule.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using MGQOnline.Arena.Numerics;

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// The game's turn condition A + B·X, on the simulation's turn numbers.
/// </summary>
/// <remarks>The game's own <c>Game_Enemy#conditions_met_turns?</c> reads <c>$game_troop.turn_count + 1</c>
/// because <c>BattleManager.input_start</c> makes the enemies' actions before <c>turn_start</c> raises the
/// count, so the game's n is the turn about to start, 1 for the first, which is the simulation's turn.</remarks>
public static class TurnSchedule
{
    /// <summary>
    /// Tells whether a turn condition holds on a turn.
    /// </summary>
    /// <param name="a">The first turn, as the game stores it.</param>
    /// <param name="b">The turns between two more, 0 for turn A alone, as the game stores it.</param>
    /// <param name="turn">The turn, 1 the first.</param>
    /// <returns>Whether it holds.</returns>
    public static bool Holds(int a, int b, int turn) =>
        b == 0
            ? turn == a
            : turn > 0 && turn >= a && RubyMath.FloorMod(turn, b) == RubyMath.FloorMod(a, b);
}
