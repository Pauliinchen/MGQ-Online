//----------------------------------------------------------------
//  TradeLimits.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Trade;

/// <summary>
/// An item of an offer as the player's game reads it, which the room checks of a trade take.
/// </summary>
/// <param name="Facts">What the player's game tells of it, <see langword="null"/> for an item it does not know.</param>
/// <param name="Amount">How many the offer moves.</param>
/// <param name="Held">How many the player's bag holds.</param>
/// <param name="Given">How many of it the player's own offer gives away.</param>
/// <param name="Room">How many more copies of its kind the party can take, <see langword="null"/>
/// when the game keeps no count of copies.</param>
/// <param name="CopiesGiven">How many copies of its kind the player's own offer gives away.</param>
/// <param name="Name">Its name in the player's game.</param>
public sealed record TradeEntry(TradeItemFacts? Facts, long Amount, long Held, long Given, long? Room, long CopiesGiven, string Name);

/// <summary>
/// What the game tells of an item for a trade.
/// </summary>
/// <param name="Kind">"item", "weapon", "armor" or another kind of thing.</param>
/// <param name="Key">Whether it is a key item.</param>
/// <param name="Stone">Whether it is an enchant stone.</param>
/// <param name="Unique">Whether it is an enchanted or socketed copy, which only one game has.</param>
public sealed record TradeItemFacts(string Kind, bool Key, bool Stone, bool Unique);

/// <summary>
/// The rules of the items a trade moves, which trade.rbx and the trade screen apply: which items
/// may be traded, how many of one an offer holds, and whether the player's game can take the
/// other player's offer.
/// </summary>
public static class TradeLimits
{
    /// <summary>
    /// The kinds of things a trade moves.
    /// </summary>
    private static readonly string[] Kinds = ["item", "weapon", "armor"];

    /// <summary>
    /// Reports whether an item may be traded: items, equipment and enchant stones, but no key items.
    /// </summary>
    /// <param name="item">What the game tells of the item.</param>
    /// <returns>Whether it may.</returns>
    public static bool Tradeable(TradeItemFacts item)
    {
        ArgumentNullException.ThrowIfNull(item);
        return Kinds.Contains(item.Kind) && !(item.Kind == "item" && item.Key && !item.Stone);
    }

    /// <summary>
    /// Works out how many of an item an offer holds when the player wants a number of them: what
    /// the bag holds, at most <see cref="TradeOffers.MaxAmount"/>, and one of a unique copy.
    /// </summary>
    /// <param name="wanted">How many the player wants to offer.</param>
    /// <param name="held">How many the bag holds.</param>
    /// <param name="unique">Whether the item is a unique copy.</param>
    /// <returns>How many, and why not as many as wanted; <see langword="null"/> when as many.</returns>
    public static (long Amount, string? Why) Amount(long wanted, long held, bool unique)
    {
        long most = unique ? 1 : TradeOffers.MaxAmount;
        if (wanted <= 0)
        {
            return (0, null);
        }

        if (wanted > most && most <= held)
        {
            return (most, unique ? "a unique copy goes once" : $"a trade moves at most {TradeOffers.MaxAmount}");
        }

        return wanted > held ? (Math.Max(held, 0), $"the bag holds {held}") : (wanted, null);
    }

    /// <summary>
    /// Tells why the player's game cannot take the other player's offer, counting what the player
    /// gives away in the same trade, which leaves the bag first.
    /// </summary>
    /// <param name="name">The other player's name.</param>
    /// <param name="entries">The other player's offer's items.</param>
    /// <param name="gold">The party's gold.</param>
    /// <param name="maxGold">The most gold the party may carry.</param>
    /// <param name="goldGiven">The gold the player's own offer gives away.</param>
    /// <param name="goldTaken">The gold the other player's offer gives.</param>
    /// <returns>The reason, <see langword="null"/> while the game can take it.</returns>
    public static string? ReceiveRefusal(string name, IReadOnlyList<TradeEntry> entries, long gold, long maxGold, long goldGiven, long goldTaken)
    {
        ArgumentNullException.ThrowIfNull(entries);
        if (entries.Any(entry => entry.Facts is null))
        {
            return $"{name}'s offer holds items your game does not know.";
        }

        if (entries.Any(entry => !Tradeable(entry.Facts!)))
        {
            return $"{name}'s offer holds key items.";
        }

        if (entries.Any(entry => entry.Amount < 1 || entry.Amount > (entry.Facts!.Unique ? 1 : TradeOffers.MaxAmount)))
        {
            return $"{name}'s offer is not valid.";
        }

        if (gold - goldGiven + goldTaken > maxGold)
        {
            return "You cannot carry that much gold.";
        }

        if (entries.FirstOrDefault(entry => !entry.Facts!.Unique && entry.Held - entry.Given + entry.Amount > TradeOffers.MaxAmount) is { } full)
        {
            return $"You cannot carry more {full.Name}.";
        }

        IGrouping<string, TradeEntry>? crowded = entries.Where(entry => entry.Facts!.Unique).GroupBy(entry => entry.Facts!.Kind)
            .FirstOrDefault(copies => (copies.First().Room ?? TradeOffers.MaxAmount) + copies.First().CopiesGiven < copies.Count());
        return crowded is null ? null : $"You cannot carry more equipment like {crowded.First().Name}.";
    }
}
