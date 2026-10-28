//----------------------------------------------------------------
//  CommandClassifierTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Game.Tests.Events;

/// <summary>
/// Covers how the reader turns the texts of a list's commands into numbers and kinds.
/// </summary>
public sealed class CommandClassifierTests
{
    /// <summary>
    /// Asserts each kind of script, a script read with its continuation lines, and the variable a
    /// choice writes as its first number.
    /// </summary>
    [Fact]
    public void Classify_TellsTheScriptsApart()
    {
        EventCommand[] list = CommandClassifier.Classify(
        [
            Command(355, 0, "wait(30)"),
            Command(355, 0, ""), Command(655, 0, "forced_transfer(3, 4, 5)"),
            Command(355, 0, "unlimited_choices(12, [\"Yes\", \"No\"])"),
            Command(355, 0, "call_novel_scene(\"Ending\")"),
            Command(355, 0, "$game_party.gain_gold(5)"),
            Command(101, 0, "", 0, 0, 2),
        ]);

        Assert.Equal(
            [TextKind.Talk, TextKind.Travel, TextKind.None, TextKind.Choice, TextKind.Novel, TextKind.Other, TextKind.None],
            list.Select(command => command.TextKind));
        Assert.Equal(12, list[3].Number(0));
    }

    /// <summary>
    /// Asserts that a jump becomes the place of its name's first label, -1 for a name without one,
    /// and that labels are numbered by their names.
    /// </summary>
    [Fact]
    public void Classify_ResolvesJumpsToTheirLabels()
    {
        EventCommand[] list = CommandClassifier.Classify(
        [
            Command(119, 0, "End"), Command(118, 0, "Top"), Command(118, 0, "End"), Command(118, 0, "End"), Command(119, 0, "Nowhere"),
        ]);

        Assert.Equal([2L, 1L, 2L, 2L, -1L], list.Select(command => command.Number(0)));
    }

    /// <summary>
    /// Asserts that a self switch's letter becomes its number and back, and that every script text
    /// names its switches and variables, those it assigns as set: a script and its lines, a branch on
    /// a script, and a variable set to a script's value.
    /// </summary>
    [Fact]
    public void Classify_NumbersLettersAndFindsScriptKeys()
    {
        EventCommand[] list = CommandClassifier.Classify(
        [
            Command(123, 0, "C", 0),
            Command(355, 0, "$game_variables[5] += 1"), Command(655, 0, "$game_switches[7] == true"),
            Command(111, 0, 12, "$game_switches[8]"),
            Command(122, 0, 9, 9, 0, 4, "$game_variables[10] * 2"),
        ]);

        Assert.Equal(3, list[0].Number(0));
        Assert.Equal("C", CommandClassifier.LetterOf(list[0].Number(0)));
        Assert.Equal([new ScriptKey(true, 5, true)], list[1].ScriptKeys);
        Assert.Equal([new ScriptKey(false, 7, false)], list[2].ScriptKeys);
        Assert.Equal([new ScriptKey(false, 8, false)], list[3].ScriptKeys);
        Assert.Equal([new ScriptKey(true, 10, false)], list[4].ScriptKeys);
    }

    /// <summary>
    /// Asserts the switch of the innermost branch on a switch being on around a command: none in
    /// that branch's else, and, among chosen switches only, the outer one past another.
    /// </summary>
    [Fact]
    public void EnclosingSwitch_FindsTheInnermostBranchOnASwitch()
    {
        EventCommand[] list = CommandClassifier.Classify(
        [
            Command(111, 0, 0, 4, 0),
            Command(111, 1, 0, 30, 0),
            Command(301, 2, 0, 71, 0, 0),
            Command(411, 1),
            Command(301, 2, 0, 72, 0, 0),
            Command(412, 1),
            Command(412, 0),
        ]);

        Assert.Equal(30, CommandClassifier.EnclosingSwitch(list, 2));
        Assert.Equal(4, CommandClassifier.EnclosingSwitch(list, 4));
        Assert.Equal(4, CommandClassifier.EnclosingSwitch(list, 2, new HashSet<long> { 4, 5 }));
        Assert.Null(CommandClassifier.EnclosingSwitch(list, 0));
    }

    /// <summary>
    /// Makes a command as the reader reads it.
    /// </summary>
    /// <param name="code">The code.</param>
    /// <param name="indent">The indent.</param>
    /// <param name="parameters">The parameters, whole numbers and texts.</param>
    /// <returns>The command.</returns>
    private static RawCommand Command(int code, int indent, params object[] parameters) =>
        new(code, indent, new RubyArray(parameters.Select(parameter => parameter is string text ? (RubyValue)text : (RubyValue)(long)(int)parameter)));
}
