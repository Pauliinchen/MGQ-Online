#----------------------------------------------------------------
#  world_screen.rbx
#
#  Changelog:
#      Paulinchen  2026-10-04: Renamed from mp_world_screen.rbx
#      Paulinchen  2026-10-03: Created
#
#----------------------------------------------------------------

# The world screen, opened from the title screen, and its windows: the worlds at the left, the
# chosen world's details or a form at the right, and the choices in the middle. It builds on
# world.rbx, which knows the worlds, and on world_text.rbx for what the player types.

# The world screen, opened from the title screen: every world of the relay's directory at the left,
# the chosen one's players at the right, and what the player can do with it. Creating a world and
# joining a hidden one are forms that take the right side while the list points at them.
class Scene_MpWorlds < Scene_MenuBase
  # What the screen says while nothing else happened.
  HINT = "Choose a world to enter it, or make a new one."

  # What the screen says while a text box is typed into.
  TYPING_HINT = "Type on the keyboard. Enter keeps it, Esc goes back."

  # Frames between two fetches of the list, ten seconds at 60 frames per second.
  REFRESH_FRAMES = 600

  # Frames between two looks at the list the DLL holds.
  LOOK_FRAMES = 20

  # What the screen says while an action runs, by the action's kind.
  BUSY_TEXTS = {
    "create" => "Making the world . . .",
    "unlock" => "Opening the world . . .",
    "delete" => "Deleting the world . . .",
    "ban" => "Removing the player . . .",
    "start" => "Fetching the starting save . . .",
  }

  # Creates the windows, fetches the list, and takes what the text or save screen handed back.
  #
  # The scene is the same object again when those screens return, so the forms keep what was
  # filled in.
  def start
    super
    @info_window = Window_MpInfo.new
    @list_window = Window_MpWorldList.new(@info_window.height)
    @detail_window = Window_MpWorldDetail.new(@list_window.width, @info_window.height, @list_window.height)
    @form_window = Window_MpWorldForm.new(@detail_window.x, @detail_window.y, @detail_window.width, @detail_window.height)
    @form_window.set_handler(:ok, method(:on_field))
    @form_window.set_handler(:cancel, method(:leave_form))
    @list_window.set_handler(:world, method(:on_world))
    @list_window.set_handler(:new_world, method(:enter_form))
    @list_window.set_handler(:join_hidden, method(:enter_form))
    @list_window.set_handler(:rename, method(:on_rename))
    @list_window.set_handler(:cancel, method(:return_scene))
    @actions_window = Window_MpChoice.new
    [:enter, :favourite, :copy_id, :ban, :delete_world, :export_save, :delete_saves].each { |symbol| @actions_window.set_handler(symbol, method(:"on_#{symbol}")) }
    @actions_window.set_handler(:cancel, method(:back_to_list))
    @members_window = Window_MpChoice.new
    @members_window.set_handler(:member, method(:on_member))
    @members_window.set_handler(:cancel, method(:back_to_list))
    @confirm_window = Window_MpChoice.new
    @confirm_window.set_handler(:yes, method(:on_confirmed))
    @confirm_window.set_handler(:cancel, method(:back_to_list))
    @start_window = Window_MpChoice.new
    [:from_creator, :from_beginning, :from_own].each { |symbol| @start_window.set_handler(symbol, method(:"on_#{symbol}")) }
    @start_window.set_handler(:cancel, method(:back_to_list))
    @forms ||= { :new_world => MGQ_MpWorld::Form.create, :join_hidden => MGQ_MpWorld::Form.join }
    @message ||= HINT
    @me = MGQ_MpWorld::Directory.my_id
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
    super

    if @ask_name
      @ask_name = false
      ask_text(:player_name, "Your name, which the others see", MGQ_Multiplayer::Player.name.to_s, :max_chars => MGQ_MpWorld::MAX_NAME_CHARS)
      return
    end

    return start_from_own if @own_start

    if form && form.editing
      update_typing
    elsif @resume_form && !@start_window.active && !Input.press?(:C) && !Input.press?(:B)
      # The press that ended the typing must not reach the form, or Enter types again at once.
      @resume_form = false
      @form_window.activate
    end

    follow_action if @busy
    show_panel
    show_field_hint

    @refresh_frames += 1
    if @refresh_frames >= REFRESH_FRAMES && !@busy
      @refresh_frames = 0
      MGQ_MpWorld::Directory.refresh
    end

    @look_frames += 1
    look_at_list if @look_frames >= LOOK_FRAMES
  rescue => e
    MGQ_MpWorld.log("world screen failed: #{e.class}: #{e.message}")
    return_scene
  end

  # Stops taking what is typed, should the screen close while a text box is typed into.
  def terminate
    MGQ_Multiplayer::Link.typing(false) if form && form.editing
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
  end

  # Shows at the right what the list points at: a world's details, or a form.
  def show_panel
    shown = @forms[@list_window.current_symbol]
    @form_window.form = shown if shown
    @form_window.visible = !shown.nil?
    @detail_window.visible = shown.nil?
    @detail_window.show(@list_window.current_ext, @me) unless shown
  end

  # Acts on what the text screen handed back.
  def take_text_result
    kind, text = MGQ_MpWorld.take_text_result

    case kind
    when :player_name
      MGQ_Multiplayer::Player.name = text if text
      @me = MGQ_MpWorld::Directory.my_id
      return return_scene if MGQ_Multiplayer::Player.name.nil?
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
    listed = @entry.listed
    creator = listed && listed.creator_id == @me
    commands = []
    commands.push(["Enter the world", :enter]) if listed || @entry.local
    commands.push([@entry.favourite ? "No longer a favourite" : "Mark as a favourite", :favourite]) if @entry.id
    commands.push(["Copy the world id", :copy_id]) if creator && listed.hidden
    commands.push(["Remove a player", :ban, listed.members.size > 1]) if creator
    commands.push(["Delete the world for everyone", :delete_world]) if creator || (listed && @admin)
    commands.push(["Copy my latest save to my game", :export_save]) if @entry.local && @entry.local.latest_save
    commands.push(["Delete my saves of it", :delete_saves]) if @entry.local
    commands.push(["Back", :cancel])
    @actions_window.start(commands)
  end

  # Enters the chosen world, asking for its password the first time, unless it has none.
  def on_enter
    if @entry.listed && @entry.listed.start == "pending"
      Sound.play_buzzer
      say("#{@entry.name} is still being set up by its creator. Try again in a moment.")
      back_to_list
    elsif @entry.local && @entry.listed.nil? && @entry.local.latest_save.nil?
      # Without the list, a first entry cannot know where the world's players start.
      refuse(@entry.gone ? "#{@entry.name} is no longer in the list: it was deleted, or you were removed." : "#{@entry.name} is not in the list right now. Try again once the list has loaded.")
      back_to_list
    elsif @entry.local
      listed = @entry.listed
      @entry.local.describe(listed.name, listed.id) if listed
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
      say("The id of #{@entry.name} is on the clipboard. Send it#{@entry.open? ? '' : ' with the password'} to those who may join.")
    else
      Sound.play_buzzer
      say("The id could not be put on the clipboard.")
    end
    back_to_list
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
    confirm(:delete_world, "Delete #{@entry.name} for everyone? Nobody can enter it again. Saves stay on each PC.", "Delete it")
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
    end
  end

  # Asks for the player's name again.
  def on_rename
    ask_text(:player_name, "Your name, which the others see", MGQ_Multiplayer::Player.name.to_s, :max_chars => MGQ_MpWorld::MAX_NAME_CHARS)
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

  # Moves from the form back to the list, keeping what was filled in.
  def leave_form
    @form_symbol = nil
    @hinted = nil
    @form_window.unselect
    @form_window.deactivate
    say(HINT)
    @list_window.activate
  end

  # Puts the cursor back on the form after another screen, at the field it left from.
  def return_to_form
    @list_window.select_symbol(@form_symbol)
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
      send_form
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
    @typed_before = form[field.key]
    @typing_frames = 0
    MGQ_Multiplayer::Link.typing(true)
    @form_window.refresh
    say(TYPING_HINT)
  end

  # Takes what was typed into the text box, or moves the typing to the text screen, whose letters
  # a gamepad can pick, once a button is pressed that did not come from the keyboard.
  def update_typing
    field = @form_window.field
    text, keys = MGQ_Multiplayer::Link.take_typed
    @typing_frames += 1

    # The press that started the typing is still reported in its first frame.
    if keys == 0 && text.empty? && @typing_frames > 1 && MGQ_MpWorld.gamepad_pressed?
      stop_typing
      return ask_field(field, true)
    end

    text.each_char do |char|
      type(field, char)
      break unless form.editing
    end
  end

  # Types one character into the text box: Enter keeps the text if it is valid, Escape puts the
  # text back as it was, Backspace removes the last character.
  #
  # @param field [MGQ_MpWorld::Form::Field] The text box.
  # @param char [String] The character.
  def type(field, char)
    case char
    when "\r"
      text, error = form.check(field, form[field.key])
      return refuse(error) if error

      form[field.key] = text
      Sound.play_ok
      stop_typing
    when "\e"
      form[field.key] = @typed_before
      Sound.play_cancel
      stop_typing
    when "\b"
      return if form[field.key].empty?

      form[field.key] = form[field.key][0...-1]
      Sound.play_cancel
    else
      return if char =~ /[[:cntrl:]]/

      form.add(field, char) ? Sound.play_cursor : Sound.play_buzzer
    end
    @form_window.redraw_current_item
  end

  # Stops typing into the text box and hands the cursor back to the form.
  def stop_typing
    MGQ_Multiplayer::Link.typing(false)
    form.editing = nil
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

    @form_symbol == :new_world ? create_world : join_world
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

  # Makes the world the form describes.
  def create_world
    values = @forms[:new_world]
    files = values[:from_save] ? MGQ_MpSaveDistribution.files_of(values[:save]) : []
    @creating = values[:name]
    @start_files = files
    start_action("create") { MGQ_MpWorld::Directory.create(values[:name], values[:password], values[:seats].to_i, values[:hidden], values[:choose], MGQ_MpSaveDistribution.text_of(files)) }
  end

  # Opens the hidden world the form names by its id.
  def join_world
    values = @forms[:join_hidden]
    @entry = nil
    start_action("unlock") { MGQ_MpWorld::Directory.unlock(values[:id], values[:password]) }
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
        choose = @forms[:new_world][:choose]
        # A fresh form keeps going back from the world from making it again.
        @forms[:new_world] = MGQ_MpWorld::Form.create
        leave_form
        MGQ_MpWorld::Directory.refresh
        return enter(world, "none", choose)
      end

      say(world ? "Your save could not be copied into #{@creating}." : "The world's folder could not be made.")
    when "unlock"
      return if enter_opened(action)
    when "start"
      return start_world(@fetched, true)
    when "delete"
      say("#{@entry.name} was deleted for everyone.")
    when "ban"
      say("#{@target.name} was removed from #{@entry.name}.")
    end

    MGQ_MpWorld::Directory.refresh
    back_to_list
  end

  # Enters a world whose lock was opened, from the list or by its id, or says why it cannot.
  #
  # @param action [Hash] The ended action, with the world's code, id, name and starting save.
  # @return [Boolean] Whether it went on to enter the world.
  def enter_opened(action)
    name = @entry ? @entry.name : action["name"].to_s

    if action["start"] == "pending"
      Sound.play_buzzer
      say("#{name} is still being set up by its creator. Try again in a moment.")
      return false
    end

    world = MGQ_MpWorld::World.found(action["code"], name, action["world"])

    unless world
      say("The world's folder could not be made.")
      return false
    end

    if @entry
      enter(world, @entry.listed.start, @entry.listed.choose)
    else
      enter(world, action["start"] || "none", action["choose"] == "1")
    end
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
    say("Where do you start in #{world.name}? A save you start from cannot be undone; At the beginning asks again until you save there.")
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

    form ? @resume_form = true : @list_window.activate
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

# The worlds at the left of the world screen, then what else it offers.
class Window_MpWorldList < Window_Command
  # Width of the window.
  WIDTH = 300

  # Creates the list below the lines, reaching down to the bottom of the screen.
  #
  # @param y [Integer] The top edge.
  def initialize(y)
    @entries = []
    @height = Graphics.height - y
    super(0, y)
  end

  # Returns the window's width.
  #
  # @return [Integer] The width.
  def window_width
    WIDTH
  end

  # Returns the window's height: down to the bottom of the screen.
  #
  # @return [Integer] The height.
  def window_height
    @height
  end

  # Shows other worlds, keeping the world or command chosen, so a form stays open while worlds
  # come and go above it.
  #
  # @param entries [Array<MGQ_MpWorld::Entry>] The worlds.
  def entries=(entries)
    return if entries == @entries

    chosen = current_ext
    symbol = current_symbol
    @entries = entries
    clear_command_list
    make_command_list
    refresh
    again = if chosen
              @list.index { |command| command[:ext] && command[:ext].id == chosen.id && command[:ext].name == chosen.name }
            else
              @list.index { |command| command[:symbol] == symbol }
            end
    select(again || [[index, 0].max, item_max - 1].min)
  end

  # Lists the worlds, then the other commands.
  def make_command_list
    (@entries || []).each { |entry| add_command(entry.name, :world, true, entry) }
    add_command("Create new world", :new_world)
    add_command("Join a hidden world", :join_hidden)
    add_command("Change your name", :rename)
    add_command("Back", :cancel)
  end

  # Draws a world with its players online and seats, a featured one in gold, a favourite with a
  # mark, and one its creator deleted pale.
  #
  # @param index [Integer] The row.
  def draw_item(index)
    entry = @list[index][:ext]
    return super unless entry

    rect = item_rect_for_text(index)
    change_color(entry.featured? ? MGQ_MpWorld::FEATURED_COLOR : entry.favourite ? crisis_color : normal_color, !entry.gone)
    draw_text(rect, entry.favourite ? "* #{entry.name}" : entry.name)
    draw_text(rect, "#{entry.listed.online}/#{entry.listed.seats}", 2) if entry.listed
  end
end

# The chosen world's details at the right of the world screen: who made it, who is online, and
# everyone who ever joined.
class Window_MpWorldDetail < Window_Base
  # Creates the window beside the list.
  #
  # @param x [Integer] The left edge.
  # @param y [Integer] The top edge.
  # @param height [Integer] The height.
  def initialize(x, y, height)
    super(x, y, Graphics.width - x, height)
    @shown = :nothing
  end

  # Shows a world, if it is another than shown.
  #
  # @param entry [MGQ_MpWorld::Entry, nil] The world, nil for none.
  # @param me [String] The player's id.
  def show(entry, me)
    return if entry == @shown

    @shown = entry
    contents.clear
    return unless entry

    lines = []
    listed = entry.listed
    lines.push([entry.name, entry.featured? ? MGQ_MpWorld::FEATURED_COLOR : system_color])

    if listed
      lines.push(["Featured: one of the relay's own worlds.", MGQ_MpWorld::FEATURED_COLOR]) if listed.featured
      lines.push(["Made by #{listed.creator_id == me ? 'you' : listed.creator_name}", normal_color])
      lines.push(["#{listed.online} of #{listed.seats} players online", normal_color])
      start = start_text(listed)
      lines.push([start, normal_color]) if start
      lines.push(["No password: anyone may enter.", normal_color]) if listed.open
      lines.push(["Hidden: only its players and the relay's admins see it in the list.", normal_color]) if listed.hidden
    elsif entry.gone
      lines.push(["Only on this PC: it was deleted, or you were removed.", normal_color])
    else
      lines.push(["Not in the list right now.", normal_color])
    end

    lines.push([entry.local ? played_text(entry.local) : "You have not entered it yet.", normal_color])
    lines.push(["", normal_color])

    if listed
      lines.push(["Players", system_color])
      listed.members.each do |member|
        name = member.id == me ? "#{member.name} (you)" : member.name
        lines.push([member.online ? "#{name} - online" : name, member.online ? power_up_color : normal_color])
      end
    end

    rows = contents_height / line_height
    lines = lines.first(rows - 1) + [["and #{lines.size - rows + 1} more", normal_color]] if lines.size > rows
    lines.each_with_index do |(text, color), row|
      change_color(color)
      draw_text(0, row * line_height, contents_width, line_height, text)
    end
  end

  # Tells where a world's new players start, unless it is the beginning for everyone.
  #
  # @param listed [MGQ_MpWorld::Directory::ListedWorld] The world in the directory.
  # @return [String, nil] The text, nil for the beginning.
  def start_text(listed)
    return "Its creator is still uploading its starting save." if listed.start == "pending"
    return "New players choose: the beginning, their own save or its creator's." if listed.choose && listed.start == "ready"
    return "New players choose: the beginning or one of their own saves." if listed.choose
    return "New players start from its creator's save." if listed.start == "ready"

    nil
  end

  # Tells when the player last played a world.
  #
  # @param world [MGQ_MpWorld::World] The world on this PC.
  # @return [String] The text.
  def played_text(world)
    world.played_at ? "You last played it on #{world.played_at.strftime('%Y-%m-%d')}." : "You have entered it, but not played yet."
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

# A form at the right of the world screen, in place of a world's details: its title, then text
# boxes, checkboxes, a save to choose and the button that sends it. Up and down move between rows,
# left and right between two fields on one row.
class Window_MpWorldForm < Window_Selectable
  # Width of the labels in front of the text boxes.
  LABEL_WIDTH = 120

  # Side of a checkbox.
  BOX_SIZE = 14

  # Fill behind the text of a text box.
  TEXT_BOX_COLOR = Color.new(0, 0, 0, 96)

  # What a text box being typed into shows after its text.
  CARET = "_"

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

  # Places a field on its row, below the title, across the row or on its half of it.
  #
  # @param index [Integer] The field's index.
  # @return [Rect] Where it is drawn.
  def item_rect(index)
    field = @form.fields[index]
    half = contents_width / 2
    rect = Rect.new(0, (field.row + 1) * item_height, contents_width, item_height)
    rect.width = half if field.side
    rect.x = half if field.side == :right
    rect
  end

  # Tells whether the field the cursor is on can be used.
  #
  # @return [Boolean] Whether it can.
  def current_item_enabled?
    field ? @form.enabled?(field) : false
  end

  # Draws the title and every field.
  def refresh
    contents.clear
    return unless @form

    change_color(system_color)
    draw_text(0, 0, contents_width, line_height, @form.title)
    draw_all_items
  end

  # Draws a field: a text box, a checkbox, a save or the button.
  #
  # @param index [Integer] The field's index.
  def draw_item(index)
    field = @form.fields[index]
    rect = item_rect_for_text(index)
    enabled = @form.enabled?(field)

    case field.kind
    when :check
      draw_check(rect, field)
    when :button
      change_color(normal_color)
      draw_text(rect, field.label, 1)
    else
      draw_box(rect, field, enabled)
    end
  end

  # Draws a text box or the save to choose: its label, then its value on a darker box.
  #
  # @param rect [Rect] Where.
  # @param field [MGQ_MpWorld::Form::Field] The field.
  # @param enabled [Boolean] Whether it can be used.
  def draw_box(rect, field, enabled)
    change_color(system_color, enabled)
    draw_text(rect.x, rect.y, LABEL_WIDTH, rect.height, field.label)
    box = Rect.new(rect.x + LABEL_WIDTH, rect.y + 2, rect.width - LABEL_WIDTH, rect.height - 4)
    contents.fill_rect(box, TEXT_BOX_COLOR)
    change_color(normal_color, enabled)
    draw_text(box.x + 4, rect.y, box.width - 8, rect.height, value_text(field))
  end

  # Draws a checkbox and its label, the box filled while ticked.
  #
  # @param rect [Rect] Where.
  # @param field [MGQ_MpWorld::Form::Field] The checkbox.
  def draw_check(rect, field)
    box = Rect.new(rect.x, rect.y + (rect.height - BOX_SIZE) / 2, BOX_SIZE, BOX_SIZE)
    contents.fill_rect(box, normal_color)
    contents.clear_rect(box.x + 1, box.y + 1, BOX_SIZE - 2, BOX_SIZE - 2)
    contents.fill_rect(box.x + 3, box.y + 3, BOX_SIZE - 6, BOX_SIZE - 6, normal_color) if @form[field.key]
    change_color(normal_color)
    draw_text(rect.x + BOX_SIZE + 6, rect.y, rect.width - BOX_SIZE - 6, rect.height, field.label)
  end

  # Writes what a text box or the save shows: a password as stars, and the caret while typed into.
  #
  # @param field [MGQ_MpWorld::Form::Field] The field.
  # @return [String] The text.
  def value_text(field)
    value = @form[field.key]
    return value.nil? ? "Choose one of your saves" : save_text(value) if field.kind == :save

    text = field.kind == :password ? "*" * value.size : value
    @form.editing == field.key ? text + CARET : text
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
