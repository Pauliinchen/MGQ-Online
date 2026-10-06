#----------------------------------------------------------------
#  ui_wheel.rbx
#
#  Changelog:
#      Paulinchen  2026-10-06: Waited a moment before an arrow let go of a diagonal counts, since two arrows are seldom let go in the same frame
#                            - Spread a wheel's choices evenly over the directions the arrows point to
#                            - Created
#
#----------------------------------------------------------------

# What the wheels on the map share, the action wheel (ui_actions.rbx) and the emote wheel
# (ui_emotes.rbx): the arrows held point like a joystick, one arrow to its side and two to the
# diagonal between them, and nowhere while none is held. A wheel spreads its choices evenly over
# those directions (places), picks what lies in the direction pointed to, and keeps it picked once
# the arrows are let go.
module MGQ_MpWheel
  # The directions the arrows can point to, clockwise from the top.
  DIRECTIONS = [:UP, :UP_RIGHT, :RIGHT, :DOWN_RIGHT, :DOWN, :DOWN_LEFT, :LEFT, :UP_LEFT]

  # The direction by the row and the column the arrows held point to, from -1 (up, left) to 1
  # (down, right).
  STEPS = {
    [-1, 0] => :UP, [-1, 1] => :UP_RIGHT, [0, 1] => :RIGHT, [1, 1] => :DOWN_RIGHT,
    [1, 0] => :DOWN, [1, -1] => :DOWN_LEFT, [0, -1] => :LEFT, [-1, -1] => :UP_LEFT,
  }

  # Frames one arrow of a diagonal must stay held alone before it points to its own side, about an
  # eighth of a second, since two arrows let go together are seldom let go in the same frame.
  GRACE_FRAMES = 8

  @steady = nil
  @waited = 0

  # Finds the direction the arrows held point to, past the capture of the wheel's buttons.
  #
  # @return [Symbol, nil] One of DIRECTIONS, nil while no arrow is held or only opposite ones are.
  def self.held
    capture = MGQ_Multiplayer::Capture
    row = (capture.press?(:DOWN) ? 1 : 0) - (capture.press?(:UP) ? 1 : 0)
    column = (capture.press?(:RIGHT) ? 1 : 0) - (capture.press?(:LEFT) ? 1 : 0)
    STEPS[[row, column]]
  end

  # Finds the direction the arrows held point to as steady as a wheel needs it: one arrow left of
  # a diagonal still points to the diagonal for GRACE_FRAMES, so letting go of both never lands on
  # one side. Called once a frame by the wheel that is open.
  #
  # @return [Symbol, nil] One of DIRECTIONS, nil while no arrow is held or only opposite ones are.
  def self.steady
    raw = held
    if raw && side_of?(raw, @steady) && (@waited += 1) < GRACE_FRAMES
      return @steady
    end

    @waited = 0
    @steady = raw
  end

  # Forgets the direction pointed to, as a wheel opens.
  def self.reset
    @steady = nil
    @waited = 0
  end

  # Reports whether a direction is one of the two sides of a diagonal.
  #
  # @param side [Symbol] The direction.
  # @param diagonal [Symbol, nil] The diagonal.
  # @return [Boolean] Whether it is.
  def self.side_of?(side, diagonal)
    return false unless diagonal && side != diagonal

    row, column = STEPS.key(side)
    diagonal_row, diagonal_column = STEPS.key(diagonal)
    diagonal_row != 0 && diagonal_column != 0 && (row == 0 ? column == diagonal_column : column == 0 && row == diagonal_row)
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
