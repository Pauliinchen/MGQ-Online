//----------------------------------------------------------------
//  EventTables.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Added the pairs the one-time repair of stuck saves completes
//                            - Added the lists that give and the branches of each choice
//      Paulinchen  2026-10-28: Read the views
//                            - Keyed pages by site
//                            - Created
//
//----------------------------------------------------------------

using System;

namespace MGQOnline.Data.Events;

/// <summary>
/// How each table of <see cref="EventSchema"/> is written and read, besides meta and counts.
/// </summary>
internal static class EventTables
{
    /// <summary>The fingerprint's parts.</summary>
    public static readonly TableShape<FingerprintPart> FingerprintParts = new(
        "fingerprint_parts",
        ["part_no", "part", "crc", "id_count"],
        r => r.PartNo,
        (w, r) => w.Int(r.PartNo).Text(r.Part).Text(r.Crc).Int(r.IdCount),
        r => new FingerprintPart(r.Int(), r.TextNotNull(), r.TextNotNull(), r.Int()));

    /// <summary>The maps.</summary>
    public static readonly TableShape<MapRow> Maps = new(
        "maps",
        ["id", "folder", "number", "parent_id", "tileset_id", "has_file", "cutscene"],
        r => r.Id,
        (w, r) => w.Int(r.Id).Int(r.Folder).Int(r.Number).Int(r.ParentId).Int(r.TilesetId).Flag(r.HasFile).Flag(r.Cutscene),
        r => new MapRow(r.Int(), r.Int(), r.Int(), r.Int(), r.Int(), r.Flag(), r.Flag()));

    /// <summary>The maps' random encounters.</summary>
    public static readonly TableShape<MapEncounterRow> MapEncounters = new(
        "map_encounters",
        ["map_id", "ord", "troop_id", "weight"],
        r => (r.MapId, r.Ord),
        (w, r) => w.Int(r.MapId).Int(r.Ord).Int(r.TroopId).Int(r.Weight),
        r => new MapEncounterRow(r.Int(), r.Int(), r.Int(), r.Int()));

    /// <summary>The maps' events.</summary>
    public static readonly TableShape<MapEventRow> MapEvents = new(
        "map_events",
        ["map_id", "event_id", "x", "y", "page_count"],
        r => (r.MapId, r.EventId),
        (w, r) => w.Int(r.MapId).Int(r.EventId).Int(r.X).Int(r.Y).Int(r.PageCount),
        r => new MapEventRow(r.Int(), r.Int(), r.Int(), r.Int(), r.Int()));

    /// <summary>The lists of commands.</summary>
    public static readonly TableShape<ListRow> Lists = new(
        "lists",
        ["list_id", "kind", "map_id", "event_id", "page_no", "common_id", "troop_id", "troop_page_no", "count_all", "count_kept", "shape"],
        r => r.ListId,
        (w, r) => w.Int(r.ListId).Int((int)r.Kind).Int(r.MapId).Int(r.EventId).Int(r.PageNo).Int(r.CommonId).Int(r.TroopId)
            .Int(r.TroopPageNo).Int(r.CountAll).Int(r.CountKept).Int(r.Shape),
        r => new ListRow(r.Int(), (ListKind)r.Int(), r.IntOrNull(), r.IntOrNull(), r.IntOrNull(), r.IntOrNull(), r.IntOrNull(), r.IntOrNull(), r.Int(), r.Int(), r.Int()));

    /// <summary>The map events' pages.</summary>
    public static readonly TableShape<PageRow> Pages = new(
        "pages",
        [
            "list_id", "map_id", "event_id", "page_no", "trigger", "cond_switch1", "cond_switch2", "cond_variable", "cond_value",
            "cond_self_switch", "cond_item", "cond_actor", "move_type", "kind_new_game", "chest_letter", "scene_page", "runs_nothing",
            "has_fade_in", "sets_encounters",
        ],
        r => (r.MapId, r.EventId, r.PageNo),
        (w, r) => w.Int(r.ListId).Int(r.MapId).Int(r.EventId).Int(r.PageNo).Int(r.Trigger).Int(r.CondSwitch1).Int(r.CondSwitch2)
            .Int(r.CondVariable).Int(r.CondValue).Text(r.CondSelfSwitch).Int(r.CondItem).Int(r.CondActor).Int(r.MoveType)
            .Int(r.KindNewGame).Text(r.ChestLetter).Flag(r.ScenePage).Flag(r.RunsNothing).Flag(r.HasFadeIn).Flag(r.SetsEncounters),
        r => new PageRow(
            r.Int(), r.Int(), r.Int(), r.Int(), r.Int(), r.IntOrNull(), r.IntOrNull(), r.IntOrNull(), r.Long(), r.Text(), r.IntOrNull(),
            r.IntOrNull(), r.Int(), r.IntOrNull(), r.Text(), r.Flag(), r.Flag(), r.Flag(), r.FlagOrNull()));

    /// <summary>The common events.</summary>
    public static readonly TableShape<CommonEventRow> CommonEvents = new(
        "common_events",
        ["id", "list_id", "trigger", "switch_id", "own", "leading_marks", "battlefuck", "final_chapter", "fades_in"],
        r => r.Id,
        (w, r) => w.Int(r.Id).Int(r.ListId).Int(r.Trigger).Int(r.SwitchId).Flag(r.Own).Int(r.LeadingMarks).Flag(r.Battlefuck)
            .Flag(r.FinalChapter).Flag(r.FadesIn),
        r => new CommonEventRow(r.Int(), r.Int(), r.Int(), r.Int(), r.Flag(), r.Int(), r.Flag(), r.Flag(), r.Flag()));

    /// <summary>The troops.</summary>
    public static readonly TableShape<TroopRow> Troops = new(
        "troops",
        ["id", "member_count", "page_count"],
        r => r.Id,
        (w, r) => w.Int(r.Id).Int(r.MemberCount).Int(r.PageCount),
        r => new TroopRow(r.Int(), r.Int(), r.Int()));

    /// <summary>The troops' enemies.</summary>
    public static readonly TableShape<TroopMemberRow> TroopMembers = new(
        "troop_members",
        ["troop_id", "position", "enemy_id", "x", "y", "hidden"],
        r => (r.TroopId, r.Position),
        (w, r) => w.Int(r.TroopId).Int(r.Position).Int(r.EnemyId).Int(r.X).Int(r.Y).Flag(r.Hidden),
        r => new TroopMemberRow(r.Int(), r.Int(), r.Int(), r.Int(), r.Int(), r.Flag()));

    /// <summary>The troops' pages.</summary>
    public static readonly TableShape<TroopPageRow> TroopPages = new(
        "troop_pages",
        [
            "list_id", "troop_id", "page_no", "span", "turn_ending", "turn_valid", "turn_a", "turn_b", "enemy_valid", "enemy_index",
            "enemy_hp", "actor_valid", "actor_id", "actor_hp", "switch_valid", "switch_id",
        ],
        r => r.ListId,
        (w, r) => w.Int(r.ListId).Int(r.TroopId).Int(r.PageNo).Int(r.Span).Flag(r.TurnEnding).Flag(r.TurnValid).Int(r.TurnA)
            .Int(r.TurnB).Flag(r.EnemyValid).Int(r.EnemyIndex).Int(r.EnemyHp).Flag(r.ActorValid).Int(r.ActorId).Int(r.ActorHp)
            .Flag(r.SwitchValid).Int(r.SwitchId),
        r => new TroopPageRow(
            r.Int(), r.Int(), r.Int(), r.Int(), r.Flag(), r.Flag(), r.Int(), r.Int(), r.Flag(), r.Int(), r.Int(), r.Flag(), r.Int(),
            r.Int(), r.Flag(), r.Int()));

    /// <summary>The kept commands.</summary>
    public static readonly TableShape<CommandRow> Commands = new(
        "commands",
        ["list_id", "ord", "idx", "code", "indent", "p0", "p1", "p2", "p3", "p4", "p5", "text_kind"],
        r => (r.ListId, r.Ord),
        (w, r) => w.Int(r.ListId).Int(r.Ord).Int(r.Idx).Int(r.Code).Int(r.Indent).Int(r.P0).Int(r.P1).Int(r.P2).Int(r.P3).Int(r.P4)
            .Int(r.P5).Int(r.TextKind),
        r => new CommandRow(r.Int(), r.Int(), r.Int(), r.Int(), r.Int(), r.Long(), r.Long(), r.Long(), r.Long(), r.Long(), r.Long(), r.Int()));

    /// <summary>What the lists read.</summary>
    public static readonly TableShape<ListReadRow> ListReads = new(
        "list_reads",
        ["list_id", "kind", "id", "sources"],
        r => (r.ListId, (int)r.Kind, r.Id),
        (w, r) => w.Int(r.ListId).Int((int)r.Kind).Int(r.Id).Int((int)r.Sources),
        r => new ListReadRow(r.Int(), (KeyKind)r.Int(), r.Int(), (ReadSources)r.Int()));

    /// <summary>What the lists set.</summary>
    public static readonly TableShape<ListWriteRow> ListWrites = new(
        "list_writes",
        ["list_id", "ord", "idx", "kind", "from_id", "to_id", "turns_on", "by_script", "value"],
        r => (r.ListId, r.Ord, (int)r.Kind, r.FromId),
        (w, r) => w.Int(r.ListId).Int(r.Ord).Int(r.Idx).Int((int)r.Kind).Int(r.FromId).Int(r.ToId).Flag(r.TurnsOn).Flag(r.ByScript).Int(r.Value),
        r => new ListWriteRow(r.Int(), r.Int(), r.Int(), (KeyKind)r.Int(), r.Int(), r.Int(), r.Flag(), r.Flag(), r.IntOrNull()));

    /// <summary>The self switches the lists set.</summary>
    public static readonly TableShape<ListSelfSwitchRow> ListSelfSwitches = new(
        "list_self_switches",
        ["list_id", "ord", "idx", "letter", "turns_on"],
        r => (r.ListId, r.Ord),
        (w, r) => w.Int(r.ListId).Int(r.Ord).Int(r.Idx).Text(r.Letter).Flag(r.TurnsOn),
        r => new ListSelfSwitchRow(r.Int(), r.Int(), r.Int(), r.TextNotNull(), r.Flag()));

    /// <summary>The common events the lists call.</summary>
    public static readonly TableShape<ListCallRow> ListCalls = new(
        "list_calls",
        ["list_id", "ord", "idx", "common_id"],
        r => (r.ListId, r.Ord),
        (w, r) => w.Int(r.ListId).Int(r.Ord).Int(r.Idx).Int(r.CommonId),
        r => new ListCallRow(r.Int(), r.Int(), r.Int(), r.Int()));

    /// <summary>The battles the lists start.</summary>
    public static readonly TableShape<ListBattleRow> ListBattles = new(
        "list_battles",
        ["list_id", "ord", "idx", "battle_no", "troop_id", "by_variable", "can_escape", "can_lose", "indent", "preamble_idx", "side_switch"],
        r => (r.ListId, r.Ord),
        (w, r) => w.Int(r.ListId).Int(r.Ord).Int(r.Idx).Int(r.BattleNo).Int(r.TroopId).Flag(r.ByVariable).Flag(r.CanEscape)
            .Flag(r.CanLose).Int(r.Indent).Int(r.PreambleIdx).Int(r.SideSwitch),
        r => new ListBattleRow(r.Int(), r.Int(), r.Int(), r.Int(), r.Int(), r.Flag(), r.Flag(), r.Flag(), r.Int(), r.Int(), r.IntOrNull()));

    /// <summary>The transfers the lists make.</summary>
    public static readonly TableShape<ListTransferRow> ListTransfers = new(
        "list_transfers",
        ["list_id", "ord", "idx", "map_id", "x", "y", "direction", "by_variable", "side_switch"],
        r => (r.ListId, r.Ord),
        (w, r) => w.Int(r.ListId).Int(r.Ord).Int(r.Idx).Int(r.MapId).Int(r.X).Int(r.Y).Int(r.Direction).Flag(r.ByVariable).Int(r.SideSwitch),
        r => new ListTransferRow(r.Int(), r.Int(), r.Int(), r.Int(), r.Int(), r.Int(), r.Int(), r.Flag(), r.IntOrNull()));

    /// <summary>The tileset changes the lists make.</summary>
    public static readonly TableShape<ListTilesetRow> ListTilesets = new(
        "list_tilesets",
        ["list_id", "idx", "tileset_id"],
        r => (r.ListId, r.Idx),
        (w, r) => w.Int(r.ListId).Int(r.Idx).Int(r.TilesetId),
        r => new ListTilesetRow(r.Int(), r.Int(), r.Int()));

    /// <summary>The troops raid sites may hold in place of others.</summary>
    public static readonly TableShape<SiteAlternativeRow> SiteAlternatives = new(
        "site_alternatives",
        ["troop_id", "other_troop_id", "side_switch"],
        r => (r.TroopId, r.OtherTroopId),
        (w, r) => w.Int(r.TroopId).Int(r.OtherTroopId).Int(r.SideSwitch),
        r => new SiteAlternativeRow(r.Int(), r.Int(), r.Int()));

    /// <summary>The transfers into scene maps; the whole row orders them, since the table has no key.</summary>
    public static readonly TableShape<SceneEntryRow> SceneEntries = new(
        "scene_entries",
        ["list_id", "field_map", "field_event", "x", "y", "side_switch", "to_map", "to_x", "to_y", "direction"],
        r => (r.ListId, r.FieldMap, r.FieldEvent, r.X, r.Y, r.SideSwitch ?? -1, (r.ToMap, r.ToX, r.ToY, r.Direction)),
        (w, r) => w.Int(r.ListId).Int(r.FieldMap).Int(r.FieldEvent).Int(r.X).Int(r.Y).Int(r.SideSwitch).Int(r.ToMap).Int(r.ToX).Int(r.ToY)
            .Int(r.Direction),
        r => new SceneEntryRow(r.Int(), r.Int(), r.Int(), r.Int(), r.Int(), r.IntOrNull(), r.Int(), r.Int(), r.Int(), r.Int()));

    /// <summary>The chest pages.</summary>
    public static readonly TableShape<ChestRow> Chests = new(
        "chests",
        ["map_id", "event_id", "page_no", "letter", "list_id"],
        r => (r.MapId, r.EventId, r.PageNo),
        (w, r) => w.Int(r.MapId).Int(r.EventId).Int(r.PageNo).Text(r.Letter).Int(r.ListId),
        r => new ChestRow(r.Int(), r.Int(), r.Int(), r.TextNotNull(), r.Int()));

    /// <summary>The pairs the one-time repair of stuck saves completes.</summary>
    public static readonly TableShape<RepairPairRow> RepairPairs = new(
        "repair_pairs",
        ["map_id", "event_id", "page_no", "letter", "switch_id"],
        r => (r.MapId, r.EventId, r.PageNo, r.Letter, r.SwitchId),
        (w, r) => w.Int(r.MapId).Int(r.EventId).Int(r.PageNo).Text(r.Letter).Int(r.SwitchId),
        r => new RepairPairRow(r.Int(), r.Int(), r.Int(), r.TextNotNull(), r.Int()));

    /// <summary>The lists that give.</summary>
    public static readonly TableShape<GivesRow> Gives = new(
        "gives",
        ["list_id"],
        r => r.ListId,
        (w, r) => w.Int(r.ListId),
        r => new GivesRow(r.Int()));

    /// <summary>The branches of each choice.</summary>
    public static readonly TableShape<ChoiceBranchRow> ChoiceBranches = new(
        "choice_branches",
        ["list_id", "idx", "branch", "first_idx", "last_idx", "holdings"],
        r => (r.ListId, r.Idx, r.Branch),
        (w, r) => w.Int(r.ListId).Int(r.Idx).Int(r.Branch).Int(r.FirstIdx).Int(r.LastIdx).Text(r.Holdings),
        r => new ChoiceBranchRow(r.Int(), r.Int(), r.Int(), r.Int(), r.Int(), r.TextNotNull()));

    /// <summary>The switches.</summary>
    public static readonly TableShape<SwitchRow> Switches = new(
        "switches",
        ["id", "named", "scratch", "story_band", "chest_flag"],
        r => r.Id,
        (w, r) => w.Int(r.Id).Flag(r.Named).Flag(r.Scratch).Flag(r.StoryBand).Flag(r.ChestFlag),
        r => new SwitchRow(r.Int(), r.Flag(), r.Flag(), r.Flag(), r.Flag()));

    /// <summary>The variables.</summary>
    public static readonly TableShape<VariableRow> Variables = new(
        "variables",
        ["id", "named", "scratch", "affection"],
        r => r.Id,
        (w, r) => w.Int(r.Id).Flag(r.Named).Flag(r.Scratch).Flag(r.Affection),
        r => new VariableRow(r.Int(), r.Flag(), r.Flag(), r.Flag()));

    /// <summary>The items, weapons and armors.</summary>
    public static readonly TableShape<ItemRow> Items = new(
        "items",
        ["kind", "id", "key_item", "unlock_class"],
        r => ((int)r.Kind, r.Id),
        (w, r) => w.Int((int)r.Kind).Int(r.Id).Flag(r.KeyItem).Int((int)r.UnlockClass),
        r => new ItemRow((ItemKind)r.Int(), r.Int(), r.Flag(), (UnlockClass)r.Int()));

    /// <summary>The enemies.</summary>
    public static readonly TableShape<EnemyRow> Enemies = new(
        "enemies",
        ["id", "level"],
        r => r.Id,
        (w, r) => w.Int(r.Id).Int(r.Level),
        r => new EnemyRow(r.Int(), r.Int()));

    /// <summary>The battles by troop id on map pages and in common events; a view, never written.</summary>
    public static readonly TableShape<BattleSiteRow> BattleSites = new(
        "battle_sites",
        ["troop_id", "map_id", "event_id", "page_no", "common_id", "list_id", "idx", "battle_no", "indent", "preamble_idx", "side_switch", "cutscene"],
        r => (r.ListId, r.Idx),
        (_, _) => throw new NotSupportedException("battle_sites is a view."),
        r => new BattleSiteRow(r.Int(), r.IntOrNull(), r.IntOrNull(), r.IntOrNull(), r.IntOrNull(), r.Int(), r.Int(), r.Int(), r.Int(), r.Int(), r.IntOrNull(), r.Flag()));

    /// <summary>
    /// The map pages that reach one common event: the walk of the view site_callers started only
    /// from the calls of the common event its one parameter names.
    /// </summary>
    public static readonly TableShape<SiteCallerRow> SiteCallersOfOne = new(
        $"({EventSchema.SiteCallersSql("WHERE common_id = ?")}) AS site_callers",
        ["common_id", "list_id", "map_id", "event_id", "page_no"],
        r => (r.CommonId, r.ListId),
        (_, _) => throw new NotSupportedException("site_callers is a view."),
        r => new SiteCallerRow(r.Int(), r.Int(), r.Int(), r.Int(), r.Int()));

    /// <summary>The post-defeat processing's common events and their writes; a view, never written.</summary>
    public static readonly TableShape<DefeatWriteRow> DefeatWrites = new(
        "defeat_writes",
        ["common_id", "kind", "from_id", "to_id"],
        r => (r.CommonId, r.Kind is { } kind ? (int)kind : -1, r.FromId ?? -1),
        (_, _) => throw new NotSupportedException("defeat_writes is a view."),
        r => new DefeatWriteRow(r.Int(), r.IntOrNull() is { } kind ? (KeyKind)kind : null, r.IntOrNull(), r.IntOrNull()));
}
