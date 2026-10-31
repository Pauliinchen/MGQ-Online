#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Read the old scripts from a commit that feat/refactor holds
#      Paulinchen  2026-10-30: Created
#
#----------------------------------------------------------------

# Writes the golden cases of a Raid World's pool ledger next to this file, ledger.json, from
# battles_raid_pool.rbx as it kept the ledger before it moved to C# (commit 1bdba95d, which this
# generator reads through git, so it runs again on later commits). Each scenario is a list of steps
# the C# ledger replays: the relay's push of a pool, the player's own report, the relay's answer
# that settles a report, and time passing; each step records every pool as the player's game knows
# it then (its share left now to ten decimals, its max, its defeat and who defeated it), the pools
# told defeated for the world and the changes of those. The scenarios leave out what the move
# changes on purpose: the DLL's state lines and their tolerance, and time running backwards.
# MGQOnline.Game.Tests and GameScript/Tests/pool_support.rb replay them.
#
#   ruby fixtures/pool/make_fixtures.rb

require "json"
require "tempfile"
require_relative "../../GameScript/Tests/support"

# The commit whose battles_raid_pool.rbx kept the ledger.
SOURCE_COMMIT = "1bdba95d"

# The log stays quiet; the cases record what the rules did, not their lines.
module MGQ_Multiplayer; module Log; def self.write(_line); end; end; end

# The clock, which stands still unless a step moves it.
$now = Time.at(1_000_000)
# Stands in for the clock: answers $now.
def Time.now; $now; end

# Stands in for the world's sync, which the script registers with as it loads.
module MGQ_MpOverworldSync
  # The field of the relay's push of a pool.
  BOSS_FIELD = "boss_key"
  # Takes a route.
  def self.route(_field, &_block); end
  # Takes a block to run each frame.
  def self.on_tick(&_block); end
  # Takes a block of the player's state fields.
  def self.state_fields(&_block); end
end
# Stands in for a Raid World.
module MGQ_MpCoop; module Scope; def self.raid?; true; end; end; end
# Stands in for the world's story.
module MGQ_MpWorldStory; def self.active?; true; end; def self.mode; :world; end; def self.world_id; "w1"; end; end
# Stands in for the chat log.
module MGQ_MpChat; def self.system(_text); end; end
# Stands in for the scenes, which the script hooks.
module SceneManager; def self.run; end; def self.scene; nil; end; end
# Stands in for the title screen.
class Scene_Title; def start; end; end
# Stands in for the battles, which the script hooks.
module BattleManager; def self.setup(*_args); end; end
# Stands in for the map, which the script hooks.
class Game_Map; def update_interpreter; end; end
# Stands in for the interpreter, which the script hooks.
class Game_Interpreter; def command_301; end; end

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

load_old("battles_raid_bosses")
load_old("battles_raid_pool")
POOL = MGQ_MpRaidPool

# Runs one step on the script's ledger.
#
# @param step [Hash] The step: "op" with "push" ("key", "left" as the relay writes it, "max",
#   "defeated", "by"), "own" ("key", "delta", "max", "dead"), "settle" ("key") or "wait" ("ms").
def run(step)
  case step["op"]
  when "push"
    POOL.pushed(MGQ_MpOverworldSync::BOSS_FIELD => step["key"], "left" => step["left"], "max" => step["max"].to_s,
                "defeated" => step["defeated"] ? "1" : "0", "by" => step["by"].to_s, :relay => true)
  when "own"
    POOL.note_own(step["key"], step["delta"], step["max"], step["dead"])
    POOL.instance_variable_get(:@pending) << step["key"]
  when "settle"
    pending = POOL.instance_variable_get(:@pending)
    pending.delete_at(pending.index(step["key"]))
  when "wait"
    $now += step["ms"] / 1000.0
  end
end

# Describes every pool as the script knows it now.
#
# @return [Array<Array>] Each pool's key, share left now to ten decimals, max, defeat and who
#   defeated it (empty while it stands), by key.
def view
  POOL.pools.sort_by { |key, _| key.b }.map do |key, pool|
    [key, format("%.10f", POOL.left_now(pool, $now)), pool.max.to_i, pool.defeated ? true : false, pool.defeated ? pool.by.to_s : ""]
  end
end

# Lists the pools told defeated for the world, by their key.
#
# @return [Array<String>] The keys.
def told
  POOL.instance_variable_get(:@announced).keys.sort_by(&:b)
end

# Plays a scenario on a fresh ledger.
#
# @param name [String] What it shows.
# @param steps [Array<Hash>] Its steps, see run.
# @return [Hash] The scenario with what each step left.
def scenario(name, steps)
  POOL.forget
  $now = Time.at(1_000_000)
  played = steps.map do |step|
    before = told
    run(step)
    after = told
    events = (after - before).map { |key| ["defeated", key] } + (before - after).map { |key| ["back", key] }
    step.merge("view" => view, "told" => after, "events" => events)
  end
  { "name" => name, "steps" => played }
end

# Makes the relay's push of a pool.
#
# @param key [String] The pool.
# @param left [String] The share left, as the relay writes it.
# @param max [Integer] The raid max HP.
# @param defeated [Boolean] Whether the push defeats it.
# @param by [String] Who defeated it.
# @return [Hash] The step.
def push(key, left, max, defeated = false, by = "")
  { "op" => "push", "key" => key, "left" => left, "max" => max, "defeated" => defeated, "by" => by }
end

# Makes the player's own report.
#
# @param key [String] The pool.
# @param delta [Float] The share of the max lost.
# @param max [Integer] The battle's max HP of the enemy.
# @param dead [Boolean] Whether the enemy died.
# @return [Hash] The step.
def own(key, delta, max, dead = false)
  { "op" => "own", "key" => key, "delta" => delta, "max" => max, "dead" => dead }
end

# Makes the relay's answer to the oldest unanswered report of a pool.
#
# @param key [String] The pool.
# @return [Hash] The step.
def settle(key)
  { "op" => "settle", "key" => key }
end

# Makes time pass.
#
# @param ms [Integer] The milliseconds.
# @return [Hash] The step.
def wait(ms)
  { "op" => "wait", "ms" => ms }
end

SCENARIOS = [
  scenario("a pool gains its share a minute back, at most all of it",
           [push("Alpha", "0.5", 1000), wait(60_000), wait(20_000), wait(1_800_000)]),
  scenario("a standing pool keeps its least share, a defeat empties it and names who, a reset fills it",
           [push("Alpha", "0", 900), push("Alpha", "0", 900, true, "Hero"), wait(60_000), push("Alpha", "1", 900)]),
  scenario("the player's own reports count at once, on a pool the relay told of or not",
           [own("Beta", 0.25, 800), push("Gamma", "0.6", 5000), own("Gamma", 0.1, 4000), wait(120_000), own("Gamma", -0.5, 4000)]),
  scenario("an own kill or an own report on a defeated pool leaves it defeated",
           [own("Beta", 0.05, 800, true), push("Gamma", "0", 300, true, "Hero"), own("Gamma", 0.2, 300)]),
  scenario("word of more HP than the player's own unanswered reports leave is older and ignored",
           [push("Beta", "0.8", 5000), own("Beta", 0.3, 5000), push("Beta", "0.8", 5000), push("Beta", "0.4", 5000), settle("Beta"), push("Beta", "0.9", 5000)]),
  scenario("a defeat and a reset are taken while a report waits",
           [push("Gamma", "0.6", 7000), own("Gamma", 0.1, 7000), push("Gamma", "0", 7000, true, "Rival"), own("Gamma", 0.1, 7000), push("Gamma", "1", 7000)]),
  scenario("each unanswered report of a pool holds older word back until the last is answered",
           [push("Delta", "0.9", 2000), own("Delta", 0.2, 2000), own("Delta", 0.2, 2000), settle("Delta"), push("Delta", "0.7", 2000),
            settle("Delta"), push("Delta", "0.7", 2000)]),
  scenario("a push defeats and fills each pool of its own once",
           [push("Alpha", "0", 900, true, "Hero"), push("Alpha", "0", 900, true, "Hero"), push("Beta", "0", 900, true),
            push("Alpha", "1", 900), push("Alpha", "1", 900)]),
].freeze

File.write(File.join(__dir__, "ledger.json"), JSON.pretty_generate("source" => SOURCE_COMMIT, "regen_per_minute" => POOL::REGEN_PER_MINUTE,
                                                                     "min_left" => POOL::MIN_LEFT, "scenarios" => SCENARIOS) + "\n")
system("node", File.join(__dir__, "make_relay_fixtures.mjs"), exception: true)
puts "wrote ledger.json and relay.json"
