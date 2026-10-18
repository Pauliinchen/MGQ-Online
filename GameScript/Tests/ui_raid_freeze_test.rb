#----------------------------------------------------------------
#  ui_raid_freeze_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-17: Created
#
#----------------------------------------------------------------

# Covers the frozen fights of a Raid World's bosses on the map, ui_raid_freeze.rbx: the tableaux
# built from the player's own records and the world's entries, an own record winning, only on their
# map and never while their resume runs, outside the story or in battle; the stand-ins with their
# rows' looks and places; the live events hidden (the boss's always, any other only while its page
# runs nothing); the fight's own events and those whose page writes a held story value kept from
# starting, at once for an entry that just arrived; the fight's own events the player presses or
# touches (a cutscene's field source, another caller of its common event) resuming the fight
# instead, once per touch and never while the scene plays live, with no other start in that frame;
# the stand-ins stepping aside while another player tells the story on the map or a blocked event
# runs; the
# action button facing a boss's stand-in or across a counter, which resumes its fight; the nearest
# frozen fight for the Join Battle hotkey; the sprites a spriteset keeps; and building anew after a
# map's setup and a load. battles_raid_freeze.rbx, world_freeze.rbx and battles_raid_pool.rbx stand
# in here.

require_relative "support"

$log = []
# The mod's log, kept in $log and printed with the checks.
module MGQ_Multiplayer; module Log; def self.write(m); $log << m; puts "  log: #{m}"; end; end; end
$frame = 0
# The game's frame count, at $frame.
module Graphics; def self.frame_count; $frame; end; end

# Stand-ins for the game's characters, map and sprites.

# A character of the map, as far as the stand-ins and their sprites read it. moveto puts a walking
# character's pattern back to its original one, as the game straightens it.
class Game_Character
  attr_reader :x, :y, :direction, :pattern, :character_name, :character_index, :tile_id, :opacity,
              :blend_type, :priority_type, :through, :walk_anime, :step_anime, :transparent
  # Creates a character as the game's starts: facing down, walking, opaque.
  def initialize
    @x = 0; @y = 0; @direction = 2; @pattern = 1; @original_pattern = 1; @character_name = ""
    @character_index = 0; @tile_id = 0; @opacity = 255; @blend_type = 0; @priority_type = 1
    @through = false; @walk_anime = true; @step_anime = false; @transparent = false
  end
  # Puts it on a tile, straightening a walking character's pattern.
  def moveto(x, y); @x = x; @y = y; @pattern = @original_pattern if @walk_anime || @step_anime; end
end
# A command of an event's page.
module RPG; EventCommand = Struct.new(:code, :indent, :parameters); end
# A map event: its id, whether it is starting, whether it was unlocked, its page's commands, none
# unless set, and its trigger, the action button unless set.
class Game_Event < Game_Character
  attr_reader :id, :starting, :unlocked
  attr_accessor :list, :trigger
  # Creates the event on a tile.
  def initialize(id, x, y, trigger = 0); super(); @id = id; moveto(x, y); @starting = false; @trigger = trigger; end
  # Starts it, as its trigger does.
  def start; @starting = true; @unlocked = false; end
  # Updates it: one that runs by itself starts, as the game's check of its trigger does every frame.
  def update; start if @trigger == 3; end
  # Clears its starting flag.
  def clear_starting_flag; @starting = false; end
  # Unlocks it.
  def unlock; @unlocked = true; end
end
# The map's interpreter, running while $running is set, the event of $running_event.
class Game_Interpreter
  # Whether it runs.
  def running?; $running ? true : false; end
  # The event it runs, 0 for none.
  def event_id; $running_event || 0; end
end
# The map: its id, its events, the counters in $counters, and the event it started last in $started.
class Game_Map
  attr_accessor :map_id, :events
  attr_reader :interpreter
  # Creates map 138 without events.
  def initialize; @map_id = 138; @events = {}; @interpreter = Game_Interpreter.new; end
  # Sets up a map.
  def setup(map_id); @map_id = map_id; @events = {}; end
  # The tile's x beside one in a direction.
  def round_x_with_direction(x, d); x + (d == 6 ? 1 : d == 4 ? -1 : 0); end
  # The tile's y beside one in a direction.
  def round_y_with_direction(y, d); y + (d == 2 ? 1 : d == 8 ? -1 : 0); end
  # Whether a tile is a counter.
  def counter?(x, y); ($counters || []).include?([x, y]); end
  # Starts the first starting event, as the game does, noting it in $started.
  def setup_starting_map_event
    event = @events.values.find { |each| each.starting }
    event.clear_starting_flag if event
    $started = event
    event
  end
end
# The player: where they stand and face; the game's own action check notes itself in $checked.
class Game_Player
  attr_accessor :x, :y, :direction
  # Creates the player at the top left, facing down.
  def initialize; @x = 0; @y = 0; @direction = 2; end
  # The game's own action check.
  def check_action_event; $checked = true; :game; end
end
# The party, in battle while $in_battle is set.
class Game_Party; def in_battle; $in_battle ? true : false; end; end
# A character's sprite: its character and whether it shows, which its update reads anew.
class Sprite_Character
  attr_reader :character, :viewport, :disposed
  attr_accessor :visible
  # Creates the sprite of a character in a viewport.
  def initialize(viewport, character); @viewport = viewport; @character = character; @visible = true; end
  # Shows the sprite unless its character is see-through.
  def update; @visible = !@character.transparent; end
  # Frees it.
  def dispose; @disposed = true; end
end
# The map's sprites: its viewport of characters and its characters' sprites.
class Spriteset_Map
  # Creates the map's sprites with the characters' sprites.
  def initialize(sprites); @viewport1 = :characters; @character_sprites = sprites; end
  # Updates the characters' sprites.
  def update; @character_sprites.each { |sprite| sprite.update }; end
  # Frees nothing of its own.
  def dispose; end
end
# The title screen.
class Scene_Title; def start; end; end
# The game's saves.
module DataManager; def self.extract_save_contents(_contents); end; end

# Stand-ins for the mod's other scripts.

# The pools: active while $active, a troop named by $names.
module MGQ_MpRaidPool
  # Whether the player plays a Raid World's story.
  def self.active?; $active; end
  # The boss's name.
  def self.troop_label(troop); ($names || {})[troop] || "troop #{troop}"; end
end
# The engine: the player's frozen records in $records, any state in $any_records, the resumes
# running in $resuming, each resume asked for noted in $resumed and starting while $resume_ok.
module MGQ_MpRaidFreeze
  # The player's frozen records.
  def self.records; $records; end
  # A record of any state.
  def self.record_for(troop); ($records + ($any_records || [])).find { |record| record["troop"] == troop }; end
  # Whether a troop's resume runs.
  def self.resuming?(troop = nil); troop ? ($resuming || []).include?(troop) : !($resuming || []).empty?; end
  # Notes a resume asked for.
  def self.resume(troop); ($resumed ||= []) << troop; $resume_ok; end
end
# The world's frozen fights, its active entries in $entries.
module MGQ_MpWorldFreeze
  # The active entries.
  def self.entries; $entries; end
end
# The freeze's data: what the post-defeat processing writes itself.
module MGQ_MpRaidFreezeData; DEFEAT_WRITES = { :switches => [22, 31..37], :variables => [11] }; end
# The notification box, its messages kept in $notices.
module MGQ_MpNotices; def self.message(_key, text, _frames); $notices << text; end; end
# The hotkeys, the join hotkey being J.
module MGQ_MpHotkeys; def self.label(_action); "J"; end; end
# The other players, each with the state their game tells.
module MGQ_MpOverworldSync; module Peers; Peer = Struct.new(:state); end; end
# Who tells the story the player shares: $teller.
module MGQ_MpCoop; module Scope; def self.teller; $teller; end; end; end
# Whether the player watches another player's story scene: $watching.
module MGQ_MpCoopScene; def self.watching?; $watching ? true : false; end; end
# The common events, by id.
$data_common_events = []

load_script "ui_raid_freeze"
ui = MGQ_MpRaidFreezeUi

# A sprite row of a tableau.
#
# @param id [Integer] The event it stands for.
# @param x [Integer] Its x.
# @param y [Integer] Its y.
# @param name [String] Its picture.
# @param boss [Integer] 1 for the boss.
# @param hide [Integer] 1 when its live event hides.
# @return [Array] The row.
def row(id, x, y, name, boss = 0, hide = 1)
  [id, x, y, 4, 2, name, 3, 0, 200, 1, 1, boss, hide]
end

# The record or entry of a frozen fight.
#
# @param troop [Integer] The troop.
# @param map [Integer] The tableau's map.
# @param rows [Array<Array>] Its rows.
# @param blocked [Array<Integer>] The events it blocks.
# @return [Hash] The record or entry.
def frozen(troop, map, rows, blocked)
  { "troop" => troop, "site" => "map:#{map}:13:1", "outer" => "map:#{map}:13:1", "scene" => false, "tableau" => [map, rows, blocked], "spot" => [map, 30, 10, 8] }
end

# Starts the game anew: map 138, the player at (30, 10) facing up, nothing frozen, the next scan.
def reset
  $game_map = Game_Map.new
  $game_player = Game_Player.new
  $game_player.x = 30
  $game_player.y = 10
  $game_player.direction = 8
  $game_party = Game_Party.new
  $records = []
  $any_records = []
  $entries = []
  $resuming = []
  $resumed = []
  $resume_ok = true
  $active = true
  $in_battle = false
  $running = false
  $running_event = 0
  $teller = nil
  $watching = false
  $notices = []
  $counters = []
  $checked = false
  $names = { 868 => "Sonya Mazda", 126 => "Morrigan", 870 => "Sonya Chaos" }
  $frame += MGQ_MpRaidFreezeUi::SCAN_FRAMES
  MGQ_MpRaidFreezeUi.forget("a test")
end

sonya_rows = [row(13, 30, 9, "$Sonya", 1), row(14, 28, 9, "Alice"), row(15, 31, 12, "", 0, 0)]

# The tableaux.
reset
check("nothing frozen shows nothing", ui.tableaux, [])
$records = [frozen(868, 138, sonya_rows, [13])]
$frame += MGQ_MpRaidFreezeUi::SCAN_FRAMES
tableau = ui.tableaux.first
check("the player's own record shows its tableau on its map, the boss its boss row",
      [ui.tableaux.size, tableau.troop, tableau.name, tableau.own, tableau.standins.size, tableau.boss.event_id, tableau.boss.boss?],
      [1, 868, "Sonya Mazda", true, 3, 13, true])
boss = tableau.boss
check("a stand-in looks and stands as its row: place, facing, pattern, picture, tile, opacity, blend, priority",
      [boss.x, boss.y, boss.direction, boss.pattern, boss.character_name, boss.character_index, boss.tile_id, boss.opacity, boss.blend_type, boss.priority_type],
      [30, 9, 4, 2, "$Sonya", 3, 0, 200, 1, 1])
check("walking through everything, without walking or stepping, its pattern kept on moveto",
      [boss.through, boss.walk_anime, boss.step_anime, boss.troop], [true, false, false, 868])
check("only rows with hide 1 stand for live events, and the tableau blocks its events",
      [tableau.hidden.map { |id, kept| [id, kept.event_id, kept.boss] }, tableau.blocked], [[[13, 13, 1], [14, 14, 0]], [13]])
$entries = [frozen(868, 138, [row(40, 1, 1, "$Other", 1)], [40]), frozen(126, 138, [row(5, 10, 6, "$Morrigan", 1)], [5])]
$frame += MGQ_MpRaidFreezeUi::SCAN_FRAMES
check("a world's entry shows for a boss without an own record, the own record winning over the world's entry",
      ui.tableaux.map { |each| [each.troop, each.own, each.boss.event_id] }, [[868, true, 13], [126, false, 5]])
$records = []
$any_records = [frozen(126, 138, [], []).merge("state" => "lost")]
$frame += MGQ_MpRaidFreezeUi::SCAN_FRAMES
check("nor for a boss whose own record is not frozen yet", ui.tableaux.map { |each| each.troop }, [868])
$any_records = []
$frame += MGQ_MpRaidFreezeUi::SCAN_FRAMES
built = ui.tableaux
$frame += 1
check("between two scans the stand-ins stay the same", ui.tableaux.first.boss.equal?(built.first.boss), true)
$frame += MGQ_MpRaidFreezeUi::SCAN_FRAMES
check("and so they do when a scan finds the same sources", ui.tableaux.first.boss.equal?(built.first.boss), true)
$entries.last["tableau"][1][0][1] = 12
$frame += MGQ_MpRaidFreezeUi::SCAN_FRAMES
check("a tableau changed in place is built anew at the next scan", ui.tableaux.last.boss.x, 12)
$entries = [frozen(126, 138, [row(5, 10, 6, "$Morrigan", 1)], [5])]
$frame += MGQ_MpRaidFreezeUi::SCAN_FRAMES
check("an entry that ended, which the world leaves out, shows no more", ui.tableaux.map { |each| each.troop }, [126])
$game_map.map_id = 139
$frame += 1
check("a tableau shows only on its map", ui.tableaux, [])
$game_map.map_id = 138
$frame += 1
$resuming = [126]
check("none while its fight's resume runs", ui.tableaux, [])
$resuming = []
$active = false
$frame += 1
check("none outside a Raid World's story", ui.tableaux, [])
$active = true
$in_battle = true
$frame += 1
check("none while a battle runs", ui.tableaux, [])
$in_battle = false
$frame += 1
$entries = [frozen(126, 138, [[5, 10], "broken", row(6, 11, 6, "$Morrigan", 1)], ["x", 6])]
$frame += MGQ_MpRaidFreezeUi::SCAN_FRAMES
check("rows that lack values are left out", [ui.tableaux.first.standins.map { |each| each.event_id }, ui.tableaux.first.blocked], [[6], [6]])
$entries = [frozen(126, 138, [row(7, 2, 2, "$Morrigan")], [])]
$frame += MGQ_MpRaidFreezeUi::SCAN_FRAMES
check("a tableau without a boss row takes its first stand-in as the boss", ui.tableaux.first.boss.event_id, 7)

# Hidden live events and blocked starts.
reset
$records = [frozen(868, 138, sonya_rows, [13])]
sonya = Game_Event.new(13, 30, 8)
alice = Game_Event.new(14, 28, 9)
guard = Game_Event.new(15, 31, 12)
$game_map.events = { 13 => sonya, 14 => alice, 15 => guard }
check("a live event a row with hide 1 stands for hides, others and the stand-ins do not",
      [ui.hidden?(sonya), ui.hidden?(alice), ui.hidden?(guard), ui.hidden?(ui.tableaux.first.boss), ui.hidden?(nil)], [true, true, false, false, false])
talk = [RPG::EventCommand.new(101, 0, []), RPG::EventCommand.new(0, 0, [])]
alice.list = [RPG::EventCommand.new(108, 0, ["a note"]), RPG::EventCommand.new(0, 0, [])]
check("a live event whose page runs nothing but comments hides", ui.hidden?(alice), true)
alice.list = talk
sonya.list = talk
check("one whose page has something to run, such as a talk, shows and serves on; the boss's hides all the same",
      [ui.hidden?(alice), ui.hidden?(sonya)], [false, true])
alice.list = nil
sonya.list = nil
sonya.trigger = 3
sonya.update
guard.start
check("the frozen event that runs by itself cannot start again: after its update it does not count as starting",
      [sonya.starting, $game_map.setup_starting_map_event.equal?(guard)], [false, true])
$frame += 1
sonya.update
check("logged once, and never noticed", [$log.grep(/kept event 13 on map 138 from starting: it is the fight's own event; the fight against Sonya Mazda \(troop 868\) waits frozen there/).size, $notices], [1, []])
sonya.instance_variable_set(:@starting, true)
$game_map.setup_starting_map_event
check("one starting past its start is kept from running, unlocked", [sonya.starting, sonya.unlocked, $started], [false, true, nil])
check("which is logged", $log.grep(/kept starting event 13 on map 138 from running: it is the fight's own event/).size, 1)
$resuming = [868]
$frame += 1
sonya.start
$game_map.setup_starting_map_event
check("while its resume runs it starts as the game starts it", $started.equal?(sonya), true)
$resuming = []
$game_map.map_id = 139
$frame += 1
sonya.start
$game_map.setup_starting_map_event
check("nor is it blocked while the tableau shows elsewhere", $started.equal?(sonya), true)

# A touch tile that calls the fight's common event too, which the tableau blocks with the fight's
# own event, resumes the fight when the player touches it rather than starting the scene anew, but
# starts as the game starts it during the resume.
reset
$records = [frozen(868, 138, sonya_rows, [13, 16])]
tile = Game_Event.new(16, 30, 11, 1)
$game_map.events = { 13 => Game_Event.new(13, 30, 8), 16 => tile }
tile.start
$game_map.setup_starting_map_event
check("touching another caller of the fight's common event resumes the fight, the caller not starting",
      [tile.starting, $started, $resumed], [false, nil, [868]])
check("which is logged", $log.grep(/the player started event 16 on map 138, which leads into the frozen fight against Sonya Mazda \(troop 868\): resuming its fight/).size, 1)
$resuming = [868]
$frame += 1
tile.start
$game_map.setup_starting_map_event
check("and starts as the game starts it while the fight's resume runs", [$started.equal?(tile), $resumed], [true, [868]])
$resuming = []

# The field event that leads into a cutscene map's fight, where its boss's stand-in waits, resumes
# the fight as the stand-in does; so does a source the player walks onto on the world map.
reset
$game_map.map_id = 139
$records = [frozen(126, 139, [row(37, 12, 6, "$Morrigan", 1, 0)], [37]).merge("scene" => true)]
source = Game_Event.new(37, 10, 6)
source.list = [RPG::EventCommand.new(201, 0, [0, 587, 1, 1, 0]), RPG::EventCommand.new(0, 0, [])]
villager = Game_Event.new(38, 11, 6)
$game_map.events = { 37 => source, 38 => villager }
source.start
check("pressing the source event resumes the fight, the event not starting", [source.starting, $resumed, $notices], [false, [126], []])
check("which is logged", $log.grep(/the player started event 37 on map 139, which leads into the frozen fight against Morrigan \(troop 126\): resuming its fight/).size, 1)
villager.start
$game_map.setup_starting_map_event
check("in the frame the press resumed the fight no other event starts", [villager.starting, $started], [false, nil])
check("which is logged", $log.grep(/kept event 38 on map 139 from starting: a frozen fight resumed this frame/).size, 1)
$frame += 1
villager.start
check("an ordinary villager starts again the frame after", villager.starting, true)
villager.clear_starting_flag
$resume_ok = false
$resumed = []
$frame += 2
source.start
check("a refused resume keeps the event from starting all the same", [source.starting, $resumed], [false, [126]])
check("which is logged as for the stand-in", $log.last, "raid freeze ui: the fight against Morrigan (troop 126) did not start")
$frame += 1
source.start
check("a touch kept up the next frame, such as walking against the event, resumes nothing again",
      [source.starting, $resumed, $log.grep(/kept event 37 on map 139 from starting: the player keeps touching it/).size], [false, [126], 1])
$frame += 1
source.start
check("nor the frame after while it lasts, logged once", [$resumed, $log.grep(/the player keeps touching it/).size], [[126], 1])
$frame += 2
source.start
check("a new touch or press resumes again", $resumed, [126, 126])
$resume_ok = true
reset
$game_map.map_id = 2
$entries = [frozen(249, 2, [row(39, 257, 249, "$Astaroth", 1, 0)], [39, 40]).merge("scene" => true)]
gate = Game_Event.new(39, 257, 249, 1)
row_tile = Game_Event.new(40, 258, 249, 2)
$game_map.events = { 39 => gate, 40 => row_tile }
gate.start
check("walking onto a world map source tile of a world's entry resumes its fight", [gate.starting, $resumed], [false, [249]])
$frame += 2
row_tile.start
check("so does an event touch source", [row_tile.starting, $resumed], [false, [249, 249]])
gate.trigger = 3
$frame += 2
gate.start
check("one of the fight's own that runs by itself resumes nothing and stays blocked", [gate.starting, $resumed], [false, [249, 249]])
gate.trigger = 4
$frame += 2
gate.start
check("nor one that runs in parallel", [gate.starting, $resumed], [false, [249, 249]])
reset
$game_map.map_id = 139
$records = [frozen(126, 139, [row(37, 12, 6, "$Morrigan", 1, 0)], [37]).merge("scene" => true)]
source = Game_Event.new(37, 10, 6)
$game_map.events = { 37 => source }
$teller = MGQ_MpOverworldSync::Peers::Peer.new({ "telling" => "1", "map" => "139", "name" => "Player Two" })
source.start
check("while another player tells the story here the source event stays blocked, as the stand-in steps aside",
      [source.starting, $resumed, $notices], [false, [], []])

# A world's entry that arrives on the fight's map blocks at once.
reset
sonya = Game_Event.new(13, 30, 8, 3)
$game_map.events = { 13 => sonya }
check("nothing frozen yet", ui.tableaux, [])
$entries = [frozen(868, 138, sonya_rows, [13]).merge("held" => [[1, 1075, 14]])]
sonya.update
check("an entry that arrived this very frame keeps the autorun its held values turned on from starting",
      [sonya.starting, ui.tableaux.map { |each| each.troop }], [false, [868]])

# Events whose page writes a story value the fight holds cannot start; the others stay live.
reset
$entries = [frozen(868, 138, sonya_rows, [13]).merge("held" => [[1, 1075, 14], [0, 2307, true], [1, 11, 0], [2, [138, 40, "A"], false]])]
$data_common_events[500] = Struct.new(:list).new([RPG::EventCommand.new(121, 0, [2300, 2310, 1]), RPG::EventCommand.new(0, 0, [])])
writer = Game_Event.new(32, 32, 7)
writer.list = [RPG::EventCommand.new(101, 0, []), RPG::EventCommand.new(122, 0, [1075, 1075, 0, 0, 13]), RPG::EventCommand.new(0, 0, [])]
calling = Game_Event.new(33, 33, 7)
calling.list = [RPG::EventCommand.new(117, 0, [500]), RPG::EventCommand.new(0, 0, [])]
self_writer = Game_Event.new(40, 34, 7)
self_writer.list = [RPG::EventCommand.new(123, 0, ["A", 0]), RPG::EventCommand.new(0, 0, [])]
other_self = Game_Event.new(41, 35, 7)
other_self.list = [RPG::EventCommand.new(123, 0, ["A", 0]), RPG::EventCommand.new(0, 0, [])]
inn = Game_Event.new(42, 36, 7)
inn.list = [RPG::EventCommand.new(122, 0, [11, 11, 0, 0, 1]), RPG::EventCommand.new(121, 0, [22, 22, 0]), RPG::EventCommand.new(0, 0, [])]
talk = Game_Event.new(43, 37, 7)
talk.list = [RPG::EventCommand.new(101, 0, []), RPG::EventCommand.new(0, 0, [])]
$game_map.events = { 32 => writer, 33 => calling, 40 => self_writer, 41 => other_self, 42 => inn, 43 => talk }
$game_map.events.each_value(&:start)
check("one whose page writes a held variable, one whose common event writes a held switch and one that writes its held self switch cannot start",
      [writer.starting, calling.starting, self_writer.starting], [false, false, false])
check("one writing another event's self switch, an inn writing the post-defeat processing's own values and a talk start",
      [other_self.starting, inn.starting, talk.starting], [true, true, true])
check("each refusal is logged with the value",
      [$log.grep(/kept event 32 on map 138 from starting: its page writes v1075, which the fight holds/).size,
       $log.grep(/kept event 33 on map 138 from starting: its page writes s2307/).size,
       $log.grep(/kept event 40 on map 138 from starting: its page writes self switch 138\.40\.A/).size], [1, 1, 1])
check("and the player who started it gets no message, only the log", $notices, [])
check("none of them resumes the fight", $resumed, [])
$notices.clear
$frame += 1
writer.start
check("pressed again at once, it is not logged again", [writer.starting, $notices, $log.grep(/kept event 32 on map 138/).size], [false, [], 1])
$frame += MGQ_MpRaidFreezeUi::REFUSE_FRAMES
writer.start
check("but after a while it is logged again, still without a message", [$notices.size, $log.grep(/kept event 32 on map 138/).size], [0, 2])
$resuming = [868]
$frame += 1
writer.start
check("while the fight's resume runs it starts", writer.starting, true)

# The stand-ins step aside while the scene plays live.
reset
$records = [frozen(868, 138, sonya_rows, [13])]
sonya = Game_Event.new(13, 30, 8, 3)
$game_map.events = { 13 => sonya }
$teller = MGQ_MpOverworldSync::Peers::Peer.new({ "telling" => "1", "map" => "138", "name" => "Player Two" })
check("another player telling the story on the map hides the stand-ins and shows the live events",
      [ui.tableaux, ui.bar_targets, ui.hidden?(sonya), ui.press_target], [[], [], false, nil])
check("which is logged", $log.grep(/hides the stand-ins of the frozen fight against Sonya Mazda \(troop 868\) on map 138: Player Two tells the story here/).size, 1)
sonya.update
check("its own event still cannot start", sonya.starting, false)
$teller = MGQ_MpOverworldSync::Peers::Peer.new({ "telling" => "1", "map" => "139", "name" => "Player Two" })
$frame += 1
check("one telling elsewhere hides nothing, which is logged", [ui.tableaux.size, $log.grep(/shows the stand-ins of the frozen fight against Sonya Mazda \(troop 868\) on map 138 again/).size], [1, 1])
$teller = MGQ_MpOverworldSync::Peers::Peer.new({ "telling" => "0", "map" => "138", "name" => "Player Two" })
$frame += 1
check("nor one not telling", ui.tableaux.size, 1)
$teller = nil
$watching = true
$frame += 1
check("watching another player's story scene hides them too", ui.tableaux, [])
$watching = false
$running = true
$running_event = 13
$frame += 1
check("so does an event the fight blocks that runs all the same", [ui.tableaux, ui.hidden?(sonya)], [[], false])
$running_event = 5
$frame += 1
check("but not another event that runs", ui.tableaux.size, 1)

# The sprites a spriteset keeps.
reset
$records = [frozen(868, 138, sonya_rows, [13])]
sonya = Game_Event.new(13, 30, 8)
$game_map.events = { 13 => sonya }
live = Sprite_Character.new(:characters, sonya)
spriteset = Spriteset_Map.new([live])
spriteset.update
kept = ui.sprites_of(spriteset)
check("the spriteset keeps a sprite per stand-in in its viewport of characters",
      [kept.size, kept.map { |sprite| sprite.character.event_id }, kept.map { |sprite| sprite.viewport }.uniq], [3, [13, 14, 15], [:characters]])
check("the live event's sprite hides after its update", live.visible, false)
$records = []
$frame += MGQ_MpRaidFreezeUi::SCAN_FRAMES
spriteset.update
check("stand-ins that went free their sprites", [ui.sprites_of(spriteset), kept.map { |sprite| sprite.disposed }.uniq], [[], [true]])
check("and the live event shows again", live.visible, true)
$records = [frozen(868, 138, sonya_rows, [13])]
$frame += MGQ_MpRaidFreezeUi::SCAN_FRAMES
spriteset.update
kept = ui.sprites_of(spriteset)
spriteset.dispose
check("the spriteset's going frees them all", [ui.sprites_of(spriteset), kept.map { |sprite| sprite.disposed }.uniq], [[], [true]])

# The action button.
reset
$records = [frozen(868, 138, sonya_rows, [13])]
check("the action button facing the boss's stand-in resumes its fight, taking the press",
      [$game_player.check_action_event, $resumed, $checked], [true, [868], false])
$resume_ok = false
$resumed = []
check("also when the resume refuses", [$game_player.check_action_event, $resumed, $checked], [true, [868], false])
check("which is logged", $log.last, "raid freeze ui: the fight against Sonya Mazda (troop 868) did not start")
$resume_ok = true
$resumed = []
$running = true
check("not while an interpreter runs, the game's own check deciding", [$game_player.check_action_event, $resumed, $checked], [:game, [], true])
$running = false
$checked = false
$game_player.direction = 4
check("facing elsewhere the game's own check decides", [$game_player.check_action_event, $resumed, $checked], [:game, [], true])
$checked = false
$game_player.x = 27
$game_player.y = 9
$game_player.direction = 6
check("a non-boss stand-in leaves the press to the game", [ui.press_target, $game_player.check_action_event, $checked], [nil, :game, true])
$checked = false
$game_player.x = 30
$game_player.y = 10
$game_player.direction = 8
$records = [frozen(868, 138, [row(13, 30, 8, "$Sonya", 1)], [13])]
$frame += MGQ_MpRaidFreezeUi::SCAN_FRAMES
check("two tiles away without a counter between, the game decides", [ui.press_target, $game_player.check_action_event], [nil, :game])
$counters = [[30, 9]]
check("across a counter the boss's stand-in takes the press", [$game_player.check_action_event, $resumed], [true, [868]])
$counters = []
$records = [frozen(868, 138, [row(13, 30, 10, "", 1, 0)], [13])]
$frame += MGQ_MpRaidFreezeUi::SCAN_FRAMES
$resumed = []
check("an invisible boss row under the player takes it too", [$game_player.check_action_event, $resumed], [true, [868]])

# The Join Battle hotkey's frozen fight.
reset
$records = [frozen(868, 138, sonya_rows, [13])]
$entries = [frozen(126, 138, [row(5, 33, 10, "$Morrigan", 1)], [5])]
check("the nearest boss's stand-in within the reach, diagonal steps counted as one",
      [ui.join_target(30, 10, 3), ui.join_target(33, 9, 3), ui.join_target(30, 4, 3)], [[868, "Sonya Mazda"], [126, "Morrigan"], nil])
check("ties go to the lower troop", ui.join_target(31, 11, 3), [126, "Morrigan"])
check("only bosses count, not the stand-ins around them", ui.join_target(28, 10, 1), nil)
check("joining resumes the fight", [ui.join(868), $resumed], [true, [868]])
check("a troop the map shows no frozen fight of resumes nothing", [ui.join(870), $resumed], [false, [868]])
check("the bosses' stand-ins carry the bars", ui.bar_targets.map { |standin, troop| [standin.event_id, troop] }, [[13, 868], [5, 126]])

# Building anew.
reset
$records = [frozen(868, 138, sonya_rows, [13])]
first = ui.tableaux.first.boss
$frame += 1
$game_map.setup(138)
check("a map's setup builds the stand-ins anew", [ui.tableaux.size, ui.tableaux.first.boss.equal?(first)], [1, false])
first = ui.tableaux.first.boss
$frame += 1
DataManager.extract_save_contents({})
check("so does a load", ui.tableaux.first.boss.equal?(first), false)
first = ui.tableaux.first.boss
$frame += 1
Scene_Title.new.start
check("and the title screen", ui.tableaux.first.boss.equal?(first), false)
check("building logs what shows", $log.grep(/shows the frozen fight against Sonya Mazda \(troop 868\) on map 138 from the player's own record: 3 stand-in\(s\)/).empty?, false)

check("no hook of the frozen fights failed", $log.grep(/raid freeze ui.*(FAILED|failed)/), [])
