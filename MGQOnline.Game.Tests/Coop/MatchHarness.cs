//----------------------------------------------------------------
//  MatchHarness.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Told a player away as the room does
//      Paulinchen  2026-10-30: Replayed the invites, the requests to lead and the rivals as the scripts take them
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Coop;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Tests.Coop;

/// <summary>
/// Replays the matchmaking's golden scenarios (fixtures/coop/match.json and invites.json) on a
/// <see cref="CoopMatchmaking"/>: each step sets the world as the old scripts saw it, runs its
/// operation as the scripts run it, taking the steps the scripts take, and notes what was sent,
/// shown, logged and done, as the scenario recorded it.
/// </summary>
internal sealed class MatchHarness : ICoopWorld, ICoopHost
{
    /// <summary>
    /// The players of the step.
    /// </summary>
    private List<Peer> peers = [];

    /// <summary>
    /// The party's leader of the step.
    /// </summary>
    private PartyLeader? leader;

    /// <summary>
    /// The clock in milliseconds.
    /// </summary>
    private long now;

    /// <summary>
    /// The number the stretched steps are varied by.
    /// </summary>
    private double draw;

    /// <summary>
    /// The battle ids made up so far.
    /// </summary>
    private int ids;

    /// <summary>
    /// The facts the game tells, which a battle made live changes.
    /// </summary>
    private CoopFacts facts = CoopFacts.None;

    /// <summary>
    /// Initializes the harness with a fresh matchmaking.
    /// </summary>
    public MatchHarness()
    {
        Match = new CoopMatchmaking(this, this, () => now, () => draw, _ => "b" + (++ids).ToString(CultureInfo.InvariantCulture));
    }

    /// <summary>
    /// Gets the matchmaking.
    /// </summary>
    public CoopMatchmaking Match { get; }

    /// <summary>
    /// Gets the messages sent in the step, [seat, text] each.
    /// </summary>
    public List<object[]> Sent { get; } = [];

    /// <summary>
    /// Gets what the notification box was told in the step.
    /// </summary>
    public List<object?[]> Box { get; } = [];

    /// <summary>
    /// Gets the steps the scripts took in the step.
    /// </summary>
    public List<object?[]> Actions { get; } = [];

    /// <summary>
    /// Gets the log lines of the step.
    /// </summary>
    public List<string> Logs { get; } = [];

    /// <summary>
    /// Gets the steps the last "steps" operation answered, in hundredths.
    /// </summary>
    public long? Steps { get; private set; }

    /// <inheritdoc />
    public bool InWorld => true;

    /// <inheritdoc />
    public bool Raid { get; private set; }

    /// <inheritdoc />
    public int? OwnSeat { get; private set; }

    /// <inheritdoc />
    public string OwnId => "id-me";

    /// <inheritdoc />
    public long OwnSince { get; private set; }

    /// <inheritdoc />
    public IEnumerable<Peer> Peers => peers;

    /// <inheritdoc />
    public string? PartyId => "p1";

    /// <inheritdoc />
    public IEnumerable<Peer> Members => peers.Where(peer => peer.Member);

    /// <inheritdoc />
    public PartyLeader? Leader => leader;

    /// <inheritdoc />
    public bool InParty => Members.Any();

    /// <inheritdoc />
    public Peer? At(int seat) => peers.Find(peer => peer.Seat == seat);

    /// <inheritdoc />
    public bool Leads(Peer? peer) => leader is { } found && (peer is null ? found.IsMe : ReferenceEquals(found.Peer, peer));

    /// <inheritdoc />
    public bool Send(int seat, string text)
    {
        Sent.Add([seat, text]);
        return true;
    }

    /// <inheritdoc />
    public void Log(string line) => Logs.Add(line);

    /// <inheritdoc />
    public void Notice(string key, int? seat, string text, int frames) => Box.Add(["message", key, seat, text, frames]);

    /// <inheritdoc />
    public void DropNotice(string key, int? seat, string? reason) => Box.Add(["drop", key, seat, reason]);

    /// <summary>
    /// Runs a step of a scenario.
    /// </summary>
    /// <param name="step">The step.</param>
    public void Run(JsonElement step)
    {
        Sent.Clear();
        Box.Clear();
        Actions.Clear();
        Logs.Clear();
        Steps = null;
        SetWorld(step.GetProperty("world"));
        JsonElement args = step.GetProperty("args");
        switch (step.GetProperty("op").GetString())
        {
            case "offer":
                Offer(OfferOf(args, args.GetProperty("troop").GetInt32(), args.GetProperty("encounter").GetBoolean(), false), args);
                break;
            case "poll":
                Poll(args);
                break;
            case "steps":
                draw = args.GetProperty("rand").GetDouble();
                Steps = Match.Steps(args.GetProperty("steps").GetInt64());
                break;
            case "soon":
                Match.TakeSoon(At(args.GetProperty("seat").GetInt32())!);
                break;
            case "freeze":
                Match.TakeFreeze(At(args.GetProperty("seat").GetInt32())!, args.GetProperty("map").GetString());
                break;
            case "unfreeze":
                Match.UnfreezeFor(At(args.GetProperty("seat").GetInt32())!, args.GetProperty("other_invite").GetBoolean());
                break;
            case "take":
                Take(At(args.GetProperty("seat").GetInt32())!, FieldsOf(args.GetProperty("message")));
                break;
            case "take_map":
                Match.DropMapMessage(At(args.GetProperty("seat").GetInt32()), FieldsOf(args.GetProperty("message")).Text("map_coop"));
                break;
            case "leader_wait":
                LeaderWait(args);
                break;
            case "yield":
                Apply(Match.Yield());
                break;
            case "decline_waiting":
                Match.DeclineWaiting(args.GetProperty("reason").GetString()!);
                break;
        }
    }

    /// <summary>
    /// Reads the battle a step offers, with the facts the old scripts read beside it.
    /// </summary>
    /// <param name="args">The step's arguments.</param>
    /// <param name="troop">The troop.</param>
    /// <param name="encounter">Whether it is a random encounter.</param>
    /// <param name="askedHot">Whether a running battle did not take it in.</param>
    /// <returns>The battle.</returns>
    private static CoopOffer OfferOf(JsonElement args, int troop, bool encounter, bool askedHot)
    {
        JsonElement leading = args.GetProperty("leading");
        return new CoopOffer(
            troop,
            true,
            false,
            encounter,
            args.GetProperty("encountering").GetBoolean(),
            args.GetProperty("joining").GetBoolean(),
            askedHot,
            args.GetProperty("side").GetBoolean(),
            args.GetProperty("pools_won").GetBoolean(),
            args.GetProperty("boss").GetBoolean(),
            args.GetProperty("rates").GetString()!,
            [.. args.GetProperty("invite_fields").EnumerateArray().Select(pair => new KeyValuePair<string, string>(pair[0].GetString()!, pair[1].GetString()!))],
            Seats(args.GetProperty("viewers")),
            leading.ValueKind == JsonValueKind.Null ? null : (leading[0].GetInt32(), leading[1].GetString()!),
            Seats(args.GetProperty("stays_out")));
    }

    /// <summary>
    /// Reads seats.
    /// </summary>
    /// <param name="list">The seats.</param>
    /// <returns>The seats.</returns>
    private static List<int> Seats(JsonElement list) => [.. list.EnumerateArray().Select(seat => seat.GetInt32())];

    /// <summary>
    /// Reads a message as the scripts read it, its fields in order.
    /// </summary>
    /// <param name="message">The message.</param>
    /// <returns>The fields.</returns>
    private static WorldFields FieldsOf(JsonElement message)
    {
        var fields = new WorldFields();
        foreach (JsonProperty field in message.EnumerateObject())
        {
            fields.Set(field.Name, field.Value.GetString()!);
        }

        return fields;
    }

    /// <summary>
    /// Reads a host and battle the scripts told.
    /// </summary>
    /// <param name="facts">The facts.</param>
    /// <param name="name">The fact.</param>
    /// <returns>The host's seat and the battle's id, <see langword="null"/> for none.</returns>
    private static (int Seat, string BattleId)? BattleOf(JsonElement facts, string name) =>
        !facts.TryGetProperty(name, out JsonElement value) || value.ValueKind == JsonValueKind.Null ? null : (value[0].GetInt32(), value[1].GetString()!);

    /// <summary>
    /// Reads a flag the scripts told, false when a step did not record it.
    /// </summary>
    /// <param name="facts">The facts.</param>
    /// <param name="name">The fact.</param>
    /// <returns>Whether it is true.</returns>
    private static bool Flag(JsonElement facts, string name) => facts.TryGetProperty(name, out JsonElement value) && value.ValueKind == JsonValueKind.True;

    /// <summary>
    /// Reads a text the scripts told.
    /// </summary>
    /// <param name="facts">The facts.</param>
    /// <param name="name">The fact.</param>
    /// <returns>The text, <see langword="null"/> for null.</returns>
    private static string? Text(JsonElement facts, string name) => facts.GetProperty(name).ValueKind == JsonValueKind.Null ? null : facts.GetProperty(name).GetString();

    /// <summary>
    /// Sets the world as a step's old scripts saw it.
    /// </summary>
    /// <param name="world">The world.</param>
    private void SetWorld(JsonElement world)
    {
        peers = [];
        foreach (JsonElement entry in world.GetProperty("peers").EnumerateArray())
        {
            peers.Add(new Peer(entry.GetProperty("seat").GetInt32(), FieldsOf(entry.GetProperty("state")))
            {
                Member = entry.GetProperty("member").GetBoolean(),
                Away = entry.GetProperty("away").GetBoolean(),
            });
        }

        JsonElement leaderOf = world.GetProperty("leader");
        leader = leaderOf.ValueKind switch
        {
            JsonValueKind.Null => null,
            JsonValueKind.String => new PartyLeader(null),
            _ => new PartyLeader(At(leaderOf.GetInt32())),
        };
        Raid = world.GetProperty("raid").GetBoolean();
        OwnSeat = world.GetProperty("own_seat").GetInt32();
        OwnSince = world.GetProperty("since").GetInt64();
        now = world.GetProperty("now").GetInt64();
        JsonElement told = world.GetProperty("facts");
        facts = new CoopFacts(
            told.GetProperty("map").GetInt64(),
            told.GetProperty("x").GetInt64(),
            told.GetProperty("y").GetInt64(),
            Text(told, "role"),
            Text(told, "bid"),
            Seats(told.GetProperty("seats")),
            Flag(told, "coop"),
            Flag(told, "running"),
            Text(told, "kind"),
            Flag(told, "pvp"),
            Flag(told, "memory"),
            Flag(told, "battle_scene"),
            Flag(told, "interpreter"),
            Flag(told, "trading"),
            Flag(told, "coming"),
            Flag(told, "transfer"),
            Flag(told, "moving"),
            Flag(told, "active"),
            Flag(told, "late"),
            Flag(told, "own_troop"),
            BattleOf(told, "hot_ask"),
            BattleOf(told, "gave_up"),
            false,
            Flag(told, "story"));
        Match.Take(facts);
    }

    /// <summary>
    /// Offers a battle and takes the steps it asks for, as the scripts' offer does.
    /// </summary>
    /// <param name="offer">The battle.</param>
    /// <param name="args">The step's arguments, with the running battle's answer under "hot_answer".</param>
    private void Offer(CoopOffer offer, JsonElement args)
    {
        foreach (CoopAction action in Match.Offer(offer))
        {
            if (action.Kind == "ask_hot")
            {
                Actions.Add(["ask_hot"]);
                if (!args.GetProperty("hot_answer").GetBoolean())
                {
                    Offer(offer with { AskedHot = true }, args);
                }

                return;
            }

            Apply([action]);
        }
    }

    /// <summary>
    /// Takes the steps the matchmaking asks for, as the scripts take them.
    /// </summary>
    /// <param name="actions">The steps.</param>
    private void Apply(IEnumerable<CoopAction> actions)
    {
        foreach (CoopAction action in actions)
        {
            switch (action.Kind)
            {
                case "join":
                    Join(action.Role!, action.BattleId!, action.Seats!, action.Label!);
                    break;
                case "fight_alone" when facts.Role is null:
                    Actions.Add(["fight_alone"]);
                    break;
                case "accept":
                    if (action.Label == "story")
                    {
                        Actions.Add(["drop_call"]);
                    }

                    Actions.Add(["accept", action.Seat, action.Fields!["bid"]]);
                    break;
                case "lead":
                    Actions.Add(["lead", action.Seat, action.Fields!["bid"]]);
                    break;
                case "yield":
                    Finish();
                    Follow(action);
                    break;
                case "follow":
                    Follow(action);
                    break;
                case "miss" or "break_off" or "call_off_own":
                    Actions.Add([action.Kind, action.Label]);
                    break;
            }
        }
    }

    /// <summary>
    /// Becomes the guest of another battle, as the scripts' adopt_troop and join_world do.
    /// </summary>
    /// <param name="action">The step, with the battle's invite.</param>
    private void Follow(CoopAction action)
    {
        Actions.Add(["adopt", (int)WorldFields.ToI(action.Fields!["troop"])]);
        Join("guest", action.Fields.Text("bid"), [action.Seat!.Value], action.Label!);
    }

    /// <summary>
    /// Makes the battle live, as the scripts' join_world does.
    /// </summary>
    /// <param name="role">The role.</param>
    /// <param name="battleId">The battle's id.</param>
    /// <param name="seats">The other games' seats.</param>
    /// <param name="label">Who the waits name.</param>
    private void Join(string role, string battleId, IReadOnlyList<int> seats, string label)
    {
        Actions.Add(["join", role, battleId, seats.ToArray(), label]);
        facts = facts with { Role = role, BattleId = battleId, Seats = seats, Coop = true, Running = true, Kind = "coop" };
        Match.Take(facts);
    }

    /// <summary>
    /// Ends the live battle, as the scripts' finish does.
    /// </summary>
    private void Finish()
    {
        if (facts.Role is not null)
        {
            Actions.Add(["finish"]);
        }

        facts = facts with { Role = null, BattleId = null, Seats = [], Coop = false, Running = false, Kind = null };
        Match.Take(facts);
    }

    /// <summary>
    /// Takes a co-op message as the routes hand it over, an "off" through the scripts.
    /// </summary>
    /// <param name="peer">Who sent it.</param>
    /// <param name="message">The message.</param>
    private void Take(Peer peer, WorldFields message)
    {
        if (message["coop"] != "off")
        {
            Match.TakeMessage(peer, message);
            return;
        }

        string fields = string.Join(" ", message.Where(field => field.Key != "coop").Select(field => $"{field.Key}={field.Value}"));
        Logs.Add($"co-op battle: took off from {CoopMatchmaking.Who(peer)}: {fields}");
        Apply(Match.TakeOff(peer, message));
    }

    /// <summary>
    /// Waits for the party's leader as the scripts' wait does, a message coming at a frame and the
    /// wait ending by itself at a frame; then the player hosts the battle should the leader not lead it.
    /// </summary>
    /// <param name="args">The step's arguments.</param>
    private void LeaderWait(JsonElement args)
    {
        int? injectAt = args.GetProperty("inject_at").ValueKind == JsonValueKind.Null ? null : args.GetProperty("inject_at").GetInt32();
        int? endAt = args.GetProperty("end_at").ValueKind == JsonValueKind.Null ? null : args.GetProperty("end_at").GetInt32();
        string? answer = null;
        for (int frame = 1; answer is null; frame++)
        {
            if (frame == injectAt)
            {
                Take(At(args.GetProperty("seat").GetInt32())!, FieldsOf(args.GetProperty("message")));
            }

            answer = frame == endAt ? args.GetProperty("ending").GetString() : Match.LeaderWait();
        }

        if (Match.LeaderEnd(answer) is { } hosted)
        {
            Finish();
            Apply(Match.Host(hosted, null));
        }
    }

    /// <summary>
    /// Runs frames on the map, starting a held encounter, joining an invite and leading a request as
    /// the scripts do.
    /// </summary>
    /// <param name="args">The step's arguments.</param>
    private void Poll(JsonElement args)
    {
        List<int> asked = Seats(args.GetProperty("asked"));
        for (int frame = 0; frame < args.GetProperty("count").GetInt32(); frame++)
        {
            foreach (CoopAction action in Match.Poll(asked))
            {
                if (action.Kind != "start_held")
                {
                    Apply([action]);
                    continue;
                }

                Offer(OfferOf(args, action.Troop!.Value, true, false) with { Escape = action.Escape, Lose = action.Lose }, args);
                Match.Release(action.Seats ?? [], asked);
                Actions.Add(["call", "Scene_Battle"]);
            }
        }
    }
}
