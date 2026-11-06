//----------------------------------------------------------------
//  PvpTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Created
//
//----------------------------------------------------------------

using System;
using System.Globalization;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Duels;

namespace MGQOnline.Game.Topics;

/// <summary>
/// The bridge topics of a PvP battle's balance and turn order, see <see cref="PvpBalance"/>, which
/// the host's battle asks. Shares and damage cross as decimal texts, since no Float crosses the bridge.
/// </summary>
public static class PvpTopics
{
    /// <summary>
    /// Tells the balance's values the stat hooks apply many times a frame: nothing in;
    /// <c>hp_rate</c>, <c>monster_formulas</c>, <c>avoid_ceiling</c>, <c>element_floor</c> and
    /// <c>taken_floor</c> out.
    /// </summary>
    public const string Rules = "pvp.rules";

    /// <summary>
    /// Works out what a hit deals or heals, see <see cref="PvpBalance.Hit"/>: <c>max_hp</c>,
    /// <c>before</c> and <c>value</c> in; what it deals or heals out, without its sign.
    /// </summary>
    public const string Hit = "pvp.hit";

    /// <summary>
    /// Works out what gets through a defense wall, see <see cref="PvpBalance.Wall"/>: <c>max_hp</c>
    /// and <c>damage</c> in; what gets through out.
    /// </summary>
    public const string Wall = "pvp.wall";

    /// <summary>
    /// Orders queued automatic skills by speed, see <see cref="PvpBalance.BySpeed"/>: [key, agility]
    /// of each skill's character in; the skills' places out.
    /// </summary>
    public const string BySpeed = "pvp.by_speed";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="random">The context's randomness, which rolls the speeds.</param>
    public static void Register(BridgeContext context, Random random)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(random);
        context.Register(Rules, (_, _) => new RubyHash
        {
            { "hp_rate", PvpBalance.HpRate },
            { "monster_formulas", PvpBalance.MonsterFormulas },
            { "avoid_ceiling", Text(PvpBalance.AvoidCeiling) },
            { "element_floor", Text(PvpBalance.ElementFloor) },
            { "taken_floor", Text(PvpBalance.DamageRateFloor) },
        });
        context.Register(Hit, (_, request) =>
        {
            RubyHash hit = request.AsHash();
            return Text(PvpBalance.Hit(hit["max_hp"].AsLong(), Number(hit["before"]), Number(hit["value"])));
        });
        context.Register(Wall, (_, request) =>
        {
            RubyHash wall = request.AsHash();
            return Text(PvpBalance.Wall(wall["max_hp"].AsLong(), Number(wall["damage"])));
        });
        context.Register(BySpeed, (_, request) =>
        {
            var owners = request.AsArray().Select(owner => (owner.AsArray()[0].AsLong(), owner.AsArray()[1].AsLong())).ToList();
            return new RubyArray(PvpBalance.BySpeed(owners, random).Select(place => (RubyValue)place));
        });
    }

    /// <summary>
    /// Reads a number the scripts wrote as text.
    /// </summary>
    /// <param name="value">The text.</param>
    /// <returns>The number.</returns>
    private static double Number(RubyValue value) => double.Parse(value.AsText(), NumberStyles.Float, CultureInfo.InvariantCulture);

    /// <summary>
    /// Writes a number as text the scripts read back exactly.
    /// </summary>
    /// <param name="number">The number.</param>
    /// <returns>The text.</returns>
    private static string Text(double number) => number.ToString("R", CultureInfo.InvariantCulture);
}
