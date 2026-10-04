#----------------------------------------------------------------
#  coop_castle.rbx
#
#  Changelog:
#      Paulinchen  2026-10-04: Noted where the castle's way out returns a member the party brings into the castle
#                            - Created
#
#----------------------------------------------------------------

# The Pocket Castle in a party: the home the party returns to, whose companions, merchants, inn and
# maids each player talks to in their own game. coop_events.rbx asks it which pages are residents.
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

  # A variable shown in a speaker's name, which a companion's name shows for their affection.
  SHOWN_VARIABLE = /\\V\[(\d+)\]/i

  # The Pocket Castle's front gate, where its item takes the player.
  FRONT_GATE = 126

  # Variables of where the castle's way out returns the player: the map, x and y where they used
  # the castle's item, each player's own (see MGQ_MpCoopStory::PERSONAL_VARIABLES).
  EXIT_VARIABLES = [21, 22, 23]

  extend MGQ_MpLog

  # What starts this script's lines in the mod's InGame.log.
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
