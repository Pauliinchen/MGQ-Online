//----------------------------------------------------------------
//  IdFlags.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Read the story's band of switches from StoryIds
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Globalization;
using System.Text.RegularExpressions;
using MGQOnline.Data.Events;
using MGQOnline.Data.Generator.Source;
using MGQOnline.Game.Story;

namespace MGQOnline.Data.Generator.Build;

/// <summary>
/// Reads the flags of switches, variables, items and enemies from their names, descriptions and
/// notes, in the untranslated game's words and the translation's alike.
/// </summary>
internal static partial class IdFlags
{
    /// <summary>
    /// The first switch of the story's band, which brings companions and is never scratch, as
    /// EventSorter keeps it.
    /// </summary>
    public const int FirstStorySwitch = StoryIds.FirstStorySwitch;

    /// <summary>
    /// See <see cref="FirstStorySwitch"/>.
    /// </summary>
    public const int LastStorySwitch = StoryIds.LastStorySwitch;

    /// <summary>
    /// The item type of key items.
    /// </summary>
    private const int KeyItemType = 2;

    /// <summary>
    /// Reads the switches' flags.
    /// </summary>
    /// <param name="names">The switches' names by id, with the empty first one.</param>
    /// <param name="chestFlags">The switches only chests turn on, see <see cref="ChestFlags"/>.</param>
    /// <returns>A row per switch from 1.</returns>
    public static List<SwitchRow> Switches(IReadOnlyList<string> names, IReadOnlySet<int> chestFlags)
    {
        var rows = new List<SwitchRow>(names.Count);
        for (int id = 1; id < names.Count; id++)
        {
            bool storyBand = id is >= FirstStorySwitch and <= LastStorySwitch;
            rows.Add(new SwitchRow(id, names[id].Length > 0, !storyBand && IsScratch(names[id]), storyBand, chestFlags.Contains(id)));
        }

        return rows;
    }

    /// <summary>
    /// Reads the variables' flags.
    /// </summary>
    /// <param name="names">The variables' names by id, with the empty first one.</param>
    /// <param name="actors">How many entries the actors' list holds, its empty first one included.</param>
    /// <returns>A row per variable from 1.</returns>
    public static List<VariableRow> Variables(IReadOnlyList<string> names, int actors)
    {
        var rows = new List<VariableRow>(names.Count);
        for (int id = 1; id < names.Count; id++)
        {
            bool affection = id >= ClassicStoryTable.AffectionBase && id < ClassicStoryTable.AffectionBase + actors;
            rows.Add(new VariableRow(id, names[id].Length > 0, IsScratch(names[id]), affection));
        }

        return rows;
    }

    /// <summary>
    /// Reads the flags of one list of items, weapons or armors.
    /// </summary>
    /// <param name="kind">The list.</param>
    /// <param name="entries">Its entries by id.</param>
    /// <returns>A row per entry the game has.</returns>
    public static IEnumerable<ItemRow> Items(ItemKind kind, IReadOnlyList<SourceEntry?> entries)
    {
        for (int id = 1; id < entries.Count; id++)
        {
            if (entries[id] is { } entry)
            {
                yield return new ItemRow(kind, id, kind == ItemKind.Item && entry.ItemType == KeyItemType, UnlockOf(entry.Description));
            }
        }
    }

    /// <summary>
    /// Reads the enemies' levels from their notes, 0 for an enemy without one.
    /// </summary>
    /// <param name="entries">The enemies by id.</param>
    /// <returns>A row per enemy the game has.</returns>
    public static IEnumerable<EnemyRow> Enemies(IReadOnlyList<SourceEntry?> entries)
    {
        for (int id = 1; id < entries.Count; id++)
        {
            if (entries[id] is { } entry)
            {
                Match level = EnemyLevel().Match(entry.Note);
                yield return new EnemyRow(id, level.Success && int.TryParse(level.Groups[1].ValueSpan, NumberStyles.None, CultureInfo.InvariantCulture, out int found) ? found : 0);
            }
        }
    }

    /// <summary>
    /// Tells whether an item is described as a key item or a material, whose events tell the story.
    /// </summary>
    /// <param name="entry">The item.</param>
    /// <returns>Whether it is.</returns>
    public static bool IsStoryItem(SourceEntry entry) => entry.ItemType == KeyItemType && KeyItemTag().IsMatch(entry.Description);

    /// <summary>
    /// Tells whether a switch's or variable's name is a scratch one's.
    /// </summary>
    /// <param name="name">The name.</param>
    /// <returns>Whether it is.</returns>
    private static bool IsScratch(string name) => ScratchName().IsMatch(name);

    /// <summary>
    /// Reads what an item's description says it unlocks.
    /// </summary>
    /// <param name="description">The description.</param>
    /// <returns>A job, a race or nothing.</returns>
    private static UnlockClass UnlockOf(string description) => UnlockTag().Match(description) switch
    {
        { Success: false } => UnlockClass.None,
        { Groups: var groups } when groups["race"].Success => UnlockClass.Race,
        _ => UnlockClass.Job,
    };

    /// <summary>
    /// The names of switches and variables the game uses as scratch while an event runs: coop_events.rbx's
    /// TEMPORARY_NAMES, with システム専用, the untranslated words of its "system only".
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex("general|temp|system only|汎用|一時|システム専用", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex ScratchName();

    /// <summary>
    /// The tag at the start of an item's description that tells it unlocks a job or a race: [Job] or
    /// [Race], 職業 or 種族 in either kind of bracket, and 【転職用】, the untranslated game's tag of the
    /// items the translation tags [Job].
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"\A[ \t\r\n\f\v]*(?:[\[［](?:Job|職業)|【転職用】|(?<race>[\[［](?:Race|種族)))", RegexOptions.CultureInvariant)]
    private static partial Regex UnlockTag();

    /// <summary>
    /// The descriptions that tell key items and ores from the other items of the key item type:
    /// [Key Item] and [Material], and 【貴重品】 and 【素材】, the untranslated game's tags.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"\A(?:\[(?:Key Item|Material)\]|【(?:貴重品|素材)】)", RegexOptions.CultureInvariant)]
    private static partial Regex KeyItemTag();

    /// <summary>
    /// The note tag of an enemy's level, read for the Makina.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"<逃走レベル[ \t\r\n\f\v]?([0-9]+)>", RegexOptions.CultureInvariant)]
    private static partial Regex EnemyLevel();
}
