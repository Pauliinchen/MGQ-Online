//----------------------------------------------------------------
//  EventDecision.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

namespace MGQOnline.Game.Events;

/// <summary>
/// Where a list of event commands runs, and what of it only the game knows, which the decision
/// reads besides the commands.
/// </summary>
/// <param name="Map">The map the list runs on, 0 outside one.</param>
/// <param name="Common">The common event the list is, <see langword="null"/> for a map event's page or another list.</param>
/// <param name="Trigger">The trigger of the page the list is, <see langword="null"/> for a list that is no page.</param>
/// <param name="Texts">What the list's texts tell.</param>
/// <param name="Resumed">Whether the list is the page of a frozen raid boss fight that resumes, which is story whatever page its event shows now.</param>
public sealed record EventSite(long Map, long? Common, int? Trigger, PageTexts Texts, bool Resumed = false)
{
    /// <summary>
    /// A list that runs nowhere the decision knows of and tells nothing by its texts.
    /// </summary>
    public static EventSite Nowhere { get; } = new(0, null, null, PageTexts.None);
}

/// <summary>
/// The one decision every script asks of a list before it runs, see <see cref="EventSorter.Decide"/>.
/// </summary>
/// <param name="Kind">The page's kind, the list's for a list that is no page.</param>
/// <param name="ListKind">The list's kind, whatever page it is.</param>
/// <param name="MayTell">Whether a talk turns into story behind one of its choices, which the scripts watch; never for the player's own list or a Pocket Castle resident's.</param>
/// <param name="Scene">Whether the list is a story scene, for which a teller gathers the party.</param>
/// <param name="Marks">What the commands that can run now do.</param>
/// <param name="Own">Why the list runs in the player's own game alone, with nobody taken along; <see langword="null"/> when it does not.</param>
public sealed record EventDecision(EventKind Kind, EventKind ListKind, bool MayTell, bool Scene, EventMarks Marks, string? Own);
