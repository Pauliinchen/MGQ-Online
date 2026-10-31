//----------------------------------------------------------------
//  ChoiceAsks.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Data.Generator.Build;

/// <summary>
/// Finds the branches of every Show Choices command of the map pages and common events, from which
/// the DLL tells with the live scopes whether a replay asks the receiver the choice ("Issue 73 chest
/// effects.md", rule 4): its branches do different things to the receiver's own things.
/// </summary>
internal static class ChoiceAsks
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
    /// Finds the branches.
    /// </summary>
    /// <param name="game">The game read.</param>
    /// <returns>The branches by list, choice and answer.</returns>
    public static IReadOnlyList<ChoiceBranchRow> Of(BuiltGame game)
    {
        IReadOnlySet<long> touching = Gives.TouchingCommons(game);
        var rows = new List<ChoiceBranchRow>();
        foreach (BuiltList list in Gives.Replayable(game))
        {
            EventCommand[] commands = list.Commands;
            for (int idx = 0; idx < commands.Length; idx++)
            {
                if (commands[idx].Code == ShowChoices)
                {
                    rows.AddRange(BranchesOf(list, idx).Select(branch => new ChoiceBranchRow(list.Site.ListId, idx, branch.Answer, branch.First, branch.Last, Holdings(list, branch.First, branch.Last, touching))));
                }
            }
        }

        return rows;
    }

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
}
