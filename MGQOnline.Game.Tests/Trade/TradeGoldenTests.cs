//----------------------------------------------------------------
//  TradeGoldenTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Trade;

namespace MGQOnline.Game.Tests.Trade;

/// <summary>
/// Replays the trades trade.rbx played before its handshake and session moved to C# (fixtures/trade,
/// written by make_fixtures.rb there) and checks that every step sends, tells and keeps what the
/// script did.
/// </summary>
public sealed class TradeGoldenTests
{
    /// <summary>
    /// Gives the name of every scenario.
    /// </summary>
    /// <returns>The names.</returns>
    public static TheoryData<string> Scenarios() => new(Cases().GetProperty("scenarios").EnumerateArray().Select(scenario => scenario.GetProperty("name").GetString()!));

    /// <summary>
    /// Asserts that every step of a scenario does what the script did.
    /// </summary>
    /// <param name="name">The scenario.</param>
    [Theory]
    [MemberData(nameof(Scenarios))]
    public void Step_DoesWhatTheScriptDid(string name)
    {
        JsonElement scenario = Cases().GetProperty("scenarios").EnumerateArray().First(entry => entry.GetProperty("name").GetString() == name);
        var harness = new TradeHarness();
        int index = 0;
        foreach (JsonElement step in scenario.GetProperty("steps").EnumerateArray())
        {
            harness.Clear();
            foreach (JsonElement op in step.GetProperty("ops").EnumerateArray())
            {
                Run(harness, op);
            }

            JsonElement handed = step.GetProperty("handed");
            string? busy = handed.GetProperty("busy").ValueKind == JsonValueKind.Null ? null : handed.GetProperty("busy").GetString();
            harness.Machine.TakeFrame(new TradeFrame(busy, handed.GetProperty("inviting").GetBoolean(),
                [.. handed.GetProperty("targets").EnumerateArray().Select(target => target.GetString()!)], TradeHarness.World));
            harness.Frames(step.GetProperty("frames").GetInt32());
            string expected = JsonSerializer.Serialize(step.GetProperty("outcome"));
            string actual = JsonSerializer.Serialize(Outcome(harness));
            Assert.True(expected == actual, $"step {index} of {name}:\nexpected {expected}\nactual   {actual}");
            index++;
        }
    }

    /// <summary>
    /// Reads the cases.
    /// </summary>
    /// <returns>The cases.</returns>
    private static JsonElement Cases() => Fixtures.Read("trade", "cases.json");

    /// <summary>
    /// Runs an operation of a step as the script ran it.
    /// </summary>
    /// <param name="harness">The trade.</param>
    /// <param name="op">The operation.</param>
    private static void Run(TradeHarness harness, JsonElement op)
    {
        JsonElement[] parts = [.. op.EnumerateArray()];
        switch (parts[0].GetString())
        {
            case "message":
                harness.Message(parts[1].GetString()!);
                break;
            case "out":
                harness.Out();
                break;
            case "back":
                harness.Back();
                break;
            case "accept":
                harness.Machine.Accept(harness.Friend());
                break;
            case "decline":
                harness.Machine.Decline(harness.Friend(), "no");
                break;
            case "offer":
                if (parts[1].ValueKind == JsonValueKind.String)
                {
                    harness.Machine.Offer(parts[1].GetString()!);
                }

                break;
            case "confirm":
                harness.Machine.ToggleConfirm(parts[1].ValueKind == JsonValueKind.String ? parts[1].GetString() : null);
                break;
            case "cancel":
                harness.Machine.Cancel();
                break;
            case "send_fails":
                harness.SendFails = parts[1].GetBoolean();
                break;
            case "relay":
                harness.Commit = CommitOf(parts[1].GetString()!);
                break;
            case "invite":
            case "busy":
                break;
            default:
                throw new InvalidOperationException($"There is no operation {parts[0]}.");
        }
    }

    /// <summary>
    /// Reads the relay's answer about the commit as the script read it.
    /// </summary>
    /// <param name="text">key=value lines.</param>
    /// <returns>The commit.</returns>
    private static TradeCommitState CommitOf(string text)
    {
        Dictionary<string, string> fields = text.Split('\n').Select(line => line.Split('=', 2)).ToDictionary(pair => pair[0], pair => pair[1], StringComparer.Ordinal);
        return new TradeCommitState(fields["trade"], fields["state"], fields.GetValueOrDefault("reason"), fields.GetValueOrDefault("error"));
    }

    /// <summary>
    /// Describes what a step did, as the script's cases record it.
    /// </summary>
    /// <param name="harness">The trade.</param>
    /// <returns>The outcome.</returns>
    private static Dictionary<string, object?> Outcome(TradeHarness harness)
    {
        TradeSession? session = harness.Machine.Session;
        Dictionary<string, object?>? state = session is null ? null : new()
        {
            ["id"] = session.Id,
            ["partner"] = session.Partner,
            ["stage"] = session.StageName,
            ["my_rev"] = session.MyRevision,
            ["their_rev"] = session.TheirRevision,
            ["confirmed"] = session.Confirmed,
            ["their_confirmed"] = session.TheirConfirmed,
            ["relay_id"] = session.RelayId,
            ["leaving"] = session.Leaving,
            ["unsent"] = session.Unsent,
            ["away"] = session.Away,
        };
        return new()
        {
            ["sent"] = harness.Sent.Select(sent => new object[] { sent.Seat, sent.Text }).ToList(),
            ["notices"] = harness.Notices.ToList(),
            ["relay"] = harness.RelayCalls.Where(call => call[0] is "mp_trade_commit" or "mp_trade_cancel").ToList(),
            ["applied"] = harness.Applied.ToList(),
            ["view"] = new Dictionary<string, object?>
            {
                ["session"] = state,
                ["accepted"] = harness.Machine.Accepted?.Id,
                ["open_screen"] = harness.OpenScreenWanted,
            },
        };
    }
}
