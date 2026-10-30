#----------------------------------------------------------------
#  make_setup_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-30: Created
#
#----------------------------------------------------------------

# Writes the golden cases of a served battle's setup next to this file, setup.json, from
# battles_served.rbx and BattleServer/lib/served.rb as they wrote, read and checked it before that
# moved to C# (commit e2a51fe5, which this generator reads through git, so it runs again on later
# commits): the setup line written from the facts the starter's game collects, the setups read
# back (lines of other formats and fields of the wrong kind among them), the battle server's
# refusals, and the scripts' fingerprint over a few scripts. MGQOnline.Game.Tests replays them.
#
#   ruby fixtures/served/make_setup_fixtures.rb

require "json"
require "tempfile"
require "zlib"
require_relative "../../GameScript/Tests/support"

# The commit whose scripts kept the setup.
SOURCE_COMMIT = "e2a51fe5"

# The log stays quiet; the cases record what the rules did, not their lines.
module MGQ_Multiplayer; module Log; def self.write(_line); end; end; end

# The game's classes the battle line codec names.
class Game_Battler; end
# An action.
class Game_Action; end
# An action's result.
class Game_ActionResult; end
# A color.
class Color; end
# A tone.
class Tone; end
# An equipped item.
class Game_BaseItem; end
# The database's entries.
module RPG; class BaseItem; end; class Skill < BaseItem; end; class Item < BaseItem; end; class State < BaseItem; end; class Weapon < BaseItem; end; class Armor < BaseItem; end; end

# Stands in for the live battle.
module MGQ_MpBattlesSync; def self.log_once(_key, _text); end; end
# Stands in for the world's sync.
module MGQ_MpOverworldSync
  # The player's own state.
  module Me; def self.seat; $facts["starter"]; end; end
  # Takes a block run as a player leaves.
  def self.on_leave(&_block); end
end
# Stands in for the co-op battles: the players as they read them, the rates and the enemies.
module MGQ_MpBattlesCoop
  # A player of the battle; reading players hands their fields on as they came.
  Player = Struct.new(:seat, :name, :builds, :vitals, :max, :order, :front, :bench) do
    # Reads players: their fields as they came.
    def self.read_all(list); Array(list); end
  end
  # The enemies' rates.
  def self.rates_text; $facts["rates"]; end
  # The troop's enemies.
  def self.troop_entries; $facts["enemies"]; end
  # Whether the battle is a Raid World's.
  def self.raid?; $facts["raid"]; end
end
# Stands in for the world: its squad rules and game data.
module MGQ_MpWorld
  # The world's squad rules.
  def self.squad; $facts["squad"] && Hash[$facts["squad"].map { |key, value| [key.to_sym, value] }]; end
  # Reads squad rules as the DLL answers them.
  def self.squad_from(rules); rules; end
  # The game data's fingerprint.
  module GameData; def self.fingerprint; $facts["data"]; end; end
end
# Stands in for the raid pools' fields of the battle.
module MGQ_MpRaidPool; def self.served_fields; $facts["pool"]; end; end
# Stands in for the tiers' fight of the battle.
module MGQ_MpRaidTiers; def self.fight; $facts["tiers"]; end; end
# Stands in for the world's mods.
module MGQ_MpWorldMods; def self.served_mods; $facts["mods"]; end; def self.served_settings; $facts["settings"]; end; end
# Stands in for the game's state the setup reads.
module MGQ_MpGame; def self.get(_object, field); $facts[field.to_s.sub("can_", "")]; end; end
# Stands in for the battle manager.
module BattleManager; end
# The game's switches, as the game keeps them.
class Game_Switches; def initialize(on); @data = []; on.each { |id| @data[id] = true }; end; end
# The game's variables, as the game keeps them.
class Game_Variables; def initialize(set); @data = []; set.each { |id, value| @data[id] = value }; end; end
# The troop.
class Game_Troop; def troop; Struct.new(:id).new($facts["troop"]); end; end
# The map.
class Game_Map; def map_id; $facts["map"]; end; end
# Answers the squad rules a setup carries as they cross, see MGQ_MpBattlesServed.squad_of.
module MGQ_Multiplayer; module Bridge; def self.call(_topic, pairs = nil); pairs; end; end; end

# Loads a file of the source commit.
#
# @param path [String] Its path in the repository.
def load_old(path)
  source = `git -C "#{File.expand_path('../..', __dir__)}" show #{SOURCE_COMMIT}:#{path}`
  raise "git could not read #{path} of #{SOURCE_COMMIT}" if source.empty?

  script = Tempfile.new([File.basename(path, ".*"), File.extname(path)])
  script.write(source)
  script.close
  load script.path
end

load File.join(SCRIPTS_DIR, "core_log.rbx")
load_old("GameScript/Multiplayer/Scripts/battles_sync_wire.rbx")
load_old("GameScript/Multiplayer/Scripts/battles_served.rbx")
SERVED = MGQ_MpBattlesServed
WIRE = MGQ_MpBattlesSync::Wire

# The facts a starter collects for a battle, as the C# writer takes them: a Float or a Symbol
# tagged, as battles_served.rbx's plain_fact hands them over.
FACTS = [
  { "scripts" => "0badf00d", "data" => "1:data", "troop" => 40, "escape" => true, "lose" => false, "map" => 5, "rates" => "100,100,0",
    "enemies" => [[31, 320, 300, 0], [32, 400, 310, 1]], "players" => [[0, "Me", "1,2,3", [[100, 50]], 8, 0, 3, 1], [2, "Friend\tTab", "7", [], 8, 1, 2, 0]],
    "level" => 30, "switches" => [12, 4001], "variables" => [[150, 3], [1003, -2]], "raid" => true,
    "pool" => [1, 0, [["Queen Harpy", "0.5000000000", 6000, 0, ""], ["Ilias#1", "0.0000000000", 9000, 1, "Hero"]]], "tiers" => false,
    "starter" => 0, "squad" => [["luka", false], ["formation", 4], ["front", 2], ["raid_front", 1]],
    "mods" => [["teamboostfix", "upload", "1.0", [["Team_Boost_Fix.rb", "a" * 64]]]], "settings" => "mod_rate=i:2" },
  { "scripts" => "", "data" => "", "troop" => 7, "escape" => false, "lose" => true, "map" => 0, "rates" => "", "enemies" => [], "players" => [[3, "Solo", "", [], 4, 0, 4, 0]],
    "level" => nil, "switches" => [], "variables" => [], "raid" => false, "pool" => nil, "tiers" => true, "starter" => 3, "squad" => nil, "mods" => [], "settings" => "" },
  { "scripts" => "0badf00d", "data" => "1:data", "troop" => 41, "escape" => false, "lose" => false, "map" => 9, "rates" => "",
    "enemies" => [[31, { "float" => "320.5" }, 300, 0]], "players" => [[0, "Me", "1", [[{ "float" => "0.25" }, { "symbol" => "guard" }]], 8, 0, 1, 0]],
    "level" => nil, "switches" => [], "variables" => [], "raid" => false, "pool" => nil, "tiers" => false, "starter" => 0, "squad" => nil, "mods" => [], "settings" => "" },
]

# Turns tagged facts back into the values the starter's game held.
#
# @param value [Object] A fact as FACTS holds it.
# @return [Object] The fact with its Floats and Symbols.
def held(value)
  case value
  when Array then value.map { |item| held(item) }
  when Hash
    if value.keys == ["float"] then value["float"].to_f
    elsif value.keys == ["symbol"] then value["symbol"].to_sym
    else value.each_with_object({}) { |(key, item), out| out[key] = held(item) }
    end
  else value
  end
end

writes = FACTS.map do |facts|
  $facts = held(facts)
  $game_switches = Game_Switches.new(facts["switches"])
  $game_variables = Game_Variables.new(facts["variables"])
  $game_troop = Game_Troop.new
  $game_map = Game_Map.new
  SERVED.instance_variable_set(:@scripts_fingerprint, facts["scripts"])
  players = $facts["players"].map { |fields| MGQ_MpBattlesCoop::Player.new(*fields) }
  { "facts" => facts, "line" => SERVED.setup_text(players, facts["level"]) }
end

# Describes a setup as read_setup reads it, as plain values.
#
# @param setup [Hash, nil] The setup.
# @return [Hash, nil] Its fields by name.
def plain(setup)
  setup && setup.each_with_object({}) { |(key, value), out| out[key.to_s] = key == :squad && value ? value.to_a : value }
end

# The setup with Floats and a Symbol is a write case alone: C# reads them as nil, since the bridge
# carries neither back, and the scripts take only Integers of those fields.
lines = writes.first(2).map { |write| write["line"] } + [
  WIRE.line([2, "", "", 40]),
  WIRE.line([1, "", "", "40"]),
  "",
  WIRE.line([1, 5, nil, 40, 1, 2, "9", 7, "x", ["bad", [4], [5, "Five"]], -1, [0, 3, "4", 2], [[1, 2], [3], ["4", 5], [6, 7, 8]], 1, "pool", 1, "0",
             [["luka", true], ["front", "2"], ["x"], [3, 4]], [["k", "", "1.0", [["a.rb", "b" * 64], ["c.rb", "short"], [1, "d"]]], ["", "x", "1", []], "junk", ["n", "t", "v", "notfiles"]], 5]),
]
reads = lines.map { |line| { "line" => line, "setup" => plain(SERVED.read_setup(line)) } }

# The battle server's check: what it refuses of a setup, with the server's fingerprints and
# whether the setup's troop has enemies in the server's database.
checks = []
[[writes[0]["line"], "0badf00d", "1:data", true], [writes[0]["line"], "other", "1:data", true], [writes[0]["line"], "0badf00d", "other", true],
 [writes[0]["line"], "0badf00d", "1:data", false], [WIRE.line([1, "s", "d", 40, 0, 0, 0, "", [], [], 0, [], [], 0, nil, 0, 0]), "s", "d", true],
 [WIRE.line([1, "s", "d", 40, 0, 0, 0, "", [], [[0, "A"], [0, "B"]], 0, [], [], 0, nil, 0, 0]), "s", "d", true],
 [WIRE.line([1, "s", "d", 40, 0, 0, 0, "", [], [[0, "A"], [32, "B"]], 0, [], [], 0, nil, 0, 0]), "s", "d", true],
 [WIRE.line([1, "s", "d", 40, 0, 0, 0, "", [], [[0, "A"], [1, "B"]], 0, [], [], 0, nil, 0, 5]), "s", "d", true],
 [WIRE.line([1, "s", "d", -1, 0, 0, 0, "", [], [[0, "A"]], 0, [], [], 0, nil, 0, 0]), "s", "d", true],
 ["", "s", "d", true]].each do |line, scripts, data, enemies|
  setup = SERVED.read_setup(line)
  # The game's Player.read drops a player whose seat is no number.
  players = setup ? setup[:players].select { |fields| Array(fields)[0].is_a?(Integer) } : []
  refusal =
    if !setup then ["setup", "a setup of another format"]
    elsif setup[:scripts] != scripts then ["scripts", "the starter's MGQ Online differs from the server's"]
    elsif setup[:data] != data then ["data", "the starter's game data differs from the server's"]
    elsif !(setup[:troop].positive? && enemies) then ["setup", "troop #{setup[:troop]} has no enemies"]
    elsif players.empty? then ["setup", "a battle without players"]
    elsif (seats = players.map { |fields| fields[0] }).uniq.size != seats.size || !seats.all? { |seat| seat.is_a?(Integer) && (0..31).cover?(seat) }
      ["setup", "players on seats #{seats.inspect}, not distinct world seats"]
    elsif !seats.include?(setup[:starter]) then ["setup", "the starter on seat #{setup[:starter].inspect} is none of the players"]
    end
  checks << { "line" => line, "scripts" => scripts, "data" => data, "troop_enemies" => enemies, "refusal" => refusal }
end

# The scripts' fingerprint as scripts_fingerprint chains it, over texts with line ends of both kinds.
scripts = [["core_log", "# log\r\nmodule A\r\nend\r\n"], ["battles_served", "module MGQ_MpBattlesServed\n  FORMAT = 1\nend\n"], ["battles_raid_pool", "puts 'アリス'\r\n".b]]
sum = 0
scripts.each { |name, text| sum = Zlib.crc32(name + "\n" + text.b.delete("\r"), sum) }
fingerprint = { "scripts" => scripts.map { |name, text| [name, text.b.unpack1("H*")] }, "fingerprint" => format("%08x", sum), "empty" => format("%08x", 0) }

File.write(File.join(__dir__, "setup.json"), JSON.pretty_generate("source" => SOURCE_COMMIT, "writes" => writes, "reads" => reads, "checks" => checks, "fingerprint" => fingerprint) + "\n")
puts "wrote setup.json"
