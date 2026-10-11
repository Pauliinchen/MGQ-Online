#----------------------------------------------------------------
#  hotkeys_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-12: Checked the hotkey that makes the Leader HUD small, and the hotkeys' own group in the Mod Config
#      Paulinchen  2026-10-11: Checked the hotkey that opens the bug report
#                            - Checked that a hotkey pressed while a confirm box is open goes to the box
#      Paulinchen  2026-10-10: Checked that every help says hotkey and keeps its lines short
#      Paulinchen  2026-10-09: Checked the hotkey that joins a battle nearby
#      Paulinchen  2026-10-04: Checked the party box size key and the name of Tab
#                            - Checked the emote wheel's key
#                            - Followed the scripts to their new names, without mp_
#      Paulinchen  2026-10-03: Checked the keys that accept and decline the first notification
#                            - Renamed from keys_test.rb
#      Paulinchen  2026-10-02: Created
#
#----------------------------------------------------------------

# Covers the keys the player binds, core_hotkeys.rbx: the defaults, the keys kept in Player.ini, their
# names in the texts, and their key bindings in Mod Config Remake.

require_relative "support"

# Stand-ins for the game, Mod Config Remake and the mod's base script.
module NWConst; module Config; MOD_CONTENTS = [{ :key => :return }]; end; end
module ModConfigRemake; module Keys; def self.name(code); { 0x4B => "K", 0x54 => "T" }.fetch(code, "?"); end; end; end
$player_ini = {}
$down = []
$log = []
module MGQ_Multiplayer
  module Log; def self.write(message); $log << message; end; end
  module Key; def self.pressed?(code); $down.include?(code); end; end
  module Player
    def self.setting(key); $player_ini[key]; end
    def self.store(key, value); $player_ini[key] = value.to_s; true; end
  end
end

load_script "core_hotkeys"

keys = MGQ_MpHotkeys

# The defaults.
check("the defaults: B, T, F11, Y, N, E, Tab, H, J and F3",
      [keys.code(:wheel), keys.code(:chat), keys.code(:overview), keys.code(:accept), keys.code(:decline), keys.code(:emotes), keys.code(:party_box),
       keys.code(:leader_hud), keys.code(:join_battle), keys.code(:bug_report)],
      [0x42, 0x54, 0x7A, 0x59, 0x4E, 0x45, 0x09, 0x48, 0x4A, 0x72])
check("a key is read by its code", [($down = [0x54]) && keys.pressed?(:chat), keys.pressed?(:wheel)], [true, false])

# A confirm box of the mod takes every hotkey while it is open.
check("no confirm box is open before ui.rbx loaded", keys.confirm_open?, false)
module MGQ_MpUi; module Confirm; def self.open?; $confirm_open; end; end; end
$confirm_open = true
$log.clear
check("a hotkey pressed while a confirm box is open goes to the box", [keys.pressed?(:chat), $log], [false, ["keys: hotkey T went to the confirm box"]])
$confirm_open = false
check("and reads again once the box is gone", keys.pressed?(:chat), true)

# Binding.
keys.bind(:wheel, 0x4B)
check("a bound key goes to Player.ini", [$player_ini["key_wheel"], keys.code(:wheel)], ["75", 0x4B])
check("the texts name the bound key", keys.label(:wheel), "K")
$player_ini["key_chat"] = "junk"
check("an unreadable setting falls back to the default", keys.code(:chat), 0x54)
$player_ini["key_chat"] = "999"
check("as does a code no key has", keys.code(:chat), 0x54)

# The options in Mod Config Remake.
rows = NWConst::Config::MOD_CONTENTS[0..-2]
check("one key binding per key in the hotkeys' group, before Return", rows.map { |row| [row[:name], row[:keybind]] },
      [["[MGQ Online Hotkeys] Action Wheel", true], ["[MGQ Online Hotkeys] Chat", true], ["[MGQ Online Hotkeys] World Overview", true],
       ["[MGQ Online Hotkeys] Accept Notification", true], ["[MGQ Online Hotkeys] Decline Notification", true],
       ["[MGQ Online Hotkeys] Emote Wheel", true], ["[MGQ Online Hotkeys] Party Box Size", true], ["[MGQ Online Hotkeys] Leader HUD Size", true],
       ["[MGQ Online Hotkeys] Join Battle", true], ["[MGQ Online Hotkeys] Report a Bug", true]])
check("Return stays last", NWConst::Config::MOD_CONTENTS.last[:key], :return)
check("each reads its key from Player.ini", rows.map { |row| row[:value].call }, [0x4B, 0x54, 0x7A, 0x59, 0x4E, 0x45, 0x09, 0x48, 0x4A, 0x72])
rows[2][:on_change].call(0x4C)
check("and keeps a new key there", [$player_ini["key_overview"], keys.code(:overview)], ["76", 0x4C])

# Without Mod Config Remake 1.3.0, such as with an older version.
ModConfigRemake.send(:remove_const, :Keys)
check("a bound key is still named", [keys.label(:wheel), keys.label(:overview), keys.plain_name(0xBA), keys.plain_name(0x09), keys.label(:bug_report)],
      ["K", "L", "key 186", "Tab", "F3"])
before = NWConst::Config::MOD_CONTENTS.size
keys.register
check("and no key bindings are added", NWConst::Config::MOD_CONTENTS.size, before)

# The help texts.
check("every help calls its binding a hotkey", keys::BINDINGS.values.map { |binding| binding.help[/\A\S+ \S+/] }.uniq, ["The hotkey"])
check("no help line is longer than 120 characters",
      keys::BINDINGS.values.map { |binding| binding.help.split("\n") }.flatten.select { |line| line.size > 120 }, [])
check("the Party Box Size help has two lines", keys::BINDINGS[:party_box].help.split("\n").size, 2)
