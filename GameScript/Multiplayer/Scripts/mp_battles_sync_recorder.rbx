#----------------------------------------------------------------
#  mp_battles_sync_recorder.rbx
#
#  Changelog:
#      Paulinchen  2026-10-03: Recorded the characters outside the battle that its mode names
#                            - Read and wrote the game's private fields and called its private methods through MGQ_MpGame
#                            - Created
#
#----------------------------------------------------------------

# The host's side of a live battle's stream: what the host's battle shows, recorded as events
# for the guests or for a mirror match's file. It builds on mp_battles_sync.rbx.

module MGQ_MpBattlesSync
  # Everything the host's battle shows, in the order it shows it: battle log lines, popups,
  # messages, pictures, screen effects, sounds, animations, sprite effects and waits, with the
  # battlers' values after every action. A live battle streams it to the guest, a mirror match
  # writes it to RECORDING_FILE.
  module Recorder
    # Events kept before a mirror match writes them to the file.
    FLUSH_EVENTS = 200

    # The events only the recording on file keeps, which no guest plays.
    FILE_ONLY = ["action", "turn_end"]

    # Seeds a call's random choices are drawn from.
    SEED_RANGE = 1 << 30

    # Reports whether the battle on screen is recorded.
    #
    # @return [Boolean] Whether the battle is recorded.
    def self.active?
      @active ? true : false
    end

    # Starts recording a battle.
    #
    # @param sink [Symbol] :link to stream it to the guest, :file to write it over the last
    #   mirror match's recording.
    def self.start(sink)
      @active = true
      @sink = sink
      @command_phase = false
      @frame = 0
      @events = []
      @values = {}
      @file_mode = "wb"
      event("battle", "settings", display_settings) if sink == :file
    rescue => e
      stop_after(e)
    end

    # Ends the recording and sends or writes what is left.
    #
    # @param result [Integer] The game's battle result.
    def self.finish(result)
      return unless active?

      event("battle_end", result)
      flush
      @active = false
    rescue => e
      stop_after(e)
    end

    # Counts a frame, and streams what the battle showed every SEND_FRAMES frames.
    def self.tick
      return unless active?

      @frame += 1
      flush if @sink == :link && @frame % SEND_FRAMES == 0
    end

    # Records an event, unless a call that the guest makes itself is running.
    #
    # @param kind [String] What happened.
    # @param fields [Array] Its values, see Wire.line.
    def self.event(kind, *fields)
      return unless active? && !muted?
      return if @sink == :link && FILE_ONLY.include?(kind)

      line = Wire.line([kind] + fields)
      @events << (@sink == :file ? "#{@frame.to_s.rjust(6)}\t#{line}" : line)
      flush if @events.size >= FLUSH_EVENTS
    rescue => e
      stop_after(e)
    end

    # Records the values of every battler that changed since the last time. The next send streams
    # them, every SEND_FRAMES frames, so the guest can tell by the sends waiting how far behind it is.
    #
    # @param full [Boolean] true to record every battler's, which corrects anything the guest
    #   missed; the host does at every command phase.
    def self.values(full = false)
      return unless active? && !muted?

      @values = {} if full
      battlers.each do |battler|
        current = value_fields(battler)
        next if @values[battler.object_id] == current

        @values[battler.object_id] = current
        event("values", battler, *current)
      end
      time_stop
    rescue => e
      stop_after(e)
    end

    # Records the start of a command phase once, with every battler's values, and sends it at once.
    # With none of its characters able to act, the host's game skips its own commands and waits for
    # the guest's within the same call, so the guest must hear of the phase before.
    def self.command_phase
      return unless active? && !@command_phase

      @command_phase = true
      values(true)
      event("commands")
      flush
    rescue => e
      stop_after(e)
    end

    # Ends the command phase, so the next one is recorded. Called as a turn starts.
    def self.turn_started
      @command_phase = false
    end

    # Records how long time stands still and for whom, when it changed. It decides who may act,
    # so the guest needs it to offer only the commands the host will take.
    def self.time_stop
      current = [$game_party.od_turn.to_i, $game_party.od_user]
      return if @time_stop == [current[0], current[1].object_id]

      @time_stop = [current[0], current[1].object_id]
      event("time_stop", *current)
    end

    # Records a call the guest makes itself with its own game's texts: the method and its
    # arguments, the action results it reads and the seed its random choices come from, such as
    # the line a character says. What the call does is left out of the recording, since the
    # guest's call does the same. A call with an argument that cannot travel is recorded as what
    # it does instead.
    #
    # @param receiver [String] "log" for the battle log, "scene" for the battle.
    # @param name [String] The method.
    # @param args [Array] Its arguments.
    # @param subject [Game_Battler, nil] Who acts, which a call of the battle reads.
    # @return [Object] What the block returns.
    def self.call(receiver, name, args, subject = nil)
      return yield unless active? && !muted? && Wire.encodable?(args)

      values
      seed = rand(SEED_RANGE)
      event("call", receiver, name.to_s, seed, subject, results_of(args), *args)
      seeded(seed) { muted { yield } }
    end

    # Records an event and leaves out what the block does, which the guest does its own way.
    #
    # @param kind [String] What happened.
    # @return [Object] What the block returns.
    def self.instead(kind)
      event(kind)
      muted { yield }
    end

    # Leaves out every event the block records.
    #
    # @return [Object] What the block returns.
    def self.muted
      @muted = (@muted || 0) + 1
      yield
    ensure
      @muted -= 1
    end

    # Tells whether events are left out.
    #
    # @return [Boolean] Whether a call the guest makes itself is running.
    def self.muted?
      (@muted || 0) > 0
    end

    # Runs the battle's own showing of an animation, which is recorded as one event, so the
    # animation it starts on each target is not recorded a second time.
    #
    # @yield The game's method.
    # @return [Object] What the block returns.
    def self.showing_animation
      @showing_animation = true
      yield
    ensure
      @showing_animation = false
    end

    # Tells whether the battle's own showing of an animation is running.
    #
    # @return [Boolean] Whether it is.
    def self.showing_animation?
      @showing_animation ? true : false
    end

    # Runs a block with the random numbers following a seed, so the guest's call makes the same
    # random choices, then goes on with random numbers the seed does not predict.
    #
    # @param seed [Integer] The seed.
    # @return [Object] What the block returns.
    def self.seeded(seed)
      resume = rand(SEED_RANGE)
      srand(seed)
      yield
    ensure
      srand(resume)
    end

    # Lists the action results of the battlers among a call's arguments, which the battle log reads.
    #
    # @param args [Array] The arguments.
    # @return [Array<Array>] Each battler with its result.
    def self.results_of(args)
      battlers = args.flatten.select { |arg| arg.is_a?(Game_Battler) }.uniq
      battlers.map { |battler| [battler, battler.result] }.select { |_, result| result.is_a?(Game_ActionResult) }
    end

    # Records a sprite effect a battler starts, after the battlers' values, since the guest needs a
    # hit's HP and a defeat's death before it shows the effect.
    #
    # @param battler [Game_Battler] The battler.
    # @param effect [Symbol, nil] The effect, nil for none.
    def self.sprite_effect(battler, effect)
      return unless active? && !muted? && effect

      values
      event("battler.sprite_effect_type", battler, effect)
    end

    # Names the battler who speaks.
    #
    # @return [Game_Battler, nil] The battler whose line the game is showing.
    def self.speaker
      @speaker
    end

    # Marks a battler as the speaker of the lines the block shows.
    #
    # @param battler [Game_Battler] The battler.
    # @return [Object] What the block returns.
    def self.speaking(battler)
      @speaker = battler
      yield
    ensure
      @speaker = nil
    end

    # Names a battler by its side and place, "a0" for the party's first, "e0" for the troop's, or as
    # the battle's mode names a character outside the battle.
    #
    # @param battler [Game_Battler] A battler, or the stand-in the game uses for automatic skills.
    # @return [String] The reference, "?" for a battler the battle does not know.
    def self.ref(battler)
      battler = battler.observer if defined?(Game_Master) && battler.is_a?(Game_Master)
      party = $game_party.battle_members.index(battler)
      return "a#{party}" if party

      troop = $game_troop.members.index(battler)
      troop ? "e#{troop}" : (MGQ_MpBattlesSync.mode.reserve_ref(battler) || "?")
    end

    # Sends or writes the kept events.
    def self.flush
      return if @events.empty?

      if @sink == :link
        Channel.post("events", @events.join("\n"))
      else
        File.open(MGQ_Multiplayer.path(RECORDING_FILE), @file_mode) { |file| file.write(@events.join("\n") + "\n") }
        @file_mode = "ab"
      end
      @events = []
    end

    # Reads the host's display settings.
    #
    # @return [Array] The host's settings that leave parts of a battle unshown.
    def self.display_settings
      (SKIP_SETTINGS + [:bt_wait]).map { |key| "#{key}=#{$game_system.conf[key].inspect}" }
    end

    # Lists the battlers of the battle.
    #
    # @return [Array<Game_Battler>] Every battler of the battle, and the characters outside it the stream names.
    def self.battlers
      MGQ_MpBattlesSync.party_side + MGQ_MpBattlesSync.troop_side
    end

    # Reads the values the stream carries of a battler.
    #
    # @param battler [Game_Battler] The battler.
    # @return [Array] Its HP and maximum, MP and maximum, SP, state ids and buffs.
    def self.value_fields(battler)
      [battler.hp, battler.mhp, battler.mp, battler.mmp, battler.tp.to_i,
       battler.states.map(&:id).sort, Array(MGQ_MpGame.get(battler, :buffs)).map(&:to_i)]
    end

    # Stops recording without sending or writing what is left, such as after a reset.
    def self.stop
      @active = false
      @events = []
    end

    # Stops recording after an error, which stays in InGame.log, and breaks a live battle off, since
    # the guest sees nothing but the stream.
    #
    # @param error [Exception] The error.
    def self.stop_after(error)
      @active = false
      MGQ_MpBattlesSync.log("recording stopped: #{error.class}: #{error.message}")
      MGQ_MpBattlesSync.break_off("the host's recording stopped") if @sink == :link
    end
  end
end
