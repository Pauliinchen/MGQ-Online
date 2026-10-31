//----------------------------------------------------------------
//  OverviewBosses.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using MGQOnline.Game.Raid;
using MGQOnline.Game.Ruby;

namespace MGQOnline.Game.Overview;

/// <summary>
/// The World page's raid bosses: each section of the story with its bosses summed up from the
/// world's pools, and what the list and the reading pane say of each.
/// </summary>
public static class OverviewBosses
{
    /// <summary>
    /// The section the pools go under whose bosses the tables lack.
    /// </summary>
    public const string OtherSection = "Other";

    /// <summary>
    /// What the list and the pane say of a defeated raid boss.
    /// </summary>
    public const string DefeatedText = "Defeated";

    /// <summary>
    /// How the pane tells a raid boss's tier and what it changes.
    /// </summary>
    public const string TierLine = "Tier {0}: enemies have {1}.";

    /// <summary>
    /// How the pane tells who last hurt a raid boss.
    /// </summary>
    public const string LastHurt = "Last hurt by {0}.";

    /// <summary>
    /// The parts and routes of the world's story from which on a section's raid bosses show, by the
    /// section's name; a route the world finished counts too. A section left out shows once the
    /// story is told.
    /// </summary>
    public static readonly IReadOnlyDictionary<string, IReadOnlyList<string>> SectionReach = new Dictionary<string, IReadOnlyList<string>>(StringComparer.Ordinal)
    {
        ["Part 2"] = ["2", "3", "ad", "mr", "chaos"],
        ["Part 3"] = ["3", "ad", "mr", "chaos"],
        ["Angelic Dominion"] = ["ad", "chaos"],
        ["Monster Realm"] = ["mr", "chaos"],
        ["Chaos route"] = ["chaos"],
        ["Chaos Domain"] = ["chaos"],
    };

    /// <summary>
    /// The names of the stats a tier changes.
    /// </summary>
    public static readonly IReadOnlyDictionary<string, string> TierStats = new Dictionary<string, string>(StringComparer.Ordinal)
    {
        ["mhp"] = "HP", ["def"] = "DEF", ["mdf"] = "MDF", ["atk"] = "ATK", ["mat"] = "MAT", ["agi"] = "AGI", ["luk"] = "LUK", ["mmp"] = "MP",
    };

    /// <summary>
    /// The enemy's place in the troop that ends a pool's key, which its boss's name leaves out.
    /// </summary>
    private static readonly Regex Place = new("#[0-9]+\\z", RegexOptions.CultureInvariant);

    /// <summary>
    /// Lists the raid bosses by the story's sections in story order: each section the world's story
    /// reached or holding a boss a pool was told of, its bosses in the order the story meets them,
    /// then the pools of its fights that take their own name, by name; last, under
    /// <see cref="OtherSection"/>, the pools whose bosses the tables lack, by name.
    /// </summary>
    /// <param name="facts">The sections, the tables and the world's story.</param>
    /// <param name="pools">The pools as they stand now, by key.</param>
    /// <param name="told">The pools' keys in the order they were last told.</param>
    /// <returns>Each section's name with its bosses.</returns>
    public static IReadOnlyList<(string Section, IReadOnlyList<OverviewBoss> Bosses)> Sections(OverviewWorldFacts facts, IReadOnlyList<PoolView> pools, IReadOnlyList<string> told)
    {
        ArgumentNullException.ThrowIfNull(facts);
        ArgumentNullException.ThrowIfNull(pools);
        ArgumentNullException.ThrowIfNull(told);
        var order = told.Select((key, index) => (key, index)).ToDictionary(pair => pair.key, pair => pair.index, StringComparer.Ordinal);
        var byBoss = new Dictionary<string, List<PoolView>>(StringComparer.Ordinal);
        foreach (PoolView pool in pools)
        {
            string boss = BossOf(pool.Key);
            if (!byBoss.TryGetValue(boss, out List<PoolView>? kept))
            {
                byBoss[boss] = kept = [];
            }

            kept.Add(pool);
        }

        var listed = new List<(string, IReadOnlyList<OverviewBoss>)>();
        foreach (OverviewSection section in facts.Sections)
        {
            List<string> names = [.. section.Bosses, .. byBoss.Keys.Where(name => !section.Bosses.Contains(name, StringComparer.Ordinal) && SectionOf(facts, name) == section.Name).Order(StringComparer.Ordinal)];
            if (!Reached(section.Name, facts.Story) && !names.Any(byBoss.ContainsKey))
            {
                continue;
            }

            listed.Add((section.Name, [.. names.Select(name => Sum(name, TierOf(facts, name), Take(byBoss, name), order))]));
        }

        List<OverviewBoss> others = [.. byBoss.Keys.Order(StringComparer.Ordinal).Select(name => Sum(name, null, byBoss[name], order))];
        if (others.Count > 0)
        {
            listed.Add((OtherSection, others));
        }

        return listed;
    }

    /// <summary>
    /// Writes the share of a raid boss's HP left, never 0% while any is.
    /// </summary>
    /// <param name="left">The share, 0 to 1.</param>
    /// <returns>Such as "68%".</returns>
    public static string ShareText(double left) =>
        Math.Max((long)Math.Round(left * 100, MidpointRounding.AwayFromZero), left > 0 ? 1 : 0).ToString(CultureInfo.InvariantCulture) + "%";

    /// <summary>
    /// Lays a raid boss out for the reading pane: its section, its tier and what it changes, how
    /// much of its HP the world left it, and who last hurt it.
    /// </summary>
    /// <param name="boss">The boss.</param>
    /// <param name="section">Its section.</param>
    /// <param name="tiers">The stats each tier changes.</param>
    /// <returns>The pane's lines.</returns>
    public static IReadOnlyList<OverviewPaneLine> Pane(OverviewBoss boss, string section, IReadOnlyDictionary<int, IReadOnlyList<OverviewTierStat>> tiers)
    {
        ArgumentNullException.ThrowIfNull(boss);
        ArgumentNullException.ThrowIfNull(tiers);
        List<OverviewPaneLine> lines = [new("text", section, 0)];
        if (boss.Tier is { } tier && tiers.TryGetValue(tier, out IReadOnlyList<OverviewTierStat>? stats) && stats.Count > 0)
        {
            string text = string.Join(", ", stats.Select(stat => $"{TierStats.GetValueOrDefault(stat.Stat) ?? Upcase(stat.Stat)} x{Factor(stat.Factor)}"));
            lines.Add(new("text", string.Format(CultureInfo.InvariantCulture, TierLine, tier, text), 0));
        }

        lines.Add(new("gauge", boss.Defeated ? DefeatedText : ShareText(boss.Left), boss.Defeated ? 0.0 : boss.Left));
        if (boss.By is { } by)
        {
            lines.Add(new("text", string.Format(CultureInfo.InvariantCulture, LastHurt, by), 0));
        }

        return lines;
    }

    /// <summary>
    /// Finds the boss of a pool's key, without the enemy's place in the troop.
    /// </summary>
    /// <param name="key">The pool's key, such as "Black Alice#2".</param>
    /// <returns>The boss's name.</returns>
    public static string BossOf(string key) => Place.Replace(key, string.Empty, 1);

    /// <summary>
    /// Reports whether the world's story reached a section, see <see cref="SectionReach"/>.
    /// </summary>
    /// <param name="section">The section's name.</param>
    /// <param name="story">The world's story, <see langword="null"/> before the relay told it, which reaches none.</param>
    /// <returns>Whether it did.</returns>
    private static bool Reached(string section, OverviewWorldStory? story) =>
        story is not null && (!SectionReach.TryGetValue(section, out IReadOnlyList<string>? reach) || reach.Any(part => part == story.Part || story.Done.Contains(part, StringComparer.Ordinal)));

    /// <summary>
    /// Finds the section of a boss's name as the tables tell it.
    /// </summary>
    /// <param name="facts">The tables.</param>
    /// <param name="name">The name.</param>
    /// <returns>The section, <see langword="null"/> for a name the tables lack.</returns>
    private static string? SectionOf(OverviewWorldFacts facts, string name) => facts.Bosses.GetValueOrDefault(name)?.Section;

    /// <summary>
    /// Finds the tier of a boss's name as the tables tell it.
    /// </summary>
    /// <param name="facts">The tables.</param>
    /// <param name="name">The name.</param>
    /// <returns>The tier, <see langword="null"/> for a name the tables lack.</returns>
    private static int? TierOf(OverviewWorldFacts facts, string name) => facts.Bosses.GetValueOrDefault(name)?.Tier;

    /// <summary>
    /// Takes a boss's pools out of those not listed yet.
    /// </summary>
    /// <param name="byBoss">The pools not listed yet, by boss.</param>
    /// <param name="name">The boss.</param>
    /// <returns>Its pools, none while the relay told none.</returns>
    private static IReadOnlyList<PoolView> Take(Dictionary<string, List<PoolView>> byBoss, string name) =>
        byBoss.Remove(name, out List<PoolView>? pools) ? pools : [];

    /// <summary>
    /// Sums a raid boss up from its pools: the share left over them, whether every one is empty for
    /// good, and who defeated the one told last that names anyone.
    /// </summary>
    /// <param name="name">The boss's name.</param>
    /// <param name="tier">Its tier.</param>
    /// <param name="pools">Its pools.</param>
    /// <param name="order">Each pool's place in the order they were told.</param>
    /// <returns>The boss.</returns>
    private static OverviewBoss Sum(string name, int? tier, IReadOnlyList<PoolView> pools, Dictionary<string, int> order)
    {
        if (pools.Count == 0)
        {
            return new OverviewBoss(name, tier, 1.0, false, null);
        }

        double left = 0.0;
        foreach (PoolView pool in pools)
        {
            left += pool.Left;
        }

        PoolView? hurt = pools.Where(pool => pool.By.Length > 0).MaxBy(pool => order.GetValueOrDefault(pool.Key, -1));
        return new OverviewBoss(name, tier, left / pools.Count, pools.All(pool => pool.Defeated), hurt?.By);
    }

    /// <summary>
    /// Upper-cases a stat's name as Ruby 1.9's <c>String#upcase</c> does: the letters a to z only.
    /// </summary>
    /// <param name="text">The name.</param>
    /// <returns>The name with a to z upper-cased.</returns>
    private static string Upcase(string text) => string.Concat(text.Select(character => character is >= 'a' and <= 'z' ? (char)(character - 32) : character));

    /// <summary>
    /// Writes a tier's factor as the pane shows it: a whole number without its point.
    /// </summary>
    /// <param name="factor">The factor as the tables write it.</param>
    /// <returns>Such as "50" or "4.33".</returns>
    private static string Factor(string factor)
    {
        double value = RubyNumbers.ToF(Encoding.UTF8.GetBytes(factor));
        double whole = Math.Round(value, MidpointRounding.AwayFromZero);
        return value == whole ? whole.ToString("0", CultureInfo.InvariantCulture) : RubyNumbers.FloatToS(value);
    }
}
