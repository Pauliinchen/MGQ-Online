//----------------------------------------------------------------
//  OverviewPages.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Handed the World page's players online and story over as values with their captions
//                            - Listed the labels of every entry of a page, those of folded groups too
//      Paulinchen  2026-11-08: Took over the quests' text rules from the scripts
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.RegularExpressions;
using MGQOnline.Game.Raid;

namespace MGQOnline.Game.Overview;

/// <summary>
/// The World overview's pages with a head, a list and a reading pane: the World page, the Quests
/// page and the Unlocks page, from what the scripts read of the game and the world's pools.
/// </summary>
public static class OverviewPages
{
    /// <summary>
    /// The World page.
    /// </summary>
    public const string WorldPage = "world";

    /// <summary>
    /// The Quests page.
    /// </summary>
    public const string QuestsPage = "quests";

    /// <summary>
    /// The Unlocks page.
    /// </summary>
    public const string UnlocksPage = "unlocks";

    /// <summary>
    /// The kind of Amira's objective.
    /// </summary>
    public const string MainKind = "main";

    /// <summary>
    /// The kind of Amira's numbered side quests.
    /// </summary>
    public const string SideKind = "side";

    /// <summary>
    /// The kind of the companions' requests on the Pocket Castle's board.
    /// </summary>
    public const string CompanionKind = "companion";

    /// <summary>
    /// What joins a quest's name and who tells it in its title.
    /// </summary>
    public const string TitleJoin = " · ";

    /// <summary>
    /// What the list says of the objective.
    /// </summary>
    public const string ObjectiveLabel = "Objective";

    /// <summary>
    /// The World page's caption of the players online.
    /// </summary>
    public const string PlayersCaption = "Players online";

    /// <summary>
    /// How the World page writes the players online and the world's seats.
    /// </summary>
    public const string PlayersOf = "{0} / {1}";

    /// <summary>
    /// The World page's caption of a Raid World's story.
    /// </summary>
    public const string StoryCaption = "Story";

    /// <summary>
    /// What the World page says of a Classic world's story.
    /// </summary>
    public const string ClassicStory = "Each party plays its leader's story.";

    /// <summary>
    /// The World page's heading over a section's raid bosses, with how many it holds.
    /// </summary>
    public const string BossSection = "{0} ({1})";

    /// <summary>
    /// What the World page says of a Raid World without raid bosses to list.
    /// </summary>
    public const string NoBosses = "No raid bosses yet.";

    /// <summary>
    /// What the World page says of raid bosses in a Classic world.
    /// </summary>
    public const string ClassicBosses = "Raid bosses fight in Raid Worlds.";

    /// <summary>
    /// What a quest group and the Quests page's head say without quests.
    /// </summary>
    public const string NoQuests = "None right now.";

    /// <summary>
    /// A level's heading on the Unlocks page.
    /// </summary>
    public const string LevelHeading = "Level {0}";

    /// <summary>
    /// The Unlocks page's title with the level characters catch up to.
    /// </summary>
    public const string ExpHeading = "Catch-up EXP until level {0}";

    /// <summary>
    /// The Unlocks page's title before the catch-up starts.
    /// </summary>
    public const string ExpHeadingNone = "Catch-up EXP";

    /// <summary>
    /// What the Unlocks page says before the catch-up starts.
    /// </summary>
    public const string NoCatchUp = "Starts once the world's story raises the level cap.";

    /// <summary>
    /// What the Unlocks page says without levels.
    /// </summary>
    public const string NothingUnlocked = "Nothing to catch up with yet.";

    /// <summary>
    /// The note of the Unlocks page's head with the player's level.
    /// </summary>
    public const string YourLevelNote = "Your level {0}";

    /// <summary>
    /// The Unlocks page's group of the levels whose every unlock the player got.
    /// </summary>
    public const string Passed = "Passed ({0})";

    /// <summary>
    /// The Unlocks page's group of the levels still to come.
    /// </summary>
    public const string ComingUp = "Coming up ({0})";

    /// <summary>
    /// The key of the Unlocks page's passed levels' group.
    /// </summary>
    public const string PassedKey = "passed";

    /// <summary>
    /// The key of the Unlocks page's coming levels' group.
    /// </summary>
    public const string ComingKey = "coming";

    /// <summary>
    /// What the list says of a level with an unlock due.
    /// </summary>
    public const string DueText = "Due";

    /// <summary>
    /// The quests' titles in the reading pane by their kind, a side quest's with its number.
    /// </summary>
    public static readonly IReadOnlyDictionary<string, string> QuestTitles = new Dictionary<string, string>(StringComparer.Ordinal)
    {
        [MainKind] = "Main quest", [SideKind] = "Side quest {0}", [CompanionKind] = "Request",
    };

    /// <summary>
    /// The Quests page's headings over its groups by their kind, with how many each holds.
    /// </summary>
    public static readonly IReadOnlyDictionary<string, string> QuestHeadings = new Dictionary<string, string>(StringComparer.Ordinal)
    {
        [SideKind] = "Side quests ({0})", [CompanionKind] = "Companion quests ({0})",
    };

    /// <summary>
    /// Words before a full stop that end no sentence, such as in "Mt. Saint Amos".
    /// </summary>
    public static readonly IReadOnlyList<string> Abbreviations = ["Mt", "Dr", "Mr", "Mrs", "Ms", "St"];

    /// <summary>
    /// The end of a sentence: its marks with closing quotes or brackets, followed by a space or the
    /// text's end, or a Japanese one.
    /// </summary>
    private static readonly Regex SentenceEnd = new("[.!?♪…]+[\"'”’)」』）]*(?=[ \\t\\n\\v\\f\\r]|\\z)|[。！？]+[」』）]*", RegexOptions.CultureInvariant);

    /// <summary>
    /// The last word of a text, as Ruby's <c>\S+\z</c> finds it.
    /// </summary>
    private static readonly Regex LastWord = new("[^ \\t\\n\\v\\f\\r]+\\z", RegexOptions.CultureInvariant);

    /// <summary>
    /// The whitespace Ruby 1.9's <c>String#strip</c> takes off.
    /// </summary>
    private static readonly char[] Spaces = [' ', '\t', '\n', '\v', '\f', '\r'];

    /// <summary>
    /// Lays the World page out: the players online and the story at the top; Amira's objective and
    /// in a Raid World every raid boss by its section in the list.
    /// </summary>
    /// <param name="facts">What the page shows besides the pools.</param>
    /// <param name="folds">The groups the player opened or folded.</param>
    /// <param name="pools">The world's pools as they stand now, by key.</param>
    /// <param name="told">The pools' keys in the order they were last told.</param>
    /// <returns>The page; the scripts write its title and note.</returns>
    public static OverviewModel World(OverviewWorldFacts facts, OverviewFolds folds, IReadOnlyList<PoolView> pools, IReadOnlyList<string> told)
    {
        ArgumentNullException.ThrowIfNull(facts);
        string online = facts.Seats > 0 ? Format(PlayersOf, facts.Online, facts.Seats) : facts.Online.ToString(CultureInfo.InvariantCulture);
        var list = new List<OverviewItem>();
        var entries = new List<OverviewEntry>();
        if (facts.Main is { } main)
        {
            var objective = new OverviewNote(ObjectiveLabel, main.Texts);
            list.Add(new OverviewItem(null, objective));
            entries.Add(objective);
        }

        var sections = facts.Raid ? OverviewBosses.Sections(facts, pools, told) : [];
        foreach ((string section, IReadOnlyList<OverviewBoss> bosses) in sections)
        {
            List<OverviewEntry> group = [.. bosses.Select(boss => new OverviewBossEntry(boss, section, OverviewBosses.Pane(boss, section, facts.Tiers)))];
            AddGroup(list, folds, WorldPage, section, Format(BossSection, section, bosses.Count), true, group);
            entries.AddRange(group);
        }

        if (sections.Count == 0)
        {
            list.Add(new OverviewItem(facts.Raid ? NoBosses : ClassicBosses, null));
        }

        var players = new OverviewField(PlayersCaption, online);
        OverviewHead head = facts.Raid
            ? new(null, null, [players, new OverviewField(StoryCaption, OverviewText.WorldStoryText(facts.Story?.Part))], [], null)
            : new(null, null, [players], [ClassicStory], null);
        return new OverviewModel(head, list, PicksOf(list), LabelsOf(entries));
    }

    /// <summary>
    /// Lays the Quests page out: the main quest at the top, the side quests numbered and the
    /// companions' requests in the list, each as <see cref="Told"/> tells it; one that says nothing
    /// is left out.
    /// </summary>
    /// <param name="main">The messages of Amira's objective.</param>
    /// <param name="sides">The messages of each side quest Amira tells now.</param>
    /// <param name="companions">The messages of each companion's request on the board now.</param>
    /// <param name="folds">The groups the player opened or folded.</param>
    /// <returns>The page; the scripts add how Amira and the companions look.</returns>
    public static OverviewModel Quests(IReadOnlyList<OverviewMessage> main, IReadOnlyList<IReadOnlyList<OverviewMessage>> sides, IReadOnlyList<IReadOnlyList<OverviewMessage>> companions, OverviewFolds folds)
    {
        ArgumentNullException.ThrowIfNull(sides);
        ArgumentNullException.ThrowIfNull(companions);
        List<OverviewQuestText> sideQuests = [.. sides.Select(quest => Told(quest, true)).OfType<OverviewQuestText>()];
        List<OverviewQuestText> requests = [.. companions.Select(quest => Told(quest, true)).OfType<OverviewQuestText>()];
        OverviewQuest? told = Told(main, false) is { } objective ? new OverviewQuest(MainKind, objective.Speaker, objective.Texts, null) : null;
        var head = new OverviewHead(QuestTitles[MainKind], null, [], [told?.First ?? NoQuests], told);
        var list = new List<OverviewItem>();
        List<OverviewQuest> sideEntries = [.. sideQuests.Select((quest, index) => new OverviewQuest(SideKind, quest.Speaker, quest.Texts, index + 1))];
        List<OverviewQuest> requestEntries = [.. requests.Select(quest => new OverviewQuest(CompanionKind, quest.Speaker, quest.Texts, null))];
        AddGroup(list, folds, QuestsPage, SideKind, Format(QuestHeadings[SideKind], sideQuests.Count), true, sideEntries, NoQuests);
        AddGroup(list, folds, QuestsPage, CompanionKind, Format(QuestHeadings[CompanionKind], requests.Count), true, requestEntries, NoQuests);
        return new OverviewModel(head, list, [.. told is null ? [] : new OverviewEntry[] { told }, .. PicksOf(list)], LabelsOf([.. sideEntries, .. requestEntries]));
    }

    /// <summary>
    /// Tells what a quest says: its messages with a text, by the speaker of the first of them.
    /// </summary>
    /// <remarks>An entry of Amira's lists or of the board counts its first speaker alone, so the others' remarks in between stay out.</remarks>
    /// <param name="messages">Its messages as the scripts looked them up.</param>
    /// <param name="firstSpeakerOnly">Whether only the first speaker's messages count, as for an entry; the objective counts every one.</param>
    /// <returns>The quest, <see langword="null"/> when it says nothing.</returns>
    public static OverviewQuestText? Told(IReadOnlyList<OverviewMessage> messages, bool firstSpeakerOnly)
    {
        ArgumentNullException.ThrowIfNull(messages);
        List<OverviewMessage> said = [.. messages.Where(message => message.Text.Length > 0)];
        if (said.Count == 0)
        {
            return null;
        }

        string? speaker = said[0].Speaker;
        return new OverviewQuestText(speaker, [.. said.Where(message => !firstSpeakerOnly || message.Speaker == speaker).Select(message => message.Text)]);
    }

    /// <summary>
    /// Lays the Unlocks page out: the catch-up's target and the player's level at the top; the
    /// levels whose every unlock the player got folded under Passed, the others under Coming up.
    /// </summary>
    /// <param name="target">The level characters catch up to, <see langword="null"/> before the catch-up starts.</param>
    /// <param name="level">The player's level as the catch-up counts it, <see langword="null"/> for none.</param>
    /// <param name="unlocks">What the catch-up hands out, by level.</param>
    /// <param name="folds">The groups the player opened or folded.</param>
    /// <returns>The page; the scripts add Luka's looks and the formation's grid.</returns>
    public static OverviewModel Unlocks(int? target, int? level, IReadOnlyList<OverviewUnlock> unlocks, OverviewFolds folds)
    {
        ArgumentNullException.ThrowIfNull(unlocks);
        var head = new OverviewHead(target is { } to ? Format(ExpHeading, to) : ExpHeadingNone, level is { } at ? Format(YourLevelNote, at) : null, [],
            target is null ? [NoCatchUp] : [], null);
        List<OverviewLevel> levels = [.. unlocks.Select((unlock, index) => (unlock, index)).GroupBy(pair => pair.unlock.Level).OrderBy(group => group.Key)
            .Select(group => new OverviewLevel(group.Key, [.. group.Select(pair => pair.index)], [.. group.Select(pair => pair.unlock.Name)],
                group.All(pair => pair.unlock.Got), group.Any(pair => pair.unlock.Due)))];
        List<OverviewLevel> passed = [.. levels.Where(entry => entry.Got)];
        List<OverviewLevel> coming = [.. levels.Where(entry => !entry.Got)];
        var list = new List<OverviewItem>();
        if (passed.Count > 0)
        {
            AddGroup(list, folds, UnlocksPage, PassedKey, Format(Passed, passed.Count), false, passed);
        }

        if (levels.Count > 0)
        {
            AddGroup(list, folds, UnlocksPage, ComingKey, Format(ComingUp, coming.Count), true, coming);
        }
        else
        {
            list.Add(new OverviewItem(NothingUnlocked, null));
        }

        return new OverviewModel(head, list, PicksOf(list), LabelsOf(levels));
    }

    /// <summary>
    /// Finds a text's first sentence: up to the first end of a sentence followed by a space or the
    /// text's end, or a Japanese one; an abbreviation such as "Mt." ends none.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The sentence; the whole text without an end.</returns>
    public static string FirstSentence(string? text)
    {
        string whole = Strip(text ?? string.Empty);
        int offset = 0;
        for (Match end = SentenceEnd.Match(whole, offset); end.Success; end = SentenceEnd.Match(whole, offset))
        {
            string word = LastWord.Match(whole[..end.Index]).Value;
            if (!Abbreviations.Contains(word, StringComparer.Ordinal))
            {
                return Strip(whole[..(end.Index + end.Length)]);
            }

            offset = end.Index + end.Length;
        }

        return whole;
    }

    /// <summary>
    /// Adds a group to a list: its row, which folds it, and while open its entries, or a text without any.
    /// </summary>
    /// <param name="list">The list's rows.</param>
    /// <param name="folds">The groups the player opened or folded.</param>
    /// <param name="page">The page.</param>
    /// <param name="key">The group's key.</param>
    /// <param name="title">Its title.</param>
    /// <param name="open">Whether it starts open.</param>
    /// <param name="entries">Its entries.</param>
    /// <param name="empty">What it says without entries, <see langword="null"/> for nothing.</param>
    private static void AddGroup(List<OverviewItem> list, OverviewFolds folds, string page, string key, string title, bool open, IReadOnlyList<OverviewEntry> entries, string? empty = null)
    {
        var fold = new OverviewFold(key, title, folds.IsOpen(page, key, open));
        list.Add(new OverviewItem(null, fold));
        if (!fold.Open)
        {
            return;
        }

        if (entries.Count == 0 && empty is not null)
        {
            list.Add(new OverviewItem(empty, null));
        }

        list.AddRange(entries.Select(entry => new OverviewItem(null, entry)));
    }

    /// <summary>
    /// Lists what can be picked of a list's rows: its groups and their entries.
    /// </summary>
    /// <param name="list">The rows.</param>
    /// <returns>The groups and the entries, in their order.</returns>
    private static List<OverviewEntry> PicksOf(List<OverviewItem> list) => [.. list.Select(item => item.Entry).OfType<OverviewEntry>()];

    /// <summary>
    /// Lists the labels of entries as their rows show them, each once.
    /// </summary>
    /// <param name="entries">The entries.</param>
    /// <returns>The labels.</returns>
    private static List<string> LabelsOf(IEnumerable<OverviewEntry> entries) =>
        [.. entries.Select(entry => entry.Row().Label).OfType<string>().Where(label => label.Length > 0).Distinct(StringComparer.Ordinal)];

    /// <summary>
    /// Takes the whitespace off a text's ends as Ruby 1.9's <c>String#strip</c> does, nulls at its end too.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The text without them.</returns>
    private static string Strip(string text) => text.TrimStart(Spaces).TrimEnd([.. Spaces, '\0']);

    /// <summary>
    /// Fills a text's places.
    /// </summary>
    /// <param name="format">The text.</param>
    /// <param name="values">The values.</param>
    /// <returns>The text filled in.</returns>
    private static string Format(string format, params object[] values) => string.Format(CultureInfo.InvariantCulture, format, values);
}
