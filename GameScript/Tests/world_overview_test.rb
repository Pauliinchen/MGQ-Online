#----------------------------------------------------------------
#  world_overview_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-08: Checked the map box of a Raid World: its players and order, the Frontline level, its colors, its cap and its key
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
# wheel, the arrows, the menu of a player, the mouse, the places the party box shortens, and the
# map box that replaces the party box in a Raid World.

require_relative "world_support"

# Stand-ins for the mouse, the open world and the game's data.
module MGQ_Multiplayer
  module Mouse
    def self.position; $mouse; end
    def self.clicked?; c = $click; $click = false; c; end
  end
end
module MGQ_MpWorld; def self.world; Struct.new(:name).new("Test World"); end; end
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
other = { "id" => "other", "name" => "bea", "map" => 5, "x" => 30, "y" => 30, "d" => 2, "scene" => "menu", "place" => "Ilias Village", "lv" => 12, "progress" => "1", "ping" => 40 }
friend = { "id" => "friend", "name" => "Friend", "map" => 7, "x" => 1, "y" => 1, "d" => 2, "scene" => "battle", "place" => "Forest", "lv" => 30, "progress" => "2:ilias", "ping" => 250 }
$inbox << entry("seat", 0) << entry("in", 2) << entry("message", 2, told(friend)) << entry("in", 3) << entry("message", 3, told(other))
MGQ_MpOverworldSync.tick
lines = overview.lines(overview.rows)
check("places: the player's first, each with its players, the player first", lines.map { |kind, value| kind == :place ? value : value.name },
      ["Ilias Village", "Me (you)", "bea", "Forest", "Friend"])
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
box = Sprite_MpWorldOverview::BOX
$mouse = [box.x + 100, box.y + Sprite_MpWorldOverview::TITLE + Sprite_MpWorldOverview::ROW * 4 + 5]
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
font = Struct.new(:color, :size, :outline).new
canvas = Object.new
canvas.define_singleton_method(:font) { font }
canvas.define_singleton_method(:clear) {}
canvas.define_singleton_method(:fill_rect) { |*args| drawn << [:fill, args[2]] }
canvas.define_singleton_method(:stretch_blt) { |*_| drawn << [:crown] }
canvas.define_singleton_method(:draw_text) { |_x, _y, _w, _h, text, *_| drawn << [:text, text] }
module Cache; def self.system(_name); nil; end; end
module Graphics; def self.width; 640; end; end
box = Sprite_MpPartyBox.allocate
class << box; attr_accessor :x, :y; end
box.define_singleton_method(:bitmap) { canvas }
box.draw_small(overview.party_rows)
check("small, it lists only the crown, the names and the pings, in a narrower box at the top right",
      [box.x, drawn.first, drawn.select { |kind, _| kind == :crown }.size, drawn.select { |kind, _| kind == :text }.map(&:last).reject { |text| text.end_with?("ms") }],
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
bea = MGQ_MpOverworldSync::Peers.at(3)
check("a member sees their leader in the party", MGQ_MpCoop::Offers.peer_option(friend_peer).text, "In your party")
check("and may not invite", [MGQ_MpCoop::Offers.peer_option(bea).run, MGQ_MpCoop::Offers.peer_option(bea).refusal], [nil, "Only the party's leader invites."])
MGQ_MpCoop::Party.reset
MGQ_MpCoop::Party.invite("zz-bea")
$inbox << entry("message", 3, told(other.merge("party" => MGQ_MpCoop::Party.id, "id" => "zz-bea")))
MGQ_MpOverworldSync.tick
check("the leader may remove a member", MGQ_MpCoop::Offers.peer_option(bea).text, "Remove from party")

# The map box of a Raid World.
module MGQ_MpWorld; def self.raid?; $raid; end; end
own_order = MGQ_MpCoopSquad.method(:own_order)
MGQ_MpCoopSquad.define_singleton_method(:own_order) { $front }
$front = [Actor.new(40, true), Actor.new(70, false), Actor.new(90, false)]
overview.instance_variable_set(:@frames, 0)
overview.tick(true)
check("a Classic world tells no Frontline level", [MGQ_MpOverworldSync::Me.current.key?("flv"), MGQ_MpPartyBox.map_box?], [false, false])
$raid = true
check("in a party the Frontline level is the squad's share, Luka included", overview.front_level, 70)
own_share = MGQ_MpCoopSquad.method(:own_share)
MGQ_MpCoopSquad.define_singleton_method(:own_share) { nil }
check("without a share it is the first character's", overview.front_level, 40)
MGQ_MpCoopSquad.define_singleton_method(:own_share, own_share)
overview.instance_variable_set(:@frames, 0)
overview.tick(true)
check("a Raid World tells it as flv beside lv", MGQ_MpOverworldSync::Me.current.values_at("lv", "flv"), [55, 70])
module MGQ_MpBattlesCoop; def self.active?; $coop_battle; end; end
$coop_battle = true
$front = [Actor.new(5, true)]
check("during a co-op battle it keeps the level read before", overview.front_level, 70)
$coop_battle = false
$front = [Actor.new(40, true), Actor.new(70, false), Actor.new(90, false)]

cleo = { "id" => "cleo", "name" => "Cleo", "map" => 5, "x" => 2, "y" => 2, "d" => 2, "scene" => "map", "place" => "Ilias Village", "lv" => 80, "flv" => 20, "progress" => "1", "ping" => 80 }
$inbox << entry("in", 4) << entry("message", 4, told(cleo)) << entry("in", 5) << entry("message", 5, told(cleo.merge("id" => "anna", "name" => "anna", "flv" => 0, "party" => "anna-p", "invite" => 0)))
$inbox << entry("message", 3, told(other.merge("party" => MGQ_MpCoop::Party.id, "id" => "zz-bea", "flv" => 33)))
MGQ_MpOverworldSync.tick
map_rows = overview.map_rows
check("the map box lists everyone on the map, the party first with its leader, then the others by name",
      map_rows.map { |row| [row.name, row.member, row.level] }, [["Me", true, "Lv 70"], ["bea", true, "Lv 33"], ["anna", false, ""], ["Cleo", false, "Lv 20"]])
check("only the party's leader keeps a crown, and every other player shows their ping", [map_rows.map { |row| row.badge && row.badge[1] }, map_rows[1..-1].map { |row| row.ping && row.ping[0] }],
      [[true, false, nil, nil], ["40 ms", "80 ms", "80 ms"]])
check("the box follows the world's type", MGQ_MpPartyBox.map_box?, true)

drawn = []
font = Struct.new(:color, :size, :outline).new
canvas = Object.new
canvas.define_singleton_method(:font) { font }
canvas.define_singleton_method(:clear) { drawn.clear }
canvas.define_singleton_method(:fill_rect) { |*args| drawn << [:fill, args[2], args[3]] }
canvas.define_singleton_method(:stretch_blt) { |*_| drawn << [:crown] }
canvas.define_singleton_method(:draw_text) { |_x, _y, _w, _h, text, *_| drawn << [:text, text, font.color] }
map_box = Sprite_MpPartyBox.allocate
class << map_box; attr_accessor :x, :y; end
map_box.define_singleton_method(:bitmap) { canvas }
texts = lambda { drawn.select { |kind, _| kind == :text }.map { |_, text, _| text }.reject { |text| text.end_with?("ms") } }
green = lambda { |name| drawn.find { |kind, text, _| kind == :text && text == name }[2].equal?(Sprite_MpWorldOverview::MEMBER_COLOR) }
row_height = Sprite_MpPartyBox::ROW
map_box.draw_map(map_rows)
check("it is titled with how many are on the map, a line each and no place", [texts.call, drawn.first],
      [["Map 4", "Me", "Lv 70", "bea", "Lv 33", "anna", "", "Cleo", "Lv 20"], [:fill, Sprite_MpPartyBox::WIDTH, row_height * 5 + 4]])
check("party members are green, the others not", %w[Me bea anna Cleo].map { |name| green.call(name) }, [true, true, false, false])
crowd = map_rows * 3
map_box.draw_map(crowd)
check("past ten lines it lists nine and says how many more", [texts.call.first, texts.call.size, texts.call.last, drawn.first[2]],
      ["Map 12", 1 + 9 * 2 + 1, "+3 more", row_height * 11 + 4])
map_box.draw_small(crowd, true)
crowd = map_rows[1..-1] * 4 + map_rows.first(1)
shown, more = MGQ_MpPartyBox.capped(crowd)
check("cut short, it keeps the player's own line in place of the last listed", [shown.size, shown.last.player, shown.count { |row| row.player == :me }, more],
      [9, :me, 1, 4])
crowd = map_rows * 3
check("small, it keeps to ten lines too, the others white", [texts.call.size, texts.call.last, green.call("anna"), drawn.first[1..2]],
      [10, "+3 more", false, [Sprite_MpPartyBox::SMALL_WIDTH, row_height * 10 + 4]])

MGQ_MpChat.stop_typing
$pressed = MGQ_MpHotkeys.code(:party_box)
MGQ_MpPartyBox.on_map
check("its key makes it small", MGQ_MpPartyBox.small?, true)
peers_here = MGQ_MpCoop::Scope.method(:peers_here)
MGQ_MpCoop::Scope.define_singleton_method(:peers_here) { [] }
check("alone on the map there is no box, and its key says why", [overview.map_rows, MGQ_MpPartyBox.busy_reason], [[], "nobody else is on the map"])
MGQ_MpCoop::Scope.define_singleton_method(:peers_here, peers_here)
$raid = false
check("back in a Classic world the party box lists the party alone", overview.party_rows.map(&:name), ["Me", "bea"])
MGQ_MpCoopSquad.define_singleton_method(:own_order, own_order)
overview.tick(false)
check("a closed world forgets what the player told, so the next one reads it at once",
      [overview.instance_variable_get(:@front), overview.instance_variable_get(:@level), overview.instance_variable_get(:@frames)], [nil, nil, 0])
