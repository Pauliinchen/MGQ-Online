#----------------------------------------------------------------
#  world_overview_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-12: Checked the World, Quests and Unlocks pages with a head, a list and a pane
#                            - Checked the Quests page and the catch-up experience on the Levels page
#                            - Checked that a refused overview hotkey is logged under the hotkeys, and not while the player types
#                            - Checked that Part 2 starts at progress 19 and Part 3 at 34, with a route shown before the Great Decision
#      Paulinchen  2026-10-11: Checked the Levels page of a Raid World, its rows drawn and its absence in a Classic world, and counted its tab among the tabs
#                            - Checked that the level told is the formation's highest, Luka included, and kept during a co-op battle
#                            - Checked a Raid World's objective on the World page: Amira's first words in a branch, plain, past her network's branch, read every few seconds and wrapped
#                            - Expected Part 2 to start with Bonnie and Ashel and end with Sonya Mazda, Sonya Mainyu and Sonya Chaos
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
# formation's highest level, place in the story), the list by place, opening with F11 and the
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
    def self.wheel; $wheel.to_i; end
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
  PART_TWO = 19
  PART_THREE = 34
  ROUTES = %w(ad mr chaos)
  ROUTE_VARIABLES = [1141, 1142, 1143]
  def self.world; $world_story; end
  def self.active?; $raid; end
  def self.part_of(counters); counters["part"]; end
end
# The catch-up's list of what it hands out by level, and the level it counts.
module MGQ_MpWorldCatchup
  Unlock = Struct.new(:level, :kind, :name, :icon, :got, :due, :id, :gains)
  Gain = Struct.new(:kind, :id, :item_kind, :amount, :name, :icon)
  def self.unlocks; $unlocks; end
  def self.counted_level; $counted_level; end
end
$unlocks = []
$counted_level = nil
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
  def stretch_blt(*args); @drawn << [:blt, args]; end
  def clear; @drawn.clear; end
  def dispose; @disposed = true; end
  def disposed?; @disposed ? true : false; end
  def texts; @drawn.select { |kind, _| kind == :text }.map { |_, text, _| text }; end
end
# A character, whose levels the game keeps as a Hash of base, class and race level.
Actor = Struct.new(:base_level, :luca) do
  def luca?; luca; end
  def name; luca ? "Luka" : "Lv#{base_level}"; end
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
load_script "world_catchup_exp"
load_script "world_overview"
load_script "world_overview_pages"
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
$data_system.variables[1001] = "Overall Events Progress"
$game_variables[1142] = 0
$game_variables[1001] = 18
$game_switches[50] = false
check("progress 18 is still Part 1", overview.story_code, "1")
$game_switches[50] = true
check("Part 2 starts at progress 19, with Tartarus Escape", [19, 33].map { |progress| $game_variables[1001] = progress; overview.story_code }, ["2:alice", "2:alice"])
$game_variables[1001] = 34
check("Part 3 starts at progress 34, with the Middle Chapter's epilogue", overview.story_code, "3:alice")
$game_variables[1142] = 3
$game_variables[1001] = 39
check("before the Great Decision a route already shows", overview.story_code, "3:destroyer")
check("an unknown place shows nothing", overview.story_text(""), "")
logged = []
write = MGQ_Multiplayer::Log.method(:write)
MGQ_Multiplayer::Log.define_singleton_method(:write) { |line| logged << line }
check("a name the game lacks reads 0 or off, logged once", [overview.variable(["No Such"]), overview.variable(["No Such"]), overview.switch?(["Nor This"]), logged],
      [0, 0, false, ["overview: no variable of the game is named No Such, reading 0", "overview: no switch of the game is named Nor This, reading off"]])
MGQ_Multiplayer::Log.define_singleton_method(:write, write)

# The formation's highest level and the place.
$game_party.all_members = [Actor.new(30, true), Actor.new(55, false), Actor.new(99, false)]
$game_party.stand_members = [Actor.new(80, false)]
def $game_party.battle_members; all_members.first(2); end
check("the formation's highest, Luka included, the reserve and waiting ones left out", overview.formation_level, 55)
$game_party.all_members = [Actor.new(60, true), Actor.new(55, false), Actor.new(99, false)]
check("Luka counts like everyone in the formation", overview.formation_level, 60)
$game_party.all_members = [Actor.new(30, true), Actor.new(55, false), Actor.new(99, false)]
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
refused = logged_lines { overview.on_map }
check("the overview stays shut while the emote wheel is open", overview.open?, false)
check("which the log says under the hotkeys", refused.grep(/ignored/),
      ["keys: hotkey F11 (World Overview) ignored: not on a quiet map in a world, or the chat or a wheel is open"])
$mgq_text_input = true
$pressed = 0x7A
typed = logged_lines { overview.on_map }
$mgq_text_input = nil
check("but not while the player types, where a hotkey bound to a letter is what they typed", [overview.open?, typed.grep(/ignored/)], [false, []])
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
check("the formation's level too", overview.formation_level, 55)
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
world = overview.view[:model]
check("Right turns to the World page, which in a Classic world heads the world's name with its type and difficulty, its players and that each party plays its leader's story",
      [overview.page, world.head.title, world.head.note, world.head.lines, world.rows],
      [:world, "Test World", "Classic | Per player", ["Players online: #{online} / 8", "Each party plays its leader's story."], [[:none, "Raid bosses fight in Raid Worlds."]]])
$buttons << :RIGHT
overview.on_map
check("Right turns on to the Quests page, in a Classic world too", overview.page, :quests)
$buttons << :RIGHT
overview.on_map
check("past the last page it comes round to the first", overview.page, :players)
$buttons << :LEFT
overview.on_map
$buttons << :LEFT
overview.on_map
check("and Left turns back", overview.page, :world)

# A Raid World with a difficulty, a story and pools.
$raid = true
$difficulty = 1
$world_story = { "part" => "2" }

# The Unlocks page of a Raid World: Luka with the catch-up experience at the top, the levels in the
# list, what a level brings in the pane.
unlock = MGQ_MpWorldCatchup::Unlock
gain = MGQ_MpWorldCatchup::Gain
$unlocks = [unlock.new(10, :story, "Part 1", nil, true, false, nil, [gain.new(:item, 5, "i", 1, "Herb", 20)]),
            unlock.new(25, :story, "Part 2", nil, false, true, nil,
                       [gain.new(:key, 615, "i", 1, "Informant Papers", 230), gain.new(:skill, 930, nil, 1, "Hero Slash", 40), gain.new(:item, 7, "i", 3, "Herb", 20)]),
            unlock.new(25, :companion, "Lime", nil, false, true, 54, []),
            unlock.new(40, :makina, "Super Vibro Blade", 183, false, false, 701, [])]
$counted_level = 30
$buttons << :RIGHT
overview.on_map
$buttons << :RIGHT
overview.on_map
unlocks = overview.view[:model]
check("in a Raid World Right turns on past the Quests page to the Unlocks page, headed by the catch-up experience with the level it counts",
      [overview.page, unlocks.head.title, unlocks.head.note, unlocks.head.lines, unlocks.head.grid],
      [:unlocks, "Catch-up EXP", "Your level 30", ["Starts once the world's story raises the level cap."], nil])
check("the levels whose every unlock the player got fold under Passed, the others follow under Coming up",
      unlocks.rows.map { |kind, value| kind == :entry ? [kind, value.level, value.got, value.due] : (kind == :fold ? [kind, value.title, value.open] : [kind, value]) },
      [[:fold, "Passed (1)", false], [:fold, "Coming up (2)", true], [:entry, 25, false, true], [:entry, 40, false, false]])
check("a level's row tells what it brings and that it is due",
      overview.row_view(unlocks.rows[2][1]).to_a, ["Level 25", "Part 2, Lime", "Due", false, nil])
pane = overview.pane_of(unlocks.rows[2][1])
check("its pane lists key items and unlocks first, then moving on, the companions, the skills, the Makina and the other items, each with its icon or portrait, the note they share once in the title",
      [pane.title, pane.lines.map { |kind, item| item ? [item.name, item.icon, item.note] : kind }],
      ["Level 25 · Due", [["Informant Papers", 230, nil], :gap, ["Moving on from Part 2", nil, nil], :gap, ["Lime", nil, nil], :gap, ["Hero Slash", 40, nil], :gap, ["Herb x3", 20, nil]]])
group = lambda { |*names| names.map { |name| [:item, overview::PaneItem.new(nil, nil, name, nil, false)] } }
crowd = overview::Pane.new("Level 25", nil, group.call("Moving on from Part 2") + [[:gap]] + group.call("Lime", "Ilias", "Alice", "Lime", "Ilias") + [[:gap]] + group.call("Herb", "Herb"))
laid = lambda { Sprite_MpWorldOverview.pane_layout(crowd).map { |kind, (items, columns)| kind == :items ? [items.size, columns] : kind } }
check("in the box's least width the pane sets each group in as many columns as its longest name fits",
      laid.call, [[1, 1], :gap, [3, 3], [2, 3], :gap, [2, 3]])
$player_ini["ui_overview"] = "0,32,640,404"
MGQ_MpUi::Layout.instance_variable_get(:@stored).delete(:overview)
check("in the widest box more of them share a row, at most four", laid.call, [[1, 1], :gap, [3, 3], [2, 3], :gap, [2, 4]])
$player_ini.delete("ui_overview")
MGQ_MpUi::Layout.instance_variable_get(:@stored).delete(:overview)
mixed = overview.level_pane(overview::Level.new(25, [$unlocks[1].dup.tap { |part| part.got = true; part.due = false }, $unlocks[2]], false, true))
check("a level whose unlocks differ keeps each one's note", [mixed.title, mixed.lines.map { |_, item| item && item.note }.compact.uniq], ["Level 25", ["Done", "Due"]])
$buttons << :C
overview.on_map
unlocks = overview.view[:model]
check("confirm on Passed opens it", unlocks.rows.first(2).map { |kind, value| kind == :entry ? value.level : value.title }, ["Passed (1)", 10])
check("a passed level's pane says so, its unlocks dimmed",
      [overview.pane_of(unlocks.rows[1][1]).title, overview.pane_of(unlocks.rows[1][1]).lines.map { |kind, item| item ? [item.name, item.note, item.dim] : kind }],
      ["Level 10, passed", [["Moving on from Part 1", nil, true], :gap, ["Herb", nil, true]]])
unlock_sprite = Sprite_MpWorldOverview.allocate
unlock_sprite.bitmap = Bitmap.new(Sprite_MpWorldOverview.box.width, Sprite_MpWorldOverview.box.height)
unlock_sprite.draw(overview.view)
check("the page draws its head, the groups and the levels",
      ["Catch-up EXP", "Your level 30", "▾ Passed (1)", "▾ Coming up (2)", "Level 10", "Level 25", "Level 40"].map { |text| unlock_sprite.bitmap.texts.any? { |drawn| drawn.to_s.start_with?(text) } }, [true] * 7)
$buttons << :C
overview.on_map
check("and confirm folds it again", overview.view[:model].rows.first[1].open, false)
overview.pick_entry(:unlocks, 1)
$buttons << :C
overview.on_map
check("Coming up folds the same way", overview.view[:model].rows.map { |kind, value| [kind, value.title, value.open] }, [[:fold, "Passed (1)", false], [:fold, "Coming up (2)", false]])
$buttons << :C
overview.on_map
$unlocks = []
overview.turn_to(:world, "the test")
overview.turn_to(:unlocks, "the test")
overview.on_map
check("with nothing unlocked yet it says so", overview.view[:model].rows, [[:none, "Nothing to catch up with yet."]])
members = $game_party.all_members
$game_party.all_members = [Actor.new(30, true), Actor.new(20, false), Actor.new(99, false)]
$world_story = $world_story.merge("caps" => [10, 40, 65])
overview.turn_to(:world, "the test")
overview.turn_to(:unlocks, "the test")
overview.on_map
check("once the world's story raised the level cap, the head lists each formation member's level and catch-up experience up to the level it holds",
      [overview.view[:model].head.title, overview.view[:model].head.grid], ["Catch-up EXP until level 40", [["Luka", "Lv 30", "x4"], ["Lv20", "Lv 20", "x7"]]])
$game_party.all_members = members
$world_story = $world_story.reject { |key, _| key == "caps" }
$raid = false
overview.on_map
check("a Classic world has no Unlocks page, which turns back to the Players page", [overview.page, overview.pages.map(&:first)], [:players, [:players, :world, :quests]])
$raid = true
overview.turn_to(:world, "the test")
overview.on_map
world = overview.view[:model]
sections = MGQ_MpRaidBosses.sections
check("a Raid World heads its type and difficulty, its players and its story, then lists its raid bosses under a heading per section with how many it holds",
      [world.head.note, world.head.lines, [world.rows.first[0], world.rows.first[1].title]], ["Raid | Hard", ["Players online: #{online} / 8", "Story: Part 2"], [:fold, "Part 1 (#{sections[0][1].size})"]])
headings = lambda { |model| model.rows.select { |kind, _| kind == :fold }.map { |_, fold| fold.title.sub(/ \(\d+\)\z/, "") } }
bosses = world.rows.select { |kind, _| kind == :entry }.map { |_, entry| entry.boss }
check("at Part 2 only Part 1 and Part 2 follow, each boss once in the order the story meets them, with its tier, untouched while the relay told no pool",
      [headings.call(world), bosses.map(&:name), bosses.first.to_a, bosses.last.to_a],
      [["Part 1", "Part 2"], sections[0][1] + sections[1][1], ["Four bandits", 9, 1.0, false, nil], ["Sonya Chaos", 4, 1.0, false, nil]])
check("a boss's row tells its share left over a gauge, its pane its section, its tier with what it changes and its gauge",
      [overview.row_view(world.rows[1][1]).to_a, overview.pane_of(world.rows[1][1]).to_a],
      [[nil, "Four bandits", "100%", false, 1.0], ["Four bandits", nil, [[:text, "Part 1"], [:text, "Tier 9: enemies have HP x5."], [:gauge, 1.0, "100%"]]]])
check("the sections run in story order, the Chaos route's by the order of the troops, the one-time bosses last",
      [sections.map(&:first), sections[1][1].first, sections[1][1].last(3), sections[2][1].last, sections[5][1].first, sections[5][1].last, sections[6][1].size],
      [["Part 1", "Part 2", "Part 3", "Angelic Dominion", "Monster Realm", "Chaos route", "Chaos Domain"], "Bonnie and Ashel",
       ["Sonya Mazda", "Sonya Mainyu", "Sonya Chaos"], "Great Decision", "Kagetsumugi and her dolls (cap 125)", "Chaos", 6])
check("a boss's section is found by its troop or its name",
      [MGQ_MpRaidBosses.section(838), MGQ_MpRaidBosses.section("1509"), MGQ_MpRaidBosses.section("Tamamo (cap 83)"), MGQ_MpRaidBosses.section(2221), MGQ_MpRaidBosses.section("Chaos Maria"), MGQ_MpRaidBosses.section("Nobody")],
      ["Part 2", "Part 3", "Monster Realm", "Chaos route", "Chaos Domain", nil])
reached = lambda do |story|
  $world_story = story
  headings.call(overview.world_model)
end
every = sections.map(&:first)
check("the sections shown follow the world's story: Part 1 from the start, Part 3 on every route, a route once under way or finished, the Chaos route with all",
      [reached.call("part" => "1"), reached.call("part" => "3"), reached.call("part" => "ad"), reached.call("part" => "mr", "done" => ["ad"]),
       reached.call("part" => "chaos", "done" => ["ad", "mr"]), reached.call("part" => "3", "done" => ["chaos"])],
      [every[0, 1], every[0, 3], every[0, 4], every[0, 5], every, every])
check("before the relay told the story no section shows without a pool, which says so", [reached.call(nil), overview.world_model.rows], [[], [[:none, "No raid bosses yet."]]])
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

# The story's objective, as Amira's event tells it asked for information.
ObjectiveCommand = Struct.new(:code, :indent, :parameters)
ObjectiveEvent = Struct.new(:list)
command = lambda { |code, indent, *params| ObjectiveCommand.new(code, indent, params) }
message = lambda { |indent, *lines| [command.call(101, indent, "amira_fc1", 0, 0, 2)] + lines.map { |line| command.call(401, indent, line) } }
amira = message.call(0, "\\n<Amira>", "Let's see, your current primary objective is...") +
        [command.call(111, 0, 1, 1009, 0, 1, 2)] + message.call(1, "\\n<Amira>Give me some time until my information network is developed.") + [command.call(115, 1), command.call(412, 0)] +
        [command.call(111, 0, 1, 1001, 0, 9, 2)] + message.call(1, "\\n<Amira>Head to the \\C[17]Tartarus rift\\C[0] south", "of Iliasville.") + [command.call(412, 0)] +
        [command.call(111, 0, 1, 1001, 0, 10, 0), command.call(117, 1, 120), command.call(412, 0)] +
        [command.call(111, 0, 1, 1001, 0, 11, 0), command.call(119, 1, "tip"), command.call(412, 0)] +
        [command.call(111, 0, 0, 5, 0), command.call(118, 1, "tip")] + message.call(1, "Your party has \\V[7] members.") + [command.call(412, 0)]
$data_common_events = []
$data_common_events[overview::OBJECTIVE_EVENT] = ObjectiveEvent.new(amira)
$data_common_events[120] = ObjectiveEvent.new(message.call(0, "\\n<Amira>Cross the eastern mountains."))
objective = lambda do |progress|
  $game_variables[1001] = progress
  main = overview.main_quest
  main && main.texts
end
$game_variables[1009] = 0
$game_variables[7] = 3
check("the main quest is Amira's words in a branch, plain, past her network's branch, through the events she calls and the labels she jumps to",
      [objective.call(5), objective.call(10), objective.call(11), objective.call(12)],
      [["Head to the Tartarus rift south of Iliasville."], ["Cross the eastern mountains."], ["Your party has 3 members."], nil])
$world_story = { "part" => "1" }
$game_variables[1001] = 5
note = overview.world_model.rows.first[1]
check("the World page lists it first as the objective, its first sentence in the row and all of it in the pane",
      [note.title, overview.row_view(note).to_a, overview.pane_of(note).lines],
      ["Objective", ["Objective", "Head to the Tartarus rift south of Iliasville.", nil, false, nil], [[:text, "Head to the Tartarus rift south of Iliasville."]]])

# The Quests page: the main quest, Amira's side quests and the board's companion quests.
mark = lambda { |indent| command.call(122, indent, overview::QUEST_COUNT, overview::QUEST_COUNT, 0, 0, 1) }
main = message.call(0, "\\n<Amira>", "Let's see, your current primary objective is...") +
       [command.call(111, 0, 1, 1001, 0, 10, 0)] + message.call(1, "\\n<Amira>Cross the mountains.") + message.call(1, "\\n<Amira>Buy golden equipment.") + [command.call(412, 0)] +
       [command.call(111, 0, 1, 1143, 0, 20, 2), command.call(117, 1, 131), command.call(115, 1), command.call(412, 0)]
sides = message.call(0, "\\n<Amira>I have some other information.") +
        [command.call(111, 0, 0, 2018, 1), mark.call(1)] + message.call(1, "\\n<Amira>Strange crying near Iliasville.") + [command.call(412, 0)] +
        [command.call(111, 0, 1, 1004, 0, 0, 0), mark.call(1)] + message.call(1, "\\n<Amira>A troublesome job.") +
        [command.call(111, 1, 0, 6, 0)] + message.call(2, "\\n<Sonya>She sounds scary.") + [command.call(411, 1)] + message.call(2, "\\n<Luka>So she sells them.") + [command.call(412, 1)] +
        message.call(1, "\\n<Amira>Go to the slums.") + [command.call(412, 0)] +
        [command.call(111, 0, 8, 151), command.call(411, 0), mark.call(1)] + message.call(1, "\\n<Amira>Iron ore in the Pornof mines.") + [command.call(412, 0)] +
        [command.call(111, 0, 1, 1009, 0, 3, 1), mark.call(1)] + message.call(1, "\\n<Amira>The engineer wants makina.") + [command.call(412, 0)] +
        [command.call(111, 0, 0, 2040, 0), mark.call(1)] + message.call(1, "\\n<Amira>A door in a solid wall.") + [command.call(412, 0)]
board = message.call(0, "It seems your companions have written a variety of messages on this bulletin board.") +
        [command.call(111, 0, 0, 1056, 0), mark.call(1), command.call(111, 1, 1, 1041, 0, 0, 0)] + message.call(2, "\\n<Rami>Take me to Harpy Village♪") + [command.call(412, 1), command.call(412, 0)] +
        [command.call(111, 0, 12, "actor_class_level_over?(1, 151, 10)"), mark.call(1)] + message.call(1, "\\n<Kamuro>Homework.") + [command.call(412, 0)] +
        [command.call(111, 0, 12, "$game_switches[1] = true"), mark.call(1)] + message.call(1, "\\n<Gigi>Never.") + [command.call(412, 0)] +
        [command.call(111, 0, 0, 1060, 0), mark.call(1)] + message.call(1, "【ポチ】", "犬に会いたい") + [command.call(412, 0)]
BoardPage = Struct.new(:list)
BoardEvent = Struct.new(:pages)
BoardMap = Struct.new(:events)
$board_loads = 0
Object.send(:define_method, :load_data) do |path|
  $board_loads += 1
  raise "unexpected #{path}" unless path == "Data/Map228.rvdata2"

  BoardMap.new({ overview::BOARD_EVENT => BoardEvent.new([BoardPage.new(board)]) })
end
class Game_Interpreter
  def actor_class_level_over?(actor, job, level); $class_levels && [actor, job, level] == [1, 151, 10]; end
end
overview.instance_variable_set(:@board_list, nil)
$data_items = []
$data_items[151] = :iron_ore
$held_items = []
$class_levels = true
def $game_party.has_item?(item); $held_items.include?(item); end
$data_common_events = []
$data_common_events[overview::OBJECTIVE_EVENT] = ObjectiveEvent.new(main)
$data_common_events[131] = ObjectiveEvent.new(sides)
$data_common_events[135] = ObjectiveEvent.new([mark.call(0)] + message.call(0, "\\n<Amira>Chaos errands."))
$game_variables[1001] = 10
$game_variables[1004] = 0
$game_variables[1009] = 3
$game_variables[1041] = 0
$game_variables[1143] = 0
[2018, 2040].each { |id| $game_switches[id] = false }
[6, 1056, 1060].each { |id| $game_switches[id] = true }
check("the main quest is every message of Amira's objective, her side quests left out",
      overview.main_quest.to_a, [:main, "Amira", ["Cross the mountains.", "Buy golden equipment."], nil, nil])
check("and Amira's lists of side quests never count as the main quest, so a step without one of its own has none", ($game_variables[1001] = 12; overview.main_quest), nil)
$game_variables[1001] = 10
texts = lambda { |quests| quests.map { |quest| quest.texts.join(" ") } }
check("the side quests are the entries Amira tells now, each in her words alone, her network counting",
      texts.call(overview.side_quests), ["Strange crying near Iliasville.", "A troublesome job. Go to the slums.", "Iron ore in the Pornof mines.", "The engineer wants makina."])
check("each numbered, each message kept apart", overview.side_quests[1].to_a, [:side, "Amira", ["A troublesome job.", "Go to the slums."], 2, nil])
$held_items = [:iron_ore]
$game_variables[1009] = 2
check("an item held or a network not yet grown leaves its entry out", texts.call(overview.side_quests), ["Strange crying near Iliasville.", "A troublesome job. Go to the slums."])
$game_variables[1143] = 21
check("from the Chaos route's step 21 Amira's second list counts", texts.call(overview.side_quests), ["Chaos errands."])
$game_variables[1143] = 0
check("the companion quests are the board's entries by their companion, a check of the game's own counting and any other script not",
      overview.companion_quests.map { |quest| [quest.kind, quest.speaker, quest.texts, quest.number] },
      [[:companion, "Rami", ["Take me to Harpy Village♪"], nil], [:companion, "Kamuro", ["Homework."], nil], [:companion, "ポチ", ["犬に会いたい"], nil]])
overview.companion_quests
check("the board's map is read once a session", $board_loads, 1)
LooksActor = Struct.new(:id, :name, :character_name, :character_index, :face_name, :face_index)
$data_actors = [nil, LooksActor.new(1, "Luka", "Main01_cip", 0, "luka_fc", 0), LooksActor.new(56, "Rami", "Evil01_cip", 5, "rami_fc", 1),
                LooksActor.new(57, "Rami", "Evil02_cip", 2, "rami_fc", 2), LooksActor.new(103, "Kamuro", "", 0, "kamuro_fc", 0),
                LooksActor.new(104, "Kamuro", "Beast03_cip", 7, "kamuro_fc", 3)]
overview.instance_variable_set(:@looks_by_name, nil)
party_members = $game_party.all_members
$game_party.all_members = [LooksActor.new(57, "Rami", "Evil02_cip", 2, "rami_fc", 2)]
check("a companion quest knows how its companion looks: the party's of that name first, else the first with a map sprite, none for a name without a character",
      [overview.looks_of("Rami").to_a, overview.looks_of("Kamuro").to_a, overview.looks_of("ポチ"), overview.looks_of(nil)],
      [["Evil02_cip", 2, "rami_fc", 2], ["Beast03_cip", 7, "kamuro_fc", 3], nil, nil])
$game_party.all_members = []
check("without one in the party the game's first of that name", overview.looks_of("Rami").to_a, ["Evil01_cip", 5, "rami_fc", 1])
$game_party.all_members = party_members
check("the side quests and the main quest have no portrait of their own", [overview.side_quests[0].looks, overview.main_quest.looks], [nil, nil])
check("the portraits are sprites until the player picks faces, which Player.ini keeps",
      [overview.portraits, (overview.choose_portraits("Faces"); overview.portraits), $player_ini["quest_portraits"], (overview.choose_portraits("Bogus"); overview.portraits)],
      ["Sprites", "Faces", "Faces", "Sprites"])
check("a quest shows its first sentence, past abbreviations, Japanese too, and the whole text without an end",
      ["Head south. Then east.", "Climb Mt. Saint Amos. Then rest.", "Wait... what? No.", "犬に会いたい。猫も。", "No end here"].map { |text| overview.first_sentence(text) },
      ["Head south.", "Climb Mt. Saint Amos.", "Wait...", "犬に会いたい。", "No end here"])
check("the reading pane titles a quest with its kind and who tells it", [overview.main_quest.title, overview.side_quests[1].title, overview.companion_quests[0].title],
      ["Main quest · Amira", "Side quest 2 · Amira", "Request · Rami"])
$frame = $frame.to_i + overview::READ_FRAMES
data = overview.model(:quests)
check("the list heads the side and companion quests with how many each holds, the main quest first among those to pick",
      [data.rows.map { |kind, value| kind == :entry ? [kind, value.first] : [kind, value.title] }, data.picks.map { |pick| pick.is_a?(overview::Fold) ? pick.title : pick.first }],
      [[[:fold, "Side quests (2)"], [:entry, "Strange crying near Iliasville."], [:entry, "A troublesome job."],
        [:fold, "Companion quests (3)"], [:entry, "Take me to Harpy Village♪"], [:entry, "Homework."], [:entry, "犬に会いたい"]],
       ["Cross the mountains.", "Side quests (2)", "Strange crying near Iliasville.", "A troublesome job.", "Companion quests (3)", "Take me to Harpy Village♪", "Homework.", "犬に会いたい"]])
check("a quest's row in the list, none for the main quest at the top", [0, 2, 3, 5].map { |pick| Sprite_MpWorldOverview.entry_row(data, pick) }, [nil, 1, 2, 4])
check("the head holds Amira with the main quest's first sentence", [data.head.title, data.head.lines, data.head.entry.equal?(data.picks.first)], ["Main quest", ["Cross the mountains."], true])

# Picking a quest and reading it.
$raid = true
overview.turn_to(:quests, "the test")
overview.on_map
check("the Quests page opens on the main quest", [overview.page, overview.view[:pick]], [:quests, 0])
$buttons << :DOWN
overview.on_map
$buttons << :DOWN
overview.on_map
check("Down picks the group, then its first quest", overview.view[:pick], 2)
$buttons << :UP
overview.on_map
$buttons << :UP
overview.on_map
$buttons << :UP
overview.on_map
check("and Up past the first comes round to the last", overview.view[:pick], 7)
quest_box = Sprite_MpWorldOverview.box
layout = Sprite_MpWorldOverview.split_layout(quest_box.width, quest_box.height)
$mouse = [quest_box.x + Sprite_MpWorldOverview::MARGIN + 20, quest_box.y + layout[:body_y] + 2 * Sprite_MpWorldOverview::ROW + 5]
$click = true
overview.on_map
check("a click on a quest in the list picks it", overview.view[:pick], 3)
$mouse = [quest_box.x + layout[:text_x] + 20, quest_box.y + layout[:head_y] + 10]
$click = true
overview.on_map
check("and a click on the main quest at the top picks that", overview.view[:pick], 0)
$mouse = nil
quest_drawing = Sprite_MpWorldOverview.allocate
quest_drawing.bitmap = Bitmap.new(quest_box.width, quest_box.height)
quest_drawing.draw(overview.view)
check("the page draws the main quest's first sentence at the top, the list's first sentences cut to their room, and the picked quest's whole text",
      ["Main quest", "Cross the mountains.", "▾ Side quests (2)", "Strange crying near Iliasville.", "Rami", "Take me to Harpy Village♪", "Main quest · Amira", "Buy golden equipment."]
        .map { |text| quest_drawing.bitmap.texts.any? { |drawn| drawn.to_s.start_with?(text[0, 12]) } }, [true] * 8)
$portraits_drawn = []
$portrait_fills = []
class Sprite_MpLeaderHud < Sprite
  def self.draw_figure(_bitmap, name, index, x, y, side, fill); $portraits_drawn << [:sprite, name, index, x, y, side]; $portrait_fills << fill; end
  def self.draw_face(_bitmap, name, index, x, y, side, fill); $portraits_drawn << [:face, name, index, x, y, side]; $portrait_fills << fill; end
end
$data_actors[540] = LooksActor.new(540, "Amira", "Civlian01_cip", 0, "amira_fc1", 0)
$data_actors[56] = LooksActor.new(56, "Rami", "Evil01_cip", 5, "rami_fc", 1)
overview.instance_variable_set(:@looks_by_name, nil)
$frame = $frame.to_i + overview::READ_FRAMES
overview.model(:quests)
overview.pick_entry(:quests, 5)
quest_drawing.bitmap.clear
quest_drawing.draw(overview.view)
pane = Sprite_MpWorldOverview.split_layout(quest_box.width, quest_box.height)
check("Amira shows at the top left and the companion asking for help at the top of the reading pane, as sprites",
      $portraits_drawn, [[:sprite, "Civlian01_cip", 0, Sprite_MpWorldOverview::MARGIN, pane[:head_y], Sprite_MpWorldOverview::PORTRAIT],
                         [:sprite, "Evil01_cip", 5, pane[:pane_x], pane[:body_y], Sprite_MpWorldOverview::PANE_PORTRAIT]])
check("the title stands beside the companion's portrait and the text starts under it",
      [quest_drawing.bitmap.drawn.find { |kind, text| kind == :text && text == "Request · Rami" }[3], Sprite_MpWorldOverview.pane_head(overview.pane_of(overview.view[:model].picks[5]))],
      [pane[:pane_x] + Sprite_MpWorldOverview::PANE_PORTRAIT + Sprite_MpWorldOverview::SPLIT_GAP, Sprite_MpWorldOverview::PANE_PORTRAIT + MGQ_MpUi::Style::GAP])
overview.choose_portraits("Faces")
$portraits_drawn.clear
quest_drawing.draw(overview.view)
check("with faces picked they show by their faces", $portraits_drawn.map { |kind, name, index, _| [kind, name, index] }, [[:face, "amira_fc1", 0], [:face, "rami_fc", 1]])
check("every portrait stands on the box's background", $portrait_fills.all? { |fill| fill.equal?(MGQ_MpUi::Style::BACK) } && $portrait_fills.size == 4, true)
overview.choose_portraits("Sprites")
measured = 0
quest_drawing.bitmap.define_singleton_method(:text_size) { |text| measured += 1; Rect.new(0, 0, text.to_s.size * font.size / 2, font.size) }
Sprite_MpWorldOverview.instance_variable_set(:@fitted, nil)
quest_drawing.draw(overview.view)
first_draw = measured
measured = 0
quest_drawing.draw(overview.view)
check("drawing the page again measures far less, as the fitted texts are kept", measured * 4 < first_draw, true)
$frame = $frame.to_i + overview::READ_FRAMES
kept = overview.model(:quests)
$frame = $frame.to_i + overview::READ_FRAMES
check("the same quests read again stay the same objects", overview.model(:quests).equal?(kept), true)
long = overview::Quest.new(:side, "Amira", ["Word " * 400], 9)
overview.model(:quests).picks << long
overview.pick_entry(:quests, 8)
$buttons << :R
overview.on_map
check("Page Down reads on in a long quest, and Page Up back", [overview.view[:pane_scroll] > 0, ($buttons << :L; overview.on_map; overview.view[:pane_scroll])], [true, 0])
overview.model(:quests).picks.pop
overview.pick_entry(:quests, 0)
[1056, 1060].each { |id| $game_switches[id] = false }
$game_variables[1001] = 12
$game_variables[1004] = 1
$game_switches[2018] = true
$class_levels = false
$frame = $frame.to_i + overview::READ_FRAMES
data = overview.model(:quests)
check("with nothing to tell the main quest is gone and each list says so",
      [data.head.entry, data.head.lines, data.rows.select { |kind, _| kind == :none }.map(&:last), data.picks.map(&:title)],
      [nil, ["None right now."], ["None right now."] * 2, ["Side quests (0)", "Companion quests (0)"]])
data.picks.each { |fold| overview.toggle(:quests, fold) }
check("the quest groups fold too, each to its row alone", overview.model(:quests).rows.map { |kind, value| [kind, value.open] }, [[:fold, false], [:fold, false]])
data.picks.each { |fold| overview.toggle(:quests, fold.tap { |closed| closed.open = false }) }
overview.turn_to(:world, "the test")
quest_sprite = Sprite_MpWorldOverview.allocate
quest_sprite.bitmap = Bitmap.new(560, 404)
quest_sprite.draw_backdrop
check("without Amira's Library picture the page draws none", quest_sprite.bitmap.drawn.none? { |kind, _| kind == :blt }, true)
module NWConst; module Library; ACTOR_IMAGE = { 540 => ["Graphics/Pictures/", "80_amira_st01", 0, 0, -20, 0.9] }; end; end
def Cache.load_bitmap(folder, name); $loaded_picture = [folder, name]; Bitmap.new(640, 480); end
overview.instance_variable_set(:@backdrop_missing, nil)
quest_sprite.draw_backdrop
blt = quest_sprite.bitmap.drawn.find { |kind, _| kind == :blt }
room = 404 - Sprite_MpWorldOverview::LIST_TOP - Sprite_MpWorldOverview::HINT_HEIGHT - Sprite_MpWorldOverview::MARGIN
check("Amira's Library picture shows faintly behind the Quests page, as tall as the room under the tabs, at the right",
      [$loaded_picture, blt && blt[1][0].height, blt && blt[1][0].x + blt[1][0].width, blt && blt[1][3]],
      [["Graphics/Pictures/", "80_amira_st01"], room, 560 - Sprite_MpWorldOverview::MARGIN, overview::BACKDROP_OPACITY])
$frame = $frame.to_i + overview::READ_FRAMES
$data_common_events = nil
objective.call(5)
check("without Amira's event the World page lists no objective", overview.world_model.rows.any? { |kind, entry| kind == :entry && entry.is_a?(overview::Note) }, false)
$world_story = nil
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

# Picking on the World page, the mouse wheel, and the tabs.
overview.on_map
world = overview.view[:model]
$buttons << :DOWN
overview.on_map
check("Down picks the next boss, whose pane shows", [overview.view[:pick], overview.pane_of(world.picks[overview.view[:pick]]).title], [1, world.picks[1].boss.name])
list_rows = Sprite_MpWorldOverview.list_rows_shown
30.times { $buttons << :DOWN; overview.on_map }
row = Sprite_MpWorldOverview.entry_row(world, overview.view[:pick])
check("a pick past the rows in sight scrolls the list so it stays in sight",
      [overview.view[:list_scroll] > 0, row >= overview.view[:list_scroll] && row < overview.view[:list_scroll] + list_rows], [true, true])
wheel_box = Sprite_MpWorldOverview.box
wheel_layout = Sprite_MpWorldOverview.split_layout(wheel_box.width, wheel_box.height)
before = overview.view[:list_scroll]
$mouse = [wheel_box.x + Sprite_MpWorldOverview::MARGIN + 20, wheel_box.y + wheel_layout[:body_y] + 10]
$wheel = 1
overview.on_map
check("the mouse wheel over the list scrolls it, a row a notch", overview.view[:list_scroll], before - 1)
$wheel = -100
overview.on_map
check("never past its end", overview.view[:list_scroll], [world.rows.size - list_rows, 0].max)
$wheel = 0
$mouse = nil
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
      [Sprite_MpWorldOverview.tab_at(box.x + Sprite_MpWorldOverview::MARGIN + Sprite_MpWorldOverview::TAB_WIDTH + 1, tab_y), Sprite_MpWorldOverview.tab_at(box.x + Sprite_MpWorldOverview::MARGIN + 4 * tab_step, tab_y)], [nil, nil])
$mouse = nil

# The picture: the title with the world's type and difficulty before the party, the tabs, the
# hint and a raid boss's row.
sprite = Sprite_MpWorldOverview.allocate
sprite.bitmap = Bitmap.new(box.width, box.height)
sprite.draw(overview.view)
style = MGQ_MpUi::Style
check("the title says the world's type and difficulty after its name, the party at the right, then the tabs",
      sprite.bitmap.texts.first(4), ["Party 2 / 4", "Test World | Raid | Hard", "Players", "World"])
check("the hint names Left and Right, picking, reading on and the numpad's 0", sprite.bitmap.texts.last, "Left or right: page   Up or down: pick   Page Up or Down: read on   Esc, Numpad 0 or F11: close")
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
harpy = MGQ_MpWorldOverview::BossEntry.new(boss_named.call("Queen Harpy"), "Part 1")
sprite.draw_entry_row(overview.row_view(harpy), 0, 0, 300, false)
gauge = sprite.bitmap.drawn.select { |kind, _| kind == :fill }.map { |_, args| args }
check("a raid boss's row: its name, and at the right its share over a thin gauge", sprite.bitmap.texts, ["40%", "Queen Harpy"])
check("the gauge: its frame, its empty part and the share left in the bad color",
      gauge, [[228, 9, 40, 6, style::EDGE], [229, 10, 38, 4, style::WELL], [229, 10, 15, 4, style::BAD]])
check("its pane adds who last hurt it", overview.pane_of(harpy).lines.last, [:text, "Last hurt by Player A."])
sprite.bitmap.clear
sprite.draw_entry_row(overview.row_view(MGQ_MpWorldOverview::BossEntry.new(boss_named.call("Four bandits"), "Part 1")), 0, 0, 300, false)
check("a defeated boss says so in place of its share, dimmed, without a gauge",
      [sprite.bitmap.texts, sprite.bitmap.drawn.select { |kind, _| kind == :text }.last[2].equal?(style::DIM), sprite.bitmap.drawn.count { |kind, _| kind == :fill }],
      [["Defeated", "Four bandits"], true, 0])

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
      [layout.instance_variable_get(:@boxes)[:overview].to_a, [sprite_class::PLAYERS_WIDTH, sprite_class::TABS_WIDTH]],
      [["World overview", 560, 232, :both], [560, 332]])
check("it starts at the list box's place with its lines", [sprite_class.box.to_a, sprite_class.list_rows], [[40, 32, 560, 404], 13])
place_box.call("20,150,600,300")
check("a placement Player.ini keeps is honoured, the lines following its height", [sprite_class.box.to_a, sprite_class.list_rows], [[20, 150, 600, 300], 9])
check("the clicks follow the box: its tabs and inside it where it lies now, not where it starts",
      [sprite_class.tab_at(20 + sprite_class::MARGIN + 10, 150 + sprite_class::TITLE + 5), sprite_class.tab_at(40 + sprite_class::MARGIN + 10, 32 + sprite_class::TITLE + 5),
       sprite_class.inside?(25, 155), sprite_class.inside?(45, 40)], [:players, nil, true, false])
overview.turn_to(:players, "the test")
overview.on_map
check("a line under the mouse is read from the box's top", sprite_class.line_at(100, 150 + sprite_class::LIST_TOP + sprite_class::ROW * 2 + 3, overview.view), overview.view[:scroll] + 2)
place_box.call("0,0,100,50")
check("a placement smaller than the least size grows to it, tall enough for a page's head over three rows", sprite_class.box.to_a, [0, 0, 560, 232])
check("which shows six lines of the Players page", sprite_class.list_rows, 6)
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
check("in a lower box the picked player stays in sight", [view[:selected] >= view[:scroll], view[:selected] < view[:scroll] + sprite_class.list_rows], [true, true])
place_box.call(nil)
overview.on_map
check("and in a taller one no room is left below the last line", overview.view[:scroll], [overview.view[:lines].size - 13, 0].max)
overview.turn_to(:world, "the test")
place_box.call("0,0,560,166")
overview.on_map
40.times { $buttons << :UP; overview.on_map }
low_scroll = overview.view[:list_scroll]
place_box.call(nil)
overview.on_map
rows = overview.view[:model].rows.size
check("the World page's list scrolls further in a lower box, and back within its rows in a taller one",
      [low_scroll > 0, overview.view[:list_scroll] <= [rows - sprite_class.list_rows_shown, 0].max], [true, true])

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
check("the box is framed in the preset's colors, the page shown on the picked tab and the others, the Unlocks page of a Raid World too, on the tab color",
      [fills.first, fills.count { |args| args[4].equal?(style::EDGE) } >= 4, fills.any? { |args| args[4].equal?(style::RIM) }, tab_fills.map { |color| [color.equal?(style::PICKED), color.equal?(style::TAB)] }],
      [[0, 0, 610, 320, style::BACK], true, true, [[false, true], [true, false], [false, true], [false, true]]])
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
overview.on_map
narrow.draw(overview.view)
check("narrowest, the World page draws the title, every tab, its head, its list and the whole hint smaller, all inside the box",
      [narrow.bitmap.texts.first(6), narrow.bitmap.texts.include?("Test World"), narrow.bitmap.texts.last, narrow.bitmap.font.size, inside_box.call(narrow.bitmap)],
      [["Party 2 / 4", "Test World | Raid | Hard", "Players", "World", "Quests", "Unlocks"], true,
       "Left or right: page   Up or down: pick   Page Up or Down: read on   Esc, Numpad 0 or F11: close", style::TINY_SIZE, true])
wide = Sprite_MpWorldOverview.allocate
wide.bitmap = Bitmap.new(sprite_class::MIN_WIDTH + 100, sprite_class::MIN_HEIGHT)
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
