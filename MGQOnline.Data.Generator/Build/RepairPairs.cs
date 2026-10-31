//----------------------------------------------------------------
//  RepairPairs.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Data.Generator.Build;

/// <summary>
/// The pairs the one-time repair of saves stuck by the 0.6.9.2 chest path may complete ("Issue 73
/// chest effects.md", E2): a gift page whose self switch K, once on, proves its switch S on, since
/// the page turns S on in the same block as K with nothing between them that leaves it, or inside
/// "if S is OFF" before K. The gates keep every save the plain game made unchanged: nothing else
/// turns K on (no other page of its event, no common event its event calls, no script); every list
/// that turns S off resets K's map with it; and no game script or database entry uses S as a switch.
/// </summary>
internal static class RepairPairs
{
    /// <summary>
    /// The commands that leave a list or a block before what follows runs: exit, break the loop, jump
    /// to a label, a battle that may end in a defeat, game over and return to the title.
    /// </summary>
    private static readonly HashSet<int> Leaving = [113, 115, EventCodes.JumpToLabel, EventCodes.Battle, EventCodes.GameOver, EventCodes.ReturnToTitle];

    /// <summary>
    /// The conditional branch's type that tests a switch.
    /// </summary>
    private const long SwitchBranch = 0;

    /// <summary>
    /// The value a switch branch tests for OFF.
    /// </summary>
    private const long Off = 1;

    /// <summary>
    /// Finds the pairs of the game.
    /// </summary>
    /// <param name="game">The game read.</param>
    /// <param name="uses">The switches the game's scripts and database use as switches.</param>
    /// <returns>The pairs, by site, letter and switch.</returns>
    public static IReadOnlyList<RepairPairRow> Of(BuiltGame game, SwitchUses uses)
    {
        ArgumentNullException.ThrowIfNull(game);
        ArgumentNullException.ThrowIfNull(uses);
        var pages = game.Lists.Where(list => list.Site.Kind == ListKind.Page).Select(list => (List: list, Page: game.PageOf(list))).ToList();
        var byEvent = pages.ToLookup(page => (page.Page.MapId, page.Page.EventId));
        List<SwitchOff> offs = [.. game.Lists.SelectMany(OffsOf)];
        HashSet<(int? Map, int? Event, string Letter)> scripted = [.. game.Lists.SelectMany(list => list.SelfSwitchScripts.TurnedOn).Select(write => (write.MapId, write.EventId, write.Letter))];
        var rows = new List<RepairPairRow>();
        foreach ((BuiltList list, PageRow page) in pages.Where(page => Gives(game, page.List)))
        {
            EventCommand[] commands = list.Commands;
            foreach (string letter in LettersOn(commands).Distinct())
            {
                int[] closes = [.. Enumerable.Range(0, commands.Length).Where(index => TurnsOn(commands[index], letter))];
                foreach (int id in SwitchesOn(commands).Distinct())
                {
                    if (closes.All(close => Certain(commands, close, id)) && !uses.Uses(id) && OnlyWriter(game, byEvent[(page.MapId, page.EventId)], page, letter, scripted)
                        && offs.Where(off => off.Covers(id)).All(off => off.Resets(page.MapId)))
                    {
                        rows.Add(new RepairPairRow(page.MapId, page.EventId, page.PageNo, letter, id));
                    }
                }
            }
        }

        return rows;
    }

    /// <summary>
    /// Tells whether S is on whenever the command that turns K on ran: S turned on in the same block
    /// before or after it, or at the top of an "if S is OFF" of its block before or after it, with
    /// nothing between that leaves the block.
    /// </summary>
    /// <param name="commands">The page's commands.</param>
    /// <param name="close">The place of the command that turns K on.</param>
    /// <param name="id">S.</param>
    /// <returns>Whether it is.</returns>
    private static bool Certain(EventCommand[] commands, int close, int id)
    {
        int indent = commands[close].Indent;
        for (int at = 0; at < commands.Length; at++)
        {
            if (!TurnsOnSwitch(commands[at], id))
            {
                continue;
            }

            if (commands[at].Indent == indent && Stays(commands, Math.Min(at, close), Math.Max(at, close), indent))
            {
                return true;
            }

            int branch = Array.FindLastIndex(commands, at, command => command.Indent < commands[at].Indent);
            if (branch >= 0 && IsOffBranch(commands[branch], id) && commands[branch].Indent == indent && commands[at].Indent == indent + 1
                && Stays(commands, branch, at, indent + 1) && Stays(commands, Math.Min(branch, close), Math.Max(branch, close), indent))
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>
    /// Tells whether every command between two places stays in the block of an indent and none
    /// leaves it.
    /// </summary>
    /// <param name="commands">The commands.</param>
    /// <param name="from">The first place, left out.</param>
    /// <param name="to">The last place, left out.</param>
    /// <param name="indent">The block's indent.</param>
    /// <returns>Whether they do.</returns>
    private static bool Stays(EventCommand[] commands, int from, int to, int indent)
    {
        for (int at = from + 1; at < to; at++)
        {
            if (commands[at].Indent < indent || Leaving.Contains(commands[at].Code))
            {
                return false;
            }
        }

        return true;
    }

    /// <summary>
    /// Tells whether nothing but the page turns K on: no other page of its event, no common event a
    /// page of its event calls (which writes the calling event's self switch), and no script, by K's
    /// key or as the running event's, nor a script of the event that writes a self switch its text
    /// does not name.
    /// </summary>
    /// <param name="game">The game read.</param>
    /// <param name="eventPages">The pages of K's event.</param>
    /// <param name="page">The page.</param>
    /// <param name="letter">K's letter.</param>
    /// <param name="scripted">The self switches scripts turn on by their keys.</param>
    /// <returns>Whether it does.</returns>
    private static bool OnlyWriter(BuiltGame game, IEnumerable<(BuiltList List, PageRow Page)> eventPages, PageRow page, string letter, HashSet<(int? Map, int? Event, string Letter)> scripted)
    {
        foreach ((BuiltList list, PageRow other) in eventPages)
        {
            if (other.PageNo != page.PageNo && (LettersOn(list.Commands).Contains(letter) || WritesBound(list, letter)))
            {
                return false;
            }

            if (Called(game, list).Any(common => LettersOn(common.Commands).Contains(letter) || WritesBound(common, letter)))
            {
                return false;
            }
        }

        return !scripted.Contains((page.MapId, page.EventId, letter));
    }

    /// <summary>
    /// Tells whether a list's scripts turn a letter of the running event on, or write a self switch
    /// their text does not name.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="letter">The letter.</param>
    /// <returns>Whether they do.</returns>
    private static bool WritesBound(BuiltList list, string letter) =>
        list.SelfSwitchScripts.Unnamed || list.SelfSwitchScripts.TurnedOn.Any(write => write.MapId is null && write.EventId is null && write.Letter == letter);

    /// <summary>
    /// Lists the common events a list calls, through the common events they call too.
    /// </summary>
    /// <param name="game">The game read.</param>
    /// <param name="list">The list.</param>
    /// <returns>The common events' lists, each once.</returns>
    private static IEnumerable<BuiltList> Called(BuiltGame game, BuiltList list)
    {
        var seen = new HashSet<long>();
        var next = new Queue<long>(BuiltGame.CallsOf(list));
        while (next.TryDequeue(out long id))
        {
            if (!seen.Add(id) || game.CommonListOf(id) is not { } common)
            {
                continue;
            }

            yield return common;
            foreach (long called in BuiltGame.CallsOf(common))
            {
                next.Enqueue(called);
            }
        }
    }

    /// <summary>
    /// Tells whether a page gives what the 0.6.9.2 chest path handed over: items, weapons, armors or
    /// gold, itself or in the common events it calls.
    /// </summary>
    /// <param name="game">The game read.</param>
    /// <param name="list">The page.</param>
    /// <returns>Whether it does.</returns>
    private static bool Gives(BuiltGame game, BuiltList list) =>
        list.Commands.Any(GivesAny) || Called(game, list).Any(common => common.Commands.Any(GivesAny));

    /// <summary>
    /// Tells whether a command gives gold, an item, a weapon or an armor.
    /// </summary>
    /// <param name="command">The command.</param>
    /// <returns>Whether it does.</returns>
    private static bool GivesAny(EventCommand command) => command.Code switch
    {
        EventCodes.ChangeGold => command.Number(0) == 0,
        EventCodes.ChangeItems or EventCodes.ChangeWeapons or EventCodes.ChangeArmors => command.Number(1) == 0,
        _ => false,
    };

    /// <summary>
    /// Lists the letters a list's Control Self Switch commands turn on.
    /// </summary>
    /// <param name="commands">The commands.</param>
    /// <returns>The letters, as often as turned on.</returns>
    private static IEnumerable<string> LettersOn(EventCommand[] commands) =>
        commands.Where(command => command.Code == EventCodes.ControlSelfSwitch && command.Number(1) == 0).Select(command => CommandClassifier.LetterOf(command.Number(0)));

    /// <summary>
    /// Tells whether a command turns a letter on.
    /// </summary>
    /// <param name="command">The command.</param>
    /// <param name="letter">The letter.</param>
    /// <returns>Whether it does.</returns>
    private static bool TurnsOn(EventCommand command, string letter) =>
        command.Code == EventCodes.ControlSelfSwitch && command.Number(1) == 0 && CommandClassifier.LetterOf(command.Number(0)) == letter;

    /// <summary>
    /// Lists the switches a list's Control Switches commands turn on.
    /// </summary>
    /// <param name="commands">The commands.</param>
    /// <returns>The switches.</returns>
    private static IEnumerable<int> SwitchesOn(EventCommand[] commands) =>
        commands.Where(command => command.Code == EventCodes.ControlSwitches && command.Number(2) == 0)
            .SelectMany(command => Enumerable.Range((int)command.Number(0), (int)Math.Max(0, command.Number(1) - command.Number(0) + 1)));

    /// <summary>
    /// Tells whether a command turns a switch on.
    /// </summary>
    /// <param name="command">The command.</param>
    /// <param name="id">The switch.</param>
    /// <returns>Whether it does.</returns>
    private static bool TurnsOnSwitch(EventCommand command, int id) =>
        command.Code == EventCodes.ControlSwitches && command.Number(2) == 0 && command.Number(0) <= id && command.Number(1) >= id;

    /// <summary>
    /// Tells whether a command is "if the switch is OFF".
    /// </summary>
    /// <param name="command">The command.</param>
    /// <param name="id">The switch.</param>
    /// <returns>Whether it is.</returns>
    private static bool IsOffBranch(EventCommand command, int id) =>
        command.Code == EventCodes.Branch && command.Number(0) == SwitchBranch && command.Number(1) == id && command.Number(2) == Off;

    /// <summary>
    /// Lists where a list may turn switches off: a Control Switches command off, and a script that
    /// sets a switch, with the self switches the list resets.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>Each range it may turn off.</returns>
    private static IEnumerable<SwitchOff> OffsOf(BuiltList list)
    {
        ScriptSelfSwitches resets = list.SelfSwitchScripts;
        foreach (EventCommand command in list.Commands)
        {
            if (command.Code == EventCodes.ControlSwitches && command.Number(2) != 0)
            {
                yield return new SwitchOff((int)command.Number(0), (int)command.Number(1), resets);
            }

            foreach (ScriptKey key in command.ScriptKeys.Where(key => !key.Variable && key.Set))
            {
                yield return new SwitchOff((int)key.Id, (int)key.Id, resets);
            }
        }
    }

    /// <summary>
    /// A range of switches a list may turn off, with the self switches it resets.
    /// </summary>
    /// <param name="From">The first switch.</param>
    /// <param name="To">The last switch.</param>
    /// <param name="Scripts">What the list's scripts do to self switches.</param>
    private readonly record struct SwitchOff(int From, int To, ScriptSelfSwitches Scripts)
    {
        /// <summary>
        /// Tells whether the range holds a switch.
        /// </summary>
        /// <param name="id">The switch.</param>
        /// <returns>Whether it does.</returns>
        public bool Covers(int id) => id >= From && id <= To;

        /// <summary>
        /// Tells whether the list resets a map's self switches too.
        /// </summary>
        /// <param name="map">The map.</param>
        /// <returns>Whether it does.</returns>
        public bool Resets(int map) => Scripts.ResetsAll || Scripts.ResetMaps.Contains(map);
    }
}
