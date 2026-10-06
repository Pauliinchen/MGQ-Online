#----------------------------------------------------------------
#  battles_sync_playback.rbx
#
#  Changelog:
#      Paulinchen  2026-10-06: Showed the host's battle messages through the game's message alone, naming their speaker on it
#      Paulinchen  2026-10-04: Stopped playing for the player to choose again when the host names them
#                            - Logged a host's call the guest leaves out, once per method
#                            - Let the game read a guest's character's features anew once the host's states or buffs changed it, so Division's extra actions count
#                            - Renamed from mp_battles_sync_playback.rbx
#      Paulinchen  2026-10-03: Found the characters outside the battle that its mode names
#                            - Asked the running battle's mode instead of naming co-op battles and team duels
#                            - Read and wrote the game's private fields and called its private methods through MGQ_MpGame
#                            - Created
#
#----------------------------------------------------------------

# The guest's side of a live battle's stream: the host's events, played on the guest's battle.
# It builds on battles_sync.rbx.

module MGQ_MpBattlesSync
  # The guest's side of a live battle: it plays what the host's battle showed instead of
  # computing its own; in a PvP battle with the host's party as its troop and the host's troop as
  # its party.
  module Playback
    # Battle log methods the host may have called.
    LOG_METHODS = %w(add_text replace_text back_one back_to clear clear_popup)

    # Scene waits the host may have called, with a duration.
    TIMED_WAITS = %w(wait abs_wait)

    # Scene waits the host may have called, until something ends.
    OPEN_WAITS = %w(wait_for_animation wait_for_effect wait_for_message)

    # Sprite effects the host may have started.
    SPRITE_EFFECTS = [:appear, :disappear, :whiten, :blink, :collapse, :boss_collapse, :instant_collapse]

    # Longest wait taken from the host, 10 seconds.
    MAX_WAIT = 600

    # A picture the host may show: a file name, never a path.
    PICTURE_NAME = /\A[\w\- ]+\z/

    # Plays the host's stream until its next command phase, the player's choosing again or the
    # battle's end.
    #
    # @param scene [Scene_Battle] The battle.
    # @return [Array, nil] The "end" event when the battle ended, the "choose_again" event that names
    #   the player, an ending of Channel.ending or [:left] when it ended early, nil at the next
    #   command phase.
    def self.run(scene)
      @events ||= []
      quiet = 0
      # The party's status windows show during a turn, which the guest's own battle never has.
      MGQ_MpGame.set(scene, :battle_actor_status_windows_show, true)
      window = nil
      held = Waiting.hold_input(scene)

      loop do
        event = next_event(scene)

        unless event
          ending = Channel.ending
          return [ending] if ending

          quiet += 1
          window ||= Waiting.open("Waiting for #{MGQ_MpBattlesSync.player}...") if quiet == QUIET_FRAMES
          return [:left] if window && Waiting.leave?(window, quiet - QUIET_FRAMES)

          MGQ_MpGame.call(scene, :update_for_wait)
          next
        end

        quiet = 0
        window = Waiting.close(window)
        return nil if event[0] == "commands"
        return event if event[0] == "end"
        if event[0] == "choose_again"
          # Only the players named choose again; the others wait on for the turn.
          return event if Array(event[1]).include?(MGQ_MpOverworldSync::Me.seat)

          next
        end

        play(scene, event)
        @message_complete = @events.empty? || @events.first[0] != "message" if event[0] == "message"
      end
    ensure
      MGQ_MpGame.set(scene, :battle_actor_status_windows_show, false)
      Waiting.close(window)
      Waiting.release_input(held)
    end

    # Forgets events of an earlier battle.
    def self.reset
      @events = []
      @message_complete = false
    end

    # Takes the next event of the host's stream, taking a co-op party's change on the way.
    #
    # @param scene [Scene_Battle] The battle.
    # @return [Array, nil] The next event of the host's stream, nil while none arrived.
    def self.next_event(scene)
      while @events.empty?
        mode = MGQ_MpBattlesSync.mode
        kind, body = Channel.take_first(mode.stream_kinds + ["events"])
        return nil unless kind

        # The battle's own messages come between two sends, so the next send's battlers are those
        # the message leaves, such as a co-op party's once a player left.
        if kind != "events"
          mode.take(kind, scene, body)
          next
        end

        body.split("\n").each do |line|
          event = Wire.parse(line) { |ref| battler(ref) }
          @events << event if event && event[0].is_a?(String)
        end
      end
      @events.shift
    end

    # Finds the guest's battler for a reference of the host's side.
    #
    # @param ref [String] A battler of the host's side, such as "a0", or a character outside the
    #   battle as its mode names it.
    # @return [Game_Battler, nil] The guest's battler in its place.
    def self.battler(ref)
      return MGQ_MpBattlesSync.mode.reserve(ref) unless ref =~ /\A([ae])(\d{1,2})\z/

      # In a PvP battle the host's party is the guest's troop; a co-op battle's sides are the same,
      # and so are those of a team duel's guest on the host's side.
      party = MGQ_MpBattlesSync.same_side? ? $1 == "a" : $1 == "e"
      party ? $game_party.battle_members[$2.to_i] : $game_troop.members[$2.to_i]
    end

    # Plays one event. An event that fails is left out and logged once per kind.
    #
    # @param scene [Scene_Battle] The battle.
    # @param event [Array] The event's kind and values.
    def self.play(scene, event)
      kind, *args = event
      method = kind.split(".", 2)[1]

      case kind
      when "call"
        call(scene, *args)
      when "emerge"
        emerge(scene)
      when /\Alog\./
        log_window(scene).send(method, *args.map { |arg| arg.is_a?(String) ? Names.swap(arg) : arg }) if LOG_METHODS.include?(method)
      when "popup"
        log_window(scene).popup.push(Names.swap(args[0].to_s), args[1])
      when "message"
        message(scene, *args)
      when /\Apicture\./
        picture(method, args)
      when /\Ascreen\./
        $game_troop.screen.send(method, *args) if recorded?(Hooks::SCREEN_METHODS, method)
      when /\Aaudio\./
        Audio.send(method, *args) if recorded?(Hooks::AUDIO_METHODS, method)
      when "animation"
        animation(scene, *args)
      when "battler.animation_id", "battler.animation_mirror"
        battler_animation(method, *args)
      when "battler.sprite_effect_type"
        sprite_effect(*args)
      when "skill_name"
        (args[0] == "troop" ? $game_troop : $game_party).display_skill_name = args[1].is_a?(String) ? Names.swap(args[1]) : nil
      when /\Ascene\./
        wait(scene, method, args[0])
      when "values"
        values(*args)
        MGQ_MpGame.call(scene, :refresh_status)
      when "time_stop"
        $game_party.od_turn = args[0].to_i
        $game_party.od_user = args[1]
      when "turn"
        MGQ_MpGame.set($game_troop, :turn_count, args[0].to_i)
      end
    rescue => e
      MGQ_MpBattlesSync.log_once([:play, kind], "could not play #{kind}: #{e.class}: #{e.message}")
    end

    # Reports whether the hooks record a method, which the guest then plays as the host called it.
    #
    # The name came from the host, so it is compared as text and never made a symbol, since symbols
    # are never freed.
    #
    # @param names [Array<Symbol>] The methods the hooks record.
    # @param method [String] The method the host called.
    # @return [Boolean] Whether they record it.
    def self.recorded?(names, method)
      names.any? { |name| name.to_s == method }
    end

    # Makes a call the host recorded with this game's own texts, see Recorder.call: the battle log
    # or the battle writes the line in this game's language, with the host's action results and
    # random choices. Its waits are skipped while the guest catches up.
    #
    # @param scene [Scene_Battle] The battle.
    # @param receiver [String] "log" or "scene".
    # @param name [String] The method.
    # @param seed [Integer] The seed of the host's random choices.
    # @param subject [Game_Battler, nil] Who acts.
    # @param results [Array<Array>] Battlers with their action results.
    # @param args [Array] The method's arguments.
    def self.call(scene, receiver, name, seed, subject, results, *args)
      unless callable?(receiver, name)
        # A call the guest leaves out shows nothing, such as a hit's damage numbers.
        return MGQ_MpBattlesSync.log_once([:left_out, receiver.to_s, name.to_s[0, 40]], "left out the host's #{receiver} call #{name.to_s[0, 40]}")
      end

      Array(results).each do |battler, result|
        MGQ_MpGame.set(battler, :result, result) if battler && result.is_a?(Game_ActionResult)
      end
      earlier = MGQ_MpGame.get(scene, :subject)
      begin
        MGQ_MpGame.set(scene, :subject, subject) if receiver == "scene"
        @in_call = true
        srand(seed.to_i)
        (receiver == "log" ? log_window(scene) : scene).send(name, *args)
      ensure
        @in_call = false
        srand
        MGQ_MpGame.set(scene, :subject, earlier)
      end
    end

    # Tells whether a recorded call names a method the host may have the guest call.
    #
    # @param receiver [String] "log" or "scene".
    # @param name [String] The method.
    # @return [Boolean] Whether the guest makes the call.
    def self.callable?(receiver, name)
      case receiver
      when "log" then name =~ Hooks::LOG_CALL && Window_BattleLog.method_defined?(name) ? true : false
      when "scene" then Hooks::SCENE_CALLS.include?(name.to_s.to_sym)
      else false
      end
    end

    # Tells whether the guest skips a wait of a call it makes, since it fell behind the host's stream.
    #
    # @return [Boolean] Whether the wait is skipped.
    def self.skip_wait?
      @in_call && behind? ? true : false
    end

    # Says which of the host's characters appear, in this game's language, as the host's battle
    # did at its start.
    #
    # @param scene [Scene_Battle] The battle.
    def self.emerge(scene)
      $game_message.speaker = nil
      $game_troop.enemy_names.each { |name| $game_message.add(format(Vocab::Emerge, name)) }
      MGQ_MpGame.call(scene, :wait_for_message)
    end

    # Starts an animation a battler started by itself on the host, outside the battle's own showing
    # of one, or mirrors it.
    #
    # @param field [String] "animation_id" or "animation_mirror".
    # @param battler [Game_Battler, nil] The guest's battler.
    # @param value [Integer, Boolean] The animation, or whether it is mirrored.
    def self.battler_animation(field, battler, value)
      return if battler.nil? || behind?
      return battler.animation_mirror = value ? true : false if field == "animation_mirror"

      battler.animation_id = value.to_i if $data_animations[value.to_i]
    end

    # Starts a sprite effect the host started. The host's characters fall with an actor's collapse,
    # but on the guest they are the enemy side, which stays as a silhouette after the defeat flash.
    #
    # @param battler [Game_Battler, nil] The guest's battler.
    # @param effect [Symbol] The effect.
    def self.sprite_effect(battler, effect)
      return unless battler && SPRITE_EFFECTS.include?(effect)

      collapse = [:collapse, :boss_collapse, :instant_collapse].include?(effect)
      battler.sprite_effect_type = collapse && $game_troop.members.include?(battler) ? :whiten : effect
    end

    # Finds the battle log of a battle scene.
    #
    # @param scene [Scene_Battle] The battle.
    # @return [Window_BattleLog] Its battle log.
    def self.log_window(scene)
      MGQ_MpGame.get(scene, :log_window)
    end

    # Shows a line a character says, with its face, through the game's message, which names its
    # speaker for a mod that shows battle messages by their side.
    #
    # The first line of a message lets the game move an earlier one on first, unless the guest has
    # to catch up, so two messages never show as one.
    #
    # @param scene [Scene_Battle] The battle.
    # @param speaker [Game_Battler, nil] Who says it.
    # @param face_name [String] The face file.
    # @param face_index [Integer] The face in the file.
    # @param background [Integer] The window's background.
    # @param position [Integer] The window's position.
    # @param text [String] The line.
    def self.message(scene, speaker, face_name, face_index, background, position, text)
      MGQ_MpGame.call(scene, :wait_for_message) if @message_complete && $game_message.has_text? && !behind?
      @message_complete = false
      $game_message.speaker = speaker
      $game_message.face_name = face_name.to_s
      $game_message.face_index = face_index.to_i
      $game_message.background = background.to_i
      $game_message.position = position.to_i
      $game_message.add(Names.readable(Names.swap_message(text.to_s)))
    end

    # Changes a picture, such as a cut-in.
    #
    # @param method [String] What the host did with it.
    # @param args [Array] The picture's number, then the method's arguments.
    def self.picture(method, args)
      number = args[0].to_i
      return unless recorded?(Hooks::PICTURE_METHODS, method) && number > 0 && number <= 100
      return if method == "show" && args[1].to_s !~ PICTURE_NAME

      $game_troop.screen.pictures[number].send(method, *args[1..-1])
    end

    # Starts an animation on the guest's battlers, unless the guest holds the skip key or has to
    # catch up. It only starts it: the host's recorded waits that follow keep the pace, and the
    # game's own animation methods would wait a second time.
    #
    # @param scene [Scene_Battle] The battle.
    # @param subject [Game_Battler, nil] Who acts, whose weapons an attack animation shows.
    # @param targets [Array] The targets.
    # @param animation_id [Integer] The animation, below 0 for the subject's attack animation.
    def self.animation(scene, subject, targets, animation_id)
      return if behind? || MGQ_MpGame.call(scene, :battle_show_skip?)

      ids = animation_id.to_i < 0 ? (subject && subject.actor? ? subject.atk_animation_ids.first(1) : []) : [animation_id.to_i]
      ids.each do |id|
        next unless $data_animations[id]

        Array(targets).compact.each do |target|
          target.animation_id = id
          target.animation_mirror = false
        end
      end
    end

    # Tells whether the guest fell behind the host's stream.
    #
    # @return [Boolean] Whether the host's stream piled up, so the guest skips waits to catch up.
    def self.behind?
      Channel.pending("events") >= BEHIND_SENDS
    end

    # Waits the way the host's battle waited, at the guest's own battle speed, unless it has to
    # catch up.
    #
    # @param scene [Scene_Battle] The battle.
    # @param method [String] The wait.
    # @param duration [Integer, nil] Its frames, for a timed wait.
    def self.wait(scene, method, duration)
      return if behind?

      if TIMED_WAITS.include?(method)
        scene.send(method, [duration.to_i, MAX_WAIT].min)
      elsif OPEN_WAITS.include?(method)
        scene.send(method)
      end
    end

    # Gives a battler the values the host computed.
    #
    # @param battler [Game_Battler, nil] The guest's battler.
    # @param hp [Integer] Its HP.
    # @param _mhp [Integer] Its maximum HP on the host.
    # @param mp [Integer] Its MP.
    # @param _mmp [Integer] Its maximum MP on the host.
    # @param tp [Integer] Its SP.
    # @param states [Array<Integer>] Its state ids.
    # @param buffs [Array<Integer>] Its buffs.
    def self.values(battler, hp, _mhp, mp, _mmp, tp, states, buffs)
      return unless battler

      MGQ_MpGame.set(battler, :hp, hp.to_i)
      MGQ_MpGame.set(battler, :mp, mp.to_i)
      MGQ_MpGame.set(battler, :tp, tp.to_i)
      ids = Array(states).map(&:to_i).select { |id| $data_states[id] }
      turns = MGQ_MpGame.get(battler, :state_turns) || {}
      ids.each { |id| turns[id] ||= 1 }
      before = [MGQ_MpGame.get(battler, :states), MGQ_MpGame.get(battler, :buffs)].map { |list| Array(list).dup }
      MGQ_MpGame.set(battler, :states, ids)
      MGQ_MpGame.set(battler, :buffs, Array(buffs).map(&:to_i)) if Array(buffs).size == 8
      features_changed(battler) if before != [ids, Array(MGQ_MpGame.get(battler, :buffs))]
    end

    # Lets the game read a character's features anew once its states or buffs changed.
    #
    # The game keeps each character's features until it refreshes the character, which values set
    # past the game's setters never does, so a state's extra actions, such as Division's, or its
    # counters never counted on the guest.
    #
    # @param battler [Game_Battler] The guest's battler.
    def self.features_changed(battler)
      return unless battler.actor?

      if defined?(CacheActorFeatures)
        CacheActorFeatures.init_actor(battler)
        CacheUniq.init if defined?(CacheUniq)
      else
        battler.refresh
      end
    end
  end
end

class Game_Message
  # The battler who says the message, for a mod that shows battle messages by their side.
  attr_accessor :speaker unless method_defined?(:speaker)
end
