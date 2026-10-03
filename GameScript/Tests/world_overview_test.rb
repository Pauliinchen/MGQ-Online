#----------------------------------------------------------------
#  world_overview_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-03: Named the member in the leader's invite, which admits them
#      Paulinchen  2026-10-02: Opened the overview with the key mp_keys.rbx binds instead of a stand-in for the PvP battle screen's
#      Paulinchen  2026-10-01: Created
#
#----------------------------------------------------------------

# Covers the World overview, mp_world_overview.rbx: what the player tells the others (place,
# highest companion level, place in the story), the list by place, opening with F11 and the
# wheel, the arrows, the menu of a player, the mouse, and the places the party box shortens.

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

load_script "mp_world_overview"

overview = MGQ_MpWorldOverview

# The place in the story.
$data_system.variables[1001] = "Overall Events Progress"
$data_system.switches[50] = "Alice Chosen"
$data_system.variables[1142] = "天界ルート進行度"
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

# The highest companion level and the place.
$game_party.all_members = [Actor.new(99, true), Actor.new(40, false)]
$game_party.stand_members = [Actor.new(55, false)]
check("the highest companion, waiting ones too, Luka left out", overview.top_level, 55)
check("a map without a shown name goes by its name in the editor", overview.place, "Ilias Village (editor)")
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
check("inviting names the player, wherever they are", [MGQ_MpCoop::Party.targets, overview.menu], [["friend"], nil])
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

# An invite from afar.
$inbox << entry("message", 2, told(friend.merge("party" => "friend-p", "invite" => 1, "invite_to" => "me")))
MGQ_MpOverworldSync.tick
check("an invite naming the player is accepted from the overview", overview.party_option(MGQ_MpOverworldSync::Peers.at(2)).text, "Accept party invite")
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

# Places shortened to fit the party box, measured at 10 pixels a letter in 300 pixels.
fit = lambda { |place| overview.fit_place(place, 300) { |text| text.length * 10 } }
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
check("a member sees their leader in the party", overview.party_option(friend_peer).text, "In your party")
check("and may not invite", [overview.party_option(bea).run, overview.party_option(bea).refusal], [nil, "Only the party's leader invites."])
MGQ_MpCoop::Party.reset
MGQ_MpCoop::Party.invite("zz-bea")
$inbox << entry("message", 3, told(other.merge("party" => MGQ_MpCoop::Party.id, "id" => "zz-bea")))
MGQ_MpOverworldSync.tick
check("the leader may remove a member", overview.party_option(bea).text, "Remove from party")
