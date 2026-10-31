#----------------------------------------------------------------
#  settings_handover_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

# Covers the hand-over of the settings the Mod Framework keeps now, Stages.hand_over_settings of
# Multiplayer.rb: the look, the window color, every place and the Accept and Decline keys go from
# Player.ini into the framework's settings once, Player.ini forgets them only after the framework
# kept them, also at a later start, and MGQ Online's own hotkeys stay.

require_relative "bridge_support"

source = File.read(File.expand_path("../Multiplayer.rb", __dir__), :encoding => "UTF-8")
load_bridge

# Stands in for Multiplayer.rb's log, in $log, and Player.ini, in $player_ini, whose writes answer
# $player_ini_writes.
module MGQ_Multiplayer
  module Log; def self.write(line); $log << line; end; end
  module Player
    def self.readable?; true; end
    def self.keys_under(prefix); $player_ini.keys.select { |key| key.start_with?(prefix) }; end
    def self.setting(key); $player_ini[key]; end
    def self.change(changes)
      return false unless $player_ini_writes

      changes.each { |key, value| value.nil? ? $player_ini.delete(key) : $player_ini[key] = value }
      true
    end
  end
end
MGQ_Multiplayer.module_eval(source[/  MOD_FRAMEWORK_REQUIRED = .*\n/])
MGQ_Multiplayer.module_eval(source[/  module Stages\n.*?\n  end\n/m])
stages = MGQ_Multiplayer::Stages

# Starts a game session whose framework file holds some settings, writing it as $framework_writes
# says.
#
# @param held [Hash] What the framework's file holds.
def start_session(held)
  $framework_file = held.dup
  settings = Mod_Framework::Settings
  [:@values, :@read_at, :@failed_at, :@refused, :@noticed].each { |name| settings.instance_variable_set(name, nil) }
  settings.instance_variable_set(:@readable, false)
  settings.instance_variable_set(:@pending, false)
  fake = FakeBridge.new
  fake.answer("ini.read") { |_request| $framework_file.dup }
  fake.answer("ini.write") { |(_path, values)| $framework_writes ? ($framework_file = values.dup; true) : false }
  open_framework(fake)
end

$log = []
before = { "name" => "Me", "ui_preset" => "Legacy", "window_color" => "10,-20,30", "ui_chat" => "100,40,420,150", "ui_list_box" => "0,0,640,300",
           "key_accept" => "78", "key_chat" => "75" }

# A framework file that cannot be written takes nothing over, and Player.ini keeps it all.
$player_ini = before.dup
$player_ini_writes = true
$framework_writes = false
start_session({})
stages.hand_over_settings
check("a framework file that cannot be written leaves Player.ini as it is, for the next start to try again",
      [$player_ini, $log.last], [before, "the Mod Framework did not take ui_preset, window_color, ui_chat, ui_list_box, key_accept over, Player.ini keeps them for the next start"])

# The next start hands them over; the framework keeps a setting its file holds already.
$framework_writes = true
start_session("ui_preset" => "Monarch")
stages.hand_over_settings
check("the look, the window color, the places and Accept go into the framework's settings, a look it holds already kept",
      $framework_file.reject { |key, _| key.start_with?(Mod_Framework::Settings::MIGRATED) },
      { "ui_preset" => "Monarch", "window_color" => "10,-20,30", "ui_chat" => "100,40,420,150", "ui_list_box" => "0,0,640,300", "key_accept" => "78" })
check("and Player.ini forgets them once the framework kept them, keeping the player's name and MGQ Online's own hotkeys",
      [$player_ini, $log.last], [{ "name" => "Me", "key_chat" => "75" }, "handed ui_preset, window_color, ui_chat, ui_list_box, key_accept over to the Mod Framework"])

# A later start takes nothing over and forgets a place an older build wrote into Player.ini again.
$player_ini["ui_chat"] = "1,2,3,4"
start_session($framework_file)
stages.hand_over_settings
check("a later start forgets a place Player.ini holds again, the framework's kept",
      [$player_ini, $framework_file["ui_chat"], $log.last], [{ "name" => "Me", "key_chat" => "75" }, "100,40,420,150", "Player.ini forgot ui_chat, which the Mod Framework keeps"])

# A Player.ini that cannot forget them keeps them, the framework holding them already.
$player_ini = before.dup
$player_ini_writes = false
start_session({})
stages.hand_over_settings
check("a Player.ini that cannot be written keeps them beside the framework's, which says so in the log",
      [$player_ini, $framework_file["key_accept"], $log.last], [before, "78", "handed ui_preset, window_color, ui_chat, ui_list_box, key_accept over to the Mod Framework, but Player.ini could not forget them"])
$player_ini_writes = true
start_session($framework_file)
stages.hand_over_settings
check("the next start forgets them", [$player_ini, $log.last],
      [{ "name" => "Me", "key_chat" => "75" }, "Player.ini forgot ui_preset, window_color, ui_chat, ui_list_box, key_accept, which the Mod Framework keeps"])
