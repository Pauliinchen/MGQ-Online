//----------------------------------------------------------------
//  ItemText.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.RegularExpressions;

namespace MGQOnline.Game.Actors;

/// <summary>
/// An equipped item as text, the same in both games, which a build's equipment field and a trade's
/// token of an enchanted or socketed copy hold: <c>w</c> or <c>a</c> and the id for a weapon or
/// armor, <c>s</c> in front for a socket item followed by <c>.</c> and its gems, <c>e</c> in front
/// for an enchanted item followed by
/// <c>.rarity.upgrade.sockets.variance.enchantments.stat rolls.trait rolls.gems</c>; lists joined
/// by <c>+</c>, rolls in per mille and a trait roll as <c>enchantment:formula:roll:value</c>.
/// </summary>
public static partial class ItemText
{
    /// <summary>
    /// The stat rolls an enchanted item has, one per stat.
    /// </summary>
    public const int StatRollCount = 8;

    /// <summary>
    /// The trait rolls an enchanted item takes at most.
    /// </summary>
    public const int MostTraitRolls = 500;

    /// <summary>
    /// The gems an item takes at most, as many as the largest number of sockets the text can say.
    /// </summary>
    public const int MostGems = 999;

    /// <summary>
    /// A stat roll of 1, which an enchanted item without a full set of stat rolls takes for each.
    /// </summary>
    private const long WholeRoll = 1000;

    /// <summary>
    /// Writes an equipped item.
    /// </summary>
    /// <param name="item">The item, <see langword="null"/> for an empty slot.</param>
    /// <returns>The text, empty for an empty slot.</returns>
    public static string Write(BuildItem? item)
    {
        if (item is null)
        {
            return string.Empty;
        }

        string kind = item.Weapon ? "w" : "a";
        if (item.Enchant is { } enchant)
        {
            return string.Join(
                ".",
                $"e{kind}{Text(item.Id)}",
                Text(enchant.Rarity),
                Text(enchant.Plus),
                Text(enchant.Sockets),
                Text(enchant.Variance),
                Joined(enchant.Enchants),
                Joined(enchant.StatRolls),
                string.Join("+", enchant.TraitRolls.Select(roll => $"{Text(roll.Enchant)}:{Text(roll.Formula)}:{Text(roll.Variance)}:{Text(roll.Value)}")),
                Joined(item.Gems ?? []));
        }

        return item.Gems is { } gems ? $"s{kind}{Text(item.Id)}.{Joined(gems)}" : kind + Text(item.Id);
    }

    /// <summary>
    /// Reads an equipped item another game wrote.
    /// </summary>
    /// <param name="text">The text, see <see cref="Write"/>.</param>
    /// <param name="item">The item, <see langword="null"/> for an empty slot or an unreadable text.</param>
    /// <returns>Whether the text reads, an empty one included.</returns>
    public static bool TryRead(string text, out BuildItem? item)
    {
        item = null;
        if (text.Length == 0)
        {
            return true;
        }

        if (PlainPattern().Match(text) is { Success: true } plain)
        {
            item = new BuildItem(plain.Groups[1].Value == "w", long.Parse(plain.Groups[2].Value, CultureInfo.InvariantCulture), null, null);
        }
        else if (SocketPattern().Match(text) is { Success: true } socket)
        {
            item = new BuildItem(socket.Groups[1].Value == "w", long.Parse(socket.Groups[2].Value, CultureInfo.InvariantCulture), Gems(socket.Groups[3].Value), null);
        }
        else if (EnchantedPattern().Match(text) is { Success: true } enchanted)
        {
            item = Enchanted(enchanted.Groups);
        }

        return item is not null;
    }

    /// <summary>
    /// Reads the parts of an enchanted item.
    /// </summary>
    /// <param name="parts">The groups of <see cref="EnchantedPattern"/>.</param>
    /// <returns>The item.</returns>
    private static BuildItem Enchanted(GroupCollection parts)
    {
        List<long> statRolls = [.. BuildText.Split(parts[8].Value, '+').Select(BuildText.ToI)];
        var traitRolls = new List<TraitRoll>();
        foreach (string entry in BuildText.Split(parts[9].Value, '+').Take(MostTraitRolls))
        {
            List<long> numbers = [.. BuildText.Split(entry, ':').Select(BuildText.ToI)];
            if (numbers.Count >= 4)
            {
                traitRolls.Add(new TraitRoll(numbers[0], numbers[1], numbers[2], numbers[3]));
            }
        }

        var enchant = new ItemEnchant(
            BuildText.ToI(parts[3].Value),
            BuildText.ToI(parts[4].Value),
            BuildText.ToI(parts[5].Value),
            BuildText.ToI(parts[6].Value),
            [.. BuildText.Split(parts[7].Value, '+').Select(BuildText.ToI)],
            statRolls.Count == StatRollCount ? statRolls : [.. Enumerable.Repeat(WholeRoll, StatRollCount)],
            traitRolls);
        return new BuildItem(parts[1].Value == "w", BuildText.ToI(parts[2].Value), Gems(parts[10].Value), enchant);
    }

    /// <summary>
    /// Reads the gems of an item.
    /// </summary>
    /// <param name="text">Item ids joined by <c>+</c>, 0 for an empty socket.</param>
    /// <returns>The gems' item ids, at most <see cref="MostGems"/>.</returns>
    private static List<long> Gems(string text) => [.. BuildText.Split(text, '+').Take(MostGems).Select(BuildText.ToI)];

    /// <summary>
    /// Joins numbers by <c>+</c>.
    /// </summary>
    /// <param name="numbers">The numbers.</param>
    /// <returns>The text.</returns>
    private static string Joined(IEnumerable<long> numbers) => string.Join("+", numbers.Select(Text));

    /// <summary>
    /// Writes a number.
    /// </summary>
    /// <param name="number">The number.</param>
    /// <returns>Its digits.</returns>
    private static string Text(long number) => number.ToString(CultureInfo.InvariantCulture);

    /// <summary>
    /// A weapon or armor of the database.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex("\\A([wa])([0-9]{1,6})\\z", RegexOptions.CultureInvariant)]
    private static partial Regex PlainPattern();

    /// <summary>
    /// A socket item and its gems.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex("\\As([wa])([0-9]{1,6})\\.([0-9+]*)\\z", RegexOptions.CultureInvariant)]
    private static partial Regex SocketPattern();

    /// <summary>
    /// An enchanted item and its rolls.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex("\\Ae([wa])([0-9]{1,6})\\.([0-9]{1,6})\\.([0-9]{1,4})\\.([0-9]{1,3})\\.([0-9]{1,6})\\.([0-9+]*)\\.([0-9+]*)\\.([-0-9:+]*)\\.([0-9+]*)\\z", RegexOptions.CultureInvariant)]
    private static partial Regex EnchantedPattern();
}
