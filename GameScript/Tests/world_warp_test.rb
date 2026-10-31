#----------------------------------------------------------------
#  world_warp_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

# Covers the warp ban in a world (story_state.rbx): a world keeps it off, whether a loaded save held
# it or an event sets it, while outside a world the game's ban holds.

require_relative "support"

# Stands in for the mod's log: records each line in $log and answers with a byte count, as
# File#write does.
module MGQ_Multiplayer; module Log; def self.write(m); $log << m; 87; end; end; end
$log = []

# Stands in for the game's switches.
class Game_Switches
  # Starts with every switch off.
  def initialize; @data = []; end
  # Reads a switch.
  def [](id); @data[id] || false; end
  # Sets a switch.
  def []=(id, value); @data[id] = value; end
end

# Stands in for the game's loading of a save, which puts the save's switches in place.
module DataManager
  # Puts a save's switches in place.
  def self.extract_save_contents(contents); $game_switches = contents[:switches]; end
end

# Stands in for the game's warp check, which the Warp spell and the warp items ask, with one place
# open.
module WarpManager
  # Reports whether the player may warp, as the game's WarpManager.usable? does.
  def self.usable?; !($game_switches[NWConst::Sw::WARP_BAN] || opend_places.empty?); end
  # Lists the places the player opened.
  def self.opend_places; [:iliasville]; end
end

# Stands in for the game's switch constants.
module NWConst; module Sw; WARP_BAN = 100; end; end

# Stands in for the world: open while $in_world is set.
module MGQ_MpOverworldSync; def self.in_world?; $in_world; end; end

load_script "story_state"

# Makes a save's switches with both bans on.
#
# @return [Game_Switches] The switches.
def banned_save
  switches = Game_Switches.new
  switches.instance_variable_get(:@data)[100] = true
  switches.instance_variable_get(:@data)[94] = true
  switches
end

# Reads the warp ban and the escape spell's ban as the game keeps them.
#
# @return [Array<Boolean>] The warp ban, then the escape spell's ban.
def bans
  data = $game_switches.instance_variable_get(:@data)
  [data[100] ? true : false, data[94] ? true : false]
end

$in_world = false
DataManager.extract_save_contents(:switches => banned_save)
check("a save loaded outside a world keeps both bans", bans, [true, true])
check("so the player cannot warp there", WarpManager.usable?, false)

$in_world = true
DataManager.extract_save_contents(:switches => banned_save)
check("a save loaded in a world loses the warp ban it held and keeps the escape spell's ban", bans, [false, true])
check("so the player can warp", WarpManager.usable?, true)

$game_switches = Game_Switches.new
$game_switches[100] = true
$game_switches[94] = true
check("in a world an event setting both bans leaves the warp ban off and the escape spell's ban on", bans, [false, true])
check("so the warp check reads no ban", WarpManager.usable?, true)

$in_world = false
$game_switches[100] = true
check("outside a world an event sets the warp ban", bans, [true, true])
check("and it stops the player from warping", WarpManager.usable?, false)
