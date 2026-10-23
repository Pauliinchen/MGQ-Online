#----------------------------------------------------------------
#  make_mod_check.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Writes check.json: how world_mods.rbx checked a world's required mods against the relay's catalog,
# this game's copies and the creator's hashes (differing, summary, log_check, creator_hashes,
# fit_hashes, installed_version, served_mods) before the check moved to ModCheck in MGQOnline.Game,
# as golden cases both sides check.
#
#   ruby fixtures/mods/make_mod_check.rb <world_mods.rbx of the version to record>

require "json"

SOURCE = File.read(ARGV[0] || File.expand_path("../../GameScript/Multiplayer/Scripts/world_mods.rbx", __dir__), :encoding => "UTF-8")

# Takes one part of the script's source.
#
# @param pattern [Regexp] The part.
# @return [String] Its source.
def part(pattern)
  SOURCE[pattern] or raise "world_mods.rbx lacks #{pattern.inspect}"
end

# The mod's base script, as far as the check reaches it: the catalog topic and the hashes of the
# files of the case being recorded.
module MGQ_Multiplayer
  # Hands out the catalog of the case.
  module Bridge; def self.call(_topic, _request = nil); $catalog; end; end
  # Hashes the files of the case, as mp_mod_hash does.
  module Link
    # A DLL function that writes a file's hash.
    Function = Struct.new(:name) do
      # Writes the hash of the file named first into the buffer.
      #
      # @param args [Array] Path, buffer and size.
      # @return [Integer] The hash's length, 0 for none.
      def call(*args)
        hash = $files[args[0].chomp("\0")]
        return 0 unless hash

        args[1][0, hash.size] = hash
        hash.size
      end
    end
    # Finds a function.
    def self.function(name); Function.new(name); end
  end
end

# The worlds' script, as far as the check reaches it, with the scripts in Patch of the case.
module MGQ_MpWorld
  PATCH_DIR = "Patch"
  # The marks as world.rbx read them before ModsText.
  def self.marked(text, mark); text.to_s.split(";").map { |mod| mod.strip[/\A#{mark}\s*(\S.*)\z/, 1] }.compact; end
  def self.required_mods(text); marked(text, /!/); end
  def self.essential_mods(text); marked(text, /\?/); end
  def self.mods_of(text)
    names = text.to_s.split(";").map { |mod| mod.strip.sub(/\A[!?]\s*/, "") }.reject { |mod| mod.empty? }
    (names & required_mods(text)) + (names & essential_mods(text)) + (names - required_mods(text) - essential_mods(text))
  end
  def self.mod_key(name); name.to_s.downcase.sub(/\.rb\z/, "").delete(" \t\n\v\f\r_-"); end
  def self.installed_mod?(name); $installed.nil? || $installed.any? { |key, _| key == mod_key(name) }; end
  def self.installed_path(name); found = ($installed || []).find { |key, _| key == mod_key(name) }; found && found[1]; end
  def self.forget_installed; end
end

# The check as world_mods.rbx had it.
module MGQ_MpWorldMods
  def self.log(line); ($logged ||= []) << line; nil; end
  def self.log_once(_key, line); log(line); end
end
MGQ_MpWorldMods.module_eval(%w(CATALOG_TOPIC CATALOG_SECONDS HASH_SIZE ZIP_KINDS MAX_HASH_NAME_CHARS MAX_HASHES_CHARS).map { |name| part(/^  #{name} = .*\n/) }.join)
MGQ_MpWorldMods.module_eval(part(/^  Mod = Struct.new.*\n/) + part(/^  Row = Struct.new.*?\n  end\n/m))
%w(catalog log_catalog mod_of personal_keys mod_named hash_of forget_installed differing row_for link_row zip_row version_of hashes_of log_check creator_hashes fit_hashes summary installed_version served_mods).each do |name|
  MGQ_MpWorldMods.module_eval(part(/^  def self\.#{name}\b.*?\n  end\n/m))
end
MGQ_MpWorldMods.instance_variable_set(:@hashes, {})

E = "e" * 64
F = "f" * 64
CATALOG = {
  "state" => "ready", "error" => nil, "personal" => ["personalmod", "skins"],
  "mods" => [
    { "key" => "levelcap", "name" => "Level Cap", "kind" => "link", "version" => "1.4.0", "files" => { "Level_Cap.rb" => "bb" },
      "versions" => [["1.4.0", { "Level_Cap.rb" => "bb" }], ["1.3.5", { "Level_Cap.rb" => "aa" }]], "options_version" => "1.3.5" },
    { "key" => "pack", "name" => "Pack", "kind" => "upload", "version" => "2", "files" => { "Pack/a.luka" => "p1", "Pack/b.luka" => "p2" },
      "versions" => [["2", { "Pack/a.luka" => "p1", "Pack/b.luka" => "p2" }]], "options_version" => nil },
    { "key" => "hero", "name" => "Hero", "kind" => "zip", "version" => "1.1", "files" => { "Hero.rb" => "h2", "Hero/a.luka" => "h3" },
      "versions" => [["1.1", { "Hero.rb" => "h2", "Hero/a.luka" => "h3" }], ["1.0", { "Hero.rb" => "h1", "Hero/a.luka" => "h3" }]], "options_version" => "1.1" },
  ],
}
LEVEL_CAP = ["levelcap", "Patch/Mods/Level Cap.rb"]
OTHER = ["othermod", "Patch/Other_Mod.rb"]
LONG = "M" * 101

# Each case: the world's mods and creator's hashes, the catalog known or not, the scripts in Patch
# (nil when Patch cannot be read) and the files' hashes.
CASES = [
  ["!Level Cap", "", true, [LEVEL_CAP], { LEVEL_CAP[1] => "bb" }],
  ["!Level Cap", "", true, [LEVEL_CAP], { LEVEL_CAP[1] => "aa" }],
  ["!Level Cap", "", true, [LEVEL_CAP], { LEVEL_CAP[1] => "cc" }],
  ["!Level Cap", "", true, [], {}],
  ["!Pack", "", true, [], { "Patch/Pack/a.luka" => "p1", "Patch/Pack/b.luka" => "p2" }],
  ["!Pack", "", true, [], { "Patch/Pack/a.luka" => "p1" }],
  ["!Pack", "", true, [], {}],
  ["!Hero", "", true, [], { "Patch/Hero.rb" => "h2", "Patch/Hero/a.luka" => "h3" }],
  ["!Hero", "", true, [], { "Patch/Hero.rb" => "h1", "Patch/Hero/a.luka" => "h3" }],
  ["!Other Mod; !Missing Mod", "Other Mod=#{E}", true, [OTHER], { OTHER[1] => E }],
  ["!Other Mod; !Missing Mod", "Other Mod=#{E}", true, [OTHER], { OTHER[1] => F }],
  ["!Other Mod; !Missing Mod", "", true, [OTHER], { OTHER[1] => F }],
  ["!Other Mod", "other_mod=#{E};broken;=x;Missing=", true, [OTHER], { OTHER[1] => E }],
  ["!Level Cap; !Missing Mod", "", false, [LEVEL_CAP], { LEVEL_CAP[1] => "aa" }],
  ["!Level Cap; !Missing Mod", "", true, nil, { LEVEL_CAP[1] => "aa" }],
  ["?Data; Free; !Level Cap; !Hero", "", true, [LEVEL_CAP], { LEVEL_CAP[1] => "aa", "Patch/Hero.rb" => "h1", "Patch/Hero/a.luka" => "h3" }],
  ["Free Mod", "", true, [], {}],
]

# Sets up a case's game.
def set_up(known, installed, files)
  $catalog = known ? CATALOG : { "state" => "failed", "error" => "down", "mods" => [], "personal" => [] }
  $installed = installed
  $files = files
  MGQ_MpWorldMods.instance_variable_set(:@catalog_read, nil)
  MGQ_MpWorldMods.instance_variable_set(:@catalog_told, :none)
  MGQ_MpWorldMods.instance_variable_set(:@hashes, {})
end

Listed = Struct.new(:mods, :mod_hashes)

checks = CASES.map do |mods, hashes, known, installed, files|
  set_up(known, installed, files)
  listed = Listed.new(mods, hashes)
  rows = MGQ_MpWorldMods.differing(listed)
  $logged = []
  MGQ_MpWorldMods.log_check("Modded", listed, rows)
  versions = (MGQ_MpWorldMods.catalog || []).map { |mod| [mod.key, MGQ_MpWorldMods.installed_version(mod)] }
  MGQ_MpWorldMods.instance_variable_set(:@world, { :mods => mods })
  {
    "mods" => mods, "hashes" => hashes, "catalog" => known, "installed" => installed, "files" => files,
    "rows" => rows.map { |row| { "name" => row.name, "yours" => row.yours, "worlds" => row.worlds, "key" => row.mod && row.mod.key, "target" => row.target, "text" => row.text } },
    "summary" => rows.empty? ? nil : MGQ_MpWorldMods.summary("Modded", rows),
    "log" => $logged.last,
    "installed_versions" => versions,
    "served" => MGQ_MpWorldMods.served_mods.map { |key, kind, version, pairs| [key, kind, version, pairs] },
  }
end

HASHED = [OTHER, LEVEL_CAP, ["mmmm", "Patch/#{LONG}.rb"], ["ab", "Patch/a=b.rb"]]
creator = [
  ["!Level Cap; !Other Mod; Free Mod; !Missing Mod", true, HASHED, { OTHER[1] => F, LEVEL_CAP[1] => "aa" }],
  ["!Other Mod; !#{LONG}; !a=b", true, HASHED, { OTHER[1] => F, "Patch/#{LONG}.rb" => F, "Patch/a=b.rb" => F }],
  ["!Level Cap; !Other Mod", false, HASHED, { OTHER[1] => F, LEVEL_CAP[1] => "aa" }],
  ["!Other Mod", true, HASHED, {}],
].map do |mods, known, installed, files|
  set_up(known, installed, files)
  { "mods" => mods, "catalog" => known, "installed" => installed, "files" => files, "hashes" => MGQ_MpWorldMods.creator_hashes(mods) }
end

fits = [[["A=#{'1' * 64}", "B=#{'2' * 64}", "C=3"], 70], [["É=#{'1' * 64}", "B=2"], 68], [[], 10]].map do |pairs, most|
  { "pairs" => pairs, "most" => most, "fitted" => MGQ_MpWorldMods.fit_hashes(pairs, most) }
end

File.write(File.join(__dir__, "check.json"), JSON.pretty_generate({ "catalog" => CATALOG, "checks" => checks, "creator" => creator, "fits" => fits }) + "\n")
