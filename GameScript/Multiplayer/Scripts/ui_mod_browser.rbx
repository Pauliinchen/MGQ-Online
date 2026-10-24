#----------------------------------------------------------------
#  ui_mod_browser.rbx
#
#  Changelog:
#      Paulinchen  2026-10-24: Showed the mods as cards with screenshots and each on a page of its own
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
  HINT = "Arrows pick a mod, Enter opens it, Up from the first row reaches Update all. Esc or Numpad 0 goes back."

  # What the screen says on a mod's page.
  PAGE_HINT = "Left and right pick a button, up and down scroll the text. Esc or Numpad 0 goes back."

  # What the screen says while the lists are fetched.
  LOADING_TEXT = "The mod lists are being fetched . . ."

  # What the screen says while a change runs.
  BUSY_TEXT = "Changing the mods . . ."

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

  # The question once mods changed, which load only as the game starts.
  RESTART_QUESTION = "The changed mods load when the game starts again. Restart the game now?"

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
    @bar_commands.set_handler(:update_all, method(:on_update_all))
    @bar_commands.set_handler(:refresh, method(:on_refresh))
    @bar_commands.set_handler(:cancel, method(:return_scene))
    @grid = Window_MpModGrid.new(@bar.height, Graphics.height - @bar.height)
    @grid.set_handler(:ok, method(:on_card))
    @grid.set_handler(:cancel, method(:return_scene))
    @page_commands = Window_MpModPageCommands.new
    @page = Window_MpModPage.new(@bar.height, Graphics.height - @bar.height - @page_commands.height)
    [:install, :replace, :remove, :open_site].each { |symbol| @page_commands.set_handler(symbol, method(:"on_#{symbol}")) }
    @page_commands.set_handler(:back, method(:close_page))
    @page_commands.set_handler(:cancel, method(:close_page))
    @message = HINT
    @busy = false
    @list = MGQ_MpModBrowser::EMPTY
    MGQ_MpModBrowser.refresh("the Mods screen opened")
    look
    give_back_input
    MGQ_MpModBrowser.log("opened")
  rescue => e
    MGQ_MpModBrowser.log("the Mods screen could not start: #{e.class}: #{e.message}")
    return_scene
  end

  # Moves between the bar and the cards, scrolls a page's text, backs out with Numpad 0 too, and
  # follows the list and a running change.
  def update
    grid_row = @grid.active ? @grid.index / @grid.col_max : nil
    super
    move_focus(grid_row) unless MGQ_MpUi::Confirm.open?
    @look_frames += 1
    look if @look_frames >= MGQ_MpModBrowser::LOOK_FRAMES
  rescue => e
    MGQ_MpModBrowser.log("the Mods screen failed: #{MGQ_MpLog.failure(e)} at #{Array(e.backtrace).first}")
    return_scene
  end

  # Takes the arrows and Numpad 0 the windows leave alone: Up from the first row of cards to the
  # bar, Down from the bar to the cards, up and down on a page to its text.
  #
  # @param grid_row [Integer, nil] The row the cards' cursor was on before this frame, nil while
  #   they had no input.
  def move_focus(grid_row)
    if @grid.active
      return return_scene if MGQ_MpUi.numpad_cancel?
      return focus_bar if grid_row == 0 && Input.trigger?(:UP) && @bar_commands.usable?
    elsif @bar_commands.active
      return return_scene if MGQ_MpUi.numpad_cancel?
      return focus_grid if Input.trigger?(:DOWN) && @grid.item_max > 0
    elsif @page_commands.active
      return close_page if MGQ_MpUi.numpad_cancel?

      @page.scroll(-1) if Input.repeat?(:UP)
      @page.scroll(1) if Input.repeat?(:DOWN)
    end
  end

  # Gives the input to the bar's buttons.
  def focus_bar
    Sound.play_cursor
    @bar_for_want = false
    @grid.deactivate
    @bar_commands.activate
  end

  # Gives the input back to the cards.
  def focus_grid
    Sound.play_cursor
    @bar_commands.deactivate
    @grid.activate
  end

  # Frees the screenshots and logs that the screen closed.
  def terminate
    super
    MGQ_MpModBrowser::Pictures.clear
    MGQ_MpModBrowser.log("closed")
  end

  # Shows the list the DLL holds, and what became of a running change.
  def look
    @look_frames = 0
    @list = MGQ_MpModBrowser.list
    @grid.list = @list
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
      return give_back_input
    end

    Sound.play_ok
    say(@list.done.to_s.empty? ? HINT : @list.done)
    @list.restart ? ask_restart : give_back_input
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
    Sound.play_cancel
    @page_mod = nil
    @page.visible = false
    @page_commands.hide
    @page_commands.deactivate
    @grid.show
    @grid.activate
    say(HINT)
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
  def ask_restart
    take_input
    asked = MGQ_MpUi::Confirm.ask(RESTART_QUESTION, RESTART_CHOICES) do |yes|
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

  # Gives the input back to the page while it shows, else to the cards, or to the bar while there
  # are none.
  def give_back_input
    if @page_mod then @page_commands.activate
    elsif @grid.item_max > 0 then @grid.activate
    else
      @bar_commands.activate
      @bar_for_want = true
    end
  end

  # Keeps the input where there is something to pick: on the bar while there are no cards, and on
  # the cards once the first arrive while the bar had the input only for want of them.
  def follow_cards
    if @grid.active && @grid.item_max == 0
      @grid.deactivate
      @bar_commands.activate
      @bar_for_want = true
    elsif @bar_for_want && @bar_commands.active && @grid.item_max > 0
      @bar_for_want = false
      @bar_commands.deactivate
      @grid.activate
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

  # Shows the bar's status and what happened last.
  def show_info
    status = if @list.mods.empty? && @list.state != "failed" then LOADING_TEXT
             elsif @list.updates > 0 then "#{@list.updates} update#{@list.updates == 1 ? '' : 's'}"
             else "#{@list.mods.size} mods"
             end
    @bar.show(status, @list.error || @message)
  end
end

# The bar at the top of the Mods screen: the title and a status at the left of its first line, the
# buttons at its right, and what happened last below.
class Window_MpModBar < Window_Base
  include MGQ_MpUi::Theme::Skinned

  # Lines the bar has.
  LINES = 2

  # Creates the bar across the top of the screen.
  def initialize
    super(0, 0, Graphics.width, fitting_height(LINES))
  end

  # Draws the status and the message, if they changed.
  #
  # @param status [String] Such as "2 updates".
  # @param message [String] What happened last.
  def show(status, message)
    return if [status, message] == @shown

    @shown = [status, message]
    contents.clear
    change_color(system_color)
    draw_text(0, 0, 80, line_height, MGQ_MpModBrowser::COMMAND_NAME)
    contents.font.size = MGQ_MpModDrawing::SMALL_SIZE
    change_color(normal_color, false)
    draw_text(80, 0, 200, line_height, status)
    reset_font_settings
    contents.font.size = MGQ_MpModDrawing::SMALL_SIZE
    draw_text(0, line_height, contents_width, line_height, MGQ_MpUi.cut(self, message.to_s, contents_width))
    reset_font_settings
  end
end

# The bar's buttons, Update all and Refresh, at the right of its first line.
class Window_MpModBarCommands < Window_HorzCommand
  include MGQ_MpUi::Theme::Skinned

  # Width of the buttons together.
  WIDTH = 300

  # The first button while updates wait, their number filled in.
  UPDATE_ALL = "Update all (%d)"

  # The first button while no update waits.
  NO_UPDATES = "Update all"

  # Creates the buttons without a frame of their own, over the bar, without the input.
  def initialize
    @updates = 0
    super(Graphics.width - WIDTH, 0)
    self.opacity = 0
    deactivate
    select(1)
  end

  # Returns the buttons' width.
  #
  # @return [Integer] The width.
  def window_width
    WIDTH
  end

  # Returns how many buttons fit side by side.
  #
  # @return [Integer] Both.
  def col_max
    2
  end

  # Lists Update all, enabled while updates wait, and Refresh.
  def make_command_list
    add_command(@updates > 0 ? format(UPDATE_ALL, @updates) : NO_UPDATES, :update_all, @updates > 0)
    add_command("Refresh", :refresh)
  end

  # Names the updates waiting, redrawing the buttons once their number changed.
  #
  # @param updates [Integer] How many there are.
  def updates=(updates)
    return if updates == @updates

    @updates = updates
    refresh
  end

  # Tells whether the buttons can take the input.
  #
  # @return [Boolean] Always, since Refresh always works.
  def usable?
    true
  end
end

# The mods as cards, three to a row, two rows on the screen: each with its screenshot, its badge,
# its name and version, who made it and its summary.
class Window_MpModGrid < Window_Selectable
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

  # Creates the cards below the bar, without the input.
  #
  # @param y [Integer] The top edge.
  # @param height [Integer] The height.
  def initialize(y, height)
    @mods = []
    super(0, y, Graphics.width, height)
    deactivate
    refresh
  end

  # Returns how many cards stand side by side.
  #
  # @return [Integer] COLUMNS.
  def col_max
    COLUMNS
  end

  # Returns the space between two cards.
  #
  # @return [Integer] The space.
  def spacing
    8
  end

  # Returns a card's height, two rows filling the window.
  #
  # @return [Integer] The height.
  def item_height
    (height - standard_padding * 2) / ROWS
  end

  # Returns how many cards there are.
  #
  # @return [Integer] The number.
  def item_max
    @mods ? @mods.size : 0
  end

  # Shows another list, keeping the mod picked.
  #
  # @param list [MGQ_MpModBrowser::List] The list the DLL holds.
  def list=(list)
    signature = list.mods.map { |mod| [mod.id, mod.name, mod.status, mod.installed, mod.latest, mod.thumbnail, mod.summary] }
    return if signature == @signature

    @signature = signature
    picked = current_mod && current_mod.id
    @mods = list.mods
    create_contents
    refresh
    again = picked && @mods.index { |mod| mod.id == picked }
    select(again || [[index, 0].max, item_max - 1].min) if item_max > 0
  end

  # Returns the mod the cursor is on.
  #
  # @return [MGQ_MpModBrowser::Mod, nil] The mod, nil while there is none.
  def current_mod
    index >= 0 ? @mods[index] : nil
  end

  # Tells whether Enter may open the card the cursor is on.
  #
  # @return [Boolean] Whether there is one.
  def current_item_enabled?
    !current_mod.nil?
  end

  # Draws a card: its screenshot with its badge, its name and version, who made it and its summary.
  #
  # @param index [Integer] The card.
  def draw_item(index)
    mod = @mods[index]
    rect = item_rect(index)
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
