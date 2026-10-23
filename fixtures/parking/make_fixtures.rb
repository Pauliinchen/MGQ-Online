#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Writes plans.json: how world_mods_parking.rbx decided which scripts a world turns off, what
# entering it needs and what it said about them, before those rules moved to ParkingRules in
# MGQOnline.Game, as golden cases the C# tests check.
#
#   ruby fixtures/parking/make_fixtures.rb [world_mods_parking.rbx] [world_mods.rbx]

require "json"

scripts_dir = File.expand_path("../../GameScript/Multiplayer/Scripts", __dir__)
parking_source = File.read(ARGV[0] || File.join(scripts_dir, "world_mods_parking.rbx"), :encoding => "UTF-8").gsub("\r\n", "\n")
mods_source = File.read(ARGV[1] || File.join(scripts_dir, "world_mods.rbx"), :encoding => "UTF-8").gsub("\r\n", "\n")

# Stands in for the log the module extends.
module MGQ_MpLog; def log(_line); end; def log_once(_key, _line); end; end

# Stands in for the world: mod keys as the relay makes them of ASCII names, and the mods of a text
# as world.rbx read them before ModsText.
module MGQ_MpWorld
  SHARED_SCRIPTS = %w[patch multiplayer 0modconfigremake]
  def self.mod_key(name); name.to_s.downcase.sub(/\.rb\z/, "").delete(" \t\n\v\f\r_-"); end
  def self.short(id); id.to_s[0, 8]; end
  def self.mods_of(text)
    names = text.to_s.split(";").map { |mod| mod.strip.sub(/\A[!?]\s*/, "") }.reject { |mod| mod.empty? }
    required = text.to_s.split(";").map { |mod| mod.strip[/\A!\s*(\S.*)\z/, 1] }.compact
    essential = text.to_s.split(";").map { |mod| mod.strip[/\A\?\s*(\S.*)\z/, 1] }.compact
    (names & required) + (names & essential) + (names - required - essential)
  end
end

# Stands in for the world's mods: the personal keys a case sets, and list_text as world_mods.rbx
# has it.
module MGQ_MpWorldMods
  class << self; attr_accessor :personal; end
  def self.personal_keys; personal; end
end
list_text = mods_source[/^  def self\.list_text\(.*?\n  end\n/m] or raise "world_mods.rbx has no list_text"
MGQ_MpWorldMods.module_eval(list_text)

parking_module = parking_source[/^module MGQ_MpModParking\n.*?\n^end\n/m] or raise "world_mods_parking.rbx has no module"
eval(parking_module)

# Lets a case set what the DLL would tell.
module MGQ_MpModParking
  class << self; attr_accessor :case_scripts, :case_elsewhere, :case_state, :case_moved; end
  def self.scripts; case_scripts && case_scripts.reject { |path| shared?(path) }.uniq { |path| path_key(path) }; end
  def self.elsewhere; case_elsewhere && case_elsewhere.reject { |path| shared?(path) }.uniq { |path| path_key(path) }; end
  def self.parked_state; case_state; end
  def self.moved_here?; case_moved; end
end

Listed = Struct.new(:id, :mods, :other_mods_off)

OWNERS = ["Patch/Luka_Replacer/heroes.rb", "Patch\\Sub\\Deep\\x.rb", "Patch/Invasions.rb", "Patch/Odd.RB", "patch/lower/Mod.rb",
          "Invasions.rb", "Patch/ünïcode Mod.rb", "Patch//Twice//a.rb", "Other/Thing/x.rb", "Patch/Multiplayer/Old.rb",
          "Patch/0_ModConfigRemake.rb", "Patch/Sub/Multiplayer.rb"]

SCRIPTS = ["Patch/Invasions.rb", "Patch/Level_Cap.rb", "Patch/Luka_Replacer.rb", "Patch/Luka_Replacer/heroes.rb", "Patch/Sub/Extra-Mod.rb",
           "Patch/Victory_Screen.rb", "Patch/Multiplayer/Old_Backup.rb", "Patch/Multiplayer.rb", "Patch/Zeta.rb", "Patch/alpha.rb"]

PLANS = [
  { "name" => "allows other mods", "mods" => "", "off" => false },
  { "name" => "names some", "mods" => "!Level Cap; ?Luka Replacer" },
  { "name" => "names all in any case", "mods" => "level cap; Invasions; sub; luka-replacer; zeta; ALPHA" },
  { "name" => "a script of a folder names nothing", "mods" => "Level Cap; Luka Replacer; Invasions; Extra Mod" },
  { "name" => "catalog unknown", "mods" => "", "personal" => nil },
  { "name" => "catalog unknown but every script named", "mods" => "Level Cap; Invasions; Sub; Luka Replacer; Victory Screen; Zeta; alpha", "personal" => nil },
  { "name" => "catalog unknown with this world parked", "mods" => "", "personal" => nil, "parked" => ["Patch/Invasions.rb"], "parked_world" => "w1" },
  { "name" => "catalog unknown with another world parked", "mods" => "", "personal" => nil, "parked" => ["Patch/Invasions.rb"], "parked_world" => "w9" },
  { "name" => "unlisted", "mods" => "", "scripts" => nil },
  { "name" => "unlisted for a world that allows them", "mods" => "", "off" => false, "scripts" => nil },
  { "name" => "moved this session", "mods" => "", "moved" => true },
  { "name" => "behind a link", "mods" => "Level Cap", "elsewhere" => ["Patch/Invasions.rb", "Patch/Sub/Extra-Mod.rb"] },
  { "name" => "one behind a link", "mods" => "Level Cap", "elsewhere" => ["Patch/Sub/Extra-Mod.rb"] },
  { "name" => "a link the world names", "mods" => "Level Cap; Invasions; Sub; Luka Replacer; Zeta; alpha", "elsewhere" => ["Patch/Invasions.rb"] },
  { "name" => "parked already as planned", "mods" => "Level Cap; Luka Replacer; Zeta; alpha",
    "parked" => ["Patch/Invasions.rb", "Patch/Sub/Extra-Mod.rb"], "parked_world" => "w9" },
  { "name" => "parked otherwise", "mods" => "Level Cap", "parked" => ["Patch/Invasions.rb"], "parked_world" => "w1" },
  { "name" => "parked for a world that allows them", "mods" => "", "off" => false, "parked" => ["Patch/Invasions.rb"], "parked_world" => "w1" },
  { "name" => "every script the world names is personal", "mods" => "", "personal" => %w(invasions levelcap lukareplacer sub victoryscreen zeta alpha) },
  { "name" => "duplicate scripts", "mods" => "Level Cap", "scripts" => ["Patch/Invasions.rb", "patch\\invasions.rb", "Patch/Zeta.rb"] },
]

plans = PLANS.map do |entry|
  parking = MGQ_MpModParking
  parking.case_scripts = entry.key?("scripts") ? entry["scripts"] : SCRIPTS
  parking.case_elsewhere = entry.key?("scripts") && entry["scripts"].nil? ? nil : (entry["elsewhere"] || [])
  parked = entry["parked"] || []
  parking.case_state = parked.empty? ? {} : { "world" => entry["parked_world"], :paths => parked }
  parking.case_moved = entry["moved"] == true
  MGQ_MpWorldMods.personal = entry.key?("personal") ? entry["personal"] : %w(victoryscreen)
  listed = Listed.new("w1", entry["mods"], entry.key?("off") ? entry["off"] : true)
  change = parking.change_for(listed)
  {
    "name" => entry["name"], "scripts" => parking.scripts, "elsewhere" => parking.elsewhere, "mods" => listed.mods,
    "off" => listed.other_mods_off, "personal" => MGQ_MpWorldMods.personal, "parked" => parked, "parked_world" => entry["parked_world"],
    "moved" => parking.case_moved, "change" => change.is_a?(Symbol) ? change.to_s : change,
    "plan" => parking.plan_for(listed), "stuck" => parking.stuck_for(listed), "elsewhere_text" => parking.elsewhere_text(listed),
    "confirm_text" => change.is_a?(Array) ? parking.confirm_text("Strict", change) : nil, "also_text" => parking.also_text(change),
  }
end

owners = OWNERS.map do |path|
  { "path" => path, "name" => MGQ_MpModParking.owner_name(path), "key" => MGQ_MpModParking.owner_key(path),
    "path_key" => MGQ_MpModParking.path_key(path), "shared" => MGQ_MpModParking.shared?(path) }
end

GROUPS = [[], ["Patch/A.rb"], ["Patch/A.rb", "Patch/B.rb"], ["Patch/A.rb", "Patch/B.rb", "Patch/C.rb"],
          ["Patch/A.rb", "Patch/B/x.rb", "Patch/B/y.rb", "Patch/C.rb", "Patch/D.rb"], ["Patch/b/x.rb", "Patch/B.rb"]]
groups = GROUPS.map do |paths|
  { "paths" => paths, "mods" => MGQ_MpModParking.mods_of(paths), "list_text" => MGQ_MpModParking.list_text(paths),
    "names" => MGQ_MpModParking.names_of(paths) }
end

texts = { "return" => MGQ_MpModParking.confirm_text("Loose", []), "also_none" => MGQ_MpModParking.also_text([]) }

File.write(File.join(__dir__, "plans.json"), JSON.pretty_generate({ "owners" => owners, "plans" => plans, "groups" => groups, "texts" => texts }) + "\n")
