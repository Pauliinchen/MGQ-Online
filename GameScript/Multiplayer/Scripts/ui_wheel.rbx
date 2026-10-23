#----------------------------------------------------------------
#  ui_wheel.rbx
#
#  Changelog:
#      Paulinchen  2026-10-23: Left the pointing, the placing and the wheels' rules to C#
#      Paulinchen  2026-10-11: Drew a close hint under both wheels
#      Paulinchen  2026-10-06: Waited a moment before an arrow let go of a diagonal counts
#                            - Spread a wheel's choices evenly over the directions the arrows point to
#                            - Created
#
#----------------------------------------------------------------

# What the wheels on the map share, the action wheel (ui_actions.rbx) and the emote wheel
# (ui_emotes.rbx), whose rules C# keeps (WheelModel in MGQOnline.Game's Ui/Wheels): the arrows held
# point like a joystick, one arrow to its side and two to the diagonal between them, and nowhere
# while none is held. A wheel spreads its choices evenly over those directions (places), picks what
# lies in the direction pointed to, and keeps it picked once the arrows are let go. Each wheel's
# owner hands over its frame where it read the keys, and takes the wheel's events.
module MGQ_MpWheel
  # The directions the arrows can point to, clockwise from the top, WheelDirection in C#.
  DIRECTIONS = [:UP, :UP_RIGHT, :RIGHT, :DOWN_RIGHT, :DOWN, :DOWN_LEFT, :LEFT, :UP_LEFT]

  # The wheels' event, WheelModel.EventTopic.
  EVENT = "ui.wheel"

  # Closes a wheel from outside, WheelModel.CloseTopic.
  CLOSE = "ui.wheel.close"

  # Places a count of choices, WheelModel.PlacesTopic.
  PLACES = "ui.wheel.places"

  # What a wheel's event names the action wheel's middle choice, WheelModel.Center.
  CENTER = -1

  # The bits of the arrows held, WheelArrows in C#.
  ARROW_BITS = { :UP => 1, :DOWN => 2, :LEFT => 4, :RIGHT => 8 }

  # Height of the hint under a wheel, see draw_hint.
  HINT_HEIGHT = 18

  # The places of each count of choices C# answered.
  @places = {}

  # Hands a wheel its frame on the map: whether the map leaves it free, its hotkey, and while it is
  # open cancel, confirm and the arrows held, past the capture of the wheel's buttons.
  #
  # @param name [String] The wheel's name in the tick, "wheel" or "emotes".
  # @param free [Boolean, String] true, or why the wheel may not show, which closes it.
  # @param key [Boolean] Whether its hotkey went down.
  # @param count [Integer] How many choices it has.
  # @param open [Boolean] Whether it is open, so the buttons are read.
  def self.put(name, free, key, count, open)
    capture = MGQ_Multiplayer::Capture
    arrows = 0
    ARROW_BITS.each { |button, bit| arrows |= bit if open && capture.press?(button) }
    cancel = open && MGQ_MpUi.cancel?
    confirm = open && capture.trigger?(:C)
    MGQ_MpUi::Tick.put(name, [free, key ? true : false, cancel ? true : false, confirm ? true : false, arrows, count])
  end

  # Spreads a wheel's choices evenly over DIRECTIONS, clockwise from the top, mirror-symmetric for
  # every count, as C# places them; asked once per count.
  #
  # @param count [Integer] How many choices the wheel has, at most DIRECTIONS.size.
  # @return [Array<Symbol>] Each choice's direction, in the choices' order; none while the bridge is closed.
  def self.places(count)
    return @places[count] if @places.key?(count)

    answer = MGQ_Multiplayer::Bridge.call(PLACES, [count])
    return [] unless answer

    @places[count] = answer.map { |direction| DIRECTIONS[direction] }
  end

  # Names the pick of a wheel's event.
  #
  # @param selected [Integer, nil] The direction's number, CENTER for the middle, nil for none.
  # @param center [Object] What the middle is named.
  # @return [Symbol, Object, nil] One of DIRECTIONS, the middle's name, or nil.
  def self.direction_of(selected, center)
    selected == CENTER ? center : selected && DIRECTIONS[selected]
  end

  # Draws the hint under a wheel, HINT_HEIGHT high: what closes it, Esc, the numpad's 0 and the
  # wheel's hotkey, in the style's tiny size and heading color, whole even when a rebound key's
  # longer name makes it wide.
  #
  # @param bitmap [Bitmap] The wheel's picture.
  # @param x [Integer] The hint's left.
  # @param y [Integer] The hint's top.
  # @param width [Integer] The hint's width.
  # @param action [Symbol] The wheel's hotkey, see MGQ_MpHotkeys.label.
  def self.draw_hint(bitmap, x, y, width, action)
    style = MGQ_MpUi::Style
    style.draw_hint(bitmap, x, y, width, HINT_HEIGHT, style.close_hint(MGQ_MpHotkeys.label(action)), style::TINY_SIZE, style::HEADING)
  end
end
