#----------------------------------------------------------------
#  mp_battles_coop.rbx
#
#  Changelog:
#      Paulinchen  2026-10-02: Started a co-op battle when a player who joined it left the world before the roster went out
#                            - Followed the map and installed the late hooks through mp_hooks.rbx
#                            - Turned an invite down through MGQ_MpBattlesSync.tell, and took the seat, place and Luka from Game_MpActor
#                            - Turned a co-op battle down while the leader's story scene is about to bring the player over
#      Paulinchen  2026-10-01: Listed the battle's players, so each hears at once when another leaves
#                            - Rebuilt the host's enemies on a guest whose troop differs, such as through a mod of either game
#                            - Brought each player's squad, a share of the Frontline and of the Backline, the leader's first
#                            - Let each player swap their own Backline in, telling every game the party's new order
#                            - Found the leader of any party among the battle's players, for the sides of a team duel
#                            - Let a player of a team duel command the characters of a player who left their side
#      Paulinchen  2026-09-30: Sent and took the party's messages through mp_coop.rbx, which drops those of another party
#                            - Registered with mp_overworld_sync.rbx for its messages instead of being asked by mp_overworld.rbx
#                            - Moved into Patch/Multiplayer/Scripts as mp_battles_coop.rbx, which Multiplayer.rb loads
#                            - Renamed from mp_coop.rb, with the module MGQ_MpBattlesCoop
#                            - Let a player who got away leave the battle, the others fighting on, alone with their own full team
#                            - Showed the co-op party in the game's window per character too
#                            - Invited party members whose window is in the background, and logged why nobody was invited
#                            - Created
#
#----------------------------------------------------------------

# Co-op battles: when a party member's game starts a battle, the party members on the same map who
# are playing on the map join it. The game that started it computes it (the host); the others play
# it back and command their own characters, through mp_battles_sync.rbx over the world's room. The
# party is every player's squad together (see mp_coop_squad.rbx): each brings their share of the
# Frontline, the party's leader first, and may swap their share of the Backline in. A player who
# gets away leaves the battle; the others fight on with larger shares, and one left alone fights on
# with their own full team, as in a battle of their own. Every game ends the battle with its own
# rewards or its own defeat.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpBattlesCoop
  # Frames the host waits for the invited members to join, six seconds.
  JOIN_FRAMES = 360

  # Frames an invite waits for the player to be free before it is turned down, three seconds.
  ACCEPT_FRAMES = 180

  # What another player does, by their state's scene, while they may be invited: walking the map,
  # reading an event's messages, such as the leader's story, or on the map with their window in the
  # background, which keeps running.
  FREE_SCENES = %w(map event away)

  # Players the characters a player sends are counted for: two, the fewest who share a battle,
  # whose squads are the largest, so a party that loses a player can bring more.
  FEWEST_PLAYERS = 2

  # Characters a player's builds hold at most, the game's largest party.
  MOST_CHARACTERS = 14

  @members = nil
  @players = nil
  @allies = {}

  # Reports whether the hooks can be installed.
  #
  # A second copy of this script would wrap the same methods under the same names, and each hook
  # would then call itself until the stack overflows.
  #
  # @return [Boolean] false when the hooks are in place already.
  def self.hookable?
    !BattleManager.respond_to?(:mgq_mp_battles_coop_setup)
  end

  # Writes a line to the mod's InGame.log.
  #
  # @param message [String] The line.
  def self.log(message)
    MGQ_Multiplayer::Log.write("co-op battle: #{message}")
  rescue
  end

  # The party of the co-op battle running: every player's characters in the order every game shares.
  #
  # @return [Array<Game_Actor>, nil] The party, nil outside a co-op battle.
  def self.members
    @members
  end

  # Reports whether a co-op battle's party stands in for the player's.
  #
  # @return [Boolean] Whether one does.
  def self.active?
    !@members.nil?
  end

  # The player's own world seat.
  #
  # @return [Integer] The seat, -1 while the game holds none.
  def self.own_seat
    seat = MGQ_MpOverworldSync::Link.status["seat"]
    seat.to_s.empty? ? -1 : seat.to_i
  end

  # Sends a co-op message to one game or to everyone, who ignore it outside the party.
  #
  # @param seat [Integer] The game's seat, -1 for everyone.
  # @param kind [String] What it is.
  # @param fields [Hash] Its other fields.
  # @return [Boolean] Whether it went out.
  def self.tell(seat, kind, fields)
    MGQ_MpCoop.tell(seat, "coop", kind, fields)
  end

  # The host's side.

  # Makes a battle the game just set up a co-op battle, inviting the party members on the map who
  # are playing on it. Called after BattleManager.setup.
  #
  # @param troop_id [Integer] The troop.
  # @param can_escape [Boolean] Whether the party may escape.
  # @param can_lose [Boolean] Whether losing goes on without a game over.
  def self.offer(troop_id, can_escape, can_lose)
    return if @joining || !host_possible?

    seats = candidates.map(&:seat)
    if seats.empty?
      others = MGQ_MpCoop::Party.members.map { |peer| "#{peer.state['name']} on map #{peer.state['map']} (#{peer.state['scene']})" }
      return log("nobody to invite on map #{$game_map.map_id}: #{others.empty? ? 'no other party member' : others.join(', ')}")
    end

    battle_id = rand(36**8).to_s(36)
    MGQ_MpBattlesSync.join_world(:host, battle_id, seats, "the party")
    MGQ_MpBattlesSync.battle_started
    MGQ_MpBattles.begin(:coop)
    tell(-1, "invite", "bid" => battle_id, "troop" => troop_id, "escape" => can_escape ? 1 : 0, "lose" => can_lose ? 1 : 0,
                       "seats" => seats.join(","), "map" => $game_map.map_id)
    log("invited #{seats.size} member(s) to battle #{battle_id} against troop #{troop_id}")
  rescue => e
    log("could not offer a co-op battle: #{e.class}: #{e.message}")
  end

  # Reports whether a battle starting now may become a co-op battle: in a party of an open world,
  # and no other multiplayer battle or Library replay running.
  #
  # @return [Boolean] Whether it may.
  def self.host_possible?
    return false unless defined?(MGQ_MpOverworldSync) && MGQ_MpOverworldSync.in_world? && defined?(MGQ_MpCoop) && MGQ_MpCoop::Party.id
    return false if $game_temp && $game_temp.in_memory_battle
    return false if defined?(MGQ_MpBattlesPvp) && MGQ_MpBattlesPvp::Battle.running?

    busy = MGQ_MpBattlesSync.role || MGQ_MpBattles.running?
    log("no co-op battle: another multiplayer battle still runs (#{MGQ_MpBattlesSync.role.inspect}, #{MGQ_MpBattles.kind.inspect})") if busy
    !busy
  end

  # Lists the party members who may join: on the player's map, playing on it.
  #
  # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The members.
  def self.candidates
    MGQ_MpCoop::Party.members.select { |peer| peer.state["map"].to_i == $game_map.map_id && FREE_SCENES.include?(peer.state["scene"]) }
  end

  # As host, waits for the invited members to join or turn the battle down, then sends everyone the
  # party and builds it. Without anyone joining, the battle is the host's own. Called at the battle's start.
  #
  # @param scene [Scene_Battle] The battle.
  # @return [Symbol, nil] An ending of mp_battles_sync's Channel.ending, nil once the battle may start.
  def self.gather(scene)
    channel = MGQ_MpBattlesSync::Channel
    invited = MGQ_MpBattlesSync.seats
    joined = {}
    answered = []
    frames = 0
    answer = MGQ_MpBattlesSync::Waiting.wait_for(scene, "Gathering the party...") do
      invited.each do |seat|
        next if answered.include?(seat)

        body = channel.take_from("join", seat)
        joined[seat] = body if body
        answered << seat if body || channel.take_from("decline", seat) || MGQ_MpOverworldSync::Peers.at(seat).nil?
      end
      frames += 1
      answered.size == invited.size || frames >= JOIN_FRAMES ? true : nil
    end
    return answer if answer.is_a?(Symbol) && answer != :gone
    return stand_down if joined.empty? || answer == :gone

    MGQ_MpBattlesSync.keep_seats(joined.keys)
    players = [[own_seat, MGQ_Multiplayer::Player.name.to_s] + own_build]
    joined.keys.sort.each do |seat|
      builds, vitals, max = MGQ_MpBattlesSync::Wire.parse(joined[seat].to_s)
      # A player who joined may have left the world since; their characters fight on all the same.
      peer = MGQ_MpOverworldSync::Peers.at(seat)
      players << [seat, peer ? peer.state["name"].to_s : "?", builds.to_s, Array(vitals), max.to_i]
    end
    players = arrange(players)
    channel.post("roster", MGQ_MpBattlesSync::Wire.line([troop_entries, players]))
    form(scene, players)
    log("battle #{MGQ_MpBattlesSync.battle_id} with #{players.size} players")
    nil
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

  # Takes a co-op message. Called by mp_coop.rbx.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it.
  # @param message [Hash] The message's fields.
  def self.take(peer, message)
    return unless message["coop"] == "invite"
    return unless message["seats"].to_s.split(",").map(&:to_i).include?(own_seat)

    @invite = { :peer => peer, :message => message, :frames => 0 }
  rescue => e
    log("taking an invite failed: #{e.class}: #{e.message}")
  end

  # Joins an invite once the player is free on the map, or turns it down when they stay busy.
  # Called by the map every frame, so the battle starts as an encounter would.
  def self.on_map
    return unless @invite

    invite = @invite
    peer = invite[:peer]
    message = invite[:message]
    invite[:frames] += 1
    return decline(peer, message) unless message["map"].to_i == $game_map.map_id && MGQ_MpBattlesSync.role.nil?
    return decline(peer, message) if invite[:frames] > ACCEPT_FRAMES || (defined?(MGQ_MpCoopEvents) && MGQ_MpCoopEvents.coming?)
    return unless free?

    @invite = nil
    accept(peer, message)
  rescue => e
    @invite = nil
    log("joining a co-op battle failed: #{e.class}: #{e.message}")
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
    # The leader's story dialogue a member reads may be on screen; the battle takes its place.
    $game_message.clear
    @joining = true
    BattleManager.setup(message["troop"].to_i, message["escape"] == "1", message["lose"] == "1")
    @joining = false
    MGQ_MpBattlesSync.join_world(:guest, message["bid"].to_s, [peer.seat], peer.state["name"].to_s)
    MGQ_MpBattlesSync.battle_started
    MGQ_MpBattles.begin(:coop)
    SceneManager.call(Scene_Battle)
    log("joined #{peer.state['name']}'s battle #{message['bid']}")
  ensure
    @joining = false
  end

  # Turns an invite down, so the host need not wait for the player.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The host.
  # @param message [Hash] The invite.
  def self.decline(peer, message)
    @invite = nil
    MGQ_MpBattlesSync.tell(peer.seat, "decline", message["bid"].to_s)
  end

  # As guest, tells the host who joins and builds the party the host sends. Called at the battle's start.
  #
  # @param scene [Scene_Battle] The battle.
  # @return [Symbol, nil] An ending of mp_battles_sync's Channel.ending, nil once the battle may start.
  def self.join(scene)
    # The host's party says how many of them fight and how many wait on the Backline.
    MGQ_MpBattlesSync::Channel.post("join", MGQ_MpBattlesSync::Wire.line(own_build))
    roster = MGQ_MpBattlesSync::Waiting.wait_for(scene, "Joining #{MGQ_MpBattlesSync.player}'s battle...") { MGQ_MpBattlesSync::Channel.take("roster") }
    return roster if roster.is_a?(Symbol)

    enemies, players = MGQ_MpBattlesSync::Wire.parse(roster.to_s)
    take_troop(scene, Array(enemies))
    form(scene, Array(players))
    nil
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
    return if enemies.empty? || enemies == troop_entries
    unless enemies.all? { |id, *| $data_enemies[id.to_i] }
      return log("the host's troop holds enemies this game lacks; it keeps its own")
    end

    rebuilt = enemies.each_with_index.map do |(id, x, y, hidden), index|
      enemy = Game_Enemy.new(index, id.to_i)
      enemy.screen_x = x.to_i
      enemy.screen_y = y.to_i
      enemy.hide if hidden.to_i == 1
      enemy
    end
    $game_troop.instance_variable_set(:@enemies, rebuilt)
    # The game counts each name's enemies for their letters, so the count starts over as in setup.
    $game_troop.instance_variable_set(:@names_count, {})
    $game_troop.send(:make_unique_names)
    spriteset = scene.instance_variable_get(:@spriteset)
    if spriteset
      spriteset.dispose_enemies
      spriteset.create_enemies
    end
    log("took the host's troop of #{rebuilt.size} enemies in place of this game's own")
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
    [MGQ_MpActors::Builds.write(@own_squad), @own_squad.map { |actor| [actor.hp, actor.mp] }, max]
  end

  # Writes the player's Frontline for a team duel, whose places its characters count, and starts the
  # duel's party anew.
  #
  # @return [Array] The builds, see MGQ_MpActors::Builds, and the player's party_member_max.
  def self.team_build
    @own_squad = MGQ_MpCoopSquad.own_order.first(MGQ_MpCoopSquad::FRONTLINE)
    @allies = {}
    [MGQ_MpActors::Builds.write(@own_squad), $game_party.party_member_max]
  end

  # Orders the battle's players as their party does, the leader first, and tells each player's
  # share of the Frontline and of the Backline in the battle, and the order of their places.
  #
  # @param players [Array<Array>] Each player's seat, name, builds, HP and MP, party_member_max,
  #   and the order of their places once they have one.
  # @return [Array<Array>] Each player's seat, name, builds, HP and MP, party_member_max, the
  #   order of their places, the Frontline's first, and their shares of the Frontline and of the Backline.
  def self.arrange(players)
    ranked = MGQ_MpCoopSquad.ranked(players.map { |seat, *| [player_id(seat), leads?(seat)] })
    players = players.sort_by { |seat, *| ranked.index(player_id(seat)) }
    players.each_with_index.map do |(seat, name, builds, vitals, max, order), position|
      count = MGQ_MpActors::Builds.parse(builds.to_s, MOST_CHARACTERS).size
      front, bench = MGQ_MpCoopSquad.share(position, players.size, max.to_i)
      front = [front, count].min
      [seat, name, builds, vitals, max, valid_order(order, count), front, [bench, count - front].min]
    end
  end

  # Tells a battle player's id, which orders the players as their party does.
  #
  # @param seat [Integer] The player's world seat.
  # @return [String] The id, empty when unknown.
  def self.player_id(seat)
    return MGQ_MpOverworldSync::Me.identity[0].to_s if seat == own_seat

    peer = MGQ_MpOverworldSync::Peers.at(seat)
    peer ? peer.state["id"].to_s : ""
  end

  # Reports whether a battle player leads the party.
  #
  # @param seat [Integer] The player's world seat.
  # @return [Boolean] Whether they do.
  def self.leads?(seat)
    player = seat == own_seat ? :me : MGQ_MpOverworldSync::Peers.at(seat)
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

  # Lists a player's places on the battle's Frontline and on its Backline.
  #
  # @param player [Array] The player, see arrange.
  # @return [Array<Array<Integer>>] The Frontline's places and the Backline's.
  def self.lines_of(player)
    order, front, bench = Array(player[5]), player[6].to_i, player[7].to_i
    [order.first(front), order[front, bench] || []]
  end

  # Lists the world seats of the battle's players.
  #
  # @return [Array<Integer>] The seats, the player's own included; none before the party is formed.
  def self.player_seats
    Array(@players).map { |seat, *| seat }
  end

  # Finds the player's own entry among the battle's players.
  #
  # @return [Array, nil] The entry, see arrange, nil outside a co-op battle.
  def self.own_player
    Array(@players).find { |seat, *| seat == own_seat }
  end

  # Lists the player's own characters on the battle's Backline, those they may swap in.
  #
  # @return [Array<Game_Actor>] The characters.
  def self.own_bench
    player = own_player
    player && @own_squad ? lines_of(player)[1].map { |place| @own_squad[place] }.compact : []
  end

  # The order of the player's places, which their commands tell the host.
  #
  # @return [Array<Integer>, nil] The places, the Frontline's first, nil outside a co-op battle.
  def self.own_order
    player = own_player
    player && player[5]
  end

  # Builds the co-op party every game shares, in the host's order: each player's share of the
  # Frontline, the player's own characters as they are, everyone else's rebuilt with their HP and
  # MP. Others' characters the battle had before stay as they are, with what the battle did to them.
  #
  # @param scene [Scene_Battle] The battle.
  # @param players [Array<Array>] Each player, see arrange.
  def self.form(scene, players)
    @players = players
    @own_squad ||= MGQ_MpCoopSquad.own_order
    members = []
    players.each do |player|
      seat, name, builds, vitals = player
      front = lines_of(player)[0]
      if seat == own_seat
        members.concat(front.map { |place| @own_squad[place] }.compact)
      else
        members.concat(front.map { |place| ally(seat, name, builds, vitals, place) }.compact)
      end
    end
    @members = members
    show_party(scene, members)
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

  # Rebuilds another player's character with the HP and MP it has in their game.
  #
  # @param member [MGQ_MpActors::Builds::Member] The character's build.
  # @param name [String] Its owner's name.
  # @param seat [Integer] Its owner's world seat.
  # @param place [Integer] Its place among its owner's characters.
  # @param vitals [Array, nil] Its HP and MP.
  # @return [Game_MpAlly] The character.
  def self.new_ally(member, name, seat, place, vitals)
    ally = Game_MpAlly.new(member, name, seat, place)
    hp, mp = Array(vitals)
    ally.hp = hp if hp.is_a?(Integer) && hp > 0
    ally.mp = mp if mp.is_a?(Integer)
    ally
  end

  # Shows a party in the battle's windows, which the scene made for the player's own party: the
  # status window, and the game's window per character, which takes its character only when made.
  #
  # @param scene [Scene_Battle] The battle.
  # @param members [Array<Game_Actor>] The party.
  def self.show_party(scene, members)
    Array(scene.instance_variable_get(:@battle_actor_status_windows)).each_with_index { |window, index| window.actor = members[index] }
    scene.send(:refresh_status) if scene.respond_to?(:refresh_status, true)
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

    staying = @players.select { |seat, *| seat == own_seat || MGQ_MpBattlesSync.guests_in.include?(seat) }
    return if staying.size == @players.size

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
  # @param scene [Scene_Battle] The battle.
  def self.take_over(scene)
    log("the host left battle #{MGQ_MpBattlesSync.battle_id}, it goes on alone")
    stand_alone(scene)
    BattleManager.turn_end
    scene.start_party_command_selection
  rescue => e
    log("taking the battle over failed: #{e.class}: #{e.message}")
    BattleManager.process_abort
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
  end

  # Ends a co-op battle: the player's own party again, the game's own settings back, and the live
  # battle over. Called once the battle's scene ended.
  def self.ended
    return unless active? || (MGQ_MpBattlesSync.role && MGQ_MpBattlesSync.coop?) || MGQ_MpBattles.kind == :coop

    forget
    MGQ_MpBattlesSync.finish if MGQ_MpBattlesSync.coop?
    MGQ_MpBattles.finish if MGQ_MpBattles.kind == :coop
  rescue => e
    @members = nil
    log("ending a co-op battle failed: #{e.class}: #{e.message}")
  end

  # Forgets the co-op party, its players and their characters.
  def self.forget
    @members = nil
    @players = nil
    @own_squad = nil
    @allies = {}
    @reordered = false
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

    order = player[5]
    front = player[6].to_i
    at = order.first(front).index { |place| @own_squad[place].equal?(actor) }
    to = front + bench_index
    return false unless at && bench_index >= 0 && bench_index < player[7].to_i && order[to]

    party = $game_party.all_members
    first = party.index(@own_squad[order[at]])
    second = party.index(@own_squad[order[to]])
    $game_party.swap_order(first, second) if first && second
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
    player = Array(@players).find { |player_seat, *| player_seat == seat }
    return unless player && order.is_a?(Array) && order != player[5]

    player[5] = valid_order(order, player[5].size)
    @reordered = true
    form(SceneManager.scene, @players)
  rescue => e
    log("taking a new order failed: #{e.class}: #{e.message}")
  end

  # As host, tells the guests the party once a player swapped, before the turn's events, so every
  # game plays the turn with the same characters. Called once every guest's commands came.
  def self.share_order
    post_party if active? && @reordered
  rescue => e
    log("telling the new order failed: #{e.class}: #{e.message}")
  end

  # As host, sends the guests the party, between two of the host's sends.
  def self.post_party
    MGQ_MpBattlesSync::Recorder.flush if MGQ_MpBattlesSync::Recorder.active?
    MGQ_MpBattlesSync::Channel.post("coop_party", MGQ_MpBattlesSync::Wire.line([@players]))
    @reordered = false
  end

  # Reports whether a character of the party is the player's own, whom only they may swap.
  #
  # @param actor [Game_Actor, nil] The character.
  # @return [Boolean] Whether it is.
  def self.own?(actor)
    !actor.nil? && !actor.is_a?(Game_MpActor)
  end

  # Reports whether a swap would leave the party with nobody standing, as the game forbids.
  #
  # @param actor [Game_Actor, nil] The character on the Frontline.
  # @param bench [Game_Actor, nil] The character on the Backline.
  # @return [Boolean] Whether it would.
  def self.swap_kills_all?(actor, bench)
    return false unless actor && bench
    return false if @members.reject(&:all_dead?).size != 1

    !actor.all_dead? && bench.all_dead?
  end

  # Installs the hooks on methods the game's plugins may define anew. Called once the first scene starts.
  def self.install
    return if @installed

    @installed = true
    install_party
    install_shift_change
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

# Another player's character in a co-op battle's party. Its owner commands it from their own game;
# the computer plays it when no command came, as after its owner left.
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

  # Makes the turn's actions with the game's own auto-battle, which the owner's commands replace.
  def make_actions
    super
    make_auto_battle_actions unless @actions.empty? || inputable?
  end
end

# What this script takes part in of the party's messages, through mp_coop.rbx.

begin
  MGQ_MpCoop.route("coop") { |peer, message| MGQ_MpBattlesCoop.take(peer, message) }
rescue => e
  MGQ_MpBattlesCoop.log("co-op FAILED: #{e.class}: #{e.message}")
end

# Game hooks shared with other scripts, through mp_hooks.rbx.

begin
  # Installs the hooks on methods the game's plugins may define anew, as the game starts running.
  MGQ_MpHooks.before(SceneManager.singleton_class, :run, "mp_battles_coop") { MGQ_MpBattlesCoop.install }

  # After the map's update, joins a co-op battle the player was invited to.
  MGQ_MpHooks.after(Scene_Map, :update_scene, "mp_battles_coop") { MGQ_MpBattlesCoop.on_map unless scene_changing? }
rescue => e
  MGQ_MpBattlesCoop.log("hooks FAILED: #{e.class}: #{e.message}")
end

# Game hooks of this script alone.
#
# Each wraps a game method: the original runs first unless said otherwise, and the mod's part never
# raises.

if MGQ_MpBattlesCoop.hookable?
  begin
    class << BattleManager
      alias mgq_mp_battles_coop_setup setup

      # Sets up a battle, then makes it a co-op battle where the party can join.
      #
      # @param troop_id [Integer] The troop.
      # @param can_escape [Boolean] Whether the party may escape.
      # @param can_lose [Boolean] Whether losing goes on without a game over.
      def setup(troop_id, can_escape = true, can_lose = false)
        mgq_mp_battles_coop_setup(troop_id, can_escape, can_lose)
        MGQ_MpBattlesCoop.offer(troop_id, can_escape, can_lose)
      end
    end
  rescue => e
    MGQ_MpBattlesCoop.log("battle setup hook FAILED: #{e.class}: #{e.message}")
  end

  begin
    class Scene_Battle
      alias mgq_mp_battles_coop_terminate terminate

      # Ends the battle's scene, then a co-op battle.
      def terminate
        mgq_mp_battles_coop_terminate
        MGQ_MpBattlesCoop.ended
      end
    end
  rescue => e
    MGQ_MpBattlesCoop.log("battle end hook FAILED: #{e.class}: #{e.message}")
  end
end
