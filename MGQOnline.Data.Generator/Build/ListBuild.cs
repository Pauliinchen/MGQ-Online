//----------------------------------------------------------------
//  ListBuild.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Read the side switches from StoryIds
//      Paulinchen  2026-11-01: Handed on each list's extended choices
//      Paulinchen  2026-10-31: Handed each list's script roots on
//                            - Handed on what each list's scripts do to self switches
//                            - Handed on each list's scripts that touch what a player holds
//      Paulinchen  2026-10-28: Moved the folder rule of transfers to the game data paths
//                            - Handed each list on to the derived rows
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;
using MGQOnline.Game.Story;

namespace MGQOnline.Data.Generator.Build;

/// <summary>
/// Turns one list of event commands as the game runs it into its rows: the list's row with its
/// count and shape, its kept commands with their place among the kept (ord) and in the list (idx),
/// and what it reads and writes by itself.
/// </summary>
internal static class ListBuild
{
    /// <summary>
    /// Change Tileset, whose tileset the Raid Designer reads.
    /// </summary>
    private const int ChangeTileset = 282;

    /// <summary>
    /// The side switches, as the branches around battles and transfers name them.
    /// </summary>
    private static readonly IReadOnlySet<long> SideSwitches = StoryIds.SideSwitches.Select(side => (long)side).ToHashSet();

    /// <summary>
    /// Finds the shape of a list, see <see cref="ListShape"/>.
    /// </summary>
    /// <param name="list">The commands as the game runs them.</param>
    /// <returns>The shape.</returns>
    public static int ShapeOf(IReadOnlyList<RawCommand> list)
    {
        int shape = 0;
        foreach (RawCommand command in list)
        {
            if (EventSchema.Keeps(command.Code))
            {
                shape = ListShape.AddCommand(shape, command.Code, command.Indent, IntegersOf(command.Parameters));
            }
        }

        return shape;
    }

    /// <summary>
    /// Adds a list's rows.
    /// </summary>
    /// <param name="rows">The rows to add to.</param>
    /// <param name="site">The list's row, its count, kept count and shape still to fill.</param>
    /// <param name="list">The commands as the game runs them.</param>
    /// <param name="condition">The conditions of the list's page, which it reads too: a map page's, or a troop page's switch; <see langword="null"/> for none.</param>
    /// <param name="triggerSwitch">The switch that starts a common event by itself, <see langword="null"/> for none.</param>
    /// <returns>The list as the derived rows read it.</returns>
    public static BuiltList Add(EventRows rows, ListRow site, IReadOnlyList<RawCommand> list, PageCondition? condition, int? triggerSwitch)
    {
        EventCommand[] commands = CommandClassifier.Classify(list);
        int[] ords = OrdsOf(list);
        int[] owners = OwnersOf(list);
        int listId = site.ListId;
        rows.Lists.Add(site with { CountAll = list.Count, CountKept = ords.Count(ord => ord >= 0), Shape = ShapeOf(list) });
        AddCommands(rows, listId, commands, ords);

        ListRows found = condition is null ? ListRows.Of(commands) : ListRows.Of(new EventPage(condition, 0, commands));
        AddReads(rows, listId, found.Reads, triggerSwitch);
        var writes = new HashSet<(int Ord, KeyKind Kind, int From)>();
        foreach (ListWrite write in found.Writes)
        {
            int owner = owners[write.Place];
            KeyKind kind = write.Range.Variable ? KeyKind.Variable : KeyKind.Switch;
            if (writes.Add((ords[owner], kind, (int)write.Range.From)))
            {
                rows.ListWrites.Add(new ListWriteRow(listId, ords[owner], owner, kind, (int)write.Range.From, (int)write.Range.To, write.TurnsOn, write.ByScript, write.Value is { } value ? checked((int)value) : null));
            }
        }

        rows.ListSelfSwitches.AddRange(found.SelfSwitches.Select(selfSwitch => new ListSelfSwitchRow(listId, ords[selfSwitch.Place], selfSwitch.Place, selfSwitch.Letter, selfSwitch.TurnsOn)));
        rows.ListCalls.AddRange(found.Calls.Select(call => new ListCallRow(listId, ords[call.Place], call.Place, (int)call.CommonId)));
        AddBattles(rows, listId, list, commands, ords);
        AddTransfers(rows, site, commands, ords);
        for (int idx = 0; idx < commands.Length; idx++)
        {
            if (commands[idx].Code == ChangeTileset)
            {
                rows.ListTilesets.Add(new ListTilesetRow(listId, idx, (int)commands[idx].Number(0)));
            }
        }

        (List<ForcedTransfer> forced, List<int> scriptSwitches) = ScriptTexts.Of(list);
        return new BuiltList(rows.Lists[^1], commands, forced, scriptSwitches, ScriptRoots.In(list), ScriptTexts.SelfSwitchesOf(list), Gives.ScriptsOf(list), ChoiceAsks.ExChoicesOf(list));
    }

    /// <summary>
    /// Numbers the kept commands of a list in their order.
    /// </summary>
    /// <param name="list">The commands.</param>
    /// <returns>Each command's place among the kept, -1 for one the database does not keep.</returns>
    private static int[] OrdsOf(IReadOnlyList<RawCommand> list)
    {
        var ords = new int[list.Count];
        int next = 0;
        for (int idx = 0; idx < list.Count; idx++)
        {
            ords[idx] = EventSchema.Keeps(list[idx].Code) ? next++ : -1;
        }

        return ords;
    }

    /// <summary>
    /// Finds the kept command each command's rows belong to: its own, or for a script's continuation
    /// line the kept command before it, which is its script.
    /// </summary>
    /// <param name="list">The commands.</param>
    /// <returns>Each command's owner by its place in the list; a command with no kept command before it owns itself.</returns>
    private static int[] OwnersOf(IReadOnlyList<RawCommand> list)
    {
        var owners = new int[list.Count];
        int last = -1;
        for (int idx = 0; idx < list.Count; idx++)
        {
            last = EventSchema.Keeps(list[idx].Code) ? idx : last;
            owners[idx] = last >= 0 ? last : idx;
        }

        return owners;
    }

    /// <summary>
    /// Adds the kept commands' rows, a jump's label place turned into the label's ord.
    /// </summary>
    /// <param name="rows">The rows.</param>
    /// <param name="listId">The list.</param>
    /// <param name="commands">The commands, classified.</param>
    /// <param name="ords">Each command's ord, see <see cref="OrdsOf"/>.</param>
    private static void AddCommands(EventRows rows, int listId, EventCommand[] commands, int[] ords)
    {
        for (int idx = 0; idx < commands.Length; idx++)
        {
            if (ords[idx] < 0)
            {
                continue;
            }

            EventCommand command = commands[idx];
            long first = command.Number(0);
            if (command.Code == EventCodes.JumpToLabel)
            {
                first = first >= 0 ? ords[first] : -1;
            }

            rows.Commands.Add(new CommandRow(
                listId,
                ords[idx],
                idx,
                command.Code,
                command.Indent,
                first,
                command.Number(1),
                command.Number(2),
                command.Number(3),
                command.Number(4),
                command.Number(5),
                (int)command.TextKind));
        }
    }

    /// <summary>
    /// Adds the switches and variables a list reads, and a common event's own switch.
    /// </summary>
    /// <param name="rows">The rows.</param>
    /// <param name="listId">The list.</param>
    /// <param name="reads">What the list's commands and conditions read.</param>
    /// <param name="triggerSwitch">The switch that starts a common event by itself, <see langword="null"/> for none.</param>
    private static void AddReads(EventRows rows, int listId, IReadOnlyList<ListRead> reads, int? triggerSwitch)
    {
        var sources = new SortedDictionary<(KeyKind Kind, int Id), ReadSources>();
        foreach (ListRead read in reads)
        {
            sources[(read.Variable ? KeyKind.Variable : KeyKind.Switch, (int)read.Id)] = read.Sources;
        }

        if (triggerSwitch is { } own)
        {
            sources[(KeyKind.Switch, own)] = sources.GetValueOrDefault((KeyKind.Switch, own)) | ReadSources.TriggerSwitch;
        }

        rows.ListReads.AddRange(sources.Select(read => new ListReadRow(listId, read.Key.Kind, read.Key.Id, read.Value)));
    }

    /// <summary>
    /// Adds the battles a list starts, numbered among its battle commands; one against the troop of
    /// the map's random encounters has no troop and no row, but keeps its number.
    /// </summary>
    /// <param name="rows">The rows.</param>
    /// <param name="listId">The list.</param>
    /// <param name="list">The commands as read, whose flags the classified commands read as 0.</param>
    /// <param name="commands">The commands, classified.</param>
    /// <param name="ords">Each command's ord.</param>
    private static void AddBattles(EventRows rows, int listId, IReadOnlyList<RawCommand> list, EventCommand[] commands, int[] ords)
    {
        int battleNo = 0;
        for (int idx = 0; idx < commands.Length; idx++)
        {
            EventCommand command = commands[idx];
            if (command.Code != EventCodes.Battle)
            {
                continue;
            }

            if (command.Number(0) is 0 or 1)
            {
                rows.ListBattles.Add(new ListBattleRow(
                    listId,
                    ords[idx],
                    idx,
                    battleNo,
                    (int)command.Number(1),
                    command.Number(0) == 1,
                    IsTrue(list[idx].Parameters, 2),
                    IsTrue(list[idx].Parameters, 3),
                    command.Indent,
                    RaidRules.PreambleStart(commands, idx),
                    SideSwitchOf(commands, idx)));
            }

            battleNo++;
        }
    }

    /// <summary>
    /// Adds the transfers of the player a list makes; a map page's into its map's folder.
    /// </summary>
    /// <param name="rows">The rows.</param>
    /// <param name="site">The list's row.</param>
    /// <param name="commands">The commands, classified.</param>
    /// <param name="ords">Each command's ord.</param>
    private static void AddTransfers(EventRows rows, ListRow site, EventCommand[] commands, int[] ords)
    {
        for (int idx = 0; idx < commands.Length; idx++)
        {
            EventCommand command = commands[idx];
            if (command.Code == EventCodes.TransferPlayer)
            {
                int map = (int)command.Number(1);
                bool byVariable = command.Number(0) == 1;
                rows.ListTransfers.Add(new ListTransferRow(
                    site.ListId,
                    ords[idx],
                    idx,
                    !byVariable && site.Kind == ListKind.Page ? GameDataPaths.TransferMap(map, site.MapId!.Value) : map,
                    (int)command.Number(2),
                    (int)command.Number(3),
                    (int)command.Number(4),
                    byVariable,
                    SideSwitchOf(commands, idx)));
            }
        }
    }

    /// <summary>
    /// Finds the side switch of the innermost branch around a command.
    /// </summary>
    /// <param name="commands">The commands.</param>
    /// <param name="idx">The command's place.</param>
    /// <returns>The side switch, <see langword="null"/> for none.</returns>
    private static int? SideSwitchOf(EventCommand[] commands, int idx) =>
        CommandClassifier.EnclosingSwitch(commands, idx, SideSwitches) is { } side ? (int)side : null;

    /// <summary>
    /// Tells whether a parameter is true, as Ruby takes any value but nil and false.
    /// </summary>
    /// <param name="parameters">The parameters.</param>
    /// <param name="index">The parameter's place.</param>
    /// <returns>Whether it is; <see langword="false"/> for a parameter that is missing.</returns>
    private static bool IsTrue(RubyArray parameters, int index) => index < parameters.Count && parameters[index] is not (RubyNil or RubyBool { Flag: false });

    /// <summary>
    /// Picks the parameters that are Integers in Ruby, as the shape hashes them; one too large for 64
    /// bits by the low bits the shape keeps of it.
    /// </summary>
    /// <param name="parameters">The parameters.</param>
    /// <returns>The whole numbers, in order.</returns>
    private static long[] IntegersOf(RubyArray parameters)
    {
        var integers = new List<long>(parameters.Count);
        foreach (RubyValue value in parameters)
        {
            if (value is RubyInteger integer)
            {
                integers.Add(integer.Value >= long.MinValue && integer.Value <= long.MaxValue ? (long)integer.Value : (long)(integer.Value & ListShape.Mask));
            }
        }

        return [.. integers];
    }
}
