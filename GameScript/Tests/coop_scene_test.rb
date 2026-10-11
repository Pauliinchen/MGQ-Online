#----------------------------------------------------------------
#  coop_scene_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-11: Checked that a scene switch, though each player's own, reaches the viewers, is not taken as the world's and goes back once the viewer no longer sees the scene
#                            - Checked that a viewer the story brought to another map keeps the character the story showed
#                            - Checked that the viewer's character skips a blocked step of the teller's route and walks none of it once the viewer no longer sees the scene
#                            - Checked that the story's music, sounds and fades and the map's tileset, battle backgrounds and parallax reach the viewers, never a path, a file or a tileset the game lacks, the game's defaults filled in, and that a viewer away from the teller's map screen hears the music once there and none of the sound effects
#                            - Checked that the player's route, the camera's place and the map's zoom reach the viewers, whose own character walks the route without starting what it touches
#                            - Checked that a viewer the story values moved on keeps watching the telling, on the teller's side and their own, also with values between the story's events on two maps
#                            - Checked that a Raid World teller tells the story values, move routes without scripts, balloons and erasures, and that a viewer takes the values as the world, the routes without what this game lacks and the effects on the right characters
#      Paulinchen  2026-10-09: Checked that a Raid World's scene goes to several viewers in one message
#                            - Stood in for MGQ_MpOverworldSync::Peers.all, among whom the teller is found now
#      Paulinchen  2026-10-08: Checked a Raid World: the player telling the story shows its scene to the players on the map whose story matches, through the map's gate, and sees only the teller's whose story matches theirs
#                            - Stood in for the players the story took along, of coop_gather.rbx
#      Paulinchen  2026-10-07: Checked that the scene goes to the members who follow the story alone, and that one who plays their own sees none of it
#      Paulinchen  2026-10-06: Covered the first change after the party gathered, the member's own tint coming back, the grace before the leader's state and picture names with dots
#      Paulinchen  2026-10-04: Created
#
#----------------------------------------------------------------

# Covers coop_scene.rbx: the leader's story tells the party its pictures, screen effects and the
# leader's hidden character, a member on the leader's map sees them, and the member's screen comes
# back once the story ended. In a Raid World the teller on the map shows it to everyone there whose
# story matches.

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
  # A move route, with the game's defaults.
  class MoveRoute
    attr_accessor :repeat, :skippable, :wait, :list
    def initialize; @repeat = true; @skippable = false; @wait = false; @list = [MoveCommand.new]; end
  end
  # A move route's command.
  class MoveCommand
    attr_accessor :code, :parameters
    def initialize(code = 0, parameters = []); @code = code; @parameters = parameters; end
  end
  # A sound, which notes what is played, stopped and faded.
  class SE
    attr_reader :name, :volume, :pitch
    def initialize(name = "", volume = 100, pitch = 100); @name = name; @volume = volume; @pitch = pitch; end
    def play(*pos); ($played ||= []) << [self.class.name.split("::").last, @name, @volume, @pitch, *pos]; end
    def self.stop; ($played ||= []) << [name.split("::").last, :stop]; end
    def self.fade(time); ($played ||= []) << [name.split("::").last, :fade, time]; end
  end
  class BGM < SE; end
  class BGS < SE; end
  class ME < SE; end
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
  attr_reader :pictures, :done, :brightness, :tone
  def initialize; @pictures = Game_Pictures.new; @done = []; @brightness = 255; @tone = Tone.new(0, 0, 0, 0); end
  def start_fadeout(duration); @brightness = 0; @done << [:fadeout, duration]; end
  def start_fadein(duration); @brightness = 255; @done << [:fadein, duration]; end
  def start_tone_change(tone, duration); @tone = tone; @done << [:tone, tone.to_a, duration]; end
  def start_flash(color, duration); @done << [:flash, color.to_a, duration]; end
  def start_shake(power, speed, duration); @done << [:shake, power, speed, duration]; end
  def clear_flash; @done << [:clear_flash]; end
  def clear_shake; @done << [:clear_shake]; end
end
class Game_Interpreter
  def initialize(depth = 0); @depth = depth; @list = []; @index = 0; end
  def update; @work.call if @work; end
  attr_accessor :list, :index, :work
  def map_zoom(rate = 100); $game_system.zoom_mode = rate; end
end
# The story's switches, variables and self switches.
class Game_Switches; def initialize; @data = []; end; def [](id); @data[id]; end; def []=(id, value); @data[id] = value; end; end
class Game_Variables; def initialize; @data = []; end; def [](id); @data[id]; end; def []=(id, value); @data[id] = value; end; end
class Game_SelfSwitches; def initialize; @data = {}; end; def [](key); @data[key]; end; def []=(key, value); @data[key] = value; end; end
# Characters that note their routes, animations, balloons and erasure.
class Game_CharacterBase; attr_accessor :animation_id, :balloon_id; end
class Game_Character < Game_CharacterBase; attr_reader :route; def force_move_route(route); @route = route; end; def restore_move_route; $restored = true; $forcing = false; end; end
class Game_Event < Game_Character; attr_reader :id, :erased; def initialize(id); @id = id; end; def erase; @erased = true; end; end
class Game_Player < Game_Character
  attr_accessor :transparent
  def move_route_forcing; $forcing; end
  def update_nonmoving(_last_moving); $nonmoving = true; end
  def check_event_trigger_touch(_x, _y); $touched = true; end
  def x; 3; end
  def y; 4; end
  def center(x, y); $game_map.set_display_pos(x - 8.5, y - 6.5); end
  def update; end
end
# The game's map zoom.
class Game_System; attr_accessor :zoom_mode; def initialize; @zoom_mode = 100; end; end
class Game_Map
  attr_accessor :map_id, :interpreter, :events
  attr_reader :screen
  def initialize; @map_id = 7; @screen = Game_Screen.new; @interpreter = Game_Interpreter.new; @events = {}; end
  def update(main = false); end
  def change_tileset(id); (@looks ||= []) << [:tileset, id]; end
  def change_battleback(one, two); (@looks ||= []) << [:battleback, one, two]; end
  def change_parallax(*args); (@looks ||= []) << [:parallax, *args]; end
  attr_reader :looks
  def display_x; @display_x || 0.0; end
  def display_y; @display_y || 0.0; end
  def set_display_pos(x, y); @display_x = x; @display_y = y; end
end
class Scene_Map; end
# The game's Audio, which notes its calls.
module Audio
  %w(bgm_play bgm_stop bgm_fade bgs_play bgs_stop bgs_fade me_play me_stop me_fade se_play se_stop).each do |call|
    define_singleton_method(call) { |*args| ($audio ||= []) << [call, *args] }
  end
end
module SceneManager; class << self; attr_accessor :scene; end; end
module DataManager; def self.extract_save_contents(contents); end; end
module MGQ_MpOverworldSync; module Peers; Peer = Struct.new(:seat, :state); end; end
module MGQ_MpCoop
  def self.route(field, &handler); ($routes ||= {})[field] = handler; end
  def self.tell(seat, field, value, fields = {}); ($sent ||= []) << [seat, { field => value }.merge(fields)]; true; end
  def self.party_leader; $leader; end
  def self.party_leading?; $leader == :me; end
end
module MGQ_MpCoopEvents
  def self.story_playing?; $playing; end
  def self.leading_story?; $leader == :me && !$followers.empty?; end
  def self.following?; $follows != false; end
end
# The members who follow the leader's story, as coop_story.rbx tells them.
module MGQ_MpCoopStory; def self.synced_members; $followers; end; end
$followers = [MGQ_MpOverworldSync::Peers::Peer.new(4, { "name" => "Friend" })]
module Graphics; def self.frame_count; $frame_count; end; end

module MGQ_MpCoopGather; def self.story_map?(map_id); map_id == $game_map.map_id || map_id == $following; end; def self.taken_along; []; end; end
load_script "battles_sync_wire"
load_script "coop_scope"
load_script "coop_scene"

$game_map = Game_Map.new
$game_player = Game_Player.new
SceneManager.scene = Scene_Map.new
$frame_count = 1000
main = $game_map.interpreter
pictures = $game_map.screen.pictures
run = lambda { |interpreter, work| interpreter.work = work; interpreter.update; interpreter.work = nil }

# The leader's game tells the story's changes.
$leader = :me
$playing = true
$sent = []
run.call(main, lambda do
  pictures[3].show("story_cg", 0, 0, 0, 100, 100, 255, 0)
  $game_map.screen.start_tone_change(Tone.new(-68, -68, 0, 0), 30)
  $game_player.transparent = true
end)
check("the story's picture, tint and hidden leader go to the members who follow the story",
      $sent.map { |seat, fields| [seat, fields["pscene"], fields["map"]] },
      [[4, "picture.show", 7], [4, "screen.start_tone_change", 7], [4, "player.transparent", 7]])
$sent.clear
following = $followers
$followers = []
run.call(main, lambda { pictures[5].show("story_cg", 0, 0, 0, 100, 100, 255, 0) })
check("with no member following it, the story's scene goes to nobody", $sent, [])
$followers = following
$sent.clear
parallel = Game_Interpreter.new
run.call(parallel, lambda { pictures[20].show("hud", 0, 0, 0, 100, 100, 255, 0) })
check("a parallel event's picture, such as the map's display, stays the leader's own", $sent, [])
run.call(main, lambda do
  Game_Interpreter.new(1)
  pictures[4].erase
  pictures[4].show("cg2", 0, 0, 0, 100, 100, 255, 0)
end)
check("but a common event the story calls is the story's", $sent.map { |_, fields| fields["pscene"] }, ["picture.show"])
$sent.clear
run.call(parallel, lambda {})
run.call(main, lambda { $game_map.screen.start_fadeout(30) })
check("the story's first change after parallel events ran meanwhile, as while the party gathers, goes out",
      $sent.map { |_, fields| fields["pscene"] }, ["screen.start_fadeout"])
$sent.clear
pictures[8].show("menu", 0, 0, 0, 100, 100, 255, 0)
check("a change outside every interpreter is the leader's own", $sent, [])
$playing = false
run.call(main, lambda { pictures[3].erase })
check("nothing goes out once the story ended", $sent, [])
$playing = true
$sent.clear

# A member sees them on the leader's map.
leader = MGQ_MpOverworldSync::Peers::Peer.new(2, { "map" => "7", "telling" => "1" })
$leader = leader
$game_map = Game_Map.new
$game_player = Game_Player.new
$game_player.transparent = false
$game_map.screen.start_tone_change(Tone.new(-34, -34, -34, 0), 0)
$game_map.screen.done.clear
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
take.call("picture.show", [9, "a..b", 0, 0, 0, 100, 100, 255, 0])
take.call("picture.show", [101, "story_cg", 0, 0, 0, 100, 100, 255, 0])
take.call("screen.exit", [])
check("a path, a number past the pictures or an unknown method is left out",
      [$game_map.screen.pictures[5].done, $game_map.screen.pictures[9].done, $game_map.screen.pictures[101].done, $game_map.screen.done.size],
      [[], [], [], 2])
take.call("picture.show", [10, "ev_aguni._hb1", 0, 0, 0, 100, 100, 255, 0])
check("a picture whose name holds a dot shows", $game_map.screen.pictures[10].done.size, 1)
$follows = false
take.call("picture.show", [11, "story_cg", 0, 0, 0, 100, 100, 255, 0])
check("a member who plays their own story sees none of the leader's scene", [$game_map.screen.pictures[11].done, MGQ_MpCoopScene.watching?], [[], false])
$follows = true
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
check("right after a change, the leader's state may still follow, so nothing is put back yet", $game_map.screen.pictures[3].done.size, 1)
$frame_count += MGQ_MpCoopScene::STATE_GRACE_FRAMES
$game_map.update
check("then the story's pictures are erased", $game_map.screen.pictures[3].done.last, [:erase])
check("the screen comes back with the member's own tint", $game_map.screen.done.last(4),
      [[:clear_flash], [:clear_shake], [:tone, [-34, -34, -34, 0], MGQ_MpCoopScene::RESTORE_FRAMES], [:fadein, MGQ_MpCoopScene::RESTORE_FRAMES]])
check("and the member's own character shows again", $game_player.transparent, false)
done = $game_map.screen.done.size
$game_map.update
check("only once", $game_map.screen.done.size, done)

# A member the story brought to another map keeps the story's last tint and shown character, as a
# new game's hidden start the story ended.
leader.state["telling"] = "1"
$game_player.transparent = true
take.call("screen.start_tone_change", [Tone.new(-68, -68, 0, 0), 30])
take.call("player.transparent", [false])
$game_map.map_id = 8
leader.state["telling"] = "0"
$frame_count += MGQ_MpCoopScene::STATE_GRACE_FRAMES
$game_map.update
check("on another map the story's tint stays", $game_map.screen.done.last(3), [[:tone, [-68, -68, 0, 0], 30], [:clear_flash], [:clear_shake]])
check("and the character the story showed stays shown", $game_player.transparent, false)

# In a Raid World the player telling the story on the map shows it to everyone there whose story matches.
module MGQ_MpWorld; def self.raid?; $raid; end; end
module MGQ_MpOverworldSync
  def self.in_world?; true; end
  def self.who(peer); peer == :me ? "the player" : peer.state["name"].to_s; end
  def self.tell(seat, fields); $told << [seat, fields]; true; end
  module Me; def self.map_since; 2000; end; def self.id; "me"; end; end
  module Peers
    def self.present; $peers; end
    def self.all; $peers; end
    def self.on_this_map?(peer); peer.state["map"].to_i == $game_map.map_id; end
  end
end
module MGQ_MpCoopEvents
  def self.telling?; $playing; end
  def self.leading_story?; MGQ_MpCoop::Scope.leads_story?; end
  def self.told_markers; $playing ? [12, 0, 0, 0] : nil; end
end
# How far each story is, as coop_story.rbx reads it.
module MGQ_MpCoopStory
  def self.read_markers(text); values = text.to_s.split(","); values.size == 4 ? values.map(&:to_i) : nil; end
  def self.own_markers; $own_markers; end
end
$raid = true
$told = []
$game_variables = {}
$game_map = Game_Map.new
$game_player = Game_Player.new
main = $game_map.interpreter
matching = MGQ_MpOverworldSync::Peers::Peer.new(4, { "name" => "Match", "id" => "m", "map" => "7", "sm" => "12,0,0,0", "since" => "3000" })
behind = MGQ_MpOverworldSync::Peers::Peer.new(5, { "name" => "Behind", "id" => "b", "map" => "7", "sm" => "8,0,0,0", "since" => "3000" })
away = MGQ_MpOverworldSync::Peers::Peer.new(6, { "name" => "Away", "id" => "a", "map" => "9", "sm" => "12,0,0,0", "since" => "3000" })
$peers = [matching, behind, away]
$playing = true
run.call(main, lambda { $game_map.screen.pictures[3].show("story_cg", 0, 0, 0, 100, 100, 255, 0) })
check("the teller's scene goes through the map's gate to the players on the map whose story matches",
      $told.map { |seat, fields| [seat, fields["map_pscene"], fields["mmap"]] }, [[4, "picture.show", 7]])
second = MGQ_MpOverworldSync::Peers::Peer.new(7, { "name" => "Second", "id" => "s", "map" => "7", "sm" => "12,0,0,0", "since" => "3000" })
$peers = [matching, behind, second]
$told.clear
run.call(main, lambda { $game_map.screen.pictures[3].show("story_cg", 0, 0, 0, 100, 100, 255, 0) })
check("to several of them in one message that names them",
      $told.map { |seat, fields| [seat, fields["map_pscene"], fields["mto"]] }, [[-1, "picture.show", "m,s"]])

$playing = false
$own_markers = [12, 0, 0, 0]
$game_map = Game_Map.new
teller = MGQ_MpOverworldSync::Peers::Peer.new(2, { "name" => "Teller", "id" => "t", "map" => "7", "telling" => "1", "tsm" => "12,0,0,0", "sm" => "13,0,0,0", "since" => "1000" })
$peers = [teller, matching]
show = lambda do |sender, number|
  MGQ_MpCoop.take_map("pscene", sender, { "map_pscene" => "picture.show", "mmap" => "7", "map" => "7", "args" => wire.line([number, "story_cg", 0, 0, 0, 100, 100, 255, 0]) })
end
show.call(teller, 3)
check("a player whose story is where the teller's was as the telling started sees the scene, though the teller's moved on",
      [$game_map.screen.pictures[3].done.size, MGQ_MpCoopScene.watching?], [1, true])
show.call(matching, 4)
check("but none from a player who does not tell it", $game_map.screen.pictures[4].done, [])
$own_markers = [8, 0, 0, 0]
show.call(teller, 5)
check("a player whose story does not match sees none of it", [$game_map.screen.pictures[5].done, MGQ_MpCoopScene.watching?], [[], false])
$raid = false

# In a Raid World the teller's story values, the move routes it gives the map's events and the
# effects it shows on them reach the viewers, and the viewers' games take the values as the world's.
module MGQ_MpWorldStory
  def self.personal?(kind, key); kind == 0 && [4, 2029].include?(key); end
  def self.mirrored(kind, key, value); ($mirrored ||= []) << [kind, key, value]; end
end
module MGQ_MpStoryState; def self.known_id?(_kind, id); id < 5000; end; def self.scene_switch?(id); id == 2029; end; end
module MGQ_MpOverworld; def self.graphic?(_folder, name); name == "Actor1"; end; end
$data_animations = Array.new(10)
$raid = true
$playing = true
$own_markers = [12, 0, 0, 0]
$game_map = Game_Map.new
$game_player = Game_Player.new
$game_switches = Game_Switches.new
$game_variables = Game_Variables.new
$game_self_switches = Game_SelfSwitches.new
main = $game_map.interpreter
mover = Game_Event.new(12)
$game_map.events = { 12 => mover }
$peers = [matching]
$told.clear
route = RPG::MoveRoute.new
route.repeat = false
route.list = [RPG::MoveCommand.new(1), RPG::MoveCommand.new(45, ["$game_switches[1] = true"]), RPG::MoveCommand.new(41, ["Actor1", 2]),
              RPG::MoveCommand.new(44, [RPG::SE.new("Door", 80, 100)]), RPG::MoveCommand.new(0)]
run.call(main, lambda do
  $game_switches[40] = true
  $game_switches[4] = true
  $game_switches[40] = true
  $game_variables[1001] = 41
  $game_switches[2029] = true
  $game_variables[1002] = [1, 2]
  $game_self_switches[[7, 12, "A"]] = true
  mover.force_move_route(route)
  mover.balloon_id = 1
  mover.erase
end)
$game_map.update
told = lambda { |kind| $told.select { |_, fields| fields["map_pscene"] == kind }.map { |_, fields| wire.parse(fields["args"]) } }
check("the teller's story values go out once at the frame's end, what is each player's own and a list left out, but a scene switch",
      told.call("story.values"), [[[0, 40, true], [1, 1001, 41], [0, 2029, true], [2, [7, 12, "A"], true]]])
check("the move route goes out without its script, its sound by its file",
      told.call("event.route"), [[12, false, false, [[1], [41, "Actor1", 2], [44, "Door", 80, 100], [0]]]])
check("so do the balloon and the erasure", [told.call("event.balloon"), told.call("event.erase")], [[[12, 1]], [[12]]])
$told.clear
$playing = false
$game_switches[41] = true
$game_map.update
$told.clear
$playing = true
run.call(main, lambda do
  Audio.bgm_play("Audio/BGM/Story", 90, 100, 0)
  Audio.se_play("Audio/SE/Door", 80, 110)
  Audio.se_play("Audio/SE/Knock")
  Audio.bgs_play("Audio/BGS/Rain", 70)
  Audio.bgm_fade(1000)
  $game_map.change_tileset(5)
  $game_map.change_parallax("Sky", true, false, 2, 0)
end)
$playing = false
Audio.bgm_play("Audio/BGM/Field", 100, 100, 0)
check("the story's music, sounds and fades and the map's look go out, the game's defaults for what the story left out; a sound outside the story does not",
      $told.map { |_, fields| [fields["map_pscene"], wire.parse(fields["args"])] },
      [["audio.bgm_play", ["Story", 90, 100, 0]], ["audio.se_play", ["Door", 80, 110]], ["audio.se_play", ["Knock", 100, 100]], ["audio.bgs_play", ["Rain", 70, 100, 0]],
       ["audio.bgm_fade", [1000]], ["map.tileset", [5]], ["map.parallax", ["Sky", true, false, 2, 0]]])
$told.clear
check("outside the story nothing goes out", $told, [])
$playing = true
$game_system = Game_System.new
walk = RPG::MoveRoute.new
walk.list = [RPG::MoveCommand.new(4), RPG::MoveCommand.new(0)]
run.call(main, lambda do
  $game_player.force_move_route(walk)
  main.map_zoom(150)
end)
$game_map.set_display_pos(12.5, 3.0)
$game_map.update
$game_map.set_display_pos(12.75, 3.0)
$game_map.update
$frame_count += MGQ_MpCoopScene::CAMERA_FRAMES
$game_map.update
check("the player's route, the map's zoom and the camera's place go out, the place once it moved and no sooner than CAMERA_FRAMES after the last",
      [told.call("event.route").last, told.call("map.zoom"), told.call("map.camera")], [[-1, true, false, [[4], [0]]], [[150]], [[12.5, 3.0], [12.75, 3.0]]])
$told.clear
$playing = false
$playing = true
matching.state["sm"] = "13,0,0,0"
stranger = MGQ_MpOverworldSync::Peers::Peer.new(8, { "name" => "Stranger", "id" => "x", "map" => "7", "sm" => "13,0,0,0", "since" => "3000" })
$peers = [matching, stranger]
check("a viewer the values moved past where the telling started stays a viewer, one they never reached does not",
      MGQ_MpCoop::Scope.viewers.map { |peer| peer.state["name"] }, ["Match"])
matching.state["sm"] = "12,0,0,0"
$peers = [matching]
$playing = false

$game_map = Game_Map.new
viewed = Game_Event.new(12)
$game_map.events = { 12 => viewed }
$game_switches = Game_Switches.new
$game_variables = Game_Variables.new
$game_self_switches = Game_SelfSwitches.new
$mirrored = []
scene = lambda do |kind, args, map = "7"|
  MGQ_MpCoop.take_map("pscene", teller, { "map_pscene" => kind, "mmap" => "7", "map" => map, "args" => wire.line(args) })
end
scene.call("story.values", [[0, 40, true], [0, 4, true], [1, 1001, 41], [0, 2029, true], [2, [7, 12, "A"], true], [1, 9999, 3], [2, [7, 12, "Z"], true]])
check("a viewer takes the teller's story values, never what is their own or names nothing of this game, but the scene switches",
      [$game_switches[40], $game_switches[4], $game_variables[1001], $game_switches[2029], $game_self_switches[[7, 12, "A"]], $game_variables[9999], $game_self_switches[[7, 12, "Z"]]],
      [true, nil, 41, true, true, nil, nil])
check("as the world's, so they are not written as the viewer's own", $mirrored, [[0, 40, true], [1, 1001, 41], [2, [7, 12, "A"], true]])
$own_markers = [13, 0, 0, 0]
other = MGQ_MpOverworldSync::Peers::Peer.new(9, { "name" => "Other", "id" => "o", "map" => "7", "telling" => "1", "tsm" => "12,0,0,0", "since" => "1000" })
check("the values moved the viewer's story past where the telling started, and they keep watching it, but no other teller's",
      [MGQ_MpCoop::Scope.watches?(teller), MGQ_MpCoop::Scope.watches?(other)], [true, false])
teller.state["tsm"] = "13,0,0,0"
check("and the teller's next telling, which starts where they are now", MGQ_MpCoop::Scope.watches?(teller), true)
teller.state["tsm"] = "12,0,0,0"
# Values that come between the story's events on two maps, while the teller's state names no telling
# start but their progress now, leave the start the viewer keeps.
teller.state.delete("tsm")
teller.state["sm"] = "13,0,0,0"
scene.call("story.values", [[0, 41, true]])
teller.state["tsm"] = "12,0,0,0"
check("values between the story's events on two maps keep the viewer watching the telling", MGQ_MpCoop::Scope.watches?(teller), true)
scene.call("event.route", [12, true, false, [[1], [41, "Actor1", 2], [41, "Missing", 0], [41, "../evil", 0], [44, "Door", 80, 100], [45, "exit"], [2, "x"]]])
check("the event walks the teller's route, without a graphic or sound this game lacks, a script or a broken command",
      [viewed.route.list.map(&:code), viewed.route.list[1].parameters, viewed.route.repeat, viewed.route.wait], [[1, 41, 0], ["Actor1", 2], true, false])
scene.call("event.balloon", [12, 3])
scene.call("event.animation", [-1, 4])
scene.call("event.animation", [12, 99])
scene.call("event.erase", [12])
check("and shows the balloon, the player's character the animation, and is erased; an animation the game lacks is left out",
      [viewed.balloon_id, $game_player.animation_id, viewed.animation_id, viewed.erased], [3, 4, nil, true])
viewed.instance_variable_set(:@route, nil)
scene.call("event.route", [12, false, false, [[1]]], "8")
check("an event change on another map, which the viewer is still on the way to, is left out", viewed.route, nil)
$peers = [teller]
scene.call("map.zoom", [5000])
scene.call("map.camera", [20.0, 10.0])
$game_player.update
far = [$game_map.display_x, $game_map.display_y]
scene.call("map.camera", [21.0, 10.0])
$game_player.update
check("the viewer's camera jumps to the teller's far away and eases toward it near, and zooms as the teller's, the zoom kept within the game's",
      [far, [$game_map.display_x, $game_map.display_y], $game_system.zoom_mode], [[20.0, 10.0], [20.25, 10.0], 2000])
scene.call("map.camera", [30.0, 10.0], "8")
$game_player.update
check("a camera place of another map is left out", $game_map.display_x, 20.4375)
$played = []
scene.call("audio.bgm_play", ["Story", 90, 100, 0])
scene.call("audio.se_play", ["../evil", 80, 100])
scene.call("audio.bgm_fade", [1000])
scene.call("audio.exit", [])
check("the viewer plays the teller's music, sounds and fades, never a path or an unknown call", $played, [["BGM", "Story", 90, 100, 0], ["BGM", :fade, 1000]])
$played = []
scene.call("audio.se_play", ["Door"])
check("a sound sent without volume and pitch plays at the game's defaults", $played, [["SE", "Door", 100, 100]])
$played = []
SceneManager.scene = Object.new
scene.call("audio.bgm_play", ["Theme", 90, 100, 0])
scene.call("audio.se_play", ["Hit", 80, 100])
away = $played.dup
SceneManager.scene = Scene_Map.new
$game_map.update
$game_map.update
check("away from the map's screen, as in a battle, the viewer hears none of the story's sounds, and its music once back on the map",
      [away, $played], [[], [["BGM", "Theme", 90, 100, 0]]])
$played = []
$following = 8
scene.call("audio.bgs_play", ["Rain", 70, 100, 0], "8")
scene.call("audio.se_play", ["Step", 80, 100], "8")
$game_map.update
on_the_way = $played.dup
$game_map.map_id = 8
$game_map.update
check("a viewer on the way to the teller's map hears its background sound once there, after the map's own, and none of its sound effects",
      [on_the_way, $played], [[], [["BGS", "Rain", 70, 100, 0]]])
$game_map.map_id = 7
$following = nil
$data_tilesets = [nil, 1, 2, 3, 4, 5]
module MGQ_MpOverworld; def self.graphic?(_folder, name); %w(Actor1 Sky).include?(name); end; end
scene.call("map.tileset", [5])
scene.call("map.tileset", [99])
scene.call("map.parallax", ["Sky", true, false, 2, 0])
scene.call("map.parallax", ["Missing", true, false, 2, 0])
scene.call("map.battleback", ["", ""])
scene.call("map.tileset", [4], "8")
check("and changes the map's look on the teller's map, never a tileset or picture the game lacks",
      $game_map.looks, [[:tileset, 5], [:parallax, "Sky", true, false, 2, 0], [:battleback, "", ""]])
scene.call("event.route", [-1, false, false, [[4], [0]]])
$forcing = true
$nonmoving = $touched = nil
$game_player.update_nonmoving(true)
$game_player.check_event_trigger_touch(1, 1)
check("the viewer's own character walks the teller's route, starting nothing it touches and meeting no enemies",
      [$game_player.route.list.map(&:code), $nonmoving, $touched], [[4, 0], nil, nil])
$forcing = false
$game_player.update_nonmoving(true)
check("once the route ended, it does again", $nonmoving, true)
check("the route skips a step the viewer's character cannot take, which stands elsewhere than the teller's",
      $game_player.route.skippable, true)
scene.call("event.route", [-1, true, false, [[4], [0]]])
$forcing = true
$restored = nil
teller.state["telling"] = "0"
$frame_count += MGQ_MpCoopScene::STATE_GRACE_FRAMES
$game_map.update
check("a route still walked once the viewer no longer sees the scene ends, giving the player their character back",
      [$restored, $game_player.instance_variable_get(:@move_route_forcing), MGQ_MpCoopScene.walks_player?], [true, false, false])
check("and the scene switch the scene turned on is off again", $game_switches[2029], false)
teller.state["telling"] = "1"
$raid = false
