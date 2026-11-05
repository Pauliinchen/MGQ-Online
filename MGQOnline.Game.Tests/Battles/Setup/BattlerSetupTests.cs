//----------------------------------------------------------------
//  BattlerSetupTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Battles.Setup;

/// <summary>
/// Covers the plan of the battlers the scripts build through its topic, as battles_battlers.rbx
/// asks it: the HP, start, hiding and death that make each whole.
/// </summary>
public sealed class BattlerSetupTests
{
    /// <summary>
    /// The context the topic answers on.
    /// </summary>
    private readonly TopicContext _topics = new();

    /// <summary>
    /// Registers the topic.
    /// </summary>
    public BattlerSetupTests()
    {
        BattlerTopics.Register(_topics.Context);
    }

    /// <summary>
    /// Asserts that another player's character comes with the HP and MP its owner sent and gets the
    /// game's start even before this game's start ran, so the states a trait gives at low HP come
    /// (issue #31).
    /// </summary>
    [Fact]
    public void Ally_WithHpSent_StartsAtThatHp()
    {
        RubyHash plan = Plan("ally", started: false, vitals: [30L, 5L]);

        Assert.Equal((30L, 5L), (plan["hp"].AsLong(), plan["mp"].AsLong()));
        Assert.True(Flag(plan, "start"));
    }

    /// <summary>
    /// Asserts that an enemy the host hides comes hidden and one that fell there comes fallen
    /// (issue #47).
    /// </summary>
    [Fact]
    public void Enemy_TakesTheHostsMark()
    {
        RubyHash hidden = Plan("enemy", started: true, mark: 1);
        RubyHash fallen = Plan("enemy", started: true, mark: 2);

        Assert.Equal((true, false), (Flag(hidden, "hide"), Flag(hidden, "lay_down")));
        Assert.Equal((false, true), (Flag(fallen, "hide"), Flag(fallen, "lay_down")));
    }

    /// <summary>
    /// Asserts that an enemy built before this game's battle start ran is left to that start, which
    /// would otherwise start it a second time.
    /// </summary>
    [Fact]
    public void Enemy_BeforeTheGamesStart_IsNotStarted()
    {
        Assert.False(Flag(Plan("enemy", started: false), "start"));
    }

    /// <summary>
    /// Asserts that the other side's Backline in a PvP battle is started, since the game's start of
    /// the troop reaches only its Frontline.
    /// </summary>
    [Fact]
    public void Reserve_IsAlwaysStarted()
    {
        Assert.True(Flag(Plan("reserve", started: false), "start"));
    }

    /// <summary>
    /// Asks the topic for a battler's plan.
    /// </summary>
    /// <param name="kind">The battler's kind.</param>
    /// <param name="started">Whether the game's battle start already ran.</param>
    /// <param name="vitals">The HP and MP an owner sent, <see langword="null"/> for none.</param>
    /// <param name="mark">An enemy's mark.</param>
    /// <returns>The plan.</returns>
    private RubyHash Plan(string kind, bool started, RubyValue[]? vitals = null, long mark = 0) =>
        _topics.Value(BattlerTopics.PlanTopic, new RubyHash
        {
            { "kind", kind },
            { "started", started },
            { "vitals", vitals is null ? RubyNil.Value : new RubyArray(vitals) },
            { "mark", mark },
        }).AsHash();

    /// <summary>
    /// Reads a yes or no of a plan.
    /// </summary>
    /// <param name="plan">The plan.</param>
    /// <param name="part">The part.</param>
    /// <returns>Whether the part is true.</returns>
    private static bool Flag(RubyHash plan, string part) => plan[part] is RubyBool { Flag: true };
}
