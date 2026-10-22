//----------------------------------------------------------------
//  EngineSamples.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Keyed the sample book by enemy slot
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Engine;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Formulas;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Tests.Engine;

/// <summary>
/// Builds the rules, books and events the engine tests use.
/// </summary>
internal static class EngineSamples
{
    /// <summary>
    /// The light mark.
    /// </summary>
    public const int Light = 301;

    /// <summary>
    /// The dark mark.
    /// </summary>
    public const int Dark = 302;

    /// <summary>
    /// The id of the scheduled Stigmata action.
    /// </summary>
    public const string StigmataAction = "a1b2c3d4";

    /// <summary>
    /// The id of a rolled action.
    /// </summary>
    public const string RolledAction = "b2c3d4e5";

    /// <summary>
    /// The boss entity id of the rules.
    /// </summary>
    public const string BossId = "boss:7f3a91c04be2d55e0a1c9b8e2f6d4a10";

    /// <summary>
    /// Gets the light Stigmata skill, which leaves the light mark.
    /// </summary>
    public static SkillRef LightStigmata { get; } = SkillRef.OfGame(3764);

    /// <summary>
    /// Gets the dark Stigmata skill, which leaves the dark mark.
    /// </summary>
    public static SkillRef DarkStigmata { get; } = SkillRef.OfGame(3765);

    /// <summary>
    /// Gets a skill of skill type 3.
    /// </summary>
    public static SkillRef Blast { get; } = SkillRef.OfGame(1515);

    /// <summary>
    /// Gets the action list of enemy 0: Stigmata scheduled on turn 2 + 3·X with a dark follow-up, and a rolled Blast.
    /// </summary>
    public static IReadOnlyList<RuntimeAction> Actions { get; } =
    [
        new RuntimeAction(StigmataAction, LightStigmata, 5, new TurnActionCondition(2, 3), true, new FollowUpSpec(DarkStigmata, FollowUpSide.Opposite)),
        new RuntimeAction(RolledAction, Blast, 4, new AlwaysActionCondition(), false),
    ];

    /// <summary>
    /// Makes a rule.
    /// </summary>
    /// <param name="id">The rule id.</param>
    /// <param name="trigger">The trigger.</param>
    /// <param name="effects">The effects.</param>
    /// <param name="conditions">The conditions, or null for none.</param>
    /// <param name="limits">The limits, or null for none.</param>
    /// <param name="group">The group, or null.</param>
    /// <param name="preset">The preset it comes from.</param>
    /// <param name="itemId">The item it comes from, or null for the id.</param>
    /// <returns>The rule.</returns>
    public static RuleSpec Rule(
        string id,
        TriggerSpec trigger,
        IReadOnlyList<EffectSpec> effects,
        IReadOnlyList<ConditionSpec>? conditions = null,
        RuleLimits? limits = null,
        string? group = null,
        PresetKind preset = PresetKind.Advanced,
        string? itemId = null) =>
        new(id, new RuleOrigin(preset, BossId, itemId ?? id), trigger, conditions ?? [], effects, limits ?? RuleLimits.None, group);

    /// <summary>
    /// Makes a rule whose one effect gives the boss an action point, for telling which rules fired.
    /// </summary>
    /// <param name="id">The rule id.</param>
    /// <param name="trigger">The trigger.</param>
    /// <param name="conditions">The conditions, or null for none.</param>
    /// <param name="limits">The limits, or null for none.</param>
    /// <param name="group">The group, or null.</param>
    /// <returns>The rule.</returns>
    public static RuleSpec Marker(string id, TriggerSpec trigger, IReadOnlyList<ConditionSpec>? conditions = null, RuleLimits? limits = null, string? group = null) =>
        Rule(id, trigger, [new ApDeltaEffect(1, ApTurn.This)], conditions, limits, group);

    /// <summary>
    /// Makes a rule book with the sample actions for every enemy.
    /// </summary>
    /// <param name="rules">The rules.</param>
    /// <param name="enemies">The number of enemies.</param>
    /// <returns>The book.</returns>
    public static RuleBook Book(IReadOnlyList<RuleSpec> rules, int enemies = 1) =>
        new(
            rules,
            Enumerable.Range(0, enemies).ToDictionary(FakeRuleContext.SlotOfIndex, _ => Actions),
            new Dictionary<string, IReadOnlyList<int>> { [Blast.Key] = [3], [LightStigmata.Key] = [1], [DarkStigmata.Key] = [1] });

    /// <summary>
    /// Makes an engine over rules.
    /// </summary>
    /// <param name="rules">The rules.</param>
    /// <returns>The engine.</returns>
    public static RuleEngine EngineOf(params RuleSpec[] rules) => new(Book(rules));

    /// <summary>
    /// Makes the leaves-mark rule of a Stigmata skill as the lowering writes it.
    /// </summary>
    /// <param name="skill">The skill.</param>
    /// <param name="mark">The mark it leaves.</param>
    /// <returns>The rule.</returns>
    public static RuleSpec Leaves(SkillRef skill, int mark) =>
        Rule(
            $"{skill.Key}:leave{mark}",
            new UnitHitTrigger(BySkill: skill),
            [new AddStateEffect(RuleTarget.TriggerUnit, mark, MinTurns: 1, UntilNextCastOf: AddStateEffect.RootOfCast)],
            [new ChanceCondition(10_000)],
            preset: PresetKind.LeavesMark);

    /// <summary>
    /// Makes a mark reaction as the lowering writes it: damage by percent, and the held mark consumed unless kept.
    /// </summary>
    /// <param name="id">The rule id.</param>
    /// <param name="holding">The mark the unit holds.</param>
    /// <param name="leaving">The mark the hitting skill leaves.</param>
    /// <param name="percent">The damage in percent of the unit's max HP.</param>
    /// <param name="keepMark">Whether the mark stays.</param>
    /// <returns>The rule.</returns>
    public static RuleSpec Reaction(string id, int holding, int leaving, double percent, bool keepMark = false)
    {
        List<EffectSpec> effects = [new DamageEffect(RuleTarget.TriggerUnit, percent)];
        if (!keepMark)
        {
            effects.Add(new RemoveStateEffect(RuleTarget.TriggerUnit, holding));
        }

        return Rule(id, new UnitHitTrigger(Holding: holding, HitByLeaving: leaving), effects, limits: new RuleLimits(true, false), preset: PresetKind.MarkReaction);
    }

    /// <summary>
    /// Makes a unit hit event.
    /// </summary>
    /// <param name="turn">The turn.</param>
    /// <param name="castId">The cast.</param>
    /// <param name="skill">The skill.</param>
    /// <param name="seat">The unit's seat.</param>
    /// <param name="heldBefore">The states the unit held before the cast.</param>
    /// <param name="leaves">The marks the skill leaves.</param>
    /// <param name="root">The root action of the cast.</param>
    /// <param name="enemy">The casting enemy.</param>
    /// <returns>The event.</returns>
    public static UnitHitEvent Hit(int turn, string castId, SkillRef skill, int seat, int[]? heldBefore = null, int[]? leaves = null, string? root = StigmataAction, int enemy = 0) =>
        new(turn, castId, enemy, skill, seat, new GridCell(seat, 0), heldBefore ?? [], leaves ?? [], root);

    /// <summary>
    /// Makes a unit hit event that reads the unit's states and the skill's mark from a battle.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <param name="turn">The turn.</param>
    /// <param name="castId">The cast.</param>
    /// <param name="skill">The skill.</param>
    /// <param name="mark">The mark the skill leaves.</param>
    /// <param name="seat">The unit's seat.</param>
    /// <returns>The event.</returns>
    public static UnitHitEvent HitIn(FakeRuleContext context, int turn, string castId, SkillRef skill, int mark, int seat) =>
        Hit(turn, castId, skill, seat, context.StatesOf(StateHolder.Unit, seat).Select(held => held.State).ToArray(), [mark]);

    /// <summary>
    /// Reads a formula of the safe grammar.
    /// </summary>
    /// <param name="text">The formula.</param>
    /// <returns>The formula.</returns>
    /// <exception cref="ArgumentException">The formula is outside the grammar.</exception>
    public static FormulaSpec Formula(string text)
    {
        FormulaParse parse = FormulaParser.Parse(text);
        return parse.IsValid ? new FormulaSpec(text, parse.Root) : throw new ArgumentException(parse.ErrorCode, nameof(text));
    }

    /// <summary>
    /// Gives the rule ids that fired, in log order.
    /// </summary>
    /// <param name="context">The battle.</param>
    /// <returns>The ids.</returns>
    public static string[] FiredIds(FakeRuleContext context) => context.LoggedOf<RuleFiredEvent>().Select(fired => fired.RuleId).ToArray();
}
