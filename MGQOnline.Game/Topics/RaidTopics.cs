//----------------------------------------------------------------
//  RaidTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Kept the troops' sizes in a roster the frozen fights' topics read too
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Raid;

namespace MGQOnline.Game.Topics;

/// <summary>
/// The bridge topics of the raid bosses' rules, see <see cref="BossTable"/> and
/// <see cref="BossRules"/>, which both hosts answer through <see cref="SharedTopics"/>. The scripts
/// hand the game's facts (<see cref="RaidFacts.Of"/>) with each question.
/// </summary>
public static class RaidTopics
{
    /// <summary>
    /// Hands out the table: <c>sizes</c> ([troop, how many enemies its setup makes] each, kept for
    /// every later question) in; <c>troops</c> ([troop, milestone, name, tier, title, section, pool
    /// key] each, in story order), <c>tiers</c> ([tier, [[stat, factor as text], ...]] each), <c>key_troops</c>
    /// ([pool key, the troop of its boss's last phase] each), <c>stats</c> (the stats any tier changes besides max HP), <c>titles</c>, <c>sections</c> ([name, [boss
    /// names]] each) and <c>reads</c> (<c>switches</c> and <c>variables</c>, the order of the facts'
    /// <c>s</c> and <c>v</c>) out.
    /// </summary>
    public const string Bosses = "raid.bosses";

    /// <summary>
    /// Decides how a battle about to be set up, or just set up, fights a pool or its boss at its tier
    /// (<see cref="BossRules.Kind"/>): <c>troop</c>, <c>mode</c> ("pools" or "tiers"), <c>facts</c>,
    /// <c>active</c>, <c>raid</c>, <c>at_command</c>, <c>in_map</c>, <c>event</c>, <c>side</c> (a
    /// troop or nil), <c>invited</c> and <c>retry</c> ([troop, side] or nil) and <c>own</c> (how many
    /// enemies the setup made, nil before it) in; <c>kind</c>, <c>why</c>, <c>won</c>, <c>keys</c>
    /// (the pools of the troop's own enemies), <c>tier</c>, <c>defeated</c> (whether those pools are
    /// all empty now) and <c>milestone</c> out.
    /// </summary>
    public const string Kind = "raid.kind";

    /// <summary>
    /// Tells what the rules say of troops: <c>facts</c>, <c>mode</c> ("pools" or "tiers"),
    /// <c>active</c> and <c>troops</c> in; per troop <c>troop</c>, <c>pooled</c>, <c>defeated</c>,
    /// <c>shown</c> (whether its battle shows a bar), <c>beaten</c> and <c>keys</c> (the pools of its own enemies) out, in the request's order.
    /// </summary>
    public const string Troops = "raid.troops";

    /// <summary>
    /// Lists the level caps of the milestones a story beat (<see cref="BossRules.BeatenCaps"/>):
    /// <c>facts</c> in, the caps out.
    /// </summary>
    public const string Caps = "raid.caps";

    /// <summary>
    /// Registers the topics on a context, over a host's pools; the first facts with fewer story
    /// values than the rules read are logged.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="relay">The host's way to the pools.</param>
    /// <param name="sizes">The troops' sizes, which the table's request fills.</param>
    public static void Register(BridgeContext context, IRaidRelay relay, RaidRoster sizes)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(relay);
        ArgumentNullException.ThrowIfNull(sizes);
        context.Register(Bosses, (_, request) =>
        {
            sizes.Take(request is RubyHash hash ? hash["sizes"] : RubyNil.Value);
            return Table();
        });
        bool toldShort = false;
        RaidFacts FactsOf(RubyHash request)
        {
            RaidFacts facts = RaidFacts.Of(request["facts"]);
            if (!facts.Complete && !toldShort)
            {
                toldShort = true;
                context.Log.Write($"raid bosses: no battle fights a pool or a tier: {BossRules.ShortFacts}");
            }

            return facts;
        }

        context.Register(Kind, (_, request) => KindOf(request.AsHash(), FactsOf(request.AsHash()), sizes, relay.Ledger));
        context.Register(Troops, (_, request) => TroopsOf(request.AsHash(), FactsOf(request.AsHash()), sizes, relay.Ledger));
        context.Register(Caps, (_, request) => new RubyArray(BossRules.BeatenCaps(FactsOf(request.AsHash())).Select(cap => (RubyValue)cap)));
    }

    /// <summary>
    /// Writes a factor as text, every bit kept, since no Float crosses the bridge.
    /// </summary>
    /// <param name="factor">The factor.</param>
    /// <returns>The factor, such as "50" or "4.33".</returns>
    public static string FactorText(double factor) => factor.ToString("R", CultureInfo.InvariantCulture);

    /// <summary>
    /// Answers <see cref="Bosses"/>.
    /// </summary>
    /// <returns>The table.</returns>
    private static RubyHash Table() => new()
    {
        {
            "troops", new RubyArray(BossTable.Troops.Select(troop =>
            {
                RaidBoss boss = BossTable.At(troop)!;
                string name = BossTable.MilestoneKey(troop)!;
                return (RubyValue)new RubyArray(
                [
                    troop, boss.Milestone, name, BossTable.Tier(troop) is { } tier ? (RubyValue)tier : RubyNil.Value, BossTable.Title(troop), BossTable.SectionOf(name), BossTable.KeyOf(troop),
                ]);
            }))
        },
        {
            "tiers", new RubyArray(BossTable.Tiers.OrderBy(tier => tier.Key).Select(tier => (RubyValue)new RubyArray(
            [
                tier.Key, new RubyArray(tier.Value.OrderBy(stat => stat.Key == "mhp" ? 0 : 1).ThenBy(stat => stat.Key, StringComparer.Ordinal).Select(stat => (RubyValue)new RubyArray([stat.Key, FactorText(stat.Value)]))),
            ])))
        },
        {
            "key_troops", new RubyArray(BossTable.Troops.Select(BossTable.KeyOf).OfType<string>().Distinct(StringComparer.Ordinal)
                .Select(key => (key, troop: BossTable.TroopOfKey(key))).Where(pair => pair.troop is not null).Select(pair => (RubyValue)new RubyArray([pair.key, pair.troop!.Value])))
        },
        { "stats", new RubyArray(BossTable.TierStats.Select(stat => (RubyValue)stat)) },
        { "titles", new RubyArray(BossTable.Titles.Select(title => (RubyValue)title)) },
        { "sections", new RubyArray(BossTable.Sections.Select(section => (RubyValue)new RubyArray([section.Name, new RubyArray(section.Bosses.Select(name => (RubyValue)name))]))) },
        {
            "reads", new RubyHash
            {
                { "switches", new RubyArray(BossRules.ReadSwitches.Select(id => (RubyValue)id)) },
                { "variables", new RubyArray(BossRules.ReadVariables.Select(id => (RubyValue)id)) },
            }
        },
    };

    /// <summary>
    /// Answers <see cref="Kind"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <param name="facts">The game, read of the request.</param>
    /// <param name="sizes">The troops' sizes.</param>
    /// <param name="ledger">The pools.</param>
    /// <returns>The answer.</returns>
    private static RubyHash KindOf(RubyHash request, RaidFacts facts, RaidRoster sizes, PoolLedger ledger)
    {
        int troop = request["troop"].AsInt();
        RaidMode mode = request["mode"].AsText() == "tiers" ? RaidMode.Tiers : RaidMode.Pools;
        var ask = new BattleAsk(troop, mode, Flag(request, "active"), Flag(request, "raid"), Flag(request, "at_command"), Flag(request, "in_map"), Flag(request, "event"),
            request["side"] is RubyInteger { Value: var side } ? (int)side : null, PairOf(request["invited"]), PairOf(request["retry"]));
        BattleKind kind = BossRules.Kind(ask, facts);
        int own = request["own"] is RubyInteger { Value: var made } && made > 0 ? (int)made : sizes.SizeOf(troop);
        return new RubyHash
        {
            { "kind", kind.Kind },
            { "why", kind.Why },
            { "won", kind.WonAtOnce },
            { "keys", new RubyArray(BossRules.Keys(troop, own).Select(key => (RubyValue)key)) },
            { "tier", BossTable.Tier(troop) is { } tier ? (RubyValue)tier : RubyNil.Value },
            { "defeated", BossRules.Defeated(troop, sizes.SizeOf(troop), ledger) },
            { "milestone", BossTable.At(troop)?.Milestone },
        };
    }

    /// <summary>
    /// Answers <see cref="Troops"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <param name="facts">The game, read of the request.</param>
    /// <param name="sizes">The troops' sizes.</param>
    /// <param name="ledger">The pools.</param>
    /// <returns>The answer.</returns>
    private static RubyArray TroopsOf(RubyHash request, RaidFacts facts, RaidRoster sizes, PoolLedger ledger)
    {
        bool tiers = request["mode"] is RubyString mode && mode.AsText() == "tiers";
        bool active = Flag(request, "active");
        var answer = new RubyArray();
        foreach (RubyValue each in request["troops"] is RubyArray troops ? troops : new RubyArray())
        {
            if (each is not RubyInteger { Value: var id })
            {
                continue;
            }

            int troop = (int)id;
            int own = sizes.SizeOf(troop);
            bool shown = tiers ? active && BossRules.Refusal(troop, facts, RaidMode.Tiers) is null : BossRules.Shown(troop, facts, own, ledger);
            answer.Add(new RubyHash
            {
                { "troop", troop },
                { "pooled", BossRules.Pooled(troop, facts) },
                { "defeated", BossRules.Defeated(troop, own, ledger) },
                { "shown", shown },
                { "beaten", BossRules.Beaten(troop, facts) },
                { "keys", new RubyArray(BossRules.Keys(troop, own).Select(key => (RubyValue)key)) },
            });
        }

        return answer;
    }

    /// <summary>
    /// Reads a field that is true or anything else.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <param name="name">The field.</param>
    /// <returns>Whether it is true.</returns>
    private static bool Flag(RubyHash request, string name) => request[name] is RubyBool { Flag: true };

    /// <summary>
    /// Reads a troop with whether its battle is a side battle.
    /// </summary>
    /// <param name="value">[troop, side], or nil.</param>
    /// <returns>The pair, null for none.</returns>
    private static (int Troop, bool Side)? PairOf(RubyValue value) =>
        value is RubyArray { Count: >= 1 } pair && pair[0] is RubyInteger { Value: var troop } ? ((int)troop, pair.Count > 1 && pair[1] is RubyBool { Flag: true }) : null;
}
