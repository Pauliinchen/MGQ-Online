#----------------------------------------------------------------
#  core_game_access.rbx
#
#  Changelog:
#      Paulinchen  2026-10-06: Named the title screen's commands, which show whether the player backed out of a world's new game
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

  # What starts this script's lines in the mod's InGame.log.
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
    :buffs => :@buffs,
    :actions => :@actions,
    :result => :@result,

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
    :names_count => :@names_count,
    :turn_count => :@turn_count,
    :in_battle => :@in_battle,
    :gain_medals => :@gain_medals,

    # BattleManager, SceneManager and DataManager.
    :retry_data => :@retry_data,
    :stack => :@stack,
    :system_save_count => :@system_save_count,

    # Window_Command, and Game_Interpreter with the command it runs.
    :list => :@list,
    :index => :@index,
    :depth => :@depth,

    # $data_mapinfos: the map lists, the main one and one per further map folder.
    :map_lists => :@data,
  }

  # The fields the game sets only once it needs them, so one that is missing is no reason to log:
  # a battle has no acting battler before its first action, which a guest's playback reads first.
  LAZY = [:stones, :enchants, :retry_data, :system_save_count, :subject]

  # The game's private methods the mod calls.
  METHODS = [
    :auto_state_with_switch, :make_unique_names, :refresh_status, :update_for_wait, :wait_for_message,
    :scene_changing?, :battle_show_skip?,
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
end
