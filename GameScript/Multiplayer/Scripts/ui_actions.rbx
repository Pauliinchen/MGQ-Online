#----------------------------------------------------------------
#  ui_actions.rbx
#
#  Changelog:
#      Paulinchen  2026-10-12: Read the map's viewports and character sprites through MGQ_MpGame
#      Paulinchen  2026-10-11: Framed the wheel's boxes in the preset's colors, the picked one lit inside its frame, drawn anew once the preset changes
#                            - Drew the wheel and the line above the player's own head in the shared style, fading them in and out, with the hint under the ring the wheels share, which names Esc, the numpad's 0 and the wheel's hotkey
#                            - Made the line half the screen wide and cut it and a choice's text to their room, the line without its seconds once they make it too wide
#                            - Drew the wheel's hint whole through the shared style, so a rebound key's longer name never cuts it, and its icons through MGQ_MpUi.draw_icon
#                            - Showed the seconds left after a doing in the line above the player's own head, which a script names with the moment it lapses, also counted from a moment in frames
#                            - Left a line or doing that fails out of the line, logged once, instead of losing the line and the wheel
#                            - Told whether a screen of the mod lies over the map, which the edge arrows ask
#      Paulinchen  2026-10-08: Closed with the numpad's 0 through MGQ_MpUi.cancel?, also with Num Lock off
#                            - Listed the choices of another player's menu and of the player's own here, which the World overview and the chat share
#      Paulinchen  2026-10-07: Took the icon rect, white and the depths from MGQ_MpUi
#                            - Logged the action wheel opening with its choices and closing with why, each choice taken or refused, a wheel key that went elsewhere, and the line above the player's head
#      Paulinchen  2026-10-06: Kept the choice pointed at last once the arrows are let go, instead of going back to the middle, and the diagonal while its arrows are let go one after the other
#                            - Built the wheel's ring from the choices the scripts register by order, spread over the arrows' eight directions, instead of four fixed sides
#                            - Pointed at a choice with the arrows held, like a joystick, and at the middle while no arrow or a diagonal is held
#      Paulinchen  2026-10-04: Renamed from mp_actions.rbx
#      Paulinchen  2026-10-03: Took the wheel's choices, the own line and what lies over the map from what the later scripts register, and kept their offers for the World overview and the notification box
#                            - Asked MGQ_MpOverworldSync whether the map is quiet or the player free on it
#                            - Sent messages, showed notices and read the world, the own id and the own seat through MGQ_MpOverworldSync
#                            - Logged through MGQ_MpLog
#                            - Read the bound keys through MGQ_MpHotkeys, renamed from MGQ_MpKeys
#      Paulinchen  2026-10-02: Opened the wheel with the key the player bound, and named the bound keys of the chat and the World overview
#                            - Followed the map and its sprites through core_hooks.rbx
#                            - Took a choice through MGQ_MpActions.choose, which the World overview shares
#      Paulinchen  2026-10-01: Showed a globe in a small square box in the wheel's middle instead of its text
#                            - Refused to invite into a full party or to accept the invite of one
#                            - Challenged the players nearby to a duel, or accepted their challenge, on the wheel's right
#                            - Opened the World overview from the wheel's middle, where the wheel now opens
#                            - Left the keys to the World overview while it is open, whose B closes it
#                            - Let only the party's leader invite
#                            - Showed the wait for the party's story scene above the player's own head
#      Paulinchen  2026-09-30: Left the chat to ui_chat.rbx, keeping the wheel's chat choice
#                            - Left the party to coop.rbx, keeping the wheel's party choices
#                            - Registered with overworld_sync.rbx for its messages instead of being asked by overworld.rbx
#                            - Moved into Patch/Multiplayer/Scripts as ui_actions.rbx, which Multiplayer.rb loads
#                            - Found the party's leader, the member who made the party
#                            - Gave the chat box a blinking cursor, moved with the arrows, Home and End, with Delete
#      Paulinchen  2026-09-29: Told overworld.rbx while the player types in the chat
#                            - Showed the chat box's text as it is typed
#                            - Left room right above the player's head for their ping
#                            - Added chat, opened with T or the wheel: a bubble above the sender and a log at the bottom left
#                            - Opened an action wheel with B, which invites, accepts, leaves the party, and holds chat and duels
#                            - Created
#
#----------------------------------------------------------------

# The action wheel on the map: its key (B unless the player binds another, see core_hotkeys.rbx) opens it
# around the player. The scripts after this one fill its ring (wheel_choice) and its middle
# (wheel_center), say the line above the player's own head (own_line_from, own_doing_from) and add
# what they offer between two players to the World overview and the notification box (offer). It
# builds on ui_wheel.rbx, which reads the arrows, and overworld_sync.rbx, which knows the other
# players.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpActions
  # Pixels kept free right above the player's head, where overworld.rbx shows their ping.
  HEAD_ROOM = 16

  # A choice of the action wheel or of a player's menu in the World overview.
  #
  # @!attribute text [String] What the wheel shows.
  # @!attribute run [Proc, nil] What choosing it does, nil while it cannot be chosen.
  # @!attribute refusal [String, nil] The notice for choosing it while it cannot be chosen.
  # @!attribute icon [Integer, nil] The icon the wheel shows instead of the text, nil for the text.
  # @!attribute leaves [Boolean, nil] Whether choosing it closes the World overview too.
  Option = Struct.new(:text, :run, :refusal, :icon, :leaves)

  # A line of the notification box: an invite, or a message.
  #
  # @!attribute key [Object] What it is about; a newer message with the same key replaces it.
  # @!attribute text [String] What it says.
  # @!attribute color [Color] Its text's color.
  # @!attribute action [String, nil] What accepting it does, such as "Accept"; nil for a message and
  #   for an invite that cannot be accepted here.
  # @!attribute take [Proc, nil] Accepts it, nil when action is.
  # @!attribute decline [Proc, nil] Declines it, nil for a message.
  # @!attribute mark [Object] What the invite is, which tells a new one from the one the player declined.
  Notice = Struct.new(:key, :text, :color, :action, :take, :decline, :mark)

  # The wheel's middle choice while no script fills it.
  NO_OPTION = Option.new("", nil, nil)

  # Color of the line above the player's own head, the style's own color, which the invites'
  # notices share.
  LINE_COLOR = MGQ_MpUi::Style::OWN

  # How the seconds left are written after a doing in the line above the player's own head.
  TIME_LEFT = " (#{MGQ_MpUi::SECONDS_TEXT})"

  @offers = []
  @choices = []
  @center = nil
  @lines = []
  @doings = []
  @covers = []

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "actions"

  # Takes a choice of the wheel or the World overview, or tells why it cannot be taken.
  #
  # @param option [Option, nil] The choice.
  # @yield Closes what offered the choice, before the choice runs.
  def self.choose(option)
    return unless option

    unless option.run
      log("refused #{option_name(option)}: #{option.refusal || 'it cannot be chosen now'}")
      Sound.play_buzzer
      MGQ_MpOverworldSync.notice(option.refusal) if option.refusal
      return
    end

    log("chose #{option_name(option)}")
    Sound.play_ok
    yield if block_given?
    option.run.call
  end

  # Names a choice for the log.
  #
  # @param option [Option] The choice.
  # @return [String] Its text, or its icon for a choice the wheel shows as one.
  def self.option_name(option)
    text = option.text.to_s
    return "\"#{text}\"" unless text.empty?

    option.icon ? "the choice with icon #{option.icon}" : "nothing"
  rescue
    "a choice"
  end

  # Closes the wheel once the map is left. Called by overworld_sync.rbx every frame in every
  # scene.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    Wheel.close(in_world ? "the map was left" : "no world is open") unless in_world && SceneManager.scene.is_a?(Scene_Map)
  end

  # Adds what a script offers between two players, such as party invites or duels, to the World
  # overview and the notification box.
  #
  # @param offers [Module] Answers call_of(peer) with the text and color of the other player's
  #   invite that reaches the player, notice_of(peer) with its Notice, peer_option(peer) with the
  #   Option of the other player's menu, and own_options with the Options of the player's own
  #   menu; nil or none where it has nothing.
  def self.offer(offers)
    @offers << offers
  end

  # Lists the choices of another player's menu: what every script offers with them, in the order
  # the scripts registered.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  # @return [Array<Option>] The choices, none when no script offers anything.
  def self.peer_options(peer)
    @offers.map { |offers| offers.peer_option(peer) }.compact
  end

  # Lists the choices of the player's own menu, such as leaving the party.
  #
  # @return [Array<Option>] The choices, none when no script offers anything.
  def self.own_options
    @offers.map(&:own_options).flatten.compact
  end

  # Lists what the scripts offer between two players, in the order they registered.
  #
  # @return [Array<Module>] See offer.
  def self.offers
    @offers
  end

  # Adds a choice to the action wheel's ring, which spreads its choices over the directions the
  # arrows point to (MGQ_MpWheel.places). A ring holds one choice per direction at most.
  #
  # @param order [Integer] Its place on the ring, clockwise from the top: the lower, the earlier.
  # @yieldreturn [Option] The choice the wheel shows now.
  def self.wheel_choice(order, &option)
    if @choices.size >= MGQ_MpWheel::DIRECTIONS.size
      log("action wheel: no room for a choice of order #{order}")
      return
    end

    @choices << [order, @choices.size, option]
    @choices.sort_by! { |place, added, _| [place, added] }
  end

  # Fills the action wheel's middle, which is picked while the arrows point at no choice.
  #
  # @yieldreturn [Option] The choice the wheel shows there now.
  def self.wheel_center(&option)
    @center = option
  end

  # The directions of the ring's choices, in their order.
  #
  # @return [Array<Symbol>] Directions of MGQ_MpWheel::DIRECTIONS.
  def self.wheel_places
    MGQ_MpWheel.places(@choices.size)
  end

  # Lets a script say the line above the player's own head, in place of every other.
  #
  # @yieldreturn [String, nil] The line, nil while the script has none.
  def self.own_line_from(&line)
    @lines << line
  end

  # Lets a script name what the player is doing in the line above their own head, such as
  # "Inviting to a party". The line joins what every script names, each with its seconds left.
  #
  # @yieldreturn [String, Array, nil] What the player is doing, or the doing with the Time it
  #   lapses (see lapse_in), nil while nothing.
  def self.own_doing_from(&doing)
    @doings << doing
  end

  # Tells the moment a number of frames from now, for a timer counted in frames.
  #
  # @param frames [Integer] The frames left; 0 or less lapse now.
  # @return [Time] The moment.
  def self.lapse_in(frames)
    Time.now + frames / MGQ_MpUi::FRAMES_PER_SECOND.to_f
  end

  # Tells the moment some frames after a moment lapse, for a timer that counts frames from a
  # Graphics.frame_count.
  #
  # @param since [Integer] The moment's Graphics.frame_count.
  # @param frames [Integer] The frames it lasts.
  # @return [Time] The moment, now or past once they passed.
  def self.lapse_at(since, frames)
    lapse_in(since + frames - Graphics.frame_count)
  end

  # Writes a doing with its seconds left, such as "Asking Player A to teleport (45 s)"; the text
  # alone once it lapsed or has no time. A lapse that is no Time, such as a frame count by
  # mistake, counts as none, so one wrong caller cannot break the line.
  #
  # @param doing [String, Array] The doing, see own_doing_from.
  # @param now [Time] The moment the seconds count from.
  # @return [Array(String, String)] The text alone, the log's key, and the text as shown.
  def self.doing_text(doing, now = Time.now)
    text, lapse = doing.is_a?(Array) ? doing : [doing, nil]
    seconds = lapse.is_a?(Time) ? (lapse - now).ceil : 0
    [text.to_s, seconds > 0 ? "#{text}#{TIME_LEFT % seconds}" : text.to_s]
  end

  # Asks a script's block for the line or doing it names, leaving out one that fails, logged once.
  #
  # @param block [Proc] The block.
  # @return [String, Array, nil] What it names.
  def self.named_by(block)
    block.call
  rescue => e
    log_once(block, "a line or doing failed: #{e.class}: #{e.message}")
    nil
  end

  # Lets a script tell that one of its screens lies over the map, which the wheel leaves the
  # buttons to.
  #
  # @yieldparam wheel_key [Boolean] Whether the wheel key went down this frame, which may close the screen.
  # @yieldreturn [Boolean] Whether the screen is open.
  def self.cover(&open)
    @covers << open
  end

  # Reports whether a screen of the mod lies over the map: the action wheel, or a screen that
  # registered with cover, such as the emote wheel, the chat box or the World overview.
  #
  # @return [Boolean] Whether one does.
  def self.covered?
    Wheel.open? || @covers.any? { |open| open.call(false) }
  end

  # Tells what the line above the player's own head says, if anything: a script's line, else the
  # doings with their seconds left, and the same without the seconds, which the line falls back
  # to once the seconds make it too wide. The seconds stay out of the log, which says the line
  # once.
  #
  # @return [Array(String, String), nil] The line with the seconds and without them, nil for none.
  def self.own_lines
    return nil unless MGQ_MpOverworldSync.in_world? && !Wheel.open?

    line = key = @lines.map { |block| named_by(block) }.compact.first
    unless line
      named = @doings.map { |block| named_by(block) }.compact
      # The clock is read after the doings named their lapses, so none lies a moment ahead of it.
      now = Time.now
      doings = named.map { |doing| doing_text(doing, now) }
      key = doings.empty? ? nil : "#{doings.map { |pair| pair[0] }.join(', ')} . . ."
      line = doings.empty? ? nil : "#{doings.map { |pair| pair[1] }.join(', ')} . . ."
    end
    if key != @own_line
      log(key ? "the line above the player's head says: #{key}" : "the line above the player's head is gone")
      @own_line = key
    end
    line ? [line, key] : nil
  end

  # Tells what the line above the player's own head says, with the seconds left, see own_lines.
  #
  # @return [String, nil] The line.
  def self.own_line
    lines = own_lines
    lines && lines[0]
  end

  # The action wheel's choices, by the direction that picks them.
  #
  # @return [Hash{Symbol => Option}] The middle's choice under Wheel::CENTER, then the ring's under
  #   their directions.
  def self.wheel_options
    options = { Wheel::CENTER => @center ? @center.call : NO_OPTION }
    wheel_places.zip(@choices) { |direction, (_, _, option)| options[direction] = option.call }
    options
  end

  # Opens, steers or closes the action wheel on the map, but leaves the keys to a screen that lies
  # over it, such as the chat box. Called by the map every frame, so a press of the key is seen once.
  def self.on_map
    wheel_key = MGQ_MpHotkeys.pressed?(:wheel)
    unless MGQ_MpOverworldSync.in_world? && MGQ_MpOverworldSync.map_quiet?
      log("action wheel stays shut: #{MGQ_MpOverworldSync.in_world? ? 'an event runs or a message shows' : 'no world is open'}") if wheel_key
      Wheel.close("an event started or a message shows")
      return
    end
    if @covers.any? { |open| open.call(wheel_key) }
      log("the wheel key went to the screen over the map") if wheel_key
      return
    end

    if Wheel.open?
      Wheel.update(wheel_key)
    elsif wheel_key
      Wheel.open
    end
  rescue => e
    log("action wheel failed: #{e.class}: #{e.message}")
    Wheel.close("it failed")
  end

  # The action wheel: a ring of choices around the player and one over them, taken with the game's
  # confirm button. It opens on the middle; the arrows held point at a choice, like a joystick, which
  # stays picked once they are let go, and a direction without a choice picks the middle again. It
  # holds the buttons while open, so the player stands still and the game's menu stays shut.
  module Wheel
    # The choice over the player.
    CENTER = :CENTER

    @open = false
    @selected = CENTER

    # Reports whether the wheel is open.
    #
    # @return [Boolean] Whether it is.
    def self.open?
      @open
    end

    # The direction whose choice is picked.
    #
    # @return [Symbol] One of MGQ_MpWheel::DIRECTIONS, or CENTER.
    def self.selected
      @selected
    end

    # Opens the wheel on its middle choice.
    def self.open
      @selected = CENTER
      @open = true
      MGQ_MpWheel.reset
      MGQ_Multiplayer::Capture.start(:wheel)
      MGQ_MpActions.log("action wheel opened: #{choices_text}")
      Sound.play_cursor
    end

    # Lists the wheel's choices for the log, those that cannot be taken marked.
    #
    # @return [String] Each choice by its direction.
    def self.choices_text
      MGQ_MpActions.wheel_options.map do |direction, option|
        "#{direction} #{MGQ_MpActions.option_name(option)}#{option.run ? '' : ' (refused)'}"
      end.join(", ")
    rescue => e
      "unreadable (#{e.class})"
    end

    # Closes the wheel, if it is open, and gives the buttons back.
    #
    # @param reason [String, nil] Why, for the log.
    def self.close(reason = nil)
      return unless @open

      @open = false
      MGQ_Multiplayer::Capture.stop(:wheel)
      MGQ_MpActions.log("action wheel closed#{reason ? ": #{reason}" : ''}")
    end

    # Picks the choice the arrows held point to, the middle for a direction without one, keeps the
    # pick while no arrow is held, takes the picked choice on confirm, and closes on cancel or the
    # wheel key.
    #
    # @param pressed [Boolean] Whether the wheel key went down this frame.
    def self.update(pressed)
      if pressed || MGQ_MpUi.cancel?
        close(pressed ? "its key" : "cancel")
        Sound.play_cancel
        return
      end

      held = MGQ_MpWheel.steady
      pointed = held.nil? ? @selected : MGQ_MpActions.wheel_places.include?(held) ? held : CENTER
      Sound.play_cursor if pointed != @selected
      @selected = pointed

      MGQ_MpActions.choose(MGQ_MpActions.wheel_options[@selected]) { close("took the #{@selected} choice") } if MGQ_Multiplayer::Capture.trigger?(:C)
    end
  end
end

# The line above the player's own head: what the scripts say there, such as an invite to a party,
# a trade offer or the wait for the party's story, see MGQ_MpActions.own_line. Half the screen
# wide, cut to that, in the style's own color, fading in and out.
class Sprite_MpOwnLine < Sprite
  # How many times the line fits across the screen.
  SCREEN_SHARE = 2

  # Height of the line.
  HEIGHT = 24

  # Creates the line, empty.
  #
  # @param viewport [Viewport] The map's viewport of characters.
  def initialize(viewport)
    super(viewport)
    width = Graphics.width / SCREEN_SHARE
    self.bitmap = Bitmap.new(width, HEIGHT)
    self.ox = width / 2
    self.z = MGQ_MpUi::Z[:labels]
    @motion = MGQ_MpUi::Motion.new(self)
    @shown = nil
  end

  # Draws the line, if it changed, above the player's sprite, fading it in, and fades it out once
  # there is none, keeping its picture until it is gone.
  #
  # @param sprite [Sprite_Character, nil] The player's sprite.
  def show(sprite)
    lines = MGQ_MpActions.own_lines
    unless lines && sprite
      @motion.hide
      @motion.update
      return
    end

    @motion.place(sprite.x, sprite.y - sprite.height - MGQ_MpActions::HEAD_ROOM - HEIGHT)
    @motion.show
    draw(lines) unless lines == @shown
    @motion.update
  end

  # Draws the line: with its seconds while that fits the picture, else without them, cut to the
  # picture's width, so a cut only ever loses the end of a text, never a countdown that fits.
  #
  # @param lines [Array(String, String)] The line with the seconds and without them.
  def draw(lines)
    style = MGQ_MpUi::Style
    @shown = lines
    bitmap.clear
    style.use_font(bitmap, style::TEXT_SIZE, style::OWN)
    text = bitmap.text_size(lines[0]).width <= bitmap.width ? lines[0] : MGQ_MpUi.cut(bitmap, lines[1], bitmap.width)
    bitmap.draw_text(0, 0, bitmap.width, HEIGHT, text, 1)
  end

  # Frees the line's picture.
  def dispose
    bitmap.dispose
    super
  end
end

# The action wheel around the player: the ring's boxes in a column left and right of them and one
# above and below, a square one with an icon over them, the picked one lit, those that cannot be
# taken dim, and under them the hint that names what closes the wheel. The boxes are laid out
# from the directions the ring has, so the picture fits them. Drawn in the shared style, it fades
# in and out.
class Sprite_MpActionWheel < Sprite
  # Width of a choice's box.
  BOX_WIDTH = 200

  # Height of a choice's box.
  BOX_HEIGHT = 26

  # Width of the middle choice's box, square and narrower than the player's sprite, so it never
  # reaches the boxes left and right of the player.
  CENTER_WIDTH = BOX_HEIGHT

  # Size of an icon in the game's icon set.
  ICON_SIZE = MGQ_MpUi::ICON_SIZE

  # Room between a box's side edges and its text.
  TEXT_MARGIN = 4

  # Room kept free around the player's sprite, which is 32 by 48 pixels, and between boxes.
  GAP = 4

  # Height of the player's sprite.
  PLAYER_HEIGHT = 48

  # Half the width of the player's sprite, plus the gap.
  PLAYER_SIDE = 20

  # The column and the row of each direction beside the player: -1 for the left column and 1 for
  # the right; -1 for the row above the side's middle, 0 for the middle and 1 for the row below.
  # Up and down sit above and below every box beside the player.
  SIDES = {
    :UP_RIGHT => [1, -1], :RIGHT => [1, 0], :DOWN_RIGHT => [1, 1],
    :DOWN_LEFT => [-1, 1], :LEFT => [-1, 0], :UP_LEFT => [-1, -1],
  }

  # Lays the boxes out around the player.
  #
  # @param directions [Array<Symbol>] The directions of the ring's choices.
  # @return [Hash{Symbol => Rect}] Each box by its direction, the middle's under
  #   MGQ_MpActions::Wheel::CENTER, measured from the middle of the player's feet.
  def self.layout(directions)
    middle = -(PLAYER_HEIGHT + BOX_HEIGHT) / 2
    boxes = { MGQ_MpActions::Wheel::CENTER => Rect.new(-CENTER_WIDTH / 2, middle, CENTER_WIDTH, BOX_HEIGHT) }
    directions.each do |direction|
      column, row = SIDES[direction]
      next unless column

      x = column > 0 ? PLAYER_SIDE : -PLAYER_SIDE - BOX_WIDTH
      boxes[direction] = Rect.new(x, middle + row * (BOX_HEIGHT + GAP), BOX_WIDTH, BOX_HEIGHT)
    end
    beside = boxes.values
    top = [-PLAYER_HEIGHT - MGQ_MpActions::HEAD_ROOM, beside.map { |box| box.y }.min].min - GAP - BOX_HEIGHT
    bottom = [0, beside.map { |box| box.y + box.height }.max].max + GAP
    boxes[:UP] = Rect.new(-BOX_WIDTH / 2, top, BOX_WIDTH, BOX_HEIGHT) if directions.include?(:UP)
    boxes[:DOWN] = Rect.new(-BOX_WIDTH / 2, bottom, BOX_WIDTH, BOX_HEIGHT) if directions.include?(:DOWN)
    boxes
  end

  # Creates the wheel, hidden.
  #
  # @param viewport [Viewport] The map's topmost viewport.
  def initialize(viewport)
    super(viewport)
    self.z = MGQ_MpUi::Z[:wheels]
    @motion = MGQ_MpUi::Motion.new(self)
    @shown = nil
    @places = nil
    @boxes = {}
    @hint = nil
  end

  # Draws the wheel around the player's sprite while it is open, if it changed, and fades it in;
  # fades it out once it closed, keeping its picture until it is gone.
  #
  # @param sprite [Sprite_Character, nil] The player's sprite.
  def show(sprite)
    unless MGQ_MpActions::Wheel.open? && sprite
      @motion.hide
      @motion.update
      return
    end

    arrange(MGQ_MpActions.wheel_places)
    @motion.place(sprite.x, sprite.y)
    @motion.show
    options = MGQ_MpActions.wheel_options
    drawn = [MGQ_MpActions::Wheel.selected, MGQ_MpUi::Theme.serial] + options.map { |direction, option| [direction, option.text, option.icon, !option.run.nil?] }
    draw(options, drawn) unless drawn == @shown
    @motion.update
  end

  # Draws the boxes and the hint under them.
  #
  # @param options [Hash{Symbol => MGQ_MpActions::Option}] The choices by their direction.
  # @param drawn [Array] What the picture then shows, which show compares.
  def draw(options, drawn)
    style = MGQ_MpUi::Style
    @shown = drawn
    bitmap.clear
    options.each { |direction, option| draw_box(direction, option) }
    MGQ_MpWheel.draw_hint(bitmap, @hint.x, @hint.y, @hint.width, :wheel)
  end

  # Lays the boxes out, with the hint's room under them, and sizes the picture to them, when the
  # ring's directions changed.
  #
  # @param places [Array<Symbol>] The directions of the ring's choices.
  def arrange(places)
    return if places == @places

    @places = places
    @boxes = self.class.layout(places)
    left = @boxes.values.map { |box| box.x }.min
    top = @boxes.values.map { |box| box.y }.min
    right = @boxes.values.map { |box| box.x + box.width }.max
    bottom = @boxes.values.map { |box| box.y + box.height }.max
    @boxes.each_value do |box|
      box.x -= left
      box.y -= top
    end
    @hint = Rect.new(0, bottom - top, right - left, MGQ_MpWheel::HINT_HEIGHT)
    bitmap.dispose if bitmap
    self.bitmap = Bitmap.new(right - left, bottom - top + MGQ_MpWheel::HINT_HEIGHT)
    self.ox = -left
    self.oy = -top
    @shown = nil
  end

  # Draws one choice's box in its frame, lit while picked, its text cut to the box.
  #
  # @param direction [Symbol] The direction that picks it.
  # @param option [MGQ_MpActions::Option] The choice.
  def draw_box(direction, option)
    box = @boxes[direction]
    return unless box

    style = MGQ_MpUi::Style
    if direction == MGQ_MpActions::Wheel.selected
      bitmap.fill_rect(box.x, box.y, box.width, box.height, style::PICKED)
      style.draw_frame(bitmap, box.x, box.y, box.width, box.height)
    else
      style.draw_box(bitmap, box.x, box.y, box.width, box.height)
    end
    return draw_icon(option, box.x + (box.width - ICON_SIZE) / 2, box.y + (box.height - ICON_SIZE) / 2) if option.icon

    style.use_font(bitmap, style::TEXT_SIZE, option.run ? style::TEXT : style::DIM)
    room = box.width - 2 * TEXT_MARGIN
    bitmap.draw_text(box.x + TEXT_MARGIN, box.y, room, box.height, MGQ_MpUi.cut(bitmap, option.text, room), 1)
  end

  # Draws a choice's icon, dim while it cannot be taken.
  #
  # @param option [MGQ_MpActions::Option] The choice.
  # @param x [Integer] The icon's left edge.
  # @param y [Integer] The icon's top edge.
  def draw_icon(option, x, y)
    MGQ_MpUi.draw_icon(bitmap, option.icon, x, y, ICON_SIZE, option.run ? MGQ_MpUi::Motion::OPAQUE : MGQ_MpUi::Style::DIM_OPACITY)
  end

  # Frees the wheel's picture.
  def dispose
    bitmap.dispose if bitmap
    super
  end
end

# What this script takes part in of the world's messages, through overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpActions.tick(in_world) }
rescue => e
  MGQ_MpActions.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

# Game hooks, through core_hooks.rbx.

begin
  # After the map's update, the action wheel. The game checks its own keys there too, only while no
  # scene change is in the way.
  MGQ_MpHooks.after(Scene_Map, :update_scene, "ui_actions") { MGQ_MpActions.on_map unless scene_changing? }

  # After the map's sprites, the line above the player's own head and the action wheel around them.
  MGQ_MpHooks.after(Spriteset_Map, :update, "ui_actions") do
    @mgq_mp_own_line ||= Sprite_MpOwnLine.new(MGQ_MpGame.get(self, :viewport1))
    @mgq_mp_wheel ||= Sprite_MpActionWheel.new(MGQ_MpGame.get(self, :viewport3))
    player = MGQ_MpGame.get(self, :character_sprites).find { |sprite| sprite.character.equal?($game_player) }
    @mgq_mp_own_line.show(player)
    @mgq_mp_wheel.show(player)
  end

  MGQ_MpHooks.before(Spriteset_Map, :dispose, "ui_actions") do
    [@mgq_mp_own_line, @mgq_mp_wheel].compact.each { |sprite| sprite.dispose }
    @mgq_mp_own_line = @mgq_mp_wheel = nil
  end
rescue => e
  MGQ_MpActions.log("hooks FAILED: #{e.class}: #{e.message}")
end
