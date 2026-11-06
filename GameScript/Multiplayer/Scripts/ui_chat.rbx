#----------------------------------------------------------------
#  ui_chat.rbx
#
#  Changelog:
#      Paulinchen  2026-11-06: Asked the UI layer whether the player arranges the parts
#                            - Drew the chat's log, box, player menu and bubbles through the UI layer
#                            - Named the chats' colors once
#      Paulinchen  2026-11-05: Took the log's size kept in Player.ini as the width and lines the DLL reads
#                            - Named a scene whose class has no name by the class it builds on, so the chat's model always gets one
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
# The chat's rules are the DLL's chat model (the chat.* topics): this script shows the model's view
# through the UI layer, the log with its tabs and its box in a window that rests under the game's
# windows while closed, a player's menu and the bubbles, and hands the typing, the keys and the
# clicks to the model. It keeps where and when the chat opens, the bubbles' characters and the
# menu's choices.
#
# It must never interrupt the game, so its per-frame work rescues.
module MGQ_MpChat
  # The Mod Framework's UI.
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

  # The chats' colors, those of World of Warcraft, each named once as the script loads: the tags,
  # the bubbles, the tabs and the box row. Global is plain text.
  CHANNEL_COLORS = { "map" => :mgq_online_chat_map, "party" => :mgq_online_chat_party, "whisper" => :mgq_online_chat_whisper }

  # The colors the chats' names stand for.
  CHANNEL_RGB = { :mgq_online_chat_map => [255, 192, 192], :mgq_online_chat_party => [170, 170, 255], :mgq_online_chat_whisper => [255, 128, 255] }

  # The chats whose lines draw their text in the chat's color too.
  COLORED_TEXT = %w[map whisper]

  # The colors of a sender's name by whose line it is; anyone else's is plain text.
  NAME_COLORS = { "me" => :own, "member" => :ally, "admin" => :gold, "system" => :dim }

  # The color of a notice of the relay's own.
  NOTICE_COLOR = :error

  # What the empty box says. It names no close key, by the player's wish.
  BOX_HINT = "↑↓: scroll   Alt: more   /help: help"

  # What the empty box says while the left Alt is held.
  ALT_HINT = "←→: tab   ↑↓: sent   Drag: move, resize"

  # What the box says on the help tab, before the close keys.
  HELP_HINT = "Pick another tab to chat."

  # The keys with Alt the box claims, each as its step through the tabs and through the lines sent.
  ALT_KEYS = { "Alt+Left" => [-1, 0], "Alt+Right" => [1, 0], "Alt+Up" => [0, -1], "Alt+Down" => [0, 1] }

  # The keys the box claims while it types: Tab takes the lit name or does nothing, and the Alt keys.
  BOX_KEYS = ["Tab"] + ALT_KEYS.keys

  # The places of the log, each kept on its own under its id: its name while the player arranges,
  # the room kept below it, and the layer it rests in while closed: the map's under the game's
  # message, the battle's and the menus' above their scenes' windows.
  PLACES = { :chat => ["Chat", 96, :hud], :battle_chat => ["Battle chat", 200, :over], :menu_chat => ["Menu chat", 8, :over] }

  # Room between the log and the screen's left edge where it starts.
  MARGIN = 8

  # Height of the tabs' row.
  TAB_ROW = 24

  # Height of a line of the log in its small font.
  ROW = 18

  # Height of the box row.
  BOX_ROW = 22

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

  # The frames over which a line of the closed log fades out, as the view counts them.
  FADE_FRAMES = 12

  # Where the box lies among the windows while it types, above a window that hosts its scene,
  # such as the trade screen's.
  TYPING_Z = 50

  # The chat's view, see take_view; nil before the DLL told one.
  @view = nil

  # Counts the views taken, which the log's window watches.
  @serial = 0

  # The log's window, nil while it shows nowhere.
  @root = nil

  # The place of the log's window, one of PLACES.
  @place = nil

  # The bubbles' handles, by seat.
  @bubbles = {}

  # The scenes besides the map and battles where the chat box opens, see follow_scene.
  @menu_scenes = []

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "chat"

  class << self
    # @return [Integer] Counts the views taken.
    attr_reader :serial
  end

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

  # Tells the log's window.
  #
  # @return [Object, nil] Its handle, nil while it shows nowhere.
  def self.root
    @root
  end

  # Tells the place the log shows in.
  #
  # @return [Symbol, nil] One of PLACES, nil while it shows nowhere.
  def self.place
    @root ? @place : nil
  end

  # Tells the bubbles.
  #
  # @return [Hash{Integer => Object}] Their handles by seat, OWN_SEAT the player's.
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
    take_view(call(OPEN_TOPIC, "key" => !key.nil?, "scene" => scene_name(SceneManager.scene), "close" => UI.cancel_keys(:text)))
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

  # Takes the chat's view, which the log's window and the bubbles show.
  #
  # @param view [Hash, nil] The view, see the DLL's chat.view; anything else is left alone.
  def self.take_view(view)
    return unless view.is_a?(Hash)

    @view = view
    @serial += 1
    refresh_bubbles
  end

  # Tells whether the log has nothing to show: the box is closed and no line is recent.
  #
  # @return [Boolean] Whether it has.
  def self.empty?
    !typing? && Array(@view && @view["lines"]).empty?
  end

  # Tells the log's size until the player resizes it: SIZE_SETTING's, which the DLL reads as a
  # width and lines, else DEFAULT_SIZE.
  #
  # @return [Array<Integer>] Its width and its lines.
  def self.size
    stored = MGQ_Multiplayer::Player.setting(SIZE_SETTING)
    stored.is_a?(Array) ? stored : DEFAULT_SIZE
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

  # Tells the scenes a place's log shows in: the map's on the map alone, so the live map behind a
  # menu shows none, the battle's in battles, the menus' in the scenes follow_scene names.
  #
  # @param place [Symbol] One of PLACES.
  # @return [Array<Class>] The scenes.
  def self.scenes_of(place)
    case place
    when :chat then [Scene_Map]
    when :battle_chat then [Scene_Battle]
    else @menu_scenes.dup
    end
  end

  # Shows the log in a place while it has something to show, opening its window unless it shows
  # there already, and closes it once it has nothing.
  #
  # @param place [Symbol] One of PLACES.
  def self.show_in(place)
    return drop_root if empty?
    return if @root && @root.open? && @place == place

    drop_root
    return unless available?

    @place = place
    @root = UI.open(ChatBox, :place => place) { |_result, why| MGQ_MpChat.log("the #{PLACES[place][0]} log closed: #{why}") unless why == :script }
  end

  # Closes the log's window, if it shows.
  def self.drop_root
    root = @root
    @root = nil
    root.close if root && root.open?
  end

  # Hands what the box holds after typing to the chat's model, its caret at the end.
  #
  # @param text [String] The box's text.
  def self.typed(text)
    take_view(call(TYPED_TOPIC, "text" => text.to_s, "cursor" => text.to_s.length))
  end

  # Hands Enter in the box to the model, which sends the line or closes the empty box.
  def self.enter
    take_view(call(ENTER_TOPIC))
  end

  # Hands a key the box claims to the model: Tab takes the lit name while names show, the Alt keys
  # step the tabs and bring back lines sent.
  #
  # @param name [String] The key, such as "Alt+Left".
  def self.key(name)
    return take_view(call(ALT_TOPIC, ALT_KEYS[name])) if ALT_KEYS[name]
    return unless name == "Tab" && !suggestions.empty?

    take_view(call(TAKE_PICK_TOPIC))
  end

  # Picks a tab through the model.
  #
  # @param tab [String] Its name, one of TABS.
  def self.pick_tab(tab)
    take_view(call(TAB_TOPIC, tab)) if tab && tab != view_tab
  end

  # Closes the chat box on the game's cancel, which the framework plays its sound for; the log's
  # window stays, showing the recent lines.
  def self.cancelled
    take_view(call(CLOSE_TOPIC, "cancel"))
  end

  # Takes a fitting name the box gave: Enter or Tab take the lit one, a click any one, which the
  # model picks first.
  #
  # @param index [Integer] Its place in the list.
  def self.take_name(index)
    step = index.to_i - (@view ? @view["pick"].to_i : 0)
    take_view(call(PICK_TOPIC, step)) unless step == 0
    take_view(call(TAKE_PICK_TOPIC))
  end

  # Tells the tab the view shows.
  #
  # @return [String] One of TABS.
  def self.view_tab
    (@view && @view["tab"]) || "all"
  end

  # Tells the tabs the view shows, in their order.
  #
  # @return [Array<String>] The tabs.
  def self.tabs
    shown = Array(@view && @view["tabs"])
    TABS.select { |tab| shown.include?(tab) }
  end

  # Tells whether a tab holds lines the player did not read.
  #
  # @param tab [String] The tab.
  # @return [Boolean] Whether it does.
  def self.unread?(tab)
    Array(@view && @view["unread"]).include?(tab)
  end

  # Tells whether the tabs show above the closed log: while a tab holds unread lines and the log
  # shows lines.
  #
  # @return [Boolean] Whether they do.
  def self.unread_shown?
    !Array(@view && @view["unread"]).empty? && !Array(@view && @view["lines"]).empty?
  end

  # Tells the text the model holds in the box.
  #
  # @return [String] The text, empty while the box is closed.
  def self.box_text
    box = @view && @view["box"]
    box ? box[0].to_s : ""
  end

  # Tells whether the box shows the help tab, which takes no typing.
  #
  # @return [Boolean] Whether it does.
  def self.help_tab?
    view_tab == "help"
  end

  # Tells what the box row says before the text: the chat it sends to, whom a whisper goes to.
  #
  # @return [String] The label.
  def self.label
    return LABELS["help"] if help_tab?

    channel = @view && @view["channel"]
    channel == "whisper" && @view["whisper_to"] ? "To #{@view['whisper_to']}:" : LABELS[channel].to_s
  end

  # Tells the color of the box row's label: the chat's it sends to, plain on the help tab.
  #
  # @return [Symbol, nil] The color's name, nil for plain text.
  def self.label_color
    help_tab? ? nil : CHANNEL_COLORS[@view && @view["channel"]]
  end

  # Tells the names that fit what the box holds, which it offers.
  #
  # @return [Array<String>] The names.
  def self.suggestions
    Array(@view && @view["suggestions"])
  end

  # Tells what the empty box says: the help tab's with the close keys, the Alt controls while the
  # player holds the left Alt, else the plain hint.
  #
  # @return [String] The hint.
  def self.hint
    return "#{HELP_HINT} #{UI.close_hint}" if help_tab?

    UI.arranging? ? ALT_HINT : BOX_HINT
  end

  # Lists the log's rows of the view's lines.
  #
  # @param open [Boolean] Whether the box is open, in which a name can be clicked.
  # @return [Array] The rows.
  def self.rows(open)
    Array(@view && @view["lines"]).map { |line| row_of(line, open) }
  end

  # Makes a row of the log of a line of the view: its tag, its sender's name and its text in their
  # colors; open, another player's name can be clicked.
  #
  # @param line [Array] [tag, name, text, who, channel, id, fade].
  # @param open [Boolean] Whether the box is open.
  # @return [Array<Hash>, Hash] The row's parts, with its opacity while it fades.
  def self.row_of(line, open)
    tag, name, text, who, channel, id, fade = line
    parts = []
    parts << colored(tag, who == "admin" ? :gold : CHANNEL_COLORS[channel]) unless tag.to_s.empty?
    unless name.to_s.empty?
      part = colored(name, NAME_COLORS[who])
      part[:data] = id if open && id
      parts << part
    end
    parts << colored(text.to_s, text_color(who, channel))
    fade ? { :parts => parts, :opacity => 255 * fade.to_i / FADE_FRAMES } : parts
  end

  # Makes a part of a row, colored when a color is named.
  #
  # @param text [String] Its text.
  # @param color [Symbol, nil] Its color's name, nil for plain text.
  # @return [Hash] The part.
  def self.colored(text, color)
    color ? { :text => text, :color => color } : { :text => text }
  end

  # Picks the color of a line's text: a notice of the relay's own red, the chats of COLORED_TEXT in
  # their color, any other plain.
  #
  # @param who [String] Whose line it is.
  # @param channel [String, nil] Its chat.
  # @return [Symbol, nil] The color's name, nil for plain text.
  def self.text_color(who, channel)
    return NOTICE_COLOR if who == "notice"

    COLORED_TEXT.include?(channel) ? CHANNEL_COLORS[channel] : nil
  end

  # Opens the menu of a player whose name was clicked in the log at the pointer: what every script
  # offers with them and a whisper; off the map, in a battle, a shop, the casino or a trade, the
  # whisper alone. A choice that cannot be taken now is greyed with why as its tooltip.
  #
  # @param id [String] Their player id.
  def self.open_menu(id)
    peer = MGQ_MpOverworldSync::Peers.with_id(id)
    return log("no menu: the player of id #{id} left the world") unless peer

    name = MGQ_MpOverworldSync::Peers.label_of(peer) || peer.state["name"].to_s
    whisper = MGQ_MpActions::Option.new("Whisper", lambda { MGQ_MpChat.take_view(MGQ_MpChat.call(WHISPER_TOPIC, peer.seat)) }, nil)
    options = SceneManager.scene.is_a?(Scene_Map) ? MGQ_MpActions.peer_options(peer) + [whisper] : [whisper]
    choices = options.map { |option| { :text => option.text.to_s, :enabled => !option.run.nil?, :tooltip => option.refusal } }
    menu = UI.menu(choices, :title => name, :at => :pointer) { |_choice, index| MGQ_MpChat.menu_taken(name, options, index) }
    return log("the menu of #{name} did not open: another menu is open") unless menu

    log("menu of #{name} opened from the chat: #{options.map { |option| option.text }.join(', ')}")
  end

  # Takes a choice of a player's menu, or its close without one. A choice that leaves, such as
  # accepting a duel, closes the chat box too.
  #
  # @param name [String] The player's name.
  # @param options [Array<MGQ_MpActions::Option>] The menu's choices.
  # @param index [Integer, nil] The choice taken, nil when the menu closed without one.
  def self.menu_taken(name, options, index)
    option = index && options[index]
    return log("menu of #{name} closed: no choice taken") unless option

    log("menu of #{name} closed: chose #{option.text}")
    MGQ_MpActions.choose(option) { stop_typing("#{option.text} leaves the chat") if option.leaves }
  end

  # Shows a bubble above each player the view has one for, and hides those it has none for any
  # longer; outside a world none shows.
  def self.refresh_bubbles
    wanted = MGQ_MpOverworldSync.in_world? && @view.is_a?(Hash) ? (@view["bubbles"] || {}) : {}
    (@bubbles.keys - wanted.keys).each do |seat|
      bubble = @bubbles.delete(seat)
      bubble.hide if bubble && bubble.shown?
    end
    wanted.each_key do |seat|
      next if @bubbles[seat] && @bubbles[seat].shown?

      bubble = available? ? UI.show(ChatBubble, :seat => seat) : nil
      bubble ? @bubbles[seat] = bubble : @bubbles.delete(seat)
    end
  rescue => e
    log("showing the bubbles FAILED: #{e.class}: #{e.message}")
  end

  # Tells the line a player's bubble says.
  #
  # @param seat [Integer] Their seat, OWN_SEAT for the player.
  # @return [Array(String, String), nil] Its text and its chat, nil while the view has none.
  def self.bubble_of(seat)
    bubbles = @view.is_a?(Hash) ? (@view["bubbles"] || {}) : {}
    bubbles[seat]
  end

  # Finds whom a player's bubble follows: the player, or another player's ghost on this map.
  #
  # @param seat [Integer] Their seat, OWN_SEAT for the player.
  # @return [Game_Character, nil] The character, nil while this map does not show them.
  def self.bubble_character(seat)
    return $game_player if seat == OWN_SEAT

    peer = MGQ_MpOverworldSync::Peers.at(seat)
    peer && peer.ghost
  end

  # Tells whether a player's bubble hides now: while this map does not show them, and the player's
  # own while the action wheel is open.
  #
  # @param seat [Integer] Their seat, OWN_SEAT for the player.
  # @return [Boolean] Whether it hides.
  def self.bubble_hidden?(seat)
    bubble_character(seat).nil? || (seat == OWN_SEAT && MGQ_MpActions.wheel_open?)
  end

  # Names a scene as the chat's model reads it: by its class, or for a class without a name, such
  # as one made with Class.new, by the nearest named class it builds on.
  #
  # @param scene [Scene_Base, nil] The scene.
  # @return [String] The name.
  def self.scene_name(scene)
    named = scene.class
    named = named.superclass while named.name.nil?
    named.name
  end

  # Stages the scene in front for the chat's model, which closes the box where the chat does not
  # open, and closes the log and the bubbles once no world is open. Called by overworld_sync.rbx
  # every frame in every scene.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    scene = SceneManager.scene
    MGQ_Multiplayer::Bridge.stage(SCENE_TOPIC, "scene" => scene_name(scene), "chat_scene" => chat_scene?(scene) ? true : false)
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

    if !typing? && chat_key && available? && !MGQ_MpActions.wheel_open? && map_open?
      Sound.play_ok
      start_typing(MGQ_MpHotkeys.code(:chat))
    elsif !typing? && chat_key
      MGQ_MpHotkeys.log_refusal(:chat, !available? ? 'the keyboard cannot reach the game' : MGQ_MpActions.wheel_open? ? 'the action wheel is open' : 'an event runs on the map')
    end
    show_in(:chat)
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
    chat_anywhere(:menu_chat, scene_name(SceneManager.scene), true)
  end

  # Shows the log in a place and opens the chat box with its key, in a scene that holds no event the
  # chat box could interrupt.
  #
  # @param place [Symbol] The log's place, one of PLACES.
  # @param where [String] The scene, for the log.
  # @param menus [Boolean] Whether the scene is one of menus, where the chat box waits while a box
  #   of a mod, such as a question, holds the buttons over the scene.
  def self.chat_anywhere(place, where, menus = false)
    chat_key = MGQ_MpHotkeys.pressed?(:chat)
    return drop_root unless MGQ_MpOverworldSync.in_world?

    held = menus && !typing? && held_over_scene?
    if !typing? && chat_key && available? && !held
      Sound.play_ok
      start_typing(MGQ_MpHotkeys.code(:chat))
    elsif !typing? && chat_key
      MGQ_MpHotkeys.log_refusal(:chat, held ? "another box of the mod holds the buttons" : "the keyboard cannot reach the game")
    end
    show_in(place)
  rescue => e
    log("#{where} chat failed: #{e.class}: #{e.message}")
  end

  # Tells whether a box of a mod holds the game's buttons over a scene of menus, such as a question,
  # which the chat box waits for. The trade screen's own window is the scene's, so over it only its
  # gold box and its question count.
  #
  # @return [Boolean] Whether one does.
  def self.held_over_scene?
    return MGQ_MpTradeUi.asking? if defined?(Scene_MpTrade) && SceneManager.scene.is_a?(Scene_MpTrade)

    UI.busy?
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

  # The chat in one of its places: while closed, the picked tab's recent lines without a frame,
  # resting under the game's windows and letting the pointer through, the tabs only while lines
  # wait unread; while open, framed above everything with the tabs, every kept line and the box.
  class ChatBox < UI::Component
    # Where it shows, one of PLACES.
    param :place

    # The tab picked, by its id.
    state(:picked_tab) { ChatBox.tab_id(place, MGQ_MpChat.view_tab) }

    watch { MGQ_MpChat.serial }
    watch { follow_tab }

    # Names a tab's id in a place.
    #
    # @param place [Symbol] One of PLACES.
    # @param tab [String] One of TABS.
    # @return [Symbol] The id.
    def self.tab_id(place, tab)
      :"#{place}_tab_#{tab}"
    end

    # Describes the chat.
    def render
      open = MGQ_MpChat.typing?
      name, _room, rest = PLACES[place]
      at, size = MGQ_MpChat.default_place(place)
      window nil, id: place, place_name: name, shown_in: MGQ_MpChat.scenes_of(place), captures: :typing, frame: open, mouse: open ? :all : :none,
                  layer: open ? :windows : rest, z: open ? TYPING_Z : 0, resizable: true, min_size: MIN_SIZE, at: at, width: size[0], height: size[1],
                  on_cancel: -> { MGQ_MpChat.cancelled; false } do
        tabs bind: :picked_tab, pages: false, id: :"#{place}_tabs", visible: open || MGQ_MpChat.unread_shown?, on_change: ->(picked) { pick(picked) } do
          MGQ_MpChat.tabs.each do |each|
            color = CHANNEL_COLORS[each]
            tab TAB_NAMES[each], { id: ChatBox.tab_id(place, each), badge: MGQ_MpChat.unread?(each) }.merge(color ? { color: color } : {})
          end
        end
        log MGQ_MpChat.rows(open), id: :"#{place}_log", rows_shown: :fill, wheel_rows: 3, scrollbar: open, keep_place: true,
                                   on_click: ->(_row, part) { MGQ_MpChat.open_menu(part[:data]) if part[:data] }
        component(ChatLine, place: place) if open
      end
    end

    private

    # Picks a tab the player clicked or stepped to through the model.
    #
    # @param picked [Symbol] The tab's id.
    def pick(picked)
      MGQ_MpChat.pick_tab(TABS.find { |each| ChatBox.tab_id(place, each) == picked })
    end

    # Keeps the picked tab on the view's, which the model decides.
    #
    # @return [String] The view's tab.
    def follow_tab
      shown = MGQ_MpChat.view_tab
      wanted = ChatBox.tab_id(place, shown)
      self.picked_tab = wanted unless picked_tab == wanted
      shown
    end
  end

  # The open box's row: the chat it sends to and the line typed, which types as it shows.
  class ChatLine < UI::Component
    # Where the chat shows, one of PLACES.
    param :place

    # The line typed, as the model holds it.
    state(:line) { MGQ_MpChat.box_text }

    watch { follow_box }

    # Describes the row.
    def render
      color = MGQ_MpChat.label_color
      stack row: true do
        text MGQ_MpChat.label, { typo: :body2 }.merge(color ? { color: color } : {})
        text_field nil, id: field_id, bind: :line, grow: 1, max_length: MAX_LENGTH, read_only: MGQ_MpChat.help_tab?, placeholder: -> { MGQ_MpChat.hint },
                        letters: false, steer: :"#{place}_log", keys: BOX_KEYS, completions: ->(_word) { MGQ_MpChat.suggestions },
                        on_change: ->(text) { MGQ_MpChat.typed(text) }, on_submit: ->(_text) { MGQ_MpChat.enter },
                        on_key: ->(name) { MGQ_MpChat.key(name) }, on_complete: ->(_text, index) { MGQ_MpChat.take_name(index) }
      end
    end

    # Types into the line as the box opens.
    def mounted
      part(field_id).focus
    end

    private

    # Names the line's id.
    #
    # @return [Symbol] The id.
    def field_id
      :"#{place}_field"
    end

    # Keeps the line on the model's text, which changes it as a command is taken out or a line
    # sent comes back.
    #
    # @return [String] The model's text.
    def follow_box
      text = MGQ_MpChat.box_text
      self.line = text unless line == text
      text
    end
  end

  # A chat line over its sender on this map, in its chat's color, as long as the model keeps it.
  class ChatBubble < UI::Component
    # The sender's seat, OWN_SEAT for the player.
    param :seat

    watch { [MGQ_MpChat.bubble_of(seat), MGQ_MpChat.bubble_character(seat)] }

    # Describes the bubble.
    def render
      text, channel = MGQ_MpChat.bubble_of(seat) || ["", nil]
      color = CHANNEL_COLORS[channel]
      bubble({ id: :"mgq_online_chat_bubble_#{seat == OWN_SEAT ? 'own' : seat}", follow: seat == OWN_SEAT ? :player : MGQ_MpChat.bubble_character(seat) || :player, side: :top,
               hide_while: -> { MGQ_MpChat.bubble_hidden?(seat) } }.merge(color ? { color: color } : {})) do
        text text, typo: :body2, wrap: true, most_lines: 3
      end
    end
  end
end

# The chats' colors, named once.

begin
  MGQ_MpChat::CHANNEL_RGB.each { |name, rgb| Mod_Framework::UI.color(name, rgb) }
rescue => e
  MGQ_MpChat.log("chat colors FAILED: #{e.class}: #{e.message}")
end

# What the chat takes from the DLL's chat model: its view, its sounds and the relay's notices.

begin
  MGQ_Multiplayer::Bridge.on(MGQ_MpChat::VIEW_EVENT) { |view| MGQ_MpChat.take_view(view) }
  MGQ_Multiplayer::Bridge.on(MGQ_MpChat::SOUND_EVENT) { |name| Sound.send("play_#{name}") if Sound.respond_to?("play_#{name}") }
  MGQ_Multiplayer::Bridge.on(MGQ_MpChat::ANNOUNCE_EVENT) { |text| MGQ_MpNotices.announce(text) if defined?(MGQ_MpNotices) }
rescue => e
  MGQ_MpChat.log("chat model FAILED: #{e.class}: #{e.message}")
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
