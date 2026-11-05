//----------------------------------------------------------------
//  KeyItemLoan.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Game.Catchup;

/// <summary>
/// The Classic party's key item loan, a named exception beside the story replay (user decision
/// 2026-11-04): a member who plays the leader's story while ahead of it borrows the copies of each
/// key item the leader holds beyond their own, such as one that opens a door, and gives them back
/// once the leader holds them no more or the member gets their own story back. Every other item
/// stays the leader's.
/// </summary>
/// <remarks>
/// A member who keeps the leader's story borrows nothing: the catch-up gives them the key items to
/// keep.
/// </remarks>
public static class KeyItemLoan
{
    /// <summary>
    /// Answers the topic of the loan.
    /// </summary>
    /// <param name="request">"keeps" (whether the member keeps the leader's story), "guest" (whether they play it), "leader" ({id => count} of the items the leader names), "held" ({id => count} the member's bag holds of them, lent copies included), "lent" ({id => count} lent now) and "key_items" (the ids among them that are key items in the member's game).</param>
    /// <returns>"lent" ([id, count] each, what the loan of each key item whose loan changes becomes), "why" (nil, "keeps" or "own" when nothing is lent) and "skipped" (the ids lent nothing as no key item).</returns>
    public static RubyHash Answer(RubyHash request)
    {
        ArgumentNullException.ThrowIfNull(request);
        if (request["keeps"] is RubyBool { Flag: true })
        {
            return Refused("keeps");
        }

        if (request["guest"] is not RubyBool { Flag: true })
        {
            return Refused("own");
        }

        Dictionary<long, long> leader = Counts(request["leader"]);
        Dictionary<long, long> held = Counts(request["held"]);
        Dictionary<long, long> lent = Counts(request["lent"]);
        HashSet<long> keyItems = request["key_items"] is RubyArray ids ? [.. ids.Select(id => id.AsLong())] : [];
        var changes = new RubyArray();
        var skipped = new RubyArray();
        foreach (long id in leader.Keys.Union(lent.Keys).Order())
        {
            if (!keyItems.Contains(id))
            {
                skipped.Add(id);
                continue;
            }

            long own = held.GetValueOrDefault(id) - lent.GetValueOrDefault(id);
            long wanted = Math.Max(leader.GetValueOrDefault(id) - own, 0);
            if (wanted != lent.GetValueOrDefault(id))
            {
                changes.Add(new RubyArray { id, wanted });
            }
        }

        return new RubyHash { { "lent", changes }, { "why", RubyNil.Value }, { "skipped", skipped } };
    }

    /// <summary>
    /// Answers a loan of nothing.
    /// </summary>
    /// <param name="why">Why.</param>
    /// <returns>The answer.</returns>
    private static RubyHash Refused(string why) => new() { { "lent", new RubyArray() }, { "why", why }, { "skipped", new RubyArray() } };

    /// <summary>
    /// Reads counts of items by their id.
    /// </summary>
    /// <param name="value">{id => count}, nil for none.</param>
    /// <returns>The counts.</returns>
    private static Dictionary<long, long> Counts(RubyValue value)
    {
        var counts = new Dictionary<long, long>();
        if (value is RubyHash hash)
        {
            foreach ((RubyValue id, RubyValue count) in hash)
            {
                counts[id.AsLong()] = count.AsLong();
            }
        }

        return counts;
    }
}
