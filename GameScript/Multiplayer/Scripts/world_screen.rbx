#----------------------------------------------------------------
#  world_screen.rbx
#
#  Changelog:
#      Paulinchen  2026-11-11: Started a world with the row the DLL hands with the start step instead of the row picked before its mods were read
#                            - Handed the DLL mods the Mod Framework finds ready at once, which it refuses itself while they still differ
#                            - Dropped the DLL's confirmation step, which no rule asks for
#      Paulinchen  2026-11-09: Gave the details' boxes a little room at their sides
#                            - Wrapped the description to as many lines as its box holds, where it showed one
#                            - Drew a thin box around each part of the details the player can pick, at one height for every world
#                            - Lined the details' captions and values up in fixed columns, each column of captions at its widest caption
#                            - Gave the description four lines beside narrower players and dropped the frames of the details' parts, so none is cut at the bottom
#                            - Opened the World panel into the list box with the world's facts alone, the Game data panel with its mods and game data settings alone
#                            - Put the search and the filters in a box of their own above the worlds, which the cursor in the list no longer reaches
#                            - Cut a world detail too long for its cell with ... and showed its whole text as its tooltip
#                            - Lined the captions of the details up at the widest caption the details can show for any world, so the column never moves
#                            - Lined the narrow captions of a form up at the widest of them
#                            - Kept the screen at a fixed size, its commands always on screen, with the details and the forms fitted into the right box instead of scrolling
#                            - Searched the worlds by name and filtered them by type and players online above the list
#                            - Put the captions of the mods and the save above their buttons so their text shows
#                            - Kept the players and the description at one height and place for every world
#                            - Made the right box itself the preview of a form, so the form fits it
#      Paulinchen  2026-11-08: Handed the DLL the installed mods anew once the Mod Framework made a world's mods ready
#                            - Handed the DLL the installed mods each second while the Mod Framework fetches the website
#                            - Scrolled a form inside the right box instead of letting it grow past the screen
#                            - Gave its UI ids the mgq_online_ prefix
#                            - Showed the details of the world under the cursor once the first worlds arrive
#                            - Moved the focus onto a field of the form only once its last render made the field
#                            - Showed a world's mods in its details as chips that only show
#      Paulinchen  2026-11-07: Left the form back to its list when cancel reaches the screen from a field, and greyed menu choices through disabled:
#      Paulinchen  2026-11-06: Asked again for a release to play whose question could not open while one of the screen's was
#                            - Refused a world whose mods the Mod Framework finds ready while MGQ Online's check finds them differing, instead of asking again
#                            - Moved the focus and said the lines at the top without rescuing an error of the UI layer
#                            - Drew the world screen, its details, forms and formation limits through the UI layer
#                            - Opened a world's players, mods and description and the mod picker in MGQ Online's list box, a mod added by name removed through its context menu
#                            - Asked for the mods a world needs in the Mod Framework's dialog, in place of the download and the list box
#      Paulinchen  2026-11-05: Made a world of the directory through the directory's own reader
#      Paulinchen  2026-11-01: Dropped the form window no screen draws with any more
#                            - Named the Mod Framework's interface by its own name
#                            - Showed a world's players, mods and description and the mod picker in the list box of the Mod Framework's components
#                            - Typed a mod's name into the picker's own Name field
#                            - Showed the lines across the top in the info strip of the Mod Framework's components
#                            - Built the screen on the Mod Framework's components
#                            - Stopped the worlds and the commands on their boxes as a whole first through the framework
#                            - Showed a world's details as plated values, tags and a description that fills its room
#                            - Built the forms from the DLL's view and typed in place, a gamepad through the game's letters
#                            - Opened the formation limits in a dialog over the form
#                            - Asked a world's choices and the DLL's questions in the framework's menu and question box
#                            - Dropped the text screen
#                            - Noted a world started from another player's starting save as the DLL's steps name it
#      Paulinchen  2026-10-31: Typed and cancelled through the Mod Framework, and named the keys that cancel as the player bound them
#      Paulinchen  2026-10-30: Dropped the creator's update of the game data and handing this game's data over, since entering compares it once the world's mods loaded
#                            - Noted the mods of the world's session for the Mod Framework to load as the world's game loads or starts
#                            - Dropped giving up an entry for the parked mods
#                            - Installed a world's mods through the Mod Framework, and started the game again for one that runs already
#      Paulinchen  2026-10-28: Read the list on the screen's first look even when the list bit was taken earlier in the session
#      Paulinchen  2026-10-23: Left the lines of what the DLL decides to its log
#                            - Left a world's favourite, its id copied, its removal from the list and the deletion of its saves to the DLL's steps
#                            - Left the requests of the forms and what they lead to to the DLL's steps
#                            - Played the DLL's steps into a world, its starting save, the restart for its mods, a Discord invite and the entry after a restart
#                            - Took the list, the details, the choices, the list box's lines, the screen's texts and the refresh from the DLL's model of the screen
#                            - Took what entering needs of the parked mods, its texts and the restart for downloaded mods from the DLL's parking
#                            - Took the required-mods check, its summary, the download and the shared settings' marker from the DLL
#                            - Opened the forms the DLL holds and left Enter, the checks and the tidying of a sent form to it
#                            - Opened and closed the mod picker in the DLL
#                            - Typed into the forms and the mod picker through the text box in C#
#                            - Asked the DLL for the default squad rules
#                            - Dropped the restart by hand under Wine or Proton, where the game starts itself again now
#      Paulinchen  2026-10-22: Opened the world the cursor is on, whose mods the list then carries, and read them before entering or editing it
#      Paulinchen  2026-10-14: Named a Raid World's starting save in its details in every build
#      Paulinchen  2026-10-13: Sent a Classic world's raid bosses with the new world and the edits, and showed them in the details
#                            - Sent a Raid World's squad rules with the new world and the edits, and showed them in the details
#                            - Opened a Raid World's squad rules in a form of their own and went back from it
#      Paulinchen  2026-10-12: Asked before taking a world's starting save unless the player created the world
#                            - Scrolled the worlds, the choices, the list box, the mod picker and a description with the mouse wheel
#                            - Drew the scrollbars of the worlds and the choices through the shared list windows
#                            - Opened the text screen of the description with its text broken over several lines
#                            - Said that a world stays as it was when Player.ini could not be read
#      Paulinchen  2026-10-11: Dressed the screen's windows in the interface look
#                            - Broke a description in the list box anew once the player resized the box
#                            - Moved the list box's fade on every frame, and measured a description with the shared style
#                            - Named Numpad 0 in the mod picker's hint, and counted a row's further mods as every box does
#                            - Put the cursor on the world just created or added once the list shows it
#                            - Sent the hidden world's id with Enter
#                            - Held the form's cursor while the action a form sent runs
#                            - Said in the details whether a world's password is known
#      Paulinchen  2026-10-10: Let a development build's Raid World go without a shared save, and named its start in the details
#                            - Forgot to enter the world after a refused or failed data update
#                            - Stayed on the world screen with a notice for a world's downloaded mods while mods stay parked
#                            - Kept the game out of a world that turns off scripts behind a link to another drive
#      Paulinchen  2026-10-09: Asked before entering a world that turns other mods off, then turned them off and restarted to enter it
#                            - Asked before putting back parked mods that a world allows
#                            - Turned other mods off too as the game restarts for a world's downloaded mods
#                            - Put the turned-off mods back when the start for a world ended without entering it
#                            - Refused a full world or one still being set up before restarting for it
#                            - Asked the creator of a world that turns other mods off to take the game's data once they are off
#                            - Sent Turn off other mods with the new world and the edits
#                            - Said in a world's details whether it turns other mods off, and listed the player's mods it turns off
#                            - Had the parked mods' journal name the world about to be entered
#                            - Told the player that another game of this folder has mods turned off
#                            - Sent a Raid World's difficulty with the new world and the edits, and showed it in the details
#                            - Sent neither a starting save nor the player's choice with a new Raid World
#      Paulinchen  2026-10-08: Showed Raid Worlds in red, and their type and companion sharing in the details
#                            - Sent the new world's type and companion sharing, and kept both in world.ini
#                            - Drew and turned the forms' switches in Window_MpWorldForm
#                            - Sent Shared Mod Settings with a new world and from the creator's edit form
#                            - Closed the list boxes, the details, the mod picker and the start's choice with Numpad 0
#                            - Backed out of the worlds or the commands with Numpad 0 also with Num Lock off
#                            - Said in a world's details whether it shares its creator's mod settings
#                            - Noted the world entered with its creator and settings in one call
#                            - Told whether the list was fetched since the screen opened as a world is entered
#                            - Said when the edit form's Shared Mod Settings apply
#                            - Noted the world's mod settings only as the world opens
#                            - Started the edit form's Shared Mod Settings from the settings the relay took last
#                            - Claimed each directory action it starts, and gave up its answer as the screen closes
#                            - Told the player to restart by hand under Wine or Proton after installing a world's mods
#      Paulinchen  2026-10-07: Left typing alone without a form, and logged where the screen failed
#                            - Cut texts through MGQ_MpUi.cut, and took the choice window's depth from MGQ_MpUi
#                            - Logged the screen's actions with their outcome and reason
#                            - Filled the name's form with the name the player chose
#      Paulinchen  2026-10-06: Typed a world's password in place in a form
#                            - Kept a name typed in place without closing the screen, and a name from the text screen at once
#                            - Fell back to the text screen for a mod's name without the keyboard or with a gamepad
#                            - Kept the typing hint while a mod's name is typed, and acted on the mod clicked
#                            - Waited with a Discord invite or an entry after a restart until no window, box or form is open
#                            - Asked for the password again once a Discord invite's code failed
#                            - Kept a full world closed to players with saves of it too
#                            - Put the cursor back on the chosen world after the text or save screen
#                            - Sent a form's tidied values
#                            - Typed a 0 with Numpad 0 in Max Players and World id
#                            - Said that a request could not be started instead of that another one runs
#                            - Took the colors of a world's mods in the list box and the details from one place
#                            - Created the list box with the other windows, and closed the screen when it cannot start
#                            - Read the installed mods anew only as the screen opens
#                            - Played the OK sound in the mod picker only for a change it took
#                            - Entered the world of a Discord invite once the list holds it
#                            - Asked for the player's name in a form typed in place
#                            - Kept a mod added by name when unlisted, and removed it with Delete
#                            - Typed a mod's name in place in the picker
#                            - Named a mod in the picker with Enter and its ! and ? buttons, and listed or unlisted every mod at once
#                            - Had an admin's game send the Mod Config options of the catalog's mods as the list arrives
#                            - Picked a world's mods in the mod picker
#                            - Left the mod settings out of creating and changing a world, and noted whose world is entered
#                            - Checked a world's required mods on entry, and offered to download them and restart
#                            - Entered the world again on its own after a restart for its mods
#                            - Sent the creator's mod hashes and settings with a world made or changed
#                            - Showed the installed and the world's version of each required mod in the details
#      Paulinchen  2026-10-04: Picked the worlds or the commands as a whole first, then moved into the picked window
#                            - Created the list box before a cancelled name prompt closes the screen
#                            - Kept a world this PC has saves of from being entered while the list has not arrived
#                            - Broke a description's lines through MGQ_MpUi.wrap
#                            - Renamed from mp_world_screen.rbx
#                            - Drew the forms' text boxes through MGQ_MpUi::TextBox and MGQ_MpUi::TextEdit
#                            - Showed a world's description, the mods it needs and whether the player's game data matches
#                            - Laid the world's details out like a form, in panels
#                            - Laid the forms out in the same panels, with the whole description in a box of several lines
#                            - Listed every player of a world, and each mod it needs, in a list box
#                            - Showed the description in a smaller font, and whole in the list box
#                            - Kept the commands in a window of their own below the worlds
#                            - Left a new world to be entered from the list, as a favourite
#                            - Took the players and the mods out of a world's choices
#                            - Left a text box being typed into with Numpad 0
#                            - Typed into the forms' text boxes with a cursor
#                            - Showed required mods in green, or in red while this game lacks their script, and kept such a game out
#                            - Showed essential mods in green while this game's data matches the world's, in gold otherwise
#                            - Let a world's creator take their game's data as the world's
#                            - Drew the list and the details only when what they show changed
#                            - Logged frames of the world screen that take long
#                            - Showed each mod in a box of its own in the details
#                            - Said create where a text said make
#                            - Added a hidden world to the list by its id, and offered to take it off again
#                            - Offered the creator and admins a form that changes a world's Max Players, mods and description
#                            - Shortened the messages that did not fit the lines at the top
#                            - Asked whether games whose data differs may enter
#                            - Warned a game whose data differs before it enters a world, or kept it out
#                            - Showed the end of a text too long for its text box
#      Paulinchen  2026-10-03: Created
#
#----------------------------------------------------------------

# The world screen. It builds on world.rbx, which knows the worlds, and on the Mod Framework's UI
# layer, which lays it out, routes the keys, the mouse and a gamepad, and types.

# The world screen's model in the DLL (WorldScreen and WorldScreenModel): the worlds it lists, a
# world's details, its choices and the list box's rows, and the screen's texts. The scripts draw
# what it says.
module MGQ_MpWorldScreen
  # The topic that opens the screen, which fetches the list at once and every ten seconds after.
  OPEN_TOPIC = "screen.open"

  # The topic that closes the screen, which stops the refresh.
  CLOSE_TOPIC = "screen.close"

  # The topic that hands out the screen's texts.
  TEXTS_TOPIC = "screen.texts"

  # The topic that hands out the list as it stands.
  LIST_TOPIC = "screen.list"

  # The topic that finds one world in the list.
  WORLD_TOPIC = "screen.world"

  # The topic that hands out a world's details.
  DETAILS_TOPIC = "screen.details"

  # The topic that hands out what can be done with a world.
  ACTIONS_TOPIC = "screen.actions"

  # The topic that hands out the list box's lines of a world.
  BOX_TOPIC = "screen.box"

  # The list as it stands, while the DLL did not answer.
  NO_LIST = { "state" => "idle", "error" => nil, "admin" => false, "info" => nil, "empty" => nil, "rows" => [] }

  # The colors of the list box's rows, by the names the DLL gives them; "plain" and "normal" take none.
  BOX_COLORS = { "good" => :success, "gold" => :gold, "warn" => :warning, "bad" => :error, "grey" => :dim }

  # Opens the screen.
  def self.open
    MGQ_Multiplayer::Bridge.call(OPEN_TOPIC)
  end

  # Closes the screen.
  def self.close
    MGQ_Multiplayer::Bridge.call(CLOSE_TOPIC)
  end

  # Reads one of the screen's texts, asked once.
  #
  # @param name [String] "hint" or "enter_hint".
  # @return [String] The text, empty while the DLL did not answer.
  def self.text(name)
    texts[name].to_s
  end

  # Reads what the screen says while an action runs.
  #
  # @param kind [String] The action's kind, such as "create".
  # @return [String, nil] The text, nil for a kind it names none for.
  def self.busy_text(kind)
    (texts["busy"] || {})[kind]
  end

  # Reads the screen's texts, asked once.
  #
  # @return [Hash] The texts, none while the DLL did not answer.
  def self.texts
    @texts ||= MGQ_Multiplayer::Bridge.call(TEXTS_TOPIC)
    @texts.is_a?(Hash) ? @texts : {}
  end

  # Reads the list as it stands under the search and the filters, which the DLL matches.
  #
  # @param filter [Hash] "search", "type" ("all", "raid" or "classic") and "online".
  # @return [Array] The state ("idle", "loading", "ready" or "failed"), why it failed, whether the
  #   player is one of the relay's admins, the list's line at the top (nil for none), what the list
  #   says while the filters hide every world (nil otherwise) and every entry, each an
  #   MGQ_MpWorld::Entry with its row, whose "shown" tells whether the filters show it.
  def self.list(filter = nil)
    list = MGQ_Multiplayer::Bridge.call(LIST_TOPIC, filter)
    list = NO_LIST unless list.is_a?(Hash)
    [list["state"], list["error"], list["admin"] == true, list["info"], list["empty"], list["rows"].map { |row| entry_of(row) }]
  end

  # Finds one world in the list as it stands, with its mods once they were read.
  #
  # @param id [String] The world's id.
  # @return [MGQ_MpWorld::Directory::ListedWorld, nil] The world, nil when the list lacks it.
  def self.world(id)
    found = MGQ_Multiplayer::Bridge.call(WORLD_TOPIC, id.to_s)
    found.is_a?(Hash) && found["listed"] ? listed_of(found["listed"]) : nil
  end

  # Reads a world's details.
  #
  # @param entry [MGQ_MpWorld::Entry] The world.
  # @return [Hash, nil] "title", "title_color", "played", "panels" and "description"; nil when the
  #   DLL's list lacks it.
  def self.details(entry)
    answer = entry.key ? MGQ_Multiplayer::Bridge.call(DETAILS_TOPIC, entry.key) : nil
    answer.is_a?(Hash) ? answer : nil
  end

  # Reads what can be done with a world.
  #
  # @param entry [MGQ_MpWorld::Entry] The world.
  # @return [Array<Array>] Each choice's label, symbol and whether it can be chosen; Back alone when
  #   the DLL's list lacks the world.
  def self.actions(entry)
    answer = entry.key ? MGQ_Multiplayer::Bridge.call(ACTIONS_TOPIC, entry.key) : nil
    return [["Back", :cancel]] unless answer.is_a?(Array)

    answer.map { |label, symbol, enabled| [label, symbol.to_sym, enabled] }
  end

  # Reads the list box's rows of a world's players, mods, World facts or Game data.
  #
  # @param entry [MGQ_MpWorld::Entry] The world.
  # @param kind [Symbol] :players, :mods, :world or :data.
  # @return [Array<Hash>] The rows of MGQ_MpListBox: headings, and items with their color and what
  #   their right end says; none when the DLL's list lacks the world.
  def self.box(entry, kind)
    answer = entry.key ? MGQ_Multiplayer::Bridge.call(BOX_TOPIC, "key" => entry.key, "kind" => kind.to_s) : nil
    return [] unless answer.is_a?(Array)

    answer.map do |kind_of, text, color, note|
      kind_of == "head" ? { :heading => text.to_s } : { :text => text.to_s, :color => BOX_COLORS[color.to_s], :right => note }
    end
  end

  # Makes an entry of a row of the list.
  #
  # @param row [Hash] The row, as screen.list tells it.
  # @return [MGQ_MpWorld::Entry] The entry.
  def self.entry_of(row)
    MGQ_MpWorld::Entry.new(row["id"], row["name"], row["listed"] && listed_of(row["listed"]), row["local"] && MGQ_MpWorld::World.new(row["local"]),
                           row["favourite"], row["gone"], row["key"], row)
  end

  # Makes a world of the directory as the scripts keep it.
  #
  # @param values [Hash] The world, as screen.list tells it.
  # @return [MGQ_MpWorld::Directory::ListedWorld] The world.
  def self.listed_of(values)
    MGQ_MpWorld::Directory.listed_of(values)
  end
end

# The world screen, opened from the title screen: the lines across the top, the worlds at the left
# above the commands, and at the right the chosen world's details or a form. Its window is the UI
# layer's (WorldScreen); this scene keeps what the screen shows, plays the DLL's steps and opens the
# menus, the questions, the list box, the mod picker, the formation limits and the dialog of the
# mods a world needs. What the screen decides is the DLL's (WorldScreen, WorldEntering, WorldForms,
# ModPick); the scene draws what it answers and hands over what the player does.
class Scene_MpWorlds < Scene_MenuBase
  # The Mod Framework's UI.
  UI = Mod_Framework::UI

  # What the lines at the top say while a field types, the keys that go back filled in.
  TYPING_HINT = "Type on the keyboard. Arrows, Home, End move the cursor. Enter keeps it, %s goes back."

  # The topic that enters a world through the DLL's steps.
  ENTER_TOPIC = "screen.enter"

  # The topic that hands the DLL's steps the player's answer or what a step's effect did.
  ANSWER_TOPIC = "screen.answer"

  # The topic that follows the DLL's running action.
  STEP_TOPIC = "screen.step"

  # The topic that runs a command of the screen in the DLL.
  DO_TOPIC = "screen.do"

  # The forms of the chosen world, which no command of the list stands for.
  WORLD_FORMS = [:edit_world, :password]

  # The commands below the worlds, each its text and symbol; the forms are kept under the symbol.
  COMMANDS = [["Create new world", :new_world], ["Add a hidden world", :join_hidden], ["Change your name", :rename], ["Back", :back]]

  # Seconds a frame of the screen may take before the log says what took them.
  SLOW_FRAME = 0.05

  # Seconds between two log lines of slow frames.
  SLOW_FRAME_PAUSE = 2.0

  # The screen's window, not movable.
  ROOT_ID = :mgq_online_world_screen

  # Width of the worlds and the commands.
  LEFT_WIDTH = 230

  # Height of the lines at the top: three lines and the room of their box, kept while the third says
  # nothing, so the boxes below never move.
  STRIP_HEIGHT = 92

  # Room the screen's window leaves between the lines at the top and the boxes below.
  STRIP_GAP = 4

  # Room between the rows of a panel of the details or a group of a form, in units of 4 pixels.
  ROW_SPACING = 0.5

  # The caption the captions of a form line up with, the widest of the usual ones; a longer caption
  # keeps its own width.
  FORM_CAPTION = "Max Players"

  # How a cell of a row of the details takes its room: an equal share of the row whatever it holds,
  # so its caption and its value start at one place on every row.
  DETAIL_CELL = { width: 0, grow: 1 }

  # Least heights of the boxes of the World and the Game data panels of the details, by their
  # target: the most rows either shows, a Raid World's four and the Game data's three, inside a
  # border of one pixel, so a world with fewer rows moves nothing below them while the cursor walks
  # the worlds.
  BOX_HEIGHTS = { "world" => 112, "data" => 84 }

  # Width of the players beside the description, which takes the rest of the row to read.
  PLAYERS_WIDTH = 140

  # How a part of the details the player presses draws: a thin box in the look's edge color, so it
  # stands out as a part to pick, with a little room at its sides alone and no background of its
  # own, so the details fit the right box; the focus lights its edge.
  PRESSED_AREA = { clickable: true, border: :theme, border_width: 1, padding: [0, 0.5], background: false }

  # How a part of the details that opens nothing draws: without a box, as nothing there is picked.
  PLAIN_AREA = { clickable: false, border: false }

  # What the description says while a world has none.
  NO_DESCRIPTION = "No description."

  # The heading of a world's description.
  DESCRIPTION_TITLE = "Description"

  # What the lines at the top say on the World and the Game data panels of the details, by the
  # target the DLL gives them.
  PANEL_HELPS = { "world" => "Confirm shows every fact of this world in full.", "data" => "Confirm shows the world's mods and game data settings in full." }

  # The list box's note for each kind of lines the DLL writes.
  BOX_NOTES = { :players => "Players", :world => "World", :data => "Game data" }

  # The title of the formation limits over a form.
  LIMITS_TITLE = "Formation limits"

  # The title of the mod picker.
  MOD_PICK_TITLE = "Mods of the world"

  # The mod picker's key line.
  MOD_PICK_KEYS = [{ :button => :C, :text => "list or unlist" }, { :key => "→", :text => "! required, ? essential" }, { :button => :B, :text => "done" }]

  # The colors of the mod picker's rows, by the names ModPick gives them; :plain takes none.
  MOD_PICK_COLORS = { :grey => :dim, :bad => :error, :gold => :gold }

  # The colors of the details' cells, by the names the DLL gives them; "normal" takes none.
  CELL_COLORS = { "good" => :success, "warn" => :warning, "gold" => :gold, "bad" => :error }

  # The colors of the worlds' rows and names, by the names the DLL gives them; "normal" takes none.
  ROW_COLORS = { "raid" => MGQ_MpWorld::RAID_COLOR, "featured" => MGQ_MpWorld::FEATURED_COLOR, "favourite" => :warning }

  # The width of a menu of the screen.
  MENU_WIDTH = 360

  # The most rows a menu of the screen shows before it scrolls.
  MENU_ROWS = 10

  # The caption of the search above the worlds, which also titles a gamepad's letter pages.
  SEARCH_CAPTION = "Search"

  # What the search shows while it is empty.
  SEARCH_PLACEHOLDER = "World name"

  # The most characters the search takes, a world name's.
  SEARCH_CHARS = 40

  # What the help line says on the search.
  SEARCH_HELP = "Type part of a world's name to show only the worlds that hold it."

  # The type filter's items: text, value the DLL matches and tooltip.
  TYPE_FILTERS = [["All", "all", "Every world"], ["Raid", "raid", "Raid Worlds only"], ["Classic", "classic", "Classic worlds only"]]

  # What the help line says on the type filter.
  TYPE_HELP = "Show every world, only Raid Worlds or only Classic worlds."

  # The players online filter's one item: text and tooltip.
  ONLINE_FILTER = ["Online", "Someone online"]

  # What the help line says on the players online filter.
  ONLINE_HELP = "Show only the worlds with someone online."

  # What the help line says on the box of the search and the filters as a whole.
  FILTERS_HELP = "Confirm to search the worlds by name or filter them by type and players online."

  # Tells what the lines at the top say while a field types, naming the keys that go back while
  # typing.
  #
  # @return [String] The hint.
  def self.typing_hint
    format(TYPING_HINT, UI.cancel_keys(:text))
  end

  # @return [String, nil] What runs in the DLL, which holds the screen, nil while nothing does.
  attr_reader :busy

  # @return [Integer] Counts the changes the window shows, which it watches.
  attr_reader :serial

  # @return [Array<MGQ_MpWorld::Entry>] The worlds the search and the filters show, in the list's
  #   order.
  attr_reader :entries

  # @return [String] What the search holds.
  attr_reader :search

  # @return [String] The type filter: "all", "raid" or "classic".
  attr_reader :type_filter

  # @return [Boolean] Whether only worlds with someone online show.
  attr_reader :online_filter

  # @return [String, nil] What the list says while the filters hide every world, nil otherwise.
  attr_reader :list_empty

  # @return [Integer] The row of the worlds the cursor is on.
  attr_reader :world_index

  # @return [Integer] The row of the commands the cursor is on.
  attr_reader :command_index

  # @return [Array, nil] Where the focus should go: [target, serial], see request_focus.
  attr_reader :focus_request

  # @return [Array, nil] What the lines at the top should say: [text, serial], see say.
  attr_reader :said

  # @return [Symbol, nil] The form entered, nil while none is.
  attr_reader :form_symbol

  # @return [Hash{Symbol => MGQ_MpWorld::WorldForm}] The forms, by their symbol.
  attr_reader :forms

  # @return [Object, nil] The formation limits' handle, nil while closed.
  attr_reader :limits

  # @return [Object, nil] The list box's or the mod picker's handle, nil while neither is open.
  attr_reader :list_box

  # @return [MGQ_MpWorld::ModPick, nil] The mod picker's mods, nil while it is closed.
  attr_reader :mod_pick

  # Opens the window, fetches the list, and takes what the save screen handed back.
  #
  # The scene is the same object again when the save screen returns, so the forms, the search and
  # the filters keep what was filled in; the window opens anew.
  def start
    super
    returning = @forms ? true : false
    # The save screen returns to the same object, which read the installed mods already.
    MGQ_MpWorldMods.forget_installed unless @forms
    @forms ||= { :new_world => MGQ_MpWorld::WorldForm.create(:new_world), :join_hidden => MGQ_MpWorld::WorldForm.join(:join_hidden) }
    @forms[:rename] = MGQ_MpWorld::WorldForm.rename(:rename, MGQ_Multiplayer::Player.setting("name").to_s)
    @me = MGQ_MpWorld::Directory.my_id
    @later = []
    @serial = 0
    @world_index ||= 0
    @command_index ||= 0
    @whole = :commands
    @place = nil
    @arrived = false
    @entries = []
    @all_entries = []
    @search ||= ""
    @type_filter ||= TYPE_FILTERS[0][1]
    @online_filter ||= false
    @restore = @entry.id if @entry && (@form_symbol.nil? || WORLD_FORMS.include?(@form_symbol))
    request_focus(:commands_box)
    say(MGQ_MpWorldScreen.text("hint"))
    open_steps
    MGQ_MpWorldScreen.open
    look_at_list
    take_start_save
    @screen = UI.open(WorldScreen, :scene => self) { |_result, why| screen_closed(why) }
    return leave_screen("its window did not open") unless @screen

    return_to_form if @form_symbol
    @ask_name = MGQ_Multiplayer::Player.name.nil? && !@name_asked
    name = MGQ_Multiplayer::Player.name
    log_screen(returning ? "back from the save screen" : "opened, #{name ? "playing as #{name} (#{MGQ_MpWorld.short(@me)})" : 'no name yet'}")
  rescue => e
    MGQ_MpWorld.log("world screen could not start: #{e.class}: #{e.message} at #{Array(e.backtrace).first}")
    return_scene
  end

  # Asks for the player's name the first time, runs what a menu or a question answered, follows a
  # running action, asks again for a release to play whose question could not open, and keeps the
  # list, the details and the installed mods fresh.
  def update
    started = Time.now
    @spent = {}
    due = @later
    @later = []
    timed(:windows) { super }
    due.each { |block| block.call }

    if @ask_name
      @ask_name = false
      return ask_name
    end

    return start_from_own if @own_start

    timed(:action) { follow_steps } if @busy
    MGQ_MpWorldMods.follow_framework
    MGQ_MpWorld::Update.on_world_screen_update(self, popup_open?)
    timed(:details) { follow_details }
    timed(:list) { look_at_list }
    log_slow_frame(Time.now - started)
  rescue => e
    MGQ_MpWorld.log("world screen failed: #{MGQ_MpLog.failure(e)} at #{Array(e.backtrace).first}")
    return_scene
  end

  # Runs a part of the frame and notes how long it took.
  #
  # @param part [Symbol] What the part is called in the log.
  # @yield The part.
  # @return [Object] What the part returned.
  def timed(part)
    started = Time.now
    result = yield
    @spent[part] = Time.now - started
    result
  end

  # Logs a frame that took long, with what took the time, a few seconds apart at most.
  #
  # @param seconds [Float] How long the frame took.
  def log_slow_frame(seconds)
    return if seconds < SLOW_FRAME || (@slow_logged && Time.now - @slow_logged < SLOW_FRAME_PAUSE)

    @slow_logged = Time.now
    parts = @spent.map { |part, spent| "#{part} #{(spent * 1000).round}" }.join(", ")
    MGQ_MpWorld.log("world screen: a frame took #{(seconds * 1000).round} ms (#{parts})")
  end

  # Runs what a menu or a question answered in the next frame's update, once the framework gave the
  # focus back to the screen as the menu or the question closed.
  #
  # @yield What to run.
  def later(&block)
    @later << block
  end

  # Closes the screen's window, its boxes and the open menu or question, and tells the DLL the
  # screen closed.
  def terminate
    close_popups
    dll_do("close") if @busy
    MGQ_MpWorldScreen.close
    @closing = true
    [@list_box, @limits, @screen].each { |root| root.close if root && root.open? }
    @list_box = @limits = @screen = nil
    @closing = false
    log_screen("closed")
    super
  end

  # Leaves the screen for the title, as cancel on a box as a whole and the commands' Back do.
  #
  # @param why [String] Why, for the log.
  def leave_screen(why = "leaving for the title")
    log_screen(why)
    return_scene
  end

  # Follows the window closing other than by the scene's end, such as a refused open: the screen
  # leaves too.
  #
  # @param why [Symbol, String] Why it closed.
  def screen_closed(why)
    return if @closing || why == :script || why == :scene

    @screen = nil
    leave_screen("its window closed: #{why}")
  end

  # Writes a line of the world screen to the log.
  #
  # @param message [String] The line.
  def log_screen(message)
    MGQ_MpWorld.log("world screen: #{message}")
  end

  # Names the chosen world for the log.
  #
  # @return [String] Its name and its id's start.
  def entry_text
    @entry ? "#{@entry.name} (#{MGQ_MpWorld.short(@entry.id)})" : "no world"
  end

  # Tells the window to show what changed.
  def changed
    @serial += 1
  end

  # Asks the window to put the focus on a part once it shows: :worlds_box or :commands_box as a
  # whole, the rows of :worlds or :commands, or [:field, key] of the form entered; a part's id is its
  # name with the mgq_online_ prefix.
  #
  # @param target [Symbol, Array] Where.
  def request_focus(target)
    @focus_request = [target, (@focus_request ? @focus_request[1] : 0) + 1]
    changed
  end

  # Says something in the lines at the top, until the focus moves.
  #
  # @param message [String, nil] What to say; nil says nothing.
  def say(message)
    return if message.nil?

    @said = [message.to_s, (@said ? @said[1] : 0) + 1]
    changed
  end

  # Tells what the lines at the top say besides the help: who plays and how the list stands.
  #
  # @return [Array<String>] The player's line and the list's line, empty for none.
  def strip_lines
    name = MGQ_Multiplayer::Player.name
    [name ? "You play as #{name}." : "You have no name yet.", @list_info.to_s]
  end

  # Shows the list the DLL holds once it changed, then enters a world waiting for the list: the one
  # the game started again for, or a Discord invite's.
  def look_at_list
    changed = MGQ_MpWorld::Changes.take?(MGQ_MpWorld::Changes::LIST)
    if changed || @list_state.nil?
      read_list
      MGQ_MpWorldMods.report_options(@admin) if @list_state == "ready"
    end
    look_for_entry(@all_entries, @list_state) if @waiting
  end

  # Reads the list under the search and the filters and shows it.
  def read_list
    @list_state, @list_error, @admin, @list_info, @list_empty, entries = MGQ_MpWorldScreen.list(filter_request)
    show_entries(entries)
  end

  # Tells the DLL's list the search and the filters.
  #
  # @return [Hash] "search", "type" and "online".
  def filter_request
    { "search" => @search, "type" => @type_filter, "online" => @online_filter }
  end

  # Takes what the search holds as the player types.
  #
  # @param text [String] The text.
  def searched(text)
    return if text.to_s == @search

    @search = text.to_s
    read_list
  end

  # Takes the type filter the player turned on.
  #
  # @param type [String] "all", "raid" or "classic".
  def type_turned(type)
    return if type.nil? || type.to_s == @type_filter

    @type_filter = type.to_s
    read_list
  end

  # Takes the players online filter as the player turned it.
  #
  # @param values [Array] The values on: the filter's own while it is on.
  def online_turned(values)
    @online_filter = !Array(values).empty?
    read_list
  end

  # Moves the focus from the search onto the worlds, as Enter there does.
  def search_done
    request_focus(:worlds)
  end

  # Shows other worlds, the cursor kept on its world while the filters show it. The first worlds to
  # arrive pick the worlds' box as a whole if the commands' box is still picked as a whole where it
  # started, or the cursor goes onto the world chosen before the save screen; the commands' box is
  # picked as a whole when the last world went; the cursor moves onto a world asked for once the
  # list shows it.
  #
  # @param entries [Array<MGQ_MpWorld::Entry>] Every world, each row telling whether the filters
  #   show it.
  def show_entries(entries)
    kept = current_entry && current_entry.key
    @all_entries = entries
    @entries = entries.select { |entry| entry.row.nil? || entry.row["shown"] != false }
    at = kept && @entries.index { |entry| entry.key == kept }
    @world_index = at || [[@world_index, @entries.size - 1].min, 0].max
    changed
    if !@arrived && !@entries.empty?
      @arrived = true
      if !restore_world(@entries) && @place.nil? && @whole == :commands && !@form_symbol
        request_focus(:worlds_box)
        @whole = :worlds
      end
    elsif entries.empty? && @whole == :worlds && !@form_symbol
      request_focus(:commands_box)
      @whole = :commands
    end
    select_asked(entries)
  end

  # Writes a world's row as the DLL wrote it: its players online and seats at the right, a Raid
  # World in red, a featured one in gold, a favourite in the crisis color, one that left the list
  # pale.
  #
  # @param entry [MGQ_MpWorld::Entry] The world.
  # @return [Hash] The row.
  def world_row(entry)
    row = entry.row || {}
    color = ROW_COLORS[row["color"]]
    shown = { :text => row["text"].to_s, :faint => row["dim"] ? true : false }
    shown[:right] = row["count"].to_s if row["count"]
    shown[:color] = color if color
    shown
  end

  # Puts the cursor on a world once the first worlds arrive, the world chosen before the save
  # screen, if the list holds it; the focus goes into the worlds unless a form took it.
  #
  # @param entries [Array<MGQ_MpWorld::Entry>] The worlds, in the list's order.
  # @return [Boolean] Whether the cursor moved onto it.
  def restore_world(entries)
    id = @restore
    @restore = nil
    at = id ? entries.index { |entry| entry.id == id } : nil
    return false unless at

    @world_index = at
    unless @form_symbol
      request_focus(:worlds)
      @whole = :worlds
    end
    true
  end

  # Puts the cursor on a world as soon as the list shows it, as on the world just created or
  # added, which the list may show only once it was fetched again. One world at a time: a world
  # asked for before and not shown yet gives way.
  #
  # @param id [String] The world's directory id.
  def select_world(id)
    log_screen("the cursor goes onto world #{MGQ_MpWorld.short(id)} once the list shows it#{@select ? ", instead of world #{MGQ_MpWorld.short(@select)}" : ''}")
    @select = id
  end

  # Moves the cursor into the worlds, onto the world asked for with select_world, once the list
  # shows it; the ask is over then. The cursor stays where it is when the player moved on to a form
  # or a menu meanwhile, since it would jump under them. A world the search or the filters hide
  # clears them, so it shows under the cursor.
  #
  # @param entries [Array<MGQ_MpWorld::Entry>] Every world, in the list's order.
  # @return [Boolean] Whether the cursor moved onto it.
  def select_asked(entries)
    id = @select
    return false unless id && entries.any? { |entry| entry.id == id }

    unless on_left_side?
      @select = nil
      log_screen("the cursor stays off world #{MGQ_MpWorld.short(id)}, which the list shows now: the player moved on")
      return false
    end

    at = @entries.index { |entry| entry.id == id }
    return filtered? ? clear_filters(id) : false unless at

    @select = nil

    @world_index = at
    @whole = :worlds
    request_focus(:worlds)
    log_screen("the cursor is on world #{MGQ_MpWorld.short(id)} now, row #{at + 1} of the list")
    true
  end

  # Tells whether the search or a filter is on.
  #
  # @return [Boolean] Whether one is.
  def filtered?
    !@search.strip.empty? || @type_filter != TYPE_FILTERS[0][1] || @online_filter
  end

  # Clears the search and the filters, which hide a world the cursor should go onto, and shows the
  # list anew.
  #
  # @param id [String] The world's directory id.
  # @return [Boolean] Whether the cursor moved onto it.
  def clear_filters(id)
    log_screen("the search and the filters are cleared: they hid world #{MGQ_MpWorld.short(id)}, which the cursor goes onto")
    @search = ""
    @type_filter = TYPE_FILTERS[0][1]
    @online_filter = false
    read_list
    @select.nil?
  end

  # Tells whether the focus is in the filters, the worlds or the commands, with no form, menu,
  # question or box over them.
  #
  # @return [Boolean] Whether it is.
  def on_left_side?
    !@form_symbol && !popup_open? && !box_open? && !@busy
  end

  # Notes that the keys went into the box of the search and filters, the worlds or the commands; in
  # the search and filters the right side keeps the world under the cursor. Coming straight from a
  # field of the form entered, as cancel, a click or a key there does, the form is left and the
  # focus stays where it went.
  #
  # @param side [Symbol] :filters, :worlds or :commands.
  def entered(side)
    from_form = @form_symbol && @place == :form
    @place = side
    @whole = side == :filters ? :worlds : side
    changed
    return unless from_form
    return keep_name_form("moved off it") if name_missing?

    on_form_cancel(false)
  end

  # Notes that the keys left the box of the search and filters, the worlds or the commands: into the
  # form entered, or back out onto the box as a whole or the details. A box the keys left after
  # they went into another keeps the other's place.
  #
  # @param side [Symbol] :filters, :worlds or :commands.
  def left(side)
    return unless @place == side

    @place = @form_symbol ? :form : nil
    changed
  end

  # Notes the world the cursor moved to.
  #
  # @param entry [MGQ_MpWorld::Entry] The world.
  def pointed_world(entry)
    at = @entries.index(entry)
    return unless at

    @world_index = at
    changed
  end

  # Notes the command the cursor moved to.
  #
  # @param command [Array] Its text and symbol.
  def pointed_command(command)
    at = COMMANDS.index(command)
    return unless at

    @command_index = at
    changed
  end

  # Finds the world the worlds' cursor is on.
  #
  # @return [MGQ_MpWorld::Entry, nil] The world, nil for none.
  def current_entry
    @entries[@world_index]
  end

  # Finds the command the commands' cursor is on.
  #
  # @return [Symbol] Its symbol.
  def current_command
    COMMANDS[@command_index][1]
  end

  # Tells what the right side shows: the form entered, a command's form as a preview while the
  # commands' box is picked, or the world the worlds' cursor is on while the worlds' box is.
  #
  # @return [Array, nil] [:form, symbol], [:preview, symbol] or [:world, entry]; nil for nothing.
  def right_view
    return [:form, @form_symbol] if @form_symbol && @forms[@form_symbol]

    if @whole == :worlds
      entry = current_entry
      entry ? [:world, entry] : nil
    else
      symbol = current_command
      @forms[symbol] ? [:preview, symbol] : nil
    end
  end

  # Opens the world the cursor is on while the screen waits for the player, so the list carries
  # its mods, and shows its details anew once they read something new.
  def follow_details
    view = right_view
    world = view && view[0] == :world ? view[1] : nil
    MGQ_MpWorld::Directory.open(world && world.listed ? world.id : nil) if idle? && !scene_changing?
    changed if MGQ_MpWorld::Changes.take?(MGQ_MpWorld::Changes::DETAILS | MGQ_MpWorld::Changes::MODS)
  end

  # Tells whether the name form is open while the player has no name, which only cancel leaves,
  # closing the screen.
  #
  # @return [Boolean] Whether it is.
  def name_missing?
    @form_symbol == :rename && MGQ_Multiplayer::Player.name.nil?
  end

  # Puts the focus back into the name form the player has to fill in first.
  #
  # @param what [String] What the player did, for the log.
  def keep_name_form(what)
    log_screen("the name form stays: the player #{what} without a name")
    resume_form
  end

  # Takes cancel on the screen, which reaches it from a field of the form entered once the field no
  # longer types, or on a box as a whole: leaves the form back to its list, else leaves for the
  # title; it buzzes while an action of the DLL runs, which the screen waits for.
  def cancelled
    if @busy
      Sound.play_buzzer
      return log_screen("cancel while #{@busy} runs: the screen waits for it")
    end

    @form_symbol && @place == :form ? on_form_cancel : leave_screen
  end

  # Buzzes at what the player does while an action of the DLL runs.
  #
  # @param what [String] What the player did, for the log.
  # @return [Boolean] Whether an action runs.
  def held?(what)
    return false unless @busy

    Sound.play_buzzer
    log_screen("#{what} while #{@busy} runs: the screen waits for it")
    true
  end

  # Tells the DLL the screen opened (topic screen.do, open), with the world the game started again
  # for, which the DLL then enters once the list holds it, as it does a Discord invite's world.
  def open_steps
    play(dll_do("open", "rejoin" => MGQ_MpWorldMods.rejoining, "me" => @me.to_s))
    MGQ_MpWorldMods.rejoined
  end

  # Hands the DLL the list while it waits to enter the world the game started again for or a
  # Discord invite names (topic screen.do, look).
  #
  # @param entries [Array<MGQ_MpWorld::Entry>] The list.
  # @param state [String] How the list stands.
  def look_for_entry(entries, state)
    @looked = entries
    rows = entries.map { |entry| [entry.id, entry.local && entry.local.id, entry.name.to_s, entry.gone ? true : false] }
    play(dll_do("look", "state" => state.to_s, "idle" => idle?, "named" => !MGQ_Multiplayer::Player.name.nil?, "entries" => rows))
  end

  # Runs a command of the screen in the DLL (topic screen.do).
  #
  # @param command [String] The command, such as "look".
  # @param request [Hash] What it needs.
  # @return [Hash, nil] Its steps, nil when the DLL did not answer.
  def dll_do(command, request = {})
    MGQ_Multiplayer::Bridge.call(DO_TOPIC, { "do" => command }.merge(request))
  end

  # Hands the DLL the player's answer or what a step's effect did (topic screen.answer), and plays
  # the steps that follow.
  #
  # @param answer [String] The answer, such as "back".
  # @param request [Hash] What it needs, such as "text".
  def answer(answer, request = {})
    play(MGQ_Multiplayer::Bridge.call(ANSWER_TOPIC, { "answer" => answer }.merge(request)))
  end

  # Describes the chosen world for the DLL's steps.
  #
  # @return [Hash] Its id, folder, name, whether the list no longer has it, and the player's id;
  #   this game's data went over as the screen opened.
  def entry_request
    { "id" => @entry.id.to_s, "folder" => @entry.local && @entry.local.id, "name" => @entry.name.to_s, "gone" => @entry.gone ? true : false, "me" => @me.to_s }
  end

  # Plays the steps the DLL answered, in order, see play_step.
  #
  # @param reply [Hash, nil] The answer, with "steps" and maybe "waiting".
  def play(reply)
    return unless reply.is_a?(Hash)

    @waiting = reply["waiting"] if reply.key?("waiting")
    Array(reply["steps"]).each { |step| play_step(step) }
  end

  # Plays one step of the DLL's way into a world (WorldEntering in C#).
  #
  # @param step [Array] The step's kind and what it needs.
  def play_step(step)
    kind, first, second, third, fourth = step
    case kind
    when "say" then say(first)
    when "buzz" then Sound.play_buzzer
    when "back" then back_to_list
    when "choices" then ask_dll(first)
    when "password" then ask_password(first)
    when "leave_form" then leave_form if @form_symbol == :password
    when "busy" then hold_for(first)
    when "idle" then free_screen
    when "entry" then @entry = (@looked || []).find { |entry| entry.id == first } || @entry
    when "read" then take_read_world
    when "edit" then on_edit_world
    when "forget_installed" then MGQ_MpWorldMods.forget_installed
    when "exit" then SceneManager.exit
    when "needed_mods" then ask_mods(first, second)
    when "save_screen" then MGQ_MpSaveDistribution.choose(:own)
    when "copy_own" then own_start(MGQ_MpWorld::World.new(first), second)
    when "start" then start_world(MGQ_MpWorld::World.new(first), second, third, fourth)
    when "discard" then MGQ_MpSaveDistribution.discard(MGQ_MpWorld::World.new(first))
    when "other_start" then MGQ_MpSaveDistribution.note_other_start(MGQ_MpWorld::World.new(first))
    when "place_start" then answer("placed", "ok" => MGQ_MpSaveDistribution.place(MGQ_MpWorld::World.new(first), second))
    when "fresh_form" then @forms[first.to_sym] = fresh_form(first)
    when "close_form" then leave_form
    when "select" then select_world(first)
    when "resume_form" then resume_form
    else log_screen("the DLL named a step this script does not know: #{kind}")
    end
  end

  # Asks the DLL's question of where to start in a menu, with what the steps said last as the
  # question. Cancel answers back.
  #
  # @param offered [Array<Array>] Each command's label and answer.
  def ask_dll(offered)
    close_popups
    choices = offered.map { |label, symbol| [label.to_s, symbol.to_s] }
    log_screen("asking where to start: #{choices.map { |_label, symbol| symbol }.join(', ')}")
    ask_menu(@said && @said[0], choices.map { |label, symbol| [label, symbol, true] }) { |symbol| symbol.to_s == "cancel" ? on_back(true) : answer(symbol.to_s) }
  end

  # Opens a menu of choices in the middle of the screen. Its answer runs in the frame after, once
  # the focus is back; cancel, a click outside and a close by the screen answer :cancel, and a menu
  # the screen closed itself answers nothing.
  #
  # @param question [String, nil] What it asks, nil for none.
  # @param choices [Array<Array>] Each choice's label, symbol and whether it can be chosen.
  # @yieldparam symbol [Object] The symbol picked, :cancel without a pick.
  # @return [Boolean] Whether the menu opened.
  def ask_menu(question, choices, &answered)
    serial = (@asked = @asked.to_i + 1)
    items = choices.map { |label, _symbol, enabled| { :text => label.to_s, :disabled => enabled == false } }
    params = { :width => MENU_WIDTH, :most_rows => MENU_ROWS }
    params[:title] = question.to_s unless question.to_s.empty?
    menu = UI.menu(items, params) do |_item, index|
      symbol = index ? choices[index][1] : :cancel
      later { answered.call(symbol) } if serial == @asked
    end
    @popup = menu ? [:menu, menu] : nil
    log_screen("a menu could not open: another one is open") unless menu
    menu ? true : false
  end

  # Asks a question with one doing command and Back, Back lit first. Its answer runs in the frame
  # after; a question the screen closed itself answers nothing.
  #
  # @param question [String] The question.
  # @param yes [String] The doing command.
  # @param back [String] The command that does nothing.
  # @yieldparam yes [Boolean] Whether the doing command was picked.
  # @return [Boolean] Whether the question opened.
  def ask_confirm(question, yes, back = "Back", &answered)
    serial = (@asked = @asked.to_i + 1)
    asked = UI.confirm(question.to_s, :yes => yes, :no => back) { |picked| later { answered.call(picked ? true : false) } if serial == @asked }
    @popup = asked ? [:confirm, asked] : nil
    log_screen("a question could not open: another one is open") unless asked
    asked ? true : false
  end

  # Tells whether the screen's menu or question is open.
  #
  # @return [Boolean] Whether one is.
  def popup_open?
    @popup && @popup[1].open? ? true : false
  end

  # Closes the screen's menu and question, whose answers then do nothing.
  def close_popups
    @asked = @asked.to_i + 1
    kind, handle = @popup
    @popup = nil
    return unless handle && handle.open?

    kind == :confirm ? handle.close("the world screen moved on") : handle.close
  end

  # Asks the Mod Framework to make ready the mods a world needs in its dialog "Mods for <world>":
  # each to install, update, change or turn on, each only its author has; its first button does
  # what can be done and enters, which starts the game again into the world where a mod that runs
  # already changes. The DLL hears whether the mods are ready, at once or later, or the player went
  # back.
  #
  # @param name [String] The world's name.
  # @param mods [Array<Hash>] Each mod "name", "version" (the world's, nil for any) and "differs".
  def ask_mods(name, mods)
    close_popups
    needed = Array(mods).map { |mod| { :name => mod["name"].to_s, :version => mod["version"], :differs => mod["differs"] == true } }
    log_screen("asking the Mod Framework for the mods #{name} needs: #{needed.map { |mod| "#{mod[:name]} #{mod[:version] || 'any'}#{mod[:differs] ? ', this copy differs' : ''}" }.join('; ')}")
    restart = [MGQ_Multiplayer::Stages::REJOIN_ACTION, @entry ? @entry.id.to_s : ""]
    @mods_asked = true
    asking = true
    handle = Mod_Framework::Mods.ask_needed(name, needed, :restart => restart) { |result| later { mods_answered(result) } unless asking }
    asking = false
    return mods_answered(:ready) if handle == :ready
    return if handle

    @mods_asked = nil
    log_screen("the mods #{name} needs could not be compared")
    refuse("The mods #{name} needs could not be checked. Try again in a moment.")
    answer("back")
  end

  # Hands the DLL how the dialog of the mods a world needs ended.
  #
  # @param result [Symbol] :ready, :restarting or :back.
  def mods_answered(result)
    @mods_asked = nil
    log_screen("the mods of #{entry_text}: #{result}")
    case result
    when :ready
      # The DLL checks the world's mods again at once, by the Mod Framework's list as it is now.
      MGQ_MpWorldMods.hand_framework
      answer("mods_ready")
    when :restarting then answer("mods_restarting")
    else answer("back")
    end
  end

  # Takes the chosen world anew, once the DLL read its mods.
  def take_read_world
    listed = MGQ_MpWorldScreen.world(@entry.id)
    @entry.listed = listed if listed
    changed
  end

  # Waits for the DLL's running action, which tells through MGQ_MpWorld::Changes once it ended.
  def follow_steps
    play(MGQ_Multiplayer::Bridge.call(STEP_TOPIC)) if MGQ_MpWorld::Changes.take?(MGQ_MpWorld::Changes::SCREEN)
  end

  # Tells whether the screen waits for the player, with no action, form, menu, question, list box,
  # mod picker, dialog of mods or formation limits open, so an entry of its own may begin.
  #
  # @return [Boolean] Whether it does.
  def idle?
    !@busy && !@form_symbol && !popup_open? && !box_open? && !@limits && !@own_start && !@mods_asked
  end

  # Tells whether the list box or the mod picker is open.
  #
  # @return [Boolean] Whether one is.
  def box_open?
    @list_box && @list_box.open? ? true : false
  end

  # Opens the list box for what the details point at.
  #
  # @param target [Symbol] :world, :data, :players or :description.
  def open_target(target)
    return if held?("opening the #{target}")

    entry = current_entry
    return unless entry

    @entry = entry
    open_box(target)
  end

  # Opens the list box with the chosen world's players, World facts, Game data or description.
  #
  # @param kind [Symbol] :players, :world, :data or :description.
  def open_box(kind)
    log_screen("showing the #{kind} of #{entry_text}")
    close_popups
    @list_box.close if box_open?
    params = if kind == :description
               { :source => MGQ_MpListBox::Source.new(nil, DESCRIPTION_TITLE), :description => @entry.listed ? @entry.listed.description.to_s : "" }
             else
               { :source => MGQ_MpListBox::Source.new(MGQ_MpWorldScreen.box(@entry, kind), BOX_NOTES[kind]) }
             end
    @list_box = UI.open(MGQ_MpListBox, params.merge(:title => @entry.name.to_s))
  rescue => e
    log_screen("the list box could not open: #{e.class}: #{e.message}")
    @list_box = nil
  end

  # Opens what can be done with the chosen world.
  #
  # @param entry [MGQ_MpWorld::Entry] The world.
  def on_world(entry)
    return if entry.nil? || held?("picking a world")
    return keep_name_form("picked a world") if name_missing?

    @entry = entry
    listed = @entry.listed
    creator = listed && listed.creator_id == @me
    commands = MGQ_MpWorldScreen.actions(@entry)
    log_screen("picked #{entry_text}: #{listed ? "#{listed.online}/#{listed.seats} online, start #{listed.start}" : 'not listed'}, " \
               "#{@entry.local ? "folder #{@entry.local.id}" : 'never entered'}#{creator ? ', own world' : ''}#{@admin ? ', as an admin' : ''}; " \
               "offers #{commands.map { |command| command[1] }.join(', ')}")
    ask_menu(nil, commands) { |symbol| world_action(symbol.to_sym) }
  end

  # Does what the player picked of a world's choices.
  #
  # @param symbol [Symbol] The choice, such as :enter; :cancel for Back.
  def world_action(symbol)
    case symbol
    when :enter then on_enter
    when :favourite then play(dll_do("favourite", entry_request))
    when :copy_id then play(dll_do("copy_id", entry_request))
    when :forget then play(dll_do("forget", entry_request))
    when :edit_world then on_edit_world
    when :ban then on_ban
    when :delete_world then confirm(:delete_world, "Delete #{@entry.name} for everyone? Saves stay on each PC.", "Delete it")
    when :export_save then on_export_save
    when :delete_saves then on_delete_saves
    else on_back(false, "the world's choices")
    end
  end

  # Acts on a command below the worlds: moves into its form, or leaves the screen.
  #
  # @param command [Array] Its text and symbol.
  def on_command(command)
    symbol = command[1]
    return if held?("picking #{symbol}")
    return leave_screen if symbol == :back
    return keep_name_form("picked a command") if name_missing?

    enter_form(symbol)
  end

  # Enters the chosen world through the DLL's steps (topic screen.enter), which ask, in order,
  # whether the world takes players now, whether its required mods match, whether the catalog its
  # other mods turned off need is known, and then for its password or where to start.
  def on_enter
    play(MGQ_Multiplayer::Bridge.call(ENTER_TOPIC, entry_request))
  end

  # Opens the form that asks for the chosen world's password, typing into it at once.
  #
  # @param name [String] The world's name.
  def ask_password(name)
    close_popups
    @forms[:password] = MGQ_MpWorld::WorldForm.password(:password, name)
    enter_form(:password)
  end

  # Lists the chosen world's other players to remove one, then asks.
  def on_ban
    others = @entry.listed.members.reject { |member| member.id == @me }
    log_screen("choosing a player to remove from #{entry_text}: #{others.map { |member| "#{member.name} (#{MGQ_MpWorld.short(member.id)})" }.join(', ')}")
    choices = others.map { |member| [member.name.to_s, member, true] } + [["Back", :cancel, true]]
    ask_menu(nil, choices) do |member|
      next on_back(false, "the players to remove") if member == :cancel

      @target = member
      confirm(:ban, "Remove #{member.name} from #{@entry.name}? They cannot enter it again.", "Remove them")
    end
  end

  # Copies the chosen world's latest save into the player's own game, see MGQ_MpSaveExport.
  def on_export_save
    log_screen("copying the latest save of #{entry_text} into the player's own game")
    say(MGQ_MpSaveExport.export(@entry.local))
    back_to_list
  end

  # Asks whether to delete the player's saves of the chosen world.
  def on_delete_saves
    question = "Delete your saves of #{@entry.name}?"
    question += @entry.open? ? " You would start anew." : " You would need its password again, and start anew." if @entry.listed
    confirm(:delete_saves, question, "Delete them")
  end

  # Asks whether to do something to the chosen world, saying the question in the lines at the top
  # too.
  #
  # @param what [Symbol] :ban, :delete_world or :delete_saves.
  # @param question [String] The question.
  # @param yes [String] The command that does it.
  def confirm(what, question, yes)
    log_screen("asking to confirm #{what} for #{entry_text}")
    say(question)
    ask_confirm(question, yes) { |picked| picked ? on_confirmed(what) : on_back(false, "confirming #{what}") }
  end

  # Does what the player confirmed.
  #
  # @param what [Symbol] :ban, :delete_world or :delete_saves.
  def on_confirmed(what)
    case what
    when :ban then play(dll_do("ban", entry_request.merge("target" => @target.id.to_s, "target_name" => @target.name.to_s)))
    when :delete_world then play(dll_do("delete", entry_request))
    when :delete_saves then play(dll_do("delete_saves", entry_request))
    end
  end

  # Backs out of a menu or a question, which leaves it unanswered; the DLL's question goes back to
  # it.
  #
  # @param dll [Boolean] Whether the DLL asked it.
  # @param what [String, nil] What the screen asked, for the log.
  def on_back(dll, what = nil)
    return answer("back") if dll

    log_screen("backed out of #{what || 'a menu'} for #{entry_text}")
    back_to_list
  end

  # Closes the menus and goes back to where the player was: the form being filled in, or the list,
  # which the framework gave the focus back already.
  def back_to_list
    close_popups
    resume_form if form && !@busy
  end

  # Opens the form of the player's name, typing into it at once, as when the screen opens and the
  # player has no name.
  def ask_name
    log_screen("asking for the player's name, which they have none of yet")
    @name_asked = true
    @command_index = COMMANDS.index { |_text, symbol| symbol == :rename }
    enter_form(:rename)
  end

  # Keeps the name the form holds, which the others see from now on.
  def rename_player
    before = MGQ_Multiplayer::Player.name
    MGQ_Multiplayer::Player.name = form[:name]
    @me = MGQ_MpWorld::Directory.my_id
    @forms[:rename] = MGQ_MpWorld::WorldForm.rename(:rename, MGQ_Multiplayer::Player.setting("name").to_s)
    leave_form
    log_screen("name: #{before.inspect} -> #{MGQ_Multiplayer::Player.name.inspect}#{form_name_empty_text}, id #{MGQ_MpWorld.short(@me)}")
    say("The others see you as #{MGQ_Multiplayer::Player.name}.")
  end

  # Tells the log that the name chosen is the one on Discord, when the player left it empty.
  #
  # @return [String] The note with a space in front, "" for a typed name.
  def form_name_empty_text
    MGQ_Multiplayer::Player.setting("name").to_s.empty? ? " (Discord's)" : ""
  end

  # The form the player fills in, nil while none is entered.
  #
  # @return [MGQ_MpWorld::WorldForm, nil] The form.
  def form
    @form_symbol && @forms[@form_symbol]
  end

  # Moves into a form at the right, onto the field it was left at or its first.
  #
  # @param symbol [Symbol] The form's key in @forms.
  # @param key [Symbol, nil] The field to put the focus on, nil for the first.
  def enter_form(symbol, key = nil)
    @form_symbol = symbol
    @field_key = key
    @place = :form
    log_screen("opened the form #{symbol}")
    resume_form
  end

  # Moves into the form shown as a preview at the right, as confirm or a click on it does.
  def enter_preview
    return if held?("entering a form")

    symbol = current_command
    enter_form(symbol) if @forms[symbol]
  end

  # Puts the focus back on the form's field it was left at, or its first.
  def resume_form
    return unless form

    key = @field_key || (form.fields.first && form.fields.first.key)
    request_focus([:field, key])
  end

  # Moves from the form back to the list, keeping what was filled in, unless it changed a world.
  #
  # @param focus [Boolean] Whether the focus goes to the list, rather than staying where the player
  #   moved it.
  def leave_form(focus = true)
    # Without a name the player cannot be in a world, so the screen closes.
    if name_missing?
      log_screen("closing: the name form was left without a name")
      return return_scene
    end

    log_screen("left the form #{@form_symbol}") if @form_symbol
    world_form = WORLD_FORMS.include?(@form_symbol)
    @limits.close if @limits && @limits.open?
    WORLD_FORMS.each { |symbol| @forms[symbol].close if @forms[symbol] }
    WORLD_FORMS.each { |symbol| @forms.delete(symbol) }
    @form_symbol = nil
    @field_key = nil
    @place = nil
    say(MGQ_MpWorldScreen.text("hint"))
    if focus
      @whole = world_form ? :worlds : :commands
      request_focus(@whole)
    end
    changed
  end

  # Leaves the form the player backed out of; backing out of the password of the world the game
  # started again for ends that entry, which the DLL decides.
  #
  # @param focus [Boolean] Whether the focus goes to the list, rather than staying where the player
  #   moved it.
  def on_form_cancel(focus = true)
    password = @form_symbol == :password
    leave_form(focus)
    answer("password_back") if password
  end

  # Puts the cursor back on the form after the save screen, at the field it left from.
  def return_to_form
    at = COMMANDS.index { |_text, symbol| symbol == @form_symbol }
    @command_index = at if at
    enter_form(@form_symbol, @field_key) unless @busy
  end

  # Notes the field that took the focus, which the form goes back to.
  #
  # @param page [MGQ_MpWorld::WorldForm] The form, or its page of the limits.
  # @param field [MGQ_MpWorld::Form::Field] The field.
  def field_focused(page, field)
    @place = :form
    @field_key = field.key if page.equal?(form)
  end

  # Takes a text typed into a field, which goes over to the DLL.
  #
  # @param page [MGQ_MpWorld::WorldForm] The form, or its page of the limits.
  # @param field [MGQ_MpWorld::Form::Field] The field.
  # @param text [String] What it holds.
  def typed(page, field, text)
    field_focused(page, field)
    page[field.key] = text.to_s
  end

  # Checks the text Enter gave: a refusal buzzes and says why, the focus staying; a text taken sends
  # the form where Enter sends it, else moves the focus to the field below.
  #
  # @param page [MGQ_MpWorld::WorldForm] The form, or its page of the limits.
  # @param field [MGQ_MpWorld::Form::Field] The text box.
  # @param text [String] The text.
  def submitted(page, field, text)
    return if held?("Enter in #{field.label}")

    field_focused(page, field)
    checked, error = page.check(field, text.to_s)
    if error
      log_screen("#{field.label} refused: #{error}")
      return refuse(error)
    end

    page[field.key] = checked
    changed
    Sound.play_ok
    return send_form if page.equal?(form) && page.sends_on_enter?

    below = page.fields.find { |candidate| candidate.row > field.row }
    request_focus([:field, below.key]) if below
  end

  # Ticks a checkbox, or unticks it, and shows the form anew from the DLL's view.
  #
  # @param page [MGQ_MpWorld::WorldForm] The form, or its page of the limits.
  # @param field [MGQ_MpWorld::Form::Field] The checkbox.
  def ticked(page, field)
    return if held?("ticking #{field.label}")

    field_focused(page, field)
    page.tick(field.key)
    log_screen("#{page[field.key] ? 'ticked' : 'unticked'} #{field.label} in the form #{@form_symbol}")
    changed
  end

  # Turns a switch to the outcome picked, and shows the form anew from the DLL's view.
  #
  # @param page [MGQ_MpWorld::WorldForm] The form, or its page of the limits.
  # @param field [MGQ_MpWorld::Form::Field] The switch.
  # @param index [Integer] The outcome picked.
  def turned(page, field, index)
    return if held?("turning #{field.label}")

    field_focused(page, field)
    before = page[field.key].to_i
    step = index.to_i - before
    return if step == 0

    page.turn(field, step)
    log_screen("#{field.label}: \"#{field.choices[before]}\" -> \"#{field.choices[page[field.key].to_i]}\" in the form #{@form_symbol}")
    changed
  end

  # Acts on a form's button: opens or closes the formation limits, or sends the form.
  #
  # @param field [MGQ_MpWorld::Form::Field] The button.
  def pressed(field)
    return if held?("pressing #{field.label}")

    case field.key
    when :limits then open_limits
    when :done then @limits.close if @limits
    else send_form
    end
  end

  # Opens the formation limits of a Raid World over the form, which keeps whatever they change.
  def open_limits
    log_screen("opened the formation limits of the form #{@form_symbol}")
    @limits = UI.open(LimitsDialog, :scene => self, :page => form.limits) { |_result, _why| limits_closed }
  end

  # Goes back from the formation limits to the form, at their button, keeping the limits picked.
  def limits_closed
    @limits = nil
    return if @closing || !form

    log_screen("closed the formation limits: #{MGQ_MpWorld.squad_summary(form.squad)}")
    @field_key = :limits
    resume_form
  end

  # Opens the game's save screen for the new world's starting save.
  def choose_save
    return if held?("choosing a save")

    log_screen("opening the save screen for the new world's starting save")
    MGQ_MpSaveDistribution.choose(:world)
  end

  # Says why something typed or the form is not accepted.
  #
  # @param error [String] Why.
  def refuse(error)
    Sound.play_buzzer
    say(error)
  end

  # Sends the filled-in form, or points at the first field that keeps it from being sent, with why.
  def send_form
    index, error = form.problem

    if error
      field = form.fields[index]
      log_screen("the form #{@form_symbol} was not sent: #{error} (#{field.label})")
      request_focus([:field, field.key])
      return refuse(error)
    end

    log_screen("sending the form #{@form_symbol}")
    case @form_symbol
    when :new_world then create_world
    when :edit_world then play(dll_do("edit", entry_request.merge("fresh" => @list_state == "ready")))
    when :rename then rename_player
    when :password then answer("password", "text" => form[:password].to_s)
    when :join_hidden then play(dll_do("find"))
    end
  end

  # Writes what the save or the mods field shows.
  #
  # @param page [MGQ_MpWorld::WorldForm] The form.
  # @param field [MGQ_MpWorld::Form::Field] The field.
  # @return [String] The text.
  def value_text(page, field)
    value = page[field.key]
    return value.to_s.empty? ? "None. Confirm to pick them." : value.to_s if field.kind == :mods
    return field.optional ? "The beginning" : "Choose one of your saves" if value.nil?

    save_text(value)
  end

  # Names a save by its slot and, when its header tells it, the time played.
  #
  # @param index [Integer] The save's index, as DataManager takes it.
  # @return [String] The text.
  def save_text(index)
    header = DataManager.load_header(index) rescue nil
    played = header.is_a?(Hash) ? header[:playtime_s] : nil
    played ? "Save #{index + 1}  (#{played})" : "Save #{index + 1}"
  end

  # Opens the mod picker over the form: the installed mods and those added by name, as the form
  # names them.
  def open_mod_pick
    return if held?("opening the mod picker")

    @mod_pick = MGQ_MpWorld::ModPick.new(form[:mods])
    @pick_source = MGQ_MpListBox::Source.new(mod_pick_rows, nil)
    log_screen("opened the mod picker on \"#{form[:mods]}\": #{@mod_pick.entries.size} mod(s)")
    @list_box = UI.open(MGQ_MpListBox, :title => MOD_PICK_TITLE, :source => @pick_source, :picker => true, :note_color => :error, :keys => MOD_PICK_KEYS,
                                       :max_length => MGQ_MpWorld::MAX_MODS_CHARS, :typing_help => Scene_MpWorlds.typing_hint,
                                       :on_submit => lambda { |row| act_on_mod(row[:data], 0) }, :on_toggle => lambda { |row, toggle| act_on_mod(row[:data], toggle + 1) },
                                       :on_add => lambda { |name| add_mod(name) }, :on_remove => lambda { |row| remove_added_mod(row[:data]) }) { |_result, _why| close_mod_pick }
  end

  # Tells why the mod picker refused the last change.
  #
  # @return [String, nil] Why, nil while it took the last change or is closed.
  def mod_pick_note
    @pick_source && @mod_pick ? @pick_source.note : nil
  end

  # Writes the mod picker's rows, each item's row with the item as its :data.
  #
  # @return [Array<Hash>] The rows.
  def mod_pick_rows
    mod_pick_items.map { |item| item.is_a?(String) ? mod_pick_row(item) : mod_pick_row(item).merge(:data => item) }
  end

  # Lists what the mod picker shows: the item that lists or unlists every installed mod, the
  # installed mods, the added ones, each under its heading, then the item that adds one.
  #
  # @return [Array] The items: :all, a heading's text, a mod's index in the picker's entries, :add.
  def mod_pick_items
    entries = @mod_pick ? @mod_pick.entries : []
    items = [:all]
    [["Your mods", true], ["Added by name", false]].each do |heading, installed|
      group = (0...entries.size).select { |index| entries[index].installed == installed }
      next if group.empty? && !installed

      items << "#{heading} (#{group.size})"
      items.concat(group)
    end
    items << :add
  end

  # Writes a row of the mod picker: a mod with its red ! toggle for required and its orange ? toggle
  # for essential, removable when added by name, a heading, or the rows that list every mod and
  # open the Name field.
  #
  # @param item [Object] See mod_pick_items.
  # @return [Hash] The row.
  def mod_pick_row(item)
    return { :heading => item } if item.is_a?(String)
    return { :text => @mod_pick.all_listed? ? "Unlist all your mods" : "List all your mods" } if item == :all
    return { :text => "Add a mod by name . . .", :name_field => true } if item == :add

    entry = @mod_pick.entries[item]
    row = { :text => entry.name, :right => entry.label, :removable => !entry.installed,
            :toggles => [{ :text => "!", :color => :error, :on => entry.state == :required, :tooltip => "Required" },
                         { :text => "?", :color => :warning, :on => entry.state == :essential, :tooltip => "Essential" }] }
    color = MOD_PICK_COLORS[entry.color]
    row[:color] = color if color
    row
  end

  # Tells whether an item of the mod picker is a mod added by name, which Remove takes out.
  #
  # @param item [Object] See mod_pick_items.
  # @return [Boolean] Whether it is.
  def added_mod?(item)
    item.is_a?(Integer) && @mod_pick && @mod_pick.entries[item] && !@mod_pick.entries[item].installed ? true : false
  end

  # Acts on what the mod picker points at: lists or unlists a mod, makes it required or essential
  # with its toggles, or lists or unlists every installed mod.
  #
  # @param item [Object] See mod_pick_items.
  # @param column [Integer] 0 for the mod's name, 1 for its required toggle, 2 for its essential one.
  def act_on_mod(item, column)
    return unless @mod_pick && (item == :all || item.is_a?(Integer))

    entry = item.is_a?(Integer) ? @mod_pick.entries[item] : nil
    before = entry && entry.state
    error = if item == :all
              @mod_pick.all_listed? ? @mod_pick.unlist_all : @mod_pick.list_all
            elsif column == 0
              @mod_pick.toggle(item)
            else
              @mod_pick.mark(item, column == 1 ? :required : :essential)
            end
    change = entry ? "#{entry.name} #{before} -> #{entry.state}" : "every installed mod #{@mod_pick.all_listed? ? 'listed' : 'unlisted'}"
    log_screen("mod picker: #{change}#{error ? ", refused: #{error}" : ''}")
    picked(error)
  end

  # Adds a mod by the name typed, or says why it cannot be.
  #
  # @param name [String] The name.
  # @return [Boolean] Whether it was added.
  def add_mod(name)
    return false unless @mod_pick

    error = @mod_pick.add(name)
    log_screen(error ? "mod picker: #{name} not added: #{error}" : "mod picker: added #{name} by name")
    picked(error)
    error.nil?
  end

  # Takes a mod added by name out of the picker and the form.
  #
  # @param item [Object] See mod_pick_items.
  def remove_added_mod(item)
    return Sound.play_buzzer unless added_mod?(item)

    name = @mod_pick.entries[item].name
    return unless @mod_pick.remove(item)

    log_screen("mod picker: removed #{name}, added by name")
    picked(nil, false)
    Sound.play_cancel
  end

  # Shows the mod picker anew and the form's mods with it, with the OK sound for a change it took or
  # the buzzer and why for one it refused.
  #
  # @param error [String, nil] Why the change was refused, nil when it was taken.
  # @param sound [Boolean] Whether it plays the sound of a change taken.
  def picked(error, sound = true)
    form[:mods] = @mod_pick.text if form
    @pick_source.rows = mod_pick_rows
    @pick_source.note = error
    changed
    error ? Sound.play_buzzer : (Sound.play_ok if sound)
  end

  # Closes the mod picker, back to the form, which shows the mods picked.
  def close_mod_pick
    return unless @mod_pick

    log_screen("closed the mod picker: \"#{form && form[:mods]}\"")
    @mod_pick.close
    @mod_pick = nil
    @list_box = nil
    @field_key = :mods
    resume_form unless @closing
  end

  # Opens the form that changes the chosen world, filled in as the world is, once its mods were read.
  def on_edit_world
    return play(dll_do("read_for_edit", entry_request)) if @entry.listed.mods_unread

    log_screen("editing #{entry_text}#{@entry.listed.creator_id == @me ? ' as its creator' : ' as an admin'}")
    close_popups
    @forms[:edit_world] = MGQ_MpWorld::WorldForm.edit(:edit_world, @entry.listed, @entry.listed.creator_id == @me)
    enter_form(:edit_world)
  end

  # Takes the save picked on the save screen: as the new world's starting save, or as where the
  # player starts in the world they are entering, which the DLL's steps then copy or ask about
  # again. Called as the world screen starts again.
  def take_start_save
    purpose, index = MGQ_MpSaveDistribution.take_chosen
    return unless purpose

    if purpose == :world
      log_screen(index ? "picked #{MGQ_MpWorld.save_name(index)} as the new world's starting save" : "left the save screen without a starting save")
      @forms[:new_world][:save] = index if index
    else
      answer("own_save", "index" => index)
    end
  end

  # Has the DLL make the world the form describes, with the files of its starting save, which
  # only this game can name.
  def create_world
    values = @forms[:new_world]
    files = values.from_save? && values[:save] ? MGQ_MpSaveDistribution.files_of(values[:save]) : []
    play(dll_do("create", "start" => files))
  end

  # Opens a fresh form in a slot, for the next world after one was made or added.
  #
  # @param slot [String] The slot, such as "new_world".
  # @return [MGQ_MpWorld::WorldForm] The form.
  def fresh_form(slot)
    slot == "join_hidden" ? MGQ_MpWorld::WorldForm.join(:join_hidden) : MGQ_MpWorld::WorldForm.create(:new_world)
  end

  # Holds the screen while an action of the DLL runs, and says what it waits for.
  #
  # @param kind [String] The action's kind.
  def hold_for(kind)
    close_popups
    @busy = kind
    say(MGQ_MpWorldScreen.busy_text(kind))
    changed
  end

  # Frees the screen once the DLL's action ended, and gives the focus back to where it was.
  def free_screen
    @busy = nil
    changed
    refocus
  end

  # Puts the focus back where the player left it: the form entered, else the worlds' or the
  # commands' rows, or their box as a whole.
  def refocus
    return resume_form if form

    request_focus(@place == @whole ? @whole : :"#{@whole}_box")
  end

  # Notes the player's save to copy into the world they are entering, which update copies once the
  # world screen is back, since entering loads the map, which must not happen while it starts.
  #
  # @param world [MGQ_MpWorld::World] The world.
  # @param index [Integer] The save's index.
  def own_start(world, index)
    @own_start = [world, index]
  end

  # Copies the save picked on the save screen into the world the player is entering, and tells the
  # DLL how it went. Called by update once the world screen is back.
  def start_from_own
    world, index = @own_start
    @own_start = nil
    copied = MGQ_MpSaveDistribution.place(world, MGQ_MpSaveDistribution.files_of(index))
    log_screen("own #{MGQ_MpWorld.save_name(index)} #{copied ? 'copied' : 'could not be copied'} into #{world.name}")
    answer("own_copied", "ok" => copied ? true : false)
  end

  # Enters a world from its latest save, or at the beginning without one, and tells the DLL why not
  # when it cannot.
  #
  # @param world [MGQ_MpWorld::World] The world.
  # @param placed [Boolean] Whether its save was just placed there, which is checked first.
  # @param listed [Hash, nil] The world as the list holds it now, whose mods and settings apply; nil
  #   when the list lacks it.
  # @param fresh [Boolean] Whether the list had arrived as the world began to open.
  def start_world(world, placed, listed, fresh)
    error = placed && MGQ_MpSaveDistribution.check(world)
    unless error
      known = listed.is_a?(Hash) ? MGQ_MpWorldScreen.listed_of(listed) : nil
      MGQ_MpWorld::Directory.open(known.id) if known
      MGQ_MpWorldMods.enter_world(known, @me, fresh ? true : false)
      MGQ_MpWorldMods.note_session(known)
      error = MGQ_MpWorld.start(world, self)
      MGQ_MpWorldMods.forget_world if error
    end
    answer("start_failed", "text" => error.to_s, "placed" => placed ? true : false) if error
  end

  # The world screen's window: the lines at the top, the boxes of the search and filters, the worlds
  # and the commands the keys stop on as a whole first, and at the right a world's details or a form.
  class WorldScreen < UI::Component
    # The scene, which keeps what the screen shows.
    param :scene

    # The row the worlds' cursor is on.
    state(:world_index) { scene.world_index }

    # The row the commands' cursor is on.
    state(:command_index) { scene.command_index }

    # What the search holds.
    state(:search) { scene.search }

    # The type filter on.
    state(:type_filter) { scene.type_filter }

    # The players online filter's values on: its own while it is on.
    state(:online_filter) { scene.online_filter ? [:online] : [] }

    watch { scene.serial }
    watch { follow_scene }

    # Describes the screen.
    def render
      window nil, id: ROOT_ID, width: :screen, height: :screen, frame: false, movable: false, on_cancel: -> { scene.cancelled; false } do
        paper id: :mgq_online_world_screen_strip, height: STRIP_HEIGHT do
          lines = scene.strip_lines
          text lines[0], typo: :body2, most_lines: 1
          help_line id: :mgq_online_world_screen_help, lines: 1
          text(lines[1], typo: :body2, most_lines: 1, color: :dim) unless lines[1].empty?
        end
        stack row: true, height: Graphics.height - STRIP_HEIGHT - STRIP_GAP do
          stack width: LEFT_WIDTH do
            paper enter: true, id: :mgq_online_world_filters_box, help: FILTERS_HELP,
                  on_enter: -> { scene.entered(:filters) }, on_leave: -> { scene.left(:filters) } do
              filters
            end
            paper enter: true, id: :mgq_online_worlds_box, height: :fill, help: MGQ_MpWorldScreen.text("enter_hint"),
                  on_enter: -> { scene.entered(:worlds) }, on_leave: -> { scene.left(:worlds) } do
              list scene.entries, id: :mgq_online_worlds, bind_index: :world_index, rows_shown: :fill, height: :fill, autofocus: true, empty: scene.list_empty,
                                  row: ->(entry) { scene.world_row(entry) }, on_change: ->(entry) { scene.pointed_world(entry) }, on_submit: ->(entry) { scene.on_world(entry) }
            end
            paper enter: true, id: :mgq_online_commands_box, help: MGQ_MpWorldScreen.text("hint"),
                  on_enter: -> { scene.entered(:commands) }, on_leave: -> { scene.left(:commands) } do
              list COMMANDS, id: :mgq_online_commands, bind_index: :command_index, text: ->(command) { command[0] },
                             on_change: ->(command) { scene.pointed_command(command) }, on_submit: ->(command) { scene.on_command(command) }
            end
          end
          kind, target = scene.right_view
          # A preview makes the box itself the part a click or confirm presses, so the form has the
          # room it has once entered, which a framed box inside would cut.
          preview = kind == :preview ? { clickable: true, on_click: -> { scene.enter_preview } } : {}
          paper({ id: :mgq_online_right_box, grow: 1, key: preview.empty? ? :box : :preview }.merge(preview)) do
            case kind
            when :world then details(target)
            when :form, :preview then component(WorldFormView, scene: scene, page: scene.forms[target], key: [kind, target, scene.forms[target].object_id])
            end
          end
        end
      end
    end

    private

    # Describes the search in its box above the worlds, its caption beside it, then the filters of
    # the worlds' type and players online side by side; the DLL matches the worlds against them.
    def filters
      field SEARCH_CAPTION, caption_width: [SEARCH_CAPTION] do
        text_field bind: :search, id: :mgq_online_world_search, placeholder: SEARCH_PLACEHOLDER, max_length: SEARCH_CHARS, help: SEARCH_HELP,
                   typing_help: Scene_MpWorlds.typing_hint, on_change: ->(text) { scene.searched(text) }, on_submit: ->(_text) { scene.search_done }
      end
      stack row: true, spacing: 1 do
        toggle_group bind: :type_filter, id: :mgq_online_world_type, help: TYPE_HELP, on_change: ->(type) { scene.type_turned(type) } do
          TYPE_FILTERS.each { |text, value, tip| toggle_item text, value: value, tooltip: tip, key: value }
        end
        toggle_group bind: :online_filter, id: :mgq_online_world_online, multi: true, help: ONLINE_HELP, on_change: ->(values) { scene.online_turned(values) } do
          toggle_item ONLINE_FILTER[0], value: :online, tooltip: ONLINE_FILTER[1]
        end
      end
    end

    # Describes a world's details as the DLL tells them: its name with when the player played it
    # last, the panels of plated values, then at the foot the panels of lines beside the
    # description, at one height and place for every world. A panel with a target is one part the
    # player presses to open the list box with it.
    #
    # @param entry [MGQ_MpWorld::Entry] The world.
    def details(entry)
      about = MGQ_MpWorldScreen.details(entry)
      return unless about

      panels = Array(about["panels"])
      beside = panels.select { |panel| panel["lines"] }
      captions = Array(about["captions"])
      stack spacing: 1, key: :facts do
        stack row: true do
          text about["title"].to_s, color: ROW_COLORS[about["title_color"]] || :system, grow: 1, most_lines: 1
          text about["played"].to_s, typo: :caption, color: :dim
        end
        (panels - beside).each_with_index { |panel, index| panel_of(panel, index, captions) }
      end
      return if beside.empty? && !about["description"]

      stack row: true, height: :fill, key: :rest do
        beside.each_with_index { |panel, index| lines_panel_of(panel, index) }
        description_of(about["description"].to_s) if about["description"]
      end
    end

    # Describes a panel of a world's details: its title with its note, and its rows of one or two
    # cells, pressed as one boxed part at its least height where it opens something, such as the
    # world's facts in full.
    #
    # @param panel [Hash] The panel, as screen.details tells it.
    # @param index [Integer] Its place among the panels.
    # @param captions [Array<Array<String>>] Every caption the details can show by column, whose widest sets that column's width.
    def panel_of(panel, index, captions)
      target = panel["target"]
      group panel["title"].to_s, { size: :tiny, dense: true, key: index }.merge(panel["note"] ? { note: panel["note"].to_s } : {}) do
        if target
          paper(area_of(true, id: :"mgq_online_details_#{panel['title'].to_s.downcase.tr(' ', '_')}", help: PANEL_HELPS[target],
                        min_size: [0, BOX_HEIGHTS.fetch(target, 0)], on_click: -> { scene.open_target(target.to_sym) })) { rows_of_panel(panel, captions) }
        else
          rows_of_panel(panel, captions)
        end
      end
    end

    # Describes the rows of a panel of a world's details, each of one or two cells.
    #
    # @param panel [Hash] The panel, as screen.details tells it.
    # @param captions [Array<Array<String>>] Every caption the details can show by column, whose widest sets that column's width.
    def rows_of_panel(panel, captions)
      stack spacing: ROW_SPACING do
        Array(panel["rows"]).each_with_index do |cells, row|
          stack(row: true, key: row) { cells.each_with_index { |cell, column| cell_of(cell, column, captions) } }
        end
      end
    end

    # Describes a panel of a world's details whose rows are lines, such as its players, narrow
    # beside the description: as many as the room left holds, the last telling how many more there
    # are, pressed as one boxed part where it opens something.
    #
    # @param panel [Hash] The panel, as screen.details tells it.
    # @param index [Integer] Its place among such panels.
    def lines_panel_of(panel, index)
      target = panel["target"]
      shown = Array(panel["rows"]).map do |cells|
        color = CELL_COLORS[cells[0]["color"]]
        { text: cells[0]["text"].to_s }.merge(color ? { color: color } : {})
      end
      group panel["title"].to_s, { size: :tiny, dense: true, key: [:lines, index], width: PLAYERS_WIDTH }.merge(panel["note"] ? { note: panel["note"].to_s } : {}) do
        paper(area_of(!target.nil?, { height: :fill, on_click: target ? -> { scene.open_target(target.to_sym) } : nil }.merge(target ? { id: :"mgq_online_details_#{target}" } : {}))) do
          lines shown, size: :small, height: :fill
        end
      end
    end

    # Describes a cell of a world's details in its column: its caption at the column's caption width
    # and its value on a plate, cut with ... and whole in its tooltip where it is too long, or its
    # values as chips; an empty cell keeps its half.
    #
    # @param cell [Hash, nil] The cell, as screen.details tells it.
    # @param column [Integer] Its place in its row.
    # @param captions [Array<Array<String>>] Every caption the details can show by column, whose widest sets that column's width.
    def cell_of(cell, column, captions)
      return stack(DETAIL_CELL.merge(key: column)) {} unless cell

      color = CELL_COLORS[cell["color"]]
      if cell["chips"]
        colors = Hash[Array(cell["chip_colors"]).to_a]
        chip_set DETAIL_CELL.merge(key: column) do
          Array(cell["chips"]).each do |name|
            chip_color = CELL_COLORS[colors[name] || cell["color"]]
            chip name.to_s, { key: name }.merge(chip_color ? { color: chip_color } : {})
          end
        end
      else
        field cell["label"].to_s, DETAIL_CELL.merge(caption_width: captions[column], plate: true, key: column) do
          text cell["text"].to_s, { wrap: true, most_lines: 1 }.merge(color ? { color: color } : {})
        end
      end
    end

    # Describes the description, which takes the rest of the room, in lines of the small font's
    # height, its last line cut when it does not all fit; the player presses its box to read it whole
    # in the list box. A text that keeps as many lines as its room holds measures as one line, so it
    # takes the box's whole height.
    #
    # @param description [String] The description, empty for none.
    def description_of(description)
      group DESCRIPTION_TITLE, size: :tiny, dense: true, width: 0, grow: 1 do
        paper area_of(!description.empty?, id: :mgq_online_details_description, height: :fill,
                      on_click: description.empty? ? nil : -> { scene.open_target(:description) }) do
          text description.empty? ? NO_DESCRIPTION : description,
               { wrap: true, most_lines: :fill, height: :fill, typo: :body2, line_height: UI::SMALL_LINE_HEIGHT }.merge(description.empty? ? { color: :dim } : {})
        end
      end
    end

    # Tells how a part of the details draws: as a thin box the player presses where it opens
    # something, else without a box.
    #
    # @param pressed [Boolean] Whether it opens something.
    # @param params [Hash] Its own params.
    # @return [Hash] Its params.
    def area_of(pressed, params)
      PRESSED_AREA.merge(pressed ? {} : PLAIN_AREA).merge(params)
    end

    # Follows what the scene asks of the window: the cursors it moved, the search and the filters it
    # cleared, the focus it wants and what the lines at the top say, the focus first, as a text said
    # keeps until the focus moves.
    #
    # @return [Array] What it followed.
    def follow_scene
      self.world_index = scene.world_index unless world_index == scene.world_index
      self.command_index = scene.command_index unless command_index == scene.command_index
      self.search = scene.search unless search == scene.search
      self.type_filter = scene.type_filter unless type_filter == scene.type_filter
      online = scene.online_filter ? [:online] : []
      self.online_filter = online unless online_filter == online
      request = scene.focus_request
      if request && request[1] != @focused && request[0].is_a?(Symbol)
        part(:"mgq_online_#{request[0]}").focus
        @focused = request[1]
      end
      said = scene.said
      if said && said[1] != @told
        part(:mgq_online_world_screen_help).say(said[0])
        @told = said[1]
      end
      [request, said]
    end
  end

  # A form at the right from the DLL's view, or its page of the formation limits: its title, its
  # first group across with one or two fields to a row, the groups after it side by side with a
  # field to a line, and the fields of no group last.
  class WorldFormView < UI::Component
    # The scene, which keeps the forms.
    param :scene

    # The form, or its page of the limits.
    param :page

    # Whether it shows its title, which the limits' dialog shows instead.
    param :titled, true

    watch { scene.serial }

    # Describes the form.
    def render
      stack grow: 1, spacing: 1 do
        fields_of
      end
    end

    private

    # Describes the title and the fields: the first group across, the groups after it side by side
    # in one row, so the form fits the right box without scrolling, and the fields of no group after
    # the last group.
    def fields_of
      text(page.title, color: :system) if titled
      fields = page.fields
      groups = fields.map { |field| field.group }.compact.uniq
      loose = fields.select { |field| field.group.nil? }
      if groups.first
        group(groups.first, size: :tiny, key: groups.first) { stack(spacing: ROW_SPACING) { rows_of(fields.select { |field| field.group == groups.first }) } }
      end
      return rows_of(loose) if groups.size < 2

      stack row: true, key: :beside do
        groups.drop(1).each do |name|
          stack width: 0, grow: 1, spacing: 1, key: name do
            group(name, size: :tiny) { lines_of(fields.select { |field| field.group == name }) }
            lines_of(loose) if name == groups.last && !loose.empty?
          end
        end
      end
    end

    # Describes the rows of a group's fields as the DLL sets them, one or two to a row in halves of
    # equal width, a lone field on its side.
    #
    # @param fields [Array<MGQ_MpWorld::Form::Field>] The fields.
    def rows_of(fields)
      fields.map { |field| field.row }.uniq.each do |row|
        on_row = fields.select { |field| field.row == row }
        stack row: true, key: row do
          stack(width: 0, grow: 1) {} if on_row.size == 1 && on_row[0].side == :right
          on_row.each { |field| component(FormField, scene: scene, page: page, input_field: field, key: [field.key, field.kind], width: 0, grow: 1) }
          stack(width: 0, grow: 1) {} if on_row.size == 1 && on_row[0].side == :left
        end
      end
    end

    # Describes fields one to a line, as in a group beside another.
    #
    # @param fields [Array<MGQ_MpWorld::Form::Field>] The fields.
    def lines_of(fields)
      stack spacing: ROW_SPACING do
        fields.each { |field| component(FormField, scene: scene, page: page, input_field: field, key: [field.key, field.kind]) }
      end
    end
  end

  # A field of a form: a text box, a password shown as stars, a number, a box of several lines, a
  # checkbox, a switch, the save to start from, the mods, or a button, its caption beside it where
  # it has no label of its own, above it for the save and the mods. It takes the focus as the scene
  # asks.
  class FormField < UI::Component
    # The scene, which hands the field's changes to the form.
    param :scene

    # The form, or its page of the limits.
    param :page

    # The field.
    param :input_field

    # What the field holds: its text, number, tick or outcome.
    state(:value) { FormField.value_of(page, input_field) }

    watch { follow_page }
    watch { follow_focus }

    # Reads what a field holds as its part takes it.
    #
    # @param page [MGQ_MpWorld::WorldForm] The form.
    # @param input_field [MGQ_MpWorld::Form::Field] The field.
    # @return [Object] A text, a number, true or false, or an outcome's index.
    def self.value_of(page, input_field)
      value = page[input_field.key]
      case input_field.kind
      when :number then value.to_s =~ /\A\d+\z/ ? value.to_i : input_field.min.to_i
      when :check then value ? true : false
      when :switch then input_field.choices.size == 2 ? value.to_i == 1 : value.to_i
      else value.to_s
      end
    end

    # Describes the field.
    def render
      @rendered_id = field_id
      common = { id: @rendered_id, help: input_field.hint, disabled: !page.enabled?(input_field) }
      case input_field.kind
      when :text, :password, :id
        captioned do
          text_field common.merge(bind: :value, password: input_field.kind == :password, max_length: input_field.max_chars, allowed: input_field.allowed,
                                  leave_sides: true, typing_help: Scene_MpWorlds.typing_hint, on_change: ->(text) { scene.typed(page, input_field, text) },
                                  on_submit: ->(text) { scene.submitted(page, input_field, text) })
        end
      when :number
        captioned do
          numeric_field common.merge(bind: :value, min: input_field.min, max: input_field.max, on_change: ->(number) { scene.typed(page, input_field, number.to_s) },
                                     on_submit: ->(number) { scene.submitted(page, input_field, number.to_s) })
        end
      when :area
        text_field common.merge(bind: :value, lines: input_field.lines, max_length: input_field.max_chars, placeholder: input_field.label, typing_help: Scene_MpWorlds.typing_hint,
                                on_change: ->(text) { scene.typed(page, input_field, text) }, on_submit: ->(text) { scene.submitted(page, input_field, text) })
      when :check
        checkbox input_field.label, common.merge(bind: :value, on_change: ->(_on) { scene.ticked(page, input_field) })
      when :switch
        switch_of(common)
      when :save, :mods
        captioned_above do
          button scene.value_text(page, input_field), common.merge(variant: :outlined, on_click: -> { input_field.kind == :save ? scene.choose_save : scene.open_mod_pick })
        end
      when :button
        button input_field.label, common.merge(variant: :filled, on_click: -> { scene.pressed(input_field) })
      end
    end

    private

    # Names the field's part.
    #
    # @return [Symbol] Its id.
    def field_id
      :"mgq_online_form_#{page.equal?(scene.form) ? 'main' : 'limits'}_#{input_field.key}"
    end

    # Describes a switch: of two outcomes a switch that Left and Right turn, of more a select of them
    # with its caption beside it.
    #
    # @param common [Hash] The params every field takes.
    def switch_of(common)
      choices = input_field.choices
      if choices.size == 2
        switch input_field.label, common.merge(bind: :value, values: choices, on_change: ->(on) { scene.turned(page, input_field, on ? 1 : 0) })
      else
        captioned do
          select common.merge(bind: :value, on_change: ->(index) { scene.turned(page, input_field, index) if index }) do
            choices.each_with_index { |choice, index| select_item choice, value: index, key: index }
          end
        end
      end
    end

    # Describes the field's caption with its value beside it, as a field whose label would take a
    # row of its own above it. A narrow caption lines up with the page's other narrow captions at
    # the widest of them, so the value gets the room; the others line up at FORM_CAPTION's width.
    def captioned(&value)
      label = input_field.label
      captions = input_field.narrow_caption ? page.fields.select { |field| field.narrow_caption }.map { |field| field.label } : [label, Scene_MpWorlds::FORM_CAPTION]
      field label, caption_width: captions, &value
    end

    # Describes the field's caption above its value, which takes the field's whole width, as the
    # save's and the mods' buttons show names that a caption beside them would cut.
    def captioned_above(&value)
      group input_field.label, size: :small, spacing: 0, &value
    end

    # Keeps what the field holds on the form's value, which the DLL may change, such as a text it
    # tidied or a switch another field follows.
    #
    # @return [Object] The form's value.
    def follow_page
      wanted = FormField.value_of(page, input_field)
      self.value = wanted unless value == wanted
      wanted
    end

    # Takes the focus once the scene asks for this field and the field's last render made its part
    # under the id it has now.
    #
    # A preview's field turning into the form's changes its id before it renders again.
    #
    # @return [Array, nil] The scene's ask.
    def follow_focus
      request = scene.focus_request
      if request && request[1] != @focused && request[0] == [:field, input_field.key] && page.equal?(scene.form) && @rendered_id == field_id
        part(@rendered_id).focus
        @focused = request[1]
      end
      request
    end
  end

  # The formation limits of a Raid World, in a dialog over the screen: its page of the form, which
  # keeps whatever they change; Done and cancel close it.
  class LimitsDialog < UI::Component
    # The scene, which keeps the form.
    param :scene

    # The form's page of the limits.
    param :page

    # Describes the dialog.
    def render
      dialog LIMITS_TITLE, id: :mgq_online_world_limits, width: 420 do
        component(WorldFormView, scene: scene, page: page, titled: false)
      end
    end
  end
end
