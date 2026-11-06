#----------------------------------------------------------------
#  coop_flow.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Erased the pictures a loaded world save shows at once while no event runs
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# The one guard of the game's flow. Wherever the mod cuts, skips, moves or ends a game event, the
# game's own flow cannot put back what it set: a dark screen, a tint, pictures, the player's hidden
# character or followers, a temporary party, the bans and a forced route. This script reads the
# state before and now and the commands the event would still run, the DLL decides what to put back
# (MGQOnline.Game's FlowGuard, behind the topics of FlowTopics), and this script puts it back.
#
# The places the mod interrupts call it: coop_events.rbx as it ends an event early (cut) or keeps
# one from starting (skipped), coop_gather.rbx and world_story.rbx as they move the player away
# (leave), coop_scene.rbx as a watched scene ends for the player (watched), world_gates.rbx as it
# keeps the player from a move (refused), battles_pvp.rbx as a duel puts the game back from its
# snapshot (restored) and battles_raid_freeze.rbx as a resume puts a scene back (resuming). It also
# keeps the player's own scene: the state the map's events start from, from the first, or from a
# loaded save, until the player stands free with nothing of it left, and the pictures its events
# show. A screen left dark while nothing of the game's flow runs, which no place saw, comes back.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpFlowGuard
  # The DLL's topic of what to put back, see FlowTopics.PlanTopic.
  PLAN_TOPIC = "flow.plan"

  # The DLL's topic of whether the player's own scene still stands, see FlowTopics.StandsTopic.
  STANDS_TOPIC = "flow.stands"

  # How often a plan hands over the common events the DLL names it needs, at most: one they call
  # may call more.
  MAX_ROUNDS = 8

  # Events kept from starting whose plan is kept, at most, before they are all forgotten.
  MAX_KEPT_SKIPS = 200

  # The game's bans of $game_system, by the names the DLL gives them.
  SYSTEM_BANS = { "menu" => :menu_disabled, "save" => :save_disabled, "encounter" => :encounter_disabled, "formation" => :formation_disabled }

  # The DLL's name of the escape spell's ban, a switch of the place (MGQ_MpStoryState::ESCAPE_BAN).
  ESCAPE_BAN = "escape"

  # The brightness of a screen nothing dims.
  FULL_BRIGHTNESS = 255

  # The command that calls a common event, whose commands a plan hands over.
  CALL_COMMON = 117

  # The commands of a script's lines, the only ones whose text the DLL reads.
  SCRIPT_CODES = [355, 655]

  # The player's own scene, nil while none runs or stands: :start, its state as it began, see
  # state_now; :run, the state as its latest event began; :owned, the numbers of the pictures its
  # running event showed and has not erased; :stood, what the DLL last answered of whether it
  # stands, with the parts of the state it was asked for, see stands?.
  @scene = nil

  # Whether a save was loaded whose scene the guard has not taken yet, see settle_load.
  @loaded = false

  # The event the map's interpreter set up last, for the log, since the game clears its id once
  # the event ended.
  @last_event = 0

  # The events kept from starting whose plan was asked, by their list and the state then.
  @skips = {}

  # The commands of the common events handed to the DLL, by id, while the game's common events stay
  # the same.
  @commons = {}

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "flow guard"

  # Notes the state an event of the map's interpreter starts from, opening the player's own scene
  # with it unless one runs already. Called after an interpreter's setup.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  def self.started(interpreter)
    return unless $game_map && interpreter.equal?($game_map.interpreter)

    settle_load
    @last_event = MGQ_MpGame.get(interpreter, :event_id).to_i
    now = state_now
    @scene ||= { :start => now, :owned => [] }
    @scene[:run] = now
  rescue => e
    log_once(:started, "noting the player's own scene failed: #{e.class}: #{e.message}")
  end

  # Notes a picture the running event of the player's own scene shows or erases on the map's
  # screen. Called after a picture's show and erase.
  #
  # @param picture [Game_Picture] The picture.
  # @param name [Symbol] :show or :erase.
  def self.picture(picture, name)
    return unless @scene && MGQ_MpCoopScene.map_turn? && $game_map.screen.pictures[picture.number].equal?(picture)

    if name == :show
      @scene[:owned] |= [picture.number]
    else
      @scene[:owned].delete(picture.number)
    end
  rescue => e
    log_once(:picture, "noting a picture of the player's own scene failed: #{e.class}: #{e.message}")
  end

  # Closes the player's own scene once none of its events runs and the DLL finds nothing of it
  # stands; the pictures an event that ran to its end showed are no longer that event's to take
  # along when the mod cuts the next. Brings back a screen left dark, see bring_light. Called after
  # the map's update.
  def self.update
    settle_load
    bring_light
    return unless @scene && !$game_map.interpreter.running?

    @scene[:owned] = []
    @scene = nil unless stands?
  rescue => e
    log_once(:update, "following the player's own scene failed: #{e.class}: #{e.message}")
  end

  # Asks the DLL whether the player's own scene still stands, again only once what it reads of the
  # state changed: the temporary party, the hidden character, the followers and the pictures.
  #
  # @return [Boolean] Whether it stands.
  def self.stands?
    key = [temp_party?, $game_player.transparent ? true : false, $game_player.followers.visible ? true : false, pictures_shown($game_map.screen)]
    return @scene[:stood][1] if @scene[:stood] && @scene[:stood][0] == key

    answer = MGQ_Multiplayer::Bridge.call(STANDS_TOPIC, "start" => @scene[:start], "now" => state_now) == true
    @scene[:stood] = [key, answer]
    answer
  end

  # Takes the player's own scene a loaded save stopped, once the game runs on from it: the state at
  # the load is where it began, without the pictures the save shows, which a scene the save
  # stopped left. In a world they go at once while nothing of the game's flow runs, else once the
  # mod moves the player away. None is taken while the save shows no picture.
  def self.settle_load
    return unless @loaded

    @loaded = false
    now = state_now
    return if now["pictures"].empty?

    start = now.merge("pictures" => [])
    @scene = { :start => start, :run => start, :owned => [] }
    return leave("the loaded world save shows picture(s) #{now['pictures'].join(', ')} on map #{now['map']} with no event running") if world_open? && free?

    log("the loaded save shows picture(s) #{now['pictures'].join(', ')} on map #{now['map']} with no scene the guard saw begin: " \
        "they go once the mod moves the player away, unless the game erases them first")
  end

  # Brings back a screen left dark while the player stands free and nothing of the game's flow
  # runs that would light it: no event of the map's, parallel or common, no watched scene and no
  # transfer. Logged once per map and event, since only a cause none of the places that call the
  # guard saw leaves such a screen.
  def self.bring_light
    screen = $game_map.screen
    return unless screen.brightness.to_i < FULL_BRIGHTNESS && MGQ_MpGame.get(screen, :fadein_duration).to_i == 0
    return unless SceneManager.scene.is_a?(Scene_Map) && free?

    done = put_back("free", {})
    return if done.empty?

    log_once([:dark, $game_map.map_id, @last_event],
             "the screen stood dark on map #{$game_map.map_id} with nothing of the game's flow running, after event #{@last_event} " \
             "of the map's interpreter: #{done.join(', ')}")
  rescue => e
    log_once(:bring_light, "bringing back a dark screen failed: #{e.class}: #{e.message}")
  end

  # Reports whether the player stands free with nothing of the game's flow running: no event of the
  # map's interpreter, no parallel event or common event, no message, no transfer and no watched
  # scene waiting to be put back.
  #
  # @return [Boolean] Whether they do.
  def self.free?
    return false if $game_map.interpreter.running? || $game_player.transfer? || $game_message.busy? || MGQ_MpCoopScene.pending?

    holders = $game_map.events.values + Array(MGQ_MpGame.get($game_map, :common_events))
    holders.none? do |holder|
      interpreter = MGQ_MpGame.get(holder, :interpreter)
      interpreter && interpreter.running?
    end
  end

  # Reports whether a world is open, whose saves the player loads.
  #
  # @return [Boolean] Whether one is.
  def self.world_open?
    defined?(MGQ_MpWorld) && MGQ_MpWorld.open? ? true : false
  end

  # Reports whether the player's own scene is under way.
  #
  # @return [Boolean] Whether it is.
  def self.open?
    @scene ? true : false
  end

  # Puts back what an event of the player's own the mod ends early would have put back itself, from
  # the state it began from and its commands from where it ends. The scene stays open, as what came
  # before that event still stands.
  #
  # @param list [Array<RPG::EventCommand>] The event's commands.
  # @param index [Integer] Where it ends: the command that does not run.
  # @param reason [String] Why it ends, for the log.
  def self.cut(list, index, reason)
    run = @scene ? @scene[:run] : nil
    owned = @scene ? @scene[:owned] : []
    done = put_back("cut", "before" => run, "owned" => owned, "rest" => rows_of(list[index..-1] || []))
    @scene[:owned] = [] if @scene
    log("put back what the player's own event would have, since #{reason}: #{done.empty? ? 'nothing' : done.join(', ')}")
  rescue => e
    log("putting back what the player's own event would have failed: #{e.class}: #{e.message}")
  end

  # Puts back what an event the mod keeps from starting would have, such as the light of a screen
  # the event would fade in, once per event and state, since the game starts such an event again
  # every frame or step. What a watched scene that still plays shows stays.
  #
  # @param list [Array<RPG::EventCommand>] The event's commands.
  # @param what [String] The event, for the log.
  def self.skipped(list, what)
    return unless $game_map && list

    now = state_now
    watched = MGQ_MpCoopScene.shown
    key = [list.object_id, list.size, now["brightness"] >= FULL_BRIGHTNESS, now["fading_in"], now["pictures"], now["bans"], watched]
    return if @skips.key?(key)

    @skips.clear if @skips.size >= MAX_KEPT_SKIPS
    @skips[key] = true
    done = put_back("skip", { "rest" => rows_of(list), "watch" => watched }, now)
    log("put back what #{what} would have, which the player's game did not start: #{done.join(', ')}") unless done.empty?
  rescue => e
    log_once(:skipped, "putting back what an event kept from starting would have failed: #{e.class}: #{e.message}")
  end

  # Takes the player out of their own scene and their place as the mod moves them away: what the
  # DLL finds the scene and the place leave goes back, every picture shown that was not as the
  # scene began among it, and the scene closes.
  #
  # @param reason [String] Why the player leaves, for the log.
  # @param whole [Boolean] Whether every scene of the player's own goes, a temporary party it began
  #   with too, as when the world's story returns the player to a point where none plays.
  # @param elsewhere [Boolean] Whether the player goes to another map.
  def self.leave(reason, whole = false, elsewhere = false)
    settle_load
    start = @scene ? @scene[:start] : nil
    @scene = nil
    done = put_back("leave", "before" => start, "whole" => whole ? true : false, "elsewhere" => elsewhere ? true : false)
    log("took the player out of #{start ? 'their own scene' : 'their place'}, since #{reason}: #{done.empty? ? 'nothing to put back' : done.join(', ')}")
  rescue => e
    @scene = nil
    log("taking the player out of their own scene failed: #{e.class}: #{e.message}")
  end

  # Puts back what a watched scene of another player's game changed of the player's screen once it
  # ends for them, and lays what it put back over the states the player's own scene began from, see
  # rebase.
  #
  # @param before [Hash, nil] The state before the scene reached the screen, see state_now; nil when
  #   it only gave the player's character a route.
  # @param shown [Hash] What of the scene reached the screen, see MGQ_MpCoopScene.shown.
  # @return [Array<String>] What was put back, for the log.
  def self.watched(before, shown)
    plan = ask("cut" => "watched", "before" => before, "watch" => shown, "now" => state_now)
    return [] unless plan

    done = apply(plan)
    rebase(shown, plan)
    done
  end

  # Lays the tint, the character and the music a watched scene's end left over the states the
  # player's own scene and its latest event began from, for each the watched scene changed: an
  # event of the player's own that began while the watched scene showed would otherwise bring its
  # leftovers back once the mod cuts it.
  #
  # @param shown [Hash] What of the watched scene reached the screen, see MGQ_MpCoopScene.shown.
  # @param plan [Hash] What its end put back.
  def self.rebase(shown, plan)
    return unless @scene

    now = state_now
    values = {}
    values["tone"] = plan["tone"] || now["tone"] if shown["screen"]
    values["hidden"] = now["hidden"] if shown["hidden"]
    values["music"] = now["music"] if shown["music"]
    return if values.empty?

    [:start, :run].each { |part| @scene[part] = @scene[part].merge(values) if @scene[part] }
    @scene[:stood] = nil
  end

  # Puts back what a move the mod keeps the player from leaves, such as the dark screen the event
  # faded out before it.
  #
  # @param why [String] Why the move is kept back, for the log.
  def self.refused(why)
    done = put_back("refused", {})
    log("put back what the move kept back would have, since #{why}: #{done.join(', ')}") unless done.empty?
  rescue => e
    log("putting back what a move kept back would have failed: #{e.class}: #{e.message}")
  end

  # Puts back what a snapshot of the mod's own leaves as it puts the game back, such as a duel's
  # dark screen, since nothing of the game's flow runs afterwards that would.
  #
  # @param why [String] What put the game back, for the log.
  def self.restored(why)
    done = put_back("free", {})
    log("put back what the snapshot left, since #{why}: #{done.join(', ')}") unless done.empty?
  rescue => e
    log("putting back what a snapshot left failed: #{e.class}: #{e.message}")
  end

  # Reads the state a resume begins from, before it puts anything back, see resuming.
  #
  # @return [Hash, nil] The state; nil when it could not be read.
  def self.resume_begins
    state_now
  rescue => e
    log_once(:resume_begins, "reading the state before a resume failed: #{e.class}: #{e.message}")
    nil
  end

  # Runs a block that puts a scene back, as a raid boss fight's resume does, opening the player's
  # own scene from the state before the resume began: what the resume puts back, its CG, its party
  # and the hidden character among it, is the scene's, which the guard puts back once the mod moves
  # the player away from it.
  #
  # @param before [Hash, nil] The state before the resume began, see state_now; nil for now.
  # @return [Object] What the block returns.
  def self.resuming(before = nil)
    before ||= state_now
    @scene = { :start => before, :run => before, :owned => [] }
    result = yield
    @scene[:owned] |= state_now["pictures"] - before["pictures"] if @scene
    result
  end

  # Forgets the player's own scene and the events kept from starting, as when a new game starts,
  # which brings its own state.
  def self.forget
    @scene = nil
    @skips = {}
    @loaded = false
  end

  # Forgets the player's own scene as a save is loaded, which brings its own state, and takes the
  # one the save stopped once the game runs on from it, see settle_load.
  def self.loaded
    forget
    @loaded = true
  end

  # Asks the DLL what to put back and puts it back. What a watched scene that still plays shows goes
  # with every request but the one of a watched scene that ended, which names its own.
  #
  # @param cut [String] How the mod interrupted the flow, see FlowTopics.PlanTopic.
  # @param fields [Hash] The request's other fields.
  # @param now [Hash] The state now, read here unless given.
  # @return [Array<String>] What was put back, for the log; empty when nothing.
  def self.put_back(cut, fields, now = state_now)
    fields = { "watch" => MGQ_MpCoopScene.shown }.merge(fields)
    plan = ask(fields.merge("cut" => cut, "now" => now))
    plan ? apply(plan) : []
  end

  # Asks the DLL for the plan, handing over the commands of the common events the commands call
  # that were handed over before, then those it names it needs until it has them all.
  #
  # @param request [Hash] The request, which takes the commands.
  # @return [Hash, nil] The plan; nil while the DLL answers none.
  def self.ask(request)
    known = known_commons(request["rest"])
    request["commons"] = known unless known.empty?
    MAX_ROUNDS.times do
      answer = MGQ_Multiplayer::Bridge.call(PLAN_TOPIC, request)
      return nil unless answer.is_a?(Hash)
      return answer unless answer["needs"]

      commons = (request["commons"] ||= {})
      answer["needs"].each { |id| commons[id] = common_rows(id) }
    end
    log_once(:rounds, "the DLL still named common events it needs after #{MAX_ROUNDS} rounds")
    nil
  end

  # Gathers the rows of the common events handed over before that rows call, and of those these
  # call in turn.
  #
  # @param rows [Array<Array>, nil] The rows, see rows_of.
  # @return [Hash] The rows of each common event, by id.
  def self.known_commons(rows)
    fresh_commons
    found = {}
    calls = calls_in(rows)
    until calls.empty?
      id = calls.shift
      next if found.key?(id) || !@commons.key?(id)

      found[id] = @commons[id]
      calls.concat(calls_in(found[id]))
    end
    found
  end

  # Lists the common events rows call.
  #
  # @param rows [Array<Array>, nil] The rows, see rows_of.
  # @return [Array<Integer>] The common events' ids.
  def self.calls_in(rows)
    Array(rows).select { |code, _indent, _params| code == CALL_COMMON }.map { |_code, _indent, params| Array(params)[0].to_i }
  end

  # Puts back what a plan of the DLL names.
  #
  # @param plan [Hash] The plan, see FlowTopics.PlanTopic.
  # @return [Array<String>] What was put back, for the log.
  def self.apply(plan)
    done = []
    screen = $game_map.screen
    frames = plan["frames"].to_i
    numbers = Array(plan["erase"])
    unless numbers.empty?
      numbers.each { |number| screen.pictures[number].erase }
      done << "erased picture(s) #{numbers.join(', ')}"
    end
    if plan["clear_effects"]
      screen.clear_flash if screen.respond_to?(:clear_flash)
      screen.clear_shake if screen.respond_to?(:clear_shake)
    end
    if plan["tone"]
      screen.start_tone_change(Tone.new(*plan["tone"]), frames)
      done << "tone back to #{plan['tone'].map { |value| value.round }.join(',')}"
    end
    if plan["fade_in"]
      screen.start_fadein(frames)
      done << "faded in"
    end
    apply_player(plan, done)
    apply_bans(Array(plan["lift"]), done)
    done
  end

  # Puts back what a plan names of the player's character, the followers, the party and the music.
  #
  # @param plan [Hash] The plan.
  # @param done [Array<String>] What was done, for the log, which takes it.
  def self.apply_player(plan, done)
    unless plan["hidden"].nil?
      $game_player.transparent = plan["hidden"]
      done << "character #{plan['hidden'] ? 'hidden' : 'shown'}"
    end
    unless plan["followers"].nil?
      $game_player.followers.visible = plan["followers"]
      $game_player.refresh
      done << "followers #{plan['followers'] ? 'shown' : 'hidden'}"
    end
    if plan["release_party"]
      $game_party.release_temp_actors
      $game_player.refresh
      done << "ended the temporary party"
    end
    if plan["music"]
      RPG::BGM.new(*plan["music"]).play
      done << "music back to '#{plan['music'][0]}'"
    end
    return unless plan["end_route"]

    MGQ_MpGame.set($game_player, :move_route_forcing, false)
    $game_player.restore_move_route
    done << "ended the forced route of the player's character"
  end

  # Lifts the bans a plan names.
  #
  # @param bans [Array<String>] The bans, by the DLL's names.
  # @param done [Array<String>] What was done, for the log, which takes it.
  def self.apply_bans(bans, done)
    return if bans.empty?

    bans.each do |ban|
      field = SYSTEM_BANS[ban]
      if field
        $game_system.send(:"#{field}=", false)
      elsif ban == ESCAPE_BAN
        $game_switches[MGQ_MpStoryState::ESCAPE_BAN] = false
      end
    end
    done << "lifted the #{bans.join(' and ')} ban#{bans.size > 1 ? 's' : ''}"
  end

  # Reads the state of the screen, the player's character, the party and the bans an event may
  # change, as the DLL reads it (FlowTopics).
  #
  # @return [Hash] "map", "brightness", "fading_in", "tone", "hidden", "followers", "temp_party",
  #   "music", "bans", "route" and "pictures".
  def self.state_now
    screen = $game_map.screen
    last = RPG::BGM.respond_to?(:last) ? RPG::BGM.last : nil
    { "map" => $game_map.map_id, "brightness" => screen.brightness.to_i, "fading_in" => MGQ_MpGame.get(screen, :fadein_duration).to_i > 0,
      "tone" => tone_values(screen.tone), "hidden" => $game_player.transparent ? true : false,
      "followers" => $game_player.followers.visible ? true : false, "temp_party" => temp_party?,
      "music" => last ? [last.name.to_s, last.volume.to_i, last.pitch.to_i] : nil, "bans" => bans_on,
      "route" => $game_player.move_route_forcing ? true : false, "pictures" => pictures_shown(screen) }
  end

  # Reads a tint's values, rounded, since no Float crosses the bridge.
  #
  # @param tone [Tone] The tint.
  # @return [Array<Integer>] Its red, green, blue and gray.
  def self.tone_values(tone)
    [tone.red.round, tone.green.round, tone.blue.round, tone.gray.round]
  end

  # Reports whether a story's temporary party plays, the game's set_temp_actors.
  #
  # @return [Boolean] Whether one does.
  def self.temp_party?
    $game_party.respond_to?(:temp_actors_use?) && $game_party.temp_actors_use? ? true : false
  end

  # Lists the bans on now, by the DLL's names.
  #
  # @return [Array<String>] The bans.
  def self.bans_on
    bans = SYSTEM_BANS.keys.select { |ban| $game_system.respond_to?(SYSTEM_BANS[ban]) && $game_system.send(SYSTEM_BANS[ban]) }
    bans << ESCAPE_BAN if defined?(MGQ_MpStoryState::ESCAPE_BAN) && $game_switches && $game_switches[MGQ_MpStoryState::ESCAPE_BAN]
    bans
  end

  # Lists the pictures the map's screen shows.
  #
  # @param screen [Game_Screen] The screen.
  # @return [Array<Integer>] Their numbers.
  def self.pictures_shown(screen)
    shown = []
    (MGQ_MpGame.get(screen.pictures, :data) || []).each_with_index { |picture, number| shown << number if picture && !picture.name.to_s.empty? }
    shown
  end

  # Writes commands as the DLL reads them: [code, indent, plain parameters], a text only in a
  # script's lines, so no message's text crosses the bridge.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @return [Array<Array>] The rows.
  def self.rows_of(list)
    list.map { |command| [command.code, command.indent, plain(command.parameters, SCRIPT_CODES.include?(command.code))] }
  end

  # Writes a common event's commands, kept per id while the game's common events stay the same.
  #
  # @param id [Integer] The common event.
  # @return [Array<Array>] The rows; none for a common event the game lacks.
  def self.common_rows(id)
    fresh_commons
    common = $data_common_events && $data_common_events[id]
    @commons[id] ||= common && common.list ? rows_of(common.list) : []
  end

  # Drops the common events' rows kept once the game's common events are others, as after a mod
  # reloaded them.
  def self.fresh_commons
    return if @commons_of.equal?($data_common_events)

    @commons_of = $data_common_events
    @commons = {}
  end

  # Turns a parameter into a value that crosses the bridge: a number whole, a tint as its four
  # values, a text only where asked; anything else is nil.
  #
  # @param value [Object] The parameter.
  # @param texts [Boolean] Whether a text crosses.
  # @return [Object] It, its plain values, or nil.
  def self.plain(value, texts)
    case value
    when nil, true, false, Integer then value
    when Float then value.finite? ? value.round : nil
    when String then texts && value.valid_encoding? ? value : nil
    when Array then value.map { |item| plain(item, texts) }
    else
      tone_values(value) if value.respond_to?(:gray)
    end
  end
end

# Game hooks of this script, through core_hooks.rbx.

begin
  # The player's own scene notes the state each event of the map's interpreter starts from and the
  # pictures it shows. A common event passes the list alone, so the arguments are not spread.
  MGQ_MpHooks.after(Game_Interpreter, :setup, "coop_flow") { |*_args| MGQ_MpFlowGuard.started(self) }
  [:show, :erase].each do |name|
    MGQ_MpHooks.after(Game_Picture, name, "coop_flow") { |*_args| MGQ_MpFlowGuard.picture(self, name) }
  end
  MGQ_MpHooks.after(Game_Map, :update, "coop_flow") { MGQ_MpFlowGuard.update }

  # A loaded save and a new game bring their own state, so nothing of the player's own scene is put
  # back; a loaded save's own scene is taken once the game runs on from it.
  MGQ_MpHooks.after(DataManager.singleton_class, :extract_save_contents, "coop_flow") { |_contents| MGQ_MpFlowGuard.loaded }
  MGQ_MpHooks.after(DataManager.singleton_class, :setup_new_game, "coop_flow") { MGQ_MpFlowGuard.forget }
rescue => e
  MGQ_MpFlowGuard.log("hooks FAILED: #{e.class}: #{e.message}")
end
