#----------------------------------------------------------------
#  core_game_access.rbx
#
#  Changelog:
#      Paulinchen  2026-10-08: Named whether a battle allows escaping and losing
#                            - Named a battle's phase and the troop it fights
#      Paulinchen  2026-10-07: Named the counters the game keeps per state, the turns held and the steps left
#                            - Named an interpreter's event and map, the trades a save keeps and the title screen's command closing
#      Paulinchen  2026-10-06: Left scene_changing? out of the private methods, since the game makes it public
#                            - Named a battler's counters, which hold its barriers, and whether a battle starts with a first strike or a surprise
#                            - Named whether the map's menu was asked for, and the entries of the game's switches and variables
#                            - Found the database's items, weapons and armors by the letter of their kind, for every script that writes items as text
#                            - Named the party's own companions, past a story's temporary party
#                            - Named the title screen's commands, which show whether the player backed out of a world's new game
#      Paulinchen  2026-10-04: Named a character's levels, which the level sync reads
#                            - Counted a battle's acting battler as set only once needed, which ends the false log line about it
#                            - Named how deep an interpreter runs
#                            - Named the command an interpreter runs
#                            - Renamed from mp_game_access.rbx
#                            - Read the map lists the game keeps, one per map folder
#      Paulinchen  2026-10-03: Created
#
#----------------------------------------------------------------

# What the mod reads and writes of the game that the game keeps private: fields without accessors
# and private methods, each named once here. When a game update renames one, this is the one place
# to follow it, and the log names the field the game no longer has.
#
# The game's classes are not reopened with accessors of the mod's own, which another mod's could
# clash with.
module MGQ_MpGame
  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "game"

  # The game's private fields the mod uses, by the name the mod calls each.
  FIELDS = {
    # Game_Actor: what a build writes of a character.
    :param_plus => :@param_plus,
    :skills => :@skills,
    :abilities => :@abilities,
    :equip_abilities => :@equip_abilities,
    :equips => :@equips,

    # Game_Actor: its personal, job and race level, which a co-op battle's level sync lowers for a
    # moment to read its stats at the battle's level.
    :level => :@level,

    # Game_Battler: what the host's battle sets on the guest's battlers. Written past the game's
    # setters, which would refresh the battler and add or remove its death by themselves.
    :hp => :@hp,
    :mp => :@mp,
    :tp => :@tp,
    :states => :@states,
    :state_turns => :@state_turns,
    :state_turn_counts => :@state_turn_counts,
    :state_steps => :@state_steps,
    :buffs => :@buffs,
    :actions => :@actions,
    :result => :@result,

    # Game_Battler: its battle counters, which hold its barriers.
    :counters => :@cnt,

    # An enchanted item, and an enemy's extra data.
    :plus_num => :@plus_num,
    :socket_num => :@socket_num,
    :enchants => :@enchants,
    :stones => :@stones,
    :prefix => :@prefix,
    :data_ex => :@data_ex,

    # Scene_Battle.
    :subject => :@subject,
    :log_window => :@log_window,
    :spriteset => :@spriteset,
    :status_window => :@status_window,
    :party_command_window => :@party_command_window,
    :actor_command_window => :@actor_command_window,
    :info_viewport => :@info_viewport,
    :battle_actor_status_windows => :@battle_actor_status_windows,
    :battle_actor_status_windows_show => :@battle_actor_status_windows_show,

    # Scene_Title.
    :command_window => :@command_window,

    # $game_troop, $game_party and $game_temp.
    :enemies => :@enemies,
    :troop_id => :@troop_id,
    :names_count => :@names_count,
    :turn_count => :@turn_count,
    :in_battle => :@in_battle,
    :gain_medals => :@gain_medals,

    # $game_party: the companions of the player's own party and castle, which its include_actors
    # replaces with a story's temporary party while one plays.
    :include_actors => :@include_actors,

    # BattleManager, SceneManager and DataManager.
    :retry_data => :@retry_data,
    :preemptive => :@preemptive,
    :surprise => :@surprise,
    :can_escape => :@can_escape,
    :can_lose => :@can_lose,
    :phase => :@phase,
    :stack => :@stack,
    :system_save_count => :@system_save_count,

    # Window_Command, and Game_Interpreter with the command it runs, the event and the map it runs for.
    :list => :@list,
    :index => :@index,
    :depth => :@depth,
    :event_id => :@event_id,
    :map_id => :@map_id,

    # $game_system: the trades applied in this save, a field of the mod's own that its saves keep.
    :trades => :@mgq_mp_trades,

    # Scene_Map: whether the game's menu was asked for.
    :menu_calling => :@menu_calling,

    # $data_mapinfos: the map lists, the main one and one per further map folder.
    :map_lists => :@data,

    # $game_switches, $game_variables and $game_self_switches: their entries, written past the game's
    # setters, which refresh the map and act on some switches by themselves.
    :data => :@data,
  }

  # The fields the game sets only once it needs them, so one that is missing is no reason to log:
  # a battle has no acting battler before its first action, which a guest's playback reads first.
  LAZY = [:stones, :enchants, :retry_data, :system_save_count, :subject, :trades]

  # The game's private methods the mod calls.
  METHODS = [
    :auto_state_with_switch, :make_unique_names, :refresh_status, :update_for_wait, :wait_for_message,
    :battle_show_skip?, :close_command_window,
  ]

  # Reads a private field of one of the game's objects, logging once when the game has no such
  # field.
  #
  # @param object [Object] The game's object.
  # @param field [Symbol] A key of FIELDS.
  # @return [Object, nil] The field's value, nil when the game has no such field.
  def self.get(object, field)
    name = FIELDS.fetch(field)
    unless LAZY.include?(field) || object.instance_variable_defined?(name)
      log_once([object.class, field], "#{object.is_a?(Module) ? object : object.class} has no #{name}")
    end
    object.instance_variable_get(name)
  end

  # Writes a private field of one of the game's objects.
  #
  # @param object [Object] The game's object.
  # @param field [Symbol] A key of FIELDS.
  # @param value [Object] The value.
  # @return [Object] The value.
  def self.set(object, field, value)
    object.instance_variable_set(FIELDS.fetch(field), value)
  end

  # Calls a private method of one of the game's objects.
  #
  # @param object [Object] The game's object.
  # @param method [Symbol] One of METHODS.
  # @param args [Array] Its arguments.
  # @return [Object] What the method returns.
  def self.call(object, method, *args)
    raise ArgumentError, "#{method} is none of the game's methods the mod calls" unless METHODS.include?(method)

    object.send(method, *args)
  end

  # Finds an item of the game's database by the letter of its kind.
  #
  # @param kind [String] "i" for an item, "w" for a weapon, "a" for an armor.
  # @param id [Integer] Its id in the database.
  # @return [RPG::BaseItem, nil] The item, nil for another letter, an id the database lacks or an
  #   unnamed entry.
  def self.item(kind, id)
    table = { "i" => $data_items, "w" => $data_weapons, "a" => $data_armors }[kind]
    return nil unless table && id > 0 && id < table.size

    item = table[id]
    item && !item.name.to_s.empty? ? item : nil
  end
end
