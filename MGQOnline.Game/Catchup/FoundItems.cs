//----------------------------------------------------------------
//  FoundItems.cs
//
//  Changelog:
//      Paulinchen  2026-11-01: Took a copy of each key item another player's event used up from every save that holds it
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Game.Catchup;

/// <summary>
/// What a player's game does with the key items and the items unlocking a job or a race that
/// another player found or used up: the items reach every player as soon as anyone gets one, in
/// every world type, each save gets each of them once, and each use of one by an event takes one
/// copy from every save that holds it.
/// </summary>
/// <param name="Gives">The items to give, one of each.</param>
/// <param name="Trims">The items unlocking a job or a race held more than once, each with the copies to take back.</param>
/// <param name="Takes">The items another player's event used up, one copy for each entry.</param>
/// <param name="Got">Every item the save has held, the given ones included.</param>
/// <param name="Spent">Every use the save has counted, the new ones included, in ordinal order.</param>
public sealed record FoundItems(IReadOnlyList<long> Gives, IReadOnlyList<(long Id, long Extra)> Trims, IReadOnlyList<long> Takes, IReadOnlyList<long> Got, IReadOnlyList<string> Spent)
{
    /// <summary>
    /// Decides what to give, take back and take.
    /// </summary>
    /// <remarks>
    /// A save that held an item once gets none again, so a key item an event took stays away, and
    /// a used up item goes to no save that never held it, so a use heard before the find leaves no copy.
    /// </remarks>
    /// <param name="found">The items any player found.</param>
    /// <param name="got">The items the save has held before.</param>
    /// <param name="held">How many the party holds of each item the game has, found or held.</param>
    /// <param name="keepsOne">Tells whether an item is held once at most, as one that unlocks a job or a race.</param>
    /// <param name="used">Every use of an item by an event any player knows of, as "item.mark".</param>
    /// <param name="spent">The uses the save has counted before, its own among them.</param>
    /// <returns>The decision.</returns>
    public static FoundItems Plan(IEnumerable<long> found, IEnumerable<long> got, IReadOnlyDictionary<long, long> held, Func<long, bool> keepsOne, IEnumerable<string> used, IEnumerable<string> spent)
    {
        ArgumentNullException.ThrowIfNull(found);
        ArgumentNullException.ThrowIfNull(got);
        ArgumentNullException.ThrowIfNull(held);
        ArgumentNullException.ThrowIfNull(keepsOne);
        ArgumentNullException.ThrowIfNull(used);
        ArgumentNullException.ThrowIfNull(spent);
        var had = new SortedSet<long>(got);
        had.UnionWith(held.Where(pair => pair.Value > 0).Select(pair => pair.Key));
        var left = new Dictionary<long, long>(held);
        List<long> foundIds = [.. found.Distinct()];
        var trims = new List<(long Id, long Extra)>();
        foreach (long id in foundIds)
        {
            if (left.TryGetValue(id, out long count) && count > 1 && keepsOne(id))
            {
                trims.Add((id, count - 1));
                left[id] = 1;
            }
        }

        var counted = new SortedSet<string>(spent, StringComparer.Ordinal);
        var usedIds = new HashSet<long>();
        var takes = new List<long>();
        foreach (string use in used.Distinct().Order(StringComparer.Ordinal))
        {
            if (ItemOf(use) is not long id)
            {
                continue;
            }

            usedIds.Add(id);
            if (counted.Add(use) && left.TryGetValue(id, out long count) && count > 0)
            {
                takes.Add(id);
                left[id] = count - 1;
            }
        }

        var gives = new List<long>();
        foreach (long id in foundIds)
        {
            if (left.TryGetValue(id, out long count) && count == 0 && !usedIds.Contains(id) && had.Add(id))
            {
                gives.Add(id);
            }
        }

        return new FoundItems(gives, trims, takes, [.. had], [.. counted]);
    }

    /// <summary>
    /// Answers the topic of a Classic party's found items: {"found", "got", "held" (count by id),
    /// "keeps_one", "used", "spent"} in, {"give" ([id, ...]), "trim" ([[id, copies], ...]), "take"
    /// ([id, ...]), "got" ([id, ...]), "spent" (["item.mark", ...])} out.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The answer.</returns>
    public static RubyHash Check(RubyHash request)
    {
        ArgumentNullException.ThrowIfNull(request);
        var held = new Dictionary<long, long>();
        if (request["held"] is RubyHash counts)
        {
            foreach ((RubyValue id, RubyValue count) in counts)
            {
                held[id.AsLong()] = count.AsLong();
            }
        }

        HashSet<long> keepsOne = [.. Numbers(request["keeps_one"])];
        FoundItems plan = Plan(Numbers(request["found"]), Numbers(request["got"]), held, keepsOne.Contains, Texts(request["used"]), Texts(request["spent"]));
        return new RubyHash
        {
            { "give", new RubyArray(plan.Gives.Select(id => (RubyValue)id)) },
            { "trim", new RubyArray(plan.Trims.Select(trim => (RubyValue)new RubyArray { trim.Id, trim.Extra })) },
            { "take", new RubyArray(plan.Takes.Select(id => (RubyValue)id)) },
            { "got", new RubyArray(plan.Got.Select(id => (RubyValue)id)) },
            { "spent", new RubyArray(plan.Spent.Select(use => (RubyValue)use)) },
        };
    }

    /// <summary>
    /// Reads the item of a use, "item.mark".
    /// </summary>
    /// <param name="use">The use.</param>
    /// <returns>The item, null for a use that names none.</returns>
    private static long? ItemOf(string use)
    {
        int dot = use.IndexOf('.', StringComparison.Ordinal);
        return dot > 0 && long.TryParse(use.AsSpan(0, dot), NumberStyles.None, CultureInfo.InvariantCulture, out long id) && id > 0 ? id : null;
    }

    /// <summary>
    /// Reads a list of whole numbers, none for nil.
    /// </summary>
    /// <param name="value">The list.</param>
    /// <returns>The numbers.</returns>
    private static IEnumerable<long> Numbers(RubyValue value) => value.IsNil ? [] : value.AsArray().Select(number => number.AsLong());

    /// <summary>
    /// Reads a list of texts, none for nil.
    /// </summary>
    /// <param name="value">The list.</param>
    /// <returns>The texts.</returns>
    private static IEnumerable<string> Texts(RubyValue value) => value.IsNil ? [] : value.AsArray().Select(text => text.AsText());
}
