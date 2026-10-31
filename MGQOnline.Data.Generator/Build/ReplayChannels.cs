//----------------------------------------------------------------
//  ReplayChannels.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Frozen;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Data.Events;

namespace MGQOnline.Data.Generator.Build;

/// <summary>
/// What an event command or a script's root touches in the game's scripts, as a story replay in the
/// receiving game treats it (story_replay.rbx).
/// </summary>
[Flags]
internal enum ReplayChannel
{
    /// <summary>
    /// Not classed.
    /// </summary>
    None = 0,

    /// <summary>
    /// The receiver's state, which the replay writes as the game does.
    /// </summary>
    State = 1,

    /// <summary>
    /// What the opener saw and heard, which the replay keeps shut.
    /// </summary>
    Presentation = 2,

    /// <summary>
    /// The opener's play (transfers, scenes, moves, access settings), which the replay never makes.
    /// </summary>
    Play = 4,

    /// <summary>
    /// An answer, a draw or a read of the opener's game, which the replay takes from the record.
    /// </summary>
    Input = 8,
}

/// <summary>
/// The gate of the story replay: every event command code and every script root of the map pages
/// and common events is classed by the channels it touches in the game's scripts, and a command the
/// replay closes writes only the game's work keys.
/// </summary>
/// <remarks>
/// Troop pages belong to their battle and are never replayed, so the gate leaves them out.
/// </remarks>
internal static class ReplayChannels
{
    /// <summary>
    /// The channels of each command code, read from the game's scripts 042, 148 and the plugins.
    /// </summary>
    public static readonly FrozenDictionary<int, ReplayChannel> Commands = new Dictionary<int, ReplayChannel>
    {
        [0] = ReplayChannel.State,
        [101] = ReplayChannel.Presentation | ReplayChannel.Input,
        [102] = ReplayChannel.Input,
        [103] = ReplayChannel.Input,
        [104] = ReplayChannel.Input,
        [105] = ReplayChannel.Presentation,
        [108] = ReplayChannel.State,
        [111] = ReplayChannel.State | ReplayChannel.Input,
        [112] = ReplayChannel.State,
        [113] = ReplayChannel.State,
        [115] = ReplayChannel.State,
        [117] = ReplayChannel.State,
        [118] = ReplayChannel.State,
        [119] = ReplayChannel.State,
        [121] = ReplayChannel.State,
        [122] = ReplayChannel.State | ReplayChannel.Input,
        [123] = ReplayChannel.State,
        [124] = ReplayChannel.Play,
        [125] = ReplayChannel.State,
        [126] = ReplayChannel.State,
        [127] = ReplayChannel.State,
        [128] = ReplayChannel.State,
        [129] = ReplayChannel.State,
        [132] = ReplayChannel.Presentation,
        [133] = ReplayChannel.Presentation,
        [134] = ReplayChannel.Play,
        [135] = ReplayChannel.Play,
        [136] = ReplayChannel.Play,
        [137] = ReplayChannel.Play,
        [138] = ReplayChannel.Presentation,
        [201] = ReplayChannel.Play,
        [202] = ReplayChannel.State,
        [203] = ReplayChannel.Play,
        [204] = ReplayChannel.Presentation,
        [205] = ReplayChannel.State | ReplayChannel.Play,
        [206] = ReplayChannel.Play,
        [211] = ReplayChannel.Play,
        [212] = ReplayChannel.Presentation,
        [213] = ReplayChannel.Presentation,
        [214] = ReplayChannel.Play,
        [216] = ReplayChannel.Play,
        [217] = ReplayChannel.Play,
        [221] = ReplayChannel.Presentation,
        [222] = ReplayChannel.Presentation,
        [223] = ReplayChannel.Presentation,
        [224] = ReplayChannel.Presentation,
        [225] = ReplayChannel.Presentation,
        [230] = ReplayChannel.Presentation,
        [231] = ReplayChannel.Presentation,
        [232] = ReplayChannel.Presentation,
        [233] = ReplayChannel.Presentation,
        [234] = ReplayChannel.Presentation,
        [235] = ReplayChannel.Presentation,
        [236] = ReplayChannel.Presentation,
        [241] = ReplayChannel.Presentation,
        [242] = ReplayChannel.Presentation,
        [243] = ReplayChannel.Presentation,
        [244] = ReplayChannel.Presentation,
        [245] = ReplayChannel.Presentation,
        [246] = ReplayChannel.Presentation,
        [249] = ReplayChannel.Presentation,
        [250] = ReplayChannel.Presentation,
        [251] = ReplayChannel.Presentation,
        [261] = ReplayChannel.Presentation,
        [281] = ReplayChannel.Presentation,
        [282] = ReplayChannel.Presentation,
        [283] = ReplayChannel.Presentation,
        [284] = ReplayChannel.Presentation,
        [285] = ReplayChannel.Input,
        [301] = ReplayChannel.Input,
        [302] = ReplayChannel.Play,
        [303] = ReplayChannel.Play,
        [311] = ReplayChannel.State,
        [312] = ReplayChannel.State,
        [313] = ReplayChannel.State,
        [314] = ReplayChannel.State,
        [315] = ReplayChannel.State,
        [316] = ReplayChannel.State,
        [317] = ReplayChannel.State,
        [318] = ReplayChannel.State,
        [319] = ReplayChannel.State,
        [320] = ReplayChannel.State,
        [321] = ReplayChannel.State,
        [322] = ReplayChannel.State,
        [323] = ReplayChannel.State,
        [324] = ReplayChannel.State,
        [326] = ReplayChannel.State,
        [331] = ReplayChannel.State,
        [332] = ReplayChannel.State,
        [333] = ReplayChannel.State,
        [334] = ReplayChannel.State,
        [335] = ReplayChannel.State,
        [336] = ReplayChannel.State,
        [337] = ReplayChannel.Presentation,
        [339] = ReplayChannel.State,
        [340] = ReplayChannel.Play,
        [351] = ReplayChannel.Play,
        [352] = ReplayChannel.Play,
        [353] = ReplayChannel.Play,
        [354] = ReplayChannel.Play,
        [355] = ReplayChannel.State,
        [401] = ReplayChannel.Presentation,
        [402] = ReplayChannel.State,
        [403] = ReplayChannel.State,
        [404] = ReplayChannel.State,
        [405] = ReplayChannel.Presentation,
        [408] = ReplayChannel.State,
        [411] = ReplayChannel.State,
        [412] = ReplayChannel.State,
        [413] = ReplayChannel.State,
        [505] = ReplayChannel.State | ReplayChannel.Play,
        [601] = ReplayChannel.State,
        [602] = ReplayChannel.State,
        [603] = ReplayChannel.State,
        [604] = ReplayChannel.State,
        [605] = ReplayChannel.Play,
        [655] = ReplayChannel.State,
        [999] = ReplayChannel.State,
    }.ToFrozenDictionary();

    /// <summary>
    /// The keys a command the replay closes writes in the game's scripts: the transfer takes and
    /// clears the map it was sent to (script 148, <c>NWConst::Var::MAP_TRANSFER</c>).
    /// </summary>
    public static readonly FrozenDictionary<int, string[]> ClosedCommandWrites = new Dictionary<int, string[]>
    {
        [201] = ["v57"],
    }.ToFrozenDictionary();

    /// <summary>
    /// The channels of each script root, read from the game's scripts that define them.
    /// </summary>
    public static readonly FrozenDictionary<string, ReplayChannel> Roots = new Dictionary<string, ReplayChannel>(StringComparer.Ordinal)
    {
        ["$data_actors.compact"] = ReplayChannel.State,
        ["$data_armors.compact"] = ReplayChannel.State,
        ["$data_common_events[]"] = ReplayChannel.State,
        ["$data_items.compact"] = ReplayChannel.State,
        ["$data_library.collect_per_accessory"] = ReplayChannel.State,
        ["$data_library.collect_per_actor"] = ReplayChannel.State,
        ["$data_library.collect_per_all"] = ReplayChannel.State,
        ["$data_library.collect_per_armor"] = ReplayChannel.State,
        ["$data_library.collect_per_enemy"] = ReplayChannel.State,
        ["$data_library.collect_per_item"] = ReplayChannel.State,
        ["$data_library.collect_per_weapon"] = ReplayChannel.State,
        ["$data_weapons.compact"] = ReplayChannel.State,
        ["$game_actors[]"] = ReplayChannel.State,
        ["$game_library.count_up_battlefuck_lose"] = ReplayChannel.State,
        ["$game_library.count_up_battlefuck_win"] = ReplayChannel.State,
        ["$game_library.party_battle"] = ReplayChannel.State,
        ["$game_library.party_class_change"] = ReplayChannel.State,
        ["$game_library.party_defeat"] = ReplayChannel.State,
        ["$game_library.party_escape"] = ReplayChannel.State,
        ["$game_library.party_lose"] = ReplayChannel.State,
        ["$game_library.party_open_class"] = ReplayChannel.State,
        ["$game_library.party_open_tribe"] = ReplayChannel.State,
        ["$game_library.party_synthesize"] = ReplayChannel.State,
        ["$game_library.party_tribe_change"] = ReplayChannel.State,
        ["$game_library.purchase_gold"] = ReplayChannel.State,
        ["$game_map.airship"] = ReplayChannel.State,
        ["$game_map.boat"] = ReplayChannel.State,
        ["$game_map.events"] = ReplayChannel.Play,
        ["$game_map.field?"] = ReplayChannel.Input,
        ["$game_map.need_refresh"] = ReplayChannel.State,
        ["$game_map.screen"] = ReplayChannel.Presentation,
        ["$game_map.ship"] = ReplayChannel.State,
        ["$game_party.add_actor"] = ReplayChannel.State,
        ["$game_party.all_members"] = ReplayChannel.State,
        ["$game_party.gain_item"] = ReplayChannel.State,
        ["$game_player.direction"] = ReplayChannel.Input,
        ["$game_player.in_ship?"] = ReplayChannel.Input,
        ["$game_player.normal_walk?"] = ReplayChannel.Input,
        ["$game_player.x"] = ReplayChannel.Input,
        ["$game_player.y"] = ReplayChannel.Input,
        ["$game_self_switches"] = ReplayChannel.State,
        ["$game_self_switches="] = ReplayChannel.State,
        ["$game_self_switches[]"] = ReplayChannel.State,
        ["$game_self_switches[]="] = ReplayChannel.State,
        ["$game_switches[]"] = ReplayChannel.State,
        ["$game_switches[]="] = ReplayChannel.State,
        ["$game_troop.lose_event_id"] = ReplayChannel.State,
        ["$game_variables[]"] = ReplayChannel.State,
        ["$game_variables[]="] = ReplayChannel.State,
        ["@depth"] = ReplayChannel.State,
        ["@goods"] = ReplayChannel.State,
        ["@goods="] = ReplayChannel.State,
        ["@params="] = ReplayChannel.State,
        ["BattleManager.process_defeat"] = ReplayChannel.Play,
        ["Game_Interpreter.new"] = ReplayChannel.State,
        ["Game_SelfSwitches.new"] = ReplayChannel.State,
        ["NWConst::Class::JOB_RANGE.each"] = ReplayChannel.State,
        ["NWConst::Class::TRIBE_RANGE.each"] = ReplayChannel.State,
        ["NWConst::Library::MEDAL_DATA"] = ReplayChannel.State,
        ["RPG::MoveCommand.new"] = ReplayChannel.State,
        ["RPG::MoveRoute.new"] = ReplayChannel.State,
        ["SceneManager.call"] = ReplayChannel.Play,
        ["Scene_Forget"] = ReplayChannel.Play,
        ["Scene_InitSkill"] = ReplayChannel.Play,
        ["Scene_JobChange"] = ReplayChannel.Play,
        ["Scene_Library_Music"] = ReplayChannel.Play,
        ["Scene_ParamSetting"] = ReplayChannel.Play,
        ["Scene_PartyEdit"] = ReplayChannel.Play,
        ["Scene_PartyLoad"] = ReplayChannel.Play,
        ["Scene_PartySave"] = ReplayChannel.Play,
        ["Scene_Smith"] = ReplayChannel.Play,
        ["Scene_Storehouse"] = ReplayChannel.Play,
        ["Tone.new"] = ReplayChannel.State,
        ["actor_class_level_over?"] = ReplayChannel.State,
        ["actor_copy"] = ReplayChannel.State,
        ["actor_equip_lock"] = ReplayChannel.State,
        ["actor_equip_unlock"] = ReplayChannel.State,
        ["actor_label_jump"] = ReplayChannel.State,
        ["actor_skill_have?"] = ReplayChannel.State,
        ["add_actor_ex"] = ReplayChannel.State | ReplayChannel.Input,
        ["add_actor_ex_nc"] = ReplayChannel.State,
        ["add_encounter_airship"] = ReplayChannel.State,
        ["add_stand_actor"] = ReplayChannel.State,
        ["add_temp_actors"] = ReplayChannel.State,
        ["all_member_remove_equip"] = ReplayChannel.State,
        ["all_members_add_state"] = ReplayChannel.State,
        ["all_members_armor_have?"] = ReplayChannel.State,
        ["battle_memory"] = ReplayChannel.Play,
        ["battler_graphic_hide"] = ReplayChannel.Presentation,
        ["battler_graphic_show"] = ReplayChannel.Presentation,
        ["call_casino_prize"] = ReplayChannel.Play,
        ["call_novel_scene"] = ReplayChannel.State | ReplayChannel.Presentation,
        ["call_party_edit"] = ReplayChannel.Play,
        ["call_poker_scene"] = ReplayChannel.Play,
        ["call_slot_scene"] = ReplayChannel.Play,
        ["call_synthesize"] = ReplayChannel.Play,
        ["change_actor_ability"] = ReplayChannel.State,
        ["change_actor_equip_stone"] = ReplayChannel.State,
        ["change_friend"] = ReplayChannel.State | ReplayChannel.Presentation,
        ["change_friend_n"] = ReplayChannel.State,
        ["change_joblv"] = ReplayChannel.State,
        ["change_region"] = ReplayChannel.State,
        ["change_sub_class_member"] = ReplayChannel.State,
        ["change_sub_joblv"] = ReplayChannel.State,
        ["check_party_category"] = ReplayChannel.State,
        ["check_picture_exist"] = ReplayChannel.State,
        ["choice_armor"] = ReplayChannel.Input,
        ["choice_weapon"] = ReplayChannel.Input,
        ["clear_actor_equip"] = ReplayChannel.State,
        ["clear_actor_ex"] = ReplayChannel.State,
        ["clear_skill_name"] = ReplayChannel.Presentation,
        ["clear_stone_no_actor_equip"] = ReplayChannel.State,
        ["command_203"] = ReplayChannel.Play,
        ["common_data_to_text"] = ReplayChannel.Play,
        ["common_text_to_data"] = ReplayChannel.Play,
        ["delete_actor_ex"] = ReplayChannel.State,
        ["delete_encounter_airship"] = ReplayChannel.State,
        ["display_skill_name"] = ReplayChannel.Presentation,
        ["edit_multiparty"] = ReplayChannel.Play,
        ["edit_multiparty_cancel?"] = ReplayChannel.State,
        ["end_multiparty"] = ReplayChannel.State,
        ["erase_class_level"] = ReplayChannel.State,
        ["ex_choice_add"] = ReplayChannel.State,
        ["ex_choice_show"] = ReplayChannel.Input,
        ["exist_party_in_map?"] = ReplayChannel.State,
        ["exist_party_persona_id?"] = ReplayChannel.State,
        ["force_change_equip"] = ReplayChannel.State,
        ["forced_get_off_vehicle"] = ReplayChannel.Play,
        ["forced_get_on_boat"] = ReplayChannel.Play,
        ["forced_get_on_airship"] = ReplayChannel.Play,
        ["forced_get_on_ship"] = ReplayChannel.Play,
        ["forced_transfer"] = ReplayChannel.Play,
        ["gain_actor_exp"] = ReplayChannel.State,
        ["gain_coin"] = ReplayChannel.State,
        ["gain_medal"] = ReplayChannel.State,
        ["gain_party_class_exp"] = ReplayChannel.State,
        ["gain_party_exp"] = ReplayChannel.State,
        ["gain_party_friend"] = ReplayChannel.State,
        ["gain_party_tribe_exp"] = ReplayChannel.State,
        ["get_character"] = ReplayChannel.State | ReplayChannel.Play | ReplayChannel.Input,
        ["input_keys"] = ReplayChannel.Input,
        ["interrupt_skill"] = ReplayChannel.State,
        ["keep_all_enchant_equip"] = ReplayChannel.State,
        ["keep_all_equip"] = ReplayChannel.State,
        ["keep_all_item"] = ReplayChannel.State,
        ["keep_all_item_over?"] = ReplayChannel.State,
        ["keep_all_normal_equip"] = ReplayChannel.State,
        ["keys_stack"] = ReplayChannel.State,
        ["level_adjust"] = ReplayChannel.State,
        ["level_round_down"] = ReplayChannel.State,
        ["library_all_open"] = ReplayChannel.State,
        ["map_zoom"] = ReplayChannel.Presentation,
        ["memory_interruption"] = ReplayChannel.State,
        ["move_actor_ex"] = ReplayChannel.State | ReplayChannel.Input,
        ["move_party"] = ReplayChannel.State | ReplayChannel.Play,
        ["move_stand_actor"] = ReplayChannel.State,
        ["move_stand_actors_except_luca"] = ReplayChannel.State,
        ["off_ssw"] = ReplayChannel.State,
        ["on_ssw"] = ReplayChannel.State,
        ["party_members"] = ReplayChannel.State,
        ["persona_change"] = ReplayChannel.State,
        ["play_base_bgm"] = ReplayChannel.Presentation,
        ["present_start"] = ReplayChannel.Input,
        ["rand"] = ReplayChannel.Input,
        ["refresh_ability"] = ReplayChannel.State,
        ["release_temp_actors"] = ReplayChannel.State,
        ["reset_selfswitch_map"] = ReplayChannel.State,
        ["retry_battle"] = ReplayChannel.Play,
        ["screen"] = ReplayChannel.Presentation,
        ["sell_enchant_armors"] = ReplayChannel.State,
        ["sell_enchant_weapons"] = ReplayChannel.State,
        ["set_actor_had"] = ReplayChannel.State,
        ["set_actors"] = ReplayChannel.State,
        ["set_airship_bgm"] = ReplayChannel.Presentation,
        ["set_class_level"] = ReplayChannel.State,
        ["set_temp_actors"] = ReplayChannel.State,
        ["set_title_bg"] = ReplayChannel.Presentation,
        ["set_title_bgm"] = ReplayChannel.Presentation,
        ["shop_item_add"] = ReplayChannel.State,
        ["ssw"] = ReplayChannel.State,
        ["stand_members"] = ReplayChannel.State,
        ["start_multiparty"] = ReplayChannel.State,
        ["start_poker"] = ReplayChannel.Play,
        ["storehouse_take_items"] = ReplayChannel.State,
        ["sw"] = ReplayChannel.State,
        ["take_all_enchant_equip"] = ReplayChannel.State,
        ["take_all_item"] = ReplayChannel.State,
        ["take_all_normal_equip"] = ReplayChannel.State,
        ["test_enchantment"] = ReplayChannel.State,
        ["unlimited_choices"] = ReplayChannel.Input,
        ["unlock_level"] = ReplayChannel.State,
        ["v"] = ReplayChannel.State,
        ["wait"] = ReplayChannel.Presentation,
    }.ToFrozenDictionary(StringComparer.Ordinal);

    /// <summary>
    /// Lists every command code and script root of the map pages and common events the tables do
    /// not class, each once with the first list it stands in and how many lists hold it.
    /// </summary>
    /// <param name="game">The game.</param>
    /// <returns>The problems, such as "command 901 in map:1:2:0 (and 3 more lists)".</returns>
    public static IReadOnlyList<string> Unclassed(BuiltGame game)
    {
        var found = new Dictionary<string, (string Site, int Lists)>(StringComparer.Ordinal);
        foreach (BuiltList list in Replayable(game))
        {
            IEnumerable<string> codes = list.Commands.Select(command => command.Code).Distinct().Where(code => !Commands.ContainsKey(code))
                .Select(code => string.Create(CultureInfo.InvariantCulture, $"command {code}"));
            IEnumerable<string> roots = list.ScriptRoots.Where(root => !Roots.ContainsKey(root)).Select(root => $"script root {root}");
            foreach (string what in codes.Concat(roots))
            {
                found[what] = found.TryGetValue(what, out (string Site, int Lists) seen) ? (seen.Site, seen.Lists + 1) : (SiteOf(list), 1);
            }
        }

        return [.. found.OrderBy(entry => entry.Key, StringComparer.Ordinal).Select(entry => Described(entry.Key, entry.Value.Site, entry.Value.Lists))];
    }

    /// <summary>
    /// Lists the keys the closed commands of the map pages and common events write, each once.
    /// </summary>
    /// <param name="game">The game.</param>
    /// <returns>The keys as the tracks name them, such as "v57".</returns>
    public static IReadOnlyList<string> ClosedWrites(BuiltGame game)
    {
        HashSet<int> codes = [.. Replayable(game).SelectMany(list => list.Commands.Select(command => command.Code))];
        return [.. ClosedCommandWrites.Where(entry => codes.Contains(entry.Key)).SelectMany(entry => entry.Value).Distinct().Order(StringComparer.Ordinal)];
    }

    /// <summary>
    /// Finds everything that fails the gate: an unclassed command code or script root, and a key a
    /// closed command writes that the reviewed story key list does not mark as work.
    /// </summary>
    /// <param name="game">The game.</param>
    /// <param name="isWork">Tells whether the reviewed list marks a key, as the tracks name it, as work.</param>
    /// <returns>The problems; none when the gate passes.</returns>
    public static IReadOnlyList<string> Problems(BuiltGame game, Func<string, bool> isWork) =>
        [.. Unclassed(game), .. ClosedWrites(game).Where(key => !isWork(key)).Select(key => $"a closed command writes {key}, which is no work key")];

    /// <summary>
    /// Lists the lists a replay may run: the map pages and the common events.
    /// </summary>
    /// <param name="game">The game.</param>
    /// <returns>The lists.</returns>
    private static IEnumerable<BuiltList> Replayable(BuiltGame game) => game.Lists.Where(list => list.Site.Kind != ListKind.TroopPage);

    /// <summary>
    /// Names a list as the game's sites do, pages from 0.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>Such as "map:215:23:0" or "ce:129".</returns>
    private static string SiteOf(BuiltList list) => list.Site.Kind == ListKind.Common
        ? string.Create(CultureInfo.InvariantCulture, $"ce:{list.Site.CommonId}")
        : string.Create(CultureInfo.InvariantCulture, $"map:{list.Site.MapId}:{list.Site.EventId}:{list.Site.PageNo}");

    /// <summary>
    /// Describes an unclassed command or root with where it stands.
    /// </summary>
    /// <param name="what">The command or root.</param>
    /// <param name="site">The first list it stands in.</param>
    /// <param name="lists">How many lists hold it.</param>
    /// <returns>The description.</returns>
    private static string Described(string what, string site, int lists) =>
        lists == 1 ? $"{what} in {site}" : string.Create(CultureInfo.InvariantCulture, $"{what} in {site} (and {lists - 1} more lists)");
}
