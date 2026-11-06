#----------------------------------------------------------------
#  ui_actions.rbx
#
#  Changelog:
#      Paulinchen  2026-11-06: Named the line's color by its name in the player's look
#                            - Built the action wheel as a wheel of the Mod Framework's UI layer, its hotkey declared on its class
#      Paulinchen  2026-11-01: Dropped the lapse after a frame count, which nothing calls
#                            - Named the Mod Framework's interface by its own name
#                            - Left the line above the player's head to overworld.rbx
#                            - Built the action wheel as a Mod Framework wheel of boxes that follows the player
#      Paulinchen  2026-10-31: Defined and steered its wheel through the Mod Framework
#      Paulinchen  2026-10-23: Left the action wheel's rules to C#, taking a choice in the frame after confirm
#                            - Kept the own line and the action wheel off the live map behind menus
#      Paulinchen  2026-10-12: Logged a refused hotkey through MGQ_MpHotkeys.log_refusal
#                            - Read the map's viewports and character sprites through MGQ_MpGame
#      Paulinchen  2026-10-11: Framed the wheel's boxes in the preset's colors
#                            - Drew the wheel and the own line in the shared style with fades and the shared hint
#                            - Made the own line half the screen wide and cut texts to their room
#                            - Drew the wheel's hint whole and its icons through MGQ_MpUi.draw_icon
#                            - Showed the seconds left after a doing in the own line
#                            - Left a failing line or doing out of the own line
#                            - Told whether a screen of the mod lies over the map
#      Paulinchen  2026-10-08: Closed with the numpad's 0 through MGQ_MpUi.cancel?
#                            - Listed the choices of the player menus here
#      Paulinchen  2026-10-07: Took the icon rect, white and the depths from MGQ_MpUi
#                            - Logged the action wheel, its choices and the own line
#      Paulinchen  2026-10-06: Kept the last pointed choice once the arrows are let go
#                            - Built the wheel's ring from registered choices over eight directions
#                            - Pointed at a choice with the arrows held
#      Paulinchen  2026-10-04: Renamed from mp_actions.rbx
#      Paulinchen  2026-10-03: Took the wheel's choices, the own line and the covering screens from later scripts
#                            - Asked MGQ_MpOverworldSync whether the map is quiet or the player free on it
#                            - Sent messages, showed notices and read the world through MGQ_MpOverworldSync
#                            - Logged through MGQ_MpLog
#                            - Read the bound keys through MGQ_MpHotkeys
#      Paulinchen  2026-10-02: Opened the wheel with its bound hotkey
#                            - Followed the map and its sprites through core_hooks.rbx
#                            - Took a choice through MGQ_MpActions.choose
#      Paulinchen  2026-10-01: Showed a globe in the wheel's middle
#                            - Refused to invite into a full party or to accept the invite of one
#                            - Added duel challenges to the wheel
#                            - Opened the World overview from the wheel's middle
#                            - Left the keys to the World overview while it is open
#                            - Let only the party's leader invite
#                            - Showed the wait for the party's story scene above the player's own head
#      Paulinchen  2026-09-30: Left the chat to ui_chat.rbx
#                            - Left the party to coop.rbx
#                            - Registered with overworld_sync.rbx for its messages
#                            - Moved into Patch/Multiplayer/Scripts as ui_actions.rbx
#                            - Found the party's leader
#                            - Gave the chat box a blinking cursor
#      Paulinchen  2026-09-29: Told overworld.rbx while the player types in the chat
#                            - Showed the chat box's text as it is typed
#                            - Left room right above the player's head for their ping
#                            - Added chat with bubbles and a log
#                            - Added an action wheel opened with B
#                            - Created
#
#----------------------------------------------------------------

# The action wheel on the map: its hotkey (B unless the player binds another, see core_hotkeys.rbx)
# opens it around the player. The scripts after this one fill its ring (wheel_choice) and its middle
# (wheel_center), say the line above the player's own head (own_line_from, own_doing_from) and add
# what they offer between two players to the World overview and the notification box (offer). The
# wheel is a wheel of the Mod Framework's UI layer (ActionWheel); overworld_sync.rbx knows the other
# players.
#
# It must never interrupt the game, so its per-frame work rescues.
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

  # What the wheel's choices name its middle by.
  CENTER = :CENTER

  # The action wheel's id among the roots of the Mod Framework.
  WHEEL_ID = :mgq_online_action_wheel

  # Color of the line above the player's own head, MGQ Online's own color, which the invites'
  # notices share.
  LINE_COLOR = :mgq_online_own

  # How the seconds left are written after a doing in the line above the player's own head.
  TIME_LEFT = " (%d s)"

  # Frames in a second, by which a timer counted in frames lapses.
  FRAMES_PER_SECOND = 60

  # The eight directions a wheel's choices spread over, clockwise from the top, as the Mod
  # Framework's wheel spreads them.
  DIRECTIONS = [:UP, :UP_RIGHT, :RIGHT, :DOWN_RIGHT, :DOWN, :DOWN_LEFT, :LEFT, :UP_LEFT]

  # The registered offers between two players, see offer.
  @offers = []

  # The ring's choices as [order, registration index, block], sorted, see wheel_choice.
  @choices = []

  # The block that fills the wheel's middle, nil while none does.
  @center = nil

  # The blocks that say the own line, see own_line_from.
  @lines = []

  # The blocks that name a doing, see own_doing_from.
  @doings = []

  # Whether the action wheel is open, which other scripts ask, see wheel.
  @wheel = nil

  # The choice the wheel took, its registration index or CENTER, with the frame it did in; nil
  # while none waits.
  @taken = nil

  extend MGQ_MpLog

  # What starts this script's lines in the log.
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
  # arrows point to (see wheel_places). A ring holds one choice per direction at most.
  #
  # @param order [Integer] Its place on the ring, clockwise from the top: the lower, the earlier.
  # @yieldreturn [Option] The choice the wheel shows now.
  def self.wheel_choice(order, &option)
    if @choices.size >= DIRECTIONS.size
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

  # The directions of the ring's choices, in their order: spread evenly over the eight, the choice
  # at place i on the direction round(i * 8 / n), as the Mod Framework's wheel spreads them.
  #
  # @return [Array<Symbol>] Directions of DIRECTIONS.
  def self.wheel_places
    count = @choices.size
    (0...count).map { |place| DIRECTIONS[(place * DIRECTIONS.size.to_f / count).round % DIRECTIONS.size] }
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
    Time.now + frames / FRAMES_PER_SECOND.to_f
  end

  # Writes a doing with its seconds left, such as "Asking Player A to teleport (45 s)"; the text
  # alone once it lapsed or has no time. A lapse that is no Time, such as a frame count by
  # mistake, counts as none, so one wrong caller cannot break the line.
  #
  # @param doing [String, Array] The doing, see own_doing_from.
  # @param now [Time] The moment the seconds count from.
  # @return [Array(String, String)] The text alone, which the log keys on, and the text as shown.
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

  # Tells what the line above the player's own head says, if anything: a script's line, else the
  # doings with their seconds left, and the same without the seconds, which the line falls back
  # to once the seconds make it too wide. The seconds stay out of the log, which says the line
  # once.
  #
  # @return [Array(String, String), nil] The line with the seconds and without them, nil for none.
  def self.own_lines
    return nil unless MGQ_MpOverworldSync.in_world? && !wheel.open?

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
  # @return [Hash{Symbol => Option}] The middle's choice under CENTER, then the ring's under their
  #   directions.
  def self.wheel_options
    options = { CENTER => @center ? @center.call : NO_OPTION }
    wheel_places.zip(@choices) { |direction, (_, _, option)| options[direction] = option.call }
    options
  end

  # Whether a wheel is open, which other scripts ask, and what runs once nothing of it shows any
  # more, such as the bug report's screenshot waiting for the wheel to fade.
  class OpenState
    # Makes the state of a closed wheel.
    def initialize
      @open = false
      @gone = []
    end

    # Tells whether the wheel is open.
    #
    # @return [Boolean] Whether it is.
    def open?
      @open
    end

    # Notes whether the wheel is open.
    #
    # @param open [Boolean] Whether it is.
    def open=(open)
      @open = open ? true : false
    end

    # Adds a block to run once nothing of the wheel shows any more after it closed.
    #
    # @param event [Symbol] :gone, the one event it tells.
    # @return [OpenState] Itself.
    def on(event, &block)
      @gone << block if event == :gone && block
      self
    end

    # Runs the blocks added for :gone, each rescued.
    def gone
      @gone.each do |block|
        begin
          block.call
        rescue => e
          MGQ_MpActions.log_once(block, "a block run as the wheel faded out failed: #{e.class}: #{e.message}")
        end
      end
    end
  end

  # The action wheel: its hotkey opens it on a free map in a world, wide boxes around the player
  # holding the choices the scripts registered, asked every frame, the World overview in the
  # middle; a choice taken runs in the frame after, once the wheel closed, so its confirm never
  # reaches the screen the choice opens.
  class ActionWheel < Mod_Framework::UI::Component
    hotkey MGQ_MpHotkeys.action(:wheel)

    # Describes the wheel.
    def render
      actions = MGQ_MpActions
      wheel id: WHEEL_ID, look: :boxes, follow: :player, if: -> { actions.free_reason || true }, choices: -> { actions.wheel_choices },
            center: -> { actions.wheel_middle }, on_open: -> { actions.opened }, on_submit: ->(choice) { actions.taken(choice) },
            on_refuse: ->(choice) { actions.refused(choice) }, on_close: ->(why) { actions.closed(why) }, on_gone: -> { actions.wheel.gone }
    end
  end

  # Tells whether the action wheel is open, and runs what waits for it to fade out.
  #
  # @return [OpenState] The wheel's state.
  def self.wheel
    @wheel ||= OpenState.new
  end

  # Notes that the action wheel opened, with its choices for the log.
  def self.opened
    wheel.open = true
    log("action wheel opened: #{choices_text}")
  end

  # Notes that the action wheel closed.
  #
  # @param why [Symbol, String] Why.
  def self.closed(why)
    wheel.open = false
    log("action wheel closed: #{why}")
  end

  # Takes the choice the wheel took, which runs in the frame after.
  #
  # @param choice [Hash] The wheel's choice, its registration index or CENTER as its data.
  def self.taken(choice)
    @taken = [choice[:data], MGQ_Multiplayer::Bridge.frame_number]
  end

  # Tells why the action wheel may not show now.
  #
  # @return [String, nil] Why, nil while the player stands free on the map of a world.
  def self.free_reason
    return "no world is open" unless MGQ_MpOverworldSync.in_world?

    Mod_Framework::UI::Game.map_free_reason
  end

  # Lists the ring's choices as the wheel draws them.
  #
  # @return [Array<Hash>] Each choice: its text, icon, whether it can be taken, why not, and its
  #   registration index as its data.
  def self.wheel_choices
    @choices.map { |_, added, option| wheel_choice_of(option.call, added) }
  end

  # Tells the middle's choice as the wheel draws it.
  #
  # @return [Hash, nil] The choice, nil while no script fills the middle.
  def self.wheel_middle
    @center ? wheel_choice_of(@center.call, CENTER) : nil
  end

  # Turns a choice into one of the wheel.
  #
  # @param option [Option] The choice.
  # @param data [Integer, Symbol] Its registration index, or CENTER.
  # @return [Hash] The wheel's choice.
  def self.wheel_choice_of(option, data)
    { :text => option.text.to_s, :icon => option.icon, :enabled => !option.run.nil?, :tooltip => option.refusal, :data => data }
  end

  # Tells the player why a choice of the wheel cannot be taken; the wheel buzzed and stays open.
  #
  # @param choice [Hash] The wheel's choice.
  def self.refused(choice)
    name = choice[:text].to_s.empty? ? "the choice with icon #{choice[:icon]}" : "\"#{choice[:text]}\""
    log("refused #{name}: #{choice[:tooltip] || 'it cannot be chosen now'}")
    MGQ_MpOverworldSync.notice(choice[:tooltip]) if choice[:tooltip]
  end

  # Runs the choice the wheel took in the frame before, asked anew, so it is the one that stands
  # now. Called by the map every frame.
  def self.on_map
    taken, frame = @taken
    now = MGQ_Multiplayer::Bridge.frame_number
    return unless taken && frame < now

    @taken = nil
    return log("dropped the choice taken in frame #{frame}: the map did not run in the frame after") if frame < now - 1

    choose(taken == CENTER ? wheel_options[CENTER] : @choices.find { |_, added, _| added == taken }[2].call)
  rescue => e
    log("running the action wheel's choice failed: #{e.class}: #{e.message}")
  end

  # Lists the wheel's choices for the log, those that cannot be taken marked.
  #
  # @return [String] Each choice by its direction.
  def self.choices_text
    wheel_options.map { |direction, option| "#{direction} #{option_name(option)}#{option.run ? '' : ' (refused)'}" }.join(", ")
  rescue => e
    "unreadable (#{e.class})"
  end
end

# Game hooks, through core_hooks.rbx.

begin
  # After the map's update, the choice the action wheel took. The game checks its own keys there
  # too, only while no scene change is in the way.
  MGQ_MpHooks.after(Scene_Map, :update_scene, "ui_actions") { MGQ_MpActions.on_map unless scene_changing? }
rescue => e
  MGQ_MpActions.log("hooks FAILED: #{e.class}: #{e.message}")
end
