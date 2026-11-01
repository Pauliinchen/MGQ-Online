#----------------------------------------------------------------
#  make_report_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-11-01: Took the wheel's screenshot once the action wheel is gone, as the scripts of commit 861fb7e6 do
#      Paulinchen  2026-10-31: Wrote the texts C# words anew as C# words them
#                            - Created
#
#----------------------------------------------------------------

# Writes the golden cases of the bug report's request next to this file, report.json, from
# ui_bug_report.rbx as it kept the request before it moved to C# (MGQParadox.Multiplayer's
# Reports/BugReportRequest): the hotkey and the wheel in each scene, the refusals, the screenshot,
# the form opening at once or on a free map, the report forgotten on the title screen or by a scene
# that took the form's place, sending and the outcome, and what waits for the notification box.
# Each scenario is a list of steps; a step's operation runs, then the step records what the script
# logged, played, told, snapped, opened, dropped and sent. MGQParadox.Multiplayer.Tests replays
# them.
#
# It runs on the scripts of commit 861fb7e6, the last that kept the request in ui_bug_report.rbx,
# with the stand-ins below, on Ruby 3.3, from a checkout of that commit with this file copied in:
#
#   ruby fixtures/hud/make_report_fixtures.rb

require "json"
require_relative "../../GameScript/Tests/support"

# The scenes, by the place the cases name them.
class Scene_Base; def update; end; def terminate; end; end
class Scene_MenuBase < Scene_Base; end
class Scene_Menu < Scene_MenuBase; end
class Scene_MpStoryChoices < Scene_MenuBase; def menu_root; end; end
class Scene_Load < Scene_Base; end
class Scene_Title < Scene_Base; end
class Scene_Battle < Scene_Base; end
class Scene_Map < Scene_Base; def update_scene; end; def scene_changing?; false; end; end
class Window_Base; def initialize(*); end; end

# What the step records: the log's lines, the hotkeys' refusals, the sounds, the chat's lines, the
# notification box's messages, the screenshots, the forms opened, the screenshots dropped and the
# reports sent.
$logs = []
$refusals = []
$sounds = []
$chat = []
$notices = []
$snaps = 0
$opened = 0
$drops = 0
$sends = []

module Sound; %w[ok buzzer].each { |sound| define_singleton_method("play_#{sound}") { $sounds << sound } }; end
module SceneManager
  class << self; attr_accessor :scene; end
  def self.call(klass); $opened += 1; @scene = klass.allocate; end
end
module MGQ_Multiplayer
  def self.available?; true; end
  module Log; def self.write(line); $logs << line; end; def self.hand_over; end; end
  module Player; def self.name; $named ? "Me" : nil; end; def self.share; $named; end; end
  module Link
    Function = Struct.new(:name) do
      def call(*args)
        case name
        when "mp_report_send" then $sends << args.first(4).map { |text| text.chomp("\0") } + [args[4]]; $started ? 1 : 0
        when "mp_report_drop_snap" then $drops += 1; 1
        end
      end
    end
    def self.function(name); Function.new(name); end
    def self.read(name, _size); name == "mp_report_state" ? $state.dup : ""; end
  end
end
module MGQ_MpHotkeys
  def self.pressed?(_action); hotkey = $hotkey; $hotkey = false; hotkey; end
  def self.log_refusal(_action, reason); $refusals << reason; end
end
module MGQ_MpOverworldSync
  def self.on_tick(&block); $tick = block; end
  def self.map_free?; $map_ready; end
  def self.in_world?; $in_world; end
end
module MGQ_MpActions
  Option = Struct.new(:text, :run, :refusal, :icon, :leaves)
  WHEEL = Object.new
  def WHEEL.on(event, &block); $wheel_gone = block if event == :gone; self; end
  def self.wheel_choice(_order, &_option); end
  def self.wheel; WHEEL; end
end
module Mod_Framework::UI; def self.busy?; false; end; end
module MGQ_MpNotices
  def self.message(_key, text, frames = nil); $notices << [text, frames]; end
  def self.shown?; $shown; end
end
module MGQ_MpChat; def self.system(text); $chat << text; end; end

load_script "ui_bug_report"
REPORT = MGQ_MpBugReport

# The screenshot as the script takes it, kept unless $snap_kept says no.
module MGQ_MpBugReport::Screenshot; def self.take; $snaps += 1; $snap_kept; end; end

# The facts and details the script gathers, which stay the script's: thirteen facts, and details
# with a line break and a value longer than a detail takes.
module MGQ_MpBugReport
  def self.where_text(scene); "#{scene.class.name}, map 5"; end
  def self.facts(scene); (1..12).map { |n| ["Fact #{n}", "value\t#{n}"] } + [["Where", where_text(scene)]]; end
  def self.details(_scene); [["Player", "Me\n(me000001)"], ["Long", "x" * 1100]]; end
end

# The scenes by the place the cases name them.
SCENES = { "map" => Scene_Map, "battle" => Scene_Battle, "menu" => Scene_Menu, "waiting_menu" => Scene_MpStoryChoices,
           "form" => Scene_MpBugReport, "title" => Scene_Title, "other" => Scene_Load }

# The scenarios, each its name and its steps.
SCENARIOS = []

# Records a scenario of steps, starting on a free map of an open world with nothing asked for.
#
# @param name [String] What the scenario shows.
# @param steps [Array<Hash>] The operations, see run_step.
def scenario(name, steps)
  REPORT.instance_variables.each { |variable| REPORT.instance_variable_set(variable, nil) }
  REPORT.instance_variable_set(:@sending, false)
  REPORT.instance_variable_set(:@poll_frames, 0)
  $place = "map"
  SceneManager.scene = Scene_Map.new
  $in_world = true
  $map_ready = true
  $shown = true
  $mgq_text_input = nil
  $named = true
  $snap_kept = true
  $started = true
  $state = "idle"
  $form = nil
  recorded = steps.map { |step| step.merge("answer" => run_step(step)) }
  SCENARIOS << { "name" => name, "steps" => recorded }
end

# Runs one operation and reads what the script did.
#
# @param step [Hash] "op" and its fields: "scene" ("place", "in_world", "map_ready", "shown",
#   "typing"), "frame" ("hotkey", "count"), "wheel", "wheel_gone", "take_opening", "send" ("title", "text",
#   "screenshot", "logs"), "closed" ("reason"), "state" ("text"), "named" ("named"), "snap"
#   ("kept"), "started" ("started").
# @return [Hash] What the script did.
def run_step(step)
  [$logs, $refusals, $sounds, $chat, $notices, $sends].each(&:clear)
  $snaps = 0
  $opened = 0
  $drops = 0
  answer = nil
  case step["op"]
  when "scene"
    $place = step["place"]
    SceneManager.scene = SCENES[$place].allocate
    $in_world = step["in_world"] unless step["in_world"].nil?
    $map_ready = step["map_ready"] unless step["map_ready"].nil?
    $shown = step["shown"] unless step["shown"].nil?
    $mgq_text_input = step["typing"] ? true : nil
  when "frame"
    (step["count"] || 1).times do
      $hotkey = step["hotkey"] ? true : false
      $tick.call($in_world)
      REPORT.on_map if SceneManager.scene.is_a?(Scene_Map)
    end
  when "wheel"
    option = REPORT.wheel_option
    answer = option.refusal
    option.run.call if option.run
  when "wheel_gone" then $wheel_gone.call
  when "take_opening"
    $form = REPORT.take_opening
    answer = $form && $form[:snapped]
  when "send" then answer = REPORT.send_report($form, step["title"], step["text"], step["screenshot"], step["logs"])
  when "closed" then REPORT.closed($form, step["reason"])
  when "state" then $state = step["text"]
  when "named" then $named = step["named"]
  when "snap" then $snap_kept = step["kept"]
  when "started" then $started = step["started"]
  end
  { "answer" => answer, "logs" => $logs.select { |line| line.start_with?("bug report: ") }, "refusals" => $refusals.dup, "sounds" => $sounds.dup,
    "chat" => $chat.dup, "notices" => $notices.dup, "snaps" => $snaps, "opened" => $opened, "drops" => $drops, "sends" => $sends.dup,
    "waiting" => !REPORT.instance_variable_get(:@pending).nil?, "sending" => REPORT.instance_variable_get(:@sending) == true }
end

scenario("the hotkey on a free map, on a busy map and in a menu", [
  { "op" => "frame", "hotkey" => true },
  { "op" => "take_opening" },
  { "op" => "closed", "reason" => "Escape" },
  { "op" => "scene", "place" => "map", "map_ready" => false },
  { "op" => "frame", "hotkey" => true },
  { "op" => "frame", "count" => 3 },
  { "op" => "scene", "place" => "map", "map_ready" => true },
  { "op" => "frame" },
  { "op" => "scene", "place" => "form" },
  { "op" => "take_opening" },
  { "op" => "closed", "reason" => "Escape" },
  { "op" => "scene", "place" => "menu" },
  { "op" => "snap", "kept" => false },
  { "op" => "frame", "hotkey" => true },
  { "op" => "scene", "place" => "form" },
  { "op" => "take_opening" },
  { "op" => "closed", "reason" => "Escape" },
])

scenario("the hotkey in a battle and in a menu that waits, the notification box hidden", [
  { "op" => "scene", "place" => "battle", "shown" => false },
  { "op" => "frame", "hotkey" => true },
  { "op" => "scene", "place" => "battle", "in_world" => false },
  { "op" => "frame" },
  { "op" => "scene", "place" => "battle", "shown" => true },
  { "op" => "frame" },
  { "op" => "scene", "place" => "map", "map_ready" => false, "in_world" => true },
  { "op" => "frame" },
  { "op" => "scene", "place" => "map", "map_ready" => true, "shown" => false },
  { "op" => "scene", "place" => "battle", "in_world" => true },
  { "op" => "frame", "hotkey" => true },
  { "op" => "scene", "place" => "waiting_menu", "shown" => false },
  { "op" => "frame" },
  { "op" => "scene", "place" => "title", "shown" => true },
  { "op" => "frame" },
  { "op" => "scene", "place" => "waiting_menu" },
  { "op" => "frame", "hotkey" => true },
  { "op" => "scene", "place" => "map", "map_ready" => false, "shown" => false },
  { "op" => "frame", "hotkey" => true },
  { "op" => "scene", "place" => "map", "map_ready" => true, "shown" => true },
  { "op" => "frame" },
])

scenario("the wheel, its screenshot once the wheel is gone and its refusals", [
  { "op" => "wheel" },
  { "op" => "frame", "count" => 13 },
  { "op" => "scene", "place" => "map", "map_ready" => false },
  { "op" => "wheel_gone" },
  { "op" => "wheel_gone" },
  { "op" => "frame" },
  { "op" => "wheel" },
  { "op" => "frame", "hotkey" => true },
  { "op" => "scene", "place" => "map", "map_ready" => true },
  { "op" => "frame" },
  { "op" => "scene", "place" => "menu" },
  { "op" => "frame" },
  { "op" => "scene", "place" => "map" },
  { "op" => "named", "named" => false },
  { "op" => "wheel" },
  { "op" => "frame", "hotkey" => true },
  { "op" => "scene", "place" => "map", "typing" => true },
  { "op" => "frame", "hotkey" => true },
  { "op" => "scene", "place" => "form" },
  { "op" => "frame", "hotkey" => true },
  { "op" => "scene", "place" => "title" },
  { "op" => "frame", "hotkey" => true },
])

scenario("sending, refused while it runs, and its outcomes", [
  { "op" => "scene", "place" => "menu" },
  { "op" => "frame", "hotkey" => true },
  { "op" => "scene", "place" => "form" },
  { "op" => "take_opening" },
  { "op" => "started", "started" => false },
  { "op" => "send", "title" => "It broke", "text" => "Steps\nhere", "screenshot" => true, "logs" => true },
  { "op" => "started", "started" => true },
  { "op" => "send", "title" => "#{'Long title ' * 9}end", "text" => "Steps", "screenshot" => true, "logs" => false },
  { "op" => "send", "title" => "Again", "text" => "Steps", "screenshot" => false, "logs" => true },
  { "op" => "closed", "reason" => "sent" },
  { "op" => "scene", "place" => "map" },
  { "op" => "frame", "hotkey" => true },
  { "op" => "wheel" },
  { "op" => "state", "text" => "sending" },
  { "op" => "frame", "count" => 29 },
  { "op" => "state", "text" => "sent\t42\thttps://example.invalid/42" },
  { "op" => "scene", "place" => "map", "shown" => false },
  { "op" => "frame", "count" => 30 },
  { "op" => "scene", "place" => "map", "shown" => true },
  { "op" => "frame" },
  { "op" => "scene", "place" => "menu" },
  { "op" => "frame", "hotkey" => true },
  { "op" => "scene", "place" => "form" },
  { "op" => "take_opening" },
  { "op" => "send", "title" => "Second", "text" => "Steps", "screenshot" => false, "logs" => false },
  { "op" => "state", "text" => "failed\trate\tHTTP 429" },
  { "op" => "frame", "count" => 30 },
  { "op" => "take_opening" },
  { "op" => "scene", "place" => "menu" },
  { "op" => "frame", "hotkey" => true },
  { "op" => "scene", "place" => "form" },
  { "op" => "take_opening" },
  { "op" => "send", "title" => "Third", "text" => "Steps", "screenshot" => true, "logs" => true },
  { "op" => "state", "text" => "failed\thttp500\t  " },
  { "op" => "frame", "count" => 30 },
])

scenario("a form another scene took the place of, and a report forgotten on the title screen", [
  { "op" => "scene", "place" => "menu" },
  { "op" => "frame", "hotkey" => true },
  { "op" => "scene", "place" => "map" },
  { "op" => "frame" },
  { "op" => "scene", "place" => "map", "map_ready" => false },
  { "op" => "frame", "hotkey" => true },
  { "op" => "scene", "place" => "title" },
  { "op" => "frame" },
  { "op" => "frame", "hotkey" => true },
])

# The texts C# words anew, each the script's text and the one BugReportRequest shows.
REWORDED = {
  "The report could not be sent. Multiplayer.log tells why." => "The bug report could not be sent. Try again later.",
  "The bug report failed: http500" => "The bug report failed: try again later.",
}

text = JSON.pretty_generate({ "scenarios" => SCENARIOS }) + "\n"
File.write(File.join(__dir__, "report.json"), REWORDED.inject(text) { |cases, (old, now)| cases.gsub(old, now) })
puts "wrote #{SCENARIOS.size} scenarios"
