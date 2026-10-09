#----------------------------------------------------------------
#  battles_raid_pool.rbx
#
#  Changelog:
#      Paulinchen  2026-10-09: Created
#
#----------------------------------------------------------------

# The raid bosses of a Raid World: each story boss has a pool of kills at the relay that the whole
# world wears down together, and that fills up again within the hour (Relay/core/bosses.js). A won
# boss battle moves the story on only once it empties the pool; until then the boss falls back: the
# event that started the battle ends as the game's defeat ends it, without the defeat scene, and
# the switches, variables and self switches it set before the battle are put back with how the map
# looked and sounded, so the event can be played again.
#
# A battle counts when the player hosts it in a Raid World whose story they play, a story event
# started it with its battle command, its troop is the last phase of a boss fight of
# MGQ_MpRaidBosses whose milestone the story has not beaten, and the event moved none of the
# story's progress before the battle. Guests of a co-op battle and Classic worlds are never touched.
# The host reports the share of the boss's HP the battle dealt, in kills, since each host's
# difficulty and mods set the boss's HP; a relay that does not answer in time lets the story go on.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpRaidPool
  # Frames a won battle waits at most for the relay's answer before the story goes on, ten seconds,
  # as long as the DLL's first two tries.
  WAIT_FRAMES = 600

  # Frames a lost battle's report is followed at most for the line in the chat log, thirty seconds,
  # longer than all of the DLL's tries.
  WATCH_FRAMES = 1800

  # Frames between two reads of the DLL's state while a report runs.
  STATE_FRAMES = 10

  # Frames after the player's own report in which the relay's push of the same pool says nothing
  # new, ten seconds.
  OWN_PUSH_FRAMES = 600

  # Bytes the DLL may write the pools' state into at first.
  STATE_SIZE = 4096

  # Kills a full pool holds while the DLL tells none.
  DEFAULT_MAX = 5

  # The switch the Hades rematches turn on around their battles.
  HADES_SWITCH = 97

  # The switch the Colosseum's battles turn on.
  COLOSSEUM_SWITCH = 87

  # The trigger of an event that starts by itself, which would start again at once.
  AUTORUN = 3

  # Longest key the relay takes.
  MAX_KEY_LENGTH = 64

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

  # Last phases that never count, by troop, with why: their events change the party in ways that
  # cannot be put back, or set the route for the whole world.
  UNPOOLED = {
    1507 => "the Great Decision sets the world's route",
    1509 => "the Great Decision sets the world's route",
    1725 => "its event puts a party of its own together",
    1946 => "its event puts a party of its own together",
    1975 => "its event adds companions for the fight alone",
    2001 => "its event changes a companion's persona",
    2095 => "its event changes a companion's persona",
    2133 => "its event splits the party",
    2158 => "its event changes a companion's persona and the story between its phases",
    2188 => "its event changes the party's size and a companion's persona",
    2219 => "its event puts a party of its own together",
  }

  # What tells each milestone beaten, by milestone and cap: alternatives split by "|", each a list
  # of conditions split by "&", a switch on ("s2261") or a variable at least a value ("v1003>=8").
  # These are the story's own markers, written after the milestone's last fight.
  BEATEN = {
    ["Four bandits", 10] => "v1003>=8",
    ["Queen Harpy", 15] => "v1011>=4",
    ["Morrigan", 18] => "v1019>=6",
    ["Adramelech", 25] => "v1032>=7",
    ["Alma Elma, then Granberia", 30] => "v1052>=6",
    ["Lilith", 35] => "v1063>=13",
    ["Salamander", 40] => "v1001>=28",
    ["Queen Elf", 43] => "v1070>=3",
    ["Queen Mermaid", 45] => "v1071>=3",
    ["Spider Princess", 47] => "v1072>=3",
    ["Queen Vampire", 50] => "v1073>=3",
    ["Black Alice", 65] => "s2261",
    ["Sonya Chaos", 55] => "v1001>=34",
    ["Garuda", 60] => "v1001>=37",
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

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "raid pool"

  # A battle that counts against a pool.
  #
  # @!attribute key [String] The pool's key at the relay.
  # @!attribute name [String] What the player reads the boss as: the troop's enemies.
  # @!attribute troop [Integer] The troop.
  # @!attribute battle [String] The battle's id, which the relay counts once.
  # @!attribute writes [Array<Hash>] What the event changed before the battle, see writes_since.
  # @!attribute map_id [Integer] The map the event started on.
  # @!attribute event_id [Integer] The event.
  # @!attribute scene [Hash, nil] How the map looked and sounded as the event started, see raw_scene.
  Fight = Struct.new(:key, :name, :troop, :battle, :writes, :map_id, :event_id, :scene)

  # Forgets every battle and report, as at the title screen.
  def self.forget
    @snapshot = nil
    @fight = nil
    @lost = nil
    @pending = nil
    @watch = nil
    @own = nil
    @at_command = false
    @retrying = false
    @save_held = false
  end

  # Reports whether the pools apply: the player plays the story of a Raid World.
  #
  # @return [Boolean] Whether they do.
  def self.active?
    MGQ_MpCoop::Scope.raid? && MGQ_MpWorldStory.active? && MGQ_MpWorldStory.mode == :world
  rescue
    false
  end

  # Notes the story as a map event starts on the map's interpreter, which a boss that falls back
  # puts back. Called after Game_Interpreter#setup.
  #
  # @param interpreter [Game_Interpreter] The interpreter set up.
  def self.event_started(interpreter)
    return unless $game_map && interpreter.equal?($game_map.interpreter)

    @lost = nil
    @snapshot = nil
    return unless interpreter.event_id > 0 && active?

    @snapshot = { :event_id => interpreter.event_id, :map_id => interpreter.map_id, :story => raw_story, :scene => raw_scene }
  rescue => e
    @snapshot = nil
    log_once(:snapshot, "noting the story at an event's start failed: #{e.class}: #{e.message}")
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

  # Decides whether the battle just set up counts against a pool. Called after BattleManager.setup.
  #
  # @param troop_id [Integer] The battle's troop.
  def self.set_up(troop_id)
    return retried if @retrying

    at_command = @at_command
    @at_command = false
    @fight = nil
    @lost = nil
    return unless at_command && @in_map && active? && MGQ_MpRaidBosses.boss?(troop_id)

    reason = refusal(troop_id.to_i)
    return log("troop #{troop_id} counts against no pool: #{reason}") if reason

    root = $game_map.interpreter
    @fight = Fight.new(key_of(troop_id), troop_name, troop_id.to_i, new_battle_id, writes_since(@snapshot[:story]), root.map_id, root.event_id, @snapshot[:scene])
    log("battle #{@fight.battle} against #{@fight.name} (troop #{troop_id}) counts against the pool #{@fight.key}, " \
        "#{change_count(@fight.writes)} story value(s) put back if it holds")
  rescue => e
    @fight = nil
    log("deciding on troop #{troop_id} failed: #{e.class}: #{e.message}")
  end

  # Takes a retry of a lost battle that counted as one that counts again, with an id of its own.
  def self.retried
    @retrying = false
    lost = @lost
    @lost = nil
    return unless lost

    @fight = Fight.new(*lost.to_a)
    @fight.battle = new_battle_id
    log("the retry of the battle against #{@fight.name} counts as battle #{@fight.battle}")
  end

  # Finds why a story boss battle counts against no pool.
  #
  # @param troop_id [Integer] The troop.
  # @return [String, nil] Why, nil when it counts.
  def self.refusal(troop_id)
    boss = MGQ_MpRaidBosses.at(troop_id)
    return "an earlier phase of its fight" unless MGQ_MpRaidBosses.last_phase?(troop_id)
    return UNPOOLED[troop_id] if UNPOOLED[troop_id]
    return "a Hades rematch" if $game_switches[HADES_SWITCH]
    return "a Colosseum battle" if $game_switches[COLOSSEUM_SWITCH]
    return "the story beat #{boss.milestone} already" if beaten?(boss)
    return "no story was noted as its event started" unless snapshot_of_root?

    moved = moved_progress(writes_since(@snapshot[:story]))
    return "its event moved the story's progress (#{moved}) before the battle" if moved

    key_of(troop_id) ? nil : "its key is none the relay takes"
  end

  # Reports whether the noted story belongs to the event the map's interpreter runs.
  #
  # @return [Boolean] Whether it does.
  def self.snapshot_of_root?
    root = $game_map.interpreter
    @snapshot && @snapshot[:event_id] == root.event_id && @snapshot[:map_id] == root.map_id ? true : false
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

  # Names the story's progress an event wrote, which the relay orders the world's story by and
  # would refuse to take back.
  #
  # @param writes [Array<Hash>] What it wrote, see writes_since.
  # @return [String, nil] Such as "v1001", nil for none.
  def self.moved_progress(writes)
    switches = writes[0].keys & MGQ_MpWorldStory::PROGRESS_SWITCHES
    variables = writes[1].keys & MGQ_MpWorldStory::PROGRESS_VARIABLES
    moved = switches.map { |id| "s#{id}" } + variables.map { |id| "v#{id}" }
    moved.empty? ? nil : moved.join(", ")
  end

  # Finds a troop's pool: the fight's own name for a fight of FIGHTS, else its milestone, with its
  # cap where several milestones share the name.
  #
  # @param troop_id [Integer, String] The troop.
  # @return [String, nil] The key, nil for a troop that is no story boss or a key the relay refuses.
  def self.key_of(troop_id)
    key = FIGHTS[troop_id.to_i]
    unless key
      boss = MGQ_MpRaidBosses.at(troop_id)
      return nil unless boss

      key = shared_name?(boss.milestone) ? "#{boss.milestone} (cap #{boss.cap})" : boss.milestone
    end
    key.strip == key && !key.empty? && key.length <= MAX_KEY_LENGTH ? key : nil
  end

  # Reports whether milestones of several caps share a name.
  #
  # @param milestone [String] The name.
  # @return [Boolean] Whether they do.
  def self.shared_name?(milestone)
    @caps ||= MGQ_MpRaidBosses::TROOPS.values.each_with_object({}) { |row, caps| (caps[row[0]] ||= []) << row[1] }
    @caps.fetch(milestone, []).uniq.size > 1
  end

  # Names the battle's enemies, as the player reads the boss.
  #
  # @return [String] Such as "Morrigan and Astaroth".
  def self.troop_name
    names = $game_troop.members.map { |enemy| enemy.respond_to?(:original_name) ? enemy.original_name : enemy.name }
    names.map { |name| name.to_s }.reject { |name| name.empty? }.uniq.first(3).join(" and ")
  end

  # Makes a battle's id: letters and digits the relay takes, unique enough across the world.
  #
  # @return [String] The id.
  def self.new_battle_id
    "rp#{Time.now.to_i.to_s(36)}#{rand(36**8).to_s(36)}"
  end

  # Copies the story as the game keeps it.
  #
  # @return [Array] The switches, variables and self switches.
  def self.raw_story
    [$game_switches, $game_variables, $game_self_switches].map { |object| MGQ_MpGame.get(object, :data).dup }
  end

  # Notes how the map looks and sounds, which a boss event sets up for its battle and puts back only
  # in its commands after the battle.
  #
  # @return [Hash, nil] The battle BGM, the BGM and BGS playing, the player's transparency, the
  #   followers' visibility, the pictures shown by number with their names, and the screen's tone,
  #   brightness and weather; nil when noting failed.
  def self.raw_scene
    screen = $game_map.screen
    pictures = {}
    screen.pictures.each { |picture| pictures[picture.number] = picture.name unless picture.name.to_s.empty? }
    { :battle_bgm => $game_system.battle_bgm, :bgm => RPG::BGM.last.clone, :bgs => RPG::BGS.last.clone,
      :transparent => $game_player.transparent, :followers => $game_player.followers.visible,
      :pictures => pictures, :tone => screen.tone.clone, :brightness => screen.brightness,
      :weather => [screen.weather_type, screen.weather_power] }
  rescue => e
    log_once(:scene, "noting how the map looks failed: #{e.class}: #{e.message}")
    nil
  end

  # Puts back how the map looked and sounded as the event started: the battle BGM, the player and
  # followers shown, the screen, and the BGM and BGS the battle's end played again. Pictures shown
  # since are erased; one the event erased stays erased.
  #
  # @param scene [Hash, nil] What raw_scene noted.
  def self.restore_scene(scene)
    return unless scene

    $game_system.battle_bgm = scene[:battle_bgm]
    $game_player.transparent = scene[:transparent]
    unless $game_player.followers.visible == scene[:followers]
      $game_player.followers.visible = scene[:followers]
      $game_player.refresh
    end
    screen = $game_map.screen
    screen.pictures.each { |picture| picture.erase unless picture.name.to_s.empty? || scene[:pictures][picture.number] == picture.name }
    screen.start_tone_change(scene[:tone], 0)
    screen.clear_fade if scene[:brightness] == 255
    weather, power = scene[:weather]
    screen.change_weather(weather, power, 0)
    scene[:bgm].replay unless scene[:bgm].name == RPG::BGM.last.name
    scene[:bgs].replay unless scene[:bgs].name == RPG::BGS.last.name
  rescue => e
    log("putting back how the map looked failed: #{e.class}: #{e.message}")
  end

  # Finds what changed in the story since it was noted.
  #
  # @param before [Array] The noted switches, variables and self switches.
  # @return [Array<Hash>] The switches, variables and self switches that changed, each with its
  #   value as noted (nil for a self switch that was not set).
  def self.writes_since(before)
    now = raw_story
    [changed(before[0], now[0]), changed(before[1], now[1]), changed_keys(before[2], now[2])]
  end

  # Finds the entries of a list that changed.
  #
  # @param before [Array] The list as noted.
  # @param now [Array] The list now.
  # @return [Hash] The value as noted, by the id of each entry that changed.
  def self.changed(before, now)
    (0...[before.size, now.size].max).each_with_object({}) { |id, out| out[id] = before[id] unless before[id] == now[id] }
  end

  # Finds the keys of a table whose value changed.
  #
  # @param before [Hash] The table as noted.
  # @param now [Hash] The table now.
  # @return [Hash] The value as noted, by each key whose value changed.
  def self.changed_keys(before, now)
    (before.keys | now.keys).each_with_object({}) { |key, out| out[key] = before[key] unless before[key] == now[key] }
  end

  # Counts what an event changed.
  #
  # @param writes [Array<Hash>] What it changed, see writes_since.
  # @return [Integer] How many values.
  def self.change_count(writes)
    writes.inject(0) { |sum, table| sum + table.size }
  end

  # Puts back what an event changed before its battle, past the game's own handling, which would
  # act on some switches by itself.
  #
  # @param writes [Array<Hash>] What it changed, see writes_since.
  def self.restore(writes)
    switches, variables, self_switches = [$game_switches, $game_variables, $game_self_switches].map { |object| MGQ_MpGame.get(object, :data) }
    writes[0].each { |id, value| switches[id] = value }
    writes[1].each { |id, value| variables[id] = value }
    writes[2].each { |key, value| value.nil? ? self_switches.delete(key) : self_switches[key] = value }
    $game_map.need_refresh = true
  end

  # Finds the share of the boss's HP a battle dealt: what the troop's enemies that appeared lost of
  # their max HP together.
  #
  # Weighing by HP keeps a boss's small helpers from counting as a whole kill.
  #
  # @return [Float] The share, 0 to 1.
  def self.dealt
    shown = $game_troop.members.reject { |enemy| enemy.hidden? }
    max = shown.inject(0.0) { |sum, enemy| sum + [enemy.mhp.to_f, 0.0].max }
    return 0.0 unless max > 0

    lost = shown.inject(0.0) { |sum, enemy| sum + [[enemy.mhp.to_f - enemy.hp.to_f, 0.0].max, enemy.mhp.to_f].min }
    [lost / max, 1.0].min
  end

  # Reports a battle that counts as it ends: a won one waits for the relay's answer before the
  # event goes on, a lost one keeps its fight for the game's retry. Called as BattleManager.battle_end
  # starts.
  #
  # @param result [Integer] The game's result: 0 won, 1 escaped, 2 lost.
  def self.battle_ended(result)
    fight = @fight
    @fight = nil
    return unless fight
    return log("battle #{fight.battle} became a guest's of another player's battle: its host reports") if MGQ_MpBattlesSync.guest?

    share = dealt
    started = Relay.report(MGQ_MpWorldStory.world_id, fight.key, fight.battle, format("%.3f", share))
    @own = [fight.key, @clock]
    log("battle #{fight.battle} against #{fight.name} ended #{result == 0 ? 'won' : 'lost'} with #{format('%.3f', share)} of a kill" \
        "#{started ? ', reporting it' : ', but the DLL did not start the report'}")
    if result == 0
      @pending = { :fight => fight, :started => started, :since => @clock, :answer => nil }
      notice("Telling the world how the battle against #{fight.name} went...", WAIT_FRAMES + 60) if started
    else
      @lost = fight if result == 2
      @watch = { :fight => fight, :since => @clock } if started
    end
  rescue => e
    @pending = nil
    log("reporting the battle failed: #{e.class}: #{e.message}")
  end

  # Holds the event that started a won battle until the relay answered, then lets it go on or has
  # the boss fall back. Called before each command of the map's interpreter, in its fiber.
  def self.before_command
    return unless @pending && @in_map

    Fiber.yield while waiting?
    return unless finish(true) == :holds

    # The event ended: its fiber is never resumed again.
    Fiber.yield
  rescue FiberError => e
    log("holding the event failed: #{e.message}")
  end

  # Reports whether a won battle still waits for the relay's answer, reading the DLL's state now
  # and then.
  #
  # @return [Boolean] Whether it does.
  def self.waiting?
    pending = @pending
    return false unless pending && pending[:started] && pending[:answer].nil?
    return false if @clock - pending[:since] >= WAIT_FRAMES

    pending[:answer] = answer_for(pending[:fight].battle) if @clock - @read_at >= STATE_FRAMES
    pending[:answer].nil?
  end

  # Reads the relay's answer to a report.
  #
  # @param battle [String] The battle's id.
  # @return [Hash, nil] The DLL's state once the report of that battle ended, nil before.
  def self.answer_for(battle)
    @read_at = @clock
    state = Relay.state
    state["report_battle"] == battle && %w(done failed).include?(state["report"]) ? state : nil
  end

  # Ends the wait for a won battle's answer: the story goes on, or the boss falls back.
  #
  # @param in_event [Boolean] Whether the event still runs, which then ends.
  # @return [Symbol] :emptied, :defeated, :holds or :unknown, see outcome_of.
  def self.finish(in_event)
    pending = @pending
    @pending = nil
    drop_notice
    fight = pending[:fight]
    state = pending[:answer]
    outcome = outcome_of(state)
    case outcome
    when :emptied
      log("battle #{fight.battle} emptied the pool #{fight.key}: the story goes on")
      chat("#{fight.name} is defeated for the whole world.")
    when :defeated
      log("the pool #{fight.key} was emptied by another battle before: the story goes on")
      chat("The world defeated #{fight.name} already.")
    when :holds
      fall_back(fight, state, in_event)
    else
      why = state ? [state['report_code'], state['report_error']].compact.reject { |part| part.empty? }.join(": ") : "none in time"
      log("no answer for battle #{fight.battle} (#{why}): the story goes on")
    end
    release_save
    outcome
  rescue => e
    log("ending the wait failed: #{e.class}: #{e.message}")
    :unknown
  end

  # Runs the game's autosave, unless a won battle waits for the relay's answer: the game autosaves
  # after a won retry, and a save then would let a loaded game play the event on past a boss that
  # falls back. finish makes the save once the answer is in.
  #
  # @return [Object] What the autosave returns, nil when held.
  def self.auto_saving
    return yield unless @pending

    @save_held = true
    log("held the autosave until the relay answers")
    nil
  end

  # Makes the autosave held for a won battle's answer.
  def self.release_save
    return unless @save_held

    @save_held = false
    DataManager.auto_save_game
  end

  # Reads how a report ended.
  #
  # @param state [Hash, nil] The DLL's state of the report, nil without an answer.
  # @return [Symbol] :emptied when this battle emptied the pool, :defeated when another did before,
  #   :holds while kills are left, :unknown without an answer.
  def self.outcome_of(state)
    return :unknown unless state && state["report"] == "done"
    return :emptied if state["report_emptied"] == "1"
    return :defeated if state["report_defeated"] == "1"

    :holds
  end

  # Has a boss fall back: puts back what the event changed before the battle and how the map looked,
  # ends the event as the game's defeat does, and tells the player how much is left.
  #
  # @param fight [Fight] The battle.
  # @param state [Hash] The DLL's state of the report.
  # @param in_event [Boolean] Whether the event still runs.
  def self.fall_back(fight, state, in_event)
    restore(fight.writes)
    restore_scene(fight.scene)
    end_event(fight) if in_event
    left = "#{amount(state['report_hp'])}/#{amount(max_of(state, fight.key))}"
    log("#{fight.name} falls back, #{left} left in the pool #{fight.key}: #{change_count(fight.writes)} story value(s) put back")
    text = "#{fight.name} falls back. Raid HP left: #{left}."
    notice(text)
    chat(text)
  end

  # Ends the event of a battle, which may then start again. Clearing the interpreter skips the
  # unlock Game_Map#update_interpreter does for an event that ended, so it is done here. One whose
  # page, with the story put back, starts by itself is erased until the map is entered again, since
  # it would start again at once.
  #
  # @param fight [Fight] The battle.
  def self.end_event(fight)
    root = $game_map.interpreter
    root.clear
    return unless fight.map_id == $game_map.map_id

    $game_map.unlock_event(fight.event_id)
    event = $game_map.events[fight.event_id]
    return unless event

    event.refresh
    event.erase if event.trigger == AUTORUN
  end

  # Finds a pool's full kills in the DLL's state.
  #
  # @param state [Hash] The state.
  # @param key [String] The pool's key.
  # @return [Float] Its max, DEFAULT_MAX when the state lists it not.
  def self.max_of(state, key)
    line = state[:payload].to_s.split("\n").map { |row| row.split("\t") }.find { |row| row[0] == key }
    line && line[2].to_f > 0 ? line[2].to_f : (state["max"] ? state["max"].to_f : DEFAULT_MAX)
  end

  # Writes kills as the player reads them.
  #
  # @param value [Object] The kills.
  # @return [String] Such as "4", "3.5" or "0.25".
  def self.amount(value)
    format("%.2f", value.to_f).sub(/\.?0+\z/, "")
  end

  # Follows the reports for one frame: ends a won battle's wait whose event already ended, and tells
  # the answer to a lost battle's report. Called after the map's update.
  def self.tick
    @clock += 1
    if @pending && !$game_map.interpreter.running? && !waiting?
      finish(false)
    elsif @watch && !@pending
      watch_loss
    end
  rescue => e
    log_once(:tick, "following the reports failed: #{e.class}: #{e.message}")
  end

  # Tells the answer to a lost battle's report in the chat log.
  def self.watch_loss
    watch = @watch
    return @watch = nil if @clock - watch[:since] >= WATCH_FRAMES
    return unless @clock - @read_at >= STATE_FRAMES

    state = answer_for(watch[:fight].battle)
    return unless state

    @watch = nil
    return log("the lost battle's report failed (#{state['report_code']}): #{state['report_error']}") unless state["report"] == "done"

    fight = watch[:fight]
    chat("#{fight.name} holds on. Raid HP left: #{amount(state['report_hp'])}/#{amount(max_of(state, fight.key))}.")
  end

  # Takes the relay's push that a pool changed, which another player's battle or an admin's reset
  # did, as a line in the chat log. The push of the player's own report says nothing new.
  #
  # @param message [Hash] The push: MGQ_MpOverworldSync::BOSS_FIELD with the pool's key, "hp" with
  #   its kills, and :relay, which no player's message carries.
  def self.pushed(message)
    return log("ignored a boss push not from the relay") unless message[:relay]

    key = message[MGQ_MpOverworldSync::BOSS_FIELD].to_s
    hp = message["hp"].to_f
    own = @own && @own[0] == key && @clock - @own[1] < OWN_PUSH_FRAMES
    log("the relay tells the pool #{key} holds #{amount(hp)}#{own ? ', after the player\'s own report' : ''}")
    return if own || key.empty?

    chat(push_line(key, hp))
  rescue => e
    log("taking the relay's push failed: #{e.class}: #{e.message}")
  end

  # Words a push of the relay for the chat log. A full pool reads as a boss that stands again, since
  # an admin's reset pushes one and no battle took place.
  #
  # @param key [String] The pool's key.
  # @param hp [Float] Its kills.
  # @return [String] The line.
  def self.push_line(key, hp)
    return "#{key} is defeated for the whole world." unless hp > 0
    return "#{key} stands again. Raid HP: #{amount(hp)}/#{amount(DEFAULT_MAX)}." if hp >= DEFAULT_MAX

    "A raid battle against #{key} ended. Raid HP left: #{amount(hp)}/#{amount(DEFAULT_MAX)}."
  end

  # Shows a message in the notification box.
  #
  # @param text [String] The message.
  # @param frames [Integer] How long it shows.
  def self.notice(text, frames = NOTICE_FRAMES)
    MGQ_MpNotices.message(NOTICE_KEY, text, frames) if defined?(MGQ_MpNotices)
  end

  # Takes the waiting message away.
  def self.drop_notice
    MGQ_MpNotices.drop(NOTICE_KEY, "the relay answered") if defined?(MGQ_MpNotices)
  end

  # Adds a line of the game's own to the chat log.
  #
  # @param text [String] The line.
  def self.chat(text)
    MGQ_MpChat.system(text) if defined?(MGQ_MpChat)
  end

  # Installs the battle hooks on methods the game's plugins may define anew, as the game starts
  # running.
  def self.install
    # As a battle ends, a battle that counts reports.
    MGQ_MpHooks.before(BattleManager.singleton_class, :battle_end, "battles_raid_pool") { |result| MGQ_MpRaidPool.battle_ended(result) }

    # A won battle's autosave waits for the relay's answer.
    if DataManager.respond_to?(:auto_save_game)
      MGQ_MpHooks.around(DataManager.singleton_class, :auto_save_game, "battles_raid_pool") do |_manager, _args, original|
        MGQ_MpRaidPool.auto_saving { original.call }
      end
    end

    # The game's retry of a lost battle counts again.
    return unless BattleManager.respond_to?(:retry_battle)

    MGQ_MpHooks.around(BattleManager.singleton_class, :retry_battle, "battles_raid_pool") do |_manager, _args, original|
      MGQ_MpRaidPool.retrying { original.call }
    end
  rescue => e
    log("battle hooks FAILED: #{e.class}: #{e.message}")
  end

  # Patch/Multiplayer/Multiplayer.dll's boss pools at the relay.
  module Relay
    # Starts reporting a battle.
    #
    # @param world [String] The world's id.
    # @param key [String] The pool's key.
    # @param battle [String] The battle's id.
    # @param dealt [String] The share of a kill, such as "1.000".
    # @return [Boolean] Whether it started.
    def self.report(world, key, battle, dealt)
      MGQ_Multiplayer::Link.function('mp_raid_boss_report').call(world + "\0", key + "\0", battle + "\0", dealt + "\0") == 1
    rescue => e
      MGQ_MpRaidPool.log("reporting failed: #{e.class}: #{e.message}")
      false
    end

    # Reads the pools the relay told and how the requests stand.
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
rescue => e
  MGQ_MpRaidPool.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # Installs the battle hooks as the game starts running.
  MGQ_MpHooks.before(SceneManager.singleton_class, :run, "battles_raid_pool") { MGQ_MpRaidPool.install }

  # Before the title screen starts, every battle and report is forgotten.
  MGQ_MpHooks.before(Scene_Title, :start, "battles_raid_pool") { MGQ_MpRaidPool.forget }

  # After the map's update, the reports.
  MGQ_MpHooks.after(Game_Map, :update, "battles_raid_pool") { MGQ_MpRaidPool.tick }

  # After a list of commands is set up, the map's event notes the story. A common event passes the
  # list alone, which a block of two parameters would spread over both.
  MGQ_MpHooks.after(Game_Interpreter, :setup, "battles_raid_pool") { |*_args| MGQ_MpRaidPool.event_started(self) }

  # Before an event command runs, an event whose won battle waits for the relay holds.
  MGQ_MpHooks.before(Game_Interpreter, :execute_command, "battles_raid_pool") { MGQ_MpRaidPool.before_command }

  # After a battle is set up, it counts against a pool or not.
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
