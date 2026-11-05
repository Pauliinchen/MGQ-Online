#----------------------------------------------------------------
#  world_freeze_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Read the scripts' clock from $frame
#      Paulinchen  2026-10-28: Stood in for the freeze's tables the DLL's events database answers
#      Paulinchen  2026-10-23: Checked each frozen fight as a key of the relay's story tracks instead of a list beside the whole story
#      Paulinchen  2026-10-17: Created
#
#----------------------------------------------------------------

# Covers world_freeze.rbx with battles_raid_bosses.rbx and a stand-in of the freeze's tables: a frozen
# raid boss fight's text written and read back, broken texts dropped, the union by troop, the held
# keys' index, the fight's key asked of the relay, and the end of a frozen fight by its defeated
# pools or its BEATEN marker in the player's or the world's story, or by the end of the fight the
# other side plays in its stead, and the end written as the fight's key and read from it, final for
# the world: no note, take or merge brings a fight back that ended, nor the fight the other side
# plays in its stead.

require_relative "support"

# Stands in for the mod's log: prints each line.
module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end

# The scripts' clock, which the checks move with $frame.
clock_from { $frame }
$frame = 0

# Stands in for the title scene, whose start forgets the frozen fights.
class Scene_Title; def start; end; end

# Stands in for the game's switches, off unless set.
class Game_Switches; def initialize; @data = []; end; def [](id); @data[id] || false; end; def []=(id, value); @data[id] = value; end; end
# Stands in for the game's variables, 0 unless set.
class Game_Variables; def initialize; @data = []; end; def [](id); @data[id] || 0; end; def []=(id, value); @data[id] = value; end; end

# Stands in for story_state.rbx: writes and reads values as it does.
module MGQ_MpStoryState
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

# Stands in for the world's story: the open world's id and the fights' keys asked of the relay, each
# troop and value in $written.
module MGQ_MpWorldStory
  class << self
    attr_accessor :world_id
  end

  # Notes a fight's key asked of the relay.
  #
  # @param troop [Integer] The troop.
  # @param text [String] The value.
  # @return [Boolean] Whether it goes to the relay, always.
  def self.write_freeze(troop, text)
    $written << [troop, text]
    true
  end
end
MGQ_MpWorldStory.world_id = "w1"
$written = []

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
# Stands in for battles_raid_freeze.rbx's tables, which the DLL's events database answers: the
# fights each side plays in the other's stead, Sonya Mazda (868) and Mainyu (869) among them.
module MGQ_MpRaidFreeze
  # Reads a table.
  def self.data(name, default); name == :ALTERNATIVES ? { 672 => [673], 673 => [672], 868 => [869], 869 => [868] } : default; end
end
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

# Writes a fight's key as the relay keeps it: the entry's text after its troop.
#
# @param entry [Hash] The entry.
# @return [String] The value.
def key_of(entry)
  MGQ_MpWorldFreeze.encode_entry(entry).split("|", 2)[1]
end

# Text: every free text escaped, so separators inside names and values never break the key.
odd = entry_of(868, [[1, 1075, 14], [1, 2001, "a|b;c,d:e%f~g=h.i ü"], [1, 2002, 1.5], [1, 2003, -7], [0, 31, false], [0, 32, true],
                     [2, [138, 13, "A"], false], [2, [138, 14, "B|;"], true]], "$Sonya!|;,:%~=.ソニア")
text = freeze.encode_entry(odd)
check("a frozen fight's text holds no separator inside its free texts",
      [text.count(";"), text.count("|"), text.include?("ソ"), text.include?("~g")], [0, 8, false, false])
read = freeze.decode_entry(text)
check("and reads back as written: UTF-8, $ and ! names, self switch keys, string and float values", read, odd)
check("its names come back as UTF-8", read["tableau"][1][0][5].encoding, Encoding::UTF_8)
check("an escaped text has only the plain bytes and %XX", freeze.escape("a-b_c$d!e f.g"), "a-b_c$d!e%20f%2Eg")

# Broken texts and unknown troops are dropped.
good = freeze.encode_entry(entry_of(870, [[1, 1075, 16]]))
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
  good.sub("255:0:1:1:1,", "255:0:1:0:1,"),
]
check("broken texts, troops that are no boss and tableaus without exactly one boss row are dropped, the good one read",
      [broken.map { |each| freeze.decode_entry(each) }.compact, freeze.decode_entry(good)["troop"]], [[], 870])

# The player's own frozen fight: noted, indexed, and its key asked of the relay.
noted = freeze.note(entry_of(868, [[1, 1075, 14], [0, 31, false], [2, [138, 13, "A"], false], [1, 2004, [1, 2]]]).merge("state" => "frozen", "frames" => []))
check("noting the player's frozen fight asks the relay to keep its key for the world",
      [noted, $written], [true, [[868, key_of(entry_of(868, [[1, 1075, 14], [0, 31, false], [2, [138, 13, "A"], false]]))]]])
check("whose entry leaves the record's own fields and a list value the story cannot carry out",
      [freeze.entry(868).keys.sort, freeze.held.map { |kind, key, _| [kind, key] }], [%w(held outer scene site spot tableau troop), [[1, 1075], [0, 31], [2, [138, 13, "A"]]]])
check("its held keys are indexed by kind and key",
      [freeze.held_value(1, 1075), freeze.held_value(0, 31), freeze.held_value(2, [138, 13, "A"]), freeze.held_value(1, 1076), freeze.held_value(0, 1075)],
      [[true, 14], [true, false], [true, false], nil, nil])
$written.clear
check("a note that is no entry is refused without a key", [freeze.note("map:1"), freeze.note(entry_of(868, []).merge("site" => "x")), $written], [false, false, []])

# Union by troop: a known fight keeps its fields and gains the keys it lacks, its own value winning.
world = entry_of(868, [[1, 1075, 16], [1, 1076, 3]])
world["spot"] = [138, 1, 1, 2]
other = entry_of(870, [[1, 1075, 18], [0, 33, true]])
other["site"] = "map:728:12:1"
freeze.take_keys(868 => key_of(world), 870 => key_of(other), 999 => "garbage")
check("the world's key of a known fight adds its new keys, the known value winning",
      [freeze.held_value(1, 1075), freeze.held_value(1, 1076), freeze.entry(868)["spot"]], [[true, 14], [true, 3], [138, 30, 10, 8]])
check("a fight the player did not know joins the list after the known ones, one this game cannot read is dropped", freeze.entries.map { |entry| entry["troop"] }, [868, 870])
check("the oldest fight's value wins a key two fights hold", [freeze.held_value(1, 1075), freeze.held_value(0, 33)], [[true, 14], [true, true]])

# The end of a frozen fight: its pools defeated, its marker met in the player's story or the world's.
$pools["Sonya Mazda"] = MGQ_MpRaidPool::Pool.new(0.0, 100, false)
$frame = 100
check("a pool not yet defeated keeps the fight", freeze.entries.map { |entry| entry["troop"] }, [868, 870])
$pools["Sonya Mazda"] = MGQ_MpRaidPool::Pool.new(0.0, 100, true)
$frame = 130
check("its defeat is looked at once a second", freeze.entries.size, 2)
$frame = 161
$written.clear
check("then ends the fight", [freeze.entries.map { |entry| entry["troop"] }, freeze.ended?(entry_of(868, []))], [[870], true])
check("whose keys the next fight takes over or lets go", [freeze.held_value(1, 1075), freeze.held_value(1, 1076), freeze.held_value(0, 31)], [[true, 18], nil, nil])
check("and whose end goes to the relay for the world, with the end of the other side's fight", $written, [[868, "0"], [869, "0"]])
freeze.take_keys(868 => key_of(entry_of(868, [[1, 1075, 14]])))
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

# The end of a fight travels as its key's "0", which the relay keeps in place of the fight, so it
# reaches every game, also those that only read.
$won.clear
Scene_Title.new.start
$written.clear
freeze.take_keys(870 => key_of(entry_of(870, [[1, 1075, 16]])))
check("a game that only reads takes the world's fight", freeze.entries.map { |entry| entry["troop"] }, [870])
freeze.take_keys(870 => "0", 868 => key_of(entry_of(868, [[1, 1076, 2]])))
check("and drops it once the world's story carries its end, taking the other fights", freeze.entries.map { |entry| entry["troop"] }, [868])
check("without asking the relay, since the world's story ends it already", $written, [])
check("the player's own fight against a troop the world ended is refused, for good",
      [freeze.note(entry_of(870, [[1, 1075, 18]])), freeze.final?(870), freeze.entries.map { |entry| entry["troop"] }, $written], [false, true, [868], []])
freeze.take_keys(870 => key_of(entry_of(870, [[1, 1075, 18]])), 868 => key_of(entry_of(868, [[1, 1076, 2]])))
check("as is the world's key of it, which a racing write brought back", freeze.entries.map { |entry| entry["troop"] }, [868])
freeze.world_told([[nil] * 7009 + [true], [], {}])
check("an end this game saw goes to the relay with the other side's", [freeze.entries, $written], [[], [[868, "0"], [869, "0"]]])
freeze.world_told([[], [], {}])
freeze.take_keys(868 => key_of(entry_of(868, [[1, 1076, 2]])))
check("one whose marker the world's story no longer meets stays ended for good",
      [freeze.entries, freeze.final?(868), freeze.final?(869)], [[], true, true])

# The player's own fight ends with the end the world's story carries, and a world's end of one side's
# fight ends the other side's too.
Scene_Title.new.start
freeze.note(entry_of(870, [[1, 1075, 18]]))
freeze.take_keys(870 => "0")
check("the player's own fight ends with the world's end of it",
      [freeze.entries, freeze.held, freeze.note(entry_of(870, [[1, 1075, 18]]))], [[], [], false])
check("a fight not ended is no final one", [freeze.final?(868), freeze.final?(869)], [false, false])
$written.clear
freeze.take_keys(868 => "0")
check("the world's end of Sonya Mazda ends Mainyu too, without asking the relay", [freeze.final?(869), freeze.note(entry_of(869, [[1, 1075, 15]])), freeze.entries, $written], [true, false, [], []])
long = entry_of(870, (1..300).map { |id| [1, 2000 + id, "x" * 200] })
Scene_Title.new.start
$written.clear
check("a fight longer than the relay keeps is never written", [freeze.encode_entry(long), freeze.note(long), $written], [nil, false, []])

# A fight only one side plays also ends with the fight the other side plays in its stead, so a player
# of the other side past it is never held back: Sonya Mazda (868) on Alice's, Mainyu (869) on Ilias's.
check("Sonya Mazda and Mainyu are each other's other side, Sonya Chaos has none",
      [freeze.alternatives(868), freeze.alternatives(869), freeze.alternatives(870)], [[869], [868], []])
Scene_Title.new.start
freeze.note(entry_of(868, [[1, 1075, 14], [0, 2307, true]]))
check("a fight whose other side's fight has not ended holds its keys", freeze.held, [[1, 1075, 14], [0, 2307, true]])
$won << 869
$written.clear
check("an Ilias-side win over Mainyu ends the frozen fight against Mazda at once, both ends going to the relay",
      [freeze.held, freeze.entries, freeze.ended?(entry_of(868, [])), $written], [[], [], true, [[868, "0"], [869, "0"]]])
check("nor is Mazda noted again", freeze.note(entry_of(868, [[1, 1075, 14]])), false)
$won.clear
Scene_Title.new.start
freeze.note(entry_of(868, [[1, 1075, 14]]))
freeze.world_told([[nil] * 7010 + [true], [], {}])
check("the world's story meeting Mainyu's marker ends it too", freeze.entries, [])
freeze.world_told([[], [], {}])
check("for good, Mainyu's fight with it", [freeze.note(entry_of(869, [[1, 1075, 15]])), freeze.entries], [false, []])
Scene_Title.new.start
freeze.note(entry_of(869, [[1, 1075, 15]]))
$game_switches[7009] = true
check("and the other way round, the player's story past Mazda ends a frozen fight against Mainyu", [freeze.held, freeze.entries], [[], []])
$game_switches[7009] = false
