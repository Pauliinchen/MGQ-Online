#----------------------------------------------------------------
#  boxes_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Read the scripts' clock from $frame
#      Paulinchen  2026-11-01: Dropped the checks of the list windows' mouse wheel and scrollbar, which no screen uses any more
#                            - Renamed from ui_boxes_test.rb and covered the list box and the info strip on the Mod Framework's components
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

# Covers what MGQ Online's screens keep of their own in ui_online.rbx: the color of a player, and
# the list box and the info strip on the Mod Framework's components over a stand-in for C#'s tree.
# The framework's components, question box and message are its own tests'.

require_relative "bridge_support"

# Stand-ins for the game and the mod's base script.
$log = []
$keys_down = []
$buttons = []
$sounds = []
$watched = []
$frame = 0
$player_ini = {}
# The mod's base script: the log in $log, the keys held in $keys_down, the buttons in $buttons and
# Player.ini in $player_ini.
module MGQ_Multiplayer
  # The mod's log, kept in $log.
  module Log; def self.write(message); $log << message; end; end
  # Windows' keys: those watched go to $watched, those in $keys_down are held and triggered.
  module Mod_Framework::UI::Key
    # Records the keys watched in $watched.
    def self.watch(*codes); $watched.concat(codes); end
    # Whether a key in $keys_down was pressed.
    def self.triggered?(code); $keys_down.include?(code); end
    # Whether a key in $keys_down is pressed.
    def self.pressed?(code); $keys_down.include?(code); end
    # Whether a key in $keys_down is held.
    def self.down?(code); $keys_down.include?(code); end
  end
  # The mouse, off the screen.
  module Mod_Framework::UI::Mouse; def self.position; nil; end; end
  # The capture: kept by its owners, its buttons taken from $buttons once each.
  module Mod_Framework::UI::Capture
    @owners = []
    # Adds an owner of the capture.
    def self.start(owner); @owners.push(owner) unless @owners.include?(owner); end
    # Removes an owner of the capture.
    def self.stop(owner); @owners.delete(owner); end
    # Whether anyone holds the capture.
    def self.on?; !@owners.empty?; end
    # Takes a button from $buttons as pressed.
    def self.trigger?(button); $buttons.delete(button) ? true : false; end
    # Takes a button from $buttons as repeated.
    def self.repeat?(button); $buttons.delete(button) ? true : false; end
  end
  # Player.ini, kept in $player_ini.
  module Player
    # A setting of Player.ini.
    def self.setting(key); $player_ini[key]; end
    # Stores a setting.
    def self.store(key, value); $player_ini[key] = value.to_s; true; end
    # Forgets a setting.
    def self.forget(key); $player_ini.delete(key); true; end
  end
end
# Mod Config with its Return row alone.
module NWConst; module Config; MOD_CONTENTS = [{ :key => :return }]; end; end
# The game's rectangle.
Rect = Struct.new(:x, :y, :width, :height)
# A font that keeps one color of its own, as RGSS does: color hands out that color and color=
# copies a color's values into it.
class Font < Struct.new(:size, :color, :bold, :outline, :out_color)
  # Copies a color's values into the font's own color.
  #
  # @param value [Color] The color.
  def color=(value)
    self[:color] ||= Color.new
    self[:color].red, self[:color].green, self[:color].blue, self[:color].alpha = value.red, value.green, value.blue, value.alpha
  end
end
# A picture that records its texts, its fills and how many outline copies it drew.
class Bitmap
  # Its size, its font, the texts and fills drawn, the outline copies and whether a text was drawn
  # with the font's own outline on.
  attr_reader :width, :height, :font, :texts, :fills, :outlines, :outlined_twice
  # Creates an empty picture in a white font of 24 without an outline.
  def initialize(width, height); @width = width; @height = height; @font = Font.new(24, Color.new(255, 255, 255, 255), false, false, nil); @texts = []; @fills = []; @outlines = 0; end
  # The picture's whole rectangle.
  def rect; Rect.new(0, 0, @width, @height); end
  # Measures a text at half the font's size a character.
  def text_size(text); Rect.new(0, 0, text.to_s.size * @font.size / 2, @font.size); end
  # Records a text drawn, or counts it as an outline copy when drawn in the outline's color.
  #
  # @param x [Integer] Its left.
  # @param y [Integer] Its top.
  # @param width [Integer] Its width.
  # @param height [Integer] Its height.
  # @param text [String] The text.
  # @param align [Integer] Its alignment.
  def draw_text(x, y, width, height, text, align = 0)
    @outlined_twice = true if @font.outline
    if @font.color == Mod_Framework::UI::Style::OUTLINE
      @outlines += 1
    else
      @texts << [x, y, text, @font.size, @font.color.dup, align]
    end
  end
  # Records a fill with its rectangle and color.
  #
  # @param args [Array] A rectangle and a color, or x, y, width, height and a color.
  def fill_rect(*args)
    x, y, w, h, color = args[0].is_a?(Rect) ? [args[0].x, args[0].y, args[0].width, args[0].height, args[1]] : args
    @fills << [x, y, w, h, color]
  end
  # Forgets the texts, fills and outline copies.
  def clear; @texts.clear; @fills.clear; @outlines = 0; end
  # Frees the picture.
  def dispose; @disposed = true; end
  # Whether the picture was freed.
  def disposed?; @disposed ? true : false; end
end
# The game's screen of 640 by 480 pixels, at frame $frame.
module Graphics; def self.width; 640; end; def self.height; 480; end; def self.update; end; end
clock_from { $frame }
# The game's system sounds: each one played is added to $sounds.
module Sound; %w[cursor ok cancel buzzer].each { |s| define_singleton_method("play_#{s}") { $sounds << s } }; end
# The game's scene manager, whose scene is $scene.
module SceneManager; def self.scene; $scene; end; end
# The game's scene base, which does nothing.
class Scene_Base; def update; end; def start; end; end
# The game's window base, which draws nothing.
class Window_Base; def initialize(*); end; end
# The open world, whose player is me.
module MGQ_MpOverworldSync; module Me; def self.id; "me"; end; end; end
# The party p1.
module MGQ_MpCoop; module Party; def self.member?(state); state["party"] == "p1"; end; end; end
$scene = Scene_Base.new

load_script "core_hotkeys"
load_script "ui_online"

style = Mod_Framework::UI::Style

# The color of a player.
colors = MGQ_MpPlayerColor
# Another player: their seat, their state and whether they are in the party.
Peer = Struct.new(:seat, :state, :member)
peer = Peer.new(2, { "id" => "p-other", "name" => "Player A" }, false)
mate = Peer.new(3, { "id" => "p-mate" }, true)
check("the player themself is OWN", [colors.of(:me), colors.of("me"), colors.of(peer, nil, true), colors.label(:me)], [style::OWN, style::OWN, style::OWN, "own"])
check("a party member is MEMBER", [colors.of(mate), colors.of(peer, true), colors.of({ "id" => "x", "party" => "p1" }), colors.label(mate)], [style::MEMBER, style::MEMBER, style::MEMBER, "member"])
check("anyone else is plain text, whatever their id", [colors.of(peer), colors.of("p-other"), colors.of({ "id" => "p-other", "party" => "p2" }), colors.label(peer), colors.const_defined?(:PALETTE)],
      [style::TEXT, style::TEXT, style::TEXT, "plain", false])
check("nobody reads as plain text, without raising", [colors.of(""), colors.of(Object.new), colors.of(nil), colors.label("")], [style::TEXT, style::TEXT, style::TEXT, "plain"])

# The list box, on the framework's components over a stand-in for C#'s tree.
open_fake_ui { ["", 0] }
tree = $fake_tree
ui = Mod_Framework::UI
# The props C#'s tree holds of a component.
props = lambda { |component| tree.nodes[component.node][:props] }
rows = [{ :heading => "Online (1)" }, { :text => "Mia (you)", :color => :good, :right => "online" }, { :heading => "Offline (1)" }, { :text => "Ana", :color => :dim, :right => "offline" }]
box = MGQ_MpListBox.open(:title => "Iliasburg", :note => "Players", :rows => rows)
list = MGQ_MpListBox.list(box)
ui_frame
labels = box.children.first.children
check("the list box opens over the screen, 40 from the sides, 32 from the top and 44 from the bottom, in front of the screen's windows",
      [box.open?, props.call(box)["at"], props.call(box)["size"], props.call(box)["z"]], [true, [40, 32], [560, 404], ui::Z[:boxes]])
check("it is placed and kept under its old id, both ways resizable down to its least size, wide enough for its whole key line",
      [registered_box(:list_box), props.call(box)["layout_id"]], [["List box", MGQ_MpListBox.key_help(box).measure[0] + 2 * ui::Box::ROOM, 132, :both], "list_box"])
check("it closes on cancel and a click outside, and holds the game's buttons while open",
      [props.call(box)["closable"], props.call(box)["close_outside"], ui::Capture.on?], [true, true, true])
check("its title is the world's name, its note at the right in the good color",
      labels.map { |label| [label.text, label.color] }, [["Iliasburg", nil], ["Players", :good]])
check("the rows show with their headings, the cursor on the first player, the list taking the keys",
      [list.rows, list.index, tree.focused], [rows, 1, list.node])
check("the key line names moving and the cancel keys as bound, and a click outside",
      MGQ_MpListBox.key_help(box).line, "Up and down: move  X, Numpad 0 or a click outside: close")
closed = []
box.on(:close) { |why| closed << why }
tree.tell(box, "close", "outside")
ui_frame
check("a click outside closes it, telling why, and it leaves C#'s tree", [closed, box.open?, tree.holds?(list)], [[:outside], false, false])

# The description: wrapped text in a box that scrolls.
text = MGQ_MpListBox.open_text("Iliasburg", "Description", "A slow run through part one of the story with friends.")
ui_frame
pane = text.children[1]
check("a description opens as one wrapped label in a box that scrolls and takes the keys",
      [MGQ_MpListBox.list(text), props.call(pane)["scroll"], pane.children.map { |label| [label.text, label.wrap] }, tree.focused],
      [nil, true, [["A slow run through part one of the story with friends.", true]], pane.node])
text.close
ui_frame

# The parts of the mod picker: the note, the field under the list and the remove button.
keys = [{ :key => "Enter", :text => "list or unlist" }]
picker = MGQ_MpListBox.open(:title => "Mods of the world", :rows => [{ :text => "List all your mods" }, { :text => "Add a mod by name . . ." }], :keys => keys,
                            :field => "Name", :max_length => 300, :remove => "Remove")
field = MGQ_MpListBox.field(picker)
remove = MGQ_MpListBox.remove_button(picker)
ui_frame
check("a picker without a note shows none, its own key line, and a hidden field and remove button",
      [picker.find(MGQ_MpListBox::NOTE).visible?, MGQ_MpListBox.key_help(picker).line, field.parent.parent.visible?, remove.visible?, remove.hotkey],
      [false, "Enter: list or unlist", false, false, MGQ_MpListBox::DELETE_KEY])
MGQ_MpListBox.note(picker, "Level_Cap is in the list already.", :bad)
check("a note shows in its color", [picker.find(MGQ_MpListBox::NOTE).text, picker.find(MGQ_MpListBox::NOTE).color, picker.find(MGQ_MpListBox::NOTE).visible?],
      ["Level_Cap is in the list already.", :bad, true])
MGQ_MpListBox.show_field(picker)
ui_frame
check("show_field shows the field empty and gives it the keys, its cancel going back to the list",
      [field.parent.parent.visible?, field.text, tree.focused, props.call(field)["cancel_to"], props.call(field)["max_length"] || field.max_length],
      [true, "", field.node, MGQ_MpListBox.list(picker).node, 300])
MGQ_MpListBox.hide_field(picker)
ui_frame
check("hide_field hides it and gives the list the keys back", [field.parent.parent.visible?, tree.focused], [false, MGQ_MpListBox.list(picker).node])
short = props.call(picker)["min"]
MGQ_MpListBox.show_keys(picker, [{ :key => "Enter", :text => "list or unlist" }, { :key => "→", :text => "! required, ? essential" },
                                 { :key => "Del", :text => "remove" }, { :button => :B, :text => "done" }])
ui_frame
whole = MGQ_MpListBox.key_help(picker).measure[0] + 2 * ui::Box::ROOM
long = props.call(picker)["min"]
MGQ_MpListBox.show_remove(picker, true)
ui_frame
check("the box keeps its least size for a short key line, and grows wider for a long one and the remove button beside it",
      [short, long, props.call(picker)["min"][0] > whole, remove.visible?], [[460, 132], [whole, 132], true, true])
picker.close
ui_frame

# Without the DLL the framework opens no box, and the box comes back closed.
Mod_Framework.available = false
check("a list box the framework refuses comes back closed", MGQ_MpListBox.open(:title => "T", :rows => []).open?, false)
Mod_Framework.available = true

# The lines across the top of a screen.
strip = MGQ_MpInfoStrip.new
two = MGQ_MpInfoStrip.new(2)
ui_frame
window = strip.instance_variable_get(:@window)
label = window.children.first
check("the info strip is as high as the game's window of its lines, across the top of the screen",
      [strip.height, two.height, props.call(window)["at"], props.call(window)["size"]], [3 * 24 + 24, 2 * 24 + 24, [0, 0], [640, 96]])
check("it takes neither the keys nor the pointer, and no cancel closes it",
      [window.inert?, window.mouse, props.call(window)["closable"], window.captures], [true, false, false, false])
sets = 0
label.define_singleton_method(:text=) { |value| sets += 1; super(value) }
strip.show(["Playing as Mia", nil, "3 worlds"])
strip.show(["Playing as Mia", nil, "3 worlds"])
check("it wraps the lines it is given, nil ones left out, at most its rows, and the same lines twice draw once",
      [label.text, label.wrap, label.most_lines, sets], ["Playing as Mia\n3 worlds", true, 3, 1])
strip.dispose
two.dispose
check("dispose closes it", window.open?, false)
