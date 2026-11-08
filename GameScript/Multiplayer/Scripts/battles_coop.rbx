#----------------------------------------------------------------
#  battles_coop.rbx
#
#  Changelog:
#      Paulinchen  2026-11-08: Named the characters in the battle's status window through the Mod Framework's row patch instead of drawing them
#      Paulinchen  2026-11-06: Read the player's own color in the status window through the Mod Framework's UI.color_now
#                            - Dropped RAID_PLAYERS, which the DLL's CoopMatchmaking keeps
#      Paulinchen  2026-11-05: Handed the enemy rates, the invite's fields and whether the player is busy as values, and read the invites' flags as true or false
#                            - Had C# write and read the joins and the troop's changes
#                            - Built other players' characters and the host's troop through MGQ_MpBattlers
#                            - Started a rival's troop taken after the battle's start through MGQ_MpBattlers
#                            - Let a guest that takes a battle over go on from the battlers its start made whole, started once
#                            - Told whether a battle's invite is open for the player, which the screens the mod opens on its own wait for
#                            - Dropped the copies of the free and fighting rules, which the DLL's Sessions decides
#                            - Told whether the player types in the chat box, so a waiting invite waits for them
#      Paulinchen  2026-11-01: Named the Mod Framework's interface by its own name
#      Paulinchen  2026-10-31: Took a player's color from MGQ_MpPlayerColor
#                            - Checked a rebuilt character before its battle start states, as its owner's game measured it
#      Paulinchen  2026-10-30: Decided offers, held encounters, the stand-still and the encounter's steps through the matchmaking in the DLL
#                            - Wrote and read the roster and the party, repaired the host's troop and settled departures through the rules in C#
#                            - Kept invites, requests to lead and rivals in the DLL, which takes their messages and hands the rest over
#                            - Left the answers to the player's requests and the party members' offers to the DLL
#                            - Gathered the joins and waited for the roster through the live session in the DLL
#      Paulinchen  2026-10-23: Arranged the battle's players through the DLL or the core library
#                            - Removed the unused ROSTER_FRAMES and the side battle check of older pool scripts
#                            - Found the battle's players by the seats they held at its start
#                            - Let the starter of a battle the server never started fight it as their own and named the server to its guests
#                            - Sent a guest whose battle ended before its roster back to the map, told why
#                            - Kept a guest's own enemies at the host's places when only their places differ
#                            - Made rebuilt enemies of the kind the troop's battle needs
#      Paulinchen  2026-10-17: Started another player's character in battle at the HP it came with
#      Paulinchen  2026-10-15: Handed a gathered battle to the battle server and followed one there as guest
#                            - Passed requests to join a served battle on to the battle server and joined one late on its channel
#                            - Kept a served battle on the server for its last player and ended one every player left
#                            - Stood the player's own characters up with 1 HP after a battle won while all of them fell
#                            - Stood them up as well when a save loads in a world with all of them fallen
#      Paulinchen  2026-10-13: Told the guests of a Classic world's battle whether its boss fights at its tier
#                            - Brought a Raid World player's squad by the world's squad rules
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
# first, then those nearest the party's leader, up to the DLL's CoopMatchmaking.RaidPlayers (see raid_candidates). The
# player who starts it hosts it; of a random encounter and another player's battle started at the
# same moment, an event's battle or else the player who entered the map first hosts, and the other
# joins as a guest with the players who joined them (CoopMatchmaking in the DLL). Every player's
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

  # What starts the waiting box's names line of a player who joins a running battle at its next
  # turn, which names no player: how long the wait may last.
  UP_TO_PREFIX = "Up to "

  # The field of a running battle's "off" that tells the player why it called their joining off,
  # see MGQ_MpBattlesHotjoin::OFF_OVER.
  OFF_WHY_FIELD = "why"

  # What a guest is told whose battle ended before they got into it, with its host's name.
  MISSED_TEXT = "%s's battle ended before you could join."

  # What a guest is told whom the host's party left out, with the host's name.
  LEFT_OUT_TEXT = "%s's battle went on without you."

  # How the host of a battle on the battle server is named in what a guest is told.
  SERVER_NAME = "The server"

  # The endings of a guest's wait for the roster after which the player never got the battle.
  MISSED_ENDINGS = [:gone, :broken, :forfeit]

  # Players the characters a player sends are counted for: two, the fewest who share a battle,
  # whose squads are the largest, so a party that loses a player can bring more.
  FEWEST_PLAYERS = 2

  # Characters a player's builds hold at most, the game's largest party.
  MOST_CHARACTERS = 14

  # The topic that orders a battle's players and tells their places, which the DLL answers in the
  # game and the core library on the battle server.
  ARRANGE_TOPIC = "squad.arrange"

  # The topic that writes the roster a host sends.
  WRITE_ROSTER_TOPIC = "coop.write_roster"

  # The topic that writes the party a host sends.
  WRITE_PARTY_TOPIC = "coop.write_party"

  # The topic that reads the roster on a guest.
  READ_ROSTER_TOPIC = "coop.read_roster"

  # The topic that reads the party on a guest.
  READ_PARTY_TOPIC = "coop.read_party"

  # The topic that repairs the host's enemies a guest fights.
  REPAIR_TOPIC = "coop.repair"

  # The topic that decides what the host does once players left.
  SETTLE_TOPIC = "coop.settle"

  # The variables of the enemies' strength the game reads as their parameters are asked: the rates
  # of their HP, attack, defense, agility, instant death resistance and MP, which the difficulty, a
  # fight's own values or the Labyrinth of Chaos's level set. The rates of experience, job
  # experience and gold (46, 49, 47) stay each player's own rewards.
  RATE_VARIABLES = [41, 42, 43, 44, 45, 48]

  # A player of a co-op battle, or of a side of a team duel. The battle's messages carry a player
  # as their fields in this order; the rules in C# read the roster's and the party's, Player.read
  # those of a team duel and of a served battle's setup.
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

  # What starts this script's lines in the log.
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

  # The results of a battle as the game numbers them, for the log.
  RESULTS = { 0 => "won", 1 => "escaped", 2 => "lost" }

  # Writes a message's fields for the log.
  #
  # @param fields [Hash] The fields.
  # @return [String] The fields as name=value pairs.
  def self.fields_text(fields)
    fields.reject { |key, _| key.is_a?(Symbol) }.map { |key, value| "#{key}=#{value}" }.join(" ")
  rescue
    "?"
  end

  # Names a character of a player's builds by its place, for the log.
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

  # Describes a battle player's share of the Frontline and of the Backline, for the log.
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

  # The topic of a battle the game just set up, which the DLL's matchmaking answers.
  OFFER_TOPIC = "coop.offer"

  # The topic that hosts a battle the player set up after all.
  HOST_TOPIC = "coop.host"

  # The topic of a frame on the map.
  POLL_TOPIC = "coop.poll"

  # The topic that lets the players a held encounter made stand still walk on.
  RELEASE_TOPIC = "coop.release"

  # The topic of the steps the game drew to the next random encounter.
  STEPS_TOPIC = "coop.steps"

  # The topic of the player's facts before a frame, which the co-op messages of the frame read.
  FRAME_TOPIC = "coop.frame"

  # The topic of a host's word that their battle is off.
  TAKE_OFF_TOPIC = "coop.take_off"

  # The topic of a frame of the wait for the party's leader to lead the player's battle.
  LEADER_WAIT_TOPIC = "coop.leader_wait"

  # The topic that ends the wait for the party's leader.
  LEADER_END_TOPIC = "coop.leader_end"

  # The topic that gives the player's battle up for a rival's.
  YIELD_TOPIC = "coop.yield"

  # The topic that turns down the invite that waits for the player.
  DECLINE_WAITING_TOPIC = "coop.decline_waiting"

  # The topic that refuses to lead a member's battle.
  REFUSE_LEAD_TOPIC = "coop.refuse_lead"

  # The topic that forgets the battle that ended: its rival and the invite it joined.
  CLEAR_TOPIC = "coop.clear"

  # The topic of a player's word that hotjoining is off, which the DLL's asking side takes first.
  ASK_OFF_TOPIC = "coop.ask_off"

  # The topic of the host's gathering of the players it invited, from the live battle's session.
  GATHER_TOPIC = "coop.gather"

  # The topic of a guest's wait for the host's roster, from the live battle's session.
  ROSTER_WAIT_TOPIC = "coop.roster_wait"

  # The topic that tells the party, or the players a Raid World's battle takes, to stand still.
  FREEZE_PARTY_TOPIC = "coop.freeze_party"

  # The topic that lists the players a battle in a Raid World takes.
  CANDIDATES_TOPIC = "coop.raid_candidates"

  # The topic that forgets a held encounter and the stand-still after a reset.
  DROP_TOPIC = "coop.drop"

  # The event of a message for the notification box.
  NOTICE_EVENT = "coop.notice"

  # The event that takes a message of the notification box away.
  DROP_NOTICE_EVENT = "coop.drop_notice"

  # The event of the matchmaking's status, once a co-op message changed it.
  STATUS_EVENT = "coop.status"

  # The event of a co-op message the matchmaking leaves to the scripts.
  MESSAGE_EVENT = "coop.message"

  # Makes a battle the game just set up a co-op battle, as the DLL's matchmaking decides (topic
  # coop.offer): it asks the party's leader to lead it when the leader plays on the map (see
  # await_leader), else invites the party members on the map who are playing on it; in a Raid World
  # the player hosts it and invites the players on the map, unless it is a random encounter that
  # joins a battle running on the map (MGQ_MpBattlesHotjoin.ask) or a side battle against a raid
  # boss, which starts as the player's own (see side_battle?). A random encounter waits for busy
  # party members on the map first. Called after BattleManager.setup.
  #
  # @param troop_id [Integer] The troop.
  # @param can_escape [Boolean] Whether the party may escape.
  # @param can_lose [Boolean] Whether losing goes on without a game over.
  # @param encounter [Boolean] Whether the battle is a random encounter, the only kind that yields to
  #   a rival's.
  # @param asked_hot [Boolean] Whether the running battle the player asked did not take it in.
  def self.offer(troop_id, can_escape, can_lose, encounter = @encountering, asked_hot = false)
    request = offer_request(troop_id, can_escape, can_lose, encounter).merge("asked_hot" => asked_hot ? true : false)
    act(MGQ_Multiplayer::Bridge.call(OFFER_TOPIC, request), troop_id, can_escape, can_lose, encounter)
  rescue => e
    log("could not offer a co-op battle: #{e.class}: #{e.message}")
  end

  # Hosts a battle the player set up after all, as the DLL's matchmaking hosts it (topic coop.host):
  # inviting the party members on the map who are playing on it, in a Raid World the players near.
  #
  # @param troop_id [Integer] The troop.
  # @param can_escape [Boolean] Whether the party may escape.
  # @param can_lose [Boolean] Whether losing goes on without a game over.
  # @param battle_id [String, nil] The battle's id the member who asked chose, nil for a new one.
  def self.host(troop_id, can_escape, can_lose, battle_id = nil)
    request = offer_request(troop_id, can_escape, can_lose, false).merge("bid" => battle_id)
    act(MGQ_Multiplayer::Bridge.call(HOST_TOPIC, request), troop_id, can_escape, can_lose, false)
  rescue => e
    log("could not host a co-op battle: #{e.class}: #{e.message}")
  end

  # Tells what only the game knows of the player for the matchmaking: their map and tile, the live
  # battle, the multiplayer battle's rules, a PvP battle, a Library replay, the scene, the map's
  # event, a trade, the leader's call, a transfer or step under way, the co-op party, a late join and
  # its own troop, whether the story that calls the player over is the waiting invite's, whether
  # the player is in a battle, also under a screen its party command called, and whether they type
  # in the chat box.
  #
  # @return [Hash] The facts, see CoopRoomTopics.FactsOf.
  def self.facts
    sync = MGQ_MpBattlesSync
    kind = MGQ_MpBattles.kind
    hotjoin = MGQ_MpBattlesHotjoin
    { "map" => $game_map.map_id, "x" => $game_player.x, "y" => $game_player.y, "role" => sync.role && sync.role.to_s, "bid" => sync.battle_id && sync.battle_id.to_s,
      "seats" => Array(sync.seats), "coop" => sync.coop? ? true : false, "running" => MGQ_MpBattles.running? ? true : false, "kind" => kind && kind.to_s,
      "pvp" => defined?(MGQ_MpBattlesPvp) && MGQ_MpBattlesPvp::Battle.running? ? true : false, "memory" => $game_temp && $game_temp.in_memory_battle ? true : false,
      "battle_scene" => SceneManager.scene.is_a?(Scene_Battle), "interpreter" => $game_map.interpreter.running? ? true : false, "trading" => trading?,
      "coming" => defined?(MGQ_MpCoopGather) && MGQ_MpCoopGather.coming? ? true : false, "transfer" => $game_player.transfer? ? true : false,
      "moving" => $game_player.moving? ? true : false, "active" => active?, "late" => hotjoin.late? ? true : false, "own_troop" => hotjoin.own_troop? ? true : false,
      "story" => story_invite?, "in_battle" => in_battle_scene?, "typing" => defined?(MGQ_MpChat) && MGQ_MpChat.typing? ? true : false }
  end

  # Reports whether the invite that waits for the player belongs to the battle of the story that
  # calls them over (see MGQ_MpCoopGather.calling_battle?), which joining it answers.
  #
  # @return [Boolean] Whether it does.
  def self.story_invite?
    waiting = @waiting
    return false unless waiting && defined?(MGQ_MpCoopGather)

    peer = MGQ_MpOverworldSync::Peers.at(waiting["seat"])
    peer && MGQ_MpCoopGather.calling_battle?(peer, waiting["map"].to_i) ? true : false
  end

  # Hands the DLL the player's facts once they changed, so the co-op messages it takes in the frame
  # read them. Called before every frame's Graphics.update, so the frame's batch carries them before
  # the drain.
  def self.before_frame
    return unless $game_map && $game_player && MGQ_MpOverworldSync.in_world? && MGQ_Multiplayer::Bridge.has?(FRAME_TOPIC)

    told = facts
    return if told == @staged

    @staged = told
    MGQ_Multiplayer::Bridge.stage(FRAME_TOPIC, told)
  rescue => e
    log_once(:before_frame, "handing the DLL the player's co-op facts failed: #{e.class}: #{e.message}")
  end

  # Tells what the game knows of a battle it set up for the matchmaking: the troop, escape and
  # lose, how it came, the raid boss's pools, the enemies' rates and the invite's fields, who reads
  # the story told on the map, a member's battle the player leads, and the party members who stay
  # out of a battle with the player.
  #
  # @param troop_id [Integer] The troop.
  # @param can_escape [Boolean] Whether the party may escape.
  # @param can_lose [Boolean] Whether losing goes on without a game over.
  # @param encounter [Boolean] Whether the battle is a random encounter.
  # @return [Hash] The battle, see CoopRoomTopics.OfferOf.
  def self.offer_request(troop_id, can_escape, can_lose, encounter)
    boss = MGQ_MpRaidBosses.battle?(troop_id)
    fields = if raid? then defined?(MGQ_MpRaidPool) ? MGQ_MpRaidPool.invite_fields(troop_id) : {}
             else defined?(MGQ_MpRaidTiers) ? MGQ_MpRaidTiers.invite_fields(troop_id) : {}
             end
    { "facts" => facts, "troop" => troop_id.to_i, "escape" => can_escape ? true : false, "lose" => can_lose ? true : false,
      "encounter" => encounter ? true : false, "encountering" => @encountering ? true : false, "joining" => @joining ? true : false,
      "side" => side_battle?(troop_id), "pools_won" => pools_won?(troop_id), "boss" => boss, "rates" => rates,
      "invite_fields" => fields.map { |key, value| [key.to_s, value] }, "viewers" => raid? && boss ? MGQ_MpCoop::Scope.viewers.map(&:seat) : [],
      "leading" => @leading, "stays_out" => MGQ_MpBattlesHotjoin.stays_out_seats }
  end

  # Takes the steps the matchmaking asks for and keeps its status.
  #
  # @param answer [Hash, nil] The answer: "actions" and the status, nil while the DLL does not answer.
  # @param troop_id [Integer, nil] The troop of the battle the answer is about.
  # @param can_escape [Boolean, nil] Whether its party may escape.
  # @param can_lose [Boolean, nil] Whether losing it goes on without a game over.
  # @param encounter [Boolean, nil] Whether it is a random encounter.
  def self.act(answer, troop_id, can_escape, can_lose, encounter)
    return unless answer.is_a?(Hash)

    take_status(answer)
    Array(answer["actions"]).each do |action|
      case action["kind"]
      when "join" then begin_battle(action)
      when "ask_hot"
        return if MGQ_MpBattlesHotjoin.ask(troop_id, can_escape, can_lose)

        return offer(troop_id, can_escape, can_lose, encounter, true)
      when "fight_alone" then MGQ_MpBattlesHotjoin.fight_alone unless MGQ_MpBattlesSync.role
      when "start_held" then start_held(action)
      when "accept" then accept_invite(action)
      when "lead" then lead_request(action)
      when "follow" then follow(action)
      when "miss" then MGQ_MpBattlesSync.miss(action["label"].to_s)
      when "break_off" then MGQ_MpBattlesSync.break_off(action["label"].to_s, false)
      when "call_off_own" then MGQ_MpBattlesHotjoin.call_off_own(action["label"])
      end
    end
  end

  # Keeps the matchmaking's status, which the player's hold and state, the invite that waits and the
  # waits for the leader and a rival read.
  #
  # @param answer [Hash, nil] The answer or the coop.status event: "holding", "frozen", "busy",
  #   "waiting" (the invite that waits: "seat", "bid" and "map"), "rival", "asking", "requested",
  #   "waits", "ask" (the player asks a running battle), "ask_party" (first the party members) and
  #   "join_waits" (the player waits for the answer of a battle they asked to join).
  def self.take_status(answer)
    return unless answer.is_a?(Hash)

    @holding = answer["holding"] ? true : false
    @frozen = answer["frozen"] ? true : false
    @busy = answer["busy"] ? true : false
    @waiting = answer["waiting"].is_a?(Hash) ? answer["waiting"] : nil
    @rival_kept = answer["rival"] ? true : false
    @asking_leader = answer["asking"] ? true : false
    @requested = answer["requested"] ? true : false
    @waits = answer["waits"] && answer["waits"].to_s
    @asking_hot = answer["ask"] ? true : false
    @asking_party = answer["ask_party"] ? true : false
    @join_waits = answer["join_waits"] ? true : false
  end

  # Reports whether the player asks a running battle to take their encounter in, see
  # MGQ_MpBattlesHotjoin.ask.
  #
  # @return [Boolean] Whether they do.
  def self.asking_hot?
    @asking_hot ? true : false
  end

  # Reports whether the player asks their party members first whether they start a battle with the
  # player, see MGQ_MpBattlesHotjoin.await.
  #
  # @return [Boolean] Whether they do.
  def self.asking_party?
    @asking_party ? true : false
  end

  # Reports whether the player waits for the answer of a battle's host they asked to join, see
  # MGQ_MpBattlesJoin.asking?.
  #
  # @return [Boolean] Whether they do.
  def self.join_waits?
    @join_waits ? true : false
  end

  # Reports whether a battle's invite is open for the player, as the DLL's matchmaking last told:
  # an invite that waits for them, their request to join a battle, or their encounter asking a
  # running battle.
  #
  # @return [Boolean] Whether one is.
  def self.invite_open?
    !@waiting.nil? || @join_waits || @asking_hot ? true : false
  end

  # Forgets the matchmaking's status, as a reset or a closed bridge leaves none.
  def self.forget_status
    @holding = @frozen = @busy = @rival_kept = @asking_leader = @requested = @asking_hot = @asking_party = @join_waits = false
    @waiting = @waits = nil
  end

  # Makes the battle a live co-op battle the player hosts, with the multiplayer rules, noting the
  # member who asked the player to lead it, whose battle gather calls off should they not join.
  #
  # @param action [Hash] The matchmaking's step: "role", "bid", "seats" and "label".
  def self.begin_battle(action)
    @requester = @leading && @leading[0]
    MGQ_MpBattlesSync.join_world(action["role"].to_s.to_sym, action["bid"].to_s, Array(action["seats"]), action["label"].to_s)
    MGQ_MpBattlesSync.battle_started
    MGQ_MpBattles.begin(:coop)
  end

  # Starts the held encounter once its busy members came back or its wait ran out, inviting whoever
  # plays on the map then, and lets the players it held who are not invited walk on.
  #
  # @param action [Hash] The matchmaking's step: "troop", "escape", "lose" and the seats it froze.
  def self.start_held(action)
    offer(action["troop"], action["escape"], action["lose"], true)
    release(action["seats"])
    SceneManager.call(Scene_Battle)
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
    defined?(MGQ_MpRaidPool) && MGQ_MpRaidPool.respond_to?(:side_battle?) && MGQ_MpRaidPool.side_battle?(troop_id) ? true : false
  end

  # Makes up a battle's id, which its messages carry.
  #
  # @return [String] The id.
  def self.new_battle_id
    MGQ_MpCoop.random_id(8)
  end

  # As a member, waits at the battle's start for the party's leader the matchmaking asked to lead it
  # (see offer), the DLL counting the frames and taking the leader's answer. When the leader turns it
  # down, is gone or stays silent, the player hosts it instead. Called at the battle's start, before
  # its live side.
  #
  # @param scene [Scene_Battle] The battle.
  def self.await_leader(scene)
    return unless @asking_leader

    answer = MGQ_MpBattlesSync::Waiting.wait_for(scene, "Asking #{MGQ_MpBattlesSync.player} to lead the battle...") do
      MGQ_Multiplayer::Bridge.open? ? MGQ_Multiplayer::Bridge.call(LEADER_WAIT_TOPIC) : "silent"
    end
    @asking_leader = false
    hosted = MGQ_Multiplayer::Bridge.call(LEADER_END_TOPIC, answer.to_s)
    return unless hosted.is_a?(Hash)

    MGQ_MpBattlesSync.finish
    MGQ_MpBattles.finish
    host(hosted["troop"], hosted["escape"], hosted["lose"])
  rescue => e
    MGQ_Multiplayer::Bridge.call(LEADER_END_TOPIC, "failed") if @asking_leader
    @asking_leader = false
    MGQ_MpBattlesSync.finish
    MGQ_MpBattles.finish
    log("waiting for the leader failed: #{e.class}: #{e.message}")
  end

  # Lists the players a battle in a Raid World takes, as the DLL's matchmaking finds them (topic
  # coop.raid_candidates): of those on the player's map who are free and near, and for a boss battle
  # those reading the story the player tells there, the party members first, then the nearest.
  #
  # @param boss [Boolean] Whether it is a boss battle.
  # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The players.
  def self.raid_candidates(boss = false)
    viewers = boss ? MGQ_MpCoop::Scope.viewers.map(&:seat) : []
    seats = MGQ_Multiplayer::Bridge.call(CANDIDATES_TOPIC, "facts" => facts, "viewers" => viewers, "stays_out" => MGQ_MpBattlesHotjoin.stays_out_seats)
    Array(seats).map { |seat| MGQ_MpOverworldSync::Peers.at(seat) }.compact
  end

  # The fields the co-op battle adds to the state the player's game tells the others: in a Raid
  # World "busy", 1 while the player trades or is about to teleport, whose scene says "map" all the
  # same, as the matchmaking last told.
  #
  # @return [Hash] The fields, none in a Classic world.
  def self.state_fields
    raid? ? { "busy" => @busy ? true : false } : {}
  end

  # Reports whether the player takes part in a trade, through trade.rbx.
  #
  # @return [Boolean] Whether they do.
  def self.trading?
    defined?(MGQ_MpTrade) && MGQ_MpTrade.session ? true : false
  end

  # Stretches the steps the game drew to the next random encounter while another player who would
  # fight it stands near, as the DLL's matchmaking stretches them (topic coop.steps); a player with
  # nobody near keeps the game's draw.
  #
  # @param steps [Numeric] The steps the game drew.
  # @return [Numeric] The steps the player takes.
  def self.party_encounter_steps(steps)
    hundredths = (steps * 100).round
    answer = MGQ_Multiplayer::Bridge.call(STEPS_TOPIC, "facts" => facts, "steps" => hundredths)
    answer.is_a?(Integer) && answer != hundredths ? answer / 100.0 : steps
  rescue => e
    log("stretching the steps to the next random encounter failed: #{e.class}: #{e.message}")
    steps
  end

  # Runs the game's random encounter, which holds its battle while party members on the map are
  # busy (see offer). Called by Game_Player#encounter.
  #
  # @yieldreturn [Boolean] Whether the game's encounter starts a battle.
  # @return [Boolean] Whether the battle starts now.
  def self.encounter
    return false if holding?

    @encountering = true
    starts = yield
    starts && !holding?
  ensure
    @encountering = false
  end

  # Reports whether a random encounter waits for busy party members, while the player stands still,
  # as the matchmaking last told.
  #
  # @return [Boolean] Whether one does.
  def self.holding?
    @holding ? true : false
  end

  # Lets the players a held encounter in a Raid World made stand still walk on, those its battle
  # does not invite or bring along to a running battle (the DLL knows those a request brings along).
  #
  # @param seats [Array<Integer>, nil] The seats the hold froze, nil in a Classic world.
  def self.release(seats)
    request = { "facts" => facts, "seats" => Array(seats) }
    take_status(MGQ_Multiplayer::Bridge.call(RELEASE_TOPIC, request))
  end

  # Tells every party member that the player met enemies on their map, so the members there stand
  # still until the battle invites them; in a Raid World only the players the battle takes.
  #
  # @param seats [Array<Integer>, nil] The seats of the players a Raid World's battle takes, nil
  #   in a Classic world.
  def self.freeze_party(seats = nil)
    MGQ_Multiplayer::Bridge.call(FREEZE_PARTY_TOPIC, "facts" => facts, "seats" => Array(seats))
  end

  # Reports whether the player stands still for a party member's battle on their map, as the
  # matchmaking last told.
  #
  # @return [Boolean] Whether they do.
  def self.frozen?
    @frozen ? true : false
  end

  # Shows a message of the matchmaking in the notification box.
  #
  # @param notice [Hash] The message: "key", "seat", "text" and "frames".
  def self.notice(notice)
    MGQ_MpNotices.message(notice_key(notice), notice["text"].to_s, notice["frames"].to_i) if defined?(MGQ_MpNotices)
  end

  # Takes a message of the matchmaking out of the notification box.
  #
  # @param notice [Hash] The message's "key", "seat" and "reason", nil for the box's own.
  def self.drop_notice(notice)
    return unless defined?(MGQ_MpNotices)

    key = notice_key(notice)
    notice["reason"] ? MGQ_MpNotices.drop(key, notice["reason"].to_s) : MGQ_MpNotices.drop(key)
  end

  # Tells the notification box's key of a message of the matchmaking.
  #
  # @param notice [Hash] The message, its key's name under "key" and the seat it names under "seat".
  # @return [Symbol, Array] The key, such as :hold or [:soon, 2].
  def self.notice_key(notice)
    name = notice["key"].to_s.to_sym
    notice["seat"] ? [name, notice["seat"]] : name
  end

  # As host, waits for the invited members to join or turn the battle down, which the DLL takes from
  # the live battle's session (topic coop.gather), then sends everyone the party and the battle's
  # level and builds the party. Without anyone joining, the battle is the host's own. A rival's
  # battle in a Raid World ends the wait, and the player joins it instead (see yield_to_rival).
  # Called at the battle's start.
  #
  # @param scene [Scene_Battle] The battle.
  # @return [Symbol, nil] An ending of battles_sync's Channel.ending, :guest once the player became
  #   a rival's guest or the battle went to the battle server, nil once the battle may start.
  def self.gather(scene)
    return MGQ_MpBattlesServed.host_gather(scene) if defined?(MGQ_MpBattlesServed) && MGQ_MpBattlesServed.server?

    bridge = MGQ_Multiplayer::Bridge
    invited = Array(MGQ_MpBattlesSync.seats)
    bridge.call(GATHER_TOPIC, "op" => "start", "seats" => invited, "limit" => join_frames)
    answer = MGQ_MpBattlesSync::Waiting.wait_for(scene, raid? ? "Gathering the players..." : "Gathering the party...") do
      next :rival if @rival_kept

      gone = invited.select { |seat| MGQ_MpBattlesSync.peer_at(seat).nil? }
      MGQ_MpBattlesSync::Channel.poll
      !bridge.open? || bridge.call(GATHER_TOPIC, "op" => "frame", "gone" => gone) ? true : nil
    end
    ended = bridge.call(GATHER_TOPIC, "op" => "end") || {}
    joined = {}
    Array(ended["joined"]).each { |seat, body| joined[seat] = body }
    outcomes = {}
    Array(ended["outcomes"]).each { |seat, outcome| outcomes[seat] = outcome if outcome }
    frames = ended["frames"].to_i
    log("gathered battle #{MGQ_MpBattlesSync.battle_id} after #{frames} frames (#{answer.inspect}): " +
        invited.map { |seat| "#{MGQ_MpBattlesSync.who(seat)} #{outcomes[seat] || 'did not answer'}" }.join(", "))
    if answer == :rival
      return :guest if yield_to_rival(scene)

      answer = true
    end
    return answer if answer.is_a?(Symbol) && answer != :gone
    return call_off if @requester && !joined.key?(@requester)
    return stand_down if joined.empty? || answer == :gone

    MGQ_MpBattlesSync.keep_seats(joined.keys)
    players = [[MGQ_MpBattlesSync.own_seat, MGQ_Multiplayer::Player.name.to_s] + own_build]
    joined.keys.sort.each do |seat|
      builds, vitals, max = MGQ_MpBattlesSync::Wire.read(joined[seat])
      # A player who joined may have left the world since; their characters fight on all the same.
      peer = MGQ_MpBattlesSync.peer_at(seat)
      players << [seat, peer ? peer.state["name"].to_s : "?", builds.to_s, Array(vitals), max.is_a?(Integer) ? max : 0]
    end
    players = arrange(players)
    level = MGQ_MpCoopLevelSync.level_for(players)
    # The battle server hosts the battle where the relay has one; the player then plays it back.
    return :guest if defined?(MGQ_MpBattlesServed) && MGQ_MpBattlesServed.serve(scene, players, level)

    start_battle(scene, players, level)
    nil
  end

  # As host, starts a gathered battle: sends everyone the party and the battle's level, and builds
  # the party. Called by gather, and on the battle server once the players came.
  #
  # @param scene [Scene_Battle] The battle.
  # @param players [Array<Player>] The players, as arrange gives them.
  # @param level [Integer, nil] The battle's level, see MGQ_MpCoopLevelSync.level_for.
  def self.start_battle(scene, players, level)
    roster = MGQ_Multiplayer::Bridge.call(WRITE_ROSTER_TOPIC, "enemies" => troop_entries, "players" => players.map(&:to_a), "level" => level.to_i).to_s
    MGQ_MpBattlesSync::Channel.post("roster", roster)
    note_troop
    log("sent the roster of battle #{MGQ_MpBattlesSync.battle_id} (#{roster.size} bytes): #{$game_troop.members.size} enemies, #{players.size} players, level #{level.inspect}")
    MGQ_MpCoopLevelSync.begin(level)
    form(scene, players)
    log("battle #{MGQ_MpBattlesSync.battle_id} with #{players.size} players")
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

  # Tells the frames a player waits for the battle server's party: longer than the server waits for
  # the players to come onto the battle channel.
  #
  # @return [Integer] The frames.
  def self.served_roster_frames
    MGQ_MpBattlesServed::ARRIVE_FRAMES + ROSTER_MARGIN_FRAMES
  end

  # Gives the player's battle up for the rival's the matchmaking kept (topic coop.yield), which tells
  # the players it invited that it is off: takes the rival's troop and becomes the rival's guest.
  #
  # @param scene [Scene_Battle] The battle.
  # @return [Symbol, nil] :guest, after which the battle starts as the rival's guest; nil once no
  #   rival is kept any more.
  def self.yield_to_rival(scene)
    answer = MGQ_Multiplayer::Bridge.call(YIELD_TOPIC)
    take_status(answer)
    action = Array(answer.is_a?(Hash) ? answer["actions"] : nil).find { |taken| taken["kind"] == "yield" }
    return nil unless action

    message = action["fields"]
    MGQ_MpBattlesSync.finish
    adopt_troop(scene, message)
    MGQ_MpBattlesHotjoin.note_invite(message)
    take_pool(message)
    MGQ_MpBattlesSync.join_world(:guest, message["bid"].to_s, [action["seat"]], action["label"].to_s)
    MGQ_MpBattlesSync.battle_started
    :guest
  end

  # Moves the player from the battle whose party they waited for, which its host gave up, to the
  # battle of the invite the matchmaking kept: takes its troop and joins it as a guest, which join
  # then tells its host.
  #
  # @param action [Hash] The matchmaking's step: the host's "seat" and name ("label"), the invite
  #   under "fields".
  def self.follow(action)
    message = action["fields"]
    adopt_troop(SceneManager.scene, message)
    MGQ_MpBattlesHotjoin.note_invite(message)
    take_pool(message)
    MGQ_MpBattlesSync.join_world(:guest, message["bid"].to_s, [action["seat"]], action["label"].to_s)
    MGQ_MpBattlesSync.battle_started
    @moved = true
  end

  # Sets the rival's battle up in place of the player's own, as joining an invite does: its enemy
  # rates (see borrow_rates), its troop, started when the battle's start already ran (see
  # MGQ_MpBattlers.start_troop) and drawn anew, its chance to escape, and whether it allows
  # escaping and losing; no first strike or surprise.
  #
  # @param scene [Scene_Battle] The battle.
  # @param message [Hash] The rival's invite.
  def self.adopt_troop(scene, message)
    borrow_rates(message)
    $game_troop.setup(message["troop"].to_i)
    MGQ_MpBattlers.start_troop
    BattleManager.make_escape_ratio if BattleManager.respond_to?(:make_escape_ratio)
    MGQ_MpGame.set(BattleManager, :can_escape, message["escape"] ? true : false)
    MGQ_MpGame.set(BattleManager, :can_lose, message["lose"] ? true : false)
    MGQ_MpGame.set(BattleManager, :preemptive, false)
    MGQ_MpGame.set(BattleManager, :surprise, false)
    MGQ_MpBattlers.redraw(scene)
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

  # Takes a host's word that their battle is off, since the host joined a rival's battle, or that
  # their held encounter does not invite the player: the DLL's asking side forgets a party member's
  # offer and takes a host's word as its refusal (topic coop.ask_off), a player whose encounter the
  # player's battle took in is forgotten (see MGQ_MpBattlesHotjoin); the rest the matchmaking decides
  # (topic coop.take_off), which may have the player follow to another battle or break theirs off.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The host.
  # @param message [Hash] The message, the battle's id under "bid", none for a held encounter.
  def self.take_off(peer, message)
    fields = {}
    message.each { |key, value| fields[key] = value.to_s unless key.is_a?(Symbol) }
    return if MGQ_Multiplayer::Bridge.call(ASK_OFF_TOPIC, "facts" => facts, "seat" => peer.seat, "fields" => fields) == true
    return if MGQ_MpBattlesHotjoin.take_off(peer, message)

    act(MGQ_Multiplayer::Bridge.call(TAKE_OFF_TOPIC, "facts" => facts, "seat" => peer.seat, "fields" => fields), nil, nil, nil, nil)
  end

  # The guest's side.

  # Takes a co-op message the DLL's matchmaking leaves to the scripts (event coop.message), or one the
  # battle server's starter passed on: requests to join a running battle and a host's word that
  # their battle is off. The DLL takes invites, requests to lead, the leader's refusal, the
  # stand-stills, the answers to the player's requests and the party members' offers itself.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it.
  # @param message [Hash] The message's fields.
  def self.take(peer, message)
    # The starter of a served battle passes requests to join it on to the battle server.
    return MGQ_MpBattlesServed.forward(peer, message) if defined?(MGQ_MpBattlesServed) && MGQ_MpBattlesServed.fronts?(message)

    log("took #{message['coop']} from #{MGQ_MpOverworldSync.who(peer)}: #{fields_text(message.reject { |key, _| key == 'coop' })}")
    case message["coop"]
    when "off" then take_off(peer, message)
    when "hot" then MGQ_MpBattlesHotjoin.take_request(peer, message)
    when "pick" then MGQ_MpBattlesJoin.take_request(peer, message)
    end
  rescue => e
    log("taking a co-op message failed: #{e.class}: #{e.message}")
  end

  # Takes a co-op message the DLL's routes handed over (event coop.message).
  #
  # @param event [Hash] The event: the sender's "seat" and the message's "fields".
  def self.take_message(event)
    take(MGQ_MpOverworldSync::Peers.at(event["seat"]), event["fields"] || {})
  end

  # Reports whether an invite from a host to a battle waits for the player to be free, as the
  # matchmaking's status tells.
  #
  # @param seat [Integer] The host's seat.
  # @param bid [String] The battle's id.
  # @return [Boolean] Whether one does.
  def self.invited_by?(seat, bid)
    waiting = @waiting
    !waiting.nil? && waiting["seat"] == seat && waiting["bid"].to_s == bid.to_s
  end

  # Names the invite or request that waits for the player to be free on the map, as the
  # matchmaking's status tells, so the pages of a teller's story give way to it (see
  # MGQ_MpCoopEvents.give_way_to).
  #
  # @return [String, nil] What waits, nil while nothing does.
  def self.waiting_for_player
    @waits
  end

  # Tells the matchmaking of the frame on the map (topic coop.poll), which starts a held encounter or
  # lets the player walk on, leads a member's battle once the player is free on the map or refuses
  # it, and joins an invite once the player is free on the map or turns it down. Called by the map
  # every frame, so the battle starts as an encounter would.
  def self.on_map
    act(MGQ_Multiplayer::Bridge.call(POLL_TOPIC, "facts" => facts), nil, nil, nil, nil)
  rescue => e
    log("the map's co-op frame failed: #{e.class}: #{e.message}")
  end

  # Joins the invite the matchmaking accepted, answering the story that called the player over when
  # it is that story's battle.
  #
  # @param action [Hash] The matchmaking's step: the host's "seat", the invite under "fields" and
  #   "label" "story" for the story's battle.
  def self.accept_invite(action)
    message = action["fields"]
    peer = MGQ_MpOverworldSync::Peers.at(action["seat"])
    return log("could not join battle #{message['bid']}: its host left the world") unless peer

    MGQ_MpCoopGather.drop_call("the player joins the battle of the story that called them") if action["label"] == "story"
    accept(peer, message)
  rescue => e
    give_back_rates
    log("joining a co-op battle failed: #{e.class}: #{e.message}")
  end

  # Leads the member's battle the matchmaking took on.
  #
  # @param action [Hash] The matchmaking's step: the member's "seat" and the request under "fields".
  def self.lead_request(action)
    message = action["fields"]
    peer = MGQ_MpOverworldSync::Peers.at(action["seat"])
    return log("could not lead battle #{message['bid']}: the member left the world") unless peer

    lead(peer, message)
  rescue => e
    log("leading a member's battle failed: #{e.class}: #{e.message}")
  end

  # Starts a member's battle as its host, with the id the member chose; the member joins it.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @param message [Hash] The member's request.
  def self.lead(peer, message)
    @leading = [peer.seat, message["bid"].to_s]
    MGQ_MpRaidTiers.note_invite(message) if defined?(MGQ_MpRaidTiers)
    BattleManager.setup(message["troop"].to_i, message["escape"] ? true : false, message["lose"] ? true : false)
    return refuse_lead(peer, message, "the battle did not become a co-op battle the player hosts (#{MGQ_MpBattlesSync.role.inspect})") unless MGQ_MpBattlesSync.role == :host

    SceneManager.call(Scene_Battle)
    log("leads #{peer.state['name']}'s battle #{message['bid']} against troop #{message['troop']}")
  ensure
    @leading = nil
  end

  # Refuses to lead a member's battle, which the member then hosts (topic coop.refuse_lead).
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @param message [Hash] The member's request.
  # @param reason [String] Why, for the log.
  def self.refuse_lead(peer, message, reason = "?")
    MGQ_Multiplayer::Bridge.call(REFUSE_LEAD_TOPIC, "seat" => peer.seat, "bid" => message["bid"].to_s, "reason" => reason)
  end

  # Starts the invited battle as a guest, with the host's enemy rates (see borrow_rates).
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The host.
  # @param message [Hash] The invite.
  def self.accept(peer, message)
    # The leader's story dialogue a member reads may be on screen; the battle takes its place.
    $game_message.clear
    @joining = true
    MGQ_MpBattlesHotjoin.note_invite(message)
    MGQ_MpRaidTiers.note_invite(message) if defined?(MGQ_MpRaidTiers)
    borrow_rates(message)
    BattleManager.setup(message["troop"].to_i, message["escape"] ? true : false, message["lose"] ? true : false)
    MGQ_MpBattlesSync.join_world(:guest, message["bid"].to_s, [peer.seat], peer.state["name"].to_s)
    MGQ_MpBattlesServed.become_guest(message["bid"].to_s) if message["served"] && defined?(MGQ_MpBattlesServed)
    MGQ_MpBattlesSync.battle_started
    MGQ_MpBattles.begin(:coop)
    SceneManager.call(Scene_Battle)
    log("joined #{peer.state['name']}'s battle #{message['bid']} against troop #{message['troop']}")
  ensure
    @joining = false
  end

  # Tells the enemies' rates the player's game fights with, for the invites of a battle it hosts.
  #
  # @return [Array<Integer>] RATE_VARIABLES' values.
  def self.rates
    RATE_VARIABLES.map { |id| $game_variables[id].to_i }
  end

  # Fights the battle the player joins with its host's enemy rates, which an invite in a Raid World
  # carries, so its enemies are as strong in every game: those of a special boss, the Colosseum or
  # the host's Labyrinth of Chaos too, whatever the player's own difficulty. Keeps the player's own
  # until the battle ends (see restore); a second invite keeps the first's.
  #
  # @param message [Hash] The invite, "rates" with the host's rates.
  def self.borrow_rates(message)
    rates = message["rates"]
    return unless rates.is_a?(Array) && rates.size == RATE_VARIABLES.size && rates.all? { |rate| rate.is_a?(Integer) }

    @kept_rates ||= RATE_VARIABLES.map { |id| [id, $game_variables[id]] }
    RATE_VARIABLES.each_with_index { |id, index| $game_variables[id] = rates[index] }
    log("fights with the host's enemy rates #{rates.join(',')} instead of the player's own #{@kept_rates.map { |_, rate| rate }.join(',')}")
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

  # Turns the invite that waits down, so its host need not wait for the player (topic
  # coop.decline_waiting).
  #
  # @param reason [String] Why, for the log.
  def self.decline_waiting(reason)
    take_status(MGQ_Multiplayer::Bridge.call(DECLINE_WAITING_TOPIC, reason))
  end

  # As guest, tells the host who joins and builds the party the host sends, which the DLL takes from
  # the live battle's session (topic coop.roster_wait). Called at the battle's start. A player who
  # joins a running battle late (MGQ_MpBattlesHotjoin.late?) waits for its next command phase, and
  # takes its turn count; one whose encounter it took in fights that encounter alone when the roster
  # never comes (see own_ending?). A player who follows to another battle meanwhile (see follow)
  # joins that one, and one whose roster came turns a kept invite down.
  #
  # @param scene [Scene_Battle] The battle.
  # @return [Symbol, nil] An ending of battles_sync's Channel.ending, nil once the battle may start.
  def self.join(scene)
    hotjoin = MGQ_MpBattlesHotjoin
    served = defined?(MGQ_MpBattlesServed)
    limit = hotjoin.late? ? hotjoin::ROSTER_FRAMES : roster_frames
    if served && MGQ_MpBattlesServed.starter?
      # The starter's characters went to the battle server with the battle.
      limit = served_roster_frames
      log("waits up to #{limit / 60} s for the server's roster of battle #{MGQ_MpBattlesSync.battle_id}")
    else
      # The host's party says how many of them fight and how many wait on the Backline.
      build = own_build
      MGQ_MpBattlesSync::Channel.post("join", MGQ_MpBattlesSync::Wire.write(build))
      log("sent join for battle #{MGQ_MpBattlesSync.battle_id} with #{Array(build[1]).size} characters, party_member_max #{build[2]}, waiting up to #{limit / 60} s for the roster")
    end
    bridge = MGQ_Multiplayer::Bridge
    bridge.call(ROSTER_WAIT_TOPIC, "op" => "start", "limit" => limit)
    text = hotjoin.late? ? "Joining #{MGQ_MpBattlesSync.player}'s battle at its next turn..." : "Joining #{MGQ_MpBattlesSync.player}'s battle..."
    # A late join may last a whole turn, which the box's names line tells, since the text line
    # would clip with that note and the wait names nobody.
    limit_text = lambda { [Mod_Framework::UI::SECONDS_TEXT % (limit / Mod_Framework::UI::FRAMES_PER_SECOND)] }
    roster = MGQ_MpBattlesSync::Waiting.wait_for(scene, text, hotjoin.late? ? limit_text : nil, UP_TO_PREFIX) do
      next :called_off if hotjoin.called_off?
      next :moved if @moved

      # The host handed the battle to the battle server, whose roster comes over the battle channel.
      serve = served && !MGQ_MpBattlesSync.served? ? MGQ_MpBattlesSync::Channel.take("serve") : nil
      restart = nil
      if serve
        MGQ_MpBattlesServed.follow(serve)
        limit = restart = served_roster_frames
      end
      MGQ_MpBattlesSync::Channel.poll
      wait = bridge.open? ? bridge.call(ROSTER_WAIT_TOPIC, "op" => "frame", "restart" => restart) : { "late" => true }
      wait.is_a?(Hash) ? wait["roster"] || (wait["late"] ? :late : nil) : nil
    end
    if roster == :called_off
      text = hotjoin.take_off_text
      MGQ_MpBattlesSync::Departures.say(text) if text
      return hotjoin.fight_own("the host called it off")
    end
    if roster == :moved
      @moved = false
      return join(scene)
    end
    hotjoin.give_up(roster) if roster.is_a?(Symbol)
    return hotjoin.fight_own(roster == :late ? "the host's party never came" : "the host's battle ended before its party came (#{roster.inspect})") if own_ending?(roster)
    return left_out("the host's party never came") if roster == :late
    if roster.is_a?(Symbol)
      log("no roster for battle #{MGQ_MpBattlesSync.battle_id}: the wait ended with #{roster.inspect}")
      return never_got(roster)
    end

    read = read_roster(roster.to_s)
    players = Player.read_all(read["players"])
    level = read["level"]
    turn = read["turn"]
    log("took the roster of battle #{MGQ_MpBattlesSync.battle_id} (#{roster.to_s.size} bytes): #{read['size'].to_i} enemies, #{players.size} players, level #{level.inspect}#{", turn #{turn}" if turn}")
    decline_waiting("the player's battle #{MGQ_MpBattlesSync.battle_id} began") if @waiting
    return left_out("the host's party came without the player") unless players.any? { |player| player.seat == MGQ_MpBattlesSync.own_seat }

    MGQ_MpGame.set($game_troop, :turn_count, turn) if turn.is_a?(Integer)
    take_repaired(scene, repaired(read))
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
  # @param reason [String] Why, for the log.
  # @return [Symbol] :broken, which ends the battle.
  def self.left_out(reason)
    log("left out of battle #{MGQ_MpBattlesSync.battle_id}: #{reason}")
    MGQ_MpBattlesSync.miss(LEFT_OUT_TEXT % host_name)
    :broken
  end

  # Ends the wait of a guest whose battle ended before its roster came: the player goes back to the
  # map and is told, since they never got the battle. The starter of a battle the server never
  # started fights its own encounter as a battle of their own instead.
  #
  # @param ending [Symbol] How the wait ended, see MGQ_MpBattlesSync::Waiting.wait_for.
  # @return [Symbol] The ending the battle takes: :broken for a battle the player never got.
  def self.never_got(ending)
    return ending unless MISSED_ENDINGS.include?(ending)

    if defined?(MGQ_MpBattlesServed) && MGQ_MpBattlesServed.starter?
      log("the server never started battle #{MGQ_MpBattlesSync.battle_id}: the player fights their encounter as their own")
      return ending
    end
    MGQ_MpBattlesSync.miss(MGQ_MpBattlesSync.take_missed || MISSED_TEXT % host_name)
    :broken
  end

  # Names the host a guest waits for in what the player is told: the host's name, or the server.
  #
  # @return [String] The name.
  def self.host_name
    MGQ_MpBattlesSync.served? ? SERVER_NAME : MGQ_MpBattlesSync.player.to_s
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
    hotjoin.send_to(seats, "coop_troop", sync::Wire.write([hotjoin.late_entries, sync.names]))
    # Noted only once sent, so a send that failed is tried again before the next one.
    @shared_troop = current
    log("the troop of battle #{sync.battle_id} changed, now #{current.size} enemies (#{current.count { |_, _, hidden| hidden == 1 }} hidden)" +
        (seats.empty? ? ", no guest to tell" : ""))
  rescue => e
    log("telling the guests the troop failed: #{e.class}: #{e.message}")
  end

  # Repairs the enemies the host named, each at its place, as the rules in C# repair them (topic
  # coop.repair): a screen x or y that is no number becomes that of this game's enemy at the place,
  # else 0, and a mark that is no number 0, each logged once per field and kind.
  #
  # @param enemies [Array] The host's enemies, see troop_entries, as another game's line read.
  # @return [Array<Array>, nil] The enemies, or nil when one of them is no enemy this game has, no
  #   list or of an id that is no number, which keeps this game's own troop.
  def self.repaired_enemies(enemies)
    repaired(MGQ_Multiplayer::Bridge.call(REPAIR_TOPIC, troop_facts.merge("enemies" => plain_enemies(enemies))))
  end

  # Tells what the rules in C# compare the host's enemies with: this game's troop, each enemy's
  # screen x and y, and the size of its table of enemies.
  #
  # @return [Hash] "own" and "count".
  def self.troop_facts
    { "own" => $game_troop.members.map { |enemy| [enemy.screen_x.to_i, enemy.screen_y.to_i] }, "count" => $data_enemies.size }
  end

  # Writes the host's enemies as the rules in C# take them: each one's first four fields, a whole
  # number or the class name of a field of another kind, or the class name of one that is no list.
  #
  # @param enemies [Array] The enemies, as another game's line read.
  # @return [Array] The enemies.
  def self.plain_enemies(enemies)
    Array(enemies).map do |entry|
      next entry.class.name unless entry.is_a?(Array)

      Array.new(4) { |index| entry[index].is_a?(Integer) ? entry[index] : entry[index].class.name }
    end
  end

  # Takes the host's troop as the rules in C# repaired it, logging each field left out once per
  # field and kind, and the enemies this game lacks.
  #
  # @param answer [Hash, nil] The answer of coop.repair, coop.read_roster or coop.read_troop.
  # @return [Array<Array>, nil] The enemies, nil to keep this game's own troop.
  def self.repaired(answer)
    return nil unless answer

    Array(answer["enemy_dropped"]).each { |field, kind, owner| dropped_kind(field, kind, owner) }
    lacking = Array(answer["lacking"])
    log("the host's troop holds enemies this game lacks (#{lacking.join(', ')}); it keeps its own") unless lacking.empty?
    answer["enemies"]
  end

  # Reads the roster the host sent, its enemies repaired against this game's troop, logging each
  # of its players' fields left out once per field and kind.
  #
  # @param roster [String] The roster.
  # @return [Hash] The answer of coop.read_roster, empty while the DLL does not answer.
  def self.read_roster(roster)
    read = MGQ_Multiplayer::Bridge.call(READ_ROSTER_TOPIC, troop_facts.merge("line" => roster)) || {}
    Array(read["dropped"]).each { |field, kind, owner| dropped_kind(field, kind, owner) }
    read
  end

  # As guest, fights the host's enemies in place of the player's own, which mods of either game
  # may have changed, such as one that doubles them: the host names every enemy by its place.
  # Keeps the player's own when one of them is no enemy this game has (see repaired_enemies), and
  # moves them to the host's places when they are the host's enemies (see same_enemies?).
  #
  # @param scene [Scene_Battle] The battle.
  # @param enemies [Array<Array>] The host's enemies, see troop_entries.
  def self.take_troop(scene, enemies)
    take_repaired(scene, repaired_enemies(enemies))
  rescue => e
    log("taking the host's troop failed: #{e.class}: #{e.message}")
  end

  # Fights the host's enemies once repaired, see take_troop, built through MGQ_MpBattlers.
  #
  # @param scene [Scene_Battle] The battle.
  # @param enemies [Array<Array>, nil] The host's enemies, see repaired_enemies.
  def self.take_repaired(scene, enemies)
    return if enemies.nil? || enemies.empty?
    return keep_troop(enemies) if same_enemies?(enemies)

    rebuilt = MGQ_MpBattlers.fill_troop(scene, enemies)
    log("took the host's troop of #{rebuilt.size} enemies in place of this game's own: #{rebuilt.map { |enemy| "#{enemy.enemy_id} #{enemy.name}#{' (hidden)' if enemy.hidden?}#{' (fallen)' if enemy.dead?}" }.join(', ')}")
  rescue => e
    log("taking the host's troop failed: #{e.class}: #{e.message}")
  end

  # Reports whether the host's troop holds this game's enemies, each at its place and as shown or
  # hidden, where only the screen places may differ.
  #
  # The places differ wherever the game corrects a large picture's place by its size, which the
  # battle server, without pictures, never does.
  #
  # @param enemies [Array<Array>] The host's enemies, see repaired_enemies.
  # @return [Boolean] Whether the troops hold the same enemies.
  def self.same_enemies?(enemies)
    enemies.map { |id, _, _, mark| [id, mark] } == troop_entries.map { |id, _, _, hidden| [id, hidden] }
  end

  # Moves this game's own enemies to the host's places, see same_enemies?.
  #
  # @param enemies [Array<Array>] The host's enemies, see repaired_enemies.
  def self.keep_troop(enemies)
    $game_troop.members.zip(enemies) do |enemy, (_, x, y)|
      enemy.screen_x = x
      enemy.screen_y = y
    end
    log("the host's troop of #{enemies.size} enemies matches this game's own")
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
      front, bench = squad.share(0, FEWEST_PLAYERS, max)
      @own_squad = squad.own_order.first(front + bench)
      limit = "#{front} + #{bench}"
    end
    @allies = {}
    log("brings #{@own_squad.size} characters (up to #{limit} of party_member_max #{max}): #{squad_text}")
    [MGQ_MpActors::Builds.write(@own_squad), @own_squad.map { |actor| [actor.hp, actor.mp] }, max]
  end

  # Describes the player's characters a battle may take, for the log.
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
  # their squad by the world's rules, with the Frontline's places split between them, but always
  # their first character; a team duel's shares are split as in a Classic world. No player gets more
  # places than the characters they bring.
  #
  # @param players [Array<Player, Array>] The players, or their fields: at least each one's seat,
  #   name, builds, HP and MP and party_member_max.
  # @param backline [Boolean] Whether the players bring a share of the Backline, which a team duel's
  #   do not.
  # @return [Array<Player>] The players in the party's order, each with the order of their places
  #   and their shares of the Frontline and of the Backline; none while the DLL does not answer.
  def self.arrange(players, backline = true)
    players = Player.read_all(players)
    hosted = backline && raid?
    squad = MGQ_MpCoopSquad
    counts = players.map { |player| MGQ_MpActors::Builds.parse(player.builds.to_s, MOST_CHARACTERS).size }
    fields = players.each_with_index.map do |player, index|
      [player_id(player.seat), hosted ? player.seat == MGQ_MpBattlesSync.own_seat : leads?(player.seat), player.max.to_i, counts[index]]
    end
    request = { "rules" => raid? ? squad.rules_request(squad.rules) : nil, "raid" => squad.raid_fight? ? true : false, "backline" => backline ? true : false, "players" => fields }
    Array(MGQ_Multiplayer::Bridge.call(ARRANGE_TOPIC, request)).map do |index, front, bench|
      player = players[index]
      Player.new(player.seat, player.name, player.builds, player.vitals, player.max, valid_order(player.order, counts[index]), front, bench)
    end
  end

  # Tells a battle player's id, which orders the players as their party does.
  #
  # @param seat [Integer] The player's world seat.
  # @return [String] The id, empty when unknown.
  def self.player_id(seat)
    return MGQ_MpOverworldSync::Me.id if seat == MGQ_MpBattlesSync.own_seat

    peer = MGQ_MpBattlesSync.peer_at(seat)
    peer ? peer.state["id"].to_s : ""
  end

  # Reports whether a battle player leads the party.
  #
  # @param seat [Integer] The player's world seat.
  # @return [Boolean] Whether they do.
  def self.leads?(seat)
    player = seat == MGQ_MpBattlesSync.own_seat ? :me : MGQ_MpBattlesSync.peer_at(seat)
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
    dropped_kind(field, value.class.name, owner)
  end

  # Logs a field another game sent that is of the wrong kind once per field and kind, as the rules
  # in C# name it.
  #
  # @param field [Symbol, String] The field's name.
  # @param kind [String] The class it came as.
  # @param owner [String] Whose field it is, as the log names it.
  # @return [nil] Nothing, which stands for the field.
  def self.dropped_kind(field, kind, owner)
    log_once([:dropped, field.to_s, kind], "dropped #{owner} #{field} another game sent as #{kind}")
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
    Array(@players).find { |player| player.seat == MGQ_MpBattlesSync.own_seat }
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
      if player.seat == MGQ_MpBattlesSync.own_seat
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

  # Describes characters of a battle with their HP, for the log.
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

  # Rebuilds another player's character for the battle through MGQ_MpBattlers, checked before its
  # start, whose states its owner's game did not measure on the map.
  #
  # @param member [MGQ_MpActors::Builds::Member] The character's build.
  # @param name [String] Its owner's name.
  # @param seat [Integer] Its owner's world seat.
  # @param place [Integer] Its place among its owner's characters.
  # @param vitals [Array, nil] Its HP and MP, none for a character at full HP and MP.
  # @return [Game_MpAlly, nil] The character, nil when it could not be built.
  def self.new_ally(member, name, seat, place, vitals)
    ally = MGQ_MpBattlers.ally(member, name, seat, place, vitals) { |built| check(built) }
    log_rebuild(ally, member, place, vitals) if ally
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
  # which in a Raid World is their squad (see MGQ_MpCoopSquad.raid_battle?). On the battle server,
  # which has no characters of its own, the last player fights on there, and a battle every player
  # left ends. Called when a command phase starts.
  #
  # @param scene [Scene_Battle] The battle.
  def self.settle(scene)
    return unless active?

    served = defined?(MGQ_MpBattlesServed) && MGQ_MpBattlesServed.server? ? true : false
    decided = MGQ_Multiplayer::Bridge.call(SETTLE_TOPIC, "players" => player_seats, "own" => MGQ_MpBattlesSync.own_seat, "in" => MGQ_MpBattlesSync.guests_in,
                                                         "served" => served)
    return if decided.nil? || decided["outcome"] == "none"

    staying = @players.select { |player| decided["staying"].include?(player.seat) }
    log("#{(@players - staying).map { |player| "#{player.name} (seat #{player.seat})" }.join(', ')} left battle #{MGQ_MpBattlesSync.battle_id}, their characters leave the party")
    return abandon if decided["outcome"] == "abandon"
    return go_solo(scene) if decided["outcome"] == "solo"

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
    read = MGQ_Multiplayer::Bridge.call(READ_PARTY_TOPIC, body.to_s) || {}
    Array(read["dropped"]).each { |field, kind, owner| dropped_kind(field, kind, owner) }
    before = player_seats
    form(scene, Array(read["players"]))
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
    (seats - [MGQ_MpBattlesSync.own_seat]).each do |seat|
      peer = MGQ_MpBattlesSync.peer_at(seat)
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

  # As the battle server, ends a battle every player left, which nobody plays on.
  def self.abandon
    log("every player left battle #{MGQ_MpBattlesSync.battle_id}, the server ends it")
    BattleManager.process_abort
  end

  # As guest, fights on alone once the host got away or is gone: the player's own full team takes
  # the battle over from where the host's stream left it, as a battle of their own (in a Raid World
  # their squad).
  #
  # The guest's battle never ran the rest of the game's battle start, since the host's stream stood
  # in for it: one the host left before its party came starts now, without starting its party and
  # troop a second time; one it left later goes on from the battlers its start and MGQ_MpBattlers
  # made whole.
  #
  # @param scene [Scene_Battle] The battle.
  def self.take_over(scene)
    formed = active?
    log("the host left battle #{MGQ_MpBattlesSync.battle_id}, it goes on alone #{formed ? 'from where the stream left it' : 'from its start, the host party never came'}")
    stand_alone(scene)
    MGQ_MpRaidPool.taken_over if defined?(MGQ_MpRaidPool) && MGQ_MpRaidPool.respond_to?(:taken_over)
    if formed
      MGQ_MpBattlesSync::Live.pick_defeat_scene(false)
      BattleManager.turn_end
    else
      MGQ_MpBattlers.start_taken_over
      scene.process_event if scene.respond_to?(:process_event)
    end
    scene.start_party_command_selection
  rescue => e
    log("taking the battle over failed: #{e.class}: #{e.message}")
    BattleManager.process_abort
  end

  # Ends the co-op side of the battle, which goes on as the player's own: their own full team, the
  # game's own settings, no live battle; in a Raid World one that other players' encounters may join.
  #
  # @param scene [Scene_Battle] The battle.
  def self.stand_alone(scene)
    MGQ_MpBattlesHotjoin.call_off("the battle goes on alone", MGQ_MpBattlesHotjoin::OFF_CLOSED)
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
    held = [("the battle" if @members), ("the hold" if holding?), ("the request to the leader" if @asking_leader),
            ("an invite" if @waiting), ("a request to lead" if @requested)].compact
    log("forgot #{held.join(', ')} after a reset") unless held.empty?
    @result = nil
    MGQ_MpBattlesHotjoin.drop
    clear
    forget_status
    # The DLL forgets the held encounter, what waits for the player, and lets the player walk on.
    take_status(MGQ_Multiplayer::Bridge.call(DROP_TOPIC))
    @kept_rates = nil
  end

  # Forgets the co-op party, its players and their characters, the troop the guests know, and in the
  # DLL a rival's invite and the battle the player joined as a guest (topic coop.clear).
  def self.clear
    @seen = nil
    @shared_troop = nil
    @members = nil
    @players = nil
    @own_squad = nil
    @allies = {}
    @reordered = false
    @requester = nil
    @moved = false
    take_status(MGQ_Multiplayer::Bridge.call(CLEAR_TOPIC))
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
    own?(actor) ? MGQ_MpBattlesSync.own_seat : actor.mp_seat
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
    line = MGQ_Multiplayer::Bridge.call(WRITE_PARTY_TOPIC, @players.map(&:to_a)).to_s
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
    return unless defined?(DataManager) && DataManager.respond_to?(:extract_save_contents)

    MGQ_MpHooks.after(DataManager.singleton_class, :extract_save_contents, "battles_coop") { |_contents| MGQ_MpBattlesCoop.stand_up_loaded }
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

  # Stands the player's own fallen characters up with 1 HP when the co-op party won or left the
  # battle while all of them fell, as the game's defeat does. Called as BattleManager.battle_end ends.
  #
  # Without it the victory's autosave keeps a party without anyone standing, and the map's game over
  # check then sends the player to the plain Game Over screen on every load.
  #
  # @param result [Integer] The game's result: 0 won, 1 escaped, 2 lost.
  def self.stand_up(result)
    stand_up_all("in a battle the co-op party #{RESULTS.fetch(result, result.inspect)}") unless result == 2
  end

  # Stands the player's own characters up with 1 HP when a save loads in a world with all of them
  # fallen, as the autosave of a co-op battle won before stand_up existed kept them.
  def self.stand_up_loaded
    stand_up_all("in the save loaded") if MGQ_MpOverworldSync.in_world?
  end

  # Stands the player's own characters up with 1 HP when all of them fell.
  #
  # @param where [String] Where they fell, for the log.
  def self.stand_up_all(where)
    own = $game_party.all_members
    return if own.empty? || !own.all?(&:dead?)

    own.each { |actor| actor.hp = 1 }
    log("the player's own characters all fell #{where}: they stand up with 1 HP")
  rescue => e
    log("standing the player's fallen characters up failed: #{e.class}: #{e.message}")
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
  # character's battles, defeats and steals by its id: those belong to their owners' games. The
  # battle's end also stands the player's own fallen characters up, see stand_up.
  def self.install_counts
    if BattleManager.respond_to?(:battle_end)
      MGQ_MpHooks.around(BattleManager.singleton_class, :battle_end, "battles_coop") do |_manager, args, original|
        next original.call unless MGQ_MpBattlesCoop.active?

        MGQ_MpBattlesCoop.note_end(args[0])
        ended = MGQ_MpBattlesCoop.own_only { original.call }
        MGQ_MpBattlesCoop.stand_up(args[0])
        ended
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

  # Names each character in the battle's status window in its player's color while a co-op battle
  # runs, through the Mod Framework's row patch, see status_rows.
  def self.install_status_names
    Mod_Framework::UI.patch("Window_BattleStatus") { |status| status.rows { |rows| MGQ_MpBattlesCoop.status_rows(rows) } }
  rescue => e
    log("status names patch FAILED: #{e.class}: #{e.message}")
  end

  # Gives the rows of the battle's status window the looks of their characters' names while a
  # co-op battle runs, see status_look; outside one every row stays the game's.
  #
  # @param rows [Array<Hash>] The window's rows, each { index: } of a battle member.
  # @return [Array<Hash>] The rows with their looks.
  def self.status_rows(rows)
    return rows unless active?

    members = $game_party.battle_members
    rows.map { |row| members[row[:index]] ? row.merge(status_look(members[row[:index]])) : row }
  end

  # Tells the look of a character's name in the status window of a co-op battle: the player's own
  # in the player's own color, another player's by its own name, without its owner, in its owner's
  # MGQ_MpPlayerColor.
  #
  # The game colors a character in crisis or knocked out by hp_color (below a quarter of its max HP,
  # which covers 0), so such a name keeps the game's color.
  #
  # @param actor [Game_Actor] The character.
  # @return [Hash] :name for another player's character, :name_color unless in crisis.
  def self.status_look(actor)
    ally = actor.is_a?(Game_MpAlly)
    look = {}
    look[:name] = actor.base_name if ally
    look[:name_color] = MGQ_MpPlayerColor.role(ally ? (MGQ_MpBattlesSync.peer_at(actor.mp_seat) || actor.owner) : :me) if actor.hp >= actor.mhp / 4
    look
  end
end

# What a co-op battle does differently in a live battle, its scene's steps: every game's party is
# the host's, the party gathers before the start and re-forms when a player leaves or swaps, and a
# guest whose host got away fights on alone. That every guest stands on the host's side and the
# kinds of the battle's own messages in the stream are MGQ_MpBattles::Mode's, which the DLL answers.
module MGQ_MpBattlesCoop::Mode
  extend MGQ_MpBattles::Mode

  # (see MGQ_MpBattles::Mode#same_side?)
  def self.same_side?
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

# What this script takes part in of the party's co-op messages, which the DLL's routes take and
# hand over by the events coop.status and coop.message.

begin
  MGQ_MpOverworldSync.state_fields { MGQ_MpBattlesCoop.state_fields }
  MGQ_MpBattles.mode(:coop, MGQ_MpBattlesCoop::Mode)
  MGQ_Multiplayer::Bridge.on(MGQ_MpBattlesCoop::NOTICE_EVENT) { |notice| MGQ_MpBattlesCoop.notice(notice) }
  MGQ_Multiplayer::Bridge.on(MGQ_MpBattlesCoop::DROP_NOTICE_EVENT) { |notice| MGQ_MpBattlesCoop.drop_notice(notice) }
  MGQ_Multiplayer::Bridge.on(MGQ_MpBattlesCoop::STATUS_EVENT) { |status| MGQ_MpBattlesCoop.take_status(status) }
  MGQ_Multiplayer::Bridge.on(MGQ_MpBattlesCoop::MESSAGE_EVENT) { |event| MGQ_MpBattlesCoop.take_message(event) }
rescue => e
  MGQ_MpBattlesCoop.log("co-op FAILED: #{e.class}: #{e.message}")
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # Installs the hooks on methods the game's plugins may define anew, as the game starts running.
  MGQ_MpHooks.before(SceneManager.singleton_class, :run, "battles_coop") { MGQ_MpBattlesCoop.install }

  # After the map's update, joins a co-op battle the player was invited to.
  MGQ_MpHooks.after(Scene_Map, :update_scene, "battles_coop") { MGQ_MpBattlesCoop.on_map unless scene_changing? }

  # Before every frame, the DLL learns the player's facts the frame's co-op messages read.
  MGQ_MpHooks.before(Graphics.singleton_class, :update, "battles_coop") { MGQ_MpBattlesCoop.before_frame }
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
