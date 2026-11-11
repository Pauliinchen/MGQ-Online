//----------------------------------------------------------------
//  CatchupTables.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Kept the items unlocking a job or race, as the events database lists them
//      Paulinchen  2026-11-05: Dropped the counts of prizes, which the story replay hands over after the log
//                            - Kept the items an event of the game takes away, which the reward repair never gives back
//      Paulinchen  2026-11-01: Kept which players the companions of the Alice and Ilias choice may join
//      Paulinchen  2026-10-31: Dropped the maps where warping is free, since a world never bans warping
//                            - Read a world chest without its chest flags, which only released builds read
//      Paulinchen  2026-10-28: Read the steps of the story in free order
//                            - Read the switches of prizes handed out once
//                            - Read a world chest the game shuts by a switch
//                            - Read the rewards a party member catches up with, every chest and the chest flags
//                            - Kept what the catch-up's engine works out of the tables once
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Game.Story;
using static MGQOnline.Game.Story.JsonFields;

namespace MGQOnline.Game.Catchup;

/// <summary>
/// The catch-up's tables the relay keeps beside the story mapping (Relay/README.md "Catch-up
/// tables"), read from the mapping games fetch: what carries a Raid World player behind along with
/// the world's story, in the story's order, and what a party member of a Classic world catches up
/// with. A row this version cannot read is left out.
/// </summary>
public sealed class CatchupTables
{
    /// <summary>
    /// The tables while no mapping came, every one empty.
    /// </summary>
    public static readonly CatchupTables Empty = new();

    /// <summary>
    /// The names the relay's rows give a side.
    /// </summary>
    private static readonly string[] Sides = ["alice", "ilias"];

    /// <summary>
    /// Gets the story's parts in their order.
    /// </summary>
    public IReadOnlyList<CatchupPart> Parts { get; private set; } = [];

    /// <summary>
    /// Gets every story join of a companion.
    /// </summary>
    public IReadOnlyList<CatchupJoin> Joins { get; private set; } = [];

    /// <summary>
    /// Gets every removal of a companion by the story.
    /// </summary>
    public IReadOnlyList<CatchupRemoval> Removals { get; private set; } = [];

    /// <summary>
    /// Gets every key item the story gives or takes.
    /// </summary>
    public IReadOnlyList<CatchupKeyItem> KeyItems { get; private set; } = [];

    /// <summary>
    /// Gets the chests that hold key items.
    /// </summary>
    public IReadOnlyList<CatchupChest> Chests { get; private set; } = [];

    /// <summary>
    /// Gets every skill Luka learns and item the story gives.
    /// </summary>
    public IReadOnlyList<CatchupReward> Rewards { get; private set; } = [];

    /// <summary>
    /// Gets every skill the story teaches a companion.
    /// </summary>
    public IReadOnlyList<CatchupLesson> Lessons { get; private set; } = [];

    /// <summary>
    /// Gets every class and race the story gives a character.
    /// </summary>
    public IReadOnlyList<CatchupClassLevel> ClassLevels { get; private set; } = [];

    /// <summary>
    /// Gets what the story's events change of the characters outright.
    /// </summary>
    public IReadOnlyList<CatchupActorChange> ActorChanges { get; private set; } = [];

    /// <summary>
    /// Gets every setting of a player's own value by the story's events.
    /// </summary>
    public IReadOnlyList<CatchupSetting> Settings { get; private set; } = [];

    /// <summary>
    /// Gets every event that puts a vehicle on a map.
    /// </summary>
    public IReadOnlyList<CatchupVehicle> Vehicles { get; private set; } = [];


    /// <summary>
    /// Gets every Makina with its level.
    /// </summary>
    public IReadOnlyList<CatchupMakina> Makina { get; private set; } = [];

    /// <summary>
    /// Gets the switches of the Medal King's one-of-a-kind exchanges, see <see cref="MedalKingGift"/>.
    /// </summary>
    public IReadOnlyList<int> PrizeSwitches { get; private set; } = [];

    /// <summary>
    /// Gets the items, weapons and armors an event of the game takes away, such as "w4112", from the
    /// events database (<see cref="NoteItemsTaken"/>), or from the table <c>taken_items</c> of the
    /// golden cases.
    /// </summary>
    public IReadOnlySet<string> TakenItems { get; private set; } = new HashSet<string>(StringComparer.Ordinal);

    /// <summary>
    /// Gets the items that unlock a job or a race, from the events database
    /// (<see cref="NoteUnlockItems"/>).
    /// </summary>
    public IReadOnlySet<long> UnlockItems { get; private set; } = new HashSet<long>();

    /// <summary>
    /// Gets the least a variable holds once a companion is in the roster.
    /// </summary>
    public IReadOnlyList<CompanionValue> CompanionValues { get; private set; } = [];

    /// <summary>
    /// Gets the variables that count switches.
    /// </summary>
    public IReadOnlyList<CatchupCount> Counts { get; private set; } = [];

    /// <summary>
    /// Gets the rules of the catch-up.
    /// </summary>
    public CatchupRules Rules { get; private set; } = CatchupRules.Empty;

    /// <summary>
    /// Gets the rewards of the game's events a party member catches up with.
    /// </summary>
    public IReadOnlyList<EventReward> EventRewards { get; private set; } = [];

    /// <summary>
    /// Gets the events that give each side other skills or companions.
    /// </summary>
    public IReadOnlyList<SideEvent> SideEvents { get; private set; } = [];

    /// <summary>
    /// Gets the self switch of every chest of the game.
    /// </summary>
    public IReadOnlyList<StoryKey> PartyChests { get; private set; } = [];

    /// <summary>
    /// Gets the switches only chests turn on.
    /// </summary>
    public IReadOnlyList<int> ChestFlags { get; private set; } = [];

    /// <summary>
    /// Gets what the catch-up's engine works out of the tables once, built at its first look.
    /// </summary>
    internal CatchupIndex Index => _index ??= new CatchupIndex(this);

    /// <summary>
    /// Gets which players the companions of the Alice and Ilias choice may join, built at its first ask.
    /// </summary>
    public CompanionScope Scope => _scope ??= new CompanionScope(this);

    /// <summary>
    /// The index, <see langword="null"/> before the first look.
    /// </summary>
    private CatchupIndex? _index;

    /// <summary>
    /// The scope of the companions, <see langword="null"/> before the first ask.
    /// </summary>
    private CompanionScope? _scope;

    /// <summary>
    /// Reads the catch-up's tables of a mapping.
    /// </summary>
    /// <param name="tables">The mapping's <c>tables</c> by name.</param>
    /// <returns>The tables.</returns>
    public static CatchupTables Read(JsonElement tables)
    {
        var read = new CatchupTables
        {
            Parts = Rows(tables, "parts", PartOf),
            Joins = Rows(tables, "joins", JoinOf),
            Removals = Rows(tables, "removals", RemovalOf),
            KeyItems = Rows(tables, "key_items", KeyItemOf),
            Chests = Rows(tables, "chests", ChestOf),
            Rewards = Rows(tables, "rewards", RewardOf),
            Lessons = Rows(tables, "lessons", LessonOf),
            ClassLevels = Rows(tables, "class_levels", ClassLevelOf),
            ActorChanges = Rows(tables, "actor_changes", ActorChangeOf),
            Settings = Rows(tables, "settings", SettingOf),
            Vehicles = Rows(tables, "vehicles", VehicleOf),

            Makina = Rows(tables, "makina", MakinaOf),
            PrizeSwitches = IdsOf(tables, "prize_switches", "switch"),
            CompanionValues = Rows(tables, "companion_values", CompanionValueOf),
            Counts = Rows(tables, "counts", CountOf),
            EventRewards = Rows(tables, "event_rewards", EventRewardOf),
            SideEvents = Rows(tables, "side_events", SideEventOf),
            PartyChests = SelfSwitchesOf(tables, "party_chests"),
            ChestFlags = IdsOf(tables, "chest_flags", "switch"),
        };
        read.Rules = RulesOf(tables);
        read.TakenItems = new HashSet<string>(RowsOf(tables, "taken_items").Where(row => row.TryGetProperty("item", out JsonElement item) && item.ValueKind == JsonValueKind.String)
            .Select(row => row.GetProperty("item").GetString()!), StringComparer.Ordinal);
        return read;
    }

    /// <summary>
    /// Keeps the items an event of the game takes away, as the events database lists them, once.
    /// </summary>
    /// <param name="items">The items, see <see cref="TakenItems"/>.</param>
    public void NoteItemsTaken(IEnumerable<string> items)
    {
        if (TakenItems.Count == 0)
        {
            TakenItems = new HashSet<string>(items, StringComparer.Ordinal);
        }
    }

    /// <summary>
    /// Keeps the items that unlock a job or a race, as the events database lists them, once.
    /// </summary>
    /// <param name="items">The items' ids.</param>
    public void NoteUnlockItems(IEnumerable<int> items)
    {
        if (UnlockItems.Count == 0)
        {
            UnlockItems = new HashSet<long>(items.Select(id => (long)id));
        }
    }

    /// <summary>
    /// Reads the rows of a table that read.
    /// </summary>
    /// <typeparam name="T">The row.</typeparam>
    /// <param name="tables">The tables.</param>
    /// <param name="name">The table.</param>
    /// <param name="read">Reads a row, <see langword="null"/> for one that does not read.</param>
    /// <returns>The rows in the table's order.</returns>
    private static List<T> Rows<T>(JsonElement tables, string name, Func<JsonElement, T?> read)
        where T : notnull
    {
        var rows = new List<T>();
        foreach (JsonElement row in RowsOf(tables, name))
        {
            if (read(row) is { } found)
            {
                rows.Add(found);
            }
        }

        return rows;
    }

    /// <summary>
    /// Reads one id of each row of a table.
    /// </summary>
    /// <param name="tables">The tables.</param>
    /// <param name="name">The table.</param>
    /// <param name="field">The field that holds the id.</param>
    /// <returns>The ids of the rows that read, in the table's order.</returns>
    private static List<int> IdsOf(JsonElement tables, string name, string field)
    {
        var ids = new List<int>();
        foreach (JsonElement row in RowsOf(tables, name))
        {
            if (Whole(row, field, out long id))
            {
                ids.Add((int)id);
            }
        }

        return ids;
    }

    /// <summary>
    /// Reads the rules of the <c>rules</c> table, each by its row.
    /// </summary>
    /// <param name="tables">The tables.</param>
    /// <returns>The rules.</returns>
    private static CatchupRules RulesOf(JsonElement tables)
    {
        CatchupRules rules = CatchupRules.Empty;
        foreach (JsonElement row in RowsOf(tables, "rules"))
        {
            if (!row.TryGetProperty("value", out JsonElement value))
            {
                continue;
            }

            switch (Text(row, "rule"))
            {
                case "lasting_companions" when Ids(value) is { } lasting:
                    rules = rules with { LastingCompanions = lasting };
                    break;
                case "orbs" when Ids(value) is { } orbs:
                    rules = rules with { Orbs = orbs };
                    break;
                case "orb_event" when Whole(value, out long orbEvent):
                    rules = rules with { OrbEvent = (int)orbEvent };
                    break;
                case "orbs_gathered" when Whole(value, out long gathered):
                    rules = rules with { OrbsGathered = gathered };
                    break;
                case "side_step" when Whole(value, out long step):
                    rules = rules with { SideStep = step };
                    break;
                case "side_companions" when value.ValueKind == JsonValueKind.Object && Whole(value, "alice", out long alice) && Whole(value, "ilias", out long ilias):
                    rules = rules with { AliceCompanion = (int)alice, IliasCompanion = (int)ilias };
                    break;
                case "free_order" when PartStepsOf(value) is { } steps:
                    rules = rules with { FreeOrder = steps };
                    break;
            }
        }

        return rules;
    }

    /// <summary>
    /// Reads a list of steps of parts, each <c>{part, step}</c>.
    /// </summary>
    /// <param name="value">The list.</param>
    /// <returns>The steps, <see langword="null"/> for a value that does not read.</returns>
    private static List<PartStep>? PartStepsOf(JsonElement value)
    {
        if (value.ValueKind != JsonValueKind.Array)
        {
            return null;
        }

        var steps = new List<PartStep>();
        foreach (JsonElement entry in value.EnumerateArray())
        {
            if (entry.ValueKind != JsonValueKind.Object || Text(entry, "part") is not { Length: > 0 } part || !Whole(entry, "step", out long step))
            {
                return null;
            }

            steps.Add(new PartStep(part, step));
        }

        return steps;
    }

    /// <summary>
    /// Reads a part.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>The part, <see langword="null"/> for a row that does not read.</returns>
    private static CatchupPart? PartOf(JsonElement row) =>
        Text(row, "id") is { Length: > 0 } id && Whole(row, "gate", out long gate) && MarksOf(row, "ending") is { } ending ? new CatchupPart(id, Text(row, "name"), ending, (int)gate) : null;

    /// <summary>
    /// Reads a join.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>The join, <see langword="null"/> for a row that does not read.</returns>
    private static CatchupJoin? JoinOf(JsonElement row) =>
        Whole(row, "actor", out long actor) && Whole(row, "persona", out long persona) && PlaceOf(row) is { } place && Whole(row, "gate", out long gate)
            && Text(row, "rule") is { Length: > 0 } rule && Whole(row, "index", out long index) && Flag(row, "ran", out bool ran)
            ? new CatchupJoin((int)actor, (int)persona, place, (int)gate, rule, (int)index, ran)
            : null;

    /// <summary>
    /// Reads a removal.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>The removal, <see langword="null"/> for a row that does not read.</returns>
    private static CatchupRemoval? RemovalOf(JsonElement row) =>
        Whole(row, "actor", out long actor) && Whole(row, "persona", out long persona) && PlaceOf(row) is { } place && Flag(row, "first", out bool first) && Whole(row, "index", out long index)
            ? new CatchupRemoval((int)actor, (int)persona, place, first, (int)index)
            : null;

    /// <summary>
    /// Reads a key item row.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>The row, <see langword="null"/> for one that does not read.</returns>
    private static CatchupKeyItem? KeyItemOf(JsonElement row) =>
        Whole(row, "item", out long item) && Whole(row, "amount", out long amount) && amount != 0 && PlaceOf(row) is { } place && Flag(row, "ran", out bool ran)
            ? new CatchupKeyItem((int)item, (int)amount, place, ran)
            : null;

    /// <summary>
    /// Reads a chest.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>The chest, <see langword="null"/> for a row that does not read.</returns>
    private static CatchupChest? ChestOf(JsonElement row) =>
        StoryKey.TryParse(Text(row, "key"), out StoryKey key) && key.Kind is StoryKeyKind.SelfSwitch or StoryKeyKind.Switch && Numbers(row, "items", out List<long> items) && items.Count > 0
            && WholeOrNull(row, "step", out long? step)
            ? new CatchupChest(key, Ints(items), TextOrNull(row, "part"), step)
            : null;

    /// <summary>
    /// Reads a reward.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>The reward, <see langword="null"/> for a row that does not read.</returns>
    private static CatchupReward? RewardOf(JsonElement row) =>
        Text(row, "kind") is "skill" or "item" or "weapon" or "armor" && Whole(row, "id", out long id) && Whole(row, "amount", out long amount) && amount != 0
            && PlaceOf(row) is { } place && Flag(row, "ran", out bool ran)
            ? new CatchupReward(Text(row, "kind"), (int)id, (int)amount, place, ran)
            : null;

    /// <summary>
    /// Reads a lesson.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>The lesson, <see langword="null"/> for a row that does not read.</returns>
    private static CatchupLesson? LessonOf(JsonElement row) =>
        Whole(row, "actor", out long actor) && Whole(row, "skill", out long skill) && PlaceOf(row) is { } place && Flag(row, "ran", out bool ran)
            ? new CatchupLesson((int)actor, (int)skill, place, ran)
            : null;

    /// <summary>
    /// Reads a class level.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>The class level, <see langword="null"/> for a row that does not read.</returns>
    private static CatchupClassLevel? ClassLevelOf(JsonElement row) =>
        Whole(row, "actor", out long actor) && Whole(row, "class", out long classId) && Whole(row, "level", out long level) && PlaceOf(row) is { } place && Flag(row, "ran", out bool ran)
            ? new CatchupClassLevel((int)actor, (int)classId, (int)level, place, ran)
            : null;

    /// <summary>
    /// Reads an actor change.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>The change, <see langword="null"/> for a row that does not read.</returns>
    private static CatchupActorChange? ActorChangeOf(JsonElement row)
    {
        if (!Whole(row, "actor", out long actor) || !WholeOrNull(row, "gate", out long? gate) || PlaceOf(row) is not { } place || !Flag(row, "ran", out bool ran)
            || !row.TryGetProperty("calls", out JsonElement calls) || calls.ValueKind != JsonValueKind.Array)
        {
            return null;
        }

        var read = new List<ActorCall>();
        foreach (JsonElement call in calls.EnumerateArray())
        {
            if (call.ValueKind != JsonValueKind.Array || call.GetArrayLength() != 3 || call[0].ValueKind != JsonValueKind.String || !Numbers(call[1], out List<long> numbers)
                || numbers.Count == 0 || call[2].ValueKind is not (JsonValueKind.True or JsonValueKind.False))
            {
                return null;
            }

            read.Add(new ActorCall(call[0].GetString()!, numbers, call[2].ValueKind == JsonValueKind.True));
        }

        return read.Count > 0 ? new CatchupActorChange((int)actor, read, (int?)gate, place, ran) : null;
    }

    /// <summary>
    /// Reads a setting.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>The setting, <see langword="null"/> for a row that does not read.</returns>
    private static CatchupSetting? SettingOf(JsonElement row)
    {
        string kind = Text(row, "kind");
        if (kind is not ("variable" or "switch" or "encounters") || !Whole(row, "id", out long id) || PlaceOf(row) is not { } place || !Flag(row, "ran", out bool ran)
            || !row.TryGetProperty("value", out JsonElement value))
        {
            return null;
        }

        if (kind == "variable")
        {
            return Whole(value, out long number) ? new CatchupSetting(kind, (int)id, false, number, place, ran) : null;
        }

        return value.ValueKind is JsonValueKind.True or JsonValueKind.False ? new CatchupSetting(kind, (int)id, value.ValueKind == JsonValueKind.True, 0, place, ran) : null;
    }

    /// <summary>
    /// Reads a vehicle row.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>The row, <see langword="null"/> for one that does not read.</returns>
    private static CatchupVehicle? VehicleOf(JsonElement row) =>
        Text(row, "vehicle") is "boat" or "ship" or "airship" && PlaceOf(row) is { } place && Flag(row, "ran", out bool ran) ? new CatchupVehicle(Text(row, "vehicle"), place, ran) : null;

    /// <summary>
    /// Reads a Makina.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>The Makina, <see langword="null"/> for a row that does not read.</returns>
    private static CatchupMakina? MakinaOf(JsonElement row) =>
        Whole(row, "item", out long item) && Whole(row, "level", out long level) && Text(row, "site") is { Length: > 0 } site ? new CatchupMakina((int)item, (int)level, site) : null;

    /// <summary>
    /// Reads a companion value.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>The value, <see langword="null"/> for a row that does not read.</returns>
    private static CompanionValue? CompanionValueOf(JsonElement row) =>
        Whole(row, "actor", out long actor) && Whole(row, "variable", out long variable) && Whole(row, "atLeast", out long atLeast) ? new CompanionValue((int)actor, (int)variable, atLeast) : null;

    /// <summary>
    /// Reads a count.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>The count, <see langword="null"/> for a row that does not read.</returns>
    private static CatchupCount? CountOf(JsonElement row)
    {
        if (!Whole(row, "variable", out long variable) || !WholeOrNull(row, "doneSwitch", out long? doneSwitch) || !WholeOrNull(row, "doneValue", out long? doneValue)
            || (doneSwitch is null) != (doneValue is null) || !row.TryGetProperty("weights", out JsonElement weights) || weights.ValueKind != JsonValueKind.Array)
        {
            return null;
        }

        var read = new List<CountWeight>();
        foreach (JsonElement weight in weights.EnumerateArray())
        {
            if (weight.ValueKind != JsonValueKind.Object || !Whole(weight, "switch", out long id) || !Whole(weight, "weight", out long adds))
            {
                return null;
            }

            read.Add(new CountWeight((int)id, (int)adds));
        }

        int? sinceVariable = null;
        long sinceAtLeast = 0;
        if (row.TryGetProperty("since", out JsonElement since) && since.ValueKind != JsonValueKind.Null)
        {
            if (since.ValueKind != JsonValueKind.Object || !Whole(since, "variable", out long sinceId) || !Whole(since, "atLeast", out sinceAtLeast))
            {
                return null;
            }

            sinceVariable = (int)sinceId;
        }

        return read.Count > 0 ? new CatchupCount((int)variable, read, (int?)doneSwitch, doneValue, sinceVariable, sinceAtLeast) : null;
    }

    /// <summary>
    /// Reads a reward of the game's events.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>The reward, <see langword="null"/> for a row that does not read.</returns>
    private static EventReward? EventRewardOf(JsonElement row) =>
        Text(row, "kind") is "skill" or "companion" or "item" or "weapon" or "armor" && Whole(row, "id", out long id) && WholeOrNull(row, "most", out long? most)
            && Flag(row, "sided", out bool sided) && Flag(row, "route", out bool route) && Flag(row, "final", out bool final)
            ? new EventReward(Text(row, "kind"), (int)id, (int?)most, sided, route, final)
            : null;

    /// <summary>
    /// Reads a side event.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>The event, <see langword="null"/> for a row that does not read.</returns>
    private static SideEvent? SideEventOf(JsonElement row)
    {
        if (Text(row, "site") is not { Length: > 0 } site || SideRewardsOf(row, "alice") is not { } alice || SideRewardsOf(row, "ilias") is not { } ilias
            || !Flag(row, "choice", out bool choice) || !row.TryGetProperty("marks", out JsonElement pages) || pages.ValueKind != JsonValueKind.Array)
        {
            return null;
        }

        var marks = new List<IReadOnlyList<StoryMark>>();
        foreach (JsonElement page in pages.EnumerateArray())
        {
            if (MarksOf(page) is not { } read)
            {
                return null;
            }

            marks.Add(read);
        }

        return new SideEvent(site, alice, ilias, choice, marks);
    }

    /// <summary>
    /// Reads what one side of a side event gives.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <param name="name">The side.</param>
    /// <returns>Its rewards, <see langword="null"/> for a field that does not read.</returns>
    private static SideRewards? SideRewardsOf(JsonElement row, string name) =>
        row.TryGetProperty(name, out JsonElement side) && side.ValueKind == JsonValueKind.Object && Numbers(side, "skills", out List<long> skills)
            && Numbers(side, "companions", out List<long> companions)
            ? new SideRewards(Ints(skills), Ints(companions))
            : null;

    /// <summary>
    /// Reads the self switch of each row of a table, its <c>key</c>.
    /// </summary>
    /// <param name="tables">The tables.</param>
    /// <param name="name">The table.</param>
    /// <returns>The self switches of the rows that read, in the table's order.</returns>
    private static List<StoryKey> SelfSwitchesOf(JsonElement tables, string name)
    {
        var keys = new List<StoryKey>();
        foreach (JsonElement row in RowsOf(tables, name))
        {
            if (StoryKey.TryParse(Text(row, "key"), out StoryKey key) && key.Kind == StoryKeyKind.SelfSwitch)
            {
                keys.Add(key);
            }
        }

        return keys;
    }

    /// <summary>
    /// Reads a row's place in the story.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>The place, <see langword="null"/> for a row that does not read.</returns>
    private static StoryPlace? PlaceOf(JsonElement row)
    {
        string site = Text(row, "site");
        string? side = TextOrNull(row, "side");
        return site.Length > 0 && WholeOrNull(row, "step", out long? step) && (side is null || Array.IndexOf(Sides, side) >= 0) && MarksOf(row, "marks") is { } marks
            ? new StoryPlace(site, TextOrNull(row, "part"), step, side, marks)
            : null;
    }

    /// <summary>
    /// Reads a row's marks.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <param name="name">The field.</param>
    /// <returns>The marks, <see langword="null"/> for a field that does not read.</returns>
    private static List<StoryMark>? MarksOf(JsonElement row, string name) => row.TryGetProperty(name, out JsonElement list) ? MarksOf(list) : null;

    /// <summary>
    /// Reads a list of marks.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>The marks, <see langword="null"/> for a list that does not read.</returns>
    private static List<StoryMark>? MarksOf(JsonElement list)
    {
        if (list.ValueKind != JsonValueKind.Array)
        {
            return null;
        }

        var marks = new List<StoryMark>();
        foreach (JsonElement mark in list.EnumerateArray())
        {
            if (MarkOf(mark) is not { } read)
            {
                return null;
            }

            marks.Add(read);
        }

        return marks;
    }

    /// <summary>
    /// Reads a mark: <c>["s", switch]</c>, <c>["v", variable, at least]</c> or <c>["ss", map, event, letter]</c>.
    /// </summary>
    /// <param name="mark">The mark.</param>
    /// <returns>The mark, <see langword="null"/> for one that does not read.</returns>
    private static StoryMark? MarkOf(JsonElement mark)
    {
        if (mark.ValueKind != JsonValueKind.Array || mark.GetArrayLength() < 2 || mark[0].ValueKind != JsonValueKind.String)
        {
            return null;
        }

        switch (mark[0].GetString())
        {
            case "s" when mark.GetArrayLength() == 2 && Whole(mark[1], out long switchId) && switchId > 0:
                return new StoryMark(StoryKey.Switch((int)switchId));
            case "v" when mark.GetArrayLength() == 3 && Whole(mark[1], out long variable) && variable > 0 && Whole(mark[2], out long atLeast):
                return new StoryMark(StoryKey.Variable((int)variable), atLeast);
            case "ss" when mark.GetArrayLength() == 4 && Whole(mark[1], out long map) && Whole(mark[2], out long eventId) && mark[3].ValueKind == JsonValueKind.String && mark[3].GetString() is { Length: > 0 } letter:
                return new StoryMark(StoryKey.SelfSwitch((int)map, (int)eventId, letter));
            default:
                return null;
        }
    }

    /// <summary>
    /// Reads a list of ids.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The ids, <see langword="null"/> for a value that is no such list.</returns>
    private static List<int>? Ids(JsonElement value) => Numbers(value, out List<long> numbers) ? Ints(numbers) : null;

    /// <summary>
    /// Narrows numbers that fit an id.
    /// </summary>
    /// <param name="numbers">The numbers.</param>
    /// <returns>The ids.</returns>
    private static List<int> Ints(List<long> numbers)
    {
        var ids = new List<int>(numbers.Count);
        foreach (long number in numbers)
        {
            ids.Add((int)number);
        }

        return ids;
    }
}
