#----------------------------------------------------------------
#  make_settings.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Named the commit whose scripts it records
#                            - Wrote the texts C# words anew as C# words them
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Writes settings.json: how world_mods.rbx built, joined and merged a world's shared mod settings
# and wrote its notices (pairs_of, shared?, fit_settings, shared_text, with_marker, merged_text,
# changes_text, relay_change_text, creator_on_text, stay_text, options_text, mods_text, list_text,
# value_text, notice_lines, details_text) before they moved to SharedSettings in MGQOnline.Game, as
# golden cases both sides check. The options are those of OPTIONS, as Mod Config Remake would group
# them.
#
#   git show 75951eed:GameScript/Multiplayer/Scripts/world_mods.rbx > old_world_mods.rbx
#   ruby fixtures/mods/make_settings.rb old_world_mods.rbx

require "json"

SOURCE = File.read(ARGV[0] || abort("Name the world_mods.rbx of commit 75951eed, see the header."), :encoding => "UTF-8")

# Takes one part of the script's source.
#
# @param pattern [Regexp] The part.
# @return [String] Its source.
def part(pattern)
  SOURCE[pattern] or raise "world_mods.rbx lacks #{pattern.inspect}"
end

# The prefix of the mod's own options, which only ROW_NAME reads.
module MGQ_MpUi; OPTION_PREFIX = "[MGQ Online Settings] "; end

# The Mod Config groups of the cases: each group's name and its options' keys, rows and value names.
OPTIONS = [
  ["Level Cap", [[:mod_level_cap, "[Level Cap] Level Cap", { 1 => "On", 0 => "Off" }], [:mod_level_cap_limits, "  -> Job and Race Limits", {}]]],
  ["Party Sheet", [[:mod_party_sheet_theme, "[Party Sheet] Theme", { :dark => "Dark", :light => "Light" }], [:mod_party_sheet_size, "[Party Sheet] Size", { 2 => "Small" }],
                   [:mod_party_sheet_rate, "[Party Sheet] Rate", {}]]],
  ["Third", [[:mod_third_a, "[Third] A", {}]]],
  ["Fourth", [[:mod_fourth_a, "[Fourth] A", {}]]],
]

# Mod Config's tables, as far as the notices read them.
module NWConst
  module Config
    DATA_TEXT = {}
    OPTIONS.each { |_, entries| entries.each { |key, _, names| DATA_TEXT[key] = Hash[names.map { |value, name| [value, { :name => name }] }] } }
  end
end

# The script's settings and notices as world_mods.rbx had them.
module MGQ_MpWorldMods
  def self.log(_line); end
  def self.menu_groups; OPTIONS.map { |name, entries| [name, entries.map { |key, row, _| { :key => key, :name => row } }] }; end
  def self.option_pairs(_keys); $mine; end
  def self.menu_keys; $known; end
end
module MGQ_MpWorld; def self.mods_of(_text); []; end; def self.mod_key(name); name; end; end
module MGQ_Multiplayer; def self.clean(text); text.to_s; end; end
MGQ_MpWorldMods.module_eval(SOURCE.scan(/^  [A-Z_]+ = .*\n/).join)
%w(name_of short_name pairs_of shared? fit_settings shared_text with_marker merged_text encode type_of decode settings_from same_value? known_keys options_text mods_text
   list_text changes_text value_text notice_lines details_text relay_change_text creator_on_text stay_text).each do |name|
  MGQ_MpWorldMods.module_eval(part(/^  def self\.#{Regexp.escape(name)}(\(|\n).*?\n  end\n/m))
end
M = MGQ_MpWorldMods

# Writes a list of option keys as JSON, as the scripts name them.
def keys(list); list.map { |key| key.to_s }; end

pairs = [nil, "", "a=i:1;b=s:x;;=i:2;c", "@shared=o:1;a=i:1;", "x=s:a=b"].map { |text| { "text" => text, "pairs" => M.pairs_of(text).map { |key, pair| [key.to_s, pair] } } }
shared = [nil, "", " ", "\t\n", "@shared=o:1", "a"].map { |text| { "text" => text, "shared" => M.shared?(text) } }

M.send(:remove_const, :MAX_SETTINGS_CHARS)
M.const_set(:MAX_SETTINGS_CHARS, 30)
fits = [
  [["a", "a=s:#{'x' * 20}"], ["b", "b=s:#{'y' * 20}"], ["c", "c=i:1"]],
  [["é", "é=s:#{'é' * 20}"], ["b", "b=i:2"]],
  [],
].map do |list|
  text, left = M.fit_settings(list.map { |key, pair| [key.to_sym, pair] })
  { "pairs" => list, "most" => 30, "text" => text, "left_out" => keys(left) }
end
M.send(:remove_const, :MAX_SETTINGS_CHARS)
M.const_set(:MAX_SETTINGS_CHARS, 64_000)

built = [
  [[["mod_level_cap", "mod_level_cap=i:0"], ["mod_party_sheet_theme", "mod_party_sheet_theme=y:dark"]], %w(mod_level_cap mod_party_sheet_theme mod_party_sheet_size), ""],
  [[["mod_level_cap", "mod_level_cap=i:0"]], %w(mod_level_cap mod_party_sheet_theme), "@shared=o:1;mod_other=i:3;mod_level_cap=i:1;mod_party_sheet_theme=y:light"],
  [[], [], nil],
].map do |mine, known, base|
  $mine = mine.map { |key, pair| [key.to_sym, pair] }
  $known = known.map { |key| key.to_sym }
  text, left = M.shared_text("", base)
  { "mine" => mine, "known" => known, "base" => base, "text" => text, "left_out" => keys(left) }
end

marked = ["", nil, "mod_level_cap=i:0", "@shared=o:1;a=i:1"].map { |text| { "text" => text, "marked" => M.with_marker(text) } }

merged = [
  ["@shared=o:1;mod_level_cap=i:1", "@shared=o:1;mod_level_cap=i:0", "@shared=o:1;mod_level_cap=i:1;mod_party_sheet_theme=y:light", :options],
  ["@shared=o:1;a=i:1;b=i:1", "@shared=o:1;a=i:2;b=i:1;c=i:5", "@shared=o:1;b=i:3;d=i:4", :load],
  ["@shared=o:1", "", "@shared=o:1;a=i:1", :switch],
  ["@shared=o:1", "", "@shared=o:1;a=i:1", :options],
  ["", "@shared=o:1;a=i:1", "", :switch],
  ["", "@shared=o:1;a=i:1", "", :load],
].map { |base, mine, theirs, reason| { "base" => base, "mine" => mine, "theirs" => theirs, "reason" => reason.to_s, "merged" => M.merged_text(base, mine, theirs, reason) } }

changes = [
  ["mod_level_cap=i:1", "mod_level_cap=i:0"],
  ["mod_level_cap=i:1;mod_party_sheet_theme=y:dark;mod_party_sheet_size=i:2", "mod_level_cap=i:0;mod_party_sheet_theme=y:light;mod_party_sheet_size=i:4"],
  ["mod_party_sheet_rate=f:1.0", "mod_party_sheet_rate=f:1.0000001"],
  ["mod_party_sheet_rate=f:1.0", "mod_party_sheet_rate=f:2.005"],
  ["mod_party_sheet_rate=f:1.5", "mod_party_sheet_rate=i:1"],
  ["mod_level_cap=i:1", ""],
  ["", "mod_party_sheet_theme=y:dark"],
  ["mod_missing=i:1", "mod_missing=i:2"],
  ["mod_missing=i:1;mod_level_cap=i:1", "mod_missing=i:2;mod_level_cap=i:1"],
  ["a=i:1", "a=i:1"],
  ["mod_third_a=s:x%3By", "mod_third_a=s:x%3Dy;mod_level_cap=i:007"],
  ["mod_third_a=b:true", "mod_third_a=b:false;mod_fourth_a=y:"],
].map { |before, after| { "before" => before, "after" => after, "changes" => M.changes_text(M.settings_from(before), M.settings_from(after)) } }

relay = [
  ["@shared=o:1;mod_level_cap=i:1", ""], ["", "@shared=o:1;mod_level_cap=i:1;mod_party_sheet_theme=y:dark"], ["", "@shared=o:1;mod_missing=i:1"],
  ["@shared=o:1;mod_level_cap=i:1", "@shared=o:1;mod_level_cap=i:0"], ["@shared=o:1;mod_missing=i:1", "@shared=o:1;mod_missing=i:2"], ["@shared=o:1", "@shared=o:1"],
].map { |before, after| { "before" => before, "after" => after, "text" => M.relay_change_text(before, after) } }

key_lists = [[], %w(mod_level_cap), %w(mod_level_cap mod_party_sheet_theme), %w(mod_level_cap mod_party_sheet_theme mod_third_a), %w(mod_level_cap mod_party_sheet_theme mod_third_a mod_fourth_a), %w(mod_missing mod_level_cap_limits)]
lists = key_lists.map do |list|
  symbols = list.map { |key| key.to_sym }
  { "keys" => list, "known" => keys(M.known_keys(symbols)), "mods" => M.mods_text(symbols), "options" => list.empty? ? nil : M.options_text(M.known_keys(symbols)),
    "stay" => M.stay_text(M.known_keys(symbols), "Creator"), "creator_on" => M.creator_on_text(M.known_keys(symbols)) }
end
names = [[%w(A), 2], [%w(A B), 2], [%w(A B C), 2], [%w(A B C), 3], [%w(A B C D), 3], [%w(A B), 1]].map { |list, named| { "names" => list, "named" => named, "text" => M.list_text(list, named) } }

notices = [
  "Short.",
  "Party Sheet shares mod settings here: 2 options of Level Cap and Party Sheet are set for you. Your own saves keep yours.",
  "One #{'x' * 60} word longer than a line, then more words to fill the box past its lines, past three lines of forty-six characters each, with more words still to come.",
  "  Spaces   between\twords  ",
].map { |text| { "text" => text, "lines" => M.notice_lines(text) } }

# A listed world as far as details_text reads it.
Listed = Struct.new(:settings, :creator_id, :creator_name)
details = [
  ["@shared=o:1;mod_party_sheet_theme=y:dark;mod_missing=i:1", "creator"], ["@shared=o:1", "me"], ["@shared=o:1;mod_missing=i:1", "creator"],
  ["@shared=o:1;mod_missing=i:1;mod_missing_b=i:1", "creator"], ["", "creator"], ["mod_level_cap=i:0", "creator"],
].map { |settings, creator| { "settings" => settings, "creator_id" => creator, "text" => M.details_text(Listed.new(settings, creator, "Creator"), "me") } }

options = OPTIONS.map { |name, entries| [name, entries.map { |key, row, values| [key.to_s, M.short_name(:name => row), values.map { |value, text| [M.encode(value), text] }] }] }
text = JSON.pretty_generate({
  "options" => options, "pairs" => pairs, "shared" => shared, "fits" => fits, "built" => built, "marked" => marked, "merged" => merged, "changes" => changes,
  "relay" => relay, "lists" => lists, "names" => names, "notices" => notices, "details" => details,
}) + "\n"

# The texts C# words anew, each the script's text and the one SettingNotices writes.
REWORDED = {
  "Shared Mod Settings were turned off on the relay:" => "An admin turned Shared Mod Settings off:",
  "Shared Mod Settings were turned on on the relay:" => "An admin turned Shared Mod Settings on:",
  "The shared mod settings were changed on the relay:" => "An admin changed the shared mod settings:",
}
File.write(File.join(__dir__, "settings.json"), REWORDED.inject(text) { |cases, (old, now)| cases.gsub(old, now) })
