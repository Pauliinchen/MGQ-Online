#----------------------------------------------------------------
#  battles_raid_bosses.rbx
#
#  Changelog:
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
  # it, "Seduction During Boss Decision", which also covers the bosses outside the table.
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
    837 => ["Black Alice", 65, false],
    838 => ["Black Alice", 65, false],
    839 => ["Black Alice", 65, true],
    868 => ["Sonya Chaos", 55, false],
    869 => ["Sonya Chaos", 55, false],
    870 => ["Sonya Chaos", 55, true],

    # Part 3 before the Great Decision, and the Great Decision on either route.
    1451 => ["Garuda", 60, true],
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

  # Finds a story boss troop.
  #
  # @param troop_id [Integer, String] The troop.
  # @return [Boss, nil] The troop's milestone, cap and last phase, nil for a troop that is no story
  #   boss.
  def self.at(troop_id)
    row = TROOPS[troop_id.to_i]
    row && Boss.new(*row)
  end

  # Reports whether a troop is one of the story's bosses.
  #
  # @param troop_id [Integer, String] The troop.
  # @return [Boolean] Whether it is.
  def self.boss?(troop_id)
    TROOPS.key?(troop_id.to_i)
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
