#----------------------------------------------------------------
#  emotes_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Answered the emotes, a refused emote and an emote of another player that does not play with fixed values
#      Paulinchen  2026-11-06: Took the emotes as the wheel of the UI layer tells them, leaving its keys to the in-game suite
#      Paulinchen  2026-11-05: Handed the other players' messages as the DLL reads them and expected the emote sent as the scripts hand it
#                            - Read the scripts' clock from $frame_count and dropped the check of a cooldown a loaded save ended, since the clock never goes back
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

# Covers ui_emotes.rbx: the emotes its wheel offers, when the wheel may open, playing the emote it
# took on the player and telling the others, an emote the DLL refuses, and another player's emote
# on their ghost unless the DLL tells why not. The wheel's keys are the framework's and the in-game
# suite's; EmotesTests own the rules.

require_relative "world_support"

# The player's and the ghosts' characters, which show a balloon or jump.
[Player, Game_Character].each do |owner|
  owner.class_eval do
    attr_accessor :balloon_id
    attr_reader :jumps
    def jump(x, y); @jumps = (@jumps || 0) + 1; end
  end
end
# The scripts' clock reads $frame_count.
clock_from { $frame_count }
$frame_count = 0

load_script "ui_emotes"
# The DLL's answers: the emotes, why an emote of the player may not play ($refusal) and why
# another player's may not ($ignored), each nil to play it.
EMOTE_NAMES = %w(Jump Surprise Question Music Heart Anger Sweat Idea)
$world_bridge.answer("emote.list") { EMOTE_NAMES.each_with_index.map { |name, index| [name, index == 0 ? nil : index] } }
$world_bridge.answer("emote.play") { |_index| $refusal }
$taken = []
$world_bridge.answer("emote.take") { |request| $taken << request; $ignored }

emotes = MGQ_MpEmotes
friend = { "id" => "friend", "name" => "Friend", "map" => "5", "x" => "4", "y" => "4", "d" => "2", "sprite" => "Actor2", "index" => "0", "speed" => "4" }
$inbox << entry("seat", 0)
$inbox << entry("message", 2, told(friend))
MGQ_MpOverworldSync.tick
MGQ_MpOverworld.update_ghosts

# The wheel: the framework's wheel of the UI layer keeps its keys (the in-game suite walks them);
# the script names its emotes, plays the one taken in the frame after and tells the others.
#
# Takes an emote as the wheel tells it, then runs the frame after on the map.
take = lambda do |index|
  emotes.opened
  emotes.taken(emotes.choices[index])
  emotes.closed(:submit)
  emotes.on_map
  $frame_count += 1
  emotes.on_map
end
check("its emotes are a jump by its name and the game's balloons, the wheel saying None while none is picked",
      [emotes::NONE_TEXT, emotes.choices.map { |choice| choice.key?(:bitmap) }, emotes.choices.map { |choice| choice[:text] }],
      ["None", [false] + [true] * 7, EMOTE_NAMES])
emotes.opened
check("the other scripts see it open", emotes.wheel.open?, true)
emotes.taken(emotes.choices[1])
emotes.closed(:submit)
$sent.clear
emotes.on_map
check("the emote taken waits for the frame after, the wheel closed", [emotes.wheel.open?, $sent], [false, []])
$frame_count += 1
emotes.on_map
check("the frame after plays it, a balloon above the player", $game_player.balloon_id, 1)
check("and tells the others", $sent.last[1].values_at("emote", "map"), [1, 5])
$sent.clear
$sounds.clear
$refusal = "Sweat: only 1 of 30 frames since the last emote"
take.call(6)
check("an emote the DLL refuses buzzes and plays nothing", [$sent, $sounds.last], [[], "buzzer"])
$refusal = nil
take.call(0)
check("the jump plays once the DLL lets it", [$game_player.jumps, $sent.size], [1, 1])
emotes.taken(emotes.choices[2])
$frame_count += 3
emotes.on_map
check("an emote taken frames ago, the map not running meanwhile, plays nothing", $sent.size, 1)

# When the wheel may open.
check("on a free map in a world it may open", emotes.busy_reason, nil)
$game_message.busy = true
check("a message keeps it shut", emotes.busy_reason.nil?, false)
$game_message.busy = false

ghost = MGQ_MpOverworldSync::Peers.at(2).ghost
$inbox << entry("message", 2, { "emote" => 4, "map" => "5" })
MGQ_MpOverworldSync.tick
check("another player's emote plays on their ghost", ghost.balloon_id, 4)
check("asked with the emote, their map and the player's, and whether their ghost is here",
      $taken.last, { "emote" => 4, "map" => 5, "own_map" => 5, "ghost" => true })
$inbox << entry("message", 2, { "emote" => 0, "map" => "5" })
MGQ_MpOverworldSync.tick
check("their jump too", ghost.jumps, 1)
$inbox << entry("message", 2, { "emote" => 4, "map" => "9" })
ghost.balloon_id = 0
$ignored = "Heart: played on map 9, the player is on 5"
MGQ_MpOverworldSync.tick
check("but not one the DLL tells why not", ghost.balloon_id, 0)
