#----------------------------------------------------------------
#  ui_online.rbx
#
#  Changelog:
#      Paulinchen  2026-11-06: Asked again for a HUD part the UI layer refused, a while later or in a new scene
#                            - Read a player's color in the player's look through UI.color_now
#                            - Named MGQ Online's colors for the Mod Framework's UI layer and kept its HUD parts shown
#                            - Named a player's color by MGQ Online's color names
#                            - Rebuilt the list box as a window of the UI layer, the mod picker's Remove in its rows' context menu
#                            - Dropped the lines across the top of a screen, which the world screen holds itself now
#      Paulinchen  2026-11-01: Dropped the name the old screens reached the Mod Framework's interface by
#                            - Named a player's color as the Mod Framework's components take it, and left the room at the top to its docks
#                            - Built the list box and the lines across the top of a screen on the Mod Framework's components
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

# What MGQ Online's screens keep of their own now that their input, look, places, text boxes,
# question box and wheels are the Mod Framework's: the groups of the mod's rows in Options > Mods,
# the colors it names, its HUD parts kept shown, the color a player is named in, the list box on
# the framework's UI layer.

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

  # Names every color of COLORS, logging each the framework refuses; nothing without the Mod
  # Framework's DLL, without which MGQ Online stays off.
  def self.name_all
    return unless Mod_Framework.available?

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
  # The keeps a part the framework refused waits before it is asked again; a part is kept once a frame.
  RETRY_FRAMES = 300

  # The handle of each part shown, by its key.
  @handles = {}

  # Each part the framework refused, by its key: [keeps left before it is asked again, the scene
  # it was refused in], asked again at once in another scene.
  @refused = {}

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "ui"

  # Shows a component once, and again after F12 took it away; a part the framework refused is
  # asked again a while later, or at once in another scene.
  #
  # @param key [Object] What the part is, such as :leader_hud.
  # @param klass [Class] Its component class.
  # @param params [Hash] Its params.
  # @return [Object, nil] Its handle, nil while the framework refuses it.
  def self.keep(key, klass, params = {})
    handle = @handles[key]
    return handle if handle && handle.shown?
    return nil if waiting?(key)

    handle = Mod_Framework::UI.show(klass, params)
    return refused(key, klass) unless handle

    @refused.delete(key)
    @handles[key] = handle
  end

  # Counts a keep of a refused part, telling whether it still waits: until RETRY_FRAMES keeps
  # passed, or the scene changed.
  #
  # @param key [Object] What the part is.
  # @return [Boolean] Whether it waits.
  def self.waiting?(key)
    wait = @refused[key]
    return false unless wait

    wait[0] -= 1
    wait[0] > 0 && wait[1].equal?(SceneManager.scene)
  end

  # Notes that the framework refused a part, logging it once until it is shown or dropped.
  #
  # @param key [Object] What the part is.
  # @param klass [Class] Its component class.
  # @return [nil] Always.
  def self.refused(key, klass)
    log("the UI layer refused to show #{klass} (#{key.is_a?(Array) ? key[0] : key}); asking again every #{RETRY_FRAMES} frames and in each new scene") unless @refused.key?(key)
    @handles.delete(key)
    @refused[key] = [RETRY_FRAMES, SceneManager.scene]
    nil
  end

  # Takes a part off the screen for good, until it is kept again.
  #
  # @param key [Object] What the part is.
  def self.drop(key)
    @refused.delete(key)
    handle = @handles.delete(key)
    handle.hide if handle && handle.shown?
  end

  # Lists the keys of the parts kept now that are Arrays starting with a kind, such as the labels
  # over the other players' characters.
  #
  # @param kind [Symbol] The kind, such as :ghost_label.
  # @return [Array<Array>] Their keys.
  def self.keys_of(kind)
    (@handles.keys | @refused.keys).select { |key| key.is_a?(Array) && key[0] == kind }
  end
end

# The color a player is named in everywhere: the look's own color for the player themself, its ally
# color for a party member and its text color for anyone else.
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

  # Picks a player's color in the player's look now: :own for the player themself, :ally for a
  # party member, else :text, also for one it cannot read.
  #
  # @param who [Peer, Hash, String, Symbol] See id_of.
  # @param member [Boolean, nil] Whether they are in the player's party; nil derives it from a peer's
  #   member, a state hash through MGQ_MpCoop::Party.member? once coop loaded, false for an id.
  # @param own [Boolean, nil] Whether they are the player; nil derives it from :me, or an id equal
  #   to MGQ_MpOverworldSync::Me.id once overworld_sync loaded.
  # @return [Color] The color.
  def self.of(who, member = nil, own = nil)
    Mod_Framework::UI.color_now({ :own => :own, :member => :ally }.fetch(pick(who, member, own), :text))
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

# The large window over a screen that lists rows under a title, a window of the Mod Framework's UI
# layer: the title, a note, a list of rows or a scrolling text, and a key line. The world screen
# shows a world's players, mods or description in it, and its forms the mod picker (picker: true),
# whose rows have toggles, a Name field to add a mod by name and a Remove for the mods added so. The
# player moves and resizes it with Alt; cancel, Numpad 0 and a click outside close it.
#
#   UI.open(MGQ_MpListBox, title: "Iliasburg", source: MGQ_MpListBox::Source.new(rows, "Players")) { |_value, why| ... }
class MGQ_MpListBox < Mod_Framework::UI::Component
  # The window's place id, bare as before the framework, so the places players stored stay theirs.
  ID = :list_box

  # The window's name while the player arranges the windows.
  NAME = "List box"

  # Room between the window and either side of the screen where it starts.
  SIDE = 40

  # Room between the window and the top of the screen where it starts.
  TOP = 32

  # Room between the window and the bottom of the screen where it starts.
  BOTTOM = 44

  # The least size: a mod's name with its right text and two toggle columns and three rows.
  MIN_SIZE = [460, 132]

  # The id of the list of rows.
  LIST = :list_box_list

  # The id of the Name field the picker adds a mod by.
  FIELD = :list_box_field

  # The id of the button that removes a mod added by name.
  REMOVE = :list_box_remove

  # The text of the Remove button and of its choice in the row's context menu.
  REMOVE_TEXT = "Remove"

  # The key line unless the caller gives its own: moving, and closing by the cancel keys as the
  # player bound them or a click outside.
  KEYS = [{ :key => "Up and down", :text => "move" }, { :button => :B, :key => "a click outside", :text => "close" }]

  # What the window shows, which its opener may change while it is open, such as the mod picker's
  # rows and its note of a refused change; the window reads it anew every few frames.
  #
  # @!attribute rows [Array, nil] The list's rows: { heading: "Online (2)" } over the rows under
  #   it, and { text:, color:, right:, toggles: } items; in the picker an item with name_field:
  #   true opens the Name field and one with removable: true is removed by Remove; nil shows the
  #   description.
  # @!attribute note [String, nil] The note beside the title, such as "Players", nil for none.
  Source = Struct.new(:rows, :note)

  # The window's title.
  param :title

  # The rows and the note it shows, see Source.
  param :source

  # The note's color.
  param :note_color, :success

  # The description shown instead of rows, scrolling without a cursor.
  param :description, nil

  # Whether it is the mod picker: its rows' toggles, the Name field and Remove.
  param :picker, false

  # The key line's entries, KEYS unless given.
  param :keys, nil

  # The most characters the Name field takes.
  param :max_length, nil

  # The help line's text while the Name field types.
  param :typing_help, nil

  # A row was picked: the row.
  event :submit

  # A row's toggle was pressed: the row and the toggle's place, from 0.
  event :toggle

  # A name was typed into the Name field: the name.
  event :add

  # A row added by name is to go: the row.
  event :remove

  # Whether the Name field shows, to add a mod by name.
  state :naming, false

  # The place of the list's cursor row.
  state :cursor, 0

  # Renders it anew once its opener changed the rows or the note.
  watch(:every => 5) { [source.rows, source.note] }

  # Puts the cursor on the first row that is not a heading.
  def setup
    self.cursor = (source.rows || []).index { |row| !(row.is_a?(Hash) && row.key?(:heading)) } || 0
  end

  # Describes the window.
  def render
    window title.to_s, id: ID, place_name: NAME, close_outside: true, resizable: true, at: [SIDE, TOP],
                       width: Graphics.width - 2 * SIDE, height: Graphics.height - TOP - BOTTOM, min_size: MIN_SIZE do
      text(source.note.to_s, color: note_color, typo: :subtitle1, id: :list_box_note) if source.note
      if description
        paper scroll: :vertical, focusable: true, height: :fill, autofocus: true do
          text description.to_s, wrap: true
        end
      else
        list source.rows || [], id: LIST, rows_shown: :fill, height: :fill, autofocus: true, bind_index: :cursor, empty: "No entries",
                              on_submit: ->(row) { picked(row) }, on_toggle: ->(row, index) { emit :toggle, row, index },
                              on_focus: -> { self.naming = false if naming },
                              context_menu: -> { removable?(cursor_row) ? [{ text: REMOVE_TEXT, on_click: -> { remove(cursor_row) } }] : [] }
      end
      component(MGQ_MpListBoxName, box: self, max_length: max_length, typing_help: typing_help) if picker && naming
      stack row: true do
        key_help entries: keys || KEYS, grow: 1
        button(REMOVE_TEXT, id: REMOVE, variant: :text, visible: removable?(cursor_row), on_click: -> { remove(cursor_row) }) if picker
      end
    end
  end

  # Takes the name typed: the Name field closes unless the opener refused the name, which it says
  # in the note.
  #
  # @param name [String] The name.
  def add(name)
    source.note = nil
    emit :add, name
    self.naming = false unless source.note
  end

  private

  # Tells the row the list's cursor is on.
  #
  # @return [Hash, String, nil] The row, nil without rows.
  def cursor_row
    (source.rows || [])[cursor]
  end

  # Tells whether a row is one of the picker added by name, which Remove takes away.
  #
  # @param row [Object] The row.
  # @return [Boolean] Whether it is.
  def removable?(row)
    picker && row.is_a?(Hash) && row[:removable] ? true : false
  end

  # Takes a picked row: the picker's row that adds a mod by name opens the Name field, any other is
  # told.
  #
  # @param row [Object] The row.
  def picked(row)
    return self.naming = true if picker && row.is_a?(Hash) && row[:name_field]

    emit :submit, row
  end

  # Tells that a row added by name is to go.
  #
  # @param row [Hash] The row.
  def remove(row)
    emit :remove, row if removable?(row)
  end
end

# The mod picker's Name field under the list box's rows, typing as it shows; the first cancel stops
# typing, the next goes back to the rows.
class MGQ_MpListBoxName < Mod_Framework::UI::Component
  # The list box, which takes the name.
  param :box

  # The most characters it takes, nil for the field's own most.
  param :max_length, nil

  # The help line's text while it types.
  param :typing_help, nil

  # Describes the field.
  def render
    field = { id: MGQ_MpListBox::FIELD, cancel_to: MGQ_MpListBox::LIST, on_submit: ->(name) { box.add(name) } }
    field[:max_length] = max_length if max_length
    field[:typing_help] = typing_help if typing_help
    text_field "Name", field
  end

  # Types into the field as it shows.
  def mounted
    part(MGQ_MpListBox::FIELD).focus
  end
end

# The colors MGQ Online's screens name.

begin
  MGQ_MpColors.name_all
rescue => e
  MGQ_MpColors.log("naming the colors FAILED: #{e.class}: #{e.message}")
end
