#----------------------------------------------------------------
#  battles_sync_live.rbx
#
#  Changelog:
#      Paulinchen  2026-10-04: Settled who fights on only as a command phase opens, not each time the game shows the commands again
#                            - Sent the players back to choose again whose commands lost their target to another player's swap
#                            - Renamed from mp_battles_sync_live.rbx
#                            - Gave the guest of a lost co-op battle the defeat scene the host's battle chose, which crashed without one
#      Paulinchen  2026-10-03: Told the one guest of a PvP battle an order of places that changed, as the guests of a co-op battle
#                            - Asked the running battle's mode instead of naming co-op battles and team duels
#                            - Read and wrote the game's private fields and called its private methods through MGQ_MpGame
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
    # The battle log's primitives, which every battle log line goes through.
    LOG_METHODS = [:add_text, :replace_text, :back_one, :back_to, :clear, :clear_popup, :wait]

    # What pictures do, such as a cut-in.
    PICTURE_METHODS = [:show, :move, :rotate, :start_tone_change, :erase]

    # What the screen does, such as a flash, and the darkening while time stands still.
    SCREEN_METHODS = [:start_shake, :start_flash, :start_tone_change, :start_fadeout, :start_fadein, :od_fadein, :od_fadeout]

    # Every sound and piece of music, and the music fading while time stands still.
    AUDIO_METHODS = [:se_play, :me_play, :bgm_play, :bgs_play, :se_stop, :me_stop, :bgm_stop, :bgs_stop,
                     :me_fade, :bgm_fade, :bgs_fade, :start_over_drive, :end_over_drive]

    # The animation a battler starts on its sprite. The sprite clears it again once taken, which is not recorded.
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

    # Installs the hooks, a failing group alone left out. Calling it again does nothing.
    def self.install
      return if @installed
      @installed = true

      [:battle_log, :messages, :pictures, :audio, :battlers, :course, :live, :calls].each do |group|
        begin
          send(group)
        rescue => e
          MGQ_MpBattlesSync.log("#{group} hooks FAILED: #{e.class}: #{e.message}")
        end
      end
    end

    # The battle log's lines and the popups over them.
    def self.battle_log
      LOG_METHODS.each { |name| record_before(Window_BattleLog, name) { |_log, args| ["log.#{name}", *args] } }
      record_before(PopupResults, :push) { |_popups, args| ["popup", *args] }
    end

    # Messages with their face and speaker, such as the lines characters say when they use a skill
    # or fall, which move on by themselves in a live battle.
    #
    # A line names its speaker by name only, which both teams can share.
    def self.messages
      record_before(Game_Message, :add) do |message, args|
        ["message", Recorder.speaker, message.face_name, message.face_index, message.background, message.position, *args]
      end
      MGQ_MpHooks.around(Scene_Battle, :process_skill_word) do |scene, _args, original|
        Recorder.speaking(MGQ_MpGame.get(scene, :subject)) { original.call }
      end
      MGQ_MpHooks.around(Scene_Battle, :process_down_word) do |_scene, args, original|
        Recorder.speaking(args[0]) { original.call }
      end
      MGQ_MpHooks.around(Window_Message, :input_pause) do |window, _args, original|
        next original.call unless MGQ_MpBattlesSync.live? && $game_party.in_battle

        window.pause = true
        frames = 0
        until frames >= MESSAGE_FRAMES || Input.trigger?(:B) || Input.trigger?(:C)
          Fiber.yield
          frames += 1
        end
        Input.update
        window.pause = false
      end
    end

    # Pictures and the battle screen's effects.
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

    # Every call of Audio, including the sounds the battle log plays directly.
    def self.audio
      owner = Audio.singleton_class
      AUDIO_METHODS.select { |name| owner.method_defined?(name) }.each do |name|
        record_before(owner, name) { |_audio, args| ["audio.#{name}", *args] }
      end
    end

    # Animations, sprite effects and the skill name.
    def self.battlers
      ANIMATION_SETTERS.each do |name|
        kind = "battler.#{name.to_s.chomp('=')}"
        record_before(Game_Battler, name) do |battler, args|
          [kind, battler, args[0]] if args[0] && args[0] != 0 && !Recorder.showing_animation?
        end
      end
      MGQ_MpHooks.around(Game_Battler, :sprite_effect_type=) do |battler, args, original|
        Recorder.sprite_effect(battler, args[0])
        original.call
      end
      [Game_Actor, Game_Enemy].product(EFFECT_METHODS).each do |owner, name|
        MGQ_MpHooks.around(owner, name) do |battler, _args, original|
          result = original.call
          Recorder.sprite_effect(battler, battler.sprite_effect_type)
          result
        end
      end
      record_before(Game_Unit, :display_skill_name=) do |unit, args|
        ["skill_name", unit.equal?($game_party) ? "party" : "troop", args[0]]
      end
    end

    # The battle's course as the host records it: turns, actions, animations and waits, with the
    # values after each action.
    def self.course
      MGQ_MpHooks.around(Scene_Battle, :turn_start) do |_scene, _args, original|
        Recorder.turn_started
        Recorder.event("turn", $game_troop.turn_count + 1)
        original.call
      end

      # Recorded before the game checks the skip key, which leaves the animation out on this screen only.
      MGQ_MpHooks.around(Scene_Battle, :show_animation) do |scene, args, original|
        Recorder.event("animation", MGQ_MpGame.get(scene, :subject), args[0], args[1]) if Recorder.active?
        Recorder.showing_animation { original.call }
      end

      record_before(Scene_Battle, :turn_end) { |_scene, _args| ["turn_end"] }

      # The game also comes back here after a party change or a menu in the same phase, which
      # Recorder.command_phase records only once.
      MGQ_MpHooks.around(Scene_Battle, :start_party_command_selection) do |scene, _args, original|
        unless MGQ_MpGame.call(scene, :scene_changing?)
          # A co-op party changes between two of the host's sends: here, before the command phase is
          # recorded, when a player left, and once the commands came, when a player swapped.
          Live.open_phase(scene) if MGQ_MpBattlesSync.host?
          Recorder.command_phase
        end
        original.call
      end

      MGQ_MpHooks.around(Scene_Battle, :apply_item_effects) do |_scene, _args, original|
        result = original.call
        Recorder.values
        result
      end

      MGQ_MpHooks.around(Scene_Battle, :use_item) do |scene, _args, original|
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

      MGQ_MpHooks.around(Scene_Battle, :update_basic) do |_scene, _args, original|
        Recorder.tick
        original.call
      end

      [:process_victory, :process_defeat, :process_abort].each do |name|
        MGQ_MpHooks.around(BattleManager.singleton_class, name) do |_manager, _args, original|
          if Recorder.active?
            Recorder.event("end", name.to_s, $game_temp.lose_event_id, $game_temp.lose_event_enemy_id)
            Recorder.flush
          end
          original.call
        end
      end

      MGQ_MpHooks.around(BattleManager.singleton_class, :battle_end) do |_manager, args, original|
        Recorder.finish(args[0])
        original.call
      end
    end

    # The live battle's flow on both sides: the start both wait for, the host waiting for the
    # guest's commands, the guest playing the host's stream, forfeits and the end.
    def self.live
      MGQ_MpHooks.around(Scene_Battle, :battle_start) do |scene, _args, original|
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

      MGQ_MpHooks.around(Scene_Battle, :turn_start) do |scene, _args, original|
        if MGQ_MpBattlesSync.guest?
          Live.guest_turn(scene)
        elsif MGQ_MpBattlesSync.host? && !MGQ_MpBattlesSync.solo?
          if Live.host_commands(scene)
            Live.close_phase
            original.call
          end
        else
          original.call
        end
      end

      MGQ_MpHooks.around(Scene_Battle, :update) do |scene, _args, original|
        result = original.call
        Live.watch(scene) if MGQ_MpBattlesSync.live?
        result
      end

      MGQ_MpHooks.around(Scene_Battle, :command_escape) do |scene, _args, original|
        if Live.escape_leaves?
          Live.forfeit(scene)
        else
          result = original.call
          Live.escaped(scene)
          result
        end
      end

      MGQ_MpHooks.around(BattleManager.singleton_class, :judge_win_loss) do |_manager, _args, original|
        MGQ_MpBattlesSync.guest? ? false : original.call
      end
    end

    # The calls whose lines each game writes in its own language: the host records them as calls,
    # the guest makes them itself. See Recorder.call.
    def self.calls
      Window_BattleLog.instance_methods(false).map(&:to_s).grep(LOG_CALL).each do |name|
        MGQ_MpHooks.around(Window_BattleLog, name.to_sym) do |_log, args, original|
          Recorder.call("log", name, args) { original.call }
        end
      end

      SCENE_CALLS.select { |name| Scene_Battle.method_defined?(name) }.each do |name|
        MGQ_MpHooks.around(Scene_Battle, name) do |scene, args, original|
          Recorder.call("scene", name, args, MGQ_MpGame.get(scene, :subject)) { original.call }
        end
      end

      # Who appears is named with each game's own names, so the guest names the host's characters.
      MGQ_MpHooks.around(BattleManager.singleton_class, :battle_start) do |_manager, _args, original|
        Recorder.instead("emerge") { original.call }
      end

      SKIPPABLE_WAITS.select { |name| Scene_Battle.method_defined?(name) }.each do |name|
        MGQ_MpHooks.around(Scene_Battle, name) do |_scene, _args, original|
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
      MGQ_MpHooks.around(owner, name) do |object, args, original|
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
    # The host waits for the guest's battle, then streams its own.
    #
    # @param scene [Scene_Battle] The battle.
    # @return [Boolean] Whether the battle starts, false when it ended early.
    def self.host_start(scene)
      close_phase
      formed = MGQ_MpBattlesSync.mode.host_start(scene)
      return true if formed == :own
      return end_early(scene, formed) if formed.is_a?(Symbol)

      MGQ_MpBattlesSync.show_everything
      Channel.post("ready", MGQ_MpBattlesSync.names)
      @ready = []
      ready = Waiting.wait_for(scene, "Waiting for #{MGQ_MpBattlesSync.player}...") { all_ready? }
      return end_early(scene, ready) if ready.is_a?(Symbol)

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
      (MGQ_MpBattlesSync.guests_in - @ready).empty? ? true : nil
    end

    # The guest waits for the host's battle, then plays its start.
    #
    # @param scene [Scene_Battle] The battle.
    def self.guest_start(scene)
      Playback.reset
      # The game marks the party as fighting in on_battle_start, which the guest leaves out with the
      # rest of the battle's logic. Skills usable only in battle check it, and the end clears it.
      MGQ_MpGame.set($game_party, :in_battle, true)
      joined = MGQ_MpBattlesSync.mode.guest_start(scene)
      return end_early(scene, joined) if joined.is_a?(Symbol)

      Channel.post("ready", MGQ_MpBattlesSync.names)
      names = Waiting.wait_for(scene, "Waiting for #{MGQ_MpBattlesSync.player}...") { Channel.take("ready") }
      return end_early(scene, names) if names.is_a?(Symbol)

      Names.setup(names)
      play_until_commands(scene)
    end

    # The guest sends its commands and plays the host's turn.
    #
    # @param scene [Scene_Battle] The battle.
    def self.guest_turn(scene)
      MGQ_MpGame.get(scene, :party_command_window).close
      MGQ_MpGame.get(scene, :actor_command_window).close
      MGQ_MpGame.get(scene, :status_window).unselect
      MGQ_MpGame.get(scene, :info_viewport).visible = false
      Channel.post("commands", Commands.build)
      play_until_commands(scene)
    end

    # The guest plays the host's stream, then lets its player choose, choose again when a command
    # of theirs lost its target, or ends the battle as the host's ended.
    #
    # @param scene [Scene_Battle] The battle.
    def self.play_until_commands(scene)
      event = Playback.run(scene)
      return end_early(scene, event[0]) if event && event[0].is_a?(Symbol)
      return choose_again(scene) if event && event[0] == "choose_again"
      if event
        take_defeat_scene(event) if MGQ_MpBattlesSync.same_side?
        return guest_end(event[1], scene)
      end

      # The guest's own battle never reaches the turn's end, and a command phase started in the
      # middle of one keeps the last turn's actions and skips every command.
      BattleManager.turn_end
      scene.start_party_command_selection
    end

    # Takes the defeat scene the host's battle chose, or one of an enemy here when the host's is
    # unknown to this game.
    #
    # The game picks the scene at the battle's start and with each enemy's action, both of which the
    # guest's battle leaves out, and a defeat without a scene raises.
    #
    # @param event [Array] The "end" event: its kind, how the battle ended, the scene's common event
    #   and its enemy.
    def self.take_defeat_scene(event)
      scene_id, enemy_id = event[2], event[3]
      unless scene_id.is_a?(Integer) && scene_id > 0 && $data_common_events[scene_id]
        enemy = $game_troop.members.sample
        return unless enemy

        scene_id, enemy_id = enemy.lose_event_id, enemy.id
      end
      $game_temp.lose_event_id = scene_id
      $game_temp.lose_event_enemy_id = enemy_id
    end

    # Ends the guest's battle the way the host's ended: as it ended in a co-op battle and on the
    # host's side of a team duel, else seen from the other side.
    #
    # @param result [String] How the host's battle ended.
    # @param scene [Scene_Battle] The battle.
    def self.guest_end(result, scene)
      if MGQ_MpBattlesSync.same_side?
        return same_end(result) do
          # When the co-op host got away, the guest fights on alone. In a team duel the host gave up
          # or left, and with them the game that computes the duel.
          unless MGQ_MpBattlesSync.mode.take_over(scene)
            $game_message.add("#{MGQ_MpBattlesSync.player} left the duel.")
            BattleManager.process_abort
          end
        end
      end

      case result
      when "process_victory" then BattleManager.process_defeat
      when "process_defeat" then BattleManager.process_victory
      else
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

    # The host waits for the guests' commands and gives them to their characters.
    #
    # @param scene [Scene_Battle] The battle.
    # @return [Boolean] Whether the turn goes on.
    def self.host_commands(scene)
      return host_guests_commands(scene) if MGQ_MpBattlesSync.several?

      commands = Waiting.wait_for(scene, "Waiting for #{MGQ_MpBattlesSync.player}'s commands...") { Channel.take("commands") }
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
      MGQ_MpBattlesSync.mode.settle(scene)
    end

    # As host, closes the command phase, as the turn starts or the battle begins.
    def self.close_phase
      @phase_open = false
      @answered = []
    end

    # The host of a co-op battle or a team duel waits for the commands of every guest still in the
    # battle who has not sent theirs this phase, and gives them to their characters as they come. A
    # guest who left sends none, and the computer plays their characters. The players whose
    # commands lost their target to another player's swap choose again.
    #
    # @param scene [Scene_Battle] The battle.
    # @return [Boolean] Whether the turn goes on.
    def self.host_guests_commands(scene)
      @answered ||= []
      waiting = MGQ_MpBattlesSync.guests_in - @answered
      answer = Waiting.wait_for(scene, "Waiting for the party's commands...") do
        waiting.dup.each do |seat|
          commands = Channel.take_from("commands", seat)
          next unless commands || !MGQ_MpBattlesSync.guests_in.include?(seat)

          Commands.apply(commands, seat) if commands
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

    # As host, gives the characters of the players whose commands lost their target the computer's
    # commands, and sends those still in the battle back to choose again, shown the party as it is
    # now. Waits for the guests' new commands; for those who left, the computer's stay.
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
      return if MGQ_MpBattlesSync.solo? || MGQ_MpGame.call(scene, :scene_changing?) || BattleManager.battle_end?

      ending = Channel.ending
      end_early(scene, ending) if ending
    end

    # Ends the battle before its course did.
    #
    # @param scene [Scene_Battle] The battle.
    # @param reason [Symbol] :left when this player left, or an ending of Channel.ending.
    # @return [Boolean] true when the battle goes on with the computer, see MGQ_MpBattlesSync.friend_gone.
    def self.end_early(scene, reason)
      case reason
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

    # Leaves a live battle at once: a PvP battle is lost, without the chance of failing; a co-op
    # player leaves the battle, which the others fight on.
    #
    # @param scene [Scene_Battle] The battle.
    def self.forfeit(scene)
      MGQ_MpGame.get(scene, :info_viewport).visible = false
      # A team duel's guest leaves it, and another player of their side takes their characters over.
      Channel.post(MGQ_MpBattlesSync.coop? || (MGQ_MpBattlesSync.team? && MGQ_MpBattlesSync.guest?) ? "leave" : "forfeit")
      BattleManager.process_abort
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
      Channel.post("leave") if MGQ_MpBattlesSync.coop? && MGQ_MpBattlesSync.guest? && MGQ_MpGame.call(scene, :scene_changing?)
    end
  end
end
