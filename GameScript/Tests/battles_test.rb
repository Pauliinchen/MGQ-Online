#----------------------------------------------------------------
#  battles_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-06: Checked that a reset forgets the rules without touching the switches of the save loaded next
#      Paulinchen  2026-10-04: Followed the scripts to their new names, without mp_
#      Paulinchen  2026-10-03: Checked that a PvP battle with the Backline may swap it in
#                            - Checked the modes of live battles
#      Paulinchen  2026-10-01: Checked that only PvP battles forbid swapping the Backline in
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# Covers battles.rbx: the rules every multiplayer battle shares, and putting the game's own back.

require_relative "support"

module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end
module SceneManager; def self.run; end; end
class Scene_Title; def start; end; end
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
load_script "battles"
SceneManager.run
$game_switches[27] = false
$game_switches[86] = false
check("Give Up outside", BattleManager.can_giveup?, true)
MGQ_MpBattles.begin(:coop)
check("rules on", [MGQ_MpBattles.kind, $game_switches[86], BattleManager.can_giveup?], [:coop, true, false])
check("a co-op battle may swap the Backline in", $game_switches[27], false)
MGQ_MpBattles.finish
check("the game's own settings come back", [MGQ_MpBattles.running?, $game_switches[86], $game_switches[27], BattleManager.can_giveup?], [false, false, false, true])
$game_switches[86] = true
MGQ_MpBattles.begin(:pvp)
check("a PvP battle may not swap the Backline in", $game_switches[27], true)
MGQ_MpBattles.finish
check("a switch that was on stays on", [$game_switches[86], $game_switches[27]], [true, false])
MGQ_MpBattles.begin(:pvp, true)
check("a PvP battle with the Backline may swap it in", $game_switches[27], false)
MGQ_MpBattles.finish
$data_system.switches[86] = "Other name"
check("the id stands in for a translated name", MGQ_MpBattles.switch_rules(:pvp).keys.sort, [27, 86])

# What a kind of live battle does differently.
duel = MGQ_MpBattles::Duel
check("a kind that registered no mode is a duel", MGQ_MpBattles.mode_of(:unknown), duel)
check("a duel changes nothing", [duel.same_side?, duel.same_side_as_host?(2), duel.player_seats, duel.host_start(nil), duel.heir_of(2), duel.stream_kinds, duel.take_over(nil)],
      [false, false, [], nil, nil, [], false])
other = Module.new.extend(MGQ_MpBattles::Mode)
MGQ_MpBattles.mode(:other, other)
check("a kind's mode is found by its name", MGQ_MpBattles.mode_of(:other), other)

# A reset in the middle of a battle.
$data_system.switches[86] = "No Seduction"
MGQ_MpBattles.begin(:coop)
$game_switches = Game_Switches.new
Scene_Title.new.start
check("a reset forgets the rules", [MGQ_MpBattles.running?, BattleManager.can_giveup?], [false, true])
MGQ_MpBattles.finish
check("and never puts their switches into the save loaded next", [$game_switches[86], $game_switches[27]], [false, false])
