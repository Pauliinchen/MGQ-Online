#----------------------------------------------------------------
#  coop_npcs.rbx
#
#  Changelog:
#      Paulinchen  2026-10-04: Made the party's leader the Map Owner of the Pocket Castle, and told coop_castle.rbx the Map Owner's events and pages
#                            - Let a story's forced routes, and every event while the leader's story plays, walk through party members
#                            - Renamed from mp_coop_npcs.rbx
#      Paulinchen  2026-10-03: Called the scripts that load before this one without asking whether they loaded
#                            - Sent messages, showed notices and read the world, the own id and the own seat through MGQ_MpOverworldSync
#                            - Logged through MGQ_MpLog
#      Paulinchen  2026-10-02: Followed the map's update through core_hooks.rbx
#                            - Took an event's page from coop.rbx, and dropped the unused role
#      Paulinchen  2026-09-30: Sent and took the party's messages through coop.rbx, which drops those of another party
#                            - Registered with overworld_sync.rbx for its messages instead of being asked by overworld.rbx
#                            - Moved into Patch/Multiplayer/Scripts as coop_npcs.rbx, which Multiplayer.rb loads
#                            - Renamed from mp_npcs.rb, with the module MGQ_MpCoopNpcs
#                            - Created
#
#----------------------------------------------------------------

# The NPCs a party shares on a map. Of the party members on a map, the one who entered it first is
# its Map Owner: their game moves the map's events as the game does, and tells the others where each
# stands, which way it faces and which page it shows. The other members' games stop moving events
# on their own and walk them where the Map Owner's are. Players outside the party, or on other
# maps, share nothing: each moves their own NPCs.
#
# The world's creator plays no part in this; every map has its own Map Owner, and it changes as
# players come and go.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpCoopNpcs
  # Frames between two messages of the Map Owner, a quarter of a second at 60 frames per second.
  SEND_FRAMES = 15

  # Tiles an event walks to catch up; farther away, it moves there at once.
  CATCH_UP_TILES = 3

  # Frames an event may fail to walk to its place before it moves there at once.
  STUCK_FRAMES = 60

  # Tiles within which an approaching event notices a party member, as the game's own check does for the player.
  NEAR_TILES = 20

  @role = nil
  @frames = 0
  @sent = {}
  @present = []
  @targets = {}
  @stuck = {}
  @blockers = []

  # Reports whether the hooks can be installed.
  #
  # A second copy of this script would wrap the same methods under the same names, and each hook
  # would then call itself until the stack overflows.
  #
  # @return [Boolean] false when the hooks are in place already.
  def self.hookable?
    !Game_Event.method_defined?(:mgq_mp_coop_npcs_update_self_movement)
  end

  extend MGQ_MpLog

  # What starts this script's lines in the mod's InGame.log.
  LOG_TAG = "co-op npcs"

  # Reports whether another party member's game moves this map's events.
  #
  # @return [Boolean] Whether it does.
  def self.following?
    @role == :follower
  end

  # Lists the other party members on the player's map.
  #
  # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The members.
  def self.party_here
    return [] unless MGQ_MpOverworldSync.in_world?
    return [] unless MGQ_MpCoop::Party.id

    MGQ_MpOverworldSync::Peers.all.select { |peer| peer.member && peer.state["map"].to_i == $game_map.map_id }
  end

  # Finds the Map Owner among the party members on the map: the one who entered it first, the lower
  # player id among equals, so every member's game finds the same one. On the Pocket Castle's maps
  # it is the party's leader while they are there, see coop_castle.rbx.
  #
  # @param members [Array<MGQ_MpOverworldSync::Peers::Peer>] The other party members on the map.
  # @return [MGQ_MpOverworldSync::Peers::Peer, Symbol] The member, or :me for the player.
  def self.owner(members)
    castle = defined?(MGQ_MpCoopCastle) && MGQ_MpCoopCastle.owner(members)
    return castle if castle

    me = [[MGQ_MpOverworldSync::Me.map_since.to_i, MGQ_MpOverworldSync::Me.id], :me]
    others = members.map { |peer| [[peer.state["since"].to_i, peer.state["id"].to_s], peer] }
    ([me] + others).min_by { |key, _| key }[1]
  end

  # Follows the map for one frame: finds the Map Owner, and sends or follows the events. Called
  # after the map's own update, behind other screens too.
  def self.update
    members = party_here
    role = members.empty? ? nil : (owner(members) == :me ? :owner : :follower)
    change_role(role) if role != @role
    @blockers = members.map(&:ghost).compact

    case @role
    when :owner then lead(members)
    when :follower then follow
    end
  rescue => e
    log_once(:update, "update failed: #{e.class}: #{e.message}")
  end

  # Starts a new part, forgetting what the old one sent or followed.
  #
  # @param role [Symbol, nil] The new part.
  def self.change_role(role)
    @role = role
    @sent = {}
    @present = []
    @targets = {}
    @stuck = {}
    @frames = SEND_FRAMES
  end

  # As Map Owner, sends newcomers the whole picture and everyone what changed.
  #
  # @param members [Array<MGQ_MpOverworldSync::Peers::Peer>] The other party members on the map.
  def self.lead(members)
    seats = members.map(&:seat)
    (seats - @present).each { |seat| tell(seat, snapshot, true) }
    @present = seats

    @frames += 1
    return if @frames < SEND_FRAMES

    @frames = 0
    now = snapshot
    changed = now.reject { |id, state| @sent[id] == state }
    return if changed.empty?

    @sent = now if tell(-1, changed, false)
  end

  # Reads every event of the map.
  #
  # @return [Hash{Integer => Array<Integer>}] Each event's x, y, facing and page by its id.
  def self.snapshot
    states = {}
    $game_map.events.each { |id, event| states[id] = event.mgq_mp_npc_state }
    states
  end

  # Sends events' states to one party member or to everyone, who ignore it unless they are in the
  # party on this map.
  #
  # @param seat [Integer] The member's seat, -1 for everyone.
  # @param states [Hash{Integer => Array<Integer>}] The events' states.
  # @param full [Boolean] Whether they are all the map's events.
  # @return [Boolean] Whether it went out.
  def self.tell(seat, states, full)
    list = states.map { |id, state| "#{id}:#{state.join(',')}" }.join(";")
    MGQ_MpCoop.tell(seat, "npcs", $game_map.map_id, "full" => full ? 1 : 0, "events" => list)
  end

  # Takes the Map Owner's events. Called by coop.rbx.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent them.
  # @param message [Hash] The message's fields.
  def self.take(peer, message)
    return unless following? && peer && message["npcs"].to_i == $game_map.map_id
    return unless owner(party_here).equal?(peer)

    full = message["full"] == "1"
    @targets = {} if full
    message["events"].to_s.split(";").each do |entry|
      id, state = entry.split(":", 2)
      @targets[id.to_i] = state.to_s.split(",").map(&:to_i)
    end
    @targets.each { |id, state| place($game_map.events[id], state) } if full
  rescue => e
    log_once(:take, "taking events failed: #{e.class}: #{e.message}")
  end

  # The Map Owner's events the player's game follows.
  #
  # @return [Hash{Integer => Array<Integer>}] Each event's x, y, facing and page by its id.
  def self.targets
    @targets
  end

  # Finds a page of an event, as the Map Owner's game shows it.
  #
  # @param event [Game_Event, nil] The event.
  # @param index [Integer] The page's index, below 0 for none.
  # @return [RPG::Event::Page, nil] The page, nil for none.
  def self.page_of(event, index)
    event && index >= 0 ? event.mgq_mp_pages[index] : nil
  end

  # Walks every event toward where the Map Owner's stands.
  def self.follow
    @targets.each { |id, state| walk($game_map.events[id], id, state) }
  end

  # Walks an event a step toward its place, or moves it there at once when it is far or stuck.
  #
  # An event talking to the player or moved by one of the player's own events stays where it is,
  # and so does an event on another page than the Map Owner's, which means another story state.
  #
  # @param event [Game_Event, nil] The event.
  # @param id [Integer] Its id.
  # @param state [Array<Integer>] Its place: x, y, facing and page.
  def self.walk(event, id, state)
    return unless event && event.mgq_mp_npc_free? && event.mgq_mp_page == state[3]
    return if event.moving?

    x, y, direction = state
    dx = x - event.x
    dy = y - event.y
    if dx == 0 && dy == 0
      @stuck.delete(id)
      event.mgq_mp_npc_face(direction)
    elsif dx.abs + dy.abs > CATCH_UP_TILES || (@stuck[id] = @stuck[id].to_i + 1) > STUCK_FRAMES
      @stuck.delete(id)
      place(event, state)
    else
      event.move_straight(dx.abs >= dy.abs ? (dx > 0 ? 6 : 4) : (dy > 0 ? 2 : 8))
    end
  end

  # Moves an event to its place at once.
  #
  # @param event [Game_Event, nil] The event.
  # @param state [Array<Integer>] Its place: x, y, facing and page.
  def self.place(event, state)
    return unless event && event.mgq_mp_npc_free? && event.mgq_mp_page == state[3]

    event.moveto(state[0], state[1])
    event.mgq_mp_npc_face(state[2])
  end

  # Reports whether a party member stands on a tile, which an event cannot walk onto.
  #
  # @param x [Integer] The tile's x.
  # @param y [Integer] The tile's y.
  # @return [Boolean] Whether one does.
  def self.member_at?(x, y)
    @blockers.any? { |ghost| ghost.x == x && ghost.y == y }
  end

  # Finds the party member an approaching event goes for on the Map Owner's map: the nearest of the
  # player and the other members.
  #
  # @param event [Game_Event] The event.
  # @return [Game_Character, nil] The member's ghost when one is nearer than the player, else nil.
  def self.nearest_member(event)
    return nil unless @role == :owner

    distance = lambda { |character| event.distance_x_from(character.x).abs + event.distance_y_from(character.y).abs }
    nearest = @blockers.min_by { |ghost| distance.call(ghost) }
    nearest && distance.call(nearest) < distance.call($game_player) ? nearest : nil
  end

  # Reports whether a party member is near enough for an approaching event to notice them.
  #
  # @param event [Game_Event] The event.
  # @return [Boolean] Whether one is.
  def self.member_near?(event)
    @role == :owner && @blockers.any? { |ghost| event.distance_x_from(ghost.x).abs + event.distance_y_from(ghost.y).abs < NEAR_TILES }
  end
end

# What this script takes part in of the party's messages, through coop.rbx.

begin
  MGQ_MpCoop.route("npcs") { |peer, message| MGQ_MpCoopNpcs.take(peer, message) }
rescue => e
  MGQ_MpCoopNpcs.log("co-op FAILED: #{e.class}: #{e.message}")
end

# Game hooks.
#
# Each wraps a game method: the original runs first unless said otherwise, and the mod's part never
# raises.

if MGQ_MpCoopNpcs.hookable?
  begin
    class Game_Event
      alias mgq_mp_coop_npcs_update_self_movement update_self_movement
      alias mgq_mp_coop_npcs_collide_with_characters? collide_with_characters?
      alias mgq_mp_coop_npcs_near_the_player? near_the_player?

      # Moves the event on its own, unless another party member's game moves it. The original does
      # not run then.
      def update_self_movement
        mgq_mp_coop_npcs_update_self_movement unless MGQ_MpCoopNpcs.following?
      end

      # Reports whether the event collides with a character on a tile, a party member included
      # while the event walks on its own.
      #
      # A story moves its events on routes it waits for, which a member standing in the way would
      # hold up for good, so members never block a forced route or an event while the leader's
      # story plays.
      #
      # @param x [Integer] The tile's x.
      # @param y [Integer] The tile's y.
      # @return [Boolean] Whether it does.
      def collide_with_characters?(x, y)
        return true if mgq_mp_coop_npcs_collide_with_characters?(x, y)
        return false if @move_route_forcing || !normal_priority? || (MGQ_MpCoopEvents.telling? rescue false)

        MGQ_MpCoopNpcs.member_at?(x, y)
      end

      # Reports whether the player, or on the Map Owner's map a party member, is near enough for an
      # approaching event to go for them.
      #
      # @return [Boolean] Whether one is.
      def near_the_player?
        mgq_mp_coop_npcs_near_the_player? || MGQ_MpCoopNpcs.member_near?(self)
      end

      # Walks toward the nearest party member, the player unless another member is nearer. The
      # original does not run for another member.
      def move_toward_player
        member = MGQ_MpCoopNpcs.nearest_member(self)
        member ? move_toward_character(member) : super
      end

      # Tells where the event stands, which way it faces and which page it shows.
      #
      # @return [Array<Integer>] x, y, facing and the page's index, -1 for none, as when erased.
      def mgq_mp_npc_state
        [@x, @y, @direction, mgq_mp_page]
      end

      # Reports whether the Map Owner may move the event here: not while it talks to the player or
      # one of the player's own events moves it.
      #
      # @return [Boolean] Whether it may.
      def mgq_mp_npc_free?
        !@locked && !@move_route_forcing
      end

      # Turns the event to a facing, as far as the event lets itself be turned.
      #
      # @param direction [Integer] The facing.
      def mgq_mp_npc_face(direction)
        set_direction(direction) if direction > 0 && direction != @direction
      end
    end
  rescue => e
    MGQ_MpCoopNpcs.log("event hooks FAILED: #{e.class}: #{e.message}")
  end
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # After the map's update, its events for the party.
  MGQ_MpHooks.after(Game_Map, :update, "coop_npcs") { MGQ_MpCoopNpcs.update }
rescue => e
  MGQ_MpCoopNpcs.log("map hook FAILED: #{e.class}: #{e.message}")
end
