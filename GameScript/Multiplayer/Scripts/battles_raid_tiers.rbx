#----------------------------------------------------------------
#  battles_raid_tiers.rbx
#
#  Changelog:
#      Paulinchen  2026-11-05: Asked the DLL which battles fight at their tier, why not and whether a bar shows, in place of deciding here
#                            - Kept and read its switch in Player.ini as true or false, which the DLL writes as 1 or 0
#                            - Took the relay's raid bosses as the flag the DLL reads
#                            - Told and read the invite's tier as true or false
#      Paulinchen  2026-10-30: Raised the stats through the pools' wrap with the factors kept per battle
#      Paulinchen  2026-10-13: Created
#
#----------------------------------------------------------------

# The raid bosses outside Raid Worlds: in a Classic world whose creator ticked Raid Bosses, and in
# single player while the player turned Raid Bosses on in the Mod Config (MGQ Online SP), each story
# boss fights with the stat factors of its tier (MGQ_MpRaidBosses.tiers), in every battle anew: no
# relay keeps its HP and nothing regenerates. The same fights count as in a Raid World, by the one
# refusal chain of the DLL's rules (MGQOnline.Game's BossRules, topic raid.kind): the last phase of
# a boss the player's story has not beaten, started by its map event, never a Hades rematch, a
# Colosseum battle or a Great Decision fight. ui_raid_bar.rbx draws its bars.
#
# In a co-op battle the host decides and its invite carries INVITE_FIELD, so every guest raises the
# same enemies. A Raid World never reaches this script's battles: active? and kind_of refuse there.
#
# It must work without any connection: the DLL answers in single player too.
module MGQ_MpRaidTiers
  # The setting in Player.ini that turns the raid bosses on in single player with 1.
  SETTING = "sp_raid_bosses"

  # The key of the Mod Config row that turns the raid bosses on and off in single player, which
  # ui_single_player.rbx adds.
  OPTION = :mp_sp_raid_bosses

  # The name of the Mod Config row that turns the raid bosses on and off in single player.
  OPTION_NAME = "Raid Bosses"

  # The help of the Mod Config row that turns the raid bosses on and off in single player.
  OPTION_HELP = "On: outside a world, story bosses fight as raid bosses of their tier, with far more HP\n" \
                "and defense, and show an HP bar. A Classic world decides this for itself."

  # The field an invite, or a request to lead, adds with 1 when its battle fights its boss at its
  # tier, see invite_fields.
  INVITE_FIELD = "tiers"

  # A battle whose boss fights at its tier.
  #
  # @!attribute troop [Integer] The troop.
  # @!attribute own [Integer] How many enemies the troop's setup made, which come first in the troop.
  # @!attribute tier [Integer] The boss's tier, see MGQ_MpRaidBosses.tiers.
  Fight = Struct.new(:troop, :own, :tier)

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "raid tiers"

  # Forgets every battle, as at the title screen.
  def self.forget
    @fight = nil
    @lost = nil
    @invited = nil
    @at_command = false
    @retrying = false
    MGQ_MpRaidPool::Stats.forget
  end

  # Reports whether the story bosses fight as raid bosses now: never in a Raid World, whose pools
  # are battles_raid_pool.rbx's; in a Classic world as its creator set it; else as the player set it
  # for single player.
  #
  # @return [Boolean] Whether they do.
  def self.active?
    return false if MGQ_MpCoop::Scope.raid?

    MGQ_MpOverworldSync.in_world? ? MGQ_MpWorld.raid_bosses? : single_player?
  rescue
    false
  end

  # Reports whether the player turned the raid bosses on for single player, as Player.ini keeps it,
  # off until they turn it on.
  #
  # @return [Boolean] Whether they did.
  def self.single_player?
    @single_player = MGQ_Multiplayer::Player.setting(SETTING) == true if @single_player.nil?
    @single_player
  end

  # Turns the raid bosses on or off for single player and keeps the choice in Player.ini.
  #
  # @param on [Boolean] Whether they are on.
  def self.choose(on)
    @single_player = on ? true : false
    MGQ_Multiplayer::Player.store(SETTING, @single_player)
    log("raid bosses in single player are #{@single_player ? 'on' : 'off'}")
  rescue => e
    log("keeping whether raid bosses are on in single player FAILED: #{e.class}: #{e.message}")
  end

  # Tells the battle whose boss fights at its tier now.
  #
  # @return [Fight, nil] The battle, nil for none.
  def self.fight
    @fight
  end

  # Runs the map's interpreter, noting that its commands run, which are the story's.
  #
  # @return [Object] What the block returns.
  def self.in_map
    was = @in_map
    @in_map = true
    yield
  ensure
    @in_map = was
  end

  # Runs an event's battle command, noting that the battle set up next is the event's.
  #
  # @return [Object] What the block returns.
  def self.at_command
    @at_command = true
    yield
  ensure
    @at_command = false
  end

  # Runs the game's retry of a lost battle, noting that the battle set up next is a retry.
  #
  # @return [Object] What the block returns.
  def self.retrying
    @retrying = true
    yield
  ensure
    @retrying = false
  end

  # Asks the DLL how a battle about to be set up, or just set up, fights its boss at its tier.
  #
  # @param troop_id [Integer, String] The battle's troop.
  # @return [Hash] "kind" ("retry", "invited", "event" or nil, always nil in a Raid World) and "why"
  #   an event's story boss battle keeps its boss as the game has it; empty while the DLL does not answer.
  def self.ask(troop_id)
    troop = troop_id.to_i
    answer = MGQ_Multiplayer::Bridge.call(MGQ_MpRaidPool::KIND_TOPIC, "troop" => troop, "mode" => "tiers", "facts" => MGQ_MpRaidBosses.facts,
                                          "active" => active?, "raid" => MGQ_MpCoop::Scope.raid? ? true : false, "at_command" => @at_command ? true : false,
                                          "in_map" => @in_map ? true : false, "event" => @at_command && @in_map && $game_map.interpreter.event_id > 0 ? true : false,
                                          "invited" => @invited ? [@invited, false] : nil, "retry" => @retrying && @lost ? [@lost.troop, false] : nil)
    answer.is_a?(Hash) ? answer : {}
  end

  # Tells how a battle about to be set up, or just set up, fights its boss at its tier.
  #
  # @param troop_id [Integer, String] The battle's troop.
  # @return [Symbol, nil] :retry for the game's retry of such a battle that was lost, :invited for
  #   one a host's invite or a member's request marked, :event for a story boss's battle its map
  #   event started; nil for none, always in a Raid World.
  def self.kind_of(troop_id)
    kind = ask(troop_id)["kind"]
    kind ? kind.to_sym : nil
  end

  # Decides whether the battle just set up fights its boss at its tier, and raises its enemies.
  # Called after BattleManager.setup.
  #
  # @param troop_id [Integer] The battle's troop.
  def self.set_up(troop_id)
    troop = troop_id.to_i
    answer = ask(troop)
    kind = answer["kind"] ? answer["kind"].to_sym : nil
    lost = @lost
    @at_command = false
    @invited = nil
    @fight = nil
    @lost = nil
    return answer["why"] ? log("troop #{troop} keeps its boss as the game has it: #{answer['why']}") : nil unless kind

    own = kind == :retry ? lost.own : MGQ_MpRaidPool.own_count(troop)
    @fight = Fight.new(troop, own, MGQ_MpRaidBosses.tier(troop))
    scale(@fight)
    log("battle against troop #{troop} (#{kind}) fights its boss at tier #{@fight.tier}: " \
        "#{MGQ_MpRaidPool.own_enemies(own).compact.map { |enemy| "#{enemy.name} #{enemy.hp}/#{enemy.mhp}" }.join(', ')}")
  rescue => e
    @fight = nil
    log("deciding on troop #{troop_id} failed: #{e.class}: #{e.message}")
  end

  # Gives a battle's own enemies their tier's stats (see MGQ_MpRaidPool::Stats), each new one
  # keeping the share of its max HP it had.
  #
  # @param fight [Fight] The battle.
  def self.scale(fight)
    MGQ_MpRaidPool::Stats.scale(MGQ_MpRaidPool.own_enemies(fight.own).compact, fight.tier)
  end

  # Gives the enemies of a troop a guest built anew from its host's their tier's stats before the
  # host's HP reaches them, which their own max HP would cut. Called by
  # MGQ_MpBattlesCoop.take_troop.
  def self.rescale
    fight = @fight
    scale(fight) if fight
  rescue => e
    log("raising the troop built anew failed: #{e.class}: #{e.message}")
  end

  # Ends the battle whose boss fights at its tier, keeping a lost one for the game's retry. Called
  # as BattleManager.battle_end starts.
  #
  # @param result [Integer] The game's result: 0 won, 1 escaped, 2 lost.
  def self.battle_ended(result)
    fight = @fight
    @fight = nil
    return unless fight

    @lost = fight if result == 2
    log("battle against troop #{fight.troop} at tier #{fight.tier} ended #{{ 0 => 'won', 1 => 'escaped', 2 => 'lost' }.fetch(result, result.inspect)}")
  end

  # Writes the field an invite to the player's battle, or a request to the party's leader to lead
  # it, adds when its boss fights at its tier, so the other games raise the same enemies.
  #
  # Only in the battle scene does the decision taken count: there a member hosts its battle at its
  # start once the party's leader would not lead it, while a battle set up on the map comes before
  # set_up, where a fight a refused lead left behind would mislabel it.
  #
  # @param troop_id [Integer] The troop of the battle just set up, before set_up decides on it,
  #   since battles_coop.rbx's hook on BattleManager.setup runs first; or of the battle running.
  # @return [Hash] The field, none for a battle whose boss keeps the game's stats.
  def self.invite_fields(troop_id)
    fight = @fight
    running = fight && fight.troop == troop_id.to_i && SceneManager.scene.is_a?(Scene_Battle)
    tiered = running || kind_of(troop_id)
    tiered ? { INVITE_FIELD => true } : {}
  rescue => e
    log("writing the invite's tier failed: #{e.class}: #{e.message}")
    {}
  end

  # Notes whether the battle of an invite the player accepts, or of a member's request the player
  # leads, fights its boss at its tier, as its INVITE_FIELD says. Called by MGQ_MpBattlesCoop.accept
  # and lead before they set the battle up.
  #
  # @param message [Hash] The invite or the request: "troop" and INVITE_FIELD.
  def self.note_invite(message)
    @invited = !MGQ_MpCoop::Scope.raid? && message[INVITE_FIELD] == true ? message["troop"].to_i : nil
  end

  # Takes the relay's word that the open Classic world's creator or an admin changed whether its
  # story bosses fight as raid bosses, from the next boss battle on.
  #
  # @param message [Hash] The push: MGQ_MpOverworldSync::RAID_BOSSES_FIELD, true or false as the DLL
  #   reads it, marked :relay by overworld_sync.rbx.
  def self.pushed(message)
    return log("ignored a raid bosses push not from the relay") unless message[:relay]

    on = message[MGQ_MpOverworldSync::RAID_BOSSES_FIELD] == true
    return if on == MGQ_MpWorld.raid_bosses?
    return log("ignored the relay's raid bosses outside a Classic world") unless MGQ_MpWorld.take_raid_bosses(on)

    log("the relay tells the world's raid bosses are #{on ? 'on' : 'off'} now")
    MGQ_MpOverworldSync.notice(on ? "The world's story bosses fight as raid bosses now." : "The world's story bosses fight as usual now.")
  rescue => e
    log("taking the relay's raid bosses failed: #{e.class}: #{e.message}")
  end

  # Installs the battle hooks on methods the game's plugins may define anew, as the game starts
  # running; the stats are battles_raid_pool.rbx's wrap.
  def self.install
    MGQ_MpHooks.before(BattleManager.singleton_class, :battle_end, "battles_raid_tiers") { |result| MGQ_MpRaidTiers.battle_ended(result) }

    return unless BattleManager.respond_to?(:retry_battle)

    MGQ_MpHooks.around(BattleManager.singleton_class, :retry_battle, "battles_raid_tiers") do |_manager, _args, original|
      MGQ_MpRaidTiers.retrying { original.call }
    end
  rescue => e
    log("battle hooks FAILED: #{e.class}: #{e.message}")
  end

  forget
end

# The relay's push, through overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.route(MGQ_MpOverworldSync::RAID_BOSSES_FIELD) { |_peer, message| MGQ_MpRaidTiers.pushed(message) }
rescue => e
  MGQ_MpRaidTiers.log("push route FAILED: #{e.class}: #{e.message}")
end

# Game hooks, through core_hooks.rbx.

begin
  MGQ_MpHooks.before(SceneManager.singleton_class, :run, "battles_raid_tiers") { MGQ_MpRaidTiers.install }
  MGQ_MpHooks.before(Scene_Title, :start, "battles_raid_tiers") { MGQ_MpRaidTiers.forget }
  MGQ_MpHooks.after(BattleManager.singleton_class, :setup, "battles_raid_tiers") { |troop_id, *_rest| MGQ_MpRaidTiers.set_up(troop_id) }
  MGQ_MpHooks.around(Game_Map, :update_interpreter, "battles_raid_tiers") { |_map, _args, original| MGQ_MpRaidTiers.in_map { original.call } }
  MGQ_MpHooks.around(Game_Interpreter, :command_301, "battles_raid_tiers") { |_interpreter, _args, original| MGQ_MpRaidTiers.at_command { original.call } }
rescue => e
  MGQ_MpRaidTiers.log("hooks FAILED: #{e.class}: #{e.message}")
end
