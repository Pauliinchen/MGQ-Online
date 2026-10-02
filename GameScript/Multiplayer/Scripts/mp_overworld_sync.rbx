#----------------------------------------------------------------
#  mp_overworld_sync.rbx
#
#  Changelog:
#      Paulinchen  2026-10-02: Told Discord the open world's name, its players and its seats through the Discord mod
#                            - Followed Graphics.update through mp_hooks.rbx
#                            - Marked the player's state, which tells it apart from the scripts' messages
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# The open world's messages: each game tells the others where its player stands, how they look and
# whether they are on the map, in a battle, a menu or an event, takes what the others told, and
# hands every other message to the script that registered for the field that marks it. What the
# player sees of it is mp_overworld.rbx's.
#
# Scripts that load after this one take part through its registry: route for their messages,
# state_fields and busy_scene for the player's state, on_tick, on_observe and on_leave to follow
# the others, and label_line for the line above a ghost's name.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpOverworldSync
  # What a player does on a screen of the game, by the screen's class name; any other screen is a menu.
  SCREENS = {
    /\AScene_(Item|Storehouse)\z/ => "items",
    /\AScene_(Equip|EquipStone\w*|Smith|Synthesize)\z/ => "equip",
    /\AScene_Shop\z/ => "shop",
    /\AScene_(Poker|Slot|CasinoPrize)\z/ => "casino",
    /Library/ => "library",
  }

  # Frames a notice stays at the bottom left, four seconds at 60 frames per second.
  NOTICE_FRAMES = 240

  # Frames between two looks at the connection.
  STATUS_FRAMES = 30

  # Bytes the DLL may write an inbox entry into at first.
  ENTRY_SIZE = 4096

  # Milliseconds a ping must differ from the one the others know before they are told again.
  PING_STEP = 20

  # Share of the ping the others know that a new ping must differ by, too, before they are told again.
  PING_SHARE = 0.25

  # The field that marks a message as a player's state, which no route may be named like.
  STATE_FIELD = "state"

  @routes = {}
  @handlers = Hash.new { |handlers, kind| handlers[kind] = [] }
  @failed = {}

  # Writes a line to the mod's InGame.log.
  #
  # @param message [String] The line.
  def self.log(message)
    MGQ_Multiplayer::Log.write("overworld sync: #{message}")
  rescue
  end

  # Reports whether a world is open.
  #
  # @return [Boolean] Whether mp_world.rbx has a world open.
  def self.in_world?
    defined?(MGQ_MpWorld) && MGQ_MpWorld.open? ? true : false
  end

  # The fields the Discord mod publishes about the open world, which Discord shows as its name and
  # its players, such as "(3 of 8)".
  #
  # @return [Hash] The world's name, id, players and seats, none outside a world.
  def self.status_fields
    world = in_world? ? MGQ_MpWorld.world : nil
    return {} unless world

    { "mp_world" => world.name, "mp_world_id" => world.id, "mp_world_size" => Peers.all.size + 1, "mp_world_max" => world.seats }
  end

  # Hands every message marked by a field to a script. The first field registered wins when a
  # message carries several.
  #
  # @param field [String] The field, such as "chat".
  # @yieldparam peer [Peers::Peer, nil] Who sent it, nil before their first state.
  # @yieldparam message [Hash] The message's fields, and its body under :payload.
  def self.route(field, &handler)
    @routes[field] = handler
  end

  # Lets a script follow the frames. Called every frame in every scene.
  #
  # @yieldparam in_world [Boolean] Whether a world is open.
  def self.on_tick(&block)
    @handlers[:tick] << block
  end

  # Adds a script's fields to the state the player's game tells the others.
  #
  # @yieldreturn [Hash] The fields.
  def self.state_fields(&block)
    @handlers[:state_fields] << block
  end

  # Lets a script tell that it has the player busy, such as typing in the chat.
  #
  # @yieldreturn [String, nil] A key of MGQ_MpOverworld::STATE_ICONS, nil when it has not.
  def self.busy_scene(&block)
    @handlers[:busy_scene] << block
  end

  # Tells a script what another player just told.
  #
  # @yieldparam peer [Peers::Peer] The player, with what they just told.
  def self.on_observe(&block)
    @handlers[:observe] << block
  end

  # Tells a script that another player left the world.
  #
  # @yieldparam peer [Peers::Peer] The player.
  def self.on_leave(&block)
    @handlers[:leave] << block
  end

  # Lets a script give the line above a ghost's name, such as an invite.
  #
  # @yieldparam peer [Peers::Peer] The ghost's player.
  # @yieldreturn [Array, nil] The text and its color, nil for none.
  def self.label_line(&block)
    @handlers[:label_line] << block
  end

  # Asks the scripts for the line above a ghost's name. Called by mp_overworld.rbx.
  #
  # @param peer [Peers::Peer] The ghost's player.
  # @return [Array, nil] The first script's text and color, nil for none.
  def self.label_line_of(peer)
    ask(:label_line, peer).compact.first
  end

  # Calls every block registered for a kind, logging a failing one once.
  #
  # @param kind [Symbol] The kind, see @handlers.
  # @param args [Array] What the blocks get.
  # @return [Array] What each block returned, nil for one that failed.
  def self.ask(kind, *args)
    @handlers[kind].map do |block|
      begin
        block.call(*args)
      rescue => e
        log("#{kind} of #{block.source_location.to_a.first} failed: #{e.class}: #{e.message}") unless @failed[block]
        @failed[block] = true
        nil
      end
    end
  end

  # Takes what the others sent and tells them what changed here. Called every frame in every scene.
  def self.tick
    unless in_world?
      Peers.clear unless Peers.empty?
      ask(:tick, false)
      return
    end

    Inbox.take_all
    ask(:tick, true)
    Me.tell_changes
    Status.look
  rescue => e
    log("tick failed: #{e.class}: #{e.message}") unless @tick_failed
    @tick_failed = true
  end

  # Hands a message to the script registered for its field.
  #
  # @param peer [Peers::Peer, nil] Who sent it, nil before their first state.
  # @param message [Hash] The message's fields.
  # @return [Boolean] Whether a script took it.
  def self.hand_over(peer, message)
    field, handler = @routes.find { |key, _| message[key] }
    return false unless field

    handler.call(peer, message)
    true
  rescue => e
    log("#{field} message failed: #{e.class}: #{e.message}")
    true
  end

  # Patch/Multiplayer/Multiplayer.dll's world room: the inbox and sending.
  module Link
    # Hands out the oldest inbox entry.
    #
    # @return [Hash, nil] "kind" ("seat", "in", "out" or "message"), "seat", "others", and the
    #   message's text under :payload; nil while none waits.
    def self.next_entry
      text = MGQ_Multiplayer::Link.read('mp_world_receive', ENTRY_SIZE)
      text.empty? ? nil : MGQ_Multiplayer::Link.parse(text)
    end

    # Sends a message to one seat or to every other game.
    #
    # @param target [Integer] The seat, -1 for everyone.
    # @param text [String] The message.
    # @return [Boolean] Whether it went out.
    def self.send_to(target, text)
      MGQ_Multiplayer::Link.function('mp_world_send', 'lp').call(target, text + "\0") == 1
    end

    # Reads how the connection stands.
    #
    # @return [Hash] "state" ("idle", "connecting", "open", "reconnecting" or "failed"), "seat", "others" and "error".
    def self.status
      text = MGQ_Multiplayer::Link.read('mp_world_status', 1024)
      text.empty? ? { "state" => "idle" } : MGQ_Multiplayer::Link.parse(text)
    end
  end

  # What this game tells the others about its player.
  module Me
    # Tells every other game what changed, if anything did.
    def self.tell_changes
      state = current
      return if state.nil? || state == @told

      @told = state if Link.send_to(-1, encode(state))
    end

    # Tells one game everything, as a newcomer needs.
    #
    # @param seat [Integer] The newcomer's seat, -1 for everyone, which also reads the player's
    #   id and name again, since a new connection may follow a new name.
    def self.tell_all(seat)
      @identity = nil if seat < 0
      state = current
      Link.send_to(seat, encode(state)) if state
      @told = state if seat < 0
    end

    # Reads what the others need to know about the player.
    #
    # @return [Hash, nil] The player's state, nil before the map exists.
    def self.current
      return nil unless $game_player && $game_map && $game_map.map_id > 0

      looks = $game_player.vehicle || $game_player
      state = {
        STATE_FIELD => 1,
        "id" => identity[0],
        "name" => identity[1],
        "sprite" => looks.character_name.to_s,
        "index" => looks.character_index,
        "map" => $game_map.map_id,
        "since" => map_since,
        "x" => $game_player.x,
        "y" => $game_player.y,
        "d" => $game_player.direction,
        "speed" => $game_player.real_move_speed,
        "hidden" => $game_player.transparent ? 1 : 0,
        "scene" => scene,
        "ping" => Ping.told,
      }
      MGQ_MpOverworldSync.ask(:state_fields).compact.each { |fields| state.merge!(fields) }
      state
    end

    # The player's id and name, read once per connection, since the state is compared every frame.
    #
    # @return [Array<String>] The id and the name.
    def self.identity
      @identity ||= [MGQ_Multiplayer::Link.player_id, MGQ_Multiplayer::Player.name.to_s]
    end

    # Tells when the player entered the map they are on, which decides who of a party on a map is
    # its Map Owner.
    #
    # @return [Integer] Milliseconds since 1970 by this computer's clock.
    def self.map_since
      if @since_map != $game_map.map_id
        @since_map = $game_map.map_id
        @since = (Time.now.to_f * 1000).to_i
      end
      @since
    end

    # Tells what the player does: walk the map, travel by boat or airship, fight, watch an event,
    # sit in a menu or one of its screens, or have the game in the background.
    #
    # @return [String] A key of MGQ_MpOverworld::STATE_ICONS, or "map" for walking the map.
    def self.scene
      current = SceneManager.scene
      name = current.class.name.to_s
      return "battle" if current.is_a?(Scene_Battle)
      return "event" if name =~ /Novel/ || (current.is_a?(Scene_Map) && ($game_message.busy? || $game_map.interpreter.running?))
      return "away" unless MGQ_Multiplayer::Background.in_front?

      busy = MGQ_MpOverworldSync.ask(:busy_scene).compact.first
      return busy if busy
      return SCREENS.find { |pattern, _| name =~ pattern }.to_a[1] || "menu" unless current.is_a?(Scene_Map)

      return "flying" if $game_player.in_airship?

      $game_player.in_boat? || $game_player.in_ship? ? "sailing" : "map"
    end

    # Writes a state as a message.
    #
    # @param state [Hash] The state.
    # @return [String] The message: key=value lines.
    def self.encode(state)
      state.map { |key, value| "#{key}=#{value.to_s.gsub(/[\r\n]/, ' ')}" }.join("\n") + "\n\n"
    end
  end

  # The other games of the world, by seat, as their last messages said.
  module Peers
    # Another player: their seat, what they last told, and their ghost while on this map.
    #
    # @!attribute seat [Integer] Their game's seat.
    # @!attribute state [Hash] What they last told: "name", "sprite", "index", "map", "x", "y", "d", "speed", "hidden", "scene".
    # @!attribute ghost [Game_MpGhost, nil] Their ghost, while they are on this map.
    # @!attribute member [Boolean] Whether they were in the player's party at their last message.
    Peer = Struct.new(:seat, :state, :ghost, :member)

    @peers = {}

    # Takes what a game told.
    #
    # @param seat [Integer] The game's seat.
    # @param state [Hash] What it told.
    def self.take(seat, state)
      peer = @peers[seat]

      if peer
        peer.state = state
      else
        peer = @peers[seat] = Peer.new(seat, state, nil, false)
        Status.notice("#{state['name']} joined the world.")
      end

      MGQ_MpOverworldSync.ask(:observe, peer)
    end

    # Finds a game by its seat.
    #
    # @param seat [Integer] The seat.
    # @return [Peer, nil] The game, nil before its first state.
    def self.at(seat)
      @peers[seat]
    end

    # Forgets a game that left.
    #
    # @param seat [Integer] Its seat.
    def self.remove(seat)
      peer = @peers.delete(seat)
      return unless peer

      Status.notice("#{peer.state['name']} left the world.")
      MGQ_MpOverworldSync.ask(:leave, peer)
    end

    # Forgets every game, as after a reconnect or once the world closed.
    def self.clear
      @peers.clear
    end

    # Reports whether no other game is known.
    #
    # @return [Boolean] Whether none is.
    def self.empty?
      @peers.empty?
    end

    # Lists the other games.
    #
    # @return [Array<Peer>] The games.
    def self.all
      @peers.values
    end
  end

  # Reads the world room's inbox.
  module Inbox
    # Most entries read per frame, so a flood never stalls a frame.
    MAX_PER_FRAME = 64

    # Takes every waiting entry.
    def self.take_all
      MAX_PER_FRAME.times do
        entry = Link.next_entry
        break unless entry

        take(entry)
      end
    end

    # Takes one entry.
    #
    # @param entry [Hash] The entry, see Link.next_entry.
    def self.take(entry)
      seat = entry["seat"].to_i

      case entry["kind"]
      when "seat"
        # A new connection: every other game is told everything, and tells everything back.
        Peers.clear
        Me.tell_all(-1)
      when "in"
        Me.tell_all(seat)
      when "out"
        Peers.remove(seat)
      when "message"
        message = MGQ_Multiplayer::Link.parse(entry[:payload].dup)
        # A state may carry a field named like a route, and a script's message may name a map, so
        # only STATE_FIELD tells them apart.
        if message[STATE_FIELD]
          message.delete(:payload)
          Peers.take(seat, message)
        else
          MGQ_MpOverworldSync.hand_over(Peers.at(seat), message)
        end
      end
    end
  end

  # What the line at the bottom left of the map shows: who came and went, and when the connection
  # is down.
  module Status
    @frames = 0
    @notices = []

    # Adds a notice, shown for a few seconds.
    #
    # @param text [String] The notice.
    def self.notice(text)
      @notices.push([text, NOTICE_FRAMES])
      @notices.shift while @notices.size > 3
    end

    # Looks at the connection every STATUS_FRAMES, and lets notices run out.
    def self.look
      @notices.each { |notice| notice[1] -= 1 }
      @notices.reject! { |_, left| left <= 0 }
      @frames += 1
      return if @frames < STATUS_FRAMES

      @frames = 0
      state = Link.status
      Ping.take(state["ping"])
      @problem =
        case state["state"]
        when "reconnecting" then "Reconnecting . . ."
        when "connecting" then state["error"] || "Connecting . . ."
        when "failed" then "Not connected: #{state['error']}"
        end
    end

    # Tells what the line shows now.
    #
    # @return [Array<String>] The lines, the connection's problem first.
    def self.lines
      ([@problem] + @notices.map { |text, _| text }).compact
    end
  end

  # The player's ping: the round trip to the relay, which the DLL times every few seconds. The
  # player sees each new one; the others are told only once it moved noticeably, since every
  # message counts against the relay's free plan.
  module Ping
    @measured = nil
    @told = ""

    # Takes the ping the connection's status tells.
    #
    # @param text [String, nil] The milliseconds, nil or empty while there is no connection.
    def self.take(text)
      @measured = text.to_s.empty? ? nil : text.to_i
      return if @measured.nil?

      told = @told.empty? ? nil : @told.to_i
      @told = @measured.to_s if told.nil? || (@measured - told).abs >= [PING_STEP, told * PING_SHARE].max
    end

    # The last ping measured.
    #
    # @return [Integer, nil] The milliseconds, nil while there is no connection.
    def self.measured
      @measured
    end

    # The ping the others are told.
    #
    # @return [String] The milliseconds, empty before the first.
    def self.told
      @told
    end
  end
end

# Game hooks, through mp_hooks.rbx.

begin
  # After every frame, takes the others' messages and tells them what changed here. Graphics.update
  # runs every frame in every scene, so the others hear of a battle or a menu and nothing piles up
  # meanwhile.
  MGQ_MpHooks.after(Graphics.singleton_class, :update, "mp_overworld_sync") { MGQ_MpOverworldSync.tick }
rescue => e
  MGQ_MpOverworldSync.log("Graphics hook FAILED: #{e.class}: #{e.message}")
end

# Discord shows the world and its players, through the Discord mod's bridge when it is installed.
begin
  MGQ_Discord::Bridge.add_status { |_scene| MGQ_MpOverworldSync.status_fields } if MGQ_Multiplayer::Discord.available?
rescue => e
  MGQ_MpOverworldSync.log("status source FAILED: #{e.class}: #{e.message}")
end
