#----------------------------------------------------------------
#  world_freeze_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-17: Created
#
#----------------------------------------------------------------

# Covers world_freeze.rbx with battles_raid_bosses.rbx and battles_raid_freeze_data.rbx: the frozen
# raid boss fights' text written and read back, broken texts dropped, the union by troop, the held
# keys' index, a write asked for, and the end of a frozen fight by its defeated pools or its BEATEN
# marker in the player's or the world's story, or by the end of the fight the other side plays in
# its stead, and the end written into the world's story and read from it, final for the world: no
# note, take or merge brings a fight back that ended, nor the fight the other side plays in its stead.

require_relative "support"

# Stands in for the mod's log: prints each line.
module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end

# Stands in for the frame counter, which the checks move with $frame.
module Graphics; def self.frame_count; $frame; end; end
$frame = 0

# Stands in for the title scene, whose start forgets the frozen fights.
class Scene_Title; def start; end; end

# Stands in for the game's switches, off unless set.
class Game_Switches; def initialize; @data = []; end; def [](id); @data[id] || false; end; def []=(id, value); @data[id] = value; end; end
# Stands in for the game's variables, 0 unless set.
class Game_Variables; def initialize; @data = []; end; def [](id); @data[id] || 0; end; def []=(id, value); @data[id] = value; end; end

# Stands in for story_state.rbx: packs the story's lists and writes and reads values as it does.
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
    Zlib::Inflate.inflate(text.unpack("m0")[0]).force_encoding("UTF-8").split("\n").map { |line| line.split("=", 2) }.each_with_object({}) { |(name, list), lists| lists[name] = list.to_s }
  end

  # Writes a variable's value as story_state.rbx does.
  #
  # @param value [Object] The value.
  # @return [String] The value, empty for a kind no message carries.
  def self.encode_value(value)
    case value
    when Integer then "n#{value}"
    when Float then "f#{value}"
    when String then "s#{[value].pack('m0')}"
    when true then "T"
    when false then "F"
    else ""
    end
  end

  # Reads a variable's value as story_state.rbx does.
  #
  # @param text [String] The value as written.
  # @return [Object] The value, nil for none.
  def self.decode_value(text)
    case text[0, 1]
    when "n" then text[1..-1].to_i
    when "f" then text[1..-1].to_f
    when "s" then text[1..-1].unpack('m0')[0].force_encoding("UTF-8")
    when "T" then true
    when "F" then false
    end
  end
end

# Stands in for the world's story: the open world's id and the writes asked for.
module MGQ_MpWorldStory
  class << self
    attr_accessor :world_id, :requests
  end

  # Counts a write asked for.
  #
  # @return [Boolean] Whether a write follows, always.
  def self.request_post
    @requests += 1
    true
  end
end
MGQ_MpWorldStory.world_id = "w1"
MGQ_MpWorldStory.requests = 0

# Stands in for the raid pools: each troop's pool keys from $keys, the pools from $pools, and the
# BEATEN markers of the Sonya fights read as battles_raid_pool.rbx reads them.
module MGQ_MpRaidPool
  # A pool as the relay told it.
  Pool = Struct.new(:left, :max, :defeated)

  # The markers that tell a milestone beaten.
  BEATEN = { ["Sonya Mazda", 55] => "s7009", ["Sonya Mainyu", 55] => "s7010", ["Sonya Chaos", 55] => "v1075>=20" }

  # Lists a troop's pool keys.
  def self.troop_keys(troop); $keys[troop] || []; end

  # Finds a pool the relay told.
  def self.pool(key); $pools[key]; end

  # Reports whether the player's story beat a milestone.
  def self.beaten?(boss); test = BEATEN[[boss.milestone, boss.cap]]; test ? met?(test) : false; end

  # Reports whether the game's values, or a story's, meet a test of BEATEN.
  def self.met?(test, story = nil)
    switches, variables = story || [$game_switches, $game_variables]
    test.split("|").any? do |all|
      all.split("&").all? do |condition|
        case condition
        when /\As(\d+)\z/ then switches[$1.to_i] ? true : false
        when /\Av(\d+)>=(-?\d+)\z/ then variables[$1.to_i].to_i >= $2.to_i
        else false
        end
      end
    end
  end
end
$keys = { 868 => ["Sonya Mazda"], 870 => ["Sonya Chaos"] }
$pools = {}
$game_switches = Game_Switches.new
$game_variables = Game_Variables.new

load_script "battles_raid_bosses"
load_script "battles_raid_freeze_data"
load_script "world_freeze"
freeze = MGQ_MpWorldFreeze

# Makes a frozen fight's entry as battles_raid_freeze.rbx builds it.
#
# @param troop [Integer] The troop.
# @param held [Array<Array>] The held keys.
# @param name [String] The boss sprite's character name.
# @return [Hash] The entry.
def entry_of(troop, held, name = "$Sonya")
  { "troop" => troop, "site" => "map:138:13:1", "outer" => "map:138:13:1", "scene" => false,
    "tableau" => [138, [[13, 32, 8, 2, 1, name, 0, 0, 255, 0, 1, 1, 1], [14, 30, 8, 6, 0, "Luka", 2, 0, 255, 0, 1, 0, 1]], [13]],
    "spot" => [138, 30, 10, 8], "held" => held }
end

# Packs a world's story with a frozen fights' list.
#
# @param list [String, nil] The list, nil for a story without one.
# @return [String] The packed story.
def story_with(list)
  lists = { "v" => "1001:n33" }
  lists["f"] = list if list
  MGQ_MpStoryState.pack(lists)
end

# Text: every free text escaped, so separators inside names and values never break the list.
odd = entry_of(868, [[1, 1075, 14], [1, 2001, "a|b;c,d:e%f~g=h.i ü"], [1, 2002, 1.5], [1, 2003, -7], [0, 31, false], [0, 32, true],
                     [2, [138, 13, "A"], false], [2, [138, 14, "B|;"], true]], "$Sonya!|;,:%~=.ソニア")
text = freeze.encode([odd])
check("a frozen fight's text holds none of the list's separators inside its free texts",
      [text.count(";"), text.count("|"), text.include?("ソ"), text.include?("~g")], [0, 8, false, false])
read = freeze.decode(text)
check("and reads back as written: UTF-8, $ and ! names, self switch keys, string and float values", read, [odd])
check("its names come back as UTF-8", read[0]["tableau"][1][0][5].encoding, Encoding::UTF_8)
check("an escaped text has only the plain bytes and %XX", freeze.escape("a-b_c$d!e f.g"), "a-b_c$d!e%20f%2Eg")

# Broken texts and unknown troops are dropped, the rest read.
good = freeze.encode([entry_of(870, [[1, 1075, 16]])])
broken = [
  "garbage",
  good.sub("870|", "5|"),
  good.sub("map:138:13:1", "map:138:13"),
  good.sub(":1:1:1,", ":1:2:1,"),
  good.sub("$Sonya", "%zzSonya"),
  good.sub("v1075~n16", "v1075~"),
  good.sub("|138.30.10.8|", "|138.30.10|"),
  good.sub("870|", "99999999999|"),
  good + "|extra",
]
check("broken entries and troops that are no boss are dropped, the good one read",
      freeze.decode((broken + [good]).join(";")).map { |entry| entry["troop"] }, [870])
check("a list carries at most MAX_ENTRIES fights", freeze.decode(([good] * 40).join(";")).size, MGQ_MpWorldFreeze::MAX_ENTRIES)
check("a tableau needs exactly one boss row", freeze.decode(good.sub("255:0:1:1:1,", "255:0:1:0:1,")), [])

# The player's own frozen fight: noted, indexed, and a write asked for.
noted = freeze.note(entry_of(868, [[1, 1075, 14], [0, 31, false], [2, [138, 13, "A"], false], [1, 2004, [1, 2]]]).merge("state" => "frozen", "frames" => []))
check("noting the player's frozen fight asks for a write", [noted, MGQ_MpWorldStory.requests], [true, 1])
check("and marks it unshared until a write carries it", freeze.unshared?, true)
check("whose entry leaves the record's own fields and a list value the story cannot carry out",
      [freeze.entry(868).keys.sort, freeze.held.map { |kind, key, _| [kind, key] }], [%w(held outer scene site spot tableau troop), [[1, 1075], [0, 31], [2, [138, 13, "A"]]]])
check("its held keys are indexed by kind and key",
      [freeze.held_value(1, 1075), freeze.held_value(0, 31), freeze.held_value(2, [138, 13, "A"]), freeze.held_value(1, 1076), freeze.held_value(0, 1075)],
      [[true, 14], [true, false], [true, false], nil, nil])
check("a note that is no entry is refused without a write", [freeze.note("map:1"), freeze.note(entry_of(868, []).merge("site" => "x")), MGQ_MpWorldStory.requests], [false, false, 1])

# Union by troop: a known fight keeps its fields and gains the keys it lacks, its own value winning.
world = entry_of(868, [[1, 1075, 16], [1, 1076, 3]])
world["spot"] = [138, 1, 1, 2]
other = entry_of(870, [[1, 1075, 18], [0, 33, true]])
other["site"] = "map:728:12:1"
freeze.take(story_with(freeze.encode([world, other])))
check("the world's entry of a known fight adds its new keys, the known value winning",
      [freeze.held_value(1, 1075), freeze.held_value(1, 1076), freeze.entry(868)["spot"]], [[true, 14], [true, 3], [138, 30, 10, 8]])
check("a fight the player did not know joins the list after the known ones", freeze.entries.map { |entry| entry["troop"] }, [868, 870])
check("the oldest fight's value wins a key two fights hold", [freeze.held_value(1, 1075), freeze.held_value(0, 33)], [[true, 14], [true, true]])
before = freeze.entries
freeze.take(story_with(nil))
freeze.take(story_with(""))
check("a world's story without the list, as an earlier version writes it, changes nothing", freeze.entries, before)
lists = freeze.add("v" => "1001:n33")
check("a story written carries the list", freeze.decode(lists["f"]).map { |entry| entry["troop"] }, [868, 870])
check("which leaves nothing unshared", freeze.unshared?, false)
freeze.take(story_with(nil))
check("nor does a world's story without the list, as the relay's keyed story comes back, since no write could fix it", freeze.unshared?, false)
freeze.take(story_with(freeze.encode([world])))
check("a world's story that lacks a known fight or held key marks the list unshared again", freeze.unshared?, true)
freeze.add({})

# The end of a frozen fight: its pools defeated, its marker met in the player's story or the world's.
$pools["Sonya Mazda"] = MGQ_MpRaidPool::Pool.new(0.0, 100, false)
$frame = 100
check("a pool not yet defeated keeps the fight", freeze.entries.map { |entry| entry["troop"] }, [868, 870])
$pools["Sonya Mazda"] = MGQ_MpRaidPool::Pool.new(0.0, 100, true)
$frame = 130
check("its defeat is looked at once a second", freeze.entries.size, 2)
$frame = 161
check("then ends the fight", [freeze.entries.map { |entry| entry["troop"] }, freeze.ended?(entry_of(868, []))], [[870], true])
check("whose keys the next fight takes over or lets go", [freeze.held_value(1, 1075), freeze.held_value(1, 1076), freeze.held_value(0, 31)], [[true, 18], nil, nil])
check("and which is never written again", freeze.decode(freeze.add({})["f"]).map { |entry| entry["troop"] }, [870])
freeze.take(story_with(freeze.encode([entry_of(868, [[1, 1075, 14]])])))
check("nor taken again from a world's story that still carries it", freeze.entries.map { |entry| entry["troop"] }, [870])
check("nor noted again", [freeze.note(entry_of(868, [[1, 1075, 14]])), freeze.entries.size], [false, 1])
$pools.clear
freeze.world_told([[], [nil] * 1075 + [20], {}])
check("the world's told story meeting the marker ends a fight at once", freeze.entries, [])
freeze.world_told([[], [], {}])
check("a fight the world's story beat stays ended for good, though its story no longer meets the marker",
      [freeze.note(entry_of(870, [[1, 1075, 18]])), freeze.entries, freeze.final?(870)], [false, [], true])
Scene_Title.new.start
freeze.note(entry_of(870, [[1, 1075, 18]]))
$game_variables[1075] = 20
$frame = 300
check("the player's own story meeting the marker ends it too", [freeze.entries, freeze.held], [[], []])
$game_variables[1075] = 0
$keys[868] = ["Sonya Mazda#0", "Sonya Mazda#1"]
$pools["Sonya Mazda#0"] = MGQ_MpRaidPool::Pool.new(0.0, 100, true)
freeze.note(entry_of(868, [[1, 1075, 14]]))
check("a boss with a pool the relay has not told is not ended by its other defeated pool", freeze.entries.map { |entry| entry["troop"] }, [868])

# Another world, and the title.
MGQ_MpWorldStory.world_id = "w2"
check("another world forgets the frozen fights of the last", [freeze.entries, freeze.held_value(1, 1075)], [[], nil])
freeze.note(entry_of(868, [[1, 1075, 14]]))
Scene_Title.new.start
check("the title forgets them", [freeze.entries, freeze.held_value(1, 1075)], [[], nil])

# A battle the player won against the troop's pools ends its frozen fight at once, its keys let go
# before they are put into a story.
# Stands in for battles_raid_freeze.rbx: the troops the player won a battle against, in $won.
module MGQ_MpRaidFreeze; def self.won?(troop); $won.include?(troop.to_i); end; end
$won = []
$pools.clear
$keys.clear
freeze.note(entry_of(868, [[1, 1075, 14]]))
check("a fight not won holds its keys", freeze.held, [[1, 1075, 14]])
$won << 868
check("a won one lets them go at once", [freeze.held, freeze.entries, freeze.ended?(entry_of(868, []))], [[], [], true])

# The end of a fight travels as "<troop>|0", which the DLL and the relay keep in place of the
# fight's key, so it reaches every game, also those that only read.
check("the end of a fight this game saw goes into every write, with the end of the other side's fight",
      [freeze.add({})["f"], freeze.add({})["f"]], ["868|0;869|0", "868|0;869|0"])
$won.clear
Scene_Title.new.start
asked = MGQ_MpWorldStory.requests
freeze.take(story_with(freeze.encode([entry_of(870, [[1, 1075, 16]])])))
check("a game that only reads takes the world's fight", freeze.entries.map { |entry| entry["troop"] }, [870])
freeze.take(story_with("870|0;" + freeze.encode([entry_of(868, [[1, 1076, 2]])])))
check("and drops it once the world's story carries its end, taking the other fights", freeze.entries.map { |entry| entry["troop"] }, [868])
written = freeze.add({})["f"]
check("without a write, since the world's story ends it already, though every write still carries the end",
      [MGQ_MpWorldStory.requests - asked, freeze.unshared?, freeze.decode(written).map { |entry| entry["troop"] }, written.end_with?(";870|0")], [0, false, [868], true])
check("the player's own fight against a troop the world ended is refused, for good",
      [freeze.note(entry_of(870, [[1, 1075, 18]])), freeze.final?(870), freeze.entries.map { |entry| entry["troop"] }, MGQ_MpWorldStory.requests - asked], [false, true, [868], 0])
freeze.take(story_with(freeze.encode([entry_of(870, [[1, 1075, 18]]), entry_of(868, [[1, 1076, 2]])])))
check("as is the world's entry of it, which a racing write brought back", freeze.entries.map { |entry| entry["troop"] }, [868])
check("whose story lacks the end then", freeze.unshared?, true)
freeze.add({})
asked = MGQ_MpWorldStory.requests
freeze.world_told([[nil] * 7009 + [true], [], {}])
check("an end this game saw asks for a write that carries it, with the other side's",
      [freeze.entries, MGQ_MpWorldStory.requests - asked, freeze.unshared?, freeze.add({})["f"]], [[], 1, true, "868|0;869|0;870|0"])
freeze.take(story_with(freeze.encode([entry_of(868, [[1, 1076, 2]])])))
check("a world's story that still carries the fight lacks its end", [freeze.entries, freeze.unshared?], [[], true])
freeze.world_told([[], [], {}])
freeze.take(story_with(freeze.encode([entry_of(868, [[1, 1076, 2]])])))
check("one whose marker the world's story no longer meets stays ended for good, its end still written",
      [freeze.entries, freeze.final?(868), freeze.final?(869), freeze.add({})["f"]], [[], true, true, "868|0;869|0;870|0"])

# The player's own fight that no write carried yet ends with the end the world's story carries, and a
# world's end of one side's fight ends the other side's too, which this game then writes.
Scene_Title.new.start
freeze.note(entry_of(870, [[1, 1075, 18]]))
freeze.take(story_with("870|0"))
check("the player's own fight that no write carried yet ends with the world's end of it",
      [freeze.entries, freeze.held, freeze.note(entry_of(870, [[1, 1075, 18]]))], [[], [], false])
check("a fight not ended is no final one", [freeze.final?(868), freeze.final?(869)], [false, false])
freeze.add({})
freeze.take(story_with("868|0;870|0"))
check("the world's end of Sonya Mazda ends Mainyu too", [freeze.final?(869), freeze.note(entry_of(869, [[1, 1075, 15]])), freeze.entries], [true, false, []])
check("which the world's story lacks, so the next write carries it", [freeze.unshared?, freeze.add({})["f"]], [true, "868|0;869|0;870|0"])
freeze.take(story_with("868|0;869|0;870|0"))
check("and a world's story with every end lacks nothing", freeze.unshared?, false)
check("an end of no troop is no end", [freeze.ended_troop("0|0"), freeze.ended_troop("12|00"), freeze.ended_troop("12|0")], [nil, nil, 12])
long = entry_of(870, (1..300).map { |id| [1, 2000 + id, "x" * 200] })
check("a fight longer than the relay keeps is never written", [freeze.encode([long]), freeze.note(long)], ["", false])

# A fight only one side plays also ends with the fight the other side plays in its stead, so a player
# of the other side past it is never held back: Sonya Mazda (868) on Alice's, Mainyu (869) on Ilias's.
check("Sonya Mazda and Mainyu are each other's other side, Sonya Chaos has none",
      [freeze.alternatives(868), freeze.alternatives(869), freeze.alternatives(870)], [[869], [868], []])
Scene_Title.new.start
freeze.note(entry_of(868, [[1, 1075, 14], [0, 2307, true]]))
check("a fight whose other side's fight has not ended holds its keys", freeze.held, [[1, 1075, 14], [0, 2307, true]])
$won << 869
check("an Ilias-side win over Mainyu ends the frozen fight against Mazda at once",
      [freeze.held, freeze.entries, freeze.ended?(entry_of(868, [])), freeze.add({})["f"]], [[], [], true, "868|0;869|0"])
check("nor is Mazda noted again", freeze.note(entry_of(868, [[1, 1075, 14]])), false)
$won.clear
Scene_Title.new.start
freeze.note(entry_of(868, [[1, 1075, 14]]))
freeze.world_told([[nil] * 7010 + [true], [], {}])
check("the world's story meeting Mainyu's marker ends it too", [freeze.entries, freeze.add({})["f"]], [[], "868|0;869|0"])
freeze.world_told([[], [], {}])
check("for good, Mainyu's fight with it", [freeze.note(entry_of(869, [[1, 1075, 15]])), freeze.entries], [false, []])
Scene_Title.new.start
freeze.note(entry_of(869, [[1, 1075, 15]]))
$game_switches[7009] = true
check("and the other way round, the player's story past Mazda ends a frozen fight against Mainyu", [freeze.held, freeze.entries], [[], []])
$game_switches[7009] = false
