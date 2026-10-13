#----------------------------------------------------------------
#  battles_sync_live.rbx
#
#  Changelog:
#      Paulinchen  2026-10-12: Took the host's defeat scene and enemy only when valid here
#                            - Won the battle when its enemies fall during the wait for commands
#                            - Picked a defeat scene for a guest who leaves a story's battle
#                            - Put the host's skip settings back as the battle ends
#                            - Moved battle messages on while the message skip is held
#      Paulinchen  2026-10-11: Named the guests the host still waits for in the waiting box
#                            - Lost a story's battle for the co-op player who leaves it
#                            - Told the guests whom the host still waits for
#                            - Told the guests who chooses again after a swap, the host itself included
#      Paulinchen  2026-10-08: Closed a command phase the battle ended in as the battle ends
#                            - Started a host who became another battle's guest as that battle's guest
#      Paulinchen  2026-10-07: Left an earlier battle's command phase out of the log
#                            - Let a battle message outside a fiber move on at once
#                            - Logged the live battle's start, command phases, commands, escapes, leaving and end
#                            - Left out the commands a guest sent before leaving the battle
#      Paulinchen  2026-10-06: Asked a scene directly whether it changes
#                            - Told the guest how the battle began
#                            - Recorded the consumable items a guest's character used
#                            - Settled who fights on also once the computer plays for those who left
#                            - Recorded the speaker the game's message names instead of one of the mod's own
#                            - Recorded the battle log's waits only as the scene's
#                            - Listed the battle log's methods the guest calls itself as texts
#                            - Sent the guest's ready word without names
#      Paulinchen  2026-10-05: Started the newer translation's battle log anew at the guest's battle and turn start
#      Paulinchen  2026-10-04: Settled who fights on only as a command phase opens
#                            - Sent players whose commands lost their target to a swap back to choose
#                            - Renamed from mp_battles_sync_live.rbx
#                            - Gave the guest of a lost co-op battle the host's defeat scene
#      Paulinchen  2026-10-03: Told a PvP battle's guest a changed order of places
#                            - Asked the running battle's mode instead of naming co-op battles and team duels
#                            - Reached the game's private fields and methods through MGQ_MpGame
#                            - Created
#
#----------------------------------------------------------------

# A live battle's hooks into the game's battle, and its steps that differ between host and
# guest: the start both wait for, the commands, the end and leaving. It builds on
# battles_sync.rbx and its recorder and playback.

module MGQ_MpBattlesSync
  # The game hooks, which run the original and return its result unless a live battle's side takes
  # the method over.
  #
  # The game's plugins load after the Patch folder and some define battle methods anew, which drops
  # a hook installed before them, so the hooks go in once the first scene starts.
  module Hooks
    # The battle log's primitives, which every battle log line goes through. Its waits call the
    # scene's, see SCENE_WAITS.
    LOG_METHODS = [:add_text, :replace_text, :back_one, :back_to, :clear, :clear_popup]

    # What pictures do, such as a cut-in.
    PICTURE_METHODS = [:show, :move, :rotate, :start_tone_change, :erase]

    # What the screen does, such as a flash, and the darkening while time stands still.
    SCREEN_METHODS = [:start_shake, :start_flash, :start_tone_change, :start_fadeout, :start_fadein, :od_fadein, :od_fadeout]

    # Every sound and piece of music, and the music fading while time stands still.
    AUDIO_METHODS = [:se_play, :me_play, :bgm_play, :bgs_play, :se_stop, :me_stop, :bgm_stop, :bgs_stop,
                     :me_fade, :bgm_fade, :bgs_fade, :start_over_drive, :end_over_drive]

    # The animation a battler starts on its sprite. The sprite clears it again once taken, which is
    # not recorded.
    ANIMATION_SETTERS = [:animation_id=, :animation_mirror=]

    # Where the game starts a hit's and a defeat's sprite effect, by writing the battler's field
    # directly, which the setter's hook never sees.
    EFFECT_METHODS = [:perform_damage_effect, :perform_collapse_effect]

    # The scene's waits, which set the battle's pace.
    SCENE_WAITS = [:wait, :abs_wait, :wait_for_animation, :wait_for_effect, :wait_for_message]

    # The battle log's methods that write a line of their own, which the guest calls itself.
    LOG_CALL = /\Adisplay_\w+\z/

    # The battle's methods the guest calls itself: the line a character says with a skill, with its
    # cut-in, and the skill's name at the top.
    SCENE_CALLS = [:process_skill_word, :display_skill_name]

    # The scene's waits a call the guest makes itself skips while the guest catches up.
    SKIPPABLE_WAITS = [:wait, :abs_wait]

    # SCENE_CALLS as texts, which the names in the host's stream are compared with.
    SCENE_CALL_NAMES = SCENE_CALLS.map(&:to_s)

    # Lists the battle log's methods the hooks record as calls, as texts.
    #
    # @return [Array<String>] The methods' names, none before the hooks are in.
    def self.log_calls
      @log_calls || []
    end

    # Installs the hooks, a failing group alone left out. Calling it again does nothing.
    def self.install
      return if @installed
      @installed = true

      installed = [:battle_log, :messages, :pictures, :audio, :battlers, :course, :ending, :live, :calls].select do |group|
        begin
          send(group)
          true
        rescue => e
          MGQ_MpBattlesSync.log("#{group} hooks FAILED: #{e.class}: #{e.message}")
          false
        end
      end
      MGQ_MpBattlesSync.log("battle hooks installed: #{installed.empty? ? 'none' : installed.join(', ')}; #{log_calls.size} battle log calls the guest makes itself")
    end

    # Records the battle log's lines and the popups over them.
    def self.battle_log
      LOG_METHODS.each { |name| record_before(Window_BattleLog, name) { |_log, args| ["log.#{name}", *args] } }
      record_before(PopupResults, :push) { |_popups, args| ["popup", *args] }
    end

    # Records messages with their face and speaker, see Game_Message#speaker, such as the lines
    # characters say when they use a skill or fall, and moves them on by themselves in a live battle.
    def self.messages
      record_before(Game_Message, :add) do |message, args|
        ["message", message.speaker, message.face_name, message.face_index, message.background, message.position, *args]
      end
      MGQ_MpHooks.around(Window_Message, :input_pause, "battles_sync_live messages") do |window, _args, original|
        MGQ_MpBattlesSync.live? && $game_party.in_battle ? Live.pass_message(window) : original.call
      end
    end

    # Records pictures and the battle screen's effects.
    def self.pictures
      PICTURE_METHODS.each do |name|
        record_before(Game_Picture, name) do |picture, args|
          ["picture.#{name}", picture.number, *args] unless name == :erase && picture.name.empty?
        end
      end
      SCREEN_METHODS.select { |name| Game_Screen.method_defined?(name) }.each do |name|
        record_before(Game_Screen, name) { |screen, args| ["screen.#{name}", *args] if screen.equal?($game_troop.screen) }
      end
    end

    # Records every call of Audio, including the sounds the battle log plays directly.
    def self.audio
      owner = Audio.singleton_class
      AUDIO_METHODS.select { |name| owner.method_defined?(name) }.each do |name|
        record_before(owner, name) { |_audio, args| ["audio.#{name}", *args] }
      end
    end

    # Records animations, sprite effects, the skill name and the items a guest's character uses up.
    def self.battlers
      ANIMATION_SETTERS.each do |name|
        kind = "battler.#{name.to_s.chomp('=')}"
        record_before(Game_Battler, name) do |battler, args|
          [kind, battler, args[0]] if args[0] && args[0] != 0 && !Recorder.showing_animation?
        end
      end
      MGQ_MpHooks.around(Game_Battler, :sprite_effect_type=, "battles_sync_live battlers") do |battler, args, original|
        Recorder.sprite_effect(battler, args[0])
        original.call
      end
      [Game_Actor, Game_Enemy].product(EFFECT_METHODS).each do |owner, name|
        MGQ_MpHooks.around(owner, name, "battles_sync_live battlers") do |battler, _args, original|
          result = original.call
          Recorder.sprite_effect(battler, battler.sprite_effect_type)
          result
        end
      end
      record_before(Game_Unit, :display_skill_name=) do |unit, args|
        ["skill_name", unit.equal?($game_party) ? "party" : "troop", args[0]]
      end
      # The host's game uses up nothing of a guest's bag, so the guest's own game is told.
      record_before(Game_MpActor, :consume_item) do |battler, args|
        ["item_used", battler, args[0]] if args[0].is_a?(RPG::Item) && args[0].consumable
      end
    end

    # Records the battle's course: turns, actions, animations and waits, with the values after each
    # action.
    def self.course
      MGQ_MpHooks.around(Scene_Battle, :turn_start, "battles_sync_live course") do |_scene, _args, original|
        Recorder.turn_started
        Recorder.event("turn", $game_troop.turn_count + 1)
        original.call
      end

      # Recorded before the game checks the skip key, which leaves the animation out on this screen only.
      MGQ_MpHooks.around(Scene_Battle, :show_animation, "battles_sync_live course") do |scene, args, original|
        Recorder.event("animation", MGQ_MpGame.get(scene, :subject), args[0], args[1]) if Recorder.active?
        Recorder.showing_animation { original.call }
      end

      record_before(Scene_Battle, :turn_end) { |_scene, _args| ["turn_end"] }

      # The game also comes back here after a party change or a menu in the same phase, which
      # Recorder.command_phase records only once.
      MGQ_MpHooks.around(Scene_Battle, :start_party_command_selection, "battles_sync_live course") do |scene, _args, original|
        unless scene.scene_changing?
          # A co-op party changes between two of the host's sends: here, before the command phase is
          # recorded, when a player left, and once the commands came, when a player swapped.
          Live.open_phase(scene) if MGQ_MpBattlesSync.host?
          Recorder.command_phase
        end
        original.call
      end

      MGQ_MpHooks.around(Scene_Battle, :apply_item_effects, "battles_sync_live course") do |_scene, _args, original|
        result = original.call
        Recorder.values
        result
      end

      MGQ_MpHooks.around(Scene_Battle, :use_item, "battles_sync_live course") do |scene, _args, original|
        Recorder.values
        if Recorder.active?
          subject = MGQ_MpGame.get(scene, :subject)
          action = subject && subject.current_action
          Recorder.event("action", subject, action && action.item, action && action.target_index, action && action.symbol)
        end
        result = original.call
        Recorder.values
        result
      end

      SCENE_WAITS.select { |name| Scene_Battle.method_defined?(name) }.each do |name|
        record_before(Scene_Battle, name) { |_scene, args| ["scene.#{name}", *args] }
      end

      MGQ_MpHooks.around(Scene_Battle, :update_basic, "battles_sync_live course") do |_scene, _args, original|
        Recorder.tick
        original.call
      end

      [:process_victory, :process_defeat, :process_abort].each do |name|
        MGQ_MpHooks.around(BattleManager.singleton_class, name, "battles_sync_live course") do |_manager, _args, original|
          if Recorder.active?
            Recorder.event("end", name.to_s, $game_temp.lose_event_id, $game_temp.lose_event_enemy_id)
            Recorder.flush
          end
          original.call
        end
      end

      MGQ_MpHooks.around(BattleManager.singleton_class, :battle_end, "battles_sync_live course") do |_manager, args, original|
        Recorder.finish(args[0])
        Live.end_phase
        original.call
      end
    end

    # Puts the host's skip settings back as the battle ends, before the victory autosave writes
    # them.
    #
    # An after-hook of its own: after-hooks are rescued one by one, and the course group stops at
    # its first method the game lacks.
    def self.ending
      MGQ_MpHooks.after(BattleManager.singleton_class, :battle_end, "battles_sync_live ending") { |*_args| MGQ_MpBattlesSync.restore_settings }
    end

    # Hooks the live battle's flow on both sides: the start both wait for, the host waiting for the
    # guest's commands, the guest playing the host's stream, forfeits and the end.
    def self.live
      MGQ_MpHooks.around(Scene_Battle, :battle_start, "battles_sync_live live") do |scene, _args, original|
        # A member's battle becomes the leader's to host, or stays the member's own to host.
        MGQ_MpBattlesSync.mode.before_start(scene)
        if MGQ_MpBattlesSync.guest?
          Live.guest_start(scene)
        elsif MGQ_MpBattlesSync.host? && !Live.host_start(scene)
          nil
        else
          Recorder.start(:file) if MGQ_MpBattlesSync.take_file_recording
          Recorder.values
          original.call
        end
      end

      MGQ_MpHooks.around(Scene_Battle, :turn_start, "battles_sync_live live") do |scene, _args, original|
        if MGQ_MpBattlesSync.guest?
          Live.guest_turn(scene)
        elsif MGQ_MpBattlesSync.host?
          # Alone, the host closes the phase too, so the next one settles who fights on.
          if (MGQ_MpBattlesSync.solo? || Live.host_commands(scene)) && !Live.ended_in_wait?(scene)
            Live.close_phase
            original.call
          end
        else
          original.call
        end
      end

      MGQ_MpHooks.around(Scene_Battle, :update, "battles_sync_live live") do |scene, _args, original|
        result = original.call
        Live.watch(scene) if MGQ_MpBattlesSync.live?
        result
      end

      MGQ_MpHooks.around(Scene_Battle, :command_escape, "battles_sync_live live") do |scene, _args, original|
        if Live.escape_leaves?
          Live.forfeit(scene)
        else
          result = original.call
          Live.escaped(scene)
          result
        end
      end

      MGQ_MpHooks.around(BattleManager.singleton_class, :judge_win_loss, "battles_sync_live live") do |_manager, _args, original|
        MGQ_MpBattlesSync.guest? ? false : original.call
      end
    end

    # Hooks the calls whose lines each game writes in its own language: the host records them as
    # calls, the guest makes them itself, see Recorder.call.
    def self.calls
      @log_calls = Window_BattleLog.instance_methods(false).map(&:to_s).grep(LOG_CALL)
      @log_calls.each do |name|
        MGQ_MpHooks.around(Window_BattleLog, name.to_sym, "battles_sync_live calls") do |_log, args, original|
          Recorder.call("log", name, args) { original.call }
        end
      end

      SCENE_CALLS.select { |name| Scene_Battle.method_defined?(name) }.each do |name|
        MGQ_MpHooks.around(Scene_Battle, name, "battles_sync_live calls") do |scene, args, original|
          Recorder.call("scene", name, args, MGQ_MpGame.get(scene, :subject)) { original.call }
        end
      end

      # Who appears is named with each game's own names, so the guest names the host's characters.
      MGQ_MpHooks.around(BattleManager.singleton_class, :battle_start, "battles_sync_live calls") do |_manager, _args, original|
        encounter = Live.encounter
        Live.log_encounter(*encounter) if MGQ_MpBattlesSync.host?
        Recorder.instead("emerge", *encounter) { original.call }
      end

      SKIPPABLE_WAITS.select { |name| Scene_Battle.method_defined?(name) }.each do |name|
        MGQ_MpHooks.around(Scene_Battle, name, "battles_sync_live calls") do |_scene, _args, original|
          original.call unless Playback.skip_wait?
        end
      end
    end

    # Records an event before the original runs.
    #
    # @param owner [Module] The class that has the method.
    # @param name [Symbol] The method.
    # @yieldparam object [Object] The object the method runs on.
    # @yieldparam args [Array] The method's arguments.
    # @yieldreturn [Array, nil] The event's kind and fields, nil to record nothing.
    def self.record_before(owner, name, &event)
      MGQ_MpHooks.around(owner, name, "battles_sync_live record_before") do |object, args, original|
        if Recorder.active?
          fields = event.call(object, args)
          Recorder.event(*fields) if fields
        end
        original.call
      end
    end
  end

  # The steps of a live battle that differ between host and guest.
  module Live
    # Why a live battle ends early, by the reason end_early takes, for Multiplayer InGame.log.
    END_REASONS = {
      :left => "this player left it",
      :forfeit => "the other side forfeited",
      :broken => "it broke off",
      :gone => "the other side is gone",
      :won => "its enemies fell while it waited for commands",
    }

    # What starts the waiting box's names line while the host waits for the players' commands.
    STILL_CHOOSING = "Still choosing: "

    # What starts the waiting box's names line while the host waits for the guests' battles to be
    # ready.
    NOT_READY = "Not ready: "

    # The message the host tells its guests whom it still waits for with: their seats, joined by
    # WAITING_SEPARATOR, "" for nobody.
    WAITING_KIND = "waiting"

    # What separates the seats in a WAITING_KIND message.
    WAITING_SEPARATOR = ","

    # The game's message_skip_mode of the Instant skip, which passes a message at once while the
    # skip is held.
    INSTANT_SKIP = 3

    # Frames a battle message waits before the window's message_pause_input counts, as the game's
    # own message pause waits that long before it reads the buttons.
    SKIP_WAIT_FRAMES = 10

    # As host, waits as Waiting.wait_for does, the box naming the players still waited for, and
    # tells the guests those players as they change, so their own boxes name them too (see
    # host_waits_for). Once the wait is answered the guests hear that nobody is waited for.
    #
    # @param scene [Scene_Battle] The battle.
    # @param text [String] What the game waits for.
    # @param prefix [String] What starts the names line, such as STILL_CHOOSING.
    # @param seats [Proc] Returns the Array<Integer> of the seats still waited for.
    # @yieldreturn [Object, nil] The answer, nil to wait on.
    # @return [Object, Symbol] The answer, an ending of Channel.ending, or :left.
    def self.wait_telling(scene, text, prefix, seats)
      answer = Waiting.wait_for(scene, text, lambda { seats.call.map { |seat| MGQ_MpBattlesSync.seat_name(seat) } }, prefix) do
        tell_waiting(seats.call)
        yield
      end
      tell_waiting([]) unless answer.is_a?(Symbol)
      answer
    end

    # As host of a battle over the world's room, tells the guests whom the host still waits for,
    # when that changed since the last telling, so a guest whose turn waits on the others knows why.
    #
    # @param seats [Array<Integer>] The seats still waited for, none once the wait is answered.
    def self.tell_waiting(seats)
      return unless MGQ_MpBattlesSync.world?

      seats = seats.sort
      return if seats == @told_waiting

      @told_waiting = seats
      Channel.post(WAITING_KIND, seats.join(WAITING_SEPARATOR))
    end

    # As guest, names the players the host still waits for, as the host last told (see
    # tell_waiting), the player themself left out: what their own waiting box names while the
    # host's stream stalls. Over the link nobody, since the friend's game names no seats.
    #
    # @return [Array<String>] Their names, see MGQ_MpBattlesSync.seat_name.
    def self.host_waits_for
      return [] unless MGQ_MpBattlesSync.world?

      while (body = Channel.take(WAITING_KIND))
        @host_waiting = body.split(WAITING_SEPARATOR).map { |seat| seat.to_i }
        MGQ_MpBattlesSync.log("the host still waits for #{@host_waiting.empty? ? 'nobody' : @host_waiting.map { |seat| MGQ_MpBattlesSync.who(seat) }.join(', ')}")
      end
      (Array(@host_waiting) - [MGQ_MpOverworldSync::Me.seat]).map { |seat| MGQ_MpBattlesSync.seat_name(seat) }
    end

    # Forgets whom the host told it waits for, as a battle begins, so an earlier battle's word
    # never names anyone.
    def self.forget_waiting
      @told_waiting = nil
      @host_waiting = nil
    end

    # Moves a battle message on by itself after MESSAGE_FRAMES, at a button, or at once while the
    # message skip is held, so neither player holds the battle up for the other.
    #
    # Returns without the pause and without Input.update while the skip is held, as the game's
    # own message pause does.
    #
    # @param window [Window_Message] The message window.
    def self.pass_message(window)
      return if skip_held?(window)

      window.pause = true
      frames = 0
      begin
        until frames >= MESSAGE_FRAMES || skip_held?(window) || pause_input?(window, frames)
          Fiber.yield
          frames += 1
        end
      rescue FiberError
        MGQ_MpBattlesSync.log_once(:message_fiber, "could not hold a battle message: the message window runs outside a fiber, so it moves on at once")
      end
      Input.update
      window.pause = false
    rescue => e
      MGQ_MpBattlesSync.log_once([:message_pause, e.class.name], "could not hold a battle message, it moves on: #{e.class}: #{e.message}")
      window.pause = false
    end

    # Names the game's message skip button.
    #
    # @return [Symbol] MGQ_MpCoopEvents::SKIP_BUTTON, :X without coop_events.rbx.
    def self.skip_button
      defined?(MGQ_MpCoopEvents::SKIP_BUTTON) ? MGQ_MpCoopEvents::SKIP_BUTTON : :X
    end

    # Reports whether the held message skip passes a battle message at once: always, but during
    # the victory's results only when the game's Skip Battle Results setting is Instant, as the
    # window's message_skip_mode tells.
    #
    # @param window [Window_Message] The message window.
    # @return [Boolean] Whether it does.
    def self.skip_held?(window)
      return false unless Input.press?(skip_button)

      !window.respond_to?(:message_skip_mode) || window.message_skip_mode >= INSTANT_SKIP
    end

    # Reports whether the player's buttons move a battle message on: cancel or confirm at once, and
    # from SKIP_WAIT_FRAMES on whatever the window's message_pause_input reads, such as the held
    # skip in the Slow and Fast result skips or a press of it under No Skip.
    #
    # @param window [Window_Message] The message window.
    # @param frames [Integer] The frames the message waited so far.
    # @return [Boolean] Whether they do.
    def self.pause_input?(window, frames)
      return true if Input.trigger?(:B) || Input.trigger?(:C)

      frames >= SKIP_WAIT_FRAMES && window.respond_to?(:message_pause_input) && window.message_pause_input ? true : false
    end

    # The host waits for the guest's battle, then streams its own. A host who became another
    # battle's guest meanwhile starts as a guest.
    #
    # @param scene [Scene_Battle] The battle.
    # @return [Boolean] Whether the battle starts as the host's, false when it ended early or
    #   started as a guest's.
    def self.host_start(scene)
      formed = MGQ_MpBattlesSync.mode.host_start(scene)
      if formed == :own
        MGQ_MpBattlesSync.log("nobody joined: the battle is the host's own, not live")
        return true
      end
      if formed == :guest
        MGQ_MpBattlesSync.log("the host became a guest of #{MGQ_MpBattlesSync.player}'s battle, which it plays back")
        guest_start(scene)
        return false
      end
      return end_early(scene, formed) if formed.is_a?(Symbol)

      MGQ_MpBattlesSync.show_everything
      Channel.post("ready", MGQ_MpBattlesSync.names)
      @ready = []
      forget_waiting
      MGQ_MpBattlesSync.log("host's battle built, waiting for #{guests_text} to be ready")
      ready = wait_telling(scene, Waiting::WAITING_FOR % MGQ_MpBattlesSync.player, NOT_READY, lambda { not_ready }) { all_ready? }
      return end_early(scene, ready) if ready.is_a?(Symbol)

      MGQ_MpBattlesSync.log("every guest is ready, the host's battle starts and streams")
      Recorder.start(:link)
      true
    end

    # Takes the guests' word that their battle is ready: the one guest's in a PvP battle, every
    # guest's still in a co-op battle or a team duel. host_start empties the guests ready before
    # each wait.
    #
    # @return [Boolean, nil] true once every guest is ready, nil while one is not.
    def self.all_ready?
      return Channel.take("ready") ? true : nil unless MGQ_MpBattlesSync.several?

      MGQ_MpBattlesSync.guests_in.each { |seat| @ready << seat if !@ready.include?(seat) && Channel.take_from("ready", seat) }
      not_ready.empty? ? true : nil
    end

    # Lists the guests still in the battle whose battle is not ready yet, see all_ready?.
    #
    # @return [Array<Integer>] Their seats.
    def self.not_ready
      MGQ_MpBattlesSync.guests_in - Array(@ready)
    end

    # The guest waits for the host's battle, then plays its start.
    #
    # @param scene [Scene_Battle] The battle.
    def self.guest_start(scene)
      Playback.reset
      clear_translation_log(scene)
      # The game marks the party as fighting in on_battle_start, which the guest leaves out with the
      # rest of the battle's logic. Skills usable only in battle check it, and the end clears it.
      MGQ_MpGame.set($game_party, :in_battle, true)
      joined = MGQ_MpBattlesSync.mode.guest_start(scene)
      return end_early(scene, joined) if joined.is_a?(Symbol)

      Channel.post("ready")
      forget_waiting
      MGQ_MpBattlesSync.log("guest's battle built, waiting for #{MGQ_MpBattlesSync.player}'s battle to be ready")
      names = Waiting.wait_for(scene, Waiting::WAITING_FOR % MGQ_MpBattlesSync.player, lambda { host_waits_for }, NOT_READY) { Channel.take("ready") }
      return end_early(scene, names) if names.is_a?(Symbol)

      Names.setup(names)
      MGQ_MpBattlesSync.log("#{MGQ_MpBattlesSync.player}'s battle is ready, playing its start")
      play_until_commands(scene)
    end

    # Starts the battle log of the newer translation's Log command anew.
    #
    # Its own battle_start and turn_start clear it, which the guest leaves out, so it would keep
    # every earlier battle's lines.
    #
    # @param scene [Scene_Battle] The battle.
    def self.clear_translation_log(scene)
      log = MGQ_MpGame.get(scene, :log_window)
      log.ctext_clear if log && log.respond_to?(:ctext_clear)
    end

    # The guest sends its commands and plays the host's turn.
    #
    # @param scene [Scene_Battle] The battle.
    def self.guest_turn(scene)
      MGQ_MpGame.get(scene, :party_command_window).close
      MGQ_MpGame.get(scene, :actor_command_window).close
      MGQ_MpGame.get(scene, :status_window).unselect
      MGQ_MpGame.get(scene, :info_viewport).visible = false
      clear_translation_log(scene)
      commands = Commands.build
      MGQ_MpBattlesSync.log("turn #{MGQ_MpBattlesSync.turn + 1}: sending the commands #{Commands.built}")
      Channel.post("commands", commands)
      play_until_commands(scene)
    end

    # The guest plays the host's stream, then lets its player choose, choose again when a command
    # of theirs lost its target, or ends the battle as the host's ended.
    #
    # @param scene [Scene_Battle] The battle.
    def self.play_until_commands(scene)
      event = Playback.run(scene)
      return end_early(scene, event[0]) if event && event[0].is_a?(Symbol)
      if event && event[0] == "choose_again"
        MGQ_MpBattlesSync.log("the host sends this player back to choose again: a command lost its target to a swap")
        return choose_again(scene)
      end
      if event
        take_defeat_scene(event) if MGQ_MpBattlesSync.same_side?
        return guest_end(event[1], scene)
      end

      # The guest's own battle never reaches the turn's end, and a command phase started in the
      # middle of one keeps the last turn's actions and skips every command.
      BattleManager.turn_end
      Playback.take_encounter
      scene.start_party_command_selection
    end

    # Reads how the host's battle began, which the guest's start shows and its first command phase
    # follows.
    #
    # @return [Array<Boolean>] Whether the party struck first, and whether it was surprised.
    def self.encounter
      [MGQ_MpGame.get(BattleManager, :preemptive) ? true : false, MGQ_MpGame.get(BattleManager, :surprise) ? true : false]
    rescue => e
      MGQ_MpBattlesSync.log_once(:encounter, "could not read how the battle began: #{e.class}: #{e.message}")
      [false, false]
    end

    # Logs how the host's battle began.
    #
    # @param preemptive [Boolean] Whether the party struck first.
    # @param surprise [Boolean] Whether the party was surprised.
    def self.log_encounter(preemptive, surprise)
      began = preemptive ? "with the party striking first" : surprise ? "with the party surprised" : "without a first strike"
      MGQ_MpBattlesSync.log("the host's battle began #{began}")
    end

    # Takes the defeat scene the host's battle chose and its enemy, picking an enemy's scene here
    # when the host's is unknown to this game and a random enemy here when the host names none.
    #
    # The game picks the scene at the battle's start and with each enemy's action, both of which the
    # guest's battle leaves out, and a defeat without a scene raises.
    #
    # @param event [Array] The "end" event: its kind, how the battle ended, the scene's common event
    #   and its enemy.
    def self.take_defeat_scene(event)
      scene_id, enemy_id = event[2], event[3]
      unless defeat_scene?(scene_id)
        MGQ_MpBattlesSync.log("the host's defeat scene #{scene_id.inspect[0, 40]} is unknown here, picking one of an enemy here")
        return pick_defeat_scene(false)
      end
      unless enemy_id.is_a?(Integer)
        enemy = $game_troop.members.sample
        MGQ_MpBattlesSync.log("the host's defeat scene names no enemy (#{enemy_id.inspect[0, 40]}), took #{enemy ? MGQ_MpBattlesSync.named(enemy) : 'none'}")
        enemy_id = enemy && enemy.id
      end
      MGQ_MpBattlesSync.log("defeat scene: common event #{scene_id}, enemy #{enemy_id.inspect}")
      $game_temp.lose_event_id = scene_id
      $game_temp.lose_event_enemy_id = enemy_id
    end

    # Sets the defeat scene of a battle this game did not pick one for: the one it has, when kept
    # and known to this game, else one of a random enemy of the troop whose scene this game knows,
    # else of any enemy, as the game picks one at the battle's start.
    #
    # A guest's own scene is nil or a former battle's, since its battle never ran the game's picks.
    #
    # @param keep_own [Boolean] Whether a scene this game already set stays, as on the host.
    # @return [Boolean] Whether a scene this game knows is set.
    def self.pick_defeat_scene(keep_own)
      return false unless $game_temp.respond_to?(:lose_event_id)
      return true if keep_own && defeat_scene?($game_temp.lose_event_id)

      enemies = $game_troop.members.select { |enemy| enemy.respond_to?(:lose_event_id) }
      enemy = enemies.select { |member| defeat_scene?(member.lose_event_id) }.sample || enemies.sample
      unless enemy
        MGQ_MpBattlesSync.log("no defeat scene: no enemy is left to pick one")
        return false
      end

      $game_temp.lose_event_id = enemy.lose_event_id
      $game_temp.lose_event_enemy_id = enemy.id
      MGQ_MpBattlesSync.log("picked the defeat scene of #{MGQ_MpBattlesSync.named(enemy)}: common event #{enemy.lose_event_id.inspect[0, 40]}")
      defeat_scene?(enemy.lose_event_id)
    rescue => e
      MGQ_MpBattlesSync.log_once(:pick_defeat_scene, "picking a defeat scene failed: #{e.class}: #{e.message}")
      false
    end

    # Reports whether a defeat scene is a common event this game has.
    #
    # @param scene_id [Object] The scene's common event id, as a peer or the game set it.
    # @return [Boolean] Whether it is.
    def self.defeat_scene?(scene_id)
      scene_id.is_a?(Integer) && scene_id > 0 && scene_id < $data_common_events.size && $data_common_events[scene_id] ? true : false
    end

    # Ends the guest's battle the way the host's ended: as it ended in a co-op battle and on the
    # host's side of a team duel, else seen from the other side.
    #
    # @param result [String] How the host's battle ended.
    # @param scene [Scene_Battle] The battle.
    def self.guest_end(result, scene)
      side = MGQ_MpBattlesSync.same_side? ? "on the host's side" : "against the host"
      MGQ_MpBattlesSync.log("the host's battle ended (#{result}), this game fought #{side}")
      if MGQ_MpBattlesSync.same_side?
        return same_end(result) do
          # When the co-op host got away, the guest fights on alone. In a team duel the host gave up
          # or left, and with them the game that computes the duel.
          unless MGQ_MpBattlesSync.mode.take_over(scene)
            MGQ_MpBattlesSync.log("the host left the team duel: it ends without a winner")
            $game_message.add("#{MGQ_MpBattlesSync.player} left the duel.")
            BattleManager.process_abort
          end
        end
      end

      case result
      when "process_victory" then BattleManager.process_defeat
      when "process_defeat" then BattleManager.process_victory
      else
        MGQ_MpBattlesSync.log("#{MGQ_MpBattlesSync.player} gave up or left: this game wins")
        $game_message.add("#{MGQ_MpBattlesSync.player} forfeited.")
        BattleManager.process_victory
      end
    end

    # Ends a guest's battle on the host's side as the host's ended: each game wins or loses with its
    # own rewards or defeat.
    #
    # @param result [String] How the host's battle ended.
    # @yield What follows when the host's battle ended otherwise, as when the host got away.
    def self.same_end(result)
      case result
      when "process_victory" then BattleManager.process_victory
      when "process_defeat" then BattleManager.process_defeat
      else yield
      end
    end

    # The host waits for the guests' commands and gives them to their characters. The wait ends as
    # won once every enemy fell meanwhile, as a Raid World's pools kill them.
    #
    # @param scene [Scene_Battle] The battle.
    # @return [Boolean] Whether the turn goes on.
    def self.host_commands(scene)
      return host_guests_commands(scene) if MGQ_MpBattlesSync.several?

      commands = Waiting.wait_for(scene, "Waiting for #{MGQ_MpBattlesSync.player}'s commands...") do
        $game_troop.all_dead? ? :won : Channel.take("commands")
      end
      return end_early(scene, commands) if commands.is_a?(Symbol)

      Commands.apply(commands)
      MGQ_MpBattlesSync.mode.share_order
      true
    end

    # As host, opens a command phase the first time the game shows the party's commands after a
    # turn: settles who fights on, which re-forms the party, only here. The game shows them again
    # within the same phase after a swap, a menu or choosing again, when the players' commands
    # already count places of the party as it stands.
    #
    # @param scene [Scene_Battle] The battle.
    def self.open_phase(scene)
      return if @phase_open

      @phase_open = true
      @answered = []
      MGQ_MpBattlesSync.log("command phase of turn #{MGQ_MpBattlesSync.turn + 1} opened, #{guests_text} in")
      MGQ_MpBattlesSync.mode.settle(scene)
      # Everyone chooses now, the host too, which a guest done choosing sees while its turn waits.
      tell_waiting(MGQ_MpBattlesSync.guests_in + [MGQ_MpOverworldSync::Me.seat])
    end

    # As host, reports whether the battle ended while the turn waited to start, such as by an
    # ending its wait for commands answered, and logs it; the turn then never starts.
    #
    # @param scene [Scene_Battle] The battle.
    # @return [Boolean] Whether it ended.
    def self.ended_in_wait?(scene)
      return false unless BattleManager.battle_end? || scene.scene_changing?

      MGQ_MpBattlesSync.log("the battle ended before turn #{MGQ_MpBattlesSync.turn + 1} started: the turn is left out")
      true
    end

    # As host, closes the command phase as the turn starts.
    def self.close_phase
      if @phase_open
        MGQ_MpBattlesSync.log("command phase closed, turn #{MGQ_MpBattlesSync.turn + 1} starts" +
                              (MGQ_MpBattlesSync.solo? ? ", the computer playing for those who left" : ""))
      end
      @phase_open = false
      @answered = []
    end

    # As host, closes a command phase the battle ended in, such as by a forfeit or an escape while
    # the players chose, so the next battle's first phase opens anew. Called as the battle ends and
    # as the live battle finishes, which a reset ends it with.
    def self.end_phase
      MGQ_MpBattlesSync.log("command phase of turn #{MGQ_MpBattlesSync.turn + 1} closed: the battle ended in it") if @phase_open
      @phase_open = false
      @answered = []
    end

    # Names the guests still in the live battle for Multiplayer InGame.log.
    #
    # @return [String] Their seats and names, or the friend over the link.
    def self.guests_text
      return MGQ_MpBattlesSync.player.to_s unless MGQ_MpBattlesSync.world?

      seats = MGQ_MpBattlesSync.guests_in
      seats.empty? ? "no guests" : seats.map { |seat| MGQ_MpBattlesSync.who(seat) }.join(", ")
    end

    # The host of a co-op battle or a team duel waits for the commands of every guest still in the
    # battle who has not sent theirs this phase, and gives them to their characters as they come. A
    # guest who left is answered without commands, see MGQ_MpBattles::Mode#left. The players whose
    # commands lost their target to another player's swap choose again. The wait ends as won as in
    # host_commands.
    #
    # @param scene [Scene_Battle] The battle.
    # @return [Boolean] Whether the turn goes on.
    def self.host_guests_commands(scene)
      @answered ||= []
      waiting = MGQ_MpBattlesSync.guests_in - @answered
      unless waiting.empty?
        MGQ_MpBattlesSync.log("waiting for the commands of #{waiting.map { |seat| MGQ_MpBattlesSync.who(seat) }.join(', ')}")
      end
      answer = wait_telling(scene, "Waiting for the party's commands...", STILL_CHOOSING, lambda { waiting }) do
        next :won if $game_troop.all_dead?

        waiting.dup.each do |seat|
          staying = MGQ_MpBattlesSync.guests_in.include?(seat)
          commands = Channel.take_from("commands", seat)
          next unless commands || !staying

          if commands && staying
            Commands.apply(commands, seat)
          else
            MGQ_MpBattlesSync.log("#{MGQ_MpBattlesSync.who(seat)} left, their characters do nothing this turn" +
                                  (commands ? ", the commands they sent before are left out" : ""))
          end
          @answered << seat
          waiting.delete(seat)
        end
        waiting.empty? ? true : nil
      end
      return end_early(scene, answer) if answer.is_a?(Symbol)

      lost = MGQ_MpBattlesSync.mode.lost_targets
      return choose_again_for(scene, lost) unless lost.empty?

      MGQ_MpBattlesSync.mode.share_order
      true
    end

    # As host, makes the characters of the players whose commands lost their target new actions, and
    # sends those still in the battle back to choose again, shown the party as it is now. Waits for
    # the guests' new commands; the characters of those who left do nothing.
    #
    # @param scene [Scene_Battle] The battle.
    # @param seats [Array<Integer>] Their world seats, the host's own and those who left included.
    # @return [Boolean] Whether the turn goes on: false while the host chooses again.
    def self.choose_again_for(scene, seats)
      MGQ_MpBattlesSync.mode.choose_again(seats)
      asked = seats & (MGQ_MpBattlesSync.guests_in + [MGQ_MpOverworldSync::Me.seat])
      MGQ_MpBattlesSync.log("commands of seats #{seats.join(', ')} lost their target to a swap, choosing again: #{asked.empty? ? 'nobody' : asked.join(', ')}")
      return host_guests_commands(scene) if asked.empty?

      @answered -= asked
      # The guests were told the wait was over as it answered; now they choose again, the host too.
      tell_waiting(asked)
      Recorder.event("choose_again", asked)
      Recorder.flush
      return host_guests_commands(scene) unless asked.include?(MGQ_MpOverworldSync::Me.seat)

      choose_again(scene)
      false
    end

    # Sends the player back to choose their commands again, once a character one of them was for
    # was swapped out. Only their own characters' commands start anew, the command phase going on,
    # so neither the enemies nor the other players' characters choose again.
    #
    # @param scene [Scene_Battle] The battle.
    def self.choose_again(scene)
      MGQ_MpChat.system("A character you chose a command for left the Frontline. Choose your commands again.")
      $game_party.battle_members.each { |actor| actor.make_actions unless actor.is_a?(Game_MpActor) }
      BattleManager.clear_actor
      scene.start_party_command_selection
    end

    # Ends the battle when it ended early while this game is not waiting for the friend, such as
    # while its player chooses commands. Called by the battle's every frame.
    #
    # @param scene [Scene_Battle] The battle.
    def self.watch(scene)
      return if MGQ_MpBattlesSync.solo? || scene.scene_changing? || BattleManager.battle_end?

      ending = Channel.ending
      end_early(scene, ending) if ending
    end

    # Ends the battle before its course did.
    #
    # @param scene [Scene_Battle] The battle.
    # @param reason [Symbol] :left when this player left, :won when the enemies fell during the
    #   host's wait for commands, or an ending of Channel.ending.
    # @return [Boolean] true when the battle goes on, with the computer (see
    #   MGQ_MpBattlesSync.friend_gone) or as the game holds its victory back.
    def self.end_early(scene, reason)
      MGQ_MpBattlesSync.log("the live battle ends early in turn #{MGQ_MpBattlesSync.turn}: #{END_REASONS.fetch(reason, reason.to_s)}")
      case reason
      when :won
        return win(scene)
      when :left
        forfeit(scene)
      when :forfeit
        $game_message.add("#{MGQ_MpBattlesSync.player} forfeited.")
        # On the host's side of a team duel, the host's forfeit is the side's.
        MGQ_MpBattlesSync.team? && MGQ_MpBattlesSync.same_side? ? BattleManager.process_defeat : BattleManager.process_victory
      when :broken
        $game_message.add("The live battle broke off.")
        BattleManager.process_abort
      else
        return MGQ_MpBattlesSync.friend_gone(scene)
      end
      false
    end

    # As host, wins the battle whose enemies all fell while it waited for the players' commands,
    # once their collapse played, as the game judges after an action.
    #
    # The game holds its judgement back while one of its own battle actions is still due, and the
    # turn must then start so the battle reaches it instead of standing still.
    #
    # @param scene [Scene_Battle] The battle.
    # @return [Boolean] Whether the battle goes on: true when the game held its judgement back.
    def self.win(scene)
      scene.wait_for_effect if scene.respond_to?(:wait_for_effect)
      BattleManager.judge_win_loss
      return false if BattleManager.battle_end? || scene.scene_changing?

      MGQ_MpBattlesSync.log("the game holds the victory back, the turn starts on the fallen enemies")
      true
    end

    # Leaves a live battle at once: a PvP battle is lost, without the chance of failing; a co-op
    # player leaves the battle, which the others fight on, and loses a story's battle they cannot
    # escape (see story_battle?) with a defeat scene of its enemies, or leaves it as an escape when
    # none of them has one this game knows.
    #
    # @param scene [Scene_Battle] The battle.
    def self.forfeit(scene)
      MGQ_MpGame.get(scene, :info_viewport).visible = false
      # A team duel's guest leaves it, and another player of their side takes their characters over.
      kind = MGQ_MpBattlesSync.coop? || (MGQ_MpBattlesSync.team? && MGQ_MpBattlesSync.guest?) ? "leave" : "forfeit"
      lost = leaving_loses?
      outcome = kind == "leave" ? "the others fight on#{lost ? ', the story counts it as lost here' : ''}" : "the battle is lost"
      MGQ_MpBattlesSync.log("this player leaves the live battle in turn #{MGQ_MpBattlesSync.turn}: #{outcome}")
      Channel.post(kind)
      return BattleManager.process_abort unless lost

      # The guests fight on, so the stream ends as an abort for them; the defeat is this game's alone.
      if Recorder.active?
        Recorder.event("end", "process_abort", $game_temp.lose_event_id, $game_temp.lose_event_enemy_id)
        Recorder.finish(1)
      end
      unless pick_defeat_scene(!MGQ_MpBattlesSync.guest?)
        MGQ_MpBattlesSync.log("no enemy of the battle has a defeat scene here: the player leaves it as an escape")
        return BattleManager.process_abort
      end

      BattleManager.process_defeat
    end

    # Reports whether the battle is one a story event started and the player cannot escape.
    #
    # Ended by an abort, the game counts it as an escape, which such an event has no branch for, so
    # the story would play on as if the battle was won.
    #
    # @return [Boolean] Whether it is.
    def self.story_battle?
      !MGQ_MpGame.get(BattleManager, :event_proc).nil? && !MGQ_MpGame.get(BattleManager, :can_escape)
    end

    # Reports whether leaving the live battle now loses it for the player though the others fight
    # on, see forfeit.
    #
    # @return [Boolean] Whether it does.
    def self.leaving_loses?
      MGQ_MpBattlesSync.coop? && story_battle?
    end

    # Reports whether Escape leaves the live battle at once: in a PvP battle. In a co-op battle each
    # player tries to escape as in any battle, and one who got away leaves it (see escaped).
    #
    # @return [Boolean] Whether it does.
    def self.escape_leaves?
      MGQ_MpBattlesSync.live? && !MGQ_MpBattlesSync.coop?
    end

    # Tells the host that a co-op guest got away, so the others fight on without them. The host's
    # getting away reaches the guests as its battle's end. Called after an escape.
    #
    # @param scene [Scene_Battle] The battle.
    def self.escaped(scene)
      return unless MGQ_MpBattlesSync.live?

      away = scene.scene_changing?
      MGQ_MpBattlesSync.log("tried to escape as #{MGQ_MpBattlesSync.role} in turn #{MGQ_MpBattlesSync.turn}: #{away ? 'got away' : 'failed'}")
      Channel.post("leave") if MGQ_MpBattlesSync.coop? && MGQ_MpBattlesSync.guest? && away
    end
  end
end
