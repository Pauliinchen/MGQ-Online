#----------------------------------------------------------------
#  make_wheel_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Writes wheel.json next to this file: the wheels' golden cases, the arrows held frame by frame
# through MGQ_MpWheel.steady and every count of choices through MGQ_MpWheel.places, as ui_wheel.rbx
# had them before the wheels moved to C# (WheelPointer and WheelPlaces in MGQOnline.Game), which
# MGQOnline.Game.Tests replays. The scripts no longer hold those rules, so hand it the script of
# commit 8fc9bc6 to write the cases again:
#
#   git show 8fc9bc6:GameScript/Multiplayer/Scripts/ui_wheel.rbx > old_wheel.rbx
#   ruby fixtures/ui/make_wheel_fixtures.rb old_wheel.rbx

require "json"

# The arrows a frame holds, read by the wheel through the stand-in below.
$wheel_arrows = []

# Stand-ins for the mod's base script: the arrows a frame holds, past the capture.
module MGQ_Multiplayer
  # The buttons past the capture.
  module Capture
    # Whether the frame holds an arrow.
    #
    # @param button [Symbol] The button.
    # @return [Boolean] Whether it does.
    def self.press?(button)
      $wheel_arrows.include?(button.to_s)
    end
  end
end

# The wheels' shared pointing and placing, read out of the script.
module MGQ_MpWheel
  source = File.read(ARGV[0] || abort("Name the ui_wheel.rbx of commit 8fc9bc6, see the header."), :encoding => "UTF-8")
  module_eval(source[/^  DIRECTIONS = .*?\n/m] + source[/^  STEPS = \{.*?^  \}\n/m] + source[/^  GRACE_FRAMES = \d+\n/])
  %w[held steady reset side_of\? places].each do |name|
    module_eval(source[/^  def self\.#{name}(\(|\n).*?^  end\n/m] || abort("#{name} is missing"))
  end
  @steady = nil
  @waited = 0
end

# The cases: the arrows held in each frame, from a wheel just opened.
STEADY = {
  "one_arrow" => [["UP"], ["UP"], []],
  "diagonal_let_go_together" => [["UP", "RIGHT"], ["RIGHT"], ["RIGHT"], []],
  "diagonal_left_to_its_side" => [["DOWN", "LEFT"]] + [["LEFT"]] * 9,
  "opposite_arrows" => [["UP", "DOWN"], ["LEFT", "RIGHT"], ["UP", "DOWN", "LEFT"]],
  "diagonal_to_diagonal" => [["UP", "LEFT"], ["UP", "RIGHT"], ["RIGHT"], ["DOWN", "RIGHT"], ["DOWN"]],
  "side_held_after_another_side" => [["UP"], ["UP", "RIGHT"], ["UP"], ["LEFT"]],
}.freeze

steady = STEADY.map do |name, frames|
  MGQ_MpWheel.reset
  pointed = frames.map do |arrows|
    $wheel_arrows = arrows
    direction = MGQ_MpWheel.steady
    direction && direction.to_s
  end
  { "name" => name, "frames" => frames, "pointed" => pointed }
end
places = (1..MGQ_MpWheel::DIRECTIONS.size).map { |count| { "count" => count, "places" => MGQ_MpWheel.places(count).map(&:to_s) } }
fixture = { "directions" => MGQ_MpWheel::DIRECTIONS.map(&:to_s), "grace_frames" => MGQ_MpWheel::GRACE_FRAMES, "steady" => steady, "places" => places }
File.write(File.join(__dir__, "wheel.json"), JSON.pretty_generate(fixture) + "\n")
puts "wrote wheel.json: #{steady.size} pointing and #{places.size} placing cases"
