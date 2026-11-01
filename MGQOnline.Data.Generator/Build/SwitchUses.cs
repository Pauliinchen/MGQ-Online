//----------------------------------------------------------------
//  SwitchUses.cs
//
//  Changelog:
//      Paulinchen  2026-11-01: Read a constant of the scripts by its name
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.RegularExpressions;
using MGQOnline.Data.Generator.Source;

namespace MGQOnline.Data.Generator.Build;

/// <summary>
/// The switches the game's scripts and database use as switches, which the repair of stuck saves
/// leaves alone ("Issue 73 chest effects.md", E2 gate 3): a switch use is <c>$game_switches[...]</c>
/// with a literal or a constant, a band the scripts index by a constant base (the companions'
/// <c>ADD_ACTOR_RANGE</c>, the warp and place flags), the awaken band of the actors that hold
/// anything, and a database switch use: an enemy's action that asks for a switch, a note or a
/// damage formula that reads one. A number in a script that is no switch's index, as a variable's
/// or a class's id, is no use.
/// </summary>
internal sealed partial class SwitchUses
{
    /// <summary>
    /// The name of the constant whose band the scripts index by an actor's id, which counts only the
    /// actors that hold anything: the scripts act on such a switch only through its actor.
    /// </summary>
    private const string ActorBand = "AWAKEN_ID";

    /// <summary>
    /// The module whose range constants are switch bands.
    /// </summary>
    private const string SwitchModule = "Sw";

    /// <summary>
    /// How far a band reaches when no other band starts above it.
    /// </summary>
    private const int LastBandSpan = 1000;

    /// <summary>
    /// The switches used one by one.
    /// </summary>
    private readonly HashSet<int> _ids;

    /// <summary>
    /// The bands used, each from and to.
    /// </summary>
    private readonly List<(int From, int To)> _bands;

    /// <summary>
    /// Initializes the uses.
    /// </summary>
    /// <param name="ids">The switches used one by one.</param>
    /// <param name="bands">The bands used.</param>
    private SwitchUses(HashSet<int> ids, List<(int From, int To)> bands)
    {
        _ids = ids;
        _bands = bands;
    }

    /// <summary>
    /// Tells whether the game uses a switch as a switch outside its events.
    /// </summary>
    /// <param name="id">The switch.</param>
    /// <returns>Whether it does.</returns>
    public bool Uses(int id) => _ids.Contains(id) || _bands.Exists(band => id >= band.From && id <= band.To);

    /// <summary>
    /// Reads the uses of the game's scripts and database.
    /// </summary>
    /// <param name="scripts">The game's scripts, each as one text.</param>
    /// <param name="actorsInUse">Whether each actor holds anything, by id.</param>
    /// <param name="entries">The database's entries.</param>
    /// <returns>The uses.</returns>
    public static SwitchUses Of(IReadOnlyList<string> scripts, IReadOnlyList<bool?> actorsInUse, IEnumerable<SourceEntry?> entries)
    {
        ArgumentNullException.ThrowIfNull(scripts);
        ArgumentNullException.ThrowIfNull(actorsInUse);
        ArgumentNullException.ThrowIfNull(entries);
        Dictionary<string, long> values = ConstantsOf(scripts, out Dictionary<string, (long From, long To)> switchRanges);
        var ids = new HashSet<int>();
        var bases = new SortedSet<long>();
        string? actorBase = null;
        foreach (string script in scripts)
        {
            foreach (string index in IndexesOf(script))
            {
                if (Evaluate(index, values) is { } id)
                {
                    ids.Add((int)id);
                }
                else if (BaseOf(index, values) is { } found)
                {
                    bases.Add(found.Value);
                    actorBase = found.Name == ActorBand ? found.Name : actorBase;
                }
            }
        }

        long? actorStart = actorBase is null ? null : values[ActorBand];
        var bands = new List<(int From, int To)>();
        foreach (long start in bases.Where(start => start != actorStart))
        {
            long next = bases.FirstOrDefault(other => other > start);
            bands.Add(((int)start, (int)(next > start ? next - 1 : start + LastBandSpan)));
        }

        bands.AddRange(switchRanges.Values.Select(range => ((int)range.From, (int)range.To)));
        if (actorStart is { } awaken)
        {
            ids.UnionWith(Enumerable.Range(0, actorsInUse.Count).Where(actor => actorsInUse[actor] == true).Select(actor => (int)(awaken + actor)));
        }

        foreach (SourceEntry entry in entries.OfType<SourceEntry>())
        {
            ids.UnionWith(entry.ActionSwitches);
            foreach (Match read in SwitchRead().Matches(entry.Note + "\n" + entry.Formula))
            {
                ids.Add(int.Parse(read.Groups[1].Success ? read.Groups[1].Value : read.Groups[2].Value, CultureInfo.InvariantCulture));
            }
        }

        return new SwitchUses(ids, bands);
    }

    /// <summary>
    /// Reads a constant the scripts define with a value of whole numbers and other constants.
    /// </summary>
    /// <param name="scripts">The game's scripts, each as one text.</param>
    /// <param name="name">The constant's name, the last part of its path.</param>
    /// <returns>Its value, <see langword="null"/> when the scripts define none.</returns>
    public static long? ConstantOf(IReadOnlyList<string> scripts, string name)
    {
        ArgumentNullException.ThrowIfNull(scripts);
        return ConstantsOf(scripts, out _).TryGetValue(name, out long value) ? value : null;
    }

    /// <summary>
    /// Reads the constants the scripts define with a value of whole numbers and other constants, and
    /// the switch module's ranges.
    /// </summary>
    /// <param name="scripts">The scripts.</param>
    /// <param name="switchRanges">The ranges of the switch module, by name.</param>
    /// <returns>The values by name, the last part of a path naming one.</returns>
    private static Dictionary<string, long> ConstantsOf(IReadOnlyList<string> scripts, out Dictionary<string, (long From, long To)> switchRanges)
    {
        var definitions = new List<(string Name, string Value, bool InSwitches)>();
        foreach (string script in scripts)
        {
            string? module = null;
            foreach (string line in script.Split('\n'))
            {
                if (ModuleLine().Match(line) is { Success: true } opened)
                {
                    module = opened.Groups[1].Value;
                }
                else if (ConstantLine().Match(line) is { Success: true } constant)
                {
                    definitions.Add((constant.Groups[1].Value, constant.Groups[2].Value.Trim(), module == SwitchModule));
                }
            }
        }

        var values = new Dictionary<string, long>(StringComparer.Ordinal);
        for (bool found = true; found;)
        {
            found = false;
            foreach ((string name, string value, _) in definitions.Where(definition => !values.ContainsKey(definition.Name)))
            {
                if (Evaluate(value, values) is { } number)
                {
                    values[name] = number;
                    found = true;
                }
            }
        }

        switchRanges = new Dictionary<string, (long From, long To)>(StringComparer.Ordinal);
        foreach ((string name, string value, _) in definitions.Where(definition => definition.InSwitches))
        {
            if (RangeValue().Match(value) is { Success: true } range && Evaluate(range.Groups[1].Value, values) is { } from && Evaluate(range.Groups[2].Value, values) is { } to)
            {
                switchRanges[name] = (from, to);
            }
        }

        return values;
    }

    /// <summary>
    /// Lists the index expressions of a script's <c>$game_switches[...]</c>.
    /// </summary>
    /// <param name="script">The script.</param>
    /// <returns>The expressions between the brackets.</returns>
    private static IEnumerable<string> IndexesOf(string script)
    {
        const string Opening = "$game_switches[";
        for (int at = script.IndexOf(Opening, StringComparison.Ordinal); at >= 0; at = script.IndexOf(Opening, at + 1, StringComparison.Ordinal))
        {
            int start = at + Opening.Length;
            int depth = 1;
            int end = start;
            while (end < script.Length && depth > 0)
            {
                depth += script[end] == '[' ? 1 : script[end] == ']' ? -1 : 0;
                end++;
            }

            if (depth == 0)
            {
                yield return script[start..(end - 1)];
            }
        }
    }

    /// <summary>
    /// Evaluates whole numbers and constants added and taken away, such as <c>Actor::AWAKEN_BASE_ID + 5600</c>.
    /// </summary>
    /// <param name="expression">The expression.</param>
    /// <param name="values">The constants known.</param>
    /// <returns>Its value, <see langword="null"/> when it holds anything else.</returns>
    private static long? Evaluate(string expression, IReadOnlyDictionary<string, long> values)
    {
        Match terms = SumOfTerms().Match(expression.Trim());
        if (!terms.Success)
        {
            return null;
        }

        long sum = 0;
        for (int index = 0; index < terms.Groups["term"].Captures.Count; index++)
        {
            string term = terms.Groups["term"].Captures[index].Value;
            long? value = long.TryParse(term.Replace("_", string.Empty, StringComparison.Ordinal), NumberStyles.None, CultureInfo.InvariantCulture, out long number)
                ? number
                : values.TryGetValue(term[(term.LastIndexOf(':') + 1)..], out long constant) ? constant : null;
            if (value is null)
            {
                return null;
            }

            sum += index > 0 && terms.Groups["sign"].Captures[index - 1].Value == "-" ? -value.Value : value.Value;
        }

        return sum;
    }

    /// <summary>
    /// Finds the constant base an index adds something to, such as <c>NWConst::Sw::WARP_OPEN_BASE + place[:index]</c>.
    /// </summary>
    /// <param name="index">The index.</param>
    /// <param name="values">The constants known.</param>
    /// <returns>The base's name and value, <see langword="null"/> for an index of no constant base.</returns>
    private static (string Name, long Value)? BaseOf(string index, IReadOnlyDictionary<string, long> values) =>
        BaseIndex().Match(index.Trim()) is { Success: true } found && found.Groups[1].Value is { } path
            && values.TryGetValue(path[(path.LastIndexOf(':') + 1)..], out long value)
            ? (path[(path.LastIndexOf(':') + 1)..], value)
            : null;

    /// <summary>
    /// A line that opens a module.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"^\s*module\s+([A-Z]\w*)\s*$", RegexOptions.CultureInvariant)]
    private static partial Regex ModuleLine();

    /// <summary>
    /// A line that defines a constant, with its value up to a comment.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"^\s*([A-Z][A-Z0-9_]*)\s*=(?!=)\s*([^#\r]+)", RegexOptions.CultureInvariant)]
    private static partial Regex ConstantLine();

    /// <summary>
    /// A range of two expressions, such as <c>(ADD_ACTOR_BASE + 1)..(ADD_ACTOR_BASE + ADD_ACTOR_BASE_NUMBER)</c>.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"^\(?([^.()]+)\)?\.\.\(?([^.()]+)\)?$", RegexOptions.CultureInvariant)]
    private static partial Regex RangeValue();

    /// <summary>
    /// Whole numbers and constant paths added and taken away.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"^(?<term>[0-9][0-9_]*|[A-Z]\w*(?:::[A-Z]\w*)*)(?:\s*(?<sign>[+-])\s*(?<term>[0-9][0-9_]*|[A-Z]\w*(?:::[A-Z]\w*)*))*$", RegexOptions.CultureInvariant)]
    private static partial Regex SumOfTerms();

    /// <summary>
    /// An index that adds something to a constant base.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"^([A-Z]\w*(?:::[A-Z]\w*)*)\s*\+", RegexOptions.CultureInvariant)]
    private static partial Regex BaseIndex();

    /// <summary>
    /// A read of a switch in a note or a damage formula: <c>$game_switches[n]</c> or <c>s[n]</c>.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"\$game_switches\[\s*([0-9]+)\s*\]|(?<![A-Za-z0-9_$])s\[\s*([0-9]+)\s*\]", RegexOptions.CultureInvariant)]
    private static partial Regex SwitchRead();
}
