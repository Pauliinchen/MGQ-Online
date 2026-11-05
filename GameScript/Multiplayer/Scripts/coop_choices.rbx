#----------------------------------------------------------------
#  coop_choices.rbx
#
#  Changelog:
#      Paulinchen  2026-11-05: Caught a Classic member up again once they answered a choice the leader's story is past
#                            - Asked the DLL the route of the leader's story an offer brings the player to
#                            - Read the story's ids from story_ids.rbx
#                            - Left the self switches of the Navy's and the Pirates' lines to the reviewed key list
#                            - Counted the offers' times by the bridge's frame
#      Paulinchen  2026-11-01: Kept a screen the Mod Framework refused or lost waiting, telling the player only an offer gone
#                            - Built the screens of the choices and of a replay's question on the Mod Framework's windows
#                            - Put off a number, a choice without cancel and a choice of the player's own on cancel
#                            - Filled in the names and variables of a replayed choice's labels
#                            - Sent away the companions an outcome sends away on the player's playthrough
#      Paulinchen  2026-10-31: Read the keys and the mouse through the Mod Framework
#                            - Asked the player the question a replay waits on
#                            - Asked a number, a key item or a present a replay waits on, on a screen of its own
#                            - Left every choice a stream hands the run of to the replay
#      Paulinchen  2026-10-28: Asked the DLL for the choices, their outcomes and which keys are the player's own
#                            - Read the Final Chapter's rewards from the catch-up tables the DLL holds
#      Paulinchen  2026-10-14: Added the Navy or the Pirates as each player's own choice, with its ship and its line's self switches
#                            - Asked a save past a choice a later build added once the world's first story came
#      Paulinchen  2026-10-11: Dropped Amira's choice in Iliasburg
#      Paulinchen  2026-10-10: Forgot the waiting choices and route once the world closes
#      Paulinchen  2026-10-09: Read the story and the roster and brought companions through story_state.rbx
#                            - Forgot the waiting choices when a new game starts
#      Paulinchen  2026-10-08: Left drawing and turning the switches to Window_MpWorldForm
#                            - Kept every choice's outcome each player's own in a Raid World
#                            - Offered only the routes a Raid World may still take at the Great Decision
#                            - Offered no story sync in a Raid World
#      Paulinchen  2026-10-07: Created
#
#----------------------------------------------------------------

# The story's choices a member makes for themselves, whatever the leader chose: their outcome's
# switches and variables stay out of the leader's story the member plays, and the companions it
# brings join them, never the leader's. A party's leader offers a member behind them to bring their
# story up to the leader's ("Sync story"), and the member picks on one screen every choice the
# catch-up carries them past. The same screen asks a member their own outcome of each choice the
# leader's story passes, and in a Raid World each choice the world's story passes. The choices,
# their outcomes and the rules are the DLL's (MGQOnline.Game's Story/Choices, behind the topics of
# ChoiceTopics); this script reads the game, writes the outcomes and shows the screen. A choice the
# save's log covers is asked while the run is replayed in the player's game instead (ask_input,
# with a number, a key item and a present), so only history from before the log gets the frozen
# outcomes here. Both screens are Mod Framework windows in a menu scene of their own (Screen and
# Question below), which the game's cancel button closes.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpCoopChoices
  # The DLL's topics of the choices, see ChoiceTopics in MGQOnline.Game.
  PASSED_TOPIC = "choices.passed"
  PROMPTS_TOPIC = "choices.prompts"
  MISSED_TOPIC = "choices.missed"
  OFFERED_TOPIC = "choices.offered"
  ENDINGS_TOPIC = "choices.endings"
  NOTE_TOPIC = "choices.note"
  OUTCOME_TOPIC = "choices.outcome"
  PERSONAL_TOPIC = "choices.personal"
  SKIP_TOPIC = "choices.skip"
  OFFER_REFUSAL_TOPIC = "choices.offer_refusal"
  LAPSED_TOPIC = "choices.lapsed"
  TABLE_TOPIC = "choices.table"
  INPUT_OPEN_TOPIC = "choices.input_open"

  # The choice of Alice or Ilias, which the party's story chooses, and the Great Decision.
  SIDE = :side
  DECISION = :decision

  # What the routes are called, by the Great Decision's outcome.
  ROUTE_NAMES = ["Angelic Dominion", "Monster Realm", "Chaos"]

  # The table while the DLL has not handed it: no choices, nothing read.
  NO_TABLE = { "branches" => [], "reads" => { "s" => [], "v" => [], "roster" => [] }, "decision" => [], "offer_frames" => 3600 }

  # What the screen offers while the DLL does not answer: nothing.
  NO_OFFER = { "labels" => [], "outcomes" => [] }

  # The keys that are the player's own while the DLL does not answer: none.
  NO_PERSONAL = { "s" => [], "v" => [] }

  # The speaker's code at the start of a message: \n<Name>, or 【Name】 in the untranslated game.
  SPEAKER = /\A(?:\\n<(.+?)>|【(.+?)】)/

  # The framework's interface the screens are built of.
  UI = Mod_Framework::UI

  # The most width of the screens, which leave 32 pixels at either side on a narrower screen.
  MOST_WIDTH = 480

  # The room the screens leave above and below them, together.
  SCREEN_ROOM = 16

  # Color of the offer in the notification box and the World overview.
  OFFER_COLOR = MGQ_MpActions::LINE_COLOR

  # The leader's standing offers: by the member's id, the offer's number, its start frame and name.
  @offers = {}
  # The choices waiting for the player to pick their own outcome, in the order they came.
  @prompts = []
  # The leader's offer the player accepted, until the leader's whole story came.
  @accepted = nil
  # The screen waiting to show, see show_screen.
  @screen = nil
  # The commands of the Great Decision's outcome waiting to play once the player is free.
  @queued = nil
  # The number of the leader's latest offer.
  @nonce = 0
  # The route a Raid World took at the Great Decision, waiting for the player to confirm it.
  @raid_route = nil
  # The table the DLL handed, see table.
  @table = nil
  # The keys the DLL named the player's own, with the request they answer, see personal_keys.
  @personal = nil
  # The question a replay waits on, see ask_input; nil for none.
  @question = nil
  # Whether the player put the choice of their own outcome off until they next stand free.
  @prompts_later = false

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "co-op choices"

  # What the scripts read of the choices, handed by the DLL once: each choice's key, title, point
  # and hint, the switches, variables and companions the rules read, and the Great Decision's
  # outcomes.
  #
  # @return [Hash] The table, see ChoiceTopics.Table; NO_TABLE while the DLL does not answer.
  def self.table
    @table ||= MGQ_Multiplayer::Bridge.call(TABLE_TOPIC)
    @table || NO_TABLE
  end

  # Lists the choices, in story order.
  #
  # @return [Array<Symbol>] Their names.
  def self.keys
    table["branches"].map { |entry| entry[0].to_sym }
  end

  # Finds a choice by its name.
  #
  # @param key [Symbol] Its name.
  # @return [Array, nil] Its key, title, point and hint; nil for none.
  def self.branch(key)
    table["branches"].find { |entry| entry[0] == key.to_s }
  end

  # Tells the main story's progress from which a choice can be made.
  #
  # @param key [Symbol] The choice.
  # @return [Integer] The progress.
  def self.point_of(key)
    found = branch(key)
    found ? found[2] : 0
  end

  # Reads the values of a story the rules read, as the DLL's requests carry them.
  #
  # @param switches [Array] The story's switches.
  # @param variables [Array] The story's variables.
  # @param roster [Array<Integer>] The player's companions.
  # @return [Hash] "s", the switches read that are on; "v", each variable read with its value;
  #   "roster", the companions read that are in the roster.
  def self.values_of(switches, variables, roster)
    reads = table["reads"]
    { "s" => reads["s"].select { |id| switches[id] }, "v" => reads["v"].map { |id| [id, variables[id].to_i] }, "roster" => reads["roster"] & roster }
  end

  # Reads the values of the story played.
  #
  # @return [Hash] The values, see values_of.
  def self.story_values
    values_of(MGQ_MpStoryState.data_of($game_switches), MGQ_MpStoryState.data_of($game_variables), MGQ_MpStoryState.roster_ids)
  end

  # Writes what the rules read of the game beside the story played: whether a Raid World is open,
  # the install's endings, the route a Raid World took and the routes it may still take.
  #
  # @param fields [Hash] What the request names besides.
  # @return [Hash] The request.
  def self.context(fields = {})
    switches = defined?($game_system_switches) ? $game_system_switches : nil
    { "raid" => raid?, "values" => story_values, "ends" => [switches && switches[:ed1] ? true : false, switches && switches[:ed2] ? true : false],
      "raid_route" => @raid_route, "world_routes" => defined?(MGQ_MpWorldStory) ? MGQ_MpWorldStory.decision_routes : nil }.merge(fields)
  end

  # Writes the answers given so far as a request carries them.
  #
  # @param answers [Hash{Symbol => Integer}] The answers.
  # @return [Hash{String => Integer}] The answers.
  def self.answers_text(answers)
    Hash[answers.map { |key, index| [key.to_s, index] }]
  end

  # Reads where the stream that hands the player runs began: in a Raid World where the world's log
  # starts, in a Classic party where the player started keeping the leader's story. A choice up to
  # it is history no run hands over, which alone this screen asks and gives its frozen outcome; the
  # replay of a run asks every later one.
  #
  # @return [Array<Integer>, nil] The place's markers, nil for none.
  def self.start_place
    if raid?
      world = defined?(MGQ_MpWorldStory) ? MGQ_MpWorldStory.world : nil
      world ? world["start"] : nil
    else
      defined?(MGQ_MpCoopStory) && MGQ_MpCoopStory.respond_to?(:follow_place) ? MGQ_MpCoopStory.follow_place : nil
    end
  end

  # Lists the choices a catch-up from one point of the main story to another carries the player
  # past, which they have not made in their own story and no stream hands the run of.
  #
  # @param from [Integer] The player's main story progress.
  # @param to [Integer] The progress they are brought to.
  # @param switches [Array] The player's own switches.
  # @param variables [Array] The player's own variables.
  # @param roster [Array<Integer>] The player's companions.
  # @return [Array<Symbol>] The choices, in story order.
  def self.passed(from, to, switches, variables, roster)
    request = { "from" => from, "to" => to, "values" => values_of(switches, variables, roster), "start" => start_place }
    Array(MGQ_Multiplayer::Bridge.call(PASSED_TOPIC, request)).map { |key| key.to_sym }
  end

  # Reports whether the player's own save cleared both endings, which the third way of the Great
  # Decision asks, as the game's own event does; in a Raid World whether the world cleared both
  # routes, by its clear switches.
  #
  # @return [Boolean] Whether it did.
  def self.both_endings?
    MGQ_Multiplayer::Bridge.call(ENDINGS_TOPIC, context) ? true : false
  rescue
    false
  end

  # Asks the DLL what the screen offers for a choice.
  #
  # @param key [Symbol] The choice.
  # @return [Hash] "labels", the outcomes' labels, and "outcomes", each one's place in the
  #   choice's outcomes; NO_OFFER while the DLL does not answer.
  def self.offered(key)
    MGQ_Multiplayer::Bridge.call(OFFERED_TOPIC, context("key" => key.to_s)) || NO_OFFER
  end

  # Lists the outcomes the screen offers for a choice: the third way only with both endings cleared;
  # in a Raid World the routes the world may still take.
  #
  # @param key [Symbol] The choice.
  # @return [Array<String>] The outcomes' labels.
  def self.labels(key)
    offered(key)["labels"]
  end

  # Reports whether the open world is a Raid World, see MGQ_MpCoop::Scope.
  #
  # @return [Boolean] Whether it is.
  def self.raid?
    MGQ_MpCoop::Scope.raid?
  end

  # Writes what an outcome brings, for the screen's line below it.
  #
  # @param key [Symbol] The choice.
  # @param index [Integer] The outcome.
  # @param answers [Hash{Symbol => Integer}] The answers given so far.
  # @param leader_route [Integer, nil] The leader's route, its place in the routes, nil before the Great Decision.
  # @param leader_name [String] The leader's name.
  # @return [String] The line.
  def self.note(key, index, answers, leader_route = nil, leader_name = "the leader")
    MGQ_Multiplayer::Bridge.call(NOTE_TOPIC, context("key" => key.to_s, "index" => index, "answers" => answers_text(answers), "route" => leader_route, "leader" => leader_name)).to_s
  end

  # The keys the DLL names the player's own as choices' outcomes, asked once per request: in a Raid
  # World every choice's, while a Classic party's member plays the leader's story those of the
  # choices their own story made.
  #
  # @return [Hash] "s" and "v", the switches and variables by id.
  def self.personal_keys
    own = !raid? && MGQ_MpCoopStory.guest? ? MGQ_MpCoopStory.own_story_data : nil
    request = { "raid" => raid?, "own" => own ? values_of(own[0], own[1], []) : nil }
    return @personal[1] if @personal && @personal[0] == request

    answer = MGQ_Multiplayer::Bridge.call(PERSONAL_TOPIC, request) || NO_PERSONAL
    keys = { "s" => Hash[answer["s"].map { |id| [id, true] }], "v" => Hash[answer["v"].map { |id| [id, true] }] }
    @personal = [request, keys]
    keys
  end

  # Reports whether a switch or a variable is the player's own as a choice's outcome, while they
  # play the leader's story; never for the leader, whose story the members get. In a Raid World every
  # choice's outcome is each player's own.
  #
  # @param kind [Symbol] :s for a switch, :v for a variable.
  # @param id [Integer] The switch or variable.
  # @return [Boolean] Whether it is.
  def self.personal?(kind, id)
    personal_keys[kind == :s ? "s" : "v"].key?(id)
  rescue
    false
  end

  # Tells why the catch-up leaves out a reward: a choice's companion, which comes with the member's
  # own outcome, or one only another route's Final Chapter gives a member who starts their own.
  #
  # @param kind [Symbol] :skills, :actors or :items.
  # @param id [Integer, String] The reward.
  # @return [String, nil] The reason, nil to give it.
  def self.skip_reason(kind, id)
    reason = MGQ_Multiplayer::Bridge.call(SKIP_TOPIC, "kind" => kind.to_s, "id" => id)
    return reason if reason
    rewards = @accepted && @accepted[:other_route] ? MGQ_MpStoryState.rewards : nil
    return nil unless rewards

    rewards.final[kind].include?(id) ? "only the leader's route gives it, and the player starts another" : nil
  end

  # Gives the player a choice's outcome in the story they play: its switches and variables, the
  # values it raises and the self switches it turns on, also in their own story kept aside, the
  # companions it sends away and brings, and the ship it puts on the field. In a Raid World the
  # catch-up then follows the outcome as a story carrying the player past it, so its items and return
  # point come; in a Classic party a member who catches up with the leader's story gets the rows that
  # waited for their outcome.
  #
  # @param key [Symbol] The choice.
  # @param index [Integer] The answer, its place among the labels offered.
  # @param answers [Hash{Symbol => Integer}] Every answer given, Magistea Village's among them.
  def self.apply(key, index, answers = {})
    outcome = MGQ_Multiplayer::Bridge.call(OUTCOME_TOPIC, context("key" => key.to_s, "index" => index, "answers" => answers_text(answers), "start" => start_place))
    return log("the DLL did not answer the outcome of #{key}") unless outcome
    return MGQ_MpCoopStory.choose_side(outcome["side"].to_sym) if key == SIDE

    @personal = nil
    before = MGQ_MpStoryState.deep_copy(MGQ_MpStoryState.raw_state)
    switches = MGQ_MpStoryState.data_of($game_switches)
    variables = MGQ_MpStoryState.data_of($game_variables)
    own = MGQ_MpCoopStory.own_story_aside
    written = []
    outcome["switches"].each do |id, value|
      written << "s#{id} #{switches[id] ? 'on' : 'off'} -> #{value ? 'on' : 'off'}"
      switches[id] = value
      own[0][id] = value if own
    end
    outcome["variables"].each do |id, value|
      written << "v#{id} #{variables[id].to_i} -> #{value}"
      variables[id] = value
      own[1][id] = value if own
    end
    outcome["least"].each do |id, value|
      next if variables[id].to_i >= value

      written << "v#{id} #{variables[id].to_i} -> #{value}"
      variables[id] = value
      own[1][id] = value if own
    end
    outcome["self_switches"].each do |self_key|
      written << "ss#{self_key.join('.')} on"
      $game_self_switches[self_key] = true
      own[2][self_key] = true if own
    end
    $game_map.need_refresh = true if $game_map
    log("#{outcome['title']}: the player's own outcome \"#{outcome['label']}\": #{written.join(', ')}")
    Array(outcome["leaves"]).each { |id| send_away(id) }
    outcome["joins"].each do |id|
      name = MGQ_MpStoryState.bring(id)
      MGQ_MpOverworldSync.notice("#{name} joined you.") if name
    end
    place_ship(outcome["ship"]) if outcome["ship"]
    return MGQ_MpWorldCatchup.carried(before) if raid? && defined?(MGQ_MpWorldCatchup)

    MGQ_MpCoopStory.choice_answered unless raid?
  end

  # Sends away a companion an outcome sends away, as the game's own branch does.
  #
  # @param id [Integer] The companion.
  def self.send_away(id)
    return unless MGQ_MpStoryState.in_roster?(id)

    $game_party.remove_actor(id)
    log("#{MGQ_MpStoryState.actor_label(id)} left the player's roster: the outcome sends them away")
    MGQ_MpOverworldSync.notice("#{$data_actors[id].name} left you.")
  end

  # Puts the ship an outcome gives where the game's own event of that side leaves it, unless the
  # player rides it.
  #
  # @param place [Array<Integer>] The map, x and y.
  def self.place_ship(place)
    ship = $game_map.vehicle(:ship)
    return unless ship && !$game_player.vehicle.equal?(ship)

    ship.set_location(*place)
    log("put the ship on map #{place[0]} (#{place[1]},#{place[2]}), where the player's side leaves it")
  end

  # The fields the choices add to the state the player's game tells the others: the members the
  # player, as leader, offers to bring their story up to theirs.
  #
  # @return [Hash] "ssoffer": each member's id and the offer's number, comma separated.
  def self.state_fields
    { "ssoffer" => @offers.map { |id, offer| "#{id}:#{offer[:nonce]}" }.join(",") }
  end

  # As leader, offers a member to bring their story up to the player's.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  def self.offer(peer)
    @nonce += 1
    @offers[peer.state["id"].to_s] = { :nonce => @nonce, :since => MGQ_Multiplayer::Bridge.frame_number, :name => peer.state["name"].to_s }
    log("offered #{MGQ_MpOverworldSync.who(peer)} to bring their story (#{MGQ_MpCoopStory.markers_text(MGQ_MpCoopStory.read_markers(peer.state['sm']))}) " \
        "up to the player's (#{MGQ_MpCoopStory.markers_text(MGQ_MpCoopStory.own_markers)}), offer #{@nonce}")
    MGQ_MpOverworldSync.notice("You offered #{peer.state['name']} to sync their story with yours.")
  end

  # As leader, takes back an offer.
  #
  # @param id [String] The member's id.
  # @param reason [String] Why, for the log.
  def self.drop_offer(id, reason)
    offer = @offers.delete(id)
    log("took back the story sync offered to #{offer[:name]}: #{reason}") if offer
  end

  # Reports whether a member's story is behind the player's, which only an offer may bring up: no
  # progress beyond the player's, some behind it, and not following the player's story yet.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @return [String, nil] Why no offer is possible, nil when it is.
  def self.offer_refusal(peer)
    request = { "name" => peer.state["name"].to_s, "theirs" => MGQ_MpCoopStory.read_markers(peer.state["sm"]), "own" => MGQ_MpCoopStory.own_markers,
                "follows" => peer.state["ssync"].to_s == MGQ_MpOverworldSync::Me.id.to_s }
    MGQ_Multiplayer::Bridge.call(OFFER_REFUSAL_TOPIC, request)
  end

  # As leader, takes back the offers that no longer stand: to a player who left the party, follows
  # the player's story now, or let it run out. Called after the map's update.
  def self.tick_offers
    return @offers.clear if @offers.any? && MGQ_MpCoop.party_leader != :me
    return if @offers.empty?

    members = MGQ_MpCoop::Party.members
    lapsed = Array(MGQ_Multiplayer::Bridge.call(LAPSED_TOPIC, "now" => MGQ_Multiplayer::Bridge.frame_number, "since" => @offers.map { |id, offer| [id, offer[:since]] }))
    @offers.keys.each do |id|
      member = members.find { |peer| peer.state["id"].to_s == id }
      next drop_offer(id, "they left the party") unless member
      next drop_offer(id, "they follow the player's story now") if member.state["ssync"].to_s == MGQ_MpOverworldSync::Me.id.to_s
      next drop_offer(id, "nobody answered in #{table['offer_frames'] / 60} s") if lapsed.include?(id)
    end
  end

  # Reads the offer of a player, as their state tells it, when it is for the player.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  # @return [String, nil] The offer's number, nil for no offer.
  def self.offer_of(peer)
    return nil unless MGQ_MpCoop.party_leader.equal?(peer)

    me = MGQ_MpOverworldSync::Me.id.to_s
    entry = peer.state["ssoffer"].to_s.split(",").find { |part| part.split(":", 2)[0] == me }
    entry ? entry.split(":", 2)[1].to_s : nil
  end

  # As member, accepts the leader's offer: shows the screen of the choices the catch-up carries the
  # player past.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The leader.
  def self.accept(peer)
    own = MGQ_MpCoopStory.own_markers
    theirs = MGQ_MpCoopStory.read_markers(peer.state["sm"])
    unless theirs && own.each_with_index.all? { |value, index| value <= theirs[index] } && own != theirs
      log("accepted #{MGQ_MpOverworldSync.who(peer)}'s offer, but the player is not behind them (own #{MGQ_MpCoopStory.markers_text(own)}, theirs #{MGQ_MpCoopStory.markers_text(theirs)})")
      return MGQ_MpOverworldSync.notice("Your story is not behind #{peer.state['name']}'s.")
    end

    keys = passed(own[0], theirs[0], MGQ_MpStoryState.data_of($game_switches), MGQ_MpStoryState.data_of($game_variables), MGQ_MpStoryState.roster_ids)
    log("accepted #{MGQ_MpOverworldSync.who(peer)}'s offer: own #{MGQ_MpCoopStory.markers_text(own)}, theirs #{MGQ_MpCoopStory.markers_text(theirs)}; " \
        "choices to make: #{keys.empty? ? 'none' : keys.join(', ')}")
    sync = MGQ_MpCoopStory.sync_of(own, theirs)
    route = sync ? sync["route"] : nil
    show_screen("Sync story with #{peer.state['name']}", keys, ["Bring me there", "Cancel"], peer, route,
                lambda { |answers| confirm_offer(peer, theirs, route, answers) }, lambda { valid_offer?(peer) })
  end

  # As member, declines the leader's offer and tells the leader.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The leader.
  def self.decline(peer)
    log("declined #{MGQ_MpOverworldSync.who(peer)}'s offer to sync the story")
    MGQ_MpCoop.tell(peer.seat, "choices", "declined", {})
  end

  # Reports whether the leader's offer still stands while the screen shows it.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @return [String, nil] Why it no longer does, nil while it does.
  def self.valid_offer?(peer)
    return "#{peer.state['name']} no longer leads your party." unless MGQ_MpCoop.party_leader.equal?(peer)
    return "#{peer.state['name']} took the offer back." unless offer_of(peer)

    nil
  end

  # As member, brings the player's story up to the leader's with the answers given: the choices'
  # outcomes in their own story first, then the leader's whole story, which they then keep.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The leader.
  # @param theirs [Array<Integer>] How far the leader's story is.
  # @param route [Integer, nil] The leader's route, nil before the Great Decision.
  # @param answers [Hash{Symbol => Integer}] The answers.
  def self.confirm_offer(peer, theirs, route, answers)
    decision = answers[DECISION]
    other = !decision.nil? && decision != route
    @accepted = { :with => peer.state["id"].to_s, :decision => decision, :other_route => other }
    log("bringing the player's story up to #{MGQ_MpOverworldSync.who(peer)}'s (#{MGQ_MpCoopStory.markers_text(theirs)})" \
        "#{decision ? ", the Great Decision: #{labels(DECISION)[decision]}#{other ? ', another route than theirs' : ', their route'}" : ''}")
    (answers.keys & keys - [DECISION]).sort_by { |key| point_of(key) }.each { |key| apply(key, answers[key], answers) }
    MGQ_MpCoopStory.start_offer(peer)
  end

  # Reports whether the player accepted an offer of a leader, whose story they then follow before
  # any other rule says so.
  #
  # @param id [String] The leader's id.
  # @return [Boolean] Whether they did.
  def self.offer_with?(id)
    @accepted && @accepted[:with] == id ? true : false
  end

  # As member, finishes an accepted offer once the leader's whole story came and the catch-up gave
  # what it brings: one who took another side of the Great Decision than the leader then starts their
  # own route. Called after the whole story was borrowed.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The leader.
  def self.borrowed(peer)
    return unless @accepted && @accepted[:with] == peer.state["id"].to_s

    accepted = @accepted
    @accepted = nil
    log("the player's story is up to #{MGQ_MpOverworldSync.who(peer)}'s now")
    return unless accepted[:other_route]

    start_route(accepted[:decision], peer)
  end

  # Starts the route of the Great Decision's outcome the player took, which is not the leader's:
  # they keep the leader's story up to the Great Decision, and play the decision's outcome as the
  # game's own event does, from where it puts a player, on their own.
  #
  # @param index [Integer] The outcome.
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The leader.
  def self.start_route(index, peer)
    variables = MGQ_MpStoryState.data_of($game_variables)
    # The kept story must not tell the leader's route, or the player would follow it again at once.
    ids = MGQ_MpStoryIds
    variables[ids.main_progress] = ids.before_decision
    ([ids.decision_progress] + ids.route_variables).each { |id| variables[id] = 0 }
    MGQ_MpCoopStory.keep_and_leave("the player starts the #{ROUTE_NAMES[index]} route, not #{peer.state['name']}'s")
    @queued = decision_commands(index)
    log("the Great Decision's outcome \"#{labels(DECISION)[index]}\" waits to play once the player is free: #{@queued.size} commands")
    MGQ_MpOverworldSync.notice("You start your own route. Each of you plays your own story.")
  end

  # Builds the commands that play the Great Decision's outcome: the Final Chapter put back as the
  # game's own reset does, the outcome's part of the Great Decision's common event, which changes
  # the party and takes the player to its map, with the side and the route set on the way.
  #
  # @param index [Integer] The outcome: 0 the Dark Goddess, 1 the Goddess Ilias, 2 the third way.
  # @return [Array<RPG::EventCommand>] The commands.
  def self.decision_commands(index)
    ids = MGQ_MpStoryIds
    commands = [RPG::EventCommand.new(117, 0, [ids.final_reset_event]), RPG::EventCommand.new(122, 0, [ids.decision_progress, ids.decision_progress, 0, 0, 0])]
    outcome = table["decision"][index] || {}
    routes = ids.route_variables
    if index == 2
      [7091, 7092, 92].each { |id| commands << RPG::EventCommand.new(121, 0, [id, id, 0]) }
      commands << RPG::EventCommand.new(122, 0, [ids.main_progress, ids.main_progress, 0, 0, ids.great_decision])
      commands << RPG::EventCommand.new(122, 0, [routes[2], routes[2], 0, 0, 1])
      commands << RPG::EventCommand.new(201, 0, [0] + ids.chaos_start + [2])
      return commands << RPG::EventCommand.new(0, 0, [])
    end

    part = decision_part(outcome)
    transfer = part.pop || RPG::EventCommand.new(201, 0, [0, outcome["map"], 25, 19, 8, 2])
    commands.concat(part)
    ids.side_switches.each { |id| commands << RPG::EventCommand.new(121, 0, [id, id, id == outcome["side"] ? 0 : 1]) }
    commands << RPG::EventCommand.new(122, 0, [routes[index], routes[index], 0, 0, 1])
    commands << transfer
    commands << RPG::EventCommand.new(0, 0, [])
  end

  # Builds the commands that play the player's own half of the route a Raid World took at the Great
  # Decision, whose global half the world's story brings: the outcome's part of common event 380
  # without its transfer, which changes the companions when the player's side differs, then the side,
  # and the screen faded in again, which that part fades out. The third way changes nothing of the
  # player's own.
  #
  # @param index [Integer] The outcome: 0 the Dark Goddess, 1 the Goddess Ilias, 2 the third way.
  # @return [Array<RPG::EventCommand>] The commands, none for the third way.
  def self.raid_decision_commands(index)
    outcome = table["decision"][index] || {}
    return [] unless outcome["return"]

    commands = decision_part(outcome)
    commands.pop if commands.last && commands.last.code == 201
    MGQ_MpStoryIds.side_switches.each { |id| commands << RPG::EventCommand.new(121, 0, [id, id, id == outcome["side"] ? 0 : 1]) }
    commands << RPG::EventCommand.new(222, 0, [])
    commands << RPG::EventCommand.new(0, 0, [])
  end

  # Copies the part of the Great Decision's common event that plays an outcome: from where it notes
  # where a game over returns the player to the transfer to the outcome's map, moved to the left so
  # it runs on its own.
  #
  # @param outcome [Hash] The outcome: "return" and "map".
  # @return [Array<RPG::EventCommand>] The commands, the transfer last; none when the game's event
  #   differs.
  def self.decision_part(outcome)
    event = $data_common_events[MGQ_MpStoryIds.decision_event]
    list = (event && event.list) || []
    back = MGQ_MpStoryIds.game_over_return
    first = list.index { |command| command.code == 122 && command.parameters[0, 5] == [back, back, 0, 0, outcome["return"]] }
    last = first && (first...list.size).find { |at| list[at].code == 201 && list[at].parameters[1] == outcome["map"] }
    unless first && last
      log("the Great Decision's event differs from the one known, so its outcome plays without its party changes")
      return [RPG::EventCommand.new(122, 0, [back, back, 0, 0, outcome["return"].to_i])]
    end

    base = list[first].indent
    list[first..last].map { |command| RPG::EventCommand.new(command.code, [command.indent - base, 0].max, command.parameters) }
  end

  # Lists the choices a part of the leader's story the player plays carries them past, which they
  # made neither in their own story nor here, to ask their own outcome. Called once the player
  # catches up, and whenever the leader's story moves on; in a Raid World whenever the world's
  # story does.
  #
  # @param from [Integer] The main story's progress before.
  # @param to [Integer] The progress after.
  # @param changed [Array<Integer>] The switches and variables that changed, besides.
  def self.story_passed(from, to, changed = [])
    return if @accepted

    story = MGQ_MpCoopStory.own_story_data
    return unless story

    request = { "from" => from, "to" => to, "changed" => changed, "raid" => raid?, "values" => values_of(story[0], story[1], MGQ_MpStoryState.roster_ids),
                "waiting" => @prompts.map { |key| key.to_s }, "start" => start_place }
    keys = Array(MGQ_Multiplayer::Bridge.call(PROMPTS_TOPIC, request)).map { |key| key.to_sym }
    return if keys.empty?

    @prompts.concat(keys)
    log("the #{raid? ? 'world' : 'leader'}'s story passed #{keys.join(', ')} (main story #{from} -> #{to}), whose own outcome the player picks once free")
  end

  # Asks the player the choices a later build added that a Raid World's story is past while their
  # own save never made them, since no story moves them past those again. Called with the first
  # world's story laid over theirs after entering, a load or a new game.
  #
  # @param progress [Integer] The main story's progress of the story laid over theirs.
  def self.missed(progress)
    return unless raid?

    request = { "progress" => progress, "raid" => true, "values" => story_values, "waiting" => @prompts.map { |key| key.to_s }, "start" => start_place }
    keys = Array(MGQ_Multiplayer::Bridge.call(MISSED_TOPIC, request)).map { |key| key.to_sym }
    return if keys.empty?

    @prompts.concat(keys)
    log("the player's save is past #{keys.join(', ')} without its own outcome, which the player picks once free")
  rescue => e
    log("looking for the choices the save missed failed: #{e.class}: #{e.message}")
  end

  # Asks the player at the Great Decision once a Raid World's story carried them past it: the screen
  # offers the route the world took alone, whose own half plays once confirmed.
  #
  # @param index [Integer] The world's route, its place in the routes.
  def self.raid_decision(index)
    @raid_route = index
    @prompts << DECISION unless @prompts.include?(DECISION)
    log("the world's story took the #{labels(DECISION).first} route at the Great Decision, which the player confirms once free")
  end

  # Shows the screen of the next choice the player picks their own outcome of, once they are free
  # on the map, and plays the Great Decision's outcome waiting. Called after the map's update.
  def self.update
    tick_offers
    play_queued
    free = MGQ_MpOverworldSync.map_free? && SceneManager.scene.class == Scene_Map
    left_free unless free
    return unless free

    return show_question if @question
    return if @prompts.empty? || @prompts_later

    unless raid? || MGQ_MpCoopStory.follows_leader?
      log("forgot the choices #{@prompts.join(', ')} the player was to pick: they no longer follow the leader's story")
      return @prompts.clear
    end

    key = @prompts.first
    lead = MGQ_MpCoop.party_leader
    title = key == DECISION && raid? ? "The world's route" : "Your own outcome"
    show_screen(title, [key], ["Confirm"], lead, nil, lambda { |answers| answered_prompt(key, answers) }, nil)
  rescue => e
    log("updating the choices failed: #{e.class}: #{e.message}")
  end

  # Opens the screen of the question a replay waits on, once; one the DLL does not open waits as
  # one put off does.
  def self.show_question
    return if @question[:shown]

    @question[:shown] = true
    input = open_question
    return Question.open(@question, input) if input

    @question[:later] = true
    log("the DLL did not open the #{@question[:kind]} a replay asks: it is asked again once the player stands free after a message, menu, battle or transfer")
  end

  # Keeps the question shown closed until the player leaves standing free on the map and comes
  # back, as cancel closes the screen of a number or a choice without cancel, whose game window
  # has none.
  def self.put_off_question
    @question[:later] = true
    log("the player closed the #{@question[:kind]} a replay asks: it opens again once they stand free after a message, menu, battle or transfer")
  end

  # Keeps the choice of the player's own outcome closed until they leave standing free on the map
  # and come back, as cancel closes its screen.
  def self.put_off_prompt
    @prompts_later = true
    log("the player closed the choice of their own outcome: it opens again once they stand free after a message, menu, battle or transfer")
  end

  # Lets a question or a choice put off open again, as the player left standing free on the map.
  # Called by update and as the map's scene ends.
  def self.left_free
    @question.merge!(:later => false, :shown => false) if @question && @question[:later]
    @prompts_later = false
  end

  # Takes the player's own outcome of a choice the leader's story passed.
  #
  # @param key [Symbol] The choice.
  # @param answers [Hash{Symbol => Integer}] The answer.
  def self.answered_prompt(key, answers)
    @prompts.delete(key)
    return unless answers.key?(key)
    return take_raid_decision(answers[key]) if key == DECISION && raid?

    apply(key, answers[key], answers)
  end

  # Plays the player's own half of the route a Raid World took at the Great Decision, once free.
  #
  # @param place [Integer] The outcome's place among those the screen offered.
  def self.take_raid_decision(place)
    index = offered(DECISION)["outcomes"][place.to_i]
    @raid_route = nil
    return unless index

    commands = raid_decision_commands(index)
    log("the Great Decision of the world: the #{ROUTE_NAMES[index]} route, #{commands.empty? ? 'nothing of the player\'s own changes' : "the player's own half waits to play once free: #{commands.size} commands"}")
    @queued = commands unless commands.empty?
  end

  # Plays the Great Decision's outcome that waits, once the player is free on the map.
  def self.play_queued
    return unless @queued && MGQ_MpOverworldSync.map_free? && $game_map

    commands = @queued
    @queued = nil
    log("playing the Great Decision's outcome now: #{commands.map { |command| command.code }.join(' ')}")
    $game_map.interpreter.setup(commands, 0)
  end

  # Asks the player the choice a replay waits on, with its own labels and the message's last lines.
  #
  # @param opener [String, nil] Who ran the event, nil for the player's own history.
  # @param lines [Array<String>] The message's lines.
  # @param labels [Array<String>] The answers' labels.
  # @param done [Proc] Takes the place of the answer picked.
  # @param cancel [Integer, nil] The place cancel answers, the labels' size for the choice's own
  #   branch; nil where the choice cannot be cancelled, which cancel then puts off.
  def self.ask(opener, lines, labels, done, cancel = nil)
    ask_input(opener, lines, "choice", { "labels" => labels, "cancel" => cancel }, done)
  end

  # Asks the player the input a replay waits on, as the game's own window for it would, on the
  # screen of the question once they stand free on the map. The game's cancel answers what the
  # game's window answers on cancel, and puts off a number and a choice without cancel, see
  # put_off_question.
  #
  # @param opener [String, nil] Who ran the event, nil for the player's own history.
  # @param lines [Array<String>] The message's lines, the speaker's code first.
  # @param kind [String] "choice", "number", "item" or "present".
  # @param spec [Hash] By kind: "labels" and "cancel" (the place cancel answers, the labels' size
  #   for the choice's own branch; nil where it cannot be cancelled); "digits" and "value"; "items"
  #   ([id, name, count] each); for a present also "actor" and "result" (the game's line of the
  #   last present). A list's "index" is the row it starts on, 0 when left out.
  # @param done [Proc] Takes the answer: the place of the label, the number, or the item (0 for none).
  def self.ask_input(opener, lines, kind, spec, done)
    @question = { :opener => opener, :lines => lines, :kind => kind, :spec => spec, :done => done, :place => $game_map ? $game_map.display_name.to_s : "" }
    log("a replay asks the player #{kind == 'choice' ? "\"#{spec['labels'].join(' / ')}\"" : "for a #{kind}"}, once they are free")
  end

  # The question a replay waits on.
  #
  # @return [Hash, nil] The question, see ask_input, with :input once the DLL opened it; nil for none.
  def self.question
    @question
  end

  # Splits the speaker off a message's lines.
  #
  # @param lines [Array<String>] The lines.
  # @return [Array] The speaker's name, nil for none, and the lines without the speaker's code.
  def self.speaker_of(lines)
    first = lines.first.to_s
    found = first.match(SPEAKER)
    return [nil, lines] unless found

    rest = first[found[0].size..-1]
    [found[1] || found[2], rest.empty? ? lines[1..-1] : [rest] + lines[1..-1]]
  end

  # Has the DLL open the question a replay waits on.
  #
  # @return [Hash, nil] The question as the DLL hands it, see ChoiceTopics.InputOpen; nil while it
  #   does not answer.
  def self.open_question
    question = @question
    spec = question[:spec].merge("index" => question[:spec]["index"].to_i)
    spec["labels"] = spec["labels"].map { |label| filled(label) } if spec["labels"]
    spec["items"] = spec["items"].map { |id, name, count| [id, name, count, $data_items[id].description.to_s] } if spec["items"]
    spec["result"] = spec["result"].to_s if question[:kind] == "present"
    companion = question[:kind] == "present" ? $game_actors[spec["actor"]].name : nil
    question[:input] = MGQ_Multiplayer::Bridge.call(INPUT_OPEN_TOPIC, "kind" => question[:kind], "opener" => question[:opener], "companion" => companion, "spec" => spec)
  end

  # Fills in the names, variables and the currency a label's codes stand for, with the game's own
  # conversion, keeping its other codes for the list to draw.
  #
  # @param label [String] The label.
  # @return [String] The label filled in; as it was where the game cannot convert it.
  def self.filled(label)
    return label.to_s unless defined?(Window_Base) && (Window_Base.method_defined?(:convert_escape_characters) || Window_Base.private_method_defined?(:convert_escape_characters))

    Window_Base.allocate.send(:convert_escape_characters, label.to_s).gsub("\e", "\\")
  rescue => e
    log("filling in the label #{label.inspect} failed, so it shows as it is: #{e.class}: #{e.message}")
    label.to_s
  end

  # Takes the close of the question's screen: an answer goes to the replay; cancel answers what
  # the question's cancel answers, or puts it off where it answers nothing; any other close lets it
  # open again the next time the player stands free.
  #
  # @param why [Symbol, String] Why the screen closed, see Mod_Framework::UI's close reasons.
  # @param answer [Integer, nil] The answer picked, nil for none.
  def self.question_closed(why, answer)
    question = @question
    return unless question

    return answered_question(answer) unless answer.nil?

    if why == :cancel
      cancel = question[:input]["cancel"]
      return answered_question(cancel) unless cancel.nil?

      return put_off_question
    end
    log("closed the screen of the question (#{why}): it opens again once the player stands free")
    question[:shown] = false
  end

  # Hands the answer to the replay that waits on it, once the screen closed.
  #
  # @param answer [Integer] The answer.
  def self.answered_question(answer)
    done = @question[:done]
    log("the player answered the #{@question[:kind]} a replay asks: #{answer}")
    @question = nil
    done.call(answer)
  end

  # Opens the screen of choices, unless what it is about no longer stands.
  #
  # @param title [String] Its title.
  # @param keys [Array<Symbol>] The choices, in story order.
  # @param buttons [Array<String>] The buttons: the one that confirms, then the one that cancels, if any.
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The leader.
  # @param route [Integer, nil] The leader's route.
  # @param done [Proc] Takes the answers once confirmed.
  # @param valid [Proc, nil] Tells why the screen must close, nil while it may stay.
  def self.show_screen(title, keys, buttons, peer, route, done, valid)
    reason = valid ? valid.call : nil
    return MGQ_MpOverworldSync.notice("#{reason} Your story stays as it was.") if reason

    name = peer.respond_to?(:state) ? peer.state["name"].to_s : "the leader"
    answers = {}
    keys.each do |key|
      offered = labels(key)
      answers[key] = key == DECISION && route && route < offered.size ? route : 0
    end
    @screen = { :title => title, :keys => keys, :buttons => buttons, :route => route, :leader => name, :done => done, :valid => valid, :answers => answers }
    log("showing the screen \"#{title}\" with #{keys.empty? ? 'no choices' : keys.join(', ')}")
    Screen.open(@screen)
  end

  # The screen of choices that shows.
  #
  # @return [Hash, nil] The screen, see show_screen, with :answers, each choice's outcome picked;
  #   nil while none shows.
  def self.screen
    @screen
  end

  # Takes the close of the screen of choices: confirmed, it hands every outcome on; the offer
  # gone, it tells the player; cancelled, the story stays, and a choice of the player's own
  # waits until they next stand free; refused or lost by the Mod Framework, it opens again once
  # they stand free.
  #
  # @param screen [Hash] The screen, see show_screen.
  # @param why [Symbol, String] Why it closed, see Mod_Framework::UI's close reasons; a String is
  #   why the offer no longer stands, or why the framework refused the screen.
  def self.screen_closed(screen, why)
    @screen = nil if @screen.equal?(screen)
    return confirmed(screen) if screen[:confirmed]
    return offer_gone(why) if why.is_a?(String) && screen[:valid] && screen[:valid].call == why
    return log("closed \"#{screen[:title]}\" (#{why}); the story stays as it was") if screen[:buttons].size > 1
    return put_off_prompt if why == :cancel

    log("closed the screen of choices (#{why}): it opens again once the player stands free")
  end

  # Tells the player that the offer of the screen of choices no longer stands.
  #
  # @param why [String] Why, as the player reads it.
  def self.offer_gone(why)
    log("closed the screen of choices: #{why}")
    MGQ_MpOverworldSync.notice("#{why} Your story stays as it was.")
  end

  # Hands every outcome shown to the screen's confirm.
  #
  # @param screen [Hash] The screen, see show_screen.
  def self.confirmed(screen)
    answers = screen[:answers]
    log("\"#{screen[:buttons][0]}\" with #{answers.empty? ? 'no choices' : answers.map { |key, index| "#{key}: #{labels(key)[index]}" }.join(', ')}")
    screen[:done].call(answers)
  end

  # Forgets what waits, as when a save is loaded or the world closes.
  #
  # @param reason [String] Why, for the log.
  def self.forget(reason)
    waiting = [@accepted && 'the accepted offer', @prompts.any? && "the choices #{@prompts.join(', ')}", @queued && "the Great Decision's outcome",
               @raid_route && "the world's route to confirm", @question && "the #{@question[:kind]} a replay asks"].select { |what| what }
    log("forgot #{waiting.join(', ')}: #{reason}") unless waiting.empty?
    @accepted = nil
    @prompts.clear
    @screen = nil
    @queued = nil
    @raid_route = nil
    @personal = nil
    @question = nil
    @prompts_later = false
  end

  # Takes a message about the choices. Called by coop.rbx.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who sent it.
  # @param message [Hash] The message's fields.
  def self.take(peer, message)
    log("got #{message['choices']} from #{MGQ_MpOverworldSync.who(peer)}")
    return unless message["choices"] == "declined" && @offers.key?(peer.state["id"].to_s)

    drop_offer(peer.state["id"].to_s, "they declined it")
    MGQ_MpOverworldSync.notice("#{peer.state['name']} declined to sync their story.")
  rescue => e
    log("taking #{message['choices']} failed: #{e.class}: #{e.message}")
  end

  # What the choices add to the World overview and the notification box: the leader's offer.
  module Offers
    # Tells the leader's offer, when it reaches the player.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @return [Array, nil] The text and its color, nil for none.
    def self.call_of(peer)
      MGQ_MpCoopChoices.offer_of(peer) ? ["Offers to sync your story", OFFER_COLOR] : nil
    end

    # Tells the leader's offer for the notification box.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @return [MGQ_MpActions::Notice, nil] The offer, nil for none.
    def self.notice_of(peer)
      nonce = MGQ_MpCoopChoices.offer_of(peer)
      return nil unless nonce

      MGQ_MpActions::Notice.new([:story_sync, peer.seat], "#{peer.state['name']} offers to bring your story up to theirs", OFFER_COLOR, "Accept",
                                lambda { MGQ_MpCoopChoices.accept(peer) }, lambda { MGQ_MpCoopChoices.decline(peer) }, nonce)
    end

    # The choice for a member in the World overview, as their party's leader: offering to sync their
    # story; none in a Raid World, whose story is the world's.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @return [MGQ_MpActions::Option, nil] The choice, nil for another player than a member.
    def self.peer_option(peer)
      return nil if MGQ_MpCoopChoices.raid?
      return nil unless MGQ_MpCoop.party_leader == :me && MGQ_MpCoop::Party.member?(peer.state)

      option = MGQ_MpActions::Option
      return option.new("Story sync offered", nil, "Your offer to #{peer.state['name']} stands.") if MGQ_MpCoopChoices.offered?(peer)

      refusal = MGQ_MpCoopChoices.offer_refusal(peer)
      option.new("Sync story", refusal ? nil : lambda { MGQ_MpCoopChoices.offer(peer) }, refusal)
    end

    # The choices on the player's own row: none.
    #
    # @return [Array<MGQ_MpActions::Option>] No choices.
    def self.own_options
      []
    end
  end

  # Reports whether the player offers a member to sync their story.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @return [Boolean] Whether they do.
  def self.offered?(peer)
    @offers.key?(peer.state["id"].to_s)
  end
end

module MGQ_MpCoopChoices
  # Tells how wide the screens are: the most width, or 32 pixels clear of either side.
  #
  # @return [Integer] The width.
  def self.screen_width
    [Graphics.width - 64, MOST_WIDTH].min
  end

  # Writes the key line's entries of a screen, the bound cancel key named by the framework.
  #
  # @param entries [Array<Array(String, String)>] Each [keys, what they do]; the keys "cancel"
  #   stand for the game's cancel button.
  # @return [Array<Hash>] The entries, as Mod_Framework::UI::KeyHelp takes them.
  def self.key_entries(entries)
    entries.map { |key, text| key == "cancel" ? { :button => :B, :text => text } : { :key => key, :text => text } }
  end

  # The screen of the story's choices: a row per choice whose outcome turns, the line of what the
  # picked outcome of the cursor's choice brings, and the buttons, in a menu scene of its own.
  module Screen
    # Id of the window, which keeps the focus of a window made anew.
    ID = :mgq_online_story_choices

    # Id of the list of choices.
    LIST_ID = :mgq_online_story_choices_list

    # Width of the choices' names.
    LABEL_WIDTH = 150

    # The rows of choices shown at most; the rest scroll.
    MOST_ROWS = 8

    # The lines the hint takes at most.
    HINT_LINES = 2

    # What heads the choices.
    HEADING = "Your choices"

    # The hints of the confirm button with choices and without, and of the cancel button.
    CONFIRM_HINT = "Takes every outcome shown."
    NOTHING_HINT = "Nothing to choose: confirm to go on."
    CANCEL_HINT = "Leaves your story as it is."

    # The keys the key line names before cancel.
    KEYS = [["Left/Right or Enter", "change the outcome"], ["Up/Down", "move"]]

    # What cancel does on the screen of the leader's offer, and on a screen that only confirms.
    CANCEL_TEXT = "cancel"
    LATER_TEXT = "answer later"

    # Opens the screen, in a menu scene of its own over the map.
    #
    # @param screen [Hash] The screen, see MGQ_MpCoopChoices.show_screen.
    # @return [Mod_Framework::UI::Window] The window.
    def self.open(screen)
      width = MGQ_MpCoopChoices.screen_width
      sync = screen[:buttons].size > 1
      options = { :id => ID, :title => screen[:title], :center => true, :width => width, :max_size => [width, Graphics.height - SCREEN_ROOM], :menu => true }
      options[:if] = lambda { screen[:valid].call || true } if screen[:valid]
      window = UI::Window.new(options)
      parts = build(window, screen, sync)
      window.on(:close) { |why| MGQ_MpCoopChoices.screen_closed(screen, why) }
      show(parts, screen, parts[:list].row_at(parts[:list].index))
      window.open
    end

    # Adds the parts of the screen to its window.
    #
    # @param window [Mod_Framework::UI::Window] The window.
    # @param screen [Hash] The screen.
    # @param sync [Boolean] Whether it is the leader's offer, which the player may cancel.
    # @return [Hash] The parts: :hint, :list and :note.
    def self.build(window, screen, sync)
      choices = !screen[:keys].empty?
      parts = { :hint => window.add_label("", :wrap => true, :most_lines => HINT_LINES, :color => :dim) }
      parts[:list] = window.add_list(:id => LIST_ID, :rows => rows_of(screen), :sides => true, :label_width => LABEL_WIDTH, :leave_ends => true, :shoulder_pages => false,
                                     :most_rows => MOST_ROWS, :grow => 1, :quiet => true, :visible => choices)
      parts[:note] = window.add_label("", :wrap => true, :steady => true, :font_size => :small, :visible => choices)
      buttons = window.add_row(:justify => :end, :gap => UI::Style::GAP)
      confirm = buttons.add_button(screen[:buttons][0], :closes => true)
      confirm.on(:click) { screen[:confirmed] = true }
      confirm.on(:focus) { parts[:hint].text = choices ? CONFIRM_HINT : NOTHING_HINT }
      buttons.add_button(screen[:buttons][1], :closes => true).on(:focus) { parts[:hint].text = CANCEL_HINT } if sync
      window.add_key_help(MGQ_MpCoopChoices.key_entries(KEYS + [["cancel", sync ? CANCEL_TEXT : LATER_TEXT]]))
      list = parts[:list]
      list.on(:side) { |row, _index, step| turn(parts, screen, row, step) }
      list.on(:submit) { |row, _index| turn(parts, screen, row, 1) }
      list.on(:change) { |row, _index| show(parts, screen, row) }
      list.on(:focus) { show(parts, screen, list.row_at(list.index)) }
      parts
    end

    # Lists the rows: the heading, then each choice's title with its picked outcome.
    #
    # @param screen [Hash] The screen.
    # @return [Array<Hash>] The rows.
    def self.rows_of(screen)
      rows = screen[:keys].map do |key|
        found = MGQ_MpCoopChoices.branch(key) || [key.to_s, key.to_s, 0, ""]
        { :label => found[1], :value => MGQ_MpCoopChoices.labels(key)[screen[:answers][key]].to_s, :data => key }
      end
      [{ :heading => HEADING }] + rows
    end

    # Turns a choice's outcome by a step, round its outcomes, and shows the rows and the note anew.
    #
    # @param parts [Hash] The parts, see build.
    # @param screen [Hash] The screen.
    # @param row [Hash] The choice's row.
    # @param step [Integer] 1 for the next outcome, -1 for the one before.
    def self.turn(parts, screen, row, step)
      key = row[:data]
      offered = MGQ_MpCoopChoices.labels(key)
      return if offered.empty?

      before = screen[:answers][key]
      screen[:answers][key] = (before + step) % offered.size
      Sound.play_cursor
      MGQ_MpCoopChoices.log("#{row[:label]}: \"#{offered[before]}\" -> \"#{offered[screen[:answers][key]]}\"")
      parts[:list].rows = rows_of(screen)
      show(parts, screen, parts[:list].row_at(parts[:list].index))
    end

    # Shows the hint of a choice and the note of what its picked outcome brings, asked anew, since
    # one choice's note can read another's answer.
    #
    # @param parts [Hash] The parts, see build.
    # @param screen [Hash] The screen.
    # @param row [Hash, nil] The choice's row, nil for none.
    def self.show(parts, screen, row)
      key = row.is_a?(Hash) ? row[:data] : nil
      return unless key

      found = MGQ_MpCoopChoices.branch(key)
      parts[:hint].text = found ? found[3].to_s : ""
      parts[:note].text = MGQ_MpCoopChoices.note(key, screen[:answers][key], screen[:answers], screen[:route], screen[:leader])
    end
  end

  # The screen of a question a replay asks: its title, why it is asked and the place, the message's
  # last lines under their speaker, then the answers as rows, or the digits with a button that
  # answers, in a menu scene of its own over the map.
  module Question
    # Id of the window, which keeps the focus of a window made anew.
    ID = :mgq_online_story_question

    # Ids of the list of answers and of the digits.
    LIST_ID = :mgq_online_story_question_list
    DIGITS_ID = :mgq_online_story_question_digits

    # What the line under the title says.
    WHY_TEXT = "Your answer changes your own game."

    # The label of the button that answers a number.
    ANSWER_TEXT = "Answer"

    # The message's lines shown at most, the last ones.
    MESSAGE_LINES = 4

    # The rows of answers shown at most; the rest scroll.
    MOST_ROWS = 8

    # The lines the hint takes at most.
    HINT_LINES = 2

    # Opens the screen of a question, in a menu scene of its own over the map.
    #
    # @param question [Hash] The question, see MGQ_MpCoopChoices.ask_input.
    # @param input [Hash] What the DLL opened of it, see ChoiceTopics.InputOpen.
    # @return [Mod_Framework::UI::Window] The window.
    def self.open(question, input)
      width = MGQ_MpCoopChoices.screen_width
      window = UI::Window.new(:id => ID, :title => input["title"], :center => true, :width => width, :max_size => [width, Graphics.height - SCREEN_ROOM], :menu => true)
      add_head(window, question)
      answer = nil
      take = lambda do |value|
        answer = value
        window.close(:submit)
      end
      if input["kind"] == "number"
        list = nil
        add_digits(window, input, take)
      else
        list = add_list(window, input, take)
      end
      hint = window.add_label(input["hint"].to_s, :wrap => true, :most_lines => HINT_LINES, :color => :dim)
      list.on(:change) { |_row, index| hint.text = input["rows"][index][3].to_s if index >= 0 && input["rows"][index] } if list
      window.add_key_help(MGQ_MpCoopChoices.key_entries(input["keys"]))
      window.on(:close) { |why| MGQ_MpCoopChoices.question_closed(why, answer) }
      window.open
    end

    # Adds the line of why and where, and the message under its speaker, between lines across.
    #
    # @param window [Mod_Framework::UI::Window] The window.
    # @param question [Hash] The question.
    def self.add_head(window, question)
      head = window.add_row(:gap => UI::Style::GAP)
      head.add_label(WHY_TEXT, :grow => 1, :shrink => true)
      head.add_label(question[:place], :color => :dim) unless question[:place].to_s.empty?
      window.add_divider
      speaker, lines = MGQ_MpCoopChoices.speaker_of(question[:lines])
      window.add_label(speaker, :color => :system) if speaker
      lines.last(MESSAGE_LINES).each { |line| window.add_label(line.to_s, :escapes => true) }
      window.add_divider
    end

    # Adds the answers as rows: a choice's labels, or the items with their icons and counts, with
    # the cancel answer's own row last and dim.
    #
    # @param window [Mod_Framework::UI::Window] The window.
    # @param input [Hash] The question as the DLL opened it.
    # @param take [Proc] Takes the answer picked.
    # @return [Mod_Framework::UI::List] The list.
    def self.add_list(window, input, take)
      list = window.add_list(:id => LIST_ID, :rows => rows_of(input), :index => input["index"].to_i, :escapes => true, :most_rows => MOST_ROWS, :grow => 1,
                             :shoulder_pages => false)
      list.on(:submit) { |row, _index| take.call(row[:data]) }
      list
    end

    # Lists the rows of a question that lists its answers.
    #
    # @param input [Hash] The question as the DLL opened it.
    # @return [Array<Hash>] The rows.
    def self.rows_of(input)
      items = input["kind"] != "choice"
      input["rows"].map do |answer, name, count, _hint, cancel|
        next { :text => name.to_s, :color => :dim, :data => answer } if cancel

        row = { :text => name.to_s, :data => answer }
        row[:icon] = $data_items[answer].icon_index if items && $data_items[answer]
        row[:right] = "x#{count}" if count
        row
      end
    end

    # Adds the digits of a number with the button that answers it.
    #
    # @param window [Mod_Framework::UI::Window] The window.
    # @param input [Hash] The question as the DLL opened it.
    # @param take [Proc] Takes the number answered.
    # @return [Mod_Framework::UI::NumberField] The digits.
    def self.add_digits(window, input, take)
      row = window.add_row(:justify => :center, :gap => UI::Style::GAP)
      digits = row.add_number_field(:id => DIGITS_ID, :digits => input["digits"].to_i, :value => input["value"].to_i)
      digits.on(:submit) { |value| take.call(value) }
      row.add_button(ANSWER_TEXT).on(:click) { take.call(digits.value) }
      digits
    end
  end
end

# What this script takes part in of the party's messages and states, through coop.rbx and
# overworld_sync.rbx.

begin
  MGQ_MpCoop.route("choices") { |peer, message| MGQ_MpCoopChoices.take(peer, message) }
  MGQ_MpOverworldSync.state_fields { MGQ_MpCoopChoices.state_fields }
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpCoopChoices.forget("the world closed") unless in_world }
  MGQ_MpActions.offer(MGQ_MpCoopChoices::Offers)
rescue => e
  MGQ_MpCoopChoices.log("co-op FAILED: #{e.class}: #{e.message}")
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # After the map's update, the leader's offers, the choices to pick and the Great Decision's outcome.
  MGQ_MpHooks.after(Game_Map, :update, "coop_choices") { MGQ_MpCoopChoices.update }

  # The player leaves the map for a menu or a battle, after which a question or a choice put off
  # opens again.
  MGQ_MpHooks.after(Scene_Map, :terminate, "coop_choices") { MGQ_MpCoopChoices.left_free }

  # A loaded save brings its own story, so what waited goes.
  MGQ_MpHooks.after(DataManager.singleton_class, :extract_save_contents, "coop_choices") { |_contents| MGQ_MpCoopChoices.forget("a save was loaded") }

  # A new game too, which a Raid World's player may start while its route waits to be confirmed.
  MGQ_MpHooks.after(DataManager.singleton_class, :setup_new_game, "coop_choices") { MGQ_MpCoopChoices.forget("a new game started") }
rescue => e
  MGQ_MpCoopChoices.log("hooks FAILED: #{e.class}: #{e.message}")
end
