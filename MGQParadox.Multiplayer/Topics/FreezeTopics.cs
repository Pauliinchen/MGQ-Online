//----------------------------------------------------------------
//  FreezeTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Data.Events;
using MGQOnline.Game.Raid;
using MGQOnline.Game.Events;

namespace MGQParadox.Multiplayer.Topics;

/// <summary>
/// The bridge topics of a Raid World's frozen boss fights (<see cref="FrozenFights"/>) and of a lost
/// raid boss battle's defeat (<see cref="FreezeRules"/>), which only the game answers: the battle
/// server keeps no story. Each request names the open world and hands the player's facts
/// (<see cref="RaidFacts.Of"/>); the writes the list asks of the relay come back with each answer,
/// which the scripts send as story keys.
/// </summary>
internal static class FreezeTopics
{
    /// <summary>
    /// Hands out the list after dropping the fights that are over: <c>world</c>, <c>facts</c> in;
    /// <c>version</c>, <c>entries</c>, <c>held</c> ([kind, key, value] each, the oldest fight's for a
    /// key two hold) and <c>writes</c> out.
    /// </summary>
    public const string State = "freeze.fights.state";

    /// <summary>
    /// Notes the player's own frozen fight: <c>world</c>, <c>facts</c>, <c>entry</c> in; <c>held</c>
    /// (whether the list holds it) and <c>writes</c> out.
    /// </summary>
    public const string Note = "freeze.fights.note";

    /// <summary>
    /// Takes the fights of the world's story the relay handed: <c>world</c>, <c>facts</c>,
    /// <c>keys</c> ([troop, fight, false once it ended, or nil] each) in; <c>writes</c> out.
    /// </summary>
    public const string Take = "freeze.fights.take";

    /// <summary>
    /// Takes the world's story as the relay told it: <c>world</c>, <c>facts</c>, <c>told</c> (the
    /// world's story as facts) in; <c>writes</c> out.
    /// </summary>
    public const string Told = "freeze.fights.told";

    /// <summary>
    /// Notes that the player won a battle against a troop's pools: <c>troop</c> in, nothing out.
    /// </summary>
    public const string Won = "freeze.fights.won";

    /// <summary>
    /// Tells why troops' fights are over, the one decision every caller asks: <c>world</c>,
    /// <c>facts</c>, <c>troops</c> in; [troop, why or nil] each out.
    /// </summary>
    public const string Over = "freeze.fights.over";

    /// <summary>
    /// Forgets the fights and the battles won, as at the title: nothing in, nothing out.
    /// </summary>
    public const string Forget = "freeze.fights.forget";

    /// <summary>
    /// Finds why a lost raid boss battle's defeat changes nothing back
    /// (<see cref="FreezeRules.DefeatRefusal"/>): <c>troop</c>, <c>troop_now</c>, <c>active</c>,
    /// <c>can_lose</c>, <c>library</c>, <c>known</c>, <c>kind</c>, <c>record</c>, <c>over</c> (whether
    /// its fight is over for the world) and <c>facts</c> in;
    /// why, or nil, out.
    /// </summary>
    public const string Defeat = "freeze.defeat";

    /// <summary>
    /// Decides which value each key a defeat changed goes back to (<see cref="FreezeRules.Undo"/>):
    /// <c>rows</c> ([kind, id, personal, changed before the battle] each) in; per row "start",
    /// "was" or nil out.
    /// </summary>
    public const string Undo = "freeze.undo";

    /// <summary>
    /// What a log line starts with, as the script's lines did.
    /// </summary>
    private const string LogTag = "world freeze: ";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="ledger">Gives the pools.</param>
    /// <param name="roster">The troops' sizes.</param>
    /// <param name="events">Gives the game's events once a topic is called.</param>
    public static void Register(BridgeContext context, Func<PoolLedger> ledger, RaidRoster roster, Func<GameEvents> events)
    {
        RubyHash? kept = null;
        RubyHash Tables()
        {
            if (kept is not null)
            {
                return kept;
            }

            RubyHash found = EventTableTopics.SitesOf(events(), new RubyHash { { "troops", new RubyArray(BossTable.Troops.Select(troop => (RubyValue)troop)) } });
            kept = found["sites"].AsHash().Count > 0 ? found : null;
            return found;
        }

        IReadOnlyList<int> Alternatives(int troop) =>
            Tables()["alternatives"].AsHash()[troop] is RubyArray others ? [.. others.Select(other => other.AsInt())] : [];

        var fights = new FrozenFights(Alternatives, line => context.Log.Write(LogTag + line));
        Func<int, string?> OverFor(RubyHash request)
        {
            fights.Enter(request["world"].AsText());
            RaidFacts facts = RaidFacts.Of(request["facts"]);
            PoolLedger pools = ledger();
            return troop => fights.EndReason(troop, facts, each => BossRules.Defeated(each, roster.SizeOf(each), pools));
        }

        context.Register(State, (_, request) =>
        {
            RubyHash hash = request.AsHash();
            fights.DropEnded(OverFor(hash));
            return new RubyHash
            {
                { "version", fights.Version },
                { "entries", new RubyArray(fights.Entries) },
                { "held", new RubyArray(fights.Held) },
                { "writes", Writes(fights) },
            };
        });
        context.Register(Note, (_, request) =>
        {
            RubyHash hash = request.AsHash();
            bool held = hash["entry"] is RubyHash entry && fights.Note(entry, OverFor(hash));
            return new RubyHash { { "held", held }, { "writes", Writes(fights) } };
        });
        context.Register(Take, (_, request) =>
        {
            RubyHash hash = request.AsHash();
            List<(int, RubyValue)> keys = [.. hash["keys"].AsArray().Select(pair => pair.AsArray()).Where(pair => pair.Count == 2 && pair[0] is RubyInteger)
                .Select(pair => (pair[0].AsInt(), pair[1]))];
            fights.Take(keys, OverFor(hash));
            return new RubyHash { { "writes", Writes(fights) } };
        });
        context.Register(Told, (_, request) =>
        {
            RubyHash hash = request.AsHash();
            Func<int, string?> over = OverFor(hash);
            fights.Told(RaidFacts.Of(hash["told"]), over);
            return new RubyHash { { "writes", Writes(fights) } };
        });
        context.Register(Won, (_, request) =>
        {
            fights.Won(request.AsHash()["troop"].AsInt());
            return null;
        });
        context.Register(Over, (_, request) =>
        {
            RubyHash hash = request.AsHash();
            Func<int, string?> over = OverFor(hash);
            return new RubyArray(hash["troops"].AsArray().Where(troop => troop is RubyInteger).Select(troop => (RubyValue)new RubyArray([troop, over(troop.AsInt())])));
        });
        context.Register(Forget, (_, _) =>
        {
            fights.Forget("at the title");
            fights.ForgetWins();
            return null;
        });
        context.Register(Defeat, (_, request) => DefeatOf(request.AsHash()));
        context.Register(Undo, (_, request) => UndoOf(Tables(), request.AsHash()));
    }

    /// <summary>
    /// Writes the relay's writes the list asked for since the last answer.
    /// </summary>
    /// <param name="fights">The list.</param>
    /// <returns>[troop, fight or false] each.</returns>
    private static RubyArray Writes(FrozenFights fights) => new(fights.TakeWrites().Select(write => (RubyValue)new RubyArray([write.Troop, write.Value])));

    /// <summary>
    /// Answers <see cref="Defeat"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>Why, nil when the defeat changes back.</returns>
    private static RubyValue DefeatOf(RubyHash request)
    {
        static bool Flag(RubyValue value) => value is RubyBool { Flag: true };
        var ask = new DefeatAsk(request["troop"].AsInt(), request["troop_now"] is RubyInteger now ? now.AsInt() : 0, Flag(request["active"]), Flag(request["can_lose"]),
            Flag(request["library"]), Flag(request["known"]), request["kind"] is RubyString kind ? kind.AsText() : null, Flag(request["record"]), Flag(request["over"]));
        return FreezeRules.DefeatRefusal(ask, RaidFacts.Of(request["facts"]));
    }

    /// <summary>
    /// Answers <see cref="Undo"/>.
    /// </summary>
    /// <param name="tables">The freeze's tables, see <see cref="EventTableTopics.Sites"/>.</param>
    /// <param name="request">The request.</param>
    /// <returns>Per row "start", "was" or nil.</returns>
    private static RubyArray UndoOf(RubyHash tables, RubyHash request)
    {
        RubyHash defeat = tables["defeat"].AsHash();
        HashSet<int> switches = [.. defeat["switches"].AsArray().Select(id => id.AsInt())];
        HashSet<int> variables = [.. defeat["variables"].AsArray().Select(id => id.AsInt())];
        List<UndoRow> rows = [.. request["rows"].AsArray().Select(row => row.AsArray())
            .Select(row => new UndoRow(row[0].AsInt(), row[1] is RubyInteger id ? id.AsInt() : 0, row[2] is RubyBool { Flag: true }, row[3] is RubyBool { Flag: true }))];
        return new RubyArray(FreezeRules.Undo(rows, switches, variables).Select(choice => (RubyValue)choice));
    }
}
