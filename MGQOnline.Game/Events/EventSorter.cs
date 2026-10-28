//----------------------------------------------------------------
//  EventSorter.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Read scripts and jumps by their classified kinds and places
//                            - Read the common events and scratch flags from an event source
//                            - Opened the list of the player's own common events
//      Paulinchen  2026-10-23: Sorted a page that calls a battlefuck event as the player's own
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Game.Events;

/// <summary>
/// Sorts event pages by what of them can run now: a talk, travel, a chest, a battle without
/// dialogue, story, or a battlefuck of the player's own. A branch on a switch or a variable runs only when its condition holds, its
/// else only when it does not; a branch on anything else may run either way.
/// </summary>
/// <remarks>
/// Exits hold the story's warnings in such branches, as Iliasville's do, which would make every
/// exit story long after the warnings passed.
/// </remarks>
/// <param name="source">The game's events: the common events and the scratch switches and variables.</param>
public sealed class EventSorter(IEventSource source)
{
    /// <summary>
    /// How deep called common events are followed; one deeper counts as story.
    /// </summary>
    public const int MaxDepth = 5;

    /// <summary>
    /// The trigger of a page that runs by itself as the player enters.
    /// </summary>
    public const int AutorunTrigger = 3;

    /// <summary>
    /// The highest trigger an exit starts by: the action button, the player's or the event's touch.
    /// </summary>
    private const int MostExitTrigger = 2;

    /// <summary>
    /// The switches that are never scratch, whatever their names: the story's.
    /// </summary>
    private const long FirstStorySwitch = 1001;

    /// <summary>
    /// See <see cref="FirstStorySwitch"/>.
    /// </summary>
    private const long LastStorySwitch = 2000;

    /// <summary>
    /// Event commands that move the story on wherever they appear: party changes, vehicles, name
    /// input, game over and title.
    /// </summary>
    private static readonly int[] StoryCodes =
        [EventCodes.ChangePartyMember, EventCodes.GetOnOffVehicle, EventCodes.NameInput, EventCodes.GameOver, EventCodes.ReturnToTitle];

    /// <summary>
    /// Event commands that show dialogue: text, choices, scrolling text.
    /// </summary>
    private static readonly int[] MessageCodes = [EventCodes.ShowText, EventCodes.ShowChoices, EventCodes.ScrollingText];

    /// <summary>
    /// Common events that run only in the player's own game, never as the party's story: the game's
    /// map display, its Pocket Castle call, its processing after every battle and its transfer process.
    /// </summary>
    public static readonly IReadOnlySet<long> OwnCommonEvents = new HashSet<long> { 2, 3, 5, 114 };

    /// <summary>
    /// The marks a branch of a choice makes story with.
    /// </summary>
    private const EventMarks StoryMarks = EventMarks.Story | EventMarks.Sets;

    /// <summary>
    /// The marks an exit has none of.
    /// </summary>
    private const EventMarks NoExitMarks = EventMarks.Story | EventMarks.Says | EventMarks.Battle | EventMarks.Gives | EventMarks.OwnSwitch;

    /// <summary>
    /// Sorts a map event's page, as the game shows it now.
    /// </summary>
    /// <param name="page">The page, <see langword="null"/> for an event that shows none.</param>
    /// <param name="state">The live values.</param>
    /// <param name="resident">Whether the page is a Pocket Castle resident's, which is a talk.</param>
    /// <returns>Its kind; a talk for an event without a page.</returns>
    public EventKind KindOfPage(EventPage? page, IEventState state, bool resident = false)
    {
        if (page is null)
        {
            return EventKind.Talk;
        }

        if (IsExit(page, state))
        {
            return EventKind.Travel;
        }

        EventKind sorted = KindOf(page.List, state, resident);

        // A scene that runs by itself and hides its story behind a choice, as Alice's recap at the
        // Strategy Conference, plays in the teller's game alone: a viewer's copy, ended at the story
        // as a talk's would be, would start over and over.
        return sorted == EventKind.Talk && page.Trigger == AutorunTrigger && MayTell(page.List, state) ? EventKind.Story : sorted;
    }

    /// <summary>
    /// Reports whether a page only takes the player elsewhere when they step on it or press a
    /// button: a transfer without dialogue, battle, items, self switch or script, which may note a
    /// switch or variable on the way, such as the warp and library flags of a town's entrance.
    /// </summary>
    /// <param name="page">The page.</param>
    /// <param name="state">The live values.</param>
    /// <returns>Whether it does.</returns>
    public bool IsExit(EventPage page, IEventState state)
    {
        if (page.Trigger > MostExitTrigger)
        {
            return false;
        }

        EventMarks marks = MarksOf(page.List, state);
        return marks.HasFlag(EventMarks.Travel) && (marks & NoExitMarks) == 0;
    }

    /// <summary>
    /// Sorts a list of commands by what of it can run now.
    /// </summary>
    /// <remarks>
    /// Story only behind a choice, such as a trader's "Talk" that moves a side quest on, leaves a
    /// page a talk, or travel when a transfer lies behind the choice too, which may turn into story
    /// once that choice is taken.
    /// </remarks>
    /// <param name="list">The commands.</param>
    /// <param name="state">The live values.</param>
    /// <param name="resident">Whether the list is a Pocket Castle resident's, which is a talk.</param>
    /// <returns>Its kind; a battlefuck's page is the player's own, though it moves the story on.</returns>
    public EventKind KindOf(IReadOnlyList<EventCommand> list, IEventState state, bool resident = false)
    {
        var run = new Run(this, state);
        IReadOnlyList<EventCommand> runnable = run.Runnable(list);

        // Only what can run now counts, since a town's quest page may hold its battlefuck in one
        // step's branch and story in the others.
        if (runnable.Any(BattlefuckEvents.Calls))
        {
            return EventKind.Own;
        }

        if (resident)
        {
            return EventKind.Talk;
        }

        // Wandering monsters call the game's common events before and after their battle, which set
        // variables, so a battle is told apart by the page itself: a fight without its own dialogue.
        if (runnable.Any(command => command.Code == EventCodes.Battle) && !runnable.Any(IsMessage))
        {
            return EventKind.Battle;
        }

        EventMarks marks = run.MarksOf(runnable, 0);
        if ((marks & StoryMarks) != 0)
        {
            return EventKind.Story;
        }

        if (marks.HasFlag(EventMarks.Gives) && marks.HasFlag(EventMarks.OwnSwitch) && !marks.HasFlag(EventMarks.ChoiceStory))
        {
            return EventKind.Chest;
        }

        if (IsOneTimeTalk(marks))
        {
            return EventKind.Talk;
        }

        if ((marks & (EventMarks.OwnSwitch | EventMarks.Battle)) != 0)
        {
            return EventKind.Story;
        }

        return marks.HasFlag(EventMarks.Travel) ? EventKind.Travel : EventKind.Talk;
    }

    /// <summary>
    /// Finds what the commands of a list that can run now do.
    /// </summary>
    /// <param name="list">The commands.</param>
    /// <param name="state">The live values.</param>
    /// <returns>The marks.</returns>
    public EventMarks MarksOf(IReadOnlyList<EventCommand> list, IEventState state)
    {
        var run = new Run(this, state);
        return run.MarksOf(run.Runnable(list), 0);
    }

    /// <summary>
    /// Reports whether a talk turns into story behind one of its choices.
    /// </summary>
    /// <param name="list">The commands.</param>
    /// <param name="state">The live values.</param>
    /// <returns>Whether it does.</returns>
    public bool MayTell(IReadOnlyList<EventCommand> list, IEventState state) => MarksOf(list, state).HasFlag(EventMarks.ChoiceStory);

    /// <summary>
    /// Reports whether a list is a story scene: story with its own dialogue or novel scene.
    /// </summary>
    /// <param name="list">The commands.</param>
    /// <param name="state">The live values.</param>
    /// <param name="resident">Whether the list is a Pocket Castle resident's.</param>
    /// <returns>Whether it is.</returns>
    public bool IsScene(IReadOnlyList<EventCommand> list, IEventState state, bool resident = false)
    {
        bool shows = new Run(this, state).Runnable(list).Any(command =>
            IsMessage(command) || (command.Code == EventCodes.Script && command.TextKind == TextKind.Novel));
        return shows && KindOf(list, state, resident) == EventKind.Story;
    }

    /// <summary>
    /// Reports whether one command of a list moves the story on, whatever branch it stands in.
    /// </summary>
    /// <param name="list">The commands.</param>
    /// <param name="index">The command's place.</param>
    /// <param name="state">The live values, which a called common event's branches read.</param>
    /// <returns>Whether it does.</returns>
    public bool IsStoryCommand(IReadOnlyList<EventCommand> list, int index, IEventState state)
    {
        if (index < 0 || index >= list.Count)
        {
            return false;
        }

        EventMarks marks = EventMarks.None;
        new Run(this, state).Mark(ref marks, list, index, 0);
        return (marks & (StoryMarks | EventMarks.OwnSwitch | EventMarks.Battle | EventMarks.ChoiceStory)) != 0;
    }

    /// <summary>
    /// Finds the self switch a chest's page sets: its first that turns one on.
    /// </summary>
    /// <param name="list">The page's commands.</param>
    /// <returns>The self switch's letter, <see langword="null"/> when the page sets none.</returns>
    public static string? ChestLetter(IReadOnlyList<EventCommand> list) =>
        list.FirstOrDefault(command => command.Code == EventCodes.ControlSelfSwitch && command.Number(1) == 0) is { Code: EventCodes.ControlSelfSwitch } found
            ? CommandClassifier.LetterOf(found.Number(0))
            : null;

    /// <summary>
    /// Reports whether a command shows dialogue.
    /// </summary>
    /// <param name="command">The command.</param>
    /// <returns>Whether it does.</returns>
    private static bool IsMessage(EventCommand command) => MessageCodes.Contains(command.Code);

    /// <summary>
    /// Finds a common event's commands.
    /// </summary>
    /// <param name="id">The common event.</param>
    /// <returns>Its commands, <see langword="null"/> for none.</returns>
    private IReadOnlyList<EventCommand>? CommonList(long id) => source.CommonList(id);

    /// <summary>
    /// Reports whether marks are a one-time talk's: dialogue and the page's own self switch, nothing
    /// else, as a signpost or a villager who says something once.
    /// </summary>
    /// <param name="marks">The marks.</param>
    /// <returns>Whether they are.</returns>
    private static bool IsOneTimeTalk(EventMarks marks) => marks == (EventMarks.OwnSwitch | EventMarks.Says);

    /// <summary>
    /// Reports whether a switch is only scratch, or the player's own.
    /// </summary>
    /// <param name="id">The switch.</param>
    /// <param name="state">The live values.</param>
    /// <returns>Whether it is.</returns>
    private bool TemporarySwitch(long id, IEventState state) =>
        id is < FirstStorySwitch or > LastStorySwitch && (source.IsScratchSwitch(id) || state.PersonalSwitch(id));

    /// <summary>
    /// Reports whether a variable is only scratch, or the player's own, such as affection.
    /// </summary>
    /// <param name="id">The variable.</param>
    /// <param name="state">The live values.</param>
    /// <returns>Whether it is.</returns>
    private bool TemporaryVariable(long id, IEventState state) => source.IsScratchVariable(id) || state.PersonalVariable(id);

    /// <summary>
    /// One sort: the live values it reads and the common events it sorted, once per id and depth.
    /// </summary>
    /// <param name="sorter">The sorter.</param>
    /// <param name="state">The live values.</param>
    private sealed class Run(EventSorter sorter, IEventState state)
    {
        /// <summary>
        /// The marks of each common event by id and depth, see <see cref="CommonMarks"/>.
        /// </summary>
        private readonly Dictionary<(long Id, int Depth), EventMarks> _common = [];

        /// <summary>
        /// Lists the commands of a list that can run now. A jump that can run makes the commands
        /// after its label run too, up to the end of the label's block, also inside a branch that
        /// does not hold.
        /// </summary>
        /// <param name="list">The commands.</param>
        /// <returns>Those that can run, in their order.</returns>
        public IReadOnlyList<EventCommand> Runnable(IReadOnlyList<EventCommand> list)
        {
            HashSet<long> variables = ChoiceVariables(list);
            var kept = new bool[list.Count];
            var starts = new Queue<int>([0]);
            var jumped = new HashSet<long>();
            while (starts.Count > 0)
            {
                foreach (int place in RunnableFrom(list, starts.Dequeue(), variables))
                {
                    kept[place] = true;
                    EventCommand command = list[place];
                    long label = command.Number(0);
                    if (command.Code == EventCodes.JumpToLabel && jumped.Add(label) && label >= 0 && label < list.Count)
                    {
                        starts.Enqueue((int)label);
                    }
                }
            }

            return list.Where((_, place) => kept[place]).ToArray();
        }

        /// <summary>
        /// Finds what a list of commands does. What a choice's branch does that would make it story
        /// counts as <see cref="EventMarks.ChoiceStory"/> instead, since the player may never take it.
        /// </summary>
        /// <param name="list">The commands that can run, see <see cref="Runnable"/>.</param>
        /// <param name="depth">How many common events deep the list is.</param>
        /// <returns>The marks.</returns>
        public EventMarks MarksOf(IReadOnlyList<EventCommand> list, int depth)
        {
            EventMarks marks = EventMarks.None;
            EventMarks choice = EventMarks.None;
            var branches = new Stack<int>();
            var open = new Dictionary<int, bool>();
            HashSet<long> variables = ChoiceVariables(list);
            for (int index = 0; index < list.Count; index++)
            {
                EventCommand command = list[index];
                while (branches.Count > 0 && command.Indent <= branches.Peek())
                {
                    branches.Pop();
                }

                if (command.Code is EventCodes.ChoiceBranch or EventCodes.CancelBranch || IsChoiceBranch(command, variables, open))
                {
                    branches.Push(command.Indent);
                    continue;
                }

                if (branches.Count == 0)
                {
                    Mark(ref marks, list, index, depth);
                }
                else
                {
                    Mark(ref choice, list, index, depth);
                }
            }

            // A chest asks first whether to open it, so its own switch with items behind a choice
            // keeps it a chest, unless story lies behind the choice too, as behind Amira's paid tip in
            // Iliasburg, whose story value a chest kept from the world's story.
            bool chest = choice.HasFlag(EventMarks.Gives) && choice.HasFlag(EventMarks.OwnSwitch)
                && (choice & (StoryMarks | EventMarks.Battle | EventMarks.ChoiceStory)) == 0;
            if ((choice & (StoryMarks | EventMarks.Battle | EventMarks.ChoiceStory)) != 0 || (choice.HasFlag(EventMarks.OwnSwitch) && !chest))
            {
                marks |= EventMarks.ChoiceStory;
            }

            marks |= choice & (EventMarks.Says | EventMarks.Gives | EventMarks.Travel);
            return chest ? marks | EventMarks.OwnSwitch : marks;
        }

        /// <summary>
        /// Marks what one command does.
        /// </summary>
        /// <param name="marks">What the list does so far.</param>
        /// <param name="list">The commands.</param>
        /// <param name="index">The command's place.</param>
        /// <param name="depth">How many common events deep the list is.</param>
        public void Mark(ref EventMarks marks, IReadOnlyList<EventCommand> list, int index, int depth)
        {
            EventCommand command = list[index];
            switch (command.Code)
            {
                case EventCodes.ControlSwitches:
                    if (!marks.HasFlag(EventMarks.Sets) && !Ids(command).All(id => sorter.TemporarySwitch(id, state)))
                    {
                        marks |= EventMarks.Sets;
                    }

                    break;
                case EventCodes.ControlVariables:
                    if (!marks.HasFlag(EventMarks.Sets) && !Ids(command).All(id => sorter.TemporaryVariable(id, state)))
                    {
                        marks |= EventMarks.Sets;
                    }

                    break;
                case EventCodes.ControlSelfSwitch:
                    marks |= EventMarks.OwnSwitch;
                    break;
                case EventCodes.ChangeGold or EventCodes.ChangeItems or EventCodes.ChangeWeapons or EventCodes.ChangeArmors:
                    marks |= EventMarks.Gives;
                    break;
                case EventCodes.TransferPlayer:
                    marks |= EventMarks.Travel;
                    break;
                case EventCodes.Battle:
                    marks |= EventMarks.Battle;
                    break;
                case EventCodes.ShowText or EventCodes.ShowChoices or EventCodes.ScrollingText:
                    marks |= EventMarks.Says;
                    break;
                case EventCodes.Script:
                    marks |= ScriptMarks(command.TextKind);
                    break;
                case EventCodes.CallCommonEvent:
                    marks |= CommonMarks(command.Number(0), depth + 1);
                    break;
                default:
                    if (StoryCodes.Contains(command.Code))
                    {
                        marks |= EventMarks.Story;
                    }

                    break;
            }
        }

        /// <summary>
        /// Lists the variables the choice scripts of a list write their answers into.
        /// </summary>
        /// <param name="list">The commands.</param>
        /// <returns>The variables.</returns>
        private static HashSet<long> ChoiceVariables(IReadOnlyList<EventCommand> list)
        {
            var ids = new HashSet<long>();
            foreach (EventCommand command in list)
            {
                if (command.Code == EventCodes.Script && command.TextKind == TextKind.Choice)
                {
                    ids.Add(command.Number(0));
                }
            }

            return ids;
        }

        /// <summary>
        /// Lists the switches or variables a Control Switches or Control Variables command sets.
        /// </summary>
        /// <param name="command">The command.</param>
        /// <returns>Its range's ids, none for a range that ends before it starts.</returns>
        private static IEnumerable<long> Ids(EventCommand command)
        {
            for (long id = command.Number(0); id <= command.Number(1); id++)
            {
                yield return id;
            }
        }

        /// <summary>
        /// Reports whether a command starts a branch on a choice script's variable, which counts as a
        /// choice's branch: the branch itself and its else, until the branch ends.
        /// </summary>
        /// <param name="command">The command.</param>
        /// <param name="variables">The choice scripts' variables.</param>
        /// <param name="open">Whether the branch open at each indent is such a branch, kept between calls.</param>
        /// <returns>Whether it does.</returns>
        private static bool IsChoiceBranch(EventCommand command, HashSet<long> variables, Dictionary<int, bool> open)
        {
            switch (command.Code)
            {
                case EventCodes.Branch:
                    bool choice = command.Number(0) == 1 && variables.Contains(command.Number(1));
                    open[command.Indent] = choice;
                    return choice;
                case EventCodes.Else:
                    return open.GetValueOrDefault(command.Indent);
                case EventCodes.BranchEnd:
                    open.Remove(command.Indent);
                    return false;
                default:
                    return false;
            }
        }

        /// <summary>
        /// Marks what a script does: a talk's, travel, or story for any other.
        /// </summary>
        /// <param name="kind">The script's kind.</param>
        /// <returns>Its marks.</returns>
        private static EventMarks ScriptMarks(TextKind kind) => kind switch
        {
            TextKind.Travel => EventMarks.Travel,
            TextKind.Talk or TextKind.Choice => EventMarks.None,
            _ => EventMarks.Story,
        };

        /// <summary>
        /// Lists the places of the commands that can run from a place in a list: to its end from the
        /// list's start, else to the end of the block the place stands in.
        /// </summary>
        /// <param name="list">The commands.</param>
        /// <param name="start">The place.</param>
        /// <param name="variables">The choice scripts' variables, on whose branches either way may run.</param>
        /// <returns>The places of those that can run.</returns>
        private IEnumerable<int> RunnableFrom(IReadOnlyList<EventCommand> list, int start, HashSet<long> variables)
        {
            var held = new Dictionary<int, bool?>();
            int? skip = null;
            int? floor = start > 0 ? list[start].Indent : null;
            for (int place = start; place < list.Count; place++)
            {
                EventCommand command = list[place];
                int indent = command.Indent;
                if (floor is { } lowest && indent < lowest)
                {
                    yield break;
                }

                if (skip is { } skipped && indent > skipped)
                {
                    continue;
                }

                switch (command.Code)
                {
                    case EventCodes.Branch:
                        held[indent] = command.Number(0) == 1 && variables.Contains(command.Number(1)) ? null : Holds(command);
                        if (held[indent] == false)
                        {
                            skip = indent;
                        }

                        break;
                    case EventCodes.Else:
                        skip = held.GetValueOrDefault(indent) == true ? indent : null;
                        break;
                    case EventCodes.BranchEnd:
                        skip = null;
                        break;
                }

                yield return place;
            }
        }

        /// <summary>
        /// Reports whether a branch's condition on a switch or a variable holds now.
        /// </summary>
        /// <param name="command">The branch.</param>
        /// <returns>Whether it holds, <see langword="null"/> for a condition on anything else.</returns>
        private bool? Holds(EventCommand command)
        {
            switch (command.Number(0))
            {
                case 0:
                    return state.Switch(command.Number(1)) == (command.Number(2) == 0);
                case 1:
                    if (state.Variable(command.Number(1)) is not { } value)
                    {
                        return null;
                    }

                    long? other = command.Number(2) == 0 ? command.Number(3) : state.Variable(command.Number(3));
                    if (other is not { } compared)
                    {
                        return null;
                    }

                    // Ruby picks the comparison from a list, so -1 is its last and 6 is none.
                    long operation = command.Number(4);
                    return (operation < 0 ? operation + 6 : operation) switch
                    {
                        0 => value == compared,
                        1 => value >= compared,
                        2 => value <= compared,
                        3 => value > compared,
                        4 => value < compared,
                        5 => value != compared,
                        _ => null,
                    };
                default:
                    return null;
            }
        }

        /// <summary>
        /// Finds what a called common event does, of what can run now, once per id and depth: a
        /// common event sorted deep down counts the events it calls past <see cref="MaxDepth"/> as
        /// story, which a call from higher up must not take over.
        /// </summary>
        /// <param name="id">The common event.</param>
        /// <param name="depth">How deep it is called.</param>
        /// <returns>Its marks; none for one of the player's own common events, which runs in the player's own game whoever calls it; story past <see cref="MaxDepth"/>.</returns>
        private EventMarks CommonMarks(long id, int depth)
        {
            if (OwnCommonEvents.Contains(id))
            {
                return EventMarks.None;
            }

            if (depth > MaxDepth)
            {
                return EventMarks.Story;
            }

            if (!_common.TryGetValue((id, depth), out EventMarks marks))
            {
                marks = sorter.CommonList(id) is { } list ? MarksOf(Runnable(list), depth) : EventMarks.None;
                _common[(id, depth)] = marks;
            }

            return marks;
        }
    }
}
