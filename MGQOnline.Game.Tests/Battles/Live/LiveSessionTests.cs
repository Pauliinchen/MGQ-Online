//----------------------------------------------------------------
//  LiveSessionTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Nodes;
using MGQOnline.Game.Battles.Live;

namespace MGQOnline.Game.Tests.Battles.Live;

/// <summary>
/// Covers the live battle's session and its verdicts, replayed from the golden cases of
/// fixtures/live/session.json and verdicts.json, which battles_sync.rbx and battles_sync_live.rbx
/// answered before the rules left them.
/// </summary>
public sealed class LiveSessionTests
{
    /// <summary>
    /// The names the scenario's steps give the seats when it asks for the host's waits.
    /// </summary>
    private static readonly Dictionary<int, string> SeatNames = new() { [0] = "Host", [2] = "Ann", [3] = "Bea", [4] = "Cid" };

    /// <summary>
    /// Asserts that every step of the scenario answers and logs as the scripts did.
    /// </summary>
    [Fact]
    public void Scenario_AnswersAsTheScriptsDid()
    {
        var session = new LiveSession();
        foreach (JsonElement step in Fixtures.Read("live", "session.json").GetProperty("steps").EnumerateArray())
        {
            string op = step.GetProperty("op").GetString()!;
            var logs = new List<LiveLogLine>();
            var departed = new List<(int Seat, int StillIn)>();
            JsonNode? value = Run(session, step, logs, departed);
            string label = $"{op} {step}";
            Assert.True(WireValue(step.GetProperty("value")) == (value?.ToJsonString() ?? "null"), $"{label}: {value?.ToJsonString()}");
            Assert.True(Departed(step) == string.Join(",", departed.Select(left => $"{left.Seat}:{left.StillIn}")), label);
            Assert.True(step.GetProperty("logs").EnumerateArray().Select(line => line.GetString()!).SequenceEqual(Once(logs)), $"{label}: {string.Join(" | ", logs.Select(line => line.Text))}");
        }
    }

    /// <summary>
    /// Asserts that a battle ends early as the scripts ended it.
    /// </summary>
    [Fact]
    public void EndEarly_EndsAsTheScriptsDid()
    {
        foreach (JsonElement entry in Fixtures.Read("live", "verdicts.json").GetProperty("early").EnumerateArray())
        {
            string reason = entry.GetProperty("reason").GetString()!;
            bool missed = entry.GetProperty("missed").GetBoolean();
            LiveEnd end = LiveVerdicts.EndEarly(reason, entry.GetProperty("team").GetBoolean() && entry.GetProperty("side").GetBoolean(), "Rival");
            List<string> effects = end.Process switch
            {
                "win" => ["win"],
                "forfeit" => ["forfeit"],
                "gone" => ["friend_gone"],
                _ when missed => ["say", $"process {end.Process}"],
                _ => [$"message {end.Message}", $"process {end.Process}"],
            };
            Assert.Equal(Effects(entry), effects);
            Assert.Contains($"the live battle ends early in turn 0: {LiveVerdicts.ReasonText(reason)}", Texts(entry.GetProperty("logs")));
        }
    }

    /// <summary>
    /// Asserts that a guest's battle ends as the host's ended, as the scripts ended it.
    /// </summary>
    [Fact]
    public void GuestEnd_EndsAsTheScriptsDid()
    {
        foreach (JsonElement entry in Fixtures.Read("live", "verdicts.json").GetProperty("guest").EnumerateArray())
        {
            (string first, LiveEnd end) = LiveVerdicts.GuestEnd(entry.GetProperty("result").GetString()!, entry.GetProperty("side").GetBoolean(), "Rival");
            List<string> effects = Ended(end, entry.GetProperty("take_over").GetBoolean());
            Assert.Equal(Effects(entry), effects);
            Assert.Equal(Texts(entry.GetProperty("logs")), new[] { first }.Concat(Logged(end, entry.GetProperty("take_over").GetBoolean())));
        }
    }

    /// <summary>
    /// Asserts that a battle whose other side is gone ends as the scripts ended it.
    /// </summary>
    [Fact]
    public void FriendGone_EndsAsTheScriptsDid()
    {
        foreach (JsonElement entry in Fixtures.Read("live", "verdicts.json").GetProperty("gone").EnumerateArray())
        {
            var session = new LiveSession();
            string role = entry.GetProperty("role").GetString()!;
            session.Join(role, "v3", role == "host" ? [2] : [0], "Rival", entry.GetProperty("kind").GetString()!, entry.GetProperty("team").GetBoolean(), false);
            session.Start();
            bool takeOver = entry.GetProperty("take_over").GetBoolean();
            LiveEnd end = LiveVerdicts.FriendGone(session, entry.GetProperty("side").GetBoolean());
            List<string> effects = end.Process == "solo" ? ["solo"] : Ended(end, takeOver);
            Assert.Equal(Effects(entry), effects);
            Assert.Equal(entry.GetProperty("result").GetBoolean(), end.Process == "solo");
            Assert.All(Logged(end, takeOver), line => Assert.Contains(line, Texts(entry.GetProperty("logs"))));
        }
    }

    /// <summary>
    /// Asserts that a guest falls behind once four sends of the host's stream wait.
    /// </summary>
    [Fact]
    public void Behind_FromFourSendsWaiting()
    {
        var session = new LiveSession();
        session.Join("guest", "b1", [0], "Host", "coop", false, false);
        for (int send = 0; send < 3; send++)
        {
            session.Receive(0, "events", "e", "Host");
        }

        bool before = session.Behind;
        session.Receive(0, "events", "e", "Host");

        Assert.False(before);
        Assert.True(session.Behind);
        session.Take(["events"]);
        Assert.False(session.Behind);
    }

    /// <summary>
    /// Asserts that a guest who leaves while the host waits for the commands is no longer waited for,
    /// and is taken out once.
    /// </summary>
    [Fact]
    public void GuestLeft_MidPhase_IsNoLongerWaitedFor()
    {
        var session = new LiveSession();
        session.Join("host", "p1", [2, 3], "the party", "coop", false, false);
        session.Start();
        session.OpenPhase();
        session.Answer(2);

        bool first = session.GuestLeft(3);
        bool again = session.GuestLeft(3);

        Assert.Equal((true, false), (first, again));
        Assert.Empty(session.Unanswered);
        Assert.Equal([2], session.GuestsIn);
    }

    /// <summary>
    /// Asserts that a departure told twice is told once.
    /// </summary>
    [Fact]
    public void Tell_DepartureToldTwice_IsToldOnce()
    {
        var session = new LiveSession();
        session.Join("host", "d1", [2], "the party", "coop", false, false);

        Assert.Equal((true, false, true), (session.Tell(2, "left"), session.Tell(2, "left"), session.Tell(2, "joined")));
    }

    /// <summary>
    /// Runs one step of the scenario.
    /// </summary>
    /// <param name="session">The session.</param>
    /// <param name="step">The step.</param>
    /// <param name="logs">Where its log lines go.</param>
    /// <param name="departed">Where the guests it took out go.</param>
    /// <returns>What it answers, as the scripts answered it.</returns>
    private static JsonNode? Run(LiveSession session, JsonElement step, List<LiveLogLine> logs, List<(int Seat, int StillIn)> departed)
    {
        string Who(int seat) => step.GetProperty("who").GetProperty(seat.ToString(System.Globalization.CultureInfo.InvariantCulture)).GetString()!;
        List<int> Seats(string name) => step.GetProperty(name).EnumerateArray().Select(seat => seat.GetInt32()).ToList();
        switch (step.GetProperty("op").GetString())
        {
            case "join":
                session.Join(step.GetProperty("role").GetString()!, step.GetProperty("bid").GetString()!, Seats("seats"), step.GetProperty("player").GetString()!,
                    step.GetProperty("kind").GetString()!, step.GetProperty("team").GetBoolean(), false);
                session.ResetReady();
                session.ForgetWaiting();
                return null;
            case "start":
                session.Start();
                return null;
            case "finish":
                session.ClosePhase();
                session.Finish();
                return null;
            case "expect":
                session.Expect(Seats("seats"));
                return new JsonArray(session.Expected.Select(seat => (JsonNode)seat).ToArray());
            case "keep":
                session.KeepSeats(Seats("seats"));
                return new JsonArray(session.Seats.Select(seat => (JsonNode)seat).ToArray());
            case "receive":
                int from = step.GetProperty("seat").GetInt32();
                if (session.Receive(from, step.GetProperty("kind").GetString()!, step.GetProperty("body").GetString()!, Who(from)) is { } line)
                {
                    logs.Add(line);
                }

                return null;
            case "pending":
                return session.Pending(step.GetProperty("kind").GetString()!);
            case "take":
                string[] kinds = step.GetProperty("kinds").EnumerateArray().Select(kind => kind.GetString()!).ToArray();
                int? seat = step.GetProperty("seat").ValueKind == JsonValueKind.Null ? null : step.GetProperty("seat").GetInt32();
                LiveMessage? taken = session.Take(kinds, seat);
                return taken is null ? null : kinds.Length > 1 ? new JsonArray(taken.Kind, taken.Body) : taken.Body;
            case "gone":
                session.NoteGone(Seats("seats"));
                return null;
            case "ticks":
                var endings = new JsonArray();
                for (int count = step.GetProperty("count").GetInt32(); count > 0; count--)
                {
                    LiveTick tick = session.Tick(new LiveFacts(step.GetProperty("in_world").GetBoolean(), false));
                    logs.AddRange(tick.Logs);
                    departed.AddRange(tick.Departed);
                    if (tick.Ending is not null)
                    {
                        endings.Add(tick.Ending);
                    }
                }

                return endings;
            case "tell":
                return session.Tell(step.GetProperty("seat").GetInt32(), step.GetProperty("kind").GetString()!);
            case "admit":
                if (session.Refusal(step.GetProperty("channel").GetBoolean(), step.GetProperty("bid").GetString(), step.GetProperty("kind").GetString()!,
                        Who(step.GetProperty("who_seat").GetInt32())) is { } refusal)
                {
                    logs.Add(refusal);
                }

                return null;
            case "ready_reset":
                session.ResetReady();
                return null;
            case "ready":
                return session.AllReady() ? true : null;
            case "not_ready":
                return new JsonArray(session.NotReady.Select(left => (JsonNode)left).ToArray());
            case "tell_waiting":
                string? body = session.TellWaiting(Seats("seats"));
                return body is null ? null : new JsonArray("waiting", body);
            case "host_waiting":
                return new JsonArray(session.HostWaiting().Seats.Where(waiting => waiting != 0).Select(waiting => (JsonNode)SeatNames[waiting]).ToArray());
            default:
                throw new InvalidOperationException($"The scenario has no step {step.GetProperty("op").GetString()}.");
        }
    }

    /// <summary>
    /// Writes a golden value as the test writes the session's answer.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>Its JSON.</returns>
    private static string WireValue(JsonElement value) => JsonNode.Parse(value.GetRawText())?.ToJsonString() ?? "null";

    /// <summary>
    /// Writes the guests a golden step took out.
    /// </summary>
    /// <param name="step">The step.</param>
    /// <returns>Each seat with the guests still in after it.</returns>
    private static string Departed(JsonElement step) =>
        string.Join(",", step.GetProperty("departed").EnumerateArray().Select(left => $"{left[0].GetInt32()}:{left[1].GetInt32()}"));

    /// <summary>
    /// Keeps the first log line of each key, as the scripts log them once.
    /// </summary>
    /// <param name="logs">The lines.</param>
    /// <returns>The texts logged.</returns>
    private static IEnumerable<string> Once(IEnumerable<LiveLogLine> logs)
    {
        var keys = new HashSet<string>(StringComparer.Ordinal);
        return logs.Where(line => line.Key is null || keys.Add(line.Key)).Select(line => line.Text).ToList();
    }

    /// <summary>
    /// Reads texts.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>The texts.</returns>
    private static List<string> Texts(JsonElement list) => list.EnumerateArray().Select(text => text.GetString()!).ToList();

    /// <summary>
    /// Writes the effects a golden case noted, each as "name argument".
    /// </summary>
    /// <param name="entry">The case.</param>
    /// <returns>The effects.</returns>
    private static List<string> Effects(JsonElement entry) =>
        entry.GetProperty("effects").EnumerateArray()
            .Select(effect => effect[0].GetString() is "say" ? "say" : string.Join(" ", effect.EnumerateArray().Select(part => part.ToString())))
            .ToList();

    /// <summary>
    /// Writes the effects of an ending, the take over answered as given.
    /// </summary>
    /// <param name="end">The ending.</param>
    /// <param name="takeOver">Whether the battle's mode takes over.</param>
    /// <returns>The effects.</returns>
    private static List<string> Ended(LiveEnd end, bool takeOver)
    {
        if (end.Process != "take_over")
        {
            return [.. end.Message is null ? Array.Empty<string>() : [$"message {end.Message}"], $"process {end.Process}"];
        }

        return takeOver ? ["take_over"] : ["take_over", .. Ended(end.Otherwise!, false)];
    }

    /// <summary>
    /// Lists the lines an ending logs, the take over answered as given.
    /// </summary>
    /// <param name="end">The ending.</param>
    /// <param name="takeOver">Whether the battle's mode takes over.</param>
    /// <returns>The lines.</returns>
    private static IEnumerable<string> Logged(LiveEnd end, bool takeOver)
    {
        if (end.Process == "take_over")
        {
            return takeOver ? [] : Logged(end.Otherwise!, false);
        }

        return end.Log is null ? [] : [end.Log];
    }
}
