//----------------------------------------------------------------
//  CoopTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Set how long a late guest waits for the roster and answered the limit of every wait for it
//      Paulinchen  2026-11-06: Answered whether a character fights at the battle's level and what its equipment keeps
//      Paulinchen  2026-11-05: Took the seats an encounter brings along as numbers
//                            - Took the widths every request to join a battle carries
//                            - Told whether the running battle takes players in or why not, which Sessions reads in the other games
//                            - Timed the players taken in by the bridge's frame
//      Paulinchen  2026-10-30: Kept the widths of a served battle's troop its setup carries
//                            - Collected the joins of a gathered battle, the roster and the players taken in from the live session
//                            - Placed enemies by the widths the players who asked to join measured
//                            - Answered the battle's level, the roster's lines, the troop's repair and the departures
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Numerics;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Battles.Live;
using MGQOnline.Game.Battles.Wire;
using MGQOnline.Game.Coop;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Topics;

/// <summary>
/// The bridge topics of the co-op battles' rules that both hosts answer through
/// <see cref="SharedTopics"/>, since the scripts that ask them run in the player's game and on the
/// battle server: the host's intake of players who join a running battle, the battle's level, its
/// roster and party lines, the host's troop repaired on a guest, the departures, and the joins the
/// live battle's session holds.
/// </summary>
public static class CoopTopics
{
    /// <summary>
    /// Places the enemies of an encounter a running battle takes in, see
    /// <see cref="EnemyPlacement.PlaceFirst"/>: <c>bid</c>, <c>troop</c> ([id, x, width, hidden,
    /// fallen] each), <c>queued</c> ([id, x, width] each), <c>entries</c> ([id, y, width] each),
    /// <c>screen</c> and, from a request, <c>widths</c> (see <see cref="EnemyWidths"/>, kept for the
    /// battle) in; the enemies placed out, [id, x, y] each. A width the battle kept stands for the
    /// one this game measured.
    /// </summary>
    public const string Place = "coop.place";

    /// <summary>
    /// Writes the widths of an encounter's enemies a request tells, see <see cref="EnemyWidths.Write"/>:
    /// [id, width] each in, the text out.
    /// </summary>
    public const string WriteWidths = "coop.write_widths";

    /// <summary>
    /// Keeps the widths of a battle's troop for its placements, as the battle server takes them from
    /// a served battle's setup: <c>bid</c> and <c>widths</c> (see <see cref="EnemyWidths"/>) in;
    /// nothing out.
    /// </summary>
    public const string KeepWidths = "coop.keep_widths";

    /// <summary>
    /// Reads the enemies a request carries, see <see cref="TroopEntries.Read"/>: the text in;
    /// [id, x, y, mark] each out.
    /// </summary>
    public const string ReadEntries = "coop.read_entries";

    /// <summary>
    /// Writes the enemies a request carries, see <see cref="TroopEntries.Write"/>: the enemies'
    /// fields in, the text out.
    /// </summary>
    public const string WriteEntries = "coop.write_entries";

    /// <summary>
    /// Checks a request to join the running battle, see <see cref="JoinIntake.Refusal"/>:
    /// <c>kind</c> ("encounter" or "choice"), <c>facts</c> (see <see cref="FactsOf"/>), <c>seat</c>,
    /// <c>bid</c>, <c>map</c>, <c>troop</c>, <c>boss_troop</c> and <c>seats</c> (the seats an
    /// encounter brings along, nil for none) in; <c>refusal</c> ([code, reason], nil to take it), and
    /// for an encounter <c>kept</c>, <c>left</c> and <c>room</c> (see <see cref="JoinIntake.Fit"/>) out.
    /// </summary>
    public const string Intake = "coop.intake";

    /// <summary>
    /// Tells the running battle as the player's state tells it, see <see cref="JoinIntake.Told"/>:
    /// the facts in; the state's fields <c>rbn</c> and <c>rbs</c> out.
    /// </summary>
    public const string Room = "coop.room";

    /// <summary>
    /// Works out the battle's level, see <see cref="CoopLevel.Of"/>: <c>raid</c> and <c>players</c>
    /// ([seat, leads, places, levels] each) in; <c>level</c> (nil for none) and <c>log</c> out.
    /// </summary>
    public const string Level = "coop.level";

    /// <summary>
    /// Works out a character's sync, see <see cref="CoopLevel.Sync"/>: <c>level</c>, <c>kind</c>,
    /// <c>own_level</c>, and <c>own</c> and <c>bases</c> (each stat as decimal text) in;
    /// <c>equipment</c> (each stat's share as decimal text) or <c>why</c> out.
    /// </summary>
    public const string Sync = "coop.sync";

    /// <summary>
    /// Writes a roster, see <see cref="CoopRoster.WriteRoster"/>: <c>enemies</c>, <c>players</c>
    /// (each player's fields), <c>level</c> and, for players who join late, <c>turn</c> in; the
    /// line out.
    /// </summary>
    public const string WriteRoster = "coop.write_roster";

    /// <summary>
    /// Writes the party the host tells its guests: the players' fields in, the line out.
    /// </summary>
    public const string WriteParty = "coop.write_party";

    /// <summary>
    /// Reads a roster, see <see cref="CoopRoster.ReadRoster"/>: <c>line</c>, <c>own</c> (this
    /// game's troop, [x, y] each) and <c>count</c> (the size of its table of enemies) in;
    /// <c>size</c> (the enemies sent), <c>enemies</c> (see <see cref="Repair"/>), <c>players</c>,
    /// <c>dropped</c> (the players' fields left out), <c>enemy_dropped</c>, <c>lacking</c>,
    /// <c>level</c> and <c>turn</c> out.
    /// </summary>
    public const string ReadRoster = "coop.read_roster";

    /// <summary>
    /// Reads the party the host tells its guests: the line in; <c>players</c> and <c>dropped</c> out.
    /// </summary>
    public const string ReadParty = "coop.read_party";

    /// <summary>
    /// Reads the troop the host tells its guests once it changed: <c>line</c>, <c>own</c> and
    /// <c>count</c> in; <c>enemies</c>, <c>enemy_dropped</c>, <c>lacking</c> (see
    /// <see cref="Repair"/>) and <c>names</c> (nil for none) out.
    /// </summary>
    public const string ReadTroop = "coop.read_troop";

    /// <summary>
    /// Repairs the host's enemies a guest fights, see <see cref="TroopRepair.Repair"/>:
    /// <c>enemies</c> (each a list of four fields, a whole number or the class name of a field of
    /// another kind, or the class name of an enemy that is no list), <c>own</c> and <c>count</c> in;
    /// <c>enemies</c> ([id, x, y, mark] each, nil to keep this game's troop), <c>enemy_dropped</c>
    /// ([field, kind, owner] each) and <c>lacking</c> (the ids this game lacks) out.
    /// </summary>
    public const string Repair = "coop.repair";

    /// <summary>
    /// Decides what the host does once players left, see <see cref="CoopDepartures.Settle"/>:
    /// <c>players</c>, <c>own</c>, <c>in</c> (the guests still in) and <c>served</c> in;
    /// <c>staying</c>, <c>left</c> and <c>outcome</c> ("none", "reform", "solo" or "abandon") out.
    /// </summary>
    public const string Settle = "coop.settle";

    /// <summary>
    /// The host's gathering of the players it invited, see <see cref="CoopJoins.GatherFrame"/>:
    /// <c>op</c> "start" with <c>seats</c> and <c>limit</c>, "frame" with <c>gone</c> (the invited
    /// players the world no longer knows) or "end" in; nil, whether the gathering is over, or
    /// <c>joined</c> ([seat, join] each, in the order they came), <c>outcomes</c> ([seat, outcome or
    /// nil] each) and <c>frames</c> out.
    /// </summary>
    public const string Gather = "coop.gather";

    /// <summary>
    /// A guest's wait for the host's roster, see <see cref="CoopJoins.RosterFrame"/>: <c>op</c>
    /// "start" with <c>limit</c>, or with <c>late</c> true for a player who joins a running battle
    /// (<see cref="CoopJoins.LateRosterFrames"/>), or "frame" with <c>restart</c> (the new limit once
    /// the battle went to the battle server, nil otherwise) in; the limit set, or <c>roster</c> (nil
    /// before it came), <c>late</c> and <c>frames</c> out.
    /// </summary>
    public const string RosterWait = "coop.roster_wait";

    /// <summary>
    /// The host's players taken into its running battle who have not joined yet, see
    /// <see cref="CoopJoins"/>: <c>op</c> "take_in" (with <c>requester</c>, <c>seats</c> and
    /// <c>enemies</c>), "release" (with <c>seat</c>; [seat, reason] each out), "expire" (with
    /// <c>gone</c>; [seat, reason, tell off] each out), "joins" ([seat, join] each out),
    /// "next_added" (with <c>seats</c>; the enemies of the next encounter whose player joined out,
    /// nil for none), "remove" (with <c>seats</c>), "take_off" (with <c>seat</c>; whether it was
    /// taken in out), "call_off" (the seats out), "seats", "queued" (the enemies still to join out) or
    /// "count" in.
    /// </summary>
    public const string Pending = "coop.pending";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="session">The live battle's session, whose messages hold the joins.</param>
    public static void Register(BridgeContext context, LiveSession session)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(session);
        var joins = new CoopJoins(session);
        context.Register(Gather, (_, request) => GatherOf(joins, request.AsHash()));
        context.Register(RosterWait, (_, request) => RosterOf(joins, request.AsHash()));
        context.Register(Pending, (host, request) => PendingOf(joins, request.AsHash(), host.Frame));
        var widths = new EnemyWidths();
        context.Register(Place, (_, request) => PlaceOf(request.AsHash(), widths));
        context.Register(KeepWidths, (_, request) =>
        {
            RubyHash kept = request.AsHash();
            widths.Note(TextOf(kept["bid"]) ?? string.Empty, kept["widths"].AsText());
            return null;
        });
        context.Register(WriteWidths, (_, request) => EnemyWidths.Write(request.AsArray().Select(pair => (pair.AsArray()[0].AsLong(), pair.AsArray()[1].AsLong()))));
        context.Register(ReadEntries, (_, request) => new RubyArray(TroopEntries.Read(request.IsNil ? null : request.AsText())
            .Select(entry => (RubyValue)new RubyArray { entry.Id, entry.X, entry.Y, entry.Mark })));
        context.Register(WriteEntries, (_, request) => TroopEntries.Write(request.AsArray().Select(entry => entry.AsArray().Select(field => field.AsLong()).ToList())));
        context.Register(Intake, (_, request) => IntakeOf(request.AsHash(), joins));
        context.Register(Room, (_, request) =>
        {
            (int rbn, string rbs) = JoinIntake.Told(FactsOf(request.AsHash(), joins));
            return new RubyHash { { "rbn", rbn }, { "rbs", rbs } };
        });
        context.Register(Level, (_, request) => LevelOf(request.AsHash()));
        context.Register(Sync, (_, request) => SyncOf(request.AsHash()));
        context.Register(WriteRoster, (_, request) =>
        {
            RubyHash fields = request.AsHash();
            return CoopRoster.WriteRoster(WireOf(fields["enemies"]), WireOf(fields["players"]), WireOf(fields["level"]),
                fields.ContainsKey("turn") ? WireOf(fields["turn"]) : null);
        });
        context.Register(WriteParty, (_, request) => CoopRoster.WriteParty(WireOf(request)));
        context.Register(ReadRoster, (_, request) => RosterOf(request.AsHash()));
        context.Register(ReadParty, (_, request) => PlayersOf(CoopRoster.ReadParty(request.AsText()), new RubyHash()));
        context.Register(ReadTroop, (_, request) =>
        {
            RubyHash fields = request.AsHash();
            (List<HostEnemy> enemies, string? names) = CoopRoster.ReadTroop(fields["line"].AsText());
            RubyHash answer = RepairOf(enemies, fields);
            answer.Add("names", names);
            return answer;
        });
        context.Register(Repair, (_, request) =>
        {
            RubyHash fields = request.AsHash();
            return RepairOf([.. fields["enemies"].AsArray().Select(PlainEnemy)], fields);
        });
        context.Register(Settle, (_, request) => SettleOf(request.AsHash()));
    }

    /// <summary>
    /// Reads the facts of the running battle as the scripts hand them over.
    /// </summary>
    /// <param name="facts">{"bid", "host", "own_seat", "role", "seats", "live", "active", "solo",
    /// "ending", "boss", "pvp", "players", "pending" (left out where the joins know them), "map"}.</param>
    /// <param name="joins">The joins, whose players taken in count when the facts name none.</param>
    /// <returns>The facts.</returns>
    internal static IntakeFacts FactsOf(RubyHash facts, CoopJoins? joins = null) => new(
        TextOf(facts["bid"]),
        facts["host"].IsNil ? null : facts["host"].AsLong(),
        facts["own_seat"].AsLong(),
        TextOf(facts["role"]),
        Seats(facts["seats"]),
        IsTrue(facts["live"]),
        IsTrue(facts["active"]),
        IsTrue(facts["solo"]),
        IsTrue(facts["ending"]),
        IsTrue(facts["boss"]),
        IsTrue(facts["pvp"]),
        facts["players"].AsInt(),
        facts.ContainsKey("pending") ? Seats(facts["pending"]) : [.. (joins?.PendingSeats ?? []).Select(seat => (long)seat)],
        facts["map"].AsLong());

    /// <summary>
    /// Answers <see cref="Level"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The level and its log line.</returns>
    private static RubyHash LevelOf(RubyHash request)
    {
        List<LevelPlayer> players = [.. request["players"].AsArray().Select(entry => entry.AsArray()).Select(player => new LevelPlayer(
            player[0].AsLong(),
            IsTrue(player[1]),
            [.. player[2].AsArray().Select(place => place.AsLong())],
            [.. player[3].AsArray().Select(level => level.IsNil ? null : (long?)level.AsLong())]))];
        (long? level, string log) = CoopLevel.Of(IsTrue(request["raid"]), players);
        return new RubyHash { { "level", level is { } found ? found : RubyNil.Value }, { "log", log } };
    }

    /// <summary>
    /// Answers <see cref="Sync"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The equipment's shares, or why the character is not synced.</returns>
    private static RubyHash SyncOf(RubyHash request)
    {
        static List<double> Stats(RubyValue stats) => [.. stats.AsArray().Select(stat => double.Parse(stat.AsText(), NumberStyles.Float, CultureInfo.InvariantCulture))];
        (IReadOnlyList<double>? equipment, string? why) = CoopLevel.Sync(request["level"].AsLong(), request["kind"].AsText(), request["own_level"].AsLong(), Stats(request["own"]), Stats(request["bases"]));
        return equipment is null
            ? new RubyHash { { "why", why } }
            : new RubyHash { { "equipment", new RubyArray(equipment.Select(share => (RubyValue)share.ToString("R", CultureInfo.InvariantCulture))) } };
    }

    /// <summary>
    /// Answers <see cref="ReadRoster"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The roster.</returns>
    private static RubyHash RosterOf(RubyHash request)
    {
        RosterLine roster = CoopRoster.ReadRoster(request["line"].AsText());
        RubyHash answer = RepairOf(roster.Enemies, request);
        answer.Add("size", roster.Enemies.Count);
        answer.Add("level", Number(roster.Level));
        answer.Add("turn", Number(roster.Turn));
        return PlayersOf(roster.Players, answer);
    }

    /// <summary>
    /// Adds the players a line named to an answer.
    /// </summary>
    /// <param name="players">The players.</param>
    /// <param name="answer">The answer.</param>
    /// <returns>The answer, with <c>players</c> and <c>dropped</c>.</returns>
    private static RubyHash PlayersOf(RosterPlayers players, RubyHash answer)
    {
        answer.Add("players", new RubyArray(players.Players.Select(player => (RubyValue)new RubyArray
        {
            new RubyInteger(player.Seat),
            player.Name,
            player.Builds,
            new RubyArray(player.Vitals.Select(vitals => vitals is null ? RubyNil.Value : (RubyValue)new RubyArray(vitals.Select(number => Number(number))))),
            Number(player.Max),
            player.Order is null ? RubyNil.Value : new RubyArray(player.Order.Select(place => (RubyValue)new RubyInteger(place))),
            Number(player.Front),
            Number(player.Bench),
        })));
        answer.Add("dropped", Drops(players.Drops));
        return answer;
    }

    /// <summary>
    /// Repairs the host's enemies for an answer.
    /// </summary>
    /// <param name="enemies">The host's enemies as sent.</param>
    /// <param name="request">The request, with <c>own</c> and <c>count</c>.</param>
    /// <returns>The answer, with <c>enemies</c>, <c>enemy_dropped</c> and <c>lacking</c>.</returns>
    private static RubyHash RepairOf(List<HostEnemy> enemies, RubyHash request)
    {
        List<(BigInteger X, BigInteger Y)> own = [.. request["own"].AsArray().Select(place => place.AsArray())
            .Select(place => (((RubyInteger)place[0]).Value, ((RubyInteger)place[1]).Value))];
        RepairedTroop troop = TroopRepair.Repair(enemies, own, request["count"].AsLong());
        return new RubyHash
        {
            { "enemies", troop.Enemies is null ? RubyNil.Value : new RubyArray(troop.Enemies.Select(entry => (RubyValue)new RubyArray(entry.Select(field => (RubyValue)new RubyInteger(field))))) },
            { "enemy_dropped", Drops(troop.Drops) },
            { "lacking", new RubyArray(troop.Lacking.Select(id => (RubyValue)new RubyInteger(id))) },
        };
    }

    /// <summary>
    /// Reads an enemy the scripts hand over as the host sent it: four fields, each a whole number or
    /// the class name of a field of another kind, or the class name of an enemy that is no list.
    /// </summary>
    /// <param name="value">The enemy.</param>
    /// <returns>The enemy.</returns>
    private static HostEnemy PlainEnemy(RubyValue value)
    {
        if (value is not RubyArray fields)
        {
            return new HostEnemy(null, value.AsText());
        }

        return new HostEnemy([.. Enumerable.Range(0, TroopRepair.FieldCount).Select(index => index >= fields.Count ? new EnemyField(null, "NilClass")
            : fields[index] is RubyInteger number ? new EnemyField(number.Value, "Integer") : new EnemyField(null, fields[index].AsText()))], "Array");
    }

    /// <summary>
    /// Answers <see cref="Settle"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The decision.</returns>
    private static RubyHash SettleOf(RubyHash request)
    {
        (List<long> staying, List<long> left, DepartureOutcome outcome) = CoopDepartures.Settle(Seats(request["players"]), request["own"].AsLong(),
            Seats(request["in"]), IsTrue(request["served"]));
        return new RubyHash { { "staying", Seats(staying) }, { "left", Seats(left) }, { "outcome", outcome.ToString().ToLowerInvariant() } };
    }

    /// <summary>
    /// Writes fields left out as the scripts log them.
    /// </summary>
    /// <param name="drops">The fields.</param>
    /// <returns>[field, kind, owner] each.</returns>
    private static RubyArray Drops(IEnumerable<FieldDrop> drops) => new(drops.Select(drop => (RubyValue)new RubyArray { drop.Field, drop.Kind, drop.Owner }));

    /// <summary>
    /// Writes a number that may be missing.
    /// </summary>
    /// <param name="number">The number.</param>
    /// <returns>The Integer, nil for none.</returns>
    private static RubyValue Number(BigInteger? number) => number is { } found ? new RubyInteger(found) : RubyNil.Value;

    /// <summary>
    /// Takes a plain value the scripts hand over as a value of a battle line.
    /// </summary>
    /// <param name="value">The value: nil, true, false, an Integer, a String or an Array of them.</param>
    /// <returns>The line's value.</returns>
    /// <exception cref="BridgeRequestException">The value is of another kind.</exception>
    private static WireValue WireOf(RubyValue value) => value switch
    {
        RubyNil => WireNil.Value,
        RubyBool flag => flag.Flag,
        RubyInteger number => new WireInteger(number.Value),
        RubyString text => new WireString(text.Text),
        RubyArray list => new WireList([.. list.Select(WireOf)]),
        _ => throw new BridgeRequestException($"{value.KindName} cannot go into a battle line."),
    };

    /// <summary>
    /// Answers a step of the host's gathering.
    /// </summary>
    /// <param name="joins">The joins.</param>
    /// <param name="request">The request, see <see cref="Gather"/>.</param>
    /// <returns>The answer.</returns>
    private static RubyValue GatherOf(CoopJoins joins, RubyHash request)
    {
        switch (request["op"].AsText())
        {
            case "start":
                joins.StartGather([.. Seats(request["seats"]).Select(seat => (int)seat)], request["limit"].AsInt());
                return RubyNil.Value;
            case "frame":
                return joins.GatherFrame([.. Seats(request["gone"]).Select(seat => (int)seat)]);
            default:
                GatherEnd end = joins.EndGather();
                return new RubyHash
                {
                    { "joined", new RubyArray(end.Joined.Select(join => (RubyValue)new RubyArray { join.Key, join.Value })) },
                    { "outcomes", new RubyArray(end.Outcomes.Select(outcome => (RubyValue)new RubyArray { outcome.Seat, outcome.Outcome })) },
                    { "frames", end.Frames },
                };
        }
    }

    /// <summary>
    /// Answers a step of a guest's wait for the roster.
    /// </summary>
    /// <param name="joins">The joins.</param>
    /// <param name="request">The request, see <see cref="RosterWait"/>.</param>
    /// <returns>The answer.</returns>
    private static RubyValue RosterOf(CoopJoins joins, RubyHash request)
    {
        if (request["op"].AsText() == "start")
        {
            int limit = IsTrue(request["late"]) ? CoopJoins.LateRosterFrames : request["limit"].AsInt();
            joins.StartRoster(limit);
            return limit;
        }

        RosterWait wait = joins.RosterFrame(request["restart"].IsNil ? null : request["restart"].AsInt());
        return new RubyHash { { "roster", wait.Roster }, { "late", wait.Late }, { "frames", wait.Frames } };
    }

    /// <summary>
    /// Answers a step of the host's list of the players taken in.
    /// </summary>
    /// <param name="joins">The joins.</param>
    /// <param name="request">The request, see <see cref="Pending"/>.</param>
    /// <param name="frame">The bridge's frame, the clock.</param>
    /// <returns>The answer.</returns>
    private static RubyValue PendingOf(CoopJoins joins, RubyHash request, long frame)
    {
        long now = GameClock.Milliseconds(frame);
        List<int> SeatsOf(string field) => [.. Seats(request[field]).Select(seat => (int)seat)];
        switch (request["op"].AsText())
        {
            case "take_in":
                joins.TakeIn(request["requester"].AsInt(), SeatsOf("seats"), EntriesOf(request["enemies"]), now);
                return RubyNil.Value;
            case "release":
                return new RubyArray(joins.ReleaseCompanion(request["seat"].AsInt()).Select(drop => (RubyValue)new RubyArray { drop.Seat, drop.Reason }));
            case "expire":
                return new RubyArray(joins.Expire(now, SeatsOf("gone")).Select(drop => (RubyValue)new RubyArray { drop.Seat, drop.Reason, drop.TellOff }));
            case "joins":
                return new RubyArray(joins.TakeJoins().Select(join => (RubyValue)new RubyArray { join.Seat, join.Body }));
            case "next_added":
                return joins.NextAdded(SeatsOf("seats")) is { } enemies ? Entries(enemies) : RubyNil.Value;
            case "remove":
                joins.Remove(SeatsOf("seats"));
                return RubyNil.Value;
            case "take_off":
                return joins.TakeOff(request["seat"].AsInt());
            case "call_off":
                return new RubyArray(joins.CallOff().Select(seat => (RubyValue)seat));
            case "queued":
                return Entries(joins.QueuedEnemies);
            case "count":
                return joins.Count;
            default:
                return new RubyArray(joins.PendingSeats.Select(seat => (RubyValue)seat));
        }
    }

    /// <summary>
    /// Reads enemies the scripts hand over.
    /// </summary>
    /// <param name="value">[id, x, y, mark] each, nil for none.</param>
    /// <returns>The enemies.</returns>
    private static List<IReadOnlyList<long>> EntriesOf(RubyValue value) =>
        value.IsNil ? [] : [.. value.AsArray().Select(entry => (IReadOnlyList<long>)[.. entry.AsArray().Select(field => field.AsLong())])];

    /// <summary>
    /// Writes enemies for the scripts.
    /// </summary>
    /// <param name="entries">The enemies.</param>
    /// <returns>[id, x, y, mark] each.</returns>
    private static RubyArray Entries(IEnumerable<IReadOnlyList<long>> entries) =>
        new(entries.Select(entry => (RubyValue)new RubyArray(entry.Select(field => (RubyValue)field))));

    /// <summary>
    /// Answers <see cref="Place"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <param name="widths">The widths kept for the battle.</param>
    /// <returns>The enemies placed.</returns>
    private static RubyArray PlaceOf(RubyHash request, EnemyWidths widths)
    {
        string bid = TextOf(request["bid"]) ?? string.Empty;
        if (request.ContainsKey("widths"))
        {
            widths.Note(bid, request["widths"].AsText());
        }

        int Width(RubyArray row, int index) => widths.Of(bid, row[0].AsLong(), row[index].AsInt());
        List<TroopSpot> troop = [.. request["troop"].AsArray().Select(spot => spot.AsArray())
            .Select(spot => new TroopSpot(spot[1].AsInt(), Width(spot, 2), IsTrue(spot[3]), IsTrue(spot[4])))];
        List<QueuedSpot> queued = [.. request["queued"].AsArray().Select(spot => spot.AsArray()).Select(spot => new QueuedSpot(spot[1].AsInt(), Width(spot, 2)))];
        List<NewEnemy> entries = [.. request["entries"].AsArray().Select(entry => entry.AsArray())
            .Select(entry => new NewEnemy(entry[0].AsInt(), entry[1].AsInt(), Width(entry, 2)))];
        return new RubyArray(EnemyPlacement.PlaceFirst(troop, queued, entries, request["screen"].AsInt())
            .Select(placed => (RubyValue)new RubyArray { placed.Id, placed.X, placed.Y }));
    }

    /// <summary>
    /// Answers <see cref="Intake"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <param name="joins">The joins, whose players taken in count for a battle's facts that name none.</param>
    /// <returns>The refusal, and for an encounter the players it brings in.</returns>
    /// <exception cref="BridgeRequestException">The kind is none the intake knows.</exception>
    private static RubyHash IntakeOf(RubyHash request, CoopJoins joins)
    {
        IntakeKind kind = TextOf(request["kind"]) switch
        {
            "encounter" => IntakeKind.Encounter,
            "choice" => IntakeKind.Choice,
            string other => throw new BridgeRequestException($"There is no request to join of the kind {other}."),
            null => throw new BridgeRequestException("A request to join names no kind."),
        };
        IntakeFacts facts = FactsOf(request["facts"].AsHash(), joins);
        long seat = request["seat"].AsLong();
        IntakeRefusal? refusal = JoinIntake.Refusal(facts, kind, seat, TextOf(request["bid"]), TextOf(request["map"]), TextOf(request["troop"]), IsTrue(request["boss_troop"]));
        var answer = new RubyHash { { "refusal", refusal is null ? RubyNil.Value : new RubyArray { refusal.Code, refusal.Reason } } };
        if (kind == IntakeKind.Encounter)
        {
            IntakeFit fit = JoinIntake.Fit(facts, seat, MessageFields.Write("seats", request["seats"]));
            answer.Add("kept", Seats(fit.Kept));
            answer.Add("left", Seats(fit.Left));
            answer.Add("room", fit.Room);
        }

        return answer;
    }

    /// <summary>
    /// Reads a list of seats.
    /// </summary>
    /// <param name="value">The list, nil for none.</param>
    /// <returns>The seats.</returns>
    private static List<long> Seats(RubyValue value) => value.IsNil ? [] : [.. value.AsArray().Select(seat => seat.AsLong())];

    /// <summary>
    /// Writes a list of seats.
    /// </summary>
    /// <param name="seats">The seats.</param>
    /// <returns>The list.</returns>
    private static RubyArray Seats(IEnumerable<long> seats) => new(seats.Select(seat => (RubyValue)seat));

    /// <summary>
    /// Reads a text that may be nil.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The text, <see langword="null"/> for nil.</returns>
    private static string? TextOf(RubyValue value) => value.IsNil ? null : value.AsText();

    /// <summary>
    /// Reads a flag, nil as false.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>Whether it is true.</returns>
    private static bool IsTrue(RubyValue value) => value is RubyBool { Flag: true };
}
