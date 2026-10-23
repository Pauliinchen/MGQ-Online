#----------------------------------------------------------------
#  catchup_exp_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Checked the requests to the DLL, which owns the rule
#      Paulinchen  2026-10-13: Checked that a character the catch-up does not count gains no more
#      Paulinchen  2026-10-12: Created
#
#----------------------------------------------------------------

# Covers world_catchup_exp.rbx: the level characters catch up to and a battle's base, job and race
# experience grown, only in a Raid World's story, as the DLL answers them (the rule's own cases are
# in MGQOnline.Game.Tests).

require_relative "rules_support"

# Stands in for the loader's log, printing its lines.
module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end

# The world's story: whether it is followed, and the counters the relay told.
module MGQ_MpWorldStory
  class << self
    attr_accessor :active, :world
  end

  def self.active?
    @active
  end
end

# A character: its base level and the experience the game gave it.
class Game_Actor
  attr_reader :name, :base_level, :gained

  def initialize(name, base_level)
    @name = name
    @base_level = base_level
    @gained = []
  end

  # Keeps each grant of experience in @gained.
  def gain_exp(exp, cexp = nil)
    @gained << [exp, cexp]
  end
end

# Stands in for the catch-up, which counts every character but those named in $uncounted.
module MGQ_MpWorldCatchup; def self.counts?(actor); !Array($uncounted).include?(actor.name); end; end

load_script("world_catchup_exp")
exp = MGQ_MpWorldCatchupExp
bridge = open_rules_bridge

MGQ_MpWorldStory.active = true
MGQ_MpWorldStory.world = { "caps" => [] }
check("no catch-up before the world's story raised the level cap", exp.target, nil)
MGQ_MpWorldStory.world = { "caps" => [10] }
check("the first raise leaves the cap every story starts with", exp.target, 5)
MGQ_MpWorldStory.world = { "caps" => [10, 15] }
check("the world jumping from 10 to 15 catches up to 10", exp.target, 10)
MGQ_MpWorldStory.active = false
check("no catch-up outside a Raid World's story", exp.target, nil)

check("the Unlocks page asks the factor of a level", [exp.factor_text(30, 40), exp.factor_text(1, nil)], ["x4", "x1"])

low = Game_Actor.new("Low", 6)
high = Game_Actor.new("High", 12)
MGQ_MpWorldStory.active = true
MGQ_MpWorldStory.world = { "caps" => [10, 15] }
low.gain_exp(100, 40)
high.gain_exp(100, 40)
check("a battle's base, job and race experience grow for a character below the target, not for one above it", [low.gained, high.gained], [[[580, 232]], [[100, 40]]])
check("the DLL is told the target, the level and the experience",
      bridge.calls.select { |topic, _| topic == "catchup.grow" }.map { |_, bytes| Marshal.load(bytes) }.first, { "target" => 10, "level" => 6, "exp" => 100, "cexp" => 40 })
guest = Game_Actor.new("Guest", 6)
$uncounted = ["Guest"]
asked = bridge.calls.size
guest.gain_exp(100, 40)
check("nor for one the catch-up does not count, such as a story's temporary party or a companion on a visit", [guest.gained, bridge.calls.size], [[[100, 40]], asked])
$uncounted = nil

MGQ_MpWorldStory.active = false
low.gain_exp(100, 40)
check("outside a Raid World's story it stays", low.gained.last, [100, 40])
low.gain_exp(100)
check("experience given another way stays", low.gained.last, [100, nil])
