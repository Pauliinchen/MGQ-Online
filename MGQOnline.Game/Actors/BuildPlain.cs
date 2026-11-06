//----------------------------------------------------------------
//  BuildPlain.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Dropped the hero of a replaced Luka
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Battles.Wire;

namespace MGQOnline.Game.Actors;

/// <summary>
/// A build's facts as the bridge carries them between the scripts and C#: a Hash of a character's
/// facts by name, the same both ways; a Float and an item's entry of the database tagged as a
/// battle line's values are (<see cref="WirePlain"/>), such as <c>{"float" => "0.95"}</c> and
/// <c>{"weapon" => 12}</c>.
/// </summary>
/// <remarks>
/// The scripts hand the game's own values, a rate or a roll as the Float the game keeps; the per
/// mille the text holds is the text's own.
/// </remarks>
public static class BuildPlain
{
    /// <summary>
    /// The highest number taken as a rate or roll, far above any the game has, so its per mille fits.
    /// </summary>
    private const double MostReal = 1e12;

    /// <summary>
    /// A per mille's part of 1.
    /// </summary>
    private const double PerMille = 1000.0;

    /// <summary>
    /// Takes a character's facts the scripts handed over.
    /// </summary>
    /// <param name="facts">A Hash: "actor", "level", "class", "tribe", "levels" ([id, level]
    /// pairs), "param_plus", "skills", "abilities" and "equip_abilities" ([skill type, ids] pairs),
    /// "equips" (see <see cref="ItemOf"/>), "params", "rates" (Floats), "counters" and
    /// "switches".</param>
    /// <returns>The build.</returns>
    /// <exception cref="BridgeRequestException">A fact is of another kind.</exception>
    public static ActorBuild BuildOf(RubyValue facts)
    {
        ArgumentNullException.ThrowIfNull(facts);
        RubyHash hash = facts.AsHash();
        return new ActorBuild(
            Whole(hash["actor"]),
            Whole(hash["level"]),
            hash["class"].IsNil ? null : Whole(hash["class"]),
            hash["tribe"].IsNil ? null : Whole(hash["tribe"]),
            [.. List(hash["levels"]).Select(pair => (Whole(pair.AsArray()[0]), Whole(pair.AsArray()[1])))],
            Wholes(hash["param_plus"]),
            Wholes(hash["skills"]),
            Groups(hash["abilities"]),
            Groups(hash["equip_abilities"]),
            [.. List(hash["equips"]).Select(ItemOf)],
            Wholes(hash["params"]),
            [.. List(hash["rates"]).Select(rate => PerMilleOf(Real(rate)))],
            Wholes(hash["counters"]),
            Wholes(hash["switches"]));
    }

    /// <summary>
    /// Gives a build as the scripts take it.
    /// </summary>
    /// <param name="build">The build.</param>
    /// <returns>The facts, see <see cref="BuildOf"/>.</returns>
    public static RubyHash ToPlain(ActorBuild build)
    {
        ArgumentNullException.ThrowIfNull(build);
        return new RubyHash
        {
            { "actor", build.ActorId },
            { "level", build.BaseLevel },
            { "class", build.ClassId is { } classId ? classId : RubyNil.Value },
            { "tribe", build.TribeId is { } tribeId ? tribeId : RubyNil.Value },
            { "levels", new RubyArray(build.Levels.Select(level => (RubyValue)new RubyArray { level.Id, level.Level })) },
            { "param_plus", Plain(build.ParamPlus) },
            { "skills", Plain(build.Skills) },
            { "abilities", Plain(build.Abilities) },
            { "equip_abilities", Plain(build.EquipAbilities) },
            { "equips", new RubyArray(build.Equips.Select(ToPlain)) },
            { "params", Plain(build.Params) },
            { "rates", new RubyArray(build.Rates.Select(FloatOf)) },
            { "counters", Plain(build.Counters) },
            { "switches", Plain(build.SwitchesOn) },
        };
    }

    /// <summary>
    /// Takes an equipped item's facts the scripts handed over.
    /// </summary>
    /// <param name="facts">nil for an empty slot, else a Hash: "base", the item's entry of the
    /// database, the weapon or armor a socket or enchanted item is made of; "gems" for a socket
    /// or enchanted item, its gems' item ids, nil or 0 for an empty socket; and "enchant" for an
    /// enchanted item: "rarity", "plus", "sockets", "variance", "enchants", "stats" (a Float per
    /// stat) and "traits" ([enchantment, formula, roll, Float] lists).</param>
    /// <returns>The item, <see langword="null"/> for an empty slot.</returns>
    /// <exception cref="BridgeRequestException">A fact is of another kind.</exception>
    public static BuildItem? ItemOf(RubyValue facts)
    {
        ArgumentNullException.ThrowIfNull(facts);
        if (facts.IsNil)
        {
            return null;
        }

        RubyHash hash = facts.AsHash();
        if (WirePlain.Of(hash["base"]) is not WireDatabaseItem { Table: WireTable.Weapons or WireTable.Armors } entry)
        {
            throw new BridgeRequestException($"An equipped item is made of {hash["base"]}, no weapon or armor.");
        }

        IReadOnlyList<long>? gems = hash["gems"].IsNil ? null : Wholes(hash["gems"]);
        RubyValue enchanted = hash["enchant"];
        ItemEnchant? enchant = enchanted.IsNil ? null : new ItemEnchant(
            Whole(enchanted.AsHash()["rarity"]),
            Whole(enchanted.AsHash()["plus"]),
            Whole(enchanted.AsHash()["sockets"]),
            Whole(enchanted.AsHash()["variance"]),
            Wholes(enchanted.AsHash()["enchants"]),
            [.. List(enchanted.AsHash()["stats"]).Select(roll => PerMilleOf(Real(roll)))],
            [.. List(enchanted.AsHash()["traits"]).Select(Trait)]);
        return new BuildItem(entry.Table == WireTable.Weapons, entry.Id, gems ?? (enchant is null ? null : []), enchant);
    }

    /// <summary>
    /// Gives an equipped item as the scripts take it.
    /// </summary>
    /// <param name="item">The item, <see langword="null"/> for an empty slot.</param>
    /// <returns>The facts, see <see cref="ItemOf"/>.</returns>
    public static RubyValue ToPlain(BuildItem? item)
    {
        if (item is null)
        {
            return RubyNil.Value;
        }

        var facts = new RubyHash { { "base", WirePlain.ToPlain(new WireDatabaseItem(item.Weapon ? WireTable.Weapons : WireTable.Armors, (int)Math.Clamp(item.Id, int.MinValue, int.MaxValue))) } };
        if (item.Gems is { } gems)
        {
            facts.Add("gems", Plain(gems));
        }

        if (item.Enchant is { } enchant)
        {
            facts.Add("enchant", new RubyHash
            {
                { "rarity", enchant.Rarity },
                { "plus", enchant.Plus },
                { "sockets", enchant.Sockets },
                { "variance", enchant.Variance },
                { "enchants", Plain(enchant.Enchants) },
                { "stats", new RubyArray(enchant.StatRolls.Select(FloatOf)) },
                { "traits", new RubyArray(enchant.TraitRolls.Select(roll => (RubyValue)new RubyArray { roll.Enchant, roll.Formula, roll.Variance, FloatOf(roll.Value) })) },
            });
        }

        return facts;
    }

    /// <summary>
    /// Takes a trait roll the scripts handed over.
    /// </summary>
    /// <param name="roll">[enchantment, formula, roll, Float].</param>
    /// <returns>The roll.</returns>
    private static TraitRoll Trait(RubyValue roll)
    {
        RubyArray parts = roll.AsArray();
        return parts.Count == 4
            ? new TraitRoll(Whole(parts[0]), Whole(parts[1]), Whole(parts[2]), PerMilleOf(Real(parts[3])))
            : throw new BridgeRequestException($"A trait roll is {roll}.");
    }

    /// <summary>
    /// Takes ability ids by skill type, leaving out the nils the game's tables hold.
    /// </summary>
    /// <param name="groups">[skill type, ids] pairs.</param>
    /// <returns>The groups.</returns>
    private static List<(long SkillType, IReadOnlyList<long> Ids)> Groups(RubyValue groups) =>
        [.. List(groups).Select(group => (Whole(group.AsArray()[0]), (IReadOnlyList<long>)[.. List(group.AsArray()[1]).Where(id => !id.IsNil).Select(Whole)]))];

    /// <summary>
    /// Takes a list, none for nil.
    /// </summary>
    /// <param name="value">An Array or nil.</param>
    /// <returns>The list's values.</returns>
    private static IEnumerable<RubyValue> List(RubyValue value) => value.IsNil ? [] : value.AsArray();

    /// <summary>
    /// Takes whole numbers as Ruby's <c>to_i</c> makes them.
    /// </summary>
    /// <param name="value">An Array of numbers, nil among them, or nil.</param>
    /// <returns>The numbers.</returns>
    private static List<long> Wholes(RubyValue value) => [.. List(value).Select(Whole)];

    /// <summary>
    /// Takes a whole number as Ruby's <c>to_i</c> makes it: nil as 0, a Float cut to its whole part.
    /// </summary>
    /// <param name="value">nil, an Integer or a Float.</param>
    /// <returns>The number.</returns>
    /// <exception cref="BridgeRequestException">The value is no number, or none of 64 bits.</exception>
    private static long Whole(RubyValue value) => WirePlain.Of(value) switch
    {
        WireNil => 0,
        WireInteger { Value: var number } when number >= long.MinValue && number <= long.MaxValue => (long)number,
        WireFloat { Value: var number } when Math.Abs(number) < MostReal => (long)Math.Truncate(number),
        _ => throw new BridgeRequestException($"{value} is no whole number of a build."),
    };

    /// <summary>
    /// Takes a number that may have a fraction.
    /// </summary>
    /// <param name="value">An Integer or a Float.</param>
    /// <returns>The number.</returns>
    /// <exception cref="BridgeRequestException">The value is no number.</exception>
    private static double Real(RubyValue value) => WirePlain.Of(value) switch
    {
        WireInteger { Value: var number } => (double)number,
        WireFloat { Value: var number } => number,
        _ => throw new BridgeRequestException($"{value} is no number of a build."),
    };

    /// <summary>
    /// Writes a number in per mille, rounded half away from zero as Ruby's <c>round</c> does.
    /// </summary>
    /// <param name="number">The number.</param>
    /// <returns>Its per mille.</returns>
    /// <exception cref="BridgeRequestException">The number is no finite one of the game's.</exception>
    private static long PerMilleOf(double number) =>
        double.IsFinite(number) && Math.Abs(number) < MostReal
            ? (long)Math.Round(number * PerMille, MidpointRounding.AwayFromZero)
            : throw new BridgeRequestException($"The rate or roll {number} is out of range.");

    /// <summary>
    /// Gives a per mille as the Float the scripts take.
    /// </summary>
    /// <param name="perMille">The per mille.</param>
    /// <returns>A Float, tagged.</returns>
    private static RubyValue FloatOf(long perMille) => WirePlain.ToPlain(new WireFloat(perMille / PerMille));

    /// <summary>
    /// Gives whole numbers as the scripts take them.
    /// </summary>
    /// <param name="numbers">The numbers.</param>
    /// <returns>An Array of Integers.</returns>
    private static RubyArray Plain(IEnumerable<long> numbers) => new(numbers.Select(number => (RubyValue)number));

    /// <summary>
    /// Gives ability ids by skill type as the scripts take them.
    /// </summary>
    /// <param name="groups">The groups.</param>
    /// <returns>[skill type, ids] pairs.</returns>
    private static RubyArray Plain(IEnumerable<(long SkillType, IReadOnlyList<long> Ids)> groups) =>
        new(groups.Select(group => (RubyValue)new RubyArray { group.SkillType, Plain(group.Ids) }));
}
