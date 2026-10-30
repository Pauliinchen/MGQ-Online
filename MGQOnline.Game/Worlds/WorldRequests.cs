//----------------------------------------------------------------
//  WorldRequests.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Dropped the refusal of a world that keeps differing games out without this game's data
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using MGQOnline.Game.Forms;

namespace MGQOnline.Game.Worlds;

/// <summary>
/// The changes an edit of a world sends along: each one only when the form changed it, since the
/// relay tells every player in the world of each.
/// </summary>
/// <param name="Difficulty">A Raid World's new difficulty, <see langword="null"/> to leave it.</param>
/// <param name="Squad">A Raid World's new squad rules, <see langword="null"/> to leave them.</param>
/// <param name="RaidBosses">Whether a Classic world's story bosses now fight as raid bosses, <see langword="null"/> to leave it.</param>
/// <param name="OtherModsOff">Whether the world now turns other mods off, <see langword="null"/> to leave it.</param>
public sealed record WorldEdit(int? Difficulty, WorldSquad? Squad, bool? RaidBosses, bool? OtherModsOff);

/// <summary>
/// The world screen's requests to the directory: what an edit sends along and what the player is
/// told of each request.
/// </summary>
public static class WorldRequests
{
    /// <summary>
    /// What a request that could not start says.
    /// </summary>
    public const string NotStartedText = "The request could not be started. Try again in a moment.";

    /// <summary>
    /// What a world folder that could not be made says.
    /// </summary>
    public const string NoFolderText = "The world could not be set up on this PC.";

    /// <summary>
    /// Finds what an edit sends along.
    /// </summary>
    /// <param name="raid">Whether the world is a Raid World.</param>
    /// <param name="listed">The world as the list has it.</param>
    /// <param name="defaultSquad">The squad rules a Raid World that names none plays with.</param>
    /// <param name="form">The form's values.</param>
    /// <returns>The changes.</returns>
    public static WorldEdit EditOf(bool raid, WorldEdit listed, WorldSquad defaultSquad, WorldFormValues form)
    {
        ArgumentNullException.ThrowIfNull(listed);
        ArgumentNullException.ThrowIfNull(form);
        int? difficulty = raid && form.Difficulty is { } chosen && chosen != listed.Difficulty ? chosen : null;
        WorldSquad? squad = raid && form.Squad != (listed.Squad ?? defaultSquad) ? form.Squad : null;
        bool? raidBosses = raid || form.RaidBosses == listed.RaidBosses ? null : form.RaidBosses;
        bool? otherModsOff = form.OtherModsOff == listed.OtherModsOff ? null : form.OtherModsOff;
        return new WorldEdit(difficulty, squad, raidBosses, otherModsOff);
    }

    /// <summary>
    /// Tells whether an edit turns the sharing of the world's mod settings on or off, which only its
    /// creator may.
    /// </summary>
    /// <param name="own">Whether the player made the world.</param>
    /// <param name="shared">Whether the world's settings are shared now.</param>
    /// <param name="wanted">Whether the form shares them.</param>
    /// <returns>Whether they are shared after the edit, <see langword="null"/> when the edit leaves them.</returns>
    public static bool? SharingOf(bool own, bool shared, bool wanted) => own && shared != wanted ? wanted : null;

    /// <summary>
    /// Tells the creator or an admin what an edit changed for the world's players.
    /// </summary>
    /// <param name="edit">The changes sent along.</param>
    /// <param name="difficultyName">Names a difficulty.</param>
    /// <param name="formationName">Names a Formation size.</param>
    /// <returns>The sentences after the one that the world was changed, each with a space in front; empty when none changed.</returns>
    public static string ChangedText(WorldEdit edit, Func<int, string?> difficultyName, Func<int, string> formationName)
    {
        ArgumentNullException.ThrowIfNull(edit);
        ArgumentNullException.ThrowIfNull(difficultyName);
        string text = edit.Difficulty is { } difficulty ? $" Its players play on {difficultyName(difficulty)} now." : "";
        if (edit.Squad is { } squad)
        {
            text += $" Its squads: {SquadSummary(squad, formationName)}.";
        }

        if (edit.RaidBosses is { } raidBosses)
        {
            text += raidBosses ? " Its story bosses fight as raid bosses now." : " Its story bosses fight as usual now.";
        }

        return edit.OtherModsOff switch
        {
            true => text + " Players in it with other mods enter again without them.",
            false => text + " Its players keep their mods from their next entry.",
            null => text,
        };
    }

    /// <summary>
    /// Tells squad rules in a few words.
    /// </summary>
    /// <param name="squad">The rules.</param>
    /// <param name="formationName">Names a Formation size.</param>
    /// <returns>The text, such as "Formation 4, Frontline 1 | 1, Luka fixed", the Frontline in regular fights before the one in raids.</returns>
    public static string SquadSummary(WorldSquad squad, Func<int, string> formationName)
    {
        ArgumentNullException.ThrowIfNull(squad);
        ArgumentNullException.ThrowIfNull(formationName);
        return $"Formation {formationName(squad.Formation)}, Frontline {squad.Front} | {squad.RaidFront}, Luka {(squad.Luka ? "replaceable" : "fixed")}";
    }

    /// <summary>
    /// Tells the creator when their world's players get what it now does with its mod settings.
    /// </summary>
    /// <param name="shared">Whether the settings are shared now.</param>
    /// <returns>The sentence.</returns>
    public static string SharedText(bool shared) =>
        shared ? "Its players get your mod options once you play in it." : "Its players set their own mod options from their next visit.";

    /// <summary>
    /// Tells the creator that their world's other changes were saved but its mod settings were not.
    /// </summary>
    /// <param name="name">The world's name.</param>
    /// <returns>The message.</returns>
    public static string SettingsFailedText(string name) => $"{name} was changed, but its mod settings could not be saved. Try again later.";
}
