//----------------------------------------------------------------
//  BuiltList.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Globalization;
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
/// One list the build read, kept until the derived rows are made: its row, its commands as the
/// rules read them, and what its scripts' texts tell, which the commands no longer hold.
/// </summary>
/// <param name="Site">The list's row.</param>
/// <param name="Commands">Its commands, classified.</param>
/// <param name="ForcedTransfers">The transfers its scripts make at once.</param>
/// <param name="ScriptSwitches">The switches its scripts name, as the chest flags' rule reads them.</param>
internal sealed record BuiltList(ListRow Site, EventCommand[] Commands, IReadOnlyList<ForcedTransfer> ForcedTransfers, IReadOnlyList<int> ScriptSwitches);

/// <summary>
/// Reads what a list's script lines tell by their texts.
/// </summary>
internal static partial class ScriptTexts
{
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
}
