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
  # Icons of the game's icon set next to a ghost's name, by what its player does. Walking the map shows none.
  STATE_ICONS = {
    "battle" => 451,
    "event" => 4,
    "menu" => 183,
    "items" => 3059,
    "equip" => 3905,
    "shop" => 3874,
    "casino" => 220,
    "library" => 3240,
    "sailing" => 4069,
    "flying" => 3836,
    "away" => 6,
  }

  # What a player does on a screen of the game, by the screen's class name; any other screen is a menu.
  SCREENS = {
    /\AScene_(Item|Storehouse)\z/ => "items",
    /\AScene_(Equip|EquipStone\w*|Smith|Synthesize)\z/ => "equip",
    /\AScene_Shop\z/ => "shop",
    /\AScene_(Poker|Slot|CasinoPrize)\z/ => "casino",
    /Library/ => "library",
  }

  # Tiles a ghost walks to catch up; farther away, it moves there at once.
  CATCH_UP_TILES = 3

  # Windows' code of the key that invites to a party, accepts an invite or leaves the party: B,
  # which neither the game's Input nor its gamepad plugin reads.
  PARTY_KEY = 0x42

  # Tiles another player may be away, on the same map, to be invited or to accept.
  NEAR_TILES = 2

  # Frames an invite stands, fifteen seconds at 60 frames per second.
  INVITE_FRAMES = 900

  # Frames the second press that leaves the party may take, three seconds.
  LEAVE_FRAMES = 180

  # Opacity of the ghost of a player outside the party.
  STRANGER_OPACITY = 150

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
      Party.reset
      return
    end

    Inbox.take_all
    Party.count_down
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
        "party" => Party.id.to_s,
        "invite" => Party.inviting? ? 1 : 0,
      }
    end

    # Tells what the player does: walk the map, travel by boat or airship, fight, watch an event,
    # sit in a menu or one of its screens, or have the game in the background.
    #
    # @return [String] A key of STATE_ICONS, or "map" for walking the map.
    def self.scene
      current = SceneManager.scene
      name = current.class.name.to_s
      return "battle" if current.is_a?(Scene_Battle)
      return "event" if name =~ /Novel/ || (current.is_a?(Scene_Map) && ($game_message.busy? || $game_map.interpreter.running?))
      return "away" unless MGQ_Multiplayer::Background.in_front?
      return SCREENS.find { |pattern, _| name =~ pattern }.to_a[1] || "menu" unless current.is_a?(Scene_Map)

      return "flying" if $game_player.in_airship?

      $game_player.in_boat? || $game_player.in_ship? ? "sailing" : "map"
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
    # @!attribute member [Boolean] Whether they were in the player's party at their last message.
    Peer = Struct.new(:seat, :state, :ghost, :member)

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
        peer = @peers[seat] = Peer.new(seat, state, nil, false)
        Status.notice("#{state['name']} joined the world.")
      end

      Party.observe(peer)
    end

    # Forgets a game that left.
    #
    # @param seat [Integer] Its seat.
    def self.remove(seat)
      peer = @peers.delete(seat)
      return unless peer

      Status.notice("#{peer.state['name']} left the world.")
      Party.observe_leaving(peer)
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

  # The player's party: the others who share its id. Every game says its party's id and whether it
  # invites in the message it sends anyway, so joining needs no message of its own: a player who
  # accepts takes the inviter's id, and the inviter sees them join by it.
  module Party
    @id = nil
    @invite_frames = 0
    @leave_frames = 0

    # The party's id, nil while the player is in none.
    #
    # @return [String, nil] The id.
    def self.id
      @id
    end

    # Reports whether the player invites to a party now.
    #
    # @return [Boolean] Whether they do.
    def self.inviting?
      @invite_frames > 0
    end

    # Reports whether the player waits for a second press to leave the party.
    #
    # @return [Boolean] Whether they do.
    def self.leaving?
      @leave_frames > 0
    end

    # Reports whether another player is in the player's party.
    #
    # @param state [Hash] What the other player last told.
    # @return [Boolean] Whether they are.
    def self.member?(state)
      !@id.nil? && state["party"] == @id
    end

    # Lists the other players in the party, whom a battle will take along once co-op battles exist.
    #
    # @return [Array<Peers::Peer>] The members.
    def self.members
      Peers.all.select { |peer| member?(peer.state) }
    end

    # Leaves the party and forgets any invite, as when the world closes.
    def self.reset
      @id = nil
      @invite_frames = 0
      @leave_frames = 0
    end

    # Lets an invite and a waiting leave run out, and forgets a party nobody joined. Called every frame.
    def self.count_down
      @leave_frames -= 1 if @leave_frames > 0
      return unless @invite_frames > 0

      @invite_frames -= 1
      @id = nil if @invite_frames == 0 && members.empty?
    end

    # Acts on the party key, pressed on the map: accepts an invite nearby, invites the players
    # nearby, or leaves the party with a second press when nobody is near.
    def self.press
      near = Peers.all.select { |peer| near?(peer.state) }
      inviter = near.find { |peer| peer.state["invite"] == "1" && !member?(peer.state) }

      if inviter
        join(inviter)
      elsif near.any? { |peer| !member?(peer.state) }
        invite
      elsif @id && !members.empty?
        leaving? ? leave : ask_to_leave
      else
        Status.notice("Nobody is near enough to form a party.")
      end
    end

    # Invites the players nearby, making a party of one for them to join.
    def self.invite
      @id ||= "#{MGQ_Multiplayer::Link.player_id[0, 8]}#{rand(36**6).to_s(36)}"
      @invite_frames = INVITE_FRAMES
      @leave_frames = 0
    end

    # Joins the party of a player who invites.
    #
    # @param inviter [Peers::Peer] The player.
    def self.join(inviter)
      left = @id && !members.empty?
      @id = inviter.state["party"]
      @invite_frames = 0
      @leave_frames = 0
      Status.notice("#{left ? 'You left your party and joined' : 'You joined'} #{inviter.state['name']}'s party.")
      Peers.all.each { |peer| peer.member = member?(peer.state) }
    end

    # Asks for a second press before leaving the party.
    def self.ask_to_leave
      @leave_frames = LEAVE_FRAMES
      Status.notice("Press B again to leave the party.")
    end

    # Leaves the party.
    def self.leave
      reset
      Status.notice("You left the party.")
      Peers.all.each { |peer| peer.member = false }
    end

    # Notices a player coming into or going out of the party, and stops inviting once one joined.
    #
    # @param peer [Peers::Peer] The player, with what they just told.
    def self.observe(peer)
      member = member?(peer.state)
      return if member == peer.member

      peer.member = member
      if member
        @invite_frames = 0
        Status.notice("#{peer.state['name']} joined your party.")
      else
        Status.notice("#{peer.state['name']} left your party.")
      end
    end

    # Forgets a party member who left the world.
    #
    # @param peer [Peers::Peer] The player.
    def self.observe_leaving(peer)
      @id = nil if peer.member && members.empty? && !inviting?
    end

    # Reports whether another player stands near the player, on the same map.
    #
    # @param state [Hash] What the other player last told.
    # @return [Boolean] Whether they do.
    def self.near?(state)
      state["map"].to_i == $game_map.map_id &&
        [(state["x"].to_i - $game_player.x).abs, (state["y"].to_i - $game_player.y).abs].max <= NEAR_TILES
    end
  end

  # Takes the party key on the map, while no event, message or scene change is in the way.
  # Called by the map every frame, so a press is seen once.
  def self.on_map
    pressed = MGQ_Multiplayer::Key.pressed?(PARTY_KEY)
    return unless pressed && in_world?
    return if $game_map.interpreter.running? || $game_message.busy?

    Party.press
  rescue => e
    log("party key failed: #{e.class}: #{e.message}")
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
        peer.ghost.follow(peer.state, peer.member)
      else
        peer.ghost = nil
      end
    end
  rescue => e
    log("ghost update failed: #{e.class}: #{e.message}") unless @ghosts_failed
    @ghosts_failed = true
  end

  # Lists the ghosts on this map, with what their players last told and whether they are in the party.
  #
  # @return [Array<Array>] The ghosts, their states and whether each is a party member.
  def self.ghosts
    in_world? ? Peers.all.select { |peer| peer.ghost }.map { |peer| [peer.ghost, peer.state, peer.member] } : []
  end

  # Tells what the line above the player's own head says, if anything.
  #
  # @return [String, nil] The line.
  def self.own_line
    return nil unless in_world?
    return "Inviting to a party . . ." if Party.inviting?

    Party.leaving? ? "Press B again to leave the party" : nil
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
    follow(state, false)
  end

  # Walks toward where the player stands, at their speed, and looks like them: see-through a
  # little while they are outside the player's party.
  #
  # @param state [Hash] What the player last told.
  # @param member [Boolean] Whether they are in the player's party.
  def follow(state, member)
    look_like(state)
    @opacity = member ? 255 : MGQ_MpOverworld::STRANGER_OPACITY
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

# A ghost's name above its head, with an icon for what its player does, green for a party member,
# and a line above it while its player invites to a party.
class Sprite_MpGhostLabel < Sprite
  # Width of the label.
  WIDTH = 240

  # Height of one line.
  LINE = 24

  # Color of a party member's name.
  MEMBER_COLOR = Color.new(128, 255, 128)

  # Color of the invite line.
  INVITE_COLOR = Color.new(255, 224, 128)

  # Creates the label, empty.
  #
  # @param viewport [Viewport] The map's viewport of characters.
  def initialize(viewport)
    super(viewport)
    self.bitmap = Bitmap.new(WIDTH, LINE * 2)
    self.ox = WIDTH / 2
    self.z = 250
    @shown = nil
  end

  # Draws the label, if it changed, and follows the ghost's sprite.
  #
  # @param sprite [Sprite_Character] The ghost's sprite.
  # @param state [Hash] What the player last told.
  # @param member [Boolean] Whether the player is in the party.
  def show(sprite, state, member)
    self.x = sprite.x
    self.y = sprite.y - sprite.height - LINE * 2 + 4
    self.visible = sprite.visible && sprite.opacity > 0 && state["hidden"].to_i != 1
    inviting = state["invite"] == "1" && !member
    drawn = [state["name"], state["scene"], member, inviting]
    return if drawn == @shown

    @shown = drawn
    bitmap.clear
    bitmap.font.size = 18
    bitmap.font.outline = true
    line(0, "Invites to a party (B)", INVITE_COLOR) if inviting
    draw_name(state["name"].to_s, MGQ_MpOverworld::STATE_ICONS[state["scene"]], member ? MEMBER_COLOR : Color.new(255, 255, 255))
  end

  # Draws a centered line of text.
  #
  # @param row [Integer] The line, 0 above the name.
  # @param text [String] The text.
  # @param color [Color] Its color.
  def line(row, text, color)
    bitmap.font.color = color
    bitmap.draw_text(0, row * LINE, WIDTH, LINE, text, 1)
  end

  # Draws the name on the lower line, and the icon before it.
  #
  # @param name [String] The player's name.
  # @param icon [Integer, nil] The icon's index in the game's icon set, nil for none.
  # @param color [Color] The name's color.
  def draw_name(name, icon, color)
    width = [bitmap.text_size(name).width, WIDTH - 28].min
    left = (WIDTH - width - (icon ? 26 : 0)) / 2

    if icon
      iconset = Cache.system("Iconset")
      bitmap.blt(left, LINE, iconset, Rect.new(icon % 16 * 24, icon / 16 * 24, 24, 24))
      left += 26
    end

    bitmap.font.color = color
    bitmap.draw_text(left, LINE, width, LINE, name)
  end

  # Frees the label's picture.
  def dispose
    bitmap.dispose
    super
  end
end

# The line above the player's own head while they invite to a party or are about to leave it.
class Sprite_MpOwnLine < Sprite
  # Width of the line.
  WIDTH = 320

  # Height of the line.
  HEIGHT = 24

  # Creates the line, empty.
  #
  # @param viewport [Viewport] The map's viewport of characters.
  def initialize(viewport)
    super(viewport)
    self.bitmap = Bitmap.new(WIDTH, HEIGHT)
    self.ox = WIDTH / 2
    self.z = 250
    @shown = nil
  end

  # Draws the line, if it changed, above the player's sprite.
  #
  # @param sprite [Sprite_Character, nil] The player's sprite.
  def show(sprite)
    text = MGQ_MpOverworld.own_line
    self.visible = !text.nil? && !sprite.nil?
    return unless visible

    self.x = sprite.x
    self.y = sprite.y - sprite.height - HEIGHT
    return if text == @shown

    @shown = text
    bitmap.clear
    bitmap.font.size = 18
    bitmap.font.outline = true
    bitmap.font.color = Sprite_MpGhostLabel::INVITE_COLOR
    bitmap.draw_text(0, 0, WIDTH, HEIGHT, text, 1)
  end

  # Frees the line's picture.
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

      # Keeps a sprite and label per ghost on this map, the line above the player's head, and the status line.
      def mgq_mp_overworld_update_ghosts
        @mgq_mp_ghosts ||= {}
        @mgq_mp_status ||= Sprite_MpWorldStatus.new(@viewport3)
        @mgq_mp_own_line ||= Sprite_MpOwnLine.new(@viewport1)
        ghosts = MGQ_MpOverworld.ghosts

        @mgq_mp_ghosts.keys.each do |ghost|
          next if ghosts.any? { |here, _| here.equal?(ghost) }

          sprite, label = @mgq_mp_ghosts.delete(ghost)
          sprite.dispose
          label.dispose
        end

        ghosts.each do |ghost, state, member|
          @mgq_mp_ghosts[ghost] ||= [Sprite_Character.new(@viewport1, ghost), Sprite_MpGhostLabel.new(@viewport1)]
          sprite, label = @mgq_mp_ghosts[ghost]
          sprite.update
          label.show(sprite, state, member)
        end

        @mgq_mp_own_line.show(@character_sprites.find { |sprite| sprite.character.equal?($game_player) })
        @mgq_mp_status.update
      rescue => e
        MGQ_MpOverworld.log("ghost sprites failed: #{e.class}: #{e.message}") unless @mgq_mp_failed
        @mgq_mp_failed = true
      end

      alias mgq_mp_overworld_dispose dispose

      # Frees the ghosts' sprites, the player's line and the status line, then the map's.
      def dispose
        (@mgq_mp_ghosts || {}).values.flatten.each { |sprite| sprite.dispose }
        @mgq_mp_ghosts = nil
        [@mgq_mp_status, @mgq_mp_own_line].compact.each { |sprite| sprite.dispose }
        @mgq_mp_status = @mgq_mp_own_line = nil
        mgq_mp_overworld_dispose
      end
    end
  rescue => e
    MGQ_MpOverworld.log("sprite hooks FAILED: #{e.class}: #{e.message}")
  end

  begin
    class Scene_Map
      alias mgq_mp_overworld_update_scene update_scene

      # Updates the map, then takes the party key.
      #
      # The game checks its own keys here too, only while no scene change is in the way.
      def update_scene
        mgq_mp_overworld_update_scene
        MGQ_MpOverworld.on_map unless scene_changing?
      end
    end
  rescue => e
    MGQ_MpOverworld.log("map key hook FAILED: #{e.class}: #{e.message}")
  end
end
