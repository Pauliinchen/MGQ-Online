//----------------------------------------------------------------
//  PresentationSpec.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Arena.Model;

/// <summary>
/// How a skill's wave looks: its timing, cell effects, telegraph colour and animation.
/// </summary>
/// <param name="RingDelay">The frames between two rings of the wave.</param>
/// <param name="PulseGap">The frames between two pulses.</param>
/// <param name="Danger">The telegraph colour, resolved through the element colours.</param>
/// <param name="Animation">Where and how the skill's battle animation plays, resolved.</param>
/// <param name="CellAnimation">The animation on the cells, or null for none.</param>
/// <param name="CellFlash">The flash of the cells, or null for none.</param>
public sealed record PresentationSpec(
    int RingDelay,
    int PulseGap,
    ColorRgba Danger,
    AnimationSpec Animation,
    CellAnimationSpec? CellAnimation = null,
    CellFlashSpec? CellFlash = null);

/// <summary>
/// An animation played on the cells a wave reaches.
/// </summary>
/// <param name="Animation">The game animation id.</param>
/// <param name="Where">Where it plays.</param>
public sealed record CellAnimationSpec(int Animation, CellAnimationPlace Where);

/// <summary>
/// A flash of the cells a wave reaches.
/// </summary>
/// <param name="Color">The colour.</param>
/// <param name="Frames">How long it lasts in frames.</param>
public sealed record CellFlashSpec(ColorRgba Color, int Frames);

/// <summary>
/// Where and how a skill's battle animation plays.
/// </summary>
/// <param name="Placement">Where it plays.</param>
/// <param name="Screen">How a screen animation is sized.</param>
/// <param name="Opacity">The animation's opacity in percent, 0 to 100.</param>
/// <param name="Flash">The strength of its flashes in percent, 0 to 100; 0 drops screen flashes.</param>
public sealed record AnimationSpec(AnimationPlacement Placement, AnimationScreen Screen, int Opacity, int Flash);
