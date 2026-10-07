#----------------------------------------------------------------
#  story_rewards.rb
#
#  Changelog:
#      Paulinchen  2026-10-06: Created
#
#----------------------------------------------------------------

# Writes coop_story_rewards.rbx from a game's Data folder: the skills Luka learns and the companions
# who join in the game's events, the items the story's events give, and the events that reward the
# side the player chose, Alice's or Ilias's, differently.
#
# Runs on Ruby 3: ruby story_rewards.rb "<game folder>\Data" [output file].

# The switches that tell the side the player chose: Alice (4) and Ilias (5).
SIDE_SWITCHES = { 4 => :alice, 5 => :ilias }

# The actor whose skills count, Luka.
HERO = 1

# Common events of the Great Decision and its resets, which choose a side anew in the Final Chapter.
FINAL_CHAPTER = /Great Decision/

# First common event of the Chaos route, a part of the Final Chapter.
CHAOS_ROUTE_EVENTS = 9000

# Variables of the routes after the Great Decision; a list that reads one plays in the Final Chapter.
ROUTE_VARIABLES = [1141, 1142, 1143]

# Scripts that bring a companion into the party.
RECRUIT_SCRIPT = /\A\s*(?:add_actor_ex|add_actor_ex_nc|add_stand_actor)\((\d+)\)/

# Event commands that give items: items (126), weapons (127) and armors (128), by their letter.
ITEM_CODES = { 126 => "i", 127 => "w", 128 => "a" }

# Event commands a chest gives with: gold (125) and the items of ITEM_CODES.
CHEST_CODES = [125] + ITEM_CODES.keys

# Switches that bring a companion into the party when turned on, the companion's id plus 1000.
ACTOR_SWITCHES = 1001..2000

# Event commands that make a page more than a chest: switches, variables, party changes, battles
# and scripts.
STORY_CODES = [121, 122, 129, 301, 355]

# The variables of the story's progress: the main story (1001) and the three routes (1141-1143).
PROGRESS_VARIABLES = [1001, 1141, 1142, 1143]

# Names of switches and variables the game uses as scratch while an event runs.
TEMPORARY_NAMES = /general|temp|system only|汎用|一時/i

# Switches that are each player's own in coop_story.rbx (SIDE_SWITCHES, PERSONAL_SWITCHES with the
# warp ban 100, AWAKENING_SWITCHES to AWAKENING_LAST), which tell nothing of how far the story is.
# A test checks that both lists agree.
PERSONAL_SWITCHES = [4, 5, 95, 100, 445..447, 502, 1001..2000, 6000..6999]

# First variable that holds a companion's affection, one per actor of the database.
AFFECTION_VARIABLES = 3000

# Lists the variables that are each player's own in coop_story.rbx (PERSONAL_VARIABLES, then the
# affection variables up to one per actor). A test checks that both lists agree.
#
# @param actors [Integer] How many actors the database holds.
# @return [Array<Range, Integer>] The variables.
def personal_variables(actors)
  [21..23, 56, 1002, 2000...(AFFECTION_VARIABLES + actors)]
end

# The file written when the command line names none.
OUTPUT = File.expand_path("../Multiplayer/Scripts/coop_story_rewards.rbx", __dir__)

# Data classes of the game that the files name, loaded without their own code.
class Table; def self._load(*) new end; end
class Color; def self._load(*) new end; end
class Tone; def self._load(*) new end; end

# Defines a class the data names, nested as its name says.
#
# @param path [String] The class's full name.
def define_path(path)
  scope = Object
  path.split("::").each do |part|
    scope = scope.const_defined?(part, false) ? scope.const_get(part) : scope.const_set(part, Class.new)
  end
end

# Loads a data file, defining each class it names on the way.
#
# @param path [String] The file.
# @return [Object] Its contents.
def load_data(path)
  Marshal.load(File.binread(path))
rescue ArgumentError => e
  raise unless e.message =~ /undefined class\/module (\S+)/

  define_path($1.sub(/::$/, ""))
  retry
end

# Reads an instance variable of a data object.
#
# @param object [Object] The object.
# @param name [Symbol] The variable without its @.
# @return [Object] Its value.
def iv(object, name)
  object.instance_variable_get("@#{name}")
end

# Reports whether a page only gives items or gold and shuts itself, as a chest does, whose items
# each player loots in their own game.
#
# @param list [Array] The page's commands.
# @return [Boolean] Whether it does.
def chest?(list)
  codes = list.map { |command| iv(command, :code) }
  codes.include?(123) && !(codes & CHEST_CODES).empty? && (codes & STORY_CODES).empty?
end

# Reports whether a list moves the story's progress on, which makes the items it gives the story's.
#
# @param list [Array] The commands.
# @return [Boolean] Whether it does.
def progress?(list)
  list.any? do |command|
    params = iv(command, :parameters)
    iv(command, :code) == 122 && PROGRESS_VARIABLES.any? { |id| (params[0]..params[1]).include?(id) }
  end
end

# The side a page's conditions ask for, or the side its map is played on.
#
# @param page [Object] The page.
# @param map_side [Symbol, nil] The side the map's name says, such as "Middle Chapter Final Battle (Alice)".
# @return [Symbol, nil] :alice, :ilias or nil.
def page_side(page, map_side)
  condition = iv(page, :condition)
  [[:switch1_valid, :switch1_id], [:switch2_valid, :switch2_id]].each do |valid, id|
    return SIDE_SWITCHES[iv(condition, id)] if iv(condition, valid) && SIDE_SWITCHES.key?(iv(condition, id))
  end
  map_side
end

# The side a map's name says it is played on.
#
# @param name [String] The map's name.
# @return [Symbol, nil] :alice, :ilias or nil.
def map_side(name)
  return nil unless name =~ /(?:\(\s*|-\s+)(Alice|Ilias)\s*\)?\s*\z/

  Regexp.last_match(1) == "Alice" ? :alice : :ilias
end

# Collects the rewards of a list of commands, each with the side of the branch it stands in, and
# tells where the list chooses a side.
#
# @param list [Array] The commands.
# @param side [Symbol, nil] The side of the whole list, as its page asks for or it chooses.
# @yield [kind, id, amount, side] Each reward: :skill, :actor (by a party change, a script or the
#   companion's switch) or the item's letter; :choice with the side chosen.
def rewards(list, side)
  branches = {}
  list.each do |command|
    code = iv(command, :code)
    indent = iv(command, :indent)
    params = iv(command, :parameters)
    branches.delete_if { |level, _| level >= indent } unless [411, 412].include?(code)
    if code == 111 && params[0] == 0 && SIDE_SWITCHES.key?(params[1])
      chosen = SIDE_SWITCHES[params[1]]
      branches[indent] = params[2] == 0 ? chosen : (SIDE_SWITCHES.values - [chosen]).first
      next
    end
    if code == 411
      branches[indent] = (SIDE_SWITCHES.values - [branches[indent]]).first if branches[indent]
      next
    end
    current = branches.values.last || side
    if code == 121 && params[2] == 0
      chosen = SIDE_SWITCHES.keys.find { |id| (params[0]..params[1]).include?(id) }
      yield :choice, 0, 0, SIDE_SWITCHES[chosen] if chosen
      (params[0]..params[1]).each { |id| yield :actor, id - 1000, 1, current if ACTOR_SWITCHES.include?(id) && id - 1000 != HERO }
    end

    case code
    when 318
      yield :skill, params[3], 1, current if params[0] == 0 && params[1] == HERO && params[2] == 0
    when 129
      yield :actor, params[0], 1, current if params[1] == 0
    when 355, 655
      yield :actor, Regexp.last_match(1).to_i, 1, current if params[0].to_s =~ RECRUIT_SCRIPT
    when *ITEM_CODES.keys
      yield ITEM_CODES[code], params[0], params[3], current if params[1] == 0 && params[2] == 0
    end
  end
end

# Reports whether a switch or variable is scratch or the player's own, which tells nothing of how
# far the story is.
#
# @param kind [Symbol] :s for a switch, :v for a variable.
# @param id [Integer] Its id.
# @param names [Array<String>] The names of the switches or variables.
# @return [Boolean] Whether it is.
def unmarked?(kind, id, names)
  return true if names[id].to_s =~ TEMPORARY_NAMES

  ranges = kind == :s ? PERSONAL_SWITCHES : $personal_variables
  ranges.any? { |range| range === id }
end

# Finds what a list leaves in the story once it ran: the switches it leaves on, the variables it
# leaves at a number and the self switches it turns on, each as its last command left it.
#
# @param list [Array] The commands.
# @param self_key [Array, nil] The map and event whose self switches the list sets, nil for a
#   common event.
# @param names [Array<Array<String>>] The names of the switches and of the variables.
# @return [Array<Array>] Each mark: [:s, id], [:v, id, value] or [:ss, map, event, letter].
def marks(list, self_key, names)
  switches = {}
  variables = {}
  self_switches = {}
  list.each do |command|
    params = iv(command, :parameters)
    case iv(command, :code)
    when 121 then (params[0]..params[1]).each { |id| switches[id] = params[2] == 0 }
    when 122
      (params[0]..params[1]).each { |id| variables[id] = params[2] == 0 && params[3] == 0 ? params[4] : nil }
    when 123 then self_switches[params[0]] = params[1] == 0 if self_key
    end
  end
  progress = variables.select { |id, value| value.is_a?(Integer) && value > 0 && !unmarked?(:v, id, names[1]) }.sort.map { |id, value| [:v, id, value] }
  # The story's variables come first, since the other side's events set them too, where a switch
  # may be one side's alone.
  return progress unless progress.empty?

  switches.select { |id, on| on && !unmarked?(:s, id, names[0]) }.keys.sort.map { |id| [:s, id] } +
    self_switches.select { |_, on| on }.keys.sort.map { |letter| [:ss, self_key[0], self_key[1], letter] }
end

# The side a list chooses, as the Iliasville scene does: the one side switch it turns on.
#
# @param list [Array] The commands.
# @return [Symbol, nil] :alice, :ilias, or nil for a list that chooses none or both.
def chosen_side(list)
  chosen = list.select { |command| iv(command, :code) == 121 && iv(command, :parameters)[2] == 0 }.flat_map do |command|
    params = iv(command, :parameters)
    SIDE_SWITCHES.keys.select { |id| (params[0]..params[1]).include?(id) }
  end.uniq
  chosen.size == 1 ? SIDE_SWITCHES[chosen.first] : nil
end

# Reports whether a list plays in the Final Chapter: its page or one of its branches reads a route's
# progress.
#
# @param list [Array] The commands.
# @param page [Object, nil] The list's page, nil for a common event.
# @return [Boolean] Whether it does.
def final_chapter?(list, page)
  if page
    condition = iv(page, :condition)
    return true if iv(condition, :variable_valid) && ROUTE_VARIABLES.include?(iv(condition, :variable_id))
  end
  list.any? do |command|
    params = iv(command, :parameters)
    iv(command, :code) == 111 && params[0] == 1 && ROUTE_VARIABLES.include?(params[1])
  end
end

# A test loads this file for its lists alone.
return unless __FILE__ == $PROGRAM_NAME

data = ARGV[0] or abort("usage: ruby story_rewards.rb \"<game folder>\\Data\" [output file]")
output = ARGV[1] || OUTPUT

system = load_data(File.join(data, "System.rvdata2"))
names = [iv(system, :switches), iv(system, :variables)]
$personal_variables = personal_variables(load_data(File.join(data, "Actors.rvdata2")).size)
# The self switch of every chest: map, event and letter.
chests = []
# Each list: its event, its commands, its side, the map and event of its self switches, and whether
# it plays in the Final Chapter.
lists = []
load_data(File.join(data, "CommonEvents.rvdata2")).each_with_index do |common, index|
  next unless common

  list = iv(common, :list) || []
  final = iv(common, :name).to_s =~ FINAL_CHAPTER || index >= CHAOS_ROUTE_EVENTS || final_chapter?(list, nil)
  lists << ["ce:#{index}", list, nil, nil, final ? true : false]
end
infos = load_data(File.join(data, "MapInfos.rvdata2"))
infos.keys.sort.each do |map_id|
  path = File.join(data, format("Map%03d.rvdata2", map_id))
  next unless File.exist?(path)

  side = map_side(iv(infos[map_id], :name).to_s.force_encoding("UTF-8"))
  iv(load_data(path), :events).each do |event_id, event|
    iv(event, :pages).each do |page|
      list = iv(page, :list) || []
      if chest?(list)
        letter = list.map { |command| iv(command, :parameters) if iv(command, :code) == 123 && iv(command, :parameters)[1] == 0 }.compact.first
        chests |= [[map_id, event_id, letter[0]]] if letter
        next
      end

      lists << ["map:#{map_id}:#{event_id}", list, page_side(page, side), [map_id, event_id], final_chapter?(list, page)]
    end
  end
end

skills = []
actors = []
items = Hash.new(0)
# The skills and companions some event gives without a side before the Great Decision.
unsided = { :skills => [], :actors => [] }
# The skills and companions the Final Chapter's events give.
final_rewards = { :skills => [], :actors => [] }
groups = Hash.new do |hash, key|
  hash[key] = { :alice => { :skills => [], :actors => [] }, :ilias => { :skills => [], :actors => [] }, :choice => false, :marks => [] }
end
lists.each do |key, list, side, self_key, final|
  story = progress?(list)
  side ||= chosen_side(list)
  sided = !side.nil?
  # A list gives an item once, though it may hold one branch for each stage of the story.
  given = Hash.new(0)
  rewards(list, side) do |kind, id, amount, current|
    case kind
    when :choice then groups[key][:choice] = true unless final
    when :skill then skills |= [id]
    when :actor then actors |= [id]
    else given["#{kind}#{id}"] = [given["#{kind}#{id}"], amount].max if story
    end
    next unless [:skill, :actor].include?(kind)

    reward_kind = kind == :skill ? :skills : :actors
    next final_rewards[reward_kind] |= [id] if final
    next unsided[reward_kind] |= [id] unless current

    sided = true
    groups[key][current][reward_kind] |= [id]
  end
  given.each { |item, amount| items[item] += amount }
  list_marks = sided && !final ? marks(list, self_key, names) : []
  groups[key][:marks] << list_marks unless list_marks.empty? || groups[key][:marks].include?(list_marks)
end

# A group only counts where its two sides differ.
groups.reject! { |_, group| group[:alice] == group[:ilias] }
sided_rewards = [:skills, :actors].map do |kind|
  groups.values.flat_map { |group| group[:alice][kind] + group[:ilias][kind] }.uniq - unsided[kind]
end
route_rewards = [:skills, :actors].each_with_index.map { |kind, index| sided_rewards[index] & final_rewards[kind] }

table = lambda do |ids|
  ids.sort.each_slice(16).map { |row| "    " + row.join(", ") }.join(",\n")
end
group_rows = groups.keys.sort.map do |key|
  group = groups[key]
  "    # #{key}\n    { :alice => { :skills => #{group[:alice][:skills].sort.inspect}, :actors => #{group[:alice][:actors].sort.inspect} },\n" \
  "      :ilias => { :skills => #{group[:ilias][:skills].sort.inspect}, :actors => #{group[:ilias][:actors].sort.inspect} },\n" \
  "      :choice => #{group[:choice]}, :marks => #{group[:marks].inspect} }"
end
chest_rows = chests.sort_by { |key| [key[0], key[1], key[2]] }.map(&:inspect).each_slice(8).map { |row| "    " + row.join(", ") }.join(",\n")
item_rows = items.keys.sort.map { |key| "#{key.inspect} => #{items[key]}" }.each_slice(8).map { |row| "    " + row.join(", ") }.join(",\n")

File.write(output, <<~RUBY)
  # <auto-generated>
  # Written by GameScript/Tools/story_rewards.rb from the game's data; run it again rather than
  # editing this file.
  # </auto-generated>

  # The rewards of the game's events, which coop_story.rbx gives a member who catches up with the
  # leader's story: what their own game would have given them on the way.
  module MGQ_MpCoopStoryRewards
    # The skills Luka learns in events.
    SKILLS = [
  #{table.call(skills)}
    ]

    # The companions who join in events.
    ACTORS = [
  #{table.call(actors)}
    ]

    # How many of each item the events that move the story on give at most, by its letter and id.
    ITEMS = {
  #{item_rows}
    }

    # The self switch of every chest: map, event and letter. Chests are each player's own, so a member
    # who catches up keeps their own of these.
    CHESTS = [
  #{chest_rows}
    ]

    # The skills and companions only the events where the sides differ give before the Great
    # Decision, which come with those events alone.
    SIDED = {
      :skills => #{sided_rewards[0].sort.inspect},
      :actors => #{sided_rewards[1].sort.inspect}
    }

    # The skills and companions of SIDED that the Final Chapter's events give too, such as the Great
    # Decision, which come as the leader holds them once the story is past it.
    ROUTE = {
      :skills => #{route_rewards[0].sort.inspect},
      :actors => #{route_rewards[1].sort.inspect}
    }

    # The events that give each side other skills or companions, before the Great Decision: each
    # side's rewards, whether the event is where the player chooses a side, and what each of its
    # pages leaves in the story once it ran ([:s, switch] on, [:v, variable, at least],
    # [:ss, map, event, letter] on).
    GROUPS = [
  #{group_rows.join(",\n")}
    ]
  end
RUBY
puts "wrote #{output}: #{skills.size} skills, #{actors.size} companions, #{items.size} items, #{chests.size} chests, #{groups.size} groups"
