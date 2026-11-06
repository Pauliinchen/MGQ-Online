#----------------------------------------------------------------
#  ui_online.rbx
#
#  Changelog:
#      Paulinchen  2026-11-06: Named MGQ Online's colors for the Mod Framework's UI layer and kept its HUD parts shown
#                            - Named a player's color by MGQ Online's color names
#      Paulinchen  2026-11-01: Dropped the name the old screens reached the Mod Framework's interface by
#                            - Named a player's color as the Mod Framework's components take it, and left the room at the top to its docks
#                            - Built the list box and the lines across the top of a screen on the Mod Framework's components
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

# What MGQ Online's screens keep of their own now that their input, look, places, text boxes,
# question box and wheels are the Mod Framework's: the groups of the mod's rows in Options > Mods,
# the color a player is named in, and the list box and the lines across the top of a screen, built
# of the framework's components.

module MGQ_Multiplayer
  # What the names of the mod's settings rows in Options > Mods start with.
  OPTION_PREFIX = "[MGQ Online Settings] "

  # What the names of the single player settings rows start with.
  SP_PREFIX = "[MGQ Online SP] "
end

# The colors MGQ Online's screens name, given once to the Mod Framework's UI layer: a player's own
# color, a party member's, a Raid World's, a featured world's, and the fills of the HUD's bars.
module MGQ_MpColors
  # Each color's name and what it is: a color name of the player's look it follows, or red, green
  # and blue.
  COLORS = [
    [:mgq_online_own, :own], [:mgq_online_member, :ally], [:mgq_online_raid, :error], [:mgq_online_featured, :gold],
    [:mgq_online_hp_left, [150, 20, 20]], [:mgq_online_hp_right, [230, 60, 50]],
    [:mgq_online_mp_left, [30, 80, 170]], [:mgq_online_mp_right, [70, 150, 240]],
    [:mgq_online_base_left, [200, 150, 40]], [:mgq_online_base_right, [255, 220, 110]],
    [:mgq_online_job_left, [40, 150, 70]], [:mgq_online_job_right, [110, 220, 120]],
    [:mgq_online_race_left, [130, 70, 190]], [:mgq_online_race_right, [200, 140, 255]],
    [:mgq_online_raid_top, [156, 32, 50]], [:mgq_online_raid_middle, [110, 16, 30]], [:mgq_online_raid_bottom, [70, 8, 18]]
  ]

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "ui"

  # Names every color of COLORS, logging each the framework refuses.
  def self.name_all
    COLORS.each do |name, value|
      begin
        Mod_Framework::UI.color(name, value)
      rescue => e
        log("naming the color #{name} FAILED: #{e.message}")
      end
    end
  end
end

# MGQ Online's HUD parts on the Mod Framework's UI layer, each shown once and kept: a hud stays
# across the scenes, and F12 takes every part of the layer away, so each is shown again then.
module MGQ_MpShown
  # The handle of each part shown, by its key; false for one the framework refused, which is not
  # asked again until it is dropped.
  @handles = {}

  # Shows a component once, and again after F12 took it away.
  #
  # @param key [Object] What the part is, such as :leader_hud.
  # @param klass [Class] Its component class.
  # @param params [Hash] Its params.
  # @return [Object, nil] Its handle, nil while the framework refuses it.
  def self.keep(key, klass, params = {})
    handle = @handles[key]
    return nil if handle == false
    return handle if handle && handle.shown?

    @handles[key] = Mod_Framework::UI.show(klass, params) || false
    @handles[key] || nil
  end

  # Takes a part off the screen for good, until it is kept again.
  #
  # @param key [Object] What the part is.
  def self.drop(key)
    handle = @handles.delete(key)
    handle.hide if handle && handle.shown?
  end

  # Lists the keys of the parts kept now that are Arrays starting with a kind, such as the labels
  # over the other players' characters.
  #
  # @param kind [Symbol] The kind, such as :ghost_label.
  # @return [Array<Array>] Their keys.
  def self.keys_of(kind)
    @handles.keys.select { |key| key.is_a?(Array) && key[0] == kind }
  end
end

# The color a player is named in everywhere: Style::OWN for the player themself, Style::MEMBER for
# a party member and Style::TEXT for anyone else.
module MGQ_MpPlayerColor
  # What the player's own color is called in the log.
  OWN_NAME = "own"

  # What a party member's color is called in the log.
  MEMBER_NAME = "member"

  # What anyone else's color is called in the log.
  PLAIN_NAME = "plain"

  # Finds a player's id.
  #
  # @param who [MGQ_MpOverworldSync::Peers::Peer, Hash, String, Symbol] A peer, a state hash with
  #   "id", an id, or :me.
  # @return [String] The id, "" for none.
  def self.id_of(who)
    if who == :me
      defined?(MGQ_MpOverworldSync::Me) ? MGQ_MpOverworldSync::Me.id.to_s : ""
    elsif who.is_a?(String)
      who
    elsif who.is_a?(Hash)
      who["id"].to_s
    elsif who.respond_to?(:state) && who.state.is_a?(Hash)
      who.state["id"].to_s
    else
      ""
    end
  rescue
    ""
  end

  # Picks a player's color: Style::OWN for the player themself, Style::MEMBER for a party member,
  # else Style::TEXT, also for one it cannot read.
  #
  # @param who [Peer, Hash, String, Symbol] See id_of.
  # @param member [Boolean, nil] Whether they are in the player's party; nil derives it from a peer's
  #   member, a state hash through MGQ_MpCoop::Party.member? once coop loaded, false for an id.
  # @param own [Boolean, nil] Whether they are the player; nil derives it from :me, or an id equal
  #   to MGQ_MpOverworldSync::Me.id once overworld_sync loaded.
  # @return [Color] The color.
  def self.of(who, member = nil, own = nil)
    style = Mod_Framework::UI::Style
    { :own => style::OWN, :member => style::MEMBER }.fetch(pick(who, member, own), style::TEXT)
  end

  # Names a player's color for the log: "own", "member" or "plain".
  #
  # @param who [Peer, Hash, String, Symbol] See id_of.
  # @param member [Boolean, nil] See of.
  # @param own [Boolean, nil] See of.
  # @return [String] The name.
  def self.label(who, member = nil, own = nil)
    { :own => OWN_NAME, :member => MEMBER_NAME }.fetch(pick(who, member, own), PLAIN_NAME)
  end

  # Names a player's color as the Mod Framework's UI layer takes it in color:.
  #
  # @param who [Peer, Hash, String, Symbol] See id_of.
  # @param member [Boolean, nil] See of.
  # @param own [Boolean, nil] See of.
  # @return [Symbol] :mgq_online_own for the player themself, :mgq_online_member for a party member,
  #   :text for anyone else.
  def self.role(who, member = nil, own = nil)
    { :own => :mgq_online_own, :member => :mgq_online_member }.fetch(pick(who, member, own), :text)
  end

  # Tells which of the three a player is, which of and label name in their own way.
  #
  # @param who [Peer, Hash, String, Symbol] See id_of.
  # @param member [Boolean, nil] See of.
  # @param own [Boolean, nil] See of.
  # @return [Symbol] :own for the player themself, :member for a party member, :plain for anyone
  #   else or one it cannot read.
  def self.pick(who, member = nil, own = nil)
    return :own if own.nil? ? own?(who) : own
    return :member if member.nil? ? member?(who) : member

    :plain
  rescue
    :plain
  end

  # Tells whether a player is the player themself.
  #
  # @param who [Peer, Hash, String, Symbol] See id_of.
  # @return [Boolean] Whether they are.
  def self.own?(who)
    return true if who == :me
    return false unless defined?(MGQ_MpOverworldSync::Me)

    id = id_of(who)
    !id.empty? && id == MGQ_MpOverworldSync::Me.id.to_s
  end

  # Tells whether a player is in the player's party.
  #
  # @param who [Peer, Hash, String, Symbol] See id_of.
  # @return [Boolean] Whether they are.
  def self.member?(who)
    return who.member ? true : false if who.respond_to?(:member)
    return false unless who.is_a?(Hash) && defined?(MGQ_MpCoop::Party)

    MGQ_MpCoop::Party.member?(who) ? true : false
  end
end

# The large box over a screen that lists rows under a title, built of the Mod Framework's parts: a
# floating Box with the title and a note in its top row, a List or a scrolling text, and a key line.
# The world screen shows a world's players, mods and description in it, and its forms the mod
# picker. The player moves and resizes it with Alt; it closes on the game's cancel, Numpad 0 and a
# click outside it.
module MGQ_MpListBox
  # The box's place id, bare as before the framework, so the places players stored stay theirs.
  ID = :list_box

  # The box's name in the outlines.
  NAME = "List box"

  # Room between the box and either side of the screen where it starts.
  SIDE = 40

  # Room between the box and the top of the screen where it starts.
  TOP = 32

  # Room between the box and the bottom of the screen where it starts.
  BOTTOM = 44

  # The least size: a mod's name with its right text and two toggle columns and three rows; wider
  # while the key line needs more, see show_keys.
  MIN_SIZE = [460, 132]

  # The id of the List of rows, see list.
  LIST = :list_box_list

  # The id of the note at the top right.
  NOTE = :list_box_note

  # The id of the field row under the list, hidden until show_field.
  FIELD_ROW = :list_box_field_row

  # The id of the text field in the field row, see field.
  FIELD = :list_box_field

  # The id of the key line.
  KEYS = :list_box_keys

  # The id of the button beside the key line, see remove_button.
  REMOVE = :list_box_remove

  # Windows' code of the Delete key, the remove button's hotkey.
  DELETE_KEY = 0x2E

  # Tells the key line's entries unless a screen gives its own: moving, and closing by the cancel
  # keys as the player bound them or a click outside.
  #
  # @return [Array<Hash>] The entries, as KeyHelp takes them.
  def self.keys
    [{ :key => "Up and down", :text => "move" }, { :button => :B, :key => "a click outside", :text => "close" }]
  end

  # Opens the box with a List of rows, the cursor on the first row that is not a heading.
  #
  # @param options [Hash] :title, :note (nil for none), :rows (List rows), :keys (the key line's
  #   entries, keys by default), :field (a caption: a text field under the list, hidden until
  #   show_field), :max_length (the field's most characters), :remove (a text: a button beside the
  #   key line that Delete clicks, hidden until shown).
  # @return [Mod_Framework::UI::Box] The box, closed when the framework refused it.
  def self.open(options)
    rows = options[:rows] || []
    box = make(options[:title], options[:note])
    list = box.add_list(:id => LIST, :rows => rows, :rows_shown => :fill, :grow => 1, :index => first_item(rows))
    add_field(box, list, options[:field], options[:max_length]) if options[:field]
    add_foot(box, options[:keys] || keys, options[:remove])
    fit_keys(box)
    show(box, list)
  end

  # Opens the box with a text that wraps to its width and scrolls.
  #
  # @param title [String] The title.
  # @param note [String, nil] The note at the top right.
  # @param text [String] The text.
  # @return [Mod_Framework::UI::Box] The box, closed when the framework refused it.
  def self.open_text(title, note, text)
    box = make(title, note)
    pane = box.add_box(:frame => false, :scroll => true, :focusable => true, :grow => 1)
    pane.add_label(text.to_s, :wrap => true)
    add_foot(box, keys)
    fit_keys(box)
    show(box, pane)
  end

  # Finds the box's List.
  #
  # @param box [Mod_Framework::UI::Box] The box.
  # @return [Mod_Framework::UI::List, nil] The List, nil for a box of text.
  def self.list(box)
    box.find(LIST)
  end

  # Finds the box's text field.
  #
  # @param box [Mod_Framework::UI::Box] The box.
  # @return [Mod_Framework::UI::TextField, nil] The field, nil for a box without one.
  def self.field(box)
    box.find(FIELD)
  end

  # Finds the button beside the key line.
  #
  # @param box [Mod_Framework::UI::Box] The box.
  # @return [Mod_Framework::UI::Button, nil] The button, nil for a box without one.
  def self.remove_button(box)
    box.find(REMOVE)
  end

  # Finds the key line.
  #
  # @param box [Mod_Framework::UI::Box] The box.
  # @return [Mod_Framework::UI::KeyHelp] The key line.
  def self.key_help(box)
    box.find(KEYS)
  end

  # Shows other entries in the key line, or reads its entries anew, and keeps the box wide enough
  # for the whole line and the button beside it.
  #
  # @param box [Mod_Framework::UI::Box] The box.
  # @param entries [Array<Hash>, nil] The entries, as KeyHelp takes them; nil keeps those shown.
  def self.show_keys(box, entries = nil)
    help = key_help(box)
    help.entries = entries if entries
    help.refresh
    fit_keys(box)
  end

  # Shows the button beside the key line, or hides it, and reads the key line anew.
  #
  # @param box [Mod_Framework::UI::Box] The box.
  # @param shown [Boolean] Whether it shows.
  def self.show_remove(box, shown)
    remove_button(box).visible = shown
    show_keys(box)
  end

  # Shows a note at the top right, or none.
  #
  # @param box [Mod_Framework::UI::Box] The box.
  # @param text [String, nil] The note, nil for none.
  # @param color [Symbol] Its color.
  def self.note(box, text, color = :good)
    label = box.find(NOTE)
    label.text = text.to_s
    label.color = color
    label.visible = !text.nil?
  end

  # Shows the text field, empty, and gives it the focus.
  #
  # @param box [Mod_Framework::UI::Box] The box.
  def self.show_field(box)
    box.find(FIELD_ROW).visible = true
    field(box).text = ""
    field(box).focus
  end

  # Hides the text field and gives the List the focus back.
  #
  # @param box [Mod_Framework::UI::Box] The box.
  def self.hide_field(box)
    box.find(FIELD_ROW).visible = false
    list(box).focus if box.open?
  end

  # Makes the box, closed, with its top row.
  #
  # @param title [String] The title, cut with "..." before the note.
  # @param note [String, nil] The note, nil for none.
  # @return [Mod_Framework::UI::Box] The box.
  def self.make(title, note)
    ui = Mod_Framework::UI
    box = ui::Box.new(:id => ID, :place_name => NAME, :z => ui::Z[:boxes], :at => [SIDE, TOP],
                      :size => [Graphics.width - 2 * SIDE, Graphics.height - TOP - BOTTOM], :min_size => MIN_SIZE, :movable => true,
                      :resizable => true, :closable => true, :captures => true, :close_outside => true)
    top = box.add_row(:gap => ui::Style::PAD)
    top.add_label(title.to_s, :font_size => :large, :grow => 1, :shrink => true)
    top.add_label(note.to_s, :id => NOTE, :font_size => :large, :color => :good, :visible => !note.nil?)
    box
  end
  private_class_method :make

  # Adds the hidden field row under the list, whose cancel goes back to the list.
  #
  # @param box [Mod_Framework::UI::Box] The box.
  # @param list [Mod_Framework::UI::List] The list.
  # @param caption [String] The field's caption.
  # @param max_length [Integer, nil] Its most characters.
  def self.add_field(box, list, caption, max_length)
    row = box.add_field(caption.to_s, :id => FIELD_ROW, :visible => false)
    row.add_text_field(:id => FIELD, :max_length => max_length, :cancel_to => list)
  end
  private_class_method :add_field

  # Adds the key line, with the hidden button beside it.
  #
  # @param box [Mod_Framework::UI::Box] The box.
  # @param entries [Array<Hash>] The key line's entries.
  # @param remove [String, nil] The button's text, nil for none.
  def self.add_foot(box, entries, remove = nil)
    foot = box.add_row(:align => :stretch)
    foot.add_key_help(entries, :id => KEYS, :text_align => :center, :grow => 1)
    foot.add_button(remove, :id => REMOVE, :hotkey => DELETE_KEY, :flat => true, :visible => false) if remove
  end
  private_class_method :add_foot

  # Keeps the box at least as wide as its key line with the button beside it while it shows, so
  # the line leaves out none of its entries where the screen has room.
  #
  # @param box [Mod_Framework::UI::Box] The box.
  def self.fit_keys(box)
    ui = Mod_Framework::UI
    width = key_help(box).measure[0]
    button = remove_button(box)
    if button && button.visible?
      text = ui.font_bitmap(ui.font_px(button.font_size)).text_size(button.text.to_s).width
      width += ui::Style::GAP + text + 2 * ui::Button::PAD_X
    end
    box.min_size = [[MIN_SIZE[0], width + 2 * ui::Box::ROOM].max, MIN_SIZE[1]]
  end
  private_class_method :fit_keys

  # Opens the box and gives a part the focus.
  #
  # @param box [Mod_Framework::UI::Box] The box.
  # @param part [Mod_Framework::UI::Component] What takes the keys.
  # @return [Mod_Framework::UI::Box] The box.
  def self.show(box, part)
    box.open
    part.focus if box.open?
    box
  end
  private_class_method :show

  # Finds the first row that is not a heading.
  #
  # @param rows [Array] The rows.
  # @return [Integer] Its index, 0 without one.
  def self.first_item(rows)
    rows.index { |row| !(row.is_a?(Hash) && row.key?(:heading)) } || 0
  end
  private_class_method :first_item
end

# The lines across the top of a screen of the mod, such as the world screen's, as a framework Window
# that takes neither keys nor the pointer: long lines wrap, and lines past its rows are left out.
class MGQ_MpInfoStrip
  # Lines it has room for unless told otherwise.
  ROWS = 3

  # Height of a line, the game's.
  LINE_HEIGHT = 24

  # Opens the strip across the top of the screen, empty.
  #
  # @param rows [Integer] The lines it has room for.
  def initialize(rows = ROWS)
    @rows = rows
    @window = Mod_Framework::UI::Window.new(:at => [0, 0], :size => [Graphics.width, height], :closable => false, :captures => false,
                                            :inert => true, :mouse => false)
    @label = @window.add_label("", :wrap => true, :most_lines => rows)
    @window.open
  end

  # Tells the strip's height, the game's fitting height of its rows, so the windows under it can be
  # placed before it shows.
  #
  # @return [Integer] The pixels.
  def height
    @rows * LINE_HEIGHT + 2 * Mod_Framework::UI::Window::PADDING
  end

  # Shows the lines, if they changed.
  #
  # @param lines [Array<String, nil>] The lines, nil ones left out.
  def show(lines)
    return if lines == @given

    @given = lines.dup
    @label.text = lines.compact.join("\n")
  end

  # Closes the strip.
  def dispose
    @window.close
  end
end

# The colors MGQ Online's screens name.

begin
  MGQ_MpColors.name_all
rescue => e
  MGQ_MpColors.log("naming the colors FAILED: #{e.class}: #{e.message}")
end
