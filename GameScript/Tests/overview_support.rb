#----------------------------------------------------------------
#  overview_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-01: Created
#
#----------------------------------------------------------------

# The World overview's models in the DLL (MGQOnline.Game/Overview behind OverviewTopics), stood in
# for by FakeBridge: what the player tells the others, the lists of players and the World, Quests
# and Unlocks pages. Each stand-in is checked against the golden cases of fixtures/overview, which
# the C# owners pass too, as this file loads, so the stand-ins cannot drift from what C# answers.
# answer_overview_models answers the topics from the test's world: MGQ_MpOverworldSync's players,
# MGQ_MpCoop's party and MGQ_MpRaidPool's pools.

require_relative "rules_support"

# The golden steps of what the player tells the others.
OVERVIEW_STATE_CASES = rule_cases("overview", "state.json")

# The golden world of the lists of players.
OVERVIEW_ROW_CASES = rule_cases("overview", "rows.json")

# The golden pages.
OVERVIEW_PAGE_CASES = rule_cases("overview", "pages.json")

# The whole parts a gauge's share crosses the bridge in.
OVERVIEW_GAUGE_PARTS = 1_000_000

# What the player tells the others, as OverviewState keeps it: the levels and the story read every
# 180 frames in a world, the levels from before a co-op battle kept while it runs, and the place.
class StandInOverviewState
  # The frames between two readings.
  READ_FRAMES = 180

  # @return [Integer, nil] The formation's highest level as last read.
  attr_reader :level

  # @return [String, nil] The place in the story as last read.
  attr_reader :story

  # @return [Integer, nil] The Frontline's highest level as last read.
  attr_reader :front

  # @return [String] Where the player is as last told.
  attr_reader :place

  # Makes the state before the first reading.
  def initialize
    @frames = 0
    @place = ""
  end

  # Counts a frame, forgetting what was read outside a world.
  #
  # @param in_world [Boolean] Whether a world is open.
  # @return [Boolean] Whether the game reads now.
  def step(in_world)
    return forget && false unless in_world

    @frames -= 1
    return false if @frames > 0

    @frames = READ_FRAMES
    true
  end

  # Keeps what the game read.
  #
  # @param level [Integer] The formation's highest level.
  # @param front [Integer, nil] The Frontline's, nil outside a Raid World.
  # @param story [String] The place in the story.
  # @param battle [Boolean] Whether a co-op battle runs.
  # @return [String, nil] The log's line, nil while nothing changed.
  def take(level, front, story, battle)
    level = battle ? @level.to_i : level
    front = front.nil? ? nil : (battle ? @front.to_i : front)
    line = if [level, story, front] == [@level, @story, @front] then nil
           else "told the others: level #{@level.inspect} -> #{level}, story #{@story.inspect} -> #{story.inspect}#{front ? ", Frontline level #{@front.inspect} -> #{front}" : ''}"
           end
    @level, @story, @front = level, story, front
    line
  end

  # Forgets what was read.
  #
  # @return [Boolean] true.
  def forget
    @level = @story = @front = nil
    @frames = 0
    true
  end

  # Keeps where the player is and tells the state's fields.
  #
  # @param place [String] Where the player is.
  # @param raid [Boolean] Whether the world is a Raid World.
  # @return [Hash] The fields.
  def fields(place, raid)
    @place = place.to_s
    told = { "place" => @place, "lv" => @level.to_i, "progress" => @story.to_s }
    told["flv"] = @front.to_i if raid
    told
  end
end

OVERVIEW_STATE_CASES["steps"].inject(StandInOverviewState.new) do |state, step|
  logged = []
  step["frames"].times do
    next unless state.step(step["in_world"])

    line = state.take(step["level"].to_i, step["raid"] ? step["front"].to_i : nil, step["story"].to_s, step["battle"] == true)
    logged << line if line
  end
  fields = state.fields(step["place"].to_s, step["raid"] == true)
  raise "the overview state stand-in tells #{[fields, logged].inspect} for #{step.inspect}" unless [fields, logged] == [step["fields"], step["logged"]]
  state
end

# A player of a world as the lists' stand-in reads them: their seat, what they told, whether they
# are in the player's party, and whether they stand on the player's map within the world's scope.
OverviewPeer = Struct.new(:seat, :state, :member, :here)

# Down-cases the letters A to Z only, as the DLL's ordinal sorts do.
#
# @param text [String] The text.
# @return [String] The text.
def overview_downcase(text)
  text.to_s.tr("A-Z", "a-z")
end

# Builds the lists of players as OverviewRows does.
#
# @param own [Hash] The player: :name, :place, :level, :front, :story (a code), :ping, :party (the
#   party's id), :members (whether the party holds anyone else).
# @param peers [Array<OverviewPeer>] The other players, in their seats' order.
# @param world [Hash] :raid and :in_world.
# @param party [#size_of, #leads?] The parties: size_of(id), leads?(seat, -1 for the player).
# @return [Hash] "players", "lines", "party", "raid_party" and "map" as the topic answers them.
def stand_in_overview_rows(own, peers, world, party)
  badge = lambda do |id, seat|
    size = party.size_of(id)
    size >= 2 ? ["#{size} / 4", party.leads?(seat)] : nil
  end
  level_text = lambda { |level| level.to_i > 0 ? "Lv #{level.to_i}" : "" }
  own_row = lambda { |name, level| [-1, name, own[:place], level_text.call(level), stand_in_story_text(own[:story]), own[:ping].to_s, "", own[:members], badge.call(own[:party], -1)] }
  row_of = lambda do |peer, level|
    state = peer.state
    [peer.seat, state["name"].to_s, state["place"].to_s, level_text.call(level), stand_in_story_text(state["progress"]), state["ping"].to_s, state["scene"].to_s,
     peer.member ? true : false, badge.call(state["party"], peer.seat)]
  end
  named = peers.select { |peer| peer.state.key?("name") }
  players = [own_row.call(own[:name] + " (you)", own[:level])] + named.map { |peer| row_of.call(peer, peer.state["lv"]) }
  first = players[0][2]
  lines = players.group_by { |row| row[2] }.sort_by { |place, _| [place == first ? 0 : 1, overview_downcase(place), place] }.map do |place, rows|
    [["place", place.empty? ? "Unnamed place" : place]] +
      rows.sort_by { |row| [row[0] == -1 ? 0 : 1, overview_downcase(row[1]), row[0]] }.map { |row| ["player", players.index(row)] }
  end.flatten(1)
  in_party = world[:in_world] && party.size_of(own[:party]) >= 2
  party_list = lambda do |front|
    rows = [own_row.call(own[:name], front ? own[:front] : own[:level])] + named.select { |peer| peer.member }.map { |peer| row_of.call(peer, peer.state[front ? "flv" : "lv"]) }
    rows.sort_by { |row| [row[8] && row[8][1] ? 0 : 1, overview_downcase(row[1]), row[0]] }
  end
  here = named.select { |peer| peer.here && (world[:raid] || peer.member) }
  map = if !world[:in_world] || (!world[:raid] && own[:party].nil?) || here.empty? then []
        else
          rows = [own_row.call(own[:name], own[:front])] + here.map { |peer| row_of.call(peer, peer.state["flv"]) }
          rows = rows.map { |row| row[7] ? row : row[0, 8] + [nil] }
          rows.sort_by { |row| [row[7] ? 0 : 1, row[8] && row[8][1] ? 0 : 1, overview_downcase(row[1]), row[0]] }
        end
  { "players" => players, "lines" => lines, "party" => in_party ? party_list.call(false) : [], "raid_party" => in_party ? party_list.call(true) : [], "map" => map }
end

# The parties of the golden world of the lists, by the DLL's rules: a party's leader is the player
# who made it, else its player with the lowest id.
class GoldenOverviewParties
  # Makes the parties.
  #
  # @param own [String] The player's id.
  # @param party [String] The player's party's id.
  # @param peers [Array<OverviewPeer>] The other players.
  def initialize(own, party, peers)
    @own = own
    @party = party
    @peers = peers
  end

  # Lists a party's players but the player, each [id, seat].
  def players_of(id)
    found = id == @party ? @peers.select { |peer| peer.member } : @peers.select { |peer| peer.state["party"] == id }
    found.map { |peer| [peer.state["id"], peer.seat] }
  end

  # Tells a party's size.
  def size_of(id)
    return 0 if id.to_s.empty?

    players_of(id).size + (id == @party ? 1 : 0)
  end

  # Tells whether a player leads their party of two or more.
  def leads?(seat)
    id = seat == -1 ? @party : @peers.find { |peer| peer.seat == seat }.state["party"]
    return false if size_of(id) < 2

    candidates = players_of(id)
    candidates.unshift([@own, -1]) if id == @party
    maker = candidates.find { |player_id, _| player_id[0, 8] == id[0, 8] }
    (maker || candidates.min_by { |player_id, _| player_id })[1] == seat
  end
end

golden_own = OVERVIEW_ROW_CASES["own"]
golden_party = "p0000001p1"
golden_admitted = %w(me000001 p0000002 p0000003)
golden_peers = OVERVIEW_ROW_CASES["peers"].map do |peer|
  state = peer["state"]
  member = state["party"] == golden_party && (state["id"].to_s[0, 8] == golden_party[0, 8] || golden_admitted.include?(state["id"]))
  OverviewPeer.new(peer["seat"], state, member, state["map"].to_i == golden_own["map"])
end
golden_parties = GoldenOverviewParties.new(golden_own["id"], golden_party, golden_peers)
%w(classic raid).each do |world|
  raid = world == "raid"
  own = { :name => golden_own["name"], :place => golden_own["place"], :level => golden_own["level"], :front => raid ? golden_own["front"] : nil,
          :story => golden_own["story"], :ping => nil, :party => golden_party, :members => true }
  made = stand_in_overview_rows(own, golden_peers, { :raid => raid, :in_world => true }, golden_parties)
  expected = OVERVIEW_ROW_CASES[world]
  described = lambda { |rows| rows.map { |row| row.each_with_index.map { |value, index| [5, 6].include?(index) && value == "" ? nil : value } } }
  lines = made["lines"].map { |kind, value| kind == "place" ? [kind, value] : [kind, made["players"][value][0]] }
  %w(players party raid_party map).each do |list|
    raise "the overview rows stand-in lists #{list} of the #{world} world otherwise" unless described.call(made[list]) == expected[list]
  end
  raise "the overview rows stand-in lays the #{world} world's lines out otherwise" unless lines == expected["lines"]
end

# Finds a text's first sentence as OverviewPages.FirstSentence does.
#
# @param text [String, nil] The text.
# @return [String] The sentence; the whole text without an end.
def stand_in_first_sentence(text)
  text = text.to_s.strip
  offset = 0
  while (match = /[.!?♪…]+["'”’)」』）]*(?=\s|\z)|[。！？]+[」』）]*/.match(text, offset))
    word = text[0, match.begin(0)][/\S+\z/].to_s
    return text[0, match.end(0)].strip unless %w[Mt Dr Mr Mrs Ms St].include?(word)

    offset = match.end(0)
  end
  text
end

# Writes a share as whole parts, as no float crosses the bridge.
#
# @param share [Float] The share, 0 to 1.
# @return [Integer] The parts.
def overview_parts(share)
  (share * OVERVIEW_GAUGE_PARTS).round
end

# Writes the share of a raid boss's HP left, never 0% while any is.
#
# @param left [Float] The share.
# @return [String] Such as "68%".
def stand_in_share_text(left)
  "#{[(left * 100).round, left > 0 ? 1 : 0].max}%"
end

# The parts and routes of the world's story from which on a section's raid bosses show.
OVERVIEW_SECTION_REACH = { "Part 2" => %w(2 3 ad mr chaos), "Part 3" => %w(3 ad mr chaos), "Angelic Dominion" => %w(ad chaos), "Monster Realm" => %w(mr chaos),
                           "Chaos route" => %w(chaos), "Chaos Domain" => %w(chaos) }

# The names of the stats a tier changes.
OVERVIEW_TIER_STATS = { "mhp" => "HP", "def" => "DEF", "mdf" => "MDF", "atk" => "ATK", "mat" => "MAT", "agi" => "AGI", "luk" => "LUK", "mmp" => "MP" }

# Adds a group of a page and, while open, its entries or a text without any, as OverviewPages does.
#
# @param rows [Array] The page's rows.
# @param folds [Hash] Whether each group the player opened or folded is open, by [page, key].
# @param page [String] The page.
# @param key [String] The group.
# @param title [String] Its title.
# @param open [Boolean] Whether it starts open.
# @param entries [Array<Array>] Its entries, each [view, value].
# @param empty [String, nil] What it says without entries.
def stand_in_overview_group(rows, folds, page, key, title, open, entries, empty = nil)
  open = folds.fetch([page, key], open)
  rows << ["fold", [nil, (open ? "▾ " : "▸ ") + title, nil, false, nil], ["fold", key, title, open]]
  return unless open

  rows << ["none", empty] if entries.empty? && empty
  entries.each { |view, value| rows << ["entry", view, value] }
end

# Lists what can be picked of a page's rows: its groups and their entries.
#
# @param rows [Array] The rows.
# @return [Array<Integer>] Their places.
def stand_in_overview_picks(rows)
  (0...rows.size).reject { |index| rows[index][0] == "none" }
end

# Lays the World page out as OverviewPages.World does.
#
# @param request [Hash] What the topic takes.
# @param raid [Boolean] Whether the world is a Raid World.
# @param online [Integer] The players online, the player included.
# @param pools [Array<Array>] The world's pools in the order they were told, each [key, left, defeated, by].
# @param folds [Hash] See stand_in_overview_group.
# @return [Hash] The page.
def stand_in_overview_world(request, raid, online, pools, folds)
  seats = request["seats"].to_i
  story = raid ? "Story: #{stand_in_world_story(request['story'] && request['story']['part'])['text']}" : "Each party plays its leader's story."
  rows = []
  main = request["main"]
  rows << ["entry", ["Objective", stand_in_first_sentence(main[1][0]), nil, false, nil], ["note", "Objective", main[1]]] if main
  sections = raid ? stand_in_overview_bosses(request, pools) : []
  sections.each do |section, bosses|
    entries = bosses.map do |name, tier, left, defeated, by|
      [[nil, name, defeated ? "Defeated" : stand_in_share_text(left), defeated, defeated ? nil : overview_parts(left)],
       ["boss", section, name, defeated, by, stand_in_overview_boss_pane(section, tier, left, defeated, by, request["tiers"])]]
    end
    stand_in_overview_group(rows, folds, "world", section, "#{section} (#{bosses.size})", true, entries)
  end
  rows << ["none", raid ? "No raid bosses yet." : "Raid bosses fight in Raid Worlds."] if sections.empty?
  lines = ["Players online: #{seats > 0 ? "#{online} / #{seats}" : online}", story]
  { "head" => { "title" => nil, "note" => nil, "lines" => lines, "entry" => nil }, "rows" => rows, "picks" => stand_in_overview_picks(rows) }
end

# Sums the raid bosses up by the story's sections as OverviewBosses.Sections does.
#
# @param request [Hash] "sections", "bosses" and "story".
# @param pools [Array<Array>] See stand_in_overview_world.
# @return [Array<Array>] Each section with its bosses, each [name, tier, left, defeated, by].
def stand_in_overview_bosses(request, pools)
  by_boss = {}
  pools.each_with_index { |(key, left, defeated, by), told| (by_boss[key.sub(/#\d+\z/, "")] ||= []) << [left, defeated, by.to_s, told] }
  table = request["bosses"]
  story = request["story"]
  sum = lambda do |name, tier, entries|
    next [name, tier, 1.0, false, nil] if entries.empty?

    hurt = entries.reject { |entry| entry[2].empty? }.max_by { |entry| entry[3] }
    [name, tier, entries.inject(0.0) { |total, entry| total + entry[0] } / entries.size, entries.all? { |entry| entry[1] }, hurt && hurt[2]]
  end
  listed = []
  request["sections"].each do |section, keys|
    names = keys + by_boss.keys.select { |name| !keys.include?(name) && (table[name] || [])[0] == section }.sort
    reach = OVERVIEW_SECTION_REACH[section]
    reached = story && (reach.nil? || reach.any? { |part| part == story["part"] || Array(story["done"]).include?(part) })
    next unless reached || names.any? { |name| by_boss.key?(name) }

    listed << [section, names.map { |name| sum.call(name, (table[name] || [])[1], by_boss.delete(name) || []) }]
  end
  others = by_boss.keys.sort.map { |name| sum.call(name, nil, by_boss[name]) }
  listed << ["Other", others] unless others.empty?
  listed
end

# Lays a raid boss's pane out as OverviewBosses.Pane does.
#
# @return [Array<Array>] The lines, each [kind, text, share in whole parts].
def stand_in_overview_boss_pane(section, tier, left, defeated, by, tiers)
  lines = [["text", section, 0]]
  stats = tier && tiers[tier]
  unless stats.nil? || stats.empty?
    text = stats.map do |stat, factor|
      value = factor.to_f
      "#{OVERVIEW_TIER_STATS[stat] || stat.upcase} x#{value == value.round ? value.round : value}"
    end.join(", ")
    lines << ["text", "Tier #{tier}: enemies have #{text}.", 0]
  end
  lines << ["gauge", defeated ? "Defeated" : stand_in_share_text(left), overview_parts(defeated ? 0.0 : left)]
  lines << ["text", "Last hurt by #{by}.", 0] if by
  lines
end

# Writes a quest's entry as OverviewTopics describes it.
#
# @param kind [String] "main", "side" or "companion".
# @param told [Array] [speaker, texts].
# @param number [Integer, nil] A side quest's number.
# @return [Array] The view and the entry.
def stand_in_overview_quest(kind, told, number)
  speaker, texts = told
  name = { "main" => "Main quest", "side" => "Side quest #{number}", "companion" => "Request" }[kind]
  view = [kind == "side" ? "#{number}." : speaker.to_s, stand_in_first_sentence(texts[0]), nil, false, nil]
  [view, ["quest", kind, speaker, texts, number, speaker ? "#{name} · #{speaker}" : name]]
end

# Lays the Quests page out as OverviewPages.Quests does.
#
# @param request [Hash] "main", "side" and "companion".
# @param folds [Hash] See stand_in_overview_group.
# @return [Hash] The page.
def stand_in_overview_quests(request, folds)
  main = request["main"]
  told = main ? stand_in_overview_quest("main", main, nil)[1] : nil
  rows = []
  sides = request["side"].each_with_index.map { |quest, index| stand_in_overview_quest("side", quest, index + 1) }
  stand_in_overview_group(rows, folds, "quests", "side", "Side quests (#{sides.size})", true, sides, "None right now.")
  companions = request["companion"].map { |quest| stand_in_overview_quest("companion", quest, nil) }
  stand_in_overview_group(rows, folds, "quests", "companion", "Companion quests (#{companions.size})", true, companions, "None right now.")
  head = { "title" => "Main quest", "note" => nil, "lines" => [main ? stand_in_first_sentence(main[1][0]) : "None right now."], "entry" => told }
  { "head" => head, "rows" => rows, "picks" => (told ? [-1] : []) + stand_in_overview_picks(rows) }
end

# Lays the Unlocks page out as OverviewPages.Unlocks does.
#
# @param request [Hash] "target", "level" and "unlocks".
# @param folds [Hash] See stand_in_overview_group.
# @return [Hash] The page.
def stand_in_overview_unlocks(request, folds)
  target = request["target"]
  level = request["level"]
  levels = request["unlocks"].each_with_index.group_by { |unlock, _| unlock[0] }.sort.map do |at, pairs|
    got = pairs.all? { |unlock, _| unlock[2] }
    due = pairs.any? { |unlock, _| unlock[3] }
    [["Level #{at}", pairs.map { |unlock, _| unlock[1] }.join(", "), due ? "Due" : nil, got, nil], ["level", at, pairs.map { |_, index| index }, got, due]]
  end
  passed, coming = levels.partition { |_, value| value[3] }
  rows = []
  stand_in_overview_group(rows, folds, "unlocks", "passed", "Passed (#{passed.size})", false, passed) unless passed.empty?
  levels.empty? ? rows << ["none", "Nothing to catch up with yet."] : stand_in_overview_group(rows, folds, "unlocks", "coming", "Coming up (#{coming.size})", true, coming)
  head = { "title" => target ? "Catch-up EXP until level #{target}" : "Catch-up EXP", "note" => level ? "Your level #{level}" : nil,
           "lines" => target ? [] : ["Starts once the world's story raises the level cap."], "entry" => nil }
  { "head" => head, "rows" => rows, "picks" => stand_in_overview_picks(rows) }
end

# Writes a golden page in the form the topic answers: a group's row as its view and its entry, a
# quest without its first sentence, a raid boss without its tier and share, each gauge in whole parts.
#
# @param model [Hash] The golden page: "head" ([title, note, lines]), "rows" and "picks".
# @return [Array] The head's title, note and lines, the rows and the picks.
def overview_topic_form(model)
  rows = model["rows"].map do |row|
    next row if row[0] == "none"
    next ["fold", row[4], ["fold", row[1], row[2], row[3]]] if row[0] == "fold"

    value = row[2]
    value = case value[0]
            when "quest" then value[0, 6]
            when "boss" then value[0, 3] + value[5, 2] + [value[7].map { |line, first, second| line == "gauge" ? [line, second, overview_parts(first)] : [line, first, 0] }]
            else value
            end
    ["entry", row[1][0, 4] + [row[1][4] && overview_parts(row[1][4])], value]
  end
  model["head"] + [rows, model["picks"]]
end

# Writes a page the stand-ins laid out as overview_topic_form writes the golden ones.
#
# @param page [Hash] The page.
# @return [Array] The head's title, note and lines, the rows and the picks.
def overview_page_form(page)
  [page["head"]["title"], page["head"]["note"], page["head"]["lines"], page["rows"], page["picks"]]
end

OVERVIEW_PAGE_CASES["sentences"].each do |text, first|
  raise "the first sentence stand-in finds #{stand_in_first_sentence(text).inspect} in #{text.inspect}" unless stand_in_first_sentence(text) == first
end
OVERVIEW_PAGE_CASES["shares"].each do |left, text|
  raise "the share stand-in writes #{left} otherwise" unless stand_in_share_text(left) == text
end
OVERVIEW_PAGE_CASES["world"].each do |scenario|
  pools = scenario["pools"].sort_by { |pool| pool[5] }.map { |key, left, _max, defeated, by, _at| [key, defeated ? 0.0 : left, defeated, by] }
  table = {}
  scenario["bosses"].each { |name, facts| table[name] = facts }
  tiers = {}
  scenario["tiers"].each { |tier, stats| tiers[tier] = stats }
  request = { "seats" => scenario["seats"], "story" => scenario["story"], "main" => scenario["main"], "sections" => scenario["sections"], "bosses" => table, "tiers" => tiers }
  folds = {}
  scenario["closed"].each { |key| folds[["world", key]] = false }
  made = overview_page_form(stand_in_overview_world(request, scenario["raid"], scenario["online"], pools, folds))
  # The scripts wrote the World page's title and note; the DLL leaves them to the scripts.
  raise "the World page stand-in lays #{scenario['name']} out otherwise" unless made[2..-1] == overview_topic_form(scenario["model"])[2..-1]
end
OVERVIEW_PAGE_CASES["quests"].each do |scenario|
  folds = {}
  scenario["closed"].each { |key| folds[["quests", key]] = false }
  made = overview_page_form(stand_in_overview_quests(scenario, folds))
  raise "the Quests page stand-in lays #{scenario['name']} out otherwise" unless made == overview_topic_form(scenario["model"])
end
OVERVIEW_PAGE_CASES["unlocks"].each do |scenario|
  folds = {}
  scenario["opened"].each { |key| folds[["unlocks", key]] = true }
  made = overview_page_form(stand_in_overview_unlocks(scenario, folds))
  raise "the Unlocks page stand-in lays #{scenario['name']} out otherwise" unless made == overview_topic_form(scenario["model"])
end

# The parties of the test's world, as MGQ_MpCoop tells them.
class LiveOverviewParties
  # Tells a party's size.
  def size_of(id)
    MGQ_MpCoop.size_of(id)
  end

  # Tells whether a player leads their party of two or more.
  def leads?(seat)
    MGQ_MpCoop.leads?(seat == -1 ? :me : MGQ_MpOverworldSync::Peers.at(seat))
  end
end

# What the player told the others in the test, which the stand-ins keep.
$overview_state = StandInOverviewState.new

# Answers the World overview's topics of the DLL from the test's world, with the stand-ins above:
# overview.tell, overview.fields, overview.rows (built anew at each ask, a new serial once they
# changed), overview.world (the pools of MGQ_MpRaidPool in the order of their times), overview.quests,
# overview.unlocks and overview.fold. tell_overview_read posts the DLL's overview.read.
#
# @param fake [FakeBridge] The bridge.
def answer_overview_models(fake)
  folds = {}
  serial = 0
  built = nil
  fake.answer("overview.tell") do |request|
    $overview_state.take(request["lv"].to_i, request["flv"] && request["flv"].to_i, stand_in_story(request["story"]), request["battle"] == true)
  end
  fake.answer("overview.fields") { |place| $overview_state.fields(place, MGQ_MpCoop::Scope.raid?) }
  fake.answer("overview.rows") do |request|
    state = $overview_state
    own = { :name => request["name"].to_s, :place => state.place, :level => state.level, :front => state.front, :story => state.story,
            :ping => MGQ_MpOverworldSync::Ping.measured, :party => MGQ_MpCoop::Party.id, :members => !MGQ_MpCoop::Party.members.empty? }
    here = MGQ_MpCoop::Scope.peers_here
    peers = MGQ_MpOverworldSync::Peers.all.map { |peer| OverviewPeer.new(peer.seat, peer.state, peer.member ? true : false, here.include?(peer)) }
    lists = stand_in_overview_rows(own, peers, { :raid => MGQ_MpCoop::Scope.raid?, :in_world => MGQ_MpOverworldSync.in_world? }, LiveOverviewParties.new)
    serial += 1 unless lists == built
    built = lists
    request["serial"] == serial ? nil : lists.merge("serial" => serial)
  end
  fake.answer("overview.world") do |request|
    pools = MGQ_MpRaidPool.pools.sort_by { |_, pool| pool.at.to_f }.map { |key, pool| [key, MGQ_MpRaidPool.left_now(pool), pool.defeated ? true : false, pool.by.to_s] }
    online = 1 + MGQ_MpOverworldSync::Peers.all.count { |peer| peer.state.key?("name") }
    stand_in_overview_world(request, MGQ_MpCoop::Scope.raid?, online, pools, folds)
  end
  fake.answer("overview.quests") { |request| stand_in_overview_quests(request, folds) }
  fake.answer("overview.unlocks") { |request| stand_in_overview_unlocks(request, folds) }
  fake.answer("overview.fold") { |request| folds[[request["page"], request["key"]]] = request["open"] == true; nil }
end

# Posts the DLL's ask to read the player's levels and story, which the next frame's drain hands on.
#
# @param fake [FakeBridge] The bridge.
def tell_overview_read(fake)
  fake.post("overview.read", true)
end
