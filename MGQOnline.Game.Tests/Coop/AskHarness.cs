//----------------------------------------------------------------
//  AskHarness.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Coop;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Tests.Coop;

/// <summary>
/// Replays the golden scenarios of asking a running battle and of joining one by choice
/// (fixtures/coop/asks.json) on <see cref="CoopAsking"/> and <see cref="JoinChoice"/>: each step
/// sets the world as the scripts saw it, runs its operation as the scripts now run it, taking the
/// steps the scripts take, and notes what was sent, shown, logged, done and answered.
/// </summary>
internal sealed class AskHarness : ICoopWorld, ICoopHost
{
    /// <summary>
    /// The scripts' reasons the player may not join a battle that come before the player's own request.
    /// </summary>
    private static readonly string[] BusyBefore =
        ["no world is open", "not a Raid World", "the map is not free: an event, a message or a transfer", "the player is in a multiplayer battle"];

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
    /// The facts the game tells.
    /// </summary>
    private CoopFacts facts = CoopFacts.None;

    /// <summary>
    /// The step's world as recorded.
    /// </summary>
    private JsonElement told;

    /// <summary>
    /// Initializes the harness with a fresh matchmaking, asking and joining side.
    /// </summary>
    public AskHarness()
    {
        Match = new CoopMatchmaking(this, this, () => now, () => 0.5, _ => "b1");
        Asking = new CoopAsking(this, Match, () => now);
        Join = new JoinChoice(this, this, Match, Asking, () => now);
    }

    /// <summary>
    /// Gets the matchmaking.
    /// </summary>
    public CoopMatchmaking Match { get; }

    /// <summary>
    /// Gets the asking side.
    /// </summary>
    public CoopAsking Asking { get; }

    /// <summary>
    /// Gets the joining side.
    /// </summary>
    public JoinChoice Join { get; }

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
    /// Gets what the step's operation answered.
    /// </summary>
    public object? Result { get; private set; }

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
        Result = null;
        SetWorld(step.GetProperty("world"));
        JsonElement args = step.GetProperty("args");
        switch (step.GetProperty("op").GetString())
        {
            case "ask":
                Ask(args);
                break;
            case "take":
                Take(At(args.GetProperty("seat").GetInt32()), FieldsOf(args.GetProperty("message")));
                break;
            case "await":
                Await(args);
                break;
            case "undo":
                if (Asking.Asking)
                {
                    Finish();
                    Asking.Undo();
                }

                break;
            case "offers":
                Result = Asking.Offers().Select(entry => new object[]
                {
                    entry.Seat, $"{(entry.Offer.Mode == "join" ? "Join" : "Start")} battle with {At(entry.Seat)!.Name}?", entry.Offer.Mode == "join" ? "Join" : "Start", entry.Offer.At,
                }).ToList();
                break;
            case "accept_party":
                Asking.AcceptParty(At(args.GetProperty("seat").GetInt32())!, Join, Busy());
                break;
            case "decline_party":
                Asking.DeclineParty(At(args.GetProperty("seat").GetInt32())!);
                break;
            case "prompt":
                Prompt(args.GetProperty("pressed").GetBoolean(), args.GetProperty("changing").GetBoolean());
                break;
        }
    }

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
    /// Reads a text the scripts told.
    /// </summary>
    /// <param name="facts">The facts.</param>
    /// <param name="name">The fact.</param>
    /// <returns>The text, <see langword="null"/> for null.</returns>
    private static string? Text(JsonElement facts, string name) => facts.GetProperty(name).ValueKind == JsonValueKind.Null ? null : facts.GetProperty(name).GetString();

    /// <summary>
    /// Reads a flag the scripts told.
    /// </summary>
    /// <param name="facts">The facts.</param>
    /// <param name="name">The fact.</param>
    /// <returns>Whether it is true.</returns>
    private static bool Flag(JsonElement facts, string name) => facts.TryGetProperty(name, out JsonElement value) && value.ValueKind == JsonValueKind.True;

    /// <summary>
    /// Sets the world as a step's scripts saw it.
    /// </summary>
    /// <param name="world">The world.</param>
    private void SetWorld(JsonElement world)
    {
        told = world;
        peers = [];
        foreach (JsonElement entry in world.GetProperty("peers").EnumerateArray())
        {
            int seat = entry.GetProperty("seat").GetInt32();
            peers.Add(new Peer(seat, FieldsOf(entry.GetProperty("state"))) { Member = entry.GetProperty("member").GetBoolean() });
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
        JsonElement fact = world.GetProperty("facts");
        facts = new CoopFacts(
            fact.GetProperty("map").GetInt64(), fact.GetProperty("x").GetInt64(), fact.GetProperty("y").GetInt64(), Text(fact, "role"), Text(fact, "bid"),
            [.. fact.GetProperty("seats").EnumerateArray().Select(seat => seat.GetInt32())], Flag(fact, "coop"), Flag(fact, "running"), Text(fact, "kind"),
            Flag(fact, "pvp"), Flag(fact, "memory"), Flag(fact, "battle_scene"), Flag(fact, "interpreter"), Flag(fact, "trading"), Flag(fact, "coming"),
            Flag(fact, "transfer"), Flag(fact, "moving"), Flag(fact, "active"), Flag(fact, "late"), Flag(fact, "own_troop"), null, null, false, Flag(fact, "story"),
            Flag(fact, "in_battle"));
        Match.Take(facts with { HotAsk = Asking.Battle, GaveUp = Join.GaveUp });
    }

    /// <summary>
    /// Asks the running battle near, as the scripts' ask does.
    /// </summary>
    /// <param name="args">The step's arguments.</param>
    private void Ask(JsonElement args)
    {
        List<IReadOnlyList<long>> entries = [.. told.GetProperty("entries").EnumerateArray().Select(entry => (IReadOnlyList<long>)[.. entry.EnumerateArray().Select(field => field.GetInt64())])];
        List<(long Id, long Width)> widths = [.. told.GetProperty("widths").EnumerateArray().Select(pair => (pair[0].GetInt64(), pair[1].GetInt64()))];
        var encounter = new AskedEncounter(args.GetProperty("troop").GetInt32(), args.GetProperty("escape").GetBoolean(), args.GetProperty("lose").GetBoolean(),
            args.GetProperty("boss").GetBoolean(), entries, widths, [.. told.GetProperty("stays_out").EnumerateArray().Select(seat => seat.GetInt32())]);
        CoopAction? join = Asking.Ask(encounter).FirstOrDefault(action => action.Kind == "join");
        if (join is not null)
        {
            Actions.Add(["join", join.Role, join.BattleId, join.Seats!.ToArray(), join.Label]);
            facts = facts with { Role = "guest", BattleId = join.BattleId, Seats = join.Seats!, Coop = true, Running = true, Kind = "coop" };
            Match.Take(facts);
        }

        Result = join is not null;
    }

    /// <summary>
    /// Takes a co-op message as the routes and the scripts' take do.
    /// </summary>
    /// <param name="peer">Who sent it.</param>
    /// <param name="message">The message.</param>
    private void Take(Peer? peer, WorldFields message)
    {
        Match.Took(peer, message);
        switch (message["coop"])
        {
            case "hot_ok":
                Asking.TakeAnswer(peer!, message, "accepted");
                break;
            case "hot_no":
                Asking.TakeAnswer(peer!, message, "refused");
                break;
            case "party_hot":
                Asking.TakePartyOffer(peer!, message);
                break;
            case "party_ans":
                Asking.TakePartyAnswer(peer, message);
                break;
            case "pick_no":
                Join.TakeRefusal(peer, message);
                break;
            case "off":
                if (!Asking.TakeOff(peer!, message))
                {
                    Match.TakeOff(peer!, message);
                }

                break;
        }
    }

    /// <summary>
    /// Waits at the battle's start for the answers as the scripts' await does, a frame counted across
    /// both waits: messages come at frames, and the wait may end by itself at a frame.
    /// </summary>
    /// <param name="args">The step's arguments.</param>
    private void Await(JsonElement args)
    {
        int frame = 0;
        int? endAt = args.GetProperty("end_at").ValueKind == JsonValueKind.Null ? null : args.GetProperty("end_at").GetInt32();
        string? Wait(System.Func<string?> next)
        {
            frame++;
            foreach (JsonElement message in args.GetProperty("inject").EnumerateArray().Where(message => message[0].GetInt32() == frame))
            {
                Take(At(message[1].GetInt32()), FieldsOf(message[2]));
            }

            return frame == endAt ? args.GetProperty("ending").GetString() : next();
        }

        if (!Asking.Asking)
        {
            return;
        }

        if (Asking.AsksParty)
        {
            while (Wait(Asking.PartyWait) is null)
            {
            }

            if (Asking.PartyEnd() is { } started)
            {
                Own(started);
                return;
            }
        }

        string? answer;
        while ((answer = Wait(Asking.Wait)) is null)
        {
        }

        AskOutcome outcome = Asking.End(answer)!;
        if (!outcome.Late)
        {
            Own(outcome);
            return;
        }

        AskHost host = outcome.Host!;
        Actions.Add(["rates", host.Rates]);
        Actions.Add(["set", "can_escape", host.Escape]);
        Actions.Add(["set", "can_lose", host.Lose]);
        Actions.Add(["set", "preemptive", false]);
        Actions.Add(["set", "surprise", false]);
        Asking.ReleaseCompanions(outcome.Release);
        Result = new Dictionary<string, object> { ["stays_out"] = outcome.StaysOut, ["own_troop"] = true, ["late"] = true };
    }

    /// <summary>
    /// Starts the encounter on its own as the scripts do once the running battle never took it in.
    /// </summary>
    /// <param name="outcome">How the request ended.</param>
    private void Own(AskOutcome outcome)
    {
        Finish();
        Actions.Add(["host", outcome.Encounter.Troop, outcome.Encounter.Escape, outcome.Encounter.Lose]);
        Actions.Add(["fight_alone"]);
        Asking.ReleaseCompanions(outcome.Release);
        Result = new Dictionary<string, object> { ["stays_out"] = outcome.StaysOut, ["own_troop"] = false, ["late"] = false };
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
    /// Splits the reason the scripts recorded why the player may not join a battle into the reasons
    /// before and after the player's own request, which the joining side knows itself.
    /// </summary>
    /// <returns>The reasons.</returns>
    private JoinBusy Busy()
    {
        string? busy = Text(told.GetProperty("prompt"), "busy");
        return busy is null || busy == "the player waits for an answer" ? new JoinBusy(null, null)
            : BusyBefore.Contains(busy) ? new JoinBusy(busy, null) : new JoinBusy(null, busy);
    }

    /// <summary>
    /// Runs a frame on the map for the join prompt as the scripts' on_map does, and tells the
    /// prompt's text and whether the player waits for an answer.
    /// </summary>
    /// <param name="pressed">Whether the Join Battle hotkey went down.</param>
    /// <param name="changing">Whether the map's scene changes.</param>
    private void Prompt(bool pressed, bool changing)
    {
        JsonElement prompt = told.GetProperty("prompt");
        List<JoinSide> sides = [.. prompt.GetProperty("sides").EnumerateArray().Select(side => new JoinSide(side[0].GetInt32(), side[1].GetInt32(), side[2].GetString()!,
            side[3].ValueKind == JsonValueKind.Null ? null : side[3].GetInt64(), side[4].GetString()!))];
        JsonElement freezeOf = prompt.GetProperty("freeze");
        JoinFreeze? freeze = freezeOf.ValueKind == JsonValueKind.Null ? null : new JoinFreeze(freezeOf[0].GetInt32(), freezeOf[1].GetString()!);
        JoinPrompt found = Join.Frame(new JoinFrame(true, pressed, changing, Busy(), sides, freeze));
        JoinSide? side = found.Side;
        if (pressed && !changing && !found.Asked && side is not null)
        {
            Logs.Add($"join battle: fights {side.Label} (troop {side.Troop}) in a side battle alongside a full boss battle near the player");
            Actions.Add(["side", side.Troop, side.Rates]);
            side = null;
        }
        else if (pressed && !changing && !found.Asked && found.Target is null && found.Freeze is { } frozen)
        {
            Actions.Add(["freeze", frozen.Troop]);
        }

        string? text = found.Target is not null ? "Press J to join battle" : side is not null ? $"Press J to fight {side.Label} alongside"
            : found.Freeze is { } fight ? $"Press J to fight {fight.Name}" : null;
        Result = new Dictionary<string, object?> { ["text"] = text, ["asking"] = Join.Waits };
    }
}
