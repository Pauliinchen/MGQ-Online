#----------------------------------------------------------------
#  battles_coop.rbx
#
#  Changelog:
#      Paulinchen  2026-10-07: Registered the battle setup and encounter hooks through core_hooks.rbx instead of wraps of its own, and the battle's end once the game runs, where plugins define it anew
#                            - Named players and characters through battles_sync.rbx and overworld_sync.rbx, and made up a battle's id through coop.rbx, instead of copies of their helpers
#                            - Logged the co-op messages, the invites, requests and who hosts with their reasons, the roster, rebuilds, swaps, choosing again, the Library counts left out and the battle's result
#                            - Stopped a guest's characters at once when the guest leaves, instead of letting the computer play them for the rest of the turn
#                            - Let the host's computer choose nothing for a guest's characters while it waits for the guest's commands
#                            - Named the party after the player's own characters while a co-op battle runs, as when it runs away or is defeated
#      Paulinchen  2026-10-06: Forgot the co-op battle, its invites and its requests when a reset interrupts them
#                            - Rebuilt another player's fallen character fallen, which fought at full HP and came back to life on its owner's game
#                            - Ended a guest's battle that the host's party left out or never came for, instead of playing it back or waiting on
#                            - Aimed the skills that reach the Backline too at the co-op party and the player's own Backline
#                            - Kept the other players' characters out of the Library's battle, defeat and steal counts all saves share
#                            - Dropped the game's Retry of a co-op battle, whose snapshot held synced stats or an older battle
#                            - Started the battle of a guest that takes over before the host's party came, and set the counters of one that takes over later
#                            - Brought no share of the Backline to a team duel
#                            - Turned down at once the invites and requests to lead the player cannot take, instead of leaving them unanswered
#                            - Compared a rebuilt character of a team duel with what its owner's game showed without the PvP balance
#      Paulinchen  2026-10-04: Sent the players back to choose whose command was for a character another player swapped out
#                            - Synced the characters above the battle's level, which the host sends with the roster
#                            - Logged where a guest's rebuilt character differs from what the guest's game showed
#                            - Held every party member on the map while a member's encounter waits, until they join it, turn it down or ten seconds pass
#                            - Asked coop_gather.rbx whether the leader's story is about to bring the player over
#                            - Renamed from mp_battles_coop.rbx
#      Paulinchen  2026-10-03: Registered what a co-op battle does differently in a live battle as its Mode
#                            - Read and wrote the game's private fields and called its private methods through MGQ_MpGame
#                            - Kept the battle's players as Player records instead of arrays read by position
#                            - Held the player through MGQ_MpHooks.hold_player
#                            - Called the scripts that load before this one without asking whether they loaded
#                            - Sent messages, showed notices and read the world, the own id and the own seat through MGQ_MpOverworldSync
#                            - Logged through MGQ_MpLog
#                            - Started the battle and each turn for the other players' characters, whose unset hit count crashed the game when hit
#                            - Showed the player's own leader and followers on the map again once the co-op party is forgotten
#                            - Let the party's leader host a battle a member started, so the leader's game and mods decide it
#                            - Turned down an invite that came during a battle of the player's own, and one older than three seconds
#                            - Held a random encounter up to three seconds for party members on the map who are busy, telling them
#      Paulinchen  2026-10-02: Started a co-op battle when a player who joined it left the world before the roster went out
#                            - Followed the map and installed the late hooks through core_hooks.rbx
#                            - Turned an invite down through MGQ_MpBattlesSync.tell, and took the seat, place and Luka from Game_MpActor
#                            - Turned a co-op battle down while the leader's story scene is about to bring the player over
#      Paulinchen  2026-10-01: Listed the battle's players, so each hears at once when another leaves
#                            - Rebuilt the host's enemies on a guest whose troop differs, such as through a mod of either game
#                            - Brought each player's squad, a share of the Frontline and of the Backline, the leader's first
#                            - Let each player swap their own Backline in, telling every game the party's new order
#                            - Found the leader of any party among the battle's players, for the sides of a team duel
#                            - Let a player of a team duel command the characters of a player who left their side
#      Paulinchen  2026-09-30: Sent and took the party's messages through coop.rbx, which drops those of another party
#                            - Registered with overworld_sync.rbx for its messages instead of being asked by overworld.rbx
#                            - Moved into Patch/Multiplayer/Scripts as battles_coop.rbx, which Multiplayer.rb loads
#                            - Renamed from mp_coop.rb, with the module MGQ_MpBattlesCoop
#                            - Let a player who got away leave the battle, the others fighting on, alone with their own full team
#                            - Showed the co-op party in the game's window per character too
#                            - Invited party members whose window is in the background, and logged why nobody was invited
#                            - Created
#
#----------------------------------------------------------------

# Co-op battles: when a party member's game starts a battle, the party members on the same map who
# are playing on the map join it. The party's leader computes it (the host), so the leader's game
# and mods decide it: a member who started it asks the leader to lead it and joins as a guest. When
# the leader is elsewhere, busy or silent, the game that started it hosts. The others play it back
# and command their own characters, through battles_sync.rbx over the world's room. The
# party is every player's squad together (see coop_squad.rbx): each brings their share of the
# Frontline, the party's leader first, and may swap their share of the Backline in. A player who
# gets away leaves the battle; the others fight on with larger shares, and one left alone fights on
# with their own full team, as in a battle of their own. Every game ends the battle with its own
# rewards or its own defeat.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpBattlesCoop
  # Frames the host waits for the invited members to join, six seconds.
  JOIN_FRAMES = 360

  # Frames a guest waits for the host's party, ten seconds: longer than the host waits for the
  # players to join after it sent the invite.
  ROSTER_FRAMES = JOIN_FRAMES + 240

  # Frames an invite waits for the player to be free before it is turned down, three seconds.
  ACCEPT_FRAMES = 180

  # Frames a member's battle waits for the party's leader to lead it, six seconds: longer than the
  # leader waits to be free, so a leader who takes it never finds the member gone.
  LEADER_FRAMES = 360

  # Frames a random encounter waits for the party members on the map who are busy, such as in a
  # menu, to come back to it and join, three seconds.
  HOLD_FRAMES = 180

  # Seconds a party member on the map stands still at most once another member met enemies, until
  # they join the battle or turn it down.
  FREEZE_SECONDS = 10

  # What another player does, by their state's scene, while they may be invited: walking the map,
  # reading an event's messages, such as the leader's story, or on the map with their window in the
  # background, which keeps running.
  FREE_SCENES = %w(map event away)

  # Players the characters a player sends are counted for: two, the fewest who share a battle,
  # whose squads are the largest, so a party that loses a player can bring more.
  FEWEST_PLAYERS = 2

  # Characters a player's builds hold at most, the game's largest party.
  MOST_CHARACTERS = 14

  # A player of a co-op battle, or of a side of a team duel. The battle's messages carry a player
  # as their fields in this order.
  #
  # @!attribute seat [Integer] Their world seat.
  # @!attribute name [String] Their name.
  # @!attribute builds [String] Their characters' builds.
  # @!attribute vitals [Array] Their characters' HP and MP.
  # @!attribute max [Integer] Their party_member_max.
  # @!attribute order [Array<Integer>, nil] The order of their places, the Frontline's first, once arranged.
  # @!attribute front [Integer, nil] Their share of the Frontline, once arranged.
  # @!attribute bench [Integer, nil] Their share of the Backline, once arranged.
  Player = Struct.new(:seat, :name, :builds, :vitals, :max, :order, :front, :bench) do
    # Reads a player from the fields a message carries.
    #
    # @param fields [Array, Player] The fields in the order of the attributes, or a player already read.
    # @return [Player] The player.
    def self.read(fields)
      fields.is_a?(self) ? fields : new(*Array(fields).first(members.size))
    end

    # Lists the player's places on the battle's Frontline and on its Backline.
    #
    # @return [Array<Array<Integer>>] The Frontline's places and the Backline's.
    def lines
      places = Array(order)
      [places.first(front.to_i), places[front.to_i, bench.to_i] || []]
    end
  end

  @members = nil
  @players = nil
  @allies = {}

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "co-op battle"

  # The party of the co-op battle running: every player's characters in the order every game shares,
  # only the player's own while the game counts them (see own_only).
  #
  # @return [Array<Game_Actor>, nil] The party, nil outside a co-op battle.
  def self.members
    @own_only && @members ? @members.reject { |actor| actor.is_a?(Game_MpActor) } : @members
  end

  # Runs a block in which the co-op party holds only the player's own characters, such as the end
  # of a battle, which counts each character's battles in the Library all saves share by its id.
  #
  # @yield What counts the party's characters.
  # @return [Object] What the block returns.
  def self.own_only
    was = @own_only
    @own_only = true
    yield
  ensure
    @own_only = was
  end

  # Runs a block in which the Library counts no character's deeds, such as an action between
  # another player's character and someone else, whose count belongs to its owner's game.
  #
  # @yield The deed, such as a defeat or a steal.
  # @return [Object] What the block returns.
  def self.uncounted
    was = @uncounted
    @uncounted = true
    yield
  ensure
    @uncounted = was
  end

  # Reports whether the Library counts no character's deeds now, see uncounted.
  #
  # @return [Boolean] Whether it does not.
  def self.uncounted?
    @uncounted ? true : false
  end

  # Reports whether the Library counts what some characters did: none of them is another player's.
  #
  # @param battlers [Array<Game_Battler, nil>] The characters.
  # @return [Boolean] Whether it does.
  def self.counted?(*battlers)
    battlers.none? { |battler| battler.is_a?(Game_MpActor) }
  end

  # Reports whether a co-op battle's party stands in for the player's.
  #
  # @return [Boolean] Whether one does.
  def self.active?
    !@members.nil?
  end

  # Sends a co-op message to one game or to everyone, who ignore it outside the party.
  #
  # @param seat [Integer] The game's seat, -1 for everyone.
  # @param kind [String] What it is.
  # @param fields [Hash] Its other fields.
  # @return [Boolean] Whether it went out.
  def self.tell(seat, kind, fields)
    sent = MGQ_MpCoop.tell(seat, "coop", kind, fields)
    log("sent #{kind} to #{seat == -1 ? 'the party' : MGQ_MpBattlesSync.who(seat)}: #{fields_text(fields)}#{' (not sent)' unless sent}")
    sent
  end

  # The results of a battle as the game numbers them, for Multiplayer InGame.log.
  RESULTS = { 0 => "won", 1 => "escaped", 2 => "lost" }

  # Writes a message's fields for Multiplayer InGame.log.
  #
  # @param fields [Hash] The fields.
  # @return [String] The fields as name=value pairs.
  def self.fields_text(fields)
    fields.reject { |key, _| key.is_a?(Symbol) }.map { |key, value| "#{key}=#{value}" }.join(" ")
  rescue
    "?"
  end

  # Names a character of a player's builds by its place, for Multiplayer InGame.log.
  #
  # @param members [Array<MGQ_MpActors::Builds::Member>] The player's builds.
  # @param place [Integer] Its place among the player's characters.
  # @return [String] Its actor id, name and level, such as "7 Alice Lv30".
  def self.member_text(members, place)
    member = members[place]
    return "#{place} ?" unless member

    data = $data_actors && $data_actors[member.actor_id]
    "#{member.actor_id} #{data ? data.name : '?'} Lv#{member.base_level}"
  rescue
    "#{place} ?"
  end

  # Describes a battle player's share of the Frontline and of the Backline, for Multiplayer
  # InGame.log.
  #
  # @param player [Player] The player, as arrange gives them.
  # @return [String] Their name, seat and characters per line.
  def self.player_text(player)
    members = MGQ_MpActors::Builds.parse(player.builds.to_s, MOST_CHARACTERS)
    front, back = player.lines
    places = lambda { |line| line.empty? ? "none" : line.map { |place| member_text(members, place) }.join(", ") }
    "#{player.name} (seat #{player.seat}): Frontline #{places.call(front)}; Backline #{places.call(back)}"
  rescue => e
    "#{player.name rescue '?'} (#{e.class})"
  end

  # The host's side.

  # Makes a battle the game just set up a co-op battle: asks the party's leader to lead it when the
  # leader plays on the map, else invites the party members on the map who are playing on it.
  # Called after BattleManager.setup.
  #
  # @param troop_id [Integer] The troop.
  # @param can_escape [Boolean] Whether the party may escape.
  # @param can_lose [Boolean] Whether losing goes on without a game over.
  def self.offer(troop_id, can_escape, can_lose)
    @frozen = nil
    return if @joining
    return unless host_possible?(troop_id)
    return hold(troop_id, can_escape, can_lose) if @encountering && !busy_members.empty?

    @requester, battle_id = @leading
    leader = MGQ_MpCoop::Party.leader
    return ask_leader(leader, troop_id, can_escape, can_lose) if @requester.nil? && candidates.include?(leader)

    log("hosts the battle against troop #{troop_id}: #{host_reason(leader)}")
    host(troop_id, can_escape, can_lose, battle_id)
  rescue => e
    log("could not offer a co-op battle: #{e.class}: #{e.message}")
  end

  # Hosts a co-op battle, inviting the party members on the map who are playing on it, and the
  # member who asked the player to lead it.
  #
  # @param troop_id [Integer] The troop.
  # @param can_escape [Boolean] Whether the party may escape.
  # @param can_lose [Boolean] Whether losing goes on without a game over.
  # @param battle_id [String, nil] The battle's id the member who asked chose, nil for a new one.
  def self.host(troop_id, can_escape, can_lose, battle_id = nil)
    seats = candidates.map(&:seat)
    seats |= [@requester] if @requester
    if seats.empty?
      others = MGQ_MpCoop::Party.members.map { |peer| "#{peer.state['name']} on map #{peer.state['map']} (#{peer.state['scene']})" }
      return log("nobody to invite on map #{$game_map.map_id}: #{others.empty? ? 'no other party member' : others.join(', ')}")
    end

    battle_id ||= new_battle_id
    MGQ_MpBattlesSync.join_world(:host, battle_id, seats, "the party")
    MGQ_MpBattlesSync.battle_started
    MGQ_MpBattles.begin(:coop)
    freeze_party
    tell(-1, "invite", "bid" => battle_id, "troop" => troop_id, "escape" => can_escape ? 1 : 0, "lose" => can_lose ? 1 : 0,
                       "seats" => seats.join(","), "map" => $game_map.map_id)
    log("invited #{seats.size} member(s) to battle #{battle_id} against troop #{troop_id} on map #{$game_map.map_id}: #{seats.map { |seat| MGQ_MpBattlesSync.who(seat) }.join(', ')}")
  rescue => e
    log("could not host a co-op battle: #{e.class}: #{e.message}")
  end

  # Tells why the player hosts a battle instead of asking the party's leader to lead it, for
  # Multiplayer InGame.log.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The party's leader.
  # @return [String] The reason.
  def self.host_reason(leader)
    return "the leader, asked by #{MGQ_MpBattlesSync.who(@requester)}" if @requester
    return "the player leads the party" if leader == :me
    return "no party leader" unless leader

    "the leader #{MGQ_MpOverworldSync.who(leader)} is on map #{leader.state['map']} (#{leader.state['scene']})"
  rescue
    "?"
  end

  # Makes up a battle's id, which its messages carry.
  #
  # @return [String] The id.
  def self.new_battle_id
    MGQ_MpCoop.random_id(8)
  end

  # As a member, asks the party's leader to lead the battle the player's game just set up, which the
  # player then joins as a guest. The battle's start waits for the answer, see await_leader.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer] The party's leader.
  # @param troop_id [Integer] The troop.
  # @param can_escape [Boolean] Whether the party may escape.
  # @param can_lose [Boolean] Whether losing goes on without a game over.
  def self.ask_leader(leader, troop_id, can_escape, can_lose)
    battle_id = new_battle_id
    @asking = { :seat => leader.seat, :bid => battle_id, :troop => troop_id, :escape => can_escape, :lose => can_lose, :answer => nil }
    MGQ_MpBattlesSync.join_world(:guest, battle_id, [leader.seat], leader.state["name"].to_s)
    MGQ_MpBattlesSync.battle_started
    MGQ_MpBattles.begin(:coop)
    freeze_party
    tell(leader.seat, "lead", "bid" => battle_id, "troop" => troop_id, "escape" => can_escape ? 1 : 0, "lose" => can_lose ? 1 : 0,
                              "map" => $game_map.map_id)
    log("asked the leader #{MGQ_MpOverworldSync.who(leader)} to lead battle #{battle_id} against troop #{troop_id} on map #{$game_map.map_id}, waiting up to #{LEADER_FRAMES / 60} s")
  end

  # As a member, waits at the battle's start for the party's leader to lead it. When the leader
  # turns it down, is gone or stays silent for LEADER_FRAMES, the player hosts it instead. Called
  # at the battle's start, before its live side.
  #
  # @param scene [Scene_Battle] The battle.
  def self.await_leader(scene)
    asking = @asking
    return unless asking

    frames = 0
    answer = MGQ_MpBattlesSync::Waiting.wait_for(scene, "Asking #{MGQ_MpBattlesSync.player} to lead the battle...") do
      frames += 1
      asking[:answer] || (frames >= LEADER_FRAMES ? :silent : nil)
    end
    @asking = nil
    return log("#{MGQ_MpBattlesSync.player} leads battle #{asking[:bid]}") if answer == :leads

    # A late invite from the leader must not start this battle anew once it is over.
    @dropped_bid = asking[:bid]
    log("#{MGQ_MpBattlesSync.player} does not lead battle #{asking[:bid]} (#{answer}), the player hosts it")
    MGQ_MpBattlesSync.finish
    MGQ_MpBattles.finish
    host(asking[:troop], asking[:escape], asking[:lose])
  rescue => e
    @asking = nil
    MGQ_MpBattlesSync.finish
    MGQ_MpBattles.finish
    log("waiting for the leader failed: #{e.class}: #{e.message}")
  end

  # Reports whether a battle starting now may become a co-op battle: in a party of an open world,
  # and no other multiplayer battle or Library replay running.
  #
  # @param troop_id [Integer, nil] The battle's troop, for Multiplayer InGame.log.
  # @return [Boolean] Whether it may.
  def self.host_possible?(troop_id = nil)
    return false unless MGQ_MpOverworldSync.in_world?

    reason = if !MGQ_MpCoop::Party.id then "not in a party"
             elsif $game_temp && $game_temp.in_memory_battle then "a Library replay"
             elsif defined?(MGQ_MpBattlesPvp) && MGQ_MpBattlesPvp::Battle.running? then "a PvP battle runs"
             elsif MGQ_MpBattlesSync.role || MGQ_MpBattles.running?
               "another multiplayer battle still runs (#{MGQ_MpBattlesSync.role.inspect}, #{MGQ_MpBattles.kind.inspect})"
             end
    log("no co-op battle against troop #{troop_id}: #{reason}") if reason
    reason.nil?
  end

  # Lists the party members who may join: on the player's map, playing on it.
  #
  # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The members.
  def self.candidates
    MGQ_MpCoop::Party.members.select { |peer| peer.state["map"].to_i == $game_map.map_id && FREE_SCENES.include?(peer.state["scene"]) }
  end

  # Lists the party members on the player's map who could join once back on it: in a menu, typing
  # or on a vehicle, but not in a battle of their own.
  #
  # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The members.
  def self.busy_members
    MGQ_MpCoop::Party.members.select do |peer|
      peer.state["map"].to_i == $game_map.map_id && !FREE_SCENES.include?(peer.state["scene"]) && peer.state["scene"] != "battle"
    end
  end

  # Runs the game's random encounter, which holds its battle while party members on the map are
  # busy (see hold). Called by Game_Player#encounter.
  #
  # @yieldreturn [Boolean] Whether the game's encounter starts a battle.
  # @return [Boolean] Whether the battle starts now.
  def self.encounter
    return false if @hold

    @encountering = true
    starts = yield
    starts && !@hold
  ensure
    @encountering = false
  end

  # Reports whether a random encounter waits for busy party members, while the player stands still.
  #
  # @return [Boolean] Whether one does.
  def self.holding?
    !@hold.nil?
  end

  # Forgets a held encounter without starting it.
  def self.drop_hold
    @hold = nil
    MGQ_MpNotices.drop(:hold) if defined?(MGQ_MpNotices)
  end

  # Holds a random encounter the game just set up for up to HOLD_FRAMES, telling the busy party
  # members on the map, so they can come back to the map and join; see tick_hold.
  #
  # @param troop_id [Integer] The troop.
  # @param can_escape [Boolean] Whether the party may escape.
  # @param can_lose [Boolean] Whether losing goes on without a game over.
  def self.hold(troop_id, can_escape, can_lose)
    busy = busy_members
    @hold = { :troop => troop_id, :escape => can_escape, :lose => can_lose, :frames => HOLD_FRAMES, :seats => busy.map(&:seat) }
    busy.each { |peer| tell(peer.seat, "soon", "map" => $game_map.map_id) }
    freeze_party
    names = busy.map { |peer| peer.state["name"].to_s }.join(", ")
    MGQ_MpNotices.message(:hold, "Enemies! Waiting for #{names}", HOLD_FRAMES) if defined?(MGQ_MpNotices)
    log("held an encounter with troop #{troop_id} up to #{HOLD_FRAMES / 60} s for the busy members #{busy.map { |peer| "#{MGQ_MpOverworldSync.who(peer)} (#{peer.state['scene']})" }.join(', ')}")
  end

  # Starts the held encounter once every busy member came back to the map or HOLD_FRAMES passed,
  # inviting whoever plays on the map then. An event that started meanwhile drops it. Called by
  # the map every frame.
  def self.tick_hold
    hold = @hold
    hold[:frames] -= 1
    waiting = busy_members.select { |peer| hold[:seats].include?(peer.seat) }
    return unless waiting.empty? || hold[:frames] <= 0

    drop_hold
    return log("dropped the held encounter with troop #{hold[:troop]} for an event") if $game_map.interpreter.running?

    log("starts the held encounter with troop #{hold[:troop]}: #{waiting.empty? ? 'every busy member is back on the map' : "the wait ran out, #{waiting.map { |peer| MGQ_MpOverworldSync.who(peer) }.join(', ')} still busy"}")
    offer(hold[:troop], hold[:escape], hold[:lose])
    SceneManager.call(Scene_Battle)
  end

  # Tells the player for a moment that a party member on their map met enemies, whose battle waits
  # for them to come back to the map.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  def self.take_soon(peer)
    MGQ_MpNotices.message([:soon, peer.seat], "#{peer.state['name']} is in a battle!", HOLD_FRAMES) if defined?(MGQ_MpNotices)
  end

  # Tells every party member that the player met enemies on their map, so the members there stand
  # still until the battle invites them.
  def self.freeze_party
    tell(-1, "freeze", "map" => $game_map.map_id)
  end

  # Holds the player once a party member on their map met enemies, until the player joins the
  # battle, turns it down or FREEZE_SECONDS pass, so nobody walks off before the invite comes.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member who met them.
  # @param message [Hash] The message, the member's map under "map".
  def self.take_freeze(peer, message)
    return log("not standing still for #{MGQ_MpOverworldSync.who(peer)}: their map #{message['map']} is not the player's #{$game_map.map_id}") unless message["map"].to_i == $game_map.map_id
    return log("not standing still for #{MGQ_MpOverworldSync.who(peer)}: the player is in a battle") if MGQ_MpBattlesSync.role || SceneManager.scene.is_a?(Scene_Battle)

    @frozen = Time.now
    MGQ_MpNotices.message([:soon, peer.seat], "Enemies! #{peer.state['name']} is in a battle.", HOLD_FRAMES) if defined?(MGQ_MpNotices)
    log("stands still up to #{FREEZE_SECONDS} s: #{MGQ_MpOverworldSync.who(peer)} met enemies on map #{$game_map.map_id}")
  end

  # Reports whether the player stands still for a party member's battle on their map.
  #
  # @return [Boolean] Whether they do.
  def self.frozen?
    return false unless @frozen
    return true if Time.now - @frozen < FREEZE_SECONDS

    @frozen = nil
    log("stands still no more: no invite came within #{FREEZE_SECONDS} s")
    false
  end

  # As host, waits for the invited members to join or turn the battle down, then sends everyone the
  # party and the battle's level and builds the party. Without anyone joining, the battle is the host's own. Called at the battle's start.
  #
  # @param scene [Scene_Battle] The battle.
  # @return [Symbol, nil] An ending of battles_sync's Channel.ending, nil once the battle may start.
  def self.gather(scene)
    channel = MGQ_MpBattlesSync::Channel
    invited = MGQ_MpBattlesSync.seats
    joined = {}
    answered = []
    outcomes = {}
    frames = 0
    answer = MGQ_MpBattlesSync::Waiting.wait_for(scene, "Gathering the party...") do
      invited.each do |seat|
        next if answered.include?(seat)

        body = channel.take_from("join", seat)
        joined[seat] = body if body
        outcome = if body then "joined (#{body.to_s.size} bytes)"
                  elsif channel.take_from("decline", seat) then "declined"
                  elsif MGQ_MpOverworldSync::Peers.at(seat).nil? then "left the world"
                  end
        next unless outcome

        answered << seat
        outcomes[seat] = outcome
      end
      frames += 1
      answered.size == invited.size || frames >= JOIN_FRAMES ? true : nil
    end
    log("gathered battle #{MGQ_MpBattlesSync.battle_id} after #{frames} frames (#{answer.inspect}): " +
        invited.map { |seat| "#{MGQ_MpBattlesSync.who(seat)} #{outcomes[seat] || 'did not answer'}" }.join(", "))
    return answer if answer.is_a?(Symbol) && answer != :gone
    return call_off if @requester && !joined.key?(@requester)
    return stand_down if joined.empty? || answer == :gone

    MGQ_MpBattlesSync.keep_seats(joined.keys)
    players = [[MGQ_MpOverworldSync::Me.seat, MGQ_Multiplayer::Player.name.to_s] + own_build]
    joined.keys.sort.each do |seat|
      builds, vitals, max = MGQ_MpBattlesSync::Wire.parse(joined[seat].to_s)
      # A player who joined may have left the world since; their characters fight on all the same.
      peer = MGQ_MpOverworldSync::Peers.at(seat)
      players << [seat, peer ? peer.state["name"].to_s : "?", builds.to_s, Array(vitals), max.to_i]
    end
    players = arrange(players)
    level = MGQ_MpCoopLevelSync.level_for(players)
    roster = MGQ_MpBattlesSync::Wire.line([troop_entries, players.map(&:to_a), level.to_i])
    channel.post("roster", roster)
    log("sent the roster of battle #{MGQ_MpBattlesSync.battle_id} (#{roster.size} bytes): #{$game_troop.members.size} enemies, #{players.size} players, level #{level.inspect}")
    MGQ_MpCoopLevelSync.begin(level)
    form(scene, players)
    log("battle #{MGQ_MpBattlesSync.battle_id} with #{players.size} players")
    nil
  end

  # Ends a battle the player leads for a member before it began, since that member did not join:
  # the encounter was theirs, and everyone else who joined leaves it too.
  #
  # @return [Symbol] :broken, which ends the battle.
  def self.call_off
    log("the member who asked to lead battle #{MGQ_MpBattlesSync.battle_id} did not join it")
    MGQ_MpBattlesSync.break_off("the member who asked for it did not join")
    :broken
  end

  # Ends the co-op battle before it began, since nobody joined: the battle is the host's own.
  #
  # @return [nil] Nothing, the battle starts.
  def self.stand_down
    log("nobody joined battle #{MGQ_MpBattlesSync.battle_id}")
    MGQ_MpBattlesSync.finish
    MGQ_MpBattles.finish
    nil
  end

  # The guest's side.

  # Takes a co-op message. Called by coop.rbx.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it.
  # @param message [Hash] The message's fields.
  def self.take(peer, message)
    log("took #{message['coop']} from #{MGQ_MpOverworldSync.who(peer)}: #{fields_text(message.reject { |key, _| key == 'coop' })}")
    case message["coop"]
    when "invite" then take_invite(peer, message)
    when "lead" then take_request(peer, message)
    when "no_lead" then answer_of(peer, message, :refused)
    when "soon" then take_soon(peer)
    when "freeze" then take_freeze(peer, message)
    end
  rescue => e
    log("taking a co-op message failed: #{e.class}: #{e.message}")
  end

  # Takes an invite to a battle: the answer of the leader the player asked to lead their battle, or
  # an invite to join on the map, which a player in a battle of their own turns down at once.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The host.
  # @param message [Hash] The invite.
  def self.take_invite(peer, message)
    unless message["seats"].to_s.split(",").map(&:to_i).include?(MGQ_MpOverworldSync::Me.seat)
      return log("invite to battle #{message['bid']} ignored: it is for seats #{message['seats']}, not the player's")
    end
    return answer_of(peer, message, :leads) if asked?(peer, message)

    # Turned down at once, so the host need not wait for the player: while the player waits for the
    # leader, or is in a battle, and the leader's late invite to a battle the player hosts instead.
    reason = if @asking then "the player waits for the leader to lead battle #{@asking[:bid]}"
             elsif message["bid"] == @dropped_bid then "a late invite to a battle the player hosts instead"
             elsif MGQ_MpBattlesSync.role then "the player is in a multiplayer battle (#{MGQ_MpBattlesSync.role})"
             elsif SceneManager.scene.is_a?(Scene_Battle) then "the player is in a battle"
             end
    if reason
      log("declined #{MGQ_MpOverworldSync.who(peer)}'s invite to battle #{message['bid']} at once: #{reason}")
      return MGQ_MpBattlesSync.tell(peer.seat, "decline", message["bid"].to_s)
    end

    log("replaced the waiting invite to battle #{@invite[:message]['bid']} with #{MGQ_MpOverworldSync.who(peer)}'s") if @invite
    @invite = { :peer => peer, :message => message, :at => Time.now }
    log("keeps #{MGQ_MpOverworldSync.who(peer)}'s invite to battle #{message['bid']} against troop #{message['troop']} on map #{message['map']} until the player is free, #{ACCEPT_FRAMES / 60} s at most")
  end

  # Keeps a member's request that the player lead their battle, refusing an earlier one that waits
  # still, whose member would otherwise wait for an answer in vain.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @param message [Hash] The request.
  def self.take_request(peer, message)
    waiting = @request
    if waiting && !(waiting[:peer].equal?(peer) && waiting[:message]["bid"] == message["bid"])
      refuse_lead(waiting[:peer], waiting[:message], "a newer request from #{MGQ_MpOverworldSync.who(peer)} came")
    end
    @request = { :peer => peer, :message => message, :at => Time.now }
    log("keeps #{MGQ_MpOverworldSync.who(peer)}'s request to lead battle #{message['bid']} against troop #{message['troop']} on map #{message['map']} until the player is free, #{ACCEPT_FRAMES / 60} s at most")
  end

  # Reports whether an invite or a request to lead waited longer than ACCEPT_FRAMES. It counts by the
  # clock, since one that arrived outside the map waits for the map, where the frames count.
  #
  # @param entry [Hash] The invite or the request, with :at, when it arrived.
  # @return [Boolean] Whether it did.
  def self.expired?(entry)
    Time.now - entry[:at] > ACCEPT_FRAMES / 60.0
  end

  # Notes the leader's answer to the player's request to lead their battle.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who answered.
  # @param message [Hash] The answer.
  # @param answer [Symbol] :leads or :refused.
  def self.answer_of(peer, message, answer)
    return log("#{answer} answer for battle #{message['bid']} from #{MGQ_MpOverworldSync.who(peer)} ignored: not the battle the player asked about") unless asked?(peer, message)

    @asking[:answer] = answer
    log("the leader #{MGQ_MpOverworldSync.who(peer)} answered for battle #{message['bid']}: #{answer}")
  end

  # Reports whether a message answers the player's request to lead their battle: from the leader
  # asked, about that battle.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who sent it.
  # @param message [Hash] The message.
  # @return [Boolean] Whether it does.
  def self.asked?(peer, message)
    asking = @asking
    !asking.nil? && peer.seat == asking[:seat] && message["bid"] == asking[:bid]
  end

  # Leads a member's battle once the player is free on the map, refuses it otherwise, then joins an
  # invite once the player is free on the map, or turns it down when they stay busy. Called by the
  # map every frame, so the battle starts as an encounter would.
  def self.on_map
    return tick_hold if @hold

    serve_request if @request
    return unless @invite

    invite = @invite
    peer = invite[:peer]
    message = invite[:message]
    return decline(peer, message, "the player is on map #{$game_map.map_id}, not #{message['map']}") unless message["map"].to_i == $game_map.map_id
    return decline(peer, message, "the player is in a multiplayer battle (#{MGQ_MpBattlesSync.role})") unless MGQ_MpBattlesSync.role.nil?
    return decline(peer, message, "the player stayed busy for #{ACCEPT_FRAMES / 60} s") if expired?(invite)
    return decline(peer, message, "the leader's story is about to bring the player over") if MGQ_MpCoopGather.coming?
    return unless free?

    @invite = nil
    accept(peer, message)
  rescue => e
    @invite = nil
    log("joining a co-op battle failed: #{e.class}: #{e.message}")
  end

  # As the party's leader, leads a member's battle once the player is free on the member's map, or
  # refuses it when the player is elsewhere, busy for ACCEPT_FRAMES or no longer the leader.
  def self.serve_request
    request = @request
    peer = request[:peer]
    message = request[:message]
    return refuse_lead(peer, message, "the player is on map #{$game_map.map_id}, not #{message['map']}") unless message["map"].to_i == $game_map.map_id
    return refuse_lead(peer, message, "the player is in a multiplayer battle (#{MGQ_MpBattlesSync.role})") unless MGQ_MpBattlesSync.role.nil?
    return refuse_lead(peer, message, "the player no longer leads the party") unless MGQ_MpCoop::Party.leader == :me
    return refuse_lead(peer, message, "the player stayed busy for #{ACCEPT_FRAMES / 60} s") if expired?(request)
    return refuse_lead(peer, message, "the player's story is about to bring them over") if MGQ_MpCoopGather.coming?
    return unless free?

    @request = nil
    lead(peer, message)
  rescue => e
    @request = nil
    log("leading a member's battle failed: #{e.class}: #{e.message}")
  end

  # Starts a member's battle as its host, with the id the member chose; the member joins it.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @param message [Hash] The member's request.
  def self.lead(peer, message)
    @leading = [peer.seat, message["bid"].to_s]
    BattleManager.setup(message["troop"].to_i, message["escape"] == "1", message["lose"] == "1")
    return refuse_lead(peer, message, "the battle did not become a co-op battle the player hosts (#{MGQ_MpBattlesSync.role.inspect})") unless MGQ_MpBattlesSync.role == :host

    SceneManager.call(Scene_Battle)
    log("leads #{peer.state['name']}'s battle #{message['bid']} against troop #{message['troop']}")
  ensure
    @leading = nil
  end

  # Refuses to lead a member's battle, which the member then hosts.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @param message [Hash] The member's request.
  # @param reason [String] Why, for Multiplayer InGame.log.
  def self.refuse_lead(peer, message, reason = "?")
    @request = nil
    tell(peer.seat, "no_lead", "bid" => message["bid"].to_s)
    log("could not lead #{peer.state['name']}'s battle #{message['bid']}: #{reason}")
  end

  # Reports whether the player may join a battle: on the map, with no event or transfer of their own.
  #
  # @return [Boolean] Whether they may.
  def self.free?
    !$game_map.interpreter.running? && !$game_player.transfer? && !$game_player.moving?
  end

  # Starts the invited battle as a guest.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The host.
  # @param message [Hash] The invite.
  def self.accept(peer, message)
    @frozen = nil
    # The leader's story dialogue a member reads may be on screen; the battle takes its place.
    $game_message.clear
    @joining = true
    BattleManager.setup(message["troop"].to_i, message["escape"] == "1", message["lose"] == "1")
    MGQ_MpBattlesSync.join_world(:guest, message["bid"].to_s, [peer.seat], peer.state["name"].to_s)
    MGQ_MpBattlesSync.battle_started
    MGQ_MpBattles.begin(:coop)
    SceneManager.call(Scene_Battle)
    log("joined #{peer.state['name']}'s battle #{message['bid']} against troop #{message['troop']}")
  ensure
    @joining = false
  end

  # Turns an invite down, so the host need not wait for the player.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The host.
  # @param message [Hash] The invite.
  # @param reason [String] Why, for Multiplayer InGame.log.
  def self.decline(peer, message, reason = "?")
    @invite = nil
    @frozen = nil
    log("declined #{MGQ_MpOverworldSync.who(peer)}'s invite to battle #{message['bid']}: #{reason}")
    MGQ_MpBattlesSync.tell(peer.seat, "decline", message["bid"].to_s)
  end

  # As guest, tells the host who joins and builds the party the host sends. Called at the battle's start.
  #
  # @param scene [Scene_Battle] The battle.
  # @return [Symbol, nil] An ending of battles_sync's Channel.ending, nil once the battle may start.
  def self.join(scene)
    # The host's party says how many of them fight and how many wait on the Backline.
    build = own_build
    MGQ_MpBattlesSync::Channel.post("join", MGQ_MpBattlesSync::Wire.line(build))
    log("sent join for battle #{MGQ_MpBattlesSync.battle_id} with #{Array(build[1]).size} characters, party_member_max #{build[2]}, waiting up to #{ROSTER_FRAMES / 60} s for the roster")
    frames = 0
    roster = MGQ_MpBattlesSync::Waiting.wait_for(scene, "Joining #{MGQ_MpBattlesSync.player}'s battle...") do
      frames += 1
      MGQ_MpBattlesSync::Channel.take("roster") || (frames >= ROSTER_FRAMES ? :late : nil)
    end
    return left_out("the host's party never came") if roster == :late
    if roster.is_a?(Symbol)
      log("no roster for battle #{MGQ_MpBattlesSync.battle_id}: the wait ended with #{roster.inspect}")
      return roster
    end

    enemies, players, level = MGQ_MpBattlesSync::Wire.parse(roster.to_s)
    players = Array(players).map { |fields| Player.read(fields) }
    log("took the roster of battle #{MGQ_MpBattlesSync.battle_id} (#{roster.to_s.size} bytes): #{Array(enemies).size} enemies, #{players.size} players, level #{level.inspect}")
    return left_out("the host's party came without the player") unless players.any? { |player| player.seat == MGQ_MpOverworldSync::Me.seat }

    take_troop(scene, Array(enemies))
    MGQ_MpCoopLevelSync.begin(level)
    form(scene, players)
    nil
  end

  # Ends a guest's battle the host's party left out, since the guest joined after the host stopped
  # waiting.
  #
  # @param reason [String] Why, for Multiplayer InGame.log.
  # @return [Symbol] :broken, which ends the battle.
  def self.left_out(reason)
    log("left out of battle #{MGQ_MpBattlesSync.battle_id}: #{reason}")
    MGQ_MpBattlesSync.break_off(reason, false)
    :broken
  end

  # Describes the troop's enemies as the guests rebuild them.
  #
  # @return [Array<Array>] Each enemy's id, screen x and y, and 1 when hidden, else 0.
  def self.troop_entries
    $game_troop.members.map { |enemy| [enemy.enemy_id, enemy.screen_x, enemy.screen_y, enemy.hidden? ? 1 : 0] }
  end

  # As guest, fights the host's enemies in place of the player's own, which mods of either game
  # may have changed, such as one that doubles them: the host names every enemy by its place.
  #
  # @param scene [Scene_Battle] The battle.
  # @param enemies [Array<Array>] The host's enemies, see troop_entries.
  def self.take_troop(scene, enemies)
    return if enemies.empty?
    return log("the host's troop of #{enemies.size} enemies matches this game's own") if enemies == troop_entries
    unless enemies.all? { |id, *| $data_enemies[id.to_i] }
      missing = enemies.map { |id, *| id.to_i }.reject { |id| $data_enemies[id] }
      return log("the host's troop holds enemies this game lacks (#{missing.join(', ')}); it keeps its own")
    end

    rebuilt = enemies.each_with_index.map do |(id, x, y, hidden), index|
      enemy = Game_Enemy.new(index, id.to_i)
      enemy.screen_x = x.to_i
      enemy.screen_y = y.to_i
      enemy.hide if hidden.to_i == 1
      enemy
    end
    MGQ_MpGame.set($game_troop, :enemies, rebuilt)
    # The game counts each name's enemies for their letters, so the count starts over as in setup.
    MGQ_MpGame.set($game_troop, :names_count, {})
    MGQ_MpGame.call($game_troop, :make_unique_names)
    spriteset = MGQ_MpGame.get(scene, :spriteset)
    if spriteset
      spriteset.dispose_enemies
      spriteset.create_enemies
    end
    log("took the host's troop of #{rebuilt.size} enemies in place of this game's own: #{rebuilt.map { |enemy| "#{enemy.enemy_id} #{enemy.name}#{' (hidden)' if enemy.hidden?}" }.join(', ')}")
  rescue => e
    log("taking the host's troop failed: #{e.class}: #{e.message}")
  end

  # Both sides.

  # Writes the player's characters for a co-op battle: as many as their squad holds with the fewest
  # players, which the battle's places then count. Starts the battle's party anew.
  #
  # @return [Array] The builds, see MGQ_MpActors::Builds, each character's HP and MP, and the
  #   player's party_member_max, which decides their share of the Backline.
  def self.own_build
    max = $game_party.party_member_max
    front, bench = MGQ_MpCoopSquad.share(0, FEWEST_PLAYERS, max)
    @own_squad = MGQ_MpCoopSquad.own_order.first(front + bench)
    @allies = {}
    log("brings #{@own_squad.size} characters (up to #{front} + #{bench} of party_member_max #{max}): #{squad_text}")
    [MGQ_MpActors::Builds.write(@own_squad), @own_squad.map { |actor| [actor.hp, actor.mp] }, max]
  end

  # Describes the player's characters a battle may take, for Multiplayer InGame.log.
  #
  # @return [String] Each character's id, name, level and HP.
  def self.squad_text
    Array(@own_squad).map { |actor| "#{MGQ_MpBattlesSync.named(actor)} Lv#{actor.base_level rescue '?'} #{actor.hp}/#{actor.mhp} HP" }.join(", ")
  rescue
    "?"
  end

  # Writes the player's Frontline for a team duel, whose places its characters count, and starts the
  # duel's party anew.
  #
  # @return [Array] The builds, see MGQ_MpActors::Builds, and the player's party_member_max.
  def self.team_build
    @own_squad = MGQ_MpCoopSquad.own_order.first(MGQ_MpCoopSquad::FRONTLINE)
    @allies = {}
    log("brings #{@own_squad.size} characters to a team duel: #{squad_text}")
    [MGQ_MpActors::Builds.write(@own_squad), $game_party.party_member_max]
  end

  # Orders the battle's players as their party does, the leader first, and tells each player's
  # share of the Frontline and of the Backline in the battle, and the order of their places.
  #
  # @param players [Array<Player, Array>] The players, or their fields: at least each one's seat,
  #   name, builds, HP and MP and party_member_max.
  # @param backline [Boolean] Whether the players bring a share of the Backline, which a team duel's
  #   do not.
  # @return [Array<Player>] The players in the party's order, each with the order of their places
  #   and their shares of the Frontline and of the Backline.
  def self.arrange(players, backline = true)
    players = players.map { |fields| Player.read(fields) }
    ranked = MGQ_MpCoopSquad.ranked(players.map { |player| [player_id(player.seat), leads?(player.seat)] })
    players = players.sort_by { |player| ranked.index(player_id(player.seat)) }
    players.each_with_index.map do |player, position|
      count = MGQ_MpActors::Builds.parse(player.builds.to_s, MOST_CHARACTERS).size
      front, bench = MGQ_MpCoopSquad.share(position, players.size, player.max.to_i)
      front = [front, count].min
      bench = backline ? [bench, count - front].min : 0
      Player.new(player.seat, player.name, player.builds, player.vitals, player.max, valid_order(player.order, count), front, bench)
    end
  end

  # Tells a battle player's id, which orders the players as their party does.
  #
  # @param seat [Integer] The player's world seat.
  # @return [String] The id, empty when unknown.
  def self.player_id(seat)
    return MGQ_MpOverworldSync::Me.id if seat == MGQ_MpOverworldSync::Me.seat

    peer = MGQ_MpOverworldSync::Peers.at(seat)
    peer ? peer.state["id"].to_s : ""
  end

  # Reports whether a battle player leads the party.
  #
  # @param seat [Integer] The player's world seat.
  # @return [Boolean] Whether they do.
  def self.leads?(seat)
    player = seat == MGQ_MpOverworldSync::Me.seat ? :me : MGQ_MpOverworldSync::Peers.at(seat)
    player ? MGQ_MpCoop.leads?(player) : false
  end

  # Checks the order of a player's places, which another game sent.
  #
  # @param order [Array, nil] The places, the Frontline's first.
  # @param count [Integer] The player's characters.
  # @return [Array<Integer>] The order, the characters' own order when there was none or it is broken.
  def self.valid_order(order, count)
    order.is_a?(Array) && order.sort == (0...count).to_a ? order.dup : (0...count).to_a
  end

  # Lists the world seats of the battle's players.
  #
  # @return [Array<Integer>] The seats, the player's own included; none before the party is formed.
  def self.player_seats
    Array(@players).map(&:seat)
  end

  # Finds the player's own entry among the battle's players.
  #
  # @return [Player, nil] The entry, see arrange, nil outside a co-op battle.
  def self.own_player
    Array(@players).find { |player| player.seat == MGQ_MpOverworldSync::Me.seat }
  end

  # Lists the player's own characters on the battle's Backline, those they may swap in.
  #
  # @return [Array<Game_Actor>] The characters.
  def self.own_bench
    player = own_player
    player && @own_squad ? player.lines[1].map { |place| @own_squad[place] }.compact : []
  end

  # The order of the player's places, which their commands tell the host.
  #
  # @return [Array<Integer>, nil] The places, the Frontline's first, nil outside a co-op battle.
  def self.own_order
    player = own_player
    player && player.order
  end

  # Builds the co-op party every game shares, in the host's order: each player's share of the
  # Frontline, the player's own characters as they are, everyone else's rebuilt with their HP and
  # MP. Others' characters the battle had before stay as they are, with what the battle did to them.
  # Those above the battle's level fight at it (see battles_coop_level_sync.rbx).
  #
  # @param scene [Scene_Battle] The battle.
  # @param players [Array<Player, Array>] The players as arrange gives them, or their fields.
  def self.form(scene, players)
    @players = players.map { |fields| Player.read(fields) }
    @own_squad ||= MGQ_MpCoopSquad.own_order
    members = []
    @players.each do |player|
      front = player.lines[0]
      if player.seat == MGQ_MpOverworldSync::Me.seat
        members.concat(front.map { |place| @own_squad[place] }.compact)
      else
        members.concat(front.map { |place| ally(player.seat, player.name, player.builds, player.vitals, place) }.compact)
      end
    end
    members.each { |actor| MGQ_MpCoopLevelSync.sync(actor) }
    @members = members
    log_party
    show_party(scene, members)
  end

  # Logs who brings which characters and the party that fights, as form built it.
  def self.log_party
    log("party of #{@players.size} players: #{@players.map { |player| player_text(player) }.join(' | ')}")
    log("fighting: #{members_text(@members)}")
  rescue => e
    log("party unknown: #{e.class}")
  end

  # Describes characters of a battle with their HP, for Multiplayer InGame.log.
  #
  # @param actors [Array<Game_Actor>] The characters.
  # @return [String] Each character's id, name and HP.
  def self.members_text(actors)
    Array(actors).map { |actor| "#{MGQ_MpBattlesSync.named(actor)} #{actor.hp}/#{actor.mhp} HP" }.join(", ")
  rescue
    "#{Array(actors).size} characters"
  end

  # Finds another player's character, rebuilt the first time the battle needs it.
  #
  # @param seat [Integer] Its owner's world seat.
  # @param name [String] Its owner's name.
  # @param builds [String] Its owner's builds.
  # @param vitals [Array] Its owner's characters' HP and MP.
  # @param place [Integer] Its place among its owner's characters.
  # @return [Game_MpAlly, nil] The character, nil when the builds hold none at that place.
  def self.ally(seat, name, builds, vitals, place)
    @allies[[seat, place]] ||= begin
      member = MGQ_MpActors::Builds.parse(builds.to_s, MOST_CHARACTERS)[place]
      member && new_ally(member, name.to_s, seat, place, Array(vitals)[place])
    end
  end

  # Rebuilds another player's character for the battle, with the HP and MP it has in their game, a
  # fallen one fallen.
  #
  # The game starts a battle only for the characters of its own party, which leaves the counters of
  # a rebuilt one unset.
  #
  # @param member [MGQ_MpActors::Builds::Member] The character's build.
  # @param name [String] Its owner's name.
  # @param seat [Integer] Its owner's world seat.
  # @param place [Integer] Its place among its owner's characters.
  # @param vitals [Array, nil] Its HP and MP, none for a character at full HP and MP.
  # @return [Game_MpAlly] The character.
  def self.new_ally(member, name, seat, place, vitals)
    ally = Game_MpAlly.new(member, name, seat, place)
    ally.on_battle_start
    hp, mp = Array(vitals)
    ally.hp = hp if hp.is_a?(Integer) && hp >= 0
    ally.mp = mp if mp.is_a?(Integer)
    log_rebuild(ally, member, place, vitals)
    check(ally)
    ally
  end

  # Logs another player's character as new_ally rebuilt it.
  #
  # @param ally [Game_MpAlly] The character.
  # @param member [MGQ_MpActors::Builds::Member] Its build.
  # @param place [Integer] Its place among its owner's characters.
  # @param vitals [Array, nil] The HP and MP its owner sent.
  def self.log_rebuild(ally, member, place, vitals)
    log("rebuilt #{MGQ_MpBattlesSync.named(ally)} of seat #{ally.mp_seat}, place #{place}, Lv#{member.base_level}: #{ally.hp}/#{ally.mhp} HP, " \
        "#{ally.mp}/#{ally.mmp} MP#{', fallen' if ally.hp <= 0}#{', full HP and MP as none were sent' unless vitals}")
  rescue => e
    log("rebuilt #{MGQ_MpBattlesSync.named(ally)} of seat #{ally.mp_seat rescue '?'}, place #{place}, its HP unknown: #{e.class}")
  end

  # Logs where a rebuilt character's stats or rates, its counter rate among them, differ from what
  # its owner's game showed, which tells a counter the host's battle never makes. Its owner's game
  # measured without the PvP balance of a team duel.
  #
  # @param ally [Game_MpAlly] The rebuilt character.
  def self.check(ally)
    differences = defined?(MGQ_MpBalancePvp) ? MGQ_MpBalancePvp.unbalanced { ally.differences } : ally.differences
    log("#{ally.name} differs: #{differences.join(', ')}") unless differences.empty?
  rescue => e
    log_once(:check, "could not check a rebuild: #{e.class}: #{e.message}")
  end

  # Shows a party in the battle's windows, which the scene made for the player's own party: the
  # status window, and the game's window per character, which takes its character only when made.
  #
  # @param scene [Scene_Battle] The battle.
  # @param members [Array<Game_Actor>] The party.
  def self.show_party(scene, members)
    Array(MGQ_MpGame.get(scene, :battle_actor_status_windows)).each_with_index { |window, index| window.actor = members[index] }
    MGQ_MpGame.call(scene, :refresh_status) if scene.respond_to?(:refresh_status, true)
  rescue => e
    log("showing the party failed: #{e.class}: #{e.message}")
  end

  # As host, takes the players who left out of the party, before a command phase: the others fight
  # on, each bringing as many as the smaller party lets them, told to the guests between two of the
  # host's sends. Alone, the host fights on with their own full team, as in a battle of their own.
  # Called when a command phase starts.
  #
  # @param scene [Scene_Battle] The battle.
  def self.settle(scene)
    return unless active?

    staying = @players.select { |player| player.seat == MGQ_MpOverworldSync::Me.seat || MGQ_MpBattlesSync.guests_in.include?(player.seat) }
    return if staying.size == @players.size

    log("#{(@players - staying).map { |player| "#{player.name} (seat #{player.seat})" }.join(', ')} left battle #{MGQ_MpBattlesSync.battle_id}, their characters leave the party")
    return go_solo(scene) if staying.size == 1

    form(scene, arrange(staying))
    post_party
    log("#{staying.size} players fight on")
  rescue => e
    log("settling the party failed: #{e.class}: #{e.message}")
  end

  # As guest, takes the party the host sent after a player left or swapped.
  #
  # @param scene [Scene_Battle] The battle.
  # @param body [String] The party, see post_party.
  def self.reform(scene, body)
    log("took the host's new party (#{body.to_s.size} bytes)")
    players = MGQ_MpBattlesSync::Wire.parse(body.to_s)
    form(scene, Array(players && players[0]))
  rescue => e
    log("taking the new party failed: #{e.class}: #{e.message}")
  end

  # As host, fights on alone with the player's own full team, as in a battle of their own.
  #
  # @param scene [Scene_Battle] The battle.
  def self.go_solo(scene)
    log("everyone else left battle #{MGQ_MpBattlesSync.battle_id}, it goes on alone")
    stand_alone(scene)
  end

  # As guest, fights on alone once the host got away or is gone: the player's own full team takes
  # the battle over from where the host's stream left it, as a battle of their own.
  #
  # The guest's battle never started as the game starts one, since the host's stream stood in for
  # it: one the host left before its party came starts now, one it left later gets the counters
  # the start sets.
  #
  # @param scene [Scene_Battle] The battle.
  def self.take_over(scene)
    formed = active?
    log("the host left battle #{MGQ_MpBattlesSync.battle_id}, it goes on alone #{formed ? 'from where the stream left it' : 'from its start, the host party never came'}")
    stand_alone(scene)
    if formed
      resume_alone
      BattleManager.turn_end
    else
      BattleManager.battle_start
      scene.process_event if scene.respond_to?(:process_event)
    end
    scene.start_party_command_selection
  rescue => e
    log("taking the battle over failed: #{e.class}: #{e.message}")
    BattleManager.process_abort
  end

  # Readies the battle a guest takes over from the host's stream: the counters the game sets for
  # every battler at a battle's start, keeping the barriers the stream gave, and a defeat scene,
  # which the game picks at the start and with each enemy's action.
  def self.resume_alone
    ($game_party.battle_members + $game_troop.members).each do |battler|
      next unless battler.respond_to?(:set_counter)

      walls = battler.respond_to?(:defence_wall) ? battler.defence_wall : nil
      battler.set_counter
      MGQ_MpBattlesSync::Playback.set_walls(battler, walls) if walls
    end
    return unless $game_temp.respond_to?(:lose_event_id) && $game_temp.lose_event_id.to_i <= 0

    enemy = $game_troop.members.sample
    return unless enemy && enemy.respond_to?(:lose_event_id)

    $game_temp.lose_event_id = enemy.lose_event_id
    $game_temp.lose_event_enemy_id = enemy.id
    log("picked the defeat scene of enemy #{enemy.enemy_id rescue '?'} #{enemy.name rescue '?'} (event #{enemy.lose_event_id})")
  end

  # Ends the co-op side of the battle, which goes on as the player's own: their own full team, the
  # game's own settings, no live battle.
  #
  # @param scene [Scene_Battle] The battle.
  def self.stand_alone(scene)
    forget
    MGQ_MpBattlesSync.finish
    MGQ_MpBattles.finish
    show_party(scene, $game_party.battle_members)
    log("fights on with the player's own party: #{members_text($game_party.battle_members)}")
  end

  # Ends a co-op battle: the player's own party again, the game's own settings back, and the live
  # battle over. Called once the battle's scene ended.
  def self.ended
    return unless active? || (MGQ_MpBattlesSync.role && MGQ_MpBattlesSync.coop?) || MGQ_MpBattles.kind == :coop

    log("battle #{MGQ_MpBattlesSync.battle_id} is over (#{@result ? RESULTS.fetch(@result, @result.inspect) : 'no result'}), the player's own party is back")
    @result = nil
    forget
    MGQ_MpBattlesSync.finish if MGQ_MpBattlesSync.coop?
    MGQ_MpBattles.finish if MGQ_MpBattles.kind == :coop
  rescue => e
    @members = nil
    log("ending a co-op battle failed: #{e.class}: #{e.message}")
  end

  # Forgets the co-op party, its players and their characters, gives synced characters their own
  # stats back, and shows the player's own party on the map again. The game's Retry is gone too:
  # its snapshot of the battle's start holds synced stats, or on a guest an older battle's.
  #
  # The game draws the map's leader and followers from the battle members whenever it refreshes the
  # player, which during the battle were the co-op party's.
  def self.forget
    MGQ_MpCoopLevelSync.finish
    MGQ_MpGame.set(BattleManager, :retry_data, nil)
    log("dropped the game's Retry of the battle and forgot the co-op party")
    clear
    $game_player.refresh if $game_player
  end

  # Forgets a co-op battle a reset interrupted, and every invite, request and hold, without touching
  # any character, whose save the reset dropped.
  def self.drop
    held = [("the battle" if @members), ("the hold" if @hold), ("the request to the leader" if @asking),
            ("an invite" if @invite), ("a request to lead" if @request)].compact
    log("forgot #{held.join(', ')} after a reset") unless held.empty?
    @result = nil
    drop_hold
    clear
    @asking = nil
    @invite = nil
    @request = nil
    @frozen = nil
  end

  # Forgets the co-op party, its players and their characters.
  def self.clear
    @seen = nil
    @members = nil
    @players = nil
    @own_squad = nil
    @allies = {}
    @reordered = false
    @requester = nil
  end

  # Swaps one of the player's characters on the Frontline with one of theirs on the Backline, in
  # the battle and in the player's own party, as the game's shift change does.
  #
  # @param scene [Scene_Battle] The battle.
  # @param actor [Game_Actor] The character on the Frontline.
  # @param bench_index [Integer] The other character's row in the Backline's window.
  # @return [Boolean] Whether they swapped.
  def self.swap(scene, actor, bench_index)
    player = own_player
    return false unless player && @own_squad

    order = player.order
    front = player.front.to_i
    at = order.first(front).index { |place| @own_squad[place].equal?(actor) }
    to = front + bench_index
    unless at && bench_index >= 0 && bench_index < player.bench.to_i && order[to]
      log("swap of #{MGQ_MpBattlesSync.named(actor)} with Backline row #{bench_index} refused: #{at ? 'no such Backline row of the player' : "not one of the player's own Frontline"}")
      return false
    end

    party = $game_party.all_members
    first = party.index(@own_squad[order[at]])
    second = party.index(@own_squad[order[to]])
    $game_party.swap_order(first, second) if first && second
    log("swapped #{MGQ_MpBattlesSync.named(@own_squad[order[at]])} on the Frontline with #{MGQ_MpBattlesSync.named(@own_squad[order[to]])} of the Backline#{', the party order too' if first && second}")
    order[at], order[to] = order[to], order[at]
    @reordered = true
    form(scene, @players)
    true
  end

  # As host, takes the order of a guest's places, which their commands carry, before their commands.
  #
  # @param seat [Integer] The guest's world seat.
  # @param order [Array, nil] The places, the Frontline's first.
  def self.take_order(seat, order)
    player = Array(@players).find { |candidate| candidate.seat == seat }
    return unless player && order.is_a?(Array) && order != player.order

    player.order = valid_order(order, player.order.size)
    log("#{MGQ_MpBattlesSync.who(seat)} swapped: order #{order.inspect}#{" (broken, their characters' own order instead)" unless player.order == order}")
    @reordered = true
    form(SceneManager.scene, @players)
  rescue => e
    log("taking a new order failed: #{e.class}: #{e.message}")
  end

  # As host, tells the guests the party once a player swapped, before the turn's events or before
  # players choose again, so every game shows the same characters. Called once every guest's
  # commands came.
  def self.share_order
    post_party if active? && @reordered
  rescue => e
    log("telling the new order failed: #{e.class}: #{e.message}")
  end

  # As host, notes who stands at each place of the party as a command phase opens, which every
  # player chooses their commands against.
  def self.note_places
    @seen = active? ? @members.dup : nil
  end

  # As host, lists the players a command of whose was for one character of the party at a place
  # another player swapped since they saw it. A player sees only their own swaps while choosing,
  # so the command would reach the character swapped in, or another one the game picks instead.
  # Notes the places anew, which the players who choose again see.
  #
  # @return [Array<Integer>] Their world seats, the host's own and those who left included.
  def self.lost_targets
    return [] unless active? && @seen

    seats = []
    @members.each do |actor|
      seat = seat_of(actor)
      lost = Array(actor.actions).find { |action| lost_target?(action, seat) }
      next unless lost

      index = lost.target_index
      log("#{MGQ_MpBattlesSync.named(actor)}'s command #{lost.item.name rescue '?'} was for place #{index}, #{MGQ_MpBattlesSync.named(@seen[index])}, whom #{MGQ_MpBattlesSync.named(@members[index])} replaced")
      seats << seat unless seats.include?(seat)
    end
    @seen = @members.dup
    seats
  rescue => e
    log("checking the targets failed: #{e.class}: #{e.message}")
    []
  end

  # Reports whether a command was for one character of the party that another player swapped out.
  #
  # @param action [Game_Action] The command.
  # @param seat [Integer] The world seat of the player who gave it.
  # @return [Boolean] Whether it was.
  def self.lost_target?(action, seat)
    item = action && action.item
    return false unless item.respond_to?(:for_friend?) && item.for_friend? && item.for_one? && !item.for_user?

    index = action.target_index
    seen = index.is_a?(Integer) && index >= 0 ? @seen[index] : nil
    !seen.nil? && !seen.equal?(@members[index]) && seat_of(seen) != seat
  end

  # Tells whose a character of the party is.
  #
  # @param actor [Game_Actor] The character.
  # @return [Integer] Its owner's world seat.
  def self.seat_of(actor)
    own?(actor) ? MGQ_MpOverworldSync::Me.seat : actor.mp_seat
  end

  # As host, makes the other players' characters whose commands lost their target new actions,
  # which those still in the battle fill once they chose again, takes those of the players who left
  # away, and shows the guests the party a swap changed.
  #
  # @param seats [Array<Integer>] The world seats of the players whose commands lost their target.
  def self.choose_again(seats)
    if active?
      @members.each do |actor|
        next if own?(actor) || !seats.include?(actor.mp_seat)

        if MGQ_MpBattlesSync.guests_in.include?(actor.mp_seat)
          actor.make_actions
          log("#{MGQ_MpBattlesSync.named(actor)} gets new actions, which its owner fills choosing again")
        else
          actor.clear_actions
          log("#{MGQ_MpBattlesSync.named(actor)} does nothing this turn: its owner left the battle")
        end
      end
    end
    share_order
  rescue => e
    log("giving the computer's commands failed: #{e.class}: #{e.message}")
  end

  # As host, sends the guests the party, between two of the host's sends.
  def self.post_party
    MGQ_MpBattlesSync::Recorder.flush if MGQ_MpBattlesSync::Recorder.active?
    line = MGQ_MpBattlesSync::Wire.line([@players.map(&:to_a)])
    MGQ_MpBattlesSync::Channel.post("coop_party", line)
    log("sent the guests the party (#{line.size} bytes)")
    @reordered = false
  end

  # Reports whether a character of the party is the player's own, whom only they may swap.
  #
  # @param actor [Game_Actor, nil] The character.
  # @return [Boolean] Whether it is.
  def self.own?(actor)
    !actor.nil? && !actor.is_a?(Game_MpActor)
  end

  # As host, takes away the actions of the characters of a guest who left, so they do nothing more
  # before the next command phase takes them out of the party.
  #
  # @param seat [Integer] The guest's world seat.
  def self.idle(seat)
    stopped = Array(@members).select { |actor| !own?(actor) && actor.mp_seat == seat }
    stopped.each(&:clear_actions)
    log("#{MGQ_MpBattlesSync.who(seat)} left: stopped their characters #{stopped.map { |actor| MGQ_MpBattlesSync.named(actor) }.join(', ')}")
  rescue => e
    log("stopping a guest's characters failed: #{e.class}: #{e.message}")
  end

  # Reports whether the host waits for a character's commands from its owner, still in the battle,
  # in which case the computer chooses none for it.
  #
  # @param ally [Game_MpAlly] The character.
  # @return [Boolean] Whether it does.
  def self.awaits_commands?(ally)
    MGQ_MpBattlesSync.coop? && MGQ_MpBattlesSync.host? && MGQ_MpBattlesSync.guests_in.include?(ally.mp_seat)
  end

  # Names the player's side of the co-op party the way the game names a party, after the player's
  # own first character, since the party's first character may be another player's.
  #
  # @return [String] The name.
  def self.party_name
    own = Array(@members).select { |actor| own?(actor) }
    own = Array(@own_squad).first(1) if own.empty?
    return "" if own.empty?

    own.size == 1 ? own[0].name : format(Vocab::PartyName, own[0].name)
  end

  # Reports whether a swap would leave the party with nobody standing, as the game forbids.
  #
  # @param actor [Game_Actor, nil] The character on the Frontline.
  # @param bench [Game_Actor, nil] The character on the Backline.
  # @return [Boolean] Whether it would.
  def self.swap_kills_all?(actor, bench)
    return false unless actor && bench
    return false if @members.reject(&:all_dead?).size != 1

    kills = !actor.all_dead? && bench.all_dead?
    log("swap of #{MGQ_MpBattlesSync.named(actor)} with #{MGQ_MpBattlesSync.named(bench)} refused: it would leave nobody standing") if kills
    kills
  end

  # Installs the hooks on methods the game's plugins may define anew. Called once the first scene starts.
  def self.install
    return if @installed

    @installed = true
    install_party
    install_targets
    install_shift_change
    install_counts
    install_end
  end

  # Ends a co-op battle once the battle's scene ended.
  def self.install_end
    MGQ_MpHooks.after(Scene_Battle, :terminate, "battles_coop") { MGQ_MpBattlesCoop.ended }
  rescue => e
    log("battle end hook FAILED: #{e.class}: #{e.message}")
  end

  # Aims the skills and items that reach the Backline too at the co-op party and the player's own
  # Backline, where the game takes the player's whole party, without the other players' characters.
  def self.install_targets
    return unless Game_Party.method_defined?(:item_target_members)

    MGQ_MpHooks.around(Game_Party, :item_target_members, "battles_coop") do |party, args, original|
      item = args[0]
      bench = MGQ_MpBattlesCoop.active? && item.respond_to?(:include_bench?) && item.include_bench?
      MGQ_MpBattlesCoop.note_bench(item) if bench
      bench ? party.battle_members + party.bench_members : original.call
    end
  rescue => e
    log("target hook FAILED: #{e.class}: #{e.message}")
  end

  # Logs once a battle that a skill or item reaching the Backline aims at the co-op party and the
  # player's own Backline.
  #
  # @param item [RPG::UsableItem] The skill or item.
  def self.note_bench(item)
    log_once([:bench, MGQ_MpBattlesSync.battle_id, item.class.name, item.id], "aimed #{item.id} #{item.name} at the co-op party and the player's own Backline")
  rescue
  end

  # Notes the result the game ends a co-op battle with and logs the Library counts it leaves to the
  # other players' games. Called as BattleManager.battle_end starts.
  #
  # @param result [Integer] The game's result: 0 won, 1 escaped, 2 lost.
  def self.note_end(result)
    @result = result
    others = Array(@members).reject { |actor| own?(actor) }
    log("battle #{MGQ_MpBattlesSync.battle_id} ends #{RESULTS.fetch(result, result.inspect)}; the Library counts only the player's own " \
        "#{Array(@members).size - others.size} characters, not #{others.empty? ? 'others' : others.map { |actor| MGQ_MpBattlesSync.named(actor) }.join(', ')}")
  rescue
  end

  # Logs a Library count left to the other players' games, see install_counts.
  #
  # @param what [String] The count, such as "defeat".
  # @param battlers [Array<Game_Battler, nil>] Who took part.
  def self.note_uncounted(what, *battlers)
    log("left the #{what} count of #{battlers.map { |battler| battler ? "#{battler.name}" : 'nobody' }.join(' and ')} to its owner's Library")
  rescue
  end

  # Keeps the other players' characters out of the Library all saves share, which counts each
  # character's battles, defeats and steals by its id: those belong to their owners' games.
  def self.install_counts
    if BattleManager.respond_to?(:battle_end)
      MGQ_MpHooks.around(BattleManager.singleton_class, :battle_end, "battles_coop") do |_manager, args, original|
        next original.call unless MGQ_MpBattlesCoop.active?

        MGQ_MpBattlesCoop.note_end(args[0])
        MGQ_MpBattlesCoop.own_only { original.call }
      end
    end
    if Scene_Battle.method_defined?(:count_up_defeat)
      MGQ_MpHooks.around(Scene_Battle, :count_up_defeat, "battles_coop") do |_scene, args, original|
        next original.call if MGQ_MpBattlesCoop.counted?(args[0], args[1])

        MGQ_MpBattlesCoop.note_uncounted("defeat", args[0], args[1])
        MGQ_MpBattlesCoop.uncounted { original.call }
      end
    end
    [:item_effect_steal, :item_effect_force_steal].select { |name| Game_Enemy.method_defined?(name) }.each do |name|
      MGQ_MpHooks.around(Game_Enemy, name, "battles_coop") do |enemy, args, original|
        next original.call if MGQ_MpBattlesCoop.counted?(args[0])

        MGQ_MpBattlesCoop.note_uncounted("steal", args[0], enemy)
        MGQ_MpBattlesCoop.uncounted { original.call }
      end
    end
    return unless defined?(Game_Library) && Game_Library.method_defined?(:count_up_actor_data)

    MGQ_MpHooks.around(Game_Library, :count_up_actor_data, "battles_coop") do |_library, _args, original|
      original.call unless MGQ_MpBattlesCoop.uncounted?
    end
  rescue => e
    log("count hooks FAILED: #{e.class}: #{e.message}")
  end

  # Puts the co-op party in the place of the player's in battle.
  def self.install_party
    Game_Party.class_eval do
      alias_method :mgq_mp_battles_coop_battle_members, :battle_members

      # Lists the battle members: the co-op party while a co-op battle runs.
      #
      # @return [Array<Game_Actor>] The members.
      def battle_members
        MGQ_MpBattlesCoop.active? ? MGQ_MpBattlesCoop.members : mgq_mp_battles_coop_battle_members
      end

      alias_method :mgq_mp_battles_coop_bench_members, :bench_members

      # Lists the Backline: the player's own share of it while a co-op battle runs.
      #
      # @return [Array<Game_Actor>] The members.
      def bench_members
        MGQ_MpBattlesCoop.active? ? MGQ_MpBattlesCoop.own_bench : mgq_mp_battles_coop_bench_members
      end

      alias_method :mgq_mp_battles_coop_name, :name

      # Names the party, as the battle says it runs away or was defeated: the player's own side
      # while a co-op battle runs.
      #
      # @return [String] The name.
      def name
        MGQ_MpBattlesCoop.active? ? MGQ_MpBattlesCoop.party_name : mgq_mp_battles_coop_name
      end
    end
  rescue => e
    log("party hook FAILED: #{e.class}: #{e.message}")
  end

  # Lets the battle's shift change swap only the player's own characters, within their squad.
  def self.install_shift_change
    Window_BattleStatus.class_eval do
      alias_method :mgq_mp_battles_coop_current_item_enabled?, :current_item_enabled?

      # Reports whether the character pointed at may be picked: in a co-op battle's shift change,
      # only the player's own.
      #
      # @return [Boolean] Whether it may.
      def current_item_enabled?
        return mgq_mp_battles_coop_current_item_enabled? unless MGQ_MpBattlesCoop.active? && BattleManager.shift_change?

        actor = $game_party.battle_members[index]
        MGQ_MpBattlesCoop.own?(actor) && !(BattleManager.bind? && actor.luca?)
      end
    end

    Scene_Battle.class_eval do
      alias_method :mgq_mp_battles_coop_no_change_all_dead_on_bench?, :no_change_all_dead_on_bench?

      # Reports whether the swap picked would leave nobody standing, with the co-op party's places.
      #
      # @return [Boolean] Whether it would.
      def no_change_all_dead_on_bench?
        return mgq_mp_battles_coop_no_change_all_dead_on_bench? unless MGQ_MpBattlesCoop.active?

        MGQ_MpBattlesCoop.swap_kills_all?($game_party.battle_members[@status_window.index], $game_party.bench_members[@bench_window.index])
      end

      alias_method :mgq_mp_battles_coop_bench_member_ok, :bench_member_ok

      # Swaps the characters picked, in a co-op battle within the player's own squad.
      def bench_member_ok
        return mgq_mp_battles_coop_bench_member_ok unless MGQ_MpBattlesCoop.active?

        MGQ_MpBattlesCoop.swap(self, $game_party.battle_members[@status_window.index], @bench_window.index)
        refresh_status
        bench_member_cancel
      end
    end
  rescue => e
    log("shift change hooks FAILED: #{e.class}: #{e.message}")
  end
end

# What a co-op battle does differently in a live battle: every game's party is the host's, the
# party gathers before the start and re-forms when a player leaves or swaps, and a guest whose
# host got away fights on alone.
module MGQ_MpBattlesCoop::Mode
  extend MGQ_MpBattles::Mode

  # (see MGQ_MpBattles::Mode#same_side?)
  def self.same_side?
    true
  end

  # (see MGQ_MpBattles::Mode#same_side_as_host?)
  def self.same_side_as_host?(_seat)
    true
  end

  # (see MGQ_MpBattles::Mode#player_seats)
  def self.player_seats
    MGQ_MpBattlesCoop.player_seats
  end

  # (see MGQ_MpBattles::Mode#before_start)
  def self.before_start(scene)
    MGQ_MpBattlesCoop.await_leader(scene)
  end

  # (see MGQ_MpBattles::Mode#host_start)
  def self.host_start(scene)
    gathered = MGQ_MpBattlesCoop.gather(scene)
    return gathered if gathered.is_a?(Symbol)

    # Nobody joined: the battle is the host's own.
    MGQ_MpBattlesSync.host? ? nil : :own
  end

  # (see MGQ_MpBattles::Mode#guest_start)
  def self.guest_start(scene)
    MGQ_MpBattlesCoop.join(scene)
  end

  # (see MGQ_MpBattles::Mode#settle)
  def self.settle(scene)
    MGQ_MpBattlesCoop.settle(scene)
    MGQ_MpBattlesCoop.note_places
  end

  # (see MGQ_MpBattles::Mode#own_order)
  def self.own_order
    MGQ_MpBattlesCoop.own_order
  end

  # (see MGQ_MpBattles::Mode#take_order)
  def self.take_order(seat, order)
    MGQ_MpBattlesCoop.take_order(seat, order)
  end

  # (see MGQ_MpBattles::Mode#share_order)
  def self.share_order
    MGQ_MpBattlesCoop.share_order
  end

  # (see MGQ_MpBattles::Mode#lost_targets)
  def self.lost_targets
    MGQ_MpBattlesCoop.lost_targets
  end

  # (see MGQ_MpBattles::Mode#choose_again)
  def self.choose_again(seats)
    MGQ_MpBattlesCoop.choose_again(seats)
  end

  # (see MGQ_MpBattles::Mode#stream_kinds)
  def self.stream_kinds
    ["coop_party"]
  end

  # (see MGQ_MpBattles::Mode#take)
  def self.take(_kind, scene, body)
    MGQ_MpBattlesCoop.reform(scene, body)
  end

  # (see MGQ_MpBattles::Mode#take_over)
  def self.take_over(scene)
    MGQ_MpBattlesCoop.take_over(scene)
    true
  end

  # (see MGQ_MpBattles::Mode#left)
  def self.left(seat)
    MGQ_MpBattlesCoop.idle(seat)
  end
end

# Another player's character in a co-op battle's party. Its owner commands it from their own game;
# while the owner is in a co-op battle it does nothing without their commands, and once they left
# it does nothing more. In a team duel the computer plays it when no command came.
class Game_MpAlly < Game_MpActor
  # Rebuilds another player's character.
  #
  # @param member [MGQ_MpActors::Builds::Member] The character's build.
  # @param player [String] Who the character belongs to.
  # @param seat [Integer] The owner's world seat.
  # @param place [Integer] The character's place among its owner's characters.
  def initialize(member, player, seat, place)
    super(member, player)
    self.mp_seat = seat
    self.mp_place = place
  end

  # Tells whether this game's player commands the character: only in a team duel, once its owner
  # left and this player took it over.
  #
  # @return [Boolean] Whether they do.
  def inputable?
    defined?(MGQ_MpBattlesTeam) && MGQ_MpBattlesTeam.commands?(self) ? super : false
  end

  # Makes the turn's actions, which the owner's commands fill; without an owner to wait for, with
  # the game's own auto-battle.
  def make_actions
    super
    return if @actions.empty? || inputable? || MGQ_MpBattlesCoop.awaits_commands?(self)

    make_auto_battle_actions
    MGQ_MpBattlesCoop.log_once([:auto, MGQ_MpBattlesSync.battle_id, mp_seat, mp_place], "the computer plays #{id} #{name} this battle, no owner's commands to wait for")
  end

  # Starts a turn, with the hit count the game resets only for the characters of its own party.
  def on_turn_start
    super
    @turn_hit_damage_count = 0
  end
end

# What this script takes part in of the party's messages, through coop.rbx.

begin
  MGQ_MpCoop.route("coop") { |peer, message| MGQ_MpBattlesCoop.take(peer, message) }
  MGQ_MpBattles.mode(:coop, MGQ_MpBattlesCoop::Mode)
rescue => e
  MGQ_MpBattlesCoop.log("co-op FAILED: #{e.class}: #{e.message}")
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # Installs the hooks on methods the game's plugins may define anew, as the game starts running.
  MGQ_MpHooks.before(SceneManager.singleton_class, :run, "battles_coop") { MGQ_MpBattlesCoop.install }

  # After the map's update, joins a co-op battle the player was invited to.
  MGQ_MpHooks.after(Scene_Map, :update_scene, "battles_coop") { MGQ_MpBattlesCoop.on_map unless scene_changing? }
rescue => e
  MGQ_MpBattlesCoop.log("hooks FAILED: #{e.class}: #{e.message}")
end

begin
  # Before the title screen starts, a battle and an encounter a reset interrupted are forgotten, so
  # neither reaches the save loaded next.
  MGQ_MpHooks.before(Scene_Title, :start, "battles_coop") { MGQ_MpBattlesCoop.drop }

  # The player stands still and opens no menu while their encounter waits for the party, or a
  # party member's encounter on their map waits for them.
  MGQ_MpHooks.hold_player("battles_coop") { MGQ_MpBattlesCoop.holding? || MGQ_MpBattlesCoop.frozen? }
rescue => e
  MGQ_MpBattlesCoop.log("title hook FAILED: #{e.class}: #{e.message}")
end

# Game hooks of this script alone, through core_hooks.rbx.

begin
  # After a battle is set up, it becomes a co-op battle where the party can join.
  MGQ_MpHooks.after(BattleManager.singleton_class, :setup, "battles_coop") do |troop_id, can_escape = true, can_lose = false|
    MGQ_MpBattlesCoop.offer(troop_id, can_escape, can_lose)
  end
rescue => e
  MGQ_MpBattlesCoop.log("battle setup hook FAILED: #{e.class}: #{e.message}")
end

begin
  # A random encounter when its steps ran out, held while party members on the map are busy (see
  # MGQ_MpBattlesCoop.hold).
  MGQ_MpHooks.around(Game_Player, :encounter, "battles_coop") { |_player, _args, original| MGQ_MpBattlesCoop.encounter { original.call } }
rescue => e
  MGQ_MpBattlesCoop.log("encounter hook FAILED: #{e.class}: #{e.message}")
end
