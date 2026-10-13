#----------------------------------------------------------------
#  coop_events_test.rb
#
#  Changelog:
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
  def setup(list, event_id = 0); @list = list; @event_id = event_id; end
  # Runs the commands that give items, set self switches and exit the event, the rest skipped.
  def run
    @list.each do |command|
      break if command.code == 115

      $game_party.gain_item($data_items[command.parameters[0]], command.parameters[3]) if command.code == 126
      $game_self_switches[[$game_map.map_id, @event_id, command.parameters[0]]] = command.parameters[1] == 0 if command.code == 123
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
module SceneManager; class << self; attr_accessor :scene; end; end
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
  def self.lapse_at(since, frames); lapse_in(since + frames - Graphics.frame_count); end
end
load_script "coop_scope"
load_script "story_state"
# The chest flags of coop_story_rewards.rbx, as the game has them; the rest of that table stays out,
# since these checks build their own stories.
CHEST_FLAGS = eval(File.read(File.join(SCRIPTS_DIR, "coop_story_rewards.rbx"), :encoding => "UTF-8")[/CHEST_FLAGS = (\[[\d, ]*\])/, 1])
# Lists the chest flags from CHEST_FLAGS, see MGQ_MpStoryState.chest_flags.
def MGQ_MpStoryState.chest_flags; CHEST_FLAGS; end
load_script "coop_story"
load_script "coop_events"
load_script "coop_gather"
load_script "coop_castle"

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

# Sorting events.
check("a plain conversation is a talk", kind([c(101, "", 0, 0, 2), c(401, "Hello")]), :talk)
check("a conversation with a companion's own lines and choices is a talk", kind([c(355, "actor_label_jump"), c(355, "unlimited_choices(3, [\"Give presents\"])")]), :talk)
check("the job change menu is a talk", kind([c(355, "SceneManager.call(Scene_JobChange)")]), :talk)
check("a shop is a talk", kind([c(302, 0, 1, 0, 0, false)]), :talk)
check("scratch switches and variables keep it a talk", kind([c(121, 20, 20, 0), c(122, 7, 7, 0, 0, 1)]), :talk)
check("affection keeps it a talk", kind([c(122, 3005, 3005, 1, 0, 5)]), :talk)
check("a story switch makes it story", kind([c(101, "", 0, 0, 2), c(121, 60, 60, 0)]), :story)
check("a recruiting switch makes it story", kind([c(121, 1500, 1500, 0)]), :story)
check("a novel scene makes it story", kind([c(355, "call_novel_scene(12)")]), :story)
check("an unknown script makes it story", kind([c(355, "$game_party.do_something")]), :story)
check("a script continued over lines is read whole", kind([c(355, "actor_label_jump"), c(655, "x")]), :talk)
check("a transfer is travel", kind([c(250, nil), c(201, 0, 5, 1, 1, 2, 0)]), :travel)
check("a forced transfer is travel", kind([c(355, "forced_transfer(1,2,3)")]), :travel)
pocket_castle = [c(101, "", 0, 0, 2), c(122, 21, 21, 0, 3, 7, 0, 0), c(122, 22, 22, 0, 3, 5, -1, 0), c(122, 23, 23, 0, 3, 5, -1, 1), c(201, 0, 126, 15, 14, 2, 1)]
check("the Pocket Castle item, which notes where it was used, is travel and no story scene", [kind(pocket_castle), MGQ_MpCoopEvents.scene?(pocket_castle)], [:travel, false])
check("items and the event's own switch make a chest", kind([c(126, 1, 0, 0, 1), c(123, "A", 0)]), :chest)
check("with a found-it message too", kind([c(101, "", 0, 0, 2), c(126, 1, 0, 0, 1), c(123, "A", 0)]), :chest)
check("and with a chest flag turned on, as the first Makina's (2045)", kind([c(126, 700, 0, 0, 1), c(123, "A", 0), c(121, 2045, 2045, 0)]), :chest)
check("but another story switch makes it story", kind([c(126, 700, 0, 0, 1), c(123, "A", 0), c(121, 60, 60, 0)]), :story)
check("its own switch with dialogue alone is a one-time talk", kind([c(101, "", 0, 0, 2), c(123, "A", 0)]), :talk)
check("its own switch without dialogue is story", kind([c(123, "A", 0), c(214)]), :story)
check("a fight without dialogue is a battle", kind([c(301, 0, 5, false, false), c(214)]), :battle)
check("a fight with dialogue is story", kind([c(101, "", 0, 0, 2), c(301, 0, 5, false, false)]), :story)
check("a called common event counts", kind([c(117, 1)]), :story)
check("common events calling each other end", kind([c(117, 6)]), :story)
$data_common_events[5] = RPG::CommonEvent.new([c(121, 60, 60, 0), c(301, 0, 5, false, false)])
check("the game's processing after every battle, common event 5, called at a talk's end leaves it a talk",
      kind([c(101, "", 0, 0, 2), c(401, "Hello"), c(117, 5)]), :talk)
check("and a story event story", kind([c(101, "", 0, 0, 2), c(121, 61, 61, 0), c(117, 5)]), :story)
check("as the map display and the Pocket Castle call, 2 and 3, and the transfer process, 114",
      [2, 3, 114].map { |id| $data_common_events[id] = $data_common_events[5]; kind([c(201, 0, 5, 1, 1, 2, 0), c(117, id)]) }, [:travel] * 3)
[2, 3, 5, 114].each { |id| $data_common_events[id] = nil }
(20..25).each { |id| $data_common_events[id] = RPG::CommonEvent.new([c(117, id + 1)]) }
$data_common_events[26] = RPG::CommonEvent.new([c(101, "", 0, 0, 2)])
check("a chain of common events too deep counts as story", kind([c(117, 20)]), :story)
check("its end called from higher up is sorted by what it does", kind([c(117, 24)]), :talk)
story = MGQ_MpStoryState
check("the awakening switches are the player's own, the story's boss flags from 7000 are not", [6500, 6999, 7015].map { |id| story.personal_switch?(id) }, [true, true, false])

# The Pocket Castle's residents are talks there, whatever their talk sets.
$game_map = Game_Map.new
companion = [c(101, "", 0, 0, 2), c(401, "\\n<Vanilla (Affection:\\V[3005])>Hello"), c(355, "call_novel_scene(12)"), c(121, 60, 60, 0)]
inn = [c(101, "", 0, 0, 2), c(401, "A stuffed animal is watching over the inn."), c(117, 270)]
coin_shop = [c(355, "@goods = []"), c(121, 60, 60, 0)]
castle_story = [c(101, "", 0, 0, 2), c(401, "\\n<Sphinx>The Yellow Orb..."), c(355, "actor_label_jump"), c(121, 60, 60, 0)]
$game_map.map_id = 228
check("in the Pocket Castle a companion's talk, the inn and the coin shop are talks", [kind(companion), kind(inn), kind(coin_shop)], [:talk, :talk, :talk])
check("its story events stay story", kind(castle_story), :story)
$game_map.map_id = 7
check("outside the castle a companion's novel scene stays story", kind(companion), :story)

# An exit that notes a flag on the way, as Iliasville's north exit notes Sonya, is travel.
exit_page = RPG::Page.new([c(250, nil), c(201, 0, 6, 5, 66, 2, 0), c(111, 0, 60, 0), c(121, 60, 60, 0), c(412)])
talking_exit = RPG::Page.new([c(101, "", 0, 0, 2), c(201, 0, 6, 5, 66, 2, 0), c(121, 60, 60, 0)])
$game_map.events = { 21 => Game_Event.new(21, [exit_page]), 22 => Game_Event.new(22, [exit_page], 3), 23 => Game_Event.new(23, [talking_exit]) }
check("an exit that notes a story switch on the way is travel", MGQ_MpCoopEvents.kind($game_map.events[21]), :travel)
check("the same page running by itself stays story", MGQ_MpCoopEvents.kind($game_map.events[22]), :story)
check("an exit with dialogue stays story", MGQ_MpCoopEvents.kind($game_map.events[23]), :story)

# An exit holding the story's warning in a branch, as Iliasville's do, is story only while the
# branch can run: here while the story's progress (variable 1001) is 7, or switch 61 is off.
$game_switches = Game_Switches.new
$game_variables = Game_Variables.new
warning_exit = RPG::Page.new([
  Command.new(111, 0, [1, 1001, 0, 7, 0]), Command.new(101, 1, ["", 0, 0, 2]), Command.new(121, 1, [60, 60, 0]), Command.new(115, 1, []), Command.new(0, 1, []),
  Command.new(412, 0, []),
  Command.new(111, 0, [0, 61, 0]), Command.new(0, 1, []), Command.new(411, 0, []), Command.new(101, 1, ["", 0, 0, 2]), Command.new(121, 1, [62, 62, 0]), Command.new(0, 1, []),
  Command.new(412, 0, []),
  c(201, 0, 2, 296, 355, 0, 0)])
$game_map.events = { 24 => Game_Event.new(24, [warning_exit]) }
$game_variables[1001] = 7
$game_switches[61] = true
check("while its warning can show, the exit is story", MGQ_MpCoopEvents.kind($game_map.events[24]), :story)
$game_variables[1001] = 12
check("once the story moved past it, the exit is travel", MGQ_MpCoopEvents.kind($game_map.events[24]), :travel)
$game_switches[61] = false
check("a branch's else runs when its condition fails", MGQ_MpCoopEvents.kind($game_map.events[24]), :story)

# Traders: a shop calling a side quest's common event, as Vanilla's supply quest in Magistea, is a
# talk while the quest cannot run; a shop listing its goods in a script, as the Casino's coin
# sellers, is a talk; a quest step behind a choice leaves a talk that may turn into story.
$data_common_events[30] = RPG::CommonEvent.new([Command.new(111, 0, [1, 1005, 0, 14, 0]), Command.new(121, 1, [65, 65, 0]), Command.new(412, 0, [])])
magistea = [c(101, "", 0, 0, 2), c(302, 0, 2, 0, 0, false), c(605, 0, 13, 0, 0), c(117, 30)]
frames_before = $frame_count
$game_variables[1005] = 0
check("a shop whose side quest cannot run now is a talk", [kind(magistea), MGQ_MpCoopEvents.may_tell?(magistea)], [:talk, false])
$game_variables[1005] = 14
$frame_count += 1
check("and story while the quest's step can run", kind(magistea), :story)
$game_variables[1005] = 15
check("a common event is sorted anew in the next frame only", kind(magistea), :story)
$frame_count += 1
check("then it is a talk again", kind(magistea), :talk)
coin_seller = [c(101, "", 0, 0, 2), c(355, "goods = []"), c(655, "goods.push([0, 2149, 0, 0])"), c(655, "SceneManager.call(Scene_Shop)")]
check("a shop that lists its goods in a script is a talk", kind(coin_seller), :talk)
blacksmith = [c(101, "", 0, 0, 2), Command.new(102, 0, [["Synthesis", "Talk"], 2]),
              Command.new(402, 0, [0, "Synthesis"]), Command.new(355, 1, ["call_synthesize(14)"]), Command.new(0, 1, []),
              Command.new(402, 0, [1, "Talk"]), Command.new(101, 1, ["", 0, 0, 2]), Command.new(122, 1, [1007, 1007, 0, 0, 1]), Command.new(0, 1, []),
              Command.new(404, 0, [])]
check("a quest step behind a choice leaves a talk that may turn into story", [kind(blacksmith), MGQ_MpCoopEvents.may_tell?(blacksmith)], [:talk, true])
boxed_chest = [c(101, "", 0, 0, 2), Command.new(102, 0, [["Open it", "Leave it"], 2]), Command.new(402, 0, [0, "Open it"]),
               Command.new(123, 1, ["A", 0]), Command.new(126, 1, [1, 0, 0, 1]), Command.new(0, 1, []), Command.new(402, 0, [1, "Leave it"]), Command.new(0, 1, []),
               Command.new(404, 0, [])]
check("a chest that asks first stays a chest", [kind(boxed_chest), MGQ_MpCoopEvents.may_tell?(boxed_chest)], [:chest, false])
paid_tip = [c(101, "", 0, 0, 2), Command.new(102, 0, [["Ask her name", "Leave"], 2]), Command.new(402, 0, [0, "Ask her name"]),
            Command.new(123, 1, ["A", 0]), Command.new(125, 1, [1, 0, 1500]), Command.new(122, 1, [1009, 1009, 0, 0, 1]), Command.new(0, 1, []),
            Command.new(402, 0, [1, "Leave"]), Command.new(0, 1, []), Command.new(404, 0, [])]
check("an informant who sells a story tip behind a choice is a talk that may turn into story, no chest",
      [kind(paid_tip), MGQ_MpCoopEvents.may_tell?(paid_tip)], [:talk, true])
check("and one who sets her own switch before it is story", kind([c(123, "A", 0)] + paid_tip), :story)
story_choice = [c(101, "", 0, 0, 2), c(121, 60, 60, 0), Command.new(102, 0, [["Yes", "No"], 2]), Command.new(402, 0, [0, "Yes"]), Command.new(121, 1, [61, 61, 0])]
check("story outside a choice stays story", kind(story_choice), :story)

# A choice a script shows writes its answer into a variable the page then branches on, as Alice's
# recap at the Strategy Conference does: the branch counts as the choice's, since the choice is not
# made yet when the page is sorted.
recap = [c(355, "unlimited_choices(11, [\"The rabbit\", \"Tartarus\"])"),
         Command.new(111, 0, [1, 11, 0, 1, 0]), Command.new(101, 1, ["", 0, 0, 2]), Command.new(122, 1, [1011, 1011, 0, 0, 1]), Command.new(0, 1, []),
         Command.new(411, 0, []), Command.new(101, 1, ["", 0, 0, 2]), Command.new(122, 1, [1014, 1014, 0, 0, 1]), Command.new(0, 1, []),
         Command.new(412, 0, [])]
$game_variables[11] = 0
check("a talk whose branch on a choice script's variable moves the story on may turn into story", [kind(recap), MGQ_MpCoopEvents.may_tell?(recap)], [:talk, true])
check("both sides of that branch count", MGQ_MpCoopEvents.runnable(recap).size, recap.size)
$game_map.events[25] = Game_Event.new(25, [RPG::Page.new(recap)], 3)
check("a scene running by itself that hides its story behind such a choice is story", MGQ_MpCoopEvents.kind($game_map.events[25]), :story)
check("a signpost of dialogue and its own self switch is a talk", kind([c(101, "", 0, 0, 2), c(401, "Keep out"), c(123, "A", 0)]), :talk)
check("its own self switch with anything else stays story", [kind([c(123, "A", 0)]), kind([c(101, "", 0, 0, 2), c(123, "A", 0), c(121, 60, 60, 0)]), kind([c(101, "", 0, 0, 2), c(123, "A", 0), c(201, 0, 2, 296, 355, 0, 0)])], [:story, :story, :story])
check("the cosmetic scripts keep a talk", kind([c(101, "", 0, 0, 2), c(355, "mr = RPG::MoveRoute.new"), c(355, "wait(30)"), c(355, "set_zoom(1, 150)"), c(355, "map_zoom(120)"), c(355, "input_keys(60)")]), :talk)
check("the flags the game toggles around its fights are the player's own", kind([c(101, "", 0, 0, 2), c(121, 73, 73, 1), c(121, 22, 22, 1), c(121, 97, 97, 1)]), :talk)
$frame_count = frames_before
$game_switches = $game_variables = nil
check("without the game's switches every branch counts", MGQ_MpCoopEvents.kind($game_map.events[24]), :story)
$game_map = nil

# Chests.
$game_map = Game_Map.new
$game_party = Game_Party.new
$game_switches = Game_Switches.new
$game_variables = Game_Variables.new
$game_self_switches = Game_SelfSwitches.new
chest_page = RPG::Page.new([c(126, 1, 0, 0, 2), c(123, "A", 0)])
talk_page = RPG::Page.new([c(101, "", 0, 0, 2)])
$game_map.events = { 5 => Game_Event.new(5, [chest_page]), 6 => Game_Event.new(6, [talk_page]) }
check("the map's chests are found", MGQ_MpCoopEvents.chest_keys, [[3, 5, "A"]])
opened_page = RPG::Page.new([c(101, "", 0, 0, 2)])
$game_map.events[7] = Game_Event.new(7, [chest_page, opened_page])
$game_map.events[7].show(1)
MGQ_MpCoopEvents.instance_variable_set(:@chest_keys_map, nil)
check("so is a chest that shows its opened page", MGQ_MpCoopEvents.chest_keys, [[3, 5, "A"], [3, 7, "A"]])
$game_map.events.delete(7)
MGQ_MpCoopEvents.instance_variable_set(:@chest_keys_map, nil)

$party = "p1"
$leader = :me
friend = MGQ_MpOverworldSync::Peers::Peer.new(2, { "id" => "f", "name" => "Friend", "party" => "p1" }, nil, true)
$members = [friend]
$sent.clear
$game_map.interpreter.setup(chest_page.list, 5)
$game_map.interpreter.run
check("opening a chest tells the party what was in it, and its sound", $sent.map { |seat, f| [seat, f["chest"], f["gains"], f["se"]] }, [[-1, "3.5.A", "i1x2", "Chest,80,100"]])
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
$played = []
MGQ_MpCoopEvents.take(friend, { "chest" => "4.9.A", "party" => "p1", "gains" => "i2x1,w1x1,g0x50", "se" => "Chest2,90,110" })
check("a chest a member opened gives the same items, in a battle too", [$game_party.items["Elixir"], $game_party.items["Sword"], $game_party.gold], [1, 1, 50])
check("and marks it looted", raw($game_self_switches)[[4, 9, "A"]], true)
check("its sound and notice wait for the map", [$played, $notices.include?("Friend opened a chest for the party: Elixir, Sword, 50 G.")], [[], false])
SceneManager.scene = Scene_Map.new
$game_map.update
check("then the notice shows with the first item's icon", [$notices.last, $icons.last], ["Friend opened a chest for the party: Elixir, Sword, 50 G.", 102])
check("and the chest's sound plays", $played, [["Chest2", 90, 110]])
$played = []
MGQ_MpCoopEvents.play_sound("../evil,500,1")
check("a sound named like a path plays the chest's own, within the game's range", $played, [["Chest", 100, 50]])
$sent.clear
MGQ_MpCoopEvents.take(friend, { "chest" => "4.9.A", "party" => "p1", "gains" => "i2x1" })
check("a chest looted already gives nothing more", $game_party.items["Elixir"], 1)
check("and granting tells nobody", $sent.size, 0)
MGQ_MpCoopEvents.take(MGQ_MpOverworldSync::Peers::Peer.new(8, { "party" => "p9" }, nil, false), { "chest" => "4.8.A", "party" => "p1", "gains" => "i1x9" })
check("strangers give nothing", $game_party.items["Potion"], 2)
MGQ_MpCoopEvents.take(friend, { "chest" => "4.7.A", "party" => "p1", "gains" => "q1x1,i99x1,i1x1" })
check("unknown items are skipped", $game_party.items["Potion"], 3)
MGQ_MpCoopEvents.take(friend, { "chest" => "4.6.A", "party" => "p1", "gains" => "" })
check("a chest that gave nothing stays shut", raw($game_self_switches)[[4, 6, "A"]], nil)

# Chests while playing the leader's story.
leader = MGQ_MpOverworldSync::Peers::Peer.new(4, { "id" => "l", "name" => "Leader", "party" => "p1" }, nil, true)
$leader = leader
$members = [leader]
raw($game_self_switches)[[3, 5, "A"]] = nil
MGQ_MpCoopStory.take(leader, { "story" => "full", "party" => "p1", "s" => "", "v" => "", "ss" => "3.5.A,3.1.B" })
check("a member's chests stay their own on the leader's story", [raw($game_self_switches)[[3, 5, "A"]], raw($game_self_switches)[[3, 1, "B"]]], [nil, true])
MGQ_MpCoopStory.take(leader, { "story" => "delta", "party" => "p1", "s" => "", "v" => "", "ss" => "3.5.A:1" })
check("and the leader's chests do not change them", raw($game_self_switches)[[3, 5, "A"]], nil)
$game_map.interpreter.setup(chest_page.list, 5)
raw($game_self_switches)[[3, 5, "A"]] = true
$game_map.interpreter.run
check("a chest a member opens is theirs for good", MGQ_MpCoopStory.own_self_switch([3, 5, "A"]), true)
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
$game_switches[MGQ_MpStoryState::WARP_BAN] = true
MGQ_MpCoopEvents.take(leader, { "pevent" => "gather", "party" => "p1", "map" => "8", "x" => "9", "y" => "3", "d" => "6", "warp_ban" => "0" })
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
check("where warping is allowed again, though they never walked out of the cave they were in", $game_switches[MGQ_MpStoryState::WARP_BAN], false)
check("a leader tells whether warping is banned where they stand", MGQ_MpCoopGather.place_fields["warp_ban"], 0)
check("the warp ban is each player's own, not the leader's story", MGQ_MpStoryState.personal_switch?(MGQ_MpStoryState::WARP_BAN), true)
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
check("asking whether the member is coming once the calls stopped only says no", [MGQ_MpCoopGather.coming?, $notices], [false, []])
$game_map.update
check("once the calls stop, the story started without the member, who stays", [MGQ_MpCoopGather.own_doing, $notices.last, $game_player.reserved],
      [nil, "Leader's story started without you.", nil])

# A member teleports to another member through coop_teleport.rbx, which brings them over here.
MGQ_MpCoopGather.come_to("Leader", [5, 1, 1, 2], true)
check("a member who teleports waits only to be free", MGQ_MpCoopGather.own_doing, "Joining Leader once free")
$game_map.update
check("and comes at once, taking over the place's warp ban", [$game_player.reserved, $game_switches[MGQ_MpStoryState::WARP_BAN]], [[5, 1, 1, 2], true])
$game_player.instance_variable_set(:@reserved, nil)
$game_switches[MGQ_MpStoryState::WARP_BAN] = false

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
MGQ_MpCoopEvents.take(leader, { "pevent" => "follow", "party" => "p1", "map" => "624", "x" => "63", "y" => "27", "d" => "2", "warp_ban" => "0" })
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
MGQ_MpCoopEvents.take(leader, { "pevent" => "follow", "party" => "p1", "map" => "126", "x" => "15", "y" => "14", "d" => "2", "warp_ban" => "0" })
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
# The map's screen, faded out by the scene that brought the player.
class LateScreen
  attr_accessor :brightness, :fadein
  def initialize; @brightness = 0; end
  def start_fadein(duration); @fadein = duration; @brightness = 1; end
end
class Game_Map; attr_accessor :screen; end
# When the player entered the map, from $map_since.
module MGQ_MpOverworldSync; module Me; def self.map_since; $map_since; end; end; end
$game_map.screen = LateScreen.new
$map_since = 1000
$sent.clear
$game_map.events[13].start
check("a story event that runs by itself is left to the leader's game", [$game_map.setup_starting_map_event, $sent.size], [nil, 0])
check("which fades in the dark screen of a player who came in the middle of it", $game_map.screen.fadein, MGQ_MpCoopEvents::LATE_FADEIN_FRAMES)
$game_map.screen = LateScreen.new
$game_map.events[13].start
$game_map.setup_starting_map_event
check("only once per arrival, so the teller's own fade out stays", $game_map.screen.fadein, nil)
$map_since = 2000
$game_map.events[13].start
$game_map.setup_starting_map_event
check("but again on the next arrival", $game_map.screen.fadein, MGQ_MpCoopEvents::LATE_FADEIN_FRAMES)
$game_map.screen = LateScreen.new
$game_map.screen.brightness = 255
$map_since = 3000
$game_map.events[13].start
$game_map.setup_starting_map_event
check("and never on a screen that is not dark", $game_map.screen.fadein, nil)
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
      $sent.select { |_, f| f["pevent"] == "say" }.map { |_, f| MGQ_MpCoopEvents.decode(f["lines"]) }, ["A companion's line"])
Object.send(:remove_const, :MGQ_MpCoopScene)
$game_message.add("Hello, \\N[1]!")
$game_message.choices.push("Yes", "No")
check("with its face and text", [say["face"], say["index"], say["map"], MGQ_MpCoopEvents.decode(say["lines"].split(",")[0]), say["choices"].split(",").map { |t| MGQ_MpCoopEvents.decode(t) }], ["Alice", "2", "7", "Hello, \\N[1]!", ["Yes", "No"]])

# Holding the game's skip, the leader passes a page every frame: the members hear one page every
# SKIP_SEND_FRAMES, always the last, and that the leader moved past only the pages told.
pass_page = lambda do |text|
  $frame_count += 1
  $game_message.add(text)
  $game_map.interpreter.wait_for_message
  $game_message.clear
  $game_map.update
end
told_pages = lambda { $sent.select { |_, f| %w[say done].include?(f["pevent"]) }.map { |seat, f| [seat, f["pevent"], f["page"], f["lines"] && MGQ_MpCoopEvents.decode(f["lines"])] } }
SceneManager.scene = Scene_Map.new
$game_message.clear
$game_map.interpreter.setup(story_page.list, 11)
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
      [told.size <= 2 * (100 / MGQ_MpCoopEvents::SKIP_SEND_FRAMES) + 2, told.select { |_, kind, _, _| kind == "done" }.all? { |_, _, page, _| told.any? { |_, kind, said, _| kind == "say" && said == page } }],
      [true, true])
$sent.clear
$skipping = true
pass_page.call("Kept page")
check("a page kept while skipping waits", told_pages.call, [])
MGQ_MpCoopEvents.finished($game_map.interpreter)
$game_map.update
check("and goes out once the story's event ended", told_pages.call.map { |_, kind, _, line| [kind, line] }, [["say", "Kept page"], ["done", nil]])
$game_map.interpreter.setup(story_page.list, 11)
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
heard = MGQ_MpCoopEvents.instance_variable_get(:@heard).dup
$log.clear
2.times { MGQ_MpCoopEvents.take($leader, all_say) }
check("a member who plays their own story ignores it, saying so once",
      [MGQ_MpCoopEvents.instance_variable_get(:@heard), $log.grep(/ignored say from Leader: not synced with the leader/).size], [heard, 1])
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
MGQ_MpCoopEvents.guard(interpreter)
check("a member's talk ends where it would move the story on", [interpreter.instance_variable_get(:@index), $notices.last], [trader.size - 1, "Only Leader can move the story on."])
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
MGQ_MpCoopEvents.take(leader, { "pevent" => "done", "party" => "p1", "map" => "7", "x" => "0", "y" => "0", "d" => "2", "page" => say["page"] })
check("the leader moving on leaves the page a moment to read", [pause.resume, window.pause], [nil, true])
$frame_count += MGQ_MpCoopEvents.reading_frames(["Hello, \\N[1]!", "Leader chooses: Yes / No"])
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
$frame_count += MGQ_MpCoopEvents::STALE_FRAMES
check("a page ends anyway once the leader stopped telling the story a while ago", MGQ_MpCoopEvents.page_done?, true)
MGQ_MpCoopEvents.page_ended
$game_message.clear

# The leader tells the party what their story gives, takes and sends away.
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
check("items, gold and departures of the leader's story go to the party",
      $sent.map { |seat, f| [seat, f["story"], f["item"] || f["actor"]] }, [[-1, "gain", "i1x3"], [-1, "gain", "g0x-5"], [-1, "depart", "3"]])
$sent.clear
$game_party.gain_item($data_items[1], -2, false, true)
check("items only moved to the item storage are not", $sent.size, 0)
unique = RPG::Weapon.new(1, "Sword+")
def unique.uniq_item?; true; end
$game_party.gain_item(unique, -1)
check("nor an enchanted copy, which exists only in the leader's game", $sent.size, 0)
MGQ_MpCoopEvents.take(friend, { "chest" => "6.2.A", "party" => "p1", "gains" => "i2x1" })
check("nor what a member's chest gives the leader meanwhile", $sent.select { |_, f| f["story"] }.size, 0)
$game_party.in_battle = true
$game_party.gain_gold(100)
check("nor battle rewards, which every player gets in their own game", $sent.select { |_, f| f["story"] }.size, 0)
$game_party.in_battle = false
$game_map.interpreter.busy = false
$game_party.gain_item($data_items[2], 1)
check("nor what comes once the story event ended", $sent.select { |_, f| f["story"] }.size, 0)
MGQ_MpCoopEvents.finished($game_map.interpreter)
check("the end of the map's main event ends the telling, so a later message, such as a PvP battle's result, is not told",
      MGQ_MpCoopEvents.instance_variable_get(:@telling), false)

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
  [["gain", "item", "i1x2"], ["gain", "item", "g0x-30"], ["gain", "item", "w1x1"], ["gain", "item", "i3x1"], ["keys", "k", "3:1"], ["depart", "actor", "3"], ["recruit", "actor", "3"],
   ["recruit", "actor", "4"]].each do |kind, field, value|
    MGQ_MpCoopStory.take($story_leader, { "story" => kind, "party" => "p1", field => value })
  end
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
check("a save made in the party holds it too, the story's key item included", saved, [true, 41, 7, 1])
check("which they keep", $game_party.items["Basement Key"], 1)
check("the story's items and gold are theirs", [$game_party.items["Potion"], $game_party.items["Sword"], $game_party.gold], [2, 1, -30])
check("a companion the story sent away and brought back is in the party again, a new one waits at the castle",
      [$game_party.actors, $game_party.include_actors], [[3], [3, 4]])
check("with notices", $notices.include?("Leader's story took 30 G from you too.") && $notices.include?("Tamamo joined you too."), true)

joined, switches, variables, saved = play_along(30)
check("a member behind the leader hears they catch up and keep what they play together", joined,
      "You follow Leader's story while in the party. You catch up with it and keep what you play together.")
check("once the party ends they keep the leader's story, what the leader had before included, and their own switch the leader never set",
      [switches[80], switches[81], switches[82], variables[1001]], [true, true, true, 41])
check("and what changed in their own game meanwhile, in a save made in the party too", [switches[90], variables[151], saved], [true, 7, [true, 41, 7, 1]])
check("with the story's items, gold and companions", [$game_party.items["Potion"], $game_party.items["Basement Key"], $game_party.gold, $game_party.include_actors],
      [2, 1, -30, [3, 4]])

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
MGQ_MpCoopStory.take(leader, { "story" => "gain", "party" => "p1", "item" => "i1x1" })
check("what the story gives before the member plays it again waits", $game_party.items["Potion"], 0)
MGQ_MpCoopStory.take(leader, full_story)
check("once they play it again, the key is lent again", $game_party.items["Basement Key"], 1)

# A duel puts the game back as it was before it.
$pvp = true
before_duel = MGQ_MpCoopStory.save_contents(:switches => $game_switches, :variables => $game_variables, :self_switches => $game_self_switches, :party => $game_party)
MGQ_MpCoopEvents.take(friend = MGQ_MpOverworldSync::Peers::Peer.new(2, { "id" => "f", "name" => "Friend", "party" => "p1" }, nil, true),
                      { "chest" => "9.1.A", "party" => "p1", "gains" => "i2x1" })
check("a chest another member opens during a duel waits", $game_party.items["Elixir"], 0)
$game_party = before_duel[:party]
$game_switches, $game_variables, $game_self_switches = before_duel[:switches], before_duel[:variables], before_duel[:self_switches]
DataManager.extract_save_contents({})
$pvp = false
check("putting the game back after the duel took the key along", $game_party.items["Basement Key"], 0)
SceneManager.scene = Scene_Map.new
$game_map.update
check("then the chest's items come", $game_party.items["Elixir"], 1)
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
# Stands in for the table of coop_story_rewards.rbx.
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
# A skill's data.
Skill = Struct.new(:id, :name)
$data_skills = Array.new(14)
$data_skills[11] = Skill.new(11, "Demon Decapitation")
$data_skills[12] = Skill.new(12, "Angel Dance")
$data_skills[13] = Skill.new(13, "Sylph")
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
holdings = { "sk" => "11,13", "ac" => "4,5,8", "it" => "w1:1,i3:1,i1:5", "side" => "a" }
behind_story = { "story" => "full", "party" => "p1", "s" => "120", "v" => "1001:n40,1076:n5", "ss" => "" }.merge(holdings)

check("the side each player chose is their own before the Great Decision", [4, 5].map { |id| MGQ_MpStoryState.personal_switch?(id, []) }, [true, true])
check("but not after it, which sets the side anew with the route", [4, 5].map { |id| MGQ_MpStoryState.personal_switch?(id, [0] * 1141 + [2]) }, [false, false])
member_game(30)
MGQ_MpCoopStory.take(leader, behind_story)
check("a member behind without a side catches up with what both sides get", [$game_actors[1].skills, $game_party.include_actors], [[13], [4]])
check("and with the story's items and key items, but not every item the leader holds", [held("Sword"), held("Basement Key"), held("Potion")], [1, 1, 0])
check("with notices", $notices.include?("Luka learned Sylph to catch up with Leader's story.") && $notices.include?("You got Sword and Basement Key to catch up with Leader's story."), true)
MGQ_MpCoopStory.update
check("once free on the map, the member chooses a side", [$game_message.texts.last, $game_message.choices, $game_message.choice_cancel_type],
      ["Leader took Alice along. Whom do you take along on your own journey?", ["Alice", "Ilias"], 0])
$game_message.choice_proc.call(1)
check("taking Ilias brings the companion the choice brings into the party", [$game_switches[5], $game_switches[4], $game_party.actors], [true, false, [9]])
check("and Ilias's side's rewards of every event the leader's story got past: the skill of a camp the leader trained at on Alice's side, " \
      "the companions of a council and of a shrine only Ilias's side gets one at", [$game_actors[1].skills, $game_party.include_actors], [[13, 12], [4, 9, 6, 7]])
MGQ_MpCoopStory.take(leader, behind_story)
check("hearing it again gives nothing more", [$game_actors[1].skills, $game_party.include_actors, held("Sword")], [[13, 12], [4, 9, 6, 7], 1])
check("the leader's story never takes the member's side", [$game_switches[5], $game_switches[4]], [true, false])
MGQ_MpCoopStory.take(leader, { "story" => "recruit", "party" => "p1", "actor" => "5" })
check("a companion only Alice's side gets in the story stays the leader's", $game_party.include_actors.include?(5), false)

member_game(30, 4)
MGQ_MpCoopStory.take(leader, behind_story)
check("a member on the leader's side gets what the leader got", [$game_actors[1].skills.sort, $game_party.include_actors], [[11, 13], [4, 5]])
check("and is not asked", ($game_message.choices || []).empty?, true)

member_game(30, 5)
part3 = behind_story.merge("s" => "4,120", "v" => "1001:n40,1076:n5,1141:n2")
MGQ_MpCoopStory.take(leader, part3)
check("after the Great Decision a member still gets their own side's rewards of the events before it, and the companion the route brings",
      [$game_actors[1].skills.sort, $game_party.include_actors], [[12, 13], [4, 5, 6, 7]])
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
MGQ_MpCoopStory.take(leader, behind_story.merge("sk" => "13", "ac" => "4"))
check("a member as far along gets nothing the leader held before, nor of events the story got past", [$game_actors[1].skills, $game_party.include_actors, held("Sword")], [[], [], 0])
MGQ_MpCoopStory.take(leader, { "story" => "hold", "party" => "p1" }.merge(holdings))
check("only what the leader came to hold since, their own side's", [$game_actors[1].skills, $game_party.include_actors], [[12], []])

member_game(50, 5)
MGQ_MpCoopStory.take(leader, behind_story)
check("a member ahead catches up with nothing", [$game_actors[1].skills, $game_party.include_actors, held("Sword")], [[], [], 0])

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
check("the leader tells the story's skills, companions, items and their side", told && told[1].values_at("sk", "ac", "it", "side"), ["11", "5", "w1:1", "a"])

# The catch-up's edge cases: rewards some event gives either side, the side after the Great
# Decision, the member's own side quests, the leader's rewards outside the story, a companion let
# go, and equipment at the castle.
$data_actors[10] = Actor.new("Morrigan")
morrigan = holdings.merge("ac" => "4,5,8,10")
member_game(30, 5)
MGQ_MpCoopStory.take(leader, behind_story.merge(morrigan))
check("a companion some event gives without a side reaches a member of the other side", $game_party.include_actors.include?(10), true)

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
member_game(40, 5)
MGQ_MpCoopStory.take(leader, behind_story)
MGQ_MpCoopStory.take(leader, { "story" => "learn", "party" => "p1", "skill" => "13" })
MGQ_MpCoopStory.take(leader, { "story" => "learn", "party" => "p1", "skill" => "11" })
check("a story skill the leader learns while the story plays is the member's too, unless only the other side learns it",
      $game_actors[1].skills, [13])

# The leader tells a story skill Luka learns while the story plays, and only then.
MGQ_MpCoopStory.forget
$leader = :me
$members = [friend]
$game_actors = [nil, Hero.new]
$sent.clear
$game_actors[1].learn_skill(13)
check("outside the story the leader's new skill stays theirs", $sent.select { |_, f| f["story"] == "learn" }, [])
MGQ_MpCoopEvents.instance_variable_set(:@telling, true)
$game_map.interpreter.busy = true
$game_actors[1].learn_skill(13)
Hero.new.learn_skill(13)
check("in the story the party hears of it, of Luka's alone", $sent.select { |_, f| f["story"] == "learn" }.map { |seat, f| [seat, f["skill"]] }, [[-1, "13"]])

# What a shop or a menu the story opens changes is the leader's alone, and a companion the story
# brings is told though the leader has them already, whom a member may lack.
class Scene_Shop; end
$game_party = Game_Party.new
$sent.clear
SceneManager.scene = Scene_Shop.new
$game_party.gain_item($data_items[1], 2)
$game_party.gain_gold(-30)
check("what the leader buys in a shop the story opens is never told as the story's", $sent.select { |_, f| f["story"] == "gain" }, [])
SceneManager.scene = Scene_Map.new
$game_party.gain_item($data_items[1], 1)
check("what the story gives on the map is", $sent.select { |_, f| f["story"] == "gain" }.map { |_, f| f["item"] }, ["i1x1"])
$game_party.add_stand_actor(6)
$sent.clear
$game_party.add_actor(6)
check("a companion the story brings whom the leader has already is told too, and held once",
      [$sent.select { |_, f| f["story"] == "recruit" }.map { |_, f| f["actor"] }, $game_party.include_actors], [["6"], [6]])
MGQ_MpCoopEvents.instance_variable_set(:@telling, false)
$game_map.interpreter.busy = false

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
check("and the leader holds the story companion of either persona", MGQ_MpCoopStory.holdings({})[:actors], [8, 9])
$game_actors = [nil, Hero.new]

# Luka's abilities are kept apart from his skills.
$game_actors[1].instance_variable_set(:@abilities, { 5 => [12] })
check("a story ability Luka knows counts as held", MGQ_MpCoopStory.holdings({})[:skills], [12])
check("and is not learned again", MGQ_MpStoryState.learn(12), nil)
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
MGQ_MpCoopStory.take(leader, { "story" => "gain", "party" => "p1", "item" => "w1x1" })
MGQ_MpCoopStory.take(leader, { "story" => "hold", "party" => "p1" }.merge(holdings).merge("side" => "i"))
MGQ_MpCoopStory.take(leader, behind_story)
MGQ_MpCoopStory.update
check("a story item that waited is not given twice once the whole story caught the member up", held("Sword"), 1)
check("and older holdings that waited do not replace the newer ones", MGQ_MpCoopStory.instance_variable_get(:@leader_held)[:side], :alice)

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

# The Great Decision brings its companions before the route's progress tells it is over: one only
# the sides' events give waits until then, and joins if the leader still has them.
member_game(30, 5)
MGQ_MpCoopStory.take(leader, behind_story)
MGQ_MpCoopStory.take(leader, { "story" => "recruit", "party" => "p1", "actor" => "5" })
check("a companion the Great Decision brings waits while the sides still differ", $game_party.include_actors.include?(5), false)
MGQ_MpCoopStory.take(leader, { "story" => "delta", "party" => "p1", "s" => "", "v" => "1141:n2", "ss" => "" })
check("and joins once the route's progress tells the decision is over", [$game_party.include_actors.include?(5), $notices.last], [true, "Ilias joined you too."])
member_game(30, 5)
MGQ_MpCoopStory.take(leader, behind_story)
MGQ_MpCoopStory.take(leader, { "story" => "recruit", "party" => "p1", "actor" => "5" })
MGQ_MpCoopStory.take(leader, { "story" => "hold", "party" => "p1" }.merge(holdings).merge("ac" => "4"))
MGQ_MpCoopStory.take(leader, { "story" => "delta", "party" => "p1", "s" => "", "v" => "1141:n2", "ss" => "" })
check("one the leader's route let go stays gone", [$game_party.include_actors.include?(5), MGQ_MpCoopStory.instance_variable_get(:@route_waiting)], [false, []])

# An event the leader played on one side counts once the Great Decision set them on the other.
member_game(30, 4)
MGQ_MpCoopStory.take(leader, behind_story.merge("sk" => "12,13", "ac" => "4", "side" => "a"))
check("a camp the leader trained at on Ilias's side counts though they now play Alice's", $game_actors[1].skills.sort, [11, 13])

# What waited for the member is the leader's who sent it, never another leader's.
other_leader = MGQ_MpOverworldSync::Peers::Peer.new(6, { "id" => "o", "name" => "Other", "party" => "p1" }, nil, true)
member_game(40, 5)
MGQ_MpCoopStory.take(leader, behind_story)
$pvp = true
MGQ_MpCoopStory.take(leader, { "story" => "gain", "party" => "p1", "item" => "w1x1" })
$pvp = false
$leader = other_leader
$members = [other_leader]
MGQ_MpCoopStory.update
MGQ_MpCoopStory.take(other_leader, behind_story)
MGQ_MpCoopStory.update
check("what a former leader's story gave meanwhile is never given with another leader's", held("Sword"), 0)

# The pages a former leader told are forgotten once another member leads.
$leader = leader
$members = [leader]
SceneManager.scene = Scene_Battle.new
MGQ_MpCoopEvents.hear(leader, { "page" => "x.1", "lines" => ["Old line"].pack("m0") })
check("a page the leader tells waits while the member is busy", MGQ_MpCoopEvents.instance_variable_get(:@heard).size, 1)
$leader = other_leader
$members = [other_leader]
MGQ_MpCoopEvents.update
SceneManager.scene = Scene_Map.new
check("the pages a former leader told are forgotten once another member leads", MGQ_MpCoopEvents.instance_variable_get(:@heard), [])
check("a chest's items given inside another gift leave it a gift",
      MGQ_MpCoopEvents.granting { MGQ_MpCoopEvents.grant("i1x1"); MGQ_MpCoopEvents.instance_variable_get(:@granting) }, true)
$party = nil
$leader = nil
$members = []
MGQ_MpCoopStory.update

# Who plays the leader's story: before the Great Decision both at most two steps apart in the main
# story, after it both on the same route at most five steps apart.
story = MGQ_MpCoopStory
check("just behind or ahead within two steps is synced, three behind is not",
      [story.sync_state([28, 0, 0, 0], [30, 0, 0, 0]), story.sync_state([32, 0, 0, 0], [30, 0, 0, 0]), story.sync_state([27, 0, 0, 0], [30, 0, 0, 0])],
      [:synced, :synced, :apart])
check("across the Great Decision is not, nor a player reset to it against one on a route",
      [story.sync_state([39, 0, 0, 0], [40, 3, 0, 1]), story.sync_state([40, 0, 0, 1], [39, 0, 0, 0])], [:decision, :decision])
check("different routes are not", story.sync_state([40, 3, 0, 1], [40, 0, 5, 1]), :route)
check("route counters five apart are synced, six apart are not",
      [story.sync_state([40, 3, 0, 1], [40, 8, 0, 1]), story.sync_state([40, 3, 0, 1], [40, 9, 0, 1])], [:synced, :apart])
check("the Chaos route, which the Great Decision itself starts, counts as a route",
      [story.sync_state([40, 0, 0, 4], [40, 0, 0, 6]), story.sync_state([40, 0, 0, 4], [40, 2, 0, 1])], [:synced, :route])
check("at the end of the same route, as in the postgame, both are synced", story.sync_state([40, 76, 0, 1], [40, 76, 0, 1]), :synced)

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
MGQ_MpCoopStory.take(leader, { "story" => "gain", "party" => "p1", "item" => "w1x1" })
check("the leader's story, its gifts and its catch-up stay away from them, and nothing waits",
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
      [MGQ_MpCoopGather.coming?, MGQ_MpCoopGather.blocked?, MGQ_MpCoopEvents.instance_variable_get(:@heard).size], [false, false, 0])
leader.state["telling"] = "0"
MGQ_MpCoopEvents.take(leader, { "chest" => "9.2.A", "party" => "p1", "gains" => "i2x1" })
check("but chests the party opens are shared all the same", held("Elixir"), 1)

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

# The generator of coop_story_rewards.rbx, in MGQ-Paradox-Event-Checker next to this repository,
# leaves out of its marks exactly what is each player's own; without that repository this goes unchecked.
generator = Module.new
generator_file = File.expand_path("../../../MGQ-Paradox-Event-Checker/Tools/story_rewards.rb", __dir__)
if File.exist?(generator_file)
  load(generator_file, generator)
  own_switches = generator::PERSONAL_SWITCHES.flat_map { |ids| Array(ids) }
  own_variables = Object.new.extend(generator).send(:personal_variables, $data_actors.size).flat_map { |ids| Array(ids) }
  # The chest flags are each player's own too, but only chests set them, which no marks come from.
  check("the generator's switches of each player's own are this script's, the chest flags aside",
        [own_switches.all? { |id| MGQ_MpStoryState.personal_switch?(id, []) }, (1..8000).select { |id| MGQ_MpStoryState.personal_switch?(id, []) } - own_switches - CHEST_FLAGS], [true, []])
  check("and so are its variables", [own_variables.all? { |id| MGQ_MpStoryState.personal_variable?(id) }, (1..8000).select { |id| MGQ_MpStoryState.personal_variable?(id) } - own_variables], [true, []])
else
  puts "skipped the generator's lists: #{generator_file} is missing"
end

# An event command as the game's data holds it, which the generator reads by its fields.
class ToolCommand
  def initialize(code, parameters, indent = 0); @code = code; @parameters = parameters; @indent = indent; end
end
# An event page's condition as the game's data holds it: whether it asks for a variable, which.
class ToolCondition
  def initialize(variable_valid, variable_id); @variable_valid = variable_valid; @variable_id = variable_id; @switch1_valid = false; @switch2_valid = false; end
end
# An event page as the game's data holds it, its condition alone.
class ToolPage
  def initialize(condition); @condition = condition; end
end
tool = File.exist?(generator_file) ? Object.new.extend(generator) : nil
if tool
  check("the generator counts a chest of gold alone as a chest", tool.send(:chest?, [ToolCommand.new(125, [0, 0, 50]), ToolCommand.new(123, ["A", 0])]), true)
  flag_chest = [ToolCommand.new(126, [700, 0, 0, 1]), ToolCommand.new(123, ["A", 0]), ToolCommand.new(121, [2045, 2045, 0])]
  plain_page = ToolPage.new(ToolCondition.new(false, 0))
  $chest_flags = [2045]
  check("and a chest that turns on a chest flag, on a page that asks for no story, but no other switch",
        [tool.send(:chest?, flag_chest, plain_page), tool.send(:chest?, flag_chest, ToolPage.new(ToolCondition.new(true, 1001))),
         tool.send(:chest?, flag_chest + [ToolCommand.new(121, [60, 60, 0])], plain_page)], [true, false, false])
  check("a chest flag is a switch only such chests turn on",
        [tool.send(:flag_chest?, flag_chest, plain_page), tool.send(:switches_of, flag_chest + [ToolCommand.new(121, [61, 61, 1])], true)], [true, [2045]])
  $chest_flags = nil
  found = []
  tool.send(:rewards, [ToolCommand.new(121, [1005, 1005, 0]), ToolCommand.new(121, [1001, 1001, 0]), ToolCommand.new(121, [1006, 1006, 1])], nil) { |*reward| found << reward }
  check("and a companion who joins by their switch as joining, never Luka nor one whose switch turns off", found, [[:actor, 5, 1, nil]])
  found = []
  tool.send(:rewards, [ToolCommand.new(355, ["set_actors(1,6,26,35)"])], nil) { |*reward| found << reward }
  check("and every companion a script sets the party with, never Luka", found.map { |reward| reward[1] }, [6, 26, 35])
  require "tmpdir"
  require "fileutils"
  Dir.mktmpdir do |data|
    ["", "Map/Data", "Map2/Data"].each do |folder|
      FileUtils.mkdir_p(File.join(data, folder))
      File.write(File.join(data, folder, "MapInfos.rvdata2"), "")
    end
    check("the generator reads the maps from 1000 on in the folders the game keeps them in",
          tool.send(:map_folders, data), [[data, 0], [File.join(data, "Map", "Data"), 1000], [File.join(data, "Map2", "Data"), 2000]])
  end
end

# The table the generator wrote holds what the maps from 1000 on give, such as Puruel and Inuel at
# the Chaos route's snow shrine.
table = Module.new
table.module_eval(File.read(File.join(SCRIPTS_DIR, "coop_story_rewards.rbx"), :encoding => "UTF-8"))
rewards = table::MGQ_MpCoopStoryRewards
check("the table holds Puruel (516) and Inuel (517), and the companions set_actors brings", [516, 517, 6, 33, 35].map { |id| rewards::ACTORS.include?(id) }, [true] * 5)
check("the skills Luka learns on maps from 1000 on, and their chests",
      [rewards::SKILLS.include?(9799), rewards::CHESTS.any? { |key| key[0] >= 1000 }], [true, true])

# The game's Library Flags, "Library Flag: ..." and the untranslated rest, which translations differ
# in setting, so no event's marks may hold one.
library_flags = [201..420, 5201..5600]
check("no event where the sides differ is marked by a Library Flag",
      rewards::GROUPS.map { |group| group[:marks] }.flatten(2).select { |mark| mark[0] == :s && library_flags.any? { |range| range.include?(mark[1]) } }, [])
check("so the Strategy Conference is marked by its warp switch and Alice's adult form alone",
      rewards::GROUPS.find { |group| group[:alice][:actors].include?(34) }[:marks], [[[:s, 5091], [:s, 7089]]])
switch_names = Array.new(5600, "")
switch_names[2922] = "Library Door"
switch_names[5249] = "Library Flag: Magical Academy"
switch_names[5588] = [0x56f3, 0x9451, 0x30d5, 0x30e9, 0x30b0, 0xff1a, 0x521d, 0x671f, 0x88c5, 0x5099].pack("U*")
if tool
  check("the generator leaves a Library Flag out by its English or its untranslated name, unlike a switch named after the library",
        [2922, 5249, 5588].map { |id| tool.send(:unmarked?, :s, id, switch_names) }, [false, true, true])
  check("so a list that turns one on is marked by its other switches",
        tool.send(:marks, [ToolCommand.new(121, [5091, 5091, 0]), ToolCommand.new(121, [5249, 5249, 0]), ToolCommand.new(121, [5588, 5588, 0])], nil, [switch_names, []]),
        [[:s, 5091]])
end

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
# The world screen's form, which the screen of choices draws with, stood in by its fields alone.
class Window_MpWorldForm; def initialize(*); end; end
# The base of the game's menu scenes.
class Scene_MenuBase; end
# The scenes called, kept in $scenes.
module SceneManager; def self.call(scene); ($scenes ||= []) << scene; end; end
# Stands in for the world screen of world.rbx, its form alone.
module MGQ_MpWorld
  # A form of the world screen: its fields and what is filled in.
  class Form
    # A field of the form.
    Field = Struct.new(:key, :kind, :label, :row, :hint, :options) do
      def choices; options[:choices] || []; end
      def note_of(form); options[:note] ? options[:note].call(form, form[key].to_i).to_s : ""; end
    end
    attr_reader :title, :fields
    def initialize(title, fields, values); @title = title; @fields = fields; @values = values; end
    def [](key); @values[key]; end
    def []=(key, value); @values[key] = value; end
  end
end
# The world's ticks, with which coop_choices.rbx forgets what waits once the world closes.
module MGQ_MpOverworldSync; def self.on_tick(&block); ($choice_ticks ||= []) << block if block; end; end
load_script "coop_choices"
choices = MGQ_MpCoopChoices
{ 5 => "Alice", 26 => "Ilias", 163 => "Lily", 167 => "Lucia", 287 => "Succubus", 288 => "Natasha", 540 => "Amira", 153 => "Sphinx", 241 => "Priestess",
  245 => "Miria", 334 => "Spider Princess" }.each { |id, name| $data_actors[id] = Actor.new(name) }

check("a catch-up from the start to the Great Decision asks every choice, in story order",
      choices.passed(5, 40, [], [], []), [:side, :magistea, :plansect, :succubus, :spider, :sphinx, :decision])
check("one from 20 to 32 asks those between, and not one the player made",
      choices.passed(20, 32, Array.new(3000).tap { |s| s[2096] = true }, [], []), [:plansect, :succubus, :spider, :sphinx])
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
choices.apply(:sphinx, 1)
check("the Queen Bee's side, the Spider Princess and the Sphinx invited",
      [$game_variables[1061], $game_switches[2154], $game_switches[2280], [245, 334, 153].map { |id| $game_party.include_actors.include?(id) }],
      [2, true, true, [true, true, true]])

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
MGQ_MpCoopStory.take(leader, { "story" => "recruit", "party" => "p1", "actor" => "163" })
check("whether caught up or recruited in the story", $game_party.include_actors.include?(163), false)
MGQ_MpCoopStory.take(leader, { "story" => "delta", "party" => "p1", "s" => "2096:0,2097:1", "v" => "", "ss" => "" })
check("nor do the leader's later changes of it reach the member", [$game_switches[2096], $game_switches[2097]], [true, false])

# Synced play: a choice the shared story passes, or the leader resolves, asks the member's own outcome.
choices.forget("next check")
member_game(15, 5)
MGQ_MpCoopStory.take(leader, behind_story.merge("v" => "1001:n16"))
$scenes = []
MGQ_MpCoopStory.take(leader, { "story" => "delta", "party" => "p1", "s" => "", "v" => "1001:n17", "ss" => "" })
SceneManager.scene = Scene_Map.new
$game_map.interpreter.busy = false
$game_message.busy = false
$game_map.update
check("the shared story passing Magistea Village asks the member's own outcome, on the screen with one row",
      [$scenes, choices.instance_variable_get(:@screen) && choices.instance_variable_get(:@screen)[:keys]], [[Scene_MpStoryChoices], [:magistea]])
screen = choices.take_screen
screen[:done].call(:magistea => 1)
check("and keeps it", [$game_switches[2097], $game_party.include_actors.include?(163), choices.instance_variable_get(:@prompts)], [true, true, []])
MGQ_MpCoopStory.take(leader, { "story" => "delta", "party" => "p1", "s" => "2280:1", "v" => "", "ss" => "" })
check("the leader resolving a choice the member has not made asks it too", choices.instance_variable_get(:@prompts), [:spider])
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
screen = choices.take_screen
check("accepting shows the choices the catch-up carries them past",
      [$scenes, screen[:keys], screen[:buttons]], [[Scene_MpStoryChoices], [:plansect, :succubus, :spider, :sphinx, :decision], ["Bring me there", "Cancel"]])
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

# A Raid World: whoever tells the story on the map tells it to everyone there whose story matches,
# party or not.
# Whether the world is a Raid World, from $raid.
module MGQ_MpWorld; def self.raid?; $raid; end; end
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
teller = MGQ_MpOverworldSync::Peers::Peer.new(6, { "id" => "t", "name" => "Teller", "map" => "3", "since" => "1000", "telling" => "1", "sm" => "12,0,0,0" }, nil, false)
stranger = MGQ_MpOverworldSync::Peers::Peer.new(7, { "id" => "s", "name" => "Stranger", "map" => "3", "since" => "3000", "sm" => "12,0,0,0" }, nil, false)
behind = MGQ_MpOverworldSync::Peers::Peer.new(8, { "id" => "b", "name" => "Behind", "map" => "3", "since" => "3000", "sm" => "5,0,0,0" }, nil, false)
leader.state.merge!("map" => "9", "telling" => "0", "since" => "500")
$peers = [teller, stranger, behind, leader]
check("a Raid World's parties lead no story: nobody borrows a leader's story or tells members one",
      [MGQ_MpCoopStory.leader, MGQ_MpCoopStory.real_synced_members, MGQ_MpCoopStory.real_follows_leader?], [nil, [], false])

raid_event = Game_Event.new(51, [story_page])
$game_map.events = { 51 => raid_event }
$notices.clear
check("a player telling the story on the map, party or not, keeps the player's story events from starting",
      [MGQ_MpCoopEvents.hand_over(raid_event), MGQ_MpCoopEvents.following?, $notices.last], [true, true, "Teller is telling the story here."])
MGQ_MpCoopEvents.take(teller, { "pevent" => "say", "map" => "3", "page" => "r.1", "lines" => ["Raid line"].pack("m0") })
$game_map.update
check("their pages show for a player whose story matches", $game_message.texts, ["Raid line"])
$game_message.clear
MGQ_MpCoopEvents.page_ended
MGQ_MpCoopEvents.take(stranger, { "pevent" => "say", "map" => "3", "page" => "s.1", "lines" => ["Not told"].pack("m0") })
$game_variables[1001] = 5
MGQ_MpCoopEvents.take(teller, { "pevent" => "say", "map" => "3", "page" => "r.2", "lines" => ["Too far"].pack("m0") })
$game_map.update
check("but neither a player's who does not tell it, nor the teller's for a player whose story differs", $game_message.texts, [])
$game_variables[1001] = 12

teller.state["telling"] = "0"
raid_story = Game_Event.new(52, [story_page])
$game_map.events = { 52 => raid_story }
check("once nobody tells it here, the player's own story events start", MGQ_MpCoopEvents.hand_over(raid_story), false)
$sent.clear
interpreter = $game_map.interpreter
interpreter.setup(story_page.list, 52)
interpreter.busy = true
check("the player tells it, alone too, with how far their story was as it started",
      [MGQ_MpCoopGather.holding_story?, MGQ_MpCoopEvents.state_fields], [false, { "telling" => 1, "tsm" => "12,0,0,0", "twb" => 0 }])
$game_message.add("Told line")
MGQ_MpCoopEvents.show(interpreter)
check("its pages go through the map's gate in one message to the players on the map whose story matches",
      $sent.map { |seat, fields| [seat, fields["map_pevent"], fields["mmap"], fields["mto"]] }, [[-1, "say", "3", "t,s"]])
$game_message.clear
stranger.state["telling"] = "1"
MGQ_MpCoopEvents.yield_story(interpreter)
check("another player who started telling at the same moment but entered the map later stops, not the player",
      MGQ_MpCoopEvents.telling?, true)
stranger.state["telling"] = "0"
teller.state["telling"] = "1"
$notices.clear
MGQ_MpCoopEvents.yield_story(interpreter)
check("one who entered the map first tells it, and the player's event ends at its next command",
      [interpreter.instance_variable_get(:@index), MGQ_MpCoopEvents.telling?, $notices.last], [story_page.list.size - 1, false, "Teller is telling the story here."])
interpreter.busy = false

teller.state["telling"] = "0"
interpreter.setup(story_page.list, 52)
interpreter.busy = true
teller.state["telling"] = "1"
$frame_count += MGQ_MpCoopEvents::TIE_FRAMES
MGQ_MpCoopEvents.yield_story(interpreter)
check("a player telling a while already is no tie and goes on", [MGQ_MpCoopEvents.telling?, MGQ_MpCoop::Scope.teller], [true, :me])
interpreter.busy = false
teller.state["telling"] = "0"
interpreter.setup(story_page.list, 52)
interpreter.busy = true
$game_map.map_id = 4
teller.state.merge!("telling" => "1", "map" => "4")
MGQ_MpCoopEvents.yield_story(interpreter)
check("nor is one whose story moved them onto a map where another player tells one", MGQ_MpCoopEvents.telling?, true)
interpreter.busy = false
$game_map.map_id = 3
teller.state.merge!("telling" => "0", "map" => "3")
# The story's next event starts in the frame its last ended, before the world's story went out.
$game_map.update
interpreter.setup(story_page.list, 52)
interpreter.busy = true
$game_map.update
$game_variables[1001] = 13
MGQ_MpCoopGather.instance_variable_set(:@taken_along, ["x"])
MGQ_MpCoopEvents.finished(interpreter)
interpreter.setup(story_page.list, 52)
check("the story's next event goes on with the telling: how far the story was as it started, and whom it took along",
      [MGQ_MpCoopEvents.state_fields["tsm"], MGQ_MpCoop::Scope.viewers, MGQ_MpCoopGather.instance_variable_get(:@taken_along)],
      ["12,0,0,0", [teller, stranger], ["x"]])
interpreter.busy = false
$game_map.update
interpreter.setup(story_page.list, 52)
interpreter.busy = true
check("a telling after a frame without one starts anew", [MGQ_MpCoopEvents.state_fields["tsm"], MGQ_MpCoopGather.instance_variable_get(:@taken_along)], ["13,0,0,0", nil])
interpreter.busy = false
$game_map.update
$game_variables[1001] = 12

# A story event waits at its start while someone on the map entered it first.
interpreter.setup(story_page.list, 52)
interpreter.busy = true
check("a story event waits at its start while a player who entered the map first may tell at the same moment",
      MGQ_MpCoopEvents.tie_holding?(interpreter), true)
teller.state["telling"] = "1"
check("and stops before its first command once they turn out to tell it",
      [MGQ_MpCoopEvents.tie_holding?(interpreter), (interpreter.execute_command; interpreter.instance_variable_get(:@index)), MGQ_MpCoopEvents.telling?],
      [false, story_page.list.size - 1, false])
interpreter.busy = false
teller.state["telling"] = "0"
interpreter.setup(story_page.list, 52)
interpreter.busy = true
$frame_count += MGQ_MpCoopEvents::TIE_HOLD_FRAMES - 1
check("it waits a whole second, so a state that comes late still stops it before its first command",
      [MGQ_MpCoopEvents::TIE_HOLD_FRAMES, MGQ_MpCoopEvents.tie_holding?(interpreter)], [60, true])
$frame_count += 1
check("it waits no longer than TIE_HOLD_FRAMES", [MGQ_MpCoopEvents.tie_holding?(interpreter), MGQ_MpCoopEvents.telling?], [false, true])
interpreter.busy = false
teller.state["map"] = "9"
interpreter.setup(story_page.list, 52)
interpreter.busy = true
check("nor at all once nobody on the map entered it first", MGQ_MpCoopEvents.tie_holding?(interpreter), false)
interpreter.busy = false
teller.state["map"] = "3"
$game_map.update

$game_party = Game_Party.new
$game_self_switches = Game_SelfSwitches.new
$game_map.events = { 5 => Game_Event.new(5, [chest_page]) }
MGQ_MpCoopEvents.instance_variable_set(:@chest_keys_map, nil)
$sent.clear
$game_map.interpreter.setup(chest_page.list, 5)
$game_map.interpreter.run
check("a Raid World's chests are personal: opening one tells nobody, party or not", $sent.select { |_, f| f["chest"] }, [])
MGQ_MpCoopEvents.take(leader, { "chest" => "3.6.A", "party" => "p1", "gains" => "g0x50" })
check("and one a party member opened gives nothing", $game_party.gold, 0)
$game_map.events = {}
MGQ_MpCoopEvents.instance_variable_set(:@chest_keys_map, nil)

# A player behind the world's story starts no story event and hears the level that moves them on;
# story that runs by itself waits silently, talks run.
# Stands in for world_catchup.rbx, the player behind the world's story while $behind is set.
module MGQ_MpWorldCatchup
  def self.holds_story?; $behind; end
  def self.refusal_text; "Reach level 25 to continue the story."; end
end
$behind = true
$peers = []
$notices.clear
MGQ_MpCoopEvents.instance_variable_set(:@refused, nil)
behind_story = Game_Event.new(54, [story_page])
behind_auto = Game_Event.new(55, [story_page], 3)
behind_talk = Game_Event.new(56, [talk_page])
check("a player behind the world's story starts no story event and hears the level that moves them on",
      [MGQ_MpCoopEvents.hand_over(behind_story), $notices], [true, ["Reach level 25 to continue the story."]])
check("once, however often they step on it", [MGQ_MpCoopEvents.hand_over(behind_story), $notices.size], [true, 1])
check("story that runs by itself waits without a word, so a teleport onto its map cannot loop", [MGQ_MpCoopEvents.hand_over(behind_auto), $notices.size], [true, 1])
check("talks run", MGQ_MpCoopEvents.hand_over(behind_talk), false)
behind_common = RPG::CommonEvent.new([c(101, "", 0, 0, 2), c(121, 60, 60, 0)])
behind_common.switch_id = 70
$data_common_events[4] = behind_common
raw($game_switches)[70] = true
check("as does a story common event that runs by itself", $game_map.setup_autorun_common_event, nil)
$behind = false
check("caught up, the player's story events start again", [MGQ_MpCoopEvents.hand_over(behind_story), $game_map.setup_autorun_common_event], [false, behind_common])

# Until the world's story came after the world opened or a save loaded, story events wait, the
# player's and those that run by themselves, without a word; talks run.
# Stands in for world_story.rbx, waiting for the world's story.
module MGQ_MpWorldStory
  def self.awaits_world?; true; end
  def self.awaits_teller?; false; end
end
$notices.clear
check("story events wait for the world's story, without a word",
      [MGQ_MpCoopEvents.hand_over(behind_story), MGQ_MpCoopEvents.hand_over(behind_auto), $game_map.setup_autorun_common_event, $notices], [true, true, nil, []])
check("talks run meanwhile", MGQ_MpCoopEvents.hand_over(behind_talk), false)
Object.send(:remove_const, :MGQ_MpWorldStory)
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
check("a story event on the new map within CONTINUE_FRAMES goes on with the telling: how far the story was as it started, whom it took along, and that the player tells it",
      [MGQ_MpCoopEvents.state_fields, MGQ_MpCoopGather.taken_along, MGQ_MpCoop::Scope.viewers, $log.grep(/goes on with the telling that moved the player from map 430/).size],
      [{ "telling" => 1, "tsm" => "12,0,0,0", "twb" => 0 }, [stranger], [stranger], 1])
teller.state.merge!("telling" => "1", "map" => "432")
MGQ_MpCoopEvents.yield_story(interpreter)
check("which no tie on the new map stops", MGQ_MpCoopEvents.telling?, true)
teller.state.merge!("telling" => "0", "map" => "3")
$game_player.reserve_transfer(433, 0, 0, 2)
$game_player.perform_transfer
MGQ_MpCoopEvents.finished(interpreter)
interpreter.busy = false
$game_map.update
$frame_count += MGQ_MpCoopEvents::CONTINUE_FRAMES
interpreter.setup(story_page.list, 54)
interpreter.busy = true
check("a story event later than CONTINUE_FRAMES after the move starts a telling anew",
      [MGQ_MpCoopEvents::CONTINUE_FRAMES, MGQ_MpCoopEvents.state_fields["tsm"], MGQ_MpCoopGather.taken_along], [300, "13,0,0,0", []])
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
      [MGQ_MpCoopEvents.state_fields["tsm"], $log.grep(/goes on with the telling/).size], ["14,0,0,0", 0])
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
check("a story event the player starts on the new map within CONTINUE_FRAMES is a new telling: how far the story is now, nobody taken along",
      [MGQ_MpCoopEvents.state_fields["tsm"], MGQ_MpCoopGather.taken_along, $log.grep(/goes on with the telling/).size], ["15,0,0,0", [], 0])
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
      [MGQ_MpCoopEvents.state_fields["tsm"], $log.grep(/goes on with the telling that moved the player from map 435/).size], ["15,0,0,0", 1])
MGQ_MpCoopEvents.finished(interpreter)
interpreter.busy = false
$game_map.update
$game_map.events = {}

# A follower on the way to where the teller's story moved them starts no story event of their own,
# keeps that teller while their state says they tell nothing, and hears their pages from the new map.
$game_map.map_id = 430
$game_player.moveto(25, 19)
$game_variables[1001] = 12
teller.state.merge!("map" => "432", "telling" => "0")
stranger.state["map"] = "3"
$peers = [teller, stranger]
MGQ_MpCoopEvents.page_ended
$game_message.clear
$notices.clear
$log.clear
MGQ_MpCoopEvents.take(teller, { "pevent" => "follow", "map" => "432", "x" => "0", "y" => "0", "d" => "2", "warp_ban" => "0" })
own_copy = Game_Event.new(57, [story_page], 3)
check("a follower on the way to where the teller's story moved them keeps their own copy of it, which runs by itself, from starting, silently",
      [MGQ_MpCoopEvents.hand_over(own_copy), MGQ_MpCoopEvents.hand_over(own_copy), $notices,
       $log.grep(/kept event 57 on map 430 from starting: the player follows Teller's story to map 432/).size],
      [true, true, [], 1])
check("the teller they follow stays the teller while their state says they tell nothing for a moment", [MGQ_MpCoop::Scope.teller, MGQ_MpCoopEvents.following?], [teller, true])
teller.state["map"] = "3"
check("but not while they are not on the follow's map", MGQ_MpCoop::Scope.teller, nil)
teller.state["map"] = "432"
MGQ_MpCoopEvents.take(teller, { "pevent" => "say", "map" => "432", "page" => "m.1", "lines" => ["Moved line"].pack("m0") })
check("and their pages from the new map wait for the player", MGQ_MpCoopEvents.instance_variable_get(:@heard).map { |page| page[:page] }, ["m.1"])
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
check("and the pages the teller moved past are left out, so the player is free to go", [$game_message.texts, MGQ_MpCoopEvents.instance_variable_get(:@heard)], [[], []])
class << MGQ_MpCoopGather; alias_method :due?, :due_before_check; end
next_copy = Game_Event.new(2, [story_page], 3)
check("arrived, their copy of the story's next event waits too while the teller's state still says they tell nothing",
      [MGQ_MpCoopEvents.hand_over(next_copy), $log.grep(/kept event 2 on map 432 from starting: the player follows Teller's story to map 432/).size, MGQ_MpCoop::Scope.teller],
      [true, 1, teller])
teller.state["telling"] = "1"
check("and once it says so again", [MGQ_MpCoopEvents.hand_over(next_copy), MGQ_MpCoop::Scope.teller], [true, teller])
teller.state["telling"] = "0"
$frame_count += MGQ_MpCoopGather::CALL_LAPSE_FRAMES
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
