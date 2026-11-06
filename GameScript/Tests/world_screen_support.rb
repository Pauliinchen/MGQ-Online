#----------------------------------------------------------------
#  world_screen_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Cancelled in the form through the screen's window, and read a greyed menu choice from disabled:
#      Paulinchen  2026-11-06: Stood in for the UI layer's menu, and acted on the screen as its window of the layer hands over what the player does
#      Paulinchen  2026-11-01: Created
#
#----------------------------------------------------------------

# The world screen for the script tests: the screen built without the game's scene, stand-ins for
# the UI layer's question and menu, and helpers that act as the player does, handing the screen
# what its window of the layer hands over. How the layer draws the screen is the in-game suite's.
# Require it before the scripts load, since world.rbx wraps the game's pictures; build the screen
# once the bridges are open (open_rules_bridge, open_fake_ui).

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

# The layer's menu, standing in for the dialog the framework draws: what it asked is kept for the
# checks, which answer it as the player does. The question is the bridge's StandInConfirm.
module StandInDialogs
  # An open menu: open until answered or closed.
  class Handle
    # @return [Array] What it asked: the menu's choices and params.
    attr_reader :asked

    # Makes an open one.
    #
    # @param asked [Array] What it asks.
    # @param closed [Object] What closing it answers.
    # @param block [Proc] Takes the answer.
    def initialize(asked, closed, block)
      @asked = asked
      @closed = closed
      @block = block
    end

    # Tells whether it waits for an answer.
    #
    # @return [Boolean] Whether it does.
    def open?
      !@block.nil?
    end

    # Answers it.
    #
    # @param values [Array] The answer.
    def answer(*values)
      block = @block
      @block = nil
      block.call(*values) if block
    end

    # Closes it from outside, answering what closing answers.
    def close(*_reason)
      answer(*@closed)
    end
  end

  class << self
    # @return [Handle, nil] The menu opened last.
    attr_accessor :menu
  end

  # Stands in for UI.menu from now on.
  def self.install
    ui = Mod_Framework::UI
    ui.define_singleton_method(:menu) do |choices, options = {}, &block|
      next false if StandInDialogs.menu && StandInDialogs.menu.open?

      StandInDialogs.menu = Handle.new([choices, options], [nil, nil], block)
    end
  end
end

StandInDialogs.install

# Opens the world screen as the game starts it, the list read as the DLL's answers hold it; the
# scenes' base of the test takes the start. The screen is kept in $screen, which type_in types into.
#
# @return [Scene_MpWorlds] The screen.
def world_scene
  # The framework's roots note the scene they open in; a test's scene manager may know none.
  SceneManager.define_singleton_method(:scene) { nil } unless SceneManager.respond_to?(:scene)
  close_screen($screen) if $screen
  scene = Scene_MpWorlds.new
  lines = logged_lines { scene.start }
  failed = lines.find { |line| line.include?("could not start") }
  raise failed if failed

  $screen = scene
end

# Closes the windows a screen of an earlier check left open, as the scene's end does.
#
# @param scene [Scene_MpWorlds] The screen.
def close_screen(scene)
  [:@list_box, :@limits, :@screen].each do |name|
    root = scene.instance_variable_get(name)
    root.close if root && root.open?
  end
end

# Runs what a menu or a question of the screen answered, as the next frame's update does.
#
# @param scene [Scene_MpWorlds] The screen.
def run_later(scene)
  due = scene.instance_variable_get(:@later)
  scene.instance_variable_set(:@later, [])
  due.each { |block| block.call }
end

# Tells what the lines at the top said last.
#
# @param scene [Scene_MpWorlds] The screen.
# @return [String, nil] The message.
def said(scene)
  scene.said && scene.said[0]
end

# Tells where the screen asked the focus to go last: :worlds, :commands, :worlds_box,
# :commands_box, or the key of a form's field.
#
# @param scene [Scene_MpWorlds] The screen.
# @return [Symbol, nil] Where.
def focused(scene)
  target = scene.focus_request && scene.focus_request[0]
  target.is_a?(Array) ? target[1] : target
end

# Finds a field of the form entered.
#
# @param scene [Scene_MpWorlds] The screen.
# @param key [Symbol] The field's key.
# @return [MGQ_MpWorld::Form::Field, nil] The field, nil while the form shows none.
def form_field(scene, key)
  scene.form && scene.form.fields.find { |field| field.key == key }
end

# Tells the texts of the open menu's choices.
#
# @return [Array<String>, nil] The texts, nil while no menu is open.
def menu_texts
  menu = StandInDialogs.menu
  menu && menu.open? ? menu.asked[0].map { |choice| choice[:text] } : nil
end

# Tells which choices of the open menu can be picked.
#
# @return [Array<Boolean>] Whether each can.
def menu_enabled
  StandInDialogs.menu.asked[0].map { |choice| !choice[:disabled] }
end

# Picks a choice of the open menu, as confirm on it does, and runs what the screen does with it.
#
# @param scene [Scene_MpWorlds] The screen.
# @param index [Integer] The choice.
def pick_menu(scene, index)
  menu = StandInDialogs.menu
  menu.answer(menu.asked[0][index], index)
  run_later(scene)
end

# Closes the open menu by cancel, and runs what the screen does then.
#
# @param scene [Scene_MpWorlds] The screen.
def cancel_menu(scene)
  StandInDialogs.menu.answer(nil, nil)
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

# Types into the field the screen put the focus on last, as the player does: the text goes over as
# typed, and "\r" at its end is Enter.
#
# @param text [String] What is typed.
def type_in(text)
  scene = $screen
  key = focused(scene)
  page = scene.limits && scene.form ? scene.form.limits : scene.form
  field = page.fields.find { |each| each.key == key }
  typed = text.chomp("\r")
  scene.typed(page, field, typed)
  scene.submitted(page, field, typed) if text.end_with?("\r")
end

# Cancels in the form entered once its field stopped typing, as the framework does: cancel reaches
# the screen's window.
#
# @param scene [Scene_MpWorlds] The screen.
def cancel_form(scene)
  scene.cancelled
end
