//----------------------------------------------------------------
//  WorldProgress.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Game.Story;

/// <summary>
/// The values that tell how far a Raid World's story is, which decide whom a telling takes along
/// when it moves its teller: those who watch it follow at once only when it moves the world's
/// story on, the others get an offer.
/// </summary>
/// <remarks>
/// A scene that runs by itself and moves its teller without moving the story on started again for
/// every player left behind, one after another (issue #61).
/// </remarks>
/// <param name="table">The story mapping, whose one-way variables move the story on too; <see langword="null"/> before it came.</param>
public sealed class WorldProgress(StoryTable? table)
{
    /// <summary>
    /// The switches that move the story on: the bosses of the Monster Lord's Castle and the route clears.
    /// </summary>
    private static readonly long[] FixedSwitches = [.. StoryIds.CastleBosses.Concat(StoryIds.ClearSwitches).Select(id => (long)id)];

    /// <summary>
    /// The variables that move the story on: the story markers, the Great Decision's progress, the
    /// areas' progress the parts are ordered by, and those the mapping keeps going only up, as a
    /// boss beaten or a quest's step.
    /// </summary>
    public IReadOnlyList<long> Variables { get; } =
        [.. StoryIds.Markers.Append(StoryIds.DecisionProgress).Concat(StoryIds.AreaProgress).Select(id => (long)id).Concat(OneWay(table)).Distinct()];

    /// <summary>
    /// Reads the values that move the story on, in an order that stays the same while the mapping does.
    /// </summary>
    /// <param name="state">The live values.</param>
    /// <returns>Each variable's number, then 1 or 0 for each switch.</returns>
    public long[] Now(IEventState state) =>
        [.. Variables.Select(id => state.Variable(id) ?? 0), .. FixedSwitches.Select(id => state.Switch(id) ? 1L : 0L)];

    /// <summary>
    /// Reports whether commands of a list from a place on may move the story on: they set a value
    /// of <see cref="Now"/>, themselves or in a common event they call, behind a branch taken or not.
    /// </summary>
    /// <param name="source">The game's events, whose common events the commands call.</param>
    /// <param name="list">The commands.</param>
    /// <param name="from">The place to read from.</param>
    /// <returns>Whether they may.</returns>
    public bool Ahead(IEventSource source, IReadOnlyList<EventCommand> list, int from)
    {
        IReadOnlyList<EventCommand> rest = from <= 0 ? list : [.. list.Skip(from)];
        (IReadOnlyList<KeyRange> writes, _) = new EventCommandIndex(source).WritesOf(rest);
        return writes.Any(write => (write.Variable ? Variables : FixedSwitches).Any(id => write.From <= id && id <= write.To));
    }

    /// <summary>
    /// Lists the variables the mapping keeps going only up.
    /// </summary>
    /// <param name="table">The mapping, <see langword="null"/> for none.</param>
    /// <returns>Their ids.</returns>
    private static IEnumerable<long> OneWay(StoryTable? table) =>
        table is null ? [] : Enumerable.Range(0, table.Variables.Length).Where(id => ((StoryClass)table.Variables[id]).HasFlag(StoryClass.OneWay)).Select(id => (long)id);
}
