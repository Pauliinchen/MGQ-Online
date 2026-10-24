#----------------------------------------------------------------
#  ui_mod_browser.rbx
#
#  Changelog:
#      Paulinchen  2026-10-24: Created
#
#----------------------------------------------------------------

# The Mods screen, opened from the title screen's Mods command below Multiplayer: every mod of the
# website and of the relay's catalog at the left, those with an update first, and the picked mod's
# details at the right. The DLL fetches the lists, finds which mods and versions are in Patch, and
# installs, updates and removes them; this script only shows what it tells and passes on what the
# player picks. The title command counts the updates waiting.
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
  LIST_SIZE = 32768

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
  List = Struct.new(:state, :error, :updates, :action, :action_error, :done, :restart, :mods)

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
  # @!attribute notes [Array<String>] The newest version's changelog, a line each.
  Mod = Struct.new(:id, :name, :author, :status, :installed, :latest, :source, :page, :files, :bytes, :summary, :notes)

  # The list before the DLL told one.
  EMPTY = List.new("idle", nil, 0, "idle", nil, nil, false, [])

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
        mod.notes = []
        mods << mod
        by_id[mod.id] = mod
      when "note"
        mod = by_id[fields[1]]
        mod.notes << fields[2].to_s if mod
      end
    end

    List.new(state["state"] || "idle", state["error"], state["updates"].to_i, state["action"] || "idle",
             state["action_error"], state["done"], state["restart"] == "1", mods)
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
end

# The Mods screen: the mods at the left, the picked one's details at the right, what can be done
# with it in a small window in the middle, and what happened in the lines at the top.
class Scene_MpMods < Scene_MenuBase
  # What the screen says while nothing else happened.
  HINT = "Up and down pick a mod, confirm shows what you can do with it. Esc or Numpad 0 goes back."

  # Lines at the top of the screen.
  INFO_LINES = 2

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
    @info_window = Window_MpInfo.new(INFO_LINES)
    @list_window = Window_MpModList.new(@info_window.height, Graphics.height - @info_window.height)
    @list_window.set_handler(:mod, method(:on_mod))
    @list_window.set_handler(:update_all, method(:on_update_all))
    @list_window.set_handler(:retry, method(:on_retry))
    @list_window.set_handler(:cancel, method(:return_scene))
    @detail_window = Window_MpModDetail.new(@list_window.width, @info_window.height, @list_window.height)
    @actions_window = Window_MpChoice.new
    [:install, :replace, :remove, :open_page].each { |symbol| @actions_window.set_handler(symbol, method(:"on_#{symbol}")) }
    @actions_window.set_handler(:cancel, method(:back_to_list))
    @message = HINT
    @busy = false
    MGQ_MpModBrowser.refresh("the Mods screen opened")
    look
    @list_window.activate
    MGQ_MpModBrowser.log("opened")
  rescue => e
    MGQ_MpModBrowser.log("the Mods screen could not start: #{e.class}: #{e.message}")
    return_scene
  end

  # Follows the list and a running change, and backs out with Numpad 0 too.
  def update
    super
    unless MGQ_MpUi::Confirm.open?
      if @actions_window.active && MGQ_MpUi.numpad_cancel? then back_to_list
      elsif @list_window.active && MGQ_MpUi.numpad_cancel? then return_scene
      end
    end

    @look_frames += 1
    look if @look_frames >= MGQ_MpModBrowser::LOOK_FRAMES
    @detail_window.show(@list_window.current_mod, @list_window.current_symbol)
  rescue => e
    MGQ_MpModBrowser.log("the Mods screen failed: #{MGQ_MpLog.failure(e)} at #{Array(e.backtrace).first}")
    return_scene
  end

  # Logs that the screen closed.
  def terminate
    MGQ_MpModBrowser.log("closed")
    super
  end

  # Shows the list the DLL holds, and what became of a running change.
  def look
    @look_frames = 0
    @list = MGQ_MpModBrowser.list
    @list_window.list = @list
    follow_change if @busy
    show_info
  end

  # Ends a running change once the DLL finished it, says what it did or why it failed, and offers
  # the restart the changed mods need.
  def follow_change
    return unless ["done", "failed"].include?(@list.action)

    @busy = false
    if @list.action == "failed"
      Sound.play_buzzer
      say(format(FAILED_TEXT, @list.action_error.to_s))
      return @list_window.activate
    end

    Sound.play_ok
    say(@list.done.to_s.empty? ? HINT : @list.done)
    @list.restart ? ask_restart : @list_window.activate
  end

  # Shows what can be done with the picked mod, which the choices act on even when the list
  # changes under them.
  def on_mod
    mod = @picked = @list_window.current_mod
    install = case mod.status
              when "update" then ["Update to #{mod.latest}", :install]
              when "changed" then ["Replace with #{mod.latest}", :replace]
              when "available" then ["Install #{mod.latest}", :install]
              end
    choices = []
    choices << install if install
    choices << ["Remove", :remove] if ["update", "current"].include?(mod.status)
    choices << ["Open page", :open_page, !mod.page.empty?]
    @actions_window.start(choices)
  end

  # Updates every mod with an update, changed copies left alone.
  def on_update_all
    updates = @list.mods.select { |mod| mod.status == "update" }
    change(updates.map { |mod| [:install, mod] })
  end

  # Fetches the lists again after they failed.
  def on_retry
    MGQ_MpModBrowser.refresh("the player asked again")
    @list_window.activate
    look
  end

  # Installs or updates the picked mod.
  def on_install
    @actions_window.finish
    change([[:install, @picked]])
  end

  # Replaces the picked mod's changed copy, once the player agreed to lose it.
  def on_replace
    @actions_window.finish
    mod = @picked
    ask(format(REPLACE_QUESTION, mod.name, mod.latest), REPLACE_CHOICES) { change([[:install, mod]]) }
  end

  # Removes the picked mod, once the player agreed.
  def on_remove
    @actions_window.finish
    mod = @picked
    ask(format(REMOVE_QUESTION, mod.name), REMOVE_CHOICES) { change([[:remove, mod]]) }
  end

  # Opens the picked mod's page in the browser.
  def on_open_page
    @actions_window.finish
    return refuse(PAGE_FAILED_TEXT) unless MGQ_MpModBrowser.open_page(@picked)

    @list_window.activate
  end

  # Starts a change, unless mods are parked for a world.
  #
  # @param changes [Array<Array(Symbol, MGQ_MpModBrowser::Mod)>] Each change and its mod.
  def change(changes)
    return refuse(PARKED_TEXT) if MGQ_MpModBrowser.parked?
    return refuse(NOT_STARTED_TEXT) unless MGQ_MpModBrowser.apply(changes)

    @busy = true
    say(BUSY_TEXT)
    @list_window.deactivate
  end

  # Asks a question in the shared box, and goes back to the list once it is answered.
  #
  # @param question [String] The question.
  # @param choices [Array<String>] The yes and the no label.
  # @yield What a yes does.
  def ask(question, choices)
    @list_window.deactivate
    asked = MGQ_MpUi::Confirm.ask(question, choices) do |yes|
      @list_window.activate
      yield if yes
    end
    @list_window.activate unless asked
  end

  # Offers to start the game again so the changed mods load.
  def ask_restart
    @list_window.deactivate
    asked = MGQ_MpUi::Confirm.ask(RESTART_QUESTION, RESTART_CHOICES) do |yes|
      @list_window.activate
      yes ? restart : say(RESTART_LATER_TEXT)
    end
    @list_window.activate unless asked
  end

  # Starts the game again, or tells the player to.
  def restart
    case MGQ_MpModBrowser.restart
    when :restarting then SceneManager.exit
    when :by_hand then say(RESTART_BY_HAND_TEXT)
    else say(RESTART_FAILED_TEXT)
    end
  end

  # Closes the small window and goes back to the list.
  def back_to_list
    Sound.play_cancel
    @actions_window.finish
    @list_window.activate
  end

  # Says why something cannot be done.
  #
  # @param text [String] Why.
  def refuse(text)
    Sound.play_buzzer
    say(text)
    @list_window.activate
  end

  # Says what happened last.
  #
  # @param message [String] What.
  def say(message)
    @message = message
    show_info
  end

  # Shows what happened last and how the lists stand.
  def show_info
    status = case @list.state
             when "idle", "loading" then @list.mods.empty? ? LOADING_TEXT : nil
             end
    @info_window.show([@message, status || @list.error])
  end
end

# The mods at the left of the Mods screen, which scroll: Update all while updates wait, then every
# mod with a tag at its right for an update, a changed copy and an installed one.
class Window_MpModList < Window_Command
  include MGQ_MpUi::Theme::Skinned
  include MGQ_MpUi::ScrollingWindow

  # Width of the window.
  WIDTH = 230

  # The tag at the right of a mod, by its status.
  TAGS = { "update" => "Update", "changed" => "Changed", "current" => "Installed" }

  # Font size of the tags.
  TAG_SIZE = 15

  # The first row while updates wait, their number filled in.
  UPDATE_ALL = "Update all (%d)"

  # The row while the lists failed and no mod is known.
  RETRY = "Try again"

  # The row while the lists are fetched and no mod is known yet.
  LOADING = "Loading . . ."

  # Creates the list below the lines.
  #
  # @param y [Integer] The top edge.
  # @param height [Integer] The height.
  def initialize(y, height)
    @mods_list = MGQ_MpModBrowser::EMPTY
    @height = height
    super(0, y)
    deactivate
  end

  # Returns the window's width.
  #
  # @return [Integer] The width.
  def window_width
    WIDTH
  end

  # Returns the window's height.
  #
  # @return [Integer] The height.
  def window_height
    @height
  end

  # Shows another list, keeping the mod picked.
  #
  # @param list [MGQ_MpModBrowser::List] The list the DLL holds.
  def list=(list)
    signature = [list.state, list.updates, list.mods.map { |mod| [mod.id, mod.name, mod.status, mod.installed] }]
    return if signature == @signature

    @signature = signature
    picked = current_mod && current_mod.id
    @mods_list = list
    clear_command_list
    make_command_list
    refresh
    again = picked && @list.index { |command| command[:ext] && command[:ext].id == picked }
    select(again || [[index, 0].max, item_max - 1].min)
  end

  # Lists Update all while updates wait, then the mods; while there are none, what the lists do.
  def make_command_list
    list = @mods_list || MGQ_MpModBrowser::EMPTY
    add_command(format(UPDATE_ALL, list.updates), :update_all) if list.updates > 0
    list.mods.each { |mod| add_command(mod.name, :mod, true, mod) }
    return unless list.mods.empty?

    list.state == "failed" ? add_command(RETRY, :retry) : add_command(LOADING, :retry, false)
  end

  # Draws a mod with its tag at the right, a mod with an update in gold and a changed copy in the
  # warning color.
  #
  # @param index [Integer] The row.
  def draw_item(index)
    mod = @list[index][:ext]
    return super unless mod

    rect = item_rect_for_text(index)
    tag = TAGS[mod.status]
    if tag
      contents.font.size = TAG_SIZE
      change_color(system_color)
      tag_width = text_size(tag).width + 4
      draw_text(rect, tag, 2)
      rect.width -= tag_width
      reset_font_settings
    end
    change_color(color_of(mod.status))
    draw_text(rect, MGQ_MpUi.cut(self, mod.name, rect.width))
  end

  # Finds the color of a mod's name.
  #
  # @param status [String] The mod's status.
  # @return [Color] The color.
  def color_of(status)
    case status
    when "update" then MGQ_MpWorld::FEATURED_COLOR
    when "changed" then crisis_color
    else normal_color
    end
  end

  # Returns the mod the cursor is on.
  #
  # @return [MGQ_MpModBrowser::Mod, nil] The mod, nil on another row or none.
  def current_mod
    current_symbol == :mod ? current_ext : nil
  end

  # Tells whether the list is free to scroll with the mouse wheel.
  #
  # @return [Boolean] Whether it takes the input.
  def takes_wheel?
    active
  end
end

# The picked mod's details at the right of the Mods screen, laid out as a world's details: its
# name, a panel of who made it and the versions, then its summary and the newest version's changes.
class Window_MpModDetail < Window_MpWorldDetail
  # What the details call each source.
  SOURCES = { "site" => "Website", "github" => "GitHub", "relay" => "Relay" }

  # Most lines the summary takes.
  SUMMARY_LINES = 3

  # What the details say on the Update all row.
  UPDATE_ALL_TEXT = "Updates every mod marked Update. Changed copies stay as they are."

  # Shows a mod, if it is another than shown or changed.
  #
  # @param mod [MGQ_MpModBrowser::Mod, nil] The mod, nil on another row.
  # @param symbol [Symbol, nil] The row's symbol, which tells the Update all row.
  def show(mod, symbol = nil)
    signature = mod ? mod.to_a : symbol
    return if signature == @shown

    @shown = signature
    @targets = {}
    contents.clear
    return draw_lines(nil, [UPDATE_ALL_TEXT], 0) if symbol == :update_all
    return unless mod

    y = draw_name(mod) + GAP
    y = draw_panel(mod_panel(mod), y) + GAP
    y = draw_lines("Summary", [mod.summary], y, SUMMARY_LINES) + GAP unless mod.summary.empty?
    draw_lines("Changes in #{mod.latest}", mod.notes.empty? ? ["No changes told."] : mod.notes, y)
    reset_font_settings
  end

  # Tells who made a mod, where it comes from, the version installed and the newest, and how large
  # it is.
  #
  # @param mod [MGQ_MpModBrowser::Mod] The mod.
  # @return [Panel] The panel.
  def mod_panel(mod)
    rows = [
      [Cell.new("Author", mod.author.empty? ? "Unknown" : mod.author, :normal), Cell.new("From", SOURCES[mod.source] || mod.source, :normal)],
      [yours_cell(mod), Cell.new("Newest", mod.latest, :normal)],
      [Cell.new("Files", mod.files.to_s, :normal), Cell.new("Size", size_text(mod.bytes), :normal)],
    ]
    Panel.new("Mod", nil, rows)
  end

  # Tells the version in Patch, in the color of what is fine while it is the newest.
  #
  # @param mod [MGQ_MpModBrowser::Mod] The mod.
  # @return [Cell] The cell.
  def yours_cell(mod)
    case mod.status
    when "current" then Cell.new("Yours", mod.installed, :good)
    when "update" then Cell.new("Yours", mod.installed, :gold)
    when "changed" then Cell.new("Yours", "Changed copy", :warn)
    else Cell.new("Yours", "Not installed", :normal)
    end
  end

  # Tells a download's size.
  #
  # @param bytes [Integer] The size, 0 when unknown.
  # @return [String] Such as "34 KB", or "Unknown".
  def size_text(bytes)
    return "Unknown" if bytes <= 0

    bytes >= 1024 * 1024 ? format("%.1f MB", bytes / 1048576.0) : "#{[(bytes + 1023) / 1024, 1].max} KB"
  end

  # Draws the mod's name, one with an update in gold.
  #
  # @param mod [MGQ_MpModBrowser::Mod] The mod.
  # @return [Integer] The bottom edge.
  def draw_name(mod)
    reset_font_settings
    change_color(mod.status == "update" ? MGQ_MpWorld::FEATURED_COLOR : system_color)
    draw_text(0, 0, contents_width, TITLE_HEIGHT, cut(mod.name, contents_width))
    TITLE_HEIGHT
  end

  # Draws lines of text in a panel under a heading, each wrapped, as many as fit or as asked.
  #
  # @param title [String, nil] The heading, nil for none.
  # @param texts [Array<String>] The texts, each broken into lines of its own.
  # @param y [Integer] The top edge.
  # @param most [Integer, nil] Most lines, nil for as many as fit below.
  # @return [Integer] The bottom edge.
  def draw_lines(title, texts, y, most = nil)
    x = ACCENT_WIDTH + PAD * 2
    width = contents_width - x - PAD
    contents.font.size = DESCRIPTION_SIZE
    lines = texts.map { |text| MGQ_MpUi.wrap(self, text.to_s, width) }.flatten
    head = title ? HEADER_HEIGHT : 0
    room = (contents_height - y - head - PAD * 2) / DESCRIPTION_LINE_HEIGHT
    rows = [most || room, room].min
    return y if rows < 1

    if lines.size > rows
      lines = lines.first(rows)
      lines[-1] = cut("#{lines[-1]} ..", width)
    end
    height = most ? head + lines.size * DESCRIPTION_LINE_HEIGHT + PAD * 2 : contents_height - y
    contents.fill_rect(0, y, contents_width, height, PANEL_COLOR)
    contents.fill_rect(0, y, ACCENT_WIDTH, height, system_color)
    draw_header(title, nil, x, y) if title
    contents.font.size = DESCRIPTION_SIZE
    change_color(normal_color)
    lines.each_with_index do |line, row|
      draw_text(x, y + head + PAD + row * DESCRIPTION_LINE_HEIGHT, width, DESCRIPTION_LINE_HEIGHT, line)
    end
    y + height
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
