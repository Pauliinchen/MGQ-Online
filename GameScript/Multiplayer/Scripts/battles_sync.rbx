#----------------------------------------------------------------
#  battles_sync.rbx
#
#  Changelog:
#      Paulinchen  2026-10-07: Told the battle's mode on the host when a guest leaves, which stops a co-op guest's characters at once
#      Paulinchen  2026-10-06: Put the host's settings that leave parts of a battle unshown back once the live battle ends, which a co-op battle kept off
#                            - Sent a battle's messages to its players alone instead of the whole world
#                            - Stopped streaming once the computer plays on for the guests who left
#                            - Let a guest's empty commands take its characters' actions away, so a failed escape costs their turn
#                            - Took no more of a guest's commands than the host's game gave the character actions
#                            - Dropped the reader of the battle's kind, which the battle's mode had replaced
#      Paulinchen  2026-10-04: Renamed from mp_battles_sync.rbx
#      Paulinchen  2026-10-03: Named the characters outside the battle to the guest too, which a PvP battle with the Backline swaps in
#                            - Asked the running battle's mode instead of naming co-op battles and team duels
#                            - Read and wrote the game's private fields and called its private methods through MGQ_MpGame
#                            - Read the sides' players as MGQ_MpBattlesCoop::Player records
#                            - Moved the wire into battles_sync_wire.rbx, the recorder, the playback, and the hooks with the live battle's steps into scripts of their own
#                            - Built the battle hooks with MGQ_MpHooks.around
#                            - Called the scripts that load before this one without asking whether they loaded
#                            - Sent messages, showed notices and read the world, the own id and the own seat through MGQ_MpOverworldSync
#                            - Logged through MGQ_MpLog
#                            - Took from a guest only skills their character has and items a battle allows
#                            - Waited at a member's battle start for the party's leader to lead it
#                            - Streamed an animation once, played one a battler starts by itself, and kept actions and turn ends to the recording on file
#      Paulinchen  2026-10-02: Installed the battle hooks through core_hooks.rbx
#                            - Sent every message of a battle over the world's room through tell
#                            - Played back only the picture, screen and audio methods the hooks record
#                            - Ended a guest's co-op battle and a team duel on the host's side through one method
#                            - Started every wait for the guests with nobody ready, whatever an earlier wait left behind
#      Paulinchen  2026-10-01: Told every player of a live battle at once when another leaves it or the world
#                            - Carried a co-op guest's swaps with their commands, and told the party anew before the turn
#                            - Carried duels, PvP battles between two players of a world, over the world's room
#                            - Carried team duels, two parties with several players a side, whose players' commands each go to their own side
#      Paulinchen  2026-09-30: Registered with overworld_sync.rbx for its messages instead of being asked by overworld.rbx
#                            - Moved into Patch/Multiplayer/Scripts as battles_sync.rbx, which Multiplayer.rb loads
#                            - Renamed from mp_sync.rb, with the module MGQ_MpBattlesSync
#                            - Let a co-op player who got away leave the battle, which the others fight on
#                            - Held the battle's menus while waiting, so a hidden party command no longer takes presses after auto battle
#                            - Carried co-op battles over the world's room, several guests commanding their own characters in one party
#                            - Left turning Give Up off to battles.rbx, which does it for every multiplayer battle
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

# Live battles: the host's game computes the battle and streams what it shows, every guest's game
# plays that back and sends its own characters' commands. A PvP battle with a friend runs over the
# link; co-op battles, duels and team duels over the world's room, co-op battles and team duels with
# several guests.
#
# Each game sees its own team as the party, so the two would draw their random numbers in a
# different order if both computed.
module MGQ_MpBattlesSync
  # File inside the game folder's Logs folder that a recorded battle writes into.
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
  # battle, since the guest sees only what the host's battle shows; finish puts them back after it.
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

    # The world seats of the other games of a co-op battle: the guests for the host, the host for a guest.
    #
    # @return [Array<Integer>] The seats.
    attr_reader :seats

    # The co-op battle's id, which its messages carry.
    #
    # @return [String, nil] The id.
    attr_reader :battle_id
  end

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "battle sync"

  # Makes the next battle live, when the link to the friend stands. The mode calls battle_started
  # once that battle starts.
  #
  # @param state [Hash] How the connection stands, see MGQ_Multiplayer::Link.state.
  # @return [Boolean] Whether the battle is live, false for a battle of its own on each side.
  def self.join(state)
    return false unless state["link"] == "open" && %w(host guest).include?(state["role"])

    @role = state["role"].to_sym
    @player = MGQ_Multiplayer.clean(state["opponent"])
    @kind = :pvp
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

  # Makes the next battle a live battle over the world's room: a co-op battle, or a duel, which is
  # a PvP battle between two players of the world.
  #
  # @param role [Symbol] :host or :guest.
  # @param battle_id [String] The battle's id, which its messages carry.
  # @param seats [Array<Integer>] The other games' seats: the invited guests, or the host.
  # @param player [String] Who the waits name: the host's name, or "the party" for the host.
  # @param mode [Symbol] :coop, or :pvp for a duel.
  # @param team [Boolean] Whether the duel is a team duel, see battles_team.rbx.
  def self.join_world(role, battle_id, seats, player, mode = :coop, team = false)
    @role = role
    @player = player
    @kind = mode
    @team = team
    @transport = :world
    @seats = seats.dup
    @left = []
    @battle_id = battle_id
    @solo = false
    @broken = false
    @battle_running = false
    Channel.reset
    log("#{mode == :pvp ? 'duel' : 'co-op battle'} #{battle_id} as #{role}")
  end

  # Reports whether the live battle is a co-op battle.
  #
  # @return [Boolean] Whether it is.
  def self.coop?
    @role && @kind == :coop ? true : false
  end

  # Reports whether the live battle is a team duel, two parties fighting each other.
  #
  # @return [Boolean] Whether it is.
  def self.team?
    @role && @kind == :pvp && @team ? true : false
  end

  # Reports whether this game's party is the host's party: in a co-op battle, and on the host's
  # side of a team duel. Otherwise the host's party is this game's troop.
  #
  # @return [Boolean] Whether it is.
  def self.same_side?
    mode.same_side?
  end

  # What the running battle's kind does differently: a co-op battle's or a team duel's
  # MGQ_MpBattles::Mode, else a duel's.
  #
  # @return [MGQ_MpBattles::Mode] The mode.
  def self.mode
    MGQ_MpBattles.mode_of(coop? ? :coop : team? ? :team : :duel)
  end

  # Reports whether the host takes commands from several guests: in a co-op battle and a team duel.
  #
  # @return [Boolean] Whether it does.
  def self.several?
    coop? || team?
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

  # Notes that a guest left a co-op battle, and on the host tells the battle's mode, see
  # MGQ_MpBattles::Mode#left. In a co-op battle their characters do nothing more; the next command
  # phase takes them out of the party (see MGQ_MpBattlesCoop.settle).
  #
  # @param seat [Integer] The guest's seat.
  def self.guest_left(seat)
    return if (@left ||= []).include?(seat)

    @left << seat
    mode.left(seat) if host?
    log("a guest left the battle, their characters leave at the next command phase")
  end

  # Takes a message of a co-op battle or a duel from the world's room. Called by overworld_sync.rbx.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it.
  # @param message [Hash] The message: "battle" its kind, "bid" the battle's id, and the body.
  def self.take(peer, message)
    return unless peer && world? && @role && message["bid"] == @battle_id

    kind = message["battle"].to_s
    # Every player of the battle hears of one who leaves, not only the host who takes them out.
    Departures.left(peer) if kind == "leave"
    Channel.receive(peer.seat, kind, message[:payload].to_s)
  end

  # Lists the other players of a live battle over the world's room: the host or the guests, and in
  # a co-op battle or a team duel everyone else in it.
  #
  # @return [Array<Integer>] Their world seats.
  def self.player_seats
    seats = Array(@seats)
    seats |= mode.player_seats
    seats - [MGQ_MpOverworldSync::Me.seat]
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

  # Ends the live battle and closes the link, stops a recording and puts the host's settings back.
  # Called by the mode when it puts the game back, and after a reset.
  def self.finish
    Recorder.stop
    @record_next = false
    restore_settings
    return unless @role

    world = world?
    @role = nil
    @team = false
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
  # @param reason [String] What went wrong, for Multiplayer InGame.log.
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

  # Turns off the host's settings that would keep parts of the battle from the guest, keeping their
  # values for restore_settings.
  def self.show_everything
    @kept_settings ||= {}
    SKIP_SETTINGS.each do |key|
      next unless $game_system.conf.key?(key)

      @kept_settings[key] = $game_system.conf[key] unless @kept_settings.key?(key)
      $game_system.conf[key] = false
    end
  end

  # Puts back the settings show_everything turned off.
  def self.restore_settings
    kept = @kept_settings
    @kept_settings = nil
    Array(kept).each { |key, value| $game_system.conf[key] = value } if $game_system
  end

  # Lists the names the guest swaps.
  #
  # @return [String] The names of this game's party and troop, each with its characters outside the
  #   battle, which the guest swaps for its own.
  def self.names
    Wire.line([party_side.map(&:name), troop_side.map(&:name)])
  end

  # Lists the party's characters the stream names: those in the battle, then those outside it.
  #
  # @return [Array<Game_Battler>] The characters.
  def self.party_side
    $game_party.battle_members + mode.own_reserve
  end

  # Lists the troop's characters the stream names: those in the battle, then those outside it.
  #
  # @return [Array<Game_Battler>] The characters.
  def self.troop_side
    $game_troop.members + mode.other_reserve
  end

  # Sends a message of a battle over the world's room.
  #
  # @param seat [Integer] The game's seat, -1 for everyone.
  # @param kind [String] What it is.
  # @param battle_id [String] The battle's id.
  # @param body [String] The rest.
  # @return [Boolean] Whether it went out.
  def self.tell(seat, kind, battle_id, body = "")
    MGQ_MpOverworldSync.tell(seat, { "battle" => kind, "bid" => battle_id }, body)
  end

  # Ends the battle once the friend is gone: won, or played on by the computer on the host.
  #
  # @param scene [Scene_Battle] The battle.
  # @return [Boolean] true when the battle goes on with the computer.
  def self.friend_gone(scene)
    log("the link to #{@player} ended")

    # A co-op battle plays on on the host once every guest is gone, the host's own full team again
    # from the next command phase (see MGQ_MpBattlesCoop.settle); a guest whose host is gone fights on
    # alone.
    if host? && (DROPOUT == :computer || coop?)
      @solo = true
      Recorder.stop
      return true
    end

    return false if mode.take_over(scene)

    # A team duel's host wins once the other side is empty; a guest on the host's side loses its
    # host, who computes the duel, so the duel breaks off.
    if team? && (host? || same_side?)
      $game_message.add(host? ? "Everyone on the other side left." : "#{@player} left the duel.")
      host? ? BattleManager.process_victory : BattleManager.process_abort
      return false
    end

    $game_message.add("#{@player} left the battle.")
    BattleManager.process_victory
    false
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

    # Sends a message: over the world's room to each of the battle's other players, see
    # MGQ_MpBattlesSync.player_seats, else over the link.
    #
    # @param kind [String] What it is.
    # @param body [String] The rest.
    # @return [Boolean] Whether it went out to anyone.
    def self.post(kind, body = "")
      return MGQ_Multiplayer::Link.post("#{kind}\n#{body}") unless MGQ_MpBattlesSync.world?

      sent = false
      MGQ_MpBattlesSync.player_seats.each do |seat|
        sent = true if MGQ_MpBattlesSync.tell(seat, kind, MGQ_MpBattlesSync.battle_id, body)
      end
      sent
    end

    # Takes a message that arrived over the world's room: a guest takes only the host's, the host
    # only its guests'.
    #
    # @param seat [Integer] The sender's world seat.
    # @param kind [String] What it is.
    # @param body [String] The rest.
    def self.receive(seat, kind, body)
      return unless MGQ_MpBattlesSync.seats.include?(seat)

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
      @gone = MGQ_MpBattlesSync.world? ? world_gone? : MGQ_Multiplayer::Link.status["link"] != "open"
    end

    # Looks at who of a co-op battle or a duel is still in the world's room.
    #
    # @return [Boolean] Whether the other side is gone: every guest for the host, the host for a guest.
    def self.world_gone?
      return true unless MGQ_MpOverworldSync.in_world?

      MGQ_MpBattlesSync.guests_in.each do |seat|
        MGQ_MpBattlesSync.guest_left(seat) if MGQ_MpOverworldSync::Peers.at(seat).nil? || take_from("leave", seat)
      end
      return true if MGQ_MpBattlesSync.host? && MGQ_MpBattlesSync.mode.other_side_gone?

      MGQ_MpBattlesSync.guests_in.empty?
    end

    # Reports why the friend's game will send nothing more for the battle, taking a forfeit or
    # break-off that arrived.
    #
    # @return [Symbol, nil] :forfeit when the friend forfeited, :broken when either game broke the
    #   battle off, :gone when the link ended, nil while the battle goes on.
    def self.ending
      return :forfeit if take("forfeit")

      MGQ_MpBattlesSync.break_off("#{MGQ_MpBattlesSync.player}'s game broke it off", false) if take("broken")
      return :broken if MGQ_MpBattlesSync.broken?

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
      return if MGQ_MpBattlesSync.world?

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
    # Writes the guest's commands: for every party member, its actions, an empty list when it has
    # none, such as after a failed escape, and nil for the other players' characters in a co-op
    # battle; then the order of the guest's places, which a swap with their Backline changed.
    #
    # @return [String] The commands.
    def self.build
      commands = $game_party.battle_members.map do |actor|
        # Others' characters send nothing, but those this player took over from a player who left.
        next nil if actor.is_a?(Game_MpActor) && !actor.inputable?

        actor.actions.select(&:item).map do |action|
          [action.item.is_a?(RPG::Item) ? "item" : "skill", action.item.id, action.target_index]
        end
      end
      order = MGQ_MpBattlesSync.mode.own_order
      order ? Wire.line([commands, order]) : Wire.line([commands])
    end

    # Gives a guest's characters on the host the guest's commands, see command. A character the
    # guest named none for keeps what the computer chose. In a co-op battle the guest's swaps come
    # first, so the commands find the characters the guest sees.
    #
    # @param body [String] The commands.
    # @param seat [Integer, nil] The guest's world seat in a co-op battle, whose characters take them.
    def self.apply(body, seat = nil)
      values = Wire.parse(body.to_s)
      commands = values && values[0]
      return MGQ_MpBattlesSync.log("unreadable commands") unless commands.is_a?(Array)

      MGQ_MpBattlesSync.mode.take_order(seat, values[1])

      # The guest's party is the host's party in a co-op battle and on the host's side of a team
      # duel, else the host's troop, in the same order.
      same = MGQ_MpBattlesSync.mode.same_side_as_host?(seat)
      battlers = same ? $game_party.battle_members : $game_troop.members
      battlers.each_with_index do |battler, index|
        next if MGQ_MpBattlesSync.several? && !commanded_by?(battler, seat)

        list = commands[index]
        command(battler, list) if list.is_a?(Array)
      end
    end

    # Gives a character its owner's commands: an empty list takes its actions away, as its owner's
    # game did; of a list, as many as the host's game gave it actions, the computer's staying when
    # the character may give none of them.
    #
    # The host rolls a character's extra actions, so the owner's game never decides how often it acts.
    #
    # @param battler [Game_Battler] The character.
    # @param list [Array<Array>] Its commands, see action.
    def self.command(battler, list)
      return MGQ_MpGame.set(battler, :actions, []) if list.empty?

      actions = list.first(action_count(battler)).map { |command| action(battler, command) }.compact
      MGQ_MpGame.set(battler, :actions, actions) unless actions.empty?
    end

    # Counts the actions the host's game gives a character this turn, making them first for one that
    # has none yet, such as one a swap just brought into the battle.
    #
    # @param battler [Game_Battler] The character.
    # @return [Integer] How many actions it takes.
    def self.action_count(battler)
      battler.make_actions if Array(MGQ_MpGame.get(battler, :actions)).empty?
      Array(MGQ_MpGame.get(battler, :actions)).size
    end

    # Reports whether a guest commands a character: their own, or in a team duel one of a player
    # who left, which they took over.
    #
    # @param battler [Game_Battler] The character.
    # @param seat [Integer] The guest's world seat.
    # @return [Boolean] Whether they do.
    def self.commanded_by?(battler, seat)
      return false unless battler.respond_to?(:mp_seat)

      heir = MGQ_MpBattlesSync.mode.heir_of(battler.mp_seat)
      battler.mp_seat == seat || (!heir.nil? && heir == seat)
    end

    # Turns a friend's command into an action.
    #
    # @param battler [Game_Battler] The character.
    # @param command [Array] "skill" or "item", the id and the target's index.
    # @return [Game_Action, nil] The action, nil for a command it cannot read or the character may not give.
    def self.action(battler, command)
      kind, id, target = command
      return nil unless command.is_a?(Array) && id.is_a?(Integer) && id > 0 && target.is_a?(Integer)

      item = { "skill" => $data_skills, "item" => $data_items }.fetch(kind, [])[id]
      return nil unless item
      return refuse(battler, item) unless allowed?(battler, item)

      action = Game_Action.new(battler)
      action.set_symbol(:count) if action.respond_to?(:set_symbol)
      item.is_a?(RPG::Item) ? action.set_item(id) : action.set_skill(id)
      action.target_index = target
      action
    end

    # Reports whether a character may be commanded to use a skill or an item: a skill it has, or
    # one of no skill type, as attacking, guarding and struggling are, and an item a battle allows.
    #
    # The owner's bag is not known here, so their own game uses an item up as the host's stream
    # tells it, see Playback.use_up.
    #
    # @param battler [Game_Battler] The character.
    # @param item [RPG::UsableItem] The skill or item.
    # @return [Boolean] Whether it may.
    def self.allowed?(battler, item)
      return item.battle_ok? if item.is_a?(RPG::Item)

      item.stype_id == 0 || [battler.attack_skill_id, battler.guard_skill_id].include?(item.id) ||
        (battler.respond_to?(:skills) && battler.skills.include?(item))
    end

    # Leaves out a command the character may not give, and logs it.
    #
    # @param battler [Game_Battler] The character.
    # @param item [RPG::UsableItem] The skill or item.
    # @return [nil] Nothing.
    def self.refuse(battler, item)
      MGQ_MpBattlesSync.log("left out #{item.class.name.split('::').last.downcase} #{item.id} for #{battler.name}, who may not use it")
      nil
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
    # @param body [String] The host's party and troop names, see MGQ_MpBattlesSync.names.
    def self.setup(body)
      values = Wire.parse(body.to_s) || []
      party, troop = values
      @swaps = {}
      # A co-op battle's party and troop stand on the same side on every game, with each
      # player's own characters named without their owner.
      sides = [MGQ_MpBattlesSync.party_side, MGQ_MpBattlesSync.troop_side]
      own_party, own_troop = MGQ_MpBattlesSync.same_side? ? sides : sides.reverse
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

  # Tells the player at once when another player leaves the live battle, in the chat log, which
  # shows in battle, and in the world's status line: the battle itself takes them out only at its
  # next command phase.
  module Departures
    # Battles and seats already told, at most this many kept.
    KEPT = 32

    @told = []

    # Tells that a player left the battle, as their "leave" says.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
    def self.left(peer)
      tell(peer, "#{peer.state['name']} left the battle.")
    end

    # Tells that a player of the battle left the world. Called by overworld_sync.rbx.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
    def self.gone(peer)
      return unless MGQ_MpBattlesSync.role && MGQ_MpBattlesSync.world? && MGQ_MpBattlesSync.player_seats.include?(peer.seat)

      tell(peer, "#{peer.state['name']} left the world, and the battle.")
    end

    # Tells of a player leaving, once per battle.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
    # @param text [String] What the player sees.
    def self.tell(peer, text)
      key = [MGQ_MpBattlesSync.battle_id, peer.seat]
      return if @told.include?(key)

      @told.push(key)
      @told.shift while @told.size > KEPT
      MGQ_MpChat.system(text)
      MGQ_MpOverworldSync.notice(text)
    rescue => e
      MGQ_MpBattlesSync.log("telling of a departure failed: #{e.class}: #{e.message}")
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

        MGQ_MpGame.call(scene, :update_for_wait)
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
      MGQ_MpBattlesSync.log("could not hold the battle's input: #{e.class}: #{e.message}")
      []
    end

    # Hands the windows a wait deactivated back as they were.
    #
    # @param windows [Array<Window_Selectable>, nil] The windows.
    def self.release_input(windows)
      Array(windows).each { |window| window.activate unless window.disposed? }
    end
  end

end

# What this script takes part in of the world's messages, through overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.route("battle") { |peer, message| MGQ_MpBattlesSync.take(peer, message) }
  MGQ_MpOverworldSync.on_leave { |peer| MGQ_MpBattlesSync::Departures.gone(peer) }
rescue => e
  MGQ_MpBattlesSync.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

# Game hooks, through core_hooks.rbx.

begin
  # Installs the battle hooks as the game starts running. The game's plugins load after the Patch
  # folder and define battle methods anew, so the hooks go in once every plugin is in.
  MGQ_MpHooks.before(SceneManager.singleton_class, :run, "battles_sync") { MGQ_MpBattlesSync::Hooks.install }
rescue => e
  MGQ_MpBattlesSync.log("SceneManager hook FAILED: #{e.class}: #{e.message}")
end
