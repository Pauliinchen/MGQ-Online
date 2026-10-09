#----------------------------------------------------------------
#  coop_choices.rbx
#
#  Changelog:
#      Paulinchen  2026-10-09: Read the story and the roster and brought companions through the state model of story_state.rbx instead of coop_story.rbx
#                            - Forgot the choices waiting to be picked when a new game starts, so a Raid World's route waiting to be confirmed never plays on a fresh game
#      Paulinchen  2026-10-08: Left drawing and turning the switches to Window_MpWorldForm, which the world screen's forms share
#                            - Kept every choice's outcome each player's own in a Raid World, and asked a player the world's story carried past a choice, their side included, for their own outcome
#                            - Offered at the Great Decision of a Raid World only the routes the world may still take, the third way once the world cleared both other routes, and played only the player's own half of the route the world took
#                            - Offered no story sync in a Raid World, whose story is the world's
#      Paulinchen  2026-10-07: Created
#
#----------------------------------------------------------------

# The story's choices a member makes for themselves: who Luka takes along, Amira, Magistea Village,
# Plansect, Succubus Village, the Spider Princess, the Sphinx and the Great Decision. Each is the
# member's own, whatever the leader chose: their outcome's switches and variables stay out of the
# leader's story the member plays, and the companions it brings join them, never the leader's.
#
# A party's leader offers a member behind them to bring their story up to the leader's ("Sync
# story"): the member accepts in the notification box, picks on one screen every choice the catch-up
# carries them past, and is then brought there; one who takes the other side of the Great Decision
# starts their own route. While a member plays the leader's story, the same screen asks them their
# own outcome of each choice the story passes.
#
# In a Raid World every choice's outcome is each player's own, and a player the world's story
# carries past a choice picks their own on the same screen; at the Great Decision the screen offers
# the route the world took, whose global half the world's story brings, so only the player's own half
# plays: the companions the side changes and the side.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpCoopChoices
  # A choice of the story: where it is, by the main story's progress (variable 1001) from which it
  # can be made, and its outcomes.
  #
  # @!attribute key [Symbol] Its name.
  # @!attribute title [String] What the screen calls it.
  # @!attribute point [Integer] The main story's progress from which it can be made.
  # @!attribute hint [String] What the lines at the top say while the cursor is on it.
  # @!attribute outcomes [Array<Hash>] Each outcome's :label, :switches (by id, on or off),
  #   :variables (by id), :joins (companions) and :note (what it brings).
  Branch = Struct.new(:key, :title, :point, :hint, :outcomes)

  # The choices, in story order.
  BRANCHES = [
    Branch.new(:side, "Alice or Ilias", 7, "Iliasville: whom Luka takes along on his journey, his side until the Great Decision.", [
      { :label => "Take Alice along", :switches => { 4 => true, 5 => false }, :joins => [5], :note => "Alice joins." },
      { :label => "Take Ilias along", :switches => { 4 => false, 5 => true }, :joins => [26], :note => "Ilias joins." },
    ]),
    Branch.new(:amira, "Amira in Iliasburg", 9, "Iliasburg: what Luka does with Amira. Killed, she comes back later.", [
      { :label => "Ask her name", :switches => { 2127 => true }, :joins => [540], :note => "Amira joins." },
      { :label => "Kill her", :switches => { 2108 => true }, :joins => [], :note => "She comes back later, and can join you then." },
    ]),
    Branch.new(:magistea, "Magistea Village", 17, "Magistea Village: whom Luka defeats, Lily or Lucia. The other joins.", [
      { :label => "Defeat Lily", :switches => { 2096 => true, 7017 => true, 2095 => true, 2097 => false, 7016 => false, 2094 => false, 2138 => true, 2137 => false },
        :variables => { 1029 => 6 }, :joins => [167], :note => "Lucia joins." },
      { :label => "Defeat Lucia", :switches => { 2097 => true, 7016 => true, 2094 => true, 2096 => false, 7017 => false, 2095 => false, 2137 => true, 2138 => false },
        :variables => { 1029 => 6 }, :joins => [163], :note => "Lily joins." },
    ]),
    Branch.new(:plansect, "Plansect", 24, "Plansect: whose side Luka takes, the plants' Priestess or the insects' Queen Bee.", [
      { :label => "Side with the Priestess", :switches => { 7003 => true, 2154 => false, 7002 => false }, :variables => { 1061 => 1, 1056 => 6 },
        :joins => [241], :note => "The Queen Bee is defeated. The Priestess joins." },
      { :label => "Side with the Queen Bee", :switches => { 2154 => true, 7002 => true, 7003 => false }, :variables => { 1061 => 2, 1056 => 6 },
        :joins => [245], :note => "The Priestess is defeated. Miria, the Queen Bee, joins." },
    ]),
    Branch.new(:succubus, "Succubus Village", 27, "Succubus Village: whom Luka allies with. Who joins depends on Lily or Lucia.", [
      { :label => "Ally with Natasha", :note => "" },
      { :label => "Ally with the mayor", :note => "" },
    ]),
    Branch.new(:spider, "The Spider Princess", 30, "The Secluded Lands: whose side Luka takes, the Spider Princess or the Queen Ants.", [
      { :label => "Side with the Spider Princess", :switches => { 2280 => true, 2281 => false }, :joins => [334], :note => "The Spider Princess joins." },
      { :label => "Side with the Queen Ants", :switches => { 2281 => true, 2280 => false }, :joins => [], :note => "Nobody joins." },
    ]),
    Branch.new(:sphinx, "The Sphinx", 31, "The Pyramid: whether Luka challenges the Sphinx or invites her along.", [
      { :label => "Challenge her", :switches => { 2090 => true }, :joins => [], :note => "The Sphinx is defeated. Nobody joins." },
      { :label => "Invite her", :switches => {}, :joins => [153], :note => "The Sphinx joins." },
    ]),
    Branch.new(:decision, "The Great Decision", 40, "The Monster Lord's Castle: whose side Luka takes, which decides the route of the Final Chapter.", [
      { :label => "Side with the Dark Goddess (World Breaker)", :route => 0, :side => 4, :return => 111, :map => 430 },
      { :label => "Side with the Goddess Ilias (Judgement)", :route => 1, :side => 5, :return => 112, :map => 431 },
      { :label => "Search for a third way (Chaos)", :route => 2 },
    ]),
  ]

  # The outcomes of Succubus Village, by the side taken and whether Lily (with Natasha) or Lucia
  # (with the mayor) is with the player.
  SUCCUBUS = {
    [0, true] => { :switches => { 2210 => true, 7007 => true }, :joins => [288] },
    [0, false] => { :switches => { 2211 => true, 7007 => true }, :joins => [] },
    [1, true] => { :switches => { 2212 => true, 7008 => true }, :joins => [287] },
    [1, false] => { :switches => { 2213 => true, 7008 => true }, :joins => [] },
  }

  # Every switch the outcomes of Succubus Village set, which each of them sets on or off.
  SUCCUBUS_SWITCHES = [2210, 2211, 2212, 2213, 7007, 7008]

  # The companions the choices bring, which come only with the member's own outcome, never as the
  # leader holds them: Lily, Lucia, Natasha, the mayor, Amira, the Sphinx, the Priestess, Miria and
  # the Spider Princess.
  CHOICE_COMPANIONS = [163, 167, 288, 287, 540, 153, 241, 245, 334]

  # The main story's progress the Great Decision sets.
  GREAT_DECISION = 40

  # The routes' progress variables, by the Great Decision's outcome.
  ROUTES = [1141, 1142, 1143]

  # Where the Great Decision's third way takes the player: map, x, y and direction.
  CHAOS_START = [437, 12, 12, 0]

  # The switches that tell the world cleared the two first routes, which open the third way in a
  # Raid World.
  ROUTE_CLEARS = [7096, 7097]

  # Frames an offer of the leader stands, a minute.
  OFFER_FRAMES = 3600

  # Color of the offer in the notification box and the World overview.
  OFFER_COLOR = MGQ_MpActions::LINE_COLOR

  @offers = {}
  @prompts = []
  @accepted = nil
  @screen = nil
  @queued = nil
  @nonce = 0
  @raid_route = nil

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "co-op choices"

  # Finds a choice by its name.
  #
  # @param key [Symbol] Its name.
  # @return [Branch, nil] The choice.
  def self.branch(key)
    BRANCHES.find { |candidate| candidate.key == key }
  end

  # Lists every switch and variable an outcome of a choice sets.
  #
  # @param branch [Branch] The choice.
  # @return [Array<Array<Integer>>] The switches, then the variables.
  def self.keys_of(branch)
    return [SUCCUBUS_SWITCHES, [1065]] if branch.key == :succubus
    return [[], []] if branch.key == :decision

    [branch.outcomes.map { |outcome| (outcome[:switches] || {}).keys }.flatten.uniq,
     branch.outcomes.map { |outcome| (outcome[:variables] || {}).keys }.flatten.uniq]
  end

  # Reports whether a story made a choice already: Amira only once she joined, since killed she
  # comes back.
  #
  # @param key [Symbol] The choice.
  # @param switches [Array] The story's switches.
  # @param variables [Array] The story's variables.
  # @param roster [Array<Integer>] The player's companions.
  # @return [Boolean] Whether it did.
  def self.made?(key, switches, variables, roster)
    case key
    when :side then switches[4] || switches[5] ? true : false
    when :amira then switches[2127] ? true : false
    when :magistea then switches[2096] || switches[2097] ? true : false
    when :plansect then variables[1061].to_i >= 1
    when :succubus then SUCCUBUS_SWITCHES.first(4).any? { |id| switches[id] }
    when :spider then switches[2280] || switches[2281] ? true : false
    when :sphinx then switches[2090] || roster.include?(153) ? true : false
    when :decision then variables[1001].to_i >= GREAT_DECISION
    else false
    end
  end

  # Lists the choices a catch-up from one point of the main story to another carries the player
  # past, which they have not made in their own story.
  #
  # @param from [Integer] The player's main story progress.
  # @param to [Integer] The progress they are brought to.
  # @param switches [Array] The player's own switches.
  # @param variables [Array] The player's own variables.
  # @param roster [Array<Integer>] The player's companions.
  # @param always [Array<Symbol>] The choices asked whenever the player has not made them and is
  #   brought past them, though their own story is past them too.
  # @return [Array<Symbol>] The choices, in story order.
  def self.passed(from, to, switches, variables, roster, always = [])
    BRANCHES.select do |branch|
      (from < branch.point || always.include?(branch.key)) && to >= branch.point && !made?(branch.key, switches, variables, roster)
    end.map { |branch| branch.key }
  end

  # Reports whether the player's own save cleared both endings, which the third way of the Great
  # Decision asks, as the game's own event does; in a Raid World whether the world cleared both
  # routes, by its clear switches.
  #
  # @return [Boolean] Whether it did.
  def self.both_endings?
    return ROUTE_CLEARS.all? { |id| MGQ_MpStoryState.data_of($game_switches)[id] } if raid?

    switches = defined?($game_system_switches) ? $game_system_switches : nil
    switches && switches[:ed1] && switches[:ed2] ? true : false
  rescue
    false
  end

  # Lists the outcomes the screen offers for a choice: the third way only with both endings cleared;
  # in a Raid World the routes of decision_routes.
  #
  # @param key [Symbol] The choice.
  # @return [Array<String>] The outcomes' labels.
  def self.labels(key)
    outcomes = branch(key).outcomes
    return decision_routes.map { |index| outcomes[index][:label] } if key == :decision && raid?

    outcomes = outcomes.first(2) if key == :decision && !both_endings?
    outcomes.map { |outcome| outcome[:label] }
  end

  # Reports whether Lily is with the player once Magistea Village is decided, by the screen's answer,
  # else by their own story or roster.
  #
  # @param answers [Hash{Symbol => Integer}] The answers given so far.
  # @return [Array<Boolean>] Whether Lily is with them, and whether Lucia is.
  def self.magistea_companions(answers)
    return [answers[:magistea] == 1, answers[:magistea] == 0] if answers.key?(:magistea)

    switches = MGQ_MpStoryState.data_of($game_switches)
    roster = MGQ_MpStoryState.roster_ids
    [switches[2097] || roster.include?(163) ? true : false, switches[2096] || roster.include?(167) ? true : false]
  rescue
    [false, false]
  end

  # Finds what an outcome of Succubus Village sets and brings.
  #
  # @param index [Integer] 0 for Natasha's side, 1 for the mayor's.
  # @param answers [Hash{Symbol => Integer}] The answers given so far, Magistea Village's among them.
  # @return [Hash] :switches and :joins.
  def self.succubus_outcome(index, answers)
    lily, lucia = magistea_companions(answers)
    chosen = SUCCUBUS[[index, index == 0 ? lily : lucia]]
    switches = {}
    SUCCUBUS_SWITCHES.each { |id| switches[id] = chosen[:switches][id] ? true : false }
    { :switches => switches, :variables => { 1065 => 3 }, :joins => chosen[:joins] }
  end

  # Reports whether the open world is a Raid World, see MGQ_MpCoop::Scope.
  #
  # @return [Boolean] Whether it is.
  def self.raid?
    MGQ_MpCoop::Scope.raid?
  end

  # Lists the Great Decision's outcomes the screen offers in a Raid World: the route the world took
  # when it carried the player past the decision, else those the world may still take (see
  # MGQ_MpWorldStory.decision_routes).
  #
  # @return [Array<Integer>] The outcomes, by their place in the decision's outcomes.
  def self.decision_routes
    return [@raid_route] if @raid_route

    routes = defined?(MGQ_MpWorldStory) ? MGQ_MpWorldStory.decision_routes : nil
    routes || (both_endings? ? [0, 1, 2] : [0, 1])
  end

  # Writes what an outcome brings, for the screen's line below it.
  #
  # @param key [Symbol] The choice.
  # @param index [Integer] The outcome.
  # @param answers [Hash{Symbol => Integer}] The answers given so far.
  # @param leader_route [Integer, nil] The leader's route, its place in ROUTES, nil before the Great Decision.
  # @param leader_name [String] The leader's name.
  # @return [String] The line.
  def self.note(key, index, answers, leader_route = nil, leader_name = "the leader")
    case key
    when :succubus
      lily, lucia = magistea_companions(answers)
      return lily ? "Natasha joins, as Lily is with you." : "Nobody joins: Natasha joins only while Lily is with you." if index == 0

      lucia ? "The mayor joins, as Lucia is with you." : "Nobody joins: the mayor joins only while Lucia is with you."
    when :decision then raid? ? raid_decision_note(decision_routes[index] || index) : decision_note(index, leader_route, leader_name)
    else branch(key).outcomes[index][:note].to_s
    end
  end

  # Writes what an outcome of the Great Decision brings.
  #
  # @param index [Integer] The outcome.
  # @param leader_route [Integer, nil] The leader's route, nil before the Great Decision.
  # @param leader_name [String] The leader's name.
  # @return [String] The line.
  def self.decision_note(index, leader_route, leader_name)
    follow = index == leader_route ? "You follow #{leader_name}'s route." : "Not #{leader_name}'s route: you start it and play it on your own."
    (decision_texts(index) + [follow]).reject { |part| part.empty? }.join(" ")
  end

  # Writes what an outcome of the Great Decision brings in a Raid World, where the world took it.
  #
  # @param index [Integer] The outcome.
  # @return [String] The line.
  def self.raid_decision_note(index)
    (decision_texts(index) + ["The whole world plays this route."]).reject { |part| part.empty? }.join(" ")
  end

  # Names an outcome of the Great Decision and the companions it changes.
  #
  # @param index [Integer] The outcome.
  # @return [Array<String>] The route, then the companions, empty when none change.
  def self.decision_texts(index)
    route = ["Angelic Dominion route", "Monster Realm route", "Chaos route"][index]
    party = ["Alice, Alicetroemeria and Morrigan join; Ilias's companions leave.", "Ilias, Micaela-chan, Lucifina-chan, Eden and Heinrich join; Alice's companions leave.", ""][index]
    party = "" if variable(912) > 0
    [route + ".", party]
  end

  # Reads a variable of the story played.
  #
  # @param id [Integer] The variable.
  # @return [Integer] Its value.
  def self.variable(id)
    MGQ_MpStoryState.data_of($game_variables)[id].to_i
  rescue
    0
  end

  # Lists the switches and variables the choices the player made keep their own, while they play the
  # leader's story: those of every choice their own story made.
  #
  # @return [Array<Hash>] The switches and the variables, by id.
  def self.own_keys
    story = MGQ_MpCoopStory.own_story_data
    return [{}, {}] unless story

    signature = BRANCHES.map { |branch| made?(branch.key, story[0], story[1], []) }
    return @own_keys if @own_keys && @own_keys_for == signature

    switches = {}
    variables = {}
    BRANCHES.each_with_index do |branch, index|
      next unless signature[index]

      keys = keys_of(branch)
      keys[0].each { |id| switches[id] = true }
      keys[1].each { |id| variables[id] = true }
    end
    @own_keys_for = signature
    @own_keys = [switches, variables]
  end

  # Reports whether a switch or a variable is the player's own as a choice's outcome, while they
  # play the leader's story; never for the leader, whose story the members get. In a Raid World every
  # choice's outcome is each player's own.
  #
  # @param kind [Symbol] :s for a switch, :v for a variable.
  # @param id [Integer] The switch or variable.
  # @return [Boolean] Whether it is.
  def self.personal?(kind, id)
    return raid_keys[kind == :s ? 0 : 1].key?(id) if raid?
    return false unless MGQ_MpCoopStory.guest?

    own_keys[kind == :s ? 0 : 1].key?(id)
  rescue
    false
  end

  # Lists the switches and variables of every choice's outcomes, each player's own in a Raid World.
  #
  # @return [Array<Hash>] The switches and the variables, by id.
  def self.raid_keys
    @raid_keys ||= begin
      switches = {}
      variables = {}
      BRANCHES.each do |branch|
        keys = keys_of(branch)
        keys[0].each { |id| switches[id] = true }
        keys[1].each { |id| variables[id] = true }
      end
      [switches, variables]
    end
  end

  # Tells why the catch-up leaves out a reward: a choice's companion, which comes with the member's
  # own outcome, or one only another route's Final Chapter gives a member who starts their own.
  #
  # @param kind [Symbol] :skills, :actors or :items.
  # @param id [Integer, String] The reward.
  # @return [String, nil] The reason, nil to give it.
  def self.skip_reason(kind, id)
    return "a choice's companion, who comes with the player's own outcome" if kind == :actors && CHOICE_COMPANIONS.include?(id)
    return nil unless @accepted && @accepted[:other_route] && defined?(MGQ_MpCoopStoryRewards) && MGQ_MpCoopStoryRewards.const_defined?(:FINAL)

    MGQ_MpCoopStoryRewards::FINAL[kind].include?(id) ? "only the leader's route gives it, and the player starts another" : nil
  end

  # Gives the player a choice's outcome in the story they play: its switches and variables, also in
  # their own story kept aside, and the companions it brings.
  #
  # @param key [Symbol] The choice.
  # @param index [Integer] The outcome.
  # @param answers [Hash{Symbol => Integer}] Every answer given, Magistea Village's among them.
  def self.apply(key, index, answers = {})
    return MGQ_MpCoopStory.choose_side(index == 0 ? :alice : :ilias) if key == :side

    outcome = key == :succubus ? succubus_outcome(index, answers) : branch(key).outcomes[index]
    switches = MGQ_MpStoryState.data_of($game_switches)
    variables = MGQ_MpStoryState.data_of($game_variables)
    own = MGQ_MpCoopStory.own_story_aside
    written = []
    (outcome[:switches] || {}).each do |id, value|
      written << "s#{id} #{switches[id] ? 'on' : 'off'} -> #{value ? 'on' : 'off'}"
      switches[id] = value
      own[0][id] = value if own
    end
    (outcome[:variables] || {}).each do |id, value|
      written << "v#{id} #{variables[id].to_i} -> #{value}"
      variables[id] = value
      own[1][id] = value if own
    end
    $game_map.need_refresh = true if $game_map
    log("#{branch(key).title}: the player's own outcome \"#{labels(key)[index]}\": #{written.join(', ')}")
    (outcome[:joins] || []).each do |id|
      name = MGQ_MpStoryState.bring(id)
      MGQ_MpOverworldSync.notice("#{name} joined you.") if name
    end
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
    @offers[peer.state["id"].to_s] = { :nonce => @nonce, :since => Graphics.frame_count, :name => peer.state["name"].to_s }
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
    theirs = MGQ_MpCoopStory.read_markers(peer.state["sm"])
    own = MGQ_MpCoopStory.own_markers
    return "#{peer.state['name']}'s game tells no story progress." unless theirs
    return "#{peer.state['name']} follows your story already." if peer.state["ssync"].to_s == MGQ_MpOverworldSync::Me.id.to_s
    return "#{peer.state['name']} is not behind you in the story." if theirs == own || theirs.each_with_index.any? { |value, index| value > own[index] }

    nil
  end

  # As leader, takes back the offers that no longer stand: to a player who left the party, follows
  # the player's story now, or let it run out. Called after the map's update.
  def self.tick_offers
    return @offers.clear if @offers.any? && MGQ_MpCoop.party_leader != :me

    members = MGQ_MpCoop::Party.members
    @offers.keys.each do |id|
      member = members.find { |peer| peer.state["id"].to_s == id }
      next drop_offer(id, "they left the party") unless member
      next drop_offer(id, "they follow the player's story now") if member.state["ssync"].to_s == MGQ_MpOverworldSync::Me.id.to_s
      next drop_offer(id, "nobody answered in #{OFFER_FRAMES / 60} s") if Graphics.frame_count - @offers[id][:since] >= OFFER_FRAMES || Graphics.frame_count < @offers[id][:since]
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

    switches = MGQ_MpStoryState.data_of($game_switches)
    variables = MGQ_MpStoryState.data_of($game_variables)
    # Amira killed comes back, so she is asked of every member who never had her join.
    keys = passed(own[0], theirs[0], switches, variables, MGQ_MpStoryState.roster_ids, [:amira])
    log("accepted #{MGQ_MpOverworldSync.who(peer)}'s offer: own #{MGQ_MpCoopStory.markers_text(own)}, theirs #{MGQ_MpCoopStory.markers_text(theirs)}; " \
        "choices to make: #{keys.empty? ? 'none' : keys.join(', ')}")
    route = theirs[0] >= GREAT_DECISION ? MGQ_MpCoopStory.route_of(theirs) : nil
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
    decision = answers[:decision]
    other = !decision.nil? && decision != route
    @accepted = { :with => peer.state["id"].to_s, :decision => decision, :other_route => other }
    log("bringing the player's story up to #{MGQ_MpOverworldSync.who(peer)}'s (#{MGQ_MpCoopStory.markers_text(theirs)})" \
        "#{decision ? ", the Great Decision: #{labels(:decision)[decision]}#{other ? ', another route than theirs' : ', their route'}" : ''}")
    (answers.keys & BRANCHES.map { |branch| branch.key } - [:decision]).sort_by { |key| branch(key).point }.each { |key| apply(key, answers[key], answers) }
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
    ([1001] + (1140..1143).to_a).each { |id| variables[id] = id == 1001 ? GREAT_DECISION - 1 : 0 }
    MGQ_MpCoopStory.keep_and_leave("the player starts the #{["Angelic Dominion", "Monster Realm", "Chaos"][index]} route, not #{peer.state['name']}'s")
    @queued = decision_commands(index)
    log("the Great Decision's outcome \"#{labels(:decision)[index]}\" waits to play once the player is free: #{@queued.size} commands")
    MGQ_MpOverworldSync.notice("You start your own route. Each of you plays your own story.")
  end

  # Builds the commands that play the Great Decision's outcome: the Final Chapter put back as the
  # game's own reset does (common event 154), the outcome's part of common event 380, which changes
  # the party and takes the player to its map, with the side and the route set on the way.
  #
  # @param index [Integer] The outcome: 0 the Dark Goddess, 1 the Goddess Ilias, 2 the third way.
  # @return [Array<RPG::EventCommand>] The commands.
  def self.decision_commands(index)
    commands = [RPG::EventCommand.new(117, 0, [154]), RPG::EventCommand.new(122, 0, [1140, 1140, 0, 0, 0])]
    outcome = branch(:decision).outcomes[index]
    if index == 2
      [7091, 7092, 92].each { |id| commands << RPG::EventCommand.new(121, 0, [id, id, 0]) }
      commands << RPG::EventCommand.new(122, 0, [1001, 1001, 0, 0, GREAT_DECISION])
      commands << RPG::EventCommand.new(122, 0, [1143, 1143, 0, 0, 1])
      commands << RPG::EventCommand.new(201, 0, [0] + CHAOS_START + [2])
      return commands << RPG::EventCommand.new(0, 0, [])
    end

    part = decision_part(outcome)
    transfer = part.pop || RPG::EventCommand.new(201, 0, [0, outcome[:map], 25, 19, 8, 2])
    commands.concat(part)
    [4, 5].each { |id| commands << RPG::EventCommand.new(121, 0, [id, id, id == outcome[:side] ? 0 : 1]) }
    commands << RPG::EventCommand.new(122, 0, [ROUTES[index], ROUTES[index], 0, 0, 1])
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
    outcome = branch(:decision).outcomes[index]
    return [] unless outcome[:return]

    commands = decision_part(outcome)
    commands.pop if commands.last && commands.last.code == 201
    [4, 5].each { |id| commands << RPG::EventCommand.new(121, 0, [id, id, id == outcome[:side] ? 0 : 1]) }
    commands << RPG::EventCommand.new(222, 0, [])
    commands << RPG::EventCommand.new(0, 0, [])
  end

  # Copies the part of common event 380 that plays an outcome of the Great Decision: from where it
  # notes where a game over returns the player to the transfer to the outcome's map, moved to the
  # left so it runs on its own.
  #
  # @param outcome [Hash] The outcome: :return and :map.
  # @return [Array<RPG::EventCommand>] The commands, the transfer last; none when the game's event
  #   differs.
  def self.decision_part(outcome)
    list = ($data_common_events[380] && $data_common_events[380].list) || []
    first = list.index { |command| command.code == 122 && command.parameters[0, 5] == [1002, 1002, 0, 0, outcome[:return]] }
    last = first && (first...list.size).find { |at| list[at].code == 201 && list[at].parameters[1] == outcome[:map] }
    unless first && last
      log("the Great Decision's event differs from the one known, so its outcome plays without its party changes")
      return [RPG::EventCommand.new(122, 0, [1002, 1002, 0, 0, outcome[:return].to_i])]
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

    roster = MGQ_MpStoryState.roster_ids
    # The side is each player's own in a Raid World, whose story nobody chose it in for them.
    keys = passed(from, to, story[0], story[1], roster) - (raid? ? [:decision] : [:side, :decision])
    # The leader resolving a choice the player has not made asks it too.
    BRANCHES.each do |branch|
      next if [:side, :decision].include?(branch.key) || keys.include?(branch.key) || made?(branch.key, story[0], story[1], roster)

      all = keys_of(branch).flatten
      keys << branch.key if (all & changed).any?
    end
    keys -= @prompts
    return if keys.empty?

    @prompts.concat(keys)
    log("the #{raid? ? 'world' : 'leader'}'s story passed #{keys.join(', ')} (1001 #{from} -> #{to}), whose own outcome the player picks once free")
  end

  # Asks the player at the Great Decision once a Raid World's story carried them past it: the screen
  # offers the route the world took alone, whose own half plays once confirmed.
  #
  # @param index [Integer] The world's route, its place in ROUTES.
  def self.raid_decision(index)
    @raid_route = index
    @prompts << :decision unless @prompts.include?(:decision)
    log("the world's story took the #{labels(:decision).first} route at the Great Decision, which the player confirms once free")
  end

  # Shows the screen of the next choice the player picks their own outcome of, once they are free
  # on the map, and plays the Great Decision's outcome waiting. Called after the map's update.
  def self.update
    tick_offers
    play_queued
    return if @prompts.empty? || !MGQ_MpOverworldSync.map_free? || SceneManager.scene.class != Scene_Map

    unless raid? || MGQ_MpCoopStory.follows_leader?
      log("forgot the choices #{@prompts.join(', ')} the player was to pick: they no longer follow the leader's story")
      return @prompts.clear
    end

    key = @prompts.first
    lead = MGQ_MpCoop.party_leader
    title = key == :decision && raid? ? "The world's route" : "Your own outcome"
    show_screen(title, [key], ["Confirm"], lead, nil, lambda { |answers| answered_prompt(key, answers) }, nil)
  rescue => e
    log("updating the choices failed: #{e.class}: #{e.message}")
  end

  # Takes the player's own outcome of a choice the leader's story passed.
  #
  # @param key [Symbol] The choice.
  # @param answers [Hash{Symbol => Integer}] The answer.
  def self.answered_prompt(key, answers)
    @prompts.delete(key)
    return unless answers.key?(key)
    return take_raid_decision(answers[key]) if key == :decision && raid?

    apply(key, answers[key], answers)
  end

  # Plays the player's own half of the route a Raid World took at the Great Decision, once free.
  #
  # @param place [Integer] The outcome's place among those the screen offered.
  def self.take_raid_decision(place)
    index = decision_routes[place.to_i]
    @raid_route = nil
    return unless index

    commands = raid_decision_commands(index)
    log("the Great Decision of the world: \"#{branch(:decision).outcomes[index][:label]}\", #{commands.empty? ? 'nothing of the player\'s own changes' : "the player's own half waits to play once free: #{commands.size} commands"}")
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

  # Opens the screen of choices.
  #
  # @param title [String] Its title.
  # @param keys [Array<Symbol>] The choices, in story order.
  # @param buttons [Array<String>] The buttons: the one that confirms, then the one that cancels, if any.
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The leader.
  # @param route [Integer, nil] The leader's route.
  # @param done [Proc] Takes the answers once confirmed.
  # @param valid [Proc, nil] Tells why the screen must close, nil while it may stay.
  def self.show_screen(title, keys, buttons, peer, route, done, valid)
    name = peer.respond_to?(:state) ? peer.state["name"].to_s : "the leader"
    @screen = { :title => title, :keys => keys, :buttons => buttons, :route => route, :leader => name, :done => done, :valid => valid }
    log("showing the screen \"#{title}\" with #{keys.empty? ? 'no choices' : keys.join(', ')}")
    SceneManager.call(Scene_MpStoryChoices)
  end

  # The screen waiting to show, taken once by the screen.
  #
  # @return [Hash, nil] The screen, see show_screen.
  def self.take_screen
    screen = @screen
    @screen = nil
    screen
  end

  # Builds the screen's form: a switch per choice, with the line of what the picked outcome brings,
  # then the buttons.
  #
  # @param screen [Hash] The screen, see show_screen.
  # @return [MGQ_MpWorld::Form] The form.
  def self.form_of(screen)
    field = MGQ_MpWorld::Form::Field
    fields = []
    values = {}
    screen[:keys].each_with_index do |key, row|
      branch = branch(key)
      note = lambda { |form, index| note(key, index, answers_of(form, screen[:keys]), screen[:route], screen[:leader]) }
      fields << field.new(key, :switch, branch.title, row, branch.hint, :choices => labels(key), :note => note, :group => "Your choices")
      values[key] = key == :decision && screen[:route] && screen[:route] < labels(key).size ? screen[:route] : 0
    end
    row = screen[:keys].size
    screen[:buttons].each_with_index do |label, index|
      side = screen[:buttons].size > 1 ? (index == 0 ? :left : :right) : nil
      hint = index == 0 ? (screen[:keys].empty? ? "Nothing to choose: confirm to go on." : "Takes every outcome shown.") : "Leaves your story as it is."
      fields << field.new(index == 0 ? :confirm : :cancel, :button, label, row, hint, :side => side)
    end
    MGQ_MpWorld::Form.new(screen[:title], fields, values)
  end

  # Reads the answers a form holds.
  #
  # @param form [MGQ_MpWorld::Form] The form.
  # @param keys [Array<Symbol>] The choices.
  # @return [Hash{Symbol => Integer}] Each choice's outcome.
  def self.answers_of(form, keys)
    answers = {}
    keys.each { |key| answers[key] = form[key].to_i }
    answers
  end

  # Forgets what waits, as when a save is loaded or the world closes.
  #
  # @param reason [String] Why, for the log.
  def self.forget(reason)
    log("forgot #{[@accepted && 'the accepted offer', @prompts.any? && "the choices #{@prompts.join(', ')}", @queued && "the Great Decision's outcome"].compact.join(', ')}: #{reason}") if @accepted || @prompts.any? || @queued
    @accepted = nil
    @prompts = []
    @queued = nil
    @raid_route = nil
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

# The screen of the story's choices: a switch per choice, the line of what the picked outcome
# brings below each, and the buttons, drawn and turned as the world screen's forms.
class Window_MpStoryChoices < Window_MpWorldForm
  # Width of the choices' names, which Window_MpWorldForm#draw_switch reads.
  LABEL_WIDTH = 150
end

# The screen of the story's choices, opened over the map.
class Scene_MpStoryChoices < Scene_MenuBase
  # Keys the lines at the top name.
  KEYS_HINT = "Left/Right or Enter: change the outcome. Up/Down: move. Esc: cancel."

  # Keys the lines at the top name on a screen that only confirms.
  CONFIRM_HINT = "Left/Right or Enter: change the outcome. Up/Down: move."

  # Builds the windows.
  def start
    super
    @screen = MGQ_MpCoopChoices.take_screen
    return return_scene unless @screen

    @form = MGQ_MpCoopChoices.form_of(@screen)
    @info_window = Window_MpInfo.new(2)
    width = [Graphics.width - 64, 480].min
    height = Graphics.height - @info_window.height - 16
    @form_window = Window_MpStoryChoices.new((Graphics.width - width) / 2, @info_window.height + 8, width, height)
    @form_window.form = @form
    @form_window.on_turn = method(:turn)
    @form_window.set_handler(:ok, method(:on_ok))
    @form_window.set_handler(:cancel, method(:on_cancel))
    @form_window.visible = true
    @form_window.activate
    @form_window.select(0)
    show_hint
  rescue => e
    MGQ_MpCoopChoices.log("opening the screen of choices failed: #{e.class}: #{e.message}")
    return_scene
  end

  # Closes the screen once what it is about no longer stands, and follows the mouse.
  def update
    super
    reason = @screen && @screen[:valid] ? @screen[:valid].call : nil
    if reason
      MGQ_MpCoopChoices.log("closed the screen of choices: #{reason}")
      MGQ_MpOverworldSync.notice("#{reason} Your story stays as it was.")
      return return_scene
    end

    follow_mouse
    show_hint
  rescue => e
    MGQ_MpCoopChoices.log("the screen of choices failed: #{e.class}: #{e.message}")
    return_scene
  end

  # Takes a click: on a switch it turns it, on a button it presses it.
  def follow_mouse
    return unless MGQ_Multiplayer::Mouse.clicked?

    position = MGQ_Multiplayer::Mouse.position
    return unless position

    x = position[0] - @form_window.x - @form_window.padding
    y = position[1] - @form_window.y - @form_window.padding + @form_window.oy
    index = (0...@form.fields.size).find do |at|
      rect = @form_window.item_rect(at)
      x >= rect.x && x < rect.x + rect.width && y >= rect.y && y < rect.y + rect.height
    end
    return unless index

    @form_window.select(index)
    on_ok
  end

  # Shows the hint of the field the cursor is on and the keys.
  def show_hint
    field = @form_window.field
    @info_window.show([field ? field.hint : nil, @screen[:buttons].size > 1 ? KEYS_HINT : CONFIRM_HINT])
  end

  # Turns the switch the cursor is on.
  #
  # @param step [Integer] 1 for the next outcome, -1 for the previous.
  def turn(step)
    field = @form_window.field
    before = field.choices[@form[field.key].to_i]
    @form.turn(field, step)
    Sound.play_cursor
    MGQ_MpCoopChoices.log("#{field.label}: \"#{before}\" -> \"#{field.choices[@form[field.key].to_i]}\"")
    @form_window.refresh
  end

  # Turns a switch onward, or presses a button.
  def on_ok
    field = @form_window.field
    @form_window.activate
    return turn(1) if field && field.kind == :switch
    return confirm if field && field.key == :confirm

    on_cancel
  end

  # Takes every outcome shown and closes the screen.
  def confirm
    answers = MGQ_MpCoopChoices.answers_of(@form, @screen[:keys])
    MGQ_MpCoopChoices.log("\"#{@form_window.field.label}\" with #{answers.empty? ? 'no choices' : answers.map { |key, index| "#{key}: #{MGQ_MpCoopChoices.labels(key)[index]}" }.join(', ')}")
    done = @screen[:done]
    return_scene
    done.call(answers)
  end

  # Closes the screen without the outcomes, where it may be cancelled.
  def on_cancel
    return @form_window.activate if @screen[:buttons].size < 2

    MGQ_MpCoopChoices.log("cancelled \"#{@screen[:title]}\"; the story stays as it was")
    return_scene
  end
end

# What this script takes part in of the party's messages and states, through coop.rbx and
# overworld_sync.rbx.

begin
  MGQ_MpCoop.route("choices") { |peer, message| MGQ_MpCoopChoices.take(peer, message) }
  MGQ_MpOverworldSync.state_fields { MGQ_MpCoopChoices.state_fields }
  MGQ_MpActions.offer(MGQ_MpCoopChoices::Offers)
rescue => e
  MGQ_MpCoopChoices.log("co-op FAILED: #{e.class}: #{e.message}")
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # After the map's update, the leader's offers, the choices to pick and the Great Decision's outcome.
  MGQ_MpHooks.after(Game_Map, :update, "coop_choices") { MGQ_MpCoopChoices.update }

  # A loaded save brings its own story, so what waited goes.
  MGQ_MpHooks.after(DataManager.singleton_class, :extract_save_contents, "coop_choices") { |_contents| MGQ_MpCoopChoices.forget("a save was loaded") }

  # A new game too, which a Raid World's player may start while its route waits to be confirmed.
  MGQ_MpHooks.after(DataManager.singleton_class, :setup_new_game, "coop_choices") { MGQ_MpCoopChoices.forget("a new game started") }
rescue => e
  MGQ_MpCoopChoices.log("hooks FAILED: #{e.class}: #{e.message}")
end
