#----------------------------------------------------------------
#  battles_duel.rbx
#
#  Changelog:
#      Paulinchen  2026-11-05: Handed the DLL the player's team as values and took a team duel's sides as values
#                            - Handed the players a challenge names to the DLL as a list, which it writes into the state
#      Paulinchen  2026-10-31: Worded what the player reads plainly, leaving causes and internals to the log
#      Paulinchen  2026-10-30: Left the duel and team duel handshake to the DLL and read its view
#      Paulinchen  2026-10-23: Started duels without the deleted mirror match flag
#                            - Asked no longer for the deleted PvP switch
#      Paulinchen  2026-10-12: Took a non-numeric party_member_max as 0 and left a team duel whose sides did not read
#      Paulinchen  2026-10-11: Drew the challenge in the color every request and offer shares
#                            - Named the duel's waits in the line above the player's head with their seconds left
#                            - Stopped the player's own challenge once they accept another player's duel
#      Paulinchen  2026-10-07: Named players through overworld_sync.rbx and battles_sync.rbx
#                            - Logged every duel message and each step of a duel
#      Paulinchen  2026-10-06: Called a duel off whose battle could not start
#                            - Told a player who already started the duel once why it was called off
#                            - Brought no share of the Backline to a team duel
#                            - Made up a duel's id as a co-op battle's
#                            - Added the duel's choice to the action wheel's ring by order
#      Paulinchen  2026-10-04: Renamed from mp_battles_duel.rbx
#      Paulinchen  2026-10-03: Started a duel with the Backline when the challenger's duels have it
#                            - Kept a waiting duel and its sides' players as records
#                            - Offered the duel's choices and challenges through MGQ_MpActions
#                            - Asked MGQ_MpOverworldSync whether the map is quiet or the player free on it
#                            - Sent messages, showed notices and read the world through MGQ_MpOverworldSync
#                            - Logged through MGQ_MpLog
#                            - Took a team duel's call only from the accepted challenger or the party's leader
#                            - Read the hotkeys through MGQ_MpHotkeys
#                            - Told the challenger that a player declined
#      Paulinchen  2026-10-02: Named the action wheel's hotkey in the challenge line above a ghost
#                            - Followed the map through core_hooks.rbx
#                            - Sent the battle's break-off and leaving through MGQ_MpBattlesSync.tell
#      Paulinchen  2026-10-01: Created
#
#----------------------------------------------------------------

# Duels: PvP battles between two players of a world, the same battle as the PvP battle screen's
# (battles_pvp.rbx) carried over the world's room (battles_sync.rbx). The handshake is the DLL's
# (MGQOnline.Game's DuelHandshake): challenges, accepting, the start on both sides, declines and
# call-offs, and a team duel's gathering when a party's leader takes part. This script hands it what
# only the game knows (whether the player is free on the map, the game's fingerprint, the player's
# team, and how many members another player's team holds), starts the duels it hands back from the
# map, and offers the duel's choices, reading the DLL's view of the duels, which it never asks for
# per frame.
module MGQ_MpBattlesDuel
  # Color of the challenge line above a ghost's name and above the player's own head, the one every
  # request and offer shares.
  CHALLENGE_COLOR = MGQ_MpActions::LINE_COLOR

  # The bridge topic the player's frame goes to the DLL by, see before_frame.
  FRAME_TOPIC = "duel.frame"

  # The bridge topic a duel message the route took goes to the DLL by, see forward.
  TAKE_TOPIC = "duel.take"

  # The bridge topics of the player's actions, each answering the view afterwards.
  CHALLENGE_TOPIC = "duel.challenge"

  # See CHALLENGE_TOPIC.
  STOP_TOPIC = "duel.stop"

  # See CHALLENGE_TOPIC.
  ACCEPT_TOPIC = "duel.accept"

  # See CHALLENGE_TOPIC.
  DECLINE_TOPIC = "duel.decline"

  # The bridge topic that answers what the DLL needs of a team, see answer_need.
  TEAM_TOPIC = "duel.team"

  # The bridge topic that lets the duel waiting to start begin, see on_map.
  BEGIN_TOPIC = "duel.begin"

  # The bridge topic that calls off a duel whose battle could not start, see on_map.
  WITHDRAW_TOPIC = "duel.withdraw"

  # The bridge topic and event of the view, see take_view.
  VIEW_TOPIC = "duel.view"

  # The view outside a world.
  NO_VIEW = { "inviting" => false, "targets" => [], "invite_ends" => 0, "doing" => nil, "challengers" => {} }

  # A duel waiting to start from the map, as the DLL handed it.
  #
  # @!attribute role [Symbol] :host or :guest of a duel between two players, :team for a team duel.
  # @!attribute battle_id [String] The duel's id.
  # @!attribute peer [MGQ_MpOverworldSync::Peers::Peer, nil] The other player; of a team duel its
  #   host, nil when the player hosts it.
  # @!attribute members [Array<MGQ_MpActors::Builds::Member>, nil] The other player's team, nil for a team duel.
  # @!attribute own [Array<MGQ_MpBattlesCoop::Player>, nil] The players of the player's side of a team duel.
  # @!attribute other [Array<MGQ_MpBattlesCoop::Player>, nil] The players of the other side of a team duel.
  # @!attribute same_side [Boolean, nil] Whether the player stands on the host's side of a team duel.
  # @!attribute backline [Boolean, nil] Whether a duel between two players has the Backline.
  Pending = Struct.new(:role, :battle_id, :peer, :members, :own, :other, :same_side, :backline) do
    # Lists the seats of a team duel's players.
    #
    # @return [Array<Integer>] The seats of both sides.
    def seats
      (Array(own) + Array(other)).map(&:seat)
    end
  end

  # The DLL's view of the duels, see VIEW_TOPIC in DuelTopics.
  @view = NO_VIEW

  # The duel waiting to start once this player is back on the map, nil when none waits.
  @pending = nil

  # The player's frame as handed to the DLL last.
  @staged = nil

  # The other player's team read last and its members, which the duel that starts with it keeps.
  @read = nil

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "duel"

  # Reports whether duels can run: the mod is installed and up to date, and a world is open.
  #
  # @return [Boolean] Whether they can.
  def self.available?
    MGQ_Multiplayer.available? && !MGQ_Multiplayer.outdated? && MGQ_MpOverworldSync.in_world?
  end

  # Reports whether the player challenges to a duel now.
  #
  # @return [Boolean] Whether they do.
  def self.inviting?
    @view["inviting"] ? true : false
  end

  # The ids of the players the challenge reaches wherever they are, besides those nearby.
  #
  # @return [Array<String>] The ids, none while the player does not challenge.
  def self.targets
    Array(@view["targets"])
  end

  # Reports whether another player's challenge reaches the player: standing near, or naming them.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  # @param anywhere [Boolean] Whether a challenge naming the player counts wherever the challenger stands.
  # @return [Boolean] Whether it does.
  def self.challenged_by?(peer, anywhere = true)
    near, named = challenge_of(peer)
    near || (anywhere && named) ? true : false
  end

  # Reports whether a duel with another player who challenges becomes a team duel.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  # @return [Boolean] Whether it does.
  def self.team_duel?(peer)
    challenge_of(peer)[2] ? true : false
  end

  # Tells how another player's challenge reaches the player, as the view tells it.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  # @return [Array] Whether they stand near, whether the challenge names the player, and whether
  #   the duel becomes a team duel; all false while they do not challenge.
  def self.challenge_of(peer)
    (@view["challengers"] || {})[peer.seat] || [false, false, false]
  end

  # Reports whether the player may start a duel: on the map, with no event, message, transfer,
  # menu or other multiplayer battle of their own.
  #
  # @return [Boolean] Whether they may.
  def self.free?
    MGQ_MpOverworldSync.map_free? && MGQ_MpBattlesSync.role.nil? && !MGQ_MpBattles.running? && !MGQ_MpBattlesPvp::Battle.running?
  end

  # Challenges the players nearby, and a player anywhere in the world when named.
  #
  # @param target_id [String, nil] The id of a player the challenge reaches wherever they are.
  def self.invite(target_id = nil)
    act(CHALLENGE_TOPIC, "target" => target_id && target_id.to_s, "backline" => MGQ_MpBattlesPvp::Backline.wanted? ? true : false)
  end

  # Stops challenging.
  def self.stop
    act(STOP_TOPIC)
  end

  # Accepts a challenge: the DLL sends the challenger the player's team, while the player is free.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The challenger.
  def self.accept(peer)
    free = free?
    act(ACCEPT_TOPIC, "seat" => peer.seat, "free" => free, "team" => free ? team_values : nil)
  end

  # Turns another player down, telling them why.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  # @param reason [String] Why, such as "no".
  def self.decline(peer, reason)
    act(DECLINE_TOPIC, "seat" => peer.seat, "reason" => reason.to_s)
  end

  # Hands the DLL a duel message the route took, or a call to a team duel the party's leader passed on.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it.
  # @param message [Hash] The message's fields, its body under :payload.
  def self.forward(peer, message)
    fields = {}
    message.each { |key, value| fields[key] = value.to_s unless key.is_a?(Symbol) }
    act(TAKE_TOPIC, "seat" => peer && peer.seat, "fields" => fields, "body" => message[:payload].to_s)
  end

  # Asks the DLL for an action, and takes the view it answers.
  #
  # @param topic [String] The action's topic.
  # @param request [Object] What it takes, nil for nothing.
  def self.act(topic, request = nil)
    take_view(MGQ_Multiplayer::Bridge.call(topic, request))
  end

  # Takes the DLL's view of the duels.
  #
  # @param view [Hash] The view, see NO_VIEW for its fields.
  def self.take_view(view)
    @view = view if view.is_a?(Hash)
  end

  # Hands the DLL whether the player is free on the map and the game's fingerprint, once they
  # changed. Called before every frame's Graphics.update, so the frame's batch carries them before
  # the drain.
  def self.before_frame
    return unless MGQ_Multiplayer::Bridge.has?(FRAME_TOPIC)

    in_world = MGQ_MpOverworldSync.in_world?
    frame = { "free" => in_world && free? ? true : false, "game" => in_world ? MGQ_MpBattlesPvp::Team.game.to_s : "" }
    return if frame == @staged

    @staged = frame
    MGQ_Multiplayer::Bridge.stage(FRAME_TOPIC, frame)
  rescue => e
    log_once(:before_frame, "handing the DLL the player's frame failed: #{e.class}: #{e.message}")
  end

  # Forgets the duel waiting to start once no world is open. Called every frame in every scene.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    return if in_world

    @pending = nil
    @read = nil
  end

  # The fields the duel adds to the state the player's game tells the others.
  #
  # They are not named "duel", which marks the messages the DLL takes.
  #
  # @return [Hash] The fields.
  def self.state_fields
    { "challenge" => inviting? ? 1 : 0, "challenge_to" => targets, "challenge_backline" => MGQ_MpBattlesPvp::Backline.wanted? ? 1 : 0 }
  end

  # Words another player's challenge, with the Backline when their duels have it, which a team
  # duel never does.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The challenger.
  # @param start [String] How the line starts, up to the duel.
  # @return [String] The line.
  def self.challenge_text(peer, start)
    "#{start} to a duel#{' with Backline' if peer.state['challenge_backline'].to_i == 1 && !team_duel?(peer)}"
  end

  # Tells what the line above a ghost's name says: their challenge, when it reaches the player.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The ghost's player.
  # @return [Array, nil] The text and its color, nil for none.
  def self.label_line(peer)
    challenged_by?(peer) ? ["Challenges you to a duel (#{MGQ_MpHotkeys.label(:wheel)})", CHALLENGE_COLOR] : nil
  end

  # Answers what the DLL needs of a team: reads another player's team, writes the player's own,
  # and counts the characters of Frontlines, which only the game's data can.
  #
  # @param need [Hash] "id", "theirs" (a team to read), "own" ("pvp", "coop" or nil) and "builds"
  #   (Frontlines to count).
  def self.answer_need(need)
    answer = { "id" => need["id"] }
    if need["theirs"]
      members = MGQ_MpBattlesPvp::Team.parse(need["theirs"].to_s)
      @read = [need["theirs"].to_s, members]
      answer["count"] = members.size
    end
    own_team(need["own"], answer) unless answer["count"] == 0
    if need["builds"]
      answer["own_count"] = characters(answer["builds"])
      answer["counts"] = Array(need["builds"]).map { |builds| characters(builds) }
    end
    act(TEAM_TOPIC, answer)
  rescue => e
    log("answering what the DLL needs of a team failed: #{e.class}: #{e.message}")
    # An answer of nothing read lets the DLL drop what waits for it, so the challenge takes accepts again.
    act(TEAM_TOPIC, "id" => need["id"], "count" => 0)
  end

  # Writes the player's own team into an answer.
  #
  # @param kind [String, nil] "pvp" for a duel between two players, "coop" for a team duel's
  #   Frontline, nil for none.
  # @param answer [Hash] The answer.
  def self.own_team(kind, answer)
    case kind
    when "pvp"
      answer["line"] = team_values
      answer["backline"] = MGQ_MpBattlesPvp::Team.sent_backline?
    when "coop"
      builds, max = MGQ_MpBattlesCoop.team_build
      answer["builds"] = builds.to_s
      answer["max"] = max.to_i
    end
  end

  # Counts the characters a Frontline brings.
  #
  # @param builds [String, nil] The Frontline.
  # @return [Integer] Its characters.
  def self.characters(builds)
    MGQ_MpActors::Builds.parse(builds.to_s, MGQ_MpBattlesCoop::MOST_CHARACTERS).size
  end

  # Takes a duel the DLL hands to start from the map.
  #
  # @param start [Hash] "role", "bid", "seat", "name", "team", "backline", "sides" and "same_side".
  def self.take_start(start)
    seat = start["seat"]
    peer = seat && (MGQ_MpOverworldSync::Peers.at(seat) || MGQ_MpOverworldSync::Peers::Peer.new(seat, { "name" => start["name"].to_s }))
    if start["role"] == "team"
      sides = Array(start["sides"])
      hosts, others = [sides[0], sides[1]].map { |side| MGQ_MpBattlesCoop::Player.read_all(side) }
      own, other = start["same_side"] ? [hosts, others] : [others, hosts]
      @pending = Pending.new(:team, start["bid"].to_s, peer, nil, own, other, start["same_side"] ? true : false)
    else
      @pending = Pending.new(start["role"].to_s.to_sym, start["bid"].to_s, peer, members_of(start["team"].to_s), nil, nil, nil, start["backline"] ? true : false)
    end
  rescue => e
    log("taking a duel to start failed: #{e.class}: #{e.message}")
  end

  # Tells the members of the other player's team, as read when the DLL asked.
  #
  # @param team [String] The team.
  # @return [Array<MGQ_MpActors::Builds::Member>] The members.
  def self.members_of(team)
    read = @read
    @read = nil
    read && read[0] == team ? read[1] : MGQ_MpBattlesPvp::Team.parse(team)
  end

  # Starts a team duel from the map: as host with every other player as a guest, else as a guest
  # of the challenger.
  #
  # @param pending [Pending] The team duel.
  def self.start_team(pending)
    host = pending.peer
    if host
      MGQ_MpBattlesSync.join_world(:guest, pending.battle_id, [host.seat], host.state["name"].to_s, :pvp, true)
    else
      MGQ_MpBattlesSync.join_world(:host, pending.battle_id, pending.seats - [MGQ_MpOverworldSync::Me.seat], "the duel", :pvp, true)
    end
    MGQ_MpBattlesTeam.prepare(pending.own, pending.other, pending.same_side)
    MGQ_MpBattlesPvp::Battle.start(MGQ_MpBattlesTeam.opponent_name, []) { MGQ_MpBattlesTeam.opponents }
    log("team duel #{pending.battle_id} as #{host ? 'guest' : 'host'}, #{pending.own.size} against #{pending.other.size}")
  end

  # Gives the player's game fingerprint and team, which the DLL writes for the other player's game
  # to rebuild.
  #
  # @return [Array(String, String)] The fingerprint and the team.
  def self.team_values
    [MGQ_MpBattlesPvp::Team.game, MGQ_MpBattlesPvp::Team.build]
  end

  # Starts a duel waiting to start, from the map, as an encounter starts, once the DLL lets it
  # begin: it calls off one an event, a transfer or a menu came first to, or that it dropped since.
  # A duel whose battle could not start is called off too. Called by the map every frame.
  def self.on_map
    return unless @pending

    pending = @pending
    @pending = nil
    return unless MGQ_Multiplayer::Bridge.call(BEGIN_TOPIC, "bid" => pending.battle_id, "free" => free?)

    pending.role == :team ? start_team(pending) : start_duel(pending)
    act(WITHDRAW_TOPIC, pending.battle_id) unless MGQ_MpBattlesPvp::Battle.running?
  rescue => e
    @pending = nil
    log("starting a duel failed: #{e.class}: #{e.message}")
  end

  # Starts a duel between two players from the map.
  #
  # @param pending [Pending] The duel.
  def self.start_duel(pending)
    role, battle_id, peer, members = pending.role, pending.battle_id, pending.peer, pending.members
    name = peer.state["name"].to_s
    MGQ_MpBattlesSync.join_world(role, battle_id, [peer.seat], name, :pvp)
    MGQ_MpBattlesPvp::Battle.start(name, members, pending.backline)
    log("duel #{battle_id} with #{name} as #{role}#{' with the Backline' if pending.backline}")
  end

  # Names what the player is doing for the line above their own head, with the moment it lapses,
  # as the DLL's view names it.
  #
  # @return [Array, nil] The doing and when it lapses, nil while nothing waits.
  def self.own_doing
    doing = @view["doing"]
    doing ? [doing[0], MGQ_MpActions.lapse_in(doing[1] - MGQ_Multiplayer::Bridge.frame_number)] : nil
  end

  # What duels offer between two players, through ui_actions.rbx: their choices on the action wheel
  # and in the World overview, and challenges in the overview and the notification box.
  module Offers
    # The choice wherever duels cannot run.
    UNAVAILABLE = MGQ_MpActions::Option.new("Duel", nil, "Duels are not available right now.")

    # The wheel's duel choice: accepting the challenge of a player nearby, else challenging the
    # players nearby.
    #
    # @return [MGQ_MpActions::Option] The choice.
    def self.wheel_option
      duel = MGQ_MpBattlesDuel
      return UNAVAILABLE unless duel.available?

      option = MGQ_MpActions::Option
      near = MGQ_MpOverworldSync::Peers.all.select { |peer| MGQ_MpCoop::Party.near?(peer.state) }
      challenger = near.find { |peer| duel.challenged_by?(peer, false) }
      return option.new("Accept #{challenger.state['name']}'s duel", lambda { duel.accept(challenger) }, nil) if challenger
      return own_options.first if duel.inviting?

      option.new("Challenge to a duel", near.empty? ? nil : lambda { duel.invite }, "Nobody is near enough to challenge.")
    end

    # The duel choice for another player in the World overview: accepting their challenge, which
    # closes the overview, else challenging them.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
    # @return [MGQ_MpActions::Option] The choice.
    def self.peer_option(peer)
      duel = MGQ_MpBattlesDuel
      return UNAVAILABLE unless duel.available?

      option = MGQ_MpActions::Option
      return option.new("Accept duel", lambda { duel.accept(peer) }, nil, nil, true) if duel.challenged_by?(peer)
      return option.new("Challenged to a duel", nil, "Your challenge to #{peer.state['name']} stands.") if duel.targets.include?(peer.state["id"].to_s)

      option.new("Challenge to a duel", lambda { duel.invite(peer.state["id"]) }, nil)
    end

    # The duel choice on the player's own row of the World overview: stopping a challenge.
    #
    # @return [Array<MGQ_MpActions::Option>] The choice, none while the player does not challenge.
    def self.own_options
      MGQ_MpBattlesDuel.inviting? ? [MGQ_MpActions::Option.new("Stop challenging", lambda { MGQ_MpBattlesDuel.stop }, nil)] : []
    end

    # Tells another player's challenge, when it reaches the player.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @return [Array, nil] The text and its color, nil for none.
    def self.call_of(peer)
      MGQ_MpBattlesDuel.challenged_by?(peer) ? [MGQ_MpBattlesDuel.challenge_text(peer, "Challenges you"), CHALLENGE_COLOR] : nil
    end

    # Tells another player's challenge for the notification box, while it reaches the player and
    # duels can run.
    #
    # A duel starts only from the map, so in a menu the challenge stands without its Accept choice.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @return [MGQ_MpActions::Notice, nil] The challenge, nil for none.
    def self.notice_of(peer)
      duel = MGQ_MpBattlesDuel
      return nil unless duel.available? && duel.challenged_by?(peer)

      on_map = SceneManager.scene.is_a?(Scene_Map)
      MGQ_MpActions::Notice.new([:duel, peer.seat], duel.challenge_text(peer, "#{peer.state['name']} challenges you"), CHALLENGE_COLOR, on_map ? "Accept" : nil,
                                on_map ? lambda { duel.accept(peer) } : nil, lambda { duel.decline(peer, "no") }, peer.state["id"])
    end
  end
end

# What duels take part in of the world's messages, through overworld_sync.rbx, which the DLL takes.

begin
  MGQ_MpOverworldSync.route("duel") { |peer, message| MGQ_MpBattlesDuel.forward(peer, message) }
  MGQ_MpCoop.route("duel_call") { |peer, message| MGQ_MpBattlesDuel.forward(peer, message) }
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpBattlesDuel.tick(in_world) }
  MGQ_MpOverworldSync.state_fields { MGQ_MpBattlesDuel.state_fields }
  MGQ_MpOverworldSync.label_line { |peer| MGQ_MpBattlesDuel.label_line(peer) }
rescue => e
  MGQ_MpBattlesDuel.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

# What the DLL tells of the duels, through the bridge.

begin
  bridge = MGQ_Multiplayer::Bridge
  duel = MGQ_MpBattlesDuel
  bridge.on(duel::VIEW_TOPIC) { |view| duel.take_view(view) }
  bridge.on("duel.notice") { |text| MGQ_MpOverworldSync::Status.show(text.to_s) }
  bridge.on("duel.need_team") { |need| duel.answer_need(need) }
  bridge.on("duel.start") { |start| duel.take_start(start) }
rescue => e
  MGQ_MpBattlesDuel.log("bridge events FAILED: #{e.class}: #{e.message}")
end

# What duels add to the action wheel, the World overview and the notification box, through
# ui_actions.rbx.

begin
  MGQ_MpActions.offer(MGQ_MpBattlesDuel::Offers)
  MGQ_MpActions.wheel_choice(20) { MGQ_MpBattlesDuel::Offers.wheel_option }
  MGQ_MpActions.own_doing_from { MGQ_MpBattlesDuel.own_doing }
rescue => e
  MGQ_MpBattlesDuel.log("actions FAILED: #{e.class}: #{e.message}")
end

# Game hooks, through core_hooks.rbx.

begin
  # Before every frame, hands the DLL whether the player is free, which the frame's batch carries
  # before the drain.
  MGQ_MpHooks.before(Graphics.singleton_class, :update, "battles_duel") { MGQ_MpBattlesDuel.before_frame }
  MGQ_MpHooks.after(Scene_Map, :update_scene, "battles_duel") { MGQ_MpBattlesDuel.on_map unless scene_changing? }
rescue => e
  MGQ_MpBattlesDuel.log("hooks FAILED: #{e.class}: #{e.message}")
end
