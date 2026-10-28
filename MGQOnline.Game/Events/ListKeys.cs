//----------------------------------------------------------------
//  ListKeys.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Read the script keys and self switch letters the classifier found
//                            - Built the keys from the rows of a list
//                            - Kept the value each variable is set to when it is known before the list runs
//                            - Kept the self switches the list turns on and the maps it transfers the player to
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Game.Events;

/// <summary>
/// A range of switches or variables a command writes.
/// </summary>
/// <param name="Variable">Whether the range is of variables, else of switches.</param>
/// <param name="From">The first id.</param>
/// <param name="To">The last id; a range that ends before it starts holds none.</param>
public readonly record struct KeyRange(bool Variable, long From, long To);

/// <summary>
/// A range of variables a command sets, with the value when it is known before the list runs.
/// </summary>
/// <param name="From">The first variable.</param>
/// <param name="To">The last variable; a range that ends before it starts holds none.</param>
/// <param name="Value">The value a set to a constant writes; <see langword="null"/> for any other operation, operand or command.</param>
public readonly record struct VariableSet(long From, long To, long? Value);

/// <summary>
/// What one list of event commands reads and writes by itself, every branch counted, without the
/// common events it calls: the keys of the story it reads, the keys and self switches it sets, the
/// common events it calls and the troops it fights.
/// </summary>
public sealed class ListKeys
{
    /// <summary>
    /// Gets the switches the list reads: branches, page conditions and scripts.
    /// </summary>
    public HashSet<long> ReadSwitches { get; } = [];

    /// <summary>
    /// Gets the variables the list reads: branches, operands, places and troops by variable, scripts.
    /// </summary>
    public HashSet<long> ReadVariables { get; } = [];

    /// <summary>
    /// Gets the switches and variables the list sets, in their order.
    /// </summary>
    public List<KeyRange> Writes { get; } = [];

    /// <summary>
    /// Gets the variables the list sets with their values where known, in their order.
    /// </summary>
    public List<VariableSet> VariableSets { get; } = [];

    /// <summary>
    /// Gets the switches the list turns on (Control Switches to on), in their order.
    /// </summary>
    public List<KeyRange> TurnsOn { get; } = [];

    /// <summary>
    /// Gets the letters of the self switches the list sets, in their order.
    /// </summary>
    public List<string> SelfSwitches { get; } = [];

    /// <summary>
    /// Gets the letters of the self switches the list turns on, in their order.
    /// </summary>
    public List<string> SelfSwitchesOn { get; } = [];

    /// <summary>
    /// Gets the maps the list transfers the player to by a constant, by the numbers the commands
    /// hold (see <see cref="GameDataPaths.TransferMap"/>), in their order.
    /// </summary>
    public List<long> Transfers { get; } = [];

    /// <summary>
    /// Gets the common events the list calls, in their order.
    /// </summary>
    public List<long> Calls { get; } = [];

    /// <summary>
    /// Gets the troops the list fights by their ids, in their order.
    /// </summary>
    public List<long> Troops { get; } = [];

    /// <summary>
    /// Gets the battles and common event calls of the list in their order: each a troop it fights,
    /// or a common event it calls.
    /// </summary>
    public List<(bool Call, long Id)> BattlesAndCalls { get; } = [];

    /// <summary>
    /// Initializes the keys of a list from its rows, see <see cref="ListRows"/>.
    /// </summary>
    /// <param name="rows">The rows, each kind in the order of the commands.</param>
    public ListKeys(ListRows rows)
    {
        foreach (ListRead read in rows.Reads)
        {
            (read.Variable ? ReadVariables : ReadSwitches).Add(read.Id);
        }

        foreach (ListWrite write in rows.Writes)
        {
            Writes.Add(write.Range);
            if (write.Range.Variable)
            {
                VariableSets.Add(new VariableSet(write.Range.From, write.Range.To, write.Value));
            }

            if (write.TurnsOn)
            {
                TurnsOn.Add(write.Range);
            }
        }

        SelfSwitches.AddRange(rows.SelfSwitches.Select(selfSwitch => selfSwitch.Letter));
        SelfSwitchesOn.AddRange(rows.SelfSwitches.Where(selfSwitch => selfSwitch.TurnsOn).Select(selfSwitch => selfSwitch.Letter));
        Transfers.AddRange(rows.Transfers.Select(transfer => transfer.MapId));
        Calls.AddRange(rows.Calls.Select(call => call.CommonId));
        Troops.AddRange(rows.Battles.Select(battle => battle.TroopId));
        BattlesAndCalls.AddRange(rows.Calls.Select(call => (call.Place, (true, call.CommonId)))
            .Concat(rows.Battles.Select(battle => (battle.Place, (false, battle.TroopId))))
            .OrderBy(pair => pair.Place)
            .Select(pair => pair.Item2));
    }

    /// <summary>
    /// Reads what a list does.
    /// </summary>
    /// <param name="list">The commands.</param>
    /// <returns>What it reads and writes.</returns>
    public static ListKeys Of(IReadOnlyList<EventCommand> list) => new(ListRows.Of(list));

    /// <summary>
    /// Reads what a map event's page does: its list and the switches and variable its conditions check.
    /// </summary>
    /// <param name="page">The page.</param>
    /// <returns>What it reads and writes.</returns>
    public static ListKeys Of(EventPage page) => new(ListRows.Of(page));

    /// <summary>
    /// Tells whether the list reads or writes a switch or variable of a set.
    /// </summary>
    /// <param name="switches">The switches, sorted.</param>
    /// <param name="variables">The variables, sorted.</param>
    /// <returns>Whether it does.</returns>
    public bool Touches(SortedSet<long> switches, SortedSet<long> variables) =>
        ReadSwitches.Overlaps(switches) || ReadVariables.Overlaps(variables)
        || Writes.Exists(range => range.From <= range.To && (range.Variable ? variables : switches).GetViewBetween(range.From, range.To).Count > 0);
}
