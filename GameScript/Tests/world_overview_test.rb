#----------------------------------------------------------------
#  world_overview_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-08: Checked the quests looked up at the places the DLL's quest walk names, the walk itself left to the C# tests
#                            - Expected the menu beside the players list under its mgq_online_ id
#      Paulinchen  2026-11-07: Read a greyed menu choice from disabled:
#      Paulinchen  2026-11-06: Dropped the check of the picture behind the Quests page
#                            - Expected the DLL to hear that the player chose to leave the party
#                            - Reached the Mod Framework's engine under its own name
#                            - Answered the catch-up's topics with fixed values instead of recorded cases
#                            - Read the small party box's rows, leaving how it looks to the in-game suite
#                            - Read the overview's rows, menus, gate and pages from the script, leaving its window of the UI layer to the in-game suite
#                            - Dropped the pages of other mods, which come through UI.patch now
#                            - Named M as the party box size hotkey in its check
#      Paulinchen  2026-11-05: Answered the teleports' view with a fixed offer instead of from the party's stand-in
#                            - Answered the title with fixed values per world
#                            - Answered the lists, the told state and the pages with the values each check sets and checked what goes to the DLL, instead of what its stand-ins built
#                            - Dropped the check of the sections' order, which the DLL's table of the raid bosses keeps
#                            - Expected the box's switch kept as true or false
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

# Covers the World overview, world_overview.rbx and world_overview_pages.rbx: what the player tells
# the others, the Players page's rows with their menus, the gate that keeps the window open, the
# party box and the map box it feeds, the World, Quests and Unlocks pages' rows, heads and panes,
# and the question box before leaving the party or removing a member. The DLL's models answer with
# the values each check sets (overview_support.rb): the script tests check what goes to them and
# what the overview makes of their answers; how the UI layer draws the window, its tabs and its
# keys is the in-game suite's (33_step9_overview_*.rb).
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
  # Answers the story in $world_story.
  def self.world; $world_story; end
  # Answers whether the world keeps a story, as a Raid World does.
  def self.active?; $raid; end
  # Reads the part a story's counters name.
  def self.part_of(counters); counters["part"]; end
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
# A character with a base level, Luka or not, and their id.
Actor = Struct.new(:base_level, :luca, :id) do
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
# Stands in for story_replay.rbx's codes of the commands the events database keeps: every command
# but a message's lines and a block's end.
module MGQ_MpStoryReplay; def self.kept_code?(code); ![0, 401].include?(code); end; end
# Stands in for coop_events.rbx's asking, which hands the DLL the values it names it needs; this
# DLL names none.
module MGQ_MpCoopEvents; def self.ask(topic, request, _needs); MGQ_Multiplayer::Bridge.call(topic, request.merge("values" => {})); end; end
# Answers the items of the party's bag, as $bag_items lists them.
def $game_party.items; Array($bag_items); end
load_script "world_catchup_exp"
load_script "world_overview"
load_script "world_overview_pages"
# Stands in for the emote wheel, shut until a test opens it with $emotes_open.
module MGQ_MpEmotes; def self.wheel; StandInWheel.new(lambda { $emotes_open }); end; end
load_script "ui_party_box"
rules_bridge = open_rules_bridge
# The title's tail and the World page's note the DLL writes for the worlds below, by whether it is
# a Raid World and its difficulty.
$rule_answers.cases("overview.title", {
  [false, nil] => { "tail" => " | Classic", "note" => "Classic | Per player" }, [false, 1] => { "tail" => " | Classic | Hard", "note" => "Classic | Hard" },
  [true, nil] => { "tail" => " | Raid", "note" => "Raid | Per player" }, [true, 1] => { "tail" => " | Raid | Hard", "note" => "Raid | Hard" },
}) { |request| request.values_at("raid", "difficulty") }
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
$overviews.set("overview.tell", "told the others: level nil -> 55, story nil -> \"3:destroyer\"")
told = logged_lines { tell_overview_read(rules_bridge); map_frame }
$overviews.set("overview.tell")
check("the DLL's ask has the script hand it the level and the story read, and what the DLL says changed is logged",
      [$overviews.asked("overview.tell").last, told.grep(/told the others/)],
      [{ "lv" => 55, "flv" => nil, "story" => overview.story_request, "battle" => false }, ["overview: told the others: level nil -> 55, story nil -> \"3:destroyer\""]])
$overviews.set("overview.fields") { |place| { "place" => place, "lv" => 55, "progress" => "3:destroyer" } }
MGQ_MpOverworldSync.tick
check("the state tells the fields the DLL answers for the place handed", [MGQ_MpOverworldSync::Me.current.values_at("place", "lv", "progress"), $overviews.asked("overview.fields").last],
      [["Ilias Village", 55, "3:destroyer"], "Ilias Village"])

# The lists of players as the DLL builds them (OverviewRowsTests): the player in Ilias Village,
# Friend in Forest, member where a check puts them; in Friend's party once the player joined it.
set_lists = lambda do |member_place, party|
  me = [-1, "Me (you)", "Ilias Village", "Lv 55", "Part 3: Destroyer route", "", "", party, nil]
  friend = [2, "Friend", "Forest", "Lv 30", "Part 2: Ilias side", "250", "battle", party, party ? ["2 / 4", true] : nil]
  member = [3, "member", member_place, "Lv 12", "Part 1", "40", "menu", false, nil]
  lines = if member_place == "Forest" then [["place", "Ilias Village"], ["player", 0], ["place", "Forest"], ["player", 1], ["player", 2]]
          else [["place", "Ilias Village"], ["player", 0], ["player", 2], ["place", "Forest"], ["player", 1]]
          end
  own = [-1, "Me", "Ilias Village", "Lv 55", "Part 3: Destroyer route", "", "", true, ["2 / 4", false]]
  $overviews.lists = { "players" => [me, friend, member], "lines" => lines, "party" => party ? [friend, own] : [] }
end
set_lists.call("Ilias Village", false)

# The Players page lays the players out by place as the DLL lines them up.
other = { "id" => "other", "name" => "member", "map" => 5, "x" => 30, "y" => 30, "d" => 2, "scene" => "menu", "place" => "Ilias Village", "lv" => 12, "progress" => "1", "ping" => 40 }
friend = { "id" => "friend", "name" => "Friend", "map" => 7, "x" => 1, "y" => 1, "d" => 2, "scene" => "battle", "place" => "Forest", "lv" => 30, "progress" => "2:ilias", "ping" => 250 }
$inbox << entry("seat", 0) << entry("in", 2) << entry("message", 2, told(friend)) << entry("in", 3) << entry("message", 3, told(other))
MGQ_MpOverworldSync.tick
lines = overview.lines(overview.rows)
check("the lines the DLL hands, each place with its players, the script asking with the player's name", [lines.map { |kind, value| kind == :place ? value : value.name },
      $overviews.asked("overview.rows").last["name"]], [["Ilias Village", "Me (you)", "member", "Forest", "Friend"], "Me"])
friend_row = lines[4][1]
check("a player's row", [friend_row.level, friend_row.story, friend_row.ping[0], friend_row.icon], ["Lv 30", "Part 2: Ilias side", "250 ms", 451])
check("the script asks again with the serial of the lists it holds, which the DLL answers with nothing while they stay",
      [overview.rows.size, $overviews.asked("overview.rows").last["serial"].nil?, overview.rows.size], [3, false, 3])

# The UI layer's window and menu, as far as the overview's checks need them: UI.open of the overview
# opens it as the window's setup and on_open do once its gate lets it, its close tells why as
# on_close does, and UI.menu keeps its choices, its params and its block in $menu. How the layer
# draws the overview is the in-game suite's (33_step9_overview_*.rb).
class StandInOverview
  # Closes the window, telling the overview why.
  #
  # @param why [Symbol, String] Why.
  def close(why = :script)
    MGQ_MpWorldOverview.closed(why)
  end
end
Mod_Framework::UI.define_singleton_method(:open) do |klass, _params = {}, &_block|
  next nil unless klass == MGQ_MpWorldOverview::WorldOverview && MGQ_MpWorldOverview.open_reason.nil?

  view = StandInOverview.new
  MGQ_MpWorldOverview.start_page
  MGQ_MpWorldOverview.opened(view)
  view
end
$menu = nil
Mod_Framework::UI.define_singleton_method(:menu) { |choices, params = {}, &block| $menu = [choices, params, block]; true }
# Tells the menu open, each choice with whether it can be taken; nil while none is open.
menu = lambda { $menu && $menu[0].map { |choice| [choice[:text], !choice[:disabled]] } }
# Takes a choice of the menu open, or with "refuse" tries a greyed one, which the menu refuses.
pick = lambda do |index, event|
  choices, params, block = $menu
  next params[:on_refuse].call(choices[index], index) if event == "refuse"

  $menu = nil
  block.call(choices[index], index)
end
# Closes the menu open without a choice.
cancel_menu = lambda { block = $menu[2]; $menu = nil; block.call(nil, nil) }
# Opens the overview as its hotkey has the framework do.
open_overview = lambda { Mod_Framework::UI.open(MGQ_MpWorldOverview::WorldOverview) }
# Closes the open overview as its window does, telling why.
close_overview = lambda { |why| overview.instance_variable_get(:@view).close(why) }
# Tells the headings and the names of the Players page's list.
shown = lambda { overview.player_rows.map { |row| row[:heading] || row[:cells][1][:text] } }
# Tells the place of a player's row in the list.
row_named = lambda { |name| overview.player_rows.index { |row| row[:cells] && row[:cells][1][:text] == name } }
# Opens the menu of a row of the Players page, as confirm on it does.
submit = lambda { |index| overview.open_menu(overview.player_rows[index], index) }
opening = logged_lines { open_overview.call }
check("the hotkey opens the overview on the Players page in a world, which the log says with the players online",
      [overview.open?, overview.page, opening.grep(/overview: opened/)], [true, :players, ["overview: opened through its hotkey, 3 player(s) online"]])
check("on the Players page, a heading per place and its players, the player's own row first", shown.call, ["Ilias Village", "Me (you)", "member", "Forest", "Friend"])
friend_cells = overview.player_rows[4][:cells]
check("a player's row: what they do, their name, their party, their level, their story and their ping in its color",
      [friend_cells.map { |cell| cell[:icons] || cell[:text] }, friend_cells[5].values_at(:color, :align)],
      [[[451], "Friend", "", "Lv 30", "Part 2: Ilias side", "250 ms"], [:error, :end]])
submit.call(4)
check("confirm on a player opens their menu beside the row, greying what cannot be taken now with why as its tooltip",
      [menu.call, $menu[0][1][:tooltip], $menu[1].values_at(:beside, :row)],
      [[["Invite to party", true], ["Duel", false]], "Duels are not available right now.", ["#mgq_online_overview_players", 4]])
refusing = logged_lines { pick.call(1, "refuse") }
check("a greyed choice the player tries is logged with why", refusing.grep(/refused/), ["overview: Duel for Friend (seat 2) refused: Duels are not available right now."])
$party_answer = party_view("me-p", [], -1, "inviting" => true, "invite_ends" => 900, "targets" => ["friend"])
pick.call(0, nil)
$party_answer = nil
check("a choice taken runs", [$party_calls.last, MGQ_MpCoop::Party.targets], [["invite", "friend"], ["friend"]])
submit.call(4)
check("the menu then says the invite stands", menu.call.first[0], "Invited to party")
cancel_menu.call
check("closing the menu leaves the overview open", [$menu, overview.open?], [nil, true])
submit.call(1)
check("the player's own menu stops the invite", menu.call.map(&:first), ["Stop inviting"])
cancel_menu.call
closing = logged_lines { close_overview.call(:cancel) }
check("cancel closes the overview, which the log says", [overview.open?, closing.grep(/overview: closed/)], [false, ["overview: closed: cancel"]])
open_overview.call
$pressed = MGQ_MpHotkeys.code(:wheel)
closing = logged_lines { overview.on_map }
$pressed = nil
check("the action wheel's hotkey closes the overview, which the log says",
      [overview.open?, closing.grep(/overview: closed/)], [false, ["overview: closed: the action wheel's hotkey"]])

# The emote wheel keeps the overview shut, and a player nothing is offered with gets a menu that
# says so.
$emotes_open = true
check("the overview stays shut while the emote wheel is open, its gate telling why", [open_overview.call, overview.open?, overview.open_reason], [nil, false, "a wheel is open"])
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

# The Players tab marks the invite while another page shows; the inviter's menu takes it.
open_overview.call
overview.turned(:world)
check("a call waits for the player, which marks the Players tab while the World page shows", [overview.page, overview.call_waiting?], [:world, true])
overview.turned(:players)
submit.call(row_named.call("Friend"))
check("confirm on the inviter's row opens their menu with the invite to accept", menu.call.map(&:first), ["Accept party invite", "Duel"])
$party_answer = party_view("friend-p", [MGQ_MpOverworldSync::Peers.at(2)], 2, "admitted_me" => false)
pick.call(0, nil)
$party_answer = nil
check("taking a choice runs it", [$party_calls.last, MGQ_MpCoop::Party.id], [["join", 2], "friend-p"])
set_lists.call("Ilias Village", true)
check("in a party the player's own row is green, as the DLL marks it", overview.rows.first.member, true)
check("the party box lists the party the DLL lists, with levels and the leader's crown", overview.party_rows.map { |row| [row.name, row.level, row.badge[1]] },
      [["Friend", "Lv 30", true], ["Me", "Lv 55", false]])
check("and where each one is", overview.party_rows.map(&:place), overview.party_rows.map { |row| overview.rows.find { |r| r.name.start_with?(row.name) }.place })

# The party box's size hotkey, whose choice Player.ini keeps.
overview.close("the test")
check("the party box starts full", MGQ_MpPartyBox.small?, false)
$pressed = MGQ_MpHotkeys.code(:party_box)
MGQ_MpPartyBox.on_map
check("M makes it small, which Player.ini keeps", [MGQ_MpPartyBox.small?, $player_ini["party_box_small"]], [true, true])
MGQ_MpPartyBox.instance_variable_set(:@small, nil)
check("so it is small again after a restart", MGQ_MpPartyBox.small?, true)
MGQ_MpPartyBox.read(false)
# Lists each row of the party box: its crown and its texts.
listed = lambda do
  MGQ_MpPartyBox.rows.map do |row|
    cells = row[:cells].reject { |cell| cell == "" }
    cells.select { |cell| cell[:icons] }.map { |cell| cell[:icons] }.flatten.select { |icon| icon == MGQ_MpOverworld::CROWN_ICON } + cells.select { |cell| cell[:text] }.map { |cell| cell[:text] }
  end
end
check("small, it lists only the crown, the names and the pings", listed.call.map { |row| row.reject { |part| part.is_a?(String) && part.end_with?(" ms") } },
      [[MGQ_MpOverworld::CROWN_ICON, "Friend"], ["Me"]])
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
# The action wheel's middle opens the overview, and a choice that leaves closes it.
MGQ_MpActions.wheel_options[:CENTER].run.call
check("the action wheel's middle opens the overview on the Players page, no menu open", [overview.open?, overview.page, $menu], [true, :players, nil])
taken = []
leaving = MGQ_MpActions::Option.new("Teleport to Friend", lambda { taken << :teleport }, nil, nil, true)
friend_now = overview.rows.find { |row| row.name == "Friend" }
closing = logged_lines { overview.choose(leaving, friend_now) }
check("a choice that leaves runs and closes the overview", [taken, overview.open?, closing.grep(/overview: closed/)],
      [[:teleport], false, ["overview: closed: the choice leaves it"]])

# An event, a message or the chat box starting, or leaving the map, has the window's gate close the
# overview, the log naming why.
open_overview.call
$game_message.busy = true
message_reason = overview.open_reason
$game_message.busy = false
map_scene = SceneManager.scene
SceneManager.scene = Scene_Battle.new
scene_reason = overview.open_reason
SceneManager.scene = map_scene
$pressed = 0x54
map_frame
check("a message, leaving the map and the chat box each have the gate answer why",
      [message_reason, scene_reason, MGQ_MpChat.typing?, overview.open_reason],
      ["an event, a message or the chat box took over", "the map was left", true, "an event, a message or the chat box took over"])
closing = logged_lines { close_overview.call(overview.open_reason) }
check("the log names the gate's answer", [overview.open?, closing.grep(/overview: closed/)], [false, ["overview: closed: an event, a message or the chat box took over"]])

# Only the party's leader invites and removes.
friend_peer = MGQ_MpOverworldSync::Peers.at(2)
member_peer = MGQ_MpOverworldSync::Peers.at(3)
$teleport_view = teleport_view(2 => teleport_offer("Teleport to Friend"))
MGQ_MpCoopTeleport.tick(true)
check("a member may teleport to their leader", MGQ_MpActions.peer_options(friend_peer).map(&:text), ["Teleport to Friend", "Duel"])
$teleport_view = nil
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
check("a Classic world tells no Frontline level", [$overviews.asked("overview.tell").last["flv"], MGQ_MpPartyBox.map_box?], [nil, false])
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
check("a Raid World hands the DLL the Frontline level beside the formation's", $overviews.asked("overview.tell").last.values_at("lv", "flv"), [55, 40])
# Stands in for co-op battles, one running while $coop_battle is set.
module MGQ_MpBattlesCoop; def self.active?; $coop_battle; end; end
$coop_battle = true
$front = [Actor.new(5, true)]
members = $game_party.all_members
$game_party.all_members = [Actor.new(5, true)]
tell_state.call
check("during a co-op battle the script tells the DLL so, which keeps the levels read before", $overviews.asked("overview.tell").last.values_at("lv", "flv", "battle"), [5, 5, true])
$game_party.all_members = members
$coop_battle = false
$front = [Actor.new(40, true), Actor.new(70, false), Actor.new(90, false)]

stranger = { "id" => "stranger", "name" => "Stranger", "map" => 5, "x" => 2, "y" => 2, "d" => 2, "scene" => "map", "place" => "Ilias Village", "lv" => 80, "flv" => 20, "progress" => "1", "ping" => 80 }
$inbox << entry("in", 4) << entry("message", 4, told(stranger)) << entry("in", 5) << entry("message", 5, told(stranger.merge("id" => "loner", "name" => "loner", "flv" => 0, "party" => "loner-p", "invite" => 0)))
$inbox << entry("message", 3, told(other.merge("party" => MGQ_MpCoop::Party.id, "id" => "zz-member", "flv" => 33)))
MGQ_MpOverworldSync.tick
# The lists of a Raid World's map as the DLL builds them: the player leads member, loner and
# Stranger stand on the map too.
raid_me = [-1, "Me", "Ilias Village", "Lv 40", "Part 3: Destroyer route", "", "", true, ["2 / 4", true]]
raid_member = [3, "member", "Ilias Village", "Lv 33", "Part 1", "40", "menu", true, ["2 / 4", false]]
map_lists = { "players" => [], "party" => [raid_me.dup.tap { |row| row[3] = "Lv 55" }, raid_member.dup.tap { |row| row[3] = "Lv 12" }], "raid_party" => [raid_me, raid_member],
              "map" => [raid_me, raid_member, [5, "loner", "Ilias Village", "", "Part 1", "80", "map", false, nil], [4, "Stranger", "Ilias Village", "Lv 20", "Part 1", "80", "map", false, nil]] }
$overviews.lists = map_lists
map_rows = overview.map_rows
check("the map box lists the DLL's players on the map, with their party marks and levels",
      map_rows.map { |row| [row.name, row.member, row.level] }, [["Me", true, "Lv 40"], ["member", true, "Lv 33"], ["loner", false, ""], ["Stranger", false, "Lv 20"]])
check("the crown only where the DLL gives the leader's, and every other player's ping", [map_rows.map { |row| row.badge && row.badge[1] }, map_rows[1..-1].map { |row| row.ping && row.ping[0] }],
      [[true, false, nil, nil], ["40 ms", "80 ms", "80 ms"]])
check("the box follows the world's type", MGQ_MpPartyBox.map_box?, true)

sections = MGQ_MpPartyBox.method(:sections)
# Reads the box for the players of the map and the party a check gives, as it reads them.
show_rows = lambda do |party_rows, other_rows|
  MGQ_MpPartyBox.define_singleton_method(:sections) { [party_rows, other_rows] }
  MGQ_MpPartyBox.read(false)
end
# Lists the box's rows: a heading's text, else each text with its color.
rows_of = lambda do
  MGQ_MpPartyBox.rows.map { |row| row[:heading] || row[:cells].select { |cell| cell.is_a?(Hash) && cell[:text] }.map { |cell| [cell[:text], cell[:color]] } }
end
# Lists the names the box shows, each row's first text.
listed = lambda { rows_of.call.reject { |row| row.is_a?(String) }.map { |row| row.first.first } }
# Tells the color the box names a player in.
color_of = lambda { |name| rows_of.call.find { |row| row.is_a?(Array) && row.first.first == name }.first[1] }
MGQ_MpPartyBox.instance_variable_set(:@small, false)
show_rows.call([], map_rows)
check("it is titled with how many are on the map, a row each and no place", [MGQ_MpPartyBox.title, listed.call], ["Map 4", ["Me", "member", "loner", "Stranger"]])
check("party members are in their color, the player's own row and the others not", %w[Me member loner Stranger].map { |name| color_of.call(name) },
      [:mgq_online_own, :mgq_online_member, :text, :text])
crowd = map_rows * 3
show_rows.call([], crowd)
check("past ten rows it lists nine and says how many more", [listed.call.size, listed.call.last], [10, "+3 more"])
crowd = map_rows[1..-1] * 4 + map_rows.first(1)
shown, more = MGQ_MpPartyBox.capped(crowd)
check("cut short, it keeps the player's own row in place of the last listed", [shown.size, shown.last.player, shown.count { |row| row.player == :me }, more],
      [9, :me, 1, 4])
MGQ_MpPartyBox.instance_variable_set(:@small, true)
show_rows.call([], map_rows * 3)
check("small, it keeps to ten rows too, the others in plain text", [listed.call.size, listed.call.last, color_of.call("loner")], [10, "+3 more", :text])
MGQ_MpPartyBox.instance_variable_set(:@small, false)
MGQ_MpPartyBox.define_singleton_method(:sections, sections)
party, others = MGQ_MpPartyBox.sections
check("in a party the box lists the party first, with Frontline levels, then the others on the map",
      [party.map { |row| [row.name, row.level] }, others.map(&:name)], [[["Me", "Lv 40"], ["member", "Lv 33"]], ["loner", "Stranger"]])
MGQ_MpPartyBox.read(false)
check("shown as the party box, its places under the members, then the map's heading and a row for each other player",
      rows_of.call.last(3).map { |row| row.is_a?(String) ? row : row.map { |text, _color| text } }, ["Map 2", ["loner", "", "80 ms"], ["Stranger", "Lv 20", "80 ms"]])

MGQ_MpChat.stop_typing
$pressed = MGQ_MpHotkeys.code(:party_box)
MGQ_MpPartyBox.on_map
check("its key makes it small", MGQ_MpPartyBox.small?, true)
peers_here = MGQ_MpCoop::Scope.method(:peers_here)
MGQ_MpCoop::Scope.define_singleton_method(:peers_here) { [] }
$overviews.lists = map_lists.merge("map" => [])
check("alone on the map the party box still lists the party, and its key works", [overview.map_rows, MGQ_MpPartyBox.busy_reason, MGQ_MpPartyBox.sections.map { |rows| rows.map(&:name) }],
      [[], nil, [["Me", "member"], []]])
in_party = MGQ_MpCoop.method(:in_party?)
MGQ_MpCoop.define_singleton_method(:in_party?) { false }
check("outside a party there is no box then, and its key says why", MGQ_MpPartyBox.busy_reason, "nobody else is on the map")
MGQ_MpCoop.define_singleton_method(:in_party?, in_party)
MGQ_MpCoop::Scope.define_singleton_method(:peers_here, peers_here)
$raid = false
check("back in a Classic world the party box lists the party alone", overview.party_rows.map(&:name), ["Me", "member"])
# The lists once the player leads member's party, Friend outside it.
$overviews.lists = { "players" => [[-1, "Me (you)", "Ilias Village", "Lv 55", "Part 3: Destroyer route", "", "", true, ["2 / 4", true]],
                                   [2, "Friend", "Forest", "Lv 30", "Part 2: Ilias side", "250", "battle", false, nil],
                                   [3, "member", "Ilias Village", "Lv 12", "Part 1", "40", "menu", true, ["2 / 4", false]]],
                     "lines" => [["place", "Ilias Village"], ["player", 0], ["player", 2], ["place", "Forest"], ["player", 1]], "party" => map_lists["party"] }

# The pages as the DLL lays them out (OverviewPagesTests): the head's title, note and lines, the
# rows ([kind, view, entry], see MGQ_MpWorldOverview.model_of) and the places that can be picked.
page_of = lambda { |lines, rows, picks = [], head = {}| { "head" => { "title" => nil, "note" => nil, "lines" => lines, "entry" => nil }.merge(head), "rows" => rows, "picks" => picks } }
$overviews.set("overview.world", page_of.call(["Players online: 3 / 8", "Each party plays its leader's story."], [["none", "Raid bosses fight in Raid Worlds."]]))

# Turning to the World page reads it.
MGQ_MpChat.stop_typing
open_overview.call
overview.turned(:world)
world = overview.model(:world)
check("turning to the World page reads it, headed by the world's name with its type and difficulty, the DLL laying out the rest from the seats and the story the script hands",
      [overview.page, world.head.title, world.head.note, $overviews.asked("overview.world").last.values_at("seats", "story", "main"), world.head.lines, world.rows],
      [:world, "Test World", "Classic | Per player", [8, nil, []], ["Players online: 3 / 8", "Each party plays its leader's story."], [[:none, "Raid bosses fight in Raid Worlds."]]])
check("its head shows the globe, its list a dim line in place of raid bosses", [world.head.icon, world.rows.map { |item| overview.entry_row(item) }],
      [3988, [{ :none => "Raid bosses fight in Raid Worlds." }]])

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
passed_fold = ["fold", [nil, "▸ Passed (1)", nil, false, nil], ["fold", "passed", "Passed (1)", false]]
passed_open = ["fold", [nil, "▾ Passed (1)", nil, false, nil], ["fold", "passed", "Passed (1)", true]]
coming_fold = ["fold", [nil, "▾ Coming up (2)", nil, false, nil], ["fold", "coming", "Coming up (2)", true]]
coming_shut = ["fold", [nil, "▸ Coming up (2)", nil, false, nil], ["fold", "coming", "Coming up (2)", false]]
level_10 = ["entry", ["Level 10", "Part 1", nil, true, nil], ["level", 10, [0], true, false]]
level_25 = ["entry", ["Level 25", "Part 2, Lime", "Due", false, nil], ["level", 25, [1, 2], false, true]]
level_40 = ["entry", ["Level 40", "Super Vibro Blade", nil, false, nil], ["level", 40, [3], false, false]]
unlocks_head = { "title" => "Catch-up EXP", "note" => "Your level 30" }
unlocks_folded = page_of.call(["Starts once the world's story raises the level cap."], [passed_fold, coming_fold, level_25, level_40], [0, 1, 2, 3], unlocks_head)
$overviews.set("overview.unlocks", unlocks_folded)
overview.turned(:unlocks)
unlocks = overview.model(:unlocks)
check("in a Raid World the Unlocks page, the DLL laying it out from the levels the script hands",
      [overview.page, $overviews.asked("overview.unlocks").last, unlocks.head.title, unlocks.head.note, unlocks.head.lines, unlocks.head.grid],
      [:unlocks, { "target" => nil, "level" => 30, "unlocks" => [[10, "Part 1", true, false], [25, "Part 2", false, true], [25, "Lime", false, true], [40, "Super Vibro Blade", false, false]] },
       "Catch-up EXP", "Your level 30", ["Starts once the world's story raises the level cap."], nil])
pane = overview.pane_of(unlocks.rows[2][1])
check("its pane lists key items and unlocks first, then moving on, the companions, the skills, the Makina and the other items, each with its icon or portrait, the note they share once in the title",
      [pane.title, pane.lines.map { |kind, item| item ? [item.name, item.icon, item.note] : kind }],
      ["Level 25 · Due", [["Informant Papers", 230, nil], :gap, ["Moving on from Part 2", nil, nil], :gap, ["Lime", nil, nil], :gap, ["Hero Slash", 40, nil], :gap, ["Herb x3", 20, nil]]])
mixed = overview.level_pane(overview::Level.new(25, [$unlocks[1].dup.tap { |part| part.got = true; part.due = false }, $unlocks[2]], false, true))
check("a level whose unlocks differ keeps each one's note", [mixed.title, mixed.lines.map { |_, item| item && item.note }.compact.uniq], ["Level 25", ["Done", "Due"]])
check("its list holds the groups, whether each is open, and the levels under them, each due one saying so",
      unlocks.rows.map { |item| overview.entry_row(item).values_at(:group, :open, :label, :text, :right) },
      [["passed", false, nil, "Passed (1)", nil], ["coming", true, nil, "Coming up (2)", nil], [nil, nil, "Level 25", "Part 2, Lime", "Due"], [nil, nil, "Level 40", "Super Vibro Blade", nil]])
check("a level picked shows its pane, a group or the head without an entry none",
      [overview.pick_pane(unlocks, unlocks.rows[2]).title, overview.pick_pane(unlocks, unlocks.rows[0]), overview.pick_pane(unlocks, :head)], ["Level 25 · Due", nil, nil])
$overviews.set("overview.unlocks", page_of.call(unlocks_folded["head"]["lines"], [passed_open, level_10, coming_fold, level_25, level_40], [0, 1, 2, 3, 4], unlocks_head))
overview.fold(:unlocks, "passed", true)
unlocks = overview.model(:unlocks)
check("opening Passed has the DLL open it, and the page reads its model anew",
      [$overviews.asked("overview.fold").last, unlocks.rows.first(2).map { |item| overview.entry_row(item)[:text] }], [{ "page" => "unlocks", "key" => "passed", "open" => true }, ["Passed (1)", "Part 1"]])
check("a passed level's pane says so, its unlocks dimmed",
      [overview.pane_of(unlocks.rows[1][1]).title, overview.pane_of(unlocks.rows[1][1]).lines.map { |kind, item| item ? [item.name, item.note, item.dim] : kind }],
      ["Level 10, passed", [["Moving on from Part 1", nil, true], :gap, ["Herb", nil, true]]])
$overviews.set("overview.unlocks", unlocks_folded)
overview.fold(:unlocks, "passed", false)
$overviews.set("overview.unlocks", page_of.call(unlocks_folded["head"]["lines"], [passed_fold, coming_shut], [0, 1], unlocks_head))
overview.fold(:unlocks, "coming", false)
check("folding it again, and Coming up the same way, goes through the DLL",
      [$overviews.asked("overview.fold").last(2), overview.model(:unlocks).rows.map { |item| overview.entry_row(item).values_at(:text, :open) }],
      [[{ "page" => "unlocks", "key" => "passed", "open" => false }, { "page" => "unlocks", "key" => "coming", "open" => false }], [["Passed (1)", false], ["Coming up (2)", false]]])
$unlocks = []
$overviews.set("overview.unlocks", page_of.call(unlocks_folded["head"]["lines"], [["none", "Nothing to catch up with yet."]], [], unlocks_head))
overview.forget_model(:unlocks)
check("with nothing unlocked yet it shows the DLL's line", [overview.model(:unlocks).rows.map { |item| overview.entry_row(item) }, $overviews.asked("overview.unlocks").last["unlocks"]],
      [[{ :none => "Nothing to catch up with yet." }], []])
members = $game_party.all_members
$game_party.all_members = [Actor.new(30, true), Actor.new(20, false), Actor.new(99, false)]
$world_story = $world_story.merge("caps" => [10, 40, 65])
# The DLL's catch-up for the caps above: up to 40, a character of level 30 gaining four times and
# one of level 20 seven times.
rules_bridge.answer("catchup.target") { |_caps| 40 }
rules_bridge.answer("catchup.factor") { |request| request["level"] == 30 ? "x4" : "x7" }
overview.forget_model(:unlocks)
overview.model(:unlocks)
check("once the world's story raised the level cap, the DLL hears the level characters catch up to, and the head lists each formation member's level and catch-up experience",
      [$overviews.asked("overview.unlocks").last["target"], overview.model(:unlocks).head.grid], [40, [["Luka", "Lv 30", "x4"], ["Lv20", "Lv 20", "x7"]]])
$uncounted = ["Lv20"]
overview.forget_model(:unlocks)
check("a character the catch-up does not count, such as a story's temporary party or a companion on a visit, is left out", overview.model(:unlocks).head.grid, [["Luka", "Lv 30", "x4"]])
$uncounted = nil
$game_party.all_members = members
$world_story = $world_story.reject { |key, _| key == "caps" }

# The World page of a Raid World: its head, and its raid bosses under the story's sections.
# A raid boss's row as the DLL lays it out: its share left over a gauge, and its pane's lines.
boss_row = lambda do |section, name, share, parts, defeated, by, tier|
  pane = [["text", section, 0]] + (tier ? [["text", tier, 0]] : []) + [["gauge", share, parts]] + (by ? [["text", "Last hurt by #{by}.", 0]] : [])
  ["entry", [nil, name, share, defeated, defeated ? nil : parts], ["boss", section, name, defeated, by, pane]]
end
bandits = boss_row.call("Part 1", "Four bandits", "100%", 1_000_000, false, nil, "Tier 9: enemies have HP x5.")
$overviews.set("overview.world", page_of.call(["Players online: 3 / 8", "Story: Part 2"], [["fold", [nil, "▾ Part 1 (1)", nil, false, nil], ["fold", "Part 1", "Part 1 (1)", true]], bandits], [0, 1]))
overview.turned(:world)
world = overview.model(:world)
sections = MGQ_MpRaidBosses.sections
asked_world = $overviews.asked("overview.world").last
check("a Raid World's page hands the DLL the world's story, the sections of the raid bosses, each boss's section and tier and each tier's stats, the head noting its type and difficulty",
      [world.head.note, asked_world.values_at("seats", "story"), asked_world["sections"].first[0], asked_world["bosses"]["Four bandits"], asked_world["tiers"].first],
      ["Raid | Hard", [8, { "part" => "2", "done" => [] }], sections.first[0].to_s, ["Part 1", 9], [0, [["mhp", "50.0"], ["def", "5.0"], ["mdf", "5.0"]]]])
check("a boss's row tells its share left over a gauge, its pane the lines the DLL wrote, the gauge's share in whole parts",
      [world.rows[1][1].row.to_a, overview.pane_of(world.rows[1][1]).to_a],
      [[nil, "Four bandits", "100%", false, 1.0], ["Four bandits", nil, [[:text, "Part 1"], [:text, "Tier 9: enemies have HP x5."], [:gauge, 1.0, "100%"]]]])
check("a boss's section is found by its troop or its name",
      [MGQ_MpRaidBosses.section(838), MGQ_MpRaidBosses.section("1509"), MGQ_MpRaidBosses.section("Tamamo (cap 83)"), MGQ_MpRaidBosses.section(2221), MGQ_MpRaidBosses.section("Chaos Maria"), MGQ_MpRaidBosses.section("Nobody")],
      ["Part 2", "Part 3", "Monster Realm", "Chaos route", "Chaos Domain", nil])
# Tells the story the World page hands the DLL for a world's story.
reached = lambda do |story|
  $world_story = story
  overview.world_model
  $overviews.asked("overview.world").last["story"]
end
check("the world's story goes to the DLL with its part and the routes done, none before the relay told it",
      [reached.call("part" => "mr", "done" => ["ad"]), reached.call("part" => "chaos", "done" => [:ad, "mr"]), reached.call(nil)],
      [{ "part" => "mr", "done" => ["ad"] }, { "part" => "chaos", "done" => ["ad", "mr"] }, nil])
$world_story = { "part" => "2" }
check("the title says the type and the difficulty after the world's name", [overview.world_name, overview.title_tail], ["Test World", " | Raid | Hard"])
titles_asked = lambda { rules_bridge.calls.count { |topic, _| topic == "overview.title" } }
before = titles_asked.call
3.times { overview.title_tail }
check("the title is asked once while the type and the difficulty stay", [before > 0, titles_asked.call - before], [true, 0])
$difficulty = nil
check("a changed difficulty asks the DLL again", [overview.title_tail, $rule_answers.asked("overview.title").last], [" | Raid", { "raid" => true, "difficulty" => nil }])
$difficulty = 1
$world_story = nil

# The quests: the DLL walks the game's events (overview.quest_walk; the walk is the C# tests') and
# names each message by its list and its place among the commands the events database keeps, which
# the script looks up in its own game data.
# An event command: its code, indent and parameters.
ObjectiveCommand = Struct.new(:code, :indent, :parameters)
# A common event: its commands.
ObjectiveEvent = Struct.new(:list)
# Makes an event command.
command = lambda { |code, indent, *params| ObjectiveCommand.new(code, indent, params) }
# Makes a message: the command that shows a face, then a command per line.
message = lambda { |indent, *lines| [command.call(101, indent, "amira_fc1", 0, 0, 2)] + lines.map { |line| command.call(401, indent, line) } }
# Kept places: 0 the opening, 1 the branch, 2 Amira's two lines, 3 Luka's, 4 the branch's end.
amira = message.call(0, "\\n<Amira>", "Let's see, your current primary objective is...") + [command.call(111, 0, 1, 1001, 0, 10, 0)] +
        message.call(1, "\\n<Amira>Head to the \\C[17]Tartarus rift\\C[0] south", "of Iliasville.") + message.call(1, "\\n<Luka>A party of \\V[7].") + [command.call(412, 0)]
$data_common_events = []
$data_common_events[108] = ObjectiveEvent.new(amira)
$data_common_events[131] = ObjectiveEvent.new([command.call(122, 0, 11, 11, 0, 0, 1)] + message.call(0, "\\n<Amira>", "Strange crying near Iliasville."))
# A page of the board's event: its commands.
BoardPage = Struct.new(:list)
# The board's event: its pages.
BoardEvent = Struct.new(:pages)
# The board's map: its events by id.
BoardMap = Struct.new(:events)
$board_loads = 0
# Stands in for the game's naming of a map's file.
module DataManager; def self.map_file_name(id); format("Data/Map%03d.rvdata2", id); end; end
# Stands in for the game's loading of data, which hands out the board's map, counting each load in
# $board_loads.
Object.send(:define_method, :load_data) do |path|
  $board_loads += 1
  raise "unexpected #{path}" unless path == "Data/Map228.rvdata2"

  BoardMap.new({ 37 => BoardEvent.new([BoardPage.new([]), BoardPage.new(message.call(0, "【ポチ】", "犬に会いたい"))]) })
end
# A character of the game's data: its id, name, map sprite and face.
LooksActor = Struct.new(:id, :name, :character_name, :character_index, :face_name, :face_index)
# An item of the bag: its id.
BagItem = Struct.new(:id)
members_before_quests = $game_party.all_members
$game_party.all_members = [LooksActor.new(1, "Luka", "Main01_cip", 0, "luka_fc", 0)]
$bag_items = [BagItem.new(151)]
$game_variables[7] = 3
objective_place = lambda { |place| [["ce", 108], place] }
walked = { "main" => [objective_place.call(2), objective_place.call(1), objective_place.call(3), [["ce", 999], 0]],
           "side" => [[[["ce", 131], 1]]], "companion" => [[[["map", 228, 37, 2], 0]]], "board" => ["map", 228, 37, 2] }
$overviews.set("overview.quest_walk", walked)
$world_story = { "part" => "1" }
objective_row = ["entry", ["Objective", "Head to the Tartarus rift.", nil, false, nil], ["note", "Objective", ["Head to the Tartarus rift south of Iliasville.", "Then rest."]]]
$overviews.set("overview.world", page_of.call(["Players online: 3 / 8", "Story: Part 1"], [objective_row], [0]))
note = overview.world_model.rows.first[1]
check("the DLL walks the quests with the party's characters and items",
      $overviews.asked("overview.quest_walk").last, { "party" => [1], "items" => [151], "values" => {} })
check("the World page hands the DLL the objective's messages, each looked up at its place by who says it, plain; a place without a message here is left out",
      $overviews.asked("overview.world").last["main"], [["Amira", "Head to the Tartarus rift south of Iliasville."], ["Luka", "A party of 3."]])
check("the objective's pane lays its texts out a gap apart",
      [note.row.to_a, overview.pane_of(note).to_a],
      [["Objective", "Head to the Tartarus rift.", nil, false, nil], ["Objective", nil, [[:text, "Head to the Tartarus rift south of Iliasville."], [:gap], [:text, "Then rest."]]]])
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
check("the portraits are sprites until the player picks faces, which Player.ini keeps",
      [overview.portraits, (overview.choose_portraits("Faces"); overview.portraits), $player_ini["quest_portraits"], (overview.choose_portraits("Bogus"); overview.portraits)],
      ["Sprites", "Faces", "Faces", "Sprites"])
# A quest's row as the DLL lays it out: its label and first sentence, and the quest.
quest_row = lambda { |kind, label, speaker, texts, number, title| ["entry", [label, texts[0], nil, false, nil], ["quest", kind, speaker, texts, number, title]] }
quests_page = page_of.call(["Cross the mountains."],
                           [["fold", [nil, "▾ Side quests (2)", nil, false, nil], ["fold", "side", "Side quests (2)", true]],
                            quest_row.call("side", "1.", "Amira", ["Strange crying near Iliasville."], 1, "Side quest 1 · Amira"),
                            quest_row.call("side", "2.", "Amira", ["A troublesome job.", "Go to the slums."], 2, "Side quest 2 · Amira"),
                            ["fold", [nil, "▾ Companion quests (3)", nil, false, nil], ["fold", "companion", "Companion quests (3)", true]],
                            quest_row.call("companion", "Rami", "Rami", ["Take me to Harpy Village♪"], nil, "Request · Rami"),
                            quest_row.call("companion", "Kamuro", "Kamuro", ["Homework."], nil, "Request · Kamuro"),
                            quest_row.call("companion", "ポチ", "ポチ", ["犬に会いたい"], nil, "Request · ポチ")],
                           [-1, 0, 1, 2, 3, 4, 5, 6],
                           "title" => "Main quest", "entry" => ["quest", "main", "Amira", ["Cross the mountains.", "Buy golden equipment."], nil, "Main quest · Amira"])
$overviews.set("overview.quests", quests_page)
$frame = $frame.to_i + overview::READ_FRAMES
data = overview.model(:quests)
check("the Quests page hands the DLL each quest's messages as the script looks them up, the board's from the board's page",
      $overviews.asked("overview.quests").last,
      { "main" => [["Amira", "Head to the Tartarus rift south of Iliasville."], ["Luka", "A party of 3."]],
        "side" => [[["Amira", "Strange crying near Iliasville."]]], "companion" => [[["ポチ", "犬に会いたい"]]] })
check("the head holds Amira with the main quest's first sentence, its pane titled by who tells it", [data.head.title, data.head.lines, data.head.entry.equal?(data.picks.first), overview.pane_of(data.picks.last).title],
      ["Main quest", ["Cross the mountains."], true, "Request · ポチ"])

# The Quests page in its view: Amira at the top with the main quest picked first, the quests in
# their groups, the portraits as the Quest Portraits row picks them, and Amira's Library picture
# faintly behind it.
$raid = true
$data_actors[540] = LooksActor.new(540, "Amira", "Civlian01_cip", 0, "amira_fc1", 0)
$data_actors[56] = LooksActor.new(56, "Rami", "Evil01_cip", 5, "rami_fc", 1)
overview.instance_variable_set(:@looks_by_name, nil)
overview.turned(:quests)
quests = overview.model(:quests)
check("the Quests page heads Amira by her map sprite with the main quest's first sentence, the whole quest in the pane of the head",
      [overview.page, quests.head.title, quests.head.lines, overview.picture_of(quests.head.looks).keys, quests.head.looks.to_a, overview.pick_pane(quests, :head).lines],
      [:quests, "Main quest", ["Cross the mountains."], [:figure], ["Civlian01_cip", 0, "amira_fc1", 0], [[:text, "Cross the mountains."], [:gap], [:text, "Buy golden equipment."]]])
check("its list holds the groups and under them the quests, numbered or by who asks",
      quests.rows.map { |item| overview.entry_row(item).values_at(:label, :text) },
      [[nil, "Side quests (2)"], ["1.", "Strange crying near Iliasville."], ["2.", "A troublesome job."],
       [nil, "Companion quests (3)"], ["Rami", "Take me to Harpy Village♪"], ["Kamuro", "Homework."], ["ポチ", "犬に会いたい"]])
pane = overview.pick_pane(quests, quests.rows[4])
check("a companion's request picked shows in the pane by its title, beside the companion's sprite",
      [pane.title, pane.looks.to_a, pane.lines], ["Request · Rami", ["Evil01_cip", 5, "rami_fc", 1], [[:text, "Take me to Harpy Village♪"]]])
overview.choose_portraits("Faces")
check("with faces picked they show by their faces", [overview.picture_of(quests.head.looks).keys, overview.picture_of(pane.looks).keys], [[:face], [:face]])
overview.choose_portraits("Sprites")
$frame = $frame.to_i + overview::READ_FRAMES
kept = overview.model(:quests)
$frame = $frame.to_i + overview::READ_FRAMES
check("the same quests read again stay the same objects, so the view is not set anew", overview.model(:quests).equal?(kept), true)
check("the board's map is read once a session", $board_loads, 1)
$overviews.set("overview.quest_walk", nil)
side_none = ["fold", [nil, "▾ Side quests (0)", nil, false, nil], ["fold", "side", "Side quests (0)", true]]
companion_none = ["fold", [nil, "▾ Companion quests (0)", nil, false, nil], ["fold", "companion", "Companion quests (0)", true]]
$overviews.set("overview.quests", page_of.call(["None right now."], [side_none, ["none", "None right now."], companion_none, ["none", "None right now."]], [0, 2], "title" => "Main quest"))
$frame = $frame.to_i + overview::READ_FRAMES
data = overview.model(:quests)
check("with no quests walked the DLL hears none, and the page has no main quest to pick",
      [$overviews.asked("overview.quests").last, data.head.entry, data.picks.map { |pick| pick.value[2] }],
      [{ "main" => [], "side" => [], "companion" => [] }, nil, ["Side quests (0)", "Companion quests (0)"]])
check("its list: a line under each group", data.rows.map { |item| row = overview.entry_row(item); row[:none] || row[:text] },
      ["Side quests (0)", "None right now.", "Companion quests (0)", "None right now."])
$overviews.set("overview.quests", page_of.call(["None right now."], [["fold", [nil, "▸ Side quests (0)", nil, false, nil], ["fold", "side", "Side quests (0)", false]], companion_none,
                                                                     ["none", "None right now."]], [0, 1], "title" => "Main quest"))
overview.fold(:quests, "side", false)
check("the quest groups fold too, through the DLL", [$overviews.asked("overview.fold").last, overview.entry_row(overview.model(:quests).rows.first)[:open]],
      [{ "page" => "quests", "key" => "side", "open" => false }, false])
overview.turned(:world)
$frame = $frame.to_i + overview::READ_FRAMES
$overviews.set("overview.quest_walk", walked)
$data_common_events = nil
overview.world_model
check("without the game's common events no place holds a message, so the World page hands the DLL none", $overviews.asked("overview.world").last["main"], [])
$overviews.set("overview.quest_walk", nil)
$game_party.all_members = members_before_quests
$bag_items = nil
$world_story = nil
$world_story = { "part" => "2" }

# The raid bosses' pools, as the relay tells them, fill in the World page's bosses.
told = Time.at(1_000_000)
pool = MGQ_MpRaidPool::Pool
$pools = { "Queen Harpy" => pool.new(0.4, 6000, false, "Player A", told), "Four bandits" => pool.new(0.0, 6000, true, "Player B", told),
           "Metatronne and Sandalphone#0" => pool.new(0.5, 9000, false, "Player C", told), "Metatronne and Sandalphone#1" => pool.new(1.0, 9000, false, "Player D", told + 1),
           "Fourth Law" => pool.new(0.25, 1, false, "", told), "Sisel" => pool.new(0.9, 1, false, "Player E", told),
           "Unknown Boss" => pool.new(0.5, 1, false, "Player F", told) }
harpy = boss_row.call("Part 1", "Queen Harpy", "40%", 400_000, false, "Player A", "Tier 9: enemies have HP x5.")
defeated = boss_row.call("Part 1", "Four bandits", "Defeated", 0, true, "Player B", nil)
$overviews.set("overview.world", page_of.call(["Players online: 3 / 8", "Story: Part 2"], [["fold", [nil, "▾ Part 1 (2)", nil, false, nil], ["fold", "Part 1", "Part 1 (2)", true]], defeated, harpy],
                                              [0, 1, 2]))
overview.world_model
bosses = $overviews.asked("overview.world").last["bosses"]
check("the tables hand the DLL each pooled boss's section and tier, also of a fight's own pool by its troop, none for a boss they do not know",
      [bosses["Sisel"], bosses["Metatronne and Sandalphone"], bosses["Unknown Boss"]],
      [["Chaos route", 2], ["Angelic Dominion", 4], [nil, nil]])

# The World page in its view: the raid bosses under their sections, each with a thin gauge, a
# boss's pane, the title and the mark of a call waiting on the Players page.
overview.forget_model(:world)
world = overview.model(:world)
row_of = lambda { |name| world.rows.find { |kind, entry| kind == :entry && entry.row.text == name } }
harpy_row = overview.entry_row(row_of.call("Queen Harpy"))
bandits_row = overview.entry_row(row_of.call("Four bandits"))
check("a raid boss's row: its name, at the right its share over a thin gauge; a defeated one says so, dim, without a gauge",
      [harpy_row.values_at(:right, :right_color, :gauge, :faint), bandits_row.values_at(:right, :gauge, :faint)],
      [["40%", :dim, 0.4, false], ["Defeated", nil, true]])
check("its pane: its section, its tier, a gauge with its share and who last hurt it", overview.pick_pane(world, row_of.call("Queen Harpy")).to_a,
      ["Queen Harpy", nil, [[:text, "Part 1"], [:text, "Tier 9: enemies have HP x5."], [:gauge, 0.4, "40%"], [:text, "Last hurt by Player A."]]])
check("the title says the world's name, its type and difficulty after it, and the party", [overview.world_name, overview.title_tail, overview.party_text],
      ["Test World", " | Raid | Hard", "Party 2 / 4"])
check("the invite from afar still waits on the Players page, which marks its tab while the World page shows", overview.call_waiting?, true)
$inbox << entry("message", 2, told(friend.merge("party" => "friend-p", "invite" => 0)))
take_party("me-p2", [member_peer])
MGQ_MpOverworldSync.tick
check("without a call the tab has no mark", overview.call_waiting?, false)
$pools = {}
$raid = false

# The confirm box before removing a member and leaving the party, which the overview waits for.
confirm = Mod_Framework::UI::Engine::Confirm
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
overview.close("the test")
open_overview.call
submit.call(row_named.call("Me (you)"))
check("the player's own menu offers to leave", menu.call.first[0], "Leave the party")
pick.call(0, nil)
check("leaving asks first, closing the menu, and the overview stays", [confirm.open?, confirm.instance_variable_get(:@question), menu.call, overview.open?], [true, "Leave the party?", nil, true])
answer_confirm(false)
check("no keeps the party", [confirm.open?, MGQ_MpCoop::Party.id.nil?], [false, false])
leave_option = MGQ_MpCoop::Offers.party_options(true).first
submit.call(row_named.call("Me (you)"))
pick.call(0, nil)
$party_answer = party_view(nil)
answer_confirm(true)
$party_answer = nil
check("yes leaves it through the DLL", [confirm.open?, $party_calls.last, MGQ_MpCoop::Party.id], [false, ["leave", "the player chose it"], nil])
overview.close("the test")
leave_option.run.call
notices = MGQ_MpOverworldSync::Status.lines.size
answer_confirm(true)
check("yes once the party dissolved under the box leaves nothing, so nothing says so", [confirm.open?, MGQ_MpOverworldSync::Status.lines.size], [false, notices])

# Outside a world the hotkey opens the overview too, as Single player, on the Quests page.
$open = false
open_overview.call
check("outside a world the hotkey opens the overview on the Quests page, titled Single player",
      [overview.open?, overview.page, overview.world_name, overview.title_tail], [true, :quests, "Single player", ""])
$open = true
check("a world opening under it has the gate close it", overview.open_reason, "a world opened")
close_overview.call(overview.open_reason)
MGQ_MpCoopSquad.define_singleton_method(:own_order, own_order)
