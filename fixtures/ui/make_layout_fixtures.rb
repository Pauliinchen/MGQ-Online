#----------------------------------------------------------------
#  make_layout_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Read the old scripts from a commit that feat/refactor holds
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Writes layout.json next to this file: the layout's golden cases, steps played through
# MGQ_MpUi::Layout as ui_layout.rbx had it before its rules moved to C# (LayoutModel in
# MGQOnline.Game), with what each rect answered and what each frame kept in Player.ini, which
# MGQOnline.Game.Tests replays. The script no longer holds those rules, so hand it the script of
# commit 40f11e4d to write the cases again:
#
#   git show 40f11e4d:GameScript/Multiplayer/Scripts/ui_layout.rbx > old_layout.rbx
#   ruby fixtures/ui/make_layout_fixtures.rb old_layout.rbx

require "json"

# The keys held and the mouse, read by the layout through the stand-ins below.
$layout_down = []
$layout_mouse = nil
$layout_ini = {}

# The game's rectangle and color.
Rect = Struct.new(:x, :y, :width, :height)
Color = Struct.new(:red, :green, :blue, :alpha)
# The game's screen of 640 by 480 pixels.
module Graphics; def self.width; 640; end; def self.height; 480; end; end
# The mod's base script: the keys held, the mouse and Player.ini.
module MGQ_Multiplayer
  # Windows' keys held.
  module Key; def self.down?(code); $layout_down.include?(code); end; end
  # The mouse.
  module Mouse; def self.position; $layout_mouse; end; end
  # Player.ini.
  module Player
    # A setting.
    def self.setting(key); $layout_ini[key]; end
    # Keeps a setting.
    def self.store(key, value); $layout_ini[key] = value; end
    # Forgets a setting.
    def self.forget(key); $layout_ini.delete(key); end
  end
end
# The log the layout writes, kept for the cases.
module MGQ_MpLog
  # Keeps a line.
  def log(line); ($layout_log ||= []) << line; end
  # Keeps a line once.
  def log_once(_key, line); log(line); end
end
# The shared interface, as far as the layout needs it.
module MGQ_MpUi
  # Keeps a value between two bounds.
  def self.within(value, low, high); [[value, low].max, high].min; end
  # Adds no Mod Config row.
  def self.add_option(*); false; end
end
# The hooks, which the cases call by hand.
module MGQ_MpHooks; def self.after(*); end; end
load(ARGV[0] || abort("Name the ui_layout.rbx of commit 40f11e4d, see the header."))
# The overlay is drawing, which the cases leave out.
MGQ_MpUi::Layout.define_singleton_method(:draw) { |_offers, _position| }

# The left Alt and the left button, as the layout reads them.
ALT = MGQ_MpUi::Layout::ALT_KEY
BUTTON = MGQ_MpUi::Layout::LEFT_BUTTON

# The steps: boxes registered with their places kept in Player.ini, rects asked for, boxes
# offered, frames with Alt, the button and the mouse, and resets.
STEPS = [
  { "register" => ["test_box", "Test box", 200, 100, "both"], "stored" => nil },
  { "rect" => ["test_box", 20, 30, 300, 120] },
  { "rect" => ["test_box", 600, -50, 100, 50] },
  { "offer" => ["test_box", 20, 30, 300, 120, 5] },
  { "tick" => { "alt" => true, "held" => true, "mouse" => [50, 60] } },
  { "rect" => ["test_box", 20, 30, 300, 120] },
  { "offer" => ["test_box", 20, 30, 300, 120, 5] },
  { "tick" => { "alt" => true, "held" => true, "mouse" => [100, 80] } },
  { "rect" => ["test_box", 20, 30, 300, 120] },
  { "tick" => { "alt" => true, "held" => false, "mouse" => [100, 80] } },
  { "rect" => ["test_box", 20, 30, 300, 120] },
  { "offer" => ["test_box", 70, 50, 300, 120, 5] },
  { "tick" => { "alt" => true, "held" => true, "mouse" => [367, 167] } },
  { "tick" => { "alt" => true, "held" => true, "mouse" => [200, 100] } },
  { "tick" => { "alt" => true, "held" => false, "mouse" => [200, 100] } },
  { "rect" => ["test_box", 20, 30, 300, 120] },
  { "offer" => ["test_box", 70, 50, 200, 100, 5] },
  { "tick" => { "alt" => true, "held" => true, "mouse" => [72, 60] } },
  { "tick" => { "alt" => true, "held" => true, "mouse" => [20, 60] } },
  { "rect" => ["test_box", 20, 30, 300, 120] },
  { "tick" => { "alt" => true, "held" => true, "mouse" => [-40, 60] } },
  { "tick" => { "alt" => true, "held" => false, "mouse" => [-40, 60] } },
  { "rect" => ["test_box", 20, 30, 300, 120] },
  { "register" => ["wide_box", "Wide box", 150, 40, "width"], "stored" => nil },
  { "rect" => ["wide_box", 10, 10, 200, 40] },
  { "offer" => ["wide_box", 10, 10, 200, 40, 9] },
  { "tick" => { "alt" => true, "held" => true, "mouse" => [100, 11] } },
  { "tick" => { "alt" => true, "held" => true, "mouse" => [100, 51] } },
  { "tick" => { "alt" => true, "held" => false, "mouse" => [100, 51] } },
  { "rect" => ["wide_box", 10, 10, 200, 40] },
  { "rect" => ["wide_box", 10, 10, 200, 64] },
  { "offer" => ["test_box", 0, 50, 270, 100, 5] },
  { "offer" => ["wide_box", 10, 50, 200, 64, 9] },
  { "tick" => { "alt" => false, "held" => true, "mouse" => [100, 60] } },
  { "tick" => { "alt" => false, "held" => false, "mouse" => [100, 60] } },
  { "offer" => ["test_box", 0, 50, 270, 100, 5] },
  { "offer" => ["wide_box", 10, 50, 200, 64, 9] },
  { "tick" => { "alt" => true, "held" => true, "mouse" => [100, 60] } },
  { "tick" => { "alt" => true, "held" => false, "mouse" => [100, 60] } },
  { "rect" => ["wide_box", 10, 10, 200, 64] },
  { "offer" => ["test_box", 0, 50, 270, 100, 5] },
  { "tick" => { "alt" => true, "held" => true, "mouse" => [150, 120] } },
  { "tick" => { "alt" => true, "held" => false, "mouse" => [150, 120] } },
  { "offer" => ["test_box", 0, 50, 270, 100, 5] },
  { "tick" => { "alt" => true, "held" => true, "mouse" => [152, 122] } },
  { "tick" => { "alt" => true, "held" => false, "mouse" => [152, 122] } },
  { "rect" => ["test_box", 20, 30, 300, 120] },
  { "reset" => "wide_box" },
  { "rect" => ["wide_box", 10, 10, 200, 64] },
  { "register" => ["broken_box", "Broken box", 10, 10, "both"], "stored" => "1,2,three,4" },
  { "rect" => ["broken_box", 20, 30, 300, 120] },
  { "register" => ["kept_box", "Kept box", 50, 50, "none"], "stored" => " 100, -20 ,10,10" },
  { "rect" => ["kept_box", 5, 5, 80, 60] },
].freeze

layout = MGQ_MpUi::Layout
held = false
results = STEPS.map do |step|
  if step["register"]
    id, name, width, height, resize = step["register"]
    step["stored"] ? $layout_ini["ui_#{id}"] = step["stored"] : $layout_ini.delete("ui_#{id}")
    layout.register(id.to_sym, name, width, height, resize.to_sym)
    nil
  elsif step["rect"]
    id, x, y, width, height = step["rect"]
    layout.rect(id.to_sym, Rect.new(x, y, width, height)).to_a
  elsif step["offer"]
    id, *place = step["offer"]
    layout.offer(id.to_sym, *place)
    nil
  elsif step["tick"]
    tick = step["tick"]
    $layout_down = ([tick["alt"] ? ALT : nil, tick["held"] ? BUTTON : nil]).compact
    $layout_mouse = tick["mouse"]
    before = $layout_ini.dup
    layout.tick
    { "kept" => $layout_ini.reject { |key, value| before[key] == value }, "forgot" => before.keys - $layout_ini.keys, "dragging" => !layout.instance_variable_get(:@drag).nil? }
  else
    layout.reset(step["reset"].to_sym, "a case")
    nil
  end
end
fixture = { "screen" => [640, 480], "steps" => STEPS.zip(results).map { |step, result| result.nil? ? step : step.merge("result" => result) } }
File.write(File.join(__dir__, "layout.json"), JSON.pretty_generate(fixture) + "\n")
puts "wrote layout.json: #{STEPS.size} steps"
