#----------------------------------------------------------------
#  battles_sync_playback.rbx
#
#  Changelog:
#      Paulinchen  2026-10-08: Showed a message of the host without its face while this game lacks the face file
#      Paulinchen  2026-10-07: Gave the states the host adds the counters the game keeps per state, without which a turn's end on the map ended the game
#                            - Checked the arguments of the host's audio calls as a picture's are checked, and left out a call that fails, logged once
#                            - Took the number of pictures the screen holds from coop_scene.rbx
#                            - Logged each turn's playback with its waits and catching up, how the battle began, the items used up and the host's values this game cannot take
#                            - Gave a battler the host's HP, MP, SP and states after the game read its features anew, which held HP below this game's own maximum
#                            - Logged once per character when the host's HP lies above this game's maximum
#      Paulinchen  2026-10-06: Showed how the host's battle began, and kept a surprised party from choosing in its first command phase
#                            - Used up the consumable items the player's own characters used in the host's battle
#                            - Took the turns each state has left and the barriers from the host
#                            - Let a real monster's defeat on the host fade it out here too, keeping the silhouette to the other player's characters
#                            - Checked the host's calls against the names the hooks list as texts, never making a symbol of the host's text
#                            - Played the battle log's methods the hooks record, from their one list
#                            - Showed the host's battle messages through the game's message alone, naming their speaker on it
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

    # A sound or piece of music the host may play: a path inside the game's Audio folder, as the
    # game passes it, whose parts are plain names, so it never leads out of that folder.
    AUDIO_FILE = %r{\AAudio/(?:[\w\- ]+/)+[\w\- ]+(?:\.[\w\- ]+)*\z}

    # The volumes the game plays at.
    VOLUME_RANGE = 0..100

    # The pitches the game plays at.
    PITCH_RANGE = 50..150

    # Longest fade of music taken from the host, in milliseconds, ten seconds.
    MAX_FADE = 10_000

    # Plays the host's stream until its next command phase, the player's choosing again or the
    # battle's end.
    #
    # @param scene [Scene_Battle] The battle.
    # @return [Array, nil] The "end" event when the battle ended, the "choose_again" event that names
    #   the player, an ending of Channel.ending or [:left] when it ended early, nil at the next
    #   command phase.
    def self.run(scene)
      @events ||= []
      @stats = Hash.new(0)
      outcome = "stopped"
      quiet = 0
      # The party's status windows show during a turn, which the guest's own battle never has.
      MGQ_MpGame.set(scene, :battle_actor_status_windows_show, true)
      window = nil
      held = Waiting.hold_input(scene)

      loop do
        event = next_event(scene)

        unless event
          ending = Channel.ending
          if ending
            outcome = "the battle ended early (#{ending})"
            return [ending]
          end

          quiet += 1
          count(:quiet)
          if quiet == QUIET_FRAMES
            count(:stalls)
            window ||= Waiting.open("Waiting for #{MGQ_MpBattlesSync.player}...")
          end
          if window && Waiting.leave?(window, quiet - QUIET_FRAMES)
            outcome = "the player left while waiting for the host's stream"
            return [:left]
          end

          MGQ_MpGame.call(scene, :update_for_wait)
          next
        end

        quiet = 0
        window = Waiting.close(window)
        if event[0] == "commands"
          outcome = "the next command phase"
          return nil
        end
        if event[0] == "end"
          outcome = "the battle's end (#{event[1]})"
          return event
        end
        if event[0] == "choose_again"
          # Only the players named choose again; the others wait on for the turn.
          if Array(event[1]).include?(MGQ_MpOverworldSync::Me.seat)
            outcome = "this player choosing again"
            return event
          end

          count(:others_choose)
          next
        end

        play(scene, event)
        @message_complete = @events.empty? || @events.first[0] != "message" if event[0] == "message"
      end
    ensure
      log_run(outcome)
      MGQ_MpGame.set(scene, :battle_actor_status_windows_show, false)
      Waiting.close(window)
      Waiting.release_input(held)
    end

    # Counts something of the playback for the turn's line in Multiplayer InGame.log.
    #
    # @param key [Symbol] What happened.
    # @param amount [Integer] How often.
    def self.count(key, amount = 1)
      (@stats ||= Hash.new(0))[key] += amount
    end

    # Sums up a playback until the next command phase or the battle's end in Multiplayer InGame.log.
    #
    # @param outcome [String] Where the playback stopped.
    def self.log_run(outcome)
      stats = @stats || Hash.new(0)
      turn = MGQ_MpBattlesSync.turn
      parts = ["#{stats[:events]} events of #{stats[:sends]} sends"]
      parts << "behind the host #{stats[:behind]} times, skipping waits and animations to catch up" if stats[:behind] > 0
      parts << "waited #{format('%.1f', stats[:quiet] / 60.0)} s for the host's stream, #{stats[:stalls]} times long enough to say so" if stats[:quiet] > 0
      parts << "#{stats[:unreadable]} lines unreadable" if stats[:unreadable] > 0
      parts << "#{stats[:failed]} events failed" if stats[:failed] > 0
      parts << "#{stats[:others_choose]} times others chose again" if stats[:others_choose] > 0
      MGQ_MpBattlesSync.log("played #{turn == 0 ? "the battle's start" : "turn #{turn}"} up to #{outcome}: #{parts.join('; ')}")
    end

    # Forgets events of an earlier battle.
    def self.reset
      @events = []
      @message_complete = false
      @encounter = nil
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

        count(:sends)
        body.split("\n").each do |line|
          event = Wire.parse(line) { |ref| battler(ref) }
          if event && event[0].is_a?(String)
            @events << event
            count(:events)
          else
            count(:unreadable)
            MGQ_MpBattlesSync.log_once(:unreadable_event, "left out an unreadable line of the host's stream (#{line.size} characters)")
          end
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
        emerge(scene, *args)
      when "item_used"
        use_up(*args)
      when /\Alog\./
        log_window(scene).send(method, *args.map { |arg| arg.is_a?(String) ? Names.swap(arg) : arg }) if recorded?(Hooks::LOG_METHODS, method)
      when "popup"
        log_window(scene).popup.push(Names.swap(args[0].to_s), args[1])
      when "message"
        message(scene, *args)
      when /\Apicture\./
        picture(method, args)
      when /\Ascreen\./
        $game_troop.screen.send(method, *args) if recorded?(Hooks::SCREEN_METHODS, method)
      when /\Aaudio\./
        audio(method, args)
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
      else
        MGQ_MpBattlesSync.log_once([:unknown_event, kind[0, 40]], "left out the host's event #{kind[0, 40]}, which this game does not know")
      end
    rescue => e
      count(:failed)
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
      when "log" then Hooks.log_calls.include?(name)
      when "scene" then Hooks::SCENE_CALL_NAMES.include?(name)
      else false
      end
    end

    # Tells whether the guest skips a wait of a call it makes, since it fell behind the host's stream.
    #
    # @return [Boolean] Whether the wait is skipped.
    def self.skip_wait?
      return false unless @in_call && behind?

      count(:behind)
      true
    end

    # Says which of the host's characters appear, and whether a side struck first, in this game's
    # language, as the host's battle did at its start. Keeps how the battle began for
    # take_encounter.
    #
    # @param scene [Scene_Battle] The battle.
    # @param preemptive [Boolean] Whether the host's party struck first.
    # @param surprise [Boolean] Whether the host's party was surprised.
    def self.emerge(scene, preemptive = false, surprise = false)
      # The host's party is this game's troop in a PvP battle, so its first strike is a surprise here.
      preemptive, surprise = surprise, preemptive unless MGQ_MpBattlesSync.same_side?
      $game_message.speaker = nil
      $game_troop.enemy_names.each { |name| $game_message.add(format(Vocab::Emerge, name)) }
      if preemptive
        $game_message.add(format(Vocab::Preemptive, $game_party.name))
      elsif surprise
        $game_message.add(format(Vocab::Surprise, $game_party.name))
      end
      @encounter = [preemptive ? true : false, surprise ? true : false]
      began = preemptive ? "with this party striking first" : surprise ? "with this party surprised" : "without a first strike"
      MGQ_MpBattlesSync.log("the host's battle began #{began}, #{$game_troop.members.size} on the other side")
      MGQ_MpGame.call(scene, :wait_for_message)
    end

    # Gives the guest's first command phase how the host's battle began, which emerge kept: a
    # surprised party chooses no commands, and one that struck first gets away for sure.
    #
    # The guest's battle sets these at its own setup, which knows nothing of the host's encounter.
    def self.take_encounter
      encounter = @encounter
      @encounter = nil
      return unless encounter

      MGQ_MpGame.set(BattleManager, :preemptive, encounter[0])
      MGQ_MpGame.set(BattleManager, :surprise, encounter[1])
      if encounter[0]
        MGQ_MpBattlesSync.log("first command phase: this party struck first, so it gets away for sure")
      elsif encounter[1]
        MGQ_MpBattlesSync.log("first command phase: this party was surprised, so it chooses no commands")
      end
    rescue => e
      MGQ_MpBattlesSync.log_once(:take_encounter, "could not take how the battle began: #{e.class}: #{e.message}")
    end

    # Uses up an item one of this game's own characters used in the host's battle, which the host's
    # game leaves to the owner's bag.
    #
    # @param battler [Game_Battler, nil] The guest's battler who used it.
    # @param item [RPG::Item, nil] The item.
    def self.use_up(battler, item)
      return unless battler && item.is_a?(RPG::Item) && battler.actor? && !battler.is_a?(Game_MpActor)

      before = $game_party.item_number(item) rescue nil
      $game_party.consume_item(item)
      log_used_up(battler, item, before)
    end

    # Logs an item used up as the host's battle used it.
    #
    # @param battler [Game_Battler] The guest's battler who used it.
    # @param item [RPG::Item] The item.
    # @param before [Integer, nil] How many the party had before.
    def self.log_used_up(battler, item, before)
      MGQ_MpBattlesSync.log("used up item #{item.id} #{item.name} (#{before.inspect} -> #{$game_party.item_number(item)}), " \
                            "which #{MGQ_MpBattlesSync.named(battler)} used in the host's battle")
    rescue
      MGQ_MpBattlesSync.log("used up item #{item.id}, which #{MGQ_MpBattlesSync.named(battler)} used in the host's battle")
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

    # Starts a sprite effect the host started. In a PvP battle the host's characters fall with an
    # actor's collapse, but on the guest they are the enemy side, which stays as a silhouette after
    # the defeat flash; a co-op battle's monsters fall as they do on the host.
    #
    # @param battler [Game_Battler, nil] The guest's battler.
    # @param effect [Symbol] The effect.
    def self.sprite_effect(battler, effect)
      return unless battler && SPRITE_EFFECTS.include?(effect)

      collapse = [:collapse, :boss_collapse, :instant_collapse].include?(effect)
      silhouette = collapse && !MGQ_MpBattlesSync.same_side? && $game_troop.members.include?(battler)
      battler.sprite_effect_type = silhouette ? :whiten : effect
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
      $game_message.face_name = MGQ_MpOverworld.graphic?(:face, face_name.to_s) ? face_name.to_s : ""
      $game_message.face_index = face_index.to_i
      $game_message.background = background.to_i
      $game_message.position = position.to_i
      $game_message.add(Names.readable(Names.swap_message(text.to_s)))
    end

    # Plays a sound or a piece of music as the host did, once its arguments read as the game's own
    # calls: a file inside the Audio folder, a volume and a pitch the game plays at. A call the
    # game refuses is left out and logged once per method.
    #
    # @param method [String] What the host called of Audio.
    # @param args [Array] The call's arguments.
    def self.audio(method, args)
      return unless recorded?(Hooks::AUDIO_METHODS, method)
      unless audio_args?(method, args)
        return MGQ_MpBattlesSync.log_once([:audio_args, method], "left out the host's audio call #{method} with the arguments #{args.inspect[0, 80]}")
      end

      Audio.send(method, *args)
    rescue => e
      MGQ_MpBattlesSync.log_once([:audio, method], "could not play the host's #{method}: #{e.class}: #{e.message}")
    end

    # Reports whether the arguments of one of the host's audio calls read as the game's own: a play
    # names a file with a volume, a pitch and, for music, a position, a stop takes nothing, a fade
    # its milliseconds, and the game's own over drive calls only plain values.
    #
    # @param method [String] What the host called of Audio.
    # @param args [Array] The call's arguments.
    # @return [Boolean] Whether they do.
    def self.audio_args?(method, args)
      case method
      when /_play\z/
        name, volume, pitch, position = args
        args.size <= 4 && name.is_a?(String) && name =~ AUDIO_FILE && bounded?(volume, VOLUME_RANGE) && bounded?(pitch, PITCH_RANGE) &&
          (position.nil? || (method =~ /\Abg/ && position.is_a?(Integer) && position >= 0))
      when /_stop\z/ then args.empty?
      when /_fade\z/ then args.size == 1 && bounded?(args[0], 0..MAX_FADE)
      else args.all? { |arg| arg.nil? || arg == true || arg == false || arg.is_a?(Numeric) }
      end ? true : false
    end

    # Reports whether an optional number of an audio call lies within what the game accepts.
    #
    # @param value [Object, nil] The number, nil when the call leaves it to the game.
    # @param range [Range] What the game accepts.
    # @return [Boolean] Whether it does.
    def self.bounded?(value, range)
      value.nil? || (value.is_a?(Integer) && range.include?(value))
    end

    # Changes a picture, such as a cut-in.
    #
    # @param method [String] What the host did with it.
    # @param args [Array] The picture's number, then the method's arguments.
    def self.picture(method, args)
      number = args[0].to_i
      unless recorded?(Hooks::PICTURE_METHODS, method) && number > 0 && number <= MGQ_MpCoopScene::MAX_PICTURE
        return MGQ_MpBattlesSync.log_once([:picture, method.to_s[0, 40]], "left out the host's picture call #{method.to_s[0, 40]} on picture #{number}")
      end
      if method == "show" && args[1].to_s !~ PICTURE_NAME
        return MGQ_MpBattlesSync.log_once([:picture_name, args[1].to_s[0, 40]], "left out the host's picture #{args[1].to_s[0, 40].inspect}, not a plain file name")
      end

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
      return count(:behind) if behind?
      return if MGQ_MpGame.call(scene, :battle_show_skip?)

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
      return count(:behind) if behind?

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
    # @param mp [Integer] Its MP.
    # @param tp [Integer] Its SP.
    # @param states [Array<Integer>] Its state ids.
    # @param turns [Array<Integer>] The turns each of those states has left.
    # @param buffs [Array<Integer>] Its buffs.
    # @param walls [Integer] Its barriers.
    def self.values(battler, hp, mp, tp, states, turns, buffs, walls)
      return unless battler

      known = Array(states).map(&:to_i).zip(Array(turns)).select { |id, _| $data_states[id] }
      ids = known.map(&:first)
      unknown(battler, Array(states).map(&:to_i) - ids, buffs)
      state_turns = MGQ_MpGame.get(battler, :state_turns) || MGQ_MpGame.set(battler, :state_turns, {})
      known.each { |id, count| state_turns[id] = count.to_i }
      before = [MGQ_MpGame.get(battler, :states), MGQ_MpGame.get(battler, :buffs)].map { |list| Array(list).dup }
      seed_state_counts(battler, ids - before[0])
      MGQ_MpGame.set(battler, :states, ids)
      MGQ_MpGame.set(battler, :buffs, Array(buffs).map(&:to_i)) if Array(buffs).size == 8
      features_changed(battler) if before != [ids, Array(MGQ_MpGame.get(battler, :buffs))]
      # Reading the features anew lets the game hold HP below this game's own maximum and add or
      # remove a death, so the host's values go in last.
      MGQ_MpGame.set(battler, :states, ids)
      MGQ_MpGame.set(battler, :hp, hp.to_i)
      MGQ_MpGame.set(battler, :mp, mp.to_i)
      MGQ_MpGame.set(battler, :tp, tp.to_i)
      over_maximum(battler, hp.to_i, mp.to_i)
      set_walls(battler, walls)
    end

    # Gives the states the host added the counters the game keeps per state as it adds one itself:
    # the turns the state was held and the steps left on the map.
    #
    # The game's turn end, on the map as well, counts every state's turns held, and a state without
    # the counter ends the game.
    #
    # @param battler [Game_Battler] The guest's battler.
    # @param ids [Array<Integer>] The ids of the states new to it.
    def self.seed_state_counts(battler, ids)
      return if ids.empty?

      counts = MGQ_MpGame.get(battler, :state_turn_counts) || MGQ_MpGame.set(battler, :state_turn_counts, {})
      steps = MGQ_MpGame.get(battler, :state_steps) || MGQ_MpGame.set(battler, :state_steps, {})
      ids.each do |id|
        counts[id] ||= 0
        steps[id] ||= $data_states[id].respond_to?(:steps_to_remove) ? $data_states[id].steps_to_remove.to_i : 0
      end
    end

    # Logs once per character that the host's HP or MP of it lies above this game's maximum, which
    # tells a rebuild that differs between the two games.
    #
    # @param battler [Game_Battler] The guest's battler.
    # @param hp [Integer] Its HP on the host.
    # @param mp [Integer, nil] Its MP on the host.
    def self.over_maximum(battler, hp, mp = nil)
      if battler.respond_to?(:mhp) && hp > battler.mhp
        MGQ_MpBattlesSync.log_once([:over_maximum, battler.name], "#{battler.name} has #{hp} HP on the host, above this game's maximum of #{battler.mhp}")
      end
      return unless mp && battler.respond_to?(:mmp) && mp > battler.mmp

      MGQ_MpBattlesSync.log_once([:over_maximum_mp, battler.name], "#{battler.name} has #{mp} MP on the host, above this game's maximum of #{battler.mmp}")
    end

    # Logs once per character the host's states this game does not know, which it leaves out, and
    # buffs it cannot read, which it leaves as they were.
    #
    # @param battler [Game_Battler] The guest's battler.
    # @param states [Array<Integer>] The host's state ids this game does not know.
    # @param buffs [Array] The host's buffs.
    def self.unknown(battler, states, buffs)
      unless states.empty?
        MGQ_MpBattlesSync.log_once([:unknown_states, battler.name, states], "left out states #{states.join(', ')} of #{battler.name} on the host, which this game does not know")
      end
      return if Array(buffs).size == 8

      MGQ_MpBattlesSync.log_once([:buffs, battler.name], "kept #{battler.name}'s buffs: the host sent #{Array(buffs).size} instead of 8")
    end

    # Gives a battler as many barriers as the host's battle shows.
    #
    # @param battler [Game_Battler] The guest's battler.
    # @param count [Integer] Its barriers.
    def self.set_walls(battler, count)
      counters = MGQ_MpGame.get(battler, :counters)
      counters[:defense_wall] = [true] * count.to_i if counters.is_a?(Hash) && counters[:defense_wall].is_a?(Array)
    rescue => e
      MGQ_MpBattlesSync.log_once(:walls, "could not set the barriers: #{e.class}: #{e.message}")
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
