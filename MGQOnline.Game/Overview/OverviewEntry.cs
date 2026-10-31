//----------------------------------------------------------------
//  OverviewEntry.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Globalization;

namespace MGQOnline.Game.Overview;

/// <summary>
/// What a list row of a page shows: a label at the left, its text, a note at the right, whether it
/// is dimmed, and the share of a gauge, if any.
/// </summary>
/// <param name="Label">The label, <see langword="null"/> for none.</param>
/// <param name="Text">The text.</param>
/// <param name="Note">The note, <see langword="null"/> for none.</param>
/// <param name="Dim">Whether it is dimmed.</param>
/// <param name="Gauge">The gauge's share, 0 to 1; <see langword="null"/> for none.</param>
public sealed record OverviewRowView(string? Label, string Text, string? Note, bool Dim, double? Gauge);

/// <summary>
/// A line of the reading pane: a paragraph, or a gauge with its text.
/// </summary>
/// <param name="Kind">"text" or "gauge".</param>
/// <param name="Text">The paragraph or the gauge's text.</param>
/// <param name="Share">The gauge's share, 0 to 1; 0 for a paragraph.</param>
public sealed record OverviewPaneLine(string Kind, string Text, double Share);

/// <summary>
/// What a page's list can pick: a group's row or an entry.
/// </summary>
public abstract record OverviewEntry
{
    /// <summary>
    /// Tells what the entry's list row shows.
    /// </summary>
    /// <returns>The row.</returns>
    public abstract OverviewRowView Row();
}

/// <summary>
/// A group's row, which folds its entries away until it is opened again.
/// </summary>
/// <param name="Key">The group's key, which keeps whether it is open.</param>
/// <param name="Title">Its title.</param>
/// <param name="Open">Whether it is open.</param>
public sealed record OverviewFold(string Key, string Title, bool Open) : OverviewEntry
{
    /// <summary>
    /// The mark of a folded group.
    /// </summary>
    public const string Folded = "▸ ";

    /// <summary>
    /// The mark of an opened group.
    /// </summary>
    public const string Unfolded = "▾ ";

    /// <inheritdoc />
    public override OverviewRowView Row() => new(null, (Open ? Unfolded : Folded) + Title, null, false, null);
}

/// <summary>
/// A text of the World page: its title and its messages.
/// </summary>
/// <param name="Title">Its title.</param>
/// <param name="Texts">Its messages.</param>
public sealed record OverviewNote(string Title, IReadOnlyList<string> Texts) : OverviewEntry
{
    /// <inheritdoc />
    public override OverviewRowView Row() => new(Title, OverviewPages.FirstSentence(Texts[0]), null, false, null);
}

/// <summary>
/// A quest: its kind, who tells it, its messages and a side quest's number.
/// </summary>
/// <param name="Kind">"main", "side" or "companion".</param>
/// <param name="Speaker">Who tells it, <see langword="null"/> for nobody named.</param>
/// <param name="Texts">Its messages.</param>
/// <param name="Number">A side quest's number, <see langword="null"/> for the others.</param>
public sealed record OverviewQuest(string Kind, string? Speaker, IReadOnlyList<string> Texts, int? Number) : OverviewEntry
{
    /// <summary>
    /// Gets the first sentence of its first message.
    /// </summary>
    public string First => OverviewPages.FirstSentence(Texts[0]);

    /// <summary>
    /// Gets its title in the reading pane, such as "Side quest 2 · Amira".
    /// </summary>
    public string Title
    {
        get
        {
            string name = string.Format(CultureInfo.InvariantCulture, OverviewPages.QuestTitles[Kind], Number ?? 0);
            return Speaker is null ? name : name + OverviewPages.TitleJoin + Speaker;
        }
    }

    /// <inheritdoc />
    public override OverviewRowView Row() =>
        new(Kind == OverviewPages.SideKind ? Number?.ToString(CultureInfo.InvariantCulture) + "." : Speaker ?? string.Empty, First, null, false, null);
}

/// <summary>
/// A raid boss summed up from its pools.
/// </summary>
/// <param name="Name">Its milestone's name, such as "Tamamo (cap 61)", or its pools' boss.</param>
/// <param name="Tier">Its tier, <see langword="null"/> for a boss the tables lack.</param>
/// <param name="Left">The share of its HP left over its pools, 0 to 1; all of it while the relay told none.</param>
/// <param name="Defeated">Whether every pool of it is empty for good.</param>
/// <param name="By">Who defeated the pool told last that names anyone, <see langword="null"/> for none.</param>
public sealed record OverviewBoss(string Name, int? Tier, double Left, bool Defeated, string? By);

/// <summary>
/// A raid boss of the World page with its section and its reading pane.
/// </summary>
/// <param name="Boss">The boss.</param>
/// <param name="Section">Its section.</param>
/// <param name="Pane">The reading pane's lines, see <see cref="OverviewBosses.Pane"/>.</param>
public sealed record OverviewBossEntry(OverviewBoss Boss, string Section, IReadOnlyList<OverviewPaneLine> Pane) : OverviewEntry
{
    /// <inheritdoc />
    public override OverviewRowView Row() =>
        new(null, Boss.Name, Boss.Defeated ? OverviewBosses.DefeatedText : OverviewBosses.ShareText(Boss.Left), Boss.Defeated, Boss.Defeated ? null : Boss.Left);
}

/// <summary>
/// A level of the Unlocks page: what it brings, whether the player got all of it and whether any of it is due.
/// </summary>
/// <param name="Level">The level.</param>
/// <param name="Unlocks">What it brings, as places in the list the scripts handed.</param>
/// <param name="Names">What it brings, by name.</param>
/// <param name="Got">Whether the player got all of it.</param>
/// <param name="Due">Whether any of it is due.</param>
public sealed record OverviewLevel(int Level, IReadOnlyList<int> Unlocks, IReadOnlyList<string> Names, bool Got, bool Due) : OverviewEntry
{
    /// <inheritdoc />
    public override OverviewRowView Row() =>
        new(string.Format(CultureInfo.InvariantCulture, OverviewPages.LevelHeading, Level), string.Join(", ", Names), Due ? OverviewPages.DueText : null, Got, null);
}
