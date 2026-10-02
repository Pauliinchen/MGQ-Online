#----------------------------------------------------------------
#  coop_events_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-02: Checked that no random encounter starts for a member the story scene is about to bring over
#      Paulinchen  2026-10-01: Checked that a page counts only the branches that can run now
#                            - Checked that exits noting a flag on the way are travel, and that members come over after five seconds
#                            - Checked that only the leader moves the story dialogue on, and the Pocket Castle's residents sorted as talks
#                            - Checked that a story scene waits for the whole party, at most thirty seconds, which comes over after ten seconds and stands still, and that a member it started without plays on
#                            - Checked that members no longer follow the leader to other maps
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# Covers mp_coop_events.rbx with mp_coop_story.rbx: how event pages are sorted, chests, gathering
# for story scenes, and story events played in the leader's game.

require_relative "support"

module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end
$sent = []
$notices = []
module MGQ_MpOverworldSync
  def self.in_world?; true; end
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
  attr_reader :items, :gold
  def initialize; @items = Hash.new(0); @gold = 0; end
  def gain_item(item, amount, include_equip = false, keep_flag = false); @items[item.name] += amount; end
  def gain_gold(amount); @gold += amount; end
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
load_script "mp_coop_story"
load_script "mp_coop_events"

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
check("items and the event's own switch make a chest", kind([c(126, 1, 0, 0, 1), c(123, "A", 0)]), :chest)
check("with a found-it message too", kind([c(101, "", 0, 0, 2), c(126, 1, 0, 0, 1), c(123, "A", 0)]), :chest)
check("its own switch without items is story", kind([c(101, "", 0, 0, 2), c(123, "A", 0)]), :story)
check("a fight without dialogue is a battle", kind([c(301, 0, 5, false, false), c(214)]), :battle)
check("a fight with dialogue is story", kind([c(101, "", 0, 0, 2), c(301, 0, 5, false, false)]), :story)
check("a called common event counts", kind([c(117, 1)]), :story)
check("common events calling each other end", kind([c(117, 2)]), :story)

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
MGQ_MpCoopEvents.update
check("a member stays when the leader goes to another map", $game_player.reserved, nil)
MGQ_MpCoopEvents.take(friend, { "pevent" => "gather", "party" => "p1", "map" => "7", "x" => "2", "y" => "2", "d" => "4" })
check("only the leader calls the party to a story scene", MGQ_MpCoopEvents.own_line, nil)
$game_map.map_id = 7
$game_player.moveto(2, 2)

# A member called to the leader's story scene.
$notices.clear
leader.state.merge!("map" => "8")
MGQ_MpCoopEvents.take(leader, { "pevent" => "gather", "party" => "p1", "map" => "8", "x" => "9", "y" => "3", "d" => "6" })
MGQ_MpCoopEvents.update
check("a member called to the story hears when they come over", [$notices.last, MGQ_MpCoopEvents.own_line], ["Leader's story is starting. You join them in 5 seconds.", "Joining Leader in 5 s . . ."])
check("and is not moved before five seconds", [$game_player.reserved, $game_map.map_id], [nil, 7])
$game_player.encounter_count = 5
check("a member about to come over meets no random encounter while steps are left", $game_player.encounter, false)
$game_player.encounter_count = 0
check("nor once they ran out, which draws new steps", [$game_player.encounter, $game_player.encounter_count], [false, 30])
$frame_count = 150
MGQ_MpCoopEvents.take(leader, { "pevent" => "gather", "party" => "p1", "map" => "8", "x" => "9", "y" => "3", "d" => "6" })
check("calls again do not start the time anew", MGQ_MpCoopEvents.own_line, "Joining Leader in 3 s . . .")
$frame_count = 300
SceneManager.scene = Scene_Battle.new
MGQ_MpCoopEvents.update
check("a member in battle comes once it is over", [$game_player.reserved, MGQ_MpCoopEvents.own_line], [nil, "Joining Leader once free . . ."])
SceneManager.scene = Scene_Map.new
MGQ_MpCoopEvents.update
check("then they are brought to the leader's map", $game_player.reserved, [8, 9, 3, 6])
$game_player.perform_transfer
check("and wait no more", MGQ_MpCoopEvents.own_line, nil)
$game_player.encounter_count = 0
check("then random encounters come again", $game_player.encounter, true)
MGQ_MpCoopEvents.take(leader, { "pevent" => "gather", "party" => "p1", "map" => "8", "x" => "11", "y" => "4", "d" => "6" })
check("a member standing near already is not moved", [MGQ_MpCoopEvents.own_line, $game_player.x], [nil, 9])
$frame_count = 2000
MGQ_MpCoopEvents.take(leader, { "pevent" => "gather", "party" => "p1", "map" => "5", "x" => "1", "y" => "1", "d" => "2" })
$frame_count = 2359
check("a call stands while the leader still calls", MGQ_MpCoopEvents.own_line, "Joining Leader once free . . .")
$frame_count = 2360
$notices.clear
check("asking whether the member is coming once the calls stopped only says no", [MGQ_MpCoopEvents.coming?, $notices], [false, []])
MGQ_MpCoopEvents.update
check("once the calls stop, the story started without the member, who stays", [MGQ_MpCoopEvents.own_line, $notices.last, $game_player.reserved],
      [nil, "Leader's story started without you.", nil])

# While the leader's story scene plays, the member stands still.
check("free while the leader tells no story", [$game_player.movable?, MGQ_MpCoopEvents.blocked?], [true, false])
leader.state["telling"] = "1"
scene = Scene_Map.new
scene.update_call_menu
check("blocked while it plays: no moving, no menu", [$game_player.movable?, scene.menu_calling], [false, false])
leader.state["map"] = "5"
check("a member on another map, whom the story started without, plays on", [$game_player.movable?, MGQ_MpCoopEvents.blocked?], [true, false])
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
check("and waits while one is away", [MGQ_MpCoopEvents.holding?(interpreter), MGQ_MpCoopEvents.own_line, MGQ_MpCoopEvents.state_fields["telling"]], [true, "Gathering the party . . .", 0])
$sent.clear
$frame_count = 1100
MGQ_MpCoopEvents.holding?(interpreter)
check("calling again only every three seconds", $sent.size, 0)
$frame_count = 1200
MGQ_MpCoopEvents.holding?(interpreter)
check("then once more", $sent.map { |_, f| f["pevent"] }, ["gather"])
check("other interpreters never wait", MGQ_MpCoopEvents.holding?(Game_Interpreter.new), false)
friend.state.merge!("map" => "3", "x" => "7", "y" => "4")
check("once everyone stands near, the scene plays", [MGQ_MpCoopEvents.holding?(interpreter), $notices.last, MGQ_MpCoopEvents.state_fields["telling"]], [false, "The party is here.", 1])
interpreter.busy = false
check("and the members are free once it ends", MGQ_MpCoopEvents.state_fields["telling"], 0)
$sent.clear
interpreter.setup([c(101, "", 0, 0, 2), c(121, 60, 60, 0)], 1)
check("a party gathered already plays at once", [$sent.size, MGQ_MpCoopEvents.holding?(interpreter)], [0, false])
friend.state.merge!("map" => "9", "x" => "1", "y" => "1")
$frame_count = 3000
interpreter.setup([c(101, "", 0, 0, 2), c(121, 60, 60, 0)], 1)
interpreter.busy = true
$frame_count = 4799
check("a member who does not come holds the scene up to thirty seconds", MGQ_MpCoopEvents.holding?(interpreter), true)
$frame_count = 4800
check("then it plays without them", [MGQ_MpCoopEvents.holding?(interpreter), $notices.last, MGQ_MpCoopEvents.state_fields["telling"]],
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
check("the leader is asked to play it", $sent.map { |seat, f| [seat, f["pevent"], f["map"], f["event"]] }, [[4, "run", "7", "11"]])
check("and the member hears where it goes on", $notices.last, "The story goes on in Leader's game.")
$game_map.events[12].start
check("a talk runs in the member's own game", $game_map.setup_starting_map_event, $game_map.events[12])
$sent.clear
$game_map.events[13].start
check("a story event that runs by itself is left to the leader's game", [$game_map.setup_starting_map_event, $sent.size], [nil, 0])
leader.state["map"] = "8"
$game_map.events[11].start
$game_map.setup_starting_map_event
check("with the leader elsewhere, the member is told to bring them", [$sent.size, $notices.last], [0, "Leader leads the party's story. Bring them here to go on."])
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

# The leader plays requested events and tells the dialogue.
$game_message.busy = false
$game_map.interpreter.busy = false
MGQ_MpCoopEvents.take(friend, { "pevent" => "run", "party" => "p1", "map" => "7", "event" => "11" })
MGQ_MpCoopEvents.take(stranger = MGQ_MpOverworldSync::Peers::Peer.new(8, { "party" => "p9" }, nil, false), { "pevent" => "run", "party" => "p1", "map" => "7", "event" => "12" })
$game_map.interpreter.busy = true
MGQ_MpCoopEvents.update
check("a requested event waits while the leader is busy", $game_map.events[11].starting ? true : false, false)
$game_map.interpreter.busy = false
MGQ_MpCoopEvents.update
check("then starts in the leader's game", $game_map.events[11].starting, true)
check("only for party members", $game_map.events[12].starting, false)
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

# A member sees the leader's dialogue.
$leader = leader
$members = [leader]
$game_message.clear
$game_message.busy = true
MGQ_MpCoopEvents.take(leader, say)
MGQ_MpCoopEvents.update
check("a member busy with a message sees the leader's later", $game_message.texts, [])
$game_message.busy = false
MGQ_MpCoopEvents.update
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
MGQ_MpCoopEvents.update
check("a member busy meanwhile skips the pages the leader moved past", $game_message.texts, ["Current page"])
leader.state["telling"] = "0"
$frame_count += MGQ_MpCoopEvents::STALE_FRAMES
check("a page ends anyway once the leader stopped telling the story a while ago", MGQ_MpCoopEvents.page_done?, true)
MGQ_MpCoopEvents.page_ended
$game_message.clear
