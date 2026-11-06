//----------------------------------------------------------------
//  ActorBuild.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Dropped the hero of a replaced Luka
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.Actors;

/// <summary>
/// A character's build, which another game rebuilds as a character of its own data: its make-up,
/// the stats and rates its owner's game showed, and what of the owner's save it reads.
/// </summary>
/// <remarks>
/// Nothing of the save format leaves the game, since loading someone else's save data can run code.
/// </remarks>
/// <param name="ActorId">The actor's id.</param>
/// <param name="BaseLevel">The personal level.</param>
/// <param name="ClassId">The job, <see langword="null"/> for none.</param>
/// <param name="TribeId">The race, <see langword="null"/> for none.</param>
/// <param name="Levels">Every job and race level by its job's or race's id.</param>
/// <param name="ParamPlus">The stat growths from items.</param>
/// <param name="Skills">The skills learned.</param>
/// <param name="Abilities">The abilities learned, by skill type.</param>
/// <param name="EquipAbilities">The abilities set, by skill type.</param>
/// <param name="Equips">The equipment per slot, <see langword="null"/> for an empty slot.</param>
/// <param name="Params">The stats, max HP to luck, as the owner's game showed them.</param>
/// <param name="Rates">The rates the scripts compare in per mille, as the owner's game showed them.</param>
/// <param name="Counters">The counters of the owner's save the character reads, see <see cref="BuildText.CounterCount"/>.</param>
/// <param name="SwitchesOn">The switches on in the owner's save that the battle start states wait for.</param>
public sealed record ActorBuild(
    long ActorId,
    long BaseLevel,
    long? ClassId,
    long? TribeId,
    IReadOnlyList<(long Id, long Level)> Levels,
    IReadOnlyList<long> ParamPlus,
    IReadOnlyList<long> Skills,
    IReadOnlyList<(long SkillType, IReadOnlyList<long> Ids)> Abilities,
    IReadOnlyList<(long SkillType, IReadOnlyList<long> Ids)> EquipAbilities,
    IReadOnlyList<BuildItem?> Equips,
    IReadOnlyList<long> Params,
    IReadOnlyList<long> Rates,
    IReadOnlyList<long> Counters,
    IReadOnlyList<long> SwitchesOn);
