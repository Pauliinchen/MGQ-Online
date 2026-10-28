//----------------------------------------------------------------
//  EventChain.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Started a chain from the keys of a list as the events database holds them
//                            - Followed each transfer into the folder of the map that runs it
//                            - Read the maps and the lists through an event source
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Threading;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Game.Events;

/// <summary>
/// Follows a list through the maps its Transfer Player commands name by a constant, inside the
/// folder of the map whose event runs them, into the autorun pages those maps would show, each map
/// once, and on from those pages: the story chain an event starts across maps.
/// </summary>
/// <remarks>
/// A part's ending often runs on a cutscene map without exits that an earlier event transfers the
/// player to, so holding only the ending's own page strands a player there.
/// </remarks>
/// <param name="source">The game's events, whose maps the chain reaches.</param>
/// <param name="commands">The command index, which walks the common events each list calls.</param>
public sealed class EventChain(IEventSource source, EventCommandIndex commands)
{
    /// <summary>
    /// Held while <see cref="_autoruns"/> changes.
    /// </summary>
    private readonly Lock _autorunsLock = new();

    /// <summary>
    /// The events of each map read so far that have an autorun page, every page kept.
    /// </summary>
    private readonly Dictionary<int, IReadOnlyList<AutorunEvent>> _autoruns = [];

    /// <summary>
    /// Lists the variables a list and the chain it starts set, with the values known before they
    /// run, in the order the walk meets them.
    /// </summary>
    /// <param name="list">The commands.</param>
    /// <param name="map">The map of the event whose page the list is, 0 for none.</param>
    /// <param name="eventId">The event whose page the list is, 0 for none.</param>
    /// <param name="state">The live values the pages' conditions read.</param>
    /// <returns>The variables set.</returns>
    public IReadOnlyList<VariableSet> VariableSetsOf(IReadOnlyList<EventCommand> list, int map, int eventId, IPageState state) =>
        VariableSetsOf(ListKeys.Of(list), map, eventId, state);

    /// <summary>
    /// Lists the variables a list and the chain it starts set by the list's keys, such as a page's
    /// from the events database, see <see cref="VariableSetsOf(IReadOnlyList{EventCommand}, int, int, IPageState)"/>.
    /// </summary>
    /// <param name="start">What the list does by itself.</param>
    /// <param name="map">The map of the event whose page the list is, 0 for none.</param>
    /// <param name="eventId">The event whose page the list is, 0 for none.</param>
    /// <param name="state">The live values the pages' conditions read.</param>
    /// <returns>The variables set.</returns>
    public IReadOnlyList<VariableSet> VariableSetsOf(ListKeys start, int map, int eventId, IPageState state)
    {
        var walk = new Walk(state);
        var reached = new HashSet<int>();
        var pending = new Queue<(ListKeys Keys, int Map, int Event)>();
        pending.Enqueue((start, map, eventId));
        while (pending.TryDequeue(out var step))
        {
            var targets = new List<int>();
            foreach (ListKeys keys in commands.Reached(step.Keys))
            {
                walk.Add(keys, step.Map, step.Event);
                targets.AddRange(keys.Transfers
                    .Where(number => number is > 0 and <= int.MaxValue)
                    .Select(number => GameDataPaths.TransferMap((int)number, step.Event > 0 ? step.Map : 0)));
            }

            foreach (int target in targets.Where(reached.Add))
            {
                foreach (AutorunEvent mapEvent in AutorunsOf(target))
                {
                    if (walk.ShownPage(target, mapEvent) is { } shown && mapEvent.Pages[shown] is { Trigger: EventSorter.AutorunTrigger }
                        && source.PageKeys(target, mapEvent.Id, shown) is { } keys)
                    {
                        pending.Enqueue((keys, target, mapEvent.Id));
                    }
                }
            }
        }

        return walk.Sets;
    }

    /// <summary>
    /// Gets the events of a map that have an autorun page, read on first use.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <returns>The events, none for a map without a file.</returns>
    private IReadOnlyList<AutorunEvent> AutorunsOf(int map)
    {
        lock (_autorunsLock)
        {
            if (!_autoruns.TryGetValue(map, out IReadOnlyList<AutorunEvent>? events))
            {
                _autoruns[map] = events = [.. source.EventIdsOf(map)
                    .Select(eventId => new AutorunEvent(eventId, PagesOf(map, eventId)))
                    .Where(mapEvent => mapEvent.Pages.Any(page => page?.Trigger == EventSorter.AutorunTrigger))];
            }

            return events;
        }
    }

    /// <summary>
    /// Gets every page of a map event.
    /// </summary>
    /// <param name="map">The map.</param>
    /// <param name="eventId">The event.</param>
    /// <returns>The pages in their order, <see langword="null"/> for one the source lacks.</returns>
    private EventPage?[] PagesOf(int map, int eventId) =>
        [.. Enumerable.Range(0, source.PageCountOf(map, eventId)).Select(page => source.Page(map, eventId, page))];

    /// <summary>
    /// A map event that has an autorun page.
    /// </summary>
    /// <param name="Id">The event.</param>
    /// <param name="Pages">Its pages in their order, <see langword="null"/> for one the source lacks.</param>
    private sealed record AutorunEvent(int Id, IReadOnlyList<EventPage?> Pages);

    /// <summary>
    /// What one walk of a chain met so far: the variables set, the switches and self switches
    /// turned on, by which the pages it reaches are chosen.
    /// </summary>
    /// <param name="state">The live values the pages' conditions read.</param>
    private sealed class Walk(IPageState state)
    {
        /// <summary>
        /// The switches turned on.
        /// </summary>
        private readonly List<KeyRange> _switchesOn = [];

        /// <summary>
        /// The self switches turned on, by map, event and letter.
        /// </summary>
        private readonly HashSet<(int Map, int Event, string Letter)> _selfSwitchesOn = [];

        /// <summary>
        /// Gets the variables set, in the order met.
        /// </summary>
        public List<VariableSet> Sets { get; } = [];

        /// <summary>
        /// Notes what a list does by itself.
        /// </summary>
        /// <param name="keys">The list's keys.</param>
        /// <param name="map">The map of the event that runs it, 0 for none.</param>
        /// <param name="eventId">The event that runs it, 0 for none, whose self switches it sets.</param>
        public void Add(ListKeys keys, int map, int eventId)
        {
            Sets.AddRange(keys.VariableSets);
            _switchesOn.AddRange(keys.TurnsOn);
            if (eventId > 0)
            {
                _selfSwitchesOn.UnionWith(keys.SelfSwitchesOn.Select(letter => (map, eventId, letter)));
            }
        }

        /// <summary>
        /// Finds the page the game would show of an event, as Game_Event#find_proper_page does: the
        /// last whose conditions hold, now or once the chain so far ran.
        /// </summary>
        /// <param name="map">The event's map.</param>
        /// <param name="mapEvent">The event.</param>
        /// <returns>The page's place, <see langword="null"/> for none.</returns>
        public int? ShownPage(int map, AutorunEvent mapEvent)
        {
            for (int at = mapEvent.Pages.Count - 1; at >= 0; at--)
            {
                if (mapEvent.Pages[at] is { Condition: var condition } && SwitchOn(condition.Switch1) && SwitchOn(condition.Switch2) && Reaches(condition.Variable, condition.VariableValue)
                    && (condition.SelfSwitch is not { } letter || _selfSwitchesOn.Contains((map, mapEvent.Id, letter)) || state.SelfSwitch(map, mapEvent.Id, letter)))
                {
                    return at;
                }
            }

            return null;
        }

        /// <summary>
        /// Tells whether a page's switch condition holds.
        /// </summary>
        /// <param name="id">The switch, <see langword="null"/> for none.</param>
        /// <returns>Whether it holds.</returns>
        private bool SwitchOn(int? id) => id is not { } on || _switchesOn.Exists(range => range.From <= on && on <= range.To) || state.Switch(on);

        /// <summary>
        /// Tells whether a page's variable condition may hold.
        /// </summary>
        /// <remarks>
        /// A value known only as the chain runs may reach any least value.
        /// </remarks>
        /// <param name="id">The variable, <see langword="null"/> for none.</param>
        /// <param name="least">The least value it must hold.</param>
        /// <returns>Whether it may.</returns>
        private bool Reaches(int? id, long least) =>
            id is not { } variable
            || Sets.Exists(set => set.From <= variable && variable <= set.To && (set.Value is not { } value || value >= least))
            || state.Variable(variable) is { } now && now >= least;
    }
}
