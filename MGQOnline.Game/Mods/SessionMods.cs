//----------------------------------------------------------------
//  SessionMods.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;

namespace MGQOnline.Game.Mods;

/// <summary>
/// The mods a game session in a world that turns other mods off loads, see <see cref="SessionMods.Of"/>.
/// </summary>
/// <param name="Only">The names of the mods the session loads, in the order given.</param>
/// <param name="Off">The names of the mods it leaves out, in the order given.</param>
public sealed record SessionPlan(IReadOnlyList<string> Only, IReadOnlyList<string> Off);

/// <summary>
/// Which of the player's mods a world that turns other mods off lets load: those it names, those the
/// relay's catalog marks personal and those every player has. The Mod Framework loads only these as
/// the player enters such a world, besides the mods that run from the start of the game.
/// </summary>
public static class SessionMods
{
    /// <summary>
    /// The keys of the mods every player has, which no world turns off: the mod loader, this mod, the
    /// Mod Framework's loader and its old entry file, and Mod Config Remake, which older releases shipped.
    /// </summary>
    public static readonly IReadOnlySet<string> SharedKeys = new HashSet<string>(StringComparer.Ordinal) { "patch", "multiplayer", "!modframework", "modframework", "0modconfigremake" };

    /// <summary>
    /// Most mods a text names before it counts the rest.
    /// </summary>
    public const int NamedMods = 3;

    /// <summary>
    /// What the world screen says while the catalog, which tells the personal mods, is unknown.
    /// </summary>
    public const string Catalog = "The mod list has not loaded yet. Try again in a moment.";

    /// <summary>
    /// The folder the mods' scripts sit in.
    /// </summary>
    private const string PatchFolder = "patch";

    /// <summary>
    /// The extension of a script, which a mod's name leaves out.
    /// </summary>
    private const string ScriptExtension = ".rb";

    /// <summary>
    /// Splits the player's mods into those a world's session loads and those it leaves out.
    /// </summary>
    /// <param name="names">The player's mods, by the names the Mod Framework gives them.</param>
    /// <param name="mods">The world's mods as its creator wrote them.</param>
    /// <param name="personal">The keys of the catalog's personal mods; <see langword="null"/> while the catalog is unknown.</param>
    /// <returns>The plan, each mod once; <see langword="null"/> while the catalog is unknown and a mod the world does not name might be personal.</returns>
    public static SessionPlan? Of(IReadOnlyList<string> names, string? mods, IReadOnlyCollection<string>? personal)
    {
        HashSet<string> named = ModsText.Names(mods).Select(ModKey.Of).ToHashSet(StringComparer.Ordinal);
        List<string> only = [];
        List<string> off = [];
        foreach (string name in names.DistinctBy(ModKey.Of, StringComparer.Ordinal))
        {
            string key = ModKey.Of(name);
            if (named.Contains(key) || SharedKeys.Contains(key))
            {
                only.Add(name);
            }
            else if (personal == null)
            {
                return null;
            }
            else if (personal.Contains(key))
            {
                only.Add(name);
            }
            else
            {
                off.Add(name);
            }
        }

        return new SessionPlan(only, off);
    }

    /// <summary>
    /// Lists the mods a world turns off, by the scripts of the Patch folder, for the world's details.
    /// </summary>
    /// <param name="scripts">The scripts' paths relative to the game folder; <see langword="null"/> when they could not be listed.</param>
    /// <param name="mods">The world's mods as its creator wrote them.</param>
    /// <param name="personal">The keys of the catalog's personal mods; <see langword="null"/> while the catalog is unknown.</param>
    /// <returns>Each mod turned off with how many of the scripts are its; <see langword="null"/> while unknown.</returns>
    public static IReadOnlyList<(string Name, int Scripts)>? TurnedOff(IReadOnlyList<string>? scripts, string? mods, IReadOnlyCollection<string>? personal)
    {
        if (scripts == null)
        {
            return null;
        }

        IReadOnlyList<(string Name, int Scripts)> owners = ModsOf(scripts);
        SessionPlan? plan = Of([.. owners.Select(owner => owner.Name)], mods, personal);
        return plan == null ? null : [.. owners.Where(owner => plan.Off.Contains(owner.Name))];
    }

    /// <summary>
    /// Lists the mods running in a world's session that the world turns off now that its creator or an
    /// admin changed its rule or its mods.
    /// </summary>
    /// <param name="otherModsOff">Whether the world turns other mods off now.</param>
    /// <param name="running">The mods the session loaded, by the names the Mod Framework gives them, but those that run from the start of the game.</param>
    /// <param name="mods">The world's mods now.</param>
    /// <param name="personal">The keys of the catalog's personal mods; <see langword="null"/> while the catalog is unknown.</param>
    /// <returns>The mods; none while the catalog is unknown.</returns>
    public static IReadOnlyList<string> NowTurnedOff(bool otherModsOff, IReadOnlyList<string> running, string? mods, IReadOnlyCollection<string>? personal) =>
        otherModsOff ? Of(running, mods, personal)?.Off ?? [] : [];

    /// <summary>
    /// Tells a player entering a world what it leaves out, and which of those mods stay on, since they
    /// run from the start of the game.
    /// </summary>
    /// <param name="world">The world's name.</param>
    /// <param name="off">The mods the world leaves out.</param>
    /// <param name="staysOn">Those of them that run from the start of the game.</param>
    /// <returns>The text; empty when the world leaves nothing out.</returns>
    public static string Entered(string world, IReadOnlyList<string> off, IReadOnlyList<string> staysOn)
    {
        List<string> left = [.. off.Where(name => !staysOn.Contains(name, StringComparer.OrdinalIgnoreCase))];
        List<string> sentences = [];
        if (left.Count > 0)
        {
            sentences.Add($"{world} plays without your other mods: {SharedSettings.ListText(left, NamedMods)} {(left.Count == 1 ? "stays" : "stay")} off until you leave it.");
        }

        if (staysOn.Count > 0)
        {
            sentences.Add($"{SharedSettings.ListText(staysOn, NamedMods)} {(staysOn.Count == 1 ? "is" : "are")} part of the framework and {(staysOn.Count == 1 ? "stays" : "stay")} on.");
        }

        return string.Join(" ", sentences);
    }

    /// <summary>
    /// Tells a player in a world that now turns off mods their game runs.
    /// </summary>
    /// <param name="world">The world's name.</param>
    /// <returns>The text.</returns>
    public static string NowOff(string world) => $"{world} now turns off other mods. The game starts again and enters it without them.";

    /// <summary>
    /// Names the mod a script belongs to: the folder it sits in right under the Patch folder, or for a
    /// script right in it its own file's name.
    /// </summary>
    /// <param name="path">The script's path relative to the game folder, such as "Patch/Luka_Replacer/heroes.rb".</param>
    /// <returns>The mod's name as the folder or file has it, such as "Luka_Replacer".</returns>
    public static string OwnerName(string path)
    {
        List<string> parts = [.. path.Replace('\\', '/').Split('/').Where(part => part.Length > 0)];
        if (parts.Count > 1 && Worlds.WorldEntries.AsciiLower(parts[0]) == PatchFolder)
        {
            parts.RemoveAt(0);
        }

        if (parts.Count > 1)
        {
            return parts[0];
        }

        string last = parts.Count > 0 ? parts[^1] : string.Empty;
        return last.EndsWith(ScriptExtension, StringComparison.OrdinalIgnoreCase) ? last[..^ScriptExtension.Length] : last;
    }

    /// <summary>
    /// Groups scripts by the mod they belong to, see <see cref="OwnerName"/>.
    /// </summary>
    /// <param name="paths">The scripts.</param>
    /// <returns>Each mod's name, as its first script names it, and how many of the scripts are its, in the order of their first script.</returns>
    public static IReadOnlyList<(string Name, int Scripts)> ModsOf(IEnumerable<string> paths)
    {
        List<(string Key, string Name, int Scripts)> mods = [];
        foreach (string path in paths)
        {
            string key = ModKey.Of(OwnerName(path));
            int index = mods.FindIndex(mod => mod.Key == key);
            if (index < 0)
            {
                mods.Add((key, OwnerName(path), 1));
            }
            else
            {
                mods[index] = mods[index] with { Scripts = mods[index].Scripts + 1 };
            }
        }

        return [.. mods.Select(mod => (mod.Name, mod.Scripts))];
    }
}
