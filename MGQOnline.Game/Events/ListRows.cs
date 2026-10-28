//----------------------------------------------------------------
//  ListRows.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Read the rows of a list from the events database
//                            - Kept where each key is read and script writes
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Game.Events;

/// <summary>
/// A switch or variable a list reads.
/// </summary>
/// <param name="Variable">Whether it is a variable, else a switch.</param>
/// <param name="Id">Its id.</param>
/// <param name="Sources">Where the list reads it.</param>
public readonly record struct ListRead(bool Variable, long Id, ReadSources Sources);

/// <summary>
/// A range of switches or variables a command of a list sets.
/// </summary>
/// <param name="Place">The command's place in the list.</param>
/// <param name="Range">The range.</param>
/// <param name="TurnsOn">Whether the command turns the range's switches on.</param>
/// <param name="ByScript">Whether the command's script sets it.</param>
/// <param name="Value">The value a Control Variables command sets the range to when it sets a constant; <see langword="null"/> for any other operation, operand or command.</param>
public readonly record struct ListWrite(int Place, KeyRange Range, bool TurnsOn, bool ByScript, long? Value);

/// <summary>
/// A self switch a command of a list sets.
/// </summary>
/// <param name="Place">The command's place in the list.</param>
/// <param name="Letter">The self switch's letter, such as "A".</param>
/// <param name="TurnsOn">Whether the command turns it on, else off.</param>
public readonly record struct ListSelfSwitch(int Place, string Letter, bool TurnsOn);

/// <summary>
/// A common event a command of a list calls.
/// </summary>
/// <param name="Place">The command's place in the list.</param>
/// <param name="CommonId">The common event.</param>
public readonly record struct ListCall(int Place, long CommonId);

/// <summary>
/// A troop a command of a list fights by its id.
/// </summary>
/// <param name="Place">The command's place in the list.</param>
/// <param name="TroopId">The troop.</param>
public readonly record struct ListBattle(int Place, long TroopId);

/// <summary>
/// A map a Transfer Player command of a list moves the player to by a constant.
/// </summary>
/// <param name="Place">The command's place in the list.</param>
/// <param name="MapId">The map, by the number the command holds.</param>
public readonly record struct ListTransfer(int Place, long MapId);

/// <summary>
/// What one list of event commands reads and writes by itself, as rows that keep each command's
/// place: the form the events database stores, from which <see cref="ListKeys"/> is built.
/// </summary>
/// <param name="Reads">The switches and variables read, each once, in the order first read.</param>
/// <param name="Writes">The ranges set, in their order.</param>
/// <param name="SelfSwitches">The self switches set, in their order.</param>
/// <param name="Calls">The common events called, in their order.</param>
/// <param name="Battles">The troops fought by their ids, in their order.</param>
/// <param name="Transfers">The maps the player is transferred to by a constant, in their order.</param>
public sealed record ListRows(
    IReadOnlyList<ListRead> Reads,
    IReadOnlyList<ListWrite> Writes,
    IReadOnlyList<ListSelfSwitch> SelfSwitches,
    IReadOnlyList<ListCall> Calls,
    IReadOnlyList<ListBattle> Battles,
    IReadOnlyList<ListTransfer> Transfers)
{
    /// <summary>
    /// Reads the rows of a list, every branch counted.
    /// </summary>
    /// <param name="list">The commands.</param>
    /// <returns>The rows.</returns>
    public static ListRows Of(IReadOnlyList<EventCommand> list)
    {
        var builder = new Builder();
        for (int place = 0; place < list.Count; place++)
        {
            builder.Add(list[place], place);
        }

        return builder.Rows();
    }

    /// <summary>
    /// Reads the rows of a map event's page: its list and the switches and variable its conditions check.
    /// </summary>
    /// <param name="page">The page.</param>
    /// <returns>The rows.</returns>
    public static ListRows Of(EventPage page)
    {
        var builder = new Builder();
        builder.ReadCondition(false, page.Condition.Switch1);
        builder.ReadCondition(false, page.Condition.Switch2);
        builder.ReadCondition(true, page.Condition.Variable);
        for (int place = 0; place < page.List.Count; place++)
        {
            builder.Add(page.List[place], place);
        }

        return builder.Rows();
    }

    /// <summary>
    /// Reads the rows of a list as the events database holds them, each command's place its place
    /// among the kept commands.
    /// </summary>
    /// <param name="rows">The database's rows of the list.</param>
    /// <param name="runningMap">The map of a page's event, whose folder the database resolved the page's transfers into; 0 for a common event or a troop page.</param>
    /// <returns>The rows, a transfer's map by the number its command holds, as <see cref="Of(IReadOnlyList{EventCommand})"/> reads it.</returns>
    public static ListRows Of(ListRowSet rows, int runningMap)
    {
        int folder = GameDataPaths.TransferMap(0, runningMap);
        return new ListRows(
            [.. rows.Reads.Select(read => new ListRead(read.Kind == KeyKind.Variable, read.Id, read.Sources))],
            [.. rows.Writes.Select(write => new ListWrite(write.Ord, new KeyRange(write.Kind == KeyKind.Variable, write.FromId, write.ToId), write.TurnsOn, write.ByScript, write.Value))],
            [.. rows.SelfSwitches.Select(selfSwitch => new ListSelfSwitch(selfSwitch.Ord, selfSwitch.Letter, selfSwitch.TurnsOn))],
            [.. rows.Calls.Select(call => new ListCall(call.Ord, call.CommonId))],
            [.. rows.Battles.Where(battle => !battle.ByVariable).Select(battle => new ListBattle(battle.Ord, battle.TroopId))],
            [.. rows.Transfers.Where(transfer => !transfer.ByVariable).Select(transfer => new ListTransfer(transfer.Ord, transfer.MapId - folder))]);
    }

    /// <summary>
    /// Leaves out the switch that starts a common event, which the database counts among its list's
    /// reads and the list alone does not read.
    /// </summary>
    /// <returns>The rows without it.</returns>
    public ListRows WithoutTriggerSwitch() => this with { Reads = [.. Reads.Where(read => read.Sources != ReadSources.TriggerSwitch)] };

    /// <summary>
    /// Collects the rows of one list, command by command.
    /// </summary>
    private sealed class Builder
    {
        /// <summary>
        /// The reads, in the order first met.
        /// </summary>
        private readonly List<ListRead> _reads = [];

        /// <summary>
        /// The place in the reads of each key read so far, where a second read of it adds its source.
        /// </summary>
        private readonly Dictionary<(bool Variable, long Id), int> _seen = [];

        /// <summary>
        /// The writes.
        /// </summary>
        private readonly List<ListWrite> _writes = [];

        /// <summary>
        /// The self switches set.
        /// </summary>
        private readonly List<ListSelfSwitch> _selfSwitches = [];

        /// <summary>
        /// The calls.
        /// </summary>
        private readonly List<ListCall> _calls = [];

        /// <summary>
        /// The battles against a troop by its id.
        /// </summary>
        private readonly List<ListBattle> _battles = [];

        /// <summary>
        /// The transfers to a map by a constant.
        /// </summary>
        private readonly List<ListTransfer> _transfers = [];

        /// <summary>
        /// Gives the rows collected.
        /// </summary>
        /// <returns>The rows.</returns>
        public ListRows Rows() => new(_reads, _writes, _selfSwitches, _calls, _battles, _transfers);

        /// <summary>
        /// Notes a page condition's read when there is one.
        /// </summary>
        /// <param name="variable">Whether it is a variable.</param>
        /// <param name="id">The id, <see langword="null"/> for none.</param>
        public void ReadCondition(bool variable, long? id)
        {
            if (id is { } found)
            {
                Read(variable, found, ReadSources.Condition);
            }
        }

        /// <summary>
        /// Reads what one command does.
        /// </summary>
        /// <param name="command">The command.</param>
        /// <param name="place">Its place in the list.</param>
        public void Add(EventCommand command, int place)
        {
            switch (command.Code)
            {
                case EventCodes.InputNumber or EventCodes.SelectKeyItem or EventCodes.GetLocationInfo:
                    Write(place, true, command.Number(0), command.Number(0), false);
                    if (command.Code == EventCodes.GetLocationInfo && command.Number(2) == 1)
                    {
                        Read(true, command.Number(3), ReadSources.Place);
                        Read(true, command.Number(4), ReadSources.Place);
                    }

                    break;
                case EventCodes.Branch:
                    AddBranch(command);
                    break;
                case EventCodes.CallCommonEvent:
                    _calls.Add(new ListCall(place, command.Number(0)));
                    break;
                case EventCodes.ControlSwitches:
                    _writes.Add(new ListWrite(place, new KeyRange(false, command.Number(0), command.Number(1)), command.Number(2) == 0, false, null));
                    break;
                case EventCodes.ControlVariables:
                    _writes.Add(new ListWrite(place, new KeyRange(true, command.Number(0), command.Number(1)), false, false, ConstantSet(command)));
                    AddOperand(command, 3);
                    break;
                case EventCodes.ControlSelfSwitch:
                    _selfSwitches.Add(new ListSelfSwitch(place, CommandClassifier.LetterOf(command.Number(0)), command.Number(1) == 0));
                    break;
                case EventCodes.ChangeGold:
                    AddOperand(command, 1);
                    break;
                case EventCodes.ChangeItems or EventCodes.ChangeWeapons or EventCodes.ChangeArmors:
                    AddOperand(command, 2);
                    break;
                case EventCodes.TransferPlayer:
                    AddPlace(command, 0, 1, 3);
                    if (command.Number(0) == 0)
                    {
                        _transfers.Add(new ListTransfer(place, command.Number(1)));
                    }

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
                        _battles.Add(new ListBattle(place, command.Number(1)));
                    }
                    else if (command.Number(0) == 1)
                    {
                        Read(true, command.Number(1), ReadSources.TroopByVariable);
                    }

                    break;
            }

            foreach (ScriptKey key in command.ScriptKeys)
            {
                Read(key.Variable, key.Id, ReadSources.Script);
                if (key.Set)
                {
                    Write(place, key.Variable, key.Id, key.Id, true);
                }
            }
        }

        /// <summary>
        /// Notes a read, once per key with every source it is read from.
        /// </summary>
        /// <param name="variable">Whether it is a variable.</param>
        /// <param name="id">The id.</param>
        /// <param name="source">Where it is read.</param>
        private void Read(bool variable, long id, ReadSources source)
        {
            if (_seen.TryGetValue((variable, id), out int index))
            {
                _reads[index] = _reads[index] with { Sources = _reads[index].Sources | source };
                return;
            }

            _seen[(variable, id)] = _reads.Count;
            _reads.Add(new ListRead(variable, id, source));
        }

        /// <summary>
        /// Notes a range set that turns nothing on, to a value known only as the list runs.
        /// </summary>
        /// <param name="place">The command's place.</param>
        /// <param name="variable">Whether the range is of variables.</param>
        /// <param name="from">The first id.</param>
        /// <param name="to">The last id.</param>
        /// <param name="byScript">Whether a script sets it.</param>
        private void Write(int place, bool variable, long from, long to, bool byScript) =>
            _writes.Add(new ListWrite(place, new KeyRange(variable, from, to), false, byScript, null));

        /// <summary>
        /// Reads the value a Control Variables command sets when it sets a constant.
        /// </summary>
        /// <param name="command">The command: its operation third (0 sets), its operand's kind fourth (0 for a constant), the constant fifth.</param>
        /// <returns>The constant, <see langword="null"/> for another operation or operand.</returns>
        private static long? ConstantSet(EventCommand command) => command.Number(2) == 0 && command.Number(3) == 0 ? command.Number(4) : null;

        /// <summary>
        /// Reads a conditional branch's switch or variables.
        /// </summary>
        /// <param name="command">The branch.</param>
        private void AddBranch(EventCommand command)
        {
            switch (command.Number(0))
            {
                case 0:
                    Read(false, command.Number(1), ReadSources.Branch);
                    break;
                case 1:
                    Read(true, command.Number(1), ReadSources.Branch);
                    if (command.Number(2) != 0)
                    {
                        Read(true, command.Number(3), ReadSources.Branch);
                    }

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
                Read(true, command.Number(kind + 1), ReadSources.Operand);
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
                Read(true, command.Number(place), ReadSources.Place);
            }
        }
    }
}
