//----------------------------------------------------------------
//  QuestWalk.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Overview;

/// <summary>
/// The live values a quest walk reads.
/// </summary>
public interface IQuestState
{
    /// <summary>
    /// Reads a switch.
    /// </summary>
    /// <param name="id">The switch.</param>
    /// <returns>Whether it is on.</returns>
    bool Switch(long id);

    /// <summary>
    /// Reads a variable as a whole number.
    /// </summary>
    /// <param name="id">The variable.</param>
    /// <returns>Its value, <see langword="null"/> for one that is no number.</returns>
    long? Variable(long id);

    /// <summary>
    /// Tells whether a character is in the party.
    /// </summary>
    /// <param name="actor">The character.</param>
    /// <returns>Whether they are.</returns>
    bool InParty(long actor);

    /// <summary>
    /// Tells whether the party holds an item.
    /// </summary>
    /// <param name="item">The item.</param>
    /// <returns>Whether it holds at least one.</returns>
    bool Holds(long item);
}

/// <summary>
/// A message a quest walk passes, named as the story replay names a command: its list and its
/// place among the list's commands the events database keeps, which a translation leaves where it was.
/// </summary>
/// <param name="Site">The list.</param>
/// <param name="Place">The message's place among the list's kept commands.</param>
public readonly record struct QuestMessage(ReplaySite Site, int Place);

/// <summary>
/// The quests the game tells now, each as the messages it shows.
/// </summary>
/// <param name="Main">The messages of Amira's objective.</param>
/// <param name="Sides">Amira's side quests, each from its mark on.</param>
/// <param name="Companions">The companions' requests on the Pocket Castle's board, each from its mark on.</param>
/// <param name="Board">The board's page that holds the requests, <see langword="null"/> when the game has none.</param>
public sealed record QuestPlaces(IReadOnlyList<QuestMessage> Main, IReadOnlyList<IReadOnlyList<QuestMessage>> Sides, IReadOnlyList<IReadOnlyList<QuestMessage>> Companions, ReplaySite? Board);

/// <summary>
/// Runs through the events that tell the quests as the game would run them now, without running
/// any: Amira's objective, her lists of side quests and the Pocket Castle's board.
/// </summary>
/// <remarks>
/// It reads only the commands the events database keeps, so a list walks alike from the database
/// and from the game's own data; Exit Event Processing is not one of them.
/// </remarks>
public static class QuestWalk
{
    /// <summary>
    /// The common event of Amira the Informant, whose words on the information asked for name the
    /// story's current objective.
    /// </summary>
    public const int ObjectiveEvent = 108;

    /// <summary>
    /// The variable of Amira's information network, whose branch at the top of her event keeps every
    /// hint back until the rabbit side quest moved on.
    /// </summary>
    /// <remarks>The objective passes it, since the overview shows the story's objective, not whether Amira would tell it.</remarks>
    public const int NetworkVariable = 1009;

    /// <summary>
    /// Common events deep the walk follows calls.
    /// </summary>
    public const int MostDepth = 3;

    /// <summary>
    /// Jumps to a label one list follows at most, so labels that jump in a circle end.
    /// </summary>
    public const int MostJumps = 50;

    /// <summary>
    /// The Chaos route's step from which Amira tells the second list of <see cref="SideEvents"/>.
    /// </summary>
    public const int ChaosSideStep = 21;

    /// <summary>
    /// The map of the Pocket Castle's bulletin board, where companions leave their requests.
    /// </summary>
    public const int BoardMap = 228;

    /// <summary>
    /// The event of the Pocket Castle's bulletin board.
    /// </summary>
    public const int BoardEvent = 37;

    /// <summary>
    /// The variable Amira's lists and the board set to 1 before each entry they tell, which marks
    /// where an entry starts.
    /// </summary>
    public const int QuestCount = 11;

    /// <summary>
    /// The kind of a conditional branch on a switch.
    /// </summary>
    private const long SwitchBranch = 0;

    /// <summary>
    /// The kind of a conditional branch on a variable.
    /// </summary>
    private const long VariableBranch = 1;

    /// <summary>
    /// The kind of a conditional branch on a character.
    /// </summary>
    private const long ActorBranch = 4;

    /// <summary>
    /// The kind of a conditional branch on an item.
    /// </summary>
    private const long ItemBranch = 8;

    /// <summary>
    /// Amira's lists of side quests, which her event calls after the objective: the first until the
    /// Chaos route's step <see cref="ChaosSideStep"/>, the second from it.
    /// </summary>
    public static readonly IReadOnlyList<int> SideEvents = [131, 135];

    /// <summary>
    /// <see cref="SideEvents"/> as the objective leaves them out.
    /// </summary>
    private static readonly HashSet<long> SideCalls = [.. SideEvents.Select(id => (long)id)];

    /// <summary>
    /// No common events left out, as Amira's lists and the board are walked.
    /// </summary>
    private static readonly HashSet<long> NoCalls = [];

    /// <summary>
    /// Walks every quest the game tells now.
    /// </summary>
    /// <param name="source">The game's events.</param>
    /// <param name="state">The live values.</param>
    /// <returns>The quests.</returns>
    public static QuestPlaces Walk(IEventSource source, IQuestState state)
    {
        var main = new List<QuestMessage>();
        if (source.CommonList(ObjectiveEvent) is { } objective)
        {
            main.AddRange(Steps(source, state, Common(ObjectiveEvent), objective, 0, false, SideCalls)
                .Where(step => !step.Mark && (step.Indent > 0 || step.Depth > 0)).Select(step => step.Message));
        }

        int sideEvent = SideEvents[state.Variable(StoryIds.RouteVariables[2]) >= ChaosSideStep ? 1 : 0];
        IReadOnlyList<IReadOnlyList<QuestMessage>> sides = source.CommonList(sideEvent) is { } list
            ? Entries(Steps(source, state, Common(sideEvent), list, 0, true, NoCalls))
            : [];
        ReplaySite? board = BoardPage(source);
        IReadOnlyList<IReadOnlyList<QuestMessage>> companions = board is { } page
            ? Entries(Steps(source, state, page, source.Page(page.MapId, page.EventId, page.PageNo)!.List, 0, true, NoCalls))
            : [];
        return new QuestPlaces(main, sides, companions, board);
    }

    /// <summary>
    /// Finds the board's page that holds the requests: its first page with a mark.
    /// </summary>
    /// <param name="source">The game's events.</param>
    /// <returns>Its site, <see langword="null"/> for none.</returns>
    private static ReplaySite? BoardPage(IEventSource source)
    {
        for (int page = 0; page < source.PageCountOf(BoardMap, BoardEvent); page++)
        {
            if (source.Page(BoardMap, BoardEvent, page) is { } found && found.List.Any(IsMark))
            {
                return ReplaySite.Page(BoardMap, BoardEvent, page);
            }
        }

        return null;
    }

    /// <summary>
    /// Splits a walk into the entries its marks start, each up to the end of the mark's block.
    /// </summary>
    /// <param name="steps">The walk.</param>
    /// <returns>Each entry's messages.</returns>
    private static List<IReadOnlyList<QuestMessage>> Entries(IEnumerable<Step> steps)
    {
        var entries = new List<IReadOnlyList<QuestMessage>>();
        (int Indent, int Depth, List<QuestMessage> Messages)? entry = null;
        foreach (Step step in steps)
        {
            if (step.Mark)
            {
                entry = (step.Indent, step.Depth, []);
                entries.Add(entry.Value.Messages);
            }
            else if (entry is { } open)
            {
                if (step.Depth < open.Depth || (step.Depth == open.Depth && step.Indent < open.Indent))
                {
                    entry = null;
                }
                else
                {
                    open.Messages.Add(step.Message);
                }
            }
        }

        return entries;
    }

    /// <summary>
    /// Runs through a list as the game would run it now: the branches that hold, the first answer of
    /// a choice, the common events it calls and the labels it jumps to.
    /// </summary>
    /// <param name="source">The game's events.</param>
    /// <param name="state">The live values.</param>
    /// <param name="site">The list's site.</param>
    /// <param name="list">The list's commands.</param>
    /// <param name="depth">How many calls deep the list is.</param>
    /// <param name="network">Whether a branch on Amira's network compares as the game does.</param>
    /// <param name="leftOut">The common events whose calls are passed.</param>
    /// <returns>The messages and marks met, in order.</returns>
    private static IEnumerable<Step> Steps(IEventSource source, IQuestState state, ReplaySite site, IReadOnlyList<EventCommand> list, int depth, bool network, IReadOnlySet<long> leftOut)
    {
        var held = new Dictionary<int, bool>();
        var choosing = new HashSet<int>();
        int? skip = null;
        int jumps = 0;
        int kept = 0;
        for (int index = 0; index < list.Count; index++)
        {
            EventCommand command = list[index];
            if (!EventSchema.Keeps(command.Code))
            {
                continue;
            }

            int place = kept++;
            if (skip is { } over && command.Indent > over)
            {
                continue;
            }

            skip = null;
            switch (command.Code)
            {
                case EventCodes.Branch:
                    held[command.Indent] = Holds(command, state, network);
                    skip = held[command.Indent] ? null : command.Indent;
                    break;
                case EventCodes.Else when held.GetValueOrDefault(command.Indent):
                case EventCodes.CancelBranch:
                    skip = command.Indent;
                    break;
                case EventCodes.ShowChoices:
                    choosing.Add(command.Indent);
                    break;
                case EventCodes.ChoiceBranch:
                    skip = choosing.Remove(command.Indent) ? null : command.Indent;
                    break;
                case EventCodes.ShowText:
                    yield return new Step(false, new QuestMessage(site, place), command.Indent, depth);
                    break;
                case EventCodes.ControlVariables when IsMark(command):
                    yield return new Step(true, default, command.Indent, depth);
                    break;
                case EventCodes.CallCommonEvent when depth < MostDepth && !leftOut.Contains(command.Number(0)) && source.CommonList(command.Number(0)) is { } called:
                    foreach (Step step in Steps(source, state, Common((int)command.Number(0)), called, depth + 1, network, leftOut))
                    {
                        yield return step;
                    }

                    break;
                case EventCodes.JumpToLabel:
                    long label = command.Number(0);
                    if (++jumps > MostJumps || label < 0 || label >= list.Count)
                    {
                        yield break;
                    }

                    kept = list.Take((int)label + 1).Count(other => EventSchema.Keeps(other.Code));
                    index = (int)label;
                    break;
            }
        }
    }

    /// <summary>
    /// Tells whether a branch holds now: on a switch, a variable, a party member or an item.
    /// </summary>
    /// <remarks>A script's check never holds, since the walk runs no script, so the board's request behind a class level never shows.</remarks>
    /// <param name="branch">The conditional branch.</param>
    /// <param name="state">The live values.</param>
    /// <param name="network">Whether a branch on Amira's network compares as the game does.</param>
    /// <returns>Whether it holds.</returns>
    private static bool Holds(EventCommand branch, IQuestState state, bool network) => branch.Number(0) switch
    {
        SwitchBranch => state.Switch(branch.Number(1)) == (branch.Number(2) == 0),
        VariableBranch => (network || branch.Number(1) != NetworkVariable) && Compares(branch, state),
        ActorBranch => branch.Number(2) == 0 && state.InParty(branch.Number(1)),
        ItemBranch => state.Holds(branch.Number(1)),
        _ => false,
    };

    /// <summary>
    /// Compares a variable as a branch on it does: with a number or another variable, by its operator.
    /// </summary>
    /// <param name="branch">The conditional branch.</param>
    /// <param name="state">The live values.</param>
    /// <returns>Whether it holds; <see langword="false"/> for a value that is no number.</returns>
    private static bool Compares(EventCommand branch, IQuestState state)
    {
        if (state.Variable(branch.Number(1)) is not { } value || (branch.Number(2) == 0 ? branch.Number(3) : state.Variable(branch.Number(3))) is not { } other)
        {
            return false;
        }

        return branch.Number(4) switch
        {
            0 => value == other,
            1 => value >= other,
            2 => value <= other,
            3 => value > other,
            4 => value < other,
            5 => value != other,
            _ => false,
        };
    }

    /// <summary>
    /// Tells whether a command marks the start of a quest: <see cref="QuestCount"/> set to 1.
    /// </summary>
    /// <param name="command">The command.</param>
    /// <returns>Whether it does.</returns>
    private static bool IsMark(EventCommand command) =>
        command.Code == EventCodes.ControlVariables && command.Number(0) == QuestCount && command.Number(1) == QuestCount
        && command.Number(2) == 0 && command.Number(3) == 0 && command.Number(4) == 1;

    /// <summary>
    /// Names a common event's list.
    /// </summary>
    /// <param name="id">The common event.</param>
    /// <returns>Its site.</returns>
    private static ReplaySite Common(int id) => new(0, 0, 0, id);

    /// <summary>
    /// A message or a mark the walk met.
    /// </summary>
    /// <param name="Mark">Whether it is a mark, else a message.</param>
    /// <param name="Message">The message, <see langword="default"/> for a mark.</param>
    /// <param name="Indent">The command's indent.</param>
    /// <param name="Depth">How many calls deep it is.</param>
    private readonly record struct Step(bool Mark, QuestMessage Message, int Indent, int Depth);
}
