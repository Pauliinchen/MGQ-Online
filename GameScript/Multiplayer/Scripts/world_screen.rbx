#----------------------------------------------------------------
#  world_screen.rbx
#
#  Changelog:
#      Paulinchen  2026-10-06: Asked for the player's name in a form typed in place instead of on the text screen
#                            - Kept a mod added by name when unlisted, and removed it with Delete, which the hint names while it is picked
#                            - Typed a mod's name in place in the picker, on the keyboard, instead of on the text screen
#                            - Named a mod in the picker with Enter and its red ! and orange ? buttons under titled columns instead of a menu, and listed or unlisted every mod at once
#                            - Had an admin's game send the Mod Config options of the catalog's mods as the list arrives
#                            - Picked a world's mods in the mod picker, a list of the installed ones and those added by name, each left out, listed, required or essential
#                            - Left the mod settings out of creating and changing a world, which its creator now sets in Mod Config, and noted whose world is entered
#                            - Checked a world's required mods against the relay's catalog and the creator's copies on entry, and offered to download the world's versions and restart
#                            - Entered the world again on its own after a restart for its mods
#                            - Sent the creator's hashes of required mods outside the catalog and their settings with a world made or changed
#                            - Showed the installed and the world's version of each required mod in the details
#      Paulinchen  2026-10-04: Picked the worlds or the commands as a whole first, then moved into the picked window with confirm and back out with cancel
#                            - Created the list box before a cancelled name prompt closes the screen, which disposes it
#                            - Kept a world this PC has saves of from being entered while the list, which tells its mods and game data, has not arrived
#                            - Broke a description's lines through MGQ_MpUi.wrap, which breaks inside a word longer than a line
#                            - Renamed from mp_world_screen.rbx
#                            - Drew the forms' text boxes through MGQ_MpUi::TextBox, and moved their cursor a line through MGQ_MpUi::TextEdit, which every text box shares
#                            - Showed a world's description, the mods it needs and whether the player's game data matches its creator's
#                            - Laid the world's details out like a form, in panels, with the description at the bottom, and gave them more of the screen
#                            - Laid the forms out in the same panels, with the whole description in a box of several lines
#                            - Listed every player of a world, and each mod it needs, in a list box, opened from the world's choices,
#                              from the details with the right arrow and confirm, or with a click on them
#                            - Showed the description in a smaller font, and whole in the list box
#                            - Kept the commands in a window of their own below the worlds, which scroll with a scrollbar
#                            - Left a new world to be entered from the list, as a favourite, instead of entering it at once
#                            - Took the players and the mods out of a world's choices, which the details open
#                            - Left a text box being typed into with the numpad's 0, the game's cancel key, as with Escape
#                            - Typed into the forms' text boxes with a cursor: arrows, Home, End and Delete, through MGQ_MpUi::TextEdit
#                            - Showed required mods in green, or in red while this game lacks their script, and kept such a game out
#                            - Showed essential mods in green while this game's data matches the world's, in gold otherwise
#                            - Let a world's creator take their game's data as the world's from the details' Your game row and a button of the edit form
#                            - Drew the list and the details only when what they show changed, not with every reading of the list
#                            - Logged frames of the world screen that take long, with what took the time
#                            - Showed each mod in a box of its own in the details, as many as fit the row, and counted the rest in a last box
#                            - Said create where a text said make
#                            - Added a hidden world to the list by its id, and offered to take it off again
#                            - Offered the creator and admins a form that changes a world's Max Players, mods and description
#                            - Shortened the messages that did not fit the lines at the top
#                            - Asked whether games whose data differs may enter instead of whether only games like the creator's may
#                            - Warned a game whose data differs before it enters a world, or kept it out when the creator said so
#                            - Showed the end of a text too long for its text box
#      Paulinchen  2026-10-03: Created
#
#----------------------------------------------------------------

# The world screen, opened from the title screen, and its windows: the worlds at the left, the
# chosen world's details or a form at the right, and the choices in the middle. It builds on
# world.rbx, which knows the worlds, and on world_text.rbx for what the player types.

# The world screen, opened from the title screen: every world of the relay's directory at the left,
# the chosen one's players at the right, and what the player can do with it. Creating a world and
# adding a hidden one are forms that take the right side while the list points at them.
class Scene_MpWorlds < Scene_MenuBase
  # What the screen says while nothing else happened.
  HINT = "Up and down pick the worlds or the commands, confirm moves into them. Right arrow on a world: its details."

  # What the screen says while a text box is typed into.
  TYPING_HINT = "Type on the keyboard. Arrows, Home, End move the cursor. Enter keeps it, Esc or Numpad 0 goes back."

  # Frames between two fetches of the list, ten seconds at 60 frames per second.
  REFRESH_FRAMES = 600

  # Frames between two looks at the list the DLL holds.
  LOOK_FRAMES = 20

  # Windows' codes of the numpad's 0, the game's cancel key, with Num Lock on and off.
  NUMPAD_CANCEL_KEYS = [0x60, 0x2D]

  # Seconds a frame of the screen may take before the log says what took them, and seconds between
  # two such lines.
  SLOW_FRAME = 0.05
  SLOW_FRAME_PAUSE = 2.0

  # What the screen says while an action runs, by the action's kind.
  BUSY_TEXTS = {
    "create" => "Creating the world . . .",
    "unlock" => "Opening the world . . .",
    "delete" => "Deleting the world . . .",
    "ban" => "Removing the player . . .",
    "edit" => "Saving the changes . . .",
    "find" => "Looking for the world . . .",
    "data" => "Updating the game data . . .",
    "start" => "Fetching the starting save . . .",
    "mods" => "Downloading the mods . . .",
  }

  # What the bottom of the mod picker says.
  MOD_PICK_HINT = "Enter: list or unlist    →: ! required, ? essential    Esc: done"

  # What the bottom of the mod picker says while a mod added by name is picked.
  MOD_PICK_ADDED_HINT = "Enter: list or unlist    →: ! required, ? essential    Del: remove    Esc: done"

  # Windows' code of the Delete key, which removes a mod added by name from the picker.
  DELETE_KEY = 0x2E

  # The titles of the mod picker's button columns.
  MOD_PICK_COLUMNS = ["Required", "Essential"]

  # What the right end of a mod's row says, by how it is named.
  MOD_STATE_LABELS = { :unlisted => "unlisted", :listed => "listed", :required => "required", :essential => "essential" }

  # The colour of a mod's row, by how it is named, as its buttons show it.
  MOD_STATE_COLORS = { :unlisted => :grey, :listed => :plain, :required => :bad, :essential => :gold }

  # Creates the windows, fetches the list, and takes what the text or save screen handed back.
  #
  # The scene is the same object again when those screens return, so the forms keep what was
  # filled in.
  def start
    super
    @info_window = Window_MpInfo.new
    @commands_window = Window_MpWorldCommands.new
    @worlds_window = Window_MpWorldList.new(@info_window.height, Graphics.height - @info_window.height - @commands_window.height)
    @list_window = MpWorldListPane.new(@worlds_window, @commands_window)
    @detail_window = Window_MpWorldDetail.new(@list_window.width, @info_window.height, @list_window.height)
    @form_window = Window_MpWorldForm.new(@detail_window.x, @detail_window.y, @detail_window.width, @detail_window.height)
    @form_window.set_handler(:ok, method(:on_field))
    @form_window.set_handler(:cancel, method(:leave_form))
    @list_window.set_handler(:world, method(:on_world))
    @list_window.set_handler(:new_world, method(:enter_form))
    @list_window.set_handler(:join_hidden, method(:enter_form))
    @list_window.set_handler(:rename, method(:enter_form))
    @list_window.set_handler(:cancel, method(:return_scene))
    @actions_window = Window_MpChoice.new
    [:enter, :favourite, :copy_id, :forget, :edit_world, :ban, :delete_world, :export_save, :delete_saves].each { |symbol| @actions_window.set_handler(symbol, method(:"on_#{symbol}")) }
    @actions_window.set_handler(:cancel, method(:back_to_list))
    @members_window = Window_MpChoice.new
    @members_window.set_handler(:member, method(:on_member))
    @members_window.set_handler(:cancel, method(:back_to_list))
    @confirm_window = Window_MpChoice.new
    @confirm_window.set_handler(:yes, method(:on_confirmed))
    @confirm_window.set_handler(:show_mods, method(:on_show_mods))
    @confirm_window.set_handler(:cancel, method(:back_to_list))
    @start_window = Window_MpChoice.new
    [:from_creator, :from_beginning, :from_own].each { |symbol| @start_window.set_handler(symbol, method(:"on_#{symbol}")) }
    @start_window.set_handler(:cancel, method(:back_to_list))
    @forms ||= { :new_world => MGQ_MpWorld::Form.create, :join_hidden => MGQ_MpWorld::Form.join }
    @forms[:rename] = MGQ_MpWorld::Form.rename(MGQ_Multiplayer::Player.name.to_s)
    @message ||= HINT
    @me = MGQ_MpWorld::Directory.my_id
    MGQ_MpWorldMods.forget_installed
    MGQ_MpWorld::Directory.refresh
    @refresh_frames = 0
    @look_frames = LOOK_FRAMES
    look_at_list
    take_text_result
    take_start_save
    return_to_form if @form_symbol
    show_panel
    show_info
  end

  # Asks for the player's name the first time, takes what is typed into a text box, follows a
  # running action, and keeps the list fresh.
  def update
    started = Time.now
    @spent = {}
    # The game's frame counter raises on the title screen, so the pane is told of each new frame.
    @list_window.settle
    timed(:windows) { super }

    if @ask_name
      @ask_name = false
      return ask_name
    end

    return start_from_own if @own_start

    timed(:input) do
      if @mod_view
        update_mod_pick
      elsif @box
        update_box
      elsif form && form.editing
        update_typing
      elsif @resume_form && !@start_window.active && !Input.press?(:C) && !Input.press?(:B)
        # The press that ended the typing must not reach the form, or Enter types again at once.
        @resume_form = false
        @form_window.activate
      elsif !form && !@busy && !popup_open?
        @list_window.update
        update_focus
      end
    end

    timed(:action) { follow_action } if @busy
    timed(:panel) do
      show_panel
      show_field_hint
    end

    @refresh_frames += 1
    if @refresh_frames >= REFRESH_FRAMES && !@busy
      @refresh_frames = 0
      MGQ_MpWorld::Directory.refresh
    end

    @look_frames += 1
    timed(:list) { look_at_list } if @look_frames >= LOOK_FRAMES
    log_slow_frame(Time.now - started)
  rescue => e
    MGQ_MpWorld.log("world screen failed: #{e.class}: #{e.message}")
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

  # Stops taking what is typed, should the screen close while a text box is typed into.
  def terminate
    MGQ_Multiplayer::Link.typing(false) if (form && form.editing) || @mod_edit
    @list_box.dispose
    super
  end

  # Shows the list the DLL holds, if it changed.
  def look_at_list
    @look_frames = 0
    state, error, listed, admin = MGQ_MpWorld::Directory.list
    @list_state = state
    @list_error = state == "failed" ? error : nil
    @admin = admin
    entries = MGQ_MpWorld.entries(listed, state == "ready")
    @list_window.entries = entries
    show_info
    MGQ_MpWorldMods.report_options(admin) if state == "ready"
    rejoin(entries, state)
  end

  # Enters the world the game started again for, once the list holds it, as if the player chose it.
  #
  # @param entries [Array<MGQ_MpWorld::Entry>] The list.
  # @param state [String] How the list stands.
  def rejoin(entries, state)
    id = MGQ_MpWorldMods.rejoining
    return unless id && state != "loading" && !@busy && !form

    MGQ_MpWorldMods.rejoined
    @entry = entries.find { |entry| entry.id == id }
    return say("The world you restarted for is not in the list right now.") unless @entry && state == "ready"

    @data_accepted = false
    on_enter
  end

  # Shows at the right what the list points at: a world's details, or a form.
  def show_panel
    shown = form || @forms[@list_window.current_symbol]
    @form_window.form = shown if shown
    @form_window.visible = !shown.nil?
    @detail_window.visible = shown.nil?
    @detail_window.show(@list_window.current_ext, @me) unless shown
  end

  # Acts on what the text screen handed back.
  def take_text_result
    kind, text = MGQ_MpWorld.take_text_result
    # The screen may close below, and terminate disposes the list box.
    @list_box = Sprite_MpListBox.new
    @box = nil
    @focus = nil

    case kind
    when :password
      start_action("unlock") { MGQ_MpWorld::Directory.unlock(@entry.id, text) } if text && @entry && @entry.listed
    when Array
      fill_field(kind[1], text) if text && form
    end

    @ask_name = MGQ_Multiplayer::Player.name.nil?
  end

  # Opens what can be done with the chosen world.
  def on_world
    @entry = @list_window.current_ext
    @data_accepted = false
    listed = @entry.listed
    creator = listed && listed.creator_id == @me
    commands = []
    commands.push(["Enter the world", :enter]) if listed || @entry.local
    commands.push([@entry.favourite ? "No longer a favourite" : "Mark as a favourite", :favourite]) if @entry.id
    commands.push(["Copy the world id", :copy_id]) if creator && listed.hidden
    commands.push(["Remove from my list", :forget]) if @entry.local.nil? && MGQ_MpWorld::Added.all.include?(@entry.id)
    commands.push(["Edit the world", :edit_world]) if listed && (creator || @admin)
    commands.push(["Remove a player", :ban, listed.members.size > 1]) if creator
    commands.push(["Delete the world for everyone", :delete_world]) if creator || (listed && @admin)
    commands.push(["Copy my latest save to my game", :export_save]) if @entry.local && @entry.local.latest_save
    commands.push(["Delete my saves of it", :delete_saves]) if @entry.local
    commands.push(["Back", :cancel])
    @actions_window.start(commands)
  end

  # Enters the chosen world, asking for its password the first time, unless it has none. A game
  # whose data differs from the creator's is warned or kept out first.
  def on_enter
    listed = @entry.listed
    return if listed && !mods_allow?(listed)

    MGQ_MpWorldMods.use(listed && listed.settings)
    MGQ_MpWorldMods.own_world(listed && listed.creator_id == @me ? [@entry.id, listed.mods] : nil)
    return if listed && !data_allows?(@entry.name, listed.data, listed.strict, listed.mods, listed.creator_id == @me) { on_enter }

    if @entry.listed && @entry.listed.start == "pending"
      Sound.play_buzzer
      say("#{@entry.name} is still being set up by its creator. Try again in a moment.")
      back_to_list
    elsif @entry.local && @entry.listed.nil? && (@entry.local.latest_save.nil? || !@entry.gone)
      # Without the list, a first entry cannot know where the world's players start, and no entry
      # which mods and game data the world asks for.
      refuse(@entry.gone ? "#{@entry.name} is no longer in the list: it was deleted, or you were removed." : "#{@entry.name} is not in the list right now. Try again once the list has loaded.")
      back_to_list
    elsif @entry.local
      listed = @entry.listed
      @entry.local.describe(listed.name, listed.id, listed.seats) if listed
      enter(@entry.local, listed && listed.start, listed && listed.choose)
    elsif @entry.listed.online >= @entry.listed.seats
      Sound.play_buzzer
      say("#{@entry.name} is full right now.")
      back_to_list
    elsif @entry.open?
      start_action("unlock") { MGQ_MpWorld::Directory.unlock(@entry.id, "") }
    else
      ask_text(:password, "The password of #{@entry.name}", "", :masked => true, :max_chars => MGQ_MpWorld::MAX_PASSWORD_CHARS)
    end
  end

  # Decides whether the player's game may enter a world as far as its required mods go: every one
  # installed in the world's version. Offers to download what the relay's catalog has, and says
  # which the player gets from the mod's author.
  #
  # @param listed [MGQ_MpWorld::Directory::ListedWorld] The world.
  # @return [Boolean] Whether entering goes on now.
  def mods_allow?(listed)
    rows = MGQ_MpWorldMods.differing(listed)
    return true if rows.empty?

    @mod_rows = rows
    unavailable = rows.reject { |row| row.downloadable? }

    if unavailable.size == rows.size && rows.all? { |row| row.yours == "not installed" }
      refuse("#{@entry.name} needs #{rows.map(&:name).join(', ')}: no such script in your Patch folder.")
      back_to_list
    elsif unavailable.empty?
      @confirming = :mods
      say(MGQ_MpWorldMods.summary(@entry.name, rows))
      @confirm_window.start([["Download and restart", :yes], ["See the mods", :show_mods], ["Back", :cancel]])
    else
      @confirming = :mods
      Sound.play_buzzer
      say(MGQ_MpWorldMods.summary(@entry.name, rows))
      @confirm_window.start([["See the mods", :show_mods], ["Back", :cancel]])
    end
    false
  end

  # Shows each required mod with the player's and the world's version.
  def on_show_mods
    @confirm_window.finish
    open_box(:mods)
  end

  # Decides whether the player's game may enter a world now: one whose data differs from the
  # creator's is kept out of a world for the same data only, and otherwise asked first.
  #
  # @param name [String] The world's name.
  # @param data [String, nil] The creator's game data, see MGQ_MpWorld::GameData.fingerprint.
  # @param strict [Boolean] Whether only games with the same data may enter.
  # @param mods [String, nil] The mods the world needs, as its creator wrote them.
  # @param own [Boolean] Whether the player made the world, and so may update its game data.
  # @yield What enters the world once the player said to enter anyway.
  # @return [Boolean] Whether entering goes on now.
  def data_allows?(name, data, strict, mods, own = false, &enter)
    differing = MGQ_MpWorld::GameData.differing(data)
    accepted = @data_accepted
    @data_accepted = false
    return true if differing.nil? || differing.empty? || (accepted && !strict)

    needed = MGQ_MpWorld.mods_of(mods)
    needs = needed.empty? ? "" : " It needs: #{needed.join(', ')}."

    if strict
      refuse(own ? "#{name} only takes matching game data. Update it under Your game in its details." : "#{name} only takes matching game data.#{needs}")
      back_to_list
    else
      @after_accept = enter
      confirm(:differing, "Your game data differs.#{needs} Enter anyway?", "Enter anyway")
    end
    false
  end

  # Marks the chosen world as a favourite, or no longer.
  def on_favourite
    favourite = MGQ_MpWorld::Favourites.toggle(@entry.id)
    say(favourite ? "#{@entry.name} is a favourite now." : "#{@entry.name} is no longer a favourite.")
    look_at_list
    back_to_list
  end

  # Puts the chosen hidden world's id on the clipboard, for its creator to hand out.
  def on_copy_id
    if MGQ_MpWorld::Link.copy(@entry.id)
      say("Copied the id of #{@entry.name}. Share it#{@entry.open? ? '' : ' with the password'}.")
    else
      Sound.play_buzzer
      say("The id could not be put on the clipboard.")
    end
    back_to_list
  end

  # Opens the list box with the chosen world's players, mods or description.
  #
  # @param kind [Symbol] :players, :mods or :description.
  def open_box(kind)
    listed = @entry.listed
    close_popups
    @list_window.deactivate
    lines = case kind
            when :players then player_lines(listed.members)
            when :mods then mod_lines(listed.mods, @entry.differing, MGQ_MpWorldMods.differing(listed))
            else description_lines(listed.description.to_s)
            end
    @box = Sprite_MpListBox::View.of(@entry.name, { :players => "Players", :mods => "Mods" }[kind] || "Description", lines)
    @box_pointed = nil
  end

  # Writes the list box's lines for a world's players: those online, then the others.
  #
  # @param members [Array<MGQ_MpWorld::Directory::Member>] Everyone who ever joined.
  # @return [Array<Array>] The lines, see Sprite_MpListBox::View.
  def player_lines(members)
    online = members.select { |member| member.online }
    lines = []

    [["Online", online, :good], ["Offline", members - online, :grey]].each do |heading, group, color|
      next if group.empty?

      lines.push([:head, "#{heading} (#{group.size})"])
      group.each { |member| lines.push([:item, member.id == @me ? "#{member.name} (you)" : member.name, color, heading.downcase]) }
    end
    lines
  end

  # Writes the list box's lines for the mods a world needs: the required ones first, green while
  # this game has their script in the world's version, gold in another version and red while it
  # lacks it, then the essential ones, green while this game's data matches the world's and gold
  # otherwise.
  #
  # @param text [String, nil] The mods as the world's creator wrote them.
  # @param differing [Array<String>, nil] What of this game's data differs from the world's, see MGQ_MpWorld::Entry#differing.
  # @param rows [Array<MGQ_MpWorldMods::Row>, nil] The required mods this game has in another version or lacks, see MGQ_MpWorldMods.differing.
  # @return [Array<Array>] The lines, see Sprite_MpListBox::View.
  def mod_lines(text, differing = nil, rows = nil)
    mods = MGQ_MpWorld.mods_of(text)
    required = MGQ_MpWorld.required_mods(text)
    essential = MGQ_MpWorld.essential_mods(text)
    lines = mods.map do |mod|
      row = rows && rows.find { |candidate| candidate.name == mod }

      if row && row.yours != "not installed"
        [:item, mod, :gold, "required, #{row.text.sub(/\A[^:]*: /, '')}"]
      elsif required.include?(mod)
        MGQ_MpWorld.installed_mod?(mod) ? [:item, mod, :good, "required, installed"] : [:item, mod, :bad, "required, missing"]
      elsif essential.include?(mod)
        if differing.nil?
          [:item, mod, :gold, "essential, not checked"]
        else
          differing.empty? ? [:item, mod, :good, "essential, data matches"] : [:item, mod, :gold, "essential, data differs"]
        end
      else
        [:item, mod, :plain, nil]
      end
    end
    [[:head, "Mods (#{mods.size})"]] + lines
  end

  # Writes the list box's lines for a world's description, broken to the box's width.
  #
  # @param text [String] The description.
  # @return [Array<Array>] The lines, see Sprite_MpListBox::View.
  def description_lines(text)
    measure = @list_box.bitmap
    measure.font.size = Sprite_MpListBox::ITEM_SIZE
    width = Sprite_MpListBox::BOX.width - Sprite_MpListBox::ITEM_LEFT - 16
    MGQ_MpUi.wrap(measure, text, width).map { |line| [:item, line, :plain, nil] }
  end

  # Follows the arrows, cancel and the mouse while the list box is open.
  def update_box
    @box.move(1) if Input.repeat?(:DOWN)
    @box.move(-1) if Input.repeat?(:UP)
    position = mouse_position
    clicked = mouse_clicked?

    if position
      line = Sprite_MpListBox.line_at(position[0], position[1], @box)
      @box.pick(line) if line && @box.lines[line][0] == :item && position != @box_pointed
      @box_pointed = position
    end

    outside = clicked && position && !Sprite_MpListBox.inside?(position[0], position[1])
    return close_box if Input.trigger?(:B) || outside

    @list_box.show(@box)
  end

  # Closes the list box and goes back to where it was opened from.
  def close_box
    Sound.play_cancel
    @box = nil
    @list_box.hide
    @list_window.activate unless @focus
  end

  # Moves between the list and the chosen world's details: the right arrow moves onto what the
  # details open, up and down between them, confirm or a click opens it, left or cancel goes back.
  def update_focus
    targets = @detail_window.visible ? @detail_window.targets : []
    clicked = clicked_target(targets)
    return open_target(clicked) if clicked

    if @focus
      return leave_focus if targets.empty?

      @focus = targets.first unless targets.include?(@focus)

      if Input.trigger?(:B) || Input.trigger?(:LEFT)
        Sound.play_cancel
        return leave_focus
      elsif Input.trigger?(:C)
        Sound.play_ok
        return open_target(@focus)
      elsif Input.repeat?(:DOWN) || Input.repeat?(:UP)
        Sound.play_cursor
        @focus = targets[(targets.index(@focus) + (Input.repeat?(:DOWN) ? 1 : -1)) % targets.size]
      end
      @detail_window.focus(@focus)
    elsif @list_window.active && Input.trigger?(:RIGHT) && !targets.empty?
      Sound.play_cursor
      @focus = targets.first
      @list_window.deactivate
      @detail_window.focus(@focus)
    end
  end

  # Moves from the details back to the list.
  def leave_focus
    @focus = nil
    @detail_window.focus(nil)
    @list_window.activate
  end

  # Opens the list box for what the details point at.
  #
  # @param target [Symbol] :players or :mods.
  def open_target(target)
    @entry = @list_window.current_ext
    return open_box(target) unless target == :data

    @list_window.deactivate
    ask_data_update
  end

  # Makes the chosen world take the creator's game data as it is now, at once, as the edit form's
  # button does.
  def update_data
    if MGQ_MpWorld::GameData.fingerprint.empty?
      refuse("Your game data could not be read.")
      return back_to_list
    end

    start_action("data") { MGQ_MpWorld::Directory.set_data(@entry.id) }
  end

  # Asks the creator whether the chosen world takes their game's data as it is now, from the
  # details, where a click reaches it.
  def ask_data_update
    if MGQ_MpWorld::GameData.fingerprint.empty?
      refuse("Your game data could not be read.")
      return back_to_list
    end

    confirm(:update_data, "Take your game's data as that of #{@entry.name}? Games that differ from yours are then warned or kept out.", "Update it")
  end

  # Finds what of the details the mouse clicked, while the list or the details take the input.
  #
  # @param targets [Array<Symbol>] What the details open.
  # @return [Symbol, nil] :players or :mods, nil without a click on one.
  def clicked_target(targets)
    return nil unless mouse_clicked? && (@focus || @list_window.active) && !targets.empty?

    position = mouse_position
    position && @detail_window.target_at(position[0], position[1])
  end

  # Tells where the mouse points on the game's screen.
  #
  # @return [Array<Integer>, nil] x and y, nil outside the window or without the mouse.
  def mouse_position
    defined?(MGQ_Multiplayer::Mouse) ? MGQ_Multiplayer::Mouse.position : nil
  end

  # Reports whether the left mouse button went down since the last call.
  #
  # @return [Boolean] Whether it went down.
  def mouse_clicked?
    defined?(MGQ_Multiplayer::Mouse) ? MGQ_Multiplayer::Mouse.clicked? : false
  end

  # Opens the list of the chosen world's players to remove one.
  def on_ban
    others = @entry.listed.members.reject { |member| member.id == @me }
    @members_window.start(others.map { |member| [member.name, :member, true, member] } + [["Back", :cancel]])
  end

  # Asks whether to remove the chosen player.
  def on_member
    @target = @members_window.current_ext
    confirm(:ban, "Remove #{@target.name} from #{@entry.name}? They cannot enter it again.", "Remove them")
  end

  # Asks whether to delete the chosen world for everyone.
  def on_delete_world
    confirm(:delete_world, "Delete #{@entry.name} for everyone? Saves stay on each PC.", "Delete it")
  end

  # Copies the chosen world's latest save into the player's own game, see MGQ_MpSaveExport.
  def on_export_save
    say(MGQ_MpSaveExport.export(@entry.local))
    back_to_list
  end

  # Asks whether to delete the player's saves of the chosen world.
  def on_delete_saves
    again = @entry.open? ? "You would start anew." : "You would need its password again, and start anew."
    confirm(:delete_saves, "Delete your saves of #{@entry.name}? #{@entry.listed ? again : ''}", "Delete them")
  end

  # Does what the player confirmed.
  def on_confirmed
    case @confirming
    when :ban
      start_action("ban") { MGQ_MpWorld::Directory.ban(@entry.id, @target.id) }
    when :delete_world
      start_action("delete") { MGQ_MpWorld::Directory.delete(@entry.id) }
    when :delete_saves
      say(@entry.local.delete ? "Your saves of #{@entry.name} were deleted." : "Your saves of #{@entry.name} could not be deleted.")
      look_at_list
      back_to_list
    when :update_data
      update_data
    when :differing
      @confirm_window.finish
      @data_accepted = true
      @after_accept.call
    when :mods
      start_action("mods") { MGQ_MpWorldMods.install(@mod_rows) }
    end
  end

  # Opens the form of the player's name and starts typing into it, as when the screen opens and
  # the player has no name.
  def ask_name
    @list_window.select_symbol(:rename)
    @list_window.deactivate
    @form_symbol = :rename
    @field_index = 0
    @hinted = nil
    @form_window.form = form
    @form_window.select(0)
    start_typing(form.fields.first)
  end

  # Keeps the name the form holds, which the others see from now on.
  def rename_player
    MGQ_Multiplayer::Player.name = form[:name]
    @me = MGQ_MpWorld::Directory.my_id
    @forms[:rename] = MGQ_MpWorld::Form.rename(MGQ_Multiplayer::Player.name.to_s)
    leave_form
    @resume_form = false
    say("The others see you as #{MGQ_Multiplayer::Player.name}.")
  end

  # The form the player fills in, nil while the list has the cursor.
  #
  # @return [MGQ_MpWorld::Form, nil] The form.
  def form
    @form_symbol && @forms[@form_symbol]
  end

  # Moves from the list into the form it points at.
  def enter_form
    @form_symbol = @list_window.current_symbol
    @form_window.select(0)
    @form_window.activate
  end

  # Moves from the form back to the list, keeping what was filled in, unless it changed a world.
  def leave_form
    # Without a name the player cannot be in a world, so the screen closes.
    return return_scene if @form_symbol == :rename && MGQ_Multiplayer::Player.name.nil?

    @forms.delete(:edit_world)
    @form_symbol = nil
    @hinted = nil
    @form_window.unselect
    @form_window.deactivate
    say(HINT)
    @list_window.activate
  end

  # Puts the cursor back on the form after another screen, at the field it left from.
  def return_to_form
    @list_window.select_symbol(@form_symbol) unless @form_symbol == :edit_world
    @list_window.deactivate
    @form_window.form = form
    @form_window.select(@field_index || 0)
    @resume_form = true unless @busy
  end

  # Acts on the chosen field: ticks a checkbox, opens the save screen, sends the form, or starts
  # typing into a text box.
  def on_field
    field = @form_window.field
    @field_index = @form_window.index

    case field.kind
    when :check
      form[field.key] = !form[field.key]
      @form_window.refresh
      @form_window.activate
    when :save
      MGQ_MpSaveDistribution.choose(:world)
    when :button
      field.key == :data ? update_data : send_form
    when :mods
      open_mod_pick
    else
      start_typing(field)
    end
  end

  # Starts typing into a text box in place, or on the text screen when the keyboard cannot reach
  # the game.
  #
  # @param field [MGQ_MpWorld::Form::Field] The text box.
  def start_typing(field)
    return ask_field(field, false) unless MGQ_Multiplayer::Background.running?

    form.editing = field.key
    form.edit = MGQ_MpUi::TextEdit.new(form[field.key], :max_chars => field.max_chars, :allowed => field.allowed)
    @typed_before = form[field.key]
    @typing_frames = 0
    @cursor_shown = true
    MGQ_Multiplayer::Link.typing(true)
    @form_window.refresh
    say(TYPING_HINT)
  end

  # Takes what was typed into the text box and lets its editor follow the keys that move the
  # cursor, or moves the typing to the text screen, whose letters a gamepad can pick, once a
  # button is pressed that did not come from the keyboard.
  def update_typing
    field = @form_window.field
    text, keys = MGQ_Multiplayer::Link.take_typed
    @typing_frames += 1

    # The press that started the typing is still reported in its first frame.
    if keys == 0 && text.empty? && @typing_frames > 1 && MGQ_MpWorld.gamepad_pressed?
      stop_typing
      return ask_field(field, true)
    end

    # The numpad's 0 cancels everywhere else in the game, so it leaves the box instead of typing a 0.
    return type(field, "\e") if numpad_cancel?

    text.each_char do |char|
      type(field, char)
      return unless form.editing
    end

    editor = form.edit
    moved = editor.update_keys(field.kind == :area ? @form_window.current_area_spans(editor.text) : nil)
    form[field.key] = editor.text
    # The blinking cursor is drawn again as it shows and hides.
    return unless moved || editor.cursor_shown? != @cursor_shown

    @cursor_shown = editor.cursor_shown?
    @form_window.redraw_current_item
  end

  # Reports whether the numpad's 0 went down, with Num Lock on or off.
  #
  # @return [Boolean] Whether it did.
  def numpad_cancel?
    NUMPAD_CANCEL_KEYS.map { |code| MGQ_Multiplayer::Key.pressed?(code) }.any?
  end

  # Types one character into the text box at its cursor: Enter keeps the text if it is valid,
  # Escape puts the text back as it was.
  #
  # @param field [MGQ_MpWorld::Form::Field] The text box.
  # @param char [String] The character.
  def type(field, char)
    case form.edit.type(char)
    when :enter
      text, error = form.check(field, form.edit.text)
      return refuse(error) if error

      form[field.key] = text
      Sound.play_ok
      stop_typing
      # The name's form has nothing else to fill in, so Enter keeps the name at once.
      return @form_symbol == :rename ? send_form : nil
    when :escape
      form[field.key] = @typed_before
      Sound.play_cancel
      return stop_typing
    when :refused
      Sound.play_buzzer
    when :edited
      Sound.play_cursor
    end
    form[field.key] = form.edit.text
    @form_window.redraw_current_item
  end

  # Stops typing into the text box and hands the cursor back to the form.
  def stop_typing
    MGQ_Multiplayer::Link.typing(false)
    form.editing = nil
    form.edit = nil
    @form_window.refresh
    @hinted = nil
    @resume_form = true
  end

  # Opens the text screen for a text box.
  #
  # @param field [MGQ_MpWorld::Form::Field] The text box.
  # @param letters [Boolean] Whether to show the game's letters at once, for a gamepad.
  def ask_field(field, letters)
    ask_text([:field, field.key], field.label, form[field.key], :masked => field.kind == :password, :max_chars => field.max_chars, :allowed => field.allowed, :letters => letters)
  end

  # Fills in a text box from the text screen, if the text is valid.
  #
  # @param key [Symbol] The text box's key.
  # @param text [String] The text.
  def fill_field(key, text)
    field = form.fields.find { |candidate| candidate.key == key }
    checked, error = form.check(field, text)

    if error
      say(error)
      # Keeps the reason on screen instead of the field's hint.
      @hinted = @field_index
    else
      form[key] = checked
      @hinted = nil
    end
  end

  # Opens the mod picker over the form: the installed mods and those added by name, as the form
  # names them.
  def open_mod_pick
    @mod_pick = MGQ_MpWorld::ModPick.new(form[:mods], MGQ_MpWorld.installed_mod_names)
    @mod_view = Sprite_MpListBox::View.of("Mods of the world", nil, [], MOD_PICK_HINT)
    @form_window.deactivate
    @mod_pick_hold = true
    show_mod_pick
  end

  # Lists the mod picker anew, keeping the item picked where it can.
  def show_mod_pick
    lines, @mod_targets = mod_pick_lines
    line = @mod_view.selected || 0
    line = [line, lines.size - 1].min
    line -= 1 while line > 0 && lines[line][0] != :item
    @mod_view.lines = lines
    @mod_view.note = nil
    @mod_view.pick(lines[line][0] == :item ? line : @mod_view.items.first)
    @mod_view.column = 0 unless mod_buttons?
    @mod_view.hint = added_mod_picked? ? MOD_PICK_ADDED_HINT : MOD_PICK_HINT unless @mod_edit
  end

  # Tells whether the item picked is a mod added by name, which Delete removes.
  #
  # @return [Boolean] Whether it is.
  def added_mod_picked?
    target = @mod_targets && @mod_view.selected && @mod_targets[@mod_view.selected]
    target.is_a?(Integer) && !@mod_pick.entries[target].installed
  end

  # Takes the mod added by name that is picked out of the picker and the form.
  def remove_added_mod
    return unless added_mod_picked? && @mod_pick.remove(@mod_targets[@mod_view.selected])

    Sound.play_cancel
    form[:mods] = @mod_pick.text
    show_mod_pick
  end

  # Writes the mod picker's lines: the row that lists or unlists every installed mod, the installed
  # mods, the added ones, then the row that adds one. Each mod has a red ! button for required and
  # an orange ? button for essential, below their columns' titles.
  #
  # @return [Array] The lines, see Sprite_MpListBox::View, and what each stands for: a mod's index
  #   in the picker's entries, :all, :add, or nil for a heading. While a name is typed, the last row
  #   is its text box.
  def mod_pick_lines
    entries = @mod_pick.entries
    lines = [[:item, @mod_pick.all_listed? ? "Unlist all your mods" : "List all your mods", :plain, nil]]
    targets = [:all]

    [["Your mods", true], ["Added by name", false]].each do |heading, installed|
      group = (0...entries.size).select { |index| entries[index].installed == installed }
      next if group.empty? && !installed

      lines.push([:head, "#{heading} (#{group.size})", MOD_PICK_COLUMNS])
      targets.push(nil)
      group.each do |index|
        state = entries[index].state
        lines.push([:item, entries[index].name, MOD_STATE_COLORS[state], MOD_STATE_LABELS[state], [["!", :red, state == :required], ["?", :orange, state == :essential]]])
        targets.push(index)
      end
    end
    lines.push(@mod_edit ? [:item, "Name:", :plain, nil, nil, [@mod_edit, @mod_edit.text, @mod_edit.cursor, @mod_edit.cursor_shown?]] : [:item, "Add a mod by name . . .", :plain, nil])
    targets.push(:add)
    [lines, targets]
  end

  # Tells whether the item picked is a mod, with its two buttons.
  #
  # @return [Boolean] Whether it is.
  def mod_buttons?
    @mod_view.selected && @mod_view.lines[@mod_view.selected][4] ? true : false
  end

  # Follows the arrows, confirm, cancel and the mouse while the mod picker is open: up and down
  # pick a row, left and right a mod's buttons, confirm or a click acts on what is picked.
  def update_mod_pick
    @list_box.show(@mod_view)
    return update_mod_typing if @mod_edit

    # The key that opened the picker or ended the typing must not act on it before it is let go.
    return @mod_pick_hold = Input.press?(:C) || Input.press?(:B) if @mod_pick_hold

    if Input.repeat?(:DOWN) || Input.repeat?(:UP)
      @mod_view.move(Input.repeat?(:DOWN) ? 1 : -1)
      @mod_view.column = 0 unless mod_buttons?
    end
    move_mod_column(1) if Input.repeat?(:RIGHT)
    move_mod_column(-1) if Input.repeat?(:LEFT)
    remove_added_mod if MGQ_Multiplayer::Key.pressed?(DELETE_KEY)

    position = mouse_position
    clicked = mouse_clicked?
    line = position && Sprite_MpListBox.line_at(position[0], position[1], @mod_view)

    if line && @mod_view.lines[line][0] == :item && position != @box_pointed
      @mod_view.pick(line)
      @mod_view.column = @mod_view.lines[line][4] ? Sprite_MpListBox.button_at(position[0], 2).to_i : 0
    end
    @box_pointed = position if position

    # Closing the picker clears it, so nothing may draw it afterwards.
    return close_mod_pick if Input.trigger?(:B) || (clicked && position && !Sprite_MpListBox.inside?(position[0], position[1]))

    act_on_mod(@mod_targets[@mod_view.selected], @mod_view.column.to_i) if Input.trigger?(:C) || (clicked && line && @mod_view.lines[line][0] == :item)
    @mod_view.hint = added_mod_picked? ? MOD_PICK_ADDED_HINT : MOD_PICK_HINT
    @list_box.show(@mod_view)
  end

  # Moves the cursor between a mod's name and its two buttons.
  #
  # @param step [Integer] 1 to the right, -1 to the left.
  def move_mod_column(step)
    return unless mod_buttons?

    column = [[@mod_view.column.to_i + step, 0].max, 2].min
    Sound.play_cursor if column != @mod_view.column.to_i
    @mod_view.column = column
  end

  # Acts on what the mod picker points at: lists or unlists a mod, makes it required or essential
  # with its buttons, lists or unlists every installed mod, or asks for the name of a mod to add.
  #
  # @param target [Integer, Symbol] The mod's index in the picker's entries, :all or :add.
  # @param column [Integer] 0 for the mod's name, 1 for its required button, 2 for its essential one.
  def act_on_mod(target, column)
    Sound.play_ok
    return start_mod_typing if target == :add

    error = if target == :all
              @mod_pick.all_listed? ? @mod_pick.unlist_all : @mod_pick.list_all
            elsif column == 0
              @mod_pick.toggle(target)
            else
              @mod_pick.mark(target, column == 1 ? :required : :essential)
            end
    form[:mods] = @mod_pick.text
    show_mod_pick
    refuse_in_pick(error) if error
  end

  # Turns the last row of the picker into a text box for a mod's name, typed on the keyboard.
  def start_mod_typing
    @mod_edit = MGQ_MpUi::TextEdit.new("", :max_chars => MGQ_MpWorld::MAX_MODS_CHARS)
    MGQ_Multiplayer::Link.typing(true)
    @mod_view.hint = TYPING_HINT
    show_mod_pick
  end

  # Takes what was typed into the name's text box: Enter adds the mod, Escape or the numpad's 0 goes
  # back to the picker.
  def update_mod_typing
    text, _keys = MGQ_Multiplayer::Link.take_typed
    # The numpad's 0 cancels everywhere else in the game, so it leaves the box instead of typing a 0.
    return finish_mod_typing(nil) if numpad_cancel?

    text.each_char do |char|
      case @mod_edit.type(char)
      when :enter then return finish_mod_typing(@mod_edit.text)
      when :escape then return finish_mod_typing(nil)
      when :refused then Sound.play_buzzer
      when :edited then Sound.play_cursor
      end
    end

    @mod_edit.update_keys
    show_mod_pick
    @list_box.show(@mod_view)
  end

  # Stops typing the name, and adds the mod when it was entered.
  #
  # @param name [String, nil] The name, nil when the player went back.
  def finish_mod_typing(name)
    MGQ_Multiplayer::Link.typing(false)
    @mod_edit = nil
    @mod_pick_hold = true
    name ? add_mod(name) : Sound.play_cancel
    show_mod_pick unless name
    @list_box.show(@mod_view)
  end

  # Adds a mod by the name typed, picked, or says why it cannot be.
  #
  # @param name [String] The name.
  def add_mod(name)
    return unless @mod_pick

    error = @mod_pick.add(name)
    form[:mods] = @mod_pick.text
    show_mod_pick
    return refuse_in_pick(error) if error

    @mod_view.pick(@mod_targets.index(@mod_pick.entries.size - 1))
    @mod_view.hint = MOD_PICK_ADDED_HINT
  end

  # Says in the mod picker's title row why a change was refused, since the box covers the lines
  # at the top.
  #
  # @param error [String] Why.
  def refuse_in_pick(error)
    Sound.play_buzzer
    @mod_view.note = error
  end

  # Closes the mod picker, back to the form, which shows the mods picked.
  def close_mod_pick
    Sound.play_cancel
    @mod_view = nil
    @mod_pick = nil
    @list_box.hide
    @form_window.refresh
    @hinted = nil
    @resume_form = true
  end

  # Says why something typed or the form is not accepted.
  #
  # @param error [String] Why.
  def refuse(error)
    Sound.play_buzzer
    say(error)
  end

  # Shows the hint of the field the cursor is on, once it moved there.
  def show_field_hint
    return unless form && !form.editing && @form_window.index >= 0 && @form_window.index != @hinted

    @hinted = @form_window.index
    say(@form_window.field.hint)
  end

  # Sends the filled-in form, or points at the first field that keeps it from being sent.
  def send_form
    index, error = form.problem

    if error
      refuse(error)
      @form_window.select(index)
      @hinted = index
      return @resume_form = true
    end

    case @form_symbol
    when :new_world then create_world
    when :edit_world then edit_world
    when :rename then rename_player
    else join_world
    end
  end

  # Takes the chosen hidden world, added by its id and never entered, off the list again.
  def on_forget
    MGQ_MpWorld::Added.remove(@entry.id)
    say("#{@entry.name} was removed from your list.")
    MGQ_MpWorld::Directory.refresh
    back_to_list
  end

  # Opens the form that changes the chosen world, filled in as the world is.
  def on_edit_world
    close_popups
    @forms[:edit_world] = MGQ_MpWorld::Form.edit(@entry.listed, @entry.listed.creator_id == @me)
    @form_symbol = :edit_world
    @field_index = 0
    @hinted = nil
    @list_window.deactivate
    @form_window.form = form
    @form_window.select(0)
    @resume_form = true
  end

  # Changes the chosen world as the form says; its creator's game sends the hashes of its required
  # mods outside the catalog too.
  def edit_world
    values = form
    hashes = @entry.listed.creator_id == @me ? MGQ_MpWorldMods.creator_hashes(values[:mods]) : nil
    start_action("edit") { MGQ_MpWorld::Directory.edit(@entry.id, values[:seats].to_i, values[:description], values[:mods], hashes) }
  end

  # Takes the save picked on the save screen: as the new world's starting save, or as where the
  # player starts in the world they are entering, which update then enters, asking again when they
  # picked none. Called as the world screen starts again.
  def take_start_save
    purpose, index = MGQ_MpSaveDistribution.take_chosen
    return unless purpose

    if purpose == :world
      @forms[:new_world][:save] = index if index
    elsif index
      @own_start = index
      @list_window.deactivate
    else
      ask_start(@starting, @starting_from)
    end
  end

  # Makes the world the form describes, unless it keeps differing games out and the creator's
  # game data cannot be read, which would let every game in.
  def create_world
    values = @forms[:new_world]

    if !values[:mismatch] && MGQ_MpWorld::GameData.fingerprint.empty?
      refuse("Your game data could not be read. Tick Allow data mismatch.")
      return @resume_form = true
    end

    files = values[:from_save] ? MGQ_MpSaveDistribution.files_of(values[:save]) : []
    @creating = values[:name]
    @start_files = files
    about = { :description => values[:description], :mods => values[:mods], :data => MGQ_MpWorld::GameData.fingerprint, :strict => !values[:mismatch],
              :mod_hashes => MGQ_MpWorldMods.creator_hashes(values[:mods]), :settings => "" }
    start_action("create") { MGQ_MpWorld::Directory.create(values[:name], values[:password], values[:seats].to_i, values[:hidden], values[:choose], MGQ_MpSaveDistribution.text_of(files), about) }
  end

  # Looks up the hidden world the form names by its id, to add it to the list.
  def join_world
    @adding = @forms[:join_hidden][:id]
    start_action("find") { MGQ_MpWorld::Directory.find(@adding) }
  end

  # Starts a directory action and waits for it, the input held meanwhile.
  #
  # @param kind [String] The action's kind.
  def start_action(kind)
    close_popups

    unless yield
      Sound.play_buzzer
      say("Another request is still running. Try again in a moment.")
      return back_to_list
    end

    @busy = kind
    @list_window.deactivate
    @form_window.deactivate
    # What the action ends with must not give way to the hint of the field it was sent from.
    @hinted = @form_window.index
    say(BUSY_TEXTS[kind])
  end

  # Acts once the running action ended.
  def follow_action
    action = MGQ_MpWorld::Directory.action
    return if action["state"] == "busy"

    kind = @busy
    @busy = nil
    MGQ_MpWorld::Directory.clear

    if action["state"] == "failed"
      Sound.play_buzzer
      say(action["error"])
      return back_to_list
    end

    case kind
    when "create"
      world = MGQ_MpWorld::World.found(action["code"], @creating, action["world"])

      if world && (@start_files.empty? || MGQ_MpSaveDistribution.place(world, @start_files))
        MGQ_MpWorld::Favourites.add(action["world"])
        # A fresh form keeps the next world from starting as a copy of this one.
        @forms[:new_world] = MGQ_MpWorld::Form.create
        leave_form
        say("#{@creating} was created. Enter it from the list.")
      else
        say(world ? "Your save could not be copied into #{@creating}." : "The world's folder could not be created.")
      end
    when "unlock"
      return if enter_opened(action)
    when "start"
      return start_world(@fetched, true)
    when "mods"
      return restart_for_mods
    when "delete"
      say("#{@entry.name} was deleted for everyone.")
    when "ban"
      say("#{@target.name} was removed from #{@entry.name}.")
    when "find"
      MGQ_MpWorld::Added.add(@adding)
      @forms[:join_hidden] = MGQ_MpWorld::Form.join
      leave_form
      say("#{action['name']} was added to your list.")
    when "data"
      say("The data scan of #{@entry.name} was updated to your game.")
    when "edit"
      leave_form
      say("#{@entry.name} was changed.")
    end

    MGQ_MpWorld::Directory.refresh
    back_to_list
  end

  # Starts the game again once the world's mods are installed, so they load, and enters the world
  # once it is back; says what to do when the game cannot start itself again.
  def restart_for_mods
    MGQ_MpWorldMods.forget_installed
    return SceneManager.exit if MGQ_MpWorldMods.restart(@entry.id)

    say("The mods were installed. Close the game and start it again to enter #{@entry.name}.")
    back_to_list
  end

  # Enters the chosen world, whose lock was opened, or says why it cannot.
  #
  # @param action [Hash] The ended action, with the world's code and id.
  # @return [Boolean] Whether it went on to enter the world.
  def enter_opened(action)
    if action["start"] == "pending"
      Sound.play_buzzer
      say("#{@entry.name} is still being set up by its creator. Try again in a moment.")
      return false
    end

    world = MGQ_MpWorld::World.found(action["code"], @entry.name, action["world"])

    unless world
      say("The world's folder could not be created.")
      return false
    end

    enter(world, @entry.listed.start, @entry.listed.choose)
    true
  end

  # Enters a world, first asking where to start or fetching its starting save when this PC has no
  # save of it yet, or says why it cannot.
  #
  # @param world [MGQ_MpWorld::World] The world.
  # @param start [String, nil] How far it is with its starting save, nil when the list does not tell.
  # @param choose [Boolean, nil] Whether each new player chooses where to start, nil when the list does not tell.
  def enter(world, start, choose)
    return ask_start(world, start) if MGQ_MpSaveDistribution.ask_start?(world, choose)
    return fetch_start(world) if MGQ_MpSaveDistribution.fetch?(world, start)

    start_world(world)
  end

  # Asks a new player of a world whose players choose where to start.
  #
  # @param world [MGQ_MpWorld::World] The world.
  # @param start [String] How far it is with its starting save.
  def ask_start(world, start)
    close_popups
    @list_window.deactivate
    @form_window.deactivate
    @starting = world
    @starting_from = start
    choices = []
    choices.push(["From the creator's save", :from_creator]) if start == "ready"
    choices.push(["At the beginning", :from_beginning])
    choices.push(["From one of my saves", :from_own])
    choices.push(["Back", :cancel])
    say("Where do you start in #{world.name}? A save cannot be undone.")
    @start_window.start(choices)
  end

  # Starts the world from its creator's save, fetching it first.
  def on_from_creator
    fetch_start(@starting)
  end

  # Starts the world at the beginning.
  def on_from_beginning
    @start_window.finish
    start_world(@starting)
  end

  # Opens the save screen to pick the save the player starts the world from.
  def on_from_own
    MGQ_MpSaveDistribution.choose(:own)
  end

  # Copies the save picked on the save screen into the world the player is entering, and enters it.
  # Called by update once the world screen is back.
  def start_from_own
    index = @own_start
    @own_start = nil

    return start_world(@starting, true) if MGQ_MpSaveDistribution.place(@starting, MGQ_MpSaveDistribution.files_of(index))

    # A copy that failed halfway would otherwise be the world's first save.
    MGQ_MpSaveDistribution.discard(@starting)
    refuse("Your save could not be copied into #{@starting.name}.")
    back_to_list
  end

  # Fetches a world's starting save, then enters the world.
  #
  # @param world [MGQ_MpWorld::World] The world.
  def fetch_start(world)
    @fetched = world
    start_action("start") { MGQ_MpSaveDistribution.fetch(world) }
  end

  # Enters a world from its latest save, or at the beginning without one, or says why it cannot.
  #
  # @param world [MGQ_MpWorld::World] The world.
  # @param placed [Boolean] Whether its save was just placed there, which is checked first and
  #   thrown away when it cannot be loaded, so the next entry starts anew instead of failing again.
  def start_world(world, placed = false)
    error = (placed && MGQ_MpSaveDistribution.check(world)) || MGQ_MpWorld.start(world, self)
    return unless error

    MGQ_MpSaveDistribution.discard(world) if placed
    refuse(error)
    back_to_list
  end

  # Asks whether to do something.
  #
  # @param what [Symbol] What is asked about.
  # @param question [String] The question.
  # @param yes [String] The command that does it.
  def confirm(what, question, yes)
    @confirming = what
    say(question)
    @confirm_window.start([[yes, :yes], ["Back", :cancel]])
  end

  # Opens the text screen.
  #
  # @param kind [Symbol, Array] What the text is for, [:field, key] for a text box of the form.
  # @param caption [String] What the screen says it is for.
  # @param default [String] The text it starts with.
  # @param options [Hash] See Scene_MpText#prepare.
  def ask_text(kind, caption, default, options)
    SceneManager.call(Scene_MpText)
    SceneManager.scene.prepare(kind, caption, default, options)
  end

  # Closes the small windows and goes back to the list, or to the form the player was filling in.
  def back_to_list
    close_popups
    show_info
    return if @busy

    return @resume_form = true if form

    # While the cursor is in the details, the list stays still.
    @list_window.activate unless @focus
  end

  # Tells whether one of the small windows takes the input.
  #
  # @return [Boolean] Whether one does.
  def popup_open?
    [@actions_window, @members_window, @confirm_window, @start_window].any? { |window| window.active }
  end

  # Closes the small windows.
  def close_popups
    [@actions_window, @members_window, @confirm_window, @start_window].each { |window| window.finish }
  end

  # Says something in the lines at the top.
  #
  # @param message [String] What to say.
  def say(message)
    @message = message
    show_info
  end

  # Shows who plays, what happened last, and how the list stands.
  def show_info
    name = MGQ_Multiplayer::Player.name
    list = case @list_state
           when "loading" then "The list is being fetched . . ."
           when "failed" then "The list could not be fetched: #{@list_error}"
           end
    @info_window.show([name ? "You play as #{name}." : "You have no name yet.", @message, list])
  end
end

# The left side of the world screen as the screen sees it: the worlds, which scroll, above the
# commands, which stay in place. The player first picks one of the two windows as a whole, so the
# commands are reached without moving past every world, then confirms to move inside it; cancel
# goes back to picking a window. The pane answers for whichever window has the cursor.
class MpWorldListPane
  # Creates the pane with the commands picked, since the worlds arrive later.
  #
  # @param worlds [Window_MpWorldList] The worlds.
  # @param commands [Window_MpWorldCommands] The commands below them.
  def initialize(worlds, commands)
    @worlds = worlds
    @commands = commands
    @focus = :commands
    @inside = false
    @picking = true
    @left_at = {}
    @arrived = false
    [@worlds, @commands].each do |window|
      window.unselect
      window.deactivate
    end
    show_pick
  end

  # Returns the width of the pane.
  #
  # @return [Integer] The width.
  def width
    @worlds.width
  end

  # Returns the height of the pane, both windows'.
  #
  # @return [Integer] The height.
  def height
    @worlds.height + @commands.height
  end

  # Sets what a choice does: entering a world's choices, a command, or leaving the screen, which
  # cancel does while a window is picked and the commands' Back does always.
  #
  # @param symbol [Symbol] :world, a command's symbol or :cancel.
  # @param handler [Method] What it does.
  def set_handler(symbol, handler)
    if symbol == :cancel
      @leave = handler
      @worlds.set_handler(:cancel, method(:back_out))
      @commands.set_handler(:cancel, method(:back_out))
      @commands.set_handler(:back, handler)
    elsif symbol == :world
      @worlds.set_handler(symbol, handler)
    else
      @commands.set_handler(symbol, handler)
    end
  end

  # Finds the window that is picked, or has the cursor on one of its rows.
  #
  # @return [Window_Command] The worlds or the commands.
  def focused
    @focus == :worlds ? @worlds : @commands
  end

  # Tells whether the cursor is on a row inside a window, not around a window as a whole.
  #
  # @return [Boolean] Whether it is.
  def inside?
    @inside
  end

  # Returns the world the cursor is on.
  #
  # @return [MGQ_MpWorld::Entry, nil] The world, nil while the cursor is on a command or around a window.
  def current_ext
    @inside && @focus == :worlds ? @worlds.current_ext : nil
  end

  # Returns the symbol of what the cursor is on.
  #
  # @return [Symbol, nil] :world or a command's symbol, nil while the cursor is around a window.
  def current_symbol
    @inside ? focused.current_symbol : nil
  end

  # Tells whether the pane takes the input.
  #
  # @return [Boolean] Whether one of its windows does, or the pick between them.
  def active
    @inside ? @worlds.active || @commands.active : @picking
  end

  # Lets the window with the cursor take the input, or the pick between the windows.
  def activate
    back_out if @inside && @focus == :worlds && @worlds.item_max == 0

    if @inside
      focused.select(0) if focused.index < 0
      focused.activate
    else
      # The press that led here must not also pick or leave.
      @settling = true
      @picking = true
    end
  end

  # Stops the pane from taking the input.
  def deactivate
    @worlds.deactivate
    @commands.deactivate
    @picking = false
  end

  # Puts the cursor on a command.
  #
  # @param symbol [Symbol] The command's symbol.
  def select_symbol(symbol)
    @focus = :commands
    @inside = true
    @worlds.unselect
    show_pick
    @commands.select_symbol(symbol)
  end

  # Shows other worlds. The first worlds to arrive are picked if the pick still rests where it
  # started, and the commands when the last world went.
  #
  # @param entries [Array<MGQ_MpWorld::Entry>] The worlds.
  def entries=(entries)
    @worlds.entries = entries

    if !@arrived && !entries.empty?
      @arrived = true
      pick(:worlds) if !@inside && @focus == :commands
    elsif @focus == :worlds && entries.empty?
      was_active = active
      back_out if @inside
      pick(:commands)
      @picking = was_active
    end
  end

  # Picks a window as a whole.
  #
  # @param target [Symbol] :worlds or :commands.
  # @return [Boolean] Whether it is picked; not a list without worlds.
  def pick(target)
    return false if @inside || (target == :worlds && @worlds.item_max == 0)

    @focus = target
    show_pick
    true
  end

  # Moves the cursor into the picked window, onto the row it left there.
  #
  # @return [Boolean] Whether it moved; not into a list without worlds.
  def enter
    return false if @inside || (@focus == :worlds && @worlds.item_max == 0)

    @inside = true
    @picking = false
    show_pick
    focused.select([[@left_at[@focus] || 0, 0].max, focused.item_max - 1].min)
    focused.activate
    true
  end

  # Moves the cursor out of a window and around it, back to the pick between the windows.
  def back_out
    return unless @inside

    @left_at[@focus] = focused.index
    focused.unselect
    focused.deactivate
    @inside = false
    @picking = true
    @settling = true
    show_pick
  end

  # Follows the keys while a window is picked: up and down pick the other one, confirm moves
  # into it, cancel leaves the screen. Called by the screen after its windows updated.
  def update
    return if @inside || !@picking || @settling

    if Input.trigger?(:C)
      enter ? Sound.play_ok : Sound.play_buzzer
    elsif Input.trigger?(:B)
      Sound.play_cancel
      @leave.call if @leave
    elsif Input.trigger?(:DOWN) || Input.trigger?(:UP)
      Sound.play_cursor if pick(@focus == :worlds ? :commands : :worlds)
    end
  end

  # Draws the cursor around the picked window, or around none while the cursor is inside one.
  def show_pick
    @worlds.boxed = !@inside && @focus == :worlds
    @commands.boxed = !@inside && @focus == :commands
  end

  # Ends the frame the pick began in. Called by the screen before its windows update.
  def settle
    @settling = false
  end
end

# Lets a window of the left side show the cursor around all it shows, while the player picks
# between the windows.
module MGQ_MpBoxCursor
  # Draws the cursor around the whole window, or gives it back to the rows.
  #
  # @param boxed [Boolean] Whether the window is picked as a whole.
  def boxed=(boxed)
    @boxed = boxed
    update_cursor
  end

  # Keeps the cursor around all the window shows while it is picked as a whole.
  def update_cursor
    return super unless @boxed

    cursor_rect.set(0, oy, contents_width, height - standard_padding * 2)
  end
end

# The worlds at the left of the world screen, which scroll, with a bar at the right that tells
# where the list stands while not all of them fit.
class Window_MpWorldList < Window_Command
  # Width of the window.
  WIDTH = 230

  # Width kept free at the right of a world's name for its players online and seats.
  COUNT_WIDTH = 52

  # Width of the scrollbar.
  BAR_WIDTH = 4

  # Colors of the scrollbar's track and of its thumb.
  TRACK_COLOR = Color.new(0, 0, 0, 96)
  THUMB_COLOR = Color.new(255, 255, 255, 160)

  include MGQ_MpBoxCursor

  # Creates the list below the lines.
  #
  # @param y [Integer] The top edge.
  # @param height [Integer] The height.
  def initialize(y, height)
    @entries = []
    @height = height
    super(0, y)
    @bar = Sprite.new
    @bar.bitmap = Bitmap.new(BAR_WIDTH, height - standard_padding * 2)
    @bar.x = WIDTH - BAR_WIDTH - 5
    @bar.y = y + standard_padding
    @bar.z = z + 1
    @bar_drawn = nil
    update_bar
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

  # Shows other worlds, keeping the world chosen, or no cursor while the commands have it.
  #
  # @param entries [Array<MGQ_MpWorld::Entry>] The worlds.
  def entries=(entries)
    signatures = entries.map { |entry| entry.signature }
    return if signatures == @signatures

    @signatures = signatures
    chosen = current_ext
    at = index
    @entries = entries
    clear_command_list
    make_command_list
    refresh
    return unselect if at < 0

    again = chosen && @list.index { |command| command[:ext].id == chosen.id && command[:ext].name == chosen.name }
    select(again || [[at, 0].max, item_max - 1].min)
  end

  # Lists the worlds.
  def make_command_list
    (@entries || []).each { |entry| add_command(entry.name, :world, true, entry) }
  end

  # Draws a world with its players online and seats, a featured one in gold, a favourite with a
  # mark, and one its creator deleted pale.
  #
  # @param index [Integer] The row.
  def draw_item(index)
    entry = @list[index][:ext]
    rect = item_rect_for_text(index)
    rect.width -= BAR_WIDTH + 2
    change_color(entry.featured? ? MGQ_MpWorld::FEATURED_COLOR : entry.favourite ? crisis_color : normal_color, !entry.gone)
    draw_text(rect, "#{entry.listed.online}/#{entry.listed.seats}", 2) if entry.listed
    rect.width -= COUNT_WIDTH if entry.listed
    draw_text(rect, entry.favourite ? "* #{entry.name}" : entry.name)
  end

  # Keeps the scrollbar where the list stands.
  def update
    super
    update_bar if @bar
  end

  # Draws the scrollbar if the list moved or changed its length: a thumb as long as the share of
  # the worlds in sight, hidden while all of them fit.
  def update_bar
    rows = item_max
    page = page_row_max
    @bar.visible = visible && rows > page
    state = [rows, page, top_row]
    return if state == @bar_drawn || !@bar.visible

    @bar_drawn = state
    track = @bar.bitmap.height
    thumb = [track * page / rows, 8].max
    top = (track - thumb) * top_row / [rows - page, 1].max
    @bar.bitmap.clear
    @bar.bitmap.fill_rect(0, 0, BAR_WIDTH, track, TRACK_COLOR)
    @bar.bitmap.fill_rect(0, top, BAR_WIDTH, thumb, THUMB_COLOR)
  end

  # Frees the scrollbar with the window.
  def dispose
    @bar.bitmap.dispose
    @bar.dispose
    super
  end
end

# What the world screen offers besides the worlds, in a window of its own below them, so it stays
# in place while the worlds scroll.
class Window_MpWorldCommands < Window_Command
  include MGQ_MpBoxCursor

  # Creates the window at the bottom left of the screen.
  def initialize
    super(0, 0)
    self.y = Graphics.height - height
  end

  # Returns the window's width, the world list's.
  #
  # @return [Integer] The width.
  def window_width
    Window_MpWorldList::WIDTH
  end

  # Lists the commands.
  def make_command_list
    add_command("Create new world", :new_world)
    add_command("Add a hidden world", :join_hidden)
    add_command("Change your name", :rename)
    add_command("Back", :back)
  end
end

# What the windows at the right of the world screen share, the world's details and the forms: the
# measures and colors of their panels, groups of rows under a heading, and how texts are fitted.
module MGQ_MpWorldPanels
  # Height of the line at the top: the world's name or the form's title.
  TITLE_HEIGHT = 24

  # Height of a panel's heading.
  HEADER_HEIGHT = 16

  # Height of a row.
  ROW_HEIGHT = 21

  # Height of a line of the description.
  DESCRIPTION_LINE_HEIGHT = 16

  # Space inside a panel's edge, and between two cells of a row.
  PAD = 3

  # Space between two panels.
  GAP = 3

  # Font sizes of the headings, the labels, the values and the description.
  HEADER_SIZE = 13
  LABEL_SIZE = 15
  VALUE_SIZE = 18
  DESCRIPTION_SIZE = 15

  # Fill behind a panel.
  PANEL_COLOR = Color.new(0, 0, 0, 56)

  # Fill behind a value.
  TEXT_BOX_COLOR = Color.new(0, 0, 0, 96)

  # Draws a panel's heading in small capitals, and what it says at its right.
  #
  # @param title [String] The heading.
  # @param note [String, nil] What it says at its right.
  # @param x [Integer] The left edge.
  # @param y [Integer] The top edge.
  def draw_header(title, note, x, y)
    contents.font.size = HEADER_SIZE
    change_color(system_color)
    draw_text(x, y + PAD, contents_width - x - PAD, HEADER_HEIGHT, title.upcase)
    return unless note

    change_color(normal_color, false)
    draw_text(x, y + PAD, contents_width - x - PAD, HEADER_HEIGHT, note, 2)
  end

  # Cuts a text at its end until it fits, in the font set.
  #
  # @param text [String] The text.
  # @param width [Integer] The width it may take.
  # @return [String] The text, or its start before two dots.
  def cut(text, width)
    return text if text_size(text).width <= width

    text = text[0...-1] while text.size > 1 && text_size("#{text}..").width > width
    "#{text.rstrip}.."
  end
end

# The chosen world's details at the right of the world screen, laid out like its forms: labels with
# their values on darker boxes, grouped under headings. The world itself comes first, then how the
# player's game compares with its creator's, its players, and its description at the bottom.
class Window_MpWorldDetail < Window_Base
  include MGQ_MpWorldPanels

  # A group of rows under a heading.
  #
  # @!attribute title [String] The heading.
  # @!attribute note [String, nil] What the heading says at its right, nil for nothing.
  # @!attribute rows [Array<Array<Cell>>] The rows, each one cell across the panel or two side by side.
  # @!attribute target [Symbol, nil] What the whole panel opens, nil for nothing.
  Panel = Struct.new(:title, :note, :rows, :target)

  # A value on a darker box.
  #
  # @!attribute label [String, nil] What it is called, nil for a box across the whole cell.
  # @!attribute text [String] The value.
  # @!attribute color [Symbol] :normal, :good for what is fine or online, or :warn.
  # @!attribute target [Symbol, nil] What the cell opens, nil for nothing.
  # @!attribute chips [Array<String>, nil] Values shown in a box each instead of the text, nil for the text.
  # @!attribute chip_colors [Hash, nil] The color of chips drawn in another than the cell's, by their text: :good, :bad or :gold.
  Cell = Struct.new(:label, :text, :color, :target, :chips, :chip_colors)

  # Space inside a chip's left and right edge, and between two chips.
  CHIP_PAD = 6
  CHIP_GAP = 4

  # Width of the labels in front of the values.
  LABEL_WIDTH = 68

  # Width of the bar at the left of the description.
  ACCENT_WIDTH = 3

  # Most players the players' panel names; one more place counts the rest.
  NAMED_PLAYERS = 4

  # Most parts of the game data a row names before it counts the rest.
  NAMED_PARTS = 2

  # Creates the window beside the list.
  #
  # @param x [Integer] The left edge.
  # @param y [Integer] The top edge.
  # @param height [Integer] The height.
  def initialize(x, y, height)
    super(x, y, Graphics.width - x, height)
    @shown = :nothing
    @targets = {}
  end

  # Shows a world, if it is another than shown or shows something else by now.
  #
  # @param entry [MGQ_MpWorld::Entry, nil] The world, nil for none.
  # @param me [String] The player's id.
  def show(entry, me)
    signature = [entry && entry.signature, me]
    return if signature == @shown

    @shown = signature
    @targets = {}
    contents.clear
    return unless entry

    y = draw_title(entry) + GAP
    panels(entry, me).each { |panel| y = draw_panel(panel, y) + GAP }
    draw_description(entry.listed.description.to_s, y) if entry.listed
    reset_font_settings
  end

  # Lists what the panels say about a world.
  #
  # @param entry [MGQ_MpWorld::Entry] The world.
  # @param me [String] The player's id.
  # @return [Array<Panel>] The panels, from the top.
  def panels(entry, me)
    listed = entry.listed
    return [Panel.new("World", nil, [[Cell.new("Status", entry.gone ? "Only on this PC: deleted, or you were removed" : "Not in the list right now", :normal)]])] unless listed

    [world_panel(listed, me), data_panel(entry, me), players_panel(listed, me)]
  end

  # Tells who made a world, how full it is, how it is entered and where its new players start.
  #
  # @param listed [MGQ_MpWorld::Directory::ListedWorld] The world in the directory.
  # @param me [String] The player's id.
  # @return [Panel] The panel.
  def world_panel(listed, me)
    rows = [
      [Cell.new("Creator", listed.creator_id == me ? "You" : listed.creator_name, :normal), Cell.new("Players", "#{listed.online} / #{listed.seats} online", :normal)],
      [Cell.new("Password", listed.open ? "None" : "Needed", :normal), Cell.new("Listed", listed.hidden ? "Hidden" : "Public", :normal)],
      [Cell.new("Start", start_text(listed), :normal)],
    ]
    Panel.new("World", listed.featured ? "featured: one of the relay's own" : nil, rows)
  end

  # Tells the mods a world needs, whether the player's game data matches that of its creator, and
  # which games may enter.
  #
  # @param entry [MGQ_MpWorld::Entry] The world, which the directory lists.
  # @param me [String, nil] The player's id, who may update the game data of a world of their own.
  # @return [Panel] The panel.
  def data_panel(entry, me = nil)
    listed = entry.listed
    mods = MGQ_MpWorld.mods_of(listed.mods)
    differing = entry.differing
    # The creator's game is the world's measure: once it differs, or the world tells none, they
    # may take it as the world's.
    update = listed.creator_id == me && (differing.nil? || !differing.empty?) ? :data : nil
    game = if differing.nil?
             Cell.new("Your game", update ? "Not compared. Confirm to set yours" : "Not compared: the world does not tell", :normal, update)
           elsif differing.empty?
             Cell.new("Your game", "Matches the creator's", :good)
           else
             Cell.new("Your game", "Differs: #{MGQ_MpWorld::GameData.text(differing, NAMED_PARTS)}", :warn, update)
           end
    note = if update
             "confirm on Your game: update"
           elsif listed.strict
             "same data only"
           elsif differing
             "differing games are warned"
           end
    colors = mod_colors(listed.mods, differing, MGQ_MpWorldMods.differing(listed))
    Panel.new("Game data", note, [[Cell.new("Mods", mods.empty? ? "No mod named" : mods.join(", "), :normal, mods.empty? ? nil : :mods, mods.empty? ? nil : mods, colors)], [game]])
  end

  # Tells the colors of a world's marked mods: a required one in the color of what is fine while
  # this game has its script in the world's version, in gold in another version, and in the color
  # of what is wrong while it lacks it; an essential one in the color of what is fine while this
  # game's data matches the world's, and in gold otherwise.
  #
  # @param text [String, nil] The mods as the world's creator wrote them.
  # @param differing [Array<String>, nil] What of this game's data differs from the world's.
  # @param rows [Array<MGQ_MpWorldMods::Row>, nil] The required mods this game has in another version or lacks.
  # @return [Hash] The color by the mod's name.
  def mod_colors(text, differing = nil, rows = nil)
    colors = {}
    MGQ_MpWorld.required_mods(text).each { |mod| colors[mod] = MGQ_MpWorld.installed_mod?(mod) ? :good : :bad }
    (rows || []).each { |row| colors[row.name] = :gold if row.yours != "not installed" }
    MGQ_MpWorld.essential_mods(text).each { |mod| colors[mod] = differing && differing.empty? ? :good : :gold }
    colors
  end

  # Places values in boxes of their own along a row, as many as fit, with a last box that counts
  # the rest. Measured in the font set.
  #
  # @param texts [Array<String>] The values, at least one.
  # @param width [Integer] The width of the row.
  # @return [Array<Array>] Each box's text, left edge and width.
  def chips(texts, width)
    size = lambda { |text| text_size(text).width + CHIP_PAD * 2 }
    named = texts.size

    loop do
      rest = texts.size - named
      labels = texts.first(named) + (rest > 0 ? ["+#{rest} more"] : [])
      widths = labels.map { |label| size.call(label) }
      needed = widths.inject(0) { |sum, chip| sum + chip } + CHIP_GAP * (labels.size - 1)

      if needed > width && named == 1
        # Not even the first value fits beside the count: it is cut to what is left.
        labels[0] = cut(labels[0], width - (needed - widths[0]) - CHIP_PAD * 2)
        widths[0] = size.call(labels[0])
        needed = width
      end

      if needed <= width
        left = 0
        return labels.each_with_index.map { |label, index| place = [label, left, widths[index]]; left += widths[index] + CHIP_GAP; place }
      end

      named -= 1
    end
  end

  # Names a world's players, those online first as the directory lists them, two to a row.
  #
  # @param listed [MGQ_MpWorld::Directory::ListedWorld] The world in the directory.
  # @param me [String] The player's id.
  # @return [Panel] The panel.
  def players_panel(listed, me)
    members = listed.members
    named = members.size > NAMED_PLAYERS ? members.first(NAMED_PLAYERS - 1) : members
    cells = named.map { |member| Cell.new(nil, member.id == me ? "#{member.name} (you)" : member.name, member.online ? :good : :normal) }
    cells.push(Cell.new(nil, "and #{members.size - named.size} more", :normal)) if named.size < members.size
    rows = []
    cells.each_slice(2) { |pair| rows.push(pair.size == 2 ? pair : pair + [nil]) }
    Panel.new("Players", "#{members.size} joined", rows, :players)
  end

  # Lists what the details shown open, from the top: the mods, the creator's update of the game
  # data, the players, the description.
  #
  # @return [Array<Symbol>] :mods, :data, :players and :description, those the world shown has.
  def targets
    [:mods, :data, :players, :description].select { |target| @targets[target] }
  end

  # Puts the cursor on what the details open, or takes it away.
  #
  # @param target [Symbol, nil] :mods or :players, nil for no cursor.
  def focus(target)
    rect = target && @targets[target]
    rect ? cursor_rect.set(rect.x, rect.y, rect.width, rect.height) : cursor_rect.empty
    self.active = !rect.nil?
  end

  # Finds what the details open under a point of the screen.
  #
  # @param x [Integer] The point's x.
  # @param y [Integer] The point's y.
  # @return [Symbol, nil] :mods or :players, nil elsewhere.
  def target_at(x, y)
    inside_x = x - self.x - standard_padding
    inside_y = y - self.y - standard_padding
    targets.find do |target|
      rect = @targets[target]
      inside_x >= rect.x && inside_x < rect.x + rect.width && inside_y >= rect.y && inside_y < rect.y + rect.height
    end
  end

  # Tells where a world's new players start.
  #
  # @param listed [MGQ_MpWorld::Directory::ListedWorld] The world in the directory.
  # @return [String] The text.
  def start_text(listed)
    return "Its creator is still setting it up" if listed.start == "pending"
    return "Your choice: beginning, own or creator's save" if listed.choose && listed.start == "ready"
    return "Your choice: beginning or own save" if listed.choose
    return "The creator's save" if listed.start == "ready"

    "The beginning"
  end

  # Tells when the player last played a world.
  #
  # @param world [MGQ_MpWorld::World, nil] The world on this PC, nil before the player entered it.
  # @return [String] The text.
  def played_text(world)
    return "not entered yet" unless world

    world.played_at ? "last played #{world.played_at.strftime('%Y-%m-%d')}" : "entered, not played yet"
  end

  # Draws the world's name, a featured one in gold, and at its right when the player last played it.
  #
  # @param entry [MGQ_MpWorld::Entry] The world.
  # @return [Integer] The bottom edge.
  def draw_title(entry)
    played = played_text(entry.local)
    contents.font.size = LABEL_SIZE
    played_width = text_size(played).width + 4
    change_color(normal_color, false)
    draw_text(contents_width - played_width, 0, played_width, TITLE_HEIGHT, played, 2)
    reset_font_settings
    change_color(entry.featured? ? MGQ_MpWorld::FEATURED_COLOR : system_color)
    draw_text(0, 0, contents_width - played_width - PAD, TITLE_HEIGHT, entry.name)
    TITLE_HEIGHT
  end

  # Draws a panel: its fill, its heading and its rows.
  #
  # @param panel [Panel] The panel.
  # @param y [Integer] The top edge.
  # @return [Integer] The bottom edge.
  def draw_panel(panel, y)
    height = HEADER_HEIGHT + panel.rows.size * ROW_HEIGHT + PAD * 2
    contents.fill_rect(0, y, contents_width, height, PANEL_COLOR)
    draw_header(panel.title, panel.note, PAD, y)
    @targets[panel.target] = Rect.new(0, y, contents_width, height) if panel.target

    panel.rows.each_with_index do |cells, row|
      width = (contents_width - PAD * (cells.size + 1)) / cells.size
      cells.each_with_index do |cell, column|
        draw_cell(cell, PAD + column * (width + PAD), y + HEADER_HEIGHT + PAD + row * ROW_HEIGHT, width) if cell
      end
    end
    y + height
  end

  # Draws a cell: its label, then its value on a darker box, as a text box of a form, or its
  # values on a box each.
  #
  # @param cell [Cell] The cell.
  # @param x [Integer] The left edge.
  # @param y [Integer] The top edge.
  # @param width [Integer] The width.
  def draw_cell(cell, x, y, width)
    label_width = cell.label ? LABEL_WIDTH : 0
    @targets[cell.target] = Rect.new(x, y, width, ROW_HEIGHT) if cell.target

    if cell.label
      contents.font.size = LABEL_SIZE
      change_color(system_color)
      draw_text(x, y, label_width, ROW_HEIGHT, cell.label)
    end

    contents.font.size = VALUE_SIZE
    change_color(color_of(cell.color))

    if cell.chips
      chips(cell.chips, width - label_width).each do |text, left, chip_width|
        contents.fill_rect(x + label_width + left, y + 1, chip_width, ROW_HEIGHT - 2, TEXT_BOX_COLOR)
        change_color(color_of((cell.chip_colors && cell.chip_colors[text]) || cell.color))
        draw_text(x + label_width + left, y, chip_width, ROW_HEIGHT, text, 1)
      end
      return
    end

    box = Rect.new(x + label_width, y + 1, width - label_width, ROW_HEIGHT - 2)
    contents.fill_rect(box, TEXT_BOX_COLOR)
    draw_text(box.x + 4, y, box.width - 8, ROW_HEIGHT, cut(cell.text, box.width - 8))
  end

  # Draws the description in a panel that takes the rest of the window, as many lines as fit.
  #
  # @param text [String] The description, empty for none.
  # @param y [Integer] The top edge.
  def draw_description(text, y)
    height = contents_height - y
    rows = (height - HEADER_HEIGHT - PAD * 2) / DESCRIPTION_LINE_HEIGHT
    return if rows < 1

    contents.fill_rect(0, y, contents_width, height, PANEL_COLOR)
    contents.fill_rect(0, y, ACCENT_WIDTH, height, system_color)
    @targets[:description] = Rect.new(0, y, contents_width, height) unless text.empty?
    x = ACCENT_WIDTH + PAD * 2
    width = contents_width - x - PAD
    draw_header("Description", nil, x, y)
    contents.font.size = DESCRIPTION_SIZE
    change_color(normal_color, !text.empty?)

    description_lines(text, width, rows).each_with_index do |line, row|
      draw_text(x, y + HEADER_HEIGHT + PAD + row * DESCRIPTION_LINE_HEIGHT, width, DESCRIPTION_LINE_HEIGHT, line)
    end
  end

  # Breaks the description into the lines shown, the last one cut when there are more.
  #
  # @param text [String] The description, empty for none.
  # @param width [Integer] The width a line may take.
  # @param rows [Integer] How many lines fit.
  # @return [Array<String>] The lines.
  def description_lines(text, width, rows)
    lines = text.empty? ? ["No description."] : MGQ_MpUi.wrap(self, text, width)
    return lines if lines.size <= rows

    lines = lines.first(rows)
    lines[-1] = cut("#{lines[-1]} ..", width)
    lines
  end

  # Finds the color a cell asks for.
  #
  # @param name [Symbol] :normal, :good, :warn, :gold or :bad.
  # @return [Color] The color.
  def color_of(name)
    case name
    when :good then power_up_color
    when :warn then crisis_color
    when :gold then MGQ_MpWorld::FEATURED_COLOR
    when :bad then knockout_color
    else normal_color
    end
  end

end

# A small command window in the middle of the screen, closed until needed, whose commands are
# set as it opens.
class Window_MpChoice < Window_Command
  # Width of the window.
  WIDTH = 360

  # Creates the window, closed.
  def initialize
    @choices = []
    super(0, 0)
    self.z = 200
    self.openness = 0
    deactivate
  end

  # Returns the window's width.
  #
  # @return [Integer] The width.
  def window_width
    WIDTH
  end

  # Returns how many rows are shown at once.
  #
  # @return [Integer] The rows, at most ten.
  def visible_line_number
    [[item_max, 1].max, 10].min
  end

  # Lists the commands set last.
  def make_command_list
    @choices.each { |name, symbol, enabled, ext| add_command(name, symbol, enabled != false, ext) }
  end

  # Opens the window with commands and takes the input.
  #
  # @param choices [Array<Array>] Each command's name, symbol, and optionally whether it is enabled and its extra value.
  def start(choices)
    @choices = choices
    clear_command_list
    make_command_list
    self.height = window_height
    create_contents
    refresh
    self.x = (Graphics.width - width) / 2
    self.y = (Graphics.height - height) / 2
    select(0)
    open
    activate
  end

  # Closes the window.
  def finish
    close
    deactivate
  end
end

# A form at the right of the world screen, in place of a world's details and laid out like them:
# its title, then its fields in panels, text boxes, checkboxes, a save to choose and a box of
# several lines, and below them the button that sends it. Up and down move between rows, left and
# right between two fields on one row.
class Window_MpWorldForm < Window_Selectable
  include MGQ_MpWorldPanels

  # Width of the labels in front of the text boxes.
  LABEL_WIDTH = 84

  # Side of a checkbox.
  BOX_SIZE = 12

  # Height of the button that sends the form.
  BUTTON_HEIGHT = 20

  # Room between a text box's edge and its text.
  TEXT_INSET = 4

  # The form shown, nil for none.
  attr_reader :form

  # Creates the window, hidden and without a form.
  #
  # @param x [Integer] The left edge.
  # @param y [Integer] The top edge.
  # @param width [Integer] The width.
  # @param height [Integer] The height.
  def initialize(x, y, width, height)
    @form = nil
    @rects = []
    @widths = {}
    super
    self.visible = false
    deactivate
  end

  # Shows a form, if it is another than shown.
  #
  # @param form [MGQ_MpWorld::Form] The form.
  def form=(form)
    return if form.equal?(@form)

    @form = form
    unselect
    refresh
  end

  # Counts the fields.
  #
  # @return [Integer] One per field of the form.
  def item_max
    @form ? @form.fields.size : 0
  end

  # Finds the field the cursor is on.
  #
  # @return [MGQ_MpWorld::Form::Field, nil] The field, nil without a cursor.
  def field
    @form && index >= 0 ? @form.fields[index] : nil
  end

  # Tells where a field is drawn, as the last refresh placed it.
  #
  # @param index [Integer] The field's index.
  # @return [Rect] Where, a copy the caller may change.
  def item_rect(index)
    rect = @rects[index]
    rect ? Rect.new(rect.x, rect.y, rect.width, rect.height) : Rect.new(0, 0, 0, 0)
  end

  # Tells whether the field the cursor is on can be used.
  #
  # @return [Boolean] Whether it can.
  def current_item_enabled?
    field ? @form.enabled?(field) : false
  end

  # Draws the title, the panels and every field.
  def refresh
    contents.clear
    return unless @form

    reset_font_settings
    change_color(system_color)
    draw_text(0, 0, contents_width, TITLE_HEIGHT, @form.title)
    @rects = places(@form.fields) { |group, y, height| draw_group(group, y, height) }
    draw_all_items
    reset_font_settings
  end

  # Places the fields below the title: each group's rows in a panel under the group's heading,
  # and fields without a group, such as the button, in rows of their own.
  #
  # @param fields [Array<MGQ_MpWorld::Form::Field>] The fields.
  # @yieldparam group [String] A group.
  # @yieldparam y [Integer] The top edge of its panel.
  # @yieldparam height [Integer] The height of its panel.
  # @return [Array<Rect>] Where each field is drawn, by the field's index.
  def places(fields)
    rects = []
    y = TITLE_HEIGHT + GAP

    fields.map { |field| field.group }.uniq.each do |group|
      top = y
      y += HEADER_HEIGHT + PAD if group
      grouped = fields.select { |field| field.group == group }

      grouped.map { |field| field.row }.uniq.each do |row|
        on_row = grouped.select { |field| field.row == row }
        height = on_row.map { |field| height_of(field) }.max
        on_row.each { |field| rects[fields.index(field)] = place(field, y, height) }
        y += height
      end

      y += PAD if group
      yield group, top, y - top if group
      y += GAP
    end
    rects
  end

  # Places a field on its row: across the row, or on its half of it.
  #
  # @param field [MGQ_MpWorld::Form::Field] The field.
  # @param y [Integer] The row's top edge.
  # @param height [Integer] The row's height.
  # @return [Rect] Where it is drawn.
  def place(field, y, height)
    inset = field.group ? PAD : 0
    width = contents_width - inset * 2
    return Rect.new(inset, y, width, height) unless field.side

    half = (width - PAD) / 2
    Rect.new(field.side == :right ? inset + half + PAD : inset, y, half, height)
  end

  # Tells how high a field's row is.
  #
  # @param field [MGQ_MpWorld::Form::Field] The field.
  # @return [Integer] The height.
  def height_of(field)
    case field.kind
    when :area then field.lines * DESCRIPTION_LINE_HEIGHT + 2
    when :button then BUTTON_HEIGHT
    else ROW_HEIGHT
    end
  end

  # Draws a group's panel: its fill and its heading.
  #
  # @param group [String] The group.
  # @param y [Integer] The top edge.
  # @param height [Integer] The height.
  def draw_group(group, y, height)
    contents.fill_rect(0, y, contents_width, height, PANEL_COLOR)
    draw_header(group, nil, PAD, y)
  end

  # Clears a field's place, down to its panel's fill.
  #
  # @param index [Integer] The field's index.
  def clear_item(index)
    rect = item_rect(index)
    contents.clear_rect(rect)
    contents.fill_rect(rect, PANEL_COLOR) if @form.fields[index].group
  end

  # Draws a field: a text box, a checkbox, a save, a box of several lines or the button.
  #
  # @param index [Integer] The field's index.
  def draw_item(index)
    field = @form.fields[index]
    rect = item_rect(index)

    case field.kind
    when :check then draw_check(rect, field)
    when :button then draw_button(rect, field)
    when :area then draw_area(rect, field)
    else draw_box(rect, field, @form.enabled?(field))
    end
  end

  # Draws a text box or the save to choose: its label, then its value on a darker box.
  #
  # @param rect [Rect] Where.
  # @param field [MGQ_MpWorld::Form::Field] The field.
  # @param enabled [Boolean] Whether it can be used.
  def draw_box(rect, field, enabled)
    contents.font.size = LABEL_SIZE
    change_color(system_color, enabled)
    draw_text(rect.x, rect.y, LABEL_WIDTH, rect.height, field.label)
    box = Rect.new(rect.x + LABEL_WIDTH, rect.y + 1, rect.width - LABEL_WIDTH, rect.height - 2)
    contents.fill_rect(box, TEXT_BOX_COLOR)
    contents.font.size = VALUE_SIZE
    change_color(normal_color, enabled)
    inner = Rect.new(box.x + TEXT_INSET, rect.y, box.width - TEXT_INSET * 2, rect.height)
    return draw_text(inner.x, inner.y, inner.width, inner.height, cut(value_text(field), inner.width)) unless @form.editing == field.key

    MGQ_MpUi::TextBox.draw_line(contents, inner, @form.edit, value_text(field))
  end

  # Draws a box of several lines, such as the description: its text broken into lines, or what it
  # is for while it is empty. While typed into, it shows the lines around the cursor, and the
  # cursor; otherwise its first lines.
  #
  # @param rect [Rect] Where.
  # @param field [MGQ_MpWorld::Form::Field] The field.
  def draw_area(rect, field)
    box = Rect.new(rect.x, rect.y + 1, rect.width, rect.height - 2)
    contents.fill_rect(box, TEXT_BOX_COLOR)
    contents.font.size = DESCRIPTION_SIZE
    text = @form[field.key].to_s
    editing = @form.editing == field.key
    change_color(normal_color, editing || !text.empty?)
    inner = Rect.new(box.x + TEXT_INSET, box.y, box.width - TEXT_INSET * 2, box.height)
    return draw_text(inner.x, inner.y, inner.width, DESCRIPTION_LINE_HEIGHT, field.label) if text.empty? && !editing

    spans = area_spans(text, inner.width)
    return MGQ_MpUi::TextBox.draw_area(contents, inner, @form.edit, spans, DESCRIPTION_LINE_HEIGHT) if editing

    spans.first(field.lines).each_with_index do |(start, length), row|
      line = text[start, length]
      line = cut("#{line.rstrip} ..", inner.width) if row == field.lines - 1 && spans.size > field.lines
      draw_text(inner.x, inner.y + row * DESCRIPTION_LINE_HEIGHT, inner.width, DESCRIPTION_LINE_HEIGHT, line)
    end
  end

  # Breaks the text of a box of several lines into lines, each a stretch of the text.
  #
  # Words are measured once and their widths kept, since a text is broken again with every key.
  #
  # @param text [String] The text.
  # @param width [Integer] The width a line may take.
  # @return [Array<Array<Integer>>] Each line's first character and length, see MGQ_MpUi.wrap_spans.
  def area_spans(text, width)
    @widths = {} if @widths.size > 2000
    contents.font.size = DESCRIPTION_SIZE
    MGQ_MpUi.wrap_spans(text, width) { |part| @widths[part] ||= text_size(part).width }
  end

  # Breaks a text into the lines the box of several lines the cursor is on draws it in.
  #
  # @param text [String] The text.
  # @return [Array<Array<Integer>>] Each line's first character and length, see MGQ_MpUi.wrap_spans.
  def current_area_spans(text)
    area_spans(text, item_rect(index).width - TEXT_INSET * 2)
  end

  # Draws the button that sends the form, on a darker box.
  #
  # @param rect [Rect] Where.
  # @param field [MGQ_MpWorld::Form::Field] The button.
  def draw_button(rect, field)
    contents.fill_rect(rect.x, rect.y + 1, rect.width, rect.height - 2, TEXT_BOX_COLOR)
    contents.font.size = VALUE_SIZE
    change_color(normal_color)
    draw_text(rect, field.label, 1)
  end

  # Draws a checkbox and its label, the box filled while ticked.
  #
  # @param rect [Rect] Where.
  # @param field [MGQ_MpWorld::Form::Field] The checkbox.
  def draw_check(rect, field)
    box = Rect.new(rect.x + 2, rect.y + (rect.height - BOX_SIZE) / 2, BOX_SIZE, BOX_SIZE)
    contents.fill_rect(box, normal_color)
    contents.clear_rect(box.x + 1, box.y + 1, BOX_SIZE - 2, BOX_SIZE - 2)
    contents.fill_rect(box.x + 1, box.y + 1, BOX_SIZE - 2, BOX_SIZE - 2, TEXT_BOX_COLOR)
    contents.fill_rect(box.x + 3, box.y + 3, BOX_SIZE - 6, BOX_SIZE - 6, normal_color) if @form[field.key]
    contents.font.size = VALUE_SIZE
    change_color(normal_color)
    draw_text(box.x + BOX_SIZE + 6, rect.y, rect.width - BOX_SIZE - 8, rect.height, field.label)
  end

  # Writes what a text box, the save or the mods show: a password as stars.
  #
  # @param field [MGQ_MpWorld::Form::Field] The field.
  # @return [String] The text.
  def value_text(field)
    value = @form[field.key]
    return value.nil? ? "Choose one of your saves" : save_text(value) if field.kind == :save
    return value.to_s.empty? ? "None. Confirm to pick them." : value if field.kind == :mods

    field.kind == :password ? "*" * value.size : value
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

  # Moves to the row below.
  #
  # @param wrap [Boolean] Whether the cursor may wrap to the top.
  def cursor_down(wrap = false)
    move_row(1, wrap)
  end

  # Moves to the row above.
  #
  # @param wrap [Boolean] Whether the cursor may wrap to the bottom.
  def cursor_up(wrap = false)
    move_row(-1, wrap)
  end

  # Moves to the field at the right on a row of two.
  #
  # @param _wrap [Boolean] Unused.
  def cursor_right(_wrap = false)
    move_side(:right)
  end

  # Moves to the field at the left on a row of two.
  #
  # @param _wrap [Boolean] Unused.
  def cursor_left(_wrap = false)
    move_side(:left)
  end

  # Keeps the cursor still, since the form fits on one page.
  def cursor_pagedown
  end

  # Keeps the cursor still, since the form fits on one page.
  def cursor_pageup
  end

  # Keeps the page still, since the form fits on one page and its rows differ in height.
  def ensure_cursor_visible
  end

  # Moves to another row, onto the field on the same side when that row has two.
  #
  # @param step [Integer] 1 for the row below, -1 for the one above.
  # @param wrap [Boolean] Whether the cursor may wrap around.
  def move_row(step, wrap)
    rows = @form.fields.map { |candidate| candidate.row }.uniq
    at = rows.index(field.row) + step
    return unless wrap || at.between?(0, rows.size - 1)

    row = rows[at % rows.size]
    on_row = (0...item_max).select { |candidate| @form.fields[candidate].row == row }
    select(on_row.find { |candidate| @form.fields[candidate].side == field.side } || on_row.first)
  end

  # Moves to the other field of a row of two.
  #
  # @param side [Symbol] :left or :right.
  def move_side(side)
    other = (0...item_max).find { |candidate| @form.fields[candidate].row == field.row && @form.fields[candidate].side == side }
    select(other) if other
  end
end
