#----------------------------------------------------------------
#  hotkeys_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-04: Followed the scripts to their new names, without mp_
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
module MGQ_Multiplayer
  module Log; def self.write(_message); end; end
  module Key; def self.pressed?(code); $down.include?(code); end; end
  module Player
    def self.setting(key); $player_ini[key]; end
    def self.store(key, value); $player_ini[key] = value.to_s; true; end
  end
end

load_script "core_hotkeys"

keys = MGQ_MpHotkeys

# The defaults.
check("the defaults: B, T, F11, Y and N", [keys.code(:wheel), keys.code(:chat), keys.code(:overview), keys.code(:accept), keys.code(:decline)],
      [0x42, 0x54, 0x7A, 0x59, 0x4E])
check("a key is read by its code", [($down = [0x54]) && keys.pressed?(:chat), keys.pressed?(:wheel)], [true, false])

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
check("one key binding per key, before Return", rows.map { |row| [row[:name], row[:keybind]] },
      [["[Monster Girl Quest! Online] Action Wheel", true], ["[Monster Girl Quest! Online] Chat", true], ["[Monster Girl Quest! Online] World Overview", true],
       ["[Monster Girl Quest! Online] Accept Notification", true], ["[Monster Girl Quest! Online] Decline Notification", true]])
check("Return stays last", NWConst::Config::MOD_CONTENTS.last[:key], :return)
check("each reads its key from Player.ini", rows.map { |row| row[:value].call }, [0x4B, 0x54, 0x7A, 0x59, 0x4E])
rows[2][:on_change].call(0x4C)
check("and keeps a new key there", [$player_ini["key_overview"], keys.code(:overview)], ["76", 0x4C])

# Without Mod Config Remake 1.3.0, such as with an older version.
ModConfigRemake.send(:remove_const, :Keys)
check("a bound key is still named", [keys.label(:wheel), keys.label(:overview), keys.plain_name(0xBA)], ["K", "L", "key 186"])
before = NWConst::Config::MOD_CONTENTS.size
keys.register
check("and no key bindings are added", NWConst::Config::MOD_CONTENTS.size, before)
