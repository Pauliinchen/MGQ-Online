#----------------------------------------------------------------
#  single_player_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-11: Checked that the rows apply at once, the restart offer and its resume gone
#      Paulinchen  2026-11-07: Expected the rows without personal:, which the Mod Framework no longer takes
#                            - Dropped the stand-in for Mod Config Remake, which nothing reads
#      Paulinchen  2026-11-06: Expected the restart offered through UI.confirm with Later lit first
#      Paulinchen  2026-11-05: Expected the slot kept as a number and the switches as true or false
#      Paulinchen  2026-11-01: Named the Mod Framework's interface by its own name, and took the framework away only for the restart's answer
#      Paulinchen  2026-10-31: Read the single player group from MGQ_Multiplayer::SP_PREFIX
#                            - Checked that the restart question starts on Restart
#      Paulinchen  2026-10-30: Started the game again through the Mod Framework's stand-in
#                            - Dropped the parked mods, which no world parks any more
#      Paulinchen  2026-10-23: Dropped the restart by hand under Wine
#      Paulinchen  2026-10-13: Created
#
#----------------------------------------------------------------

# Covers ui_single_player.rbx with the scripts whose settings its rows show (ui_leader_hud.rbx,
# ui_raid_bar.rbx, battles_raid_tiers.rbx): a row of MGQ Online SP picked in Options > Mods in a game
# of the player's own applies at once.

require_relative "world_support"

# The Mod Config's rows, the last of them the Return row, which the mod's rows go before.
NWConst::Config::MOD_CONTENTS = [{ :key => :return }] unless NWConst::Config.const_defined?(:MOD_CONTENTS)

load_script "battles_raid_bosses"
load_script "battles_raid_pool"
load_script "battles_raid_tiers"
load_script "ui_raid_bar"
load_script "ui_leader_hud"
load_script "ui_single_player"

hud = MGQ_MpLeaderHud
tiers = MGQ_MpRaidTiers

# Finds a row of the Mod Config.
#
# @param key [Symbol] The row's key.
# @return [Hash, nil] The row.
def row(key)
  NWConst::Config::MOD_CONTENTS.find { |each| each[:key] == key }
end

# A game of the player's own, outside a world, on an empty Player.ini: the Leader HUD picked Off and
# Raid Bosses picked On take effect at once, as the Options screen picks them.
$open = false
$player_ini = {}
row(hud::SP_SHOWN_OPTION)[:on_change].call("Off")
row(tiers::OPTION)[:on_change].call("On")
check("rows picked in a game of the player's own apply at once, and Player.ini keeps them",
      [hud.on?, tiers.active?, $player_ini.values_at(hud::SP_SHOWN_SETTING, tiers::SETTING)], [false, true, [false, true]])
