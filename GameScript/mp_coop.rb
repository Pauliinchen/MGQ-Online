#----------------------------------------------------------------
#  mp_coop.rb
#
#  Changelog:
#      Paulinchen  2026-09-30: Showed the co-op party in the game's window per character too
#                            - Invited party members whose window is in the background, and logged why nobody was invited
#                            - Created
#
#----------------------------------------------------------------

# Co-op battles: when a party member's game starts a battle, the party members on the same map who
# are playing on the map join it. The game that started it computes it (the host); the others play
# it back and command their own characters, through mp_sync.rb over the world's room. The party is
# every player's characters together: with two players each brings the first two of their
# Frontline, with three or four each brings their first. Every game ends the battle with its own
# rewards or its own defeat.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpCoop
  # Frames the host waits for the invited members to join, six seconds.
  JOIN_FRAMES = 360

  # Frames an invite waits for the player to be free before it is turned down, three seconds.
  ACCEPT_FRAMES = 180

  # What another player does, by their state's scene, while they may be invited: walking the map,
  # reading an event's messages, such as the leader's story, or on the map with their window in the
  # background, which keeps running.
  FREE_SCENES = %w(map event away)

  # Characters each player brings with two players; with more, each brings one.
  PAIR_SHARE = 2

  @members = nil

  # Reports whether the hooks can be installed.
  #
  # A second copy of this script would wrap the same methods under the same names, and each hook
  # would then call itself until the stack overflows.
  #
  # @return [Boolean] false when the hooks are in place already.
  def self.hookable?
    !SceneManager.respond_to?(:mgq_mp_coop_run)
  end

  # Writes a line to the Multiplayer mod's InGame.log.
  #
  # @param message [String] The line.
  def self.log(message)
    MGQ_Multiplayer::Log.write("coop: #{message}")
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
    seat = MGQ_MpOverworld::Link.status["seat"]
    seat.to_s.empty? ? -1 : seat.to_i
  end

  # Sends a co-op message to one game or to everyone, who ignore it outside the party.
  #
  # @param seat [Integer] The game's seat, -1 for everyone.
  # @param kind [String] What it is.
  # @param fields [Hash] Its other fields.
  # @return [Boolean] Whether it went out.
  def self.tell(seat, kind, fields)
    message = { "coop" => kind, "party" => MGQ_MpActions::Party.id }.merge(fields)
    MGQ_MpOverworld::Link.send_to(seat, MGQ_MpOverworld::Me.encode(message))
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
      others = MGQ_MpActions::Party.members.map { |peer| "#{peer.state['name']} on map #{peer.state['map']} (#{peer.state['scene']})" }
      return log("nobody to invite on map #{$game_map.map_id}: #{others.empty? ? 'no other party member' : others.join(', ')}")
    end

    battle_id = rand(36**8).to_s(36)
    MGQ_MpSync.join_world(:host, battle_id, seats, "the party")
    MGQ_MpSync.battle_started
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
    return false unless defined?(MGQ_MpOverworld) && MGQ_MpOverworld.in_world? && defined?(MGQ_MpActions) && MGQ_MpActions::Party.id
    return false if $game_temp && $game_temp.in_memory_battle
    return false if defined?(MGQ_PvpBattle) && MGQ_PvpBattle::Battle.running?

    busy = MGQ_MpSync.role || MGQ_MpBattles.running?
    log("no co-op battle: another multiplayer battle still runs (#{MGQ_MpSync.role.inspect}, #{MGQ_MpBattles.kind.inspect})") if busy
    !busy
  end

  # Lists the party members who may join: on the player's map, playing on it.
  #
  # @return [Array<MGQ_MpOverworld::Peers::Peer>] The members.
  def self.candidates
    MGQ_MpActions::Party.members.select { |peer| peer.state["map"].to_i == $game_map.map_id && FREE_SCENES.include?(peer.state["scene"]) }
  end

  # As host, waits for the invited members to join or turn the battle down, then sends everyone the
  # party and builds it. Without anyone joining, the battle is the host's own. Called at the battle's start.
  #
  # @param scene [Scene_Battle] The battle.
  # @return [Symbol, nil] An ending of mp_sync's Channel.ending, nil once the battle may start.
  def self.gather(scene)
    channel = MGQ_MpSync::Channel
    invited = MGQ_MpSync.seats
    joined = {}
    answered = []
    frames = 0
    answer = MGQ_MpSync::Waiting.wait_for(scene, "Gathering the party...") do
      invited.each do |seat|
        next if answered.include?(seat)

        body = channel.take_from("join", seat)
        joined[seat] = body if body
        answered << seat if body || channel.take_from("decline", seat) || MGQ_MpOverworld::Peers.at(seat).nil?
      end
      frames += 1
      answered.size == invited.size || frames >= JOIN_FRAMES ? true : nil
    end
    return answer if answer.is_a?(Symbol) && answer != :gone
    return stand_down if joined.empty? || answer == :gone

    MGQ_MpSync.keep_seats(joined.keys)
    players = [[own_seat, MGQ_Multiplayer::Player.name.to_s] + own_build(joined.size + 1)]
    joined.keys.sort.each do |seat|
      builds, vitals = MGQ_MpSync::Wire.parse(joined[seat].to_s)
      players << [seat, MGQ_MpOverworld::Peers.at(seat).state["name"].to_s, builds.to_s, Array(vitals)]
    end
    channel.post("roster", MGQ_MpSync::Wire.line([$game_troop.members.map(&:enemy_id), players]))
    form(scene, players)
    log("battle #{MGQ_MpSync.battle_id} with #{players.size} players")
    nil
  end

  # Ends the co-op battle before it began, since nobody joined: the battle is the host's own.
  #
  # @return [nil] Nothing, the battle starts.
  def self.stand_down
    log("nobody joined battle #{MGQ_MpSync.battle_id}")
    MGQ_MpSync.finish
    MGQ_MpBattles.finish
    nil
  end

  # The guest's side.

  # Takes a co-op message. Called by mp_overworld.rb.
  #
  # @param peer [MGQ_MpOverworld::Peers::Peer, nil] Who sent it.
  # @param message [Hash] The message's fields.
  def self.take(peer, message)
    return unless peer && message["coop"] == "invite" && message["party"] == MGQ_MpActions::Party.id
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
    return decline(peer, message) unless message["map"].to_i == $game_map.map_id && MGQ_MpSync.role.nil?
    return decline(peer, message) if invite[:frames] > ACCEPT_FRAMES
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
  # @param peer [MGQ_MpOverworld::Peers::Peer] The host.
  # @param message [Hash] The invite.
  def self.accept(peer, message)
    # The leader's story dialogue a member reads may be on screen; the battle takes its place.
    $game_message.clear
    @joining = true
    BattleManager.setup(message["troop"].to_i, message["escape"] == "1", message["lose"] == "1")
    @joining = false
    MGQ_MpSync.join_world(:guest, message["bid"].to_s, [peer.seat], peer.state["name"].to_s)
    MGQ_MpSync.battle_started
    MGQ_MpBattles.begin(:coop)
    SceneManager.call(Scene_Battle)
    log("joined #{peer.state['name']}'s battle #{message['bid']}")
  ensure
    @joining = false
  end

  # Turns an invite down, so the host need not wait for the player.
  #
  # @param peer [MGQ_MpOverworld::Peers::Peer] The host.
  # @param message [Hash] The invite.
  def self.decline(peer, message)
    @invite = nil
    MGQ_MpOverworld::Link.send_to(peer.seat, "battle=decline\nbid=#{message['bid']}\n\n")
  end

  # As guest, tells the host who joins and builds the party the host sends. Called at the battle's start.
  #
  # @param scene [Scene_Battle] The battle.
  # @return [Symbol, nil] An ending of mp_sync's Channel.ending, nil once the battle may start.
  def self.join(scene)
    # The guest sends as many characters as a pair brings; the host's party says how many fight.
    builds, vitals = own_build(2)
    MGQ_MpSync::Channel.post("join", MGQ_MpSync::Wire.line([builds, vitals]))
    roster = MGQ_MpSync::Waiting.wait_for(scene, "Joining #{MGQ_MpSync.player}'s battle...") { MGQ_MpSync::Channel.take("roster") }
    return roster if roster.is_a?(Symbol)

    enemy_ids, players = MGQ_MpSync::Wire.parse(roster.to_s)
    log("the troop differs from the host's") if Array(enemy_ids) != $game_troop.members.map(&:enemy_id)
    form(scene, Array(players))
    nil
  end

  # Both sides.

  # Writes the player's characters for a co-op battle.
  #
  # @param players [Integer] How many players fight, which decides how many characters each brings.
  # @return [Array] The builds, see MGQ_MpActors::Builds, and each character's HP and MP.
  def self.own_build(players)
    actors = own_members(share(players))
    [MGQ_MpActors::Builds.write(actors), actors.map { |actor| [actor.hp, actor.mp] }]
  end

  # Tells how many characters each player brings.
  #
  # @param players [Integer] How many players fight.
  # @return [Integer] How many characters each brings.
  def self.share(players)
    players == 2 ? PAIR_SHARE : 1
  end

  # Lists the first of the player's own battle members, past the co-op party.
  #
  # @param count [Integer] How many.
  # @return [Array<Game_Actor>] The characters.
  def self.own_members(count)
    $game_party.mgq_mp_coop_battle_members.first(count)
  end

  # Builds the co-op party every game shares, in the host's order: the player's own characters as
  # they are, everyone else's rebuilt with their HP and MP.
  #
  # @param scene [Scene_Battle] The battle.
  # @param players [Array<Array>] Each player's seat, name, builds and HP and MP.
  def self.form(scene, players)
    count = share(players.size)
    seat = own_seat
    members = []
    players.each do |player_seat, name, builds, vitals|
      if player_seat == seat
        members.concat(own_members(count))
        next
      end

      MGQ_MpActors::Builds.parse(builds.to_s, count).each_with_index do |member, index|
        ally = Game_MpAlly.new(member, name.to_s, player_seat)
        hp, mp = Array(vitals)[index]
        ally.hp = hp if hp.is_a?(Integer) && hp > 0
        ally.mp = mp if mp.is_a?(Integer)
        members << ally
      end
    end
    @members = members
    show_party(scene)
  end

  # Shows the co-op party in the battle's windows, which the scene made for the player's own party:
  # the status window, and the game's window per character, which takes its character only when made.
  #
  # @param scene [Scene_Battle] The battle.
  def self.show_party(scene)
    Array(scene.instance_variable_get(:@battle_actor_status_windows)).each_with_index { |window, index| window.actor = @members[index] }
    scene.send(:refresh_status) if scene.respond_to?(:refresh_status, true)
  rescue => e
    log("showing the party failed: #{e.class}: #{e.message}")
  end

  # Ends a co-op battle: the player's own party again, the game's own settings back, and the live
  # battle over. Called once the battle's scene ended.
  def self.ended
    return unless active? || (MGQ_MpSync.role && MGQ_MpSync.coop?) || MGQ_MpBattles.kind == :coop

    @members = nil
    MGQ_MpSync.finish if MGQ_MpSync.coop?
    MGQ_MpBattles.finish if MGQ_MpBattles.kind == :coop
  rescue => e
    @members = nil
    log("ending a co-op battle failed: #{e.class}: #{e.message}")
  end

  # Installs the hooks on methods the game's plugins may define anew. Called once the first scene starts.
  def self.install
    return if @installed

    @installed = true
    Game_Party.class_eval do
      alias_method :mgq_mp_coop_battle_members, :battle_members

      # Lists the battle members: the co-op party while a co-op battle runs.
      #
      # @return [Array<Game_Actor>] The members.
      def battle_members
        MGQ_MpCoop.active? ? MGQ_MpCoop.members : mgq_mp_coop_battle_members
      end
    end
  rescue => e
    log("party hook FAILED: #{e.class}: #{e.message}")
  end
end

# Another player's character in a co-op battle's party. Its owner commands it from their own game;
# the computer plays it when no command came, as after its owner left.
class Game_MpAlly < Game_MpActor
  # The owner's world seat.
  #
  # @return [Integer] The seat.
  attr_reader :mp_seat

  # Rebuilds another player's character.
  #
  # @param member [MGQ_MpActors::Builds::Member] The character's build.
  # @param player [String] Who the character belongs to.
  # @param seat [Integer] The owner's world seat.
  def initialize(member, player, seat)
    super(member, player)
    @mp_seat = seat
  end

  # Tells whether this game's player commands the character.
  #
  # @return [Boolean] Never, its owner does.
  def inputable?
    false
  end

  # Tells whether the character is Luka.
  #
  # @return [Boolean] Never; Luka's mechanics, binding and giving up, belong to the player's own Luka.
  def luca?
    false
  end

  # Makes the turn's actions with the game's own auto-battle, which the owner's commands replace.
  def make_actions
    super
    make_auto_battle_actions unless @actions.empty?
  end
end

# Game hooks.
#
# Each wraps a game method: the original runs first unless said otherwise, and the mod's part never
# raises.

if MGQ_MpCoop.hookable?
  begin
    class << SceneManager
      alias mgq_mp_coop_run run

      # Installs the hooks on methods the game's plugins may define anew, then runs the game.
      def run
        MGQ_MpCoop.install
        mgq_mp_coop_run
      end
    end
  rescue => e
    MGQ_MpCoop.log("SceneManager hook FAILED: #{e.class}: #{e.message}")
  end

  begin
    class << BattleManager
      alias mgq_mp_coop_setup setup

      # Sets up a battle, then makes it a co-op battle where the party can join.
      #
      # @param troop_id [Integer] The troop.
      # @param can_escape [Boolean] Whether the party may escape.
      # @param can_lose [Boolean] Whether losing goes on without a game over.
      def setup(troop_id, can_escape = true, can_lose = false)
        mgq_mp_coop_setup(troop_id, can_escape, can_lose)
        MGQ_MpCoop.offer(troop_id, can_escape, can_lose)
      end
    end
  rescue => e
    MGQ_MpCoop.log("battle setup hook FAILED: #{e.class}: #{e.message}")
  end

  begin
    class Scene_Map
      alias mgq_mp_coop_update_scene update_scene

      # Updates the map, then joins a co-op battle the player was invited to.
      def update_scene
        mgq_mp_coop_update_scene
        MGQ_MpCoop.on_map unless scene_changing?
      end
    end

    class Scene_Battle
      alias mgq_mp_coop_terminate terminate

      # Ends the battle's scene, then a co-op battle.
      def terminate
        mgq_mp_coop_terminate
        MGQ_MpCoop.ended
      end
    end
  rescue => e
    MGQ_MpCoop.log("scene hooks FAILED: #{e.class}: #{e.message}")
  end
end
