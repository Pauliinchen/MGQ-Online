#----------------------------------------------------------------
#  player_ini_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Expected whole numbers and true or false handed over as they are
#      Paulinchen  2026-10-23: Left marking favourites and adding hidden worlds to the DLL's tests
#                            - Checked that the world lists hand their changes to the DLL and take Player.ini as it answers it
#                            - Checked the settings the DLL answers instead of the file, whose reading and writing its tests cover
#      Paulinchen  2026-10-12: Created
#
#----------------------------------------------------------------

# Covers Player.ini as the scripts see it (Multiplayer.rb's Player and Ini, which ask the DLL
# through the bridge) and the world lists world.rbx asks the DLL for: the settings kept as the DLL
# last answered them, asked again only while Player.ini cannot be read. Reading and writing the
# files, and the lists' rules, are the DLL's (PlayerIniTests, IniFileTests, LocalWorldTopicsTests).

require_relative "bridge_support"
require "tmpdir"

source = File.read(File.expand_path("../Multiplayer.rb", __dir__), encoding: "UTF-8").gsub("\r\n", "\n")
world_source = File.read(File.join(SCRIPTS_DIR, "world.rbx"), encoding: "UTF-8").gsub("\r\n", "\n")

$log = []
# Stands in for Multiplayer.rb, around the Bridge, Ini and Player modules taken from it.
module MGQ_Multiplayer
  # Answers the file name as it is.
  def self.path(name); name; end
  # Stands in for the mod's log: records each line in $log.
  module Log; def self.write(message); $log << message; end; end
  # Stands in for the Discord bridge: the player's name on Discord is $discord_name.
  module Discord; def self.player_name; $discord_name; end; end
end
load_bridge
MGQ_Multiplayer.module_eval(source[/  module Ini\n.*?\n  end\n/m])
MGQ_Multiplayer.module_eval(source[/  module Player\n.*?\n  end\n/m])

# Stands in for world.rbx, around the settings and list modules taken from it.
module MGQ_MpWorld
  # Records the line in $log, tagged "world: ".
  def self.log(message); $log << "world: #{message}"; end
  # Answers the id as it is.
  def self.short(id); id; end
end
%w[Added].each do |name|
  MGQ_MpWorld.module_eval(world_source[/  module #{name}\n.*?\n  end\n/m])
end

# The DLL's side: Player.ini's settings in $ini, which it cannot read while $unreadable, the other
# files in $files (:unreadable for one that cannot be read), and how often the settings were asked.
fake = FakeBridge.new
state = lambda do
  { "values" => $unreadable ? {} : $ini.dup, "readable" => !$unreadable, "notice" => $refused ? "Player.ini could not be read." : nil, "name" => $ini["name"] || $told.last }
end
fake.answer("player.state") { |_request| $asked += 1; state.call }
fake.answer("player.change") do |changes|
  $refused = true if $unreadable
  changes.each { |key, value| $ini.delete(key); $ini[key] = value unless value.nil? } unless $unreadable
  state.call.merge("written" => !$unreadable)
end
fake.answer("player.discord") { |name| $told << name; state.call }
fake.answer("ini.read") { |request| $files[request["path"]] == :unreadable ? nil : ($files[request["path"]] || {}) }
MGQ_Multiplayer::Bridge.open(fake)

player = MGQ_Multiplayer::Player

# Starts Player and the old lists afresh, as a new session does.
fresh = lambda do
  [:@state, :@asked_at, :@noticed, :@discord_name].each { |name| player.instance_variable_set(name, nil) }
  $ini = {}
  $files = {}
  $unreadable = false
  $refused = false
  $told = []
  $asked = 0
  $log.clear
end
# Reads the request of the last call of a topic, as it crossed.
#
# @param topic [String] The topic.
# @return [Object] The request.
sent = lambda { |topic| Marshal.load(fake.calls.reverse.find { |name, _bytes| name == topic }[1]) }

fresh.call
$ini = { "name" => "X", "p.b" => "1", "p.a" => "2" }
check("the settings are asked once and then read from the copy", [player.setting("name"), player.setting("name"), player.keys_under("p."), $asked], ["X", "X", ["b", "a"], 1])
check("a change answers them anew, so the setting reads at once without asking",
      [player.store("k", "5"), player.setting("k"), $asked], [true, "5", 1])
player.change("z" => 1, "on" => true, "y" => :sym, "k" => nil)
check("a change hands whole numbers and true or false over as they are, which the DLL writes, any other value as text, nil for a setting to remove",
      sent.call("player.change"), { "z" => 1, "on" => true, "y" => "sym", "k" => nil })

fresh.call
$unreadable = true
check("while Player.ini cannot be read no setting holds and nothing is written",
      [player.setting("name"), player.readable?, player.store("k", "v"), player.setting("k")], [nil, false, false, nil])
player.setting("name")
check("and it is not asked again within a second", $asked, 1)
check("the notice of a write turned down is taken once a session", [player.take_notice, player.take_notice], ["Player.ini could not be read.", nil])
$unreadable = false
$ini = { "name" => "X" }
player.instance_variable_set(:@asked_at, Time.now - 2)
check("after it, it is asked again and holds", [player.setting("name"), player.readable?, $asked], ["X", true, 2])

fresh.call
$discord_name = "Disco"
3.times { player.name }
check("the name Discord tells is handed over once, and the name follows it", [$told, player.name], [["Disco"], "Disco"])
$discord_name = "Disco 2"
check("and again once it changes", [player.name, $told], ["Disco 2", ["Disco", "Disco 2"]])
$discord_name = nil

# The other ini files cross as text, and one that cannot be read reads as nil.
$files = { "world.ini" => :unreadable }
check("another ini file that cannot be read loads as nil and reads as empty", [MGQ_Multiplayer::Ini.load("world.ini"), MGQ_Multiplayer::Ini.read("world.ini")], [nil, {}])
fake.answer("ini.write") { |_request| true }
MGQ_Multiplayer::Ini.write("world.ini", "written" => 12, :name => "Plain")
check("and a write hands its values over as text", sent.call("ini.write"), { "path" => "world.ini", "values" => { "written" => "12", "name" => "Plain" } })
