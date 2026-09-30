#----------------------------------------------------------------
#  coop_events_test.rb
#
#  Changelog:
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# Covers mp_coop_events.rbx with mp_coop_story.rbx: how event pages are sorted, chests, travelling
# together, and story events played in the leader's game.

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

class Game_Switches; def initialize; @data = []; end; end
class Game_Variables; def initialize; @data = []; end; end
class Game_SelfSwitches; def initialize; @data = {}; end; end
class Game_Party
  attr_reader :items, :gold
  def initialize; @items = Hash.new(0); @gold = 0; end
  def gain_item(item, amount, include_equip = false, keep_flag = false); @items[item.name] += amount; end
  def gain_gold(amount); @gold += amount; end
end
class Game_Interpreter
  attr_accessor :busy
  def setup(list, event_id = 0); @list = list; @event_id = event_id; end
  def run; @list.each { |command| $game_party.gain_item($data_items[command.parameters[0]], command.parameters[3]) if command.code == 126 }; end
  def running?; @busy; end
end
class Game_Player
  attr_reader :x, :y, :direction, :reserved
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
class Game_Message
  attr_accessor :busy, :face_name, :face_index, :background, :position
  attr_reader :texts, :choices
  def initialize; clear; end
  def clear; @texts = []; @choices = []; end
  def add(text); @texts << text; end
  def busy?; @busy; end
end
class Scene_Map; end
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
check("the leader takes the party along", $sent.map { |seat, f| [seat, f["pevent"], f["map"], f["x"], f["y"], f["d"]] }, [[-1, "travel", "9", "4", "5", "8"]])
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
MGQ_MpCoopEvents.take(friend, { "pevent" => "travel", "party" => "p1", "map" => "7", "x" => "2", "y" => "2", "d" => "4" })
$game_map.update
MGQ_MpCoopEvents.update
check("only the leader is followed", $game_player.reserved, nil)
MGQ_MpCoopEvents.take(leader, { "pevent" => "travel", "party" => "p1", "map" => "7", "x" => "2", "y" => "2", "d" => "4" })
$game_message.busy = true
MGQ_MpCoopEvents.update
check("a member in a message follows later", $game_player.reserved, nil)
$game_message.busy = false
SceneManager.scene = Scene_Menu.new
MGQ_MpCoopEvents.update
check("so does a member in a menu", $game_player.reserved, nil)
SceneManager.scene = Scene_Map.new
MGQ_MpCoopEvents.update
check("then the member goes where the leader went", $game_player.reserved, [7, 2, 2, 4])
$game_player.perform_transfer
MGQ_MpCoopEvents.take(leader, { "pevent" => "gather", "party" => "p1", "map" => "7", "x" => "9", "y" => "3", "d" => "6" })
MGQ_MpCoopEvents.update
check("a story scene brings the member to the leader", [$game_player.x, $game_player.y, $game_player.direction, $game_player.reserved], [9, 3, 6, nil])
MGQ_MpCoopEvents.take(leader, { "pevent" => "gather", "party" => "p1", "map" => "8", "x" => "1", "y" => "1", "d" => "2" })
MGQ_MpCoopEvents.update
check("but only on the leader's map", [$game_player.x, $game_player.y, $game_player.reserved], [9, 3, nil])

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
$game_map.interpreter.wait_for_message
says = $sent.select { |_, f| f["pevent"] == "say" }
check("the leader's story message goes to the party once", says.size, 1)
say = says.first[1]
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
check("then the leader's message", [$game_message.face_name, $game_message.texts], ["Alice", ["Hello, \\N[1]!"]])
$game_message.clear
MGQ_MpCoopEvents.update
check("then what the leader chooses from", $game_message.texts, ["Leader chooses:", "Yes", "No"])
