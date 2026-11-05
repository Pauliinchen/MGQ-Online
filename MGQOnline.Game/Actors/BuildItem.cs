//----------------------------------------------------------------
//  BuildItem.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.Actors;

/// <summary>
/// An equipped item of a character's build, which another game remakes from its own data: a
/// weapon or armor of the database, a socket item and its gems, or an enchanted item and its rolls.
/// </summary>
/// <remarks>
/// Socket and enchanted items are one of a kind, so the receiver makes its own copy, the way the
/// game remakes an enchanted item's traits from its rolls when a save loads.
/// </remarks>
/// <param name="Weapon">Whether the item is a weapon rather than an armor.</param>
/// <param name="Id">The id of the item, of the one it is made of for a socket or enchanted item.</param>
/// <param name="Gems">The gems' item ids, 0 for an empty socket; <see langword="null"/> for an item of the database.</param>
/// <param name="Enchant">The rolls of an enchanted item, <see langword="null"/> for any other.</param>
public sealed record BuildItem(bool Weapon, long Id, IReadOnlyList<long>? Gems, ItemEnchant? Enchant);

/// <summary>
/// The rolls of an enchanted item.
/// </summary>
/// <param name="Rarity">Its rarity.</param>
/// <param name="Plus">Its upgrade.</param>
/// <param name="Sockets">Its sockets.</param>
/// <param name="Variance">The base of its variance.</param>
/// <param name="Enchants">Its enchantments' ids.</param>
/// <param name="StatRolls">Its roll per stat in per mille.</param>
/// <param name="TraitRolls">Its trait rolls.</param>
public sealed record ItemEnchant(long Rarity, long Plus, long Sockets, long Variance, IReadOnlyList<long> Enchants, IReadOnlyList<long> StatRolls, IReadOnlyList<TraitRoll> TraitRolls);

/// <summary>
/// A trait roll of an enchanted item.
/// </summary>
/// <param name="Enchant">The enchantment's id.</param>
/// <param name="Formula">The formula's id within the enchantment.</param>
/// <param name="Variance">The roll's id within the formula.</param>
/// <param name="Value">The roll in per mille.</param>
public sealed record TraitRoll(long Enchant, long Formula, long Variance, long Value);
