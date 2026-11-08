#----------------------------------------------------------------
#  raid_freeze_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-08: Answered the records check, the held values, the record's end, the tableau, the fresh start and the items given back with fixed values per case, and checked what the scripts hand the DLL
#      Paulinchen  2026-11-06: Answered whether a page runs nothing as the DLL's events database and dropped the check of a Hades hall, which the DLL leaves out of the sites
#      Paulinchen  2026-11-05: Answered the sites of an earlier release's save with fixed values and checked the texts handed
#                            - Dropped the checks of the write journal against its golden cases, which StoryJournalTests walks
#                            - Answered why the world's list calls a fight over with fixed values per case
#                            - Asked the stand-in of the world's list why a fight is over, and answered a defeat's refusal and undo with fixed values per case
#                            - Asked the stand-in of the pools whether a troop's milestone is beaten
#                            - Checked that a value written over that the bridge cannot carry stays with the scripts
#                            - Handed and expected sites as plain values, and checked that the DLL reads the sites of an earlier release's save once
#                            - Read the scripts' clock from $frame
#      Paulinchen  2026-10-28: Answered the freeze's tables as the DLL's events database does
#                            - Checked writes the DLL refuses, writes the journal looks away from and a defeat whose start the journal lost
#      Paulinchen  2026-10-23: Ran on the shared stand-in bridge, whose journal keeps the story's writes, and replayed the journal's golden cases
#                            - Checked a resume from a boat in place of its refusal
#      Paulinchen  2026-10-17: Created
#
#----------------------------------------------------------------

# Covers battles_raid_freeze.rbx with battles_raid_bosses.rbx: the record a raid boss fight takes at
# its battle command, inside the common events its event calls too; the undo of a defeat's changes
# once its chain ended; the game's retry and a load; the resume onto the battle's spot with the
# scene as it stood, inside branches, choices and loops; the fresh start of a player without a
# record from the spot its trigger starts it on, the hidden events passing through; the stand-ins
# of a fight, its boss and the events only its scene shows while the map's own stay live, and of a
# cutscene fight; the joiner's spot; and the save field. The interpreter runs real fibers as the
# game's does; the raid pool, the freeze's tables (as the DLL's events database answers them), the
# world's story and the world's entries are stand-ins; the DLL's write journal is the shared stand-in bridge's (rules_support.rb),
# and the DLL's rules of the records, the tableau's place, the fresh start and the items answer with
# fixed values per case (raid_support.rb), which MGQOnline.Multiplayer.Tests and MGQOnline.Game.Tests cover.

require_relative "rules_support"

# Stands in for the mod's base script, whose log prints each line and keeps it in $log.
module MGQ_Multiplayer; module Log; def self.write(m); $log << m; puts "  log: #{m}"; end; end; end
$log = []

# The game's data classes the freeze reads.
module RPG
  # A command of an event's list.
  EventCommand = Struct.new(:code, :indent, :parameters)
  # A map event of a map's data: its place, its graphic and its pages.
  Event = Struct.new(:id, :x, :y, :character_name, :pages)
  # A page of a map event: its commands, the test that tells it applies (nil for always), its
  # picture (nil for the event's), how it moves by itself (nil for not at all) and what starts it
  # (nil for the action button).
  EventPage = Struct.new(:list, :condition, :character_name, :move_type, :trigger)
  # A page's test that names the switches it needs, as the game's page conditions do.
  class EventPageCondition
    attr_reader :switch1_valid, :switch1_id, :switch2_valid, :switch2_id
    # Makes the test of one or two switches, all of them on.
    #
    # @param ids [Array<Integer>] The switches.
    def initialize(*ids)
      @ids = ids
      @switch1_valid = !ids[0].nil?; @switch1_id = ids[0].to_i
      @switch2_valid = !ids[1].nil?; @switch2_id = ids[1].to_i
    end
    # Answers whether every switch is on.
    def call; @ids.all? { |id| $game_switches[id] }; end
  end
  # A common event of the database.
  CommonEvent = Struct.new(:id, :list)
  # A map's data, its events by id.
  MapData = Struct.new(:events)
  # Music, noting what plays in $played and answering the last one played.
  class BGM < Struct.new(:name, :volume, :pitch)
    # Answers the music playing, $bgm.
    def self.last; $bgm; end
    # Notes that the music stopped.
    def self.stop; $played << [:bgm_stop]; end
    # Plays the music from a position, noting it.
    #
    # @param pos [Integer] The position.
    def play(pos = 0); $played << [:bgm, name, pos]; end
    # Answers the position the music stood at: $bgm_pos.
    def pos; $bgm_pos; end
  end
  # A sound, as the music.
  class BGS < Struct.new(:name, :volume, :pitch)
    # Answers the sound playing: none.
    def self.last; nil; end
    # Notes that the sound stopped.
    def self.stop; $played << [:bgs_stop]; end
    # Plays the sound, noting it.
    #
    # @param pos [Integer] The position.
    def play(pos = 0); $played << [:bgs, name, pos]; end
  end
end

# An item of the database, by its kind's letter and id.
Item = Struct.new(:letter, :id, :name)
$data_items = Array.new(560)
$data_items[557] = Item.new("i", 557, "Remina Key Card")
$data_items[1] = Item.new("i", 1, "Potion")
$data_weapons = []
$data_armors = []

# The game's switches, as the game keeps them.
class Game_Switches
  # Makes the switches, all off.
  def initialize; @data = []; end
  # Answers a switch, off unless set.
  def [](id); @data[id] || false; end
  # Sets a switch, and the map's events look at the story again.
  def []=(id, value); @data[id] = value; $game_map.need_refresh = true if $game_map; end
end
# The game's variables, as the game keeps them.
class Game_Variables
  # Makes the variables, all 0.
  def initialize; @data = []; end
  # Answers a variable, 0 unless set.
  def [](id); @data[id] || 0; end
  # Sets a variable, and the map's events look at the story again.
  def []=(id, value); @data[id] = value; $game_map.need_refresh = true if $game_map; end
end
# The game's self switches, as the game keeps them.
class Game_SelfSwitches
  # Makes the self switches, all off.
  def initialize; @data = {}; end
  # Answers a self switch, off unless set.
  def [](key); @data[key] == true; end
  # Sets a self switch.
  def []=(key, value); @data[key] = value; end
end

# The save's system object, with its battle music.
class Game_System; attr_accessor :battle_bgm; end
# The game's temporary state, with a transfer's fade.
class Game_Temp; attr_accessor :fade_type; end
# The message window's state, busy while $busy is.
class Game_Message; def busy?; $busy; end; end
# The battle's troop.
class Game_Troop; def setup(troop_id); @troop_id = troop_id; end; end

# The party: its items by letter and id, its temporary members and split parties.
class Game_Party
  attr_accessor :in_battle
  # Makes a party without items or temporary members.
  def initialize; @items = {}; @temp_actors = []; @multi_party_flag = false; @multi_party = nil; @in_battle = false; end
  # Answers how many of an item the party has.
  #
  # @param item [Item] The item.
  # @return [Integer] How many.
  def item_number(item); @items[[item.letter, item.id]] || 0; end
  # Gives the party items, or takes them for a negative count.
  #
  # @param item [Item] The item.
  # @param count [Integer] How many.
  def gain_item(item, count); @items[[item.letter, item.id]] = item_number(item) + count; end
end

# A picture of the screen.
class Game_Picture
  attr_reader :number, :name
  # Makes a picture without an image.
  #
  # @param number [Integer] Its number.
  def initialize(number); @number = number; @name = ""; end
  # Shows an image.
  #
  # @param name [String] The image.
  def show(name); @name = name; end
  # Takes the image away.
  def erase; @name = ""; end
end
# The screen's pictures, made as they are asked for.
class Game_Pictures
  # Makes the list, empty.
  def initialize; @data = []; end
  # Answers a picture, making it.
  #
  # @param number [Integer] Its number.
  # @return [Game_Picture] The picture.
  def [](number); @data[number] ||= Game_Picture.new(number); end
end
# The map's screen: its tone and pictures.
class Game_Screen
  attr_reader :pictures
  attr_accessor :tone
  # Makes the screen, cleared.
  def initialize; @pictures = Game_Pictures.new; clear; end
  # Clears the tone and takes every picture away, as the game's post-defeat processing does.
  def clear; @tone = [0, 0, 0]; @pictures.instance_variable_get(:@data).compact.each(&:erase); end
end

# A character on the map, as the game's Game_CharacterBase keeps it.
class Game_Character
  attr_reader :id, :x, :y, :direction, :pattern, :character_name, :character_index, :tile_id, :opacity, :blend_type, :priority_type,
              :through, :direction_fix, :walk_anime, :step_anime, :move_speed
  attr_accessor :transparent
  # Makes a character at 0,0 facing down.
  def initialize
    @id = 0; @x = 0; @y = 0; @direction = 2; @pattern = 1; @original_pattern = 1; @character_name = ""; @character_index = 0; @tile_id = 0
    @opacity = 255; @blend_type = 0; @priority_type = 1; @through = false; @transparent = false; @direction_fix = false; @walk_anime = true
    @step_anime = false; @move_speed = 4
  end
  # Moves the character.
  def moveto(x, y); @x = x; @y = y; end
  # Turns the character, unless its direction is fixed or the direction is none.
  def set_direction(direction); @direction = direction if !@direction_fix && direction != 0; end
  # Gives the character a graphic.
  def set_graphic(name, index); @tile_id = 0; @character_name = name; @character_index = index; @original_pattern = 1; end
end

# A map event, built from the map's data as the game's is, showing the last page whose test holds.
# A page set up anew takes its picture and passes through only without a page, as the game's does:
# the page's own picture, else the event's, and none without a page.
class Game_Event < Game_Character
  attr_reader :starting, :list
  # Makes the event of the map's data.
  #
  # @param map_id [Integer] The map.
  # @param event [RPG::Event] The event's data.
  def initialize(map_id, event)
    super()
    @map_id = map_id; @event = event; @id = event.id; @erased = false; @starting = false; @page = false
    moveto(event.x, event.y)
    refresh
  end
  # Finds the page that applies.
  def refresh
    page = @erased ? nil : @event.pages.reverse.find { |each| each.condition.nil? || each.condition.call }
    return if page.equal?(@page)

    @page = page
    @list = page && page.list
    @character_name = page ? (page.character_name || @event.character_name).to_s : ""
    @through = page.nil?
  end
  # Answers whether the event stands among the characters, as the game's priority 1.
  def normal_priority?; @priority_type == 1; end
  # Answers the page's index, as coop.rbx does.
  def mgq_mp_page; @page ? @event.pages.index(@page) : -1; end
  # Answers the pages, as coop.rbx does.
  def mgq_mp_pages; @event.pages; end
  # Starts the event.
  def start; @starting = true; end
  # Clears the start.
  def clear_starting_flag; @starting = false; end
  # Unlocks the event.
  def unlock; end
  # Erases the event for the map's stay.
  def erase; @erased = true; refresh; end
end

# A follower of the player.
class Game_Follower < Game_Character; end
# The player's followers.
class Game_Followers
  attr_accessor :visible
  # Makes two followers, shown.
  def initialize; @visible = true; @data = [Game_Follower.new, Game_Follower.new]; end
  # Runs a block for each follower.
  def each(&block); @data.each(&block); end
end
# A vehicle, which follows the player while driven and stands where it was left otherwise, as the
# game's does.
class Game_Vehicle < Game_Character
  attr_reader :driving
  # Makes the vehicle, on no map.
  def initialize; super; @map_id = 0; @driving = false; end
  # Places the vehicle.
  def set_location(map_id, x, y); @map_id = map_id; @x = x; @y = y; refresh; end
  # Follows the player while driven.
  def refresh
    return unless @driving

    @map_id = $game_map.map_id
    @x = $game_player.x; @y = $game_player.y; @direction = $game_player.direction
  end
  # Lets the player off, facing left.
  def get_off; @driving = false; @direction = 4; end
end
# The player, whose transfer works as the game's.
class Game_Player < Game_Character
  attr_reader :followers
  # Answers the vehicle the player drives, nil on foot.
  def vehicle; $game_map.vehicle(@vehicle_type); end
  # Gets off the vehicle where the player stands, as the game's does.
  def forced_get_off_vehicle
    return unless vehicle

    vehicle.get_off
    @vehicle_type = :walk
    @transparent = false
  end
  # Makes the player on foot.
  def initialize; super; @followers = Game_Followers.new; @vehicle_type = :walk; @transferring = false; @new_map_id = 0; end
  # Reserves a transfer.
  def reserve_transfer(map_id, x, y, direction = 2); @transferring = true; @new_map_id = map_id; @new_x = x; @new_y = y; @new_direction = direction; end
  # Answers whether a transfer waits.
  def transfer?; @transferring; end
  # Performs the transfer reserved.
  def perform_transfer
    return unless transfer?

    set_direction(@new_direction)
    $game_map.setup(@new_map_id) if @new_map_id != $game_map.map_id
    moveto(@new_x, @new_y)
    vehicle.refresh if vehicle
    @transferring = false
  end
  # Counts the player's refreshes in $refreshes.
  def refresh; $refreshes += 1; end
end

# The map: its events from $maps, its screen and interpreter, updated as the game's.
class Game_Map
  attr_reader :map_id, :events, :interpreter, :screen, :display_x, :display_y, :parallax_name, :battleback1_name, :battleback2_name
  attr_accessor :need_refresh
  # Makes the map, with no map set up.
  def initialize
    @map_id = 0; @events = {}; @interpreter = Game_Interpreter.new; @screen = Game_Screen.new; @display_x = 0; @display_y = 0
    @tileset_id = 1; @parallax_name = ""; @parallax_loop_x = false; @parallax_loop_y = false; @parallax_sx = 0; @parallax_sy = 0
    @battleback1_name = ""; @battleback2_name = ""
    @vehicles = { :boat => Game_Vehicle.new, :ship => Game_Vehicle.new, :airship => Game_Vehicle.new }
  end
  # Answers a vehicle by its type, nil for none.
  def vehicle(type); @vehicles[type]; end
  # Sets a map up, its events anew from $maps.
  #
  # @param map_id [Integer] The map.
  def setup(map_id)
    @map_id = map_id
    @events = {}
    ($maps[map_id] || []).each { |event| @events[event.id] = Game_Event.new(map_id, event) }
    @tileset_id = 1
    @parallax_name = ""
  end
  # Moves the camera.
  def set_display_pos(x, y); @display_x = x; @display_y = y; end
  # Has the events find their pages.
  def refresh; @events.each_value(&:refresh); @need_refresh = false; end
  # Changes the tileset.
  def change_tileset(id); @tileset_id = id; refresh; end
  # Changes the parallax.
  def change_parallax(name, loop_x, loop_y, sx, sy); @parallax_name = name; @parallax_loop_x = loop_x; @parallax_loop_y = loop_y; @parallax_sx = sx; @parallax_sy = sy; end
  # Changes the battle backs.
  def change_battleback(one, two); @battleback1_name = one; @battleback2_name = two; end
  # Answers whether a tile lies on the map, 100 by 100 tiles.
  def valid?(x, y); x >= 0 && y >= 0 && x < 100 && y < 100; end
  # Answers whether a tile is passable, every tile but those of $walls.
  def passable?(x, y, _direction); !$walls.include?([x, y]); end
  # Answers the x of the tile next to x in a direction.
  def round_x_with_direction(x, direction); x + { 4 => -1, 6 => 1 }.fetch(direction, 0); end
  # Answers the y of the tile next to y in a direction.
  def round_y_with_direction(y, direction); y + { 2 => 1, 8 => -1 }.fetch(direction, 0); end
  # Lists the events on a tile that do not pass through.
  def events_xy_nt(x, y); @events.values.select { |event| event.x == x && event.y == y && !event.through }; end
  # Runs a frame: the events look at the story, then the interpreter runs.
  def update(main = false); refresh if @need_refresh; update_interpreter if main; end
  # Runs the interpreter as the game's does, with $in_map set as MGQ_MpRaidPool.in_map notes it.
  def update_interpreter
    $in_map = true
    loop do
      @interpreter.update
      return if @interpreter.running?

      @interpreter.clear if @interpreter.event_id > 0
      return unless setup_starting_map_event
    end
  ensure
    $in_map = false
  end
  # Sets the starting event up, as the game's does.
  def setup_starting_map_event
    event = @events.values.find(&:starting)
    event.clear_starting_flag if event
    @interpreter.setup(event.list, event.id) if event
    event
  end
end

# The interpreter, as the game's runs its commands in a fiber; it notes each command it runs in
# $executed as its depth and index. Code 900 notes its parameter in $ran, 901 clears the screen.
class Game_Interpreter
  attr_reader :map_id, :event_id
  # Makes an interpreter.
  #
  # @param depth [Integer] How deep in common event calls it runs.
  def initialize(depth = 0); @depth = depth; clear; end
  # Forgets the event.
  def clear; @map_id = 0; @event_id = 0; @list = nil; @index = 0; @branch = {}; @fiber = nil; end
  # Starts commands in a fiber of their own.
  def setup(list, event_id = 0); clear; @map_id = $game_map.map_id; @event_id = event_id; @list = list; @fiber = Fiber.new { run } if @list; end
  # Answers whether the interpreter runs on the map it started on.
  def same_map?; @map_id == $game_map.map_id; end
  # Runs the commands to the end, then waits a frame before it ends.
  def run
    Fiber.yield while $game_message.busy?
    while @list[@index]
      execute_command
      @index += 1
    end
    Fiber.yield
    @fiber = nil
  end
  # Answers whether commands run.
  def running?; !@fiber.nil?; end
  # Runs on to the next wait.
  def update; @fiber.resume if @fiber; end
  # Runs the command at the interpreter's place.
  def execute_command
    command = @list[@index]
    @params = command.parameters
    @indent = command.indent
    $executed << [@depth, @index]
    name = "command_#{command.code}"
    send(name) if respond_to?(name)
  end
  # Skips the commands deeper than the current one.
  def command_skip; @index += 1 while @list[@index + 1].indent > @indent; end
  # A conditional branch on a switch or a variable (equal to, at least).
  def command_111
    result = case @params[0]
             when 0 then $game_switches[@params[1]] == (@params[2] == 0)
             when 1 then @params[4] == 0 ? $game_variables[@params[1]] == @params[3] : $game_variables[@params[1]] >= @params[3]
             else false
             end
    @branch[@indent] = result
    command_skip unless result
  end
  # The else branch.
  def command_411; command_skip if @branch[@indent]; end
  # Shows choices, answered with $answer at once.
  def command_102; @branch[@indent] = $answer; end
  # A choice's branch.
  def command_402; command_skip if @branch[@indent] != @params[0]; end
  # The cancel branch.
  def command_403; command_skip if @branch[@indent] != 4; end
  # A loop's start.
  def command_112; end
  # A loop's end, back to its start.
  def command_413
    begin
      @index -= 1
    end until @list[@index].indent == @indent
  end
  # Breaks out of a loop.
  def command_113
    loop do
      @index += 1
      return if @index >= @list.size - 1
      return if @list[@index].code == 413 && @list[@index].indent < @indent
    end
  end
  # Calls a common event, as the game's does.
  def command_117
    common = $data_common_events[@params[0]]
    return unless common

    child = Game_Interpreter.new(@depth + 1)
    child.setup(common.list, same_map? ? @event_id : 0)
    child.run
  end
  # Turns switches on (0) or off (1).
  def command_121; (@params[0]..@params[1]).each { |id| $game_switches[id] = @params[2] == 0 }; $game_map.need_refresh = true; end
  # Sets variables (0) or adds to them (1).
  def command_122
    (@params[0]..@params[1]).each { |id| $game_variables[id] = @params[2] == 1 ? $game_variables[id] + @params[4] : @params[4] }
    $game_map.need_refresh = true
  end
  # Turns a self switch of the event on (0) or off (1).
  def command_123; $game_self_switches[[@map_id, @event_id, @params[0]]] = @params[1] == 0; $game_map.need_refresh = true; end
  # Transfers the player and waits for it.
  def command_201
    $game_player.reserve_transfer(@params[1], @params[2], @params[3], @params[4])
    Fiber.yield while $game_player.transfer?
  end
  # Waits frames.
  def command_230; @params[0].times { Fiber.yield }; end
  # Starts a battle and waits for it, as the game's does.
  def command_301
    return if $game_party.in_battle

    BattleManager.setup(@params[1], @params[2], @params[3])
    BattleManager.event_proc = Proc.new { |n| @branch[@indent] = n }
    SceneManager.call(Scene_Battle)
    Fiber.yield
  end
  # Notes the common event, as the game's command 999 does.
  def command_999; @common_event_id = @params[0]; end
  # Notes a mark in $ran.
  def command_900; $ran << @params[0]; end
  # Clears the screen, as the post-defeat processing does.
  def command_901; $game_map.screen.clear; end
end

# The battle's start and end as the game's: the retry loads the save the battle's start kept, a
# defeat clears the map's interpreter and goes on to the defeat's scene.
module BattleManager
  # Sets a battle up.
  def self.setup(troop_id, can_escape = true, can_lose = false)
    @troop_id = troop_id; @can_escape = can_escape; @can_lose = can_lose; @event_proc = nil
    $game_troop.setup(troop_id)
  end
  # Takes the handler of the battle's result.
  def self.event_proc=(proc); @event_proc = proc; end
  # Keeps the save for a retry, as the battle starts.
  def self.battle_start; @retry_data = Marshal.dump(DataManager.make_save_contents); end
  # Ends the battle, handing its result to the event.
  def self.battle_end(result); $game_party.in_battle = false; @event_proc.call(result) if @event_proc; @event_proc = nil; end
  # Loses the battle: the map's interpreter is dropped and the defeat's scene follows.
  def self.process_defeat
    $game_map.interpreter.clear unless memory_battle?
    SceneManager.goto(Scene_Novel)
    battle_end(2)
    true
  end
  # Fights the lost battle again from the save its start kept.
  def self.retry_battle
    return false unless @retry_data

    DataManager.extract_save_contents(Marshal.load(@retry_data))
    setup(@troop_id, @can_escape, @can_lose)
    SceneManager.call(Scene_Battle)
    true
  end
  # Answers whether a replay of the Library runs: $memory.
  def self.memory_battle?; $memory; end
end
# The saves, of the objects the freeze reads.
module DataManager
  # Makes a save's contents.
  def self.make_save_contents
    { :system => $game_system, :switches => $game_switches, :variables => $game_variables, :self_switches => $game_self_switches, :party => $game_party }
  end
  # Puts a save's contents in place.
  def self.extract_save_contents(contents)
    $game_system = contents[:system]; $game_switches = contents[:switches]; $game_variables = contents[:variables]
    $game_self_switches = contents[:self_switches]; $game_party = contents[:party]
  end
  # Names a map's file.
  def self.map_file_name(map_id); "Map#{map_id}"; end
end
# Reads a map's data from $map_files.
def load_data(name); $map_files.fetch(name); end
# Counts the frames in $frame.
clock_from { $frame }
# The scenes, the running one in $scene.
module SceneManager
  # Answers the running scene.
  def self.scene; $scene; end
  # Calls a scene.
  def self.call(klass); $scene = klass.new; end
  # Goes to a scene.
  def self.goto(klass); $scene = klass.new; end
end
# The map's scene: a frame runs the map, then the transfer, as the game's.
class Scene_Map
  # Runs a frame.
  def update
    $frame += 1
    $game_map.update(true)
    $game_player.perform_transfer if $game_player.transfer?
  end
end
# The battle's scene, which starts the battle.
class Scene_Battle; def initialize; $game_party.in_battle = true; BattleManager.battle_start; end; end
# The defeat's scene.
class Scene_Novel; end
# The title screen.
class Scene_Title; def start; end; end

# Stands in for the raid pool: the player plays a Raid World's story while $active is, the battle
# set up last fights as $kind and $fight is the fight.
module MGQ_MpRaidPool
  # A fight against a pool.
  Fight = Struct.new(:troop, :side)
  # Answers whether the pools apply.
  def self.active?; $active; end
  # Answers the kind of the battle set up last.
  def self.set_up_kind; $kind; end
  # Answers whether the map's interpreter runs.
  def self.in_map?; $in_map; end
  # Answers the fight.
  def self.fight; $fight; end
  # Answers a boss's key.
  def self.key_of(troop); { 868 => "Sonya Mazda", 807 => "Spider Princess", 870 => "Sonya Chaos" }[troop.to_i] || "Boss #{troop}"; end
  # Answers whether a Hades rematch runs: $hades.
  def self.hades?; $hades; end
  # Answers a boss's name.
  def self.troop_label(troop); key_of(troop); end
end
# Stands in for the DLL's events database: the freeze's tables of a few fights, which the checks
# change and then have the engine read anew (reread_tables).
module FreezeTables
  # The fights' sites: key, index, indent, preamble's start and whether on a cutscene map.
  SITES = {
    607 => [[["map", 138, 16, 1], 1, 0, 1, false]],
    807 => [[["ce", 347], 11, 2, 9, false]],
    868 => [[["map", 138, 13, 1], 7, 1, 4, false]],
    870 => [[["map", 728, 12, 1], 2, 0, 0, true], [["map", 749, 13, 1], 2, 0, 0, true]],
  }
  # How the story enters each cutscene site: its field sources, side switch and entry spot; the DLL
  # hands them as rows, since a Hash that crosses the bridge has no Array keys.
  SCENES = {
    ["map", 728, 12, 1] => [[[138, 13, 32, 8]], 4, [728, 0, 0, 0]],
    ["map", 749, 13, 1] => [[[138, 13, 32, 8]], 5, [749, 1, 0, 0]],
  }
  # The cutscene maps.
  SCENE_MAPS = [728, 746, 747, 749]
end
# Stands in for the world's entries of frozen fights: $entries by troop, notes kept in $noted, the
# troops whose fight ended for the world in $final, and the battles won in $won.
module MGQ_MpWorldFreeze
  # Answers the world's entry of a troop.
  def self.entry(troop); $entries[troop.to_i]; end
  # Notes an entry.
  def self.note(entry); $noted << entry; true; end
  # Answers whether a troop's fight ended for the world.
  def self.final?(troop); ($final || []).include?(troop.to_i); end
  # Notes a battle won.
  def self.won(troop); ($won ||= []) << troop.to_i; end
end
# Stands in for the world's story of world $world: switch 22 and the self switch "chest" are the
# player's own.
module MGQ_MpWorldStory
  # Answers the world's id.
  def self.world_id; $world; end
  # Compares two values as the world's story does.
  def self.same?(kind, one, other)
    return (one.nil? ? 0 : one) == (other.nil? ? 0 : other) if kind == 1

    (one ? true : false) == (other ? true : false)
  end
  # Answers whether a value is the player's own.
  def self.personal?(kind, key); (kind == 0 && key == 22) || (kind == 2 && key[2] == "chest"); end
end
# Stands in for the story's state model's raw access.
module MGQ_MpStoryState
  # Answers the data of switches, variables or self switches.
  def self.data_of(object); object.instance_variable_get(:@data); end
  # Copies a story deeply.
  def self.deep_copy(story); Marshal.load(Marshal.dump(story)); end
  # Turns a variable's value into what the bridge carries, as story_state.rbx does.
  def self.plain_variable(value); value.is_a?(Float) ? { "float" => value.to_s } : [Integer, Float, String, TrueClass, FalseClass].any? { |kind| value.is_a?(kind) } ? value : nil; end
  # Turns a value the bridge carried back into the variable's, as story_state.rbx does.
  def self.variable_value(value); value.is_a?(Hash) ? value["float"].to_s.to_f : value; end
end
# Stands in for coop_events.rbx, noting each block it runs as story in $as_story.
module MGQ_MpCoopEvents
  # Runs a block as story, counting it.
  def self.as_story; $as_story += 1; yield; end
  # Answers what the DLL's events database finds in a page: it runs nothing when it holds only its end.
  def self.page_flags(event, place); { "runs_nothing" => event.mgq_mp_pages[place].list.all? { |command| command.code == 0 } }; end
end
# Stands in for the co-op scope, the story's teller being $teller.
module MGQ_MpCoop; module Scope; def self.teller; $teller; end; end; end
# Stands in for the world's sync: the player is free on a quiet map.
module MGQ_MpOverworldSync
  # A player in the world's room.
  module Peers; Peer = Struct.new(:seat, :state); end
  # Answers whether the player is free on the map.
  def self.map_free?; $scene.is_a?(Scene_Map) && !$game_map.interpreter.running? && !$game_player.transfer?; end
end
# Stands in for the notification box, keeping its messages in $notices.
module MGQ_MpNotices; def self.message(_key, text, _frames); $notices << text; end; end
# Stands in for the hotkeys, the join hotkey being J.
module MGQ_MpHotkeys; def self.label(_action); "J"; end; end

load_script "battles_raid_bosses"
load_script "battles_raid_freeze"
open_rules_bridge
freeze = MGQ_MpRaidFreeze
$world_bridge.answer("raid.sites") do |request|
  $sites_asked = request["troops"]
  { "sites" => FreezeTables::SITES, "scenes" => FreezeTables::SCENES.to_a,
    "scene_maps" => FreezeTables::SCENE_MAPS }
end

# Has the engine read the freeze's tables anew, as after a check changed them.
def reread_tables
  MGQ_MpRaidFreeze.instance_variable_set(:@tables, nil)
end

check("the freeze's tables come from the DLL for every raid boss troop", [freeze.data(:SITES, {}).keys.sort, $sites_asked.include?(868), $sites_asked == $sites_asked.sort],
      [FreezeTables::SITES.keys.sort, true, true])

# Makes a command.
#
# @param code [Integer] Its code.
# @param indent [Integer] Its indent.
# @param params [Array] Its parameters.
# @return [RPG::EventCommand] The command.
def c(code, indent, *params)
  RPG::EventCommand.new(code, indent, params)
end

# Sonya Mazda's page: it sets the story on, turning page 2 on, and fights inside a branch.
SONYA_PAGE = RPG::EventPage.new([
  c(121, 0, 31, 31, 0), c(122, 0, 1075, 1075, 0, 0, 16), c(230, 0, 1), c(111, 0, 0, 4, 0),
  c(132, 1), c(121, 1, 22, 22, 0), c(283, 1), c(301, 1, 0, 868, false, false), c(121, 1, 7009, 7009, 0), c(900, 1, :won), c(0, 1),
  c(412, 0), c(0, 0),
], lambda { $game_variables[1075] >= 14 }, nil, nil, 3)
# Sonya Mazda's later page, once the story moved on.
SONYA_LATER = RPG::EventPage.new([c(900, 0, :page2), c(0, 0)], lambda { $game_variables[1075] >= 16 })
# An earlier phase's page.
PHASE_PAGE = RPG::EventPage.new([c(122, 0, 1020, 1020, 0, 0, 5), c(301, 0, 0, 607, false, false), c(0, 0)], nil)
# The page of a fight inside a choice that calls a common event, which calls another.
SPIDER_PAGE = RPG::EventPage.new([
  c(102, 0, ["A", "B"], 1), c(402, 0, 0, "A"), c(117, 1, 340), c(900, 1, :after_ce), c(0, 1),
  c(402, 0, 1, "B"), c(900, 1, :chose_b), c(0, 1), c(404, 0), c(0, 0),
], nil)
# Sonya Chaos's cutscene pages, one per side.
CHAOS_PAGE = RPG::EventPage.new([c(132, 0), c(121, 0, 22, 22, 0), c(301, 0, 0, 870, false, false), c(0, 0)], nil)
# The same on the other side's cutscene map.
CHAOS_ILIAS_PAGE = RPG::EventPage.new([c(132, 0), c(121, 0, 22, 22, 0), c(301, 0, 0, 870, false, false), c(0, 0)], nil)
# The maps' events by map: Sonya Mazda's field with a villager, an invisible event and an earlier
# phase; Hades; the Spider Princess; Sonya Chaos's two cutscene maps.
$maps = {
  138 => [RPG::Event.new(13, 32, 8, "$sonya", [SONYA_PAGE, SONYA_LATER]), RPG::Event.new(14, 28, 9, "villager", [RPG::EventPage.new([c(0, 0)], nil)]),
          RPG::Event.new(15, 20, 20, "", [RPG::EventPage.new([c(0, 0)], nil)]), RPG::Event.new(16, 10, 10, "alma", [PHASE_PAGE])],
  154 => [],
  214 => [RPG::Event.new(42, 5, 5, "$spider", [SPIDER_PAGE])],
  728 => [RPG::Event.new(12, 0, 0, "$sonya_chaos", [CHAOS_PAGE])],
  749 => [RPG::Event.new(13, 1, 0, "$sonya_chaos", [CHAOS_ILIAS_PAGE])],
}
# The map files a probe of another map's event reads.
$map_files = { "Map749" => RPG::MapData.new({ 13 => $maps[749][0] }), "Map728" => RPG::MapData.new({ 12 => $maps[728][0] }) }
# The common events: 340 calls 347 inside a branch, 347 fights inside a loop.
$data_common_events = []
$data_common_events[340] = RPG::CommonEvent.new(340, [
  c(999, 0, 340), c(111, 0, 0, 50, 0), c(117, 1, 347), c(0, 1), c(411, 0), c(900, 1, :else_ran), c(0, 1), c(412, 0), c(0, 0),
])
$data_common_events[347] = RPG::CommonEvent.new(347, [
  c(999, 0, 347), c(122, 0, 60, 60, 0, 0, 0), c(112, 0), c(122, 1, 60, 60, 1, 0, 1), c(111, 1, 1, 60, 0, 3, 1), c(113, 2), c(0, 2), c(412, 1),
  c(111, 1, 1, 60, 0, 2, 0), c(132, 2), c(121, 2, 22, 22, 0), c(301, 2, 0, 807, false, false), c(0, 2), c(412, 1), c(900, 1, :loop_body), c(0, 1),
  c(413, 0), c(900, 0, :ce347_after), c(0, 0),
])
# The rest of the post-defeat processing, as it runs on the map: its own writes, a cleared screen,
# other music and the transfer to Hades.
CHAIN = [c(121, 0, 22, 22, 1), c(121, 0, 31, 31, 1), c(122, 0, 11, 11, 0, 0, 3), c(901, 0), c(201, 0, 0, 154, 5, 5, 2), c(0, 0)]

# What the DLL answers of the keys the defeats below change: the values the event set before the
# battle go back to their start values, the others to their values at the defeat, a self switch
# named by no id; the player's own and those the post-defeat processing writes itself it leaves out.
UNDO = { [1, 1001] => "start", [1, 1075] => "start", [1, 1020] => "start", [0, 2307] => "was", [2, 0] => "was" }

# What the DLL plans at a lost battle's end whose record the battle took: the record waits as lost.
LOST = { "record" => "lost" }.freeze

# What it plans at a lost battle's end that took no record: nothing.
NO_RECORD = {}.freeze

# What it plans at a won battle's end of a running record: the battle counts as won and the record
# goes.
WON = { "won" => true, "record" => "drop" }.freeze

# What the DLL's records check answers while Sonya Mazda's frozen fight waits.
SONYA_LISTED = { "listed" => [868], "dropped" => [] }.freeze

# Starts the game's objects anew, on map 138 at 32,9 facing up, in world w1's story.
def reset
  $game_switches = Game_Switches.new
  $game_variables = Game_Variables.new
  $game_self_switches = Game_SelfSwitches.new
  $game_party = Game_Party.new
  $game_troop = Game_Troop.new
  $game_system = Game_System.new
  $game_temp = Game_Temp.new
  $game_message = Game_Message.new
  $game_player = Game_Player.new
  $game_map = Game_Map.new
  $scene = Scene_Map.new
  $frame = 0
  $active = true
  $kind = :event
  $fight = nil
  $world = "w1"
  $teller = nil
  $hades = false
  $memory = false
  $busy = false
  $answer = 0
  $as_story = 0
  $refreshes = 0
  $bgm = nil
  $bgm_pos = 0
  [$entries = {}, $noted = [], $notices = [], $ran = [], $executed = [], $played = [], $walls = []]
  $log.clear
  $raid_answers.clear
  $raid_answers.undo = UNDO
  MGQ_MpRaidFreeze.forget
  $game_map.setup(138)
  $game_player.moveto(32, 9)
  $game_player.set_direction(8)
end

# Runs frames of the map's scene.
#
# @param count [Integer] How many.
def frames(count = 1)
  count.times { $scene.update if $scene.is_a?(Scene_Map) }
end

# Starts a map event and runs frames until its battle starts.
#
# @param id [Integer] The event.
def fight_event(id)
  $game_map.refresh
  $game_map.events[id].start
  20.times { break if $scene.is_a?(Scene_Battle); frames }
end

# Wins the battle running and returns to the map.
#
# @param plan [Hash] What the DLL plans at the battle's end, see RaidAnswers#ending.
def win(plan = WON)
  $raid_answers.ending = plan
  BattleManager.battle_end(0)
  $scene = Scene_Map.new
end

# Loses the battle running: the defeat's scene writes, then the rest of the post-defeat processing
# runs on the map until its chain ended.
#
# @param scene [Proc] What the defeat's scene changes.
# @param plan [Hash] What the DLL plans at the battle's end, see RaidAnswers#ending.
# @return [Array<Boolean>] Whether the writes were held right after the defeat, in its scene, and while the map's part ran.
def lose(scene = nil, plan = LOST)
  $raid_answers.ending = plan
  BattleManager.process_defeat
  held = [MGQ_MpRaidFreeze.holding_writes?]
  scene.call if scene
  held << MGQ_MpRaidFreeze.holding_writes?
  $scene = Scene_Map.new
  $game_map.interpreter.setup(CHAIN)
  frames(1)
  held << MGQ_MpRaidFreeze.holding_writes?
  frames(4)
  held
end

# The defeat's scene of Sonya Mazda: the story set back, the card taken, a self switch set.
SONYA_DEFEAT = lambda do
  $game_variables[1075] = 12
  $game_switches[2307] = false
  $game_party.gain_item($data_items[557], -1)
  $game_self_switches[[138, 13, "A"]] = true
  $bgm = RPG::BGM.new("Hades", 100, 100)
end

# Lists whether a value holds core types only.
#
# @param value [Object] The value.
# @return [Boolean] Whether it does.
def core_only?(value)
  case value
  when nil, true, false, Integer, Float, String then true
  when Array then value.all? { |item| core_only?(item) }
  when Hash then value.all? { |key, item| core_only?(key) && core_only?(item) }
  else false
  end
end

# A value written over that the bridge cannot carry stays with the scripts, the DLL's journal
# naming it by its write's number, and comes back as it was.
reset
$game_variables[1077] = [1, 2]
mark = freeze.instance_variable_get(:@seq)
freeze.instance_variable_set(:@run, { :mark => mark })
$game_variables[1077] = 5
calls = $world_bridge.calls.size
diff = freeze.changed_since(mark)
handed = $world_bridge.calls[calls..-1].select { |topic, _| topic == "freeze.journal" }.map { |_, bytes| Marshal.load(bytes)["entries"] }.flatten(1)
check("a value the bridge cannot carry stays with the scripts and comes back as it was", [diff, handed.map { |entry| entry[3] }], [[[1, 1077, [1, 2], 5]], [{ "object" => mark + 1 }]])

# Writes the DLL refuses stay with the scripts until it takes them; meanwhile the journal knows
# nothing since the mark.
reset
mark = freeze.instance_variable_get(:@seq)
freeze.instance_variable_set(:@run, { :mark => mark })
$world_bridge.answer("freeze.journal") { |_request| raise FakeBridge::BadRequest, "refused" }
$game_variables[1075] = 3
freeze.hand_journal
check("writes the DLL refuses stay with the scripts, which know nothing since the mark meanwhile, logged once",
      [freeze.changed_since(mark), $log.grep(/the DLL refused the journal's writes 1 time\(s\) in a row/).size], [nil, 1])
answer_journal($world_bridge)
$game_variables[1076] = 4
check("and go once the DLL takes them again", freeze.changed_since(mark), [[1, 1075, nil, 3], [1, 1076, nil, 4]])

# The world's story the relay hands is no event's to put back: its writes stay out of the journal.
reset
mark = freeze.instance_variable_get(:@seq)
freeze.instance_variable_set(:@run, { :mark => mark })
freeze.unjournaled { $game_variables[1075] = 5 }
$game_switches[2307] = true
check("writes the journal looks away from stay out of it", freeze.changed_since(mark), [[0, 2307, nil, true]])

# A fight at a map page's battle command is recorded, its page by the list that runs.
reset
$game_switches[4] = true
$game_switches[2307] = true
$game_variables[1075] = 14
$game_party.gain_item($data_items[557], 1)
$game_party.instance_variable_set(:@temp_actors, [525])
sonya = $game_map.events[13]
sonya.moveto(31, 8)
sonya.instance_variable_set(:@opacity, 200)
$game_map.screen.tone = [10, 20, 30]
$game_map.screen.pictures[1].show("sonya")
picture = $game_map.screen.pictures[1]
$game_map.set_display_pos(20, 3)
$game_player.followers.visible = false
$bgm = RPG::BGM.new("Sonya", 90, 100)
$bgm_pos = 1234
# Beside the map's villager, invisible event and earlier phase: an angel only the scene's switch 31
# brings out, a figure the scene's switch turns into a large one, and a shopkeeper the story turns
# to a later page of its own.
[RPG::Event.new(17, 30, 6, "angel", [RPG::EventPage.new([c(0, 0)], RPG::EventPageCondition.new(31))]),
 RPG::Event.new(18, 34, 6, "figure", [RPG::EventPage.new([c(0, 0)], nil), RPG::EventPage.new([c(0, 0)], RPG::EventPageCondition.new(31), "$mefist")]),
 RPG::Event.new(19, 36, 9, "shopkeeper", [RPG::EventPage.new([c(101, 0), c(0, 0)], nil), RPG::EventPage.new([c(101, 0), c(0, 0)], lambda { $game_variables[1075] >= 16 }, "shopkeeper_late")]),
].each { |data| $game_map.events[data.id] = Game_Event.new(138, data) }
fight_event(13)
record = freeze.record_for(868)
check("a raid boss fight of the map's event takes a record as its battle is set up", [record && record["state"], $scene.class], ["battle", Scene_Battle])
check("its frame: the page by the list that runs, the battle command's index and the branches", record["frames"], [[["map", 138, 13, 1], 7, { 0 => true }]])
check("while the event shows a later page", $game_map.events[13].mgq_mp_page, 1)
check("it resumes at the preamble's start, at the command's indent", [record["resume"], record["indent"], record["event_id"], record["map"]], [4, 1, 13, 138])
check("it keeps the values the event changed since its start, at both ends, the player's own too",
      [record["start"].sort_by(&:inspect), record["pre"].sort_by(&:inspect)],
      [[[0, 22, nil], [0, 31, nil], [1, 1075, 14]].sort_by(&:inspect), [[0, 22, true], [0, 31, true], [1, 1075, 16]].sort_by(&:inspect)])
check("its stand-ins: the fight's event as the boss and the events only its scene shows, each standing for itself", record["tableau"],
      [138, [[13, 31, 8, 2, 1, "$sonya", 0, 0, 200, 0, 1, 1, 1], [17, 30, 6, 2, 1, "angel", 0, 0, 255, 0, 1, 0, 1],
             [18, 34, 6, 2, 1, "$mefist", 0, 0, 255, 0, 1, 0, 1]], [13]])
check("the villager, the shopkeeper on a later page of the story and the earlier phase stay live, which is logged",
      $log.grep(/the frozen scene of map 138 keeps event 13 as its boss and the events its scene shows \[17, 18\]; 3 other event\(s\) that showed before it stay live/).size, 1)
check("and the player's spot", [record["spot"], record["player"]], [[138, 32, 9, 8], [138, 32, 9, 8, false, false, 4, "walk"]])
check("the music, camera and followers as they were", [record["audio"][0], record["camera"], record["followers"]], [["Sonya", 90, 100, 1234], [20, 3], [false, [[0, 0, 2], [0, 0, 2]]]])
notes = $game_system.instance_variable_get(MGQ_MpRaidFreeze::FIELD)
check("the save field survives a dump and holds core types only", [Marshal.load(Marshal.dump(notes)) == notes, core_only?(notes)], [true, true])
check("and names the world", [notes["world"], notes["records"].keys], ["w1", [868]])

# Lost: the defeat's changes go back once its chain ended, except what the post-defeat processing
# writes itself and the player's own values.
$raid_answers.items = [["i", 557, 1]]
$raid_answers.held = { "start" => [false, true, true], "undone" => [true, false, true] }
held = lose(SONYA_DEFEAT)
check("the writes are held from the defeat through its scene and the map's part, then let go", [held, freeze.holding_writes?], [[true, true, true], false])
check("the post-defeat processing ran and moved the player to Hades", [$game_map.map_id, $game_switches[31], $game_variables[11]], [154, false, 3])
check("a value the event set before the battle goes back to its start value, another to its value at the defeat",
      [$game_variables[1075], $game_switches[2307], $game_self_switches[[138, 13, "A"]]], [14, true, false])
check("the player's own switch stays as the defeat set it", $game_switches[22], false)
check("the DLL hears the party's items at the defeat's start and its end, and the item it names comes back",
      [$raid_answers.asked("freeze.undo").last["items"], $game_party.item_number($data_items[557])], [{ "before" => [["i", 557, 1]], "after" => [] }, 1])
check("each undone value and item is logged", $log.grep(/put back s2307 off -> on, v1075 12 -> 14, self switch 138\.13\.A on -> off, item 557 \+1\z/).size, 1)
check("the fight waits frozen without a message, the stand-in telling enough", record["state"], "frozen")
$raid_answers.checked = SONYA_LISTED
check("no message tells of the frozen fight", $notices.grep(/waits/), [])
check("the DLL picks the held values of the event's start values, the player's own named, and of the undone ones",
      $raid_answers.asked("freeze.records.held").last,
      { "start" => [[0, 22, true], [0, 31, false], [1, 1075, false]], "undone" => [[0, 2307], [1, 1075], [2, [138, 13, "A"]]] })
check("the world hears of it, holding the picked start values, then the picked undone ones",
      $noted.last && $noted.last["held"], [[0, 31, nil], [1, 1075, 14], [0, 2307, true], [2, [138, 13, "A"], nil]])
check("the world's entry carries where the boss waits", [$noted.last["troop"], $noted.last["site"], $noted.last["outer"], $noted.last["scene"], $noted.last["spot"]],
      [868, ["map", 138, 13, 1], ["map", 138, 13, 1], false, [138, 32, 9, 8]])
check("it is the player's own record of the open world", [freeze.records.map { |r| r["troop"] }, freeze.resuming?], [[868], false])

# The resume puts the player on the battle's spot with the scene as it stood and runs the event
# from the preamble.
$game_party.instance_variable_set(:@temp_actors, [])
$executed.clear
$as_story = 0
check("the resume starts", freeze.resume(868), true)
check("and runs from its start until its event stopped", [freeze.resuming?, freeze.resuming?(868), freeze.resuming?(870)], [true, true, false])
check("the party's temporary members come back before the transfer", $game_party.instance_variable_get(:@temp_actors), [525])
frames(1)
check("the player stands on the battle's spot", [$game_map.map_id, $game_player.x, $game_player.y, $game_player.direction], [138, 32, 9, 8])
check("the story at the battle is back", [$game_variables[1075], $game_switches[31], $game_switches[22]], [16, true, true])
event = $game_map.events[13]
check("the events stand and show as at the battle", [event.x, event.y, event.opacity], [31, 8, 200])
check("the screen's tone and picture are back, in the same picture object", [$game_map.screen.tone, $game_map.screen.pictures[1].name, $game_map.screen.pictures[1].equal?(picture)],
      [[10, 20, 30], "sonya", true])
check("the camera, the followers and the music are back", [[$game_map.display_x, $game_map.display_y], $game_player.followers.visible, $played.include?([:bgm, "Sonya", 1234])], [[20, 3], false, true])
interpreter = $game_map.interpreter
check("the event is set up as story at the preamble's start with its branches",
      [interpreter.instance_variable_get(:@index), interpreter.instance_variable_get(:@branch), $as_story], [4, { 0 => true }, 1])
frames(1)
check("its first command run is the preamble's start, then its battle", [$executed.first, $scene.class, record["state"]], [[0, 4], Scene_Battle, "battle"])
check("the resumed battle keeps the record's values", $log.grep(/the resumed fight against Sonya Mazda \(troop 868\) fights as event/).size, 1)
win
frames(3)
check("won, the event goes on after its battle and the record goes", [$ran, $game_switches[7009], freeze.record_for(868)], [[:won], true, nil])
check("and the resume ends with the event", freeze.resuming?, false)

# A resumed battle lost again keeps the record and its first values; one whose event stops before
# its battle stays frozen.
reset
$game_switches[4] = true
$game_variables[1075] = 14
fight_event(13)
lose(SONYA_DEFEAT)
first_start = freeze.record_for(868)["start"].dup
freeze.resume(868)
frames(2)
lose(SONYA_DEFEAT)
record = freeze.record_for(868)
check("a resumed battle lost again freezes again with the first start values", [record["state"], record["start"], $game_variables[1075]], ["frozen", first_start, 14])
freeze.resume(868)
frames(1)
MGQ_MpGame.set($game_map.interpreter, :index, SONYA_PAGE.list.size)
$notices.clear
frames(3)
check("an event that stops before its battle leaves the fight frozen and says so",
      [freeze.record_for(868)["state"], freeze.resuming?, $notices], ["frozen", false, ["Could not resume the fight against Sonya Mazda."]])

# A resume from the boss's own map holds the frozen event's own start until its transfer came.
$game_map.setup(138)
$game_map.refresh
$game_map.events[13].start
$executed.clear
freeze.resume(868)
frames(1)
check("the frozen event's own start waits for the resume's transfer, which runs it from the preamble",
      [$log.grep(/held event 13's start on map 138: the resume of troop 868 waits for its transfer/).size, $executed, $game_map.interpreter.instance_variable_get(:@index)],
      [1, [], 4])

# A lost battle whose defeat puts nothing back drops its record.
reset
$game_switches[4] = true
$game_variables[1075] = 14
fight_event(13)
$memory = true
$raid_answers.defeat = "a replay of the Library"
$raid_answers.ending = { "record" => "drop" }
BattleManager.process_defeat
check("a lost replay of the Library tells the DLL so, puts nothing back as it answers, and its record goes",
      [$raid_answers.asked("freeze.defeat").last["library"], freeze.holding_writes?, freeze.record_for(868), $log.grep(/puts nothing back: a replay of the Library; its record goes/).size],
      [true, false, nil, 1])

# A fight inside a choice, a common event's branch and another's loop: frames by depth, the
# resume hands each common event its place.
reset
$game_switches[50] = true
$game_map.setup(214)
$game_player.moveto(5, 6)
fight_event(42)
record = freeze.record_for(807)
check("a fight two common events deep records every frame with its index, branches and common event, a common event's with its map and event",
      record && record["frames"], [[["map", 214, 42, 1], 2, { 0 => 0 }], [["ce", 340], 2, { 0 => true }, [214, 42]], [["ce", 347], 11, { 1 => true }, [214, 42]]])
check("the innermost list's preamble starts inside the loop's branch", record["resume"], 9)
check("before the battle the loop ran once", [$ran, $game_variables[60]], [[:loop_body], 2])
lose
$ran.clear
$executed.clear
freeze.resume(807)
frames(1)
check("the outer list resumes at its call with its choice's branch", [$executed, $game_map.interpreter.instance_variable_get(:@index)], [[], 2])
frames(1)
check("each common event runs from its recorded place, the innermost from the preamble",
      $executed.first(5), [[0, 2], [1, 2], [2, 9], [2, 10], [2, 11]])
check("the handed common event knows its id", $log.grep(/runs common event 347 from command 9, right before its battle/).size, 1)
win
frames(5)
check("after the battle the loop loops, the else and the other choice are skipped as recorded",
      [$ran, $game_variables[60]], [[:loop_body, :ce347_after, :after_ce], 3])

# What takes no record, logged.
reset
$kind = nil
$game_variables[1075] = 14
$game_switches[4] = true
fight_event(13)
check("a battle that fights no pool as an event's records nothing", [freeze.record_for(868), $log.grep(/troop 868 freezes nothing: it fights no pool as an event's battle \(nil\)/).size], [nil, 1])
reset
$game_variables[1075] = 14
$game_switches[4] = true
kept = FreezeTables::SITES.delete(868)
reread_tables
fight_event(13)
FreezeTables::SITES[868] = kept
reread_tables
check("nor one whose site the data lacks", [freeze.record_for(868), $log.grep(/its site \["map", 138, 13, 1\] is not in the data/).size], [nil, 1])
reset
$game_variables[1075] = 14
$game_switches[4] = true
$game_switches[2307] = true
$final = [868]
fight_event(13)
check("nor one whose fight ended for the world, which is final", [freeze.record_for(868), $log.grep(/troop 868 freezes nothing: its fight ended for the world, for good/).size], [nil, 1])
lose(SONYA_DEFEAT, NO_RECORD)
$final = nil
check("whose loss puts its defeat back as any raid boss loss does, but neither freezes nor tells the world",
      [$game_variables[1075], $game_switches[2307], freeze.record_for(868), $noted, $notices], [14, true, nil, [], []])
reset
$game_variables[1075] = 14
$game_switches[4] = true
$game_map.events[13].start
frames(1)
DataManager.extract_save_contents(DataManager.make_save_contents)
frames(3)
check("nor one whose event's start values are unknown, as after a load", [freeze.record_for(868), $log.grep(/the story's values at its event's start are unknown/).size], [nil, 1])
$game_variables[1075] = 16
$raid_answers.defeat = "the story's values at its event's start are unknown"
lose(SONYA_DEFEAT, NO_RECORD)
check("whose defeat then puts nothing back, as the DLL answers once told the start is unknown", [$game_variables[1075], $log.grep(/puts nothing back: the story's values at its event's start are unknown/).size], [12, 1])

# The game's retry drops the undo; the retried battle's loss undoes with the first battle's values.
reset
$game_switches[4] = true
$game_variables[1075] = 14
$game_switches[2307] = true
fight_event(13)
$raid_answers.ending = LOST
BattleManager.process_defeat
check("a defeat holds the writes", freeze.holding_writes?, true)
SONYA_DEFEAT.call
BattleManager.retry_battle
check("the game's retry drops them, logged", [freeze.holding_writes?, $log.grep(/the game's retry ran: the lost battle's defeat puts nothing back/).size], [false, 1])
check("and keeps the first battle's snapshots", [$log.grep(/the game's retry of troop 868 keeps the first battle's snapshots\z/).size, freeze.record_for(868)["state"]], [1, "battle"])
lose(SONYA_DEFEAT)
check("the retried battle's loss puts back as the first one's would", [$game_variables[1075], $game_switches[2307], freeze.record_for(868)["state"]], [14, true, "frozen"])

# A load forgets the defeat under way and the resume.
reset
$game_switches[4] = true
$game_variables[1075] = 14
fight_event(13)
$raid_answers.ending = LOST
BattleManager.process_defeat
DataManager.extract_save_contents(DataManager.make_save_contents)
check("a load drops the pending undo and the battle", [freeze.holding_writes?, freeze.instance_variable_get(:@battle)], [false, nil])

# A defeat whose start the journal lost puts back nothing of the story, but the items, and its record
# goes.
reset
$game_switches[4] = true
$game_switches[2307] = true
$game_variables[1075] = 14
$game_party.gain_item($data_items[557], 1)
fight_event(13)
$world_bridge.answer("freeze.since") { |_mark| { "rows" => [], "overflow" => true } }
$raid_answers.items = [["i", 557, 1]]
lose(SONYA_DEFEAT)
answer_journal($world_bridge)
check("a defeat whose start the journal lost puts back nothing of the story", [$game_variables[1075], $game_switches[2307]], [12, false])
check("but the item it took, and the record goes, logged",
      [$game_party.item_number($data_items[557]), freeze.record_for(868), $log.grep(/the journal lost the story at its start: put back nothing of the story, item 557 \+1; its record goes\z/).size],
      [1, nil, 1])

# An earlier phase, a guest's and a side battle undo without a record.
reset
$kind = nil
fight_event(16)
lose(lambda { $game_variables[1020] = 1 }, NO_RECORD)
check("an earlier phase's defeat goes back to the event's start, with no record or notice",
      [$game_variables[1020], freeze.record_for(607), $noted, $notices], [0, nil, [], []])
[[:guest, nil], [:side, MGQ_MpRaidPool::Fight.new(868, true)]].each do |kind, fight|
  reset
  $kind = kind
  $fight = fight
  $game_variables[1075] = 14
  $raid_answers.undo = UNDO.merge([1, 1075] => "was")
  BattleManager.setup(868, false, false)
  $scene = Scene_Battle.new
  lose(SONYA_DEFEAT, NO_RECORD)
  check("a #{kind} battle's defeat goes back to its values at the defeat, with no record", [$game_variables[1075], freeze.record_for(868), $noted], [14, nil, []])
end

# A joiner without a record of their own goes onto the starter's spot after a won battle, only on its map.
reset
$kind = :guest
$entries[868] = { "troop" => 868, "spot" => [138, 30, 10, 4] }
BattleManager.setup(868, false, false)
$scene = Scene_Battle.new
win("won" => true, "spot" => [138, 30, 10, 4], "whose" => "the starter's")
frames(2)
check("a won joined battle hands the DLL the starter's spot", $raid_answers.asked("freeze.records.end").last.values_at("result", "kind", "state", "entry_spot"),
      [0, "guest", nil, [138, 30, 10, 4]])
check("and brings the player onto the spot it names without a fade", [$game_player.x, $game_player.y, $game_player.direction, $game_temp.fade_type], [30, 10, 4, 2])
reset
$kind = :side
$fight = MGQ_MpRaidPool::Fight.new(868, true)
$entries[868] = { "troop" => 868, "spot" => [138, 30, 10, 4] }
$game_map.setup(154)
BattleManager.setup(868, false, false)
$scene = Scene_Battle.new
win("won" => true, "spot" => [138, 30, 10, 4], "whose" => "the starter's")
frames(2)
check("but not from another map", [$game_player.x, $game_player.y, $log.grep(/did not bring the player onto the starter's spot of troop 868: map 154, not 138/).size], [32, 9, 1])

# A player without a record of their own starts the world's entry's event from its first command.
reset
$game_switches[4] = true
$game_variables[1075] = 14
$entries[868] = { "troop" => 868, "outer" => ["map", 138, 13, 1], "scene" => false, "spot" => [138, 32, 9, 8] }
$raid_answers.fresh = { "start" => "here", "site" => ["map", 138, 13, 1] }
$game_map.refresh
check("a world entry's field event starts from its first command as story", [freeze.resume(868), $as_story, $game_map.interpreter.instance_variable_get(:@index)], [true, 1, 0])
check("as the DLL planned it from the page its event shows here and that page's trigger",
      $raid_answers.asked("freeze.fresh").last.values_at("troop", "scene", "outer", "map", "shown", "trigger", "switches"), [868, false, ["map", 138, 13, 1], 138, 0, 3, []])
check("the page of the entry", $game_map.interpreter.instance_variable_get(:@list).equal?(SONYA_PAGE.list), true)
frames(3)
check("its battle takes the player's own record", [freeze.record_for(868) && freeze.record_for(868)["state"], $scene.class], ["battle", Scene_Battle])
reset
$game_variables[1075] = 16
$entries[868] = { "troop" => 868, "outer" => ["map", 138, 13, 1], "scene" => false }
$raid_answers.fresh = { "start" => nil, "refusal" => "the page does not show" }
$game_map.refresh
check("refused as the DLL answers, telling the page the event shows", [freeze.resume(868), $notices.last, $raid_answers.asked("freeze.fresh").last["shown"]],
      [false, "Cannot fight Sonya Mazda here yet.", 1])
$game_variables[1075] = 14
$game_map.setup(154)
check("and on another map, where no page of the event shows",
      [freeze.resume(868), $raid_answers.asked("freeze.fresh").last.values_at("map", "shown"), $log.grep(/refused the fight against troop 868: the page does not show/).size], [false, [154, nil], 2])
reset
$game_switches[5] = true
$entries[870] = { "troop" => 870, "outer" => ["map", 728, 12, 1], "scene" => true }
$raid_answers.fresh = { "start" => "scene", "site" => ["map", 749, 13, 1], "spot" => [749, 1, 0, 0] }
check("a cutscene entry takes the cutscene the DLL picks, its page probed before the transfer", freeze.resume(870), true)
check("which the DLL picked by the switches that are on", [$raid_answers.asked("freeze.fresh").last["scene"], $raid_answers.asked("freeze.fresh").last["switches"].include?(5)], [true, true])
frames(1)
check("and starts it on arrival from its first command", [$game_map.map_id, $game_player.x, $game_player.y, $game_map.interpreter.event_id, $game_map.interpreter.instance_variable_get(:@index)],
      [749, 1, 0, 13, 0])

# Nobody resumes while another player tells the story here.
reset
$game_variables[1075] = 14
$entries[868] = { "troop" => 868, "outer" => ["map", 138, 13, 1], "scene" => false }
$teller = MGQ_MpOverworldSync::Peers::Peer.new(2, { "name" => "Teller" })
check("refused while another player tells the story", [freeze.resume(868), $notices.last, $log.grep(/refused the fight against troop 868: Teller tells the story here/).size],
      [false, "Teller is telling the story here.", 1])

# A cutscene fight's boss waits on the field map the story entered the cutscene from.
reset
$game_switches[4] = true
$game_player.reserve_transfer(728, 0, 1, 8)
frames(1)
check("a transfer from a field map into a cutscene map notes where the player left", $game_system.instance_variable_get(MGQ_MpRaidFreeze::FIELD)["origin"], [138, 32, 9, 8])
$raid_answers.tableau = { "map" => 138, "at" => [32, 9], "blocked" => [13], "callers" => 0 }
fight_event(12)
record = freeze.record_for(870)
check("a cutscene fight hands the DLL its page and where the player left the field",
      $raid_answers.asked("freeze.tableau").last.values_at("scene", "moved", "outer", "origin"), [true, false, ["map", 728, 12, 1], [138, 32, 9, 8]])
check("its boss stands where the DLL places it, on the field map, the events it names blocked",
      [record["scene"], record["tableau"]], [true, [138, [[12, 32, 9, 2, 1, "$sonya_chaos", 0, 0, 255, 0, 1, 1, 0]], [13]]])
check("and the teleport goes back into the cutscene", record["spot"], [728, 0, 1, 8])

# Which events stand in for the scene and its boss.
reset
# Makes an event on map 138 with one page of its own picture and commands.
#
# @param id [Integer] The event.
# @param x [Integer] Its x.
# @param name [String] Its picture.
# @param list [Array<RPG::EventCommand>] Its page's commands.
# @param condition [Object, nil] Its page's test.
# @return [Game_Event] The event.
def figure(id, x, name, list = [c(0, 0)], condition = nil)
  $game_map.events[id] = Game_Event.new(138, RPG::Event.new(id, x, 9, name, [RPG::EventPage.new(list, condition)]))
end
outer = $game_map.events[15]
talker = figure(20, 33, "$villager", [c(101, 0), c(0, 0)])
statue = figure(21, 34, "$statue")
small = figure(22, 35, "guard")
chest = figure(23, 31, "!Chest")
figure(24, 36, "$sonya", [c(0, 0)], RPG::EventPageCondition.new(31))
angel = figure(25, 33, "angel", [c(0, 0)], RPG::EventPageCondition.new(31))
before = freeze.event_states
$game_switches[31] = true
$game_map.refresh
shown = freeze.visible_events
scene = freeze.scene_events(shown, before)
check("the scene's events are those that showed nothing as its event started", scene.map(&:id), [24, 25])
check("unknown events at the start keep none", freeze.scene_events(shown, nil), [])
check("an invisible event's boss is the scene's large sprite nearest the player, before nearer ones and the map's large figures",
      freeze.boss_event(outer, shown, scene).id, 24)
check("else the scene's nearest character", freeze.boss_event(outer, shown, [angel, chest]).id, 25)
check("without a scene, the map's large figure that runs nothing, never one to talk to", freeze.boss_event(outer, [talker, statue, small, chest], []).id, 21)
check("else its nearest figure that runs nothing, never an object", freeze.boss_event(outer, [talker, small, chest], []).id, 22)
check("ties go to the lower id", freeze.boss_event(outer, [figure(26, 35, "guard"), small], []).id, 22)
check("none fits when only people to talk to and objects show", freeze.boss_event(outer, [talker, chest], []), nil)
check("the fight's own event when it shows", freeze.boss_event(talker, [talker, statue], []).id, 20)
$game_map.events.each_value { |e| e.transparent = true }
check("none showing, the boss is an invisible row at the fight's event", freeze.field_rows(outer, before, 138), [[15, 20, 20, 2, 0, "", 0, 0, 255, 0, 1, 1, 1]])

# The events the scene changed in place: a page of a story value, a place.
reset
# Makes an event on map 138 that shows a quiet page of its own picture until v1075 reaches 15, then
# another page.
#
# @param id [Integer] The event, also its x.
# @param name [String] Its first picture.
# @param later [RPG::EventPage] Its page from v1075 15 on.
# @return [Game_Event] The event.
def turning(id, name, later)
  $game_map.events[id] = Game_Event.new(138, RPG::Event.new(id, id, 9, name, [RPG::EventPage.new([c(0, 0)], nil), later]))
end
later = lambda { $game_variables[1075] >= 15 }
beast = turning(30, "beast", RPG::EventPage.new([c(0, 0)], later, "$girl"))
turning(31, "merchant", RPG::EventPage.new([c(302, 0), c(0, 0)], later))
priest = figure(32, 32, "priest")
cat = figure(33, 33, "cat")
cat.mgq_mp_pages[0].move_type = 1
talker = figure(34, 34, "$villager", [c(101, 0), c(0, 0)])
before = freeze.event_states
$game_variables[1075] = 15
$game_map.refresh
[priest, cat, talker].each { |event| event.moveto(event.x, 12) }
scene = freeze.scene_events(freeze.visible_events, before).map(&:id) & [30, 31, 32, 33, 34]
check("a quiet event the scene turned to another page of a story value, and one it moved, are the scene's", scene, [30, 32])
check("one that walks by itself, one to talk to and one whose new page runs something, a shop, stay live", scene & [31, 33, 34], [])
rows = freeze.field_rows(beast, before, 138).select { |row| [30, 32].include?(row[0]) }
check("their stand-ins show them as the battle had them", rows.map { |row| row[0, 3] + [row[5]] }, [[30, 30, 9, "$girl"], [32, 32, 12, "priest"]])

# Another world's story reads the field as empty.
reset
$game_switches[4] = true
$game_variables[1075] = 14
fight_event(13)
lose(SONYA_DEFEAT)
$raid_answers.checked = { "listed" => [], "dropped" => [[868, "the player's story beat it"]] }
check("a record of a boss the story beat is no record to show, though it stays until the next look", [freeze.records, freeze.record_for(868)["state"]], [[], "frozen"])
$frame += MGQ_MpRaidFreeze::CHECK_FRAMES
frames(1)
check("which drops it", [freeze.record_for(868), $log.grep(/dropped the record of troop 868: the player's story beat it/).size], [nil, 1])
$game_map.setup(138)
fight_event(13)
lose(SONYA_DEFEAT)
$world = "w2"
check("another world's story reads no records", [freeze.records, freeze.record_for(868)], [[], nil])
check("and starts the field anew for itself", $game_system.instance_variable_get(MGQ_MpRaidFreeze::FIELD)["world"], "w2")

# A won battle against a troop's pools tells the world's list, which ends its frozen fight at once.
reset
$won = []
$game_switches[4] = true
$game_variables[1075] = 14
fight_event(13)
check("a fight not yet won tells nothing", $won, [])
win
check("a won battle against the pools is told to the world's list", [$won, $log.grep(/won the battle against troop 868: the world's frozen fight against it ends/).size], [[868], 1])

# A frozen fight the save keeps is told to the world once after the title, unless its list holds it.
reset
$raid_answers.checked = SONYA_LISTED
$game_switches[4] = true
$game_variables[1075] = 14
fight_event(13)
lose(SONYA_DEFEAT)
check("the freeze itself tells the world once", $noted.size, 1)
freeze.forget
$noted.clear
$frame += MGQ_MpRaidFreeze::CHECK_FRAMES
frames(1)
check("after the title the save's frozen fight is told again", [$noted.map { |entry| entry["troop"] }, $log.grep(/told the world of the frozen fight against Sonya Mazda \(troop 868\) the save keeps: its list holds it/).size], [[868], 1])
$frame += MGQ_MpRaidFreeze::CHECK_FRAMES
frames(1)
check("but only once", $noted.size, 1)
freeze.forget
$noted.clear
$entries[868] = { "troop" => 868 }
$frame += MGQ_MpRaidFreeze::CHECK_FRAMES
frames(1)
check("nor when the world's list holds it", $noted, [])

# A fight whose common event moves the player to another map before its battle: the page is the
# one of the map the event started on, the boss waits at that event, the event and the other pages
# that call the common event are blocked, and the resume runs the page from that map's data, its
# interpreters on that map as at the battle.
reset
FreezeTables::SITES[2133] = [[["ce", 9062], 2, 0, 1, false]]
reread_tables
$raid_answers.tableau = { "map" => 138, "at" => [40, 10], "blocked" => [30, 31], "callers" => 1 }
$data_common_events[9062] = RPG::CommonEvent.new(9062, [
  c(201, 0, 0, 300, 4, 4, 8), c(132, 0), c(301, 0, 0, 2133, false, false), c(123, 0, "A", 0), c(900, 0, :ce9062_after), c(0, 0),
])
# A touch trigger of map 138 that sets the story on and calls the common event, and its sibling.
TRIGGER_PAGE = RPG::EventPage.new([c(122, 0, 1001, 1001, 0, 0, 40), c(117, 0, 9062), c(900, 0, :after_9062), c(0, 0)], nil)
trigger = RPG::Event.new(30, 40, 10, "", [TRIGGER_PAGE])
sibling = RPG::Event.new(31, 41, 10, "", [RPG::EventPage.new(TRIGGER_PAGE.list, nil)])
$map_files["Map138"] = RPG::MapData.new({ 30 => trigger, 31 => sibling })
# The battle's map: another event 30, the boss's figure, and a villager to talk to.
$maps[300] = [RPG::Event.new(30, 5, 3, "$allknowing", [RPG::EventPage.new([c(0, 0)], nil)]),
              RPG::Event.new(2, 9, 9, "villager", [RPG::EventPage.new([c(101, 0), c(0, 0)], nil)])]
[trigger, sibling].each { |data| $game_map.events[data.id] = Game_Event.new(138, data) }
$game_variables[1001] = 39
fight_event(30)
record = freeze.record_for(2133)
check("a fight whose event moved the player away first takes a record on the battle's map", [record && record["state"], $game_map.map_id], ["battle", 300])
check("its frames name the page of the map the event started on, the common event's with its interpreter's map and event",
      record["frames"], [[["map", 138, 30, 1], 1, {}], [["ce", 9062], 2, {}, [138, 30]]])
check("the story at the event's start is known", [record["start"], record["pre"]], [[[1, 1001, 39]], [[1, 1001, 40]]])
check("it hands the DLL the map the event started on, where it stood and the frames' sites",
      $raid_answers.asked("freeze.tableau").last.values_at("scene", "moved", "map", "event", "place", "frames"),
      [false, true, 138, 30, [40, 10], [["map", 138, 30, 1], ["ce", 9062]]])
check("its boss waits where the DLL places it, looking as the battle map's boss, the events it names blocked",
      record["tableau"], [138, [[30, 40, 10, 2, 1, "$allknowing", 0, 0, 255, 0, 1, 1, 0]], [30, 31]])
check("which is logged", $log.grep(/blocks the starts of events \[30, 31\] on map 138, 1 of them other callers of its common events/).size, 1)
check("it is no cutscene, and its spot is on the battle's map", [record["scene"], record["spot"], record["map"]], [false, [300, 4, 4, 8], 300])
lose(lambda { $game_variables[1001] = 10 })
check("lost, the story goes back to the event's start and the fight waits", [$game_variables[1001], record["state"], $noted.last["outer"]], [39, "frozen", ["map", 138, 30, 1]])
$executed.clear
$ran.clear
check("its resume starts", freeze.resume(2133), true)
frames(1)
interpreter = $game_map.interpreter
check("the resume puts the player on the battle's map and runs the page of map 138 at its call, its interpreter on map 138",
      [$game_map.map_id, $game_player.x, $game_player.y, interpreter.map_id, interpreter.event_id, interpreter.instance_variable_get(:@index),
       interpreter.instance_variable_get(:@list).equal?(TRIGGER_PAGE.list), $game_variables[1001]],
      [300, 4, 4, 138, 30, 1, true, 40])
frames(1)
check("the common event runs from its preamble on to its battle", [$executed.first(3), $scene.class], [[[0, 1], [1, 1], [1, 2]], Scene_Battle])
win
frames(3)
check("won, both lists go on, the common event's self switch on the event of map 138 as at the battle",
      [$ran, $game_self_switches[[138, 30, "A"]], freeze.record_for(2133)], [[:ce9062_after, :after_9062], true, nil])
FreezeTables::SITES.delete(2133)
reread_tables

# A resume given up before its battle puts back what it changed and brings the player back.
reset
$game_switches[4] = true
$game_variables[1075] = 14
$game_party.instance_variable_set(:@temp_actors, [525])
$game_map.screen.pictures[1].show("sonya")
fight_event(13)
lose(SONYA_DEFEAT)
$game_party.instance_variable_set(:@temp_actors, [])
check("before the resume the player is in Hades without the scene", [$game_map.map_id, $game_variables[1075], $game_map.screen.pictures[1].name], [154, 14, ""])
freeze.resume(868)
frames(1)
check("the resume put the scene and the party back", [$game_map.map_id, $game_variables[1075], $game_switches[31], $game_map.screen.pictures[1].name,
                                                       $game_party.instance_variable_get(:@temp_actors)], [138, 16, true, "sonya", [525]])
MGQ_MpGame.set($game_map.interpreter, :index, SONYA_PAGE.list.size)
$played.clear
frames(2)
check("given up before its battle, the story values, the party, the screen and the music are as before the press",
      [freeze.resuming?, $game_variables[1075], $game_switches[31], $game_party.instance_variable_get(:@temp_actors), $game_map.screen.pictures[1].name,
       $played.include?([:bgm, "Hades", 0])], [false, 14, false, [], "", true])
check("the record stays frozen", freeze.record_for(868)["state"], "frozen")
check("the way back is on its way at once on a free map", [$game_player.transfer?, $log.grep(/the player goes back to map 154 at 5,5, where they started the fight, once the map is free/).size], [true, 1])
frames(1)
check("the player goes back to where they pressed", [$game_map.map_id, $game_player.x, $game_player.y], [154, 5, 5])
check("each step is logged", [$log.grep(/put back what the resume of troop 868 changed: 3 story value\(s\), the party, the screen and the music\z/).size,
                              $log.grep(/brought the player back to map 154 at 5,5, where they started the fight against troop 868/).size], [1, 1])

# A fight whose event parked the boat before its battle resumes from the boat (issue #50): the
# player gets off and the boat goes back where the event parked it; given up, the player is back on
# the boat where they pressed. A record taken before vehicles were recorded leaves the boat there.
[true, false].each do |recorded|
  reset
  $game_switches[4] = true
  $game_variables[1075] = 14
  boat = $game_map.vehicle(:boat)
  boat.set_location(138, 40, 9)
  boat.set_direction(6)
  fight_event(13)
  lose(SONYA_DEFEAT)
  freeze.record_for(868).delete("vehicles") unless recorded
  boat.set_location(154, 5, 5)
  boat.instance_variable_set(:@driving, true)
  $game_player.instance_variable_set(:@vehicle_type, :boat)
  check("a frozen fight resumes from a boat#{recorded ? '' : ', also with a record without vehicles'}", freeze.resume(868), true)
  frames(1)
  parked = recorded ? [138, 40, 9, 6] : [154, 5, 5, 6]
  check("the player is off the boat on the battle's spot, the boat #{recorded ? 'where the event parked it' : 'where they pressed'}",
        [$game_player.instance_variable_get(:@vehicle_type), $game_map.map_id, boat.driving, boat.instance_variable_get(:@map_id), boat.x, boat.y, boat.direction],
        [:walk, 138, false] + parked)
  MGQ_MpGame.set($game_map.interpreter, :index, SONYA_PAGE.list.size)
  frames(3)
  check("given up before its battle, the player is back on the boat where they pressed",
        [$game_map.map_id, $game_player.x, $game_player.y, $game_player.instance_variable_get(:@vehicle_type), boat.driving, boat.instance_variable_get(:@map_id), boat.x, boat.y],
        [154, 5, 5, :boat, true, 154, 5, 5])
end

# A joiner with a frozen record of their own of the same boss goes onto the starter's spot after a
# won joined battle, else onto their record's, and the record goes.
[[{ "troop" => 868, "spot" => [138, 30, 10, 4] }, [30, 10, 4], "the starter's"], [nil, [32, 9, 8], "the player's own record's"]].each do |entry, place, whose|
  reset
  $game_switches[4] = true
  $game_variables[1075] = 14
  fight_event(13)
  lose(SONYA_DEFEAT)
  $game_map.setup(138)
  $game_player.moveto(20, 20)
  $kind = :guest
  $entries[868] = entry if entry
  BattleManager.setup(868, false, false)
  $scene = Scene_Battle.new
  win(WON.merge("spot" => [138] + place, "whose" => whose))
  frames(2)
  check("a won joined battle of a player with an own record hands the DLL both spots",
        $raid_answers.asked("freeze.records.end").last.values_at("state", "entry_spot", "record_spot"), ["frozen", entry && entry["spot"], [138, 32, 9, 8]])
  check("and brings them onto #{whose} spot as it names", [$game_player.x, $game_player.y, $game_player.direction], place)
  check("and their own record goes", [freeze.record_for(868), $log.grep(/the boss of troop 868 fell in the won guest battle: the player's own frozen record of it goes/).size], [nil, 1])
end

# A player without a record of their own goes onto the spot that starts the entry's page first: in
# front of an action button's event facing it, onto a touch's own tile; the tableau's hidden events
# pass through meanwhile.
SONYA_TABLEAU = [138, [[13, 32, 8, 2, 1, "$sonya", 0, 0, 255, 0, 1, 1, 1], [14, 28, 9, 2, 1, "villager", 0, 0, 255, 0, 1, 0, 1],
                       [16, 10, 10, 2, 1, "alma", 0, 0, 255, 0, 1, 0, 0]], [13]]

# Readies the world's entry of Sonya Mazda's fight, her page started by a trigger, the player away
# at 20,20 facing down.
#
# @param trigger [Integer] The page's trigger.
def fresh_sonya(trigger)
  reset
  SONYA_PAGE.trigger = trigger
  $game_switches[4] = true
  $game_variables[1075] = 14
  $entries[868] = { "troop" => 868, "outer" => ["map", 138, 13, 1], "scene" => false, "spot" => [138, 32, 9, 8], "tableau" => SONYA_TABLEAU }
  $raid_answers.fresh = { "start" => { 0 => "action", 1 => "touch", 2 => "touch" }.fetch(trigger, "here"), "site" => ["map", 138, 13, 1] }
  $game_map.refresh
  $game_player.moveto(20, 20)
  $game_player.set_direction(2)
end

# Answers where the player's reserved transfer goes: x, y and direction.
#
# @return [Array<Integer>] The spot.
def reserved_spot
  [:@new_x, :@new_y, :@new_direction].map { |name| $game_player.instance_variable_get(name) }
end

# Answers whether events of the map pass through.
#
# @param ids [Array<Integer>] The events.
# @return [Array<Boolean>] Whether each does.
def through_of(*ids)
  ids.map { |id| $game_map.events[id].through }
end

fresh_sonya(0)
check("an action button's page goes onto the tile in front of its event first, facing it, with a fade",
      [freeze.resume(868), $game_player.transfer?, reserved_spot, $game_temp.fade_type, $game_map.interpreter.running?], [true, true, [32, 9, 8], 0, false])
check("which is logged", $log.grep(/the action button starts event 13 from the tile in front of it: 32,9\z/).size, 1)
check("the tableau's hidden events pass through meanwhile, one standing elsewhere stays as it was", through_of(13, 14, 16), [true, true, false])
check("and the stand-ins step aside as for any resume", freeze.resuming?(868), true)
frames(1)
check("on arrival its event starts from its first command as story",
      [$game_player.x, $game_player.y, $game_player.direction, $game_map.interpreter.event_id, $game_map.interpreter.instance_variable_get(:@index), $as_story],
      [32, 9, 8, 13, 0, 1])
frames(2)
row = ->(id) { freeze.record_for(868)["events"].find { |each| each[0] == id } }
check("its battle's record keeps the events' own through, never the hold",
      [$scene.class, row.call(13)[11], row.call(14)[11], $game_map.events[14].through], [Scene_Battle, false, false, true])
win
frames(1)
check("after the battle a page the run turned to passes through again while the run lasts", [$game_map.events[13].mgq_mp_page, through_of(13, 14)], [1, [true, true]])
frames(2)
check("the run ended, the events pass through as their pages say again", [freeze.resuming?, through_of(13, 14, 16), $ran], [false, [false, false, false], [:won]])
check("which is logged", $log.grep(/events \[13, 14\] pass through as their pages say again: the fresh start of troop 868 ended/).size, 1)

fresh_sonya(1)
$game_map.events[13].set_direction(4)
check("a touch's page goes onto its event's own tile and direction first", [freeze.resume(868), reserved_spot, $game_temp.fade_type], [true, [32, 8, 4], 0])
frames(1)
check("and starts there from its first command", [$game_player.x, $game_player.y, $game_player.direction, $game_map.interpreter.instance_variable_get(:@index)], [32, 8, 4, 0])
MGQ_MpGame.set($game_map.interpreter, :index, SONYA_PAGE.list.size)
frames(4)
check("given up before its battle, the hidden events pass through as before and the player goes back to where they pressed",
      [freeze.resuming?, through_of(13, 14), $game_player.x, $game_player.y, $log.grep(/events \[13, 14\] pass through as their pages say again/).size],
      [false, [false, false], 20, 20, 1])

fresh_sonya(0)
$game_map.events[50] = Game_Event.new(138, RPG::Event.new(50, 32, 9, "guard", [RPG::EventPage.new([c(0, 0)], nil)]))
$walls << [31, 8]
$game_map.events[14].moveto(33, 8)
check("a front tile a live event blocks gives way to the free neighbour nearest the player, past a wall, a hidden event there no hindrance",
      [freeze.resume(868), reserved_spot], [true, [33, 8, 4]])
check("which is logged", $log.grep(/starts event 13 from its free neighbour, the tile in front of it \(facing 2\) not being free: 33,8\z/).size, 1)

fresh_sonya(0)
$walls.concat([[32, 9], [31, 8], [33, 8], [32, 7]])
check("with no free tile around its event, the page starts where the player stands",
      [freeze.resume(868), $game_player.transfer?, $game_map.interpreter.running?, $game_map.interpreter.instance_variable_get(:@index), through_of(13, 14)],
      [true, false, true, 0, [true, true]])
check("which is logged", $log.grep(/no tile around event 13 at 32,8 is free: it starts where the player stands/).size, 1)

fresh_sonya(3)
check("an autorun page starts where the player stands as before, no event let through",
      [freeze.resume(868), $game_player.transfer?, $game_map.interpreter.running?, through_of(13, 14)], [true, false, true, [false, false]])

fresh_sonya(4)
check("a parallel page starts where the player stands as before, no event let through",
      [freeze.resume(868), $game_player.transfer?, $game_map.interpreter.running?, through_of(13, 14)], [true, false, true, [false, false]])

fresh_sonya(2)
$game_map.events[13].set_direction(6)
check("an event touch's page goes onto its event's own tile and direction first, the hidden events let through",
      [freeze.resume(868), reserved_spot, $game_temp.fade_type, through_of(13, 14)], [true, [32, 8, 6], 0, [true, true]])
frames(1)
check("and starts there from its first command", [$game_player.x, $game_player.y, $game_map.interpreter.instance_variable_get(:@index)], [32, 8, 0])
MGQ_MpGame.set($game_map.interpreter, :index, SONYA_PAGE.list.size)
frames(4)
check("given up there, the hidden events pass through as their pages say again", [freeze.resuming?, through_of(13, 14)], [false, [false, false]])

fresh_sonya(0)
$game_map.singleton_class.send(:define_method, :valid?) { |_x, _y| raise ArgumentError, "a broken map" }
check("a failing look for the start's tile starts the page where the player stands, the hold kept for the run",
      [freeze.resume(868), $game_player.transfer?, $game_map.interpreter.running?, through_of(13, 14)], [true, false, true, [true, true]])
check("which is logged", $log.grep(/finding the tile that starts event 13 failed: ArgumentError: a broken map: it starts where the player stands/).size, 1)
$game_map.singleton_class.send(:remove_method, :valid?)

# A fight whose event moved the player away first starts at its touch on the map it started on.
reset
TRIGGER_PAGE.trigger = 1
$game_map.events[30] = Game_Event.new(138, trigger)
$entries[2133] = { "troop" => 2133, "outer" => ["map", 138, 30, 1], "scene" => false, "spot" => [300, 4, 4, 8],
                   "tableau" => [138, [[30, 40, 10, 2, 1, "$allknowing", 0, 0, 255, 0, 1, 1, 0]], [30, 31]] }
$raid_answers.fresh = { "start" => "touch", "site" => ["map", 138, 30, 1] }
check("a moved fight's touch goes onto its event's tile, nothing let through", [freeze.resume(2133), reserved_spot, through_of(30)], [true, [40, 10, 2], [false]])
frames(1)
check("and starts its page there", [$game_map.map_id, $game_player.x, $game_player.y, $game_map.interpreter.event_id,
                                     $game_map.interpreter.instance_variable_get(:@list).equal?(TRIGGER_PAGE.list)], [138, 40, 10, 30, true])
TRIGGER_PAGE.trigger = nil
SONYA_PAGE.trigger = 3

# A save of an earlier release keeps its frozen fights' sites as texts, which the DLL reads once
# (StoryTopicsTests.Sites_ReadTheTextsOfAnEarlierReleasesSave).
sites_asked = []
$world_bridge.answer("story.sites") { |texts| sites_asked << texts; [["ce", 347], ["map", 138, 13, 1]] }
older = { "troop" => 868, "state" => "frozen", "site" => "ce:347", "outer" => "map:138:13:1", "frames" => [["map:138:13:1", 7, {}], ["ce:347", 11, {}, [138, 13]]] }
MGQ_MpGame.set($game_system, :raid_freeze, { "world" => $world, "origin" => nil, "records" => { 868 => older } })
read = freeze.record_for(868)
check("a save of an earlier release has the DLL read its frozen fights' sites once",
      [sites_asked, read["site"], read["outer"], read["frames"].map(&:first)],
      [[["ce:347", "map:138:13:1"]], ["ce", 347], ["map", 138, 13, 1], [["map", 138, 13, 1], ["ce", 347]]])
