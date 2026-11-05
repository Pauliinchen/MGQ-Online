#----------------------------------------------------------------
#  battles_battlers.rbx
#
#  Changelog:
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# The one factory of the battlers the game's own setup never makes: another player's character in
# a co-op battle's party, the enemies of a troop another game sent or set up after the battle's
# start, and the other side's Backline in a PvP battle. Each is made as the game makes its own
# (Game_Actor#setup through Game_MpActor, the troop's own kind of enemy) and given the game's own
# battle start (Game_Battler#on_battle_start) where the game's start never reaches it, as the rules
# in C# decide (topic battlers.plan, MGQOnline.Game's BattlerSetup), once in each battle. A guest,
# whose battle the host's stream plays, starts its own party and troop through the game's unit
# starts, so every battler of its battle has what the game's start gives.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpBattlers
  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "battlers"

  # The DLL's topic that plans a battler, see plan.
  PLAN_TOPIC = "battlers.plan"

  # Builds another player's character for the battle, with the HP and MP it has in their game, a
  # fallen one fallen, then starts it as the game starts its own.
  #
  # @param member [MGQ_MpActors::Builds::Member] The character's build.
  # @param name [String] Its owner's name.
  # @param seat [Integer] Its owner's world seat.
  # @param place [Integer] Its place among its owner's characters.
  # @param vitals [Array, nil] Its HP and MP, none for a character at full HP and MP.
  # @yieldparam ally [Game_MpAlly] The character before its start, as its owner's game measured it.
  # @return [Game_MpAlly, nil] The character, nil when it could not be built.
  def self.ally(member, name, seat, place, vitals)
    ally = Game_MpAlly.new(member, name, seat, place)
    order = plan("ally", "vitals" => vitals)
    ally.hp = order["hp"] if order["hp"]
    ally.mp = order["mp"] if order["mp"]
    yield ally if block_given?
    ally.on_battle_start if order["start"]
    ally
  rescue => e
    log("building #{name}'s character at place #{place} failed: #{e.class}: #{e.message}")
    ally
  end

  # Fills the troop with another game's enemies in place of this game's own, as the game's troop
  # setup fills it: each at its place, lettered anew, the fallen laid down, in the Library, its
  # boss raised to its tier, and drawn anew.
  #
  # @param scene [Scene_Battle] The battle.
  # @param entries [Array<Array>] The enemies: each one's id, screen x and y, and mark (see
  #   MGQ_MpBattlesHotjoin.mark).
  # @return [Array<Game_Enemy>] The enemies, none when they could not be built.
  def self.fill_troop(scene, entries)
    built = entries.each_with_index.map { |entry, index| enemy(index, entry) }
    MGQ_MpGame.set($game_troop, :enemies, built.map(&:first))
    # The game counts each name's enemies for their letters, so the count starts over as in setup.
    MGQ_MpGame.set($game_troop, :names_count, {})
    MGQ_MpRaidPool.rescale if defined?(MGQ_MpRaidPool)
    MGQ_MpRaidTiers.rescale if defined?(MGQ_MpRaidTiers)
    settle(scene, built)
  rescue => e
    log("building the host's troop of #{Array(entries).size} enemies failed: #{e.class}: #{e.message}")
    []
  end

  # Adds enemies after the troop's own, as fill_troop builds them.
  #
  # @param scene [Scene_Battle] The battle.
  # @param entries [Array<Array>] The enemies, see fill_troop.
  # @return [Array<Game_Enemy>] The enemies added, none when they could not be built.
  def self.add_to_troop(scene, entries)
    enemies = MGQ_MpGame.get($game_troop, :enemies)
    built = entries.map do |entry|
      pair = enemy(enemies.size, entry)
      enemies << pair[0]
      pair
    end
    settle(scene, built)
  rescue => e
    log("adding #{Array(entries).size} enemies to the troop failed: #{e.class}: #{e.message}")
    []
  end

  # Starts a guest's battle, whose host's stream stands in for the rest of the game's battle start:
  # the game's own start of the player's party and of the troop, which marks the party as fighting
  # and gives every battler its counters, its start states and cleared actions, and the troop's
  # enemies entered in the Library, as the game's start enters the host's.
  #
  # The game's start of the troop reads a random enemy's defeat scene, so an empty troop, whose
  # enemies this game lacks, is left to the enemies built from the host's.
  def self.start_guest
    $game_party.on_battle_start
    unless $game_troop.members.empty?
      $game_troop.on_battle_start
      discover($game_troop.members)
    end
    log("started the guest's battle as the game starts its party and troop: #{$game_party.members.size} characters, #{$game_troop.members.size} enemies")
  rescue => e
    # Skills usable only in battle check the mark, and the battle's end clears it.
    MGQ_MpGame.set($game_party, :in_battle, true)
    log("starting the guest's battle failed, the party is marked as fighting: #{e.class}: #{e.message}")
  end

  # Starts the enemies of a troop set up anew in a running battle, such as the rival's troop a
  # guest follows its host to, which the game's start of the troop never reached: each as the
  # rules in C# plan it.
  def self.start_troop
    started = $game_troop.members.select { |enemy| plan("enemy", {})["start"] }
    started.each(&:on_battle_start)
    log("started #{started.size} of the troop's #{$game_troop.members.size} enemies set up after the battle's start") unless started.empty?
  rescue => e
    log("starting the troop set up anew failed: #{e.class}: #{e.message}")
  end

  # Starts the other side's characters outside its Frontline in a PvP battle with the Backline,
  # which the game's start of the troop never reaches, as the game starts the troop's: each as the
  # rules in C# plan it. A swap later moves them as they are.
  #
  # @param battlers [Array<Game_Battler>] The characters.
  def self.start_reserve(battlers)
    started = Array(battlers).select { |battler| plan("reserve", {})["start"] }
    started.each(&:on_battle_start)
    log("started the other side's Backline as the game starts the troop: #{started.size} characters") unless started.empty?
  rescue => e
    log("starting the other side's Backline failed: #{e.class}: #{e.message}")
  end

  # Runs the game's battle start for a guest's battle the host's party never formed, which the
  # guest takes over as its own: everything but the start of the party and the troop, which the
  # guest's start already gave them.
  def self.start_taken_over
    @units_started = started?
    BattleManager.battle_start
  ensure
    @units_started = false
  end

  # Tells whether the game's start of the party and the troop stands aside, see start_taken_over.
  #
  # @return [Boolean] Whether it does.
  def self.units_started?
    @units_started ? true : false
  end

  # Tells whether the game's battle start already ran in this game, which then reaches no battler
  # built after it.
  #
  # @return [Boolean] Whether it ran.
  def self.started?
    $game_party.in_battle ? true : false
  end

  # Builds an enemy of the troop as the game's troop setup builds one: of the kind the troop's
  # battle needs, such as a Challenge Battle's enemy that takes damage without falling, at its
  # place, hidden when the host hides it.
  #
  # @param index [Integer] Its place in the troop.
  # @param entry [Array] Its id, screen x and y, and mark.
  # @return [Array(Game_Enemy, Hash)] The enemy and its plan.
  def self.enemy(index, entry)
    id, x, y, mark = entry
    kind = $game_troop.respond_to?(:enemy_class) ? $game_troop.enemy_class : Game_Enemy
    enemy = kind.new(index, id.to_i)
    enemy.screen_x = x.to_i
    enemy.screen_y = y.to_i
    order = plan("enemy", "mark" => mark)
    enemy.hide if order["hide"]
    enemy.on_battle_start if order["start"]
    [enemy, order]
  end

  # Settles the enemies built: letters them as the game's setup does, lays the fallen down after,
  # since the game letters only the living and the host's fallen got theirs before they fell,
  # enters them in the Library as the game's start does, and draws them.
  #
  # @param scene [Scene_Battle] The battle.
  # @param built [Array<Array(Game_Enemy, Hash)>] The enemies and their plans.
  # @return [Array<Game_Enemy>] The enemies.
  def self.settle(scene, built)
    enemies = built.map(&:first)
    MGQ_MpGame.call($game_troop, :make_unique_names)
    built.each { |enemy, order| lay_down(enemy) if order["lay_down"] }
    discover(enemies)
    redraw(scene)
    enemies
  end

  # Gives an enemy the death it has on the host, before its sprite is made, so it stands
  # invisible as the fallen do and comes back should the host's stream revive it.
  #
  # @param enemy [Game_Enemy] The enemy.
  def self.lay_down(enemy)
    death = enemy.respond_to?(:death_state_id) ? enemy.death_state_id : 1
    MGQ_MpBattlesSync::Playback.values(enemy, 0, MGQ_MpGame.get(enemy, :mp).to_i, MGQ_MpGame.get(enemy, :tp).to_i,
                                       [death], [0], MGQ_MpGame.get(enemy, :buffs), 0)
  rescue => e
    log("laying a fallen enemy down failed: #{e.class}: #{e.message}")
  end

  # Enters enemies in the game's monster library, as the game's battle start does for the troop's
  # own.
  #
  # @param enemies [Array<Game_Enemy>] The enemies.
  def self.discover(enemies)
    library = $game_library
    return unless library && library.respond_to?(:enemy) && library.enemy.respond_to?(:set_discovery)

    library.enemy.set_discovery(enemies.map(&:enemy_id))
  rescue => e
    log("entering the enemies in the library failed: #{e.class}: #{e.message}")
  end

  # Draws the troop's enemies anew in the battle.
  #
  # @param scene [Scene_Battle] The battle.
  def self.redraw(scene)
    spriteset = MGQ_MpGame.get(scene, :spriteset)
    return unless spriteset

    spriteset.dispose_enemies
    spriteset.create_enemies
  end

  # Asks the rules in C# how to build a battler.
  #
  # @param kind [String] "ally", "enemy" or "reserve".
  # @param fields [Hash] "vitals" of an ally, "mark" of an enemy.
  # @return [Hash] "hp", "mp", "start", "hide" and "lay_down"; while the DLL does not answer, only
  #   the start of a battler the game's start never reaches.
  def self.plan(kind, fields)
    answer = MGQ_Multiplayer::Bridge.call(PLAN_TOPIC, { "kind" => kind, "started" => started? }.merge(fields))
    return answer if answer.is_a?(Hash)

    always = kind != "enemy"
    log_once([:plan, kind], "the DLL did not plan a battler of kind #{kind}, which is built #{always ? 'with' : 'without'} its start")
    { "start" => always }
  end

  # Installs the hooks on methods the game's plugins may define anew. Called once the first scene
  # starts.
  def self.install
    return if @installed

    @installed = true
    [Game_Party, Game_Troop].each do |unit|
      MGQ_MpHooks.around(unit, :on_battle_start, "battles_battlers") do |_unit, _args, original|
        MGQ_MpBattlers.units_started? ? nil : original.call
      end
    end
  rescue => e
    log("battler hooks FAILED: #{e.class}: #{e.message}")
  end
end

# Game hooks, through core_hooks.rbx.

begin
  MGQ_MpHooks.before(SceneManager.singleton_class, :run, "battles_battlers") { MGQ_MpBattlers.install }
rescue => e
  MGQ_MpBattlers.log("SceneManager hook FAILED: #{e.class}: #{e.message}")
end
