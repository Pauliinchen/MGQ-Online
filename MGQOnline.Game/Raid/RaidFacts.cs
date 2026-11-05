//----------------------------------------------------------------
//  RaidFacts.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Game.Raid;

/// <summary>
/// What the raid boss rules read of a game: the map it stands on and the switches and variables of
/// <see cref="BossRules.ReadSwitches"/> and <see cref="BossRules.ReadVariables"/>; any other reads off.
/// </summary>
/// <param name="Map">The map, 0 for none.</param>
/// <param name="Switches">The switches that are on.</param>
/// <param name="Variables">The variables' values, by id.</param>
public sealed record RaidFacts(int Map, IReadOnlySet<int> Switches, IReadOnlyDictionary<int, long> Variables)
{
    /// <summary>
    /// Gets the facts of a new game on no map.
    /// </summary>
    public static RaidFacts Fresh { get; } = new(0, new HashSet<int>(), new Dictionary<int, long>());

    /// <summary>
    /// Gets whether the scripts handed every switch and variable the rules read.
    /// </summary>
    /// <remarks>Scripts whose table failed to load hand empty lists, which would read every boss as unbeaten.</remarks>
    public bool Complete { get; init; } = true;

    /// <summary>
    /// Reads the facts the scripts hand: <c>map</c>, <c>s</c> (on or off per switch of
    /// <see cref="BossRules.ReadSwitches"/>) and <c>v</c> (the value per variable of
    /// <see cref="BossRules.ReadVariables"/>), in that order; facts with shorter lists are not
    /// <see cref="Complete"/>.
    /// </summary>
    /// <param name="value">The facts, nil for a new game's.</param>
    /// <returns>The facts.</returns>
    public static RaidFacts Of(RubyValue value)
    {
        if (value is not RubyHash hash)
        {
            return Fresh;
        }

        var switches = new HashSet<int>();
        if (hash["s"] is RubyArray on)
        {
            for (int index = 0; index < on.Count && index < BossRules.ReadSwitches.Count; index++)
            {
                if (on[index] is RubyBool { Flag: true })
                {
                    switches.Add(BossRules.ReadSwitches[index]);
                }
            }
        }

        var variables = new Dictionary<int, long>();
        if (hash["v"] is RubyArray values)
        {
            for (int index = 0; index < values.Count && index < BossRules.ReadVariables.Count; index++)
            {
                if (values[index] is RubyInteger { Value: var number })
                {
                    variables[BossRules.ReadVariables[index]] = (long)number;
                }
            }
        }

        bool complete = hash["s"] is RubyArray { Count: var read } && read >= BossRules.ReadSwitches.Count
            && hash["v"] is RubyArray { Count: var valued } && valued >= BossRules.ReadVariables.Count;
        return new RaidFacts(hash["map"] is RubyInteger { Value: var map } ? (int)map : 0, switches, variables) { Complete = complete };
    }

    /// <summary>
    /// Tells whether a switch is on.
    /// </summary>
    /// <param name="id">The switch.</param>
    /// <returns>Whether it is.</returns>
    public bool Switch(int id) => Switches.Contains(id);

    /// <summary>
    /// Reads a variable.
    /// </summary>
    /// <param name="id">The variable.</param>
    /// <returns>Its value, 0 for one the facts lack.</returns>
    public long Variable(int id) => Variables.TryGetValue(id, out long value) ? value : 0;
}
