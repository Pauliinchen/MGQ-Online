#----------------------------------------------------------------
#  pvp_backline_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-12: Stood in for the Mod Config settings group
#      Paulinchen  2026-10-07: Loaded coop.rbx and stood in for the live battle's list of names
#      Paulinchen  2026-10-04: Followed the scripts to their new names
#      Paulinchen  2026-10-03: Created
#
#----------------------------------------------------------------

# Covers battles_pvp_backline.rbx: the option, the other side's characters outside its Frontline,
# the Frontline each game tells the other, what a swap costs the character swapped in, and the
# characters outside both Frontlines in the host's stream.

require_relative "support"

$log = []
# Stands in for the mod's base script.
module MGQ_Multiplayer
  # Stands in for the log, which notes each line in $log.
  module Log; def self.write(m); $log << m; end; end
  # Stands in for the DLL link: the player's id is always me-id-000.
  module Link; def self.player_id; "me-id-000"; end; end
  # Stands in for Discord, which is not running.
  module Discord; def self.available?; false; end; end
end
# Stands in for the world's sync, as far as coop.rbx, through which the option registers, asks it.
module MGQ_MpOverworldSync
  # Stands in for the check for an open world: the player is in none.
  def self.in_world?; false; end
  # Stands in for routing a field's messages, ignoring the handler.
  def self.route(*); end
  # Stands in for running a block each frame, ignoring it.
  def self.on_tick(*); end
  # Stands in for adding fields to the player's state, ignoring the block.
  def self.state_fields(*); end
  # Stands in for watching the other players, ignoring the block.
  def self.on_observe(*); end
  # Stands in for running a block as the player leaves, ignoring it.
  def self.on_leave(*); end
  # Stands in for adding a line above the player's head, ignoring it.
  def self.label_line(*); end
  # Stands in for the other players of the world, of whom there are none.
  module Peers
    # Another player as the world's sync knows them.
    Peer = Struct.new(:seat, :state, :ghost, :member)
    # Stands in for listing the other players: there are none.
    def self.all; []; end
  end
  # Stands in for the player: id me-id-000, named Me.
  module Me; def self.identity; ["me-id-000", "Me"]; end; def self.id; identity[0]; end; end
end
# Stands in for the action wheel, which coop.rbx offers its actions in.
module MGQ_MpActions
  # Stands in for the color of the line above the player's head.
  LINE_COLOR = :line
  # Stands in for offering an action, ignoring it.
  def self.offer(*); end
  # Stands in for registering a choice of the wheel, ignoring it.
  def self.wheel_choice(*); end
  # Stands in for the player's doing as the other players see it: none.
  def self.own_doing_from; end
end
# Stands in for the game's colors.
class Color; def initialize(*); end; end
# Stands in for the game's scenes, the running one in $scene.
module SceneManager
  # Stands in for starting the game, doing nothing.
  def self.run; end
  # Stands in for the running scene: answers $scene.
  def self.scene; $scene; end
end
# Stands in for the battle's sprites, counting in drawn how often the enemies are drawn anew.
class Spriteset; attr_reader :drawn; def dispose_enemies; end; def create_enemies; @drawn = (@drawn || 0) + 1; end; end
# Stands in for the battle's scene.
class Scene_Battle
  # Makes the scene with its sprites.
  def initialize; @spriteset = Spriteset.new; end
  # Stands in for the Party command's swap: swaps the places $swap names.
  def bench_member_ok; $game_party.swap(*$swap); end
end
# Stands in for the game's options, without the Mod Config, which the option goes into.
module NWConst
  # The options' entries, values, texts and defaults.
  module Config
    # The options' entries, which the option goes before the last of.
    CONTENTS = [{ :key => :first }, { :key => :last }]
    # Each option's values.
    DATA = {}
    # Each option's names and help of its values.
    DATA_TEXT = {}
    # Each option's default value.
    DEFAULT = {}
  end
end
# Stands in for the game's system object, which holds the options' values in conf.
System = Struct.new(:conf)
$game_system = System.new({})

# The game's characters, as far as the Backline follows them.
class Game_Battler
  attr_reader :id, :name, :actions
  # Makes a character without actions.
  #
  # @param id [Integer] Its id.
  # @param name [String] Its name.
  def initialize(id, name); @id = id; @name = name; @actions = []; end
  # Drops the character's actions.
  def clear_actions; @actions = []; end
  # Stands in for whether the character gives commands: answers true.
  def inputable?; true; end
  # Gives the character an attack as its action.
  def make_actions; @actions = [:attack]; end
end
# A character of the player's own.
class Game_Actor < Game_Battler; end
# A side of the battle, whose skills reach all its members.
class Game_Unit; def item_target_members(_item); members; end; end
# The player's party: the first two characters are its Frontline, the rest its Backline.
class Game_Party < Game_Unit
  attr_reader :all_members
  # Makes the party.
  #
  # @param members [Array<Game_Actor>] Its characters in their order.
  def initialize(members); @all_members = members; end
  # Answers the Frontline, the first two characters.
  def battle_members; @all_members.first(2); end
  # Answers the Backline, every character after the first two.
  def bench_members; @all_members[2..-1] || []; end
  # Answers the Frontline.
  def members; battle_members; end
  # Swaps two characters' places.
  #
  # @param first [Integer] The first place.
  # @param second [Integer] The second place.
  def swap(first, second); @all_members[first], @all_members[second] = @all_members[second], @all_members[first]; end
end
# The troop, which holds the other side's Frontline.
class Game_Troop < Game_Unit
  attr_accessor :turn_count
  # Makes an empty troop at turn 0.
  def initialize; @enemies = []; @turn_count = 0; end
  # Answers the troop's characters.
  def members; @enemies; end
end

# Stands in for the battles, keeping each battle kind's mode.
module MGQ_MpBattles
  # Stands in for a battle kind's mode, whose stream carries no messages of its own.
  module Mode; def stream_kinds; []; end; end
  # Keeps a battle kind's mode.
  #
  # @param name [Symbol] The battle kind.
  # @param mode [Module] Its mode.
  def self.mode(name, mode); (@modes ||= {})[name] = mode; end
  # Answers the mode kept for a battle kind.
  #
  # @param name [Symbol] The battle kind.
  # @return [Module, nil] Its mode.
  def self.mode_of(name); @modes[name]; end
end
# Stands in for the PvP battle.
module MGQ_MpBattlesPvp
  # A character of the other side.
  class Opponent < Game_Actor; end
  # Stands in for placing the other side's characters, noting their ids in $stood.
  module Opponents; def self.stand(opponents); $stood = opponents.map(&:id); opponents; end; end
end
# Stands in for the live battle, which the player hosts and whose stream notes its posts in $posted.
module MGQ_MpBattlesSync
  # Stands in for whether the player hosts: answers true.
  def self.host?; true; end
  # Names characters by name and id, as the live battle does.
  #
  # @param battlers [Array<Game_Battler>] The characters.
  # @return [String] Their names, "nobody" for none.
  def self.named_list(battlers); battlers.empty? ? "nobody" : battlers.map { |battler| "#{battler.name} (#{battler.id})" }.join(", "); end
  # Stands in for the recorder of the host's stream, which is on and notes each flush in $posted.
  module Recorder; def self.active?; true; end; def self.flush; $posted << [:flush]; end; end
  # Stands in for the battle's channel, noting each post in $posted.
  module Channel; def self.post(kind, body); $posted << [kind, body]; end; end
  # Stands in for the stream's wire format, which is Marshal here.
  module Wire
    # Writes values as a line.
    def self.line(values); Marshal.dump(values); end
    # Reads a line's values back.
    def self.parse(text); Marshal.load(text); end
  end
end
$posted = []

load File.join(SCRIPTS_DIR, "core_log.rbx")
# Gives the PvP battle the log it writes with.
module MGQ_MpBattlesPvp; extend MGQ_MpLog; LOG_TAG = "pvp battle"; end
# Stands in for the mod's UI: the first words of the mod's settings in the Mod Config, as ui.rbx
# names them.
module MGQ_MpUi; OPTION_PREFIX = "[MGQ Online Settings] " unless const_defined?(:OPTION_PREFIX); end
load_script "coop"
load_script "battles_pvp_backline"
SceneManager.run
backline = MGQ_MpBattlesPvp::Backline
mode = MGQ_MpBattles.mode_of(:duel)
# A skill that may reach the Backline, or the Backline alone.
item = Struct.new(:bench, :only) do
  # Answers whether the skill reaches the Backline too.
  def include_bench?; bench; end
  # Answers whether the skill reaches the Backline alone.
  def bench_only?; only; end
end

# The option goes into the options, with the Backline by default.
config = NWConst::Config
check("the option goes before the options' last entry", config::CONTENTS.map { |entry| entry[:key] }, [:first, backline::OPTION, :last])
check("with the Backline by default", [config::DEFAULT[backline::OPTION], backline.wanted?], [backline::WITH_BACKLINE, true])
$game_system.conf[backline::OPTION] = backline::FRONTLINE_ONLY
check("the player can leave the Backline out", backline.wanted?, false)

own = [Game_Actor.new(1, "Luka"), Game_Actor.new(2, "Alice"), Game_Actor.new(3, "Ilias"), Game_Actor.new(4, "Sonya")]
$game_party = Game_Party.new(own.dup)
$game_troop = Game_Troop.new
others = [5, 6, 7].map { |id| MGQ_MpBattlesPvp::Opponent.new(id, "Friend #{id}") }
$game_troop.instance_variable_set(:@enemies, others.first(2))
$scene = Scene_Battle.new

# Outside a battle nothing is swapped in or kept in reserve.
check("outside a battle nothing is swapped in or kept in reserve", [backline.on?, backline.swapped_in?(own[0]), backline.reserve, mode.own_order, mode.stream_kinds], [false, false, [], nil, []])
check("and a skill of the other side reaches the troop alone", backline.troop_targets(item.new(true, false), others.first(2)), others.first(2))

# In a battle with the Backline, the other side's characters past its Frontline wait in reserve.
backline.begin(others)
check("the other side's characters past its Frontline wait in reserve", [backline.on?, backline.reserve, backline.own_reserve.map(&:id)], [true, [others[2]], [3, 4]])
check("a skill that reaches the Backline reaches the other side's too", backline.troop_targets(item.new(true, false), $game_troop.members), others)
check("a skill for the Backline alone reaches only it", backline.troop_targets(item.new(false, true), $game_troop.members), [others[2]])
check("any other skill reaches the troop alone", backline.troop_targets(item.new(false, false), $game_troop.members), others.first(2))

# The player's own swap.
own.each(&:make_actions)
check("before a swap everyone commands", [own.map(&:inputable?), mode.own_order], [[true] * 4, [1, 2]])
$swap = [1, 2]
$scene.bench_member_ok
own.each(&:make_actions)
check("the character swapped in gives no commands that round", [own[2].inputable?, own[2].actions, own[0].inputable?, own[0].actions], [false, [], true, [:attack]])
check("the commands carry the new Frontline", mode.own_order, [1, 3])
$scene.bench_member_ok
own.each(&:make_actions)
check("swapped back in the same round, the character commands again", [own[1].inputable?, own[1].actions], [true, [:attack]])
$scene.bench_member_ok
mode.share_order
check("the host tells the guest its Frontline before the turn's events", $posted, [[:flush], [backline::FRONT_MESSAGE, Marshal.dump([[1, 3]])]])
$posted.clear
$game_troop.turn_count = 1
own.each(&:make_actions)
check("in the next round the character commands", [own[2].inputable?, own[2].actions], [true, [:attack]])
mode.share_order
check("a Frontline that did not change is not told again", $posted, [])

# The other side's swap.
others[1].make_actions
others[2].make_actions
mode.take_order(nil, [5, 7])
check("the other side's Frontline is put in the troop and drawn anew", [$game_troop.members.map(&:id), $stood, $scene.instance_variable_get(:@spriteset).drawn, backline.reserve], [[5, 7], [5, 7], 1, [others[1]]])
check("the character swapped in loses the actions it had left", [others[2].actions, others[0].actions], [[], []])
others[2].make_actions
mode.share_order
check("and the commands a guest sent for it", others[2].actions, [])
mode.take(backline::FRONT_MESSAGE, $scene, Marshal.dump([[6, 7]]))
check("a guest takes the host's Frontline from the stream", $game_troop.members.map(&:id), [6, 7])
[[5, 5], [5, 9], [5], "x", nil].each { |front| mode.take_order(nil, front) }
check("a Frontline that does not fit the team is left out", $game_troop.members.map(&:id), [6, 7])
check("the stream carries the Frontline's message", mode.stream_kinds, [backline::FRONT_MESSAGE])

# The stream names the characters outside both Frontlines.
check("the host names its own Backline and the other side's", [mode.reserve_ref(own[1]), mode.reserve_ref(others[0]), mode.reserve_ref(own[0])], ["b2", "r5", nil])
check("the guest finds the host's as the other side's, and its own", [mode.reserve("b5"), mode.reserve("r2"), mode.reserve("a0"), mode.reserve("b99")], [others[0], own[1], nil, nil])
check("both are listed for the names and values", [mode.own_reserve.map(&:id), mode.other_reserve.map(&:id)], [[2, 4], [5]])

backline.finish
check("after the battle nothing is swapped in or kept in reserve", [backline.on?, backline.swapped_in?(own[2]), backline.reserve, mode.own_order, mode.reserve("b5")], [false, false, [], nil, nil])
check("nothing failed", $log.grep(/FAILED|failed/).size, 0)
