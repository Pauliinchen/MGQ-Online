#----------------------------------------------------------------
#  local_worlds_support.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Dropped the stand-ins of the topics the DLL no longer has
#                            - Handed out each mod's label and colour in the picker and left the entries to the screen's stand-in
#                            - Created
#
#----------------------------------------------------------------

# The topics of the worlds on this PC, the player's lists of worlds, the Discord invite, the game
# data compared and the mod picker, answered by FakeBridge stand-ins that keep their state in
# memory: the worlds in $local_worlds, the favourites and hidden worlds added in $world_lists. Each
# rule a stand-in follows is checked against the golden cases under fixtures/worlds as this file
# loads, which the C# owners pass too.

require "digest/md5"
require "fileutils"

# The golden cases of the local worlds.
LOCAL_WORLD_CASES = %w(entries ini saves data modpick).each_with_object({}) { |name, cases| cases[name] = rule_cases("worlds", "#{name}.json") }

# The worlds on this PC the stand-ins keep, by folder id, each as worlds.local tells it.
$local_worlds = {}

# The favourites and hidden worlds added, oldest first.
$world_lists = { "favourite" => [], "added" => [] }

# Strips a text as Ruby's strip does.
#
# @param text [String] The text.
# @return [String] It, stripped.
def stand_in_strip(text)
  text.to_s.gsub(/\A[\t\n\v\f\r \0]+|[\t\n\v\f\r \0]+\z/, "")
end

# Cleans a name as Multiplayer.rb cleans names.
#
# @param name [String] The name.
# @return [String] The name, "A friend" when nothing is left.
def stand_in_clean(name)
  cleaned = name.to_s.gsub(/[\x00-\x1f\\]/, "").strip[0, 32]
  cleaned.empty? ? "A friend" : cleaned
end

# Reads a world from its world.ini values as fixtures/worlds/ini.json shows it, into what
# worlds.local tells of it.
#
# @param id [String] The folder's id.
# @param values [Hash] The world.ini values.
# @return [Hash] The world.
def stand_in_world(id, values)
  difficulty = values["difficulty"].to_s =~ /\A-?\d\z/ ? values["difficulty"].to_i : nil
  difficulty = nil unless difficulty && difficulty.between?(-2, 4)
  code = values["code"] && stand_in_code("code" => values["code"])
  { "id" => id, "name" => stand_in_strip(values["name"]).empty? ? "?" : stand_in_clean(values["name"]), "code" => values["code"], "world" => values["world"],
    "created" => values["created"].to_i, "played" => values["played"] ? values["played"].to_i : nil, "type" => values["type"], "share" => values["share"],
    "difficulty" => difficulty, "squad" => stand_in_squad(values["squad"].to_s), "raid_bosses" => values["raid_bosses"].to_s == "1", "seats" => code ? code["seats"] : 0 }
end

LOCAL_WORLD_CASES["ini"]["cases"].each do |entry|
  world = stand_in_world("id", entry["values"])
  fields = entry["fields"]
  read = [world["name"], world["created"], world["played"], world["difficulty"], world["squad"] && stand_in_squad_text(world["squad"]), world["raid_bosses"]]
  raise "the world stand-in reads #{entry['values'].inspect} as #{read.inspect}" if read != fields.values_at("name", "created", "played", "difficulty", "squad", "raid_bosses")
end

# Makes a world on this PC the stand-ins keep, as a test sets one up.
#
# @param id [String] The folder's id.
# @param values [Hash] Its world.ini values.
# @return [MGQ_MpWorld::World] The world.
def local_world(id, values = {})
  $local_worlds[id] = stand_in_world(id, values)
  MGQ_MpWorld::World.new($local_worlds[id])
end

# Finds the latest save among files as fixtures/worlds/saves.json shows it.
#
# @param files [Array<Array>] [name, time] of each file, in the folder's order.
# @return [Array, nil] The save's index and file's name, nil without any.
def stand_in_latest_save(files)
  saves = files.map do |name, time|
    case name
    when /\ASave(\d{2})\.rvdata2\z/i then [$1.to_i - 1, name, time]
    when /\AAutoSave(\d{2})\.rvdata2\z/i then [$1, name, time]
    end
  end
  latest = saves.compact.max_by { |save| save[2] }
  latest && latest[0, 2]
end

LOCAL_WORLD_CASES["saves"]["cases"].each do |entry|
  raise "the save stand-in finds #{stand_in_latest_save(entry['files']).inspect} in #{entry['files'].inspect}" if stand_in_latest_save(entry["files"]) != entry["latest"]
end

# Builds the world screen's entries as fixtures/worlds/entries.json shows them.
#
# @param listed [Array<Array>] [id, name, raid, featured] of each listed world.
# @param local [Array<Hash>] The worlds on this PC.
# @param favourites [Array<String>] The favourites' directory ids.
# @param complete [Boolean] Whether the list arrived.
# @return [Array<Array>] [id, name, listed index, world, favourite, gone] of each entry, in order.
def stand_in_entries(listed, local, favourites, complete)
  by_id = {}
  local.each { |world| by_id[world["world"]] = world if world["world"] }
  ids = listed.map { |world| world[0] }
  made = listed.each_with_index.map { |(id, name, raid, featured), index| [id, name, index, by_id[id], favourites.include?(id), false, raid, featured] }
  local.each do |world|
    next if world["world"] && ids.include?(world["world"])

    made << [world["world"], world["name"], nil, world, favourites.include?(world["world"]), complete || !world["world"], world["type"] == "raid", false]
  end
  made.sort_by { |entry| [entry[5] ? 1 : 0, entry[6] ? 0 : 1, entry[4] ? 0 : 1, entry[7] ? 0 : 1, -(entry[3] ? entry[3]["played"].to_i : 0), entry[1].downcase] }.map { |entry| entry[0, 6] }
end

LOCAL_WORLD_CASES["entries"]["cases"].each do |entry|
  local = entry["local"].map { |id, name, world, raid, played| { "id" => id, "name" => name, "world" => world, "type" => raid ? "raid" : nil, "played" => played } }
  made = stand_in_entries(entry["listed"], local, entry["favourites"], entry["complete"]).map { |id, name, index, world, favourite, gone| [id, name, index && entry["listed"][index][0], world && world["id"], favourite, gone] }
  raise "the entries stand-in orders #{made.inspect}, the scripts #{entry['entries'].inspect}" if made != entry["entries"]
end

# The game data fingerprint handed to the stand-ins.
$game_fingerprint = ""

# Compares two fingerprints as fixtures/worlds/data.json shows it.
#
# @param mine [String] This game's fingerprint.
# @param other [String, nil] The other's.
# @return [Array<String>, nil] The parts that differ, nil when they cannot be compared.
def stand_in_differing(mine, other)
  parts = LOCAL_WORLD_CASES["data"]["parts"]
  return nil if other.to_s.empty?

  format, sums = mine.split(":", 2)
  other_format, theirs = other.to_s.split(":", 2)
  return nil unless sums && theirs && format == other_format

  sums = sums.split(".")
  theirs = theirs.split(".")
  return nil unless sums.size == parts.size && theirs.size == parts.size

  (0...parts.size).select { |index| sums[index] != theirs[index] }.map { |index| parts[index] }
end

# Names parts in a sentence as fixtures/worlds/data.json shows it.
#
# @param parts [Array<String>] The parts.
# @param named [Integer] Most parts named.
# @return [String] The text.
def stand_in_data_text(parts, named)
  parts.size <= named ? parts.join(", ") : "#{parts.first(named).join(', ')} and #{parts.size - named} more"
end

LOCAL_WORLD_CASES["data"]["differing"].each do |entry|
  raise "the data stand-in compares #{entry['other'].inspect} otherwise" if stand_in_differing(entry["mine"], entry["other"]) != entry["differing"]
end
LOCAL_WORLD_CASES["data"]["texts"].each do |entry|
  raise "the data stand-in names #{entry['parts'].inspect} otherwise" if stand_in_data_text(entry["parts"], entry["named"]) != entry["text"]
end

# The mod picker as fixtures/worlds/modpick.json shows it, with the golden mod keys.
class StandInModPick
  # The colour of a mod's row by its state, as fixtures/screen/screen.json holds them.
  MOD_STATE_COLORS = rule_cases("screen", "screen.json")["texts"]["mod_states"].each_with_object({}) { |(state, _label, color), colors| colors[state] = color }

  # The longest text of mods.
  MAX = 16_000

  # Each mod as [name, state, installed].
  attr_reader :entries

  # Opens the picker.
  #
  # @param text [String] The mods as written.
  # @param installed [Array<String>] The installed mods' names.
  def initialize(text, installed)
    @entries = installed.map { |name| [name, "unlisted", true] }
    read = stand_in_mods_text(text)
    read["names"].each do |name|
      state = read["required"].include?(name) ? "required" : (read["essential"].include?(name) ? "essential" : "listed")
      found = find(name)
      found ? found[1] = state : @entries << [name, state, false]
    end
  end

  # @return [String] The mods named.
  def text
    @entries.reject { |entry| entry[1] == "unlisted" }.map { |entry| "#{{ 'listed' => '', 'required' => '!', 'essential' => '?' }[entry[1]]}#{entry[0]}" }.join("; ")
  end

  # @return [Boolean] Whether every installed mod is named.
  def all_listed
    @entries.all? { |entry| !entry[2] || entry[1] != "unlisted" }
  end

  # Runs a change as modpick.act names it.
  #
  # @param request [Hash] The change.
  # @return [Object] Its answer.
  def act(request)
    index = request["index"]
    case request["do"]
    when "set" then set(index, request["state"])
    when "toggle" then set(index, @entries[index][1] == "unlisted" ? "listed" : "unlisted")
    when "mark" then set(index, @entries[index][1] == request["state"] ? "listed" : request["state"])
    when "remove" then @entries[index][2] ? false : (@entries.delete_at(index) && true)
    when "list_all" then (0...@entries.size).each { |at| next unless @entries[at][2] && @entries[at][1] == "unlisted"; error = set(at, "listed"); return error if error }; nil
    when "unlist_all" then @entries.each { |entry| entry[1] = "unlisted" if entry[2] }; nil
    when "add" then add(request["name"])
    end
  end

  # Describes the picker as modpick.open answers it.
  #
  # @return [Hash] The picker.
  def view
    { "entries" => @entries.map { |entry| entry + [entry[1], MOD_STATE_COLORS[entry[1]]] }, "text" => text, "all_listed" => all_listed }
  end

  private

  # Names a mod another way, unless the text grows too long.
  def set(index, state)
    before = @entries[index][1]
    @entries[index][1] = state
    return nil if text.size <= MAX

    @entries[index][1] = before
    "The mods may take #{MAX} characters at most."
  end

  # Adds a mod by its name.
  def add(name)
    name = name.to_s.strip.sub(/\A[!?]\s*/, "")
    return "A mod's name cannot be empty." if name.empty?
    return "A mod's name cannot hold a semicolon." if name.include?(";")
    return "#{find(name)[0]} is in the list already." if find(name)

    @entries << [name, "listed", false]
    return nil if text.size <= MAX

    @entries.pop
    "The mods may take #{MAX} characters at most."
  end

  # Makes a mod key: the golden one, or for a name the golden keys lack, the ASCII rule with any
  # letter in lower case.
  def key_of(name)
    GOLDEN_KEYS[name] || name.downcase.sub(/\.rb\z/, "").delete(" \t\n\v\f\r_-")
  end

  # Finds a mod by its key.
  def find(name)
    @entries.find { |entry| key_of(entry[0]) == key_of(name) }
  end
end

LOCAL_WORLD_CASES["modpick"]["cases"].each do |entry|
  pick = StandInModPick.new(entry["text"], entry["installed"])
  entry["steps"].each do |step|
    operation, *arguments = step["step"]
    long = arguments.map { |argument| argument.is_a?(String) && argument =~ /\A<(.)\*(\d+)>\z/ ? $1 * $2.to_i : argument }
    answer = operation == "all_listed" ? pick.all_listed : pick.act("do" => operation, "index" => long[0], "state" => long[1], "name" => long[0])
    names = pick.entries.map { |name, state, installed| [name.size > 40 ? "#{name[0, 3]}*#{name.size}" : name, state, installed] }
    raise "the picker stand-in answers #{answer.inspect} to #{step['step'].inspect}" if answer != step["answer"]
    raise "the picker stand-in holds #{names.inspect} after #{step['step'].inspect}" if names != step["pick"]["entries"] || pick.text.size != step["pick"]["text_size"]
  end
end

# The directory id the invite stand-in tells of every world code, nil for one made from the code.
$invite_world_id = nil

# The scripts in Patch the mod picker lists, as the test sets them; nil reads the Patch folder.
$picker_installed = nil

# Writes what the directory says of a world into a world the stand-ins keep.
#
# @param world [Hash] The world.
# @param request [Hash] What the directory says, as worlds.found takes it.
# @return [Hash] The world.
def stand_in_describe(world, request)
  world["name"] = stand_in_clean(request["name"])
  world["world"] = request["world"]
  %w(type share difficulty squad).each { |key| world[key] = request[key] if request[key] }
  world["raid_bosses"] = request["raid_bosses"] unless request["raid_bosses"].nil?
  if request["seats"]
    told = stand_in_code("code" => world["code"].to_s, "seats" => request["seats"])
    world["code"], world["seats"] = told["code"], told["seats"] if told
  end
  world
end

# Answers the topics of the worlds on this PC, the lists, the invite, the game data and the mod picker.
#
# @param fake [FakeBridge] The bridge.
def answer_local_worlds(fake)
  fake.answer("worlds.local") { $local_worlds.values }
  fake.answer("worlds.found") do |request|
    next nil unless stand_in_code("code" => request["code"])

    id = Digest::MD5.hexdigest(request["code"])[0, 12]
    $local_worlds[id] ||= stand_in_world(id, "code" => request["code"], "created" => Time.now.to_i.to_s)
    stand_in_describe($local_worlds[id], request)
  end
  fake.answer("worlds.describe") { |request| $local_worlds[request["id"]] && stand_in_describe($local_worlds[request["id"]], request) }
  fake.answer("worlds.update") do |request|
    world = $local_worlds[request["id"]]
    next nil unless world

    %w(difficulty squad).each { |key| world[key] = request[key] if request[key] }
    world["raid_bosses"] = request["raid_bosses"] unless request["raid_bosses"].nil?
    world["played"] = Time.now.to_i if request["played"]
    { "world" => world, "written" => true }
  end
  fake.answer("worlds.latest_save") do |id|
    folder = "#{MGQ_MpWorld::WORLDS_DIR}/#{id}/Save"
    files = File.directory?(folder) ? Dir.entries(folder).sort_by { |name| name.downcase }.map { |name| [name, File.mtime("#{folder}/#{name}")] } : []
    latest = stand_in_latest_save(files)
    latest && [latest[0], "#{folder}/#{latest[1]}"]
  end
  fake.answer("worlds.added") { $world_lists["added"] }
  fake.answer("worlds.invite") do |request|
    next nil unless stand_in_code("code" => request["code"].to_s)

    id = $invite_world_id || Digest::MD5.hexdigest(request["code"])
    taken = request["open"] != id
    $world_invite = [id, request["code"]] if taken
    { "world" => id, "taken" => taken }
  end
  fake.answer("worlds.invite_take") { taken = $world_invite; $world_invite = nil; taken }
  fake.answer("worlds.game_data") { |fingerprint| $game_fingerprint = fingerprint; nil }
  fake.answer("worlds.data_differing") { |other| stand_in_differing($game_fingerprint, other) }
  fake.answer("worlds.data_text") { |request| stand_in_data_text(request["parts"], request["named"]) }
  fake.answer("modpick.open") do |request|
    installed = $picker_installed || Dir.glob("Patch/**/*.rb").map { |path| File.basename(path, ".rb") }.reject { |name| %w(patch multiplayer 0modconfigremake).include?(golden_mod_key(name)) }
    $mod_pick = StandInModPick.new(request["text"], installed.uniq { |name| golden_mod_key(name) }.sort_by { |name| name.downcase })
    $mod_pick.view
  end
  fake.answer("modpick.act") { |request| $mod_pick && { "answer" => $mod_pick.act(request), "pick" => $mod_pick.view } }
  fake.answer("modpick.close") { $mod_pick = nil }
end
