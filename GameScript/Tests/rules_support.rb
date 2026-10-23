#----------------------------------------------------------------
#  rules_support.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Answered the mod catalog a test sets
#                            - Added the answers to the world room's stand-in bridge when a test has one
#                            - Stood in for the squad math, checked against its golden cases
#                            - Answered the squad rules of a served battle and their defaults
#                            - Answered the ids coop.rbx makes up
#                            - Answered the squad rules of a served battle and their defaults
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

# The golden cases of the squad rules and their math, recorded from the scripts before they left.
SQUAD_CASES = rule_cases("squad", "squad.json")

# Stands in for the squad math as the golden cases show it, checked against every case below.
module SquadStandIn
  # Splits places between players, one more each for the first ones while some are left over.
  #
  # @param total [Integer] The places.
  # @param count [Integer] The players.
  # @return [Array<Integer>] Each player's places.
  def self.split(total, count)
    return [] if count < 1

    total = [total, 0].max
    (0...count).map { |position| total / count + (position < total % count ? 1 : 0) }
  end

  # Splits a party's places between its players.
  #
  # @param count [Integer] The players.
  # @param max [Integer] The party_member_max.
  # @return [Array<Array>] Each player's [front, bench].
  def self.shares(count, max)
    split(4, count).zip(split(max - 4, count))
  end

  # Sizes a Raid World's squad for a fight, the last place cut unless the team keeps the game's size.
  #
  # @param rules [Hash] The rules by their names in the topics.
  # @param max [Integer] The party_member_max.
  # @param raid [Boolean] Whether the fight is a raid.
  # @return [Array<Integer>] [front, bench].
  def self.raid_share(rules, max, raid)
    original = rules["formation"] == 0
    size = original ? max : [max, rules["formation"]].min
    front = [[raid ? rules["raid_front"] : rules["front"], size].min, 1].max
    [front, original ? size - front : [size - front - 1, 0].max]
  end

  # Sizes a Raid World's squad for both fights.
  #
  # @param rules [Hash, nil] The rules by their names in the topics, nil for the defaults.
  # @param max [Integer] The party_member_max.
  # @return [Hash] "regular", "raid" and "largest".
  def self.raid(rules, max)
    rules ||= WORLD_RULES["rules"]["squad"]
    regular, raid = raid_share(rules, max, false), raid_share(rules, max, true)
    { "regular" => regular, "raid" => raid, "largest" => [regular.inject(:+), raid.inject(:+)].max }
  end

  # Orders players, the first one first, then by id.
  #
  # @param players [Array<Array>] Each player's id and whether they come first.
  # @return [Array<Integer>] Their places in the list given, in order.
  def self.ranked(players)
    (0...players.size).sort_by { |index| [players[index][1] ? 0 : 1, players[index][0], index] }
  end

  # Arranges a battle's players.
  #
  # @param request [Hash] The request of squad.arrange.
  # @return [Array<Array>] [index, front, bench] per player, in order.
  def self.arrange(request)
    players = request["players"]
    ranked(players).each_with_index.map do |index, position|
      _, _, max, count = players[index]
      front, bench =
        if !request["backline"] || request["rules"].nil?
          shares(players.size, max)[position]
        else
          squad = raid_share(request["rules"], max, request["raid"])
          fighting = [squad[0], [split(4, players.size)[position], 1].max].min
          [fighting, squad.inject(:+) - fighting]
        end
      front = [front, count].min
      [index, front, request["backline"] ? [bench, count - front].min : 0]
    end
  end

  # Picks the companions a team past its cap leaves out.
  #
  # @param request [Hash] The request of squad.past_cap.
  # @return [Array<Integer>] The ids left out.
  def self.past_cap(request)
    team, size = request["team"], request["cap"]
    kept = request["keep_luka"] ? team.select { |id| request["luka"].include?(id) }.first(size) : []
    team.each { |id| kept << id if kept.size < size && !kept.include?(id) }
    team - kept
  end
end

SQUAD_CASES["split"].each { |entry| raise "the split stand-in differs at #{entry.inspect}" unless SquadStandIn.split(entry["total"], entry["count"]) == entry["places"] }
SQUAD_CASES["share"].each { |entry| raise "the share stand-in differs at #{entry.inspect}" unless SquadStandIn.shares(entry["count"], entry["max"])[entry["position"]] == entry["share"] }
SQUAD_CASES["raid"].each do |entry|
  answer = SquadStandIn.raid(entry["rules"], entry["max"])
  raise "the raid stand-in differs at #{entry.inspect}" unless [answer["regular"], answer["raid"], answer["largest"]] == [entry["regular"], entry["raid"], entry["largest"]]
end
SQUAD_CASES["rank"].each { |entry| raise "the rank stand-in differs at #{entry.inspect}" unless SquadStandIn.ranked(entry["players"]).map { |index| entry["players"][index][0] } == entry["order"] }
SQUAD_CASES["arrange"].each { |entry| raise "the arrange stand-in differs at #{entry.inspect}" unless SquadStandIn.arrange(entry) == entry["arranged"] }
SQUAD_CASES["past_cap"].each { |entry| raise "the past_cap stand-in differs at #{entry.inspect}" unless SquadStandIn.past_cap(entry) == entry["standby"] }

# Answers the squad topics both hosts answer from the golden cases: the rules of a served battle's
# setup by looking its case up, the defaults as the world's rules name them, and the math by
# SquadStandIn.
#
# @param fake [FakeBridge] The bridge.
def answer_squads(fake)
  fake.answer("squad.default") { WORLD_RULES["rules"]["squad"] }
  fake.answer("squad.served") do |pairs|
    found = SQUAD_CASES["served"].find { |entry| entry["list"] == pairs } or raise "no golden served squad for #{pairs.inspect}"
    found["squad"]
  end
  fake.answer("squad.shares") { |request| SquadStandIn.shares(request["count"], request["max"]) }
  fake.answer("squad.rank") { |players| SquadStandIn.ranked(players).map { |index| players[index][0] } }
  fake.answer("squad.raid") { |request| SquadStandIn.raid(request["rules"], request["max"]) }
  fake.answer("squad.arrange") { |request| SquadStandIn.arrange(request) }
  fake.answer("squad.past_cap") { |request| SquadStandIn.past_cap(request) }
end

# Makes up an id as the DLL does, its digits counted up instead of drawn, so a test can tell ids
# apart: exactly the length asked for, in the base asked for.
#
# @param request [Hash] "length" and "radix".
# @return [String] The id.
def stand_in_random_id(request)
  $random_ids = $random_ids.to_i + 1
  $random_ids.to_s(request["radix"] || 36).rjust(request["length"], "0")[-request["length"], request["length"]]
end

# Answers the topic of random ids with stand_in_random_id.
#
# @param fake [FakeBridge] The bridge.
def answer_random_ids(fake)
  fake.answer("id.random") { |request| stand_in_random_id(request) }
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
  answer_random_ids(fake)
  answer_squads(fake)
  MGQ_Multiplayer::Bridge.open(fake)
  fake
end
