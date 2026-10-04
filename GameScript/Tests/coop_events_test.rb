#----------------------------------------------------------------
#  coop_events_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-04: Checked that a member's story event starts nowhere and says so once
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
  def self.notice(text); Status.notice(text); end
  def self.map_free?; SceneManager.scene.is_a?(Scene_Map) && !$game_map.interpreter.running? && !$game_message.busy? && !$game_player.transfer?; end
  def self.tell(seat, fields, body = ""); Link.send_to(seat, Me.encode(fields) + body); end
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
end
module RPG
  class BaseItem; attr_accessor :id, :name; def initialize(id, name); @id, @name = id, name; end; end
  class Item < BaseItem; end
  class Weapon < BaseItem; end
  class Armor < BaseItem; end
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
$data_system = System.new(Array.new(200, ""), Array.new(4000, ""))
$data_system.switches[20] = "Event General-Purpose 1"
$data_system.variables[7] = "General 0"
$data_common_events = [nil, RPG::CommonEvent.new([c(121, 50, 50, 0)]), RPG::CommonEvent.new([c(101, "", 0, 0, 2), c(117, 3)]), RPG::CommonEvent.new([c(117, 2)])]
$data_actors = Array.new(10)
$data_items = [nil, RPG::Item.new(1, "Potion"), RPG::Item.new(2, "Elixir")]
$data_weapons = [nil, RPG::Weapon.new(1, "Sword")]
$data_armors = [nil]
module Vocab; def self.currency_unit; "G"; end; end

class Game_Switches; def initialize; @data = []; end; def [](id); @data[id] || false; end; def []=(id, value); @data[id] = value; end; end
class Game_Variables; def initialize; @data = []; end; def [](id); @data[id] || 0; end; def []=(id, value); @data[id] = value; end; end
class Game_SelfSwitches; def initialize; @data = {}; end; end
class Game_Party
  attr_reader :items, :gold, :actors, :include_actors
  attr_accessor :in_battle
  def initialize; @items = Hash.new(0); @gold = 0; @actors = []; @include_actors = []; end
  def gain_item(item, amount, include_equip = false, keep_flag = false); @items[item.name] += amount; end
  def gain_gold(amount); @gold += amount; end
  def add_actor(actor_id); add_stand_actor(actor_id); @actors << actor_id; end
  def add_stand_actor(actor_id); @include_actors << actor_id; end
  def remove_actor(actor_id); @include_actors.delete(actor_id); @actors.delete(actor_id); end
  def exist_all_actor_id?(actor_id); @include_actors.include?(actor_id); end
  def exist_party_actor_id?(actor_id); @actors.include?(actor_id); end
  def party_member_full?; @actors.size >= 2; end
end
module Graphics; def self.frame_count; $frame_count; end; end
$frame_count = 0
class Game_Interpreter
  attr_accessor :busy
  def execute_command; end
  def setup(list, event_id = 0); @list = list; @event_id = event_id; end
  def run; @list.each { |command| $game_party.gain_item($data_items[command.parameters[0]], command.parameters[3]) if command.code == 126 }; end
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
class Game_Event
  attr_reader :id, :starting, :trigger, :locked
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
end
load_script "coop_story"
load_script "coop_events"
load_script "coop_gather"
load_script "coop_castle"

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
check("the awakening switches end with the last companion's",
      [story.personal_switch?(story::AWAKENING_SWITCHES + 9), story.personal_switch?(story::AWAKENING_SWITCHES + 10)], [true, false])

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
check("opening a chest tells the party what was in it", $sent.map { |seat, f| [seat, f["chest"], f["gains"]] }, [[-1, "3.5.A", "i1x2"]])
$sent.clear
other = Game_Interpreter.new
other.setup(talk_page.list, 6)
other.run
check("other events tell nothing", $sent.size, 0)

MGQ_MpCoopEvents.take(friend, { "chest" => "4.9.A", "party" => "p1", "gains" => "i2x1,w1x1,g0x50" })
check("a chest a member opened gives the same items", [$game_party.items["Elixir"], $game_party.items["Sword"], $game_party.gold], [1, 1, 50])
check("and marks it looted", $game_self_switches.mgq_mp_data[[4, 9, "A"]], true)
check("with a notice", $notices.last, "Friend opened a chest for the party: Elixir, Sword, 50 G.")
$sent.clear
MGQ_MpCoopEvents.take(friend, { "chest" => "4.9.A", "party" => "p1", "gains" => "i2x1" })
check("a chest looted already gives nothing more", $game_party.items["Elixir"], 1)
check("and granting tells nobody", $sent.size, 0)
MGQ_MpCoopEvents.take(MGQ_MpOverworldSync::Peers::Peer.new(8, { "party" => "p9" }, nil, false), { "chest" => "4.8.A", "party" => "p1", "gains" => "i1x9" })
check("strangers give nothing", $game_party.items["Potion"], 2)
MGQ_MpCoopEvents.take(friend, { "chest" => "4.7.A", "party" => "p1", "gains" => "q1x1,i99x1,i1x1" })
check("unknown items are skipped", $game_party.items["Potion"], 3)

# Chests while playing the leader's story.
leader = MGQ_MpOverworldSync::Peers::Peer.new(4, { "id" => "l", "name" => "Leader", "party" => "p1" }, nil, true)
$leader = leader
$members = [leader]
$game_self_switches.mgq_mp_data[[3, 5, "A"]] = nil
MGQ_MpCoopStory.take(leader, { "story" => "full", "party" => "p1", "s" => "", "v" => "", "ss" => "3.5.A,3.1.B" })
check("a member's chests stay their own on the leader's story", [$game_self_switches.mgq_mp_data[[3, 5, "A"]], $game_self_switches.mgq_mp_data[[3, 1, "B"]]], [nil, true])
MGQ_MpCoopStory.take(leader, { "story" => "delta", "party" => "p1", "s" => "", "v" => "", "ss" => "3.5.A:1" })
check("and the leader's chests do not change them", $game_self_switches.mgq_mp_data[[3, 5, "A"]], nil)
$game_map.interpreter.setup(chest_page.list, 5)
$game_self_switches.mgq_mp_data[[3, 5, "A"]] = true
$game_map.interpreter.run
check("a chest a member opens is theirs for good", MGQ_MpCoopStory.own_self_switch([3, 5, "A"]), true)
$party = nil
$leader = nil
$members = []
$game_map.update
MGQ_MpCoopStory.update
check("and stays opened in their own story", $game_self_switches.mgq_mp_data[[3, 5, "A"]], true)

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
interpreter.busy = false
$leader = leader
$members = [leader]
$game_map.map_id = 7

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
leader.state["map"] = "7"

class RPG::CommonEvent; attr_accessor :switch_id; def autorun?; !@switch_id.nil?; end; end
$game_switches.mgq_mp_data[70] = true
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
MGQ_MpCoopEvents.instance_variable_set(:@telling, false)

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
  $game_variables[150] = 7
  $game_switches[90] = true
  [["gain", "item", "i1x2"], ["gain", "item", "g0x-30"], ["gain", "item", "w1x1"], ["depart", "actor", "3"], ["recruit", "actor", "3"], ["recruit", "actor", "4"]].each do |kind, field, value|
    MGQ_MpCoopStory.take($story_leader, { "story" => kind, "party" => "p1", field => value })
  end
  save = MGQ_MpCoopStory.save_contents(:switches => $game_switches, :variables => $game_variables, :self_switches => $game_self_switches)
  saved = [save[:switches][82], save[:variables][1001], save[:variables][150]]
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
check("and what changed in their own game meanwhile", [switches[90], variables[150]], [true, 7])
check("a save made in the party holds it too", saved, [true, 41, 7])
check("the story's items and gold are theirs", [$game_party.items["Potion"], $game_party.items["Sword"], $game_party.gold], [2, 1, -30])
check("a companion the story sent away and brought back is in the party again, a new one waits at the castle",
      [$game_party.actors, $game_party.include_actors], [[3], [3, 4]])
check("with notices", $notices.include?("Leader's story took 30 G from you too.") && $notices.include?("Tamamo joined you too."), true)

joined, switches, variables, saved = play_along(30)
check("a member behind the leader keeps none of the leader's story", [switches[80], switches[82], variables[1001], switches[90], variables[150]], [true, false, 30, false, 0])
check("nor its items, gold or companions", [$game_party.items["Potion"], $game_party.gold, $game_party.include_actors], [0, 0, [3]])
