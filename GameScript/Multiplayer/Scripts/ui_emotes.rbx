#----------------------------------------------------------------
#  ui_emotes.rbx
#
#  Changelog:
#      Paulinchen  2026-11-06: Took the wheel's emotes, the cooldown and which emotes of others play from the rules in C#
#      Paulinchen  2026-11-06: Built the emote wheel as a wheel of the Mod Framework's UI layer, its hotkey declared on its class
#      Paulinchen  2026-11-05: Read the emote's place as a number
#                            - Counted the emote's cooldown by the bridge's frame
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
# light bulb, on a wheel of the Mod Framework's UI layer. The game's confirm button plays the emote
# pointed at on the player's character, and every other game showing the player's map plays it on
# the player's ghost. The rules in C# (Emotes) name the emotes, keep the cooldown and tell which
# emotes of others play.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpEmotes
  # An emote of the wheel.
  #
  # @!attribute name [String] What it is, shown below the wheel's ring.
  # @!attribute balloon [Integer, nil] The game's balloon it shows, nil for a jump.
  Emote = Struct.new(:name, :balloon)

  # The topic that lists the wheel's emotes.
  LIST_TOPIC = "emote.list"

  # The topic that plays an emote of the player unless the last was too soon.
  PLAY_TOPIC = "emote.play"

  # The topic that tells whether another player's ghost plays their emote.
  TAKE_TOPIC = "emote.take"

  # The emote wheel's id among the roots of the Mod Framework.
  WHEEL_ID = :mgq_online_emote_wheel

  # What the wheel says while no emote is picked.
  NONE_TEXT = "None"

  # Column of Balloon.png whose balloon is drawn in full.
  BALLOON_FRAME = 7

  # Size of a balloon in the game's Balloon.png.
  BALLOON = 32

  # Whether the emote wheel is open, which other scripts ask, see wheel.
  @wheel = nil

  # The emotes as the wheel's choices, made once the wheel first asks.
  @choices = nil

  # The emote the wheel took and the frame it did in, nil while none waits.
  @take = nil

  # The wheel's emotes, as the DLL lists them once the wheel first asks.
  @emotes = nil

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "emotes"

  # The emote wheel: its hotkey opens it on a free map in a world, a ring of the emotes around the
  # player that the arrows point at, "None" while none is picked; the emote taken plays in the frame
  # after.
  class EmoteWheel < Mod_Framework::UI::Component
    hotkey MGQ_MpHotkeys.action(:emotes)

    # Describes the wheel.
    def render
      emotes = MGQ_MpEmotes
      wheel id: WHEEL_ID, look: :ring, follow: :player, none_text: NONE_TEXT, if: -> { emotes.busy_reason || true }, choices: emotes.choices,
            on_open: -> { emotes.opened }, on_submit: ->(choice) { emotes.taken(choice) }, on_close: ->(why) { emotes.closed(why) }
    end
  end

  # Tells whether the emote wheel is open.
  #
  # @return [MGQ_MpActions::OpenState] The wheel's state.
  def self.wheel
    @wheel ||= MGQ_MpActions::OpenState.new
  end

  # Notes that the emote wheel opened.
  def self.opened
    wheel.open = true
    log("emote wheel opened")
  end

  # Notes that the emote wheel closed.
  #
  # @param why [Symbol, String] Why.
  def self.closed(why)
    wheel.open = false
    log("emote wheel closed: #{why}")
  end

  # Takes the emote the wheel took, which plays in the frame after.
  #
  # @param choice [Hash] The wheel's choice, its place among the emotes as its data.
  def self.taken(choice)
    @take = [choice[:data], MGQ_Multiplayer::Bridge.frame_number]
  end

  # Lists the wheel's emotes, clockwise from the top, as the DLL lists them (topic emote.list).
  #
  # @return [Array<Emote>] The emotes.
  def self.emotes
    @emotes ||= Array(MGQ_Multiplayer::Bridge.call!(LIST_TOPIC)).map { |name, balloon| Emote.new(name, balloon) }
  end

  # Lists the emotes as the wheel's choices: a jump as its name, a balloon as its picture.
  #
  # @return [Array<Hash>] Each emote's choice, its place among the emotes as its data.
  def self.choices
    @choices ||= emotes.each_with_index.map do |emote, index|
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
    now = MGQ_Multiplayer::Bridge.frame_number
    return unless index && frame < now

    @take = nil
    play_own(index) if frame >= now - 1
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

  # Plays an emote on the player's character and tells the others, unless the DLL refuses it
  # (topic emote.play), such as when the last was too soon.
  #
  # @param index [Integer] The emote's place among the emotes.
  def self.play_own(index)
    refusal = MGQ_Multiplayer::Bridge.call!(PLAY_TOPIC, index)
    if refusal
      log("refused #{refusal}")
      return Sound.play_buzzer
    end

    play(emotes[index], $game_player)
    sent = MGQ_MpOverworldSync.tell(-1, "emote" => index, "map" => $game_map.map_id)
    log("played #{emotes[index].name} on map #{$game_map.map_id}, #{sent ? 'told everyone' : 'could not tell the others'}")
  end

  # Takes another player's emote: their ghost plays it unless the DLL tells why not (topic
  # emote.take), such as when they are on another map.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who played it.
  # @param message [Hash] The message, the emote's place under "emote".
  def self.take(peer, message)
    index = message["emote"]
    who = peer ? MGQ_MpOverworldSync.who(peer) : "a game without a state yet"
    why = MGQ_Multiplayer::Bridge.call!(TAKE_TOPIC, "emote" => index.is_a?(Integer) ? index : nil, "map" => message["map"].to_i,
                                                     "own_map" => $game_map.map_id, "ghost" => peer && peer.ghost ? true : false)
    return log("ignored #{why} from #{who}") if why

    play(emotes[index], peer.ghost)
    log("#{who} played #{emotes[index].name}")
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

# Game hooks, through core_hooks.rbx.

begin
  # After the map's update, the emote the wheel took. The game checks its own keys there too, only
  # while no scene change is in the way.
  MGQ_MpHooks.after(Scene_Map, :update_scene, "ui_emotes") { MGQ_MpEmotes.on_map unless scene_changing? }
rescue => e
  MGQ_MpEmotes.log("hooks FAILED: #{e.class}: #{e.message}")
end
