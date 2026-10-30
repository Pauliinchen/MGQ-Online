//----------------------------------------------------------------
//  RecorderBufferTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Battles.Live;

namespace MGQOnline.Game.Tests.Battles.Live;

/// <summary>
/// Covers the host's recording, replayed from the golden steps of fixtures/live/recorder.json,
/// which battles_sync_recorder.rbx sent and counted before its buffer left it.
/// </summary>
public sealed class RecorderBufferTests
{
    /// <summary>
    /// Asserts that every step sends and counts as the script did.
    /// </summary>
    [Fact]
    public void Steps_SendAndCountAsTheScriptDid()
    {
        var recorder = new RecorderBuffer();
        int index = 0;
        foreach (JsonElement step in Fixtures.Read("live", "recorder.json").GetProperty("steps").EnumerateArray())
        {
            var sends = new List<string?>();
            var logs = new List<string>();
            switch (step.GetProperty("op").GetString())
            {
                case "start":
                    recorder.Start();
                    logs.Add("recording the battle for the guests' stream");
                    break;
                case "values":
                    sends.AddRange(recorder.Values(Battlers(step), step.GetProperty("full").GetBoolean()));
                    break;
                case "tick":
                    sends.Add(recorder.Tick());
                    break;
                case "event":
                    sends.Add(recorder.Event(step.GetProperty("line").GetString()!));
                    break;
                case "flush":
                    sends.Add(recorder.Flush());
                    break;
                case "phase":
                    sends.AddRange(recorder.Values(Battlers(step), true));
                    sends.Add(recorder.Event(step.GetProperty("line").GetString()!));
                    sends.Add(recorder.Flush());
                    (int events, int counted) = recorder.TakeCounts();
                    logs.Add($"streamed the battle's start: {events} events in {counted} sends, every battler's values anew");
                    break;
                case "finish":
                    sends.Add(recorder.Flush());
                    logs.Add($"recording finished, battle result 0: {recorder.TotalEvents} events in {recorder.TotalSends} sends");
                    break;
                case "stop":
                    logs.Add($"recording stopped, {recorder.Stop()} events left unsent");
                    break;
            }

            List<string> expected = step.GetProperty("sends").EnumerateArray().Select(sent => sent.GetString()!).ToList();
            List<string> actual = sends.OfType<string>().SelectMany(send => new[] { "before_send", send }).ToList();
            Assert.True(expected.SequenceEqual(actual), $"step {index} {step.GetProperty("op").GetString()}");
            Assert.Equal(step.GetProperty("logs").EnumerateArray().Select(line => line.GetString()!), logs);
            index++;
        }
    }

    /// <summary>
    /// Asserts that values that did not change are recorded once, and every battler's again on a full recording.
    /// </summary>
    [Fact]
    public void Values_RecordedOnlyWhenChanged()
    {
        var recorder = new RecorderBuffer();
        recorder.Start();

        recorder.Values([(1, "a0", "i1"), (2, "a1", "i2")], false);
        recorder.Values([(1, "a0", "i1"), (2, "a1", "i3")], false);
        int changed = recorder.Waiting;
        recorder.Values([(1, "a0", "i1"), (2, "a1", "i3")], true);

        Assert.Equal(3, changed);
        Assert.Equal(5, recorder.Waiting);
    }

    /// <summary>
    /// Reads the battlers of a step.
    /// </summary>
    /// <param name="step">The step.</param>
    /// <returns>Each battler's key, reference and values.</returns>
    private static IEnumerable<(long, string, string)> Battlers(JsonElement step) =>
        step.GetProperty("battlers").EnumerateArray().Select(entry => (entry[0].GetInt64(), entry[1].GetString()!, entry[2].GetString()!)).ToList();
}
