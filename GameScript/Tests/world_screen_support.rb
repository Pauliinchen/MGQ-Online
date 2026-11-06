#----------------------------------------------------------------
#  world_screen_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Read the list box from its component of the Mod Framework's UI layer
#      Paulinchen  2026-11-01: Created
#
#----------------------------------------------------------------

# The world screen on the Mod Framework's components for the script tests: the screen built
# without the game's scene, C#'s focus played at once, and helpers that act as the player does on
# the framework's parts, its menu and its question box. Require it before the scripts load, since
# world.rbx wraps the game's pictures; build the screen once the bridges are open
# (open_rules_bridge, open_fake_ui).

# The game's font, as far as the framework's measuring sets it.
class Font
  attr_accessor :name, :size, :color, :bold, :italic, :outline, :shadow, :out_color

  # Makes the game's font of 24.
  def initialize(*); @size = 24; end
end unless defined?(Font)

# The game's picture, as far as the framework measures texts on it; it draws nothing.
class Bitmap
  # Its size and font.
  attr_reader :width, :height, :font

  # Makes an empty picture.
  #
  # @param width [Integer] Its width.
  # @param height [Integer] Its height.
  def initialize(width = 1, height = 1)
    @width = width
    @height = height
    @font = Font.new
  end

  # Tells its whole rectangle.
  #
  # @return [Rect] The rectangle.
  def rect
    Rect.new(0, 0, @width, @height)
  end

  # Measures a text at half the font's size a character.
  #
  # @param text [String] The text.
  # @return [Rect] Its size.
  def text_size(text)
    Rect.new(0, 0, text.to_s.size * @font.size.to_i / 2, @font.size.to_i)
  end

  # Tells that it was not freed.
  #
  # @return [Boolean] false.
  def disposed?
    false
  end

  # Draws nothing for any drawing call.
  #
  # @param _name [Symbol] The call.
  # @param _args [Array] Its arguments.
  def method_missing(_name, *_args)
    nil
  end
end unless defined?(Bitmap)

# The component holding the focus as the stand-in of C#'s tree gave it, nil for none.
$focused = nil

# Plays C#'s focus at once: a component given the focus takes it now, the one that had it hears its
# blur first, as the tree reports both.
def play_focus_at_once
  Mod_Framework::UI::Tree.define_singleton_method(:focus) do |component|
    was = $focused
    unless was.equal?(component)
      $focused = component
      was.receive("blur") if was
      component.receive("focus")
    end
  end
end

play_focus_at_once

# Opens the world screen as the game starts it, the list read as the DLL's answers hold it; the
# scenes' base of the test takes the start.
#
# @return [Scene_MpWorlds] The screen.
def world_scene
  $focused = nil
  close_open_roots
  # The framework's roots note the scene they open in; a test's scene manager may know none.
  SceneManager.define_singleton_method(:scene) { nil } unless SceneManager.respond_to?(:scene)
  scene = Scene_MpWorlds.new
  lines = logged_lines { scene.start }
  failed = lines.find { |line| line.include?("could not start") }
  raise failed if failed
  scene
end

# Closes every root a screen of an earlier check left open, as the scene's end does.
def close_open_roots
  Mod_Framework::UI::Tree.roots.reverse.each { |root| root.close }
end

# Runs what a menu or a question of the screen answered, as the next frame's update does.
#
# @param scene [Scene_MpWorlds] The screen.
def run_later(scene)
  due = scene.instance_variable_get(:@later)
  scene.instance_variable_set(:@later, [])
  due.each { |block| block.call }
end

# Tells the lines the info strip shows.
#
# @param scene [Scene_MpWorlds] The screen.
# @return [String] The lines joined by line breaks.
def strip_text(scene)
  scene.strip.instance_variable_get(:@label).text.to_s
end

# Finds the list box's component while it is open.
#
# @return [MGQ_MpListBox, nil] The component, nil while it is closed.
def list_box_part
  top = Mod_Framework::UI::Engine::Layer.tops.find { |each| each.id == MGQ_MpListBox::ID.to_s && !each.closed }
  top && top.mount.component
end

# Reads what the open list box shows now.
#
# @param name [Symbol] :rows, :note, :title or :description.
# @return [Object] Its value.
def list_box_value(name)
  part = list_box_part
  [:rows, :note].include?(name) ? part.source.send(name) : part.send(name)
end

# Tells the note beside the list box's title.
#
# @return [String] The note.
def note_text
  list_box_value(:note).to_s
end

# Tells what the lines at the top said last.
#
# @param scene [Scene_MpWorlds] The screen.
# @return [String, nil] The message.
def said(scene)
  scene.instance_variable_get(:@message)
end

# Finds a form's field on the right side.
#
# @param scene [Scene_MpWorlds] The screen.
# @param key [Symbol] The field's key.
# @return [Mod_Framework::UI::Component, nil] Its component.
def form_part(scene, key)
  scene.right_box.find("form:#{key}")
end

# Tells the texts of the open menu's choices.
#
# @return [Array<String>, nil] The texts, nil while no menu is open.
def menu_texts
  menu = Mod_Framework::UI::Menu.current
  menu && menu.instance_variable_get(:@list).rows.map { |row| row[:text] }
end

# Tells which choices of the open menu can be picked.
#
# @return [Array<Boolean>] Whether each can.
def menu_enabled
  Mod_Framework::UI::Menu.current.instance_variable_get(:@list).rows.map { |row| row[:enabled] }
end

# Picks a choice of the open menu, as confirm on it does, and runs what the screen does with it.
#
# @param scene [Scene_MpWorlds] The screen.
# @param index [Integer] The choice.
def pick_menu(scene, index)
  Mod_Framework::UI::Menu.current.instance_variable_get(:@list).receive("submit", index)
  run_later(scene)
end

# Closes the open menu by cancel, and runs what the screen does then.
#
# @param scene [Scene_MpWorlds] The screen.
def cancel_menu(scene)
  Mod_Framework::UI::Menu.current.receive("close", "cancel")
  run_later(scene)
end

# Answers the open question, and runs what the screen does with the answer.
#
# @param scene [Scene_MpWorlds] The screen.
# @param yes [Boolean] The answer.
def answer_question(scene, yes)
  answer_confirm(yes)
  run_later(scene)
end

# Cancels in a part as C# does: the focus goes to the part its :cancel_to names, its own or that of
# what holds it, else its root hears cancel.
#
# @param part [Mod_Framework::UI::Component] The part.
def cancel_in(part)
  holder = part
  holder = holder.parent until holder.nil? || holder.cancel_to
  return Mod_Framework::UI::Tree.focus(holder.cancel_to) if holder

  part.root.receive("cancel")
end

# Types into the field that has the focus over two frames, the field handing the tick its box as the
# game's tick has it do; a text box that took Enter takes the next text a frame later.
#
# @param text [String] What is typed; "\r" is Enter.
def type_in(text)
  $typed = text
  2.times do
    Mod_Framework::UI::TextField.follow
    ui_frame
  end
end
