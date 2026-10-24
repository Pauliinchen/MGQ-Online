//----------------------------------------------------------------
//  MarkScenarioTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Played the Stigmata as battle and skill rows of the Trigger -> Effect framework
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Engine;
using MGQOnline.Arena.Events;
using MGQOnline.Arena.Model;
using static MGQOnline.Arena.Tests.Engine.EngineSamples;

namespace MGQOnline.Arena.Tests.Engine;

/// <summary>
/// Plays the Stigmata rows over several turns with a minimal planner: a scheduled light Stigmata on
/// turn 2 + 3·X with a dark follow-up on the other half, light and dark marks until the next scheduled
/// cast, and a reaction to each mark hit by the other.
/// </summary>
public sealed class MarkScenarioTests
{
    /// <summary>
    /// The seats on the left half.
    /// </summary>
    private static readonly int[] LeftSeats = [0, 1];

    /// <summary>
    /// The seats on the right half.
    /// </summary>
    private static readonly int[] RightSeats = [2, 3];

    /// <summary>
    /// The battle.
    /// </summary>
    private readonly FakeRuleContext _context = new();

    /// <summary>
    /// The engine over the rows.
    /// </summary>
    private readonly RuleEngine _engine = EngineOf(
        Rule(
            StigmataAction,
            new TurnTrigger(2, 3),
            [Use(LightStigmata, uninterruptible: true, side: CastSide.Alternate, caster: FakeRuleContext.SlotOfIndex(0))],
            owner: RuleOwner.Battle),
        FollowUp,
        Leaves(LightStigmata, Light),
        Leaves(DarkStigmata, Dark),
        Reaction("lightHitByDark", Light, DarkStigmata, 10),
        Reaction("darkHitByLight", Dark, LightStigmata, 20));

    /// <summary>
    /// The casts planned so far.
    /// </summary>
    private readonly List<(string CastId, SkillRef Skill, GridHalf Side)> _casts = [];

    /// <summary>
    /// The half the next alternating cast takes.
    /// </summary>
    private GridHalf _nextAlternate = GridHalf.Left;

    /// <summary>
    /// Initializes the planner the battle answers casts with.
    /// </summary>
    public MarkScenarioTests() => _context.Plan = PlanCast;

    /// <summary>
    /// Casts on turns 2 and 5 only, the follow-up on the other half each time.
    /// </summary>
    [Fact]
    public void CastsOnTheScheduleWithTheFollowUpOpposite()
    {
        PlayTurns(dodge: false);

        Assert.Equal(
            [("c1", LightStigmata, GridHalf.Left), ("c2", DarkStigmata, GridHalf.Right), ("c3", LightStigmata, GridHalf.Right), ("c4", DarkStigmata, GridHalf.Left)],
            _casts);
        Assert.All(_context.Orders, order => Assert.True(order.Free));
        Assert.True(_context.Orders[0].Uninterruptible);
    }

    /// <summary>
    /// Fires each unit's reaction exactly once on turn 5, removes the old mark and lands the new one.
    /// </summary>
    [Fact]
    public void ReactsOncePerMarkedUnitAndSwapsTheMarks()
    {
        PlayTurns(dodge: false);

        RuleFiredEvent[] reactions = _context.LoggedOf<RuleFiredEvent>().Where(fired => fired.RuleId.Contains("HitBy")).ToArray();
        Assert.Equal(4, reactions.Length);
        Assert.All(reactions, fired => Assert.Equal(5, fired.Turn));
        Assert.All(LeftSeats, seat => Assert.Equal(900, _context.HpOf(StateHolder.Unit, seat)));
        Assert.All(RightSeats, seat => Assert.Equal(800, _context.HpOf(StateHolder.Unit, seat)));
        Assert.All(LeftSeats, seat => Assert.Equal((false, new MarkClock(6, StigmataAction, "c4")), (_context.UnitHolds(seat, Light), _context.StateOf(StateHolder.Unit, seat, Dark)?.Clock)));
        Assert.All(RightSeats, seat => Assert.Equal((false, new MarkClock(6, StigmataAction, "c3")), (_context.UnitHolds(seat, Dark), _context.StateOf(StateHolder.Unit, seat, Light)?.Clock)));
    }

    /// <summary>
    /// Fires no reaction when every unit dodges turn 5, and the old marks end with the cast.
    /// </summary>
    [Fact]
    public void FiresNothingWhenEveryoneDodges()
    {
        PlayTurns(dodge: true);

        Assert.DoesNotContain(_context.LoggedOf<RuleFiredEvent>(), fired => fired.RuleId.Contains("HitBy"));
        Assert.All(_context.Seats, seat => Assert.Equal(1000, _context.HpOf(StateHolder.Unit, seat)));
        Assert.All(_context.Seats, seat => Assert.Empty(_context.StatesOf(StateHolder.Unit, seat)));
    }

    /// <summary>
    /// Plays turns 1 to 5: the plan, the resolve of every cast, the action's end and the turn end.
    /// </summary>
    /// <param name="dodge">Whether every unit leaves the telegraphed cells on turn 5.</param>
    private void PlayTurns(bool dodge)
    {
        for (int turn = 1; turn <= 5; turn++)
        {
            int planned = _casts.Count;
            _engine.Raise(_context, new TurnScheduleEvent(turn, 0));
            List<string> castIds = [];
            foreach ((string castId, SkillRef skill, GridHalf side) in _casts.Skip(planned))
            {
                castIds.Add(castId);
                int mark = skill == LightStigmata ? Light : Dark;
                foreach (int seat in dodge && turn == 5 ? [] : side == GridHalf.Left ? LeftSeats : RightSeats)
                {
                    _engine.Raise(_context, HitIn(_context, turn, castId, skill, mark, seat));
                }
            }

            if (castIds.Count > 0)
            {
                MarkLifecycle.ActionEnded(_context, turn, StigmataAction, castIds);
            }

            MarkLifecycle.TurnEnded(_context, turn);
            _engine.Raise(_context, new TurnEndEvent(turn));
        }
    }

    /// <summary>
    /// Plans a cast now: an alternating half flips per cast, a fixed half is kept.
    /// </summary>
    /// <param name="order">The cast.</param>
    /// <returns>Its after-cast event.</returns>
    private AfterCastEvent PlanCast(CastOrder order)
    {
        GridHalf side = order.FixedSide ?? _nextAlternate;
        if (order.FixedSide is null)
        {
            _nextAlternate = side == GridHalf.Left ? GridHalf.Right : GridHalf.Left;
        }

        string castId = "c" + (_casts.Count + 1);
        _casts.Add((castId, order.Skill, side));
        _context.Sides[castId] = side;
        int turn = _context.Logged.OfType<RuleFiredEvent>().Last().Turn;
        return new AfterCastEvent(turn, castId, order.Enemy, order.Skill, order.Kind, order.ActionId, order.RootActionId, side);
    }
}
