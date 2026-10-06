#----------------------------------------------------------------
#  emotes_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-06: Pointed at emotes with the arrows held, diagonals and none included, and kept the last one once they are let go, a diagonal also when its arrows are let go one after the other
#      Paulinchen  2026-10-04: Created
#
#----------------------------------------------------------------

# Covers ui_emotes.rbx: the emote wheel's key, pointing at an emote with the arrows held, playing an emote on the player and
# telling the others, and another player's emote on their ghost.

require_relative "world_support"

# The player's and the ghosts' characters, which show a balloon or jump.
[Player, Game_Character].each do |owner|
  owner.class_eval do
    attr_accessor :balloon_id
    attr_reader :jumps
    def jump(x, y); @jumps = (@jumps || 0) + 1; end
  end
end
module Graphics; def self.frame_count; $frame_count; end; end
$frame_count = 0

load_script "ui_wheel"
load_script "ui_emotes"

emotes = MGQ_MpEmotes
friend = { "id" => "friend", "name" => "Friend", "map" => 5, "x" => 4, "y" => 4, "d" => 2, "sprite" => "Actor2", "index" => 0, "speed" => 4 }
$inbox << entry("seat", 0, "")
$inbox << entry("message", 2, told(friend))
MGQ_MpOverworldSync.tick
MGQ_MpOverworld.update_ghosts

# Opening and pointing.
$pressed = MGQ_MpHotkeys.code(:emotes)
emotes.on_map
check("E opens the emote wheel on the map, which holds the buttons and points at none", [emotes.open?, MGQ_Multiplayer::Capture.on?, emotes.selected], [true, true, nil])
$held = [:RIGHT]
emotes.on_map
check("an arrow held points at the emote on its side", emotes.selected, 2)
$held = [:UP, :LEFT]
emotes.on_map
check("two point at the diagonal between them", emotes.selected, MGQ_MpEmotes::EMOTES.size - 1)
$held = [:LEFT, :RIGHT]
emotes.on_map
check("opposite ones keep the emote", emotes.selected, MGQ_MpEmotes::EMOTES.size - 1)
$held = []
emotes.on_map
check("letting go keeps it too", emotes.selected, MGQ_MpEmotes::EMOTES.size - 1)
$held = [:DOWN, :RIGHT]
emotes.on_map
$held = [:RIGHT]
emotes.on_map
$held = []
emotes.on_map
check("letting go of a diagonal one arrow after the other keeps the diagonal", emotes.selected, 3)
$held = [:DOWN, :RIGHT]
emotes.on_map
$held = [:RIGHT]
MGQ_MpWheel::GRACE_FRAMES.times { emotes.on_map }
check("one arrow held on alone points to its side after a moment", emotes.selected, 2)
$held = []
emotes.close
emotes.open
$buttons << :C
emotes.on_map
check("confirm on none closes the wheel without an emote", [emotes.open?, $game_player.balloon_id, $sent.count { |message| message[1].start_with?("emote=") }], [false, nil, 0])

# Playing one.
emotes.open
$sent.clear
$held = [:UP, :RIGHT]
$buttons << :C
emotes.on_map
check("confirm closes the wheel and plays the picked emote, a balloon above the player", [emotes.open?, $game_player.balloon_id], [false, 1])
check("and tells the others", $sent.last[1].start_with?("emote=1\n") && $sent.last[1].include?("map=5"), true)
$sent.clear
emotes.open
$held = [:LEFT]
$buttons << :C
emotes.on_map
check("a second emote right after is refused", [$sent, $sounds.last], [[], "buzzer"])
$frame_count += MGQ_MpEmotes::COOLDOWN_FRAMES
emotes.open
$held = [:UP]
$buttons << :C
emotes.on_map
$held = []
check("the jump plays once a moment passed", [$game_player.jumps, $sent.size], [1, 1])
$pressed = MGQ_MpHotkeys.code(:emotes)
emotes.on_map
$pressed = MGQ_MpHotkeys.code(:emotes)
emotes.on_map
check("its key closes it again", emotes.open?, false)

# Another player's emote.
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
$pressed = MGQ_MpHotkeys.code(:emotes)
emotes.on_map
check("the chat box keeps the wheel shut", emotes.open?, false)
MGQ_MpChat.stop_typing
