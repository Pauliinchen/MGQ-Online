//----------------------------------------------------------------
//  CastOutcome.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Debris;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Hits;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Casting;

/// <summary>
/// What one pulse of a cast did.
/// </summary>
/// <param name="Pulse">The pulse, 0 the first.</param>
/// <param name="Anchor">The telegraphed anchor, null when nothing was aimed at.</param>
/// <param name="Layout">Where it landed and whom it hit; nothing without an anchor.</param>
/// <param name="DebrisBefore">The debris the pulse met.</param>
/// <param name="DebrisAfter">The debris after the pulse's hits wore it down, before the cast's own debris lands.</param>
public sealed record PulseOutcome(int Pulse, GridCell? Anchor, HitLayout Layout, DebrisField DebrisBefore, DebrisField DebrisAfter)
{
    /// <summary>
    /// Gets whether the pulse aimed at a cell but hit nobody, such as a single hit on a cell its unit left.
    /// </summary>
    public bool Fizzled => Anchor is not null && Layout.Hits.Count == 0;
}

/// <summary>
/// What a cast did over its telegraphed cells.
/// </summary>
/// <param name="Telegraph">The cast's telegraph.</param>
/// <param name="Pulses">Every pulse's outcome, in order.</param>
/// <param name="Debris">The debris the cast left after its last pulse.</param>
/// <param name="DebrisAfter">The debris after the cast, its own included.</param>
/// <param name="UnitsAfter">The party after the cast, the units its debris pushed on their new cells.</param>
/// <param name="Warnings">What the cast warns about, the telegraph's warnings first.</param>
public sealed record CastOutcome(CastTelegraph Telegraph, IReadOnlyList<PulseOutcome> Pulses, DebrisPlacement Debris, DebrisField DebrisAfter, IReadOnlyList<GridUnit> UnitsAfter, IReadOnlyList<CastWarning> Warnings)
{
    /// <summary>
    /// Gets the seats the cast hit in any pulse, each once, in the order first hit.
    /// </summary>
    public IReadOnlyList<int> HitSeats => Pulses.SelectMany(pulse => pulse.Layout.Hits).Select(hit => hit.Unit.Seat).Distinct().ToList();

    /// <summary>
    /// Gets whether the cast hit nobody at all.
    /// </summary>
    public bool Fizzled => HitSeats.Count == 0;
}
