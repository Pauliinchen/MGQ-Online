#----------------------------------------------------------------
#  coop_scene_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-04: Created
#
#----------------------------------------------------------------

# Covers coop_scene.rbx: the leader's story tells the party its pictures, screen effects and the
# leader's hidden character, a member on the leader's map sees them, and the member's screen comes
# back once the story ended.

require_relative "support"

module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end
class Game_Battler; end
class Game_Action; end
class Game_ActionResult; end
class Game_BaseItem; end
module RPG
  class BaseItem; end
  class Skill < BaseItem; end
  class Item < BaseItem; end
  class State < BaseItem; end
  class Weapon < BaseItem; end
  class Armor < BaseItem; end
  EventCommand = Struct.new(:code, :indent, :parameters)
end
Tone = Struct.new(:red, :green, :blue, :gray)
Color = Struct.new(:red, :green, :blue, :alpha)

# A picture that notes what was done to it.
class Game_Picture
  attr_reader :number, :name, :done
  def initialize(number); @number = number; @name = ""; @done = []; end
  def show(name, *rest); @name = name; @done << [:show, name] + rest; end
  def move(*args); @done << [:move] + args; end
  def rotate(speed); @done << [:rotate, speed]; end
  def start_tone_change(tone, duration); @done << [:tone, tone.to_a, duration]; end
  def erase; @name = ""; @done << [:erase]; end
end
# The pictures of a screen, made as they are asked for.
class Game_Pictures
  def initialize; @data = {}; end
  def [](number); @data[number] ||= Game_Picture.new(number); end
end
# A screen that notes its effects.
class Game_Screen
  attr_reader :pictures, :done, :brightness
  def initialize; @pictures = Game_Pictures.new; @done = []; @brightness = 255; end
  def start_fadeout(duration); @brightness = 0; @done << [:fadeout, duration]; end
  def start_fadein(duration); @brightness = 255; @done << [:fadein, duration]; end
  def start_tone_change(tone, duration); @done << [:tone, tone.to_a, duration]; end
  def start_flash(color, duration); @done << [:flash, color.to_a, duration]; end
  def start_shake(power, speed, duration); @done << [:shake, power, speed, duration]; end
  def clear_flash; @done << [:clear_flash]; end
  def clear_shake; @done << [:clear_shake]; end
end
class Game_Interpreter
  def initialize(depth = 0); @depth = depth; @list = []; @index = 0; end
  def execute_command; end
  attr_accessor :list, :index
end
class Game_Player; attr_accessor :transparent; end
class Game_Map
  attr_accessor :map_id, :interpreter
  attr_reader :screen
  def initialize; @map_id = 7; @screen = Game_Screen.new; @interpreter = Game_Interpreter.new; end
  def update(main = false); end
end
class Scene_Map; end
module SceneManager; class << self; attr_accessor :scene; end; end
module DataManager; def self.extract_save_contents(contents); end; end
module MGQ_MpOverworldSync; module Peers; Peer = Struct.new(:seat, :state); end; end
module MGQ_MpCoop
  def self.route(field, &handler); ($routes ||= {})[field] = handler; end
  def self.tell(seat, field, value, fields = {}); ($sent ||= []) << [seat, { field => value }.merge(fields)]; true; end
end
module MGQ_MpCoopEvents
  def self.story_playing?; $playing; end
  def self.leading?; $leader == :me; end
  def self.leader; $leader; end
end

module MGQ_MpCoopGather; def self.story_map?(map_id); map_id == $game_map.map_id || map_id == $following; end; end
load_script "battles_sync_wire"
load_script "coop_scene"

$game_map = Game_Map.new
$game_player = Game_Player.new
SceneManager.scene = Scene_Map.new
scene = MGQ_MpCoopScene
main = $game_map.interpreter

# The leader's game tells the story's changes.
$leader = :me
$playing = true
$sent = []
main.execute_command
$game_map.screen.pictures[3].show("story_cg", 0, 0, 0, 100, 100, 255, 0)
$game_map.screen.start_tone_change(Tone.new(-68, -68, 0, 0), 30)
$game_player.transparent = true
check("the story's picture, tint and hidden leader go to the party",
      $sent.map { |seat, fields| [seat, fields["pscene"], fields["map"]] },
      [[-1, "picture.show", 7], [-1, "screen.start_tone_change", 7], [-1, "player.transparent", 7]])
$sent.clear
parallel = Game_Interpreter.new
parallel.execute_command
$game_map.screen.pictures[20].show("hud", 0, 0, 0, 100, 100, 255, 0)
check("a parallel event's picture, such as the map's display, stays the leader's own", $sent, [])
main.list = [RPG::EventCommand.new(117, 0, [5])]
main.index = 0
Game_Interpreter.new(1).execute_command
$game_map.screen.pictures[4].erase
$game_map.screen.pictures[4].show("cg2", 0, 0, 0, 100, 100, 255, 0)
check("but a common event the story calls is the story's", $sent.map { |_, fields| fields["pscene"] }, ["picture.show"])
$sent.clear
main.execute_command
$playing = false
$game_map.screen.pictures[3].erase
check("nothing goes out once the story ended", $sent, [])
$playing = true
$sent.clear

# A member sees them on the leader's map.
leader = MGQ_MpOverworldSync::Peers::Peer.new(2, { "map" => "7", "telling" => "1" })
$leader = leader
$game_map = Game_Map.new
$game_player = Game_Player.new
$game_player.transparent = false
wire = MGQ_MpBattlesSync::Wire
take = lambda { |kind, args, map = 7| $routes["pscene"].call(leader, { "pscene" => kind, "map" => map.to_s, "args" => wire.line(args) }) }
take.call("picture.show", [3, "story_cg", 0, 0, 0, 100, 100, 255, 0])
take.call("screen.start_fadeout", [30])
take.call("screen.start_flash", [Color.new(255, 255, 255, 170), 20])
take.call("player.transparent", [true])
check("a member on the leader's map sees the picture", $game_map.screen.pictures[3].done, [[:show, "story_cg", 0, 0, 0, 100, 100, 255, 0]])
check("and the screen's fade and flash", $game_map.screen.done, [[:fadeout, 30], [:flash, [255, 255, 255, 170], 20]])
check("and hides their own character as the leader's is", $game_player.transparent, true)
take.call("picture.show", [5, "../../evil", 0, 0, 0, 100, 100, 255, 0])
take.call("picture.show", [101, "story_cg", 0, 0, 0, 100, 100, 255, 0])
take.call("screen.exit", [])
check("a path, a number past the pictures or an unknown method is left out",
      [$game_map.screen.pictures[5].done, $game_map.screen.pictures[101].done, $game_map.screen.done.size], [[], [], 2])
take.call("picture.show", [6, "elsewhere", 0, 0, 0, 100, 100, 255, 0], 8)
check("a change on another map is left out", $game_map.screen.pictures[6].done, [])
$following = 8
take.call("picture.show", [6, "ahead", 0, 0, 0, 100, 100, 255, 0], 8)
check("but not on the map the member follows the leader to", $game_map.screen.pictures[6].done, [[:show, "ahead", 0, 0, 0, 100, 100, 255, 0]])
$game_map.screen.pictures[6].erase
$following = nil
$game_map.update
check("while the story plays, nothing is put back", $game_map.screen.pictures[3].done.size, 1)

# Once the story ended, the member's screen comes back.
leader.state["telling"] = "0"
$game_map.update
check("then the story's pictures are erased", $game_map.screen.pictures[3].done.last, [:erase])
check("the screen comes back", $game_map.screen.done.last(4),
      [[:clear_flash], [:clear_shake], [:tone, [0, 0, 0, 0], MGQ_MpCoopScene::RESTORE_FRAMES], [:fadein, MGQ_MpCoopScene::RESTORE_FRAMES]])
check("and the member's own character shows again", $game_player.transparent, false)
done = $game_map.screen.done.size
$game_map.update
check("only once", $game_map.screen.done.size, done)
