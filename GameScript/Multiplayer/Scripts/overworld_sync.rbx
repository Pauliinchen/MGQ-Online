#----------------------------------------------------------------
#  overworld_sync.rbx
#
#  Changelog:
#      Paulinchen  2026-10-08: Marked an admin's line from the relay with a key no player's message can carry, which let any player post as an admin
#                            - Passed on whether the relay got a chat line or the DLL dropped it for coming too fast, instead of whether it went out
#                            - Listed the players whose connection stands, found them by name and id and told whether one is on the player's map, which the chat and the map share
#                            - Numbered a name that several players share, such as "Name (2)", so each is found by it, and found nobody by a missing name or id
#      Paulinchen  2026-10-07: Mirrored a chat line to the relay through say, and handed an admin's line from the relay to the chat's route
#                            - Kept the player's seat as the inbox and the status tell it, asking the DLL only while none was told
#                            - Logged a failing route once
#                            - Named the DLL's exports alone, their signatures living in Multiplayer.rb
#                            - Logged players joining, leaving, going away, coming back and moving seats, their changes of map and screen, the player's own, every change of the connection's status with how it closed, the notices and dropped messages
#      Paulinchen  2026-10-06: Moved a player who tells from a new seat while their old one still stands, without telling anyone they left
#                            - Dropped Status.lines, which only the tests read
#                            - Handed the Discord mod the world code, which its invites into the world carry
#      Paulinchen  2026-10-04: Took an icon with a notice
#                            - Renamed from mp_overworld_sync.rbx
#      Paulinchen  2026-10-03: Added map_quiet? and map_free?, which the scripts check before they act on the map
#                            - Added tell, notice, Me.id and Me.seat, which every script sends, notifies and names the player with
#                            - Logged through MGQ_MpLog
#                            - Kept a player whose connection dropped for fifteen seconds, and every player across the game's own reconnect, so a party and a battle outlast it
#      Paulinchen  2026-10-02: Told Discord the open world's name, its players and its seats through the Discord mod
#                            - Followed Graphics.update through core_hooks.rbx
#                            - Marked the player's state, which tells it apart from the scripts' messages
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# The open world's messages: each game tells the others where its player stands, how they look and
# whether they are on the map, in a battle, a menu or an event, takes what the others told, and
# hands every other message to the script that registered for the field that marks it. What the
# player sees of it is overworld.rbx's.
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

  # Frames a player whose connection dropped is kept, fifteen seconds, since the relay ends every
  # connection after a while and the games connect again at once.
  REJOIN_FRAMES = 900

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

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "overworld sync"

  # Fields of a player's state whose changes the log follows; the others, such as where they
  # stand, change with every step.
  LOGGED_FIELDS = %w[name map scene hidden party]

  # Names a player for the log: their name and seat.
  #
  # @param peer [Peers::Peer, Symbol, nil] The player, :me for the player, nil for none.
  # @return [String] The name; never raises.
  def self.who(peer)
    return "the player" if peer == :me
    return "an unknown player" unless peer

    "#{peer.state['name']} (seat #{peer.seat})"
  rescue
    "?"
  end

  # Writes what changed between two states of a player, for the log.
  #
  # @param before [Hash, nil] The earlier state.
  # @param after [Hash] The later state.
  # @return [String] Each changed field of LOGGED_FIELDS as "map 5 -> 7", empty when none changed.
  def self.changes(before, after)
    return "" unless before

    LOGGED_FIELDS.reject { |field| before[field].to_s == after[field].to_s }.map do |field|
      "#{field} #{before[field].to_s.empty? ? '-' : before[field]} -> #{after[field].to_s.empty? ? '-' : after[field]}"
    end.join(", ")
  rescue
    ""
  end

  # Reports whether a world is open.
  #
  # @return [Boolean] Whether world.rbx has a world open.
  def self.in_world?
    defined?(MGQ_MpWorld) && MGQ_MpWorld.open? ? true : false
  end

  # Reports whether the map is quiet: no event runs and no message shows.
  #
  # @return [Boolean] Whether it is.
  def self.map_quiet?
    !$game_map.interpreter.running? && !$game_message.busy?
  end

  # Reports whether the player is free on the map: the map is the scene and quiet, and no transfer
  # is on its way.
  #
  # @return [Boolean] Whether they are.
  def self.map_free?
    SceneManager.scene.is_a?(Scene_Map) && map_quiet? && !$game_player.transfer?
  end

  # Shows a notice at the bottom left of the map for a few seconds.
  #
  # @param text [String] The notice.
  # @param icon [Integer, nil] An icon of the game's iconset before it, such as an item's.
  def self.notice(text, icon = nil)
    Status.notice(text, icon)
  end

  # Sends a message to one seat or to every other game.
  #
  # @param seat [Integer] The seat, -1 for everyone.
  # @param fields [Hash] The message's fields, the first of which marks it for its route.
  # @param body [String] What follows the fields, such as a team.
  # @return [Boolean] Whether it went out.
  def self.tell(seat, fields, body = "")
    Link.send_to(seat, Me.encode(fields) + body)
  end

  # Mirrors a line of the world's chat to the relay, which keeps the last lines of every world for
  # its admins and passes it to nobody; the line itself goes to the others through tell.
  #
  # @param text [String] The line.
  # @return [Integer] 1 when the relay got it, 0 when it did not, 2 when the DLL dropped it for
  #   coming too fast.
  def self.say(text)
    Link.say(text)
  end

  # The fields the Discord mod publishes about the open world, which Discord shows as its name and
  # its players, such as "(3 of 8)", and whose code its invites carry.
  #
  # @return [Hash] The world's name, id, players, seats and code, none outside a world.
  def self.status_fields
    world = in_world? ? MGQ_MpWorld.world : nil
    return {} unless world

    fields = { "mp_world" => world.name, "mp_world_id" => world.id, "mp_world_size" => Peers.all.size + 1, "mp_world_max" => world.seats }
    # A world from before the directory cannot be found in the list, so an invite could not enter it.
    fields["mp_world_invite"] = world.code if world.directory_id
    fields
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

  # Asks the scripts for the line above a ghost's name. Called by overworld.rbx.
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
        log_once(block, "#{kind} of #{block.source_location.to_a.first} failed: #{e.class}: #{e.message}")
        nil
      end
    end
  end

  # Takes what the others sent and tells them what changed here. Called every frame in every scene.
  def self.tick
    unless in_world?
      Peers.clear unless Peers.empty?
      Me.forget_seat
      Status.look_closed
      ask(:tick, false)
      return
    end

    Inbox.take_all
    Peers.tick
    ask(:tick, true)
    Me.tell_changes
    Status.look
  rescue => e
    log_once(:tick, "tick failed: #{e.class}: #{e.message}")
  end

  # Hands a message to the script registered for its field.
  #
  # @param peer [Peers::Peer, nil] Who sent it, nil before their first state.
  # @param message [Hash] The message's fields.
  # @return [Boolean] Whether a script took it.
  def self.hand_over(peer, message)
    field, handler = @routes.find { |key, _| message[key] }
    unless field
      fields = message.keys.reject { |key| key == :payload }.first(4).join(", ")
      log_once([:unrouted, fields], "dropped a message from #{who(peer)} that no script takes (fields #{fields})")
      return false
    end

    handler.call(peer, message)
    true
  rescue => e
    log_once([:route_failed, field], "#{field} message failed: #{e.class}: #{e.message}")
    true
  end

  # Patch/Multiplayer/Multiplayer.dll's world room: the inbox and sending.
  module Link
    # Hands out the oldest inbox entry.
    #
    # @return [Hash, nil] "kind" ("seat", "in", "out", "message" or "chat"), "seat", "others",
    #   "name" for a chat entry, and the message's or the chat line's text under :payload; nil
    #   while none waits.
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
      MGQ_Multiplayer::Link.function('mp_world_send').call(target, text + "\0") == 1
    end

    # Mirrors a line of the world's chat to the relay, which keeps it for the world's admins.
    #
    # @param text [String] The line.
    # @return [Integer] 1 when the relay got it, 0 when it did not, 2 when the DLL dropped it for
    #   coming too fast.
    def self.say(text)
      MGQ_Multiplayer::Link.function('mp_world_say').call(text + "\0")
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

      sent = Link.send_to(-1, encode(state))
      log_sending(sent)
      return unless sent

      changed = @told ? MGQ_MpOverworldSync.changes(@told, state) : "the first state, on map #{state['map']} as #{state['name']}"
      MGQ_MpOverworldSync.log("told the others: #{changed}") unless changed.empty?
      @told = state
    end

    # Logs when telling the others starts or stops failing, once each time.
    #
    # @param sent [Boolean] Whether the state went out.
    def self.log_sending(sent)
      return if sent == !@failing

      @failing = !sent
      MGQ_MpOverworldSync.log(sent ? "telling the others works again" : "telling the others failed, trying again every frame")
    end

    # Tells one game everything, as a newcomer needs.
    #
    # @param seat [Integer] The newcomer's seat, -1 for everyone, which also reads the player's
    #   id and name again, since a new connection may follow a new name.
    def self.tell_all(seat)
      @identity = nil if seat < 0
      state = current
      sent = state ? Link.send_to(seat, encode(state)) : false
      MGQ_MpOverworldSync.log("told #{seat < 0 ? 'everyone' : "seat #{seat}"} everything#{state ? " (map #{state['map']})" : ', but the map does not exist yet'}#{sent || !state ? '' : ', which failed'}")
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

    # The id everyone sees for the player.
    #
    # @return [String] The id, "" before the player was set.
    def self.id
      identity[0].to_s
    end

    # The seat of the player's game in the world's room, as the DLL last told it: the inbox tells
    # it on every connection and Status every STATUS_FRAMES; the DLL is asked only while none was told.
    #
    # @return [Integer] The seat, -1 while the game holds none.
    def self.seat
      @seat || take_seat(Link.status["seat"])
    end

    # Keeps the seat the DLL told.
    #
    # @param seat [String, Integer, nil] The seat, empty or nil while the game holds none.
    # @return [Integer] The seat, -1 while the game holds none.
    def self.take_seat(seat)
      @seat = seat.to_s.empty? ? nil : seat.to_i
      @seat || -1
    end

    # Forgets the seat, as the world closes.
    def self.forget_seat
      @seat = nil
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
      return "event" if name =~ /Novel/ || (current.is_a?(Scene_Map) && !MGQ_MpOverworldSync.map_quiet?)
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
    # @!attribute away [Integer, nil] The frames they are still kept for while their connection is down, nil while it stands.
    Peer = Struct.new(:seat, :state, :ghost, :member, :away)

    @peers = {}

    # Takes what a game told. A player who tells from another seat, away or not, is the same player
    # as before.
    #
    # @param seat [Integer] The game's seat.
    # @param state [Hash] What it told.
    def self.take(seat, state)
      peer = @peers[seat]
      # Another player took the seat of one who is away.
      remove(seat, "#{state['name']} took their seat while they were away") if peer && peer.away && peer.state["id"] != state["id"]
      peer = @peers[seat] || moved(seat, state)

      if peer
        changed = MGQ_MpOverworldSync.changes(peer.state, state)
        MGQ_MpOverworldSync.log("#{MGQ_MpOverworldSync.who(peer)} is back, after #{(REJOIN_FRAMES - peer.away) / 60} s away") if peer.away
        MGQ_MpOverworldSync.log("#{MGQ_MpOverworldSync.who(peer)}: #{changed}") unless changed.empty?
        peer.state = state
        peer.away = nil
      else
        peer = @peers[seat] = Peer.new(seat, state, nil, false, nil)
        MGQ_MpOverworldSync.log("#{state['name']} joined the world on seat #{seat} (id #{state['id'].to_s[0, 8]}), on map #{state['map']}")
        Status.notice("#{state['name']} joined the world.")
      end

      MGQ_MpOverworldSync.ask(:observe, peer)
    end

    # Finds the player who now tells from another seat, and moves them there, forgetting the old seat
    # without telling anyone they left.
    #
    # The game connects again as soon as it thinks its connection broke, which the relay may notice
    # only later, so the old seat may still stand.
    #
    # @param seat [Integer] The seat they tell from.
    # @param state [Hash] What they told.
    # @return [Peer, nil] The player, nil when nobody else has their id.
    def self.moved(seat, state)
      peer = @peers.values.find { |other| !state["id"].to_s.empty? && other.state["id"] == state["id"] }
      return nil unless peer

      MGQ_MpOverworldSync.log("#{peer.state['name']} moved from seat #{peer.seat} to seat #{seat}#{peer.away ? '' : ', the old seat still standing'}")
      @peers.delete(peer.seat)
      peer.seat = seat
      @peers[seat] = peer
    end

    # Keeps a game whose connection dropped for REJOIN_FRAMES, in which it may come back.
    #
    # @param seat [Integer] Its seat.
    def self.wait_for(seat)
      peer = @peers[seat]
      return unless peer && peer.away.nil?

      peer.away = REJOIN_FRAMES
      MGQ_MpOverworldSync.log("#{MGQ_MpOverworldSync.who(peer)} is away, kept for #{REJOIN_FRAMES / 60} s")
    end

    # Keeps every game for REJOIN_FRAMES after the player's own connection came back, in which
    # each tells its state again.
    def self.wait_for_all
      @peers.each_key { |seat| wait_for(seat) }
    end

    # Forgets the games that stayed away. Called every frame.
    def self.tick
      @peers.values.each do |peer|
        next unless peer.away

        peer.away -= 1
        remove(peer.seat, "away for #{REJOIN_FRAMES / 60} s") if peer.away <= 0
      end
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
    # @param reason [String] Why, for the log.
    def self.remove(seat, reason = "left")
      peer = @peers.delete(seat)
      return unless peer

      MGQ_MpOverworldSync.log("#{MGQ_MpOverworldSync.who(peer)} left the world: #{reason}")
      Status.notice("#{peer.state['name']} left the world.")
      MGQ_MpOverworldSync.ask(:leave, peer)
    end

    # Forgets every game, as once the world closed.
    def self.clear
      MGQ_MpOverworldSync.log("no world open: forgot #{@peers.size} player(s)") unless @peers.empty?
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

    # Lists the other players whose connection stands, leaving out those kept while away.
    #
    # @return [Array<Peer>] The players.
    def self.present
      all.select { |peer| peer.away.nil? }
    end

    # Lists the players whose connection stands by the names that tell them apart: a name that
    # several share, whatever its case, is numbered from the second of them on by their ids, such
    # as "Name (2)". Nameless players are left out.
    #
    # @return [Array<Array(String, Peer)>] Each name with its player.
    def self.labeled
      named = present.reject { |peer| peer.state["name"].to_s.empty? }
      named.group_by { |peer| peer.state["name"].to_s.downcase }.values.map do |sharing|
        sharing.sort_by { |peer| peer.state["id"].to_s }.each_with_index.map do |peer, index|
          name = peer.state["name"].to_s
          [index == 0 ? name : "#{name} (#{index + 1})", peer]
        end
      end.flatten(1)
    end

    # Tells the name that tells a player apart, see labeled.
    #
    # @param peer [Peer] The player.
    # @return [String, nil] The name, nil once their connection is down or for a nameless player.
    def self.label_of(peer)
      pair = labeled.find { |_, other| other.equal?(peer) }
      pair && pair[0]
    end

    # Finds a player whose connection stands by the name that tells them apart, see labeled.
    #
    # @param name [String, nil] The name.
    # @return [Peer, nil] The player, nil when nobody present has that name, or for none.
    def self.named(name)
      return nil if name.to_s.empty?

      pair = labeled.find { |label, _| label == name }
      pair && pair[1]
    end

    # Finds a player whose connection stands by their player id.
    #
    # @param id [String, nil] The id.
    # @return [Peer, nil] The player, nil when nobody present has that id, or for none.
    def self.with_id(id)
      return nil if id.to_s.empty?

      present.find { |peer| peer.state["id"].to_s == id.to_s }
    end

    # Reports whether another player's connection stands and they are on the player's map, as their
    # last state tells.
    #
    # @param peer [Peer] The player.
    # @return [Boolean] Whether they are.
    def self.on_this_map?(peer)
      peer.away.nil? && $game_map && peer.state["map"].to_i == $game_map.map_id ? true : false
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
        Me.take_seat(entry["seat"])
        MGQ_MpOverworldSync.log("connected on seat #{seat}, #{entry['others'].to_i} other game(s) in the room")
        Peers.wait_for_all
        Me.tell_all(-1)
      when "in"
        MGQ_MpOverworldSync.log("a game came in on seat #{seat}")
        Me.tell_all(seat)
      when "out"
        MGQ_MpOverworldSync.log("the game on seat #{seat} went out#{Peers.at(seat) ? '' : ', which never told its state'}")
        Peers.wait_for(seat)
      when "chat"
        # An admin's line, said in the World Admin tool: no seat said it, so the chat takes it
        # without a sender's state.
        name = entry["name"].to_s
        MGQ_MpOverworldSync.log("chat line from the relay for #{name}")
        # A Symbol key, which no player's message carries, since those are parsed into strings.
        MGQ_MpOverworldSync.hand_over(nil, { "chat" => entry[:payload].to_s, "name" => name, :relay => true })
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
    # @param icon [Integer, nil] An icon of the game's iconset before it, such as an item's.
    def self.notice(text, icon = nil)
      MGQ_MpOverworldSync.log("notice: #{text}")
      @notices.push([text, NOTICE_FRAMES, icon])
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
      Me.take_seat(state["seat"])
      log_connection(state)
      Ping.take(state["ping"])
      @problem =
        case state["state"]
        when "reconnecting" then "Reconnecting . . ."
        when "connecting" then state["error"] || "Connecting . . ."
        when "failed" then "Not connected: #{state['error']}"
        end
    end

    # Follows the connection outside a world every STATUS_FRAMES until it reads idle, so how it
    # closed or failed reaches the log too. Called every frame while no world is open.
    def self.look_closed
      return if @logged_connection.nil? || @logged_connection["state"] == "idle"

      @frames += 1
      return if @frames < STATUS_FRAMES

      @frames = 0
      log_connection(Link.status)
    end

    # Logs the world connection's status once it changed: its state, seat, the other seats, its
    # error and whatever else the DLL tells, such as how the relay closed it. The ping is left out.
    #
    # @param state [Hash] The status, see Link.status.
    def self.log_connection(state)
      fields = state.reject { |key, _| key == "ping" || key == :payload }
      return if fields == @logged_connection

      @logged_connection = fields
      others = fields["others"].to_s.split(/[,;\s]+/).reject(&:empty?)
      parts = [fields["seat"].to_s.empty? ? nil : "seat #{fields['seat']}",
               fields.key?("others") ? "#{others.size} other game(s) in the room" : nil,
               fields["error"].to_s.empty? ? nil : "error: #{fields['error']}"]
      extra = fields.reject { |key, _| %w[state seat others error].include?(key) }.map { |key, value| "#{key} #{value}" }
      MGQ_MpOverworldSync.log("world connection #{fields['state']}#{(parts.compact + extra).empty? ? '' : ', ' + (parts.compact + extra).join(', ')}")
    rescue => e
      MGQ_MpOverworldSync.log_once(:log_connection, "logging the connection failed: #{e.class}: #{e.message}")
    end

    # Tells what the line shows now, with each notice's icon.
    #
    # @return [Array<Array>] Each line's text and icon, nil for none; the connection's problem first.
    def self.shown
      (@problem ? [[@problem, nil]] : []) + @notices.map { |text, _, icon| [text, icon] }
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
      return unless told.nil? || (@measured - told).abs >= [PING_STEP, told * PING_SHARE].max

      MGQ_MpOverworldSync.log("ping #{told ? "#{told} -> " : ''}#{@measured} ms, told the others")
      @told = @measured.to_s
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

# Game hooks, through core_hooks.rbx.

begin
  # After every frame, takes the others' messages and tells them what changed here. Graphics.update
  # runs every frame in every scene, so the others hear of a battle or a menu and nothing piles up
  # meanwhile.
  MGQ_MpHooks.after(Graphics.singleton_class, :update, "overworld_sync") { MGQ_MpOverworldSync.tick }
rescue => e
  MGQ_MpOverworldSync.log("Graphics hook FAILED: #{e.class}: #{e.message}")
end

# Discord shows the world and its players, through the Discord mod's bridge when it is installed.
begin
  MGQ_Discord::Bridge.add_status { |_scene| MGQ_MpOverworldSync.status_fields } if MGQ_Multiplayer::Discord.available?
rescue => e
  MGQ_MpOverworldSync.log("status source FAILED: #{e.class}: #{e.message}")
end
