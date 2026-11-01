#----------------------------------------------------------------
#  framework_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-01: Ran a frame of the Mod Framework's components as the game does
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

# The Mod Framework for the script tests: MGQ Online's scripts read their keys and draw their boxes
# through it, so every test loads its scripts first, from the copy the build or the release's fetch
# puts into package/Framework, or from MGQ_MOD_FRAMEWORK_DIR when it is set. Its DLL is closed, as
# without the game; a test opens its bridge with a FakeBridge (bridge_support.rb).

# The folders a copy of the framework is looked for in, the first that holds its loader taken.
FRAMEWORK_PLACES = [ENV["MGQ_MOD_FRAMEWORK_DIR"], File.expand_path("../../package/Framework/Patch/Mod_Framework", __dir__)].compact

# The copy of the framework the tests load, nil when none was found.
FRAMEWORK_DIR = FRAMEWORK_PLACES.find { |dir| File.file?(File.join(dir, "loader.rbx")) && File.directory?(File.join(dir, "Scripts")) }

# The line a run without the framework fails with, naming where it looked.
FRAMEWORK_MISSING = "The Mod Framework's scripts are missing: none in #{FRAMEWORK_PLACES.join(' or ')}. Build MGQParadox.Multiplayer, " \
                    "fetch the framework release, or set MGQ_MOD_FRAMEWORK_DIR to a copy's folder (Patch/Mod_Framework)."

# The lines the framework's log took, which its tests read.
$framework_log = []

# The game's color, which the framework's style makes its colors of as it loads; a test may bring
# its own after.
unless defined?(Color)
  class Color
    attr_accessor :red, :green, :blue, :alpha

    # Makes a color, its alpha nil unless given, as the script tests' colors keep it.
    def initialize(red = 0, green = 0, blue = 0, alpha = nil)
      @red, @green, @blue, @alpha = red, green, blue, alpha
    end

    # Lists its parts.
    #
    # @return [Array<Integer>] Red, green, blue and alpha.
    def to_a
      [red, green, blue, alpha]
    end

    # Tells whether another color has the same parts, of this class or a test's own.
    #
    # @param other [Object] The other color.
    # @return [Boolean] Whether it has.
    def ==(other)
      other.respond_to?(:red) && other.respond_to?(:alpha) && to_a == [other.red, other.green, other.blue, other.alpha]
    end
  end
end

# The game's screen, which the framework's tick hands its models; a test may bring its own.
unless defined?(Graphics)
  module Graphics
    # Answers the screen's width.
    def self.width; 640; end
    # Answers the screen's height.
    def self.height; 480; end
  end
end

# The game's buttons, which the framework's tick reads past the capture; none is pressed unless a
# test brings its own.
unless defined?(Input)
  module Input
    # Answers that no button went down.
    def self.trigger?(_button); false; end
    # Answers that no button is held.
    def self.press?(_button); false; end
    # Answers that no button repeats.
    def self.repeat?(_button); false; end
  end
end

# Loads the framework's scripts in its loader's order over a stand-in for the loader, its DLL
# closed, once per test file; its log lines go to $framework_log.
def load_framework
  return if defined?(Mod_Framework::UI::Tick)

  abort(FRAMEWORK_MISSING) unless FRAMEWORK_DIR
  Object.class_eval <<-RUBY
    module Mod_Framework
      VERSION = "0.1.0"
      FOLDER = "Patch/Mod_Framework"
      WINDOWS = "windows"
      WINE = "wine"
      JOIPLAY = "joiplay"
      def self.available?; @available == true; end
      def self.available=(on); @available = on; end
      def self.booted?; true; end
      def self.platform; WINDOWS; end
      def self.at_least?(version); (VERSION.split(".").map { |part| part.to_i } <=> version.to_s.split(".").map { |part| part.to_i }) >= 0; end
    end
  RUBY
  names = File.read(File.join(FRAMEWORK_DIR, "loader.rbx"), :encoding => "BOM|UTF-8")[/SCRIPTS = %w\[(.*?)\]/m, 1].split
  names.each { |name| load File.join(FRAMEWORK_DIR, "Scripts", "#{name}.rbx") }
  Mod_Framework::Log.define_singleton_method(:write) { |line| $framework_log << line.to_s; nil }
  record_layout_registrations
  # The look the game's start puts to use, before any mod's screen draws.
  Mod_Framework::UI::Theme.load
end

# The boxes the scripts made arrangeable, by id, each [name, options], which open_fake_ui registers
# again once the bridge opened, as the game has them registered in C# before the scripts load.
$layout_registrations = {}

# Has Layout.register note each box in $layout_registrations.
def record_layout_registrations
  layout = Mod_Framework::UI::Layout
  register = layout.method(:register)
  layout.define_singleton_method(:register) do |id, name, options = {}|
    $layout_registrations[id.to_sym] = [name, options]
    register.call(id, name, options)
  end
end

# Opens the framework's bridge with a FakeBridge, whose events of the interface (topics starting
# "ui.") its drain hands to the framework and the rest to MGQ Online's bridge, and counts the DLL
# as working.
#
# @param fake [FakeBridge] The DLL's side.
def open_framework(fake)
  Mod_Framework.bridge.open(fake)
  fake.ui_context = Mod_Framework.bridge.instance_variable_get(:@context)
  Mod_Framework.available = true
end

# Runs a frame of the framework's components as the game does before Graphics.update, but for the
# drawing: each open root follows its :if and its hiding, the components that count frames count
# one, and the changes queued since the tick go to the tree; then the frame ends with its tick.
def tree_frame
  tree = Mod_Framework::UI::Tree
  tree.send(:tick_components)
  tree.instance_variable_get(:@roots).dup.each { |root| tree.send(:watch, root) }
  tree.flush
  ui_frame
end

load_framework

# Tells how a box registered with the framework's layout, as the scripts registered it.
#
# @param id [Symbol] The box.
# @return [Array, nil] Its name, least width and height and how it resizes (:both, :width,
#   :height or :none); nil for a box not registered.
def registered_box(id)
  name, options = $layout_registrations[id]
  return nil unless name

  width, height = options[:min_size]
  resize = options.key?(:resizable) ? options[:resizable] : true
  [name, width, height, { true => :both, false => :none }.fetch(resize, resize)]
end
