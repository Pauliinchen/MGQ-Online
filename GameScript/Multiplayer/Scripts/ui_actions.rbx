#----------------------------------------------------------------
#  ui_actions.rbx
#
#  Changelog:
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

  # The wheel's choice in a direction no script fills.
  NO_OPTION = Option.new("", nil, nil)

  # Color of the line above the player's own head, which invites share.
  LINE_COLOR = Color.new(255, 224, 128)

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
      Sound.play_buzzer
      MGQ_MpOverworldSync.notice(option.refusal) if option.refusal
      return
    end

    Sound.play_ok
    yield if block_given?
    option.run.call
  end

  # Closes the wheel once the map is left. Called by overworld_sync.rbx every frame in every
  # scene.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    Wheel.close unless in_world && SceneManager.scene.is_a?(Scene_Map)
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
  # "Inviting to a party". The line joins what every script names.
  #
  # @yieldreturn [String, nil] What the player is doing, nil while nothing.
  def self.own_doing_from(&doing)
    @doings << doing
  end

  # Lets a script tell that one of its screens lies over the map, which the wheel leaves the
  # buttons to.
  #
  # @yieldparam wheel_key [Boolean] Whether the wheel key went down this frame, which may close the screen.
  # @yieldreturn [Boolean] Whether the screen is open.
  def self.cover(&open)
    @covers << open
  end

  # Tells what the line above the player's own head says, if anything.
  #
  # @return [String, nil] The line.
  def self.own_line
    return nil unless MGQ_MpOverworldSync.in_world? && !Wheel.open?

    line = @lines.map(&:call).compact.first
    return line if line

    doing = @doings.map(&:call).compact
    doing.empty? ? nil : "#{doing.join(', ')} . . ."
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
      Wheel.close
      return
    end
    return if @covers.any? { |open| open.call(wheel_key) }

    if Wheel.open?
      Wheel.update(wheel_key)
    elsif wheel_key
      Wheel.open
    end
  rescue => e
    log("action wheel failed: #{e.class}: #{e.message}")
    Wheel.close
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
      Sound.play_cursor
    end

    # Closes the wheel, if it is open, and gives the buttons back.
    def self.close
      return unless @open

      @open = false
      MGQ_Multiplayer::Capture.stop(:wheel)
    end

    # Picks the choice the arrows held point to, the middle for a direction without one, keeps the
    # pick while no arrow is held, takes the picked choice on confirm, and closes on cancel or the
    # wheel key.
    #
    # @param pressed [Boolean] Whether the wheel key went down this frame.
    def self.update(pressed)
      if pressed || MGQ_Multiplayer::Capture.trigger?(:B)
        close
        Sound.play_cancel
        return
      end

      held = MGQ_MpWheel.steady
      pointed = held.nil? ? @selected : MGQ_MpActions.wheel_places.include?(held) ? held : CENTER
      Sound.play_cursor if pointed != @selected
      @selected = pointed

      MGQ_MpActions.choose(MGQ_MpActions.wheel_options[@selected]) { close } if MGQ_Multiplayer::Capture.trigger?(:C)
    end
  end
end

# The line above the player's own head while they invite to a party.
class Sprite_MpOwnLine < Sprite
  # Width of the line.
  WIDTH = 320

  # Height of the line.
  HEIGHT = 24

  # Creates the line, empty.
  #
  # @param viewport [Viewport] The map's viewport of characters.
  def initialize(viewport)
    super(viewport)
    self.bitmap = Bitmap.new(WIDTH, HEIGHT)
    self.ox = WIDTH / 2
    self.z = 250
    @shown = nil
  end

  # Draws the line, if it changed, above the player's sprite.
  #
  # @param sprite [Sprite_Character, nil] The player's sprite.
  def show(sprite)
    text = MGQ_MpActions.own_line
    self.visible = !text.nil? && !sprite.nil?
    return unless visible

    self.x = sprite.x
    self.y = sprite.y - sprite.height - MGQ_MpActions::HEAD_ROOM - HEIGHT
    return if text == @shown

    @shown = text
    bitmap.clear
    bitmap.font.size = 18
    bitmap.font.outline = true
    bitmap.font.color = MGQ_MpActions::LINE_COLOR
    bitmap.draw_text(0, 0, WIDTH, HEIGHT, text, 1)
  end

  # Frees the line's picture.
  def dispose
    bitmap.dispose
    super
  end
end

# The action wheel around the player: the ring's boxes in a column left and right of them and one
# above and below, a square one with an icon over them, the picked one lit, those that cannot be
# taken grey. The boxes are laid out from the directions the ring has, so the picture fits them.
class Sprite_MpActionWheel < Sprite
  # Width of a choice's box.
  BOX_WIDTH = 200

  # Height of a choice's box.
  BOX_HEIGHT = 26

  # Width of the middle choice's box, square and narrower than the player's sprite, so it never
  # reaches the boxes left and right of the player.
  CENTER_WIDTH = BOX_HEIGHT

  # Size of an icon in the game's icon set.
  ICON_SIZE = 24

  # Opacity of an icon whose choice cannot be taken.
  GREY_OPACITY = 110

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

  # Background of a box.
  BACK = Color.new(0, 0, 0, 170)

  # Background of the picked box.
  PICKED_BACK = Color.new(48, 96, 176, 220)

  # Color of a choice that can be taken.
  TEXT = Color.new(255, 255, 255)

  # Color of a choice that cannot be taken.
  GREY = Color.new(150, 150, 150)

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
    self.z = 300
    self.visible = false
    @shown = nil
    @places = nil
    @boxes = {}
  end

  # Draws the wheel around the player's sprite while it is open, if it changed.
  #
  # @param sprite [Sprite_Character, nil] The player's sprite.
  def show(sprite)
    self.visible = MGQ_MpActions::Wheel.open? && !sprite.nil?
    return unless visible

    arrange(MGQ_MpActions.wheel_places)
    self.x = sprite.x
    self.y = sprite.y
    options = MGQ_MpActions.wheel_options
    drawn = [MGQ_MpActions::Wheel.selected] + options.map { |direction, option| [direction, option.text, option.icon, !option.run.nil?] }
    return if drawn == @shown

    @shown = drawn
    bitmap.clear
    bitmap.font.size = 18
    bitmap.font.outline = true
    options.each { |direction, option| draw_box(direction, option) }
  end

  # Lays the boxes out and sizes the picture to them, when the ring's directions changed.
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
    bitmap.dispose if bitmap
    self.bitmap = Bitmap.new(right - left, bottom - top)
    self.ox = -left
    self.oy = -top
    @shown = nil
  end

  # Draws one choice's box.
  #
  # @param direction [Symbol] The direction that picks it.
  # @param option [MGQ_MpActions::Option] The choice.
  def draw_box(direction, option)
    box = @boxes[direction]
    return unless box

    picked = direction == MGQ_MpActions::Wheel.selected
    bitmap.fill_rect(box.x, box.y, box.width, box.height, picked ? PICKED_BACK : BACK)
    return draw_icon(option, box.x + (box.width - ICON_SIZE) / 2, box.y + (box.height - ICON_SIZE) / 2) if option.icon

    bitmap.font.color = option.run ? TEXT : GREY
    bitmap.draw_text(box.x + 4, box.y, box.width - 8, box.height, option.text, 1)
  end

  # Draws a choice's icon, faded while it cannot be taken.
  #
  # @param option [MGQ_MpActions::Option] The choice.
  # @param x [Integer] The icon's left edge.
  # @param y [Integer] The icon's top edge.
  def draw_icon(option, x, y)
    source = Rect.new(option.icon % 16 * ICON_SIZE, option.icon / 16 * ICON_SIZE, ICON_SIZE, ICON_SIZE)
    bitmap.blt(x, y, Cache.system("Iconset"), source, option.run ? 255 : GREY_OPACITY)
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
    @mgq_mp_own_line ||= Sprite_MpOwnLine.new(@viewport1)
    @mgq_mp_wheel ||= Sprite_MpActionWheel.new(@viewport3)
    player = @character_sprites.find { |sprite| sprite.character.equal?($game_player) }
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
