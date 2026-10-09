#----------------------------------------------------------------
#  coop_squad_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-08: Checked a Raid World's squads: one and two for every player, the team of four with the rest on standby, no followers, the line after the third place and the battles of the player's own
#                            - Checked that a Raid World's duels fight with the squad, team duels with their own party, and that fitting a team moves Luka into the squad
#                            - Checked that a story's temporary party keeps the game's size and that a hidden squad member never lets the fourth into a battle
#                            - Stood in for the game's party list, which every change cuts down to party_member_max, and its standby
#      Paulinchen  2026-10-07: Gave the world stand-in who, which the log names players with
#                            - Checked only that no line of the log tells a failure, since the party logs what it does
#      Paulinchen  2026-10-06: Stood in for wheel_choice instead of wheel_slot
#      Paulinchen  2026-10-04: Followed the scripts to their new names, without mp_
#      Paulinchen  2026-10-03: Added a stand-in for the action wheel's registries
#                            - Gave the world stand-in tell, notice and the own id and seat
#                            - Admitted the party's members, as its leader does
#      Paulinchen  2026-10-02: Dropped the checks of squad, which the places already cover
#      Paulinchen  2026-10-01: Created
#
#----------------------------------------------------------------

# Covers a party's squads, coop_squad.rbx with coop.rbx: the shares of the Frontline and the
# Backline, the leader's choice of followers, the followers shown, the formation screens' cut, the
# option in the Mod Config, the cap of four players, and a Raid World's squads, team of four and
# battles of the player's own.

require_relative "support"

# Stand-ins for the game.
class Color
  attr_reader :red, :green, :blue, :alpha
  def initialize(red = 0, green = 0, blue = 0, alpha = 255); @red, @green, @blue, @alpha = red, green, blue, alpha; end
  def to_a; [@red.round, @green.round, @blue.round]; end
end
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
module Cache
  def self.face(name); Bitmap.new.tap { |b| b.set_pixel(0, 0, Color.new(255, 0, 0)) }; end
  def self.system(name); Bitmap.new.tap { |b| b.set_pixel(0, 0, Color.new(0, 0, 255)) }; end
end
module SceneManager; def self.run; end; end
module NWConst
  module Config
    MOD_CONTENTS = [{ :key => :return }]
    DATA = {}
    DATA_TEXT = {}
    DEFAULT = {}
  end
end
System = Struct.new(:conf)
$game_system = System.new({})
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
  def swap_order(first, second); @all_members[first], @all_members[second] = @all_members[second], @all_members[first]; end
  def temp_actors_use?; @temp; end
  def max_battle_members; 4; end
  def battle_members; @all_members.select(&:exist?)[0, max_battle_members]; end
  def bench_members; @all_members.select(&:exist?)[max_battle_members..-1] || []; end
  def item_target_members(item); item.include_bench? ? @all_members : battle_members; end
end
# A skill or item, which reaches the Backline too or not.
Usable = Struct.new(:include_bench?)
class Game_Follower
  attr_reader :character_name, :character_index
  def initialize(member_index, name); @member_index = member_index; @character_name = name; @character_index = member_index; end
  def visible?; true; end
end
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
module Foo
  module PTEdit
    # Draws a row as the game's party edit screen does: the Frontline of single player in the
    # normal color, the rest in the system color.
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
    end
  end
end

$log = []
module MGQ_Multiplayer
  module Log; def self.write(m); $log << m; end; end
  module Link; def self.player_id; "me-id-000"; end; end
  module Discord; def self.available?; false; end; end
end
module MGQ_MpOverworldSync
  @fields = []
  @ticks = []
  def self.in_world?; $open; end
  def self.route(*); end
  def self.on_tick(&block); @ticks << block; end
  def self.state_fields(&block); @fields << block; end
  def self.on_observe(*); end
  def self.on_leave(*); end
  def self.label_line(*); end
  def self.fields; @fields.map(&:call).inject({}) { |all, f| all.merge(f) }; end
  def self.tick(in_world); @ticks.each { |t| t.call(in_world) }; end
  def self.notice(text); Status.notice(text); end
  def self.who(peer); peer == :me ? "the player" : "#{peer && peer.state['name']}"; end
  module Peers
    Peer = Struct.new(:seat, :state, :ghost, :member)
    @all = []
    def self.all; @all; end
  end
  module Me; def self.identity; ["me-id-000", "Me"]; end; def self.id; identity[0]; end; end
  module Status; def self.notice(text); $notice = text; end; end
end

module MGQ_MpActions
  Option = Struct.new(:text, :run, :refusal, :icon, :leaves)
  LINE_COLOR = :line
  def self.offer(*); end
  def self.wheel_choice(*); end
  def self.own_doing_from; end
end
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
module MGQ_MpWorld; def self.raid?; $open && $raid; end; end
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
check("Luka stays in the team wherever he stands", squad.past_cap([2, 3, 4, 5, 1, 6]), [5, 6])
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
module MGQ_MpBattlesSync; def self.team?; $team_duel; end; end
check("a duel fights with the squad too", [$game_party.max_battle_members, $game_party.bench_members.map(&:id)], [1, [2, 3]])
$team_duel = true
check("a team duel brings its own party", $game_party.max_battle_members, 4)
$team_duel = false
check("a duel takes the squad, or its Frontline alone without the Backline", [squad.raid_team.map(&:id), squad.raid_team(false).map(&:id), squad.pvp_front], [[1, 2, 3], [1], 1])
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

$open = false
MGQ_MpOverworldSync.tick(false)
check("leaving the world lifts the cap", [loaded.party_member_max, squad.own_share], [8, nil])
$open = true
$raid = false
check("a Classic world has no cap and no squad alone", [loaded.party_member_max, squad.own_share, squad.place_of(actors[3])], [8, nil, nil])
check("and its duels keep the game's Frontline", squad.pvp_front, 4)
loaded.in_battle = true
check("nor narrows its battles", [loaded.max_battle_members, loaded.battle_members.size], [4, 4])
check("nothing failed", $log.grep(/fail/i), [])
