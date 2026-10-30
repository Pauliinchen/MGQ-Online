//----------------------------------------------------------------
//  PoolTopics.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Handed a fight's pools to the battle server and took them there
//                            - Ran the fights' moments and handed out the battle server's outbox, in place of counting its own reports
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
using MGQOnline.Game.Ruby;

namespace MGQOnline.Game.Topics;

/// <summary>
/// The bridge topics of a Raid World's boss pools and of the battle that fights them, see
/// <see cref="PoolLedger"/> and <see cref="RaidFight"/>, which both hosts answer through
/// <see cref="SharedTopics"/>: the DLL over the pools its relay requests fill, the battle server's
/// core over pools the server's scripts fill with what the relay tells the server.
/// </summary>
public static class PoolTopics
{
    /// <summary>
    /// Hands out the pools as they stand now: nothing in; <c>world</c> (empty before the first),
    /// <c>regen</c> (the share a minute as text) and <c>pools</c> ([key, share left now as text, max,
    /// defeated, who defeated it] each, by key) out.
    /// </summary>
    public const string Pools = "raid.pools";

    /// <summary>
    /// Takes what the relay told the battle server of a pool: <c>world</c>, <c>key</c>, <c>left</c>
    /// (the share as text; nil for an answer that refused the report), <c>max</c>, <c>defeated</c>,
    /// <c>by</c> and <c>answer</c> (whether it answers one of the server's own reports) in; whether
    /// the pool was taken out.
    /// </summary>
    public const string Heard = "raid.pool.heard";

    /// <summary>
    /// Takes the reports the battle server's scripts send through the relay's connection: nothing
    /// in; [world, key, battle, report] each, oldest first, out; none in the game, whose DLL sends its own.
    /// </summary>
    public const string Reports = "raid.pool.reports";

    /// <summary>
    /// Starts a battle that fights a boss's pools, in place of any other: <c>world</c>,
    /// <c>battle</c>, <c>keys</c> (the pools of the troop's own enemies by their place), <c>own</c>
    /// (how many enemies the troop's setup made), <c>guest</c> (whether a host's stream governs it)
    /// and <c>side</c> (whether it is a side battle) in; nothing out.
    /// </summary>
    public const string FightOpen = "raid.fight.open";

    /// <summary>
    /// Runs a moment of the battle, see <see cref="RaidFight.Turn"/>: <c>moment</c> (start, phase,
    /// action, wait, turn_end, end, take_over or role), <c>reporter</c> and <c>enemies</c>
    /// (<c>place:hp:mhp:dead:id</c> per own enemy, separated by semicolons) in; <c>actions</c>
    /// ([place, hp] each, 0 kills), <c>killed</c>, <c>reported</c>, <c>guest</c>, <c>took_over</c>,
    /// <c>rebuilt</c> (places), <c>report_in</c> and <c>sync_in</c> (milliseconds, nil for at once)
    /// out; nil without a battle. The end ends the battle.
    /// </summary>
    public const string FightTurn = "raid.fight.turn";

    /// <summary>
    /// Ends the battle without reporting: nothing in, nothing out.
    /// </summary>
    public const string FightClose = "raid.fight.close";

    /// <summary>
    /// Writes what the battle server needs to fight the battle's pools as the player's game would:
    /// nothing in; [the count of the troop's own enemies, 1 or 0 for a side battle, the pools the
    /// game knows of them ([key, share left now with ten decimals, max, 1 or 0 for defeated, who
    /// defeated it] each)] out, nil without a battle.
    /// </summary>
    public const string FightExport = "raid.fight.export";

    /// <summary>
    /// As the battle server, takes the pools of a battle its starter handed over: <c>world</c> and
    /// <c>fields</c> (as <see cref="FightExport"/> writes them) in; [the count, whether it is a side
    /// battle] out, nil for a count that is none.
    /// </summary>
    public const string FightImport = "raid.fight.import";

    /// <summary>
    /// The longest key of a pool the battle server takes from its starter: a boss's key and an enemy's place.
    /// </summary>
    private const int MaxServedKeyLength = 64;

    /// <summary>
    /// The most enemies of a troop the battle server takes the count of.
    /// </summary>
    private const int MaxOwn = 99;

    /// <summary>
    /// The event of a pool a push told defeated for the world, once: <c>key</c> and <c>by</c>.
    /// </summary>
    public const string DefeatedEvent = "raid.boss_defeated";

    /// <summary>
    /// The event of a pool a push told standing again after an admin's reset, once: <c>key</c>.
    /// </summary>
    public const string BackEvent = "raid.boss_back";

    /// <summary>
    /// What a log line of the battle starts with, as the script's lines did.
    /// </summary>
    private const string LogTag = "raid pool: ";

    /// <summary>
    /// The moments of <see cref="FightTurn"/> by their names.
    /// </summary>
    private static readonly Dictionary<string, FightMoment> Moments = new(StringComparer.Ordinal)
    {
        ["start"] = FightMoment.Start,
        ["phase"] = FightMoment.Phase,
        ["action"] = FightMoment.Action,
        ["wait"] = FightMoment.Wait,
        ["turn_end"] = FightMoment.TurnEnd,
        ["end"] = FightMoment.End,
        ["take_over"] = FightMoment.TakeOver,
        ["role"] = FightMoment.Role,
    };

    /// <summary>
    /// Registers the topics on a context, over a host's way to the pools, and posts the pools'
    /// defeats and resets as events at each drain.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="relay">The host's way to the pools.</param>
    public static void Register(BridgeContext context, IRaidRelay relay)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(relay);
        RaidFight? fight = null;
        context.Register(Pools, (_, _) => Describe(relay.Ledger));
        context.Register(Heard, (_, request) => Hear(relay.Ledger, request.AsHash()));
        context.Register(Reports, (_, _) => new RubyArray(relay.TakeOutbox().Select(report => (RubyValue)new RubyArray([report.World, report.Key, report.Battle, report.Text]))));
        context.Register(FightOpen, (_, request) =>
        {
            fight = Open(request.AsHash());
            return null;
        });
        context.Register(FightTurn, (each, request) =>
        {
            if (fight is null)
            {
                return null;
            }

            (RubyHash reply, bool ended) = Turn(fight, relay, request.AsHash(), line => each.Log.Write(LogTag + line));
            fight = ended ? null : fight;
            return reply;
        });
        context.Register(FightClose, (_, _) =>
        {
            fight = null;
            return null;
        });
        context.Register(FightExport, (_, _) => fight is null ? null : Export(fight, relay.Ledger));
        context.Register(FightImport, (_, request) => Import(relay.Ledger, request.AsHash()));
        context.EveryFrame(each => PostChanges(each, relay.Ledger));
    }

    /// <summary>
    /// Writes a share as the scripts read it back, every bit kept.
    /// </summary>
    /// <param name="share">The share.</param>
    /// <returns>The share as text, such as "0.25" or "1E-09".</returns>
    public static string ShareText(double share) => share.ToString("R", CultureInfo.InvariantCulture);

    /// <summary>
    /// Reads the enemies of <see cref="FightTurn"/>.
    /// </summary>
    /// <param name="text">place:hp:mhp:dead:id per enemy, separated by semicolons.</param>
    /// <returns>The enemies by their place.</returns>
    /// <exception cref="BridgeRequestException">A field is no whole number.</exception>
    public static Dictionary<int, FightEnemy> EnemiesOf(string text)
    {
        ArgumentNullException.ThrowIfNull(text);
        var enemies = new Dictionary<int, FightEnemy>();
        foreach (string entry in text.Split(';', StringSplitOptions.RemoveEmptyEntries))
        {
            string[] fields = entry.Split(':');
            if (fields.Length != 5 || !int.TryParse(fields[0], NumberStyles.None, CultureInfo.InvariantCulture, out int place)
                || !long.TryParse(fields[1], NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out long hp)
                || !long.TryParse(fields[2], NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out long mhp)
                || fields[3] is not ("0" or "1")
                || !long.TryParse(fields[4], NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out long id))
            {
                throw new BridgeRequestException($"The enemy {entry} is not place:hp:mhp:dead:id.");
            }

            enemies[place] = new FightEnemy(hp, mhp, fields[3] == "1", id);
        }

        return enemies;
    }

    /// <summary>
    /// Answers <see cref="Pools"/>.
    /// </summary>
    /// <param name="ledger">The ledger.</param>
    /// <returns>The pools.</returns>
    private static RubyHash Describe(PoolLedger ledger) => new()
    {
        { "world", ledger.World ?? string.Empty },
        { "regen", ShareText(ledger.RegenPerMinute) },
        {
            "pools", new RubyArray(ledger.Pools().Select(pool => (RubyValue)new RubyArray(
            [
                pool.Key, ShareText(pool.Left), (long)Math.Round(pool.Max, MidpointRounding.AwayFromZero), pool.Defeated, pool.By,
            ])))
        },
    };

    /// <summary>
    /// Answers <see cref="Heard"/>.
    /// </summary>
    /// <param name="ledger">The ledger.</param>
    /// <param name="request">The request.</param>
    /// <returns>Whether the pool was taken.</returns>
    /// <exception cref="BridgeRequestException">The share is no number.</exception>
    private static RubyValue Hear(PoolLedger ledger, RubyHash request)
    {
        string key = request["key"].AsText();
        ledger.Enter(request["world"].AsText());
        bool answer = request["answer"].AsBool();
        if (answer)
        {
            ledger.Settled(key);
        }

        // A report the relay refused is answered without the pool.
        if (request["left"].IsNil)
        {
            return false;
        }

        if (!double.TryParse(request["left"].AsText(), NumberStyles.Float, CultureInfo.InvariantCulture, out double left) || !double.IsFinite(left))
        {
            throw new BridgeRequestException($"The share {request["left"].AsText()} of {key} is no number.");
        }

        var word = new PoolWord(key, left, request["max"].AsLong(), request["defeated"].AsBool(), request["by"].IsNil ? string.Empty : request["by"].AsText());
        return ledger.Hear(word, answer ? PoolSource.Answered : PoolSource.Fetched);
    }

    /// <summary>
    /// Answers <see cref="FightOpen"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The battle.</returns>
    private static RaidFight Open(RubyHash request) =>
        new(request["world"].AsText(), request["battle"].AsText(), request["keys"].AsArray().Select(key => key.AsText()).ToList(), request["guest"].AsBool(),
            request["side"] is RubyBool { Flag: true })
        {
            Own = request["own"] is RubyInteger { Value: var own } ? (long)own : request["keys"].AsArray().Count,
        };

    /// <summary>
    /// Answers <see cref="FightExport"/>.
    /// </summary>
    /// <param name="fight">The battle.</param>
    /// <param name="ledger">The pools.</param>
    /// <returns>The battle's fields.</returns>
    private static RubyArray Export(RaidFight fight, PoolLedger ledger)
    {
        var pools = new RubyArray();
        foreach (RaidMember member in fight.Members)
        {
            if (ledger.Pool(member.Key) is { } pool)
            {
                pools.Add(new RubyArray(
                [
                    pool.Key, pool.Left.ToString("F10", CultureInfo.InvariantCulture), (long)Math.Round(pool.Max, MidpointRounding.AwayFromZero), pool.Defeated ? 1 : 0, pool.By,
                ]));
            }
        }

        return new RubyArray([fight.Own, fight.Side ? 1 : 0, pools]);
    }

    /// <summary>
    /// Answers <see cref="FightImport"/>.
    /// </summary>
    /// <param name="ledger">The pools.</param>
    /// <param name="request">The request.</param>
    /// <returns>The count and whether it is a side battle; nil for a count that is none.</returns>
    private static RubyValue? Import(PoolLedger ledger, RubyHash request)
    {
        RubyArray fields = request["fields"] is RubyArray given ? given : new RubyArray();
        if (fields.Count == 0 || fields[0] is not RubyInteger { Value: var own } || own <= 0 || own > MaxOwn)
        {
            return null;
        }

        ledger.Enter(request["world"].AsText());
        if (fields.Count > 2 && fields[2] is RubyArray pools)
        {
            foreach (RubyValue each in pools)
            {
                if (each is not RubyArray { Count: > 0 } pool || pool[0] is not RubyString key || key.AsText() is not { Length: > 0 } name
                    || name.EnumerateRunes().Count() > MaxServedKeyLength)
                {
                    continue;
                }

                RubyValue Field(int index) => index < pool.Count ? pool[index] : RubyNil.Value;
                double left = Field(1) is RubyString share ? RubyNumbers.ToF(share.AsBytes().Span) : 0;
                ledger.Hear(new PoolWord(name, left, Field(2) is RubyInteger { Value: var max } ? (double)max : 0, Field(3) is RubyInteger { Value: var one } && one == 1,
                    Field(4) is RubyString by ? by.AsText() : string.Empty), PoolSource.Fetched);
            }
        }

        return new RubyArray([(long)own, fields.Count > 1 && fields[1] is RubyInteger { Value: var side } && side == 1]);
    }

    /// <summary>
    /// Answers <see cref="FightTurn"/>.
    /// </summary>
    /// <param name="fight">The battle.</param>
    /// <param name="relay">The host's way to the pools.</param>
    /// <param name="request">The request.</param>
    /// <param name="log">Writes a line of the log.</param>
    /// <returns>The reply, and whether the battle ended.</returns>
    /// <exception cref="BridgeRequestException">The moment is none.</exception>
    private static (RubyHash Reply, bool Ended) Turn(RaidFight fight, IRaidRelay relay, RubyHash request, Action<string> log)
    {
        string name = request["moment"].AsText();
        FightMoment moment = Moments.TryGetValue(name, out FightMoment found) ? found : throw new BridgeRequestException($"There is no moment {name}.");
        FightTurn turn = fight.Turn(moment, request["reporter"].AsBool(), EnemiesOf(request["enemies"].AsText()), relay, relay.Ledger.Now, log);
        var reply = new RubyHash
        {
            { "actions", new RubyArray(turn.Actions.Select(action => (RubyValue)new RubyArray([action.Index, action.Hp]))) },
            { "killed", turn.Killed },
            { "reported", turn.Reported },
            { "guest", turn.Guest },
            { "took_over", turn.TookOver },
            { "rebuilt", new RubyArray(turn.Rebuilt.Select(place => (RubyValue)place)) },
            { "report_in", turn.ReportIn is { } report ? (RubyValue)report : RubyNil.Value },
            { "sync_in", turn.SyncIn is { } sync ? (RubyValue)sync : RubyNil.Value },
        };
        return (reply, moment == FightMoment.End);
    }

    /// <summary>
    /// Posts the defeats and resets the pushes told since the last drain.
    /// </summary>
    /// <param name="context">The context.</param>
    /// <param name="ledger">The ledger.</param>
    private static void PostChanges(BridgeContext context, PoolLedger ledger)
    {
        foreach (PoolChange change in ledger.TakeChanges())
        {
            context.Events.Post(change.Defeated ? DefeatedEvent : BackEvent, change.Defeated
                ? new RubyHash { { "key", change.Key }, { "by", change.By } }
                : new RubyHash { { "key", change.Key } });
        }
    }
}
