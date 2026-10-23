#----------------------------------------------------------------
#  rules_support.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Answered the mod catalog a test sets
#                            - Added the answers to the world room's stand-in bridge when a test has one
#                            - Answered the story parts
#                            - Answered the world rules, squad rules and world codes
#                            - Answered the mod keys and the scripts in Patch
#                            - Created
#
#----------------------------------------------------------------

# The topics of the game's rules that left the scripts, answered by FakeBridge from the golden cases
# under fixtures, which the C# owners pass too: by looking a case up, or by a small stand-in that is
# checked against every case as this file loads, so the stand-ins cannot drift from what C# answers.

require "json"
require_relative "bridge_support"

# Folder of the golden cases.
RULE_FIXTURES = File.expand_path("../../fixtures", __dir__)

# Reads a golden case file.
#
# @param area [String] Its folder under fixtures, such as "catchup".
# @param name [String] The file, such as "exp.json".
# @return [Hash] Its content.
def rule_cases(area, name)
  JSON.parse(File.read(File.join(RULE_FIXTURES, area, name), :encoding => "UTF-8"))
end

# Answers the catch-up experience's topics from fixtures/catchup/exp.json.
#
# @param fake [FakeBridge] The bridge.
def answer_catchup(fake)
  cases = rule_cases("catchup", "exp.json")
  fake.answer("catchup.target") do |caps|
    found = cases["targets"].find { |entry| entry["caps"] == caps } or raise "no golden target for caps #{caps.inspect}"
    found["target"]
  end
  fake.answer("catchup.factor") do |request|
    grow_case(cases, request)["factor"]
  end
  fake.answer("catchup.grow") do |request|
    found = grow_case(cases, request)
    found["grown"] == [request["exp"], request["cexp"]] ? nil : { "exp" => found["grown"][0], "cexp" => found["grown"][1], "factor" => found["factor"] }
  end
end

# Finds the golden case of a target and level, with the experience the request names, if any.
#
# @param cases [Hash] The catch-up cases.
# @param request [Hash] The request.
# @return [Hash] The case.
def grow_case(cases, request)
  keys = request.key?("exp") ? %w(target level exp cexp) : %w(target level)
  cases["grow"].find { |entry| keys.all? { |key| entry[key] == request[key] } } or raise "no golden case for #{request.inspect}"
end

# Makes a mod key from the golden keys of fixtures/mods/keys.json; a plain ASCII name they lack gets
# the same key the ASCII ones show (lower case, no ".rb", no white space, underscores or hyphens),
# checked against them as the support loads.
#
# @param name [String] The name.
# @return [String] The key.
def golden_mod_key(name)
  return GOLDEN_KEYS[name] if GOLDEN_KEYS.key?(name)
  raise "no golden key for #{name.inspect}" unless name.ascii_only?

  ascii_mod_key(name)
end

# Makes the key of a plain ASCII name as the golden keys show it.
#
# @param name [String] The name.
# @return [String] The key.
def ascii_mod_key(name)
  name.downcase.sub(/\.rb\z/, "").delete(" \t\n\v\f\r_-")
end

# The golden keys by name.
GOLDEN_KEYS = rule_cases("mods", "keys.json")["keys"].each_with_object({}) { |entry, keys| keys[entry["name"]] = entry["key"] }

GOLDEN_KEYS.each do |name, key|
  raise "the ASCII stand-in makes #{ascii_mod_key(name).inspect} of #{name.inspect}, the relay #{key.inspect}" if name.ascii_only? && ascii_mod_key(name) != key
end

# Answers the mod key topic from the golden keys.
#
# @param fake [FakeBridge] The bridge.
def answer_mod_keys(fake)
  fake.answer("mods.keys") { |names| names.map { |name| golden_mod_key(name) } }
end

# Answers the scripts in Patch as the DLL lists them, from the Patch folder below the current
# folder: every .rb file but hidden ones and those of this mod's folder, sorted whatever their case.
#
# @param fake [FakeBridge] The bridge.
def answer_installed(fake)
  fake.answer("mods.installed") do
    paths = Dir.glob("Patch/**/*.rb").reject { |path| path.downcase.start_with?("patch/multiplayer/") }.sort_by { |path| path.downcase }
    paths.map { |path| [golden_mod_key(File.basename(path)), path, File.basename(path).sub(/\.rb\z/i, "")] }
  end
end

# The golden answers of a world's rules.
WORLD_RULES = rule_cases("world", "rules.json")

# The golden parts of stories.
STORY_PARTS = rule_cases("story", "parts.json")["parts"]

# Reads squad rules from their text as the golden cases show it: four whole numbers separated by
# single spaces, each in its range.
#
# @param text [String] The text.
# @return [Hash, nil] The rules by their names in the DLL's answers, nil for none.
def stand_in_squad(text)
  parts = text.split(" ", -1)
  return nil unless parts.size == 4 && parts.all? { |part| part =~ /\A\d+\z/ }

  luka, formation, front, raid_front = parts.map { |part| part.to_i }
  rules = WORLD_RULES["rules"]
  return nil unless luka <= 1 && rules["formations"].any? { |size, _| size == formation } && [front, raid_front].all? { |place| rules["fronts"].include?(place) }

  { "luka" => luka == 1, "formation" => formation, "front" => front, "raid_front" => raid_front }
end

# Writes squad rules as their text, nil for rules out of range.
#
# @param squad [Hash] The rules by their names in the DLL's answers.
# @return [String, nil] The text.
def stand_in_squad_text(squad)
  text = [squad["luka"] ? 1 : 0, squad["formation"], squad["front"], squad["raid_front"]].join(" ")
  stand_in_squad(text) ? text : nil
end

# Reads a world code as the golden cases show it: "mgqmp2", a token of 16 letters and digits, a
# relay id and the seats in their range, the code written anew with the seats asked for.
#
# @param request [Hash] The code and the seats asked for, if any.
# @return [Hash, nil] The code and its seats, nil for a text that is no world code.
def stand_in_code(request)
  fields = request["code"].strip.split(";", -1)
  seats = WORLD_RULES["rules"]["seats"]
  return nil unless fields.size == 4 && fields[0] == "mgqmp2" && fields[1] =~ /\A[abcdefghjkmnpqrstuvwxyz23456789]{16}\z/ && fields[2] =~ /\A[a-z0-9]{1,8}\z/ && fields[3] =~ /\A\d{1,2}\z/
  return nil unless fields[3].to_i.between?(seats["min"], seats["max"])

  wanted = request["seats"]
  fields[3] = wanted.to_s if wanted && wanted.between?(seats["min"], seats["max"])
  { "code" => fields.join(";"), "seats" => fields[3].to_i }
end

# Finds the part a story is in as the golden cases show it.
#
# @param request [Hash] Variable 1001 and the routes' variables.
# @return [String] The part.
def stand_in_part(request)
  route = %w(ad mr chaos).zip(request["routes"]).find { |_, value| value.to_i > 0 }
  return route[0] if route

  request["p"] < 19 ? "1" : request["p"] < 34 ? "2" : "3"
end

WORLD_RULES["squads"].each do |entry|
  raise "the squad stand-in reads #{entry['text'].inspect} as #{stand_in_squad(entry['text']).inspect}, the DLL #{entry['squad'].inspect}" if stand_in_squad(entry["text"]) != entry["squad"]
  raise "the squad stand-in writes #{entry['squad'].inspect} otherwise than the DLL" if entry["squad"] && stand_in_squad_text(entry["squad"]) != entry["text"]
end
WORLD_RULES["codes"].each do |entry|
  raise "the code stand-in reads #{entry['code'].inspect} otherwise than the DLL" if stand_in_code(entry) != entry["answer"]
end
STORY_PARTS.each do |entry|
  request = { "p" => entry["p"], "routes" => [entry["r1141"], entry["r1142"], entry["r1143"]] }
  raise "the part stand-in finds #{stand_in_part(request)} for #{request.inspect}, the relay #{entry['part']}" if stand_in_part(request) != entry["part"]
end

# Answers the topics of a world's rules as fixtures/world/rules.json shows them.
#
# @param fake [FakeBridge] The bridge.
def answer_world_rules(fake)
  fake.answer("world.rules") { WORLD_RULES["rules"] }
  fake.answer("squad.read") { |text| stand_in_squad(text) }
  fake.answer("squad.write") { |squad| stand_in_squad_text(squad) }
  fake.answer("world.code") { |request| stand_in_code(request) }
end

# Answers the story part topic as fixtures/story/parts.json shows it.
#
# @param fake [FakeBridge] The bridge.
def answer_story_parts(fake)
  fake.answer("story.part") { |request| stand_in_part(request) }
end

# The mod catalog the mods.catalog topic answers, which a test sets with catalog_told; nil answers
# nothing, as when the DLL fails.
$catalog = nil

# Sets the mod catalog the DLL hands out, written as lines for short: "mod", key, name, kind,
# version, then each current file and its hash; "old", key, version and its files; "opts", key and
# the version whose options the relay keeps; "personal", key and name; each separated by tabs.
#
# @param state [String] How the DLL's list stands: "ready", "loading", "failed" or "idle".
# @param lines [Array<String>] The catalog's lines.
def catalog_told(state, *lines)
  mods = []
  personal = []
  lines.each do |line|
    fields = line.split("\t", -1)
    files = {}
    case fields[0]
    when "mod"
      fields[5..-1].each_slice(2) { |name, hash| files[name] = hash if name && hash }
      mods << { "key" => fields[1], "name" => fields[2], "kind" => fields[3], "version" => fields[4].to_s, "files" => files, "versions" => [], "options_version" => nil }
    when "old"
      fields[3..-1].each_slice(2) { |name, hash| files[name] = hash if name && hash }
      mods.find { |mod| mod["key"] == fields[1] }["versions"] << [fields[2], files]
    when "opts"
      mods.find { |mod| mod["key"] == fields[1] }["options_version"] = fields[2]
    when "personal"
      personal |= [golden_mod_key(fields[1]), golden_mod_key(fields[2])]
    end
  end
  $catalog = { "state" => state, "error" => state == "failed" ? "down" : nil, "mods" => mods, "personal" => personal }
end

# Opens the scripts' bridge on a FakeBridge that answers the rule topics from the golden cases, or adds
# those answers to the world room's stand-in bridge when the test loaded it.
#
# @return [FakeBridge] The bridge, for a test to add answers or read the calls.
def open_rules_bridge
  load_bridge unless defined?(MGQ_Multiplayer::Bridge)
  fake = $world_bridge || FakeBridge.new
  answer_catchup(fake)
  answer_mod_keys(fake)
  answer_installed(fake)
  answer_world_rules(fake)
  fake.answer("mods.catalog") { $catalog }
  answer_story_parts(fake)
  MGQ_Multiplayer::Bridge.open(fake)
  fake
end
