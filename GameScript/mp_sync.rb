#----------------------------------------------------------------
#  mp_sync.rb
#
#  Changelog:
#      Paulinchen  2026-09-29: Broke a live battle off for both players when the host's recording stops
#                            - Stopped a recording when the live battle finishes
#                            - Recorded the hit and defeat effects the game starts without the setter
#                            - Ended the guest's turn, so every command phase chooses anew
#                            - Checked the link without the friend's team
#      Paulinchen  2026-09-28: Created
#
#----------------------------------------------------------------

# Live battles, in which two players each command their own team: the host's game computes the
# battle and streams what it shows, the guest's game plays that back and sends its commands.
#
# Each game sees its own team as the party, so the two would draw their random numbers in a
# different order if both computed.
module MGQ_MpSync
  # File inside the Multiplayer folder that a recorded battle writes into.
  RECORDING_FILE = "Battle Recording.log"

  # What happens when the friend leaves or the connection drops: :win ends the battle as won,
  # :computer lets the computer play the friend's team on, which only the host can do, since only
  # its game computes the battle.
  DROPOUT = :win

  # Frames a battle message stays before it moves on by itself, so neither player holds the
  # battle up for the other.
  MESSAGE_FRAMES = 90

  # Frames between two sends of what the host's battle showed, a sixth of a second.
  SEND_FRAMES = 10

  # Frames the guest waits for the host's stream before it says it is waiting.
  QUIET_FRAMES = 20

  # Frames between two looks at whether the link still stands.
  LINK_CHECK_FRAMES = 60

  # Sends of the host's stream waiting on the guest from which the guest skips waits to catch up,
  # about two thirds of a second behind.
  BEHIND_SENDS = 4

  # The host's settings that leave parts of a battle unshown. The host turns them off for a live
  # battle, since the guest sees only what the host's battle shows; the battle's snapshot puts
  # them back after it.
  SKIP_SETTINGS = [:bt_skip, :bt_skip_cutin, :bt_skip_enemy_cutin, :bt_skip_chain_action_cutin,
                   :skip_battle_start_skill_effect, :skip_skill_effect]

  class << self
    # The side this game plays in a live battle.
    #
    # @return [Symbol, nil] :host or :guest during a live battle, nil otherwise.
    attr_reader :role

    # The friend who plays the other side.
    #
    # @return [String] The friend's name.
    attr_reader :player
  end

  # Reports whether the hooks can be installed.
  #
  # A second copy of this script would wrap the same methods under the same names, and each hook
  # would then call itself until the stack overflows.
  #
  # @return [Boolean] false when the hooks are in place already.
  def self.hookable?
    !SceneManager.respond_to?(:mgq_mp_sync_run)
  end

  # Writes a line to the Multiplayer mod's InGame.log.
  #
  # @param message [String] The line.
  def self.log(message)
    MGQ_Multiplayer::Log.write("sync: #{message}")
  rescue
  end

  # Makes the next battle live, when the link to the friend stands. The mode calls battle_started
  # once that battle starts.
  #
  # @param state [Hash] How the connection stands, see MGQ_Multiplayer::Link.state.
  # @return [Boolean] Whether the battle is live, false for a battle of its own on each side.
  def self.join(state)
    return false unless state["link"] == "open" && %w(host guest).include?(state["role"])

    @role = state["role"].to_sym
    @player = MGQ_Multiplayer.clean(state["opponent"])
    @solo = false
    @broken = false
    @battle_running = false
    Channel.reset
    log("live battle as #{@role}")
    true
  rescue => e
    log("could not go live: #{e.class}: #{e.message}")
    false
  end

  # Marks the live battle as started. Called by the mode once its battle scene is on the way.
  def self.battle_started
    @battle_running = true if @role
  end

  # Has the next battle write what it shows into RECORDING_FILE, such as a mirror match.
  def self.record_to_file
    @record_next = true
  end

  # Takes the request to record the battle starting now.
  #
  # @return [Boolean] Whether the battle starting now is to be recorded, asked once per battle.
  def self.take_file_recording
    recording = @record_next ? true : false
    @record_next = false
    recording
  end

  # Ends the live battle and closes the link, and stops a recording. Called by the mode when it puts
  # the game back, and after a reset.
  def self.finish
    Recorder.stop
    @record_next = false
    return unless @role

    @role = nil
    @broken = false
    @battle_running = false
    MGQ_Multiplayer::Link.cancel
  rescue => e
    log("finish failed: #{e.class}: #{e.message}")
  end

  # Breaks the live battle off without a winner, once something went wrong on either side.
  #
  # @param reason [String] What went wrong, for InGame.log.
  # @param tell_friend [Boolean] Whether the friend's game still has to hear of it.
  def self.break_off(reason, tell_friend = true)
    return if @broken || !@role

    @broken = true
    log("the live battle broke off: #{reason}")
    Channel.post("broken") if tell_friend
  rescue => e
    log("break-off failed: #{e.class}: #{e.message}")
  end

  # Tells whether the live battle broke off.
  #
  # @return [Boolean] Whether either game broke the live battle off.
  def self.broken?
    @broken ? true : false
  end

  # Tells whether a live battle runs.
  #
  # @return [Boolean] Whether a live battle runs.
  def self.live?
    @role && @battle_running ? true : false
  end

  # Tells whether this game is the host.
  #
  # @return [Boolean] Whether this game computes the live battle.
  def self.host?
    live? && @role == :host
  end

  # Tells whether this game is the guest.
  #
  # @return [Boolean] Whether this game plays the live battle back.
  def self.guest?
    live? && @role == :guest
  end

  # Tells whether the computer took over the friend's team.
  #
  # @return [Boolean] Whether the friend left and the computer plays their team instead.
  def self.solo?
    @solo ? true : false
  end

  # Turns off the host's settings that would keep parts of the battle from the guest.
  def self.show_everything
    SKIP_SETTINGS.each { |key| $game_system.conf[key] = false if $game_system.conf.key?(key) }
  end

  # Ends the battle once the friend is gone: won, or played on by the computer on the host.
  #
  # @param scene [Scene_Battle] The battle.
  # @return [Boolean] true when the battle goes on with the computer.
  def self.friend_gone(scene)
    log("the link to #{@player} ended")

    if host? && DROPOUT == :computer
      @solo = true
      return true
    end

    $game_message.add("#{@player} left the battle.")
    BattleManager.process_victory
    false
  end

  # Writes values as one line of tab-separated tokens and reads them back, for the messages
  # between the two games. Only plain values travel, never code or Ruby's own formats, since
  # the other game could send anything.
  module Wire
    # Characters a text escapes, which would otherwise end a token or a line.
    ESCAPES = { "\\" => "\\\\", "\t" => "\\t", "\n" => "\\n", "\r" => "\\r" }

    # The escapes turned back.
    UNESCAPES = ESCAPES.invert

    # Longest symbol taken from the other game. Symbols are never freed.
    SYMBOL_PATTERN = /\A\w{1,40}\z/

    # Writes values.
    #
    # @param values [Array] nil, true, false, numbers, symbols, texts, battlers, skills, items,
    #   colors, tones and arrays of these.
    # @return [String] The line.
    def self.line(values)
      values.map { |value| tokens(value) }.flatten.join("\t")
    end

    # Reads a line.
    #
    # @param line [String] The line.
    # @yieldparam ref [String] A battler's reference, such as "a0".
    # @yieldreturn [Game_Battler, nil] The battler it names.
    # @return [Array, nil] The values, nil when the line is broken.
    def self.parse(line, &battler)
      stack = [[]]
      line.split("\t").each do |token|
        if token == "["
          stack.push([])
        elsif token == "]"
          return nil if stack.size < 2

          inner = stack.pop
          stack.last << inner
        else
          stack.last << value(token[0, 1], token[1..-1].to_s, &battler)
        end
      end
      stack.size == 1 ? stack[0] : nil
    end

    # Turns a value into tokens.
    #
    # @param value [Object] A value.
    # @return [Array<String>] Its tokens.
    def self.tokens(value)
      case value
      when nil then ["~"]
      when true then ["+"]
      when false then ["-"]
      when Integer then ["i#{value}"]
      when Float then ["f#{value}"]
      when Symbol then [":#{escape(value.to_s)}"]
      when Game_Battler then ["@#{Recorder.ref(value)}"]
      when RPG::Skill then ["k#{value.id}"]
      when RPG::Item then ["t#{value.id}"]
      when Color then ["c#{[value.red, value.green, value.blue, value.alpha].map(&:to_i).join(',')}"]
      when Tone then ["n#{[value.red, value.green, value.blue, value.gray].map(&:to_i).join(',')}"]
      when Array then ["["] + value.map { |item| tokens(item) }.flatten + ["]"]
      else ["s#{escape(value.to_s)}"]
      end
    end

    # Reads a value back from a token.
    #
    # @param kind [String] The token's first character.
    # @param rest [String] The rest of the token.
    # @yieldparam ref [String] A battler's reference.
    # @return [Object] The value, nil for anything unknown.
    def self.value(kind, rest)
      case kind
      when "+" then true
      when "-" then false
      when "i" then rest.to_i
      when "f" then rest.to_f
      when ":" then (text = unescape(rest)) =~ SYMBOL_PATTERN ? text.to_sym : nil
      when "s" then unescape(rest)
      when "@" then block_given? ? yield(rest) : nil
      when "k" then (id = rest.to_i) > 0 ? $data_skills[id] : nil
      when "t" then (id = rest.to_i) > 0 ? $data_items[id] : nil
      when "c" then Color.new(*numbers(rest, 4))
      when "n" then Tone.new(*numbers(rest, 4))
      end
    end

    # Reads a list of numbers.
    #
    # @param text [String] Numbers joined by ",".
    # @param count [Integer] How many are needed.
    # @return [Array<Float>] The numbers, 0 for those missing.
    def self.numbers(text, count)
      values = text.split(",").first(count).map(&:to_f)
      values + [0.0] * (count - values.size)
    end

    # Escapes a text for a token.
    #
    # @param text [String] A text.
    # @return [String] The text without tabs or line breaks.
    def self.escape(text)
      text.gsub(/[\\\t\n\r]/) { |character| ESCAPES[character] }
    end

    # Reads an escaped text back.
    #
    # @param text [String] An escaped text.
    # @return [String] The text.
    def self.unescape(text)
      text.gsub(/\\[\\tnr]/) { |escape| UNESCAPES[escape] }
    end
  end

  # The messages between the two games during a live battle: a kind on the first line, the rest
  # after it.
  module Channel
    # Forgets messages of an earlier battle.
    def self.reset
      @messages = []
      @checked = 0
      @gone = false
    end

    # Sends a message.
    #
    # @param kind [String] What it is.
    # @param body [String] The rest.
    # @return [Boolean] Whether it went out.
    def self.post(kind, body = "")
      MGQ_Multiplayer::Link.post("#{kind}\n#{body}")
    end

    # Takes the oldest message of a kind that arrived.
    #
    # @param kind [String] The kind.
    # @return [String, nil] Its body, nil while none arrived.
    def self.take(kind)
      poll
      index = @messages.index { |message| message[0] == kind }
      index ? @messages.delete_at(index)[1] : nil
    end

    # Reports whether the link to the friend has ended, asking the DLL every LINK_CHECK_FRAMES calls.
    #
    # @return [Boolean] Whether the link has ended.
    def self.gone?
      return true if @gone

      @checked = (@checked || 0) + 1
      return false if @checked < LINK_CHECK_FRAMES

      @checked = 0
      @gone = MGQ_Multiplayer::Link.status["link"] != "open"
    end

    # Reports why the friend's game will send nothing more for the battle, taking a forfeit or
    # break-off that arrived.
    #
    # @return [Symbol, nil] :forfeit when the friend forfeited, :broken when either game broke the
    #   battle off, :gone when the link ended, nil while the battle goes on.
    def self.ending
      return :forfeit if take("forfeit")

      MGQ_MpSync.break_off("#{MGQ_MpSync.player}'s game broke it off", false) if take("broken")
      return :broken if MGQ_MpSync.broken?

      gone? ? :gone : nil
    end

    # Counts the waiting messages of a kind.
    #
    # @param kind [String] A kind of message.
    # @return [Integer] How many of that kind arrived and wait.
    def self.pending(kind)
      poll
      @messages.count { |message| message[0] == kind }
    end

    # Moves the messages that arrived into the queue.
    def self.poll
      @messages ||= []
      while (text = MGQ_Multiplayer::Link.next_message)
        kind, body = text.split("\n", 2)
        @messages << [kind.to_s, body.to_s]
      end
    end
  end

  # The guest's commands: every Frontline member's actions, which the host gives the friend's
  # rebuilt characters. The troop of one game is the party of the other in the same order, so a
  # target's index means the same member on both sides.
  module Commands
    # Writes the guest's commands.
    #
    # @return [String] The commands.
    def self.build
      commands = $game_party.battle_members.map do |actor|
        actor.actions.select(&:item).map do |action|
          [action.item.is_a?(RPG::Item) ? "item" : "skill", action.item.id, action.target_index]
        end
      end
      Wire.line([commands])
    end

    # Gives the friend's characters on the host the guest's commands. A character without any
    # keeps what the computer chose.
    #
    # @param body [String] The commands.
    def self.apply(body)
      values = Wire.parse(body.to_s)
      commands = values && values[0]
      return MGQ_MpSync.log("unreadable commands") unless commands.is_a?(Array)

      $game_troop.members.each_with_index do |opponent, index|
        list = commands[index]
        next unless list.is_a?(Array)

        actions = list.map { |command| action(opponent, command) }.compact
        opponent.instance_variable_set(:@actions, actions) unless actions.empty?
      end
    end

    # Turns a friend's command into an action.
    #
    # @param battler [Game_Battler] The character.
    # @param command [Array] "skill" or "item", the id and the target's index.
    # @return [Game_Action, nil] The action, nil for a command it cannot read.
    def self.action(battler, command)
      kind, id, target = command
      return nil unless command.is_a?(Array) && id.is_a?(Integer) && target.is_a?(Integer)

      action = Game_Action.new(battler)
      action.set_symbol(:count) if action.respond_to?(:set_symbol)
      case kind
      when "skill" then $data_skills[id] ? action.set_skill(id) : (return nil)
      when "item" then $data_items[id] ? action.set_item(id) : (return nil)
      else return nil
      end
      action.target_index = target
      action
    end
  end

  # Turns the host's names into the guest's in what the host's battle wrote: the host's own
  # characters are the guest's enemies, named with their owner, and the guest's characters are
  # its own, named without.
  module Names
    # Learns the names from the host's side.
    #
    # @param body [String] The host's party and troop names, see MGQ_MpSync.names.
    def self.setup(body)
      values = Wire.parse(body.to_s) || []
      party, troop = values
      @swaps = {}
      Array(party).each_with_index { |name, index| add(name, $game_troop.members[index]) }
      Array(troop).each_with_index { |name, index| add(name, $game_party.battle_members[index]) }
      names = @swaps.keys.sort_by { |name| -name.size }
      @pattern = names.empty? ? nil : Regexp.union(names)
    end

    # Swaps the names in a text.
    #
    # @param text [String] The host's text.
    # @return [String] The guest's text.
    def self.swap(text)
      @pattern ? text.gsub(@pattern) { |name| @swaps[name] } : text
    end

    # Swaps the names in a message, but not in its speaker's name box, which names a character
    # without its owner on either side.
    #
    # @param text [String] The host's message line.
    # @return [String] The guest's message line.
    def self.swap_message(text)
      text.split(/(\\n<[^>]*>)/).map { |part| part =~ /\A\\n</ ? part : swap(part) }.join
    end

    # Pairs a name of the host's side with the guest's battler.
    #
    # @param name [Object] A name of the host's side.
    # @param battler [Game_Battler, nil] The guest's battler of the same place.
    def self.add(name, battler)
      @swaps[name] = battler.name if name.is_a?(String) && !name.empty? && battler && name != battler.name
    end
  end

  # Everything the host's battle shows, in the order it shows it: battle log lines, popups,
  # messages, pictures, screen effects, sounds, animations, sprite effects and waits, with the
  # battlers' values after every action. A live battle streams it to the guest, a mirror match
  # writes it to RECORDING_FILE.
  module Recorder
    # Events kept before a mirror match writes them to the file.
    FLUSH_EVENTS = 200

    # Reports whether the battle on screen is recorded.
    #
    # @return [Boolean] Whether the battle is recorded.
    def self.active?
      @active ? true : false
    end

    # Starts recording a battle.
    #
    # @param sink [Symbol] :link to stream it to the guest, :file to write it over the last
    #   mirror match's recording.
    def self.start(sink)
      @active = true
      @sink = sink
      @frame = 0
      @events = []
      @values = {}
      @file_mode = "wb"
      event("battle", "settings", display_settings) if sink == :file
    rescue => e
      stop_after(e)
    end

    # Ends the recording and sends or writes what is left.
    #
    # @param result [Integer] The game's battle result.
    def self.finish(result)
      return unless active?

      event("battle_end", result)
      flush
      @active = false
    rescue => e
      stop_after(e)
    end

    # Counts a frame, and streams what the battle showed every SEND_FRAMES frames.
    def self.tick
      return unless active?

      @frame += 1
      flush if @sink == :link && @frame % SEND_FRAMES == 0
    end

    # Records an event.
    #
    # @param kind [String] What happened.
    # @param fields [Array] Its values, see Wire.line.
    def self.event(kind, *fields)
      return unless active?

      line = Wire.line([kind] + fields)
      @events << (@sink == :file ? "#{@frame.to_s.rjust(6)}\t#{line}" : line)
      flush if @events.size >= FLUSH_EVENTS
    rescue => e
      stop_after(e)
    end

    # Records the values of every battler that changed since the last time. The next send streams
    # them, every SEND_FRAMES frames, so the guest can tell by the sends waiting how far behind it is.
    #
    # @param full [Boolean] true to record every battler's, which corrects anything the guest
    #   missed; the host does at every command phase.
    def self.values(full = false)
      return unless active?

      @values = {} if full
      battlers.each do |battler|
        current = value_fields(battler)
        next if @values[battler.object_id] == current

        @values[battler.object_id] = current
        event("values", battler, *current)
      end
      time_stop
    rescue => e
      stop_after(e)
    end

    # Records how long time stands still and for whom, when it changed. It decides who may act,
    # so the guest needs it to offer only the commands the host will take.
    def self.time_stop
      current = [$game_party.od_turn.to_i, $game_party.od_user]
      return if @time_stop == [current[0], current[1].object_id]

      @time_stop = [current[0], current[1].object_id]
      event("time_stop", *current)
    end

    # Records a sprite effect a battler starts, after the battlers' values, since the guest needs a
    # hit's HP and a defeat's death before it shows the effect.
    #
    # @param battler [Game_Battler] The battler.
    # @param effect [Symbol, nil] The effect, nil for none.
    def self.sprite_effect(battler, effect)
      return unless active? && effect

      values
      event("battler.sprite_effect_type", battler, effect)
    end

    # Names the battler who speaks.
    #
    # @return [Game_Battler, nil] The battler whose line the game is showing.
    def self.speaker
      @speaker
    end

    # Marks a battler as the speaker of the lines the block shows.
    #
    # @param battler [Game_Battler] The battler.
    # @return [Object] What the block returns.
    def self.speaking(battler)
      @speaker = battler
      yield
    ensure
      @speaker = nil
    end

    # Names a battler by its side and place, "a0" for the party's first, "e0" for the troop's.
    #
    # @param battler [Game_Battler] A battler, or the stand-in the game uses for automatic skills.
    # @return [String] The reference, "?" for a battler outside both.
    def self.ref(battler)
      battler = battler.observer if defined?(Game_Master) && battler.is_a?(Game_Master)
      party = $game_party.battle_members.index(battler)
      return "a#{party}" if party

      troop = $game_troop.members.index(battler)
      troop ? "e#{troop}" : "?"
    end

    # Sends or writes the kept events.
    def self.flush
      return if @events.empty?

      if @sink == :link
        Channel.post("events", @events.join("\n"))
      else
        File.open(MGQ_Multiplayer.path(RECORDING_FILE), @file_mode) { |file| file.write(@events.join("\n") + "\n") }
        @file_mode = "ab"
      end
      @events = []
    end

    # Reads the host's display settings.
    #
    # @return [Array] The host's settings that leave parts of a battle unshown.
    def self.display_settings
      (SKIP_SETTINGS + [:bt_wait]).map { |key| "#{key}=#{$game_system.conf[key].inspect}" }
    end

    # Lists the battlers of the battle.
    #
    # @return [Array<Game_Battler>] Every battler of the battle.
    def self.battlers
      $game_party.battle_members + $game_troop.members
    end

    # Reads the values the stream carries of a battler.
    #
    # @param battler [Game_Battler] The battler.
    # @return [Array] Its HP and maximum, MP and maximum, SP, state ids and buffs.
    def self.value_fields(battler)
      [battler.hp, battler.mhp, battler.mp, battler.mmp, battler.tp.to_i,
       battler.states.map(&:id).sort, Array(battler.instance_variable_get(:@buffs)).map(&:to_i)]
    end

    # Stops recording without sending or writing what is left, such as after a reset.
    def self.stop
      @active = false
      @events = []
    end

    # Stops recording after an error, which stays in InGame.log, and breaks a live battle off, since
    # the guest sees nothing but the stream.
    #
    # @param error [Exception] The error.
    def self.stop_after(error)
      @active = false
      MGQ_MpSync.log("recording stopped: #{error.class}: #{error.message}")
      MGQ_MpSync.break_off("the host's recording stopped") if @sink == :link
    end
  end

  # The guest's side of a live battle: it plays what the host's battle showed instead of
  # computing its own, with the host's party as its troop and the host's troop as its party.
  module Playback
    # Battle log methods the host may have called.
    LOG_METHODS = %w(add_text replace_text back_one back_to clear clear_popup)

    # Picture methods the host may have called.
    PICTURE_METHODS = %w(show move rotate start_tone_change erase)

    # Screen methods the host may have called.
    SCREEN_METHODS = %w(start_shake start_flash start_tone_change start_fadeout start_fadein od_fadein od_fadeout)

    # Audio functions the host may have called.
    AUDIO_METHODS = %w(se_play me_play bgm_play bgs_play se_stop me_stop bgm_stop bgs_stop me_fade bgm_fade bgs_fade
                       start_over_drive end_over_drive)

    # Scene waits the host may have called, with a duration.
    TIMED_WAITS = %w(wait abs_wait)

    # Scene waits the host may have called, until something ends.
    OPEN_WAITS = %w(wait_for_animation wait_for_effect wait_for_message)

    # Sprite effects the host may have started.
    SPRITE_EFFECTS = [:appear, :disappear, :whiten, :blink, :collapse, :boss_collapse, :instant_collapse]

    # Longest wait taken from the host, 10 seconds.
    MAX_WAIT = 600

    # A picture the host may show: a file name, never a path.
    PICTURE_NAME = /\A[\w\- ]+\z/

    # Plays the host's stream until its next command phase or the battle's end.
    #
    # @param scene [Scene_Battle] The battle.
    # @return [Array, nil] The "end" event when the battle ended, an ending of Channel.ending when it
    #   ended early, nil at the next command phase.
    def self.run(scene)
      @events ||= []
      quiet = 0
      # The party's status windows show during a turn, which the guest's own battle never has.
      scene.instance_variable_set(:@battle_actor_status_windows_show, true)
      window = nil

      loop do
        event = next_event

        unless event
          ending = Channel.ending
          return [ending] if ending

          quiet += 1
          window ||= Waiting.open("Waiting for #{MGQ_MpSync.player}...") if quiet == QUIET_FRAMES
          scene.send(:update_for_wait)
          next
        end

        quiet = 0
        window = Waiting.close(window)
        return nil if event[0] == "commands"
        return event if event[0] == "end"

        play(scene, event)
        show_message if event[0] == "message" && (@events.empty? || @events.first[0] != "message")
      end
    ensure
      scene.instance_variable_set(:@battle_actor_status_windows_show, false)
      Waiting.close(window)
    end

    # Forgets events of an earlier battle.
    def self.reset
      @events = []
      @failed = {}
    end

    # Takes the next event of the host's stream.
    #
    # @return [Array, nil] The next event of the host's stream, nil while none arrived.
    def self.next_event
      while @events.empty?
        body = Channel.take("events")
        return nil unless body

        body.split("\n").each do |line|
          event = Wire.parse(line) { |ref| battler(ref) }
          @events << event if event && event[0].is_a?(String)
        end
      end
      @events.shift
    end

    # Finds the guest's battler for a reference of the host's side.
    #
    # @param ref [String] A battler of the host's side, such as "a0".
    # @return [Game_Battler, nil] The guest's battler in its place.
    def self.battler(ref)
      return nil unless ref =~ /\A([ae])(\d{1,2})\z/

      $1 == "a" ? $game_troop.members[$2.to_i] : $game_party.battle_members[$2.to_i]
    end

    # Plays one event. An event that fails is left out and logged once per kind.
    #
    # @param scene [Scene_Battle] The battle.
    # @param event [Array] The event's kind and values.
    def self.play(scene, event)
      kind, *args = event
      method = kind.split(".", 2)[1]

      case kind
      when /\Alog\./
        log_window(scene).send(method, *args.map { |arg| arg.is_a?(String) ? Names.swap(arg) : arg }) if LOG_METHODS.include?(method)
      when "popup"
        log_window(scene).popup.push(Names.swap(args[0].to_s), args[1])
      when "message"
        message(*args)
      when /\Apicture\./
        picture(method, args)
      when /\Ascreen\./
        $game_troop.screen.send(method, *args) if SCREEN_METHODS.include?(method)
      when /\Aaudio\./
        Audio.send(method, *args) if AUDIO_METHODS.include?(method)
      when "animation"
        animation(scene, *args)
      when "battler.sprite_effect_type"
        sprite_effect(*args)
      when "skill_name"
        (args[0] == "troop" ? $game_troop : $game_party).display_skill_name = args[1].is_a?(String) ? Names.swap(args[1]) : nil
      when /\Ascene\./
        wait(scene, method, args[0])
      when "values"
        values(*args)
        scene.send(:refresh_status)
      when "time_stop"
        $game_party.od_turn = args[0].to_i
        $game_party.od_user = args[1]
      when "turn"
        $game_troop.instance_variable_set(:@turn_count, args[0].to_i)
      end
    rescue => e
      @failed ||= {}
      MGQ_MpSync.log("could not play #{kind}: #{e.class}: #{e.message}") unless @failed[kind]
      @failed[kind] = true
    end

    # Starts a sprite effect the host started. The host's characters fall with an actor's collapse,
    # but on the guest they are the enemy side, which stays as a silhouette after the defeat flash.
    #
    # @param battler [Game_Battler, nil] The guest's battler.
    # @param effect [Symbol] The effect.
    def self.sprite_effect(battler, effect)
      return unless battler && SPRITE_EFFECTS.include?(effect)

      collapse = [:collapse, :boss_collapse, :instant_collapse].include?(effect)
      battler.sprite_effect_type = collapse && $game_troop.members.include?(battler) ? :whiten : effect
    end

    # Finds the battle log of a battle scene.
    #
    # @param scene [Scene_Battle] The battle.
    # @return [Window_BattleLog] Its battle log.
    def self.log_window(scene)
      scene.instance_variable_get(:@log_window)
    end

    # Shows a line a character says, with its face.
    #
    # @param speaker [Game_Battler, nil] Who says it, which decides the side of its box.
    # @param face_name [String] The face file.
    # @param face_index [Integer] The face in the file.
    # @param background [Integer] The window's background.
    # @param position [Integer] The window's position.
    # @param text [String] The line.
    def self.message(speaker, face_name, face_index, background, position, text)
      @speaker = speaker
      $game_message.face_name = face_name.to_s
      $game_message.face_index = face_index.to_i
      $game_message.background = background.to_i
      $game_message.position = position.to_i
      $game_message.add(Names.swap_message(text.to_s))
    end

    # Puts a message whose last line arrived into a box of the Battle Dialogue mod of the
    # MGQ-Paradox-Mod-Collection, which the host's battle did the same with, so the guest never
    # waits for its message window. Without the mod, the message window moves on by itself.
    def self.show_message
      return unless defined?(Battle_Dialogue) && Battle_Dialogue.active?

      Battle_Dialogue.speaking(@speaker) { Battle_Dialogue.take_message }
    end

    # Changes a picture, such as a cut-in.
    #
    # @param method [String] What the host did with it.
    # @param args [Array] The picture's number, then the method's arguments.
    def self.picture(method, args)
      number = args[0].to_i
      return unless PICTURE_METHODS.include?(method) && number > 0 && number <= 100
      return if method == "show" && args[1].to_s !~ PICTURE_NAME

      $game_troop.screen.pictures[number].send(method, *args[1..-1])
    end

    # Starts an animation on the guest's battlers, unless the guest holds the skip key or has to
    # catch up. It only starts it: the host's recorded waits that follow keep the pace, and the
    # game's own animation methods would wait a second time.
    #
    # @param scene [Scene_Battle] The battle.
    # @param subject [Game_Battler, nil] Who acts, whose weapons an attack animation shows.
    # @param targets [Array] The targets.
    # @param animation_id [Integer] The animation, below 0 for the subject's attack animation.
    def self.animation(scene, subject, targets, animation_id)
      return if behind? || scene.send(:battle_show_skip?)

      ids = animation_id.to_i < 0 ? (subject && subject.actor? ? subject.atk_animation_ids.first(1) : []) : [animation_id.to_i]
      ids.each do |id|
        next unless $data_animations[id]

        Array(targets).compact.each do |target|
          target.animation_id = id
          target.animation_mirror = false
        end
      end
    end

    # Tells whether the guest fell behind the host's stream.
    #
    # @return [Boolean] Whether the host's stream piled up, so the guest skips waits to catch up.
    def self.behind?
      Channel.pending("events") >= BEHIND_SENDS
    end

    # Waits the way the host's battle waited, at the guest's own battle speed, unless it has to
    # catch up.
    #
    # @param scene [Scene_Battle] The battle.
    # @param method [String] The wait.
    # @param duration [Integer, nil] Its frames, for a timed wait.
    def self.wait(scene, method, duration)
      return if behind?

      if TIMED_WAITS.include?(method)
        scene.send(method, [duration.to_i, MAX_WAIT].min)
      elsif OPEN_WAITS.include?(method)
        scene.send(method)
      end
    end

    # Gives a battler the values the host computed.
    #
    # @param battler [Game_Battler, nil] The guest's battler.
    # @param hp [Integer] Its HP.
    # @param _mhp [Integer] Its maximum HP on the host.
    # @param mp [Integer] Its MP.
    # @param _mmp [Integer] Its maximum MP on the host.
    # @param tp [Integer] Its SP.
    # @param states [Array<Integer>] Its state ids.
    # @param buffs [Array<Integer>] Its buffs.
    def self.values(battler, hp, _mhp, mp, _mmp, tp, states, buffs)
      return unless battler

      battler.instance_variable_set(:@hp, hp.to_i)
      battler.instance_variable_set(:@mp, mp.to_i)
      battler.instance_variable_set(:@tp, tp.to_i)
      ids = Array(states).map(&:to_i).select { |id| $data_states[id] }
      turns = battler.instance_variable_get(:@state_turns) || {}
      ids.each { |id| turns[id] ||= 1 }
      battler.instance_variable_set(:@states, ids)
      battler.instance_variable_set(:@buffs, Array(buffs).map(&:to_i)) if Array(buffs).size == 8
    end
  end

  # The box that says what the game waits for.
  module Waiting
    # Opens the box.
    #
    # @param text [String] What the game waits for.
    # @return [Window_Base] The box.
    def self.open(text)
      width = 360
      window = Window_Base.new((Graphics.width - width) / 2, 120, width, 48)
      window.z = 250
      window.contents.draw_text(0, 0, window.contents.width, window.contents.height, text, 1)
      window
    end

    # Closes a box.
    #
    # @param window [Window_Base, nil] The box.
    def self.close(window)
      window.dispose if window && !window.disposed?
      nil
    end

    # Waits, with the box open, until the block has an answer or the battle ended early.
    #
    # @param scene [Scene_Battle] The battle.
    # @param text [String] What the game waits for.
    # @yieldreturn [String, nil] The answer, nil to wait on.
    # @return [String, Symbol] The answer, or an ending of Channel.ending.
    def self.wait_for(scene, text)
      window = nil
      loop do
        answer = yield
        return answer if answer

        ending = Channel.ending
        return ending if ending

        window ||= open(text)
        scene.send(:update_for_wait)
      end
    ensure
      close(window)
    end
  end

  # Lists the names the guest swaps.
  #
  # @return [String] The names of this game's party and troop, which the guest swaps for its own.
  def self.names
    Wire.line([$game_party.battle_members.map(&:name), $game_troop.members.map(&:name)])
  end

  # The game hooks, which run the original and return its result unless a live battle's side takes
  # the method over.
  #
  # The game's plugins load after the Patch folder and some define battle methods anew, which drops
  # a hook installed before them, so the hooks go in once the first scene starts.
  module Hooks
    # The battle log's primitives, which every battle log line goes through.
    LOG_METHODS = [:add_text, :replace_text, :back_one, :back_to, :clear, :clear_popup, :wait]

    # What pictures do, such as a cut-in.
    PICTURE_METHODS = [:show, :move, :rotate, :start_tone_change, :erase]

    # What the screen does, such as a flash, and the darkening while time stands still.
    SCREEN_METHODS = [:start_shake, :start_flash, :start_tone_change, :start_fadeout, :start_fadein, :od_fadein, :od_fadeout]

    # Every sound and piece of music, and the music fading while time stands still.
    AUDIO_METHODS = [:se_play, :me_play, :bgm_play, :bgs_play, :se_stop, :me_stop, :bgm_stop, :bgs_stop,
                     :me_fade, :bgm_fade, :bgs_fade, :start_over_drive, :end_over_drive]

    # The animation a battler starts on its sprite. The sprite clears it again once taken, which is not recorded.
    ANIMATION_SETTERS = [:animation_id=, :animation_mirror=]

    # Where the game starts a hit's and a defeat's sprite effect, by writing the battler's field
    # directly, which the setter's hook never sees.
    EFFECT_METHODS = [:perform_damage_effect, :perform_collapse_effect]

    # The scene's waits, which set the battle's pace.
    SCENE_WAITS = [:wait, :abs_wait, :wait_for_animation, :wait_for_effect, :wait_for_message]

    # Installs the hooks, a failing group alone left out. Calling it again does nothing.
    def self.install
      return if @installed
      @installed = true

      [:battle_log, :messages, :pictures, :audio, :battlers, :course, :live].each do |group|
        begin
          send(group)
        rescue => e
          MGQ_MpSync.log("#{group} hooks FAILED: #{e.class}: #{e.message}")
        end
      end
    end

    # The battle log's lines and the popups over them.
    def self.battle_log
      LOG_METHODS.each { |name| record_before(Window_BattleLog, name) { |_log, args| ["log.#{name}", *args] } }
      record_before(PopupResults, :push) { |_popups, args| ["popup", *args] }
    end

    # Messages with their face and speaker, such as the lines characters say when they use a skill
    # or fall, which move on by themselves in a live battle.
    #
    # A line names its speaker by name only, which both teams can share.
    def self.messages
      record_before(Game_Message, :add) do |message, args|
        ["message", Recorder.speaker, message.face_name, message.face_index, message.background, message.position, *args]
      end
      wrap(Scene_Battle, :process_skill_word) do |scene, _args, original|
        Recorder.speaking(scene.instance_variable_get(:@subject)) { original.call }
      end
      wrap(Scene_Battle, :process_down_word) do |_scene, args, original|
        Recorder.speaking(args[0]) { original.call }
      end
      wrap(Window_Message, :input_pause) do |window, _args, original|
        next original.call unless MGQ_MpSync.live? && $game_party.in_battle

        window.pause = true
        frames = 0
        until frames >= MESSAGE_FRAMES || Input.trigger?(:B) || Input.trigger?(:C)
          Fiber.yield
          frames += 1
        end
        Input.update
        window.pause = false
      end
    end

    # Pictures and the battle screen's effects.
    def self.pictures
      PICTURE_METHODS.each do |name|
        record_before(Game_Picture, name) do |picture, args|
          ["picture.#{name}", picture.number, *args] unless name == :erase && picture.name.empty?
        end
      end
      SCREEN_METHODS.select { |name| Game_Screen.method_defined?(name) }.each do |name|
        record_before(Game_Screen, name) { |screen, args| ["screen.#{name}", *args] if screen.equal?($game_troop.screen) }
      end
    end

    # Every call of Audio, including the sounds the battle log plays directly.
    def self.audio
      owner = Audio.singleton_class
      AUDIO_METHODS.select { |name| owner.method_defined?(name) }.each do |name|
        record_before(owner, name) { |_audio, args| ["audio.#{name}", *args] }
      end
    end

    # Animations, sprite effects and the skill name.
    def self.battlers
      ANIMATION_SETTERS.each do |name|
        kind = "battler.#{name.to_s.chomp('=')}"
        record_before(Game_Battler, name) { |battler, args| [kind, battler, args[0]] if args[0] && args[0] != 0 }
      end
      wrap(Game_Battler, :sprite_effect_type=) do |battler, args, original|
        Recorder.sprite_effect(battler, args[0])
        original.call
      end
      [Game_Actor, Game_Enemy].product(EFFECT_METHODS).each do |owner, name|
        wrap(owner, name) do |battler, _args, original|
          result = original.call
          Recorder.sprite_effect(battler, battler.sprite_effect_type)
          result
        end
      end
      record_before(Game_Unit, :display_skill_name=) do |unit, args|
        ["skill_name", unit.equal?($game_party) ? "party" : "troop", args[0]]
      end
    end

    # The battle's course as the host records it: turns, actions, animations and waits, with the
    # values after each action.
    def self.course
      record_before(Scene_Battle, :turn_start) { |_scene, _args| ["turn", $game_troop.turn_count + 1] }

      # Recorded before the game checks the skip key, which leaves the animation out on this screen only.
      record_before(Scene_Battle, :show_animation) do |scene, args|
        ["animation", scene.instance_variable_get(:@subject), args[0], args[1]]
      end

      wrap(Scene_Battle, :turn_end) do |scene, _args, original|
        Recorder.event("turn_end")
        result = original.call
        Recorder.values(true)
        Recorder.event("commands") unless scene.send(:scene_changing?)
        Recorder.flush if Recorder.active?
        result
      end

      wrap(Scene_Battle, :apply_item_effects) do |_scene, _args, original|
        result = original.call
        Recorder.values
        result
      end

      wrap(Scene_Battle, :use_item) do |scene, _args, original|
        Recorder.values
        if Recorder.active?
          subject = scene.instance_variable_get(:@subject)
          action = subject && subject.current_action
          Recorder.event("action", subject, action && action.item, action && action.target_index, action && action.symbol)
        end
        result = original.call
        Recorder.values
        result
      end

      SCENE_WAITS.select { |name| Scene_Battle.method_defined?(name) }.each do |name|
        record_before(Scene_Battle, name) { |_scene, args| ["scene.#{name}", *args] }
      end

      wrap(Scene_Battle, :update_basic) do |_scene, _args, original|
        Recorder.tick
        original.call
      end

      [:process_victory, :process_defeat, :process_abort].each do |name|
        wrap(BattleManager.singleton_class, name) do |_manager, _args, original|
          if Recorder.active?
            Recorder.event("end", name.to_s)
            Recorder.flush
          end
          original.call
        end
      end

      wrap(BattleManager.singleton_class, :battle_end) do |_manager, args, original|
        Recorder.finish(args[0])
        original.call
      end
    end

    # The live battle's flow on both sides: the start both wait for, the host waiting for the
    # guest's commands, the guest playing the host's stream, forfeits and the end.
    def self.live
      wrap(Scene_Battle, :battle_start) do |scene, _args, original|
        if MGQ_MpSync.guest?
          Live.guest_start(scene)
        elsif MGQ_MpSync.host? && !Live.host_start(scene)
          nil
        else
          Recorder.start(:file) if MGQ_MpSync.take_file_recording
          Recorder.values
          result = original.call
          Recorder.values(true)
          Recorder.event("commands") unless scene.send(:scene_changing?)
          result
        end
      end

      wrap(Scene_Battle, :turn_start) do |scene, _args, original|
        if MGQ_MpSync.guest?
          Live.guest_turn(scene)
        elsif MGQ_MpSync.host? && !MGQ_MpSync.solo?
          original.call if Live.host_commands(scene)
        else
          original.call
        end
      end

      wrap(Scene_Battle, :update) do |scene, _args, original|
        result = original.call
        Live.watch(scene) if MGQ_MpSync.live?
        result
      end

      wrap(Scene_Battle, :command_escape) do |scene, _args, original|
        MGQ_MpSync.live? ? Live.forfeit(scene) : original.call
      end

      wrap(BattleManager.singleton_class, :judge_win_loss) do |_manager, _args, original|
        MGQ_MpSync.guest? ? false : original.call
      end

      wrap(BattleManager.singleton_class, :can_giveup?) do |_manager, _args, original|
        MGQ_MpSync.live? ? false : original.call
      end
    end

    # Records an event before the original runs.
    #
    # @param owner [Module] The class that has the method.
    # @param name [Symbol] The method.
    # @yieldparam object [Object] The object the method runs on.
    # @yieldparam args [Array] The method's arguments.
    # @yieldreturn [Array, nil] The event's kind and fields, nil to record nothing.
    def self.record_before(owner, name, &event)
      wrap(owner, name) do |object, args, original|
        if Recorder.active?
          fields = event.call(object, args)
          Recorder.event(*fields) if fields
        end
        original.call
      end
    end

    # Wraps a method in a block that decides when the original runs. Every wrap keeps the method it
    # wraps under a name of its own, since a method can be wrapped twice.
    #
    # @param owner [Module] The class that has the method.
    # @param name [Symbol] The method.
    # @yieldparam object [Object] The object the method runs on.
    # @yieldparam args [Array] The method's arguments.
    # @yieldparam original [Proc] Runs the original with the arguments and returns its result.
    # @yieldreturn [Object] What the method returns.
    def self.wrap(owner, name, &body)
      @wraps = (@wraps || 0) + 1
      original = :"mgq_mp_sync_#{name.to_s.gsub(/[=?!]/, '_')}_#{@wraps}"
      owner.send(:alias_method, original, name)
      owner.send(:define_method, name) do |*args|
        body.call(self, args, lambda { send(original, *args) })
      end
    end
  end

  # The steps of a live battle that differ between host and guest.
  module Live
    # The host waits for the guest's battle, then streams its own.
    #
    # @param scene [Scene_Battle] The battle.
    # @return [Boolean] Whether the battle starts, false when it ended early.
    def self.host_start(scene)
      MGQ_MpSync.show_everything
      Channel.post("ready", MGQ_MpSync.names)
      ready = Waiting.wait_for(scene, "Waiting for #{MGQ_MpSync.player}...") { Channel.take("ready") }
      return end_early(scene, ready) if ready.is_a?(Symbol)

      Recorder.start(:link)
      true
    end

    # The guest waits for the host's battle, then plays its start.
    #
    # @param scene [Scene_Battle] The battle.
    def self.guest_start(scene)
      Playback.reset
      # The game marks the party as fighting in on_battle_start, which the guest leaves out with the
      # rest of the battle's logic. Skills usable only in battle check it, and the end clears it.
      $game_party.instance_variable_set(:@in_battle, true)
      Channel.post("ready", MGQ_MpSync.names)
      names = Waiting.wait_for(scene, "Waiting for #{MGQ_MpSync.player}...") { Channel.take("ready") }
      return end_early(scene, names) if names.is_a?(Symbol)

      Names.setup(names)
      play_until_commands(scene)
    end

    # The guest sends its commands and plays the host's turn.
    #
    # @param scene [Scene_Battle] The battle.
    def self.guest_turn(scene)
      scene.instance_variable_get(:@party_command_window).close
      scene.instance_variable_get(:@actor_command_window).close
      scene.instance_variable_get(:@status_window).unselect
      scene.instance_variable_get(:@info_viewport).visible = false
      Channel.post("commands", Commands.build)
      play_until_commands(scene)
    end

    # The guest plays the host's stream, then lets its player choose or ends the battle as the
    # host's ended.
    #
    # @param scene [Scene_Battle] The battle.
    def self.play_until_commands(scene)
      event = Playback.run(scene)
      return end_early(scene, event[0]) if event && event[0].is_a?(Symbol)
      return guest_end(event[1]) if event

      # The guest's own battle never reaches the turn's end, and a command phase started in the
      # middle of one keeps the last turn's actions and skips every command.
      BattleManager.turn_end
      scene.start_party_command_selection
    end

    # Ends the guest's battle the way the host's ended, seen from the other side.
    #
    # @param result [String] How the host's battle ended.
    def self.guest_end(result)
      case result
      when "process_victory" then BattleManager.process_defeat
      when "process_defeat" then BattleManager.process_victory
      else
        $game_message.add("#{MGQ_MpSync.player} forfeited.")
        BattleManager.process_victory
      end
    end

    # The host waits for the guest's commands and gives them to the friend's characters.
    #
    # @param scene [Scene_Battle] The battle.
    # @return [Boolean] Whether the turn goes on.
    def self.host_commands(scene)
      commands = Waiting.wait_for(scene, "Waiting for #{MGQ_MpSync.player}'s commands...") { Channel.take("commands") }
      return end_early(scene, commands) if commands.is_a?(Symbol)

      Commands.apply(commands)
      true
    end

    # Ends the battle when it ended early while this game is not waiting for the friend, such as
    # while its player chooses commands. Called by the battle's every frame.
    #
    # @param scene [Scene_Battle] The battle.
    def self.watch(scene)
      return if MGQ_MpSync.solo? || scene.send(:scene_changing?) || BattleManager.battle_end?

      ending = Channel.ending
      end_early(scene, ending) if ending
    end

    # Ends the battle before its course did.
    #
    # @param scene [Scene_Battle] The battle.
    # @param reason [Symbol] An ending of Channel.ending.
    # @return [Boolean] true when the battle goes on with the computer, see MGQ_MpSync.friend_gone.
    def self.end_early(scene, reason)
      case reason
      when :forfeit
        $game_message.add("#{MGQ_MpSync.player} forfeited.")
        BattleManager.process_victory
      when :broken
        $game_message.add("The live battle broke off.")
        BattleManager.process_abort
      else
        return MGQ_MpSync.friend_gone(scene)
      end
      false
    end

    # Escape ends a live battle as lost, without the chance of failing.
    #
    # @param scene [Scene_Battle] The battle.
    def self.forfeit(scene)
      scene.instance_variable_get(:@info_viewport).visible = false
      Channel.post("forfeit")
      BattleManager.process_abort
    end
  end
end

if MGQ_MpSync.hookable?
  begin
    class << SceneManager
      alias mgq_mp_sync_run run

      # Installs the battle hooks, then runs the game.
      #
      # The game's plugins load after the Patch folder and define battle methods anew, so the hooks
      # go in once every plugin is in.
      def run
        MGQ_MpSync::Hooks.install rescue nil
        mgq_mp_sync_run
      end
    end
  rescue => e
    MGQ_MpSync.log("SceneManager hook FAILED: #{e.class}: #{e.message}")
  end
end
