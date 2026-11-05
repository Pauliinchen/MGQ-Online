#----------------------------------------------------------------
#  coop_events_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Kept the screen of choices open through the script's open_screen
#                            - Set the sorts of its own lists, answered a Classic member's play with fixed values and dropped the Classic catch-up checks that replayed recorded answers
#      Paulinchen  2026-11-05: Answered the scopes of a Classic party and the companion filter with fixed values instead of from copies of the C# rules
#                            - Answered which of the leader's changes a member takes, the merge of a member's requests, the Medal King's gifts and whether an event leaves the part and what of the story changed with fixed values per case instead of from copies of the C# rules
#                            - Answered the Classic catch-up, the side, the key item loan and how a member plays the leader's story with the recorded answer of each call instead of from engine.rb
#                            - Answered the rewards tables with fixed fields instead of a stand-in of their constants
#                            - Expected the messages sent as the scripts hand them and took the recorded Classic party's table
#                            - Answered a resumed fight's page with a fixed story sort
#                            - Answered the calls, pages, telling machine and choices with fixed values and checked what goes to the DLL and what the scripts do with its answers
#                            - Handed and expected sites as plain values
#                            - Handed and expected the story's keys and values as [kind, key] with values, the self switches a sort needs as the game keys them
#                            - Sent and took the story's messages with their fields as values, the DLL writing the whole story and what of it changed
#                            - Stood in for the world room's sending through its port
#                            - Checked that every caller asks the DLL's one decision, and left the player's own common events and the Library's replay to it
#                            - Checked that an event ended early or kept from starting goes to the one guard of the game's flow, in place of the fade-ins on frame timers
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
#                            - Read the scripts' clock from $frame_count and dropped the check of a refusal from before a loaded save, since the clock never goes back
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
# chests, gathering for story scenes, and story events played in the leader's game. The DLL's calls,
# pages, telling machine and choices answer with the fixed values each check sets
# (telling_support.rb); their rules are the C# tests' to cover.

require_relative "support"
require_relative "rules_support"

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
  def self.tell(seat, fields, body = ""); Port.send_to(seat, fields, body); end
  def self.who(peer); peer == :me ? "the player" : "#{peer && peer.state['name']}"; end
  # The other players this game knows, each a Peer: their seat, state, ghost and whether they were
  # in the player's party.
  module Peers; Peer = Struct.new(:seat, :state, :ghost, :member); end
  # The world room's sending to the other games.
  module Port
    # Notes each message sent in $sent, its seat and fields as the scripts hand them.
    def self.send_to(seat, fields, body)
      $sent << [seat, sent_message(fields, body).reject { |key, _| key == :payload }]
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
# Stands in for the screen: the brightness from $brightness; the scripts' clock reads $frame_count.
module Graphics; def self.brightness; $brightness || 255; end; end
clock_from { $frame_count }
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
    MGQ_MpOverworldSync::Port.send_to(seat, { field => value, "party" => Party.id }.merge(fields), "")
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
open_rules_bridge
# Stands in for the one guard of the game's flow (coop_flow.rbx), noting in $flow what the events
# hand it.
module MGQ_MpFlowGuard
  def self.cut(list, index, reason); ($flow ||= []) << [:cut, list.size, index, reason]; end
  def self.skipped(list, what); ($flow ||= []) << [:skipped, list.size, what]; end
  def self.leave(reason, whole = false, elsewhere = false); ($flow ||= []) << [:leave, reason, whole, elsewhere]; end
end

# The DLL's answers of how a Classic party's member plays the leader's story (ClassicStory), as
# fixed values: in step with the leader, catching up with the story played together.
CLASSIC_ANSWERS = {
  "catchup.classic_sync" => { "state" => "synced", "route" => nil },
  "catchup.classic_followers" => { "tell" => [], "told" => {} },
  "catchup.classic_mode" => { "mode" => "catch_up", "keeps" => true, "progress" => "played", "ahead" => [] },
  "catchup.classic_restore" => { "steps" => [["start", "played"], ["personal", "played"]] },
}.freeze
CLASSIC_ANSWERS.each { |topic, answer| $world_bridge.answer(topic) { |_request| answer } }

# The DLL's answer which of the leader's changes a member takes (StoryTopics.ClassicFollowOf over
# ClassicMerge.Follows): every key but those each player keeps as their own in these checks, the side
# switches, the outcomes of the Magistea Village choice and the party chests a member opened.
MEMBER_KEEPS = [[0, 4], [0, 5], [0, 2096], [0, 2097], [2, [3, 5, "A"]], [2, [40, 1, "A"]], [2, [40, 2, "A"]], [2, [50, 3, "A"]], [2, [50, 3, "B"]], [2, [50, 4, "A"]], [2, [50, 5, "A"]],
                [2, [50, 6, "A"]]].freeze
$world_bridge.answer("story.classic_follow") { |request| request["keys"].map { |key| !MEMBER_KEEPS.include?(key) } }

# The DLL's scopes of a Classic party (story.replay_scopes) for the recorded Classic table, as runs
# [from, to, scope]: 0 each player's own, 2 the party's, 3 the world's.
CLASSIC_SCOPE_SWITCHES = [[0, 0, 0], [1, 3, 3], [4, 5, 0], [6, 21, 3], [22, 22, 0], [23, 72, 3], [73, 73, 0], [74, 93, 3], [94, 95, 0], [96, 96, 3], [97, 97, 0],
                          [98, 99, 3], [100, 100, 0], [101, 444, 3], [445, 447, 0], [448, 501, 3], [502, 502, 0], [503, 1000, 3], [1001, 2000, 0],
                          [2001, 5999, 3], [6000, 6999, 0], [7000, 7101, 3], [7102, 7104, 2], [7105, 9999, 3]].freeze
CLASSIC_SCOPE_VARIABLES = [[0, 0, 0], [1, 8, 3], [9, 9, 0], [10, 20, 3], [21, 23, 0], [24, 45, 3], [46, 48, 0], [49, 54, 3], [55, 57, 0], [58, 58, 3], [59, 59, 0],
                           [60, 128, 3], [129, 129, 0], [130, 149, 3], [150, 150, 0], [151, 199, 3], [200, 201, 0], [202, 1001, 3], [1002, 1002, 0],
                           [1003, 1999, 3], [2000, 3999, 0], [4000, 4999, 3]].freeze
# The party chests of the checks' rewards, which the DLL scopes as the party's.
CLASSIC_PARTY_CHESTS = [[3, 5, "A", 2], [3, 6, "C", 2], [4, 6, "C", 2]].freeze

# The DLL's scopes of a Classic party, fresh each time, as a check may change them.
#
# @return [Hash] The scopes, see MGQ_MpStoryKeys.scopes_of.
def classic_scopes
  story_table_hash(CLASSIC_SCOPE_SWITCHES, CLASSIC_SCOPE_VARIABLES, MGQ_MpStoryKeys::SCOPE_WORLD, "keys" => CLASSIC_PARTY_CHESTS.map(&:dup))
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

# Sorting events is MGQOnline.Game's EventSorter, which MGQOnline.Game.Tests checks; here the DLL
# answers each list the checks below hand over as these sorts.
castle_tour = [c(201, 0, 228, 24, 36, 0, 0), c(101, "", 0, 0, 2), c(401, "Wow, it's huge!"), c(121, 2013, 2013, 1), c(121, 2015, 2015, 0)]
blacksmith = [c(101, "", 0, 0, 2), Command.new(102, 0, [["Synthesis", "Talk"], 2]),
              Command.new(402, 0, [0, "Synthesis"]), Command.new(355, 1, ["call_synthesize(14)"]), Command.new(0, 1, []),
              Command.new(402, 0, [1, "Talk"]), Command.new(101, 1, ["", 0, 0, 2]), Command.new(122, 1, [1007, 1007, 0, 0, 1]), Command.new(0, 1, []),
              Command.new(404, 0, [])]
# The sort of a talk that only says something.
SAYS = { "kind" => "talk", "list_kind" => "talk", "may_tell" => false, "scene" => false, "marks" => ["says"] }.freeze
# The sort of a story scene that says something and sets a switch.
SCENE = { "kind" => "story", "list_kind" => "story", "may_tell" => false, "scene" => true, "marks" => ["says", "sets"] }.freeze
# The sort of a chest that gives an item and turns its own self switch.
CHEST = { "kind" => "chest", "list_kind" => "chest", "may_tell" => false, "scene" => false, "marks" => ["gives", "own_switch"] }.freeze
# The sort of a transfer with a few words.
TRAVEL = { "kind" => "travel", "list_kind" => "travel", "may_tell" => false, "scene" => false, "marks" => ["says", "travel"] }.freeze
sorted_as([[101, 0, ["", 0, 0, 2]]], SAYS)
sorted_as([[101, 0, ["", 0, 0, 2]], [0, 0, []]], SAYS)
sorted_as([[101, 0, ["", 0, 0, 2]], [121, 0, [60, 60, 0]]], SCENE)
sorted_as([[101, 0, ["", 0, 0, 2]], [401, 0, ["Line"]], [121, 0, [60, 60, 0]]], SCENE)
sorted_as([[126, 0, [1, 0, 0, 2]], [123, 0, ["A", 0]]], CHEST)
sorted_as([[111, 0, [12, "unlock_level < 1"]], [101, 0, ["", 0, 0, 2]], [115, 0, []], [123, 0, ["A", 0]], [126, 0, [1, 0, 0, 1]]], CHEST.merge("marks" => ["gives", "own_switch", "says"]))
sorted_as(castle_tour, TRAVEL)
smithy = blacksmith + [Command.new(0, 0, [])]
sorted_as(smithy, SAYS.merge("may_tell" => true, "marks" => ["choice_story", "says"]))
sorted_as(smithy, { "story" => false }, 3)
sorted_as(smithy, { "story" => true }, 7)
choice_travel = [[101, 0, ["", 0, 0, 2]], [102, 0, [["Not yet", "Decided"], 2]], [402, 0, [0, "Not yet"]], [0, 1, []], [402, 0, [1, "Decided"]],
                 [122, 1, [1007, 1007, 0, 0, 40]], [201, 1, [0, 430, 25, 20, 8, 0]], [0, 1, []], [404, 0, []], [0, 0, []]]
sorted_as(choice_travel, TRAVEL.merge("may_tell" => true, "marks" => ["choice_story", "says", "travel"]))
sorted_as(choice_travel, { "story" => false }, 2)
sorted_as(choice_travel, { "story" => true }, 5)
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
$world_bridge.answer("events.kinds") { |request| kinds_asked << request["pages"]; set_kinds(request) }
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
$world_bridge.answer("story.rewards") { |_known| party_rewards("chests" => [[3, 6, "C"], [4, 6, "C"]], "rev" => 2) }
MGQ_MpStoryState.instance_variable_set(:@rewards_at, nil)
check("once the relay's rewards came, the map's chests are those of every chest it keeps, a chest behind a branch a new game skips among them",
      MGQ_MpCoopEvents.chest_keys, [[3, 6, "C"]])
check("and a chest the database names that the relay's reviewed rows leave out is no player's own",
      [MGQ_MpCoopEvents.chest_key?([3, 5, "B"]), story.personal_self_switch?([3, 5, "B"])], [false, false])
# From here the relay keeps the chest of the test's map among every chest of the game.
answer_party_rewards($world_bridge)
$world_bridge.answer("story.rewards") { |_known| party_rewards("chests" => [[3, 5, "A"]]) }
rewards_changed
answer_events($world_bridge)
MGQ_MpCoopEvents.instance_variable_set(:@chest_keys_map, nil)

# The DLL reads a map event's page or a common event from its events database while the database
# holds the list as the game does: the scripts name it with its length and shape, the 24-bit hash
# both sides compute alike. A common event's list and a list handed over name the map and event
# that run it, inside whose map folder the list's transfers lead.
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
  found = request["party"] ? classic_scopes : { "switches" => "\0" * 30, "variables" => "\0" * 10, "keys" => [], "self" => [], "common" => [], "index" => [], "self_default" => 0 }
  found["keys"] += [[3, 5, "A", 2], [3, 8, "A", 2], [3, 9, "A", 2]] if request["party"]
  found["switches"].setbyte(22, MGQ_MpStoryKeys::SCOPE_WORLD)
  found
end
MGQ_MpStoryKeys.instance_variable_set(:@scopes, nil)
$world_bridge.answer("story.replay_reads") { |_request| [] }
$world_bridge.answer("story.replay_ran") { |request| $ran << request; { "id" => "e#{$ran.size}", "site" => request["site"], "scope" => "party", "stream" => request["party_stream"] } }
$world_bridge.answer("story.replay_wire") { |entry| "WIRE:#{entry['id']}" }
# Stands in for the DLL's writing of a whole story (ClassicStoryLists.Full), which always fits a
# message here.
$world_bridge.answer("story.classic_full") { |lists| { "z" => lists, "part" => false } }
# The DLL's writing of what of the story changed (ClassicStoryLists.Delta, ClassicStoryListsTests),
# as each case sets it, and the writes it got.
$deltas = []
delta_asks = []
$world_bridge.answer("story.classic_delta") { |writes| delta_asks << writes; $deltas.shift }

# Writes a leader's whole story as the DLL hands its message to a member.
#
# @param lists [Hash] The lists, see MGQ_MpStoryState.story_lists.
# @param more [Hash] Other fields of the message.
# @return [Hash] The message.
def whole_story(lists, more = {})
  { "story" => "full", "party" => "p1", "z" => lists }.merge(more)
end

# Writes what of a leader's story changed as the DLL hands its message to a member.
#
# @param kind [String] "delta", or "req" for a member's requests.
# @param changes [Hash] "s", "v" and "ss", see MGQ_MpStoryState.decode_delta, none for those left out.
# @return [Hash] The message.
def story_changes(kind, changes)
  { "story" => kind, "party" => "p1", "s" => [], "v" => [], "ss" => [] }.merge(changes)
end
$world_bridge.answer("story.replay_unwire") do |text|
  id = text.sub("WIRE:", "")
  world = id.start_with?("w")
  { "id" => id, "site" => ["map", 4, 9, 1], "scope" => world ? "world" : "party", "stream" => world ? "story" : "party:p1", "place" => world ? [12, 0, 0, 0] : nil,
    "keys" => world ? [[0, 2280, false]] : [[2, [4, 9, "A"], false]] }
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
      [[[-1, "WIRE:e1"]], [["map", 3, 5, 1], [[2, [3, 5, "A"], false, true]], true, "party:p1"]])
$sent.clear
$game_map.events[9] = Game_Event.new(9, [RPG::Page.new([c(123, "A", 0), c(126, 1, 0, 0, 1), c(121, 22, 22, 0)])])
MGQ_MpCoopEvents.instance_variable_set(:@chest_keys_map, nil)
$game_map.interpreter.setup($game_map.events[9].list, 9)
$game_map.interpreter.run
check("a chest that also turns on a world switch reaches the party all the same",
      [$sent.map { |seat, f| [seat, f["replay"]] }, $ran.last.values_at("changed", "owner", "party_stream")],
      [[[-1, "WIRE:e2"]], [[[2, [3, 9, "A"], false, true], [0, 22, false, true]], true, "party:p1"]])
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
$deltas = [{ "s" => [[2280, true]], "v" => [[1050, 32]], "ss" => [] }]
MGQ_MpCoopStory::SEND_FRAMES.times { MGQ_MpCoopStory.update }
check("as leader, the party hears the story's writes the player's game made in one change, the last of each, each player's own left out",
      [delta_asks.last, $sent.select { |_, f| f["story"] == "delta" }.map { |seat, f| [seat, f["s"], f["v"], f["ss"]] }],
      [[[0, 2280, true], [1, 1050, 32]], [[-1, [[2280, true]], [[1050, 32]], []]]])
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
MGQ_MpCoopEvents.hand_entry("id" => "w1", "site" => ["map", 4, 9, 1], "scope" => "world", "stream" => "story")
check("as leader, a run of the story that changed a world key goes to every member as its entry", $sent.map { |seat, f| [seat, f["replay"]] }, [[-1, "WIRE:w1"]])

# Chests while playing the leader's story.
leader = MGQ_MpOverworldSync::Peers::Peer.new(4, { "id" => "l", "name" => "Leader", "party" => "p1" }, nil, true)
$leader = leader
$members = [leader]
raw($game_self_switches)[[3, 5, "A"]] = nil
MGQ_MpCoopStory.take(leader, whole_story("ss" => [[3, 5, "A"], [3, 1, "B"]]))
check("a member's chests stay their own on the leader's story", [raw($game_self_switches)[[3, 5, "A"]], raw($game_self_switches)[[3, 1, "B"]]], [nil, true])
MGQ_MpCoopStory.take(leader, story_changes("delta", "ss" => [[[3, 5, "A"], true]]))
check("and the leader's chests do not change them", raw($game_self_switches)[[3, 5, "A"]], nil)
MGQ_MpCoopEvents.take_entry(leader, { "replay" => "WIRE:w2", "party" => "p1" })
MGQ_MpCoopEvents.take_entry(friend, { "replay" => "WIRE:w3", "party" => "p1" })
MGQ_MpCoopEvents.take_entry(leader, { "replay" => "WIRE:w7", "party" => "p1", "opener" => "Friend" })
check("a member who follows the leader's story waits to play the leader's run in their own game, in the stream of the leader's story, not of their own, named by who ran it",
      MGQ_MpStoryReplay.waiting.map { |entry| entry.values_at("id", "stream", "opener", "place") },
      [["w2", "story:l", "Leader", [12, 0, 0, 0]], ["w7", "story:l", "Friend", [12, 0, 0, 0]]])
MGQ_MpStoryReplay.waiting.clear
$sent.clear
MGQ_MpCoopEvents.hand_entry("id" => "w4", "site" => ["map", 4, 9, 1], "scope" => "world", "stream" => "story")
check("a member's own run of the story waits to go to the leader with their requests", $sent, [])
$game_map.interpreter.setup(chest_page.list, 5)
$game_map.interpreter.run
check("a chest a member opens is theirs for good, in their own story kept aside too", MGQ_MpCoopStory.own_story_aside[2][[3, 5, "A"]], true)

# A member's writes of the leader's story go to the leader as requests (A4); the leader's story is
# the one truth, takes them by the list's merge kinds (variable 1020 one way), as the DLL's
# ClassicMerge decides over the list's scopes and classes, and sends back what it keeps by value.
$world_bridge.answer("story.classes") { story_table_hash([[0, 9999, 1]], [[0, 1019, 1], [1020, 1020, 3], [1021, 4999, 1]], 1) }
# The DLL's merge of a member's requests (StoryTopics.ClassicMergeOf over ClassicMerge, whose
# ClassicMergeTests cover it): the leader's story takes the switch and refuses variable 1020's way
# back, so the run that changed the switch is kept; a second request changes nothing.
merge_asks = []
merges = [{ "takes" => [true, false], "keeps" => [true] }, { "takes" => [true], "keeps" => [false] }]
$world_bridge.answer("story.classic_merge") { |request| merge_asks << request; merges.shift }
MGQ_MpCoopStory.update
MGQ_MpCoopStory.take(leader, whole_story({}))
$sent.clear
MGQ_MpCoopStory.update
$deltas = [{ "s" => [[2280, true]], "v" => [[1020, 3]], "ss" => [] }]
$game_switches[2280] = true
$game_variables[1020] = 3
$game_variables[3001] = 9
MGQ_MpStoryKeys.flush
MGQ_MpCoopEvents.hand_entry("id" => "w8", "site" => ["map", 4, 9, 1], "scope" => "world", "stream" => "story")
MGQ_MpCoopStory::SEND_FRAMES.times { MGQ_MpCoopStory.update }
check("a member's writes of the leader's story go to the leader as requests, each player's own left out, with the member's runs of it",
      $sent.select { |_, f| f["story"] == "req" }.map { |seat, f| [seat, f["s"], f["v"], f["ss"], f["runs"]] }, [[4, [[2280, true]], [[1020, 3]], [], ["WIRE:w8"]]])
$leader = :me
$members = [friend]
MGQ_MpCoopStory.update
raw($game_switches)[2280] = false
raw($game_variables)[1020] = 5
$sent.clear
$deltas = [{ "s" => [[2280, true]], "v" => [[1020, 5]], "ss" => [] }]
MGQ_MpCoopStory.take(friend, story_changes("req", "s" => [[2280, true]], "v" => [[1020, 3]], "runs" => ["WIRE:w5"]))
MGQ_MpCoopStory::SEND_FRAMES.times { MGQ_MpCoopStory.update }
check("the leader's story takes a member's write and sends it back to everyone by value, and a write it refuses comes back as it keeps it",
      [raw($game_switches)[2280], raw($game_variables)[1020], $sent.select { |_, f| f["story"] == "delta" }.map { |seat, f| [seat, f["s"], f["v"]] }],
      [true, 5, [[-1, [[2280, true]], [[1020, 5]]]]])
check("asking the DLL with the writes, the values the leader's story holds and the runs",
      merge_asks.first.values_at("writes", "runs").map { |list| list.map { |entry| entry.is_a?(Hash) ? entry["id"] : entry } }, [[[0, 2280, false, true], [1, 1020, 5, 3]], ["w5"]])
check("a member's run whose writes changed the leader's story goes to the party in the leader's stream, named by its opener, and plays in the leader's game too",
      [$sent.select { |_, f| f["replay"] }.map { |seat, f| [seat, f["replay"], f["opener"]] },
       MGQ_MpStoryReplay.waiting.map { |entry| entry.values_at("id", "stream", "opener") }],
      [[[-1, "WIRE:w5", "Friend"]], [["w5", MGQ_MpStoryKeys.story_stream(:me), "Friend"]]])
MGQ_MpStoryReplay.waiting.clear
$sent.clear
MGQ_MpCoopStory.take(friend, story_changes("req", "s" => [[2280, true]], "runs" => ["WIRE:w6"]))
check("one whose writes changed nothing of it goes to nobody", [$sent.select { |_, f| f["replay"] }, MGQ_MpStoryReplay.waiting], [[], []])
MGQ_MpCoopStory.take(MGQ_MpOverworldSync::Peers::Peer.new(8, { "id" => "s", "party" => "p9" }, nil, false),
                     story_changes("req", "s" => [[2281, true]]))
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
check("and gathers it for a story scene", $sent.map { |seat, f| [seat, f["pevent"], f["map"]] }, [[-1, "gather", 9]])
$sent.clear
$game_map.interpreter.setup([c(101, "", 0, 0, 2)], 1)
Game_Interpreter.new.setup([c(101, "", 0, 0, 2), c(121, 60, 60, 0)], 1)
check("but not for a talk, or for other interpreters", $sent.size, 0)
$game_map.interpreter.setup([c(101, "", 0, 0, 2), c(121, 60, 60, 0)])
check("a common event, set up with its list alone, gathers the party for its story scene too", $sent.map { |seat, f| [seat, f["pevent"], f["map"]] }, [[-1, "gather", 9]])
$sent.clear
$own_commons = [114]
$data_common_events[114] = RPG::CommonEvent.new([c(101, "", 0, 0, 2), c(121, 60, 60, 0)])
MGQ_MpCoopEvents.instance_variable_set(:@common_ids, nil)
$game_map.interpreter.setup($data_common_events[114].list)
check("a common event the DLL's decision names the player's own, as the game's transfer process, gathers nobody", [$sent, MGQ_MpCoopEvents.telling?], [[], false])
$data_common_events[114] = nil
$own_commons = []

$leader = leader
$members = [leader]
$game_map.map_id = 3
$game_player.moveto(1, 1)
MGQ_MpCoopEvents.take(leader, { "pevent" => "travel", "party" => "p1", "map" => "7", "x" => "2", "y" => "2", "d" => "4" })
$game_map.update
$game_map.update
check("a member stays when the leader goes to another map", $game_player.reserved, nil)
MGQ_MpCoopEvents.take(friend, { "pevent" => "gather", "party" => "p1", "map" => "7", "x" => "2", "y" => "2", "d" => "4" })
check("only the leader calls the party to a story scene", $tells.asked("gather.called"), [])
$game_map.map_id = 7
$game_player.moveto(2, 2)

# A member called to the leader's story scene, the calls standing as the DLL answers them.
# Has the DLL answer how the calls stand: as with none standing, but for the fields given.
calls = lambda do |fields|
  $tells.set("gather.frame", { "coming" => false, "pending" => nil, "notice" => nil, "come" => nil, "waited" => false, "follow" => nil, "holding" => false,
                               "doing" => nil, "idle" => false }.merge(fields))
  MGQ_MpCoopGather.refresh
end
$notices.clear
leader.state.merge!("map" => "8")
$tells.set("gather.called", "notice" => "Leader's story is starting. You join them in 5 seconds.")
calls.call("coming" => true, "doing" => { "text" => "Joining Leader", "left" => 300 })
MGQ_MpCoopEvents.take(leader, { "pevent" => "gather", "party" => "p1", "map" => "8", "x" => "9", "y" => "3", "d" => "6" })
$game_map.update
check("a member called to the story hands the DLL the leader's call and hears when they come over",
      [$tells.asked("gather.called").last, $notices.last, MGQ_MpCoopGather.own_doing],
      [{ "name" => "Leader", "id" => "l", "place" => [8, 9, 3, 6], "near" => false, "pvp" => false }, "Leader's story is starting. You join them in 5 seconds.",
       ["Joining Leader", 5.0]])
check("and is not moved before the DLL says where they come to", [$game_player.reserved, $game_map.map_id], [nil, 7])
$game_player.encounter_count = 5
check("a member about to come over meets no random encounter while steps are left", $game_player.encounter, false)
$game_player.encounter_count = 0
check("nor once they ran out, which draws new steps", [$game_player.encounter, $game_player.encounter_count], [false, 30])
calls.call("coming" => true, "come" => [8, 9, 3, 6])
$tells.set("gather.take", "name" => "Leader", "id" => "l", "place" => [8, 9, 3, 6], "follow" => false, "asked" => false, "bans" => [])
SceneManager.scene = Scene_Battle.new
$game_map.update
check("a member in battle comes once it is over", [$game_player.reserved, $tells.asked("gather.take").size], [nil, 0])
SceneManager.scene = Scene_Map.new
$brightness = 0
MGQ_MpCoopGather.refresh
MGQ_MpCoopGather.coming?
check("the calls are read with the map unsettled while the screen is still dark from the battle", $tells.asked("gather.frame").last["settled"], false)
$brightness = nil
$game_map.update
check("then they take the call and are brought to the leader's map", [$tells.asked("gather.take").size, $game_player.reserved], [1, [8, 9, 3, 6]])
$game_player.perform_transfer
calls.call({})
$game_player.encounter_count = 0
check("then random encounters come again", $game_player.encounter, true)
$notices.clear
MGQ_MpCoopEvents.take(leader, { "pevent" => "gather", "party" => "p1", "map" => "8", "x" => "11", "y" => "4", "d" => "6" })
check("a member standing near already tells the DLL so, which leaves them where they are",
      [$tells.asked("gather.called").last["near"], $notices, $game_player.x], [true, [], 9])
$tells.set("gather.take", nil)
$tells.set("gather.called", nil)

# While the leader's story scene plays, the member stands still.
check("free while the leader tells no story", [$game_player.movable?, MGQ_MpCoopGather.blocked?], [true, false])
leader.state["telling"] = true
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
leader.state["telling"] = false
scene.update_call_menu
check("free again once it ends", [$game_player.movable?, scene.menu_calling], [true, :asked])

# The leader's story scene waits for the party as the DLL's hold answers.
$leader = :me
$members = [friend]
$game_map.map_id = 3
$game_player.moveto(5, 5)
friend.state.merge!("map" => "9", "x" => "1", "y" => "1")
$frame_count = 1000
$sent.clear
$notices.clear
calls.call("holding" => true, "doing" => { "text" => "Gathering: Friend", "left" => 1800 })
interpreter = $game_map.interpreter
holds = $tells.asked("gather.hold").size
interpreter.setup([c(101, "", 0, 0, 2), c(121, 60, 60, 0)], 1)
check("a story scene has the DLL hold it and calls the members", [$tells.asked("gather.hold").size - holds, $sent.map { |seat, f| [seat, f["pevent"], f["map"], f["x"]] }, $notices.last],
      [1, [[-1, "gather", 3, 5]], "Gathering the party for the story . . ."])
interpreter.busy = true
$tells.set("gather.holding", "wait" => true, "call_again" => false, "notice" => nil, "released" => nil)
check("and waits while the DLL holds it, asked with the member away, telling no story meanwhile",
      [MGQ_MpCoopGather.holding?(interpreter), $tells.asked("gather.holding").last, MGQ_MpCoopGather.own_doing, MGQ_MpCoopEvents.state_fields["telling"]],
      [true, { "leading" => true, "gathered" => false, "missing" => ["Friend"] }, ["Gathering: Friend", 30.0], false])
check("the leader only waits for the party then, so the chat may open", MGQ_MpCoopGather.waiting?, true)
$sent.clear
$tells.set("gather.holding", "wait" => true, "call_again" => true, "notice" => nil, "released" => nil)
MGQ_MpCoopGather.holding?(interpreter)
check("calling the members again when the DLL says so", $sent.map { |_, f| f["pevent"] }, ["gather"])
check("other interpreters never wait", MGQ_MpCoopGather.holding?(Game_Interpreter.new), false)
friend.state.merge!("map" => "3", "x" => "7", "y" => "4")
$tells.set("gather.holding", "wait" => false, "call_again" => false, "notice" => "The party is here.", "released" => "the party is here after 3 s: the story starts")
check("once the DLL lets it go, with everyone near, the scene plays",
      [MGQ_MpCoopGather.holding?(interpreter), $tells.asked("gather.holding").last["gathered"], $notices.last, MGQ_MpCoopEvents.state_fields["telling"]],
      [false, true, "The party is here.", true])
calls.call({})
check("but no longer once the scene plays", MGQ_MpCoopGather.waiting?, false)
interpreter.busy = false
check("and the members are free once it ends", MGQ_MpCoopEvents.state_fields["telling"], false)
$sent.clear
holds = $tells.asked("gather.hold").size
interpreter.setup([c(101, "", 0, 0, 2), c(121, 60, 60, 0)], 1)
check("a party gathered already plays at once", [$sent.size, $tells.asked("gather.hold").size - holds, MGQ_MpCoopGather.holding?(interpreter)], [0, 0, false])
$tells.set("gather.holding", nil)

# The story moves the leader elsewhere, as a theater show's stage or a story's own teleport: the
# members who stood near come along at once, the others stay.
far_friend = MGQ_MpOverworldSync::Peers::Peer.new(5, { "id" => "g", "name" => "Far", "party" => "p1", "map" => "9" }, nil, true)
$members = [friend, far_friend]
friend.state.merge!("map" => "3", "x" => "6", "y" => "5")
$sent.clear
interpreter.busy = true
$game_player.reserve_transfer(624, 63, 27, 2)
$game_player.perform_transfer
check("the members near the leader are told to follow to the new place", $sent.map { |seat, f| [seat, f["pevent"], f["map"], f["x"], f["y"]] },
      [[2, "follow", 624, 63, 27]])
interpreter.busy = false
$sent.clear
$game_player.reserve_transfer(3, 5, 5, 2)
$game_player.perform_transfer
check("a transfer outside the story takes nobody along", $sent, [])
$leader = leader
$members = [leader]
$game_map.map_id = 7
$game_player.moveto(2, 2)
MGQ_MpCoopEvents.take(leader, { "pevent" => "follow", "party" => "p1", "map" => "624", "x" => "63", "y" => "27", "d" => "2" })
check("a member told to follow hands the DLL the leader's follow", $tells.asked("gather.followed").last,
      { "name" => "Leader", "id" => "l", "place" => [624, 63, 27, 2], "raid" => false })
calls.call("coming" => true, "come" => [624, 63, 27, 2], "follow" => { "id" => "l", "name" => "Leader", "place" => [624, 63, 27, 2] })
$tells.set("gather.take", "name" => "Leader", "id" => "l", "place" => [624, 63, 27, 2], "follow" => true, "asked" => false, "bans" => [])
check("and hears the leader's pages of the new map before arriving", [MGQ_MpCoopGather.story_map?(624), MGQ_MpCoopGather.story_map?(5)], [true, false])
$game_map.update
check("and comes along at once", $game_player.reserved, [624, 63, 27, 2])
$game_player.instance_variable_set(:@reserved, nil)

# The Pocket Castle's way out returns each player where they came from.
check("where the castle's way out returns is each player's own", (21..23).map { |id| MGQ_MpStoryState.personal_variable?(id) }, [true, true, true])
$game_map.map_id = 7
$game_player.moveto(12, 30)
$game_variables[21] = 1
calls.call("coming" => true, "come" => [126, 15, 14, 2])
$tells.set("gather.take", "name" => "Leader", "id" => "l", "place" => [126, 15, 14, 2], "follow" => true, "asked" => false, "bans" => [])
$game_map.update
check("a member the party brings into the castle returns where they stood", [21, 22, 23].map { |id| $game_variables[id] }, [7, 12, 30])
$game_player.instance_variable_set(:@reserved, nil)
$game_map.map_id = 126
MGQ_MpCoopCastle.arriving(229)
check("moving inside the castle keeps it", [21, 22, 23].map { |id| $game_variables[id] }, [7, 12, 30])
$game_map.map_id = 7
$tells.set("gather.take", nil)
calls.call({})

# A duel: a call during it is kept out, and one that waited through it is dropped as the duel puts
# the game back, so the leader's next call brings the player over on a settled map.
module MGQ_MpBattlesPvp; module Battle; def self.running?; $pvp; end; end; end
$pvp = true
$notices.clear
gather_call = { "pevent" => "gather", "party" => "p1", "map" => "9", "x" => "1", "y" => "1", "d" => "2" }
$tells.set("gather.called", "notice" => "Leader's story is starting. You join them in 5 seconds.")
MGQ_MpCoopEvents.take(leader, gather_call)
check("a call during a duel tells the DLL so and shows no notice", [$tells.asked("gather.called").last["pvp"], $notices], [true, []])
$pvp = false
$tells.set("gather.called", nil)
MGQ_MpCoopGather.drop_call("a PvP battle put the game back")
check("a duel's end has the DLL drop the call", $tells.asked("gather.drop_call").size, 1)

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
MGQ_MpCoopEvents.instance_variable_set(:@common_ids, nil)
$own_commons = [114]
check("but the game's transfer process runs in the member's own game", $game_map.setup_autorun_common_event, own_transfer)
$own_commons = []
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
# Has the DLL name each page shown the next page of session s and tell it, or keep it while told is
# false, its fields written of the page as the wire carries them; a page with no text is none.
pages_told = 0
tell_pages = lambda do |told = true|
  $tells.set("pages.show") do |request|
    next nil if request["lines"].empty? && request["choices"].empty?

    pages_told += 1
    id = "s.#{pages_told}"
    { "id" => id, "told" => told, "skipped" => 0, "note" => "#{request['lines'].size} lines",
      "fields" => { "page" => id, "face" => request["face"], "index" => request["index"], "background" => request["background"], "position" => request["position"],
                    "lines" => page_text(request["lines"]), "choices" => page_text(request["choices"]) } }
  end
end
# Has the DLL name the end of the page told last once, as the leader moves past it.
pass_pages = lambda do
  passed = nil
  $tells.set("pages.passed") { passed == pages_told ? nil : "s.#{passed = pages_told}" }
end
tell_pages.call
pass_pages.call
$sent.clear
$game_map.interpreter.setup(story_page.list, 11)
$game_message.face_name = "Alice"
$game_message.face_index = 2
$game_message.add("Hello, \\N[1]!")
$game_message.choices.push("Yes", "No")
$game_map.interpreter.wait_for_message
$game_message.clear
$game_map.interpreter.wait_for_message
check("the leader's story message hands the DLL its lines, choices and face, and that the skip is not held",
      $tells.asked("pages.show")[-2], { "lines" => ["Hello, \\N[1]!"], "choices" => ["Yes", "No"], "face" => "Alice", "index" => 2, "background" => 0, "position" => 0,
                                       "skip" => false })
says = $sent.select { |_, f| f["pevent"] == "say" }
check("and the page the DLL tells goes to the party once", says.size, 1)
say = says.first[1]
check("and once the leader moved on, that the page the DLL names is done", $sent.map { |_, f| [f["pevent"], f["page"]] }.select { |kind, _| %w[say done].include?(kind) },
      [["say", say["page"]], ["done", say["page"]]])
check("with its face, text and the leader's place", [say["face"], say["index"], say["map"], page_line(say["lines"].split(",")[0]), say["choices"].split(",").map { |t| page_line(t) }],
      ["Alice", 2, 7, "Hello, \\N[1]!", ["Yes", "No"]])
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
      [$tells.asked("pages.show")[-2]["lines"], $sent.select { |_, f| f["pevent"] == "say" }.map { |_, f| page_line(f["lines"]) }], [["A companion's line"], ["A companion's line"]])
Object.send(:remove_const, :MGQ_MpCoopScene)

# Holding the game's skip, the leader's pages go to the DLL marked so, and one it keeps goes out
# once it finds it due, with its end when the leader moved past it.
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
tell_pages.call(false)
$tells.set("pages.passed", nil)
pass_page.call("Skipped page")
check("holding the game's skip, a page goes to the DLL marked so, and one it keeps waits, asked each frame whether it is due",
      [$tells.asked("pages.show").last["skip"], told_pages.call, $tells.asked("pages.flush").last], [true, [], { "skip" => true, "telling" => true, "map" => true }])
$tells.set("pages.flush", "skipped" => 3, "passed" => true)
lines = logged_lines { $game_map.update }
check("once due, the page kept goes out with its end, logged with the pages left out before it",
      [told_pages.call.map { |_, kind, page, line| [kind, page, line] }, lines.grep(/left out the 3 page\(s\) before it the player skipped past/).size],
      [[["say", "s.#{pages_told}", "Skipped page"], ["done", "s.#{pages_told}", nil]], 1])
$tells.set("pages.flush", nil)
$sent.clear
pass_page.call("Kept page")
MGQ_MpCoopEvents.finished($game_map.interpreter)
$game_map.interpreter.busy = false
$game_map.update
check("the DLL is told once the story's event ended", $tells.asked("pages.flush").last, { "skip" => true, "telling" => false, "map" => true })
SceneManager.scene = Scene_Battle.new
$game_map.update
check("and once a battle is called", $tells.asked("pages.flush").last, { "skip" => true, "telling" => false, "map" => false })
$tells.set("pages.flush", "skipped" => 0, "passed" => false)
$game_map.update
$tells.set("pages.flush", nil)
SceneManager.scene = Scene_Map.new
$skipping = nil
tell_pages.call
pass_pages.call
$game_map.interpreter.setup(story_page.list, 11)
$game_map.interpreter.busy = true

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
heard = $tells.asked("pages.hear").size
$log.clear
2.times { MGQ_MpCoopEvents.take($leader, all_say) }
check("a member who plays their own story ignores it, saying so once",
      [$tells.asked("pages.hear").size - heard, $log.grep(/ignored say from Leader: not synced with the leader/).size], [0, 1])
MGQ_MpCoopStory.instance_variable_set(:@synced, synced)
$real_sync = nil
$leader = :me
$sent.clear
$game_message.clear
shown = $tells.asked("pages.show").size
$game_map.interpreter.setup(talk_page.list, 12)
$game_message.add("Just talk")
$game_map.interpreter.wait_for_message
check("a talk's message stays in the leader's game", [$tells.asked("pages.show").size - shown, $sent.select { |_, f| f["pevent"] == "say" }.size], [0, 0])
$tells.set("pages.show", nil)
$tells.set("pages.passed", nil)

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

# A member sees the leader's dialogue as the DLL hands its pages out.
$leader = leader
$members = [leader]
$game_message.clear
$game_message.busy = true
$tells.set("pages.hear", "lines" => 2, "choices" => 2, "waiting" => 1, "dropped" => 0)
$tells.set("pages.next", "show" => { "page" => say["page"], "face" => "Alice", "index" => 2, "background" => 0, "position" => 2,
                                     "lines" => ["Hello, \\N[1]!", "Leader chooses: Yes / No"] }, "skipped" => [], "passed" => [], "dropped" => 0, "waiting" => 0)
MGQ_MpCoopEvents.take(leader, say)
$game_map.update
check("a member hands the DLL the leader's page as it came, with the leader's name", $tells.asked("pages.hear").last,
      { "page" => say["page"], "name" => "Leader", "face" => "Alice", "index" => 2, "background" => 0, "position" => 0, "lines" => say["lines"], "choices" => say["choices"] })
check("and, busy with a message, sees it later", [$game_message.texts, $tells.asked("pages.next").size], [[], 0])
$game_message.busy = false
$game_map.update
check("then the page the DLL hands out, asked while sharing the story and nothing waits for the player",
      [$tells.asked("pages.next").last, $game_message.face_name, $game_message.texts],
      [{ "giving_way" => nil, "sharing" => true }, "Alice", ["Hello, \\N[1]!", "Leader chooses: Yes / No"]])
$tells.set("pages.next", nil)

# Only the leader moves the dialogue on, once the DLL finds the page over.
window = Window_Message.new
$own_pause = nil
$tells.set("pages.over", "over" => false, "reason" => nil, "wait" => nil)
pause = Fiber.new { window.process_input; :closed }
pause.resume
pause.resume
check("the member cannot move the leader's page on or close it while the DLL finds it not over",
      [pause.alive?, $own_pause, window.pause, $tells.asked("pages.over").last],
      [true, nil, true, { "teller" => "Leader", "telling" => false, "raid" => false, "giving_way" => nil, "confirm" => false, "skip" => false }])
over_asks = lambda { $tells.asked("pages.over").size }
asks = over_asks.call
5.times { $frame_count += 1; pause.resume }
check("a held page asks the DLL nothing more frame by frame while nothing changes", [over_asks.call - asks, window.pause], [0, true])
$tells.set("pages.over", "over" => false, "reason" => nil, "wait" => 20)
MGQ_MpCoopEvents.take(leader, { "pevent" => "done", "party" => "p1", "map" => "7", "x" => "0", "y" => "0", "d" => "2", "page" => say["page"] })
check("the leader moving on hands the DLL the page done and asks again", [$tells.asked("pages.done").last, pause.resume, over_asks.call - asks], [{ "page" => say["page"] }, nil, 1])
asks = over_asks.call
5.times { $frame_count += 1; pause.resume }
check("asking again only once the frames the DLL named passed", over_asks.call - asks, 0)
$tells.set("pages.over", "over" => true, "reason" => "the leader moved past it and the player read it")
$frame_count += 20
ended = $tells.asked("pages.ended").size
check("then it ends as the DLL says, which the DLL is told", [pause.resume, window.pause, $tells.asked("pages.ended").size - ended], [:closed, false, 1])
Fiber.new { window.process_input }.resume
check("then the member's own messages wait for their buttons again", $own_pause, true)
$tells.set("pages.next", "show" => { "page" => "s.0", "face" => "", "index" => 0, "background" => 0, "position" => 2, "lines" => ["Broken page"] },
                         "skipped" => [], "passed" => [], "dropped" => 0, "waiting" => 0)
MGQ_MpCoopEvents.take(leader, say.merge("page" => "s.0", "lines" => ["Broken page"].pack('m0'), "choices" => ""))
$game_message.clear
$game_map.update
$tells.set("pages.next", nil)
done = MGQ_MpCoopEvents.method(:page_done?)
MGQ_MpCoopEvents.define_singleton_method(:page_done?) { raise ArgumentError, "broken page" }
$own_pause = nil
closed = Fiber.new { window.process_input; :closed }.resume
MGQ_MpCoopEvents.define_singleton_method(:page_done?, done)
check("a page of the leader's story that fails to hold waits for the member as the game's own pages do",
      [$game_message.texts, closed, $own_pause, window.pause, MGQ_MpCoopEvents.mirroring?], [["Broken page"], :closed, true, false, false])
$game_message.clear
$tells.set("pages.next", "show" => { "page" => "s.5", "face" => "", "index" => 0, "background" => 0, "position" => 2, "lines" => ["Old page 5"] },
                         "skipped" => ["s.1", "s.2", "s.3", "s.4"], "passed" => [], "dropped" => 0, "waiting" => 1)
MGQ_MpCoopEvents.take(leader, say.merge("page" => "s.5", "lines" => ["Old page 5"].pack('m0'), "choices" => ""))
lines = logged_lines { $game_map.update }
check("a member shows the page the DLL hands out, logged with those it left out the leader moved past meanwhile",
      [$game_message.texts, lines.grep(/skipped pages s.1, s.2, s.3, s.4 of the leader's story: the leader moved past them while the player was busy/).size], [["Old page 5"], 1])
$tells.set("pages.next", nil)
$tells.set("pages.over", "over" => false, "reason" => nil, "wait" => nil)
$confirm = true
MGQ_MpCoopEvents.page_done?
$confirm = nil
$skipping = true
MGQ_MpCoopEvents.page_done?
$skipping = nil
leader.state["telling"] = true
MGQ_MpCoopEvents.page_done?
check("the DLL is asked again once the member confirms, holds the skip or the leader's telling changed",
      $tells.asked("pages.over").last(3).map { |request| request.values_at("confirm", "skip", "telling") }, [[true, false, false], [false, true, false], [false, false, true]])
leader.state["telling"] = false
$tells.set("pages.over", nil)
MGQ_MpCoopEvents.page_ended
$game_message.clear
$tells.set("pages.hear", nil)

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
leader.state.merge!("map" => "9", "telling" => false, "since" => "500", "trk" => "world")
$peers = [teller, stranger, behind, leader]
$tellings[6] = ["t1", 3, ["map", 3, 1, 1]]
check("a Raid World's parties lead no story: nobody borrows a leader's story or tells members one",
      [MGQ_MpCoopStory.leader, MGQ_MpCoopStory.real_synced_members, MGQ_MpCoopStory.real_follows_leader?], [nil, [], false])

raid_event = Game_Event.new(51, [story_page])
$game_map.events = { 51 => raid_event }
$notices.clear
check("a player telling the story on the map, party or not, keeps the player's story events from starting",
      [MGQ_MpCoopEvents.hand_over(raid_event), MGQ_MpCoopEvents.following?, $notices.last], [true, true, "Teller is telling the story here."])
heard = $tells.asked("pages.hear").size
$tells.set("pages.hear", "lines" => 1, "choices" => 0, "waiting" => 1, "dropped" => 0)
$tells.set("pages.next", "show" => { "page" => "r.1", "face" => "", "index" => 0, "background" => 0, "position" => 2, "lines" => ["Raid line"] },
                         "skipped" => [], "passed" => [], "dropped" => 0, "waiting" => 0)
MGQ_MpCoopEvents.take(teller, { "pevent" => "say", "map" => "3", "page" => "r.1", "lines" => ["Raid line"].pack("m0") })
$game_map.update
check("their pages go to the DLL and show for a player the relay told of the telling",
      [$tells.asked("pages.hear").size - heard, $tells.asked("pages.hear").last.values_at("page", "name"), $game_message.texts], [1, ["r.1", "Teller"], ["Raid line"]])
$tells.set("pages.next", nil)
$game_message.clear
MGQ_MpCoopEvents.page_ended
heard = $tells.asked("pages.hear").size
MGQ_MpCoopEvents.take(stranger, { "pevent" => "say", "map" => "3", "page" => "s.1", "lines" => ["Not told"].pack("m0") })
$tellings.delete(6)
MGQ_MpCoopEvents.take(teller, { "pevent" => "say", "map" => "3", "page" => "r.2", "lines" => ["Not on the track"].pack("m0") })
$game_map.update
check("but neither a player's who does not tell it, nor the teller's for a player the relay told of no telling, as one on another track",
      [$tells.asked("pages.hear").size - heard, $game_message.texts], [0, []])
$tells.set("pages.hear", nil)

raid_story = Game_Event.new(52, [story_page])
$game_map.events = { 52 => raid_story }
check("once nobody tells it here, the player's own story events start", MGQ_MpCoopEvents.hand_over(raid_story), false)
$sent.clear
# The telling machine's answer for a story event that starts: a new telling, held at its first
# command for the relay's telling lock while hold is set.
new_telling = lambda do |hold|
  $tells.set("telling.start") { |request| { "telling" => request["telling"], "continued" => nil, "from" => request["map"], "hold" => hold && request["telling"], "locked" => true } }
end
new_telling.call(true)
$tells.set("telling.command", "command" => "hold", "holder" => nil)
interpreter = $game_map.interpreter
interpreter.setup(story_page.list, 52)
interpreter.busy = true
check("the player tells it, alone too, and says so in their state",
      [MGQ_MpCoopGather.holding_story?, MGQ_MpCoopEvents.state_fields], [false, { "telling" => true }])
tell_pages.call
$game_message.add("Told line")
MGQ_MpCoopEvents.show(interpreter)
$tells.set("pages.show", nil)
check("its pages go through the map's gate in one message to the players on the map who play the player's track",
      $sent.map { |seat, fields| [seat, fields["map_pevent"], fields["mmap"], fields["mto"]] }, [[-1, "say", 3, ["t", "s"]]])
$game_message.clear
check("the DLL's telling machine hears of the event with its map and site, and its first command waits while the DLL holds it for the relay's lock",
      [$tells.asked("telling.start").last.values_at("telling", "by_itself", "map", "site"), MGQ_MpCoopEvents.lock_holding?(interpreter)],
      [[true, false, 3, ["map", 3, 52, 1]], true])
$tells.set("telling.command", "command" => "go", "holder" => nil)
check("and runs once the DLL says go", [MGQ_MpCoopEvents.lock_holding?(interpreter), MGQ_MpCoopEvents.telling?], [false, true])
ends = $tells.asked("telling.end").size
MGQ_MpCoopEvents.finished(interpreter)
interpreter.busy = false
$game_map.update
check("the DLL hears once the telling's event ended", $tells.asked("telling.end").size - ends, 1)
interpreter.setup(story_page.list, 52)
interpreter.busy = true
$tells.set("telling.command", "command" => "end", "holder" => 6)
$notices.clear
check("once the DLL says the relay refused the lock, the player's event ends before its first command, and the player hears who tells there",
      [MGQ_MpCoopEvents.lock_holding?(interpreter), interpreter.instance_variable_get(:@index), MGQ_MpCoopEvents.telling?, $notices.last],
      [false, story_page.list.size - 1, false, "Teller is telling the story here."])
MGQ_MpCoopEvents.finished(interpreter)
interpreter.busy = false
$game_map.update
interpreter.setup(story_page.list, 52)
interpreter.busy = true
$tells.set("telling.command", "command" => "unlocked", "holder" => nil)
$log.clear
check("one the DLL lets run without the lock runs, logged",
      [MGQ_MpCoopEvents.lock_holding?(interpreter), interpreter.instance_variable_get(:@index), MGQ_MpCoopEvents.telling?, $log.grep(/runs without the telling's lock/).size],
      [false, 0, true, 1])
MGQ_MpCoopEvents.finished(interpreter)
interpreter.busy = false
$game_map.update
# A talk that turns into story waits for the lock at the command that moves the story on.
$data_common_events = $data_common_events.dup
$data_common_events[8] = RPG::CommonEvent.new(trader)
$tells.set("telling.command", "command" => "hold", "holder" => nil)
interpreter.setup(trader)
interpreter.busy = true
interpreter.instance_variable_set(:@index, 7)
story_step = Fiber.new { interpreter.execute_command; :ran }
held = story_step.resume
$tells.set("telling.command", "command" => "go", "holder" => nil)
check("a talk that turns into story holds the command that moves the story on until the DLL says go",
      [held, MGQ_MpCoopEvents.telling?, story_step.resume, interpreter.instance_variable_get(:@index)], [nil, true, :ran, 7])
MGQ_MpCoopEvents.finished(interpreter)
interpreter.busy = false
$game_map.update
$tells.set("telling.command", "command" => "hold", "holder" => nil)
interpreter.setup(trader)
interpreter.busy = true
interpreter.instance_variable_set(:@index, 7)
story_step = Fiber.new { interpreter.execute_command; :ran }
story_step.resume
$tells.set("telling.command", "command" => "end", "holder" => 6)
check("and ends before that command once the relay refused it",
      [story_step.resume, interpreter.instance_variable_get(:@index), MGQ_MpCoopEvents.telling?], [:ran, trader.size - 1, false])
MGQ_MpCoopEvents.finished(interpreter)
interpreter.busy = false
$game_map.update
$data_common_events[8] = nil
$tells.set("telling.command", nil)
new_telling.call(false)
# The story's next event starts in the frame its last ended, which the DLL's telling machine finds
# going on with the telling.
interpreter.setup(story_page.list, 52)
interpreter.busy = true
$game_map.update
MGQ_MpCoopGather.instance_variable_set(:@taken_along, ["x"])
MGQ_MpCoopEvents.finished(interpreter)
$tells.set("telling.start", "telling" => true, "continued" => "frame", "from" => 3, "hold" => false, "locked" => true)
starts = $tells.asked("pages.telling_starts").size
$log.clear
interpreter.setup(story_page.list, 52)
check("a story event the DLL finds going on with the telling keeps whom it took along and the viewers on the player's track, logged",
      [MGQ_MpCoop::Scope.viewers, MGQ_MpCoopGather.instance_variable_get(:@taken_along), $tells.asked("pages.telling_starts").size - starts,
       $log.grep(/the story's next event goes on with the telling that started on map 3/).size], [[teller, stranger], ["x"], 0, 1])
interpreter.busy = false
$game_map.update
new_telling.call(false)
interpreter.setup(story_page.list, 52)
interpreter.busy = true
check("one it finds a new telling starts anew, which the DLL's pages hear", [MGQ_MpCoopGather.instance_variable_get(:@taken_along), $tells.asked("pages.telling_starts").size - starts], [nil, 1])
interpreter.busy = false
$game_map.update

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
# The DLL's check of what a story event writes (StoryTopics.LeavesPartTopic, whose rule
# PartEndTests covers): a page it knows only by its shape is unknown, so the scripts hand its list,
# whose answer each case sets in $leaving, a Hash or a block of the request. It counts its asks.
STAYS_IN_PART = { "leaves" => false, "why" => nil }.freeze
$leaving = STAYS_IN_PART
leave_asks = 0
$world_bridge.answer("story.leaves_part") do |request|
  leave_asks += 1
  next { "unknown" => true } unless request["list"]

  $leaving.respond_to?(:call) ? $leaving.call(request) : $leaving
end
# Writes the answer that an event's list ends the player's part.
#
# @param why [String] Why, such as "it sets s60".
# @param part [String] The part it ends.
# @return [Hash] The answer.
leaves_part = lambda { |why, part| { "leaves" => true, "why" => "#{why}, which leaves Part #{part}" } }
$behind = true
$peers = []
$notices.clear
MGQ_MpCoopEvents.instance_variable_set(:@refused, nil)
race_machine = Game_Event.new(57, [story_page])
check("a player behind the world's story starts story that stays in their part, as the race machine is", [MGQ_MpCoopEvents.hand_over(race_machine), $notices], [false, []])
$track_part = "2"
$leaving = leaves_part.call("it sets s60", 2)
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
chain_end = [750, 12, "A"]
$leaving = lambda do |request|
  known = request["values"]["ss"] && Hash[request["values"]["ss"]]
  next { "needs" => { "ss" => [chain_end] } } unless known

  known[chain_end] ? STAYS_IN_PART : leaves_part.call("its chain sets v1001", 2)
end
final_battle = Game_Event.new(58, [story_page], 3)
check("story whose chain across maps ends the part waits too, read with the self switch the DLL named",
      [MGQ_MpCoopEvents.hand_over(final_battle), $notices.size], [true, 1])
asks = leave_asks
MGQ_MpCoopEvents.hand_over(final_battle)
check("asked no more while that self switch stays", leave_asks - asks, 0)
$game_self_switches[[750, 12, "A"]] = true
check("and starts once it changed", MGQ_MpCoopEvents.hand_over(final_battle), false)
$game_self_switches[[750, 12, "A"]] = false
$leaving = leaves_part.call("it sets s60", 2)
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
$leaving = STAYS_IN_PART
check("a talk of a player behind goes on where its story stays in their part", guard_talk.call, [7, []])
$track_part = "3"
$leaving = leaves_part.call("it sets v1007", 3)
check("and ends where its story would end their part", guard_talk.call, [trader.size - 1, ["Reach level 25 to continue the story."]])
$track_part = "1"
$leaving = STAYS_IN_PART
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
# event there, through the game's transfer process between them, as the DLL's telling machine finds.
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
      [432, [[7, "follow", 430]], [stranger]])
check("and tells the DLL's telling machine the map it moves from, and the map it lands on while its event still runs",
      [$tells.asked("telling.moving").last, $tells.asked("telling.arrived").last], [{ "map" => 430 }, { "map" => 432 }])
MGQ_MpCoopEvents.finished(interpreter)
interpreter.busy = false
$game_map.update
transfer_process = RPG::CommonEvent.new([c(121, 20, 20, 0)])
$data_common_events[114] = transfer_process
MGQ_MpCoopEvents.instance_variable_set(:@common_ids, nil)
$own_commons = [114]
interpreter.setup(transfer_process.list)
interpreter.busy = true
check("the game's transfer process runs between its events in the player's own game, telling nothing, which the telling machine hears",
      [MGQ_MpCoopEvents.state_fields["telling"], MGQ_MpCoopGather.taken_along, $tells.asked("telling.start").last.values_at("telling", "by_itself")], [false, [], [false, true]])
$own_commons = []
MGQ_MpCoopEvents.finished(interpreter)
interpreter.busy = false
$game_map.update
$data_common_events[114] = nil
$tells.set("telling.start", "telling" => true, "continued" => "moved", "from" => 430, "hold" => false, "locked" => true)
$log.clear
interpreter.setup(story_page.list, 53)
interpreter.busy = true
check("a story event the DLL finds going on with the telling that moved the player keeps whom it took along, and the player tells it, without a hold",
      [MGQ_MpCoopEvents.state_fields, MGQ_MpCoopGather.taken_along, MGQ_MpCoop::Scope.viewers, $log.grep(/goes on with the telling that moved the player from map 430/).size,
       MGQ_MpCoopEvents.lock_holding?(interpreter)], [{ "telling" => true }, [stranger], [stranger], 1, false])
MGQ_MpCoopEvents.finished(interpreter)
interpreter.busy = false
$game_map.update
new_telling.call(false)

# A transfer outside a telling, such as a teleport, tells the telling machine nothing; a story event
# hands it whether it runs by itself, which alone may go on with the telling that moved the player.
$game_map.events = { 56 => Game_Event.new(56, [story_page]), 57 => Game_Event.new(57, [story_page], 3) }
moves = $tells.asked("telling.moving").size
$game_player.reserve_transfer(434, 0, 0, 2)
$game_player.perform_transfer
$game_map.update
check("a transfer outside a telling, such as a teleport, tells the telling machine nothing", $tells.asked("telling.moving").size - moves, 0)
interpreter.setup(story_page.list, 56)
interpreter.busy = true
started_by_player = $tells.asked("telling.start").last["by_itself"]
MGQ_MpCoopEvents.finished(interpreter)
interpreter.busy = false
$game_map.update
interpreter.setup(story_page.list, 57)
interpreter.busy = true
check("a story event the player starts tells the machine so, one that runs by itself too", [started_by_player, $tells.asked("telling.start").last["by_itself"]], [false, true])
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
$tellings[6] = ["t1", 430, ["map", 430, 1, 1]]
stranger.state["map"] = "3"
$peers = [teller, stranger]
MGQ_MpCoopEvents.page_ended
$game_message.clear
$notices.clear
$log.clear
calls.call("coming" => true, "follow" => { "id" => "t", "name" => "Teller", "place" => [432, 0, 0, 2] })
MGQ_MpCoopEvents.take(teller, { "pevent" => "follow", "map" => "432", "x" => "0", "y" => "0", "d" => "2" })
own_copy = Game_Event.new(57, [story_page], 3)
check("a follower on the way to where the teller's story moved them keeps their own copy of it, which runs by itself, from starting, silently",
      [MGQ_MpCoopEvents.hand_over(own_copy), MGQ_MpCoopEvents.hand_over(own_copy), $notices,
       $log.grep(/kept event 57 on map 430 from starting: the player follows Teller's story to map 432/).size],
      [true, true, [], 1])
check("the teller they follow stays the teller, whose telling the relay keeps on the map it left while the story's next event has yet to start",
      [MGQ_MpCoop::Scope.teller, MGQ_MpCoopEvents.following?], [teller, true])
heard = $tells.asked("pages.hear").size
$tells.set("pages.hear", "lines" => 1, "choices" => 0, "waiting" => 1, "dropped" => 0)
MGQ_MpCoopEvents.take(teller, { "pevent" => "say", "map" => "432", "page" => "m.1", "lines" => ["Moved line"].pack("m0") })
check("and their pages from the new map go to the DLL", [$tells.asked("pages.hear").size - heard, $tells.asked("pages.hear").last["page"]], [1, "m.1"])
calls.call("coming" => true, "come" => [432, 0, 0, 2], "follow" => { "id" => "t", "name" => "Teller", "place" => [432, 0, 0, 2] })
$tells.set("gather.take", "name" => "Teller", "id" => "t", "place" => [432, 0, 0, 2], "follow" => true, "asked" => false, "bans" => [])
$tells.set("pages.next", "show" => nil, "skipped" => [], "passed" => [], "dropped" => 0, "waiting" => 1)
$game_map.update
check("the player follows as soon as they are free, the pages asked for naming what waits for the player, and none shows before",
      [$game_player.reserved, $tells.asked("pages.next").last["giving_way"].nil?, $game_message.texts], [[432, 0, 0, 2], false, []])
$tells.set("gather.take", nil)
check("and starts no story event on the way either", [MGQ_MpCoopEvents.hand_over(own_copy), MGQ_MpCoop::Scope.teller], [true, teller])
$game_player.perform_transfer
calls.call("follow" => { "id" => "t", "name" => "Teller", "place" => [432, 0, 0, 2] })
$tells.set("pages.next", "show" => { "page" => "m.1", "face" => "", "index" => 0, "background" => 0, "position" => 2, "lines" => ["Moved line"] },
                         "skipped" => [], "passed" => [], "dropped" => 0, "waiting" => 0)
$game_map.update
check("arrived, the pages the DLL hands out show", $game_message.texts, ["Moved line"])
$tells.set("pages.next", nil)
$tells.set("pages.over", "over" => false, "reason" => nil, "wait" => nil)
class << MGQ_MpCoopGather; alias_method :due_before_check, :due?; def due?; true; end; end
MGQ_MpCoopEvents.page_done?
check("a page asks the DLL whether it is over naming what waits for the player while the story brings them over",
      $tells.asked("pages.over").last["giving_way"].nil?, false)
class << MGQ_MpCoopGather; alias_method :due?, :due_before_check; end
$tells.set("pages.over", nil)
$tells.set("pages.hear", nil)
MGQ_MpCoopEvents.page_ended
$game_message.clear
next_copy = Game_Event.new(2, [story_page], 3)
$game_map.map_id = 432
$tellings.delete(6)
check("arrived, their copy of the story's next event waits too while the relay tells of no telling of the teller's for a moment",
      [MGQ_MpCoopEvents.hand_over(next_copy), $log.grep(/kept event 2 on map 432 from starting: the player follows Teller's story to map 432/).size, MGQ_MpCoop::Scope.teller],
      [true, 1, teller])
$tellings[6] = ["t1", 432, ["map", 430, 1, 1]]
check("and once it tells of it again", [MGQ_MpCoopEvents.hand_over(next_copy), MGQ_MpCoop::Scope.teller], [true, teller])
$tellings.delete(6)
calls.call({})
check("the follow ends once the DLL names it no more", [MGQ_MpCoop::Scope.teller, MGQ_MpCoopEvents.hand_over(next_copy)], [nil, false])
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

# A frozen raid boss fight's resume runs its page as story, whatever it is sorted as otherwise: the
# DLL answers a page handed over as resumed with a story's sort.
$resumed_sort = SCENE
talk_only = RPG::Page.new([c(101, "", 0, 0, 2), c(0)])
$game_map.events[12] = Game_Event.new(12, [talk_only])
sharing = MGQ_MpCoop::Scope.method(:sharing?)
MGQ_MpCoop::Scope.define_singleton_method(:sharing?) { true }
$game_map.interpreter = Game_Interpreter.new
$log.clear
$game_map.interpreter.setup(talk_only.list, 12)
MGQ_MpCoopEvents.as_story { $game_map.interpreter.setup(talk_only.list, 12) }
$game_map.interpreter.setup(talk_only.list, 12)
check("a talk's page set up as story starts as story, said so, and only inside the block",
      $log.grep(/event 12 \(page 1\) on map \d+ starts as/).map { |line| line[/starts as (\w+)(: resumed as story)?/] },
      ["starts as talk", "starts as story: resumed as story", "starts as talk"])
# The fight's page may be one its event no longer shows, or of an event the map lacks now.
greeting = RPG::Page.new([c(101, "", 0, 0, 2), c(401, "Hello")])
$game_map.events[14] = Game_Event.new(14, [greeting])
$game_map.events[14].show(1)
$log.clear
MGQ_MpCoopEvents.as_story { $game_map.interpreter.setup(greeting.list, 14) }
MGQ_MpCoopEvents.as_story { $game_map.interpreter.setup(greeting.list, 99) }
MGQ_MpCoop::Scope.define_singleton_method(:sharing?, sharing)
$resumed_sort = nil
check("a fight resumed on a page its event no longer shows, or of an event the map lacks, starts as story too",
      $log.grep(/starts as/).map { |line| "#{line[/event 14 \(page 0\)|a common event/]} #{line[/starts as \w+/]}" },
      ["event 14 (page 0) starts as story", "a common event starts as story"])

# Every caller asks the DLL's one decision before it acts on a list: an event that starts, a story
# event the map would start, a common event that runs by itself, a talk watched before each command,
# and whom a Raid World's telling takes along, as it starts and as it moves its teller.
story_list = [c(101, "", 0, 0, 2), c(121, 60, 60, 0)]
asked = lambda do |&caller|
  MGQ_MpCoopEvents.instance_variable_set(:@answers, {})
  $world_bridge.calls.clear
  caller.call
  $world_bridge.calls.map(&:first).select { |topic| %w(events.sort story.moves).include?(topic) }.uniq
end
$await_world = true
story_event = Game_Event.new(13, [RPG::Page.new(story_list)])
$game_map.events[13] = story_event
autorun = RPG::CommonEvent.new(story_list)
interpreter = $game_map.interpreter
MGQ_MpGame.set(interpreter, :list, smithy)
MGQ_MpGame.set(interpreter, :index, 7)
check("every caller asks the DLL's one decision",
      [asked.call { $game_map.interpreter.setup(story_list, 0) },
       asked.call { MGQ_MpCoopEvents.hand_over(story_event) },
       asked.call { MGQ_MpCoopEvents.leave_to_leader?(autorun) },
       asked.call { MGQ_MpCoopEvents.instance_variable_set(:@may_tell, true); MGQ_MpCoopEvents.guard(interpreter) },
       asked.call { $raid = true; MGQ_MpCoopGather.note_story_progress; $raid = false },
       asked.call { MGQ_MpCoopGather.moves_story? }],
      [["events.sort"], ["events.sort"], ["events.sort"], ["events.sort"], ["story.moves"], ["story.moves"]])
$await_world = false
$game_map.events.delete(13)
