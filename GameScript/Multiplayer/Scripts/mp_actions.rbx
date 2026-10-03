#----------------------------------------------------------------
#  mp_actions.rbx
#
#  Changelog:
#      Paulinchen  2026-10-03: Read the bound keys through MGQ_MpHotkeys, renamed from MGQ_MpKeys
#      Paulinchen  2026-10-02: Opened the wheel with the key the player bound, and named the bound keys of the chat and the World overview
#                            - Followed the map and its sprites through mp_hooks.rbx
#                            - Took a choice through MGQ_MpActions.choose, which the World overview shares
#      Paulinchen  2026-10-01: Showed a globe in a small square box in the wheel's middle instead of its text
#                            - Refused to invite into a full party or to accept the invite of one
#                            - Challenged the players nearby to a duel, or accepted their challenge, on the wheel's right
#                            - Opened the World overview from the wheel's middle, where the wheel now opens
#                            - Left the keys to the World overview while it is open, whose B closes it
#                            - Let only the party's leader invite
#                            - Showed the wait for the party's story scene above the player's own head
#      Paulinchen  2026-09-30: Left the chat to mp_chat.rbx, keeping the wheel's chat choice
#                            - Left the party to mp_coop.rbx, keeping the wheel's party choices
#                            - Registered with mp_overworld_sync.rbx for its messages instead of being asked by mp_overworld.rbx
#                            - Moved into Patch/Multiplayer/Scripts as mp_actions.rbx, which Multiplayer.rb loads
#                            - Found the party's leader, the member who made the party
#                            - Gave the chat box a blinking cursor, moved with the arrows, Home and End, with Delete
#      Paulinchen  2026-09-29: Told mp_overworld.rbx while the player types in the chat
#                            - Showed the chat box's text as it is typed
#                            - Left room right above the player's head for their ping
#                            - Added chat, opened with T or the wheel: a bubble above the sender and a log at the bottom left
#                            - Opened an action wheel with B, which invites, accepts, leaves the party, and holds chat and duels
#                            - Created
#
#----------------------------------------------------------------

# The action wheel on the map: its key (B unless the player binds another, see mp_hotkeys.rbx) opens it
# around the player, its party choices go to mp_coop.rbx and its chat choice to mp_chat.rbx. It
# builds on mp_overworld_sync.rbx, which knows the other players.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpActions
  # Pixels kept free right above the player's head, where mp_overworld.rbx shows their ping.
  HEAD_ROOM = 16

  # A choice of the action wheel.
  #
  # @!attribute text [String] What the wheel shows.
  # @!attribute run [Proc, nil] What choosing it does, nil while it cannot be chosen.
  # @!attribute refusal [String, nil] The notice for choosing it while it cannot be chosen.
  # @!attribute icon [Integer, nil] The icon the wheel shows instead of the text, nil for the text.
  Option = Struct.new(:text, :run, :refusal, :icon)

  # The game's globe icon, which stands for the World overview in the wheel's middle.
  WORLD_ICON = 3988

  # Writes a line to the mod's InGame.log.
  #
  # @param message [String] The line.
  def self.log(message)
    MGQ_Multiplayer::Log.write("actions: #{message}")
  rescue
  end

  # Reports whether a world is open, through mp_overworld_sync.rbx.
  #
  # @return [Boolean] Whether it is.
  def self.in_world?
    defined?(MGQ_MpOverworldSync) && MGQ_MpOverworldSync.in_world? ? true : false
  end

  # Shows a notice at the bottom left of the map, through mp_overworld_sync.rbx.
  #
  # @param text [String] The notice.
  def self.notice(text)
    MGQ_MpOverworldSync::Status.notice(text) if defined?(MGQ_MpOverworldSync)
  end

  # Takes a choice of the wheel or the World overview, or tells why it cannot be taken.
  #
  # @param option [Option, nil] The choice.
  # @yield Closes what offered the choice, before the choice runs.
  def self.choose(option)
    return unless option

    unless option.run
      Sound.play_buzzer
      notice(option.refusal) if option.refusal
      return
    end

    Sound.play_ok
    yield if block_given?
    option.run.call
  end

  # Lists the other players of the world, through mp_overworld_sync.rbx.
  #
  # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The players.
  def self.peers
    defined?(MGQ_MpOverworldSync) ? MGQ_MpOverworldSync::Peers.all : []
  end

  # Closes the wheel once the map is left. Called by mp_overworld_sync.rbx every frame in every
  # scene.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    Wheel.close unless in_world && SceneManager.scene.is_a?(Scene_Map)
  end

  # Tells what the line above the player's own head says, if anything.
  #
  # @return [String, nil] The line.
  def self.own_line
    return nil unless in_world? && !Wheel.open?

    story = defined?(MGQ_MpCoopEvents) ? MGQ_MpCoopEvents.own_line : nil
    return story if story

    lines = []
    lines << "Inviting to a party" if MGQ_MpCoop::Party.inviting?
    lines << "Challenging to a duel" if defined?(MGQ_MpBattlesDuel) && MGQ_MpBattlesDuel.inviting?
    lines.empty? ? nil : "#{lines.join(', ')} . . ."
  end

  # The action wheel's choices, by the direction that picks them.
  #
  # @return [Hash{Symbol => Option}] The choices under :CENTER, :UP, :RIGHT, :DOWN and :LEFT.
  def self.wheel_options
    {
      :CENTER => overview_option,
      :UP => join_or_invite_option,
      :RIGHT => duel_option,
      :DOWN => leave_option,
      :LEFT => Option.new("Chat (#{MGQ_MpHotkeys.label(:chat)})", MGQ_MpChat.available? ? lambda { MGQ_MpChat.start_typing } : nil, "Chat needs the keyboard, which cannot reach the game."),
    }
  end

  # The wheel's middle choice: the World overview of mp_world_overview.rbx.
  #
  # @return [Option] The choice.
  def self.overview_option
    overview = defined?(MGQ_MpWorldOverview) ? MGQ_MpWorldOverview : nil
    Option.new("World (#{MGQ_MpHotkeys.label(:overview)})", overview ? lambda { overview.open } : nil, "The World overview is missing.", WORLD_ICON)
  end

  # The wheel's duel choice: accepting the challenge of a player nearby, else challenging the
  # players nearby, through mp_battles_duel.rbx.
  #
  # @return [Option] The choice.
  def self.duel_option
    return Option.new("Duel", nil, "Duels need PvP battles, which are off or out of date.") unless defined?(MGQ_MpBattlesDuel) && MGQ_MpBattlesDuel.available?

    duel = MGQ_MpBattlesDuel
    near = peers.select { |peer| MGQ_MpCoop::Party.near?(peer.state) }
    challenger = near.find { |peer| duel.challenged_by?(peer, false) }
    return Option.new("Accept #{challenger.state['name']}'s duel", lambda { duel.accept(challenger) }, nil) if challenger
    return Option.new("Stop challenging", lambda { duel.stop }, nil) if duel.inviting?

    Option.new("Challenge to a duel", near.empty? ? nil : lambda { duel.invite }, "Nobody is near enough to challenge.")
  end

  # The wheel's party choice: accepting the invite of a player nearby, else inviting the players
  # nearby who are outside the party.
  #
  # @return [Option] The choice.
  def self.join_or_invite_option
    party = MGQ_MpCoop::Party
    near = peers.select { |peer| party.near?(peer.state) && !party.member?(peer.state) }
    inviter = near.find { |peer| peer.state["invite"] == "1" }
    if inviter
      full = party.full?(inviter.state["party"])
      return Option.new("Accept #{inviter.state['name']}'s invite", full ? nil : lambda { party.join(inviter) }, "The party is full.")
    end
    return Option.new("Invite to a party", nil, "Only the party's leader invites.") unless party.may_invite?
    return Option.new("Invite to a party", nil, "The party is full.") if party.full?

    Option.new("Invite to a party", near.empty? ? nil : lambda { party.invite }, "Nobody is near enough to invite.")
  end

  # The wheel's choice that leaves the party, or stops an invite nobody took.
  #
  # @return [Option] The choice.
  def self.leave_option
    party = MGQ_MpCoop::Party
    return Option.new("Leave the party", lambda { party.leave }, nil) unless party.members.empty?
    return Option.new("Stop inviting", lambda { party.stop_inviting }, nil) if party.inviting?

    Option.new("Leave the party", nil, "You are in no party.")
  end

  # Opens, steers or closes the action wheel on the map, but leaves the keys to the chat box while
  # it is open. Called by the map every frame, so a press of the key is seen once.
  def self.on_map
    wheel_key = MGQ_MpHotkeys.pressed?(:wheel)
    unless in_world? && !$game_map.interpreter.running? && !$game_message.busy?
      Wheel.close
      return
    end
    return if MGQ_MpChat.typing?
    # The wheel key closes the World overview, which holds the buttons while open.
    if defined?(MGQ_MpWorldOverview) && MGQ_MpWorldOverview.open?
      MGQ_MpWorldOverview.close if wheel_key
      return
    end

    if Wheel.open?
      Wheel.update(wheel_key)
    elsif wheel_key
      Wheel.open
    end
  rescue => e
    log("action wheel failed: #{e.class}: #{e.message}")
    Wheel.close
  end

  # The action wheel: four choices around the player and one over them, picked with the arrows and
  # taken with the game's confirm button. It opens on the middle; an arrow picks its side, and the
  # opposite arrow goes back to the middle. It holds the buttons while open, so the player stands
  # still and the game's menu stays shut.
  module Wheel
    # The directions around the player, clockwise from the top.
    DIRECTIONS = [:UP, :RIGHT, :DOWN, :LEFT]

    # The choice over the player.
    CENTER = :CENTER

    # Each direction's opposite, which goes back to the middle.
    OPPOSITES = { :UP => :DOWN, :DOWN => :UP, :LEFT => :RIGHT, :RIGHT => :LEFT }

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
    # @return [Symbol] One of DIRECTIONS, or CENTER.
    def self.selected
      @selected
    end

    # Opens the wheel on its middle choice.
    def self.open
      @selected = CENTER
      @open = true
      MGQ_Multiplayer::Capture.start(:wheel)
      Sound.play_cursor
    end

    # Closes the wheel, if it is open, and gives the buttons back.
    def self.close
      return unless @open

      @open = false
      MGQ_Multiplayer::Capture.stop(:wheel)
    end

    # Follows the arrows, takes the picked choice on confirm, and closes on cancel or the wheel key.
    #
    # @param pressed [Boolean] Whether the wheel key went down this frame.
    def self.update(pressed)
      if pressed || MGQ_Multiplayer::Capture.trigger?(:B)
        close
        Sound.play_cancel
        return
      end

      DIRECTIONS.each do |direction|
        next unless MGQ_Multiplayer::Capture.trigger?(direction) && direction != @selected

        @selected = OPPOSITES[direction] == @selected ? CENTER : direction
        Sound.play_cursor
      end

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
    bitmap.font.color = MGQ_MpCoop::INVITE_COLOR
    bitmap.draw_text(0, 0, WIDTH, HEIGHT, text, 1)
  end

  # Frees the line's picture.
  def dispose
    bitmap.dispose
    super
  end
end

# The action wheel around the player: a box per choice above, right of, below and left of them, a
# square one with an icon over them, the picked one lit, those that cannot be taken grey.
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

  # Room kept free around the player's sprite, which is 32 by 48 pixels.
  GAP = 4

  # Height of the player's sprite.
  PLAYER_HEIGHT = 48

  # Half the width of the player's sprite, plus the gap.
  PLAYER_SIDE = 20

  # Width of the wheel's picture.
  WIDTH = (PLAYER_SIDE + BOX_WIDTH) * 2

  # Row of the wheel's picture at the player's feet.
  FEET = BOX_HEIGHT + GAP + MGQ_MpActions::HEAD_ROOM + PLAYER_HEIGHT

  # Height of the wheel's picture.
  HEIGHT = FEET + GAP + BOX_HEIGHT

  # Where each direction's box sits in the picture.
  BOXES = {
    :UP => [(WIDTH - BOX_WIDTH) / 2, 0],
    :RIGHT => [WIDTH / 2 + PLAYER_SIDE, FEET - (PLAYER_HEIGHT + BOX_HEIGHT) / 2],
    :DOWN => [(WIDTH - BOX_WIDTH) / 2, FEET + GAP],
    :LEFT => [0, FEET - (PLAYER_HEIGHT + BOX_HEIGHT) / 2],
    :CENTER => [(WIDTH - CENTER_WIDTH) / 2, FEET - (PLAYER_HEIGHT + BOX_HEIGHT) / 2],
  }

  # Background of a box.
  BACK = Color.new(0, 0, 0, 170)

  # Background of the picked box.
  PICKED_BACK = Color.new(48, 96, 176, 220)

  # Color of a choice that can be taken.
  TEXT = Color.new(255, 255, 255)

  # Color of a choice that cannot be taken.
  GREY = Color.new(150, 150, 150)

  # Creates the wheel, hidden.
  #
  # @param viewport [Viewport] The map's topmost viewport.
  def initialize(viewport)
    super(viewport)
    self.bitmap = Bitmap.new(WIDTH, HEIGHT)
    self.ox = WIDTH / 2
    self.oy = FEET
    self.z = 300
    self.visible = false
    @shown = nil
  end

  # Draws the wheel around the player's sprite while it is open, if it changed.
  #
  # @param sprite [Sprite_Character, nil] The player's sprite.
  def show(sprite)
    self.visible = MGQ_MpActions::Wheel.open? && !sprite.nil?
    return unless visible

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

  # Draws one choice's box.
  #
  # @param direction [Symbol] The direction that picks it.
  # @param option [MGQ_MpActions::Option] The choice.
  def draw_box(direction, option)
    x, y = BOXES[direction]
    width = direction == MGQ_MpActions::Wheel::CENTER ? CENTER_WIDTH : BOX_WIDTH
    picked = direction == MGQ_MpActions::Wheel.selected
    bitmap.fill_rect(x, y, width, BOX_HEIGHT, picked ? PICKED_BACK : BACK)
    return draw_icon(option, x + (width - ICON_SIZE) / 2, y + (BOX_HEIGHT - ICON_SIZE) / 2) if option.icon

    bitmap.font.color = option.run ? TEXT : GREY
    bitmap.draw_text(x + 4, y, width - 8, BOX_HEIGHT, option.text, 1)
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
    bitmap.dispose
    super
  end
end

# What this script takes part in of the world's messages, through mp_overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpActions.tick(in_world) }
rescue => e
  MGQ_MpActions.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

# Game hooks, through mp_hooks.rbx.

begin
  # After the map's update, the action wheel. The game checks its own keys there too, only while no
  # scene change is in the way.
  MGQ_MpHooks.after(Scene_Map, :update_scene, "mp_actions") { MGQ_MpActions.on_map unless scene_changing? }

  # After the map's sprites, the line above the player's own head and the action wheel around them.
  MGQ_MpHooks.after(Spriteset_Map, :update, "mp_actions") do
    @mgq_mp_own_line ||= Sprite_MpOwnLine.new(@viewport1)
    @mgq_mp_wheel ||= Sprite_MpActionWheel.new(@viewport3)
    player = @character_sprites.find { |sprite| sprite.character.equal?($game_player) }
    @mgq_mp_own_line.show(player)
    @mgq_mp_wheel.show(player)
  end

  MGQ_MpHooks.before(Spriteset_Map, :dispose, "mp_actions") do
    [@mgq_mp_own_line, @mgq_mp_wheel].compact.each { |sprite| sprite.dispose }
    @mgq_mp_own_line = @mgq_mp_wheel = nil
  end
rescue => e
  MGQ_MpActions.log("hooks FAILED: #{e.class}: #{e.message}")
end
