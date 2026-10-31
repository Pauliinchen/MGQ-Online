//----------------------------------------------------------------
//  OverviewModel.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.Overview;

/// <summary>
/// A page's head: its title with a note at the right, the lines under it, and the entry picking
/// the head shows, if any. The scripts add how a character looks or an icon, and a grid.
/// </summary>
/// <param name="Title">The title, <see langword="null"/> where the scripts write it.</param>
/// <param name="Note">The note, <see langword="null"/> for none or where the scripts write it.</param>
/// <param name="Lines">The lines.</param>
/// <param name="Entry">The entry picking the head shows, <see langword="null"/> for none.</param>
public sealed record OverviewHead(string? Title, string? Note, IReadOnlyList<string> Lines, OverviewEntry? Entry);

/// <summary>
/// A row of a page's list: a text alone, a group's row or an entry.
/// </summary>
/// <param name="None">The text alone, <see langword="null"/> for a group's row or an entry.</param>
/// <param name="Entry">The group's row or the entry, <see langword="null"/> for a text alone.</param>
public sealed record OverviewItem(string? None, OverviewEntry? Entry);

/// <summary>
/// A page laid out with a head, a list and a reading pane.
/// </summary>
/// <param name="Head">Its head.</param>
/// <param name="Rows">Its list's rows.</param>
/// <param name="Picks">What can be picked, the head's entry first.</param>
public sealed record OverviewModel(OverviewHead Head, IReadOnlyList<OverviewItem> Rows, IReadOnlyList<OverviewEntry> Picks);
