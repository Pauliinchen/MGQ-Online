#----------------------------------------------------------------
#  battles_pvp_mirror.rbx
#
#  Changelog:
#      Paulinchen  2026-10-07: Logged the mirror report's sections and the characters it leaves out
#      Paulinchen  2026-10-06: Wrote the report into the game folder's Logs folder
#      Paulinchen  2026-10-04: Renamed from mp_battles_pvp_mirror.rbx
#      Paulinchen  2026-10-03: Read and wrote the game's private fields and called its private methods through MGQ_MpGame
#                            - Created
#
#----------------------------------------------------------------

# The report of a mirror match: how the player's team and its rebuilt copy compare, turn by
# turn, written to a file for finding what a rebuilt character lacks. It builds on
# battles_pvp.rbx.

module MGQ_MpBattlesPvp
  # Logs/Mirror Match.log: each character of a mirror match next to its rebuild,
  # outside of battle and at the first turn, every value that differs marked. Written anew for every
  # match.
  module MirrorReport
    # File inside the Logs folder.
    FILE = "Mirror Match.log"

    # Names of the extra rates, in the game's order.
    XPARAM_NAMES = ["Hit", "Evasion", "Critical", "Critical evasion", "Magic evasion", "Magic reflection",
                    "Counter", "HP regeneration", "MP regeneration", "TP regeneration"]

    # Names of the special rates, in the game's order.
    SPARAM_NAMES = ["Target rate", "Guard", "Recovery", "Pharmacology", "MP cost", "TP charge",
                    "Physical damage taken", "Magical damage taken", "Floor damage", "EXP"]

    # Ends a row whose two values differ.
    MARK = "  <-- differs"

    # Width of a row's label.
    LABEL_WIDTH = 26

    # Width of each value of a row.
    VALUE_WIDTH = 20

    # Writes the first section, outside of battle, over the last match's report.
    #
    # @param opponents [Array<Opponent>] The rebuilt characters, already in the troop.
    def self.start(opponents)
      @pairs = opponents.map { |rebuilt| [$game_party.battle_members.find { |actor| actor.id == rebuilt.id }, rebuilt] }
      @pairs.reject! { |yours, _| yours.nil? }
      unless @pairs.size == opponents.size
        MGQ_MpBattlesPvp.log("the mirror report leaves out #{opponents.size - @pairs.size} rebuilt characters not in the Frontline")
      end
      @turn_written = false
      write("wb", "Outside of battle (#{Time.now.strftime('%Y-%m-%d %H:%M:%S')})")
    end

    # Adds the section at the first turn, once pre-battle spells and battle-only boosts apply.
    # Called at every turn's start.
    def self.turn_started
      return if @turn_written || @pairs.nil? || !Battle.mirror?

      @turn_written = true
      write("ab", "In battle, turn #{$game_troop.turn_count}")
    end

    # Writes a section: every character next to its rebuild.
    #
    # @param mode [String] "wb" to start the file anew, "ab" to add to it.
    # @param title [String] The section's title.
    def self.write(mode, title)
      blocks = @pairs.map { |yours, rebuilt| block(yours, rebuilt) }
      differences = blocks.inject(0) { |sum, (_, count)| sum + count }
      lines = ["=" * 70, "#{title}: #{differences} value(s) differ", "=" * 70, ""] + blocks.map(&:first).flatten
      File.open(MGQ_Multiplayer.log_path(FILE), mode) { |file| file.write(lines.join("\n") + "\n") }
      MGQ_MpBattlesPvp.log("wrote the mirror report's section #{title.sub(/ \(.*\)\z/, '').inspect} into #{FILE}: " \
                           "#{@pairs.size} characters, #{differences} values differ")
    rescue => e
      MGQ_MpBattlesPvp.log("mirror report failed: #{e.class}: #{e.message}")
    end

    # Compares a character with its rebuild.
    #
    # @param yours [Game_Actor] The player's character.
    # @param rebuilt [Opponent] Its rebuild.
    # @return [Array] The lines, and how many values differ.
    def self.block(yours, rebuilt)
      rows = rows_for(yours, rebuilt)
      lines = ["-- #{yours.name} (actor #{yours.id})", row("", "yours", "rebuilt", false)]
      lines += rows.map { |label, mine, theirs| row(label, mine, theirs, mine != theirs) }
      [lines + [""], rows.count { |_, mine, theirs| mine != theirs }]
    end

    # Compares a character with its rebuild.
    #
    # @param yours [Game_Actor] The player's character.
    # @param rebuilt [Opponent] Its rebuild.
    # @return [Array<Array>] A label and both values per row.
    def self.rows_for(yours, rebuilt)
      rows = (0...8).map { |id| [Vocab.param(id), yours.param(id).to_i, rebuilt.param(id).to_i] }
      rows += XPARAM_NAMES.each_with_index.map { |name, id| [name, percent(yours.xparam(id)), percent(rebuilt.xparam(id))] }
      rows += SPARAM_NAMES.each_with_index.map { |name, id| [name, percent(yours.sparam(id)), percent(rebuilt.sparam(id))] }
      rows.push(["Max SP", yours.max_tp.to_i, rebuilt.max_tp.to_i])
      rows.push(["Level (personal/job/race)", levels(yours), levels(rebuilt)])
      rows.push(["Job / race", "#{yours.class_id} / #{yours.tribe_id}", "#{rebuilt.class_id} / #{rebuilt.tribe_id}"])
      rows += element_rows(yours, rebuilt) + state_rows(yours, rebuilt)
      rows.push(["States now", state_names(yours), state_names(rebuilt)])
      skills = [yours.skills.map(&:id), rebuilt.skills.map(&:id)]
      abilities = [yours.all_equip_abilities.compact, rebuilt.all_equip_abilities.compact]
      rows.push(["Skills", skills[0].size, skills[1].size])
      rows.push(["Skills only yours / rebuilt", ids_text(skills[0] - skills[1]), ids_text(skills[1] - skills[0])])
      rows.push(["Abilities set", abilities[0].size, abilities[1].size])
      rows.push(["Abilities only yours / rebuilt", ids_text(abilities[0] - abilities[1]), ids_text(abilities[1] - abilities[0])])
      rows + equipment_rows(yours, rebuilt)
    end

    # Compares the element rates.
    #
    # @param yours [Game_Actor] The player's character.
    # @param rebuilt [Opponent] Its rebuild.
    # @return [Array<Array>] The element rates either of the two has other than 100%.
    def self.element_rows(yours, rebuilt)
      (1...$data_system.elements.size).map do |id|
        mine = percent(yours.element_rate(id))
        theirs = percent(rebuilt.element_rate(id))
        ["Element #{$data_system.elements[id]}", mine, theirs] unless mine == percent(1.0) && theirs == percent(1.0)
      end.compact
    end

    # Compares the state rates.
    #
    # @param yours [Game_Actor] The player's character.
    # @param rebuilt [Opponent] Its rebuild.
    # @return [Array<Array>] How many states each resists, and each state whose rate differs.
    def self.state_rows(yours, rebuilt)
      ids = (1...$data_states.size).select { |id| $data_states[id] }
      rows = [["States resisted", ids.count { |id| yours.state_resist?(id) }, ids.count { |id| rebuilt.state_resist?(id) }]]
      ids.each do |id|
        mine = state_value(yours, id)
        theirs = state_value(rebuilt, id)
        rows.push(["State #{$data_states[id].name}", mine, theirs]) unless mine == theirs
      end
      rows
    end

    # Compares the equipment.
    #
    # @param yours [Game_Actor] The player's character.
    # @param rebuilt [Opponent] Its rebuild.
    # @return [Array<Array>] Each equipment slot's item, with its gems.
    def self.equipment_rows(yours, rebuilt)
      [yours.equips.size, rebuilt.equips.size].max.times.map do |slot|
        ["Slot #{slot}", item_text(yours.equips[slot]), item_text(rebuilt.equips[slot])]
      end
    end

    # Writes an item for the report.
    #
    # @param item [RPG::EquipItem, nil] The item in a slot.
    # @return [String] The item's base name, then its gems' ids, "-" for an empty slot.
    def self.item_text(item)
      return "-" unless item

      base = item.respond_to?(:base_data) ? item.base_data : item
      gems = Array(MGQ_MpGame.get(item, :stones)).compact
      gems.empty? ? base.name : "#{base.name} [#{gems.join(' ')}]"
    end

    # Writes a state rate for the report.
    #
    # @param battler [Game_Battler] The battler.
    # @param id [Integer] The state.
    # @return [String] The state's rate, "resisted" when resisted.
    def self.state_value(battler, id)
      battler.state_resist?(id) ? "resisted" : percent(battler.state_rate(id))
    end

    # Lists the states on a battler.
    #
    # @param battler [Game_Battler] The battler.
    # @return [String] The states on the battler right now, by name.
    def self.state_names(battler)
      names = battler.states.map(&:name)
      names.empty? ? "-" : names.join(", ")
    end

    # Writes the levels of a battler.
    #
    # @param battler [Game_Battler] The battler.
    # @return [String] Personal, job and race level.
    def self.levels(battler)
      "#{battler.base_level}/#{battler.class_level}/#{battler.tribe_level}"
    end

    # Writes skill or ability ids for the report.
    #
    # @param ids [Array<Integer>] Skill or ability ids.
    # @return [String] The first eight of them, "-" for none.
    def self.ids_text(ids)
      ids.empty? ? "-" : ids.first(8).join(" ")
    end

    # Writes a rate for the report.
    #
    # @param rate [Float] A rate, 1.0 for 100%.
    # @return [String] A rate as a percentage.
    def self.percent(rate)
      format("%.1f%%", rate.to_f * 100)
    end

    # Writes a row of the report.
    #
    # @param label [String] What the row compares.
    # @param mine [Object] The player's character's value.
    # @param theirs [Object] The rebuild's value.
    # @param differs [Boolean] Whether to mark the row.
    # @return [String] One row: label and both values, marked when they differ.
    def self.row(label, mine, theirs, differs)
      label.to_s.ljust(LABEL_WIDTH) + mine.to_s.rjust(VALUE_WIDTH) + "  " + theirs.to_s.rjust(VALUE_WIDTH) + (differs ? MARK : "")
    end
  end
end
