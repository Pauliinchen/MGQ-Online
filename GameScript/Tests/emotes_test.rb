#----------------------------------------------------------------
#  emotes_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-01: Checked the emote wheel as a Mod Framework wheel, its drawing left to the framework's tests
#      Paulinchen  2026-10-31: Expected the game's cancel key in the wheel's hint and read the Mod Framework's capture
#      Paulinchen  2026-10-30: Dropped the fade checks
#      Paulinchen  2026-10-23: Left the wheel's pointing to C# and checked what the script does with its events
#      Paulinchen  2026-10-12: Checked the log of the emote hotkey while typing and when refused
#      Paulinchen  2026-10-11: Checked the wheel's boxes, the picked one lit and a redraw after a preset change
#                            - Checked the wheel's hint, the name of the emote pointed at and the fades
#                            - Checked the hint drawn whole with a rebound hotkey's longer name
#      Paulinchen  2026-10-06: Checked that the World overview keeps the wheel shut and a loaded save ends the cooldown
#                            - Left loading ui_wheel.rbx to world_support.rb
#                            - Pointed at emotes with the arrows held, diagonals included
#      Paulinchen  2026-10-04: Created
#
#----------------------------------------------------------------

# Covers ui_emotes.rbx: the emote wheel's hotkey, pointing at an emote with the arrows held, playing
# an emote on the player and telling the others, and another player's emote on their ghost.

require_relative "world_support"

# The player's and the ghosts' characters, which show a balloon or jump.
[Player, Game_Character].each do |owner|
  owner.class_eval do
    attr_accessor :balloon_id
    attr_reader :jumps
    def jump(x, y); @jumps = (@jumps || 0) + 1; end
  end
end
# Stands in for the screen's frame count, kept in $frame_count.
module Graphics; def self.frame_count; $frame_count; end; end
$frame_count = 0

load_script "ui_emotes"

emotes = MGQ_MpEmotes
friend = { "id" => "friend", "name" => "Friend", "map" => 5, "x" => 4, "y" => 4, "d" => 2, "sprite" => "Actor2", "index" => 0, "speed" => 4 }
$inbox << entry("seat", 0, "")
$inbox << entry("message", 2, told(friend))
MGQ_MpOverworldSync.tick
MGQ_MpOverworld.update_ghosts

# Opening, pointing and playing one: C# keeps the wheel's rules (WheelModel, its pointing checked
# in MGQOnline.Game.Tests); the script holds the buttons while the wheel is open and plays the
# emote confirm took, in the frame after.
#
# Runs one frame of the map with the wheel.
# One frame on the map: the emote taken, the end of the frame with its tick, then the hotkeys.
emote_frame = lambda do
  emotes.on_map
  ui_frame
  Mod_Framework::Hotkeys.fire
end
wheel = emotes.wheel
pointed = lambda { wheel.selected.is_a?(Hash) ? wheel.selected[:text] : wheel.selected }
# Opens the wheel with its hotkey, which C# opens in the next frame's tick.
open_wheel = lambda do
  $pressed = MGQ_MpHotkeys.code(:emotes)
  emote_frame.call
  emote_frame.call
end
play_emote = lambda do |arrows|
  open_wheel.call
  $held = arrows
  emote_frame.call
  $held = []
  $buttons << :C
  emote_frame.call
  emote_frame.call
end
open_wheel.call
check("E opens the emote wheel on the map, which holds the buttons and points at none", [wheel.open?, Mod_Framework::UI::Capture.on?, pointed.call], [true, true, nil])
check("its emotes are a jump by its name and the game's balloons, None while none is picked",
      [wheel.none_text, emotes.choices.map { |choice| choice.key?(:bitmap) }, emotes.choices.map { |choice| choice[:text] }],
      ["None", [false] + [true] * 7, emotes::EMOTES.map { |emote| emote.name }])
$held = [:UP, :RIGHT]
emote_frame.call
check("the arrows held point at the emote of their direction", pointed.call, "Surprise")
$held = []
$buttons << :C
$sent.clear
emote_frame.call
check("confirm closes the wheel and gives the buttons back, the emote not played yet", [wheel.open?, Mod_Framework::UI::Capture.on?, $sent], [false, false, []])
emote_frame.call
check("the frame after plays the picked emote, a balloon above the player", $game_player.balloon_id, 1)
check("and tells the others", $sent.last[1].start_with?("emote=1
") && $sent.last[1].include?("map=5"), true)
open_wheel.call
$buttons << :C
$sounds.clear
emote_frame.call
emote_frame.call
check("confirm on none closes the wheel without an emote, with the cancel sound", [wheel.open?, $sent.size, $sounds], [false, 1, ["cancel"]])
$sent.clear
play_emote.call([:LEFT])
check("a second emote right after buzzes and plays nothing", [$sent, $sounds.last], [[], "buzzer"])
$frame_count += MGQ_MpEmotes::COOLDOWN_FRAMES
play_emote.call([:UP])
check("the jump plays once a moment passed", [$game_player.jumps, $sent.size], [1, 1])
$frame_count = 5
play_emote.call([:UP])
check("a save loaded with fewer frames played ends the moment too", [$game_player.jumps, $sent.size], [2, 2])
open_wheel.call
$pressed = MGQ_MpHotkeys.code(:emotes)
emote_frame.call
check("its hotkey closes it again", wheel.open?, false)
$game_message.busy = true
open_wheel.call
$game_message.busy = false
check("a message keeps it shut", wheel.open?, false)
open_wheel.call
$game_message.busy = true
emote_frame.call
$game_message.busy = false
check("a message that starts closes it", wheel.open?, false)

ghost = MGQ_MpOverworldSync::Peers.at(2).ghost
$inbox << entry("message", 2, "emote=4\nmap=5\n\n")
MGQ_MpOverworldSync.tick
check("another player's emote plays on their ghost", ghost.balloon_id, 4)
$inbox << entry("message", 2, "emote=0\nmap=5\n\n")
MGQ_MpOverworldSync.tick
check("their jump too", ghost.jumps, 1)
$inbox << entry("message", 2, "emote=4\nmap=9\n\n")
ghost.balloon_id = 0
MGQ_MpOverworldSync.tick
check("but not one from another map", ghost.balloon_id, 0)
$inbox << entry("message", 2, "emote=99\nmap=5\n\n")
MGQ_MpOverworldSync.tick
check("nor one the wheel has not", ghost.balloon_id, 0)

# Not while the chat box is open.
MGQ_MpChat.start_typing
$mgq_text_input = true
$pressed = MGQ_MpHotkeys.code(:emotes)
emote_frame.call
emote_frame.call
$mgq_text_input = nil
check("the chat box keeps the wheel shut", wheel.open?, false)
MGQ_MpChat.stop_typing

Mod_Framework::UI::Capture.start(:overview)
open_wheel.call
check("the World overview, which holds the buttons, keeps the wheel shut", [wheel.open?, Mod_Framework::UI::Capture.on?], [false, true])
Mod_Framework::UI::Capture.stop(:overview)
