#----------------------------------------------------------------
#  catchup_exp_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-12: Created
#
#----------------------------------------------------------------

# Covers world_catchup_exp.rbx: the level characters catch up to, the factor by the levels below
# it, and a battle's base, job and race experience grown by it only in a Raid World's story.

require_relative "support"

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

load_script("world_catchup_exp")
exp = MGQ_MpWorldCatchupExp

MGQ_MpWorldStory.active = true
MGQ_MpWorldStory.world = { "caps" => [] }
check("no catch-up before the world's story raised the level cap", exp.target, nil)
MGQ_MpWorldStory.world = { "caps" => [10] }
check("the first raise leaves the cap every story starts with", exp.target, 5)
MGQ_MpWorldStory.world = { "caps" => [10, 15] }
check("the world jumping from 10 to 15 catches up to 10", exp.target, 10)
MGQ_MpWorldStory.active = false
check("no catch-up outside a Raid World's story", exp.target, nil)

check("the factor is tenfold in the lowest quarter of the target, falls evenly above it and is 1 from the target on",
      [40, 39, 30, 20, 11, 10, 1, 45].map { |level| exp.factor_for(level, 40).round(2) }, [1.0, 1.3, 4.0, 7.0, 9.7, 10.0, 10.0, 1.0])
check("the fade follows the target, so an early world's lowest quarter is tenfold too",
      [exp.factor_for(2, 10).round(2), exp.factor_for(4, 10).round(2), exp.factor_for(48, 195).round(2), exp.factor_for(49, 195).round(2)], [10.0, 8.2, 10.0, 9.98])
check("and 1 without a target", exp.factor_for(1, nil), 1.0)
check("the Levels page writes it short", [exp.factor_text(3.5), exp.factor_text(10.0), exp.factor_text(3.9999999), exp.factor_text(1.2345)], ["x3.5", "x10", "x4", "x1.23"])

low = Game_Actor.new("Low", 6)
high = Game_Actor.new("High", 12)
MGQ_MpWorldStory.active = true
MGQ_MpWorldStory.world = { "caps" => [10, 15] }
low.gain_exp(100, 40)
high.gain_exp(100, 40)
check("a battle's base, job and race experience grow for a character below the target, not for one above it", [low.gained, high.gained], [[[580, 232]], [[100, 40]]])

MGQ_MpWorldStory.active = false
low.gain_exp(100, 40)
check("outside a Raid World's story it stays", low.gained.last, [100, 40])
low.gain_exp(100)
check("experience given another way stays", low.gained.last, [100, nil])
