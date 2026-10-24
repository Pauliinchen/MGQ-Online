//----------------------------------------------------------------
//  GoldenParityTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Wrote the turn start skills as rows of the Trigger -> Effect framework
//      Paulinchen  2026-10-23: Built the enemy without a troop
//      Paulinchen  2026-10-22: Planned the Overdrive and Last stand cases through the plan toggles
//      Paulinchen  2026-10-21: Built state instances without a mark clock
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Text.Json;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;
using MGQOnline.Arena.Simulation;

namespace MGQOnline.Arena.Tests.Simulation;

/// <summary>
/// Compares the simulation's rules with the old designer rules captured in the apUses and
/// turnPlans goldens.
/// </summary>
/// <remarks>The old rules rolled with System.Random, so only the rules compare, never the picks.
/// Intended differences: the points left go to the bank instead of the normal attack, which is an
/// ordinary candidate of the roll with the lowest weight (so cases with a normal attack cost only
/// check the new rule), and turn start skills come from rules rather than the old chance roll.</remarks>
public sealed class GoldenParityTests
{
    /// <summary>
    /// The turns the long-battle comparison plays per case.
    /// </summary>
    private const int Turns = 20_000;

    /// <summary>
    /// The difference in uses per turn the long-battle comparison allows.
    /// </summary>
    private const double Tolerance = 0.04;

    /// <summary>
    /// The weight of the normal attack in the new rule's checks.
    /// </summary>
    private const int AttackWeight = 512;

    /// <summary>
    /// The key the normal attack's candidate rolls under.
    /// </summary>
    private const string AttackKey = "attack";

    /// <summary>
    /// What a use leaves of a weight in the old rule, 0.5 as permille.
    /// </summary>
    private const int HalfPermille = 500;

    /// <summary>
    /// The state of the mini game whose feature 180 takes one point away (Stop).
    /// </summary>
    private const int Stop = 17;

    /// <summary>
    /// The state of the mini game whose feature 61 adds one point (Haste).
    /// </summary>
    private const int Haste = 20;

    /// <summary>
    /// The new roll over a long battle uses each action as often per turn as the old rule's
    /// expected uses, cooldown rests included, for every case without a normal attack.
    /// </summary>
    [Fact]
    public void RollsTheExpectedUses()
    {
        using JsonDocument golden = Load("apUses.json");
        int compared = 0;
        foreach (JsonElement entry in golden.RootElement.GetProperty("cases").EnumerateArray().Where(entry => Kind(entry) == "expected" && entry.GetProperty("attackCost").ValueKind == JsonValueKind.Null))
        {
            List<RollCandidate> candidates = CandidatesOf(entry.GetProperty("actions"));
            int ap = entry.GetProperty("ap").GetInt32();
            double[] uses = PlayLong(candidates, ap);
            double[] expected = [.. entry.GetProperty("uses").EnumerateArray().Select(value => value.GetDouble())];
            for (int i = 0; i < expected.Length; i++)
            {
                Assert.True(Math.Abs(uses[i] - expected[i]) <= Tolerance, $"{entry.GetProperty("name").GetString()}: action {i} {uses[i]:0.000} against {expected[i]:0.000}");
            }

            compared++;
        }

        Assert.True(compared >= 7);
    }

    /// <summary>
    /// The old rule's picks and the new roll's picks of every playTurn case keep the rules: the
    /// points spent fit, resting and unpickable actions stay out, a cooldown skill comes once, and
    /// nothing affordable is left at the end.
    /// </summary>
    [Fact]
    public void KeepsTheRulesOfEveryPlayedTurn()
    {
        using JsonDocument golden = Load("apUses.json");
        int checkedCases = 0;
        foreach (JsonElement entry in golden.RootElement.GetProperty("cases").EnumerateArray().Where(entry => Kind(entry) == "playTurn"))
        {
            List<RollCandidate> candidates = CandidatesOf(entry.GetProperty("actions"));
            int ap = entry.GetProperty("ap").GetInt32();
            HashSet<string> resting = [.. entry.GetProperty("resting").EnumerateArray().Select(value => value.GetInt32().ToString(CultureInfo.InvariantCulture))];
            if (entry.GetProperty("attackCost").ValueKind == JsonValueKind.Null)
            {
                AssertRules(candidates, ap, resting, [.. entry.GetProperty("picks").EnumerateArray().Select(value => value.GetInt32())]);
            }
            else
            {
                candidates.Add(new RollCandidate(AttackKey, AttackWeight, entry.GetProperty("attackCost").GetInt32(), 0));
            }

            ArenaRandom random = new((ulong)entry.GetProperty("seed").GetInt32());
            RollResult roll = ActionRoll.Roll(candidates, ap, HalfPermille, random, resting);
            AssertRules(candidates, ap, resting, roll.Picks);
            Assert.Equal(ap - roll.Picks.Sum(pick => candidates[pick].Cost), roll.Left);
            checkedCases++;
        }

        Assert.Equal(45, checkedCases);
    }

    /// <summary>
    /// Every turnPlans case plans by the same rules as the old turn plan: the same action points,
    /// forced entries first and never disabled, as many entries disabled by crowd control, the
    /// redirect marks, the Overdrive's freeze and the grapple.
    /// </summary>
    [Fact]
    public void PlansByTheOldRules()
    {
        using JsonDocument golden = Load("turnPlans.json");
        JsonElement scenarios = golden.RootElement.GetProperty("inputs").GetProperty("scenarios");
        int compared = 0;
        foreach (JsonElement entry in golden.RootElement.GetProperty("cases").EnumerateArray())
        {
            string name = entry.GetProperty("scenario").GetString()!;
            JsonElement scenario = scenarios.GetProperty(name);
            JsonElement options = entry.GetProperty("options");
            JsonElement old = entry.GetProperty("plan");
            CaseFacts facts = FactsOf(scenario, options, name);
            (EnemyPlan plan, IReadOnlyList<PlannedCast> entries) = PlanCase(name, scenario, options, facts);

            Assert.Equal(old.GetProperty("ap").GetInt32(), plan.ApStart);
            AssertOldPlan(old, facts);
            AssertNewPlan(plan, entries, facts);
            compared++;
        }

        Assert.Equal(280, compared);
    }

    /// <summary>
    /// Checks the old plan of a case against the rules.
    /// </summary>
    /// <param name="old">The old plan.</param>
    /// <param name="facts">What the case sets.</param>
    private static void AssertOldPlan(JsonElement old, CaseFacts facts)
    {
        List<JsonElement> entries = [.. old.GetProperty("entries").EnumerateArray()];
        bool[] forced = [.. entries.Select(each => each.GetProperty("forced").ValueKind != JsonValueKind.Null)];
        bool[] stoppable = [.. entries.Select((each, i) => !forced[i] && !each.GetProperty("unstoppable").GetBoolean())];
        Assert.True(forced.SkipWhile(isForced => isForced).All(isForced => !isForced));
        Assert.True(entries.Where((_, i) => !stoppable[i]).All(each => each.GetProperty("disabledBy").ValueKind == JsonValueKind.Null));
        Assert.True(entries.Where((_, i) => !forced[i]).Sum(each => each.GetProperty("cost").GetInt32()) <= old.GetProperty("ap").GetInt32());
        if (facts.Frozen)
        {
            Assert.All(entries, each => Assert.True(each.GetProperty("timeStopped").GetBoolean()));
            return;
        }

        Assert.All(entries, each => Assert.False(each.GetProperty("timeStopped").GetBoolean()));
        int planDisabled = entries.Count(each => each.GetProperty("disabledBy").ValueKind != JsonValueKind.Null && !each.GetProperty("midTurn").GetBoolean());
        Assert.Equal(Math.Min(facts.PlanDisables, stoppable.Count(isStoppable => isStoppable)), planDisabled);
        Assert.True(entries.Count(each => each.GetProperty("midTurn").GetBoolean()) <= facts.MidTurnHardCc);
        if (facts.PlanRedirect is int redirect)
        {
            Assert.True(entries.Where((each, i) => stoppable[i] && each.GetProperty("disabledBy").ValueKind == JsonValueKind.Null)
                .All(each => each.GetProperty("mayRedirect").EnumerateArray().Any(id => id.GetInt32() == redirect)));
        }

        if (facts.GrapplePool)
        {
            Assert.Single(entries.Where((_, i) => !forced[i]));
            Assert.Equal(old.GetProperty("ap").GetInt32(), old.GetProperty("apLeft").GetInt32());
        }
    }

    /// <summary>
    /// Checks the new plan of a case against the rules.
    /// </summary>
    /// <param name="plan">The enemy's plan.</param>
    /// <param name="entries">The entries after the mid-turn landings.</param>
    /// <param name="facts">What the case sets.</param>
    private static void AssertNewPlan(EnemyPlan plan, IReadOnlyList<PlannedCast> entries, CaseFacts facts)
    {
        bool[] forced = [.. entries.Select(entry => entry.Kind is not (PlanKind.Rolled or PlanKind.Grapple))];
        Assert.True(forced.SkipWhile(isForced => isForced).All(isForced => !isForced));
        Assert.True(plan.ApSpent <= plan.ApStart);
        Assert.InRange(plan.ApBanked, 0, plan.ApStart - plan.ApSpent);
        if (facts.Frozen)
        {
            Assert.All(entries, entry => Assert.True(entry.TimeStopped && entry.Disabled));
            return;
        }

        Assert.All(entries, entry => Assert.False(entry.TimeStopped));
        Assert.All(entries.Where((_, i) => forced[i]), entry => Assert.False(entry.Disabled));
        Assert.All(entries.Where(entry => !entry.Stoppable), entry => Assert.False(entry.Disabled));
        int planDisabled = entries.Count(entry => entry.Disabled && !entry.MidTurn);
        Assert.Equal(Math.Min(facts.PlanDisables, entries.Count(entry => entry.Stoppable)), planDisabled);
        Assert.Equal(Math.Min(facts.MidTurnHardCc, facts.MidTurnEligible), entries.Count(entry => entry.MidTurn));
        if (facts.PlanRedirect is int redirect)
        {
            Assert.All(entries.Where(entry => entry.Stoppable && !entry.Disabled), entry => Assert.Contains(redirect, entry.MayRedirect));
        }

        if (facts.GrapplePool)
        {
            PlannedCast grapple = Assert.Single(entries.Where((_, i) => !forced[i]));
            Assert.Equal(PlanKind.Grapple, grapple.Kind);
            Assert.Equal(facts.GrappleSkill, grapple.Skill);
            Assert.Equal(0, plan.ApSpent);
        }
    }

    /// <summary>
    /// Plans the first turn of a turnPlans case with the new simulation.
    /// </summary>
    /// <param name="name">The scenario's name.</param>
    /// <param name="scenario">The scenario.</param>
    /// <param name="options">The case's options.</param>
    /// <param name="facts">What the case sets; receives the entries the mid-turn landings could reach.</param>
    /// <returns>The enemy's plan and its entries after the mid-turn landings.</returns>
    private static (EnemyPlan Plan, IReadOnlyList<PlannedCast> Entries) PlanCase(string name, JsonElement scenario, JsonElement options, CaseFacts facts)
    {
        RuntimeDesign design = DesignOf(name, scenario);
        BattleSimulator simulator = SimFixtures.Simulator(design, options: new SimulationOptions(new Dictionary<int, IReadOnlyList<FeatureSpec>>
        {
            [Stop] = [new FeatureSpec(180, 0, 1)],
            [Haste] = [new FeatureSpec(61, 0, 1.0)],
        }));
        BattleState state = simulator.Start(SimFixtures.Setup(seed: (ulong)options.GetProperty("seed").GetInt32()));
        EnemyState enemy = state.Enemies[0];
        foreach (JsonElement landing in options.GetProperty("states").EnumerateArray().Where(landing => !landing.GetProperty("midTurn").GetBoolean()))
        {
            StateClock.Put(enemy.States, new StateInstance(landing.GetProperty("state").GetInt32(), new StateSource(), 0, null));
        }

        string grapple = options.GetProperty("grapple").GetString()!;
        if (grapple != "None")
        {
            StateClock.Put(enemy.States, new StateInstance(grapple == "Bind" ? BattleSimulator.BindState : BattleSimulator.EternalBindState, new StateSource(), 0, null));
        }

        if (options.GetProperty("delayedAnswer").GetBoolean())
        {
            state.NextTurn.Add(new QueuedCast(0, SkillRef.OfGame(13), PlanKind.DelayedAnswer, CastSide.Own, null, null, null, "counter", 0));
        }

        PlanToggles toggles = new(options.GetProperty("overdrive").GetBoolean(), options.GetProperty("lastStandStarts").GetBoolean());
        EnemyPlan plan = simulator.Plan(state, toggles).Enemies[0];
        int from = state.Plan.Count / 2;
        foreach (JsonElement landing in options.GetProperty("states").EnumerateArray().Where(landing => landing.GetProperty("midTurn").GetBoolean()))
        {
            int id = landing.GetProperty("state").GetInt32();
            facts.MidTurnEligible = state.Plan.Skip(from).Count(entry => entry.Stoppable && !entry.Disabled);
            if (!facts.Frozen)
            {
                CrowdControl.MidTurn(state.Plan, from, 0, id, design.States[id], design.Rules.CrowdControl.MidTurnDisables, state.Random.Get(RandomStream.Cc));
            }
        }

        return (plan, [.. state.Plan]);
    }

    /// <summary>
    /// Builds the design of a scenario from its resolved inputs.
    /// </summary>
    /// <param name="name">The scenario's name.</param>
    /// <param name="scenario">The scenario.</param>
    /// <returns>The design.</returns>
    private static RuntimeDesign DesignOf(string name, JsonElement scenario)
    {
        List<JsonElement> turnActions = [.. scenario.GetProperty("turnActions").EnumerateArray()];
        List<string> pools = [.. scenario.GetProperty("pools").EnumerateArray().Select(pool => pool.GetString()!)];
        HashSet<int> unstoppable = [.. scenario.GetProperty("unstoppable").EnumerateArray().Select(id => id.GetInt32())];
        List<RuntimeAction> actions = [];
        List<RuntimeSkill> skills = [];
        for (int i = 0; i < turnActions.Count; i++)
        {
            SkillRef skill = SkillRef.OfGame(turnActions[i].GetProperty("skill").GetInt32());
            int rating = (int)turnActions[i].GetProperty("weight").GetDouble();
            IReadOnlyList<int> types = pools[i] switch
            {
                "Bind" => [BattleSimulator.BindSkillType],
                "EternalBind" => [BattleSimulator.EternalBindSkillType],
                _ => [],
            };
            actions.Add(SimFixtures.Action("a" + i.ToString(CultureInfo.InvariantCulture), skill, pools[i] == "Normal" ? rating : 5));
            skills.Add(SimFixtures.Skill(skill, turnActions[i].GetProperty("cost").GetInt32(), turnActions[i].GetProperty("recharge").GetInt32(), unstoppable.Contains(skill.Game!.Value), skillTypes: types));
        }

        foreach (int forced in new[] { 11, 13, 15, 21 }.Where(id => skills.TrueForAll(skill => skill.Ref.Game != id)))
        {
            skills.Add(SimFixtures.Skill(SkillRef.OfGame(forced)));
        }

        List<RuleSpec> rules = name == "turnStart"
            ? [
                SimFixtures.Rule("start11", new TurnStartTrigger(), [SimFixtures.Use(SkillRef.OfGame(11), uninterruptible: true)]),
                SimFixtures.Rule("start13", new TurnStartTrigger(), [SimFixtures.Use(SkillRef.OfGame(13), uninterruptible: true)], [new ChanceCondition(5000)]),
            ]
            : [];
        TraitEntrySpec lastStand = new("stand", "lastStand", TraitSource.Boss, 0, [], new Dictionary<int, SkillRef>(), false, LastStand: new LastStandSpec(50, 3, 0, 1));
        TraitBlock traits = TraitBlock.Empty with
        {
            Entries = name == "ignoresTimeStop"
                ? [lastStand, new TraitEntrySpec("t1", Overdrive.IgnoresTimeStopKind, TraitSource.Boss, 1, [], new Dictionary<int, SkillRef>(), false)]
                : [lastStand],
            StateRecipes = [new StateRecipe(1, StateRecipeRole.Phase, "stand", string.Empty, [], 0, StateRemoval.None, 0, 0, true, false, SkillRef.OfGame(15))],
        };
        RuntimeDesign design = SimFixtures.Design(actions, skills, rules, BaseAp(name), attackWeight: AttackWeight, traits: traits, attackCost: scenario.GetProperty("attack").GetProperty("cost").GetInt32());
        return design with
        {
            States = scenario.GetProperty("crowdControl").EnumerateArray().ToDictionary(
                state => state.GetProperty("state").GetInt32(),
                state => new RuntimeState(
                    state.GetProperty("hardCc").GetBoolean(),
                    state.GetProperty("disables").GetInt32(),
                    state.GetProperty("minTurns").GetInt32(),
                    state.GetProperty("maxTurns").GetInt32(),
                    Enum.Parse<StateRemoval>(state.GetProperty("timing").GetString()!),
                    0,
                    state.GetProperty("redirects").GetBoolean(),
                    0)),
        };
    }

    /// <summary>
    /// Gets a scenario's tier points: the mini game's tier 3 gives 6 by the game rule, the costs design sets 5.
    /// </summary>
    /// <param name="name">The scenario's name.</param>
    /// <returns>The points.</returns>
    private static int BaseAp(string name) => name == "costs" ? 5 : 6;

    /// <summary>
    /// Reads what a case sets.
    /// </summary>
    /// <param name="scenario">The scenario.</param>
    /// <param name="options">The case's options.</param>
    /// <param name="name">The scenario's name.</param>
    /// <returns>The facts.</returns>
    private static CaseFacts FactsOf(JsonElement scenario, JsonElement options, string name)
    {
        Dictionary<int, JsonElement> states = scenario.GetProperty("crowdControl").EnumerateArray().ToDictionary(state => state.GetProperty("state").GetInt32());
        List<(int Id, bool MidTurn)> landings = [.. options.GetProperty("states").EnumerateArray().Select(landing => (landing.GetProperty("state").GetInt32(), landing.GetProperty("midTurn").GetBoolean()))];
        string grapple = options.GetProperty("grapple").GetString()!;
        List<string> pools = [.. scenario.GetProperty("pools").EnumerateArray().Select(pool => pool.GetString()!)];
        int poolPlace = pools.IndexOf(grapple);
        return new CaseFacts
        {
            Frozen = options.GetProperty("overdrive").GetBoolean() && name != "ignoresTimeStop",
            PlanDisables = landings.Where(landing => !landing.MidTurn && states[landing.Id].GetProperty("hardCc").GetBoolean()).Sum(landing => states[landing.Id].GetProperty("disables").GetInt32()),
            MidTurnHardCc = landings.Count(landing => landing.MidTurn && states[landing.Id].GetProperty("hardCc").GetBoolean()),
            PlanRedirect = landings.Where(landing => !landing.MidTurn && states[landing.Id].GetProperty("redirects").GetBoolean()).Select(landing => (int?)landing.Id).FirstOrDefault(),
            GrapplePool = grapple != "None" && poolPlace >= 0,
            GrappleSkill = poolPlace >= 0 ? SkillRef.OfGame(scenario.GetProperty("turnActions")[poolPlace].GetProperty("skill").GetInt32()) : default,
        };
    }

    /// <summary>
    /// Plays a list over a long battle with cooldown rests and averages its uses per turn.
    /// </summary>
    /// <param name="candidates">The candidates.</param>
    /// <param name="ap">The points of each turn.</param>
    /// <returns>Each candidate's uses per turn.</returns>
    private static double[] PlayLong(IReadOnlyList<RollCandidate> candidates, int ap)
    {
        EnemyState enemy = new(new RuntimeEnemy(0, "00000001", 1, new EnemyStats(1, 1, 1, 1, 1, 1, 1, 1), ap));
        ArenaRandom random = new(7);
        double[] uses = new double[candidates.Count];
        for (int turn = 0; turn < Turns; turn++)
        {
            RollResult roll = ActionRoll.Roll(candidates, ap, HalfPermille, random, Cooldowns.RestingSkills(enemy));
            foreach (int pick in roll.Picks)
            {
                uses[pick]++;
                Cooldowns.Start(enemy, candidates[pick].SkillKey, candidates[pick].Cooldown);
            }

            Cooldowns.CountDown(enemy);
        }

        return [.. uses.Select(count => count / Turns)];
    }

    /// <summary>
    /// Checks a turn's picks against the roll's rules.
    /// </summary>
    /// <param name="candidates">The candidates.</param>
    /// <param name="ap">The points.</param>
    /// <param name="resting">The resting skills.</param>
    /// <param name="picks">The picks.</param>
    private static void AssertRules(IReadOnlyList<RollCandidate> candidates, int ap, IReadOnlySet<string> resting, IReadOnlyList<int> picks)
    {
        int left = ap - picks.Sum(pick => candidates[pick].Cost);
        Assert.True(left >= 0);
        Assert.All(picks, pick => Assert.True(candidates[pick].Weight > 0 && !resting.Contains(candidates[pick].SkillKey)));
        Dictionary<string, int> used = picks.GroupBy(pick => candidates[pick].SkillKey).ToDictionary(group => group.Key, group => group.Count());
        Assert.All(candidates.Where(candidate => candidate.Cooldown > 0), candidate => Assert.True(used.GetValueOrDefault(candidate.SkillKey) <= 1));
        Assert.DoesNotContain(candidates, candidate =>
            candidate.Weight > 0 && candidate.Cost <= left && !resting.Contains(candidate.SkillKey) && !(candidate.Cooldown > 0 && used.ContainsKey(candidate.SkillKey)));
    }

    /// <summary>
    /// Reads a golden list of turn actions as roll candidates.
    /// </summary>
    /// <param name="actions">The actions: weight, cost, skill and recharge.</param>
    /// <returns>The candidates.</returns>
    private static List<RollCandidate> CandidatesOf(JsonElement actions) => [.. actions.EnumerateArray().Select(action => new RollCandidate(
        action.GetProperty("skill").GetInt32().ToString(CultureInfo.InvariantCulture),
        (int)(action.GetProperty("weight").GetDouble() * ActionRoll.WeightPerRating),
        Math.Max(1, action.GetProperty("cost").GetInt32()),
        action.GetProperty("recharge").GetInt32()))];

    /// <summary>
    /// Reads a golden case's kind.
    /// </summary>
    /// <param name="entry">The case.</param>
    /// <returns>Its kind.</returns>
    private static string Kind(JsonElement entry) => entry.GetProperty("kind").GetString()!;

    /// <summary>
    /// Loads a golden fixture.
    /// </summary>
    /// <param name="name">Its file name.</param>
    /// <param name="source">This file's path, filled in by the compiler.</param>
    /// <returns>The document.</returns>
    private static JsonDocument Load(string name, [CallerFilePath] string source = "") =>
        JsonDocument.Parse(File.ReadAllBytes(Path.Combine(Path.GetDirectoryName(Path.GetDirectoryName(source))!, "Fixtures", "golden", name)));

    /// <summary>
    /// What a turnPlans case sets.
    /// </summary>
    private sealed class CaseFacts
    {
        /// <summary>
        /// Gets whether the party's Overdrive freezes the boss.
        /// </summary>
        public bool Frozen { get; init; }

        /// <summary>
        /// Gets the entries the hard crowd control states on the boss at the plan disable together.
        /// </summary>
        public int PlanDisables { get; init; }

        /// <summary>
        /// Gets the hard crowd control states that land after the plan.
        /// </summary>
        public int MidTurnHardCc { get; init; }

        /// <summary>
        /// Gets the redirecting state on the boss at the plan, or null.
        /// </summary>
        public int? PlanRedirect { get; init; }

        /// <summary>
        /// Gets whether the boss grapples with a pool that has an action.
        /// </summary>
        public bool GrapplePool { get; init; }

        /// <summary>
        /// Gets the grapple pool's skill.
        /// </summary>
        public SkillRef GrappleSkill { get; init; }

        /// <summary>
        /// Gets or sets the stoppable entries the last mid-turn landing could reach.
        /// </summary>
        public int MidTurnEligible { get; set; }
    }
}
