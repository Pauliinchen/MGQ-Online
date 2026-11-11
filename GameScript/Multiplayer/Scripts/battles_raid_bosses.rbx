#----------------------------------------------------------------
#  battles_raid_bosses.rbx
#
#  Changelog:
#      Paulinchen  2026-11-11: Answered no table while the bridge is closed without counting it as a failed read, and removed tier_stats
#      Paulinchen  2026-11-05: Read the bosses' table from the DLL, which keeps it and decides by it, and handed it the story values its rules read
#      Paulinchen  2026-10-11: Counted 22 more story bosses as raid bosses
#                            - Moved Adramelech to tier 5 and Sonya Chaos to tier 4
#                            - Moved Adramelech from tier 8 to tier 6 and Morrigan to tier 7
#                            - Grouped the raid bosses by the story's sections and found a boss's section and tier by its name
#      Paulinchen  2026-10-10: Counted the Three Nobles of Black as raid bosses
#                            - Gave each raid boss a title for its HP bar
#                            - Ranked the raid bosses in tiers 0 to 9, each with factors for their stats
#                            - Counted the six one-time bosses of the Chaos Domain as raid bosses
#      Paulinchen  2026-10-08: Created
#
#----------------------------------------------------------------

# The story's boss battles and the raid bosses as the DLL's table names them (MGQOnline.Game's
# BossTable, topic TOPIC): each boss troop's milestone, its name, tier, bar title, section and pool
# key, the tiers' stat factors and the story's sections. The rules that decide by the table are the
# DLL's too (MGQOnline.Game's BossRules): the scripts hand them the story values they read (facts)
# with each question, see battles_raid_pool.rbx and battles_raid_tiers.rbx.
module MGQ_MpRaidBosses
  # The switch the game's events turn on right before every story boss battle and off right after
  # it, the one the game's ero offer in boss battles reads, which also covers the bosses outside the
  # table.
  BOSS_SWITCH = 22

  # The DLL's topic of the table.
  TOPIC = "raid.bosses"

  # Frames between two asks for the table while the DLL gives none, a second.
  RETRY_FRAMES = 60

  # A boss troop as the table names it.
  #
  # @!attribute troop [Integer] The troop.
  # @!attribute milestone [String] The story milestone it belongs to.
  # @!attribute name [String] Its milestone's name, with its cap where several share the name.
  # @!attribute tier [Integer, nil] Its tier.
  # @!attribute title [String] The title above its name on its HP bar.
  # @!attribute section [String, nil] The story's section it belongs to.
  # @!attribute key [String, nil] Its pool's key, nil for one the relay refuses.
  Boss = Struct.new(:troop, :milestone, :name, :tier, :title, :section, :key)

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "raid bosses"

  # The table, nil until the DLL handed it.
  @table = nil

  # Reads the table once the DLL hands it, handing it how many enemies each troop's setup makes;
  # while the DLL gives none, it is asked again every RETRY_FRAMES.
  #
  # A read while the bridge is closed is no failed one: the battle server reads the table before
  # each battle's child opens the bridge, and every child would inherit the failure.
  #
  # @return [Hash] :troops (Boss by troop), :order (the troops in story order), :tiers ({stat =>
  #   factor} by tier), :stats, :titles, :sections, :reads ([switches, variables]) and :key_troops
  #   (the last phase of each pool key's boss); empty while the DLL does not answer.
  def self.table
    return @table if @table && (@sized || $data_troops.nil?)
    return {} unless MGQ_Multiplayer::Bridge.open?
    return {} if @failed_at && MGQ_Multiplayer::Bridge.frame_number - @failed_at < RETRY_FRAMES

    answer = MGQ_Multiplayer::Bridge.call(TOPIC, "sizes" => sizes)
    unless answer.is_a?(Hash) && answer["troops"].is_a?(Array)
      @failed_at = MGQ_Multiplayer::Bridge.frame_number
      log_once(:none, "the DLL hands no table of the raid bosses yet")
      return {}
    end

    @sized = !$data_troops.nil?
    @table = table_of(answer)
  rescue => e
    @failed_at = MGQ_Multiplayer::Bridge.frame_number
    log_once(:table, "reading the raid bosses' table failed: #{e.class}: #{e.message}")
    {}
  end

  # Reads the table the DLL handed, see table.
  #
  # @param answer [Hash] The answer of TOPIC.
  # @return [Hash] The table.
  def self.table_of(answer)
    troops = {}
    key_troops = {}
    answer["troops"].each do |troop, milestone, name, tier, title, section, key|
      troops[troop] = Boss.new(troop, milestone, name, tier, title, section, key)
    end
    Array(answer["key_troops"]).each { |key, troop| key_troops[key] = troop }
    tiers = {}
    Array(answer["tiers"]).each { |tier, stats| tiers[tier] = Hash[stats.map { |stat, factor| [stat.to_sym, factor.to_f] }] }
    reads = answer["reads"] || {}
    { :troops => troops, :order => answer["troops"].map(&:first), :tiers => tiers, :stats => Array(answer["stats"]).map(&:to_sym),
      :titles => Array(answer["titles"]), :sections => Array(answer["sections"]), :reads => [Array(reads["switches"]), Array(reads["variables"])],
      :key_troops => key_troops }
  end

  # Counts the enemies the game's setup of every troop makes, where that is not one: its members
  # whose enemy the database has.
  #
  # @return [Array<Array(Integer, Integer)>] Each troop with its count.
  def self.sizes
    return [] unless $data_troops && $data_enemies

    $data_troops.each_with_index.map do |troop, id|
      count = troop ? troop.members.count { |member| $data_enemies[member.enemy_id] } : 1
      count == 1 ? nil : [id, count]
    end.compact
  end

  # Writes the story values the DLL's rules read, of the game or of a story: the map and the
  # switches and variables the table names.
  #
  # @param story [Array, nil] A story's switches and variables, as MGQ_MpStoryState.raw_state;
  #   nil for the game's.
  # @return [Hash] "map", "s" and "v".
  def self.facts(story = nil)
    switches, variables = story || [$game_switches, $game_variables]
    read_switches, read_variables = table[:reads] || [[], []]
    { "map" => story.nil? && $game_map ? $game_map.map_id : 0, "s" => read_switches.map { |id| switches && switches[id] ? true : false },
      "v" => read_variables.map { |id| (value = variables && variables[id]).is_a?(Integer) ? value : 0 } }
  end

  # Finds a boss troop of the story or a one-time boss.
  #
  # @param troop_id [Integer, String] The troop.
  # @return [Boss, nil] The boss, nil for a troop that is none.
  def self.at(troop_id)
    (table[:troops] || {})[troop_id.to_i]
  end

  # Lists every boss troop, in story order.
  #
  # @return [Array<Integer>] The troops.
  def self.troops
    table[:order] || []
  end

  # Finds the troop of a boss's pool key: its last phase.
  #
  # @param key [String] The boss's key, see key.
  # @return [Integer, nil] The troop, nil for none.
  def self.troop_of_key(key)
    (table[:key_troops] || {})[key]
  end

  # Finds the tier of a boss troop.
  #
  # @param troop_id [Integer, String, nil] The troop.
  # @return [Integer, nil] The tier, nil for a troop that is no boss.
  def self.tier(troop_id)
    boss = troop_id && at(troop_id)
    boss && boss.tier
  end

  # Finds the tier of a boss by its name.
  #
  # @param key [String, nil] Its milestone's name (see milestone_key), or a one-time boss's own.
  # @return [Integer, nil] The tier, nil for a name the table lacks.
  def self.key_tier(key)
    boss = (table[:troops] || {}).values.find { |each| each.name == key }
    boss && boss.tier
  end

  # Finds the title above a boss's name on its HP bar.
  #
  # @param troop_id [Integer, String] The troop.
  # @return [String, nil] The title, such as "Archangel" or "Tier 6 Raid Boss"; nil for a troop
  #   that is no boss.
  def self.title(troop_id)
    boss = at(troop_id)
    boss && boss.title
  end

  # Lists the titles a raid boss's bar may carry besides its tier's.
  #
  # @return [Array<String>] The titles.
  def self.titles
    table[:titles] || []
  end

  # Lists the story's sections in story order with their bosses' names, the one-time bosses last.
  #
  # @return [Array<Array(String, Array<String>)>] Each section's name with its bosses' names.
  def self.sections
    table[:sections] || []
  end

  # Finds the section a boss belongs to.
  #
  # @param boss [Integer, String, nil] Its name (see milestone_key), or its troop.
  # @return [String, nil] The section's name, nil for a boss the table lacks.
  def self.section(boss)
    [boss.to_s, milestone_key(boss).to_s].each do |name|
      found = sections.find { |_section, names| names.include?(name) }
      return found[0] if found
    end
    nil
  end

  # Finds the name of a boss troop's milestone, with its cap where several milestones share the
  # name, such as "Tamamo (cap 61)".
  #
  # @param troop_id [Integer, String] The troop.
  # @return [String, nil] The name, nil for a troop that is no boss.
  def self.milestone_key(troop_id)
    boss = at(troop_id)
    boss && boss.name
  end

  # Finds a troop's pool key.
  #
  # @param troop_id [Integer, String] The troop.
  # @return [String, nil] The key, nil for a troop that is no boss or a key the relay refuses.
  def self.key(troop_id)
    boss = at(troop_id)
    boss && boss.key
  end

  # Lists the tiers with the factors each gives the stats it changes.
  #
  # @return [Hash{Integer => Hash{Symbol => Float}}] The factors by stat, by tier.
  def self.tiers
    table[:tiers] || {}
  end

  # Finds the factor a boss troop's tier gives one of its enemies' stats.
  #
  # @param troop_id [Integer, String] The troop.
  # @param stat [Symbol] The stat, such as :mhp.
  # @return [Numeric] The factor, 1 for a stat the tier leaves as it is or a troop that is no boss.
  def self.factor(troop_id, stat)
    tier = tier(troop_id)
    tier ? tiers.fetch(tier, {}).fetch(stat, 1) : 1
  end

  # Reports whether a troop is one of the story's bosses or a one-time boss.
  #
  # @param troop_id [Integer, String] The troop.
  # @return [Boolean] Whether it is.
  def self.boss?(troop_id)
    at(troop_id) ? true : false
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
