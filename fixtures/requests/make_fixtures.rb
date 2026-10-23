#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Writes edits.json: which changes of a world's edit went to the relay and what the creator was told
# of them, as world_screen.rbx's edit_world and difficulty_text decided before the requests moved to
# WorldRequests in MGQOnline.Game, as golden cases both sides check.
#
#   ruby fixtures/requests/make_fixtures.rb <world_screen.rbx> <world.rbx> of the version to record

require "json"

root = File.expand_path("../..", __dir__)
screen = File.read(ARGV[0] || File.join(root, "GameScript/Multiplayer/Scripts/world_screen.rbx"), :encoding => "UTF-8")
world = File.read(ARGV[1] || File.join(root, "GameScript/Multiplayer/Scripts/world.rbx"), :encoding => "UTF-8")
RULES = JSON.parse(File.read(File.join(root, "fixtures/world/rules.json"), :encoding => "UTF-8"))["rules"]

# The world script's rules as fixtures/world/rules.json gives them, with its squad_summary and
# formation_name as the version recorded wrote them.
module MGQ_MpWorld
  def self.rule(name)
    RULES[name]
  end

  def self.difficulties
    RULES["difficulties"].map { |value, _| value }
  end

  def self.difficulty_names
    RULES["difficulties"].map { |_, name| name }
  end

  def self.difficulty_name(value)
    index = difficulties.index(value)
    index ? difficulty_names[index] : nil
  end

  def self.default_squad
    squad = RULES["squad"]
    { :luka => squad["luka"], :formation => squad["formation"], :front => squad["front"], :raid_front => squad["raid_front"] }
  end
end
%w(formation_name squad_summary).each do |name|
  method = world[/^  def self\.#{name}\(.*?\n  end\n/m] or raise "world.rbx has no #{name}"
  MGQ_MpWorld.module_eval(method)
end

# Stands in for the shared settings: settings are shared when they start with "!".
module MGQ_MpWorldMods
  def self.creator_hashes(mods)
    "hashes of #{mods}"
  end

  def self.settings_of(listed, _fresh)
    listed.settings
  end

  def self.shared?(text)
    text.to_s.start_with?("!")
  end

  def self.with_marker(text)
    "!#{text}"
  end
end

# The form's values as the edit read them.
class Values
  def initialize(values)
    @values = values
  end

  def [](key)
    @values[key]
  end

  def difficulty
    @values[:difficulty]
  end

  def squad
    @values[:squad]
  end

  def raid_bosses?
    @values[:raid_bosses]
  end

  def other_mods_off?
    @values[:other_mods_off]
  end
end

Listed = Struct.new(:id, :creator_id, :settings, :raid, :difficulty, :squad, :raid_bosses, :other_mods_off) do
  def raid?
    raid
  end
end
Entry = Struct.new(:id, :listed)

# The screen with the recorded methods, its directory request caught.
class Harness
  attr_reader :sent

  def initialize(listed, values, me)
    @entry = Entry.new(listed.id, listed)
    @form = Values.new(values)
    @me = me
    @list_state = "ready"
  end

  def form
    @form
  end

  def start_action(_kind)
    @sent = yield
  end

  def edited
    { "settings" => @edited_settings, "difficulty" => @edited_difficulty, "squad" => @edited_squad && squad_of(@edited_squad),
      "raid_bosses" => @edited_raid_bosses, "other_mods_off" => @edited_other_mods }
  end

  def squad_of(squad)
    { "luka" => squad[:luka], "formation" => squad[:formation], "front" => squad[:front], "raid_front" => squad[:raid_front] }
  end
end
directory = Module.new
directory.define_singleton_method(:edit) { |*arguments| arguments }
MGQ_MpWorld.const_set(:Directory, directory)
%w(edit_world difficulty_text).each do |name|
  method = screen[/^  def #{name}\b.*?\n  end\n/m] or raise "world_screen.rbx has no #{name}"
  Harness.class_eval(method)
end

def squad(luka, formation, front, raid_front)
  { :luka => luka, :formation => formation, :front => front, :raid_front => raid_front }
end

default = MGQ_MpWorld.default_squad
CASES = [
  ["a classic world kept as it was", [false, nil, nil, false, false], [nil, default, false, false]],
  ["a classic world gets raid bosses and turns other mods off", [false, nil, nil, false, false], [nil, default, true, true]],
  ["a classic world loses raid bosses", [false, nil, nil, true, true], [nil, default, false, true]],
  ["a raid world gets a difficulty", [true, nil, nil, false, true], [3, default, false, true]],
  ["a raid world keeps its difficulty", [true, 1, nil, false, true], [1, default, false, true]],
  ["a raid world back to per player", [true, 2, nil, false, true], [nil, default, false, true]],
  ["a raid world without squad rules keeps the defaults", [true, 0, nil, false, true], [0, default, false, true]],
  ["a raid world gets squad rules", [true, 0, nil, false, true], [0, squad(true, 6, 2, 1), false, true]],
  ["a raid world changes its squad rules to the defaults", [true, 0, squad(true, 0, 3, 4), false, true], [0, default, false, true]],
  ["a raid world allows other mods", [true, -2, squad(false, 8, 4, 4), false, true], [4, squad(false, 0, 1, 2), false, false]],
  ["its creator shares the mod settings", [false, nil, nil, false, false], [nil, default, false, false], ["a=b", true, "me"]],
  ["its creator stops sharing them", [false, nil, nil, false, false], [nil, default, false, false], ["!a=b", false, "me"]],
  ["an admin leaves the sharing to its creator", [false, nil, nil, false, false], [nil, default, false, false], ["a=b", true, "admin"]],
]

cases = CASES.map do |name, (raid, difficulty, listed_squad, raid_bosses, other_mods_off), (new_difficulty, new_squad, new_raid_bosses, new_other_mods_off), sharing|
  settings, shared, me = sharing || ["", false, "me"]
  listed = Listed.new("w1", "me", settings, raid, difficulty, listed_squad, raid_bosses, other_mods_off)
  values = { :seats => "6", :description => "About", :mods => "!Mod", :shared => shared, :difficulty => new_difficulty, :squad => new_squad,
             :raid_bosses => new_raid_bosses, :other_mods_off => new_other_mods_off }
  harness = Harness.new(listed, values, me)
  harness.edit_world
  squad_hash = lambda { |value| value && harness.squad_of(value) }
  { "name" => name, "raid" => raid, "difficulty" => difficulty, "squad" => squad_hash.call(listed_squad), "raid_bosses" => raid_bosses,
    "other_mods_off" => other_mods_off, "settings" => settings, "own" => me == "me", "form" => { "shared" => shared, "difficulty" => new_difficulty, "squad" => squad_hash.call(new_squad), "raid_bosses" => new_raid_bosses,
    "other_mods_off" => new_other_mods_off }, "edited" => harness.edited, "hashes" => harness.sent[4], "text" => harness.difficulty_text }
end
File.write(File.join(__dir__, "edits.json"), JSON.pretty_generate({ "edits" => cases }) + "\n")
