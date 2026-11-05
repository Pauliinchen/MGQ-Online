//----------------------------------------------------------------
//  ReplayChannelsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Text.RegularExpressions;
using MGQOnline.Data.Events;
using MGQOnline.Data.Generator.Build;

namespace MGQOnline.Data.Generator.Tests;

/// <summary>
/// Covers the replayer's lists against the generator's gate and the events database, through the
/// fixture fixtures/replay/channels.json, which story_replay_test.rb checks the script against.
/// </summary>
public sealed partial class ReplayChannelsTests
{
    /// <summary>
    /// The command codes the gate closes that the replay need not leave out: the lines a text,
    /// scrolling text and a move route read after their command, which have no command of their own.
    /// </summary>
    private static readonly int[] ReadLines = [401, 405, 605];

    /// <summary>
    /// The functions the gate closes that the replay answers itself: the screen, waits, and the
    /// closed command a script calls.
    /// </summary>
    private static readonly string[] AnsweredFunctions = ["screen", "wait", "command_203"];

    /// <summary>
    /// Asserts that the replay leaves out exactly the codes and the interpreter's functions the gate
    /// classes as the presentation or the opener's play alone, and that an input's place counts the
    /// codes the events database keeps.
    /// </summary>
    [Fact]
    public void Replayer_LeavesOutWhatTheGateCloses()
    {
        using JsonDocument fixture = JsonDocument.Parse(File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "fixtures", "replay", "channels.json")));
        JsonElement lists = fixture.RootElement;

        int[] codes = [.. ReplayChannels.Commands.Where(pair => Closed(pair.Value)).Select(pair => pair.Key).Except(ReadLines).Order()];
        string[] functions = [.. ReplayChannels.Roots.Where(pair => FunctionName().IsMatch(pair.Key) && Closed(pair.Value)).Select(pair => pair.Key).Except(AnsweredFunctions).Order(StringComparer.Ordinal)];

        Assert.Equal(codes, lists.GetProperty("closed_codes").EnumerateArray().Select(code => code.GetInt32()).Order());
        Assert.Equal(functions, lists.GetProperty("closed_functions").EnumerateArray().Select(name => name.GetString()!).Order(StringComparer.Ordinal));
        Assert.Equal(EventSchema.KeptCodes, [.. lists.GetProperty("kept_codes").EnumerateArray().Select(code => code.GetInt32())]);
    }

    /// <summary>
    /// Tells whether channels are the presentation or the opener's play alone, which the replay
    /// leaves out.
    /// </summary>
    /// <param name="channels">The channels.</param>
    /// <returns>Whether they are.</returns>
    private static bool Closed(ReplayChannel channels) => (channels & (ReplayChannel.State | ReplayChannel.Input)) == 0;

    /// <summary>
    /// A root that names a function of the interpreter, not a global or a constant.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"\A[a-z_]\w*[?!]?\z", RegexOptions.CultureInvariant)]
    private static partial Regex FunctionName();
}
