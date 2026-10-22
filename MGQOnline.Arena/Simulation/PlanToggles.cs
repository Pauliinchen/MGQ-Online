//----------------------------------------------------------------
//  PlanToggles.cs
//
//  Changelog:
//      Paulinchen  2026-10-22: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Arena.Simulation;

/// <summary>
/// What a planned turn starts with besides the battle, for a turn plan that shows what such a turn
/// does before the battle gets there.
/// </summary>
/// <param name="Overdrive">Whether the party's Overdrive runs for the whole turn, as if it started the turn before.</param>
/// <param name="LastStandStarts">Whether the boss's first Last stand starts at this turn's start, its start skill a forced entry of every living enemy.</param>
public sealed record PlanToggles(bool Overdrive = false, bool LastStandStarts = false)
{
    /// <summary>
    /// Gets the toggles of a turn that starts with nothing besides the battle.
    /// </summary>
    public static PlanToggles None { get; } = new();
}
