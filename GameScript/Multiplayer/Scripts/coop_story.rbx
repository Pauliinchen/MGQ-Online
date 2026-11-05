#----------------------------------------------------------------
#  coop_story.rbx
#
#  Changelog:
#      Paulinchen  2026-11-05: Caught a member behind the leader up by the frozen rows and the leader's chests as the DLL finds them, instead of a copy of what the leader holds
#                            - Told a member only the leader's side, no longer the leader's skills, companions and items
#                            - Dropped the self switches of a choice's lines, which the reviewed key list keeps
#                            - Gave a party member the Medal King's prize another player bought, as the DLL finds it
#      Paulinchen  2026-11-01: Told how many copies of a key item the leader lent the player, which the player never counts as found
#                            - Gave a member a companion of the Alice and Ilias choice only by the side they took along or a route they played, as the DLL finds it
#                            - Read the side a member took along from their switches only before the Great Decision, past it from the save's note
#                            - Asked a member whose save came from another player's starting save whom they take along, and let go the companions of the other side
#                            - Asked a player of a Classic world whom they take along whenever their story is past Iliasville without a side of their own, past the Great Decision too
#      Paulinchen  2026-10-31: Gave the leader's story's gifts, companions, skills and departures by replaying the leader's runs instead of messages, and caught a member up by the frozen rows and derived entries only with the history before the log
#                            - Sent a member's runs of the leader's story with their requests, which the leader keeps for the party and their own game when they changed the leader's story
#                            - Sent a member's writes of the leader's story to the leader as requests, which the leader's story takes by the reviewed list's merge kinds and sends back by value
#                            - Gave a member behind the leader's key items by replaying the party chests that gave them
#                            - Kept a party key a run or a replay wrote in a guest's own story
#                            - Told the party no gain of a party chest's page
#      Paulinchen  2026-10-28: Read the rewards a member catches up with from the catch-up tables the DLL holds, and sent the whole story once they came
#      Paulinchen  2026-10-23: Told the members the story's writes the leader's game made, recorded by story_keys.rbx, instead of a comparison of the whole story every quarter second
#      Paulinchen  2026-10-09: Moved the story's state model into story_state.rbx
#      Paulinchen  2026-10-08: Kept the leader's story to Classic worlds
#                            - Kept the side each player's own in a Raid World
#                            - Let a join of stories keep the chests of a list the caller gives
#                            - Saved a Raid World's story as it is
#      Paulinchen  2026-10-07: Kept the variables the game sets for each area and battle each player's own
#                            - Dropped switches, variables and key items beyond this game's own
#                            - Registered the companion, map and save hooks through core_hooks.rbx
#                            - Named players, data entries and message sizes through shared helpers
#                            - Kept the outcomes of the member's own story choices their own
#                            - Let a member play the leader's story only while synced with the leader
#                            - Logged how each member plays the leader's story and why
#      Paulinchen  2026-10-06: Read the game's switches, variables and self switches through MGQ_MpGame
#                            - Told members only what the story's own commands change
#                            - Gave members the companions the Great Decision brings
#                            - Told the party a companion who joins in the story though the leader has them
#                            - Counted Luka's story abilities, and companions by their main persona
#                            - Found an event played by a reward only it gives either side
#                            - Kept what waits for the member for the leader who sent it
#                            - Stopped keeping a member's own values in the gaps of a story too large to send whole
#                            - Asked coop_events.rbx whether a PvP battle runs
#                            - Let members behind the leader keep the story they play together too
#                            - Told members the story skills Luka learns while the story plays
#                            - Kept every chest the member's own when they catch up
#                            - Forgot what waited before the leader's whole story covered it
#                            - Read the player's own companions past a story's temporary party
#                            - Never took a companion into the roster twice in a world
#                            - Packed the whole story
#                            - Kept switches from 7000 out of the awakening switches
#                            - Sent the switches and self switches the story turned off with the whole story
#                            - Kept the side each player chose their own until the Great Decision
#                            - Gave a member their own side's skills and companions where the sides differ
#      Paulinchen  2026-10-04: Lent members the leader's key items on every change and held back gifts in duels
#                            - Kept where the Pocket Castle's way out returns each player their own
#                            - Lent the key items of the leader's story to members not as far along
#                            - Renamed from mp_coop_story.rbx
#      Paulinchen  2026-10-03: Kept the warp ban as each player's own
#                            - Called the scripts that load before this one without checking them
#                            - Sent messages and read the world through MGQ_MpOverworldSync
#                            - Logged through MGQ_MpLog
#      Paulinchen  2026-10-02: Gave members as far along as the leader the story's items, gold and departures
#                            - Kept what a member as far along as the leader changed in their own game
#                            - Ended the awakening switches with the last companion's
#                            - Followed the map's update through core_hooks.rbx
#      Paulinchen  2026-10-01: Kept the places of the player's party their own
#      Paulinchen  2026-09-30: Sent and took the party's messages through coop.rbx
#                            - Registered with overworld_sync.rbx for its messages
#                            - Moved into Patch/Multiplayer/Scripts as coop_story.rbx
#                            - Renamed from mp_story.rb, with the module MGQ_MpCoopStory
#                            - Kept what members as far along as the leader play together
#                            - Kept chests the player's own while they play the leader's story
#                            - Created
#
#----------------------------------------------------------------

# The story a party plays. Outside a party every player plays their own story. In a party, the
# members synced with the leader, close to the leader in the story (see sync_state), borrow the
# leader's story, the switches, variables and self switches the game's events read, and get their
# own back when they leave or the leader goes. What the reviewed list keeps each player's own
# stays theirs throughout, and every save a member makes holds their own story. The leader's story
# is the one truth: its changes reach the members by value, a member's writes of it go to the
# leader as requests, and what each run of the leader's gives reaches every member who follows the
# story by replaying the run in their own game (coop_events.rbx hand_entry). A member as far along
# as the leader keeps what they play together. A member behind the leader keeps the leader's story
# and catches up once with its history from before the log, as a Raid World's history: the frozen
# rows the leader's story is past and theirs is not, of their own side, the world chests and the key
# items' party chests the leader's story opened, played in their own game, and the closures of their
# own keys. Nothing is copied from what the leader holds.
# A member not synced plays their own story throughout, while still sharing the party. What is the
# player's own and how a story is read, joined and sent is the state model of story_state.rbx.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpCoopStory
  # The DLL's topic that names the party chests that gave a key item, as runs of the member's history.
  KEY_CHESTS_TOPIC = "story.replay_key_chests"

  # The DLL's topic of which companions of the Alice and Ilias choice may join a player.
  SCOPE_TOPIC = "catchup.scope"

  # The DLL's topics of what a member behind the leader catches up with by the frozen rows, and of
  # the keys of a story those rows read.
  CATCHUP_TOPIC = "catchup.classic"
  KEYS_TOPIC = "catchup.keys"

  # The DLL's topic of the Medal King's prizes a player of a Classic party is owed.
  GIFT_TOPIC = "catchup.medal_king"

  # The field of $game_system that keeps the switches of the Medal King's exchanges the player's
  # story was looked at with, see check_gifts.
  GIFTS_FIELD = :@mgq_mp_medal_gifts

  # Frames between two looks for the Medal King's prizes, a second at 60 frames per second.
  GIFT_FRAMES = 60

  # The routes as the DLL names them, each with its variable and the switch that tells it cleared.
  SCOPE_ROUTES = { "ad" => [1141, 7096], "mr" => [1142, 7097], "chaos" => [1143, 7039] }

  # Frames between two messages of the leader, a quarter of a second at 60 frames per second.
  SEND_FRAMES = 15

  # Frames between two requests for the leader's story, two seconds, until it came.
  ASK_FRAMES = 120

  # Variables that tell how far along a story is: the main story (1001) and the three routes'
  # progress (1141-1143).
  STORY_MARKERS = [1001, 1141, 1142, 1143]

  # The main story's progress the Great Decision sets, which no later event raises.
  GREAT_DECISION = 40

  # How far apart in the main story two players may be before the Great Decision to play one story.
  SYNC_STEPS = 2

  # How far apart on their route two players may be after the Great Decision to play one story.
  ROUTE_SYNC_STEPS = 5

  # The message of the leader's side, which waits while the member cannot take it, see held_back?.
  HOLDINGS = %w(hold)

  # Messages that wait at most for the member to keep them.
  MAX_HELD = 100

  # The player's own switches, variables and self switches, kept aside while they play the
  # leader's story, nil while they play their own.
  @own = nil

  # The leader's story as it last came whole, its switches, variables and self switches; nil while
  # the player plays their own.
  @leader_story = nil

  # The id of the leader whose story the player asked for or follows, nil for none.
  @leader_id = nil

  # As leader, the story's writes the player's game made since the members were last told, the
  # last value by key; nil while no member follows the player's story.
  @writes = nil

  # As member, the writes of the leader's story the player's game made since the leader was last
  # asked to take them, the last value by key; nil while none waits.
  @requests = nil

  # As member, the entries of the player's runs of the leader's story that go with the next requests,
  # oldest first; they wait while the leader's story is asked for again.
  @request_runs = []

  # Frames since the leader last told what changed, see SEND_FRAMES.
  @frames = 0

  # Frames since the member last asked for the leader's story, see ASK_FRAMES.
  @ask_frames = 0

  # Frames since the last look for the Medal King's prizes, see GIFT_FRAMES.
  @gift_frames = 0

  # The switches of the Medal King's exchanges and their prizes, as the DLL names them; nil until
  # it did.
  @prizes = nil

  extend MGQ_MpLog

  # What starts this script's lines in the log.
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
      @writes = nil
      @sent_held = nil
      @followers = nil
      follow(leader) if leader && @synced
      request(leader)
    end
    ask_side(leader)
    check_gifts if leader
  rescue => e
    log_once(:update, "update failed: #{e.class}: #{e.message}")
  end

  # Gives the player of a Classic party the Medal King's prizes they are owed, the one path of his
  # free gift (MedalKingGift in the DLL): once the story they play holds the switch of an exchange
  # it was not looked at with, they get its prize if they hold none. Looks once a second while the
  # map is free, so a purchase of the player's own has given its prize first.
  def self.check_gifts
    @gift_frames += 1
    return if @gift_frames < GIFT_FRAMES || !$game_system || !MGQ_MpOverworldSync.map_free? || MGQ_MpStoryReplay.running?

    @gift_frames = 0
    @prizes ||= MGQ_Multiplayer::Bridge.call(GIFT_TOPIC, {})
    return @prizes = nil unless @prizes.is_a?(Hash) && !Array(@prizes["switches"]).empty?

    handled = Array($game_system.instance_variable_get(GIFTS_FIELD))
    return if @prizes["switches"].all? { |id| handled.include?(id) || !$game_switches[id] }

    keys = MGQ_Multiplayer::Bridge.call(KEYS_TOPIC)
    return unless keys.is_a?(Hash)

    story = [$game_switches, $game_variables, $game_self_switches].map { |object| MGQ_MpStoryState.data_of(object) }
    counts = {}
    Array(@prizes["items"]).each do |key|
      item = MGQ_MpStoryState.item_of(key)
      counts[key] = MGQ_MpStoryState.story_count(item) if item
    end
    answer = MGQ_Multiplayer::Bridge.call(GIFT_TOPIC, "story" => rows_values(story, keys), "items" => counts, "handled" => handled)
    return unless answer.is_a?(Hash)

    $game_system.instance_variable_set(GIFTS_FIELD, Array(answer["handled"]))
    log("the story holds the Medal King's exchange switches #{(Array(answer['handled']) - handled).join(', ')}, #{Array(answer['gifts']).size} prizes owed")
    given = Array(answer["gifts"]).map { |kind, id, amount| give_gift(kind, id, amount) }.compact
    MGQ_MpOverworldSync.notice("The Medal King gave you #{key_list(given, 'items')}.") unless given.empty?
  end

  # Gives the player a prize of the Medal King's.
  #
  # @param kind [String] "i", "w" or "a".
  # @param id [Integer] The item.
  # @param amount [Integer] How many.
  # @return [String, nil] Its name; nil for an item the game lacks.
  def self.give_gift(kind, id, amount)
    item = MGQ_MpStoryState.item_of("#{kind}#{id}")
    return log("skipped the Medal King's prize #{MGQ_MpStoryState.item_label("#{kind}#{id}")}: not in the game") unless item

    $game_party.gain_item(item, amount)
    log("the Medal King gave #{MGQ_MpStoryState.item_label("#{kind}#{id}")} x#{amount}: the story holds his exchange's switch and the player held none")
    item.name
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
    markers_of(guest? && !@keeps ? @own[1] : MGQ_MpStoryState.data_of($game_variables))
  end

  # Reads where the player started following the leader's story, from which the leader's runs come
  # to them live (see MGQ_MpCoopEvents.take_entry).
  #
  # @return [Array<Integer>, nil] The leader's story's values then, see markers_of; nil while the
  #   player follows none.
  def self.follow_place
    @follow_place
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
  # @return [Integer, nil] The route's place among MGQ_MpStoryState::ROUTE_MARKERS, nil before any.
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
    own = markers_of(MGQ_MpStoryState.data_of($game_variables))
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

  # As leader, tells the members what of the story the player's game wrote since the last time,
  # as story_keys.rbx records the writes of what the party shares.
  def self.lead
    if synced_members.empty?
      MGQ_MpStoryKeys.recording = nil
      @writes = nil
      @sent_keys = nil
      @sent_held = nil
      return
    end

    MGQ_MpStoryKeys.recording = :classic
    @writes ||= {}
    @frames += 1
    return if @frames < SEND_FRAMES

    @frames = 0
    unless @writes.empty?
      changes = delta_of(@writes)
      log("the story changed: #{changes.map { |key, list| "#{key} #{list.split(',').size}" }.join(', ')} (#{changes.values.join(',')[0, 200]}), " \
          "now #{MGQ_MpStoryState.progress_text(MGQ_MpStoryState.data_of($game_variables))}")
      @writes = {} if tell(-1, "delta", changes)
    end
    keys = key_items
    if keys != @sent_keys
      log("the leader's key items changed: #{keys.map { |id, count| "#{MGQ_MpStoryState.item_label("i#{id}")} x#{count}" }.join(', ')}")
      @sent_keys = keys if tell(-1, "keys", "k" => write_keys(keys))
    end
    held = write_holdings(holdings)
    if held != @sent_held
      log("the leader's side changed: #{held['side']}")
      @sent_held = held if tell(-1, "hold", held)
    end
  end

  # Takes the story's writes the player's game made in a frame, the last value of each key kept: as
  # leader, to tell the members; as member, to ask the leader to take them. Called by story_keys.rbx.
  #
  # @param batch [Array<Array>] Each write's key, value and site, see MGQ_MpStoryKeys.key_text.
  def self.recorded(batch)
    writes = guest? ? (@requests ||= {}) : @writes
    return unless writes

    batch.each do |key, value, _site|
      writes.delete(key)
      writes[key] = value
    end
  end

  # As member who plays the leader's story, records the writes of the leader's story the player's
  # game makes, and asks the leader to take them, every SEND_FRAMES, with the entries of the
  # player's runs of it: the leader's story is the one truth, which sends back what it keeps by value
  # and the runs that changed it as entries of its stream.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer, nil] The party's leader.
  def self.request(leader)
    return if MGQ_MpCoop::Scope.raid?

    asking = leader.is_a?(MGQ_MpOverworldSync::Peers::Peer) && guest? && !@waiting && follows_leader?
    MGQ_MpStoryKeys.recording = asking ? :classic : nil
    return @requests = nil unless asking
    return if (@requests.nil? || @requests.empty?) && @request_runs.empty?

    @frames += 1
    return if @frames < SEND_FRAMES

    @frames = 0
    changes = delta_of(@requests || {})
    runs = @request_runs.map { |entry| MGQ_MpStoryReplay.wire(entry) }.compact
    log("asking the leader to take the story's writes the player's game made: #{changes.values.join(',')[0, 200]}; #{runs.size} run(s)")
    return unless tell(leader.seat, "req", runs.empty? ? changes : changes.merge("runs" => runs.join(",")))

    @requests = {}
    @request_runs = []
  end

  # As member who plays the leader's story, keeps the entry of a run of the player's game that
  # changed a key of the leader's story, which goes to the leader with the next requests.
  #
  # @param entry [Hash] The run's entry, see ReplayEntry.Write in the DLL.
  def self.request_run(entry)
    @request_runs << entry
    log("the run of #{entry['site']} goes to the leader with the next requests as entry #{entry['id']}")
  end

  # As leader, takes the writes a member's game made of the player's story, each by its merge kind
  # (see merged), and tells everyone who follows the story the value it keeps, the member too; then
  # the member's runs, see keep_runs.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @param changes [Array] The switches, variables and self switches written, each by key.
  # @param runs [Array<String>] The entries of the member's runs, as MGQ_MpStoryReplay.wire writes them;
  #   the message joins them with commas, which the wire's Base64 never holds.
  def self.take_requests(peer, changes, runs = [])
    taken = []
    refused = []
    changed = {}
    changes.each_with_index do |list, kind|
      list.each do |key, value|
        held = MGQ_MpStoryKeys.value_of(kind, key)
        kept = merged(kind, key, held, value)
        name = MGQ_MpStoryKeys.key_text(kind, key)
        changed[name] = true unless kept == held
        write_own(kind, key, kept) unless kept == held
        (kept == value ? taken : refused) << name
        text = MGQ_MpStoryKeys.text_of(kind, kept)
        (@writes ||= {})[name] = text if text
      end
    end
    log("took #{MGQ_MpOverworldSync.who(peer)}'s requests: #{taken.join(', ')[0, 200]}#{refused.empty? ? '' : "; refused, kept as the story holds them: #{refused.join(', ')[0, 200]}"}")
    keep_runs(peer, runs, changed)
  end

  # As leader, keeps the runs of a member's game whose step changed the player's story, or holds a
  # party key, which the member's own save changed, in the stream of the player's story: the party
  # and the player's own game play them, and the member's log claims its own step. A run that changed
  # nothing of it, as the second of two openers, goes to nobody.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @param runs [Array<String>] The entries, as MGQ_MpStoryReplay.wire writes them.
  # @param changed [Hash{String => Boolean}] The keys the member's requests changed in the player's story.
  def self.keep_runs(peer, runs, changed)
    runs.each do |text|
      entry = MGQ_MpStoryReplay.unwire(text.to_s)
      next log("dropped a run of #{MGQ_MpOverworldSync.who(peer)} that does not read") unless entry.is_a?(Hash)

      names = (entry["keys"] || {}).keys
      unless names.any? { |name| changed[name] || party_key?(name, entry["site"]) }
        next log("dropped #{MGQ_MpOverworldSync.who(peer)}'s run of #{entry['site']}: it changed nothing of the story")
      end

      entry["stream"] = MGQ_MpStoryKeys.story_stream(:me)
      entry["opener"] = peer.state["name"].to_s
      MGQ_MpCoopEvents.hand_kept(entry)
    end
  end

  # Reports whether a key is a party key, which each player's own save keeps.
  #
  # @param name [String] The key, as the tracks name it.
  # @param site [String, nil] Where the run started.
  # @return [Boolean] Whether it is.
  def self.party_key?(name, site)
    kind, key = MGQ_MpStoryKeys.key_of(name)
    kind && kind < 3 && MGQ_MpStoryKeys.scope_of(kind, key, site) == MGQ_MpStoryKeys::SCOPE_PARTY ? true : false
  end

  # Decides the value the leader's story keeps of a member's write: a key the reviewed list makes
  # the world's, as the relay takes a Raid World's writes; but a count, which each game counts of
  # its own switches, and a one-way value set lower stay as the story holds them.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id or key.
  # @param held [Object] The value the story holds.
  # @param value [Object] The value the member wrote.
  # @return [Object] The value the story keeps.
  def self.merged(kind, key, held, value)
    return held unless MGQ_MpStoryState.classic_world?(kind, key)

    found = MGQ_MpStoryKeys.class_of(kind, key, nil, list_table)
    return held if found & MGQ_MpStoryKeys::COUNT != 0
    return held if found & MGQ_MpStoryKeys::ONE_WAY != 0 && value.is_a?(Numeric) && held.is_a?(Numeric) && value < held

    value
  end

  # The reviewed list's table, with the merge kind of each key, as the DLL hands it; asked again
  # once the rewards changed, which come with another list.
  #
  # @return [MGQ_MpStoryKeys::Table, nil] The table, nil before the list came.
  def self.list_table
    serial = MGQ_MpStoryState.rewards_serial
    return @list_table if @list_table && @list_serial == serial

    hash = MGQ_Multiplayer::Bridge.call(MGQ_MpStoryKeys::CLASSES_TOPIC)
    @list_serial = serial
    @list_table = hash ? MGQ_MpStoryKeys.table_of(hash) : nil
  end

  # Writes a value of the player's story as the multiplayer's own, past the game's own handling.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id or key.
  # @param value [Object] The value.
  def self.write_own(kind, key, value)
    data = MGQ_MpStoryState.data_of(kind == 0 ? $game_switches : kind == 1 ? $game_variables : $game_self_switches)
    data[key] = value
    $game_map.need_refresh = true if $game_map
  end

  # Writes the story's writes as the members read them, see MGQ_MpStoryState.decode_delta.
  #
  # @param writes [Hash{String => String}] Each key's last value, as story_keys.rbx writes them.
  # @return [Hash] The changed switches, variables and self switches under "s", "v" and "ss".
  def self.delta_of(writes)
    lists = { "s" => [], "v" => [], "ss" => [] }
    writes.each do |key, value|
      kind, id = MGQ_MpStoryKeys.key_of(key)
      case kind
      when 0 then lists["s"] << "#{id}:#{value}"
      when 1 then lists["v"] << "#{id}:#{value}"
      when 2 then lists["ss"] << "#{id.join('.')}:#{value}"
      end
    end
    Hash[lists.map { |name, list| [name, list.join(",")] }]
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
    return unless @waiting && rewards_came?

    @ask_frames += 1
    return if @ask_frames < ASK_FRAMES

    @ask_frames = 0
    @asks = @asks.to_i + 1
    log("asking #{MGQ_MpOverworldSync.who(leader)} for their whole story, try #{@asks}")
    tell(leader.seat, "ask", {})
  end

  # Reports whether the rewards a member catches up with came from the DLL with the story mapping,
  # which the whole story waits for on both sides: without them a member would catch up with
  # nothing, and with every side's rewards. Logs once while they have not.
  #
  # @return [Boolean] Whether they came.
  def self.rewards_came?
    return true if MGQ_MpStoryState.rewards

    log_once(:await_rewards, "the whole story waits for the rewards a member catches up with, which come with the story mapping")
    false
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
      return log("left the ask unanswered: the rewards a member catches up with have not come yet, the member asks again") unless rewards_came?

      keys = key_items
      held = holdings
      log("sending #{MGQ_MpOverworldSync.who(peer)} the whole story at #{MGQ_MpStoryState.progress_text(MGQ_MpStoryState.data_of($game_variables))}, side #{held[:side] || 'none'}")
      tell(peer.seat, "full", MGQ_MpStoryState.full(MGQ_MpStoryState.raw_state).merge("k" => write_keys(keys)).merge(write_holdings(held)))
    when "full"
      first = !guest?
      @partial = message["part"].to_s == "1"
      held = read_holdings(message)
      borrow(peer, MGQ_MpStoryState.decode_full(message), held)
      lend_keys(peer, read_keys(message["k"]))
      leader_holds(held)
      catch_up(peer) if first
      drop_covered
      choices_borrowed(peer, first)
    when "delta" then apply(MGQ_MpStoryState.decode_delta(message))
    when "req" then take_requests(peer, MGQ_MpStoryState.decode_delta(message), message["runs"].to_s.split(","))
    when "keys" then lend_keys(peer, read_keys(message["k"]))
    when "hold" then leader_holds(read_holdings(message))
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
    if kind == "req"
      return "the player does not lead the party" unless leader == :me
      return "not a member who follows the player's story" unless peer && synced_members.any? { |member| member.state["id"].to_s == peer.state["id"].to_s }

      return nil
    end
    return "not from the party's leader (#{MGQ_MpOverworldSync.who(leader)})" unless leader.equal?(peer)
    return nil if kind == "full"
    return "the player does not play the leader's story" unless guest?
    return "still waiting for the leader's whole story" if @waiting && %w(delta keys hold).include?(kind)

    nil
  end

  # Sums up the fields of a message about the story that matter for the log.
  #
  # @param kind [String] What it is about.
  # @param message [Hash] The message's fields.
  # @return [String] The summary, with a colon before it; empty when nothing matters.
  def self.message_details(kind, message)
    case kind
    when "full" then ": whole story#{message['part'].to_s == '1' ? ' without what it turned off' : ''}, keys #{message['k']}, side #{message['side']}"
    when "delta", "req" then ": switches #{message['s'].to_s[0, 200]}; variables #{message['v'].to_s[0, 200]}; self switches #{message['ss'].to_s[0, 200]}"
    when "keys" then ": #{message['k']}"
    when "hold" then ": side #{message['side']}"
    else ""
    end
  rescue
    ""
  end

  # Sends a message about the story to one member or to the whole party.
  #
  # @param seat [Integer] The member's seat, -1 for everyone, who ignore it outside the party.
  # @param kind [String] "ask", "full", "delta", "req", "keys" or "hold".
  # @param fields [Hash] The message's other fields.
  # @return [Boolean] Whether it went out.
  def self.tell(seat, kind, fields)
    sent = MGQ_MpCoop.tell(seat, "story", kind, fields)
    log("#{sent ? 'sent' : 'could not send'} #{kind} to #{seat < 0 ? 'the party' : "seat #{seat}"} (#{MGQ_MpCoop.bytes_of(fields)} bytes)")
    sent
  end

  # Starts playing the leader's story, keeping the player's own aside the first time.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param story [Array] The leader's switches, variables and self switches.
  # @param held [Hash] The leader's side, see holdings.
  def self.borrow(leader, story, held)
    first = !guest?
    if first
      @own = MGQ_MpStoryState.deep_copy(MGQ_MpStoryState.raw_state)
      @same = same_story?(@own, story)
      @keeps = @same || behind?(@own, story)
      @follow_place = markers_of(story[1])
      # The side the member took along in Iliasville, whose rewards they get.
      @own_side = MGQ_MpStoryState.own_pick(@own[0], @own[1])
      @recorded = [{}, {}, {}]
      @lent = {}
    end
    MGQ_MpStoryState.set_raw(*MGQ_MpStoryState.mix(story, MGQ_MpStoryState.raw_state, MGQ_MpStoryState.chest_keys | MGQ_MpStoryState.all_chest_keys))
    @leader_story = story
    @borrowed = MGQ_MpStoryState.deep_copy(MGQ_MpStoryState.raw_state)
    @waiting = false
    unless first
      log("took #{MGQ_MpOverworldSync.who(leader)}'s whole story again, at #{MGQ_MpStoryState.progress_text(story[1])}")
      return
    end

    log("story mode with #{MGQ_MpOverworldSync.who(leader)}: #{story_mode}; own #{MGQ_MpStoryState.progress_text(@own[1])}, leader #{MGQ_MpStoryState.progress_text(story[1])}; " \
        "own side #{@own_side || 'none'}, leader's side #{held[:side] || 'none'}#{@partial ? '; the story came without what it turned off' : ''}")
    MGQ_MpOverworldSync.notice("You follow #{leader.state['name']}'s story while in the party." + follow_text)
  end

  # Says for the log how the player plays the leader's story, and why.
  #
  # @return [String] The mode and its reason.
  def self.story_mode
    return "keep, as far along as the leader, so they keep what they play together" if @same
    return "catch up, behind the leader, so they keep the leader's story and get what it gave" if @keeps

    ahead = STORY_MARKERS.select { |id| @own[1][id].to_i > MGQ_MpStoryState.data_of($game_variables)[id].to_i }
    "borrow, ahead of the leader (#{ahead.map { |id| "#{id}: #{@own[1][id].to_i} > #{MGQ_MpStoryState.data_of($game_variables)[id].to_i}" }.join(', ')}), so they get their own story back unchanged"
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
    story = MGQ_MpStoryState.raw_state
    before = story[1][1001].to_i
    # The variables come first, since a route's progress decides whether the side switches that
    # come with it are the player's own.
    changes[1].each do |id, value|
      next if MGQ_MpStoryState.personal_variable?(id) || !MGQ_MpStoryState.known_id?(:variables, id)

      story[1][id] = @borrowed[1][id] = value
      @recorded[1][id] = value if @same
    end
    changes[0].each do |id, value|
      next if MGQ_MpStoryState.personal_switch?(id, story[1]) || !MGQ_MpStoryState.known_id?(:switches, id)

      story[0][id] = @borrowed[0][id] = value
      @recorded[0][id] = value if @same
    end
    changes[2].each do |key, value|
      next if MGQ_MpStoryState.personal_self_switch?(key)

      story[2][key] = @borrowed[2][key] = value
      @recorded[2][key] = value if @same
    end
    own = changes[1].count { |id, _| MGQ_MpStoryState.personal_variable?(id) } + changes[0].count { |id, _| MGQ_MpStoryState.personal_switch?(id, story[1]) } +
          changes[2].count { |key, _| MGQ_MpStoryState.personal_self_switch?(key) }
    log("took the leader's changes: #{changes[0].size} switches, #{changes[1].size} variables, #{changes[2].size} self switches, " \
        "#{own} of them left as the player's own; now #{MGQ_MpStoryState.progress_text(story[1])}#{@same ? ', kept for their own story' : ''}")
    MGQ_MpStoryState.set_raw(*story)
    follow_route_side
    return unless @keeps && defined?(MGQ_MpCoopChoices)

    changed = changes[0].map { |id, _| id } + changes[1].map { |id, _| id }
    MGQ_MpCoopChoices.story_passed(before, story[1][1001].to_i, changed)
  end

  # Takes the side of the leader's route once the story played is past the Great Decision, which
  # sets the side anew; the leader's game sends no side switch that did not change in it.
  def self.follow_route_side
    side = @leader_held && @leader_held[:side]
    return if side.nil? || MGQ_MpStoryState.sides_differ?

    data = MGQ_MpStoryState.data_of($game_switches)
    return if data[MGQ_MpStoryState::ALICE_CHOSEN] == (side == :alice) && data[MGQ_MpStoryState::ILIAS_CHOSEN] == (side == :ilias)

    data[MGQ_MpStoryState::ALICE_CHOSEN] = side == :alice
    data[MGQ_MpStoryState::ILIAS_CHOSEN] = side == :ilias
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
    played = MGQ_MpStoryState.raw_state
    3.times do |kind|
      @recorded[kind].each { |key, value| story[kind][key] = value }
      MGQ_MpStoryState.changed_keys(@borrowed[kind], played[kind]).each { |key| story[kind][key] = played[kind][key] }
    end
    story
  end

  # The leader's story as the player plays it, which a player who was behind keeps, with their own
  # values wherever the leader's story never set one, such as a side quest only the player played,
  # unless the story came without what it turned off, see MGQ_MpStoryState.full, and their own
  # chests on every map, so one only the leader looted stays shut for them.
  #
  # @return [Array] The switches, variables and self switches.
  def self.caught_up_story
    story = MGQ_MpStoryState.raw_state
    unless @partial
      2.times do |kind|
        @own[kind].each_with_index { |value, id| story[kind][id] = value if story[kind][id].nil? && !value.nil? }
      end
      @own[2].each { |key, value| story[2][key] = value unless story[2].key?(key) }
    end
    MGQ_MpStoryState.all_chest_keys.each { |key| @own[2].key?(key) ? story[2][key] = @own[2][key] : story[2].delete(key) }
    story
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
        log("lending no #{MGQ_MpStoryState.item_label("i#{id}")}: no key item")
        next
      end

      lent = @lent[id].to_i
      own = $game_party.item_number(item) - lent
      wanted = [keys[id].to_i - own, 0].max
      next if wanted == lent

      log("#{wanted > lent ? 'lent' : 'gave back'} #{MGQ_MpStoryState.item_label("i#{id}")}: the leader holds #{keys[id].to_i}, the player #{own} of their own, lent #{lent} -> #{wanted}")
      lend(item, wanted - lent)
      wanted > 0 ? @lent[id] = wanted : @lent.delete(id)
      (wanted > lent ? lent_now : returned) << item.name
    end
    name = leader.state["name"]
    MGQ_MpOverworldSync.notice("#{name} lent you #{key_list(lent_now)} for the story.") unless lent_now.empty?
    MGQ_MpOverworldSync.notice("#{key_list(returned)} went back to #{name}.") unless returned.empty?
  end

  # Lends the player copies of a key item, or gives lent ones back, which no run of the player's
  # counts as a found item it gave or used up (story_keys.rbx).
  #
  # @param item [RPG::Item] The key item.
  # @param amount [Integer] How many, below 0 to give back.
  def self.lend(item, amount)
    @lending = true
    $game_party.gain_item(item, amount)
  ensure
    @lending = false
  end

  # Reports whether the player is lent a key item or gives one back right now.
  #
  # @return [Boolean] Whether they are.
  def self.lending?
    @lending ? true : false
  end

  # Counts the copies of a key item the leader lent the player.
  #
  # @param id [Integer] The key item.
  # @return [Integer] How many.
  def self.lent_count(id)
    @lent ? @lent[id].to_i : 0
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
  # @return [Hash{Integer => Integer}] How many of each, by the item's id; none for a count below
  #   one.
  def self.read_keys(text)
    keys = {}
    MGQ_MpStoryState.entries(text).each { |id, count| keys[id.to_i] = count.to_i if MGQ_MpStoryState.known_id?(:items, id.to_i) && count.to_i > 0 }
    keys
  end

  # As leader, gathers the side the player chose, which a member's side past the Great Decision and
  # the question whom they take along read.
  #
  # @return [Hash] :side.
  def self.holdings
    { :side => own_side }
  end

  # Writes the leader's side for a message.
  #
  # @param held [Hash] The side, see holdings.
  # @return [Hash] The side under "side": "a" for Alice's, "i" for Ilias's, empty for none.
  def self.write_holdings(held)
    { "side" => { :alice => "a", :ilias => "i" }[held[:side]].to_s }
  end

  # Reads the leader's side.
  #
  # @param message [Hash] The message.
  # @return [Hash] The side, see holdings.
  def self.read_holdings(message)
    { :side => { "a" => :alice, "i" => :ilias }[message["side"].to_s] }
  end

  # Keeps the leader's side, which the member's side past the Great Decision and the question whom
  # they take along read, see follow_route_side and ask_side.
  #
  # @param held [Hash] The leader's side, see holdings.
  def self.leader_holds(held)
    @leader_held = held
    follow_route_side
  end

  # Catches a member who starts following the leader's story, behind it, up with the leader's
  # history from before the log, which no run of the leader's reaches them with, as a Raid World's
  # history: what the frozen rows the leader's story is past and theirs is not give, of their own
  # side, as the DLL finds it (ClassicCatchup), the world chests and the key items' party chests the
  # leader's story opened, played in their own game, and the closures of their own keys the leader's
  # story holds (see derive_closures). From then on every run of the leader's story reaches them by
  # replay, so a member as far along or ahead catches up with nothing.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer] The leader.
  def self.catch_up(leader)
    unless @keeps && !@same
      return log("no catch-up with #{MGQ_MpOverworldSync.who(leader)}'s story: the player is #{@same ? 'as far along as' : 'ahead of'} the leader, so the leader's runs from now on bring all they get")
    end

    log("catching up with #{MGQ_MpOverworldSync.who(leader)}'s story by the frozen rows, the player was behind")
    take_rows(leader, false)
    derive_closures
  end

  # Gives a member who caught up what the frozen rows the leader's story is past give, as the DLL
  # finds it: every row as they start following, or once they chose a side, the rows of that side.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param sided [Boolean] Whether only the rows of a side count.
  def self.take_rows(leader, sided)
    answer = rows_due(sided)
    return unless answer

    learned = Array(answer["skills"]).map { |id| MGQ_MpStoryState.learn(id) }.compact
    joined = Array(answer["joins"]).map { |id| MGQ_MpStoryState.join(id) }.compact
    Array(answer["lessons"]).each { |actor, skill| MGQ_MpStoryState.teach(actor, skill) }
    Array(answer["classes"]).each { |actor, klass, level| MGQ_MpStoryState.give_class(actor, klass, level) }
    items = Array(answer["items"]).map { |kind, id, amount| give_row_item(kind, id, amount) }.compact
    items += key_items_owed(Array(answer["key_items"]))
    Array(answer["chests"]).each { |chest| MGQ_MpStoryReplay.derive({ "chest" => chest }, "the leader's story opened the chest #{chest} before the player followed it") }
    log("caught up: learned #{learned.size} skills, #{joined.size} companions joined, got #{items.size} items, #{Array(answer['chests']).size} chests play")
    name = leader.state["name"]
    MGQ_MpOverworldSync.notice("#{$game_actors[MGQ_MpStoryState::HERO].name} learned #{key_list(learned, 'skills')} to catch up with #{name}'s story.") unless learned.empty?
    MGQ_MpOverworldSync.notice("#{key_list(joined, 'companions')} joined you to catch up with #{name}'s story.") unless joined.empty?
    MGQ_MpOverworldSync.notice("You got #{key_list(items, 'items')} to catch up with #{name}'s story.") unless items.empty?
  end

  # Asks the DLL what the frozen rows the leader's story is past and the member's own is not give.
  #
  # @param sided [Boolean] Whether only the rows of a side count.
  # @return [Hash, nil] The answer, see ClassicCatchup in the DLL; nil while the story mapping has
  #   not come.
  def self.rows_due(sided)
    keys = MGQ_Multiplayer::Bridge.call(KEYS_TOPIC)
    return log("no catch-up by the frozen rows: the story mapping has not come") unless keys.is_a?(Hash) && @own && @leader_story

    counts = {}
    $game_party.items.each { |item| counts["i#{item.id}"] = [$game_party.item_number(item) - lent_count(item.id), 0].max if item.is_a?(RPG::Item) && item.key_item? }
    roster = MGQ_MpStoryState.roster_ids.map { |id| MGQ_MpStoryState.main_id(id) }.uniq
    answer = MGQ_Multiplayer::Bridge.call(CATCHUP_TOPIC, "own" => rows_values(@own, keys), "leader" => rows_values(@leader_story, keys), "side" => scope_pick.to_s,
                                                         "roster" => roster, "items" => counts, "routes" => scope_routes, "sided" => sided)
    answer.is_a?(Hash) ? answer : nil
  end

  # Reads the values of a story the frozen rows read, as the Raid catch-up's snapshot holds them.
  #
  # @param story [Array] The switches, variables and self switches.
  # @param keys [Hash] What the rows read, see the DLL's catchup.keys.
  # @return [Hash] "s" (the switches on), "v" ([id, value] each) and "ss" (the self switches on).
  def self.rows_values(story, keys)
    {
      "s" => Array(keys["switches"]).select { |id| story[0][id] },
      "v" => Array(keys["variables"]).map { |id| story[1][id].is_a?(Integer) ? [id, story[1][id]] : nil }.compact,
      "ss" => Array(keys["selves"]).select { |key| story[2][key] },
    }
  end

  # Gives the member an item a frozen row gives.
  #
  # @param kind [String] "i", "w" or "a".
  # @param id [Integer] The item.
  # @param amount [Integer] How many.
  # @return [String, nil] What was given, as shown; nil for an item the game lacks.
  def self.give_row_item(kind, id, amount)
    item = MGQ_MpStoryState.item_of("#{kind}#{id}")
    return log("skipped #{MGQ_MpStoryState.item_label("#{kind}#{id}")}: not in the game") unless item

    $game_party.gain_item(item, amount)
    log("gave #{MGQ_MpStoryState.item_label("#{kind}#{id}")} x#{amount}, which a row the leader's story is past gives")
    amount > 1 ? "#{item.name} x#{amount}" : item.name
  end

  # Gives the member the key items the leader's story owes and they lack: those a party chest gave
  # the leader come by playing that chest in their own game, the others as the rows give them.
  #
  # @param owed [Array<Array>] [id, amount] each, see ClassicCatchup in the DLL.
  # @return [Array<String>] What was given, as shown.
  def self.key_items_owed(owed)
    replayed = replay_key_chests(owed.map { |id, _amount| id })
    owed.map { |id, amount| replayed.include?(id) ? nil : give_row_item("i", id, amount) }.compact
  end

  # Hands a member who was behind the leader the closures of their own keys the leader's story
  # holds, which ran in the leader's game before the member followed it: each self switch the
  # leader's story holds on, which the reviewed list keeps each player's own and the member's own
  # copy holds off, played in the member's own game from the page that turns it on, its choices
  # answered by the branch that ends with the leader's letters of the event (DerivedAnswers in the
  # DLL). A party chest's comes with its own catch-up (replay_key_chests), and a choice's line with
  # coop_choices.rbx, which asks the member's own outcome.
  def self.derive_closures
    return unless @leader_story

    found = MGQ_MpStoryState.rewards
    closed = @leader_story[2].keys.select do |key|
      @leader_story[2][key] && !@own[2][key] && !MGQ_MpStoryState.classic_world?(2, key) && !(found && found.chest?(key))
    end
    log("the leader's story closed #{closed.size} pages of keys of the player's own, which play in the player's game") unless closed.empty?
    closed.each do |key|
      map, event, _letter = key
      letters = %w(A B C D).select { |letter| @leader_story[2][[map, event, letter]] }
      MGQ_MpStoryReplay.derive({ "chest" => MGQ_MpStoryKeys.key_text(2, key), "letters" => letters }, "the leader's story closed #{key.join('.')} before the player followed it")
    end
  end

  # Hands the member the party chests that gave the leader a key item the member lacks, each played
  # in the member's own game as a run of their history: the whole chest comes, the item with it.
  #
  # @param lacking [Array<Integer>] The key items the member lacks.
  # @return [Array<Integer>] The key items that come so.
  def self.replay_key_chests(lacking)
    return [] if lacking.empty? || @leader_story.nil?

    opened = MGQ_MpStoryState.all_chest_keys.select { |chest| @leader_story[2][chest] }
    answer = MGQ_Multiplayer::Bridge.call(KEY_CHESTS_TOPIC, "items" => lacking, "opened" => opened, "party" => true)
    return [] unless answer.is_a?(Hash)

    Array(answer["entries"]).each { |entry| MGQ_MpStoryReplay.receive(entry) }
    covered = Array(answer["items"]).map { |id| id.to_i }
    log("the leader's chests of #{covered.join(', ')} play in the player's game: #{Array(answer['entries']).map { |entry| entry['site'] }.join(', ')}") unless covered.empty?
    covered
  end

  # As member, tells coop_choices.rbx the leader's whole story came, and which story's choices
  # catching up with it carried the player past, to ask their own outcome.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param first [Boolean] Whether the player just started following the story.
  def self.choices_borrowed(leader, first)
    return unless defined?(MGQ_MpCoopChoices)

    MGQ_MpCoopChoices.story_passed(@own[1][1001].to_i, MGQ_MpStoryState.data_of($game_variables)[1001].to_i) if first && @keeps
    MGQ_MpCoopChoices.borrowed(leader)
  end

  # The side the player plays, as the switches of the story played tell.
  #
  # @return [Symbol, nil] :alice, :ilias, or nil before they chose.
  def self.own_side
    MGQ_MpStoryState.side_of(MGQ_MpStoryState.data_of($game_switches))
  end

  # Keeps of some companions those who may join the member, as the DLL finds it: a companion of the
  # Alice and Ilias choice only by the side the member took along or a route they played; while
  # that side is unknown, a route's join by the side switches of the story played, which the game's
  # own event reads. Every companion may join a player who plays their own story.
  #
  # @param ids [Array<Integer>] The companions' main personas.
  # @param site [String, nil] The page or common event whose own join it is, nil for a catch-up.
  # @return [Array<Integer>] Those who may.
  def self.allowed_companions(ids, site = nil)
    return ids if ids.empty? || !guest?

    answer = MGQ_Multiplayer::Bridge.call(SCOPE_TOPIC, "actors" => ids, "site" => site, "pick" => scope_pick.to_s, "routes" => scope_routes, "held" => own_side.to_s)
    return ids unless answer.is_a?(Hash)

    allowed = ids & Array(answer["allowed"])
    (ids - allowed).each { |id| log("left out #{MGQ_MpStoryState.actor_label(id)}: of the side the player did not take along, or of a route they never played") }
    allowed
  rescue => e
    log("asking which companions may join failed: #{e.class}: #{e.message}")
    ids
  end

  # Reports whether the game's own join of a companion is left out for a member, see
  # allowed_companions.
  #
  # @param actor [Integer] The companion's main persona.
  # @param site [String, nil] The page or common event that runs.
  # @return [Boolean] Whether it is.
  def self.refuses_join?(actor, site)
    !allowed_companions([actor], site).include?(actor)
  end

  # The side the member took along in Iliasville: the one they chose when asked, else the one their
  # own story tells, see MGQ_MpStoryState.own_pick.
  #
  # @return [Symbol, nil] :alice, :ilias, or nil while it is unknown.
  def self.scope_pick
    return @own_side if @own_side

    @own ? MGQ_MpStoryState.own_pick(@own[0], @own[1]) : nil
  end

  # Lists the routes the member played: those their own story is on or cleared, and the one the
  # story they play is on.
  #
  # @return [Array<String>] The routes.
  def self.scope_routes
    played = MGQ_MpStoryState.data_of($game_variables)
    SCOPE_ROUTES.select do |_, (variable, cleared)|
      played[variable].to_i > 0 || (@own && (@own[1][variable].to_i > 0 || @own[0][cleared]))
    end.keys
  end

  # The events where the player takes a side along, a named exception of the story replay: the
  # companion and skills the side brings there, see MGQ_MpStoryState::Rewards#groups.
  #
  # @return [Array<Hash>] The events.
  def self.pick_groups
    rewards = MGQ_MpStoryState.rewards
    rewards ? rewards.groups.select { |group| group[:choice] } : []
  end

  # Asks a player of a Classic world whom they take along once they are free on the map, while
  # their own story is past the choice in Iliasville without a side of their own (see
  # side_unknown?), before the Great Decision or past it: a member once the leader's holdings came,
  # outside the leader's story scene; a player alone or a leader at once.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The leader.
  def self.ask_side(leader)
    return if @asking || !MGQ_MpOverworldSync.in_world? || MGQ_MpCoop::Scope.raid? || !side_unknown?
    return if guest? && (@leader_held.nil? || !leader.is_a?(MGQ_MpOverworldSync::Peers::Peer) || leader.state["telling"] == "1")
    return unless MGQ_MpOverworldSync.map_free? && !MGQ_MpCoopEvents.mirroring?

    @asking = true
    taken = guest? && MGQ_MpStoryState.sides_differ? ? @leader_held[:side] : nil
    if taken
      log("asking the player whom they take along, as #{MGQ_MpOverworldSync.who(leader)} took #{side_name(taken)} and the player has no side")
      $game_message.add("#{leader.state['name']} took #{side_name(taken)} along. Whom do you take along on your own journey?")
    else
      log("asking the player whom they take along: their story went past the choice of a side without one of their own")
      $game_message.add("Your story went past the choice of whom you take along. Whom do you take along on your journey?")
    end
    $game_message.choices.push(side_name(:alice), side_name(:ilias))
    $game_message.choice_cancel_type = 0
    $game_message.choice_proc = Proc.new { |index| choose_side(index == 0 ? :alice : :ilias) }
  end

  # Reports whether the player's own story is past the choice of a side in Iliasville without a
  # side they took along themselves: one of another player's starting save, or one whose notes never
  # saw a side and whose switches hold none, as a Raid World's catch-up finds it too.
  #
  # @return [Boolean] Whether it is.
  def self.side_unknown?
    return false if @own_side

    story = guest? ? @own : [MGQ_MpStoryState.data_of($game_switches), MGQ_MpStoryState.data_of($game_variables)]
    return false if MGQ_MpStoryState.own_pick(story[0], story[1])

    note = MGQ_MpStoryState.pick_note
    return true if note == ""

    note.nil? && MGQ_MpStoryState.side_of(story[0]).nil? && past_side_choice?
  end

  # Reports whether the story played is past the choice of a side in Iliasville: for a member, the
  # leader holds a side; else its main story is at the choice's point or further.
  #
  # @return [Boolean] Whether it is.
  def self.past_side_choice?
    return true if guest? && @leader_held && @leader_held[:side]

    point = defined?(MGQ_MpCoopChoices) ? MGQ_MpCoopChoices.point_of(:side) : 0
    point > 0 && MGQ_MpStoryState.data_of($game_variables)[1001].to_i >= point
  end

  # Names a side by the one the player takes along.
  #
  # @param side [Symbol] :alice or :ilias.
  # @return [String] "Alice" or "Ilias".
  def self.side_name(side)
    side == :alice ? "Alice" : "Ilias"
  end

  # Keeps the side the player chose as their own and notes it in the save. Before the Great
  # Decision it also sets the side's switch, brings in the companion the choice brings, as the
  # Iliasville scene does, and catches a member up with the side's rows; past it the route's own
  # handling of the companions stays, and so do the side switches, which tell the route.
  #
  # @param side [Symbol] :alice or :ilias.
  def self.choose_side(side)
    @asking = false
    @own_side = side
    MGQ_MpStoryState.note_pick(side)
    own_before = !guest? || MGQ_MpStoryState.sides_differ?(@own[1])
    unless MGQ_MpStoryState.sides_differ? && own_before
      log("the player took #{side_name(side)} along, as their own side; their story is past the Great Decision, whose route keeps its side switches and companions")
      return MGQ_MpOverworldSync.notice("You took #{side_name(side)} along.")
    end

    log("the player took #{side_name(side)} along, as their own side#{guest? ? ', kept for their own story too' : ''}")
    MGQ_MpStoryState::SIDE_SWITCHES.each do |id|
      $game_switches[id] = id == (side == :alice ? MGQ_MpStoryState::ALICE_CHOSEN : MGQ_MpStoryState::ILIAS_CHOSEN)
      @own[0][id] = $game_switches[id] if guest?
    end
    pick_groups.each do |group|
      group[side][:skills].each { |id| MGQ_MpStoryState.learn(id) }
      allowed_companions(group[side][:actors]).each { |id| MGQ_MpStoryState.bring(id) }
    end
    dismiss_strangers
    MGQ_MpOverworldSync.notice("You took #{side_name(side)} along.")
    lead = leader
    take_rows(lead, true) if lead.is_a?(MGQ_MpOverworldSync::Peers::Peer) && @keeps && !@same
  rescue => e
    log("choosing a side failed: #{e.class}: #{e.message}")
  end

  # Lets go the companions of the Alice and Ilias choice the member has no right to by the side
  # they just took along, as the DLL finds it, such as those another player's starting save brought.
  def self.dismiss_strangers
    held = MGQ_MpStoryState.roster_ids.map { |id| MGQ_MpStoryState.main_id(id) }.uniq - [MGQ_MpStoryState::HERO]
    (held - allowed_companions(held)).each do |id|
      $game_party.remove_actor(id)
      log("#{MGQ_MpStoryState.actor_label(id)} left the player's roster: of the side they did not take along")
      MGQ_MpOverworldSync.notice("#{$data_actors[id].name} left you.")
    end
  end

  # Reports whether the leader's holdings have to wait: during a PvP battle, which puts the game
  # back as it was before it, and until the member plays the leader's story again, as after loading
  # a save.
  #
  # @return [Boolean] Whether it has to.
  def self.held_back?
    MGQ_MpCoopEvents.pvp_running? || !guest? || @waiting ? true : false
  end

  # Keeps the leader's holdings until the member can take them, with the id of the leader who sent
  # them.
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

  # Forgets the holdings kept back that the leader's whole story just covered, which would replace
  # the newer ones it came with.
  def self.drop_covered
    before = (@held || []).size
    (@held || []).reject! { |_, message| HOLDINGS.include?(message["story"]) }
    dropped = before - (@held || []).size
    log("forgot #{dropped} waiting holdings the whole story covered") if dropped > 0
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
      $game_party.gain_item(item, -back)
      log("gave back #{MGQ_MpStoryState.item_label("i#{id}")} x#{back} of #{amount} lent")
      names << item.name
    end
    @lent = {}
    MGQ_MpOverworldSync.notice("#{key_list(names)} went back to the party's leader.") unless names.empty?
  end

  # Keeps a key a run or a replay of the player's game wrote, such as a chest's, in the player's own
  # story kept aside while they play the leader's, so it stays theirs once they leave.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id, or a self switch's map, event and letter.
  # @param value [Object] Its value.
  def self.keep_own(kind, key, value)
    return unless guest?

    @own[kind][key] = value
    log("kept #{MGQ_MpStoryKeys.key_text(kind, key)} as the player's own in their own story too")
  end

  # Shows the player's own chests on a map they enter while playing the leader's story. Called
  # after a map is set up.
  def self.map_entered
    return unless guest?

    data = MGQ_MpStoryState.data_of($game_self_switches)
    keys = MGQ_MpStoryState.chest_keys
    keys.each { |key| data[key] = @own[2][key] }
    $game_map.need_refresh = true
    log("showing the player's own chests on map #{$game_map.map_id}: #{keys.size} chests, #{keys.count { |key| @own[2][key] }} of them opened") unless keys.empty?
  rescue => e
    log("showing own chests failed: #{e.class}: #{e.message}")
  end

  # Gives the player their own story back, keeping what of their own changed meanwhile.
  def self.restore
    kept = @keeps
    before = MGQ_MpStoryState.progress_text(MGQ_MpStoryState.data_of($game_variables))
    return_lent
    story = own_with_values
    MGQ_MpStoryState.set_raw(*story)
    log("back in the player's own story (#{@same ? 'kept what they played together, as far along' : (kept ? "kept the leader's story they caught up with" : 'unchanged, they were ahead')}): " \
        "played #{before}, now #{MGQ_MpStoryState.progress_text(story[1])}#{@partial ? ', without own values in the gaps of a story too large to send whole' : ''}")
    forget
    MGQ_MpOverworldSync.notice(kept ? "You are back in your own story, with what you played together." : "You are back in your own story.")
  end

  # Forgets the story kept aside, as when a save is loaded or a new game starts, which bring their
  # own story. A member then asks the leader again.
  def self.forget
    @own = nil
    @same = false
    @keeps = false
    @follow_place = nil
    @own_side = nil
    @leader_held = nil
    @asking = false
    @recorded = nil
    @borrowed = nil
    @lent = {}
    @leader_id = nil
    @waiting = false
    @partial = false
    @leader_story = nil
    @requests = nil
    @request_runs = []
  end

  # The story a save holds: the member's own while they play the leader's; in a Raid World the
  # story as it is, the world's laid over the player's own.
  #
  # @param contents [Hash] What the game saves.
  # @return [Hash] The same, with the member's own story.
  def self.save_contents(contents)
    return contents if !guest? || MGQ_MpCoop::Scope.raid?

    switches, variables, self_switches = own_with_values
    contents[:switches] = MGQ_MpStoryState.with_data(contents[:switches], switches)
    contents[:variables] = MGQ_MpStoryState.with_data(contents[:variables], variables)
    contents[:self_switches] = MGQ_MpStoryState.with_data(contents[:self_switches], self_switches)
    contents[:party] = without_lent(contents[:party]) if contents[:party]
    log("the save holds the player's own story at #{MGQ_MpStoryState.progress_text(variables)} instead of the leader's at #{MGQ_MpStoryState.progress_text(MGQ_MpStoryState.data_of($game_variables))}" \
        "#{(@lent || {}).empty? ? '' : ", without #{@lent.size} lent key items"}")
    contents
  end

  # The player's own story with their own values as they are now, see own_story. A player who keeps
  # nothing of the leader's story keeps their own side too, which the leader's after the Great
  # Decision replaced while they played it.
  #
  # @return [Array] The switches, variables and self switches.
  def self.own_with_values
    story = MGQ_MpStoryState.mix(own_story, MGQ_MpStoryState.raw_state)
    MGQ_MpStoryState::SIDE_SWITCHES.each { |id| story[0][id] = @own[0][id] } unless @keeps
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

  # The player's own story: the one kept aside while they play the leader's, else the one played.
  #
  # @return [Array, nil] The switches and the variables, nil before the game made them.
  def self.own_story_data
    return [@own[0], @own[1]] if guest?

    $game_switches && $game_variables ? [MGQ_MpStoryState.data_of($game_switches), MGQ_MpStoryState.data_of($game_variables)] : nil
  end

  # The player's own story kept aside while they play the leader's.
  #
  # @return [Array, nil] The switches, variables and self switches, nil while they play their own.
  def self.own_story_aside
    @own
  end

  # As member, has check_sync decide anew once the player accepted a leader's offer to sync the
  # story, which it then counts as synced, see MGQ_MpCoopChoices.offer_with?.
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
  MGQ_MpHooks.after(Game_Map, :update, "coop_story") { MGQ_MpCoopStory.update }
rescue => e
  MGQ_MpCoopStory.log("map hook FAILED: #{e.class}: #{e.message}")
end

# Game hooks of this script alone, through core_hooks.rbx.

begin
  MGQ_MpHooks.after(Game_Map, :setup, "coop_story") { |_map_id| MGQ_MpCoopStory.map_entered }
rescue => e
  MGQ_MpCoopStory.log("map setup hook FAILED: #{e.class}: #{e.message}")
end

begin
  MGQ_MpHooks.around(DataManager.singleton_class, :make_save_contents, "coop_story") do |_manager, _args, original|
    contents = original.call
    begin
      MGQ_MpCoopStory.save_contents(contents)
    rescue => e
      MGQ_MpCoopStory.log("save guard failed: #{e.class}: #{e.message}")
      contents
    end
  end

  # A loaded save brings its own story, so the player follows the leader's anew.
  MGQ_MpHooks.after(DataManager.singleton_class, :extract_save_contents, "coop_story") do |_contents|
    MGQ_MpCoopStory.log("a loaded save brings its own story, so the player follows the leader's anew") if MGQ_MpCoopStory.guest?
    MGQ_MpCoopStory.forget
  end

  # A new game brings its own story too.
  MGQ_MpHooks.after(DataManager.singleton_class, :create_game_objects, "coop_story") do
    MGQ_MpCoopStory.log("a new game brings its own story, so the player follows the leader's anew") if MGQ_MpCoopStory.guest?
    MGQ_MpCoopStory.forget
  end
rescue => e
  MGQ_MpCoopStory.log("save hooks FAILED: #{e.class}: #{e.message}")
end
