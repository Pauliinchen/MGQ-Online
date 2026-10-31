#----------------------------------------------------------------
#  make_models.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Named the commit whose scripts it records
#                            - Recorded the World page with the boss tables and the world story it reads
#                            - Left the Frontline level unread in a Classic world
#                            - Created
#
#----------------------------------------------------------------

# Writes state.json, rows.json and pages.json: what world_overview.rbx and world_overview_pages.rbx
# kept of the player, listed of the players and laid out on the World, Quests and Unlocks pages
# before those models moved to MGQOnline.Game/Overview, as golden cases the C# tests replay. It
# runs the scripts' own methods over stand-ins; make_fixtures.rb runs it.
#
#   git archive d65f17b4 GameScript/Multiplayer/Scripts | tar -x -C <old tree>
#   ruby fixtures/overview/make_models.rb <old tree>/GameScript/Multiplayer/Scripts

require "json"

SCRIPTS = ARGV[0] || abort("Name the Scripts folder of commit d65f17b4, see the header.")

# Reads a script of the Scripts folder.
#
# @param name [String] The script's file name.
# @return [String] Its source.
def script(name)
  File.read(File.join(SCRIPTS, name), :encoding => "UTF-8")
end

OVERVIEW = script("world_overview.rbx")
PAGES = script("world_overview_pages.rbx")
OVERWORLD = script("overworld.rbx")
BOSSES = script("battles_raid_bosses.rbx")
POOL = script("battles_raid_pool.rbx")

# Finds a constant of a script, up to the blank line after it.
#
# @param source [String] The script.
# @param name [String] The constant.
# @return [String] Its source.
def constant(source, name)
  source[/^  #{name} = Struct\.new[^\n]*do\r?\n.*?^  end\r?\n/m] || source[/^  #{name} = .*?(?=\n\r?\n)/m] or raise "no #{name}"
end

# Finds a module method of a script.
#
# @param source [String] The script.
# @param name [String] The method.
# @return [String] Its source.
def method_of(source, name)
  source[/^  def self\.#{Regexp.escape(name)}(?=[\s(]).*?\n  end\r?\n/m] or raise "no #{name}"
end

# Stands in for the game's scene manager: the map is always open.
class Scene_Map; end

# Stands in for the game's scenes.
module SceneManager
  def self.scene
    Scene_Map.new
  end
end

# A character of the formation, by its base level.
Actor = Struct.new(:base_level)

# Stands in for the game's party.
class RecordedParty
  attr_accessor :battle_members
end

# Stands in for the game's map.
class RecordedMap
  attr_accessor :display_name, :map_id
end

$game_party = RecordedParty.new
$game_map = RecordedMap.new

# Stands in for the multiplayer mod's player.
module MGQ_Multiplayer
  module Player
    def self.name
      "Me"
    end
  end
end

# Stands in for whether a co-op battle runs.
module MGQ_MpBattlesCoop
  class << self
    attr_accessor :running
  end

  def self.active?
    running == true
  end
end

# Stands in for the player's share of the squad: the first of the order.
module MGQ_MpCoopSquad
  class << self
    attr_accessor :order
  end

  def self.own_share
    nil
  end

  def self.own_order
    order
  end
end

# Stands in for the world room's players.
module MGQ_MpOverworldSync
  # A player as overworld_sync.rbx keeps them.
  module Peers
    Peer = Struct.new(:seat, :state, :ghost, :member, :away)

    class << self
      attr_accessor :list
    end

    def self.all
      list
    end

    def self.present
      all.select { |peer| peer.away.nil? }
    end

    def self.on_this_map?(peer)
      peer.away.nil? && peer.state["map"].to_i == $game_map.map_id
    end
  end

  # Stands in for the player's own ping, which the tests leave unmeasured.
  module Ping
    def self.measured
      nil
    end
  end

  def self.in_world?
    true
  end
end

# Stands in for the parties, by the DLL's rules (MGQOnline.Game/World/Party.cs): a party's leader is
# the player who made it, else its player with the lowest id.
module MGQ_MpCoop
  MAX_PLAYERS = 4

  # The player's party.
  module Party
    class << self
      attr_accessor :id, :admitted
    end

    def self.members
      MGQ_MpOverworldSync::Peers.all.select { |peer| peer.member }
    end
  end

  # Stands in for the scope of the world.
  module Scope
    class << self
      attr_accessor :raid
    end

    def self.raid?
      raid == true
    end

    def self.peers_here
      MGQ_MpOverworldSync::Peers.present.select { |peer| peer.state["map"].to_i == $game_map.map_id && (raid? || peer.member) }
    end
  end

  def self.players_of(id)
    id == Party.id ? Party.members : MGQ_MpOverworldSync::Peers.all.select { |peer| peer.state["party"] == id }
  end

  def self.size_of(id)
    return 0 if id.to_s.empty?

    players_of(id).size + (id == Party.id ? 1 : 0)
  end

  def self.leader_of(id)
    candidates = players_of(id).map { |peer| [peer.state["id"], peer] }
    candidates.unshift(["me000001", :me]) if id == Party.id
    maker = candidates.find { |player_id, _| player_id[0, 8] == id[0, 8] }
    maker ? maker[1] : candidates.min_by { |player_id, _| player_id }[1]
  end

  def self.leads?(peer)
    id = peer == :me ? Party.id : peer.state["party"]
    size_of(id) >= 2 && (peer == :me ? leader_of(id) == :me : leader_of(id).equal?(peer))
  end
end

# Stands in for the overworld's labels: a ping and a scene as they were told.
module MGQ_MpOverworld
  STATE_ICONS = Hash.new { |_, scene| scene }

  def self.ping_label(ping)
    ping.to_s.empty? ? nil : ping.to_s
  end
end
MGQ_MpOverworld.module_eval(method_of(OVERWORLD, "party_badge"))

# The places in the story as the DLL writes them, from story.json.
STORY_TEXTS = JSON.parse(File.read(File.join(__dir__, "story.json")))["texts"].each_with_object({}) { |entry, texts| texts[entry["code"].to_s] = entry["text"] }

# The world's places in the story as the DLL writes them, by the part, from story.json.
WORLD_TEXTS = JSON.parse(File.read(File.join(__dir__, "story.json")))["worlds"].each_with_object({}) { |entry, texts| texts[entry["part"]] = entry["text"] }

# The raid bosses' sections and tiers, as world_overview_pages.rbx asks battles_raid_bosses.rbx.
module MGQ_MpRaidBosses
  class << self
    attr_accessor :listed, :table
  end

  def self.sections
    listed
  end

  def self.section(name)
    entry = table[name.to_s]
    entry && entry[0]
  end

  def self.key_tier(name)
    entry = table[name.to_s]
    entry && entry[1]
  end

  def self.tier(_troop)
    nil
  end
end
MGQ_MpRaidBosses.module_eval(constant(BOSSES, "TIERS"))

# A pool as the raid pool keeps it.
Pool = Struct.new(:left, :max, :defeated, :by, :at)

# Stands in for the raid pools, told at fixed moments so none fills up.
module MGQ_MpRaidPool
  class << self
    attr_accessor :kept
  end

  def self.pools
    kept.dup
  end

  def self.left_now(pool, _now = nil)
    pool.defeated ? 0.0 : pool.left.to_f
  end

  def self.troop_of_key(_name)
    nil
  end
end
MGQ_MpRaidPool.module_eval(method_of(POOL, "boss_key"))

# Stands in for the world's story as the relay told it.
module MGQ_MpWorldStory
  class << self
    attr_accessor :world
  end
end

# Stands in for the open world.
module MGQ_MpWorld
  World = Struct.new(:seats)

  class << self
    attr_accessor :world
  end
end

# Stands in for the catch-up.
module MGQ_MpWorldCatchup
  Unlock = Struct.new(:level, :kind, :name, :icon, :got, :due, :id, :gains)

  class << self
    attr_accessor :listed, :counted_level
  end

  def self.unlocks
    listed
  end

  def self.counts?(_actor)
    true
  end
end

# Stands in for the catch-up experience.
module MGQ_MpWorldCatchupExp
  class << self
    attr_accessor :target
  end
end

# The overview's own methods, recorded.
module MGQ_MpWorldOverview
  def self.log(line)
    (@logged ||= []) << line
  end

  def self.log_once(*); end

  def self.close(*); end

  def self.take_logged
    taken = @logged || []
    @logged = []
    taken
  end
end

%w(READ_FRAMES LEVEL_HEADING EXP_HEADING EXP_HEADING_NONE NO_CATCH_UP NOTHING_UNLOCKED DONE DUE OBJECTIVE_LABEL QUEST_HEADINGS
   NO_QUESTS QUEST_TITLES TITLE_JOIN SENTENCE_END ABBREVIATIONS PLAYERS_OF OTHER_SECTION SECTION_REACH SHARE_LEFT PERCENT
   UNTOUCHED UNNAMED_PLACE WORLD_ICON Row Boss Quest).each { |name| MGQ_MpWorldOverview.module_eval(constant(OVERVIEW, name)) }
%w(tick forget state_fields place formation_level front_level base_level_of rows own_row row_of party_rows raid_party_rows
   map_rows level_text lines).each { |name| MGQ_MpWorldOverview.module_eval(method_of(OVERVIEW, name)) }
%w(Head Model Fold Note BossEntry Level RowView Pane PLAYERS_LINE STORY_LINE CLASSIC_STORY BOSS_SECTION NO_BOSSES CLASSIC_BOSSES
   TIER_LINE TIER_STAT TIER_STATS LAST_HURT DEFEATED YOUR_LEVEL_NOTE PASSED COMING_UP FOLDED UNFOLDED).each do |name|
  MGQ_MpWorldOverview.module_eval(constant(PAGES, name))
end
%w(world_model quest_model unlock_model add_group fold_open? picks_of row_view boss_pane first_sentence boss_sections reached?
   section_of tier_of boss_of share_text).each { |name| MGQ_MpWorldOverview.module_eval(method_of(PAGES, name)) }

# The overview's stand-ins for what stays in the scripts or asks the DLL.
module MGQ_MpWorldOverview
  # Stands in for another mod's entry, which no recorded page holds.
  ModEntry = Struct.new(:page)

  class << self
    attr_accessor :told_story, :main, :sides, :companions
  end

  def self.story_code
    told_story
  end

  def self.story_text(code)
    STORY_TEXTS.fetch(code.to_s)
  end

  def self.call_of(_peer)
    nil
  end

  def self.world_name
    "World"
  end

  def self.world_note
    "Note"
  end

  def self.world_story_text
    counters = MGQ_MpWorldStory.world
    WORLD_TEXTS.fetch(counters ? counters["part"].to_s : nil)
  end

  def self.main_quest
    main
  end

  def self.side_quests
    sides
  end

  def self.companion_quests
    companions
  end

  def self.exp_cells(*)
    []
  end

  def self.looks(*)
    nil
  end
end

# Plays the tick over frames and records the fields told after each step.
#
# @return [Array<Hash>] The steps with what they left.
def state_cases
  overview = MGQ_MpWorldOverview
  steps = [
    { "frames" => 1, "in_world" => false },
    { "frames" => 1, "in_world" => true, "raid" => true, "level" => 30, "front" => 25, "story" => "2:alice", "place" => "Ilias Village" },
    { "frames" => 179, "in_world" => true, "raid" => true, "level" => 31, "front" => 26, "story" => "2:alice", "place" => "Ilias Village" },
    { "frames" => 1, "in_world" => true, "raid" => true, "level" => 31, "front" => 26, "story" => "2:alice", "place" => "Iliasburg" },
    { "frames" => 180, "in_world" => true, "raid" => true, "battle" => true, "level" => 5, "front" => 5, "story" => "3:destroyer", "place" => "" },
    { "frames" => 180, "in_world" => true, "raid" => true, "level" => 5, "front" => 4, "story" => "3:destroyer", "place" => "" },
    { "frames" => 180, "in_world" => true, "raid" => true, "level" => 5, "front" => 4, "story" => "3:destroyer", "place" => "" },
    { "frames" => 1, "in_world" => false },
    { "frames" => 1, "in_world" => true, "raid" => false, "level" => 40, "story" => "", "place" => "Sabasa" },
    { "frames" => 1, "in_world" => false },
    { "frames" => 1, "in_world" => true, "raid" => true, "battle" => true, "level" => 50, "front" => 50, "story" => "1", "place" => "Sabasa" },
  ]
  steps.map do |step|
    MGQ_MpCoop::Scope.raid = step["raid"]
    MGQ_MpBattlesCoop.running = step["battle"]
    $game_party.battle_members = [Actor.new(step["level"].to_i), Actor.new(1)]
    MGQ_MpCoopSquad.order = [Actor.new(step["front"].to_i), Actor.new(99)]
    overview.told_story = step["story"].to_s
    $game_map.display_name = step["place"].to_s
    step["frames"].times { overview.tick(step["in_world"]) }
    step.merge("fields" => overview.state_fields, "logged" => overview.take_logged)
  end
end

# The other players of the rows' world: seat, id, name, party, map, and what they told.
PEERS = [
  [1, "p0000001", "Granberia", "p0000001p1", 3, { "lv" => "61", "flv" => "58", "progress" => "2:alice", "ping" => "80", "place" => "Ilias Village", "party_members" => "me000001,p0000002,p0000003" }],
  [2, "p0000002", "alma", "p0000001p1", 3, { "lv" => "12", "flv" => "12", "progress" => "1", "place" => "Ilias Village", "scene" => "battle" }],
  [3, "p0000003", "Tamamo", "p0000001p1", 7, { "lv" => "0", "progress" => "3:chaos", "place" => "Sabasa Castle B2F" }],
  [4, "p0000004", "Erubetie", "", 3, { "lv" => "40", "flv" => "35", "progress" => "2:ilias", "place" => "Ilias Village", "ping" => "1200" }],
  [5, "p0000005", "zed", "", 3, { "lv" => "7", "progress" => "", "place" => "" }],
  [6, "p0000006", "Alice", "", 3, { "lv" => "99", "flv" => "99", "progress" => "3:destroyer", "place" => "Ilias Village" }],
  [7, "p0000007", "Sara", "", 9, { "lv" => "20", "progress" => "2:alice", "place" => "iliasburg" }],
  [8, "p0000008", "Micaela", "", 9, { "lv" => "25", "progress" => "3:judgment", "place" => "Iliasburg Church" }],
  [9, "p0000009", "Lazarus", "", 10, { "lv" => "33", "progress" => "3:other", "place" => "Pocket Monster Lord's Castle" }],
  [10, "p0000010", "Sonya", "p0000010pb", 3, { "lv" => "15", "flv" => "15", "progress" => "1", "place" => "Ilias Village", "party_members" => "p0000011,p0000012" }],
  [11, "p0000011", "Amira", "p0000010pb", 3, { "lv" => "16", "flv" => "11", "progress" => "1", "place" => "Ilias Village" }],
  [12, "p0000012", "chrome", "p0000010pb", 11, { "lv" => "17", "progress" => "1", "place" => "Enrika" }],
  [13, "p0000013", "Promestein", "", 11, { "lv" => "70", "progress" => "3:chaos", "place" => "Enrika" }],
  [14, "p0000014", "Lily", "", 11, { "lv" => "45", "progress" => "2:ilias", "place" => "Enrika" }],
  [15, "p0000015", "Kitsune", "", 3, { "progress" => "1", "place" => "Ilias Village" }],
  [16, "p0000016", "Nanabi", "", 12, { "lv" => "2", "progress" => "1", "place" => "" }],
  [17, "p0000017", "Yao", "", 12, { "lv" => "3", "progress" => "1", "place" => "" }],
  [18, "p0000018", "Shirome", "", 13, { "lv" => "18", "progress" => "2:alice", "place" => "Yamatai Village" }],
  [19, "p0000019", "Kanade", "", 13, { "lv" => "19", "progress" => "2:alice", "place" => "Yamatai Village" }],
  [20, "p0000020", "Ilias", "p0000020pc", 14, { "lv" => "80", "progress" => "3:judgment", "place" => "Heaven", "party_members" => "p0000021" }],
  [21, "p0000021", "lucifina", "p0000020pc", 14, { "lv" => "81", "progress" => "3:judgment", "place" => "Heaven" }],
  [22, "p0000022", "Black Alice", "", 15, { "lv" => "90", "progress" => "3:chaos", "place" => "Remina" }],
  [23, "p0000023", "Ammon", "", 15, { "lv" => "50", "progress" => "3:chaos", "place" => "Remina" }],
  [24, "p0000024", "Heinrich", "", 3, { "lv" => "60", "flv" => "61", "progress" => "3:destroyer", "place" => "Ilias Village" }],
  [25, "p0000025", "Ellie", "", 16, { "lv" => "8", "progress" => "1", "place" => "Saloon" }],
  [26, "p0000026", "Hans", "", 16, { "lv" => "9", "progress" => "1", "place" => "Saloon" }],
  [27, "p0000027", "Gnome", "", 17, { "lv" => "21", "progress" => "2:alice", "place" => "Safaru Ruins" }],
  [28, "p0000028", "Sylph", "", 17, { "lv" => "22", "progress" => "2:alice", "place" => "Forest of Spirits" }],
  [29, "p0000029", "Undine", "", 18, { "lv" => "23", "progress" => "2:alice", "place" => "Undine's Spring" }],
  [30, "p0000030", "Salamander", "p0000099pd", 3, { "lv" => "24", "progress" => "2:alice", "place" => "Ilias Village" }],
  [31, "p0000031", "Luka", "p0000099pd", 3, { "lv" => "26", "progress" => "2:alice", "place" => "Ilias Village" }],
]

# Records the rows of the rows' world: the player in Granberia's party on map 3.
#
# @return [Hash] The world and the rows.
def rows_cases
  overview = MGQ_MpWorldOverview
  MGQ_MpCoop::Party.id = "p0000001p1"
  admitted = %w(me000001 p0000002 p0000003)
  $game_map.map_id = 3
  $game_map.display_name = "Ilias Village"
  peers = PEERS.map do |seat, id, name, party, map, told|
    state = { "id" => id, "name" => name, "party" => party, "map" => map.to_s }.merge(told)
    member = party == MGQ_MpCoop::Party.id && (id[0, 8] == party[0, 8] || admitted.include?(id))
    MGQ_MpOverworldSync::Peers::Peer.new(seat, state, nil, member, nil)
  end
  peers << MGQ_MpOverworldSync::Peers::Peer.new(32, { "id" => "p0000032", "map" => "3" }, nil, false, nil)
  MGQ_MpOverworldSync::Peers.list = peers
  overview.instance_variable_set(:@level, 30)
  overview.instance_variable_set(:@story, "2:alice")
  described = lambda { |rows| rows.map { |row| describe_row(row) } }
  cases = { "own" => { "id" => "me000001", "name" => "Me", "map" => 3, "place" => "Ilias Village", "level" => 30, "story" => "2:alice", "front" => 28 },
            "peers" => peers.map { |peer| { "seat" => peer.seat, "state" => peer.state } } }
  [false, true].each do |raid|
    MGQ_MpCoop::Scope.raid = raid
    overview.instance_variable_set(:@front, raid ? 28 : nil)
    rows = overview.rows
    cases[raid ? "raid" : "classic"] = {
      "players" => described.call(rows),
      "lines" => overview.lines(rows).map { |kind, value| kind == :place ? ["place", value] : ["player", key_of(value)] },
      "party" => described.call(overview.party_rows),
      "raid_party" => described.call(overview.raid_party_rows),
      "map" => described.call(overview.map_rows),
    }
  end
  cases
end

# Tells which player a row is.
#
# @param row [MGQ_MpWorldOverview::Row] The row.
# @return [Integer] The seat, -1 for the player.
def key_of(row)
  row.player == :me ? -1 : row.player.seat
end

# Describes a row for the golden file.
#
# @param row [MGQ_MpWorldOverview::Row] The row.
# @return [Array] Its seat, name, place, level, story, ping, scene, member and badge.
def describe_row(row)
  [key_of(row), row.name, row.place, row.level, row.story, row.ping, row.icon, row.member, row.badge]
end

# Describes a page's model for the golden file.
#
# @param model [MGQ_MpWorldOverview::Model] The model.
# @param unlocks [Array] The unlocks the page was built from.
# @return [Hash] Its head, rows and picks.
def describe_model(model, unlocks = [])
  overview = MGQ_MpWorldOverview
  head = model.head
  rows = model.rows.map do |kind, value|
    case kind
    when :none then ["none", value]
    when :fold then ["fold", value.key.to_s, value.title, value.open, overview.row_view(value).to_a]
    else ["entry", overview.row_view(value).to_a, describe_entry(value, unlocks)]
    end
  end
  picks = model.picks.map { |pick| model.rows.index { |_, value| value.equal?(pick) } || -1 }
  { "head" => [head.title, head.note, head.lines], "rows" => rows, "picks" => picks }
end

# Describes an entry of a page for the golden file.
#
# @param entry [Object] A Quest, Note, BossEntry or Level.
# @param unlocks [Array] The unlocks the page was built from.
# @return [Array] What it holds.
def describe_entry(entry, unlocks)
  overview = MGQ_MpWorldOverview
  case entry
  when overview::Quest then ["quest", entry.kind.to_s, entry.speaker, entry.texts, entry.number, entry.title, entry.first]
  when overview::Note then ["note", entry.title, entry.texts]
  when overview::BossEntry
    boss = entry.boss
    ["boss", entry.section, boss.name, boss.tier, boss.left, boss.defeated, boss.by, overview.boss_pane(entry).lines]
  when overview::Level
    ["level", entry.level, entry.unlocks.map { |unlock| unlocks.index { |one| one.equal?(unlock) } }, entry.got, entry.due]
  end
end

# The story's sections of the World page's cases, with their bosses in story order.
SECTIONS = [
  ["Part 1", ["Granberia (cap 20)", "Alma Elma"]],
  ["Part 2", ["Tamamo (cap 61)", "Erubetie"]],
  ["Angelic Dominion", ["Ilias"]],
  ["Chaos Domain", ["Black Alice"]],
  ["Optional", ["Sisel's Mother"]],
]

# The section and tier of every name the tables know, as Ruby hands them until 7.2c.
TABLE = {
  "Granberia (cap 20)" => ["Part 1", 0], "Alma Elma" => ["Part 1", 1], "Tamamo (cap 61)" => ["Part 2", 4],
  "Erubetie" => ["Part 2", 5], "Ilias" => ["Angelic Dominion", 9], "Black Alice" => ["Chaos Domain", 6],
  "Sisel's Mother" => ["Optional", 2], "Sisel" => ["Part 2", 3],
}

# Records the World page: a Raid World with pools told, one without, and a Classic world.
#
# @return [Array<Hash>] The cases.
def world_cases
  overview = MGQ_MpWorldOverview
  MGQ_MpRaidBosses.listed = SECTIONS
  MGQ_MpRaidBosses.table = TABLE
  pools = [
    ["Alma Elma#0", 0.5, 4000, false, "", 10], ["Alma Elma#1", 0.0, 4000, true, "Hero", 20],
    ["Black Alice#2", 0.0, 9000, true, "Creator", 40], ["Erubetie#0", 0.004, 6000, false, "", 11],
    ["Kitsune#0", 0.75, 900, false, "", 12], ["Nanabi", 0.3333, 900, false, "", 13],
    ["Sisel#0", 0.995, 5000, false, "", 14], ["Tamamo (cap 61)#0", 0.0, 7000, true, "Sara", 30],
  ]
  scenarios = [
    { "name" => "raid", "raid" => true, "online" => 3, "seats" => 8, "story" => { "part" => "2", "done" => [] }, "pools" => pools,
      "main" => [nil, ["Head for Iliasburg. Mt. Saint Amos waits beyond.", "Second message."]], "closed" => ["Optional"] },
    { "name" => "raid route", "raid" => true, "online" => 1, "seats" => 0, "story" => { "part" => "chaos", "done" => ["ad"] }, "pools" => [], "main" => nil, "closed" => [] },
    { "name" => "raid untold", "raid" => true, "online" => 2, "seats" => 4, "story" => nil, "pools" => [], "main" => nil, "closed" => [] },
    { "name" => "classic", "raid" => false, "online" => 5, "seats" => 16, "story" => nil, "pools" => pools, "main" => nil, "closed" => [] },
  ]
  scenarios.map do |scenario|
    MGQ_MpCoop::Scope.raid = scenario["raid"]
    MGQ_MpWorld.world = MGQ_MpWorld::World.new(scenario["seats"])
    MGQ_MpWorldStory.world = scenario["story"]
    MGQ_MpRaidPool.kept = scenario["pools"].each_with_object({}) { |(key, left, max, defeated, by, at), kept| kept[key] = Pool.new(left, max, defeated, by, at) }
    main = scenario["main"]
    overview.main = main ? overview::Quest.new(:main, main[0], main[1], nil) : nil
    overview.instance_variable_set(:@folds, { :world => scenario["closed"].each_with_object({}) { |key, folds| folds[key] = false } })
    online = scenario["online"]
    overview.define_singleton_method(:rows) { Array.new(online) }
    scenario.merge("sections" => SECTIONS, "bosses" => TABLE.to_a, "tiers" => MGQ_MpRaidBosses::TIERS.map { |tier, stats| [tier, stats.map { |stat, factor| [stat.to_s, factor.to_s] }] },
                   "model" => describe_model(overview.world_model))
  end
end

# Records the Quests page: with quests, without any, and with the side quests folded.
#
# @return [Array<Hash>] The cases.
def quest_cases
  overview = MGQ_MpWorldOverview
  quest = lambda { |kind, number, (speaker, texts)| overview::Quest.new(kind, speaker, texts, number, nil) }
  scenarios = [
    { "name" => "told", "main" => ["Amira", ["Go to Mt. Saint Amos. Then rest.", "Then come back."]],
      "side" => [["Amira", ["Find the ring」と言った。 More."]], [nil, ["No end here"]]],
      "companion" => [["Alma", ["Bring me Dr. Pepper! Please."]]], "closed" => [] },
    { "name" => "none", "main" => nil, "side" => [], "companion" => [], "closed" => [] },
    { "name" => "folded", "main" => nil, "side" => [["Amira", ["One."]]], "companion" => [], "closed" => ["side"] },
  ]
  scenarios.map do |scenario|
    main = scenario["main"]
    overview.main = main ? overview::Quest.new(:main, main[0], main[1], nil) : nil
    overview.sides = scenario["side"].each_with_index.map { |told, index| quest.call(:side, index + 1, told) }
    overview.companions = scenario["companion"].map { |told| quest.call(:companion, nil, told) }
    overview.instance_variable_set(:@folds, { :quests => scenario["closed"].each_with_object({}) { |key, folds| folds[key.to_sym] = false } })
    scenario.merge("model" => describe_model(overview.quest_model))
  end
end

# Records the Unlocks page: levels passed and to come, none, and before the catch-up starts.
#
# @return [Array<Hash>] The cases.
def unlock_cases
  overview = MGQ_MpWorldOverview
  unlock = lambda { |level, name, got, due| MGQ_MpWorldCatchup::Unlock.new(level, :story, name, nil, got, due, nil, []) }
  scenarios = [
    { "name" => "levels", "target" => 40, "level" => 31, "unlocks" => [[20, "Part 1", true, false], [20, "Alma", true, false],
      [30, "Granberia", true, false], [30, "Sara", false, true], [45, "Part 2", false, false], [45, "Tamamo", false, false]], "opened" => [] },
    { "name" => "passed opened", "target" => 40, "level" => 31, "unlocks" => [[20, "Part 1", true, false], [30, "Sara", false, true]], "opened" => ["passed"] },
    { "name" => "all passed", "target" => nil, "level" => nil, "unlocks" => [[20, "Part 1", true, false]], "opened" => [] },
    { "name" => "nothing", "target" => nil, "level" => 5, "unlocks" => [], "opened" => [] },
  ]
  scenarios.map do |scenario|
    MGQ_MpWorldCatchupExp.target = scenario["target"]
    MGQ_MpWorldCatchup.counted_level = scenario["level"]
    unlocks = scenario["unlocks"].map { |level, name, got, due| unlock.call(level, name, got, due) }
    MGQ_MpWorldCatchup.listed = unlocks
    $game_party.battle_members = []
    overview.instance_variable_set(:@folds, { :unlocks => scenario["opened"].each_with_object({}) { |key, folds| folds[key.to_sym] = true } })
    scenario.merge("model" => describe_model(overview.unlock_model, unlocks))
  end
end

File.write(File.join(__dir__, "state.json"), JSON.pretty_generate({ "steps" => state_cases }) + "\n")
File.write(File.join(__dir__, "rows.json"), JSON.pretty_generate(rows_cases) + "\n")

overview = MGQ_MpWorldOverview
sentences = ["Go to Mt. Saint Amos. Then rest.", "Dr. Who? Yes.", "No end here", "  Spaced out!  Next.", "Wait... what?", "「来て」と言った。次。",
             "Sing ♪ along ♪ now", "He said \"Stop!\" Then left.", "Ends with Mt.", "", "Find the ring」と言った。 More."]
shares = [1.0, 0.68, 0.005, 0.0049, 0.001, 0.0, 0.995, 0.9951, 0.125, 0.335]
pages = {
  "sentences" => sentences.map { |text| [text, overview.first_sentence(text)] },
  "shares" => shares.map { |left| [left, overview.share_text(left)] },
  "world" => world_cases, "quests" => quest_cases, "unlocks" => unlock_cases,
}

File.write(File.join(__dir__, "pages.json"), JSON.pretty_generate(pages) + "\n")
