#----------------------------------------------------------------
#  world_freeze.rbx
#
#  Changelog:
#      Paulinchen  2026-11-11: Told the version of the list it keeps
#      Paulinchen  2026-11-05: Left the world's list of frozen fights and when a fight is over to the DLL, which keeps both, and sent the story keys it asks for
#                            - Asked the DLL whether the player's story or the world's beat a frozen fight's boss
#                            - Left writing and reading a frozen fight's text to the DLL, handing it the fight as values
#                            - Read the bridge's frame as its clock
#      Paulinchen  2026-10-28: Read the fights each side plays in the other's stead from the freeze's tables
#      Paulinchen  2026-10-23: Sent and took each frozen fight as a key of the relay's story tracks instead of a list beside the whole story
#      Paulinchen  2026-10-17: Created
#
#----------------------------------------------------------------

# A Raid World's frozen boss fights: a player who lost a raid boss's story battle keeps the story at
# that battle (see battles_raid_freeze.rbx), and the world's story keeps it there for every player
# until the fight is over. The list and the one decision whether a fight is over are the DLL's
# (MGQOnline.Game's FrozenFights, the topics of MGQOnline.Multiplayer's FreezeTopics): a fight ends
# once the player won its battle, its pools are defeated, or the player's or the world's story beat
# its boss or the fight the other side plays in its stead, and that is final for the world. Each
# frozen fight is one key of the relay's story tracks by its troop (f<troop>), which this script
# sends as the DLL asks (writes); ENDED replaces a fight that ended for every game. An entry's held
# keys are the switches, variables and self switches the world's story holds at their value from
# before the fight's event ran (see MGQ_MpWorldStory.held_value), kept here as the game's values.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpWorldFreeze
  # What a fight's key holds once the fight ended, which the relay keeps in place of the fight.
  ENDED = false

  # Frames between two looks at the list, a second.
  CHECK_FRAMES = 60

  # The DLL's topic that hands out the list, see FreezeTopics.
  STATE_TOPIC = "freeze.fights.state"

  # The DLL's topic that notes the player's own frozen fight.
  NOTE_TOPIC = "freeze.fights.note"

  # The DLL's topic that takes the fights of the world's story.
  TAKE_TOPIC = "freeze.fights.take"

  # The DLL's topic that takes the world's story for the end rule.
  TOLD_TOPIC = "freeze.fights.told"

  # The DLL's topic that notes a battle won against a troop's pools.
  WON_TOPIC = "freeze.fights.won"

  # The DLL's topic that tells why fights are over.
  OVER_TOPIC = "freeze.fights.over"

  # The DLL's topic that forgets the fights and the battles won.
  FORGET_TOPIC = "freeze.fights.forget"

  # The letters the log names the held keys' kinds by: a switch, a variable, a self switch.
  KIND_LETTERS = ["s", "v", "ss"]

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "world freeze"

  # Forgets the frozen fights and the battles won, as at the title.
  def self.forget
    MGQ_Multiplayer::Bridge.call(FORGET_TOPIC) if MGQ_Multiplayer::Bridge.open?
    clear
  rescue => e
    log("forgetting the frozen fights failed: #{e.class}: #{e.message}")
  end

  # Forgets the list kept here.
  def self.clear
    @entries = []
    @index = [{}, {}, {}]
    @held = []
    @version = nil
    @checked_at = nil
  end

  clear

  # The open world's id.
  #
  # @return [String] The id, empty outside a Raid World.
  def self.world_id
    defined?(MGQ_MpWorldStory) ? MGQ_MpWorldStory.world_id.to_s : ""
  rescue
    ""
  end

  # What every request names: the open world and the player's story values.
  #
  # @return [Hash] "world" and "facts".
  def self.base
    { "world" => world_id, "facts" => MGQ_MpRaidBosses.facts }
  end

  # Asks the DLL for the list at most every CHECK_FRAMES, or now.
  #
  # @param now [Boolean] Whether to ask now.
  def self.check(now = false)
    frame = MGQ_Multiplayer::Bridge.frame_number
    return if !now && @checked_at && (frame - @checked_at).abs < CHECK_FRAMES

    @checked_at = frame
    answer = MGQ_Multiplayer::Bridge.call(STATE_TOPIC, base)
    return unless answer.is_a?(Hash)

    send_writes(answer["writes"])
    take_state(answer) unless answer["version"] == @version
  end

  # Takes the list the DLL handed, its held values made the game's.
  #
  # @param answer [Hash] "version", "entries" and "held".
  def self.take_state(answer)
    @version = answer["version"]
    @entries = Array(answer["entries"]).map { |entry| game_entry(entry) }
    @held = Array(answer["held"]).map { |kind, key, value| [kind, key, MGQ_MpStoryKeys.game_value(kind, value)] }
    @index = [{}, {}, {}]
    @held.each { |kind, key, value| @index[kind][key] = value if @index[kind] }
  end

  # Sends the story keys the DLL asks the relay to keep: each fight, or ENDED.
  #
  # @param writes [Array, nil] [troop, fight or false] each.
  def self.send_writes(writes)
    Array(writes).each do |troop, value|
      asked = defined?(MGQ_MpWorldStory) && MGQ_MpWorldStory.write_freeze(troop, value)
      log("the frozen fight against troop #{troop} #{value == ENDED ? 'ends for the world' : 'goes to the world'}#{asked ? '' : ', in this game alone: no Raid World story takes it'}")
    end
  end

  # Tells the version of the list kept here, which changes with the list.
  #
  # @return [Object, nil] The version the DLL named, nil before the first list.
  def self.version
    @version
  end

  # Lists the open world's frozen fights that have not ended, oldest first.
  #
  # @return [Array<Hash>] The entries, see battles_raid_freeze.rbx; the caller changes none.
  def self.entries
    check
    @entries.dup
  rescue => e
    log_once(:entries, "listing the frozen fights failed: #{e.class}: #{e.message}")
    []
  end

  # Finds the frozen fight against a troop.
  #
  # @param troop [Integer] The troop.
  # @return [Hash, nil] The entry, nil while no fight against it is frozen.
  def self.entry(troop)
    entries.find { |entry| entry["troop"] == troop.to_i }
  end

  # Reads the value the world's story holds a switch, variable or self switch at while a fight is
  # frozen.
  #
  # Called for every key of every comparison of the story, so it must stay cheap.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id or key.
  # @return [Array, nil] true and the value, nil for a key no frozen fight holds.
  def self.held_value(kind, key)
    return nil if @entries.empty?

    check
    values = @index[kind]
    values && values.key?(key) ? [true, values[key]] : nil
  rescue
    nil
  end

  # Lists every held key of the frozen fights, the oldest fight's value for a key two hold, asked
  # anew, since the caller puts these values into a story.
  #
  # @return [Array<Array>] Each key as kind, key and value.
  def self.held
    return [] if @entries.empty?

    check(true)
    @held.dup
  rescue
    []
  end

  # Notes the player's own frozen fight and has the DLL ask the relay to keep it for the world.
  # Called by battles_raid_freeze.rbx once a lost fight's undo ran.
  #
  # @param entry [Hash] The entry, see battles_raid_freeze.rbx.
  # @return [Boolean] Whether the list holds the fight now.
  def self.note(entry)
    answer = MGQ_Multiplayer::Bridge.call(NOTE_TOPIC, base.merge("entry" => plain_entry(entry)))
    return false unless answer.is_a?(Hash)

    send_writes(answer["writes"])
    check(true)
    answer["held"] ? true : false
  rescue => e
    log("noting a frozen fight failed: #{e.class}: #{e.message}")
    false
  end

  # Tells why troops' fights are over, the one decision every caller asks.
  #
  # @param troops [Array<Integer>] The troops.
  # @return [Hash{Integer => String}] Why, by the troop of each fight that is over.
  def self.over(troops)
    return {} if troops.empty?

    answer = MGQ_Multiplayer::Bridge.call(OVER_TOPIC, base.merge("troops" => troops.map { |troop| troop.to_i }))
    found = {}
    Array(answer).each { |troop, reason| found[troop] = reason if reason }
    found
  end

  # Reports whether the fight against a troop is over for the open world, which is final: no game
  # freezes it again. Called by battles_raid_freeze.rbx as a battle is set up.
  #
  # @param troop [Integer, String] The troop.
  # @return [Boolean] Whether it is.
  def self.final?(troop)
    over([troop]).key?(troop.to_i)
  rescue => e
    log_once(:final, "looking whether a fight ended for the world failed: #{e.class}: #{e.message}")
    false
  end

  # Notes that the player won a battle against a troop's pools, which ends its frozen fight at once.
  #
  # @param troop [Integer] The troop.
  def self.won(troop)
    MGQ_Multiplayer::Bridge.call(WON_TOPIC, "troop" => troop.to_i)
  rescue => e
    log("noting a won battle failed: #{e.class}: #{e.message}")
  end

  # Takes the frozen fights of the world's story the relay handed.
  #
  # @param keys [Hash{Integer => Object}] Each fight's key by troop: the fight as the DLL reads it
  #   (FrozenFightText), ENDED, or nil for a fight it cannot read.
  def self.take_keys(keys)
    answer = MGQ_Multiplayer::Bridge.call(TAKE_TOPIC, base.merge("keys" => keys.map { |troop, value| [troop.to_i, value] }))
    send_writes(answer["writes"]) if answer.is_a?(Hash)
    check(true)
  rescue => e
    log_once(:take_keys, "taking the world's frozen fights failed: #{e.class}: #{e.message}")
  end

  # Hands the DLL the world's story laid over the player's last, for the end rule. Called by
  # world_story.rbx once it wrote the relay's story while the player plays the world's.
  #
  # @param told [Array] The world's story: switches, variables and self switches.
  def self.world_told(told)
    answer = MGQ_Multiplayer::Bridge.call(TOLD_TOPIC, base.merge("told" => MGQ_MpRaidBosses.facts(told)))
    send_writes(answer["writes"]) if answer.is_a?(Hash)
    check(true)
  rescue => e
    log_once(:world_told, "following the world's story for the frozen fights failed: #{e.class}: #{e.message}")
  end

  # Turns an entry into what the DLL takes: its fields alone, each held value as the DLL takes it
  # (MGQ_MpStoryKeys.plain_of), a value no story carries left out.
  #
  # @param entry [Hash] The entry.
  # @return [Hash] The entry.
  def self.plain_entry(entry)
    held = Array(entry["held"]).map do |kind, key, value|
      plain = MGQ_MpStoryKeys.plain_of(kind, value)
      next log_once([:unsent, kind, key], "left the held #{KIND_LETTERS[kind]}#{key} out: its value is no kind the story carries") if plain.nil?

      [kind, key, plain]
    end
    { "troop" => entry["troop"], "site" => entry["site"], "outer" => entry["outer"], "scene" => entry["scene"] ? true : false,
      "tableau" => entry["tableau"], "spot" => entry["spot"], "held" => held.compact }
  end

  # Turns an entry the DLL read into the game's values, see plain_entry.
  #
  # @param entry [Hash] The entry.
  # @return [Hash] The entry.
  def self.game_entry(entry)
    entry.merge("held" => Array(entry["held"]).map { |kind, key, value| [kind, key, MGQ_MpStoryKeys.game_value(kind, value)] })
  end
end

# Game hooks of this script alone, through core_hooks.rbx.

begin
  MGQ_MpHooks.before(Scene_Title, :start, "world_freeze") { MGQ_MpWorldFreeze.forget }
rescue => e
  MGQ_MpWorldFreeze.log("hooks FAILED: #{e.class}: #{e.message}")
end
