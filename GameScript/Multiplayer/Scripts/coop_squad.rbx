#----------------------------------------------------------------
#  coop_squad.rbx
#
#  Changelog:
#      Paulinchen  2026-11-11: Kept the squad read last while the DLL answers that it is unchanged
#      Paulinchen  2026-11-08: Colored the party edit screen's rows through the Mod Framework's row patch instead of drawing them
#                            - Greyed the formation list's rows past the squad through the row patch instead of drawing them
#      Paulinchen  2026-11-07: Greyed the Party Followers row for members through disabled:
#      Paulinchen  2026-11-06: Read the color of the line past a squad in the player's look each time it draws
#      Paulinchen  2026-11-05: Told the followers shown and read a ghost's as values, the DLL writing them
#      Paulinchen  2026-11-01: Named the Mod Framework's interface by its own name
#                            - Added the followers' row through the Mod Framework's options
#      Paulinchen  2026-10-31: Took the group of its row from MGQ_Multiplayer::OPTION_PREFIX
#      Paulinchen  2026-10-30: Read the own share, the followers' mode and whether squads split from the DLL's view of the party once a frame
#      Paulinchen  2026-10-23: Asked the DLL or the core library for the squad math, the team fit and the default squad rules
#      Paulinchen  2026-10-13: Sized a Raid World's team and squads by the world's squad rules
#                            - Let a Raid World's Luka leave the team when its rules allow it
#                            - Kept the event command of followers from swapping Luka to the front
#                              in a Raid World
#                            - Offered Give Up in a Raid World only while Luka leads the team
#      Paulinchen  2026-10-12: Listed the option among the settings of the Mod Config
#      Paulinchen  2026-10-11: Drew the line past a squad in the shared style's bad color
#      Paulinchen  2026-10-10: Took a Raid World's squad from the team's first three places
#      Paulinchen  2026-10-08: Gave every player one Frontline and two Backline places in a Raid World
#                            - Capped party_member_max at 4 in a Raid World
#                            - Fought the player's own Raid World battles with the squad alone
#                            - Brought only the squad to the duels and team duels of a Raid World
#                            - Moved Luka into the squad when fitting the team to a Raid World
#                            - Hid every follower in a Raid World
#      Paulinchen  2026-10-07: Registered the followers' option through coop.rbx and named the face and icon sizes
#                            - Logged every player's share and the followers' mode on change
#      Paulinchen  2026-10-06: Took the party's leader from coop.rbx's party_leader
#      Paulinchen  2026-10-04: Renamed from mp_coop_squad.rbx
#      Paulinchen  2026-10-03: Sent messages and read the world through MGQ_MpOverworldSync
#                            - Logged through MGQ_MpLog
#      Paulinchen  2026-10-02: Installed the hooks on the game's plugins through core_hooks.rbx
#                            - Took party membership from coop.rbx and dropped squad
#      Paulinchen  2026-10-01: Created
#
#----------------------------------------------------------------

# A party's squads: the players of a party share one single-player team between them. The four
# places of the Frontline and the Backline's places are split between the players, the party's
# leader taking what does not split evenly, so each player keeps a squad of their first characters
# and the rest are cut. Only the squad fights in co-op battles (battles_coop.rbx). The formation
# screens show the squad's Frontline and Backline as the game shows its own, and the cut characters
# grey under a line. On the map only each player's share of the Frontline follows them, or
# nobody, as the leader chose in Options > Mods. A battle a player fights alone keeps their own
# full team, so nothing here changes the game's party itself, except in a Raid World: there the
# world's squad rules (see rules) size every player's team and squad, in a party or not and in
# every battle, the companions past the team wait on standby, Luka stays in the team unless the
# rules let him go, the game never swaps him to the front on its own, and nobody follows on the
# map.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpCoopSquad
  # Places of the Frontline, the game's battle members.
  FRONTLINE = 4

  # The Formation size of a Raid World's rules that keeps the game's own team size.
  ORIGINAL = 0

  # The topic that tells the squad rules of a Raid World that names none.
  DEFAULT_TOPIC = "squad.default"

  # The topic that splits a party's places between its players.
  SHARES_TOPIC = "squad.shares"

  # The topic that orders players as every member's game does.
  RANK_TOPIC = "squad.rank"

  # The topic that sizes a Raid World's squad for both fights.
  RAID_TOPIC = "squad.raid"

  # The topic that picks the companions a team past its cap leaves out.
  PAST_CAP_TOPIC = "squad.past_cap"

  # The topic that reads the player's squad over the party, once a frame.
  VIEW_TOPIC = "squad.view"

  # The names of a squad rule in the topics' answers, by the rule's key in the scripts.
  RULE_NAMES = { :luka => "luka", :formation => "formation", :front => "front", :raid_front => "raid_front" }

  # Answers kept at most, see ask.
  KEPT_ANSWERS = 64

  # The option of followers in a party, its key in $game_system.conf.
  FOLLOWERS = :mp_party_followers

  # Followers' value that shows each player's share of the Frontline.
  ACTIVE_FRONTLINE = 0

  # Followers' value that shows the players alone.
  LEADERS_ONLY = 1

  # Followers' values by their name and help in Options > Mods.
  FOLLOWER_VALUES = {
    ACTIVE_FRONTLINE => ["Active Frontline", "Each player's own share of the Frontline walks behind them."],
    LEADERS_ONLY => ["Leaders Only", "The players walk alone."],
  }

  # Color name of the line above the first character past a squad in the formation screens.
  CUT_COLOR = :error

  # The game's text color of the party edit screen's Frontline.
  NORMAL_TEXT = 0

  # The game's text color of the party edit screen's Backline.
  SYSTEM_TEXT = 16

  # The player's share, the followers' mode and whether a Raid World is open, as tick last took
  # them, nil outside a world.
  @shown = nil

  # The player's squad as the DLL read it last: "share", "mode" and "squads"; nil outside a world
  # and before the DLL answered.
  @view = nil

  # The party fitted to a Raid World, which party_member_max caps, nil while no cap holds.
  @capped = nil

  # The squad rules the party was fitted to, see fit_team.
  @capped_rules = nil

  # Whether the game's swaps of the party's order are held back, while the event command of
  # followers runs in a Raid World.
  @holding_order = false

  # The squad topics' answers by topic and request, see ask.
  @answers = {}

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "co-op squad"

  # Asks the DLL a squad topic, once per request while the answer is kept: the game's hooks ask
  # for the squad many times a frame.
  #
  # @param topic [String] The topic.
  # @param request [Object] The request.
  # @return [Object, nil] The answer, nil while the DLL does not answer.
  def self.ask(topic, request)
    key = [topic, request]
    return @answers[key] if @answers.key?(key)

    answer = MGQ_Multiplayer::Bridge.call(topic, request)
    return nil if answer.nil?

    @answers.clear if @answers.size >= KEPT_ANSWERS
    @answers[key] = answer
  end

  # Writes squad rules as the squad topics read them.
  #
  # @param rules [Hash] The rules, see rules.
  # @return [Hash] The rules by their names in RULE_NAMES.
  def self.rules_request(rules)
    request = {}
    RULE_NAMES.each { |key, name| request[name] = key == :luka ? (rules[key] ? true : false) : rules[key].to_i }
    request
  end

  # Tells a player's squad: their share of the Frontline and of the Backline, the party's places
  # split between its players, one more each for the first ones while some are left over.
  #
  # @param position [Integer] The player's place among the players, the leader first.
  # @param count [Integer] The players.
  # @param max [Integer] The player's party_member_max, Frontline and Backline together.
  # @return [Array<Integer>] The Frontline's and the Backline's share.
  def self.share(position, count, max)
    shares = ask(SHARES_TOPIC, { "count" => count.to_i, "max" => max.to_i }) || []
    (shares[position] || [0, 0]).dup
  end

  # Tells the places of the Frontline in a PvP battle between two players: the squad's in a Raid
  # World, else FRONTLINE.
  #
  # @return [Integer] The places.
  def self.pvp_front
    raid? ? raid_share[0] : FRONTLINE
  end

  # Lists the player's characters a PvP battle takes in a Raid World: their squad, or only its
  # Frontline in a duel without the Backline.
  #
  # @param backline [Boolean] Whether the battle takes the Backline.
  # @return [Array<Game_Actor>] The characters, the Frontline first.
  def self.raid_team(backline = true)
    front, bench = raid_share
    own_order.first(backline ? front + bench : front)
  end

  # Reports whether a Raid World is open, where the world's squad rules size every player's team.
  #
  # @return [Boolean] Whether one is.
  def self.raid?
    MGQ_MpCoop::Scope.raid?
  end

  # Reads the open Raid World's squad rules.
  #
  # @return [Hash] :luka (whether Luka may leave the team), :formation (the team's size, ORIGINAL
  #   for the game's own), :front and :raid_front (the Frontline's places in regular fights and in
  #   raids); default_rules when the world names none.
  def self.rules
    world = defined?(MGQ_MpWorld) && MGQ_MpWorld.respond_to?(:squad) ? MGQ_MpWorld.squad : nil
    world || default_rules
  end

  # Reads the squad rules of a Raid World that names none.
  #
  # @return [Hash] The rules, see rules; formation 0 and no Frontline while the DLL does not answer.
  def self.default_rules
    names = ask(DEFAULT_TOPIC, nil) || {}
    rules = {}
    RULE_NAMES.each { |key, name| rules[key] = key == :luka ? (names[name] ? true : false) : names[name].to_i }
    rules
  end

  # Reports whether Luka may leave the team: in a Raid World whose rules allow it.
  #
  # @return [Boolean] Whether he may.
  def self.luka_free?
    raid? && rules[:luka] ? true : false
  end

  # Tells the team's size a Raid World holds.
  #
  # @return [Integer, nil] The size, nil for the game's own.
  def self.team_cap
    formation = rules[:formation].to_i
    formation == ORIGINAL ? nil : formation
  end

  # Reports whether the battle running is a raid, a fight with one of the raid bosses.
  #
  # @return [Boolean] Whether it is.
  def self.raid_fight?
    return false unless $game_party && $game_party.in_battle && $game_troop && defined?(MGQ_MpRaidBosses)

    MGQ_MpRaidBosses.boss?(MGQ_MpGame.get($game_troop, :troop_id))
  end

  # Sizes the player's squad in a Raid World for both fights by the world's rules.
  #
  # @param max [Integer] The player's party_member_max.
  # @return [Hash] "regular" and "raid" (each the Frontline's and the Backline's places) and
  #   "largest" (the larger squad's characters); none of them while the DLL does not answer.
  def self.raid_sizes(max)
    ask(RAID_TOPIC, { "rules" => rules_request(rules), "max" => max.to_i }) || {}
  end

  # Tells the player's squad in a Raid World for a fight: the Frontline the world's rules give for
  # it and the Backline the team leaves, the last place cut unless the team keeps the game's own
  # size.
  #
  # @param max [Integer] The player's party_member_max.
  # @param raid [Boolean] Whether the fight is a raid.
  # @return [Array<Integer>] The Frontline's and the Backline's places.
  def self.raid_share(max = $game_party.party_member_max, raid = raid_fight?)
    (raid_sizes(max)[raid ? "raid" : "regular"] || [0, 0]).dup
  end

  # Tells how many characters a player's squad in a Raid World holds at most, in a regular fight or
  # in a raid, which a co-op battle's host may hold either.
  #
  # @param max [Integer] The player's party_member_max.
  # @return [Integer] The characters.
  def self.largest_squad(max)
    raid_sizes(max)["largest"].to_i
  end

  # Reports whether Luka leads the player's team, its first character.
  #
  # @return [Boolean] Whether he does.
  def self.luka_leads?
    first = $game_party.all_members.first
    first && first.luca? ? true : false
  end

  # Reports whether the player's characters split into a squad and the cut ones: in a party, and
  # always in a Raid World, as the DLL read it this frame.
  #
  # @return [Boolean] Whether they do.
  def self.squads?
    @view && @view["squads"] ? true : false
  end

  # Reads the player's squad from the DLL once it changed, asked once a frame while a world is open:
  # their share, how followers show and whether squads split, over the party and the world's squad
  # rules. Keeps the squad read last while the DLL answers none.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.read_view(in_world)
    return @view = nil unless in_world && $game_party

    raid = raid?
    request = { "max" => $game_party.party_member_max, "own_mode" => own_mode, "raid" => raid, "raid_fight" => raid && raid_fight?,
                "rules" => raid ? rules_request(rules) : nil }
    answer = MGQ_Multiplayer::Bridge.call(VIEW_TOPIC, request)
    @view = answer if answer.is_a?(Hash)
  end

  # Orders players as every member's game does: the leader first, then by their ids.
  #
  # @param players [Array<Array>] Each player's id and whether they lead.
  # @return [Array<String>] The ids in order, none while the DLL does not answer.
  def self.ranked(players)
    (ask(RANK_TOPIC, players.map { |id, leads| [id.to_s, leads ? true : false] }) || []).dup
  end

  # Tells the player's squad, as the DLL read it this frame: in a Raid World as its rules size it
  # for the fight (see raid_share), else their share in their party.
  #
  # @return [Array<Integer>, nil] The Frontline's and the Backline's share, nil outside a party in
  #   a Classic world.
  def self.own_share
    share = @view && @view["share"]
    share ? share.dup : nil
  end

  # Lists the player's characters in the order their squad takes them; in a Raid World only those
  # in the squad's places of the team, as in_squad keeps them.
  #
  # A hidden squad member would otherwise move the cut place into the squad of duels and co-op
  # battles.
  #
  # @param size [Integer, nil] The squad's places in a Raid World, nil for the squad of the fight.
  # @return [Array<Game_Actor>] The characters that exist, the Frontline first.
  def self.own_order(size = nil)
    members = $game_party.all_members
    existing = members.select(&:exist?)
    raid? ? existing & members.first(size || raid_share.inject(:+)) : existing
  end

  # Tells where a character stands in the player's squad.
  #
  # @param actor [Game_Actor, nil] The character.
  # @return [Symbol, nil] :front, :bench or :cut, nil without squads (see squads?) or for no
  #   character.
  def self.place_of(actor)
    return nil unless actor && squads?

    index = own_order.index(actor)
    index ? place_at(index) : :cut
  end

  # Tells what a place of the player's order is in their squad.
  #
  # @param index [Integer] The place, 0 for the player's first character.
  # @return [Symbol, nil] :front, :bench or :cut, nil without squads (see squads?).
  def self.place_at(index)
    front, bench = own_share
    return nil unless front
    return :front if index < front

    index < front + bench ? :bench : :cut
  end

  # Reads how followers show in the party, as the DLL read it this frame: the leader's choice, the
  # player's own when they lead or play outside a party.
  #
  # @return [Integer] ACTIVE_FRONTLINE or LEADERS_ONLY.
  def self.mode
    value = @view ? @view["mode"] : own_mode
    value == LEADERS_ONLY ? LEADERS_ONLY : ACTIVE_FRONTLINE
  end

  # Reads the player's own choice of followers in Options > Mods.
  #
  # @return [Integer] ACTIVE_FRONTLINE or LEADERS_ONLY.
  def self.own_mode
    value = $game_system.conf[FOLLOWERS] rescue nil
    value.to_i == LEADERS_ONLY ? LEADERS_ONLY : ACTIVE_FRONTLINE
  end

  # Reports whether a follower shows on the map: in a party only the player's share of the
  # Frontline, nobody when the party's leader chose the players alone, and nobody in a Raid World.
  #
  # Reads the share and the choice tick took this frame, since the game asks for every follower
  # several times a frame.
  #
  # @param member_index [Integer] The follower's place in the Frontline, 1 for the first behind the
  #   player.
  # @return [Boolean] Whether it shows; outside a party in a Classic world, always.
  def self.follower_shown?(member_index)
    share, shown_mode, raid = @shown
    return true unless share
    return false if raid

    shown_mode == ACTIVE_FRONTLINE && member_index.to_i < share[0]
  rescue
    true
  end

  # Writes the looks of the followers the player shows, which their party's games show behind
  # their ghost.
  #
  # @return [Array<Array>] Each follower's sprite and index.
  def self.trail
    return [] unless MGQ_MpCoop.in_party? && $game_player

    shown = []
    $game_player.followers.each do |follower|
      shown << [follower.character_name.to_s, follower.character_index] if follower.visible? && !follower.character_name.to_s.empty?
    end
    shown
  end

  # Reads the looks of a ghost's followers, leaving out what another game sent that is none.
  #
  # @param trail [Object] The trail the ghost's player told, see trail.
  # @return [Array<Array>] Each follower's sprite and index.
  def self.followers_of(trail)
    return [] unless trail.is_a?(Array)

    trail.select { |look| look.is_a?(Array) && look.size == 2 && look[0].is_a?(String) && !look[0].empty? && look[1].is_a?(Integer) }
  end

  # The fields the squad adds to the state the player's game tells the others.
  #
  # @return [Hash] The followers' mode, the player's choice or the leader's they follow, and the
  #   looks of the followers the player shows.
  def self.state_fields
    { "follow" => mode, "trail" => trail }
  end

  # Fits the team to a Raid World, reads the squad, and shows the followers anew once the party, the
  # player's share, the leader's choice, the world's type or its squad rules changed. Called every
  # frame in every scene.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    raid = in_world && raid?
    fit_team(raid)
    read_view(in_world)
    shown = in_world ? [own_share, mode, raid, raid ? rules : nil] : nil
    return if shown == @shown

    @shown = shown
    log("squads #{shares_line}; followers: #{raid ? 'none in a Raid World' : FOLLOWER_VALUES[mode][0]}") if in_world
    $game_player.refresh if $game_player
  end

  # Fits the player's team to a Raid World's rules once it is in one or the rules changed: brings
  # Luka back from standby unless he may leave, moves the companions past the team's size to
  # standby before the cap holds for it (see party_member_max), and swaps Luka into the squad unless
  # he may leave. Lifts the cap outside a Raid World. A new game and a loaded save bring a team of
  # their own, which is fitted anew.
  #
  # The game cuts its party list down to party_member_max whenever it changes, so the cap is lifted
  # while the team is fitted and holds only for a team fitted first; the team is fitted anew after a
  # story's temporary party, since companions may have joined meanwhile.
  #
  # @param raid [Boolean] Whether a Raid World is open.
  def self.fit_team(raid)
    return lift_cap("outside a Raid World") unless raid

    party = $game_party
    return if party.nil?
    return lift_cap("while a story's temporary party plays") if party.temp_actors_use?

    current = rules
    return if (party.equal?(@capped) && current == @capped_rules) || party.in_battle

    @capped = nil
    luka_back(party) unless current[:luka]
    cap = team_cap
    moved = cap ? past_cap(party.actors.to_a, cap, !current[:luka]) : []
    moved.each do |id|
      party.add_stand_actor(id)
      party.move_stand_actor(id)
    end
    luka_into_squad(party) unless current[:luka]
    @capped = party
    @capped_rules = current
    log("a Raid World holds a team of #{cap || 'the game\'s own size'}, Luka #{current[:luka] ? 'may leave it' : 'stays'}" \
        "#{moved.empty? ? '' : "; to standby: #{moved.map { |id| actor_name(id) }.join(', ')}"}")
  rescue => e
    log("fitting the team failed: #{e.class}: #{e.message}")
  end

  # Lifts the cap on the team's size until the team is fitted again.
  #
  # @param reason [String] When, for the log.
  def self.lift_cap(reason)
    log("the team's size is the game's again, #{reason}") if @capped
    @capped = nil
  end

  # Picks the companions a team of a size leaves out: those past its first places, Luka kept when
  # he stays.
  #
  # @param ids [Array<Integer>] The team's character ids in order.
  # @param size [Integer] The team's size.
  # @param keep_luka [Boolean] Whether Luka stays in the team.
  # @return [Array<Integer>] The ids left out, in order; none while the DLL does not answer.
  def self.past_cap(ids, size, keep_luka = true)
    request = { "team" => ids, "luka" => ids.select { |id| luka?(id) }, "cap" => size, "keep_luka" => keep_luka ? true : false }
    MGQ_Multiplayer::Bridge.call(PAST_CAP_TOPIC, request) || []
  end

  # Brings Luka back from standby into the team, which he left while a Raid World's rules let him.
  #
  # @param party [Game_Party] The team fitted.
  def self.luka_back(party)
    id = party.stand_actors.to_a.find { |stand_id| luka?(stand_id) }
    return unless id

    party.move_actor(id)
    log("brought Luka back into the team: the world's rules keep him in it")
  end

  # Swaps Luka into the squad's last place when he stands past it, which fitting a team leaves him
  # in when he stood past the squad.
  #
  # @param party [Game_Party] The team fitted.
  def self.luka_into_squad(party)
    place = party.actors.to_a.index { |id| luka?(id) }
    size = raid_share(party.party_member_max, false).inject(:+)
    return unless place && place >= size

    party.swap_order(place, size - 1)
    log("moved Luka into the squad's place #{size}, from place #{place + 1}")
  end

  # Reports whether a character is Luka, whom the game never sends to standby.
  #
  # @param id [Integer] The character's id.
  # @return [Boolean] Whether it is.
  def self.luka?(id)
    actor = $game_actors[id]
    actor.respond_to?(:luca?) && actor.luca? ? true : false
  end

  # Names a character for the log.
  #
  # @param id [Integer] The character's id.
  # @return [String] Its name and id.
  def self.actor_name(id)
    "#{$game_actors[id].name} (#{id})"
  rescue
    id.to_s
  end

  # Caps the game's party size in a Raid World, for the team fitted to it (see fit_team), which
  # leaves the items that raise the party size without effect there.
  #
  # A story's temporary party is its own standby list, so a cap on it would drop characters from
  # the story.
  #
  # @param party [Game_Party] The party asked.
  # @param max [Integer] The game's party_member_max.
  # @return [Integer] The team's size of the Raid World's rules or less in a Raid World, else the
  #   game's.
  def self.party_member_max(party, max)
    return max if @capped.nil? || !@capped.equal?(party) || party.temp_actors_use?

    cap = raid? ? team_cap : nil
    cap ? [max, cap].min : max
  end

  # Reports whether a battle fights with the player's own squad of a Raid World: a battle of their
  # own, a duel, or one a co-op battle left them alone in. A co-op party and a team duel bring their
  # own.
  #
  # @param party [Game_Party] The party asked.
  # @return [Boolean] Whether it does.
  def self.raid_battle?(party)
    return false unless party.equal?($game_party) && party.in_battle && raid?
    return false if defined?(MGQ_MpBattlesCoop) && MGQ_MpBattlesCoop.active?

    !(defined?(MGQ_MpBattlesSync) && MGQ_MpBattlesSync.team?)
  end

  # Keeps the members that stand in the squad's places of a Raid World battle, so a hidden squad
  # member never lets the cut place in.
  #
  # @param party [Game_Party] The party.
  # @param members [Array<Game_Actor>] The game's battle members or Backline.
  # @return [Array<Game_Actor>] Those among the team's first places the squad holds, in order.
  def self.in_squad(party, members)
    members & party.all_members.first(raid_share(party.party_member_max).inject(:+))
  end

  # Writes every player's squad in the party, for the log, as the player's game splits the places
  # by its own party_member_max.
  #
  # @return [String] Each player's Frontline and Backline share, the leader first, the one share of
  #   everyone in a Raid World, or that the player keeps the full team outside a party.
  def self.shares_line
    if raid?
      current = rules
      max = $game_party.party_member_max
      return "(front/back of #{max} places): #{raid_share(max, false).join('/')} in regular fights, #{raid_share(max, true).join('/')} in raids " \
             "for every player in a Raid World, the rest cut; Luka #{current[:luka] ? 'may leave the team' : 'stays'}"
    end
    return "none: the player keeps the full team outside a party" unless MGQ_MpCoop.in_party?

    leader = MGQ_MpCoop.party_leader
    names = { MGQ_MpOverworldSync::Me.id => "#{MGQ_MpOverworldSync::Me.identity[1]} (the player)" }
    players = [[MGQ_MpOverworldSync::Me.id, leader == :me]]
    MGQ_MpCoop::Party.members.each do |peer|
      names[peer.state["id"].to_s] = peer.state["name"].to_s
      players << [peer.state["id"].to_s, peer.equal?(leader)]
    end
    max = $game_party.party_member_max
    order = ranked(players)
    shares = order.each_with_index.map { |id, position| "#{names[id]} #{share(position, order.size, max).join('/')}" }
    "(front/back of #{max} places): #{shares.join(', ')}"
  rescue => e
    "unknown (#{e.class})"
  end

  # Adds the followers' row to Options > Mods, which only the party's leader may change.
  def self.register
    added = Mod_Framework::Options.add(FOLLOWERS, "#{MGQ_Multiplayer::OPTION_PREFIX}Party Followers",
                                       "Who walks behind the players of a party. The party's leader decides for everyone.\r\n←/→ Toggle",
                                       FOLLOWER_VALUES, ACTIVE_FRONTLINE, :disabled => lambda { MGQ_MpCoop.in_party? && MGQ_MpCoop.party_leader != :me })
    log(added ? "added the Party Followers to Options > Mods" : "no Party Followers in Options > Mods, see the Mod Framework's log")
  end

  # Installs the hooks on the game's plugins, which load after the Patch folder. Called once the
  # first scene starts.
  def self.install
    return if @installed

    @installed = true
    install_followers
    install_formation
    install_party_edit
    install_party_cap
    install_raid_battle
    install_luka
  end

  # Takes the relay's word that the open Raid World's creator or an admin changed its squad rules,
  # which the next tick fits the team to.
  #
  # @param message [Hash] The push: MGQ_MpOverworldSync::SQUAD_FIELD with the rules' text, marked
  #   :relay by overworld_sync.rbx.
  def self.pushed(message)
    return log("ignored a squad rules push not from the relay") unless message[:relay]

    text = message[MGQ_MpOverworldSync::SQUAD_FIELD]
    taken = MGQ_MpWorld.squad_of(text)
    return log("ignored the relay's squad rules #{text.inspect}") if taken.nil?
    return if taken == MGQ_MpWorld.squad
    return log("ignored the relay's squad rules outside a Raid World") unless MGQ_MpWorld.take_squad(taken)

    log("the relay tells the world's squad rules are #{text} now")
    MGQ_MpOverworldSync.notice("The world's team rules changed: #{MGQ_MpWorld.squad_summary(taken)}.")
  rescue => e
    log("taking the relay's squad rules failed: #{e.class}: #{e.message}")
  end

  # Enables the rows of Luka in the party edit screen, which the game disables, while he may leave
  # the team.
  #
  # @param window [Foo::PTEdit::Window_PartyMember] The screen's list of the team.
  def self.free_luka_rows(window)
    list = MGQ_MpGame.get(window, :list)
    Array(window.actors).each_with_index { |id, index| list[index][:enabled] = true if id && luka?(id) && list[index] }
  end

  # Sends Luka to standby in the party edit screen, as the game sends any other character, while he
  # may leave the team: on the button, while another character stays in it.
  #
  # @param window [Foo::PTEdit::Window_PartyMember] The screen's list of the team.
  def self.move_luka(window)
    return unless MGQ_MpGame.call(window, :cursor_movable?)
    return unless Input.trigger?(:A)

    Input.update
    if window.actors.size > 1
      Sound.play_equip
      MGQ_MpGame.call(window, :call_handler, :move_member)
      window.select(0)
    else
      Sound.play_buzzer
    end
  end

  # Reports whether the game's swaps of the party's order are held back, see install_luka.
  #
  # @return [Boolean] Whether they are.
  def self.holding_order?
    @holding_order
  end

  # Runs the event command of followers without its swap of Luka to the team's first place in a
  # Raid World, where each player picks who leads.
  #
  # @param original [Proc] Runs the command as the game does.
  # @return [Object] What the command returns.
  def self.followers_command(original)
    return original.call unless raid? && $game_party && !$game_party.temp_actors_use?

    @holding_order = true
    original.call
  ensure
    @holding_order = false
  end

  # Lets Luka leave the team in the party edit screen while a Raid World's rules allow it, and keeps
  # the game from swapping him to the team's first place in a Raid World: the event command of
  # followers, which story and defeat scenes run, swaps him there, and so does Give Up, which a Raid
  # World offers only while he leads already.
  def self.install_luka
    MGQ_MpHooks.around(Game_Interpreter, :command_216, "coop_squad") { |_interpreter, _args, original| MGQ_MpCoopSquad.followers_command(original) }
    MGQ_MpHooks.around(Game_Party, :swap_order, "coop_squad") { |_party, _args, original| MGQ_MpCoopSquad.holding_order? ? nil : original.call }
    MGQ_MpHooks.around(BattleManager.singleton_class, :can_giveup?, "coop_squad") do |_manager, _args, original|
      MGQ_MpCoopSquad.raid? && !MGQ_MpCoopSquad.luka_leads? ? false : original.call
    end
    return unless defined?(Foo::PTEdit::Window_PartyMember)

    MGQ_MpHooks.around(Foo::PTEdit::Window_PartyMember, :make_command_list, "coop_squad") do |window, _args, original|
      original.call
      MGQ_MpCoopSquad.free_luka_rows(window) if MGQ_MpCoopSquad.luka_free?
    end
    MGQ_MpHooks.around(Foo::PTEdit::Window_PartyMember, :process_move_member, "coop_squad") do |window, _args, original|
      actor = MGQ_MpCoopSquad.luka_free? ? window.select_actor : nil
      actor && actor.luca? ? MGQ_MpCoopSquad.move_luka(window) : original.call
    end
  rescue => e
    log("Luka hooks FAILED: #{e.class}: #{e.message}")
  end

  # Caps the party's size in a Raid World, see party_member_max.
  def self.install_party_cap
    MGQ_MpHooks.around(Game_Party, :party_member_max, "coop_squad") { |party, _args, original| MGQ_MpCoopSquad.party_member_max(party, original.call) }
  rescue => e
    log("party size hook FAILED: #{e.class}: #{e.message}")
  end

  # Fights a battle of the player's own or a duel in a Raid World with their squad, see
  # raid_battle?: the Frontline and the Backline the world's rules give for the fight, the cut place
  # out of the battle even for the skills that reach the Backline too.
  #
  # The game's Backline window and swap count the Backline's places from max_battle_members, so the
  # Frontline is narrowed there. The game skips hidden members when it counts, so both lists are
  # also kept to the squad's places.
  def self.install_raid_battle
    MGQ_MpHooks.around(Game_Party, :max_battle_members, "coop_squad") do |party, _args, original|
      MGQ_MpCoopSquad.raid_battle?(party) ? MGQ_MpCoopSquad.raid_share(party.party_member_max)[0] : original.call
    end
    [:battle_members, :bench_members].each do |name|
      MGQ_MpHooks.around(Game_Party, name, "coop_squad") do |party, _args, original|
        members = original.call
        MGQ_MpCoopSquad.raid_battle?(party) ? MGQ_MpCoopSquad.in_squad(party, members) : members
      end
    end
    MGQ_MpHooks.around(Game_Party, :item_target_members, "coop_squad") do |party, args, original|
      item = args[0]
      bench = MGQ_MpCoopSquad.raid_battle?(party) && item.respond_to?(:include_bench?) && item.include_bench?
      bench ? party.battle_members + party.bench_members : original.call
    end
  rescue => e
    log("raid battle hooks FAILED: #{e.class}: #{e.message}")
  end

  # Shows only the player's share of the Frontline behind them in a party, nobody when the party's
  # leader chose the players alone, and nobody in a Raid World.
  def self.install_followers
    Game_Follower.class_eval do
      alias_method :mgq_mp_coop_squad_visible?, :visible?

      # Reports whether the follower shows: as in single player, but in a party only while it is in
      # the player's share of the Frontline, and never in a Raid World.
      #
      # @return [Boolean] Whether it shows.
      def visible?
        mgq_mp_coop_squad_visible? && MGQ_MpCoopSquad.follower_shown?(@member_index)
      end
    end
  rescue => e
    log("follower hook FAILED: #{e.class}: #{e.message}")
  end

  # Greys the menu's formation list past the party's squad through the Mod Framework's row patch,
  # see formation_rows. The game's own drawing stays.
  def self.install_formation
    Mod_Framework::UI.patch("Window_MenuStatus") { |formation| formation.rows { |rows| MGQ_MpCoopSquad.formation_rows(rows) } }
  rescue => e
    log("formation patch FAILED: #{e.class}: #{e.message}")
  end

  # Gives the rows of the menu's formation list the looks of their places in the player's squad
  # while they have one: the rest past the squad grey with a line above the first of them, the
  # squad's rows as the game draws them. Without squads and in a battle every row stays the game's.
  #
  # The patch also reaches the menu's list of targets for items and skills, a subclass of the
  # formation list, which greys the same characters.
  #
  # @param rows [Array<Hash>] The window's rows, each { index: } of a party member.
  # @return [Array<Hash>] The rows with their looks.
  def self.formation_rows(rows)
    return rows if $game_party.in_battle

    cut = lambda { |index| index >= 0 && place_of($game_party.members[index]) == :cut }
    rows.map do |row|
      next row unless cut.call(row[:index])

      row.merge(:grey => true, :line_above => cut.call(row[:index] - 1) ? nil : CUT_COLOR)
    end
  end

  # Colors the party edit screen by the party's squad through the Mod Framework's row patch, see
  # party_edit_rows. The game's own drawing stays, with the translation's larger rows.
  def self.install_party_edit
    Mod_Framework::UI.patch("Foo::PTEdit::Window_PartyMember") { |edit| edit.rows { |rows| MGQ_MpCoopSquad.party_edit_rows(edit.read(:actors), rows) } }
  rescue => e
    log("party edit patch FAILED: #{e.class}: #{e.message}")
  end

  # Gives the rows of the party edit screen the looks of their places in the player's squad while
  # they have one: the Frontline's share in the normal color, the Backline's share in the system
  # color, and the rest grey with a line above the first of them; an empty row by its place.
  # Without squads every row stays the game's.
  #
  # @param ids [Array<Integer>] The ids of the characters the screen holds, in order.
  # @param rows [Array<Hash>] The screen's commands, one per place.
  # @return [Array<Hash>] The commands with their looks.
  def self.party_edit_rows(ids, rows)
    return rows unless squads?

    places = Array.new(rows.size) { |index| (ids[index] ? place_of($game_actors[ids[index]]) : place_at(index)) || :cut }
    rows.each_with_index.map do |row, index|
      case places[index]
      when :front then row.merge(:name_color => NORMAL_TEXT)
      when :bench then row.merge(:name_color => SYSTEM_TEXT)
      else row.merge(:name_color => SYSTEM_TEXT, :grey => true, :line_above => index > 0 && places[index - 1] != :cut ? CUT_COLOR : nil)
      end
    end
  end
end

# What the squad takes part in of the world's messages, through overworld_sync.rbx, and its
# option.

begin
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpCoopSquad.tick(in_world) }
  MGQ_MpOverworldSync.state_fields { MGQ_MpCoopSquad.state_fields }
  MGQ_MpOverworldSync.route(MGQ_MpOverworldSync::SQUAD_FIELD) { |_peer, message| MGQ_MpCoopSquad.pushed(message) }
rescue => e
  MGQ_MpCoopSquad.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

begin
  MGQ_MpCoopSquad.register
rescue => e
  MGQ_MpCoopSquad.log("option FAILED: #{e.class}: #{e.message}")
end

# Game hooks, through core_hooks.rbx.

begin
  MGQ_MpHooks.before(SceneManager.singleton_class, :run, "coop_squad") { MGQ_MpCoopSquad.install }
rescue => e
  MGQ_MpCoopSquad.log("SceneManager hook FAILED: #{e.class}: #{e.message}")
end
