//----------------------------------------------------------------
//  ChoiceAsks.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Named the variable of the extended choices' answers for the whole build
//      Paulinchen  2026-11-01: Found the branches of each extended choice too, by the answers it adds and the branches on its result after it
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Data.Generator.Build;

/// <summary>
/// An extended choice of a list: a script command that calls <c>ex_choice_show</c> of the game's
/// extended choices script (拡張選択肢), which writes the id of the answer picked into its result
/// variable, and the answers it offers.
/// </summary>
/// <param name="Idx">The place of the script command.</param>
/// <param name="Last">The place of the script's last line.</param>
/// <param name="Answers">The ids its <c>ex_choice_add</c> calls since the previous extended choice add, then the id a cancel gives when it lets the player cancel.</param>
internal readonly record struct ExChoice(int Idx, int Last, IReadOnlyList<int> Answers);

/// <summary>
/// Finds the branches of every Show Choices command and extended choice of the map pages and
/// common events, from which the DLL tells with the live scopes whether a replay asks the receiver
/// the choice ("Issue 73 chest effects.md", rule 4): its branches do different things to the
/// receiver's own things.
/// </summary>
internal static partial class ChoiceAsks
{
    /// <summary>
    /// Show Choices.
    /// </summary>
    private const int ShowChoices = 102;

    /// <summary>
    /// The branch of one answer, whose first parameter is the answer's place.
    /// </summary>
    private const int When = 402;

    /// <summary>
    /// The branch of the cancel.
    /// </summary>
    private const int WhenCancel = 403;

    /// <summary>
    /// The answer the game hands on for the cancel branch.
    /// </summary>
    private const int CancelAnswer = 4;

    /// <summary>
    /// The first parameter of a conditional branch on a variable.
    /// </summary>
    private const int VariableBranch = 1;

    /// <summary>
    /// The third parameter of a conditional branch on a variable that compares it with a constant.
    /// </summary>
    private const int ConstantOperand = 0;

    /// <summary>
    /// The cancel <c>ex_choice_show</c> gives when it names none: the player cannot cancel.
    /// </summary>
    private const int NoCancel = -1;

    /// <summary>
    /// The constant of the scripts that names the variable an extended choice writes its answer into.
    /// </summary>
    private const string ExChoiceResult = "EX_CHOICE_RESULT";

    /// <summary>
    /// Finds the variable the extended choices write their answer into.
    /// </summary>
    /// <param name="scripts">The game's scripts, each as one text.</param>
    /// <returns>The variable, <see langword="null"/> while the scripts name none.</returns>
    public static long? ResultVariable(IReadOnlyList<string> scripts) => SwitchUses.ConstantOf(scripts, ExChoiceResult);

    /// <summary>
    /// Finds the branches.
    /// </summary>
    /// <param name="game">The game read.</param>
    /// <param name="scripts">The game's scripts, each as one text, which name the variable of the extended choices' answers.</param>
    /// <returns>The branches by list, choice and answer.</returns>
    public static IReadOnlyList<ChoiceBranchRow> Of(BuiltGame game, IReadOnlyList<string> scripts)
    {
        long? exChoiceResult = ResultVariable(scripts);
        IReadOnlySet<long> touching = Gives.TouchingCommons(game);
        var rows = new List<ChoiceBranchRow>();
        foreach (BuiltList list in Gives.Replayable(game))
        {
            EventCommand[] commands = list.Commands;
            for (int idx = 0; idx < commands.Length; idx++)
            {
                if (commands[idx].Code == ShowChoices)
                {
                    rows.AddRange(BranchesOf(list, idx).Select(branch => Row(list, idx, branch, touching)));
                }
            }

            if (exChoiceResult is { } result)
            {
                foreach (ExChoice choice in list.ExChoices)
                {
                    rows.AddRange(ExBranchesOf(list, choice, result).Select(branch => Row(list, choice.Idx, branch, touching)));
                }
            }
        }

        return rows;
    }

    /// <summary>
    /// Finds the extended choices of a list, each with the answers added before it.
    /// </summary>
    /// <param name="list">The commands as read.</param>
    /// <returns>The extended choices, in their order.</returns>
    public static IReadOnlyList<ExChoice> ExChoicesOf(IReadOnlyList<RawCommand> list)
    {
        var found = new List<ExChoice>();
        var answers = new List<int>();
        for (int idx = 0; idx < list.Count; idx++)
        {
            if (list[idx].Code != EventCodes.Script)
            {
                continue;
            }

            int start = idx;
            var script = new StringBuilder(list[idx].Text(0));
            while (idx + 1 < list.Count && list[idx + 1].Code == EventCodes.ScriptLine)
            {
                script.Append('\n').Append(list[++idx].Text(0));
            }

            answers.AddRange(ExChoiceAdd().Matches(script.ToString()).Select(add => WholeNumber(add.Groups[1])));
            if (ExChoiceShow().Match(script.ToString()) is { Success: true } show)
            {
                int cancel = show.Groups[1].Success ? WholeNumber(show.Groups[1]) : NoCancel;
                found.Add(new ExChoice(start, idx, [.. answers.Concat(cancel > NoCancel ? [cancel] : []).Distinct()]));
                answers.Clear();
            }
        }

        return found;
    }

    /// <summary>
    /// Makes the row of a branch.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="idx">The choice's place.</param>
    /// <param name="branch">The branch's answer and the places of its first and last command.</param>
    /// <param name="touching">The common events that change what a player holds.</param>
    /// <returns>The row.</returns>
    private static ChoiceBranchRow Row(BuiltList list, int idx, (int Answer, int First, int Last) branch, IReadOnlySet<long> touching) =>
        new(list.Site.ListId, idx, branch.Answer, branch.First, branch.Last, Holdings(list, branch.First, branch.Last, touching));

    /// <summary>
    /// Lists the branches of a choice: each When or When Cancel at the choice's indent opens one,
    /// whose commands run up to the next command at that indent.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="idx">The choice's place.</param>
    /// <returns>Each branch's answer and the places of its first and last command.</returns>
    private static IEnumerable<(int Answer, int First, int Last)> BranchesOf(BuiltList list, int idx)
    {
        EventCommand[] commands = list.Commands;
        int indent = commands[idx].Indent;
        (int Answer, int Opened)? open = null;
        for (int at = idx + 1; at < commands.Length && commands[at].Indent >= indent; at++)
        {
            if (commands[at].Indent > indent)
            {
                continue;
            }

            if (open is { } branch)
            {
                yield return (branch.Answer, branch.Opened + 1, at - 1);
            }

            open = commands[at].Code switch
            {
                When => ((int)commands[at].Number(0), at),
                WhenCancel => (CancelAnswer, at),
                _ => null,
            };
            if (open is null)
            {
                yield break;
            }
        }
    }

    /// <summary>
    /// Lists the branches each answer of an extended choice runs: of the conditional branches on
    /// the result variable that follow the script at its indent, the part whose condition holds for
    /// the answer, each as a branch of its own. An answer that runs none has one branch without
    /// commands.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="choice">The extended choice.</param>
    /// <param name="result">The variable the answer is written into.</param>
    /// <returns>Each branch's answer and the places of its first and last command.</returns>
    private static IEnumerable<(int Answer, int First, int Last)> ExBranchesOf(BuiltList list, ExChoice choice, long result)
    {
        List<ResultBranch> chain = [.. ResultBranches(list.Commands, choice.Last + 1, list.Commands[choice.Idx].Indent, result)];
        foreach (int answer in choice.Answers)
        {
            List<(int First, int Last)> ranges = [.. chain.Select(branch => Holds(branch.Operation, answer, branch.Value) ? branch.Then : branch.Otherwise).OfType<(int First, int Last)>()];
            if (ranges.Count == 0)
            {
                yield return (answer, choice.Last + 1, choice.Last);
            }

            foreach ((int first, int last) in ranges)
            {
                yield return (answer, first, last);
            }
        }
    }

    /// <summary>
    /// Lists the conditional branches on a variable that compare it with a constant, one after the
    /// other at an indent from a place on.
    /// </summary>
    /// <param name="commands">The list's commands.</param>
    /// <param name="from">The place of the first.</param>
    /// <param name="indent">Their indent.</param>
    /// <param name="variable">The variable.</param>
    /// <returns>The branches.</returns>
    private static IEnumerable<ResultBranch> ResultBranches(EventCommand[] commands, int from, int indent, long variable)
    {
        int at = from;
        while (at < commands.Length && commands[at] is { Code: EventCodes.Branch } branch && branch.Indent == indent
            && branch.Number(0) == VariableBranch && branch.Number(1) == variable && branch.Number(2) == ConstantOperand)
        {
            int close = NextAtIndent(commands, at);
            int end = close;
            (int First, int Last)? otherwise = null;
            if (close < commands.Length && commands[close].Code == EventCodes.Else)
            {
                end = NextAtIndent(commands, close);
                otherwise = (close + 1, end - 1);
            }

            yield return new ResultBranch(branch.Number(4), branch.Number(3), (at + 1, close - 1), otherwise);
            at = end + 1;
        }
    }

    /// <summary>
    /// Finds the next command at a command's indent, which closes its part.
    /// </summary>
    /// <param name="commands">The list's commands.</param>
    /// <param name="at">The command's place.</param>
    /// <returns>The next one's place, the list's length for none.</returns>
    private static int NextAtIndent(EventCommand[] commands, int at)
    {
        int indent = commands[at].Indent;
        int next = at + 1;
        while (next < commands.Length && commands[next].Indent > indent)
        {
            next++;
        }

        return next;
    }

    /// <summary>
    /// Tells whether a conditional branch's comparison holds, as <c>Game_Interpreter#command_111</c>
    /// compares.
    /// </summary>
    /// <param name="operation">The comparison: 0 equal, 1 at least, 2 at most, 3 above, 4 below, 5 not equal.</param>
    /// <param name="value">The variable's value.</param>
    /// <param name="constant">The constant it is compared with.</param>
    /// <returns>Whether it holds.</returns>
    private static bool Holds(long operation, long value, long constant) => operation switch
    {
        0 => value == constant,
        1 => value >= constant,
        2 => value <= constant,
        3 => value > constant,
        4 => value < constant,
        5 => value != constant,
        _ => false,
    };

    /// <summary>
    /// Writes what a branch's commands do to what a player holds: each command that changes it as
    /// its code and numbers, each script that does by its place, and each common event it calls that
    /// does by its id.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="first">The place of the branch's first command.</param>
    /// <param name="last">The place of its last command.</param>
    /// <param name="touching">The common events that change what a player holds.</param>
    /// <returns>The parts joined by ";", empty for none.</returns>
    private static string Holdings(BuiltList list, int first, int last, IReadOnlySet<long> touching)
    {
        var parts = new List<string>();
        for (int at = first; at <= last; at++)
        {
            EventCommand command = list.Commands[at];
            if (Gives.Touches(command))
            {
                parts.Add(string.Join(':', new[] { (long)command.Code }.Concat(command.Numbers).Select(number => number.ToString(CultureInfo.InvariantCulture))));
            }
            else if (command.Code == EventCodes.CallCommonEvent && touching.Contains(command.Number(0)))
            {
                parts.Add(string.Create(CultureInfo.InvariantCulture, $"ce{command.Number(0)}"));
            }
            else if (list.HoldingScripts.Any(script => script.Idx == at))
            {
                parts.Add(string.Create(CultureInfo.InvariantCulture, $"script@{at}"));
            }
        }

        return string.Join(';', parts);
    }

    /// <summary>
    /// Reads a whole number a pattern found.
    /// </summary>
    /// <param name="group">The group that found it.</param>
    /// <returns>The number.</returns>
    private static int WholeNumber(Group group) => int.Parse(group.ValueSpan, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture);

    /// <summary>
    /// An <c>ex_choice_add</c> call with an answer's label and id.
    /// </summary>
    /// <returns>The pattern, the id its first group.</returns>
    [GeneratedRegex(@"\bex_choice_add\(\s*(?:""(?:[^""\\]|\\.)*""|'(?:[^'\\]|\\.)*')\s*,\s*(-?[0-9]+)", RegexOptions.CultureInvariant)]
    private static partial Regex ExChoiceAdd();

    /// <summary>
    /// An <c>ex_choice_show</c> call, with the id a cancel gives when it names one.
    /// </summary>
    /// <returns>The pattern, the cancel's id its first group.</returns>
    [GeneratedRegex(@"\bex_choice_show\b(?:\(\s*(-?[0-9]+))?", RegexOptions.CultureInvariant)]
    private static partial Regex ExChoiceShow();

    /// <summary>
    /// A conditional branch on the result variable of an extended choice.
    /// </summary>
    /// <param name="Operation">Its comparison, see <see cref="Holds"/>.</param>
    /// <param name="Value">The constant it compares with.</param>
    /// <param name="Then">The places of the first and last command of the part that runs when it holds.</param>
    /// <param name="Otherwise">Those of its else part, <see langword="null"/> for none.</param>
    private readonly record struct ResultBranch(long Operation, long Value, (int First, int Last) Then, (int First, int Last)? Otherwise);
}
