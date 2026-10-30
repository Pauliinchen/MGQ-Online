//----------------------------------------------------------------
//  LiveEnd.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Battles.Live;

/// <summary>
/// How a live battle ends, see <see cref="LiveVerdicts"/>.
/// </summary>
/// <param name="Process">The game's ending, such as "process_victory", or a step of the scripts'
/// own: "win", "forfeit", "gone", "solo" or "take_over".</param>
/// <param name="Log">The line logged, <see langword="null"/> for none.</param>
/// <param name="Message">What the battle's message says, <see langword="null"/> for nothing.</param>
/// <param name="Otherwise">The ending when the battle's mode takes the battle over not.</param>
public sealed record LiveEnd(string Process, string? Log = null, string? Message = null, LiveEnd? Otherwise = null);
