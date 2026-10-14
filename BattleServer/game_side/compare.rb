#----------------------------------------------------------------
#  compare.rb
#
#  Changelog:
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

# Plays a battle in the real game the way the battle server plays it, so the two logs can be
# compared: the same save and troop, the same seeds at the same points, auto battle commands,
# the first of every choice, the skip key held, and the battle log kept. The game's saves are
# skipped while it is loaded. Test only, in Ruby 1.9 for RGSS3.
module CompareBattle
  # Escape codes the battle log's lines carry, stripped as the server strips them.
  ESCAPE_CODE = /\\[A-Za-z]+(\[[^\]]*\])?|\e[A-Za-z]+(\[[^\]]*\])?/

  # The key the game skips messages with while it is held.
  SKIP_KEY = :X

  class << self
    # The battle being compared, or nil.
    attr_reader :battle

    # Starts a battle from a save file, as the server's HeadlessBattle.run does.
    #
    # @param save_path [String] The save file.
    # @param troop_id [Integer] The troop.
    # @param seed [Integer] The seed: the troop's setup takes it, the battle scene it plus one.
    # @param name [String] The name the log is written under, TestDriver/out/battle_<name>.txt.
    def start(save_path, troop_id, seed, name)
      # Every battle adds to the library's lifetime counts, which some damage boosts read, so each
      # battle starts from the same system save, as the server's do.
      DataManager.extract_system_save_contents(File.open("TestDriver/saves/SystemSave.rvdata2", "rb") { |file| Marshal.load(file) })
      DataManager.send(:update_system) if DataManager.respond_to?(:update_system, true)
      DataManager.fix_system
      $game_library.make_preparation_list
      DataManager.create_game_objects
      File.open(save_path, "rb") do |file|
        Marshal.load(file)
        DataManager.extract_save_contents(Marshal.load(file))
      end
      DataManager.send(:update) if DataManager.respond_to?(:update, true)
      DataManager.send(:reload_map_if_updated) if DataManager.respond_to?(:reload_map_if_updated, true)
      # Some saves keep the enchantment rarity at 0, which no drop table covers, and an enchanted
      # drop then crashes the game; the server's comparison sets the same.
      $game_variables[150] = 1 if $game_variables[150] == 0
      @battle ={ :seed => seed, :name => name, :log => [], :turn => 0, :result => nil, :written => false }
      srand(seed)
      BattleManager.setup(troop_id, true, true)
      BattleManager.save_bgm_and_bgs
      Graphics.frame_count = 0
      SceneManager.clear
      SceneManager.instance_variable_get(:@stack).push(Scene_Title.new)
      SceneManager.goto(Scene_Battle)
      "started #{name}"
    end

    # Keeps a line of the battle log, as the server's take_line does.
    #
    # @param text [String] The line.
    def take_line(text)
      return unless @battle && !@battle[:written]

      line = text.to_s.gsub(ESCAPE_CODE, "").strip
      @battle[:log] << line unless line.empty? || @battle[:log].last == line
    end

    # Notes a pick of a choice, as the server's choose does.
    #
    # @param names [Array<String>] The choices' names.
    # @return [Integer] The index picked, always the first.
    def choose(names)
      @battle[:log] << "[choice] #{names[0]} (of #{names.join(" / ")})" if @battle && !@battle[:written]
      0
    end

    # Writes the battle's outcome once it ended.
    #
    # @param result [Integer] 0 for a victory, 1 for an escape, 2 for a defeat.
    def finish(result)
      return unless @battle && !@battle[:written]

      @battle[:result] = { 0 => "victory", 1 => "escape", 2 => "defeat" }[result] || result.to_s
      lines = ["result #{@battle[:result]}", "turns #{@battle[:turn]}"]
      lines += @battle[:log]
      lines += $game_party.members.map { |actor| "party: #{battler_line(actor)}" }
      lines += $game_troop.members.map { |enemy| "troop: #{battler_line(enemy)}" }
      File.open("TestDriver/out/battle_#{@battle[:name]}.txt", "wb") { |file| file.write(lines.join("\n")) }
      @battle[:written] = true
    end

    # A battler's name, HP and states, as the server writes them.
    #
    # @param battler [Game_Battler] The battler.
    # @return [String] The line.
    def battler_line(battler)
      states = battler.states.map { |state| state.name }.reject { |name| name.empty? }
      "#{battler.name} #{battler.hp}/#{battler.mhp} HP#{states.empty? ? "" : " [#{states.join(", ")}]"}"
    end
  end
end

class Scene_Battle
  alias compare_start start

  # Starts the battle scene, seeded as the server seeds it.
  def start
    srand(CompareBattle.battle[:seed] + 1) if CompareBattle.battle
    compare_start
  end

  alias compare_start_party_command_selection start_party_command_selection

  # Gives every actor the auto battle's commands and starts the turn, as the server does.
  def start_party_command_selection
    return compare_start_party_command_selection unless CompareBattle.battle
    return if scene_changing?

    refresh_status
    if BattleManager.input_start
      CompareBattle.battle[:turn] += 1
      $game_party.battle_members.select { |actor| actor.inputable? }.each { |actor| actor.make_auto_battle_actions }
      turn_start
    else
      turn_start
    end
  end
end

class Window_BattleLog
  alias compare_add_text add_text
  alias compare_replace_text replace_text

  # Shows a line, and keeps it.
  def add_text(text)
    CompareBattle.take_line(text)
    compare_add_text(text)
  end

  # Replaces the last line, and keeps the new one.
  def replace_text(text)
    CompareBattle.take_line(text)
    compare_replace_text(text)
  end
end

class Window_Message
  alias compare_input_choice input_choice

  # Picks the first choice at once.
  def input_choice
    return compare_input_choice unless CompareBattle.battle

    compare_pick(@choice_window)
  end

  if method_defined?(:input_ex_choice)
    alias compare_input_ex_choice input_ex_choice

    # Picks the first extended choice at once.
    def input_ex_choice
      return compare_input_ex_choice unless CompareBattle.battle

      compare_pick(@ex_choice_window)
    end
  end

  # Opens a choice window and confirms the first choice in it.
  def compare_pick(window)
    window.start
    return unless window.active

    names = window.instance_variable_get(:@list).map { |command| command[:name].to_s.gsub(CompareBattle::ESCAPE_CODE, "") }
    window.select(CompareBattle.choose(names))
    window.call_ok_handler
    window.deactivate
  end
end

class << BattleManager
  alias compare_battle_end battle_end

  # Ends the battle, writing the comparison's log.
  def battle_end(result)
    CompareBattle.finish(result)
    compare_battle_end(result)
  end
end

class << Input
  alias compare_trigger? trigger?
  alias compare_press? press?

  # The skip key counts as held and confirm as pressed every other frame while comparing.
  def trigger?(key)
    return compare_trigger?(key) unless CompareBattle.battle
    return true if key == CompareBattle::SKIP_KEY
    return Graphics.frame_count.odd? if key == :C

    compare_trigger?(key)
  end

  # The skip key counts as held and confirm as pressed every other frame while comparing.
  def press?(key)
    return compare_press?(key) unless CompareBattle.battle
    return true if key == CompareBattle::SKIP_KEY
    return Graphics.frame_count.odd? if key == :C

    compare_press?(key)
  end
end

class << DataManager
  # The comparison never writes the player's saves.
  def save_game(*args)
    true
  end

  # The comparison never writes the player's saves.
  def auto_save_game(*args)
    true
  end

  # The comparison never writes the player's system save.
  def save_system(*args)
    true
  end
end

"compare installed"
