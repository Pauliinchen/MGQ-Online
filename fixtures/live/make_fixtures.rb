#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-30: Wrote the golden steps of the host's recording
#                            - Wrote the golden cases of the command plan and a team duel's sides
#                            - Wrote the golden cases of the session and of the battle's endings
#                            - Created
#
#----------------------------------------------------------------

# Writes the golden cases of the live battle's rules next to this file from the scripts of commit
# eae042b7, the last that kept them in Ruby (battles_sync*.rbx), which MGQOnline.Game.Tests replays
# against MGQOnline.Game's Battles/Live folder and GameScript/Tests/live_support.rb checks its
# stand-ins against:
#
# - stream.json: the guest's intake of the host's stream. Each case sets the guest up with the
#   host's names and its own, takes one send and lists what the old playback did with each line
#   (its effect: what reached the battle log, the message window, the screen, Audio and the
#   battlers, with the names swapped), what it counted and what it logged. The sends are hand
#   cases and the sends of three battles the battle server hosted (served_streams.json).
#
# It runs on the old scripts with their own test support, on Ruby 3.3:
#
#   git archive eae042b7 GameScript fixtures Relay/seed | tar -x -C <old>
#   ruby fixtures/live/make_fixtures.rb <old>
#
# served_streams.json holds the names line and the sends of served battles as their guests got
# them; with --served it is written anew from recordings of BattleServer/tools/try_served.rb's
# battles (JSON of {"sent" => [[seat, message], ...]}, one file per battle):
#
#   ruby fixtures/live/make_fixtures.rb <old> --served <battle>.json...

require "json"

OLD = File.expand_path(ARGV.shift || abort("usage: make_fixtures.rb <old tree> [--served <recording>...]"))
HERE = __dir__

# The host's sends kept of each served battle, enough to cover every kind of line it streams.
SENDS_KEPT = 12

# Writes served_streams.json from recordings of served battles.
#
# @param files [Array<String>] The recordings.
def write_served(files)
  battles = files.map do |file|
    sent = JSON.parse(File.read(file, :encoding => "UTF-8"))["sent"]
    messages = sent.map { |_, text| head, body = text.split("\n\n", 2); [head.to_s[/^battle=(.*)$/, 1], body.to_s] }
    names = messages.find { |kind, body| kind == "ready" && !body.empty? }
    sends = messages.select { |kind, _| kind == "events" }.map(&:last).uniq
    kinds = []
    kept = sends.select do |send|
      fresh = send.split("\n").map { |line| line[/\As[^\t]*/] }.uniq - kinds
      next false if fresh.empty? && kinds.size > 0

      kinds |= fresh
      true
    end
    { "file" => File.basename(file), "names" => names && names[1], "sends" => (kept + sends.first(SENDS_KEPT)).uniq.first(SENDS_KEPT * 2) }
  end
  File.write(File.join(HERE, "served_streams.json"), JSON.pretty_generate({ "battles" => battles }) + "\n")
  puts "wrote served_streams.json: #{battles.map { |battle| battle['sends'].size }.sum} sends"
end

if ARGV[0] == "--served"
  write_served(ARGV[1..-1])
  exit
end

Dir.chdir(File.join(OLD, "GameScript", "Tests"))
require File.join(OLD, "GameScript", "Tests", "battle_support")
# The story's scene, whose checks the old playback asked for pictures and the screen.
Object.send(:remove_const, :MGQ_MpCoopScene)
load_script "coop_scene"

sync = MGQ_MpBattlesSync
PLAYBACK = sync::Playback

# A battler of the guest's battle, named by the host's reference, which notes what happens to it.
class FixtureBattler < Game_Battler
  attr_reader :ref
  def initialize(ref); @ref = ref; end
  def animation_id=(id); $effects << ["animation_id", id]; end
  def animation_mirror=(mirror); $effects << ["animation_mirror", mirror]; end
  def actor?; true; end
  def name; "Battler #{@ref}"; end
  # The animations of its attack, which no case shows.
  def atk_animation_ids; []; end
end

# The game's result of an action, with the fields the battle log reads.
class Game_ActionResult
  def initialize(battler = nil)
    @battler = battler
    @used = @missed = @evaded = @critical = @success = false
    @hp_damage = @mp_damage = @tp_damage = 0
    @added_states = []
  end
end

# The guest's battle log, which notes its lines and the calls the guest makes itself.
class FixtureLog
  def method_missing(name, *args)
    $effects << (name.to_s.start_with?("display_") ? ["call", "log", name.to_s] : ["log", name.to_s, describe(args)])
  end
  def respond_to_missing?(*); true; end
  def popup; FixturePopup.new; end
end

# The battle log's popup, which notes its lines.
class FixturePopup; def push(text, mark = nil); $effects << ["popup", text, describe(mark)]; end; end

# The guest's battle scene, which notes its waits and its own calls.
class FixtureScene
  def initialize; @log_window = FixtureLog.new; end
  %w(wait abs_wait wait_for_animation wait_for_effect wait_for_message).each do |name|
    define_method(name) { |*args| $effects << ["scene", name, describe(args)] }
  end
  %w(process_skill_word display_skill_name).each { |name| define_method(name) { |*_args| $effects << ["call", "scene", name] } }
  def battle_show_skip?; false; end
  def refresh_status; end
  def update_for_wait; end
end

# A picture of the troop's screen, which notes what is done to it.
class FixturePicture
  def initialize(number); @number = number; end
  def method_missing(name, *args); $effects << ["picture", name.to_s, describe([@number] + args)]; end
  def respond_to_missing?(*); true; end
end

# The troop's screen, which notes its effects.
class FixtureScreen
  def pictures; Hash.new { |all, number| all[number] = FixturePicture.new(number) }; end
  def method_missing(name, *args); $effects << ["screen", name.to_s, describe(args)]; end
  def respond_to_missing?(*); true; end
end

# The game's sounds, which note every call.
module Audio
  def self.method_missing(name, *args); $effects << ["audio", name.to_s, describe(args)]; end
  def self.respond_to_missing?(*); true; end
end

# The message window, which notes its lines.
class FixtureMessage
  attr_accessor :speaker, :face_name, :face_index, :background, :position
  def add(text); $effects << ["message", text]; end
  def has_text?; false; end
end

# The troop and party, which note the skill names they show.
class FixtureUnit
  def initialize(side); @side = side; end
  def display_skill_name=(name); $effects << ["skill_name", @side, name]; end
  def screen; @screen ||= FixtureScreen.new; end
end

# Describes a value the old playback handed on, as fixtures/wire describes a line's values.
#
# @param value [Object] The value.
# @return [Object] Its description.
def describe(value)
  case value
  when nil, true, false then value
  when Integer then { "i" => value.to_s }
  when Float then { "f" => [value].pack("G").unpack1("H*") }
  when String then { "s" => value }
  when Symbol then { "sym" => value.to_s }
  when Array then value.map { |item| describe(item) }
  when FixtureBattler then { "ref" => value.ref }
  when Color then { "c" => [value.red, value.green, value.blue, value.alpha].map { |channel| [channel.to_f].pack("G").unpack1("H*") } }
  else { "other" => value.class.name }
  end
end

# The kinds the old playback played without a check, noted as passed.
PASSED = %w(values time_stop turn emerge item_used battler.sprite_effect_type battler.animation_mirror).freeze

play = PLAYBACK.method(:play)
PLAYBACK.define_singleton_method(:play) do |scene, event|
  PASSED.include?(event[0]) ? $effects << ["pass", event[0]] : play.call(scene, event)
end
PLAYBACK.define_singleton_method(:battler) { |ref| FixtureBattler.new(ref) }
MGQ_MpCoopScene.define_singleton_method(:map_graphics?) { |_graphics| true }

# The lists the old hooks recorded, which the guest's setup hands on.
LISTS = {
  "log" => sync::Hooks::LOG_METHODS.map(&:to_s), "picture" => sync::Hooks::PICTURE_METHODS.map(&:to_s),
  "screen" => sync::Hooks::SCREEN_METHODS.map(&:to_s), "audio" => sync::Hooks::AUDIO_METHODS.map(&:to_s),
  "scene_calls" => sync::Hooks::SCENE_CALL_NAMES,
}.freeze

# The battle log's calls a guest of the cases makes itself.
LOG_CALLS = %w(display_damage display_action_results display_use_item).freeze

# Plays one case on the old scripts.
#
# @param entry [Hash] The case: "names" (the host's names line or nil), "own" (the guest's names the
#   host's party and troop stand for), "name_box", "animations", "seat" and "body".
# @return [Hash] The case with "effects", "events", "unreadable", "others_choose" and "logs".
def play_case(entry)
  sync = MGQ_MpBattlesSync
  MGQ_MpLog.instance_variable_set(:@logged, {})
  $my_seat = entry["seat"]
  sync.join_world(:guest, "fx", [0], "Host")
  sync.battle_started
  sync::Hooks.instance_variable_set(:@log_calls, LOG_CALLS)
  $data_animations = Array.new(entry["animations"]) { |id| id.zero? ? nil : :animation }
  $game_message = FixtureMessage.new
  $game_party = FixtureUnit.new("party")
  $game_troop = FixtureUnit.new("troop")
  own = entry["own"].map { |names| names.map { |name| Struct.new(:name).new(name) } }
  sync.define_singleton_method(:party_side) { own[0] }
  sync.define_singleton_method(:troop_side) { own[1] }
  sync.define_singleton_method(:same_side?) { true }
  if entry["name_box"]
    Object.const_set(:Window_NameMessage, Class.new) unless defined?(Window_NameMessage)
  elsif defined?(Window_NameMessage)
    Object.send(:remove_const, :Window_NameMessage)
  end
  scene = FixtureScene.new
  $log.clear
  $effects = []
  PLAYBACK.reset
  sync::Names.instance_variable_set(:@swaps, {})
  sync::Names.instance_variable_set(:@pattern, nil)
  sync::Names.setup(entry["names"].to_s) if entry["names"]
  PLAYBACK.instance_variable_set(:@stats, Hash.new(0))
  others = 0
  sync::Channel.receive(0, "events", entry["body"])
  while (event = PLAYBACK.next_event(scene))
    case event[0]
    when "commands", "end" then $effects << ["marker", event[0]]
    when "choose_again"
      Array(event[1]).include?(sync.own_seat) ? $effects << ["marker", "choose_again"] : others += 1
    else PLAYBACK.play(scene, event)
    end
  end
  stats = PLAYBACK.instance_variable_get(:@stats)
  logs = $log.map { |line| line.sub(/\Abattle sync: /, "") }
  sync.finish
  entry.merge("effects" => $effects, "events" => stats[:events], "unreadable" => stats[:unreadable], "others_choose" => others, "logs" => logs)
end

# Writes a line of values as the host's recorder wrote it.
#
# @param values [Array] The values.
# @return [String] The line.
def line(*values)
  MGQ_MpBattlesSync::Wire.line(values)
end

# A setup of the hand cases: the host names Alice and Slime, the guest's own names differ.
NAMED = { "names" => line(["Alice (Host)", "Luka"], ["Slime"]), "own" => [["Alice", "Luka (Me)"], ["Slime Girl"]],
          "name_box" => true, "animations" => 10, "seat" => 1 }.freeze

# Builds a hand case.
#
# @param name [String] What the case shows.
# @param lines [Array<String>] The send's lines.
# @param setup [Hash] Changes of NAMED.
# @return [Hash] The case.
def hand(name, lines, setup = {})
  NAMED.merge(setup).merge("name" => name, "body" => lines.join("\n"))
end

HAND = [
  hand("the battle log's lines swap the host's names, its other methods are left out",
       [line("log.add_text", "Alice (Host) hits Slime!"), line("log.replace_text", "Luka falls", 3), line("log.unknown", "Alice (Host)")]),
  hand("a longer name swaps before a shorter one it starts with",
       [line("log.add_text", "Alice (Host) and Alice")], "names" => line(["Alice (Host)", "Alice"], []), "own" => [["A", "B"], []]),
  hand("a popup swaps its text, a missing one reads as empty", [line("popup", "Slime is down", :mgq_mp_departure), line("popup", nil, nil)]),
  hand("a message swaps its text but not its name box or speaker line",
       [line("message", nil, "Face", 1, 0, 2, "\\n<Alice (Host)>Alice (Host) attacks Slime"),
        line("message", nil, "", 0, 0, 2, "【Alice (Host)】Slime!"), line("message", nil, "", 0, 0, 2, "\\N3<Luka>\\n<Slime>Luka【Slime】")]),
  hand("an untranslated guest reads a name box as a speaker line", [line("message", nil, "", 0, 0, 2, "\\n<Alice (Host)>Slime, run!"),
                                                                    line("message", nil, "", 0, 0, 2, "Plain Slime")], "name_box" => false),
  hand("the skill's name swaps on either side", [line("skill_name", "troop", "Slime Tackle"), line("skill_name", "party", 5), line("skill_name", "party", "Luka Strike")]),
  hand("the guest makes only the calls its lists name",
       [line("call", "log", "display_damage", 7, nil, []), line("call", "log", "display_unheard_of", 7, nil, []),
        line("call", "scene", "process_skill_word", 7, nil, []), line("call", "scene", "exit", 7, nil, []),
        line("call", nil, "display_damage", 7, nil, []), line("call", 5, "count", 7, nil, [])]),
  hand("pictures the game takes show, others are left out with the reason",
       [line("picture.show", 3, "cutin_alice.v2", 0, 10, 20.5, 100, 100, 255, 0), line("picture.move", 3, 0, 10, 20, 100, 100, 0, 0, 30),
        line("picture.erase", 3), line("picture.show", 4, "../cutin", 0, 10, 20, 100, 100, 255, 0), line("picture.show", 0, "cutin", 0, 0, 0, 100, 100, 255, 0),
        line("picture.show", 101, "cutin", 0, 0, 0, 100, 100, 255, 0), line("picture.move", 4, 0, 10, 20, 100, 100, 0, 0, -1),
        line("picture.spin", 4), line("picture.show", 5, "cutin", 0, 1e9, 0, 100, 100, 255, 0)]),
  hand("the screen takes a flash and a shake in the editor's range alone, other changes are left out silently",
       [line("screen.start_flash", Color.new(255, 255, 255, 170), 20), line("screen.start_flash", "white", 20), line("screen.start_shake", 5, 5, 10),
        line("screen.start_shake", 50, 5, 10), line("screen.wobble", 3), line("screen.start_fadeout", 30)]),
  hand("sounds play from the Audio folder within the game's volumes and pitches",
       [line("audio.se_play", "Audio/SE/Attack1", 80, 100), line("audio.bgm_play", "Audio/BGM/Battle 1.ogg", 100, 100, 1200),
        line("audio.se_play", "Audio/SE/Attack1", 101, 100), line("audio.se_play", "Audio/SE/Attack1", 80, 40),
        line("audio.se_play", "Audio/SE/Attack1", 80, 100, 5), line("audio.se_play", "Audio/../Save/x", 80, 100),
        line("audio.se_play", "Data/SE/x", 80, 100), line("audio.se_stop"), line("audio.se_stop", 1), line("audio.bgm_fade", 2000),
        line("audio.bgm_fade", 20_000), line("audio.start_over_drive", 1, true), line("audio.start_over_drive", "x"), line("audio.unheard_of", 1)]),
  hand("the scene's waits take at most 10 seconds as whole frames, other methods are left out",
       [line("scene.wait", 30), line("scene.wait", 9999), line("scene.abs_wait", "12"), line("scene.wait", nil), line("scene.abs_wait", 2.9),
        line("scene.wait_for_message"), line("scene.wait_for_effect"), line("scene.nap", 5)]),
  hand("animations this game has start, others are left out",
       [line("animation", "@a0", ["@e0"], 5), line("animation", "@a0", ["@e0"], 0), line("animation", "@a0", ["@e0"], 10),
        line("battler.animation_id", "@e1", 9), line("battler.animation_id", "@e1", 0), line("battler.animation_id", "@e1", 99),
        line("battler.animation_id", "@e1", -2), line("battler.animation_id", "@e1", "3"), line("battler.animation_id", "@e1", 1.7)].map { |text| text.gsub("s@", "@") }),
  hand("plain events pass, an unknown kind is left out with the reason",
       [line("values", "@a0", 10, 5, 0, [], [], [0] * 8, 0), line("time_stop", 0, nil), line("turn", 2), line("emerge", true, false),
        line("item_used", "@a0", "t3"), line("battler.sprite_effect_type", "@e0", :collapse), line("battler.animation_mirror", "@e0", true),
        line("frobnicate", 1)].map { |text| text.gsub("s@", "@").gsub("st3", "t3") }),
  hand("lines that do not read are counted and left out once",
       ["[\ti1", "i5", "", "\t", line("turn", 3), "s" + "x" * 30 + "\t]"]),
  hand("the markers come through, a choose again only when it names the player",
       [line("commands"), line("choose_again", [2]), line("choose_again", [1, 2]), line("choose_again", 1), line("choose_again", nil), line("end", "process_victory", 0, 0)]),
  hand("without names nothing is swapped", [line("log.add_text", "Alice (Host) hits Slime!")], "names" => nil),
  hand("names that do not read swap nothing", [line("log.add_text", "Alice (Host) hits Slime!")], "names" => "[\t[", "own" => [["Alice"], ["Slime Girl"]]),
].freeze

served = JSON.parse(File.read(File.join(HERE, "served_streams.json"), :encoding => "UTF-8"))["battles"]
SERVED = served.each_with_index.flat_map do |battle, index|
  names = MGQ_MpBattlesSync::Wire.parse(battle["names"].to_s) || [[], []]
  own = names.first(2).map { |side| Array(side).each_with_index.map { |name, place| place.even? ? "#{name} (seen)" : name.to_s } }
  battle["sends"].each_with_index.map do |body, send|
    { "name" => "served battle #{index + 1}, send #{send + 1}", "names" => battle["names"], "own" => own, "name_box" => index != 1,
      "animations" => 120, "seat" => 1, "body" => body }
  end
end

cases = (HAND + SERVED).map { |entry| play_case(entry) }
File.write(File.join(HERE, "stream.json"), JSON.pretty_generate({ "lists" => LISTS, "log_calls" => LOG_CALLS, "cases" => cases }) + "\n")
puts "wrote stream.json: #{cases.size} cases, #{cases.map { |entry| entry['effects'].size }.sum} effects"

# The verdicts and the session: the old live battle's endings and its messages, seats, departures
# and ending checks, played on the old scripts with the battle's mode, the game's endings and its
# message noted.

# A battle mode whose answers each case sets, noting what is asked of it.
module FixtureMode
  extend MGQ_MpBattles::Mode
  def self.same_side?; $side; end
  def self.take_over(_scene); $effects << ["take_over"]; $take_over; end
  def self.other_side_gone?; $other_gone; end
  def self.left(seat); $effects << ["mode_left", seat]; end
  def self.player_seats; []; end
end
sync.define_singleton_method(:mode) { FixtureMode }
sync.define_singleton_method(:same_side?) { $side }
%w(process_victory process_defeat process_abort).each do |name|
  BattleManager.define_singleton_method(name) { $effects << ["process", name] }
end
sync::Live.define_singleton_method(:win) { |_scene| $effects << ["win"]; :won_result }
sync::Live.define_singleton_method(:forfeit) { |_scene| $effects << ["forfeit"] }
sync::Departures.define_singleton_method(:say) { |text| $effects << ["say", text] }
friend_gone = sync.method(:friend_gone)
$game_message = FixtureMessage.new
$game_message.define_singleton_method(:add) { |text| $effects << ["message", text] }

# Starts a case: the log and the noted effects empty, every line logged anew.
def fresh
  MGQ_MpLog.instance_variable_set(:@logged, {})
  $log.clear
  $effects = []
end

# The log's lines of the live battle since the case started.
#
# @return [Array<String>] The lines, without their tag.
def logged
  $log.grep(/\Abattle sync: /).map { |line| line.sub(/\Abattle sync: /, "") }
end

$my_seat = 0
scene = FixtureScene.new
early = []
%w(won left forfeit broken gone other).each do |reason|
  [[false, false], [true, true], [true, false]].each do |team, side|
    [false, true].each do |missed|
      next if missed && reason != "broken"

      sync.finish
      sync.join_world(:host, "v1", [2], "Rival", :pvp, team)
      sync.battle_started
      $side = side
      sync.instance_variable_set(:@missed, missed ? "Rival's battle ended before you could join." : nil)
      sync.define_singleton_method(:friend_gone) { |_scene| $effects << ["friend_gone"]; :gone_result }
      fresh
      result = sync::Live.end_early(scene, reason.to_sym)
      early << { "reason" => reason, "team" => team, "side" => side, "missed" => missed, "effects" => $effects, "logs" => logged,
                 "result" => result.inspect }
    end
  end
end
sync.define_singleton_method(:friend_gone, friend_gone)

guest = []
%w(process_victory process_defeat process_abort process_escape).each do |result|
  [true, false].each do |side|
    [false, true].each do |take_over|
      sync.finish
      sync.join_world(:guest, "v2", [0], "Rival", :pvp, true)
      sync.battle_started
      $side = side
      $take_over = take_over
      fresh
      sync::Live.guest_end(result, scene)
      guest << { "result" => result, "side" => side, "take_over" => take_over, "effects" => $effects, "logs" => logged }
    end
  end
end

gone = []
%w(host guest).each do |role|
  [["coop", false], ["pvp", false], ["pvp", true]].each do |kind, team|
    [false, true].each do |side|
      [false, true].each do |take_over|
        sync.finish
        sync.join_world(role.to_sym, "v3", role == "host" ? [2] : [0], "Rival", kind.to_sym, team)
        sync.battle_started
        $side = side
        $take_over = take_over
        fresh
        result = sync.friend_gone(scene)
        $effects << ["solo"] if sync.solo?
        gone << { "role" => role, "kind" => kind, "team" => team, "side" => side, "take_over" => take_over, "effects" => $effects,
                  "logs" => logged, "result" => result }
      end
    end
  end
end
sync.finish
File.write(File.join(HERE, "verdicts.json"), JSON.pretty_generate({ "early" => early, "guest" => guest, "gone" => gone }) + "\n")
puts "wrote verdicts.json: #{early.size + guest.size + gone.size} cases"

# The session's scenario: each step what the old scripts did, answered and logged of what the
# session now does.
peers = MGQ_MpOverworldSync::Peers
peers.all.replace([peers::Peer.new(2, { "id" => "id-2", "name" => "Ann" }, nil, false), peers::Peer.new(3, { "id" => "id-3", "name" => "Bea" }, nil, false),
                   peers::Peer.new(4, { "id" => "id-4", "name" => "Cid" }, nil, false), peers::Peer.new(0, { "id" => "id-0", "name" => "Host" }, nil, false)])
$other_gone = false
$side = true
STEPS = []
# The lines of the log that the session writes now.
SESSION_LINES = /\A(received |ignored |the live battle broke off: |the other side of the battle is gone)/

# Runs a step of the scenario on the old scripts and notes it.
#
# @param op [String] The step's name, which MGQOnline.Game.Tests runs on the session.
# @param args [Hash] What it takes.
# @yieldreturn [Object] What it answers.
def step(op, args = {})
  sync = MGQ_MpBattlesSync
  fresh
  departed = []
  left = sync.method(:guest_left)
  sync.define_singleton_method(:guest_left) do |seat|
    before = sync.guests_in.include?(seat)
    left.call(seat)
    departed << [seat, sync.guests_in.size] if before
  end
  value = yield
  sync.define_singleton_method(:guest_left, left)
  STEPS << args.merge("op" => op, "value" => value.is_a?(Symbol) ? value.to_s : value, "departed" => departed,
                      "logs" => logged.grep(SESSION_LINES), "who" => [0, 2, 3, 4, 5].each_with_object({}) { |seat, names| names[seat.to_s] = sync.who(seat) })
end

# Runs ending checks with the player in a world or not.
#
# @param count [Integer] How many.
# @param in_world [Boolean] Whether the player is in a world.
# @return [Array<String>] The endings that came, in order.
def ticks(count, in_world)
  MGQ_MpOverworldSync.define_singleton_method(:in_world?) { in_world }
  (1..count).map { MGQ_MpBattlesSync::Channel.ending }.compact.map(&:to_s)
end

# Tells of a player leaving or joining.
#
# @param seat [Integer] The player's seat.
# @param kind [Symbol] :left or :joined.
# @return [Boolean] Whether the player was told.
def told(seat, kind)
  shown = 0
  MGQ_MpBattlesSync::Departures.define_singleton_method(:popup) { |*| shown += 1 }
  MGQ_MpBattlesSync::Departures.tell(MGQ_MpOverworldSync::Peers::Peer.new(seat, { "name" => "P#{seat}" }, nil, false), "P#{seat} #{kind}.", kind)
  shown == 1
end

# Writes what the host tells its guests it waits for.
#
# @param seats [Array<Integer>] The seats waited for.
# @return [Array, nil] The message's kind and body, nil for none sent.
def told_waiting(seats)
  posted = nil
  MGQ_MpBattlesSync::Channel.define_singleton_method(:post) { |kind, body = ""| posted = [kind, body] }
  MGQ_MpBattlesSync::Live.tell_waiting(seats)
  posted
end

# Joins a battle as the scenario's step.
#
# @param role [String] "host" or "guest".
# @param bid [String] The battle's id.
# @param seats [Array<Integer>] The other games' seats.
# @param player [String] Who the waits name.
# @param kind [String] "coop" or "pvp".
def joined(role, bid, seats, player, kind)
  step("join", "role" => role, "bid" => bid, "seats" => seats, "player" => player, "kind" => kind, "team" => false) do
    MGQ_MpBattlesSync.join_world(role.to_sym, bid, seats, player, kind.to_sym, false)
    nil
  end
  step("start") { MGQ_MpBattlesSync.battle_started; nil }
end

# Receives a message as the scenario's step.
#
# @param seat [Integer] The sender's seat.
# @param kind [String] What it is.
# @param body [String] The rest.
def received(seat, kind, body = "")
  step("receive", "seat" => seat, "kind" => kind, "body" => body) { MGQ_MpBattlesSync::Channel.receive(seat, kind, body); nil }
end

channel = sync::Channel
joined("host", "s1", [2, 3], "the party", "coop")
step("expect", "seats" => [4]) { sync.expect([4]); sync.expected }
[[2, "ready"], [5, "ready"], [4, "commands", "c4"], [3, "events", "e1"], [3, "events", "e2"], [2, "commands", "c2"], [3, "leave"],
 [3, "events", "e3"], [3, "events", "e4"]].each { |message| received(*message) }
step("pending", "kind" => "events") { channel.pending("events") }
step("take", "kinds" => ["ready"], "seat" => nil) { channel.take("ready") }
step("take", "kinds" => %w(commands events), "seat" => nil) { channel.take_first(%w(commands events)) }
step("take", "kinds" => ["commands"], "seat" => 2) { channel.take_from("commands", 2) }
step("take", "kinds" => ["commands"], "seat" => 2) { channel.take_from("commands", 2) }
step("ticks", "count" => 60, "in_world" => true) { ticks(60, true) }
step("gone", "seats" => [2]) { sync::Seats.presence(peers.all[0], :gone); nil }
step("ticks", "count" => 60, "in_world" => true) { ticks(60, true) }
received(2, "forfeit")
step("ticks", "count" => 1, "in_world" => true) { ticks(1, true) }
step("ticks", "count" => 1, "in_world" => true) { ticks(1, true) }
step("keep", "seats" => [2]) { sync.keep_seats([2]); sync.seats }
step("tell", "seat" => 7, "kind" => "left") { told(7, :left) }
step("tell", "seat" => 7, "kind" => "left") { told(7, :left) }
step("tell", "seat" => 7, "kind" => "joined") { told(7, :joined) }
(10..41).each { |seat| step("tell", "seat" => seat, "kind" => "left") { told(seat, :left) } }
step("tell", "seat" => 7, "kind" => "left") { told(7, :left) }
step("finish") { sync.finish; sync.role }
joined("guest", "s2", [0], "Host", "pvp")
step("admit", "channel" => false, "bid" => "s1", "kind" => "commands", "who_seat" => 0) { sync.take(peers.all[3], { "battle" => "commands", "bid" => "s1", :payload => "" }); nil }
step("admit", "channel" => true, "bid" => "s2", "kind" => "commands", "who_seat" => 0) { sync.take_served(0, { "battle" => "commands", "bid" => "s2", :payload => "" }); nil }
received(0, "broken")
step("ticks", "count" => 2, "in_world" => true) { ticks(2, true) }
step("ready", "several" => false) { sync::Live.all_ready? }
received(0, "ready")
step("ready", "several" => false) { sync::Live.all_ready? }
step("finish") { sync.finish; sync.role }
joined("host", "s3", [2, 3], "the party", "coop")
step("ready_reset") { sync::Live.instance_variable_set(:@ready, []); nil }
received(2, "ready")
step("ready", "several" => true) { sync::Live.all_ready? }
step("not_ready") { sync::Live.not_ready }
received(3, "ready")
step("ready", "several" => true) { sync::Live.all_ready? }
step("tell_waiting", "seats" => [3, 2]) { told_waiting([3, 2]) }
step("tell_waiting", "seats" => [2, 3]) { told_waiting([2, 3]) }
step("tell_waiting", "seats" => []) { told_waiting([]) }
received(3, "leave")
step("ticks", "count" => 60, "in_world" => false) { ticks(60, false) }
step("finish") { sync.finish; sync.role }
joined("guest", "s4", [0], "Host", "coop")
received(0, "waiting", "0,2,3")
received(0, "waiting", "2,3")
step("host_waiting") { $my_seat = 2; names = sync::Live.host_waits_for; $my_seat = 0; names }
step("finish") { sync.finish; sync.role }
File.write(File.join(HERE, "session.json"), JSON.pretty_generate({ "steps" => STEPS }) + "\n")
puts "wrote session.json: #{STEPS.size} steps"

# The guests' commands: which places the old Commands.apply gave which actions, with every
# character taking two actions and allowed every skill below KNOWN_SKILLS, the skill of no type
# and the items a battle allows.

# The actions the host's game gives a character before the commands: two of the computer's.
COMPUTER = [:computer, :computer].freeze
FixtureMode.define_singleton_method(:same_side_as_host?) { |_seat| $same_host }
FixtureMode.define_singleton_method(:heir_of) { |seat| $heirs[seat] }
FixtureMode.define_singleton_method(:take_order) { |_seat, _order| nil }
$unchained = []

# Writes the actions a character ended with, as the golden cases note them.
#
# @param battler [Game_Battler] The character.
# @return [String, Array] "kept" for the computer's, else each action as [kind, id, target, chain].
def actions_of(battler)
  actions = MGQ_MpGame.get(battler, :actions)
  return "kept" if actions == COMPUTER

  actions.map do |action|
    chain = []
    link = action.chain_action
    while link
      chain << [link.item[0].to_s, link.item[1], link.target_index]
      link = link.chain_action
    end
    [action.item[0].to_s, action.item[1], action.target_index, chain]
  end
end

# Gives a side the guest's commands on the old scripts.
#
# @param name [String] What the case shows.
# @param commands [Array] Per place its commands, then the order, as the guest writes them.
# @param owners [Array<Integer, nil>] Each place's owner.
# @param options [Hash] "seat", "several", "heirs" and "body" (a line written by hand).
# @return [Hash] The case.
def planned(name, commands, owners, options = {})
  sync = MGQ_MpBattlesSync
  seat = options.fetch("seat", 2)
  several = options.fetch("several", true)
  sync.finish
  several ? sync.join_world(:host, "p1", [2, 3], "the party", :coop) : sync.join_world(:host, "p1", [2], "Rival", :pvp)
  sync.battle_started
  $same_host = true
  $heirs = options.fetch("heirs", {})
  battlers = owners.each_with_index.map do |owner, place|
    actor = Game_MpActor.new(MGQ_MpActors::Builds::Member.new(10 + place), "P")
    actor.mp_seat = owner
    actor.actions = COMPUTER.dup
    actor
  end
  $game_party = Game_Party.new
  $game_party.own = battlers
  body = options["body"] || MGQ_MpBattlesSync::Wire.line(commands)
  fresh
  sync::Commands.apply(body, seat)
  { "name" => name, "body" => body, "seat" => seat, "several" => several, "owners" => owners, "heirs" => $heirs.to_a,
    "skills" => $data_skills.size, "items" => $data_items.size, "places" => battlers.map { |battler| actions_of(battler) }, "logs" => logged }
end

skill = lambda { |id, target = 0, chain = nil| chain ? ["skill", id, target, chain] : ["skill", id, target] }
plans = [
  planned("a guest commands only their own places", [[[skill.(5)], [skill.(6, -1)], [skill.(7, 1)], []]], [0, 2, 2, 3]),
  planned("and those of a player who left that they took over", [[[skill.(5)], [skill.(6, -1)], [skill.(7, 1)], [skill.(8, 2)]]], [0, 2, 2, 3], "heirs" => { 3 => 2 }),
  planned("an empty list takes the actions away, nil keeps the computer's", [[nil, [], nil, nil]], [2, 2, 2, 2]),
  planned("commands the host cannot read are left out in their place",
          [[[["skill", 0, 0], ["skill", 200, 0], ["skill", 5, 256], ["skill", 5, -2]], [["magic", 5, 0], "skill", ["skill", 5.0, 0], ["skill", 5, "0"]],
            [["item", 3, 1], ["item", 50, 1], ["skill", 2**70, 0], ["skill", 5, 0]], [["skill", 5, -1], ["skill", 6, 255]]]], [2, 2, 2, 2]),
  planned("each character takes as many commands as the host's game gives it actions", [[[skill.(5), skill.(6), skill.(7)], [skill.(8)]]], [2, 2]),
  planned("a chain takes at most 16 skills", [[[skill.(5, 0, (1..17).map { |id| skill.(20 + id) })]]], [2]),
  planned("a chain ends at its first item or command the host cannot read",
          [[[skill.(5, 0, [skill.(6), ["item", 3, 0], skill.(7)])], [skill.(5, 0, [skill.(6), ["skill", 0, 0], skill.(7)])],
            [skill.(5, 0, [skill.(6), [], skill.(7)])], [skill.(5, 0, [])]]], [2, 2, 2, 2]),
  planned("skills and items the character may not use are left out, a chain ending there",
          [[[skill.(160), ["item", 45, 0]], [skill.(199), ["item", 3, 0]], [skill.(5, 0, [skill.(6), skill.(160), skill.(7)])]]], [2, 2, 2]),
  planned("in a duel the guest commands every place of its side", [[[skill.(5)], [skill.(6)], nil]], [nil, 7, nil], "seat" => nil, "several" => false),
  planned("commands that do not read keep every place's", [], [2, 2], "body" => "[\t["),
  planned("a list that is no list keeps every place's", [5], [2, 2]),
]
File.write(File.join(HERE, "plan.json"), JSON.pretty_generate({ "cases" => plans }) + "\n")
puts "wrote plan.json: #{plans.size} cases"

# The team duel's sides: who commands the characters of who left, as the old battles_team.rbx
# settled them on the host and took them on a guest.
load_script "battles_team"
team = MGQ_MpBattlesTeam
sync.define_singleton_method(:mode) { MGQ_MpBattles.mode_of(sync.coop? ? :coop : sync.team? ? :team : :duel) }
posted = []
sync::Channel.define_singleton_method(:post) { |kind, body = ""| posted << [kind, body] }
team_steps = []
# Notes a step of the team duel's scenario.
#
# @param op [String] The step.
# @param args [Hash] What it takes.
# @yieldreturn [Object] What it answers.
team_step = lambda do |op, args = {}, &block|
  fresh
  posted.clear
  value = block.call
  team_steps << args.merge("op" => op, "value" => value, "heirs" => team.instance_variable_get(:@heirs).to_a, "posted" => posted.map(&:last),
                           "logs" => $log.map { |line| line.sub(/\A[a-z ]+: /, "") }.grep(/dropped who commands/))
end
players = lambda { |seats| seats.map { |seat| [seat, "P#{seat}", "1,2", [], 8, [0, 1], 2, 0] } }
$my_seat = 0
team_step.call("join", "own" => [0, 2], "other" => [5, 6], "same_side" => true) do
  sync.finish
  sync.join_world(:host, "t1", [2, 5, 6], "the duel", :pvp, true)
  sync.battle_started
  team.prepare(players.([0, 2]), players.([5, 6]), true)
  nil
end
team_step.call("same_side", "seat" => 2) { team.same_side_as_host?(2) }
team_step.call("same_side", "seat" => 5) { team.same_side_as_host?(5) }
team_step.call("settle") { team.settle; nil }
team_step.call("left", "seat" => 5) { sync.guest_left(5); nil }
team_step.call("settle") { team.settle; nil }
team_step.call("heir", "seat" => 5) { team.heir_of(5) }
team_step.call("settle") { team.settle; nil }
team_step.call("gone") { team.other_side_gone? }
team_step.call("left", "seat" => 2) { sync.guest_left(2); nil }
team_step.call("settle") { team.settle; nil }
team_step.call("left", "seat" => 6) { sync.guest_left(6); nil }
team_step.call("settle") { team.settle; nil }
team_step.call("gone") { team.other_side_gone? }
team_step.call("join", "own" => [5, 6], "other" => [0, 2], "same_side" => false) do
  sync.finish
  $my_seat = 5
  sync.join_world(:guest, "t2", [0], "Me", :pvp, true)
  sync.battle_started
  team.prepare(players.([5, 6]), players.([0, 2]), false)
  nil
end
[[6, 5], [6, "x", 7, 5, [8], 2], [6, 5, 6, 2], 5, [], nil].each do |pairs|
  body = pairs.nil? ? "[\t[" : MGQ_MpBattlesSync::Wire.line([pairs])
  team_step.call("take", "body" => body) { team.take_heirs(body); nil }
end
$my_seat = 0
sync.finish
File.write(File.join(HERE, "team.json"), JSON.pretty_generate({ "steps" => team_steps }) + "\n")
puts "wrote team.json: #{team_steps.size} steps"

# The host's recording: what the old Recorder sent and counted for a sequence of events, frames,
# battlers' values and command phases, with each step's input as the buffer now takes it.
recorder = sync::Recorder
# A battler of the recording, whose values the steps set.
class RecordedBattler < Game_Battler
  attr_reader :place
  def initialize(place); @place = place; end
end
$recorded = (0...3).map { |place| RecordedBattler.new(place) }
$values_of = {}
recorder.define_singleton_method(:battlers) { $recorded }
recorder.define_singleton_method(:value_fields) { |battler| $values_of[battler.place] }
recorder.define_singleton_method(:ref) { |battler| "a#{battler.place}" }
recorder.define_singleton_method(:time_stop) { nil }
sync.define_singleton_method(:mode) { FixtureMode }
FixtureMode.define_singleton_method(:before_send) { $sends << :before_send }
sync::Channel.define_singleton_method(:post) { |kind, body = ""| $sends << [kind, body] }
record_steps = []
# Runs a step of the recording on the old scripts and notes what it sent and logged.
#
# @param op [String] The step, which MGQOnline.Game.Tests runs on the buffer.
# @param args [Hash] What the buffer takes.
# @yieldreturn [Object] Nothing.
record_step = lambda do |op, args = {}, &block|
  fresh
  $sends = []
  block.call
  record_steps << args.merge("op" => op, "sends" => $sends.map { |sent| sent == :before_send ? "before_send" : sent[1] },
                             "logs" => logged.grep(/\A(recording|streamed)/))
end
$values_of.merge!(0 => [100, 10, 0, [], [], [0] * 8, 0], 1 => [80, 5, 3, [4], [2], [0] * 8, 1], 2 => [40, 0, 0, [], [], [0] * 8, 0])
entries = lambda { $recorded.map { |battler| [battler.place, "a#{battler.place}", MGQ_MpBattlesSync::Wire.line($values_of[battler.place])] } }
values_step = lambda { |full| record_step.call("values", "battlers" => entries.call, "full" => full) { recorder.values(full) } }
record_step.call("start") { recorder.start }
values_step.call(false)
9.times { record_step.call("tick") { recorder.tick } }
record_step.call("tick") { recorder.tick }
record_step.call("tick") { recorder.tick }
record_step.call("event", "line" => MGQ_MpBattlesSync::Wire.line(["log.add_text", "Hit!"])) { recorder.event("log.add_text", "Hit!") }
$values_of[1] = [70, 5, 3, [4], [1], [0] * 8, 1]
values_step.call(false)
values_step.call(false)
values_step.call(true)
(1..205).each { |count| record_step.call("event", "line" => MGQ_MpBattlesSync::Wire.line(["scene.wait", count])) { recorder.event("scene.wait", count) } }
record_step.call("flush") { recorder.flush }
record_step.call("flush") { recorder.flush }
record_step.call("phase", "battlers" => entries.call, "line" => MGQ_MpBattlesSync::Wire.line(["commands"])) do
  recorder.turn_started
  recorder.command_phase
end
record_step.call("event", "line" => MGQ_MpBattlesSync::Wire.line(["turn", 1])) { recorder.event("turn", 1) }
record_step.call("finish") { recorder.finish(0) }
record_step.call("start") { recorder.start }
record_step.call("event", "line" => MGQ_MpBattlesSync::Wire.line(["turn", 1])) { recorder.event("turn", 1) }
record_step.call("stop") { recorder.stop }
File.write(File.join(HERE, "recorder.json"), JSON.pretty_generate({ "steps" => record_steps }) + "\n")
puts "wrote recorder.json: #{record_steps.size} steps"
