#----------------------------------------------------------------
#  flow_guard_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Answered the guard's topics with fixed plans and checked what the guard hands the DLL and how it puts a plan back
#                            - Created
#
#----------------------------------------------------------------

# Covers coop_flow.rbx, the one guard of the game's flow, with fixed plans of the DLL
# (telling_support.rb): what it hands the DLL where the mod ends an event early, keeps one from
# starting, moves the player away, ends a watched scene, resumes a frozen fight's scene or puts the
# game back after a duel, the player's own scene it keeps for that, from a loaded save too, a screen
# left dark that no such place saw, and how it puts back what a plan names. What a plan holds for
# each case is FlowGuardTests' to cover.

require_relative "support"
require_relative "telling_support"

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
answer_telling(fake)
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
# Has the DLL answer a plan that puts back what it names and nothing else.
plan = lambda do |named|
  $tells.set("flow.plan", { "erase" => [], "fade_in" => false, "tone" => nil, "hidden" => nil, "followers" => nil, "release_party" => false, "music" => nil,
                            "lift" => [], "end_route" => false, "clear_effects" => false, "frames" => 30 }.merge(named))
end
# The last plan the guard asked for.
asked = lambda { $tells.asked("flow.plan").last }

# A talk the mod ends early hands the DLL the state it began with, the pictures it showed and its
# commands from where it ends, and the guard puts back what the plan names (issue #49).
$music = RPG::BGM.new("Castle", 100, 100)
talk = [command.call(101, "", 0, 0, 2), command.call(401, "Not now."), command.call(121, 2001, 2001, 0), command.call(235, 5), command.call(0)]
run.call(talk) do
  pictures[5].show("companion")
  $game_map.screen.start_tone_change(Tone.new(-68, -68, -68, 0), 30)
  $game_map.screen.start_fadeout(30)
  $music = RPG::BGM.new("Sad", 90, 100)
end
pictures[20].show("hud")
plan.call("erase" => [5], "tone" => [0, 0, 0, 0], "fade_in" => true, "music" => ["Castle", 100, 100])
guard.cut(talk, 2, "a talk ended where it would move the story on")
check("a talk the mod ends hands the DLL the tint and music it began with, the picture it showed and its commands from where it ends",
      [asked.call["cut"], asked.call["before"].values_at("tone", "music"), asked.call["owned"], asked.call["now"]["pictures"], asked.call["rest"].map(&:first)],
      ["cut", [[0, 0, 0, 0], ["Castle", 100, 100]], [5], [5, 20], [121, 235, 0]])
check("and erases the picture the plan names, but no other", [pictures[5].done.last, pictures[20].done.last], [:erase, :show])
check("and brings back the tint, the light and the music the plan names over its frames",
      [$game_map.screen.done.last(2), $played], [[[:tone, [0, 0, 0, 0], 30], [:fadein, 30]], [["Castle", 100, 100]]])
guard.cut(talk, 0, "a talk ended before its first line")
check("a message's text never crosses to the DLL", asked.call["rest"][1], [401, 0, [nil]])
pictures[20].erase
idle.call
check("once its event ended and the DLL finds nothing of it stands, the player's own scene closes", guard.open?, false)

# An ending puts the player in a temporary party, hidden, and lets them walk; the world's return to
# the Great Decision then takes them out of it (issue #52).
run.call([command.call(0)]) do
  $temp_party = true
  $game_player.transparent = true
  $game_player.followers.visible = false
end
$tells.set("flow.stands", true)
$tells.clear
3.times { idle.call }
stands = $tells.asked("flow.stands")
check("an ending the DLL finds still stands keeps the player's own scene under way, asked once while nothing changes, with the state it began from",
      [guard.open?, stands.size, stands[0]["start"].values_at("temp_party", "hidden"), stands[0]["now"].values_at("temp_party", "hidden")],
      [true, 1, [false, false], [true, true]])
villager = [command.call(101, "", 0, 0, 2), command.call(0)]
run.call(villager) { pictures[6].show("villager") }
plan.call("erase" => [6])
guard.cut(villager, 1, "a talk ended where it would move the story on")
check("a talk cut on that walk hands the DLL only its own picture, with the ending's party and hidden character it began with",
      [asked.call["owned"], asked.call["before"].values_at("temp_party", "hidden"), pictures[6].done.last], [[6], [true, true], :erase])
idle.call
plan.call("hidden" => false, "followers" => true, "release_party" => true)
guard.leave("the world went back to the Great Decision", true, true)
check("the world's return hands the DLL the state the scene began from, whole and elsewhere",
      [asked.call["cut"], asked.call["before"].values_at("temp_party", "hidden"), asked.call.values_at("whole", "elsewhere")], ["leave", [false, false], [true, true]])
check("and ends the temporary party and shows the player and the followers as the plan names, which closes the scene",
      [$temp_party, $game_player.transparent, $game_player.followers.visible, guard.open?], [false, false, true, false])
$tells.set("flow.stands", nil)
guard.leave("the player went to the story")
check("a teleport with no scene of the player's own under way hands the DLL no state before", asked.call.values_at("before", "whole", "elsewhere"), [nil, false, false])

# A teleport out of a place that bans the escape spell lifts its ban, and shows the followers a
# defeat's place left hidden (issues #1 and #63, the field test of 2026-10-11).
$game_switches[94] = true
$game_player.followers.visible = false
plan.call("lift" => ["escape"], "followers" => true)
guard.leave("the player went to the leader", false, true)
check("a teleport hands the DLL the escape spell's ban on, and lifts it and shows the followers as the plan names",
      [asked.call["now"]["bans"], $game_switches[94], $game_player.followers.visible], [["escape"], false, true])

# The report of issue #68: after F12 the world's autosave loads on map 1951 showing Chaos's CG
# with no event running. The story event that would erase it starts only by the player's touch and
# never runs; the player teleports to the story on map 228.
pictures[5].show("80_chaos_st01")
DataManager.extract_save_contents({})
$tells.set("flow.stands", true)
2.times { idle.call }
plan.call("erase" => [5])
guard.leave("the player went to the story", false, true)
check("a loaded save's CG that no event erased is no part of the state the scene it stopped began from as the player teleports away",
      [asked.call["before"] && asked.call["before"]["pictures"], asked.call["now"]["pictures"], pictures[5].done.last], [[], [5], :erase])
$tells.set("flow.stands", nil)

# The same CG goes once the player touches that event while another player's game runs the story
# there, so it is kept from starting; the DLL names the common event it calls (issue #68).
$data_common_events = [nil]
$data_common_events[9050] = RPG::CommonEvent.new([command.call(231, 5, "80_chaos_st01"), command.call(401, "Chaos: Begone."), command.call(221),
                                                   command.call(355, "$game_party.release_temp_actors"), command.call(235, 5), command.call(235, 6),
                                                   command.call(211, 0), command.call(222), command.call(0)])
pictures[5].show("80_chaos_st01")
event34 = [command.call(117, 9050), command.call(0)]
$tells.set("flow.plan") { |request| request["commons"] ? { "erase" => [5], "frames" => 30 } : { "needs" => [9050] } }
$tells.clear
guard.skipped(event34, "event 34 on map 1951")
asks = $tells.asked("flow.plan")
check("an event kept from starting that calls a common event hands its commands once the DLL names it",
      [asks.size, asks[0]["cut"], asks[0].key?("commons"), asks[1]["commons"].keys], [2, "skip", false, [9050]])
check("without a picture's name or a message's text, but with a script's",
      asks[1]["commons"][9050].first(4).map(&:last), [[5, nil], [nil], [], ["$game_party.release_temp_actors"]])
check("and the plan's picture goes", pictures[5].done.last, :erase)
2.times { guard.skipped(event34, "event 34 on map 1951") }
check("the same event kept again asks once for the state the guard left, the common event handed over with it, then nothing more, as the game starts it every frame",
      [$tells.asked("flow.plan").size, $tells.asked("flow.plan").last["commons"].keys], [3, [9050]])

# The teller's CG on the same picture, shown while the player watches, goes with the request.
pictures[5].show("80_chaos_st01")
$watched = { "screen" => true, "hidden" => false, "music" => false, "route" => false, "pictures" => [5] }
plan.call({})
guard.skipped(event34, "event 34 on map 1951")
check("while the player watches a telling, the kept event hands the DLL what the watched scene shows", asked.call["watch"], $watched)
$watched = nil
pictures[5].erase

# A frozen fight's resume puts its scene back, CG and story party included. The resumed event stops
# before its end; once the player stands free, a teleport away hands the state before the resume
# (issue #68).
before_resume = guard.resume_begins
$temp_party = true
guard.resuming(before_resume) { pictures[7].show("80_chaos_st01") }
run.call([command.call(301, 0, 2219, false, false), command.call(235, 7), command.call(0)])
$tells.set("flow.stands", true)
2.times { idle.call }
plan.call("erase" => [7], "release_party" => true)
guard.leave("the player went to the story", false, true)
check("a teleport away from a resumed scene hands the DLL the state before the resume, and the plan erases its CG and ends its party",
      [asked.call["before"].values_at("temp_party", "pictures"), pictures[7].done.last, $temp_party], [[false, []], :erase, false])
$tells.set("flow.stands", nil)

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
plan.call("tone" => [0, 0, 0, 0], "hidden" => false)
guard.watched(unwatched, shown)
check("a watched scene's end hands the DLL the state before it and what it showed, and puts back the plan's tint and character",
      [asked.call["cut"], asked.call["before"]["tone"], asked.call["watch"], $game_map.screen.tone.to_a, $game_player.transparent],
      ["watched", [0, 0, 0, 0], shown, [0, 0, 0, 0], false])
plan.call({})
guard.cut(own, 1, "a talk ended where it would move the story on")
check("a cut of an event that began during the watched scene hands the DLL the tint and character that scene's end left, not its own",
      asked.call["before"].values_at("tone", "hidden"), [[0, 0, 0, 0], false])
idle.call

# A move kept back after the scene faded out brings the light back (the field test of 2026-10-24).
$game_map.screen.start_fadeout(30)
plan.call("fade_in" => true)
guard.refused("the Central Tartarus is shut")
check("a move kept back asks the DLL and fades the screen in as the plan names", [asked.call["cut"], $game_map.screen.done.last], ["refused", [:fadein, 30]])

# A duel's end puts the game back from its snapshot, whose screen the leader's call had faded out
# (the field test of 2026-10-04).
fades = lambda { $game_map.screen.done.count { |entry| entry[0] == :fadein } }
$game_map.screen.start_fadeout(30)
DataManager.extract_save_contents({})
counted = fades.call
guard.restored("a PvP battle put the game back")
check("a duel's end asks the DLL and fades in the screen its snapshot held dark", [asked.call["cut"], fades.call], ["free", counted + 1])

# A screen left dark by a cause none of the places that call the guard saw comes back once the
# player stands free with nothing of the game's flow running, and only then.
$game_map.screen.start_fadeout(30)
parallel = Game_Event.new
$game_map.events[3] = parallel
parallel.instance_variable_get(:@interpreter).running = true
$watched = { "screen" => true, "hidden" => false, "music" => false, "route" => false, "pictures" => [] }
$transferring = true
counted = fades.call
$tells.clear
idle.call
$watched = nil
idle.call
$transferring = false
idle.call
check("a dark screen asks nothing while a watched scene, a transfer or a parallel event runs", [$tells.asked("flow.plan").size, fades.call], [0, counted])
parallel.instance_variable_get(:@interpreter).running = false
lines = logged_lines { idle.call }
check("then asks the DLL and fades in, logged with the map and the event that ran last",
      [asked.call["cut"], fades.call, lines.grep(/screen stood dark on map 1951 .* after event 34 /).size], ["free", counted + 1, 1])
$game_map.screen.start_fadeout(30)
lines = logged_lines { idle.call }
check("again, logged once per map and event", [fades.call, lines.grep(/screen stood dark/).size], [counted + 2, 0])
