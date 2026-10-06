#----------------------------------------------------------------
#  ui_wheel.rbx
#
#  Changelog:
#      Paulinchen  2026-10-06: Spread a wheel's choices evenly over the directions the arrows point to
#                            - Created
#
#----------------------------------------------------------------

# What the wheels on the map share, the action wheel (ui_actions.rbx) and the emote wheel
# (ui_emotes.rbx): the arrows held point like a joystick, one arrow to its side and two to the
# diagonal between them, and nowhere while none is held. A wheel spreads its choices evenly over
# those directions (places), picks what lies in the direction pointed to, and its middle while the
# arrows point nowhere.
module MGQ_MpWheel
  # The directions the arrows can point to, clockwise from the top.
  DIRECTIONS = [:UP, :UP_RIGHT, :RIGHT, :DOWN_RIGHT, :DOWN, :DOWN_LEFT, :LEFT, :UP_LEFT]

  # The direction by the row and the column the arrows held point to, from -1 (up, left) to 1
  # (down, right).
  STEPS = {
    [-1, 0] => :UP, [-1, 1] => :UP_RIGHT, [0, 1] => :RIGHT, [1, 1] => :DOWN_RIGHT,
    [1, 0] => :DOWN, [1, -1] => :DOWN_LEFT, [0, -1] => :LEFT, [-1, -1] => :UP_LEFT,
  }

  # Finds the direction the arrows held point to, past the capture of the wheel's buttons.
  #
  # @return [Symbol, nil] One of DIRECTIONS, nil while no arrow is held or only opposite ones are.
  def self.held
    capture = MGQ_Multiplayer::Capture
    row = (capture.press?(:DOWN) ? 1 : 0) - (capture.press?(:UP) ? 1 : 0)
    column = (capture.press?(:RIGHT) ? 1 : 0) - (capture.press?(:LEFT) ? 1 : 0)
    STEPS[[row, column]]
  end

  # Spreads a wheel's choices evenly over DIRECTIONS, clockwise from the top, so every count comes
  # out mirror-symmetric: four take the sides, five add the two lower diagonals in place of the bottom.
  #
  # @param count [Integer] How many choices the wheel has, at most DIRECTIONS.size.
  # @return [Array<Symbol>] Each choice's direction, in the choices' order.
  def self.places(count)
    Array.new(count) { |index| DIRECTIONS[(index * DIRECTIONS.size.to_f / count).round % DIRECTIONS.size] }
  end
end
