#----------------------------------------------------------------
#  world_overview_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Expected the box's switch kept as true or false
#                            - Read the scripts' clock from $frame
#      Paulinchen  2026-11-01: Named the Mod Framework's interface by its own name
#                            - Checked the overview built of the Mod Framework's window, list, page views and menus through its tree
#                            - Read the party box from the Mod Framework's components it builds
#                            - Stood in for the overview's own drawing of portraits
#                            - Stood in for the emote wheel of the Mod Framework
#                            - Checked that the action wheel's hotkey closes the overview
#                            - Answered the lists, the told state and the pages from the DLL's stand-ins in overview_support.rb
#                            - Checked the pick kept on its player, the list going round, and the overview closed by Numpad 0, its hotkey,
#                              a choice that leaves, a message and leaving the map, and opened from the wheel without a menu
#      Paulinchen  2026-10-31: Expected the game's cancel key in the hints and answered the question box through its stand-in
#                            - Kept the boxes' places in the Mod Framework's settings
#                            - Expected the plainer texts the player reads
#      Paulinchen  2026-10-30: Answered the teleports' view and the squad from the party's stand-in
#                            - Kept one check of the story's place
#      Paulinchen  2026-10-28: Read the place in the story by the ids of its switches and variables
#      Paulinchen  2026-10-24: Checked the pages of other mods with their tabs, controls, buttons and mouse
#      Paulinchen  2026-10-23: Checked that the title is asked once
#                            - Named the world's route by the number of its variable
#                            - Answered the confirm box after the frame it opened in, through the stand-in
#                            - Answered the catch-up through the bridge from the golden cases and found the part as the DLL does
#                            - Answered the confirm box after the frame it opened in, through the stand-in
#                            - Played the party's view and checked the party's actions asked of the DLL
#                            - Answered the catch-up through the bridge from the golden cases
#      Paulinchen  2026-10-13: Checked that the Unlocks grid leaves out characters the catch-up does not count
#      Paulinchen  2026-10-12: Checked the World, Quests and Unlocks pages with a head, a list and a pane
#                            - Checked the Quests page and the catch-up experience on the Levels page
#                            - Checked the log of a refused overview hotkey
#                            - Checked the starts of Part 2 and Part 3
#      Paulinchen  2026-10-11: Checked the Levels page of a Raid World
#                            - Checked the level told and kept during a co-op battle
#                            - Checked a Raid World's objective on the World page
#                            - Expected the first and last bosses of Part 2
#                            - Checked the Raid World box listing the party and the others on the map
#                            - Checked the overview as a box the player moves and resizes
#                            - Expected the raid boss gauges and the box in the preset's colors
#                            - Loaded ui_theme.rbx and ui_layout.rbx
#                            - Checked the raid bosses grouped by the story's sections
#                            - Left the map box's size hint out of the texts read
#                            - Read the small party box's left and compared its green with the member color
#                            - Checked the World page
#                            - Checked the confirm box before leaving the party and removing a member
#                            - Stood in for the open world, its difficulty, story and pools, and for pictures
#      Paulinchen  2026-10-10: Expected the teleport to the party's leader in a member's menu
#                            - Named the map box's players outside the party with placeholders
#                            - Named the party member in the checks with a placeholder
#      Paulinchen  2026-10-08: Checked the map box of a Raid World
#                            - Expected the Frontline level of a Raid World
#      Paulinchen  2026-10-07: Measured places with a text measurer and checked the log of a name the game lacks
#                            - Expected no place on an unnamed map, headed Unnamed place
#      Paulinchen  2026-10-06: Checked the overview kept shut by the emote wheel and an empty player menu
#                            - Read the open menu without the dropped reader
#      Paulinchen  2026-10-04: Checked the party box's size hotkey, small rows and setting
#                            - Followed the scripts to their new names
#      Paulinchen  2026-10-03: Followed the choices to the scripts that offer them
#                            - Added a stand-in for duels without PvP battles
#                            - Named the member in the leader's invite
#      Paulinchen  2026-10-02: Opened the overview with the hotkey of mp_keys.rbx
#      Paulinchen  2026-10-01: Created
#
#----------------------------------------------------------------

# Covers the World overview, world_overview.rbx, world_overview_pages.rbx and
# world_overview_mods.rbx, built of the Mod Framework's window, list, page views and menus and
# played through its tree: what the player tells the others, the Players page with its menus, the
# party box and the map box it feeds, the World, Quests and Unlocks pages, the pages of other mods,
# the window the player moves and resizes, and the question box before leaving the party or
# removing a member. The DLL's models answer through the stand-ins of overview_support.rb.
require_relative "hud_support"
require_relative "rules_support"
# The open world: its name and seats.
World = Struct.new(:name, :seats)
$world = World.new("Test World", 8)
# Stands in for the world: the one in $world, a Raid World while $raid is set.
module MGQ_MpWorld
  # The difficulties' names, from -2 to 4.
  DIFFICULTY_NAMES = ["VERY EASY", "EASY", "NORMAL", "HARD", "VERY HARD", "HELL", "PARADOX"]
  # Answers the world in $world.
  def self.world; $world; end
  # Answers whether the world is a Raid World, as $raid says.
  def self.raid?; $raid; end
  # Names a difficulty, nil for none.
  def self.difficulty_name(value); value ? DIFFICULTY_NAMES[value + 2] : nil; end
end
# Stands in for the world's difficulty, read from $difficulty.
module MGQ_MpWorldDifficulty; def self.value; $difficulty; end; end
# Stands in for the world's story as the relay told it, in $world_story, kept in a Raid World.
module MGQ_MpWorldStory
  # The part the Great Decision lies in.
  DECISION_PART = "3"
  # The routes' keys in the world's story.
  ROUTES = %w(ad mr chaos)
  # The variables that count each route's progress, in the order of ROUTES.
  ROUTE_VARIABLES = [1141, 1142, 1143]
  # Answers the story in $world_story.
  def self.world; $world_story; end
  # Answers whether the world keeps a story, as a Raid World does.
  def self.active?; $raid; end
  # Reads the part from a story's counters, or finds it from variable 1001 and the routes as the DLL does.
  def self.part_of(counters); counters.key?("part") ? counters["part"] : stand_in_part("p" => counters["p"].to_i, "routes" => ROUTE_VARIABLES.map { |id| counters["r#{id}"].to_i }); end
end
# Stands in for the catch-up: its list of what it hands out by level in $unlocks, and the level it
# counts in $counted_level.
module MGQ_MpWorldCatchup
  # What the catch-up hands out at a level.
  Unlock = Struct.new(:level, :kind, :name, :icon, :got, :due, :id, :gains)
  # Something moving on from a part brings along.
  Gain = Struct.new(:kind, :id, :item_kind, :amount, :name, :icon)
  # Answers the list in $unlocks.
  def self.unlocks; $unlocks; end
  # Answers the level in $counted_level.
  def self.counted_level; $counted_level; end
  # Counts every character but those named in $uncounted.
  def self.counts?(actor); !Array($uncounted).include?(actor.name); end
end
$unlocks = []
$counted_level = nil
$pools = {}
# Stands in for the raid bosses' pools, as the relay told them in $pools.
module MGQ_MpRaidPool
  # A boss's pool: the share left, the most HP, whether defeated, who emptied it and when it held.
  Pool = Struct.new(:left, :max, :defeated, :by, :at)
  # Answers a copy of $pools.
  def self.pools; $pools.dup; end
  # Answers the boss a pool's key names, without the number of its enemy.
  def self.boss_key(key); key.sub(/#\d+\z/, ""); end
  # Answers Sisel's troop, none for any other key.
  def self.troop_of_key(key); key == "Sisel" ? 2016 : nil; end
  # Answers the share left, none once defeated.
  def self.left_now(pool, _now = Time.now); pool.defeated ? 0.0 : pool.left; end
end
load_script "battles_raid_bosses"
# Gives the sprite stand-in what the overview sets and calls.
class Sprite
  attr_accessor :bitmap, :x, :y, :z, :ox, :oy, :opacity, :visible
  # Disposes of the sprite.
  def dispose; @disposed = true; end
  # Answers whether the sprite was disposed.
  def disposed?; @disposed ? true : false; end
end
# A picture that records what it draws, measuring each character at half the font's size.
class Bitmap
  # The picture's font.
  Font = Struct.new(:size, :color, :bold, :outline, :out_color)
  attr_reader :width, :height, :font, :drawn
  # Makes an empty picture with a font of size 24.
  def initialize(width, height); @width = width; @height = height; @font = Font.new(24, nil, false, false, nil); @drawn = []; end
  # Answers the picture's rectangle.
  def rect; Rect.new(0, 0, @width, @height); end
  # Measures a text at half the font's size a character.
  def text_size(text); Rect.new(0, 0, text.to_s.size * @font.size / 2, @font.size); end
  # Records a text with its color, left, width and alignment.
  def draw_text(x, y, width, height, text, align = 0); @drawn << [:text, text, @font.color, x, width, align]; end
  # Records a fill.
  def fill_rect(*args); @drawn << [:fill, args]; end
  # Records a picture drawn on it.
  def stretch_blt(*args); @drawn << [:blt, args]; end
  # Answers a see-through pixel, as an empty sheet has.
  def get_pixel(_x, _y); Color.new(0, 0, 0, 0); end
  # Forgets everything drawn.
  def clear; @drawn.clear; end
  # Disposes of the picture.
  def dispose; @disposed = true; end
  # Answers whether the picture was disposed.
  def disposed?; @disposed ? true : false; end
  # Tells the texts drawn.
  def texts; @drawn.select { |kind, _| kind == :text }.map { |_, text, _| text }; end
end
# A character with a base level, Luka or not.
Actor = Struct.new(:base_level, :luca) do
  # Answers whether the character is Luka.
  def luca?; luca; end
  # Answers Luka, or the character's level as a name.
  def name; luca ? "Luka" : "Lv#{base_level}"; end
  # Answers the levels as a Hash of base, class and race level.
  def level; { :base => base_level, :class => 1, :tribe => 1 }; end
end
# A map's entry in the game's map list, named as in the editor.
MapInfo = Struct.new(:name)
$data_mapinfos = { 5 => MapInfo.new("Ilias Village (editor)") }

# Stands in for the game's cache of the characters' sprites and faces, which the portraits measure.
module Cache
  # Answers a sheet of map sprites.
  def self.character(_name); Bitmap.new(384, 256); end
  # Answers a sheet of faces.
  def self.face(_name); Bitmap.new(384, 384); end
end
# Stands in for duels without PvP battles, which the overview greys out.
module MGQ_MpBattlesDuel
  # Answers a greyed duel choice for every player.
  def self.peer_option(_peer); MGQ_MpActions::Option.new("Duel", nil, "Duels are not available right now."); end
  # Answers that no duel is offered on the player's own row.
  def self.own_options; []; end
  # Answers that no other player challenges the player.
  def self.call_of(_peer); nil; end
end
MGQ_MpActions.offer(MGQ_MpBattlesDuel)
load_script "world_catchup_exp"
load_script "world_overview"
load_script "world_overview_pages"
load_script "world_overview_mods"
# Stands in for the emote wheel, shut until a test opens it with $emotes_open.
module MGQ_MpEmotes; def self.wheel; StandInWheel.new(lambda { $emotes_open }); end; end
load_script "ui_party_box"
rules_bridge = open_rules_bridge
# The scripts' clock, which the checks move with $frame.
clock_from { $frame }
require_relative "overview_support"
answer_overview_models(rules_bridge)
require_relative "party_support"
answer_party(rules_bridge)

overview = MGQ_MpWorldOverview

# What the player tells the others: the DLL asks every three seconds in a world, and the script
# reads the formation's highest level, a Raid World's Frontline's and the place in the story.
check("the wheel's middle is the overview's globe", [MGQ_MpActions.wheel_options[:CENTER].text, MGQ_MpActions.wheel_options[:CENTER].icon], ["World (F11)", 3988])
$game_switches[4] = true
$game_variables[1001] = 39
$game_variables[1141] = 3
check("the progress, the routes and the sides go to the DLL by their ids", overview.story_request,
      { "p" => 39, "routes" => { "chaos" => 0, "destroyer" => 3, "judgment" => 0 }, "sides" => { "ilias" => false, "alice" => true } })

# The formation's highest level and the place the player tells.
$game_party.all_members = [Actor.new(30, true), Actor.new(55, false), Actor.new(99, false)]
$game_party.stand_members = [Actor.new(80, false)]
# Answers the formation: the first two characters.
def $game_party.battle_members; all_members.first(2); end
check("the formation's highest, Luka included, the reserve and waiting ones left out", overview.formation_level, 55)
$game_party.all_members = [Actor.new(60, true), Actor.new(55, false), Actor.new(99, false)]
check("Luka counts like everyone in the formation", overview.formation_level, 60)
$game_party.all_members = [Actor.new(30, true), Actor.new(55, false), Actor.new(99, false)]
check("a map the game names nowhere has no place, never its untranslated name in the editor", overview.place, "")
$game_map.display_name = "Ilias Village"
told = logged_lines { tell_overview_read(rules_bridge); map_frame }
check("the DLL's ask has the script read the level and the story, and what changed is logged", told.grep(/told the others/),
      ["overview: told the others: level nil -> 55, story nil -> \"3:destroyer\""])
MGQ_MpOverworldSync.tick
check("the state tells place, level and story, as the DLL keeps them", MGQ_MpOverworldSync::Me.current.values_at("place", "lv", "progress"), ["Ilias Village", 55, "3:destroyer"])

# The list groups the players by place, the player's own first.
other = { "id" => "other", "name" => "member", "map" => 5, "x" => 30, "y" => 30, "d" => 2, "scene" => "menu", "place" => "Ilias Village", "lv" => 12, "progress" => "1", "ping" => 40 }
friend = { "id" => "friend", "name" => "Friend", "map" => 7, "x" => 1, "y" => 1, "d" => 2, "scene" => "battle", "place" => "Forest", "lv" => 30, "progress" => "2:ilias", "ping" => 250 }
$inbox << entry("seat", 0) << entry("in", 2) << entry("message", 2, told(friend)) << entry("in", 3) << entry("message", 3, told(other))
MGQ_MpOverworldSync.tick
lines = overview.lines(overview.rows)
check("places: the player's first, each with its players, the player first", lines.map { |kind, value| kind == :place ? value : value.name },
      ["Ilias Village", "Me (you)", "member", "Forest", "Friend"])
friend_row = lines[4][1]
check("a player's row", [friend_row.level, friend_row.story, friend_row.ping[0], friend_row.icon], ["Lv 30", "Part 2: Ilias side", "250 ms", 451])

# F11 opens the overview, a framework window, on the Players page; confirm on a player opens their
# menu beside the row, and cancel steps back.
# Tells the overview's window.
window = lambda { overview.window }
# Tells the Players page's list.
players = lambda { overview.instance_variable_get(:@players) }
# Tells the tabs of the pages.
tabs = lambda { overview.instance_variable_get(:@tabs) }
# Tells the page view of a page.
view_of = lambda { |page| overview.instance_variable_get(:@views)[page] }
# Tells the key help as it reads.
help_line = lambda { overview.instance_variable_get(:@help).line }
# Tells events of C#'s tree, then runs a frame.
tell = lambda { |*events| $fake_tree.post(events); tree_frame }
# Tells the headings and the names of the Players page's list.
shown = lambda { players.call.rows.map { |row| row[:heading] || row[:cells][1][:text] } }
# Tells the menu open, each choice with whether it can be taken; nil while none is open.
menu = lambda { (open = Mod_Framework::UI::Menu.current) ? open.instance_variable_get(:@choices).map { |choice| [choice[:text], choice[:enabled]] } : nil }
# Takes a choice of the menu open, or with "refuse" picks a greyed one.
pick = lambda { |index, event| tell.call([Mod_Framework::UI::Menu.current.instance_variable_get(:@list).node, event || "submit", index]) }
# Opens the overview with its hotkey and lets the tree lay it out.
open_overview = lambda { $pressed = 0x7A; overview.on_map; 2.times { tree_frame } }
# Tells the place of a player's row in the list.
row_named = lambda { |name| players.call.rows.index { |row| row[:cells] && row[:cells][1][:text] == name } }
open_overview.call
check("F11 opens the overview, a window that holds the game's buttons", [overview.open?, window.call.open?, Mod_Framework::UI::Capture.on?], [true, true, true])
check("on the Players page, a heading per place and its players, the player's own row picked",
      [overview.page, shown.call, players.call.index], [:players, ["Ilias Village", "Me (you)", "member", "Forest", "Friend"], 1])
friend_cells = players.call.rows[4][:cells]
check("a player's row: what they do, their name, their party, their level, their story and their ping in its color",
      [friend_cells.map { |cell| cell[:icons] || cell[:text] }, friend_cells[5][:color].equal?(Mod_Framework::UI::Style::BAD), friend_cells[5][:align]],
      [[[451], "Friend", "", "Lv 30", "Part 2: Ilias side", "250 ms"], true, :end])
check("the window keeps its place under the overview's id, named World overview while the player arranges it, never smaller than 560 by 232",
      [registered_box(:overview), window.call.at, window.call.size, window.call.movable, window.call.resizable, window.call.close_outside],
      [["World overview", 560, 232, :both], [40, 32], [560, 404], true, true, true])
check("the key help names the page's keys, and closes with the bound cancel keys and the hotkey", help_line.call,
      "Left or right: page  Z: invite, duel or trade  X, Numpad 0 or F11: close")
tell.call([players.call.node, "submit", 4])
check("confirm on a player opens their menu, greying what cannot be taken now", menu.call, [["Invite to party", true], ["Duel", false]])
pick.call(1, "refuse")
check("a greyed choice says why, the menu staying open", [MGQ_MpOverworldSync::Status.lines.last.inspect.include?("Duels are not available right now."), menu.call.size], [true, 2])
$party_answer = party_view("me-p", [], -1, "inviting" => true, "invite_ends" => 900, "targets" => ["friend"])
pick.call(0, nil)
$party_answer = nil
check("a choice taken runs and closes the menu", [$party_calls.last, MGQ_MpCoop::Party.targets, menu.call], [["invite", "friend"], ["friend"], nil])
tell.call([players.call.node, "submit", 4])
check("the menu then says the invite stands", menu.call.first[0], "Invited to party")
tell.call([Mod_Framework::UI::Menu.current.node, "close"])
check("cancel closes the menu, the overview staying open", [menu.call, overview.open?], [nil, true])
tell.call([players.call.node, "submit", 1])
check("the player's own menu stops the invite", menu.call.map(&:first), ["Stop inviting"])
tell.call([Mod_Framework::UI::Menu.current.node, "close"])
reads = 0
rows = overview.method(:rows)
overview.define_singleton_method(:rows) { reads += 1; rows.call }
overview.on_map
overview.define_singleton_method(:rows, rows)
check("a frame reads the players once", reads, 1)
closing = logged_lines { tell.call([window.call.node, "close"]) }
check("cancel closes the overview and gives the buttons back, which the log says",
      [overview.open?, Mod_Framework::UI::Capture.on?, closing.grep(/overview: closed/)], [false, false, ["overview: closed: cancel"]])
open_overview.call
$pressed = MGQ_MpHotkeys.code(:wheel)
closing = logged_lines { overview.on_map }
$pressed = nil
check("the action wheel's hotkey closes the overview, which the log says",
      [overview.open?, closing.grep(/overview: closed/)], [false, ["overview: closed: the action wheel's hotkey"]])

# The emote wheel keeps the overview shut, and a player nothing is offered with gets a menu that
# says so.
$emotes_open = true
$pressed = 0x7A
refused = logged_lines { overview.on_map }
check("the overview stays shut while the emote wheel is open", overview.open?, false)
check("which the log says under the hotkeys", refused.grep(/ignored/),
      ["keys: hotkey F11 (World Overview) ignored: not on a quiet map, or the chat or a wheel is open"])
$mgq_text_input = true
$pressed = 0x7A
typed = logged_lines { overview.on_map }
$mgq_text_input = nil
check("but not while the player types, where a hotkey bound to a letter is what they typed", [overview.open?, typed.grep(/ignored/)], [false, []])
$emotes_open = false
registered = MGQ_MpActions.offers.dup
MGQ_MpActions.offers.clear
check("a player nothing is offered with gets a menu that says so", overview.menu_options(friend_row).map { |option| [option.text, option.run] }, [["Nothing to do", nil]])
MGQ_MpActions.offers.concat(registered)

# An invite from a player elsewhere shows on their row and is accepted from the overview.
$inbox << entry("message", 2, told(friend.merge("party" => "friend-p", "invite" => 1, "invite_to" => "me")))
take_party("me-p", [], -1, "inviting" => true, "invite_ends" => 900, "targets" => ["friend"], "inviters" => [2], "parties" => { "me-p" => [1, -1], "friend-p" => [1, 2] })
MGQ_MpOverworldSync.tick
check("an invite naming the player is accepted from the overview", MGQ_MpCoop::Offers.peer_option(MGQ_MpOverworldSync::Peers.at(2)).text, "Accept party invite")
# Finds the row of the player in a seat on the Players page.
row_at = lambda { |seat| overview.rows.find { |row| row.player != :me && row.player.seat == seat } }
check("and shows on the inviter's row in place of the story", row_at.call(2).call[0], "Invites you to a party")
check("but not on another player's", row_at.call(3).call, nil)
check("outside a party the player's own row is white", [overview.rows.first.member, overview.party_rows], [false, []])

# The Players tab marks the invite in gold while another page shows; the inviter's menu takes it.
open_overview.call
overview.turn_to(:world, "the test")
tree_frame
check("while the World page shows, the Players tab carries a gold mark for the invite waiting there", [overview.page, tabs.call.tab(0).badge], [:world, true])
overview.turn_to(:players, "the test")
check("which goes once the Players page shows", tabs.call.tab(0).badge, false)
tell.call([players.call.node, "submit", row_named.call("Friend")])
check("a click on the inviter's row opens their menu with the invite to accept", menu.call.map(&:first), ["Accept party invite", "Duel"])
$party_answer = party_view("friend-p", [MGQ_MpOverworldSync::Peers.at(2)], 2, "admitted_me" => false)
pick.call(0, nil)
$party_answer = nil
check("a click on a choice takes it", [$party_calls.last, MGQ_MpCoop::Party.id], [["join", 2], "friend-p"])
check("in a party the player's own row is green", overview.rows.first.member, true)
check("the party box lists the party, its leader first, with levels", overview.party_rows.map { |row| [row.name, row.level, row.badge[1]] },
      [["Friend", "Lv 30", true], ["Me", "Lv 55", false]])
check("and where each one is", overview.party_rows.map(&:place), overview.party_rows.map { |row| overview.rows.find { |r| r.name.start_with?(row.name) }.place })

# The party box's size hotkey, whose choice Player.ini keeps.
overview.close
check("the party box starts full", MGQ_MpPartyBox.small?, false)
$pressed = MGQ_MpHotkeys.code(:party_box)
MGQ_MpPartyBox.on_map
check("Tab makes it small, which Player.ini keeps", [MGQ_MpPartyBox.small?, $player_ini["party_box_small"]], [true, true])
MGQ_MpPartyBox.instance_variable_set(:@small, nil)
check("so it is small again after a restart", MGQ_MpPartyBox.small?, true)
party_view = MGQ_MpPartyBox::View.new
# Lists the names of the party box's lines.
listed = lambda { parts_of_kind(party_view.root, Mod_Framework::UI::Grid).map { |line| parts_of_kind(line, Mod_Framework::UI::Label).first.text } }
party_view.refresh(false)
check("small, it lists only the crown, the names and the pings, in a narrower panel at the right edge",
      [party_view.root.children.first.width, parts_of_kind(party_view.root, Mod_Framework::UI::Icon).map(&:icon).count(MGQ_MpOverworld::CROWN_ICON), listed.call,
       texts_of(party_view.root).any? { |text| text.start_with?("Lv") }],
      [MGQ_MpPartyBox::View::SMALL_WIDTH, 1, ["Friend", "Me"], false])
MGQ_MpChat.start_typing
$pressed = MGQ_MpHotkeys.code(:party_box)
MGQ_MpPartyBox.on_map
check("its key does nothing while the player types", MGQ_MpPartyBox.small?, true)
MGQ_MpChat.stop_typing
$pressed = MGQ_MpHotkeys.code(:party_box)
MGQ_MpPartyBox.on_map
check("then makes it full again", [MGQ_MpPartyBox.small?, $player_ini["party_box_small"]], [false, false])

# Places are shortened to fit the party box, measured at 10 pixels a letter in 300 pixels.
ruler = Object.new
ruler.define_singleton_method(:text_size) { |text| Struct.new(:width).new(text.length * 10) }
# Fits a place into 300 pixels.
fit = lambda { |place| overview.fit_place(place, 300, ruler) }
check("a short place stays", fit.call("Iliasville"), "Iliasville")
check("the Pocket Castle takes its short name", fit.call("Pocket Monster Lord's Castle Conference Room"), "Pocket Castle Conference Room")
check("then the part in brackets goes", fit.call("Tartarus (Western Hellgondo Continent)"), "Tartarus")
check("then the name is cut before its floor", fit.call("Alliance of Wisdom Laboratory B2F"), "Alliance of Wisdom Labo... B2F")
check("and a name without a floor is cut at its end", fit.call("A Very Long Place Name Without Any Floor"), "A Very Long Place Name With...")
open_overview.call
closing = logged_lines { tell.call([window.call.node, "close", "outside"]) }
check("a click outside the window closes it", [overview.open?, closing.grep(/overview: closed/)], [false, ["overview: closed: a click outside the box"]])

# The pick stays on its player while the rows change, and goes round at both ends.
open_overview.call
before_move = shown.call
tell.call([players.call.node, "change", row_named.call("member")])
$inbox << entry("message", 3, told(other.merge("map" => 7, "place" => "Forest")))
MGQ_MpOverworldSync.tick
overview.on_map
check("the rows set again with the players in a new order keep the cursor on the same player",
      [before_move, shown.call, players.call.index == row_named.call("member")],
      [["Ilias Village", "Me (you)", "member", "Forest", "Friend"], ["Ilias Village", "Me (you)", "Forest", "Friend", "member"], true])
$inbox << entry("message", 3, told(other))
MGQ_MpOverworldSync.tick
overview.on_map
last_row = players.call.rows.size - 1
tell.call([players.call.node, "change", last_row])
tell.call([players.call.node, "change", 1])
round_trip = [players.call.index]
tell.call([players.call.node, "change", last_row])
check("the Players list goes round at both ends: Down on the last player picks the first and Up goes back to the last",
      [$fake_tree.node_of(players.call)[:props]["round"], round_trip << players.call.index, menu.call], [true, [1, last_row], nil])

# Numpad 0, which C# takes as cancel on every root, closes a player's menu and then the overview.
tell.call([players.call.node, "submit", row_named.call("Friend")])
opened_menu = menu.call ? true : false
tell.call([Mod_Framework::UI::Menu.current.node, "close", "cancel"])
menu_closed = [menu.call, overview.open?]
closing = logged_lines { tell.call([window.call.node, "close", "cancel"]) }
check("Numpad 0 closes the menu first, the overview staying, then the overview",
      [opened_menu, menu_closed, overview.open?, closing.grep(/overview: closed/)], [true, [nil, true], false, ["overview: closed: cancel"]])

# The hotkey closes the open overview.
open_overview.call
closing = logged_lines { $pressed = 0x7A; overview.on_map; tree_frame }
check("the hotkey closes the open overview", [overview.open?, closing.grep(/overview: closed/)], [false, ["overview: closed: its hotkey"]])

# The press of the action wheel's middle opens the overview without opening a player's menu.
$buttons << :C
MGQ_MpActions.wheel_options[:CENTER].run.call
2.times { tree_frame }
$buttons.clear
check("opening from the action wheel leaves no menu open", [overview.open?, overview.page, menu.call], [true, :players, nil])

# A choice that leaves, such as a teleport, closes the overview.
taken = []
leaving = MGQ_MpActions::Option.new("Teleport to Friend", lambda { taken << :teleport }, nil, nil, true)
friend_now = overview.rows.find { |row| row.name == "Friend" }
closing = logged_lines { overview.choose(leaving, friend_now); tree_frame }
check("a choice that leaves runs and closes the overview", [taken, overview.open?, closing.grep(/overview: closed/)],
      [[:teleport], false, ["overview: closed: the choice leaves it"]])

# An event or a message starting closes the overview, and so does leaving the map.
open_overview.call
$game_message.busy = true
closing = logged_lines { tree_frame }
$game_message.busy = false
check("a message starting closes it", [overview.open?, closing.grep(/overview: closed/)], [false, ["overview: closed: an event, a message or the chat box took over"]])
open_overview.call
map_scene = SceneManager.scene
SceneManager.scene = Scene_Battle.new
closing = logged_lines { overview.tick(true); tree_frame }
SceneManager.scene = map_scene
check("leaving the map closes it", [overview.open?, closing.grep(/overview: closed/)], [false, ["overview: closed: the map was left"]])

# The chat box closes the overview.
open_overview.call
$pressed = 0x54
map_frame
overview.on_map
closing = logged_lines { tree_frame }
check("the chat box closes it", [MGQ_MpChat.typing?, overview.open?, closing.grep(/overview: closed/)],
      [true, false, ["overview: closed: an event, a message or the chat box took over"]])

# Only the party's leader invites and removes.
friend_peer = MGQ_MpOverworldSync::Peers.at(2)
member_peer = MGQ_MpOverworldSync::Peers.at(3)
MGQ_MpCoopTeleport.tick(true)
check("a member may teleport to their leader", MGQ_MpActions.peer_options(friend_peer).map(&:text), ["Teleport to Friend", "Duel"])
check("and may not invite", [MGQ_MpCoop::Offers.peer_option(member_peer).run, MGQ_MpCoop::Offers.peer_option(member_peer).refusal], [nil, "Only the party's leader invites."])
$inbox << entry("message", 3, told(other.merge("party" => "me-p2", "id" => "zz-member")))
# Friend's invite from afar still names the player, who is outside Friend's party now.
take_party("me-p2", [member_peer], -1, "inviters" => [2])
MGQ_MpOverworldSync.tick
check("the leader may remove a member", MGQ_MpCoop::Offers.peer_option(member_peer).text, "Remove from party")

# The Frontline level a Raid World tells, and its map box.
# Answers that the party is out of battle.
def $game_party.in_battle; false; end
# Answers that no story's temporary party plays.
def $game_party.temp_actors_use?; false; end
# Answers no characters, so coop_squad.rbx moves none past four to standby in a Raid World.
def $game_party.actors; []; end
own_order = MGQ_MpCoopSquad.method(:own_order)
MGQ_MpCoopSquad.define_singleton_method(:own_order) { $front }
$front = [Actor.new(40, true), Actor.new(70, false), Actor.new(90, false)]
# Has the DLL ask the script to read the levels and the story, and the state go out.
tell_state = lambda { tell_overview_read(rules_bridge); map_frame; MGQ_MpOverworldSync.tick }
tell_state.call
check("a Classic world tells no Frontline level", [MGQ_MpOverworldSync::Me.current.key?("flv"), MGQ_MpPartyBox.map_box?], [false, false])
$raid = true
MGQ_MpOverworldSync.tick
check("in a Raid World the Frontline level is the one Frontline character's, Luka included", overview.front_level, 40)
own_share = MGQ_MpCoopSquad.method(:own_share)
MGQ_MpCoopSquad.define_singleton_method(:own_share) { [2, 2] }
check("a share of two reads the higher of the first two", overview.front_level, 70)
MGQ_MpCoopSquad.define_singleton_method(:own_share) { nil }
check("without a share it is the first character's", overview.front_level, 40)
MGQ_MpCoopSquad.define_singleton_method(:own_share, own_share)
tell_state.call
check("a Raid World tells it as flv beside lv", MGQ_MpOverworldSync::Me.current.values_at("lv", "flv"), [55, 40])
# Stands in for co-op battles, one running while $coop_battle is set.
module MGQ_MpBattlesCoop; def self.active?; $coop_battle; end; end
$coop_battle = true
$front = [Actor.new(5, true)]
members = $game_party.all_members
$game_party.all_members = [Actor.new(5, true)]
tell_state.call
check("during a co-op battle the DLL keeps the levels read before", MGQ_MpOverworldSync::Me.current.values_at("lv", "flv"), [55, 40])
$game_party.all_members = members
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

sections = MGQ_MpPartyBox.method(:sections)
# Shows the box for the players of the map and the party a check gives, as it reads them.
show_rows = lambda do |party_rows, other_rows|
  MGQ_MpPartyBox.define_singleton_method(:sections) { [party_rows, other_rows] }
  party_view.refresh(false)
end
# Tells the color the box names a player in.
color_of = lambda { |name| part_with_text(party_view.root, name).color }
MGQ_MpPartyBox.instance_variable_set(:@small, false)
show_rows.call([], map_rows)
check("it is titled with how many are on the map, a line each and no place",
      [texts_of(party_view.root).first, listed.call], ["Map 4", ["Me", "member", "loner", "Stranger"]])
check("party members are in their color, the player's own line and the others not", %w[Me member loner Stranger].map { |name| color_of.call(name) }, [:own, :ally, :text, :text])
crowd = map_rows * 3
show_rows.call([], crowd)
check("past ten lines it lists nine and says how many more", [listed.call.size, texts_of(party_view.root).last], [9, "+3 more"])
crowd = map_rows[1..-1] * 4 + map_rows.first(1)
shown, more = MGQ_MpPartyBox.capped(crowd)
check("cut short, it keeps the player's own line in place of the last listed", [shown.size, shown.last.player, shown.count { |row| row.player == :me }, more],
      [9, :me, 1, 4])
MGQ_MpPartyBox.instance_variable_set(:@small, true)
show_rows.call([], map_rows * 3)
check("small, it keeps to ten lines too, the others in plain text", [listed.call.size, texts_of(party_view.root).last, color_of.call("loner")], [9, "+3 more", :text])
MGQ_MpPartyBox.instance_variable_set(:@small, false)
MGQ_MpPartyBox.define_singleton_method(:sections, sections)
party, others = MGQ_MpPartyBox.sections
check("in a party the box lists the party first, with Frontline levels, then the others on the map",
      [party.map { |row| [row.name, row.level] }, others.map(&:name)], [[["Me", "Lv 40"], ["member", "Lv 33"]], ["loner", "Stranger"]])
party_view.refresh(false)
check("shown as the party box, its places below the members, then the map's title and a line for each other player",
      texts_of(party_view.root).last(6), ["Map 2", "loner", "80 ms", "Stranger", "Lv 20", "80 ms"])
party_view.close

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

# Left and Right turn the pages, round at either end.
$buttons.clear
open_overview.call
check("the overview opens on the Players page", overview.page, :players)
tell.call([tabs.call.node, "step", 1])
online = overview.rows.size
world = overview.model(:world)
check("Right turns to the World page, which in a Classic world heads the world's name with its type and difficulty, its players and that each party plays its leader's story",
      [overview.page, world.head.title, world.head.note, world.head.lines, world.rows],
      [:world, "Test World", "Classic | Per player", ["Players online: #{online} / 8", "Each party plays its leader's story."], [[:none, "Raid bosses fight in Raid Worlds."]]])
world_view = view_of.call(:world)
check("its view shows the globe in the head and a dim line in place of raid bosses",
      [world_view.instance_variable_get(:@head_value).values_at(:icon, :title, :note), world_view.list.rows], [[3988, "Test World", "Classic | Per player"], [{ :heading => "Raid bosses fight in Raid Worlds.", :color => :dim }]])
check("a page view's key help names picking and reading on", help_line.call, "Left or right: page  Up or down: pick  Q or W: read on  X, Numpad 0 or F11: close")
tell.call([tabs.call.node, "step", 1])
check("Right turns on to the Quests page, in a Classic world too", overview.page, :quests)
tell.call([tabs.call.node, "step", 1])
check("past the last page it comes round to the first", overview.page, :players)
2.times { tell.call([tabs.call.node, "step", -1]) }
check("and Left turns back", overview.page, :world)

# The world turns into a Raid World with a difficulty and a story.
$raid = true
$difficulty = 1
$world_story = { "part" => "2" }

# The Unlocks page of a Raid World: the catch-up experience at the top, the levels in the list,
# what a level brings in the pane.
unlock = MGQ_MpWorldCatchup::Unlock
gain = MGQ_MpWorldCatchup::Gain
$unlocks = [unlock.new(10, :story, "Part 1", nil, true, false, nil, [gain.new(:item, 5, "i", 1, "Herb", 20)]),
            unlock.new(25, :story, "Part 2", nil, false, true, nil,
                       [gain.new(:key, 615, "i", 1, "Informant Papers", 230), gain.new(:skill, 930, nil, 1, "Hero Slash", 40), gain.new(:item, 7, "i", 3, "Herb", 20)]),
            unlock.new(25, :companion, "Lime", nil, false, true, 54, []),
            unlock.new(40, :makina, "Super Vibro Blade", 183, false, false, 701, [])]
$counted_level = 30
2.times { tell.call([tabs.call.node, "step", 1]) }
unlocks = overview.model(:unlocks)
check("in a Raid World Right turns on past the Quests page to the Unlocks page, headed by the catch-up experience with the level it counts",
      [overview.page, unlocks.head.title, unlocks.head.note, unlocks.head.lines, unlocks.head.grid],
      [:unlocks, "Catch-up EXP", "Your level 30", ["Starts once the world's story raises the level cap."], nil])
check("the DLL folds the levels whose every unlock the player got under Passed, the others follow under Coming up, each naming the unlocks handed by their places",
      unlocks.rows.map { |kind, value| kind == :none ? [kind, value] : value.value },
      [["fold", "passed", "Passed (1)", false], ["fold", "coming", "Coming up (2)", true], ["level", 25, [1, 2], false, true], ["level", 40, [3], false, false]])
check("a level's row tells what it brings and that it is due",
      unlocks.rows[2][1].row.to_a, ["Level 25", "Part 2, Lime", "Due", false, nil])
pane = overview.pane_of(unlocks.rows[2][1])
check("its pane lists key items and unlocks first, then moving on, the companions, the skills, the Makina and the other items, each with its icon or portrait, the note they share once in the title",
      [pane.title, pane.lines.map { |kind, item| item ? [item.name, item.icon, item.note] : kind }],
      ["Level 25 · Due", [["Informant Papers", 230, nil], :gap, ["Moving on from Part 2", nil, nil], :gap, ["Lime", nil, nil], :gap, ["Hero Slash", 40, nil], :gap, ["Herb x3", 20, nil]]])
mixed = overview.level_pane(overview::Level.new(25, [$unlocks[1].dup.tap { |part| part.got = true; part.due = false }, $unlocks[2]], false, true))
check("a level whose unlocks differ keeps each one's note", [mixed.title, mixed.lines.map { |_, item| item && item.note }.compact.uniq], ["Level 25", ["Done", "Due"]])
unlocks_view = view_of.call(:unlocks)
check("its view lists the groups with their marks and the levels under them, each due one saying so",
      unlocks_view.list.rows.map { |row| row.values_at(:label, :text, :right, :indent) },
      [[nil, "▸ Passed (1)", nil, nil], [nil, "▾ Coming up (2)", nil, nil], ["Level 25", "Part 2, Lime", "Due", 8], ["Level 40", "Super Vibro Blade", nil, 8]])
tell.call([unlocks_view.list.node, "change", 2])
shown_pane = unlocks_view.instance_variable_get(:@pane_value)
check("a level picked shows its pane, the things it brings in runs a gap apart",
      [shown_pane[:title], shown_pane[:lines].map { |line| line.is_a?(Hash) ? line[:items].map { |item| [item[:text], item[:icon]] } : line }],
      ["Level 25 · Due", [[["Informant Papers", 230]], :gap, [["Moving on from Part 2", nil]], :gap, [["Lime", nil]], :gap, [["Hero Slash", 40]], :gap, [["Herb x3", 20]]]])
tell.call([unlocks_view.list.node, "submit", 0])
unlocks = overview.model(:unlocks)
check("confirm on Passed opens it, which the DLL keeps", [unlocks.rows.first(2).map { |_, value| value.value[0] == "fold" ? value.value[2] : value.value[1] }, unlocks_view.list.rows.first(2).map { |row| row[:text] }],
      [["Passed (1)", 10], ["▾ Passed (1)", "Part 1"]])
check("a passed level's pane says so, its unlocks dimmed",
      [overview.pane_of(unlocks.rows[1][1]).title, overview.pane_of(unlocks.rows[1][1]).lines.map { |kind, item| item ? [item.name, item.note, item.dim] : kind }],
      ["Level 10, passed", [["Moving on from Part 1", nil, true], :gap, ["Herb", nil, true]]])
tell.call([unlocks_view.list.node, "submit", 0])
check("and confirm folds it again", overview.model(:unlocks).rows.first[1].value[3], false)
tell.call([unlocks_view.list.node, "submit", 1])
check("Coming up folds the same way", overview.model(:unlocks).rows.map { |kind, value| [kind, value.value[2], value.value[3]] }, [[:fold, "Passed (1)", false], [:fold, "Coming up (2)", false]])
tell.call([unlocks_view.list.node, "submit", 1])
$unlocks = []
overview.forget_model(:unlocks)
overview.on_map
check("with nothing unlocked yet it says so", unlocks_view.list.rows, [{ :heading => "Nothing to catch up with yet.", :color => :dim }])
members = $game_party.all_members
$game_party.all_members = [Actor.new(30, true), Actor.new(20, false), Actor.new(99, false)]
$world_story = $world_story.merge("caps" => [10, 40, 65])
overview.forget_model(:unlocks)
overview.on_map
check("once the world's story raised the level cap, the head lists each formation member's level and catch-up experience up to the level it holds",
      [overview.model(:unlocks).head.title, overview.model(:unlocks).head.grid], ["Catch-up EXP until level 40", [["Luka", "Lv 30", "x4"], ["Lv20", "Lv 20", "x7"]]])
check("its view shows them in a grid, the factor in the title color", unlocks_view.instance_variable_get(:@head_value)[:grid],
      [["Luka", "Lv 30", { :text => "x4", :color => :title }], ["Lv20", "Lv 20", { :text => "x7", :color => :title }]])
$uncounted = ["Lv20"]
overview.forget_model(:unlocks)
overview.on_map
check("a character the catch-up does not count, such as a story's temporary party or a companion on a visit, is left out", overview.model(:unlocks).head.grid, [["Luka", "Lv 30", "x4"]])
$uncounted = nil
$game_party.all_members = members
$world_story = $world_story.reject { |key, _| key == "caps" }
$raid = false
overview.on_map
check("a Classic world has no Unlocks page, which turns back to the Players page",
      [overview.page, overview.pages.map(&:first), tabs.call.tab(3).visible?], [:players, [:players, :world, :quests], false])

# The World page of a Raid World: its head, and its raid bosses under the story's sections.
$raid = true
overview.on_map
check("the Unlocks page coming back leaves the page shown", overview.page, :players)
overview.turn_to(:world, "the test")
world = overview.model(:world)
sections = MGQ_MpRaidBosses.sections
check("a Raid World heads its type and difficulty, its players and its story, then lists its raid bosses under a heading per section with how many it holds",
      [world.head.note, world.head.lines, [world.rows.first[0], world.rows.first[1].value[2]]], ["Raid | Hard", ["Players online: #{online} / 8", "Story: Part 2"], [:fold, "Part 1 (#{sections[0][1].size})"]])
# Tells a page's section headings without their counts.
headings = lambda { |model| model.rows.select { |kind, _| kind == :fold }.map { |_, fold| fold.value[2].sub(/ \(\d+\)\z/, "") } }
bosses = world.rows.select { |kind, _| kind == :entry }.map { |_, entry| entry.value }
check("at Part 2 only Part 1 and Part 2 follow, each boss once in the order the story meets them, untouched while the relay told no pool",
      [headings.call(world), bosses.map { |boss| boss[2] }, bosses.first[3, 2], bosses.last[3, 2]],
      [["Part 1", "Part 2"], sections[0][1] + sections[1][1], [false, nil], [false, nil]])
check("a boss's row tells its share left over a gauge, its pane its section, its tier with what it changes and its gauge",
      [world.rows[1][1].row.to_a, overview.pane_of(world.rows[1][1]).to_a],
      [[nil, "Four bandits", "100%", false, 1.0], ["Four bandits", nil, [[:text, "Part 1"], [:text, "Tier 9: enemies have HP x5."], [:gauge, 1.0, "100%"]]]])
check("the sections run in story order, the Chaos route's by the order of the troops, the one-time bosses last",
      [sections.map(&:first), sections[1][1].first, sections[1][1].last(3), sections[2][1].last, sections[5][1].first, sections[5][1].last, sections[6][1].size],
      [["Part 1", "Part 2", "Part 3", "Angelic Dominion", "Monster Realm", "Chaos route", "Chaos Domain"], "Bonnie and Ashel",
       ["Sonya Mazda", "Sonya Mainyu", "Sonya Chaos"], "Great Decision", "Kagetsumugi and her dolls (cap 125)", "Chaos", 6])
check("a boss's section is found by its troop or its name",
      [MGQ_MpRaidBosses.section(838), MGQ_MpRaidBosses.section("1509"), MGQ_MpRaidBosses.section("Tamamo (cap 83)"), MGQ_MpRaidBosses.section(2221), MGQ_MpRaidBosses.section("Chaos Maria"), MGQ_MpRaidBosses.section("Nobody")],
      ["Part 2", "Part 3", "Monster Realm", "Chaos route", "Chaos Domain", nil])
# Tells the section headings the World page shows for a world's story.
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
titles_asked = lambda { rules_bridge.calls.count { |topic, _| topic == "overview.title" } }
before = titles_asked.call
3.times { overview.title_tail }
check("the title is asked once while the type and the difficulty stay", [before > 0, titles_asked.call - before], [true, 0])
$difficulty = nil
check("without a difficulty the type alone", overview.title_tail, " | Raid")
$difficulty = 1
$world_story = { "part" => "mr" }
check("the world's part goes to the DLL, which names a route as the player's own", overview.world_model.head.lines.last, "Story: Part 3: Judgment route")
$world_story = nil
check("before the relay told the story", overview.world_model.head.lines.last, "Story: Not told yet")

# The story's objective is what Amira's event tells when asked for information.
# An event command: its code, indent and parameters.
ObjectiveCommand = Struct.new(:code, :indent, :parameters)
# A common event: its commands.
ObjectiveEvent = Struct.new(:list)
# Makes an event command.
command = lambda { |code, indent, *params| ObjectiveCommand.new(code, indent, params) }
# Makes a message: the command that shows Amira's face, then a command per line.
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
# Tells the main quest's texts at a story progress, nil for none.
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
      [note.value[1], note.row.to_a, overview.pane_of(note).lines],
      ["Objective", ["Objective", "Head to the Tartarus rift south of Iliasville.", nil, false, nil], [[:text, "Head to the Tartarus rift south of Iliasville."]]])

# The Quests page: the main quest, Amira's side quests and the board's companion quests.
# Makes the command that marks where a quest's entry starts.
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
# A page of the board's event: its commands.
BoardPage = Struct.new(:list)
# The board's event: its pages.
BoardEvent = Struct.new(:pages)
# The board's map: its events by id.
BoardMap = Struct.new(:events)
$board_loads = 0
# Stands in for the game's loading of data, which hands out the board's map, counting each load in
# $board_loads.
Object.send(:define_method, :load_data) do |path|
  $board_loads += 1
  raise "unexpected #{path}" unless path == "Data/Map228.rvdata2"

  BoardMap.new({ overview::BOARD_EVENT => BoardEvent.new([BoardPage.new(board)]) })
end
# Stands in for the game's interpreter, whose methods the overview calls for the board's checks.
class Game_Interpreter
  # Answers $class_levels for the board's check of character 1's job 151 at level 10, false for
  # any other.
  def actor_class_level_over?(actor, job, level); $class_levels && [actor, job, level] == [1, 151, 10]; end
end
overview.instance_variable_set(:@board_list, nil)
$data_items = []
$data_items[151] = :iron_ore
$held_items = []
$class_levels = true
# Answers whether the party holds an item, as $held_items lists it.
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
# Tells each quest's texts as one line.
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
# A character of the game's data: its id, name, map sprite and face.
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
$frame = $frame.to_i + overview::READ_FRAMES
data = overview.model(:quests)
check("the quests go to the DLL, whose list heads the side and companion quests with how many each holds, the main quest first among those to pick",
      [data.rows.map { |kind, value| [kind, kind == :entry ? value.row.text : value.value[2]] }, data.picks.map { |pick| pick.kind == "fold" ? pick.value[2] : pick.value[3].first }],
      [[[:fold, "Side quests (2)"], [:entry, "Strange crying near Iliasville."], [:entry, "A troublesome job."],
        [:fold, "Companion quests (3)"], [:entry, "Take me to Harpy Village♪"], [:entry, "Homework."], [:entry, "犬に会いたい"]],
       ["Cross the mountains.", "Side quests (2)", "Strange crying near Iliasville.", "A troublesome job.", "Companion quests (3)", "Take me to Harpy Village♪", "Homework.", "犬に会いたい"]])
check("the head holds Amira with the main quest's first sentence, its pane titled by who tells it", [data.head.title, data.head.lines, data.head.entry.equal?(data.picks.first), overview.pane_of(data.picks.last).title],
      ["Main quest", ["Cross the mountains."], true, "Request · ポチ"])

# The Quests page in its view: Amira at the top with the main quest picked first, the quests in
# their groups, the portraits as the Quest Portraits row picks them, and Amira's Library picture
# faintly behind it.
$raid = true
$data_actors[540] = LooksActor.new(540, "Amira", "Civlian01_cip", 0, "amira_fc1", 0)
$data_actors[56] = LooksActor.new(56, "Rami", "Evil01_cip", 5, "rami_fc", 1)
overview.instance_variable_set(:@looks_by_name, nil)
overview.turn_to(:quests, "the test")
tree_frame
quests = view_of.call(:quests)
head = quests.instance_variable_get(:@head_value)
check("the Quests page heads Amira by her map sprite with the main quest's first sentence, picked first with the whole quest in the pane",
      [overview.page, head[:title], head[:lines], head[:figure].to_a, head[:pick], quests.instance_variable_get(:@pane_value)[:lines]],
      [:quests, "Main quest", ["Cross the mountains."], ["Civlian01_cip", 0, "amira_fc1", 0], :head, ["Cross the mountains.", :gap, "Buy golden equipment."]])
check("its list holds the groups and under them the quests, numbered or by who asks",
      quests.list.rows.map { |row| row.values_at(:label, :text) },
      [[nil, "▾ Side quests (2)"], ["1.", "Strange crying near Iliasville."], ["2.", "A troublesome job."],
       [nil, "▾ Companion quests (3)"], ["Rami", "Take me to Harpy Village♪"], ["Kamuro", "Homework."], ["ポチ", "犬に会いたい"]])
tell.call([quests.list.node, "change", 4])
pane = quests.instance_variable_get(:@pane_value)
check("a companion's request picked shows in the pane by its title, beside the companion's sprite",
      [pane[:title], pane[:figure].to_a, pane[:lines]], ["Request · Rami", ["Evil01_cip", 5, "rami_fc", 1], ["Take me to Harpy Village♪"]])
overview.choose_portraits("Faces")
overview.on_map
check("with faces picked they show by their faces", [quests.instance_variable_get(:@head_value)[:face].to_a, quests.instance_variable_get(:@pane_value)[:face].to_a],
      [["Civlian01_cip", 0, "amira_fc1", 0], ["Evil01_cip", 5, "rami_fc", 1]])
overview.choose_portraits("Sprites")
check("Amira's Library picture lies faintly behind the page at its bottom right", quests.backdrop,
      { :portrait => overview::AMIRA, :opacity => overview::BACKDROP_OPACITY, :anchor => :bottom_right })
$frame = $frame.to_i + overview::READ_FRAMES
kept = overview.model(:quests)
$frame = $frame.to_i + overview::READ_FRAMES
check("the same quests read again stay the same objects, so the view is not set anew", overview.model(:quests).equal?(kept), true)
[1056, 1060].each { |id| $game_switches[id] = false }
$game_variables[1001] = 12
$game_variables[1004] = 1
$game_switches[2018] = true
$class_levels = false
$frame = $frame.to_i + overview::READ_FRAMES
data = overview.model(:quests)
check("with nothing to tell the main quest is gone and each list says so",
      [data.head.entry, data.head.lines, data.rows.select { |kind, _| kind == :none }.map(&:last), data.picks.map { |pick| pick.value[2] }],
      [nil, ["None right now."], ["None right now."] * 2, ["Side quests (0)", "Companion quests (0)"]])
overview.on_map
check("its view: no pick on the head, a dim line under each group", [quests.instance_variable_get(:@head_value).key?(:pick), quests.list.rows.map { |row| row[:heading] || row[:text] }],
      [false, ["▾ Side quests (0)", "None right now.", "▾ Companion quests (0)", "None right now."]])
tell.call([quests.list.node, "submit", 0])
check("the quest groups fold too, which the DLL keeps", [overview.model(:quests).rows.first[1].value, quests.list.rows.first[:text]],
      [["fold", "side", "Side quests (0)", false], "▸ Side quests (0)"])
tell.call([quests.list.node, "submit", 0])
overview.turn_to(:world, "the test")
$frame = $frame.to_i + overview::READ_FRAMES
$data_common_events = nil
objective.call(5)
check("without Amira's event the World page lists no objective", overview.world_model.rows.any? { |kind, entry| kind == :entry && entry.kind == "note" }, false)
$world_story = nil
$world_story = { "part" => "2" }

# The raid bosses' pools, as the relay tells them, fill in the World page's bosses.
told = Time.at(1_000_000)
pool = MGQ_MpRaidPool::Pool
$pools = { "Queen Harpy" => pool.new(0.4, 6000, false, "Player A", told), "Four bandits" => pool.new(0.0, 6000, true, "Player B", told),
           "Metatronne and Sandalphone#0" => pool.new(0.5, 9000, false, "Player C", told), "Metatronne and Sandalphone#1" => pool.new(1.0, 9000, false, "Player D", told + 1),
           "Fourth Law" => pool.new(0.25, 1, false, "", told), "Sisel" => pool.new(0.9, 1, false, "Player E", told),
           "Unknown Boss" => pool.new(0.5, 1, false, "Player F", told) }
pooled = overview.world_model
# Finds a raid boss of the World page by its name: its section, its row and its pane's lines.
boss_named = lambda do |name|
  entry = pooled.rows.map { |_, value| value }.find { |value| value.is_a?(overview::Entry) && value.kind == "boss" && value.value[2] == name }
  [entry.value[1], entry.row.to_a, overview.pane_of(entry).lines]
end
check("the tables hand the DLL each pooled boss's section and tier, also of a fight's own pool by its troop, and an unknown boss goes under Other last",
      [headings.call(pooled), boss_named.call("Sisel")[0], boss_named.call("Sisel")[2][1], boss_named.call("Unknown Boss")[0]],
      [["Part 1", "Part 2", "Angelic Dominion", "Chaos route", "Chaos Domain", "Other"], "Chaos route", [:text, "Tier 2: enemies have HP x40, DEF x3.67, MDF x3.67."], "Other"])
check("a pool tells a boss's share left and who last hurt it, a boss of several enemies sharing its pools' HP, an empty one defeated",
      [boss_named.call("Queen Harpy")[1], boss_named.call("Queen Harpy")[2].last, boss_named.call("Metatronne and Sandalphone")[1][2], boss_named.call("Four bandits")[1]],
      [[nil, "Queen Harpy", "40%", false, 0.4], [:text, "Last hurt by Player A."], "75%", [nil, "Four bandits", "Defeated", true, nil]])
$world_story = nil
check("before the relay told the story only the sections with a pool show", headings.call(overview.world_model), ["Part 1", "Angelic Dominion", "Chaos route", "Chaos Domain", "Other"])
$world_story = { "part" => "2" }

# The World page in its view: the raid bosses under their sections, each with a thin gauge, a
# boss's pane, the title and the gold mark of a call waiting on the Players page.
overview.forget_model(:world)
overview.on_map
world_view = view_of.call(:world)
harpy_row = world_view.list.rows.find { |row| row[:text] == "Queen Harpy" }
bandits_row = world_view.list.rows.find { |row| row[:text] == "Four bandits" }
check("a raid boss's row: its name, at the right its share over a thin gauge; a defeated one says so, dim, without a gauge",
      [harpy_row.values_at(:right, :right_color, :gauge, :faint, :indent), bandits_row.values_at(:right, :gauge, :faint)],
      [["40%", :dim, 0.4, false, 8], ["Defeated", nil, true]])
tell.call([world_view.list.node, "change", world_view.list.rows.index(harpy_row)])
check("its pane: its section, its tier, a gauge with its share and who last hurt it", world_view.instance_variable_get(:@pane_value),
      { :title => "Queen Harpy", :lines => ["Part 1", "Tier 9: enemies have HP x5.", { :gauge => 0.4, :text => "40%" }, "Last hurt by Player A."] })
labels = [:@name_label, :@tail_label, :@party_label].map { |name| overview.instance_variable_get(name) }
check("the title says the world's name, its type and difficulty after it, and the party at the right; a long name gives way first",
      [labels.map { |label| label.text }, labels[2].visible?, labels.map { |label| label.shrink ? true : false }],
      [["Test World", " | Raid | Hard", "Party 2 / 4"], true, [true, false, false]])
check("the invite from afar still waits on the Players page, which marks its tab in gold while the World page shows", tabs.call.tab(0).badge, true)
$inbox << entry("message", 2, told(friend.merge("party" => "friend-p", "invite" => 0)))
take_party("me-p2", [member_peer])
MGQ_MpOverworldSync.tick
overview.on_map
check("without a call the tab has no mark", tabs.call.tab(0).badge, false)
$pools = {}
$raid = false

# The confirm box before removing a member and leaving the party, which the overview waits for.
confirm = Mod_Framework::UI::Confirm
$frame = 1
member_peer = MGQ_MpOverworldSync::Peers.at(3)
removed = []
remove = MGQ_MpCoop::Party.method(:remove)
MGQ_MpCoop::Party.define_singleton_method(:remove) { |peer| removed << peer.seat }
MGQ_MpCoop::Offers.peer_option(member_peer).run.call
check("removing a member asks first, naming them", [confirm.open?, confirm.instance_variable_get(:@question), confirm.instance_variable_get(:@yes), confirm.instance_variable_get(:@no)],
      [true, "Remove member from the party?", "Remove", "Keep"])
answer_confirm(false)
check("no keeps them", [confirm.open?, removed], [false, []])
MGQ_MpCoop::Offers.peer_option(member_peer).run.call
answer_confirm(true)
check("yes removes them", removed, [3])
MGQ_MpCoop::Party.define_singleton_method(:remove, remove)
overview.turn_to(:players, "the test")
overview.close
open_overview.call
tell.call([players.call.node, "submit", players.call.index])
check("the player's own menu offers to leave", menu.call.first[0], "Leave the party")
pick.call(0, nil)
check("leaving asks first, closing the menu, and the overview stays", [confirm.open?, confirm.instance_variable_get(:@question), menu.call, overview.open?], [true, "Leave the party?", nil, true])
answer_confirm(false)
check("no keeps the party", [confirm.open?, MGQ_MpCoop::Party.id.nil?], [false, false])
leave_option = MGQ_MpCoop::Offers.party_options(true).first
tell.call([players.call.node, "submit", players.call.index])
pick.call(0, nil)
$party_answer = party_view(nil)
answer_confirm(true)
$party_answer = nil
check("yes leaves it through the DLL", [confirm.open?, $party_calls.last, MGQ_MpCoop::Party.id], [false, ["leave", nil], nil])
overview.close
leave_option.run.call
notices = MGQ_MpOverworldSync::Status.lines.size
answer_confirm(true)
check("yes once the party dissolved under the box leaves nothing, so nothing says so", [confirm.open?, MGQ_MpOverworldSync::Status.lines.size], [false, notices])

# Pages of other mods: a mod adds one to ModPages, which shows as a tab while it has something to
# show, laid out like the World page; confirm moves the cursor into the pane, onto its controls and
# the buttons beside its title.

# Stands in for another mod's page: two characters, two controls, a Reset button with a menu of
# one step; the steps and paths taken kept in $mod_adjusted and $mod_chosen.
class TestModPage
  # Whether the page has something to show.
  attr_accessor :shown

  # Its tab's title.
  def title; "Points"; end
  # Whether it shows, as the test sets it.
  def shown?; @shown; end
  # Its head: title, note, lines and portrait.
  def head; ["Job points", "9 points", ["Slots cost points."], ["Granberia_cip", 0, "granberia_fc", 1]]; end
  # One group with both characters.
  def groups; [["Party", [1, 2]]]; end
  # A character's row.
  def row(key); [key == 1 ? "Luka" : "Alice", "Hero / Human", "#{key} free", key == 2]; end
  # A character's pane: looks, a text, two controls, a gap and the points under the name.
  def pane(_key)
    ["Luka", ["Hero_cip", 1, "luka_fc", 2],
     [[:text, "Points per tier."], [:control, :jobs, "Basic jobs", "1/2", :good, false, true], [:control, :races, "Basic races", "1/1", :warn, true, true], [:gap]], "3 of 9 points free"]
  end
  # Records the step; raising the races is refused.
  def adjust(key, id, step); $mod_adjusted << [key, id, step]; id == :races && step > 0 ? "No room." : nil; end
  # The Reset button, then which job to keep, of which one cannot be taken.
  def menu(_key, path)
    case path
    when [] then [["Reset", true]]
    when [0] then [["Keep Hero", true], ["Keep Fighter", false]]
    else []
    end
  end
  # Records the path taken and tells what happened.
  def choose(key, path); $mod_chosen << [key, path]; "Reset Luka."; end
end

$mod_adjusted = []
$mod_chosen = []
mod_page = TestModPage.new
ModPages.add(mod_page)
overview.open("the test")
tree_frame
check("a mod's page with nothing to show has no tab", overview.pages.assoc(:mod_0), nil)
mod_page.shown = true
$frame += 1
check("one with something to show follows the own pages", overview.pages.last, [:mod_0, "Points"])
overview.turn_to(:mod_0, "the test")
tree_frame
points = view_of.call(:mod_0)
mod_tab = tabs.call.tab(overview.instance_variable_get(:@tab_keys).index(:mod_0))
mod_head = points.instance_variable_get(:@head_value)
check("its tab shows, and its page view reads the page: its head with its portrait, its group and each entry's row",
      [[mod_tab.text, mod_tab.visible?], mod_head.values_at(:title, :note, :lines), mod_head[:face].to_a, points.list.rows.map { |row| row.values_at(:label, :text, :right, :faint) }],
      [["Points", true], ["Job points", "9 points", ["Slots cost points."]], ["Granberia_cip", 0, "granberia_fc", 1],
       [[nil, "▾ Party (2)", nil, nil], ["Luka", "Hero / Human", "1 free", false], ["Alice", "Hero / Human", "2 free", true]]])
tell.call([points.list.node, "change", 1])
pane = points.instance_variable_get(:@pane_value)
check("an entry's pane: its title, the line under it, its text, its controls, its gap and its button",
      [pane[:title], pane[:subtitle], pane[:lines], pane[:buttons]],
      ["Luka", "3 of 9 points free", ["Points per tier.", { :control => :jobs, :text => "Basic jobs", :value => "1/2", :color => :good, :less => false, :more => true },
                                      { :control => :races, :text => "Basic races", :value => "1/1", :color => :warn, :less => true, :more => true }, :gap],
       [{ :text => "Reset", :enabled => true }]])
controls = points.instance_variable_get(:@controls)[0]
tell.call([controls.node, "side", 0, 1])
check("Right changes a control through the page", $mod_adjusted.last, [1, :jobs, 1])
tell.call([controls.node, "side", 1, 1])
check("a change the page refuses tells why", [$mod_adjusted.last, MGQ_MpOverworldSync::Status.lines.last.inspect.include?("No room.")], [[1, :races, 1], true])
tell.call([points.instance_variable_get(:@buttons)[0].node, "click"])
check("the button beside the title opens the page's menu, a choice that cannot be taken greyed", menu.call, [["Keep Hero", true], ["Keep Fighter", false]])
pick.call(0, nil)
check("the last choice runs through the page with the whole path, and what the page answers is told",
      [$mod_chosen, menu.call, MGQ_MpOverworldSync::Status.lines.last.inspect.include?("Reset Luka.")], [[[1, [0, 0]]], nil, true])
$fake_tree.post_states({ controls.node => Mod_Framework::UI::Tree::FOCUSED })
tree_frame
overview.on_map
check("in the pane the key help names the keys that go back, the bound cancel keys first", help_line.call,
      "Up or down: pick  Left or right: change  Z: press  X, Numpad 0 or Ctrl: back")
$sounds.clear
$buttons << :CTRL
Mod_Framework::UI::Tree.send(:press_buttons)
check("Ctrl takes the focus back to the list", [$sounds, Mod_Framework::UI::Tree.instance_variable_get(:@focus)], [["cancel"], points.list.node])
tree_frame
mod_page.shown = false
$frame += 1
overview.on_map
check("once it has nothing to show its tab goes and the overview turns back to the Players page", [overview.pages.assoc(:mod_0), overview.page, mod_tab.visible?], [nil, :players, false])
overview.close

# Outside a world the hotkey opens the overview too, as Single player, with the Quests page and
# the pages of other mods.
$open = false
mod_page.shown = true
$frame += 1
$pressed = 0x7A
overview.on_map
check("outside a world the hotkey opens the overview on the Quests page, titled Single player, with the pages of other mods",
      [overview.open?, overview.page, overview.pages, overview.world_name, overview.title_tail],
      [true, :quests, [[:quests, "Quests"], [:mod_0, "Points"]], "Single player", ""])
$pressed = nil
overview.tick(true)
check("a world opening under it closes it", overview.open?, false)
$open = true
mod_page.shown = false
MGQ_MpCoopSquad.define_singleton_method(:own_order, own_order)
