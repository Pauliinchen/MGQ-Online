//----------------------------------------------------------------
//  ParkingRules.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace MGQOnline.Game.Mods;

/// <summary>
/// What entering a world needs of the parked scripts, see <see cref="ParkingRules.Change"/>.
/// </summary>
public enum ParkingKind
{
    /// <summary>
    /// The scripts parked are those the world turns off already.
    /// </summary>
    None,

    /// <summary>
    /// The scripts of <see cref="ParkingChange.Plan"/> must be parked, none putting every parked one back.
    /// </summary>
    Plan,

    /// <summary>
    /// This session moved scripts, which load only at the next start.
    /// </summary>
    Restart,

    /// <summary>
    /// The scripts could not be listed.
    /// </summary>
    Unlisted,

    /// <summary>
    /// Scripts the world turns off lie behind a link to another drive, which are never parked.
    /// </summary>
    Elsewhere,

    /// <summary>
    /// The catalog, which tells the personal mods, is unknown.
    /// </summary>
    Unknown,
}

/// <summary>
/// What the game knows as it decides what a world needs of the parked scripts.
/// </summary>
/// <param name="Scripts">The scripts this game would have with every mod on, the Patch folder's and the parked ones, relative to the game folder; <see langword="null"/> when they could not be listed.</param>
/// <param name="Elsewhere">The scripts behind a link to another drive; <see langword="null"/> when they could not be listed.</param>
/// <param name="Personal">The keys of the personal mods and of their names; <see langword="null"/> while the catalog is unknown.</param>
/// <param name="ParkedWorld">The world the parked scripts are parked for, empty when none are.</param>
/// <param name="Parked">The parked scripts.</param>
/// <param name="MovedHere">Whether this session moved scripts.</param>
public sealed record ParkingFacts(IReadOnlyList<string>? Scripts, IReadOnlyList<string>? Elsewhere, IReadOnlyCollection<string>? Personal, string ParkedWorld, IReadOnlyList<string> Parked, bool MovedHere);

/// <summary>
/// What entering a world needs of the parked scripts.
/// </summary>
/// <param name="Kind">The kind.</param>
/// <param name="Plan">The scripts to have parked for <see cref="ParkingKind.Plan"/>, sorted; none otherwise.</param>
/// <param name="Stuck">The scripts behind a link to another drive the world turns off.</param>
public sealed record ParkingChange(ParkingKind Kind, IReadOnlyList<string> Plan, IReadOnlyList<string> Stuck);

/// <summary>
/// Which scripts a world that turns other mods off parks: every script of the Patch folder but those
/// of the mods it names, of the personal ones and those every player has.
/// </summary>
public static class ParkingRules
{
    /// <summary>
    /// The keys of the scripts every player has, which no world turns off: the mod loader, this mod and
    /// Mod Config Remake, which ships with it.
    /// </summary>
    public static readonly IReadOnlySet<string> SharedKeys = new HashSet<string>(StringComparer.Ordinal) { "patch", "multiplayer", "0modconfigremake" };

    /// <summary>
    /// The folder the scripts sit in.
    /// </summary>
    private const string PatchFolder = "patch";

    /// <summary>
    /// The extension of a script, which an owner's name leaves out.
    /// </summary>
    private const string ScriptExtension = ".rb";

    /// <summary>
    /// Writes a path as two paths are compared by: forward slashes, ASCII letters in lower case, as
    /// Ruby 1.9's <c>downcase</c> did.
    /// </summary>
    /// <param name="path">The path.</param>
    /// <returns>The key.</returns>
    public static string PathKey(string path)
    {
        var key = new StringBuilder(path.Length);
        foreach (char character in path)
        {
            key.Append(character == '\\' ? '/' : character is >= 'A' and <= 'Z' ? (char)(character + 32) : character);
        }

        return key.ToString();
    }

    /// <summary>
    /// Names the mod a script belongs to: the folder it sits in right under the Patch folder, or for a
    /// script right in it its own file's name.
    /// </summary>
    /// <remarks>
    /// The mod loader loads the scripts of every folder under Patch too, and a mod keeps its helper
    /// scripts in a folder named after it.
    /// </remarks>
    /// <param name="path">The script's path relative to the game folder, such as "Patch/Luka_Replacer/heroes.rb".</param>
    /// <returns>The mod's name as the folder or file has it, such as "Luka_Replacer".</returns>
    public static string OwnerName(string path)
    {
        List<string> parts = path.Replace('\\', '/').Split('/').Where(part => part.Length > 0).ToList();
        if (parts.Count > 1 && PathKey(parts[0]) == PatchFolder)
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
    /// Tells which mod a script belongs to, see <see cref="OwnerName"/>.
    /// </summary>
    /// <param name="path">The script's path.</param>
    /// <returns>The mod's key, see <see cref="ModKey"/>.</returns>
    public static string OwnerKey(string path) => ModKey.Of(OwnerName(path));

    /// <summary>
    /// Picks the scripts a world's mods turn off.
    /// </summary>
    /// <param name="found">The scripts; <see langword="null"/> when they could not be listed.</param>
    /// <param name="mods">The world's mods as its creator wrote them.</param>
    /// <param name="personal">The keys of the personal mods; <see langword="null"/> while the catalog is unknown.</param>
    /// <returns>The scripts it turns off, each once, sorted by <see cref="PathKey"/>; <see langword="null"/> while they are unknown, also when the catalog is unknown and a script might be personal.</returns>
    public static IReadOnlyList<string>? TurnedOff(IReadOnlyList<string>? found, string? mods, IReadOnlyCollection<string>? personal)
    {
        if (found == null)
        {
            return null;
        }

        HashSet<string> named = ModsText.Names(mods).Select(ModKey.Of).ToHashSet(StringComparer.Ordinal);
        List<string> others = Distinct(found).Where(path => !named.Contains(OwnerKey(path))).ToList();
        if (others.Count == 0)
        {
            return [];
        }

        if (personal == null)
        {
            return null;
        }

        return others.Where(path => !personal.Contains(OwnerKey(path))).OrderBy(PathKey, Utf8Order.Instance).ToList();
    }

    /// <summary>
    /// Tells what has to change before the game may enter a world.
    /// </summary>
    /// <remarks>
    /// While the catalog is unknown, the scripts parked for the world stay as they are, since they were
    /// parked with a known one.
    /// </remarks>
    /// <param name="facts">What the game knows.</param>
    /// <param name="world">The world's id.</param>
    /// <param name="mods">The world's mods as its creator wrote them.</param>
    /// <param name="otherModsOff">Whether it turns other mods off.</param>
    /// <returns>The change.</returns>
    public static ParkingChange Change(ParkingFacts facts, string world, string? mods, bool otherModsOff)
    {
        IReadOnlyList<string> stuck = Stuck(facts, mods, otherModsOff);
        if (facts.MovedHere)
        {
            return new ParkingChange(ParkingKind.Restart, [], stuck);
        }

        if (otherModsOff && facts.Scripts == null)
        {
            return new ParkingChange(ParkingKind.Unlisted, [], stuck);
        }

        if (stuck.Count > 0)
        {
            return new ParkingChange(ParkingKind.Elsewhere, [], stuck);
        }

        IReadOnlyList<string>? plan = Plan(facts, mods, otherModsOff);
        if (plan == null)
        {
            return new ParkingChange(facts.Parked.Count == 0 || facts.ParkedWorld != world ? ParkingKind.Unknown : ParkingKind.None, [], stuck);
        }

        return SameScripts(plan, facts.Parked) ? new ParkingChange(ParkingKind.None, [], stuck) : new ParkingChange(ParkingKind.Plan, plan, stuck);
    }

    /// <summary>
    /// Lists the scripts a world turns off.
    /// </summary>
    /// <param name="facts">What the game knows.</param>
    /// <param name="mods">The world's mods.</param>
    /// <param name="otherModsOff">Whether it turns other mods off.</param>
    /// <returns>The scripts, none for a world that allows other mods; <see langword="null"/> while they are unknown, see <see cref="TurnedOff"/>.</returns>
    public static IReadOnlyList<string>? Plan(ParkingFacts facts, string? mods, bool otherModsOff) =>
        otherModsOff ? TurnedOff(facts.Scripts, mods, facts.Personal) : [];

    /// <summary>
    /// Lists the scripts behind a link to another drive that a world turns off, which keep the game out
    /// of it.
    /// </summary>
    /// <param name="facts">What the game knows.</param>
    /// <param name="mods">The world's mods.</param>
    /// <param name="otherModsOff">Whether it turns other mods off.</param>
    /// <returns>The scripts, none for a world that allows other mods or while they are unknown.</returns>
    public static IReadOnlyList<string> Stuck(ParkingFacts facts, string? mods, bool otherModsOff) =>
        otherModsOff ? TurnedOff(facts.Elsewhere, mods, facts.Personal) ?? [] : [];

    /// <summary>
    /// Tells whether two lists name the same scripts, by <see cref="PathKey"/>.
    /// </summary>
    /// <param name="first">The first list.</param>
    /// <param name="second">The second list.</param>
    /// <returns>Whether they do, the same script listed twice counting twice.</returns>
    public static bool SameScripts(IEnumerable<string> first, IEnumerable<string> second) =>
        first.Select(PathKey).Order(Utf8Order.Instance).SequenceEqual(second.Select(PathKey).Order(Utf8Order.Instance), StringComparer.Ordinal);

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
            string key = OwnerKey(path);
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

        return mods.Select(mod => (mod.Name, mod.Scripts)).ToList();
    }

    /// <summary>
    /// Leaves out every script listed before by its <see cref="PathKey"/>.
    /// </summary>
    /// <param name="paths">The scripts.</param>
    /// <returns>Each once, in the order listed.</returns>
    public static IEnumerable<string> Distinct(IEnumerable<string> paths) => paths.DistinctBy(PathKey, StringComparer.Ordinal);

    /// <summary>
    /// Orders texts by their UTF-8 bytes, as Ruby compares strings.
    /// </summary>
    private sealed class Utf8Order : IComparer<string>
    {
        /// <summary>
        /// The one comparer.
        /// </summary>
        public static readonly Utf8Order Instance = new();

        /// <inheritdoc />
        public int Compare(string? x, string? y) =>
            Encoding.UTF8.GetBytes(x ?? string.Empty).AsSpan().SequenceCompareTo(Encoding.UTF8.GetBytes(y ?? string.Empty));
    }
}
