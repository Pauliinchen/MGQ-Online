//----------------------------------------------------------------
//  BattlerSetup.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Gave the steps that build another player's character after the game's own setup
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Battles.Setup;

/// <summary>
/// Decides how battles_battlers.rbx builds a battler the game's troop setup or party never made:
/// another player's character in a co-op battle, an enemy of another game's troop, or the other
/// side's characters in a PvP battle. Each is made as the game makes its own, a character through
/// the game's setup and changers in the steps core_actors.rbx applies, then given the game's own
/// battle start where the game's start never reaches it.
/// </summary>
public static class BattlerSetup
{
    /// <summary>
    /// The mark of an enemy the host shows.
    /// </summary>
    public const long Shown = 0;

    /// <summary>
    /// The mark of an enemy the host hides.
    /// </summary>
    public const long Hidden = 1;

    /// <summary>
    /// The mark of an enemy that fell on the host, or that the host's game hid as it was eaten.
    /// </summary>
    public const long Fallen = 2;

    /// <summary>
    /// Plans a battler.
    /// </summary>
    /// <remarks>
    /// The game's battle start reaches only its own party and the troop's members, so another
    /// player's character and the Backline are always started here, a character after its HP, since
    /// a trait's states for low HP come only at the start.
    /// </remarks>
    /// <param name="order">The battler and the battle as the factory finds them.</param>
    /// <returns>What the factory gives it.</returns>
    public static BattlerPlan Plan(BattlerOrder order) => order.Kind switch
    {
        BattlerKind.Ally => new BattlerPlan(order.Hp is >= 0 ? order.Hp : null, order.Mp, Start: true, Hide: false, LayDown: false),
        BattlerKind.Reserve => new BattlerPlan(null, null, Start: true, Hide: false, LayDown: false),
        _ => new BattlerPlan(null, null, Start: order.Started, Hide: order.Mark == Hidden, LayDown: order.Mark == Fallen),
    };

    /// <summary>
    /// Lists the steps that turn a character the game's own setup made of its actor into another
    /// player's build: the past jobs and races with their levels, the current job and race, the jobs
    /// and races known, the personal level, the skills, the stat growths, the abilities set and every slot's equipment.
    /// </summary>
    /// <remarks>
    /// The game's <c>change_class</c> keeps each job's and race's level in the character's list, so
    /// the current job and race come after the past ones and the character ends on them.
    /// </remarks>
    /// <param name="build">What this game's data knows of the build.</param>
    /// <returns>The steps, in the order they apply.</returns>
    public static IReadOnlyList<AllyStep> AllySteps(AllyBuild build)
    {
        var current = new[] { (Changer: AllyChanger.Job, Id: build.ClassId), (Changer: AllyChanger.Race, Id: build.TribeId) }
            .Where(entry => entry.Id is not null).Select(entry => (entry.Changer, Id: entry.Id!.Value)).ToList();
        var steps = build.Levels.Where(level => current.TrueForAll(entry => entry.Id != level.Id))
            .Select(level => new AllyStep(AllyChanger.Class, [level.Id, level.Level])).ToList();
        steps.AddRange(current.Select(entry => new AllyStep(entry.Changer, [entry.Id, build.Levels.FirstOrDefault(level => level.Id == entry.Id, (entry.Id, 1)).Level])));
        steps.Add(new AllyStep(AllyChanger.Classes, [.. build.Levels.Select(level => level.Id).Union(current.Select(entry => entry.Id))]));
        steps.Add(new AllyStep(AllyChanger.Level, [build.BaseLevel]));
        steps.Add(new AllyStep(AllyChanger.Skills, [.. build.Skills.Union(build.Abilities)]));
        steps.AddRange(build.ParamPlus.Select((growth, id) => (growth, id)).Where(stat => stat.growth != 0)
            .Select(stat => new AllyStep(AllyChanger.Param, [stat.id, stat.growth])));
        steps.Add(new AllyStep(AllyChanger.Abilities, build.EquipAbilities));
        steps.AddRange(Enumerable.Range(0, build.Slots).Select(slot => new AllyStep(AllyChanger.Equip, [slot])));
        return steps;
    }
}
