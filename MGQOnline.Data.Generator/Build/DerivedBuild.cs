//----------------------------------------------------------------
//  DerivedBuild.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Flagged the battlefuck events the sorter reads
//                            - Took the game's scripts as the build read them
//      Paulinchen  2026-11-01: Derived the branches of each extended choice too
//      Paulinchen  2026-10-31: Derived the pairs the one-time repair of stuck saves completes
//                            - Derived the lists that give and the branches of each choice
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Data.Events;
using MGQOnline.Data.Generator.Source;
using MGQOnline.Game.Events;
using MGQOnline.Game.Story;

namespace MGQOnline.Data.Generator.Build;

/// <summary>
/// Derives the rows the rules read once the lists are read: the flags per switch, variable, item
/// and enemy, the common events' and the pages' flags with the chests of a new game, and the raid
/// sites' alternatives and scene entries; the pairs the one-time repair of stuck saves completes; and
/// the lists that give and the branches of each choice, which the story replay reads.
/// </summary>
internal static class DerivedBuild
{
    /// <summary>
    /// The files of the item lists, by kind.
    /// </summary>
    private static readonly (ItemKind Kind, string Path)[] ItemFiles =
        [(ItemKind.Item, "Data/Items.rvdata2"), (ItemKind.Weapon, "Data/Weapons.rvdata2"), (ItemKind.Armor, "Data/Armors.rvdata2")];

    /// <summary>
    /// The enemies' file.
    /// </summary>
    private const string EnemiesFile = "Data/Enemies.rvdata2";

    /// <summary>
    /// Adds the derived rows and sets the derived flags of the pages and common events.
    /// </summary>
    /// <param name="rows">The rows read so far.</param>
    /// <param name="lists">Every list read, in the order of their ids.</param>
    /// <param name="source">The game's data, whose names, descriptions and notes the flags are read from.</param>
    /// <param name="scripts">The game's scripts, each as one text.</param>
    /// <param name="commons">The common events as read, by id.</param>
    /// <param name="actors">How many entries the actors' list holds, its empty first one included.</param>
    /// <returns>The game as the derived rows read it.</returns>
    public static BuiltGame Derive(EventRows rows, IReadOnlyList<BuiltList> lists, GameSource source, IReadOnlyList<string> scripts, IReadOnlyList<SourceCommon?> commons, int actors)
    {
        var game = new BuiltGame(rows, lists);
        (IReadOnlyList<string> switchNames, IReadOnlyList<string> variableNames) = source.ReadSystemNames();
        IReadOnlyList<SourceEntry?> items = source.ReadEntries(ItemFiles[0].Path);
        HashSet<long> storyItems = [.. Enumerable.Range(0, items.Count).Where(id => items[id] is { } item && IdFlags.IsStoryItem(item)).Select(id => (long)id)];

        SortedSet<int> chestFlags = ChestFlags.Of(game, storyItems);
        rows.Switches.AddRange(IdFlags.Switches(switchNames, chestFlags));
        rows.Variables.AddRange(IdFlags.Variables(variableNames, actors));
        foreach ((ItemKind kind, string path) in ItemFiles)
        {
            rows.Items.AddRange(IdFlags.Items(kind, source.ReadEntries(path)));
        }

        rows.Enemies.AddRange(IdFlags.Enemies(source.ReadEntries(EnemiesFile)));
        game.SetScratch(
            rows.Switches.Where(row => row.Scratch).Select(row => (long)row.Id).ToHashSet(),
            rows.Variables.Where(row => row.Scratch).Select(row => (long)row.Id).ToHashSet());

        IReadOnlySet<long> battlefucks = game.Battlefucks;
        for (int index = 0; index < rows.CommonEvents.Count; index++)
        {
            CommonEventRow common = rows.CommonEvents[index];
            BuiltList list = lists[common.ListId - 1];
            rows.CommonEvents[index] = common with
            {
                Own = EventSorter.OwnCommonEvents.Contains(common.Id),
                Battlefuck = battlefucks.Contains(common.Id),
                FinalChapter = CommonFlags.IsFinalChapter(common.Id, commons[common.Id]!.Name, list.Commands),
                FadesIn = CommonFlags.FadesIn(list.Commands),
            };
        }

        StoryTable classic = ClassicStoryTable.Build(switchNames.Count, variableNames.Count, actors, chestFlags);
        PageFlags.Derive(rows, game, classic, RaidSites.DefeatWrites(game).Switches);

        var raid = new RaidSites(game);
        rows.SiteAlternatives.AddRange(raid.Alternatives());
        rows.SceneEntries.AddRange(raid.SceneEntries());

        SwitchUses uses = SwitchUses.Of(scripts, source.ReadInUse(GameSource.NamedParts[0].Path), GameSource.NamedParts.SelectMany(part => source.ReadEntries(part.Path)));
        rows.RepairPairs.AddRange(RepairPairs.Of(game, uses));
        rows.Gives.AddRange(Gives.Of(game));
        rows.ChoiceBranches.AddRange(ChoiceAsks.Of(game, scripts));
        return game;
    }
}
