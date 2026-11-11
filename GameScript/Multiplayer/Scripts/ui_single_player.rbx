#----------------------------------------------------------------
#  ui_single_player.rbx
#
#  Changelog:
#      Paulinchen  2026-11-11: Dropped the offer to restart the game and its resume, since every row applies at once
#      Paulinchen  2026-11-07: Dropped the check for a Mod Framework call older versions lacked
#      Paulinchen  2026-11-06: Renamed add_options to offer_rows, which the Mod Framework's scan no longer takes for a call of the old UI
#                            - Offered the restart through UI.confirm, Later lit first
#      Paulinchen  2026-11-05: Took the slot to resume as the number or name the DLL reads
#      Paulinchen  2026-11-01: Named the Mod Framework's interface by its own name
#      Paulinchen  2026-10-31: Kept its rows through the Mod Framework
#                            - Worded what the player reads plainly, leaving causes and internals to the log
#                            - Started the restart question on Restart
#      Paulinchen  2026-10-30: Started the game again through the Mod Framework, which goes on from the game kept for it
#                            - Dropped the parked mods, which no world parks any more
#      Paulinchen  2026-10-23: Started the game again under Wine or Proton too
#      Paulinchen  2026-10-13: Created
#
#----------------------------------------------------------------

# The Options > Mods group of single player, MGQ Online SP (MGQ_Multiplayer::SP_PREFIX): its rows
# in their order, the interface first (the Leader HUD and the raid bosses' bars, see
# ui_leader_hud.rbx and ui_raid_bar.rbx), then Raid Bosses (battles_raid_tiers.rbx), each kept by
# its own script. Every row applies as it changes, inside a world or outside.
#
# It must work without any connection.
module MGQ_MpSinglePlayer
  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "single player"

  # Lists the group's rows in their order: each row's key, name, help, how it reads its value and
  # how it takes the value picked.
  #
  # @return [Array<Array>] The rows.
  def self.rows
    on_off = lambda { |on| on ? MGQ_MpLeaderHud::ON : MGQ_MpLeaderHud::OFF }
    [
      [MGQ_MpLeaderHud::SP_SHOWN_OPTION, MGQ_MpLeaderHud::SHOWN_OPTION_NAME, MGQ_MpLeaderHud::SP_SHOWN_OPTION_HELP,
       lambda { on_off.call(MGQ_MpLeaderHud.sp_shown?) }, lambda { |value| MGQ_MpLeaderHud.show_sp(value == MGQ_MpLeaderHud::ON) }],
      [MGQ_MpRaidBar::OPTIONS[:map], MGQ_MpRaidBar::OPTION_NAMES[:map], MGQ_MpRaidBar::OPTION_HELPS[:map],
       lambda { on_off.call(MGQ_MpRaidBar.shown?(:map)) }, lambda { |value| MGQ_MpRaidBar.show_bar(:map, value == MGQ_MpLeaderHud::ON) }],
      [MGQ_MpRaidBar::OPTIONS[:battle], MGQ_MpRaidBar::OPTION_NAMES[:battle], MGQ_MpRaidBar::OPTION_HELPS[:battle],
       lambda { on_off.call(MGQ_MpRaidBar.shown?(:battle)) }, lambda { |value| MGQ_MpRaidBar.show_bar(:battle, value == MGQ_MpLeaderHud::ON) }],
      [MGQ_MpRaidTiers::OPTION, MGQ_MpRaidTiers::OPTION_NAME, MGQ_MpRaidTiers::OPTION_HELP,
       lambda { on_off.call(MGQ_MpRaidTiers.single_player?) }, lambda { |value| MGQ_MpRaidTiers.choose(value == MGQ_MpLeaderHud::ON) }],
    ]
  end

  # Offers the group's rows in Options > Mods, kept in Player.ini.
  def self.offer_rows
    added = rows.map do |key, name, help, read, write|
      Mod_Framework::Options.keep(key, MGQ_Multiplayer::SP_PREFIX + name, help, lambda { [MGQ_MpLeaderHud::ON, MGQ_MpLeaderHud::OFF] }, read, write)
    end
    log(added.all? ? "added MGQ Online SP to Options > Mods" : "no MGQ Online SP in Options > Mods, see the Mod Framework's log")
  end
end

# The Options > Mods rows, through ui.rbx.

begin
  MGQ_MpSinglePlayer.offer_rows
rescue => e
  MGQ_MpSinglePlayer.log("Mod Config rows FAILED: #{e.class}: #{e.message}")
end
