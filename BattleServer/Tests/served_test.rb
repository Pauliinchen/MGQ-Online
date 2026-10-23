#----------------------------------------------------------------
#  served_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Tests of served.rb's drawing: a served battle updates its windows and sprites on every frame,
# and while it waits for its players only on every ServedBattle::WAIT_DRAW_FRAMES-th.

require_relative "support"
require_relative File.join(LIB_DIR, "served")

# Stands in for MGQ Online's wait for the players.
module MGQ_MpBattlesSync
  # The wait, open while waiting is true.
  module Waiting
    class << self
      # Whether the wait is open.
      attr_accessor :waiting

      # Tells whether the wait is open.
      #
      # @return [Boolean] Whether it is.
      def active?
        waiting
      end
    end
  end
end

# Counts the frames of a stretch that draw.
#
# @param frames [Integer] The frames.
# @return [Integer] How many drew.
def drawn(frames)
  Array.new(frames) do
    ServedBattle.count_waiting
    ServedBattle.drawing?
  end.count(true)
end

check("a battle that does not wait draws every frame", drawn(10), 10)
MGQ_MpBattlesSync::Waiting.waiting = true
check("a battle that waits for its players draws on every #{ServedBattle::WAIT_DRAW_FRAMES}th frame",
      drawn(ServedBattle::WAIT_DRAW_FRAMES * 4), 4)
MGQ_MpBattlesSync::Waiting.waiting = false
check("a battle draws again on the first frame after its wait", drawn(1), 1)
