#----------------------------------------------------------------
#  world_gates.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Asked the rules in C# which area a move enters and what the world's story still lacks
#      Paulinchen  2026-11-05: Left what a move kept back leaves to the one guard of the game's flow
#                            - Counted the notices' pause by the bridge's frame
#      Paulinchen  2026-10-24: Created
#
#----------------------------------------------------------------

# A Raid World's gated areas, as the rules in C# keep them (WorldGates): places the game lets a
# player into at any time, whose end needs story the world has not finished yet. Every move into one
# from outside waits until the world's story meets the area's needs, and an event that would lead
# there leaves out the commands or the choice's option that do, so nobody fights their way to its
# entrance first.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpWorldGates
  # A shut area a move would enter: its name and the names of the needs the world's story lacks.
  Shut = Struct.new(:name, :missing)

  # The topic that names the variables the gates read.
  READS_TOPIC = "gates.reads"

  # The topic that finds the shut area a move would enter.
  SHUT_TOPIC = "gates.shut"

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

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "world gates"

  # When the player last heard why an area is shut, by its name.
  @noticed = {}

  # Finds the shut area a move to a map would enter in a Raid World, as the rules in C# find it
  # (topic gates.shut) from the world's story the player's game holds.
  #
  # @param map_id [Integer] The map the move goes to.
  # @return [Shut, nil] The area, nil when the move may go.
  def self.shut_area(map_id)
    return nil unless MGQ_MpCoop::Scope.raid?

    @reads ||= MGQ_Multiplayer::Bridge.call!(READS_TOPIC)
    answer = MGQ_Multiplayer::Bridge.call!(SHUT_TOPIC, "to" => map_id, "at" => $game_map.map_id, "v" => @reads.map { |id| $game_variables[id].to_i })
    answer ? Shut.new(answer["area"], answer["missing"]) : nil
  end

  # Lets a move go unless it enters a shut area, telling the player what the area still needs and
  # putting back what the move would have, such as the light (see MGQ_MpFlowGuard.refused). Called
  # around Game_Player#reserve_transfer, which the game's transfers, the relay map and the mod's
  # follows and teleports all go through.
  #
  # The game's scenes fade the screen out before they move the player, so a move kept back would
  # leave it black.
  #
  # @param map_id [Integer] The map the move goes to.
  # @yield The move.
  def self.reserve(map_id)
    area = shut_area(map_id)
    return yield unless area

    log_once([:refused, area.name, $game_map.map_id], "kept the player out of map #{map_id} of #{area.name}: the world's story lacks #{area.missing.join(', ')}")
    tell_shut(area)
    MGQ_MpFlowGuard.refused("#{area.name} is shut") if defined?(MGQ_MpFlowGuard)
  rescue => e
    log("checking a move for a gated area failed: #{e.class}: #{e.message}")
    yield
  end

  # Tells the player what an area still needs, once in NOTICE_FRAMES.
  #
  # @param area [Shut] The area.
  def self.tell_shut(area)
    last = @noticed[area.name]
    return if last && MGQ_Multiplayer::Bridge.frame_number - last < NOTICE_FRAMES

    @noticed[area.name] = MGQ_Multiplayer::Bridge.frame_number
    MGQ_MpOverworldSync.notice("#{area.name} opens once the world finished: #{area.missing.join(', ')}.")
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
