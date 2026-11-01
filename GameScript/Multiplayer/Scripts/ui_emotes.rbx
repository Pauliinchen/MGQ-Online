#----------------------------------------------------------------
#  ui_emotes.rbx
#
#  Changelog:
#      Paulinchen  2026-11-01: Built the emote wheel as a Mod Framework wheel that follows the player
#      Paulinchen  2026-10-31: Defined and steered its wheel through the Mod Framework
#      Paulinchen  2026-10-23: Left the emote wheel's rules to C#, playing the emote in the frame after confirm
#                            - Kept the emote wheel off the live map behind menus
#      Paulinchen  2026-10-12: Logged a refused hotkey through MGQ_MpHotkeys.log_refusal
#                            - Read the map's viewport and character sprites through MGQ_MpGame
#      Paulinchen  2026-10-11: Framed the wheel's boxes in the preset's colors
#                            - Drew the wheel in the shared style with a fade and a close hint
#                            - Drew the hint whole through the shared style
#      Paulinchen  2026-10-08: Closed with the numpad's 0 through MGQ_MpUi.cancel?
#      Paulinchen  2026-10-07: Named players through MGQ_MpOverworldSync.who and took the wheel's depth from MGQ_MpUi
#                            - Logged the emote wheel's actions and refusals
#      Paulinchen  2026-10-06: Kept the wheel shut while the World overview is open
#                            - Ended the emote cooldown when the frame count went back
#                            - Kept the emote pointed at last once the arrows are let go
#                            - Placed the emotes on the directions MGQ_MpWheel spreads them over
#                            - Pointed at an emote with the arrows held like a joystick
#      Paulinchen  2026-10-04: Played an emote's balloon or jump in plain branches
#                            - Created
#
#----------------------------------------------------------------

# The emote wheel on the map: its hotkey (E unless the player binds another, see core_hotkeys.rbx)
# opens a ring of emotes around the player, a jump and the game's balloons, such as a heart or a
# light bulb, on the Mod Framework's wheel. The game's confirm button plays the emote pointed at on
# the player's character, and every other game showing the player's map plays it on the player's
# ghost.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpEmotes
  # An emote of the wheel.
  #
  # @!attribute name [String] What it is, shown below the wheel's ring.
  # @!attribute balloon [Integer, nil] The game's balloon it shows, nil for a jump.
  Emote = Struct.new(:name, :balloon)

  # The wheel's emotes, clockwise from the top, spread over Mod_Framework::UI::Wheel::DIRECTIONS: a jump, then
  # the game's balloons in Balloon.png's rows.
  EMOTES = [
    Emote.new("Jump", nil), Emote.new("Surprise", 1), Emote.new("Question", 2), Emote.new("Music", 3),
    Emote.new("Heart", 4), Emote.new("Anger", 5), Emote.new("Sweat", 6), Emote.new("Idea", 9),
  ]

  # Frames between two emotes of the player, so nobody floods the others with them.
  COOLDOWN_FRAMES = 30

  # The emote wheel's id among the roots of the Mod Framework.
  WHEEL_ID = :mgq_online_emote_wheel

  # What the wheel says while no emote is picked.
  NONE_TEXT = "None"

  # Column of Balloon.png whose balloon is drawn in full.
  BALLOON_FRAME = 7

  # Size of a balloon in the game's Balloon.png.
  BALLOON = 32

  # The emote wheel, see build_wheel.
  @wheel = nil

  # The emotes as the wheel's choices, made once the wheel first asks.
  @choices = nil

  # The emote the wheel took and the frame it did in, nil while none waits.
  @take = nil

  # The frame count of the player's last emote, nil before the first.
  @last = nil

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "emotes"

  # Tells the emote wheel, a ring of the Mod Framework around the player.
  #
  # @return [Mod_Framework::UI::Wheel] The wheel.
  def self.wheel
    @wheel
  end

  # Makes the emote wheel: its hotkey opens it on a free map in a world, the arrows point at an
  # emote, and the emote taken plays in the frame after.
  def self.build_wheel
    @wheel = Mod_Framework::UI::Wheel.new(:id => WHEEL_ID, :follow => :player, :hotkey => MGQ_MpHotkeys.action(:emotes), :none_text => NONE_TEXT,
                                          :if => lambda { MGQ_MpEmotes.busy_reason || true }, :choices => lambda { MGQ_MpEmotes.choices })
    @wheel.on(:open) { log("emote wheel opened") }
    @wheel.on(:close) { |why| log("emote wheel closed: #{why}") }
    @wheel.on(:submit) { |choice| @take = [choice[:data], Mod_Framework::UI::Key.frame] }
  end

  # Lists the emotes as the wheel's choices: a jump as its name, a balloon as its picture.
  #
  # @return [Array<Hash>] Each emote's choice, its place in EMOTES as its data.
  def self.choices
    @choices ||= EMOTES.each_with_index.map do |emote, index|
      choice = { :text => emote.name, :data => index }
      choice[:bitmap] = balloon_of(emote) if emote.balloon
      choice
    end
  end

  # Cuts an emote's balloon out of Balloon.png.
  #
  # @param emote [Emote] The emote.
  # @return [Bitmap, nil] The balloon, nil when the sheet cannot be read, which leaves the name.
  def self.balloon_of(emote)
    Mod_Framework::UI.sheet_cell("Balloon", BALLOON_FRAME, emote.balloon - 1, BALLOON)
  rescue => e
    log_once(:balloon, "the balloons could not be read, so the wheel shows their names: #{e.class}: #{e.message}")
    nil
  end

  # Plays the emote the wheel took in the frame before. Called by the map every frame.
  def self.on_map
    index, frame = @take
    return unless index && frame < Mod_Framework::UI::Key.frame

    @take = nil
    play_own(index) if frame >= Mod_Framework::UI::Key.frame - 1
  rescue => e
    log("emote wheel failed: #{e.class}: #{e.message}")
  end

  # Tells why the player may not play an emote now.
  #
  # @return [String, nil] Why, nil while the player stands free on the map of a world, not held
  #   by the party or a battle that waits.
  def self.busy_reason
    return "no world is open" unless MGQ_MpOverworldSync.in_world?

    reason = Mod_Framework::UI::Game.map_free_reason
    return reason if reason

    MGQ_MpHooks.player_held? ? "the player is held" : nil
  end

  # Plays an emote on the player's character and tells the others, unless the last was too soon.
  #
  # @param index [Integer] The emote's place in EMOTES.
  def self.play_own(index)
    # A loaded save or a new game sets the frame count back, which ends the cooldown too.
    elapsed = @last && Graphics.frame_count - @last
    if elapsed && elapsed >= 0 && elapsed < COOLDOWN_FRAMES
      log("refused #{EMOTES[index].name}: only #{elapsed} of #{COOLDOWN_FRAMES} frames since the last emote")
      return Sound.play_buzzer
    end

    @last = Graphics.frame_count
    play(EMOTES[index], $game_player)
    sent = MGQ_MpOverworldSync.tell(-1, "emote" => index, "map" => $game_map.map_id)
    log("played #{EMOTES[index].name} on map #{$game_map.map_id}, #{sent ? 'told everyone' : 'could not tell the others'}")
  end

  # Takes another player's emote: their ghost plays it, while they are on the player's map.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who played it.
  # @param message [Hash] The message, the emote's place under "emote".
  def self.take(peer, message)
    emote = EMOTES[message["emote"].to_i]
    who = peer ? MGQ_MpOverworldSync.who(peer) : "a game without a state yet"
    return log("ignored emote #{message['emote'].inspect} from #{who}: no such emote") unless emote && message["emote"].to_s =~ /\A\d+\z/
    return log("ignored #{emote.name} from #{who}: no ghost of theirs on this map") unless peer && peer.ghost
    return log("ignored #{emote.name} from #{who}: played on map #{message['map']}, the player is on #{$game_map.map_id}") unless message["map"].to_i == $game_map.map_id

    play(emote, peer.ghost)
    log("#{who} played #{emote.name}")
  rescue => e
    log_once(:take, "playing an emote failed: #{e.class}: #{e.message}")
  end

  # Plays an emote on a character: a jump on the spot, or a balloon above its head.
  #
  # @param emote [Emote] The emote.
  # @param character [Game_Character] The player's character or a ghost.
  def self.play(emote, character)
    if emote.balloon
      character.balloon_id = emote.balloon
    else
      character.jump(0, 0)
    end
  end
end

# What this script takes part in of the world's messages, through overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.route("emote") { |peer, message| MGQ_MpEmotes.take(peer, message) }
rescue => e
  MGQ_MpEmotes.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

# Game hooks, through core_hooks.rbx, and the emote wheel.

begin
  # After the map's update, the emote the wheel took. The game checks its own keys there too, only
  # while no scene change is in the way.
  MGQ_MpHooks.after(Scene_Map, :update_scene, "ui_emotes") { MGQ_MpEmotes.on_map unless scene_changing? }

  MGQ_MpEmotes.build_wheel
rescue => e
  MGQ_MpEmotes.log("hooks FAILED: #{e.class}: #{e.message}")
end
