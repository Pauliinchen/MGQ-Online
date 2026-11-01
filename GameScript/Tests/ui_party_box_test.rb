#----------------------------------------------------------------
#  ui_party_box_test.rb
#
#  Changelog:
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

# Covers the party box and the map box, ui_party_box.rbx: its box of the Mod Framework docked at the
# top right under the game's windows, its lines' icons, names, colors, levels, pings and places,
# away members, the map box, its ten lines, the small box, hiding, the log of who is listed, and the
# size hotkey and the click on the size hint.

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

ui = Mod_Framework::UI
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

view = MGQ_MpPartyBox::View.new
root = view.root
# Reads the players now, as the box does every quarter of a second.
read = lambda { view.refresh($overview_open) }
read.call
# Lists the lines of the box: each line's icons, then its texts with their colors.
lines = lambda do
  parts_of_kind(root, ui::Grid).map do |line|
    icons = parts_of_kind(line, ui::Icon).map { |icon| icon.icon }
    [icons] + parts_of_kind(line, ui::Label).map { |label| [label.text, label.color] }
  end
end
# Finds the label of a text in the box.
label = lambda { |text| part_with_text(root, text) }

check("it opens as the movable Party box at the top right, widened only, under the game's windows, the pointer passing but for its parts",
      [root.open?, root.id, root.place_name, root.dock, root.under_windows, root.resizable, root.min_size, root.mouse],
      [true, :party_box, "Party box", :top_right, true, :width, [296, 26], :parts])

# The full box of a Classic party.
check("the title names the party in the members' color, with the hint of the size hotkey at its right, dim",
      [label.call("Party").color, label.call("Tab: size").color, label.call("Tab: size").is_a?(ui::Button)], [:ally, :dim, true])
check("the leader first with a crown and the icon of their battle, named in the members' color, with level and ping; the player in their own",
      lines.call,
      [[[MGQ_MpOverworld::CROWN_ICON, MGQ_MpOverworld::STATE_ICONS["battle"]], [long_name, :ally], ["Lv 100", nil], ["999 ms", MGQ_MpOverworld::PING_COLORS.last[1]]],
       [[], ["Me", :own], ["Lv 55", nil], ["40 ms", MGQ_MpOverworld::PING_COLORS.first[1]]]])
check("below each, where they are, in the tiny font and the heading color", [label.call("Forest").font_size, label.call("Forest").color, label.call("Castle").nil?], [:tiny, :heading, false])

# A member whose connection is down is dim, with the away icon.
leader.away = 60
read.call
check("an away member is dim, with the away icon in place of the battle's",
      [label.call(long_name).color, lines.call.first.first], [:dim, [MGQ_MpOverworld::CROWN_ICON, MGQ_MpPartyBox::AWAY_ICON]])
check("the player's own line is never away", [MGQ_MpPartyBox.away?(own_row), MGQ_MpPartyBox.away?(leader_row)], [false, true])
leader.away = nil

# The map box of a Raid World outside a party, and a Raid World's party with the others below.
$sections = [[], [own_row, leader_row, stranger_row]]
read.call
check("the map box is titled with how many are on the map, the size hint at the right too", [texts_of(root).first(2), label.call("Map 3").color], [["Map 3", "Tab: size"], :text])
check("a stranger is named in plain text, the keyboard of their typing before, and no player has a place",
      [label.call("Stranger").color, lines.call.last.first, label.call("Forest")], [:text, [MGQ_MpOverworld::TYPING_ICON], nil])
$sections = [party, [stranger_row]]
read.call
check("a Raid World's party comes first with its places, then the map's title and a line for each other player",
      texts_of(root).last(5), ["Castle", "Map 1", "Stranger", "Lv 20", "80 ms"])
crowd = [leader_row, stranger_row] * 5 + [own_row, stranger_row]
$sections = [[], crowd]
read.call
check("past ten lines it lists nine and says how many more, keeping the player's own line",
      [lines.call.size, lines.call.last[1], label.call("+3 more").nil?], [9, ["Me", :own], false])

# The small box: names and pings at the right edge of the box's place.
MGQ_MpPartyBox.instance_variable_set(:@small, true)
$sections = [party, [stranger_row]]
read.call
panel = root.children.first
check("small, a narrower panel at the right edge of the box's place, without the title and the levels",
      [panel.width, panel.align, label.call("Party"), label.call("Lv 100"), lines.call.map { |line| line[1][0] }], [198, :end, nil, nil, [long_name, "Me", "Stranger"]])
MGQ_MpPartyBox.instance_variable_set(:@small, false)

# Hiding while the World overview is open or nobody is listed.
check("it shows while it lists anyone", MGQ_MpPartyBox.hidden?, false)
$overview_open = true
view.update
check("the World overview hides it at once", [MGQ_MpPartyBox.hidden?, hidden_root?(root)], [true, true])
$overview_open = false
view.update
$sections = [[], []]
read.call
check("and so does a box with nobody to list, keeping what it showed while it fades out", [hidden_root?(root), texts_of(root).include?("Stranger")], [true, true])
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
check("Tab makes it small, which Player.ini keeps", [MGQ_MpPartyBox.small?, $player_ini["party_box_small"]], [true, "1"])
$pressed = MGQ_MpHotkeys.code(:party_box)
MGQ_MpPartyBox.on_map
read.call
label.call("Tab: size").send(:emit, :click)
check("a click on the size hint makes it small too", MGQ_MpPartyBox.small?, true)
$overview_open = true
refused = logged_lines { MGQ_MpPartyBox.click_size }
$overview_open = false
check("with the hotkey's refusals, logged", [MGQ_MpPartyBox.small?, refused.grep(/World overview/).size], [true, 1])
MGQ_MpPartyBox.click_size
check("a click again makes it full", [MGQ_MpPartyBox.small?, $player_ini["party_box_small"]], [false, "0"])

# The map's sprites open the box and close it as they go.
spriteset = Spriteset_Map.new
spriteset.update
shown = spriteset.instance_variable_get(:@mgq_mp_party_box)
spriteset.dispose
check("the map's sprites open the box and close it with them", [shown.root.id, shown.root.open?], [:party_box, false])
