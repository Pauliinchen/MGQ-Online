#----------------------------------------------------------------
#  pool_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Took a fight's enemies as values
#      Paulinchen  2026-10-30: Stood in for a served fight's export and import
#                            - Stood in for the fight that fights the pools, held against its golden turns
#                            - Created
#
#----------------------------------------------------------------

# The DLL's side of a Raid World's boss pools (MGQOnline.Game's PoolLedger and RaidFight, behind
# PoolTopics) for the script tests: PoolLedgerStandIn keeps the pools and the fight that fights
# them as the DLL does and answers their topics, and check_pool_stand_in holds it against the
# golden cases of fixtures/pool, which battles_raid_pool.rbx played before its ledger and its turns
# left it and the C# replays too.

require "json"
require_relative "bridge_support"

# Folder of the pool ledger's golden cases.
POOL_FIXTURES = File.expand_path("../../fixtures/pool", __dir__)

# Stands in for the DLL's pool ledger, on a clock in milliseconds.
class PoolLedgerStandIn
  # The share of a raid max HP a pool gains back per minute, unless the relay names another.
  DEFAULT_REGEN = 0.03

  # The least share a pool that stands holds.
  MIN_LEFT = 1.0e-9

  # A minute in milliseconds.
  MINUTE_MS = 60_000.0

  # A pool as it is known: the share left when told, its max, its defeat, who defeated it, when
  # it was told in milliseconds and its place among the pools taken.
  Kept = Struct.new(:left, :max, :defeated, :by, :at, :stamp)

  # @return [String, nil] The world whose pools are kept.
  attr_reader :world

  # @return [Float] The share a minute every pool gains back.
  attr_accessor :regen

  # @return [RaidFightStandIn, nil] The battle that fights the pools, nil for none.
  attr_reader :fight

  # @return [Proc, nil] Takes a report as the DLL's relay does, [world, key, battle, text] in and
  #   whether it took it out; nil takes every report.
  attr_accessor :reporter

  # Creates a ledger that knows no pool, answering the pools' topics on a fake bridge when given one.
  #
  # @param fake [FakeBridge, nil] The bridge.
  # @yieldreturn [Integer] The time in milliseconds.
  def initialize(fake = nil, &clock)
    @clock = clock
    @fake = fake
    reset
    return unless fake

    fake.answer("raid.pools") { describe }
    fake.answer("raid.pool.heard") { |request| heard(request) }
    fake.answer("raid.pool.reports") { [] }
    fake.answer("raid.fight.open") { |request| open_fight(request["world"], request["battle"], request["keys"], request["guest"], request["side"], request["own"]); nil }
    fake.answer("raid.fight.export") { @fight && export_fight }
    fake.answer("raid.fight.import") { |request| import_fight(request["world"], request["fields"]) }
    fake.answer("raid.fight.turn") { |request| turn_of(request) }
    fake.answer("raid.fight.close") { @fight = nil }
  end

  # Forgets every world, pool, report, defeat and fight.
  def reset
    @world = nil
    @fight = nil
    forget
  end

  # Opens a battle that fights the pools, in place of any other.
  #
  # @param world [String] The world.
  # @param battle [String] The battle's id.
  # @param keys [Array<String>] The pools of the troop's own enemies by their place.
  # @param guest [Boolean] Whether a host's stream governs it.
  # @param side [Boolean] Whether it is a side battle.
  # @param own [Integer, nil] How many enemies the troop's setup made, nil for as many as the keys.
  def open_fight(world, battle, keys, guest, side = false, own = nil)
    @fight = RaidFightStandIn.new(world, battle, keys, guest)
    @fight_side = side ? true : false
    @fight_own = own || keys.size
  end

  # Writes what the battle server needs to fight the open battle's pools, see PoolTopics.Export.
  #
  # @return [Array] The count, 1 or 0 for a side battle and the pools the ledger knows of it.
  def export_fight
    pools = @fight.members.map(&:key).select { |key| @pools[key] }.map do |key|
      left, max, defeated, by = pool(key)
      [key, format("%.10f", left), max.round, defeated ? 1 : 0, by]
    end
    [@fight_own, @fight_side ? 1 : 0, pools]
  end

  # Takes the pools of a battle its starter handed over, see PoolTopics.Import.
  #
  # @param world [String] The world.
  # @param fields [Array, nil] The starter's fields, see export_fight.
  # @return [Array, nil] The count and whether it is a side battle; nil for a count that is none.
  def import_fight(world, fields)
    own, side, pools = Array(fields)
    return nil unless own.is_a?(Integer) && own > 0 && own < 100

    enter(world)
    Array(pools).each do |key, left, max, defeated, by|
      next unless key.is_a?(String) && !key.empty? && key.size <= 64

      hear(key, left.to_s.to_f, max.is_a?(Integer) ? max : 0, defeated == 1, by.to_s, :fetched)
    end
    [own, side == 1]
  end

  # Takes a report as the DLL does: through the reporter, counted in the pools once taken.
  #
  # @param world [String] The world.
  # @param key [String] The pool.
  # @param battle [String] The battle's id.
  # @param text [String] The report.
  # @return [Boolean] Whether it was taken.
  def report(world, key, battle, text)
    return false unless @reporter.nil? || @reporter.call(world, key, battle, text)

    _seq, delta, max, killed = text.split("\t")
    enter(world)
    own(key, delta.to_f, max.to_f, killed == "1")
    true
  end

  # Finds a pool as it stands now.
  #
  # @param key [String] The pool.
  # @return [Array, nil] Its share left now, max, defeat and who defeated it; nil for none.
  def pool(key)
    kept = @pools[key]
    kept && [left_at(kept, @clock.call), kept.max, kept.defeated, kept.by]
  end

  # Tells the time in milliseconds.
  #
  # @return [Integer] The time.
  def now
    @clock.call
  end

  # Keeps the pools of a world, forgetting another world's.
  #
  # @param world [String] The world.
  def enter(world)
    return if @world == world

    @world = world
    forget
  end

  # Takes what the relay told of a pool, see PoolLedger.Hear.
  #
  # @param key [String] The pool.
  # @param left [Float] The share left.
  # @param max [Numeric] The raid max HP, 0 for none.
  # @param defeated [Boolean] Whether it is defeated.
  # @param by [String] Who defeated it.
  # @param source [Symbol] :fetched, :answered or :pushed.
  # @param sent [Integer, nil] The stamp the request was sent at.
  # @return [Boolean] Whether the pool was taken.
  def hear(key, left, max, defeated, by, source, sent = nil)
    now = @clock.call
    was = @pools[key]
    if was && sent && was.stamp > sent
      was.by = by if was.defeated && was.by.empty? && defeated && !by.empty?
      return false
    end

    left = defeated ? 0.0 : [[left, MIN_LEFT].max, 1.0].min
    return false if was && behind?(key, was, left, defeated, now)

    by = !defeated ? "" : !by.empty? ? by : was ? was.by : ""
    max = max > 0 ? max : was ? was.max : 0
    @pools[key] = Kept.new(left, max, defeated, by, now, @stamp += 1)
    tell(key, defeated, by) if source == :pushed
    true
  end

  # Counts one of the player's own reports at once, see PoolLedger.Own.
  #
  # @param key [String] The pool.
  # @param delta [Float] The share lost.
  # @param max [Numeric] The battle's max HP.
  # @param dead [Boolean] Whether the enemy died.
  def own(key, delta, max, dead)
    now = @clock.call
    was = @pools[key]
    left = (was ? left_at(was, now) : 1.0) - delta
    empty = dead || left <= 0 || (was && was.defeated) ? true : false
    @pools[key] = Kept.new(empty ? 0.0 : [left, 1.0].min, was && was.max > 0 ? was.max : max, empty, was ? was.by : "", now, @stamp += 1)
    @pending[key] = @pending[key].to_i + 1
  end

  # Notes that the relay answered the oldest own report of a pool.
  #
  # @param key [String] The pool.
  def settled(key)
    left = @pending[key].to_i - 1
    left > 0 ? @pending[key] = left : @pending.delete(key)
  end

  # Lists every pool as it stands now, by key.
  #
  # @return [Array<Array>] Each pool's key, share left now, max, defeat and who defeated it.
  def pools
    now = @clock.call
    @pools.keys.sort_by(&:b).map { |key| kept = @pools[key]; [key, left_at(kept, now), kept.max, kept.defeated, kept.by] }
  end

  # Lists the pools a push told defeated, by key.
  #
  # @return [Array<String>] The keys.
  def told_defeated
    @told.keys.sort_by(&:b)
  end

  # Takes the defeats and resets told since the last call.
  #
  # @return [Array<Array>] Each change: :defeated or :back, the key and who defeated it.
  def take_changes
    taken = @changes
    @changes = []
    taken
  end

  # Posts the changes as the DLL does at each drain, then runs the scripts' frame.
  def frame
    take_changes.each do |kind, key, by|
      @fake.post(kind == :defeated ? "raid.boss_defeated" : "raid.boss_back", kind == :defeated ? { "key" => key, "by" => by } : { "key" => key })
    end
    MGQ_Multiplayer::Bridge.frame
  end

  # Answers raid.pools.
  #
  # @return [Hash] The world, the share a minute and the pools.
  def describe
    { "world" => @world.to_s,
      "pools" => pools.map { |key, left, max, defeated, by| [key, left.to_s, max.round, defeated, by] } }
  end

  # Answers raid.fight.turn.
  #
  # @param request [Hash] The moment, whether the player reports and the enemies.
  # @return [Hash, nil] The reply, nil without a fight.
  def turn_of(request)
    fight = @fight
    return nil unless fight

    enemies = {}
    request["enemies"].each { |place, hp, mhp, dead, id| enemies[place] = [hp, mhp, dead, id] }
    reply = fight.turn(request["moment"], request["reporter"], enemies, self)
    @fight = nil if request["moment"] == "end"
    reply
  end

  private

  # Forgets the pools, reports and defeats.
  def forget
    @pools = {}
    @pending = {}
    @told = {}
    @changes = []
    @stamp = 0
    @regen = DEFAULT_REGEN
  end

  # Answers raid.pool.heard.
  #
  # @param request [Hash] The word.
  # @return [Boolean] Whether the pool was taken.
  def heard(request)
    enter(request["world"])
    settled(request["key"]) if request["answer"]
    return false if request["left"].nil?

    hear(request["key"], request["left"].to_f, request["max"], request["defeated"], request["by"].to_s, request["answer"] ? :answered : :fetched)
  end

  # Tells whether word of a pool is older than the own reports the relay has not answered yet.
  #
  # @param key [String] The pool.
  # @param was [Kept] The pool as known.
  # @param left [Float] The share the word tells.
  # @param defeated [Boolean] Whether the word tells it defeated.
  # @param now [Integer] The time in milliseconds.
  # @return [Boolean] Whether it is.
  def behind?(key, was, left, defeated, now)
    @pending.key?(key) && !defeated && !was.defeated && left < 1.0 && left > left_at(was, now)
  end

  # Notes a defeat or a reset a push told, once per change.
  #
  # @param key [String] The pool.
  # @param defeated [Boolean] Whether the push tells it defeated.
  # @param by [String] Who defeated it.
  def tell(key, defeated, by)
    if defeated && !@told.key?(key)
      @told[key] = true
      @changes << [:defeated, key, by]
    elsif !defeated && @told.delete(key)
      @changes << [:back, key, by]
    end
  end

  # Finds the share of a pool left at a moment, as the relay counts it.
  #
  # @param kept [Kept] The pool.
  # @param now [Integer] The time in milliseconds.
  # @return [Float] The share.
  def left_at(kept, now)
    kept.defeated ? 0.0 : [kept.left + (@regen * [0, now - kept.at].max) / MINUTE_MS, 1.0].min
  end
end

# Stands in for a battle that fights a boss's pools (MGQOnline.Game's RaidFight).
class RaidFightStandIn
  # The least milliseconds between two reports as the battle's actions end.
  REPORT_MS = 2_000

  # The milliseconds between two takes of the pools' HP while the battle waits for commands.
  WAIT_SYNC_MS = 5_000

  # The smallest share of a pool's max a report carries.
  MIN_DELTA = 1.0e-12

  # One of the troop's own enemies: its pool, its place, its HP as last taken, whether its death
  # went out, whether its last report was refused, and the id of the enemy whose HP the base is.
  Member = Struct.new(:key, :index, :base, :killed, :held, :enemy_id)

  # @return [String] The battle's id.
  attr_reader :battle

  # @return [Array<Member>] The troop's own enemies.
  attr_reader :members

  # @return [Integer] The number of the battle's last report.
  attr_reader :seq

  # @return [Boolean] Whether a host's stream governs the battle.
  attr_reader :guest

  # Opens a battle nothing was reported of yet.
  #
  # @param world [String] The world.
  # @param battle [String] The battle's id.
  # @param keys [Array<String>] The pools of the troop's own enemies by their place.
  # @param guest [Boolean] Whether a host's stream governs it.
  def initialize(world, battle, keys, guest)
    @world = world
    @battle = battle
    @members = keys.each_with_index.map { |key, index| Member.new(key, index, nil, false, false, nil) }
    @guest = guest
    @seq = 0
    @reported_at = nil
    @synced_at = nil
  end

  # Runs a moment of the battle, see RaidFight.Turn.
  #
  # @param moment [String] The moment.
  # @param reporter [Boolean] Whether the player reports the battle now.
  # @param enemies [Hash{Integer => Array}] Each own enemy's HP, max HP, death and id by its place.
  # @param pools [PoolLedgerStandIn] The pools and the way to the relay.
  # @return [Hash] The reply, as PoolTopics writes it.
  def turn(moment, reporter, enemies, pools)
    now = pools.now
    @state = { "actions" => [], "killed" => false, "reported" => false, "took_over" => false, "rebuilt" => [] }
    case moment
    when "start" then sync(enemies, pools, false)
    when "phase"
      if reporting(enemies, reporter)
        report(enemies, pools, now)
        @synced_at = now
        sync(enemies, pools, false)
      end
    when "action"
      report(enemies, pools, now) if reporting(enemies, reporter) && !(@reported_at && now - @reported_at < REPORT_MS)
    when "wait"
      if reporting(enemies, reporter)
        @synced_at ||= now
        if now - @synced_at >= WAIT_SYNC_MS
          @synced_at = now
          sync(enemies, pools, false)
        end
      end
    when "turn_end" then sync(enemies, pools, true) if reporting(enemies, reporter)
    when "end" then report(enemies, pools, now) if reporting(enemies, reporter)
    when "take_over", "role" then reporting(enemies, reporter)
    end
    @state.merge("guest" => @guest, "report_in" => @reported_at && [0, @reported_at + REPORT_MS - now].max,
                 "sync_in" => @synced_at && [0, @synced_at + WAIT_SYNC_MS - now].max)
  end

  private

  # Tells whether the player reports the battle, taking it over from its host the first time.
  #
  # @param enemies [Hash] The enemies.
  # @param reporter [Boolean] Whether the player reports the battle now.
  # @return [Boolean] Whether it does.
  def reporting(enemies, reporter)
    unless reporter
      @guest = true
      return false
    end
    return true unless @guest

    @guest = false
    @members.each do |member|
      enemy = enemies[member.index]
      rebase(member, enemy[0], enemy[3]) if enemy
      member.held = false
    end
    @state["took_over"] = true
    true
  end

  # Gives the own enemies their pools' HP, and kills those whose pool is empty.
  #
  # @param enemies [Hash] The enemies.
  # @param pools [PoolLedgerStandIn] The pools.
  # @param only_kill [Boolean] Whether only enemies whose pool is empty change.
  def sync(enemies, pools, only_kill)
    return if @guest

    @members.each do |member|
      hp, mhp, dead, id = enemies[member.index]
      next unless hp

      pool = pools.pool(member.key)
      if pool.nil? || dead
        rebase(member, hp, id) if member.base.nil? && !only_kill
        next
      end

      left = pool[0]
      next if only_kill && left > 0

      target = left > 0 ? [(left * mhp).ceil, 1].max : 0
      if target <= 0
        @state["actions"] << [member.index, 0]
        @state["killed"] = true
        rebase(member, 0, id)
      elsif member.held
        next
      else
        @state["actions"] << [member.index, target] if hp != target
        rebase(member, target, id)
      end
    end
  end

  # Reports what each own enemy lost since its HP was last taken or reported.
  #
  # @param enemies [Hash] The enemies.
  # @param pools [PoolLedgerStandIn] The way to the relay.
  # @param now [Integer] The time in milliseconds.
  def report(enemies, pools, now)
    @reported_at = now
    @members.each do |member|
      hp, max, dead, id = enemies[member.index]
      next if member.killed || hp.nil?

      if member.enemy_id && member.enemy_id != id
        rebase(member, hp, id)
        @state["rebuilt"] << member.index
        next
      end
      next unless max > 0

      base = [member.base || max, max].min
      hp = [hp, max].min
      delta = [[(base - hp).to_f / max, -1.0].max, 1.0].min
      next if !dead && delta.abs < MIN_DELTA

      seq = @seq + 1
      unless pools.report(@world, member.key, @battle, "#{seq}\t#{format('%.10f', delta)}\t#{max}\t#{dead ? 1 : 0}")
        member.held = true
        next
      end

      @seq = seq
      rebase(member, hp, id)
      member.killed = dead
      member.held = false
      @state["reported"] = true
    end
  end

  # Takes an enemy's HP as the base its next report counts from.
  #
  # @param member [Member] The enemy's place.
  # @param hp [Integer] The HP.
  # @param id [Integer] The id of the enemy whose HP it is.
  def rebase(member, hp, id)
    member.base = hp
    member.enemy_id = id
  end
end

# Holds the stand-in against the golden cases of fixtures/pool, so it cannot drift from the C#
# ledger: every step of every scenario, and the relay's share left to the last bit.
def check_pool_stand_in
  golden = JSON.parse(File.read(File.join(POOL_FIXTURES, "ledger.json"), :encoding => "UTF-8"))
  wrong = []
  golden["scenarios"].each do |scenario|
    now = 1_000_000_000
    ledger = PoolLedgerStandIn.new { now }
    scenario["steps"].each_with_index do |step, index|
      case step["op"]
      when "push" then ledger.hear(step["key"], step["left"].to_f, step["max"], step["defeated"], step["by"], :pushed)
      when "own" then ledger.own(step["key"], step["delta"], step["max"], step["dead"])
      when "settle" then ledger.settled(step["key"])
      when "wait" then now += step["ms"]
      end
      view = ledger.pools.map { |key, left, max, defeated, by| [key, format("%.10f", left), max.round, defeated, defeated ? by : ""] }
      events = ledger.take_changes.map { |kind, key, _| [kind.to_s, key] }
      wrong << "#{scenario['name']}, step #{index}" unless [view, ledger.told_defeated, events] == [step["view"], step["told"], step["events"]]
    end
  end
  JSON.parse(File.read(File.join(POOL_FIXTURES, "relay.json")))["cases"].each do |moment|
    now = 1_000_000_000
    ledger = PoolLedgerStandIn.new { now }
    ledger.hear("Sara", moment["left"].to_f, 900, moment["defeated"], "", :fetched)
    now += moment["after"]
    wrong << "the relay's share after #{moment['after']} ms" unless ledger.pools[0][1] == moment["share"].to_f
  end
  check("the pools' stand-in keeps the pools as the golden cases say", wrong, [])
  check("the fights' stand-in reports and syncs as the golden cases say", check_turn_cases, [])
end

# The moments of the golden turns by their names, as the stand-in names them.
TURN_MOMENTS = { "rescale" => "start", "end_won" => "end", "end_lost" => "end" }

# Replays the golden turns of fixtures/pool/turns.json on the stand-in.
#
# @return [Array<String>] The steps that went another way.
def check_turn_cases
  golden = JSON.parse(File.read(File.join(POOL_FIXTURES, "turns.json"), :encoding => "UTF-8"))
  wrong = []
  golden["scenarios"].each do |scenario|
    now = 1_000_000_000
    pools = PoolLedgerStandIn.new { now }
    pools.enter(golden["world"])
    taking = true
    sent = []
    pools.reporter = lambda { |_world, key, battle, text| taking ? (sent << [key, battle, text]; true) : false }
    open = scenario["open"]
    pools.open_fight(golden["world"], open["battle"], open["keys"], open["guest"])
    enemies = []
    reporter = true
    scenario["steps"].each_with_index do |step, index|
      enemies = step["enemies"].map(&:dup) if step["enemies"]
      reporter = step["role"] != "guest" if step.key?("role")
      now += step["ms"].to_i
      taking = step["taking"] if step.key?("taking")
      pools.hear(step["push"][0], step["push"][1].to_f, step["push"][2], step["push"][3], "", :pushed) if step["push"]
      sent.clear
      moment = TURN_MOMENTS.fetch(step["moment"], step["moment"])
      reply = pools.turn_of("moment" => moment, "reporter" => reporter,
                            "enemies" => enemies.each_with_index.map { |(hp, mhp, dead, id), place| [place, hp, mhp, dead, id] })
      collapsed = []
      reply["actions"].each do |place, hp|
        enemies[place][0] = hp
        enemies[place][2] = hp <= 0
        collapsed << enemies[place][3] if hp <= 0
      end
      judged = reply["killed"] && enemies.all? { |enemy| enemy[2] } && %w(phase wait).include?(moment) ? 1 : 0
      fight = pools.fight
      state = fight && { "seq" => fight.seq, "guest" => fight.guest,
                         "members" => fight.members.map { |member| [member.base, member.killed, member.held, member.enemy_id] } }
      actual = [sent, enemies.map { |enemy| [enemy[0], enemy[2]] }, collapsed, judged, state]
      wrong << "#{scenario['name']}, step #{index}" unless actual == [step["reports"], step["after"], step["collapsed"], step["judged"], step["fight"]]
    end
  end
  wrong
end
