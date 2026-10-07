#----------------------------------------------------------------
#  coop_events_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-07: Took variable 151 as the story's sample, since 150 is each player's own now
#                            - Stood in for the helpers of coop.rbx the party scripts share now, and gave the game's switches their full count, which the story bounds another game's by
#                            - Checked the story's choices a member makes: what is asked, each outcome, the outcomes kept from the leader's story, the choices' companions left out, the prompts of synced play, the leader's offer declined, accepted and taken back, and the other route's start
#                            - Checked when a member follows the leader's story: the rule's edges, a member too far behind, across the Great Decision, on another route, drifting apart and caught up, the leader's followers, and chests shared all the same
#                            - Checked the generator's maps from 1000 on and set_actors, and that the table holds Puruel and Inuel
#                            - Let every member follow the leader's story in the checks of other things
#                            - Gave the world stand-in who, which the log names players with
#                            - Checked that the end of the map's main event ends the telling of the leader's story
#      Paulinchen  2026-10-06: Checked the Great Decision's companions, shops in the story, abilities, personas, held messages of another leader, a story too large to send whole, the generator's gold chests and switch recruits, old pages and frames from before a load
#                            - Took the party's leader from a stand-in of coop.rbx, and the game's raw data from its field
#                            - Took the castle's ghosts' opacity and catch-up tiles from a stand-in of overworld.rbx
#                            - Checked chests on every map, what waited before the whole story, a temporary party, a companion taken twice, the packed story, and that the generator leaves out each player's own switches and variables
#                            - Checked rewards some event gives either side, the side after the Great Decision, own side quests, rewards outside the story, a companion let go and equipment at the castle
#                            - Checked that a member behind the leader catches up with the story, its skills, companions and items, those of their own side, and chooses a side first
#                            - Checked that a member ahead of the leader is lent the key items instead
#                            - Checked that a locked chest stays shut and tells the party nothing
#      Paulinchen  2026-10-04: Checked lent key items and gifts through a load, a crash, a duel, a battle and all at once
#                            - Checked that a chest's sound and first icon reach the members, after a battle once on the map
#                            - Checked that the castle shows the leader's residents, those only the leader has as ghosts
#                            - Checked that the Pocket Castle's way out returns each player where they came from
#                            - Checked that a member not as far along is lent the story's key items, which go back and stay out of saves
#                            - Checked that a call is kept out of a duel, dropped at its end, and waits for a dark screen
#                            - Checked that the members near the leader follow where the story moves the leader
#                            - Checked that a member's story event starts nowhere and says so once
#                            - Checked traders: a side quest that cannot run, a goods script, a quest step behind a choice, a chest that asks first, and the talk's watch
#                            - Checked when the player only waits for the party's story
#                            - Followed gathering into coop_gather.rbx and the Pocket Castle's residents into coop_castle.rbx
#                            - Followed the scripts to their new names, without mp_
#      Paulinchen  2026-10-03: Checked that the Pocket Castle item is travel
#                            - Checked that a member teleports to the leader on their own
#                            - Checked that a member brought to the leader takes over the warp ban of the leader's place
#                            - Gave the world stand-in map_free?
#                            - Gave the world stand-in tell, notice and the own id and seat
#                            - Checked that a chest showing its opened page is still a chest, and that a story event left to the leader lets the next event start
#      Paulinchen  2026-10-02: Checked that members as far along as the leader keep the story, its items, gold and companions, and their own changes
#                            - Checked that a common event sorted deep down is sorted anew higher up, and where the awakening switches end
#                            - Gave the stand-ins the party check and the event page that coop.rbx now holds
#                            - Checked that no random encounter starts for a member the story scene is about to bring over
#      Paulinchen  2026-10-01: Checked that a page counts only the branches that can run now
#                            - Checked that exits noting a flag on the way are travel, and that members come over after five seconds
#                            - Checked that only the leader moves the story dialogue on, and the Pocket Castle's residents sorted as talks
#                            - Checked that a story scene waits for the whole party, at most thirty seconds, which comes over after ten seconds and stands still, and that a member it started without plays on
#                            - Checked that members no longer follow the leader to other maps
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# Covers coop_events.rbx with coop_story.rbx: how event pages are sorted, chests, gathering
# for story scenes, and story events played in the leader's game.

require_relative "support"

module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end
$sent = []
$notices = []
module MGQ_MpOverworldSync
  def self.in_world?; true; end
  def self.notice(text, icon = nil); Status.notice(text); ($icons ||= []) << icon; end
  def self.map_free?; SceneManager.scene.is_a?(Scene_Map) && !$game_map.interpreter.running? && !$game_message.busy? && !$game_player.transfer?; end
  def self.tell(seat, fields, body = ""); Link.send_to(seat, Me.encode(fields) + body); end
  def self.who(peer); peer == :me ? "the player" : "#{peer && peer.state['name']}"; end
  module Peers; Peer = Struct.new(:seat, :state, :ghost, :member); end
  module Me; def self.encode(state); state.map { |k, v| "#{k}=#{v}" }.join("\n") + "\n\n"; end; end
  module Link
    def self.send_to(seat, text)
      fields = {}
      text.split("\n").each { |line| k, v = line.split("=", 2); fields[k] = v if v }
      $sent << [seat, fields]
      true
    end
  end
  module Status; def self.notice(text); $notices << text; end; end
end
module MGQ_MpCoop
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
module RPG
  class BaseItem; attr_accessor :id, :name; def initialize(id, name); @id, @name = id, name; end; def icon_index; 100 + @id; end; end
  # A sound effect, which notes that it played.
  class SE < Struct.new(:name, :volume, :pitch); def play; ($played ||= []) << to_a; end; end
  class Item < BaseItem; attr_writer :key; def key_item?; @key ? true : false; end; end
  class EquipItem < BaseItem; end
  class Weapon < EquipItem; end
  class Armor < EquipItem; end
  EventCommand = Struct.new(:code, :indent, :parameters)
  CommonEvent = Struct.new(:list)
  Page = Struct.new(:list)
end
Command = RPG::EventCommand
# Makes an event command.
#
# @param code [Integer] The command's code.
# @param params [Array] Its parameters.
# @return [RPG::EventCommand] The command.
def c(code, *params); Command.new(code, 0, params); end
System = Struct.new(:switches, :variables)
$data_system = System.new(Array.new(8000, ""), Array.new(4000, ""))
$data_system.switches[20] = "Event General-Purpose 1"
$data_system.variables[7] = "General 0"
$data_common_events = [nil, RPG::CommonEvent.new([c(121, 50, 50, 0)]), RPG::CommonEvent.new([c(101, "", 0, 0, 2), c(117, 3)]), RPG::CommonEvent.new([c(117, 2)])]
$data_actors = Array.new(10)
$data_items = [nil, RPG::Item.new(1, "Potion"), RPG::Item.new(2, "Elixir"), RPG::Item.new(3, "Basement Key")]
$data_items[3].key = true
$data_weapons = [nil, RPG::Weapon.new(1, "Sword")]
$data_armors = [nil]
module Vocab; def self.currency_unit; "G"; end; end

class Game_Switches; def initialize; @data = []; end; def [](id); @data[id] || false; end; def []=(id, value); @data[id] = value; end; end
class Game_Variables; def initialize; @data = []; end; def [](id); @data[id] || 0; end; def []=(id, value); @data[id] = value; end; end
class Game_SelfSwitches; def initialize; @data = {}; end; def [](key); @data[key] == true; end; def []=(key, value); @data[key] = value; end; end

# Reads the data the game keeps for its switches, variables or self switches, past its handling.
#
# @param object [Game_Switches, Game_Variables, Game_SelfSwitches] The object.
# @return [Array, Hash] The data itself.
def raw(object); object.instance_variable_get(:@data); end
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
  def party_member_full?; @actors.size >= 2; end
end
module Graphics; def self.frame_count; $frame_count; end; def self.brightness; $brightness || 255; end; end
$frame_count = 0
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
# The message window's wait for the player's input at a page's end.
class Window_Message
  attr_accessor :pause
  def process_input; input_pause; end
  def input_pause; $own_pause = true; end
end
class Game_Message
  attr_accessor :busy, :face_name, :face_index, :background, :position
  attr_reader :texts, :choices
  def initialize; clear; end
  def clear; @texts = []; @choices = []; end
  def add(text); @texts << text; end
  def busy?; @busy; end
end
class Scene_Map; def update_call_menu; @menu_calling = :asked; end; attr_reader :menu_calling; end
class Scene_Battle; end
class Scene_Menu; end
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
  def show(index); @page = @event.pages[index]; end
end
class Game_Map
  attr_accessor :map_id, :events, :need_refresh, :interpreter, :started
  def initialize; @map_id = 3; @events = {}; @interpreter = Game_Interpreter.new; end
  def setup(map_id); @map_id = map_id; end
  def update(main = false); end
  def setup_starting_map_event
    event = @events.values.find { |e| e.starting }
    event.clear_starting_flag if event
    @started = event
    event
  end
  def setup_autorun_common_event
    common = $data_common_events.find { |c| c && c.autorun? && $game_switches[c.switch_id] }
    @started = common
    common
  end
end
module DataManager
  def self.make_save_contents; {}; end
  def self.extract_save_contents(contents); end
  def self.create_game_objects; end
end

module MGQ_MpCoop
  def self.tell(seat, field, value, fields = {})
    MGQ_MpOverworldSync::Link.send_to(seat, MGQ_MpOverworldSync::Me.encode({ field => value, "party" => Party.id }.merge(fields)))
  end
  def self.route(*); end
end
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
check("its own switch without items is story", kind([c(101, "", 0, 0, 2), c(123, "A", 0)]), :story)
check("a fight without dialogue is a battle", kind([c(301, 0, 5, false, false), c(214)]), :battle)
check("a fight with dialogue is story", kind([c(101, "", 0, 0, 2), c(301, 0, 5, false, false)]), :story)
check("a called common event counts", kind([c(117, 1)]), :story)
check("common events calling each other end", kind([c(117, 2)]), :story)
(20..25).each { |id| $data_common_events[id] = RPG::CommonEvent.new([c(117, id + 1)]) }
$data_common_events[26] = RPG::CommonEvent.new([c(101, "", 0, 0, 2)])
check("a chain of common events too deep counts as story", kind([c(117, 20)]), :story)
check("its end called from higher up is sorted by what it does", kind([c(117, 24)]), :talk)
story = MGQ_MpCoopStory
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
story_choice = [c(101, "", 0, 0, 2), c(121, 60, 60, 0), Command.new(102, 0, [["Yes", "No"], 2]), Command.new(402, 0, [0, "Yes"]), Command.new(121, 1, [61, 61, 0])]
check("story outside a choice stays story", kind(story_choice), :story)
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

$leader = leader
$members = [leader]
$game_map.map_id = 3
$game_player.moveto(1, 1)
MGQ_MpCoopEvents.take(leader, { "pevent" => "travel", "party" => "p1", "map" => "7", "x" => "2", "y" => "2", "d" => "4" })
$game_map.update
$game_map.update
check("a member stays when the leader goes to another map", $game_player.reserved, nil)
MGQ_MpCoopEvents.take(friend, { "pevent" => "gather", "party" => "p1", "map" => "7", "x" => "2", "y" => "2", "d" => "4" })
check("only the leader calls the party to a story scene", MGQ_MpCoopGather.own_line, nil)
$game_map.map_id = 7
$game_player.moveto(2, 2)

# A member called to the leader's story scene.
$notices.clear
leader.state.merge!("map" => "8")
MGQ_MpCoopEvents.take(leader, { "pevent" => "gather", "party" => "p1", "map" => "8", "x" => "9", "y" => "3", "d" => "6" })
$game_map.update
check("a member called to the story hears when they come over", [$notices.last, MGQ_MpCoopGather.own_line], ["Leader's story is starting. You join them in 5 seconds.", "Joining Leader in 5 s . . ."])
check("and is not moved before five seconds", [$game_player.reserved, $game_map.map_id], [nil, 7])
$game_player.encounter_count = 5
check("a member about to come over meets no random encounter while steps are left", $game_player.encounter, false)
$game_player.encounter_count = 0
check("nor once they ran out, which draws new steps", [$game_player.encounter, $game_player.encounter_count], [false, 30])
$frame_count = 150
$game_switches[MGQ_MpCoopStory::WARP_BAN] = true
MGQ_MpCoopEvents.take(leader, { "pevent" => "gather", "party" => "p1", "map" => "8", "x" => "9", "y" => "3", "d" => "6", "warp_ban" => "0" })
check("calls again do not start the time anew", MGQ_MpCoopGather.own_line, "Joining Leader in 3 s . . .")
$frame_count = 300
SceneManager.scene = Scene_Battle.new
$game_map.update
check("a member in battle comes once it is over", [$game_player.reserved, MGQ_MpCoopGather.own_line], [nil, "Joining Leader once free . . ."])
SceneManager.scene = Scene_Map.new
$brightness = 0
$game_map.update
check("not while the screen is still dark from the battle", $game_player.reserved, nil)
$brightness = nil
$game_map.update
check("then they are brought to the leader's map", $game_player.reserved, [8, 9, 3, 6])
check("where warping is allowed again, though they never walked out of the cave they were in", $game_switches[MGQ_MpCoopStory::WARP_BAN], false)
check("a leader tells whether warping is banned where they stand", MGQ_MpCoopGather.place_fields["warp_ban"], 0)
check("the warp ban is each player's own, not the leader's story", MGQ_MpCoopStory.personal_switch?(MGQ_MpCoopStory::WARP_BAN), true)
$game_player.perform_transfer
check("and wait no more", MGQ_MpCoopGather.own_line, nil)
$game_player.encounter_count = 0
check("then random encounters come again", $game_player.encounter, true)
MGQ_MpCoopEvents.take(leader, { "pevent" => "gather", "party" => "p1", "map" => "8", "x" => "11", "y" => "4", "d" => "6" })
check("a member standing near already is not moved", [MGQ_MpCoopGather.own_line, $game_player.x], [nil, 9])
$frame_count = 2000
MGQ_MpCoopEvents.take(leader, { "pevent" => "gather", "party" => "p1", "map" => "5", "x" => "1", "y" => "1", "d" => "2" })
$frame_count = 2359
check("a call stands while the leader still calls", MGQ_MpCoopGather.own_line, "Joining Leader once free . . .")
$frame_count = 2360
$notices.clear
check("asking whether the member is coming once the calls stopped only says no", [MGQ_MpCoopGather.coming?, $notices], [false, []])
$game_map.update
check("once the calls stop, the story started without the member, who stays", [MGQ_MpCoopGather.own_line, $notices.last, $game_player.reserved],
      [nil, "Leader's story started without you.", nil])

# A member teleports to the leader on their own.
$sent.clear
come = { "pevent" => "come", "party" => "p1", "map" => "5", "x" => "1", "y" => "1", "d" => "2", "warp_ban" => "1" }
leader_before = leader.state.dup
leader.state.merge!("map" => "5", "x" => "1", "y" => "1")
MGQ_MpCoopEvents.take(leader, come)
$game_map.update
check("the leader's place moves nobody who did not ask for it", [$game_player.reserved, MGQ_MpCoopGather.own_line], [nil, nil])
MGQ_MpCoopGather.join_leader
check("a member who teleports asks the leader where they stand", [$sent.map { |seat, f| [seat, f["pevent"]] }, $notices.last], [[[leader.seat, "where"]], "Teleporting to Leader . . ."])
MGQ_MpCoopEvents.take(leader, come)
$game_map.update
check("and comes at once, taking over the place's warp ban", [$game_player.reserved, $game_switches[MGQ_MpCoopStory::WARP_BAN]], [[5, 1, 1, 2], true])
$game_player.instance_variable_set(:@reserved, nil)
$sent.clear
leader.state.merge!("map" => $game_map.map_id.to_s, "x" => $game_player.x.to_s, "y" => $game_player.y.to_s)
MGQ_MpCoopGather.join_leader
check("a member standing with the leader already asks nothing", [$sent, $notices.last], [[], "You are with Leader already."])
MGQ_MpCoopEvents.take(friend, { "pevent" => "where", "party" => "p1" })
check("a member never answers where the leader stands", $sent, [])
$game_switches[MGQ_MpCoopStory::WARP_BAN] = false
leader.state.replace(leader_before)

# While the leader's story scene plays, the member stands still.
check("free while the leader tells no story", [$game_player.movable?, MGQ_MpCoopGather.blocked?], [true, false])
leader.state["telling"] = "1"
scene = Scene_Map.new
scene.update_call_menu
check("blocked while it plays: no moving, no menu", [$game_player.movable?, scene.menu_calling], [false, false])
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
check("and waits while one is away", [MGQ_MpCoopGather.holding?(interpreter), MGQ_MpCoopGather.own_line, MGQ_MpCoopEvents.state_fields["telling"]], [true, "Gathering the party . . .", 0])
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
check("then waits for nothing more", MGQ_MpCoopGather.own_line, nil)

# The Pocket Castle's way out returns each player where they came from.
check("where the castle's way out returns is each player's own", (21..23).map { |id| MGQ_MpCoopStory.personal_variable?(id) }, [true, true, true])
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
$sent.clear
$game_map.events[13].start
check("a story event that runs by itself is left to the leader's game", [$game_map.setup_starting_map_event, $sent.size], [nil, 0])
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

class RPG::CommonEvent; attr_accessor :switch_id; def autorun?; !@switch_id.nil?; end; end
raw($game_switches)[70] = true
$data_common_events[4] = RPG::CommonEvent.new([c(101, "", 0, 0, 2), c(121, 60, 60, 0)])
$data_common_events[4].switch_id = 70
class Game_Switches; def [](id); @data[id] || false; end; end
check("a story common event that runs by itself is left to the leader's game too", $game_map.setup_autorun_common_event, nil)
$leader = :me
$members = [friend]
check("the leader's own game runs it", $game_map.setup_autorun_common_event, $data_common_events[4])
$data_common_events[4] = nil

# The leader tells the dialogue; a member's request to play a story event, as older builds sent, starts nothing.
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
$game_message.add("Hello, \\N[1]!")
$game_message.choices.push("Yes", "No")
check("with its face and text", [say["face"], say["index"], say["map"], MGQ_MpCoopEvents.decode(say["lines"].split(",")[0]), say["choices"].split(",").map { |t| MGQ_MpCoopEvents.decode(t) }], ["Alice", "2", "7", "Hello, \\N[1]!", ["Yes", "No"]])
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
check("the leader moving on ends it", [pause.resume, window.pause], [:closed, false])
Fiber.new { window.process_input }.resume
check("then the member's own messages wait for their buttons again", $own_pause, true)
$game_message.clear
$game_message.busy = true
MGQ_MpCoopEvents.take(leader, say.merge("page" => "s.1", "lines" => ["Old page"].pack('m0')))
MGQ_MpCoopEvents.take(leader, { "pevent" => "done", "party" => "p1", "map" => "7", "page" => "s.1" })
MGQ_MpCoopEvents.take(leader, say.merge("page" => "s.2", "lines" => ["Current page"].pack('m0'), "choices" => ""))
$game_message.busy = false
$game_map.update
check("a member busy meanwhile skips the pages the leader moved past", $game_message.texts, ["Current page"])
leader.state["telling"] = "0"
$frame_count += MGQ_MpCoopEvents::STALE_FRAMES
check("a page ends anyway once the leader stopped telling the story a while ago", MGQ_MpCoopEvents.page_done?, true)
MGQ_MpCoopEvents.page_ended
$game_message.clear

# The leader tells the party what their story gives, takes and sends away.
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

# A member as far along as the leader keeps what they play together once the party ends.
# Plays a member's game until the party ends, from their own story to the leader's.
#
# @param own_progress [Integer] The member's main story progress, variable 1001.
# @return [Array] The member's switches, variables and save once back in their own story.
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
  CATCH_UP_TILES = 3
  STRANGER_OPACITY = 150
end
module MGQ_MpCoopNpcs
  def self.following?; $following_npcs; end
  def self.targets; $npc_targets; end
  def self.page_of(event, index); event && index >= 0 ? event.mgq_mp_pages[index] : nil; end
end
Graphic = Struct.new(:tile_id, :character_name, :character_index, :direction, :pattern)
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
module MGQ_MpCoopStoryRewards
  SKILLS = [11, 12, 13]
  ACTORS = [4, 5, 6, 7, 8, 9]
  ITEMS = { "w1" => 1 }
  SIDED = { :skills => [11, 12], :actors => [5, 6, 7, 8, 9] }
  # The Great Decision brings Ilias with the route.
  ROUTE = { :skills => [], :actors => [5] }
  CHESTS = [[40, 1, "A"], [40, 2, "A"]]
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

check("the side each player chose is their own before the Great Decision", [4, 5].map { |id| MGQ_MpCoopStory.personal_switch?(id, []) }, [true, true])
check("but not after it, which sets the side anew with the route", [4, 5].map { |id| MGQ_MpCoopStory.personal_switch?(id, [0] * 1141 + [2]) }, [false, false])
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

# What the code review of the catch-up found: rewards some event gives either side, the side after
# the Great Decision, the member's own side quests, the leader's rewards outside the story, a
# companion let go, and equipment at the castle.
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
Wearer = Struct.new(:equips)
$game_party = Game_Party.new
$game_party.add_stand_actor(7)
$game_actors[7] = Wearer.new([$data_weapons[1], nil])
check("story equipment a companion at the castle wears counts", MGQ_MpCoopStory.story_count($data_weapons[1]), 1)
def $game_party.include_actors; [8]; end
def $game_party.temp_actors_use?; true; end
check("during a temporary party the player's own companions are the roster", MGQ_MpCoopStory.roster_ids, [7])
MGQ_MpCoopStory.bring(9)
check("and one brought in waits at the castle, outside the temporary party", [$game_party.include_actors.include?(9), $game_party.actors], [false, []])
check("in the player's own roster", MGQ_MpCoopStory.roster_ids, [7, 9])

# The game's roster keeps a companion by their main persona, so another persona of one the player
# has is in the roster too, and the leader tells the story companion by whichever persona joined.
$game_party = Game_Party.new
$game_party.add_stand_actor(8)
def $game_actors.original_id(id); id == 9 ? 8 : id; end
check("a companion's other persona is in the roster", [MGQ_MpCoopStory.in_roster?(9), MGQ_MpCoopStory.join(9)], [true, nil])
check("and the leader holds the story companion of either persona", MGQ_MpCoopStory.holdings({})[:actors], [8, 9])
$game_actors = [nil, Hero.new]

# Luka's abilities are kept apart from his skills.
$game_actors[1].instance_variable_set(:@abilities, { 5 => [12] })
check("a story ability Luka knows counts as held", MGQ_MpCoopStory.holdings({})[:skills], [12])
check("and is not learned again", MGQ_MpCoopStory.learn(12), nil)
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
packed = MGQ_MpCoopStory.full(story)
check("the whole story travels packed and reads back with what it turned off", MGQ_MpCoopStory.decode_full(packed),
      [[nil, true, false], [nil, 0, 5], { [1, 2, "A"] => true, [1, 3, "A"] => false }])
limit = MGQ_MpCoopStory::MAX_FULL_BYTES
MGQ_MpCoopStory.send(:remove_const, :MAX_FULL_BYTES)
MGQ_MpCoopStory.const_set(:MAX_FULL_BYTES, 10)
check("one too large leaves out what the story turned off", MGQ_MpCoopStory.decode_full(MGQ_MpCoopStory.full(story)),
      [[nil, true], [nil, nil, 5], { [1, 2, "A"] => true }])
check("and says so", [MGQ_MpCoopStory.full(story)["part"], packed["part"]], [1, nil])
MGQ_MpCoopStory.send(:remove_const, :MAX_FULL_BYTES)
MGQ_MpCoopStory.const_set(:MAX_FULL_BYTES, limit)
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

# The generator of coop_story_rewards.rbx leaves out of its marks exactly what is each player's own.
generator = Module.new
load(File.expand_path("../Tools/story_rewards.rb", __dir__), generator)
own_switches = generator::PERSONAL_SWITCHES.flat_map { |ids| Array(ids) }
own_variables = Object.new.extend(generator).send(:personal_variables, $data_actors.size).flat_map { |ids| Array(ids) }
check("the generator's switches of each player's own are this script's",
      [own_switches.all? { |id| MGQ_MpCoopStory.personal_switch?(id, []) }, (1..8000).select { |id| MGQ_MpCoopStory.personal_switch?(id, []) } - own_switches], [true, []])
check("and so are its variables", [own_variables.all? { |id| MGQ_MpCoopStory.personal_variable?(id) }, (1..8000).select { |id| MGQ_MpCoopStory.personal_variable?(id) } - own_variables], [true, []])

# An event command as the game's data holds it, which the generator reads by its fields.
class ToolCommand
  def initialize(code, parameters, indent = 0); @code = code; @parameters = parameters; @indent = indent; end
end
tool = Object.new.extend(generator)
check("the generator counts a chest of gold alone as a chest", tool.send(:chest?, [ToolCommand.new(125, [0, 0, 50]), ToolCommand.new(123, ["A", 0])]), true)
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

# The table the generator wrote holds what the maps from 1000 on give, such as Puruel and Inuel at
# the Chaos route's snow shrine.
table = Module.new
table.module_eval(File.read(File.join(SCRIPTS_DIR, "coop_story_rewards.rbx"), :encoding => "UTF-8"))
rewards = table::MGQ_MpCoopStoryRewards
check("the table holds Puruel (516) and Inuel (517), and the companions set_actors brings", [516, 517, 6, 33, 35].map { |id| rewards::ACTORS.include?(id) }, [true] * 5)
check("the skills Luka learns on maps from 1000 on, and their chests",
      [rewards::SKILLS.include?(9799), rewards::CHESTS.any? { |key| key[0] >= 1000 }], [true, true])

# The story's choices a member makes for themselves, coop_choices.rbx: what is asked, each outcome
# applied, the leader's offer to sync the story, and the Great Decision's other route.
module MGQ_MpActions
  LINE_COLOR = :line_color
  Option = Struct.new(:text, :run, :refusal, :icon, :leaves)
  Notice = Struct.new(:key, :text, :color, :action, :take, :decline, :mark)
  def self.offer(offers); ($offered ||= []) << offers; end
end
# The world screen's form, which the screen of choices draws with, stood in by its fields alone.
class Window_MpWorldForm; def initialize(*); end; end
class Scene_MenuBase; end
module SceneManager; def self.call(scene); ($scenes ||= []) << scene; end; end
module MGQ_MpWorld
  class Form
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
load_script "coop_choices"
choices = MGQ_MpCoopChoices
{ 5 => "Alice", 26 => "Ilias", 163 => "Lily", 167 => "Lucia", 287 => "Succubus", 288 => "Natasha", 540 => "Amira", 153 => "Sphinx", 241 => "Priestess",
  245 => "Miria", 334 => "Spider Princess" }.each { |id, name| $data_actors[id] = Actor.new(name) }

check("a catch-up from the start to the Great Decision asks every choice, in story order",
      choices.passed(5, 40, [], [], []), [:side, :amira, :magistea, :plansect, :succubus, :spider, :sphinx, :decision])
check("one from 20 to 32 asks those between, and not one the player made",
      choices.passed(20, 32, Array.new(3000).tap { |s| s[2096] = true }, [], []), [:plansect, :succubus, :spider, :sphinx])
check("Amira is asked of every member who never had her join, though killed or long past her",
      [choices.passed(20, 32, Array.new(3000).tap { |s| s[2108] = true }, [], [], [:amira]).include?(:amira),
       choices.passed(20, 32, Array.new(3000).tap { |s| s[2127] = true }, [], [], [:amira]).include?(:amira)], [true, false])
check("the Great Decision is not asked before the leader is past it", choices.passed(30, 39, [], [], []).include?(:decision), false)
$game_system_switches = {}
check("the third way only with both endings cleared", choices.labels(:decision).size, 2)
$game_system_switches = { :ed1 => true, :ed2 => true }
check("which offers it", choices.labels(:decision).last, "Search for a third way (Chaos)")
$game_system_switches = {}

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
choices.apply(:amira, 1)
choices.apply(:plansect, 1)
choices.apply(:spider, 0)
choices.apply(:sphinx, 1)
check("Amira killed, the Queen Bee's side, the Spider Princess and the Sphinx invited",
      [$game_switches[2108], $game_variables[1061], $game_switches[2154], $game_switches[2280], [245, 334, 153].map { |id| $game_party.include_actors.include?(id) }],
      [true, 2, true, true, [true, true, true]])

# The outcomes the member made stay theirs in the leader's story, and the leader's choices'
# companions never come with it.
$real_sync = false
choices.forget("next check")
member_game(30, 5)
choices.apply(:magistea, 0)
MGQ_MpCoopStory.take(leader, behind_story.merge("s" => "120,2097", "ac" => "4,163"))
check("the leader's outcome of Magistea Village stays out of the member's story",
      [$game_switches[2096], $game_switches[2097], MGQ_MpCoopStory.personal_switch?(2097)], [true, false, true])
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
check("accepting shows the choices the catch-up carries them past, Amira always",
      [$scenes, screen[:keys], screen[:buttons]], [[Scene_MpStoryChoices], [:amira, :plansect, :succubus, :spider, :sphinx, :decision], ["Bring me there", "Cancel"]])
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
choices.confirm_offer(leader, [40, 3, 0, 1], 0, :amira => 0, :plansect => 0, :succubus => 0, :spider => 1, :sphinx => 0, :decision => 1)
check("the member's outcomes are theirs before the leader's story comes",
      [$game_switches[2127], $game_variables[1061], $game_switches[2281], $game_party.include_actors.include?(540)], [true, 1, true, true])
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
