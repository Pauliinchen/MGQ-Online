#----------------------------------------------------------------
#  coop_story.rbx
#
#  Changelog:
#      Paulinchen  2026-10-06: Let members behind the leader keep the story they play together too, catching up with the story's skills, companions and items the leader holds, and keeping their own side quests
#                            - Told members the story skills Luka learns while the story plays
#                            - Kept every chest the member's own when they catch up, on every map
#                            - Forgot what waited before the leader's whole story covered it
#                            - Read the player's own companions past a story's temporary party
#                            - Never took a companion into the roster twice in a world
#                            - Packed the whole story, which a late story's lists would make too large for a message
#                            - Kept switches from 7000, the story's boss flags, out of the awakening switches
#                            - Sent the switches and self switches the story turned off with the whole story
#                            - Kept the side each player chose, Alice's or Ilias's, as their own until the Great Decision, and asked a member without one to choose, bringing in the companion the choice brings
#                            - Gave a member the skills and companions their own side gets in the events where the sides differ, once the leader's story got past them, before the Great Decision
#      Paulinchen  2026-10-04: Lent members the key items the leader holds, told with the story and on every change, so a crash, a load or a duel lends them again, and held back the story's gifts during a duel or before the story is borrowed again
#                            - Kept where the Pocket Castle's way out returns each player their own
#                            - Lent the key items of the leader's story to members not as far along, taken back when they get their own story back and left out of their saves
#                            - Renamed from mp_coop_story.rbx
#      Paulinchen  2026-10-03: Kept the warp ban as each player's own, since it tells of the place they stand in
#                            - Called the scripts that load before this one without asking whether they loaded
#                            - Sent messages, showed notices and read the world, the own id and the own seat through MGQ_MpOverworldSync
#                            - Logged through MGQ_MpLog
#      Paulinchen  2026-10-02: Gave members as far along as the leader the items, gold and departures of the leader's story too
#                            - Kept what a member as far along as the leader changed in their own game while in the party
#                            - Ended the awakening switches with the last companion's, as the affection variables end
#                            - Followed the map's update through core_hooks.rbx
#      Paulinchen  2026-10-01: Kept the places of the player's party their own, so the leader's fewer never cut it
#      Paulinchen  2026-09-30: Sent and took the party's messages through coop.rbx, which drops those of another party
#                            - Registered with overworld_sync.rbx for its messages instead of being asked by overworld.rbx
#                            - Moved into Patch/Multiplayer/Scripts as coop_story.rbx, which Multiplayer.rb loads
#                            - Renamed from mp_story.rb, with the module MGQ_MpCoopStory
#                            - Kept what members as far along as the leader play together, companions who join included
#                            - Kept chests the player's own while they play the leader's story
#                            - Created
#
#----------------------------------------------------------------

# The story a party plays. Outside a party every player plays their own story. In a party, the
# members borrow the leader's story, the switches, variables and self switches the game's events
# read, and get their own back when they leave or the leader goes. What is the player's own, their
# party, their side, their companions' awakening and their affection, stays theirs throughout, and
# every save a member makes holds their own story. A member as far along as the leader keeps what
# they play together: the story's changes, its items, gold and companions, and what changed in their
# own game. A member behind the leader keeps the leader's story and catches up with the skills,
# companions and items the story gave the leader, those of their own side where the sides differ.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpCoopStory
  # Frames between two messages of the leader, a quarter of a second at 60 frames per second.
  SEND_FRAMES = 15

  # Frames between two requests for the leader's story, two seconds, until it came.
  ASK_FRAMES = 120

  # The switch that bans warping, such as with a Harpy Feather. The game's events turn it on where
  # the player enters a cave or a building and off where they leave it, so it tells of the place a
  # player stands in, not of the story.
  WARP_BAN = defined?(NWConst::Sw::WARP_BAN) ? NWConst::Sw::WARP_BAN : 100

  # The switch that tells the player took Alice along.
  ALICE_CHOSEN = 4

  # The switch that tells the player took Ilias along.
  ILIAS_CHOSEN = 5

  # The switches of the side the player chose, their own until the Great Decision, which sets the
  # side anew with the route the party takes.
  SIDE_SWITCHES = [ALICE_CHOSEN, ILIAS_CHOSEN]

  # Switches that are the player's own: configuration mirrored in switches (95, 445-447, 502), the
  # warp ban of the place they stand in, and the switches that tell whether a companion is in the
  # party (1001-2000).
  PERSONAL_SWITCHES = [95, WARP_BAN, 445, 446, 447, 502, 1001..2000]

  # First switch that tells whether a companion awakened, one per companion.
  AWAKENING_SWITCHES = 6000

  # Last switch that tells whether a companion awakened. The switches from 7000 tell which story
  # bosses the player defeated, such as "Eden Defeated", and belong to the story.
  AWAKENING_LAST = 6999

  # Variables that are the player's own: where the Pocket Castle's way out returns them (21-23, the
  # map, x and y where they used the castle's item), the places their party has beyond eight (56),
  # since the game cuts a party down to its places, where a game over returns them (1002) and
  # monsters' friendliness (2000-2999).
  PERSONAL_VARIABLES = [21..23, 56, 1002, 2000...3000]

  # First variable that holds a companion's affection, one per companion.
  AFFECTION_VARIABLES = 3000

  # Variables that tell how far along a story is: the main story (1001) and the three routes'
  # progress (1141-1143).
  STORY_MARKERS = [1001, 1141, 1142, 1143]

  # Variables of the routes after the Great Decision, where the sides no longer differ in rewards.
  ROUTE_MARKERS = [1141, 1142, 1143]

  # The character whose story skills count, Luka.
  HERO = 1

  # Messages that change what a member holds, which wait while the member cannot keep them, see
  # held_back?.
  HOLDINGS = %w(gain recruit depart hold learn)

  # Messages that wait at most for the member to keep them.
  MAX_HELD = 100

  # Bytes the leader's whole story takes at most in a message, below the 256 KB one carries.
  MAX_FULL_BYTES = 200_000

  @own = nil
  @leader_id = nil
  @sent = nil
  @frames = 0
  @ask_frames = 0

  # Reports whether the hooks can be installed.
  #
  # A second copy of this script would wrap the same methods under the same names, and each hook
  # would then call itself until the stack overflows.
  #
  # @return [Boolean] false when the hooks are in place already.
  def self.hookable?
    !Game_Switches.method_defined?(:mgq_mp_data)
  end

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "co-op story"

  # Reports whether the player plays the leader's story now.
  #
  # @return [Boolean] Whether they do.
  def self.guest?
    !@own.nil?
  end

  # Finds the leader of the player's party, through coop.rbx.
  #
  # @return [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The leader, :me for the player, nil outside a party.
  def self.leader
    return nil unless MGQ_MpOverworldSync.in_world?

    MGQ_MpCoop::Party.leader
  end

  # Follows the party for one frame: the leader tells what changed, a member borrows the leader's
  # story, and a player who left the party gets their own back. Called after the map's update.
  def self.update
    leader = self.leader
    restore if guest? && !leader.is_a?(MGQ_MpOverworldSync::Peers::Peer)
    take_held(leader)
    if leader == :me
      lead
    else
      @sent = nil
      @sent_held = nil
      follow(leader) if leader
      ask_side(leader) if guest?
    end
  rescue => e
    log_once(:update, "update failed: #{e.class}: #{e.message}")
  end

  # As leader, tells the members what of the story changed since the last time.
  def self.lead
    if MGQ_MpCoop::Party.members.empty?
      @sent = nil
      @sent_keys = nil
      @sent_held = nil
      @held_signature = nil
      return
    end

    @frames += 1
    return if @frames < SEND_FRAMES

    @frames = 0
    now = raw_state
    changes = @sent ? delta(@sent, now) : nil
    @sent = now if changes.nil? || changes.values.all?(&:empty?) || tell(-1, "delta", changes)
    keys = key_items
    @sent_keys = keys if keys != @sent_keys && tell(-1, "keys", "k" => write_keys(keys))
    held = write_holdings(holdings(keys))
    @sent_held = held if held != @sent_held && tell(-1, "hold", held)
  end

  # Lists the ids of the player's own companions, those in the party and those waiting at the
  # castle, past a story's temporary party, which the game's own list shows while it plays.
  #
  # @return [Array<Integer>] The ids.
  def self.roster_ids
    own = MGQ_MpGame.get($game_party, :include_actors)
    own = $game_party.include_actors if own.nil? && $game_party.respond_to?(:include_actors)
    own ? own.to_a : $game_party.all_members.compact.map(&:id)
  end

  # Lists the player's own companions, see roster_ids.
  #
  # @return [Array<Game_Actor>] The companions.
  def self.roster
    roster_ids.map { |id| $game_actors[id] }.compact
  end

  # Reports whether a companion about to join is in the player's own roster already, while a world
  # is open. Called before the game takes a companion into its roster.
  #
  # @param id [Integer] The companion.
  # @return [Boolean] Whether they are.
  def self.held_already?(id)
    MGQ_MpOverworldSync.in_world? && in_roster?(id)
  rescue => e
    log_once(:held_already, "checking the roster failed: #{e.class}: #{e.message}")
    false
  end

  # Reports whether a companion is in the player's own roster, see roster_ids.
  #
  # @param id [Integer] The companion.
  # @return [Boolean] Whether they are.
  def self.in_roster?(id)
    roster_ids.include?(id)
  end

  # As member, asks the leader for their story until it came, again whenever the leader changes.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer] The leader.
  def self.follow(leader)
    id = leader.state["id"].to_s
    if id != @leader_id
      # A new leader has another story: the member first gets their own back, with what they
      # played along.
      restore if guest?
      @leader_id = id
      @waiting = true
      @ask_frames = ASK_FRAMES
    end
    return unless @waiting

    @ask_frames += 1
    return if @ask_frames < ASK_FRAMES

    @ask_frames = 0
    tell(leader.seat, "ask", {})
  end

  # Takes a message about the story. Called by coop.rbx.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it.
  # @param message [Hash] The message's fields.
  def self.take(peer, message)
    kind = message["story"]
    return hold_back(message) if HOLDINGS.include?(kind) && leader.equal?(peer) && held_back?

    case kind
    when "ask"
      if leader == :me && MGQ_MpCoop::Party.member?(peer.state)
        keys = key_items
        tell(peer.seat, "full", full(raw_state).merge("k" => write_keys(keys)).merge(write_holdings(holdings(keys))))
      end
    when "full"
      if leader.equal?(peer)
        first = !guest?
        held = read_holdings(message)
        borrow(peer, decode_full(message), held)
        lend_keys(peer, read_keys(message["k"]))
        catch_up(peer, held, first)
        drop_covered(first && @keeps && !@same)
      end
    when "delta"
      apply(decode_delta(message)) if leader.equal?(peer) && guest? && !@waiting
    when "keys"
      lend_keys(peer, read_keys(message["k"])) if leader.equal?(peer) && guest? && !@waiting
    when "hold"
      catch_up(peer, read_holdings(message), false) if leader.equal?(peer) && guest? && !@waiting
    when "learn"
      learn_told(peer, message["skill"].to_i) if leader.equal?(peer) && guest? && @keeps
    when "recruit"
      recruit(peer, message["actor"].to_i) if leader.equal?(peer) && guest? && @keeps
    when "depart"
      depart(peer, message["actor"].to_i) if leader.equal?(peer) && guest? && @keeps
    when "gain"
      gain(peer, message["item"].to_s) if leader.equal?(peer) && guest?
    end
  rescue => e
    log("taking #{message['story']} failed: #{e.class}: #{e.message}")
  end

  # Sends a message about the story to one member or to the whole party.
  #
  # @param seat [Integer] The member's seat, -1 for everyone, who ignore it outside the party.
  # @param kind [String] "ask", "full", "delta", "keys", "hold", "learn", "recruit", "depart" or "gain".
  # @param fields [Hash] The message's other fields.
  # @return [Boolean] Whether it went out.
  def self.tell(seat, kind, fields)
    MGQ_MpCoop.tell(seat, "story", kind, fields)
  end

  # Starts playing the leader's story, keeping the player's own aside the first time.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param story [Array] The leader's switches, variables and self switches.
  # @param held [Hash] The story's skills, companions and items the leader holds, see holdings.
  def self.borrow(leader, story, held)
    first = !guest?
    if first
      @own = deep_copy(raw_state)
      @same = same_story?(@own, story)
      @keeps = @same || behind?(@own, story)
      # A member as far along got what the leader holds on their own way, or can still get it.
      @baseline = @same ? held : nil
      # The side the member chose before the Great Decision, whose rewards they get.
      @own_side = side_of(@own[0])
      @granted_groups = []
      @recorded = [{}, {}, {}]
      @departed = []
      @lent = {}
    end
    set_raw(*mix(story, raw_state))
    @borrowed = deep_copy(raw_state)
    @waiting = false
    return unless first

    # Events the leader's story got past before a member as far along joined are theirs to play.
    @baseline_groups = @same ? (0...groups.size).select { |index| marked?(groups[index]) } : nil

    MGQ_MpOverworldSync.notice("You follow #{leader.state['name']}'s story while in the party." + follow_text)
  end

  # Says what the player keeps of the leader's story, for the notice when they start following it.
  #
  # @return [String] The sentence, with a space before it; empty when they keep nothing.
  def self.follow_text
    return " You are as far along, so you keep what you play together." if @same
    return " You catch up with it and keep what you play together." if @keeps

    ""
  end

  # Reports whether two stories are as far along: the same main story progress and route progress.
  #
  # @param own [Array] The player's switches, variables and self switches.
  # @param other [Array] The leader's.
  # @return [Boolean] Whether they are.
  def self.same_story?(own, other)
    STORY_MARKERS.all? { |id| own[1][id].to_i == other[1][id].to_i }
  end

  # Reports whether the player's story is behind the leader's or as far along: no progress beyond
  # the leader's, in the main story nor in a route.
  #
  # @param own [Array] The player's switches, variables and self switches.
  # @param other [Array] The leader's.
  # @return [Boolean] Whether it is.
  def self.behind?(own, other)
    STORY_MARKERS.all? { |id| own[1][id].to_i <= other[1][id].to_i }
  end

  # Takes what of the leader's story changed, and keeps it for the player's own story when they
  # are as far along as the leader.
  #
  # @param changes [Array] The changed switches, variables and self switches, each by key.
  def self.apply(changes)
    story = raw_state
    # The variables come first, since a route's progress decides whether the side switches that
    # come with it are the player's own.
    changes[1].each do |id, value|
      next if personal_variable?(id)

      story[1][id] = @borrowed[1][id] = value
      @recorded[1][id] = value if @same
    end
    changes[0].each do |id, value|
      next if personal_switch?(id, story[1])

      story[0][id] = @borrowed[0][id] = value
      @recorded[0][id] = value if @same
    end
    changes[2].each do |key, value|
      next if personal_self_switch?(key)

      story[2][key] = @borrowed[2][key] = value
      @recorded[2][key] = value if @same
    end
    set_raw(*story)
    follow_route_side
  end

  # Takes the side of the leader's route once the story played is past the Great Decision, which
  # sets the side anew; the leader's game sends no side switch that did not change in it.
  def self.follow_route_side
    side = @leader_held && @leader_held[:side]
    return if side.nil? || sides_differ?

    data = $game_switches.mgq_mp_data
    return if data[ALICE_CHOSEN] == (side == :alice) && data[ILIAS_CHOSEN] == (side == :ilias)

    data[ALICE_CHOSEN] = side == :alice
    data[ILIAS_CHOSEN] = side == :ilias
    $game_map.need_refresh = true if $game_map
  end

  # The player's own story, with what they played along when they were as far as the leader: the
  # leader's changes, then what changed in the player's own game, such as their own battles. A
  # player who was behind the leader keeps the leader's story instead.
  #
  # @return [Array] The switches, variables and self switches.
  def self.own_story
    return @own unless @keeps
    return caught_up_story unless @same

    story = @own.map(&:dup)
    played = raw_state
    3.times do |kind|
      @recorded[kind].each { |key, value| story[kind][key] = value }
      changed_keys(@borrowed[kind], played[kind]).each { |key| story[kind][key] = played[kind][key] }
    end
    story
  end

  # The leader's story as the player plays it, which a player who was behind keeps, with their own
  # values wherever the leader's story never set one, such as a side quest only the player played,
  # and their own chests on every map, so one only the leader looted stays shut for them.
  #
  # @return [Array] The switches, variables and self switches.
  def self.caught_up_story
    story = raw_state
    2.times do |kind|
      @own[kind].each_with_index { |value, id| story[kind][id] = value if story[kind][id].nil? && !value.nil? }
    end
    @own[2].each { |key, value| story[2][key] = value unless story[2].key?(key) }
    all_chest_keys.each { |key| @own[2].key?(key) ? story[2][key] = @own[2][key] : story[2].delete(key) }
    story
  end

  # Lists the self switches of every chest in the game, see MGQ_MpCoopStoryRewards::CHESTS.
  #
  # @return [Array<Array>] Their keys: map, event and letter.
  def self.all_chest_keys
    defined?(MGQ_MpCoopStoryRewards) ? MGQ_MpCoopStoryRewards::CHESTS : []
  end

  # Lists the switches, variables or self switches that differ between two stories.
  #
  # @param before [Array, Hash] Those of one story.
  # @param after [Array, Hash] Those of the other.
  # @return [Array] The keys that differ.
  def self.changed_keys(before, after)
    keys = before.is_a?(Hash) ? before.keys | after.keys : (0...[before.size, after.size].max).to_a
    keys.reject { |key| before[key] == after[key] }
  end

  # As leader, tells the party about a companion who joined in the story, so members who keep the
  # story get them too. A companion recruited outside the story, as after a battle, stays the leader's.
  # Called when a companion joins.
  #
  # @param actor_id [Integer] The companion.
  def self.joined(actor_id)
    tell(-1, "recruit", "actor" => actor_id) if telling_party?
  rescue => e
    log("telling a companion failed: #{e.class}: #{e.message}")
  end

  # As leader, tells the party about a companion who left in the story. Called when a companion
  # leaves.
  #
  # @param actor_id [Integer] The companion.
  def self.left(actor_id)
    tell(-1, "depart", "actor" => actor_id) if telling_party?
  rescue => e
    log("telling a departure failed: #{e.class}: #{e.message}")
  end

  # As leader, tells the party about items or gold the story gave or took. Called by
  # coop_events.rbx, which leaves out moves to and from the item storage and enchanted copies.
  #
  # @param kind [String] "i", "w", "a", or "g" for gold.
  # @param id [Integer] The item, 0 for gold.
  # @param amount [Integer] How many, below zero for a loss.
  def self.gave(kind, id, amount)
    tell(-1, "gain", "item" => "#{kind}#{id}x#{amount}") if amount != 0 && telling_party?
  rescue => e
    log("telling an item failed: #{e.class}: #{e.message}")
  end

  # Reports whether the player leads a party through its story now, outside a battle, whose rewards
  # each player gets in their own game.
  #
  # @return [Boolean] Whether they do.
  def self.telling_party?
    return false unless leader == :me && !MGQ_MpCoop::Party.members.empty?
    return false if $game_party && $game_party.in_battle

    MGQ_MpCoopEvents.telling?
  end

  # Takes a companion who joined the leader in the story the player plays along, back into the
  # party when the story only sent them away for a while; never one only the leader's side gets.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param actor_id [Integer] The companion.
  def self.recruit(leader, actor_id)
    return if actor_id <= 0 || sided?(:actors, actor_id)

    name = @departed.delete(actor_id) ? bring(actor_id) : join(actor_id)
    MGQ_MpOverworldSync.notice("#{name} joined you too.") if name
  end

  # Lets a companion go who left the leader in the story the player plays along.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param actor_id [Integer] The companion.
  def self.depart(leader, actor_id)
    return unless actor_id > 0 && $data_actors[actor_id] && in_roster?(actor_id)

    @departed << actor_id if $game_party.exist_party_actor_id?(actor_id)
    $game_party.remove_actor(actor_id)
    MGQ_MpOverworldSync.notice("#{$data_actors[actor_id].name} left you too.")
  end

  # Gives or takes items or gold as the leader's story did, to a member who keeps the story. One
  # ahead of the leader borrows the leader's key items instead, see lend_keys.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param text [String] The item as written: kind, id, "x" and amount, below zero for a loss.
  def self.gain(leader, text)
    return unless text =~ /\A([iwag])(\d+)x(-?\d+)\z/

    kind, id, amount = Regexp.last_match(1), Regexp.last_match(2).to_i, Regexp.last_match(3).to_i
    return unless @keeps

    if kind == "g"
      MGQ_MpCoopEvents.granting { $game_party.gain_gold(amount) }
      name = "#{amount.abs} #{Vocab.currency_unit}"
    else
      item = MGQ_MpGame.item(kind, id)
      return unless item

      MGQ_MpCoopEvents.granting { $game_party.gain_item(item, amount) }
      name = amount.abs > 1 ? "#{item.name} x#{amount.abs}" : item.name
    end
    MGQ_MpOverworldSync.notice(amount > 0 ? "#{leader.state['name']}'s story gave you #{name} too." : "#{leader.state['name']}'s story took #{name} from you too.")
  end

  # Lends a member ahead of the leader the key items the leader holds and the member does not, such
  # as the one that opens a door, so they can play the story along; one the leader no longer holds
  # goes back. Every other item and gold stays the leader's. A member who keeps the story gets the
  # key items to keep instead, see catch_up.
  #
  # The leader tells what they hold with their story and whenever it changes, so a member who
  # loaded a save, came back after a crash or a duel borrows the keys again, which no save holds.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param keys [Hash{Integer => Integer}] How many of each key item the leader holds.
  def self.lend_keys(leader, keys)
    return if @keeps || !guest?

    lent_now = []
    returned = []
    (keys.keys | @lent.keys).each do |id|
      item = $data_items[id]
      next unless item && item.key_item?

      lent = @lent[id].to_i
      own = $game_party.item_number(item) - lent
      wanted = [keys[id].to_i - own, 0].max
      next if wanted == lent

      MGQ_MpCoopEvents.granting { $game_party.gain_item(item, wanted - lent) }
      wanted > 0 ? @lent[id] = wanted : @lent.delete(id)
      (wanted > lent ? lent_now : returned) << item.name
    end
    name = leader.state["name"]
    MGQ_MpOverworldSync.notice("#{name} lent you #{key_list(lent_now)} for the story.") unless lent_now.empty?
    MGQ_MpOverworldSync.notice("#{key_list(returned)} went back to #{name}.") unless returned.empty?
  end

  # Names things for a notice: one or two by name, more by their count.
  #
  # @param names [Array<String>] The names.
  # @param noun [String] What they are, for more than two.
  # @return [String] The names, such as "Basement Key" or "5 key items".
  def self.key_list(names, noun = "key items")
    names.size > 2 ? "#{names.size} #{noun}" : names.join(" and ")
  end

  # As leader, counts the key items the player holds, which members not as far along borrow.
  #
  # @return [Hash{Integer => Integer}] How many of each, by the item's id.
  def self.key_items
    keys = {}
    $game_party.items.each { |item| keys[item.id] = $game_party.item_number(item) if item.is_a?(RPG::Item) && item.key_item? }
    keys
  end

  # Writes key items for a message.
  #
  # @param keys [Hash{Integer => Integer}] How many of each, by the item's id.
  # @return [String] Each item's id and count, "id:count", comma separated.
  def self.write_keys(keys)
    keys.map { |id, count| "#{id}:#{count}" }.join(",")
  end

  # Reads key items a leader wrote.
  #
  # @param text [String, nil] The items, see write_keys.
  # @return [Hash{Integer => Integer}] How many of each, by the item's id; none for a count below one.
  def self.read_keys(text)
    keys = {}
    entries(text).each { |id, count| keys[id.to_i] = count.to_i if id.to_i > 0 && count.to_i > 0 }
    keys
  end

  # As leader, gathers what of the story's rewards the player holds, which a member who keeps the
  # story catches up with: the story skills Luka knows, the story companions in the party or waiting
  # at the castle, the story items and key items, and the side the player chose.
  #
  # @param keys [Hash{Integer => Integer}] The key items held, see key_items.
  # @return [Hash] :skills and :actors as ids, :items as counts by letter and id, :side.
  def self.holdings(keys = key_items)
    held = { :skills => [], :actors => [], :items => {}, :side => own_side }
    return held unless defined?(MGQ_MpCoopStoryRewards)

    hero = $game_actors[HERO]
    learned = MGQ_MpGame.get(hero, :skills)
    held[:skills] = learned ? MGQ_MpCoopStoryRewards::SKILLS & learned : MGQ_MpCoopStoryRewards::SKILLS.select { |id| hero.skill_learn?($data_skills[id]) }
    held[:actors] = MGQ_MpCoopStoryRewards::ACTORS & roster_ids
    worn = worn_counts
    MGQ_MpCoopStoryRewards::ITEMS.each_key do |key|
      item = item_of(key)
      count = item ? story_count(item, worn) : 0
      held[:items][key] = count if count > 0
    end
    keys.each { |id, count| held[:items]["i#{id}"] = count }
    held
  end

  # Writes what of the story's rewards the leader holds for a message.
  #
  # @param held [Hash] What they hold, see holdings.
  # @return [Hash] The skills under "sk", the companions under "ac", the items under "it" and the
  #   side under "side": "a" for Alice's, "i" for Ilias's, empty for none.
  def self.write_holdings(held)
    {
      "sk" => held[:skills].join(","), "ac" => held[:actors].join(","),
      "it" => held[:items].map { |key, count| "#{key}:#{count}" }.join(","),
      "side" => { :alice => "a", :ilias => "i" }[held[:side]].to_s,
    }
  end

  # Reads what of the story's rewards a leader holds.
  #
  # @param message [Hash] The message.
  # @return [Hash] What they hold, see holdings.
  def self.read_holdings(message)
    items = {}
    entries(message["it"]).each { |key, count| items[key] = count.to_i if key =~ /\A[iwa]\d+\z/ && count.to_i > 0 }
    {
      :skills => message["sk"].to_s.split(",").map(&:to_i).select { |id| id > 0 },
      :actors => message["ac"].to_s.split(",").map(&:to_i).select { |id| id > 0 },
      :items => items, :side => { "a" => :alice, "i" => :ilias }[message["side"].to_s],
    }
  end

  # Finds an item by the letter of its kind and its id, written together.
  #
  # @param key [String] The item, such as "i501".
  # @return [RPG::BaseItem, nil] The item, nil for one the game lacks.
  def self.item_of(key)
    MGQ_MpGame.item(key[0, 1], key[1..-1].to_i)
  end

  # Counts how many of an item the player holds: in the bag, in the item storage and equipped by
  # any of their own companions, those waiting at the castle too.
  #
  # @param item [RPG::BaseItem] The item.
  # @param worn [Hash, nil] How many of each equipment the companions wear, see worn_counts, nil
  #   to count them now.
  # @return [Integer] How many.
  def self.story_count(item, worn = nil)
    count = $game_party.item_number(item)
    count += $game_party.storehouse_item_number(item) if $game_party.respond_to?(:storehouse_item_number)
    return count unless item.is_a?(RPG::EquipItem)

    count + (worn || worn_counts)[[item.class, item.id]].to_i
  end

  # Counts the equipment the player's own companions wear, in one look at the roster.
  #
  # @return [Hash{Array => Integer}] How many of each, by the item's class and id.
  def self.worn_counts
    worn = Hash.new(0)
    roster.each { |actor| actor.equips.each { |equip| worn[[equip.class, equip.id]] += 1 if equip } }
    worn
  end

  # Catches a member who keeps the leader's story up with its rewards. On first following it, a
  # member who was behind gets what the leader holds and they lack: the skills and companions, the
  # story's items and key items. Later the story's own messages bring what it gives, see
  # learn_told and recruit. Each time, the member gets their own side's rewards of the events
  # where the sides differ that the leader's story got past, see due_groups.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param held [Hash] What the leader holds, see holdings.
  # @param first [Boolean] Whether the member just started following the story.
  def self.catch_up(leader, held, first)
    @leader_held = held
    return unless @keeps && guest?

    follow_route_side
    past = first && !@same
    skills = past ? held[:skills].reject { |id| sided?(:skills, id) } : []
    actors = past ? held[:actors].reject { |id| sided?(:actors, id) } : []
    due_groups(held).each do |rewards|
      skills |= rewards[:skills]
      actors |= rewards[:actors]
    end
    learned = skills.map { |id| learn(id) }.compact
    joined = actors.map { |id| join(id) }.compact
    items = past ? fill_items(held[:items]) : []
    name = leader.state["name"]
    MGQ_MpOverworldSync.notice("#{$game_actors[HERO].name} learned #{key_list(learned, 'skills')} to catch up with #{name}'s story.") unless learned.empty?
    MGQ_MpOverworldSync.notice("#{key_list(joined, 'companions')} joined you to catch up with #{name}'s story.") unless joined.empty?
    MGQ_MpOverworldSync.notice("You got #{key_list(items, 'items')} to catch up with #{name}'s story.") unless items.empty?
  end

  # As leader, tells the party about a story skill Luka learned while the story plays, so members
  # who keep the story learn it too. Called when a character learns a skill.
  #
  # @param actor [Game_Actor] The character.
  # @param skill_id [Integer] The skill.
  def self.learned(actor, skill_id)
    return unless defined?(MGQ_MpCoopStoryRewards) && MGQ_MpCoopStoryRewards::SKILLS.include?(skill_id)
    return unless actor.equal?($game_actors[HERO]) && telling_party?

    tell(-1, "learn", "skill" => skill_id)
  rescue => e
    log("telling a skill failed: #{e.class}: #{e.message}")
  end

  # Teaches Luka a story skill he learned in the leader's story the player plays along, unless only
  # one side's events teach it, which come with those events, see due_groups.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param skill_id [Integer] The skill.
  def self.learn_told(leader, skill_id)
    return if sided?(:skills, skill_id)

    name = learn(skill_id)
    MGQ_MpOverworldSync.notice("#{$game_actors[HERO].name} learned #{name} too.") if name
  end

  # Reports whether the leader came to hold a reward after the member joined, which a member as far
  # along gets; one who was behind gets every reward.
  #
  # @param kind [Symbol] :skills or :actors.
  # @param id [Integer] The reward.
  # @return [Boolean] Whether they did.
  def self.new_since_joining?(kind, id)
    @baseline.nil? || !@baseline[kind].include?(id)
  end

  # Teaches Luka a story skill he lacks.
  #
  # @param id [Integer] The skill.
  # @return [String, nil] Its name, nil when he knew it or the game lacks it.
  def self.learn(id)
    skill = $data_skills[id]
    hero = $game_actors[HERO]
    return nil if skill.nil? || hero.skill_learn?(skill)

    hero.learn_skill(id)
    skill.name
  end

  # Brings a story companion the player lacks into the roster, waiting at the castle.
  #
  # @param id [Integer] The companion.
  # @return [String, nil] Their name, nil when they were there or the game lacks them.
  def self.join(id)
    return nil if !$data_actors[id] || in_roster?(id)

    $game_party.add_stand_actor(id)
    $data_actors[id].name
  end

  # Brings a companion the player lacks into the party, or into the roster when it is full or a
  # story's temporary party plays.
  #
  # @param id [Integer] The companion.
  # @return [String, nil] Their name, nil when they were there or the game lacks them.
  def self.bring(id)
    return nil if !$data_actors[id] || in_roster?(id)

    stand = $game_party.party_member_full? || ($game_party.respond_to?(:temp_actors_use?) && $game_party.temp_actors_use?)
    stand ? $game_party.add_stand_actor(id) : $game_party.add_actor(id)
    $data_actors[id].name
  end

  # Gives a member who was behind the story's items and key items the leader holds, as many as the
  # leader holds and the story gives at most, less those the member holds already.
  #
  # @param items [Hash{String => Integer}] How many the leader holds, by letter and id.
  # @return [Array<String>] What was given, as shown.
  def self.fill_items(items)
    items.map do |key, count|
      item = item_of(key)
      next unless item

      most = MGQ_MpCoopStoryRewards::ITEMS[key] if defined?(MGQ_MpCoopStoryRewards)
      most ||= item.is_a?(RPG::Item) && item.key_item? ? count : 0
      missing = [count, most].min - story_count(item)
      next unless missing > 0

      MGQ_MpCoopEvents.granting { $game_party.gain_item(item, missing) }
      missing > 1 ? "#{item.name} x#{missing}" : item.name
    end.compact
  end

  # The side the player plays, as the switches of the story played tell.
  #
  # @return [Symbol, nil] :alice, :ilias, or nil before they chose.
  def self.own_side
    side_of($game_switches.mgq_mp_data)
  end

  # The side some switches tell.
  #
  # @param switches [Array] The switches.
  # @return [Symbol, nil] :alice, :ilias, or nil for none.
  def self.side_of(switches)
    return :alice if switches[ALICE_CHOSEN]
    return :ilias if switches[ILIAS_CHOSEN]

    nil
  end

  # The side whose rewards a member gets in the events where the sides differ: the one they chose
  # before the Great Decision, or past it, for one who never chose, the leader's.
  #
  # @return [Symbol, nil] :alice, :ilias, or nil while the member has none.
  def self.story_side
    return @own_side if @own_side
    return nil if sides_differ?

    @leader_held && @leader_held[:side]
  end

  # Reports whether the sides still get other rewards in a story: before the Great Decision, while
  # no route has progress.
  #
  # @param variables [Array, nil] The story's variables, nil for those of the story played.
  # @return [Boolean] Whether they do.
  def self.sides_differ?(variables = nil)
    variables ||= $game_variables ? $game_variables.mgq_mp_data : []
    ROUTE_MARKERS.all? { |id| variables[id].to_i == 0 }
  end

  # The events where the sides get other rewards, see MGQ_MpCoopStoryRewards::GROUPS.
  #
  # @return [Array<Hash>] The events.
  def self.groups
    defined?(MGQ_MpCoopStoryRewards) ? MGQ_MpCoopStoryRewards::GROUPS : []
  end

  # Reports whether only the events where the sides differ give a reward, which comes with those
  # events alone, see MGQ_MpCoopStoryRewards::SIDED, before the Great Decision and after it alike,
  # so a member holds only their own side's; any other comes as the leader holds it.
  #
  # @param kind [Symbol] :skills or :actors.
  # @param id [Integer] The reward.
  # @return [Boolean] Whether they do.
  def self.sided?(kind, id)
    defined?(MGQ_MpCoopStoryRewards) && MGQ_MpCoopStoryRewards::SIDED[kind].include?(id) ? true : false
  end

  # Finds the rewards of the member's side, see story_side, of the events where the sides differ
  # that the leader's story got past and the member has not had yet. The place where the player
  # chooses a side gives its companion once to a member who never chose, see choose_side.
  #
  # @param held [Hash] What the leader holds.
  # @return [Array<Hash>] The side's :skills and :actors of each such event.
  def self.due_groups(held)
    side = story_side
    return [] unless side

    known = (@granted_groups ||= []) + (@baseline_groups || [])
    due = []
    groups.each_with_index do |group, index|
      next if known.include?(index)
      next if group[:choice] ? @own_side : !played?(group, held)

      @granted_groups << index
      due << group[side]
    end
    due
  end

  # Reports whether the leader's story got past an event where the sides differ: what one of its
  # pages leaves in the story holds, or the leader holds a reward only this event gives their side.
  #
  # @param group [Hash] The event.
  # @param held [Hash] What the leader holds.
  # @return [Boolean] Whether it did.
  def self.played?(group, held)
    marked?(group) || only_from?(group, held)
  end

  # Reports whether what one of an event's pages leaves in the story holds in the story played.
  #
  # @param group [Hash] The event.
  # @return [Boolean] Whether it does.
  def self.marked?(group)
    group[:marks].any? { |marks| marks.all? { |mark| mark_holds?(mark) } }
  end

  # Reports whether one thing an event leaves in the story holds in the story played.
  #
  # @param mark [Array] [:s, switch] on, [:v, variable, at least] or [:ss, map, event, letter] on.
  # @return [Boolean] Whether it does.
  def self.mark_holds?(mark)
    case mark[0]
    when :s then $game_switches.mgq_mp_data[mark[1]] ? true : false
    when :v then $game_variables.mgq_mp_data[mark[1]].to_i >= mark[2]
    when :ss then $game_self_switches.mgq_mp_data[mark[1, 3]] == true
    else false
    end
  end

  # Reports whether the leader holds a reward that only this event gives their side, since they
  # came to hold it after the player joined.
  #
  # @param group [Hash] The event.
  # @param held [Hash] What the leader holds.
  # @return [Boolean] Whether they do.
  def self.only_from?(group, held)
    side = held[:side]
    return false unless side

    [:skills, :actors].any? do |kind|
      group[side][kind].any? do |id|
        sources = groups.select { |each_group| each_group[side][kind].include?(id) }
        held[kind].include?(id) && new_since_joining?(kind, id) && sources.size == 1 && sources[0].equal?(group)
      end
    end
  end

  # Asks a member who has not chosen a side yet whom they take along, once the leader has chosen
  # and the player is free on the map, outside the leader's story scene, before the Great Decision.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The leader.
  def self.ask_side(leader)
    return if @asking || own_side || @leader_held.nil? || @leader_held[:side].nil? || !sides_differ?
    return unless leader.is_a?(MGQ_MpOverworldSync::Peers::Peer) && leader.state["telling"] != "1"
    return unless MGQ_MpOverworldSync.map_free? && !MGQ_MpCoopEvents.mirroring?

    @asking = true
    $game_message.add("#{leader.state['name']} took #{side_name(@leader_held[:side])} along. Whom do you take along on your own journey?")
    $game_message.choices.push(side_name(:alice), side_name(:ilias))
    $game_message.choice_cancel_type = 0
    $game_message.choice_proc = Proc.new { |index| choose_side(index == 0 ? :alice : :ilias) }
  end

  # Names a side by the one the player takes along.
  #
  # @param side [Symbol] :alice or :ilias.
  # @return [String] "Alice" or "Ilias".
  def self.side_name(side)
    side == :alice ? "Alice" : "Ilias"
  end

  # Keeps the side the member chose as their own, brings in the companion the choice brings, as
  # the Iliasville scene does, then catches them up with the side's rewards.
  #
  # @param side [Symbol] :alice or :ilias.
  def self.choose_side(side)
    @asking = false
    SIDE_SWITCHES.each do |id|
      $game_switches[id] = id == (side == :alice ? ALICE_CHOSEN : ILIAS_CHOSEN)
      @own[0][id] = $game_switches[id] if guest?
    end
    @own_side = side
    groups.each_with_index do |group, index|
      next unless group[:choice]

      (@granted_groups ||= []) << index
      group[side][:skills].each { |id| learn(id) }
      group[side][:actors].each { |id| bring(id) }
    end
    MGQ_MpOverworldSync.notice("You took #{side_name(side)} along.")
    lead = leader
    catch_up(lead, @leader_held, false) if lead.is_a?(MGQ_MpOverworldSync::Peers::Peer) && @leader_held
  rescue => e
    log("choosing a side failed: #{e.class}: #{e.message}")
  end

  # Reports whether a message that changes what the member holds has to wait: during a PvP
  # battle, which puts the game back as it was before it, and until the member plays the
  # leader's story again, as after loading a save, so nothing the leader's story gives is lost.
  #
  # @return [Boolean] Whether it has to.
  def self.held_back?
    pvp_running? || !guest? || @waiting ? true : false
  end

  # Reports whether a PvP battle, such as a duel, runs.
  #
  # @return [Boolean] Whether one does.
  def self.pvp_running?
    defined?(MGQ_MpBattlesPvp) && MGQ_MpBattlesPvp::Battle.running? ? true : false
  end

  # Keeps a message that changes what the member holds until they can keep it.
  #
  # @param message [Hash] The message.
  def self.hold_back(message)
    (@held ||= []) << message
    @held.shift while @held.size > MAX_HELD
  end

  # Forgets the messages kept back that the leader's whole story just covered: older holdings,
  # which would replace the newer ones, and for a member who just caught up with what the leader
  # holds, what the story gave meanwhile, which they would get twice. Departures still count.
  #
  # @param caught_up [Boolean] Whether the member just caught up with what the leader holds.
  def self.drop_covered(caught_up)
    covered = caught_up ? %w(hold gain recruit learn) : %w(hold)
    (@held || []).reject! { |message| covered.include?(message["story"]) }
  end

  # Takes the messages kept back, once the member plays the leader's story again outside a PvP
  # battle; forgets them once the party is over.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The leader.
  def self.take_held(leader)
    return if @held.nil? || @held.empty?
    return @held = nil unless leader.is_a?(MGQ_MpOverworldSync::Peers::Peer)
    return if held_back?

    held = @held
    @held = nil
    held.each { |message| take(leader, message) }
  end

  # Takes back the key items the leader's story lent, as the player gets their own story back.
  def self.return_lent
    names = []
    (@lent || {}).each do |id, amount|
      item = $data_items[id]
      next unless item

      MGQ_MpCoopEvents.granting { $game_party.gain_item(item, -[amount, $game_party.item_number(item)].min) }
      names << item.name
    end
    @lent = {}
    MGQ_MpOverworldSync.notice("#{key_list(names)} went back to the party's leader.") unless names.empty?
  end

  # Reads a self switch as it is the player's own, whether or not they play the leader's story.
  #
  # @param key [Array] The self switch: map, event and letter.
  # @return [Boolean] Its value.
  def self.own_self_switch(key)
    (guest? ? @own[2][key] : $game_self_switches.mgq_mp_data[key]) == true
  end

  # Sets a self switch of the player's own, such as a chest's, in their own story and in the one
  # they play.
  #
  # @param key [Array] The self switch: map, event and letter.
  # @param value [Boolean] Its value.
  def self.keep_own_self_switch(key, value)
    @own[2][key] = value if guest?
    $game_self_switches.mgq_mp_data[key] = value
    $game_map.need_refresh = true if $game_map
  end

  # Shows the player's own chests on a map they enter while playing the leader's story. Called
  # after a map is set up.
  def self.map_entered
    return unless guest?

    data = $game_self_switches.mgq_mp_data
    chest_keys.each { |key| data[key] = @own[2][key] }
    $game_map.need_refresh = true
  rescue => e
    log("showing own chests failed: #{e.class}: #{e.message}")
  end

  # Reports whether a self switch is the player's own: a chest's on the map, through
  # coop_events.rbx.
  #
  # @param key [Array] The self switch: map, event and letter.
  # @return [Boolean] Whether it is.
  def self.personal_self_switch?(key)
    $game_map ? MGQ_MpCoopEvents.chest_key?(key) : false
  end

  # Lists the self switches of the chests on the map, through coop_events.rbx.
  #
  # @return [Array<Array>] Their keys.
  def self.chest_keys
    $game_map ? MGQ_MpCoopEvents.chest_keys : []
  end

  # Gives the player their own story back, keeping what of their own changed meanwhile.
  def self.restore
    kept = @keeps
    return_lent
    set_raw(*own_with_values)
    forget
    MGQ_MpOverworldSync.notice(kept ? "You are back in your own story, with what you played together." : "You are back in your own story.")
  end

  # Forgets the story kept aside, as when a save is loaded or a new game starts, which bring their
  # own story. A member then asks the leader again.
  def self.forget
    @own = nil
    @same = false
    @keeps = false
    @baseline = nil
    @baseline_groups = nil
    @granted_groups = nil
    @own_side = nil
    @leader_held = nil
    @asking = false
    @recorded = nil
    @borrowed = nil
    @departed = nil
    @lent = {}
    @leader_id = nil
    @waiting = false
  end

  # The story a save holds: the member's own while they play the leader's.
  #
  # @param contents [Hash] What the game saves.
  # @return [Hash] The same, with the member's own story.
  def self.save_contents(contents)
    return contents unless guest?

    switches, variables, self_switches = own_with_values
    contents[:switches] = with_data(contents[:switches], switches)
    contents[:variables] = with_data(contents[:variables], variables)
    contents[:self_switches] = with_data(contents[:self_switches], self_switches)
    contents[:party] = without_lent(contents[:party]) if contents[:party]
    contents
  end

  # The player's own story with their own values as they are now, see own_story. A player who keeps
  # nothing of the leader's story keeps their own side too, which the leader's after the Great
  # Decision replaced while they played it.
  #
  # @return [Array] The switches, variables and self switches.
  def self.own_with_values
    story = mix(own_story, raw_state)
    SIDE_SWITCHES.each { |id| story[0][id] = @own[0][id] } unless @keeps
    story
  end

  # Copies the party the game saves without the key items the leader's story lent, which the
  # member's own story never had.
  #
  # @param party [Game_Party] The party.
  # @return [Game_Party] The party, a copy when items were lent.
  def self.without_lent(party)
    return party if (@lent || {}).empty?

    copy = Marshal.load(Marshal.dump(party))
    @lent.each { |id, amount| copy.gain_item($data_items[id], -amount) if $data_items[id] }
    copy
  rescue => e
    # The save must still hold the member's own story, which a failure here would cost.
    log("leaving the lent items out of the save failed: #{e.class}: #{e.message}")
    party
  end

  # Reads the story as the game keeps it, past the game's own handling of single switches and variables.
  #
  # @return [Array] Copies of the switches, variables and self switches.
  def self.raw_state
    [$game_switches.mgq_mp_data.dup, $game_variables.mgq_mp_data.dup, $game_self_switches.mgq_mp_data.dup]
  end

  # Replaces the story as the game keeps it, past the game's own handling, which would add or remove
  # companions, and has the map's events look at it again.
  #
  # @param switches [Array] The switches.
  # @param variables [Array] The variables.
  # @param self_switches [Hash] The self switches.
  def self.set_raw(switches, variables, self_switches)
    $game_switches.mgq_mp_data = switches
    $game_variables.mgq_mp_data = variables
    $game_self_switches.mgq_mp_data = self_switches
    $game_map.need_refresh = true if $game_map
  end

  # Joins one story with the player's own values.
  #
  # @param story [Array] The switches, variables and self switches of the story.
  # @param personal [Array] Those of the player, whose own values win.
  # @return [Array] The joined switches, variables and self switches.
  def self.mix(story, personal)
    switches = story[0].dup
    variables = story[1].dup
    [personal[0].size, switches.size].max.times { |id| switches[id] = personal[0][id] if personal_switch?(id, story[1]) }
    [personal[1].size, variables.size].max.times { |id| variables[id] = personal[1][id] if personal_variable?(id) }
    self_switches = story[2].dup
    chest_keys.each { |key| self_switches[key] = personal[2][key] }
    [switches, variables, self_switches]
  end

  # Reports whether a switch is the player's own.
  #
  # @param id [Integer] The switch.
  # @param variables [Array, nil] The variables of the story it belongs to, nil for the one played.
  # @return [Boolean] Whether it is.
  def self.personal_switch?(id, variables = nil)
    return sides_differ?(variables) if SIDE_SWITCHES.include?(id)

    PERSONAL_SWITCHES.any? { |range| range === id } || id.between?(AWAKENING_SWITCHES, AWAKENING_LAST)
  end

  # Reports whether a variable is the player's own.
  #
  # @param id [Integer] The variable.
  # @return [Boolean] Whether it is.
  def self.personal_variable?(id)
    PERSONAL_VARIABLES.any? { |range| range === id } || (id >= AFFECTION_VARIABLES && id < AFFECTION_VARIABLES + companions)
  end

  # Counts the game's companions, one affection variable each.
  #
  # @return [Integer] How many.
  def self.companions
    $data_actors ? $data_actors.size : 1000
  end

  # Lists what changed between two stories, leaving out what is the player's own.
  #
  # @param before [Array] The switches, variables and self switches before.
  # @param after [Array] The same after.
  # @return [Hash] Changed switches, variables and self switches by key, under "s", "v" and "ss".
  def self.delta(before, after)
    switches = changed_keys(before[0], after[0]).reject { |id| personal_switch?(id) }
    variables = changed_keys(before[1], after[1]).reject { |id| personal_variable?(id) }
    self_switches = changed_keys(before[2], after[2])
    {
      "s" => switches.map { |id| "#{id}:#{after[0][id] ? 1 : 0}" }.join(","),
      "v" => variables.map { |id| "#{id}:#{encode_value(after[1][id])}" }.join(","),
      "ss" => self_switches.map { |key| "#{key.join('.')}:#{after[2][key] ? 1 : 0}" }.join(","),
    }
  end

  # Writes a whole story, leaving out what is the player's own. What the story turned off or set to
  # zero is written too, apart from what it never set, which a member who catches up keeps of their
  # own, see caught_up_story. The lists are packed, see pack; one still too large for a message
  # leaves out what the story turned off or set to zero.
  #
  # @param story [Array] The switches, variables and self switches.
  # @return [Hash] The packed lists under "z", see unpack.
  def self.full(story)
    packed = pack(story_lists(story, true))
    return { "z" => packed } if packed.size <= MAX_FULL_BYTES

    log_once(:full_size, "the whole story took #{packed.size} bytes, so it leaves out what the story turned off")
    { "z" => pack(story_lists(story, false)) }
  end

  # Lists a story for a message: the switches on and off under "s" and "sf", the variables set
  # under "v", and the self switches on and off under "ss" and "ssf".
  #
  # @param story [Array] The switches, variables and self switches.
  # @param off [Boolean] Whether what the story turned off or set to zero is listed too.
  # @return [Hash{String => String}] The lists.
  def self.story_lists(story, off)
    switches = (0...story[0].size).reject { |id| story[0][id].nil? || personal_switch?(id) || (!off && !story[0][id]) }
    variables = (0...story[1].size).reject { |id| story[1][id].nil? || personal_variable?(id) || (!off && story[1][id] == 0) }
    self_switches = story[2].keys.reject { |key| story[2][key].nil? || (!off && !story[2][key]) }
    switches_on, switches_off = switches.partition { |id| story[0][id] }
    self_on, self_off = self_switches.partition { |key| story[2][key] }
    {
      "s" => switches_on.join(","), "sf" => switches_off.join(","),
      "v" => variables.map { |id| "#{id}:#{encode_value(story[1][id])}" }.join(","),
      "ss" => self_on.map { |key| key.join(".") }.join(","), "ssf" => self_off.map { |key| key.join(".") }.join(","),
    }
  end

  # Packs lists for a message: each as name=list on its own line, deflated and written in Base64,
  # since a late story's lists of ids would pass what one message carries.
  #
  # @param lists [Hash{String => String}] The lists.
  # @return [String] The packed text.
  def self.pack(lists)
    [Zlib::Deflate.deflate(lists.map { |name, list| "#{name}=#{list}" }.join("\n"))].pack("m0")
  end

  # Unpacks lists a leader packed, see pack.
  #
  # @param text [String] The packed text.
  # @return [Hash{String => String}] The lists.
  def self.unpack(text)
    lists = {}
    Zlib::Inflate.inflate(text.unpack("m0")[0].to_s).split("\n").each do |line|
      name, list = line.split("=", 2)
      lists[name] = list.to_s
    end
    lists
  end

  # Reads a whole story a leader wrote.
  #
  # @param message [Hash] The message.
  # @return [Array] The switches, variables and self switches.
  def self.decode_full(message)
    lists = message["z"] ? unpack(message["z"].to_s) : message
    switches = []
    lists["s"].to_s.split(",").each { |id| switches[id.to_i] = true }
    lists["sf"].to_s.split(",").each { |id| switches[id.to_i] = false }
    variables = []
    entries(lists["v"]).each { |id, value| variables[id.to_i] = decode_value(value) }
    self_switches = {}
    lists["ss"].to_s.split(",").each { |key| self_switches[decode_key(key)] = true }
    lists["ssf"].to_s.split(",").each { |key| self_switches[decode_key(key)] = false }
    [switches, variables, self_switches]
  end

  # Reads what of a story changed.
  #
  # @param message [Hash] The message.
  # @return [Array<Array>] The changed switches, variables and self switches, each by key.
  def self.decode_delta(message)
    [
      entries(message["s"]).map { |id, value| [id.to_i, value == "1"] },
      entries(message["v"]).map { |id, value| [id.to_i, decode_value(value)] },
      entries(message["ss"]).map { |key, value| [decode_key(key), value == "1"] },
    ]
  end

  # Splits a list of key:value entries.
  #
  # @param text [String, nil] The list.
  # @return [Array<Array<String>>] Each entry's key and value.
  def self.entries(text)
    text.to_s.split(",").map { |entry| entry.split(":", 2) }
  end

  # Writes a variable's value; only the kinds a message can carry safely.
  #
  # @param value [Object] The value.
  # @return [String] The value, empty for none or a kind no message carries.
  def self.encode_value(value)
    case value
    when Integer then "n#{value}"
    when Float then "f#{value}"
    when String then "s#{[value].pack('m0')}"
    when true then "T"
    when false then "F"
    else ""
    end
  end

  # Reads a variable's value.
  #
  # @param text [String, nil] The value as written.
  # @return [Object] The value, nil for none.
  def self.decode_value(text)
    text = text.to_s
    case text[0, 1]
    when "n" then text[1..-1].to_i
    when "f" then text[1..-1].to_f
    when "s" then text[1..-1].unpack('m0')[0].force_encoding("UTF-8")
    when "T" then true
    when "F" then false
    end
  end

  # Reads a self switch's key.
  #
  # @param text [String] The key as written: map, event and letter.
  # @return [Array] The key.
  def self.decode_key(text)
    map_id, event_id, letter = text.split(".")
    [map_id.to_i, event_id.to_i, letter]
  end

  # Copies a story, so what the game changes later leaves the copy alone.
  #
  # @param story [Array] The story.
  # @return [Array] The copy.
  def self.deep_copy(story)
    Marshal.load(Marshal.dump(story))
  end

  # Copies one of the game's switches, variables or self switches with other data.
  #
  # @param object [Game_Switches, Game_Variables, Game_SelfSwitches] The object.
  # @param data [Array, Hash] The data.
  # @return [Object] The copy.
  def self.with_data(object, data)
    copy = object.dup
    copy.mgq_mp_data = data
    copy
  end
end

# What this script takes part in of the party's messages, through coop.rbx.

begin
  MGQ_MpCoop.route("story") { |peer, message| MGQ_MpCoopStory.take(peer, message) }
rescue => e
  MGQ_MpCoopStory.log("co-op FAILED: #{e.class}: #{e.message}")
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # After the map's update, the party's story.
  MGQ_MpHooks.after(Game_Map, :update, "coop_story") { MGQ_MpCoopStory.update }
rescue => e
  MGQ_MpCoopStory.log("map hook FAILED: #{e.class}: #{e.message}")
end

begin
  # After a character learns a skill, as leader the party hears of one Luka learns in the story.
  MGQ_MpHooks.after(Game_Actor, :learn_skill, "coop_story") { |skill_id| MGQ_MpCoopStory.learned(self, skill_id) }
rescue => e
  MGQ_MpCoopStory.log("skill hook FAILED: #{e.class}: #{e.message}")
end

# Game hooks of this script alone.
#
# Each wraps a game method: the original runs first unless said otherwise, and the mod's part never
# raises.

if MGQ_MpCoopStory.hookable?
  begin
    [Game_Switches, Game_Variables, Game_SelfSwitches].each do |klass|
      klass.class_eval do
        # The data as the game keeps it, past its handling of single entries.
        #
        # @return [Array, Hash] The data.
        def mgq_mp_data
          @data
        end

        # Replaces the data as the game keeps it, past its handling of single entries.
        #
        # @param data [Array, Hash] The data.
        def mgq_mp_data=(data)
          @data = data
        end
      end
    end
  rescue => e
    MGQ_MpCoopStory.log("data access FAILED: #{e.class}: #{e.message}")
  end

  begin
    class Game_Party
      alias mgq_mp_coop_story_add_stand_actor add_stand_actor
      alias mgq_mp_coop_story_remove_actor remove_actor

      # Takes a companion into the party's roster, then as leader tells the party. In a world, one
      # already there is not taken twice, as when a member who got them catching up plays the
      # event that brings them, which the game's roster would hold twice.
      #
      # @param actor_id [Integer] The companion.
      def add_stand_actor(actor_id)
        return if MGQ_MpCoopStory.held_already?(actor_id)

        mgq_mp_coop_story_add_stand_actor(actor_id)
        MGQ_MpCoopStory.joined(actor_id)
      end

      # Takes a companion out of the party's roster, then as leader tells the party.
      #
      # @param actor_id [Integer] The companion.
      def remove_actor(actor_id)
        mgq_mp_coop_story_remove_actor(actor_id)
        MGQ_MpCoopStory.left(actor_id)
      end
    end
  rescue => e
    MGQ_MpCoopStory.log("companion hook FAILED: #{e.class}: #{e.message}")
  end

  begin
    class Game_Map
      alias mgq_mp_coop_story_setup setup

      # Sets up a map, then shows the player's own chests on it.
      #
      # @param map_id [Integer] The map.
      def setup(map_id)
        mgq_mp_coop_story_setup(map_id)
        MGQ_MpCoopStory.map_entered
      end
    end
  rescue => e
    MGQ_MpCoopStory.log("map setup hook FAILED: #{e.class}: #{e.message}")
  end

  begin
    class << DataManager
      alias mgq_mp_coop_story_make_save_contents make_save_contents
      alias mgq_mp_coop_story_extract_save_contents extract_save_contents
      alias mgq_mp_coop_story_create_game_objects create_game_objects

      # Gathers what the game saves, with a member's own story in place of the leader's.
      #
      # @return [Hash] What the game saves.
      def make_save_contents
        contents = mgq_mp_coop_story_make_save_contents
        begin
          MGQ_MpCoopStory.save_contents(contents)
        rescue => e
          MGQ_MpCoopStory.log("save guard failed: #{e.class}: #{e.message}")
          contents
        end
      end

      # Takes a loaded save, which brings its own story.
      #
      # @param contents [Hash] The save's contents.
      def extract_save_contents(contents)
        mgq_mp_coop_story_extract_save_contents(contents)
        MGQ_MpCoopStory.forget
      end

      # Makes the game's objects anew, as for a new game, which brings its own story.
      def create_game_objects
        mgq_mp_coop_story_create_game_objects
        MGQ_MpCoopStory.forget
      end
    end
  rescue => e
    MGQ_MpCoopStory.log("save hooks FAILED: #{e.class}: #{e.message}")
  end
end
