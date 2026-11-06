#----------------------------------------------------------------
#  ui_party_box_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Read the rows the box lists, leaving what it shows to the in-game suite
#      Paulinchen  2026-11-05: Expected the box's switch kept as true or false
#      Paulinchen  2026-11-01: Read the box from the Mod Framework's components it builds, and checked a click on its size hint
#                            - Stood in for the emote wheel of the Mod Framework
#      Paulinchen  2026-10-31: Kept the boxes' places in the Mod Framework's settings
#      Paulinchen  2026-10-30: Dropped the fade checks
#                            - Dropped the checks that restate pixel positions
#      Paulinchen  2026-10-23: Stood in for the part the Great Decision lies in, not the parts' starts
#      Paulinchen  2026-10-12: Checked the size hotkey pressed while the player types
#                            - Stood in for the parts of the world's story
#      Paulinchen  2026-10-11: Called the small box with the party and the others apart
#                            - Checked the box's place in the layout
#                            - Checked that a stranger is named in plain white
#                            - Created
#
#----------------------------------------------------------------

# Covers the party box and the map box, ui_party_box.rbx: the rows it lists, their icons, names,
# colors, levels, pings and places, away members, the map box, its ten rows, the small box, hiding,
# the log of who is listed, and the size hotkey and the click on the size hint. What it shows is the
# in-game suite's.

require_relative "hud_support"

# Stands in for the world, named Test World and a Raid World while $raid is set.
module MGQ_MpWorld
  # Answers the world, named Test World.
  def self.world; Struct.new(:name).new("Test World"); end
  # Answers whether the world is a Raid World, as $raid says.
  def self.raid?; $raid; end
end
# Stands in for the world's story, which the overview reads the parts' starts from.
module MGQ_MpWorldStory
  # The part the Great Decision lies in.
  DECISION_PART = "3"
end
# Stands in for duels, which offer nothing.
module MGQ_MpBattlesDuel
  # Answers that no duel is offered with a player.
  def self.peer_option(_peer); nil; end
  # Answers that no duel is offered on the player's own row.
  def self.own_options; []; end
  # Answers that no other player challenges the player.
  def self.call_of(_peer); nil; end
end
load_script "world_overview"
# Stands in for the emote wheel, which stays shut.
module MGQ_MpEmotes; def self.wheel; StandInWheel.new(lambda { false }); end; end
load_script "ui_party_box"

long_name = "A Very Long Player Name Indeed"

# Two other players join the world: the party's leader, in a battle, and a stranger who types.
$inbox << entry("seat", 0)
MGQ_MpOverworldSync.tick
leader_state = { "id" => "leader", "name" => long_name, "map" => 5, "x" => 1, "y" => 1, "d" => 2, "scene" => "battle", "ping" => 999 }
stranger_state = { "id" => "stranger", "name" => "Stranger", "map" => 5, "x" => 2, "y" => 2, "d" => 2, "scene" => "typing", "ping" => 80 }
$inbox << entry("in", 2) << entry("message", 2, told(leader_state)) << entry("in", 3) << entry("message", 3, told(stranger_state))
MGQ_MpOverworldSync.tick
leader = MGQ_MpOverworldSync::Peers.at(2)
stranger = MGQ_MpOverworldSync::Peers.at(3)
row = MGQ_MpWorldOverview::Row
# Tells a ping as the overview labels it.
ping = lambda { |milliseconds| MGQ_MpOverworld.ping_label(milliseconds) }
own_row = row.new(:me, "Me", "Castle", "Lv 55", "", ping.call(40), nil, true, ["2 / 4", false], nil)
leader_row = row.new(leader, long_name, "Forest", "Lv 100", "", ping.call(999), MGQ_MpOverworld::STATE_ICONS["battle"], true, ["2 / 4", true], nil)
stranger_row = row.new(stranger, "Stranger", "", "Lv 20", "", ping.call(80), MGQ_MpOverworld::TYPING_ICON, false, nil, nil)
party = [leader_row, own_row]
$sections = [party, []]
$raid = false
$overview_open = false
MGQ_MpPartyBox.define_singleton_method(:sections) { $sections }
MGQ_MpWorldOverview.define_singleton_method(:open?) { $overview_open }
MGQ_MpCoop.define_singleton_method(:in_party?) { true }

box = MGQ_MpPartyBox
# Reads the players now, as the box does every quarter of a second.
read = lambda { box.read($overview_open) }
read.call
# Lists the box's rows: a player's icons, then each text with its color; a heading's text.
lines = lambda do
  box.rows.map do |row|
    next row[:heading] if row[:heading]

    cells = row[:cells].reject { |cell| cell == "" }
    [cells.select { |cell| cell[:icons] }.map { |cell| cell[:icons] }.flatten] + cells.select { |cell| cell[:text] }.map { |cell| [cell[:text], cell[:color]] }
  end
end

# The full box of a Classic party.
check("the title names the party in the members' color", [box.title, box.title_color], ["Party", :mgq_online_member])
check("the leader first with a crown and the icon of their battle, named in the members' color, with level and ping, then where they are; " \
      "the player in their own color",
      lines.call,
      [[[MGQ_MpOverworld::CROWN_ICON, MGQ_MpOverworld::STATE_ICONS["battle"]], [long_name, :mgq_online_member], ["Lv 100", nil], ["999 ms", :error]],
       [[], ["Forest", :heading]],
       [[], ["Me", :mgq_online_own], ["Lv 55", nil], ["40 ms", :success]],
       [[], ["Castle", :heading]]])

# A member whose connection is down is dim, with the away icon.
leader.away = 60
read.call
check("an away member is dim, with the away icon in place of the battle's",
      lines.call.first.first(2), [[MGQ_MpOverworld::CROWN_ICON, MGQ_MpPartyBox::AWAY_ICON], [long_name, :dim]])
check("the player's own line is never away", [MGQ_MpPartyBox.away?(own_row), MGQ_MpPartyBox.away?(leader_row)], [false, true])
leader.away = nil

# The map box of a Raid World outside a party, and a Raid World's party with the others below.
$sections = [[], [own_row, leader_row, stranger_row]]
read.call
check("the map box is titled with how many are on the map", [box.title, box.title_color], ["Map 3", :text])
check("a stranger is named in plain text, the keyboard of their typing before, and no player has a place",
      [lines.call.last.first(2), lines.call.size], [[[MGQ_MpOverworld::TYPING_ICON], ["Stranger", :text]], 3])
$sections = [party, [stranger_row]]
read.call
check("a Raid World's party comes first with its places, then the map's heading and a row for each other player",
      lines.call.last(3).map { |line| line.is_a?(String) ? line : line[1][0] }, ["Castle", "Map 1", "Stranger"])
crowd = [leader_row, stranger_row] * 5 + [own_row, stranger_row]
$sections = [[], crowd]
read.call
check("past ten rows it lists nine and says how many more, keeping the player's own row",
      [lines.call.size, lines.call[-2][1], lines.call.last[1]], [10, ["Me", :mgq_online_own], ["+3 more", :dim]])

# The small box: names and pings without the title, the levels and the places.
MGQ_MpPartyBox.instance_variable_set(:@small, true)
$sections = [party, [stranger_row]]
read.call
check("small, the rows without levels and places", lines.call.map { |line| line[1..-1].map { |text, _color| text } },
      [[long_name, "999 ms"], ["Me", "40 ms"], ["Stranger", "80 ms"]])
MGQ_MpPartyBox.instance_variable_set(:@small, false)

# Hiding while the World overview is open or nobody is listed.
read.call
check("it shows while it lists anyone", MGQ_MpPartyBox.hidden?, false)
$overview_open = true
box.serial
check("the World overview hides it at once", MGQ_MpPartyBox.hidden?, true)
$overview_open = false
box.serial
$sections = [[], []]
read.call
check("and so does a box with nobody to list, keeping what it showed while it fades out", [MGQ_MpPartyBox.hidden?, lines.call.last[1][0]], [true, "Stranger"])
$sections = [party, []]
read.call

# The log names who the box lists, with each player's color and whether they are away.
logged = []
writer = MGQ_Multiplayer::Log.method(:write)
MGQ_Multiplayer::Log.define_singleton_method(:write) { |line| logged << line }
MGQ_MpPartyBox.note_rows([])
MGQ_MpPartyBox.note_rows(party)
MGQ_MpPartyBox.note_rows(party)
leader.away = 60
MGQ_MpPartyBox.note_rows(party)
leader.away = nil
MGQ_MpPartyBox.note_rows([own_row, leader_row, stranger_row], true)
MGQ_MpPartyBox.note_rows([])
MGQ_Multiplayer::Log.define_singleton_method(:write, writer)
check("the log names each listed player's color and whether they lead or are away, once per change", logged,
      ["party box: party box hidden",
       "party box: party box lists #{long_name} (leader, member), Me (own)",
       "party box: party box lists #{long_name} (leader, dim, away), Me (own)",
       "party box: map box lists Me (own), #{long_name} (leader, member), Stranger (#{MGQ_MpPlayerColor.label(stranger)})",
       "party box: party box hidden"])

# The size hotkey and the click on the size hint.
small_before = MGQ_MpPartyBox.small?
MGQ_MpChat.start_typing
$mgq_text_input = true
$pressed = MGQ_MpHotkeys.code(:party_box)
typed = logged_lines { MGQ_MpPartyBox.on_map }
$mgq_text_input = nil
MGQ_MpChat.stop_typing
check("Tab typed into the chat box changes nothing and stays out of the log", [MGQ_MpPartyBox.small?, typed.grep(/ignored/)], [small_before, []])
$pressed = MGQ_MpHotkeys.code(:party_box)
MGQ_MpPartyBox.on_map
check("Tab makes it small, which Player.ini keeps", [MGQ_MpPartyBox.small?, $player_ini["party_box_small"]], [true, true])
$pressed = MGQ_MpHotkeys.code(:party_box)
MGQ_MpPartyBox.on_map
MGQ_MpPartyBox.click_size
check("a click on the size hint makes it small too", MGQ_MpPartyBox.small?, true)
$overview_open = true
refused = logged_lines { MGQ_MpPartyBox.click_size }
$overview_open = false
check("with the hotkey's refusals, logged", [MGQ_MpPartyBox.small?, refused.grep(/World overview/).size], [true, 1])
MGQ_MpPartyBox.click_size
check("a click again makes it full", [MGQ_MpPartyBox.small?, $player_ini["party_box_small"]], [false, false])
