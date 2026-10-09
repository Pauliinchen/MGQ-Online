#----------------------------------------------------------------
#  raid_data.rb
#
#  Changelog:
#      Paulinchen  2026-10-09: Matched the names of scratch switches and variables as whole words, so a story value named after a temple keeps its marks
#                            - Created
#
#----------------------------------------------------------------

# Writes world_catchup_data.rbx from a game's Data folder: what a Raid World needs to carry a player
# who falls behind along with the world's story. That is the story's parts with their level gates,
# every story join of a companion with the level that brings it, the companions the story takes
# away, the key items the story gives, the chests that hold them, and the skills and items the
# story gives, each at its place in the story.
#
# Runs on Ruby 3: ruby raid_data.rb "<game folder>\Data" [output file].

require_relative "story_rewards"

# Reads the game's events for the story's joins, removals and rewards, and places each in the story.
class RaidData
  # A part of the story: its id as the relay names it (Relay/core/story.js), its name, the story
  # values that hold right before its ending starts, and its level gate.
  Part = Struct.new(:id, :name, :ending, :gate)

  # The story's parts in their order, each with the values right before its ending and its gate,
  # the cap of the last Level Cap milestone in the part.
  #
  # The relay ends Part 1 at 1001 = 19 and Part 2 at 1001 = 34, and Part 3 once a route's variable
  # is above 0; each ending below starts before that. Part 2's optional Black Alice (cap 65) is no
  # gate.
  PARTS = [
    Part.new("1", "Part 1", [[:v, 1001, 18], [:v, 1032, 5]], 25),
    Part.new("2", "Part 2", [[:v, 1001, 33], [:v, 1075, 14]], 55),
    Part.new("3", "Part 3", [[:v, 1001, 39], [:s, 2485], [:s, 2486], [:s, 2487]], 65),
    Part.new("ad", "Angelic Dominion", [[:v, 1141, 73]], 120),
    Part.new("mr", "Monster Realm", [[:v, 1142, 81]], 120),
    Part.new("chaos", "Chaos", [[:v, 1143, 24], [:v, 1348, 5]], 300)
  ]

  # The rank of each part in the story's order. The two routes share one, since a Raid World plays
  # them in either order before the Chaos route.
  PART_RANK = { "1" => 0, "2" => 1, "3" => 2, "ad" => 3, "mr" => 3, "chaos" => 4 }

  # The variable of the main story's progress.
  MAIN = 1001

  # The routes' progress variables, by part.
  ROUTE_VARIABLES = { "chaos" => 1143, "mr" => 1142, "ad" => 1141 }

  # The main story's progress where Part 2 and Part 3 begin, as the relay has it.
  PART_TWO = 19
  PART_THREE = 34

  # The highest gate a join gets.
  MAX_GATE = 300

  # "Overall Cycles": 0 on the first playthrough, which a Raid World always plays.
  CYCLES = 912

  # The variable the Great Decision's choice writes, and the route each value starts: the Dark
  # Goddess's (the Angelic Dominion) and Goddess Ilias's (the Monster Realm). The third way sets the
  # Chaos route's variable itself.
  DECISION_CHOICE = 1002
  DECISION_ROUTES = { 111 => "ad", 112 => "mr" }

  # The common event of the Great Decision.
  DECISION_EVENT = 380

  # The side switches, Alice's (4) and Ilias's (5).
  SIDES = { 4 => :alice, 5 => :ilias }

  # Common events that are no story: the load fix-ups (114), the Reaper's menus and resets (150,
  # 153-155, 265-268), and the defeat events (3000-3999), which restore the party for a retry.
  SKIPPED_COMMON_EVENTS = [114, 150, 153, 154, 155, 265, 266, 267, 268] + (3000..3999).to_a

  # Maps that are no story: the Pocket Castle's persona swaps (271, 273, 277) and the debug island
  # (189).
  SKIPPED_MAPS = [189, 271, 273, 277]

  # The map tree's roots whose maps play in one part: the Chaos route's prologue and its world, and
  # the two routes' worlds.
  ROOT_PARTS = { 438 => "chaos", 1287 => "chaos", 1193 => "ad", 1001 => "mr" }

  # The trigger of a page the player starts by talking to its event, which may never happen.
  TALK_TRIGGER = 0

  # The map tree's roots of side content outside the story's order: the Labyrinth of Chaos and the
  # collaboration's world. Their places have no part, and the party changes of their floors are no
  # story removals.
  SIDE_ROOTS = [644, 920]

  # The step the Chaos route's free order starts at, after the Pocket Castle's revival (CE 9141 at
  # 1143 = 20). A place on the Chaos route that tells no step of its own counts from there, or from
  # the route's first step on the maps of its prologue.
  CHAOS_FREE_ORDER = 21

  # The map tree's root of the Chaos route's prologue.
  CHAOS_PROLOGUE = 438

  # The step from which the Chaos route's ending is behind, with all of its milestones.
  CHAOS_ENDED = 25

  # What the Chaos route's free order holds once its progress reaches a step: the field's events
  # move it to 23 (map 1287, event 210) and to 24 (event 233) only once these hold.
  CHAOS_GATES = {
    23 => [[:v, 1307, 3], [:v, 1308, 13], [:v, 1311, 5], [:v, 1312, 6]],
    24 => [[:v, 1311, 6], [:v, 1312, 7], [:v, 1333, 3], [:v, 1340, 3], [:v, 1344, 3], [:v, 1345, 5], [:v, 1347, 3],
           [:v, 1353, 15], [:v, 1362, 21], [:v, 1373, 13]]
  }

  # The story variables of the two routes and of the Chaos route, which the route return (CE 154)
  # clears.
  ROUTE_STORY_VARIABLES = 1144..1200
  CHAOS_STORY_VARIABLES = 1301..1500

  # Places the events' own commands do not tell, by site or by map event: the part, the step and
  # the marks that hold once the event ran. CE 379 is the throne of Part 3's ending. The camps of
  # Part 1 and Part 2 are entered by a transfer whose event tells their place: the camp common
  # events 301, 302 and 304 and the field's events 254, 262 and 270.
  PLACES = {
    "ce:379" => ["3", 39, [[:v, 1001, 39], [:s, 2487]]],
    "ce:9001" => ["chaos", 17, [[:v, 1143, 18]]],
    "ce:9141" => ["chaos", 20, [[:v, 1143, 21]]],
    "map:1187:29" => ["chaos", 16, [[:v, 1143, 16]]],
    "map:1890:12" => ["mr", 1, [[:v, 1142, 1]]],
    "map:406:7" => ["1", 8, [[:v, 1001, 8]]],
    "map:523:7" => ["1", 13, [[:v, 1019, 2]]],
    "map:604:7" => ["1", 17, [[:s, 2087]]],
    "map:711:7" => ["2", 23, [[:ss, 2, 254, "A"]]],
    "map:736:7" => ["2", 25, [[:ss, 2, 262, "A"]]],
    "map:741:7" => ["2", 33, [[:ss, 2, 270, "A"]]]
  }

  # The Level Cap milestones a give-back's gate is read from: each one's part, its cap and the story
  # values that tell it is beaten (any one list, all of its marks). The optional Black Alice of
  # Part 2 is left out, and the route clears count for the Chaos route, which follows them. The
  # Chaos route's finale comes after World Breaker and Judgement, so its start (1348 = 5) tells
  # them beaten too.
  MILESTONES = [
    ["1", 10, [[[:v, 1003, 8]]]], ["1", 15, [[[:v, 1011, 4]]]], ["1", 18, [[[:v, 1019, 6]]]],
    ["1", 20, [[[:v, 1021, 2]]]], ["1", 25, [[[:v, 1032, 7]]]],
    ["2", 30, [[[:v, 1052, 6]]]], ["2", 35, [[[:v, 1063, 13]]]], ["2", 40, [[[:v, 1001, 28]]]],
    ["2", 43, [[[:v, 1070, 3]]]], ["2", 45, [[[:v, 1071, 3]]]], ["2", 47, [[[:v, 1072, 3]]]],
    ["2", 50, [[[:v, 1073, 3]]]], ["2", 55, [[[:v, 1001, 34]]]],
    ["3", 60, [[[:v, 1001, 37]]]], ["3", 61, [[[:s, 2485]]]], ["3", 62, [[[:s, 2486]]]],
    ["3", 63, [[[:s, 2487]]]], ["3", 65, [[[:v, 1141, 1]], [[:v, 1142, 1]], [[:v, 1143, 1]]]],
    ["ad", 67, [[[:v, 1141, 4]]]], ["ad", 70, [[[:v, 1141, 18]]]], ["ad", 78, [[[:v, 1141, 30]]]],
    ["ad", 80, [[[:v, 1141, 38]]]], ["ad", 83, [[[:v, 1141, 43]]]], ["ad", 85, [[[:v, 1173, 8]]]],
    ["ad", 90, [[[:v, 1151, 6]]]], ["ad", 95, [[[:v, 1141, 58]]]], ["ad", 100, [[[:v, 1141, 67]]]],
    ["ad", 105, [[[:v, 1141, 73]]]], ["ad", 120, [[[:s, 7096]]]],
    ["mr", 67, [[[:v, 1142, 8]]]], ["mr", 70, [[[:s, 2594], [:v, 1142, 25]]]], ["mr", 75, [[[:v, 1142, 33]]]],
    ["mr", 80, [[[:v, 1142, 34]]]], ["mr", 83, [[[:v, 1142, 36]]]], ["mr", 85, [[[:v, 1169, 23]]]],
    ["mr", 90, [[[:v, 1142, 47]]]], ["mr", 95, [[[:v, 1142, 60]]]], ["mr", 100, [[[:v, 1142, 71]]]],
    ["mr", 105, [[[:v, 1142, 81]]]], ["mr", 120, [[[:s, 7097]]]],
    ["chaos", 125, [[[:v, 1143, 4]]]], ["chaos", 130, [[[:v, 1143, 18]]]],
    ["chaos", 135, [[[:v, 1319, 7]], [[:v, 1301, 8]], [[:v, 1302, 5]]]], ["chaos", 140, [[[:v, 1302, 7]], [[:v, 1304, 5]]]],
    ["chaos", 145, [[[:v, 1307, 3]]]], ["chaos", 147, [[[:v, 1305, 6]]]], ["chaos", 151, [[[:v, 1308, 8]]]],
    ["chaos", 153, [[[:v, 1308, 11]]]], ["chaos", 155, [[[:v, 1308, 13]]]],
    ["chaos", 160, [[[:s, 3030], [:s, 3031], [:s, 3032], [:s, 3033]]]], ["chaos", 168, [[[:v, 1312, 3]]]],
    ["chaos", 175, [[[:v, 1313, 5]]]], ["chaos", 180, [[[:v, 1315, 6]]]], ["chaos", 185, [[[:v, 1316, 11]]]],
    ["chaos", 190, [[[:v, 1314, 3]]]], ["chaos", 195, [[[:v, 1317, 3]]]], ["chaos", 203, [[[:v, 1318, 10]]]],
    ["chaos", 210, [[[:v, 1328, 6], [:v, 1331, 5], [:v, 1329, 4], [:v, 1332, 5], [:v, 1326, 4]]]],
    ["chaos", 213, [[[:v, 1325, 11]]]], ["chaos", 215, [[[:v, 1325, 12]]]], ["chaos", 220, [[[:v, 1334, 4]]]],
    ["chaos", 225, [[[:v, 1373, 13]]]], ["chaos", 228, [[[:v, 1335, 5]]]], ["chaos", 230, [[[:v, 1336, 5]]]],
    ["chaos", 235, [[[:v, 1338, 4]]]], ["chaos", 240, [[[:v, 1339, 5]]]], ["chaos", 250, [[[:v, 1342, 5]]]],
    ["chaos", 255, [[[:v, 1343, 3]]]], ["chaos", 260, [[[:v, 1345, 5]]]],
    ["chaos", 275, [[[:s, 3079], [:s, 3078], [:s, 3077]]]], ["chaos", 285, [[[:s, 3080], [:s, 3081]], [[:v, 1348, 5]]]],
    ["chaos", 300, [[[:s, 7039]]]]
  ]

  # Scripts that bring a companion into the party for good, and those that bring them along for a
  # while only.
  JOIN_SCRIPTS = %w[add_actor_ex_nc add_actor_ex add_stand_actor set_actors]
  TEMP_SCRIPTS = %w[add_temp_actors set_temp_actors]

  # A script call of the party or of a level, with its whole numbers.
  PARTY_CALL = /\b(add_actor_ex_nc|add_actor_ex|add_stand_actor|set_actors|add_temp_actors|set_temp_actors|delete_actor_ex|level_adjust)\(([\d,\s]*)\)/

  # The note tags of a sub-persona's main persona and of an actor's start level.
  SUB_PERSONA_TAG = /<副人格(?::|：)ID\s*=\s*(\d+)>/
  START_LEVEL_TAG = /<初期レベル\s?(\d+)>/

  # Item type 2, which key items have, and the description that tells them from the other items of
  # that type: job items, Makina, materials, CDs and medals.
  KEY_ITEM_TYPE = 2
  KEY_ITEM_TAG = /\A\[Key Item\]/

  # The story's range of variables, and the first switch that tells the story's place.
  STORY_VARIABLES = 1001..1999
  FIRST_STORY_SWITCH = 2001

  # Names of switches and variables the game uses as scratch while an event runs, as whole words.
  # story_rewards.rb's TEMPORARY_NAMES matches "Temple", which names real story values such as the
  # Silver Orb's "Northern Undersea Temple Event" (1068).
  SCRATCH_NAMES = /\b(general|temp|temporary|system only)\b|汎用|一時/i

  # The switches that bring a companion into the party, which a page that needs one asks for the
  # player's own roster.
  ACTOR_SWITCH_RANGE = 1001..2000

  # A list of commands of the game's events: its site, its commands, its page, its map and event or
  # common event, and its map's root in the map tree.
  Site = Struct.new(:key, :list, :page, :map, :event, :common, :root)

  # A place in the story: its part and step (nil where nothing tells it), the marks its page and
  # branches need, the marks that hold while the command runs, the marks that hold once its event
  # ran, the side it asks for, and whether those marks tell that the event ran (see ran?).
  Place = Struct.new(:part, :step, :needs, :at, :marks, :side, :ran)

  # A join of a companion: its main persona, the persona added, the site, the command's index, its
  # place, its level floor, its gate, and its rule: first how it joins (:join, or :temp for a while
  # only), then the rule that gave its gate (:floor, :start, :cap or :kept, see give_gates).
  Join = Struct.new(:actor, :persona, :site, :index, :place, :floor, :gate, :rule)

  # A change of the party or a level a list makes: its kind (:join, :temp, :delete or :floor), the
  # actor, the command's index, and the level of a floor.
  Change = Struct.new(:kind, :actor, :index, :level)

  attr_reader :joins, :removals, :key_items, :chests, :rewards, :floors, :actors, :sites, :map_names

  # Reads a game's Data folder.
  #
  # @param data [String] The Data folder.
  def initialize(data)
    @data = data
    system = load_data(File.join(data, "System.rvdata2"))
    @names = [iv(system, :switches), iv(system, :variables)]
    $personal_variables = personal_variables(load_data(File.join(data, "Actors.rvdata2")).size)
    @paths = {}
    @places = {}
    read_actors
    read_items
    read_sites
    @sites_by_map = @sites.select(&:map).group_by(&:map)
    @map_steps = {}
    @callers = Hash.new { |hash, key| hash[key] = [] }
    @entries = Hash.new { |hash, key| hash[key] = [] }
    @sites.each { |site| note_calls(site) }
    @area = Hash.new { |hash, key| hash[key] = Hash.new { |values, value| values[value] = {} } }
    @sites.each { |site| note_areas(site) }
  end

  # Reads the actors: each one's main persona and start level, from the game's analysed cache where
  # it has one, as the game does, else from the note tags.
  def read_actors
    @actors = {}
    load_data(File.join(@data, "Actors.rvdata2")).each_with_index do |actor, id|
      next unless actor

      note = text(iv(actor, :note))
      main = note[SUB_PERSONA_TAG, 1]
      start = note[START_LEVEL_TAG, 1]
      @actors[id] = { :main => main ? main.to_i : id, :start => start ? start.to_i : iv(actor, :initial_level), :name => text(iv(actor, :name)) }
    end
    cache = File.join(@data, "DataEx.rvdata2")
    return unless File.exist?(cache)

    (load_data(cache)[:actors] || []).each_with_index do |actor, id|
      next unless actor && @actors[id]

      extra = iv(actor, :data_ex) || {}
      @actors[id][:main] = extra[:original_persona_id] if extra[:original_persona_id]
      @actors[id][:start] = iv(actor, :initial_level)
    end
  end

  # Reads which items are key items.
  def read_items
    @key_item_ids = []
    load_data(File.join(@data, "Items.rvdata2")).each_with_index do |item, id|
      @key_item_ids << id if item && iv(item, :itype_id) == KEY_ITEM_TYPE && text(iv(item, :description)) =~ KEY_ITEM_TAG
    end
  end

  # Reads every list of commands of the common events, the maps' event pages and the troops' pages,
  # leaving out those that are no story.
  def read_sites
    @sites = []
    load_data(File.join(@data, "CommonEvents.rvdata2")).each_with_index do |common, id|
      next unless common && !SKIPPED_COMMON_EVENTS.include?(id)

      @sites << Site.new("ce:#{id}", iv(common, :list) || [], nil, nil, nil, id, nil)
    end
    roots = map_roots
    map_folders(@data).each do |folder, first_id|
      load_data(File.join(folder, "MapInfos.rvdata2")).keys.sort.each do |number|
        path = File.join(folder, format("Map%03d.rvdata2", number))
        map_id = first_id + number
        next unless File.exist?(path) && !SKIPPED_MAPS.include?(map_id)

        iv(load_data(path), :events).sort.each do |event_id, event|
          iv(event, :pages).each_with_index do |page, index|
            @sites << Site.new("map:#{map_id}:#{event_id}:#{index + 1}", iv(page, :list) || [], page, map_id, event_id, nil, roots[map_id])
          end
        end
      end
    end
    load_data(File.join(@data, "Troops.rvdata2")).each_with_index do |troop, id|
      next unless troop

      (iv(troop, :pages) || []).each_with_index do |page, index|
        @sites << Site.new("troop:#{id}:#{index + 1}", iv(page, :list) || [], nil, nil, nil, nil, nil)
      end
    end
  end

  # Finds each map's root in the map tree, from the folders' own trees, and notes the maps' names.
  #
  # @return [Hash{Integer => Integer}] The root by map.
  def map_roots
    parents = {}
    @map_names = {}
    map_folders(@data).each do |folder, first_id|
      load_data(File.join(folder, "MapInfos.rvdata2")).each do |number, info|
        parent = iv(info, :parent_id).to_i
        parents[first_id + number] = parent > 0 ? first_id + parent : nil
        @map_names[first_id + number] = text(iv(info, :name))
      end
    end
    @parents = parents
    roots = {}
    parents.each_key do |map_id|
      root = map_id
      root = parents[root] while parents[root]
      roots[map_id] = root
    end
    roots
  end

  # Reads a text of the game's data as UTF-8.
  #
  # @param value [String, nil] The text.
  # @return [String] It in UTF-8.
  def text(value)
    value.to_s.dup.force_encoding("UTF-8")
  end

  # Notes which lists call each common event and which lists transfer into each map.
  #
  # @param site [Site] The list.
  def note_calls(site)
    site.list.each_with_index do |command, index|
      params = iv(command, :parameters)
      case iv(command, :code)
      when 117 then @callers[params[0]] << [site, index]
      when 201
        next unless params[0] == 0

        target = params[1]
        # A transfer on a map from 1000 on stays in that map's thousand, as the game's command does.
        target += site.map / 1000 * 1000 if site.map && site.map >= 1000 && target < 1000
        @entries[target] << [site, index] unless target == site.map
      end
    end
  end

  # Notes where each story variable a list sets stands on the progress variables, by the progress
  # the list's page needs, its branches ask for or it sets.
  #
  # @param site [Site] The list.
  def note_areas(site)
    progress = {}
    condition = site.page && iv(site.page, :condition)
    if condition && iv(condition, :variable_valid) && progress_variable?(iv(condition, :variable_id))
      progress[iv(condition, :variable_id)] = iv(condition, :variable_value)
    end
    sets = []
    site.list.each do |command|
      params = iv(command, :parameters)
      case iv(command, :code)
      when 111
        progress[params[1]] = [progress[params[1]], params[3]].compact.min if params[0] == 1 && params[2] == 0 && progress_variable?(params[1]) && params[3].to_i > 0
      when 122
        next unless params[2] == 0 && params[3] == 0 && params[4].is_a?(Integer) && params[4] > 0

        (params[0]..params[1]).each do |id|
          if progress_variable?(id)
            progress[id] = [progress[id], params[4]].compact.min
          elsif story_variable?(id)
            sets << [id, params[4]]
          end
        end
      end
    end
    return if progress.empty?

    sets.each do |id, value|
      progress.each { |variable, at| @area[id][value][variable] = [@area[id][value][variable], at].compact.min }
    end
  end

  # Finds where a story variable's value stands on the progress variables: the earliest place a
  # setter of that value, or of the nearest lower one, tells.
  #
  # @param id [Integer] The variable.
  # @param value [Integer] Its value.
  # @param want [Integer, nil] The progress variable to read it on, nil for any.
  # @return [Array(Integer, Integer), nil] The progress variable and its value, nil when unknown.
  def area_place(id, value, want = nil)
    return nil unless @area.key?(id)

    values = @area[id]
    lower = values.keys.select { |key| key <= value }.sort.reverse
    (lower + (values.keys.sort - lower)).each do |key|
      known = values[key].select { |variable, _| want.nil? || variable == want }
      return known.min_by { |variable, at| order_key(Place.new(part_name(variable, at), at)) } unless known.empty?
    end
    nil
  end

  # Tells the part and step the story variables of some marks stand at: the latest place any of
  # them tells. The Final Chapter's variables tell their route by their range, as the route return
  # (CE 154) clears them: the routes' from ROUTE_STORY_VARIABLES, the Chaos route's from
  # CHAOS_STORY_VARIABLES, whose free order tells no step; the others stand on the main story.
  #
  # @param marks [Array] The marks.
  # @return [Array(String, Integer), Array(nil, nil)] The part and step, nils when none tells.
  def area_part(marks)
    found = marks.select { |mark| mark[0] == :v && !progress_variable?(mark[1]) }.map do |_, id, value|
      if CHAOS_STORY_VARIABLES.include?(id)
        ["chaos", nil]
      elsif ROUTE_STORY_VARIABLES.include?(id)
        route = route_of(id)
        route ? [route, area_step([[:v, id, value]], ROUTE_VARIABLES[route])] : nil
      else
        step = area_step([[:v, id, value]], MAIN)
        step ? [main_part(step), step] : nil
      end
    end.compact
    found.max_by { |part, step| order_key(Place.new(part, step)) } || [nil, nil]
  end

  # Finds the route a variable of the routes' range belongs to, by the route most of its setters
  # tell.
  #
  # @param id [Integer] The variable.
  # @return [String, nil] "ad" or "mr", nil when no setter tells.
  def route_of(id)
    counts = Hash.new(0)
    @area[id].each_value { |known| known.each_key { |variable| counts[variable] += 1 if ["ad", "mr"].include?(ROUTE_VARIABLES.key(variable)) } } if @area.key?(id)
    counts.empty? ? nil : ROUTE_VARIABLES.key(counts.max_by { |variable, count| [count, variable] }[0])
  end

  # Tells the step on one progress variable the story variables of some marks stand at.
  #
  # @param marks [Array] The marks.
  # @param variable [Integer] The progress variable.
  # @return [Integer, nil] The latest step any of them tells, nil when none does.
  def area_step(marks, variable)
    marks.select { |mark| mark[0] == :v }.map { |mark| area_place(mark[1], mark[2], variable) }.compact.map(&:last).max
  end

  # Names the part a progress variable's value stands in.
  #
  # @param variable [Integer] The progress variable.
  # @param step [Integer] Its value.
  # @return [String] The part.
  def part_name(variable, step)
    variable == MAIN ? main_part(step) : ROUTE_VARIABLES.key(variable)
  end

  # Reports whether a variable is the main story's or a route's progress.
  #
  # @param id [Integer] The variable.
  # @return [Boolean] Whether it is.
  def progress_variable?(id)
    id == MAIN || ROUTE_VARIABLES.value?(id)
  end

  # Reports whether a variable belongs to the world's story: in the story's range, neither scratch
  # nor each player's own.
  #
  # @param id [Integer] The variable.
  # @return [Boolean] Whether it does.
  def story_variable?(id)
    STORY_VARIABLES.include?(id) && !unmarked?(:v, id, @names[1], SCRATCH_NAMES)
  end

  # Reports whether a switch belongs to the world's story: from FIRST_STORY_SWITCH on, neither
  # scratch nor each player's own.
  #
  # @param id [Integer] The switch.
  # @return [Boolean] Whether it does.
  def story_switch?(id)
    id >= FIRST_STORY_SWITCH && !unmarked?(:s, id, @names[0], SCRATCH_NAMES)
  end

  # Finds the branches each command of a list stands in: the command at each lower indent that last
  # came before it, which opens the branch it runs in.
  #
  # @param site [Site] The list.
  # @return [Array<Array<Integer>>] Each command's branch path, by the indexes of those commands.
  def paths(site)
    @paths[site.key] ||= begin
      last = []
      site.list.each_with_index.map do |command, index|
        indent = [iv(command, :indent).to_i, 0].max
        path = last.take(indent).compact
        last = last.take(indent)
        last[indent] = index
        path
      end
    end
  end

  # Reports whether one branch path lies on another: the same branch or one around it.
  #
  # @param outer [Array<Integer>] The path that may lie around.
  # @param inner [Array<Integer>] The other path.
  # @return [Boolean] Whether it does.
  def on_path?(outer, inner)
    outer.size <= inner.size && inner[0, outer.size] == outer
  end

  # Reports whether two commands can both run in one pass: one's branch lies on the other's.
  #
  # @param site [Site] Their list.
  # @param one [Integer] One command's index.
  # @param other [Integer] The other's.
  # @return [Boolean] Whether they can.
  def together?(site, one, other)
    on_path?(paths(site)[one], paths(site)[other]) || on_path?(paths(site)[other], paths(site)[one])
  end

  # Reads the condition a branch opens on, as it holds in that branch.
  #
  # @param site [Site] The list.
  # @param index [Integer] The command that opens the branch.
  # @return [Array(Array, Symbol, Boolean)] The marks the branch holds at, the side it asks for, and
  #   whether a first playthrough can run it.
  def branch(site, index)
    command = site.list[index]
    holds = true
    case iv(command, :code)
    when 111 then params = iv(command, :parameters)
    when 411
      opener = (index - 1).downto(0).find { |earlier| iv(site.list[earlier], :code) == 111 && iv(site.list[earlier], :indent) == iv(command, :indent) }
      return [[], nil, true] unless opener

      params = iv(site.list[opener], :parameters)
      holds = false
    else return [[], nil, true]
    end
    condition(site, params, holds)
  end

  # Reads a condition of a branch.
  #
  # @param site [Site] The list.
  # @param params [Array] The condition's parameters.
  # @param holds [Boolean] Whether it holds, false in its else branch.
  # @return [Array(Array, Symbol, Boolean)] The marks, the side and whether a first playthrough can
  #   meet it.
  def condition(site, params, holds)
    case params[0]
    when 0
      on = (params[2] == 0) == holds
      return [[], on ? SIDES[params[1]] : (SIDES.values - [SIDES[params[1]]]).first, true] if SIDES.key?(params[1])

      [on && story_switch?(params[1]) ? [[:s, params[1]]] : [], nil, true]
    when 1
      return [[], nil, true] unless params[2] == 0

      id = params[1]
      value = params[3].to_i
      return [[], nil, compare(0, value, params[4]) == holds] if id == CYCLES
      return [[], nil, true] unless story_variable?(id)

      least = holds ? { 0 => value, 1 => value, 3 => value + 1 }[params[4]] : { 2 => value + 1, 4 => value }[params[4]]
      [least && least > 0 ? [[:v, id, least]] : [], nil, true]
    when 2
      [site.map && holds && params[2] == 0 ? [[:ss, site.map, site.event, params[1]]] : [], nil, true]
    else [[], nil, true]
    end
  end

  # Compares two numbers as a branch's condition does.
  #
  # @param value [Integer] The variable's value.
  # @param other [Integer] The number it is compared with.
  # @param operator [Integer] 0 equal, 1 at least, 2 at most, 3 above, 4 below, 5 not equal.
  # @return [Boolean] Whether the condition holds.
  def compare(value, other, operator)
    [value == other, value >= other, value <= other, value > other, value < other, value != other][operator] ? true : false
  end

  # Reads what a page needs: the marks of its conditions, the side it asks for, and whether a first
  # playthrough can meet them.
  #
  # @param site [Site] The list.
  # @return [Array(Array, Symbol, Boolean)] The marks, the side and whether it can.
  def page_needs(site)
    return [[], nil, true] unless site.page

    condition = iv(site.page, :condition)
    marks = []
    side = nil
    [[:switch1_valid, :switch1_id], [:switch2_valid, :switch2_id]].each do |valid, key|
      next unless iv(condition, valid)

      id = iv(condition, key)
      side = SIDES[id] if SIDES.key?(id)
      marks << [:s, id] if story_switch?(id)
    end
    if iv(condition, :variable_valid)
      id = iv(condition, :variable_id)
      return [[], nil, false] if id == CYCLES && iv(condition, :variable_value) > 0

      marks << [:v, id, iv(condition, :variable_value)] if story_variable?(id) && iv(condition, :variable_value) > 0
    end
    marks << [:ss, site.map, site.event, iv(condition, :self_switch_ch)] if iv(condition, :self_switch_valid)
    [marks, side, true]
  end

  # Reports whether a page needs a companion of the player's own roster, as the Pocket Castle's
  # talks with a companion do.
  #
  # @param site [Site] The list.
  # @return [Boolean] Whether it does.
  def roster_page?(site)
    return false unless site.page

    condition = iv(site.page, :condition)
    [[:switch1_valid, :switch1_id], [:switch2_valid, :switch2_id]].any? { |valid, key| iv(condition, valid) && ACTOR_SWITCH_RANGE.include?(iv(condition, key)) }
  end

  # Reads a command's own place in its list: the marks that hold while it runs and once its list
  # ran, the side it asks for, and whether a first playthrough can run it.
  #
  # @param site [Site] The list.
  # @param index [Integer] The command.
  # @return [Array(Array, Array, Symbol, Boolean, Array)] The marks while it runs, the marks once the
  #   list ran, the side, whether it can run, and the marks its page and branches need.
  def own_marks(site, index)
    needs, side, runs = page_needs(site)
    path = paths(site)[index]
    path.each do |opener|
      marks, branch_side, branch_runs = branch(site, opener)
      needs += marks
      side ||= branch_side
      runs &&= branch_runs
    end
    before = {}
    after = {}
    site.list.each_with_index do |command, position|
      next unless on_path?(paths(site)[position], path)

      params = iv(command, :parameters)
      states = position < index ? [before, after] : [after]
      case iv(command, :code)
      when 121
        (params[0]..params[1]).each { |id| states.each { |state| state[[:s, id]] = params[2] == 0 } if story_switch?(id) }
      when 122
        (params[0]..params[1]).each do |id|
          next unless story_variable?(id)

          value = params[2] == 0 && params[3] == 0 && params[4].is_a?(Integer) ? params[4] : nil
          states.each { |state| state[[:v, id]] = value }
        end
      when 123
        states.each { |state| state[[:ss, params[0]]] = params[1] == 0 } if site.map
      end
    end
    [merge(needs, before, site), merge(needs, telling(after), site, true), side, runs, merge(needs, {}, site)]
  end

  # Keeps of what a list leaves in the story what tells its place best: the story variables it
  # leaves at a number, else the switches it leaves on, else its self switches. What it turns off
  # stays, so the marks it needs drop it.
  #
  # @param state [Hash] What the list set: [:s, id] => on, [:v, id] => value, [:ss, letter] => on.
  # @return [Hash] The part of it that tells.
  def telling(state)
    [:v, :s, :ss].each do |kind|
      kept = state.select { |key, value| key[0] == kind && (value.is_a?(Integer) ? value > 0 : value) }
      return state.select { |key, value| key[0] == kind || value == false || value.nil? } unless kept.empty?
    end
    state
  end

  # Joins the marks a command needs with what its list set: a variable at the higher of the two, a
  # switch dropped once the list turned it off.
  #
  # @param needs [Array] The marks the command needs.
  # @param state [Hash] What the list set: [:s, id] => on, [:v, id] => value, [:ss, letter] => on.
  # @param site [Site] The list.
  # @param final [Boolean] Whether the state is the list's last, whose values replace the needed ones.
  # @return [Array] The marks, ordered.
  def merge(needs, state, site, final = false)
    marks = {}
    needs.each do |mark|
      key = mark[0] == :v ? [:v, mark[1]] : mark
      marks[key] = mark[0] == :v ? [:v, mark[1], [marks[key] ? marks[key][2] : 0, mark[2]].max] : mark
    end
    state.each do |key, value|
      case key[0]
      when :s then value ? marks[key] = key : (marks.delete(key) if final)
      when :v
        if value.is_a?(Integer) && value > 0
          marks[key] = [:v, key[1], final ? value : [marks[key] ? marks[key][2] : 0, value].max]
        elsif final
          marks.delete(key)
        end
      when :ss
        mark = [:ss, site.map, site.event, key[1]]
        value ? marks[mark] = mark : (marks.delete(mark) if final)
      end
    end
    marks.values.sort_by { |mark| [[:v, :s, :ss].index(mark[0]), mark[1..-1].map(&:to_s)] }
  end

  # Places a command of a list in the story: by the marks of its own list, else by where the story
  # first comes to its map or the map around it, else by the lists that call its common event or
  # transfer onto its map, else by its map's place in the map tree.
  #
  # @param site [Site] The list.
  # @param index [Integer] The command.
  # @param seen [Hash] The lists already asked on the way, so calls in a circle end.
  # @return [Place] Its place.
  def place(site, index, seen = {})
    key = [site.key, index]
    return @places[key] if @places.key?(key)

    at, marks, side, _, needs = own_marks(site, index)
    ran = ran?(needs, marks)
    side ||= map_side(@map_names[site.map].to_s) if site.map
    return @places[key] = Place.new(nil, nil, needs, at, marks, side, ran) if SIDE_ROOTS.include?(site.root)

    fixed = PLACES[site.key] || (site.map && PLACES[site.key.sub(/:\d+\z/, "")])
    if fixed
      part, step, extra = fixed
      return @places[key] = Place.new(part, step, merge(needs + extra, {}, site), merge(at + extra, {}, site), merge(marks + extra, {}, site), side, true)
    end

    part, step = part_of(site, index, at, marks)
    root_part = site.map ? ROOT_PARTS[site.root] : nil
    if root_part && part != root_part
      part = root_part
      step = step_of(ROUTE_VARIABLES[part], at, marks) || (part == "chaos" ? nil : area_step(at + marks, ROUTE_VARIABLES[part]))
    end
    part, step = latest([part, step], area_part(at + marks)) unless root_part || site.common
    found = nil
    unless part && step
      # A Chaos map's free order takes from the events around it only a later place, such as the
      # final battle's, since the route's early events reach its areas as well.
      least = part == "chaos" && site.root != CHAOS_PROLOGUE ? CHAOS_FREE_ORDER : 2
      # Where the story first comes to the map counts too, as for a town's companions, whom the
      # earliest way onto the map would place too early; on the Chaos route's free order it would
      # place them after the ending.
      first = site.map && part != "chaos" && (map_first(site.map, part, least) || map_first(@parents[site.map], part, least))
      outer = outer_places(site, seen.merge(site.key => true)).select { |place| part.nil? || (place.part == part && place.step.to_i >= least) }
      found = outer.min_by { |place| order_key(place) }
      if found
        part, step = found.part, found.step
        needs = merge(needs + found.needs, {}, site)
        at = merge(at + found.at, {}, site)
        marks = merge(marks + found.marks, {}, site)
        side ||= found.side
      end
      part, step = latest([part, step], first) if first
    end
    part, step = latest([part, step], area_part(at + marks)) unless root_part
    # A common event whose own marks tell nothing of it ran with the list that called it, and a page
    # the player does not talk to, as a camp's bed, with the transfer that brought them there.
    ran ||= site.common && outer_places(site, seen.merge(site.key => true)).any?(&:ran) ? true : false
    ran ||= found && found.ran && site.page && iv(site.page, :trigger) != TALK_TRIGGER ? true : false
    part ||= "chaos" if site.common && site.common >= CHAOS_ROUTE_EVENTS
    step = site.root == CHAOS_PROLOGUE ? 1 : CHAOS_FREE_ORDER if part == "chaos" && step.to_i < 2
    variable = ROUTE_VARIABLES[part] || MAIN
    marks += [[:v, variable, [step.to_i, 1].max]] if part && (step.to_i > 0 || variable != MAIN)
    @places[key] = Place.new(part, step, needs, at, merge(marks, {}, site), side, ran)
  end

  # Reports whether a list's own marks tell that its event ran: they hold more than its page and
  # branches need. Marks that only tell that the event is there to play, as a town's companion who
  # joins on a talk has, hold before it ran too.
  #
  # @param needs [Array] The marks its page and branches need.
  # @param marks [Array] The marks once its event ran.
  # @return [Boolean] Whether they do.
  def ran?(needs, marks)
    marks.any? { |mark| !implied?(mark, needs) }
  end

  # Finds the earliest place the story's events on a map tell by their own marks, where the story
  # first comes to the map, as for a town's companions whose joins tell no place of their own.
  #
  # @param map_id [Integer, nil] The map.
  # @param part [String, nil] The part the place must be in, nil for any.
  # @param least [Integer] The least step the place must have.
  # @return [Array(String, Integer), nil] The part and step, nil when no event on the map tells one.
  def map_first(map_id, part, least)
    return nil unless map_id

    @map_steps[map_id] ||= (@sites_by_map[map_id] || []).map do |site|
      next if site.list.empty?

      last = site.list.size - 1
      at, marks, = own_marks(site, last)
      found = part_of(site, last, at, marks)
      found = latest(found, area_part(at + marks)) unless ROOT_PARTS.key?(site.root)
      found[0] && found[1] ? found : nil
    end.compact
    @map_steps[map_id].select { |found| (part.nil? || found[0] == part) && found[1] >= least }.min_by { |found| order_key(Place.new(*found)) }
  end

  # Places a list by the lists around it: those that call its common event, else those that
  # transfer onto its map.
  #
  # @param site [Site] The list.
  # @param seen [Hash] The lists already asked on the way.
  # @return [Array<Place>] The places of those calls or transfers that are known.
  def outer_places(site, seen)
    callers = site.common ? @callers[site.common] : (site.map ? @entries[site.map] : [])
    callers.reject { |caller, _| seen[caller.key] }.map { |caller, index| place(caller, index, seen) }.select(&:part)
  end

  # Tells the part and step of a command from its marks: a route's progress, else the main story's,
  # and the Great Decision's route by its choice.
  #
  # @param site [Site] The list.
  # @param index [Integer] The command.
  # @param at [Array] The marks while it runs.
  # @param marks [Array] The marks once its list ran.
  # @return [Array(String, Integer), Array(nil, nil)] The part and step, nils when they tell none.
  def part_of(site, index, at, marks)
    if site.common == DECISION_EVENT
      route = decision_route(site, index)
      return [route, 0] if route
    end
    ROUTE_VARIABLES.each do |part, variable|
      step = step_of(variable, at, marks)
      return [part, step] if step
    end
    step = step_of(MAIN, at, marks)
    step ? [main_part(step), step] : [nil, nil]
  end

  # Picks the later of two places, each a part and step, either of which may be unknown.
  #
  # @param one [Array(String, Integer)] One place.
  # @param other [Array(String, Integer)] The other.
  # @return [Array(String, Integer)] The later one.
  def latest(one, other)
    return one unless other[0]
    return other unless one[0]

    (order_key(Place.new(*other)) <=> order_key(Place.new(*one))) > 0 ? other : one
  end

  # Finds the route the Great Decision's choice around a command starts.
  #
  # @param site [Site] The Great Decision's list.
  # @param index [Integer] The command.
  # @return [String, nil] "ad" or "mr", nil outside those choices.
  def decision_route(site, index)
    routes = site.list.each_with_index.map do |command, position|
      params = iv(command, :parameters)
      next unless iv(command, :code) == 122 && params[0] <= DECISION_CHOICE && DECISION_CHOICE <= params[1] && params[2] == 0 && params[3] == 0

      DECISION_ROUTES[params[4]] if together?(site, index, position) && !paths(site)[position].empty?
    end
    routes = routes.compact.uniq
    routes.size == 1 ? routes[0] : nil
  end

  # Tells the step a progress variable stands at for a command: what it holds at while the command
  # runs, else one below what its list leaves.
  #
  # @param variable [Integer] The progress variable.
  # @param at [Array] The marks while the command runs.
  # @param marks [Array] The marks once its list ran.
  # @return [Integer, nil] The step, nil when neither tells it.
  def step_of(variable, at, marks)
    now = at.find { |mark| mark[0] == :v && mark[1] == variable }
    return now[2] if now

    later = marks.find { |mark| mark[0] == :v && mark[1] == variable }
    later ? later[2] - 1 : nil
  end

  # Tells the part of the main story's progress, as the relay does.
  #
  # @param step [Integer] The main story's progress.
  # @return [String] "1", "2" or "3".
  def main_part(step)
    return "1" if step < PART_TWO

    step < PART_THREE ? "2" : "3"
  end

  # Orders places by the story: by part, then by step.
  #
  # @param place [Place] The place.
  # @return [Array] The key.
  def order_key(place)
    [PART_RANK[place.part] || 9, place.step || 0, ROUTE_VARIABLES.keys.index(place.part) || 0]
  end

  # Reports whether a place surely comes before another in a Raid World's story: an earlier part,
  # an earlier step of the same part, or an earlier command of the same list. The two routes come
  # in either order, and a place whose part is unknown is never surely before or after.
  #
  # @param one [Array(Place, String, Integer)] A place with its site and command.
  # @param other [Array(Place, String, Integer)] The other.
  # @return [Boolean] Whether it does.
  def before?(one, other)
    first, second = one[0], other[0]
    return one[2] < other[2] if one[1] == other[1] && first.part == second.part
    return false unless first.part && second.part

    rank = PART_RANK[first.part] <=> PART_RANK[second.part]
    return rank < 0 unless rank == 0
    return false unless first.part == second.part
    return first.step < second.step if first.step && second.step && first.step != second.step

    further?(second.needs, first.needs)
  end

  # Reports whether a place needs more than another on a story variable both need and less on none,
  # as a later page of one area does.
  #
  # @param later [Array] The marks the place that may be later needs.
  # @param earlier [Array] The other's.
  # @return [Boolean] Whether it is.
  def further?(later, earlier)
    ahead = behind = false
    later.each do |mark|
      next unless mark[0] == :v && !progress_variable?(mark[1])

      other = earlier.find { |each| each[0] == :v && each[1] == mark[1] }
      next unless other

      ahead ||= mark[2] > other[2]
      behind ||= mark[2] < other[2]
    end
    ahead && !behind
  end

  # Reads the party's and the levels' changes a list makes, each with its command, leaving out those
  # a first playthrough never runs.
  #
  # @param site [Site] The list.
  # @return [Array<Change>] The changes.
  def changes(site)
    found = []
    site.list.each_with_index do |command, index|
      params = iv(command, :parameters)
      case iv(command, :code)
      when 129
        found << Change.new(params[1] == 0 ? :join : :delete, params[0], index, nil)
      when 355, 655
        params[0].to_s.scan(PARTY_CALL) do |name, arguments|
          ids = arguments.scan(/\d+/).map(&:to_i)
          next if ids.empty?

          if JOIN_SCRIPTS.include?(name) then ids.each { |id| found << Change.new(:join, id, index, nil) }
          elsif TEMP_SCRIPTS.include?(name) then ids.each { |id| found << Change.new(:temp, id, index, nil) }
          elsif name == "delete_actor_ex" then found << Change.new(:delete, ids[0], index, nil)
          elsif ids.size == 2 then found << Change.new(:floor, ids[0], index, ids[1])
          end
        end
      end
    end
    found.reject { |change| change.actor == HERO || !@actors[change.actor] || !own_marks(site, change.index)[3] }
  end

  # Finds the main persona of an actor.
  #
  # @param id [Integer] The actor.
  # @return [Integer] Its main persona.
  def main_of(id)
    @actors[id] ? @actors[id][:main] : id
  end

  # Scans every list for the story's joins, removals and level floors, then gives each join its gate.
  def scan_party
    @joins = []
    @removals = []
    @floors = []
    @sites.each do |site|
      found = changes(site)
      next if found.empty?

      found.each do |change|
        main = main_of(change.actor)
        floors = found.select { |other| other.kind == :floor && main_of(other.actor) == main && together?(site, other.index, change.index) }
        level = floors.map(&:level).max
        case change.kind
        when :join, :temp
          @joins << Join.new(main, change.actor, site.key, change.index, place(site, change.index), level, nil, change.kind)
        when :delete
          rejoined = found.any? { |other| other.kind == :join && main_of(other.actor) == main && other.index > change.index }
          @removals << [main, change.actor, site.key, change.index, place(site, change.index), first_cycle?(site, change.index)] unless rejoined || chosen?(site, change.index) || SIDE_ROOTS.include?(site.root)
        when :floor
          joined = found.any? { |other| [:join, :temp].include?(other.kind) && main_of(other.actor) == main && together?(site, other.index, change.index) }
          @floors << [main, change.level, site.key, change.index, place(site, change.index)] unless joined
        end
      end
    end
    @removals.uniq! { |removal| [removal[0], removal[2]] }
    @joins = @joins.group_by { |join| [join.actor, join.site, join.rule, join.place.part, join.place.side] }.map do |_, same|
      first = same.min_by(&:index)
      first.floor = same.map(&:floor).compact.max
      first
    end
    give_gates
  end

  # Reports whether a command runs on the first playthrough alone: in a branch on "Overall Cycles".
  #
  # @param site [Site] The list.
  # @param index [Integer] The command.
  # @return [Boolean] Whether it does.
  def first_cycle?(site, index)
    paths(site)[index].any? do |opener|
      params = iv(site.list[opener], :parameters)
      iv(site.list[opener], :code) == 111 && params[0] == 1 && params[1] == CYCLES
    end
  end

  # Reports whether a command stands in a choice the player makes, such as which angel stays.
  #
  # @param site [Site] The list.
  # @param index [Integer] The command.
  # @return [Boolean] Whether it does.
  def chosen?(site, index)
    paths(site)[index].any? { |opener| [402, 403].include?(iv(site.list[opener], :code)) }
  end

  # Gives each join its gate: its level floor (its own, or one the story set before it where the
  # companion came along for a while or was not joining), else the start level on a first join, else
  # for a companion the story took away and gives back the Level Cap's cap there, else the level the
  # companion keeps; never above MAX_GATE.
  def give_gates
    joins = @joins.select { |join| join.rule == :join }
    loose = @joins.select { |join| join.rule == :temp && join.floor }.map { |temp| [temp.actor, temp.floor, spot(temp)] } +
            @floors.map { |actor, level, site, index, place| [actor, level, [place, site, index]] }
    loose.each do |actor, level, where|
      later = joins.select { |join| join.actor == actor && before?(where, spot(join)) }
      later.reject { |join| later.any? { |other| before?(spot(other), spot(join)) } }.each { |join| join.floor = [join.floor, level].compact.max }
    end
    @joins = joins.sort_by { |join| order_key(join.place) + [join.site.split(":").map { |part| part =~ /\A\d+\z/ ? part.to_i : 0 }, join.index] }
    @joins.each { |join| give_gate(join) }
  end

  # Gives one join its gate, see give_gates, after the companion's joins before it.
  #
  # @param join [Join] The join.
  # @return [Integer] Its gate.
  def give_gate(join)
    return join.gate if join.gate

    earlier = @joins.select { |other| other.actor == join.actor && before?(spot(other), spot(join)) }
    if join.floor
      join.gate = join.floor
      join.rule = :floor
    elsif earlier.empty?
      join.gate = @actors[join.actor][:start]
      join.rule = :start
    elsif given_back?(join, earlier)
      join.gate = cap_at(join.place)
      join.rule = :cap
    else
      kept = earlier.map { |other| give_gate(other) } + @floors.select { |actor, _, site, index, place| actor == join.actor && before?([place, site, index], spot(join)) }.map { |floor| floor[1] }
      join.gate = kept.max
      join.rule = :kept
    end
    join.gate = [join.gate, MAX_GATE].min
  end

  # The place of a join with its site and command, as before? takes it.
  #
  # @param join [Join] The join.
  # @return [Array(Place, String, Integer)] Its place, site and command.
  def spot(join)
    [join.place, join.site, join.index]
  end

  # Reports whether the first playthrough's story took a companion away before a join, as the Chaos
  # route's Pocket Castle revival does, and nothing gave them back since.
  #
  # @param join [Join] The join.
  # @param earlier [Array<Join>] The companion's joins before it.
  # @return [Boolean] Whether it did.
  def given_back?(join, earlier)
    @removals.any? do |actor, _, site, index, place, first|
      removal = [place, site, index]
      first && actor == join.actor && before?(removal, spot(join)) && earlier.none? { |other| before?(removal, spot(other)) }
    end
  end

  # Reads the cap of the last Level Cap milestone surely beaten at a place: every milestone of the
  # parts before it, and those of its own part its step or its marks tell.
  #
  # @param place [Place] The place.
  # @return [Integer] The cap.
  def cap_at(place)
    held = place.at + place.marks
    variable = ROUTE_VARIABLES[place.part] || MAIN
    held += [[:v, variable, place.step]] if place.step
    return 0 unless place.part

    ended = place.part == "chaos" && place.step.to_i >= CHAOS_ENDED
    CHAOS_GATES.each { |step, marks| held += marks if place.part == "chaos" && place.step.to_i >= step }
    MILESTONES.select do |part, _, alternatives|
      PART_RANK[part] < PART_RANK[place.part] || (ended && part == place.part) ||
        (part == place.part && alternatives.any? { |marks| marks.all? { |mark| implied?(mark, held) } })
    end.map { |milestone| milestone[1] }.max.to_i
  end

  # Reports whether marks that hold imply one more.
  #
  # @param mark [Array] The mark.
  # @param held [Array] The marks that hold.
  # @return [Boolean] Whether they do.
  def implied?(mark, held)
    return held.include?(mark) unless mark[0] == :v

    held.any? { |other| other[0] == :v && other[1] == mark[1] && other[2] >= mark[2] }
  end

  # Scans every list for the key items the story gives or takes, the chests that hold key items, and
  # the skills and items the story gives.
  def scan_items
    @key_items = []
    @chests = []
    @rewards = []
    @sites.each do |site|
      if chest?(site.list)
        scan_chest(site)
        next
      end
      story = progress?(site.list)
      site.list.each_with_index do |command, index|
        params = iv(command, :parameters)
        code = iv(command, :code)
        if code == 318 && params[0] == 0 && params[1] == HERO && params[2] == 0
          @rewards << [:skill, params[3], 1, site.key, index, place(site, index)] if own_marks(site, index)[3]
        elsif ITEM_CODES.key?(code) && params[2] == 0 && params[3].is_a?(Integer)
          key_item = code == 126 && @key_item_ids.include?(params[0])
          next unless own_marks(site, index)[3]

          if key_item
            @key_items << [params[0], params[1] == 0 ? params[3] : -params[3], site.key, index, place(site, index)] unless roster_page?(site)
          elsif story && params[1] == 0
            @rewards << [ITEM_CODES[code].to_sym, params[0], params[3], site.key, index, place(site, index)]
          end
        end
      end
    end
    # A list gives an item once, though it may hold one branch for each stage of the story.
    @key_items = @key_items.group_by { |item, amount, site| [item, amount <=> 0, site] }.map { |_, rows| rows.max_by { |row| [row[1].abs, -row[3]] } }
    @rewards = @rewards.group_by { |kind, id, _, site| [kind, id, site] }.map { |_, rows| rows.max_by { |row| [row[2], -row[4]] } }
  end

  # Notes a chest that holds key items: its self switch and those items.
  #
  # @param site [Site] The chest's page.
  def scan_chest(site)
    items = site.list.select { |command| iv(command, :code) == 126 && iv(command, :parameters)[1] == 0 && @key_item_ids.include?(iv(command, :parameters)[0]) }
    return if items.empty?

    switch = site.list.find { |command| iv(command, :code) == 123 && iv(command, :parameters)[1] == 0 }
    return unless switch

    @chests << [[site.map, site.event, iv(switch, :parameters)[0]], items.map { |command| iv(command, :parameters)[0] }.uniq.sort, site.key, place(site, 0)]
  end

  # Runs the scans.
  def scan
    scan_party
    scan_items
    self
  end

  # Writes a place's columns of a row: part, step, side and marks.
  #
  # @param place [Place] The place.
  # @return [String] The columns.
  def place_columns(place)
    "#{place.part.inspect}, #{place.step.inspect}, #{place.side.inspect}, #{place.marks.inspect}"
  end

  # Writes world_catchup_data.rbx.
  #
  # @param output [String] The file.
  def write(output)
    sorted = lambda { |rows, place_at| rows.sort_by { |row| order_key(row[place_at]) + [row.inspect] } }
    joins = @joins.map do |join|
      "    [#{join.actor}, #{join.persona}, #{join.site.inspect}, #{place_columns(join.place)}, #{join.gate}, #{join.rule.inspect}, #{join.index}, #{join.place.ran}]"
    end
    removals = sorted.call(@removals, 4).map { |actor, persona, site, index, place, first| "    [#{actor}, #{persona}, #{site.inspect}, #{place_columns(place)}, #{first}, #{index}]" }
    # A key item given and taken at one place is given first, as the story uses what it gave.
    ordered_items = @key_items.sort_by { |row| order_key(row[4]) + [row[1] < 0 ? 1 : 0, row.inspect] }
    key_items = ordered_items.map { |item, amount, site, _, place| "    [#{item}, #{amount}, #{site.inspect}, #{place_columns(place)}, #{place.ran}]" }
    chests = sorted.call(@chests, 3).map { |key, items, _, place| "    [#{key.inspect}, #{items.inspect}, #{place.part.inspect}, #{place.step.inspect}]" }
    rewards = sorted.call(@rewards, 5).map { |kind, id, amount, site, _, place| "    [#{kind.inspect}, #{id}, #{amount}, #{site.inspect}, #{place_columns(place)}, #{place.ran}]" }
    parts = PARTS.map { |part| "    Part.new(#{part.id.inspect}, #{part.name.inspect}, #{part.ending.inspect}, #{part.gate})" }
    File.write(output, <<~RUBY)
      # <auto-generated>
      # Written by GameScript/Tools/raid_data.rb from the game's data; run it again rather than editing
      # this file.
      # </auto-generated>

      # What a Raid World needs to carry a player who falls behind along with the world's story: the
      # story's parts with their level gates, every story join of a companion with the level that
      # brings it, the companions the story takes away, the key items the story gives, the chests that
      # hold them, and the skills and items the story gives.
      #
      # A row's place in the story is its part ("1", "2", "3", "ad", "mr" or "chaos"; nil for side
      # content outside the story's order), its step there (the main story's progress, variable 1001,
      # in Parts 1 to 3, the route's variable 1141, 1142 or 1143 on a route; nil where nothing tells
      # it), the side it asks for (:alice, :ilias or nil) and its marks: what holds in the story once
      # its event ran ([:s, switch] on, [:v, variable, at least], [:ss, map, event, letter] on). A
      # route's marks no longer hold once the world returned from the route to the Great Decision,
      # which clears its variables and self switches. A row's ran tells whether its marks show that
      # its event ran; false where they only show that the event is there to play, as for a town's
      # companion who joins on a talk.
      module MGQ_MpWorldCatchupData
        # A part of the story: its id as the relay names it, its name, the marks that hold right
        # before its ending starts, and its level gate.
        Part = Struct.new(:id, :name, :ending, :gate)

        # The story's parts in their order. Each gate is the cap of the last Level Cap milestone in the
        # part.
        PARTS = [
      #{parts.join(",\n")}
        ]

        # A story join of a companion: the main persona, the persona the event adds, the event's site,
        # its place (part, step, side, marks), the gate (the highest base level a player needs) and
        # the rule that gave the gate: :floor (the story's level floor at the join, through any
        # persona), :start (the companion's start level on a first join), :cap (the Level Cap's cap at
        # a join that gives back a companion the story took away) or :kept (the level the companion
        # keeps from an earlier join); then the command's index in its list, which orders the join
        # against a removal of the same list, and ran.
        Join = Struct.new(:actor, :persona, :site, :part, :step, :side, :marks, :gate, :rule, :index, :ran)

        # Every story join, in the story's order.
        JOINS = [
      #{joins.join(",\n")}
        ].map { |row| Join.new(*row) }

        # A companion the story takes away: the main persona, the persona removed, the event's site,
        # its place, and whether only a first playthrough takes them (true for the removals that last,
        # such as the Chaos route's Pocket Castle revival, CE 9141; false for a companion who leaves
        # for a while and whom a later join gives back), and the command's index in its list.
        Removal = Struct.new(:actor, :persona, :site, :part, :step, :side, :marks, :first, :index)

        # Every removal of the story outside the player's own choices, in the story's order.
        REMOVALS = [
      #{removals.join(",\n")}
        ].map { |row| Removal.new(*row) }

        # A key item the story gives (a positive amount) or takes (a negative one): the item, the
        # amount, the event's site, its place and ran.
        KeyItem = Struct.new(:item, :amount, :site, :part, :step, :side, :marks, :ran)

        # Every key item the story's events give or take, outside chests and the talks with a
        # companion of the player's own roster, in the story's order.
        KEY_ITEMS = [
      #{key_items.join(",\n")}
        ].map { |row| KeyItem.new(*row) }

        # A chest that holds key items: its self switch (map, event, letter), the key items, and its
        # part and step.
        Chest = Struct.new(:key, :items, :part, :step)

        # The chests that hold key items, which open once for the whole world.
        CHESTS = [
      #{chests.join(",\n")}
        ].map { |row| Chest.new(*row) }

        # A skill Luka learns (:skill) or an item an event that moves the story on gives (:i, :w or
        # :a): its id, the amount, the event's site, its place and ran.
        Reward = Struct.new(:kind, :id, :amount, :site, :part, :step, :side, :marks, :ran)

        # Every skill and story item the story gives, in the story's order, key items aside.
        REWARDS = [
      #{rewards.join(",\n")}
        ].map { |row| Reward.new(*row) }
      end
    RUBY
  end
end

# A test loads this file for its class alone.
return unless __FILE__ == $PROGRAM_NAME

data = ARGV[0] or abort("usage: ruby raid_data.rb \"<game folder>\\Data\" [output file]")
output = ARGV[1] || File.expand_path("../Multiplayer/Scripts/world_catchup_data.rbx", __dir__)
tables = RaidData.new(data).scan
tables.write(output)
puts "wrote #{output}: #{tables.joins.size} joins, #{tables.removals.size} removals, #{tables.key_items.size} key items, " \
     "#{tables.chests.size} chests, #{tables.rewards.size} rewards"
