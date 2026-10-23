//----------------------------------------------------------------
//  Samples.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Added the manual cells of a skill's targeting
//                            - Gave the sample boss a battlefield instead of start debris
//                            - Gave the boss its raid and a Hades refight
//                            - Added damage reduction effects and events
//                            - Gave the boss its event battle, enemy slots, a raid boss enemy and a reserve, and added fight change rules and events
//                            - Added debris types, the standard start debris and a boss's start debris
//      Paulinchen  2026-10-22: Added a hazard type, its sources, its effect and its events
//                            - Added a not in chain condition
//                            - Added a cast resolved trigger
//                            - Added a clear debuffs effect and its event
//                            - Gave the area skill a cycle
//                            - Added a rest skipped event
//                            - Added a start rest event and an opener
//                            - Named a seat on the sample rule fire
//                            - Set the main target on a unit hit trigger and event
//      Paulinchen  2026-10-21: Kept the parsed tree in every sample formula
//                            - Added a formula with a node of every kind
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Formulas;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Tests.Model;

/// <summary>
/// Hand-built values of every runtime model and event type, for the round-trip and canonical goldens.
/// </summary>
internal static class Samples
{
    /// <summary>
    /// A custom skill id.
    /// </summary>
    public const string BlastId = "9f3c0a1b2c3d4e5f60718293a4b5c6d7";

    /// <summary>
    /// A second custom skill id.
    /// </summary>
    public const string GuardId = "0123456789abcdef0123456789abcdef";

    /// <summary>
    /// The boss entity id.
    /// </summary>
    public const string BossId = "boss:7f3a91c04be2d55e0a1c9b8e2f6d4a10";

    /// <summary>
    /// The hazard id.
    /// </summary>
    public const string FireId = "hazard:3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b";

    /// <summary>
    /// The standard debris type id.
    /// </summary>
    public const string RockId = "debris:5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d";

    /// <summary>
    /// A debris type id that gives no cover.
    /// </summary>
    public const string CrystalId = "debris:c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5";

    /// <summary>
    /// The enemy slot of the starting line-up.
    /// </summary>
    public const string FirstSlot = "1a2b3c4d";

    /// <summary>
    /// The enemy slot of the reserve.
    /// </summary>
    public const string ReserveSlot = "2b3c4d5e";

    /// <summary>
    /// Gets a game skill reference.
    /// </summary>
    public static SkillRef Stigmata { get; } = SkillRef.OfGame(3764);

    /// <summary>
    /// Gets a custom skill reference.
    /// </summary>
    public static SkillRef Blast { get; } = SkillRef.OfCustom(BlastId);

    /// <summary>
    /// Gets a formula.
    /// </summary>
    public static FormulaSpec Formula { get; } = FormulaOf("[a.atk * 4 - b.def * 2, 0].max");

    /// <summary>
    /// Gets a formula whose tree holds a node of every kind.
    /// </summary>
    public static FormulaSpec EveryNodeFormula { get; } = FormulaOf("-[a.atk, clamp(b.luk, 0, 5)].max * 2.50 + (a.mat % 3).to_f.abs");

    /// <summary>
    /// Gets a rule of every trigger, condition and effect kind spread over a few rules.
    /// </summary>
    public static IReadOnlyList<RuleSpec> Rules { get; } =
    [
        new RuleSpec(
            "a1b2c3d4:sched",
            new RuleOrigin(PresetKind.ScheduledCast, BossId, "a1b2c3d4"),
            new TurnScheduleTrigger(2, 3),
            [],
            [new UseSkillEffect(Stigmata, true, true, CastTiming.PlanNow, CastSide.Own, CastAim.Default)],
            RuleLimits.None,
            null),
        new RuleSpec(
            "a1b2c3d4:follow",
            new RuleOrigin(PresetKind.FollowUp, BossId, "a1b2c3d4"),
            new AfterCastTrigger(CastOfAction: "a1b2c3d4"),
            [],
            [new UseSkillEffect(Blast, true, false, CastTiming.PlanNow, CastSide.Opposite, CastAim.Default)],
            RuleLimits.None,
            null),
        new RuleSpec(
            "game:3764:1c2d3e4f",
            new RuleOrigin(PresetKind.LeavesMark, BossId, "1c2d3e4f"),
            new UnitHitTrigger(BySkill: Stigmata, MainTarget: true),
            [new ChanceCondition(10000)],
            [new AddStateEffect(RuleTarget.TriggerUnit, 301, MinTurns: 1, UntilNextCastOf: AddStateEffect.RootOfCast)],
            RuleLimits.None,
            null),
        new RuleSpec(
            "77aa0b1c",
            new RuleOrigin(PresetKind.MarkReaction, BossId, "77aa0b1c"),
            new UnitHitTrigger(Holding: 301, HitByLeaving: 302),
            [new UnitHoldsCondition(301)],
            [new DamageEffect(RuleTarget.TriggerUnit, 150, null), new RemoveStateEffect(RuleTarget.TriggerUnit, 301)],
            new RuleLimits(true, false, null),
            null),
        new RuleSpec(
            "0d9e8f7a",
            new RuleOrigin(PresetKind.Advanced, BossId, "0d9e8f7a"),
            new BossHitTrigger(HitKind.Magic, true, SkillRef.OfGame(12), 3),
            [new BossHasStateCondition(14), new BossHpBetweenCondition(10, 50), new TurnAtLeastCondition(3), new NotSealedCondition(Blast)],
            [
                new UseSkillEffect(Blast, true, false, CastTiming.NextTurn, CastSide.Alternate, CastAim.Attacker),
                new ApDeltaEffect(-1, ApTurn.Next),
                new DamageEffect(RuleTarget.Boss, null, Formula),
            ],
            new RuleLimits(false, true, 3),
            "counters"),
        new RuleSpec(
            "5e6f7a8b",
            new RuleOrigin(PresetKind.Advanced, BossId, "5e6f7a8b"),
            new BossHpBelowTrigger(50),
            [],
            [
                new PlaceDebrisEffect(new SkillDebrisSpec(DebrisPlace.RandomInArea, 2, Count: 3)),
                new AddStateEffect(RuleTarget.Boss, 15, Turns: 2),
                new PlaceHazardEffect(new HazardPlacement(FireId, 10000, HazardPlace.AimedCell)),
            ],
            new RuleLimits(false, false, 1),
            null),
        new RuleSpec(
            "6a7b8c9d",
            new RuleOrigin(PresetKind.Advanced, BossId, "6a7b8c9d"),
            new StateAddedTrigger(29, StateHolder.Unit),
            [],
            [new AddStateEffect(RuleTarget.HitUnits, 30, Turns: 1), new DamageReductionEffect(RuleTarget.TriggerUnit, 30, 2), new RemoveDamageReductionEffect(RuleTarget.Boss)],
            RuleLimits.None,
            null),
        Simple("1a1a1a1a", new BattleStartTrigger()),
        Simple("2b2b2b2b", new TurnStartTrigger()),
        Simple("3c3c3c3c", new TurnEndTrigger()),
        Simple("4d4d4d4d", new UnitFellTrigger()),
        new RuleSpec(
            "8e9f0a1b",
            new RuleOrigin(PresetKind.FightChange, BossId, "8e9f0a1b"),
            new EnemyFellTrigger(FirstSlot),
            [new EnemyIsCondition(FirstSlot)],
            [new EnemyTransformsEffect(ReserveSlot, true), new EnemyLeavesEffect(ReserveSlot)],
            RuleLimits.None,
            Scope: RuleScope.Fight),
        new RuleSpec(
            "9f0a1b2c",
            new RuleOrigin(PresetKind.FightChange, BossId, "9f0a1b2c"),
            new AllEnemiesFellTrigger(),
            [],
            [new EnemyJoinsEffect(ReserveSlot)],
            new RuleLimits(false, false, 1)),
    ];

    /// <summary>
    /// Gets an area skill with every optional section set.
    /// </summary>
    public static RuntimeSkill AreaSkill { get; } = new(
        Stigmata,
        SkillKind.Area,
        new ShapeSpec(ShapeType.Zone, ShapeFit.Clip),
        2,
        3,
        2,
        false,
        new TargetSpec(TargetMode.RandomCell, false, Zone: new ZoneSpec(FrontRows: 2, MiddleColumns: 9, Cells: [new GridCell(0, 0), new GridCell(3, 1)], Half: GridHalf.Left, Side: SideChoice.Alternate)),
        new DamageSpec(100, Formula),
        new SpreadSpec(SpreadMode.Splash, 2, 4, 30, DistanceMetric.Manhattan, StateLanding.MainTarget, new ShapeSpec(ShapeType.Diamond, ShapeFit.Clip, Radius: 1, Offsets: [new GridCell(0, -1), new GridCell(-1, 0), new GridCell(0, 0)]), [2, 1.5]),
        new FalloffSpec(DistanceMetric.Chebyshev, [100, 85, 70, 55.5], true),
        new PresentationSpec(
            0,
            20,
            new ColorRgba(120, 60, 255, 160),
            new AnimationSpec(AnimationPlacement.OncePerWave, AnimationScreen.FitArea, 80, 40),
            new CellAnimationSpec(41, CellAnimationPlace.EachCell),
            new CellFlashSpec(new ColorRgba(255, 255, 255, 160), 12)),
        new PayloadSpec(
            true,
            1,
            false,
            [new PayloadEffectSpec(PayloadEffectKind.AddState, 4, 5000, false, null), new PayloadEffectSpec(PayloadEffectKind.GatedState, 6, 12000, true, 4)],
            [new PayloadEffectSpec(PayloadEffectKind.RemoveDebuff, 2, 10000, false, null)],
            [new RestorationSpec(ResourcePool.Hp, 0.25)],
            [new RecoverySpec(ResourcePool.Mp, 0.1, 50)],
            ["predation"],
            new HitFactsSpec(100, 1, -500, false, 15000)),
        new SkillFacts(3, 1, 2, 1, 0, 1, 4181, 7, [1, 12], new TargetFilter([CharacterKind.Female, CharacterKind.Hero]), "SS"),
        new SkillDebrisSpec(DebrisPlace.HitCells, 3, 2, Type: CrystalId),
        new MarksSpec([new MarkLeaveSpec("1c2d3e4f", 301, 10000, StateLanding.EveryoneHit, MarkUntil.NextScheduledCast, 1, null)]),
        Opener: true,
        Cycle: new CycleSpec(5, 3),
        Hazard: new HazardPlacement(FireId, 5000, HazardPlace.RandomInArea, 2, 1));

    /// <summary>
    /// Gets a hazard type with every part set.
    /// </summary>
    public static RuntimeHazard Hazard { get; } = new(
        FireId,
        "Burning ground",
        [HazardTrigger.StepsOnto, HazardTrigger.EndsTurnOn],
        [
            new DamageEffect(RuleTarget.TriggerUnit, 5),
            new AddStateEffect(RuleTarget.TriggerUnit, 29, Turns: 2),
            new RemoveStateEffect(RuleTarget.TriggerUnit, 30),
            new UseSkillEffect(Blast, true, false, CastTiming.NextTurn, CastSide.Own, CastAim.TriggerUnit),
        ],
        3,
        new HazardLook(180, new TileRef("Dungeon_A1", 2048), 112, new ColorRgba(255, 80, 0, 96)),
        4);

    /// <summary>
    /// Gets a support skill without the optional sections.
    /// </summary>
    public static RuntimeSkill SupportSkill { get; } = new(
        Blast,
        SkillKind.Support,
        new ShapeSpec(ShapeType.Line, ShapeFit.Shift, Thickness: 1, Direction: LineDirection.DiagonalUp, Length: 3),
        1,
        1,
        0,
        true,
        new TargetSpec(TargetMode.PickedCharacter, true, TargetPick.LowestHpRate),
        new DamageSpec(100, null),
        new SpreadSpec(SpreadMode.None, 2, 4, 50, DistanceMetric.Chebyshev, StateLanding.EveryoneHit),
        new FalloffSpec(DistanceMetric.Chebyshev, [100], false),
        new PresentationSpec(6, 20, new ColorRgba(230, 40, 40, 160), new AnimationSpec(AnimationPlacement.PerCharacter, AnimationScreen.Off, 100, 0)),
        new PayloadSpec(false, 0, false, [], [], [], [], [], new HitFactsSpec(100, 0, 0, true)),
        new SkillFacts(0, 0, 7, 0, 0, 1, 0, 3, [], new TargetFilter([])),
        Support: new SupportSpec(SupportTarget.OneAlly, 2));

    /// <summary>
    /// Gets a delayed counter.
    /// </summary>
    public static DelayedCounterSpec Counter { get; } = new(CounterSource.Stance, HitKind.Any, CounterTrigger.SkillType, 10000, Blast, true, false, null, 3, 1, SkillRef.OfCustom(GuardId), 2);

    /// <summary>
    /// Gets a trait block with every part set.
    /// </summary>
    public static TraitBlock Traits { get; } = new(
        [
            new TraitEntrySpec("e5f6a7b8", "triggerState", TraitSource.Boss, 0, [0, 0, 50, 29], new Dictionary<int, SkillRef>(), false, Tag: "<トリガーステート H,0,50%,{state:0}>"),
            new TraitEntrySpec("f0e1d2c3", "lastStand", TraitSource.Tier, 1, [50, 3], new Dictionary<int, SkillRef> { [1] = Blast }, true, new FeatureSpec(61, 0, 0.5), null, new LastStandSpec(50, 3, 0, 1)),
        ],
        [new FeatureSpec(61, 0, 1.5)],
        ["<属性強化 1-50>"],
        [
            new StateRecipe(0, StateRecipeRole.Marker, "Last stand marker at 50% HP", "", [], 0, StateRemoval.None, 0, 0, true, false),
            new StateRecipe(1, StateRecipeRole.Phase, "Last stand at 50% HP", "<ステート解除>\n{custom:0}", [new FeatureSpec(22, 1, 0.1)], 5, StateRemoval.TurnEnd, 3, 3, true, true, Blast),
        ],
        [Counter],
        ["The mod maps the custom skill to its runtime id."]);

    /// <summary>
    /// Gets a tier.
    /// </summary>
    public static RuntimeTier Tier { get; } = new(
        new GridSize(15, 6),
        new StatFactors(40, 1, 1.25, 4.33, 1, 4.33, 1, 1),
        9,
        [144],
        new Dictionary<int, double> { [3] = 50, [1] = 125.5 },
        new Dictionary<int, double> { [40] = 0 },
        Traits,
        2);

    /// <summary>
    /// Gets a boss with every part set.
    /// </summary>
    public static RuntimeBoss Boss { get; } = new(
        BossId,
        "Morrigan",
        "Morrigan",
        "Tier 2 Raid Boss",
        1200,
        false,
        true,
        BossOrigin.Catalog,
        new BattleEventRef(3, 723, 12, 1),
        [new RuntimeEnemy(0, FirstSlot, 301, new EnemyStats(5_000_000, 900, 410, 380, 395, 360, 120, 80), 9, true)],
        new Dictionary<string, IReadOnlyList<RuntimeAction>>
        {
            [FirstSlot] =
            [
                new RuntimeAction("a1b2c3d4", Stigmata, 5, new TurnActionCondition(2, 3), true, new FollowUpSpec(Blast, FollowUpSide.Opposite)),
                new RuntimeAction("b2c3d4e5", SkillRef.OfGame(1515), 4, new AlwaysActionCondition(), false, null),
                new RuntimeAction("c3d4e5f6", SkillRef.OfGame(1516), 3, new HpActionCondition(0, 50), false, null),
                new RuntimeAction("d4e5f6a7", SkillRef.OfGame(1517), 3, new MpActionCondition(20, 100), false, new FollowUpSpec(Stigmata, FollowUpSide.Same)),
                new RuntimeAction("e5f6a7b9", SkillRef.OfGame(1518), 2, new StateActionCondition(14), false, null),
                new RuntimeAction("f6a7b8c9", SkillRef.OfGame(1519), 2, new PartyLevelActionCondition(60), false, null),
                new RuntimeAction("a7b8c9d0", SkillRef.OfGame(1520), 1, new SwitchActionCondition(22), false, null),
            ],
            [ReserveSlot] = [],
        },
        new RuntimeNormalAttack(new Dictionary<int, SkillRef> { [301] = Blast }, new Dictionary<int, int> { [301] = 0 }, Blast, "<通常攻撃 {custom:0}>"),
        Traits,
        new Dictionary<string, RuntimeSkill> { [Stigmata.Key] = AreaSkill, [Blast.Key] = SupportSkill },
        Rules,
        [
            new MarkReactionSpec("77aa0b1c", 301, 302, new DamageGift(150, null), false),
            new MarkReactionSpec("88bb1c2d", 302, 301, new StateGift(15, 2), true),
            new MarkReactionSpec("99cc2d3e", 301, 301, new SkillGift(Blast), false),
            new MarkReactionSpec("aadd3e4f", 302, 302, new DamageGift(10, Formula), false),
        ],
        [new BattleMapRef(88, false), new BattleMapRef(723, true)],
        2,
        Reserve: [new ReserveEnemy(ReserveSlot, 302, new EnemyStats(2_500_000, 600, 380, 300, 410, 300, 140, 60), 7, true)],
        Battlefield: new Battlefield(new BattlefieldDebris(1000, CrystalId), new BattlefieldHazards(500, [FireId])),
        Raid: new RuntimeRaid("m723e12p0c3", "Sample raid", 1, "Phase 2", 2),
        AlsoAt: [new BattleUse(new BattleEventRef(9, 576, 14, 0), BattleUseKind.HadesRefight)]);

    /// <summary>
    /// Gets a custom skill.
    /// </summary>
    public static RuntimeCustomSkill CustomSkill { get; } = new(
        BlastId,
        0,
        "Blast",
        new CustomSkillFields("A blast.", 64, 1, 2, 1, 0, 100, 1, 0, 1, 10, 0, "%1 casts Blast!", "", 0, 0, 41, new CustomDamageSpec(1, 3, FormulaOf("a.atk * 2 - b.def / 2"), 20, false, EveryNodeFormula)),
        [new SkillEffectEntry(21, 4, 0.5, 0)],
        "<使用対象 2>",
        SupportSkill,
        [],
        1515,
        new StanceSpec(2, Counter));

    /// <summary>
    /// Gets the game rule.
    /// </summary>
    public static GameRules GameRules { get; } = new(
        new GridRules(new GridSize(15, 6), new GridSize(16, 10), new GridSize(15, 6), 1.5),
        new Dictionary<int, TierRule> { [0] = new(new GridSize(15, 7), 8, StatFactors.One), [9] = new(new GridSize(15, 6), 3, new StatFactors(1, 1, 1, 1, 1, 1, 1, 1)) },
        new UnitRules(16),
        new ApRules(3, 1, 20, new ApCostRules(1, 1, 20), 61, 180, 500, 1, 512),
        new PowerRules(["E", "D", "C"], new Dictionary<string, int> { ["E"] = 3, ["D"] = 3, ["C"] = 5 }, [new PowerSize(4181, 7), new PowerSize(2078, 5)], 3, 3, 99, 500),
        new ShareRules(2, 4),
        new KindRules([1, 2, 5, 6], new Dictionary<int, ExtensionKind> { [1] = ExtensionKind.Share, [2] = ExtensionKind.Area, [3] = ExtensionKind.Strikes }, [1, 2, 3]),
        new CrowdControlRules(4, [1, 214], [2, 3], 1, 1, 20, 1, 0, 999),
        new DebrisRules(2, new TileRef("Dungeon_A1", 1536), new TileRef("Dungeon_B", 0)),
        new PresentationRules(
            6,
            20,
            new AnimationRules(new AnimationDefault(AnimationPlacement.OncePerWave, AnimationScreen.FitArea), new AnimationDefault(AnimationPlacement.PerCharacter, AnimationScreen.FullScreen), 100, 100),
            new DangerRules(new ColorRgba(230, 40, 40, 160), new Dictionary<int, ColorRgba> { [1] = new(255, 120, 40, 160) })),
        new LimitRules(1000));

    /// <summary>
    /// Gets a runtime design that holds every model type.
    /// </summary>
    public static RuntimeDesign Design { get; } = new(
        RuntimeDesign.CurrentFormat,
        new RuntimeSource("09688b016a9392eadceae70c2a1d7b2a4ee04a8114e0f7028a301fa0ed4eb39e", 418, "1.3.0", "c0ffee00c0ffee00c0ffee00c0ffee00c0ffee00c0ffee00c0ffee00c0ffee00"),
        GameRules,
        new RuntimeCatalog(22, "Tier {tier} Raid Boss", "Raid Boss"),
        new Dictionary<int, RuntimeTier> { [2] = Tier },
        new RuntimeTier(new GridSize(15, 6), StatFactors.One, 3, [], new Dictionary<int, double>(), new Dictionary<int, double>(), TraitBlock.Empty),
        new Dictionary<string, RuntimeBoss> { ["Morrigan"] = Boss },
        [CustomSkill],
        new Dictionary<int, RuntimeState>
        {
            [10] = new(true, 1, 2, 3, StateRemoval.ActionEnd, 2, true, 21),
            [301] = new(false, 1, 1, 1, StateRemoval.None, 0, false, 0),
        },
        new Dictionary<int, RuntimeMap>
        {
            [88] = new(
                false,
                false,
                ["Morrigan"],
                7,
                new TileRef("Dungeon_A2", 1540)),
            [723] = new(false, false, []),
        },
        new Dictionary<int, RuntimeTileset> { [7] = new([1540, 1541], [], null, null, 57, new TileRef("Dungeon_B", 57)) },
        new Dictionary<string, RuntimeHazard> { [FireId] = Hazard },
        new Dictionary<string, RuntimeDebrisType>
        {
            [RockId] = new("Rock", 0, Look: new DebrisLook(DebrisLookKind.Picture, Picture: "Rock")),
            [CrystalId] = new("Crystal", 3, false, new DebrisLook(DebrisLookKind.Tile, new TileRef("Dungeon_A2", 1536))),
        });

    /// <summary>
    /// Gets a battle log with one event of every type.
    /// </summary>
    public static IReadOnlyList<BattleEvent> Events { get; } =
    [
        new BattleStartEvent(0),
        new DebrisPlacedEvent(0, [new GridCell(4, 2), new GridCell(5, 2)], 0, 2, null),
        new HazardPlacedEvent(0, FireId, [new GridCell(7, 2)], 3, 4),
        new StartRestEvent(0, 0, "game:3764", 2),
        new TurnStartEvent(1),
        new TurnScheduleEvent(1, 0),
        new AfterCastEvent(1, "c1", 0, Stigmata, PlanKind.Scheduled, "a1b2c3d4", "a1b2c3d4", GridHalf.Left),
        new AfterCastEvent(1, "c2", 0, Blast, PlanKind.FollowUp, null, "a1b2c3d4", GridHalf.Right),
        new RestSkippedEvent(1, 0, "game:1515", 1, 4),
        new ApTurnEvent(1, 0, 9, 6, 3),
        new CastDisabledEvent(1, "c3", 10),
        new UnitMovedEvent(1, 3, new GridCell(2, 1), new GridCell(3, 1)),
        new HazardFiredEvent(1, FireId, new GridCell(3, 1), 3, HazardTrigger.StepsOnto),
        new BossHitEvent(1, 0, 3, new GridCell(3, 1), HitKind.Physical, SkillRef.OfGame(1), [1], true),
        new BossHpBelowEvent(1, 0, 50),
        new UnitHitEvent(1, "c1", 0, Stigmata, 2, new GridCell(1, 0), [302], [301], "a1b2c3d4", true),
        new RuleFiredEvent(1, "77aa0b1c", 0, 2),
        new DamageEvent(1, StateHolder.Unit, 2, 1234, 766, "c1", null),
        new StateAddedEvent(1, StateHolder.Unit, 2, 301, "c1", "game:3764:1c2d3e4f"),
        new StateRemovedEvent(1, StateHolder.Unit, 2, 302, "77aa0b1c"),
        new CastResolvedEvent(1, "c1", 0, Stigmata, [2], false),
        new CastResolvedEvent(1, "c2", 0, Blast, [], true),
        new HazardPlacedEvent(1, FireId, [new GridCell(1, 0), new GridCell(2, 0)], 1, 4, "c1", "5e6f7a8b"),
        new HazardExpiredEvent(1, FireId, [new GridCell(3, 1)], HazardEnd.Replaced),
        new UnitFellEvent(1, 2, "c1"),
        new EnemyFellEvent(1, 0, FirstSlot, 301),
        new AllEnemiesFellEvent(1),
        new EnemyJoinedEvent(1, 1, ReserveSlot, 302, true, "9f0a1b2c"),
        new EnemyTransformedEvent(1, 1, ReserveSlot, FirstSlot, 301, 2_500_000, "8e9f0a1b"),
        new EnemyLeftEvent(1, 1, FirstSlot, 301, "8e9f0a1b"),
        new DamageReductionAddedEvent(1, StateHolder.Unit, 2, "6a7b8c9d#1", 30, 30, 2),
        new DamageReductionRemovedEvent(1, StateHolder.Boss, 0, "6a7b8c9d"),
        new WarningEvent(1, WarningEvent.RuleLoop, "0d9e8f7a"),
        new TurnEndEvent(1),
        new HazardExpiredEvent(1, FireId, [new GridCell(7, 2)], HazardEnd.Lifetime),
        new DamageReductionExpiredEvent(1, StateHolder.Unit, 2, "6a7b8c9d#1", 30),
    ];

    /// <summary>
    /// Gets one value of every model and event type that stands alone, the abstract bases by their derived types.
    /// </summary>
    public static IReadOnlyList<object> All { get; } = BuildAll();

    /// <summary>
    /// Reads a formula of the safe grammar and keeps its tree with its printed text.
    /// </summary>
    /// <param name="text">The formula.</param>
    /// <returns>The formula.</returns>
    /// <exception cref="ArgumentException">The formula is outside the grammar.</exception>
    private static FormulaSpec FormulaOf(string text)
    {
        FormulaParse parse = FormulaParser.Parse(text);
        return parse.IsValid
            ? new FormulaSpec(RubyPrinter.Print(parse.Root), parse.Root)
            : throw new ArgumentException($"The sample formula is refused with {parse.ErrorCode}.", nameof(text));
    }

    /// <summary>
    /// Adds a formula tree's nodes, the root first.
    /// </summary>
    /// <param name="all">The values to add to.</param>
    /// <param name="node">The tree's root.</param>
    private static void AddNodes(List<object> all, FormulaNode node)
    {
        all.Add(node);
        FormulaNode[] children = node switch
        {
            FormulaNegate negate => [negate.Operand],
            FormulaBinary binary => [binary.Left, binary.Right],
            FormulaMethod method => [method.Target],
            FormulaExtreme extreme => [.. extreme.Items],
            FormulaClamp clamp => [clamp.Value, clamp.Low, clamp.High],
            _ => [],
        };
        foreach (FormulaNode child in children)
        {
            AddNodes(all, child);
        }
    }

    /// <summary>
    /// Makes a rule whose trigger alone matters.
    /// </summary>
    /// <param name="id">The rule id.</param>
    /// <param name="trigger">The trigger.</param>
    /// <returns>The rule.</returns>
    private static RuleSpec Simple(string id, TriggerSpec trigger) =>
        new(id, new RuleOrigin(PresetKind.Advanced, BossId, id), trigger, [], [new ApDeltaEffect(1, ApTurn.This)], RuleLimits.None, null);

    /// <summary>
    /// Collects every value the samples hold.
    /// </summary>
    /// <returns>The values.</returns>
    private static List<object> BuildAll()
    {
        List<object> all =
        [
            Design, Design.Source, Design.Catalog, Design.States[10], Design.Maps[88], Design.Tilesets[7],
            GameRules, GameRules.Grid, GameRules.Tiers[0], GameRules.Units, GameRules.Ap, GameRules.Ap.Cost, GameRules.Power, GameRules.Share,
            GameRules.Kinds, GameRules.CrowdControl, GameRules.Debris, GameRules.Presentation, GameRules.Presentation.Animation,
            GameRules.Presentation.Animation.Area, GameRules.Presentation.Danger, GameRules.Limits,
            Tier, Tier.Stats, Boss.Battlefield!, Boss.Battlefield!.Debris!, Boss.Battlefield!.Hazards!, Boss.Raid!, Boss.AlsoAt![0], Design.DebrisTypes![CrystalId], Traits, Traits.Entries[1], Traits.Features[0], Traits.Entries[1].LastStand!, Traits.StateRecipes[1], Counter,
            Boss, Boss.Event, new BattleEventRef(0, CommonEvent: 40), Boss.Enemies[0], Boss.Reserve![0], Boss.Enemies[0].Stats, Boss.NormalAttack, Boss.BattleMaps[0], Boss.Actions[FirstSlot][0], Boss.Actions[FirstSlot][0].FollowUp!,
            CustomSkill, CustomSkill.Fields, CustomSkill.Fields.Damage, CustomSkill.Effects[0], CustomSkill.Stance!,
            AreaSkill, AreaSkill.Shape, AreaSkill.Targeting, AreaSkill.Targeting.Zone!, new ManualTarget([new GridCell(2, 1), new GridCell(7, 3)], new GridSize(15, 6), 1), AreaSkill.Damage, Formula, AreaSkill.Spread, AreaSkill.Falloff,
            AreaSkill.Presentation, AreaSkill.Presentation.CellAnimation!, AreaSkill.Presentation.CellFlash!, AreaSkill.Presentation.Animation,
            AreaSkill.Debris!, Design.DebrisTypes![CrystalId].Look!, AreaSkill.Marks!, AreaSkill.Marks!.Leaves[0], AreaSkill.Payload, AreaSkill.Payload.TargetEffects[0],
            AreaSkill.Payload.Restorations[0], AreaSkill.Payload.Recoveries[0], AreaSkill.Payload.Hit, SupportSkill.Support!, AreaSkill.Facts, AreaSkill.Facts.Filter, AreaSkill.Cycle!,
            EveryNodeFormula, Stigmata, Blast, new GridCell(3, 4), new GridSize(16, 10), new ColorRgba(1, 2, 3, 4), new TileRef("Sheet", 7), new PowerSize(100, 3),
            new ClearDebuffsEffect(RuleTarget.Boss), new DebuffsClearedEvent(2, StateHolder.Boss, 0, "5e6f7a8b:stand"), new CastResolvedTrigger(Blast), new NotInChainCondition(Blast),
            Hazard, Hazard.Look, AreaSkill.Hazard!,
        ];
        foreach (RuleSpec rule in Rules)
        {
            all.Add(rule);
            all.Add(rule.Origin);
            all.Add(rule.Limits);
            all.Add(rule.Trigger);
            all.AddRange(rule.Conditions);
            all.AddRange(rule.Effects);
        }

        foreach (IReadOnlyList<RuntimeAction> actions in Boss.Actions.Values)
        {
            foreach (RuntimeAction action in actions)
            {
                all.Add(action.Condition);
            }
        }

        foreach (MarkReactionSpec reaction in Boss.MarkReactions)
        {
            all.Add(reaction);
            all.Add(reaction.Gives);
        }

        AddNodes(all, EveryNodeFormula.Ast);
        all.AddRange(Events);
        return all;
    }
}
