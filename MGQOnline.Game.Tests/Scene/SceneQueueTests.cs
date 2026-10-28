//----------------------------------------------------------------
//  SceneQueueTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Battles.Wire;
using MGQOnline.Game.Scene;

namespace MGQOnline.Game.Tests.Scene;

/// <summary>
/// Covers the teller's queue of scene changes, replayed from the golden cases of
/// fixtures/scene/cases.json, which coop_scene.rbx merged and split before the rules left it.
/// </summary>
public sealed class SceneQueueTests
{
    /// <summary>
    /// What the DLL knows of the game when it reads a scene's line: nothing.
    /// </summary>
    private static readonly WireGame NoGame = new([], [], new Dictionary<WireTable, int>());

    /// <summary>
    /// Asserts that every scenario the script recorded goes out in the messages it sent.
    /// </summary>
    [Fact]
    public void Changes_GoOutAsTheScriptSentThem()
    {
        JsonElement cases = Fixtures.Read("scene", "cases.json");
        Assert.Equal((SceneQueue.MaxBatch, SceneQueue.MaxBatchBytes), (cases.GetProperty("max_batch").GetInt32(), cases.GetProperty("max_batch_bytes").GetInt32()));
        foreach (JsonElement scenario in cases.GetProperty("queue").EnumerateArray())
        {
            var queue = new SceneQueue();
            string name = scenario.GetProperty("name").GetString()!;
            foreach (JsonElement step in scenario.GetProperty("steps").EnumerateArray())
            {
                if (step.GetProperty("op").GetString() == "change")
                {
                    IReadOnlyList<WireValue>? args = WireReader.Parse(step.GetProperty("line").GetString()!, NoGame);
                    Assert.NotNull(args);
                    queue.Add(step.GetProperty("kind").GetString()!, args, step.GetProperty("map").GetInt32(), step.GetProperty("logged").GetBoolean(), step.GetProperty("skip").GetBoolean());
                    continue;
                }

                var expected = step.GetProperty("messages").EnumerateArray().Select(message => (message.GetProperty("map").GetInt32(), message.GetProperty("pscene").GetString(), message.GetProperty("args").GetString())).ToList();
                var actual = queue.Flush().Select(message => (message.Map, (string?)message.Kind, (string?)message.Args)).ToList();
                Assert.True(expected.SequenceEqual(actual), $"{name}: expected {Describe(expected)}, got {Describe(actual)}");
            }
        }
    }

    /// <summary>
    /// Asserts that while the player holds the game's skip the changes go out only every
    /// <see cref="SceneQueue.SkipSendFrames"/> frames, but at once once the skip is let go or the
    /// story stopped, and that a frame count that went back counts as passed.
    /// </summary>
    [Fact]
    public void Due_ThrottlesOnlyWhileSkipping()
    {
        var queue = new SceneQueue();
        queue.Add("screen.start_fadein", [new WireInteger(30)], 7, true, true);
        queue.Flush(100);

        Assert.False(queue.Due(105, skipHeld: true, playing: true));
        Assert.True(queue.Due(110, skipHeld: true, playing: true));
        Assert.True(queue.Due(105, skipHeld: false, playing: true));
        Assert.True(queue.Due(105, skipHeld: true, playing: false));
        Assert.True(queue.Due(50, skipHeld: true, playing: true));
    }

    /// <summary>
    /// Writes messages for a failure, their arguments cut.
    /// </summary>
    /// <param name="messages">The messages.</param>
    /// <returns>The text.</returns>
    private static string Describe(List<(int Map, string? Kind, string? Args)> messages) =>
        string.Join("; ", messages.Select(message => $"map {message.Map} {message.Kind} {message.Args?[..System.Math.Min(60, message.Args.Length)]} ({message.Args?.Length} chars)"));
}
