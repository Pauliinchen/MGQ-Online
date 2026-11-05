#----------------------------------------------------------------
#  flow_guard_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers coop_flow.rbx, the one guard of the game's flow, with the DLL's guard standing in
# (flow_support.rb): the player's own scene it keeps, from a loaded save too, what it puts back
# where the mod ends an event early, keeps one from starting, moves the player away, ends a watched
# scene, resumes a frozen fight's scene or puts the game back after a duel, a screen left dark that
# no such place saw, and what it hands the DLL.

require_relative "support"
require_relative "flow_support"

# Stands in for the game's data: a piece of music, which notes what plays in $played, and a common
# event.
module RPG
  class BGM
    attr_reader :name, :volume, :pitch
    def initialize(name = "", volume = 100, pitch = 100); @name = name; @volume = volume; @pitch = pitch; end
    def play; ($played ||= []) << [@name, @volume, @pitch]; end
    def self.last; $music; end
  end
  EventCommand = Struct.new(:code, :indent, :parameters)
  CommonEvent = Struct.new(:list)
end
# A screen's tint.
Tone = Struct.new(:red, :green, :blue, :gray)
# A picture that notes what was done to it.
class Game_Picture
  attr_reader :number, :name, :done
  def initialize(number); @number = number; @name = ""; @done = []; end
  def show(name, *_rest); @name = name; @done << :show; end
  def erase; @name = ""; @done << :erase; end
end
# The pictures of a screen, made as they are asked for.
class Game_Pictures
  def initialize; @data = []; end
  def [](number); @data[number] ||= Game_Picture.new(number); end
end
# A screen that notes its fades and tints.
class Game_Screen
  attr_reader :pictures, :done, :brightness, :tone
  def initialize; @pictures = Game_Pictures.new; @done = []; @brightness = 255; @fadein_duration = 0; @tone = Tone.new(0, 0, 0, 0); end
  def start_fadeout(_duration); @brightness = 0; end
  def start_fadein(duration); @brightness = 255; @done << [:fadein, duration]; end
  def start_tone_change(tone, duration); @tone = tone; @done << [:tone, tone.to_a, duration]; end
end
# Stands in for the game's interpreter, running while running is set.
class Game_Interpreter
  attr_accessor :running
  def setup(list, event_id = 0); @list = list; @index = 0; @event_id = event_id; end
  def running?; @running ? true : false; end
end
# Stands in for the map, its screen, its interpreter, its events and its parallel common events.
class Game_Map
  attr_accessor :map_id
  attr_reader :screen, :interpreter, :events
  def initialize; @map_id = 1951; @screen = Game_Screen.new; @interpreter = Game_Interpreter.new; @events = {}; @common_events = []; end
  def update; end
end
# Stands in for a map event with a parallel page, whose interpreter runs while its running is set.
class Game_Event; def initialize; @interpreter = Game_Interpreter.new; end; end
# Stands in for the player's character, hidden while transparent, with its followers, its forced
# route and its transfer, which waits while $transferring is set.
class Game_Player
  attr_accessor :transparent
  def followers; @followers ||= Struct.new(:visible).new(true); end
  def refresh; end
  def move_route_forcing; @move_route_forcing; end
  def restore_move_route; $route_given_back = true; end
  def transfer?; $transferring ? true : false; end
end
# Stands in for the party, which plays a story's temporary party while $temp_party is set.
class Game_Party
  def temp_actors_use?; $temp_party ? true : false; end
  def release_temp_actors; $temp_party = false; end
end
# Stands in for the game's system and its bans.
class Game_System; attr_accessor :menu_disabled, :save_disabled, :encounter_disabled, :formation_disabled; end
# Stands in for the game's messages, none showing.
class Game_Message; def busy?; false; end; end
# Stands in for the map's scene, the one the scene manager shows.
class Scene_Map; end
module SceneManager; def self.scene; Scene_Map.new; end; end
# Stands in for the game's saves, whose loading the guard hooks.
module DataManager; def self.extract_save_contents(_contents); end; def self.setup_new_game; end; end
# Stands in for the story's state, its escape spell's ban by its switch.
module MGQ_MpStoryState; ESCAPE_BAN = 94; end
# Stands in for coop_scene.rbx: the map's main event makes a change while $map_turn is, and the
# watched scene shows what $watched holds, waiting to be put back while it does.
module MGQ_MpCoopScene
  def self.map_turn?; $map_turn ? true : false; end
  def self.shown; $watched || { "screen" => false, "hidden" => false, "music" => false, "route" => false, "pictures" => [] }; end
  def self.pending?; $watched ? true : false; end
end
load_script "coop_flow"
require_relative "bridge_support"
fake = FakeBridge.new
answer_flow(fake)
MGQ_Multiplayer::Bridge.open(fake)

guard = MGQ_MpFlowGuard
$game_map = Game_Map.new
$game_player = Game_Player.new
$game_party = Game_Party.new
$game_system = Game_System.new
$game_message = Game_Message.new
$game_switches = []
pictures = $game_map.screen.pictures
# Starts an event of the map's interpreter, which runs the block as its own commands.
run = lambda do |list, &work|
  $game_map.interpreter.setup(list, 34)
  $game_map.interpreter.running = true
  $map_turn = true
  work.call if work
  $map_turn = false
end
# Ends the map's running event and runs the map's update.
idle = lambda do
  $game_map.interpreter.running = false
  $game_map.update
end
command = lambda { |code, *params| RPG::EventCommand.new(code, 0, params) }

# A talk the mod ends early: its picture goes, the tint, the light and the music come back as it
# began, while a parallel event's picture stays (issue #49).
$music = RPG::BGM.new("Castle", 100, 100)
talk = [command.call(101, "", 0, 0, 2), command.call(401, "Not now."), command.call(121, 2001, 2001, 0), command.call(235, 5), command.call(0)]
run.call(talk) do
  pictures[5].show("companion")
  $game_map.screen.start_tone_change(Tone.new(-68, -68, -68, 0), 30)
  $game_map.screen.start_fadeout(30)
  $music = RPG::BGM.new("Sad", 90, 100)
end
pictures[20].show("hud")
$flow_asks = []
guard.cut(talk, 2, "a talk ended where it would move the story on")
check("a talk the mod ends hands the DLL its commands from where it ends", $flow_asks.last["rest"].map(&:first), [121, 235, 0])
check("and erases the picture it showed, but not a parallel event's", [pictures[5].done.last, pictures[20].done.last], [:erase, :show])
check("and brings back the tint, the light and the music it began with",
      [$game_map.screen.done.last(2), $played], [[[:tone, [0, 0, 0, 0], FlowStandIn::FRAMES], [:fadein, FlowStandIn::FRAMES]], [["Castle", 100, 100]]])
guard.cut(talk, 0, "a talk ended before its first line")
check("a message's text never crosses to the DLL", $flow_asks.last["rest"][1], [401, 0, [nil]])
pictures[20].erase
idle.call
check("once its event ended with nothing of it standing, the player's own scene closes", guard.open?, false)

# An ending puts the player in a temporary party, hidden, and lets them walk; the world's return to
# the Great Decision then takes them out of it (issue #52).
run.call([command.call(0)]) do
  $temp_party = true
  $game_player.transparent = true
  $game_player.followers.visible = false
end
$flow_stands = 0
3.times { idle.call }
check("an ending that leaves the player walking in a temporary party stays under way, asked once while nothing changes", [guard.open?, $flow_stands], [true, 1])
villager = [command.call(101, "", 0, 0, 2), command.call(0)]
run.call(villager) { pictures[6].show("villager") }
guard.cut(villager, 1, "a talk ended where it would move the story on")
check("a talk cut on that walk takes back only its own picture, not the ending's party or hidden character",
      [pictures[6].done.last, $temp_party, $game_player.transparent], [:erase, true, true])
idle.call
guard.leave("the world went back to the Great Decision", true, true)
check("the world's return ends the temporary party and shows the player and the followers",
      [$temp_party, $game_player.transparent, $game_player.followers.visible, guard.open?], [false, false, true, false])
$temp_party = true
$game_player.transparent = true
guard.leave("the player went to the story")
check("a teleport on the map with no scene of the player's own under way leaves the party and the character as they are", [$temp_party, $game_player.transparent], [true, true])
DataManager.extract_save_contents({})
guard.leave("the world went back to the Great Decision", true, true)
check("the world's return after a save loaded in the middle of the ending ends its temporary party and shows the player", [$temp_party, $game_player.transparent], [false, false])

# A teleport out of a place that bans the escape spell lifts its ban, and shows the followers a
# defeat's place left hidden (issues #1 and #63, the field test of 2026-10-11).
$game_switches[94] = true
$game_player.followers.visible = false
guard.leave("the player went to the leader", false, true)
check("a teleport to another map lifts the escape spell's ban of the place and shows the followers", [$game_switches[94], $game_player.followers.visible], [false, true])

# The report of issue #68: after F12 the world's autosave loads on map 1951 showing Chaos's CG
# with no event running. The story event that would erase it starts only by the player's touch and
# never runs; the player teleports to the story on map 228.
pictures[5].show("80_chaos_st01")
DataManager.extract_save_contents({})
2.times { idle.call }
guard.leave("the player went to the story", false, true)
check("a loaded save's CG that no event erased goes as the player teleports away", pictures[5].done.last, :erase)

# The same CG goes once the player touches that event while another player's game runs the story
# there, so it is kept from starting; the DLL names the common event it calls (issue #68).
$data_common_events = [nil]
$data_common_events[9050] = RPG::CommonEvent.new([command.call(231, 5, "80_chaos_st01"), command.call(401, "Chaos: Begone."), command.call(221),
                                                   command.call(355, "$game_party.release_temp_actors"), command.call(235, 5), command.call(235, 6),
                                                   command.call(211, 0), command.call(222), command.call(0)])
pictures[5].show("80_chaos_st01")
event34 = [command.call(117, 9050), command.call(0)]
$flow_asks = []
guard.skipped(event34, "event 34 on map 1951")
check("an event kept from starting that calls a common event hands its commands once the DLL names it",
      [$flow_asks.size, $flow_asks[0].key?("commons"), $flow_asks[1]["commons"].keys], [2, false, [9050]])
check("without a picture's name or a message's text, but with a script's",
      $flow_asks[1]["commons"][9050].first(4).map(&:last), [[5, nil], [nil], [], ["$game_party.release_temp_actors"]])
check("and the CG the common event's end erases goes", pictures[5].done.last, :erase)
asked = $flow_asks.size
2.times { guard.skipped(event34, "event 34 on map 1951") }
check("the same event kept again asks once for the state the guard left, the common event handed over with it, then nothing more, as the game starts it every frame",
      [$flow_asks.size, $flow_asks.last["commons"].keys], [asked + 1, [9050]])

# The teller's CG on the same picture, shown while the player watches, stays (issue #68).
pictures[5].show("80_chaos_st01")
$watched = { "screen" => true, "hidden" => false, "music" => false, "route" => false, "pictures" => [5] }
guard.skipped(event34, "event 34 on map 1951")
check("while the player watches a telling, the kept event leaves the teller's CG shown", pictures[5].done.last, :show)
$watched = nil
pictures[5].erase

# A frozen fight's resume puts its scene back, CG and story party included. The resumed event stops
# before its end; once the player stands free, a teleport away erases the CG and ends the party the
# resume put back (issue #68).
before_resume = guard.resume_begins
$temp_party = true
guard.resuming(before_resume) { pictures[7].show("80_chaos_st01") }
run.call([command.call(301, 0, 2219, false, false), command.call(235, 7), command.call(0)])
2.times { idle.call }
guard.leave("the player went to the story", false, true)
check("a teleport away from a resumed scene, once the player stood free, erases its CG and ends its party", [pictures[7].done.last, $temp_party], [:erase, false])

# An event of the player's own began while a watched scene tinted the screen and hid their
# character; the watched scene's end put both back, then the mod cuts that event.
$watched = { "screen" => true, "hidden" => true, "music" => false, "route" => false, "pictures" => [] }
unwatched = guard.state_now
$game_map.screen.start_tone_change(Tone.new(-68, -68, -68, 0), 0)
$game_player.transparent = true
own = [command.call(101, "", 0, 0, 2), command.call(0)]
run.call(own)
shown = $watched
$watched = nil
guard.watched(unwatched, shown)
guard.cut(own, 1, "a talk ended where it would move the story on")
check("a cut of an event that began during a watched scene brings back neither that scene's tint nor its hidden character",
      [$game_map.screen.tone.to_a, $game_player.transparent], [[0, 0, 0, 0], false])
idle.call

# A move kept back after the scene faded out brings the light back (the field test of 2026-10-24).
$game_map.screen.start_fadeout(30)
guard.refused("the Central Tartarus is shut")
check("a move kept back fades the screen in again", $game_map.screen.done.last, [:fadein, FlowStandIn::FRAMES])

# A duel's end puts the game back from its snapshot, whose screen the leader's call had faded out
# (the field test of 2026-10-04).
fades = lambda { $game_map.screen.done.count { |entry| entry[0] == :fadein } }
$game_map.screen.start_fadeout(30)
DataManager.extract_save_contents({})
counted = fades.call
guard.restored("a PvP battle put the game back")
check("a duel's end fades in the screen its snapshot held dark", fades.call, counted + 1)

# A screen left dark by a cause none of the places that call the guard saw comes back once the
# player stands free with nothing of the game's flow running, and only then.
$game_map.screen.start_fadeout(30)
parallel = Game_Event.new
$game_map.events[3] = parallel
parallel.instance_variable_get(:@interpreter).running = true
$watched = { "screen" => true, "hidden" => false, "music" => false, "route" => false, "pictures" => [] }
$transferring = true
counted = fades.call
idle.call
$watched = nil
idle.call
$transferring = false
idle.call
check("a dark screen stays while a watched scene, a transfer or a parallel event runs", fades.call, counted)
parallel.instance_variable_get(:@interpreter).running = false
lines = logged_lines { idle.call }
check("then fades in, logged with the map and the event that ran last",
      [fades.call, lines.grep(/screen stood dark on map 1951 .* after event 34 /).size], [counted + 1, 1])
$game_map.screen.start_fadeout(30)
lines = logged_lines { idle.call }
check("again, logged once per map and event", [fades.call, lines.grep(/screen stood dark/).size], [counted + 2, 0])
