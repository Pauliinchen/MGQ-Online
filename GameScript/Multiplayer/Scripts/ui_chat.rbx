#----------------------------------------------------------------
#  ui_chat.rbx
#
#  Changelog:
#      Paulinchen  2026-10-11: Started the chat in the global chat instead of the map chat, also in every world after the first
#                            - Moved and resized the chat log with Alt and the mouse through MGQ_MpUi::Layout, the map's as Chat and the battle's as Battle chat, each starting where it lay before at the size chat_size keeps
#                            - Dropped the log's own resizing with Alt and the mouse, which kept its size in chat_size
#                            - Snapped the log's height to whole rows below its tabs and above the chat box
#                            - Raised the log's narrowest width to what its tabs and hints need, and its fewest rows to the list of fitting names
#                            - Drew a hint of the empty chat box in the tiny font while it is wider than its room
#                            - Offered the log to the layout whenever it shows, also while the chat box is closed
#                            - Drew the open chat, its tabs and a player's menu in the interface preset's colors and frames, anew once the preset changes
#                            - Took the left Alt from MGQ_MpUi::Layout and named moving, resizing and putting back the chat in the Alt hint and the help
#                            - Renamed the say chat to the map chat, chosen with /m or /map instead of /s or /say, its lines still marked say for the games of earlier releases
#                            - Drew the chats in the colors of World of Warcraft: the global chat plain white without a tag, the map chat in its zone pink, the party chat in its party blue and whispers in its whisper pink
#                            - Showed the Whisper tab only once the player whispered, got a whisper or chose the whisper chat, until the world closes
#                            - Named every player outside the party in plain white in the log
#                            - Drew the log, its tabs, its menu, the bubbles and the hints in the shared style, dropping the log's own colors and font size, and another player's name in their own color
#                            - Faded a line of the closed log away over its last frames instead of dropping it at once
#                            - Brought back the last 20 lines sent with Alt and up or down, kept only for the session
#                            - Answered the last player who whispered with /r, which chooses them for the whisper chat as /w does and is refused as /w is once they left
#                            - Played the recovery sound once a frame for whispers that arrive while the chat box is closed
#                            - Drew the tabs dimmed above the closed log while one holds unread lines, the Whisper tab glowing too
#                            - Buzzed once a frame for a paste longer than the box takes, not once per character
#                            - Named the sent lines, /r and Ctrl+V in the hints and the help
#      Paulinchen  2026-10-08: Split the chat into the global chat, the say chat that only the players on the same map hear, and the party chat, each kept by /g, /s or /p until another is chosen
#                            - Showed the log in tabs, all lines or one chat's, picked with the mouse or Alt with left and right
#                            - Resized the chat log with Alt and the mouse dragged, keeping its size in Player.ini
#                            - Wrote the chat log smaller
#                            - Brought the chat log above everything while the player types
#                            - Closed the chat box with the numpad's 0 through MGQ_MpUi.numpad_cancel?, also with Num Lock off
#                            - Mirrored only the global chat to the relay for the world's admins
#                            - Added whispers to one player with /w or /whisper and their name, offering the names that fit in a list above the box, and a Whisper tab in pale pink
#                            - Added a Help tab at the far right that /help opens, which only reads and closes once left, and named it and the resizing in the empty box
#                            - Drew the bubbles in their chat's color, slightly see-through
#                            - Lowered the bubbles to just over the name, going one line higher while a line such as an invite shows above it
#                            - Shortened the empty chat box's hint to scrolling, Alt and /help, and showed the tab and resize controls in its place while Alt is held
#                            - Let the Global, Party and Say tabs glow yellow at their top right corner while they hold lines the player has not seen, opaque at the corner
#                            - Picked the tabs and resized with the left Alt alone, dropping what it typed as an Alt code with the numpad, which showed a symbol the font lacks
#                            - Outlined the tabs and the open chat thinly, the chat in white while Alt is held to resize it, the picked tab open into the chat
#                            - Filled the picked tab with its chat's color under dark text, which white tabs lacked the contrast for
#                            - Opened a menu of what to do with another player, such as a party invite, a duel, a trade or a whisper, with a click on their name in the open chat box
#                            - Trusted only the relay's own mark on an admin's line, so a player's message cannot pose as one
#                            - Rested the map's chat log just under the topmost viewport, which it covered with the wheels and the World overview
#                            - Sized the log before following the mouse, which a held button crashed on a log made that frame
#                            - Found players through MGQ_MpOverworldSync::Peers and moved the three lists by one arrow step
#                            - Stopped following the keys and the mouse once a menu's choice closed the chat box, which failed on the closed box
#                            - Offered only the whisper in a player's menu during a battle
#                            - Showed whispers in the closed chat log whatever the tab
#                            - Numbered a name that several players share in the whisper list and /w, and whispered to the player chosen by their id
#                            - Named the sender of a line by the same numbered name, in the log and in their menu
#                            - Sent a line of the say chat once to everyone with the sender's map, on which alone it shows
#                            - Mirrored a global line to the relay before sending it, turning it down when it comes too fast
#                            - Left out the 0 that the numpad's 0 types after it closed a player's menu
#                            - Kept the chat's size while a battle draws the log smaller, and kept a drag within the screen
#                            - Kept the typing of a frame in which the menu's player left, without its Enter or Escape
#                            - Colored the sender's name and kept its click spot when the line breaks right after it
#                            - Left out the line and paragraph separators of players' and admins' lines
#                            - Built a menu's choices and the fitting names once per frame
#                            - Said how to close the chat box, the help tab and a player's menu
#      Paulinchen  2026-10-07: Mirrored every line sent to everyone to the relay for the world's admins, and showed an admin's line from the relay as [Admin] in gold
#                            - Closed the chat box with the numpad's 0, as the game's windows close
#                            - Scrolled the chat log while the box is open with up, down, Page Up and Page Down, keeping the rows in place as lines come in
#                            - Registered the map's, the battle's and its sprites' hooks through core_hooks.rbx instead of wraps of this script
#                            - Named senders through MGQ_MpOverworldSync.who and took white and the depths from MGQ_MpUi
#                            - Logged the chat box opening and closing with why, each line sent, refused or received with a count, cut to 80 characters, the game's own lines and the chat forgotten
#      Paulinchen  2026-10-06: Opened the chat box while the map shows a message, such as the story's dialogue
#                            - Added the chat's choice to the action wheel's ring by order instead of to its left
#      Paulinchen  2026-10-05: Took the typing of an open chat box while the map shows a message, which left both stuck
#      Paulinchen  2026-10-04: Named the party tag by its module inside the log line, as Ruby 1.9 finds it
#                            - Sent a line typed with /p to the party only, and colored the senders' names: own yellow, the party's green, others white
#                            - Opened the chat box while the player waits for the party's story, and kept an open box once an event starts
#                            - Left out the character of the key that opened the chat box, which arrived after it opened
#                            - Removed BLINK_FRAMES, which MGQ_MpUi::TextEdit holds
#                            - Renamed from mp_chat.rbx
#                            - Drew the chat box through MGQ_MpUi::TextBox, which every text box shares
#                            - Typed through MGQ_MpUi::TextEdit, which every text box shares
#      Paulinchen  2026-10-03: Broke lines through MGQ_MpUi.wrap, which the windows share
#                            - Filled the wheel's chat choice and told the wheel while the chat box is open
#                            - Asked MGQ_MpOverworldSync whether the map is quiet or the player free on it
#                            - Sent messages, showed notices and read the world, the own id and the own seat through MGQ_MpOverworldSync
#                            - Logged through MGQ_MpLog
#                            - Read the bound keys through MGQ_MpHotkeys, renamed from MGQ_MpKeys
#      Paulinchen  2026-10-02: Opened the chat box with the key the player bound
#                            - Followed the map and its sprites through core_hooks.rbx
#      Paulinchen  2026-10-01: Let the chat box and the chat log work in battles, above the battle's windows
#                            - Showed the game's own lines in the chat log, such as a player leaving a battle
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# The chat: a line typed on the keyboard goes to every player of the world, to the party, to the
# players on the same map or to one player, by the chat chosen, shows in a bubble above the sender
# while they are on the same map, and in the chat log at the bottom left. Its hotkey (T unless the
# player binds another, see core_hotkeys.rbx) or the action wheel of ui_actions.rbx opens the chat
# box. It builds on overworld_sync.rbx, which knows the other players and their messages.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpChat
  # Characters a chat line may have.
  MAX_LENGTH = 120

  # Chat lines kept for the log.
  KEPT = 50

  # Frames a chat line stays in the log, ten seconds, unless the chat box is open.
  LOG_FRAMES = 600

  # Frames a bubble stays, six seconds.
  BUBBLE_FRAMES = 360

  # Frames after the chat key opened the box in which the key's own character may still arrive.
  KEY_ECHO_FRAMES = 10

  # Windows' code of the number row's 0, as which the numpad's 0 types with Num Lock on.
  ZERO_KEY = 0x30

  # What mp_world_say answers for a line of the global chat the DLL dropped for coming too fast.
  TOO_FAST = 2

  # What mp_world_say answers for a line of the global chat the relay got.
  SAID = 1

  # What a player's or an admin's line loses: control characters and the line and paragraph
  # separators, which would break the line in the log.
  LINE_BREAKERS = /[[:cntrl:]  ]/

  # Windows' codes of Page Up and Page Down, which scroll the chat log a page.
  PAGE_UP_KEY = 0x21
  PAGE_DOWN_KEY = 0x22

  # Rows Page Up and Page Down scroll the chat log by.
  PAGE_ROWS = 5

  # Windows' code of the left Alt, the layout's: with left or right it picks the log's tab, with up
  # or down it brings back the lines sent, and with the mouse the layout moves and resizes the log.
  ALT_KEY = MGQ_MpUi::Layout::ALT_KEY

  # Windows' codes of left, right and Tab.
  LEFT_KEY = 0x25
  RIGHT_KEY = 0x27
  TAB_KEY = 0x09

  # Windows' codes of up and down, which with the left Alt bring back the lines sent.
  UP_KEY = 0x26
  DOWN_KEY = 0x28

  # Lines sent that Alt with up and down bring back, kept for the session alone.
  HISTORY_SIZE = 20

  # The sound a whisper plays when it arrives while the chat box is closed: the game's recovery
  # chime, short and clearly heard, which nothing on the map plays by itself, unlike the cursor,
  # the ok and the cancel sounds of the menus; in a battle the game plays it for a heal too.
  WHISPER_SOUND = :play_recovery

  # Frames after Alt was let go in which what arrives is dropped: Alt with the numpad's digits, as
  # its arrows are with Num Lock off, types an Alt code once Alt is let go.
  ALT_CODE_FRAMES = 2

  # The chats a line goes to, in the order of their tabs.
  CHANNELS = [:global, :map, :party, :whisper]

  # The log's tabs, in their order: all lines, then each chat's. The Whisper tab shows only once the
  # player whispered or was whispered to, see whisper_tab?, and the help tab joins at the far right
  # while it is open.
  TABS = [:all] + CHANNELS

  # The chats whose tab marks lines the player has not seen yet: every chat, the whispers too,
  # although the closed log shows them whatever the tab, so their tab glows as the others do.
  UNREAD_CHATS = CHANNELS

  # What the tabs say.
  TAB_NAMES = { :all => "All", :global => "Global", :map => "Map", :party => "Party", :whisper => "Whisper", :help => "Help" }

  # The commands that choose a chat, which holds for the lines after it until another is chosen.
  COMMANDS = { "g" => :global, "global" => :global, "m" => :map, "map" => :map, "p" => :party, "party" => :party }

  # A command at the start of a line, its name in the first group.
  COMMAND = /\A\/([a-z]+)(\s+|\z)/i

  # The command that whispers to one player, their name after it.
  WHISPER_COMMAND = /\A\/(w|whisper)(\s+|\z)/i

  # The whisper command with the start of a name typed, which offers the names that fit.
  WHISPER_TYPED = /\A\/(?:w|whisper) +(\S.*)\z/i

  # The command that answers the last player who whispered to the player, see reply_to.
  REPLY_COMMAND = /\A\/r(\s+|\z)/i

  # The command that opens the help tab.
  HELP_COMMAND = /\A\/help(\s|\z)/i

  # Names the list of fitting names offers at most.
  SUGGESTIONS = 5

  # What the help tab says.
  HELP = ["A chat stays chosen until you choose another, by a command or a tab.",
          "/g <text>   Global: everyone in the world",
          "/m <text>   Map: the players on your map",
          "/p <text>   Party: your party only",
          "/w <name> <text>   Whisper: one player. Up and Down pick a name from the list, Enter or Tab takes it.",
          "/r <text>   Whisper back to the last player who whispered to you.",
          "Tabs: click one, or Alt with Left or Right. All shows every chat.",
          "Alt and a drag with the mouse move or resize the chat, Alt and a double click put it back.",
          "Alt with Up or Down brings back the lines you sent. Ctrl+V pastes.",
          "Up, Down, Page Up and Page Down scroll. Enter sends, Esc or the numpad's 0 closes."]

  # What the log shows before a line of a chat, the global chat showing none. A whisper the player
  # sent shows whom it went to instead.
  TAGS = { :map => "[Map] ", :party => "[Party] ", :whisper => "[Whisper] " }

  # What the log shows before a line an admin said from outside the game, through the relay.
  ADMIN_TAG = "[Admin] "

  # The setting in Player.ini that holds the log's size as width x rows, the size the layout starts
  # it at.
  #
  # Builds before the layout resized the log by themselves and kept its size here.
  SIZE_SETTING = "chat_size"

  # The log's size without SIZE_SETTING: its width and its rows of lines.
  DEFAULT_SIZE = [400, 6]

  # A line of the chat log.
  #
  # @!attribute name [String, nil] The sender's name, nil for a line of the game's own.
  # @!attribute text [String] The line.
  # @!attribute who [Symbol] Whose it is, which colors the name: :me, :member (of the player's
  #   party), :other, :admin (said through the relay), :system or :help (a line of the help tab).
  # @!attribute channel [Symbol, nil] Its chat, one of CHANNELS, :help for a line of the help tab,
  #   nil for a line of the game's own.
  # @!attribute left [Integer] Frames it still shows while the chat box is closed.
  # @!attribute to [String, nil] Whom the player whispered it to, nil for any other line.
  # @!attribute id [String, nil] The sender's player id, for their menu; nil for the player's own
  #   lines, an admin's and the game's.
  Line = Struct.new(:name, :text, :who, :channel, :left, :to, :id) do
    # Writes the tag before the sender's name: the admin's, whom the player whispered to, or the chat's.
    #
    # @return [String] The tag, empty for the global chat and the game's own lines.
    def tag
      return MGQ_MpChat::ADMIN_TAG if who == :admin
      return "[To #{to}] " if to

      MGQ_MpChat::TAGS[channel].to_s
    end

    # Writes what comes before the line itself: the tag and the sender's name.
    #
    # @return [String] The head, "* " for a line of the game's own, none for the help's.
    def head
      case who
      when :system then "* "
      when :help then ""
      else "#{tag}#{name}: "
      end
    end

    # Reports whether a tab of the log shows the line. The game's own lines show in every tab.
    #
    # @param tab [Symbol] The tab, one of TABS.
    # @return [Boolean] Whether it does.
    def shown_in?(tab)
      tab == :all || channel.nil? || channel == tab
    end

    # Writes the whole line, as the log shows it.
    #
    # @return [String] The line.
    def to_s
      head + text
    end
  end

  @log = []
  @bubbles = {}
  @edit = nil
  @sent = 0
  @received = 0
  @scroll = 0
  @channel = :global
  @tab = :all
  @unread = {}
  @whisper_to = nil
  @whisper_id = nil
  @pick = 0
  @alt_frames = 0
  @menu = nil
  @frame = 0
  @history = []
  @history_at = nil
  @draft = nil
  @reply_to = nil
  @buzzed = nil
  @chimed = nil
  @whisper_tab = false

  # The help tab's lines, which no other tab shows.
  HELP_LINES = HELP.map { |text| Line.new(nil, text, :help, :help, 0) }

  # Tells the chat a line without a command goes to.
  #
  # @return [Symbol] One of CHANNELS.
  def self.channel
    @channel
  end

  # Tells whom the whisper chat goes to.
  #
  # @return [String, nil] Their name, nil before the player chose anyone.
  def self.whisper_to
    @whisper_to
  end

  # Tells the last player who whispered to the player, whom /r answers.
  #
  # @return [String, nil] Their name as the log showed it, nil before anyone whispered.
  def self.reply_to
    @reply_to && @reply_to[0]
  end

  # Lists the lines the player sent, which Alt with up and down bring back.
  #
  # @return [Array<String>] The lines as typed, commands included, oldest first, HISTORY_SIZE at most.
  def self.history
    @history
  end

  # Keeps a line the player sent for Alt with up and down, unless it repeats the last one, and
  # forgets the oldest beyond HISTORY_SIZE. Also ends a walk through the lines.
  #
  # @param text [String] The line as typed, commands included.
  def self.remember_sent(text)
    @history_at = nil
    @draft = nil
    return if text.empty? || @history.last == text

    @history.push(text)
    @history.shift while @history.size > HISTORY_SIZE
  end

  # Brings a line sent back into the chat box: up the one before, down the one after, and past the
  # newest what the box held before the walk began. It stays at the oldest and at the draft.
  #
  # @param step [Integer] -1 for the line before, 1 for the one after.
  def self.walk_history(step)
    return log("no line sent to bring back") if @history.empty?

    at = @history_at || @history.size
    to = MGQ_MpUi.within(at + step, 0, @history.size)
    return if to == at

    @draft = @edit.text if @history_at.nil?
    @history_at = to == @history.size ? nil : to
    text = @history_at ? @history[to] : @draft.to_s
    @edit.edit(text, text.size)
    Sound.play_cursor
    log(@history_at ? "brought back sent line #{to + 1} of #{@history.size}" : "back at the line being typed")
  end

  # Tells the log's tab.
  #
  # @return [Symbol] One of tabs.
  def self.tab
    @tab
  end

  # Lists the log's tabs: the Whisper tab once whisper_tab? tells so, the help tab at the end while
  # it is open.
  #
  # @return [Array<Symbol>] The tabs, in their order.
  def self.tabs
    shown = @whisper_tab ? TABS : TABS - [:whisper]
    @tab == :help ? shown + [:help] : shown
  end

  # Reports whether the Whisper tab shows: once the player whispered, got a whisper or chose the
  # whisper chat, until the world closes.
  #
  # @return [Boolean] Whether it does.
  def self.whisper_tab?
    @whisper_tab
  end

  # Lists the tabs with lines the player has not seen yet: lines of a chat in UNREAD_CHATS that
  # came while neither its tab nor All was picked.
  #
  # @return [Array<Symbol>] The tabs, in TABS order.
  def self.unread_tabs
    UNREAD_CHATS.select { |chat| @unread[chat] }
  end

  # Takes the picked tab's lines as seen, all of them on the All tab.
  def self.see_tab
    @tab == :all ? @unread.clear : @unread.delete(@tab)
  end

  # Picks a tab of the log. A chat's tab also chooses that chat for the lines after it; leaving the
  # help tab closes it.
  #
  # @param tab [Symbol] The tab, one of tabs.
  # @param how [String] How it was picked, for the log.
  def self.select_tab(tab, how)
    return if tab == @tab

    @tab = tab
    @channel = tab if CHANNELS.include?(tab)
    @scroll = 0
    Sound.play_cursor
    log("picked the #{TAB_NAMES[tab]} tab #{how}, lines go to the #{TAB_NAMES[@channel]} chat")
  end

  # Opens the help tab, which the chat box only reads in.
  def self.open_help
    @before_help = @tab unless @tab == :help
    @tab = :help
    @scroll = 0
    @edit.edit("", 0)
    Sound.play_ok
    log("opened the help tab")
  end

  # Leaves the help tab for the tab it was opened from, as when the chat box closes.
  def self.leave_help
    @tab = @before_help || :all if @tab == :help
  end

  # Chooses the chat for the lines after it. The log follows to its tab unless it shows all lines.
  #
  # @param channel [Symbol] One of CHANNELS.
  def self.choose(channel)
    @whisper_tab = true if channel == :whisper
    @channel = channel
    @scroll = 0 unless @tab == :all || @tab == channel
    @tab = channel unless @tab == :all
    log("chose the #{TAB_NAMES[channel]} chat")
  end

  # Chooses whom the whisper chat goes to, and the whisper chat.
  #
  # The player is kept by their id, since the numbers of a name that several share change as they
  # come and go.
  #
  # @param name [String] Their name, numbered when several share it, see names.
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] The player, nil when nobody has that name.
  def self.whisper(name, peer = MGQ_MpOverworldSync::Peers.named(name))
    @whisper_to = name
    @whisper_id = peer && peer.state["id"].to_s
    choose(:whisper)
  end

  # Lists the names of the world's other players, whom the player may whisper to; a name that
  # several share is numbered, such as "Name (2)", so each of them is reachable.
  #
  # @return [Array<String>] The names.
  def self.names
    MGQ_MpOverworldSync::Peers.labeled.map(&:first)
  end

  # Lists the names that fit what follows the whisper command in the chat box, before a name was
  # taken, once per frame and text.
  #
  # @return [Array<String>] Up to SUGGESTIONS names, by the alphabet; none without the command and
  #   a character after it.
  def self.suggestions
    key = [@frame, @edit && @edit.text.dup, @tab]
    @suggested = [key, fitting_names] unless @suggested && @suggested[0] == key
    @suggested[1]
  end

  # Finds the names that fit what follows the whisper command in the chat box, see suggestions.
  #
  # @return [Array<String>] The names.
  def self.fitting_names
    match = @edit && @tab != :help && @edit.text.match(WHISPER_TYPED)
    return [] unless match

    start = match[1].downcase
    names.select { |name| name.downcase.start_with?(start) }.sort_by(&:downcase).first(SUGGESTIONS)
  end

  # Tells which of the fitting names Enter or Tab takes.
  #
  # @return [Integer] Its place in suggestions.
  def self.pick
    [@pick, [suggestions.size - 1, 0].max].min
  end

  # Takes the picked name of the list for the whisper chat, emptying the box.
  #
  # @return [Boolean] Whether a name was there to take.
  def self.take_suggestion
    name = suggestions[pick]
    return false unless name

    whisper(name)
    @edit.edit("", 0)
    Sound.play_ok
    true
  end

  # Tells the menu of another player that a click on their name in the log opened.
  #
  # @return [Hash, nil] Their :id and :name, the choice picked as :pick and where it opened as :at;
  #   nil while no menu is open.
  def self.menu
    @menu
  end

  # Opens the menu of a line's sender.
  #
  # @param line [Line] The line, whose sender has an id.
  # @param at [Array<Integer>] Where on the screen the menu opens: the left and the top of the name.
  def self.open_menu(line, at)
    @menu = { :id => line.id, :name => line.name, :pick => 0, :at => at }
    Sound.play_ok
    log("menu of #{line.name} opened from the chat: #{menu_options.map(&:text).join(', ')}")
  end

  # Closes the menu of another player, if one is open.
  #
  # @param reason [String] Why, for the log.
  def self.close_menu(reason)
    return unless @menu

    log("menu of #{@menu[:name]} closed: #{reason}")
    @menu = nil
  end

  # Finds the player whose menu is open, while they are in the world.
  #
  # @return [MGQ_MpOverworldSync::Peers::Peer, nil] The player, nil without a menu or once they left.
  def self.menu_peer
    @menu && MGQ_MpOverworldSync::Peers.with_id(@menu[:id])
  end

  # Lists the choices of the open menu, built once per frame and menu, see build_menu_options.
  #
  # @return [Array<MGQ_MpActions::Option>] The choices, none without a menu or once the player left.
  def self.menu_options
    key = [@frame, @menu && @menu.object_id]
    @menu_options = [key, build_menu_options] unless @menu_options && @menu_options[0] == key
    @menu_options[1]
  end

  # Builds the choices of the open menu: what every script offers with the player, see
  # MGQ_MpActions.peer_options, and a whisper; in a battle the whisper alone, since the others
  # start what a battle cannot take part in, such as a party, a duel or a trade.
  #
  # @return [Array<MGQ_MpActions::Option>] The choices, none without a menu or once the player left.
  def self.build_menu_options
    peer = menu_peer
    return [] unless peer

    name = MGQ_MpOverworldSync::Peers.label_of(peer) || peer.state["name"].to_s
    option = MGQ_MpActions::Option.new("Whisper", lambda { whisper(name, peer) }, nil)
    SceneManager.scene.is_a?(Scene_Battle) ? [option] : MGQ_MpActions.peer_options(peer) + [option]
  end

  # Points at a choice of the open menu.
  #
  # @param index [Integer] Its place among menu_options.
  def self.point_menu(index)
    @menu[:pick] = index if @menu
  end

  # Takes a choice of the open menu, closing it, or tells why it cannot be taken. A choice that
  # leaves, such as accepting a duel, closes the chat box too, after which the callers stop
  # following the keys and the mouse for the frame.
  #
  # @param index [Integer] Its place among menu_options.
  def self.take_menu(index)
    option = menu_options[index]
    return close_menu("its player left the world") unless option

    MGQ_MpActions.choose(option) do
      close_menu("chose #{option.text}")
      stop_typing("#{option.text} leaves the chat") if option.leaves
    end
  end

  # Moves the pick through the open menu with up and down.
  def self.update_menu_pick
    step = arrow_step
    size = menu_options.size
    return if step == 0 || size == 0

    @menu[:pick] = (@menu[:pick] + step) % size
    Sound.play_cursor
  end

  # Finds the player a whisper command names at the start of a text, the longest name that fits.
  #
  # @param text [String] What follows the command.
  # @return [String, nil] Their name, nil when no player's name starts the text.
  def self.named_in(text)
    names.sort_by { |name| -name.size }.find do |name|
      text.downcase.start_with?(name.downcase) && (text.size == name.size || text[name.size, 1] =~ /\s/)
    end
  end

  # Takes a command that chooses a chat from the start of a text.
  #
  # @param text [String] The text.
  # @param ended [Boolean] Whether the text is complete, so a command needs no space after it.
  # @return [String, nil] The text after the command, nil when it starts with none.
  def self.take_command(text, ended)
    match = text.match(COMMAND)
    channel = match && COMMANDS[match[1].downcase]
    return nil unless channel && (ended || !match[2].empty?)

    choose(channel)
    text[match[0].size..-1]
  end

  # Tells the log's size until the player resizes it through the layout: SIZE_SETTING's, else
  # DEFAULT_SIZE.
  #
  # @return [Array<Integer>] Its width and its rows of lines.
  def self.size
    @size ||= begin
      stored = MGQ_Multiplayer::Player.setting(SIZE_SETTING).to_s.split("x").map(&:to_i)
      stored.size == 2 && stored.all? { |value| value > 0 } ? stored : DEFAULT_SIZE
    end
  end

  # Reports whether the keyboard reaches the game, which only happens once its window is hooked.
  #
  # @return [Boolean] Whether it does.
  def self.available?
    MGQ_Multiplayer::Background.running?
  end

  # The action wheel's chat choice.
  #
  # @return [MGQ_MpActions::Option] The choice.
  def self.wheel_option
    MGQ_MpActions::Option.new("Chat (#{MGQ_MpHotkeys.label(:chat)})", available? ? lambda { start_typing } : nil,
                              "Chat needs the keyboard, which cannot reach the game.")
  end

  # Reports whether the chat box is open.
  #
  # @return [Boolean] Whether it is.
  def self.typing?
    !@edit.nil?
  end

  # The editor of the chat box.
  #
  # @return [MGQ_MpUi::TextEdit, nil] The editor, nil while the box is closed.
  def self.editor
    @edit
  end

  # The text in the chat box.
  #
  # @return [String, nil] The text, nil while the box is closed.
  def self.typed
    @edit && @edit.text
  end

  # Where the cursor stands in the chat box's text.
  #
  # @return [Integer] The characters before it.
  def self.cursor
    @edit ? @edit.cursor : 0
  end

  # Reports whether the blinking cursor shows this frame.
  #
  # @return [Boolean] Whether it does.
  def self.cursor_shown?
    @edit ? @edit.cursor_shown? : false
  end

  # Opens the chat box, which holds the buttons, so keys that type move nobody.
  #
  # @param key [Integer, nil] Windows' code of the key that opened it, nil when the wheel did.
  def self.start_typing(key = nil)
    @edit = MGQ_MpUi::TextEdit.new("", :max_chars => MAX_LENGTH)
    @echo = key ? { :key => key, :frames => KEY_ECHO_FRAMES } : nil
    @scroll = 0
    @history_at = nil
    @draft = nil
    MGQ_Multiplayer::Link.typing(true)
    MGQ_Multiplayer::Capture.start(:chat)
    log("chat box opened #{key ? 'with its key' : 'from the action wheel'} in #{SceneManager.scene.class.name}")
  end

  # Leaves out the character of the key that opened the chat box.
  #
  # The key is seen going down before the game's window gets the character it types, which then
  # reaches the box that just opened.
  #
  # @param text [String] What was typed since the last frame.
  # @return [String] The same, without the key's own character.
  def self.without_echo(text)
    echo = @echo
    return text unless echo

    echo[:frames] -= 1
    @echo = nil if echo[:frames] <= 0 || !text.empty?
    !text.empty? && text[0, 1].upcase.ord == echo[:key] ? text[1..-1] : text
  end

  # Closes the chat box, if it is open, and gives the buttons back.
  #
  # @param reason [String, nil] Why, for the log.
  def self.stop_typing(reason = nil)
    return unless typing?

    @edit = nil
    @scroll = 0
    @menu = nil
    leave_help
    MGQ_Multiplayer::Link.typing(false)
    MGQ_Multiplayer::Capture.stop(:chat)
    log("chat box closed#{reason ? ": #{reason}" : ''}")
  end

  # Types what came from the keyboard since the last frame, then lets the editor follow the keys
  # that type nothing, and scrolls the chat log. The numpad's 0 closes the open menu, else the box.
  def self.update_typing
    text, _keys = MGQ_Multiplayer::Link.take_typed
    if MGQ_MpUi.numpad_cancel?
      unless @menu
        # Its 0 arrives as the number row's, so what came with it is dropped; a 0 coming later
        # finds the typing off, which forgets it.
        stop_typing("Numpad 0")
        Sound.play_cancel
        return
      end

      Sound.play_cancel
      close_menu("Numpad 0")
      # Its 0 arrives as the number row's, in this frame or a later one, and the box stays open.
      @echo = { :key => ZERO_KEY, :frames => KEY_ECHO_FRAMES }
    end

    typed = without_alt_code(without_echo(text.to_s))
    if @menu && !menu_peer
      close_menu("its player left the world")
      # Enter and Escape were meant for the menu, so they neither send the line nor close the box.
      typed = typed.delete("\r\e")
    end

    tab_key = MGQ_Multiplayer::Key.pressed?(TAB_KEY)
    typed.each_char do |char|
      next tab_key = true if char == "\t"

      if @menu && (char == "\r" || char == "\e")
        menu_key(char)
      else
        type(char)
        take_typed_command if typing?
      end
      return unless typing?
    end
    take_suggestion if tab_key
    return if alt_keys

    @edit.update_keys unless @tab == :help
    return update_menu_pick if @menu

    suggestions.empty? ? update_scroll : update_pick
  end

  # Takes Enter or Escape while a player's menu is open: Enter takes the choice picked, Escape
  # closes the menu, not the chat box.
  #
  # @param char [String] "\r" or "\e".
  def self.menu_key(char)
    return take_menu(@menu[:pick]) if char == "\r"

    Sound.play_cancel
    close_menu("Escape")
  end

  # Drops what was typed while the left Alt is held and just after it was let go, which the numpad
  # types as an Alt code, such as a symbol for Alt with the numpad's 4, its left arrow.
  #
  # @param text [String] What was typed since the last frame.
  # @return [String] The same, empty while Alt is or just was held.
  def self.without_alt_code(text)
    @alt_frames = MGQ_Multiplayer::Key.down?(ALT_KEY) ? ALT_CODE_FRAMES : [@alt_frames - 1, 0].max
    return text if @alt_frames == 0 || text.empty?

    log("dropped #{text.size} characters typed with Alt")
    ""
  end

  # Takes a command as it is typed: /help and a space opens the help tab, a chat's command and a
  # space chooses that chat, each leaving the box without the command.
  def self.take_typed_command
    @pick = 0
    return open_help if @edit.text =~ HELP_COMMAND && @edit.text =~ /\s\z/

    rest = take_command(@edit.text, false)
    @edit.edit(rest, @edit.cursor - (@edit.text.size - rest.size)) if rest
  end

  # Follows the arrows with the left Alt: right picks the next tab and left the one before, round
  # the tabs; up and down bring back the lines sent, see walk_history, except on the help tab.
  #
  # Every arrow is read every frame, so a press Alt was let go during never counts later.
  #
  # @return [Boolean] Whether Alt is held, which leaves the arrows to the tabs and the lines sent.
  def self.alt_keys
    keys = MGQ_Multiplayer::Key
    tab_step = (keys.pressed?(RIGHT_KEY) ? 1 : 0) - (keys.pressed?(LEFT_KEY) ? 1 : 0)
    line_step = (keys.pressed?(DOWN_KEY) ? 1 : 0) - (keys.pressed?(UP_KEY) ? 1 : 0)
    return false unless keys.down?(ALT_KEY)

    shown = tabs
    select_tab(shown[(shown.index(@tab) + tab_step) % shown.size], "with Alt and the arrows") unless tab_step == 0
    walk_history(line_step) unless line_step == 0 || @tab == :help
    true
  end

  # Moves the pick through the list of fitting names with up and down.
  def self.update_pick
    step = arrow_step
    return if step == 0

    @pick = [[pick + step, 0].max, suggestions.size - 1].min
    Sound.play_cursor
  end

  # Tells where up and down move a list, each repeating while held.
  #
  # @return [Integer] 1 for down, -1 for up, 0 for neither or both.
  def self.arrow_step
    capture = MGQ_Multiplayer::Capture
    (capture.repeat?(:DOWN) ? 1 : 0) - (capture.repeat?(:UP) ? 1 : 0)
  end

  # Scrolls the chat log while the box is open: up and down a row, Page Up and Page Down a page.
  def self.update_scroll
    keys = MGQ_Multiplayer::Key
    step = -arrow_step
    step += PAGE_ROWS if keys.pressed?(PAGE_UP_KEY)
    step -= PAGE_ROWS if keys.pressed?(PAGE_DOWN_KEY)
    scroll_by(step)
  end

  # Scrolls the chat log, never below its newest row. The log's sprite keeps it above its oldest.
  #
  # @param rows [Integer] Rows to scroll up, a negative number to scroll down.
  def self.scroll_by(rows)
    @scroll = [@scroll + rows, 0].max
  end

  # Tells how far the chat log is scrolled up.
  #
  # @return [Integer] The rows below the last one shown, 0 while it shows the newest.
  def self.scroll
    @scroll
  end

  # Keeps the chat log scrolled no farther than its rows go, which only its sprite counts, having
  # broken the lines into rows.
  #
  # @param most [Integer] The most rows it may be scrolled.
  # @return [Integer] How far it is scrolled now.
  def self.limit_scroll(most)
    @scroll = [[@scroll, most].min, 0].max
  end

  # Types one character at the cursor: Enter takes the picked name of the list, opens the help
  # tab or sends, Escape closes. The help tab only reads, so nothing but Escape types there. A
  # character the box refuses buzzes once a frame, so a paste longer than the box takes buzzes once.
  #
  # @param char [String] The character.
  def self.type(char)
    return if @tab == :help && char != "\e"

    case @edit.type(char)
    when :enter
      return if take_suggestion
      return open_help if @edit.text.strip =~ HELP_COMMAND

      send_typed
    when :escape
      stop_typing("Escape")
      Sound.play_cancel
    when :refused
      Sound.play_buzzer unless @buzzed == @frame
      @buzzed = @frame
    end
  end

  # Sends the chat box's text to the chosen chat, closing the box; an empty box just closes. A
  # command at its start chooses the chat first, for this line and the ones after it, /r the
  # whisper chat to the last player who whispered, refused once they left as /w is. The line is
  # kept for Alt with up and down.
  def self.send_typed
    text = @edit.text.strip
    remember_sent(text)
    stop_typing("Enter")
    command = text.match(WHISPER_COMMAND)
    reply = text.match(REPLY_COMMAND)
    if command
      rest = text[command[0].size..-1]
      name = named_in(rest)
      return refuse(rest.empty? ? "Type a name after /w to whisper to them." : "Nobody called #{rest.split.first} is in the world.") unless name

      whisper(name)
      text = rest[name.size..-1]
    elsif reply
      return refuse("Nobody has whispered to you yet.") unless @reply_to

      peer = player_of(@reply_to[0], @reply_to[1])
      return refuse("#{@reply_to[0]} is not in the world.") unless peer

      log("/r answers #{@reply_to[0]}")
      whisper(MGQ_MpOverworldSync::Peers.label_of(peer) || @reply_to[0], peer)
      text = text[reply[0].size..-1]
    else
      text = take_command(text, true) || text
    end
    text = text.strip
    return if text.empty?

    channel = @channel
    return refuse("You are in no party, so nobody hears the party chat.") if channel == :party && !(defined?(MGQ_MpCoop) && MGQ_MpCoop.in_party?)
    return refuse("Type /w and a name to choose whom to whisper to.") if channel == :whisper && !@whisper_to

    # Only the global chat's lines reach the relay, whose limit drops those that come too fast.
    return if channel == :global && !mirror(text)

    name = MGQ_Multiplayer::Player.name.to_s
    sent = case channel
           when :party then MGQ_MpCoop.tell(-1, "pchat", text, "name" => name)
           when :global then tell("chat" => text, "name" => name)
           when :whisper then tell_whisper("whisper" => text, "name" => name)
           # A map line goes out marked say, the map chat's name before, which released games read.
           else tell_map("chat" => text, "name" => name, "ch" => "say")
           end
    return refuse(channel == :whisper ? "#{@whisper_to} is not in the world." : "The message could not be sent.") unless sent

    @sent += 1
    log("sent to the #{TAB_NAMES[channel]} chat#{channel == :whisper ? " of #{@whisper_to}" : ''} (line #{@sent} sent): #{shown_in_log(text, channel)}")
    add(:me, name, text, channel, false, false, channel == :whisper ? @whisper_to : nil)
  end

  # Mirrors a line of the global chat to the relay for the world's admins, before it goes to the
  # others, and turns it down when it comes too fast.
  #
  # @param text [String] The line.
  # @return [Boolean] Whether the line may go to the others, false when it came too fast.
  def self.mirror(text)
    said = MGQ_MpOverworldSync.say(text)
    if said == TOO_FAST
      refuse("You are sending too fast. Wait a moment, then send the line again.")
      return false
    end

    log("the relay did not take the line for the world's chat") unless said == SAID
    true
  end

  # Writes a line for Multiplayer InGame.log, leaving a whisper's text out.
  #
  # @param text [String] The line.
  # @param channel [Symbol] Its chat.
  # @return [String] What the log says of it.
  def self.shown_in_log(text, channel)
    channel == :whisper ? "(#{text.size} characters, not logged)" : MGQ_MpLog.short(text)
  end

  # Tells the player the whisper chat goes to something, through overworld_sync.rbx, and names them
  # as the whisper list does now.
  #
  # @param fields [Hash] The message's fields.
  # @return [Boolean] Whether it went out, false when they are not in the world.
  def self.tell_whisper(fields)
    peer = player_of(@whisper_to, @whisper_id)
    return false unless peer

    @whisper_to = MGQ_MpOverworldSync::Peers.label_of(peer) || @whisper_to
    MGQ_MpOverworldSync.tell(peer.seat, fields)
  end

  # Finds a player by their id, or by their name for one who had no state yet when they were
  # seen. A known id never falls back to the name, which another player may bear by now.
  #
  # @param name [String] Their name as the log shows it.
  # @param id [String, nil] Their player id, nil or empty for none.
  # @return [MGQ_MpOverworldSync::Peers::Peer, nil] The player, nil once they left the world.
  def self.player_of(name, id)
    peers = MGQ_MpOverworldSync::Peers
    id.to_s.empty? ? peers.named(name) : peers.with_id(id)
  end

  # Tells every other game a line of the map chat, with the player's map, on which the others hear
  # it, through overworld_sync.rbx.
  #
  # One message to all, since one to each player on the map could fail for some of them only.
  #
  # @param fields [Hash] The message's fields.
  # @return [Boolean] Whether it went out.
  def self.tell_map(fields)
    here = MGQ_MpOverworldSync::Peers.all.count { |peer| MGQ_MpOverworldSync::Peers.on_this_map?(peer) }
    log("#{here} other players on map #{$game_map.map_id} hear the map chat")
    tell(fields.merge("map" => $game_map.map_id))
  end

  # Turns a line down that cannot be sent.
  #
  # @param text [String] Why, as a notice.
  def self.refuse(text)
    log("did not send the line: #{text}")
    Sound.play_buzzer
    MGQ_MpOverworldSync.notice(text)
  end

  # Takes another player's line of the global or the map chat, or an admin's that the relay said,
  # marked :relay. A line of the map chat said on another map is dropped.
  #
  # The sender's map comes with the line, since their last state may lag behind or run ahead of it.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it, nil before their first state
  #   or for the relay.
  # @param message [Hash] The message, the line under "chat", "ch" "say" for the map chat with the
  #   sender's map under "map".
  def self.receive(peer, message)
    channel = message["ch"] == "say" ? :map : :global
    if channel == :map && !($game_map && !message["map"].to_s.empty? && message["map"].to_i == $game_map.map_id)
      return log("dropped a map line from #{peer ? MGQ_MpOverworldSync.who(peer) : message['name']}, said on map #{message['map'] || '?'}")
    end

    take_line(peer, message["chat"], message["name"], channel, message[:relay] == true)
  end

  # Takes a party member's line of the party chat. Called by coop.rbx, which drops another party's.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who sent it.
  # @param message [Hash] The message, the line under "pchat".
  def self.receive_party(peer, message)
    take_line(peer, message["pchat"], message["name"], :party)
  end

  # Takes a line another player whispered to the player alone.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it, nil before their first state.
  # @param message [Hash] The message, the line under "whisper".
  def self.receive_whisper(peer, message)
    take_line(peer, message["whisper"], message["name"], :whisper)
  end

  # Adds another player's line, without LINE_BREAKERS and cut to MAX_LENGTH, under the name that
  # tells them apart, such as "Name (2)" for one of several who share it.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it.
  # @param text [String, nil] The line.
  # @param name [String, nil] The name the message carries, for a sender without a state yet or an admin.
  # @param channel [Symbol] Its chat, one of CHANNELS.
  # @param admin [Boolean] Whether an admin said it through the relay, from outside the game.
  def self.take_line(peer, text, name, channel, admin = false)
    text = text.to_s.gsub(LINE_BREAKERS, "").strip[0, MAX_LENGTH]
    sender = peer ? MGQ_MpOverworldSync.who(peer) : admin ? "the admin #{name} through the relay" : "#{name} (no state yet, no bubble)"
    return log("dropped an empty #{TAB_NAMES[channel]} line from #{sender}") if text.empty?

    @received += 1
    log("#{TAB_NAMES[channel]} line from #{sender} (line #{@received} received): #{shown_in_log(text, channel)}")
    id = peer && !peer.state["id"].to_s.empty? ? peer.state["id"] : nil
    shown = peer ? MGQ_MpOverworldSync::Peers.label_of(peer) || peer.state["name"] : name
    add(peer ? peer.seat : nil, shown, text, channel, peer && member?(peer), admin, nil, id)
    whispered(shown.to_s, id) if channel == :whisper
  end

  # Takes note of a whisper that arrived: its sender is whom /r answers, and while the chat box is
  # closed, in which the log alone shows the line, WHISPER_SOUND calls the player's attention,
  # once a frame, so whispers that arrive together chime once.
  #
  # @param name [String] The sender's name as the log shows it.
  # @param id [String, nil] The sender's player id, nil without a state yet.
  def self.whispered(name, id)
    @reply_to = [name, id] unless name.empty?
    return if typing? || @chimed == @frame

    @chimed = @frame
    Sound.__send__(WHISPER_SOUND)
    log("played #{WHISPER_SOUND} for the whisper, the chat box being closed")
  end

  # Reports whether another player is in the player's party, whose name the log shows green.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
  # @return [Boolean] Whether they are.
  def self.member?(peer)
    defined?(MGQ_MpCoop) && MGQ_MpCoop.in_party? && MGQ_MpCoop::Party.member?(peer.state) ? true : false
  end

  # Adds a chat line to the log, and to the sender's bubble. A whisper shows the Whisper tab.
  #
  # @param sender [Integer, Symbol, nil] The sender's seat, :me for the player, nil for no bubble.
  # @param name [String] The sender's name.
  # @param text [String] The line.
  # @param channel [Symbol] Its chat, one of CHANNELS.
  # @param member [Boolean] Whether another sender is in the player's party.
  # @param admin [Boolean] Whether an admin said it through the relay.
  # @param to [String, nil] Whom the player whispered it to.
  # @param id [String, nil] Another sender's player id, for their menu.
  def self.add(sender, name, text, channel, member = false, admin = false, to = nil, id = nil)
    who = sender == :me ? :me : admin ? :admin : (member ? :member : :other)
    @whisper_tab = true if channel == :whisper
    push(Line.new(name.to_s, text, who, channel, 0, to, id))
    @bubbles[sender] = [text, BUBBLE_FRAMES, channel] unless sender.nil?
    @unread[channel] = true if sender != :me && UNREAD_CHATS.include?(channel) && @tab != channel && @tab != :all
  end

  # Adds a line of the game's own to the log, such as a player leaving a battle, which shows in
  # battles too, where the world's status line does not.
  #
  # @param text [String] The line.
  def self.system(text)
    log("game line: #{MGQ_MpLog.short(text)}")
    push(Line.new(nil, text, :system, nil))
  end

  # Adds a line to the log, forgetting the oldest beyond KEPT.
  #
  # @param line [Line] The line.
  def self.push(line)
    line.left = LOG_FRAMES
    @log.push(line)
    @log.shift while @log.size > KEPT
  end

  # Lets log lines and bubbles run out. Called every frame.
  def self.count_down
    @log.each { |line| line.left -= 1 if line.left > 0 }
    @bubbles.each_value { |bubble| bubble[1] -= 1 }
    @bubbles.reject! { |_, bubble| bubble[1] <= 0 }
  end

  # Forgets the log and the bubbles and closes the box, as when the world closes. The Whisper tab
  # goes too, and the next world starts in the global chat again.
  def self.reset
    stop_typing("no world is open")
    log("forgot #{@log.size} chat lines as the world closed (#{@sent} sent, #{@received} received)") unless @log.empty?
    @log.clear
    @bubbles.clear
    @unread.clear
    @history.clear
    @whisper_to = nil
    @whisper_id = nil
    @reply_to = nil
    @whisper_tab = false
    @channel = :global
    @tab = :all if @tab == :whisper
    @sent = 0
    @received = 0
  end

  # Lists the log's lines its tab shows: all kept while the chat box is open, else the recent ones
  # and the recent whispers, which the closed log shows whatever the tab; the help tab's own.
  #
  # @return [Array<Line>] The lines, oldest first.
  def self.log_entries
    return HELP_LINES if @tab == :help
    return @log.select { |line| line.shown_in?(@tab) } if typing?

    @log.select { |line| line.left > 0 && (line.shown_in?(@tab) || line.channel == :whisper) }
  end

  # Writes the log's lines to show as text.
  #
  # @return [Array<String>] The lines, oldest first.
  def self.log_lines
    log_entries.map(&:to_s)
  end

  # Tells what a sender's bubble says.
  #
  # @param sender [Integer, Symbol] The sender's seat, :me for the player.
  # @return [String, nil] The line, nil for no bubble.
  def self.bubble(sender)
    @bubbles[sender] && @bubbles[sender][0]
  end

  # Tells the chat of a sender's bubble, which colors it.
  #
  # @param sender [Integer, Symbol] The sender's seat, :me for the player.
  # @return [Symbol, nil] One of CHANNELS, nil for no bubble.
  def self.bubble_channel(sender)
    @bubbles[sender] && @bubbles[sender][2]
  end

  # Lists who has a bubble now.
  #
  # @return [Array<Integer, Symbol>] Their seats, :me for the player.
  def self.senders
    @bubbles.keys
  end

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "chat"

  # Tells every other game of the world something, through overworld_sync.rbx.
  #
  # @param fields [Hash] The message's fields, which must leave out MGQ_MpOverworldSync::STATE_FIELD,
  #   since that marks a state.
  # @return [Boolean] Whether it went out.
  def self.tell(fields)
    MGQ_MpOverworldSync.tell(-1, fields)
  end

  # Counts the frame, which ends what suggestions and menu_options keep, lets bubbles and chat lines
  # run out, closes the chat box once neither the map nor a battle shows, and forgets the chat once
  # no world is open. Called by overworld_sync.rbx every frame in every scene.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    @frame += 1
    scene = SceneManager.scene
    stop_typing("#{scene.class.name} shows, neither the map nor a battle") unless in_world && (scene.is_a?(Scene_Map) || scene.is_a?(Scene_Battle))
    see_tab
    in_world ? count_down : reset
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

  # Opens the chat box with its key, and types into it while it is open. Called by the map every
  # frame, so a press of the key is seen once.
  def self.on_map
    @map_ran = true
    chat_key = MGQ_MpHotkeys.pressed?(:chat)
    return stop_typing("no world is open") unless MGQ_MpOverworldSync.in_world?

    # A box already open stays, so a story that starts meanwhile never throws the line away; the
    # box holds the buttons, so the story's messages wait for it, and on_message takes the typing.
    if typing?
      update_typing
    elsif chat_key && available? && !MGQ_MpActions::Wheel.open? && map_open?
      Sound.play_ok
      start_typing(MGQ_MpHotkeys.code(:chat))
    elsif chat_key
      log("chat box stays shut: #{!available? ? 'the keyboard cannot reach the game' : MGQ_MpActions::Wheel.open? ? 'the action wheel is open' : 'an event runs on the map'}")
    end
  rescue => e
    log("chat failed: #{e.class}: #{e.message}")
    stop_typing("it failed")
  end

  # Notes that the map's update starts, in which on_map has not run yet. Called by the map every
  # frame.
  def self.map_updating
    @map_ran = false
  end

  # Opens the chat box and types into it while the map shows a message, which stops the map's own
  # update that on_map follows. The box holds the buttons, so the message waits for it. Called by
  # the map every frame.
  #
  # @param scene [Scene_Map] The map.
  def self.on_message(scene)
    # A message that starts during the map's own update comes after on_map ran in that update.
    on_map unless @map_ran || scene.scene_change_ok?
  rescue => e
    log("chat failed: #{e.class}: #{e.message}")
    stop_typing("it failed")
  end

  # Opens the chat box with its key in a battle of a world, and types into it while it is open.
  # Called by the battle every frame, its waits included, so the player chats while the battle plays on.
  def self.on_battle
    chat_key = MGQ_MpHotkeys.pressed?(:chat)
    return stop_typing("no world is open") unless MGQ_MpOverworldSync.in_world?

    if typing?
      update_typing
    elsif chat_key && available?
      Sound.play_ok
      start_typing(MGQ_MpHotkeys.code(:chat))
    elsif chat_key
      log("chat box stays shut: the keyboard cannot reach the game")
    end
  rescue => e
    log("battle chat failed: #{e.class}: #{e.message}")
    stop_typing("it failed")
  end
end

# A chat bubble above a player's head: their last chat line, cut after three lines, in its chat's color.
class Sprite_MpChatBubble < Sprite
  # Widest the bubble gets.
  WIDTH = 240

  # Height of one line.
  LINE = 20

  # Lines the bubble shows at most.
  MAX_LINES = 3

  # Room between the text and the bubble's edge.
  PAD = 6

  # Pixels above a ghost's feet that its bubble points at: just over its name.
  GHOST_LIFT = 68

  # Pixels above the player's feet that their bubble points at: just over their ping.
  OWN_LIFT = 64

  # Pixels a bubble goes higher while a line, such as an invite, shows above the name or the ping.
  LINE_LIFT = 24

  # Height of the tail below the bubble.
  TAIL = 5

  # The bubble's fill for a chat without a color of its own; the chats fill it with theirs.
  FILL = Color.new(255, 255, 255)

  # The bubble's edge.
  EDGE = Color.new(40, 40, 40)

  # How opaque the bubble is, 85 %, so the map shows through slightly.
  OPACITY = 217

  # The text's color.
  INK = Color.new(20, 20, 20)

  # Creates the bubble, hidden.
  #
  # @param viewport [Viewport] The map's viewport of characters.
  def initialize(viewport)
    super(viewport)
    self.bitmap = Bitmap.new(WIDTH, LINE * MAX_LINES + PAD * 2 + TAIL)
    self.ox = WIDTH / 2
    self.oy = bitmap.height
    self.z = MGQ_MpUi::Z[:bubbles]
    self.opacity = OPACITY
    self.visible = false
    @shown = nil
  end

  # Draws the bubble, if its line changed, with its tail at a point above a character.
  #
  # @param text [String, nil] The line, nil to hide the bubble.
  # @param channel [Symbol, nil] Its chat, which colors it.
  # @param x [Integer] Where the tail points, across the screen.
  # @param y [Integer] Where the tail points, down the screen.
  def show(text, channel, x, y)
    self.visible = !text.nil?
    return unless visible

    self.x = x
    self.y = y
    return if [text, channel] == @shown

    @shown = [text, channel]
    draw(text, Sprite_MpChatLog::CHANNEL_COLORS.fetch(channel, FILL))
  end

  # Draws the bubble around a line, bottom-aligned so the tail stays put.
  #
  # @param text [String] The line.
  # @param fill [Color] The bubble's fill.
  def draw(text, fill)
    bitmap.clear
    # The bubble's dark ink on its light fill takes no outline, unlike the style's texts.
    bitmap.font.size = MGQ_MpUi::Style::SMALL_SIZE
    bitmap.font.outline = false
    bitmap.font.color = INK
    lines = MGQ_MpUi.wrap(bitmap, text, WIDTH - PAD * 2)
    lines = lines[0, MAX_LINES - 1] + ["#{lines[MAX_LINES - 1]} . . ."] if lines.size > MAX_LINES
    width = [lines.map { |line| bitmap.text_size(line).width }.max + PAD * 2, 24].max
    width = [width, WIDTH].min
    height = lines.size * LINE + PAD * 2
    left = (WIDTH - width) / 2
    top = bitmap.height - TAIL - height

    bitmap.fill_rect(left, top, width, height, EDGE)
    bitmap.fill_rect(left + 1, top + 1, width - 2, height - 2, fill)
    TAIL.times { |row| bitmap.fill_rect(WIDTH / 2 - (TAIL - row), top + height - 1 + row, (TAIL - row) * 2, 1, row == 0 ? fill : EDGE) }
    lines.each_with_index { |line, row| bitmap.draw_text(left + PAD, top + PAD + row * LINE, width - PAD * 2, LINE, line, 1) }
  end

  # Frees the bubble's picture.
  def dispose
    bitmap.dispose
    super
  end
end

# The chat log, at the bottom left above the world's status line until the player moves it through
# the layout, with its tabs above it and the chat box below it while the player types. It lies on a
# viewport of its own, which comes above everything while the player types.
class Sprite_MpChatLog < Sprite
  # Height of one row.
  ROW = 19

  # Height of the tabs' row.
  TAB_ROW = 18

  # Room left and right of a tab's name.
  TAB_PAD = 6

  # Narrowest the log gets: the tabs with the help tab need 306 pixels, and the widest hint,
  # HELP_HINT in the tiny font after the help tab's label, 392.
  MIN_WIDTH = 400

  # Fewest rows of lines the log keeps: as many as the list of fitting names, which lies on the rows
  # above the chat box.
  MIN_ROWS = MGQ_MpChat::SUGGESTIONS

  # Lowest the log gets: the tabs, MIN_ROWS rows and the chat box's row.
  MIN_HEIGHT = TAB_ROW + ROW * (MIN_ROWS + 1)

  # The log's boxes in the layout, by their id: the map's and the battle's, each placed on its own.
  BOXES = { :chat => "Chat", :battle_chat => "Battle chat" }

  # Room between the screen's edges and the log at its default place: on the left, and on the right
  # at its widest.
  SCREEN_MARGIN = 8

  # Room the world's status line keeps at the bottom of the screen.
  STATUS_ROOM = 96

  # Room a battle's command and status windows keep at the bottom of the screen.
  BATTLE_ROOM = 200

  # Colors of the senders' names, the style's: the player's own, a member of the player's party as
  # their label on the map, an admin's gold as the featured worlds, and the game's own lines dim.
  # Anyone else's is plain text, see name_color.
  NAME_COLORS = { :me => MGQ_MpUi::Style::OWN, :member => MGQ_MpUi::Style::MEMBER, :admin => MGQ_MpUi::Style::GOLD, :system => MGQ_MpUi::Style::DIM }

  # Colors of the chats, for their tags, their tabs, the chat box's name of them and their bubbles,
  # the ones World of Warcraft gives its chats: the global chat plain white as its say chat, the map
  # chat its zone pink, the party chat its party blue and whispers its whisper pink.
  CHANNEL_COLORS = { :global => MGQ_MpUi::Style::TEXT, :map => Color.new(255, 192, 192), :party => Color.new(170, 170, 255), :whisper => Color.new(255, 128, 255) }

  # The chats whose text is in their color too, not only their tag.
  COLORED_TEXT = [:map, :whisper]

  # Background of a tab, the preset's. The picked one is filled with its chat's color instead, under
  # TAB_INK.
  TAB_BACK = MGQ_MpUi::Style::TAB

  # The yellow a tab with unread lines glows in at its top right corner, red, green and blue, over
  # TAB_BACK. It grows from the tab's opacity to fully opaque toward the corner, since at the tab's
  # own it barely stood out.
  UNREAD_GLOW = [255, 220, 60]

  # How far from the top right corner the glow reaches, in pixels.
  UNREAD_REACH = 28

  # Color of the picked tab's name, dark on its chat's color.
  TAB_INK = Color.new(20, 20, 20)

  # Shade over the tabs while the chat box is closed, which dims them under the unread glow.
  CLOSED_SHADE = MGQ_MpUi::Style::PLATE

  # Room left of the rows' and the chat box's text.
  TEXT_LEFT = 4

  # What the chat box says while it is empty.
  BOX_HINT = "↑↓: scroll   Alt: more   /help: help"

  # What the empty chat box says while Alt is held.
  ALT_HINT = "←→: tab   ↑↓: sent   Drag: move, resize"

  # What the chat box says on the help tab, where nobody types.
  HELP_HINT = "Pick another tab to chat. #{MGQ_MpUi::Style.close_hint}"

  # What a player's menu says below its choices.
  MENU_HINT = MGQ_MpUi::Style.close_hint

  # Room at the right of the rows for the arrows that show the log scrolls on.
  ARROW_ROOM = 14

  # Color of the thin outline of the tabs and of the open chat, the preset's.
  OUTLINE = MGQ_MpUi::Style::EDGE

  # Color of the open chat's outline while Alt is held, which shows that a drag moves or resizes it.
  RESIZE_OUTLINE = MGQ_MpUi::Style::TEXT

  # Lines whose rows the log remembers before it forgets them all, since each new line breaks once.
  WRAP_CACHE = 200

  # Creates the log, empty, on a viewport of its own.
  #
  # @param layout_id [Symbol] Its box in the layout, one of BOXES.
  # @param bottom_room [Integer] Room its default place keeps free below it: STATUS_ROOM on the map,
  #   BATTLE_ROOM in battle.
  # @param resting_z [Integer] Its viewport's depth while the player does not type.
  def initialize(layout_id, bottom_room, resting_z)
    super(Viewport.new.tap { |viewport| viewport.z = resting_z })
    @layout_id = layout_id
    @bottom_room = bottom_room
    @resting_z = resting_z
    @shown = nil
    @wrapped = {}
    @tab_spots = []
    @name_spots = []
    @menu_sprite = Sprite.new(viewport)
    @menu_sprite.z = 1
  end

  # Draws the log and the chat box where the layout places them, if they changed: the rows the log
  # is scrolled to, with an arrow at the top while older rows lie above and one at the bottom while
  # newer ones lie below, a line of the closed log fading away over its last frames. Above the
  # closed log the tabs show dimmed while one holds unread lines, so its glow is seen. While it
  # shows anything, it offers its place to the layout.
  def update
    super
    chat = MGQ_MpChat
    place(chat)
    follow_mouse(chat) if chat.typing?
    # Read after the mouse, whose click on a menu's choice may close the chat box.
    typing = chat.typing?
    depth = typing ? MGQ_MpUi::Z[:typing] : @resting_z
    viewport.z = depth unless viewport.z == depth
    draw_menu(chat)

    entries = MGQ_MpOverworldSync.in_world? ? chat.log_entries : []
    keep_place(chat, entries)
    lines = entries.last(@rows + chat.scroll)
    rows = lines.map { |line| rows_of(line).each_with_index.map { |row, index| [row, line, index == 0] } }.flatten(1)
    scroll = chat.limit_scroll(lines.size < entries.size ? chat.scroll : [rows.size - @rows, 0].max)
    shown = rows[0, rows.size - scroll].last(@rows)
    older = lines.size < entries.size || rows.size - scroll > @rows
    alt = typing && MGQ_Multiplayer::Key.down?(MGQ_MpChat::ALT_KEY)
    # A line of the closed log fades over its last frames, so those count as a change.
    fades = shown.map { |_row, line, _first| typing ? nil : [line.left, MGQ_MpUi::Style::FADE_FRAMES].min }
    offer_place if typing || !shown.empty? || !chat.unread_tabs.empty?
    drawn = [shown.map { |row, line, first| [row, line.who, line.channel, first] }, fades, older, scroll, chat.typed, chat.cursor,
             typing && chat.cursor_shown?, chat.tab, chat.channel, chat.whisper_to, chat.suggestions, chat.pick, alt, @size, chat.unread_tabs, chat.tabs,
             MGQ_MpUi::Theme.serial]
    return if drawn == @shown

    @shown = drawn
    bitmap.clear
    if typing
      bitmap.fill_rect(0, TAB_ROW, @width, bitmap.height - TAB_ROW, MGQ_MpUi::Style::BACK)
      draw_tabs(chat)
    elsif !chat.unread_tabs.empty?
      draw_tabs(chat, true)
    end
    @name_spots = []
    shown.each_with_index { |(row, line, first), index| draw_row(row, line, first, TAB_ROW + (@rows - shown.size + index) * ROW, fades[index]) }
    draw_arrow(TAB_ROW, true) if typing && older
    draw_arrow(TAB_ROW + (@rows - 1) * ROW, false) if typing && scroll > 0
    draw_box(chat, alt) if typing
    draw_chat_frame(alt ? RESIZE_OUTLINE : OUTLINE) if typing
    draw_names(chat) if typing
  end

  # Places the log where the layout says, its picture as wide as the place and as high as the
  # whole rows that fit it, standing on the place's bottom.
  #
  # @param chat [Module] MGQ_MpChat.
  def place(chat)
    rect = MGQ_MpUi::Layout.rect(@layout_id, default_rect(chat))
    rows = [rows_in(rect.height), MIN_ROWS].max
    rebuild(rect.width, rows) unless [rect.width, rows] == @size
    left = rect.x
    top = rect.y + rect.height - bitmap.height
    self.x = left unless x == left
    self.y = top unless y == top
  end

  # Tells where the log lies until the player moves it: at the screen's left, standing on the room
  # kept below it, at the chat's size within the screen.
  #
  # The rows stop above the room kept below, so a battle's smaller room draws fewer of them.
  #
  # @param chat [Module] MGQ_MpChat.
  # @return [Rect] The place.
  def default_rect(chat)
    width, rows = chat.size
    most_rows = [rows_in(Graphics.height - @bottom_room), MIN_ROWS].max
    width = MGQ_MpUi.within(width, MIN_WIDTH, [Graphics.width - SCREEN_MARGIN * 2, MIN_WIDTH].max)
    height = height_of(MGQ_MpUi.within(rows, MIN_ROWS, most_rows))
    Rect.new(SCREEN_MARGIN, Graphics.height - @bottom_room - height, width, height)
  end

  # Tells how many rows of lines fit a height below the tabs and above the chat box.
  #
  # @param height [Integer] The height.
  # @return [Integer] The rows.
  def rows_in(height)
    (height - TAB_ROW) / ROW - 1
  end

  # Tells how high the log is with a number of rows of lines.
  #
  # @param rows [Integer] The rows.
  # @return [Integer] Its height: the tabs, the rows and the chat box's row.
  def height_of(rows)
    TAB_ROW + ROW * (rows + 1)
  end

  # Makes the log's picture anew at a size.
  #
  # @param width [Integer] Its width.
  # @param rows [Integer] Its rows of lines.
  def rebuild(width, rows)
    @size = [width, rows]
    @width, @rows = width, rows
    bitmap.dispose if bitmap
    self.bitmap = Bitmap.new(width, height_of(rows))
    MGQ_MpUi::Style.use_font(bitmap, MGQ_MpUi::Style::SMALL_SIZE, MGQ_MpUi::Style::TEXT)
    @shown = nil
    @wrapped.clear
  end

  # Tells the layout where the log shows, so Alt and the mouse move and resize it.
  def offer_place
    MGQ_MpUi::Layout.offer(@layout_id, x, y, bitmap.width, bitmap.height, viewport.z)
  end

  # Follows the mouse while the chat box is open: a click on another player's name opens their
  # menu, a click on a tab picks it.
  #
  # @param chat [Module] MGQ_MpChat.
  def follow_mouse(chat)
    mouse = MGQ_Multiplayer::Mouse
    held = mouse.held?
    went_down = held && !@held
    @held = held
    position = mouse.position
    return follow_menu(chat, position, went_down) if chat.menu
    return unless went_down && position && inside?(position)

    name = @name_spots.find { |_, left, right, top| position[0] >= x + left && position[0] < x + right && position[1] >= y + top && position[1] < y + top + ROW }
    return chat.open_menu(name[0], [x + name[1], y + name[3]]) if name

    spot = @tab_spots.find { |_, left, width| position[1] < y + TAB_ROW && position[0] >= x + left && position[0] < x + left + width }
    chat.select_tab(spot[0], "with the mouse") if spot
  end

  # Follows the mouse while a player's menu is open: pointing picks a choice, a click takes it, and
  # a click outside the menu closes it.
  #
  # @param chat [Module] MGQ_MpChat.
  # @param position [Array<Integer>, nil] Where the mouse points, nil outside the window.
  # @param went_down [Boolean] Whether the left button went down this frame.
  def follow_menu(chat, position, went_down)
    index = position && menu_choice_at(position)
    chat.point_menu(index) if index && position != @menu_pointed
    @menu_pointed = position
    return unless went_down

    index ? chat.take_menu(index) : chat.close_menu("a click outside it")
  end

  # Finds the choice of the open menu at a point of the screen.
  #
  # @param position [Array<Integer>] x and y.
  # @return [Integer, nil] Its place among the menu's choices, nil outside them.
  def menu_choice_at(position)
    sprite = @menu_sprite
    return nil unless sprite.visible && sprite.bitmap

    left = position[0] - sprite.x
    row = (position[1] - sprite.y) / ROW - 1
    left >= 0 && left < sprite.bitmap.width && position[1] >= sprite.y && row >= 0 && row < @menu_choices ? row : nil
  end

  # Draws the menu of the player whose name was clicked in a box of the preset, if it changed: their
  # name as its title, bold on a strip of its own, then the choices, refused ones grey, the picked
  # one lighter, and how to close it. It opens above the name, kept on the screen.
  #
  # @param chat [Module] MGQ_MpChat.
  def draw_menu(chat)
    menu = chat.typing? ? chat.menu : nil
    options = menu ? chat.menu_options : []
    shown = menu && !options.empty? ? [menu[:name], options.map { |option| [option.text, !option.run.nil?] }, menu[:pick], menu[:at], MGQ_MpUi::Theme.serial] : nil
    return if shown == @menu_shown

    @menu_shown = shown
    @menu_sprite.visible = !shown.nil?
    return unless shown

    measure = bitmap
    measure.font.bold = true
    title = measure.text_size(menu[:name]).width
    measure.font.bold = false
    width = ([title, measure.text_size(MENU_HINT).width] + options.map { |option| measure.text_size(option.text).width }).max + TAB_PAD * 2
    @menu_choices = options.size
    @menu_sprite.bitmap.dispose if @menu_sprite.bitmap
    picture = @menu_sprite.bitmap = Bitmap.new(width, ROW * (options.size + 2))
    style = MGQ_MpUi::Style
    style.use_font(picture, style::SMALL_SIZE, style::TEXT)
    style.draw_box(picture, 0, 0, width, picture.height)
    inner = style.frame_width
    picture.fill_rect(inner, inner, width - inner * 2, ROW - inner, style::PICKED)
    picture.fill_rect(inner, ROW - 1, width - inner * 2, 1, style::DIM)
    picture.font.bold = true
    picture.draw_text(TAB_PAD, 0, width - TAB_PAD * 2, ROW, menu[:name])
    picture.font.bold = false
    options.each_with_index do |option, index|
      top = ROW * (index + 1)
      picture.fill_rect(inner, top, width - inner * 2, ROW, style::PICKED) if index == menu[:pick]
      picture.font.color = option.run ? style::TEXT : style::DIM
      picture.draw_text(TAB_PAD, top, width - TAB_PAD * 2, ROW, option.text)
    end
    picture.font.color = style::DIM
    picture.draw_text(TAB_PAD, ROW * (options.size + 1), width - TAB_PAD * 2, ROW, MENU_HINT)
    @menu_sprite.x = [[menu[:at][0], Graphics.width - width].min, 0].max
    @menu_sprite.y = [menu[:at][1] - picture.height, 0].max
  end

  # Reports whether a point of the screen lies on the log.
  #
  # @param position [Array<Integer>] x and y.
  # @return [Boolean] Whether it does.
  def inside?(position)
    return false unless bitmap

    position[0] >= x && position[0] < x + bitmap.width && position[1] >= y && position[1] < y + bitmap.height
  end

  # Breaks a line of the log into rows, once for each text.
  #
  # @param line [MGQ_MpChat::Line] The line.
  # @return [Array<String>] Its rows.
  def rows_of(line)
    @wrapped.clear if @wrapped.size > WRAP_CACHE
    @wrapped[line.to_s] ||= MGQ_MpUi.wrap(bitmap, line.to_s, @width - 8 - ARROW_ROOM)
  end

  # Keeps the rows shown where they are while lines come in with the log scrolled up, scrolling up
  # by the rows of the lines that came.
  #
  # @param chat [Module] MGQ_MpChat.
  # @param entries [Array<MGQ_MpChat::Line>] The log's lines to show, oldest first.
  def keep_place(chat, entries)
    newest = entries.last
    if chat.scroll > 0 && @newest && !newest.equal?(@newest)
      at = entries.rindex { |line| line.equal?(@newest) }
      came = at ? entries[at + 1..-1] : []
      chat.scroll_by(came.inject(0) { |sum, line| sum + rows_of(line).size })
    end
    @newest = newest
  end

  # Draws the tabs at the top, each name in its chat's color, the picked one filled with that color
  # under dark text and open into the chat below, the help tab at the far right, and keeps where
  # each lies for the mouse. Dimmed, each tab lies under CLOSED_SHADE, closed at the bottom, with
  # its glow over the shade.
  #
  # @param chat [Module] MGQ_MpChat.
  # @param dim [Boolean] Whether the tabs show dimmed above the closed log.
  def draw_tabs(chat, dim = false)
    @tab_spots = []
    @picked_gap = nil
    left = 0
    chat.tabs.each do |tab|
      name = MGQ_MpChat::TAB_NAMES[tab]
      width = bitmap.text_size(name).width + TAB_PAD * 2
      at = tab == :help ? @width - width : left
      color = CHANNEL_COLORS.fetch(tab, MGQ_MpUi::Style::TEXT)
      picked = tab == chat.tab
      unread = !picked && chat.unread_tabs.include?(tab)
      bitmap.fill_rect(at, 0, width, TAB_ROW, picked ? color : TAB_BACK)
      # The glow lies under the name, which it would blot out at the corner, except dimmed, where
      # the shade would dim it away, so it goes over the shade instead.
      draw_unread_glow(at + width) if unread && !dim
      # The outline would smear dark text on a light tab.
      bitmap.font.outline = !picked
      draw_part(at + TAB_PAD, 0, name, picked ? TAB_INK : color, TAB_ROW)
      bitmap.font.outline = true
      draw_tab_frame(at, width, !picked || dim)
      if dim
        bitmap.fill_rect(at, 0, width, TAB_ROW, CLOSED_SHADE)
        draw_unread_glow(at + width) if unread
      end
      @picked_gap = [at, width] if picked
      @tab_spots.push([tab, at, width])
      left += width + 2
    end
  end

  # Lets a tab glow yellow at its top right corner, fading toward its middle, for lines the player
  # has not seen yet.
  #
  # @param right [Integer] The tab's right edge.
  def draw_unread_glow(right)
    base = TAB_BACK.alpha.to_i
    UNREAD_REACH.times do |down|
      break if down >= TAB_ROW

      UNREAD_REACH.times do |left|
        strength = 1.0 - Math.sqrt(down * down + left * left) / UNREAD_REACH
        next if strength <= 0

        red, green, blue = UNREAD_GLOW.map { |part| (part * strength).round }
        alpha = (base + (255 - base) * strength).round
        bitmap.fill_rect(right - 1 - left, down, 1, 1, Color.new(red, green, blue, alpha))
      end
    end
  end

  # Draws a small arrow at the right of a row: up for older rows above, down for newer ones below.
  #
  # @param y [Integer] The row's top.
  # @param up [Boolean] Whether it points up.
  def draw_arrow(y, up)
    left = @width - ARROW_ROOM + 2
    5.times do |step|
      width = up ? step * 2 + 1 : (4 - step) * 2 + 1
      bitmap.fill_rect(left + 4 - width / 2, y + ROW / 2 - 2 + step, width, 1, MGQ_MpUi::Style::DIM)
    end
  end

  # Draws a tab's frame in the preset's colors, closed at the bottom or open into the chat below.
  #
  # @param left [Integer] The tab's left.
  # @param width [Integer] The tab's width.
  # @param closed [Boolean] Whether its bottom is drawn, which the picked tab of the open chat
  #   leaves out.
  def draw_tab_frame(left, width, closed)
    style = MGQ_MpUi::Style
    # An open tab's frame reaches down onto the chat's top edge, which draw_chat_frame opens under it.
    height = closed ? TAB_ROW : TAB_ROW + style.frame_width
    style.draw_frame(bitmap, left, 0, width, height, OUTLINE)
  end

  # Draws the open chat's frame below the tabs in the preset's colors, open under the picked tab,
  # whose inside meets the chat's.
  #
  # @param edge [Color] The edge's color: OUTLINE, RESIZE_OUTLINE while Alt is held.
  def draw_chat_frame(edge)
    style = MGQ_MpUi::Style
    style.draw_frame(bitmap, 0, TAB_ROW, @width, bitmap.height - TAB_ROW, edge)
    return unless @picked_gap

    inner = style.frame_width
    left, width = @picked_gap
    bitmap.fill_rect(left + inner, TAB_ROW, width - inner * 2, inner, style::BACK)
  end

  # Draws one row of the log; a line's first row with its head in the sender's colors, keeping where
  # another player's name lies for a click. The text of the chats in COLORED_TEXT is in their color.
  #
  # @param row [String] The row's text.
  # @param line [MGQ_MpChat::Line] The line the row belongs to.
  # @param first [Boolean] Whether it is the line's first row, which starts with its head.
  # @param y [Integer] The row's top.
  # @param left [Integer, nil] Frames the line has left in the closed log, which fade its colors
  #   over the last of them; nil for the open log, where nothing fades.
  def draw_row(row, line, first, y, left = nil)
    style = MGQ_MpUi::Style
    x = TEXT_LEFT
    # A line broken right after the name loses the space after it to the break.
    head = row.start_with?(line.head) ? line.head : line.head.rstrip
    if first && row.start_with?(head)
      tag = line.tag
      x = draw_part(x, y, tag, line.who == :admin ? NAME_COLORS[:admin] : CHANNEL_COLORS[line.channel], ROW, left) unless tag.empty?
      start = x
      x = draw_part(x, y, head[tag.size..-1], name_color(line), ROW, left)
      @name_spots.push([line, start, x, y]) if line.id
      row = row[head.size..-1]
    end
    draw_part(x, y, row, COLORED_TEXT.include?(line.channel) ? CHANNEL_COLORS[line.channel] : style::TEXT, ROW, left)
  end

  # Picks the color of a line's sender's name: NAME_COLORS by whose it is, plain text for anyone
  # else, as MGQ_MpUi::PlayerColor names a player outside the party.
  #
  # @param line [MGQ_MpChat::Line] The line.
  # @return [Color] The color.
  def name_color(line)
    NAME_COLORS.fetch(line.who, MGQ_MpUi::Style::TEXT)
  end

  # Draws a part of a row in a color.
  #
  # @param x [Integer] Where it starts.
  # @param y [Integer] The row's top.
  # @param text [String] The part.
  # @param color [Color] Its color.
  # @param height [Integer] The row's height.
  # @param left [Integer, nil] Frames the part's line has left, which fade the color over the last
  #   of them; nil for no fade.
  # @return [Integer] Where the next part starts.
  def draw_part(x, y, text, color, height = ROW, left = nil)
    width = bitmap.text_size(text).width
    bitmap.font.color = left ? MGQ_MpUi::Style.faded(color, left) : color
    bitmap.draw_text(x, y, width + 2, height, text)
    bitmap.font.color = MGQ_MpUi::Style::TEXT
    x + width
  end

  # Draws the chat box on the bottom row: the chosen chat's name, or whom the player whispers to,
  # then the text around the cursor and the cursor, with a hint behind them while the text is
  # empty, the Alt controls while Alt is held. The help tab shows only its name and its hint, since
  # nobody types there.
  #
  # @param chat [Module] MGQ_MpChat.
  # @param alt [Boolean] Whether Alt is held.
  def draw_box(chat, alt)
    style = MGQ_MpUi::Style
    y = TAB_ROW + @rows * ROW
    bitmap.fill_rect(0, y, @width, ROW, style::BACK)
    help = chat.tab == :help
    channel = chat.channel
    label = help ? "Help:" : channel == :whisper && chat.whisper_to ? "To #{chat.whisper_to}:" : "#{MGQ_MpChat::TAB_NAMES[channel]}:"
    @box_left = draw_part(TEXT_LEFT, y, label, help ? style::TEXT : CHANNEL_COLORS.fetch(channel, style::TEXT)) + 4
    editor = chat.editor

    draw_hint(help ? HELP_HINT : alt ? ALT_HINT : BOX_HINT, y) if editor.text.empty?

    MGQ_MpUi::TextBox.draw_line(bitmap, Rect.new(@box_left, y, @width - @box_left - TEXT_LEFT, ROW), editor) unless help
  end

  # Draws a hint of the empty chat box behind the cursor, dim, in the tiny font while it is wider
  # than the room left of the box's right edge.
  #
  # @param hint [String] The hint.
  # @param y [Integer] The chat box's top.
  def draw_hint(hint, y)
    style = MGQ_MpUi::Style
    left = @box_left + MGQ_MpUi::TextBox::CURSOR_WIDTH + 2
    room = @width - left - TEXT_LEFT
    bitmap.font.size = style::TINY_SIZE if bitmap.text_size(hint).width > room
    bitmap.font.color = style::DIM
    bitmap.draw_text(left, y, room, ROW, hint)
    bitmap.font.color = style::TEXT
    bitmap.font.size = style::SMALL_SIZE
  end

  # Draws the list of the names that fit the whisper command above the chat box, where the name
  # starts, the picked one lighter.
  #
  # @param chat [Module] MGQ_MpChat.
  def draw_names(chat)
    names = chat.suggestions
    return if names.empty?

    width = names.map { |name| bitmap.text_size(name).width }.max + TAB_PAD * 2
    command = chat.typed[/\A\S+ +/].to_s
    left = [[@box_left + bitmap.text_size(command).width - TAB_PAD, @width - width].min, 0].max
    top = TAB_ROW + (@rows - names.size) * ROW
    names.each_with_index do |name, index|
      y = top + index * ROW
      bitmap.fill_rect(left, y, width, ROW, MGQ_MpUi::Style::BACK)
      bitmap.fill_rect(left, y, width, ROW, MGQ_MpUi::Style::PICKED) if index == chat.pick
      draw_part(left + TAB_PAD, y, name, CHANNEL_COLORS[:whisper])
    end
  end

  # Frees the log's picture, its menu's and its viewport.
  def dispose
    @menu_sprite.bitmap.dispose if @menu_sprite.bitmap
    @menu_sprite.dispose
    bitmap.dispose if bitmap
    own = viewport
    super
    own.dispose
  end
end

# The chat log's boxes, which Alt and the mouse move and resize, through ui_layout.rbx.

begin
  Sprite_MpChatLog::BOXES.each do |id, name|
    MGQ_MpUi::Layout.register(id, name, Sprite_MpChatLog::MIN_WIDTH, Sprite_MpChatLog::MIN_HEIGHT, :both)
  end
rescue => e
  MGQ_MpChat.log("layout FAILED: #{e.class}: #{e.message}")
end

# What this script takes part in of the world's messages, through overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.route("chat") { |peer, message| MGQ_MpChat.receive(peer, message) }
  MGQ_MpOverworldSync.route("whisper") { |peer, message| MGQ_MpChat.receive_whisper(peer, message) }
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpChat.tick(in_world) }
  MGQ_MpOverworldSync.busy_scene { MGQ_MpChat.scene }
rescue => e
  MGQ_MpChat.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

# What the chat adds to the action wheel, through ui_actions.rbx.

begin
  MGQ_MpActions.wheel_choice(50) { MGQ_MpChat.wheel_option }
  MGQ_MpActions.cover { |_wheel_key| MGQ_MpChat.typing? }
rescue => e
  MGQ_MpChat.log("action wheel FAILED: #{e.class}: #{e.message}")
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # After the map's update, the chat box. The game checks its own keys there too, only while no
  # scene change is in the way.
  MGQ_MpHooks.after(Scene_Map, :update_scene, "ui_chat") { MGQ_MpChat.on_map unless scene_changing? }

  # After the map's sprites, the chat log and a bubble per player with a recent chat line, above
  # them while they are on this map.
  MGQ_MpHooks.after(Spriteset_Map, :update, "ui_chat") do
    # Just under the topmost viewport, whose wheels and World overview lie above the log.
    @mgq_mp_chat_log ||= Sprite_MpChatLog.new(:chat, Sprite_MpChatLog::STATUS_ROOM, @viewport3.z - 1)
    @mgq_mp_chat_log.update
    @mgq_mp_bubbles ||= {}
    chat = MGQ_MpChat
    senders = MGQ_MpOverworldSync.in_world? ? chat.senders : []
    (@mgq_mp_bubbles.keys - senders).each { |sender| @mgq_mp_bubbles.delete(sender).dispose }

    senders.each do |sender|
      bubble = @mgq_mp_bubbles[sender] ||= Sprite_MpChatBubble.new(@viewport1)
      if sender == :me
        character, lift = $game_player, Sprite_MpChatBubble::OWN_LIFT
        lift += Sprite_MpChatBubble::LINE_LIFT if MGQ_MpActions.own_line
        character = nil if MGQ_MpActions::Wheel.open?
      else
        peer = MGQ_MpOverworldSync::Peers.at(sender)
        character, lift = peer && peer.ghost, Sprite_MpChatBubble::GHOST_LIFT
        lift += Sprite_MpChatBubble::LINE_LIFT if peer && MGQ_MpOverworldSync.label_line_of(peer)
      end

      shown = character && !character.transparent
      bubble.show(shown ? chat.bubble(sender) : nil, chat.bubble_channel(sender), shown ? character.screen_x : 0, shown ? character.screen_y - lift : 0)
    end
  end

  MGQ_MpHooks.before(Spriteset_Map, :dispose, "ui_chat") do
    @mgq_mp_chat_log.dispose if @mgq_mp_chat_log
    (@mgq_mp_bubbles || {}).each_value { |sprite| sprite.dispose }
    @mgq_mp_chat_log = @mgq_mp_bubbles = nil
  end

  # Around the map's update, the chat box while a message stops the map's own update.
  MGQ_MpHooks.before(Scene_Map, :update, "ui_chat") { MGQ_MpChat.map_updating }
  MGQ_MpHooks.after(Scene_Map, :update, "ui_chat") { MGQ_MpChat.on_message(self) }
rescue => e
  MGQ_MpChat.log("hooks FAILED: #{e.class}: #{e.message}")
end

begin
  # After the battle's basics, the chat box. update_basic runs in the battle's waits too, so the
  # chat box takes typing while the battle plays on.
  MGQ_MpHooks.after(Scene_Battle, :update_basic, "ui_chat") { MGQ_MpChat.on_battle }

  # After the battle's sprites, the chat log above the battle's windows while a world is open.
  MGQ_MpHooks.after(Spriteset_Battle, :update, "ui_chat") do
    if @mgq_mp_chat_log || MGQ_MpOverworldSync.in_world?
      # The battle's windows lie above every viewport of the spriteset, so the log rests above them.
      @mgq_mp_chat_log ||= Sprite_MpChatLog.new(:battle_chat, Sprite_MpChatLog::BATTLE_ROOM, MGQ_MpUi::Z[:wheels])
      @mgq_mp_chat_log.update
    end
  end

  # Before the battle's sprites are freed, the chat log.
  MGQ_MpHooks.before(Spriteset_Battle, :dispose, "ui_chat") do
    @mgq_mp_chat_log.dispose if @mgq_mp_chat_log
    @mgq_mp_chat_log = nil
  end
rescue => e
  MGQ_MpChat.log("battle hooks FAILED: #{e.class}: #{e.message}")
end
