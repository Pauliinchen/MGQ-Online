#----------------------------------------------------------------
#  world_gates.rbx
#
#  Changelog:
#      Paulinchen  2026-10-24: Created
#
#----------------------------------------------------------------

# A Raid World's gated areas: places the game lets a player into at any time, whose end needs story
# the world has not finished yet. Every move into one from outside waits until the world's story
# meets the area's needs, and an event that would lead there leaves out the commands or the
# choice's option that do, so nobody fights their way to its entrance first.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpWorldGates
  # One need of an area: a variable of the world's story at a value or more, named as the player
  # knows its story.
  Need = Struct.new(:variable, :value, :name)

  # One gated area: its name, its maps and what the world's story needs before anyone enters it.
  Area = Struct.new(:name, :maps, :needs)

  # The gated areas. The Realm of Chaos behind the Central Tartarus ends in the Chaos route's bad end
  # unless these ten chains are done, the same the game asks before it sets v1143 to 24 (map 1287,
  # event 233); its maps are the entrance 1836 and every map below it.
  AREAS = [
    Area.new("Central Tartarus", [1836, 1751, 1936, 1937, 1938, 1939, 1941, 1942, 1943, 1944, 1945, 1946, 1947, 1948, 1949, 1950, 1842, 1951, 1843, 1752],
             [Need.new(1311, 6, "Chaos Ilias Temple"), Need.new(1312, 7, "Chaos Dark God's Castle"), Need.new(1333, 3, "Kagetsumugi's Return"),
              Need.new(1340, 3, "Administrator's Tower"), Need.new(1344, 3, "White Rabbit's Revival"), Need.new(1345, 5, "Koron"),
              Need.new(1347, 3, "Ilias's Power-up"), Need.new(1353, 15, "Alice's Power-up"), Need.new(1362, 21, "Hero of the North"),
              Need.new(1373, 13, "Granberia's Nightmare")]),
  ]

  # The event commands of a choice, one of its options, the end of the choice, a transfer, a
  # message and its text, and the empty command that ends every block of commands.
  CHOICE_CODE = 102
  OPTION_CODE = 402
  CHOICE_END_CODE = 404
  TRANSFER_CODE = 201
  MESSAGE_CODE = 101
  TEXT_CODE = 401
  END_CODE = 0

  # Frames between two notices of the same refusal, five seconds.
  NOTICE_FRAMES = 300

  # Frames the screen takes to fade in after a move kept back, half a second, as the game's own.
  FADEIN_FRAMES = 30

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "world gates"

  # When the player last heard why an area is shut, by its name.
  @noticed = {}

  # Finds the area a map lies in.
  #
  # @param map_id [Integer] The map.
  # @return [Area, nil] The area, nil for a map in none.
  def self.area_of(map_id)
    AREAS.find { |area| area.maps.include?(map_id) }
  end

  # Lists what the world's story still lacks for an area, as the player's game holds the world's
  # story.
  #
  # @param area [Area] The area.
  # @return [Array<Need>] The needs not met.
  def self.missing(area)
    area.needs.reject { |need| $game_variables[need.variable].to_i >= need.value }
  end

  # Finds the shut area a move to a map would enter in a Raid World: one the player is not in yet
  # whose needs the world's story does not meet.
  #
  # @param map_id [Integer] The map the move goes to.
  # @return [Area, nil] The area, nil when the move may go.
  def self.shut_area(map_id)
    return nil unless MGQ_MpCoop::Scope.raid?

    area = area_of(map_id)
    return nil unless area && !(area.maps.include?($game_map.map_id) || missing(area).empty?)

    area
  end

  # Lets a move go unless it enters a shut area, telling the player what the area still needs and
  # fading the screen in again. Called around Game_Player#reserve_transfer, which the game's
  # transfers, the relay map and the mod's follows and teleports all go through.
  #
  # The game's scenes fade the screen out before they move the player, so a move kept back would
  # leave it black.
  #
  # @param map_id [Integer] The map the move goes to.
  # @yield The move.
  def self.reserve(map_id)
    area = shut_area(map_id)
    return yield unless area

    log_once([:refused, area.name, $game_map.map_id], "kept the player out of map #{map_id} of #{area.name}: the world's story lacks #{needs_text(missing(area))}")
    tell_shut(area)
    screen = $game_map.screen
    screen.start_fadein(FADEIN_FRAMES) if screen.brightness < 255
  rescue => e
    log("checking a move for a gated area failed: #{e.class}: #{e.message}")
    yield
  end

  # Tells the player what an area still needs, once in NOTICE_FRAMES.
  #
  # @param area [Area] The area.
  def self.tell_shut(area)
    last = @noticed[area.name]
    return if last && Graphics.frame_count - last >= 0 && Graphics.frame_count - last < NOTICE_FRAMES

    @noticed[area.name] = Graphics.frame_count
    MGQ_MpOverworldSync.notice("#{area.name} opens once the world finished: #{needs_text(missing(area))}.")
  end

  # Names needs for the player.
  #
  # @param needs [Array<Need>] The needs.
  # @return [String] Their names, comma separated.
  def self.needs_text(needs)
    needs.map(&:name).join(", ")
  end

  # Keeps an event from leading into a shut area before it does anything on the way: a block it
  # starts that moves the player there itself is left out (skipped_block), and a choice it shows
  # leaves out the options that lead there (gated_choice). Called before every event command.
  #
  # The game's scenes fade out, change the music and land the airship before they move the player,
  # so only a block left out from its start leaves the player as they were.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  def self.before_command(interpreter)
    list = MGQ_MpGame.get(interpreter, :list)
    index = MGQ_MpGame.get(interpreter, :index)
    return unless list && index && list[index] && MGQ_MpCoop::Scope.raid?

    changed = skipped_block(list, index, interpreter)
    choice = changed ? nil : choice_at(list, index)
    changed = gated_choice(list, choice, interpreter) if choice
    MGQ_MpGame.set(interpreter, :list, changed) if changed
  rescue => e
    log("checking an event for a gated area failed: #{e.class}: #{e.message}")
  end

  # Copies an event's commands without the block an interpreter starts at a command when the block
  # moves the player into a shut area itself: the commands of a branch, an option or the whole list
  # up to the empty command that ends it, telling the player why.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param index [Integer] The command about to run.
  # @param interpreter [Game_Interpreter] The interpreter that runs them.
  # @return [Array<RPG::EventCommand>, nil] The commands, nil unless a block starts there that does.
  def self.skipped_block(list, index, interpreter)
    indent = list[index].indent
    return nil unless index == 0 || list[index - 1].indent < indent

    finish = index
    finish += 1 while list[finish] && list[finish].indent >= indent && !(list[finish].code == END_CODE && list[finish].indent == indent)
    area = list[index...finish].map { |entry| entry.indent == indent && entry.code == TRANSFER_CODE ? shut_area(transfer_map(entry, interpreter)) : nil }.compact.first
    return nil unless area

    log_once([:skipped, area.name, interpreter.object_id, index], "left out #{finish - index} commands of an event from command #{index} on: they lead into #{area.name}, which the world's story does not open yet")
    tell_shut(area)
    list[0...index] + list[finish..-1].to_a
  end

  # Finds the choice a command shows: the command itself, or the choice right after a message's
  # text, which the game's message (Yanfly's command_101) shows along without running command 102.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param index [Integer] The command about to run.
  # @return [Integer, nil] Where the choice is, nil for none.
  def self.choice_at(list, index)
    return index if list[index].code == CHOICE_CODE
    return nil unless list[index].code == MESSAGE_CODE

    at = index + 1
    at += 1 while list[at] && [TEXT_CODE, MESSAGE_CODE].include?(list[at].code)
    list[at] && list[at].code == CHOICE_CODE ? at : nil
  end

  # Copies an event's commands with a choice's options left out that move the player into a shut
  # area, telling the player why.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param index [Integer] Where the choice is.
  # @param interpreter [Game_Interpreter] The interpreter that runs them.
  # @return [Array<RPG::EventCommand>, nil] The commands, nil when every option stays or none would.
  def self.gated_choice(list, index, interpreter)
    choice = list[index]
    parts, rest = parts_of(list, index)
    options = parts.select { |part| part[:option] }
    shut = options.map { |option| option[:commands].map { |entry| entry.code == TRANSFER_CODE ? shut_area(transfer_map(entry, interpreter)) : nil }.compact.first }
    kept = options.reject.with_index { |_option, at| shut[at] }
    return nil if kept.size == options.size || kept.empty?

    shut.compact.uniq.each { |area| tell_shut(area) }
    left_out = (options - kept).map { |option| choice.parameters[0][option[:option]].inspect }
    log("left #{left_out.join(', ')} out of a choice: it leads into #{shut.compact.map(&:name).uniq.join(', ')}, which the world's story does not open yet")
    commands = (parts - (options - kept)).flat_map do |part|
      next part[:commands] unless part[:option]

      head = part[:commands].first
      [RPG::EventCommand.new(OPTION_CODE, head.indent, [kept.index(part), head.parameters[1]])] + part[:commands][1..-1]
    end
    labels = kept.map { |option| choice.parameters[0][option[:option]] }
    cancel = cancel_place(choice.parameters[1], kept.map { |option| option[:option] })
    list[0...index] + [RPG::EventCommand.new(CHOICE_CODE, choice.indent, [labels, cancel] + choice.parameters[2..-1].to_a)] + commands + list[rest..-1]
  end

  # Splits a choice into its parts: each option from its option command to the next part, and the
  # branch of its cancel.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param index [Integer] Where the choice is.
  # @return [Array(Array<Hash>, Integer)] The parts, each :option, the option's place in the choice
  #   or nil for the cancel's branch, and :commands; and where the choice's end is.
  def self.parts_of(list, index)
    indent = list[index].indent
    parts = []
    ((index + 1)...list.size).each do |at|
      entry = list[at]
      if entry.indent == indent
        return [parts, at] if entry.code == CHOICE_END_CODE

        parts << { :option => entry.code == OPTION_CODE ? entry.parameters[0] : nil, :commands => [] }
      end
      parts.last[:commands] << entry if parts.last
    end
    [parts, list.size]
  end

  # Reads the map a transfer command goes to, directly or from a variable, as the game's command_201
  # does: a map event's direct transfer stays in its own map folder, so map 836 of an event on map
  # 1287 is map 1836.
  #
  # @param command [RPG::EventCommand] The transfer.
  # @param interpreter [Game_Interpreter] The interpreter that runs it.
  # @return [Integer] The map.
  def self.transfer_map(command, interpreter)
    return $game_variables[command.parameters[1]].to_i unless command.parameters[0] == 0

    map_id = command.parameters[1].to_i
    from = MGQ_MpGame.get(interpreter, :map_id).to_i
    from >= 1000 && MGQ_MpGame.get(interpreter, :event_id).to_i > 0 ? map_id + from / 1000 * 1000 : map_id
  end

  # Moves a choice's cancel to the place its outcome has among the options kept.
  #
  # @param type [Integer] The choice's cancel: 0 none, an option's place plus one, or past them its
  #   own branch.
  # @param kept [Array<Integer>] The places the kept options had.
  # @return [Integer] The cancel.
  def self.cancel_place(type, kept)
    return type unless type.to_i.between?(1, 4)

    place = kept.index(type - 1)
    place ? place + 1 : 0
  end
end

# Game hooks of this script alone, through core_hooks.rbx.

begin
  # A move into a shut area waits for the world's story.
  MGQ_MpHooks.around(Game_Player, :reserve_transfer, "world_gates") { |_player, args, original| MGQ_MpWorldGates.reserve(args[0].to_i) { original.call } }

  # Before an event command runs, a choice leaves out what leads into a shut area.
  MGQ_MpHooks.before(Game_Interpreter, :execute_command, "world_gates") { MGQ_MpWorldGates.before_command(self) }
rescue => e
  MGQ_MpWorldGates.log("hooks FAILED: #{e.class}: #{e.message}")
end
