//----------------------------------------------------------------
//  ChestFlags.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Data.Events;
using MGQOnline.Game.Events.Data;

namespace MGQOnline.Data.Generator.Build;

/// <summary>
/// Finds the chest flags as story_rewards.rb's chest_flags_of does: the switches only pages that
/// look like chests turn on, as a chest's record of its own, such as "Initial Machine" (2045); and
/// the switches a chest notes itself opened in, which only such chests turn on and nothing but
/// their own events reads. A chest that gives a story item notes no flag, since its switch tells
/// the story. Every map page, common event and troop page counts.
/// </summary>
internal static class ChestFlags
{
    /// <summary>
    /// Commands a chest gives with: gold, items, weapons and armors.
    /// </summary>
    private static readonly int[] ChestCodes = [EventCodes.ChangeGold, EventCodes.ChangeItems, EventCodes.ChangeWeapons, EventCodes.ChangeArmors];

    /// <summary>
    /// Commands that make a page more than a chest: switches, variables, party changes, battles and scripts.
    /// </summary>
    private static readonly int[] StoryCodes = [EventCodes.ControlSwitches, EventCodes.ControlVariables, EventCodes.ChangePartyMember, EventCodes.Battle, EventCodes.Script];

    /// <summary>
    /// The reader that stands for every common event.
    /// </summary>
    private static readonly (int Map, int Event) CommonReader = (-1, 0);

    /// <summary>
    /// The reader that stands for every troop page.
    /// </summary>
    private static readonly (int Map, int Event) TroopReader = (-2, 0);

    /// <summary>
    /// Finds the chest flags.
    /// </summary>
    /// <param name="game">The game.</param>
    /// <param name="storyItems">The items described as key items or materials, see <see cref="IdFlags.IsStoryItem"/>.</param>
    /// <returns>The switches.</returns>
    public static SortedSet<int> Of(BuiltGame game, IReadOnlySet<long> storyItems)
    {
        var chestOn = new HashSet<int>();
        var otherOn = new HashSet<int>();
        var opened = new Dictionary<int, HashSet<(int Map, int Event)>>();
        var readers = new Dictionary<int, HashSet<(int Map, int Event)>>();
        foreach (BuiltList list in game.Lists)
        {
            IReadOnlyList<int> on = SwitchesOf(list.Commands, true);
            switch (list.Site.Kind)
            {
                case ListKind.Common:
                    CommonEventRow common = game.CommonOf(list);
                    otherOn.UnionWith(on);
                    AddReaders(readers, SwitchesRead(list).Concat(common.Trigger > 0 ? [common.SwitchId] : []), CommonReader);
                    break;
                case ListKind.TroopPage:
                    TroopPageRow troopPage = game.TroopPageOf(list);
                    otherOn.UnionWith(on);
                    AddReaders(readers, SwitchesRead(list).Concat(troopPage.SwitchValid ? [troopPage.SwitchId] : []), TroopReader);
                    break;
                default:
                    PageRow page = game.PageOf(list);
                    (int Map, int Event) owner = (page.MapId, page.EventId);
                    AddReaders(readers, SwitchesRead(list).Concat(new[] { page.CondSwitch1, page.CondSwitch2 }.OfType<int>()), owner);
                    if (IsFlagChest(list, page))
                    {
                        chestOn.UnionWith(on);
                    }
                    else if (IsSwitchChest(list, page) && !GivesStoryItem(list, storyItems))
                    {
                        foreach (int id in on)
                        {
                            AddReaders(opened, [id], owner);
                        }
                    }
                    else
                    {
                        otherOn.UnionWith(on);
                    }

                    break;
            }
        }

        IEnumerable<int> own = opened.Where(pair => !readers.TryGetValue(pair.Key, out var read) || read.IsSubsetOf(pair.Value)).Select(pair => pair.Key);
        return [.. chestOn.Concat(own).Except(otherOn).Where(id => id is < IdFlags.FirstStorySwitch or > IdFlags.LastStorySwitch)];
    }

    /// <summary>
    /// Tells whether a page looks like a chest that also sets switches: it gives items or gold,
    /// shuts itself and sets switches but nothing else of <see cref="StoryCodes"/>, on a page that
    /// asks for no switch or variable, unlike the Pocket Castle's handover (map 2, event 5).
    /// </summary>
    /// <param name="list">The page's list.</param>
    /// <param name="page">The page.</param>
    /// <returns>Whether it does.</returns>
    private static bool IsFlagChest(BuiltList list, PageRow page)
    {
        if (page.CondSwitch1 is not null || page.CondSwitch2 is not null || page.CondVariable is not null)
        {
            return false;
        }

        HashSet<int> codes = CodesOf(list);
        return codes.Contains(EventCodes.ControlSelfSwitch) && codes.Overlaps(ChestCodes) && SetsOnlySwitches(codes);
    }

    /// <summary>
    /// Tells whether a page looks like a chest that notes itself opened in a switch instead of a
    /// self switch, as the Final Chapter's castles do: it gives items or gold and turns switches on
    /// but does nothing else of <see cref="StoryCodes"/>, on a page that asks for nothing.
    /// </summary>
    /// <param name="list">The page's list.</param>
    /// <param name="page">The page.</param>
    /// <returns>Whether it does.</returns>
    private static bool IsSwitchChest(BuiltList list, PageRow page)
    {
        if (page.CondSwitch1 is not null || page.CondSwitch2 is not null || page.CondVariable is not null
            || page.CondSelfSwitch is not null || page.CondItem is not null || page.CondActor is not null)
        {
            return false;
        }

        HashSet<int> codes = CodesOf(list);
        return !codes.Contains(EventCodes.ControlSelfSwitch) && codes.Overlaps(ChestCodes) && SetsOnlySwitches(codes)
            && SwitchesOf(list.Commands, false).SequenceEqual(SwitchesOf(list.Commands, true));
    }

    /// <summary>
    /// Tells whether of <see cref="StoryCodes"/> a list holds Control Switches alone.
    /// </summary>
    /// <param name="codes">The list's codes.</param>
    /// <returns>Whether it does.</returns>
    private static bool SetsOnlySwitches(HashSet<int> codes) => StoryCodes.Where(codes.Contains).SequenceEqual([EventCodes.ControlSwitches]);

    /// <summary>
    /// Lists the codes of a list's commands, leaving out the scripts a talk or travel runs, so a
    /// villager's gift that also runs a companion's own lines still reads as a chest.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>The codes.</returns>
    private static HashSet<int> CodesOf(BuiltList list) =>
        [.. list.Commands.Where(command => command.Code != EventCodes.Script || command.TextKind is not (TextKind.Talk or TextKind.Choice or TextKind.Travel)).Select(command => command.Code)];

    /// <summary>
    /// Tells whether a list gives a story item.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="storyItems">The story items.</param>
    /// <returns>Whether it does.</returns>
    private static bool GivesStoryItem(BuiltList list, IReadOnlySet<long> storyItems) =>
        list.Commands.Any(command => command.Code == EventCodes.ChangeItems && command.Number(1) == 0 && storyItems.Contains(command.Number(0)));

    /// <summary>
    /// Lists the switches a list's branches and scripts read.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>The switches.</returns>
    private static IEnumerable<int> SwitchesRead(BuiltList list) =>
        list.Commands.Where(command => command.Code == EventCodes.Branch && command.Number(0) == 0).Select(command => (int)command.Number(1)).Concat(list.ScriptSwitches);

    /// <summary>
    /// Lists the switches a list's Control Switches set, each once, in their order.
    /// </summary>
    /// <param name="commands">The commands.</param>
    /// <param name="onOnly">Whether to list only those it turns on.</param>
    /// <returns>The switches.</returns>
    private static List<int> SwitchesOf(EventCommand[] commands, bool onOnly)
    {
        var seen = new HashSet<int>();
        var switches = new List<int>();
        foreach (EventCommand command in commands)
        {
            if (command.Code != EventCodes.ControlSwitches || (onOnly && command.Number(2) != 0))
            {
                continue;
            }

            for (long id = command.Number(0); id <= command.Number(1); id++)
            {
                if (seen.Add((int)id))
                {
                    switches.Add((int)id);
                }
            }
        }

        return switches;
    }

    /// <summary>
    /// Notes a reader of switches.
    /// </summary>
    /// <param name="readers">The readers by switch.</param>
    /// <param name="switches">The switches it reads.</param>
    /// <param name="reader">The reader: a map event, or one that stands for every common event or troop page.</param>
    private static void AddReaders(Dictionary<int, HashSet<(int Map, int Event)>> readers, IEnumerable<int> switches, (int Map, int Event) reader)
    {
        foreach (int id in switches)
        {
            if (!readers.TryGetValue(id, out HashSet<(int Map, int Event)>? found))
            {
                readers[id] = found = [];
            }

            found.Add(reader);
        }
    }
}
