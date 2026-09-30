#----------------------------------------------------------------
#  battles_test.rb
#
#  Changelog:
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# Covers mp_battles.rbx: the rules every multiplayer battle shares, and putting the game's own back.

require_relative "support"

module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end
module SceneManager; def self.run; end; end
module BattleManager; def self.can_giveup?; true; end; end
module NWConst; module Sw; FORBID_BATTLE_SHIFT_CHANGE = 27; end; end
System = Struct.new(:switches)
$data_system = System.new(Array.new(100, ""))
$data_system.switches[86] = "No Seduction"
class Game_Switches; def initialize; @d = {}; end; def [](i); @d[i] || false; end; def []=(i, v); @d[i] = v; end; end
$game_switches = Game_Switches.new
module MGQ_MpCoop
  def self.tell(seat, field, value, fields = {})
    MGQ_MpOverworldSync::Link.send_to(seat, MGQ_MpOverworldSync::Me.encode({ field => value, "party" => Party.id }.merge(fields)))
  end
  def self.route(*); end
end
module MGQ_MpOverworldSync
  def self.route(*); end
  def self.on_tick(*); end
  def self.state_fields(*); end
  def self.busy_scene(*); end
  def self.on_observe(*); end
  def self.on_leave(*); end
  def self.label_line(*); end
end
load_script "mp_battles"
SceneManager.run
$game_switches[27] = false
$game_switches[86] = false
check("Give Up outside", BattleManager.can_giveup?, true)
MGQ_MpBattles.begin(:coop)
check("rules on", [MGQ_MpBattles.kind, $game_switches[86], $game_switches[27], BattleManager.can_giveup?], [:coop, true, true, false])
MGQ_MpBattles.finish
check("the game's own settings come back", [MGQ_MpBattles.running?, $game_switches[86], $game_switches[27], BattleManager.can_giveup?], [false, false, false, true])
$game_switches[86] = true
MGQ_MpBattles.begin(:pvp)
MGQ_MpBattles.finish
check("a switch that was on stays on", $game_switches[86], true)
$data_system.switches[86] = "Other name"
check("the id stands in for a translated name", MGQ_MpBattles.switch_rules.keys.sort, [27, 86])
