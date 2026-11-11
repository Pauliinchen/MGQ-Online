//----------------------------------------------------------------
//  DerivedAnswers.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Named each answer by its choice's number among the page's Show Choices
//      Paulinchen  2026-11-01: Named each answer by its choice's place among the kept commands
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Data.Events;

namespace MGQOnline.Game.Story;

/// <summary>
/// Answers the choices of a derived entry of the history before the log, which has no opener run:
/// each choice of its page takes the branch that ends with the source's letters, the self switches
/// of the event the source holds on ("Issue 73 chest effects.md", "Streams, logs and catch-up").
/// </summary>
public static class DerivedAnswers
{
    /// <summary>
    /// The command that shows choices.
    /// </summary>
    private const int ShowChoices = 102;

    /// <summary>
    /// The command that starts a choice's branch, its first number the branch.
    /// </summary>
    private const int ChoiceBranch = 402;

    /// <summary>
    /// The command that starts the branch of a choice cancelled.
    /// </summary>
    private const int CancelBranch = 403;

    /// <summary>
    /// The command that ends a choice's branches.
    /// </summary>
    private const int BranchesEnd = 404;

    /// <summary>
    /// The command that writes a self switch: its letter as 1 to 4, then 0 for on.
    /// </summary>
    private const int ControlSelfSwitch = 123;

    /// <summary>
    /// The self switches' letters by the number the database keeps them as.
    /// </summary>
    private static readonly string[] Letters = ["", "A", "B", "C", "D"];

    /// <summary>
    /// Answers the choices of a page: a choice one of whose branches alone turns on self switches,
    /// each of the source's letters, takes that branch; one whose branches end alike is left to ask.
    /// </summary>
    /// <param name="store">The events database.</param>
    /// <param name="site">The page.</param>
    /// <param name="letters">The letters of the page's event the source holds on.</param>
    /// <returns>The answers as the opener's run would record them, the first occurrence of each choice; none for a common event or a page the database lacks.</returns>
    public static IReadOnlyList<ReplayInput> Of(EventStore store, ReplaySite site, IReadOnlyCollection<string> letters)
    {
        ArgumentNullException.ThrowIfNull(store);
        ArgumentNullException.ThrowIfNull(letters);
        if (site.IsCommon || store.Page(site.MapId, site.EventId, site.PageNo) is not { } page)
        {
            return [];
        }

        IReadOnlyList<CommandRow> commands = store.Commands(page.ListId);
        var answers = new List<ReplayInput>();
        int choices = 0;
        for (int index = 0; index < commands.Count; index++)
        {
            if (commands[index].Code != ShowChoices)
            {
                continue;
            }

            if (BranchOf(commands, index, letters) is { } branch)
            {
                answers.Add(new ReplayInput(StoryPlain.PlaceText(site.ToString(), ShowChoices, choices), 0, "choice", branch));
            }

            choices++;
        }

        return answers;
    }

    /// <summary>
    /// Finds the branch of a choice that ends with the source's letters.
    /// </summary>
    /// <param name="commands">The page's kept commands.</param>
    /// <param name="choice">The choice's place among them.</param>
    /// <param name="letters">The source's letters.</param>
    /// <returns>The branch, <see langword="null"/> when none or more than one does.</returns>
    private static long? BranchOf(IReadOnlyList<CommandRow> commands, int choice, IReadOnlyCollection<string> letters)
    {
        int indent = commands[choice].Indent;
        var turnedOn = new Dictionary<long, HashSet<string>>();
        long? branch = null;
        for (int index = choice + 1; index < commands.Count; index++)
        {
            CommandRow command = commands[index];
            if (command.Indent == indent && command.Code is BranchesEnd)
            {
                break;
            }

            if (command.Indent == indent && command.Code is ChoiceBranch or CancelBranch)
            {
                branch = command.Code == ChoiceBranch ? command.P0 : null;
                continue;
            }

            if (branch is { } open && command.Code == ControlSelfSwitch && command.P1 == 0 && command.P0 is > 0 and < 5)
            {
                (turnedOn.TryGetValue(open, out HashSet<string>? found) ? found : turnedOn[open] = []).Add(Letters[command.P0]);
            }
        }

        long[] fitting = [.. turnedOn.Where(pair => pair.Value.All(letters.Contains)).Select(pair => pair.Key)];
        return fitting.Length == 1 ? fitting[0] : null;
    }
}
