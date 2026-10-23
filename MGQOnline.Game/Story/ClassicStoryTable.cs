//----------------------------------------------------------------
//  ClassicStoryTable.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;

namespace MGQOnline.Game.Story;

/// <summary>
/// How a Classic party shares the leader's story with the members who follow it: every switch,
/// variable and self switch, but those each player keeps of their own (the lists story_state.rbx
/// kept before they moved here). The scripts still keep the member's own choices, their map's
/// chests and the choices' lines their own, which only the member's game knows.
/// </summary>
public static class ClassicStoryTable
{
    /// <summary>
    /// The switch that bans warping (WARP_BAN), which tells of the place a player stands in.
    /// </summary>
    public const int WarpBan = 100;

    /// <summary>
    /// The switch that bans the escape spell, which tells of the place a player stands in too.
    /// </summary>
    public const int EscapeBan = 94;

    /// <summary>
    /// The switches of the side the player chose, each player's own until the Great Decision.
    /// </summary>
    public static readonly IReadOnlyList<int> SideSwitches = [4, 5];

    /// <summary>
    /// Switches each player keeps: 0, which no switch is, the flags the game toggles around its
    /// fights (22, 73 "Chaos Enemy Pause", 97 "Hades Rematch"), configuration mirrored in switches
    /// (95, 445-447, 502), the warp and escape bans, the companions in the party (1001-2000) and
    /// their awakening (6000-6999).
    /// </summary>
    public static readonly IReadOnlyList<(int From, int To)> PersonalSwitches =
        [(0, 0), (22, 22), (73, 73), (EscapeBan, EscapeBan), (95, 95), (97, 97), (WarpBan, WarpBan), (445, 447), (502, 502), (1001, 2000), (6000, 6999)];

    /// <summary>
    /// Variables each player keeps: 0, which no variable is, the last choice's answer (9), where the
    /// Pocket Castle's way out returns them (21-23), the enemies' corrections (46-48) and the drops'
    /// rarity (150) each area sets, the medals handed in (55, 59), the party's places beyond eight
    /// (56), the map a transfer goes on to (57), the event variant picked before a call (129), the
    /// enchanted equipment's counts (200-201), the game over's return point (1002) and the monsters'
    /// friendliness (2000-2999).
    /// </summary>
    public static readonly IReadOnlyList<(int From, int To)> PersonalVariables =
        [(0, 0), (9, 9), (21, 23), (46, 48), (55, 57), (59, 59), (129, 129), (150, 150), (200, 201), (1002, 1002), (2000, 2999)];

    /// <summary>
    /// The variable before the first companion's affection; companion n's is AffectionBase + n.
    /// </summary>
    public const int AffectionBase = 3000;

    /// <summary>
    /// Builds the table of a Classic party.
    /// </summary>
    /// <param name="switches">How many switches the game has, its <c>$data_system.switches</c>.</param>
    /// <param name="variables">How many variables it has.</param>
    /// <param name="companions">How many companions it has, one affection variable each.</param>
    /// <param name="chestFlags">The switches only chests turn on, each player's own.</param>
    /// <returns>The table.</returns>
    public static StoryTable Build(int switches, int variables, int companions, IEnumerable<int> chestFlags)
    {
        ArgumentNullException.ThrowIfNull(chestFlags);
        byte[] switchClasses = Filled(Math.Max(switches, 0));
        byte[] variableClasses = Filled(Math.Max(variables, 0));
        Clear(switchClasses, PersonalSwitches);
        Clear(variableClasses, PersonalVariables);
        Clear(variableClasses, [(AffectionBase, AffectionBase + Math.Max(companions, 1) - 1)]);
        foreach (int flag in chestFlags)
        {
            if (flag >= 0 && flag < switchClasses.Length)
            {
                switchClasses[flag] = (byte)StoryClass.Chest;
            }
        }

        foreach (int side in SideSwitches)
        {
            if (side < switchClasses.Length)
            {
                switchClasses[side] = (byte)(StoryClass.Kept | StoryClass.Side);
            }
        }

        return new StoryTable(0, switchClasses, variableClasses, new Dictionary<string, StoryClass>(StringComparer.Ordinal), new HashSet<long>(),
            [], new Dictionary<string, int>(StringComparer.Ordinal), StoryClass.Kept);
    }

    /// <summary>
    /// Makes classes of a count of ids, each shared.
    /// </summary>
    /// <param name="count">How many.</param>
    /// <returns>The classes.</returns>
    private static byte[] Filled(int count)
    {
        byte[] classes = new byte[count];
        Array.Fill(classes, (byte)StoryClass.Kept);
        return classes;
    }

    /// <summary>
    /// Makes the ids of ranges each player's own.
    /// </summary>
    /// <param name="classes">The classes by id.</param>
    /// <param name="ranges">The ranges, both ends included.</param>
    private static void Clear(byte[] classes, IEnumerable<(int From, int To)> ranges)
    {
        foreach ((int from, int to) in ranges)
        {
            for (int id = Math.Max(from, 0); id <= to && id < classes.Length; id++)
            {
                classes[id] = (byte)StoryClass.Personal;
            }
        }
    }
}
