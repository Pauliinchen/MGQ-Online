#----------------------------------------------------------------
#  battles_coop.rbx
#
#  Changelog:
#      Paulinchen  2026-10-13: Brought a Raid World player's squad by the world's squad rules
#      Paulinchen  2026-10-12: Joined the battle of the story whose call is about to bring the player over
#                            - Took a joining player's party_member_max only as a number
#                            - Picked a defeat scene of the troop for a guest who takes the battle over
#                            - Read a player another game sent only with fields of the right kind
#                            - Dropped an enemy of the host's troop whose id, place or mark is no number
#                            - Kept every enemy of the host's troop at its place
#      Paulinchen  2026-10-11: Left the party members who said no to starting a battle out of its invites
#                            - Took the party members' offers and answers about a battle outside the party
#                            - Stretched the steps to the next random encounter by half once another player stands near
#                            - Invited only the players near to a Raid World's battle
#                            - Opened the player's command phase while only their Backline may swap in
#                            - Named the battle invite or lead request waiting for the player to be free
#                            - Drew each character's name in the battle's status window in its player's color
#                            - Told the player in the battle's chat log of the players who joined
#                            - Showed the notice of a member's battle as long as the player stands still for it
#                            - Told a player who joins a running battle how long the wait may last
#                            - Left a status name the mod cannot draw to the game
#                            - Wrote the late join's seconds as the waiting box does
#                            - Logged a telling of who joined that fails on its own
#      Paulinchen  2026-10-10: Stretched the steps to the next random encounter in a Raid World per player on the map
#                            - Stretched the steps to a party's next random encounter in a Classic world per member on the map
#                            - Invited the players who watch the story told on the map to a boss battle in a Raid World
#                            - Named the raid boss's pools in the invite to a battle that fights them
#                            - Invited nobody to a raid boss battle whose pools are all empty
#                            - Fought the raid boss's pools in the battle the player yields or follows to
#                            - Gave a troop taken from the host the boss's raised max HP at once
#                            - Gave the player their own enemy rates and stats back as the battle ends
#                            - Fought a requester's own encounter with its own enemy rates when the running battle's host left
#                            - Started a side battle against a raid boss as the player's own
#                            - Invited not even the host of a waiting invite to a raid boss battle whose pools are all empty
#                            - Kept a rival's invite that came twice
#                            - Told the raid pool as a guest takes a battle over
#                            - Told whether the player is in a battle also under the Library or Config
#                            - Told whether another player fights a battle also while they are away
#      Paulinchen  2026-10-09: Told the guests the troop as host whenever it changed
#                            - Fought a battle joined in a Raid World with its host's enemy rates
#                            - Ended a co-op battle only once its scene ended
#                            - Noted whether the battle the player yields to in a Raid World is a boss battle
#                            - Ignored the invite of a running battle's host the player asks to take their own encounter in
#                            - Passed a request to join a battle by choice and its refusal to battles_coop_join.rbx
#                            - Ignored the late invite of a battle the player stopped waiting to join by choice
#                            - Invited the players in a Raid World whose game window is in the background
#                            - Laid the host's fallen enemies down only once the troop a guest takes was lettered
#      Paulinchen  2026-10-08: Brought each player's first three characters to a co-op battle in a Raid World
#                            - Brought only the squad to a team duel in a Raid World
#                            - Invited the nearest free players on the map to a battle in a Raid World
#                            - Let the player who starts a battle in a Raid World host it
#                            - Settled who hosts two battles in a Raid World that started at the same moment
#                            - Held only the players invited in a Raid World instead of the whole party
#                            - Turned down one of two invites waiting in a Raid World
#                            - Invited the host of an invite waiting as the player's own battle began
#                            - Told the others in a Raid World while the player trades or is about to teleport
#                            - Let a random encounter in a Raid World join a battle running on the map
#      Paulinchen  2026-10-07: Registered the battle setup and encounter hooks through core_hooks.rbx
#                            - Named players and characters through battles_sync.rbx and overworld_sync.rbx
#                            - Logged the co-op messages, invites, requests, roster and the battle's result
#                            - Stopped a guest's characters at once when the guest leaves
#                            - Let the host's computer choose nothing for a guest's characters while it waits for their commands
#                            - Named the party after the player's own characters while a co-op battle runs
#      Paulinchen  2026-10-06: Forgot the co-op battle, its invites and its requests on a reset
#                            - Rebuilt another player's fallen character fallen
#                            - Ended a guest's battle that the host's party left out or never came for
#                            - Aimed the skills that reach the Backline at the co-op party and the player's own Backline
#                            - Kept the other players' characters out of the Library's counts
#                            - Dropped the game's Retry of a co-op battle
#                            - Started the battle of a guest that takes over before the host's party came
#                            - Set the counters of a guest that takes over later
#                            - Brought no share of the Backline to a team duel
#                            - Turned down at once the invites and requests to lead the player cannot take
#                            - Compared a rebuilt character of a team duel without the PvP balance
#      Paulinchen  2026-10-04: Sent the players back to choose whose target another player swapped out
#                            - Synced the characters above the battle's level
#                            - Logged where a guest's rebuilt character differs
#                            - Held every party member on the map while a member's encounter waits
#                            - Asked coop_gather.rbx whether the leader's story is about to bring the player over
#                            - Renamed from mp_battles_coop.rbx
#      Paulinchen  2026-10-03: Registered the co-op battle's Mode
#                            - Read and wrote the game's private fields through MGQ_MpGame
#                            - Kept the battle's players as Player records
#                            - Held the player through MGQ_MpHooks.hold_player
#                            - Called the scripts that load before this one without asking whether they loaded
#                            - Sent messages, showed notices and read the world through MGQ_MpOverworldSync
#                            - Logged through MGQ_MpLog
#                            - Started the battle and each turn for the other players' characters
#                            - Showed the player's own leader and followers on the map again after a co-op battle
#                            - Let the party's leader host a battle a member started
#                            - Turned down an invite during the player's own battle or older than three seconds
#                            - Held a random encounter up to three seconds for busy party members on the map
#      Paulinchen  2026-10-02: Started a co-op battle when a player who joined it left the world before the roster
#                            - Followed the map and installed the late hooks through core_hooks.rbx
#                            - Turned an invite down through MGQ_MpBattlesSync.tell
#                            - Took the seat, place and Luka from Game_MpActor
#                            - Turned a co-op battle down while the leader's story scene is about to bring the player over
#      Paulinchen  2026-10-01: Listed the battle's players
#                            - Rebuilt the host's enemies on a guest whose troop differs
#                            - Brought each player's squad, a share of the Frontline and of the Backline
#                            - Let each player swap their own Backline in
#                            - Found the leader of any party among the battle's players
#                            - Let a player of a team duel command the characters of a player who left their side
#      Paulinchen  2026-09-30: Sent and took the party's messages through coop.rbx
#                            - Registered with overworld_sync.rbx for its messages
#                            - Moved into Patch/Multiplayer/Scripts
#                            - Renamed from mp_coop.rb, with the module MGQ_MpBattlesCoop
#                            - Let a player who got away leave the battle
#                            - Showed the co-op party in the game's window per character too
#                            - Invited party members whose window is in the background
#                            - Logged why nobody was invited
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
# In a Raid World a battle takes the free players on the map, party or not: the party members
# first, then those nearest the party's leader, up to RAID_PLAYERS (see raid_candidates). The
# player who starts it hosts it; of a random encounter and another player's battle started at the
# same moment, an event's battle or else the player who entered the map first hosts, and the other
# joins as a guest with the players who joined them (see rival? and follows?). Every player's
# squad follows the world's squad rules, their first character always on the Frontline however
# many play, and no level sync runs. A random encounter on a map where a battle already runs joins that
# battle instead (see battles_coop_hotjoin.rbx), and a player near a running battle may join it by
# choice (see battles_coop_join.rbx).
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpBattlesCoop
  # Frames the host waits for the invited members to join, six seconds.
  JOIN_FRAMES = 360

  # Frames the host of a battle in a Raid World waits for the invited players to join, ten seconds.
  RAID_JOIN_FRAMES = 600

  # Frames a guest waits for the host's party beyond the host's wait for the players to join.
  ROSTER_MARGIN_FRAMES = 240

  # Frames a guest waits for the host's party, ten seconds: longer than the host waits for the
  # players to join after it sent the invite.
  ROSTER_FRAMES = JOIN_FRAMES + ROSTER_MARGIN_FRAMES

  # Players of a battle in a Raid World at most, the host included: as many as the Frontline has
  # places, each player's first character on it.
  RAID_PLAYERS = 4

  # What another player in a Raid World does, by their state's scene, while they may be invited:
  # walking the map, or on it with their window in the background, which keeps running.
  RAID_FREE_SCENES = %w(map away)

  # What another player in a Raid World does, by their state's scene, while they fight a battle:
  # the battle, or a screen its party command called with their window in the background.
  RAID_BATTLE_SCENES = %w(battle away)

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

  # How long the notice of the member's battle shows: as long as the player stands still.
  FREEZE_FRAMES = FREEZE_SECONDS * MGQ_MpUi::FRAMES_PER_SECOND

  # What starts the waiting box's names line of a player who joins a running battle at its next
  # turn, which names no player: how long the wait may last.
  UP_TO_PREFIX = "Up to "

  # The share either way by which the steps to a party's next random encounter vary around the
  # stretched draw, so the players' steps never fall into step.
  ENCOUNTER_MARGIN = 0.25

  # How much longer the steps to the next random encounter are while another player who would
  # fight it stands near (see encounter_players): their encounters bring the player into battles
  # too, but each player still meets enemies of their own.
  ENCOUNTER_STRETCH = 1.5

  # Tiles within which another player on the map counts as near: they stretch the player's steps
  # to the next random encounter, and a Raid World's battle invites them.
  NEARBY_TILES = 20

  # What another player does, by their state's scene, while they may be invited: walking the map,
  # reading an event's messages, such as the leader's story, or on the map with their window in the
  # background, which keeps running.
  FREE_SCENES = %w(map event away)

  # Players the characters a player sends are counted for: two, the fewest who share a battle,
  # whose squads are the largest, so a party that loses a player can bring more.
  FEWEST_PLAYERS = 2

  # Characters a player's builds hold at most, the game's largest party.
  MOST_CHARACTERS = 14

  # The variables of the enemies' strength the game reads as their parameters are asked: the rates
  # of their HP, attack, defense, agility, instant death resistance and MP, which the difficulty, a
  # fight's own values or the Labyrinth of Chaos's level set. The rates of experience, job
  # experience and gold (46, 49, 47) stay each player's own rewards.
  RATE_VARIABLES = [41, 42, 43, 44, 45, 48]

  # The fields of an enemy the host names, see troop_entries, as a log of one of the wrong kind
  # names them.
  ENEMY_FIELDS = [:id, :x, :y, :mark]

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
    # Reads a player from the fields a message carries, dropping a field of the wrong kind.
    #
    # Another game sends the fields, so any of them may be a list, a text or true.
    #
    # @param fields [Array, Player] The fields in the order of the attributes, or a player already read.
    # @return [Player, nil] The player, nil when its seat is no number.
    def self.read(fields)
      return fields if fields.is_a?(self)

      seat, name, builds, vitals, max, order, front, bench = Array(fields).first(members.size)
      return MGQ_MpBattlesCoop.dropped(:seat, seat) unless seat.is_a?(Integer)

      vitals = MGQ_MpBattlesCoop.dropped(:vitals, vitals) || [] unless vitals.is_a?(Array)
      new(seat, name.to_s, builds.to_s, vitals, count(:max, max), places(order), count(:front, front), count(:bench, bench))
    end

    # Reads a list of players, leaving out those that do not read.
    #
    # @param list [Array, nil] The players or their fields.
    # @return [Array<Player>] The players.
    def self.read_all(list)
      Array(list).map { |fields| read(fields) }.compact
    end

    # Checks a count among a player's fields.
    #
    # @param field [Symbol] The field's name.
    # @param value [Object] Its value.
    # @return [Integer, nil] The count, nil when there was none or it is no number of 0 or more.
    def self.count(field, value)
      value.nil? || (value.is_a?(Integer) && value >= 0) ? value : MGQ_MpBattlesCoop.dropped(field, value)
    end

    # Checks the order of a player's places among their fields.
    #
    # @param order [Object] The order.
    # @return [Array<Integer>, nil] The order, nil when there was none or it holds anything but
    #   numbers of 0 or more.
    def self.places(order)
      return order if order.nil? || (order.is_a?(Array) && order.all? { |place| place.is_a?(Integer) && place >= 0 })

      MGQ_MpBattlesCoop.dropped(:order, order)
    end

    # Lists the player's places on the battle's Frontline and on its Backline.
    #
    # @return [Array<Array<Integer>>] The Frontline's places and the Backline's.
    def lines
      places = Array(order)
      [places.first(front.to_i), places[front.to_i, bench.to_i] || []]
    end
  end

  # The co-op party, nil outside a co-op battle.
  @members = nil

  # The battle's players, as form took them.
  @players = nil

  # The other players' rebuilt characters by their owner's seat and place.
  @allies = {}

  # The player's own enemy rates while the battle fights with the host's, nil otherwise.
  @kept_rates = nil

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

  # Sends a co-op message to some players of the map through the map's gate, since in a Raid World
  # a battle's players need not share a party.
  #
  # @param seats [Array<Integer>] The players' seats.
  # @param kind [String] What it is.
  # @param fields [Hash] Its other fields.
  def self.tell_map(seats, kind, fields)
    seats.each do |seat|
      sent = MGQ_MpCoop.tell_map(seat, "coop", kind, fields)
      log("sent #{kind} through the map's gate to #{MGQ_MpBattlesSync.who(seat)}: #{fields_text(fields)}#{' (not sent)' unless sent}")
    end
  end

  # Reports whether a Raid World is open, whose battles take the players on the map.
  #
  # @return [Boolean] Whether one is.
  def self.raid?
    MGQ_MpCoop::Scope.raid?
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
  # leader plays on the map, else invites the party members on the map who are playing on it. In a
  # Raid World the player hosts it and invites the players on the map, see raid_candidates, unless
  # it is a random encounter that joins a battle running on the map (MGQ_MpBattlesHotjoin.ask) or a
  # side battle against a raid boss, which starts as the player's own (see side_battle?). Called
  # after BattleManager.setup.
  #
  # @param troop_id [Integer] The troop.
  # @param can_escape [Boolean] Whether the party may escape.
  # @param can_lose [Boolean] Whether losing goes on without a game over.
  # @param encounter [Boolean] Whether the battle is a random encounter, see rival?.
  def self.offer(troop_id, can_escape, can_lose, encounter = @encountering)
    thaw("the player's own battle begins")
    @rival = nil
    return if @joining
    return unless host_possible?(troop_id)
    return hold(troop_id, can_escape, can_lose) if @encountering && !busy_members.empty?

    @random_encounter = encounter ? true : false
    @requester, battle_id = @leading
    if raid?
      return if encounter && @invite.nil? && MGQ_MpBattlesHotjoin.ask(troop_id, can_escape, can_lose)

      if side_battle?(troop_id)
        log("fights the side battle against troop #{troop_id} as the player's own, inviting nobody: others may join it by choice")
      else
        log("hosts the battle against troop #{troop_id}: the player started it in a Raid World")
        host(troop_id, can_escape, can_lose)
      end
      MGQ_MpBattlesHotjoin.fight_alone unless MGQ_MpBattlesSync.role
      return answer_waiting_invite
    end

    leader = MGQ_MpCoop::Party.leader
    return ask_leader(leader, troop_id, can_escape, can_lose) if @requester.nil? && candidates.include?(leader)

    log("hosts the battle against troop #{troop_id}: #{host_reason(leader)}")
    host(troop_id, can_escape, can_lose, battle_id)
  rescue => e
    log("could not offer a co-op battle: #{e.class}: #{e.message}")
  end

  # Hosts a co-op battle, inviting the party members on the map who are playing on it, and the
  # member who asked the player to lead it; in a Raid World the players raid_candidates finds and the
  # host of a waiting invite (see with_waiting_host), or nobody when a rival's invite waits, which
  # the battle then yields to (see rival?). A Raid World's invite says whether the battle is a random
  # encounter, which may yield. A raid boss battle whose pools are all empty already invites nobody,
  # since it is won at once.
  #
  # @param troop_id [Integer] The troop.
  # @param can_escape [Boolean] Whether the party may escape.
  # @param can_lose [Boolean] Whether losing goes on without a game over.
  # @param battle_id [String, nil] The battle's id the member who asked chose, nil for a new one.
  def self.host(troop_id, can_escape, can_lose, battle_id = nil)
    return log("invites nobody to the battle against troop #{troop_id}: the raid boss's pools are all empty, so it is won at once") if raid? && pools_won?(troop_id)

    seats = invitees(troop_id).map(&:seat)
    seats |= [@requester] if @requester
    seats = with_waiting_host(seats) if raid?
    return log("nobody to invite on map #{$game_map.map_id}: #{nobody_text}") if seats.empty? && !waiting_rival?

    battle_id ||= new_battle_id
    MGQ_MpBattlesSync.join_world(:host, battle_id, seats, raid? ? "the players" : "the party")
    MGQ_MpBattlesSync.battle_started
    MGQ_MpBattles.begin(:coop)
    freeze_party(seats)
    fields = { "bid" => battle_id, "troop" => troop_id, "escape" => can_escape ? 1 : 0, "lose" => can_lose ? 1 : 0,
               "seats" => seats.join(","), "map" => $game_map.map_id }
    if raid?
      fields["enc"] = @random_encounter ? 1 : 0
      fields["boss"] = 1 if MGQ_MpRaidBosses.battle?(troop_id)
      fields["rates"] = rates_text
      fields.update(MGQ_MpRaidPool.invite_fields(troop_id)) if defined?(MGQ_MpRaidPool)
    end
    raid? ? tell_map(seats, "invite", fields) : tell(-1, "invite", fields)
    log("invited #{seats.size} #{raid? ? 'player' : 'member'}(s) to battle #{battle_id} against troop #{troop_id} on map #{$game_map.map_id}: #{seats.map { |seat| MGQ_MpBattlesSync.who(seat) }.join(', ')}")
  rescue => e
    log("could not host a co-op battle: #{e.class}: #{e.message}")
  end

  # Lists the players a battle the player hosts invites: raid_candidates in a Raid World, those
  # watching the story told on the map too for a boss battle, else candidates. A raid boss battle
  # whose pools are all empty already invites nobody, since it is won at once.
  #
  # @param troop_id [Integer, nil] The battle's troop.
  # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The players.
  def self.invitees(troop_id = nil)
    return candidates unless raid?
    return [] if troop_id && pools_won?(troop_id)

    raid_candidates(troop_id && MGQ_MpRaidBosses.battle?(troop_id))
  end

  # Reports whether a battle just set up fights a raid boss's pools that are all empty already,
  # through battles_raid_pool.rbx.
  #
  # @param troop_id [Integer] The battle's troop.
  # @return [Boolean] Whether it does.
  def self.pools_won?(troop_id)
    defined?(MGQ_MpRaidPool) && MGQ_MpRaidPool.won_already?(troop_id) ? true : false
  end

  # Reports whether a battle just set up is a side battle against a raid boss (see
  # MGQ_MpRaidPool.start_side), which the player fights as their own: it invites and holds nobody,
  # and other players may join it by choice (see battles_coop_join.rbx).
  #
  # @param troop_id [Integer] The battle's troop.
  # @return [Boolean] Whether it is.
  def self.side_battle?(troop_id)
    return false unless defined?(MGQ_MpRaidPool)
    return MGQ_MpRaidPool.side_battle?(troop_id) ? true : false if MGQ_MpRaidPool.respond_to?(:side_battle?)

    MGQ_MpRaidPool.respond_to?(:kind_of) && MGQ_MpRaidPool.kind_of(troop_id) == :side
  end

  # Adds the host of an invite that waits for the player to the players a battle in a Raid World
  # invites, unless it is a rival's: that host's battle gathers too, so raid_candidates leaves them
  # out, yet their random encounter yields to the player's battle (see rival?) instead of both
  # fighting apart.
  #
  # @param seats [Array<Integer>] The seats the battle invites.
  # @return [Array<Integer>] The seats, the waiting invite's host first, at most RAID_PLAYERS - 1.
  def self.with_waiting_host(seats)
    invite = @invite
    return seats if invite.nil? || invite[:message]["hot"] == "1" || expired?(invite) || waiting_rival?

    ([invite[:peer].seat] | seats).first(RAID_PLAYERS - 1)
  end

  # Tells what the others do while a battle invites nobody, for Multiplayer InGame.log.
  #
  # @return [String] Each party member's map and scene, in a Raid World each player's on the map.
  def self.nobody_text
    others = raid? ? MGQ_MpCoop::Scope.peers_on($game_map.map_id) : MGQ_MpCoop::Party.members
    return raid? ? "no other player on the map" : "no other party member" if others.empty?

    others.map { |peer| "#{peer.state['name']} on map #{peer.state['map']} (#{peer.state['scene']}#{', busy' if peer.state['busy'] == '1'})" }.join(", ")
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
  # or anywhere in a Raid World, and no other multiplayer battle or Library replay running.
  #
  # @param troop_id [Integer, nil] The battle's troop, for Multiplayer InGame.log.
  # @return [Boolean] Whether it may.
  def self.host_possible?(troop_id = nil)
    return false unless MGQ_MpOverworldSync.in_world?

    reason = if !MGQ_MpCoop::Party.id && !raid? then "not in a party"
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

  # Lists the players a battle in a Raid World invites: of those on the player's map who are free
  # (see raid_free?) and near (see near?), and for a boss battle those reading the story the player
  # tells there wherever they stand (see watching?), the party members first, then the nearest to
  # the party's leader, or to the player outside a party, by their states; at most RAID_PLAYERS
  # with the player. Party members who said no to starting a battle with the player stay out (see
  # MGQ_MpBattlesHotjoin.stays_out?).
  #
  # @param boss [Boolean] Whether it is a boss battle.
  # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The players.
  def self.raid_candidates(boss = false)
    members = MGQ_MpCoop::Party.members
    x, y = raid_center
    viewers = boss ? MGQ_MpCoop::Scope.viewers : []
    free = MGQ_MpCoop::Scope.peers_on($game_map.map_id).select { |peer| (raid_free?(peer) && near?(peer)) || watching?(peer, viewers) }
    free.reject! { |peer| MGQ_MpBattlesHotjoin.stays_out?(peer.seat) }
    ranked = free.sort_by do |peer|
      [members.any? { |member| member.equal?(peer) } ? 0 : 1, distance(peer, x, y), peer.state["id"].to_s]
    end
    ranked.first(RAID_PLAYERS - 1)
  end

  # Reports whether another player in a Raid World may be invited: walking the map, or on it with
  # their window in the background, and neither fighting a battle (see fights?), trading nor about
  # to teleport, as their state says (see state_fields).
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
  # @return [Boolean] Whether they may.
  def self.raid_free?(peer)
    RAID_FREE_SCENES.include?(peer.state["scene"]) && peer.state["busy"] != "1" && !fights?(peer)
  end

  # Reports whether another player in a Raid World fights a battle, as their state says: it names
  # the battle (MGQ_MpBattlesHotjoin.state_fields) and its scene is a battle's.
  #
  # A battle waiting under the Library or Config tells "away", not "battle", while its game window
  # is in the background, as MGQ_MpOverworldSync::Me.scene checks that first.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
  # @return [Boolean] Whether they do.
  def self.fights?(peer)
    !peer.state["rb"].to_s.empty? && RAID_BATTLE_SCENES.include?(peer.state["scene"])
  end

  # Reports whether another player in a Raid World reads the story the player tells on the map, as
  # their state says, and neither trades nor is about to teleport: a boss battle the story starts
  # invites them too.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
  # @param viewers [Array<MGQ_MpOverworldSync::Peers::Peer>] Those the player's story is told to, see
  #   MGQ_MpCoop::Scope.viewers.
  # @return [Boolean] Whether they do.
  def self.watching?(peer, viewers)
    peer.state["scene"] == "event" && peer.state["busy"] != "1" && viewers.any? { |viewer| viewer.equal?(peer) }
  end

  # The fields the co-op battle adds to the state the player's game tells the others: in a Raid
  # World "busy", 1 while the player trades or is about to teleport, whose scene says "map" all the
  # same.
  #
  # @return [Hash] The fields, none in a Classic world.
  def self.state_fields
    return {} unless raid?

    busy = trading? || (defined?(MGQ_MpCoopGather) && MGQ_MpCoopGather.coming?)
    { "busy" => busy ? 1 : 0 }
  end

  # Reports whether the player takes part in a trade, through trade.rbx.
  #
  # @return [Boolean] Whether they do.
  def self.trading?
    defined?(MGQ_MpTrade) && MGQ_MpTrade.session ? true : false
  end

  # Tells the tile a Raid World's battle counts the players' distance from: the party leader's
  # when the leader is on the player's map, else the player's own.
  #
  # @return [Array<Integer>] The x and y.
  def self.raid_center
    leader = MGQ_MpCoop.party_leader
    if leader.is_a?(MGQ_MpOverworldSync::Peers::Peer) && leader.state["map"].to_i == $game_map.map_id
      return [leader.state["x"].to_i, leader.state["y"].to_i]
    end

    [$game_player.x, $game_player.y]
  end

  # Reports whether another player stands within NEARBY_TILES of the player, as their state tells.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
  # @return [Boolean] Whether they do.
  def self.near?(peer)
    peer.state["map"].to_i == $game_map.map_id && distance(peer, $game_player.x, $game_player.y) <= NEARBY_TILES
  end

  # Counts the steps between another player and a tile, diagonal steps counted as one.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
  # @param x [Integer] The tile's x.
  # @param y [Integer] The tile's y.
  # @return [Integer] The steps.
  def self.distance(peer, x, y)
    [(peer.state["x"].to_i - x).abs, (peer.state["y"].to_i - y).abs].max
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

  # Stretches the steps the game drew to the next random encounter by ENCOUNTER_STRETCH, varied by
  # ENCOUNTER_MARGIN, while another player who would fight it stands near (see
  # encounter_players). A player with nobody near keeps the game's draw.
  #
  # A single stretch, not one per player, lets a party of four still meet enemies, and counting
  # only those near lets players far apart on the field meet them too.
  #
  # @param steps [Numeric] The steps the game drew.
  # @return [Numeric] The steps the player takes.
  def self.party_encounter_steps(steps)
    return steps unless raid? || MGQ_MpCoop.in_party?

    players = encounter_players
    return steps if players < 2

    stretched = steps * ENCOUNTER_STRETCH * (1 - ENCOUNTER_MARGIN + rand * 2 * ENCOUNTER_MARGIN)
    log("drew #{stretched.round} steps to the next random encounter instead of #{steps.round}: #{players} #{raid? ? 'players' : 'party members'} near on the map")
    stretched
  rescue => e
    log("stretching the steps to the next random encounter failed: #{e.class}: #{e.message}")
    steps
  end

  # Counts the players who fight the player's next random encounter together, the player included:
  # in a Raid World everyone near on the map (see near?) whose connection stands, up to the
  # RAID_PLAYERS a battle holds, in a Classic world the party members near on the map.
  #
  # @return [Integer] The players, 1 for the player alone.
  def self.encounter_players
    return [MGQ_MpCoop::Scope.peers_on($game_map.map_id).count { |peer| near?(peer) } + 1, RAID_PLAYERS].min if raid?

    MGQ_MpCoop::Party.members.count { |peer| near?(peer) } + 1
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
  # members on the map, so they can come back to the map and join; see tick_hold. In a Raid World
  # only they and the players the battle takes stand still.
  #
  # @param troop_id [Integer] The troop.
  # @param can_escape [Boolean] Whether the party may escape.
  # @param can_lose [Boolean] Whether losing goes on without a game over.
  def self.hold(troop_id, can_escape, can_lose)
    busy = busy_members
    frozen = raid? ? (raid_candidates + busy).map(&:seat).uniq : nil
    @hold = { :troop => troop_id, :escape => can_escape, :lose => can_lose, :frames => HOLD_FRAMES, :seats => busy.map(&:seat), :frozen => frozen }
    busy.each { |peer| tell(peer.seat, "soon", "map" => $game_map.map_id) }
    freeze_party(frozen)
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
    if $game_map.interpreter.running?
      release(hold[:frozen])
      return log("dropped the held encounter with troop #{hold[:troop]} for an event")
    end

    log("starts the held encounter with troop #{hold[:troop]}: #{waiting.empty? ? 'every busy member is back on the map' : "the wait ran out, #{waiting.map { |peer| MGQ_MpOverworldSync.who(peer) }.join(', ')} still busy"}")
    offer(hold[:troop], hold[:escape], hold[:lose], true)
    release(hold[:frozen])
    SceneManager.call(Scene_Battle)
  end

  # Lets the players a held encounter in a Raid World made stand still walk on, those its battle
  # does not invite or bring along to a running battle (see MGQ_MpBattlesHotjoin.asked_seats),
  # through take_off.
  #
  # @param seats [Array<Integer>, nil] The seats the hold froze, nil in a Classic world.
  def self.release(seats)
    invited = MGQ_MpBattlesSync.role == :host && MGQ_MpBattlesSync.coop? ? MGQ_MpBattlesSync.seats : MGQ_MpBattlesHotjoin.asked_seats
    left = Array(seats) - invited
    tell_map(left, "off", "map" => $game_map.map_id) unless left.empty?
  end

  # Tells the player for a moment that a party member on their map met enemies, whose battle waits
  # for them to come back to the map.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  def self.take_soon(peer)
    MGQ_MpNotices.message(soon_key(peer.seat), "#{peer.state['name']} is in a battle!", HOLD_FRAMES) if defined?(MGQ_MpNotices)
  end

  # The key of the notice about another player's battle on the player's map, see take_soon and
  # take_freeze, whose notices replace each other.
  #
  # @param seat [Integer] The player's seat.
  # @return [Array] The key.
  def self.soon_key(seat)
    [:soon, seat]
  end

  # Tells every party member that the player met enemies on their map, so the members there stand
  # still until the battle invites them; in a Raid World only the players the battle takes.
  #
  # @param seats [Array<Integer>, nil] The seats of the players a Raid World's battle takes, nil
  #   in a Classic world.
  def self.freeze_party(seats = nil)
    fields = { "map" => $game_map.map_id }
    raid? ? tell_map(Array(seats), "freeze", fields) : tell(-1, "freeze", fields)
  end

  # Holds the player once a party member on their map met enemies, until the player joins the
  # battle, turns it down or FREEZE_SECONDS pass, so nobody walks off before the invite comes.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member who met them.
  # @param message [Hash] The message, the member's map under "map".
  def self.take_freeze(peer, message)
    return log("not standing still for #{MGQ_MpOverworldSync.who(peer)}: their map #{message['map']} is not the player's #{$game_map.map_id}") unless message["map"].to_i == $game_map.map_id
    return log("not standing still for #{MGQ_MpOverworldSync.who(peer)}: the player is in a battle") if MGQ_MpBattlesSync.role || SceneManager.scene.is_a?(Scene_Battle)

    @freezers = [] unless @frozen
    @freezers = Array(@freezers) | [peer.seat]
    @frozen = Time.now
    MGQ_MpNotices.message(soon_key(peer.seat), "Enemies! #{peer.state['name']} is in a battle.", FREEZE_FRAMES) if defined?(MGQ_MpNotices)
    log("stands still up to #{FREEZE_SECONDS} s: #{MGQ_MpOverworldSync.who(peer)} met enemies on map #{$game_map.map_id}")
  end

  # Reports whether the player stands still for a party member's battle on their map.
  #
  # @return [Boolean] Whether they do.
  def self.frozen?
    return false unless @frozen
    return true if Time.now - @frozen < FREEZE_SECONDS

    thaw("no invite came within #{FREEZE_SECONDS} s")
    log("stands still no more: no invite came within #{FREEZE_SECONDS} s")
    false
  end

  # Lets the player walk on before FREEZE_SECONDS passed, taking the notices of the battles that
  # made them stand still away with their reason. Nothing while the player walks.
  #
  # @param reason [String] Why, for the notices' log line.
  def self.thaw(reason)
    seats = Array(@freezers)
    @frozen = nil
    @freezers = []
    seats.each { |seat| MGQ_MpNotices.drop(soon_key(seat), reason) } if defined?(MGQ_MpNotices)
  end

  # Lets the player walk on once a host whose battle made them stand still calls it off, unless
  # another host's battle still holds them: one that froze them too, or whose invite waits.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The host who called it off.
  def self.unfreeze_for(peer)
    @freezers = Array(@freezers) - [peer.seat]
    MGQ_MpNotices.drop(soon_key(peer.seat), "the battle was called off") if defined?(MGQ_MpNotices)
    held = !@freezers.empty? || (@invite && !@invite[:peer].equal?(peer))
    return log("still stands still after #{MGQ_MpOverworldSync.who(peer)} called their battle off: another battle holds the player") if held && @frozen

    thaw("#{MGQ_MpOverworldSync.who(peer)} called their battle off")
  end

  # As host, waits for the invited members to join or turn the battle down, then sends everyone the
  # party and the battle's level and builds the party. Without anyone joining, the battle is the
  # host's own. A rival's battle in a Raid World ends the wait, and the player joins it instead (see
  # rival?). Called at the battle's start.
  #
  # @param scene [Scene_Battle] The battle.
  # @return [Symbol, nil] An ending of battles_sync's Channel.ending, :guest once the player became
  #   a rival's guest, nil once the battle may start.
  def self.gather(scene)
    channel = MGQ_MpBattlesSync::Channel
    invited = MGQ_MpBattlesSync.seats
    joined = {}
    answered = []
    outcomes = {}
    frames = 0
    limit = join_frames
    answer = MGQ_MpBattlesSync::Waiting.wait_for(scene, raid? ? "Gathering the players..." : "Gathering the party...") do
      next :rival if @rival

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
      answered.size == invited.size || frames >= limit ? true : nil
    end
    log("gathered battle #{MGQ_MpBattlesSync.battle_id} after #{frames} frames (#{answer.inspect}): " +
        invited.map { |seat| "#{MGQ_MpBattlesSync.who(seat)} #{outcomes[seat] || 'did not answer'}" }.join(", "))
    return yield_to_rival(scene) if answer == :rival
    return answer if answer.is_a?(Symbol) && answer != :gone
    return call_off if @requester && !joined.key?(@requester)
    return stand_down if joined.empty? || answer == :gone

    MGQ_MpBattlesSync.keep_seats(joined.keys)
    players = [[MGQ_MpOverworldSync::Me.seat, MGQ_Multiplayer::Player.name.to_s] + own_build]
    joined.keys.sort.each do |seat|
      builds, vitals, max = MGQ_MpBattlesSync::Wire.parse(joined[seat].to_s)
      # A player who joined may have left the world since; their characters fight on all the same.
      peer = MGQ_MpOverworldSync::Peers.at(seat)
      players << [seat, peer ? peer.state["name"].to_s : "?", builds.to_s, Array(vitals), max.is_a?(Integer) ? max : 0]
    end
    players = arrange(players)
    level = MGQ_MpCoopLevelSync.level_for(players)
    roster = MGQ_MpBattlesSync::Wire.line([troop_entries, players.map(&:to_a), level.to_i])
    channel.post("roster", roster)
    note_troop
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

  # Ends the co-op battle before it began, since nobody joined: the battle is the host's own, which
  # other players' encounters may join in a Raid World.
  #
  # @return [nil] Nothing, the battle starts.
  def self.stand_down
    log("nobody joined battle #{MGQ_MpBattlesSync.battle_id}")
    MGQ_MpBattlesHotjoin.fight_alone(MGQ_MpBattlesSync.battle_id)
    MGQ_MpBattlesSync.finish
    MGQ_MpBattles.finish
    nil
  end

  # Tells the frames the host waits for the invited players to join: RAID_JOIN_FRAMES in a Raid
  # World, else JOIN_FRAMES.
  #
  # @return [Integer] The frames.
  def self.join_frames
    raid? ? RAID_JOIN_FRAMES : JOIN_FRAMES
  end

  # Tells the frames a guest waits for the host's party: longer than the host waits for the players
  # to join.
  #
  # @return [Integer] The frames.
  def self.roster_frames
    join_frames + ROSTER_MARGIN_FRAMES
  end

  # Reports whether an invite comes from a rival in a Raid World: another player on the player's map
  # whose battle started at the same moment as the player's random encounter, which still gathers
  # its players, inviting the player among at most RAID_PLAYERS, and whose battle is an event's or
  # who entered the map first, the lower player id among equals, as every game finds. The rival
  # hosts, and the player joins them.
  #
  # An event's battle never yields, since its event goes on by the battle's result, and an invite
  # to a battle that runs already is never a rival's (see MGQ_MpBattlesHotjoin).
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who invites.
  # @param message [Hash] The invite.
  # @return [Boolean] Whether they are a rival the player yields to.
  def self.rival?(peer, message)
    return false unless MGQ_MpBattlesSync.role == :host && MGQ_MpBattlesSync.coop? && message["bid"].to_s != MGQ_MpBattlesSync.battle_id

    rival_battle?(peer, message)
  end

  # Reports whether an invite comes from a rival, see rival?, whether or not the player hosts yet.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who invites.
  # @param message [Hash] The invite.
  # @return [Boolean] Whether they are a rival.
  def self.rival_battle?(peer, message)
    raid? && !active? && yields_to?(@random_encounter, :me, peer, message)
  end

  # Reports whether a battle on the player's map that still gathers its players yields to another
  # player's battle there, see rival?.
  #
  # @param random [Boolean] Whether the battle is a random encounter, the only kind that yields.
  # @param holder [MGQ_MpOverworldSync::Peers::Peer, Symbol] The battle's host, :me for the player.
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other battle's host.
  # @param message [Hash] The other battle's invite.
  # @return [Boolean] Whether it yields.
  def self.yields_to?(random, holder, peer, message)
    return false unless random && message["hot"] != "1"
    return false unless message["map"].to_i == $game_map.map_id && message["seats"].to_s.split(",").size < RAID_PLAYERS

    message["enc"] == "0" || earlier?(peer, holder)
  end

  # Reports whether of two battles that may meet in a Raid World the first hosts: an event's battle
  # before a random encounter, which may yield to it, else the one whose host entered the map first.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The first battle's host.
  # @param message [Hash] The first battle's invite.
  # @param other [MGQ_MpOverworldSync::Peers::Peer] The other battle's host.
  # @param other_message [Hash] The other battle's invite.
  # @return [Boolean] Whether the first hosts.
  def self.hosts_first?(peer, message, other, other_message)
    event = message["enc"] == "0"
    return event if event != (other_message["enc"] == "0")

    earlier?(peer, other)
  end

  # Reports whether a player entered the map before another, the lower player id among equals.
  #
  # @param player [MGQ_MpOverworldSync::Peers::Peer, Symbol] The player, :me for the player.
  # @param other [MGQ_MpOverworldSync::Peers::Peer, Symbol] The other, :me for the player.
  # @return [Boolean] Whether they did.
  def self.earlier?(player, other)
    scope = MGQ_MpCoop::Scope
    (scope.key_of(player) <=> scope.key_of(other)) < 0
  end

  # Reports whether an invite that waited for the player as their own battle in a Raid World began
  # comes from a rival.
  #
  # @return [Boolean] Whether it does.
  def self.waiting_rival?
    invite = @invite
    raid? && !invite.nil? && rival_battle?(invite[:peer], invite[:message])
  end

  # Answers an invite that waited for the player as their own battle in a Raid World began: keeps a
  # rival's (see rival?), turns any other down, so its host need not wait for the player.
  def self.answer_waiting_invite
    invite = @invite
    return unless invite

    @invite = nil
    return keep_rival(invite[:peer], invite[:message]) if rival?(invite[:peer], invite[:message])

    decline(invite[:peer], invite[:message], "the player began a battle of their own")
  end

  # Keeps a rival's invite, which ends the gathering of the player's own battle (see gather); of two
  # rivals the one who hosts first (see hosts_first?), turning the other down. The same invite again
  # changes nothing.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The rival.
  # @param message [Hash] The invite.
  def self.keep_rival(peer, message)
    kept = @rival
    if kept && kept[:peer].equal?(peer) && kept[:message]["bid"].to_s == message["bid"].to_s
      return log("kept #{MGQ_MpOverworldSync.who(peer)}'s invite to battle #{message['bid']} once: it came again")
    end
    if kept && hosts_first?(kept[:peer], kept[:message], peer, message)
      log("declined #{MGQ_MpOverworldSync.who(peer)}'s invite to battle #{message['bid']}: an earlier rival or an event's hosts first")
      return MGQ_MpBattlesSync.tell(peer.seat, "decline", message["bid"].to_s)
    end
    if kept
      log("declined #{MGQ_MpOverworldSync.who(kept[:peer])}'s invite to battle #{kept[:message]['bid']}: #{MGQ_MpOverworldSync.who(peer)} hosts first")
      MGQ_MpBattlesSync.tell(kept[:peer].seat, "decline", kept[:message]["bid"].to_s)
    end

    @rival = { :peer => peer, :message => message }
    log("#{MGQ_MpOverworldSync.who(peer)}'s battle #{message['bid']} started at the same moment as the player's battle #{MGQ_MpBattlesSync.battle_id}, and #{message['enc'] == '0' ? "it is an event's" : 'they entered the map first'}: the player joins theirs")
  end

  # Gives the player's battle up for the rival's (see rival?): tells the players it invited that it
  # is off, takes the rival's troop and becomes the rival's guest.
  #
  # @param scene [Scene_Battle] The battle.
  # @return [Symbol] :guest, after which the battle starts as the rival's guest.
  def self.yield_to_rival(scene)
    peer = @rival[:peer]
    message = @rival[:message]
    @rival = nil
    own_bid = MGQ_MpBattlesSync.battle_id
    tell_map(MGQ_MpBattlesSync.seats, "off", "bid" => own_bid)
    MGQ_MpBattlesSync.finish
    adopt_troop(scene, message)
    MGQ_MpBattlesHotjoin.note_invite(message)
    take_pool(message)
    MGQ_MpBattlesSync.join_world(:guest, message["bid"].to_s, [peer.seat], peer.state["name"].to_s)
    MGQ_MpBattlesSync.battle_started
    @awaited = { :peer => peer, :message => message }
    log("gave battle #{own_bid} up and joins #{MGQ_MpOverworldSync.who(peer)}'s battle #{message['bid']} against troop #{message['troop']} as a guest")
    :guest
  end

  # Reports whether the player keeps another host's invite while they wait as a guest for the party
  # of a battle in a Raid World that would yield to that host's (see yields_to?), so they follow it
  # once their own host gives up (see follow).
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who invites.
  # @param message [Hash] The invite.
  # @return [Boolean] Whether they keep it.
  def self.follows?(peer, message)
    awaited = @awaited
    sync = MGQ_MpBattlesSync
    return false unless raid? && awaited && sync.role == :guest && sync.coop? && !active? && !MGQ_MpBattlesHotjoin.late?
    return false unless awaited[:message]["bid"].to_s == sync.battle_id.to_s && !awaited[:peer].equal?(peer)

    yields_to?(awaited[:message]["enc"] == "1", awaited[:peer], peer, message)
  end

  # Moves the player from the battle whose party they waited for, which its host gave up, to the
  # battle of the invite they kept (see follows?): takes its troop and joins it as a guest, which
  # join then tells its host.
  def self.follow
    invite = @invite
    @invite = nil
    peer = invite[:peer]
    message = invite[:message]
    adopt_troop(SceneManager.scene, message)
    MGQ_MpBattlesHotjoin.note_invite(message)
    take_pool(message)
    MGQ_MpBattlesSync.join_world(:guest, message["bid"].to_s, [peer.seat], peer.state["name"].to_s)
    MGQ_MpBattlesSync.battle_started
    @awaited = invite
    @moved = true
    log("follows to #{MGQ_MpOverworldSync.who(peer)}'s battle #{message['bid']} against troop #{message['troop']}, which the player's host yielded to")
  end

  # Sets the rival's battle up in place of the player's own, as joining an invite does: its enemy
  # rates (see borrow_rates), its troop, drawn anew, its chance to escape, and whether it allows
  # escaping and losing; no first strike or surprise.
  #
  # @param scene [Scene_Battle] The battle.
  # @param message [Hash] The rival's invite.
  def self.adopt_troop(scene, message)
    borrow_rates(message)
    $game_troop.setup(message["troop"].to_i)
    BattleManager.make_escape_ratio if BattleManager.respond_to?(:make_escape_ratio)
    MGQ_MpGame.set(BattleManager, :can_escape, message["escape"] == "1")
    MGQ_MpGame.set(BattleManager, :can_lose, message["lose"] == "1")
    MGQ_MpGame.set(BattleManager, :preemptive, false)
    MGQ_MpGame.set(BattleManager, :surprise, false)
    redraw_enemies(scene)
    log("took troop #{message['troop']} of the rival's battle: #{$game_troop.members.map { |enemy| "#{enemy.enemy_id} #{enemy.name}" }.join(', ')}")
  rescue => e
    log("taking the rival's troop failed: #{e.class}: #{e.message}")
  end

  # Fights the raid boss's pools an invite names in the troop taken from it (see adopt_troop), as
  # BattleManager.setup has the battle of an accepted invite do, which a battle taken over in place
  # never runs.
  #
  # @param message [Hash] The invite.
  def self.take_pool(message)
    MGQ_MpRaidPool.set_up(message["troop"].to_i) if defined?(MGQ_MpRaidPool)
  end

  # Draws the troop's enemies anew in the battle, as they changed.
  #
  # @param scene [Scene_Battle] The battle.
  def self.redraw_enemies(scene)
    spriteset = MGQ_MpGame.get(scene, :spriteset)
    return unless spriteset

    spriteset.dispose_enemies
    spriteset.create_enemies
  end

  # Takes a host's word that their battle is off, since the host joined a rival's battle, or that
  # their held encounter does not invite the player: lets the player walk on unless another battle
  # holds them (see unfreeze_for), and forgets its invite or the rival's, or while waiting for its
  # party follows to the battle of a kept invite (see follows?) or breaks the battle off. A running
  # battle that took the player's encounter in and calls it off lets the encounter start on its own;
  # a player whose encounter the player's battle took in forgets it (see MGQ_MpBattlesHotjoin).
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The host.
  # @param message [Hash] The message, the battle's id under "bid", none for a held encounter.
  def self.take_off(peer, message)
    return if MGQ_MpBattlesHotjoin.take_off(peer, message)

    bid = message["bid"].to_s
    unfreeze_for(peer)
    if @invite && @invite[:peer].equal?(peer) && @invite[:message]["bid"] == bid
      @invite = nil
      return log("forgot #{MGQ_MpOverworldSync.who(peer)}'s invite to battle #{bid}: it is off")
    end
    if @rival && @rival[:peer].equal?(peer) && @rival[:message]["bid"] == bid
      @rival = nil
      return log("forgot #{MGQ_MpOverworldSync.who(peer)}'s rival battle #{bid}: it is off, the player's own goes on")
    end
    return unless MGQ_MpBattlesSync.role == :guest && MGQ_MpBattlesSync.battle_id == bid && !active?
    return MGQ_MpBattlesHotjoin.call_off_own if MGQ_MpBattlesHotjoin.own_troop?
    return follow if @invite

    MGQ_MpBattlesSync.break_off("#{MGQ_MpOverworldSync.who(peer)} gave battle #{bid} up for another", false)
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
    when "off" then take_off(peer, message)
    when "hot" then MGQ_MpBattlesHotjoin.take_request(peer, message)
    when "hot_ok" then MGQ_MpBattlesHotjoin.take_answer(peer, message, :accepted)
    when "hot_no" then MGQ_MpBattlesHotjoin.take_answer(peer, message, :refused)
    when "party_hot" then MGQ_MpBattlesHotjoin.take_party_offer(peer, message)
    when "party_ans" then MGQ_MpBattlesHotjoin.take_party_answer(peer, message)
    when "pick" then MGQ_MpBattlesJoin.take_request(peer, message)
    when "pick_no" then MGQ_MpBattlesJoin.take_refusal(peer, message)
    end
  rescue => e
    log("taking a co-op message failed: #{e.class}: #{e.message}")
  end

  # Takes a co-op message through the map's gate, which only a Raid World's battles use; a Classic
  # world's keep the party's gate, which drops those of players outside the party. Called by
  # coop_scope.rbx.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who sent it.
  # @param message [Hash] The message's fields.
  def self.take_map(peer, message)
    return take(peer, message) if raid?

    log_once([:map_gate, message["coop"], peer && peer.state["id"]], "dropped #{message['coop']} from #{MGQ_MpOverworldSync.who(peer)} through the map's gate: not a Raid World")
  end

  # Takes an invite to a battle: the answer of the leader the player asked to lead their battle, a
  # rival's in a Raid World (see rival?), or an invite to join on the map, which a player in a
  # battle of their own turns down at once, unless it comes from the running battle the player asks
  # to join (see MGQ_MpBattlesHotjoin.asks?). A late invite the player stopped waiting for is ignored
  # (see MGQ_MpBattlesJoin.gave_up?).
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The host.
  # @param message [Hash] The invite.
  def self.take_invite(peer, message)
    unless message["seats"].to_s.split(",").map(&:to_i).include?(MGQ_MpOverworldSync::Me.seat)
      return log("invite to battle #{message['bid']} ignored: it is for seats #{message['seats']}, not the player's")
    end
    return answer_of(peer, message, :leads) if asked?(peer, message)
    return log("ignored #{MGQ_MpOverworldSync.who(peer)}'s invite to battle #{message['bid']}: the player's own request to join it brings them") if MGQ_MpBattlesHotjoin.asks?(peer, message)
    return log("ignored #{MGQ_MpOverworldSync.who(peer)}'s late invite to battle #{message['bid']}: the player stopped waiting for it") if defined?(MGQ_MpBattlesJoin) && MGQ_MpBattlesJoin.gave_up?(peer, message)
    return keep_rival(peer, message) if rival?(peer, message)

    # Turned down at once, so the host need not wait for the player: while the player waits for the
    # leader, or is in a battle, and the leader's late invite to a battle the player hosts instead.
    reason = if @asking then "the player waits for the leader to lead battle #{@asking[:bid]}"
             elsif message["bid"] == @dropped_bid then "a late invite to a battle the player hosts instead"
             elsif follows?(peer, message) then nil
             elsif MGQ_MpBattlesSync.role then "the player is in a multiplayer battle (#{MGQ_MpBattlesSync.role})"
             elsif SceneManager.scene.is_a?(Scene_Battle) then "the player is in a battle"
             end
    if reason
      log("declined #{MGQ_MpOverworldSync.who(peer)}'s invite to battle #{message['bid']} at once: #{reason}")
      return MGQ_MpBattlesSync.tell(peer.seat, "decline", message["bid"].to_s)
    end

    return if raid? && keeps_waiting_invite?(peer, message)

    log("replaced the waiting invite to battle #{@invite[:message]['bid']} with #{MGQ_MpOverworldSync.who(peer)}'s") if @invite
    @invite = { :peer => peer, :message => message, :at => Time.now }
    until_text = MGQ_MpBattlesSync.role ? "until the player's host gives battle #{MGQ_MpBattlesSync.battle_id} up" : "until the player is free, #{ACCEPT_FRAMES / 60} s at most"
    log("keeps #{MGQ_MpOverworldSync.who(peer)}'s invite to battle #{message['bid']} against troop #{message['troop']} on map #{message['map']} #{until_text}")
  end

  # Of an invite that waits for the player in a Raid World and a newer one to another battle, keeps
  # the one whose host hosts should the two battles meet (see hosts_first?), unless it waited too
  # long, and turns the other down, so its host need not wait for the player.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The newer invite's host.
  # @param message [Hash] The newer invite.
  # @return [Boolean] Whether the waiting invite stays, the newer one turned down.
  def self.keeps_waiting_invite?(peer, message)
    waiting = @invite
    return false if waiting.nil? || waiting[:message]["bid"] == message["bid"]

    if !expired?(waiting) && hosts_first?(waiting[:peer], waiting[:message], peer, message)
      log("declined #{MGQ_MpOverworldSync.who(peer)}'s invite to battle #{message['bid']}: #{MGQ_MpOverworldSync.who(waiting[:peer])}'s waits, which hosts first")
      MGQ_MpBattlesSync.tell(peer.seat, "decline", message["bid"].to_s)
      return true
    end

    log("declined #{MGQ_MpOverworldSync.who(waiting[:peer])}'s waiting invite to battle #{waiting[:message]['bid']}: #{MGQ_MpOverworldSync.who(peer)}'s came, which hosts first, or it waited too long")
    MGQ_MpBattlesSync.tell(waiting[:peer].seat, "decline", waiting[:message]["bid"].to_s)
    false
  end

  # Keeps a member's request that the player lead their battle, refusing an earlier one that waits
  # still, whose member would otherwise wait for an answer in vain. A Raid World refuses it at once.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @param message [Hash] The request.
  def self.take_request(peer, message)
    return refuse_lead(peer, message, "the player who starts a battle in a Raid World hosts it") if raid?

    waiting = @request
    if waiting && !(waiting[:peer].equal?(peer) && waiting[:message]["bid"] == message["bid"])
      refuse_lead(waiting[:peer], waiting[:message], "a newer request from #{MGQ_MpOverworldSync.who(peer)} came")
    end
    @request = { :peer => peer, :message => message, :at => Time.now }
    log("keeps #{MGQ_MpOverworldSync.who(peer)}'s request to lead battle #{message['bid']} against troop #{message['troop']} on map #{message['map']} until the player is free, #{ACCEPT_FRAMES / 60} s at most")
  end

  # Reports whether an invite from a host to a battle waits for the player to be free, see on_map.
  #
  # @param seat [Integer] The host's seat.
  # @param bid [String] The battle's id.
  # @return [Boolean] Whether one does.
  def self.invited_by?(seat, bid)
    invite = @invite
    !invite.nil? && invite[:peer].seat == seat && invite[:message]["bid"].to_s == bid.to_s
  end

  # Reports whether an invite or a request to lead waited longer than ACCEPT_FRAMES.
  #
  # It counts by the clock, since one that arrived outside the map waits for the map, where the
  # frames count.
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

  # Names the invite or request that waits for the player to be free on the map, which lapses
  # after ACCEPT_FRAMES, so the pages of a teller's story give way to it (see
  # MGQ_MpCoopEvents.give_way_to).
  #
  # @return [String, nil] What waits, nil while nothing does.
  def self.waiting_for_player
    return "#{MGQ_MpOverworldSync.who(@invite[:peer])}'s battle invite" if @invite && MGQ_MpBattlesSync.role.nil?

    @request ? "#{MGQ_MpOverworldSync.who(@request[:peer])}'s request to lead a battle" : nil
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
    story_battle = MGQ_MpCoopGather.calling_battle?(peer, message["map"].to_i)
    return decline(peer, message, "the leader's story is about to bring the player over") if MGQ_MpCoopGather.coming? && !story_battle
    return decline(peer, message, "the player trades") if raid? && trading?
    return unless free?

    @invite = nil
    MGQ_MpCoopGather.drop_call("the player joins the battle of the story that called them") if story_battle
    accept(peer, message)
  rescue => e
    @invite = nil
    give_back_rates
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

  # Starts the invited battle as a guest, with the host's enemy rates (see borrow_rates).
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The host.
  # @param message [Hash] The invite.
  def self.accept(peer, message)
    thaw("the player joins the battle")
    # The leader's story dialogue a member reads may be on screen; the battle takes its place.
    $game_message.clear
    @joining = true
    MGQ_MpBattlesHotjoin.note_invite(message)
    borrow_rates(message)
    BattleManager.setup(message["troop"].to_i, message["escape"] == "1", message["lose"] == "1")
    MGQ_MpBattlesSync.join_world(:guest, message["bid"].to_s, [peer.seat], peer.state["name"].to_s)
    MGQ_MpBattlesSync.battle_started
    MGQ_MpBattles.begin(:coop)
    @awaited = { :peer => peer, :message => message }
    SceneManager.call(Scene_Battle)
    log("joined #{peer.state['name']}'s battle #{message['bid']} against troop #{message['troop']}")
  ensure
    @joining = false
  end

  # Writes the enemies' rates the player's game fights with, for the invites of a battle it hosts.
  #
  # @return [String] RATE_VARIABLES' values, separated by commas.
  def self.rates_text
    RATE_VARIABLES.map { |id| $game_variables[id].to_i }.join(",")
  end

  # Fights the battle the player joins with its host's enemy rates, which an invite in a Raid World
  # carries, so its enemies are as strong in every game: those of a special boss, the Colosseum or
  # the host's Labyrinth of Chaos too, whatever the player's own difficulty. Keeps the player's own
  # until the battle ends (see restore); a second invite keeps the first's.
  #
  # @param message [Hash] The invite, "rates" with rates_text of the host.
  def self.borrow_rates(message)
    rates = message["rates"].to_s.split(",")
    return unless rates.size == RATE_VARIABLES.size && rates.all? { |rate| rate =~ /\A-?\d+\z/ }

    @kept_rates ||= RATE_VARIABLES.map { |id| [id, $game_variables[id]] }
    RATE_VARIABLES.each_with_index { |id, index| $game_variables[id] = rates[index].to_i }
    log("fights with the host's enemy rates #{message['rates']} instead of the player's own #{@kept_rates.map { |_, rate| rate }.join(',')}")
  rescue => e
    log("taking the host's enemy rates failed: #{e.class}: #{e.message}")
  end

  # Puts the player's own enemy rates back once the battle they joined is over.
  def self.give_back_rates
    kept = @kept_rates
    return unless kept

    @kept_rates = nil
    kept.each { |id, rate| $game_variables[id] = rate }
    log("the player's own enemy rates #{kept.map { |_, rate| rate }.join(',')} are back")
  rescue => e
    log("putting the player's own enemy rates back failed: #{e.class}: #{e.message}")
  end

  # Turns an invite down, so the host need not wait for the player.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The host.
  # @param message [Hash] The invite.
  # @param reason [String] Why, for Multiplayer InGame.log.
  def self.decline(peer, message, reason = "?")
    @invite = nil
    thaw("the invite was turned down")
    log("declined #{MGQ_MpOverworldSync.who(peer)}'s invite to battle #{message['bid']}: #{reason}")
    MGQ_MpBattlesSync.tell(peer.seat, "decline", message["bid"].to_s)
  end

  # As guest, tells the host who joins and builds the party the host sends. Called at the battle's
  # start. A player who joins a running battle late (MGQ_MpBattlesHotjoin.late?) waits for its next
  # command phase, and takes its turn count; one whose encounter it took in fights that encounter
  # alone when the roster never comes (see own_ending?). A player who follows to another battle
  # meanwhile (see follow) joins that one, and one whose roster came turns a kept invite down.
  #
  # @param scene [Scene_Battle] The battle.
  # @return [Symbol, nil] An ending of battles_sync's Channel.ending, nil once the battle may start.
  def self.join(scene)
    hotjoin = MGQ_MpBattlesHotjoin
    # The host's party says how many of them fight and how many wait on the Backline.
    build = own_build
    MGQ_MpBattlesSync::Channel.post("join", MGQ_MpBattlesSync::Wire.line(build))
    limit = hotjoin.late? ? hotjoin::ROSTER_FRAMES : roster_frames
    log("sent join for battle #{MGQ_MpBattlesSync.battle_id} with #{Array(build[1]).size} characters, party_member_max #{build[2]}, waiting up to #{limit / 60} s for the roster")
    frames = 0
    text = hotjoin.late? ? "Joining #{MGQ_MpBattlesSync.player}'s battle at its next turn..." : "Joining #{MGQ_MpBattlesSync.player}'s battle..."
    # A late join may last a whole turn, which the box's names line tells, since the text line
    # would clip with that note and the wait names nobody.
    limit_text = lambda { [MGQ_MpUi::SECONDS_TEXT % (limit / MGQ_MpUi::FRAMES_PER_SECOND)] }
    roster = MGQ_MpBattlesSync::Waiting.wait_for(scene, text, hotjoin.late? ? limit_text : nil, UP_TO_PREFIX) do
      frames += 1
      next :called_off if hotjoin.called_off?
      next :moved if @moved

      MGQ_MpBattlesSync::Channel.take("roster") || (frames >= limit ? :late : nil)
    end
    return hotjoin.fight_own("the host called it off") if roster == :called_off
    if roster == :moved
      @moved = false
      return join(scene)
    end
    hotjoin.give_up(roster) if roster.is_a?(Symbol)
    return hotjoin.fight_own(roster == :late ? "the host's party never came" : "the host's battle ended before its party came (#{roster.inspect})") if own_ending?(roster)
    return left_out("the host's party never came") if roster == :late
    if roster.is_a?(Symbol)
      log("no roster for battle #{MGQ_MpBattlesSync.battle_id}: the wait ended with #{roster.inspect}")
      return roster
    end

    enemies, players, level, turn = MGQ_MpBattlesSync::Wire.parse(roster.to_s)
    players = Player.read_all(players)
    log("took the roster of battle #{MGQ_MpBattlesSync.battle_id} (#{roster.to_s.size} bytes): #{Array(enemies).size} enemies, #{players.size} players, level #{level.inspect}#{", turn #{turn}" if turn}")
    decline(@invite[:peer], @invite[:message], "the player's battle #{MGQ_MpBattlesSync.battle_id} began") if @invite
    return left_out("the host's party came without the player") unless players.any? { |player| player.seat == MGQ_MpOverworldSync::Me.seat }

    MGQ_MpGame.set($game_troop, :turn_count, turn) if turn.is_a?(Integer)
    take_troop(scene, Array(enemies))
    hotjoin.escape_anew if hotjoin.late?
    MGQ_MpCoopLevelSync.begin(level)
    form(scene, players)
    nil
  end

  # Reports whether a guest's wait for the roster ended so that the player's own encounter starts on
  # its own (see MGQ_MpBattlesHotjoin.fight_own): the player asked a running battle to take it in,
  # and its party never came, its host left or the battle broke off.
  #
  # @param ending [Object] How the wait ended, see join.
  # @return [Boolean] Whether it did.
  def self.own_ending?(ending)
    MGQ_MpBattlesHotjoin.own_troop? && [:late, :gone, :broken].include?(ending)
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

  # Notes the troop as the battle's guests know it now, see share_troop: after the roster, and as a
  # battle fought alone turns live for the players it took in.
  def self.note_troop
    @shared_troop = troop_signature
  end

  # Describes the troop as share_troop compares it: each enemy, what it is and whether it is hidden.
  # A fallen enemy counts as shown, also one the game hid as it was eaten, which the guests keep
  # fallen (see MGQ_MpBattlesHotjoin.mark).
  #
  # @return [Array<Array>] Each enemy's object id, enemy id, and 1 when hidden, else 0.
  def self.troop_signature
    $game_troop.members.map { |enemy| [enemy.object_id, enemy.enemy_id, MGQ_MpBattlesHotjoin.mark(enemy) == 1 ? 1 : 0] }
  end

  # As host, tells the guests the troop once it differs from what they last heard of (see
  # note_troop): enemies added mid-battle, such as by another mod or an encounter taken in, or an
  # enemy that transformed, appeared or hid. Each guest adds the new enemies after its own and
  # transforms, shows or hides its own as the host's (see MGQ_MpBattlesHotjoin.take_troop). Called
  # before every send of the host's stream, which may name the new enemies, and as a command phase
  # opens.
  #
  # @param seats [Array<Integer>, nil] The world seats of the guests to tell, nil for those still in
  #   the battle.
  def self.share_troop(seats = nil)
    sync = MGQ_MpBattlesSync
    return unless sync.host? && sync.coop? && active?

    seats ||= sync.guests_in
    current = troop_signature
    return if current == @shared_troop

    hotjoin = MGQ_MpBattlesHotjoin
    hotjoin.send_to(seats, "coop_troop", sync::Wire.line([hotjoin.late_entries, sync.names]))
    # Noted only once sent, so a send that failed is tried again before the next one.
    @shared_troop = current
    log("the troop of battle #{sync.battle_id} changed, now #{current.size} enemies (#{current.count { |_, _, hidden| hidden == 1 }} hidden)" +
        (seats.empty? ? ", no guest to tell" : ""))
  rescue => e
    log("telling the guests the troop failed: #{e.class}: #{e.message}")
  end

  # Repairs the enemies the host named, each at its place, since the host's stream names an enemy
  # by its place in the troop: a screen x or y that is no number becomes that of this game's enemy
  # at the place, else 0, and a mark that is no number 0, each logged once per field and kind.
  #
  # @param enemies [Array] The host's enemies, see troop_entries.
  # @return [Array<Array>, nil] The enemies, or nil when one of them is no enemy this game has,
  #   which keeps this game's own troop.
  def self.repaired_enemies(enemies)
    own = $game_troop.members
    repaired = Array(enemies).each_with_index.map do |entry, index|
      return dropped(:enemy, entry, "the host's troop for its") unless entry.is_a?(Array)
      return dropped(:id, entry[0], "the host's troop for its enemy") unless entry[0].is_a?(Integer)

      enemy = own[index]
      [entry[0], enemy_field(entry, :x, enemy ? enemy.screen_x : 0), enemy_field(entry, :y, enemy ? enemy.screen_y : 0),
       enemy_field(entry, :mark, 0)]
    end
    missing = repaired.map(&:first).reject { |id| known_enemy?(id) }
    return repaired if missing.empty?

    log("the host's troop holds enemies this game lacks (#{missing.join(', ')}); it keeps its own")
    nil
  end

  # Reads a field of an enemy the host named, see repaired_enemies.
  #
  # @param entry [Array] The enemy, see troop_entries.
  # @param field [Symbol] The field, one of ENEMY_FIELDS.
  # @param fallback [Integer] What stands for a field that is no number.
  # @return [Integer] The field, else the fallback.
  def self.enemy_field(entry, field, fallback)
    value = entry[ENEMY_FIELDS.index(field)]
    value.is_a?(Integer) ? value : dropped(field, value, "the host's enemy") || fallback
  end

  # Reports whether an enemy id the host named is one this game's database has.
  #
  # @param id [Integer] The id.
  # @return [Boolean] Whether this game has the enemy.
  def self.known_enemy?(id)
    id > 0 && $data_enemies[id] ? true : false
  rescue RangeError
    # An id too large for an index raises instead of giving nil.
    false
  end

  # As guest, fights the host's enemies in place of the player's own, which mods of either game
  # may have changed, such as one that doubles them: the host names every enemy by its place.
  # Keeps the player's own when one of them is no enemy this game has (see repaired_enemies).
  #
  # @param scene [Scene_Battle] The battle.
  # @param enemies [Array<Array>] The host's enemies, see troop_entries.
  def self.take_troop(scene, enemies)
    enemies = repaired_enemies(enemies)
    return if enemies.nil? || enemies.empty?
    return log("the host's troop of #{enemies.size} enemies matches this game's own") if enemies == troop_entries

    rebuilt = enemies.each_with_index.map do |(id, x, y, hidden), index|
      enemy = Game_Enemy.new(index, id.to_i)
      enemy.screen_x = x.to_i
      enemy.screen_y = y.to_i
      enemy.hide if hidden.to_i == 1
      enemy
    end
    MGQ_MpGame.set($game_troop, :enemies, rebuilt)
    MGQ_MpRaidPool.rescale if defined?(MGQ_MpRaidPool)
    # The game counts each name's enemies for their letters, so the count starts over as in setup.
    MGQ_MpGame.set($game_troop, :names_count, {})
    MGQ_MpGame.call($game_troop, :make_unique_names)
    # The game letters only the living, and the host's fallen got theirs before they fell.
    rebuilt.each_with_index do |enemy, index|
      MGQ_MpBattlesHotjoin.lay_down(enemy) if enemies[index][3].to_i == MGQ_MpBattlesHotjoin::FALLEN
    end
    spriteset = MGQ_MpGame.get(scene, :spriteset)
    if spriteset
      spriteset.dispose_enemies
      spriteset.create_enemies
    end
    log("took the host's troop of #{rebuilt.size} enemies in place of this game's own: #{rebuilt.map { |enemy| "#{enemy.enemy_id} #{enemy.name}#{' (hidden)' if enemy.hidden?}#{' (fallen)' if enemy.dead?}" }.join(', ')}")
  rescue => e
    log("taking the host's troop failed: #{e.class}: #{e.message}")
  end

  # Both sides.

  # Writes the player's characters for a co-op battle: as many as their squad holds with the fewest
  # players, in a Raid World its larger squad of a regular fight and a raid, which the battle's
  # places then count. Starts the battle's party anew.
  #
  # @return [Array] The builds, see MGQ_MpActors::Builds, each character's HP and MP, and the
  #   player's party_member_max, which decides their share of the Backline.
  def self.own_build
    max = $game_party.party_member_max
    squad = MGQ_MpCoopSquad
    if squad.raid?
      size = squad.largest_squad(max)
      @own_squad = squad.own_order(size)
      limit = "a squad of #{size}"
    else
      front, bench = squad.battle_share(0, FEWEST_PLAYERS, max)
      @own_squad = squad.own_order.first(front + bench)
      limit = "#{front} + #{bench}"
    end
    @allies = {}
    log("brings #{@own_squad.size} characters (up to #{limit} of party_member_max #{max}): #{squad_text}")
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

  # Writes the player's Frontline for a team duel, whose places its characters count, their squad in
  # a Raid World, and starts the duel's party anew.
  #
  # @return [Array] The builds, see MGQ_MpActors::Builds, and the player's party_member_max.
  def self.team_build
    squad = MGQ_MpCoopSquad
    @own_squad = squad.raid? ? squad.raid_team : squad.own_order.first(squad::FRONTLINE)
    @allies = {}
    log("brings #{@own_squad.size} characters to a team duel: #{squad_text}")
    [MGQ_MpActors::Builds.write(@own_squad), $game_party.party_member_max]
  end

  # Orders the battle's players as their party does, the leader first, and tells each player's
  # share of the Frontline and of the Backline in the battle, and the order of their places. A
  # co-op battle in a Raid World puts its host first, whose game calls this, and gives every player
  # their squad by the world's rules, with the Frontline's places split between them (see
  # MGQ_MpCoopSquad.battle_share); a team duel's shares are split as in a Classic world.
  #
  # @param players [Array<Player, Array>] The players, or their fields: at least each one's seat,
  #   name, builds, HP and MP and party_member_max.
  # @param backline [Boolean] Whether the players bring a share of the Backline, which a team duel's
  #   do not.
  # @return [Array<Player>] The players in the party's order, each with the order of their places
  #   and their shares of the Frontline and of the Backline.
  def self.arrange(players, backline = true)
    players = Player.read_all(players)
    hosted = backline && raid?
    first = lambda { |seat| hosted ? seat == MGQ_MpOverworldSync::Me.seat : leads?(seat) }
    ranked = MGQ_MpCoopSquad.ranked(players.map { |player| [player_id(player.seat), first.call(player.seat)] })
    players = players.sort_by { |player| ranked.index(player_id(player.seat)) }
    players.each_with_index.map do |player, position|
      count = MGQ_MpActors::Builds.parse(player.builds.to_s, MOST_CHARACTERS).size
      squad = MGQ_MpCoopSquad
      front, bench = backline ? squad.battle_share(position, players.size, player.max.to_i) : squad.share(position, players.size, player.max.to_i)
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

  # Drops a field another game sent that is of the wrong kind, logging it once per field and kind.
  #
  # @param field [Symbol] The field's name.
  # @param value [Object] Its value.
  # @param owner [String] Whose field it is, as the log names it.
  # @return [nil] Nothing, which stands for the field.
  def self.dropped(field, value, owner = "a player's")
    log_once([:dropped, field, value.class.name], "dropped #{owner} #{field} another game sent as #{value.class}")
  end

  # Lists the battle's players, as form took them.
  #
  # @return [Array<Player>] The players, none before the party is formed.
  def self.players
    Array(@players)
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

  # Reports whether the player may swap a character of their own Backline in, as the game's Party
  # command allows it (Window_PartyCommand#can_shift_change?): one of them stands, and neither the
  # game's switch nor a challenge battle forbids the change.
  #
  # Alone the game ends the battle once the Frontline is down, so it never opens the command phase
  # for a swap alone; in a co-op battle the other players fight on.
  #
  # @return [Boolean] Whether they may.
  def self.may_swap_in?
    return false unless own_bench.any?(&:alive?)
    return false if defined?(NWConst::Sw::FORBID_BATTLE_SHIFT_CHANGE) && $game_switches[NWConst::Sw::FORBID_BATTLE_SHIFT_CHANGE]

    !($game_troop.respond_to?(:challenge_battle?) && $game_troop.challenge_battle?)
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
    @players = Player.read_all(players)
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
  # host's sends. Alone, the host fights on with their own full team, as in a battle of their own,
  # which in a Raid World is their squad (see MGQ_MpCoopSquad.raid_battle?). Called when a command
  # phase starts.
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
    before = player_seats
    form(scene, Array(players && players[0]))
    tell_joined(player_seats - before)
  rescue => e
    log("taking the new party failed: #{e.class}: #{e.message}")
  end

  # Tells the player, in the battle's chat log, of the players who joined the running battle: on
  # the host as it takes them in (see MGQ_MpBattlesHotjoin.take_in), on a guest as the host's new
  # party names them.
  #
  # @param seats [Array<Integer>] The seats new to the party.
  def self.tell_joined(seats)
    (seats - [MGQ_MpOverworldSync::Me.seat]).each do |seat|
      peer = MGQ_MpOverworldSync::Peers.at(seat)
      next MGQ_MpBattlesSync::Departures.joined(peer) if peer

      log("#{MGQ_MpBattlesSync.who(seat)} joined battle #{MGQ_MpBattlesSync.battle_id}, which the player is not told: the game does not know them")
    end
  rescue => e
    log("telling who joined failed: #{e.class}: #{e.message}")
  end

  # As host, fights on alone with the player's own full team, as in a battle of their own: in a Raid
  # World their squad by the world's squad rules.
  #
  # @param scene [Scene_Battle] The battle.
  def self.go_solo(scene)
    log("everyone else left battle #{MGQ_MpBattlesSync.battle_id}, it goes on alone")
    stand_alone(scene)
  end

  # As guest, fights on alone once the host got away or is gone: the player's own full team takes
  # the battle over from where the host's stream left it, as a battle of their own (in a Raid World
  # their squad).
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
    MGQ_MpRaidPool.taken_over if defined?(MGQ_MpRaidPool) && MGQ_MpRaidPool.respond_to?(:taken_over)
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
  # every battler at a battle's start, keeping the barriers the stream gave, and a defeat scene of
  # its enemies, which the game picks at the start and with each enemy's action.
  def self.resume_alone
    ($game_party.battle_members + $game_troop.members).each do |battler|
      next unless battler.respond_to?(:set_counter)

      walls = battler.respond_to?(:defence_wall) ? battler.defence_wall : nil
      battler.set_counter
      MGQ_MpBattlesSync::Playback.set_walls(battler, walls) if walls
    end
    MGQ_MpBattlesSync::Live.pick_defeat_scene(false)
  end

  # Ends the co-op side of the battle, which goes on as the player's own: their own full team, the
  # game's own settings, no live battle; in a Raid World one that other players' encounters may join.
  #
  # @param scene [Scene_Battle] The battle.
  def self.stand_alone(scene)
    MGQ_MpBattlesHotjoin.call_off("the battle goes on alone")
    forget
    MGQ_MpBattlesSync.finish
    MGQ_MpBattles.finish
    MGQ_MpBattlesHotjoin.fight_alone
    show_party(scene, $game_party.battle_members)
    log("fights on with the player's own party: #{members_text($game_party.battle_members)}")
  end

  # Puts back what a battle lent the player's game that its save keeps: the player's own enemy rates
  # and the stats of their characters the level sync changed. Called as BattleManager.battle_end
  # ends, and again once the battle's scene ended, which then puts nothing back twice.
  #
  # The game's victory saves its autosave right after battle_end, before the battle's scene ends.
  def self.restore
    give_back_rates
    MGQ_MpCoopLevelSync.finish if active?
  rescue => e
    log("putting the player's own rates and stats back failed: #{e.class}: #{e.message}")
  end

  # Ends a co-op battle: the player's own party and enemy rates again, the game's own settings back,
  # and the live battle over. A battle the player hosted alone for players who never joined stays
  # their own, its Retry kept. Called once the battle's scene ended.
  def self.ended
    restore
    alone = MGQ_MpBattlesHotjoin.waiting_alone? && MGQ_MpBattles.kind != :coop
    MGQ_MpBattlesHotjoin.ended
    return MGQ_MpBattlesSync.finish if alone
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

  # Forgets a co-op battle a reset interrupted, and every invite, request, hold and the enemy rates
  # kept, without touching any character or variable, whose save the reset dropped.
  def self.drop
    held = [("the battle" if @members), ("the hold" if @hold), ("the request to the leader" if @asking),
            ("an invite" if @invite), ("a request to lead" if @request)].compact
    log("forgot #{held.join(', ')} after a reset") unless held.empty?
    @result = nil
    MGQ_MpBattlesHotjoin.drop
    drop_hold
    clear
    @asking = nil
    @invite = nil
    @request = nil
    thaw("a reset forgets it")
    @kept_rates = nil
  end

  # Forgets the co-op party, its players and their characters, the troop the guests know, a
  # rival's invite and the battle the player joined as a guest.
  def self.clear
    @seen = nil
    @shared_troop = nil
    @members = nil
    @players = nil
    @own_squad = nil
    @allies = {}
    @reordered = false
    @requester = nil
    @rival = nil
    @random_encounter = false
    @awaited = nil
    @moved = false
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

    order = Array(player.order)
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

  # Installs the hooks on methods the game's plugins may define anew. Called as the game starts
  # running.
  def self.install
    return if @installed

    @installed = true
    install_party
    install_targets
    install_shift_change
    install_status_names
    install_counts
    install_end
    install_encounters
  end

  # Stretches the steps to the next random encounter for a party once the game drew them.
  def self.install_encounters
    MGQ_MpHooks.after(Game_Player, :make_encounter_count, "battles_coop") { mgq_mp_party_encounter_steps }
  rescue => e
    log("encounter steps hook FAILED: #{e.class}: #{e.message}")
  end

  # Puts back what the battle lent the player's game as the battle ends, before the game saves (see
  # restore), and ends a co-op battle once the battle's scene ended, not when it only called another
  # screen.
  def self.install_end
    MGQ_MpHooks.after(BattleManager.singleton_class, :battle_end, "battles_coop") { |*_args| MGQ_MpBattlesCoop.restore }
    MGQ_MpHooks.after(Scene_Battle, :terminate, "battles_coop") { MGQ_MpBattlesCoop.ended unless MGQ_MpBattlesCoop.called_away?(self) }
  rescue => e
    log("battle end hook FAILED: #{e.class}: #{e.message}")
  end

  # Reports whether a battle's scene only called another screen, such as the Library or Config of
  # the party command, which ends the scene but comes back to the same battle: SceneManager.call
  # keeps the scene on the stack meanwhile.
  #
  # @param scene [Scene_Battle] The battle's scene.
  # @return [Boolean] Whether it waits on the stack.
  def self.called_away?(scene)
    stack = MGQ_MpGame.get(SceneManager, :stack)
    called = stack.is_a?(Array) && stack.any? { |waiting| waiting.equal?(scene) }
    log("the battle called #{SceneManager.scene.class} and goes on once it returns") if called
    called
  end

  # Reports whether the player is in a battle: in its scene, or in a screen its party command
  # called, such as the Library or Config, while the battle waits on SceneManager's stack as in
  # called_away?.
  #
  # @return [Boolean] Whether they are.
  def self.in_battle_scene?
    current = SceneManager.scene
    return true if current.is_a?(Scene_Battle)
    return false if current.is_a?(Scene_Map)

    stack = MGQ_MpGame.get(SceneManager, :stack)
    stack.is_a?(Array) && stack.any? { |waiting| waiting.is_a?(Scene_Battle) }
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

      alias_method :mgq_mp_battles_coop_inputable?, :inputable?

      # Reports whether the party takes commands this turn: also while a co-op battle runs and the
      # player's Frontline is down, as long as their Backline may swap in (see
      # MGQ_MpBattlesCoop.may_swap_in?), so the command phase offers the Party command.
      #
      # @return [Boolean] Whether it does.
      def inputable?
        mgq_mp_battles_coop_inputable? || (MGQ_MpBattlesCoop.active? && MGQ_MpBattlesCoop.may_swap_in?)
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

  # Draws each character's name in the battle's status window in its player's color while a co-op
  # battle runs, see draw_status_name.
  def self.install_status_names
    MGQ_MpHooks.around(Window_BattleStatus, :draw_actor_name, "battles_coop") do |window, args, original|
      MGQ_MpBattlesCoop.draw_status_name(window, args, original)
    end
  rescue => e
    log("status names hook FAILED: #{e.class}: #{e.message}")
  end

  # Draws a character's name in the status window of a co-op battle: the player's own in
  # MGQ_MpUi::Style::OWN, another player's character by its own name, without its owner, in its
  # owner's MGQ_MpUi::PlayerColor. A character in crisis or knocked out is left to the game, which
  # colors it (hp_color: below a quarter of its max HP, which covers 0); so is every character
  # outside a co-op battle, and one drawn without a width.
  #
  # @param window [Window_BattleStatus] The window.
  # @param args [Array] The character, x, y and width, as draw_actor_name takes them.
  # @param original [Proc] Draws the name as the game does.
  # @return [Object] What the game's drawing returns, nil for the mod's.
  def self.draw_status_name(window, args, original)
    actor, x, y, width = args
    return original.call unless active? && actor && width && actor.hp >= actor.mhp / 4

    ally = actor.is_a?(Game_MpAlly)
    window.change_color(ally ? MGQ_MpUi::PlayerColor.of(MGQ_MpOverworldSync::Peers.at(actor.mp_seat) || actor.owner) : MGQ_MpUi::Style::OWN)
    window.draw_text(x, y, width, window.line_height, MGQ_MpUi.cut(window, ally ? actor.base_name : actor.name, width))
    nil
  rescue => e
    # A wrapped method's body runs without MGQ_MpHooks' rescue, and a raise here would take the
    # status window down every time it refreshes.
    log_once([:status_name, actor && actor.id], "drawing a status name failed, the game draws it: #{e.class}: #{e.message}")
    original.call
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
    MGQ_MpBattlesHotjoin.await(scene)
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
    MGQ_MpBattlesHotjoin.settle(scene)
    MGQ_MpBattlesCoop.settle(scene)
    MGQ_MpBattlesCoop.share_troop
    MGQ_MpBattlesCoop.note_places
  end

  # (see MGQ_MpBattles::Mode#before_send)
  def self.before_send
    MGQ_MpBattlesCoop.share_troop
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
    ["coop_party", "coop_troop"]
  end

  # (see MGQ_MpBattles::Mode#take)
  def self.take(kind, scene, body)
    kind == "coop_troop" ? MGQ_MpBattlesHotjoin.take_troop(scene, body) : MGQ_MpBattlesCoop.reform(scene, body)
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

# What this script takes part in of the party's messages, through coop.rbx, and in a Raid World of
# the map's, through coop_scope.rbx.

begin
  MGQ_MpCoop.route("coop") { |peer, message| MGQ_MpBattlesCoop.take(peer, message) }
  MGQ_MpCoop.route_map("coop") { |peer, message| MGQ_MpBattlesCoop.take_map(peer, message) }
  MGQ_MpOverworldSync.state_fields { MGQ_MpBattlesCoop.state_fields }
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

# What the party asks of the player.

class Game_Player
  # Stretches the steps to the next random encounter the game just drew for the party, see
  # MGQ_MpBattlesCoop.party_encounter_steps.
  def mgq_mp_party_encounter_steps
    @encounter_count = MGQ_MpBattlesCoop.party_encounter_steps(@encounter_count)
  end
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

# What the pages of a teller's story give way to, through coop_events.rbx.

begin
  MGQ_MpCoopEvents.give_way_to { MGQ_MpBattlesCoop.waiting_for_player }
rescue => e
  MGQ_MpBattlesCoop.log("giving way FAILED: #{e.class}: #{e.message}")
end
