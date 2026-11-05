#----------------------------------------------------------------
#  rules_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Stood in for the one decision of the player's own common events, a resumed raid fight and whether a telling moves the world's story on, and named the castle's maps
#                            - Answered the topics of the one guard of the game's flow from its stand-in, checked against the reported cases
#      Paulinchen  2026-11-01: Dropped the stand-ins of the World overview's story topics and of marking settings shared, which no script calls
#      Paulinchen  2026-10-30: Dropped the stand-ins of the parking's topics
#                            - Dropped the stand-in of mods.install, which the Mod Framework does
#      Paulinchen  2026-10-28: Answered the chests, page flags and command index of a map's pages as a DLL without an events database
#                            - Took the fingerprint the events database is opened with and sorted the pages of a map handed over
#                            - Read the seed rows of the relay's story tables, from which the catch-up's tests build their tables
#                            - Answered the rewards a party member catches up with from the test's stand-in of coop_story_rewards.rbx
#      Paulinchen  2026-10-23: Dropped the stand-in of the directory's tickets, which no script asks for any more
#                            - Kept the test's one stand-in bridge in $world_bridge
#                            - Stood in for the frozen fights' write journal, checked against its golden cases
#                            - Answered the world screen's steps into a world with the steps a test sets
#                            - Answered the world screen's model
#                            - Answered the parking topics as for a game with no mod turned off
#                            - Answered the shared mod settings' topics with their golden texts and the steps a test queues
#                            - Answered the mods check, the directory's tickets and the mods topics the world screen calls
#                            - Answered the world screen's forms
#                            - Answered the worlds on this PC, the lists, the invite, the game data and the mod picker
#                            - Answered the World overview's story and title
#                            - Answered the mods text of a world
#                            - Kept the test's one stand-in bridge in $world_bridge
#      Paulinchen  2026-10-28: Answered the story's choices
#                            - Answered the calls of a story
#                            - Answered the story's scene
#                            - Answered the story's pages
#      Paulinchen  2026-10-23: Kept the test's one stand-in bridge in $world_bridge
#                            - Answered the event sorter
#                            - Answered the mod catalog a test sets
#                            - Added the answers to the world room's stand-in bridge when a test has one
#                            - Stood in for the squad math, checked against its golden cases
#                            - Answered the squad rules of a served battle and their defaults
#                            - Answered the ids coop.rbx makes up
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
require "zlib"
require_relative "bridge_support"
require_relative "form_support"
require_relative "../../fixtures/catchup/relay_rows"

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

# Folder of the relay's seed rows of its story tables.
STORY_SEEDS = File.expand_path("../../Relay/seed/story", __dir__)

# Reads the rows of a seed file of the relay's story tables.
#
# @param table [String] The table, such as "rules".
# @return [Array<Hash>] Its rows.
def seed_rows(table)
  JSON.parse(File.read(File.join(STORY_SEEDS, "#{table}.json"), :encoding => "UTF-8"))["rows"]
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

# The golden reads of mods texts.
MODS_TEXTS = rule_cases("mods", "text.json")["cases"]

# Reads a world's mods text as the golden cases show it: split at semicolons and stripped, the
# required ("!") and essential ("?") ones without their mark first, each once, then the rest.
#
# @param text [String, nil] The mods as written.
# @return [Hash] "names", "required" and "essential".
def stand_in_mods_text(text)
  marked = lambda { |mark| text.to_s.split(";").map { |mod| mod.strip[/\A#{Regexp.escape(mark)}\s*(\S.*)\z/, 1] }.compact }
  names = text.to_s.split(";").map { |mod| mod.strip.sub(/\A[!?]\s*/, "") }.reject { |mod| mod.empty? }
  required = marked.call("!")
  essential = marked.call("?")
  { "names" => (names & required) + (names & essential) + (names - required - essential), "required" => required, "essential" => essential }
end

MODS_TEXTS.each do |entry|
  read = stand_in_mods_text(entry["text"])
  raise "the mods text stand-in reads #{entry['text'].inspect} as #{read.inspect}" if read != { "names" => entry["names"], "required" => entry["required"], "essential" => entry["essential"] }
end

# Answers the mods text topic as fixtures/mods/text.json shows it.
#
# @param fake [FakeBridge] The bridge.
def answer_mods_text(fake)
  fake.answer("mods.text") { |text| stand_in_mods_text(text) }
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

# The golden story and title texts of the World overview.
OVERVIEW_TEXTS = rule_cases("overview", "story.json")

# The overview's names of the sides and routes.
OVERVIEW_NAMES = { "ilias" => "Ilias side", "alice" => "Alice side", "chaos" => "Chaos route", "destroyer" => "Destroyer route", "judgment" => "Judgment route" }

# Finds a player's place in the story as the golden cases show it: the part by the progress alone,
# then in Part 3 the first route under way of chaos, destroyer and judgment, else the first side
# chosen of ilias and alice.
#
# @param request [Hash] "p", "routes" and "sides".
# @return [String] The code.
def stand_in_story(request)
  part = stand_in_part("p" => request["p"], "routes" => [0, 0, 0])
  route = %w(chaos destroyer judgment).find { |key| request["routes"][key].to_i > 0 } if part == "3"
  chosen = route || %w(ilias alice).find { |key| request["sides"][key] }
  chosen ? "#{part}:#{chosen}" : part
end

# Writes a place in the story as the golden cases show it.
#
# @param code [String, nil] The code.
# @return [String] The text.
def stand_in_story_text(code)
  part, chosen = code.to_s.split(":", 2)
  return "" if part.to_s.empty?

  OVERVIEW_NAMES[chosen.to_s] ? "Part #{part}: #{OVERVIEW_NAMES[chosen.to_s]}" : "Part #{part}"
end

# Writes the world's place in the story as the golden cases show it.
#
# @param part [String, nil] The part.
# @return [Hash] "code" and "text".
def stand_in_world_story(part)
  route = { "ad" => "destroyer", "mr" => "judgment", "chaos" => "chaos" }[part]
  code = route ? "3:#{route}" : part.to_s
  { "code" => code, "text" => code.empty? ? "Not told yet" : stand_in_story_text(code) }
end

# Writes the title's tail and the World page's note as the golden cases show it.
#
# @param request [Hash] "raid" and "difficulty".
# @return [Hash] "tail" and "note".
def stand_in_title(request)
  found = WORLD_RULES["rules"]["difficulties"].find { |value, _| value == request["difficulty"] }
  name = found && found[1].capitalize
  type = request["raid"] ? "Raid" : "Classic"
  { "tail" => [type, name].compact.map { |part| " | #{part}" }.join, "note" => [type, name || "Per player"].join(" | ") }
end

OVERVIEW_TEXTS["stories"].each do |entry|
  raise "the story stand-in finds #{stand_in_story(entry['request'])} for #{entry['request'].inspect}" if stand_in_story(entry["request"]) != entry["code"]
end
OVERVIEW_TEXTS["texts"].each do |entry|
  raise "the story text stand-in writes #{entry['code'].inspect} otherwise" if stand_in_story_text(entry["code"]) != entry["text"]
end
OVERVIEW_TEXTS["worlds"].each do |entry|
  raise "the world story stand-in writes #{entry['part'].inspect} otherwise" if stand_in_world_story(entry["part"]) != { "code" => entry["code"], "text" => entry["text"] }
end
OVERVIEW_TEXTS["titles"].each do |entry|
  raise "the title stand-in writes #{entry.inspect} otherwise" if stand_in_title(entry) != { "tail" => entry["tail"], "note" => entry["note"] }
end

# Answers the World overview's title topic as fixtures/overview/story.json shows them.
#
# @param fake [FakeBridge] The bridge.
def answer_overview(fake)
  fake.answer("overview.title") { |request| stand_in_title(request) }
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

# Opens the scripts' bridge on the test's one FakeBridge, $world_bridge, made here unless the world
# room's or the interface's stand-ins made it, adding the answers of the rule topics from the golden
# cases.
# The event sorter's golden cases of fixtures/events/script_cases.json.
EVENT_CASES = rule_cases("events", "script_cases.json")["cases"]

# The values a sort's case recorded, by kind.
SORT_VALUE_KINDS = %w(s v ps pv)

# The common events the stand-in of the DLL's decision answers as the player's own, which a test
# sets; MGQOnline.Game's EventSorter.Decide holds the game's own list.
$own_commons = []

# The maps of the Pocket Castle's residents the stand-in of the DLL names, see PocketCastle in
# MGQOnline.Game.
CASTLE_MAPS = [227, 228, 229, 230] + (268..278).to_a

# Answers the event sorter's topics from fixtures/events/script_cases.json: a list the scripts hand
# over is looked up among the cases with its trigger, command and resident flag; the values it lacks
# are named as the DLL names them, and those it hands over pick the case. A map event's page or a
# common event is unknown, as the DLL holds no events database in the tests, so the scripts hand
# the list over; the fingerprint the scripts open the database with is taken and noted. For the
# same reason the chests, the page flags and the command index of a map's pages answer none. The
# decision's own answers stand in: a common event of $own_commons is the player's own, a resumed
# raid fight's page is story, and no telling moves the world's story on.
#
# @param fake [FakeBridge] The bridge.
def answer_events(fake)
  fake.answer("events.open") do |request|
    raise FakeBridge::BadRequest, "no fingerprint" unless request["fingerprint"].is_a?(String)

    { "usable" => false, "problem" => "no events database at Patch/Multiplayer/Data/events.db", "differing" => [], "castle_maps" => CASTLE_MAPS }
  end
  fake.answer("story.moves") { |_request| { "moves" => false, "progress" => [] } }
  fake.answer("events.sort") { |request| golden_sort(request) }
  fake.answer("events.kinds") { |request| golden_kinds(request) }
  fake.answer("events.chests") { |request| { "letters" => Array(request["rows"]).map { nil } } }
  fake.answer("events.pages") { |request| { "pages" => Array(request["rows"]).map { nil } } }
  fake.answer("events.index") { |request| { "indexes" => Array(request["pages"]).map { nil } } }
end

# Answers the sort of a map's pages from the golden cases, see answer_events: a page named by its
# length and shape as none, a page handed over as the golden list's kind.
#
# @param request [Hash] The request.
# @return [Hash] The kinds, or the values the pages handed over need.
def golden_kinds(request)
  answers = Array(request["pages"]).map do |row|
    next nil unless row[2].is_a?(Array)

    golden_sort("list" => row[2], "trigger" => nil, "values" => request["values"])
  end
  needs = {}
  answers.compact.each { |answer| (answer["needs"] || {}).each { |kind, ids| needs[kind] = (needs[kind] || []) | ids } }
  return { "needs" => needs } unless needs.empty?

  { "kinds" => answers.map { |answer| answer && answer["list_kind"] } }
end

# Answers one sort from the golden cases, see answer_events.
#
# @param request [Hash] The request.
# @return [Hash] The case's answer, the values it needs, or unknown.
def golden_sort(request)
  if !request["index"] && $own_commons.include?(request["common"])
    return { "kind" => "own", "list_kind" => "own", "may_tell" => false, "scene" => false, "marks" => [], "own" => "common event #{request['common']} is one of the game's own" }
  end
  return { "unknown" => true } unless request["list"]

  rows = JSON.parse(JSON.generate(request["list"]))
  call = request["index"] ? "command" : (request["trigger"].nil? ? "list" : "page")
  found = EVENT_CASES.select do |known|
    known["call"] == call && known["list"] == rows && known["index"] == request["index"] &&
      known["resident"] == (request["resident"] == true) && (call != "page" || known["trigger"] == request["trigger"])
  end
  raise "no golden sort for the #{call} #{rows.inspect}" if found.empty?

  values = request["values"] || {}
  held = found.find { |known| SORT_VALUE_KINDS.all? { |kind| (known[kind] || {}).all? { |id, value| (values[kind] || {}).key?(id.to_i) && values[kind][id.to_i] == value } } }
  return request["resumed"] && !request["index"] ? held["answer"].merge("kind" => "story", "list_kind" => "story") : held["answer"] if held

  needs = {}
  found.each do |known|
    SORT_VALUE_KINDS.each { |kind| (known[kind] || {}).each_key { |id| (needs[kind] ||= []) << id.to_i unless (values[kind] || {}).key?(id.to_i) } }
  end
  raise "no golden sort for the #{call} #{rows.inspect} with #{values.inspect}" if needs.empty?

  { "needs" => Hash[needs.map { |kind, ids| [kind, ids.uniq] }] }
end

# The frozen fights' write journal as StoryJournal in MGQOnline.Game keeps it: the writes taken,
# those at or before the oldest live mark dropped, and each key written since a mark once, with its
# value before its first write since it; a mark the journal dropped writes after reads as unknown.
class StandInJournal
  # Starts empty.
  def initialize; @entries = []; @floor = 0; @last = 0; end

  # Takes writes and drops those no live mark needs.
  #
  # @param entries [Array<Array>] Each [seq, kind, key, before].
  # @param keep [Integer, nil] The oldest live mark, nil for none.
  def take(entries, keep)
    @entries.concat(entries)
    @last = ([@last] + entries.map(&:first)).max
    return (@entries = []) && (@floor = [@floor, @last].max) if keep.nil?

    @entries.reject! { |seq, *_| seq <= keep }
    @floor = [@floor, keep].max
  end

  # Lists the keys written since a mark.
  #
  # @param mark [Integer] The mark.
  # @return [Hash] "rows" (each [kind, key, before]) and "overflow".
  def since(mark)
    return { "rows" => [], "overflow" => true } if mark < @floor

    seen = {}
    rows = @entries.select { |seq, kind, key, _| seq > mark && !seen[[kind, key]] && (seen[[kind, key]] = true) }.map { |_, kind, key, before| [kind, key, before] }
    { "rows" => rows, "overflow" => false }
  end
end

# The golden cases of the journal, which the old whole-story diff gave.
JOURNAL_CASES = rule_cases("freeze", "journal.json")["cases"]

JOURNAL_CASES.each do |entry|
  journal = StandInJournal.new
  journal.take(entry["entries"], entry["mark"])
  raise "the stand-in of the journal differs from fixtures/freeze/journal.json: #{entry['name']}" unless journal.since(entry["mark"]) == { "rows" => entry["rows"], "overflow" => false }
end

# Answers the rewards a party member catches up with from the test's stand-in of the relay's
# rewards tables in the shapes PartyRewards in the DLL hands them (MGQ_MpCoopStoryRewards, held
# against fixtures/catchup/party_rewards.json by MGQOnline.Game.Tests), empty without one; and a
# Classic world's fetch of the story mapping, which answers nothing.
#
# @param fake [FakeBridge] The bridge.
def answer_party_rewards(fake)
  fake.answer("story.rewards") { |_known| CatchupRelayRows.party_rewards(defined?(MGQ_MpCoopStoryRewards) ? MGQ_MpCoopStoryRewards : nil).merge("rev" => 1) }
  fake.answer("story.mapping") { |_world| nil }
end

# Has the scripts read the rewards a party member catches up with anew, as after a test put its
# stand-in of their table in place.
def rewards_changed
  MGQ_MpStoryState.instance_variable_set(:@rewards, nil)
  MGQ_MpStoryState.instance_variable_set(:@rewards_at, nil)
end

# Answers the frozen fights' write journal with a stand-in of its own.
#
# @param fake [FakeBridge] The bridge.
def answer_journal(fake)
  journal = StandInJournal.new
  fake.answer("freeze.journal") { |request| journal.take(request["entries"], request["keep"]) && nil }
  fake.answer("freeze.since") { |mark| journal.since(mark) }
end

require_relative "local_worlds_support"
require_relative "screen_support"
# What the mods check answers, a block a test sets that takes the request; nil checks only whether
# each required mod is installed, as the DLL does without a catalog or the creator's hashes.
$mod_check = nil

# The mods the battle server runs as mods.served answers them, the mods mods.report names and the
# options mods.options was handed.
$served_mods = []
$reported_mods = []
$sent_options = []

# Checks a world's required mods as the golden cases show it for a game without a catalog or the
# creator's hashes: each one whose script Patch lacks is not installed.
#
# @param request [Hash] The world's mods, hashes and name.
# @param installed [Array<String>, nil] The keys of the scripts in Patch, nil when it cannot be read.
# @return [Hash] The check as mods.check answers it.
def stand_in_mod_check(request, installed)
  missing = stand_in_mods_text(request["mods"])["required"].reject { |name| installed.nil? || installed.include?(golden_mod_key(name)) }
  rows = missing.map { |name| { "name" => name, "yours" => "not installed", "worlds" => nil, "key" => nil, "target" => nil, "text" => "#{name}: not installed", "downloadable" => false } }
  summary = "#{request['world']} needs mods that are missing or in another version here: #{missing.map { |name| "#{name} (get it from its author)" }.join(', ')}."
  { "known" => false, "rows" => rows, "summary" => rows.empty? ? nil : summary }
end

rule_cases("mods", "check.json")["checks"].each do |entry|
  next if entry["catalog"] || !entry["hashes"].empty?

  installed = entry["installed"] && entry["installed"].map { |key, _| key }
  read = stand_in_mod_check({ "mods" => entry["mods"], "world" => "Modded" }, installed)
  golden = entry["rows"].map { |row| row.merge("downloadable" => !row["key"].nil?) }
  raise "the mods check stand-in reads #{entry['mods'].inspect} otherwise than the DLL" if read["rows"] != golden || read["summary"] != entry["summary"]
end

# Answers the mods topics the world screen and the world's mods call: the check as $mod_check or
# the stand-in has it over the scripts in Patch, and the rest from what a test sets.
#
# @param fake [FakeBridge] The bridge.
def answer_mod_check(fake)
  fake.answer("mods.check") do |request|
    next $mod_check.call(request) if $mod_check

    # The scripts a test told world.rbx Patch holds, else those of the Patch folder below the current one.
    told = defined?(MGQ_MpWorld) && MGQ_MpWorld.instance_variable_get(:@installed)
    installed = told ? told.map { |script| script[0] } : Dir.glob("Patch/**/*.rb").map { |file| golden_mod_key(File.basename(file)) }
    stand_in_mod_check(request, installed)
  end
  fake.answer("mods.creator_hashes") { |_mods| $creator_hashes.to_s }
  fake.answer("mods.forget") { nil }
  fake.answer("mods.served") { |_mods| $served_mods }
  fake.answer("mods.report") { $reported_mods }
  fake.answer("mods.options") { |request| $sent_options << request; true }
end

# The golden texts of shared mod settings.
SETTINGS_CASES = rule_cases("mods", "settings.json")

# Tells whether settings are shared as the golden cases show it: anything but white space.
#
# @param text [String, nil] The settings.
# @return [Boolean] Whether they are.
def stand_in_shared(text)
  !text.to_s.strip.empty?
end

SETTINGS_CASES["shared"].each { |entry| raise "the shared stand-in reads #{entry['text'].inspect} otherwise" if stand_in_shared(entry["text"]) != entry["shared"] }

# Each settings topic called, as [topic, request], and the steps the next calls answer, one Array
# of steps per call, which a test queues.
$settings_calls = []
$settings_steps = []

# Answers the shared mod settings' topics: the texts as the golden cases show them, the world
# entered as the DLL describes it, and the steps a test queued.
#
# @param fake [FakeBridge] The bridge.
def answer_settings(fake)
  world = nil
  confirmed = {}
  reply = lambda { |topic, request| $settings_calls << [topic, request]; { "world" => world, "steps" => $settings_steps.shift || [] } }
  fake.answer("settings.shared") { |text| stand_in_shared(text) }
  fake.answer("settings.confirmed") { |request| confirmed[request["id"]] = request["text"]; nil }
  fake.answer("settings.of") { |request| request["fresh"] || !confirmed.key?(request["id"]) ? request["settings"] : confirmed[request["id"]] }
  fake.answer("settings.details") { |request| $settings_calls << ["settings.details", request]; "Mod settings: #{stand_in_shared(request['settings']) ? 'shared' : "each player's own"}" }
  fake.answer("settings.enter") do |request|
    listed = request["world"]
    text = listed && (request["fresh"] || !confirmed.key?(listed["id"]) ? listed["settings"] : confirmed[listed["id"]])
    world = listed && { "id" => listed["id"], "name" => listed["name"], "creator_id" => listed["creator_id"], "creator_name" => listed["creator_name"], "mods" => listed["mods"],
                        "text" => text, "crc" => Zlib.crc32(text).to_s(16), "own" => !request["me"].empty? && request["me"] == listed["creator_id"],
                        "shared" => stand_in_shared(text), "latest_shared" => stand_in_shared(text) }
    reply.call("settings.enter", request)
  end
  fake.answer("settings.forget") { |request| world = nil; reply.call("settings.forget", request) }
  %w(settings.options settings.loaded settings.want settings.step settings.applied settings.live settings.observe settings.mods).each do |topic|
    fake.answer(topic) { |request| reply.call(topic, request) }
  end
  fake.answer("settings.told") { |request| $settings_calls << ["settings.told", request]; nil }
  fake.answer("settings.leave") { |seat| $settings_calls << ["settings.leave", seat]; nil }
end

# Opens the scripts' bridge on a FakeBridge that answers the rule topics from the golden cases, or adds
# those answers to the world room's stand-in bridge when the test loaded it.
#
# @return [FakeBridge] The bridge, for a test to add answers or read the calls.
# The world screen's calls of its steps into a world (WorldEntering in C#), each as [topic, request].
$screen_calls = []

# The steps the world screen's next call of a step topic gets, which a test sets; every call takes
# them and leaves none.
$screen_steps = []

# Whether the DLL's steps wait for the list to enter a world, as screen.do answers it.
$screen_waiting = false

# Answers the topics of the world screen's steps with the steps a test set, since their rules have
# their tests in C# (WorldEnteringTests); the script tests check that the screen plays the steps it
# is handed and hands back what the player did.
#
# @param fake [FakeBridge] The bridge.
def answer_screen_steps(fake)
  %w(screen.enter screen.answer screen.step screen.do).each do |topic|
    fake.answer(topic) do |request|
      $screen_calls << [topic, request]
      steps = $screen_steps
      $screen_steps = []
      topic == "screen.do" ? { "steps" => steps, "waiting" => $screen_waiting } : { "steps" => steps }
    end
  end
end

# Finds the requests of the world screen's calls of a step topic.
#
# @param topic [String] The topic, such as "screen.answer".
# @return [Array<Hash>] Each call's request, oldest first.
def screen_requests(topic)
  $screen_calls.select { |called, _| called == topic }.map { |_, request| request }
end

def open_rules_bridge
  load_bridge unless defined?(MGQ_Multiplayer::Bridge)
  fake = ($world_bridge ||= FakeBridge.new)
  answer_catchup(fake)
  answer_mod_keys(fake)
  answer_mods_text(fake)
  answer_mod_check(fake)
  answer_settings(fake)
  answer_installed(fake)
  answer_world_rules(fake)
  fake.answer("mods.catalog") { $catalog }
  answer_story_parts(fake)
  answer_random_ids(fake)
  answer_squads(fake)
  answer_events(fake)
  answer_overview(fake)
  answer_local_worlds(fake)
  answer_screen(fake)
  answer_forms(fake)
  answer_screen_steps(fake)
  answer_choices(fake)
  answer_gather(fake)
  answer_scene(fake)
  answer_flow(fake)
  answer_pages(fake)
  answer_journal(fake)
  answer_party_rewards(fake)
  MGQ_Multiplayer::Bridge.open(fake)
  fake
end

require_relative "choices_support"
require_relative "gather_support"
require_relative "scene_support"
require_relative "flow_support"
require_relative "pages_support"
