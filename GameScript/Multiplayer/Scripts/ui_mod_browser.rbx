#----------------------------------------------------------------
#  ui_mod_browser.rbx
#
#  Changelog:
#      Paulinchen  2026-10-24: Showed the mods as cards with screenshots and each on a page of its own
#                            - Showed the mods as a list too and filtered them by a search typed in the bar
#                            - Picked the bar or the mods as a whole before moving inside them
#                            - Told in a box how a change goes and named what changed in the restart question
#                            - Created
#
#----------------------------------------------------------------

# The Mods screen, opened from the title screen's Mods command below Multiplayer, laid out like the
# website's mod browser: a bar at the top with Update all, and every mod of the website and of the
# relay's catalog as a card with its screenshot, those with an update first. A card opens the mod's
# page. The DLL fetches the lists and the screenshots, finds which mods and versions are in Patch,
# and installs, updates and removes them; this script only shows what it tells and passes on what
# the player picks. The title command counts the updates waiting.
module MGQ_MpModBrowser
  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "mods screen"

  # The title screen's command.
  COMMAND_NAME = "Mods"

  # The title screen's command while updates wait, their number filled in.
  COMMAND_COUNT_NAME = "Mods (%d)"

  # The title command's symbol.
  COMMAND_SYMBOL = :mgq_mp_mods

  # Bytes of the buffer the list is read into at first; the DLL asks for a larger one when needed.
  LIST_SIZE = 65536

  # Frames between two looks at the list the DLL holds, a third of a second at 60 frames per second.
  LOOK_FRAMES = 20

  # The Player.ini setting that keeps how the Mods screen shows the mods.
  VIEW_SETTING = "mod_browser_view"

  # How the Mods screen shows the mods, as cards or as a list, the first the default.
  VIEWS = ["cards", "list"]

  # The list the DLL holds.
  #
  # @!attribute state [String] "idle", "loading", "ready" or "failed".
  # @!attribute error [String, nil] Why a source could not be read, nil when both were.
  # @!attribute updates [Integer] How many mods have an update.
  # @!attribute action [String] "idle", "busy", "done" or "failed".
  # @!attribute action_error [String, nil] Why the last change failed.
  # @!attribute done [String, nil] What the last change did.
  # @!attribute restart [Boolean] Whether a change since the game started needs a restart to load.
  # @!attribute mods [Array<Mod>] The mods, those with an update first.
  # @!attribute loading_details [String, nil] The id of the mod whose description is being fetched.
  List = Struct.new(:state, :error, :updates, :action, :action_error, :done, :restart, :mods, :loading_details)

  # A mod of the list.
  #
  # @!attribute id [String] The DLL's id of it, such as "site:party-sheet".
  # @!attribute name [String] Its name.
  # @!attribute author [String] Who made it, empty when unknown.
  # @!attribute status [String] "update", "changed", "current" or "available".
  # @!attribute installed [String] The version in Patch, empty for none or a changed copy.
  # @!attribute latest [String] The newest version.
  # @!attribute source [String] "site", "github" or "relay".
  # @!attribute page [String] Its page, empty for none.
  # @!attribute files [Integer] How many files the newest version has.
  # @!attribute bytes [Integer] The download's size, 0 when unknown.
  # @!attribute summary [String] What it does in a line.
  # @!attribute thumbnail [String] Its screenshot's file relative to the game folder, empty for none yet.
  # @!attribute spoiler [Boolean] Whether the screenshot shows a spoiler, blurred on its card.
  # @!attribute notes [Array<String>] The newest version's changelog, a line each.
  # @!attribute description [Array<String>] Its description, a paragraph each, empty until fetched.
  Mod = Struct.new(:id, :name, :author, :status, :installed, :latest, :source, :page, :files, :bytes, :summary, :thumbnail, :spoiler, :notes, :description)

  # The list before the DLL told one.
  EMPTY = List.new("idle", nil, 0, "idle", nil, nil, false, [], nil)

  # Whether the lists were fetched since the game started.
  @refreshed = false

  # The list read last, and the text it was read from.
  @list = EMPTY
  @text = nil

  # Frames since the title screen last looked at the list.
  @title_frames = 0

  # Has the DLL fetch both lists again and look at Patch, unless it does already.
  #
  # @param why [String] What asked, for the log.
  def self.refresh(why)
    started = MGQ_Multiplayer::Link.function('mp_mod_browser_refresh').call == 1
    @refreshed = true
    log(started ? "fetching the mod lists: #{why}" : "the mod lists are being fetched already: #{why}")
  end

  # Has the DLL fetch a website mod's description, unless it knows it.
  #
  # @param mod [Mod] The mod.
  def self.fetch_description(mod)
    return unless mod.source == "site" && mod.description.empty?

    started = MGQ_Multiplayer::Link.function('mp_mod_browser_details').call(mod.id + "\0") == 1
    log(started ? "fetching the description of #{mod.name}" : "could not fetch the description of #{mod.name}")
  end

  # Reads the list the DLL holds.
  #
  # @return [List] The list, the one read last while it did not change.
  def self.list
    text = MGQ_Multiplayer::Link.read('mp_mod_browser_list', LIST_SIZE)
    return @list if text == @text

    @text = text
    @list = parse(text)
    log_list(@list)
    @list
  end

  # Reads a list as the DLL writes it.
  #
  # @param text [String] The DLL's text.
  # @return [List] The list.
  def self.parse(text)
    state = MGQ_Multiplayer::Link.parse(text.to_s)
    mods = []
    by_id = {}

    state[:payload].to_s.split("\n").each do |line|
      fields = line.split("\t", -1)
      case fields[0]
      when "mod"
        next if fields.size < 12

        mod = Mod.new(*fields[1, 11])
        mod.files = mod.files.to_i
        mod.bytes = mod.bytes.to_i
        mod.thumbnail = fields[12].to_s
        mod.spoiler = fields[13] == "1"
        mod.notes = []
        mod.description = []
        mods << mod
        by_id[mod.id] = mod
      when "note", "desc"
        mod = by_id[fields[1]]
        (fields[0] == "note" ? mod.notes : mod.description) << fields[2].to_s if mod
      end
    end

    List.new(state["state"] || "idle", state["error"], state["updates"].to_i, state["action"] || "idle",
             state["action_error"], state["done"], state["restart"] == "1", mods, state["loading_details"])
  end

  # Logs a list once it changed in more than its mods' order.
  #
  # @param list [List] The list.
  def self.log_list(list)
    counts = Hash.new(0)
    list.mods.each { |mod| counts[mod.status] += 1 }
    seen = [list.state, list.error, list.action, counts]
    return if seen == @logged

    @logged = seen
    statuses = counts.map { |status, count| "#{count} #{status}" }.join(", ")
    log("list #{list.state}#{list.error ? " (#{list.error})" : ''}: #{list.mods.size} mod(s)#{statuses.empty? ? '' : ", #{statuses}"}, change #{list.action}")
  end

  # Has the DLL install, update or remove mods, one change for all.
  #
  # @param changes [Array<Array(Symbol, Mod)>] Each change, :install or :remove, and its mod.
  # @return [Boolean] Whether the change started.
  def self.apply(changes)
    lines = changes.map { |kind, mod| "#{kind}\t#{mod.id}" }.join("\n")
    started = MGQ_Multiplayer::Link.function('mp_mod_browser_apply').call(lines + "\0") == 1
    described = changes.map { |kind, mod| "#{kind} #{mod.name} #{kind == :remove ? mod.installed : mod.latest}" }.join(", ")
    log(started ? "started: #{described}" : "could not start: #{described}")
    started
  end

  # Opens a mod's page in the browser.
  #
  # @param mod [Mod] The mod.
  # @return [Boolean] Whether it opened.
  def self.open_page(mod)
    opened = MGQ_Multiplayer::Link.function('mp_mod_browser_open_page').call(mod.id + "\0") == 1
    log(opened ? "opened the page of #{mod.name}" : "could not open the page of #{mod.name}")
    opened
  end

  # Starts the game again so the changed mods load.
  #
  # @return [Symbol] :restarting when the game closes now to start again, :by_hand under Wine or
  #   Proton, where the player starts it again, :failed when it could not and stays open.
  def self.restart
    case MGQ_Multiplayer::Link.function('mp_restart_game').call
    when 1
      log("starting the game again for the changed mods")
      :restarting
    when 2
      log("the game cannot start itself again under Wine, the player restarts it")
      :by_hand
    else
      log("the game could not start itself again")
      :failed
    end
  end

  # Tells whether mods are parked outside Patch for a world, which a change would mix up.
  #
  # @return [Boolean] Whether they are.
  def self.parked?
    defined?(MGQ_MpModParking) && MGQ_MpModParking.parked? ? true : false
  end

  # Tells how the Mods screen shows the mods, as the player chose last.
  #
  # @return [String] "cards" or "list".
  def self.view
    view = MGQ_Multiplayer::Player.setting(VIEW_SETTING).to_s
    VIEWS.include?(view) ? view : VIEWS[0]
  end

  # Keeps how the Mods screen shows the mods, for every later time it opens.
  #
  # @param view [String] "cards" or "list".
  def self.view=(view)
    MGQ_Multiplayer::Player.store(VIEW_SETTING, view)
    log("the mods show as #{view} from now on")
  end

  # Picks the mods a search finds: those whose name, author, summary or source holds every word of
  # it, whatever the case.
  #
  # @param mods [Array<Mod>] The mods.
  # @param query [String] The search, empty for every mod.
  # @return [Array<Mod>] The mods found, in their order.
  def self.found(mods, query)
    words = query.to_s.downcase.split(" ")
    return mods if words.empty?

    mods.select do |mod|
      text = [mod.name, mod.author, mod.summary, mod.source == "github" ? "GitHub" : mod.source].join(" ").downcase
      words.all? { |word| text.include?(word) }
    end
  end

  # Fetches the lists the first time the title screen opens, so the title command counts the
  # updates.
  def self.on_title_start
    return unless MGQ_Multiplayer.available?

    refresh("the title screen opened") unless @refreshed
    @title_frames = LOOK_FRAMES
  rescue => e
    log("could not fetch the mod lists for the title screen: #{e.class}: #{e.message}")
  end

  # Names the updates waiting in the title command, once the list told how many. Called by the
  # title screen every frame.
  #
  # @param scene [Scene_Title] The title screen.
  def self.on_title_update(scene)
    return unless MGQ_Multiplayer.available?

    @title_frames += 1
    return if @title_frames < LOOK_FRAMES

    @title_frames = 0
    commands = MGQ_MpGame.get(scene, :command_window)
    return unless commands && !commands.disposed?

    entry = MGQ_MpGame.get(commands, :list).find { |command| command[:symbol] == COMMAND_SYMBOL }
    return unless entry && entry[:name] != command_name(list)

    commands.refresh
    log("title command now reads #{command_name(@list)}")
  rescue => e
    log("could not name the updates in the title command: #{e.class}: #{e.message}")
  end

  # Names the title command.
  #
  # @param list [List] The list the DLL holds.
  # @return [String] Its name, with the updates waiting while there are any.
  def self.command_name(list)
    list.updates > 0 ? format(COMMAND_COUNT_NAME, list.updates) : COMMAND_NAME
  end

  # Adds the Mods command to the title screen, below Multiplayer.
  #
  # @param window [Window_TitleCommand] The title screen's commands.
  def self.add_title_command(window)
    return unless MGQ_Multiplayer.available?

    list = MGQ_MpGame.get(window, :list)
    entry = { :name => command_name(@list), :symbol => COMMAND_SYMBOL, :enabled => true, :ext => nil }
    after = list.index { |command| command[:symbol] == :mgq_mp_world } || list.index { |command| command[:symbol] == :continue }
    after ? list.insert(after + 1, entry) : list.push(entry)
  rescue => e
    log("title command failed: #{e.class}: #{e.message}")
  end

  # Opens the Mods screen from the title command.
  #
  # @param scene [Scene_Title] The title screen.
  def self.open(scene)
    MGQ_MpGame.call(scene, :close_command_window)
    SceneManager.call(Scene_MpMods)
  end

  # The screenshots the Mods screen draws, loaded once from the files the DLL saved and kept until
  # the screen closes, each also blurred for a spoiler's card.
  module Pictures
    # Times a spoiler's screenshot is blurred, enough that nothing in it can be told apart.
    BLUR_PASSES = 6

    # The pictures loaded, by their file and whether blurred.
    @bitmaps = {}

    # Hands out a screenshot.
    #
    # @param path [String] Its file, relative to the game folder; empty for none.
    # @param blurred [Boolean] Whether to hand it out blurred.
    # @return [Bitmap, nil] The picture, nil when there is none or it cannot be read.
    def self.of(path, blurred)
      return nil if path.to_s.empty?

      key = [path, blurred]
      return @bitmaps[key] if @bitmaps.key?(key)

      @bitmaps[key] = load(path, blurred)
    end

    # Reads a screenshot from its file.
    #
    # @param path [String] Its file, relative to the game folder.
    # @param blurred [Boolean] Whether to blur it.
    # @return [Bitmap, nil] The picture, nil when it cannot be read.
    def self.load(path, blurred)
      bitmap = Bitmap.new(path)
      BLUR_PASSES.times { bitmap.blur } if blurred
      bitmap
    rescue => e
      MGQ_MpModBrowser.log("could not read the screenshot #{path}: #{e.class}: #{e.message}")
      nil
    end

    # Frees every picture, as the screen closes.
    def self.clear
      @bitmaps.each_value { |bitmap| bitmap.dispose if bitmap && !bitmap.disposed? }
      @bitmaps = {}
    end
  end
end

# What the Mods screen's windows share: drawing a screenshot into a 16:9 frame, cut to fit, or a
# placeholder, and the colors of a mod's status.
module MGQ_MpModDrawing
  # What a mod's badge says, by its status.
  BADGES = { "update" => "Update", "changed" => "Changed", "current" => "Installed" }

  # Fill behind a card and a panel.
  PANEL_COLOR = Color.new(0, 0, 0, 72)

  # Fill where a screenshot is missing.
  EMPTY_COLOR = Color.new(0, 0, 0, 128)

  # Fill behind a badge and the spoiler's label.
  LABEL_COLOR = Color.new(0, 0, 0, 176)

  # Font size of a badge and of small texts.
  SMALL_SIZE = 15

  # What a missing screenshot's frame says.
  NO_PICTURE = "No screenshot"

  # What a spoiler's blurred screenshot says.
  SPOILER = "Spoiler"

  # Draws a screenshot into a frame, cut at its sides or top and bottom to fill it, or a placeholder.
  #
  # @param mod [MGQ_MpModBrowser::Mod] The mod.
  # @param rect [Rect] The frame.
  # @param blurred [Boolean] Whether a spoiler's screenshot is shown blurred.
  def draw_picture(mod, rect, blurred)
    picture = MGQ_MpModBrowser::Pictures.of(mod.thumbnail, blurred && mod.spoiler)
    unless picture
      contents.fill_rect(rect, EMPTY_COLOR)
      draw_label(NO_PICTURE, rect, false)
      return
    end

    contents.stretch_blt(rect, picture, cropped(picture, rect))
    draw_label(SPOILER, rect, true) if blurred && mod.spoiler
  end

  # Finds the part of a picture that fills a frame of other proportions, from its middle.
  #
  # @param picture [Bitmap] The picture.
  # @param rect [Rect] The frame.
  # @return [Rect] The part.
  def cropped(picture, rect)
    if picture.width * rect.height > rect.width * picture.height
      width = picture.height * rect.width / rect.height
      Rect.new((picture.width - width) / 2, 0, width, picture.height)
    else
      height = picture.width * rect.height / rect.width
      Rect.new(0, (picture.height - height) / 2, picture.width, height)
    end
  end

  # Draws a text in the middle of a frame, on a dark band when asked.
  #
  # @param text [String] The text, empty for none.
  # @param rect [Rect] The frame.
  # @param band [Boolean] Whether to put it on a dark band.
  def draw_label(text, rect, band)
    return if text.empty?

    contents.font.size = SMALL_SIZE
    y = rect.y + (rect.height - line_height) / 2
    contents.fill_rect(rect.x, y, rect.width, line_height, LABEL_COLOR) if band
    change_color(normal_color, band)
    draw_text(rect.x, y, rect.width, line_height, text, 1)
    reset_font_settings
  end

  # Draws a mod's badge at the top left of a frame.
  #
  # @param mod [MGQ_MpModBrowser::Mod] The mod.
  # @param rect [Rect] The frame.
  def draw_badge(mod, rect)
    badge = BADGES[mod.status]
    return unless badge

    contents.font.size = SMALL_SIZE
    width = text_size(badge).width + 10
    contents.fill_rect(rect.x + 4, rect.y + 4, width, 20, LABEL_COLOR)
    change_color(status_color(mod.status))
    draw_text(rect.x + 4, rect.y + 4, width, 20, badge, 1)
    reset_font_settings
  end

  # Finds the color of a mod's status.
  #
  # @param status [String] The status.
  # @return [Color] Gold for an update, the warning color for a changed copy, the color of what is
  #   fine for an installed mod.
  def status_color(status)
    case status
    when "update" then MGQ_MpWorld::FEATURED_COLOR
    when "changed" then crisis_color
    when "current" then power_up_color
    else normal_color
    end
  end

  # Names who made a mod, or where it comes from when no author is known.
  #
  # @param mod [MGQ_MpModBrowser::Mod] The mod.
  # @return [String] Such as "by Paulinchen" or "from GitHub".
  def author_text(mod)
    return "by #{mod.author}" unless mod.author.empty?

    mod.source == "github" ? "from GitHub" : "from the relay"
  end
end

# The Mods screen: the bar at the top, the cards below it, and a mod's page in their place once a
# card is opened.
class Scene_MpMods < Scene_MenuBase
  # What the screen says while nothing else happened.
  HINT = "Up and down pick the bar or the mods, Enter moves into it. Esc or Numpad 0 goes back."

  # What the screen says inside the mods.
  MODS_HINT = "Arrows pick a mod, Enter opens it. Esc or Numpad 0 goes back to picking the bar or the mods."

  # What the screen says inside the bar.
  BAR_HINT = "Left and right pick a button, Down reaches the search. Esc or Numpad 0 goes back to picking the bar or the mods."

  # What the screen says while the search is typed.
  SEARCH_HINT = "Type to filter the mods. Enter or Up keeps the filter and goes back to the buttons, Esc or Numpad 0 clears it."

  # Most characters a search takes.
  SEARCH_CHARS = 40

  # What the screen says on a mod's page.
  PAGE_HINT = "Left and right pick a button, up and down scroll the text. Esc or Numpad 0 goes back."

  # What the screen says while the lists are fetched.
  LOADING_TEXT = "The mod lists are being fetched . . ."

  # What the screen says while a change runs.
  BUSY_TEXT = "Changing the mods . . ."

  # The title of the box that tells how a change goes.
  BOX_TITLE = "Mods"

  # What the box says of the mods a change installs, their names and versions filled in.
  INSTALLING = "Installing %s"

  # What the box says of the mods a change removes, their names filled in.
  REMOVING = "Removing %s"

  # The hint of the box while a change runs.
  WAIT_HINT = "Downloading and checking the files . . ."

  # The hint of the box once a change failed.
  CLOSE_HINT = "Enter, Esc or Numpad 0: close"

  # What the screen says when a change could not start.
  NOT_STARTED_TEXT = "The change could not start. Wait until the list is fetched and try again."

  # What the screen says while mods are parked for a world.
  PARKED_TEXT = "Other mods are turned off for a world right now. Restart the game, then change the mods."

  # What the screen says when a change failed, the reason filled in.
  FAILED_TEXT = "Nothing changed: %s"

  # What the screen says when a page could not open.
  PAGE_FAILED_TEXT = "The page could not be opened."

  # The question before a changed copy is replaced, the mod's name and the new version filled in.
  REPLACE_QUESTION = "Your copy of %s differs from every version the list knows. Replace it with %s? Your changes are lost."

  # The answers to REPLACE_QUESTION.
  REPLACE_CHOICES = ["Replace", "Keep mine"]

  # The question before a mod is removed, its name filled in.
  REMOVE_QUESTION = "Remove %s? Its files are deleted from the Patch folder."

  # The answers to REMOVE_QUESTION.
  REMOVE_CHOICES = ["Remove", "Keep"]

  # The question once mods changed, which load only as the game starts, what changed filled in.
  RESTART_QUESTION = "%s The changed mods load when the game starts again. Restart the game now?"

  # The answers to RESTART_QUESTION.
  RESTART_CHOICES = ["Restart", "Later"]

  # What the screen says while a restart is still to come.
  RESTART_LATER_TEXT = "Restart the game to load the changed mods."

  # What the screen says when the game cannot start itself again under Wine or Proton.
  RESTART_BY_HAND_TEXT = "Close the game and start it again by hand to load the changed mods."

  # What the screen says when the game could not start itself again.
  RESTART_FAILED_TEXT = "The game could not start itself again. Close it and start it again to load the changed mods."

  # Creates the windows and has the DLL fetch the lists again.
  def start
    super
    @bar = Window_MpModBar.new
    @bar_commands = Window_MpModBarCommands.new
    @bar_commands.set_handler(:view, method(:on_view))
    @bar_commands.set_handler(:update_all, method(:on_update_all))
    @bar_commands.set_handler(:refresh, method(:on_refresh))
    @bar_commands.set_handler(:cancel, method(:back_to_boxes))
    @grid = Window_MpModGrid.new(@bar.height, Graphics.height - @bar.height)
    @grid.set_handler(:ok, method(:on_card))
    @grid.set_handler(:cancel, method(:back_to_boxes))
    @grid.view = MGQ_MpModBrowser.view
    @bar_commands.view = @grid.view
    @page_commands = Window_MpModPageCommands.new
    @page = Window_MpModPage.new(@bar.height, Graphics.height - @bar.height - @page_commands.height)
    [:install, :replace, :remove, :open_site].each { |symbol| @page_commands.set_handler(symbol, method(:"on_#{symbol}")) }
    @page_commands.set_handler(:back, method(:close_page))
    @page_commands.set_handler(:cancel, method(:close_page))
    @message = HINT
    @busy = false
    @query = ""
    @level = :boxes
    @box = :mods
    @list = MGQ_MpModBrowser::EMPTY
    MGQ_MpModBrowser.refresh("the Mods screen opened")
    look
    @bar_for_want = @grid.item_max == 0
    pick_box(@bar_for_want ? :bar : :mods)
    MGQ_MpModBrowser.log("opened")
  rescue => e
    MGQ_MpModBrowser.log("the Mods screen could not start: #{e.class}: #{e.message}")
    return_scene
  end

  # Picks the bar or the mods, moves inside them, scrolls a page's text, backs out with Numpad 0
  # too, and follows the list and a running change.
  def update
    super
    return close_failure if @failure_shown && (Input.trigger?(:C) || MGQ_MpUi.cancel?)

    # The key that led back to picking a box was taken this frame already and must not leave too.
    just_picked = @just_picked
    @just_picked = false
    if @search
      update_search
    elsif !(MGQ_MpUi::Confirm.open? || @failure_shown || @busy || just_picked)
      @level == :boxes && !@page_mod ? update_boxes : move_focus
    end
    @look_frames += 1
    look if @look_frames >= MGQ_MpModBrowser::LOOK_FRAMES
  rescue => e
    MGQ_MpModBrowser.log("the Mods screen failed: #{MGQ_MpLog.failure(e)} at #{Array(e.backtrace).first}")
    return_scene
  end

  # Picks the bar or the mods as a whole with Up and Down, moves inside with Enter, and leaves the
  # screen with Esc or Numpad 0.
  def update_boxes
    if MGQ_MpUi.cancel?
      Sound.play_cancel
      return return_scene
    end

    if Input.trigger?(:UP) || Input.trigger?(:DOWN)
      other = @box == :bar ? :mods : :bar
      return Sound.play_buzzer if other == :mods && @grid.item_max == 0

      Sound.play_cursor
      @bar_for_want = false
      pick_box(other)
    elsif Input.trigger?(:C)
      Sound.play_ok
      enter_box
    end
  end

  # Takes the arrows and Numpad 0 the windows leave alone: Numpad 0 back to picking the bar or the
  # mods, Down from the bar's buttons to the search, up and down on a page to its text.
  def move_focus
    if @grid.active || @bar_commands.active
      return back_to_boxes if MGQ_MpUi.numpad_cancel?
      return focus_search if @bar_commands.active && Input.trigger?(:DOWN)
    elsif @page_commands.active
      return close_page if MGQ_MpUi.numpad_cancel?

      @page.scroll(-1) if Input.repeat?(:UP)
      @page.scroll(1) if Input.repeat?(:DOWN)
    end
  end

  # Picks the bar or the mods as a whole, the input with no window, and draws the cursor around it.
  #
  # @param box [Symbol] :bar or :mods.
  def pick_box(box)
    @box = box
    @level = :boxes
    @just_picked = true
    take_input
    show_boxes
    say(HINT)
  end

  # Moves inside the box picked: to the bar's buttons or to the mods.
  def enter_box
    @level = :inside
    show_boxes
    if @box == :bar
      @bar_commands.activate
      say(BAR_HINT)
    else
      @grid.activate
      say(MODS_HINT)
    end
  end

  # Goes back from inside the bar or the mods to picking one of them as a whole.
  def back_to_boxes
    Sound.play_cancel if MGQ_MpUi.numpad_cancel?
    pick_box(@box)
  end

  # Draws the cursor around the box picked while the player picks one, and the windows' own
  # cursors while they are moved inside.
  def show_boxes
    picking = @level == :boxes
    @bar.boxed = picking && @box == :bar
    @grid.boxed = picking && @box == :mods
    @grid.cursor_hidden = @box == :bar
    @level == :inside && @box == :bar ? @bar_commands.show_cursor : @bar_commands.hide_cursor
  end

  # Starts typing the search in place in the bar, the mods filtered as it changes.
  def focus_search
    Sound.play_cursor
    @bar_for_want = false
    take_input
    @bar_commands.hide_cursor
    @searched_before = @query
    @search = MGQ_MpUi::TextEdit.new(@query, :max_chars => SEARCH_CHARS)
    MGQ_Multiplayer::Link.typing(true)
    say(SEARCH_HINT)
  end

  # Takes what is typed into the search, which belongs to the bar: Enter and Up keep it and go back
  # to the bar's buttons, Esc or Numpad 0 clear it and go back to them; only Esc there leaves the bar.
  def update_search
    text, _keys = MGQ_Multiplayer::Link.take_typed
    return end_search(:clear) if MGQ_MpUi.numpad_cancel?

    text.each_char do |char|
      case @search.type(char)
      when :enter then return end_search(:keep)
      when :escape then return end_search(:clear)
      when :refused then Sound.play_buzzer
      end
    end
    @search.update_keys
    return end_search(:keep) if MGQ_Multiplayer::Capture.trigger?(:UP)

    filter(@search.text)
    show_info
  end

  # Stops typing the search and gives the input back to the bar's buttons.
  #
  # @param kept [Symbol] :keep to keep the search, :clear to show every mod again.
  def end_search(kept)
    MGQ_Multiplayer::Link.typing(false)
    @search = nil
    Sound.play_cursor
    filter(kept == :clear ? "" : @query)
    if @query != @searched_before
      MGQ_MpModBrowser.log(@query.empty? ? "search cleared" : "searched for \"#{@query}\": #{@grid.item_max} of #{@list.mods.size} mods")
    end
    enter_box
  end

  # Shows only the mods a search finds.
  #
  # @param query [String] The search, empty for every mod.
  def filter(query)
    return if query == @query

    @query = query
    @grid.mods = MGQ_MpModBrowser.found(@list.mods, @query)
  end

  # Shows the mods as cards or as a list, the other way than now, and keeps the choice.
  def on_view
    view = @grid.view == "cards" ? "list" : "cards"
    @grid.view = view
    @bar_commands.view = view
    MGQ_MpModBrowser.view = view
    @bar_commands.activate
  end

  # Stops the typing, frees the screenshots and logs that the screen closed.
  def terminate
    MGQ_Multiplayer::Link.typing(false) if @search
    super
    @progress_box.dispose if @progress_box
    MGQ_MpModBrowser::Pictures.clear
    MGQ_MpModBrowser.log("closed")
  end

  # Shows the list the DLL holds, and what became of a running change.
  def look
    @look_frames = 0
    @list = MGQ_MpModBrowser.list
    @grid.mods = MGQ_MpModBrowser.found(@list.mods, @query)
    follow_cards
    @bar_commands.updates = @list.updates
    if @page_mod
      @page.show(page_mod, @list.loading_details == @page_mod.id)
      @page_commands.mod = page_mod
    end
    follow_change if @busy
    show_info
  end

  # Finds the mod the page shows in the list read last, which may have changed since it opened.
  #
  # @return [MGQ_MpModBrowser::Mod, nil] The mod, nil once the list lacks it.
  def page_mod
    @list.mods.find { |mod| mod.id == @page_mod.id } || @page_mod
  end

  # Ends a running change once the DLL finished it, says what it did or why it failed, and offers
  # the restart the changed mods need.
  def follow_change
    return unless ["done", "failed"].include?(@list.action)

    @busy = false
    if @list.action == "failed"
      Sound.play_buzzer
      say(format(FAILED_TEXT, @list.action_error.to_s))
      show_box(format(FAILED_TEXT, @list.action_error.to_s), CLOSE_HINT)
      @failure_shown = true
      return
    end

    hide_box
    Sound.play_ok
    say(@list.done.to_s.empty? ? HINT : @list.done)
    @list.restart ? ask_restart(@list.done.to_s) : give_back_input
  end

  # Closes the box that told why a change failed, and gives the input back.
  def close_failure
    Sound.play_cancel
    @failure_shown = false
    hide_box
    give_back_input
  end

  # Shows the box in the middle of the screen that tells how a change goes.
  #
  # @param text [String] What it says.
  # @param hint [String] Its hint at the bottom.
  def show_box(text, hint)
    @progress_box ||= Sprite_MpMessageBox.new
    @progress_box.show(BOX_TITLE, text, hint)
  end

  # Takes the box off the screen.
  def hide_box
    @progress_box.visible = false if @progress_box
  end

  # Tells what a change does, for the box while it runs.
  #
  # @param changes [Array<Array(Symbol, MGQ_MpModBrowser::Mod)>] Each change and its mod.
  # @return [String] Such as "Installing Party Sheet 1.5.2 and Level Cap 1.5.2, removing Map Display . . .".
  def change_text(changes)
    installs = changes.select { |kind, _mod| kind == :install }.map { |_kind, mod| "#{mod.name} #{mod.latest}" }
    removes = changes.select { |kind, _mod| kind == :remove }.map { |_kind, mod| mod.name }
    parts = []
    parts << format(INSTALLING, joined(installs)) unless installs.empty?
    parts << format(REMOVING, joined(removes)) unless removes.empty?
    "#{parts.each_with_index.map { |part, at| at.zero? ? part : part.sub(/\A./) { |letter| letter.downcase } }.join(', ')} . . ."
  end

  # Joins names as a sentence does.
  #
  # @param names [Array<String>] The names, at least one.
  # @return [String] Such as "A", "A and B" or "A, B and C".
  def joined(names)
    names.size > 1 ? "#{names[0..-2].join(', ')} and #{names[-1]}" : names[0].to_s
  end

  # Opens the page of the card picked.
  def on_card
    open_page(@grid.current_mod)
  end

  # Shows a mod's page in place of the cards, fetching its description when it is not installed.
  #
  # @param mod [MGQ_MpModBrowser::Mod] The mod.
  def open_page(mod)
    @page_mod = mod
    MGQ_MpModBrowser.fetch_description(mod) if mod.status == "available"
    @grid.hide
    @grid.deactivate
    @page.show(mod, mod.source == "site" && mod.status == "available" && mod.description.empty?)
    @page.visible = true
    @page_commands.mod = mod
    @page_commands.show
    @page_commands.activate
    say(PAGE_HINT)
    MGQ_MpModBrowser.log("opened the page of #{mod.name}")
  end

  # Goes back from a mod's page to the cards.
  def close_page
    # Numpad 0 is the game's cancel with Num Lock on, so the same press must not leave the mods too.
    @just_picked = true
    Sound.play_cancel
    @page_mod = nil
    @page.visible = false
    @page_commands.hide
    @page_commands.deactivate
    @grid.show
    @grid.activate
    say(MODS_HINT)
  end

  # Updates every mod with an update, changed copies left alone.
  def on_update_all
    updates = @list.mods.select { |mod| mod.status == "update" }
    change(updates.map { |mod| [:install, mod] })
  end

  # Fetches the lists again.
  def on_refresh
    MGQ_MpModBrowser.refresh("the player asked")
    @bar_commands.activate
    look
  end

  # Installs or updates the mod of the page.
  def on_install
    change([[:install, page_mod]])
  end

  # Replaces the page's mod's changed copy, once the player agreed to lose it.
  def on_replace
    mod = page_mod
    ask(format(REPLACE_QUESTION, mod.name, mod.latest), REPLACE_CHOICES) { change([[:install, mod]]) }
  end

  # Removes the mod of the page, once the player agreed.
  def on_remove
    mod = page_mod
    ask(format(REMOVE_QUESTION, mod.name), REMOVE_CHOICES) { change([[:remove, mod]]) }
  end

  # Opens the page's mod's page in the browser.
  def on_open_site
    return refuse(PAGE_FAILED_TEXT) unless MGQ_MpModBrowser.open_page(page_mod)

    give_back_input
  end

  # Starts a change, unless mods are parked for a world.
  #
  # @param changes [Array<Array(Symbol, MGQ_MpModBrowser::Mod)>] Each change and its mod.
  def change(changes)
    return refuse(PARKED_TEXT) if MGQ_MpModBrowser.parked?
    return refuse(NOT_STARTED_TEXT) unless MGQ_MpModBrowser.apply(changes)

    @busy = true
    say(BUSY_TEXT)
    show_box(change_text(changes), WAIT_HINT)
    take_input
  end

  # Asks a question in the shared box, and gives the input back once it is answered.
  #
  # @param question [String] The question.
  # @param choices [Array<String>] The yes and the no label.
  # @yield What a yes does.
  def ask(question, choices)
    take_input
    asked = MGQ_MpUi::Confirm.ask(question, choices) do |yes|
      give_back_input
      yield if yes
    end
    give_back_input unless asked
  end

  # Offers to start the game again so the changed mods load.
  #
  # @param done [String] What the change did, such as "Installed Party Sheet 1.5.2.".
  def ask_restart(done)
    take_input
    asked = MGQ_MpUi::Confirm.ask(format(RESTART_QUESTION, done).strip, RESTART_CHOICES) do |yes|
      give_back_input
      yes ? restart : say(RESTART_LATER_TEXT)
    end
    give_back_input unless asked
  end

  # Starts the game again, or tells the player to.
  def restart
    case MGQ_MpModBrowser.restart
    when :restarting then SceneManager.exit
    when :by_hand then say(RESTART_BY_HAND_TEXT)
    else say(RESTART_FAILED_TEXT)
    end
  end

  # Takes the input from every window while a change runs or a question is asked.
  def take_input
    [@grid, @bar_commands, @page_commands].each(&:deactivate)
  end

  # Gives the input back where it was: to the page while it shows, inside the bar or the mods, or
  # to picking a box, the bar while there are no mods.
  def give_back_input
    if @page_mod then @page_commands.activate
    elsif @level == :inside && @box == :bar then @bar_commands.activate
    elsif @level == :inside && @grid.item_max > 0 then @grid.activate
    elsif @grid.item_max == 0
      @box = :bar
      @level = :boxes
      show_boxes
    else
      @level = :boxes
      show_boxes
    end
  end

  # Keeps the input where there is something to pick: on the bar while there are no mods, and on
  # the mods once the first arrive while the bar was picked only for want of them.
  def follow_cards
    if @box == :mods && @grid.item_max == 0 && !@page_mod
      @grid.deactivate
      @box = :bar
      @level = :boxes
      @bar_for_want = true
      show_boxes
    elsif @bar_for_want && @level == :boxes && @box == :bar && @grid.item_max > 0
      @bar_for_want = false
      @box = :mods
      show_boxes
    end
  end

  # Says why something cannot be done.
  #
  # @param text [String] Why.
  def refuse(text)
    Sound.play_buzzer
    say(text)
    give_back_input
  end

  # Says what happened last.
  #
  # @param message [String] What.
  def say(message)
    @message = message
    show_info
  end

  # Shows the bar's status, the search and what happened last.
  def show_info
    status = if @list.mods.empty? && @list.state != "failed" then LOADING_TEXT
             elsif !@query.empty? then "#{@grid.item_max} of #{@list.mods.size} mods"
             elsif @list.updates > 0 then "#{@list.updates} update#{@list.updates == 1 ? '' : 's'}"
             else "#{@list.mods.size} mods"
             end
    @bar.show(status, @list.error || @message, @query, @search)
  end
end

# The bar at the top of the Mods screen: the title and a status at the left of its first line, the
# buttons at its right, and below them the search and what happened last.
class Window_MpModBar < Window_Base
  include MGQ_MpUi::Theme::Skinned

  # Lines the bar has.
  LINES = 2

  # Width of the search's label.
  SEARCH_LABEL_WIDTH = 56

  # Width of the search's label and box together.
  SEARCH_WIDTH = 300

  # Fill behind the search's text.
  BOX_COLOR = Color.new(0, 0, 0, 96)

  # What the search says while it is empty and not typed into.
  SEARCH_PLACEHOLDER = "Down from the buttons to type"

  # Draws the cursor around the whole bar while it is picked as a whole, or takes it away.
  #
  # @param boxed [Boolean] Whether the bar is picked as a whole.
  def boxed=(boxed)
    return if boxed == @boxed

    @boxed = boxed
    @shown = nil
    boxed ? cursor_rect.set(0, 0, contents_width, contents_height) : cursor_rect.empty
  end

  # Creates the bar across the top of the screen.
  def initialize
    super(0, 0, Graphics.width, fitting_height(LINES))
  end

  # Draws the status, the search and the message, if they changed.
  #
  # @param status [String] Such as "2 updates".
  # @param message [String] What happened last.
  # @param query [String] The search.
  # @param editor [MGQ_MpUi::TextEdit, nil] The search's editor while it is typed, nil otherwise.
  def show(status, message, query = "", editor = nil)
    shown = [status, message, query, editor && [editor.text, editor.cursor, editor.cursor_shown?]]
    return if shown == @shown

    @shown = shown
    contents.clear
    change_color(system_color)
    draw_text(0, 0, 80, line_height, MGQ_MpModBrowser::COMMAND_NAME)
    contents.font.size = MGQ_MpModDrawing::SMALL_SIZE
    change_color(normal_color, false)
    draw_text(80, 0, 200, line_height, status)
    draw_search(query, editor)
    change_color(normal_color, false)
    width = contents_width - SEARCH_WIDTH - 12
    draw_text(SEARCH_WIDTH + 12, line_height, width, line_height, MGQ_MpUi.cut(self, message.to_s, width))
    reset_font_settings
  end

  # Draws the search at the left of the second line: its label, then its text on a darker box, with
  # the cursor while it is typed, or a hint while it is empty.
  #
  # @param query [String] The search.
  # @param editor [MGQ_MpUi::TextEdit, nil] The search's editor while it is typed.
  def draw_search(query, editor)
    change_color(system_color)
    draw_text(0, line_height, SEARCH_LABEL_WIDTH, line_height, "Search")
    box = Rect.new(SEARCH_LABEL_WIDTH, line_height + 2, SEARCH_WIDTH - SEARCH_LABEL_WIDTH, line_height - 4)
    contents.fill_rect(box, BOX_COLOR)
    text = Rect.new(box.x + 4, box.y, box.width - 8, box.height)
    if editor
      change_color(normal_color)
      MGQ_MpUi::TextBox.draw_line(contents, text, editor)
      cursor_rect.set(box.x - 2, box.y - 2, box.width + 4, box.height + 4)
    else
      change_color(normal_color, !query.empty?)
      draw_text(text, query.empty? ? SEARCH_PLACEHOLDER : MGQ_MpUi.cut(self, query, text.width))
      @boxed ? cursor_rect.set(0, 0, contents_width, contents_height) : cursor_rect.empty
    end
  end
end

# The bar's buttons at the right of its first line: the other view, Update all and Refresh.
class Window_MpModBarCommands < Window_HorzCommand
  include MGQ_MpUi::Theme::Skinned

  # Width of the buttons together.
  WIDTH = 420

  # The view button, by the view it shows the mods in.
  VIEW_BUTTONS = { "cards" => "List view", "list" => "Card view" }

  # The first button while updates wait, their number filled in.
  UPDATE_ALL = "Update all (%d)"

  # The first button while no update waits.
  NO_UPDATES = "Update all"

  # Creates the buttons without a frame of their own, over the bar, without the input.
  def initialize
    @updates = 0
    @view = MGQ_MpModBrowser::VIEWS[0]
    super(Graphics.width - WIDTH, 0)
    self.opacity = 0
    deactivate
    select(2)
  end

  # Returns the buttons' width.
  #
  # @return [Integer] The width.
  def window_width
    WIDTH
  end

  # Returns how many buttons fit side by side.
  #
  # @return [Integer] All three.
  def col_max
    3
  end

  # Lists the other view, Update all, enabled while updates wait, and Refresh.
  def make_command_list
    add_command(VIEW_BUTTONS[@view], :view)
    add_command(@updates > 0 ? format(UPDATE_ALL, @updates) : NO_UPDATES, :update_all, @updates > 0)
    add_command("Refresh", :refresh)
  end

  # Takes the cursor off the buttons while the player is not inside the bar, keeping the button it
  # was on.
  def hide_cursor
    return if index < 0

    @kept = index
    unselect
  end

  # Puts the cursor back on the button it was on, Refresh the first time.
  def show_cursor
    select(@kept || 2) if index < 0
  end

  # Names the other view on its button, once the view changed.
  #
  # @param view [String] How the mods show now, "cards" or "list".
  def view=(view)
    return if view == @view

    @view = view
    refresh
  end

  # Names the updates waiting, redrawing the buttons once their number changed.
  #
  # @param updates [Integer] How many there are.
  def updates=(updates)
    return if updates == @updates

    @updates = updates
    refresh
  end

end

# The mods as cards, three to a row, two rows on the screen, each with its screenshot, its badge, its
# name and version, who made it and its summary; or as a list, six rows on the screen, each with a
# small screenshot and the same texts beside it.
class Window_MpModGrid < Window_Selectable
  include MGQ_MpBoxCursor
  include MGQ_MpUi::Theme::Skinned
  include MGQ_MpModDrawing

  # Cards side by side.
  COLUMNS = 3

  # Rows of cards on the screen.
  ROWS = 2

  # Space inside a card's edge.
  PAD = 4

  # Height of a card's name line.
  NAME_HEIGHT = 22

  # Height of a card's author line and of a line of its summary.
  SMALL_HEIGHT = 17

  # Lines of a card's summary.
  SUMMARY_LINES = 2

  # Rows of the list on the screen.
  LIST_ROWS = 6

  # Width of a list row's screenshot, 16:9 with the row's height.
  ROW_PICTURE_WIDTH = 96

  # How the mods show now, "cards" or "list".
  attr_reader :view

  # Creates the cards below the bar, without the input.
  #
  # @param y [Integer] The top edge.
  # @param height [Integer] The height.
  def initialize(y, height)
    @mods = []
    @view = MGQ_MpModBrowser::VIEWS[0]
    super(0, y, Graphics.width, height)
    deactivate
    refresh
  end

  # Returns how many mods stand side by side.
  #
  # @return [Integer] COLUMNS as cards, one as a list.
  def col_max
    @view == "list" ? 1 : COLUMNS
  end

  # Returns the space between two cards.
  #
  # @return [Integer] The space.
  def spacing
    8
  end

  # Returns a card's or a row's height, their rows filling the window.
  #
  # @return [Integer] The height.
  def item_height
    (height - standard_padding * 2) / (@view == "list" ? LIST_ROWS : ROWS)
  end

  # Shows the mods as cards or as a list, keeping the mod picked in sight.
  #
  # @param view [String] "cards" or "list".
  def view=(view)
    return if view == @view

    @view = view
    create_contents
    refresh
    select([index, 0].max) if item_max > 0
  end

  # Returns how many cards there are.
  #
  # @return [Integer] The number.
  def item_max
    @mods ? @mods.size : 0
  end

  # Shows other mods, keeping the mod picked.
  #
  # @param mods [Array<MGQ_MpModBrowser::Mod>] The mods, all or those a search found.
  def mods=(mods)
    signature = mods.map { |mod| [mod.id, mod.name, mod.status, mod.installed, mod.latest, mod.thumbnail, mod.summary] }
    return if signature == @signature

    @signature = signature
    picked = current_mod && current_mod.id
    @mods = mods
    create_contents
    refresh
    again = picked && @mods.index { |mod| mod.id == picked }
    item_max > 0 ? select(again || [[index, 0].max, item_max - 1].min) : unselect
  end

  # Returns the mod the cursor is on.
  #
  # @return [MGQ_MpModBrowser::Mod, nil] The mod, nil while there is none.
  def current_mod
    index >= 0 ? @mods[index] : nil
  end

  # Hides the cursor on the mod picked while the player works in the bar, keeping the pick.
  #
  # @param hidden [Boolean] Whether to hide it.
  def cursor_hidden=(hidden)
    return if hidden == @cursor_hidden

    @cursor_hidden = hidden
    update_cursor
  end

  # Draws the cursor as the box cursor and the game do, unless it is hidden.
  def update_cursor
    return cursor_rect.empty if @cursor_hidden

    super
  end

  # Tells whether Enter may open the card the cursor is on.
  #
  # @return [Boolean] Whether there is one.
  def current_item_enabled?
    !current_mod.nil?
  end

  # Moves the cursor up a row, never round to the last, so Up on the first row reaches the search.
  #
  # @param _wrap [Boolean] Whether the game would wrap, which the mods never do.
  def cursor_up(_wrap = false)
    super(false)
  end

  # Moves the cursor down a row, never round to the first, as the cards do.
  #
  # @param _wrap [Boolean] Whether the game would wrap, which the mods never do.
  def cursor_down(_wrap = false)
    super(false)
  end

  # Draws a mod as a card or as a row of the list.
  #
  # @param index [Integer] The mod.
  def draw_item(index)
    @view == "list" ? draw_row(@mods[index], item_rect(index)) : draw_card(@mods[index], item_rect(index))
  end

  # Draws a row of the list: a small screenshot with its badge, then the name and version, and who
  # made it with the summary below them.
  #
  # @param mod [MGQ_MpModBrowser::Mod] The mod.
  # @param rect [Rect] The row.
  def draw_row(mod, rect)
    contents.fill_rect(rect.x, rect.y + 1, rect.width, rect.height - 2, PANEL_COLOR)
    picture = Rect.new(rect.x + PAD, rect.y + PAD, ROW_PICTURE_WIDTH, ROW_PICTURE_WIDTH * 9 / 16)
    draw_picture(mod, picture, true)
    draw_badge(mod, picture)
    x = picture.x + picture.width + PAD * 2
    width = rect.x + rect.width - PAD - x
    y = rect.y + (rect.height - NAME_HEIGHT - SMALL_HEIGHT) / 2
    draw_name(mod, x, y, width)
    contents.font.size = SMALL_SIZE
    change_color(normal_color, false)
    line = mod.summary.empty? ? author_text(mod) : "#{author_text(mod)}  -  #{mod.summary}"
    draw_text(x, y + NAME_HEIGHT, width, SMALL_HEIGHT, cut(line, width))
    reset_font_settings
  end

  # Draws a card: its screenshot with its badge, its name and version, who made it and its summary.
  #
  # @param mod [MGQ_MpModBrowser::Mod] The mod.
  # @param rect [Rect] The card.
  def draw_card(mod, rect)
    contents.fill_rect(rect, PANEL_COLOR)
    width = rect.width - PAD * 2
    picture = Rect.new(rect.x + PAD, rect.y + PAD, width, width * 9 / 16)
    draw_picture(mod, picture, true)
    draw_badge(mod, picture)
    y = picture.y + picture.height + 2
    draw_name(mod, rect.x + PAD, y, width)
    y += NAME_HEIGHT
    contents.font.size = SMALL_SIZE
    change_color(normal_color, false)
    draw_text(rect.x + PAD, y, width, SMALL_HEIGHT, cut(author_text(mod), width))
    y += SMALL_HEIGHT
    change_color(normal_color)
    summary_lines(mod.summary, width).each_with_index do |line, row|
      draw_text(rect.x + PAD, y + row * SMALL_HEIGHT, width, SMALL_HEIGHT, line)
    end
    reset_font_settings
  end

  # Draws a card's name, in its status's color, with the newest version at its right.
  #
  # @param mod [MGQ_MpModBrowser::Mod] The mod.
  # @param x [Integer] The left edge.
  # @param y [Integer] The top edge.
  # @param width [Integer] The width.
  def draw_name(mod, x, y, width)
    contents.font.size = SMALL_SIZE
    version_width = [text_size(mod.latest).width + 4, width / 3].min
    change_color(normal_color, false)
    draw_text(x + width - version_width, y, version_width, NAME_HEIGHT, cut(mod.latest, version_width), 2)
    reset_font_settings
    change_color(mod.status == "available" ? normal_color : status_color(mod.status))
    draw_text(x, y, width - version_width - 4, NAME_HEIGHT, cut(mod.name, width - version_width - 4))
  end

  # Breaks a summary into the lines a card shows, the last one cut when there are more.
  #
  # @param summary [String] The summary.
  # @param width [Integer] The width a line may take.
  # @return [Array<String>] The lines.
  def summary_lines(summary, width)
    lines = MGQ_MpUi.wrap(self, summary.to_s, width)
    return lines if lines.size <= SUMMARY_LINES

    lines = lines.first(SUMMARY_LINES)
    lines[-1] = cut("#{lines[-1]} ..", width)
    lines
  end

  # Cuts a text at its end until it fits, in the font set.
  #
  # @param text [String] The text.
  # @param width [Integer] The width it may take.
  # @return [String] The text, cut when needed.
  def cut(text, width)
    MGQ_MpUi.cut(self, text, width)
  end
end

# A mod's page in place of the cards: its screenshot, unblurred, with its versions beside it, and
# below them its description while it is not installed, else the newest version's changes, which
# scroll.
class Window_MpModPage < Window_Base
  include MGQ_MpUi::Theme::Skinned
  include MGQ_MpModDrawing

  # Width of the screenshot.
  PICTURE_WIDTH = 288

  # Space between the screenshot and the rows beside it, and above the text.
  GAP = 8

  # Width of the labels beside the screenshot.
  LABEL_WIDTH = 72

  # Height of a row beside the screenshot.
  ROW_HEIGHT = 22

  # Height of a line of the text.
  TEXT_LINE_HEIGHT = 18

  # What the page says while the description is fetched.
  DESCRIPTION_LOADING = "Fetching the description . . ."

  # What the page says of a mod without a description.
  NO_DESCRIPTION = "No description."

  # What the page says of a version without a changelog.
  NO_CHANGES = "No changes told."

  # What the details call each source.
  SOURCES = { "site" => "Website", "github" => "GitHub", "relay" => "Relay" }

  # Creates the page, hidden.
  #
  # @param y [Integer] The top edge.
  # @param height [Integer] The height.
  def initialize(y, height)
    super(0, y, Graphics.width, height)
    @scroll = 0
    self.visible = false
  end

  # Shows a mod, starting at the top of its text when it is another than shown.
  #
  # @param mod [MGQ_MpModBrowser::Mod] The mod.
  # @param loading [Boolean] Whether its description is being fetched.
  def show(mod, loading = false)
    @scroll = 0 if @mod.nil? || @mod.id != mod.id
    @mod = mod
    @loading = loading
    redraw
  end

  # Scrolls the text by lines, as far as there is more.
  #
  # @param step [Integer] Lines down, negative for up.
  def scroll(step)
    return unless @mod

    scrolled = [[@scroll + step, 0].max, [@text_lines.to_i - text_rows, 0].max].min
    return if scrolled == @scroll

    @scroll = scrolled
    Sound.play_cursor
    redraw(true)
  end

  # Draws the page anew, if what it shows changed or it was scrolled.
  #
  # @param forced [Boolean] Whether to draw even when nothing changed.
  def redraw(forced = false)
    signature = [@mod.to_a, @loading, @scroll]
    return if signature == @shown && !forced

    @shown = signature
    contents.clear
    picture = Rect.new(0, 0, PICTURE_WIDTH, PICTURE_WIDTH * 9 / 16)
    draw_picture(@mod, picture, false)
    draw_badge(@mod, picture)
    draw_rows(PICTURE_WIDTH + GAP)
    draw_text_panel(picture.height + GAP)
  end

  # Draws the mod's name and the rows beside the screenshot.
  #
  # @param x [Integer] Their left edge.
  def draw_rows(x)
    width = contents_width - x
    change_color(@mod.status == "available" ? system_color : status_color(@mod.status))
    draw_text(x, 0, width, line_height, MGQ_MpUi.cut(self, @mod.name, width))
    rows = [
      ["Author", @mod.author.empty? ? "Unknown" : @mod.author],
      ["From", SOURCES[@mod.source] || @mod.source],
      ["Yours", yours_text],
      ["Newest", @mod.latest],
      ["Size", "#{size_text(@mod.bytes)}, #{@mod.files} file#{@mod.files == 1 ? '' : 's'}"],
    ]
    rows.each_with_index do |(label, value), row|
      y = line_height + 4 + row * ROW_HEIGHT
      contents.font.size = SMALL_SIZE
      change_color(system_color)
      draw_text(x, y, LABEL_WIDTH, ROW_HEIGHT, label)
      change_color(label == "Yours" ? status_color(@mod.status) : normal_color)
      draw_text(x + LABEL_WIDTH, y, width - LABEL_WIDTH, ROW_HEIGHT, MGQ_MpUi.cut(self, value, width - LABEL_WIDTH))
    end
    reset_font_settings
  end

  # Tells the version in Patch.
  #
  # @return [String] The version, "Changed copy" or "Not installed".
  def yours_text
    case @mod.status
    when "changed" then "Changed copy"
    when "available" then "Not installed"
    else @mod.installed
    end
  end

  # Tells a download's size.
  #
  # @param bytes [Integer] The size, 0 when unknown.
  # @return [String] Such as "34 KB", or "Unknown size".
  def size_text(bytes)
    return "Unknown size" if bytes <= 0

    bytes >= 1024 * 1024 ? format("%.1f MB", bytes / 1048576.0) : "#{[(bytes + 1023) / 1024, 1].max} KB"
  end

  # Draws the description of a mod that is not installed, else the newest version's changes, from
  # the line scrolled to, as many lines as fit.
  #
  # @param y [Integer] The panel's top edge.
  def draw_text_panel(y)
    height = contents_height - y
    contents.fill_rect(0, y, contents_width, height, PANEL_COLOR)
    title, texts = panel_texts
    change_color(system_color)
    contents.font.size = SMALL_SIZE
    draw_text(GAP, y + 2, contents_width - GAP * 2, TEXT_LINE_HEIGHT, title)
    lines = wrapped(texts)
    @text_lines = lines.size
    @text_top = y + TEXT_LINE_HEIGHT + 4
    change_color(normal_color)
    lines[@scroll, text_rows].to_a.each_with_index do |line, row|
      draw_text(GAP, @text_top + row * TEXT_LINE_HEIGHT, contents_width - GAP * 2, TEXT_LINE_HEIGHT, line)
    end
    draw_text(GAP, y + 2, contents_width - GAP * 2, TEXT_LINE_HEIGHT, "#{@scroll + 1}-#{[@scroll + text_rows, lines.size].min} of #{lines.size}", 2) if lines.size > text_rows
    reset_font_settings
  end

  # Breaks the text panel's texts into lines, once per text, since measuring them is slow in the
  # game and scrolling draws them again on every step.
  #
  # @param texts [Array<String>] The texts.
  # @return [Array<String>] The lines.
  def wrapped(texts)
    return @wrapped[1] if @wrapped && @wrapped[0] == texts

    lines = texts.map { |text| text.empty? ? [""] : MGQ_MpUi.wrap(self, text, contents_width - GAP * 2) }.flatten
    @wrapped = [texts, lines]
    lines
  end

  # Tells what the text panel shows: the description of a mod that is not installed, else the
  # newest version's changes.
  #
  # @return [Array(String, Array<String>)] The heading and the texts.
  def panel_texts
    unless @mod.status == "available"
      return ["Changes in #{@mod.latest}", @mod.notes.empty? ? [NO_CHANGES] : @mod.notes]
    end

    texts = if !@mod.description.empty? then @mod.description
            elsif @loading then [DESCRIPTION_LOADING]
            elsif !@mod.summary.empty? then [@mod.summary]
            else [NO_DESCRIPTION]
            end
    ["Description", texts]
  end

  # Tells how many lines of the text fit.
  #
  # @return [Integer] The lines.
  def text_rows
    [(contents_height - @text_top.to_i) / TEXT_LINE_HEIGHT, 1].max
  end
end

# The buttons under a mod's page: what can be done with it, its page on the website, and Back.
class Window_MpModPageCommands < Window_HorzCommand
  include MGQ_MpUi::Theme::Skinned

  # Creates the buttons across the bottom of the screen, hidden.
  def initialize
    @mod = nil
    super(0, 0)
    self.y = Graphics.height - height
    hide
    deactivate
  end

  # Returns the buttons' width, the screen's.
  #
  # @return [Integer] The width.
  def window_width
    Graphics.width
  end

  # Returns how many buttons fit side by side.
  #
  # @return [Integer] Four.
  def col_max
    4
  end

  # Takes the mod whose buttons to show, redrawing them once what they offer changed, the first
  # one picked for another mod.
  #
  # @param mod [MGQ_MpModBrowser::Mod] The mod.
  def mod=(mod)
    shown = [mod.id, mod.status, mod.latest, mod.page]
    return if shown == @shown

    other = @shown.nil? || @shown[0] != mod.id
    @shown = shown
    @mod = mod
    refresh
    select(0) if other
  end

  # Lists Install, Update or Replace, then Remove, Open page and Back, each enabled where it applies.
  def make_command_list
    return unless @mod

    case @mod.status
    when "update" then add_command("Update to #{@mod.latest}", :install)
    when "changed" then add_command("Replace with #{@mod.latest}", :replace)
    when "available" then add_command("Install #{@mod.latest}", :install)
    else add_command("Installed", :install, false)
    end
    add_command("Remove", :remove, ["update", "current"].include?(@mod.status))
    add_command("Open page", :open_site, !@mod.page.empty?)
    add_command("Back", :back)
  end
end

# The title screen's Mods command, through core_hooks.rbx.

begin
  MGQ_MpHooks.before(Scene_Title, :start, "ui_mod_browser") { MGQ_MpModBrowser.on_title_start }
  MGQ_MpHooks.after(Scene_Title, :update, "ui_mod_browser") { MGQ_MpModBrowser.on_title_update(self) unless scene_changing? }
  MGQ_MpHooks.after(Window_TitleCommand, :make_command_list, "ui_mod_browser") { MGQ_MpModBrowser.add_title_command(self) }
  MGQ_MpHooks.after(Scene_Title, :create_command_window, "ui_mod_browser") do
    commands = MGQ_MpGame.get(self, :command_window)
    commands.set_handler(MGQ_MpModBrowser::COMMAND_SYMBOL, lambda { MGQ_MpModBrowser.open(self) }) if commands
  end
rescue => e
  MGQ_MpModBrowser.log("title hooks FAILED: #{e.class}: #{e.message}")
end
