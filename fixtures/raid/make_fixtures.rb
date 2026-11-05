#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Gave the recorded frozen fights a boss's stand-in and handed each step its own copy of a fight
#                            - Created
#
#----------------------------------------------------------------

# Writes the golden cases of a Raid World's raid boss rules next to this file, rules.json, from the
# scripts as they decided them before the rules moved to C# (commit 2d8ef2e7, which this generator
# reads through git, so it runs again on later commits): battles_raid_bosses.rbx's names, tiers and
# last phases, battles_raid_pool.rbx's beaten markers, refusals and kinds of battle,
# battles_raid_tiers.rbx's refusals and kinds outside Raid Worlds, world_freeze.rbx's list of the
# world's frozen fights, and battles_raid_freeze.rbx's refusal of a lost battle's undo and the values
# the undo writes. Each case names the story values, the map and the troop sizes it was decided
# over. MGQOnline.Game.Tests replays them against the C# rules.
#
#   ruby fixtures/raid/make_fixtures.rb

require "json"
require "tempfile"
require_relative "../../GameScript/Tests/support"

# The commit whose scripts decided the rules.
SOURCE_COMMIT = "2d8ef2e7"

# The log stays quiet; the cases record what the rules did, not their lines.
module MGQ_Multiplayer; module Log; def self.write(_line); end; end; end

# Stands in for the world's sync, which the scripts register with as they load.
module MGQ_MpOverworldSync
  # The field of the relay's push of the raid bosses setting.
  RAID_BOSSES_FIELD = "raid_bosses"
  # Takes a route.
  def self.route(_field, &_block); end
  # Takes a block to run each frame.
  def self.on_tick(&_block); end
  # Takes a block of the player's state fields.
  def self.state_fields(&_block); end
  # Whether a world is open, as a case sets it.
  def self.in_world?; $in_world; end
end
# Stands in for the world type, as a case sets it.
module MGQ_MpCoop; module Scope; def self.raid?; $raid; end; end; end
# Stands in for a Classic world's setting.
module MGQ_MpWorld; def self.raid_bosses?; $world_bosses; end; end
# Stands in for the world's story.
module MGQ_MpWorldStory
  def self.active?; true; end
  def self.mode; :world; end
  def self.world_id; "w1"; end
  # Notes what the world's list asks the relay to keep.
  def self.write_freeze(troop, entry); ($writes ||= []) << [troop, entry == false ? false : entry["troop"]]; true; end
  # Reports whether a value is the player's own: a case names those.
  def self.personal?(kind, key); ($personal || []).include?([kind, key]); end
  # Compares values as the story does.
  def self.same?(kind, one, other)
    return (one.nil? ? 0 : one) == (other.nil? ? 0 : other) if kind == 1

    (one ? true : false) == (other ? true : false)
  end
end
# Stands in for the story's keys: every value is plain.
module MGQ_MpStoryKeys; def self.plain_of(_kind, value); value; end; def self.game_value(_kind, value); value; end; end
# Stands in for the player's settings.
module MGQ_Multiplayer; module Player; def self.setting(_name); $sp_bosses; end; def self.store(_name, _value); end; end; end
# Stands in for the chat log and the notices.
module MGQ_MpChat; def self.system(_text); end; end
module MGQ_MpNotices; def self.message(_key, _text, _frames); end; end
# Stands in for the scenes, which the scripts hook.
module SceneManager; def self.run; end; def self.scene; nil; end; end
class Scene_Title; def start; end; end
class Scene_Map; def update; end; end
class Scene_Battle; end
# Stands in for the battles, which the scripts hook.
module BattleManager
  def self.setup(*_args); end
  def self.battle_end(_result); end
  def self.process_defeat; end
  def self.memory_battle?; $memory; end
end
module DataManager; def self.extract_save_contents(_contents); end; end
# Stands in for the map and its interpreter.
class Game_Interpreter
  attr_accessor :event_id
  def command_301; end
  def command_117; end
  def setup(_list, _event_id = 0); end
end
class Game_Map
  attr_accessor :map_id, :interpreter
  def update_interpreter; end
  def setup_starting_map_event; end
end
class Game_Player; def perform_transfer; end; end
class Game_Switches; def []=(_id, _value); end; end
class Game_Variables; def []=(_id, _value); end; end
class Game_SelfSwitches; def []=(_key, _value); end; end
module Graphics; def self.update; end; end
# Stands in for the troop the battle fights.
class Game_Troop; attr_accessor :troop_id; end
# A troop of the database: only its members' count matters.
DataTroop = Struct.new(:members)
# A member of a troop.
DataMember = Struct.new(:enemy_id)

# Loads a script of the source commit.
#
# @param name [String] The script's name without its extension.
def load_old(name)
  source = `git -C "#{File.expand_path('../..', __dir__)}" show #{SOURCE_COMMIT}:GameScript/Multiplayer/Scripts/#{name}.rbx`
  raise "git could not read #{name}.rbx of #{SOURCE_COMMIT}" if source.empty?

  script = Tempfile.new([name, ".rbx"])
  script.write(source)
  script.close
  %w(core_log core_hooks core_game_access).each { |core| load File.join(SCRIPTS_DIR, "#{core}.rbx") } unless defined?(MGQ_MpGame)
  load_bridge unless defined?(MGQ_Multiplayer::Bridge)
  load script.path
end

%w(battles_raid_bosses).each { |name| load_old(name) }
load_story_ids
%w(battles_raid_pool battles_raid_tiers world_freeze battles_raid_freeze).each { |name| load_old(name) }
BOSSES = MGQ_MpRaidBosses
POOL = MGQ_MpRaidPool
TIERS = MGQ_MpRaidTiers
WORLD = MGQ_MpWorldFreeze
FREEZE = MGQ_MpRaidFreeze

# The DLL's reading of an entry keeps every field the cases use.
WORLD.define_singleton_method(:clean) { |entry| entry.is_a?(Hash) ? entry : nil }

# The troop sizes every case is decided over: each boss troop has one enemy but these.
SIZES = { 1592 => 2, 1599 => 2, 2016 => 1, 870 => 1, 1675 => 2, 607 => 1, 610 => 2 }.freeze
$data_enemies = Hash.new { |_hash, _id| true }
$data_troops = Hash.new { |_hash, troop| DataTroop.new([DataMember.new(1)] * SIZES.fetch(troop, 1)) }

# The alternatives the freeze's tables name: the two Sonya fights stand for each other.
ALTERNATIVES = { 868 => [869], 869 => [868] }.freeze
FREEZE.instance_variable_set(:@tables, { :ALTERNATIVES => ALTERNATIVES, :DEFEAT_WRITES => { :switches => [31..39], :variables => [9] }, :EXCLUDED_MAPS => [154, 576] })

# Sets the story values, the map and the world a case decides over.
#
# @param facts [Hash] "map", "switches" ({id => true}) and "variables" ({id => value}), all optional.
def take(facts)
  $game_switches = Hash.new(false).merge(Hash[(facts["switches"] || {}).map { |id, on| [id.to_i, on] }])
  $game_variables = Hash.new(0).merge(Hash[(facts["variables"] || {}).map { |id, value| [id.to_i, value] }])
  $game_map = Game_Map.new
  $game_map.map_id = facts["map"] || 1
  $game_map.interpreter = Game_Interpreter.new
  $game_map.interpreter.event_id = facts.key?("event") ? facts["event"] : 7
  $game_troop = Game_Troop.new
end

# Writes the facts a case was decided over as the C# replay reads them.
#
# @param facts [Hash] The facts, see take.
# @return [Hash] The facts with every field.
def facts_of(facts)
  { "map" => facts["map"] || 1, "switches" => facts["switches"] || {}, "variables" => facts["variables"] || {} }
end

# A story at the start of the game.
FRESH = {}.freeze

# Names, tiers, keys and last phases of troops whose rows differ in kind: a phase before the last,
# a last phase, Salamander's on Luka's side, a skirmish's troop, a milestone two caps share, the
# Great Decision, a fight of several of one milestone, the final boss, a Chaos Domain boss, a troop
# of several enemies, and a troop that is no boss.
NAME_TROOPS = [26, 29, 751, 752, 812, 1502, 1807, 1507, 2016, 2219, 2549, 1599, 870, 1000].freeze

names = NAME_TROOPS.map do |troop|
  last = [{ "map" => 1 }, { "map" => 1, "switches" => { "4" => true } }, { "map" => 723 }].map { |facts| take(facts); BOSSES.last_phase?(troop) }
  take(FRESH)
  {
    "troop" => troop, "boss" => BOSSES.boss?(troop), "milestone" => (boss = BOSSES.at(troop)) && boss.milestone, "cap" => boss && boss.cap,
    "name" => BOSSES.milestone_key(troop), "tier" => BOSSES.tier(troop), "title" => BOSSES.title(troop), "section" => BOSSES.section(troop),
    "key" => POOL.key_of(troop), "keys" => POOL.troop_keys(troop), "factors" => Hash[[:mhp, :def, :mdf, :atk].map { |stat| [stat.to_s, BOSSES.factor(troop, stat)] }],
    "last" => last,
  }
end

# Story states from the start to past the end, each with the level caps of the milestones it beat:
# together they meet every beaten marker at least once.
CAP_STORIES = [
  FRESH,
  { "variables" => { "1003" => 8, "1011" => 4, "1001" => 17, "1023" => 2 } },
  { "variables" => { "1001" => 28, "1028" => 7, "1056" => 4, "1070" => 3, "1074" => 2 }, "switches" => { "2090" => true, "7001" => true, "2268" => true } },
  { "variables" => { "1001" => 37, "1069" => 9, "1141" => 30 }, "switches" => { "2261" => true, "7015" => true, "2485" => true, "2487" => true } },
  { "variables" => { "1001" => 40, "1142" => 36, "1169" => 23 }, "switches" => { "2594" => true, "7097" => true } },
  { "variables" => { "1001" => 40, "1142" => 25 } },
  { "variables" => { "1143" => 18, "1319" => 7, "1328" => 6, "1331" => 5, "1329" => 4, "1332" => 5, "1326" => 4, "1373" => 13 },
    "switches" => { "3030" => true, "3031" => true, "3032" => true, "3033" => true, "3079" => true, "3078" => true, "7039" => true } },
  { "variables" => { "1328" => 6, "1331" => 5, "1329" => 4, "1332" => 5 }, "switches" => { "3030" => true, "3031" => true, "3032" => true, "3079" => true, "3078" => true, "3077" => true } },
].freeze

# A story past the final boss made the script fail: Chaos has no cap, which the sort cannot place,
# so such a case records the error.
caps = CAP_STORIES.map do |facts|
  take(facts)
  begin
    { "facts" => facts_of(facts), "caps" => POOL.beaten_caps([$game_switches, $game_variables]) }
  rescue ArgumentError => e
    { "facts" => facts_of(facts), "caps" => nil, "raised" => e.message }
  end
end

# The refusals of story boss battles, a Raid World's and outside one: no boss, an earlier phase,
# the Great Decision, a Hades rematch by its switch and by its hall, a Colosseum battle, a milestone
# the story beat, a skirmish, Salamander on either side, and fights that count.
REFUSALS = [
  [1000, FRESH], [26, FRESH], [29, FRESH], [1507, FRESH], [1509, { "variables" => { "1141" => 1 } }],
  [71, { "switches" => { "97" => true } }], [71, { "map" => 576 }], [71, { "switches" => { "87" => true } }],
  [71, { "variables" => { "1011" => 4 } }], [71, { "variables" => { "1011" => 3 } }], [812, { "map" => 723 }], [812, { "map" => 724 }],
  [751, FRESH], [751, { "switches" => { "4" => true } }], [2016, FRESH], [2016, { "switches" => { "3030" => true } }],
  [2016, { "switches" => { "3030" => true, "3031" => true, "3032" => true, "3033" => true } }], [2549, FRESH], [870, { "variables" => { "1001" => 33 } }],
  [870, { "variables" => { "1001" => 34 } }], [1599, FRESH],
].freeze

refusals = REFUSALS.map do |troop, facts|
  take(facts)
  POOL.instance_variable_set(:@at_command, true)
  POOL.instance_variable_set(:@in_map, true)
  $raid = true
  boss = BOSSES.at(troop)
  case_of = {
    "troop" => troop, "facts" => facts_of(facts), "pool" => POOL.refusal(troop), "tiers" => TIERS.refusal(troop),
    "pooled" => POOL.pooled_troop?(troop), "beaten" => boss ? POOL.beaten?(boss) : false, "won_at_once" => POOL.story_won?(troop),
  }
  POOL.instance_variable_set(:@at_command, false)
  POOL.instance_variable_set(:@in_map, false)
  case_of
end

# The kinds of a battle about to be set up in a Raid World: an event's story boss battle, one a
# common event of its own starts, one outside the map's interpreter, a side battle, a host's invite,
# the game's retry of a lost one and of a lost side battle, and a refused one.
POOL_KINDS = [
  ["an event's story boss battle", 71, {}],
  ["a common event of its own", 71, { "event" => 0 }],
  ["outside the map's interpreter", 71, { "in_map" => false }],
  ["a refused story boss battle", 26, {}],
  ["a side battle", 71, { "side" => 71, "at_command" => false }],
  ["a host's invite", 71, { "invited" => [71, 1, false], "at_command" => false }],
  ["a host's invite to a side battle", 71, { "invited" => [71, 1, true], "at_command" => false }],
  ["an invite to another troop", 71, { "invited" => [126, 1, false], "at_command" => false }],
  ["the retry of a lost battle", 71, { "retrying" => true, "lost" => [71, false], "at_command" => false }],
  ["the retry of a lost side battle", 71, { "retrying" => true, "lost" => [71, true], "at_command" => false }],
  ["the retry of another troop's battle", 71, { "retrying" => true, "lost" => [126, false] }],
].freeze

# A lost battle as the kinds read it.
LostFight = Struct.new(:troop, :side, :own)

pool_kinds = POOL_KINDS.map do |name, troop, state|
  take("event" => state.key?("event") ? state["event"] : 7)
  $raid = true
  POOL.instance_variable_set(:@at_command, state.fetch("at_command", true))
  POOL.instance_variable_set(:@in_map, state.fetch("in_map", true))
  POOL.instance_variable_set(:@side, state["side"])
  POOL.instance_variable_set(:@invited, state["invited"])
  POOL.instance_variable_set(:@retrying, state["retrying"] ? true : false)
  POOL.instance_variable_set(:@lost, state["lost"] && LostFight.new(state["lost"][0], state["lost"][1], 1))
  kind = POOL.kind_of(troop)
  POOL.forget rescue nil
  { "name" => name, "troop" => troop, "state" => state, "kind" => kind && kind.to_s }
end

# The kinds of a battle outside Raid Worlds: an event's story boss battle with raid bosses on and
# off, one a common event of its own starts, an invite, the retry of a lost one, and any in a Raid
# World.
TIER_KINDS = [
  ["raid bosses on", 71, { "active" => true }],
  ["raid bosses off", 71, { "active" => false }],
  ["a common event of its own", 71, { "active" => true, "event" => 0 }],
  ["a refused story boss battle", 26, { "active" => true }],
  ["an invite", 71, { "active" => false, "invited" => 71, "at_command" => false }],
  ["the retry of a lost battle", 71, { "active" => false, "retrying" => true, "lost" => 71, "at_command" => false }],
  ["in a Raid World", 71, { "active" => true, "raid" => true }],
].freeze

tier_kinds = TIER_KINDS.map do |name, troop, state|
  take("event" => state.key?("event") ? state["event"] : 7)
  $raid = state["raid"] ? true : false
  $in_world = true
  $world_bosses = state["active"]
  TIERS.forget
  TIERS.instance_variable_set(:@at_command, state.fetch("at_command", true))
  TIERS.instance_variable_set(:@in_map, true)
  TIERS.instance_variable_set(:@invited, state["invited"])
  TIERS.instance_variable_set(:@retrying, state["retrying"] ? true : false)
  TIERS.instance_variable_set(:@lost, state["lost"] && MGQ_MpRaidTiers::Fight.new(state["lost"], 1, 4))
  kind = TIERS.kind_of(troop)
  { "name" => name, "troop" => troop, "state" => state, "kind" => kind && kind.to_s }
end
$raid = true
$in_world = false

# An entry of the world's frozen fights.
#
# @param troop [Integer] The troop.
# @param held [Array<Array>] Its held keys, each kind, key and value.
# @return [Hash] The entry.
def entry(troop, held)
  { "troop" => troop, "site" => ["map", 138, 13, 1], "outer" => ["map", 138, 13, 1], "scene" => false, "tableau" => [138, [[13, 32, 8, 2, 1, "$sonya", 0, 0, 255, 0, 1, 1, 1]], [13]], "spot" => [138, 5, 6, 2],
    "held" => held }
end

# Runs one step on the world's list of frozen fights.
#
# @param step [Hash] The step: "op" with "note" ("entry"), "take" ("keys", {troop => entry or
#   false}), "told" ("facts" of the world's story), "won" ("troop"), "pool" ("key", "defeated") or
#   "story" ("facts" of the player's story).
# @return [Object] What the list answered: whether it holds a noted fight.
def world_step(step)
  case step["op"]
  when "note" then WORLD.note(Marshal.load(Marshal.dump(step["entry"])))
  when "take" then WORLD.take_keys(Hash[Marshal.load(Marshal.dump(step["keys"])).map { |troop, value| [troop.to_i, value] }])
  when "told"
    take_told = Hash.new(false).merge(Hash[(step["facts"]["switches"] || {}).map { |id, on| [id.to_i, on] }])
    told_values = Hash.new(0).merge(Hash[(step["facts"]["variables"] || {}).map { |id, value| [id.to_i, value] }])
    WORLD.world_told([take_told, told_values, {}])
  when "won" then (FREEZE.instance_variable_get(:@won) || FREEZE.instance_variable_set(:@won, {}))[step["troop"]] = true
  when "pool" then POOL.instance_variable_get(:@pools)[step["key"]] = POOL::Pool.new(0.0, 1000, step["defeated"], "Hero", Time.now)
  when "story" then take(step["facts"])
  end
end

# Plays a scenario on a fresh list.
#
# @param name [String] What it shows.
# @param steps [Array<Hash>] Its steps, see world_step.
# @return [Hash] The scenario with what each step left: the entries' troops, the held keys, the
#   fights ended for good and what the list asked the relay to keep.
def world_scenario(name, steps)
  take(FRESH)
  WORLD.forget
  WORLD.instance_variable_set(:@world_id, "w1")
  FREEZE.forget
  POOL.instance_variable_set(:@pools, {})
  played = steps.map do |step|
    $writes = []
    answer = world_step(step)
    WORLD.instance_variable_set(:@checked_at, nil)
    entries = WORLD.entries
    step.merge("answer" => step["op"] == "note" ? answer : nil, "entries" => entries.map { |each| each["troop"] }, "held" => WORLD.held,
               "ended" => WORLD.instance_variable_get(:@ended).keys.sort, "writes" => $writes)
  end
  { "name" => name, "steps" => played }
end

WORLD_SCENARIOS = [
  world_scenario("a noted fight holds its keys for the world, an older fight's value winning a key two hold",
                 [{ "op" => "note", "entry" => entry(71, [[1, 1011, 3], [0, 31, true]]) },
                  { "op" => "note", "entry" => entry(126, [[1, 1011, 5], [1, 1019, 2]]) },
                  { "op" => "note", "entry" => entry(71, [[1, 1003, 4], [1, 1011, 9]]) }]),
  world_scenario("a fight ends once its pools are defeated, the player won it, or a story beat it, for good",
                 [{ "op" => "note", "entry" => entry(71, [[1, 1011, 3]]) }, { "op" => "note", "entry" => entry(126, [[1, 1019, 2]]) },
                  { "op" => "note", "entry" => entry(212, [[1, 1001, 16]]) }, { "op" => "note", "entry" => entry(299, [[1, 1001, 17]]) },
                  { "op" => "pool", "key" => "Queen Harpy", "defeated" => true }, { "op" => "won", "troop" => 126 },
                  { "op" => "story", "facts" => { "variables" => { "1001" => 17 } } },
                  { "op" => "told", "facts" => { "variables" => { "1001" => 18 } } },
                  { "op" => "note", "entry" => entry(71, [[1, 1011, 3]]) }]),
  world_scenario("the other side's fight ends a fight with it, and the world's ends come for good",
                 [{ "op" => "note", "entry" => entry(868, [[1, 1075, 16]]) }, { "op" => "story", "facts" => { "switches" => { "7010" => true } } },
                  { "op" => "story", "facts" => {} }, { "op" => "take", "keys" => { "870" => false, "71" => entry(71, [[1, 1011, 3]]) } },
                  { "op" => "take", "keys" => { "870" => entry(870, [[1, 1001, 33]]), "1000" => entry(1000, [[1, 1, 1]]) } }]),
].freeze

# The defeats of raid boss battles: one the undo puts back, and the reasons it puts nothing back.
DEFEATS = [
  ["a lost event battle that froze", { :kind => :event, :record => true, :undo => true }, {}],
  ["a lost event battle whose record was refused", { :kind => :event, :record => false, :undo => true }, {}],
  ["a lost side battle", { :kind => :side, :record => false, :undo => true }, {}],
  ["a lost battle of no pool", { :kind => nil, :record => false, :undo => true }, {}],
  ["another troop fights", { :kind => :event, :record => true, :undo => true }, { "troop_now" => 126 }],
  ["the event goes on after a defeat", { :kind => :event, :record => true, :undo => true }, { "can_lose" => true }],
  ["a replay of the Library", { :kind => :event, :record => true, :undo => true }, { "memory" => true }],
  ["a Hades rematch", { :kind => :event, :record => true, :undo => true }, { "switches" => { "97" => true } }],
  ["a Colosseum battle", { :kind => :event, :record => true, :undo => true }, { "switches" => { "87" => true } }],
  ["a Hades hall", { :kind => :event, :record => true, :undo => true }, { "map" => 154 }],
  ["the story at its event's start is unknown", { :kind => :event, :record => false, :undo => false }, {}],
  ["no Raid World's story", { :kind => :event, :record => true, :undo => true }, { "raid" => false }],
].freeze

defeats = DEFEATS.map do |name, battle, state|
  take(state)
  $raid = state.fetch("raid", true)
  $game_troop.troop_id = state["troop_now"] || 71
  $memory = state["memory"] ? true : false
  BattleManager.instance_variable_set(:@can_lose, state["can_lose"] ? true : false)
  reason = FREEZE.defeat_refusal(battle.merge(:troop => 71))
  $raid = true
  { "name" => name, "battle" => { "kind" => battle[:kind] && battle[:kind].to_s, "record" => battle[:record], "undo" => battle[:undo] },
    "state" => state, "refusal" => reason }
end

# The values a defeat's undo writes, each changed key: one the event changed before the battle
# goes back to its value then, the post-defeat processing's own and the player's own stay, a self
# switch goes back to the defeat's start.
UNDO_ROWS = [[1, 1011, 3, 0], [1, 1075, 14, 16], [0, 31, false, true], [1, 9, 0, 5], [1, 1050, 2, 3], [2, [138, 13, "A"], true, nil]].freeze
UNDO_START = [[1, 1075, 12]].freeze
UNDO_PERSONAL = [[1, 1050]].freeze

$personal = UNDO_PERSONAL
written = []
FREEZE.singleton_class.send(:define_method, :write_value) { |kind, key, value| written << [kind, key, value] }
FREEZE.singleton_class.send(:define_method, :changed_since) { |_mark, _starts = nil| UNDO_ROWS.map { |row| row.dup } }
FREEZE.singleton_class.send(:define_method, :give_items_back) { |_before| [] }
$game_map.singleton_class.send(:attr_accessor, :need_refresh)
FREEZE.undo(:troop => 71, :mark => 0, :items => {}, :start => UNDO_START)
undo = { "rows" => UNDO_ROWS, "start" => UNDO_START, "personal" => UNDO_PERSONAL, "defeat_writes" => { "switches" => [[31, 39]], "variables" => [[9, 9]] },
         "written" => written }

File.write(File.join(__dir__, "rules.json"), JSON.pretty_generate(
  "source" => SOURCE_COMMIT, "sizes" => Hash[SIZES.map { |troop, size| [troop.to_s, size] }], "alternatives" => Hash[ALTERNATIVES.map { |troop, others| [troop.to_s, others] }],
  "sections" => BOSSES.sections, "tier_stats" => BOSSES.tier_stats.map(&:to_s), "names" => names, "caps" => caps, "refusals" => refusals,
  "pool_kinds" => pool_kinds, "tier_kinds" => tier_kinds, "world" => WORLD_SCENARIOS, "defeats" => defeats, "undo" => undo
) + "\n")
puts "wrote #{names.size} names, #{caps.size} stories, #{refusals.size} refusals, #{pool_kinds.size + tier_kinds.size} kinds, " \
     "#{WORLD_SCENARIOS.size} world scenarios, #{defeats.size} defeats and an undo"
