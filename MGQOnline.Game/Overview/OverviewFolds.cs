//----------------------------------------------------------------
//  OverviewFolds.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.Overview;

/// <summary>
/// Which groups of the pages' lists the player opened or folded, kept for the session.
/// </summary>
public sealed class OverviewFolds
{
    /// <summary>
    /// Whether each group the player opened or folded is open, by its page and its key.
    /// </summary>
    private readonly Dictionary<(string Page, string Key), bool> chosen = [];

    /// <summary>
    /// Tells whether a group of a page is open: as the player left it, else as it starts.
    /// </summary>
    /// <param name="page">The page.</param>
    /// <param name="key">The group's key.</param>
    /// <param name="open">Whether it starts open.</param>
    /// <returns>Whether it is open.</returns>
    public bool IsOpen(string page, string key, bool open) => chosen.TryGetValue((page, key), out bool kept) ? kept : open;

    /// <summary>
    /// Keeps whether the player opened or folded a group.
    /// </summary>
    /// <param name="page">The page.</param>
    /// <param name="key">The group's key.</param>
    /// <param name="open">Whether it is open now.</param>
    public void Choose(string page, string key, bool open) => chosen[(page, key)] = open;
}
