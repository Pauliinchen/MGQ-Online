//----------------------------------------------------------------
//  PvpBalanceTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Created
//
//----------------------------------------------------------------

using System;
using System.Globalization;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Tests.Duels;

/// <summary>
/// Covers the balance of a PvP battle as the host's battle asks it: one action's hits on a
/// character with four times its HP, a defense wall, and the automatic skills by speed.
/// </summary>
public sealed class PvpBalanceTests
{
    /// <summary>
    /// The balanced max HP of the character hit: 7,500 four times.
    /// </summary>
    private const long MaxHp = 30_000;

    /// <summary>
    /// The context the topics answer on.
    /// </summary>
    private readonly TopicContext _topics = new();

    /// <summary>
    /// Registers the topics with fixed randomness.
    /// </summary>
    public PvpBalanceTests()
    {
        PvpTopics.Register(_topics.Context, new Random(7));
    }

    /// <summary>
    /// Asserts that an action's hits count in full up to a fifth of max HP, then ever less, and
    /// together stay below three fifths of it, however many hits of millions of times the HP.
    /// </summary>
    [Fact]
    public void Hit_OneActionStaysBelowTheLimit()
    {
        Assert.Equal(4, _topics.Value(PvpTopics.Rules).AsHash()["hp_rate"].AsInt());
        Assert.Equal(3000, Hit(0, 3000), 6);
        Assert.Equal(10_937, Math.Round(Hit(0, MaxHp)));

        double dealt = 0;
        double taken = 0;
        foreach (double hit in Enumerable.Repeat(52_000_000_000_000.0 * 4, 5))
        {
            dealt += Hit(taken, hit);
            taken += hit;
        }

        Assert.InRange(dealt, 16_000, 18_000);
    }

    /// <summary>
    /// Asserts that a defense wall takes a quarter of max HP off a hit, and a smaller hit away.
    /// </summary>
    [Fact]
    public void Wall_TakesAQuarterOfMaxHp()
    {
        Assert.Equal(82_500, Wall(90_000));
        Assert.Equal(0, Wall(7000));
    }

    /// <summary>
    /// Asserts that the automatic skills fire by their characters' speed, the faster character's
    /// first whichever team queued them, each character's in its own order.
    /// </summary>
    [Fact]
    public void BySpeed_FasterCharacterFiresFirst()
    {
        var queue = new RubyArray
        {
            new RubyArray { 1, 10 }, new RubyArray { 1, 10 }, new RubyArray { 2, 500 },
        };

        RubyArray places = _topics.Value(PvpTopics.BySpeed, queue).AsArray();

        Assert.Equal([2, 0, 1], places.Select(place => place.AsInt()));
    }

    /// <summary>
    /// Asks what a hit on the character deals.
    /// </summary>
    /// <param name="before">What the action dealt the character before.</param>
    /// <param name="value">The hit as the game works it out.</param>
    /// <returns>What it deals in the battle.</returns>
    private double Hit(double before, double value) => double.Parse(
        _topics.Value(PvpTopics.Hit, new RubyHash { { "max_hp", MaxHp }, { "before", Text(before) }, { "value", Text(value) } }).AsText(),
        CultureInfo.InvariantCulture);

    /// <summary>
    /// Asks what gets through the character's defense wall.
    /// </summary>
    /// <param name="damage">The hit before the wall.</param>
    /// <returns>What gets through.</returns>
    private double Wall(double damage) => double.Parse(
        _topics.Value(PvpTopics.Wall, new RubyHash { { "max_hp", MaxHp }, { "damage", Text(damage) } }).AsText(),
        CultureInfo.InvariantCulture);

    /// <summary>
    /// Writes a number as the scripts write a Float.
    /// </summary>
    /// <param name="number">The number.</param>
    /// <returns>The text.</returns>
    private static string Text(double number) => number.ToString("R", CultureInfo.InvariantCulture);
}
