#----------------------------------------------------------------
#  world_overview_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-11: Expected Part 2 to start with Bonnie and Ashel and end with Sonya Mazda, Sonya Mainyu and Sonya Chaos
#                            - Checked that a Raid World's box lists the party wherever its members are, with Frontline levels, and the others on the map below it, and stays with the party alone on the map
#                            - Checked the overview as a box the player moves and resizes: its default, a placement Player.ini keeps, its least size, the lines, the scroll, the menu and the clicks following it, the sprite placed, offered and drawn anew on a new size or preset, and a box at its least size still drawing every column, the title, the tabs and the whole hint on both pages
#                            - Expected the raid bosses' gauges in the edge and well colors, and the box, its tabs and its title in the preset's colors
#                            - Loaded ui_theme.rbx and ui_layout.rbx, which the overview draws and lies by
#                            - Checked the raid bosses grouped by the story's sections, only those the world's story reached or holding a pool, a fight's own pool in its section and an unknown one under Other
#                            - Left the map box's size hint out of the texts read, as the pings are
#                            - Read the small party box's left, which its motion places, instead of its x, and compared its green against the shared style's member color
#                            - Checked the World page: turning with the arrows and the tabs, a cancel held with a click on a tab, its rows in a Classic and a Raid World, the raid bosses from their pools, a share rounded, scrolling, the title with the type and difficulty, the hint, a boss's row and the Players tab's mark while a call waits
#                            - Checked the confirm box before leaving the party and removing a member, that the overview waits while it asks, and that yes leaves no party that dissolved under the box
#                            - Stood in for the open world, its difficulty, its story and the raid bosses' pools, and for pictures
#      Paulinchen  2026-10-10: Expected the teleport to the party's leader in a member's menu, in place of the line that they are in the party
#                            - Named the map box's players outside the party with placeholders
#                            - Named the party member in the checks with a placeholder
#      Paulinchen  2026-10-08: Checked the map box of a Raid World: its players and order, the Frontline level, its colors, its cap and its key
#                            - Expected the Frontline level of a Raid World from its one Frontline character, and of a share of two from the first two
#      Paulinchen  2026-10-07: Measured places with an object that measures texts, and checked the log of a name the game lacks
#                            - Expected no place on a map the game names nowhere, headed Unnamed place in the list
#      Paulinchen  2026-10-06: Checked that the emote wheel keeps the overview shut, and the menu of a player nothing is offered with
#                            - Read the open menu without the reader the overview dropped
#      Paulinchen  2026-10-04: Checked the party box's size key, its small rows and its setting
#                            - Followed the scripts to their new names, without mp_
#      Paulinchen  2026-10-03: Followed the choices to the scripts that offer them
#                            - Added a stand-in for duels without PvP battles
#                            - Named the member in the leader's invite, which admits them
#      Paulinchen  2026-10-02: Opened the overview with the key mp_keys.rbx binds instead of a stand-in for the PvP battle screen's
#      Paulinchen  2026-10-01: Created
#
#----------------------------------------------------------------

# Covers the World overview, world_overview.rbx: what the player tells the others (place,
# highest companion level, place in the story), the list by place, opening with F11 and the
# wheel, the arrows, the menu of a player, the mouse, the places the party box shortens, the
# map box that replaces the party box in a Raid World, the World page with the world's rows and
# its raid bosses, the box the player moves and resizes, and the confirm box before leaving the
# party or removing a member.

require_relative "world_support"

# Stand-ins for the mouse, the open world, its difficulty, its story as the relay told it, the
# raid bosses' pools, pictures and the game's data.
module MGQ_Multiplayer
  module Mouse
    def self.position; $mouse; end
    def self.clicked?; c = $click; $click = false; c; end
  end
end
World = Struct.new(:name, :seats)
$world = World.new("Test World", 8)
module MGQ_MpWorld
  DIFFICULTY_NAMES = ["VERY EASY", "EASY", "NORMAL", "HARD", "VERY HARD", "HELL", "PARADOX"]
  def self.world; $world; end
  def self.raid?; $raid; end
  def self.difficulty_name(value); value ? DIFFICULTY_NAMES[value + 2] : nil; end
end
module MGQ_MpWorldDifficulty; def self.value; $difficulty; end; end
module MGQ_MpWorldStory
  ROUTES = %w(ad mr chaos)
  ROUTE_VARIABLES = [1141, 1142, 1143]
  def self.world; $world_story; end
  def self.part_of(counters); counters["part"]; end
end
$pools = {}
module MGQ_MpRaidPool
  Pool = Struct.new(:left, :max, :defeated, :by, :at)
  def self.pools; $pools.dup; end
  def self.boss_key(key); key.sub(/#\d+\z/, ""); end
  def self.troop_of_key(key); key == "Sisel" ? 2016 : nil; end
  def self.left_now(pool, _now = Time.now); pool.defeated ? 0.0 : pool.left; end
end
load_script "battles_raid_bosses"
class Sprite
  attr_accessor :bitmap, :x, :y, :z, :ox, :oy, :opacity, :visible
  def dispose; @disposed = true; end
  def disposed?; @disposed ? true : false; end
end
# A picture that records what it draws, measuring each character at half the font's size.
class Bitmap
  Font = Struct.new(:size, :color, :bold, :outline, :out_color)
  attr_reader :width, :height, :font, :drawn
  def initialize(width, height); @width = width; @height = height; @font = Font.new(24, nil, false, false, nil); @drawn = []; end
  def rect; Rect.new(0, 0, @width, @height); end
  def text_size(text); Rect.new(0, 0, text.to_s.size * @font.size / 2, @font.size); end
  def draw_text(x, y, width, height, text, align = 0); @drawn << [:text, text, @font.color, x, width, align]; end
  def fill_rect(*args); @drawn << [:fill, args]; end
  def stretch_blt(*_); end
  def clear; @drawn.clear; end
  def dispose; @disposed = true; end
  def disposed?; @disposed ? true : false; end
  def texts; @drawn.select { |kind, _| kind == :text }.map { |_, text, _| text }; end
end
# A character, whose levels the game keeps as a Hash of base, class and race level.
Actor = Struct.new(:base_level, :luca) do
  def luca?; luca; end
  def level; { :base => base_level, :class => 1, :tribe => 1 }; end
end
MapInfo = Struct.new(:name)
$data_mapinfos = { 5 => MapInfo.new("Ilias Village (editor)") }

# Duels without PvP battles, which the overview greys out.
module MGQ_MpBattlesDuel
  def self.peer_option(_peer); MGQ_MpActions::Option.new("Duel", nil, "Duels need PvP battles, which are off or out of date."); end
  def self.own_options; []; end
  def self.call_of(_peer); nil; end
end
MGQ_MpActions.offer(MGQ_MpBattlesDuel)
load_script "ui_theme" unless defined?(MGQ_MpUi::Theme)
load_script "ui_layout" unless defined?(MGQ_MpUi::Layout)
load_script "world_overview"
module MGQ_MpEmotes; def self.open?; false; end; end
load_script "ui_party_box"

overview = MGQ_MpWorldOverview

# The place in the story.
$data_system.variables[1001] = "Overall Events Progress"
$data_system.switches[50] = "Alice Chosen"
$data_system.variables[1142] = "天界ルート進行度"
check("the wheel's middle is the overview's globe", [MGQ_MpActions.wheel_options[:CENTER].text, MGQ_MpActions.wheel_options[:CENTER].icon], ["World (F11)", 3988])
check("before the side is chosen: the part", [overview.story_code, overview.story_text(overview.story_code)], ["1", "Part 1"])
$game_switches[50] = true
$game_variables[1001] = 25
check("Part 2 with a side", [overview.story_code, overview.story_text(overview.story_code)], ["2:alice", "Part 2: Alice side"])
$game_variables[1001] = 45
check("Part 3 before a route: still the side", overview.story_text(overview.story_code), "Part 3: Alice side")
$game_variables[1142] = 3
check("Part 3 with a route", [overview.story_code, overview.story_text(overview.story_code)], ["3:destroyer", "Part 3: Destroyer route"])
$data_system.variables[1001] = "総合イベント進行度"
check("the untranslated game's names count too", overview.story_code, "3:destroyer")
check("an unknown place shows nothing", overview.story_text(""), "")
logged = []
write = MGQ_Multiplayer::Log.method(:write)
MGQ_Multiplayer::Log.define_singleton_method(:write) { |line| logged << line }
check("a name the game lacks reads 0 or off, logged once", [overview.variable(["No Such"]), overview.variable(["No Such"]), overview.switch?(["Nor This"]), logged],
      [0, 0, false, ["overview: no variable of the game is named No Such, reading 0", "overview: no switch of the game is named Nor This, reading off"]])
MGQ_Multiplayer::Log.define_singleton_method(:write, write)

# The highest companion level and the place.
$game_party.all_members = [Actor.new(99, true), Actor.new(40, false)]
$game_party.stand_members = [Actor.new(55, false)]
check("the highest companion, waiting ones too, Luka left out", overview.top_level, 55)
check("a map the game names nowhere has no place, never its untranslated name in the editor", overview.place, "")
check("which the list heads Unnamed place", overview.lines([overview.own_row("Me (you)")]).first, [:place, "Unnamed place"])
$game_map.display_name = "Ilias Village"
overview.tick(true)
check("the state tells place, level and story", MGQ_MpOverworldSync::Me.current.values_at("place", "lv", "progress"), ["Ilias Village", 55, "3:destroyer"])

# The list by place.
other = { "id" => "other", "name" => "member", "map" => 5, "x" => 30, "y" => 30, "d" => 2, "scene" => "menu", "place" => "Ilias Village", "lv" => 12, "progress" => "1", "ping" => 40 }
friend = { "id" => "friend", "name" => "Friend", "map" => 7, "x" => 1, "y" => 1, "d" => 2, "scene" => "battle", "place" => "Forest", "lv" => 30, "progress" => "2:ilias", "ping" => 250 }
$inbox << entry("seat", 0) << entry("in", 2) << entry("message", 2, told(friend)) << entry("in", 3) << entry("message", 3, told(other))
MGQ_MpOverworldSync.tick
lines = overview.lines(overview.rows)
check("places: the player's first, each with its players, the player first", lines.map { |kind, value| kind == :place ? value : value.name },
      ["Ilias Village", "Me (you)", "member", "Forest", "Friend"])
friend_row = lines[4][1]
check("a player's row", [friend_row.level, friend_row.story, friend_row.ping[0], friend_row.icon], ["Lv 30", "Part 2: Ilias side", "250 ms", 451])

# Opening and the arrows.
$pressed = 0x7A
overview.on_map
check("F11 opens it and holds the buttons", [overview.open?, MGQ_Multiplayer::Capture.on?], [true, true])
check("on the player's own row", overview.view[:selected], 1)
overview.on_map
$buttons << :DOWN
overview.on_map
check("the arrows pick the next player", overview.view[:selected], 2)
$buttons << :DOWN
overview.on_map
check("past the next place's heading", overview.view[:selected], 4)
$buttons << :C
overview.on_map
check("confirm opens the player's menu", overview.view[:menu].map(&:text), ["Invite to party", "Duel"])
check("duels are greyed without PvP battles", overview.view[:menu][1].run, nil)
$buttons << :C
overview.on_map
check("inviting names the player, wherever they are", [MGQ_MpCoop::Party.targets, overview.instance_variable_get(:@menu)], [["friend"], nil])
$buttons << :C
overview.on_map
check("the menu then says the invite stands", overview.view[:menu][0].text, "Invited to party")
$buttons << :B
overview.on_map
2.times { $buttons << :UP; overview.on_map }
$buttons << :C
overview.on_map
check("the player's own menu stops the invite", overview.view[:menu].map(&:text), ["Stop inviting"])
overview.instance_variable_set(:@menu, 2)
check("a choice past a menu that shrank moves onto its last choice", overview.view[:menu_index], 0)
reads = 0
rows = overview.method(:rows)
overview.define_singleton_method(:rows) { reads += 1; rows.call }
overview.on_map
overview.define_singleton_method(:rows, rows)
check("an update reads the players once, and keeps the view for the picture", [reads, overview.shown_view[:menu].size], [1, 1])
2.times { $buttons << :B; overview.on_map }
check("cancel closes the menu, then the overview", [overview.open?, MGQ_Multiplayer::Capture.on?], [false, false])

# The emote wheel and empty menus.
MGQ_MpEmotes.define_singleton_method(:open?) { true }
$pressed = 0x7A
overview.on_map
check("the overview stays shut while the emote wheel is open", overview.open?, false)
MGQ_MpEmotes.define_singleton_method(:open?) { false }
registered = MGQ_MpActions.offers.dup
MGQ_MpActions.offers.clear
check("a player nothing is offered with gets a menu that says so", overview.menu_options(friend_row).map { |option| [option.text, option.run] }, [["Nothing to do", nil]])
MGQ_MpActions.offers.concat(registered)

# An invite from afar.
$inbox << entry("message", 2, told(friend.merge("party" => "friend-p", "invite" => 1, "invite_to" => "me")))
MGQ_MpOverworldSync.tick
check("an invite naming the player is accepted from the overview", MGQ_MpCoop::Offers.peer_option(MGQ_MpOverworldSync::Peers.at(2)).text, "Accept party invite")
check("and shows on the inviter's row in place of the story", overview.row_of(MGQ_MpOverworldSync::Peers.at(2)).call[0], "Invites you to a party")
check("but not on another player's", overview.row_of(MGQ_MpOverworldSync::Peers.at(3)).call, nil)
check("outside a party the player's own row is white", [overview.rows.first.member, overview.party_rows], [false, []])

# The mouse.
$pressed = 0x7A
overview.on_map
overview.on_map
box = Sprite_MpWorldOverview.box
$mouse = [box.x + 100, box.y + Sprite_MpWorldOverview::LIST_TOP + Sprite_MpWorldOverview::ROW * 4 + 5]
overview.on_map
check("pointing picks a player", overview.view[:selected], 4)
$click = true
overview.on_map
check("a click opens their menu", overview.view[:menu].map(&:text), ["Accept party invite", "Duel"])
left, top = Sprite_MpWorldOverview.menu_origin(overview.view)
$mouse = [box.x + left + 10, box.y + top + 5]
$click = true
overview.on_map
check("a click on a choice takes it", MGQ_MpCoop::Party.id, "friend-p")
check("in a party the player's own row is green", overview.rows.first.member, true)
check("the party box lists the party, its leader first, with levels", overview.party_rows.map { |row| [row.name, row.level, row.badge[1]] },
      [["Friend", "Lv 30", true], ["Me", "Lv 55", false]])
check("and where each one is", overview.party_rows.map(&:place), overview.party_rows.map { |row| overview.rows.find { |r| r.name.start_with?(row.name) }.place })

# The party box's size.
overview.close
check("the party box starts full", MGQ_MpPartyBox.small?, false)
$pressed = MGQ_MpHotkeys.code(:party_box)
MGQ_MpPartyBox.on_map
check("Tab makes it small, which Player.ini keeps", [MGQ_MpPartyBox.small?, $player_ini["party_box_small"]], [true, "1"])
MGQ_MpPartyBox.instance_variable_set(:@small, nil)
check("so it is small again after a restart", MGQ_MpPartyBox.small?, true)
drawn = []
font = Struct.new(:color, :size, :outline, :bold, :out_color).new
canvas = Object.new
canvas.define_singleton_method(:font) { font }
canvas.define_singleton_method(:clear) {}
canvas.define_singleton_method(:fill_rect) { |*args| drawn << [:fill, args[2]] }
canvas.define_singleton_method(:text_size) { |text| Rect.new(0, 0, text.to_s.size * 8, 16) }
canvas.define_singleton_method(:stretch_blt) { |_dest, _set, rect, *_| drawn << (rect == MGQ_MpUi.icon_rect(MGQ_MpOverworld::CROWN_ICON) ? [:crown] : [:icon]) }
canvas.define_singleton_method(:draw_text) { |_x, _y, _w, _h, text, *_| drawn << [:text, text] }
module Cache; def self.system(_name); nil; end; end
module Graphics; def self.width; 640; end; end
box = Sprite_MpPartyBox.allocate
class << box; attr_accessor :x, :y; end
box.define_singleton_method(:bitmap) { canvas }
box.draw_small(overview.party_rows)
check("small, it lists only the crown, the names and the pings, in a narrower box at the top right",
      [box.instance_variable_get(:@left), drawn.first, drawn.select { |kind, _| kind == :crown }.size, drawn.select { |kind, _| kind == :text }.map(&:last).reject { |text| text.end_with?("ms") }],
      [640 - Sprite_MpPartyBox::SMALL_WIDTH - Sprite_MpPartyBox::MARGIN, [:fill, Sprite_MpPartyBox::SMALL_WIDTH], 1, ["Friend", "Me"]])
MGQ_MpChat.start_typing
$pressed = MGQ_MpHotkeys.code(:party_box)
MGQ_MpPartyBox.on_map
check("its key does nothing while the player types", MGQ_MpPartyBox.small?, true)
MGQ_MpChat.stop_typing
$pressed = MGQ_MpHotkeys.code(:party_box)
MGQ_MpPartyBox.on_map
check("then makes it full again", [MGQ_MpPartyBox.small?, $player_ini["party_box_small"]], [false, "0"])

# Places shortened to fit the party box, measured at 10 pixels a letter in 300 pixels.
ruler = Object.new
ruler.define_singleton_method(:text_size) { |text| Struct.new(:width).new(text.length * 10) }
fit = lambda { |place| overview.fit_place(place, 300, ruler) }
check("a short place stays", fit.call("Iliasville"), "Iliasville")
check("the Pocket Castle takes its short name", fit.call("Pocket Monster Lord's Castle Conference Room"), "Pocket Castle Conference Room")
check("then the part in brackets goes", fit.call("Tartarus (Western Hellgondo Continent)"), "Tartarus")
check("then the name is cut before its floor", fit.call("Alliance of Wisdom Laboratory B2F"), "Alliance of Wisdom Labo... B2F")
check("and a name without a floor is cut at its end", fit.call("A Very Long Place Name Without Any Floor"), "A Very Long Place Name With...")
$mouse = [5, 5]
$click = true
overview.on_map
check("a click outside the box closes it", overview.open?, false)

# Leaving the map or typing closes it.
$pressed = 0x7A
overview.on_map
$pressed = 0x54
map_frame
overview.on_map
check("the chat box closes it", [MGQ_MpChat.typing?, overview.open?], [true, false])

# Only the party's leader invites and removes.
friend_peer = MGQ_MpOverworldSync::Peers.at(2)
member_peer = MGQ_MpOverworldSync::Peers.at(3)
check("a member may teleport to their leader", MGQ_MpActions.peer_options(friend_peer).map(&:text), ["Teleport to Friend", "Duel"])
check("and may not invite", [MGQ_MpCoop::Offers.peer_option(member_peer).run, MGQ_MpCoop::Offers.peer_option(member_peer).refusal], [nil, "Only the party's leader invites."])
MGQ_MpCoop::Party.reset
MGQ_MpCoop::Party.invite("zz-member")
$inbox << entry("message", 3, told(other.merge("party" => MGQ_MpCoop::Party.id, "id" => "zz-member")))
MGQ_MpOverworldSync.tick
check("the leader may remove a member", MGQ_MpCoop::Offers.peer_option(member_peer).text, "Remove from party")

# The map box of a Raid World.
# A team within four, which coop_squad.rbx keeps as it is in a Raid World.
def $game_party.in_battle; false; end
def $game_party.temp_actors_use?; false; end
def $game_party.actors; []; end
own_order = MGQ_MpCoopSquad.method(:own_order)
MGQ_MpCoopSquad.define_singleton_method(:own_order) { $front }
$front = [Actor.new(40, true), Actor.new(70, false), Actor.new(90, false)]
overview.instance_variable_set(:@frames, 0)
overview.tick(true)
check("a Classic world tells no Frontline level", [MGQ_MpOverworldSync::Me.current.key?("flv"), MGQ_MpPartyBox.map_box?], [false, false])
$raid = true
check("in a Raid World the Frontline level is the one Frontline character's, Luka included", overview.front_level, 40)
own_share = MGQ_MpCoopSquad.method(:own_share)
MGQ_MpCoopSquad.define_singleton_method(:own_share) { [2, 2] }
check("a share of two reads the higher of the first two", overview.front_level, 70)
MGQ_MpCoopSquad.define_singleton_method(:own_share) { nil }
check("without a share it is the first character's", overview.front_level, 40)
MGQ_MpCoopSquad.define_singleton_method(:own_share, own_share)
overview.instance_variable_set(:@frames, 0)
overview.tick(true)
check("a Raid World tells it as flv beside lv", MGQ_MpOverworldSync::Me.current.values_at("lv", "flv"), [55, 40])
module MGQ_MpBattlesCoop; def self.active?; $coop_battle; end; end
$coop_battle = true
$front = [Actor.new(5, true)]
check("during a co-op battle it keeps the level read before", overview.front_level, 40)
$coop_battle = false
$front = [Actor.new(40, true), Actor.new(70, false), Actor.new(90, false)]

stranger = { "id" => "stranger", "name" => "Stranger", "map" => 5, "x" => 2, "y" => 2, "d" => 2, "scene" => "map", "place" => "Ilias Village", "lv" => 80, "flv" => 20, "progress" => "1", "ping" => 80 }
$inbox << entry("in", 4) << entry("message", 4, told(stranger)) << entry("in", 5) << entry("message", 5, told(stranger.merge("id" => "loner", "name" => "loner", "flv" => 0, "party" => "loner-p", "invite" => 0)))
$inbox << entry("message", 3, told(other.merge("party" => MGQ_MpCoop::Party.id, "id" => "zz-member", "flv" => 33)))
MGQ_MpOverworldSync.tick
map_rows = overview.map_rows
check("the map box lists everyone on the map, the party first with its leader, then the others by name",
      map_rows.map { |row| [row.name, row.member, row.level] }, [["Me", true, "Lv 40"], ["member", true, "Lv 33"], ["loner", false, ""], ["Stranger", false, "Lv 20"]])
check("only the party's leader keeps a crown, and every other player shows their ping", [map_rows.map { |row| row.badge && row.badge[1] }, map_rows[1..-1].map { |row| row.ping && row.ping[0] }],
      [[true, false, nil, nil], ["40 ms", "80 ms", "80 ms"]])
check("the box follows the world's type", MGQ_MpPartyBox.map_box?, true)

drawn = []
font = Struct.new(:color, :size, :outline, :bold, :out_color).new
canvas = Object.new
canvas.define_singleton_method(:font) { font }
canvas.define_singleton_method(:clear) { drawn.clear }
canvas.define_singleton_method(:fill_rect) { |*args| drawn << [:fill, args[2], args[3]] }
canvas.define_singleton_method(:text_size) { |text| Rect.new(0, 0, text.to_s.size * 8, 16) }
canvas.define_singleton_method(:stretch_blt) { |_dest, _set, rect, *_| drawn << (rect == MGQ_MpUi.icon_rect(MGQ_MpOverworld::CROWN_ICON) ? [:crown] : [:icon]) }
canvas.define_singleton_method(:draw_text) { |_x, _y, _w, _h, text, *_| drawn << [:text, text, font.color] }
map_box = Sprite_MpPartyBox.allocate
class << map_box; attr_accessor :x, :y; end
map_box.define_singleton_method(:bitmap) { canvas }
size_hint = Sprite_MpPartyBox::SIZE_HINT % MGQ_MpHotkeys.label(:party_box)
texts = lambda { drawn.select { |kind, _| kind == :text }.map { |_, text, _| text }.reject { |text| text.end_with?("ms") || text == size_hint } }
green = lambda { |name| drawn.find { |kind, text, _| kind == :text && text == name }[2].equal?(MGQ_MpUi::Style::MEMBER) }
row_height = Sprite_MpPartyBox::ROW
map_box.draw_map(map_rows)
check("it is titled with how many are on the map, a line each and no place", [texts.call, drawn.first],
      [["Map 4", "Me", "Lv 40", "member", "Lv 33", "loner", "", "Stranger", "Lv 20"], [:fill, Sprite_MpPartyBox::WIDTH, row_height * 5 + 4]])
check("party members are green, the player's own line and the others not", %w[Me member loner Stranger].map { |name| green.call(name) }, [false, true, false, false])
crowd = map_rows * 3
map_box.draw_map(crowd)
check("past ten lines it lists nine and says how many more", [texts.call.first, texts.call.size, texts.call.last, drawn.first[2]],
      ["Map 12", 1 + 9 * 2 + 1, "+3 more", row_height * 11 + 4])
map_box.draw_small([], crowd)
crowd = map_rows[1..-1] * 4 + map_rows.first(1)
shown, more = MGQ_MpPartyBox.capped(crowd)
check("cut short, it keeps the player's own line in place of the last listed", [shown.size, shown.last.player, shown.count { |row| row.player == :me }, more],
      [9, :me, 1, 4])
crowd = map_rows * 3
check("small, it keeps to ten lines too, the others white", [texts.call.size, texts.call.last, green.call("loner"), drawn.first[1..2]],
      [10, "+3 more", false, [Sprite_MpPartyBox::SMALL_WIDTH, row_height * 10 + 4]])
party, others = MGQ_MpPartyBox.sections
check("in a party the box lists the party first, with Frontline levels, then the others on the map",
      [party.map { |row| [row.name, row.level] }, others.map(&:name)], [[["Me", "Lv 40"], ["member", "Lv 33"]], ["loner", "Stranger"]])
map_box.draw(party, others)
place_height = Sprite_MpPartyBox::PLAYER_ROW
check("drawn as the party box, its places below the members, then the map's title and a line for each other player",
      [texts.call.last(5), drawn.first], [["Map 2", "loner", "", "Stranger", "Lv 20"], [:fill, Sprite_MpPartyBox::WIDTH, row_height + place_height * 2 + row_height * 3 + 4]])

MGQ_MpChat.stop_typing
$pressed = MGQ_MpHotkeys.code(:party_box)
MGQ_MpPartyBox.on_map
check("its key makes it small", MGQ_MpPartyBox.small?, true)
peers_here = MGQ_MpCoop::Scope.method(:peers_here)
MGQ_MpCoop::Scope.define_singleton_method(:peers_here) { [] }
check("alone on the map the party box still lists the party, and its key works", [overview.map_rows, MGQ_MpPartyBox.busy_reason, MGQ_MpPartyBox.sections.map { |rows| rows.map(&:name) }],
      [[], nil, [["Me", "member"], []]])
in_party = MGQ_MpCoop.method(:in_party?)
MGQ_MpCoop.define_singleton_method(:in_party?) { false }
check("outside a party there is no box then, and its key says why", MGQ_MpPartyBox.busy_reason, "nobody else is on the map")
MGQ_MpCoop.define_singleton_method(:in_party?, in_party)
MGQ_MpCoop::Scope.define_singleton_method(:peers_here, peers_here)
$raid = false
check("back in a Classic world the party box lists the party alone", overview.party_rows.map(&:name), ["Me", "member"])
# The World page, turned with the arrows.
$mouse = nil
$buttons.clear
$pressed = 0x7A
overview.on_map
overview.on_map
check("the overview opens on the Players page", [overview.page, overview.view[:page]], [:players, :players])
$buttons << :RIGHT
overview.on_map
online = overview.rows.size
check("Right turns to the World page, which in a Classic world tells the world's name, type, difficulty and players",
      [overview.page, overview.view[:page], overview.view[:lines]],
      [:world, :world, [[:info, "World", "Test World"], [:info, "Type", "Classic"], [:info, "Difficulty", "Per player"], [:info, "Players", "#{online} / 8"]]])
$buttons << :RIGHT
overview.on_map
check("past the last page it comes round to the first", overview.page, :players)
$buttons << :LEFT
overview.on_map
check("and Left turns back", overview.page, :world)

# A Raid World with a difficulty, a story and pools.
$raid = true
$difficulty = 1
$world_story = { "part" => "2" }
overview.on_map
lines = overview.view[:lines]
check("a Raid World tells its difficulty and its story, then heads its raid bosses by the story's section",
      lines[2..5], [[:info, "Difficulty", "Hard"], [:info, "Players", "#{online} / 8"], [:info, "Story", "Part 2"], [:place, "Raid bosses: Part 1"]])
sections = MGQ_MpRaidBosses.sections
headings = lambda { |all| all.select { |kind, _| kind == :place }.map { |_, text| text.sub("Raid bosses: ", "") } }
bosses = lines.select { |kind, _| kind == :boss }.map(&:last)
check("at Part 2 only Part 1 and Part 2 follow, each boss once in the order the story meets them, with its tier, untouched while the relay told no pool",
      [headings.call(lines), bosses.map(&:name), lines[6].last.to_a, bosses.last.to_a],
      [["Part 1", "Part 2"], sections[0][1] + sections[1][1], ["Four bandits", 9, 1.0, false, nil], ["Sonya Chaos", 4, 1.0, false, nil]])
check("the sections run in story order, the Chaos route's by the order of the troops, the one-time bosses last",
      [sections.map(&:first), sections[1][1].first, sections[1][1].last(3), sections[2][1].last, sections[5][1].first, sections[5][1].last, sections[6][1].size],
      [["Part 1", "Part 2", "Part 3", "Angelic Dominion", "Monster Realm", "Chaos route", "Chaos Domain"], "Bonnie and Ashel",
       ["Sonya Mazda", "Sonya Mainyu", "Sonya Chaos"], "Great Decision", "Kagetsumugi and her dolls (cap 125)", "Chaos", 6])
check("a boss's section is found by its troop or its name",
      [MGQ_MpRaidBosses.section(838), MGQ_MpRaidBosses.section("1509"), MGQ_MpRaidBosses.section("Tamamo (cap 83)"), MGQ_MpRaidBosses.section(2221), MGQ_MpRaidBosses.section("Chaos Maria"), MGQ_MpRaidBosses.section("Nobody")],
      ["Part 2", "Part 3", "Monster Realm", "Chaos route", "Chaos Domain", nil])
reached = lambda do |story|
  $world_story = story
  headings.call(overview.world_lines(1))
end
every = sections.map(&:first)
check("the sections shown follow the world's story: Part 1 from the start, Part 3 on every route, a route once under way or finished, the Chaos route with all",
      [reached.call("part" => "1"), reached.call("part" => "3"), reached.call("part" => "ad"), reached.call("part" => "mr", "done" => ["ad"]),
       reached.call("part" => "chaos", "done" => ["ad", "mr"]), reached.call("part" => "3", "done" => ["chaos"])],
      [every[0, 1], every[0, 3], every[0, 4], every[0, 5], every, every])
check("before the relay told the story no section shows without a pool", reached.call(nil), [])
$world_story = { "part" => "2" }
check("the title says the type and the difficulty after the world's name", [overview.world_name, overview.title_tail], ["Test World", " | Raid | Hard"])
$difficulty = nil
check("without a difficulty the type alone", overview.title_tail, " | Raid")
$difficulty = 1
$world_story = { "part" => "mr" }
check("the world's route is named as the player's own, through the variable that counts it", overview.world_story_text, "Part 3: Destroyer route")
$data_system.variables[1143] = "混沌ルート進行度"
$world_story = { "part" => "chaos" }
check("so is the Chaos route", overview.world_story_text, "Part 3: Chaos route")
$world_story = nil
check("before the relay told the story", overview.world_story_text, "Not told yet")
$world_story = { "part" => "2" }
told = Time.at(1_000_000)
pool = MGQ_MpRaidPool::Pool
$pools = { "Queen Harpy" => pool.new(0.4, 6000, false, "Player A", told), "Four bandits" => pool.new(0.0, 6000, true, "Player B", told),
           "Metatronne and Sandalphone#0" => pool.new(0.5, 9000, false, "Player C", told), "Metatronne and Sandalphone#1" => pool.new(1.0, 9000, false, "Player D", told + 1),
           "Fourth Law" => pool.new(0.25, 1, false, "", told), "Sisel" => pool.new(0.9, 1, false, "Player E", told),
           "Unknown Boss" => pool.new(0.5, 1, false, "Player F", told) }
pooled = overview.boss_sections
bosses = pooled.map(&:last).flatten(1)
boss_named = lambda { |name| bosses.find { |boss| boss.name == name } }
check("a pool tells a boss's share left and who last hurt it", boss_named.call("Queen Harpy").to_a, ["Queen Harpy", 9, 0.4, false, "Player A"])
check("an empty pool tells it defeated", boss_named.call("Four bandits").to_a[2..4], [0.0, true, "Player B"])
check("a boss of several enemies shares its pools' HP, hurt last by whoever hurt the pool told of last", boss_named.call("Metatronne and Sandalphone").to_a[2..4], [0.75, false, "Player D"])
check("a section the story did not reach shows once a boss of it has a pool, a fight's own pool in its section after its bosses, an unknown boss under Other last",
      [pooled.map(&:first), pooled[3][1].last.to_a, pooled[5][1].to_a.map(&:to_a)],
      [["Part 1", "Part 2", "Angelic Dominion", "Chaos route", "Chaos Domain", "Other"], ["Sisel", 2, 0.9, false, "Player E"], [["Unknown Boss", nil, 0.5, false, "Player F"]]])
check("a one-time boss the relay told a pool of shows in the Chaos Domain with its own tier and nobody known to have hurt it", pooled[4][1].first.to_a, ["Fourth Law", 1, 0.25, false, nil])
$world_story = nil
check("before the relay told the story only the sections with a pool show", overview.boss_sections.map(&:first), ["Part 1", "Angelic Dominion", "Chaos route", "Chaos Domain", "Other"])
$world_story = { "part" => "2" }
check("the share is written in percent, rounded, never 0% while any is left", %w[1.0 0.4 0.55 0.07 0.001 0.0].map { |left| overview.share_text(left.to_f) }, ["100%", "40%", "55%", "7%", "1%", "0%"])

# Scrolling the World page, and its tabs.
overview.on_map
$buttons << :DOWN
overview.on_map
check("Down scrolls the World page", overview.view[:scroll], 1)
most = overview.view[:lines].size - Sprite_MpWorldOverview.list_rows
100.times { $buttons << :DOWN; overview.on_map }
check("no further than the last line in sight", overview.view[:scroll], most)
$buttons << :UP
overview.on_map
check("and Up scrolls back", overview.view[:scroll], most - 1)
box = Sprite_MpWorldOverview.box
tab_y = box.y + Sprite_MpWorldOverview::TITLE + 5
tab_step = Sprite_MpWorldOverview::TAB_WIDTH + MGQ_MpUi::Style::GAP
$mouse = [box.x + Sprite_MpWorldOverview::MARGIN + 10, tab_y]
$click = true
overview.on_map
check("a click on the Players tab turns to it", overview.page, :players)
$mouse = [box.x + Sprite_MpWorldOverview::MARGIN + tab_step + 10, tab_y]
$click = true
$buttons << :B
overview.on_map
check("and a click on the World tab to the World page, where a cancel held with the click does not reach the page left", [overview.page, overview.open?], [:world, true])
$buttons.clear
check("the room between the tabs and the room past them is no tab",
      [Sprite_MpWorldOverview.tab_at(box.x + Sprite_MpWorldOverview::MARGIN + Sprite_MpWorldOverview::TAB_WIDTH + 1, tab_y), Sprite_MpWorldOverview.tab_at(box.x + Sprite_MpWorldOverview::MARGIN + 3 * tab_step, tab_y)], [nil, nil])
$mouse = nil

# The picture: the title with the world's type and difficulty before the party, the tabs, the
# hint and a raid boss's row.
sprite = Sprite_MpWorldOverview.allocate
sprite.bitmap = Bitmap.new(box.width, box.height)
sprite.draw(overview.view)
style = MGQ_MpUi::Style
check("the title says the world's type and difficulty after its name, the party at the right, then the tabs",
      sprite.bitmap.texts.first(4), ["Party 2 / 4", "Test World | Raid | Hard", "Players", "World"])
check("the hint names Left and Right and the numpad's 0", sprite.bitmap.texts.last, "Left or right: page   Up or down: scroll   Esc, Numpad 0 or F11: close")
gold_marks = lambda { sprite.bitmap.drawn.count { |kind, args| kind == :fill && args[4].equal?(style::GOLD) } }
check("the invite from afar still waits on the Players page, which marks its tab in gold while the World page shows", [overview.view[:calls], gold_marks.call], [true, 1])
$inbox << entry("message", 2, told(friend.merge("party" => "friend-p", "invite" => 0)))
MGQ_MpOverworldSync.tick
sprite.draw(overview.view)
check("without a call the tab has no mark", [overview.view[:calls], gold_marks.call], [false, 0])
$world.name = "A" * 60
sprite.draw(overview.view)
title = sprite.bitmap.texts[1]
room = box.width - 2 * (Sprite_MpWorldOverview::MARGIN + 2) - "Party 2 / 4".size * style::TITLE_SIZE / 2 - Sprite_MpWorldOverview::TITLE_GAP
check("a long world name is cut before its type, which stays whole, so it never runs into the party",
      [title.end_with?("... | Raid | Hard"), title.size * style::TITLE_SIZE / 2 <= room], [true, true])
$world.name = "Test World"
sprite.bitmap.clear
sprite.draw_boss(boss_named.call("Queen Harpy"), 0)
gauge = sprite.bitmap.drawn.select { |kind, _| kind == :fill }.map { |_, args| args }
columns = Sprite_MpWorldOverview::WORLD_COLUMNS
check("a raid boss's row: its name, tier, share and who last hurt it", sprite.bitmap.texts, ["Queen Harpy", "Tier 9", "40%", "last hurt by Player A"])
check("over a thin gauge: its frame, its empty part and the share left in the bad color",
      gauge, [[columns[:gauge], 9, 90, 6, style::EDGE], [columns[:gauge] + 1, 10, 88, 4, style::WELL], [columns[:gauge] + 1, 10, 35, 4, style::BAD]])
sprite.bitmap.clear
sprite.draw_boss(boss_named.call("Four bandits"), 0)
check("a defeated boss says so in place of its share, dimmed, with an empty gauge",
      [sprite.bitmap.texts, sprite.bitmap.drawn.find { |kind, _| kind == :text }[2].equal?(style::DIM), sprite.bitmap.drawn.count { |kind, _| kind == :fill }],
      [["Four bandits", "Tier 9", "Defeated", "last hurt by Player B"], true, 2])

# The box among those the player moves and resizes: its default, a placement Player.ini keeps, its
# least size, the lines, the menu and the clicks following it, and a box at its least size still
# drawing every column, tab and hint.
layout = MGQ_MpUi::Layout
sprite_class = Sprite_MpWorldOverview
# Keeps a placement in Player.ini as the layout stores it, nil for none, and forgets the one read.
place_box = lambda do |text|
  text ? $player_ini["ui_overview"] = text : $player_ini.delete("ui_overview")
  layout.instance_variable_get(:@stored).delete(:overview)
end
place_box.call(nil)
check("the overview is a box the player moves and resizes both ways, never smaller than what its columns, tabs, lines and menu need",
      [layout.instance_variable_get(:@boxes)[:overview].to_a, [sprite_class::PLAYERS_WIDTH, sprite_class::WORLD_WIDTH, sprite_class::TABS_WIDTH]],
      [["World overview", 560, 166, :both], [560, 560, 220]])
check("it starts at the list box's place with its lines", [sprite_class.box.to_a, sprite_class.list_rows], [[40, 32, 560, 404], 13])
place_box.call("20,150,600,300")
check("a placement Player.ini keeps is honoured, the lines following its height", [sprite_class.box.to_a, sprite_class.list_rows], [[20, 150, 600, 300], 9])
check("the clicks follow the box: its tabs and inside it where it lies now, not where it starts",
      [sprite_class.tab_at(20 + sprite_class::MARGIN + 10, 150 + sprite_class::TITLE + 5), sprite_class.tab_at(40 + sprite_class::MARGIN + 10, 32 + sprite_class::TITLE + 5),
       sprite_class.inside?(25, 155), sprite_class.inside?(45, 40)], [:players, nil, true, false])
check("a line under the mouse is read from the box's top", sprite_class.line_at(100, 150 + sprite_class::LIST_TOP + sprite_class::ROW * 2 + 3, overview.view), overview.view[:scroll] + 2)
place_box.call("0,0,100,50")
check("a placement smaller than the least size grows to it", sprite_class.box.to_a, [0, 0, 560, 166])
check("which still shows three lines", sprite_class.list_rows, 3)
menu_left = 560 - sprite_class::MENU_WIDTH - sprite_class::MARGIN
menu_view = { :selected => 2, :scroll => 0, :menu => [MGQ_MpActions::Option.new("Choice", nil, nil)] * sprite_class::MENU_ROWS }
check("the longest menu stays whole above the hint in the lowest box, below or above the player picked once there is room",
      [sprite_class.menu_origin(menu_view, 560, 166), sprite_class.menu_origin(menu_view, 560, 404), sprite_class.menu_origin(menu_view.merge(:selected => 9), 560, 404)],
      [[menu_left, 0], [menu_left, sprite_class::LIST_TOP + 3 * sprite_class::ROW], [menu_left, sprite_class::LIST_TOP + 9 * sprite_class::ROW - 6 * sprite_class::ROW]])

# The picked player kept in sight and the World page's scroll kept within its lines as the box's
# height changes.
place_box.call(nil)
overview.turn_to(:players, "the test")
overview.on_map
players = (0...overview.view[:lines].size).select { |line| overview.view[:lines][line][0] == :player }
overview.instance_variable_set(:@selected, overview.key_of(overview.view[:lines][players.last][1]))
overview.on_map
place_box.call("0,0,560,166")
overview.on_map
view = overview.view
check("in a lower box the picked player stays in sight", [view[:selected] >= view[:scroll], view[:selected] < view[:scroll] + 3], [true, true])
place_box.call(nil)
overview.on_map
check("and in a taller one no room is left below the last line", overview.view[:scroll], [overview.view[:lines].size - 13, 0].max)
overview.turn_to(:world, "the test")
place_box.call("0,0,560,166")
overview.on_map
100.times { $buttons << :DOWN; overview.on_map }
low_scroll = overview.view[:scroll]
place_box.call(nil)
overview.on_map
check("the World page scrolls further in a lower box, and back within its lines in a taller one",
      [low_scroll, overview.view[:scroll]], [overview.view[:lines].size - 3, [overview.view[:lines].size - 13, 0].max])

# The sprite: placed where the box lies, its picture as large, offered to the layout, drawn anew
# once the box's size or the preset changed.
class Sprite; def update; end; end unless Sprite.method_defined?(:update)
place_box.call("20,150,600,300")
overview_sprite = Sprite_MpWorldOverview.new(nil)
draws = 0
overview_sprite.define_singleton_method(:draw) { |shown| draws += 1; super(shown) }
overview_sprite.update
offers = layout.instance_variable_get(:@offers).select { |offer| offer.id == :overview }
check("the sprite lies where the box lies, its picture as large, and offers its place to the layout",
      [overview_sprite.x, overview_sprite.y, overview_sprite.bitmap.width, overview_sprite.bitmap.height, offers.map { |offer| offer.rect.to_a }, draws],
      [20, 150, 600, 300, [[20, 150, 600, 300]], 1])
overview_sprite.update
place_box.call("30,150,600,300")
overview_sprite.update
check("moving it draws nothing anew", [overview_sprite.x, draws], [30, 1])
old_bitmap = overview_sprite.bitmap
place_box.call("30,150,610,320")
overview_sprite.update
check("resizing it makes its picture anew and draws it", [overview_sprite.bitmap.width, overview_sprite.bitmap.height, old_bitmap.disposed?, draws], [610, 320, true, 2])
MGQ_MpUi::Theme.apply("Monarch", "the test")
overview_sprite.update
check("so does another preset", draws, 3)
fills = overview_sprite.bitmap.drawn.select { |kind, _| kind == :fill }.map { |_, args| args }
tab_fills = fills.select { |args| args[1] == sprite_class::TITLE && args[2] == sprite_class::TAB_WIDTH }.map { |args| args[4] }
check("the box is framed in the preset's colors, the page shown on the picked tab and the other on the tab color",
      [fills.first, fills.count { |args| args[4].equal?(style::EDGE) } >= 4, fills.any? { |args| args[4].equal?(style::RIM) }, tab_fills.map { |color| [color.equal?(style::PICKED), color.equal?(style::TAB)] }],
      [[0, 0, 610, 320, style::BACK], true, true, [[false, true], [true, false]]])
check("the world's name in the title color", overview_sprite.bitmap.drawn.find { |kind, text, _| kind == :text && text.start_with?("Test World") }[2].equal?(style::TITLE), true)
MGQ_MpUi::Theme.apply("Legacy", "the test")
overview_sprite.dispose

# A box at its least size still draws every column, the title, the tabs and the whole hint.
# Reports whether every text drawn lies inside the picture.
inside_box = lambda { |bitmap| bitmap.drawn.select { |kind, _| kind == :text }.all? { |_, _, _, x, width, _| x >= 0 && x + width <= bitmap.width } }
narrow = Sprite_MpWorldOverview.allocate
narrow.bitmap = Bitmap.new(sprite_class::MIN_WIDTH, sprite_class::MIN_HEIGHT)
place_box.call("0,0,1,1")
overview.turn_to(:players, "the test")
overview.instance_variable_set(:@selected, :me)
overview.on_map
narrow.draw(overview.view)
texts = narrow.bitmap.texts
ping_left = sprite_class::MIN_WIDTH - sprite_class::PING_INSET - MGQ_MpOverworld::PING_WIDTH
story = narrow.bitmap.drawn.find { |kind, text, _| kind == :text && text == "Part 3: Destroyer route" }
check("narrowest, the Players page draws the title, both tabs, its lines with the story column at its least before the ping, and the whole hint smaller",
      [texts.first(4), texts.include?("Me (you)"), story && story[3..4], narrow.bitmap.drawn.count { |kind, _, _, x| kind == :text && x == ping_left } > 0, texts.last, narrow.bitmap.font.size, inside_box.call(narrow.bitmap)],
      [["Party 2 / 4", "Test World | Raid | Hard", "Players", "World"], true, [sprite_class::COLUMNS[:story], sprite_class::STORY_WIDTH], true,
       "Left or right: page   Enter: invite, duel or trade   Esc, Numpad 0 or F11: close", style::TINY_SIZE, true])
overview.turn_to(:world, "the test")
overview.instance_variable_set(:@world_scroll, 0)
overview.on_map
narrow.draw(overview.view)
check("narrowest, the World page draws the title, both tabs, its first lines and the whole hint smaller",
      [narrow.bitmap.texts, narrow.bitmap.font.size, inside_box.call(narrow.bitmap)],
      [["Party 2 / 4", "Test World | Raid | Hard", "Players", "World", "World", "Test World", "Type", "Raid", "Difficulty", "Hard",
        "Left or right: page   Up or down: scroll   Esc, Numpad 0 or F11: close"], style::TINY_SIZE, true])
narrow.bitmap.clear
narrow.draw_boss(boss_named.call("Queen Harpy"), 0)
check("and a raid boss's every column at the World page's columns", [narrow.bitmap.texts, narrow.bitmap.drawn.select { |kind, _| kind == :text }.map { |entry| entry[3] }, inside_box.call(narrow.bitmap)],
      [["Queen Harpy", "Tier 9", "40%", "last hurt by Player A"], [columns[:label], columns[:tier], columns[:share], columns[:by]], true])
wide = Sprite_MpWorldOverview.allocate
wide.bitmap = Bitmap.new(sprite_class::MIN_WIDTH + 100, sprite_class::MIN_HEIGHT)
wide.draw_boss(boss_named.call("Queen Harpy"), 0)
check("wider, the boss's name takes the extra room, the columns right of it moving along",
      [wide.bitmap.drawn.select { |kind, _| kind == :text }.map { |entry| [entry[3], entry[4]] }, wide.bitmap.drawn.find { |kind, _| kind == :fill }[1][0]],
      [[[columns[:label], columns[:tier] + 100 - columns[:label] - style::GAP], [columns[:tier] + 100, columns[:gauge] - columns[:tier] - style::GAP],
        [columns[:share] + 100, columns[:share_right] - columns[:share]], [columns[:by] + 100, sprite_class::BY_WIDTH]], columns[:gauge] + 100])
wide.bitmap.clear
wide.draw_player(overview.rows.find { |row| row.ping }, 0, false)
check("and on the Players page the story takes it, the ping keeping the right edge",
      wide.bitmap.drawn.select { |kind, _, _, x| kind == :text && x >= sprite_class::COLUMNS[:story] }.map { |entry| [entry[3], entry[4]] },
      [[sprite_class::COLUMNS[:story], sprite_class::STORY_WIDTH + 100], [ping_left + 100, MGQ_MpOverworld::PING_WIDTH]])
place_box.call(nil)
$pools = {}
$raid = false

# The confirm box before removing a member and leaving the party, which the overview waits for.
confirm = MGQ_MpUi::Confirm
$frame = 1
member_peer = MGQ_MpOverworldSync::Peers.at(3)
removed = []
remove = MGQ_MpCoop::Party.method(:remove)
MGQ_MpCoop::Party.define_singleton_method(:remove) { |peer| removed << peer.seat }
MGQ_MpCoop::Offers.peer_option(member_peer).run.call
check("removing a member asks first, naming them", [confirm.open?, confirm.instance_variable_get(:@question), confirm.instance_variable_get(:@yes), confirm.instance_variable_get(:@no)],
      [true, "Remove member from the party?", "Remove", "Keep"])
$frame += 1
$pressed = MGQ_MpHotkeys.code(:decline)
2.times { confirm.tick }
check("no keeps them", [confirm.open?, removed], [false, []])
MGQ_MpCoop::Offers.peer_option(member_peer).run.call
$frame += 1
$pressed = MGQ_MpHotkeys.code(:accept)
2.times { confirm.tick }
check("yes removes them", removed, [3])
MGQ_MpCoop::Party.define_singleton_method(:remove, remove)
overview.turn_to(:players, "the test")
overview.close
$pressed = 0x7A
overview.on_map
overview.on_map
$buttons << :C
overview.on_map
check("the player's own menu offers to leave", overview.view[:menu].map(&:text).first, "Leave the party")
$buttons << :C
overview.on_map
check("leaving asks first, closing the menu, and the overview stays", [confirm.open?, confirm.instance_variable_get(:@question), overview.view[:menu], overview.open?], [true, "Leave the party?", nil, true])
$buttons << :B
overview.on_map
check("the overview reads no key while the box asks", [overview.open?, $buttons], [true, [:B]])
$buttons.clear
$frame += 1
$pressed = MGQ_MpHotkeys.code(:decline)
2.times { confirm.tick }
check("no keeps the party", [confirm.open?, MGQ_MpCoop::Party.id.nil?], [false, false])
leave_option = MGQ_MpCoop::Offers.party_options(true).first
$buttons << :C
overview.on_map
$buttons << :C
overview.on_map
$frame += 1
$pressed = MGQ_MpHotkeys.code(:accept)
2.times { confirm.tick }
check("yes leaves it", [confirm.open?, MGQ_MpCoop::Party.id], [false, nil])
overview.close
leave_option.run.call
notices = MGQ_MpOverworldSync::Status.lines.size
$pressed = MGQ_MpHotkeys.code(:accept)
$frame += 1
2.times { confirm.tick }
check("yes once the party dissolved under the box leaves nothing, so nothing says so", [confirm.open?, MGQ_MpOverworldSync::Status.lines.size], [false, notices])

MGQ_MpCoopSquad.define_singleton_method(:own_order, own_order)
overview.tick(false)
check("a closed world forgets what the player told, so the next one reads it at once",
      [overview.instance_variable_get(:@front), overview.instance_variable_get(:@level), overview.instance_variable_get(:@frames)], [nil, nil, 0])
