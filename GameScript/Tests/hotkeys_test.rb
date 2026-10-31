#----------------------------------------------------------------
#  hotkeys_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Checked the hotkeys defined through the Mod Framework, quiet while any mod types
#                            - Stood in for the Mod Framework's keys and question box
#      Paulinchen  2026-10-30: Dropped the table of default hotkeys
#      Paulinchen  2026-10-12: Checked that a refused hotkey is logged, and not while the player types
#                            - Checked the Leader HUD size hotkey and the hotkeys' own Mod Config group
#      Paulinchen  2026-10-11: Checked the hotkey that opens the bug report
#                            - Checked that a hotkey pressed while a confirm box is open goes to the box
#      Paulinchen  2026-10-10: Checked that every help says hotkey and keeps its lines short
#      Paulinchen  2026-10-09: Checked the hotkey that joins a battle nearby
#      Paulinchen  2026-10-04: Checked the party box size hotkey and the name of Tab
#                            - Checked the emote wheel's hotkey
#                            - Followed the scripts to their new names, without mp_
#      Paulinchen  2026-10-03: Checked the hotkeys that accept and decline the first notification
#                            - Renamed from keys_test.rb
#      Paulinchen  2026-10-02: Created
#
#----------------------------------------------------------------

# Covers core_hotkeys.rbx, the hotkeys the player binds: defined through the Mod Framework with
# their rows and keys, kept in Player.ini, read and named by their short names, and quiet while any
# mod types.

require_relative "support"

$player_ini = {}
$down = []
$log = []
# Stands in for the loader's log, keys held in $down and Player.ini in $player_ini.
module MGQ_Multiplayer
  module Log; def self.write(message); $log << message; end; end
  module Player
    def self.setting(key); $player_ini[key]; end
    def self.store(key, value); $player_ini[key] = value.to_s; true; end
  end
end
# Stands in for the keyboard: the keys in $down went down.
module Mod_Framework::UI::Key; def self.pressed?(code); $down.include?(code); end; end

load_script "core_hotkeys"
Mod_Framework.available = true

keys = MGQ_MpHotkeys
defined = Mod_Framework::Hotkeys.instance_variable_get(:@hotkeys)

# The hotkeys and their rows.
check("the eight hotkeys are defined with their rows' names, keys and settings in Player.ini",
      defined.values.select { |hotkey| hotkey.store.equal?(MGQ_Multiplayer::Player) }.map { |hotkey| [hotkey.action, hotkey.name, hotkey.default, hotkey.setting] },
      [[:mgq_online_wheel, "[MGQ Online Hotkeys] Action Wheel", 0x42, "key_wheel"], [:mgq_online_chat, "[MGQ Online Hotkeys] Chat", 0x54, "key_chat"],
       [:mgq_online_overview, "[MGQ Online Hotkeys] World Overview", 0x7A, "key_overview"], [:mgq_online_emotes, "[MGQ Online Hotkeys] Emote Wheel", 0x45, "key_emotes"],
       [:mgq_online_party_box, "[MGQ Online Hotkeys] Party Box Size", 0x09, "key_party_box"], [:mgq_online_leader_hud, "[MGQ Online Hotkeys] Leader HUD Size", 0x48, "key_leader_hud"],
       [:mgq_online_join_battle, "[MGQ Online Hotkeys] Join Battle", 0x4A, "key_join_battle"], [:mgq_online_bug_report, "[MGQ Online Hotkeys] Report a Bug", 0x72, "key_bug_report"]])
check("Accept and Decline are the framework's own, kept in its settings", [:accept, :decline].map { |action| defined[action].store }, [Mod_Framework::Settings] * 2)
check("which MGQ Online asks by name without defining them", [keys::HOTKEYS.key?(:accept), keys.code(:accept), keys.label(:decline)], [false, 0x59, "N"])

# Reading a hotkey.
$down = [0x54]
check("a hotkey answers the framework's press of its key", [keys.pressed?(:chat), keys.pressed?(:wheel)], [true, false])
# Another mod that types, such as a text field of a library mod, sets $mgq_text_input.
$mgq_text_input = true
$log.clear
lines = $framework_log.size
check("a hotkey pressed while another mod types is dropped, its letter left out of every log",
      [keys.pressed?(:chat), $log, $framework_log[lines..-1]], [false, [], []])
check("as is the refusal a script logs", [keys.log_refusal(:emotes, "the chat box is open"), $log], [nil, []])
$mgq_text_input = nil
$down = []

# Binding.
$player_ini["key_wheel"] = "75"
check("a key bound in Player.ini is read back and named", [keys.code(:wheel), keys.label(:wheel)], [0x4B, "K"])
keys.bind(:overview, 0x4C)
check("a key bound in the row goes to Player.ini", [$player_ini["key_overview"], keys.code(:overview)], ["76", 0x4C])
$player_ini["key_chat"] = "junk"
check("an unreadable setting falls back to the default", keys.code(:chat), 0x54)

# The help texts.
helps = keys::HOTKEYS.values.map { |hotkey| hotkey.help }
check("every help calls its binding a hotkey", helps.map { |help| help[/\A\S+ \S+/] }.uniq, ["The hotkey"])
check("no help line is longer than 120 characters", helps.map { |help| help.split("\n") }.flatten.select { |line| line.size > 120 }, [])

# A hotkey refused.
keys.log_refusal(:emotes, "the chat box is open")
check("a refused hotkey is logged with its key, its name and why", $log.last, "keys: hotkey E (Emote Wheel) ignored: the chat box is open")

