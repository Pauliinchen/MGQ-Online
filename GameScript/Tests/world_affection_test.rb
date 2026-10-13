#----------------------------------------------------------------
#  world_affection_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-12: Created
#
#----------------------------------------------------------------

# Covers world_affection.rbx: the world's affection raising the player's, the player's written with
# their story as the highest of both, and a write asked for once the player's passes the world's.

require_relative "support"

# Stands in for the mod's log: prints each line.
module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end

# Stands in for the map, whose update world_affection.rbx hooks.
class Game_Map; def update; end; end

# Stands in for RPG::Actor with its persona kind: a sub persona keeps its affection with the main
# one.
ActorData = Struct.new(:id, :name, :persona_kind)
$data_actors = Array.new(1000)
[[56, "Rami", :main], [68, "Papi", :main], [86, "Rosary", :main], [500, "Rami (Chaos)", :sub]].each do |id, name, kind|
  $data_actors[id] = ActorData.new(id, name, kind)
end

# Stands in for the game's variables, which start at 0.
class Game_Variables; def initialize; @data = []; end; def [](id); @data[id] || 0; end; def []=(id, value); @data[id] = value; end; end

# Stands in for story_state.rbx: packs and unpacks the story's lists as it does.
module MGQ_MpStoryState
  # Packs the story's lists.
  #
  # @param lists [Hash{String => String}] The lists.
  # @return [String] The packed text.
  def self.pack(lists)
    [Zlib::Deflate.deflate(lists.map { |name, list| "#{name}=#{list}" }.join("\n"))].pack("m0")
  end

  # Unpacks the story's lists, see pack.
  #
  # @param text [String] The packed text.
  # @return [Hash{String => String}] The lists.
  def self.unpack(text)
    Zlib::Inflate.inflate(text.unpack("m0")[0]).split("\n").map { |line| line.split("=", 2) }.each_with_object({}) { |(name, list), lists| lists[name] = list.to_s }
  end
end

# Stands in for the world's story: whether it is followed, the world, and whether the player plays
# it, so a write asked for follows.
module MGQ_MpWorldStory
  class << self
    attr_accessor :active, :world_id, :plays, :requests
  end

  # Answers whether the world's story is followed.
  def self.active?; @active; end

  # Counts a write asked for in requests while the player plays the world's story.
  #
  # @return [Boolean] Whether a write follows.
  def self.request_post
    @requests += 1 if @plays
    @plays ? true : false
  end
end

load_script("world_affection")
affection = MGQ_MpWorldAffection
$game_variables = Game_Variables.new
MGQ_MpWorldStory.active = true
MGQ_MpWorldStory.world_id = "w1"
MGQ_MpWorldStory.plays = true
MGQ_MpWorldStory.requests = 0
# Ticks the affection a number of frames.
#
# @param count [Integer] The frames.
frames = lambda { |count| count.times { affection.tick } }
# Packs a world's story with an affection list.
#
# @param list [String] The list, as "companion:affection" entries.
# @return [String] The packed story.
story = lambda { |list| MGQ_MpStoryState.pack("v" => "1001:9", "a" => list) }

check("the companions are the main personas", affection.ids, [56, 68, 86])

$game_variables[3056] = 40
$game_variables[3086] = 100
affection.take(story.call("56:25,68:30,86:120,500:90"))
check("the world's affection raises the player's where it is higher, never lowers it, and leaves a sub persona out",
      [$game_variables[3056], $game_variables[3068], $game_variables[3086], $game_variables[3500]], [40, 30, 120, 0])
frames.call(130)
check("the player's own higher affection asks for a write", MGQ_MpWorldStory.requests, 1)
lists = affection.add("v" => "1001:9")
check("which carries each companion's highest of theirs and the world's", lists["a"], "56:40,68:30,86:120")
frames.call(700)
check("once written it asks no more", MGQ_MpWorldStory.requests, 1)

$game_variables[3068] = 35
frames.call(130)
check("a gift raising it later asks again, after the wait since the last write", MGQ_MpWorldStory.requests, 2)

MGQ_MpWorldStory.requests = 0
affection.take(story.call(""))
frames.call(700)
check("a story an earlier version wrote without the list leaves the player's affection and gets it written back",
      [$game_variables[3056], MGQ_MpWorldStory.requests], [40, 1])

MGQ_MpWorldStory.requests = 0
MGQ_MpWorldStory.plays = false
affection.add("v" => "")
$game_variables[3086] = 130
frames.call(700)
check("a player behind the world's story is not counted as written", MGQ_MpWorldStory.requests, 0)

MGQ_MpWorldStory.plays = true
MGQ_MpWorldStory.world_id = "w2"
lists = affection.add("v" => "")
check("another world starts without the first world's affection", lists["a"], "56:40,68:35,86:130")

MGQ_MpWorldStory.active = false
MGQ_MpWorldStory.requests = 0
$game_variables[3056] = 99
frames.call(700)
check("outside a Raid World's story it asks for nothing", MGQ_MpWorldStory.requests, 0)
