//----------------------------------------------------------------
//  EventPage.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.Events.Data;

/// <summary>
/// One page of a map event: when it shows, how it starts and its commands.
/// </summary>
/// <param name="Condition">When the page shows.</param>
/// <param name="Trigger">How it starts: 0 action button, 1 player touch, 2 event touch, 3 autorun, 4 parallel.</param>
/// <param name="List">Its commands.</param>
public sealed record EventPage(PageCondition Condition, int Trigger, IReadOnlyList<EventCommand> List);

/// <summary>
/// The conditions of a map event's page, the ids only of those it checks.
/// </summary>
/// <param name="Switch1">The first switch that must be on, <see langword="null"/> for none.</param>
/// <param name="Switch2">The second switch that must be on, <see langword="null"/> for none.</param>
/// <param name="Variable">The variable that must be at least <paramref name="VariableValue"/>, <see langword="null"/> for none.</param>
/// <param name="VariableValue">The least value of <paramref name="Variable"/>.</param>
/// <param name="SelfSwitch">The event's own self switch that must be on, such as "A", <see langword="null"/> for none.</param>
public sealed record PageCondition(int? Switch1, int? Switch2, int? Variable, long VariableValue, string? SelfSwitch)
{
    /// <summary>
    /// The conditions of a page that checks nothing.
    /// </summary>
    public static readonly PageCondition None = new(null, null, null, 0, null);
}
