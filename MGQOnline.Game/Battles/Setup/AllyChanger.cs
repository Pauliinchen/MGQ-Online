//----------------------------------------------------------------
//  AllyChanger.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Battles.Setup;

/// <summary>
/// The game's own changer a step of <see cref="BattlerSetup.AllySteps"/> applies.
/// </summary>
public enum AllyChanger
{
    /// <summary>
    /// A past job or race and its level: <c>change_class</c>, as a job or a race as the game's own
    /// event command tells them apart, then <c>change_level</c>.
    /// </summary>
    Class,

    /// <summary>
    /// The current job and its level: <c>change_class</c> as a job, then <c>change_level</c>.
    /// </summary>
    Job,

    /// <summary>
    /// The current race and its level: <c>change_class</c> as a race, then <c>change_level</c>.
    /// </summary>
    Race,

    /// <summary>
    /// Exactly these jobs and races known: <c>erase_class</c> of any other.
    /// </summary>
    Classes,

    /// <summary>
    /// The personal level: <c>change_level</c>.
    /// </summary>
    Level,

    /// <summary>
    /// Exactly these skills and abilities learned: <c>forget_skill</c> of any other, then
    /// <c>learn_skill</c> of each.
    /// </summary>
    Skills,

    /// <summary>
    /// A stat growth: <c>add_param</c>.
    /// </summary>
    Param,

    /// <summary>
    /// Exactly these abilities set, in their order: <c>remove_ability_all</c>, then each set as the
    /// owner's game set it.
    /// </summary>
    /// <remarks>
    /// The game's <c>add_ability</c> takes off what a later ability may not be set with, which the
    /// owner's game may have let be set after that one.
    /// </remarks>
    Abilities,

    /// <summary>
    /// A slot's equipment from the build: <c>force_change_equip</c>.
    /// </summary>
    Equip,
}
