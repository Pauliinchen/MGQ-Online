//----------------------------------------------------------------
//  EventChain.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Threading;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Game.Events;

/// <summary>
/// Follows a list through the maps its Transfer Player commands name by a constant into the
/// autorun pages those maps would show, each map once, and on from those pages: the story chain an
/// event starts across maps.
/// </summary>
/// <remarks>
/// A part's ending often runs on a cutscene map without exits that an earlier event transfers the
/// player to, so holding only the ending's own page strands a player there.
/// </remarks>
/// <param name="data">The game's data, whose maps the chain reaches.</param>
/// <param name="commands">The command index, which walks the common events each list calls.</param>
public sealed class EventChain(GameData data, EventCommandIndex commands)
{
    /// <summary>
    /// Held while <see cref="_autoruns"/> changes.
    /// </summary>
    private readonly Lock _autorunsLock = new();

    /// <summary>
    /// The events of each map read so far that have an autorun page, every page kept.
    /// </summary>
    private readonly Dictionary<int, IReadOnlyList<MapEvent>> _autoruns = [];

    /// <summary>
    /// Lists the variables a list and the chain it starts set, with the values known before they
    /// run, in the order the walk meets them.
    /// </summary>
    /// <param name="list">The commands.</param>
    /// <param name="map">The map of the event whose page the list is, 0 for none.</param>
    /// <param name="eventId">The event whose page the list is, 0 for none.</param>
    /// <param name="state">The live values the pages' conditions read.</param>
    /// <returns>The variables set.</returns>
    public IReadOnlyList<VariableSet> VariableSetsOf(IReadOnlyList<EventCommand> list, int map, int eventId, IPageState state)
    {
        var walk = new Walk(state);
        var reached = new HashSet<long>();
        var pending = new Queue<(IReadOnlyList<EventCommand> List, int Map, int Event)>();
        pending.Enqueue((list, map, eventId));
        while (pending.TryDequeue(out var step))
        {
            var targets = new List<long>();
            foreach (ListKeys keys in commands.Reached(step.List))
            {
                walk.Add(keys, step.Map, step.Event);
                targets.AddRange(keys.Transfers);
            }

            foreach (long target in targets.Where(target => target is > 0 and <= int.MaxValue && reached.Add(target)))
            {
                foreach (MapEvent mapEvent in AutorunsOf((int)target))
                {
                    if (walk.ShownPage((int)target, mapEvent) is { Trigger: EventSorter.AutorunTrigger } page)
                    {
                        pending.Enqueue((page.List, (int)target, mapEvent.Id));
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
    private IReadOnlyList<MapEvent> AutorunsOf(int map)
    {
        lock (_autorunsLock)
        {
            if (!_autoruns.TryGetValue(map, out IReadOnlyList<MapEvent>? events))
            {
                _autoruns[map] = events = data.ReadMap(map) is { } read
                    ? [.. read.Events.Values.Where(mapEvent => mapEvent.Pages.Any(page => page.Trigger == EventSorter.AutorunTrigger))]
                    : [];
            }

            return events;
        }
    }

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
        /// <returns>The page, <see langword="null"/> for none.</returns>
        public EventPage? ShownPage(int map, MapEvent mapEvent)
        {
            for (int at = mapEvent.Pages.Count - 1; at >= 0; at--)
            {
                PageCondition condition = mapEvent.Pages[at].Condition;
                if (SwitchOn(condition.Switch1) && SwitchOn(condition.Switch2) && Reaches(condition.Variable, condition.VariableValue)
                    && (condition.SelfSwitch is not { } letter || _selfSwitchesOn.Contains((map, mapEvent.Id, letter)) || state.SelfSwitch(map, mapEvent.Id, letter)))
                {
                    return mapEvent.Pages[at];
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
