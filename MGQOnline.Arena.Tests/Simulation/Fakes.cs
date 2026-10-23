//----------------------------------------------------------------
//  Fakes.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Placed no battlefield debris in the casting fake
//      Paulinchen  2026-10-21: Took the concrete casting seam and dropped the fake rule engine for the real one
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Arena.Casting;
using MGQOnline.Arena.Debris;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;
using MGQOnline.Arena.Simulation;
using MGQOnline.Arena.Targeting;

namespace MGQOnline.Arena.Tests.Simulation;

/// <summary>
/// A casting part for tests: a half skill telegraphs its whole half, an aimed skill its target's
/// cell, any other a random cell; a cast hits every living unit on its cells for 100 per pulse.
/// </summary>
internal sealed class FakeCasts : ICastResolver
{
    /// <summary>
    /// The damage of one pulse.
    /// </summary>
    public const int PulseDamage = 100;

    /// <summary>
    /// Gets the telegraph requests in the order they came.
    /// </summary>
    public List<TelegraphRequest> Requests { get; } = [];

    /// <inheritdoc />
    public CastTelegraph Telegraph(BattleState state, TelegraphRequest request)
    {
        Requests.Add(request);
        List<PulseTelegraph> pulses = [];
        for (int pulse = 0; pulse < Math.Max(1, request.Skill.Pulses); pulse++)
        {
            List<GridCell> cells = CellsOf(state, request);
            pulses.Add(new PulseTelegraph(pulse, new TargetChoice(cells[0], AnchorOrigin.Picked, [], [], false, false), cells));
        }

        return new CastTelegraph(request.Side, [], pulses, []);
    }

    /// <inheritdoc />
    public CastResult Resolve(BattleState state, PlannedCast request)
    {
        List<CastHit> hits = [];
        foreach (UnitState unit in state.Units.Where(unit => !unit.Fallen))
        {
            int pulses = request.TelegraphPerPulse.Count(cells => cells.Contains(unit.Cell));
            if (pulses > 0)
            {
                hits.Add(new CastHit(unit.Seat, PulseDamage * pulses, []));
            }
        }

        return new CastResult(hits, state.Debris, []);
    }

    /// <inheritdoc />
    public IReadOnlyList<DebrisCell> PlaceBattlefieldDebris(BattleState state, BattlefieldDebris debris) => [];

    /// <inheritdoc />
    public DebrisPlacement PlaceDebris(BattleState state, SkillDebrisSpec debris, PlannedCast? cast) => DebrisPlacement.None;

    /// <summary>
    /// Finds the cells of one pulse.
    /// </summary>
    /// <param name="state">The battle.</param>
    /// <param name="request">The cast.</param>
    /// <returns>The cells.</returns>
    private static List<GridCell> CellsOf(BattleState state, TelegraphRequest request)
    {
        if (request.Side is GridHalf half)
        {
            int width = state.Grid.Cols / 2;
            int first = half == GridHalf.Left ? 0 : state.Grid.Cols - width;
            return [.. Enumerable.Range(0, state.Grid.Rows).SelectMany(y => Enumerable.Range(first, width).Select(x => new GridCell(x, y)))];
        }

        if (request.AimSeat is int seat)
        {
            return [state.Units[seat].Cell];
        }

        ArenaRandom random = state.Random.Get(RandomStream.Targeting);
        return [new GridCell(random.NextInt(state.Grid.Cols), random.NextInt(state.Grid.Rows))];
    }
}
