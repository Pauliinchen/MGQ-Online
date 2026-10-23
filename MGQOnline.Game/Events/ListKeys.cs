//----------------------------------------------------------------
//  ListKeys.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Text.RegularExpressions;
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
/// What one list of event commands reads and writes by itself, every branch counted, without the
/// common events it calls: the keys of the story it reads, the keys and self switches it sets, the
/// common events it calls and the troops it fights.
/// </summary>
public sealed partial class ListKeys
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
    /// Gets the switches the list turns on (Control Switches to on), in their order.
    /// </summary>
    public List<KeyRange> TurnsOn { get; } = [];

    /// <summary>
    /// Gets the letters of the self switches the list sets, in their order.
    /// </summary>
    public List<string> SelfSwitches { get; } = [];

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
    /// Reads what a list does.
    /// </summary>
    /// <param name="list">The commands.</param>
    /// <returns>What it reads and writes.</returns>
    public static ListKeys Of(IReadOnlyList<EventCommand> list)
    {
        var keys = new ListKeys();
        foreach (EventCommand command in list)
        {
            keys.Add(command);
        }

        return keys;
    }

    /// <summary>
    /// Reads what a map event's page does: its list and the switches and variable its conditions check.
    /// </summary>
    /// <param name="page">The page.</param>
    /// <returns>What it reads and writes.</returns>
    public static ListKeys Of(EventPage page)
    {
        ListKeys keys = Of(page.List);
        AddIf(keys.ReadSwitches, page.Condition.Switch1);
        AddIf(keys.ReadSwitches, page.Condition.Switch2);
        AddIf(keys.ReadVariables, page.Condition.Variable);
        return keys;
    }

    /// <summary>
    /// Tells whether the list reads or writes a switch or variable of a set.
    /// </summary>
    /// <param name="switches">The switches, sorted.</param>
    /// <param name="variables">The variables, sorted.</param>
    /// <returns>Whether it does.</returns>
    public bool Touches(SortedSet<long> switches, SortedSet<long> variables) =>
        ReadSwitches.Overlaps(switches) || ReadVariables.Overlaps(variables)
        || Writes.Exists(range => range.From <= range.To && (range.Variable ? variables : switches).GetViewBetween(range.From, range.To).Count > 0);

    /// <summary>
    /// Adds an id when there is one.
    /// </summary>
    /// <param name="ids">The ids.</param>
    /// <param name="id">The id, <see langword="null"/> for none.</param>
    private static void AddIf(HashSet<long> ids, long? id)
    {
        if (id is { } found)
        {
            ids.Add(found);
        }
    }

    /// <summary>
    /// Reads what one command does.
    /// </summary>
    /// <param name="command">The command.</param>
    private void Add(EventCommand command)
    {
        switch (command.Code)
        {
            case EventCodes.InputNumber or EventCodes.SelectKeyItem or EventCodes.GetLocationInfo:
                WriteVariable(command.Number(0));
                if (command.Code == EventCodes.GetLocationInfo && command.Number(2) == 1)
                {
                    ReadVariables.UnionWith([command.Number(3), command.Number(4)]);
                }

                break;
            case EventCodes.Branch:
                AddBranch(command);
                break;
            case EventCodes.CallCommonEvent:
                Calls.Add(command.Number(0));
                BattlesAndCalls.Add((true, command.Number(0)));
                break;
            case EventCodes.ControlSwitches:
                Writes.Add(new KeyRange(false, command.Number(0), command.Number(1)));
                if (command.Number(2) == 0)
                {
                    TurnsOn.Add(new KeyRange(false, command.Number(0), command.Number(1)));
                }

                break;
            case EventCodes.ControlVariables:
                Writes.Add(new KeyRange(true, command.Number(0), command.Number(1)));
                AddOperand(command, 3);
                if (command.Number(3) == 4)
                {
                    AddScript(command.Text(4));
                }

                break;
            case EventCodes.ControlSelfSwitch:
                SelfSwitches.Add(command.Text(0));
                break;
            case EventCodes.ChangeGold:
                AddOperand(command, 1);
                break;
            case EventCodes.ChangeItems or EventCodes.ChangeWeapons or EventCodes.ChangeArmors:
                AddOperand(command, 2);
                break;
            case EventCodes.TransferPlayer:
                AddPlace(command, 0, 1, 3);
                break;
            case EventCodes.SetVehicleLocation:
                AddPlace(command, 1, 2, 3);
                break;
            case EventCodes.SetEventLocation:
                AddPlace(command, 1, 2, 2);
                break;
            case EventCodes.Battle:
                if (command.Number(0) == 0)
                {
                    Troops.Add(command.Number(1));
                    BattlesAndCalls.Add((false, command.Number(1)));
                }
                else if (command.Number(0) == 1)
                {
                    ReadVariables.Add(command.Number(1));
                }

                break;
            case EventCodes.Script or EventCodes.ScriptLine:
                AddScript(command.Text(0));
                break;
        }
    }

    /// <summary>
    /// Reads a conditional branch's switch or variables.
    /// </summary>
    /// <param name="command">The branch.</param>
    private void AddBranch(EventCommand command)
    {
        switch (command.Number(0))
        {
            case 0:
                ReadSwitches.Add(command.Number(1));
                break;
            case 1:
                ReadVariables.Add(command.Number(1));
                if (command.Number(2) != 0)
                {
                    ReadVariables.Add(command.Number(3));
                }

                break;
            case 12:
                AddScript(command.Text(1));
                break;
        }
    }

    /// <summary>
    /// Reads the variable an operand names, when it names one.
    /// </summary>
    /// <param name="command">The command.</param>
    /// <param name="kind">The place of the operand's kind, 1 for a variable, the operand after it.</param>
    private void AddOperand(EventCommand command, int kind)
    {
        if (command.Number(kind) == 1)
        {
            ReadVariables.Add(command.Number(kind + 1));
        }
    }

    /// <summary>
    /// Reads the variables a place by variables names.
    /// </summary>
    /// <param name="command">The command.</param>
    /// <param name="designation">The place of its designation, 1 for variables.</param>
    /// <param name="first">The place of the first variable.</param>
    /// <param name="last">The place of the last variable.</param>
    private void AddPlace(EventCommand command, int designation, int first, int last)
    {
        if (command.Number(designation) != 1)
        {
            return;
        }

        for (int place = first; place <= last; place++)
        {
            ReadVariables.Add(command.Number(place));
        }
    }

    /// <summary>
    /// Reads the switches and variables a script names by their ids, as read or set.
    /// </summary>
    /// <param name="script">The script, or one of its lines.</param>
    private void AddScript(string script)
    {
        foreach (Match match in ScriptKey().Matches(script))
        {
            long id = long.Parse(match.Groups["id"].ValueSpan, System.Globalization.CultureInfo.InvariantCulture);
            bool variable = match.Groups["kind"].Value == "variables";
            (variable ? ReadVariables : ReadSwitches).Add(id);
            if (match.Groups["set"].Success)
            {
                Writes.Add(new KeyRange(variable, id, id));
            }
        }
    }

    /// <summary>
    /// Notes a variable the list sets.
    /// </summary>
    /// <param name="id">The variable.</param>
    private void WriteVariable(long id) => Writes.Add(new KeyRange(true, id, id));

    /// <summary>
    /// A switch or variable a script names by its id, set when an assignment follows.
    /// </summary>
    /// <returns>The pattern: its kind ("switches" or "variables"), id and whether it is set.</returns>
    [GeneratedRegex(@"\$game_(?<kind>switches|variables)\[\s*(?<id>[0-9]{1,9})\s*\](?<set>\s*(?:[-+*/%|&]|<<|>>|\|\||&&)?=(?!=))?", RegexOptions.CultureInvariant)]
    private static partial Regex ScriptKey();
}
