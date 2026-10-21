//----------------------------------------------------------------
//  TraitBlock.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Arena.Model;

/// <summary>
/// The parts of a trait list the game reads: features, note tags, state recipes and delayed counters.
/// </summary>
/// <remarks>The C# engine reads the lowered rules instead; this block feeds the Ruby reader.</remarks>
/// <param name="Entries">One entry per trait, a tier's first, then a boss's.</param>
/// <param name="Features">The features added to every enemy.</param>
/// <param name="NoteTags">The note tag lines appended to every enemy's note, with placeholders.</param>
/// <param name="StateRecipes">The states made before the note is read.</param>
/// <param name="DelayedCounters">The delayed counters.</param>
/// <param name="NeedsModCode">What no tag of the game does, as sentences for the reader's authors.</param>
public sealed record TraitBlock(
    IReadOnlyList<TraitEntrySpec> Entries,
    IReadOnlyList<FeatureSpec> Features,
    IReadOnlyList<string> NoteTags,
    IReadOnlyList<StateRecipe> StateRecipes,
    IReadOnlyList<DelayedCounterSpec> DelayedCounters,
    IReadOnlyList<string> NeedsModCode)
{
    /// <summary>
    /// Gets a block of no traits.
    /// </summary>
    public static TraitBlock Empty { get; } = new([], [], [], [], [], []);
}

/// <summary>
/// One trait of a trait block.
/// </summary>
/// <param name="Id">The trait's item id.</param>
/// <param name="Kind">The trait kind's key.</param>
/// <param name="Source">Whether the tier or the boss holds it.</param>
/// <param name="Index">Its place in its list.</param>
/// <param name="Values">Its values in the game's positional order.</param>
/// <param name="CustomSkills">The custom skills by value place.</param>
/// <param name="CodeOnly">Whether only the reader's own code can do it.</param>
/// <param name="Feature">The feature it becomes, or null.</param>
/// <param name="Tag">The note tag it becomes, with placeholders, or null.</param>
/// <param name="LastStand">Its Last stand, or null.</param>
public sealed record TraitEntrySpec(
    string Id,
    string Kind,
    TraitSource Source,
    int Index,
    IReadOnlyList<double> Values,
    IReadOnlyDictionary<int, SkillRef> CustomSkills,
    bool CodeOnly,
    FeatureSpec? Feature = null,
    string? Tag = null,
    LastStandSpec? LastStand = null);

/// <summary>
/// A feature of the game's database.
/// </summary>
/// <param name="Code">The feature code.</param>
/// <param name="DataId">The data id.</param>
/// <param name="Value">The value.</param>
public sealed record FeatureSpec(int Code, int DataId, double Value);

/// <summary>
/// A Last stand of a trait.
/// </summary>
/// <param name="Hp">The HP percent it starts below.</param>
/// <param name="Turns">The turns its phase lasts.</param>
/// <param name="Marker">The index of its marker state recipe.</param>
/// <param name="Phase">The index of its phase state recipe.</param>
public sealed record LastStandSpec(int Hp, int Turns, int Marker, int Phase);

/// <summary>
/// A state the reader adds to the game's states before it reads the note.
/// </summary>
/// <param name="Index">The recipe's index, which <c>{state:N}</c> placeholders name.</param>
/// <param name="Role">What the state is for.</param>
/// <param name="Name">The state's name.</param>
/// <param name="Note">The state's note, one tag per line, with placeholders.</param>
/// <param name="Features">The state's features.</param>
/// <param name="IconIndex">The state's icon.</param>
/// <param name="AutoRemovalTiming">When the game removes it by itself.</param>
/// <param name="MinTurns">The fewest turns it lasts.</param>
/// <param name="MaxTurns">The most turns it lasts.</param>
/// <param name="RemoveAtBattleEnd">Whether it ends with the battle.</param>
/// <param name="ClearDebuffs">Whether the boss's stat debuffs go when it gets the phase state.</param>
/// <param name="StartSkill">The skill the boss uses when it gets the phase state, or null.</param>
public sealed record StateRecipe(
    int Index,
    StateRecipeRole Role,
    string Name,
    string Note,
    IReadOnlyList<FeatureSpec> Features,
    int IconIndex,
    StateRemoval AutoRemovalTiming,
    int MinTurns,
    int MaxTurns,
    bool RemoveAtBattleEnd,
    bool ClearDebuffs,
    SkillRef? StartSkill = null);

/// <summary>
/// A delayed counter: a party hit on the boss arms an answer for the boss's next turn.
/// </summary>
/// <param name="Source">Where it comes from.</param>
/// <param name="HitType">The kind of hit that arms it.</param>
/// <param name="Trigger">Which party skills arm it.</param>
/// <param name="ChanceBasisPoints">The chance per action out of 10,000.</param>
/// <param name="CounterSkill">The skill it answers with.</param>
/// <param name="UsedUp">Whether it answers once a turn (a trait) or once at all (a stance).</param>
/// <param name="Nullifies">Whether it nullifies the action that armed it.</param>
/// <param name="TriggerSkill">The skill with <see cref="CounterTrigger.Skill"/>, null otherwise.</param>
/// <param name="TriggerSkillType">The skill type with <see cref="CounterTrigger.SkillType"/>, null otherwise.</param>
/// <param name="PhaseState">The index of the Last stand phase recipe it records under, or null.</param>
/// <param name="StanceSkill">The skill whose use arms a stance, or null.</param>
/// <param name="StanceTurns">The turns a stance lasts, or null.</param>
public sealed record DelayedCounterSpec(
    CounterSource Source,
    HitKind HitType,
    CounterTrigger Trigger,
    int ChanceBasisPoints,
    SkillRef CounterSkill,
    bool UsedUp,
    bool Nullifies,
    SkillRef? TriggerSkill = null,
    int? TriggerSkillType = null,
    int? PhaseState = null,
    SkillRef? StanceSkill = null,
    int? StanceTurns = null);

/// <summary>
/// A custom skill's stance: using it arms a delayed counter for some turns.
/// </summary>
/// <param name="Turns">The turns the stance lasts.</param>
/// <param name="Counter">The counter it arms.</param>
public sealed record StanceSpec(int Turns, DelayedCounterSpec Counter);
