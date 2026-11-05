#----------------------------------------------------------------
#  ui_leader_hud_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Expected the HUD's switches kept as true or false
#      Paulinchen  2026-11-01: Read the HUD from the Mod Framework's components it builds
#                            - Stood in for the emote wheel of the Mod Framework
#      Paulinchen  2026-10-31: Kept the boxes' places in the Mod Framework's settings
#      Paulinchen  2026-10-30: Dropped the checks that restate pixel positions
#      Paulinchen  2026-10-23: Kept the HUD in the corner through Player.ini, the drag gone to C#
#      Paulinchen  2026-10-13: Expected the single player row from ui_single_player.rbx, not from the HUD
#                            - Checked the HUD outside a world by its single player setting
#      Paulinchen  2026-10-12: Checked the Small HUD at the screen edges and a refused size hotkey while typing
#                            - Created
#
#----------------------------------------------------------------

# Covers the Leader HUD, ui_leader_hud.rbx: its box of the Mod Framework docked at the top left
# under the game's windows, the Formation Leader's face or figure, name, level, bars and levels'
# progress in the Large and Small sizes, the hotkey that switches them, hiding it, the map's top
# left windows moved below the docked boxes, and its Mod Config rows.

require_relative "hud_support"

# Stands in for the emote wheel, which stays shut, unless a test defined it already.
module MGQ_MpEmotes; def self.wheel; StandInWheel.new(lambda { false }); end; end unless defined?(MGQ_MpEmotes)
# Stands in for the game's names of HP and MP.
module Vocab; def self.hp_a; "HP"; end; def self.mp_a; "MP"; end; end
# Stands in for the map's top left windows, which the HUD moves by their y.
class Window_Stand
  attr_accessor :y
  # Places the window at a height.
  def initialize(y); @y = y; end
  # Answers that the window is never disposed.
  def disposed?; false; end
end
# Gives the message stand-in whether it shows and where.
class Game_Message; attr_accessor :visible, :position; end
# Stands in for a Mod Config Remake that reads the rows the mod keeps from the mod.
module ModConfigRemake; def self.mod_stored?(_key); true; end; end
# The Mod Config's rows, the last of them the Return row, which the mod's rows go before.
NWConst::Config::MOD_CONTENTS = [{ :key => :return }] unless NWConst::Config.const_defined?(:MOD_CONTENTS)

# The Formation Leader: a character at base level 30 halfway to the next, at the job's highest level,
# and just come to a race level.
class Leader
  attr_accessor :hp, :mp, :name
  # Makes Alice with 189 HP and 40 MP.
  def initialize; @hp = 189; @mp = 40; @name = "Alice"; end
  # Answers the character's id.
  def id; 1; end
  # Answers the face sheet.
  def face_name; "alice_fc1"; end
  # Answers the face's index on its sheet.
  def face_index; 5; end
  # Answers the character sheet.
  def character_name; "Actor1"; end
  # Answers the character's index on its sheet.
  def character_index; 5; end
  # Answers the base level.
  def base_level; 30; end
  # Answers the most HP.
  def mhp; 252; end
  # Answers the most MP.
  def mmp; 80; end
  # Answers the share of HP left.
  def hp_rate; @hp.to_f / mhp; end
  # Answers the share of MP left.
  def mp_rate; @mp.to_f / mmp; end
  # Answers the job's id.
  def class_id; 7; end
  # Answers the race's id.
  def tribe_id; 9; end
  # Answers the base level's experience.
  def base_exp; 1500; end
  # Answers the job's experience.
  def class_exp; 9000; end
  # Answers the race's experience.
  def tribe_exp; 400; end
  # Answers whether a kind of level is at its highest, which only the job's is.
  def max_level?(kind); kind == :class; end
  # Answers the experience the current base or race level starts at.
  def current_level_exp(kind); { :base => 1000, :tribe => 400 }[kind]; end
  # Answers the experience the next base or race level starts at.
  def next_level_exp(kind); { :base => 2000, :tribe => 800 }[kind]; end
end
leader = Leader.new
$game_party.define_singleton_method(:leader) { $leader }
$leader = leader

load_script "ui_leader_hud"

hud = MGQ_MpLeaderHud
ui = Mod_Framework::UI
view = hud::View.new
view.update
root = view.root
gauges = lambda { parts_of_kind(root, ui::Gauge) }
picture = lambda { parts_of_kind(root, ui::Picture).first }

check("its rows in the Mod Config: on and off, then the size, both kept by the mod",
      NWConst::Config::MOD_CONTENTS.select { |row| row[:mod_stored] }.map { |row| [row[:key], row[:values].call] }.last(2),
      [[:mp_leader_hud, ["On", "Off"]], [:mp_leader_hud_size, ["Large", "Small"]]])
check("both in the Settings, the single player row left to ui_single_player.rbx",
      [NWConst::Config::MOD_CONTENTS.select { |row| row[:mod_stored] }.last(2).map { |row| row[:name] },
       NWConst::Config::MOD_CONTENTS.any? { |row| row[:key] == hud::SP_SHOWN_OPTION }],
      [[MGQ_Multiplayer::OPTION_PREFIX + hud::SHOWN_OPTION_NAME, MGQ_Multiplayer::OPTION_PREFIX + hud::SIZE_OPTION_NAME], false])

# The Large size: the face, the name, the level, both bars with their texts and the levels'
# progress, in a box docked at the top left under the game's windows.
check("it opens as the movable Leader HUD at the top left, before the notices, under the game's windows, the pointer passing but for its parts",
      [root.open?, root.id, root.place_name, root.dock, root.dock_order, root.under_windows, root.movable, root.resizable, root.mouse],
      [true, :leader_hud, "Leader HUD", :top_left, 10, true, true, false, :parts])
check("in the Large size until the player picks another: 240 wide, the leader's face in its square",
      [root.width, picture.call.face.face_name, picture.call.face.face_index, picture.call.figure], [240, "alice_fc1", 5, nil])
check("the name and the base level", texts_of(root), ["Alice", "Lv 30"])
check("the HP bar three quarters full in red with its name and numbers, the MP bar half full in blue",
      gauges.call[0, 2].map { |gauge| [gauge.rate, gauge.label, gauge.value] } + [gauges.call[0].colors, gauges.call[1].colors],
      [[0.75, "HP", "189 / 252"], [0.5, "MP", "40 / 80"], hud::View::HP_COLORS, hud::View::MP_COLORS])
check("the base level half done, the job at its highest full, the race just begun empty",
      gauges.call[2, 3].map { |gauge| [gauge.rate, gauge.colors] }, hud::View::EXP_KINDS.zip([0.5, 1.0, 0.0]).map { |kind, rate| [rate, hud::View::EXP_COLORS[kind]] })

# Nothing is set anew while nothing changed; a change of HP sets the bar.
name_label = part_with_text(root, "Alice")
sets = 0
name_label.define_singleton_method(:text=) { |value| sets += 1; super(value) }
view.update
check("a frame where nothing changed sets nothing", sets, 0)
leader.hp = 63
view.update
check("a change of HP sets the bar's share and numbers", [gauges.call[0].rate, gauges.call[0].value], [0.25, "63 / 252"])

# The Small size: the figure and bars without texts, in the same box.
hud.resize("Small")
view.update
check("the Small size keeps Player.ini's choice: 170 wide, the leader's figure in the square, the bars without texts",
      [$player_ini["leader_hud_size"], root.width, picture.call.figure.character_name, picture.call.face, gauges.call[0].label, gauges.call[0].value],
      ["Small", 170, "Actor1", nil, nil, nil])
check("in the same box, the name and level still showing", [view.root.equal?(root), root.open?, texts_of(root)], [true, true, ["Alice", "Lv 30"]])
hud.resize("Large")
view.update

# The size's hotkey switches the sizes, but not while the player types.
$sounds = []
$pressed = 0x48
hud.on_map
check("H makes it small, kept in Player.ini, with the cursor's sound", [hud.size, $player_ini["leader_hud_size"], $sounds], ["Small", "Small", ["cursor"]])
$pressed = 0x48
hud.on_map
check("and large again", hud.size, "Large")
MGQ_MpChat.singleton_class.send(:alias_method, :leader_hud_test_typing?, :typing?)
MGQ_MpChat.define_singleton_method(:typing?) { true }
logged = []
MGQ_Multiplayer::Log.define_singleton_method(:write) { |line| logged << line }
$mgq_text_input = true
$pressed = 0x48
hud.on_map
$mgq_text_input = nil
MGQ_Multiplayer::Log.define_singleton_method(:write) { |line| puts "  log: #{line}" }
check("while the chat box is open the key changes nothing and the letter typed stays out of the log", [hud.size, logged], ["Large", []])
MGQ_MpChat.singleton_class.send(:alias_method, :typing?, :leader_hud_test_typing?)

# The map's top left windows move below the boxes docked there.
scene = Scene_Map.new
name_window = Window_Stand.new(0)
medal_window = Window_Stand.new(0)
scene.instance_variable_set(:@map_name_window, name_window)
scene.instance_variable_set(:@gain_medal_window, medal_window)
SceneManager.scene = scene
$docked_room[:top_left] = 92
hud.lower_windows
check("the map's name and the medal just won move 4 pixels below the boxes docked at the top left", [name_window.y, medal_window.y], [96, 96])
$docked_room[:top_left] = 0
hud.lower_windows
check("and back where the game put them once nothing is docked there", [name_window.y, medal_window.y], [0, 0])

# A message at the top, turning the HUD off and a party without a leader hide it.
$game_message.visible = true
$game_message.position = 0
check("a message at the top hides it", [hud.shows?, hidden_root?(root)], [false, true])
$game_message.visible = false
check("it shows again once the message is gone", [hud.shows?, hidden_root?(root)], [true, false])
hud.show(false)
check("turned off it hides, kept in Player.ini", [hidden_root?(root), $player_ini["leader_hud"]], [true, false])
logged = []
MGQ_Multiplayer::Log.define_singleton_method(:write) { |line| logged << line }
$pressed = 0x48
hud.on_map
MGQ_Multiplayer::Log.define_singleton_method(:write) { |line| puts "  log: #{line}" }
check("while it is off the key changes nothing and the log says why",
      [hud.size, logged.grep(/ignored/)], ["Large", ["keys: hotkey H (Leader HUD Size) ignored: the HUD is off"]])
hud.show(true)
$leader = nil
check("a party without a leader shows nothing", hidden_root?(root), true)
$leader = leader

# Outside a world the single player row decides, inside a world the Settings row.
in_world = MGQ_MpOverworldSync.method(:in_world?)
hud.show(false)
MGQ_MpOverworldSync.define_singleton_method(:in_world?) { false }
check("outside a world the single player row follows the Settings row until the player sets it", [hud.on?, hidden_root?(root)], [false, true])
hud.show_sp(true)
check("set, the single player row decides whatever the Settings row says", [hud.on?, hidden_root?(root), $player_ini["sp_leader_hud"]], [true, false, true])
hud.show_sp(false)
check("turned off there it hides, kept in Player.ini apart from the Settings row", [hud.on?, hidden_root?(root), $player_ini["sp_leader_hud"]], [false, true, false])
check("so the size hotkey changes nothing there", hud.busy_reason, "the HUD is off")
hud.show(true)
MGQ_MpOverworldSync.define_singleton_method(:in_world?, in_world)
check("inside a world the Settings row decides, whatever the single player row says", [hud.on?, hidden_root?(root)], [true, false])
hud.show_sp(true)

# The map's sprites open the HUD and close it as they go; the map behind a menu shows none.
spriteset = Spriteset_Map.new
spriteset.update
shown = spriteset.instance_variable_get(:@mgq_mp_leader_hud)
spriteset.dispose
check("the map's sprites open the HUD and close it with them", [shown.root.id, shown.root.open?, spriteset.instance_variable_get(:@mgq_mp_leader_hud)], [:leader_hud, false, nil])
behind = Spriteset_Map.new
behind.define_singleton_method(:mgq_mp_hud?) { false }
behind.update
check("the map behind a menu opens none", behind.instance_variable_get(:@mgq_mp_leader_hud), nil)
view.close
check("closed, its box is gone", root.open?, false)
