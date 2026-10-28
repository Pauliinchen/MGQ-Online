//----------------------------------------------------------------
//  CatchupIndex.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Catchup;

/// <summary>
/// What the catch-up's engine works out of its tables once, as world_catchup.rbx kept it until the
/// rules came anew: which joins last, which removals take each join back, the visits by companion
/// and the lasting joins by companion.
/// </summary>
internal sealed class CatchupIndex
{
    /// <summary>
    /// The removals that take each join back, by the join.
    /// </summary>
    private readonly Dictionary<CatchupJoin, IReadOnlyList<CatchupRemoval>> _takingBack = new(ReferenceEqualityComparer.Instance);

    /// <summary>
    /// The joins that only bring their companion along for a visit, by the companion.
    /// </summary>
    private readonly Dictionary<int, List<CatchupJoin>> _visits = [];

    /// <summary>
    /// The lasting joins placed in the story, by the companion, in the story's order.
    /// </summary>
    private readonly Dictionary<int, List<CatchupJoin>> _joinsByActor = [];

    /// <summary>
    /// Initializes the index of tables.
    /// </summary>
    /// <param name="tables">The tables.</param>
    public CatchupIndex(CatchupTables tables)
    {
        foreach (CatchupJoin join in tables.Joins)
        {
            _takingBack[join] = StoryRows.TakingBack(tables, join);
        }

        StoryJoins = [.. tables.Joins.Where(join => _takingBack[join].Count == 0)];
        foreach (CatchupJoin join in tables.Joins.Where(join => join.Place.Part is not null && _takingBack[join].Count > 0))
        {
            (_visits.TryGetValue(join.Actor, out List<CatchupJoin>? visits) ? visits : _visits[join.Actor] = []).Add(join);
        }

        foreach (CatchupJoin join in StoryJoins.Where(join => join.Place.Part is not null))
        {
            (_joinsByActor.TryGetValue(join.Actor, out List<CatchupJoin>? joins) ? joins : _joinsByActor[join.Actor] = []).Add(join);
        }
    }

    /// <summary>
    /// Gets the story's joins that last, in the story's order.
    /// </summary>
    public IReadOnlyList<CatchupJoin> StoryJoins { get; }

    /// <summary>
    /// Lists the removals that take a join's companion away again.
    /// </summary>
    /// <param name="join">The join, one of the tables'.</param>
    /// <returns>The removals; none for a join that lasts.</returns>
    public IReadOnlyList<CatchupRemoval> TakingBack(CatchupJoin join) => _takingBack[join];

    /// <summary>
    /// Lists the joins that bring a companion along for a visit only.
    /// </summary>
    /// <param name="actor">The companion's main persona.</param>
    /// <returns>The joins.</returns>
    public IReadOnlyList<CatchupJoin> VisitsOf(int actor) => _visits.TryGetValue(actor, out List<CatchupJoin>? visits) ? visits : [];

    /// <summary>
    /// Lists the lasting joins of a companion placed in the story.
    /// </summary>
    /// <param name="actor">The companion's main persona.</param>
    /// <returns>The joins, in the story's order.</returns>
    public IReadOnlyList<CatchupJoin> JoinsOf(int actor) => _joinsByActor.TryGetValue(actor, out List<CatchupJoin>? joins) ? joins : [];
}
