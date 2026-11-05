//----------------------------------------------------------------
//  BeatenMarker.cs
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
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Raid;

/// <summary>
/// What tells a milestone beaten: alternatives split by "|", each a list of conditions split by
/// "&amp;", a switch on ("s2261") or a variable at least a value ("v1023&gt;=2"). An id of the
/// story's table goes by its name in <see cref="StoryIds.Entries"/>, with its place in a list:
/// "v{main_progress}&gt;=17" or "s{clear_switches.0}".
/// </summary>
public sealed partial class BeatenMarker
{
    /// <summary>
    /// The conditions of each alternative.
    /// </summary>
    private readonly Condition[][] _alternatives;

    /// <summary>
    /// Initializes a new instance of the <see cref="BeatenMarker"/> class.
    /// </summary>
    /// <param name="milestone">The milestone.</param>
    /// <param name="cap">Its level cap, null after the last.</param>
    /// <param name="test">The test, see the class.</param>
    public BeatenMarker(string milestone, int? cap, string test)
    {
        Milestone = milestone;
        Cap = cap;
        _alternatives = [.. test.Split('|').Select(all => all.Split('&').Select(ConditionOf).ToArray())];
    }

    /// <summary>
    /// Gets the milestone.
    /// </summary>
    public string Milestone { get; }

    /// <summary>
    /// Gets the milestone's level cap, null after the last.
    /// </summary>
    public int? Cap { get; }

    /// <summary>
    /// Gets the switches the marker reads.
    /// </summary>
    public IEnumerable<int> Switches => _alternatives.SelectMany(all => all).Where(each => each.Switch).Select(each => each.Id);

    /// <summary>
    /// Gets the variables the marker reads.
    /// </summary>
    public IEnumerable<int> Variables => _alternatives.SelectMany(all => all).Where(each => !each.Switch && each.Id > 0).Select(each => each.Id);

    /// <summary>
    /// Tells whether a story meets the marker.
    /// </summary>
    /// <param name="facts">The story.</param>
    /// <returns>Whether it does.</returns>
    public bool Met(RaidFacts facts) => _alternatives.Any(all => all.All(each => each.Id > 0 && (each.Switch ? facts.Switch(each.Id) : facts.Variable(each.Id) >= each.AtLeast)));

    /// <summary>
    /// Reads one condition, with the story's ids put in.
    /// </summary>
    /// <param name="text">Such as "s2261", "v1023&gt;=2" or "v{main_progress}&gt;=17".</param>
    /// <returns>The condition; one of id 0, which nothing meets, for a text that is none.</returns>
    private static Condition ConditionOf(string text)
    {
        string plain = StoryId().Replace(text, match => IdOf(match.Groups[1].Value, match.Groups[2].Success ? int.Parse(match.Groups[2].Value, CultureInfo.InvariantCulture) : null).ToString(CultureInfo.InvariantCulture));
        if (SwitchForm().Match(plain) is { Success: true } on)
        {
            return new Condition(true, int.Parse(on.Groups[1].Value, CultureInfo.InvariantCulture), 0);
        }

        return VariableForm().Match(plain) is { Success: true } at
            ? new Condition(false, int.Parse(at.Groups[1].Value, CultureInfo.InvariantCulture), long.Parse(at.Groups[2].Value, CultureInfo.InvariantCulture))
            : new Condition(false, 0, 0);
    }

    /// <summary>
    /// Finds an id of the story's table.
    /// </summary>
    /// <param name="name">Its name.</param>
    /// <param name="place">Its place in a list, null for a single id.</param>
    /// <returns>The id, 0 for a name or place the table lacks.</returns>
    private static int IdOf(string name, int? place) =>
        StoryIds.Entries.FirstOrDefault(entry => entry.Key == name).Value switch
        {
            int id when place is null => id,
            IReadOnlyList<int> list when place is { } at && at < list.Count => list[at],
            _ => 0,
        };

    /// <summary>
    /// An id of the story's table in a condition.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"\{(\w+)(?:\.(\d+))?\}")]
    private static partial Regex StoryId();

    /// <summary>
    /// A switch that must be on.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"\As(\d+)\z")]
    private static partial Regex SwitchForm();

    /// <summary>
    /// A variable that must be at least a value.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"\Av(\d+)>=(-?\d+)\z")]
    private static partial Regex VariableForm();

    /// <summary>
    /// One condition.
    /// </summary>
    /// <param name="Switch">Whether it names a switch, else a variable.</param>
    /// <param name="Id">The switch or variable, 0 for a condition nothing meets.</param>
    /// <param name="AtLeast">The least value of a variable.</param>
    private readonly record struct Condition(bool Switch, int Id, long AtLeast);
}
