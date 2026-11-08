//----------------------------------------------------------------
//  AllyBuild.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.Battles.Setup;

/// <summary>
/// The make-up of another player's character that the factory gives it after the game's own setup,
/// see <see cref="BattlerSetup.AllySteps"/>: only what this game's data knows of the build.
/// </summary>
/// <param name="ClassId">The job, <see langword="null"/> for one this game lacks.</param>
/// <param name="TribeId">The race, <see langword="null"/> for one this game lacks.</param>
/// <param name="Levels">Every job and race level by its job's or race's id.</param>
/// <param name="BaseLevel">The personal level.</param>
/// <param name="Skills">The skills learned.</param>
/// <param name="Abilities">The abilities learned.</param>
/// <param name="EquipAbilities">The abilities set, in their order.</param>
/// <param name="ParamPlus">The stat growths from items, max HP to luck.</param>
/// <param name="Slots">The equipment slots.</param>
public sealed record AllyBuild(
    long? ClassId,
    long? TribeId,
    IReadOnlyList<(long Id, long Level)> Levels,
    long BaseLevel,
    IReadOnlyList<long> Skills,
    IReadOnlyList<long> Abilities,
    IReadOnlyList<long> EquipAbilities,
    IReadOnlyList<long> ParamPlus,
    int Slots);
