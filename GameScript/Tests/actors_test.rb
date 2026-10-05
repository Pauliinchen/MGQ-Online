#----------------------------------------------------------------
#  actors_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-05: Created
#
#----------------------------------------------------------------

# Covers how core_actors.rbx writes and reads a character's build: the hero of Luka Replacer only
# for a replaced Luka, and lines of 0.4.1 without it read as before.

require_relative "support"

$log = []
module MGQ_Multiplayer; module Log; def self.write(m); $log << m; end; end; end
class Game_Actor; end
Named = Struct.new(:name)
$data_actors = [nil, Named.new("Luka"), Named.new("Alice")]
$data_classes = [nil] + Array.new(200) { Named.new("Class") }
$data_skills = [nil] + Array.new(100) { Named.new("Skill") }
$data_items = [nil]

load_script "core_actors"
builds = MGQ_MpActors::Builds

# A member line of 0.4.1: its fourteen fields.
OLD = "member=1;5;92;151;92:1,151:1;0,0,0,0,0,0,0,0;10,11;;;;100,10,20,20,20,20,20,20;950,50,40,0,0,0,0;;"

check("a line of 0.4.1 reads, with no hero", [builds.parse(OLD, 4).size, builds.parse(OLD, 4)[0].hero], [1, ""])
check("a line with a hero reads it", builds.parse(OLD + ";kazuya", 4)[0].hero, "kazuya")
check("a hero that is no key is left out", builds.parse(OLD + ";../x", 4)[0].hero, "")
check("a line with a field too many is unreadable", builds.parse(OLD + ";kazuya;more", 4), [])

# The hero a character shows, as Luka Replacer names it.
module MGQ_LukaReplacer; def self.hero_key(actor); actor == :luka ? "kazuya" : ""; end; end
check("Luka Replacer names the replaced Luka's hero", [builds.hero_of(:luka), builds.hero_of(:alice)], ["kazuya", ""])
