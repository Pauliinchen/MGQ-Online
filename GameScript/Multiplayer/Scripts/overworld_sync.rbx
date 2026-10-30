#----------------------------------------------------------------
#  overworld_sync.rbx
#
#  Changelog:
#      Paulinchen  2026-10-23: Left the other players, the inbox, the player's state, ping and status to the DLL, keeping a mirror of the players
#                            - Handed the DLL the player's frame and the routes with their gates
#                            - Asked the DLL when the player entered a map they just arrived on
#                            - Dropped say, since the chat sends through the DLL
#                            - Kept a player away whose seat another player took, and told each change of a player's presence
#      Paulinchen  2026-10-13: Handed the relay's raid bosses push to the script registered for it
#                            - Handed the relay's squad push to the script registered for it
#      Paulinchen  2026-10-12: Announced only the players who join after the player
#                            - Set the time the player entered their map anew after leaving the world or loading
#                            - Told nobody a state while the player is on the title screen or a new game waits
#      Paulinchen  2026-10-10: Handed on the share left, the max HP and the defeat with the relay's boss pool push
#      Paulinchen  2026-10-09: Handed the relay's boss pool push to the script registered for it
#                            - Handed the relay's difficulty push to the script registered for it
#                            - Handed the relay's mods rule push to the script registered for it
#      Paulinchen  2026-10-08: Marked an admin's line from the relay with a key no player's message can carry
#                            - Handed the relay's push of a Raid World's story to the script registered for it
#                            - Passed on whether the relay got a chat line or the DLL dropped it
#                            - Listed the players whose connection stands and found them by name, id and map
#                            - Numbered a name that several players share, such as "Name (2)"
#      Paulinchen  2026-10-07: Mirrored a chat line to the relay and handed an admin's line to the chat
#                            - Kept the player's seat as the inbox and the status tell it
#                            - Logged a failing route once
#                            - Named the DLL's exports alone
#                            - Logged the players, the connection's status, the notices and dropped messages
#      Paulinchen  2026-10-06: Moved a player who tells from a new seat while their old one still stands
#                            - Dropped Status.lines, which only the tests read
#                            - Handed the Discord mod the world code
#      Paulinchen  2026-10-04: Took an icon with a notice
#                            - Renamed from mp_overworld_sync.rbx
#      Paulinchen  2026-10-03: Added map_quiet? and map_free?
#                            - Added tell, notice, Me.id and Me.seat
#                            - Logged through MGQ_MpLog
#                            - Kept a dropped player for fifteen seconds and every player across a reconnect
#      Paulinchen  2026-10-02: Told Discord the open world's name, its players and its seats through the Discord mod
#                            - Followed Graphics.update through core_hooks.rbx
#                            - Marked the player's state apart from the scripts' messages
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# The open world's messages, as the scripts take part in them. The DLL keeps the world room (the
# other players, their settle and away windows, the player's state told to them, the inbox, the
# ping, the party and the gates; MGQOnline.Game's WorldRoom): this script hands it what the player
# does each frame and keeps a mirror of the other players its events tell. Scripts that load after
# this one take part through its registry: route for their messages, state_fields and busy_scene
# for the player's state, on_tick, on_observe, on_leave and on_presence to follow the others, and
# label_line for the line above a ghost's name. What the player sees of it is overworld.rbx's.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpOverworldSync
  # What a player does on a screen of the game, by the screen's class name; any other screen is a
  # menu.
  SCREENS = {
    /\AScene_(Item|Storehouse)\z/ => "items",
    /\AScene_(Equip|EquipStone\w*|Smith|Synthesize)\z/ => "equip",
    /\AScene_Shop\z/ => "shop",
    /\AScene_(Poker|Slot|CasinoPrize)\z/ => "casino",
    /Library/ => "library",
  }

  # Frames a notice stays at the bottom left, four seconds at 60 frames per second.
  NOTICE_FRAMES = 240

  # Frames a player whose connection dropped is kept, fifteen seconds, as the DLL keeps them
  # (WorldRoom.RejoinFrames); trade.rbx waits for a partner as long.
  REJOIN_FRAMES = 900

  # The field that marks a message as a player's state, which no route may be named like.
  STATE_FIELD = "state"

  # The field of the relay's push that a Raid World's story changed, with its revision, which the
  # world's story registers its route for.
  STORY_FIELD = "story_rev"

  # The field of the relay's push that a Raid World's boss pool changed, with the pool's key, which
  # the raid bosses' pools register their route for; "left", "max", "defeated" and "by" hold the
  # rest of the push.
  BOSS_FIELD = "boss_key"

  # The field of the relay's push that a Raid World's creator or an admin changed its difficulty,
  # with the difficulty, which world_difficulty.rbx registers its route for.
  DIFFICULTY_FIELD = "difficulty_value"

  # The field of the relay's push that a Raid World's creator or an admin changed its squad rules,
  # with the squad text, see MGQ_MpWorld.squad_of, which coop_squad.rbx registers its route for.
  SQUAD_FIELD = "squad_value"

  # The field of the relay's push that a Classic world's creator or an admin changed whether its
  # story bosses fight as raid bosses, with "1" or "0", which battles_raid_tiers.rbx registers its
  # route for.
  RAID_BOSSES_FIELD = "raid_bosses_value"

  # The field of the relay's push that a world's creator or an admin changed whether it turns other
  # mods off, or its mods, with "1" or "0" and the mods under "mods", which world_mods.rbx
  # registers its route for.
  MODS_RULE_FIELD = "mods_rule_value"

  # The bridge topic the player's frame goes to the DLL by, see before_frame.
  ME_TOPIC = "world.me"

  # The bridge topic the routes go to the DLL by, see tell_routes.
  ROUTES_TOPIC = "world.routes"

  # The scripts' message handlers, by the field that marks their messages, see route.
  @routes = {}

  # The gate each route's messages pass in the DLL, by field: "party", "map" or nil for none.
  @gates = {}

  # The blocks the scripts registered, by kind: :tick, :state_fields, :busy_scene, :observe, :leave,
  # :presence and :label_line.
  @handlers = Hash.new { |handlers, kind| handlers[kind] = [] }

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "overworld sync"

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

  # Reports whether a world is open.
  #
  # @return [Boolean] Whether world.rbx has a world open.
  def self.in_world?
    defined?(MGQ_MpWorld) && MGQ_MpWorld.open? ? true : false
  end

  # Reports whether the player is on no map yet: the title screen shows, or a world's new game
  # waits there, also through the world screen's fade-out.
  #
  # The title screen keeps the previous game's objects, so $game_map still names its map.
  #
  # @return [Boolean] Whether they are.
  def self.before_map?
    return true if SceneManager.scene.is_a?(Scene_Title)

    defined?(MGQ_MpWorld) && MGQ_MpWorld.respond_to?(:new_game_pending?) && MGQ_MpWorld.new_game_pending? ? true : false
  rescue
    false
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

  # Hands every message marked by a field to a script, once it passed the field's gate in the DLL.
  # The first field registered wins when a message carries several.
  #
  # @param field [String] The field, such as "chat".
  # @param gate [String, nil] "party" for the party's gate (MGQ_MpCoop.route), "map" for the map's
  #   (MGQ_MpCoop.route_map), nil for none.
  # @yieldparam peer [Peers::Peer, nil] Who sent it, nil before their first state and for the
  #   relay's push.
  # @yieldparam message [Hash] The message's fields, its body under :payload, and :relay for the
  #   relay's push.
  def self.route(field, gate = nil, &handler)
    @routes[field] = handler
    @gates[field] = gate
    @routes_told = false
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

  # Tells a script each change of another player's presence: their connection dropped and they
  # are kept for REJOIN_FRAMES (:away), it came back (:back), they tell from another seat (:moved),
  # or they left the world or stayed away too long (:gone, also told through on_leave).
  #
  # @yieldparam peer [Peers::Peer] The player, on their current seat.
  # @yieldparam change [Symbol] :away, :back, :moved or :gone.
  def self.on_presence(&block)
    @handlers[:presence] << block
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

  # Hands the DLL what it needs of the player this frame, once it changed: whether a world is open,
  # the player's state, the world's type and the map the story takes the player to. Called before
  # every frame's Graphics.update, so the frame's batch carries it to the DLL before its drain.
  def self.before_frame
    return unless MGQ_Multiplayer::Bridge.has?(ME_TOPIC)

    tell_routes unless @routes_told
    in_world = in_world?
    state = in_world ? Me.current : nil
    # As text, as the message carries it, so no script's Float or Symbol stops the frame's batch.
    state = Hash[state.map { |key, value| [key.to_s, value.to_s] }] if state
    frame = { "in_world" => in_world, "state" => state, "raid" => raid?, "story_map" => in_world ? story_map : nil }
    return if frame == @staged

    @staged = frame
    MGQ_Multiplayer::Bridge.stage(ME_TOPIC, frame)
  rescue => e
    log_once(:before_frame, "handing the DLL the player's frame failed: #{e.class}: #{e.message}")
  end

  # Hands the DLL every route with its gate, in the order the scripts registered them.
  def self.tell_routes
    @routes_told = true
    MGQ_Multiplayer::Bridge.stage(ROUTES_TOPIC, @routes.keys.map { |field| [field, @gates[field]] })
  end

  # Reports whether a Raid World is open, through world.rbx.
  #
  # @return [Boolean] Whether one is.
  def self.raid?
    defined?(MGQ_MpWorld) && MGQ_MpWorld.respond_to?(:raid?) && MGQ_MpWorld.raid? ? true : false
  rescue
    false
  end

  # Finds the map the story takes the player to besides their own, see MGQ_MpCoopGather.follow_taken.
  #
  # @return [Integer, nil] The map, nil for none.
  def self.story_map
    return nil unless defined?(MGQ_MpCoopGather) && MGQ_MpCoopGather.respond_to?(:follow_taken)

    follow = MGQ_MpCoopGather.follow_taken
    follow ? follow[:place][0].to_i : nil
  end

  # Follows the frames: forgets the mirror once no world is open, lets the scripts follow, and lets
  # notices run out. Called every frame in every scene, after the bridge's drain.
  def self.tick
    unless in_world?
      Peers.clear unless Peers.empty?
      Me.forget_seat
      Status.forget_problem
      ask(:tick, false)
      return
    end

    ask(:tick, true)
    Status.look
  rescue => e
    log_once(:tick, "tick failed: #{e.class}: #{e.message}")
  end

  # Hands a message the DLL routed to the script registered for its field.
  #
  # @param event [Hash] "field", "seat" (nil for the relay), "fields", "body" and "relay".
  def self.take_route(event)
    message = event["fields"]
    message[:payload] = event["body"].to_s
    # A Symbol key, which no player's message carries, since those are parsed into strings.
    message[:relay] = true if event["relay"]
    hand_over(event["seat"] && Peers.at(event["seat"]), message)
  end

  # Hands a message to the script registered for its field.
  #
  # @param peer [Peers::Peer, nil] Who sent it, nil before their first state.
  # @param message [Hash] The message's fields.
  # @return [Boolean] Whether a script took it.
  def self.hand_over(peer, message)
    field, handler = @routes.find { |key, _| message[key] }
    unless field
      fields = message.keys.reject { |key| key.is_a?(Symbol) }.first(4).join(", ")
      log_once([:unrouted, fields], "dropped a message from #{who(peer)} that no script takes (fields #{fields})")
      return false
    end

    handler.call(peer, message)
    true
  rescue => e
    log_once([:route_failed, field], "#{field} message failed: #{e.class}: #{e.message}")
    true
  end

  # Patch/Multiplayer/Multiplayer.dll's world room: sending.
  module Link
    # Sends a message to one seat or to every other game.
    #
    # @param target [Integer] The seat, -1 for everyone.
    # @param text [String] The message.
    # @return [Boolean] Whether it went out.
    def self.send_to(target, text)
      MGQ_Multiplayer::Link.function('mp_world_send').call(target, text + "\0") == 1
    end
  end

  # What this game tells the others about its player; the DLL adds their id and name, when they
  # entered their map, the ping and the party.
  module Me
    # The bridge topic that forgets when the player entered their map.
    RESET_SINCE_TOPIC = "world.reset_since"

    # The bridge topic that tells when the player entered a map.
    SINCE_TOPIC = "world.since"

    # Reads what the others need to know about the player.
    #
    # @return [Hash, nil] The player's state, nil while the player is on no map yet.
    def self.current
      return nil unless $game_player && $game_map && $game_map.map_id > 0
      return nil if MGQ_MpOverworldSync.before_map?

      looks = $game_player.vehicle || $game_player
      state = {
        STATE_FIELD => 1,
        "sprite" => looks.character_name.to_s,
        "index" => looks.character_index,
        "map" => $game_map.map_id,
        "x" => $game_player.x,
        "y" => $game_player.y,
        "d" => $game_player.direction,
        "speed" => $game_player.real_move_speed,
        "hidden" => $game_player.transparent ? 1 : 0,
        "scene" => scene,
      }
      MGQ_MpOverworldSync.ask(:state_fields).compact.each { |fields| state.merge!(fields) }
      state
    end

    # The player's id and name, read once per connection.
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

    # The seat of the player's game in the world's room, as the DLL last told it.
    #
    # @return [Integer] The seat, -1 while the game holds none.
    def self.seat
      @seat || -1
    end

    # Keeps the seat the DLL told, reading the player's id and name again on a new one, since a new
    # connection may follow a new name.
    #
    # @param seat [String, Integer, nil] The seat, empty or nil while the game holds none.
    # @return [Integer] The seat, -1 while the game holds none.
    def self.take_seat(seat)
      taken = seat.to_s.empty? ? nil : seat.to_i
      @identity = nil if taken && taken != @seat
      @seat = taken
      @seat || -1
    end

    # Forgets the seat, as the world closes.
    def self.forget_seat
      @seat = nil
    end

    # Keeps when the player entered their map, as the DLL told it.
    #
    # @param map [Integer] The map.
    # @param since [Integer, nil] Milliseconds since 1970, nil before the player entered one.
    def self.take_since(map, since)
      @since_map = since ? map : nil
      @since = since
    end

    # Forgets when the player entered their map, so a returning player or a loaded save enters it
    # anew. A reconnect keeps it.
    def self.reset_map_since
      @since_map = nil
      @since = nil
      MGQ_Multiplayer::Bridge.stage(RESET_SINCE_TOPIC)
    end

    # Tells when the player entered the map they are on, which decides who of a party on a map is
    # its Map Owner; on a map the DLL has not seen them on yet, it stamps the arrival now.
    #
    # @return [Integer] Milliseconds since 1970 by this computer's clock, 0 without the DLL.
    def self.map_since
      map = $game_map.map_id
      return @since if @since && @since_map == map

      answer = MGQ_Multiplayer::Bridge.call(SINCE_TOPIC, map)
      take_since(map, answer["since"]) if answer.is_a?(Hash)
      @since_map == map ? @since.to_i : 0
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

  # The other games of the world, by seat, mirrored from the DLL's events: the scripts read these
  # every frame, and the battle server fills it itself (battles_served.rbx).
  module Peers
    # Another player: their seat, what they last told, and their ghost while on this map.
    #
    # @!attribute seat [Integer] Their game's seat.
    # @!attribute state [Hash] What they last told: "name", "sprite", "index", "map", "x", "y",
    #   "d", "speed", "hidden", "scene".
    # @!attribute ghost [Game_MpGhost, nil] Their ghost, while they are on this map.
    # @!attribute member [Boolean] Whether they were in the player's party at their last message.
    # @!attribute away [Boolean, Integer, nil] True while their connection is down and the DLL keeps
    #   them, nil while it stands; on the battle server, which sits in no world's room, the frames
    #   left of the grace the battle channel's players are kept for, see wait_for.
    Peer = Struct.new(:seat, :state, :ghost, :member, :away)

    # The other games, by seat.
    @peers = {}

    # The players away whose seat another player took, kept until they come back on another seat or
    # the DLL forgets them.
    @displaced = []

    # The names that tell the players apart, by seat, see labeled.
    @labels = {}

    # Takes what a game told, and lets the scripts follow it. A player who was away is back.
    #
    # @param seat [Integer] The game's seat.
    # @param state [Hash] What it told.
    # @param member [Boolean] Whether its player is in the player's party.
    def self.take(seat, state, member = false)
      peer = @peers[seat] ||= Peer.new(seat, state, nil, false, nil)
      back = !peer.away.nil?
      peer.state = state
      peer.member = member ? true : false
      peer.away = nil
      changed_presence(peer, :back) if back
      MGQ_MpOverworldSync.ask(:observe, peer)
    end

    # Notes that a game's connection dropped; the DLL keeps it a while.
    #
    # @param seat [Integer] Its seat.
    def self.away(seat)
      peer = @peers[seat]
      return unless peer && peer.away.nil?

      peer.away = true
      changed_presence(peer, :away)
    end

    # Moves a player who now tells from another seat there, one kept aside included.
    #
    # @param seat [Integer] The new seat.
    # @param from [Integer] The old seat.
    # @param id [String, nil] Their player id, which tells a player kept aside from the one now on
    #   their old seat.
    def self.moved(seat, from, id = nil)
      peer = kept_aside(id) || @peers.delete(from)
      return unless peer

      @displaced.delete(peer)
      peer.seat = seat
      @peers[seat] = peer
      changed_presence(peer, :moved)
    end

    # Keeps a player who is away aside once another player tells from their seat, as the DLL does,
    # so they stay the same player when they come back on another seat.
    #
    # @param seat [Integer] The seat another player took.
    def self.displace(seat)
      peer = @peers.delete(seat)
      return unless peer

      peer.ghost = nil
      @displaced << peer
    end

    # Keeps a game whose connection dropped for REJOIN_FRAMES, in which it may come back. Called on
    # the battle server, where the battle channel tells the players' presence.
    #
    # @param seat [Integer] Its seat.
    def self.wait_for(seat)
      peer = @peers[seat]
      return unless peer && peer.away.nil?

      peer.away = REJOIN_FRAMES
      MGQ_MpOverworldSync.log("#{MGQ_MpOverworldSync.who(peer)} is away, kept for #{REJOIN_FRAMES / 60} s")
      changed_presence(peer, :away)
    end

    # Takes back a game kept away whose connection came back without a new state, as the battle
    # channel tells the battle server.
    #
    # @param seat [Integer] Its seat.
    def self.come_back(seat)
      peer = @peers[seat]
      return unless peer && peer.away

      after = peer.away.is_a?(Integer) ? ", after #{(REJOIN_FRAMES - peer.away) / 60} s away" : ""
      MGQ_MpOverworldSync.log("#{MGQ_MpOverworldSync.who(peer)} is back#{after}")
      peer.away = nil
      changed_presence(peer, :back)
    end

    # Forgets the games that stayed away past the grace wait_for gave them. Called every frame on
    # the battle server; the DLL counts the grace in a world.
    def self.tick
      @peers.values.each do |peer|
        next unless peer.away.is_a?(Integer)

        peer.away -= 1
        remove(peer.seat, "away for #{REJOIN_FRAMES / 60} s") if peer.away <= 0
      end
    end

    # Tells the scripts that follow presence of a player's change, see MGQ_MpOverworldSync.on_presence.
    #
    # @param peer [Peer] The player.
    # @param change [Symbol] :away, :back, :moved or :gone.
    def self.changed_presence(peer, change)
      MGQ_MpOverworldSync.ask(:presence, peer, change)
    end

    # Takes whom of the players the party counts, as the party's view tells.
    #
    # @param seats [Array<Integer>] The members' seats.
    def self.take_members(seats)
      @peers.each_value { |peer| peer.member = seats.include?(peer.seat) }
    end

    # Takes the names that tell the players apart.
    #
    # @param labels [Hash{Integer => String}] The names by seat, in the DLL's order.
    def self.take_labels(labels)
      @labels = labels
    end

    # Finds a game by its seat.
    #
    # @param seat [Integer] The seat.
    # @return [Peer, nil] The game, nil before its first state.
    def self.at(seat)
      @peers[seat]
    end

    # Forgets a game that left, one kept aside included, and lets the scripts follow.
    #
    # @param seat [Integer] Its seat.
    # @param reason [String] Why, for the log.
    # @param id [String, nil] Its player id, which tells a player kept aside from the one now on
    #   their old seat.
    def self.remove(seat, reason = "left", id = nil)
      peer = kept_aside(id)
      peer = @peers.delete(seat) unless peer
      return unless peer

      @displaced.delete(peer)
      MGQ_MpOverworldSync.log("forgot #{MGQ_MpOverworldSync.who(peer)}: #{reason}")
      MGQ_MpOverworldSync.ask(:leave, peer)
      changed_presence(peer, :gone)
    end

    # Forgets every game, as once the world closed.
    def self.clear
      @peers.clear
      @displaced.clear
      @labels = {}
    end

    # Reports whether no other game is known.
    #
    # @return [Boolean] Whether none is.
    def self.empty?
      @peers.empty? && @displaced.empty?
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

    # Lists the players whose connection stands by the names that tell them apart, as the DLL
    # numbers a name several share, such as "Name (2)". Nameless players are left out.
    #
    # @return [Array<Array(String, Peer)>] Each name with its player.
    def self.labeled
      @labels.map { |seat, label| [label, @peers[seat]] }.select { |_, peer| peer && peer.away.nil? }
    end

    # Tells the name that tells a player apart, see labeled.
    #
    # @param peer [Peer] The player.
    # @return [String, nil] The name, nil once their connection is down or for a nameless player.
    def self.label_of(peer)
      peer.away.nil? ? @labels[peer.seat] : nil
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

    # Finds a player by their player id, also while their connection is down and they are kept,
    # which a battle asks to know them on whatever seat they hold.
    #
    # @param id [String, nil] The id.
    # @return [Peer, nil] The player, nil when nobody kept has that id, or for none.
    def self.kept_with_id(id)
      return nil if id.to_s.empty?

      (@peers.values + @displaced).find { |peer| peer.state["id"].to_s == id.to_s }
    end

    # Finds a player kept aside by their player id.
    #
    # @param id [String, nil] The id.
    # @return [Peer, nil] The player, nil when nobody kept aside has that id, or for none.
    def self.kept_aside(id)
      return nil if id.to_s.empty?

      @displaced.find { |peer| peer.state["id"].to_s == id.to_s }
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

  # What the line at the bottom left of the map shows: who came and went, and when the connection
  # is down.
  module Status
    # The notices shown: each one's text, frames left and icon.
    @notices = []

    # Adds a notice, shown for a few seconds.
    #
    # @param text [String] The notice.
    # @param icon [Integer, nil] An icon of the game's iconset before it, such as an item's.
    def self.notice(text, icon = nil)
      MGQ_MpOverworldSync.log("notice: #{text}")
      show(text, icon)
    end

    # Shows a notice for a few seconds without logging it, as for the DLL's, which logs its own.
    #
    # @param text [String] The notice.
    # @param icon [Integer, nil] An icon of the game's iconset before it.
    def self.show(text, icon = nil)
      @notices.push([text, NOTICE_FRAMES, icon])
      @notices.shift while @notices.size > 3
    end

    # Takes how the connection stands, as the DLL tells it: the seat, its problem, the ping and when
    # the player entered their map.
    #
    # @param status [Hash] "seat", "problem", "ping", "map" and "since".
    def self.take(status)
      Me.take_seat(status["seat"])
      Me.take_since(status["map"], status["since"])
      @problem = status["problem"]
      Ping.take(status["ping"])
    end

    # Forgets the connection's problem, as the world closes.
    def self.forget_problem
      @problem = nil
    end

    # Lets notices run out. Called every frame in a world.
    def self.look
      @notices.each { |notice| notice[1] -= 1 }
      @notices.reject! { |_, left| left <= 0 }
    end

    # Tells what the line shows now, with each notice's icon.
    #
    # @return [Array<Array>] Each line's text and icon, nil for none; the connection's problem
    #   first.
    def self.shown
      (@problem ? [[@problem, nil]] : []) + @notices.map { |text, _, icon| [text, icon] }
    end
  end

  # The player's ping: the round trip to the relay, which the DLL times every few seconds and tells
  # the others once it moved noticeably.
  module Ping
    # The last ping measured in milliseconds, nil while there is no connection.
    @measured = nil

    # Takes the ping the DLL tells.
    #
    # @param ping [Integer, nil] The milliseconds, nil while there is no connection.
    def self.take(ping)
      @measured = ping
    end

    # The last ping measured.
    #
    # @return [Integer, nil] The milliseconds, nil while there is no connection.
    def self.measured
      @measured
    end
  end
end

# The DLL's events of the world room, through the bridge's drain.

begin
  bridge = MGQ_Multiplayer::Bridge
  sync = MGQ_MpOverworldSync
  bridge.on("world.peer") { |event| sync::Peers.take(event["seat"], event["state"], event["member"]) }
  bridge.on("world.peer_away") { |event| sync::Peers.away(event["seat"]) }
  bridge.on("world.peer_moved") { |event| sync::Peers.moved(event["seat"], event["from"], event["id"]) }
  bridge.on("world.peer_displaced") { |event| sync::Peers.displace(event["seat"]) }
  bridge.on("world.peer_left") { |event| sync::Peers.remove(event["seat"], "left", event["id"]) }
  bridge.on("world.labels") { |labels| sync::Peers.take_labels(labels) }
  bridge.on("world.route") { |event| sync.take_route(event) }
  bridge.on("world.notice") { |text| sync::Status.show(text) }
  bridge.on("world.status") { |status| sync::Status.take(status) }
rescue => e
  MGQ_MpOverworldSync.log("bridge events FAILED: #{e.class}: #{e.message}")
end

# Game hooks, through core_hooks.rbx.

begin
  # Before every frame, hands the DLL the player's frame, which the frame's batch carries before
  # the drain; after it, follows the frames. Graphics.update runs every frame in every scene, so
  # the others hear of a battle or a menu and nothing piles up meanwhile.
  MGQ_MpHooks.before(Graphics.singleton_class, :update, "overworld_sync") { MGQ_MpOverworldSync.before_frame }
  MGQ_MpHooks.after(Graphics.singleton_class, :update, "overworld_sync") { MGQ_MpOverworldSync.tick }
rescue => e
  MGQ_MpOverworldSync.log("Graphics hook FAILED: #{e.class}: #{e.message}")
end

begin
  # A loaded save or a new game enter their map anew. Not after extract_save_contents, which a
  # duel's end calls too to put the game back.
  MGQ_MpHooks.after(DataManager.singleton_class, :load_game_without_rescue, "overworld_sync") { |_index| MGQ_MpOverworldSync::Me.reset_map_since }
  MGQ_MpHooks.after(DataManager.singleton_class, :setup_new_game, "overworld_sync") { MGQ_MpOverworldSync::Me.reset_map_since }
rescue => e
  MGQ_MpOverworldSync.log("save hooks FAILED: #{e.class}: #{e.message}")
end

# Discord shows the world and its players, through the Discord mod's bridge when it is installed.
begin
  MGQ_Discord::Bridge.add_status { |_scene| MGQ_MpOverworldSync.status_fields } if MGQ_Multiplayer::Discord.available?
rescue => e
  MGQ_MpOverworldSync.log("status source FAILED: #{e.class}: #{e.message}")
end
