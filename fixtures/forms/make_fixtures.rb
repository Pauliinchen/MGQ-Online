#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Recorded the forms from form_prototype.rb
#                            - Created
#
#----------------------------------------------------------------

# Writes world.json: what the world screen's forms of world.rbx showed and answered, from
# form_prototype.rb (MGQ_MpWorld::Form before its schema moved to WorldForms in MGQOnline.Game), as
# golden cases the DLL's tests check and whose views the script tests answer the form topics with:
# each form opened, a few player actions, then the fields shown, the values, what the values add up
# to, the first problem, and the checks of text boxes.
#
#   ruby fixtures/forms/make_fixtures.rb

require "json"
require_relative "form_prototype"

RAID_WORLD = { "name" => "Raid", "seats" => 8, "mods" => "!Level Cap", "description" => "About", "settings" => "a=b", "difficulty" => nil, "type" => "raid",
               "other_mods_off" => true, "raid_bosses" => false, "squad" => { "luka" => true, "formation" => 6, "front" => 2, "raid_front" => 3 } }
CLASSIC_WORLD = { "name" => "Home", "seats" => 4, "mods" => "", "description" => "", "settings" => "", "difficulty" => 2, "type" => "classic",
                  "other_mods_off" => false, "raid_bosses" => true, "squad" => nil }

FORMS = [
  ["create as it opens", { "kind" => "create" }, []],
  ["create turned to a Raid World", { "kind" => "create" }, [["turn", "type", 1]]],
  ["create turned to a Raid World and back", { "kind" => "create" }, [["turn", "type", 1], ["turn", "type", -1]]],
  ["create keeps Turn off other mods once the player ticked it", { "kind" => "create" }, [["tick", "other_mods_off"], ["turn", "type", 1]]],
  ["create with Shared save ticked and no save", { "kind" => "create" }, [["set", "name", "Home"], ["tick", "from_save"]]],
  ["create with a save, a choice and raid bosses", { "kind" => "create" }, [["set", "name", " Home "], ["tick", "from_save"], ["set", "save", 2], ["tick", "choose"], ["tick", "raid_bosses"]]],
  ["create of a Raid World with its choices", { "kind" => "create" }, [["set", "name", "Raid"], ["turn", "type", 1], ["turn", "share", -1], ["turn", "difficulty", 2], ["tick", "choose"], ["tick", "raid_bosses"]]],
  ["create with seats out of range", { "kind" => "create" }, [["set", "name", "Home"], ["set", "seats", "40"]]],
  ["create with its formation limits", { "kind" => "create" }, [["turn", "type", 1], ["page", "limits"], ["tick", "luka"], ["turn", "formation", -1], ["turn", "front", 3], ["turn", "raid_front", 1]]],
  ["edit of a Raid World without a difficulty, by its creator", { "kind" => "edit", "world" => RAID_WORLD, "own" => true }, []],
  ["edit of a Raid World turned to its first difficulty", { "kind" => "edit", "world" => RAID_WORLD, "own" => false }, [["turn", "difficulty", 1]]],
  ["edit of a Classic world, by an admin", { "kind" => "edit", "world" => CLASSIC_WORLD, "own" => false }, []],
  ["edit of a Classic world with its seats emptied", { "kind" => "edit", "world" => CLASSIC_WORLD, "own" => true }, [["set", "seats", ""]]],
  ["rename without a name while Discord tells none", { "kind" => "rename", "name" => "" }, []],
  ["rename without a name while Discord tells one", { "kind" => "rename", "name" => "", "discord" => true }, []],
  ["password", { "kind" => "password", "name" => "Home" }, []],
  ["join", { "kind" => "join" }, []],
  ["join with an id", { "kind" => "join" }, [["set", "id", "0123456789ABCDEF0123456789abcdef"]]],
]

CHECKS = [
  [{ "kind" => "create" }, "seats", ["4", "2", "32", "1", "33", "04", "x", "", " 5", "５"]],
  [{ "kind" => "create" }, "name", ["Home", "  Home  ", "", "   ", "\tA\n"]],
  [{ "kind" => "create" }, "password", ["", " a b ", "pw"]],
  [{ "kind" => "create" }, "description", ["", "  text  "]],
  [{ "kind" => "join" }, "id", ["0123456789abcdef0123456789abcdef", " 0123456789ABCDEF0123456789ABCDEF ", "0123", "g123456789abcdef0123456789abcdef"]],
  [{ "kind" => "rename", "name" => "" }, "name", ["", " Me "]],
  [{ "kind" => "rename", "name" => "", "discord" => true }, "name", [""]],
]

forms = FORMS.map do |name, request, steps|
  { "case" => name, "open" => request, "steps" => steps, "view" => FormPrototype.view_of(FormPrototype.act(FormPrototype.open(request), steps)) }
end
checks = CHECKS.flat_map do |request, key, texts|
  form = FormPrototype.open(request)
  field = form.fields.find { |candidate| candidate.key.to_s == key }
  texts.map { |text| { "open" => request, "key" => key, "text" => text, "answer" => form.check(field, text) } }
end
File.write(File.join(__dir__, "world.json"), JSON.pretty_generate({ "forms" => forms, "checks" => checks }) + "\n")
