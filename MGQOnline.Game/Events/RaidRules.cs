//----------------------------------------------------------------
//  RaidRules.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Added the excluded maps, the arena switches and the post-defeat processing
//                            - Created
//
//----------------------------------------------------------------

using System.Collections.Frozen;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Game.Events;

/// <summary>
/// The hand-written rules the raid freeze reads the game's story battles by.
/// </summary>
/// <remarks>
/// They move into the Raid Designer once its redesign owns the raid rules, so they stay in this one class.
/// </remarks>
public static class RaidRules
{
    /// <summary>
    /// The switch the game's events turn on right before every story boss battle.
    /// </summary>
    public const int BossSwitch = 22;

    /// <summary>
    /// The game's post-defeat processing, which every defeat event calls at its end.
    /// </summary>
    public const int DefeatEvent = EventSchema.DefeatEvent;

    /// <summary>
    /// Maps whose boss battles never freeze: the Hades hall (154) and the Hades rematch hall (576).
    /// </summary>
    public static readonly FrozenSet<int> ExcludedMaps = new[] { 154, 576 }.ToFrozenSet();

    /// <summary>
    /// The switches of the Colosseum (87) and of Hades (97): a list that turns one on fights no story.
    /// </summary>
    public static readonly IReadOnlyList<int> ArenaSwitches = [87, 97];

    /// <summary>
    /// The commands of a battle's preamble before its battle command: the battle BGM, the battle end
    /// ME and the battleback.
    /// </summary>
    public static readonly FrozenSet<int> PreambleCodes = new[] { 132, 133, 283 }.ToFrozenSet();

    /// <summary>
    /// Finds where a battle's preamble starts: back from the battle command over the preamble's
    /// commands and the boss switch turned on, at the battle command's indent.
    /// </summary>
    /// <param name="list">The commands.</param>
    /// <param name="index">The battle command's place.</param>
    /// <returns>The place the preamble starts at, the battle command's own when it has none.</returns>
    public static int PreambleStart(IReadOnlyList<EventCommand> list, int index)
    {
        int indent = list[index].Indent;
        int start = index;
        while (start > 0 && list[start - 1].Indent == indent && (PreambleCodes.Contains(list[start - 1].Code) || TurnsOnBossSwitch(list[start - 1])))
        {
            start--;
        }

        return start;
    }

    /// <summary>
    /// Tells whether a list turns on the Colosseum's or Hades's switch.
    /// </summary>
    /// <param name="list">The commands.</param>
    /// <returns>Whether it does.</returns>
    public static bool TurnsOnArena(IReadOnlyList<EventCommand> list)
    {
        foreach (EventCommand command in list)
        {
            if (command.Code == EventCodes.ControlSwitches && command.Number(2) == 0
                && ArenaSwitches.Any(arena => command.Number(0) <= arena && arena <= command.Number(1)))
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>
    /// Tells whether a command turns the boss switch on.
    /// </summary>
    /// <param name="command">The command.</param>
    /// <returns>Whether it does.</returns>
    private static bool TurnsOnBossSwitch(EventCommand command) =>
        command.Code == EventCodes.ControlSwitches && command.Number(0) <= BossSwitch && BossSwitch <= command.Number(1) && command.Number(2) == 0;
}
