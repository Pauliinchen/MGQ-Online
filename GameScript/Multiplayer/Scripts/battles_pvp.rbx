#----------------------------------------------------------------
#  battles_pvp.rbx
#
#  Changelog:
#      Paulinchen  2026-10-07: Registered the map, troop, sprite, save and automatic skill hooks through core_hooks.rbx instead of wraps of its own, and the action and turn hooks once the game runs, where plugins define them anew
#                            - Named characters through battles_sync.rbx, and took the faces' columns from coop_squad.rbx
#                            - Logged the exchange's stages, the teams swapped, the Backline rule, the result and the game put back
#      Paulinchen  2026-10-06: Named the log in the game folder's Logs folder in the messages of a failed or broken battle
#      Paulinchen  2026-10-04: Dropped a story's call that waited through the battle once the game is put back, and logged where it was put back
#                            - Renamed from mp_battles_pvp.rbx
#                            - Counted the Backline of the friend's team for the stat boosts the game counts the whole party for
#                            - Fired the automatic skills of a battle's start, a turn's start and a turn's end by speed instead of the host's team first
#      Paulinchen  2026-10-03: Swapped the Backline's builds too, with the host's rule, and started a battle with the Backline of battles_pvp_backline.rbx
#                            - Fought with the balance of battles_balance_pvp.rbx
#                            - Read and wrote the game's private fields and called its private methods through MGQ_MpGame
#                            - Moved the mirror match's report into battles_pvp_mirror.rbx and the PvP battle screen into battles_pvp_lobby.rbx
#                            - Called the scripts that load before this one without asking whether they loaded
#                            - Logged through MGQ_MpLog
#                            - Read the bound keys through MGQ_MpHotkeys, renamed from MGQ_MpKeys
#      Paulinchen  2026-10-02: Opened the PvP battle screen with the key the player bound to the World overview
#                            - Followed the map and the title screen through core_hooks.rbx
#                            - Took the Frontline's size from coop_squad.rbx, and the seat, place and Luka from Game_MpActor
#                            - Listed the PvP battle screen's commands once per change of the exchange
#      Paulinchen  2026-10-01: Left F11 to the World overview in a world, also once a newer release is out
#                            - Let a team duel start the battle with the other side's characters it rebuilt, each with its owner's seat
#      Paulinchen  2026-09-30: Moved into Patch/Multiplayer/Scripts as battles_pvp.rbx, which Multiplayer.rb loads, and named the log there
#                            - Renamed from pvp_battle.rb, with the module MGQ_MpBattlesPvp
#                            - Disabled PvP battles once a newer release of the mod is out, telling the player on F11
#                            - Left the rules every multiplayer battle shares to battles.rbx
#                            - Left the builds and the rebuilt characters' shared parts to core_actors.rbx
#      Paulinchen  2026-09-29: Kept the PvP battle screen closed while a world is open
#                            - Joined an invite accepted after a failed exchange instead of turning it down with the failure
#                            - Stopped asking for an open port and naming the way the team came, since every team comes through the relay
#                            - Said that a host is reaching the relay until its join code is ready
#                            - Said on the PvP battle screen when the friend's team came through the relay
#                            - Said when a Discord invite arrived while hosting and was ignored
#                            - Joined the host of an accepted Discord invite at once, loading the last save at the title screen
#                            - Said on the map when a live battle broke off
#                            - Closed the link of a live battle that a reset interrupted
#                            - Started the friend's characters' sprite effects through the setter the guest's stream records
#                            - Polled the connection without the friend's team
#      Paulinchen  2026-09-28: Created
#
#----------------------------------------------------------------

# PvP battles: two games swap their teams' builds, then fight the same battle live, each player
# commanding their own team, and the game is put back as it was once it ends. Only the Frontline
# fights unless the host's battles have the Backline (battles_pvp_backline.rbx). A mirror match
# fights the player's own team, played by the computer.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpBattlesPvp
  # Turns PvP battles off without uninstalling them.
  ENABLED = true

  # Frames between two looks at the exchange, a third of a second at 60 frames per second.
  POLL_INTERVAL = 20

  # Who the player's own team belongs to in a mirror match.
  MIRROR_NAME = "Mirror"

  # What the game says when a Discord invite arrived while this game hosted, which the DLL ignores.
  IGNORED_INVITE = "You're hosting, so the Discord invite you accepted was ignored."

  # Tells whether PvP battles can run.
  #
  # A world keeps a connection of its own, and the two would both claim the Discord status.
  #
  # @return [Boolean] Whether PvP battles are on, the mod's DLL is installed, no newer
  #   release is out, and no world is open.
  def self.available?
    ENABLED && MGQ_Multiplayer.available? && !MGQ_Multiplayer.outdated? && !MGQ_MpWorld.open?
  end

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "pvp battle"

  # Has the map start a mirror match against the player's own team, once the screen closed.
  def self.request_mirror
    @mirror_requested = true
  end

  # Opens the PvP battle screen when the key is pressed, starts a requested mirror match, starts
  # the battle once the friend's team arrived, and joins the host of a Discord invite. Called by the
  # map while nothing else runs.
  #
  # Once a newer release is out, the key only tells the player to update instead.
  def self.on_map
    # In a world the same key opens the World overview, and a key press is read only once, by
    # whoever asks first.
    return if MGQ_MpWorld.open?

    if MGQ_Multiplayer.available? && MGQ_Multiplayer.outdated?
      pressed = MGQ_MpHotkeys.pressed?(:overview)
      return if $game_map.interpreter.running? || $game_player.moving?

      if pressed
        log("the PvP battle screen stays closed: a newer release is out")
        $game_message.add(MGQ_Multiplayer::UPDATE_MESSAGE)
      end
      return
    end

    return unless available?

    pressed = MGQ_MpHotkeys.pressed?(:overview)
    return if $game_map.interpreter.running? || $game_player.moving?

    if pressed
      log("opened the PvP battle screen")
      SceneManager.call(Scene_PvpLobby)
      return
    end

    if @mirror_requested
      @mirror_requested = false
      log("starting the requested mirror match")
      begin_mirror
      return
    end

    @frames = (@frames || 0) + 1
    return if @frames < POLL_INTERVAL

    @frames = 0
    look_at(MGQ_Multiplayer::Link.status)
  rescue => e
    @frames = 0
    log("map check failed: #{e.class}: #{e.message}")
  end

  # Acts on how the exchange stands, seen from the map.
  #
  # @param state [Hash] The state without the friend's team, see MGQ_Multiplayer::Link.status.
  def self.look_at(state)
    note_state(state)
    $game_message.add(IGNORED_INVITE) if ignored_invite?(state)

    case state["state"]
    when "received"
      state = MGQ_Multiplayer::Link.state
      live = MGQ_MpBattlesSync.join(state)
      log("#{MGQ_Multiplayer.clean(state['opponent'])}'s team arrived (#{state[:payload].to_s.size} bytes), " +
          (live ? "the battle is live as #{state['role']}" : "the link is not open, so the battle is not live and the link closes"))
      MGQ_Multiplayer::Link.cancel unless live
      begin_battle(state)
    when "failed"
      # Cancelling would turn down an invite the player accepted since, which makes the failure old news.
      if join_invite(state)
        log("the exchange failed, but a Discord invite was accepted since: opening the PvP battle screen")
        SceneManager.call(Scene_PvpLobby)
      else
        log("the exchange failed (#{state['error']}): closed it and told the player")
        MGQ_Multiplayer::Link.cancel
        $game_message.add("PvP battle: #{state['error']}")
      end
    else
      SceneManager.call(Scene_PvpLobby) if join_invite(state)
    end
  end

  # Logs how the exchange stands once it changed, never its join code.
  #
  # @param state [Hash] The state without the friend's team, see MGQ_Multiplayer::Link.status.
  def self.note_state(state)
    current = state["state"].to_s
    current = "idle" if current.empty?
    return if current == (@logged_state || "idle")

    details = []
    details << "as #{state['role']}" if state["role"]
    details << "join code ready" if current == "hosting" && state["code"]
    details << state["error"].to_s if current == "failed"
    log("the PvP exchange went from #{@logged_state || 'idle'} to #{current}#{details.empty? ? '' : " (#{details.join(', ')})"}")
    @logged_state = current
  rescue => e
    log_once(:note_state, "could not log the exchange: #{e.class}: #{e.message}")
  end

  # Tells once per invite that one arrived while this game hosted and was ignored.
  #
  # @param state [Hash] The state without the friend's team, see MGQ_Multiplayer::Link.status.
  # @return [Boolean] Whether another invite was ignored since the last look.
  def self.ignored_invite?(state)
    count = state["ignored"].to_i
    fresh = count > (@ignored_seen || 0)
    @ignored_seen = count
    log("a Discord invite arrived while hosting and was ignored (#{count} so far)") if fresh
    fresh
  end

  # Joins the host of an invite the player accepted in Discord, unless this game joins already.
  #
  # @param state [Hash] The state without the friend's team, see MGQ_Multiplayer::Link.status.
  # @return [Boolean] Whether it started joining.
  def self.join_invite(state)
    return false unless state["invite"] == "1" && state["state"] != "joining"

    MGQ_Multiplayer::Link.join_invite(Team.game, Team.build)
    log("joining the host of a Discord invite")
    true
  end

  # Loads the last save at the title screen once the player accepted a Discord invite, so the map
  # joins the host. Called by the title screen every frame while nothing else runs.
  #
  # Without any save it does nothing, and the map joins once the player started a game.
  def self.on_title
    return unless available? && !@title_load_failed

    @title_frames = (@title_frames || 0) + 1
    return if @title_frames < POLL_INTERVAL

    @title_frames = 0
    return unless MGQ_Multiplayer::Link.status["invite"] == "1"

    index = DataManager.latest_savefile_index
    return unless index && DataManager.load_header(index)

    unless DataManager.load_game(index)
      @title_load_failed = true
      return log("could not load the last save for a Discord invite")
    end

    log("loaded the last save for a Discord invite")
    # Scene_Load finishes the game's own loads, so the map starts exactly as after Continue.
    Scene_Load.new.on_load_success
  rescue => e
    @title_frames = 0
    log("title check failed: #{e.class}: #{e.message}")
  end

  # Starts the battle against the friend's team that arrived.
  #
  # @param state [Hash] The state, see MGQ_Multiplayer::Link.state.
  def self.begin_battle(state)
    opponent = MGQ_Multiplayer.clean(state["opponent"])
    members = Team.parse(state[:payload])

    if members.empty?
      log("#{opponent}'s team could not be read (#{state[:payload].to_s.size} bytes): no battle, the link closes")
      $game_message.add("#{opponent}'s team could not be read.")
      MGQ_MpBattlesSync.finish
      MGQ_Multiplayer::Link.cancel
      return
    end

    # The host's rule holds: the one it sent with its own team, or the one its team brought.
    backline = state["role"] == "host" ? Team.sent_backline? : Team.backline?(state[:payload])
    log("read #{members.size} members of #{opponent}'s team; the host's rule: #{backline ? 'with' : 'without'} the Backline" +
        " (#{state['role'] == 'host' ? 'this game hosts' : "the host's team says so"})")
    Battle.start(opponent, members, false, backline)
  end

  # Starts a mirror match: the player's own team, sent through the same build as a friend's would
  # be, so it fights exactly as a friend would meet it.
  def self.begin_mirror
    team = Team.build
    Battle.start(MIRROR_NAME, Team.parse(team), true, Team.backline?(team))
  end

  # The fields the Discord mod publishes about PvP battles, through its bridge. The Discord mod
  # hears of hosting and the connection with the friend from Multiplayer.rb.
  #
  # @param scene [String] What the game is showing, see MGQ_Discord::GameState.scene.
  # @return [Hash] The fields, none outside a PvP battle.
  def self.status_fields(scene)
    return {} unless Battle.running? && scene == "battle"

    Battle.mirror? ? { "pvp_battle" => "mirror" } : { "pvp_battle_with" => Battle.opponent }
  end

  # Installs the hooks on methods the game's plugins may define anew. Called once the first scene
  # starts.
  def self.install
    return if @installed

    @installed = true
    install_targetless
    install_turns
  end

  # Leaves out an action without a target the way the game leaves out one without a skill.
  def self.install_targetless
    MGQ_MpHooks.around(Scene_Battle, :use_item, "battles_pvp") do |scene, _args, original|
      subject = MGQ_MpGame.get(scene, :subject)
      next original.call unless Battle.running? && Battle.targetless?(subject)

      log("left out #{subject.name}'s action in turn #{$game_troop.turn_count}: it finds no target") rescue nil
      MGQ_MpGame.get(scene, :log_window).display_target_empty(subject)
      true
    end
  rescue => e
    log("use_item hook FAILED: #{e.class}: #{e.message}")
  end

  # Adds to a mirror match's report how both teams look as each turn starts.
  def self.install_turns
    MGQ_MpHooks.after(BattleManager.singleton_class, :turn_start, "battles_pvp") { MGQ_MpBattlesPvp::MirrorReport.turn_started if MGQ_MpBattlesPvp::Battle.running? }
  rescue => e
    log("turn hook FAILED: #{e.class}: #{e.message}")
  end

  # The team two games swap: the builds of the Frontline and the Backline, see MGQ_MpActors::Builds,
  # below a line that says whether the sender's battles have the Backline.
  module Team
    # Starts a team's first line, followed by 1 when the sender's battles have the Backline, else 0.
    RULE = "backline="

    # A team's first line.
    RULE_LINE = /\A#{RULE}([01])\r?\n/

    # Members read of a team at most, which limits what another game can have this one rebuild.
    MOST_MEMBERS = 20

    # Tells this game's data and the build format from another's.
    #
    # @return [String] The fingerprint, see MGQ_MpActors::Builds.game.
    def self.game
      MGQ_MpActors::Builds.game
    end

    # Writes the player's team, the Frontline first, and notes the rule it carries, which holds
    # when the player hosts the battle.
    #
    # @return [String] The rule's line, then a member line per party member.
    def self.build
      @sent_backline = Backline.wanted?
      party = $game_party.battle_members.first(MGQ_MpCoopSquad::FRONTLINE) + $game_party.bench_members
      sent = party.first(MOST_MEMBERS)
      MGQ_MpBattlesPvp.log("built the team to send: #{MGQ_MpBattlesSync.named_list(sent)}; " \
                           "#{@sent_backline ? 'with' : 'without'} the Backline")
      "#{RULE}#{@sent_backline ? 1 : 0}\n" + MGQ_MpActors::Builds.write(sent)
    end

    # Reports whether the team the player sent last said their battles have the Backline.
    #
    # @return [Boolean] Whether it did.
    def self.sent_backline?
      @sent_backline ? true : false
    end

    # Reports whether a team says its sender's battles have the Backline.
    #
    # @param text [String] The team, see build.
    # @return [Boolean] Whether it does.
    def self.backline?(text)
      text.to_s[RULE_LINE, 1] == "1"
    end

    # Reads a friend's team, taking only what this game's data knows.
    #
    # @param text [String] The team, see build.
    # @return [Array<MGQ_MpActors::Builds::Member>] The members, the Frontline first, none when nothing was readable.
    def self.parse(text)
      MGQ_MpActors::Builds.parse(text.to_s.sub(RULE_LINE, ""), MOST_MEMBERS)
    end
  end

  # One of the friend's characters, rebuilt from its build (see Game_MpActor) and fighting on the
  # enemy side, where it answers what the battle's code asks only of monsters.
  class Opponent < Game_MpActor
    # How grey the picture turns while the character is dead, from 0 to the fully grey 255.
    SILHOUETTE_GRAY = 255

    # How opaque the picture is while the character is dead, from 0 to the fully opaque 255.
    SILHOUETTE_OPACITY = 160

    # Where the picture stands, at its bottom edge.
    attr_accessor :screen_x, :screen_y

    # The letter and plural mark the game gives monsters of the same name.
    attr_accessor :letter, :plural

    # Rebuilds a friend's character.
    #
    # @param member [MGQ_MpActors::Builds::Member] The character's build.
    # @param player [String] Who the character belongs to.
    def initialize(member, player)
      super
      @letter = ""
      @plural = false
      @screen_x = 0
      @screen_y = 0
    end

    # Names the character without its owner.
    #
    # @return [String] The name, which the battle's "X appears!" lines read.
    def original_name
      name
    end

    # Returns the character's own side.
    #
    # @return [Game_Troop] The friend's team.
    def friends_unit
      $game_troop
    end

    # Returns the side the character fights.
    #
    # @return [Game_Party] The player's party.
    def opponents_unit
      $game_party
    end

    # Finds the character's place in the troop.
    #
    # @return [Integer, nil] The place in the troop, which targeting uses.
    def index
      $game_troop.members.index(self)
    end

    # Tells whether the character fights.
    #
    # @return [Boolean] Always, the troop is all it fights in.
    def battle_member?
      true
    end

    # Tells whether the character is drawn as a sprite.
    #
    # @return [Boolean] Always, it is drawn like a monster.
    def use_sprite?
      true
    end

    # Returns the character's drawing order.
    #
    # @return [Integer] How far in front its picture is drawn.
    def screen_z
      100
    end

    # Returns the character's battle picture.
    #
    # @return [String] No battle picture of its own, Pictures draws the Library's.
    def battler_name
      ""
    end

    # Returns the hue of the character's battle picture.
    #
    # @return [Integer] No hue change.
    def battler_hue
      0
    end

    # A stand-in for the monster data the battle's code reads of the enemy side.
    #
    # @return [RPG::Enemy] A monster without rewards, notes or recruiting.
    def enemy
      @enemy ||= Opponents.enemy_data(name)
    end

    # Returns the id enemy code reads.
    #
    # @return [Integer] The character's actor id, which enemy HP bars and the Library read.
    def enemy_id
      id
    end

    # Returns the affection enemy code reads.
    #
    # @return [Integer] No affection, which the target window shows for monsters.
    def friend
      0
    end

    # Returns the defeat scene enemy code reads.
    #
    # @return [Integer] No defeat scene.
    def lose_event_id
      0
    end

    # Tells whether running away is left out of the escape count.
    #
    # @return [Boolean] Always, running from a PvP battle counts as no escape.
    def escape_not_count?
      true
    end

    # Lists what can be stolen from the character.
    #
    # @return [Hash] Nothing to steal.
    def steal_list
      { 1 => [], 2 => [], 3 => [], 4 => [] }
    end

    # Returns the escape level enemy code reads.
    #
    # @return [Integer] How hard it is to run from, which the escape chance reads of every enemy.
    def escape_level
      enemy.escape_level
    end

    # Answers what the battle's code asks only monsters, from the monster stand-in, and logs it
    # once. A question the audit missed would otherwise end the game in the middle of a battle.
    #
    # @param name [Symbol] The method.
    # @param args [Array] Its arguments.
    # @return [Object] The stand-in's answer.
    def method_missing(name, *args, &block)
      return super unless Game_Enemy.method_defined?(name) && enemy.respond_to?(name)

      MGQ_MpBattlesPvp.log_once([:forwarded, name], "#{name} answered by the monster stand-in")
      enemy.send(name, *args, &block)
    end

    # Tells whether method_missing answers a method.
    #
    # @param name [Symbol] The method.
    # @param include_private [Boolean] Whether private methods count.
    # @return [Boolean] Whether method_missing answers it.
    def respond_to_missing?(name, include_private = false)
      (Game_Enemy.method_defined?(name) && enemy.respond_to?(name)) || super
    end

    # Tells whether the character is a boss.
    #
    # @return [Boolean] Never a boss, which the enemy HP bars read.
    def boss?
      false
    end

    # Tells whether the character's name is hidden.
    #
    # @return [Boolean] Never hides its name, which the enemy HP bars read.
    def hide_name
      false
    end

    # Returns the shift of the character's HP bar.
    #
    # @return [Integer] No shift of its HP bar.
    def lefx
      0
    end

    # Boosts a stat for each character on its own side, where the game counts the player's party:
    # the whole team outside of battle, the Frontline in battle.
    #
    # @param param_id [Integer] The stat.
    # @return [Float] The boost.
    def booster_actor_exist_param(param_id)
      return 1.0 unless (2..7).include?(param_id)

      side = $game_party.in_battle ? friends_unit.members : whole_team
      side.inject(1.0) { |rate, member| rate + features_sum_booster(ACTOR_EXIST_PARAM, member.id) }
    end

    # Boosts a stat by what every other character of its team gives the team, the Backline's too,
    # where the game counts the player's whole party.
    #
    # @param param_id [Integer] The stat.
    # @return [Float] The boost.
    def booster_party_member(param_id)
      others = whole_team.reject { |member| member.equal?(self) }
      others.inject(1.0) { |rate, member| rate + member.party_member_boost(param_id) }
    end

    # Flashes and sounds like a hit monster instead of shaking the screen.
    #
    # This and perform_collapse_effect start the effect through the setter, which a live battle
    # records for the guest.
    def perform_damage_effect
      self.sprite_effect_type = :blink
      Sound.play_enemy_damage
    end

    # Flashes and sounds like a defeated monster, but stays on the battlefield as a silhouette, since
    # the friend's team can still bring it back.
    def perform_collapse_effect
      self.sprite_effect_type = :whiten
      Sound.play_enemy_collapse
    end

    # Picks the automatic skills (pre-battle spells, counters, turn start and end) whose condition
    # holds and whose chance comes up, like the game does, with "ally" and "enemy" seen from the
    # friend's side. The game checks the player's party for allies.
    #
    # @param skills [Array<Hash>] The automatic skills, with :condition_type, :condition_ids and :per.
    # @return [Array<Hash>] Those that fire.
    def firing_auto_skills(skills)
      own = $game_troop.members
      skills.select do |skill|
        if skill[:condition_type]
          next false unless skill_race_ok?($data_skills[skill[:id]])
          next false unless auto_skill_condition_met?(skill[:condition_type], skill[:condition_ids], own)
        end
        rand < skill[:per]
      end
    end

    # Makes the turn's actions with the game's own auto-battle.
    def make_actions
      super
      make_auto_battle_actions unless @actions.empty?
    end

    # Uses a skill or item, and logs the first ones of the battle, which tells what the computer
    # picks for the character.
    #
    # @param item [RPG::UsableItem] The skill or item.
    def use_item(item)
      super
      Battle.log_action(self, item)
    end

    private

    # Lists the friend's whole team.
    #
    # @return [Array<Game_Battler>] The troop's members, then the characters outside the Frontline.
    def whole_team
      $game_troop.members + Backline.reserve
    end

    # The condition of an automatic skill, seen from the friend's side: 1 an ally of these ids
    # fights along, 2 an enemy of these monster ids is there, which a PvP battle has none of,
    # 3 an ally has one of these states, 4 an enemy has one, 5 the character itself has one.
    #
    # @param type [Integer] The condition.
    # @param ids [Array<Integer>] The actor, monster or state ids it names.
    # @param own [Array<Game_Battler>] The friend's team.
    # @return [Boolean] Whether it holds.
    def auto_skill_condition_met?(type, ids, own)
      case type
      when 1
        own_ids = own.map(&:id)
        ids.any? { |id| own_ids.include?($game_actors.original_id(id)) }
      when 2
        false
      when 3
        ids.any? { |id| own.any? { |member| member.state?(id) } }
      when 4
        ids.any? { |id| $game_party.battle_members.any? { |member| member.state?(id) } }
      when 5
        ids.any? { |id| state?(id) }
      else
        true
      end
    end
  end

  # The friend's team in the game's data: an empty troop of its own for the length of the battle,
  # which the rebuilt characters are put into.
  module Opponents
    # The troop's name.
    TROOP_NAME = "PvP battle"

    # Adds the troop.
    #
    # @return [Integer] Its troop id.
    def self.add_troop
      remove
      @troops_size = $data_troops.size
      troop = RPG::Troop.new
      troop.id = @troops_size
      troop.name = TROOP_NAME
      troop.members = []
      $data_troops[@troops_size] = troop
      @troops_size
    end

    # Takes the troop out of the game's data again, and the pictures drawn for the battle.
    def self.remove
      return unless @troops_size

      $data_troops.slice!(@troops_size..-1)
      @troops_size = nil
      Pictures.clear
    end

    # Rebuilds the friend's characters and stands them side by side at the screen's bottom, where
    # the game stands its own full-size monsters.
    #
    # @param members [Array<MGQ_MpActors::Builds::Member>] The friend's team.
    # @param player [String] The friend's name.
    # @return [Array<Opponent>] The characters, without those that could not be rebuilt.
    def self.build(members, player)
      opponents = members.map do |member|
        begin
          Opponent.new(member, player)
        rescue => e
          MGQ_MpBattlesPvp.log("could not rebuild actor #{member.actor_id}: #{e.class}: #{e.message}")
          nil
        end
      end.compact

      stand(opponents)
    end

    # Stands rebuilt characters side by side at the screen's bottom.
    #
    # @param opponents [Array<Opponent>] The characters, in the troop's order.
    # @return [Array<Opponent>] The same characters.
    def self.stand(opponents)
      opponents.each_with_index do |opponent, index|
        opponent.screen_x = Graphics.width * (2 * index + 1) / (2 * opponents.size)
        opponent.screen_y = Graphics.height
      end
      opponents
    end

    # A monster without rewards, notes or recruiting, for the code that reads a monster's data of
    # anything on the enemy side.
    #
    # A copy of a monster of the game's own, so every field that code reads is present.
    #
    # @param name [String] The character's name.
    # @return [RPG::Enemy] The monster.
    def self.enemy_data(name)
      enemy = $data_enemies.find { |candidate| candidate && !candidate.name.empty? }.dup
      enemy.id = 0
      enemy.name = name
      enemy.exp = 0
      enemy.gold = 0
      MGQ_MpGame.set(enemy, :data_ex, { :no_difficulty => true, :lib_exclude? => true })
      enemy
    end
  end

  # The pictures of the friend's characters: the full picture the Library shows of each, at full
  # size and cut to the character, or the face when there is none.
  #
  # Shrunk, they would turn jagged, since the game has no larger ones and scales without smoothing.
  module Pictures
    # Pixels skipped between two looked at when finding where a picture's character is. Looking at
    # every pixel of a Library picture takes too long in the game.
    SCAN_STEP = 4

    # How much a face is enlarged when it stands in for a picture.
    FACE_ZOOM = 2

    # Faces in a row of a face file.
    FACE_COLUMNS = MGQ_MpCoopSquad::FACE_COLUMNS

    # Rows of faces in a face file.
    FACE_ROWS = 2

    # The picture of one of the friend's characters.
    #
    # @param battler [Game_Battler] A battler of the battle.
    # @return [Bitmap, nil] The picture, nil for every other battler.
    def self.stand_in_for(battler)
      return nil unless battler.is_a?(MGQ_MpBattlesPvp::Opponent)

      @pictures ||= {}
      picture = @pictures[battler.id]
      return picture if picture && !picture.disposed?

      @pictures[battler.id] = library_picture(battler.id) || face(battler.id)
    rescue => e
      MGQ_MpBattlesPvp.log("no picture for actor #{battler.id rescue '?'}: #{e.class}: #{e.message}")
      nil
    end

    # Cuts the character out of the picture the Library shows of it, down to the picture's bottom
    # edge, so it stands where the game stands its own full-size monsters.
    #
    # @param actor_id [Integer] The character.
    # @return [Bitmap, nil] The picture, nil when the Library has none.
    def self.library_picture(actor_id)
      image = defined?(NWConst::Library::ACTOR_IMAGE) && NWConst::Library::ACTOR_IMAGE[actor_id]
      return nil unless image.is_a?(Array)

      sheet = Cache.load_bitmap(image[0], image[1], image[2] || 0)
      area = character_area(sheet)
      area.height = sheet.height - area.y
      bitmap = Bitmap.new(area.width, area.height)
      bitmap.blt(0, 0, sheet, area)
      bitmap
    end

    # Finds where the character is on a picture: the box around its visible pixels.
    #
    # @param sheet [Bitmap] The picture.
    # @return [Rect] The box, the whole picture when nothing on it is visible.
    def self.character_area(sheet)
      left, top, right, bottom = sheet.width, sheet.height, -1, -1

      (0...sheet.height).step(SCAN_STEP) do |y|
        (0...sheet.width).step(SCAN_STEP) do |x|
          next if sheet.get_pixel(x, y).alpha == 0

          left = x if x < left
          right = x if x > right
          top = y if y < top
          bottom = y if y > bottom
        end
      end

      return sheet.rect if right < 0

      left = [left - SCAN_STEP, 0].max
      top = [top - SCAN_STEP, 0].max
      Rect.new(left, top, [right + SCAN_STEP, sheet.width].min - left, [bottom + SCAN_STEP, sheet.height].min - top)
    end

    # Cuts a character's face out of its face file and enlarges it.
    #
    # @param actor_id [Integer] The character.
    # @return [Bitmap, nil] The face, nil without a face file.
    def self.face(actor_id)
      actor = $data_actors[actor_id]
      return nil if actor.face_name.to_s.empty?

      sheet = Cache.face(actor.face_name)
      width = sheet.width / FACE_COLUMNS
      height = sheet.height / FACE_ROWS
      source = Rect.new(actor.face_index % FACE_COLUMNS * width, actor.face_index / FACE_COLUMNS * height, width, height)
      bitmap = Bitmap.new(width * FACE_ZOOM, height * FACE_ZOOM)
      bitmap.stretch_blt(bitmap.rect, sheet, source)
      bitmap
    end

    # Disposes the pictures drawn for the battle.
    def self.clear
      (@pictures || {}).each_value { |bitmap| bitmap.dispose if bitmap && !bitmap.disposed? }
      @pictures = {}
    end
  end

  # The battle against the friend's team, and putting the game back afterwards.
  #
  # The game's own battle replay mode keeps EXP, gold, drops, recruiting and the autosave out, and a
  # snapshot undoes the rest, including the data all saves share.
  module Battle
    # What the map says after the battle, by the game's battle result.
    RESULTS = {
      0 => "You beat %s's team!",
      1 => "You left the PvP battle against %s's team.",
      2 => "%s's team won.",
    }

    # What the map says when the battle could not start.
    FAILED = "The battle could not start, Logs\\Multiplayer InGame.log says why."

    # What the map says after a live battle broke off without a winner.
    BROKEN = "The PvP battle against %s's team broke off, Logs\\Multiplayer InGame.log says why."

    # What the map says after a mirror match, by the game's battle result.
    MIRROR_RESULTS = {
      0 => "You beat your own team!",
      1 => "You left the mirror match.",
      2 => "Your own team won.",
    }

    # Actions of the friend's characters logged per battle, the log holds few lines per session.
    LOGGED_ACTIONS = 12

    # The game's battle results as Multiplayer InGame.log names them.
    RESULT_NAMES = { 0 => "won", 1 => "left", 2 => "lost" }

    class << self
      # The friend whose team is fought.
      #
      # @return [String] The friend whose team is fought.
      attr_reader :opponent
    end

    # Tells whether a PvP battle runs.
    #
    # @return [Boolean] Whether a PvP battle runs, until the map put the game back.
    def self.running?
      @snapshot ? true : false
    end

    # Tells whether the running battle is a mirror match.
    #
    # @return [Boolean] Whether the running battle is a mirror match.
    def self.mirror?
      @mirror ? true : false
    end

    # Starts the battle from the map.
    #
    # @param opponent [String] The friend's name.
    # @param members [Array<MGQ_MpActors::Builds::Member>] The friend's team, the Frontline first.
    # @param mirror [Boolean] Whether it is the player's own team.
    # @param backline [Boolean] Whether both players swap their Backline in, which a team duel never has.
    # @yieldreturn [Array<Opponent>] The characters of the other side, rebuilt by a team duel; without
    #   a block, the friend's team is rebuilt.
    def self.start(opponent, members, mirror, backline = false)
      # A team duel rebuilds the other side itself, and never has the Backline.
      team_duel = block_given?
      backline = false if team_duel
      members = Array(members).first(MGQ_MpCoopSquad::FRONTLINE) unless backline
      @snapshot = Marshal.dump(DataManager.make_save_contents)
      @globals = Marshal.dump(globals)
      @medals = Array(MGQ_MpGame.get($game_temp, :gain_medals)).dup
      @opponent = opponent
      @mirror = mirror
      @failed = false
      @result = nil
      @logged_actions = 0

      troop_id = Opponents.add_troop
      own = $game_party.battle_members + (backline ? $game_party.bench_members : [])
      own.each { |actor| actor.recover_all }
      MGQ_MpBattles.begin(:pvp, backline)
      $game_temp.in_memory_battle = true
      BattleManager.setup(troop_id, true, true)

      everyone = team_duel ? yield : Opponents.build(members, opponent)
      opponents = Opponents.stand(backline ? everyone.first(MGQ_MpCoopSquad::FRONTLINE) : everyone)
      raise "nobody of #{opponent}'s team could be rebuilt" if opponents.empty?

      MGQ_MpGame.set($game_troop, :enemies, opponents)
      Backline.begin(everyone) if backline
      BattleManager.make_escape_ratio if BattleManager.respond_to?(:make_escape_ratio)
      check(everyone)
      MGQ_MpBalancePvp.begin(own + everyone)
      MirrorReport.start(opponents) if mirror
      BattleManager.event_proc = Proc.new { |result| MGQ_MpBattlesPvp::Battle.finished(result) }
      MGQ_MpBattlesSync.record_to_file if mirror
      MGQ_MpBattlesSync.battle_started
      SceneManager.call(Scene_Battle)
      MGQ_MpBattlesPvp.log("started #{mirror ? 'a mirror match' : 'a PvP battle'} against #{opponent}'s team of #{opponents.size}, " \
                           "#{everyone.size - opponents.size} more on the Backline, with #{own.size} of the player's own " \
                           "(#{backline ? 'with' : 'without'} the Backline): #{MGQ_MpBattlesSync.named_list(opponents)}")
    rescue => e
      MGQ_MpBattlesPvp.log("could not start: #{e.class}: #{e.message}")
      @failed = true
      # The map would go on drawing the objects the snapshot replaces, so it is built anew.
      SceneManager.goto(Scene_Map) if running?
      restore
    end

    # Logs where a rebuilt character's stats or rates differ from what the friend's game showed.
    #
    # Both sides measure outside of battle, so only a difference in the rebuild shows.
    #
    # @param opponents [Array<Opponent>] The rebuilt characters, already in the troop.
    def self.check(opponents)
      opponents.each do |opponent|
        differences = opponent.differences
        MGQ_MpBattlesPvp.log("#{opponent.name} differs: #{differences.join(', ')}") unless differences.empty?
      end
    rescue => e
      MGQ_MpBattlesPvp.log("could not check the rebuild: #{e.class}: #{e.message}")
    end

    # Reports whether a battler's action needs a target but finds none.
    #
    # Some skills aim only at one sex or, when they bind, only at Luka, which the game only ever
    # lets monsters use on the player's party, so the battle log would name a target that is not
    # there.
    #
    # @param subject [Game_Battler] The battler about to act.
    # @return [Boolean] Whether the action finds no target.
    def self.targetless?(subject)
      action = subject && subject.current_action
      item = action && action.item
      return false unless item && (item.for_opponent? || item.for_friend?)

      action.make_targets.compact.empty?
    rescue => e
      MGQ_MpBattlesPvp.log("target check failed: #{e.class}: #{e.message}")
      false
    end

    # Orders queued automatic skills by their characters' speed, the fastest first, each character
    # rolling the speed the game rolls for its turn.
    #
    # The game queues the party's before the troop's, so the host's team would always act first.
    #
    # @param actions [Array<Game_Action>] The queued skills, each character's in its own order.
    # @return [Array<Game_Action>] The same skills, a faster character's before a slower one's.
    def self.by_speed(actions)
      speeds = {}
      place = 0
      actions.sort_by do |action|
        owner = action.subject.master_observer
        speeds[owner.object_id] ||= owner.agi + rand(5 + owner.agi / 4)
        [-speeds[owner.object_id], place += 1]
      end
    rescue => e
      MGQ_MpBattlesPvp.log_once(:by_speed, "ordering the automatic skills failed: #{e.class}: #{e.message}")
      actions
    end

    # Logs an action of one of the friend's characters, with its HP, the first LOGGED_ACTIONS of a battle.
    #
    # @param battler [Opponent] The character.
    # @param item [RPG::UsableItem] The skill or item it used.
    def self.log_action(battler, item)
      @logged_actions = (@logged_actions || 0) + 1
      return if @logged_actions > LOGGED_ACTIONS

      MGQ_MpBattlesPvp.log("#{battler.name} used #{item.id} #{item.name} at #{battler.hp}/#{battler.mhp} HP")
    rescue
    end

    # Notes how the battle ended. Called by the game when it does.
    #
    # @param result [Integer] 0 won, 1 left, 2 lost.
    def self.finished(result)
      @result = result
      MGQ_MpBattlesPvp.log("the battle against #{@opponent}'s team ended: #{RESULT_NAMES.fetch(result, result.inspect)}")
    end

    # Puts the game back as it was before the battle and says how it went. Called when the map
    # starts again.
    def self.restore
      @broken = MGQ_MpBattlesSync.broken?
      MGQ_MpBattlesSync.finish
      MGQ_MpBattles.finish
      MGQ_MpBalancePvp.finish
      Backline.finish
      return unless @snapshot

      contents = Marshal.load(@snapshot)
      saved_globals = Marshal.load(@globals)
      @snapshot = nil
      @globals = nil
      DataManager.extract_save_contents(contents)
      self.globals = saved_globals
      $game_temp.in_memory_battle = false
      $game_temp.clear_common_event
      # Medals earned in the battle are gone with the Library's, so their notices are too.
      MGQ_MpGame.set($game_temp, :gain_medals, @medals || [])
      # The game's Retry would start the PvP battle again from its own snapshot.
      MGQ_MpGame.set(BattleManager, :retry_data, nil)
      Opponents.remove
      $game_player.refresh
      $game_map.need_refresh = true
      $game_message.add(result_text)
      # A story's call that waited through the battle would move the player while the map starts.
      MGQ_MpCoopGather.drop_call("a PvP battle put the game back") if defined?(MGQ_MpCoopGather)
      MGQ_MpBattlesPvp.log("put the game back after the battle, on map #{$game_map.map_id} #{$game_player.x},#{$game_player.y}; told the player: #{result_text}")
    rescue => e
      MGQ_MpBattlesPvp.log("could not put the game back: #{e.class}: #{e.message}")
    end

    # Tells how the battle went.
    #
    # @return [String] What the map says about how the battle went.
    def self.result_text
      return FAILED if @failed
      return format(BROKEN, @opponent) if @broken
      return MIRROR_RESULTS.fetch(@result, "The mirror match ended.") if @mirror

      format(RESULTS.fetch(@result, "The PvP battle against %s's team ended."), @opponent)
    end

    # Drops a battle a reset interrupted, and closes the link of a live one, so the friend's game
    # stops waiting. The title screen makes the save's objects anew, but keeps the Library, system
    # switches and affection all saves share, so those are put back.
    def self.forget
      MGQ_MpBattlesPvp.log("a reset interrupted the PvP battle against #{@opponent}'s team: dropped it, the shared data put back") if @snapshot
      MGQ_MpBattlesSync.finish
      self.globals = Marshal.load(@globals) if @globals
    rescue => e
      MGQ_MpBattlesPvp.log("could not put the shared data back after a reset: #{e.class}: #{e.message}")
    ensure
      MGQ_MpBalancePvp.finish
      Backline.finish
      @snapshot = nil
      @globals = nil
      $game_temp.in_memory_battle = false if $game_temp
    end

    # Reads the data all saves share.
    #
    # @return [Array] The data all saves share: the Library, the system switches and the global
    #   system, which holds the affection.
    def self.globals
      [$game_library, $game_system_switches, $game_global_system]
    end

    # Puts back the data all saves share.
    #
    # @param values [Array] The data all saves share, see globals.
    def self.globals=(values)
      $game_library, $game_system_switches, $game_global_system = values
    end

    # Runs a write of the system save with the shared data as it was before the battle, while a
    # PvP battle runs. The game writes it at every scene change and when it closes.
    def self.as_before_for_system
      return yield unless running?

      current = globals
      begin
        self.globals = Marshal.load(@globals)
        yield
      ensure
        self.globals = current
      end
    end

    # Runs a write of a save file with the save and the shared data as they were before the
    # battle, while a PvP battle runs, so nothing of the friend's team or the battle reaches it.
    def self.as_before_for_save
      return yield unless running?

      current = [DataManager.make_save_contents, globals]
      begin
        DataManager.extract_save_contents(Marshal.load(@snapshot))
        self.globals = Marshal.load(@globals)
        yield
      ensure
        DataManager.extract_save_contents(current[0])
        self.globals = current[1]
      end
    end
  end

end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # After the map's update, the key and the exchange. The game checks its own keys there too, only
  # while no event, message or scene change is in the way.
  MGQ_MpHooks.after(Scene_Map, :update_scene, "battles_pvp") { MGQ_MpBattlesPvp.on_map unless scene_changing? }

  # Before the title screen starts, a PvP battle a reset interrupted is forgotten. The title screen
  # interrupts a battle only through a reset, which loads the game data anew.
  MGQ_MpHooks.before(Scene_Title, :start, "battles_pvp") { MGQ_MpBattlesPvp::Battle.forget }

  # After the title screen's update, the last save loads once the player accepted a Discord invite.
  MGQ_MpHooks.after(Scene_Title, :update, "battles_pvp") { MGQ_MpBattlesPvp.on_title unless scene_changing? }

  # Installs the hooks on methods the game's plugins may define anew, as the game starts running.
  MGQ_MpHooks.before(SceneManager.singleton_class, :run, "battles_pvp") { MGQ_MpBattlesPvp.install }
rescue => e
  MGQ_MpBattlesPvp.log("hooks FAILED: #{e.class}: #{e.message}")
end

# Game hooks of this script alone, through core_hooks.rbx.

begin
  # Before the map starts, the game is put back after a PvP battle: the map starts again after one,
  # so it is built from the game as it was before.
  MGQ_MpHooks.before(Scene_Map, :start, "battles_pvp") { MGQ_MpBattlesPvp::Battle.restore if MGQ_MpBattlesPvp::Battle.running? }
rescue => e
  MGQ_MpBattlesPvp.log("map hook FAILED: #{e.class}: #{e.message}")
end

# Other mods, such as a victory screen, read the troop's totals even though the game skips them in
# a PvP battle, and the friend's characters cannot give them.
begin
  [:exp_total, :class_exp_total, :gold_total].select { |name| Game_Troop.method_defined?(name) }.each do |name|
    MGQ_MpHooks.around(Game_Troop, name, "battles_pvp") { |_troop, _args, original| MGQ_MpBattlesPvp::Battle.running? ? 0 : original.call }
  end
  MGQ_MpHooks.around(Game_Troop, :make_drop_items, "battles_pvp") { |_troop, _args, original| MGQ_MpBattlesPvp::Battle.running? ? [] : original.call }
rescue => e
  MGQ_MpBattlesPvp.log("troop hooks FAILED: #{e.class}: #{e.message}")
end

begin
  # The Library's picture for the friend's characters, the original for other battlers.
  MGQ_MpHooks.around(Sprite_Battler, :update_bitmap, "battles_pvp") do |sprite, _args, original|
    stand_in = MGQ_MpBattlesPvp::Pictures.stand_in_for(sprite.battler)
    next original.call unless stand_in

    sprite.bitmap = stand_in if sprite.bitmap != stand_in
  end

  # After a battler's sprite updates, the HP bar of a friend's character, which the game draws only
  # for monsters, and a dead one turned into a grey, see-through silhouette once its defeat flash
  # ends, or at once when it was swapped in dead, which the game draws as not there. The game marks
  # a character dead as the hit lands, before the battle log tells of it, and every sprite effect
  # makes the picture opaque again, so the flash starts the silhouette and its opacity is set every
  # frame.
  MGQ_MpHooks.after(Sprite_Battler, :update, "battles_pvp") do
    next unless @battler.is_a?(MGQ_MpBattlesPvp::Opponent)

    begin
      update_hp_bar if respond_to?(:update_hp_bar, true)
    rescue => e
      MGQ_MpBattlesPvp.log_once(:bar, "HP bar failed: #{e.class}: #{e.message}")
    end

    begin
      dead = @battler.dead?
      @mgq_mp_battles_pvp_defeat_shown = dead && (@mgq_mp_battles_pvp_defeat_shown || @effect_type == :whiten || !@battler_visible)
      silhouette = @mgq_mp_battles_pvp_defeat_shown && @effect_type != :whiten
      if silhouette != @mgq_mp_battles_pvp_silhouette
        @mgq_mp_battles_pvp_silhouette = silhouette
        self.tone = Tone.new(0, 0, 0, silhouette ? MGQ_MpBattlesPvp::Opponent::SILHOUETTE_GRAY : 0)
        self.opacity = 255 unless silhouette
      end
      self.opacity = MGQ_MpBattlesPvp::Opponent::SILHOUETTE_OPACITY if silhouette
    rescue => e
      MGQ_MpBattlesPvp.log_once(:silhouette, "silhouette failed: #{e.class}: #{e.message}")
    end
  end
rescue => e
  MGQ_MpBattlesPvp.log("battler picture hooks FAILED: #{e.class}: #{e.message}")
end

# Nothing of a PvP battle reaches the disk: while one runs, every save write gets the save and the
# shared data as they were before it. The game writes the system save at every scene change and
# when it closes, so a battle's end would write the battle's changes before the map puts the game
# back.
begin
  MGQ_MpHooks.around(DataManager.singleton_class, :save_system, "battles_pvp") do |_manager, _args, original|
    MGQ_MpBattlesPvp::Battle.as_before_for_system { original.call }
  end
  [:save_game_without_rescue, :auto_save_game_without_rescue, :save_game_backup_without_rescue].select { |name| DataManager.singleton_class.method_defined?(name) }.each do |name|
    MGQ_MpHooks.around(DataManager.singleton_class, name, "battles_pvp") do |_manager, _args, original|
      MGQ_MpBattlesPvp::Battle.as_before_for_save { original.call }
    end
  end
rescue => e
  MGQ_MpBattlesPvp.log("save hooks FAILED: #{e.class}: #{e.message}")
end

begin
  # The automatic skills that fire, picked from the friend's side for the friend's characters.
  MGQ_MpHooks.around(BattleManager.singleton_class, :_auto_skill_per, "battles_pvp") do |_manager, args, original|
    args[1].is_a?(MGQ_MpBattlesPvp::Opponent) ? args[1].firing_auto_skills(args[0]) : original.call
  end

  # After the automatic skills of a battle's start, a turn's start or a turn's end are queued, in a
  # PvP battle the faster character's go first.
  MGQ_MpHooks.after(BattleManager.singleton_class, :set_auto_skill, "battles_pvp") do
    @action_game_masters = MGQ_MpBattlesPvp::Battle.by_speed(@action_game_masters) if MGQ_MpBattlesPvp::Battle.running?
  end
rescue => e
  MGQ_MpBattlesPvp.log("automatic skill hooks FAILED: #{e.class}: #{e.message}")
end

# Discord shows whose team the player fights, through the Discord mod's bridge when it is installed.
begin
  MGQ_Discord::Bridge.add_status { |scene| MGQ_MpBattlesPvp.status_fields(scene) } if MGQ_Multiplayer::Discord.available?
rescue => e
  MGQ_MpBattlesPvp.log("status source FAILED: #{e.class}: #{e.message}")
end
