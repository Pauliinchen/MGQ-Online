#----------------------------------------------------------------
#  ui_chat.rbx
#
#  Changelog:
#      Paulinchen  2026-11-01: Built the chat log, its tabs, its box, a player's menu and the bubbles of the Mod Framework's components
#                            - Showed the DLL's chat model and handed it the typing, the keys and the clicks, leaving it the chat's
#                              rules and messages
#                            - Opened the chat box over a window that hosts its scene, such as the trade screen's
#                            - Asked the action wheel of the Mod Framework whether it is open
#      Paulinchen  2026-10-31: Typed, cancelled, named the cancel key and placed its boxes through the Mod Framework
#                            - Worded what the player reads plainly, leaving causes and internals to the log
#      Paulinchen  2026-10-23: Acted on what was typed a frame later, as the text box in C# reports it
#                            - Sent the lines of every chat through the DLL
#                            - Removed history and log_lines, which only the tests read
#                            - Kept the chat log off the live map behind menus
#      Paulinchen  2026-10-22: Opened the chat box and showed its log in the shops, the casino and the trade screen
#                            - Kept the hooks of mods loaded later in the shops, the casino and the trade screen
#                            - Showed the relay's own notices in the notification box too
#      Paulinchen  2026-10-12: Showed the relay's own notices red between slashes in every tab
#                            - Scrolled the open chat log with the mouse wheel
#                            - Drew a scrollbar beside the open log's rows
#                            - Put the chat back to the All tab and the global chat as the world closes
#                            - Logged a refused hotkey through MGQ_MpHotkeys.log_refusal
#                            - Read the map's viewports through MGQ_MpGame
#      Paulinchen  2026-10-11: Showed the dimmed tabs above the closed log only while it shows lines
#                            - Started the chat in the global chat
#                            - Moved and resized the chat log through MGQ_MpUi::Layout
#                            - Dropped the log's own resizing
#                            - Snapped the log's height to whole rows
#                            - Raised the log's least width and fewest rows
#                            - Drew a hint of the empty chat box in the tiny font when too wide
#                            - Offered the log to the layout whenever it shows
#                            - Drew the open chat, its tabs and a player's menu in the preset's look
#                            - Took the left Alt from MGQ_MpUi::Layout and named the layout in the hints
#                            - Renamed the say chat to the map chat, chosen with /m or /map
#                            - Drew the chats in the colors of World of Warcraft
#                            - Showed the Whisper tab only once whispers are in use
#                            - Named every player outside the party in plain white in the log
#                            - Drew the log, its tabs, its menu, the bubbles and the hints in the shared style
#                            - Faded a line of the closed log away over its last frames
#                            - Brought back the last 20 lines sent with Alt and up or down
#                            - Answered the last player who whispered with /r
#                            - Played the recovery sound for whispers while the chat box is closed
#                            - Drew the tabs dimmed above the closed log while one holds unread lines
#                            - Buzzed once a frame for a paste longer than the box takes
#                            - Named the sent lines, /r and Ctrl+V in the hints and the help
#      Paulinchen  2026-10-08: Split the chat into the global, say and party chats
#                            - Showed the log in tabs
#                            - Resized the chat log with Alt and the mouse
#                            - Wrote the chat log smaller
#                            - Brought the chat log above everything while the player types
#                            - Closed the chat box with the numpad's 0 through MGQ_MpUi.numpad_cancel?
#                            - Mirrored only the global chat to the relay for the world's admins
#                            - Added whispers with /w or /whisper and a Whisper tab
#                            - Added a Help tab that /help opens
#                            - Drew the bubbles in their chat's color, slightly see-through
#                            - Lowered the bubbles to just over the name
#                            - Shortened the empty chat box's hint and showed the Alt controls in it
#                            - Let the tabs with unread lines glow yellow at their top right corner
#                            - Picked the tabs and resized with the left Alt alone
#                            - Outlined the tabs and the open chat thinly
#                            - Filled the picked tab with its chat's color under dark text
#                            - Opened a menu of another player with a click on their name
#                            - Trusted only the relay's own mark on an admin's line
#                            - Rested the map's chat log just under the topmost viewport
#                            - Sized the log before following the mouse
#                            - Found players through MGQ_MpOverworldSync::Peers
#                            - Stopped following the keys and the mouse once a menu's choice closed the chat box
#                            - Offered only the whisper in a player's menu during a battle
#                            - Showed whispers in the closed chat log whatever the tab
#                            - Numbered a name that several players share and whispered by player id
#                            - Named the sender of a line by the same numbered name
#                            - Sent a line of the say chat once to everyone with the sender's map
#                            - Mirrored a global line to the relay before sending it
#                            - Left out the 0 that the numpad's 0 types after it closed a player's menu
#                            - Kept the chat's size in battles and a drag within the screen
#                            - Kept the typing of a frame in which the menu's player left
#                            - Colored the sender's name when the line breaks right after it
#                            - Left out the line and paragraph separators of players' and admins' lines
#                            - Built a menu's choices and the fitting names once per frame
#                            - Said how to close the chat box, the help tab and a player's menu
#      Paulinchen  2026-10-07: Mirrored lines to the relay for admins and showed an admin's line as [Admin]
#                            - Closed the chat box with the numpad's 0
#                            - Scrolled the chat log while the box is open
#                            - Registered the hooks through core_hooks.rbx
#                            - Named senders through MGQ_MpOverworldSync.who and took white and depths from MGQ_MpUi
#                            - Logged the chat box and every line sent, refused or received
#      Paulinchen  2026-10-06: Opened the chat box while the map shows a message
#                            - Added the chat's choice to the action wheel's ring by order
#      Paulinchen  2026-10-05: Took the typing of an open chat box while the map shows a message
#      Paulinchen  2026-10-04: Named the party tag by its module inside the log line
#                            - Sent a line typed with /p to the party only and colored the senders' names
#                            - Opened the chat box while the player waits for the party's story
#                            - Left out the character of the key that opened the chat box
#                            - Removed BLINK_FRAMES
#                            - Renamed from mp_chat.rbx
#                            - Drew the chat box through MGQ_MpUi::TextBox
#                            - Typed through MGQ_MpUi::TextEdit
#      Paulinchen  2026-10-03: Broke lines through MGQ_MpUi.wrap
#                            - Filled the wheel's chat choice and told the wheel while the chat box is open
#                            - Asked MGQ_MpOverworldSync whether the map is quiet or the player free on it
#                            - Sent messages, showed notices and read the world through MGQ_MpOverworldSync
#                            - Logged through MGQ_MpLog
#                            - Read the bound keys through MGQ_MpHotkeys
#      Paulinchen  2026-10-02: Opened the chat box with its bound hotkey
#                            - Followed the map and its sprites through core_hooks.rbx
#      Paulinchen  2026-10-01: Let the chat box and the chat log work in battles, above the battle's windows
#                            - Showed the game's own lines in the chat log, such as a player leaving a battle
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# The chat: a line typed on the keyboard goes to every player of the world, to the party, to the
# players on the same map or to one player, shows in a bubble above the sender while they are on the
# same map, and in the chat log at the bottom left. Its hotkey (T unless the player binds another,
# see core_hotkeys.rbx) or the action wheel of ui_actions.rbx opens the chat box.
#
# The chat's rules are the DLL's chat model (the chat.* topics): this script builds the log, its tabs,
# its box, a player's menu and the bubbles of the Mod Framework's components, shows the model's view
# in them and hands their typing, keys and clicks to the model. It keeps where and when the chat
# opens, the bubbles' characters and the menu's choices.
#
# It must never interrupt the game, so its per-frame work rescues.
module MGQ_MpChat
  # The Mod Framework's interface, whose components the chat is made of.
  UI = Mod_Framework::UI

  # The topic that opens the chat box: {"key", "scene", "close"}.
  OPEN_TOPIC = "chat.open"

  # The topic that closes the chat box: the reason.
  CLOSE_TOPIC = "chat.close"

  # The topic that hands the box's text after typing: {"text", "cursor"}.
  TYPED_TOPIC = "chat.typed"

  # The topic of Enter in the box.
  ENTER_TOPIC = "chat.enter"

  # The topic of the arrows with Alt: [tab step, line step].
  ALT_TOPIC = "chat.alt"

  # The topic that moves the pick through the fitting names: the step.
  PICK_TOPIC = "chat.pick"

  # The topic that takes the picked name.
  TAKE_PICK_TOPIC = "chat.take_pick"

  # The topic that picks a tab: its name.
  TAB_TOPIC = "chat.tab"

  # The topic that whispers to a player from their menu: their seat.
  WHISPER_TOPIC = "chat.whisper"

  # The topic that adds a line of the game's own: its text.
  GAME_LINE_TOPIC = "chat.game_line"

  # The topic that stages the scene in front: {"scene", "chat_scene"}.
  SCENE_TOPIC = "chat.scene"

  # The event that carries the chat's view once it changed.
  VIEW_EVENT = "chat.view"

  # The event of a sound to play: its name after Sound.play_.
  SOUND_EVENT = "chat.sound"

  # The event of a notice of the relay's own for the notification box: its text.
  ANNOUNCE_EVENT = "chat.announce"

  # Characters a chat line may have.
  MAX_LENGTH = 120

  # The seat the view keeps the player's own bubble under.
  OWN_SEAT = -1

  # The log's tabs as the view names them, in their order: the Whisper tab shows once whispers are
  # in use, the help tab at the far right while it is open.
  TABS = %w[all global map party whisper help]

  # What the tabs say.
  TAB_NAMES = { "all" => "All", "global" => "Global", "map" => "Map", "party" => "Party", "whisper" => "Whisper", "help" => "Help" }

  # What the box row says before the text, by the chat chosen; a whisper names whom it goes to.
  LABELS = { "global" => "Global:", "map" => "Map:", "party" => "Party:", "help" => "Help:" }

  # The chats' colors, those of World of Warcraft: the tags, the bubbles, the tabs and the box row.
  CHANNEL_COLORS = { "global" => UI::Style::TEXT, "map" => Color.new(255, 192, 192), "party" => Color.new(170, 170, 255), "whisper" => Color.new(255, 128, 255) }

  # The chats whose lines draw their text in the chat's color too.
  COLORED_TEXT = %w[map whisper]

  # The colors of a sender's name by whose line it is; anyone else's is plain text.
  NAME_COLORS = { "me" => UI::Style::OWN, "member" => UI::Style::MEMBER, "admin" => UI::Style::GOLD, "system" => UI::Style::DIM }

  # The color of a notice of the relay's own.
  NOTICE_COLOR = Color.new(255, 64, 64)

  # What the empty box says. It names no close key, by the player's wish.
  BOX_HINT = "↑↓: scroll   Alt: more   /help: help"

  # What the empty box says while the left Alt is held.
  ALT_HINT = "←→: tab   ↑↓: sent   Drag: move, resize"

  # What the box says on the help tab, before the close keys.
  HELP_HINT = "Pick another tab to chat."

  # The keys with Alt the box claims, each as its step through the tabs and through the lines sent.
  ALT_KEYS = { "Alt+Left" => [-1, 0], "Alt+Right" => [1, 0], "Alt+Up" => [0, -1], "Alt+Down" => [0, 1] }

  # The places of the log, each kept on its own: its name while the player arranges, the room kept
  # below it and its depth while closed. The map's lies above the map's pictures and under the
  # game's message and the mod's wheels; the battle's and the menus' above their scenes' windows.
  PLACES = { :chat => ["Chat", 96, 99], :battle_chat => ["Battle chat", 200, UI::Z[:wheels]], :menu_chat => ["Menu chat", 8, UI::Z[:wheels]] }

  # Room between the log and the screen's left edge where it starts.
  MARGIN = 8

  # Height of the tabs' row: a tab in the small font on its plate.
  TAB_ROW = UI::SMALL_LINE_HEIGHT + 2 * UI::Button::PAD_Y

  # Height of a line of the log.
  ROW = UI::SMALL_LINE_HEIGHT

  # Height of the box row: the label and the field in the small font.
  BOX_ROW = UI::SMALL_LINE_HEIGHT

  # The fewest lines of the log, which leave room for the list of fitting names above the box.
  MIN_ROWS = 5

  # The least size of the log: its width, and the tabs, MIN_ROWS lines and the box row.
  MIN_SIZE = [400, TAB_ROW + ROW * MIN_ROWS + BOX_ROW]

  # The setting in Player.ini that holds the log's size as width x rows, its default size.
  #
  # Only earlier builds write it; this script only reads it.
  SIZE_SETTING = "chat_size"

  # The log's size without SIZE_SETTING: its width and its lines.
  DEFAULT_SIZE = [400, 6]

  # How opaque the tabs draw above the closed log.
  CLOSED_TABS_OPACITY = 160

  # The frames over which a line of the closed log fades out, as the view counts them.
  FADE_FRAMES = UI::Style::FADE_FRAMES

  # Pixels above the player's feet a bubble points at: just over their ping.
  OWN_LIFT = 64

  # Pixels above another player's feet a bubble points at: just over their name.
  GHOST_LIFT = 68

  # Pixels a bubble goes higher while a line, such as an invite, shows over the name.
  LINE_LIFT = 24

  # The chat's view, see take_view; nil before the DLL told one.
  @view = nil

  # The log's root, nil while it shows nowhere.
  @root = nil

  # The place of the log's root, one of PLACES.
  @place = nil

  # What the root shows of the view, by part, so only what changed is set.
  @shown = {}

  # The bubbles, by seat.
  @bubbles = {}

  # The scenes besides the map and battles where the chat box opens, see follow_scene.
  @menu_scenes = []

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "chat"

  # Reports whether the chat box is open.
  #
  # @return [Boolean] Whether it is.
  def self.typing?
    @view.is_a?(Hash) && !@view["box"].nil?
  end

  # Tells the chat's view, see the DLL's chat.view.
  #
  # @return [Hash, nil] The view, nil before the DLL told one.
  def self.view
    @view
  end

  # Tells the log's root.
  #
  # @return [Mod_Framework::UI::Box, nil] The root, nil while it shows nowhere.
  def self.root
    @root
  end

  # Tells the bubbles.
  #
  # @return [Hash{Integer => Mod_Framework::UI::Bubble}] The bubbles by seat, OWN_SEAT the player's.
  def self.bubbles
    @bubbles
  end

  # Reports whether the keyboard reaches the game, which only happens once its window is hooked.
  #
  # @return [Boolean] Whether it does.
  def self.available?
    Mod_Framework.available?
  end

  # The action wheel's chat choice.
  #
  # @return [MGQ_MpActions::Option] The choice.
  def self.wheel_option
    MGQ_MpActions::Option.new("Chat (#{MGQ_MpHotkeys.label(:chat)})", available? ? lambda { start_typing } : nil,
                              "Chat is not available right now.")
  end

  # Opens the chat box.
  #
  # @param key [Integer, nil] Windows' code of the key that opened it, nil when the wheel did.
  def self.start_typing(key = nil)
    take_view(call(OPEN_TOPIC, "key" => !key.nil?, "scene" => SceneManager.scene.class.name, "close" => UI.cancel_keys(:text)))
  end

  # Closes the chat box, if it is open.
  #
  # @param reason [String] Why, for the log.
  def self.stop_typing(reason = "closed by a script")
    take_view(call(CLOSE_TOPIC, reason)) if typing?
  end

  # Adds a line of the game's own to the log, such as a player leaving a battle, which shows in
  # battles too, where the world's status line does not.
  #
  # @param text [String] The line.
  def self.system(text)
    take_view(call(GAME_LINE_TOPIC, text.to_s))
  end

  # Calls a topic of the chat's model.
  #
  # @param topic [String] The topic.
  # @param request [Object] What it takes.
  # @return [Object, nil] Its answer, nil while the bridge is closed.
  def self.call(topic, request = nil)
    MGQ_Multiplayer::Bridge.call(topic, request)
  end

  # Takes the chat's view and shows it in the log's root and the bubbles.
  #
  # @param view [Hash, nil] The view, see the DLL's chat.view; anything else is left alone.
  def self.take_view(view)
    return unless view.is_a?(Hash)

    @view = view
    refresh
    refresh_bubbles
  end

  # Tells whether the log has nothing to show: the box is closed and no line is recent.
  #
  # @return [Boolean] Whether it has.
  def self.empty?
    !typing? && Array(@view && @view["lines"]).empty?
  end

  # Tells the log's size until the player resizes it through the layout: SIZE_SETTING's, else
  # DEFAULT_SIZE.
  #
  # @return [Array<Integer>] Its width and its lines.
  def self.size
    stored = MGQ_Multiplayer::Player.setting(SIZE_SETTING).to_s.split("x").map { |part| part.to_i }
    stored.size == 2 && stored.all? { |value| value > 0 } ? stored : DEFAULT_SIZE
  end

  # Tells where a place's log starts: at the left, standing on the room kept below it, its size
  # SIZE_SETTING's or DEFAULT_SIZE, never smaller than MIN_SIZE.
  #
  # @param place [Symbol] One of PLACES.
  # @return [Array(Array<Integer>, Array<Integer>)] Its left and top, and its width and height.
  def self.default_place(place)
    width, rows = size
    width = [[width, MIN_SIZE[0]].max, Graphics.width - 2 * MARGIN].min
    height = [TAB_ROW + ROW * rows + BOX_ROW, MIN_SIZE[1]].max
    [[MARGIN, Graphics.height - PLACES[place][1] - height], [width, height]]
  end

  # Shows the log in a place, making its root unless it shows there already.
  #
  # @param place [Symbol] One of PLACES.
  def self.show_in(place)
    return if @root && @root.open? && @place == place

    drop_root
    return unless available?

    @place = place
    @root = build_root(place)
    @shown = {}
    @root.open
    return drop_root unless @root.open?

    refresh
  end

  # Closes the log's root, if it shows.
  def self.drop_root
    root = @root
    @root = nil
    root.close if root && root.open?
  end

  # Makes the log's root of a place: the tabs, the lines and the box row.
  #
  # @param place [Symbol] One of PLACES.
  # @return [Mod_Framework::UI::Box] The root.
  def self.build_root(place)
    name, _room, depth = PLACES[place]
    at, extent = default_place(place)
    root = UI::Box.new(:id => place, :place_name => name, :at => at, :size => extent, :min_size => MIN_SIZE, :movable => true, :resizable => true,
                       :frame => false, :z => depth, :mouse => :parts, :hide_while => lambda { MGQ_MpChat.empty? }, :log => self)
    @tabs = root.add_tabs(:pages => false, :pad_shoulders => true, :font_size => :small)
    TABS.each { |tab| @tabs.add_tab(TAB_NAMES[tab], :color => CHANNEL_COLORS.fetch(tab, UI::Style::TEXT)) }
    @lines = root.add_log(:grow => 1, :font_size => :small, :mouse => false, :scrollbar => false)
    @row = root.add_row(:gap => 4, :visible => false)
    @label = @row.add_label("", :font_size => :small)
    @field = @row.add_text_field(:grow => 1, :max_length => MAX_LENGTH, :keys => ALT_KEYS.keys, :letters => false, :placeholder => BOX_HINT,
                                 :font_size => :small)
    @field.steer(@lines)
    wire(root)
    root
  end

  # Hands the parts' events to the chat's model.
  #
  # @param root [Mod_Framework::UI::Box] The root.
  def self.wire(root)
    root.on(:cancel) { MGQ_MpChat.cancelled; false }
    root.on(:close) { |why| MGQ_MpChat.log("the #{root.place_name} log closed: #{why}") unless why == :script }
    @tabs.on(:change) { |index| MGQ_MpChat.take_view(MGQ_MpChat.call(TAB_TOPIC, TABS[index])) }
    @lines.on(:click) { |_row, part| MGQ_MpChat.open_menu(part[:data]) }
    @field.on(:change) { |text| MGQ_MpChat.typed(text) }
    @field.on(:submit) { |_text| MGQ_MpChat.take_view(MGQ_MpChat.call(ENTER_TOPIC)) }
    @field.on(:key) { |key| MGQ_MpChat.take_view(MGQ_MpChat.call(ALT_TOPIC, ALT_KEYS[key])) if ALT_KEYS[key] }
    @field.on(:completion) { |index| MGQ_MpChat.move_pick(index) }
    @field.on(:complete) { |_name, index| MGQ_MpChat.take_name(index) }
  end

  # Hands what the box holds after typing to the chat's model, with where its caret stands.
  #
  # @param text [String] The box's text.
  def self.typed(text)
    take_view(call(TYPED_TOPIC, "text" => text, "cursor" => @field.caret))
  end

  # Closes the chat box on the game's cancel, which the framework plays its sound for; the log's
  # root stays, showing the recent lines.
  def self.cancelled
    take_view(call(CLOSE_TOPIC, "cancel (#{cancel_key})"))
  end

  # Names the key that cancelled, for the log.
  #
  # @return [String] "Esc", "Numpad 0", "pad" or "the cancel key" for a key bound to cancel.
  def self.cancel_key
    keys = UI::Key
    return UI::ESCAPE_NAME if keys.down?(UI::ESCAPE_KEY)
    return UI::NUMPAD_NAME if UI::NUMPAD_ZERO.any? { |code| keys.down?(code) }

    UI::Pad.press?(:B) ? "pad" : "the cancel key"
  rescue
    "the cancel key"
  end

  # Moves the pick through the fitting names to the one the box's list lights.
  #
  # @param index [Integer] Its place in the list.
  def self.move_pick(index)
    step = index.to_i - (@view ? @view["pick"].to_i : 0)
    take_view(call(PICK_TOPIC, step)) unless step == 0
  end

  # Takes a fitting name the box's list gave: Enter or Tab take the lit one, a click any one, which
  # the model picks first.
  #
  # @param index [Integer] Its place in the list.
  def self.take_name(index)
    move_pick(index)
    take_view(call(TAKE_PICK_TOPIC))
  end

  # Shows the view in the log's root: only what changed since it showed last.
  def self.refresh
    return unless @root && @root.open?

    view = @view || {}
    box = view["box"]
    open = !box.nil?
    show_open(open) if @shown[:open] != open
    show_tabs(view, open)
    show_lines(view, open)
    show_box(view, box) if open
    @shown[:open] = open
    @shown[:tab] = view["tab"]
  rescue => e
    log("showing the chat FAILED: #{e.class}: #{e.message}")
  end

  # Opens or closes the log's box: framed, above everything and holding the game's buttons while the
  # player types; while closed, without a frame and letting the pointer pass, but for arranging.
  #
  # @param open [Boolean] Whether the box is open.
  def self.show_open(open)
    root = @root
    root.frame = open
    root.z = open ? UI::Z[:typing] : PLACES[@place][2]
    root.closable = open
    root.captures = open
    root.mouse = open ? true : :parts
    @lines.mouse = open
    @tabs.mouse = open
    @lines.scrollbar = open
    @row.visible = open
    @tabs.opacity = open ? UI::Component::OPAQUE : CLOSED_TABS_OPACITY
    if open
      @lines.scroll_to_end
      @field.focus
    elsif @shown.key?(:open)
      @field.blur
    end
  end

  # Shows the tabs the view names, the picked one and the unread ones; above the closed log only
  # while a tab holds unread lines and the log shows lines.
  #
  # @param view [Hash] The view.
  # @param open [Boolean] Whether the box is open.
  def self.show_tabs(view, open)
    shown = Array(view["tabs"])
    unread = Array(view["unread"])
    if @shown[:tabs] != [shown, unread]
      @shown[:tabs] = [shown, unread]
      TABS.each_with_index do |tab, index|
        part = @tabs.tab(index)
        part.visible = shown.include?(tab) unless part.visible? == shown.include?(tab)
        part.badge = unread.include?(tab)
      end
    end
    index = TABS.index(view["tab"]) || 0
    @tabs.index = index unless @tabs.index == index
    @tabs.visible = open || (!unread.empty? && !Array(view["lines"]).empty?)
  end

  # Shows the view's lines, each as its tag, its sender's name and its text in their colors; open,
  # a name another player can be clicked on. Another tab goes to the newest line.
  #
  # @param view [Hash] The view.
  # @param open [Boolean] Whether the box is open.
  def self.show_lines(view, open)
    lines = Array(view["lines"])
    unless @shown[:lines] == [lines, open]
      @shown[:lines] = [lines, open]
      @lines.rows = lines.map { |line| row_of(line, open) }
    end
    @lines.scroll_to_end if open && @shown[:open] && @shown[:tab] != view["tab"]
  end

  # Makes a row of the log of a line of the view.
  #
  # @param line [Array] [tag, name, text, who, channel, id, fade].
  # @param open [Boolean] Whether the box is open, in which a name can be clicked.
  # @return [Array<Hash>, Hash] The row's parts, with its opacity while it fades.
  def self.row_of(line, open)
    tag, name, text, who, channel, id, fade = line
    parts = []
    parts << { :text => tag, :color => who == "admin" ? UI::Style::GOLD : CHANNEL_COLORS.fetch(channel, UI::Style::TEXT) } unless tag.to_s.empty?
    unless name.to_s.empty?
      part = { :text => name, :color => NAME_COLORS.fetch(who, UI::Style::TEXT) }
      part[:data] = id if open && id
      parts << part
    end
    parts << { :text => text.to_s, :color => text_color(who, channel) }
    fade ? { :parts => parts, :opacity => UI::Component::OPAQUE * fade.to_i / FADE_FRAMES } : parts
  end

  # Picks the color of a line's text: a notice of the relay's own red, the chats of COLORED_TEXT in
  # their color, any other plain.
  #
  # @param who [String] Whose line it is.
  # @param channel [String, nil] Its chat.
  # @return [Color] The color.
  def self.text_color(who, channel)
    return NOTICE_COLOR if who == "notice"

    COLORED_TEXT.include?(channel) ? CHANNEL_COLORS[channel] : UI::Style::TEXT
  end

  # Shows the open box: the chat it sends to, the fitting names, the help tab's box that takes no
  # typing, and the text and the caret once the model changed them, such as a command taken out or a
  # line sent brought back; the caret the player moves stays.
  #
  # @param view [Hash] The view.
  # @param box [Array] [text, cursor, locked].
  def self.show_box(view, box)
    text, cursor, locked = box
    help = view["tab"] == "help"
    label = help ? LABELS["help"] : view["channel"] == "whisper" && view["whisper_to"] ? "To #{view['whisper_to']}:" : LABELS[view["channel"]].to_s
    color = help ? UI::Style::TEXT : CHANNEL_COLORS.fetch(view["channel"], UI::Style::TEXT)
    @label.text = label unless @label.text == label
    @label.color = color unless @label.color.equal?(color)
    @field.read_only = locked ? true : false unless @field.read_only == (locked ? true : false)
    show_hint
    if @shown[:box] != [text, cursor] && @field.text != text.to_s
      @field.text = text.to_s
      @field.caret = cursor.to_i
    end
    @shown[:box] = [text, cursor]
    names = Array(view["suggestions"])
    @field.completions = names unless @field.completions == names
    pick = view["pick"].to_i
    @field.completion_index = pick unless names.empty? || @field.completion_index == pick
  end

  # Shows the empty box's hint: the help tab's with the close keys, the Alt controls while the left
  # Alt is held, else the plain hint.
  def self.show_hint
    hint = if @view && @view["tab"] == "help"
             "#{HELP_HINT} #{UI.close_hint}"
           elsif UI::Key.down?(UI::Layout::ALT_KEY)
             ALT_HINT
           else
             BOX_HINT
           end
    @field.placeholder = hint unless @field.placeholder == hint
  end

  # Follows a frame of a scene the chat shows in: the hint by the left Alt while the box is open.
  def self.frame_update
    show_hint if typing? && @root && @root.open?
  end

  # Opens the menu of a player whose name was clicked in the log: what every script offers with them
  # and a whisper; off the map, in a battle, a shop, the casino or a trade, the whisper alone.
  #
  # @param id [String] Their player id.
  def self.open_menu(id)
    peer = MGQ_MpOverworldSync::Peers.with_id(id)
    return log("no menu: the player of id #{id} left the world") unless peer

    name = MGQ_MpOverworldSync::Peers.label_of(peer) || peer.state["name"].to_s
    whisper = MGQ_MpActions::Option.new("Whisper", lambda { MGQ_MpChat.take_view(MGQ_MpChat.call(WHISPER_TOPIC, peer.seat)) }, nil)
    options = SceneManager.scene.is_a?(Scene_Map) ? MGQ_MpActions.peer_options(peer) + [whisper] : [whisper]
    choices = options.map { |option| { :text => option.text.to_s, :enabled => !option.run.nil?, :tooltip => option.refusal } }
    at = UI::Mouse.position || [MARGIN, Graphics.height / 2]
    menu = UI::Menu.open(choices, :title => name, :at => at, :log => self) do |index, _choice|
      MGQ_MpChat.menu_taken(name, options, index)
    end
    return log("the menu of #{name} did not open: another menu is open") unless menu

    menu.on(:refuse) { |choice| MGQ_MpChat.menu_refused(name, choice) }
    log("menu of #{name} opened from the chat: #{options.map { |option| option.text }.join(', ')}")
  end

  # Takes a choice of a player's menu, or its close without one, then gives the box its typing back.
  # A choice that leaves, such as accepting a duel, closes the chat box too.
  #
  # @param name [String] The player's name.
  # @param options [Array<MGQ_MpActions::Option>] The menu's choices.
  # @param index [Integer, nil] The choice taken, nil when the menu closed without one.
  def self.menu_taken(name, options, index)
    option = index && options[index]
    if option
      log("menu of #{name} closed: chose #{option.text}")
      MGQ_MpActions.choose(option) { stop_typing("#{option.text} leaves the chat") if option.leaves }
    else
      log("menu of #{name} closed: no choice taken")
    end
    @field.focus if typing? && @root && @root.open?
  end

  # Notes a choice of a player's menu that cannot be taken now and says why on the status line.
  #
  # @param name [String] The player's name.
  # @param choice [Hash] The choice.
  def self.menu_refused(name, choice)
    log("refused #{choice[:text]} in the menu of #{name}: #{choice[:tooltip] || 'it cannot be chosen now'}")
    MGQ_MpOverworldSync.notice(choice[:tooltip]) if choice[:tooltip]
  end

  # Shows a bubble above each player the view has one for, in their line's chat's color, and closes
  # those it has none for any longer.
  def self.refresh_bubbles
    wanted = MGQ_MpOverworldSync.in_world? && @view.is_a?(Hash) ? (@view["bubbles"] || {}) : {}
    (@bubbles.keys - wanted.keys).each do |seat|
      bubble = @bubbles.delete(seat)
      bubble.close if bubble.open?
    end
    wanted.each do |seat, (text, channel)|
      color = CHANNEL_COLORS.fetch(channel, UI::Style::TEXT)
      bubble = @bubbles[seat]
      if bubble && bubble.open?
        bubble.text = text unless bubble.text == text
        bubble.color = color unless bubble.color.equal?(color)
      else
        @bubbles[seat] = make_bubble(seat, text, color)
      end
    end
  rescue => e
    log("showing the bubbles FAILED: #{e.class}: #{e.message}")
  end

  # Makes a bubble above a player, hidden while this map does not show them; the player's own hides
  # while the action wheel is open too.
  #
  # @param seat [Integer] Their seat, OWN_SEAT for the player.
  # @param text [String] The line.
  # @param color [Color] Its chat's color.
  # @return [Mod_Framework::UI::Bubble] The bubble.
  def self.make_bubble(seat, text, color)
    hide = lambda { bubble_target(seat)[0].nil? || (seat == OWN_SEAT && MGQ_MpActions.wheel.open?) }
    bubble = UI::Bubble.new(:text => text, :color => color, :keep => true, :log => self, :hide_while => hide)
    place_bubble(seat, bubble)
    bubble.open
  end

  # Keeps each bubble on its player as they move, change map or show a line over their name.
  # Called by the map's spriteset every frame, the live map's behind a menu too.
  def self.place_bubbles
    @bubbles.each { |seat, bubble| place_bubble(seat, bubble) }
  rescue => e
    log("placing the bubbles FAILED: #{e.class}: #{e.message}")
  end

  # Keeps a bubble on its player: the character it follows and how far above their feet it points.
  #
  # @param seat [Integer] Their seat, OWN_SEAT for the player.
  # @param bubble [Mod_Framework::UI::Bubble] The bubble.
  def self.place_bubble(seat, bubble)
    character, lift = bubble_target(seat)
    bubble.follow = character unless bubble.follow.equal?(character)
    bubble.lift = lift unless bubble.lift == lift
  end

  # Finds whom a bubble follows and how far above their feet it points: just over the player's
  # ping, or just over another player's name, higher while a line shows over it.
  #
  # @param seat [Integer] Their seat, OWN_SEAT for the player.
  # @return [Array(Game_Character, Integer)] The character, nil without one, and the pixels.
  def self.bubble_target(seat)
    return [$game_player, OWN_LIFT + (MGQ_MpActions.own_line ? LINE_LIFT : 0)] if seat == OWN_SEAT

    peer = MGQ_MpOverworldSync::Peers.at(seat)
    [peer && peer.ghost, GHOST_LIFT + (peer && MGQ_MpOverworldSync.label_line_of(peer) ? LINE_LIFT : 0)]
  end

  # Stages the scene in front for the chat's model, which closes the box where the chat does not
  # open, and closes the log and the bubbles once no world is open. Called by overworld_sync.rbx
  # every frame in every scene.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    scene = SceneManager.scene
    MGQ_Multiplayer::Bridge.stage(SCENE_TOPIC, "scene" => scene.class.name, "chat_scene" => chat_scene?(scene) ? true : false)
    return if in_world

    drop_root
    refresh_bubbles
  end

  # Tells what the player does while the chat box is open. Called by overworld_sync.rbx.
  #
  # @return [String, nil] "typing" while the chat box is open, else nil.
  def self.scene
    typing? ? "typing" : nil
  end

  # Reports whether the map lets the player chat: quiet, showing a message, or busy only with the
  # party's story, which the player waits for, through coop_gather.rbx.
  #
  # @return [Boolean] Whether it does.
  def self.map_open?
    return true if MGQ_MpOverworldSync.map_quiet? || $game_message.busy?

    defined?(MGQ_MpCoopGather) && MGQ_MpCoopGather.waiting? ? true : false
  end

  # Shows the log on the map and opens the chat box with its key. Called by the map every frame, so
  # a press of the key is seen once.
  #
  # A box already open stays, so a story that starts meanwhile never throws the line away; the box
  # holds the buttons, so the story's messages wait for it.
  def self.on_map
    @map_ran = true
    chat_key = MGQ_MpHotkeys.pressed?(:chat)
    return drop_root unless MGQ_MpOverworldSync.in_world?

    show_in(:chat)
    if typing?
      frame_update
    elsif chat_key && available? && !MGQ_MpActions.wheel.open? && map_open?
      Sound.play_ok
      start_typing(MGQ_MpHotkeys.code(:chat))
    elsif chat_key
      MGQ_MpHotkeys.log_refusal(:chat, !available? ? 'the keyboard cannot reach the game' : MGQ_MpActions.wheel.open? ? 'the action wheel is open' : 'an event runs on the map')
    end
  rescue => e
    log("chat failed: #{e.class}: #{e.message}")
  end

  # Notes that the map's update starts, in which on_map has not run yet. Called by the map every
  # frame.
  def self.map_updating
    @map_ran = false
  end

  # Follows the map while it shows a message, which stops the map's own update that on_map follows.
  # The box holds the buttons, so the message waits for it. Called by the map every frame.
  #
  # @param scene [Scene_Map] The map.
  def self.on_message(scene)
    # A message that starts during the map's own update comes after on_map ran in that update.
    on_map unless @map_ran || scene.scene_change_ok?
  rescue => e
    log("chat failed: #{e.class}: #{e.message}")
  end

  # Shows the log above a battle of a world and opens the chat box with its key. Called by the
  # battle every frame, its waits included, so the player chats while the battle plays on.
  def self.on_battle
    chat_anywhere(:battle_chat, "battle")
  end

  # Shows the log in a scene follow_scene names, such as a shop, and opens the chat box with its
  # key, as in a battle. Called by the scene every frame, its waits included.
  def self.on_menu
    chat_anywhere(:menu_chat, SceneManager.scene.class.name, true)
  end

  # Shows the log in a place and opens the chat box with its key, in a scene that holds no event the
  # chat box could interrupt.
  #
  # @param place [Symbol] The log's place, one of PLACES.
  # @param where [String] The scene, for the log.
  # @param menus [Boolean] Whether the scene is one of menus, where the chat box waits while another
  #   box, such as a question, holds the buttons over the scene, since that box reads them past it; a
  #   window that hosts the scene, such as the trade screen's, holds none over it.
  def self.chat_anywhere(place, where, menus = false)
    chat_key = MGQ_MpHotkeys.pressed?(:chat)
    return drop_root unless MGQ_MpOverworldSync.in_world?

    show_in(place)
    held = menus && !typing? && UI::Capture.over_scene?
    if typing?
      frame_update
    elsif chat_key && available? && !held
      Sound.play_ok
      start_typing(MGQ_MpHotkeys.code(:chat))
    elsif chat_key
      MGQ_MpHotkeys.log_refusal(:chat, held ? "another box of the mod holds the buttons" : "the keyboard cannot reach the game")
    end
  rescue => e
    log("#{where} chat failed: #{e.class}: #{e.message}")
  end

  # Tells whether the chat box opens in a scene: the map, a battle and the scenes follow_scene names.
  #
  # @param scene [Scene_Base, nil] The scene.
  # @return [Boolean] Whether it does.
  def self.chat_scene?(scene)
    scene.is_a?(Scene_Map) || scene.is_a?(Scene_Battle) || menu_scene?(scene)
  end

  # Tells whether a scene is one of menus the chat follows, see follow_scene.
  #
  # @param scene [Scene_Base, nil] The scene.
  # @return [Boolean] Whether it is.
  def self.menu_scene?(scene)
    @menu_scenes.any? { |owner| scene.is_a?(owner) }
  end

  # Lets the chat box open, take typing and show its log in a scene of menus, as in a battle: after
  # each of its frames, its waits included, and gone as it ends. Its menus hold no input while the
  # chat box holds the buttons.
  #
  # @param owner [Class] The scene, such as Scene_Shop.
  def self.follow_scene(owner)
    @menu_scenes << owner unless @menu_scenes.include?(owner)
  end
end

# What the chat takes from the DLL's chat model: its view, its sounds and the relay's notices.

begin
  MGQ_Multiplayer::Bridge.on(MGQ_MpChat::VIEW_EVENT) { |view| MGQ_MpChat.take_view(view) }
  MGQ_Multiplayer::Bridge.on(MGQ_MpChat::SOUND_EVENT) { |name| Sound.send("play_#{name}") if Sound.respond_to?("play_#{name}") }
  MGQ_Multiplayer::Bridge.on(MGQ_MpChat::ANNOUNCE_EVENT) { |text| MGQ_MpNotices.announce(text) if defined?(MGQ_MpNotices) }
rescue => e
  MGQ_MpChat.log("chat model FAILED: #{e.class}: #{e.message}")
end

# The log's places, which Interface Positions lists and puts back before the log first shows there.

begin
  MGQ_MpChat::PLACES.each { |id, (name, _room, _depth)| Mod_Framework::UI::Layout.register(id, name, :min_size => MGQ_MpChat::MIN_SIZE) }
rescue => e
  MGQ_MpChat.log("layout FAILED: #{e.class}: #{e.message}")
end

# What this script takes part in of the world's frames, through overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpChat.tick(in_world) }
  MGQ_MpOverworldSync.busy_scene { MGQ_MpChat.scene }
rescue => e
  MGQ_MpChat.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

# What the chat adds to the action wheel, through ui_actions.rbx.

begin
  MGQ_MpActions.wheel_choice(50) { MGQ_MpChat.wheel_option }
rescue => e
  MGQ_MpChat.log("action wheel FAILED: #{e.class}: #{e.message}")
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # After the map's update, the chat box. The game checks its own keys there too, only while no
  # scene change is in the way.
  MGQ_MpHooks.after(Scene_Map, :update_scene, "ui_chat") { MGQ_MpChat.on_map unless scene_changing? }

  # After the map's sprites, the log unless the map shows behind a menu, and the bubbles on their
  # players, the live map's behind a menu too.
  MGQ_MpHooks.after(Spriteset_Map, :update, "ui_chat") do
    MGQ_MpChat.show_in(:chat) if mgq_mp_hud? && MGQ_MpOverworldSync.in_world?
    MGQ_MpChat.place_bubbles
  end

  # Around the map's update, the chat box while a message stops the map's own update.
  MGQ_MpHooks.before(Scene_Map, :update, "ui_chat") { MGQ_MpChat.map_updating }
  MGQ_MpHooks.after(Scene_Map, :update, "ui_chat") { MGQ_MpChat.on_message(self) }
rescue => e
  MGQ_MpChat.log("hooks FAILED: #{e.class}: #{e.message}")
end

begin
  # After the battle's basics, the chat box and its log above the battle's windows. update_basic
  # runs in the battle's waits too, so the chat box takes typing while the battle plays on.
  MGQ_MpHooks.after(Scene_Battle, :update_basic, "ui_chat") { MGQ_MpChat.on_battle }
rescue => e
  MGQ_MpChat.log("battle hooks FAILED: #{e.class}: #{e.message}")
end

begin
  # After every scene's basics, the chat box and its log in the scenes of menus the chat follows.
  # These scenes inherit update_basic, and a hook on one of them would keep a copy of Scene_Base's
  # that misses what mods loaded later add to it, such as Party Sheet's hotkey.
  MGQ_MpHooks.after(Scene_Base, :update_basic, "ui_chat") { MGQ_MpChat.on_menu if MGQ_MpChat.menu_scene?(self) }

  # The game's shops and its casino: the slot machines (Scene_Slot, a Scene_CasinoBase), poker and
  # the prize exchange. Each is looked up by name, since a game without one leaves it out.
  %w[Scene_Shop Scene_CasinoBase Scene_Poker Scene_CasinoPrize].each do |name|
    Object.const_defined?(name) ? MGQ_MpChat.follow_scene(Object.const_get(name)) : MGQ_MpChat.log("#{name} is not in this game, so the chat does not open there")
  end
rescue => e
  MGQ_MpChat.log("shop and casino hooks FAILED: #{e.class}: #{e.message}")
end
