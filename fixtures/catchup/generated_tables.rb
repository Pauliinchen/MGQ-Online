#----------------------------------------------------------------
#  generated_tables.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Left the Medal King's switches and the items an event takes away empty for the tests to fill, and dropped the prize counts
#      Paulinchen  2026-10-31: Dropped the maps where warping is free
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

require "json"

# The catch-up's generated tables as Ruby rows, read back from fixtures/catchup/generated, where
# Relay/seed/story/make_seed.rb wrote them from the game scripts' world_catchup_data.rbx before the
# relay's tables replaced it. The script tests and the recorders of the catch-up's golden cases build
# their tables from these rows, over which those cases were decided.
module GeneratedCatchupTables
  # Where the generated tables lie.
  FOLDER = File.join(__dir__, "generated")

  # A part of the story: its id, name, the marks that end it and its level gate.
  Part = Struct.new(:id, :name, :ending, :gate)

  # A companion's story join.
  Join = Struct.new(:actor, :persona, :site, :part, :step, :side, :marks, :gate, :rule, :index, :ran)

  # A companion's removal by the story.
  Removal = Struct.new(:actor, :persona, :site, :part, :step, :side, :marks, :first, :index)

  # A key item the story gives or takes.
  KeyItem = Struct.new(:item, :amount, :site, :part, :step, :side, :marks, :ran)

  # A chest that holds key items: its self switch, items, place and the chest flags it turns on.
  Chest = Struct.new(:key, :items, :part, :step, :flags)

  # A skill or item the story and its side quests give.
  Reward = Struct.new(:kind, :id, :amount, :site, :part, :step, :side, :marks, :ran)

  # A skill the story teaches a companion.
  Lesson = Struct.new(:actor, :skill, :site, :part, :step, :side, :marks, :ran)

  # A class or race level the story gives a character.
  ClassLevel = Struct.new(:actor, :class_id, :level, :site, :part, :step, :side, :marks, :ran)

  # A change of a companion the story makes by its calls.
  ActorChange = Struct.new(:actor, :calls, :gate, :site, :part, :step, :side, :marks, :ran)

  # A setting the story changes: the encounters, a variable or a switch.
  Setting = Struct.new(:kind, :id, :value, :site, :part, :step, :side, :marks, :ran)

  # A vehicle the story hands over, by its number.
  Vehicle = Struct.new(:vehicle, :site, :part, :step, :side, :marks, :ran)

  # A Makina with its level and site.
  Makina = Struct.new(:item, :level, :site)

  # The Ruby kind of a reward, by the relay's name.
  REWARD_KINDS = { "skill" => :skill, "item" => :i, "weapon" => :w, "armor" => :a }

  # The Ruby kind of a setting, by the relay's name.
  SETTING_KINDS = { "encounters" => :encounters, "variable" => :v, "switch" => :s }

  # The vehicles by the relay's name, at their number.
  VEHICLE_NAMES = %w(boat ship airship)

  # Reads a generated table's rows.
  #
  # @param table [String] The relay's table.
  # @return [Array<Hash>] The rows.
  def self.rows(table)
    JSON.parse(File.read(File.join(FOLDER, "#{table}.json"), :encoding => "UTF-8"))["rows"]
  end

  # Reads a mark back: its kind as a Symbol.
  #
  # @param mark [Array] Such as ["v", 1001, 6].
  # @return [Array] Such as [:v, 1001, 6].
  def self.mark(mark)
    [mark[0].to_sym] + mark[1..-1]
  end

  # Reads a row's place: site, part, step, side and marks.
  #
  # @param row [Hash] The row.
  # @return [Array] The place's values in the structs' order.
  def self.place(row)
    [row["site"], row["part"], row["step"], row["side"] && row["side"].to_sym, row["marks"].map { |each| mark(each) }]
  end

  PARTS = rows("parts").map { |row| Part.new(row["id"], row["name"], row["ending"].map { |each| mark(each) }, row["gate"]) }
  JOINS = rows("joins").map { |row| Join.new(row["actor"], row["persona"], *place(row), row["gate"], row["rule"].to_sym, row["index"], row["ran"]) }
  REMOVALS = rows("removals").map { |row| Removal.new(row["actor"], row["persona"], *place(row), row["first"], row["index"]) }
  KEY_ITEMS = rows("key_items").map { |row| KeyItem.new(row["item"], row["amount"], *place(row), row["ran"]) }
  CHESTS = rows("chests").map do |row|
    map, event, letter = row["key"][2..-1].split(".")
    Chest.new([map.to_i, event.to_i, letter], row["items"], row["part"], row["step"], row["flags"])
  end
  REWARDS = rows("rewards").map { |row| Reward.new(REWARD_KINDS.fetch(row["kind"]), row["id"], row["amount"], *place(row), row["ran"]) }
  LESSONS = rows("lessons").map { |row| Lesson.new(row["actor"], row["skill"], *place(row), row["ran"]) }
  CLASS_LEVELS = rows("class_levels").map { |row| ClassLevel.new(row["actor"], row["class"], row["level"], *place(row), row["ran"]) }
  ACTOR_CHANGES = rows("actor_changes").map do |row|
    ActorChange.new(row["actor"], row["calls"].map { |name, ids, once| [name.to_sym, ids, once] }, row["gate"], *place(row), row["ran"])
  end
  SETTINGS = rows("settings").map { |row| Setting.new(SETTING_KINDS.fetch(row["kind"]), row["id"], row["value"], *place(row), row["ran"]) }
  VEHICLES = rows("vehicles").map { |row| Vehicle.new(VEHICLE_NAMES.index(row["vehicle"]), *place(row), row["ran"]) }

  MAKINA = rows("makina").map { |row| Makina.new(row["item"], row["level"], row["site"]) }
  PRIZE_SWITCHES = []
  TAKEN_ITEMS = []
end
