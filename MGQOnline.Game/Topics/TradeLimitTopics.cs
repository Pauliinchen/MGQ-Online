//----------------------------------------------------------------
//  TradeLimitTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Trade;

namespace MGQOnline.Game.Topics;

/// <summary>
/// The bridge topics of the items a trade moves, see <see cref="TradeLimits"/>, which trade.rbx
/// and the trade screen ask. An item's facts cross as [kind, key, stone, unique].
/// </summary>
public static class TradeLimitTopics
{
    /// <summary>
    /// Tells which items may be traded, see <see cref="TradeLimits.Tradeable"/>: each item's facts in;
    /// whether each may out.
    /// </summary>
    public const string Tradeable = "trade.tradeable";

    /// <summary>
    /// Works out how many of an item an offer holds, see <see cref="TradeLimits.Amount"/>:
    /// <c>wanted</c>, <c>held</c> and <c>unique</c> in; <c>amount</c> and <c>why</c> out.
    /// </summary>
    public const string Amount = "trade.amount";

    /// <summary>
    /// Tells why the player's game cannot take the other player's offer, see
    /// <see cref="TradeLimits.ReceiveRefusal"/>: <c>name</c>, <c>gold</c>, <c>max_gold</c>,
    /// <c>gold_given</c>, <c>gold_taken</c> and <c>entries</c> (each <c>facts</c>, nil for an
    /// unknown item, <c>amount</c>, <c>held</c>, <c>given</c>, <c>room</c>, <c>copies_given</c> and
    /// <c>name</c>) in; the reason out, nil while it can.
    /// </summary>
    public const string Refusal = "trade.refusal";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        context.Register(Tradeable, (_, request) => new RubyArray(request.AsArray().Select(item => (RubyValue)TradeLimits.Tradeable(FactsOf(item)!))));
        context.Register(Amount, (_, request) =>
        {
            RubyHash asked = request.AsHash();
            (long amount, string? why) = TradeLimits.Amount(asked["wanted"].AsLong(), asked["held"].AsLong(), asked["unique"].AsBool());
            return new RubyHash { { "amount", amount }, { "why", why } };
        });
        context.Register(Refusal, (_, request) =>
        {
            RubyHash asked = request.AsHash();
            TradeEntry[] entries = [.. asked["entries"].AsArray().Select(entry => entry.AsHash()).Select(entry => new TradeEntry(
                FactsOf(entry["facts"]), entry["amount"].AsLong(), entry["held"].AsLong(), entry["given"].AsLong(),
                entry["room"].IsNil ? null : entry["room"].AsLong(), entry["copies_given"].AsLong(), entry["name"].AsText()))];
            return TradeLimits.ReceiveRefusal(asked["name"].AsText(), entries, asked["gold"].AsLong(), asked["max_gold"].AsLong(),
                asked["gold_given"].AsLong(), asked["gold_taken"].AsLong());
        });
    }

    /// <summary>
    /// Reads an item's facts.
    /// </summary>
    /// <param name="facts">[kind, key, stone, unique], nil for an unknown item.</param>
    /// <returns>The facts, <see langword="null"/> for an unknown item.</returns>
    private static TradeItemFacts? FactsOf(RubyValue facts) => facts is RubyArray { Count: 4 } fields
        ? new TradeItemFacts(fields[0].IsNil ? string.Empty : fields[0].AsText(), fields[1].AsBool(), fields[2].AsBool(), fields[3].AsBool())
        : null;
}
