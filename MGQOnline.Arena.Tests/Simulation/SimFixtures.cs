//----------------------------------------------------------------
//  SimFixtures.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Ran the simulations through the real rule engine
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Formulas;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Simulation;
using MGQOnline.Arena.Tests.Model;

namespace MGQOnline.Arena.Tests.Simulation;

/// <summary>
/// Builds small designs, setups and simulators for the simulation tests.
/// </summary>
internal static class SimFixtures
{
    /// <summary>
    /// The boss key of every test design.
    /// </summary>
    public const string BossKey = "Test";

    /// <summary>
    /// The enemy id of the test boss's first enemy.
    /// </summary>
    public const int EnemyId = 501;

    /// <summary>
    /// The tier of the test boss.
    /// </summary>
    public const int TierNumber = 3;

    /// <summary>
    /// A hard crowd control state that disables one entry.
    /// </summary>
    public const int Sleep = 11;

    /// <summary>
    /// A hard crowd control state that disables ten entries.
    /// </summary>
    public const int Stone = 12;

    /// <summary>
    /// A redirecting state.
    /// </summary>
    public const int Confusion = 10;

    /// <summary>
    /// The light mark.
    /// </summary>
    public const int LightMark = 301;

    /// <summary>
    /// The dark mark.
    /// </summary>
    public const int DarkMark = 302;

    /// <summary>
    /// Gets the normal attack.
    /// </summary>
    public static SkillRef Attack { get; } = SkillRef.OfGame(1);

    /// <summary>
    /// Gets a cheap skill.
    /// </summary>
    public static SkillRef Strike { get; } = SkillRef.OfGame(101);

    /// <summary>
    /// Gets a second cheap skill.
    /// </summary>
    public static SkillRef Sweep { get; } = SkillRef.OfGame(102);

    /// <summary>
    /// Gets a skill with a cooldown.
    /// </summary>
    public static SkillRef Heavy { get; } = SkillRef.OfGame(103);

    /// <summary>
    /// Gets a bind skill.
    /// </summary>
    public static SkillRef Hold { get; } = SkillRef.OfGame(110);

    /// <summary>
    /// Gets the light half skill.
    /// </summary>
    public static SkillRef Stigmata { get; } = SkillRef.OfGame(3764);

    /// <summary>
    /// Gets the dark half skill.
    /// </summary>
    public static SkillRef DarkStigmata { get; } = SkillRef.OfGame(3765);

    /// <summary>
    /// Makes a skill.
    /// </summary>
    /// <param name="skill">The skill.</param>
    /// <param name="cost">Its cost.</param>
    /// <param name="cooldown">Its cooldown.</param>
    /// <param name="unstoppable">Whether it is unstoppable.</param>
    /// <param name="zone">Its zone, or null.</param>
    /// <param name="skillTypes">Its skill types, or null for none.</param>
    /// <param name="marks">The marks it leaves, or null.</param>
    /// <returns>The skill.</returns>
    public static RuntimeSkill Skill(SkillRef skill, int cost = 1, int cooldown = 0, bool unstoppable = false, ZoneSpec? zone = null, IReadOnlyList<int>? skillTypes = null, MarksSpec? marks = null) => new(
        skill,
        SkillKind.Area,
        new ShapeSpec(zone is null ? ShapeType.Square : ShapeType.Zone, ShapeFit.Clip, Size: 1),
        1,
        cost,
        cooldown,
        unstoppable,
        new TargetSpec(TargetMode.RandomCell, false, Zone: zone),
        new DamageSpec(100),
        new SpreadSpec(SpreadMode.None, 0, 1, 0, DistanceMetric.Chebyshev, StateLanding.EveryoneHit),
        new FalloffSpec(DistanceMetric.Chebyshev, [100], false),
        new PresentationSpec(6, 20, new ColorRgba(230, 40, 40, 160), new AnimationSpec(AnimationPlacement.PerCharacter, AnimationScreen.Off, 100, 0)),
        new PayloadSpec(false, 0, false, [], [], [], [], [], new HitFactsSpec(100, 0, 0, true)),
        new SkillFacts(0, 1, 1, 1, 0, 1, 0, 1, skillTypes ?? [], new TargetFilter([])),
        Marks: marks);

    /// <summary>
    /// Makes a design of one boss.
    /// </summary>
    /// <param name="actions">The first enemy's actions.</param>
    /// <param name="skills">The boss's skills; the normal attack is added when missing.</param>
    /// <param name="rules">The boss's rules, or null for none.</param>
    /// <param name="ap">The tier's action points.</param>
    /// <param name="bankTurns">The turns' points a boss may bank.</param>
    /// <param name="attackWeight">The normal attack's weight.</param>
    /// <param name="tierStates">The states the tier keeps on the boss, or null for none.</param>
    /// <param name="traits">The boss's traits, or null for none.</param>
    /// <param name="attackCost">The normal attack's cost.</param>
    /// <returns>The design.</returns>
    public static RuntimeDesign Design(
        IReadOnlyList<RuntimeAction> actions,
        IEnumerable<RuntimeSkill> skills,
        IReadOnlyList<RuleSpec>? rules = null,
        int ap = 6,
        int bankTurns = 1,
        int attackWeight = 512,
        IReadOnlyList<int>? tierStates = null,
        TraitBlock? traits = null,
        int attackCost = 1)
    {
        Dictionary<string, RuntimeSkill> byKey = skills.ToDictionary(skill => skill.Ref.Key);
        byKey.TryAdd(Attack.Key, Skill(Attack, attackCost));
        RuntimeTier tier = Samples.Tier with
        {
            Grid = new GridSize(15, 6),
            Ap = ap,
            States = tierStates ?? [],
            Debris = RandomDebris.None,
            Traits = TraitBlock.Empty,
            Tier = TierNumber,
        };
        RuntimeBoss boss = Samples.Boss with
        {
            Key = BossKey,
            Troops = [new TroopPhase(900, true)],
            Last = 900,
            Enemies = [new RuntimeEnemy(900, 0, EnemyId, new EnemyStats(100_000, 500, 100, 100, 100, 100, 100, 100), ap)],
            Actions = new Dictionary<int, IReadOnlyList<RuntimeAction>> { [EnemyId] = actions },
            NormalAttack = new RuntimeNormalAttack(new Dictionary<int, SkillRef> { [EnemyId] = Attack }, new Dictionary<int, int>()),
            Traits = traits ?? TraitBlock.Empty,
            Skills = byKey,
            Rules = rules ?? [],
            MarkReactions = [],
            Tier = TierNumber,
        };
        GameRules gameRules = Samples.GameRules with
        {
            Ap = Samples.GameRules.Ap with { BankTurns = bankTurns, NormalAttackWeight = attackWeight },
        };
        return Samples.Design with
        {
            Rules = gameRules,
            Tiers = new Dictionary<int, RuntimeTier> { [TierNumber] = tier },
            Bosses = new Dictionary<string, RuntimeBoss> { [BossKey] = boss },
            States = new Dictionary<int, RuntimeState>
            {
                [Confusion] = new(false, 1, 2, 3, StateRemoval.ActionEnd, 2, true, 21),
                [Sleep] = new(true, 1, 3, 4, StateRemoval.ActionEnd, 4, false, 22),
                [Stone] = new(true, 10, 3, 4, StateRemoval.ActionEnd, 4, false, 23),
                [LightMark] = new(false, 1, 1, 1, StateRemoval.None, 0, false, 0),
                [DarkMark] = new(false, 1, 1, 1, StateRemoval.None, 0, false, 0),
            },
        };
    }

    /// <summary>
    /// Makes an action that may always be used.
    /// </summary>
    /// <param name="id">The action id.</param>
    /// <param name="skill">The skill.</param>
    /// <param name="rating">The rating.</param>
    /// <param name="condition">The condition, or null for always.</param>
    /// <param name="scheduled">Whether it is scheduled.</param>
    /// <returns>The action.</returns>
    public static RuntimeAction Action(string id, SkillRef skill, int rating = 5, ActionCondition? condition = null, bool scheduled = false) =>
        new(id, skill, rating, condition ?? new AlwaysActionCondition(), scheduled);

    /// <summary>
    /// Makes a rule.
    /// </summary>
    /// <param name="id">The rule id.</param>
    /// <param name="preset">The preset it comes from.</param>
    /// <param name="itemId">The item it comes from.</param>
    /// <param name="trigger">The trigger.</param>
    /// <param name="effects">The effects.</param>
    /// <param name="conditions">The conditions, or null for none.</param>
    /// <param name="limits">The limits, or null for none.</param>
    /// <returns>The rule.</returns>
    public static RuleSpec Rule(string id, PresetKind preset, string itemId, TriggerSpec trigger, IReadOnlyList<EffectSpec> effects, IReadOnlyList<ConditionSpec>? conditions = null, RuleLimits? limits = null) =>
        new(id, new RuleOrigin(preset, "boss:test", itemId), trigger, conditions ?? [], effects, limits ?? RuleLimits.None);

    /// <summary>
    /// Makes the rule a scheduled action is lowered to.
    /// </summary>
    /// <param name="actionId">The action id.</param>
    /// <param name="skill">The skill.</param>
    /// <param name="a">The first turn.</param>
    /// <param name="b">The turns between two more.</param>
    /// <returns>The rule.</returns>
    public static RuleSpec Scheduled(string actionId, SkillRef skill, int a, int b) =>
        Rule(actionId + ":sched", PresetKind.ScheduledCast, actionId, new TurnScheduleTrigger(a, b), [new UseSkillEffect(skill, true, true, CastTiming.PlanNow, CastSide.Own, CastAim.Default)]);

    /// <summary>
    /// Makes the rule a follow-up is lowered to.
    /// </summary>
    /// <param name="actionId">The parent action id.</param>
    /// <param name="skill">The follow-up skill.</param>
    /// <param name="side">The follow-up's side.</param>
    /// <returns>The rule.</returns>
    public static RuleSpec FollowUp(string actionId, SkillRef skill, CastSide side = CastSide.Opposite) =>
        Rule(actionId + ":follow", PresetKind.FollowUp, actionId, new AfterCastTrigger(actionId), [new UseSkillEffect(skill, true, false, CastTiming.PlanNow, side, CastAim.Default)]);

    /// <summary>
    /// Makes a party setup.
    /// </summary>
    /// <param name="cells">The units' cells.</param>
    /// <param name="seed">The battle seed.</param>
    /// <param name="partyLevel">The party's level.</param>
    /// <param name="switches">The switches on, or null for none.</param>
    /// <returns>The setup.</returns>
    public static BattleSetup Setup(IEnumerable<GridCell> cells, ulong seed = 42, int partyLevel = 10, IReadOnlySet<int>? switches = null) => new(
        BossKey,
        null,
        [.. cells.Select(cell => new PartyUnitSetup(cell, 1000, new FormulaStats(1000, 100, 50, 50, 50, 50, 50, 50, 1000, 100, 10), CharacterKind.Female, 1000, new Dictionary<int, double>(), new Dictionary<int, double>()))],
        partyLevel,
        switches ?? new HashSet<int>(),
        88,
        seed);

    /// <summary>
    /// Makes a setup of units in the front row from the left.
    /// </summary>
    /// <param name="units">How many units.</param>
    /// <param name="seed">The battle seed.</param>
    /// <returns>The setup.</returns>
    public static BattleSetup Setup(int units = 4, ulong seed = 42) => Setup(Enumerable.Range(0, units).Select(i => new GridCell(i % 15, i / 15)), seed);

    /// <summary>
    /// Makes a simulator over the fake casting part and the real rule engine.
    /// </summary>
    /// <param name="design">The design.</param>
    /// <param name="options">The options, or null.</param>
    /// <returns>The simulator.</returns>
    public static BattleSimulator Simulator(RuntimeDesign design, SimulationOptions? options = null) =>
        new(design, new FakeCasts(), options);

    /// <summary>
    /// Plays turns with an idle party and returns each turn's result.
    /// </summary>
    /// <param name="simulator">The simulator.</param>
    /// <param name="state">The battle.</param>
    /// <param name="turns">The turns.</param>
    /// <returns>The results.</returns>
    public static List<TurnResult> Play(BattleSimulator simulator, BattleState state, int turns)
    {
        List<TurnResult> results = [];
        for (int i = 0; i < turns && !state.IsOver; i++)
        {
            simulator.Plan(state);
            results.Add(simulator.Resolve(state, PartyTurn.Idle));
        }

        return results;
    }
}
