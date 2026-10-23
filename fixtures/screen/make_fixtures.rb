#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Writes screen.json: what world_screen.rbx showed of a world before the world screen's model moved
# to WorldScreenModel in MGQOnline.Game (screen_prototype.rb keeps those methods), for worlds and
# facts that reach every branch: a row of the list, the details' panels, the choices of a world and
# the list box's players and mods; and the screen's texts with the mod picker's labels and colours.
#
#   ruby fixtures/screen/make_fixtures.rb

require "json"
require_relative "screen_cases"

# Makes a world of the list.
#
# @param values [Hash] What differs from a plain Classic world.
# @return [Hash] The world.
def listed(values)
  defaults = { "id" => "w1", "seats" => 4, "online" => 0, "creator_id" => "c", "active" => 0, "creator_name" => "Creator", "name" => "World", "start" => "none", "members" => [], "hidden" => false,
               "choose" => false, "open" => false, "featured" => false, "strict" => false, "data" => "", "mods" => "", "description" => "", "mod_hashes" => "", "settings" => "", "type" => "classic",
               "share" => "off", "difficulty" => nil, "other_mods_off" => false, "squad" => nil, "raid_bosses" => false, "mods_unread" => false }
  defaults.merge(values)
end

# Players of a world: id, online, name.
MEMBERS = [["me", true, "Me"], ["a", true, "Alma"], ["b", false, "Bea"], ["c", false, "Creator"], ["d", true, "Dora"]]

# The worlds recorded.
CASES = [
  { "name" => "classic featured open world with marked mods", "me" => "me", "admin" => false, "favourite" => true, "gone" => false,
    "listed" => listed("featured" => true, "open" => true, "online" => 2, "members" => MEMBERS.first(3), "mods" => "Plain; !Req; ?Ess", "data" => "1:ab"),
    "local" => { "id" => "f1", "played" => "2026-10-01", "latest_save" => true },
    "facts" => { "differing" => [], "installed" => ["Req"], "rows" => [{ "name" => "Req", "yours" => "1.0", "text" => "Req: 1.0 here, 1.1 in the world" }], "shared" => true,
                 "settings_text" => "Mod settings: the creator's, shared with every player" } },
  { "name" => "hidden raid world of the player's own, mods not read yet", "me" => "c", "admin" => false, "favourite" => false, "gone" => false,
    "listed" => listed("hidden" => true, "type" => "raid", "share" => "story", "difficulty" => 2, "squad" => { "luka" => true, "formation" => 6, "front" => 2, "raid_front" => 1 }, "start" => "ready",
                       "choose" => true, "strict" => true, "members" => MEMBERS.first(4), "mods_unread" => true, "data" => "1:cd", "online" => 1),
    "local" => nil, "facts" => { "differing" => ["skills", "maps"], "differing_text" => "skills and maps" } },
  { "name" => "raid world still being set up that turns other mods off", "me" => "me", "admin" => true, "favourite" => false, "gone" => false,
    "listed" => listed("type" => "raid", "share" => "all", "start" => "pending", "other_mods_off" => true, "members" => MEMBERS, "mods" => "!Missing", "online" => 3, "seats" => 8),
    "local" => { "id" => "f3", "played" => nil, "latest_save" => false },
    "facts" => { "differing" => nil, "rows" => [{ "name" => "Missing", "yours" => "not installed", "text" => "Missing: not installed" }], "turned_off" => [["Invasions", 1], ["Big Mod", 3]] } },
  { "name" => "classic world of the player's own with raid bosses, not compared", "me" => "c", "admin" => false, "favourite" => false, "gone" => false,
    "listed" => listed("raid_bosses" => true, "choose" => true, "start" => "ready", "members" => [["c", true, "Creator"]], "online" => 1),
    "local" => { "id" => "f4", "played" => "2026-09-30", "latest_save" => true }, "facts" => { "differing" => nil } },
  { "name" => "classic world of the player's own whose data differs, same data only", "me" => "c", "admin" => true, "favourite" => false, "gone" => false,
    "listed" => listed("choose" => true, "strict" => true, "members" => [["c", false, "Creator"], ["a", false, "Alma"]], "mods" => "?Data Pack", "other_mods_off" => true),
    "local" => nil, "facts" => { "differing" => ["items"], "differing_text" => "items", "turned_off" => nil } },
  { "name" => "raid world that starts at the beginning on the easiest difficulty", "me" => "me", "admin" => false, "favourite" => true, "gone" => false,
    "listed" => listed("type" => "raid", "difficulty" => -2, "members" => [], "description" => "A long night."),
    "local" => nil, "facts" => { "differing" => ["skills"], "differing_text" => "skills", "added" => ["w1"] } },
  { "name" => "world only on this PC, gone from the directory", "me" => "me", "admin" => false, "favourite" => false, "gone" => true,
    "listed" => nil, "local" => { "id" => "f7", "played" => "2026-08-01", "latest_save" => true, "raid" => true }, "facts" => {} },
  { "name" => "world on this PC while the list has not arrived", "me" => "me", "admin" => false, "favourite" => true, "gone" => false,
    "listed" => nil, "local" => { "id" => "f8", "played" => nil, "latest_save" => false, "raid" => false }, "facts" => {} },
  { "name" => "hidden world added by its id, never entered", "me" => "me", "admin" => false, "favourite" => false, "gone" => false,
    "listed" => listed("hidden" => true, "members" => [["c", true, "Creator"]], "online" => 1, "seats" => 2, "mods" => "A; B; C"),
    "local" => nil, "facts" => { "added" => ["w1"], "differing" => [] } },
]

# The cases with what the prototype showed of each.
recorded = CASES.map { |entry| entry.merge("facts" => ScreenPrototype::Cases::FACTS.merge(entry["facts"])).merge(ScreenPrototype::Cases.run(entry)) }
# The screen's texts.
states = ScreenPrototype::MOD_STATE_LABELS.keys.map { |state| [state.to_s, ScreenPrototype::MOD_STATE_LABELS[state], ScreenPrototype::MOD_STATE_COLORS[state].to_s] }
texts = { "hint" => ScreenPrototype::HINT, "enter_hint" => ScreenPrototype::ENTER_HINT, "busy" => ScreenPrototype::BUSY_TEXTS, "mod_states" => states }
File.write(File.join(__dir__, "screen.json"), JSON.pretty_generate({ "texts" => texts, "cases" => recorded }) + "\n")
