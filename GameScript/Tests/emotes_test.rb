#----------------------------------------------------------------
#  emotes_test.rb
#
#  Changelog:
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
emote_frame = lambda do
  emotes.on_map
  ui_frame
end
# Opens the wheel, points at a direction's emote and confirms it, then plays it in the frame after.
#
# @param arrows [Array<Symbol>] The arrows held.
play_emote = lambda do |arrows|
  $pressed = MGQ_MpHotkeys.code(:emotes)
  emote_frame.call
  $held = arrows
  emote_frame.call
  $held = []
  $buttons << :C
  emote_frame.call
  emote_frame.call
end
$pressed = MGQ_MpHotkeys.code(:emotes)
emote_frame.call
check("E opens the emote wheel on the map, which holds the buttons and points at none", [emotes.open?, Mod_Framework::UI::Capture.on?, emotes.selected], [true, true, nil])
$held = [:UP, :RIGHT]
emote_frame.call
check("the arrows held point at the emote of their direction", emotes.selected, 1)
$held = []
$buttons << :C
emote_frame.call
check("confirm closes the wheel and gives the buttons back", [emotes.open?, Mod_Framework::UI::Capture.on?], [false, false])
$sent.clear
emote_frame.call
check("the frame after plays the picked emote, a balloon above the player", $game_player.balloon_id, 1)
check("and tells the others", $sent.last[1].start_with?("emote=1\n") && $sent.last[1].include?("map=5"), true)
$pressed = MGQ_MpHotkeys.code(:emotes)
emote_frame.call
$buttons << :C
$sounds.clear
emote_frame.call
emote_frame.call
check("confirm on none closes the wheel without an emote, with the cancel sound", [emotes.open?, $sent.size, $sounds], [false, 1, ["cancel"]])
$sent.clear
play_emote.call([:LEFT])
check("a second emote right after is refused", [$sent, $sounds.last], [[], "buzzer"])
$frame_count += MGQ_MpEmotes::COOLDOWN_FRAMES
play_emote.call([:UP])
check("the jump plays once a moment passed", [$game_player.jumps, $sent.size], [1, 1])
$frame_count = 5
play_emote.call([:UP])
check("a save loaded with fewer frames played ends the moment too", [$game_player.jumps, $sent.size], [2, 2])
$pressed = MGQ_MpHotkeys.code(:emotes)
emote_frame.call
$pressed = MGQ_MpHotkeys.code(:emotes)
emote_frame.call
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
$mgq_text_input = true
$pressed = MGQ_MpHotkeys.code(:emotes)
typed = logged_lines { emotes.on_map }
$mgq_text_input = nil
check("the chat box keeps the wheel shut, the letter typed left out of the log", [emotes.open?, typed.grep(/ignored/)], [false, []])
MGQ_MpChat.stop_typing

# Not while the World overview is open, whose hold on the buttons stays.
# Stands in for the World overview, open while $overview_open is.
module MGQ_MpWorldOverview; def self.open?; $overview_open; end; end
$overview_open = true
Mod_Framework::UI::Capture.start(:overview)
$pressed = MGQ_MpHotkeys.code(:emotes)
refused = logged_lines { emotes.on_map }
check("the World overview keeps the wheel shut", [emotes.open?, Mod_Framework::UI::Capture.on?], [false, true])
check("which the log says under the hotkeys", refused.grep(/ignored/), ["keys: hotkey E (Emote Wheel) ignored: the World overview is open"])
$overview_open = false
emotes.on_map
$pressed = MGQ_MpHotkeys.code(:emotes)
emotes.on_map
emotes.close
check("a wheel that opened and closed under another screen leaves its hold", Mod_Framework::UI::Capture.on?, true)
Mod_Framework::UI::Capture.stop(:overview)

# The wheel's picture: its boxes in the shared style, the picked emote's name below the ring and
# the hint under it, fading in on open and out on close with the picture kept. Pictures measure
# each character at 7 pixels.
# Stands in for a sprite, its picture and place readable.
class Sprite
  attr_accessor :bitmap, :x, :y, :z, :ox, :oy, :opacity, :visible
  def disposed?; false; end
  def dispose; end
end
# Stands in for a picture, keeping its texts and fills.
class Bitmap
  # The picture's font.
  Font = Struct.new(:size, :color, :bold, :outline, :out_color)
  attr_reader :texts, :fills, :font
  def initialize(*); @texts = []; @fills = []; @font = Font.new; end
  def clear; @texts.clear; @fills.clear; end
  def fill_rect(_x, _y, _w, _h, color); @fills << color; end
  def text_size(text); Rect.new(0, 0, text.to_s.size * 7, 14); end
  def draw_text(_x, y, _w, _h, text, _align = 0); @texts << [y, text, font.size, font.color]; end
  def blt(*); end
  def dispose; end
end
# Stands in for the game's cache of system pictures.
module Cache; def self.system(_name); :balloons; end; end
style = MGQ_MpUi::Style
wheel = Sprite_MpEmoteWheel.new(nil)
player = Struct.new(:x, :y).new(100, 120)
# The frames below are Legacy's, one pixel of edge.
MGQ_MpUi::Theme.apply("Legacy", "a test")
$pressed = MGQ_MpHotkeys.code(:emotes)
emote_frame.call
wheel.show(player)
hint = wheel.bitmap.texts.last
check("open, the wheel draws around the player, None named below the ring and the hint under it, fading in",
      [wheel.visible, wheel.opacity.between?(1, 254), wheel.x, wheel.y, wheel.bitmap.texts[-2][1], hint[1], hint[2], hint[3].equal?(style::HEADING)],
      [true, true, 100, 120, "None", "X, Numpad 0 or E: close", style::TINY_SIZE, true])
boxes = MGQ_MpEmotes::EMOTES.size + 1
check("the hint lies under the name's line, and the boxes fill with the style's colors, None picked, each in its frame",
      [hint[0], wheel.bitmap.fills.all? { |color| [style::BACK, style::PICKED, style::EDGE].any? { |known| color.equal?(known) } },
       wheel.bitmap.fills.count { |color| color.equal?(style::PICKED) }, wheel.bitmap.fills.count { |color| color.equal?(style::EDGE) }],
      [Sprite_MpEmoteWheel::SIZE + Sprite_MpEmoteWheel::NAME_HEIGHT, true, 1, 4 * boxes])
MGQ_MpUi::Theme.apply("Monarch", "a test")
wheel.show(player)
check("a preset change draws the wheel anew, each box's frame with the preset's rim", wheel.bitmap.fills.count { |color| color.equal?(style::RIM) }, 4 * boxes)
MGQ_MpUi::Theme.apply("Legacy", "a test")
wheel.show(player)
(style::FADE_FRAMES - 1).times { wheel.show(player) }
MGQ_MpHotkeys.bind(:emotes, 0xBA)
wide = Sprite_MpEmoteWheel.new(nil)
wide.show(player)
check("a rebound key's longer name leaves the hint whole, wider than the wheel, never cut", wide.bitmap.texts.last[1], "X, Numpad 0 or key 186: close")
$player_ini.delete("key_emotes")
$held = [:RIGHT]
emote_frame.call
$held = []
wheel.show(player)
check("the emote pointed at is named", wheel.bitmap.texts[-2][1], "Question")
emotes.close
wheel.show(player)
check("closed, the wheel fades out with its picture kept", [wheel.visible, wheel.opacity < 255, wheel.bitmap.texts.empty?], [true, true, false])
(style::FADE_FRAMES - 1).times { wheel.show(player) }
