#----------------------------------------------------------------
#  clock_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# Covers the one clock of every timer: no script reads Graphics.frame_count, which goes back to the
# save's count as a save loads, but the bridge's frame (MGQ_Multiplayer::Bridge.frame_number). Only
# core_game_access.rbx touches the game's counter, to give it the base a New Game or a load sets.

require_relative "support"

# Each script's lines that read the game's frame counter, comments left out.
scripts = Dir[File.join(SCRIPTS_DIR, "*.rbx")] + [File.expand_path("../Multiplayer.rb", __dir__)]
reads = scripts.sort.flat_map do |path|
  File.readlines(path, :encoding => "BOM|UTF-8").map(&:strip).reject { |line| line.start_with?("#") }
      .select { |line| line.include?("Graphics.frame_count") }.map { |line| [File.basename(path), line] }
end
check("no script reads the game's frame counter for a timer, only the start of its base",
      reads, [["core_game_access.rbx", "Graphics.frame_count if defined?(Graphics) && Graphics.respond_to?(:frame_count)"]])
