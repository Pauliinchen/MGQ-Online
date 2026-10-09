#----------------------------------------------------------------
#  coop_story.rbx
#
#  Changelog:
#      Paulinchen  2026-10-08: Kept the leader's story to Classic worlds: in a Raid World no member borrows a leader's story and no leader tells one
#                            - Kept the side each player's own in a Raid World, after the Great Decision too
#                            - Let a join of stories keep the chests of a list the caller gives, every chest of the game for a Raid World's story
#                            - Saved a Raid World's story as it is, which world_story.rbx lays over the player's own
#      Paulinchen  2026-10-07: Kept the variables the game sets for each area and battle, such as the rarity of enchanted drops, each player's own, since the leader's ended a member's game at a drop
#                            - Dropped the switches, variables and key items of another game's story beyond this game's own, logged once per kind
#                            - Registered the companion, map and save hooks through core_hooks.rbx instead of wraps of its own
#                            - Named players, entries of the game's data and a message's bytes through overworld_sync.rbx, core_log.rbx and coop.rbx instead of copies of their helpers
#                            - Kept the outcomes of the story's choices the member made their own, left the choices' companions out of the catch-up, and followed the leader whose offer to sync the story the member accepted
#                            - Let a member play the leader's story only while synced with the leader, close in the main story before the Great Decision or on the same route after it, told by each player's state, and their own story otherwise
#                            - Logged how each member plays the leader's story and why, every message, what the catch-up gives and skips and why, sides, held messages, lent key items, chests and restores
#      Paulinchen  2026-10-06: Read the game's switches, variables and self switches through MGQ_MpGame instead of opening their classes
#                            - Told members nothing a shop or a menu in the leader's story changes, only what the story's own commands change
#                            - Gave members the companions the Great Decision brings, waiting while the sides still differ
#                            - Told the party a companion who joins in the story though the leader has them already, since the game's roster never holds one twice
#                            - Counted Luka's story abilities, and companions by their main persona
#                            - Found an event played by a reward only it gives either side, as the side the leader plays changes at the Great Decision
#                            - Kept what waits for the member for the leader who sent it
#                            - Kept a member's own values in the gaps of a story too large to send whole no more
#                            - Asked coop_events.rbx whether a PvP battle runs
#                            - Let members behind the leader keep the story they play together too, catching up with the story's skills, companions and items the leader holds, and keeping their own side quests
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
# members synced with the leader, close to the leader in the story (see sync_state), borrow the
# leader's story, the switches, variables and self switches the game's events
# read, and get their own back when they leave or the leader goes. What is the player's own, their
# party, their side, their companions' awakening and their affection, stays theirs throughout, and
# every save a member makes holds their own story. A member as far along as the leader keeps what
# they play together: the story's changes, its items, gold and companions, and what changed in their
# own game. A member behind the leader keeps the leader's story and catches up with the skills,
# companions and items the story gave the leader, those of their own side where the sides differ.
# A member not synced plays their own story throughout, while still sharing the party.
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

  # Variables that are the player's own: the last choice's answer (9), which an event of their own
  # reads, where the Pocket Castle's way out returns them (21-23, the map, x and y where they used
  # the castle's item), the enemies' experience, gold and MP corrections (46-48) and the rarity of
  # enchanted drops (150), which the events of each area set for the battles there, the places
  # their party has beyond eight (56), since the game cuts a party down to its places, the map a
  # transfer goes on to (57), where a game over returns them (1002), the counts of their enchanted
  # weapons and armors (200-201) and monsters' friendliness (2000-2999).
  PERSONAL_VARIABLES = [9, 21..23, 46..48, 56, 57, 150, 200..201, 1002, 2000...3000]

  # First variable that holds a companion's affection, one per companion.
  AFFECTION_VARIABLES = 3000

  # Variables that tell how far along a story is: the main story (1001) and the three routes'
  # progress (1141-1143).
  STORY_MARKERS = [1001, 1141, 1142, 1143]

  # Variables of the routes after the Great Decision, where the sides no longer differ in rewards.
  ROUTE_MARKERS = [1141, 1142, 1143]

  # The main story's progress the Great Decision sets, which no later event raises.
  GREAT_DECISION = 40

  # How far apart in the main story two players may be before the Great Decision to play one story.
  SYNC_STEPS = 2

  # How far apart on their route two players may be after the Great Decision to play one story.
  ROUTE_SYNC_STEPS = 5

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

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "co-op story"

  # Reports whether the player plays the leader's story now.
  #
  # @return [Boolean] Whether they do.
  def self.guest?
    !@own.nil?
  end

  # Finds the leader of the player's party, through coop.rbx, whose story the party plays in a
  # Classic world. A Raid World's story is the world's, so its parties have no story leader.
  #
  # @return [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The leader, :me for the player, nil
  #   outside a party and in a Raid World.
  def self.leader
    return nil unless MGQ_MpOverworldSync.in_world?
    return nil if MGQ_MpCoop::Scope.raid?

    MGQ_MpCoop::Party.leader
  end

  # Follows the party for one frame: the leader tells what changed, a member borrows the leader's
  # story, and a player who left the party gets their own back. Called after the map's update.
  def self.update
    leader = self.leader
    if guest? && !leader.is_a?(MGQ_MpOverworldSync::Peers::Peer)
      log(leader == :me ? "the player leads the party now, so they get their own story back" : "no longer in a party with a leader, so the player gets their own story back")
      restore
    end
    check_sync(leader)
    take_held(leader)
    if leader == :me
      lead
      note_followers
    else
      @sent = nil
      @sent_held = nil
      @followers = nil
      follow(leader) if leader && @synced
      ask_side(leader) if guest?
    end
  rescue => e
    log_once(:update, "update failed: #{e.class}: #{e.message}")
  end

  # Reads how far a story is: the main story's progress and the three routes', see STORY_MARKERS.
  #
  # @param variables [Array] The story's variables.
  # @return [Array<Integer>] The values.
  def self.markers_of(variables)
    STORY_MARKERS.map { |id| variables[id].to_i }
  end

  # How far the player's own story is: the one they play, but their own while they borrow the story
  # of a leader they are ahead of, which they never keep.
  #
  # @return [Array<Integer>] The values, see markers_of.
  def self.own_markers
    markers_of(guest? && !@keeps ? @own[1] : data_of($game_variables))
  end

  # Reads how far another player's story is, as their state tells it.
  #
  # @param text [String, nil] The values, comma separated, see state_fields.
  # @return [Array<Integer>, nil] The values, nil when their game tells none.
  def self.read_markers(text)
    values = text.to_s.split(",")
    values.size == STORY_MARKERS.size ? values.map(&:to_i) : nil
  end

  # Finds the route a story plays past the Great Decision: the first route whose progress is above
  # zero, the Chaos route's last, since the Great Decision itself starts it.
  #
  # @param markers [Array<Integer>] The story's values, see markers_of.
  # @return [Integer, nil] The route's place among ROUTE_MARKERS, nil before any.
  def self.route_of(markers)
    markers[1..-1].index { |value| value > 0 }
  end

  # Decides whether two players play one story, the same for both of them: before the Great
  # Decision, when both are at most SYNC_STEPS apart in the main story; past it, when both play the
  # same route at most ROUTE_SYNC_STEPS apart.
  #
  # @param own [Array<Integer>] The one player's values, see markers_of.
  # @param other [Array<Integer>] The other's.
  # @return [Symbol] :synced, or why not: :apart (too far apart), :decision (one is past the Great
  #   Decision, the other before it) or :route (different routes).
  def self.sync_state(own, other)
    past = own[0] >= GREAT_DECISION
    return :decision unless past == (other[0] >= GREAT_DECISION)
    return (own[0] - other[0]).abs <= SYNC_STEPS ? :synced : :apart unless past

    route = route_of(own)
    return :route unless route == route_of(other)
    return :synced if route.nil?

    (own[route + 1] - other[route + 1]).abs <= ROUTE_SYNC_STEPS ? :synced : :apart
  end

  # Reports whether two players play one story, see sync_state.
  #
  # @param own [Array<Integer>] The one player's values, see markers_of.
  # @param other [Array<Integer>] The other's.
  # @return [Boolean] Whether they do.
  def self.synced?(own, other)
    sync_state(own, other) == :synced
  end

  # Says for the log how far a story is, see markers_of.
  #
  # @param markers [Array<Integer>, nil] The values.
  # @return [String] Such as "1001=12, routes 0/0/0".
  def self.markers_text(markers)
    markers ? "1001=#{markers[0]}, routes #{markers[1..-1].join('/')}" : "unknown progress"
  end

  # Tells a player why they and another play their own stories.
  #
  # @param state [Symbol] Why, see sync_state.
  # @param name [String] The other player's name.
  # @return [String] The notice.
  def self.apart_text(state, name)
    case state
    when :decision then "You and #{name} are on different sides of the Great Decision; each of you plays your own story."
    when :route then "You and #{name} are on different routes; each of you plays your own story."
    else "You and #{name} are too far apart in the story; each of you plays your own."
    end
  end

  # As member, decides whether the player plays the leader's story, from how far both stories are,
  # again whenever either changes: following it starts with the leader's whole story, and stops
  # with the player's own story back. A member who keeps the leader's story plays it as far as the
  # leader, so it stays synced until the party or the leader changes.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The party's leader.
  def self.check_sync(leader)
    unless leader.is_a?(MGQ_MpOverworldSync::Peers::Peer)
      log("no longer synced with a leader: the player #{leader == :me ? 'leads the party' : 'is in no party with a leader'}") if @synced
      @synced = false
      @sync_with = nil
      @sync_state = nil
      return
    end

    id = leader.state["id"].to_s
    theirs = read_markers(leader.state["sm"])
    own = own_markers
    state = if guest? && @keeps && @synced && @sync_with == id then :synced
            elsif defined?(MGQ_MpCoopChoices) && MGQ_MpCoopChoices.offer_with?(id) then :synced
            elsif theirs then sync_state(own, theirs)
            else :unknown
            end
    return if state == @sync_state && id == @sync_with

    was = @synced && @sync_with == id
    @sync_state = state
    @sync_with = id
    @synced = state == :synced
    log("story sync with #{MGQ_MpOverworldSync.who(leader)}: #{sync_reason(state)}; own #{markers_text(own)}, leader #{markers_text(theirs)}")
    return if @synced

    stop_following(leader, was)
    MGQ_MpOverworldSync.notice(apart_text(state, leader.state["name"])) unless state == :unknown
  end

  # Says for the log what a decision about playing one story means.
  #
  # @param state [Symbol] The decision, see sync_state, or :unknown.
  # @return [String] Its meaning.
  def self.sync_reason(state)
    case state
    when :synced then "synced, the player plays the leader's story"
    when :apart then "not synced, too far apart in the story, each plays their own"
    when :decision then "not synced, one is past the Great Decision and the other before it, each plays their own"
    when :route then "not synced, on different routes, each plays their own"
    else "not synced yet, the leader's game tells no story progress"
    end
  end

  # Stops playing the leader's story, as the player and the leader are no longer synced: the player
  # gets their own story back and forgets what waited from the leader's.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param was [Boolean] Whether the player was synced with them until now.
  def self.stop_following(leader, was)
    log("stopped following #{MGQ_MpOverworldSync.who(leader)}'s story") if was || guest? || @waiting
    restore if guest?
    @leader_id = nil
    @waiting = false
    dropped = (@held || []).size
    @held = nil
    log("forgot #{dropped} waiting messages of the leader's story") if dropped > 0
  end

  # Reports whether the player follows their leader's story now, see check_sync.
  #
  # @return [Boolean] Whether they do.
  def self.follows_leader?
    return false if MGQ_MpCoop::Scope.raid?

    lead = MGQ_MpCoop.party_leader
    @synced && lead.is_a?(MGQ_MpOverworldSync::Peers::Peer) && lead.state["id"].to_s == @sync_with ? true : false
  end

  # As leader, lists the members who follow the player's story, as their state tells it.
  #
  # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The members.
  def self.synced_members
    return [] unless MGQ_MpCoop.party_leader == :me && !MGQ_MpCoop::Scope.raid?

    me = MGQ_MpOverworldSync::Me.id.to_s
    MGQ_MpCoop::Party.members.select { |peer| peer.state["ssync"].to_s == me }
  end

  # Reports whether the player leads a party with members who follow the player's story.
  #
  # @return [Boolean] Whether they do.
  def self.leading_synced?
    !synced_members.empty?
  end

  # The fields the party's story adds to the state the player's game tells the others: how far
  # the player's own story is, and the leader whose story they follow.
  #
  # @return [Hash] "sm": the values of markers_of, comma separated; "ssync": the leader's id, empty
  #   for none.
  def self.state_fields
    return {} unless $game_variables

    { "sm" => own_markers.join(","), "ssync" => follows_leader? ? @sync_with.to_s : "" }
  rescue => e
    log_once(:state_fields, "telling the story's progress failed: #{e.class}: #{e.message}")
    {}
  end

  # As leader, tells the player which members start or stop following their story, and why.
  def self.note_followers
    me = MGQ_MpOverworldSync::Me.id.to_s
    own = markers_of(data_of($game_variables))
    now = {}
    MGQ_MpCoop::Party.members.each do |peer|
      id = peer.state["id"].to_s
      synced = peer.state["ssync"].to_s == me
      now[id] = synced
      next if (@followers ||= {})[id] == synced

      theirs = read_markers(peer.state["sm"])
      state = synced ? :synced : (theirs ? sync_state(own, theirs) : :unknown)
      # A member's state may tell its decision a moment after its progress.
      next if !synced && [:synced, :unknown].include?(state)

      @followers[id] = synced
      log("#{MGQ_MpOverworldSync.who(peer)} #{synced ? 'follows' : 'does not follow'} the player's story (#{state}); own #{markers_text(own)}, theirs #{markers_text(theirs)}")
      MGQ_MpOverworldSync.notice(synced ? "#{peer.state['name']} follows your story while in the party." : apart_text(state, peer.state["name"]))
    end
    @followers.keep_if { |id, _| now.key?(id) } if @followers
  end

  # As leader, tells the members what of the story changed since the last time.
  def self.lead
    if synced_members.empty?
      @sent = nil
      @sent_keys = nil
      @sent_held = nil
      return
    end

    @frames += 1
    return if @frames < SEND_FRAMES

    @frames = 0
    now = raw_state
    changes = @sent ? delta(@sent, now) : nil
    if changes && !changes.values.all?(&:empty?)
      log("the story changed: #{changes.map { |key, list| "#{key} #{list.split(',').size}" }.join(', ')} (#{changes.values.join(',')[0, 200]}), now #{progress_text(now[1])}")
    end
    @sent = now if changes.nil? || changes.values.all?(&:empty?) || tell(-1, "delta", changes)
    keys = key_items
    if keys != @sent_keys
      log("the leader's key items changed: #{keys.map { |id, count| "#{item_label("i#{id}")} x#{count}" }.join(', ')}")
      @sent_keys = keys if tell(-1, "keys", "k" => write_keys(keys))
    end
    held = write_holdings(holdings(keys))
    if held != @sent_held
      log("the leader's story rewards changed: skills #{held['sk']}; companions #{held['ac']}; items #{held['it']}; side #{held['side']}")
      @sent_held = held if tell(-1, "hold", held)
    end
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

  # Reports whether a companion is in the player's own roster, in any of their personas, see
  # roster_ids.
  #
  # @param id [Integer] The companion.
  # @return [Boolean] Whether they are.
  def self.in_roster?(id)
    roster_ids.include?(main_id(id))
  end

  # Finds the companion a persona belongs to, by whose id the game's roster keeps every persona.
  #
  # @param id [Integer] The companion or one of their personas.
  # @return [Integer] The companion's main persona.
  def self.main_id(id)
    main = $game_actors.respond_to?(:original_id) ? $game_actors.original_id(id) : nil
    main || id
  end

  # As member, asks the leader for their story until it came, again whenever the leader changes.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer] The leader.
  def self.follow(leader)
    id = leader.state["id"].to_s
    if id != @leader_id
      log("the party's leader is #{MGQ_MpOverworldSync.who(leader)} (id #{id[0, 12]}), #{@leader_id ? "was #{@leader_id[0, 12]}" : 'none before'}; asking for their story")
      # A new leader has another story: the member first gets their own back, with what they
      # played along.
      restore if guest?
      @leader_id = id
      @waiting = true
      @ask_frames = ASK_FRAMES
      @asks = 0
    end
    return unless @waiting

    @ask_frames += 1
    return if @ask_frames < ASK_FRAMES

    @ask_frames = 0
    @asks = @asks.to_i + 1
    log("asking #{MGQ_MpOverworldSync.who(leader)} for their whole story, try #{@asks}")
    tell(leader.seat, "ask", {})
  end

  # Takes a message about the story. Called by coop.rbx.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it.
  # @param message [Hash] The message's fields.
  def self.take(peer, message)
    kind = message["story"]
    log("got #{kind} from #{MGQ_MpOverworldSync.who(peer)} (#{MGQ_MpCoop.bytes_of(message)} bytes)#{message_details(kind, message)}")
    if kind != "ask" && leader.equal?(peer) && !follows_leader?
      return log("ignored #{kind} from #{MGQ_MpOverworldSync.who(peer)}: not synced with the leader, the player plays their own story")
    end
    return hold_back(peer, message) if HOLDINGS.include?(kind) && leader.equal?(peer) && held_back?

    reason = ignore_reason(kind, peer)
    return log("ignored #{kind} from #{MGQ_MpOverworldSync.who(peer)}: #{reason}") if reason

    case kind
    when "ask"
      keys = key_items
      held = holdings(keys)
      log("sending #{MGQ_MpOverworldSync.who(peer)} the whole story at #{progress_text(data_of($game_variables))}, with #{holdings_text(held)}")
      log_roster_outside_rewards
      tell(peer.seat, "full", full(raw_state).merge("k" => write_keys(keys)).merge(write_holdings(held)))
    when "full"
      first = !guest?
      @partial = message["part"].to_s == "1"
      held = read_holdings(message)
      borrow(peer, decode_full(message), held)
      lend_keys(peer, read_keys(message["k"]))
      catch_up(peer, held, first)
      drop_covered(first && @keeps && !@same)
      choices_borrowed(peer, first)
    when "delta" then apply(decode_delta(message))
    when "keys" then lend_keys(peer, read_keys(message["k"]))
    when "hold" then catch_up(peer, read_holdings(message), false)
    when "learn" then learn_told(peer, message["skill"].to_i)
    when "recruit" then recruit(peer, message["actor"].to_i)
    when "depart" then depart(peer, message["actor"].to_i)
    when "gain" then gain(peer, message["item"].to_s)
    else log("ignored #{kind} from #{MGQ_MpOverworldSync.who(peer)}: unknown kind")
    end
  rescue => e
    log("taking #{message['story']} failed: #{e.class}: #{e.message}")
  end

  # Finds why a message about the story is not for the player now.
  #
  # @param kind [String] What it is about.
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it.
  # @return [String, nil] The reason, nil when the player takes it.
  def self.ignore_reason(kind, peer)
    if kind == "ask"
      return "the player does not lead the party" unless leader == :me
      return "not a member of the party" unless peer && MGQ_MpCoop::Party.member?(peer.state)

      return nil
    end
    return "not from the party's leader (#{MGQ_MpOverworldSync.who(leader)})" unless leader.equal?(peer)
    return nil if kind == "full"
    return "the player does not play the leader's story" unless guest?
    return "still waiting for the leader's whole story" if @waiting && %w(delta keys hold).include?(kind)
    return "the player was ahead of the leader, so they keep nothing of the story" if !@keeps && %w(learn recruit depart).include?(kind)

    nil
  end

  # Sums up the fields of a message about the story that matter for the log.
  #
  # @param kind [String] What it is about.
  # @param message [Hash] The message's fields.
  # @return [String] The summary, with a colon before it; empty when nothing matters.
  def self.message_details(kind, message)
    case kind
    when "full" then ": whole story#{message['part'].to_s == '1' ? ' without what it turned off' : ''}, keys #{message['k']}, skills #{message['sk']}, companions #{message['ac']}, items #{message['it']}, side #{message['side']}"
    when "delta" then ": switches #{message['s'].to_s[0, 200]}; variables #{message['v'].to_s[0, 200]}; self switches #{message['ss'].to_s[0, 200]}"
    when "keys" then ": #{message['k']}"
    when "hold" then ": skills #{message['sk']}, companions #{message['ac']}, items #{message['it']}, side #{message['side']}"
    when "learn" then ": #{skill_label(message['skill'].to_i)}"
    when "recruit", "depart" then ": #{actor_label(message['actor'].to_i)}"
    when "gain" then ": #{message['item']}"
    else ""
    end
  rescue
    ""
  end

  # As leader, logs the companions in the roster that are no story companion, which a member who
  # catches up never gets, since the rewards table leaves them out.
  def self.log_roster_outside_rewards
    return unless defined?(MGQ_MpCoopStoryRewards)

    story = MGQ_MpCoopStoryRewards::ACTORS.map { |id| main_id(id) }
    outside = roster_ids - story - [HERO]
    log("companions in the roster a member does not catch up with, not in the rewards table's companions: #{outside.map { |id| actor_label(id) }.join(', ')}") unless outside.empty?
  end

  # Sends a message about the story to one member or to the whole party.
  #
  # @param seat [Integer] The member's seat, -1 for everyone, who ignore it outside the party.
  # @param kind [String] "ask", "full", "delta", "keys", "hold", "learn", "recruit", "depart" or "gain".
  # @param fields [Hash] The message's other fields.
  # @return [Boolean] Whether it went out.
  def self.tell(seat, kind, fields)
    sent = MGQ_MpCoop.tell(seat, "story", kind, fields)
    log("#{sent ? 'sent' : 'could not send'} #{kind} to #{seat < 0 ? 'the party' : "seat #{seat}"} (#{MGQ_MpCoop.bytes_of(fields)} bytes)")
    sent
  end

  # Names a skill for the log, such as "skill 937 Demon Decapitation".
  #
  # @param id [Integer] The skill.
  # @return [String] The name.
  def self.skill_label(id)
    "skill #{MGQ_MpLog.named($data_skills, id)}"
  end

  # Names a companion for the log, such as "companion 517 Puruel".
  #
  # @param id [Integer] The companion.
  # @return [String] The name.
  def self.actor_label(id)
    "companion #{MGQ_MpLog.named($data_actors, id)}"
  end

  # Names an item for the log by the letter of its kind and its id.
  #
  # @param key [String] The item, such as "i501", or "g0" for gold.
  # @return [String] The name.
  def self.item_label(key)
    return "gold" if key.to_s[0, 1] == "g"

    item = item_of(key.to_s)
    item ? "item #{key} #{item.name}" : "item #{key}"
  rescue
    "item #{key}"
  end

  # Says how far a story is for the log: the main story and the three routes' progress.
  #
  # @param variables [Array] The story's variables.
  # @return [String] Such as "1001=12, routes 0/0/0".
  def self.progress_text(variables)
    "1001=#{variables[1001].to_i}, routes #{ROUTE_MARKERS.map { |id| variables[id].to_i }.join('/')}"
  rescue
    "unknown progress"
  end

  # Sums up what of the story's rewards a leader holds for the log.
  #
  # @param held [Hash] What they hold, see holdings.
  # @return [String] The counts and the side.
  def self.holdings_text(held)
    "#{held[:skills].size} skills, #{held[:actors].size} companions, #{held[:items].size} items, side #{held[:side] || 'none'}"
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
      @route_waiting = []
      @recorded = [{}, {}, {}]
      @departed = []
      @lent = {}
    end
    set_raw(*mix(story, raw_state))
    @borrowed = deep_copy(raw_state)
    @waiting = false
    unless first
      log("took #{MGQ_MpOverworldSync.who(leader)}'s whole story again, at #{progress_text(story[1])}")
      return
    end

    log("story mode with #{MGQ_MpOverworldSync.who(leader)}: #{story_mode}; own #{progress_text(@own[1])}, leader #{progress_text(story[1])}; " \
        "own side #{@own_side || 'none'}, leader's side #{held[:side] || 'none'}#{@partial ? '; the story came without what it turned off' : ''}")
    # Events the leader's story got past before a member as far along joined are theirs to play.
    @baseline_groups = @same ? (0...groups.size).select { |index| marked?(groups[index]) } : nil
    log("events where the sides differ the leader's story got past before the member joined, theirs to play: #{@baseline_groups.inspect}") if @same

    MGQ_MpOverworldSync.notice("You follow #{leader.state['name']}'s story while in the party." + follow_text)
  end

  # Says for the log how the player plays the leader's story, and why.
  #
  # @return [String] The mode and its reason.
  def self.story_mode
    return "keep, as far along as the leader, so they keep what they play together" if @same
    return "catch up, behind the leader, so they keep the leader's story and get what it gave" if @keeps

    ahead = STORY_MARKERS.select { |id| @own[1][id].to_i > data_of($game_variables)[id].to_i }
    "borrow, ahead of the leader (#{ahead.map { |id| "#{id}: #{@own[1][id].to_i} > #{data_of($game_variables)[id].to_i}" }.join(', ')}), so they get their own story back unchanged"
  rescue
    "borrow"
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
    before = story[1][1001].to_i
    # The variables come first, since a route's progress decides whether the side switches that
    # come with it are the player's own.
    changes[1].each do |id, value|
      next if personal_variable?(id) || !known_id?(:variables, id)

      story[1][id] = @borrowed[1][id] = value
      @recorded[1][id] = value if @same
    end
    changes[0].each do |id, value|
      next if personal_switch?(id, story[1]) || !known_id?(:switches, id)

      story[0][id] = @borrowed[0][id] = value
      @recorded[0][id] = value if @same
    end
    changes[2].each do |key, value|
      next if personal_self_switch?(key)

      story[2][key] = @borrowed[2][key] = value
      @recorded[2][key] = value if @same
    end
    own = changes[1].count { |id, _| personal_variable?(id) } + changes[0].count { |id, _| personal_switch?(id, story[1]) } +
          changes[2].count { |key, _| personal_self_switch?(key) }
    log("took the leader's changes: #{changes[0].size} switches, #{changes[1].size} variables, #{changes[2].size} self switches, " \
        "#{own} of them left as the player's own; now #{progress_text(story[1])}#{@same ? ', kept for their own story' : ''}")
    set_raw(*story)
    follow_route_side
    take_route_rewards if @keeps
    return unless @keeps && defined?(MGQ_MpCoopChoices)

    changed = changes[0].map { |id, _| id } + changes[1].map { |id, _| id }
    MGQ_MpCoopChoices.story_passed(before, story[1][1001].to_i, changed)
  end

  # Takes the side of the leader's route once the story played is past the Great Decision, which
  # sets the side anew; the leader's game sends no side switch that did not change in it.
  def self.follow_route_side
    side = @leader_held && @leader_held[:side]
    return if side.nil? || sides_differ?

    data = data_of($game_switches)
    return if data[ALICE_CHOSEN] == (side == :alice) && data[ILIAS_CHOSEN] == (side == :ilias)

    data[ALICE_CHOSEN] = side == :alice
    data[ILIAS_CHOSEN] = side == :ilias
    $game_map.need_refresh = true if $game_map
    log("past the Great Decision, the player plays the side of the leader's route: #{side_name(side)}")
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
  # unless the story came without what it turned off, see full, and their own chests on every map,
  # so one only the leader looted stays shut for them.
  #
  # @return [Array] The switches, variables and self switches.
  def self.caught_up_story
    story = raw_state
    unless @partial
      2.times do |kind|
        @own[kind].each_with_index { |value, id| story[kind][id] = value if story[kind][id].nil? && !value.nil? }
      end
      @own[2].each { |key, value| story[2][key] = value unless story[2].key?(key) }
    end
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
    if telling_party?
      log("#{actor_label(actor_id)} joined in the story, telling the party")
      tell(-1, "recruit", "actor" => actor_id)
    elsif leading_synced?
      log("#{actor_label(actor_id)} joined outside the story (#{untold_reason}), so they stay the leader's")
    end
  rescue => e
    log("telling a companion failed: #{e.class}: #{e.message}")
  end

  # As leader, tells the party about a companion who left in the story. Called when a companion
  # leaves.
  #
  # @param actor_id [Integer] The companion.
  def self.left(actor_id)
    if telling_party?
      log("#{actor_label(actor_id)} left in the story, telling the party")
      tell(-1, "depart", "actor" => actor_id)
    elsif leading_synced?
      log("#{actor_label(actor_id)} left outside the story (#{untold_reason}), the party is not told")
    end
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
    return if amount == 0

    if telling_party?
      log("the story #{amount > 0 ? 'gave' : 'took'} #{item_label("#{kind}#{id}")} x#{amount.abs}, telling the party")
      tell(-1, "gain", "item" => "#{kind}#{id}x#{amount}")
    elsif leading_synced?
      log("#{amount > 0 ? 'got' : 'lost'} #{item_label("#{kind}#{id}")} x#{amount.abs} outside the story (#{untold_reason}), the party is not told")
    end
  rescue => e
    log("telling an item failed: #{e.class}: #{e.message}")
  end

  # Says for the log why the leader's game tells the party nothing now, see telling_party?.
  #
  # @return [String] The reason.
  def self.untold_reason
    return "in a battle" if $game_party && $game_party.in_battle
    return "not on the map but in #{SceneManager.scene.class}" unless SceneManager.scene.is_a?(Scene_Map)

    "no story event plays"
  rescue
    "unknown"
  end

  # Reports whether the player leads a party through its story now, with members who follow it, on
  # the map, whose rewards each player who follows it gets in their own game; never in a battle, nor in a shop or a menu the story opens,
  # where the player buys, sells or changes their party of their own accord.
  #
  # @return [Boolean] Whether they do.
  def self.telling_party?
    return false unless leading_synced?
    return false if $game_party && $game_party.in_battle
    return false unless SceneManager.scene.is_a?(Scene_Map)

    MGQ_MpCoopEvents.telling?
  end

  # Takes a companion who joined the leader in the story the player plays along, back into the
  # party when the story only sent them away for a while; never one only the leader's side gets,
  # though one the Great Decision brings waits until the story is past it, see take_route_rewards.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer, nil] The leader.
  # @param actor_id [Integer] The companion.
  def self.recruit(leader, actor_id)
    return log("skipped companion #{actor_id}: no companion") if actor_id <= 0
    return if skipped?(:actors, actor_id, actor_label(actor_id))
    return wait_for_route(:actors, actor_id) if sided?(:actors, actor_id)

    name = @departed.delete(actor_id) ? bring(actor_id) : join(actor_id)
    MGQ_MpOverworldSync.notice("#{name} joined you too.") if name
  end

  # Keeps a reward the leader's story gave while the sides still differ, which the Great Decision
  # may give the member's route too, until the story is past it.
  #
  # @param kind [Symbol] :skills or :actors.
  # @param id [Integer] The reward.
  def self.wait_for_route(kind, id)
    label = kind == :skills ? skill_label(id) : actor_label(id)
    return log("skipped #{label}: sided, only the events where the sides differ give it, which come with those events") unless route_reward?(kind, id)

    @route_waiting ||= []
    @route_waiting << [kind, id] unless @route_waiting.include?([kind, id])
    log("#{label} waits for the story to get past the Great Decision, since the sides still differ (route waiting)")
  end

  # Reports whether the Final Chapter gives a reward too, see MGQ_MpCoopStoryRewards::ROUTE.
  #
  # @param kind [Symbol] :skills or :actors.
  # @param id [Integer] The reward.
  # @return [Boolean] Whether it does.
  def self.route_reward?(kind, id)
    defined?(MGQ_MpCoopStoryRewards) && MGQ_MpCoopStoryRewards::ROUTE[kind].include?(id) ? true : false
  end

  # Gives the rewards that waited for the story to get past the Great Decision, once it is, those
  # the leader still holds; the others went with the route the leader took.
  #
  # The Great Decision brings its companions before the route's progress tells it is over.
  def self.take_route_rewards
    return if @route_waiting.nil? || @route_waiting.empty? || @leader_held.nil? || sides_differ?

    waiting = @route_waiting
    @route_waiting = []
    log("the story is past the Great Decision, taking the #{waiting.size} rewards that waited for it")
    waiting.each do |kind, id|
      unless @leader_held[kind].include?(id)
        log("dropped #{kind == :skills ? skill_label(id) : actor_label(id)}: not held by the leader, it went with the route they took")
        next
      end

      kind == :skills ? learn_told(nil, id) : recruit(nil, id)
    end
  end

  # Lets a companion go who left the leader in the story the player plays along.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param actor_id [Integer] The companion.
  def self.depart(leader, actor_id)
    unless actor_id > 0 && $data_actors[actor_id] && in_roster?(actor_id)
      return log("skipped the departure of #{actor_label(actor_id)}: not in the player's roster")
    end

    in_party = $game_party.exist_party_actor_id?(actor_id)
    @departed << actor_id if in_party
    $game_party.remove_actor(actor_id)
    log("#{actor_label(actor_id)} left the player too#{in_party ? ', from the party, back if the story brings them again' : ', from the castle'}")
    MGQ_MpOverworldSync.notice("#{$data_actors[actor_id].name} left you too.")
  end

  # Gives or takes items or gold as the leader's story did, to a member who keeps the story. One
  # ahead of the leader borrows the leader's key items instead, see lend_keys.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param text [String] The item as written: kind, id, "x" and amount, below zero for a loss.
  def self.gain(leader, text)
    return log("skipped the story's gift #{text}: unreadable") unless text =~ /\A([iwag])(\d+)x(-?\d+)\z/

    kind, id, amount = Regexp.last_match(1), Regexp.last_match(2).to_i, Regexp.last_match(3).to_i
    return log("skipped the story's gift #{item_label("#{kind}#{id}")} x#{amount}: the player was ahead of the leader, so they keep nothing of the story") unless @keeps

    if kind == "g"
      before = $game_party.gold
      MGQ_MpCoopEvents.granting { $game_party.gain_gold(amount) }
      name = "#{amount.abs} #{Vocab.currency_unit}"
      log("the story #{amount > 0 ? 'gave' : 'took'} #{amount.abs} gold, #{before} -> #{$game_party.gold}")
    else
      item = MGQ_MpGame.item(kind, id)
      return log("skipped the story's gift #{kind}#{id} x#{amount}: not in the game") unless item

      before = $game_party.item_number(item)
      MGQ_MpCoopEvents.granting { $game_party.gain_item(item, amount) }
      name = amount.abs > 1 ? "#{item.name} x#{amount.abs}" : item.name
      log("the story #{amount > 0 ? 'gave' : 'took'} #{item_label("#{kind}#{id}")} x#{amount.abs}, #{before} -> #{$game_party.item_number(item)}")
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
    return log("lending no key items: the player keeps the story, so the catch-up gives them") if @keeps
    return log("lending no key items: the player does not play the leader's story") unless guest?

    lent_now = []
    returned = []
    (keys.keys | @lent.keys).each do |id|
      item = $data_items[id]
      unless item && item.key_item?
        log("lending no #{item_label("i#{id}")}: no key item")
        next
      end

      lent = @lent[id].to_i
      own = $game_party.item_number(item) - lent
      wanted = [keys[id].to_i - own, 0].max
      next if wanted == lent

      log("#{wanted > lent ? 'lent' : 'gave back'} #{item_label("i#{id}")}: the leader holds #{keys[id].to_i}, the player #{own} of their own, lent #{lent} -> #{wanted}")
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
    entries(text).each { |id, count| keys[id.to_i] = count.to_i if known_id?(:items, id.to_i) && count.to_i > 0 }
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
    held[:skills] = MGQ_MpCoopStoryRewards::SKILLS.select { |id| knows?(hero, id) }
    roster = roster_ids
    held[:actors] = MGQ_MpCoopStoryRewards::ACTORS.select { |id| roster.include?(main_id(id)) }
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
  # where the sides differ that the leader's story got past, see due_groups, and those the Great
  # Decision brought once the story is past it, see take_route_rewards.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param held [Hash] What the leader holds, see holdings.
  # @param first [Boolean] Whether the member just started following the story.
  def self.catch_up(leader, held, first)
    @leader_held = held
    unless guest?
      return log("no catch-up with #{MGQ_MpOverworldSync.who(leader)}'s #{holdings_text(held)}: the player does not play the leader's story")
    end
    unless @keeps
      return log("no catch-up with #{MGQ_MpOverworldSync.who(leader)}'s #{holdings_text(held)}: the player was ahead of the leader, so they keep nothing of the story")
    end

    follow_route_side
    take_route_rewards
    past = first && !@same
    if past
      log("catching up with #{MGQ_MpOverworldSync.who(leader)}'s story, the player was behind: the leader holds #{holdings_text(held)}")
    else
      log("checking #{MGQ_MpOverworldSync.who(leader)}'s #{holdings_text(held)} for events where the sides differ#{first ? ', the player is as far along, so only what the leader gets from now on counts' : ''}")
    end
    skills = past ? held[:skills].reject { |id| (sided?(:skills, id) && log_sided(skill_label(id))) || skipped?(:skills, id, skill_label(id)) } : []
    actors = past ? held[:actors].reject { |id| (sided?(:actors, id) && log_sided(actor_label(id))) || skipped?(:actors, id, actor_label(id)) } : []
    due_groups(held).each do |rewards|
      skills |= rewards[:skills]
      actors |= rewards[:actors]
    end
    learned = skills.map { |id| learn(id) }.compact
    joined = actors.map { |id| join(id) }.compact
    items = past ? fill_items(held[:items]) : []
    log("caught up: learned #{learned.size} skills, #{joined.size} companions joined, got #{items.size} items")
    name = leader.state["name"]
    MGQ_MpOverworldSync.notice("#{$game_actors[HERO].name} learned #{key_list(learned, 'skills')} to catch up with #{name}'s story.") unless learned.empty?
    MGQ_MpOverworldSync.notice("#{key_list(joined, 'companions')} joined you to catch up with #{name}'s story.") unless joined.empty?
    MGQ_MpOverworldSync.notice("You got #{key_list(items, 'items')} to catch up with #{name}'s story.") unless items.empty?
  end

  # Reports whether the catch-up leaves out a reward for the story's choices, through
  # coop_choices.rbx, and logs why.
  #
  # @param kind [Symbol] :skills, :actors or :items.
  # @param id [Integer, String] The reward.
  # @param label [String] The reward, as skill_label or actor_label names it.
  # @return [Boolean] Whether it does.
  def self.skipped?(kind, id, label)
    reason = defined?(MGQ_MpCoopChoices) ? MGQ_MpCoopChoices.skip_reason(kind, id) : nil
    log("skipped #{label}: #{reason}") if reason
    reason ? true : false
  end

  # As member, tells coop_choices.rbx the leader's whole story came, and which story's choices
  # catching up with it carried the player past, to ask their own outcome.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param first [Boolean] Whether the player just started following the story.
  def self.choices_borrowed(leader, first)
    return unless defined?(MGQ_MpCoopChoices)

    MGQ_MpCoopChoices.story_passed(@own[1][1001].to_i, data_of($game_variables)[1001].to_i) if first && @keeps
    MGQ_MpCoopChoices.borrowed(leader)
  end

  # Logs a reward the catch-up leaves out because only the events where the sides differ give it.
  #
  # @param label [String] The reward, as skill_label or actor_label names it.
  # @return [Boolean] true, so the reward is left out.
  def self.log_sided(label)
    log("skipped #{label}: sided, only the events where the sides differ give it, the player's own side's come with those events")
    true
  end

  # As leader, tells the party about a story skill Luka learned while the story plays, so members
  # who keep the story learn it too. Called when a character learns a skill.
  #
  # @param actor [Game_Actor] The character.
  # @param skill_id [Integer] The skill.
  def self.learned(actor, skill_id)
    return unless defined?(MGQ_MpCoopStoryRewards) && MGQ_MpCoopStoryRewards::SKILLS.include?(skill_id)
    return unless actor.equal?($game_actors[HERO])
    return log("Luka learned #{skill_label(skill_id)} outside the story (#{untold_reason}), the party is not told") if leading_synced? && !telling_party?
    return unless telling_party?

    log("Luka learned #{skill_label(skill_id)} in the story, telling the party")
    tell(-1, "learn", "skill" => skill_id)
  rescue => e
    log("telling a skill failed: #{e.class}: #{e.message}")
  end

  # Teaches Luka a story skill he learned in the leader's story the player plays along, unless only
  # one side's events teach it, which come with those events, see due_groups; one the Great
  # Decision teaches too waits until the story is past it, see take_route_rewards.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer, nil] The leader.
  # @param skill_id [Integer] The skill.
  def self.learn_told(leader, skill_id)
    return wait_for_route(:skills, skill_id) if sided?(:skills, skill_id)

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
    return log("skipped #{skill_label(id)}: not in the game") if skill.nil?
    return log("skipped #{skill_label(id)}: Luka knows it already") if knows?(hero, id)

    hero.learn_skill(id)
    log("Luka learned #{skill_label(id)}")
    skill.name
  end

  # Reports whether Luka knows a skill or an ability, which the game keeps apart from his skills.
  #
  # @param hero [Game_Actor] Luka.
  # @param id [Integer] The skill.
  # @return [Boolean] Whether he does.
  def self.knows?(hero, id)
    learned = MGQ_MpGame.get(hero, :skills)
    known = learned ? learned.include?(id) : $data_skills[id] && hero.skill_learn?($data_skills[id])
    return true if known

    abilities = MGQ_MpGame.get(hero, :abilities)
    abilities.is_a?(Hash) && abilities.values.flatten.include?(id) ? true : false
  end

  # Brings a story companion the player lacks into the roster, waiting at the castle.
  #
  # @param id [Integer] The companion.
  # @return [String, nil] Their name, nil when they were there or the game lacks them.
  def self.join(id)
    return log("skipped #{actor_label(id)}: not in the game") unless $data_actors[id]
    return log("skipped #{actor_label(id)}: in the player's roster already") if in_roster?(id)

    $game_party.add_stand_actor(id)
    log("#{actor_label(id)} joined the player's roster, waiting at the castle")
    $data_actors[id].name
  end

  # Brings a companion the player lacks into the party, or into the roster when it is full or a
  # story's temporary party plays.
  #
  # @param id [Integer] The companion.
  # @return [String, nil] Their name, nil when they were there or the game lacks them.
  def self.bring(id)
    return log("skipped #{actor_label(id)}: not in the game") unless $data_actors[id]
    return log("skipped #{actor_label(id)}: in the player's roster already") if in_roster?(id)

    stand = $game_party.party_member_full? || ($game_party.respond_to?(:temp_actors_use?) && $game_party.temp_actors_use?)
    stand ? $game_party.add_stand_actor(id) : $game_party.add_actor(id)
    log("#{actor_label(id)} joined the player's #{stand ? 'roster, waiting at the castle, as the party is full or a story party plays' : 'party'}")
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
      unless item
        log("skipped #{item_label(key)}: not in the game")
        next
      end

      next if skipped?(:items, key, item_label(key))

      most = MGQ_MpCoopStoryRewards::ITEMS[key] if defined?(MGQ_MpCoopStoryRewards)
      most ||= item.is_a?(RPG::Item) && item.key_item? ? count : 0
      have = story_count(item)
      missing = [count, most].min - have
      unless missing > 0
        log("skipped #{item_label(key)}: #{most == 0 ? 'no story item' : "the player holds #{have}, the leader #{count}, the story gives at most #{most}"}")
        next
      end

      MGQ_MpCoopEvents.granting { $game_party.gain_item(item, missing) }
      log("gave #{item_label(key)} x#{missing}: the player held #{have}, the leader holds #{count}, the story gives at most #{most}")
      missing > 1 ? "#{item.name} x#{missing}" : item.name
    end.compact
  end

  # The side the player plays, as the switches of the story played tell.
  #
  # @return [Symbol, nil] :alice, :ilias, or nil before they chose.
  def self.own_side
    side_of(data_of($game_switches))
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
    variables ||= $game_variables ? data_of($game_variables) : []
    ROUTE_MARKERS.all? { |id| variables[id].to_i == 0 }
  end

  # The events where the sides get other rewards, see MGQ_MpCoopStoryRewards::GROUPS.
  #
  # @return [Array<Hash>] The events.
  def self.groups
    defined?(MGQ_MpCoopStoryRewards) ? MGQ_MpCoopStoryRewards::GROUPS : []
  end

  # Reports whether only the events where the sides differ give a reward, which comes with those
  # events alone, see MGQ_MpCoopStoryRewards::SIDED, so a member holds only their own side's; any
  # other comes as the leader holds it, as does one the Final Chapter gives too once the story played
  # is past the Great Decision, see MGQ_MpCoopStoryRewards::ROUTE.
  #
  # @param kind [Symbol] :skills or :actors.
  # @param id [Integer] The reward.
  # @return [Boolean] Whether they do.
  def self.sided?(kind, id)
    return false unless defined?(MGQ_MpCoopStoryRewards) && MGQ_MpCoopStoryRewards::SIDED[kind].include?(id)

    sides_differ? || !route_reward?(kind, id)
  end

  # Finds the rewards of the member's side, see story_side, of the events where the sides differ
  # that the leader's story got past and the member has not had yet. The place where the player
  # chooses a side gives its companion once to a member who never chose, see choose_side.
  #
  # @param held [Hash] What the leader holds.
  # @return [Array<Hash>] The side's :skills and :actors of each such event.
  def self.due_groups(held)
    side = story_side
    unless side
      log_once([:no_side, @leader_id], "no rewards of the events where the sides differ yet: the player has no side before the Great Decision")
      return []
    end

    known = (@granted_groups ||= []) + (@baseline_groups || [])
    due = []
    groups.each_with_index do |group, index|
      next if known.include?(index)
      next if group[:choice] ? @own_side : !played?(group, held)

      @granted_groups << index
      due << group[side]
      reason = group[:choice] ? "where the player chooses a side, which they never did themselves" : (marked?(group) ? "its marks hold in the story" : "the leader holds a reward only it gives")
      log("event #{index} where the sides differ is due (#{reason}): #{side_name(side)}'s side gets skills #{group[side][:skills].map { |id| skill_label(id) }.join(', ')}; " \
          "companions #{group[side][:actors].map { |id| actor_label(id) }.join(', ')}")
    end
    due
  end

  # Reports whether the leader's story got past an event where the sides differ: what one of its
  # pages leaves in the story holds, or the leader holds a reward only this event gives.
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
    when :s then data_of($game_switches)[mark[1]] ? true : false
    when :v then data_of($game_variables)[mark[1]].to_i >= mark[2]
    when :ss then data_of($game_self_switches)[mark[1, 3]] == true
    else false
    end
  end

  # Reports whether the leader holds a reward that only this event gives, to either side, since they
  # came to hold it after the player joined.
  #
  # Either side counts, since the Great Decision sets the leader's side anew after the event gave
  # the side they played then its reward.
  #
  # @param group [Hash] The event.
  # @param held [Hash] What the leader holds.
  # @return [Boolean] Whether they do.
  def self.only_from?(group, held)
    [:skills, :actors].any? do |kind|
      (group[:alice][kind] | group[:ilias][kind]).any? do |id|
        sources = groups.select { |each_group| each_group[:alice][kind].include?(id) || each_group[:ilias][kind].include?(id) }
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
    log("asking the player whom they take along, as #{MGQ_MpOverworldSync.who(leader)} took #{side_name(@leader_held[:side])} and the player has no side")
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
    log("the player took #{side_name(side)} along, as their own side#{guest? ? ', kept for their own story too' : ''}")
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
    MGQ_MpCoopEvents.pvp_running? || !guest? || @waiting ? true : false
  end

  # Keeps a message that changes what the member holds until they can keep it, with the id of the
  # leader who sent it.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param message [Hash] The message.
  def self.hold_back(peer, message)
    (@held ||= []) << [peer.state["id"].to_s, message]
    dropped = 0
    while @held.size > MAX_HELD
      @held.shift
      dropped += 1
    end
    reason = MGQ_MpCoopEvents.pvp_running? ? "a PvP battle runs" : (guest? ? "waiting for the leader's whole story" : "the player does not play the leader's story yet")
    log("held back #{message['story']} from #{MGQ_MpOverworldSync.who(peer)}: #{reason} (#{@held.size} waiting#{dropped > 0 ? ", dropped the #{dropped} oldest" : ''})")
  end

  # Forgets the messages kept back that the leader's whole story just covered: older holdings,
  # which would replace the newer ones, and for a member who just caught up with what the leader
  # holds, what the story gave meanwhile, which they would get twice. Departures still count.
  #
  # @param caught_up [Boolean] Whether the member just caught up with what the leader holds.
  def self.drop_covered(caught_up)
    covered = caught_up ? %w(hold gain recruit learn) : %w(hold)
    before = (@held || []).size
    (@held || []).reject! { |_, message| covered.include?(message["story"]) }
    dropped = before - (@held || []).size
    log("forgot #{dropped} waiting messages the whole story covered (#{covered.join(', ')}#{caught_up ? ', the player just caught up' : ''})") if dropped > 0
  end

  # Takes the messages kept back, once the member plays the leader's story again outside a PvP
  # battle, those of the leader who sent them alone, since another leader's story differs; forgets
  # them once the party is over.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The leader.
  def self.take_held(leader)
    return if @held.nil? || @held.empty?
    unless leader.is_a?(MGQ_MpOverworldSync::Peers::Peer)
      log("forgot #{@held.size} waiting messages: the party with a leader is over")
      return @held = nil
    end
    return if held_back?

    held = @held
    @held = nil
    id = leader.state["id"].to_s
    others = held.count { |from, _| from != id }
    log("taking #{held.size - others} waiting messages from #{MGQ_MpOverworldSync.who(leader)}#{others > 0 ? ", dropping #{others} from a former leader" : ''}")
    held.each { |from, message| take(leader, message) if from == id }
  end

  # Takes back the key items the leader's story lent, as the player gets their own story back.
  def self.return_lent
    names = []
    (@lent || {}).each do |id, amount|
      item = $data_items[id]
      next unless item

      back = [amount, $game_party.item_number(item)].min
      MGQ_MpCoopEvents.granting { $game_party.gain_item(item, -back) }
      log("gave back #{item_label("i#{id}")} x#{back} of #{amount} lent")
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
    (guest? ? @own[2][key] : data_of($game_self_switches)[key]) == true
  end

  # Sets a self switch of the player's own, such as a chest's, in their own story and in the one
  # they play.
  #
  # @param key [Array] The self switch: map, event and letter.
  # @param value [Boolean] Its value.
  def self.keep_own_self_switch(key, value)
    @own[2][key] = value if guest?
    data_of($game_self_switches)[key] = value
    $game_map.need_refresh = true if $game_map
    log("kept self switch #{key.join('.')} #{value ? 'on' : 'off'} as the player's own#{guest? ? ', in their own story too' : ''}")
  end

  # Shows the player's own chests on a map they enter while playing the leader's story. Called
  # after a map is set up.
  def self.map_entered
    return unless guest?

    data = data_of($game_self_switches)
    keys = chest_keys
    keys.each { |key| data[key] = @own[2][key] }
    $game_map.need_refresh = true
    log("showing the player's own chests on map #{$game_map.map_id}: #{keys.size} chests, #{keys.count { |key| @own[2][key] }} of them opened") unless keys.empty?
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
    before = progress_text(data_of($game_variables))
    return_lent
    story = own_with_values
    set_raw(*story)
    log("back in the player's own story (#{@same ? 'kept what they played together, as far along' : (kept ? "kept the leader's story they caught up with" : 'unchanged, they were ahead')}): " \
        "played #{before}, now #{progress_text(story[1])}#{@partial ? ', without own values in the gaps of a story too large to send whole' : ''}")
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
    @partial = false
    @route_waiting = nil
  end

  # The story a save holds: the member's own while they play the leader's; in a Raid World the
  # story as it is, the world's laid over the player's own.
  #
  # @param contents [Hash] What the game saves.
  # @return [Hash] The same, with the member's own story.
  def self.save_contents(contents)
    return contents if !guest? || MGQ_MpCoop::Scope.raid?

    switches, variables, self_switches = own_with_values
    contents[:switches] = with_data(contents[:switches], switches)
    contents[:variables] = with_data(contents[:variables], variables)
    contents[:self_switches] = with_data(contents[:self_switches], self_switches)
    contents[:party] = without_lent(contents[:party]) if contents[:party]
    log("the save holds the player's own story at #{progress_text(variables)} instead of the leader's at #{progress_text(data_of($game_variables))}" \
        "#{(@lent || {}).empty? ? '' : ", without #{@lent.size} lent key items"}")
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
    [data_of($game_switches).dup, data_of($game_variables).dup, data_of($game_self_switches).dup]
  end

  # Replaces the story as the game keeps it, past the game's own handling, which would add or remove
  # companions, and has the map's events look at it again.
  #
  # @param switches [Array] The switches.
  # @param variables [Array] The variables.
  # @param self_switches [Hash] The self switches.
  def self.set_raw(switches, variables, self_switches)
    MGQ_MpGame.set($game_switches, :data, switches)
    MGQ_MpGame.set($game_variables, :data, variables)
    MGQ_MpGame.set($game_self_switches, :data, self_switches)
    $game_map.need_refresh = true if $game_map
  end

  # Reads the data the game keeps for its switches, variables or self switches, past its handling
  # of single entries.
  #
  # @param object [Game_Switches, Game_Variables, Game_SelfSwitches] The object.
  # @return [Array, Hash] The data itself, not a copy.
  def self.data_of(object)
    MGQ_MpGame.get(object, :data)
  end

  # Joins one story with the player's own values.
  #
  # @param story [Array] The switches, variables and self switches of the story.
  # @param personal [Array] Those of the player, whose own values win.
  # @param chests [Array<Array>] The self switches of the chests that stay the player's own, those
  #   on the map by default.
  # @return [Array] The joined switches, variables and self switches.
  def self.mix(story, personal, chests = chest_keys)
    switches = story[0].dup
    variables = story[1].dup
    [personal[0].size, switches.size].max.times { |id| switches[id] = personal[0][id] if personal_switch?(id, story[1]) }
    [personal[1].size, variables.size].max.times { |id| variables[id] = personal[1][id] if personal_variable?(id) }
    self_switches = story[2].dup
    chests.each { |key| self_switches[key] = personal[2][key] }
    [switches, variables, self_switches]
  end

  # Reports whether a switch is the player's own. The side is until the Great Decision, and always
  # in a Raid World, where everyone keeps the side they chose.
  #
  # @param id [Integer] The switch.
  # @param variables [Array, nil] The variables of the story it belongs to, nil for the one played.
  # @return [Boolean] Whether it is.
  def self.personal_switch?(id, variables = nil)
    return MGQ_MpCoop::Scope.raid? || sides_differ?(variables) if SIDE_SWITCHES.include?(id)

    PERSONAL_SWITCHES.any? { |range| range === id } || id.between?(AWAKENING_SWITCHES, AWAKENING_LAST) || choice_key?(:s, id)
  end

  # Reports whether a switch or a variable is the outcome of a story's choice the member made,
  # through coop_choices.rbx.
  #
  # @param kind [Symbol] :s for a switch, :v for a variable.
  # @param id [Integer] The switch or variable.
  # @return [Boolean] Whether it is.
  def self.choice_key?(kind, id)
    defined?(MGQ_MpCoopChoices) && MGQ_MpCoopChoices.personal?(kind, id) ? true : false
  end

  # The player's own story: the one kept aside while they play the leader's, else the one played.
  #
  # @return [Array, nil] The switches and the variables, nil before the game made them.
  def self.own_story_data
    return [@own[0], @own[1]] if guest?

    $game_switches && $game_variables ? [data_of($game_switches), data_of($game_variables)] : nil
  end

  # The player's own story kept aside while they play the leader's.
  #
  # @return [Array, nil] The switches, variables and self switches, nil while they play their own.
  def self.own_story_aside
    @own
  end

  # As member, follows the story of a leader whose offer to sync the story the player accepted,
  # whatever the rule of check_sync says, until their whole story came.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer] The leader.
  def self.start_offer(leader)
    @sync_state = nil
    log("following #{MGQ_MpOverworldSync.who(leader)}'s story by their offer")
  end

  # Gets the player their own story back, keeping the leader's story they caught up with, and plays
  # on their own: as a member who starts another route of the Final Chapter than the leader's.
  #
  # @param reason [String] Why, for the log.
  def self.keep_and_leave(reason)
    log("leaving the leader's story, keeping it as the player's own: #{reason}")
    restore if guest?
    @synced = false
    @sync_state = nil
  end

  # Reports whether a variable is the player's own.
  #
  # @param id [Integer] The variable.
  # @return [Boolean] Whether it is.
  def self.personal_variable?(id)
    PERSONAL_VARIABLES.any? { |range| range === id } || (id >= AFFECTION_VARIABLES && id < AFFECTION_VARIABLES + companions) || choice_key?(:v, id)
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
  # leaves out what the story turned off or set to zero, and says so.
  #
  # @param story [Array] The switches, variables and self switches.
  # @return [Hash] The packed lists under "z", see unpack, and "part" 1 for a story that leaves
  #   out what it turned off.
  def self.full(story)
    packed = pack(story_lists(story, true))
    return { "z" => packed } if packed.size <= MAX_FULL_BYTES

    log_once(:full_size, "the whole story took #{packed.size} bytes, so it leaves out what the story turned off")
    { "z" => pack(story_lists(story, false)), "part" => 1 }
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
    lists["s"].to_s.split(",").each { |id| switches[id.to_i] = true if known_id?(:switches, id.to_i) }
    lists["sf"].to_s.split(",").each { |id| switches[id.to_i] = false if known_id?(:switches, id.to_i) }
    variables = []
    entries(lists["v"]).each { |id, value| variables[id.to_i] = decode_value(value) if known_id?(:variables, id.to_i) }
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
      entries(message["s"]).map { |id, value| [id.to_i, value == "1"] }.select { |id, _| known_id?(:switches, id) },
      entries(message["v"]).map { |id, value| [id.to_i, decode_value(value)] }.select { |id, _| known_id?(:variables, id) },
      entries(message["ss"]).map { |key, value| [decode_key(key), value == "1"] },
    ]
  end

  # Reports whether an id another game sent names one of this game's switches, variables or items,
  # logging once per kind one beyond them, which is dropped.
  #
  # @param kind [Symbol] :switches, :variables or :items.
  # @param id [Integer] The id.
  # @return [Boolean] Whether it does.
  def self.known_id?(kind, id)
    size = { :switches => $data_system.switches, :variables => $data_system.variables, :items => $data_items }[kind].size
    return true if id > 0 && id < size

    log_once([:unknown_id, kind], "dropped #{kind} #{id} of another game's story: this game has #{size}")
    false
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
    MGQ_MpGame.set(copy, :data, data)
    copy
  end
end

# What this script takes part in of the party's messages, through coop.rbx.

begin
  MGQ_MpCoop.route("story") { |peer, message| MGQ_MpCoopStory.take(peer, message) }
  MGQ_MpOverworldSync.state_fields { MGQ_MpCoopStory.state_fields }
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

# Game hooks of this script alone, through core_hooks.rbx.

begin
  # After a companion joins the party's roster, as leader the party hears of them, also of one the
  # roster holds already, whom a member may lack.
  MGQ_MpHooks.after(Game_Party, :add_stand_actor, "coop_story") { |actor_id| MGQ_MpCoopStory.joined(actor_id) }

  # After a companion leaves the party's roster, as leader the party hears of it.
  MGQ_MpHooks.after(Game_Party, :remove_actor, "coop_story") { |actor_id| MGQ_MpCoopStory.left(actor_id) }
rescue => e
  MGQ_MpCoopStory.log("companion hooks FAILED: #{e.class}: #{e.message}")
end

begin
  # After a map is set up, the player's own chests show on it.
  MGQ_MpHooks.after(Game_Map, :setup, "coop_story") { |_map_id| MGQ_MpCoopStory.map_entered }
rescue => e
  MGQ_MpCoopStory.log("map setup hook FAILED: #{e.class}: #{e.message}")
end

begin
  # What the game saves, with a member's own story in place of the leader's.
  MGQ_MpHooks.around(DataManager.singleton_class, :make_save_contents, "coop_story") do |_manager, _args, original|
    contents = original.call
    begin
      MGQ_MpCoopStory.save_contents(contents)
    rescue => e
      MGQ_MpCoopStory.log("save guard failed: #{e.class}: #{e.message}")
      contents
    end
  end

  # After a loaded save, which brings its own story, the player follows the leader's anew.
  MGQ_MpHooks.after(DataManager.singleton_class, :extract_save_contents, "coop_story") do |_contents|
    MGQ_MpCoopStory.log("a loaded save brings its own story, so the player follows the leader's anew") if MGQ_MpCoopStory.guest?
    MGQ_MpCoopStory.forget
  end

  # After the game's objects are made anew, as for a new game, which brings its own story, the
  # player follows the leader's anew.
  MGQ_MpHooks.after(DataManager.singleton_class, :create_game_objects, "coop_story") do
    MGQ_MpCoopStory.log("a new game brings its own story, so the player follows the leader's anew") if MGQ_MpCoopStory.guest?
    MGQ_MpCoopStory.forget
  end
rescue => e
  MGQ_MpCoopStory.log("save hooks FAILED: #{e.class}: #{e.message}")
end
