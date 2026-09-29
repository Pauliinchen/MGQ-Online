#----------------------------------------------------------------
#  mp_overworld.rb
#
#  Changelog:
#      Paulinchen  2026-09-29: Created
#
#----------------------------------------------------------------

# The other players of the open world on the map: each game tells the others where its player
# stands, how they look and whether they are on the map, in a battle, a menu or an event, and
# shows the players on the same map as ghosts with their names, which walk through everything and
# trigger nothing. A line at the bottom left tells who came and went.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpOverworld
  # Icons of the game's icon set next to a ghost's name, by what its player does.
  STATE_ICONS = { "battle" => 451, "event" => 4, "menu" => 183 }

  # Tiles a ghost walks to catch up; farther away, it moves there at once.
  CATCH_UP_TILES = 3

  # Frames a notice stays at the bottom left, four seconds at 60 frames per second.
  NOTICE_FRAMES = 240

  # Frames between two looks at the connection.
  STATUS_FRAMES = 30

  # Bytes the DLL may write an inbox entry into at first.
  ENTRY_SIZE = 4096

  # Reports whether the hooks can be installed.
  #
  # A second copy of this script would wrap the same methods under the same names, and each hook
  # would then call itself until the stack overflows.
  #
  # @return [Boolean] false when the hooks are in place already.
  def self.hookable?
    !Spriteset_Map.method_defined?(:mgq_mp_overworld_update)
  end

  # Writes a line to the Multiplayer mod's InGame.log.
  #
  # @param message [String] The line.
  def self.log(message)
    MGQ_Multiplayer::Log.write("overworld: #{message}")
  rescue
  end

  # Reports whether a world is open.
  #
  # @return [Boolean] Whether mp_world.rb has a world open.
  def self.in_world?
    defined?(MGQ_MpWorld) && MGQ_MpWorld.open? ? true : false
  end

  # Takes what the others sent and tells them what changed here. Called every frame in every scene.
  def self.tick
    unless in_world?
      Peers.clear unless Peers.empty?
      return
    end

    Inbox.take_all
    Me.tell_changes
    Status.look
  rescue => e
    log("tick failed: #{e.class}: #{e.message}") unless @tick_failed
    @tick_failed = true
  end

  # Multiplayer/Multiplayer.dll's world room: the inbox and sending.
  module Link
    # Hands out the oldest inbox entry.
    #
    # @return [Hash, nil] "kind" ("seat", "in", "out" or "message"), "seat", "others", and the
    #   message's text under :payload; nil while none waits.
    def self.next_entry
      text = MGQ_Multiplayer::Link.read('mp_world_receive', ENTRY_SIZE)
      text.empty? ? nil : MGQ_Multiplayer::Link.parse(text)
    end

    # Sends a message to one seat or to every other game.
    #
    # @param target [Integer] The seat, -1 for everyone.
    # @param text [String] The message.
    # @return [Boolean] Whether it went out.
    def self.send_to(target, text)
      MGQ_Multiplayer::Link.function('mp_world_send', 'lp').call(target, text + "\0") == 1
    end

    # Reads how the connection stands.
    #
    # @return [Hash] "state" ("idle", "connecting", "open", "reconnecting" or "failed"), "seat", "others" and "error".
    def self.status
      text = MGQ_Multiplayer::Link.read('mp_world_status', 1024)
      text.empty? ? { "state" => "idle" } : MGQ_Multiplayer::Link.parse(text)
    end
  end

  # What this game tells the others about its player.
  module Me
    # Tells every other game what changed, if anything did.
    def self.tell_changes
      state = current
      return if state.nil? || state == @told

      @told = state if Link.send_to(-1, encode(state))
    end

    # Tells one game everything, as a newcomer needs.
    #
    # @param seat [Integer] The newcomer's seat, -1 for everyone, which also reads the player's
    #   id and name again, since a new connection may follow a new name.
    def self.tell_all(seat)
      @identity = nil if seat < 0
      state = current
      Link.send_to(seat, encode(state)) if state
      @told = state if seat < 0
    end

    # Reads what the others need to know about the player.
    #
    # @return [Hash, nil] The player's state, nil before the map exists.
    def self.current
      return nil unless $game_player && $game_map && $game_map.map_id > 0

      # Read once per connection, since the state is compared every frame.
      @identity ||= [MGQ_Multiplayer::Link.player_id, MGQ_Multiplayer::Player.name.to_s]
      looks = $game_player.vehicle || $game_player
      {
        "id" => @identity[0],
        "name" => @identity[1],
        "sprite" => looks.character_name.to_s,
        "index" => looks.character_index,
        "map" => $game_map.map_id,
        "x" => $game_player.x,
        "y" => $game_player.y,
        "d" => $game_player.direction,
        "speed" => $game_player.real_move_speed,
        "hidden" => $game_player.transparent ? 1 : 0,
        "scene" => scene,
      }
    end

    # Tells what the player does: walk the map, fight, sit in a menu or watch an event.
    #
    # @return [String] "map", "battle", "menu" or "event".
    def self.scene
      current = SceneManager.scene
      return "battle" if current.is_a?(Scene_Battle)
      return "event" if current.class.name.to_s =~ /Novel/
      return "menu" unless current.is_a?(Scene_Map)

      $game_message.busy? || $game_map.interpreter.running? ? "event" : "map"
    end

    # Writes a state as a message.
    #
    # @param state [Hash] The state.
    # @return [String] The message: key=value lines.
    def self.encode(state)
      state.map { |key, value| "#{key}=#{value.to_s.gsub(/[\r\n]/, ' ')}" }.join("\n") + "\n\n"
    end
  end

  # The other games of the world, by seat, as their last messages said.
  module Peers
    # Another player: their seat, what they last told, and their ghost while on this map.
    #
    # @!attribute seat [Integer] Their game's seat.
    # @!attribute state [Hash] What they last told: "name", "sprite", "index", "map", "x", "y", "d", "speed", "hidden", "scene".
    # @!attribute ghost [Game_MpGhost, nil] Their ghost, while they are on this map.
    Peer = Struct.new(:seat, :state, :ghost)

    @peers = {}

    # Takes what a game told.
    #
    # @param seat [Integer] The game's seat.
    # @param state [Hash] What it told.
    def self.take(seat, state)
      peer = @peers[seat]

      if peer
        peer.state = state
      else
        @peers[seat] = Peer.new(seat, state, nil)
        Status.notice("#{state['name']} joined the world.")
      end
    end

    # Forgets a game that left.
    #
    # @param seat [Integer] Its seat.
    def self.remove(seat)
      peer = @peers.delete(seat)
      Status.notice("#{peer.state['name']} left the world.") if peer
    end

    # Forgets every game, as after a reconnect or once the world closed.
    def self.clear
      @peers.clear
    end

    # Reports whether no other game is known.
    #
    # @return [Boolean] Whether none is.
    def self.empty?
      @peers.empty?
    end

    # Lists the other games.
    #
    # @return [Array<Peer>] The games.
    def self.all
      @peers.values
    end
  end

  # Reads the world room's inbox.
  module Inbox
    # Most entries read per frame, so a flood never stalls a frame.
    MAX_PER_FRAME = 64

    # Takes every waiting entry.
    def self.take_all
      MAX_PER_FRAME.times do
        entry = Link.next_entry
        break unless entry

        take(entry)
      end
    end

    # Takes one entry.
    #
    # @param entry [Hash] The entry, see Link.next_entry.
    def self.take(entry)
      seat = entry["seat"].to_i

      case entry["kind"]
      when "seat"
        # A new connection: every other game is told everything, and tells everything back.
        Peers.clear
        Me.tell_all(-1)
      when "in"
        Me.tell_all(seat)
      when "out"
        Peers.remove(seat)
      when "message"
        state = MGQ_Multiplayer::Link.parse(entry[:payload].dup)
        state.delete(:payload)
        Peers.take(seat, state) if state["map"]
      end
    end
  end

  # The line at the bottom left of the map: who came and went, and when the connection is down.
  module Status
    @frames = 0
    @notices = []

    # Adds a notice, shown for a few seconds.
    #
    # @param text [String] The notice.
    def self.notice(text)
      @notices.push([text, NOTICE_FRAMES])
      @notices.shift while @notices.size > 3
    end

    # Looks at the connection every STATUS_FRAMES, and lets notices run out.
    def self.look
      @notices.each { |notice| notice[1] -= 1 }
      @notices.reject! { |_, left| left <= 0 }
      @frames += 1
      return if @frames < STATUS_FRAMES

      @frames = 0
      state = Link.status
      @problem =
        case state["state"]
        when "reconnecting" then "Reconnecting . . ."
        when "connecting" then state["error"] || "Connecting . . ."
        when "failed" then "Not connected: #{state['error']}"
        end
    end

    # Tells what the line shows now.
    #
    # @return [Array<String>] The lines, the connection's problem first.
    def self.lines
      ([@problem] + @notices.map { |text, _| text }).compact
    end
  end

  # Moves the ghosts of the players on this map. Called by the map every frame.
  def self.update_ghosts
    return unless in_world?

    map = $game_map.map_id
    Peers.all.each do |peer|
      here = peer.state["map"].to_i == map

      if here
        peer.ghost ||= Game_MpGhost.new(peer.state)
        peer.ghost.follow(peer.state)
      else
        peer.ghost = nil
      end
    end
  rescue => e
    log("ghost update failed: #{e.class}: #{e.message}") unless @ghosts_failed
    @ghosts_failed = true
  end

  # Lists the ghosts on this map, with what their players last told.
  #
  # @return [Array<Array>] The ghosts and their states.
  def self.ghosts
    in_world? ? Peers.all.select { |peer| peer.ghost }.map { |peer| [peer.ghost, peer.state] } : []
  end
end

# Another player of the world on this map: it walks where they walk, looks like their party
# leader, and walks through everything without triggering anything.
class Game_MpGhost < Game_Character
  # Creates the ghost where its player stands.
  #
  # @param state [Hash] What the player last told.
  def initialize(state)
    super()
    @through = true
    @priority_type = 1
    @step_anime = false
    @walk_anime = true
    moveto(state["x"].to_i, state["y"].to_i)
    follow(state)
  end

  # Walks toward where the player stands, at their speed, and looks like them.
  #
  # @param state [Hash] What the player last told.
  def follow(state)
    look_like(state)
    update
    return if moving?

    dx = state["x"].to_i - @x
    dy = state["y"].to_i - @y

    if dx == 0 && dy == 0
      set_direction(state["d"].to_i) if state["d"].to_i > 0
    elsif dx.abs + dy.abs > MGQ_MpOverworld::CATCH_UP_TILES
      moveto(state["x"].to_i, state["y"].to_i)
      set_direction(state["d"].to_i) if state["d"].to_i > 0
    else
      move_straight(dx.abs >= dy.abs ? (dx > 0 ? 6 : 4) : (dy > 0 ? 2 : 8))
    end
  end

  # Takes the player's sprite, speed and visibility.
  #
  # @param state [Hash] What the player last told.
  def look_like(state)
    set_graphic(state["sprite"].to_s, state["index"].to_i) if @character_name != state["sprite"].to_s || @character_index != state["index"].to_i
    @move_speed = [[state["speed"].to_i, 1].max, 6].min
    @transparent = state["hidden"].to_i == 1
  end
end

# A ghost's name above its head, with an icon for what its player does.
class Sprite_MpGhostLabel < Sprite
  # Width of the label.
  WIDTH = 200

  # Height of the label.
  HEIGHT = 24

  # Creates the label, empty.
  #
  # @param viewport [Viewport] The map's viewport of characters.
  def initialize(viewport)
    super(viewport)
    self.bitmap = Bitmap.new(WIDTH, HEIGHT)
    self.ox = WIDTH / 2
    self.z = 250
    @shown = nil
  end

  # Draws the name and icon, if they changed, and follows the ghost's sprite.
  #
  # @param sprite [Sprite_Character] The ghost's sprite.
  # @param state [Hash] What the player last told.
  def show(sprite, state)
    self.x = sprite.x
    self.y = sprite.y - sprite.height - HEIGHT + 4
    self.visible = sprite.visible && sprite.opacity > 0 && state["hidden"].to_i != 1
    drawn = [state["name"], state["scene"]]
    return if drawn == @shown

    @shown = drawn
    draw(state["name"].to_s, MGQ_MpOverworld::STATE_ICONS[state["scene"]])
  end

  # Draws the name, and the icon before it.
  #
  # @param name [String] The player's name.
  # @param icon [Integer, nil] The icon's index in the game's icon set, nil for none.
  def draw(name, icon)
    bitmap.clear
    bitmap.font.size = 18
    bitmap.font.outline = true
    width = [bitmap.text_size(name).width, WIDTH - 28].min
    left = (WIDTH - width - (icon ? 26 : 0)) / 2

    if icon
      iconset = Cache.system("Iconset")
      bitmap.blt(left, 0, iconset, Rect.new(icon % 16 * 24, icon / 16 * 24, 24, 24))
      left += 26
    end

    bitmap.draw_text(left, 0, width, HEIGHT, name)
  end

  # Frees the label's picture.
  def dispose
    bitmap.dispose
    super
  end
end

# The line at the bottom left of the map.
class Sprite_MpWorldStatus < Sprite
  # Width of the line.
  WIDTH = 400

  # Height of one row.
  ROW = 22

  # Rows the line has room for.
  ROWS = 4

  # Creates the line, empty.
  #
  # @param viewport [Viewport] The map's topmost viewport.
  def initialize(viewport)
    super(viewport)
    self.bitmap = Bitmap.new(WIDTH, ROW * ROWS)
    self.x = 8
    self.y = Graphics.height - ROW * ROWS - 8
    self.z = 200
    @shown = []
  end

  # Draws what the line shows now, if it changed.
  def update
    super
    lines = MGQ_MpOverworld.in_world? ? MGQ_MpOverworld::Status.lines.last(ROWS) : []
    return if lines == @shown

    @shown = lines
    bitmap.clear
    bitmap.font.size = 18
    bitmap.font.outline = true
    lines.each_with_index do |line, row|
      bitmap.draw_text(0, (ROWS - lines.size + row) * ROW, WIDTH, ROW, line)
    end
  end

  # Frees the line's picture.
  def dispose
    bitmap.dispose
    super
  end
end

# Game hooks.
#
# Each wraps a game method: the original runs first, and the mod's part never raises.

if MGQ_MpOverworld.hookable?
  begin
    class << Graphics
      alias mgq_mp_overworld_graphics_update update

      # Draws the frame, then takes the others' messages and tells them what changed here.
      #
      # Graphics.update runs every frame in every scene, so the others hear of a battle or a menu
      # and nothing piles up meanwhile.
      def update
        mgq_mp_overworld_graphics_update
        MGQ_MpOverworld.tick
      end
    end
  rescue => e
    MGQ_MpOverworld.log("Graphics hook FAILED: #{e.class}: #{e.message}")
  end

  begin
    class Game_Map
      alias mgq_mp_overworld_update update

      # Updates the map, then moves the ghosts on it.
      #
      # @param args [Array] The original's arguments.
      def update(*args)
        mgq_mp_overworld_update(*args)
        MGQ_MpOverworld.update_ghosts
      end
    end
  rescue => e
    MGQ_MpOverworld.log("map hook FAILED: #{e.class}: #{e.message}")
  end

  begin
    class Spriteset_Map
      alias mgq_mp_overworld_update update

      # Updates the map's sprites, then the ghosts', their labels and the status line.
      def update
        mgq_mp_overworld_update
        mgq_mp_overworld_update_ghosts
      end

      # Keeps a sprite and label per ghost on this map, and the status line.
      def mgq_mp_overworld_update_ghosts
        @mgq_mp_ghosts ||= {}
        @mgq_mp_status ||= Sprite_MpWorldStatus.new(@viewport3)
        ghosts = MGQ_MpOverworld.ghosts

        @mgq_mp_ghosts.keys.each do |ghost|
          next if ghosts.any? { |here, _| here.equal?(ghost) }

          sprite, label = @mgq_mp_ghosts.delete(ghost)
          sprite.dispose
          label.dispose
        end

        ghosts.each do |ghost, state|
          @mgq_mp_ghosts[ghost] ||= [Sprite_Character.new(@viewport1, ghost), Sprite_MpGhostLabel.new(@viewport1)]
          sprite, label = @mgq_mp_ghosts[ghost]
          sprite.update
          label.show(sprite, state)
        end

        @mgq_mp_status.update
      rescue => e
        MGQ_MpOverworld.log("ghost sprites failed: #{e.class}: #{e.message}") unless @mgq_mp_failed
        @mgq_mp_failed = true
      end

      alias mgq_mp_overworld_dispose dispose

      # Frees the ghosts' sprites and the status line, then the map's.
      def dispose
        (@mgq_mp_ghosts || {}).values.flatten.each { |sprite| sprite.dispose }
        @mgq_mp_ghosts = nil
        @mgq_mp_status.dispose if @mgq_mp_status
        @mgq_mp_status = nil
        mgq_mp_overworld_dispose
      end
    end
  rescue => e
    MGQ_MpOverworld.log("sprite hooks FAILED: #{e.class}: #{e.message}")
  end
end
