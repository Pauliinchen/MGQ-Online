//----------------------------------------------------------------
//  SideChooser.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using MGQOnline.Arena.Grids;
using MGQOnline.Arena.Model;
using MGQOnline.Arena.Randomness;

namespace MGQOnline.Arena.Targeting;

/// <summary>
/// What a cast's choice of grid half reads.
/// </summary>
/// <param name="Zone">The skill's targeting zone, null for the whole grid.</param>
/// <param name="Side">How a rule casting the skill chooses its half; <see cref="CastSide.Own"/> for the skill's own choice.</param>
/// <param name="ParentSide">The half of the triggering or parent cast, null for none.</param>
/// <param name="LastSide">The half of the last cast that shares this cast's alternation memory, null before the first.</param>
public sealed record SideRequest(ZoneSpec? Zone, CastSide Side = CastSide.Own, GridHalf? ParentSide = null, GridHalf? LastSide = null);

/// <summary>
/// Chooses the grid half of a cast: fixed, random, alternating, or relative to its parent.
/// </summary>
/// <remarks>The caller keeps the alternation memory and stores the half chosen as the next last side.</remarks>
public static class SideChooser
{
    /// <summary>
    /// Chooses a cast's half.
    /// </summary>
    /// <param name="request">What the choice reads.</param>
    /// <param name="random">The side stream; drawn from only for a random half.</param>
    /// <returns>The half, or null when the cast is not narrowed to a half.</returns>
    public static GridHalf? Choose(SideRequest request, ArenaRandom random)
    {
        ArgumentNullException.ThrowIfNull(request);
        ArgumentNullException.ThrowIfNull(random);
        return request.Side switch
        {
            CastSide.Same => request.ParentSide ?? Own(request, random),
            CastSide.Opposite => request.ParentSide is GridHalf parent ? Halves.Other(parent) : Own(request, random),
            CastSide.FixedLeft => GridHalf.Left,
            CastSide.FixedRight => GridHalf.Right,
            CastSide.Random => Rolled(random),
            CastSide.Alternate => request.LastSide is GridHalf last ? Halves.Other(last) : request.Zone?.Half ?? GridHalf.Left,
            _ => Own(request, random),
        };
    }

    /// <summary>
    /// Chooses the half by the skill's own zone.
    /// </summary>
    /// <param name="request">What the choice reads.</param>
    /// <param name="random">The side stream.</param>
    /// <returns>The half, or null for a zone without one.</returns>
    private static GridHalf? Own(SideRequest request, ArenaRandom random)
    {
        if (request.Zone?.Half is not GridHalf half)
        {
            return null;
        }

        return request.Zone.Side switch
        {
            SideChoice.Random => Rolled(random),
            SideChoice.Alternate => request.LastSide is GridHalf last ? Halves.Other(last) : half,
            _ => half,
        };
    }

    /// <summary>
    /// Rolls a half.
    /// </summary>
    /// <param name="random">The side stream.</param>
    /// <returns>Left on 0, right on 1.</returns>
    private static GridHalf Rolled(ArenaRandom random) => random.NextInt(2) == 0 ? GridHalf.Left : GridHalf.Right;
}
