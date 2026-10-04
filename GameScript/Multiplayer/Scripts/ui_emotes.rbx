#----------------------------------------------------------------
#  ui_emotes.rbx
#
#  Changelog:
#      Paulinchen  2026-10-04: Created
#
#----------------------------------------------------------------

# The emote wheel on the map: its key (E unless the player binds another, see core_hotkeys.rbx)
# opens a ring of emotes around the player, a jump and the game's balloons, such as a heart or a
# light bulb. The arrows go round the ring, the game's confirm button plays the emote on the
# player's character, and every other game showing the player's map plays it on the player's
# ghost. It builds on overworld_sync.rbx, which knows the other players.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpEmotes
  # An emote of the wheel.
  #
  # @!attribute name [String] What it is, for the wheel's hint.
  # @!attribute balloon [Integer, nil] The game's balloon it shows, nil for a jump.
  Emote = Struct.new(:name, :balloon)

  # The wheel's emotes, clockwise from the top: a jump, then the game's balloons in Balloon.png's
  # rows.
  EMOTES = [
    Emote.new("Jump", nil), Emote.new("Surprise", 1), Emote.new("Question", 2), Emote.new("Music", 3),
    Emote.new("Heart", 4), Emote.new("Anger", 5), Emote.new("Sweat", 6), Emote.new("Idea", 9),
  ]

  # Frames between two emotes of the player, so nobody floods the others with them.
  COOLDOWN_FRAMES = 30

  @open = false
  @selected = 0
  @last = nil

  extend MGQ_MpLog

  # What starts this script's lines in the mod's InGame.log.
  LOG_TAG = "emotes"

  # Reports whether the wheel is open.
  #
  # @return [Boolean] Whether it is.
  def self.open?
    @open
  end

  # The place of the picked emote in EMOTES.
  #
  # @return [Integer] The place.
  def self.selected
    @selected
  end

  # Opens the wheel on the emote picked last, holding the buttons.
  def self.open
    @open = true
    MGQ_Multiplayer::Capture.start(:emotes)
    Sound.play_cursor
  end

  # Closes the wheel, if it is open, and gives the buttons back.
  def self.close
    return unless @open

    @open = false
    MGQ_Multiplayer::Capture.stop(:emotes)
  end

  # Reports whether the player may play an emote: on a quiet map, not held by the party or a
  # battle that waits, and with no other screen of the mod over the map.
  #
  # @return [Boolean] Whether they may.
  def self.free?
    MGQ_MpOverworldSync.in_world? && MGQ_MpOverworldSync.map_quiet? && !MGQ_MpHooks.player_held? &&
      !MGQ_MpActions::Wheel.open? && !MGQ_MpChat.typing?
  end

  # Opens, steers or closes the wheel. Called by the map every frame, so a press of the key is seen
  # once.
  def self.on_map
    key = MGQ_MpHotkeys.pressed?(:emotes)
    return close unless free?

    if @open
      update(key)
    elsif key
      open
    end
  rescue => e
    log("emote wheel failed: #{e.class}: #{e.message}")
    close
  end

  # Goes round the ring with the arrows, plays the picked emote on confirm, and closes on cancel or
  # the wheel's key.
  #
  # @param key [Boolean] Whether the wheel's key went down this frame.
  def self.update(key)
    capture = MGQ_Multiplayer::Capture
    if key || capture.trigger?(:B)
      close
      return Sound.play_cancel
    end

    step = (capture.repeat?(:RIGHT) || capture.repeat?(:DOWN) ? 1 : 0) - (capture.repeat?(:LEFT) || capture.repeat?(:UP) ? 1 : 0)
    if step != 0
      @selected = (@selected + step) % EMOTES.size
      Sound.play_cursor
    end
    return unless capture.trigger?(:C)

    close
    play_own(@selected)
  end

  # Plays an emote on the player's character and tells the others, unless the last was too soon.
  #
  # @param index [Integer] The emote's place in EMOTES.
  def self.play_own(index)
    if @last && Graphics.frame_count - @last < COOLDOWN_FRAMES
      return Sound.play_buzzer
    end

    @last = Graphics.frame_count
    play(EMOTES[index], $game_player)
    MGQ_MpOverworldSync.tell(-1, "emote" => index, "map" => $game_map.map_id)
  end

  # Takes another player's emote: their ghost plays it, while they are on the player's map.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who played it.
  # @param message [Hash] The message, the emote's place under "emote".
  def self.take(peer, message)
    emote = EMOTES[message["emote"].to_i]
    return unless emote && message["emote"].to_s =~ /\A\d+\z/ && peer && peer.ghost
    return unless message["map"].to_i == $game_map.map_id

    play(emote, peer.ghost)
  rescue => e
    log_once(:take, "playing an emote failed: #{e.class}: #{e.message}")
  end

  # Plays an emote on a character: a jump on the spot, or a balloon above its head.
  #
  # @param emote [Emote] The emote.
  # @param character [Game_Character] The player's character or a ghost.
  def self.play(emote, character)
    emote.balloon ? character.balloon_id = emote.balloon : character.jump(0, 0)
  end
end

# The emote wheel around the player: a box per emote in a ring, the picked one lit, with its name
# below the ring.
class Sprite_MpEmoteWheel < Sprite
  # Size of an emote's box.
  BOX = 36

  # Pixels from the middle of the player's sprite to the middle of each box.
  RADIUS = 60

  # Height of the line naming the picked emote.
  NAME_HEIGHT = 22

  # Width and height of the wheel's picture.
  SIZE = (RADIUS + BOX) * 2

  # Half the height of the player's sprite, from their feet to their middle.
  PLAYER_MIDDLE = 24

  # Size of a balloon in the game's Balloon.png.
  BALLOON = 32

  # Column of Balloon.png whose balloon is drawn in full.
  BALLOON_FRAME = 7

  # Background of a box.
  BACK = Color.new(0, 0, 0, 170)

  # Background of the picked box.
  PICKED_BACK = Color.new(48, 96, 176, 220)

  # Creates the wheel, hidden.
  #
  # @param viewport [Viewport] The map's topmost viewport.
  def initialize(viewport)
    super(viewport)
    self.bitmap = Bitmap.new(SIZE, SIZE + NAME_HEIGHT)
    self.ox = SIZE / 2
    self.oy = SIZE / 2 + PLAYER_MIDDLE
    self.z = 300
    self.visible = false
    @shown = nil
  end

  # Draws the wheel around the player's sprite while it is open, if the picked emote changed.
  #
  # @param sprite [Sprite_Character, nil] The player's sprite.
  def show(sprite)
    self.visible = MGQ_MpEmotes.open? && !sprite.nil?
    return unless visible

    self.x = sprite.x
    self.y = sprite.y
    return if @shown == MGQ_MpEmotes.selected

    @shown = MGQ_MpEmotes.selected
    bitmap.clear
    MGQ_MpEmotes::EMOTES.each_with_index { |emote, index| draw_box(emote, index) }
    bitmap.font.size = 18
    bitmap.font.outline = true
    bitmap.draw_text(0, SIZE, SIZE, NAME_HEIGHT, MGQ_MpEmotes::EMOTES[@shown].name, 1)
  end

  # Draws one emote's box on the ring, clockwise from the top.
  #
  # @param emote [MGQ_MpEmotes::Emote] The emote.
  # @param index [Integer] Its place on the ring.
  def draw_box(emote, index)
    angle = Math::PI * 2 * index / MGQ_MpEmotes::EMOTES.size
    x = (SIZE / 2 + Math.sin(angle) * RADIUS - BOX / 2).round
    y = (SIZE / 2 - Math.cos(angle) * RADIUS - BOX / 2).round
    bitmap.fill_rect(x, y, BOX, BOX, index == @shown ? PICKED_BACK : BACK)
    if emote.balloon
      source = Rect.new(BALLOON_FRAME * BALLOON, (emote.balloon - 1) * BALLOON, BALLOON, BALLOON)
      bitmap.blt(x + (BOX - BALLOON) / 2, y + (BOX - BALLOON) / 2, Cache.system("Balloon"), source)
    else
      bitmap.font.size = 14
      bitmap.font.outline = true
      bitmap.draw_text(x, y, BOX, BOX, emote.name, 1)
    end
  end

  # Frees the wheel's picture.
  def dispose
    bitmap.dispose
    super
  end
end

# What this script takes part in of the world's messages, through overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.route("emote") { |peer, message| MGQ_MpEmotes.take(peer, message) }
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpEmotes.close unless in_world && SceneManager.scene.is_a?(Scene_Map) }
rescue => e
  MGQ_MpEmotes.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

# What the emote wheel adds to the action wheel, through ui_actions.rbx: the action wheel leaves the
# buttons to it while it is open.

begin
  MGQ_MpActions.cover { |_wheel_key| MGQ_MpEmotes.open? }
rescue => e
  MGQ_MpEmotes.log("action wheel FAILED: #{e.class}: #{e.message}")
end

# Game hooks, through core_hooks.rbx.

begin
  # After the map's update, the emote wheel. The game checks its own keys there too, only while no
  # scene change is in the way.
  MGQ_MpHooks.after(Scene_Map, :update_scene, "ui_emotes") { MGQ_MpEmotes.on_map unless scene_changing? }

  # After the map's sprites, the emote wheel around the player.
  MGQ_MpHooks.after(Spriteset_Map, :update, "ui_emotes") do
    @mgq_mp_emotes ||= Sprite_MpEmoteWheel.new(@viewport3)
    @mgq_mp_emotes.show(@character_sprites.find { |sprite| sprite.character.equal?($game_player) })
  end

  MGQ_MpHooks.before(Spriteset_Map, :dispose, "ui_emotes") do
    @mgq_mp_emotes.dispose if @mgq_mp_emotes
    @mgq_mp_emotes = nil
  end
rescue => e
  MGQ_MpEmotes.log("hooks FAILED: #{e.class}: #{e.message}")
end
