#----------------------------------------------------------------
#  coop_squad_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-13: Checked a Raid World's squad rules, their changes and Luka leaving the team
#                            - Checked that Luka is never swapped to the front and Give Up waits for him to lead
#      Paulinchen  2026-10-12: Stood in for the settings' group of the Mod Config
#      Paulinchen  2026-10-11: Stood in for the shared style's bad color
#      Paulinchen  2026-10-10: Checked that a hidden squad member never brings in the cut fourth
#                            - Checked that a Raid World offers the teleport to the story when known
#      Paulinchen  2026-10-08: Checked a Raid World's squads, team of four and own battles
#                            - Checked a Raid World's duels and that fitting a team moves Luka in
#                            - Checked a story's temporary party and hidden squad members in battle
#                            - Stood in for the game's party list and its standby
#      Paulinchen  2026-10-07: Gave the world stand-in who
#                            - Checked only that no line of the log tells a failure
#      Paulinchen  2026-10-06: Stood in for wheel_choice instead of wheel_slot
#      Paulinchen  2026-10-04: Followed the scripts to their new names, without mp_
#      Paulinchen  2026-10-03: Added a stand-in for the action wheel's registries
#                            - Gave the world stand-in tell, notice and the own id and seat
#                            - Admitted the party's members, as its leader does
#      Paulinchen  2026-10-02: Dropped the checks of squad, which the places already cover
#      Paulinchen  2026-10-01: Created
#
#----------------------------------------------------------------

# Covers a party's squads, coop_squad.rbx with coop.rbx: the Frontline and Backline shares, the
# followers and the leader's choice of them, the formation screens' cut, the cap of four players,
# and a Raid World's squads, team and battles of the player's own by its squad rules, and Luka in it.

require_relative "support"

# Stands in for the game's colors.
class Color
  attr_reader :red, :green, :blue, :alpha
  def initialize(red = 0, green = 0, blue = 0, alpha = 255); @red, @green, @blue, @alpha = red, green, blue, alpha; end
  def to_a; [@red.round, @green.round, @blue.round]; end
end
# A rectangle as the game's Rect holds it.
Rect = Struct.new(:x, :y, :width, :height)
# A picture of 2 by 2 pixels, enough to see each pixel turned grey.
class Bitmap
  attr_reader :pixels
  def initialize(*); @pixels = {}; end
  def blt(_x, _y, source, _rect, _opacity = 255); @pixels = source.pixels.dup; end
  def get_pixel(x, y); @pixels[[x, y]] || Color.new(0, 0, 0, 0); end
  def set_pixel(x, y, color); @pixels[[x, y]] = color; end
  def disposed?; false; end
end
# Stands in for the game's picture cache: a red face, a blue system picture.
module Cache
  def self.face(name); Bitmap.new.tap { |b| b.set_pixel(0, 0, Color.new(255, 0, 0)) }; end
  def self.system(name); Bitmap.new.tap { |b| b.set_pixel(0, 0, Color.new(0, 0, 255)) }; end
end
# Stands in for the game's scene manager.
module SceneManager; def self.run; end; end
# Stands in for the game's constants.
module NWConst
  # Stands in for the Mod Config's entries, holding only the Return row.
  module Config
    MOD_CONTENTS = [{ :key => :return }]
    DATA = {}
    DATA_TEXT = {}
    DEFAULT = {}
  end
end
# The game's system, holding the Mod Config's settings.
System = Struct.new(:conf)
$game_system = System.new({})
# Stands in for the game's actors, which do not exist while hidden; Luka has id 1.
class Game_Actor
  attr_reader :id
  def initialize(id); @id = id; end
  attr_writer :hidden
  def exist?; !@hidden; end
  def face_name; "Face#{@id}"; end
  def face_index; 0; end
  def name; "Actor#{@id}"; end
  def luca?; @id == 1; end
end
# The game's party: its team, which every change cuts down to party_member_max, and every companion
# the player has, those not in the team waiting on standby.
class Game_Party
  attr_accessor :all_members, :party_member_max, :in_battle, :temp
  def members; @all_members; end
  def actors; @all_members.map(&:id); end
  def included; @included ||= actors; end
  def standby; included - actors; end
  def add_stand_actor(id); included << id unless included.include?(id); end
  def move_stand_actor(id); @all_members = @all_members.reject { |actor| actor.id == id }; cut; end
  def add_actor(id); add_stand_actor(id); @all_members += [$game_actors[id]]; cut; end
  def cut; @all_members = @all_members.first(party_member_max); end
  def stand_actors; standby; end
  def move_actor(id); @all_members += [$game_actors[id]] if standby.include?(id); cut; end
  def swap_order(first, second); @all_members[first], @all_members[second] = @all_members[second], @all_members[first]; end
  def temp_actors_use?; @temp; end
  def max_battle_members; 4; end
  def battle_members; @all_members.select(&:exist?)[0, max_battle_members]; end
  def bench_members; @all_members.select(&:exist?)[max_battle_members..-1] || []; end
  def item_target_members(item); item.include_bench? ? @all_members : battle_members; end
end
# A skill or item, which reaches the Backline too or not.
Usable = Struct.new(:include_bench?)
# Stands in for the game's followers.
class Game_Follower
  attr_reader :character_name, :character_index
  def initialize(member_index, name); @member_index = member_index; @character_name = name; @character_index = member_index; end
  def visible?; true; end
end
# Stands in for the game's player, counting refreshes.
class Game_Player
  attr_accessor :followers, :refreshed
  def refresh; @refreshed = (@refreshed || 0) + 1; end
end
# What a window drew: the lines over its rows, and the pictures put on it.
class Contents
  attr_reader :fills, :pictures
  def initialize; @fills = []; @pictures = []; end
  def fill_rect(*args); @fills << args; end
  def blt(_x, _y, bitmap, *_rest); @pictures << bitmap.get_pixel(0, 0).to_a; end
end
# Draws a row as the game's Window_MenuStatus does: the face, opaque on the Frontline, then the
# status in the skin's colors, with a state's icon.
class Window_MenuStatus
  attr_reader :contents, :faces, :texts
  def initialize; @contents = Contents.new; @faces = []; @texts = []; end
  def draw_item(index)
    actor = $game_party.members[index]
    draw_actor_face(actor, 0, index * 10, index < 4)
    @texts << text_color(0).to_a
    draw_icon(1, 0, index * 10)
  end
  def draw_actor_face(actor, _x, _y, enabled = true); @faces << [actor.id, enabled ? :opaque : :translucent]; end
  def text_color(_n); Color.new(255, 128, 0); end
  def draw_icon(_icon, _x, _y, _enabled = true); @contents.pictures << :colored_icon; end
  def item_rect(index); Rect.new(0, index * 10, 100, 10); end
end
# Stands in for the namespace of the game's party edit script.
module Foo
  # Stands in for the game's party edit script.
  module PTEdit
    # Draws a row as the game's party edit screen does: the first four in the normal color, the
    # rest in the system color.
    class Window_PartyMember
      attr_reader :contents, :rows
      def initialize(actors); @actors = actors; @contents = Contents.new; @rows = []; end
      def draw_item(index)
        change_color(index < 4 ? normal_color : system_color, command_enabled?(index))
        draw_text(item_rect_for_text(index), command_name(index), alignment)
      end
      def normal_color; Color.new(255, 255, 255); end
      def system_color; Color.new(132, 170, 255); end
      def change_color(color, enabled = true); @color = [color.to_a, enabled]; end
      def command_enabled?(index); true; end
      def item_rect(index); Rect.new(0, index * 10, 100, 10); end
      def item_rect_for_text(index); item_rect(index); end
      def command_name(index); "row #{index}"; end
      def alignment; 0; end
      def draw_text(*); @rows << @color; end
      # Lists the team as the game does, Luka's row disabled.
      def make_command_list; @list = @actors.map { |id| { :enabled => !$game_actors[id].luca? } }; end
      # Sends the character picked to standby as the game does, never Luka.
      def process_move_member; $moved = select_actor.luca? ? :buzzer : select_actor.id; end
      attr_reader :actors
      attr_accessor :index
      def select_actor; $game_actors[@actors[@index]]; end
      def cursor_movable?; true; end
      def call_handler(name); $moved = [name, select_actor.id]; end
      def select(index); @index = index; end
    end
  end
end
# Stands in for the game's buttons, the A button pressed.
module Input; def self.trigger?(button); button == :A; end; def self.update; end; end
# Stands in for the game's sounds, keeping the last one in $sound.
module Sound; def self.play_equip; $sound = :equip; end; def self.play_buzzer; $sound = :buzzer; end; end
# Stands in for the game's interpreter, whose command of followers swaps Luka to the front as the
# game's own does when the followers go.
class Game_Interpreter
  def command_216
    luka = $game_party.all_members.index { |actor| actor.luca? } || 0
    $game_party.swap_order(0, luka)
  end
end
# Stands in for the game's battle manager, which offers Give Up while $give_up holds.
module BattleManager; def self.can_giveup?; $give_up; end; end
# Stands in for the raid bosses, troop 900 being one.
module MGQ_MpRaidBosses; def self.boss?(troop_id); troop_id == 900; end; end
# Stands in for the game's troop, fighting $troop.
class Game_Troop; def initialize; @troop_id = 1; end; attr_writer :troop_id; end
$game_troop = Game_Troop.new

$log = []
# Stands in for the mod's base script.
module MGQ_Multiplayer
  # Stands in for the mod's log, recording each line in $log.
  module Log; def self.write(m); $log << m; end; end
  # Stands in for the DLL's link, giving the own player's id.
  module Link; def self.player_id; "me-id-000"; end; end
  # Stands in for Discord, never there.
  module Discord; def self.available?; false; end; end
end
# Stands in for the overworld sync, keeping the ticks and state fields the scripts register; a
# world is open while $open.
module MGQ_MpOverworldSync
  @fields = []
  @ticks = []
  SQUAD_FIELD = "squad_value"
  def self.in_world?; $open; end
  # Keeps each route's block by its field.
  def self.route(field, &block); (@routes ||= {})[field] = block; end
  def self.routes; @routes; end
  def self.on_tick(&block); @ticks << block; end
  def self.state_fields(&block); @fields << block; end
  def self.on_observe(*); end
  def self.on_leave(*); end
  def self.label_line(*); end
  # Merges the fields every registered block tells.
  def self.fields; @fields.map(&:call).inject({}) { |all, f| all.merge(f) }; end
  # Runs every registered tick.
  def self.tick(in_world); @ticks.each { |t| t.call(in_world) }; end
  def self.notice(text); Status.notice(text); end
  def self.who(peer); peer == :me ? "the player" : "#{peer && peer.state['name']}"; end
  # Stands in for the other players seen, kept in @all.
  module Peers
    # Another player as the overworld sync keeps them.
    Peer = Struct.new(:seat, :state, :ghost, :member)
    @all = []
    def self.all; @all; end
  end
  # Stands in for the own player's id and name.
  module Me; def self.identity; ["me-id-000", "Me"]; end; def self.id; identity[0]; end; end
  # Stands in for the status line, keeping the last notice in $notice.
  module Status; def self.notice(text); $notice = text; end; end
end

# Stands in for the action wheel's registries.
module MGQ_MpActions
  # A choice of the action wheel.
  Option = Struct.new(:text, :run, :refusal, :icon, :leaves)
  LINE_COLOR = :line
  def self.offer(*); end
  def self.wheel_choice(*); end
  def self.own_doing_from; end
end
# Stands in for the shared style, with its bad color.
module MGQ_MpUi; module Style; BAD = Color.new(255, 96, 96); end; end
# The first words of the mod's settings in the Mod Config, as ui.rbx names them.
module MGQ_MpUi; OPTION_PREFIX = "[MGQ Online Settings] " unless const_defined?(:OPTION_PREFIX); end
load_script "coop"
load_script "coop_scope"
load_script "coop_squad"
SceneManager.run

party = MGQ_MpCoop::Party
squad = MGQ_MpCoopSquad
$open = true
actors = (1..10).map { |id| Game_Actor.new(id) }
$game_actors = Hash[actors.map { |a| [a.id, a] }]
$game_party = Game_Party.new
$game_party.all_members = actors.first(8)
$game_party.party_member_max = 8
$game_player = Game_Player.new
$game_player.followers = [1, 2, 3].map { |index| Game_Follower.new(index, "Follower#{index}") }

# Shares.
check("two players split the Frontline and the Backline evenly", [squad.share(0, 2, 8), squad.share(1, 2, 8)], [[2, 2], [2, 2]])
check("of three the leader has the place left over", (0..2).map { |at| squad.share(at, 3, 8) }, [[2, 2], [1, 1], [1, 1]])
check("four players bring one and one each", (0..3).map { |at| squad.share(at, 4, 8) }, [[1, 1]] * 4)
check("a larger party gives more of the Backline, the first ones first", (0..2).map { |at| squad.share(at, 3, 14) }, [[2, 4], [1, 3], [1, 3]])
check("alone, the whole team", squad.share(0, 1, 10), [4, 6])
check("the leader first, then by id", squad.ranked([["b", false], ["c", true], ["a", false]]), %w[c a b])

# Outside a party nothing is cut.
check("outside a party no share", squad.own_share, nil)
check("every follower shows", $game_player.followers.map { |f| f.visible? }, [true, true, true])
check("nobody is cut", squad.place_of(actors[7]), nil)
check("no trail is told", squad.state_fields["trail"], "")

# A party of two, the player leading.
party.invite
friend = MGQ_MpOverworldSync::Peers::Peer.new(2, { "id" => "friend-id", "name" => "Friend", "party" => party.id }, nil, true)
MGQ_MpOverworldSync::Peers.all << friend
party.admitted << "friend-id"
check("two players: two in front and two behind", squad.own_share, [2, 2])
check("places in the squad", actors.first(6).map { |a| squad.place_of(a) }, [:front, :front, :bench, :bench, :cut, :cut])
$game_player.refreshed = 0
MGQ_MpOverworldSync.tick(true)
MGQ_MpOverworldSync.tick(true)
check("followers are shown anew once the share changed", $game_player.refreshed, 1)
check("only the share of the Frontline follows, as the frame's tick took it", $game_player.followers.map { |f| f.visible? }, [true, false, false])
check("the trail tells the followers shown", squad.state_fields, { "follow" => 0, "trail" => "Follower1*1" })

# The leader's choice of followers.
check("the option is in the Mod Config, and the leader may choose", NWConst::Config::MOD_CONTENTS.find { |e| e[:key] == squad::FOLLOWERS }[:enable].call, true)
$game_system.conf[squad::FOLLOWERS] = squad::LEADERS_ONLY
MGQ_MpOverworldSync.tick(true)
check("leaders only hides every follower", $game_player.followers.map { |f| f.visible? }, [false, false, false])
check("and is told", squad.state_fields, { "follow" => 1, "trail" => "" })
$game_system.conf[squad::FOLLOWERS] = squad::ACTIVE_FRONTLINE

# The player joins the friend's party instead: the friend leads.
friend.state["party"] = "friend-p"
friend.state["invite"] = "1"
party.join(friend)
friend.state["follow"] = "1"
check("a member takes the leader's choice", squad.mode, squad::LEADERS_ONLY)
check("and tells it on", squad.state_fields["follow"], 1)
check("a member may not choose", NWConst::Config::MOD_CONTENTS.find { |e| e[:key] == squad::FOLLOWERS }[:enable].call, false)
friend.state["follow"] = "0"
other = MGQ_MpOverworldSync::Peers::Peer.new(3, { "id" => "a-other", "name" => "Other", "party" => "friend-p" }, nil, true)
MGQ_MpOverworldSync::Peers.all << other
party.admitted << "a-other"
check("of three, a member who does not lead has one and one", squad.own_share, [1, 1])
MGQ_MpOverworldSync.tick(true)
check("and so walks alone", $game_player.followers.map { |f| f.visible? }, [false, false, false])
check("places of a member of three", actors.first(3).map { |a| squad.place_of(a) }, [:front, :bench, :cut])
check("Discord hears of the party's size", MGQ_MpCoop.status_fields, { "mp_party" => "friend-p", "mp_party_size" => 3, "mp_party_max" => 4 })

# The formation screens.
menu = Window_MenuStatus.new
(0...4).each { |row| menu.draw_item(row) }
check("the menu draws the squad's Frontline opaque and its Backline translucent, as the game draws the Backline", menu.faces, [[1, :opaque], [2, :translucent]])
check("and the rest monochrome: faces, texts and icons", [menu.contents.pictures, menu.texts],
      [[:colored_icon, :colored_icon, [76, 76, 76], [29, 29, 29], [76, 76, 76], [29, 29, 29]], [[255, 128, 0], [255, 128, 0], [151, 151, 151], [151, 151, 151]]])
check("under a line above the first one only", menu.contents.fills.map { |f| f[1] }, [20])
check("past a row, the colors are the game's again", menu.text_color(0).to_a, [255, 128, 0])
edit = Foo::PTEdit::Window_PartyMember.new(actors.first(3).map(&:id))
(0...4).each { |row| edit.draw_item(row) }
check("the party edit screen colors by the squad: Frontline, Backline, then grey", edit.rows,
      [[[255, 255, 255], true], [[132, 170, 255], true], [[168, 168, 168], true], [[168, 168, 168], true]])
check("with a line above the first cut row only", edit.contents.fills.map { |f| f[1] }, [20])

# Big parties.
check("three players are no full party", party.full?, false)
fourth = MGQ_MpOverworldSync::Peers::Peer.new(4, { "id" => "z-fourth", "name" => "Fourth", "party" => "friend-p" }, nil, true)
MGQ_MpOverworldSync::Peers.all << fourth
party.admitted << "z-fourth"
check("four are", party.full?, true)
check("so is another party of four seen from outside", party.full?("friend-p"), true)

# Leaving the world forgets the cut.
$open = false
check("outside a world nothing is cut", [squad.own_share, squad.place_of(actors[7])], [nil, nil])
check("nor told to Discord", MGQ_MpCoop.status_fields, {})

# A Raid World: one on the Frontline and two on the Backline for everyone, a team of four.

# Stands in for the world, a Raid World while one is open and $raid holds, with the squad rules
# $squad names, the defaults while it names none.
module MGQ_MpWorld
  def self.raid?; $open && $raid; end
  def self.squad; raid? ? $squad || MGQ_MpCoopSquad::DEFAULT_RULES : nil; end
  def self.squad_of(text)
    luka, formation, front, raid_front = text.to_s.split(" ").map(&:to_i)
    raid_front ? { :luka => luka == 1, :formation => formation, :front => front, :raid_front => raid_front } : nil
  end
  def self.take_squad(rules); raid? ? ($squad = rules) && true : false; end
  def self.squad_summary(rules); "Formation #{rules[:formation]}, Frontline #{rules[:front]} | #{rules[:raid_front]}"; end
end
$raid = true
$open = true
$game_party.all_members = actors.first(7)
check("the cap waits until the team is fitted, so the game cuts nobody", $game_party.party_member_max, 8)
MGQ_MpOverworldSync.tick(true)
check("the companions past the fourth wait on standby", [$game_party.actors, $game_party.standby], [[1, 2, 3, 4], [5, 6, 7]])
check("then the team holds four", $game_party.party_member_max, 4)
$game_party.party_member_max = 10
check("which items raising the party size do not change", $game_party.party_member_max, 4)
$game_party.add_actor(8)
check("a companion joining the full team waits on standby", [$game_party.actors, $game_party.standby], [[1, 2, 3, 4], [5, 6, 7, 8]])
$game_party.temp = true
check("a story's temporary party keeps the game's size", $game_party.party_member_max, 10)
MGQ_MpOverworldSync.tick(true)
$game_party.add_actor(9)
$game_party.temp = false
check("and so does the team until it is fitted again", $game_party.party_member_max, 10)
MGQ_MpOverworldSync.tick(true)
check("which sends a companion who joined meanwhile to standby", [$game_party.actors, $game_party.standby, $game_party.party_member_max], [[1, 2, 3, 4], [5, 6, 7, 8, 9], 4])
check("Luka stays in the team wherever he stands", squad.past_cap([2, 3, 4, 5, 1, 6], 4), [5, 6])
check("unless he may leave it", squad.past_cap([2, 3, 4, 5, 1, 6], 4, false), [1, 6])
check("every player has one and two, in a party of four too", [MGQ_MpCoop.in_party?, squad.own_share], [true, [1, 2]])
check("the fourth place is cut", actors.first(4).map { |a| squad.place_of(a) }, [:front, :bench, :bench, :cut])
check("nobody follows", $game_player.followers.map { |f| f.visible? }, [false, false, false])
check("and no trail is told", squad.state_fields["trail"], "")
menu = Window_MenuStatus.new
(0...4).each { |row| menu.draw_item(row) }
check("the menu draws the Frontline opaque, the Backline translucent", menu.faces, [[1, :opaque], [2, :translucent], [3, :translucent]])
check("and the red line after the third place", menu.contents.fills.map { |f| f[1] }, [30])
edit = Foo::PTEdit::Window_PartyMember.new(actors.first(4).map(&:id))
(0...4).each { |row| edit.draw_item(row) }
check("so does the party edit screen", [edit.rows.map { |color, _| color }, edit.contents.fills.map { |f| f[1] }],
      [[[255, 255, 255], [132, 170, 255], [132, 170, 255], [168, 168, 168]], [30]])
party.leave
check("outside a party the same", [MGQ_MpCoop.in_party?, squad.own_share, squad.place_of(actors[3])], [false, [1, 2], :cut])
check("and a battle of two players brings one and two each, as alone", [squad.battle_share(0, 2, 8), squad.battle_share(1, 2, 8), squad.share(0, 2, 8)], [[1, 2], [1, 2], [2, 2]])

$game_party.in_battle = true
check("a battle of the player's own fights with the squad", [$game_party.max_battle_members, $game_party.battle_members.map(&:id), $game_party.bench_members.map(&:id)], [1, [1], [2, 3]])
check("the fourth out of the skills that reach the Backline too", [$game_party.item_target_members(Usable.new(true)).map(&:id), $game_party.item_target_members(Usable.new(false)).map(&:id)], [[1, 2, 3], [1]])
$game_actors[1].hidden = true
check("a hidden Frontline character never lets the fourth in", [$game_party.battle_members.map(&:id), $game_party.bench_members.map(&:id), $game_party.item_target_members(Usable.new(true)).map(&:id)], [[2], [3], [2, 3]])
$game_actors[2].hidden = true
check("nor does a hidden Backline character", [$game_party.battle_members.map(&:id), $game_party.bench_members.map(&:id)], [[3], []])
$game_actors[1].hidden = $game_actors[2].hidden = false
# Stands in for the battle sync, a team duel while $team_duel holds.
module MGQ_MpBattlesSync; def self.team?; $team_duel; end; end
check("a duel fights with the squad too", [$game_party.max_battle_members, $game_party.bench_members.map(&:id)], [1, [2, 3]])
$team_duel = true
check("a team duel brings its own party", $game_party.max_battle_members, 4)
$team_duel = false
check("a duel takes the squad, or its Frontline alone without the Backline", [squad.raid_team.map(&:id), squad.raid_team(false).map(&:id), squad.pvp_front], [[1, 2, 3], [1], 1])
$game_actors[2].hidden = true
check("a hidden squad member never brings the cut fourth into a duel or a co-op battle",
      [squad.raid_team.map(&:id), squad.own_order.map(&:id), squad.place_of(actors[3])], [[1, 3], [1, 3], :cut])
$game_actors[2].hidden = false

# The teleport to the story on demand, which coop.rbx offers on the player's own row in a Raid World.

# Stands in for the gathering, the story's endpoint from $story_end and a join kept in $joined_story.
module MGQ_MpCoopGather; def self.story_endpoint; $story_end; end; def self.join_story; $joined_story = true; end; end
story = lambda { MGQ_MpCoop::Offers.own_options.find { |option| option.text == "Teleport to the story" } }
$story_end = nil
check("a Raid World offers the teleport to the story, closed while nobody told it", [story.call.run, story.call.refusal], [nil, "Nobody has told the story yet."])
$story_end = [9, 1, 1, 2]
story.call.run.call
check("and open whenever its endpoint is known", $joined_story, true)
loaded = Game_Party.new
loaded.all_members = actors.first(6)
loaded.party_member_max = 8
loaded.in_battle = true
$game_party = loaded
MGQ_MpOverworldSync.tick(true)
check("a save's team waits for the battle's end to be fitted", [loaded.actors.size, loaded.party_member_max], [6, 8])
loaded.in_battle = false
loaded.temp = true
MGQ_MpOverworldSync.tick(true)
check("and for a story's temporary party to end", loaded.actors.size, 6)
loaded.temp = false
MGQ_MpOverworldSync.tick(true)
check("then it is fitted as well", [loaded.actors, loaded.standby, loaded.party_member_max], [[1, 2, 3, 4], [5, 6], 4])
check("outside a battle the game's Frontline stays", [loaded.max_battle_members, loaded.bench_members], [4, []])
luka_last = Game_Party.new
luka_last.all_members = [2, 3, 4, 5, 6, 1].map { |id| $game_actors[id] }
luka_last.party_member_max = 8
$game_party = luka_last
MGQ_MpOverworldSync.tick(true)
check("Luka standing past the fourth moves into the squad's last place", [luka_last.actors, luka_last.standby, squad.place_of(actors[0])], [[2, 3, 1, 4], [5, 6], :bench])
$game_party = loaded
MGQ_MpOverworldSync.tick(true)

# A Raid World's squad rules: the team's size, the Frontline in regular fights and in raids, and
# whether Luka may leave the team.
check("layouts: the cut place only while one is left, none with the game's own size",
      [squad.layout(1, 4, false), squad.layout(3, 4, false), squad.layout(4, 4, false), squad.layout(2, 6, false), squad.layout(1, 9, true), squad.layout(4, 9, true)],
      [[1, 2], [3, 0], [4, 0], [2, 3], [1, 8], [4, 5]])
whole = Game_Party.new
whole.all_members = actors.first(10)
whole.party_member_max = 10
$game_party = whole
squad.pushed({ "squad_value" => "0 6 2 1" })
check("a squad rules push not from the relay is ignored", MGQ_MpWorld.squad, squad::DEFAULT_RULES)
MGQ_MpOverworldSync.routes["squad_value"].call(nil, { "squad_value" => "0 6 2 1", :relay => true })
check("the relay's push takes the rules and tells the player", [MGQ_MpWorld.squad, $notice],
      [{ :luka => false, :formation => 6, :front => 2, :raid_front => 1 }, "The world's team rules changed: Formation 6, Frontline 2 | 1."])
MGQ_MpOverworldSync.tick(true)
check("a team of six: two in front, three behind, one cut", [whole.actors, whole.party_member_max, squad.own_share, actors.first(6).map { |a| squad.place_of(a) }],
      [[1, 2, 3, 4, 5, 6], 6, [2, 3], [:front, :front, :bench, :bench, :bench, :cut]])
whole.in_battle = true
check("a regular fight of the player's own takes two in front and three behind", [whole.max_battle_members, whole.battle_members.map(&:id), whole.bench_members.map(&:id)], [2, [1, 2], [3, 4, 5]])
$game_troop.troop_id = 900
check("a raid takes the raid's Frontline, the rest of the squad behind", [whole.max_battle_members, whole.battle_members.map(&:id), whole.bench_members.map(&:id)], [1, [1], [2, 3, 4, 5]])
check("a co-op raid gives each player one in front however many play", (0..2).map { |at| squad.battle_share(at, 3, 6) }, [[1, 4], [1, 4], [1, 4]])
$game_troop.troop_id = 1
check("a co-op battle gives the first players two in front while the four places last", (0..2).map { |at| squad.battle_share(at, 3, 6) }, [[2, 3], [1, 4], [1, 4]])
check("and with four players everyone one, the rest behind", (0..3).map { |at| squad.battle_share(at, 4, 6) }, [[1, 4]] * 4)
check("a co-op battle's build holds the larger squad of both fights", squad.largest_squad(6), 5)
whole.in_battle = false
$squad = { :luka => false, :formation => 4, :front => 4, :raid_front => 4 }
MGQ_MpOverworldSync.tick(true)
check("a Frontline as large as the team leaves no cut place", [whole.actors, squad.own_share, actors.first(4).map { |a| squad.place_of(a) }],
      [[1, 2, 3, 4], [4, 0], [:front, :front, :front, :front]])
$squad = { :luka => false, :formation => squad::ORIGINAL, :front => 1, :raid_front => 1 }
MGQ_MpOverworldSync.tick(true)
whole.party_member_max = 9
check("the original size keeps the game's party size and cuts nobody", [whole.party_member_max, squad.own_share, squad.place_of(actors[3])], [9, [1, 8], :bench])

# Luka may leave the team.
$squad = { :luka => true, :formation => 4, :front => 1, :raid_front => 1 }
free = Game_Party.new
free.all_members = [2, 3, 4, 5, 6, 1].map { |id| $game_actors[id] }
free.party_member_max = 8
$game_party = free
MGQ_MpOverworldSync.tick(true)
check("fitting a team where Luka may leave keeps its first places and moves him to standby", [free.actors, free.standby], [[2, 3, 4, 5], [6, 1]])
edit = Foo::PTEdit::Window_PartyMember.new([1, 2, 3])
edit.make_command_list
check("the party edit screen lets Luka's row be picked", MGQ_MpGame.get(edit, :list).map { |row| row[:enabled] }, [true, true, true])
edit.index = 0
edit.process_move_member
check("and sends him to standby", [$moved, $sound], [[:move_member, 1], :equip])
edit.index = 1
edit.process_move_member
check("others as the game does", $moved, 2)
$squad = { :luka => false, :formation => 4, :front => 1, :raid_front => 1 }
MGQ_MpOverworldSync.tick(true)
check("once the rules keep him, Luka comes back into the squad", [free.actors, free.standby], [[2, 3, 1, 4], [5, 6]])
edit.make_command_list
check("and his row is the game's again", MGQ_MpGame.get(edit, :list).map { |row| row[:enabled] }, [false, true, true])
edit.index = 0
edit.process_move_member
check("so he stays in the team", $moved, :buzzer)

# The game never swaps Luka to the front in a Raid World.
Game_Interpreter.new.command_216
check("the command of followers leaves the order", free.actors, [2, 3, 1, 4])
$give_up = true
check("Give Up waits for Luka to lead", BattleManager.can_giveup?, false)
free.swap_order(0, 2)
check("and is the game's once he does", [free.actors, BattleManager.can_giveup?], [[1, 3, 2, 4], true])
free.swap_order(0, 2)
$squad = nil
$game_party = loaded
MGQ_MpOverworldSync.tick(true)

$open = false
MGQ_MpOverworldSync.tick(false)
check("leaving the world lifts the cap", [loaded.party_member_max, squad.own_share], [8, nil])
$open = true
$raid = false
check("a Classic world has no cap and no squad alone", [loaded.party_member_max, squad.own_share, squad.place_of(actors[3])], [8, nil, nil])
check("and its duels keep the game's Frontline", squad.pvp_front, 4)
loaded.in_battle = true
check("nor narrows its battles", [loaded.max_battle_members, loaded.battle_members.size], [4, 4])
loaded.in_battle = false
Game_Interpreter.new.command_216
check("and its command of followers swaps Luka to the front as the game does", loaded.actors.first, 1)
$game_party = Game_Party.new
$game_party.all_members = [2, 1].map { |id| $game_actors[id] }
$game_party.party_member_max = 8
Game_Interpreter.new.command_216
check("wherever he stood", $game_party.actors, [1, 2])
check("and Give Up is the game's", BattleManager.can_giveup?, true)
check("nothing failed", $log.grep(/fail/i), [])
