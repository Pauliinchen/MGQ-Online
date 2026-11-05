//----------------------------------------------------------------
//  StoryValues.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Read the story's ids from StoryIds
//      Paulinchen  2026-10-28: Changed the values as the catch-up's actions change the game's, and kept the self switches in their order
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Catchup;

/// <summary>
/// What a look of the catch-up reads of a story: the switches and self switches on and the
/// variables set, as the game's own data holds them, so a variable never set is none, not 0. The
/// catch-up's engine changes them as its actions will change the game's.
/// </summary>
public sealed class StoryValues
{
    /// <summary>
    /// The switches on.
    /// </summary>
    private readonly HashSet<int> _switches;

    /// <summary>
    /// The variables set, by id.
    /// </summary>
    private readonly Dictionary<int, long> _variables;

    /// <summary>
    /// The self switches on.
    /// </summary>
    private readonly HashSet<StoryKey> _selfSwitches;

    /// <summary>
    /// The self switches on in the order they came, as the game's own Hash keeps them.
    /// </summary>
    private readonly List<StoryKey> _selfOrder = [];

    /// <summary>
    /// Initializes a story's values.
    /// </summary>
    /// <param name="switchesOn">The switches on.</param>
    /// <param name="variables">The variables set, each with its value.</param>
    /// <param name="selfSwitchesOn">The self switches on.</param>
    public StoryValues(IEnumerable<int> switchesOn, IEnumerable<KeyValuePair<int, long>> variables, IEnumerable<StoryKey> selfSwitchesOn)
    {
        ArgumentNullException.ThrowIfNull(switchesOn);
        ArgumentNullException.ThrowIfNull(variables);
        ArgumentNullException.ThrowIfNull(selfSwitchesOn);
        _switches = [.. switchesOn];
        _variables = [];
        foreach ((int id, long value) in variables)
        {
            _variables[id] = value;
        }

        _selfSwitches = [];
        foreach (StoryKey key in selfSwitchesOn)
        {
            SetSelfSwitch(key);
        }
    }

    /// <summary>
    /// Gets the part the story is in, as the relay counts it.
    /// </summary>
    public string Part => StoryParts.Of(Math.Max(Variable(StoryIds.MainProgress) ?? 0, 0), [.. StoryIds.RouteVariables.Select(route => Variable(route) ?? 0)]);

    /// <summary>
    /// Gets the self switches on, in the order they came.
    /// </summary>
    public IReadOnlyList<StoryKey> SelfSwitchesOn => _selfOrder;

    /// <summary>
    /// Gets the side the story took along: <c>alice</c>, <c>ilias</c> or <see langword="null"/> for
    /// none yet.
    /// </summary>
    public string? Side => Switch(StoryIds.SideSwitches[0]) ? "alice" : Switch(StoryIds.SideSwitches[1]) ? "ilias" : null;

    /// <summary>
    /// Reports whether a switch is on.
    /// </summary>
    /// <param name="id">The switch.</param>
    /// <returns>Whether it is.</returns>
    public bool Switch(int id) => _switches.Contains(id);

    /// <summary>
    /// Reads a variable.
    /// </summary>
    /// <param name="id">The variable.</param>
    /// <returns>Its value, <see langword="null"/> while it was never set.</returns>
    public long? Variable(int id) => _variables.TryGetValue(id, out long value) ? value : null;

    /// <summary>
    /// Reports whether a self switch is on.
    /// </summary>
    /// <param name="key">The self switch.</param>
    /// <returns>Whether it is.</returns>
    public bool SelfSwitch(StoryKey key) => _selfSwitches.Contains(key);

    /// <summary>
    /// Turns a switch on or off.
    /// </summary>
    /// <param name="id">The switch.</param>
    /// <param name="on">Whether it is on.</param>
    public void SetSwitch(int id, bool on)
    {
        if (on)
        {
            _switches.Add(id);
        }
        else
        {
            _switches.Remove(id);
        }
    }

    /// <summary>
    /// Sets a variable.
    /// </summary>
    /// <param name="id">The variable.</param>
    /// <param name="value">Its value.</param>
    public void SetVariable(int id, long value) => _variables[id] = value;

    /// <summary>
    /// Turns a self switch on.
    /// </summary>
    /// <param name="key">The self switch.</param>
    public void SetSelfSwitch(StoryKey key)
    {
        if (_selfSwitches.Add(key))
        {
            _selfOrder.Add(key);
        }
    }

    /// <summary>
    /// Reports whether a mark holds: a switch or self switch on, a variable set at its least value or
    /// more.
    /// </summary>
    /// <param name="mark">The mark.</param>
    /// <returns>Whether it holds.</returns>
    public bool Holds(StoryMark mark) => mark.Key.Kind switch
    {
        StoryKeyKind.Switch => Switch(mark.Key.Id),
        StoryKeyKind.Variable => Variable(mark.Key.Id) is { } value && value >= mark.AtLeast,
        StoryKeyKind.SelfSwitch => SelfSwitch(mark.Key),
        _ => false,
    };

    /// <summary>
    /// Reports whether the story finished a route.
    /// </summary>
    /// <param name="route">The route, as <see cref="StoryParts.Routes"/> names it.</param>
    /// <returns>Whether it did; false for no route.</returns>
    public bool Cleared(string route)
    {
        for (int index = 0; index < StoryParts.Routes.Count; index++)
        {
            if (StoryParts.Routes[index] == route)
            {
                return Switch(StoryIds.ClearSwitches[index]);
            }
        }

        return false;
    }
}
