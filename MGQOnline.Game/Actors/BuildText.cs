//----------------------------------------------------------------
//  BuildText.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.RegularExpressions;

namespace MGQOnline.Game.Actors;

/// <summary>
/// Characters' builds as text, which a co-op battle's players, a PvP team and a team duel's
/// Frontline carry: a member line per character, and for a PvP team a first line that says
/// whether the sender's battles have the Backline. The reader takes only what fits the rules; the
/// scripts then leave out what their game's data lacks.
/// </summary>
public static partial class BuildText
{
    /// <summary>
    /// Starts every member line.
    /// </summary>
    public const string MemberPrefix = "member=";

    /// <summary>
    /// Starts a PvP team's first line, followed by 1 when the sender's battles have the Backline, else 0.
    /// </summary>
    public const string RulePrefix = "backline=";

    /// <summary>
    /// The build format, which both games must share, the first part of <see cref="Game"/>.
    /// </summary>
    public const int Format = 3;

    /// <summary>
    /// The fields every member line has; the hero follows as one more only for a replaced Luka.
    /// </summary>
    public const int FieldCount = 14;

    /// <summary>
    /// The entries a list of a member takes at most.
    /// </summary>
    public const int MostEntries = 3000;

    /// <summary>
    /// The equipment slots a member takes at most.
    /// </summary>
    public const int MostSlots = 8;

    /// <summary>
    /// The highest job or race level taken from another game.
    /// </summary>
    public const long MostLevel = 999;

    /// <summary>
    /// The stats the game counts, max HP to luck.
    /// </summary>
    public const int ParamCount = 8;

    /// <summary>
    /// The counters of the owner's save a member carries, those core_actors.rbx's COUNTERS name.
    /// </summary>
    public const int CounterCount = 7;

    /// <summary>
    /// How much of an unreadable line the log shows.
    /// </summary>
    private const int LoggedLength = 120;

    /// <summary>
    /// Writes the fingerprint of a game's data and of the build format: only games with equal
    /// fingerprints may swap builds, since the ids and fields must mean the same things.
    /// </summary>
    /// <param name="sizes">The sizes of the databases a build names.</param>
    /// <returns>The fingerprint, the format and the sizes, such as "3:3,201,101".</returns>
    public static string Game(IEnumerable<long> sizes) =>
        $"{Format.ToString(CultureInfo.InvariantCulture)}:{string.Join(",", sizes.Select(Text))}";

    /// <summary>
    /// Writes characters' builds.
    /// </summary>
    /// <param name="builds">The characters' builds.</param>
    /// <param name="backline">For a PvP team, whether the sender's battles have the Backline;
    /// <see langword="null"/> for builds alone.</param>
    /// <returns>A member line per character, below the rule's line for a PvP team.</returns>
    public static string Write(IEnumerable<ActorBuild> builds, bool? backline)
    {
        ArgumentNullException.ThrowIfNull(builds);
        string members = string.Join("\n", builds.Select(Line));
        return backline is { } rule ? $"{RulePrefix}{(rule ? 1 : 0)}\n{members}" : members;
    }

    /// <summary>
    /// Reports whether a PvP team says its sender's battles have the Backline.
    /// </summary>
    /// <param name="team">The team, see <see cref="Write"/>.</param>
    /// <returns>Whether it does.</returns>
    public static bool HasBackline(string team) =>
        team.StartsWith(RulePrefix + "1\n", StringComparison.Ordinal) || team.StartsWith(RulePrefix + "1\r\n", StringComparison.Ordinal);

    /// <summary>
    /// Reads the builds another game wrote, a PvP team's rule's line skipped.
    /// </summary>
    /// <param name="text">The builds, see <see cref="Write"/>.</param>
    /// <param name="limit">How many to take at most.</param>
    /// <param name="leftOut">Takes a line for the log for each line and piece of equipment left out.</param>
    /// <returns>The builds, none when nothing was readable.</returns>
    public static List<ActorBuild> Read(string text, int limit, Action<string> leftOut)
    {
        ArgumentNullException.ThrowIfNull(text);
        ArgumentNullException.ThrowIfNull(leftOut);
        var builds = new List<ActorBuild>();
        List<string> lines = Split(text, '\n');
        if (lines.Count > 0 && RulePattern().IsMatch(lines[0].Trim()))
        {
            lines.RemoveAt(0);
        }

        foreach (string line in lines)
        {
            if (builds.Count >= limit)
            {
                break;
            }

            if (Member(line.Trim(), leftOut) is { } build)
            {
                builds.Add(build);
            }
            else
            {
                leftOut($"left out an unreadable member: {line[..Math.Min(line.Length, LoggedLength)]}");
            }
        }

        return builds;
    }

    /// <summary>
    /// Splits a text as Ruby's <c>String#split</c> does with one character: the empty parts at its
    /// end left out.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="separator">The character between the parts.</param>
    /// <returns>The parts.</returns>
    internal static List<string> Split(string text, char separator)
    {
        List<string> parts = [.. text.Split(separator)];
        while (parts.Count > 0 && parts[^1].Length == 0)
        {
            parts.RemoveAt(parts.Count - 1);
        }

        return parts;
    }

    /// <summary>
    /// Reads a number as Ruby's <c>String#to_i</c> does: an optional minus and the digits that
    /// follow, 0 for none, held at the edges of 64 bits.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The number.</returns>
    internal static long ToI(string text)
    {
        bool negative = text.StartsWith('-');
        long number = 0;
        foreach (char digit in text.Skip(negative ? 1 : 0).TakeWhile(char.IsAsciiDigit))
        {
            number = number > (long.MaxValue - 9) / 10 ? long.MaxValue : (number * 10) + (digit - '0');
        }

        return negative ? -number : number;
    }

    /// <summary>
    /// Writes a member line: <see cref="MemberPrefix"/> and its fields, split by <c>;</c>: 0 actor
    /// id, 1 personal level, 2 job, 3 race, 4 every job and race level as id:level, 5 the stat
    /// growths from items, 6 the skills learned, 7 the abilities learned and 8 set as skill
    /// type:id.id, 9 the equipment per slot (see <see cref="ItemText"/>), 10 the stats, 11 the
    /// rates, 12 the counters, 13 the switches on and 14 the hero, only when there is one.
    /// </summary>
    /// <param name="build">The character's build.</param>
    /// <returns>The member line.</returns>
    private static string Line(ActorBuild build)
    {
        var fields = new List<string>
        {
            Text(build.ActorId),
            Text(build.BaseLevel),
            build.ClassId is { } classId ? Text(classId) : string.Empty,
            build.TribeId is { } tribeId ? Text(tribeId) : string.Empty,
            string.Join(",", build.Levels.Select(level => $"{Text(level.Id)}:{Text(level.Level)}")),
            Joined(build.ParamPlus),
            Joined(build.Skills),
            Groups(build.Abilities),
            Groups(build.EquipAbilities),
            string.Join(",", build.Equips.Select(ItemText.Write)),
            Joined(build.Params),
            Joined(build.Rates),
            Joined(build.Counters),
            Joined(build.SwitchesOn),
        };
        if (build.Hero.Length > 0 && HeroPattern().IsMatch(build.Hero))
        {
            fields.Add(build.Hero);
        }

        return MemberPrefix + string.Join(";", fields);
    }

    /// <summary>
    /// Reads a member line.
    /// </summary>
    /// <param name="line">The line, see <see cref="Line"/>.</param>
    /// <param name="leftOut">Takes a line for the log for each piece of equipment left out.</param>
    /// <returns>The build, <see langword="null"/> when the line is none, has the wrong number of
    /// fields or names no actor.</returns>
    private static ActorBuild? Member(string line, Action<string> leftOut)
    {
        if (!line.StartsWith(MemberPrefix, StringComparison.Ordinal))
        {
            return null;
        }

        string[] fields = line[MemberPrefix.Length..].Split(';');
        long? actorId = fields.Length is FieldCount or FieldCount + 1 ? Number(fields[0]) : null;
        if (actorId is not > 0)
        {
            return null;
        }

        return new ActorBuild(
            actorId.Value,
            Math.Max(Number(fields[1]) ?? 1, 1),
            Number(fields[2]),
            Number(fields[3]),
            Levels(fields[4]),
            [.. Numbers(fields[5]).Concat(Enumerable.Repeat(0L, ParamCount)).Take(ParamCount)],
            [.. Numbers(fields[6]).Distinct()],
            AbilityGroups(fields[7]),
            AbilityGroups(fields[8]),
            Equips(fields[9], leftOut),
            Numbers(fields[10]),
            Numbers(fields[11]),
            [.. Numbers(fields[12]).Concat(Enumerable.Repeat(0L, CounterCount)).Take(CounterCount).Select(counter => Math.Max(counter, 0))],
            [.. Numbers(fields[13]).Where(id => id > 0)],
            fields.Length > FieldCount && HeroPattern().IsMatch(fields[FieldCount]) ? fields[FieldCount] : string.Empty);
    }

    /// <summary>
    /// Reads the job and race levels.
    /// </summary>
    /// <param name="text">id:level pairs joined by <c>,</c>.</param>
    /// <returns>Each level by its job's or race's id, held between 1 and <see cref="MostLevel"/>.</returns>
    private static List<(long Id, long Level)> Levels(string text)
    {
        var levels = new List<(long Id, long Level)>();
        foreach (string pair in Split(text, ',').Take(MostEntries))
        {
            List<string> parts = Split(pair, ':');
            if (parts.Count >= 2 && Number(parts[0]) is > 0 and var id && Number(parts[1]) is { } level)
            {
                levels.Add((id, Math.Clamp(level, 1, MostLevel)));
            }
        }

        return levels;
    }

    /// <summary>
    /// Reads an ability table.
    /// </summary>
    /// <param name="text">Skill type:id.id groups joined by <c>,</c>.</param>
    /// <returns>The ability ids by skill type.</returns>
    private static List<(long SkillType, IReadOnlyList<long> Ids)> AbilityGroups(string text)
    {
        var groups = new List<(long SkillType, IReadOnlyList<long> Ids)>();
        foreach (string group in Split(text, ',').Take(MostEntries))
        {
            int colon = group.IndexOf(':', StringComparison.Ordinal);
            if (colon >= 0 && Number(group[..colon]) is { } skillType)
            {
                groups.Add((skillType, [.. Split(group[(colon + 1)..], '.').Take(MostEntries).Select(Number).OfType<long>()]));
            }
        }

        return groups;
    }

    /// <summary>
    /// Reads the equipment per slot.
    /// </summary>
    /// <param name="text">Items joined by <c>,</c>, see <see cref="ItemText"/>.</param>
    /// <param name="leftOut">Takes a line for the log for each piece of equipment left out.</param>
    /// <returns>The items, <see langword="null"/> for an empty slot or an unreadable item; at most
    /// <see cref="MostSlots"/>.</returns>
    private static List<BuildItem?> Equips(string text, Action<string> leftOut)
    {
        var equips = new List<BuildItem?>();
        IEnumerable<string> slots = text.Length == 0 ? [] : text.Split(',').Take(MostSlots);
        foreach (string slot in slots)
        {
            if (!ItemText.TryRead(slot, out BuildItem? item))
            {
                leftOut($"left out equipment {slot[..Math.Min(slot.Length, 40)]}: unreadable");
            }

            equips.Add(item);
        }

        return equips;
    }

    /// <summary>
    /// Reads a list of numbers.
    /// </summary>
    /// <param name="text">Numbers joined by <c>,</c>.</param>
    /// <returns>The numbers, at most <see cref="MostEntries"/>.</returns>
    private static List<long> Numbers(string text) => [.. Split(text, ',').Take(MostEntries).Select(Number).OfType<long>()];

    /// <summary>
    /// Reads a number field.
    /// </summary>
    /// <param name="text">A field.</param>
    /// <returns>Its number, <see langword="null"/> when it is none.</returns>
    private static long? Number(string text) =>
        NumberPattern().IsMatch(text) ? long.Parse(text, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture) : null;

    /// <summary>
    /// Writes an ability table.
    /// </summary>
    /// <param name="groups">Ability ids by skill type.</param>
    /// <returns>The table as skill type:id.id, joined by <c>,</c>.</returns>
    private static string Groups(IEnumerable<(long SkillType, IReadOnlyList<long> Ids)> groups) =>
        string.Join(",", groups.Select(group => $"{Text(group.SkillType)}:{string.Join(".", group.Ids.Select(Text))}"));

    /// <summary>
    /// Joins numbers by <c>,</c>.
    /// </summary>
    /// <param name="numbers">The numbers.</param>
    /// <returns>The text.</returns>
    private static string Joined(IEnumerable<long> numbers) => string.Join(",", numbers.Select(Text));

    /// <summary>
    /// Writes a number.
    /// </summary>
    /// <param name="number">The number.</param>
    /// <returns>Its digits.</returns>
    private static string Text(long number) => number.ToString(CultureInfo.InvariantCulture);

    /// <summary>
    /// A whole number, ids and levels included.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex("\\A-?[0-9]{1,15}\\z", RegexOptions.CultureInvariant)]
    private static partial Regex NumberPattern();

    /// <summary>
    /// The key of a hero Luka Replacer plays in Luka's place, empty for Luka.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex("\\A[a-z0-9_]{0,32}\\z", RegexOptions.CultureInvariant)]
    private static partial Regex HeroPattern();

    /// <summary>
    /// A PvP team's first line, see <see cref="RulePrefix"/>.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex("\\Abackline=[01]\\z", RegexOptions.CultureInvariant)]
    private static partial Regex RulePattern();
}
