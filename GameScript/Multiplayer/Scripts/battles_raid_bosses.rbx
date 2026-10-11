#----------------------------------------------------------------
#  battles_raid_bosses.rbx
#
#  Changelog:
#      Paulinchen  2026-10-11: Moved Adramelech from tier 8 to tier 6 and Morrigan to tier 7
#                            - Grouped the raid bosses by the story's sections, Part 1 to the Chaos route and the Chaos Domain, and found the section and the tier of a boss by its name
#      Paulinchen  2026-10-10: Counted the Three Nobles of Black, fought before Black Alice and again before the Heavenly Knights of Part 3, as raid bosses
#                            - Gave each raid boss a title for its HP bar, the group the game names it in
#                            - Ranked the raid bosses in tiers 0 to 9, each with the factors it gives their stats: 50 times the max HP and 5 times the defense and magic defense at tier 0, down to 5 times the max HP and the game's defenses at tier 9
#                            - Counted the six one-time bosses of the Chaos Domain as raid bosses
#      Paulinchen  2026-10-08: Created
#
#----------------------------------------------------------------

# The story's boss battles, by troop: the story milestone each belongs to, the highest base level
# the milestone allows once beaten (its cap), and whether the troop is the fight's last phase. A
# Raid World never lets a battle join a boss battle (battles_coop_hotjoin.rbx); the raid bosses'
# pools count a fight on its last phase.
#
# The game keeps no list of its own: its events turn switch 22 on right before every story boss
# battle and off right after it (see BOSS_SWITCH), and no story boss battle allows escaping or
# losing. The table holds every phase of a fight with several, and the bosses a milestone's quest
# fights before it.
module MGQ_MpRaidBosses
  # The switch the game's events turn on right before every story boss battle and off right after
  # it, the one the game's ero offer in boss battles reads, which also covers the bosses outside the
  # table.
  BOSS_SWITCH = 22

  # A story boss troop.
  #
  # @!attribute milestone [String] The story milestone the troop belongs to.
  # @!attribute cap [Integer, nil] The highest base level once the milestone is beaten, nil after
  #   the last.
  # @!attribute last [Boolean, Integer] Whether the troop is the fight's last phase; a switch's id
  #   when it is the last only while that switch is on.
  Boss = Struct.new(:milestone, :cap, :last)

  # The story's boss troops, by troop id: each one's milestone, cap and last phase, see Boss.
  # Salamander's fight ends with troop 751 on Luka's side (switch 4) and goes on to Granberia (752)
  # on Alice's. Troop 1675 (Doppel Lukas and Lucifina) ends both the Angelic Dominion and the
  # Monster Realm milestone of that name. The page-trailing fights without a boss (789 Walraune,
  # 1546 Giriel, 2680 Mind Ant) are left out.
  TROOPS = {
    # Part 1 and Part 2.
    26 => ["Four bandits", 10, false],
    27 => ["Four bandits", 10, false],
    28 => ["Four bandits", 10, false],
    29 => ["Four bandits", 10, true],
    71 => ["Queen Harpy", 15, true],
    126 => ["Morrigan", 18, true],
    327 => ["Adramelech", 25, true],
    607 => ["Alma Elma, then Granberia", 30, false],
    608 => ["Alma Elma, then Granberia", 30, false],
    609 => ["Alma Elma, then Granberia", 30, false],
    610 => ["Alma Elma, then Granberia", 30, true],
    705 => ["Lilith", 35, false],
    718 => ["Lilith", 35, false],
    874 => ["Lilith", 35, false],
    719 => ["Lilith", 35, true],
    751 => ["Salamander", 40, 4],
    752 => ["Salamander", 40, true],
    784 => ["Queen Elf", 43, false],
    785 => ["Queen Elf", 43, true],
    801 => ["Queen Mermaid", 45, false],
    802 => ["Queen Mermaid", 45, true],
    807 => ["Spider Princess", 47, true],
    812 => ["Queen Vampire", 50, false],
    813 => ["Queen Vampire", 50, false],
    814 => ["Queen Vampire", 50, true],
    836 => ["Black Dahlia, Black Mamba and Black Rose", 55, true],
    837 => ["Black Alice", 65, false],
    838 => ["Black Alice", 65, false],
    839 => ["Black Alice", 65, true],
    868 => ["Sonya Chaos", 55, false],
    869 => ["Sonya Chaos", 55, false],
    870 => ["Sonya Chaos", 55, true],

    # Part 3 before the Great Decision, and the Great Decision on either route.
    1451 => ["Garuda", 60, true],
    1501 => ["Black Dahlia, Black Mamba and Black Rose", 60, true],
    1502 => ["Tamamo", 61, true],
    1503 => ["Erubetie", 62, true],
    1504 => ["Granberia", 63, true],
    1505 => ["Great Decision", 65, false],
    1506 => ["Great Decision", 65, false],
    1507 => ["Great Decision", 65, true],
    1508 => ["Great Decision", 65, false],
    1509 => ["Great Decision", 65, true],

    # The Angelic Dominion route.
    1517 => ["Heaven's Gate", 67, true],
    1544 => ["Gabriela", 70, true],
    1554 => ["Uriela, Sabiriel and Fernandez", 75, false],
    1557 => ["Uriela, Sabiriel and Fernandez", 75, false],
    1558 => ["Uriela, Sabiriel and Fernandez", 75, true],
    1564 => ["Sariela", 78, true],
    1590 => ["Laplace", 80, true],
    1592 => ["Metatronne and Sandalphone", 83, false],
    1599 => ["Metatronne and Sandalphone", 83, true],
    1610 => ["Zion (three fights)", 85, false],
    1611 => ["Zion (three fights)", 85, false],
    1612 => ["Zion (three fights)", 85, true],
    1634 => ["Cosmos", 90, false],
    1635 => ["Cosmos", 90, true],
    1642 => ["Aži Dahāka", 95, true],
    1659 => ["Marcellus and Black Alice", 95, false],
    1660 => ["Marcellus and Black Alice", 95, true],
    1674 => ["Doppel Lukas and Lucifina", 100, false],
    1675 => ["Doppel Lukas and Lucifina", 100, true],
    1722 => ["Micaela", 105, true],
    1723 => ["Ilias", 115, true],
    1724 => ["Chaos Ilias", 120, false],
    1725 => ["Chaos Ilias", 120, true],

    # The Monster Realm route.
    1745 => ["Queen Eva", 67, true],
    1763 => ["Malboro Girl, then Kanon", 70, false],
    1769 => ["Malboro Girl, then Kanon", 70, true],
    1784 => ["Kanade", 75, true],
    1807 => ["Tamamo", 80, true],
    1814 => ["Tamamo", 83, true],
    1847 => ["Minagi and Alipheese the 10th", 85, false],
    1848 => ["Minagi and Alipheese the 10th", 85, true],
    1869 => ["Kagetsumugi and her dolls", 90, true],
    1891 => ["Hiruko", 95, true],
    1902 => ["Kagetsumugi and Magatsu-Karura, then Black Alice", 95, false],
    1903 => ["Kagetsumugi and Magatsu-Karura, then Black Alice", 95, true],
    1943 => ["Saja", 105, true],
    1944 => ["Alipheese", 115, true],
    1945 => ["Chaos Alipheese", 120, false],
    1946 => ["Chaos Alipheese", 120, true],

    # The Chaos route. Fights a milestone lets the player take in any order each end on their own.
    1959 => ["Kagetsumugi and her dolls", 125, true],
    1975 => ["Angolmois", 130, true],
    2042 => ["Greedy Papi, Gob, Teeny and Vanilla", 135, false],
    2091 => ["Greedy Papi, Gob, Teeny and Vanilla", 135, false],
    2092 => ["Greedy Papi, Gob, Teeny and Vanilla", 135, true],
    1983 => ["Gabriela and Kanon", 135, false],
    1984 => ["Gabriela and Kanon", 135, true],
    1987 => ["Uriela", 135, true],
    1989 => ["Kanade", 140, true],
    1995 => ["Hiruko", 140, false],
    1996 => ["Hiruko", 140, true],
    2001 => ["Magatsu-Omikami", 145, true],
    1999 => ["Apiro Lagos", 147, true],
    2003 => ["Zion and Laplace", 151, false],
    2004 => ["Zion and Laplace", 151, true],
    2005 => ["Sigrdrifa", 153, true],
    2006 => ["Metatronne and Sandalphone, then Singularity", 155, false],
    2010 => ["Metatronne and Sandalphone, then Singularity", 155, true],
    2016 => ["Sisel, EX-Kyubi, Frere and Bloody Dragon", 160, true],
    2017 => ["Sisel, EX-Kyubi, Frere and Bloody Dragon", 160, true],
    2018 => ["Sisel, EX-Kyubi, Frere and Bloody Dragon", 160, true],
    2019 => ["Sisel, EX-Kyubi, Frere and Bloody Dragon", 160, true],
    2029 => ["Saja", 168, true],
    2047 => ["World Drown", 175, true],
    2053 => ["Cosmos", 180, true],
    2054 => ["No Life King", 185, false],
    2061 => ["No Life King", 185, true],
    2062 => ["Angolmois", 190, true],
    2221 => ["Hiruko, Kanon and Kanade", 195, true],
    2090 => ["Baal Zebub", 203, true],
    2095 => ["Seven Deadly Sins vessels", 210, true],
    2096 => ["Seven Deadly Sins vessels", 210, true],
    2097 => ["Seven Deadly Sins vessels", 210, true],
    2098 => ["Seven Deadly Sins vessels", 210, false],
    2099 => ["Seven Deadly Sins vessels", 210, true],
    2102 => ["Seven Deadly Sins vessels", 210, true],
    2107 => ["Greedy, Envious and Slothful Eva", 213, false],
    2108 => ["Greedy, Envious and Slothful Eva", 213, false],
    2109 => ["Greedy, Envious and Slothful Eva", 213, true],
    2110 => ["Seven Deadly Sins", 215, true],
    2133 => ["The All-Knowing", 220, true],
    2224 => ["Agaliarept", 225, false],
    2225 => ["Agaliarept", 225, false],
    2226 => ["Agaliarept", 225, false],
    2227 => ["Agaliarept", 225, false],
    2228 => ["Agaliarept", 225, true],
    2137 => ["Echidna Queen", 228, true],
    2144 => ["Cthulhu", 230, true],
    2154 => ["Dimensional Eroder", 235, true],
    2157 => ["Star Eater", 240, false],
    2158 => ["Star Eater", 240, true],
    2176 => ["Black Alice", 245, true],
    2222 => ["Idea Lukas", 250, true],
    2185 => ["EX Sonya", 255, true],
    2187 => ["Koron", 260, false],
    2188 => ["Koron", 260, true],
    2211 => ["Goddess, Demon and Fiend", 275, true],
    2212 => ["Goddess, Demon and Fiend", 275, true],
    2213 => ["Goddess, Demon and Fiend", 275, true],
    2214 => ["World Breaker and Judgement", 285, false],
    2215 => ["World Breaker and Judgement", 285, true],
    2216 => ["Deus Ex Machina", 300, true],
    2217 => ["Chaos", nil, false],
    2218 => ["Chaos", nil, false],
    2219 => ["Chaos", nil, true],
  }

  # The one-time bosses outside the story that count as raid bosses too, by troop: each its own
  # fight of one phase under its name, without a cap, and its tier (see TIERS).
  #
  # The Megid Pandoras guarding several Chaos Domain maps share one troop, so they stay out.
  OPTIONAL = {
    2549 => ["Fourth Law", 1], 3338 => ["Null Lilith", 1], 2923 => ["Fifth Law - Nirvana", 1],
    3127 => ["Void Image of Paradise", 1], 2410 => ["Chaos Maria", 1], 2922 => ["Fifth Law - Fallen Angel", 1],
  }

  # What each tier of raid bosses changes, tier 0 the strongest: per stat of the game's (:mhp, :mmp,
  # :atk, :def, :mat, :mdf, :agi, :luk) the factor its enemies have, applied after the game's own
  # difficulty. A stat a tier leaves out stays as the game has it.
  TIERS = {
    0 => { :mhp => 50, :def => 5.0, :mdf => 5.0 },
    1 => { :mhp => 45, :def => 4.33, :mdf => 4.33 },
    2 => { :mhp => 40, :def => 3.67, :mdf => 3.67 },
    3 => { :mhp => 35, :def => 3.0, :mdf => 3.0 },
    4 => { :mhp => 30, :def => 2.33, :mdf => 2.33 },
    5 => { :mhp => 25, :def => 1.67, :mdf => 1.67 },
    6 => { :mhp => 20 },
    7 => { :mhp => 15 },
    8 => { :mhp => 10 },
    9 => { :mhp => 5 },
  }

  # The story's sections in story order, each with the troop of TROOPS it starts at in TROOPS' order,
  # running to the next one's start; the troops' ids interleave on the Chaos route, so the order
  # counts, not the ids. The bosses of OPTIONAL make a section of their own, OPTIONAL_SECTION.
  SECTIONS = [["Part 1", 26], ["Part 2", 607], ["Part 3", 1451], ["Angelic Dominion", 1517], ["Monster Realm", 1745], ["Chaos route", 1959]]

  # The section of the one-time bosses of OPTIONAL, after the story's.
  OPTIONAL_SECTION = "Chaos Domain"

  # The story's bosses of each tier, by their milestone's name (see milestone_key), in the order the
  # story meets them. The bosses of OPTIONAL carry their tier themselves.
  TIER_BOSSES = {
    0 => ["Chaos"],
    1 => ["Cosmos (cap 180)", "No Life King", "Angolmois (cap 190)", "Hiruko, Kanon and Kanade", "Baal Zebub",
          "Seven Deadly Sins vessels", "Greedy, Envious and Slothful Eva", "Seven Deadly Sins", "The All-Knowing", "Agaliarept",
          "Echidna Queen", "Cthulhu", "Dimensional Eroder", "Star Eater", "Black Alice (cap 245)", "Idea Lukas", "EX Sonya",
          "Koron", "Goddess, Demon and Fiend", "World Breaker and Judgement", "Deus Ex Machina"],
    2 => ["Kagetsumugi and her dolls (cap 125)", "Angolmois (cap 130)", "Greedy Papi, Gob, Teeny and Vanilla", "Gabriela and Kanon",
          "Uriela", "Kanade (cap 140)", "Hiruko (cap 140)", "Magatsu-Omikami", "Apiro Lagos", "Zion and Laplace", "Sigrdrifa",
          "Metatronne and Sandalphone, then Singularity", "Sisel, EX-Kyubi, Frere and Bloody Dragon", "Saja (cap 168)", "World Drown"],
    3 => ["Ilias", "Chaos Ilias", "Alipheese", "Chaos Alipheese"],
    4 => ["Heaven's Gate", "Gabriela", "Uriela, Sabiriel and Fernandez", "Sariela", "Laplace", "Metatronne and Sandalphone",
          "Zion (three fights)", "Cosmos (cap 90)", "Aži Dahāka", "Marcellus and Black Alice", "Doppel Lukas and Lucifina", "Micaela",
          "Queen Eva", "Malboro Girl, then Kanon", "Kanade (cap 75)", "Tamamo (cap 80)", "Tamamo (cap 83)", "Minagi and Alipheese the 10th",
          "Kagetsumugi and her dolls (cap 90)", "Hiruko (cap 95)", "Kagetsumugi and Magatsu-Karura, then Black Alice", "Saja (cap 105)"],
    5 => ["Sonya Chaos", "Black Dahlia, Black Mamba and Black Rose (cap 55)", "Black Alice (cap 65)", "Garuda", "Black Dahlia, Black Mamba and Black Rose (cap 60)", "Tamamo (cap 61)",
          "Erubetie", "Granberia", "Great Decision"],
    6 => ["Adramelech", "Queen Elf", "Queen Mermaid", "Spider Princess", "Queen Vampire"],
    7 => ["Morrigan", "Alma Elma, then Granberia", "Lilith", "Salamander"],
    8 => [],
    9 => ["Four bandits", "Queen Harpy"],
  }

  # The title above a raid boss's name on its HP bar, by the group the game's enemy library names it
  # in: each title with its bosses' milestone names (see milestone_key) or OPTIONAL names. A boss
  # outside them reads as a raid boss of its tier.
  TITLES = {
    "Heavenly Knight" => ["Alma Elma, then Granberia", "Tamamo (cap 61)", "Erubetie", "Granberia"],
    "Archangel" => ["Gabriela", "Uriela, Sabiriel and Fernandez", "Sariela", "Metatronne and Sandalphone", "Zion (three fights)"],
    "Six Ancestors" => ["Malboro Girl, then Kanon", "Kanade (cap 75)", "Tamamo (cap 80)", "Tamamo (cap 83)", "Minagi and Alipheese the 10th",
                        "Hiruko (cap 95)", "Saja (cap 105)", "Hiruko, Kanon and Kanade"],
    "Apostle of Chaos" => ["Apiro Lagos", "Idea Lukas", "EX Sonya"],
    "Phenomenon of Ruin" => ["Angolmois (cap 130)", "Magatsu-Omikami", "Metatronne and Sandalphone, then Singularity", "World Drown",
                             "Angolmois (cap 190)", "Baal Zebub", "Seven Deadly Sins", "Dimensional Eroder"],
    "Chaos' Phantom" => ["Fourth Law", "Null Lilith", "Fifth Law - Nirvana", "Void Image of Paradise", "Chaos Maria", "Fifth Law - Fallen Angel"],
  }

  # Finds the title above a boss's name on its HP bar, see TITLES.
  #
  # @param troop_id [Integer, String] The troop.
  # @return [String, nil] The title, such as "Archangel" or "Tier 6 Raid Boss"; nil for a troop
  #   that is no boss.
  def self.title(troop_id)
    key = milestone_key(troop_id)
    return nil unless key

    @titles ||= TITLES.each_with_object({}) { |(title, names), titles| names.each { |name| titles[name] = title } }
    @titles[key] || "Tier #{tier(troop_id)} Raid Boss"
  end

  # Finds a boss troop of the story or of OPTIONAL.
  #
  # @param troop_id [Integer, String] The troop.
  # @return [Boss, nil] The troop's milestone, cap and last phase, nil for a troop that is no boss.
  def self.at(troop_id)
    row = TROOPS[troop_id.to_i]
    return Boss.new(*row) if row

    optional = OPTIONAL[troop_id.to_i]
    optional && Boss.new(optional[0], nil, true)
  end

  # Finds the tier of a boss troop, see TIERS.
  #
  # @param troop_id [Integer, String] The troop.
  # @return [Integer, nil] The tier, nil for a troop that is no boss.
  def self.tier(troop_id)
    optional = OPTIONAL[troop_id.to_i]
    return optional[1] if optional

    key_tier(milestone_key(troop_id))
  end

  # Finds the tier of a boss by its name: its milestone's (see milestone_key) or its own in OPTIONAL.
  #
  # @param key [String, nil] The name.
  # @return [Integer, nil] The tier, nil for a name the tables lack.
  def self.key_tier(key)
    @tiers ||= TIER_BOSSES.each_with_object({}) { |(tier, names), tiers| names.each { |name| tiers[name] = tier } }
    @optional_tiers ||= Hash[OPTIONAL.values]
    @tiers[key] || @optional_tiers[key]
  end

  # Lists the story's sections in story order with their bosses' milestone names (see
  # milestone_key), each once, in the order the story meets them; the bosses of OPTIONAL last under
  # OPTIONAL_SECTION. Walks TROOPS once and keeps what it found.
  #
  # @return [Array<Array(String, Array<String>)>] Each section's name with its bosses' names.
  def self.sections
    @sections ||= begin
      starts = Hash[SECTIONS.map { |name, troop| [troop, name] }]
      found = TROOPS.keys.each_with_object([]) do |troop_id, list|
        list << [starts[troop_id], []] if starts.key?(troop_id)
        key = milestone_key(troop_id)
        list.last[1] << key unless list.last[1].include?(key)
      end
      found << [OPTIONAL_SECTION, OPTIONAL.values.map(&:first)]
    end
  end

  # Finds the section a boss belongs to, see sections.
  #
  # @param boss [Integer, String, nil] Its troop, or its milestone's name (see milestone_key) or its
  #   own in OPTIONAL.
  # @return [String, nil] The section's name, nil for a boss the tables lack.
  def self.section(boss)
    @section_of ||= sections.each_with_object({}) { |(name, keys), found| keys.each { |key| found[key] = name } }
    @section_of[boss.to_s] || @section_of[milestone_key(boss).to_s]
  end

  # Finds the name of a boss troop's milestone, with its cap where several milestones share the
  # name, such as "Tamamo (cap 61)".
  #
  # @param troop_id [Integer, String] The troop.
  # @return [String, nil] The name, nil for a troop that is no boss.
  def self.milestone_key(troop_id)
    boss = at(troop_id)
    return nil unless boss

    @caps ||= TROOPS.values.each_with_object({}) { |row, caps| (caps[row[0]] ||= []) << row[1] }
    @caps.fetch(boss.milestone, []).uniq.size > 1 ? "#{boss.milestone} (cap #{boss.cap})" : boss.milestone
  end

  # Finds the factor a boss troop's tier gives one of its enemies' stats.
  #
  # @param troop_id [Integer, String] The troop.
  # @param stat [Symbol] The stat, such as :mhp.
  # @return [Numeric] The factor, 1 for a stat the tier leaves as it is or a troop that is no boss.
  def self.factor(troop_id, stat)
    tier = tier(troop_id)
    tier ? TIERS.fetch(tier, {}).fetch(stat, 1) : 1
  end

  # Lists the stats any tier changes besides max HP, whose methods the raid pool then wraps.
  #
  # @return [Array<Symbol>] The stats.
  def self.tier_stats
    TIERS.values.map(&:keys).flatten.uniq - [:mhp]
  end

  # Reports whether a troop is one of the story's bosses or of OPTIONAL.
  #
  # @param troop_id [Integer, String] The troop.
  # @return [Boolean] Whether it is.
  def self.boss?(troop_id)
    TROOPS.key?(troop_id.to_i) || OPTIONAL.key?(troop_id.to_i)
  end

  # Reports whether a troop is the last phase of its boss fight, reading the side's switch where
  # that decides it.
  #
  # @param troop_id [Integer, String] The troop.
  # @return [Boolean] Whether it is, false for a troop that is no story boss.
  def self.last_phase?(troop_id)
    boss = at(troop_id)
    return false unless boss
    return boss.last if boss.last == true || boss.last == false

    $game_switches[boss.last] ? true : false
  end

  # Reports whether the battle running is a boss battle: its troop is one of the story's bosses, or
  # the game's events marked it as one (BOSS_SWITCH).
  #
  # @param troop_id [Integer, String] The battle's troop.
  # @return [Boolean] Whether it is.
  def self.battle?(troop_id)
    boss?(troop_id) || ($game_switches && $game_switches[BOSS_SWITCH]) ? true : false
  end
end
