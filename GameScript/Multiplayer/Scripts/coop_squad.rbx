#----------------------------------------------------------------
#  coop_squad.rbx
#
#  Changelog:
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
# monochrome under a line. On the map only each player's share of the Frontline follows them, or
# nobody, as the leader chose in the Mod Config. A battle a player fights alone keeps their own
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

  # The squad rules of a Raid World that names none: Luka stays, a team of four, and one character
  # on the Frontline in regular fights and in raids, which leaves two on the Backline and one cut.
  DEFAULT_RULES = { :luka => false, :formation => 4, :front => 1, :raid_front => 1 }

  # The option of followers in a party, its key in $game_system.conf.
  FOLLOWERS = :mp_party_followers

  # Followers' value that shows each player's share of the Frontline.
  ACTIVE_FRONTLINE = 0

  # Followers' value that shows the players alone.
  LEADERS_ONLY = 1

  # Followers' values by their name and help in the Mod Config. The first one is the default.
  FOLLOWER_VALUES = {
    ACTIVE_FRONTLINE => ["Active Frontline", "Each player's own share of the Frontline walks behind them."],
    LEADERS_ONLY => ["Leaders Only", "The players walk alone."],
  }

  # Color of the line above the first character past a squad in the formation screens.
  CUT_COLOR = MGQ_MpUi::Style::BAD

  # Shares of red, green and blue in a color's brightness, which a monochrome picture keeps.
  LUMA = [0.299, 0.587, 0.114]

  # Faces in a row of a face file.
  FACE_COLUMNS = 4

  # Width and height of a face in a face file, in pixels.
  FACE_SIZE = 96

  # Icons in a row of the icon set.
  ICON_COLUMNS = 16

  # Width and height of an icon in the icon set, in pixels.
  ICON_SIZE = 24

  # The player's share, the followers' mode and whether a Raid World is open, as tick last took
  # them, nil outside a world.
  @shown = nil

  # Monochrome copies of picture parts, by the picture's name and the part, see monochrome.
  @monochrome = {}

  # The party fitted to a Raid World, which party_member_max caps, nil while no cap holds.
  @capped = nil

  # The squad rules the party was fitted to, see fit_team.
  @capped_rules = nil

  # Whether the game's swaps of the party's order are held back, while the event command of
  # followers runs in a Raid World.
  @holding_order = false

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "co-op squad"

  # Splits places between players, one more each for the first ones while some are left over.
  #
  # @param total [Integer] The places.
  # @param count [Integer] The players.
  # @return [Array<Integer>] Each player's places, in the players' order.
  def self.split(total, count)
    return [] if count < 1

    total = [total, 0].max
    (0...count).map { |position| total / count + (position < total % count ? 1 : 0) }
  end

  # Tells a player's squad: their share of the Frontline and of the Backline.
  #
  # @param position [Integer] The player's place among the players, the leader first.
  # @param count [Integer] The players.
  # @param max [Integer] The player's party_member_max, Frontline and Backline together.
  # @return [Array<Integer>] The Frontline's and the Backline's share.
  def self.share(position, count, max)
    [split(FRONTLINE, count)[position].to_i, split(max - FRONTLINE, count)[position].to_i]
  end

  # Tells a player's squad in a co-op battle: in a Raid World their squad for the fight (see
  # raid_share), with as much of its Frontline as the battle's places split between the players
  # leave them, but always their first character, and the rest of the squad on the Backline; else
  # as share splits it.
  #
  # @param position [Integer] The player's place among the players, the leader first.
  # @param count [Integer] The players.
  # @param max [Integer] The player's party_member_max, Frontline and Backline together.
  # @return [Array<Integer>] The Frontline's and the Backline's share.
  def self.battle_share(position, count, max)
    return share(position, count, max) unless raid?

    front, bench = raid_share(max)
    fighting = [front, [split(FRONTLINE, count)[position].to_i, 1].max].min
    [fighting, front + bench - fighting]
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
  #   raids); DEFAULT_RULES when the world names none.
  def self.rules
    world = defined?(MGQ_MpWorld) && MGQ_MpWorld.respond_to?(:squad) ? MGQ_MpWorld.squad : nil
    world || DEFAULT_RULES
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

  # Splits a team into its Frontline, its Backline and the cut place: the Frontline as large as it
  # may be, the Backline what is left but the last place, which is cut while a place is left over;
  # with the game's own size nothing is cut.
  #
  # @param front [Integer] The Frontline's places the rules give.
  # @param size [Integer] The team's size.
  # @param original [Boolean] Whether the team keeps the game's own size.
  # @return [Array<Integer>] The Frontline's and the Backline's places.
  def self.layout(front, size, original)
    front = [[front, size].min, 1].max
    [front, original ? size - front : [size - front - 1, 0].max]
  end

  # Tells the player's squad in a Raid World for a fight: the Frontline the world's rules give for
  # it and the Backline the team leaves.
  #
  # @param max [Integer] The player's party_member_max.
  # @param raid [Boolean] Whether the fight is a raid.
  # @return [Array<Integer>] The Frontline's and the Backline's places.
  def self.raid_share(max = $game_party.party_member_max, raid = raid_fight?)
    current = rules
    original = current[:formation].to_i == ORIGINAL
    size = original ? max : [max, current[:formation].to_i].min
    layout((raid ? current[:raid_front] : current[:front]).to_i, size, original)
  end

  # Tells how many characters a player's squad in a Raid World holds at most, in a regular fight or
  # in a raid, which a co-op battle's host may hold either.
  #
  # @param max [Integer] The player's party_member_max.
  # @return [Integer] The characters.
  def self.largest_squad(max)
    [false, true].map { |raid| raid_share(max, raid).inject(:+) }.max
  end

  # Reports whether Luka leads the player's team, its first character.
  #
  # @return [Boolean] Whether he does.
  def self.luka_leads?
    first = $game_party.all_members.first
    first && first.luca? ? true : false
  end

  # Reports whether the player's characters split into a squad and the cut ones: in a party, and
  # always in a Raid World.
  #
  # @return [Boolean] Whether they do.
  def self.squads?
    raid? || MGQ_MpCoop.in_party?
  end

  # Orders players as every member's game does: the leader first, then by their ids.
  #
  # @param players [Array<Array>] Each player's id and whether they lead.
  # @return [Array<String>] The ids in order.
  def self.ranked(players)
    players.sort_by { |id, leads| [leads ? 0 : 1, id.to_s] }.map { |id, _| id.to_s }
  end

  # Tells the player's squad: in a Raid World as its rules size it (see raid_share), else their
  # share in their party.
  #
  # @return [Array<Integer>, nil] The Frontline's and the Backline's share, nil outside a party in
  #   a Classic world.
  def self.own_share
    return raid_share if raid?
    return nil unless MGQ_MpCoop.in_party?

    party = MGQ_MpCoop::Party
    leader = MGQ_MpCoop.party_leader
    own_id = MGQ_MpOverworldSync::Me.id
    players = [[own_id, leader == :me]] + party.members.map { |peer| [peer.state["id"].to_s, peer.equal?(leader)] }
    order = ranked(players)
    share(order.index(own_id), order.size, $game_party.party_member_max)
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

  # Reads how followers show in the party: the leader's choice, the player's own when they lead or
  # play outside a party.
  #
  # @return [Integer] ACTIVE_FRONTLINE or LEADERS_ONLY.
  def self.mode
    leader = MGQ_MpCoop.in_party? ? MGQ_MpCoop.party_leader : :me
    value = leader == :me || leader.nil? ? own_mode : leader.state["follow"]
    value.to_s == LEADERS_ONLY.to_s ? LEADERS_ONLY : ACTIVE_FRONTLINE
  end

  # Reads the player's own choice of followers in the Mod Config.
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

  # Turns a color into the grey of the same brightness.
  #
  # @param color [Color] The color.
  # @return [Color] The grey, with the color's opacity.
  def self.grey(color)
    level = color.red * LUMA[0] + color.green * LUMA[1] + color.blue * LUMA[2]
    Color.new(level, level, level, color.alpha)
  end

  # Makes a monochrome copy of part of a picture, once per picture and part.
  #
  # The copies stay for the session, since reading and writing every pixel is slow.
  #
  # @param name [String] What the picture is, which keys the copy.
  # @param source [Bitmap] The picture.
  # @param rect [Rect] The part.
  # @return [Bitmap] The copy.
  def self.monochrome(name, source, rect)
    key = [name, rect.x, rect.y, rect.width, rect.height]
    copy = @monochrome[key]
    return copy if copy && !copy.disposed?

    copy = Bitmap.new(rect.width, rect.height)
    copy.blt(0, 0, source, rect)
    rect.height.times do |y|
      rect.width.times do |x|
        color = copy.get_pixel(x, y)
        copy.set_pixel(x, y, grey(color)) if color.alpha > 0
      end
    end
    @monochrome[key] = copy
  end

  # Writes the looks of the followers the player shows, which their party's games show behind
  # their ghost.
  #
  # @return [String] Each follower's sprite and index, "name*index" joined by "|".
  def self.trail
    return "" unless MGQ_MpCoop.in_party? && $game_player

    shown = []
    $game_player.followers.each do |follower|
      shown << "#{follower.character_name}*#{follower.character_index}" if follower.visible? && !follower.character_name.to_s.empty?
    end
    shown.join("|")
  end

  # Reads the looks of a ghost's followers.
  #
  # @param text [String, nil] The trail the ghost's player told, see trail.
  # @return [Array<Array>] Each follower's sprite and index.
  def self.parse_trail(text)
    text.to_s.split("|").map do |part|
      name, index = part.split("*", 2)
      [name.to_s, index.to_i]
    end.reject { |name, _| name.empty? }
  end

  # The fields the squad adds to the state the player's game tells the others.
  #
  # @return [Hash] The followers' mode, the player's choice or the leader's they follow, and the
  #   looks of the followers the player shows.
  def self.state_fields
    { "follow" => mode, "trail" => trail }
  end

  # Fits the team to a Raid World, and shows the followers anew once the party, the player's share,
  # the leader's choice, the world's type or its squad rules changed. Called every frame in every
  # scene.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    raid = in_world && raid?
    fit_team(raid)
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
  # @return [Array<Integer>] The ids left out, in order.
  def self.past_cap(ids, size, keep_luka = true)
    kept = keep_luka ? ids.select { |id| luka?(id) }.first(size) : []
    ids.each { |id| kept << id if kept.size < size && !kept.include?(id) }
    ids - kept
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

  # Adds the followers' option to the Mod Config, or to the game's options without it, which only
  # the party's leader may change.
  def self.register
    MGQ_MpCoop.register_option(FOLLOWERS, "#{MGQ_MpUi::OPTION_PREFIX}Party Followers",
                               "Who walks behind the players of a party. The party's leader decides for everyone.", FOLLOWER_VALUES,
                               :enable => lambda { !MGQ_MpCoop.in_party? || MGQ_MpCoop.party_leader == :me })
  end

  # Draws the line under the squad's last character, on top of a row of the first cut character.
  #
  # @param window [Window_Base] The formation screen's window.
  # @param rect [Rect] The row.
  def self.draw_cut(window, rect)
    window.contents.fill_rect(rect.x, rect.y, rect.width, 2, CUT_COLOR)
  end

  # Installs the hooks on the game's plugins, which load after the Patch folder. Called once the
  # first scene starts.
  def self.install
    return if @installed

    @installed = true
    install_followers
    install_menu
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

  # Draws the menu's formation list by the party's squad: the Frontline's share as the Frontline,
  # the Backline's share as the Backline, and the rest monochrome under a line.
  def self.install_menu
    Window_MenuStatus.class_eval do
      alias_method :mgq_mp_coop_squad_draw_item, :draw_item
      alias_method :mgq_mp_coop_squad_draw_actor_face, :draw_actor_face
      alias_method :mgq_mp_coop_squad_text_color, :text_color
      alias_method :mgq_mp_coop_squad_draw_icon, :draw_icon

      # Draws a character as the game does, in the style of their place in the player's squad
      # while they have one, with a line above the first character past the squad.
      #
      # @param index [Integer] The row.
      def draw_item(index)
        squad = MGQ_MpCoopSquad
        place = instance_of?(Window_MenuStatus) && !$game_party.in_battle ? squad.place_of($game_party.members[index]) : nil
        @mgq_mp_coop_squad_place = place
        mgq_mp_coop_squad_draw_item(index)
        return unless place == :cut && !(index > 0 && squad.place_of($game_party.members[index - 1]) == :cut)

        squad.draw_cut(self, item_rect(index))
      rescue => e
        MGQ_MpCoopSquad.log("menu row failed: #{e.class}: #{e.message}")
      ensure
        @mgq_mp_coop_squad_place = nil
      end

      # Draws a face: opaque on the squad's Frontline, translucent on its Backline as the game draws
      # the Backline, monochrome past the squad.
      #
      # @param actor [Game_Actor] The character.
      # @param x [Integer] The face's left edge.
      # @param y [Integer] The face's top edge.
      # @param enabled [Boolean] Whether the game draws it opaque.
      def draw_actor_face(actor, x, y, enabled = true)
        case @mgq_mp_coop_squad_place
        when nil then mgq_mp_coop_squad_draw_actor_face(actor, x, y, enabled)
        when :cut
          squad = MGQ_MpCoopSquad
          rect = Rect.new(actor.face_index % squad::FACE_COLUMNS * squad::FACE_SIZE, actor.face_index / squad::FACE_COLUMNS * squad::FACE_SIZE, squad::FACE_SIZE, squad::FACE_SIZE)
          contents.blt(x, y, squad.monochrome("face:#{actor.face_name}", Cache.face(actor.face_name), rect), Rect.new(0, 0, squad::FACE_SIZE, squad::FACE_SIZE))
        else mgq_mp_coop_squad_draw_actor_face(actor, x, y, @mgq_mp_coop_squad_place == :front)
        end
      end

      # Picks a text color of the window's skin, grey past the squad.
      #
      # @param n [Integer] The color's number.
      # @return [Color] The color.
      def text_color(n)
        color = mgq_mp_coop_squad_text_color(n)
        @mgq_mp_coop_squad_place == :cut ? MGQ_MpCoopSquad.grey(color) : color
      end

      # Draws an icon, monochrome past the squad.
      #
      # @param icon_index [Integer] The icon.
      # @param x [Integer] Its left edge.
      # @param y [Integer] Its top edge.
      # @param enabled [Boolean] Whether it is drawn opaque.
      def draw_icon(icon_index, x, y, enabled = true)
        return mgq_mp_coop_squad_draw_icon(icon_index, x, y, enabled) unless @mgq_mp_coop_squad_place == :cut

        squad = MGQ_MpCoopSquad
        rect = Rect.new(icon_index % squad::ICON_COLUMNS * squad::ICON_SIZE, icon_index / squad::ICON_COLUMNS * squad::ICON_SIZE, squad::ICON_SIZE, squad::ICON_SIZE)
        contents.blt(x, y, squad.monochrome("icon", Cache.system("Iconset"), rect), Rect.new(0, 0, squad::ICON_SIZE, squad::ICON_SIZE))
      end
    end
  rescue => e
    log("menu hook FAILED: #{e.class}: #{e.message}")
  end

  # Colors the party edit screen by the party's squad: the Frontline's share as the Frontline, the
  # Backline's share as the Backline, and the rest grey under a line. The game's own drawing stays,
  # with the translation's larger rows.
  def self.install_party_edit
    return unless defined?(Foo::PTEdit::Window_PartyMember)

    Foo::PTEdit::Window_PartyMember.class_eval do
      alias_method :mgq_mp_coop_squad_draw_item, :draw_item
      alias_method :mgq_mp_coop_squad_change_color, :change_color

      # Draws a row as the game does, in the color of its place in the player's squad while they
      # have one, with a line above the first row past the squad.
      #
      # @param index [Integer] The row.
      def draw_item(index)
        place = MGQ_MpCoopSquad.squads? ? mgq_mp_coop_squad_place(index) : nil
        @mgq_mp_coop_squad_place = place
        mgq_mp_coop_squad_draw_item(index)
        return unless place == :cut && index > 0 && mgq_mp_coop_squad_place(index - 1) != :cut

        MGQ_MpCoopSquad.draw_cut(self, item_rect(index))
      rescue => e
        MGQ_MpCoopSquad.log("party edit row failed: #{e.class}: #{e.message}")
      ensure
        @mgq_mp_coop_squad_place = nil
      end

      # Sets the text color, by the row's place in the party's squad while one is drawn.
      #
      # @param color [Color] The color the game picked by the Frontline of single player.
      # @param enabled [Boolean] Whether the row can be picked.
      def change_color(color, enabled = true)
        case @mgq_mp_coop_squad_place
        when :front then color = normal_color
        when :bench then color = system_color
        when :cut then color = MGQ_MpCoopSquad.grey(system_color)
        end
        mgq_mp_coop_squad_change_color(color, enabled)
      end

      # Tells a row's place in the party's squad: its character's, or the place itself for an
      # empty row.
      #
      # @param index [Integer] The row.
      # @return [Symbol] :front, :bench or :cut.
      def mgq_mp_coop_squad_place(index)
        id = @actors[index]
        (id ? MGQ_MpCoopSquad.place_of($game_actors[id]) : MGQ_MpCoopSquad.place_at(index)) || :cut
      end
    end
  rescue => e
    log("party edit hook FAILED: #{e.class}: #{e.message}")
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
