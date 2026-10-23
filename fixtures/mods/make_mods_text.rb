#----------------------------------------------------------------
#  make_mods_text.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Writes text.json: how world.rbx read a world's mods text (mods_of, required_mods, essential_mods)
# before the rule moved to ModsText in MGQOnline.Game, as golden cases both sides check.
#
#   ruby fixtures/mods/make_mods_text.rb <world.rbx of the version to record>

require "json"

source = File.read(ARGV[0] || File.expand_path("../../GameScript/Multiplayer/Scripts/world.rbx", __dir__), :encoding => "UTF-8")
recorded = Module.new
%w(mods_of required_mods essential_mods marked_mods).each do |name|
  method = source[/^  def self\.#{name}\(.*?\n  end\n/m] or raise "world.rbx has no #{name}"
  recorded.module_eval(method)
end

TEXTS = [
  nil, "", "A;B", "!A; ?B ;C", "C;!A;?B;!A;C;C", "!  spaced name", "!", "?", "  !  x  ;", "!?foo", "a\nb",
  "!a\nb", "Ünïcode;!Ünï", ";;", "\t!tab\t", "!x\0", "?Data Mod; !Script Mod.rb; Other"
]

cases = TEXTS.map do |text|
  { "text" => text, "names" => recorded.mods_of(text), "required" => recorded.required_mods(text), "essential" => recorded.essential_mods(text) }
end
File.write(File.join(__dir__, "text.json"), JSON.pretty_generate({ "cases" => cases }) + "\n")
