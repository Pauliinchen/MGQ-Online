#----------------------------------------------------------------
#  mp_battle_sync.rbx
#
#  Changelog:
#      Paulinchen  2026-09-30: Registered with mp_overworld_sync.rbx for its messages instead of being asked by mp_overworld.rbx
#                            - Moved into Patch/Multiplayer/Scripts as mp_battle_sync.rbx, which Multiplayer.rb loads
#                            - Renamed from mp_sync.rbx, with the module MGQ_MpBattleSync
#                            - Let a co-op player who got away leave the battle, which the others fight on
#                            - Held the battle's menus while waiting, so a hidden party command no longer takes presses after auto battle
#                            - Carried co-op battles over the world's room, several guests commanding their own characters in one party
#                            - Left turning Give Up off to mp_battle.rbx, which does it for every multiplayer battle
#      Paulinchen  2026-09-29: Sent the start of a command phase before the host's own, which the host skips when none of its characters can act
#                            - Streamed the battle log's lines, the skill lines and names and who appears as calls the guest makes in its own game's language
#                            - Kept the untranslated game's speaker lines out of the name swap, and showed a translated host's name boxes as such lines on an untranslated guest
#                            - Offered to leave the battle when a wait drags on
#                            - Broke a live battle off for both players when the host's recording stops
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
module MGQ_MpBattleSync
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

    # The kind of live battle.
    #
    # @return [Symbol] :pvp, the two teams against each other, or :coop, the party together against
    #   the troop.
    attr_reader :mode

    # The world seats of the other games of a co-op battle: the guests for the host, the host for a guest.
    #
    # @return [Array<Integer>] The seats.
    attr_reader :seats

    # The co-op battle's id, which its messages carry.
    #
    # @return [String, nil] The id.
    attr_reader :battle_id
  end

  # Reports whether the hooks can be installed.
  #
  # A second copy of this script would wrap the same methods under the same names, and each hook
  # would then call itself until the stack overflows.
  #
  # @return [Boolean] false when the hooks are in place already.
  def self.hookable?
    !SceneManager.respond_to?(:mgq_mp_battle_sync_run)
  end

  # Writes a line to the mod's InGame.log.
  #
  # @param message [String] The line.
  def self.log(message)
    MGQ_Multiplayer::Log.write("battle sync: #{message}")
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
    @mode = :pvp
    @transport = :link
    @seats = []
    @battle_id = nil
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

  # Makes the next battle a live co-op battle over the world's room.
  #
  # @param role [Symbol] :host or :guest.
  # @param battle_id [String] The battle's id, which its messages carry.
  # @param seats [Array<Integer>] The other games' seats: the invited guests, or the host.
  # @param player [String] Who the waits name: the host's name, or "the party" for the host.
  def self.join_world(role, battle_id, seats, player)
    @role = role
    @player = player
    @mode = :coop
    @transport = :world
    @seats = seats.dup
    @left = []
    @battle_id = battle_id
    @solo = false
    @broken = false
    @battle_running = false
    Channel.reset
    log("co-op battle #{battle_id} as #{role}")
  end

  # Reports whether the live battle is a co-op battle.
  #
  # @return [Boolean] Whether it is.
  def self.coop?
    @role && @mode == :coop ? true : false
  end

  # Reports whether the live battle runs over the world's room.
  #
  # @return [Boolean] Whether it does.
  def self.world?
    @transport == :world
  end

  # Narrows a co-op battle's guests to those who joined.
  #
  # @param seats [Array<Integer>] Their world seats.
  def self.keep_seats(seats)
    @seats = seats.dup
  end

  # Lists the guests of a co-op battle who are still in it.
  #
  # @return [Array<Integer>] Their seats.
  def self.guests_in
    @seats - (@left || [])
  end

  # Notes that a guest left a co-op battle. The computer plays their characters for the rest of the
  # turn; the next command phase takes them out of the party (see MGQ_MpBattleCoop.settle).
  #
  # @param seat [Integer] The guest's seat.
  def self.guest_left(seat)
    return if (@left ||= []).include?(seat)

    @left << seat
    log("a guest left the co-op battle, their characters leave at the next command phase")
  end

  # Takes a message of a co-op battle from the world's room. Called by mp_overworld_sync.rbx.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it.
  # @param message [Hash] The message: "battle" its kind, "bid" the battle's id, and the body.
  def self.take(peer, message)
    return unless peer && world? && @role && message["bid"] == @battle_id

    Channel.receive(peer.seat, message["battle"].to_s, message[:payload].to_s)
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

    world = world?
    @role = nil
    @broken = false
    @battle_running = false
    @transport = nil
    # The world's room stays open after a co-op battle; only a PvP battle's link ends with it.
    MGQ_Multiplayer::Link.cancel unless world
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

    # A co-op battle plays on on the host once every guest is gone, the host's own full team again
    # from the next command phase (see MGQ_MpBattleCoop.settle); a guest whose host is gone fights on
    # alone.
    if host? && (DROPOUT == :computer || coop?)
      @solo = true
      return true
    end

    if coop?
      MGQ_MpBattleCoop.take_over(scene)
      return false
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

    # What a decoded action offers: its kind, such as :count or :chain_action, which is all the
    # game's display code reads of it.
    ActionKind = Struct.new(:symbol)

    # Writes values.
    #
    # @param values [Array] See encodable?.
    # @return [String] The line.
    def self.line(values)
      values.map { |value| tokens(value) }.flatten.join("\t")
    end

    # Tells whether a value travels as itself rather than as its text.
    #
    # @param value [Object] A value.
    # @return [Boolean] Whether it is nil, true, false, a number, a symbol, a text, a battler, a
    #   skill, item, state, weapon or armor of the database, an equipped item, an action, an action
    #   result, a color, a tone, or an array of these.
    def self.encodable?(value)
      case value
      when nil, true, false, Integer, Float, Symbol, String, Game_Battler, Game_Action, Game_ActionResult,
           RPG::Skill, RPG::Item, RPG::State, RPG::Weapon, RPG::Armor, Color, Tone
        true
      when Game_BaseItem then encodable?(value.object)
      when Array then value.all? { |item| encodable?(item) }
      else false
      end
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
        case token
        when "[", "{"
          stack.push([])
        when "]"
          return nil if stack.size < 2

          inner = stack.pop
          stack.last << inner
        when "}"
          return nil if stack.size < 2

          fields = stack.pop
          stack.last << result(fields)
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
      when Game_Action then ["x#{value.symbol}"]
      when Game_ActionResult then result_tokens(value)
      when Game_BaseItem then ["g#{tokens(value.object)[0]}"]
      when RPG::Skill then ["k#{value.id}"]
      when RPG::Item then ["t#{value.id}"]
      when RPG::State then ["z#{value.id}"]
      when RPG::Weapon then ["w#{value.id}"]
      when RPG::Armor then ["a#{value.id}"]
      when Color then ["c#{[value.red, value.green, value.blue, value.alpha].map(&:to_i).join(',')}"]
      when Tone then ["n#{[value.red, value.green, value.blue, value.gray].map(&:to_i).join(',')}"]
      when Array then ["["] + value.map { |item| tokens(item) }.flatten + ["]"]
      else ["s#{escape(value.to_s)}"]
      end
    end

    # Turns an action result into tokens: its fields as name and value, those that travel.
    #
    # @param result [Game_ActionResult] The result.
    # @return [Array<String>] Its tokens.
    def self.result_tokens(result)
      fields = result.instance_variables.map do |name|
        field = result.instance_variable_get(name)
        encodable?(field) ? tokens(name.to_s.delete("@").to_sym) + tokens(field) : []
      end
      ["{"] + fields.flatten + ["}"]
    end

    # Makes an action result of its fields.
    #
    # @param fields [Array] Names and values, taking turns.
    # @return [Game_ActionResult] The result.
    def self.result(fields)
      result = Game_ActionResult.new(nil)
      fields.each_slice(2) do |name, field|
        result.instance_variable_set(:"@#{name}", field) if name.is_a?(Symbol)
      end
      result
    end

    # Reads a value back from a token.
    #
    # @param kind [String] The token's first character.
    # @param rest [String] The rest of the token.
    # @yieldparam ref [String] A battler's reference.
    # @return [Object] The value, nil for anything unknown.
    def self.value(kind, rest, &battler)
      case kind
      when "+" then true
      when "-" then false
      when "i" then rest.to_i
      when "f" then rest.to_f
      when ":" then (text = unescape(rest)) =~ SYMBOL_PATTERN ? text.to_sym : nil
      when "s" then unescape(rest)
      when "@" then block_given? ? yield(rest) : nil
      when "x" then ActionKind.new(rest =~ SYMBOL_PATTERN ? rest.to_sym : nil)
      when "g" then base_item(value(rest[0, 1].to_s, rest[1..-1].to_s))
      when "k" then data($data_skills, rest)
      when "t" then data($data_items, rest)
      when "z" then data($data_states, rest)
      when "w" then data($data_weapons, rest)
      when "a" then data($data_armors, rest)
      when "c" then Color.new(*numbers(rest, 4))
      when "n" then Tone.new(*numbers(rest, 4))
      end
    end

    # Finds an entry of the database.
    #
    # @param table [Array] The database.
    # @param rest [String] The entry's id.
    # @return [RPG::BaseItem, nil] The entry, nil for an id the database lacks.
    def self.data(table, rest)
      id = rest.to_i
      id > 0 ? table[id] : nil
    end

    # Wraps a database entry the way the game keeps an equipped or stolen item.
    #
    # @param item [RPG::BaseItem, nil] The entry.
    # @return [Game_BaseItem, nil] The wrapped entry, nil without one.
    def self.base_item(item)
      return nil unless item

      wrapped = Game_BaseItem.new
      wrapped.object = item
      wrapped
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

  # The messages between the games during a live battle: a kind, the rest, and for a co-op battle
  # the sender's world seat. A PvP battle's go over the link, a kind on the first line; a co-op
  # battle's over the world's room, marked with the battle's id.
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
      if MGQ_MpBattleSync.world?
        MGQ_MpOverworldSync::Link.send_to(-1, "battle=#{kind}\nbid=#{MGQ_MpBattleSync.battle_id}\n\n#{body}")
      else
        MGQ_Multiplayer::Link.post("#{kind}\n#{body}")
      end
    end

    # Takes a message that arrived over the world's room: a guest takes only the host's, the host
    # only its guests'.
    #
    # @param seat [Integer] The sender's world seat.
    # @param kind [String] What it is.
    # @param body [String] The rest.
    def self.receive(seat, kind, body)
      return unless MGQ_MpBattleSync.seats.include?(seat)

      (@messages ||= []) << [kind, body, seat]
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

    # Takes the oldest message of any of some kinds, which keeps their order among each other.
    #
    # @param kinds [Array<String>] The kinds.
    # @return [Array<String>, nil] Its kind and body, nil while none arrived.
    def self.take_first(kinds)
      poll
      index = @messages.index { |message| kinds.include?(message[0]) }
      index ? @messages.delete_at(index)[0, 2] : nil
    end

    # Takes the oldest message of a kind one game sent.
    #
    # @param kind [String] The kind.
    # @param seat [Integer] The sender's world seat.
    # @return [String, nil] Its body, nil while none arrived.
    def self.take_from(kind, seat)
      poll
      index = @messages.index { |message| message[0] == kind && message[2] == seat }
      index ? @messages.delete_at(index)[1] : nil
    end

    # Reports whether the link to the friend has ended, asking every LINK_CHECK_FRAMES calls. In a
    # co-op battle, the host notes each guest who left and counts the link as ended once none is
    # left; a guest counts it as ended once the host is gone.
    #
    # @return [Boolean] Whether the link has ended.
    def self.gone?
      return true if @gone

      @checked = (@checked || 0) + 1
      return false if @checked < LINK_CHECK_FRAMES

      @checked = 0
      @gone = MGQ_MpBattleSync.world? ? world_gone? : MGQ_Multiplayer::Link.status["link"] != "open"
    end

    # Looks at who of a co-op battle is still in the world's room.
    #
    # @return [Boolean] Whether the other side is gone: every guest for the host, the host for a guest.
    def self.world_gone?
      return true unless MGQ_MpOverworldSync.in_world?

      MGQ_MpBattleSync.guests_in.each do |seat|
        MGQ_MpBattleSync.guest_left(seat) if MGQ_MpOverworldSync::Peers.at(seat).nil? || take_from("leave", seat)
      end
      MGQ_MpBattleSync.guests_in.empty?
    end

    # Reports why the friend's game will send nothing more for the battle, taking a forfeit or
    # break-off that arrived.
    #
    # @return [Symbol, nil] :forfeit when the friend forfeited, :broken when either game broke the
    #   battle off, :gone when the link ended, nil while the battle goes on.
    def self.ending
      return :forfeit if take("forfeit")

      MGQ_MpBattleSync.break_off("#{MGQ_MpBattleSync.player}'s game broke it off", false) if take("broken")
      return :broken if MGQ_MpBattleSync.broken?

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

    # Moves the messages that arrived over the link into the queue. A co-op battle's arrive through
    # receive.
    def self.poll
      @messages ||= []
      return if MGQ_MpBattleSync.world?

      while (text = MGQ_Multiplayer::Link.next_message)
        kind, body = text.split("\n", 2)
        @messages << [kind.to_s, body.to_s]
      end
    end
  end

  # The guest's commands: its characters' actions, which the host gives the rebuilt characters of
  # that guest. In a PvP battle the troop of one game is the party of the other in the same order;
  # in a co-op battle every game has the same party in the same order. Either way a target's index
  # means the same battler on both sides.
  module Commands
    # Writes the guest's commands: for every party member, its actions, none for the other
    # players' characters in a co-op battle.
    #
    # @return [String] The commands.
    def self.build
      commands = $game_party.battle_members.map do |actor|
        next [] if MGQ_MpBattleSync.coop? && actor.is_a?(Game_MpActor)

        actor.actions.select(&:item).map do |action|
          [action.item.is_a?(RPG::Item) ? "item" : "skill", action.item.id, action.target_index]
        end
      end
      Wire.line([commands])
    end

    # Gives a guest's characters on the host the guest's commands. A character without any keeps
    # what the computer chose.
    #
    # @param body [String] The commands.
    # @param seat [Integer, nil] The guest's world seat in a co-op battle, whose characters take them.
    def self.apply(body, seat = nil)
      values = Wire.parse(body.to_s)
      commands = values && values[0]
      return MGQ_MpBattleSync.log("unreadable commands") unless commands.is_a?(Array)

      battlers = MGQ_MpBattleSync.coop? ? $game_party.battle_members : $game_troop.members
      battlers.each_with_index do |battler, index|
        next if MGQ_MpBattleSync.coop? && !(battler.respond_to?(:mp_seat) && battler.mp_seat == seat)

        list = commands[index]
        next unless list.is_a?(Array)

        actions = list.map { |command| action(battler, command) }.compact
        battler.instance_variable_set(:@actions, actions) unless actions.empty?
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
    # A speaker's name box of the translation's message system, "\n<Name>".
    NAME_BOX = /\\n[1-5cr]?<[^>]*>/i

    # The untranslated game's speaker line, the name in brackets opening a message: "【Name】".
    NAME_LINE = /\A【[^】]*】/

    # Learns the names from the host's side.
    #
    # @param body [String] The host's party and troop names, see MGQ_MpBattleSync.names.
    def self.setup(body)
      values = Wire.parse(body.to_s) || []
      party, troop = values
      @swaps = {}
      # A co-op battle's party and troop stand on the same side on every game, with each
      # player's own characters named without their owner.
      own_party, own_troop = MGQ_MpBattleSync.coop? ? [$game_party.battle_members, $game_troop.members] : [$game_troop.members, $game_party.battle_members]
      Array(party).each_with_index { |name, index| add(name, own_party[index]) }
      Array(troop).each_with_index { |name, index| add(name, own_troop[index]) }
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

    # Swaps the names in a message, but not in its speaker's name box or speaker line, which name a
    # character without its owner on either side.
    #
    # @param text [String] The host's message line.
    # @return [String] The guest's message line.
    def self.swap_message(text)
      speaker = Regexp.union(NAME_BOX, NAME_LINE)
      text.split(/(#{speaker})/).map { |part| part =~ /\A#{speaker}\z/ ? part : swap(part) }.join
    end

    # Writes a translated host's name box as the untranslated game's speaker line when this game has
    # no name box, which would show the code as text.
    #
    # @param text [String] A message line.
    # @return [String] The line as this game shows it.
    def self.readable(text)
      return text if defined?(Window_NameMessage)

      text.sub(NAME_BOX) { |box| "【#{box[/<(.*)>/, 1]}】\n" }
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

    # Seeds a call's random choices are drawn from.
    SEED_RANGE = 1 << 30

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
      @command_phase = false
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

    # Records an event, unless a call that the guest makes itself is running.
    #
    # @param kind [String] What happened.
    # @param fields [Array] Its values, see Wire.line.
    def self.event(kind, *fields)
      return unless active? && !muted?

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
      return unless active? && !muted?

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

    # Records the start of a command phase once, with every battler's values, and sends it at once.
    # With none of its characters able to act, the host's game skips its own commands and waits for
    # the guest's within the same call, so the guest must hear of the phase before.
    def self.command_phase
      return unless active? && !@command_phase

      @command_phase = true
      values(true)
      event("commands")
      flush
    rescue => e
      stop_after(e)
    end

    # Ends the command phase, so the next one is recorded. Called as a turn starts.
    def self.turn_started
      @command_phase = false
    end

    # Records how long time stands still and for whom, when it changed. It decides who may act,
    # so the guest needs it to offer only the commands the host will take.
    def self.time_stop
      current = [$game_party.od_turn.to_i, $game_party.od_user]
      return if @time_stop == [current[0], current[1].object_id]

      @time_stop = [current[0], current[1].object_id]
      event("time_stop", *current)
    end

    # Records a call the guest makes itself with its own game's texts: the method and its
    # arguments, the action results it reads and the seed its random choices come from, such as
    # the line a character says. What the call does is left out of the recording, since the
    # guest's call does the same. A call with an argument that cannot travel is recorded as what
    # it does instead.
    #
    # @param receiver [String] "log" for the battle log, "scene" for the battle.
    # @param name [String] The method.
    # @param args [Array] Its arguments.
    # @param subject [Game_Battler, nil] Who acts, which a call of the battle reads.
    # @return [Object] What the block returns.
    def self.call(receiver, name, args, subject = nil)
      return yield unless active? && !muted? && Wire.encodable?(args)

      values
      seed = rand(SEED_RANGE)
      event("call", receiver, name.to_s, seed, subject, results_of(args), *args)
      seeded(seed) { muted { yield } }
    end

    # Records an event and leaves out what the block does, which the guest does its own way.
    #
    # @param kind [String] What happened.
    # @return [Object] What the block returns.
    def self.instead(kind)
      event(kind)
      muted { yield }
    end

    # Leaves out every event the block records.
    #
    # @return [Object] What the block returns.
    def self.muted
      @muted = (@muted || 0) + 1
      yield
    ensure
      @muted -= 1
    end

    # Tells whether events are left out.
    #
    # @return [Boolean] Whether a call the guest makes itself is running.
    def self.muted?
      (@muted || 0) > 0
    end

    # Runs a block with the random numbers following a seed, so the guest's call makes the same
    # random choices, then goes on with random numbers the seed does not predict.
    #
    # @param seed [Integer] The seed.
    # @return [Object] What the block returns.
    def self.seeded(seed)
      resume = rand(SEED_RANGE)
      srand(seed)
      yield
    ensure
      srand(resume)
    end

    # Lists the action results of the battlers among a call's arguments, which the battle log reads.
    #
    # @param args [Array] The arguments.
    # @return [Array<Array>] Each battler with its result.
    def self.results_of(args)
      battlers = args.flatten.select { |arg| arg.is_a?(Game_Battler) }.uniq
      battlers.map { |battler| [battler, battler.result] }.select { |_, result| result.is_a?(Game_ActionResult) }
    end

    # Records a sprite effect a battler starts, after the battlers' values, since the guest needs a
    # hit's HP and a defeat's death before it shows the effect.
    #
    # @param battler [Game_Battler] The battler.
    # @param effect [Symbol, nil] The effect, nil for none.
    def self.sprite_effect(battler, effect)
      return unless active? && !muted? && effect

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
      MGQ_MpBattleSync.log("recording stopped: #{error.class}: #{error.message}")
      MGQ_MpBattleSync.break_off("the host's recording stopped") if @sink == :link
    end
  end

  # The guest's side of a live battle: it plays what the host's battle showed instead of
  # computing its own; in a PvP battle with the host's party as its troop and the host's troop as
  # its party.
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
    # @return [Array, nil] The "end" event when the battle ended, an ending of Channel.ending or
    #   [:left] when it ended early, nil at the next command phase.
    def self.run(scene)
      @events ||= []
      quiet = 0
      # The party's status windows show during a turn, which the guest's own battle never has.
      scene.instance_variable_set(:@battle_actor_status_windows_show, true)
      window = nil
      held = Waiting.hold_input(scene)

      loop do
        event = next_event(scene)

        unless event
          ending = Channel.ending
          return [ending] if ending

          quiet += 1
          window ||= Waiting.open("Waiting for #{MGQ_MpBattleSync.player}...") if quiet == QUIET_FRAMES
          return [:left] if window && Waiting.leave?(window, quiet - QUIET_FRAMES)

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
      Waiting.release_input(held)
    end

    # Forgets events of an earlier battle.
    def self.reset
      @events = []
      @failed = {}
    end

    # Takes the next event of the host's stream, taking a co-op party's change on the way.
    #
    # @param scene [Scene_Battle] The battle.
    # @return [Array, nil] The next event of the host's stream, nil while none arrived.
    def self.next_event(scene)
      while @events.empty?
        kind, body = Channel.take_first(%w(coop_party events))
        return nil unless kind

        # A co-op party changes between two sends, so the next send's battlers are the new party's.
        if kind == "coop_party"
          MGQ_MpBattleCoop.reform(scene, body)
          next
        end

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

      # In a PvP battle the host's party is the guest's troop; a co-op battle's sides are the same.
      party = MGQ_MpBattleSync.coop? ? $1 == "a" : $1 == "e"
      party ? $game_party.battle_members[$2.to_i] : $game_troop.members[$2.to_i]
    end

    # Plays one event. An event that fails is left out and logged once per kind.
    #
    # @param scene [Scene_Battle] The battle.
    # @param event [Array] The event's kind and values.
    def self.play(scene, event)
      kind, *args = event
      method = kind.split(".", 2)[1]

      case kind
      when "call"
        call(scene, *args)
      when "emerge"
        emerge(scene)
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
      MGQ_MpBattleSync.log("could not play #{kind}: #{e.class}: #{e.message}") unless @failed[kind]
      @failed[kind] = true
    end

    # Makes a call the host recorded with this game's own texts, see Recorder.call: the battle log
    # or the battle writes the line in this game's language, with the host's action results and
    # random choices. Its waits are skipped while the guest catches up.
    #
    # @param scene [Scene_Battle] The battle.
    # @param receiver [String] "log" or "scene".
    # @param name [String] The method.
    # @param seed [Integer] The seed of the host's random choices.
    # @param subject [Game_Battler, nil] Who acts.
    # @param results [Array<Array>] Battlers with their action results.
    # @param args [Array] The method's arguments.
    def self.call(scene, receiver, name, seed, subject, results, *args)
      return unless callable?(receiver, name)

      Array(results).each do |battler, result|
        battler.instance_variable_set(:@result, result) if battler && result.is_a?(Game_ActionResult)
      end
      earlier = scene.instance_variable_get(:@subject)
      begin
        scene.instance_variable_set(:@subject, subject) if receiver == "scene"
        @in_call = true
        srand(seed.to_i)
        (receiver == "log" ? log_window(scene) : scene).send(name, *args)
      ensure
        @in_call = false
        srand
        scene.instance_variable_set(:@subject, earlier)
      end
    end

    # Tells whether a recorded call names a method the host may have the guest call.
    #
    # @param receiver [String] "log" or "scene".
    # @param name [String] The method.
    # @return [Boolean] Whether the guest makes the call.
    def self.callable?(receiver, name)
      case receiver
      when "log" then name =~ Hooks::LOG_CALL && Window_BattleLog.method_defined?(name) ? true : false
      when "scene" then Hooks::SCENE_CALLS.include?(name.to_s.to_sym)
      else false
      end
    end

    # Tells whether the guest skips a wait of a call it makes, since it fell behind the host's stream.
    #
    # @return [Boolean] Whether the wait is skipped.
    def self.skip_wait?
      @in_call && behind? ? true : false
    end

    # Says which of the host's characters appear, in this game's language, as the host's battle
    # did at its start.
    #
    # @param scene [Scene_Battle] The battle.
    def self.emerge(scene)
      $game_troop.enemy_names.each { |name| $game_message.add(format(Vocab::Emerge, name)) }
      @speaker = nil
      show_message
      scene.send(:wait_for_message)
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
      $game_message.add(Names.readable(Names.swap_message(text.to_s)))
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

  # The box that says what the game waits for, and offers to leave the battle when the wait drags on.
  module Waiting
    # Width of the box.
    WIDTH = 360

    # Height of the box, two lines.
    HEIGHT = 72

    # Frames a wait lasts before the box offers to leave the battle, ten seconds. Offered later, the
    # key that moved the last message on never leaves by chance.
    LEAVE_FRAMES = 600

    # What the box says once it offers to leave.
    LEAVE_TEXT = "Cancel leaves the battle."

    # Opens the box.
    #
    # @param text [String] What the game waits for.
    # @return [Window_Base] The box.
    def self.open(text)
      window = Window_Base.new((Graphics.width - WIDTH) / 2, 120, WIDTH, HEIGHT)
      window.z = 250
      window.contents.draw_text(0, 0, window.contents.width, window.line_height, text, 1)
      window
    end

    # Offers to leave the battle once the wait lasted LEAVE_FRAMES, and tells whether the player took it.
    #
    # @param window [Window_Base] The box.
    # @param frames [Integer] Frames the box has been open.
    # @return [Boolean] Whether the player leaves the battle.
    def self.leave?(window, frames)
      return false if frames < LEAVE_FRAMES

      if frames == LEAVE_FRAMES
        window.contents.draw_text(0, window.line_height, window.contents.width, window.line_height, LEAVE_TEXT, 1)
      end
      Input.trigger?(:B)
    end

    # Closes a box.
    #
    # @param window [Window_Base, nil] The box.
    def self.close(window)
      window.dispose if window && !window.disposed?
      nil
    end

    # Waits, with the box open, until the block has an answer, the battle ended early or the player
    # left it.
    #
    # @param scene [Scene_Battle] The battle.
    # @param text [String] What the game waits for.
    # @yieldreturn [String, nil] The answer, nil to wait on.
    # @return [String, Symbol] The answer, an ending of Channel.ending, or :left when the player left.
    def self.wait_for(scene, text)
      window = nil
      frames = 0
      held = hold_input(scene)
      loop do
        answer = yield
        return answer if answer

        ending = Channel.ending
        return ending if ending

        window ||= open(text)
        frames += 1
        return :left if leave?(window, frames)

        scene.send(:update_for_wait)
      end
    ensure
      close(window)
      release_input(held)
    end

    # Deactivates the battle's windows that take input for a wait, since the battle keeps updating
    # them while it waits.
    #
    # The game's auto battle activates the hidden party command right before the turn the host
    # waits in, where its presses started a second command phase.
    #
    # @param scene [Scene_Battle] The battle.
    # @return [Array<Window_Selectable>] The windows it deactivated.
    def self.hold_input(scene)
      windows = scene.instance_variables.map { |name| scene.instance_variable_get(name) }
      windows.select { |window| window.is_a?(Window_Selectable) && !window.disposed? && window.active }.each(&:deactivate)
    rescue => e
      MGQ_MpBattleSync.log("could not hold the battle's input: #{e.class}: #{e.message}")
      []
    end

    # Hands the windows a wait deactivated back as they were.
    #
    # @param windows [Array<Window_Selectable>, nil] The windows.
    def self.release_input(windows)
      Array(windows).each { |window| window.activate unless window.disposed? }
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

    # The battle log's methods that write a line of their own, which the guest calls itself.
    LOG_CALL = /\Adisplay_\w+\z/

    # The battle's methods the guest calls itself: the line a character says with a skill, with its
    # cut-in, and the skill's name at the top.
    SCENE_CALLS = [:process_skill_word, :display_skill_name]

    # The scene's waits a call the guest makes itself skips while the guest catches up.
    SKIPPABLE_WAITS = [:wait, :abs_wait]

    # Installs the hooks, a failing group alone left out. Calling it again does nothing.
    def self.install
      return if @installed
      @installed = true

      [:battle_log, :messages, :pictures, :audio, :battlers, :course, :live, :calls].each do |group|
        begin
          send(group)
        rescue => e
          MGQ_MpBattleSync.log("#{group} hooks FAILED: #{e.class}: #{e.message}")
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
        next original.call unless MGQ_MpBattleSync.live? && $game_party.in_battle

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
      wrap(Scene_Battle, :turn_start) do |_scene, _args, original|
        Recorder.turn_started
        Recorder.event("turn", $game_troop.turn_count + 1)
        original.call
      end

      # Recorded before the game checks the skip key, which leaves the animation out on this screen only.
      record_before(Scene_Battle, :show_animation) do |scene, args|
        ["animation", scene.instance_variable_get(:@subject), args[0], args[1]]
      end

      record_before(Scene_Battle, :turn_end) { |_scene, _args| ["turn_end"] }

      # The game also comes back here after a party change or a menu in the same phase, which
      # Recorder.command_phase records only once.
      wrap(Scene_Battle, :start_party_command_selection) do |scene, _args, original|
        unless scene.send(:scene_changing?)
          # A co-op party changes only here, before the command phase is recorded, so every game
          # takes the change between two of the host's sends.
          MGQ_MpBattleCoop.settle(scene) if MGQ_MpBattleSync.coop? && MGQ_MpBattleSync.host?
          Recorder.command_phase
        end
        original.call
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
        if MGQ_MpBattleSync.guest?
          Live.guest_start(scene)
        elsif MGQ_MpBattleSync.host? && !Live.host_start(scene)
          nil
        else
          Recorder.start(:file) if MGQ_MpBattleSync.take_file_recording
          Recorder.values
          original.call
        end
      end

      wrap(Scene_Battle, :turn_start) do |scene, _args, original|
        if MGQ_MpBattleSync.guest?
          Live.guest_turn(scene)
        elsif MGQ_MpBattleSync.host? && !MGQ_MpBattleSync.solo?
          original.call if Live.host_commands(scene)
        else
          original.call
        end
      end

      wrap(Scene_Battle, :update) do |scene, _args, original|
        result = original.call
        Live.watch(scene) if MGQ_MpBattleSync.live?
        result
      end

      wrap(Scene_Battle, :command_escape) do |scene, _args, original|
        if Live.escape_leaves?
          Live.forfeit(scene)
        else
          result = original.call
          Live.escaped(scene)
          result
        end
      end

      wrap(BattleManager.singleton_class, :judge_win_loss) do |_manager, _args, original|
        MGQ_MpBattleSync.guest? ? false : original.call
      end
    end

    # The calls whose lines each game writes in its own language: the host records them as calls,
    # the guest makes them itself. See Recorder.call.
    def self.calls
      Window_BattleLog.instance_methods(false).map(&:to_s).grep(LOG_CALL).each do |name|
        wrap(Window_BattleLog, name.to_sym) do |_log, args, original|
          Recorder.call("log", name, args) { original.call }
        end
      end

      SCENE_CALLS.select { |name| Scene_Battle.method_defined?(name) }.each do |name|
        wrap(Scene_Battle, name) do |scene, args, original|
          Recorder.call("scene", name, args, scene.instance_variable_get(:@subject)) { original.call }
        end
      end

      # Who appears is named with each game's own names, so the guest names the host's characters.
      wrap(BattleManager.singleton_class, :battle_start) do |_manager, _args, original|
        Recorder.instead("emerge") { original.call }
      end

      SKIPPABLE_WAITS.select { |name| Scene_Battle.method_defined?(name) }.each do |name|
        wrap(Scene_Battle, name) do |_scene, _args, original|
          original.call unless Playback.skip_wait?
        end
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
      original = :"mgq_mp_battle_sync_#{name.to_s.gsub(/[=?!]/, '_')}_#{@wraps}"
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
      if MGQ_MpBattleSync.coop?
        gathered = MGQ_MpBattleCoop.gather(scene)
        return end_early(scene, gathered) if gathered.is_a?(Symbol)
        # Nobody joined: the battle is the host's own.
        return true unless MGQ_MpBattleSync.host?
      end

      MGQ_MpBattleSync.show_everything
      Channel.post("ready", MGQ_MpBattleSync.names)
      ready = Waiting.wait_for(scene, "Waiting for #{MGQ_MpBattleSync.player}...") { all_ready? }
      return end_early(scene, ready) if ready.is_a?(Symbol)

      Recorder.start(:link)
      true
    end

    # Takes the guests' word that their battle is ready: the one guest's in a PvP battle, every
    # guest's still in a co-op battle.
    #
    # @return [Boolean, nil] true once every guest is ready, nil while one is not.
    def self.all_ready?
      return Channel.take("ready") ? true : nil unless MGQ_MpBattleSync.coop?

      @ready ||= []
      MGQ_MpBattleSync.guests_in.each { |seat| @ready << seat if !@ready.include?(seat) && Channel.take_from("ready", seat) }
      done = (MGQ_MpBattleSync.guests_in - @ready).empty?
      @ready = nil if done
      done ? true : nil
    end

    # The guest waits for the host's battle, then plays its start.
    #
    # @param scene [Scene_Battle] The battle.
    def self.guest_start(scene)
      Playback.reset
      # The game marks the party as fighting in on_battle_start, which the guest leaves out with the
      # rest of the battle's logic. Skills usable only in battle check it, and the end clears it.
      $game_party.instance_variable_set(:@in_battle, true)
      if MGQ_MpBattleSync.coop?
        joined = MGQ_MpBattleCoop.join(scene)
        return end_early(scene, joined) if joined.is_a?(Symbol)
      end

      Channel.post("ready", MGQ_MpBattleSync.names)
      names = Waiting.wait_for(scene, "Waiting for #{MGQ_MpBattleSync.player}...") { Channel.take("ready") }
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
      return guest_end(event[1], scene) if event

      # The guest's own battle never reaches the turn's end, and a command phase started in the
      # middle of one keeps the last turn's actions and skips every command.
      BattleManager.turn_end
      scene.start_party_command_selection
    end

    # Ends the guest's battle the way the host's ended, seen from the other side.
    #
    # @param result [String] How the host's battle ended.
    def self.guest_end(result, scene)
      return coop_end(result, scene) if MGQ_MpBattleSync.coop?

      case result
      when "process_victory" then BattleManager.process_defeat
      when "process_defeat" then BattleManager.process_victory
      else
        $game_message.add("#{MGQ_MpBattleSync.player} forfeited.")
        BattleManager.process_victory
      end
    end

    # Ends a co-op guest's battle as the host's ended: each game wins or loses with its own rewards
    # or defeat. When the host got away, the guest fights on alone.
    #
    # @param result [String] How the host's battle ended.
    # @param scene [Scene_Battle] The battle.
    def self.coop_end(result, scene)
      case result
      when "process_victory" then BattleManager.process_victory
      when "process_defeat" then BattleManager.process_defeat
      else MGQ_MpBattleCoop.take_over(scene)
      end
    end

    # The host waits for the guests' commands and gives them to their characters.
    #
    # @param scene [Scene_Battle] The battle.
    # @return [Boolean] Whether the turn goes on.
    def self.host_commands(scene)
      return host_coop_commands(scene) if MGQ_MpBattleSync.coop?

      commands = Waiting.wait_for(scene, "Waiting for #{MGQ_MpBattleSync.player}'s commands...") { Channel.take("commands") }
      return end_early(scene, commands) if commands.is_a?(Symbol)

      Commands.apply(commands)
      true
    end

    # The co-op host waits for the commands of every guest still in the battle. A guest who left
    # sends none, and the computer plays their characters.
    #
    # @param scene [Scene_Battle] The battle.
    # @return [Boolean] Whether the turn goes on.
    def self.host_coop_commands(scene)
      waiting = MGQ_MpBattleSync.guests_in
      answer = Waiting.wait_for(scene, "Waiting for the party's commands...") do
        waiting.dup.each do |seat|
          commands = Channel.take_from("commands", seat)
          next unless commands || !MGQ_MpBattleSync.guests_in.include?(seat)

          Commands.apply(commands, seat) if commands
          waiting.delete(seat)
        end
        waiting.empty? ? true : nil
      end
      return end_early(scene, answer) if answer.is_a?(Symbol)

      true
    end

    # Ends the battle when it ended early while this game is not waiting for the friend, such as
    # while its player chooses commands. Called by the battle's every frame.
    #
    # @param scene [Scene_Battle] The battle.
    def self.watch(scene)
      return if MGQ_MpBattleSync.solo? || scene.send(:scene_changing?) || BattleManager.battle_end?

      ending = Channel.ending
      end_early(scene, ending) if ending
    end

    # Ends the battle before its course did.
    #
    # @param scene [Scene_Battle] The battle.
    # @param reason [Symbol] :left when this player left, or an ending of Channel.ending.
    # @return [Boolean] true when the battle goes on with the computer, see MGQ_MpBattleSync.friend_gone.
    def self.end_early(scene, reason)
      case reason
      when :left
        forfeit(scene)
      when :forfeit
        $game_message.add("#{MGQ_MpBattleSync.player} forfeited.")
        BattleManager.process_victory
      when :broken
        $game_message.add("The live battle broke off.")
        BattleManager.process_abort
      else
        return MGQ_MpBattleSync.friend_gone(scene)
      end
      false
    end

    # Leaves a live battle at once: a PvP battle is lost, without the chance of failing; a co-op
    # player leaves the battle, which the others fight on.
    #
    # @param scene [Scene_Battle] The battle.
    def self.forfeit(scene)
      scene.instance_variable_get(:@info_viewport).visible = false
      Channel.post(MGQ_MpBattleSync.coop? ? "leave" : "forfeit")
      BattleManager.process_abort
    end

    # Reports whether Escape leaves the live battle at once: in a PvP battle. In a co-op battle each
    # player tries to escape as in any battle, and one who got away leaves it (see escaped).
    #
    # @return [Boolean] Whether it does.
    def self.escape_leaves?
      MGQ_MpBattleSync.live? && !MGQ_MpBattleSync.coop?
    end

    # Tells the host that a co-op guest got away, so the others fight on without them. The host's
    # getting away reaches the guests as its battle's end. Called after an escape.
    #
    # @param scene [Scene_Battle] The battle.
    def self.escaped(scene)
      Channel.post("leave") if MGQ_MpBattleSync.coop? && MGQ_MpBattleSync.guest? && scene.send(:scene_changing?)
    end
  end
end

# What this script takes part in of the world's messages, through mp_overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.route("battle") { |peer, message| MGQ_MpBattleSync.take(peer, message) }
rescue => e
  MGQ_MpBattleSync.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

if MGQ_MpBattleSync.hookable?
  begin
    class << SceneManager
      alias mgq_mp_battle_sync_run run

      # Installs the battle hooks, then runs the game.
      #
      # The game's plugins load after the Patch folder and define battle methods anew, so the hooks
      # go in once every plugin is in.
      def run
        MGQ_MpBattleSync::Hooks.install rescue nil
        mgq_mp_battle_sync_run
      end
    end
  rescue => e
    MGQ_MpBattleSync.log("SceneManager hook FAILED: #{e.class}: #{e.message}")
  end
end
