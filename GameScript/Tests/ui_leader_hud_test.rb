#----------------------------------------------------------------
#  ui_leader_hud_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Typed through a text box of the Mod Framework instead of the old typing flag
#                            - Dropped the stand-in for Mod Config Remake, which nothing reads
#      Paulinchen  2026-11-06: Left what the HUD shows to the in-game suite, checking what its bars read
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

# Covers the Leader HUD, ui_leader_hud.rbx: what its bars read of the Formation Leader, the hotkey
# that switches its sizes, hiding it, the map's top left windows moved below the parts there, and
# its Mod Config rows. What it shows is the in-game suite's.

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

check("its rows in the Mod Config: on and off, then the size, both kept by the mod",
      NWConst::Config::MOD_CONTENTS.select { |row| row[:mod_stored] }.map { |row| [row[:key], row[:values].call] }.last(2),
      [[:mp_leader_hud, ["On", "Off"]], [:mp_leader_hud_size, ["Large", "Small"]]])
check("both in the Settings, the single player row left to ui_single_player.rbx",
      [NWConst::Config::MOD_CONTENTS.select { |row| row[:mod_stored] }.last(2).map { |row| row[:name] },
       NWConst::Config::MOD_CONTENTS.any? { |row| row[:key] == hud::SP_SHOWN_OPTION }],
      [[MGQ_Multiplayer::OPTION_PREFIX + hud::SHOWN_OPTION_NAME, MGQ_Multiplayer::OPTION_PREFIX + hud::SIZE_OPTION_NAME], false])

# What the bars read of the Formation Leader.
check("the HP bar three quarters full with its numbers, the MP bar half full",
      [hud.rate(:hp), hud.numbers(:hp), hud.rate(:mp), hud.numbers(:mp)], [0.75, "189 / 252", 0.5, "40 / 80"])
check("the base level half done, the job at its highest full, the race just begun empty",
      [:base, :class, :tribe].map { |kind| hud.exp_rate(leader, kind) }, [0.5, 1.0, 0.0])
look = hud.look
leader.hp = 63
check("a change of HP renders nothing anew, the bar reading it", [hud.look.equal?(look), hud.rate(:hp)], [true, 0.25])

# The size's hotkey switches the sizes, but not while the player types.
$sounds = []
$pressed = 0x48
hud.on_map
check("H makes it small, kept in Player.ini, with the cursor's sound, and renders it anew",
      [hud.size, $player_ini["leader_hud_size"], $sounds, hud.look.equal?(look)], ["Small", "Small", ["cursor"], false])
$pressed = 0x48
hud.on_map
check("and large again", hud.size, "Large")
MGQ_MpChat.singleton_class.send(:alias_method, :leader_hud_test_typing?, :typing?)
MGQ_MpChat.define_singleton_method(:typing?) { true }
logged = []
MGQ_Multiplayer::Log.define_singleton_method(:write) { |line| logged << line }
$pressed = 0x48
while_typing { hud.on_map }
MGQ_Multiplayer::Log.define_singleton_method(:write) { |line| puts "  log: #{line}" }
check("while the chat box is open the key changes nothing and the letter typed stays out of the log", [hud.size, logged], ["Large", []])
MGQ_MpChat.singleton_class.send(:alias_method, :typing?, :leader_hud_test_typing?)

# The map's top left windows move below the parts there.
scene = Scene_Map.new
name_window = Window_Stand.new(0)
medal_window = Window_Stand.new(0)
scene.instance_variable_set(:@map_name_window, name_window)
scene.instance_variable_set(:@gain_medal_window, medal_window)
SceneManager.scene = scene
$docked_room[:top_left] = 92
hud.lower_windows
check("the map's name and the medal just won move 4 pixels below the parts at the top left", [name_window.y, medal_window.y], [96, 96])
$docked_room[:top_left] = 0
hud.lower_windows
check("and back where the game put them once nothing takes room there", [name_window.y, medal_window.y], [0, 0])

# A message at the top, turning the HUD off and a party without a leader hide it.
$game_message.visible = true
$game_message.position = 0
check("a message at the top hides it", hud.shows?, false)
$game_message.visible = false
check("it shows again once the message is gone", hud.shows?, true)
hud.show(false)
check("turned off it hides, kept in Player.ini", [hud.shows?, $player_ini["leader_hud"]], [false, false])
logged = []
MGQ_Multiplayer::Log.define_singleton_method(:write) { |line| logged << line }
$pressed = 0x48
hud.on_map
MGQ_Multiplayer::Log.define_singleton_method(:write) { |line| puts "  log: #{line}" }
check("while it is off the key changes nothing and the log says why",
      [hud.size, logged.grep(/ignored/)], ["Large", ["keys: hotkey H (Leader HUD Size) ignored: the HUD is off"]])
hud.show(true)
$leader = nil
check("a party without a leader shows nothing", hud.shows?, false)
$leader = leader

# Outside a world the single player row decides, inside a world the Settings row.
in_world = MGQ_MpOverworldSync.method(:in_world?)
hud.show(false)
MGQ_MpOverworldSync.define_singleton_method(:in_world?) { false }
check("outside a world the single player row follows the Settings row until the player sets it", [hud.on?, hud.shows?], [false, false])
hud.show_sp(true)
check("set, the single player row decides whatever the Settings row says", [hud.on?, hud.shows?, $player_ini["sp_leader_hud"]], [true, true, true])
hud.show_sp(false)
check("turned off there it hides, kept in Player.ini apart from the Settings row", [hud.on?, hud.shows?, $player_ini["sp_leader_hud"]], [false, false, false])
check("so the size hotkey changes nothing there", hud.busy_reason, "the HUD is off")
hud.show(true)
MGQ_MpOverworldSync.define_singleton_method(:in_world?, in_world)
check("inside a world the Settings row decides, whatever the single player row says", [hud.on?, hud.shows?], [true, true])
