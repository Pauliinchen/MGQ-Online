//----------------------------------------------------------------
//  RaidDifficulty.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;

namespace MGQOnline.Game.Raid;

/// <summary>
/// The rules of a Raid World's difficulty, which world_difficulty.rbx applies: the world's
/// difficulty holds for every player, except while a fight has values of its own set, which the
/// world's difficulty never writes over.
/// </summary>
public static class RaidDifficulty
{
    /// <summary>
    /// The switch the game turns on while a special boss fights on NORMAL on EASY and below.
    /// </summary>
    public const int SpecialBoss = 23;

    /// <summary>
    /// The switch of the Labyrinth of Chaos, whose rates come from its level.
    /// </summary>
    public const int Labyrinth = 41;

    /// <summary>
    /// The switch of the final battles' fixed NORMAL.
    /// </summary>
    public const int FinalBattles = 507;

    /// <summary>
    /// The switch the Colosseum turns on while it plays its fights on NORMAL.
    /// </summary>
    public const int Colosseum = 28;

    /// <summary>
    /// The switch of a Colosseum match under way, which ends with a win and with a defeat.
    /// </summary>
    public const int ColosseumMatch = 87;

    /// <summary>
    /// Gets the switches the rules read, in the order a request carries them.
    /// </summary>
    public static IReadOnlyList<int> Switches { get; } = [SpecialBoss, Labyrinth, FinalBattles, Colosseum, ColosseumMatch];

    /// <summary>
    /// Tells whether the game has values of its own set for a fight: in the Labyrinth of Chaos, a
    /// Colosseum match, a special boss's or the final battles' fixed NORMAL.
    /// </summary>
    /// <remarks>
    /// The Colosseum counts only during a match: a defeat there puts the difficulty back but leaves
    /// its switch on, which the game turns off only at its next win or leave.
    /// </remarks>
    /// <param name="on">The switches of <see cref="Switches"/> that are on.</param>
    /// <returns>Whether it has.</returns>
    public static bool OwnValues(IReadOnlySet<int> on)
    {
        ArgumentNullException.ThrowIfNull(on);
        return on.Contains(SpecialBoss) || on.Contains(Labyrinth) || on.Contains(FinalBattles) || (on.Contains(Colosseum) && on.Contains(ColosseumMatch));
    }

    /// <summary>
    /// Tells whether the game plays on another difficulty than the world's and may be put on it
    /// now: no fight with values of its own, no battle, and no event or message running on the map,
    /// since an event may be one that sets those values.
    /// </summary>
    /// <param name="world">The world's difficulty.</param>
    /// <param name="game">The game's difficulty.</param>
    /// <param name="ownValues">Whether a fight has values of its own set, see <see cref="OwnValues"/>.</param>
    /// <param name="inBattle">Whether a battle runs.</param>
    /// <param name="quiet">Whether no event or message runs on the map.</param>
    /// <returns>Whether it may.</returns>
    public static bool Due(long world, long game, bool ownValues, bool inBattle, bool quiet) => game != world && !ownValues && !inBattle && quiet;
}
