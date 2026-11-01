//----------------------------------------------------------------
//  BuiltList.cs
//
//  Changelog:
//      Paulinchen  2026-11-01: Carried its extended choices
//      Paulinchen  2026-10-31: Carried the roots of its scripts for the story replay's gate
//                            - Carried its scripts that touch what a player holds
//                            - Carried what its scripts do to self switches for the repair of stuck saves
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Data.Generator.Build;

/// <summary>
/// A transfer a script makes at once, as the game's post-defeat processing does.
/// </summary>
/// <param name="Idx">The script line's place in the list.</param>
/// <param name="MapId">The map it leads to.</param>
/// <param name="X">Where across.</param>
/// <param name="Y">Where down.</param>
internal readonly record struct ForcedTransfer(int Idx, int MapId, int X, int Y);

/// <summary>
/// A self switch a list's script turns on: one named by its map, event and letter, or by its letter
/// alone for the event that runs the list.
/// </summary>
/// <param name="MapId">The map, <see langword="null"/> for the running event's.</param>
/// <param name="EventId">The event, <see langword="null"/> for the running event.</param>
/// <param name="Letter">The letter.</param>
internal readonly record struct ScriptSelfSwitch(int? MapId, int? EventId, string Letter);

/// <summary>
/// What a list's scripts do to self switches: those they turn on, whether they write one the text
/// does not name, and the maps whose self switches they reset (script 167's reset_selfswitch_map)
/// or whether they make every self switch anew (<c>Game_SelfSwitches.new</c>).
/// </summary>
/// <param name="TurnedOn">The self switches they turn on.</param>
/// <param name="Unnamed">Whether they write a self switch the text does not name.</param>
/// <param name="ResetMaps">The maps whose self switches they reset.</param>
/// <param name="ResetsAll">Whether they make every self switch anew.</param>
internal sealed record ScriptSelfSwitches(IReadOnlyList<ScriptSelfSwitch> TurnedOn, bool Unnamed, IReadOnlyList<int> ResetMaps, bool ResetsAll)
{
    /// <summary>
    /// A list whose scripts touch no self switch.
    /// </summary>
    public static readonly ScriptSelfSwitches None = new([], false, [], false);
}

/// <summary>
/// One list the build read, kept until the derived rows are made: its row, its commands as the
/// rules read them, and what its scripts' texts tell, which the commands no longer hold.
/// </summary>
/// <param name="Site">The list's row.</param>
/// <param name="Commands">Its commands, classified.</param>
/// <param name="ForcedTransfers">The transfers its scripts make at once.</param>
/// <param name="ScriptSwitches">The switches its scripts name, as the chest flags' rule reads them.</param>
/// <param name="ScriptRoots">The roots of its scripts, see <see cref="Build.ScriptRoots"/>.</param>
/// <param name="SelfSwitchScripts">What its scripts do to self switches.</param>
/// <param name="HoldingScripts">Its scripts that add to or take from what a player holds.</param>
/// <param name="ExChoices">Its extended choices.</param>
internal sealed record BuiltList(
    ListRow Site,
    EventCommand[] Commands,
    IReadOnlyList<ForcedTransfer> ForcedTransfers,
    IReadOnlyList<int> ScriptSwitches,
    IReadOnlyList<string> ScriptRoots,
    ScriptSelfSwitches SelfSwitchScripts,
    IReadOnlyList<HoldingScript> HoldingScripts,
    IReadOnlyList<ExChoice> ExChoices);

/// <summary>
/// Reads what a list's script lines tell by their texts.
/// </summary>
internal static partial class ScriptTexts
{
    /// <summary>
    /// The branch on a script, of a conditional branch.
    /// </summary>
    private const int ScriptBranch = 12;

    /// <summary>
    /// The script operand of a Control Variables command.
    /// </summary>
    private const int ScriptOperand = 4;

    /// <summary>
    /// Reads the forced transfers and the switches named by a list's script lines, each line by itself.
    /// </summary>
    /// <param name="list">The commands as read.</param>
    /// <returns>The forced transfers and the switches, in their order.</returns>
    public static (List<ForcedTransfer> Transfers, List<int> Switches) Of(IReadOnlyList<RawCommand> list)
    {
        var transfers = new List<ForcedTransfer>();
        var switches = new List<int>();
        for (int idx = 0; idx < list.Count; idx++)
        {
            if (list[idx].Code is not (EventCodes.Script or EventCodes.ScriptLine))
            {
                continue;
            }

            string line = list[idx].Text(0);
            if (ForcedTransferCall().Match(line) is { Success: true } transfer)
            {
                transfers.Add(new ForcedTransfer(idx, NumberOf(transfer.Groups[1]), NumberOf(transfer.Groups[2]), NumberOf(transfer.Groups[3])));
            }

            foreach (Match named in SwitchInScript().Matches(line))
            {
                switches.Add(NumberOf(named.Groups[1]));
            }
        }

        return (transfers, switches);
    }

    /// <summary>
    /// Reads what a list's scripts do to self switches: each script whole, the lines of a script
    /// command joined, and the scripts of conditional branches and Control Variables.
    /// </summary>
    /// <param name="list">The commands as read.</param>
    /// <returns>What they do.</returns>
    public static ScriptSelfSwitches SelfSwitchesOf(IReadOnlyList<RawCommand> list)
    {
        var turnedOn = new List<ScriptSelfSwitch>();
        var resetMaps = new SortedSet<int>();
        bool unnamed = false;
        bool resetsAll = false;
        foreach (string script in ScriptsOf(list))
        {
            int named = 0;
            foreach (Match write in SelfSwitchWrite().Matches(script))
            {
                named++;
                int? map = BoundOrNumber(write.Groups[1].Value, out bool mapKnown);
                int? eventId = BoundOrNumber(write.Groups[2].Value, out bool eventKnown);
                if (!mapKnown || !eventKnown)
                {
                    unnamed = true;
                }
                else if (write.Groups[4].Value != "false")
                {
                    turnedOn.Add(new ScriptSelfSwitch(map, eventId, write.Groups[3].Value));
                }
            }

            unnamed |= AnySelfSwitchWrite().Matches(script).Count > named;
            var locals = new Dictionary<string, int>(System.StringComparer.Ordinal);
            foreach (Match local in LocalNumber().Matches(script))
            {
                locals[local.Groups[1].Value] = NumberOf(local.Groups[2]);
            }

            foreach (Match reset in ResetCall().Matches(script))
            {
                resetMaps.UnionWith(reset.Groups[1].Value.Split(',').SelectMany(part => MapsOf(part.Trim(), locals)));
            }

            resetsAll |= script.Contains("Game_SelfSwitches.new", System.StringComparison.Ordinal);
        }

        return turnedOn.Count == 0 && !unnamed && resetMaps.Count == 0 && !resetsAll ? ScriptSelfSwitches.None : new ScriptSelfSwitches(turnedOn, unnamed, [.. resetMaps], resetsAll);
    }

    /// <summary>
    /// Lists a list's scripts: each script command with its continuation lines, and the scripts of
    /// conditional branches and Control Variables.
    /// </summary>
    /// <param name="list">The commands as read.</param>
    /// <returns>The scripts.</returns>
    private static IEnumerable<string> ScriptsOf(IReadOnlyList<RawCommand> list)
    {
        for (int idx = 0; idx < list.Count; idx++)
        {
            RawCommand command = list[idx];
            if (command.Code == EventCodes.Script)
            {
                var script = new StringBuilder(command.Text(0));
                while (idx + 1 < list.Count && list[idx + 1].Code == EventCodes.ScriptLine)
                {
                    script.Append('\n').Append(list[++idx].Text(0));
                }

                yield return script.ToString();
            }
            else if (command.Code == EventCodes.Branch && command.Parameters.Count > 1 && EventCommand.NumberOf(command.Parameters[0]) == ScriptBranch)
            {
                yield return command.Text(1);
            }
            else if (command.Code == EventCodes.ControlVariables && command.Parameters.Count > 4 && EventCommand.NumberOf(command.Parameters[3]) == ScriptOperand)
            {
                yield return command.Text(4);
            }
        }
    }

    /// <summary>
    /// Reads the maps one argument of reset_selfswitch_map names: a number, or a range spread, such as
    /// <c>*(map_id..last_map_id)</c>, whose ends are numbers or the script's local numbers.
    /// </summary>
    /// <param name="argument">The argument.</param>
    /// <param name="locals">The numbers the script sets its local variables to.</param>
    /// <returns>The maps; none for an argument the text does not name.</returns>
    private static IEnumerable<int> MapsOf(string argument, IReadOnlyDictionary<string, int> locals)
    {
        if (int.TryParse(argument, NumberStyles.None, CultureInfo.InvariantCulture, out int map))
        {
            return [map];
        }

        if (SpreadRange().Match(argument) is not { Success: true } range)
        {
            return [];
        }

        int? Bound(string text) => int.TryParse(text, NumberStyles.None, CultureInfo.InvariantCulture, out int number) ? number : locals.TryGetValue(text, out int local) ? local : null;
        return Bound(range.Groups[1].Value) is { } from && Bound(range.Groups[3].Value) is { } to
            ? Enumerable.Range(from, System.Math.Max(0, to - from + (range.Groups[2].Value.Length == 2 ? 1 : 0)))
            : [];
    }

    /// <summary>
    /// Reads a self switch key's map or event: a number, or the running event's (<c>@map_id</c>,
    /// <c>$game_map.map_id</c>, <c>@event_id</c>, <c>event_id</c>).
    /// </summary>
    /// <param name="text">The part of the key.</param>
    /// <param name="known">Whether the text names it.</param>
    /// <returns>The number, <see langword="null"/> for the running event's.</returns>
    private static int? BoundOrNumber(string text, out bool known)
    {
        string part = text.Trim();
        if (int.TryParse(part, NumberStyles.None, CultureInfo.InvariantCulture, out int number))
        {
            known = true;
            return number;
        }

        known = part is "@map_id" or "$game_map.map_id" or "@event_id" or "event_id";
        return null;
    }

    /// <summary>
    /// Reads a matched number as Ruby's <c>to_i</c> does, the too large ones as the largest.
    /// </summary>
    /// <param name="group">The digits.</param>
    /// <returns>The number.</returns>
    private static int NumberOf(Group group) =>
        int.TryParse(group.ValueSpan, NumberStyles.None, CultureInfo.InvariantCulture, out int number) ? number : int.MaxValue;

    /// <summary>
    /// A script that moves the player at once, as the game's post-defeat processing does: map, x and y
    /// (raid_freeze_data.rb's FORCED_TRANSFER).
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"forced_transfer\([ \t\r\n\f\v]*([0-9]+)[ \t\r\n\f\v]*,[ \t\r\n\f\v]*([0-9]+)[ \t\r\n\f\v]*,[ \t\r\n\f\v]*([0-9]+)[ \t\r\n\f\v]*\)", RegexOptions.CultureInvariant)]
    private static partial Regex ForcedTransferCall();

    /// <summary>
    /// A switch a script reads, such as "$game_switches[2688]" or the choice condition "s[7102]"
    /// (story_rewards.rb's SWITCH_IN_SCRIPT).
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex("(?:(?<![A-Za-z0-9_])s|switches)\\[([0-9]+)\\]", RegexOptions.CultureInvariant)]
    private static partial Regex SwitchInScript();

    /// <summary>
    /// A write of a self switch named by its key: map, event, letter and the value written.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"\$game_self_switches\[\s*\[\s*([^,\]]+?)\s*,\s*([^,\]]+?)\s*,\s*[""']([A-Za-z])[""']\s*\]\s*\]\s*=(?![=~])\s*([A-Za-z_]*)", RegexOptions.CultureInvariant)]
    private static partial Regex SelfSwitchWrite();

    /// <summary>
    /// Any write of a self switch.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"\$game_self_switches\s*\[.*?\]\s*=(?![=~])", RegexOptions.CultureInvariant)]
    private static partial Regex AnySelfSwitchWrite();

    /// <summary>
    /// A reset of maps' self switches, script 167's reset_selfswitch_map, with its maps.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"reset_selfswitch_map\s*\(((?:[^()]|\([^()]*\))*)\)", RegexOptions.CultureInvariant)]
    private static partial Regex ResetCall();

    /// <summary>
    /// A local variable a script sets to a number, such as <c>last_map_id = 1999</c>.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"^[ \t]*([a-z_][A-Za-z0-9_]*)[ \t]*=[ \t]*([0-9]+)[ \t]*$", RegexOptions.CultureInvariant | RegexOptions.Multiline)]
    private static partial Regex LocalNumber();

    /// <summary>
    /// A spread range, such as <c>*(map_id..last_map_id)</c>: its ends and the dots between them.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"^\*\(\s*([A-Za-z0-9_]+)\s*(\.\.\.?)\s*([A-Za-z0-9_]+)\s*\)$", RegexOptions.CultureInvariant)]
    private static partial Regex SpreadRange();
}
