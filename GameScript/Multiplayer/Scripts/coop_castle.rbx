#----------------------------------------------------------------
#  coop_castle.rbx
#
#  Changelog:
#      Paulinchen  2026-10-06: Took the party's leader from coop.rbx, and the ghosts' opacity and catch-up tiles from overworld.rbx
#      Paulinchen  2026-10-04: Showed the leader's residents in the castle, those the member's game does not show as ghosts
#                            - Noted where the castle's way out returns a member the party brings into the castle
#                            - Created
#
#----------------------------------------------------------------

# The Pocket Castle in a party: the home the party returns to, whose companions, merchants, inn and
# maids each player talks to in their own game. coop_events.rbx asks it which pages are residents.
# The castle shows the party leader's residents: the leader moves them as the Map Owner of
# coop_npcs.rbx, and a resident the member's own game does not show, such as a companion only the
# leader recruited, stands there as a see-through ghost the member cannot talk to. The member's
# own residents stay theirs to talk to.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpCoopCastle
  # Maps of the Pocket Castle, the home the party returns to, whose companions, merchants, inn and
  # maids each player talks to in their own game. The maps of the castle's side stories stay out.
  MAPS = [227, 228, 229, 230] + (268..278).to_a

  # Common events of the Pocket Castle's services: Vanilla's shop (106), Papi's smithy (107), the
  # maids' party saves (111), the item storage (144) and Teeny's inn (270).
  SERVICES = [106, 107, 111, 144, 270]

  # Scripts of the Pocket Castle's coin shop, which lists its goods itself.
  SHOP_SCRIPTS = /\A\s*@goods\b/

  @ghosts = {}

  # A variable shown in a speaker's name, which a companion's name shows for their affection.
  SHOWN_VARIABLE = /\\V\[(\d+)\]/i

  # The Pocket Castle's front gate, where its item takes the player.
  FRONT_GATE = 126

  # Variables of where the castle's way out returns the player: the map, x and y where they used
  # the castle's item, each player's own (see MGQ_MpCoopStory::PERSONAL_VARIABLES).
  EXIT_VARIABLES = [21, 22, 23]

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "co-op castle"

  # Reports whether a page on the Pocket Castle's maps is one of its residents: a companion, a
  # merchant, the inn or a maid, which each player talks to in their own game, whatever the talk
  # sets. The castle's story events show none of these, though they share the companions' scripts.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @return [Boolean] Whether it is.
  def self.resident?(list)
    return false unless $game_map && MAPS.include?($game_map.map_id)

    companion_talk?(list) || list.any? do |c|
      (c.code == 117 && SERVICES.include?(c.parameters[0])) || (c.code == 355 && c.parameters[0].to_s =~ SHOP_SCRIPTS)
    end
  end

  # Notes where the castle's way out returns the player, as the castle's item does, when the party
  # brings them into the castle from elsewhere: by a story's call, its follow, or a teleport to
  # the leader. Called before the player is moved.
  #
  # @param map_id [Integer] The map the player is brought to.
  def self.arriving(map_id)
    return unless castle_map?(map_id) && !castle_map?($game_map.map_id)

    place = [$game_map.map_id, $game_player.x, $game_player.y]
    EXIT_VARIABLES.zip(place).each { |id, value| $game_variables[id] = value }
    log("the castle's way out returns to map #{place[0]} #{place[1]},#{place[2]}")
  rescue => e
    log("noting the castle's way out failed: #{e.class}: #{e.message}")
  end

  # Reports whether a map is the Pocket Castle's: its front gate or one of its residents' maps.
  #
  # @param map_id [Integer] The map.
  # @return [Boolean] Whether it is.
  def self.castle_map?(map_id)
    map_id == FRONT_GATE || MAPS.include?(map_id)
  end

  # Forgets the ghosts, as when the map changes.
  def self.forget
    @ghosts = {}
  end

  # Finds the Map Owner of a castle map: the party's leader while they are on it, so the castle
  # shows the leader's residents.
  #
  # @param members [Array<MGQ_MpOverworldSync::Peers::Peer>] The other party members on the map.
  # @return [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The leader, :me for the player, nil off
  #   the castle or while the leader is elsewhere.
  def self.owner(members)
    return nil unless $game_map && castle_map?($game_map.map_id)

    leader = MGQ_MpCoop.party_leader
    leader == :me ? :me : members.find { |peer| peer.equal?(leader) }
  end

  # The residents only the leader's game shows, by their event's id.
  #
  # @return [Hash{Integer => Game_MpResident}] The ghosts.
  def self.ghosts
    @ghosts
  end

  # Shows the residents the leader's game shows and the player's does not, as ghosts where the
  # leader's stand, and lets the others go. Called after the map's update.
  def self.update
    targets = castle_map?($game_map.map_id) && MGQ_MpCoopNpcs.following? ? MGQ_MpCoopNpcs.targets : {}
    @ghosts.keys.each { |id| @ghosts.delete(id) unless ghost_of?($game_map.events[id], targets[id]) }
    targets.each do |id, state|
      next unless ghost_of?($game_map.events[id], state)

      ghost = @ghosts[id] ||= Game_MpResident.new(state)
      ghost.follow(MGQ_MpCoopNpcs.page_of($game_map.events[id], state[3]), state)
    end
  rescue => e
    log_once(:update, "showing the leader's residents failed: #{e.class}: #{e.message}")
  end

  # Reports whether an event stands as a ghost: the player's own game shows nothing of it, while
  # the leader's shows it with a look.
  #
  # @param event [Game_Event, nil] The player's event.
  # @param state [Array<Integer>, nil] The leader's: x, y, facing and page.
  # @return [Boolean] Whether it does.
  def self.ghost_of?(event, state)
    return false unless event && state && state[3] >= 0 && event.mgq_mp_page != state[3]
    return false if event.mgq_mp_page >= 0 && (!event.character_name.to_s.empty? || event.tile_id > 0)

    graphic = MGQ_MpCoopNpcs.page_of(event, state[3])
    graphic = graphic && graphic.graphic
    graphic && (!graphic.character_name.to_s.empty? || graphic.tile_id > 0) ? true : false
  end

  # Reports whether a page is a companion's talk: its first speaker's name shows their affection.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @return [Boolean] Whether it is.
  def self.companion_talk?(list)
    first = list.find { |c| c.code == 401 }
    return false unless first

    first.parameters[0].to_s.scan(SHOWN_VARIABLE).any? do |(id)|
      id.to_i >= MGQ_MpCoopStory::AFFECTION_VARIABLES && MGQ_MpCoopStory.personal_variable?(id.to_i)
    end
  end
end

# A resident of the Pocket Castle that only the party leader's game shows: it looks as the leader's
# page shows it, stands and walks where the leader's stands, walks through everything and starts
# nothing, since it is no event of the player's map.
class Game_MpResident < Game_Character
  # Creates the ghost where the leader's resident stands.
  #
  # @param state [Array<Integer>] The leader's: x, y, facing and page.
  def initialize(state)
    super()
    @through = true
    @opacity = MGQ_MpOverworld::STRANGER_OPACITY
    moveto(state[0], state[1])
  end

  # Takes the look of the leader's page and walks toward where the leader's resident stands, or
  # moves there at once when it is far.
  #
  # @param page [RPG::Event::Page, nil] The leader's page of the event.
  # @param state [Array<Integer>] The leader's: x, y, facing and page.
  def follow(page, state)
    look_like(page) if page
    update
    return if moving?

    x, y, direction = state
    dx = x - @x
    dy = y - @y
    if dx == 0 && dy == 0
      set_direction(direction) if direction > 0
    elsif dx.abs + dy.abs > MGQ_MpOverworld::CATCH_UP_TILES
      moveto(x, y)
    else
      move_straight(dx.abs >= dy.abs ? (dx > 0 ? 6 : 4) : (dy > 0 ? 2 : 8))
    end
  end

  # Takes the look of a page, as the game's event takes it: the sprite or tile, and how it moves.
  #
  # @param page [RPG::Event::Page] The page.
  def look_like(page)
    return if @page.equal?(page)

    @page = page
    graphic = page.graphic
    @tile_id = graphic.tile_id
    @character_name = graphic.character_name
    @character_index = graphic.character_index
    @original_pattern = @pattern = graphic.pattern
    @direction = graphic.direction
    @priority_type = page.priority_type
    @walk_anime = page.walk_anime
    @step_anime = page.step_anime
    @move_speed = page.move_speed
  end
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # After the map's update, the leader's residents the player's game does not show.
  MGQ_MpHooks.after(Game_Map, :update, "coop_castle") { MGQ_MpCoopCastle.update }

  # A new map has residents of its own.
  MGQ_MpHooks.after(Game_Map, :setup, "coop_castle") { |_map_id| MGQ_MpCoopCastle.forget }

  # After the map's sprites, a sprite per ghost of a resident.
  MGQ_MpHooks.after(Spriteset_Map, :update, "coop_castle") do
    @mgq_mp_residents ||= {}
    ghosts = MGQ_MpCoopCastle.ghosts.values
    @mgq_mp_residents.keys.each do |ghost|
      @mgq_mp_residents.delete(ghost).dispose unless ghosts.any? { |shown| shown.equal?(ghost) }
    end
    ghosts.each { |ghost| (@mgq_mp_residents[ghost] ||= Sprite_Character.new(@viewport1, ghost)).update }
  end

  MGQ_MpHooks.before(Spriteset_Map, :dispose, "coop_castle") do
    (@mgq_mp_residents || {}).each_value { |sprite| sprite.dispose }
    @mgq_mp_residents = nil
  end
rescue => e
  MGQ_MpCoopCastle.log("hooks FAILED: #{e.class}: #{e.message}")
end
