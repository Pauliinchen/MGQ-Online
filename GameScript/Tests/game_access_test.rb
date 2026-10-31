#----------------------------------------------------------------
#  game_access_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

# Covers the start core_game_access.rbx gives the game's frame counter, which raises until a New
# Game or a load sets its base: it counts once the scripts loaded, and a base the game sets stands.

require_relative "support"

$log = []
# Stands in for the loader's log, keeping its lines in $log.
module MGQ_Multiplayer; module Log; def self.write(m); $log << m; end; end; end

# The frames RGSS counted since the game started.
$frames = 120

# Stands in for the game's frame counter: the frames RGSS counted plus a base that only a New Game
# or a load sets, nil before.
module Graphics
  class << self
    # Sets the base, as a New Game and a load do.
    def frame_count=(value); @frame_count = value.abs; $frames = 0; end
    # Counts the frames from the base.
    def frame_count; $frames + @frame_count; end
  end
end

before = begin
  Graphics.frame_count
rescue TypeError => e
  e.class
end
check("the game's counter raises before a New Game or a load", before, TypeError)

load_script "core_hooks"

check("the game's counter counts from the game's start once the scripts loaded", Graphics.frame_count, 120)
check("the start is logged once", $log.grep(/frame counter/).size, 1)

Graphics.frame_count = 5000
$frames = 3
MGQ_MpGame.start_frame_count
check("a base the game set stands", Graphics.frame_count, 5003)
