#----------------------------------------------------------------
#  raid_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-08: Answered the frozen fights' records, their check and end, tableau, fresh start and items given back with the values each test sets
#      Paulinchen  2026-11-05: Took the noted requests from bridge_support.rb
#                            - Answered the pools and the battle that fights them with the values each test sets
#                            - Answered a lost battle's defeat and its undo with the values each test sets
#                            - Created
#
#----------------------------------------------------------------

# Answers the topics of the raid bosses' rules (MGQOnline.Game's RaidTopics), of a Raid World's boss
# pools and the battle that fights them (PoolTopics) and of a lost raid boss battle's defeat
# (MGQOnline.Multiplayer's FreezeTopics) on a FakeBridge with the fixed values each test sets for its
# case. The scripts only forward the rules' answers; the C# tests cover the rules.

require_relative "bridge_support"

# Stands in for the DLL's answers of the raid bosses' rules and of a lost battle's defeat.
class RaidAnswers
  include NotedRequests

  # The table raid.bosses hands: the bosses the script tests fight, with the story's sections cut
  # down to them.
  TABLE = {
    "troops" => [
      [29, "Four bandits", "Four bandits", 9, "Tier 9 Raid Boss", "Part 1", "Four bandits"],
      [71, "Queen Harpy", "Queen Harpy", 9, "Tier 9 Raid Boss", "Part 1", "Queen Harpy"],
      [126, "Morrigan", "Morrigan", 7, "Tier 7 Raid Boss", "Part 1", "Morrigan"],
      [607, "Alma Elma, then Granberia", "Alma Elma, then Granberia", 7, "Heavenly Knight", "Part 2", "Alma Elma, then Granberia"],
      [609, "Alma Elma, then Granberia", "Alma Elma, then Granberia", 7, "Heavenly Knight", "Part 2", "Alma Elma, then Granberia"],
      [610, "Alma Elma, then Granberia", "Alma Elma, then Granberia", 7, "Heavenly Knight", "Part 2", "Alma Elma, then Granberia"],
      [807, "Spider Princess", "Spider Princess", 6, "Tier 6 Raid Boss", "Part 2", "Spider Princess"],
      [836, "Black Dahlia, Black Mamba and Black Rose", "Black Dahlia, Black Mamba and Black Rose (cap 55)", 5, "Tier 5 Raid Boss", "Part 2",
       "Black Dahlia, Black Mamba and Black Rose (cap 55)"],
      [838, "Black Alice", "Black Alice (cap 65)", 5, "Tier 5 Raid Boss", "Part 2", "Black Alice (cap 65)"],
      [868, "Sonya Mazda", "Sonya Mazda", 5, "Tier 5 Raid Boss", "Part 2", "Sonya Mazda"],
      [870, "Sonya Chaos", "Sonya Chaos", 4, "Tier 4 Raid Boss", "Part 2", "Sonya Chaos"],
      [1507, "Great Decision", "Great Decision", 5, "Tier 5 Raid Boss", "Part 3", "Great Decision"],
      [1509, "Great Decision", "Great Decision", 5, "Tier 5 Raid Boss", "Part 3", "Great Decision"],
      [1599, "Metatronne and Sandalphone", "Metatronne and Sandalphone", 4, "Archangel", "Angelic Dominion", "Metatronne and Sandalphone"],
      [1814, "Tamamo", "Tamamo (cap 83)", 4, "Six Ancestors", "Monster Realm", "Tamamo (cap 83)"],
      [2016, "Sisel, EX-Kyubi, Frere and Bloody Dragon", "Sisel, EX-Kyubi, Frere and Bloody Dragon", 2, "Tier 2 Raid Boss", "Chaos route", "Sisel"],
      [2017, "Sisel, EX-Kyubi, Frere and Bloody Dragon", "Sisel, EX-Kyubi, Frere and Bloody Dragon", 2, "Tier 2 Raid Boss", "Chaos route", "EX-Kyubi"],
      [2133, "The All-Knowing", "The All-Knowing", 1, "Tier 1 Raid Boss", "Chaos route", "The All-Knowing"],
      [2221, "Hiruko, Kanon and Kanade", "Hiruko, Kanon and Kanade", 1, "Six Ancestors", "Chaos route", "Hiruko, Kanon and Kanade"],
      [2219, "Chaos", "Chaos", 0, "Tier 0 Raid Boss", "Chaos route", "Chaos"],
      [2549, "Fourth Law", "Fourth Law", 1, "Chaos' Phantom", "Chaos Domain", "Fourth Law"],
      [3127, "Void Image of Paradise", "Void Image of Paradise", 1, "Chaos' Phantom", "Chaos Domain", "Void Image of Paradise"],
      [2410, "Chaos Maria", "Chaos Maria", 1, "Chaos' Phantom", "Chaos Domain", "Chaos Maria"],
    ],
    "tiers" => [[0, [["mhp", "50"], ["def", "5"], ["mdf", "5"]]], [1, [["mhp", "45"], ["def", "4.33"], ["mdf", "4.33"]]],
                [2, [["mhp", "40"], ["def", "3.67"], ["mdf", "3.67"]]], [3, [["mhp", "35"], ["def", "3"], ["mdf", "3"]]],
                [4, [["mhp", "30"], ["def", "2.33"], ["mdf", "2.33"]]], [5, [["mhp", "25"], ["def", "1.67"], ["mdf", "1.67"]]],
                [6, [["mhp", "20"]]], [7, [["mhp", "15"]]], [8, [["mhp", "10"]]], [9, [["mhp", "5"]]]],
    "key_troops" => [["Four bandits", 29], ["Queen Harpy", 71], ["Morrigan", 126], ["Alma Elma, then Granberia", 610], ["Spider Princess", 807],
                     ["Black Dahlia, Black Mamba and Black Rose (cap 55)", 836], ["Black Alice (cap 65)", 838], ["Sonya Mazda", 868], ["Sonya Chaos", 870],
                     ["Metatronne and Sandalphone", 1599], ["Tamamo (cap 83)", 1814], ["Sisel", 2016], ["EX-Kyubi", 2017], ["The All-Knowing", 2133], ["Hiruko, Kanon and Kanade", 2221],
                     ["Chaos", 2219], ["Fourth Law", 2549], ["Void Image of Paradise", 3127], ["Chaos Maria", 2410]],
    "stats" => ["def", "mdf"],
    "titles" => ["Heavenly Knight", "Archangel", "Six Ancestors", "Apostle of Chaos", "Phenomenon of Ruin", "Chaos' Phantom"],
    "sections" => [["Part 1", ["Four bandits", "Queen Harpy", "Morrigan"]],
                   ["Part 2", ["Alma Elma, then Granberia", "Spider Princess", "Black Dahlia, Black Mamba and Black Rose (cap 55)", "Black Alice (cap 65)",
                               "Sonya Mazda", "Sonya Chaos"]],
                   ["Part 3", ["Great Decision"]],
                   ["Angelic Dominion", ["Metatronne and Sandalphone"]],
                   ["Monster Realm", ["Tamamo (cap 83)"]],
                   ["Chaos route", ["Sisel, EX-Kyubi, Frere and Bloody Dragon", "The All-Knowing", "Hiruko, Kanon and Kanade", "Chaos"]],
                   ["Chaos Domain", ["Fourth Law", "Void Image of Paradise", "Chaos Maria"]]],
    "reads" => { "switches" => [87, 97], "variables" => [1001, 1011] },
  }

  # What freeze.records.end answers while a test sets nothing: the battle was not won, the record
  # stays as it is, and no spot or owner is named.
  ENDING = { "won" => false, "record" => nil, "spot" => nil, "whose" => nil }.freeze

  # @return [Hash{Integer => Hash}] What raid.kind answers in a Raid World ("pools"), by troop.
  attr_accessor :pool_kinds

  # @return [Hash{Integer => Hash}] What raid.kind answers outside a Raid World ("tiers"), by troop.
  attr_accessor :tier_kinds

  # @return [Hash{Integer => Hash}] What raid.troops answers of each troop, by troop.
  attr_accessor :troops

  # @return [String, nil] What freeze.defeat answers: why the defeat puts nothing back, nil when it does.
  attr_accessor :defeat

  # @return [Array<Array>] What freeze.undo answers of the items: [letter, id, change] each.
  attr_accessor :items

  # @return [Hash] What freeze.records.check answers: "listed" (the troops of the records that wait)
  #   and "dropped" ([troop, why] of each record whose fight is over).
  attr_accessor :checked

  # @return [Hash, nil] What freeze.records.held answers ("start" and "undone"), nil for every row.
  attr_accessor :held

  # @return [Hash] What freeze.records.end answers over ENDING: "won", "record", "spot" and "whose".
  attr_accessor :ending

  # @return [Hash, nil] What freeze.tableau answers, nil for stand-ins in place that block the
  #   fight's event alone.
  attr_accessor :tableau

  # @return [Hash] What freeze.fresh answers: "start", "site", "spot" and "refusal".
  attr_accessor :fresh

  # @return [Hash{Array => String}] What freeze.undo answers of each changed key, by kind and key:
  #   "start" or "was"; a key it lacks keeps the value the defeat left.
  attr_accessor :undo

  # Answers the topics on a bridge.
  #
  # @param fake [FakeBridge] The bridge.
  def initialize(fake)
    @asked = []
    clear
    fake.answer("raid.bosses") { |request| note("raid.bosses", request) && TABLE }
    fake.answer("raid.kind") { |request| note("raid.kind", request) && (request["mode"] == "tiers" ? @tier_kinds : @pool_kinds).fetch(request["troop"], {}) }
    fake.answer("raid.troops") { |request| note("raid.troops", request) && Array(request["troops"]).map { |troop| { "troop" => troop }.merge(@troops.fetch(troop, {})) } }
    fake.answer("raid.caps") { |request| note("raid.caps", request) && [] }
    fake.answer("freeze.defeat") { |request| note("freeze.defeat", request) && @defeat }
    fake.answer("freeze.undo") do |request|
      note("freeze.undo", request) && { "values" => Array(request["rows"]).map { |kind, key, _personal, _before| @undo[[kind, key]] }, "items" => @items }
    end
    fake.answer("freeze.records.check") { |request| note("freeze.records.check", request) && @checked }
    fake.answer("freeze.records.held") do |request|
      note("freeze.records.held", request) && (@held || { "start" => request["start"].map { true }, "undone" => request["undone"].map { true } })
    end
    fake.answer("freeze.records.end") { |request| note("freeze.records.end", request) && ENDING.merge(@ending) }
    fake.answer("freeze.tableau") do |request|
      note("freeze.tableau", request) && (@tableau || { "map" => request["map"], "at" => nil, "blocked" => [request["event"]], "callers" => 0 })
    end
    fake.answer("freeze.fresh") { |request| note("freeze.fresh", request) && @fresh }
  end

  # Forgets every answer and request, so each topic answers that the rules give nothing.
  def clear
    @pool_kinds = {}
    @tier_kinds = {}
    @troops = {}
    @defeat = nil
    @undo = {}
    @items = []
    @checked = { "listed" => [], "dropped" => [] }
    @held = nil
    @ending = {}
    @tableau = nil
    @fresh = { "start" => nil, "refusal" => "the test set no fresh start" }
    @asked.clear
  end
end

# Stands in for the DLL's answers of a Raid World's boss pools and of the battle that fights them.
class PoolAnswers
  include NotedRequests

  # @return [Hash] What raid.pools answers: the world and its pools, each as its key, the share
  #   left as text, its max, whether it is defeated and by whom.
  attr_accessor :state

  # @return [Hash, Proc] What raid.fight.turn answers, or a block that makes it of the request.
  attr_accessor :turn

  # @return [Array, nil] What raid.fight.export answers.
  attr_accessor :export

  # @return [Array, nil] What raid.fight.import answers: the count and whether it is a side battle.
  attr_accessor :import

  # @return [Boolean] What raid.pools.fetch answers: whether the fetch started.
  attr_accessor :fetch

  # Answers the topics on a bridge.
  #
  # @param fake [FakeBridge] The bridge.
  def initialize(fake)
    @fake = fake
    @asked = []
    clear
    fake.answer("raid.pools") { |request| note("raid.pools", request) && @state }
    fake.answer("raid.pools.fetch") { |world| note("raid.pools.fetch", world) && @fetch }
    fake.answer("raid.fight.open") { |request| note("raid.fight.open", request) && nil }
    fake.answer("raid.fight.turn") { |request| note("raid.fight.turn", request) && (@turn.respond_to?(:call) ? @turn.call(request) : @turn) }
    fake.answer("raid.fight.close") { |request| note("raid.fight.close", request) && nil }
    fake.answer("raid.fight.export") { |request| note("raid.fight.export", request) && @export }
    fake.answer("raid.fight.import") { |request| note("raid.fight.import", request) && @import }
  end

  # Forgets every answer and request: no pool of world w1, a turn that changes nothing, a fetch that
  # starts.
  def clear
    @state = { "world" => "w1", "pools" => [] }
    @turn = {}
    @export = nil
    @import = nil
    @fetch = true
    @asked.clear
  end

  # Sets a pool of world w1 as raid.pools tells it.
  #
  # @param key [String] The pool's key.
  # @param left [String] The share of its max left.
  # @param max [Integer] Its max HP.
  # @param defeated [Boolean] Whether it is empty for good.
  # @param by [String] Who emptied it.
  def pool(key, left, max = 6000, defeated = false, by = "")
    @state = { "world" => "w1", "pools" => @state["pools"].reject { |each| each[0] == key } + [[key, left, max, defeated, by]] }
  end

  # Tells the scripts that the relay emptied a pool, or that an admin's reset filled it again, as the
  # DLL's events do.
  #
  # @param key [String] The pool's key.
  # @param defeated [Boolean] Whether it is empty now.
  # @param by [String] Who emptied it.
  def push(key, defeated, by = "Someone")
    @fake.post(defeated ? "raid.boss_defeated" : "raid.boss_back", defeated ? { "key" => key, "by" => by } : { "key" => key })
    MGQ_Multiplayer::Bridge.frame
  end

  # Lists the moments of the battle the scripts handed raid.fight.turn.
  #
  # @return [Array<String>] The moments, oldest first.
  def moments
    asked("raid.fight.turn").map { |request| request["moment"] }
  end
end

# Answers the raid bosses' rules and a lost battle's defeat on a bridge, kept in $raid_answers.
#
# @param fake [FakeBridge] The bridge.
# @return [RaidAnswers] The answers.
def answer_raid_rules(fake)
  $raid_answers = RaidAnswers.new(fake)
end

# Answers a Raid World's boss pools and the battle that fights them on a bridge, kept in
# $pool_answers.
#
# @param fake [FakeBridge] The bridge.
# @return [PoolAnswers] The answers.
def answer_raid_pools(fake)
  $pool_answers = PoolAnswers.new(fake)
end
