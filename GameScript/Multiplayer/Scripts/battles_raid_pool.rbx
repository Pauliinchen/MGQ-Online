#----------------------------------------------------------------
#  battles_raid_pool.rbx
#
#  Changelog:
#      Paulinchen  2026-10-11: Told the story bosses newly counted as raid bosses, such as the four spirits and the Part 2 queens' own fights, beaten by what their events set after the fight
#                            - Listed the pools the game knows, which the World overview reads
#      Paulinchen  2026-10-10: Told the Three Nobles of Black beaten by the castle quest's progress in Part 2 and the treasure gallery's switch in Part 3
#                            - Added taken_over, which the co-op battles call as a guest takes a battle over, so the damage of a battle that starts then is reported
#                            - Started a guest's reports from the enemies' HP as it takes the battle over, so the host's reported damage is not reported again, and kept a guest from killing enemies by its own view of the pools
#                            - Counted a report from no more than the enemy's max HP now, so a lowered max HP reads as no damage
#                            - Compared the DLL's line of a pool with the last one taken, so small changes in a row count once they add up
#                            - Gave a side battle's EXP, gold and drops once per boss, kept in the save, and ran none of its troop's battle events, for the players who join it too, whose invite tells it is a side battle
#                            - Added side_battle?, which the co-op battles ask to leave side battles alone
#                            - Fought no pool on the Hades rematch hall's map either
#                            - Took the pools' HP every five seconds while a battle waits for its players' commands, so its bar shows the other battles' blows meanwhile
#                            - Reported what a battle dealt as its actions end too, at most every two seconds, so the other games see a long turn's damage
#                            - Gave a pooled enemy the factors of its boss's tier for its stats instead of 7.5 times its max HP, after the game's difficulty
#                            - Named the one-time Chaos Domain bosses in the message that a boss is defeated for the whole world
#                            - Made each raid boss one fight the whole world shares: its enemies have 7.5 times their max HP, report what they lost and take their HP from the relay's pool at each command phase, and die when the pool is empty
#                            - Kept a pool per enemy of a boss troop of several, so each falls on its own
#                            - Let a player near a boss battle that takes nobody in fight the same boss in a side battle of their own, which may be lost
#                            - Let a guest of a boss battle report once it takes the battle over
#                            - Fetched the pools as the player enters the world and each map
#                            - Dropped the boss that falls back with everything it put back: the story, the party, how the map looked, the items an event gave, the held event and autosave
#      Paulinchen  2026-10-09: Counted only the boss troop's own enemies in the share of a kill and the boss's name, never enemies added mid-battle
#                            - Took back the copies of the items a boss event equips at once that its replay leaves in the bag
#                            - Counted the fights whose events change the party against their pools, putting the party back as the boss falls back
#                            - Created
#
#----------------------------------------------------------------

# The raid bosses of a Raid World: each story boss is one fight the whole world shares, its enemies'
# stats raised by the factors of its tier (MGQ_MpRaidBosses::TIERS). Its pool at the relay
# (Relay/core/bosses.js) keeps how much of its HP is left, as a share of its max, and refills by
# REGEN_PER_MINUTE of it every minute. Every battle against the boss fights the same HP: as its
# actions end, at most every REPORT_SECONDS, and at each command phase the battle reports what it
# dealt since the last report; as each command phase opens, and every INPUT_SYNC_SECONDS while it
# waits for commands, it also takes the pool's HP, so a boss falls only once the world wore its pool
# down. A battle that empties the pool, or
# fights on as another empties it, wins as the game's own battles win, and the story goes on through
# the event that started it, without waiting for the relay.
#
# A battle fights a pool when the player plays the story of a Raid World, the event of the map
# started it with its battle command, and its troop is the last phase of a boss fight of
# MGQ_MpRaidBosses whose milestone the story has not beaten; a guest of such a battle fights it with
# its host (see note_invite) and reports once it takes the battle over. A player near a boss
# battle that takes nobody in may fight the same pool in a side battle of their own (start_side).
# Classic worlds are never touched.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpRaidPool
  # Share of its max HP a pool gains back every minute, also while battles fight it, as the relay
  # counts it.
  REGEN_PER_MINUTE = 0.03

  # Least seconds between two reports of a battle as its actions end; a command phase and the
  # battle's end report at once. Keeps a player's reports within the relay's two a second
  # (Relay/core/bosses.js) for a boss of up to four enemies.
  REPORT_SECONDS = 2

  # Seconds between two takes of the pools' HP while a battle waits for its players' commands.
  INPUT_SYNC_SECONDS = 5

  # Frames between two reads of the DLL's state of the pools.
  STATE_FRAMES = 10

  # Bytes the DLL may write the pools' state into at first.
  STATE_SIZE = 4096

  # Share of a pool's max by which the DLL's line of a pool must differ from the one it gave before
  # to tell anything new, beyond the regeneration since; the DLL rounds the share it writes.
  LINE_TOLERANCE = 0.0006

  # Smallest share of a pool's max a report carries.
  MIN_DELTA = 1.0e-12

  # Share of its max a pool the relay keeps standing has at least here: the relay and the DLL round
  # the share to 6 decimals, so the last HP of a large pool arrive as 0.
  MIN_LEFT = 1.0e-9

  # Frames before the pools' fetch is tried again after the DLL did not start it.
  FETCH_RETRY_FRAMES = 120

  # Most reports the player's game counts as not answered yet, as many as the DLL queues.
  MAX_PENDING = 1000

  # The switch the Hades rematches turn on around their battles.
  HADES_SWITCH = 97

  # The map of the Hades rematch hall, whose events start the rematches before they turn
  # HADES_SWITCH on.
  HADES_MAP = 576

  # The switch the Colosseum's battles turn on.
  COLOSSEUM_SWITCH = 87

  # The field of $game_system the save keeps the bosses in whose side battle gave its rewards, see
  # rewards.
  REWARDS_FIELD = :@mgq_mp_raid_rewards

  # What the game asks before it gives a won battle's EXP, gold and drops, which a side battle of a
  # boss whose rewards the player got already answers no to.
  REWARD_CHECKS = [:enable_get_exp?, :enable_get_gold?, :enable_get_drop?]

  # Longest key of a boss, which leaves room for the enemy's number the relay's key of one enemy of
  # several adds.
  MAX_KEY_LENGTH = 60

  # The field this script adds to the state the player's game tells the others: the troop and enemy
  # rates of the boss battle the player hosts, which a side battle fights (see state_fields).
  STATE_FIELD = "rpb"

  # The notification box's key of this script's messages.
  NOTICE_KEY = :raid_pool

  # Frames a message of this script shows, five seconds.
  NOTICE_FRAMES = 300

  # Names of the fights a milestone lets the player take in any order, by troop: each has a pool of
  # its own, while the milestone is beaten only once all are.
  FIGHTS = {
    2016 => "Sisel", 2017 => "EX-Kyubi", 2018 => "Frere", 2019 => "Bloody Dragon",
    2095 => "Envious Lily", 2096 => "Wrathful Cow Demon Queen", 2097 => "Gluttonous Cassandra",
    2099 => "Lustful Witch", 2102 => "Prideful Fatima",
    2211 => "Fiend", 2212 => "Goddess", 2213 => "Demon",
  }

  # Last phases that never count, by troop, with why: their events set the route for the whole
  # world.
  UNPOOLED = {
    1507 => "the Great Decision sets the world's route",
    1509 => "the Great Decision sets the world's route",
  }

  # What tells each milestone beaten, by milestone and cap: alternatives split by "|", each a list
  # of conditions split by "&", a switch on ("s2261") or a variable at least a value ("v1003>=8").
  # These are the story's own markers, written after the milestone's last fight.
  BEATEN = {
    ["Four bandits", 10] => "v1003>=8",
    ["Queen Harpy", 15] => "v1011>=4",
    ["Morrigan", 18] => "v1019>=6",
    ["Chrome and Frederica", 20] => "v1023>=2",
    ["Sylph", 20] => "v1001>=17",
    ["Sphinx", 20] => "s2090",
    ["Sara", 20] => "v1028>=6",
    ["Astaroth", 20] => "v1028>=7",
    ["Gnome", 20] => "v1001>=18",
    ["Adramelech", 25] => "v1032>=7",
    ["Bonnie and Ashel", 25] => "s7001",
    ["Alma Elma, then Granberia", 30] => "v1052>=6",
    ["Mephisto", 30] => "s2268",
    ["Tezcatlipoca", 30] => "v1056>=4",
    ["Gnosis", 30] => "s7005",
    ["Zion", 30] => "s7006",
    ["Undine", 30] => "v1001>=25",
    ["Queen Ant", 30] => "s7011",
    ["Lilith", 35] => "v1063>=13",
    ["Salamander", 40] => "v1001>=28",
    ["Queen Fairy", 40] => "s2161",
    ["Queen Elf", 43] => "v1070>=3",
    ["Queen Alraune, then Aži Dahāka", 43] => "v1074>=2",
    ["Queen Mermaid", 45] => "v1071>=3",
    ["Spider Princess", 47] => "v1072>=3",
    ["Carmilla", 47] => "s2252",
    ["Elizabeth", 47] => "s2253",
    ["Queen Vampire", 50] => "v1073>=3",
    ["La Croix's zombies", 50] => "s2266",
    ["Black Dahlia, Black Mamba and Black Rose", 55] => "v1069>=9",
    ["Black Alice", 65] => "s2261",
    ["Eden", 55] => "s7015",
    ["Sonya Mazda", 55] => "s7009",
    ["Sonya Mainyu", 55] => "s7010",
    ["Sonya Chaos", 55] => "v1001>=34",
    ["Garuda", 60] => "v1001>=37",
    ["Erubetie", 60] => "v1136>=3",
    ["Black Dahlia, Black Mamba and Black Rose", 60] => "s2435",
    ["Tamamo", 61] => "s2485",
    ["Erubetie", 62] => "s2486",
    ["Granberia", 63] => "s2487",
    ["Great Decision", 65] => "v1141>=1|v1142>=1",
    ["Heaven's Gate", 67] => "v1141>=4",
    ["Gabriela", 70] => "v1141>=18",
    ["Uriela, Sabiriel and Fernandez", 75] => "v1141>=30",
    ["Sariela", 78] => "v1141>=30",
    ["Laplace", 80] => "v1141>=38",
    ["Metatronne and Sandalphone", 83] => "v1141>=43",
    ["Zion (three fights)", 85] => "v1173>=8",
    ["Cosmos", 90] => "v1151>=6",
    ["Aži Dahāka", 95] => "v1141>=58",
    ["Marcellus and Black Alice", 95] => "v1141>=62",
    ["Doppel Lukas and Lucifina", 100] => "v1141>=67|v1142>=71",
    ["Micaela", 105] => "v1141>=73",
    ["Ilias", 115] => "s7096",
    ["Chaos Ilias", 120] => "s7096",
    ["Queen Eva", 67] => "v1142>=8",
    ["Malboro Girl, then Kanon", 70] => "s2594&v1142>=25",
    ["Kanade", 75] => "v1142>=33",
    ["Tamamo", 80] => "v1142>=34",
    ["Tamamo", 83] => "v1142>=36",
    ["Minagi and Alipheese the 10th", 85] => "v1169>=23",
    ["Kagetsumugi and her dolls", 90] => "v1142>=47",
    ["Hiruko", 95] => "v1142>=60",
    ["Kagetsumugi and Magatsu-Karura, then Black Alice", 95] => "v1142>=63",
    ["Saja", 105] => "v1142>=81",
    ["Alipheese", 115] => "s7097",
    ["Chaos Alipheese", 120] => "s7097",
    ["Kagetsumugi and her dolls", 125] => "v1143>=4",
    ["Angolmois", 130] => "v1143>=18",
    ["Greedy Papi, Gob, Teeny and Vanilla", 135] => "v1319>=7",
    ["Gabriela and Kanon", 135] => "v1301>=8",
    ["Uriela", 135] => "v1302>=5",
    ["Kanade", 140] => "v1302>=7",
    ["Hiruko", 140] => "v1304>=5",
    ["Magatsu-Omikami", 145] => "v1307>=3",
    ["Apiro Lagos", 147] => "v1305>=6",
    ["Zion and Laplace", 151] => "v1308>=8",
    ["Sigrdrifa", 153] => "v1308>=11",
    ["Metatronne and Sandalphone, then Singularity", 155] => "v1308>=13",
    ["Sisel, EX-Kyubi, Frere and Bloody Dragon", 160] => "s3030&s3031&s3032&s3033",
    ["Saja", 168] => "v1312>=3",
    ["World Drown", 175] => "v1313>=5",
    ["Cosmos", 180] => "v1315>=6",
    ["No Life King", 185] => "v1316>=11",
    ["Angolmois", 190] => "v1314>=3",
    ["Hiruko, Kanon and Kanade", 195] => "v1317>=3",
    ["Baal Zebub", 203] => "v1318>=10",
    ["Seven Deadly Sins vessels", 210] => "v1328>=6&v1331>=5&v1329>=4&v1332>=5&v1326>=4",
    ["Greedy, Envious and Slothful Eva", 213] => "v1325>=11",
    ["Seven Deadly Sins", 215] => "v1325>=12",
    ["The All-Knowing", 220] => "v1334>=4",
    ["Agaliarept", 225] => "v1373>=13",
    ["Echidna Queen", 228] => "v1335>=5",
    ["Cthulhu", 230] => "v1336>=5",
    ["Dimensional Eroder", 235] => "v1338>=4",
    ["Star Eater", 240] => "v1339>=5",
    ["Black Alice", 245] => "v1342>=5",
    ["Idea Lukas", 250] => "v1342>=5",
    ["EX Sonya", 255] => "v1343>=3",
    ["Koron", 260] => "v1345>=5",
    ["Goddess, Demon and Fiend", 275] => "s3079&s3078&s3077",
    ["World Breaker and Judgement", 285] => "s3080&s3081",
    ["Deus Ex Machina", 300] => "s7039",
    ["Chaos", nil] => "s7039",
  }

  @clock = 0
  @read_at = 0
  @pools = {}
  @lines = {}
  @scaled = []
  @scaled_troop = nil
  @announced = {}
  @pending = []

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "raid pool"

  # A battle that fights a boss's pools.
  #
  # @!attribute key [String] The boss's key, see key_of.
  # @!attribute name [String] What the player reads the boss as: the troop's enemies.
  # @!attribute troop [Integer] The troop.
  # @!attribute battle [String] The battle's id, under which the relay counts its reports once.
  # @!attribute own [Integer] How many enemies the troop's setup made, which come first in the troop.
  # @!attribute members [Array<Member>] The troop's own enemies, each with its pool.
  # @!attribute seq [Integer] The number of the battle's last report, which the relay counts once.
  # @!attribute side [Boolean] Whether it is a side battle, see start_side.
  # @!attribute guest [Boolean] Whether a host's stream governed it when last looked at, see
  #   reporting?.
  Fight = Struct.new(:key, :name, :troop, :battle, :own, :members, :seq, :side, :guest)

  # One of the troop's own enemies in a battle that fights a boss's pools.
  #
  # @!attribute key [String] Its pool's key at the relay.
  # @!attribute index [Integer] Its place in the troop.
  # @!attribute base [Integer, nil] Its HP as last taken from the pool or reported, nil before.
  # @!attribute killed [Boolean] Whether its death was reported.
  # @!attribute held [Boolean] Whether the DLL refused its last report, so its HP waits for the next
  #   instead of taking the pool's.
  Member = Struct.new(:key, :index, :base, :killed, :held)

  # A pool as the player's game knows it.
  #
  # @!attribute left [Float] The share of its max HP left at :at, 0 to 1.
  # @!attribute max [Integer] Its max HP as the relay shows it, 0 while unknown.
  # @!attribute defeated [Boolean] Whether a battle emptied it, which lasts until an admin resets it.
  # @!attribute by [String, nil] Who emptied it.
  # @!attribute at [Time] When :left held.
  Pool = Struct.new(:left, :max, :defeated, :by, :at)

  # Forgets every battle and what the relay told, as at the title screen.
  def self.forget
    @fight = nil
    @reported_at = nil
    @synced_at = nil
    @lost = nil
    @invited = nil
    @side = nil
    @at_command = false
    @retrying = false
    @fetched = nil
    @tried = nil
    @tried_at = 0
    @world = nil
    @pools = {}
    @lines = {}
    @scaled = []
    @scaled_troop = nil
    @announced = {}
    @pending = []
  end

  # Reports whether the pools apply: the player plays the story of a Raid World.
  #
  # @return [Boolean] Whether they do.
  def self.active?
    MGQ_MpCoop::Scope.raid? && MGQ_MpWorldStory.active? && MGQ_MpWorldStory.mode == :world
  rescue
    false
  end

  # Tells the battle that fights a boss's pools now.
  #
  # @return [Fight, nil] The battle, nil for none.
  def self.fight
    @fight
  end

  # Finds a pool as the player's game knows it.
  #
  # @param key [String] Its key.
  # @return [Pool, nil] The pool, nil while the relay told nothing of it.
  def self.pool(key)
    @pools[key]
  end

  # Lists the pools as the player's game knows them, for the World overview: a copy, so a reader
  # changes nothing here.
  #
  # @return [Hash{String => Pool}] The pools by their key, see Pool.
  def self.pools
    @pools.dup
  end

  # Finds the share of a pool's max HP left now, with what it gained back since it was told.
  #
  # @param pool [Pool] The pool.
  # @param now [Time] The moment.
  # @return [Float] The share, 0 to 1.
  def self.left_now(pool, now = Time.now)
    return 0.0 if pool.defeated

    [pool.left.to_f + REGEN_PER_MINUTE * (now - pool.at) / 60.0, 1.0].min
  end

  # Finds an enemy's HP for a share of its max HP: at least 1 while any is left.
  #
  # @param left [Float] The share.
  # @param max [Integer] Its max HP.
  # @return [Integer] The HP.
  def self.hp_of(left, max)
    return 0 unless left > 0

    [(left * max).ceil, 1].max
  end

  # Runs the map's interpreter, noting that its commands run, which are the story's.
  def self.in_map
    was = @in_map
    @in_map = true
    yield
  ensure
    @in_map = was
  end

  # Runs an event's battle command, noting that the battle set up next is the event's.
  def self.at_command
    @at_command = true
    yield
  ensure
    @at_command = false
  end

  # Runs the game's retry of a lost battle, noting that the battle set up next is a retry.
  def self.retrying
    @retrying = true
    yield
  ensure
    @retrying = false
  end

  # Tells how a battle about to be set up, or just set up, fights a pool, without forgetting why.
  #
  # @param troop_id [Integer, String] The battle's troop.
  # @return [Symbol, nil] :side for a side battle, :guest for one a host's invite marked, :event for
  #   an event's story boss battle, nil for none; the lost battle's kind for the game's retry of it.
  def self.kind_of(troop_id)
    troop = troop_id.to_i
    return (@lost.side ? :side : :event) if retry_of?(troop)
    return :side if @side == troop
    return :guest if @invited && @invited[0] == troop
    return nil unless @at_command && @in_map && active? && MGQ_MpRaidBosses.boss?(troop)
    return nil unless $game_map.interpreter.event_id > 0

    refusal(troop) ? nil : :event
  end

  # Reports whether a battle about to be set up is the game's retry of the lost battle that fought a
  # pool, which battles_coop.rbx invites to before set_up takes it.
  #
  # @param troop [Integer] The battle's troop.
  # @return [Boolean] Whether it is.
  def self.retry_of?(troop)
    @retrying && @lost && @lost.troop == troop ? true : false
  end

  # Decides whether the battle just set up fights a pool, and takes its HP from it. Called after
  # BattleManager.setup.
  #
  # @param troop_id [Integer] The battle's troop.
  def self.set_up(troop_id)
    return retried if @retrying

    kind = kind_of(troop_id)
    invited = @invited
    explain = @at_command && @in_map && MGQ_MpRaidBosses.boss?(troop_id) && active?
    @at_command = false
    @invited = nil
    @side = nil
    @fight = nil
    @lost = nil
    @scaled = []
    unless kind
      reason = explain ? refusal(troop_id.to_i) || ($game_map.interpreter.event_id > 0 ? nil : "a common event of its own started it") : nil
      return reason ? log("troop #{troop_id} fights no pool: #{reason}") : nil
    end

    own = kind == :guest ? invited[1] : own_count(troop_id)
    start(troop_id.to_i, own, kind, kind == :side || (kind == :guest && invited[2]) ? true : false)
  rescue => e
    @fight = nil
    log("deciding on troop #{troop_id} failed: #{e.class}: #{e.message}")
  end

  # Starts fighting a boss's pools: its own enemies get the stats of its tier and the pools' HP.
  #
  # @param troop [Integer] The troop.
  # @param own [Integer] How many enemies the troop's setup made.
  # @param kind [Symbol] See kind_of.
  # @param side [Boolean] Whether it is a side battle, the player's own or a host's they join.
  def self.start(troop, own, kind, side)
    key = key_of(troop)
    return log("troop #{troop} fights no pool: its key is none the relay takes") unless key

    members = member_keys(key, own).each_with_index.map { |member_key, index| Member.new(member_key, index, nil, false) }
    @fight = Fight.new(key, troop_name(own), troop, new_battle_id, own, members, 0, side, kind == :guest || !reporter?)
    take_on(@fight)
    log("battle #{@fight.battle} (#{kind}) against #{@fight.name} (troop #{troop}, tier #{MGQ_MpRaidBosses.tier(troop)}) fights the pool(s) #{members.map(&:key).join(', ')}: " \
        "#{members.map { |member| enemy_text(member) }.join(', ')}")
  end

  # Takes a retry of a lost battle that fought a pool as one that fights it again, with an id of
  # its own and its HP from the pool.
  def self.retried
    @retrying = false
    lost = @lost
    @lost = nil
    return unless lost

    members = lost.members.map { |member| Member.new(member.key, member.index, nil, false) }
    @fight = Fight.new(lost.key, lost.name, lost.troop, new_battle_id, lost.own, members, 0, lost.side, !reporter?)
    take_on(@fight)
    log("the retry of the battle against #{@fight.name} fights its pools as battle #{@fight.battle}")
  end

  # Finds why a story boss battle fights no pool.
  #
  # @param troop_id [Integer] The troop.
  # @return [String, nil] Why, nil when it fights one.
  def self.refusal(troop_id)
    boss = MGQ_MpRaidBosses.at(troop_id)
    return "an earlier phase of its fight" unless MGQ_MpRaidBosses.last_phase?(troop_id)
    return UNPOOLED[troop_id] if UNPOOLED[troop_id]
    return "a Hades rematch" if hades?
    return "a Colosseum battle" if $game_switches[COLOSSEUM_SWITCH]
    return "the story beat #{boss.milestone} already" if beaten?(boss)

    key_of(troop_id) ? nil : "its key is none the relay takes"
  end

  # Reports whether the player is at a Hades rematch: its switch is on, or the player stands in the
  # rematch hall, whose events start the rematches before they turn the switch on.
  #
  # @return [Boolean] Whether they are.
  def self.hades?
    $game_switches[HADES_SWITCH] || ($game_map && $game_map.map_id == HADES_MAP) ? true : false
  end

  # Reports whether a troop's boss has pools the player may fight: the last phase of a story boss
  # the story has not beaten, which the relay takes a key of.
  #
  # @param troop_id [Integer, String] The troop.
  # @return [Boolean] Whether it has.
  def self.pooled_troop?(troop_id)
    troop = troop_id.to_i
    boss = MGQ_MpRaidBosses.at(troop)
    !boss.nil? && MGQ_MpRaidBosses.last_phase?(troop) && !UNPOOLED[troop] && !beaten?(boss) && !key_of(troop).nil?
  end

  # Reports whether the story beat a milestone, by its markers in BEATEN.
  #
  # @param boss [MGQ_MpRaidBosses::Boss] The troop's milestone.
  # @return [Boolean] Whether it did; false for a milestone without markers.
  def self.beaten?(boss)
    test = BEATEN[[boss.milestone, boss.cap]]
    test ? met?(test) : false
  end

  # Reports whether the game's values meet a test of BEATEN.
  #
  # @param test [String] The test.
  # @return [Boolean] Whether they do.
  def self.met?(test)
    test.split("|").any? { |all| all.split("&").all? { |condition| condition_met?(condition) } }
  end

  # Reports whether the game's values meet one condition of a test of BEATEN.
  #
  # @param condition [String] Such as "s2261" or "v1003>=8".
  # @return [Boolean] Whether they do; false for a condition that is none.
  def self.condition_met?(condition)
    case condition
    when /\As(\d+)\z/ then $game_switches[$1.to_i] ? true : false
    when /\Av(\d+)>=(-?\d+)\z/ then $game_variables[$1.to_i].to_i >= $2.to_i
    else false
    end
  end

  # Finds a troop's boss key: the fight's own name for a fight of FIGHTS, else its milestone, with
  # its cap where several milestones share the name.
  #
  # @param troop_id [Integer, String] The troop.
  # @return [String, nil] The key, nil for a troop that is no story boss or a key the relay refuses.
  def self.key_of(troop_id)
    key = FIGHTS[troop_id.to_i] || MGQ_MpRaidBosses.milestone_key(troop_id)
    return nil unless key

    key.strip == key && !key.empty? && !key.include?("#") && key.length <= MAX_KEY_LENGTH ? key : nil
  end

  # Finds the pools' keys of a boss's own enemies: the boss's key for one enemy, else one per enemy,
  # the key with its place in the troop, such as "Metatronne and Sandalphone#1".
  #
  # @param key [String] The boss's key, see key_of.
  # @param own [Integer] How many enemies the troop's setup makes.
  # @return [Array<String>] The keys.
  def self.member_keys(key, own)
    own.to_i <= 1 ? [key] : (0...own.to_i).map { |index| "#{key}##{index}" }
  end

  # Finds the pools' keys of a troop's own enemies, as its setup makes them.
  #
  # @param troop_id [Integer, String] The troop.
  # @return [Array<String>] The keys, none for a troop without a key.
  def self.troop_keys(troop_id)
    key = key_of(troop_id)
    key ? member_keys(key, data_own(troop_id)) : []
  end

  # Counts the enemies the setup of the troop just set up made, which come first in the troop.
  #
  # Enemies another mod adds come after them and are no part of the boss.
  #
  # @param troop_id [Integer, String] The troop.
  # @return [Integer] How many.
  def self.own_count(troop_id)
    made = $game_troop.members.size
    data = data_own(troop_id)
    data > 0 ? [data, made].min : made
  end

  # Counts the enemies the game's setup of a troop makes: its members whose enemy the database has.
  #
  # @param troop_id [Integer, String] The troop.
  # @return [Integer] How many, 0 for a troop the database lacks.
  def self.data_own(troop_id)
    troop = $data_troops && $data_troops[troop_id.to_i]
    troop ? troop.members.count { |member| $data_enemies[member.enemy_id] } : 0
  end

  # Names the troop's own enemies, as the player reads the boss.
  #
  # @param own [Integer] How many enemies the troop's setup made, see Fight.
  # @return [String] Such as "Morrigan and Astaroth".
  def self.troop_name(own)
    names = own_enemies(own).map { |enemy| enemy.respond_to?(:original_name) ? enemy.original_name : enemy.name }
    joined_names(names)
  end

  # Names a troop's own enemies by the database, as the player reads the boss outside a battle.
  #
  # @param troop_id [Integer, String] The troop.
  # @return [String] Such as "Morrigan and Astaroth", the boss's key when the database lacks them.
  def self.troop_label(troop_id)
    troop = $data_troops && $data_troops[troop_id.to_i]
    enemies = troop ? troop.members.map { |member| $data_enemies[member.enemy_id] }.compact : []
    name = joined_names(enemies.map { |enemy| enemy.name })
    name.empty? ? key_of(troop_id).to_s : name
  end

  # Joins the names of a boss's enemies, each once, at most three.
  #
  # @param names [Array] The names.
  # @return [String] Such as "Morrigan and Astaroth".
  def self.joined_names(names)
    names.map { |name| name.to_s }.reject { |name| name.empty? }.uniq.first(3).join(" and ")
  end

  # Lists the boss troop's own enemies: those its setup made, which come first in the troop.
  #
  # @param own [Integer] How many enemies the troop's setup made, see Fight.
  # @return [Array<Game_Enemy>] The enemies.
  def self.own_enemies(own)
    $game_troop.members.first(own.to_i)
  end

  # Makes a battle's id: letters and digits the relay takes, unique enough across the world.
  #
  # @return [String] The id.
  def self.new_battle_id
    "rp#{Time.now.to_i.to_s(36)}#{rand(36**8).to_s(36)}"
  end

  # Readies a battle's own enemies to fight their pools: their tier's stats, keeping the share of
  # their max HP they had, then their pools' HP.
  #
  # @param fight [Fight] The battle.
  def self.take_on(fight)
    scale_enemies(fight)
    sync(fight)
  end

  # Gives a battle's own enemies their tier's stats, see stat, each new one keeping the share of its
  # max HP it had. Done again at each command phase and as a guest builds its troop anew from
  # the host's (see rescale).
  #
  # @param fight [Fight] The battle.
  def self.scale_enemies(fight)
    enemies = own_enemies(fight.own).compact
    fresh = enemies.reject { |enemy| scaled?(enemy) }
    shares = fresh.map { |enemy| enemy.mhp.to_i > 0 ? enemy.hp.to_f / enemy.mhp : 1.0 }
    @scaled = enemies
    @scaled_troop = fight.troop
    fresh.each_with_index { |enemy, index| enemy.hp = hp_of(shares[index], enemy.mhp) unless enemy.dead? }
  end

  # Gives the enemies of a troop built anew in the battle that fights a pool their tier's stats
  # before the host's HP reaches them, which their own max HP would cut. Called by
  # MGQ_MpBattlesCoop.take_troop.
  def self.rescale
    fight = @fight
    scale_enemies(fight) if fight
  rescue => e
    log("raising the max HP of the troop built anew failed: #{e.class}: #{e.message}")
  end

  # Reports whether an enemy has its tier's stats.
  #
  # @param enemy [Game_Enemy] The enemy.
  # @return [Boolean] Whether it has.
  def self.scaled?(enemy)
    @scaled.any? { |scaled| scaled.equal?(enemy) }
  end

  # Finds one of an enemy's stats: for an enemy of a battle that fights a pool, its own times the
  # factor its boss's tier gives the stat (MGQ_MpRaidBosses.factor).
  #
  # The factor is applied on every call instead of stored, since the game computes the stat anew each
  # time, from the difficulty and the enemy's states, so it always comes after the difficulty.
  #
  # @param enemy [Game_Enemy] The enemy.
  # @param stat [Symbol] The stat, such as :mhp.
  # @param own [Integer] The stat as the game computes it.
  # @return [Integer] The stat.
  def self.stat(enemy, stat, own)
    return own if @scaled.empty? || !scaled?(enemy)

    factor = MGQ_MpRaidBosses.factor(@scaled_troop, stat)
    factor == 1 ? own : (own * factor).round
  end

  # Reports whether the player's game reports the battle's pools: as its host, alone or once it
  # took the battle over, never as a co-op guest.
  #
  # @return [Boolean] Whether it does.
  def self.reporter?
    MGQ_MpBattlesSync.role != :guest
  end

  # Gives the battle's own enemies the HP of their pools, and kills those whose pool is empty. An
  # enemy that is dead keeps its death; one whose pool the relay told nothing of, or whose last
  # report the DLL refused, keeps its HP. A guest's enemies keep the HP of their host's stream.
  #
  # @param fight [Fight] The battle.
  # @param only_kill [Boolean] Whether only enemies whose pool is empty change.
  # @return [Boolean] Whether it killed one.
  def self.sync(fight, only_kill = false)
    return false if fight.guest

    enemies = $game_troop.members
    killed = false
    now = Time.now
    fight.members.each do |member|
      enemy = enemies[member.index]
      next unless enemy

      pool = @pools[member.key]
      unless pool && !enemy.dead?
        # Set only once, since a later base would swallow what the battle dealt since its last report.
        member.base = enemy.hp if member.base.nil? && !only_kill
        next
      end

      left = left_now(pool, now)
      next if only_kill && left > 0

      target = hp_of(left, enemy.mhp)
      if target <= 0
        kill(enemy)
        killed = true
      elsif member.held
        next
      elsif enemy.hp != target
        enemy.hp = target
      end
      member.base = enemy.hp
    end
    killed
  end

  # Reports whether the player's game reports the battle's pools now, noting whether a host's stream
  # governs the battle. The first time a battle a host governed is the player's to report, as the
  # player takes it over, every enemy's base becomes its HP at that moment, since the host reported
  # what came before.
  #
  # @param fight [Fight] The battle.
  # @return [Boolean] Whether it does.
  def self.reporting?(fight)
    unless reporter?
      fight.guest = true
      return false
    end
    return true unless fight.guest

    fight.guest = false
    fight.members.each do |member|
      enemy = $game_troop.members[member.index]
      member.base = enemy.hp if enemy
      member.held = false
    end
    log("battle #{fight.battle} is the player's to report from here: #{fight.members.map { |member| enemy_text(member) }.join(', ')}")
    true
  end

  # Makes a battle the player took over from its host the player's to report from the enemies' HP
  # at this moment. Called by MGQ_MpBattlesCoop.take_over once the co-op side ended.
  #
  # A battle that never had its host's party starts after this, and the first command phase would
  # otherwise fold the damage of that start into the base.
  def self.taken_over
    fight = @fight
    reporting?(fight) if fight
  rescue => e
    log("taking the battle over for its reports failed: #{e.class}: #{e.message}")
  end

  # Kills an enemy whose pool another battle emptied, as a blow would, with its collapse.
  #
  # @param enemy [Game_Enemy] The enemy.
  def self.kill(enemy)
    enemy.hp = 0
    enemy.perform_collapse_effect if enemy.respond_to?(:perform_collapse_effect) && SceneManager.scene.is_a?(Scene_Battle)
    log("#{enemy.name} falls: its pool is empty")
  end

  # Reports what the battle dealt since the last command phase and takes the pools' HP as a command
  # phase opens, before battles_sync_live.rbx tells it the guests: the battle's host or a player
  # alone reports, gives the enemies their pools' HP, and wins once every enemy is dead; a guest
  # keeps the HP its host sent. Called before Scene_Battle#start_party_command_selection.
  #
  # The report waits for the command phase, since the game's turn end and battle start deal damage
  # of their own (slip damage, auto skills, troop events) that a sync before it would undo.
  def self.command_phase
    fight = @fight
    return unless fight

    scale_enemies(fight)
    return unless reporting?(fight)

    report(fight)
    @synced_at = Time.now
    BattleManager.judge_win_loss if sync(fight) && $game_troop.all_dead?
  rescue => e
    log_once(:command_phase, "reporting the turn and taking the pools' HP failed: #{e.class}: #{e.message}")
  end

  # Takes the pools' HP every INPUT_SYNC_SECONDS while the battle waits for its players' commands,
  # so its bar and enemies show the other battles' blows and the regeneration meanwhile. Nothing
  # of the battle's own runs then, so the HP undoes none of its damage. A battle whose enemies all
  # fall wins, as at the command phase; a guest's keeps its host's HP and falls with its host's.
  # Called after Scene_Battle#update_basic, every frame.
  def self.waiting_for_commands
    fight = @fight
    return unless fight && reporting?(fight) && MGQ_MpGame.get(BattleManager, :phase) == :input

    now = Time.now
    @synced_at ||= now
    return if now - @synced_at < INPUT_SYNC_SECONDS

    @synced_at = now
    BattleManager.judge_win_loss if sync(fight) && $game_troop.all_dead?
  rescue => e
    log_once(:waiting_for_commands, "taking the pools' HP while waiting for commands failed: #{e.class}: #{e.message}")
  end

  # Reports what the battle dealt as one of its actions ends, at most every REPORT_SECONDS, so the
  # other games see a long turn's damage. Its enemies take the pools' HP only at the command phase,
  # which would otherwise undo the turn's damage. Called after Scene_Battle#process_action.
  def self.action_done
    fight = @fight
    return unless fight && reporting?(fight)
    return if @reported_at && Time.now - @reported_at < REPORT_SECONDS

    report(fight)
  rescue => e
    log_once(:action_done, "reporting an action failed: #{e.class}: #{e.message}")
  end

  # Kills the enemies whose pool another battle emptied as a turn ends, which the game's turn end
  # then counts. Called before Scene_Battle#turn_end.
  def self.turn_ended
    fight = @fight
    return unless fight && reporting?(fight)

    sync(fight, true)
  rescue => e
    log_once(:turn_end, "taking the empty pools failed: #{e.class}: #{e.message}")
  end

  # Reports the battle's last blows as it ends; a lost one is kept for the game's retry, and a won
  # side battle notes that its boss gave its rewards. Called as BattleManager.battle_end starts,
  # after the game gave a won battle's rewards.
  #
  # @param result [Integer] The game's result: 0 won, 1 escaped, 2 lost.
  def self.battle_ended(result)
    fight = @fight
    @fight = nil
    return unless fight

    reporting = reporting?(fight)
    report(fight) if reporting
    @lost = fight if result == 2
    note_rewarded(fight.key) if result == 0 && fight.side
    log("battle #{fight.battle} against #{fight.name} ended #{{ 0 => 'won', 1 => 'escaped', 2 => 'lost' }.fetch(result, result.inspect)}" \
        "#{reporting ? '' : ', its host reports'}: #{fight.members.map { |member| enemy_text(member) }.join(', ')}")
  rescue => e
    log("reporting the battle's end failed: #{e.class}: #{e.message}")
  end

  # Reports what each of the battle's own enemies lost since its HP was last taken or reported,
  # as a share of its max HP, and its death. A report the DLL refuses is added to the next.
  #
  # @param fight [Fight] The battle.
  def self.report(fight)
    @reported_at = Time.now
    world = MGQ_MpWorldStory.world_id.to_s
    enemies = $game_troop.members
    fight.members.each do |member|
      enemy = enemies[member.index]
      next if member.killed || enemy.nil?

      max = enemy.mhp.to_i
      next unless max > 0

      dead = enemy.dead? ? true : false
      # A base above the max HP now is a max the game lowered since, which took the HP down with it.
      base = [member.base || max, max].min
      delta = [[(base - enemy.hp).to_f / max, -1.0].max, 1.0].min
      next if !dead && delta.abs < MIN_DELTA

      seq = fight.seq + 1
      text = "#{seq}\t#{format('%.10f', delta)}\t#{max}\t#{dead ? 1 : 0}"
      unless Relay.report(world, member.key, fight.battle, text)
        member.held = true
        log_once([:refused, fight.battle], "the DLL took no report of battle #{fight.battle}: what it dealt goes with the next")
        next
      end

      fight.seq = seq
      member.base = enemy.hp
      member.killed = dead
      member.held = false
      @pending << member.key
      @pending.shift if @pending.size > MAX_PENDING
      note_own(member.key, delta, max, dead)
      log("battle #{fight.battle} reports #{member.key} ##{seq}: #{format('%.6f', delta)} of #{max}#{dead ? ', killed' : ''}")
    end
  end

  # Counts the player's own report in the pool as the player's game knows it, so a command phase
  # before the relay's answer keeps what the battle dealt.
  #
  # @param key [String] The pool's key.
  # @param delta [Float] The share of its max reported lost.
  # @param max [Integer] The battle's max HP of the enemy, the pool's while the relay told none.
  # @param dead [Boolean] Whether the enemy died.
  def self.note_own(key, delta, max, dead)
    now = Time.now
    pool = @pools[key]
    left = pool ? left_now(pool, now) - delta : 1.0 - delta
    empty = dead || left <= 0 || (pool && pool.defeated)
    @pools[key] = Pool.new(empty ? 0.0 : [left, 1.0].min, pool && pool.max > 0 ? pool.max : max, empty ? true : false, pool && pool.by, now)
  end

  # Describes an enemy of the battle for Multiplayer InGame.log.
  #
  # @param member [Member] The enemy.
  # @return [String] Such as "Queen Harpy 812/6000".
  def self.enemy_text(member)
    enemy = $game_troop.members[member.index]
    enemy ? "#{enemy.name} #{enemy.hp}/#{enemy.mhp}" : "#{member.key} missing"
  end

  # Reports whether every pool of a troop's own enemies is empty, as the player's game knows them.
  #
  # @param troop_id [Integer, String] The troop.
  # @return [Boolean] Whether it is; false for a troop without pools or one the relay told nothing of.
  def self.defeated?(troop_id)
    keys = troop_keys(troop_id)
    !keys.empty? && keys.all? { |key| (pool = @pools[key]) && left_now(pool) <= 0 }
  end

  # Writes the fields an invite to the player's battle adds when it fights a pool: "pool", how many
  # enemies the troop's setup made, so the guest fights the same pools (see note_invite), and
  # "side" 1 for a side battle, which is one for the guest too.
  #
  # @param troop_id [Integer, nil] The troop of a battle just set up, before set_up decided on it;
  #   nil for the battle running.
  # @return [Hash] The fields, none for a battle that fights no pool.
  def self.invite_fields(troop_id = nil)
    fight = @fight
    if fight && (troop_id.nil? || fight.troop == troop_id.to_i)
      own = fight.own
      side = fight.side
    else
      return {} unless troop_id && kind_of(troop_id)

      own = retry_of?(troop_id.to_i) ? @lost.own : own_count(troop_id)
      side = side_battle?(troop_id)
    end
    side ? { "pool" => own, "side" => 1 } : { "pool" => own }
  rescue => e
    log("writing the invite's pool failed: #{e.class}: #{e.message}")
    {}
  end

  # Reports whether a battle just set up fights pools that are all empty already, which it then
  # wins at once without inviting anyone.
  #
  # @param troop_id [Integer] The troop.
  # @return [Boolean] Whether it does.
  def self.won_already?(troop_id)
    kind_of(troop_id) && defeated?(troop_id) ? true : false
  rescue
    false
  end

  # Notes the pools of a host's battle the player joins, which its invite names (see
  # invite_fields), so its troop gets the same max HP and the player can report should they take it
  # over. Called by MGQ_MpBattlesHotjoin.note_invite.
  #
  # @param message [Hash] The invite: "troop", "pool" and "side".
  def self.note_invite(message)
    own = message["pool"].to_s
    @invited = own =~ /\A[1-9]\d?\z/ ? [message["troop"].to_i, own.to_i, message["side"].to_s == "1"] : nil
  end

  # The field this script adds to the state the player's game tells the others: in a Raid World
  # STATE_FIELD, the troop and the enemy rates of the boss battle the player fights as its host or
  # alone while its pools are not all empty, such as "71;100,100,0", which a side battle fights, else
  # empty.
  #
  # @return [Hash] The field, none in a Classic world.
  def self.state_fields
    return {} unless MGQ_MpCoop::Scope.raid?

    fight = @fight
    open = fight && reporter? && SceneManager.scene.is_a?(Scene_Battle) && !defeated?(fight.troop)
    { STATE_FIELD => open ? "#{fight.troop};#{MGQ_MpBattlesCoop.rates_text}" : "" }
  rescue => e
    log_once(:state_fields, "telling the boss battle failed: #{e.class}: #{e.message}")
    { STATE_FIELD => "" }
  end

  # Finds the boss battle another player hosts that the player may fight in a side battle: one
  # whose pools are not all empty, of a boss the player's story has not beaten.
  #
  # @param host [MGQ_MpOverworldSync::Peers::Peer] The battle's host.
  # @return [Array, nil] Its troop and enemy rates, nil for none.
  def self.side_of(host)
    return nil unless host.state[STATE_FIELD].to_s =~ /\A(\d+);(-?\d+(?:,-?\d+)*)?\z/

    troop = $1.to_i
    rates = $2.to_s
    side_troop?(troop) ? [troop, rates] : nil
  end

  # Reports whether the player may fight a boss in a side battle: they play the world's story, the
  # boss has pools and they are not all empty.
  #
  # @param troop_id [Integer] The troop.
  # @return [Boolean] Whether they may.
  def self.side_troop?(troop_id)
    active? && pooled_troop?(troop_id) && !defeated?(troop_id)
  end

  # Starts a side battle: the same troop as a boss battle near the player, with its host's enemy
  # rates, against the same pools. It runs no event, not even its troop's, and writes no story; the
  # player may lose it without a game over, and its boss gives its rewards only the first time the
  # player wins one (see withhold_rewards?).
  #
  # @param troop [Integer] The troop.
  # @param rates [String] The host's enemy rates, see MGQ_MpBattlesCoop.rates_text.
  # @return [Boolean] Whether it started.
  def self.start_side(troop, rates)
    return false unless side_troop?(troop)

    coop = MGQ_MpBattlesCoop
    coop.borrow_rates("rates" => rates)
    @side = troop
    BattleManager.setup(troop, false, true)
    unless @fight && @fight.side
      coop.give_back_rates
      log("the side battle against troop #{troop} did not start")
      return false
    end

    SceneManager.call(Scene_Battle)
    true
  rescue => e
    @side = nil
    MGQ_MpBattlesCoop.give_back_rates
    log("starting a side battle against troop #{troop} failed: #{e.class}: #{e.message}")
    false
  end

  # Reports whether a side battle of a troop is being set up or runs, which the co-op battles leave
  # to the player alone: no gathering and no invites.
  #
  # @param troop_id [Integer, String] The troop.
  # @return [Boolean] Whether one is.
  def self.side_battle?(troop_id)
    troop = troop_id.to_i
    return true if @side == troop
    return true if @fight && @fight.side && @fight.troop == troop

    retry_of?(troop) && @lost.side ? true : false
  rescue
    false
  end

  # Lists the bosses whose side battle gave the player its rewards, as the save keeps them; those of
  # another world start anew.
  #
  # @return [Hash] The bosses' keys (see key_of), each to true.
  def self.rewards
    notes = $game_system.instance_variable_get(REWARDS_FIELD)
    world = MGQ_MpWorldStory.world_id.to_s
    unless notes.is_a?(Hash) && notes["world"] == world && notes["keys"].is_a?(Hash)
      notes = { "world" => world, "keys" => {} }
      $game_system.instance_variable_set(REWARDS_FIELD, notes)
    end
    notes["keys"]
  end

  # Notes in the save that a boss's side battle gave the player its rewards.
  #
  # @param key [String] The boss's key.
  def self.note_rewarded(key)
    kept = rewards
    return if kept[key]

    kept[key] = true
    log("the side battles against #{key} give no more rewards")
  end

  # Reports whether the battle running is a side battle whose boss gave the player its rewards
  # already, so it gives no EXP, gold or drops. Called as the game asks whether a won battle gives
  # them.
  #
  # @return [Boolean] Whether it is.
  def self.withhold_rewards?
    fight = @fight
    return false unless fight && fight.side && rewards[fight.key]

    log_once([:withheld, fight.battle], "side battle #{fight.battle} gives no rewards: the player got those of #{fight.key} already")
    true
  rescue => e
    log_once(:withhold_rewards, "deciding on the side battle's rewards failed: #{e.class}: #{e.message}")
    false
  end

  # Runs the game's start of the troop's battle events with none of its pages during a side battle,
  # so it runs nothing of the boss's event; the common events the battle's skills call still run.
  #
  # @param troop [Game_Troop] The troop.
  # @return [Object] What the block returns.
  def self.without_pages(troop)
    fight = @fight
    data = fight && fight.side && troop.respond_to?(:troop) ? troop.troop : nil
    return yield unless data && data.respond_to?(:pages=)

    kept = data.pages
    data.pages = []
    begin
      yield
    ensure
      data.pages = kept
    end
  end

  # Takes the relay's push that a pool changed, which every report and an admin's reset send to the
  # whole world. A pool the push empties is told in the chat log.
  #
  # @param message [Hash] The push: MGQ_MpOverworldSync::BOSS_FIELD with the pool's key, "left"
  #   with the share of its max left, "max", "defeated" 1 or 0, "by" who emptied it, and :relay,
  #   which no player's message carries.
  def self.pushed(message)
    return log("ignored a boss push not from the relay") unless message[:relay]

    key = message[MGQ_MpOverworldSync::BOSS_FIELD].to_s
    left = message["left"].to_s
    return log("ignored a boss push without a key or share: #{key.inspect} #{left.inspect}") if key.empty? || left !~ /\A\d+(\.\d+)?\z/

    was = @pools[key]
    defeated = message["defeated"].to_s == "1"
    share = share_of(left, defeated)
    return log("ignored the relay's push of #{key} at #{left}: the player's own reports since are not answered yet") if behind?(key, share, defeated)

    by = message["by"].to_s
    @pools[key] = Pool.new(share, integer(message["max"]) || (was ? was.max : 0), defeated, by.empty? ? (was && was.by) : by, Time.now)
    log("the relay tells the pool #{key} holds #{left} of #{message['max']}#{defeated ? ', defeated' : ''}")
    defeated ? announce(key) : back_up(key)
  rescue => e
    log("taking the relay's push failed: #{e.class}: #{e.message}")
  end

  # Tells the chat log and the notification box that a boss is defeated for the whole world, once
  # every pool of its enemies is empty, and only once.
  #
  # @param key [String] The pool that emptied.
  def self.announce(key)
    boss = boss_key(key)
    return if @announced[boss]

    troop = troop_of_key(boss)
    keys = troop ? troop_keys(troop) : [key]
    keys = [key] if keys.empty?
    return unless keys.all? { |member| (pool = @pools[member]) && pool.defeated }

    @announced[boss] = true
    text = "#{troop ? troop_label(troop) : boss} is defeated for the whole world."
    chat(text)
    MGQ_MpNotices.message(NOTICE_KEY, text, NOTICE_FRAMES) if defined?(MGQ_MpNotices)
  end

  # Forgets that a boss was told defeated once an admin's reset fills a pool of it again.
  #
  # @param key [String] The pool.
  def self.back_up(key)
    @announced.delete(boss_key(key))
  end

  # Finds the boss's key of a pool's key, without the enemy's place in the troop.
  #
  # @param key [String] The pool's key.
  # @return [String] The boss's key.
  def self.boss_key(key)
    key.sub(/#\d+\z/, "")
  end

  # Finds the troop of a boss's key: its last phase.
  #
  # @param boss [String] The boss's key, see key_of.
  # @return [Integer, nil] The troop, nil for none.
  def self.troop_of_key(boss)
    bosses = MGQ_MpRaidBosses
    @troops_by_key ||= (bosses::TROOPS.keys + bosses::OPTIONAL.keys).select { |troop| bosses.at(troop).last }.each_with_object({}) do |troop, out|
      key = key_of(troop)
      out[key] ||= troop if key
    end
    @troops_by_key[boss]
  end

  # Reads a whole number the relay sent.
  #
  # @param text [Object] The number as text.
  # @return [Integer, nil] The number, nil for none.
  def self.integer(text)
    text = text.to_s
    return text.to_i if text =~ /\A\d+\z/
    return text.to_f.round if text =~ /\A\d+(\.\d+)?(e\+?\d+)?\z/i

    nil
  end

  # Reads the share of a pool's max HP left the relay or the DLL told: at least MIN_LEFT while the
  # pool stands, at most all of it.
  #
  # @param left [String] The share as text.
  # @param defeated [Boolean] Whether the pool is empty for good.
  # @return [Float] The share, 0 to 1.
  def self.share_of(left, defeated)
    defeated ? 0.0 : [[left.to_f, MIN_LEFT].max, 1.0].min
  end

  # Reports whether word of a pool is older than the player's own reports the relay has not answered
  # yet: more HP than the player's game counts while such a report waits. A pool that fills up again
  # after an admin's reset is never older.
  #
  # @param key [String] The pool's key.
  # @param left [Float] The share of its max left the word tells.
  # @param defeated [Boolean] Whether the word tells it empty for good.
  # @return [Boolean] Whether it is older.
  def self.behind?(key, left, defeated)
    was = @pools[key]
    return false unless was && @pending.include?(key) && !defeated && !was.defeated && left < 1.0

    left > left_now(was) + LINE_TOLERANCE
  end

  # Follows the pools for one frame: fetches them as the player enters the world or a map, and reads
  # what the DLL learned now and then. Called every frame through overworld_sync.rbx.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    @clock += 1
    return unless in_world && MGQ_MpCoop::Scope.raid?

    fetch_on_move
    read_state if @clock - @read_at >= STATE_FRAMES
  rescue => e
    log_once(:tick, "following the pools failed: #{e.class}: #{e.message}")
  end

  # Fetches the world's pools as the player enters the world's story or another map, forgetting
  # those of another world first; a fetch the DLL did not start is tried again after
  # FETCH_RETRY_FRAMES.
  def self.fetch_on_move
    return unless $game_map && active?

    place = [MGQ_MpWorldStory.world_id.to_s, $game_map.map_id]
    return if place == @fetched || place[0].empty?

    if @world != place[0]
      @world = place[0]
      @pools = {}
      @lines = {}
      @announced = {}
      @pending = []
    end
    return if place == @tried && @clock - @tried_at < FETCH_RETRY_FRAMES

    @tried = place
    @tried_at = @clock
    @fetched = place if Relay.fetch(place[0])
  end

  # Reads the pools the DLL knows of the player's world, taking each line that tells something new
  # (see take_line), and forgets the player's reports it answered.
  def self.read_state
    @read_at = @clock
    state = Relay.state
    return unless state["world"].to_s == MGQ_MpWorldStory.world_id.to_s

    @pending = @pending.last(state["report_queued"].to_i)
    now = Time.now
    state[:payload].to_s.split("\n").each do |line|
      fields = line.split("\t")
      take_line(fields, now) if fields.size >= 4 && !fields[0].empty?
    end
  end

  # Takes a pool the DLL knows when it tells something new: the first line of the pool, or one that
  # differs from the last line taken beyond the regeneration since. A line the DLL keeps telling
  # unchanged would take back what the player's own reports dealt meanwhile (see note_own), and so
  # would one older than them (see behind?), which is weighed again at the next read.
  #
  # A line within LINE_TOLERANCE is never noted, so small changes in a row count once they add up.
  #
  # @param fields [Array<String>] The line: key, share left now, max, defeated and who emptied it.
  # @param now [Time] When the line was read.
  def self.take_line(fields, now)
    key, left, max, defeated, by = fields
    line = Pool.new(share_of(left, defeated == "1"), integer(max) || 0, defeated == "1", by.to_s.empty? ? nil : by, now)
    taken = @lines[key]
    return if taken && taken.defeated == line.defeated && taken.max == line.max && (left_now(taken, now) - line.left).abs <= LINE_TOLERANCE
    return if behind?(key, line.left, line.defeated)

    @lines[key] = line
    was = @pools[key]
    line.by ||= was && was.by
    @pools[key] = line
    log("the DLL tells the pool #{key} holds #{left} of #{max}#{line.defeated ? ', defeated' : ''}") unless was && was.left == line.left && was.defeated == line.defeated
  end

  # Adds a line of the game's own to the chat log.
  #
  # @param text [String] The line.
  def self.chat(text)
    MGQ_MpChat.system(text) if defined?(MGQ_MpChat)
  end

  # Installs the battle hooks on methods the game's plugins may define anew, as the game starts
  # running. Installed after battles_sync_live.rbx's, so the command phase's wrap runs first.
  def self.install
    # A pooled enemy's max HP, and each other stat a tier changes.
    ([:mhp] + MGQ_MpRaidBosses.tier_stats).each do |stat|
      next log("tiers change #{stat}, which the game's enemies lack") unless Game_Enemy.method_defined?(stat)

      MGQ_MpHooks.around(Game_Enemy, stat, "battles_raid_pool") { |enemy, _args, original| MGQ_MpRaidPool.stat(enemy, stat, original.call) }
    end

    # As a command phase opens, the battle reports what it dealt and the enemies take their pools'
    # HP, before the guests are told it.
    MGQ_MpHooks.around(Scene_Battle, :start_party_command_selection, "battles_raid_pool") do |scene, _args, original|
      MGQ_MpRaidPool.command_phase unless scene.scene_changing?
      original.call
    end

    # As each action ends, the battle reports what it dealt, a few seconds apart.
    MGQ_MpHooks.after(Scene_Battle, :process_action, "battles_raid_pool") { MGQ_MpRaidPool.action_done } if Scene_Battle.method_defined?(:process_action)

    # While the battle waits for commands, its enemies take the pools' HP every few seconds.
    MGQ_MpHooks.after(Scene_Battle, :update_basic, "battles_raid_pool") { MGQ_MpRaidPool.waiting_for_commands } if Scene_Battle.method_defined?(:update_basic)

    # As a turn ends, the enemies whose pool is empty fall.
    MGQ_MpHooks.before(Scene_Battle, :turn_end, "battles_raid_pool") { MGQ_MpRaidPool.turn_ended }

    # As a battle ends, its last blows are reported.
    MGQ_MpHooks.before(BattleManager.singleton_class, :battle_end, "battles_raid_pool") { |result| MGQ_MpRaidPool.battle_ended(result) }

    # A side battle of a boss whose rewards the player got already gives none.
    REWARD_CHECKS.each do |check|
      next log("the game lacks BattleManager.#{check}, so side battles give their rewards each time") unless BattleManager.respond_to?(check)

      MGQ_MpHooks.around(BattleManager.singleton_class, check, "battles_raid_pool") do |_manager, _args, original|
        MGQ_MpRaidPool.withhold_rewards? ? false : original.call
      end
    end

    # A side battle runs none of its troop's battle events.
    if Game_Troop.method_defined?(:setup_battle_event)
      MGQ_MpHooks.around(Game_Troop, :setup_battle_event, "battles_raid_pool") do |troop, _args, original|
        MGQ_MpRaidPool.without_pages(troop) { original.call }
      end
    end

    # The game's retry of a lost battle fights the pools again.
    return unless BattleManager.respond_to?(:retry_battle)

    MGQ_MpHooks.around(BattleManager.singleton_class, :retry_battle, "battles_raid_pool") do |_manager, _args, original|
      MGQ_MpRaidPool.retrying { original.call }
    end
  rescue => e
    log("battle hooks FAILED: #{e.class}: #{e.message}")
  end

  # Patch/Multiplayer/Multiplayer.dll's boss pools at the relay.
  module Relay
    # Starts fetching the world's pools.
    #
    # @param world [String] The world's id.
    # @return [Boolean] Whether it started.
    def self.fetch(world)
      MGQ_Multiplayer::Link.function('mp_raid_bosses_fetch').call(world + "\0") == 1
    rescue => e
      MGQ_MpRaidPool.log("fetching the pools failed: #{e.class}: #{e.message}")
      false
    end

    # Queues a report of a battle, which the DLL sends in order and tries again until the relay
    # answers.
    #
    # @param world [String] The world's id.
    # @param key [String] The pool's key.
    # @param battle [String] The battle's id.
    # @param text [String] "seq\tdelta\tmax\tkilled", see MGQ_MpRaidPool.report.
    # @return [Boolean] Whether the DLL queued it.
    def self.report(world, key, battle, text)
      MGQ_Multiplayer::Link.function('mp_raid_boss_report').call(world + "\0", key + "\0", battle + "\0", text + "\0") == 1
    rescue => e
      MGQ_MpRaidPool.log("reporting failed: #{e.class}: #{e.message}")
      false
    end

    # Reads the pools the DLL knows.
    #
    # @return [Hash] The headers (see docs/DEVELOPER.md), the pools' lines under :payload; empty
    #   before any request.
    def self.state
      text = MGQ_Multiplayer::Link.read('mp_raid_boss_state', STATE_SIZE)
      text.empty? ? {} : MGQ_Multiplayer::Link.parse(text)
    rescue => e
      MGQ_MpRaidPool.log_once([:state, e.class], "reading the pools' state failed: #{e.class}: #{e.message}")
      {}
    end
  end
end

# What this script takes part in of the world, through overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.route(MGQ_MpOverworldSync::BOSS_FIELD) { |_peer, message| MGQ_MpRaidPool.pushed(message) }
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpRaidPool.tick(in_world) }
  MGQ_MpOverworldSync.state_fields { MGQ_MpRaidPool.state_fields }
rescue => e
  MGQ_MpRaidPool.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # Installs the battle hooks as the game starts running.
  MGQ_MpHooks.before(SceneManager.singleton_class, :run, "battles_raid_pool") { MGQ_MpRaidPool.install }

  # Before the title screen starts, every battle and pool is forgotten.
  MGQ_MpHooks.before(Scene_Title, :start, "battles_raid_pool") { MGQ_MpRaidPool.forget }

  # After a battle is set up, it fights a pool or not.
  MGQ_MpHooks.after(BattleManager.singleton_class, :setup, "battles_raid_pool") { |troop_id, *_rest| MGQ_MpRaidPool.set_up(troop_id) }
rescue => e
  MGQ_MpRaidPool.log("hooks FAILED: #{e.class}: #{e.message}")
end

# Game hooks of this script alone, through core_hooks.rbx.

begin
  # The map's interpreter runs the story's events, which alone count.
  MGQ_MpHooks.around(Game_Map, :update_interpreter, "battles_raid_pool") { |_map, _args, original| MGQ_MpRaidPool.in_map { original.call } }

  # An event's battle command starts the battles that count.
  MGQ_MpHooks.around(Game_Interpreter, :command_301, "battles_raid_pool") { |_interpreter, _args, original| MGQ_MpRaidPool.at_command { original.call } }
rescue => e
  MGQ_MpRaidPool.log("battle command hooks FAILED: #{e.class}: #{e.message}")
end
