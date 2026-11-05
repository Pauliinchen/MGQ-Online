#----------------------------------------------------------------
#  coop_events_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Checked that an event ended early or kept from starting goes to the one guard of the game's flow, in place of the fade-ins on frame timers
#                            - Answered the Classic catch-up, the side and the key item loan by the DLL's rules as engine.rb stands in for them, recorded by make_classic.rb
#                            - Answered how a Classic member plays the leader's story, which of its changes they take and which of their runs it keeps by the DLL's rules as engine.rb and the checks stand in for them
#                            - Checked that a member behind loses the World Seed the leader's story used up, with no notice
#                            - Checked that a member from another player's starting save catches up with neither side before they answer, then with the side they answer
#                            - Checked that a reward behind a choice the member has not answered waits, and comes once they answer it
#                            - Checked that a member on a route whose save notes no side gets no row of a side
#                            - Checked that a player whom the side's rule could not judge before its rules came is asked once they came
#                            - Left the checks of the rule of who plays one story to the DLL's tests
#                            - Checked that a world chest the leader's story opened plays in the member's game unless their own story is past its step
#                            - Caught a member behind the leader up by the frozen rows the DLL answers, and checked that the leader tells only their side
#                            - Checked that a party member gets the Noble Orb the leader bought from the Medal King, once
#      Paulinchen  2026-11-01: Dropped the stand-in of a lapse after a frame count, which no script asks for any more
#                            - Kept the screen of choices open as asked, since the framework without its DLL refuses its window
#                            - Read the screen of choices from MGQ_MpCoopChoices.screen, now a Mod Framework window
#                            - Checked that a member gets no companion of the Alice and Ilias choice the DLL finds they have no right to
#                            - Checked that a member on a route whose save notes no side taken along is asked about with none, not with the route's side switch
#                            - Checked that a member from another player's starting save is asked whom they take along and loses the other side's companion
#                            - Checked that a member from another player's starting save on the Chaos route gets the conference's companions by the side switches and is asked whom they take along
#                            - Checked that a player alone from another player's starting save is asked whom they take along
#                            - Checked that the Sphinx joins once challenged and that the peace of Plansect brings both queens
#                            - Checked that the Spider Princess's side sends Miria away on a first playthrough
#      Paulinchen  2026-10-31: Dropped the warp ban a call, a teleport and a telling carried
#                            - Checked that the leader's story sends no gift, recruit, skill or departure message, and that a member behind catches up once with the history before the log, by the frozen rows and derived entries
#                            - Checked that the leader's runs of the story reach every member who follows it, in the stream of the leader's story
#                            - Checked that catching up asks the member the choices up to where they followed, and leaves later ones to the replay
#                            - Checked that a member's writes of the leader's story reach the leader as requests, which come back by value as the leader keeps them
#                            - Checked that a member's run of the leader's story goes with their requests, and that the leader keeps it for the party and their own game when it changed the leader's story
#                            - Stood in for the scopes a Classic party keeps its keys by, which the DLL reads from the reviewed list
#                            - Expected the side switches each player's own throughout, as the reviewed list keeps them
#                            - Checked that a chest a member opens goes to the party as its run, which each member's game plays again
#                            - Checked that a guest keeps the party keys of a chest they opened in their own story
#                            - Checked that a chest that also turns on a world switch reaches the party
#                            - Checked that a chest's run is kept in the party's stream at once
#                            - Left the retired generator of the story's rewards to the Event Checker
#      Paulinchen  2026-10-28: Checked the chests the DLL's events database names and read the rewards' checks from the relay's reviewed rows
#                            - Checked the length and shape a list is named with, the running map and event, the fingerprint and the second call for a map's pages
#                            - Checked that a held page asks the DLL whether it is over only once something changed
#                            - Checked that a player behind starts every story event and talk but one that ends their part
#                            - Read the frames of a call from the gather stand-in
#                            - Read the pages waiting from the stand-in of the DLL
#                            - Checked that a story event waits for the relay's telling lock and ends once refused, in place of the tie
#                            - Answered the telling machine through the bridge from its golden cases
#                            - Took a Raid World's tellers from the relay's tellings and its viewers from their tracks
#                            - Checked that the leader answers an ask for the whole story once the rewards a member catches up with came
#                            - Checked that the scripts ask the DLL for missing rewards once within half a second
#                            - Had the scripts read the rewards anew once the stand-in of their table is in place
#      Paulinchen  2026-10-24: Set the unlocks aside in the generator's switches of each player's own
#                            - Checked that the player's game notes whose scene that runs by itself it keeps from starting
#      Paulinchen  2026-10-23: Left the sorting checks to MGQOnline.Game.Tests and answered the sorts from its golden cases
#                            - Sorted a Raid World's events by a story mapping that keeps what the Raid personal lists kept
#                            - Checked that the leader tells the party the story's writes their game made
#                            - Compared the generator's lists within the game's switches and variables
#                            - Checked that a weapon's pedestal handing out a medal is a chest of each player's own
#                            - Checked that a talk ended early takes back what it changed
#                            - Checked that a dark screen fades in while a watched scene shows nothing for ten seconds
#      Paulinchen  2026-10-17: Checked that a resumed raid boss fight's event starts as story
#      Paulinchen  2026-10-15: Checked that a screen left dark with nothing running fades in
#                            - Checked that the Pocket Castle's tour is travel in a Raid World and story in a Classic world
#      Paulinchen  2026-10-14: Expected the Navy or the Pirates among the choices
#      Paulinchen  2026-10-12: Checked that a story event left to the teller fades in a dark screen once per arrival
#                            - Checked that a member stands free while the leader fights the story's battle
#                            - Checked that a leader's page that fails to hold waits for the member
#                            - Checked how a leader holding the game's skip tells pages
#                            - Checked that a party of four hears each page in one message
#      Paulinchen  2026-10-11: Checked chests turning on a chest flag and stood in for the chest flags
#                            - Stood in for the player's followers
#                            - Checked that a page with story behind a choice is no chest
#                            - Checked that Amira in Iliasburg is no choice
#                            - Checked the generator's rules only where the event checker repository exists
#                            - Checked the pages of called common events and pages the leader moved past
#                            - Checked that holding the game's skip passes a page the leader moved past
#                            - Checked that no page starts while the story brings the player over
#                            - Checked that travel with story behind a choice is told from the choice on
#                            - Checked that story events wait for the world's story after the world opened
#                            - Read the generator from MGQ-Paradox-Event-Checker next to the repository
#                            - Read the line above the player's head as a doing with its seconds left
#                            - Checked choice-variable branches, signposts, cosmetic scripts and battle flags
#      Paulinchen  2026-10-10: Checked which story events go on with the telling that moved the player
#                            - Checked that a Raid World's telling goes on at the story's next event on a new map
#                            - Checked a follower on the way to where the teller's story moved them
#                            - Kept the log's lines
#                            - Checked that the game's map display, castle call and post-battle processing are never story
#                            - Checked that a teleport of coop_teleport.rbx brings the member over at once
#                            - Checked that an event calling the game's own common events is sorted by the rest
#                            - Moved the common events that call each other to 6 and 7
#                            - Checked that the world closing forgets the choices and route waiting
#                            - Checked that a Raid World's story event holds a whole second for a tie
#                            - Checked that no event of coop_story_rewards.rbx is marked by a Library Flag
#      Paulinchen  2026-10-09: Loaded story_state.rbx and read the story's state model from MGQ_MpStoryState
#                            - Checked that a Raid World's pages go to the viewers in one message
#                            - Checked that the story's next event goes on with its telling
#                            - Checked that a story event waits at its start for a tie
#                            - Checked that a player behind a Raid World's story starts no story event
#      Paulinchen  2026-10-08: Checked who tells a Raid World's story and whom its pages reach
#                            - Checked a Raid World's tie between two tellers and its personal chests
#                            - Loaded coop_scope.rbx
#                            - Checked that the game's transfer process and the Library's replays gather nobody
#                            - Stood in for the faces this game has, of overworld.rbx
#      Paulinchen  2026-10-07: Checked that a common event set up with its list alone is sorted
#                            - Took variable 151 as the story's sample
#                            - Stood in for the shared helpers of coop.rbx and gave the switches their full count
#                            - Checked the story's choices a member makes
#                            - Checked when a member follows the leader's story
#                            - Checked the generator's maps from 1000 on, set_actors and the table
#                            - Let every member follow the leader's story in the checks of other things
#                            - Gave the world stand-in who
#                            - Checked that the end of the map's main event ends the telling of the leader's story
#      Paulinchen  2026-10-06: Checked the Great Decision's companions, story shops, personas and a too large story
#                            - Took the leader from a coop.rbx stand-in and the raw data from its field
#                            - Took the castle's ghosts' opacity and catch-up tiles from a stand-in of overworld.rbx
#                            - Checked chests on every map, the packed story and the generator's own lists
#                            - Checked the catch-up's edge cases, from either-side rewards to castle equipment
#                            - Checked that a member behind the leader catches up with the story's rewards
#                            - Checked that a member ahead of the leader is lent the key items instead
#                            - Checked that a locked chest stays shut and tells the party nothing
#      Paulinchen  2026-10-04: Checked lent key items and gifts through a load, a crash, a duel and a battle
#                            - Checked that a chest's sound and first icon reach the members
#                            - Checked that the castle shows the leader's residents, those only the leader has as ghosts
#                            - Checked that the Pocket Castle's way out returns each player where they came from
#                            - Checked that a member not as far along is lent the story's key items
#                            - Checked that a call is kept out of a duel and waits for a dark screen
#                            - Checked that the members near the leader follow where the story moves the leader
#                            - Checked that a member's story event starts nowhere and says so once
#                            - Checked traders, a chest that asks first and the talk's watch
#                            - Checked when the player only waits for the party's story
#                            - Followed gathering into coop_gather.rbx and residents into coop_castle.rbx
#                            - Followed the scripts to their new names, without mp_
#      Paulinchen  2026-10-03: Checked that the Pocket Castle item is travel
#                            - Checked that a member teleports to the leader on their own
#                            - Checked that a member brought to the leader takes over the warp ban of the leader's place
#                            - Gave the world stand-in map_free?
#                            - Gave the world stand-in tell, notice and the own id and seat
#                            - Checked a chest showing its opened page and a story event left to the leader
#      Paulinchen  2026-10-02: Checked that members as far along as the leader keep the story
#                            - Checked deep common event chains and where the awakening switches end
#                            - Gave the stand-ins the party check and the event page of coop.rbx
#                            - Checked that no random encounter starts for a member about to come over
#      Paulinchen  2026-10-01: Checked that a page counts only the branches that can run now
#                            - Checked that exits noting a flag are travel and members come over after five seconds
#                            - Checked that only the leader moves the dialogue on and the castle's residents are talks
#                            - Checked that a story scene waits for the whole party at most thirty seconds
#                            - Checked that members no longer follow the leader to other maps
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# Covers coop_events.rbx with story_state.rbx and coop_story.rbx: how event pages are sorted,
# chests, gathering for story scenes, and story events played in the leader's game.

require_relative "support"
require_relative "rules_support"
require_relative "telling_support"

# The mod's log, which keeps each line in $log for the checks to read.
module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; $log << m; end; end; end
$log = []
$sent = []
$notices = []
# Stands in for the world's sync of overworld_sync.rbx, always in a world.
module MGQ_MpOverworldSync
  def self.in_world?; true; end
  # Shows a notice, its icon kept in $icons.
  def self.notice(text, icon = nil); Status.notice(text); ($icons ||= []) << icon; end
  # Reports whether the player is free on the map, no event, message or transfer running.
  def self.map_free?; SceneManager.scene.is_a?(Scene_Map) && !$game_map.interpreter.running? && !$game_message.busy? && !$game_player.transfer?; end
  def self.tell(seat, fields, body = ""); Link.send_to(seat, Me.encode(fields) + body); end
  def self.who(peer); peer == :me ? "the player" : "#{peer && peer.state['name']}"; end
  # The other players this game knows, each a Peer: their seat, state, ghost and whether they were
  # in the player's party.
  module Peers; Peer = Struct.new(:seat, :state, :ghost, :member); end
  # The player's own state, encoded as the game sends it.
  module Me; def self.encode(state); state.map { |k, v| "#{k}=#{v}" }.join("\n") + "\n\n"; end; end
  # The link to the other games.
  module Link
    # Notes each message sent in $sent, its seat and fields.
    def self.send_to(seat, text)
      fields = {}
      text.split("\n").each { |line| k, v = line.split("=", 2); fields[k] = v if v }
      $sent << [seat, fields]
      true
    end
  end
  # The notices shown, kept in $notices.
  module Status; def self.notice(text); $notices << text; end; end
end
# Stands in for the party helpers of coop.rbx, the party taken from $party, $leader and $members.
module MGQ_MpCoop
  # The player's party.
  module Party
    def self.id; $party; end
    def self.leader; $leader; end
    def self.members; $members; end
    def self.member?(state); state["party"] == $party; end
  end
  def self.in_party?; !$party.nil? && !Array($members).empty?; end
  def self.party_leader; in_party? ? Party.leader : nil; end
  def self.party_leading?; party_leader == :me && !Party.members.empty?; end
  def self.bytes_of(fields); fields.inject(0) { |sum, (key, value)| sum + key.to_s.bytesize + value.to_s.bytesize }; end
  def self.event_name(id); ""; end
  def self.random_id(length); rand(36**length).to_s(36); end
end
# Stands in for the game's data classes.
module RPG
  # An item, weapon or armor, its icon taken from its id.
  class BaseItem; attr_accessor :id, :name; def initialize(id, name); @id, @name = id, name; end; def icon_index; 100 + @id; end; end
  # A sound effect, which notes in $played that it played.
  class SE < Struct.new(:name, :volume, :pitch); def play; ($played ||= []) << to_a; end; end
  # An item, a key item once set so.
  class Item < BaseItem; attr_writer :key; def key_item?; @key ? true : false; end; end
  # A piece of equipment.
  class EquipItem < BaseItem; end
  # A weapon.
  class Weapon < EquipItem; end
  # An armor.
  class Armor < EquipItem; end
  # An event command.
  EventCommand = Struct.new(:code, :indent, :parameters)
  # A common event, its list alone.
  CommonEvent = Struct.new(:list)
  # An event page, its list alone.
  Page = Struct.new(:list)
end
# The event command, by a shorter name.
Command = RPG::EventCommand
# Makes an event command.
#
# @param code [Integer] The command's code.
# @param params [Array] Its parameters.
# @return [RPG::EventCommand] The command.
def c(code, *params); Command.new(code, 0, params); end
# The game's system data, the names of its switches and variables.
System = Struct.new(:switches, :variables)
$data_system = System.new(Array.new(8000, ""), Array.new(4000, ""))
$data_system.switches[20] = "Event General-Purpose 1"
$data_system.variables[7] = "General 0"
$data_common_events = [nil, RPG::CommonEvent.new([c(121, 50, 50, 0)]), nil, nil, nil, nil, RPG::CommonEvent.new([c(101, "", 0, 0, 2), c(117, 7)]), RPG::CommonEvent.new([c(117, 6)])]
$data_actors = Array.new(10)
$data_items = [nil, RPG::Item.new(1, "Potion"), RPG::Item.new(2, "Elixir"), RPG::Item.new(3, "Basement Key")]
$data_items[3].key = true
$data_weapons = [nil, RPG::Weapon.new(1, "Sword")]
$data_armors = [nil]
# Stands in for the game's terms.
module Vocab; def self.currency_unit; "G"; end; end
# The graphics this game has, of which it lacks only one face.
module MGQ_MpOverworld; def self.graphic?(_folder, name); name != "MissingFace"; end; end

# Stands in for the game's switches.
class Game_Switches; def initialize; @data = []; end; def [](id); @data[id] || false; end; def []=(id, value); @data[id] = value; end; end
# Stands in for the game's variables.
class Game_Variables; def initialize; @data = []; end; def [](id); @data[id] || 0; end; def []=(id, value); @data[id] = value; end; end
# Stands in for the game's self switches.
class Game_SelfSwitches; def initialize; @data = {}; end; def [](key); @data[key] == true; end; def []=(key, value); @data[key] = value; end; end

# Reads the data the game keeps for its switches, variables or self switches, past its handling.
#
# @param object [Game_Switches, Game_Variables, Game_SelfSwitches] The object.
# @return [Array, Hash] The data itself.
def raw(object); object.instance_variable_get(:@data); end
# Stands in for the player's party: items by name, gold, the party and the roster.
class Game_Party
  attr_reader :items, :gold, :actors, :include_actors
  attr_accessor :in_battle
  def initialize; @items = Hash.new(0); @gold = 0; @actors = []; @include_actors = []; end
  def gain_item(item, amount, include_equip = false, keep_flag = false); @items[item.name] += amount; end
  def gain_gold(amount); @gold += amount; end
  # The game's roster and party hold a companion once, however often they are added.
  def add_actor(actor_id); add_stand_actor(actor_id); @actors |= [actor_id]; end
  def add_stand_actor(actor_id); @include_actors |= [actor_id]; end
  def remove_actor(actor_id); @include_actors.delete(actor_id); @actors.delete(actor_id); end
  def exist_all_actor_id?(actor_id); @include_actors.include?(actor_id); end
  def exist_party_actor_id?(actor_id); @actors.include?(actor_id); end
  def item_number(item); @items[item.name]; end
  # The items held, as the game lists them.
  def items_held; $data_items.compact.select { |item| @items[item.name] > 0 }; end
  # Counts a party of two as full.
  def party_member_full?; @actors.size >= 2; end
end
# Stands in for the screen: the frame count from $frame_count, the brightness from $brightness.
module Graphics; def self.frame_count; $frame_count; end; def self.brightness; $brightness || 255; end; end
# The buttons: confirm pressed while $confirm is set, the skip held while $skipping is.
module Input; def self.trigger?(button); button == :C && $confirm ? true : false; end; def self.press?(button); button == :X && $skipping ? true : false; end; end
$frame_count = 0
# Stands in for the game's interpreter, running while busy is set.
class Game_Interpreter
  attr_accessor :busy
  def execute_command; end
  def setup(list, event_id = 0); @list = list; @event_id = event_id; @index = 0; @map_id = $game_map ? $game_map.map_id : 0; end
  # Runs the commands that give items, set switches and self switches and exit the event, the rest
  # skipped, each as a command the story's runs see.
  def run
    @list.each_with_index do |command, index|
      break if command.code == 115

      @index = index
      MGQ_MpStoryKeys.executing(self) if defined?(MGQ_MpStoryKeys)
      $game_party.gain_item($data_items[command.parameters[0]], command.parameters[3]) if command.code == 126
      $game_switches[command.parameters[0]] = command.parameters[2] == 0 if command.code == 121
      $game_self_switches[[$game_map.map_id, @event_id, command.parameters[0]]] = command.parameters[1] == 0 if command.code == 123
      MGQ_MpStoryKeys.executed(self) if defined?(MGQ_MpStoryKeys)
    end
  end
  def running?; @busy; end
end
# Stands in for the player on the map, with the transfer they reserved.
class Game_Player
  attr_reader :x, :y, :direction, :reserved
  # Steps left before a random encounter.
  attr_accessor :encounter_count

  # Draws the steps to the next random encounter.
  def make_encounter_count; @encounter_count = 30; end

  # Starts a random encounter once its steps ran out.
  #
  # @return [Boolean] Whether a battle starts.
  def encounter; return false if @encounter_count > 0; make_encounter_count; true; end
  def movable?; true; end
  def initialize; @x = 1; @y = 1; @direction = 2; end
  def followers; @followers ||= Struct.new(:visible).new(true); end
  def refresh; end
  def moveto(x, y); @x, @y = x, y; end
  def set_direction(d); @direction = d; end
  def reserve_transfer(map_id, x, y, d = 2); @reserved = [map_id, x, y, d]; end
  def transfer?; !@reserved.nil?; end
  def perform_transfer
    return unless @reserved
    $game_map.map_id, @x, @y, @direction = @reserved
    @reserved = nil
  end
end
# The message window's wait for the player's input at a page's end, noted in $own_pause.
class Window_Message
  attr_accessor :pause
  def process_input; input_pause; end
  def input_pause; $own_pause = true; end
end
# Stands in for the message the game shows.
class Game_Message
  attr_accessor :busy, :face_name, :face_index, :background, :position
  attr_reader :texts, :choices
  def initialize; clear; end
  def clear; @texts = []; @choices = []; end
  def add(text); @texts << text; end
  def busy?; @busy; end
end
# The map scene, which notes in menu_calling that the menu was asked for.
class Scene_Map; def update_call_menu; @menu_calling = :asked; end; attr_reader :menu_calling; end
# The battle scene.
class Scene_Battle; end
# The menu scene.
class Scene_Menu; end
# Stands in for the game's scene manager, its scene alone.
module SceneManager; class << self; attr_accessor :scene; end; def self.scene_is?(klass); scene.is_a?(klass); end; end
class Game_Interpreter
  def wait_for_message; end
end
# A character as the game moves it, enough for a ghost to walk.
class Game_Character
  attr_reader :x, :y, :direction, :opacity, :character_name, :tile_id
  def initialize; @x = 0; @y = 0; @direction = 2; @opacity = 255; @character_name = ""; @tile_id = 0; end
  def moveto(x, y); @x, @y = x, y; end
  def update; end
  def moving?; false; end
  def set_direction(d); @direction = d; end
  def move_straight(d); @x += { 4 => -1, 6 => 1 }.fetch(d, 0); @y += { 8 => -1, 2 => 1 }.fetch(d, 0); end
end
# Stands in for an event on the map, which shows one of its pages.
class Game_Event
  attr_reader :id, :starting, :trigger, :locked
  attr_writer :character_name
  def character_name; @character_name.to_s; end
  def tile_id; 0; end
  def initialize(id, pages, trigger = 0); @id = id; @event = Struct.new(:pages).new(pages); @page = pages[0]; @trigger = trigger; end
  def list; @page && @page.list; end
  def start; @starting = true; @locked = true; end
  def clear_starting_flag; @starting = false; end
  def unlock; @locked = false; end
  def mgq_mp_page; @page ? @event.pages.index(@page).to_i : -1; end
  def mgq_mp_pages; @event.pages; end
  # Shows the page at the index, as the game does once that page's conditions hold.
  def show(index); @page = @event.pages[index]; end
end
# Stands in for the map, which notes in started the event it set up.
class Game_Map
  attr_accessor :map_id, :events, :need_refresh, :interpreter, :started
  def initialize; @map_id = 3; @events = {}; @interpreter = Game_Interpreter.new; end
  def setup(map_id); @map_id = map_id; end
  def update(main = false); end
  # Sets up the first event starting, as the game does.
  def setup_starting_map_event
    event = @events.values.find { |e| e.starting }
    event.clear_starting_flag if event
    @started = event
    event
  end
  # Sets up the first common event running by itself whose switch is on, as the game does.
  def setup_autorun_common_event
    common = $data_common_events.find { |c| c && c.autorun? && $game_switches[c.switch_id] }
    @started = common
    common
  end
end
# Stands in for the game's saves.
module DataManager
  def self.make_save_contents; {}; end
  def self.extract_save_contents(contents); end
  def self.create_game_objects; end
end

# The party's messages of coop.rbx, sent through the world's link.
module MGQ_MpCoop
  def self.tell(seat, field, value, fields = {})
    MGQ_MpOverworldSync::Link.send_to(seat, MGQ_MpOverworldSync::Me.encode({ field => value, "party" => Party.id }.merge(fields)))
  end
  def self.route(*); end
end
# The world sync's hooks, left empty, and the player's own id.
module MGQ_MpOverworldSync
  def self.route(*); end
  def self.on_tick(*); end
  def self.state_fields(*); end
  def self.busy_scene(*); end
  def self.on_observe(*); end
  def self.on_leave(*); end
  def self.label_line(*); end
  module Me; def self.id; "me"; end; end
end
# A character, who learns skills.
class Game_Actor
  def learn_skill(id); (@skills ||= []) << id; end
end
# The line above the player's head, its lapse given as the seconds left for the checks to read.
module MGQ_MpActions
  def self.lapse_in(frames); frames / 60.0; end
end
load_script "coop_scope"
load_script "story_state"
# Reads the reviewed rows of a story table the relay seeds from (Relay/seed/story, a list of admin
# edits).
#
# @param table [String] The table.
# @return [Array<Hash>] The rows.
def reviewed_rows(table)
  JSON.parse(File.read(File.join(STORY_SEEDS, "#{table}.json"), :encoding => "UTF-8")).map { |edit| edit["row"] }
end
# The chest flags as the relay keeps them for the game; its other rewards tables stay out, since
# these checks build their own stories.
CHEST_FLAGS = reviewed_rows("chest_flags").map { |row| row["switch"] }
# Lists the chest flags from CHEST_FLAGS, see MGQ_MpStoryState.chest_flags.
def MGQ_MpStoryState.chest_flags; CHEST_FLAGS; end
load_script "coop_story"
load_script "story_replay"
load_script "coop_events"
load_script "coop_gather"
load_script "coop_castle"
answer_telling(open_rules_bridge)
# Stands in for the one guard of the game's flow (coop_flow.rbx), noting in $flow what the events
# hand it.
module MGQ_MpFlowGuard
  def self.cut(list, index, reason); ($flow ||= []) << [:cut, list.size, index, reason]; end
  def self.skipped(list, what); ($flow ||= []) << [:skipped, list.size, what]; end
  def self.leave(reason, whole = false, elsewhere = false); ($flow ||= []) << [:leave, reason, whole, elsewhere]; end
end

# The DLL's rules of how a Classic party's member plays the leader's story (ClassicStory), of the
# Classic catch-up, the side and the key item loan, as fixtures/catchup/engine.rb stands in for them;
# make_classic.rb records each answer as a golden case of the C# rules.
require_relative "../../fixtures/catchup/engine"
# The answers make_classic.rb records; nil while nothing records.
$classic_record ||= nil
# The tables the Classic catch-up reads, nil until the checks of the catch-up set them.
$classic_rows = nil
# The requests of the Classic catch-up, newest last.
classic_asks = []
answer_classic = lambda do |topic, &rule|
  $world_bridge.answer(topic) do |request|
    asked = Marshal.load(Marshal.dump(request))
    classic_asks << asked if topic == "catchup.classic"
    answer, party = rule.call(request)
    if $classic_record
      $classic_record << { "topic" => topic, "tables" => topic.start_with?("catchup.classic_") ? nil : $classic_rows, "request" => asked, "party" => party,
                           "answer" => Marshal.load(Marshal.dump(answer)) }
    end
    answer
  end
end
answer_classic.call("catchup.classic_sync") { |request| CatchupEngine.classic_sync(request) }
answer_classic.call("catchup.classic_followers") { |request| CatchupEngine.classic_followers(request) }
answer_classic.call("catchup.classic_mode") { |request| CatchupEngine.classic_mode(request) }
answer_classic.call("catchup.classic_restore") { |request| CatchupEngine.classic_restore(request) }

# Stands in for the DLL's rule of which of the leader's changes a member takes (ClassicMerge.Follows):
# a key of the leader's story by the scopes above, but a choice's outcome the member's own story
# keeps and an id beyond this game's data.
$world_bridge.answer("story.classic_follow") do |request|
  request["keys"].map do |kind, key|
    known = kind == 2 || (key > 0 && key < request["sizes"][kind])
    choice = kind < 2 && request["choices"][kind == 0 ? "s" : "v"].include?(key)
    known && !choice && MGQ_MpStoryState.classic_world?(kind, key)
  end
end

# Stands in for what the Classic catch-up reads of the party (ClassicParty in the DLL): a self
# switch is a member's own by the scopes the scripts hold, and a party chest gave the key items
# $key_chests names ({[map, event, letter] => [item, ...]}). Each answer is noted, for make_classic.rb.
$key_chests = {}
def classic_party(noted)
  own = lambda do |key|
    scope = MGQ_MpStoryKeys.scope_of(2, key)
    found = !scope.nil? && scope != MGQ_MpStoryKeys::SCOPE_WORLD
    (noted["own"] ||= []) << key if found
    found
  end
  chests = lambda do |opened, items|
    found = opened.map { |key| (given = Array($key_chests[key]) & items).empty? ? nil : [key, given] }.compact
    (noted["chests"] ||= []) << [opened, items, found]
    found
  end
  CatchupEngine::Party.new(own, chests)
end

# Stands in for the DLL's one companion filter (CompanionScope) by a check's rule, which lets every
# companion join a player who plays their own story, as the DLL does.
#
# @yieldparam request [Hash] The request of a member who plays the leader's story.
# @yieldreturn [Hash] The answer.
def answer_scope(&rule)
  $world_bridge.answer("catchup.scope") { |request| request["guest"] ? rule.call(request) : { "allowed" => request["actors"] } }
end

# Stands in for the DLL's scopes of a Classic party (story.replay_scopes), which KeyScopes.Classic
# builds from the reviewed list: the keys the Classic party's stand-in table shares (support.rb)
# are the world's, its chest flags the party's, the side switches each player's own as the list
# keeps them, and every party chest the rewards name is the party's.
#
# @return [Hash] The scopes, see MGQ_MpStoryKeys.scopes_of.
def classic_scopes
  table = classic_table_hash(classic_request)
  scope = lambda do |bytes|
    bytes.bytes.map { |found| found & MGQ_MpStoryKeys::CHEST != 0 ? 2 : (found & MGQ_MpStoryKeys::KEPT != 0 && found & MGQ_MpStoryKeys::SIDE == 0 ? 3 : 0) }.pack("C*")
  end
  keys = {}
  MGQ_MpStoryState.all_chest_keys.each { |key| keys["ss#{key.join('.')}"] = MGQ_MpStoryKeys::SCOPE_PARTY }
  { "switches" => scope.call(table["switches"]), "variables" => scope.call(table["variables"]), "keys" => keys, "self" => {}, "index" => [],
    "self_default" => MGQ_MpStoryKeys::SCOPE_WORLD }
end
$world_bridge.answer("story.replay_scopes") { |request| request["party"] ? classic_scopes : nil }

# Most checks play a party whose members all follow the leader's story; the checks of the rule
# when they do turn the real decision on with $real_sync.
class << MGQ_MpCoopStory
  alias real_check_sync check_sync
  alias real_follows_leader? follows_leader?
  alias real_synced_members synced_members

  # Decides whether the player follows the leader's story, see MGQ_MpCoopStory.check_sync.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The party's leader.
  def check_sync(leader)
    return real_check_sync(leader) if $real_sync

    @synced = leader.is_a?(MGQ_MpOverworldSync::Peers::Peer)
    @sync_with = @synced ? leader.state["id"].to_s : nil
    @sync_state = @synced ? :synced : nil
  end

  # Reports whether the player follows the leader's story, see MGQ_MpCoopStory.follows_leader?.
  #
  # @return [Boolean] Whether they do.
  def follows_leader?
    $real_sync ? real_follows_leader? : MGQ_MpCoop.party_leader.is_a?(MGQ_MpOverworldSync::Peers::Peer)
  end

  # Lists the members who follow the player's story, see MGQ_MpCoopStory.synced_members.
  #
  # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The members.
  def synced_members
    return real_synced_members if $real_sync

    MGQ_MpCoop.party_leader == :me ? MGQ_MpCoop::Party.members : []
  end
end

# Sorts a list of event commands, see MGQ_MpCoopEvents.kind_of.
#
# @param list [Array<RPG::EventCommand>] The commands.
# @return [Symbol] What they do.
def kind(list); MGQ_MpCoopEvents.kind_of(list); end

# Sorting events is MGQOnline.Game's EventSorter, checked by MGQOnline.Game.Tests against the golden
# cases fixtures/events/make_fixtures.rb recorded from this file's former checks, which also answer
# the sorts the checks below make (rules_support.rb).
castle_tour = [c(201, 0, 228, 24, 36, 0, 0), c(101, "", 0, 0, 2), c(401, "Wow, it's huge!"), c(121, 2013, 2013, 1), c(121, 2015, 2015, 0)]
blacksmith = [c(101, "", 0, 0, 2), Command.new(102, 0, [["Synthesis", "Talk"], 2]),
              Command.new(402, 0, [0, "Synthesis"]), Command.new(355, 1, ["call_synthesize(14)"]), Command.new(0, 1, []),
              Command.new(402, 0, [1, "Talk"]), Command.new(101, 1, ["", 0, 0, 2]), Command.new(122, 1, [1007, 1007, 0, 0, 1]), Command.new(0, 1, []),
              Command.new(404, 0, [])]
story = MGQ_MpStoryState
check("the awakening switches are the player's own, the story's boss flags from 7000 are not", [6500, 6999, 7015].map { |id| story.personal_switch?(id) }, [true, true, false])

# Chests, first before the relay's rewards came.
$world_bridge.answer("story.rewards") { |_known| nil }
rewards_changed
$game_map = Game_Map.new
$game_party = Game_Party.new
$game_switches = Game_Switches.new
$game_variables = Game_Variables.new
$game_self_switches = Game_SelfSwitches.new
chest_page = RPG::Page.new([c(126, 1, 0, 0, 2), c(123, "A", 0)])
talk_page = RPG::Page.new([c(101, "", 0, 0, 2)])
$game_map.events = { 5 => Game_Event.new(5, [chest_page]), 6 => Game_Event.new(6, [talk_page]) }
kinds_asked = []
$world_bridge.answer("events.kinds") { |request| kinds_asked << request["pages"]; golden_kinds(request) }
check("the map's chests are found", MGQ_MpCoopEvents.chest_keys, [[3, 5, "A"]])
check("after asking the DLL's events database for them by each page's length and shape",
      $world_bridge.calls.select { |topic, _| topic == "events.chests" }.map { |_, bytes| Marshal.load(bytes) },
      [{ "map" => 3, "rows" => [[5, 0, 2, MGQ_MpCoopEvents.shape(chest_page.list)], [6, 0, 1, MGQ_MpCoopEvents.shape(talk_page.list)]] }])
check("from one call naming each page by its length and shape and one handing over those the DLL's database holds otherwise",
      kinds_asked.map { |pages| pages.map { |row| row[2].is_a?(Array) ? row[0, 2] + [row[2].size] : row } },
      [[[5, 0, 2, MGQ_MpCoopEvents.shape(chest_page.list)], [6, 0, 1, MGQ_MpCoopEvents.shape(talk_page.list)]], [[5, 0, 2], [6, 0, 1]]])
opened_page = RPG::Page.new([c(101, "", 0, 0, 2)])
$game_map.events[7] = Game_Event.new(7, [chest_page, opened_page])
$game_map.events[7].show(1)
MGQ_MpCoopEvents.instance_variable_set(:@chest_keys_map, nil)
check("so is a chest that shows its opened page", MGQ_MpCoopEvents.chest_keys, [[3, 5, "A"], [3, 7, "A"]])
$game_map.events.delete(7)
MGQ_MpCoopEvents.instance_variable_set(:@chest_keys_map, nil)
kinds_asked.clear
$world_bridge.answer("events.chests") { |request| { "letters" => request["rows"].map { |row| row[0] == 5 ? "B" : false } } }
check("a chest the database names is the self switch it names, with no page sorted, and a page it names no chest is none",
      [MGQ_MpCoopEvents.chest_keys, kinds_asked], [[[3, 5, "B"]], []])
$world_bridge.answer("story.rewards") { |_known| CatchupRelayRows.party_rewards(nil).merge("chests" => [[3, 6, "C"], [4, 6, "C"]], "rev" => 2) }
MGQ_MpStoryState.instance_variable_set(:@rewards_at, nil)
check("once the relay's rewards came, the map's chests are those of every chest it keeps, a chest behind a branch a new game skips among them",
      MGQ_MpCoopEvents.chest_keys, [[3, 6, "C"]])
check("and a chest the database names that the relay's reviewed rows leave out is no player's own",
      [MGQ_MpCoopEvents.chest_key?([3, 5, "B"]), story.personal_self_switch?([3, 5, "B"])], [false, false])
# From here the relay keeps the chest of the test's map among every chest of the game.
answer_party_rewards($world_bridge)
$world_bridge.answer("story.rewards") { |_known| CatchupRelayRows.party_rewards(nil).merge("chests" => [[3, 5, "A"]], "rev" => 1) }
rewards_changed
answer_events($world_bridge)
MGQ_MpCoopEvents.instance_variable_set(:@chest_keys_map, nil)

# The DLL reads a map event's page or a common event from its events database while the database
# holds the list as the game does: the scripts name it with its length and shape, the 24-bit hash
# both sides compute alike. A common event's list and a list handed over name the map and event
# that run it, inside whose map folder the list's transfers lead.
shape_cases = JSON.parse(File.read(File.join(RULE_FIXTURES, "events", "hash_cases.json")))["cases"]
check("the shape of each list of fixtures/events/hash_cases.json is the one the DLL computes",
      shape_cases.reject { |known| MGQ_MpCoopEvents.shape(known["list"].map { |code, indent, parameters| Command.new(code, indent, parameters) }) == known["shape"] }.map { |known| known["name"] }, [])
check("a map event's page is named with its length and shape", MGQ_MpCoopEvents.request_for(chest_page.list, $game_map.events[5]),
      { "map" => 3, "event" => 5, "page" => 0, "size" => 2, "shape" => MGQ_MpCoopEvents.shape(chest_page.list) })
check("a common event's list with the map and the event that run it", MGQ_MpCoopEvents.request_for($data_common_events[6].list, $game_map.events[5]),
      { "map" => 3, "event" => 5, "common" => 6, "size" => 2, "shape" => MGQ_MpCoopEvents.shape($data_common_events[6].list) })
check("a list handed over with the running map and no event", MGQ_MpCoopEvents.request_for([c(101, "", 0, 0, 2)], nil).values_at("map", "event", "list"),
      [3, 0, [[101, 0, ["", 0, 0, 2]]]])
check("the DLL had the game data's fingerprint once, before its first question", $world_bridge.calls.count { |topic, _| topic == "events.open" }, 1)

# The DLL's replay topics: in a Classic world the chests of map 3 are the party's, in a Raid World
# each player's own, and switch 22 is the world's; a run's end answers its entry, which crosses to
# the party as "WIRE:<id>".
$ran = []
$world_bridge.answer("story.replay_scopes") do |request|
  found = request["party"] ? classic_scopes : { "switches" => "\0" * 30, "variables" => "\0" * 10, "keys" => {}, "self" => {}, "index" => [], "self_default" => 0 }
  found["keys"].update("ss3.5.A" => 2, "ss3.8.A" => 2, "ss3.9.A" => 2) if request["party"]
  found["switches"].setbyte(22, MGQ_MpStoryKeys::SCOPE_WORLD)
  found
end
MGQ_MpStoryKeys.instance_variable_set(:@scopes, nil)
$world_bridge.answer("story.replay_reads") { |_request| [] }
$world_bridge.answer("story.replay_ran") { |request| $ran << request; { "id" => "e#{$ran.size}", "site" => request["site"], "scope" => "party", "stream" => request["party_stream"] } }
$world_bridge.answer("story.replay_wire") { |entry| "WIRE:#{entry['id']}" }
$world_bridge.answer("story.replay_unwire") do |text|
  id = text.sub("WIRE:", "")
  world = id.start_with?("w")
  { "id" => id, "site" => "map:4:9:1", "scope" => world ? "world" : "party", "stream" => world ? "story" : "party:p1", "place" => world ? [12, 0, 0, 0] : nil,
    "keys" => world ? { "s2280" => "0" } : { "ss4.9.A" => "0" } }
end

$party = "p1"
$leader = :me
friend = MGQ_MpOverworldSync::Peers::Peer.new(2, { "id" => "f", "name" => "Friend", "party" => "p1" }, nil, true)
$members = [friend]
$sent.clear
$game_map.interpreter.setup(chest_page.list, 5)
$game_map.interpreter.run
check("opening a chest hands the party the run that opened it, which changed the chest's party key",
      [$sent.map { |seat, f| [seat, f["replay"]] }, $ran.last.values_at("site", "changed", "owner", "party_stream")],
      [[[-1, "WIRE:e1"]], ["map:3:5:1", { "ss3.5.A" => ["0", "1"] }, true, "party:p1"]])
$sent.clear
$game_map.events[9] = Game_Event.new(9, [RPG::Page.new([c(123, "A", 0), c(126, 1, 0, 0, 1), c(121, 22, 22, 0)])])
MGQ_MpCoopEvents.instance_variable_set(:@chest_keys_map, nil)
$game_map.interpreter.setup($game_map.events[9].list, 9)
$game_map.interpreter.run
check("a chest that also turns on a world switch reaches the party all the same",
      [$sent.map { |seat, f| [seat, f["replay"]] }, $ran.last.values_at("changed", "owner", "party_stream")],
      [[[-1, "WIRE:e2"]], [{ "ss3.9.A" => ["0", "1"], "s22" => ["0", "1"] }, true, "party:p1"]])
$game_map.events.delete(9)
MGQ_MpCoopEvents.instance_variable_set(:@chest_keys_map, nil)
# The leader tells the party the story's writes their game made, as story_keys.rbx records them.
MGQ_MpCoopStory.update
$sent.clear
$game_switches[2280] = true
$game_variables[1050] = 31
$game_variables[3001] = 9
$game_variables[1050] = 32
MGQ_MpStoryKeys.flush
MGQ_MpCoopStory::SEND_FRAMES.times { MGQ_MpCoopStory.update }
check("as leader, the party hears the story's writes the player's game made in one change, the last of each, each player's own left out",
      $sent.select { |_, f| f["story"] == "delta" }.map { |seat, f| [seat, f["s"], f["v"], f["ss"]] }, [[-1, "2280:1", "1050:n32", ""]])
MGQ_MpCoopStory::SEND_FRAMES.times { MGQ_MpCoopStory.update }
check("and nothing more while their game wrote nothing", $sent.count { |_, f| f["story"] == "delta" }, 1)
$sent.clear
other = Game_Interpreter.new
other.setup(talk_page.list, 6)
other.run
check("other events tell nothing", $sent.size, 0)
locked_page = RPG::Page.new([c(111, 12, "unlock_level < 1"), c(101, "", 0, 0, 2), c(115), c(123, "A", 0), c(126, 1, 0, 0, 1)])
$game_map.events[8] = Game_Event.new(8, [locked_page])
MGQ_MpCoopEvents.instance_variable_set(:@chest_keys_map, nil)
$game_map.interpreter.setup(locked_page.list, 8)
$game_map.interpreter.run
check("a locked chest tells nothing", $sent.size, 0)
check("and stays shut", raw($game_self_switches)[[3, 8, "A"]], nil)
$game_map.events.delete(8)
MGQ_MpCoopEvents.instance_variable_set(:@chest_keys_map, nil)

SceneManager.scene = Scene_Battle.new
MGQ_MpCoopEvents.take_entry(friend, { "replay" => "WIRE:x1", "party" => "p1" })
check("a chest a member opened waits to play in the player's own game, named by who opened it, in a battle too",
      [MGQ_MpStoryReplay.waiting.map { |entry| [entry["id"], entry["opener"]] }, $game_party.items["Elixir"]], [[["x1", "Friend"]], 0])
MGQ_MpCoopEvents.take_entry(MGQ_MpOverworldSync::Peers::Peer.new(8, { "party" => "p9" }, nil, false), { "replay" => "WIRE:x2", "party" => "p1" })
check("strangers hand over nothing", MGQ_MpStoryReplay.waiting.size, 1)
MGQ_MpStoryReplay.waiting.clear
SceneManager.scene = Scene_Map.new
$sent.clear
MGQ_MpCoopEvents.hand_entry("id" => "w1", "site" => "map:4:9:1", "scope" => "world", "stream" => "story")
check("as leader, a run of the story that changed a world key goes to every member as its entry", $sent.map { |seat, f| [seat, f["replay"]] }, [[-1, "WIRE:w1"]])

# Chests while playing the leader's story.
leader = MGQ_MpOverworldSync::Peers::Peer.new(4, { "id" => "l", "name" => "Leader", "party" => "p1" }, nil, true)
$leader = leader
$members = [leader]
raw($game_self_switches)[[3, 5, "A"]] = nil
MGQ_MpCoopStory.take(leader, { "story" => "full", "party" => "p1", "s" => "", "v" => "", "ss" => "3.5.A,3.1.B" })
check("a member's chests stay their own on the leader's story", [raw($game_self_switches)[[3, 5, "A"]], raw($game_self_switches)[[3, 1, "B"]]], [nil, true])
MGQ_MpCoopStory.take(leader, { "story" => "delta", "party" => "p1", "s" => "", "v" => "", "ss" => "3.5.A:1" })
check("and the leader's chests do not change them", raw($game_self_switches)[[3, 5, "A"]], nil)
MGQ_MpCoopEvents.take_entry(leader, { "replay" => "WIRE:w2", "party" => "p1" })
MGQ_MpCoopEvents.take_entry(friend, { "replay" => "WIRE:w3", "party" => "p1" })
MGQ_MpCoopEvents.take_entry(leader, { "replay" => "WIRE:w7", "party" => "p1", "opener" => "Friend" })
check("a member who follows the leader's story waits to play the leader's run in their own game, in the stream of the leader's story, not of their own, named by who ran it",
      MGQ_MpStoryReplay.waiting.map { |entry| entry.values_at("id", "stream", "opener", "place") },
      [["w2", "story:l", "Leader", [12, 0, 0, 0]], ["w7", "story:l", "Friend", [12, 0, 0, 0]]])
MGQ_MpStoryReplay.waiting.clear
$sent.clear
MGQ_MpCoopEvents.hand_entry("id" => "w4", "site" => "map:4:9:1", "scope" => "world", "stream" => "story")
check("a member's own run of the story waits to go to the leader with their requests", $sent, [])
$game_map.interpreter.setup(chest_page.list, 5)
$game_map.interpreter.run
check("a chest a member opens is theirs for good, in their own story kept aside too", MGQ_MpCoopStory.own_story_aside[2][[3, 5, "A"]], true)

# A member's writes of the leader's story go to the leader as requests (A4); the leader's story is
# the one truth, takes them by the list's merge kinds (variable 1020 one way), as the DLL's
# ClassicMerge decides over the list's scopes and classes, and sends back what it keeps by value.
$world_bridge.answer("story.classes") { story_table_hash([[0, 9999, 1]], [[0, 1019, 1], [1020, 1020, 3], [1021, 4999, 1]], 1) }
$world_bridge.answer("story.classic_merge") do |request|
  list = MGQ_MpStoryKeys.table_of(story_table_hash([[0, 9999, 1]], [[0, 1019, 1], [1020, 1020, 3], [1021, 4999, 1]], 1))
  changed = {}
  takes = request["writes"].map do |kind, key, held, value|
    found = MGQ_MpStoryKeys.class_of(kind, key, nil, list)
    lower = held =~ /\An(-?\d+)\z/ && value =~ /\An(-?\d+)\z/ && value[1..-1].to_i < held[1..-1].to_i
    taken = MGQ_MpStoryState.classic_world?(kind, key) && found & MGQ_MpStoryKeys::COUNT == 0 && !(found & MGQ_MpStoryKeys::ONE_WAY != 0 && lower) ? true : false
    changed[MGQ_MpStoryKeys.key_text(kind, key)] = true if taken && held != value
    taken
  end
  keeps = request["runs"].map do |names, site|
    names.any? do |name|
      kind, key = MGQ_MpStoryKeys.key_of(name)
      changed[name] || (kind && kind < 3 && MGQ_MpStoryKeys.scope_of(kind, key, site) == MGQ_MpStoryKeys::SCOPE_PARTY) ? true : false
    end
  end
  { "takes" => takes, "keeps" => keeps }
end
MGQ_MpCoopStory.update
MGQ_MpCoopStory.take(leader, { "story" => "full", "party" => "p1", "s" => "", "v" => "", "ss" => "" })
$sent.clear
MGQ_MpCoopStory.update
$game_switches[2280] = true
$game_variables[1020] = 3
$game_variables[3001] = 9
MGQ_MpStoryKeys.flush
MGQ_MpCoopEvents.hand_entry("id" => "w8", "site" => "map:4:9:1", "scope" => "world", "stream" => "story")
MGQ_MpCoopStory::SEND_FRAMES.times { MGQ_MpCoopStory.update }
check("a member's writes of the leader's story go to the leader as requests, each player's own left out, with the member's runs of it",
      $sent.select { |_, f| f["story"] == "req" }.map { |seat, f| [seat, f["s"], f["v"], f["ss"], f["runs"]] }, [[4, "2280:1", "1020:n3", "", "WIRE:w8"]])
$leader = :me
$members = [friend]
MGQ_MpCoopStory.update
raw($game_switches)[2280] = false
raw($game_variables)[1020] = 5
$sent.clear
MGQ_MpCoopStory.take(friend, { "story" => "req", "party" => "p1", "s" => "2280:1", "v" => "1020:n3", "ss" => "", "runs" => "WIRE:w5" })
MGQ_MpCoopStory::SEND_FRAMES.times { MGQ_MpCoopStory.update }
check("the leader's story takes a member's write and sends it back to everyone by value, and a write it refuses comes back as it keeps it",
      [raw($game_switches)[2280], raw($game_variables)[1020], $sent.select { |_, f| f["story"] == "delta" }.map { |seat, f| [seat, f["s"], f["v"]] }],
      [true, 5, [[-1, "2280:1", "1020:n5"]]])
check("a member's run whose writes changed the leader's story goes to the party in the leader's stream, named by its opener, and plays in the leader's game too",
      [$sent.select { |_, f| f["replay"] }.map { |seat, f| [seat, f["replay"], f["opener"]] },
       MGQ_MpStoryReplay.waiting.map { |entry| entry.values_at("id", "stream", "opener") }],
      [[[-1, "WIRE:w5", "Friend"]], [["w5", MGQ_MpStoryKeys.story_stream(:me), "Friend"]]])
MGQ_MpStoryReplay.waiting.clear
$sent.clear
MGQ_MpCoopStory.take(friend, { "story" => "req", "party" => "p1", "s" => "2280:1", "v" => "", "ss" => "", "runs" => "WIRE:w6" })
check("one whose writes changed nothing of it goes to nobody", [$sent.select { |_, f| f["replay"] }, MGQ_MpStoryReplay.waiting], [[], []])
MGQ_MpCoopStory.take(MGQ_MpOverworldSync::Peers::Peer.new(8, { "id" => "s", "party" => "p9" }, nil, false),
                     { "story" => "req", "party" => "p1", "s" => "2281:1", "v" => "", "ss" => "" })
check("a stranger's request is refused", raw($game_switches)[2281], nil)
$party = nil
$leader = nil
$members = []
$game_map.update
MGQ_MpCoopStory.update
check("and stays opened in their own story", raw($game_self_switches)[[3, 5, "A"]], true)

# Travelling together.
$game_player = Game_Player.new
$game_message = Game_Message.new
SceneManager.scene = Scene_Map.new
$game_map.map_id = 3
$party = "p1"
$leader = :me
$members = [friend]
$sent.clear
$game_player.reserve_transfer(9, 4, 5, 8)
$game_player.perform_transfer
check("the leader's transfers take nobody along", $sent, [])
$sent.clear
$game_map.interpreter.setup([c(101, "", 0, 0, 2), c(121, 60, 60, 0)], 1)
check("and gathers it for a story scene", $sent.map { |seat, f| [seat, f["pevent"], f["map"]] }, [[-1, "gather", "9"]])
$sent.clear
$game_map.interpreter.setup([c(101, "", 0, 0, 2)], 1)
Game_Interpreter.new.setup([c(101, "", 0, 0, 2), c(121, 60, 60, 0)], 1)
check("but not for a talk, or for other interpreters", $sent.size, 0)
$game_map.interpreter.setup([c(101, "", 0, 0, 2), c(121, 60, 60, 0)])
check("a common event, set up with its list alone, gathers the party for its story scene too", $sent.map { |seat, f| [seat, f["pevent"], f["map"]] }, [[-1, "gather", "9"]])
$sent.clear
$data_common_events[114] = RPG::CommonEvent.new([c(101, "", 0, 0, 2), c(121, 60, 60, 0)])
$game_map.interpreter.setup($data_common_events[114].list)
check("the game's transfer process, a common event of the player's own, gathers nobody", [$sent, MGQ_MpCoopEvents.telling?], [[], false])
[2, 3, 5].each do |id|
  $data_common_events[id] = RPG::CommonEvent.new([c(101, "", 0, 0, 2), c(121, 7, 7, 0)])
  $game_map.interpreter.setup($data_common_events[id].list)
  check("the game's common event #{id} (map display, Pocket Castle call, after every battle) is the player's own, never story",
        [$sent, MGQ_MpCoopEvents.telling?], [[], false])
  $data_common_events[id] = nil
end
raw($game_switches)[443] = true
$game_map.interpreter.setup([c(101, "", 0, 0, 2), c(121, 60, 60, 0)])
$game_map.interpreter.setup([c(101, "", 0, 0, 2), c(121, 60, 60, 0)], 1)
check("nor does a scene the Library replays, or an event on its map", [$sent, MGQ_MpCoopEvents.telling?], [[], false])
raw($game_switches)[443] = false
$data_common_events[114] = nil

$leader = leader
$members = [leader]
$game_map.map_id = 3
$game_player.moveto(1, 1)
MGQ_MpCoopEvents.take(leader, { "pevent" => "travel", "party" => "p1", "map" => "7", "x" => "2", "y" => "2", "d" => "4" })
$game_map.update
$game_map.update
check("a member stays when the leader goes to another map", $game_player.reserved, nil)
MGQ_MpCoopEvents.take(friend, { "pevent" => "gather", "party" => "p1", "map" => "7", "x" => "2", "y" => "2", "d" => "4" })
check("only the leader calls the party to a story scene", MGQ_MpCoopGather.own_doing, nil)
$game_map.map_id = 7
$game_player.moveto(2, 2)

# A member called to the leader's story scene.
$notices.clear
leader.state.merge!("map" => "8")
MGQ_MpCoopEvents.take(leader, { "pevent" => "gather", "party" => "p1", "map" => "8", "x" => "9", "y" => "3", "d" => "6" })
$game_map.update
check("a member called to the story hears when they come over", [$notices.last, MGQ_MpCoopGather.own_doing], ["Leader's story is starting. You join them in 5 seconds.", ["Joining Leader", 5.0]])
check("and is not moved before five seconds", [$game_player.reserved, $game_map.map_id], [nil, 7])
$game_player.encounter_count = 5
check("a member about to come over meets no random encounter while steps are left", $game_player.encounter, false)
$game_player.encounter_count = 0
check("nor once they ran out, which draws new steps", [$game_player.encounter, $game_player.encounter_count], [false, 30])
$frame_count = 150
MGQ_MpCoopEvents.take(leader, { "pevent" => "gather", "party" => "p1", "map" => "8", "x" => "9", "y" => "3", "d" => "6" })
check("calls again do not start the time anew", MGQ_MpCoopGather.own_doing, ["Joining Leader", 2.5])
$frame_count = 300
SceneManager.scene = Scene_Battle.new
$game_map.update
check("a member in battle comes once it is over", [$game_player.reserved, MGQ_MpCoopGather.own_doing], [nil, "Joining Leader once free"])
SceneManager.scene = Scene_Map.new
$brightness = 0
$game_map.update
check("not while the screen is still dark from the battle", $game_player.reserved, nil)
$brightness = nil
$game_map.update
check("then they are brought to the leader's map", $game_player.reserved, [8, 9, 3, 6])
$game_player.perform_transfer
check("and wait no more", MGQ_MpCoopGather.own_doing, nil)
$game_player.encounter_count = 0
check("then random encounters come again", $game_player.encounter, true)
MGQ_MpCoopEvents.take(leader, { "pevent" => "gather", "party" => "p1", "map" => "8", "x" => "11", "y" => "4", "d" => "6" })
check("a member standing near already is not moved", [MGQ_MpCoopGather.own_doing, $game_player.x], [nil, 9])
$frame_count = 2000
MGQ_MpCoopEvents.take(leader, { "pevent" => "gather", "party" => "p1", "map" => "5", "x" => "1", "y" => "1", "d" => "2" })
$frame_count = 2359
check("a call stands while the leader still calls", MGQ_MpCoopGather.own_doing, "Joining Leader once free")
$frame_count = 2360
$notices.clear
check("asking whether the member is coming once the calls stopped says no and tells the member so once", [MGQ_MpCoopGather.coming?, $notices],
      [false, ["Leader's story started without you."]])
$game_map.update
check("once the calls stop, the story started without the member, who stays", [MGQ_MpCoopGather.own_doing, $notices.last, $game_player.reserved],
      [nil, "Leader's story started without you.", nil])

# A member teleports to another member through coop_teleport.rbx, which brings them over here.
MGQ_MpCoopGather.come_to("Leader", [5, 1, 1, 2])
check("a member who teleports waits only to be free", MGQ_MpCoopGather.own_doing, "Joining Leader once free")
$game_map.update
check("and comes at once", $game_player.reserved, [5, 1, 1, 2])
$game_player.instance_variable_set(:@reserved, nil)

# While the leader's story scene plays, the member stands still.
check("free while the leader tells no story", [$game_player.movable?, MGQ_MpCoopGather.blocked?], [true, false])
leader.state["telling"] = "1"
scene = Scene_Map.new
scene.update_call_menu
check("blocked while it plays: no moving, no menu", [$game_player.movable?, scene.menu_calling], [false, false])
leader.state["scene"] = "battle"
check("free while the leader fights the story's battle, which a member who missed its invite would stand through", [$game_player.movable?, MGQ_MpCoopGather.blocked?], [true, false])
leader.state.delete("scene")
check("and blocked again once the story goes on", MGQ_MpCoopGather.blocked?, true)
leader.state["map"] = "5"
check("a member on another map, whom the story started without, plays on", [$game_player.movable?, MGQ_MpCoopGather.blocked?], [true, false])
leader.state["map"] = "8"
leader.state["telling"] = "0"
scene.update_call_menu
check("free again once it ends", [$game_player.movable?, scene.menu_calling], [true, :asked])

# The leader's story scene waits for the party.
$leader = :me
$members = [friend]
$game_map.map_id = 3
$game_player.moveto(5, 5)
friend.state.merge!("map" => "9", "x" => "1", "y" => "1")
$frame_count = 1000
$sent.clear
$notices.clear
interpreter = $game_map.interpreter
interpreter.setup([c(101, "", 0, 0, 2), c(121, 60, 60, 0)], 1)
check("a story scene calls the members", [$sent.map { |seat, f| [seat, f["pevent"], f["map"], f["x"]] }, $notices.last], [[[-1, "gather", "3", "5"]], "Gathering the party for the story . . ."])
interpreter.busy = true
check("and waits while one is away", [MGQ_MpCoopGather.holding?(interpreter), MGQ_MpCoopGather.own_doing, MGQ_MpCoopEvents.state_fields["telling"]], [true, ["Gathering: Friend", 30.0], 0])
check("the leader only waits for the party then, so the chat may open", MGQ_MpCoopGather.waiting?, true)
$sent.clear
$frame_count = 1100
MGQ_MpCoopGather.holding?(interpreter)
check("calling again only every three seconds", $sent.size, 0)
$frame_count = 1200
MGQ_MpCoopGather.holding?(interpreter)
check("then once more", $sent.map { |_, f| f["pevent"] }, ["gather"])
check("other interpreters never wait", MGQ_MpCoopGather.holding?(Game_Interpreter.new), false)
friend.state.merge!("map" => "3", "x" => "7", "y" => "4")
check("once everyone stands near, the scene plays", [MGQ_MpCoopGather.holding?(interpreter), $notices.last, MGQ_MpCoopEvents.state_fields["telling"]], [false, "The party is here.", 1])
check("but no longer once the scene plays", MGQ_MpCoopGather.waiting?, false)
interpreter.busy = false
check("and the members are free once it ends", MGQ_MpCoopEvents.state_fields["telling"], 0)
$sent.clear
interpreter.setup([c(101, "", 0, 0, 2), c(121, 60, 60, 0)], 1)
check("a party gathered already plays at once", [$sent.size, MGQ_MpCoopGather.holding?(interpreter)], [0, false])
friend.state.merge!("map" => "9", "x" => "1", "y" => "1")
$frame_count = 3000
interpreter.setup([c(101, "", 0, 0, 2), c(121, 60, 60, 0)], 1)
interpreter.busy = true
$frame_count = 4799
check("a member who does not come holds the scene up to thirty seconds", MGQ_MpCoopGather.holding?(interpreter), true)
$frame_count = 4800
check("then it plays without them", [MGQ_MpCoopGather.holding?(interpreter), $notices.last, MGQ_MpCoopEvents.state_fields["telling"]],
      [false, "The story starts without Friend.", 1])

# The story moves the leader elsewhere, as a theater show's stage or a story's own teleport: the
# members who stood near come along at once, the others stay.
far_friend = MGQ_MpOverworldSync::Peers::Peer.new(5, { "id" => "g", "name" => "Far", "party" => "p1", "map" => "9" }, nil, true)
$members = [friend, far_friend]
friend.state.merge!("map" => "3", "x" => "6", "y" => "5")
$sent.clear
$game_player.reserve_transfer(624, 63, 27, 2)
$game_player.perform_transfer
check("the members near the leader are told to follow to the new place", $sent.map { |seat, f| [seat, f["pevent"], f["map"], f["x"], f["y"]] },
      [[2, "follow", "624", "63", "27"]])
interpreter.busy = false
$sent.clear
$game_player.reserve_transfer(3, 5, 5, 2)
$game_player.perform_transfer
check("a transfer outside the story takes nobody along", $sent, [])
$members = [friend]
$leader = leader
$members = [leader]
$game_map.map_id = 7
$game_player.moveto(2, 2)
MGQ_MpCoopEvents.take(leader, { "pevent" => "follow", "party" => "p1", "map" => "624", "x" => "63", "y" => "27", "d" => "2" })
check("a member following hears the leader's pages of the new map before arriving", [MGQ_MpCoopGather.story_map?(624), MGQ_MpCoopGather.story_map?(5)], [true, false])
$game_map.update
check("and comes along at once", $game_player.reserved, [624, 63, 27, 2])
$game_player.instance_variable_set(:@reserved, nil)
check("then waits for nothing more", MGQ_MpCoopGather.own_doing, nil)

# The Pocket Castle's way out returns each player where they came from.
check("where the castle's way out returns is each player's own", (21..23).map { |id| MGQ_MpStoryState.personal_variable?(id) }, [true, true, true])
$game_map.map_id = 7
$game_player.moveto(12, 30)
$game_variables[21] = 1
MGQ_MpCoopEvents.take(leader, { "pevent" => "follow", "party" => "p1", "map" => "126", "x" => "15", "y" => "14", "d" => "2" })
$game_map.update
check("a member the party brings into the castle returns where they stood", [21, 22, 23].map { |id| $game_variables[id] }, [7, 12, 30])
$game_player.instance_variable_set(:@reserved, nil)
$game_map.map_id = 126
MGQ_MpCoopCastle.arriving(229)
check("moving inside the castle keeps it", [21, 22, 23].map { |id| $game_variables[id] }, [7, 12, 30])
$game_map.map_id = 7

# A duel: a call during it is kept out, and one that waited through it is dropped as the duel puts
# the game back, so the leader's next call brings the player over on a settled map.
module MGQ_MpBattlesPvp; module Battle; def self.running?; $pvp; end; end; end
$pvp = true
gather_call = { "pevent" => "gather", "party" => "p1", "map" => "9", "x" => "1", "y" => "1", "d" => "2" }
MGQ_MpCoopEvents.take(leader, gather_call)
check("a call during a duel is kept out", MGQ_MpCoopGather.coming?, false)
$pvp = false
MGQ_MpCoopEvents.take(leader, gather_call)
MGQ_MpCoopGather.drop_call("a PvP battle put the game back")
check("a call the duel's end drops is gone", MGQ_MpCoopGather.coming?, false)
MGQ_MpCoopEvents.take(leader, gather_call)
check("the leader's next call stands again", MGQ_MpCoopGather.coming?, true)
MGQ_MpCoopGather.drop_call("test over")

# Story events in the leader's game.
story_page = RPG::Page.new([c(101, "", 0, 0, 2), c(401, "Line"), c(121, 60, 60, 0)])
$game_map.map_id = 7
$game_map.events = { 11 => Game_Event.new(11, [story_page]), 12 => Game_Event.new(12, [talk_page]), 13 => Game_Event.new(13, [story_page], 3) }
leader.state["map"] = "7"
$sent.clear
$game_map.events[11].start
check("a member's story event does not run in their game", [$game_map.setup_starting_map_event, $game_map.events[11].locked], [nil, false])
check("nor in the leader's: nobody is asked to play it", $sent, [])
check("and the member hears that only the leader moves the story on", $notices.last, "Only Leader can move the story on.")
$notices.clear
$game_map.events[11].start
$game_map.setup_starting_map_event
check("starting it again at once says nothing more", $notices, [])
$game_map.events[12].start
check("a talk runs in the member's own game", $game_map.setup_starting_map_event, $game_map.events[12])
# When the player entered the map, from $map_since.
module MGQ_MpOverworldSync; module Me; def self.map_since; $map_since; end; end; end
$map_since = 1000
$sent.clear
$flow = []
$game_map.events[13].start
check("a story event that runs by itself is left to the leader's game", [$game_map.setup_starting_map_event, $sent.size], [nil, 0])
check("which notes it kept the leader's scene from starting, for their follow (issue 61)", [MGQ_MpCoopEvents.keeps_autorun_of?(leader), MGQ_MpCoopEvents.keeps_autorun_of?(far_friend)], [true, false])
$frame_count += MGQ_MpCoopEvents::KEPT_AUTORUN_FRAMES + 1
check("only while it keeps it", MGQ_MpCoopEvents.keeps_autorun_of?(leader), false)
check("and hands its commands to the guard of the game's flow, which puts back what it would have, as the light of a player who came in the middle of it (issue #9)",
      $flow, [[:skipped, $game_map.events[13].list.size, "event 13 on map 7"]])
events = $game_map.events
$game_map.events = { 13 => events[13], 12 => events[12] }
$game_map.events[13].start
$game_map.events[12].start
check("and does not keep the member's own events from starting", [$game_map.setup_starting_map_event, $game_map.events[13].starting], [events[12], false])
$game_map.events = events
leader.state["map"] = "8"
MGQ_MpCoopEvents.instance_variable_set(:@refused, nil)
$game_map.events[11].start
$game_map.setup_starting_map_event
check("with the leader elsewhere, the member is told to bring them", [$sent.size, $notices.last], [0, "Only Leader can move the story on. Bring them here to go on."])
MGQ_MpCoopEvents.instance_variable_set(:@refused_at, $frame_count + 1000)
$notices.clear
$game_map.events[11].start
$game_map.setup_starting_map_event
check("a refusal from before a loaded save, whose frame count is lower, is long past", $notices.size, 1)
leader.state["map"] = "7"

# A common event, which runs by itself once it has a switch.
class RPG::CommonEvent; attr_accessor :switch_id; def autorun?; !@switch_id.nil?; end; end
raw($game_switches)[70] = true
$data_common_events[4] = RPG::CommonEvent.new([c(101, "", 0, 0, 2), c(121, 60, 60, 0)])
$data_common_events[4].switch_id = 70
class Game_Switches; def [](id); @data[id] || false; end; end
check("a story common event that runs by itself is left to the leader's game too", $game_map.setup_autorun_common_event, nil)
story_common = $data_common_events[4]
own_transfer = RPG::CommonEvent.new([c(101, "", 0, 0, 2), c(121, 60, 60, 0)])
own_transfer.switch_id = 70
$data_common_events[4], $data_common_events[114] = nil, own_transfer
check("but the game's transfer process runs in the member's own game", $game_map.setup_autorun_common_event, own_transfer)
$data_common_events[4], $data_common_events[114] = story_common, nil
$leader = :me
$members = [friend]
check("the leader's own game runs it", $game_map.setup_autorun_common_event, $data_common_events[4])
$data_common_events[4] = nil

# The leader tells the dialogue; a member's request to play a story event starts nothing.
$game_message.busy = false
$game_map.interpreter.busy = false
MGQ_MpCoopEvents.take(friend, { "pevent" => "run", "party" => "p1", "map" => "7", "event" => "11" })
$game_map.update
check("the leader's game starts no story event a member asks for", $game_map.events[11].starting ? true : false, false)
$sent.clear
$game_map.interpreter.setup(story_page.list, 11)
$game_message.face_name = "Alice"
$game_message.face_index = 2
$game_message.add("Hello, \\N[1]!")
$game_message.choices.push("Yes", "No")
$game_map.interpreter.wait_for_message
$game_message.clear
$game_map.interpreter.wait_for_message
says = $sent.select { |_, f| f["pevent"] == "say" }
check("the leader's story message goes to the party once", says.size, 1)
say = says.first[1]
check("and once the leader moved on, that it is done", $sent.map { |_, f| [f["pevent"], f["page"]] }.select { |kind, _| %w[say done].include?(kind) }, [["say", say["page"]], ["done", say["page"]]])
# A common event the story calls runs in a child interpreter inside the main one's turn, and its
# dialogue, such as a companion's lines, goes to the party too; a parallel one's does not.
# Stands in for coop_scene.rbx, whether the map's turn runs read from $map_turn.
module MGQ_MpCoopScene; def self.map_turn?; $map_turn; end; end
child = Game_Interpreter.new
$sent.clear
$map_turn = true
$game_message.add("A companion's line")
child.wait_for_message
$game_message.clear
child.wait_for_message
$map_turn = false
$game_message.add("A parallel line")
Game_Interpreter.new.wait_for_message
$game_message.clear
Game_Interpreter.new.wait_for_message
check("a common event the story calls tells its page, a parallel one does not",
      $sent.select { |_, f| f["pevent"] == "say" }.map { |_, f| page_line(f["lines"]) }, ["A companion's line"])
Object.send(:remove_const, :MGQ_MpCoopScene)
$game_message.add("Hello, \\N[1]!")
$game_message.choices.push("Yes", "No")
check("with its face and text", [say["face"], say["index"], say["map"], page_line(say["lines"].split(",")[0]), say["choices"].split(",").map { |t| page_line(t) }], ["Alice", "2", "7", "Hello, \\N[1]!", ["Yes", "No"]])

# Holding the game's skip, the leader passes a page every frame: the members hear one page every
# SKIP_SEND_FRAMES, always the last, and that the leader moved past only the pages told.
pass_page = lambda do |text|
  $frame_count += 1
  $game_message.add(text)
  $game_map.interpreter.wait_for_message
  $game_message.clear
  $game_map.update
end
told_pages = lambda { $sent.select { |_, f| %w[say done].include?(f["pevent"]) }.map { |seat, f| [seat, f["pevent"], f["page"], f["lines"] && page_line(f["lines"])] } }
SceneManager.scene = Scene_Map.new
$game_message.clear
$game_map.interpreter.setup(story_page.list, 11)
$game_map.interpreter.busy = true
$sent.clear
$skipping = true
(1..100).each { |number| pass_page.call("Skipped page #{number}") }
skipped = told_pages.call
check("holding the game's skip, the leader tells one page every SKIP_SEND_FRAMES and that they moved past it",
      [skipped.size, skipped.select { |_, kind, _, _| kind == "say" }.map { |_, _, _, line| line }],
      [20, (0..9).map { |tens| "Skipped page #{tens * 10 + 1}" }])
$skipping = false
$game_map.update
told = told_pages.call
check("letting the skip go tells the last page and that the leader moved past it",
      told.last(2).map { |_, kind, page, line| [kind, page == told.last[2], line] }, [["say", true, "Skipped page 100"], ["done", true, nil]])
check("and so at most two messages every SKIP_SEND_FRAMES went out, each end of a page told",
      [told.size <= 2 * (100 / PagesStandIn::SKIP_SEND_FRAMES) + 2, told.select { |_, kind, _, _| kind == "done" }.all? { |_, _, page, _| told.any? { |_, kind, said, _| kind == "say" && said == page } }],
      [true, true])
$sent.clear
$skipping = true
pass_page.call("Kept page")
check("a page kept while skipping waits", told_pages.call, [])
MGQ_MpCoopEvents.finished($game_map.interpreter)
$game_map.interpreter.busy = false
$game_map.update
check("and goes out once the story's event ended", told_pages.call.map { |_, kind, _, line| [kind, line] }, [["say", "Kept page"], ["done", nil]])
$game_map.interpreter.setup(story_page.list, 11)
$game_map.interpreter.busy = true
$sent.clear
pass_page.call("First page of the next event")
pass_page.call("Page before a battle")
SceneManager.scene = Scene_Battle.new
$game_map.update
check("a new telling tells its first page at once, and a page kept goes out once a battle is called",
      told_pages.call.map { |_, kind, _, line| [kind, line] }, [["say", "First page of the next event"], ["done", nil], ["say", "Page before a battle"], ["done", nil]])
SceneManager.scene = Scene_Map.new
$skipping = nil

# Members who follow the story hear each page in one message for the whole party; a member who
# plays their own story ignores it.
third = MGQ_MpOverworldSync::Peers::Peer.new(3, { "id" => "t", "name" => "Third", "party" => "p1" }, nil, true)
fourth = MGQ_MpOverworldSync::Peers::Peer.new(6, { "id" => "v", "name" => "Fourth", "party" => "p1" }, nil, true)
$members = [friend, third, fourth]
$sent.clear
pass_page.call("A page for everyone")
check("a party of four hears each page and its end in one message for all", told_pages.call.map { |seat, kind, _, _| [seat, kind] }, [[-1, "say"], [-1, "done"]])
all_say = $sent.find { |_, f| f["pevent"] == "say" }[1]
$members = [friend]
$leader = MGQ_MpOverworldSync::Peers::Peer.new(4, { "id" => "l", "name" => "Leader", "party" => "p1", "map" => "7" }, nil, true)
$real_sync = true
synced = MGQ_MpCoopStory.instance_variable_get(:@synced)
MGQ_MpCoopStory.instance_variable_set(:@synced, false)
heard = $pages_stand_in.waiting_ids
$log.clear
2.times { MGQ_MpCoopEvents.take($leader, all_say) }
check("a member who plays their own story ignores it, saying so once",
      [$pages_stand_in.waiting_ids, $log.grep(/ignored say from Leader: not synced with the leader/).size], [heard, 1])
MGQ_MpCoopStory.instance_variable_set(:@synced, synced)
$real_sync = nil
$leader = :me
$sent.clear
$game_message.clear
$game_map.interpreter.setup(talk_page.list, 12)
$game_message.add("Just talk")
$game_map.interpreter.wait_for_message
check("a talk's message stays in the leader's game", $sent.select { |_, f| f["pevent"] == "say" }.size, 0)

# A talk that turns into story behind a choice: the leader's tells the party from there, a
# member's ends there.
trader = blacksmith + [Command.new(0, 0, [])]
interpreter = $game_map.interpreter
interpreter.busy = true
interpreter.setup(trader, 0)
interpreter.instance_variable_set(:@index, 3)
MGQ_MpCoopEvents.guard(interpreter)
check("the leader's talk stays a talk while its choice moves nothing on", [MGQ_MpCoopEvents.telling?, interpreter.instance_variable_get(:@index)], [false, 3])
interpreter.instance_variable_set(:@index, 7)
MGQ_MpCoopEvents.guard(interpreter)
check("once its quest step runs, the party hears it as story", [MGQ_MpCoopEvents.telling?, interpreter.instance_variable_get(:@index)], [true, 7])

# A page whose transfer and story lie behind a choice, as the Great Decision's, is travel watched
# as a talk is: the leader tells the story from the choice on, so the transfer takes the others along.
decision = [c(101, "", 0, 0, 2), Command.new(102, 0, [["Not yet", "Decided"], 2]), Command.new(402, 0, [0, "Not yet"]), Command.new(0, 1, []),
            Command.new(402, 0, [1, "Decided"]), Command.new(122, 1, [1007, 1007, 0, 0, 40]), Command.new(201, 1, [0, 430, 25, 20, 8, 0]), Command.new(0, 1, []),
            Command.new(404, 0, []), Command.new(0, 0, [])]
check("a page whose transfer and story lie behind a choice is travel that may turn into story", [kind(decision), MGQ_MpCoopEvents.may_tell?(decision)], [:travel, true])
interpreter.setup(decision, 0)
interpreter.instance_variable_set(:@index, 2)
MGQ_MpCoopEvents.guard(interpreter)
check("it stays travel while its choice moves nothing on", MGQ_MpCoopEvents.telling?, false)
interpreter.instance_variable_set(:@index, 5)
MGQ_MpCoopEvents.guard(interpreter)
check("once the choice moves the story on, the party hears it as story", MGQ_MpCoopEvents.telling?, true)
$leader = leader
$members = [leader]
interpreter.setup(trader, 0)
interpreter.instance_variable_set(:@index, 7)
$flow = []
MGQ_MpCoopEvents.guard(interpreter)
check("a member's talk ends where it would move the story on", [interpreter.instance_variable_get(:@index), $notices.last], [trader.size - 1, "Only Leader can move the story on."])
check("handing the guard of the game's flow the talk's commands from there, which would erase what it showed, such as a companion's portrait (issue #49)",
      $flow, [[:cut, trader.size, 7, "a talk ended where it would move the story on"]])
interpreter.busy = false
$leader = :me
$members = [friend]

# A member sees the leader's dialogue.
$leader = leader
$members = [leader]
$game_message.clear
$game_message.busy = true
MGQ_MpCoopEvents.take(leader, say)
$game_map.update
check("a member busy with a message sees the leader's later", $game_message.texts, [])
$game_message.busy = false
$game_map.update
check("then the leader's message, with what the leader chooses from", [$game_message.face_name, $game_message.texts], ["Alice", ["Hello, \\N[1]!", "Leader chooses: Yes / No"]])

# Only the leader moves the dialogue on.
window = Window_Message.new
$own_pause = nil
pause = Fiber.new { window.process_input; :closed }
pause.resume
pause.resume
check("the member cannot move the leader's page on or close it", [pause.alive?, $own_pause, window.pause], [true, nil, true])
over_asks = lambda { $world_bridge.calls.count { |topic, _| topic == "pages.over" } }
asks = over_asks.call
5.times { $frame_count += 1; pause.resume }
check("a held page asks the DLL nothing more frame by frame while nothing changes", [over_asks.call - asks, window.pause], [0, true])
MGQ_MpCoopEvents.take(leader, { "pevent" => "done", "party" => "p1", "map" => "7", "x" => "0", "y" => "0", "d" => "2", "page" => say["page"] })
check("the leader moving on leaves the page a moment to read", [pause.resume, window.pause], [nil, true])
asks = over_asks.call
5.times { $frame_count += 1; pause.resume }
check("asking again only once that moment passed", over_asks.call - asks, 0)
$frame_count += $pages_stand_in.reading_frames(["Hello, \\N[1]!", "Leader chooses: Yes / No"])
check("then it ends", [pause.resume, window.pause], [:closed, false])
Fiber.new { window.process_input }.resume
check("then the member's own messages wait for their buttons again", $own_pause, true)
MGQ_MpCoopEvents.take(leader, say.merge("page" => "s.0", "lines" => ["Broken page"].pack('m0'), "choices" => ""))
$game_message.clear
$game_map.update
done = MGQ_MpCoopEvents.method(:page_done?)
MGQ_MpCoopEvents.define_singleton_method(:page_done?) { raise ArgumentError, "broken page" }
$own_pause = nil
closed = Fiber.new { window.process_input; :closed }.resume
MGQ_MpCoopEvents.define_singleton_method(:page_done?, done)
check("a page of the leader's story that fails to hold waits for the member as the game's own pages do",
      [$game_message.texts, closed, $own_pause, window.pause, MGQ_MpCoopEvents.mirroring?], [["Broken page"], :closed, true, false, false])
$game_message.clear
$game_message.clear
$game_message.busy = true
(1..5).each do |number|
  MGQ_MpCoopEvents.take(leader, say.merge("page" => "s.#{number}", "lines" => ["Old page #{number}"].pack('m0'), "choices" => ""))
  MGQ_MpCoopEvents.take(leader, { "pevent" => "done", "party" => "p1", "map" => "7", "page" => "s.#{number}" })
end
MGQ_MpCoopEvents.take(leader, say.merge("page" => "s.6", "lines" => ["Current page"].pack('m0'), "choices" => ""))
$game_message.busy = false
$game_map.update
check("a member busy meanwhile shows the pages the leader moved past, the oldest left out past CATCH_UP_PAGES", $game_message.texts, ["Old page 4"])
$confirm = true
check("confirm reads on through a page the leader moved past", MGQ_MpCoopEvents.page_done?, true)
$confirm = nil
MGQ_MpCoopEvents.page_ended
$game_message.clear
$game_map.update
check("then the next page shows, held while it is new", [$game_message.texts, MGQ_MpCoopEvents.page_done?], [["Old page 5"], false])
$skipping = true
check("holding the game's skip passes a page the leader moved past", MGQ_MpCoopEvents.page_done?, true)
$skipping = nil
MGQ_MpCoopEvents.page_ended
$game_message.clear
$game_map.update
check("and the one the leader is on", $game_message.texts, ["Current page"])
leader.state["telling"] = "0"
$frame_count += PagesStandIn::STALE_FRAMES
check("a page ends anyway once the leader stopped telling the story a while ago", MGQ_MpCoopEvents.page_done?, true)
MGQ_MpCoopEvents.page_ended
$game_message.clear

# The leader's story sends no message of what it gives, takes, teaches or sends away: each member
# who follows it gets that by playing the leader's run in their own game (hand_entry).
# A companion's data, their name alone.
Actor = Struct.new(:name)
$data_actors[3] = Actor.new("Alice")
$data_actors[4] = Actor.new("Tamamo")
$game_party = Game_Party.new
$game_party.add_actor(3)
$leader = :me
$members = [friend]
$game_map.interpreter.busy = true
MGQ_MpCoopEvents.instance_variable_set(:@telling, true)
$sent.clear
$game_party.gain_item($data_items[1], 3)
$game_party.gain_gold(-5)
$game_party.remove_actor(3)
$game_party.add_stand_actor(4)
Game_Actor.new.learn_skill(13)
check("the leader's story sends no message of its items, gold, companions or skills, which its runs bring by replay",
      $sent.select { |_, f| f["story"] }, [])
$game_map.interpreter.busy = false
MGQ_MpCoopEvents.finished($game_map.interpreter)
check("the end of the map's main event ends the telling, so a later message, such as a PvP battle's result, is not told",
      MGQ_MpCoopEvents.instance_variable_get(:@telling), false)

# The DLL's one catch-up engine in its Classic settings, its rule of the side and its rule of the
# key item loan (fixtures/catchup/engine.rb), over a Classic party's tables: at step 35 of part 3, a
# skill (13), a weapon (Sword) and a key item (Basement Key) both sides get, a companion (4) both
# sides get, a skill (11) and a companion (5) of Alice's side, a skill (12) and two companions (6,
# 7) of Ilias's side, and a world chest (41:1:A); the World Seed (610), got at step 20 and used up
# at step 36; a skill (14) of Alice's side on the Angelic Dominion at its step 4; a skill (15) at
# step 16 for defeating Lucia in Magistea Village (switch 2097, a choice's outcome); the party chests
# 40:1:A and 40:2:A; taking Alice along brings Little Alice (8), taking Ilias Little Ilias (9).
classic_place = lambda { |site, side| { "site" => site, "part" => "3", "step" => 35, "side" => side, "marks" => [["v", 1001, 35]] } }
classic_join = lambda { |actor, side, index| classic_place.call("map:50:#{actor}:1", side).merge("actor" => actor, "persona" => actor, "gate" => 1, "rule" => "start", "index" => index, "ran" => true) }
CLASSIC_ROWS = {
  "rewards" => [classic_place.call("map:50:1:1", nil).merge("kind" => "skill", "id" => 13, "amount" => 1, "ran" => true),
                classic_place.call("map:50:2:1", nil).merge("kind" => "weapon", "id" => 1, "amount" => 1, "ran" => true),
                classic_place.call("map:50:3:1", "alice").merge("kind" => "skill", "id" => 11, "amount" => 1, "ran" => true),
                classic_place.call("map:50:4:1", "ilias").merge("kind" => "skill", "id" => 12, "amount" => 1, "ran" => true),
                { "site" => "map:432:9:1", "part" => "ad", "step" => 4, "side" => "alice", "marks" => [["v", 1141, 4]], "kind" => "skill", "id" => 14, "amount" => 1, "ran" => true },
                { "site" => "map:16:1:1", "part" => "1", "step" => 16, "side" => nil, "marks" => [["v", 1001, 16], ["s", 2097]], "kind" => "skill", "id" => 15, "amount" => 1, "ran" => true }],
  "key_items" => [classic_place.call("map:50:5:1", nil).merge("item" => 3, "amount" => 1, "ran" => true),
                  { "site" => "map:20:1:1", "part" => "2", "step" => 20, "side" => nil, "marks" => [["v", 1001, 20]], "item" => 610, "amount" => 1, "ran" => true },
                  { "site" => "map:36:1:1", "part" => "3", "step" => 36, "side" => nil, "marks" => [["v", 1001, 36]], "item" => 610, "amount" => -1, "ran" => true }],
  "joins" => [classic_join.call(4, nil, 1), classic_join.call(5, "alice", 2), classic_join.call(6, "ilias", 3), classic_join.call(7, "ilias", 4)],
  "chests" => [{ "key" => "ss41.1.A", "items" => [501], "part" => "3", "step" => 35 }],
  "party_chests" => [{ "key" => "ss40.1.A" }, { "key" => "ss40.2.A" }],
  "rules" => [{ "rule" => "side_step", "value" => 7 }, { "rule" => "side_companions", "value" => { "alice" => 8, "ilias" => 9 } }],
}
classic_tables = CatchupEngine.read(CLASSIC_ROWS)
$classic_rows = CLASSIC_ROWS
$data_items[610] = RPG::Item.new(610, "World Seed")
$data_items[610].key = true
answer_classic.call("catchup.classic") do |request|
  noted = {}
  [CatchupEngine.classic(classic_tables, request, classic_party(noted)), noted]
end
answer_classic.call("catchup.side") { |request| CatchupEngine.side(classic_tables, request) }
answer_classic.call("catchup.key_loan") { |request| CatchupEngine.key_loan(request) }
answer_classic_keys = lambda { $world_bridge.answer("catchup.keys") { |_request| CatchupEngine.keys(classic_tables) } }

# Plays a member's game until the party ends, from their own story to the leader's.
#
# @param own_progress [Integer] The member's main story progress, variable 1001.
# @return [Array] The notice on joining, the member's switches and variables once back in their own
#   story, and what a save made in the party held.
def play_along(own_progress)
  $game_party = Game_Party.new
  $game_party.add_actor(3)
  $game_switches = Game_Switches.new
  $game_variables = Game_Variables.new
  $game_self_switches = Game_SelfSwitches.new
  $game_switches[80] = true
  $game_variables[1001] = own_progress
  $party = "p1"
  $leader = $story_leader
  $members = [$story_leader]
  $notices.clear
  MGQ_MpCoopStory.update
  MGQ_MpCoopStory.take($story_leader, { "story" => "full", "party" => "p1", "s" => "81", "v" => "1001:n40", "ss" => "" })
  joined = $notices.last
  MGQ_MpCoopStory.take($story_leader, { "story" => "delta", "party" => "p1", "s" => "82:1", "v" => "1001:n41", "ss" => "" })
  $game_variables[151] = 7
  $game_switches[90] = true
  MGQ_MpCoopStory.take($story_leader, { "story" => "keys", "party" => "p1", "k" => "3:1" })
  $key_in_party = $game_party.items["Basement Key"]
  save = MGQ_MpCoopStory.save_contents(:switches => $game_switches, :variables => $game_variables, :self_switches => $game_self_switches, :party => $game_party)
  saved = [save[:switches][82], save[:variables][1001], save[:variables][151], save[:party].items["Basement Key"]]
  $party = nil
  $leader = nil
  $members = []
  MGQ_MpCoopStory.update
  [joined, $game_switches, $game_variables, saved]
end

# A member as far along as the leader keeps what they play together once the party ends.
$story_leader = leader
joined, switches, variables, saved = play_along(40)
check("a member as far along hears they keep what they play together", joined,
      "You follow Leader's story while in the party. You are as far along, so you keep what you play together.")
check("once the party ends they keep the story played together, not what the leader had before",
      [switches[80], switches[81], switches[82], variables[1001]], [true, false, true, 41])
check("and what changed in their own game meanwhile", [switches[90], variables[151]], [true, 7])
check("a save made in the party holds it too", saved, [true, 41, 7, 0])

joined, switches, variables, saved = play_along(30)
check("a member behind the leader hears they catch up and keep what they play together", joined,
      "You follow Leader's story while in the party. You catch up with it and keep what you play together.")
check("once the party ends they keep the leader's story, what the leader had before included, and their own switch the leader never set",
      [switches[80], switches[81], switches[82], variables[1001]], [true, true, true, 41])
check("and what changed in their own game meanwhile, in a save made in the party too", [switches[90], variables[151], saved], [true, 7, [true, 41, 7, 0]])

joined, switches, variables, saved = play_along(50)
check("a member ahead of the leader keeps none of the leader's story", [switches[80], switches[82], variables[1001], switches[90], variables[151]], [true, false, 50, false, 0])
check("nor its items, gold or companions", [$game_party.items["Potion"], $game_party.gold, $game_party.include_actors], [0, 0, [3]])
check("but the story's key item is lent while they play along, and left out of a save", [$key_in_party, saved[3]], [1, 0])
check("and goes back once the party ends", [$game_party.items["Basement Key"], $notices.include?("Leader lent you Basement Key for the story."),
                                             $notices.include?("Basement Key went back to the party's leader.")], [0, true, true])

# The Pocket Castle shows the party leader's residents: the leader is its Map Owner, and a
# resident only the leader's game shows stands as a ghost in the member's.
module MGQ_MpOverworld
  # Tiles a ghost walks to catch up.
  CATCH_UP_TILES = 3
  # Opacity of the ghost of a player outside the party.
  STRANGER_OPACITY = 150
end
# Stands in for coop_npcs.rbx: whether the map's events follow another game's, from
# $following_npcs, and where they stand there, from $npc_targets.
module MGQ_MpCoopNpcs
  def self.following?; $following_npcs; end
  def self.targets; $npc_targets; end
  def self.page_of(event, index); event && index >= 0 ? event.mgq_mp_pages[index] : nil; end
end
# An event page's graphic.
Graphic = Struct.new(:tile_id, :character_name, :character_index, :direction, :pattern)
# A resident's event page.
ResidentPage = Struct.new(:graphic, :priority_type, :walk_anime, :step_anime, :move_speed, :list)
empty_page = ResidentPage.new(Graphic.new(0, "", 0, 2, 0), 0, true, false, 3, [])
tamamo_page = ResidentPage.new(Graphic.new(0, "tamamo", 1, 2, 1), 1, true, false, 3, [])
$party = "p1"
$leader = leader
$members = [leader]
$game_map = Game_Map.new
$game_map.map_id = 228
check("the leader is the castle's Map Owner while there", [MGQ_MpCoopCastle.owner([leader]), MGQ_MpCoopCastle.owner([])], [leader, nil])
$game_map.map_id = 7
check("elsewhere the Map Owner is whoever came first", MGQ_MpCoopCastle.owner([leader]), nil)
$game_map.map_id = 228
not_mine = Game_Event.new(31, [empty_page, tamamo_page])
mine = Game_Event.new(32, [empty_page, tamamo_page])
mine.show(1)
mine.character_name = "tamamo"
only_mine = Game_Event.new(33, [empty_page, tamamo_page])
only_mine.show(1)
only_mine.character_name = "tamamo"
$game_map.events = { 31 => not_mine, 32 => mine, 33 => only_mine }
$following_npcs = true
$npc_targets = { 31 => [5, 6, 2, 1], 32 => [7, 6, 2, 1], 33 => [9, 6, 2, 0] }
MGQ_MpCoopCastle.update
ghost = MGQ_MpCoopCastle.ghosts[31]
check("a companion only the leader has stands as a ghost where the leader's does", [MGQ_MpCoopCastle.ghosts.keys, ghost && [ghost.x, ghost.y, ghost.character_name]],
      [[31], [5, 6, "tamamo"]])
check("see-through, as players outside the party", ghost.opacity, MGQ_MpOverworld::STRANGER_OPACITY)
$npc_targets[31] = [6, 6, 4, 1]
MGQ_MpCoopCastle.update
check("and walks where the leader's walks", [ghost.x, ghost.y], [6, 6])
not_mine.show(1)
not_mine.character_name = "tamamo"
MGQ_MpCoopCastle.update
check("once the player has that companion too, the ghost goes and their own shows", MGQ_MpCoopCastle.ghosts, {})
$game_map.map_id = 7
MGQ_MpCoopCastle.update
check("off the castle there are no ghosts", MGQ_MpCoopCastle.ghosts, {})

# Key items lent through everything that can go wrong: the leader's key items reach the member with
# the story and whenever they change, so a load, a crash or a duel lends them again; what the story
# gives during a duel or before the story is borrowed again waits.
key = $data_items[3]
$story_leader = leader
$party = "p1"
$leader = leader
$members = [leader]
$game_map = Game_Map.new
$game_party = Game_Party.new
$game_switches = Game_Switches.new
$game_variables = Game_Variables.new
$game_self_switches = Game_SelfSwitches.new
$game_variables[1001] = 50
MGQ_MpCoopStory.forget
$notices.clear
full_story ={ "story" => "full", "party" => "p1", "s" => "", "v" => "1001:n40", "ss" => "", "k" => "3:1" }
MGQ_MpCoopStory.take(leader, full_story)
check("a member ahead of the leader borrows the leader's key items with the story", [$game_party.items["Basement Key"], $notices.last],
      [1, "Leader lent you Basement Key for the story."])
MGQ_MpCoopStory.take(leader, full_story)
check("hearing them again lends nothing more", $game_party.items["Basement Key"], 1)

# The member loads a save, or comes back after a crash: no save holds the key.
saved = MGQ_MpCoopStory.save_contents(:switches => $game_switches, :variables => $game_variables, :self_switches => $game_self_switches, :party => $game_party)
check("a save made meanwhile leaves the key out", saved[:party].items["Basement Key"], 0)
$game_party = saved[:party]
$game_switches, $game_variables, $game_self_switches = saved[:switches], saved[:variables], saved[:self_switches]
DataManager.extract_save_contents({})
check("so a loaded save has no key, and the member plays their own story", [$game_party.items["Basement Key"], MGQ_MpCoopStory.guest?], [0, false])
MGQ_MpCoopStory.take(leader, full_story)
check("once they play it again, the key is lent again", $game_party.items["Basement Key"], 1)

# A duel puts the game back as it was before it.
$pvp = true
before_duel = MGQ_MpCoopStory.save_contents(:switches => $game_switches, :variables => $game_variables, :self_switches => $game_self_switches, :party => $game_party)
MGQ_MpCoopEvents.take_entry(friend = MGQ_MpOverworldSync::Peers::Peer.new(2, { "id" => "f", "name" => "Friend", "party" => "p1" }, nil, true),
                            { "replay" => "WIRE:x3", "party" => "p1" })
check("a chest another member opens during a duel waits", [MGQ_MpStoryReplay.free?, MGQ_MpStoryReplay.waiting.map { |entry| entry["id"] }], [false, ["x3"]])
$game_party = before_duel[:party]
$game_switches, $game_variables, $game_self_switches = before_duel[:switches], before_duel[:variables], before_duel[:self_switches]
DataManager.extract_save_contents({})
$pvp = false
check("putting the game back after the duel took the key along", $game_party.items["Basement Key"], 0)
SceneManager.scene = Scene_Map.new
check("then the player's game may play it", MGQ_MpStoryReplay.free?, true)
MGQ_MpStoryReplay.waiting.clear
MGQ_MpCoopStory.take(leader, full_story)
check("and the key is lent again once the member plays the story again", $game_party.items["Basement Key"], 1)

# The leader leaves while the member is in a battle: the key goes back once the member is on the map.
$members = []
$leader = nil
$party = nil
check("in a battle the key stays, since the map does not run", $game_party.items["Basement Key"], 1)
$game_map.update
check("back on the map it goes back", [$game_party.items["Basement Key"], $notices.include?("Basement Key went back to the party's leader.")], [0, true])

# All at once: lent, in a duel, the leader gives more, the member loads a save, then the leader is gone.
$party = "p1"
$leader = leader
$members = [leader]
MGQ_MpCoopStory.forget
MGQ_MpCoopStory.take(leader, full_story)
$pvp = true
MGQ_MpCoopStory.take(leader, { "story" => "keys", "party" => "p1", "k" => "3:1,2:1" })
$game_party = Game_Party.new
DataManager.extract_save_contents({})
$pvp = false
$party = nil
$leader = nil
$members = []
$game_map.update
check("all at once, the member ends up with none of the leader's keys and nothing held back", [$game_party.items["Basement Key"], MGQ_MpCoopStory.instance_variable_get(:@held)],
      [0, nil])

# The leader tells the key items they hold, which the game lists as the items themselves.
class Game_Party; def items; items_held; end; end
$party = "p1"
$leader = :me
$members = [friend]
$game_party = Game_Party.new
$game_party.gain_item(key, 1)
$sent.clear
MGQ_MpCoopStory.take(friend, { "story" => "ask", "party" => "p1" })
check("the leader's story carries the key items they hold", $sent.last[1]["k"], "3:1")

# The whole story waits for the rewards a member catches up with, which come with the story mapping;
# while they are missing, the scripts ask the DLL for them only every half second.
reward_asks = 0
$world_bridge.answer("story.rewards") { |_known| reward_asks += 1; nil }
rewards_changed
$sent.clear
2.times { MGQ_MpCoopStory.take(friend, { "story" => "ask", "party" => "p1" }) }
check("the leader leaves an ask for the whole story unanswered until the rewards a member catches up with came, asking the DLL once within half a second",
      [$sent, reward_asks], [[], 1])
answer_party_rewards($world_bridge)
$frame_count += MGQ_MpStoryState::MISSING_FRAMES
MGQ_MpCoopStory.take(friend, { "story" => "ask", "party" => "p1" })
$frame_count -= MGQ_MpStoryState::MISSING_FRAMES
check("and answers it once they came", $sent.map { |_, fields| fields["story"] }, ["full"])
MGQ_MpCoopStory.instance_variable_set(:@frames, MGQ_MpCoopStory::SEND_FRAMES)
$sent.clear
MGQ_MpCoopStory.update
check("and the leader tells them again whenever they change", $sent.select { |_, f| f["story"] == "keys" }.map { |_, f| f["k"] }, ["3:1"])
$game_party.gain_item(key, -1)
MGQ_MpCoopStory.instance_variable_set(:@frames, MGQ_MpCoopStory::SEND_FRAMES)
$sent.clear
MGQ_MpCoopStory.update
check("such as when the story takes one", $sent.select { |_, f| f["story"] == "keys" }.map { |_, f| f["k"] }, [""])

# A member who keeps the story catches up with the story's skills, companions and items the leader
# holds, those of their own side where the sides differ; one without a side chooses first.
# Stands in for the relay's rewards tables.
module MGQ_MpCoopStoryRewards
  # The skills Luka learns in events.
  SKILLS = [11, 12, 13]
  # The companions who join in events.
  ACTORS = [4, 5, 6, 7, 8, 9]
  # How many of each item the story's events give at most.
  ITEMS = { "w1" => 1 }
  # The skills and companions only the events where the sides differ give.
  SIDED = { :skills => [11, 12], :actors => [5, 6, 7, 8, 9] }
  # The Great Decision brings Ilias with the route.
  ROUTE = { :skills => [], :actors => [5] }
  # The self switch of every chest.
  CHESTS = [[40, 1, "A"], [40, 2, "A"]]
  # The events where the sides differ.
  GROUPS = [
    # Training at a camp: each side learns its own skill, and nothing in the story tells it ran.
    { :alice => { :skills => [11], :actors => [] }, :ilias => { :skills => [12], :actors => [] }, :choice => false, :marks => [] },
    # A council: each side gets other companions, and it leaves switch 120 on.
    { :alice => { :skills => [], :actors => [5] }, :ilias => { :skills => [], :actors => [6] }, :choice => false, :marks => [[[:s, 120]]] },
    # A shrine where only Ilias's side gets a companion, past which variable 1076 is at least 5.
    { :alice => { :skills => [], :actors => [] }, :ilias => { :skills => [], :actors => [7] }, :choice => false, :marks => [[[:v, 1076, 5]]] },
    # Where the player takes Alice or Ilias along.
    { :alice => { :skills => [], :actors => [8] }, :ilias => { :skills => [], :actors => [] }, :choice => true, :marks => [[[:v, 1001, 7]]] },
    { :alice => { :skills => [], :actors => [] }, :ilias => { :skills => [], :actors => [9] }, :choice => true, :marks => [[[:v, 1001, 7]]] },
  ]
end
rewards_changed
# A skill's data.
Skill = Struct.new(:id, :name)
$data_skills = Array.new(14)
$data_skills[11] = Skill.new(11, "Demon Decapitation")
$data_skills[12] = Skill.new(12, "Angel Dance")
$data_skills[13] = Skill.new(13, "Sylph")
$data_skills[14] = Skill.new(14, "Death Sword Chaos Star")
$data_skills[15] = Skill.new(15, "Thunder Thrust")
{ 5 => "Ilias", 6 => "Alicetroemeria", 7 => "Eden", 8 => "Little Alice", 9 => "Little Ilias" }.each { |id, name| $data_actors[id] = Actor.new(name) }
# Luka, who learns skills.
class Hero < Game_Actor
  attr_reader :skills, :name
  def initialize; @skills = []; @abilities = {}; @name = "Luka"; end
  def skill_learn?(skill); @skills.include?(skill.id); end
end
class Game_Party; def all_members; []; end; end
class Game_Message; attr_accessor :choice_cancel_type, :choice_proc; end

# Starts a member's game anew, at their own main story progress.
#
# @param progress [Integer] Variable 1001.
# @param side [Integer, nil] The side's switch, nil for none chosen.
def member_game(progress, side = nil)
  $game_party = Game_Party.new
  $game_actors = [nil, Hero.new]
  $game_switches = Game_Switches.new
  $game_variables = Game_Variables.new
  $game_self_switches = Game_SelfSwitches.new
  $game_message = Game_Message.new
  $game_map = Game_Map.new
  $game_system = Object.new
  $game_variables[1001] = progress
  $game_switches[side] = true if side
  $party = "p1"
  $leader = $story_leader
  $members = [$story_leader]
  $notices.clear
  MGQ_MpCoopStory.forget
  MGQ_MpCoopStory.update
end

# Counts an item the member holds, by its name.
#
# @param name [String] The item's name.
# @return [Integer] How many.
def held(name)
  $game_party.instance_variable_get(:@items)[name]
end

SceneManager.scene = Scene_Map.new
holdings = { "side" => "a" }
behind_story = { "story" => "full", "party" => "p1", "s" => "120", "v" => "1001:n40,1076:n5", "ss" => "" }.merge(holdings)

# The DLL's catch-up by the frozen rows, its engine in the Classic settings over the tables above.
answer_classic_keys.call
check("the side each player chose is their own as the reviewed list keeps it, before the Great Decision and after it",
      [4, 5].map { |id| [MGQ_MpStoryState.personal_switch?(id, []), MGQ_MpStoryState.personal_switch?(id, [0] * 1141 + [2])] }, [[true, true], [true, true]])
# A key item a party chest gave the leader comes by playing that chest in the member's own game.
$key_chests = { [40, 1, "A"] => [3] }
$world_bridge.answer("story.replay_derive") { |request| { "id" => "derived:#{request['chest']}", "site" => request["chest"] == "ss40.1.A" ? "map:40:1:1" : request["chest"] } }
member_game(30)
MGQ_MpCoopStory.take(leader, behind_story.merge("ss" => "40.1.A"))
check("a key item the leader's chest gave comes by playing that chest in the member's game, not as a gift",
      [held("Basement Key"), MGQ_MpStoryReplay.waiting.map { |entry| entry["site"] }, $notices.include?("You got Sword to catch up with Leader's story.")], [0, ["map:40:1:1"], true])
MGQ_MpStoryReplay.waiting.clear
$key_chests = {}
$world_bridge.answer("story.replay_derive") { |_request| nil }

# The World Seed the leader's story used up (step 36) goes from a member behind who holds it, with no
# notice; one who never held it loses nothing (user answer 2026-11-01).
member_game(30)
$game_party.gain_item($data_items[610], 1)
MGQ_MpCoopStory.take(leader, behind_story)
check("a member behind who holds the World Seed the leader's story used up loses it, with no notice of it",
      [held("World Seed"), $notices.grep(/World Seed/)], [0, []])

member_game(30)
MGQ_MpCoopStory.take(leader, behind_story.merge("ss" => "41.1.A"))
check("a member behind without a side catches up with the rows both sides pass, as the DLL finds them from both stories",
      [$game_actors[1].skills, $game_party.include_actors, classic_asks.last["before"]["v"], classic_asks.last["leader"]["v"], classic_asks.last["pick"]],
      [[13], [4], [[1001, 30]], [[1001, 40]], nil])
check("and the world chest the leader's story opened plays in the member's own game",
      $world_bridge.calls.select { |topic, _| topic == "story.replay_derive" }.map { |_, bytes| Marshal.load(bytes)["chest"] }.include?("ss41.1.A"), true)
check("and with the rows' items and key items, never a copy of what the leader holds", [held("Sword"), held("Basement Key"), held("Potion")], [1, 1, 0])
check("with notices", $notices.include?("Luka learned Sylph to catch up with Leader's story.") && $notices.include?("You got Sword and Basement Key to catch up with Leader's story."), true)
MGQ_MpCoopStory.update
check("once free on the map, the member without a side chooses one, as soon as their own story is past Iliasville", [$game_message.texts.last, $game_message.choices, $game_message.choice_cancel_type],
      ["Your story went past the choice of whom you take along. Whom do you take along on your journey?", ["Alice", "Ilias"], 0])
$game_message.choice_proc.call(1)
check("taking Ilias brings the companion the choice brings into the party", [$game_switches[5], $game_switches[4], $game_party.actors], [true, false, [9]])
check("and the rows of Ilias's side the leader's story got past, nothing of the first catch-up twice", [$game_actors[1].skills, $game_party.include_actors, classic_asks.last["pick"], held("Sword")],
      [[13, 12], [4, 9, 6, 7], "ilias", 1])
MGQ_MpCoopStory.take(leader, behind_story)
check("hearing it again gives nothing more", [$game_actors[1].skills, $game_party.include_actors, held("Sword")], [[13, 12], [4, 9, 6, 7], 1])
check("the leader's story never takes the member's side", [$game_switches[5], $game_switches[4]], [true, false])

member_game(30, 4)
MGQ_MpCoopStory.take(leader, behind_story)
check("a member on the leader's side gets what the leader got", [$game_actors[1].skills.sort, $game_party.include_actors], [[11, 13], [4, 5]])
check("and is not asked", ($game_message.choices || []).empty?, true)

derives = lambda { $world_bridge.calls.count { |topic, bytes| topic == "story.replay_derive" && Marshal.load(bytes)["chest"] == "ss41.1.A" } }
before = derives.call
member_game(36)
MGQ_MpCoopStory.take(leader, behind_story.merge("v" => "1001:n40", "ss" => "41.1.A"))
check("a member whose own story is past a world chest's step without opening it keeps it shut", derives.call, before)

# A member whose save came from another player's starting save past Iliasville holds that player's
# side, so they are asked whom they take along; the save notes the answer, and the companion of the
# other side the starting save brought leaves them, as the DLL finds it.
$game_system = Object.new
member_game(30, 4)
MGQ_MpStoryState.note_other_start
$game_party.add_stand_actor(8)
answer_scope { |request| { "allowed" => request["pick"] == "ilias" ? request["actors"] - [8] : request["actors"] } }
MGQ_MpCoopStory.take(leader, behind_story)
check("a member from another player's starting save catches up with neither side's rows before they answer, not with the side their switches hold",
      [$game_actors[1].skills, $game_party.include_actors.sort, classic_asks.last["pick"]], [[13], [4, 8], ""])
MGQ_MpCoopStory.update
check("a member from another player's starting save is asked whom they take along", [$game_message.texts.last, $game_message.choices],
      ["Leader took Alice along. Whom do you take along on your own journey?", ["Alice", "Ilias"]])
$game_message.choice_proc.call(1)
check("and taking Ilias is noted in the save, turns their side switch to Ilias and lets the Alice side's companion go",
      [MGQ_MpStoryState.pick_note, $game_switches[4], $game_switches[5], $game_party.include_actors.include?(8), $game_party.include_actors.include?(9), $notices.include?("Little Alice left you.")],
      ["ilias", false, true, false, true, true])
check("and catches up with Ilias's rows the leader's story is past, never Alice's",
      [$game_actors[1].skills.sort, ($game_party.include_actors & [5, 6, 7]).sort], [[12, 13], [6, 7]])
$world_bridge.answer("catchup.scope") { |_request| nil }

# A member from another player's starting save who joins a leader on the Chaos route has no side of
# their own: the strategy conference's companions go by the side switches of the story played,
# as the game's own event reads them, until the member answers whom they take along, which notes
# the side and leaves the route's side switches alone.
$game_system = Object.new
member_game(30, 4)
MGQ_MpStoryState.note_other_start
scope_held = []
answer_scope { |request| scope_held << request; { "allowed" => request["pick"] == "" && request["held"] == "alice" ? request["actors"] : [] } }
MGQ_MpCoopStory.take(leader, behind_story.merge("s" => "4,120", "v" => "1001:n40,1143:n1"))
refused = MGQ_MpCoopStory.refuses_join?(26, "map:437:11:1")
check("a member without a side of their own on the Chaos route gets the conference's companions by the side switches of the story played",
      [refused, scope_held.last["pick"], scope_held.last["held"]], [false, "", "alice"])
MGQ_MpCoopStory.update
check("and is asked whom they take along though the leader is past the Great Decision", [$game_message.texts.last, $game_message.choices],
      ["Your story went past the choice of whom you take along. Whom do you take along on your journey?", ["Alice", "Ilias"]])
$game_message.choice_proc.call(1)
check("the answer is noted in the save, and the route's side switches stay", [MGQ_MpStoryState.pick_note, $game_switches[4], $game_switches[5]], ["ilias", true, false])
$world_bridge.answer("catchup.scope") { |_request| nil }
$game_system = nil

# A player alone in a Classic world whose save came from another player's starting save past
# Iliasville is asked too, with no leader to follow.
$game_system = Object.new
member_game(30, 4)
MGQ_MpStoryState.note_other_start
$party = nil
$leader = nil
$members = []
MGQ_MpCoopStory.update
check("a player alone from another player's starting save is asked whom they take along", [$game_message.texts.last, $game_message.choices],
      ["Your story went past the choice of whom you take along. Whom do you take along on your journey?", ["Alice", "Ilias"]])
$game_message.choice_proc.call(1)
check("and taking Ilias turns their side switch to Ilias", [MGQ_MpStoryState.pick_note, $game_switches[4], $game_switches[5]], ["ilias", false, true])
$game_system = nil

# A player alone whose own story is before the choice in Iliasville is not asked.
$game_system = Object.new
member_game(5)
$party = nil
$leader = nil
$members = []
MGQ_MpCoopStory.update
check("a player alone before the choice in Iliasville is not asked whom they take along", ($game_message.choices || []).empty?, true)
$game_system = nil

# The side's rules come with the story mapping: a player alone whom the rule could not judge before
# they came is asked once they came, though nothing the rule reads changed.
member_game(30, 4)
MGQ_MpStoryState.note_other_start
$party = nil
$leader = nil
$members = []
$classic_rows = {}
answer_classic.call("catchup.side") { |request| CatchupEngine.side(CatchupEngine.read({}), request) }
MGQ_MpCoopStory.update
check("a player alone from another player's starting save is not asked while the side's rules have not come", ($game_message.choices || []).empty?, true)
$classic_rows = CLASSIC_ROWS
answer_classic.call("catchup.side") { |request| CatchupEngine.side(classic_tables, request) }
$frame_count += MGQ_MpCoopStory::SIDE_RETRY_FRAMES
MGQ_MpCoopStory.update
$frame_count -= MGQ_MpCoopStory::SIDE_RETRY_FRAMES
check("but within a second once they came, though nothing the rule reads changed", [$game_message.texts.last, $game_message.choices],
      ["Your story went past the choice of whom you take along. Whom do you take along on your journey?", ["Alice", "Ilias"]])
$game_message.choice_proc.call(0)
$game_system = nil

# The leader bought the Noble Orb (job item 662) from the Medal King, whose exchange turns switch
# 2336 on. His run is never replayed: a member whose story holds 2336 and who holds no Noble Orb
# gets it by the DLL's one rule of his gift (MedalKingGift), once, and the save notes the switch
# looked at, so a Noble Orb the member uses later does not come back.
$data_items[662] = RPG::Item.new(662, "Noble Orb")
gift_asks = []
$world_bridge.answer("catchup.keys") { |_request| { "switches" => [4, 5, 120, 2336], "variables" => [1001, 1076, 1141, 1143], "selves" => [[40, 1, "A"]], "items" => [] } }
$world_bridge.answer("catchup.medal_king") do |request|
  gift_asks << request
  next { "switches" => [2336], "items" => ["i662"] } unless request["story"]

  { "gifts" => request["items"]["i662"] == 0 ? [["i", 662, 1]] : [], "handled" => request["handled"] | [2336] }
end
$game_system = Object.new
member_game(30)
look_for_gifts = lambda { MGQ_MpCoopStory::GIFT_FRAMES.times { MGQ_MpCoopStory.update } }
look_for_gifts.call
asked = gift_asks.size
$game_switches[2336] = true
look_for_gifts.call
check("a party member whose story holds the Noble Orb's exchange gets the Noble Orb, which the save notes",
      [asked, gift_asks.last["story"]["s"].include?(2336), held("Noble Orb"), $notices.last, $game_system.instance_variable_get(MGQ_MpCoopStory::GIFTS_FIELD)],
      [1, true, 1, "The Medal King gave you Noble Orb.", [2336]])
$game_party.gain_item($data_items[662], -1)
look_for_gifts.call
check("and does not get it again once it is used", [held("Noble Orb"), gift_asks.size], [0, asked + 1])
$game_system = nil
answer_classic_keys.call

# A companion of the Alice and Ilias choice the DLL finds the member has no right to stays away; it
# is asked with the side the member took along and the routes they played.
scope_asks = []
answer_scope { |request| scope_asks << request; { "allowed" => request["actors"] - [5] } }
member_game(30, 4)
MGQ_MpCoopStory.take(leader, behind_story)
check("the rows are read with the side the member took along", classic_asks.last["pick"], "alice")

# A member on the Angelic Dominion, whose switch 4 the route's reset turned on (map 432), and whose
# save notes no side taken along in Iliasville, is asked about with no side: Groys and Lilith &
# Lilim, whom only Alice pickers get, stay away.
$data_actors[406] = Actor.new("Groys")
$data_actors[341] = Actor.new("Lilith & Lilim")
answer_scope do |request|
  scope_asks << request
  { "allowed" => request["pick"] == "alice" ? request["actors"] : request["actors"] - [406, 341] }
end
member_game(40, 4)
$game_variables[1141] = 2
MGQ_MpCoopStory.take(leader, behind_story.merge("s" => "4,120", "v" => "1001:n40,1076:n5,1141:n5"))
check("a member on a route whose save notes no side taken along has the rows read with no side: no row of Alice's side the leader's route passed, though their switch 4 is on",
      [classic_asks.last["pick"], $game_actors[1].skills], [nil, []])
$world_bridge.answer("catchup.scope") { |_request| nil }

member_game(30, 5)
part3 = behind_story.merge("s" => "4,120", "v" => "1001:n40,1076:n5,1141:n2")
MGQ_MpCoopStory.take(leader, part3)
check("after the Great Decision a member still gets their own side's rows of the events before it",
      [$game_actors[1].skills.sort, $game_party.include_actors], [[12, 13], [4, 6, 7]])
check("and the member plays the side of the leader's route", [$game_switches[4], $game_switches[5]], [true, false])
$party = nil
$leader = nil
$members = []
MGQ_MpCoopStory.update
check("which they keep, having caught up with it", [$game_switches[4], $game_switches[5]], [true, false])
member_game(50, 5)
MGQ_MpCoopStory.take(leader, part3.merge("v" => "1001:n40,1141:n2"))
$party = nil
$leader = nil
$members = []
MGQ_MpCoopStory.update
check("a member ahead gets their own side back", [$game_switches[4], $game_switches[5]], [false, true])

member_game(40, 5)
asked = classic_asks.size
MGQ_MpCoopStory.take(leader, behind_story)
check("a member as far along gets nothing of events the story got past", [$game_actors[1].skills, $game_party.include_actors, held("Sword"), classic_asks.size], [[], [], 0, asked])
MGQ_MpCoopStory.take(leader, { "story" => "hold", "party" => "p1" }.merge(holdings))
check("nor anything later, which the leader's runs bring by replay", [$game_actors[1].skills, $game_party.include_actors], [[], []])

member_game(50, 5)
MGQ_MpCoopStory.take(leader, behind_story)
check("a member ahead catches up with nothing", [$game_actors[1].skills, $game_party.include_actors, held("Sword")], [[], [], 0])

# The history from before the log: the closures of keys of the member's own the leader's story
# holds come as derived entries, each played once in the member's own game, its choices answered
# by the leader's letters of the event; the leader's world keys come by value.
derived = []
$world_bridge.answer("story.replay_derive") do |request|
  derived << [request["chest"], request["letters"]]
  { "id" => "derived:#{request['chest']}", "site" => request["chest"] }
end
$world_bridge.answer("story.replay_scopes") do |request|
  found = classic_scopes
  found["self"] = { "ss50.*.*" => MGQ_MpStoryKeys::SCOPE_PLAYER } if request["party"]
  found
end
MGQ_MpStoryKeys.instance_variable_set(:@scopes, nil)
member_game(30, 5)
$game_self_switches[[50, 4, "A"]] = true
MGQ_MpCoopStory.update
MGQ_MpCoopStory.take(leader, behind_story.merge("ss" => "50.3.A,50.3.B,50.4.A,9.9.A"))
check("a member behind gets the leader's closures of their own keys they lack as derived entries, answered by the leader's letters",
      [derived, MGQ_MpStoryReplay.waiting.map { |entry| entry["id"] }, $game_self_switches[[50, 3, "A"]], $game_self_switches[[9, 9, "A"]]],
      [[["ss50.3.A", %w(A B)], ["ss50.3.B", %w(A B)]], ["derived:ss50.3.A", "derived:ss50.3.B"], false, true])
MGQ_MpCoopStory.take(leader, behind_story.merge("ss" => "50.3.A,50.3.B,50.5.A"))
member_game(40, 5)
MGQ_MpCoopStory.take(leader, behind_story.merge("v" => "1001:n40", "ss" => "50.6.A"))
check("the leader's later whole story derives nothing again, nor does a member as far along get any",
      [derived.size, MGQ_MpStoryReplay.waiting.size], [2, 2])
MGQ_MpStoryReplay.waiting.clear
$world_bridge.answer("story.replay_scopes") { |request| request["party"] ? classic_scopes : nil }
MGQ_MpStoryKeys.instance_variable_set(:@scopes, nil)

# The leader tells what of the story's rewards they hold, and their side.
MGQ_MpCoopStory.forget
$leader = :me
$members = [friend]
$game_party = Game_Party.new
$game_actors = [nil, Hero.new]
$game_actors[1].learn_skill(11)
$game_party.add_stand_actor(5)
$game_party.gain_item($data_weapons[1], 1)
$game_switches = Game_Switches.new
$game_variables = Game_Variables.new
$game_switches[4] = true
MGQ_MpCoopStory.instance_variable_set(:@frames, MGQ_MpCoopStory::SEND_FRAMES)
MGQ_MpCoopStory.instance_variable_set(:@sent_held, nil)
$sent.clear
MGQ_MpCoopStory.update
told = $sent.find { |_, f| f["story"] == "hold" }
check("the leader tells their side, and nothing of what they hold", told && [told[1]["side"], told[1].key?("sk"), told[1].key?("it")], ["a", false, false])

# The catch-up's edge cases: the side after the Great Decision, the member's own side quests, the
# leader's companions outside the story, a companion let go, and equipment at the castle.
$data_actors[10] = Actor.new("Morrigan")
morrigan = holdings

member_game(30, 5)
MGQ_MpCoopStory.take(leader, behind_story)
MGQ_MpCoopStory.take(leader, { "story" => "delta", "party" => "p1", "s" => "", "v" => "1141:n2", "ss" => "" })
check("the route's progress arriving alone makes the member play the side of the leader's route", [$game_switches[4], $game_switches[5]], [true, false])
check("and gives nothing of the leader's side on top", [$game_actors[1].skills.sort, $game_party.include_actors.include?(5)], [[12, 13], false])
MGQ_MpCoopStory.take(leader, { "story" => "hold", "party" => "p1" }.merge(holdings))
check("nor does the leader's next holdings", [$game_actors[1].skills.sort, $game_party.include_actors.include?(5)], [[12, 13], false])

member_game(30, 5)
$game_switches[300] = true
$game_switches[301] = true
$game_variables[1500] = 3
$game_self_switches[[9, 9, "A"]] = true
$game_self_switches[[9, 9, "B"]] = true
MGQ_MpCoopStory.update
MGQ_MpCoopStory.take(leader, behind_story.merge("sf" => "301", "ssf" => "9.9.B"))
$party = nil
$leader = nil
$members = []
MGQ_MpCoopStory.update
check("a member who caught up keeps their own side quest, which the leader's story never set",
      [$game_switches[300], $game_variables[1500], $game_self_switches[[9, 9, "A"]]], [true, 3, true])
check("but not what the leader's story turned off", [$game_switches[301], $game_self_switches[[9, 9, "B"]]], [false, false])

member_game(30, 5)
MGQ_MpCoopStory.take(leader, behind_story)
$game_party.remove_actor(6)
MGQ_MpCoopStory.take(leader, { "story" => "hold", "party" => "p1" }.merge(morrigan))
check("after following the story, the leader's companions from elsewhere stay the leader's, and one the member let go stays gone",
      [$game_party.include_actors.include?(10), $game_party.include_actors.include?(6)], [false, false])


# Story equipment

# Story equipment a companion waiting at the castle wears counts, and during a story's temporary
# party the player's own companions still count, never the temporary ones.
# A companion, their equipment alone.
Wearer = Struct.new(:equips)
$game_party = Game_Party.new
$game_party.add_stand_actor(7)
$game_actors[7] = Wearer.new([$data_weapons[1], nil])
check("story equipment a companion at the castle wears counts", MGQ_MpStoryState.story_count($data_weapons[1]), 1)
def $game_party.include_actors; [8]; end
def $game_party.temp_actors_use?; true; end
check("during a temporary party the player's own companions are the roster", MGQ_MpStoryState.roster_ids, [7])
MGQ_MpStoryState.bring(9)
check("and one brought in waits at the castle, outside the temporary party", [$game_party.include_actors.include?(9), $game_party.actors], [false, []])
check("in the player's own roster", MGQ_MpStoryState.roster_ids, [7, 9])

# The game's roster keeps a companion by their main persona, so another persona of one the player
# has is in the roster too, and the leader tells the story companion by whichever persona joined.
$game_party = Game_Party.new
$game_party.add_stand_actor(8)
def $game_actors.original_id(id); id == 9 ? 8 : id; end
check("a companion's other persona is in the roster", [MGQ_MpStoryState.in_roster?(9), MGQ_MpStoryState.join(9)], [true, nil])
$game_actors = [nil, Hero.new]

# Luka's abilities are kept apart from his skills.
$game_actors[1].instance_variable_set(:@abilities, { 5 => [12] })
check("a story ability Luka knows is not learned again", MGQ_MpStoryState.learn(12), nil)
$game_actors = [nil, Hero.new]

# Chests are each player's own on every map: a member who caught up keeps theirs shut where only
# the leader looted, and open where they looted themselves.
member_game(30, 5)
$game_self_switches[[40, 2, "A"]] = true
MGQ_MpCoopStory.update
MGQ_MpCoopStory.take(leader, behind_story.merge("ss" => "40.1.A,40.3.A"))
$party = nil
$leader = nil
$members = []
MGQ_MpCoopStory.update
check("a chest only the leader looted on another map stays shut for the member, theirs stays open, a story's switch comes over",
      [$game_self_switches[[40, 1, "A"]], $game_self_switches[[40, 2, "A"]], $game_self_switches[[40, 3, "A"]]], [false, true, true])

# What the leader's whole story covers is not taken again from what waited before it.
member_game(30, 5)
MGQ_MpCoopStory.take(leader, { "story" => "hold", "party" => "p1" }.merge(holdings).merge("side" => "i"))
MGQ_MpCoopStory.take(leader, behind_story)
MGQ_MpCoopStory.update
check("older holdings that waited do not replace the newer ones the whole story came with", MGQ_MpCoopStory.instance_variable_get(:@leader_held)[:side], :alice)

# The whole story travels packed, and one too large leaves out what the story turned off.
story = [[nil, true, false], [nil, 0, 5], { [1, 2, "A"] => true, [1, 3, "A"] => false }]
packed = MGQ_MpStoryState.full(story)
check("the whole story travels packed and reads back with what it turned off", MGQ_MpStoryState.decode_full(packed),
      [[nil, true, false], [nil, 0, 5], { [1, 2, "A"] => true, [1, 3, "A"] => false }])
limit = MGQ_MpStoryState::MAX_FULL_BYTES
MGQ_MpStoryState.send(:remove_const, :MAX_FULL_BYTES)
MGQ_MpStoryState.const_set(:MAX_FULL_BYTES, 10)
check("one too large leaves out what the story turned off", MGQ_MpStoryState.decode_full(MGQ_MpStoryState.full(story)),
      [[nil, true], [nil, nil, 5], { [1, 2, "A"] => true }])
check("and says so", [MGQ_MpStoryState.full(story)["part"], packed["part"]], [1, nil])
MGQ_MpStoryState.send(:remove_const, :MAX_FULL_BYTES)
MGQ_MpStoryState.const_set(:MAX_FULL_BYTES, limit)
member_game(30, 5)
$game_switches[300] = true
MGQ_MpCoopStory.update
MGQ_MpCoopStory.take(leader, behind_story.merge("part" => "1"))
$party = nil
$leader = nil
$members = []
MGQ_MpCoopStory.update
check("a member who caught up with such a story keeps none of their own values in its gaps", $game_switches[300], false)


# An event the leader played on one side counts once the Great Decision set them on the other.
member_game(30, 4)
MGQ_MpCoopStory.take(leader, behind_story.merge("sk" => "12,13", "ac" => "4", "side" => "a"))
check("a camp the leader trained at on Ilias's side counts though they now play Alice's", $game_actors[1].skills.sort, [11, 13])

# What waited for the member is the leader's who sent it, never another leader's.
other_leader = MGQ_MpOverworldSync::Peers::Peer.new(6, { "id" => "o", "name" => "Other", "party" => "p1" }, nil, true)
member_game(40, 5)

# The pages a former leader told are forgotten once another member leads.
$leader = leader
$members = [leader]
SceneManager.scene = Scene_Battle.new
MGQ_MpCoopEvents.hear(leader, { "page" => "x.1", "lines" => ["Old line"].pack("m0") })
check("a page the leader tells waits while the member is busy", $pages_stand_in.waiting, 1)
$leader = other_leader
$members = [other_leader]
MGQ_MpCoopEvents.update
SceneManager.scene = Scene_Map.new
check("the pages a former leader told are forgotten once another member leads", $pages_stand_in.waiting_ids, [])
$party = nil
$leader = nil
$members = []
MGQ_MpCoopStory.update

# The real decision in a party: the member decides from both players' progress, which each game
# tells in its state.
$real_sync = true
$story_leader = leader
leader.state["sm"] = "32,0,0,0"
MGQ_MpCoopStory.instance_variable_set(:@sync_state, nil)
$sent.clear
member_game(30)
check("a member just behind the leader follows the leader's story and asks for it",
      [MGQ_MpCoopStory.follows_leader?, MGQ_MpCoopStory.state_fields, $sent.map { |_, f| f["story"] }], [true, { "sm" => "30,0,0,0", "ssync" => "l" }, ["ask"]])

leader.state["sm"] = "33,0,0,0"
MGQ_MpCoopStory.instance_variable_set(:@sync_state, nil)
$sent.clear
member_game(30)
check("one three steps behind plays their own story and is told why",
      [MGQ_MpCoopStory.follows_leader?, MGQ_MpCoopStory.state_fields["ssync"], $sent, $notices],
      [false, "", [], ["You and Leader are too far apart in the story; each of you plays your own."]])
MGQ_MpCoopStory.take(leader, behind_story.merge("v" => "1001:n33"))
check("the leader's story and its catch-up stay away from them, and nothing waits",
      [MGQ_MpCoopStory.guest?, held("Sword"), MGQ_MpCoopStory.instance_variable_get(:@held), $game_variables[1001]], [false, 0, nil, 30])
own_event = Game_Event.new(41, [story_page])
$game_map.events = { 41 => own_event }
check("their own story events run in their own game", [MGQ_MpCoopEvents.hand_over(own_event), MGQ_MpCoopEvents.following?], [false, false])
$game_player = Game_Player.new
SceneManager.scene = Scene_Map.new
leader.state["map"] = $game_map.map_id.to_s
leader.state["telling"] = "1"
MGQ_MpCoopEvents.take(leader, { "pevent" => "gather", "party" => "p1", "map" => "9", "x" => "1", "y" => "1", "d" => "2" })
MGQ_MpCoopEvents.take(leader, { "pevent" => "say", "party" => "p1", "map" => $game_map.map_id.to_s, "page" => "x.9", "lines" => ["Hi"].pack("m0") })
check("the leader's story scene neither calls nor holds them, nor shows them its pages",
      [MGQ_MpCoopGather.coming?, MGQ_MpCoopGather.blocked?, $pages_stand_in.waiting], [false, false, 0])
leader.state["telling"] = "0"
MGQ_MpCoopEvents.take_entry(leader, { "replay" => "WIRE:x4", "party" => "p1" })
check("but chests the party opens are shared all the same", MGQ_MpStoryReplay.waiting.map { |entry| entry["id"] }, ["x4"])
MGQ_MpStoryReplay.waiting.clear

leader.state["sm"] = "40,2,0,1"
MGQ_MpCoopStory.instance_variable_set(:@sync_state, nil)
member_game(39)
check("across the Great Decision each plays their own story", $notices, ["You and Leader are on different sides of the Great Decision; each of you plays your own story."])
leader.state["sm"] = "40,0,6,1"
MGQ_MpCoopStory.instance_variable_set(:@sync_state, nil)
member_game(40)
$game_variables[1141] = 3
$game_variables[1143] = 1
MGQ_MpCoopStory.update
check("on different routes too", $notices.last, "You and Leader are on different routes; each of you plays your own story.")

# Drifting apart: a member ahead of the leader plays along until the leader passes them by more than
# two steps, then gets their own story back.
leader.state["sm"] = "30,0,0,0"
MGQ_MpCoopStory.instance_variable_set(:@sync_state, nil)
member_game(32)
MGQ_MpCoopStory.take(leader, behind_story.merge("v" => "1001:n30"))
check("a member two steps ahead plays along", [MGQ_MpCoopStory.guest?, $game_variables[1001]], [true, 30])
leader.state["sm"] = "34,0,0,0"
MGQ_MpCoopStory.update
check("still while the leader is two steps past them", MGQ_MpCoopStory.guest?, true)
leader.state["sm"] = "35,0,0,0"
MGQ_MpCoopStory.update
check("but once three steps past, they get their own story back and are told why",
      [MGQ_MpCoopStory.guest?, $game_variables[1001], $notices.last(2)],
      [false, 32, ["You are back in your own story.", "You and Leader are too far apart in the story; each of you plays your own."]])

# A member behind who caught up plays as far as the leader, so the leader's progress telling more
# than the story that came yet never ends it.
leader.state["sm"] = "31,0,0,0"
MGQ_MpCoopStory.instance_variable_set(:@sync_state, nil)
member_game(30)
MGQ_MpCoopStory.take(leader, behind_story.merge("v" => "1001:n31"))
leader.state["sm"] = "40,1,0,1"
MGQ_MpCoopStory.update
check("a member who caught up stays synced while the leader's story moves on", [MGQ_MpCoopStory.guest?, MGQ_MpCoopStory.follows_leader?], [true, true])

# The leader: only members who follow the story are waited for, and the leader hears who follows.
$party = "p1"
$leader = :me
far = MGQ_MpOverworldSync::Peers::Peer.new(6, { "id" => "o", "name" => "Other", "party" => "p1", "sm" => "20,0,0,0", "ssync" => "", "map" => "99", "x" => "0", "y" => "0" }, nil, true)
near = MGQ_MpOverworldSync::Peers::Peer.new(7, { "id" => "n", "name" => "Near", "party" => "p1", "sm" => "30,0,0,0", "ssync" => "me", "map" => "99", "x" => "0", "y" => "0" }, nil, true)
$members = [far, near]
$game_variables = Game_Variables.new
$game_variables[1001] = 30
MGQ_MpCoopStory.forget
$notices.clear
MGQ_MpCoopStory.update
check("the leader hears who follows their story and who does not, and why",
      $notices.sort, ["Near follows your story while in the party.", "You and Other are too far apart in the story; each of you plays your own."].sort)
check("only a member who follows the story is waited for", [MGQ_MpCoopStory.synced_members, MGQ_MpCoopGather.missing], [[near], ["Near"]])
near.state["ssync"] = ""
check("with nobody following, the leader tells no story and holds none", [MGQ_MpCoopEvents.leading_story?, MGQ_MpCoopGather.missing], [false, []])
$real_sync = false
$party = nil
$leader = nil
$members = []
leader.state.delete("sm")
MGQ_MpCoopStory.update

# The relay's reviewed rewards hold what the maps from 1000 on give, such as Puruel and Inuel at the
# Chaos route's snow shrine.
event_rewards = reviewed_rows("event_rewards")
party_chests = reviewed_rows("party_chests").map { |row| map, event, letter = row["key"][2..-1].split("."); [map.to_i, event.to_i, letter] }
check("the rewards hold Puruel (516) and Inuel (517), and the companions set_actors brings",
      [516, 517, 6, 33, 35].map { |id| event_rewards.any? { |row| row["kind"] == "companion" && row["id"] == id } }, [true] * 5)
check("the skills Luka learns on maps from 1000 on, and their chests",
      [event_rewards.any? { |row| row["kind"] == "skill" && row["id"] == 9799 }, party_chests.any? { |key| key[0] >= 1000 }], [true, true])
sealed_pedestal = [1457, 4, "A"]
check("a pedestal of the Sealed Chamber the world's story emptied stays full for a player who never looted it",
      MGQ_MpStoryState.mix([[], [], { sealed_pedestal => true }], [[], [], {}], party_chests)[2].key?(sealed_pedestal), false)

# The game's Library Flags, "Library Flag: ..." and the untranslated rest, which translations differ
# in setting, so no event's marks may hold one.
library_flags = [201..420, 5201..5600]
side_events = reviewed_rows("side_events")
check("no event where the sides differ is marked by a Library Flag",
      side_events.map { |row| row["marks"] }.flatten(1).flatten(1).select { |mark| mark[0] == "s" && library_flags.any? { |range| range.include?(mark[1]) } }, [])
check("so the Strategy Conference is marked by its warp switch and Alice's adult form alone",
      side_events.find { |row| row["alice"]["companions"].include?(34) }["marks"], [[["s", 5091], ["s", 7089]]])

# The story's choices a member makes for themselves, coop_choices.rbx: what is asked, each outcome
# applied, the leader's offer to sync the story, and the Great Decision's other route.
# The players' wheel and notices of ui_actions.rbx, the offers registered kept in $offered.
module MGQ_MpActions
  # Color of the line above the player's own head.
  LINE_COLOR = :line_color
  # A choice of the wheel.
  Option = Struct.new(:text, :run, :refusal, :icon, :leaves)
  # A notice of the notification box.
  Notice = Struct.new(:key, :text, :color, :action, :take, :decline, :mark)
  def self.offer(offers); ($offered ||= []) << offers; end
end
# The base of the game's menu scenes.
class Scene_MenuBase; end
# The game's rectangle and font, and a picture that measures texts, with which the screen of
# choices, a Mod Framework window, measures its parts.
Rect = Struct.new(:x, :y, :width, :height) unless defined?(Rect)
Font = Struct.new(:size, :color, :bold, :outline, :out_color, :name, :italic) unless defined?(Font)
class Bitmap
  def initialize(width, height); @width, @height, @font = width, height, Font.new(24); end
  def font; @font; end
  def text_size(text); Rect.new(0, 0, text.to_s.size * 12, 24); end
  def disposed?; false; end
end
# The scenes called, kept in $scenes.
module SceneManager; def self.call(scene); ($scenes ||= []) << scene; end; end
# The world's ticks, with which coop_choices.rbx forgets what waits once the world closes.
module MGQ_MpOverworldSync; def self.on_tick(&block); ($choice_ticks ||= []) << block if block; end; end
load_script "coop_choices"
choices = MGQ_MpCoopChoices
# The screen of choices stays open as asked: its window on the Mod Framework has its own tests
# (story_choices_test.rb), and the framework here runs without its DLL, which refuses every window.
MGQ_MpCoopChoices::Screen.define_singleton_method(:open) { |screen| screen }
{ 5 => "Alice", 26 => "Ilias", 163 => "Lily", 167 => "Lucia", 287 => "Succubus", 288 => "Natasha", 540 => "Amira", 153 => "Sphinx", 241 => "Priestess",
  245 => "Miria", 334 => "Spider Princess" }.each { |id, name| $data_actors[id] = Actor.new(name) }

check("a catch-up from the start to the Great Decision asks every choice, in story order",
      choices.passed(5, 40, [], [], []), [:side, :magistea, :navy, :plansect, :succubus, :spider, :sphinx, :decision])
check("one from 20 to 32 asks those between, and not one the player made",
      choices.passed(20, 32, Array.new(3000).tap { |s| s[2096] = true }, [], []), [:navy, :plansect, :succubus, :spider, :sphinx])
check("Amira in Iliasburg is no choice: both her outcomes end with her joining, so the story brings her",
      [choices.passed(5, 40, [], [], []).include?(:amira), choices.skip_reason(:actors, 540)], [false, nil])
check("the Great Decision is not asked before the leader is past it", choices.passed(30, 39, [], [], []).include?(:decision), false)
$game_system_switches = {}
check("the third way only with both endings cleared", choices.labels(:decision).size, 2)
$game_system_switches = { :ed1 => true, :ed2 => true }
check("which offers it", choices.labels(:decision).last, "Search for a third way (Chaos)")
$game_system_switches = {}
choices.raid_decision(0)
$choice_ticks.each { |tick| tick.call(true) }
check("an open world keeps a Raid World's route waiting to be confirmed", [choices.instance_variable_get(:@raid_route), choices.instance_variable_get(:@prompts)], [0, [:decision]])
$choice_ticks.each { |tick| tick.call(false) }
check("the world closing forgets it with the choices waiting", [choices.instance_variable_get(:@raid_route), choices.instance_variable_get(:@prompts)], [nil, []])

# Each outcome, laid over the player's own story with the companions it brings.
member_game(20, 5)
choices.apply(:magistea, 0)
check("defeating Lily keeps Lily defeated and Lucia in the party",
      [$game_switches[2096], $game_switches[2097], $game_switches[2138], $game_variables[1029], $game_party.include_actors.include?(167)], [true, false, true, 6, true])
choices.apply(:magistea, 1)
check("defeating Lucia turns it the other way and brings Lily",
      [$game_switches[2096], $game_switches[2097], $game_switches[2137], $game_party.include_actors.include?(163)], [false, true, true, true])
member_game(20, 5)
choices.apply(:succubus, 0, :magistea => 1)
check("allying with Natasha while Lily is with the player brings Natasha", [$game_switches[2210], $game_switches[2211], $game_party.include_actors.include?(288)], [true, false, true])
member_game(20, 5)
choices.apply(:succubus, 0, :magistea => 0)
check("without Lily nobody joins", [$game_switches[2211], $game_switches[2210], $game_party.include_actors.include?(288)], [true, false, false])
check("and the screen says so", choices.note(:succubus, 0, :magistea => 0), "Nobody joins: Natasha joins only while Lily is with you.")
member_game(20, 5)
choices.apply(:succubus, 1, :magistea => 0)
check("allying with the mayor while Lucia is with the player brings the mayor", [$game_switches[2212], $game_party.include_actors.include?(287)], [true, true])
member_game(20, 5)
choices.apply(:plansect, 1)
choices.apply(:spider, 0)
choices.apply(:sphinx, 0)
check("the Queen Bee's side, then the Spider Princess's side, which sends Miria away on a first playthrough, and the Sphinx challenged, who joins once defeated",
      [$game_variables[1061], $game_switches[2154], $game_switches[2280], [245, 334, 153].map { |id| $game_party.include_actors.include?(id) }, $notices.include?("Miria left you.")],
      [2, true, true, [false, true, true], true])
member_game(20, 5)
choices.apply(:plansect, 2)
check("the peace of Plansect brings both the Priestess and Miria", [$game_variables[1061], [241, 245].map { |id| $game_party.include_actors.include?(id) }], [3, [true, true]])

# The outcomes the member made stay theirs in the leader's story, and the leader's choices'
# companions never come with it.
$real_sync = false
choices.forget("next check")
member_game(30, 5)
choices.apply(:magistea, 0)
MGQ_MpCoopStory.take(leader, behind_story.merge("s" => "120,2097", "ac" => "4,163"))
check("the leader's outcome of Magistea Village stays out of the member's story",
      [$game_switches[2096], $game_switches[2097], MGQ_MpStoryState.personal_switch?(2097)], [true, false, true])
check("and the leader's choice companion with it", $game_party.include_actors.include?(163), false)
MGQ_MpCoopStory.take(leader, { "story" => "delta", "party" => "p1", "s" => "2096:0,2097:1", "v" => "", "ss" => "" })
check("nor do the leader's later changes of it reach the member", [$game_switches[2096], $game_switches[2097]], [true, false])

# Synced play: catching up with the leader's story asks the member's own outcome of the choices the
# leader passed before the member followed, the leader's place then included; the leader's runs
# after it come by replay, which asks the member's own outcome of their choices.
choices.forget("next check")
member_game(15, 5)
$scenes = []
MGQ_MpCoopStory.take(leader, behind_story.merge("v" => "1001:n17", "s" => "120,2097"))
check("a reward behind the leader's outcome of a choice the member has not answered waits for their own answer",
      $game_actors[1].skills.include?(15), false)
SceneManager.scene = Scene_Map.new
$game_map.interpreter.busy = false
$game_message.busy = false
$game_map.update
check("catching up past Magistea Village asks the member's own outcome, on the screen with one row", choices.screen && choices.screen[:keys], [:magistea])
screen = choices.screen
screen[:answers][:magistea] = 1
screen[:confirmed] = true
choices.screen_closed(screen, :button)
check("and keeps it", [$game_switches[2097], $game_party.include_actors.include?(163), choices.instance_variable_get(:@prompts)], [true, true, []])
MGQ_MpCoopStory.choice_answered
check("and the reward behind that outcome comes once they answered it, once", $game_actors[1].skills.count(15), 1)
MGQ_MpCoopStory.take(leader, { "story" => "delta", "party" => "p1", "s" => "2280:1", "v" => "", "ss" => "" })
check("a choice the leader resolves after the member followed is left to the replay of its run", choices.instance_variable_get(:@prompts), [])
choices.forget("test")

# The leader's offer to sync the story, declined.
$party = "p1"
$leader = :me
$members = [friend]
friend.state["sm"] = "20,0,0,0"
friend.state["ssync"] = ""
$game_variables = Game_Variables.new
$game_variables[1001] = 30
choices.offer(friend)
check("the leader offers a member behind to sync their story", choices.state_fields["ssoffer"].split(":")[0], "f")
friend.state["sm"] = "31,0,0,0"
check("but never to one ahead", choices.offer_refusal(friend), "Friend is not behind you in the story.")
friend.state["sm"] = "20,0,0,0"
$notices.clear
choices.take(friend, { "choices" => "declined", "party" => "p1" })
check("a member who declines is no longer offered it, and the leader hears it", [choices.state_fields["ssoffer"], $notices.last], ["", "Friend declined to sync their story."])

# Accepted: the screen asks the choices, and the member is brought to the leader's point.
member_game(20, 5)
leader.state["sm"] = "40,3,0,1"
leader.state["ssoffer"] = "me:1"
check("the member sees the leader's offer", choices::Offers.notice_of(leader).text, "Leader offers to bring your story up to theirs")
$scenes = []
choices.accept(leader)
screen = choices.screen
check("accepting shows the choices the catch-up carries them past",
      [screen[:keys], screen[:buttons]], [[:navy, :plansect, :succubus, :spider, :sphinx, :decision], ["Bring me there", "Cancel"]])
choices.screen_closed(screen, :cancel)
leader.state["ssoffer"] = ""
check("which closes once the leader takes the offer back", choices.valid_offer?(leader), "Leader took the offer back.")
$leader = nil
check("or leaves the party", choices.valid_offer?(leader), "Leader no longer leads your party.")
$leader = leader
leader.state["ssoffer"] = "me:1"

# The other side of the Great Decision: the member starts their own route from its start.
decision = [RPG::EventCommand.new(102, 0, [["a", "b"], 0]), RPG::EventCommand.new(122, 2, [1002, 1002, 0, 0, 112]),
            RPG::EventCommand.new(355, 3, ["add_actor_ex_nc(26)"]), RPG::EventCommand.new(201, 2, [0, 431, 25, 19, 8, 2])]
$data_common_events[380] = RPG::CommonEvent.new(decision)
$real_sync = true
$sent.clear
choices.confirm_offer(leader, [40, 3, 0, 1], 0, :plansect => 0, :succubus => 0, :spider => 1, :sphinx => 0, :decision => 1)
check("the member's outcomes are theirs before the leader's story comes",
      [$game_variables[1061], $game_switches[2281]], [1, true])
MGQ_MpCoopStory.update
check("the member then follows the leader's story, by the offer", MGQ_MpCoopStory.follows_leader?, true)
MGQ_MpCoopStory.take(leader, behind_story.merge("v" => "1001:n40,1141:n3", "ac" => "4,163"))
queued = choices.instance_variable_get(:@queued)
check("taking the other side, they keep the leader's story up to the Great Decision and play their own",
      [MGQ_MpCoopStory.guest?, $game_variables[1001], $game_variables[1141], MGQ_MpCoopStory.follows_leader?], [false, 39, 0, false])
check("from the Great Decision's own outcome: the Final Chapter put back, its party changes, the side and the route, and its map",
      queued.map { |command| [command.code, command.indent, command.parameters] },
      [[117, 0, [154]], [122, 0, [1140, 1140, 0, 0, 0]], [122, 0, [1002, 1002, 0, 0, 112]], [355, 1, ["add_actor_ex_nc(26)"]],
       [121, 0, [4, 4, 1]], [121, 0, [5, 5, 0]], [122, 0, [1142, 1142, 0, 0, 1]], [201, 0, [0, 431, 25, 19, 8, 2]], [0, 0, []]])
check("and the leader's choice companion stays the leader's", $game_party.include_actors.include?(163), false)
check("the third way goes to its own start", choices.decision_commands(2).map { |command| command.code }, [117, 122, 121, 121, 121, 122, 122, 201, 0])
$real_sync = false
$party = nil
$leader = nil
$members = []
choices.forget("test over")
MGQ_MpCoopStory.update

# A Raid World: whoever tells the story on the map tells it to everyone there who plays their
# track, party or not.
# Whether the world is a Raid World, from $raid.
module MGQ_MpWorld; def self.raid?; $raid; end; end
# The world's story: the player's track from $track, the tellings the relay told of on it from
# $tellings, by seat, and whether the player's story events wait for it from $await_world.
module MGQ_MpWorldStory
  def self.track; $track; end
  def self.telling_of(seat); $tellings[seat]; end
  def self.awaits_world?; $await_world ? true : false; end
  def self.awaits_teller?; false; end
  # No value moves the world's story on, and no commands may.
  def self.progress_now; []; end
  def self.progress_ahead?(*); false; end
end
$track = "world"
$tellings = {}
# The players met, from $peers, and the player who entered the map at frame 2000.
module MGQ_MpOverworldSync
  module Me; def self.map_since; 2000; end; end
  module Peers
    def self.present; $peers; end
    def self.all; $peers; end
    def self.on_this_map?(peer); peer.state["map"].to_i == $game_map.map_id; end
  end
end
$raid = true
use_listed_raid_table
check("in a Raid World it is each player's own travel, never a story told to everyone and taking them into the castle", kind(castle_tour), :travel)
$party = "p1"
$leader = leader
$members = [leader]
$game_map = Game_Map.new
$game_player = Game_Player.new
SceneManager.scene = Scene_Map.new
$game_message.clear
$game_message.busy = false
$game_switches = Game_Switches.new
$game_variables = Game_Variables.new
$game_variables[1001] = 12
MGQ_MpCoopGather.forget
MGQ_MpCoopEvents.page_ended
teller = MGQ_MpOverworldSync::Peers::Peer.new(6, { "id" => "t", "name" => "Teller", "map" => "3", "since" => "1000", "trk" => "world" }, nil, false)
stranger = MGQ_MpOverworldSync::Peers::Peer.new(7, { "id" => "s", "name" => "Stranger", "map" => "3", "since" => "3000", "trk" => "world" }, nil, false)
behind = MGQ_MpOverworldSync::Peers::Peer.new(8, { "id" => "b", "name" => "Behind", "map" => "3", "since" => "3000", "trk" => "t2" }, nil, false)
leader.state.merge!("map" => "9", "telling" => "0", "since" => "500", "trk" => "world")
$peers = [teller, stranger, behind, leader]
$tellings[6] = ["t1", 3, "map:3:1:1"]
check("a Raid World's parties lead no story: nobody borrows a leader's story or tells members one",
      [MGQ_MpCoopStory.leader, MGQ_MpCoopStory.real_synced_members, MGQ_MpCoopStory.real_follows_leader?], [nil, [], false])

raid_event = Game_Event.new(51, [story_page])
$game_map.events = { 51 => raid_event }
$notices.clear
check("a player telling the story on the map, party or not, keeps the player's story events from starting",
      [MGQ_MpCoopEvents.hand_over(raid_event), MGQ_MpCoopEvents.following?, $notices.last], [true, true, "Teller is telling the story here."])
MGQ_MpCoopEvents.take(teller, { "pevent" => "say", "map" => "3", "page" => "r.1", "lines" => ["Raid line"].pack("m0") })
$game_map.update
check("their pages show for a player the relay told of the telling", $game_message.texts, ["Raid line"])
$game_message.clear
MGQ_MpCoopEvents.page_ended
MGQ_MpCoopEvents.take(stranger, { "pevent" => "say", "map" => "3", "page" => "s.1", "lines" => ["Not told"].pack("m0") })
$tellings.delete(6)
MGQ_MpCoopEvents.take(teller, { "pevent" => "say", "map" => "3", "page" => "r.2", "lines" => ["Not on the track"].pack("m0") })
$game_map.update
check("but neither a player's who does not tell it, nor the teller's for a player the relay told of no telling, as one on another track", $game_message.texts, [])

raid_story = Game_Event.new(52, [story_page])
$game_map.events = { 52 => raid_story }
check("once nobody tells it here, the player's own story events start", MGQ_MpCoopEvents.hand_over(raid_story), false)
$sent.clear
interpreter = $game_map.interpreter
interpreter.setup(story_page.list, 52)
interpreter.busy = true
check("the player tells it, alone too, and says so in their state",
      [MGQ_MpCoopGather.holding_story?, MGQ_MpCoopEvents.state_fields], [false, { "telling" => 1 }])
$game_message.add("Told line")
MGQ_MpCoopEvents.show(interpreter)
check("its pages go through the map's gate in one message to the players on the map who play the player's track",
      $sent.map { |seat, fields| [seat, fields["map_pevent"], fields["mmap"], fields["mto"]] }, [[-1, "say", "3", "t,s"]])
$game_message.clear
check("its first command waits for the relay's answer for the telling's lock of the map",
      [MGQ_MpCoopEvents.lock_holding?(interpreter), $telling_machine.requests.last], [true, ["map:3:52:1", 3]])
$lock = true
check("and runs once the relay granted it", [MGQ_MpCoopEvents.lock_holding?(interpreter), MGQ_MpCoopEvents.telling?], [false, true])
MGQ_MpCoopEvents.finished(interpreter)
interpreter.busy = false
$game_map.update
check("the lock goes back once the telling's event ended", $telling_machine.requests.last, nil)
$lock = nil
interpreter.setup(story_page.list, 52)
interpreter.busy = true
$lock = [false, 6]
$notices.clear
check("once the relay refused it, the player's event ends before its first command, and the player hears who tells there",
      [MGQ_MpCoopEvents.lock_holding?(interpreter), interpreter.instance_variable_get(:@index), MGQ_MpCoopEvents.telling?, $notices.last],
      [false, story_page.list.size - 1, false, "Teller is telling the story here."])
MGQ_MpCoopEvents.finished(interpreter)
interpreter.busy = false
$game_map.update
$lock = nil
interpreter.setup(story_page.list, 52)
interpreter.busy = true
$lock = [false, nil]
check("a refusal that names no teller, as before the relay placed the player, lets the event run without the lock",
      [MGQ_MpCoopEvents.lock_holding?(interpreter), interpreter.instance_variable_get(:@index), MGQ_MpCoopEvents.telling?], [false, 0, true])
MGQ_MpCoopEvents.finished(interpreter)
interpreter.busy = false
$game_map.update
# A talk that turns into story waits for the lock at the command that moves the story on.
$data_common_events = $data_common_events.dup
$data_common_events[8] = RPG::CommonEvent.new(trader)
$lock = nil
interpreter.setup(trader)
interpreter.busy = true
interpreter.instance_variable_set(:@index, 7)
story_step = Fiber.new { interpreter.execute_command; :ran }
held = story_step.resume
$lock = true
check("a talk that turns into story holds the command that moves the story on until the relay granted the lock",
      [held, MGQ_MpCoopEvents.telling?, story_step.resume, interpreter.instance_variable_get(:@index)], [nil, true, :ran, 7])
MGQ_MpCoopEvents.finished(interpreter)
interpreter.busy = false
$game_map.update
$lock = nil
interpreter.setup(trader)
interpreter.busy = true
interpreter.instance_variable_set(:@index, 7)
story_step = Fiber.new { interpreter.execute_command; :ran }
story_step.resume
$lock = [false, 6]
check("and ends before that command once the relay refused it",
      [story_step.resume, interpreter.instance_variable_get(:@index), MGQ_MpCoopEvents.telling?], [:ran, trader.size - 1, false])
MGQ_MpCoopEvents.finished(interpreter)
interpreter.busy = false
$game_map.update
$data_common_events[8] = nil
$lock = true
# The story's next event starts in the frame its last ended, before the world's story went out.
$game_map.update
interpreter.setup(story_page.list, 52)
interpreter.busy = true
$game_map.update
$game_variables[1001] = 13
MGQ_MpCoopGather.instance_variable_set(:@taken_along, ["x"])
MGQ_MpCoopEvents.finished(interpreter)
interpreter.setup(story_page.list, 52)
check("the story's next event goes on with the telling: whom it took along, and the viewers on the player's track",
      [MGQ_MpCoop::Scope.viewers, MGQ_MpCoopGather.instance_variable_get(:@taken_along)], [[teller, stranger], ["x"]])
interpreter.busy = false
$game_map.update
$log.clear
interpreter.setup(story_page.list, 52)
interpreter.busy = true
check("a telling after a frame without one starts anew", [$log.grep(/goes on with the telling/).size, MGQ_MpCoopGather.instance_variable_get(:@taken_along)], [0, nil])
interpreter.busy = false
$game_map.update
$game_variables[1001] = 12

$game_party = Game_Party.new
$game_self_switches = Game_SelfSwitches.new
$game_map.events = { 5 => Game_Event.new(5, [chest_page]) }
MGQ_MpCoopEvents.instance_variable_set(:@chest_keys_map, nil)
$sent.clear
$game_map.interpreter.setup(chest_page.list, 5)
$game_map.interpreter.run
check("a Raid World's chests are personal: opening one tells nobody, party or not", $sent.select { |_, f| f["replay"] }, [])
MGQ_MpCoopEvents.take_entry(leader, { "replay" => "WIRE:x5", "party" => "p1" })
check("and one a party member opened is not played", MGQ_MpStoryReplay.waiting, [])
$game_map.events = {}
MGQ_MpCoopEvents.instance_variable_set(:@chest_keys_map, nil)

# A player behind the world's story starts no story event that ends their part and hears the level
# that moves them on; such story that runs by itself waits silently; every other story event and
# talk runs, as Promestein's race machine and Lime's talk must (issue #48).
# Stands in for world_catchup.rbx, the player behind the world's story while $behind is set.
module MGQ_MpWorldCatchup
  def self.holds_story?; $behind; end
  def self.refusal_text; "Reach level 25 to continue the story."; end
end
# The part of the player's track, $track_part.
module MGQ_MpWorldStory
  def self.part; $track_part; end
end
$track_part = "1"
# Stands in for the DLL's check of what a story event writes (StoryTopics.LeavesPartTopic, whose
# rule PartEndTests covers): a write of $part_end ("s<id>" or "v<id>") ends the player's part, and
# while $chain_end names a self switch, the chain the event starts across maps ends it until that
# self switch is on, which the DLL names as a value it needs. It counts its asks.
$part_end = "v1001"
$chain_end = nil
leave_asks = 0
$world_bridge.answer("story.leaves_part") do |request|
  leave_asks += 1
  next { "unknown" => true } unless request["list"]

  if $chain_end
    known = request["values"] && request["values"]["ss"]
    next { "needs" => { "ss" => [$chain_end] } } unless known && known.key?($chain_end)
    next { "leaves" => !known[$chain_end], "why" => known[$chain_end] ? nil : "its chain sets v1001, which leaves Part #{$track_part}" }
  end

  code = $part_end[0] == "s" ? 121 : 122
  id = $part_end[1..-1].to_i
  ends = request["list"].any? { |command, _indent, parameters| command == code && parameters[0] <= id && id <= parameters[1] }
  { "leaves" => ends, "why" => ends ? "it sets #{$part_end}, which leaves Part #{$track_part}" : nil }
end
$behind = true
$peers = []
$notices.clear
MGQ_MpCoopEvents.instance_variable_set(:@refused, nil)
race_machine = Game_Event.new(57, [story_page])
check("a player behind the world's story starts story that stays in their part, as the race machine is", [MGQ_MpCoopEvents.hand_over(race_machine), $notices], [false, []])
$track_part = "2"
$part_end = "s60"
behind_story = Game_Event.new(54, [story_page])
behind_auto = Game_Event.new(55, [story_page], 3)
behind_talk = Game_Event.new(56, [talk_page])
check("but no story event that ends their part, and hears the level that moves them on",
      [MGQ_MpCoopEvents.hand_over(behind_story), $notices], [true, ["Reach level 25 to continue the story."]])
check("once, however often they step on it", [MGQ_MpCoopEvents.hand_over(behind_story), $notices.size], [true, 1])
check("such story that runs by itself waits without a word, so a teleport onto its map cannot loop", [MGQ_MpCoopEvents.hand_over(behind_auto), $notices.size], [true, 1])
asks = leave_asks
3.times { MGQ_MpCoopEvents.hand_over(behind_auto) }
check("and asks the DLL no more on the frames it would start again", leave_asks - asks, 0)
# Alice's final battle, which leads across maps to the part's end on a map without exits, waits
# where it starts, as long as the self switch its chain's last page checks keeps that page.
$chain_end = "750.12.A"
final_battle = Game_Event.new(58, [story_page], 3)
check("story whose chain across maps ends the part waits too, read with the self switch the DLL named",
      [MGQ_MpCoopEvents.hand_over(final_battle), $notices.size], [true, 1])
asks = leave_asks
MGQ_MpCoopEvents.hand_over(final_battle)
check("asked no more while that self switch stays", leave_asks - asks, 0)
$game_self_switches[[750, 12, "A"]] = true
check("and starts once it changed", MGQ_MpCoopEvents.hand_over(final_battle), false)
$game_self_switches[[750, 12, "A"]] = false
$chain_end = nil
check("talks run", MGQ_MpCoopEvents.hand_over(behind_talk), false)
behind_common = RPG::CommonEvent.new([c(101, "", 0, 0, 2), c(121, 60, 60, 0)])
behind_common.switch_id = 70
$data_common_events[4] = behind_common
raw($game_switches)[70] = true
check("as does a story common event that runs by itself and ends the part", $game_map.setup_autorun_common_event, nil)
# A talk that turns into story follows the same rule: one whose story stays in the part goes on, as
# Lime's goes on past her wedding line's switch; one whose story ends the part ends there.
interpreter = $game_map.interpreter
guard_talk = lambda do
  interpreter.setup(trader, 0)
  interpreter.busy = true
  interpreter.instance_variable_set(:@index, 7)
  MGQ_MpCoopEvents.instance_variable_set(:@may_tell, true)
  $notices.clear
  MGQ_MpCoopEvents.guard(interpreter)
  reached = [interpreter.instance_variable_get(:@index), $notices.dup]
  MGQ_MpCoopEvents.finished(interpreter)
  interpreter.busy = false
  reached
end
check("a talk of a player behind goes on where its story stays in their part", guard_talk.call, [7, []])
$track_part = "3"
$part_end = "v1007"
check("and ends where its story would end their part", guard_talk.call, [trader.size - 1, ["Reach level 25 to continue the story."]])
$track_part = "1"
$part_end = "v1001"
$behind = false
check("caught up, the player's story events start again", [MGQ_MpCoopEvents.hand_over(behind_story), $game_map.setup_autorun_common_event], [false, behind_common])

# Until the world's story came after the world opened or a save loaded, story events wait, the
# player's and those that run by themselves, without a word; talks run.
$await_world = true
$notices.clear
check("story events wait for the world's story, without a word",
      [MGQ_MpCoopEvents.hand_over(behind_story), MGQ_MpCoopEvents.hand_over(behind_auto), $game_map.setup_autorun_common_event, $notices], [true, true, nil, []])
check("talks run meanwhile", MGQ_MpCoopEvents.hand_over(behind_talk), false)
$await_world = false
check("once it came, they start", [MGQ_MpCoopEvents.hand_over(behind_story), $game_map.setup_autorun_common_event], [false, behind_common])
$data_common_events[4] = nil
raw($game_switches)[70] = false

# A telling the story carries onto another map goes on as the same telling at the story's next
# event there, through the game's transfer process between them.
$peers = [teller, stranger]
stranger.state["map"] = "430"
$game_map.map_id = 430
$game_variables[1001] = 12
$sent.clear
interpreter.setup(story_page.list, 52)
interpreter.busy = true
$game_player.reserve_transfer(432, 0, 0, 2)
$game_player.perform_transfer
check("a telling that moves the player takes those on the map along", [$game_map.map_id, $sent.map { |seat, f| [seat, f["map_pevent"], f["mmap"]] }, MGQ_MpCoopGather.taken_along],
      [432, [[7, "follow", "430"]], [stranger]])
check("and its lock moves to the new map as the transfer lands, while its event still runs", $telling_machine.requests.last, ["map:430:52:1", 432])
MGQ_MpCoopEvents.finished(interpreter)
interpreter.busy = false
$game_map.update
transfer_process = RPG::CommonEvent.new([c(121, 20, 20, 0)])
$data_common_events[114] = transfer_process
interpreter.setup(transfer_process.list)
interpreter.busy = true
check("the game's transfer process runs between its events in the player's own game, telling nothing",
      [MGQ_MpCoopEvents.state_fields["telling"], MGQ_MpCoopGather.taken_along], [0, []])
MGQ_MpCoopEvents.finished(interpreter)
interpreter.busy = false
$game_map.update
$game_variables[1001] = 13
$log.clear
interpreter.setup(story_page.list, 53)
interpreter.busy = true
check("a story event on the new map within CONTINUE_FRAMES goes on with the telling: whom it took along, and that the player tells it",
      [MGQ_MpCoopEvents.state_fields, MGQ_MpCoopGather.taken_along, MGQ_MpCoop::Scope.viewers, $log.grep(/goes on with the telling that moved the player from map 430/).size],
      [{ "telling" => 1 }, [stranger], [stranger], 1])
check("which keeps the lock of the new map, with the telling's first site, without a hold",
      [$telling_machine.requests.last, MGQ_MpCoopEvents.lock_holding?(interpreter)], [["map:430:52:1", 432], false])
$game_player.reserve_transfer(433, 0, 0, 2)
$game_player.perform_transfer
MGQ_MpCoopEvents.finished(interpreter)
interpreter.busy = false
$game_map.update
$frame_count += TellingStandIn::CONTINUE_FRAMES
$log.clear
interpreter.setup(story_page.list, 54)
interpreter.busy = true
check("a story event later than CONTINUE_FRAMES after the move starts a telling anew",
      [TellingStandIn::CONTINUE_FRAMES, $log.grep(/goes on with the telling/).size, MGQ_MpCoopGather.taken_along], [300, 0, []])
MGQ_MpCoopEvents.finished(interpreter)
interpreter.busy = false
$game_map.update
$data_common_events[114] = nil

# A transfer outside a telling, such as a teleport, goes on with none, and a story event the player
# starts on the new map is a new telling: only one that runs by itself goes on with the telling that
# moved the player.
$game_map.events = { 55 => Game_Event.new(55, [story_page], 3), 56 => Game_Event.new(56, [story_page]), 57 => Game_Event.new(57, [story_page], 3) }
$game_variables[1001] = 14
$game_player.reserve_transfer(434, 0, 0, 2)
$game_player.perform_transfer
$game_map.update
$log.clear
interpreter.setup(story_page.list, 55)
interpreter.busy = true
check("a transfer outside a telling, such as a teleport, goes on with none: a story event within CONTINUE_FRAMES after it starts a telling anew",
      [MGQ_MpCoopEvents.telling?, $log.grep(/goes on with the telling/).size], [true, 0])
stranger.state["map"] = "434"
$game_player.reserve_transfer(435, 0, 0, 2)
$game_player.perform_transfer
MGQ_MpCoopEvents.finished(interpreter)
interpreter.busy = false
$game_map.update
$game_variables[1001] = 15
$log.clear
interpreter.setup(story_page.list, 56)
interpreter.busy = true
check("a story event the player starts on the new map within CONTINUE_FRAMES is a new telling: nobody taken along",
      [MGQ_MpCoopGather.taken_along, $log.grep(/goes on with the telling/).size], [[], 0])
$game_player.reserve_transfer(436, 0, 0, 2)
$game_player.perform_transfer
MGQ_MpCoopEvents.finished(interpreter)
interpreter.busy = false
$game_map.update
$game_variables[1001] = 16
$log.clear
interpreter.setup(story_page.list, 57)
interpreter.busy = true
check("while one that runs by itself goes on with it",
      [MGQ_MpCoopEvents.telling?, $log.grep(/goes on with the telling that moved the player from map 435/).size], [true, 1])
MGQ_MpCoopEvents.finished(interpreter)
interpreter.busy = false
$game_map.update
$game_map.events = {}

# A follower on the way to where the teller's story moved them starts no story event of their own,
# keeps that teller while their state says they tell nothing, and hears their pages from the new map.
$game_map.map_id = 430
$game_player.moveto(25, 19)
$game_variables[1001] = 12
teller.state["map"] = "432"
$tellings[6] = ["t1", 430, "map:430:1:1"]
stranger.state["map"] = "3"
$peers = [teller, stranger]
MGQ_MpCoopEvents.page_ended
$game_message.clear
$notices.clear
$log.clear
MGQ_MpCoopEvents.take(teller, { "pevent" => "follow", "map" => "432", "x" => "0", "y" => "0", "d" => "2" })
own_copy = Game_Event.new(57, [story_page], 3)
check("a follower on the way to where the teller's story moved them keeps their own copy of it, which runs by itself, from starting, silently",
      [MGQ_MpCoopEvents.hand_over(own_copy), MGQ_MpCoopEvents.hand_over(own_copy), $notices,
       $log.grep(/kept event 57 on map 430 from starting: the player follows Teller's story to map 432/).size],
      [true, true, [], 1])
check("the teller they follow stays the teller, whose telling the relay keeps on the map it left while the story's next event has yet to start",
      [MGQ_MpCoop::Scope.teller, MGQ_MpCoopEvents.following?], [teller, true])
MGQ_MpCoopEvents.take(teller, { "pevent" => "say", "map" => "432", "page" => "m.1", "lines" => ["Moved line"].pack("m0") })
check("and their pages from the new map wait for the player", $pages_stand_in.waiting_ids, ["m.1"])
$game_map.update
check("the player follows as soon as they are free, no page of the story starting before", [$game_player.reserved, $game_message.texts], [[432, 0, 0, 2], []])
check("and starts no story event on the way either", [MGQ_MpCoopEvents.hand_over(own_copy), MGQ_MpCoop::Scope.teller], [true, teller])
$game_player.perform_transfer
$game_map.update
check("arrived, the pages heard show", $game_message.texts, ["Moved line"])
MGQ_MpCoopEvents.page_ended
$game_message.clear
MGQ_MpCoopEvents.take(teller, { "pevent" => "say", "map" => "432", "page" => "m.2", "lines" => ["Long line"].pack("m0") })
MGQ_MpCoopEvents.take(teller, { "pevent" => "done", "map" => "432", "page" => "m.2" })
MGQ_MpCoopEvents.take(teller, { "pevent" => "say", "map" => "432", "page" => "m.3", "lines" => ["Passed line"].pack("m0") })
MGQ_MpCoopEvents.take(teller, { "pevent" => "done", "map" => "432", "page" => "m.3" })
$game_map.update
check("a page the teller moved past stays to read", [$game_message.texts, MGQ_MpCoopEvents.page_done?], [["Long line"], false])
class << MGQ_MpCoopGather; alias_method :due_before_check, :due?; def due?; true; end; end
check("but ends at once while the story brings the player over", MGQ_MpCoopEvents.page_done?, true)
MGQ_MpCoopEvents.page_ended
$game_message.clear
$game_map.update
check("and the pages the teller moved past are left out, so the player is free to go", [$game_message.texts, $pages_stand_in.waiting_ids], [[], []])
class << MGQ_MpCoopGather; alias_method :due?, :due_before_check; end
next_copy = Game_Event.new(2, [story_page], 3)
$tellings.delete(6)
check("arrived, their copy of the story's next event waits too while the relay tells of no telling of the teller's for a moment",
      [MGQ_MpCoopEvents.hand_over(next_copy), $log.grep(/kept event 2 on map 432 from starting: the player follows Teller's story to map 432/).size, MGQ_MpCoop::Scope.teller],
      [true, 1, teller])
$tellings[6] = ["t1", 432, "map:430:1:1"]
check("and once it tells of it again", [MGQ_MpCoopEvents.hand_over(next_copy), MGQ_MpCoop::Scope.teller], [true, teller])
$tellings.delete(6)
$frame_count += GatherStandIn::CALL_LAPSE_FRAMES
check("the follow ends by itself", [MGQ_MpCoop::Scope.teller, MGQ_MpCoopEvents.hand_over(next_copy)], [nil, false])
MGQ_MpCoopEvents.page_ended
$game_message.clear
teller.state["map"] = "3"
$peers = []
$game_map.update

$game_map.map_id = 227
check("the castle's Map Owner is the map's sync host, not the party's leader", MGQ_MpCoopCastle.owner([leader]), nil)
$raid = false
$party = nil
$leader = nil
$members = []

SceneManager.scene = Scene_Map.new
$game_map.interpreter = Game_Interpreter.new
$game_message.clear
$game_message.busy = false
$game_player = Game_Player.new

# A frozen raid boss fight's resume runs its page as story, whatever it is sorted as otherwise.
talk_only = RPG::Page.new([c(101, "", 0, 0, 2), c(0)])
$game_map.events[12] = Game_Event.new(12, [talk_only])
sharing = MGQ_MpCoop::Scope.method(:sharing?)
MGQ_MpCoop::Scope.define_singleton_method(:sharing?) { true }
$game_map.interpreter = Game_Interpreter.new
$log.clear
$game_map.interpreter.setup(talk_only.list, 12)
MGQ_MpCoopEvents.as_story { $game_map.interpreter.setup(talk_only.list, 12) }
$game_map.interpreter.setup(talk_only.list, 12)
MGQ_MpCoop::Scope.define_singleton_method(:sharing?, sharing)
check("a talk's page set up as story starts as story, said so, and only inside the block",
      $log.grep(/event 12 \(page 1\) on map \d+ starts as/).map { |line| line[/starts as (\w+)(: resumed as story)?/] },
      ["starts as talk", "starts as story: resumed as story", "starts as talk"])
