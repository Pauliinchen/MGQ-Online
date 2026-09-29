#----------------------------------------------------------------
#  Multiplayer.rb
#
#  Changelog:
#      Paulinchen  2026-09-29: Added Capture, which takes the buttons away from the game while a screen of the mod reads them
#                            - Told whether the game's window is hooked, which the keyboard needs
#                            - Told the DLL the player's key and name for worlds, and read typing from the keyboard through it
#                            - Added Player, the player's id and name, which PvP battles pass on when Discord knows no name
#                            - Found the mod folder relative to the game's folder, which works in a folder named with characters outside ASCII
#                            - Hosted without a port, since games meet at the relay
#                            - Added Link.status, which leaves the friend's team out, for the frequent checks
#      Paulinchen  2026-09-28: Created
#
#----------------------------------------------------------------

# What every way of playing together shares: the connection with a friend through
# Multiplayer/Multiplayer.dll, the game running on while its window is in the background, keys the
# game's own Input does not know, and the Discord mod, when it is installed.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_Multiplayer
  # Turns the mod off without uninstalling it.
  ENABLED = true

  # Folder next to Game.exe that holds the DLL and everything the mod writes.
  MOD_DIR = "Multiplayer"

  # File name of the DLL inside the mod folder.
  DLL = "Multiplayer.dll"

  # Frames between two hand-overs to the Discord mod, half a second at 60 frames per second.
  DISCORD_FRAMES = 30

  # Longest player name shown.
  MAX_NAME_LENGTH = 32

  # Reports whether the hooks can be installed.
  #
  # A second copy of this script would wrap the same methods under the same names, and each hook
  # would then call itself until the stack overflows.
  #
  # @return [Boolean] false when the hooks are in place already.
  def self.hookable?
    !SceneManager.respond_to?(:mgq_multiplayer_run)
  end

  # Tells whether the mod can run.
  #
  # @return [Boolean] Whether the mod is on and its DLL is in the mod folder.
  def self.available?
    ENABLED && File.exist?(path(DLL))
  end

  # Starts the DLL and keeps the game running in the background, once per game session.
  def self.start
    return if @started
    @started = true
    return unless available?

    Link.start
    Background.start
  rescue => e
    Log.write("start failed: #{e.class}: #{e.message}")
  end

  # Builds the path of a file inside the mod folder, relative to the game's folder.
  #
  # The game always runs in its own folder. An absolute path breaks in a folder named with
  # characters outside ASCII, such as the untranslated game's: File takes it only as UTF-8,
  # Win32API loads a DLL only from the system's code page. A relative one, with backslashes, works
  # for both.
  #
  # @param name [String] The file name, relative to the mod folder.
  # @return [String] The path.
  def self.path(name)
    "#{MOD_DIR}\\#{name}"
  end

  # Keeps a name someone else chose short, on one line and free of message codes.
  #
  # @param name [String, nil] The name.
  # @return [String] The name, "A friend" when nothing is left of it.
  def self.clean(name)
    cleaned = name.to_s.gsub(/[\x00-\x1f\\]/, "").strip[0, MAX_NAME_LENGTH]
    cleaned.empty? ? "A friend" : cleaned
  rescue
    "A friend"
  end

  # Multiplayer/InGame.log, which only appears when something went wrong inside the game.
  module Log
    # Lines written per session at most, an error repeating every frame would flood the file.
    MAX_LINES = 60

    @lines = 0

    # Appends a line, prefixed with the time.
    #
    # @param message [String] The line to append.
    def self.write(message)
      return if @lines >= MAX_LINES
      @lines += 1

      File.open(MGQ_Multiplayer.path("InGame.log"), "ab") { |file| file.write("#{Time.now}  #{message}\n") }
    rescue
    end
  end

  # Files of key=value lines, such as Multiplayer/Player.ini.
  module Ini
    # Reads a file.
    #
    # @param path [String] The file.
    # @return [Hash] The values by key, empty when the file is missing or unreadable.
    def self.read(path)
      values = {}
      return values unless File.exist?(path)

      File.open(path, "rb") { |file| file.read }.force_encoding("UTF-8").split(/\r?\n/).each do |line|
        key, value = line.split("=", 2)
        values[key.strip] = value.strip if value
      end
      values
    rescue => e
      Log.write("could not read #{path}: #{e.class}: #{e.message}")
      {}
    end

    # Writes a file, replacing it.
    #
    # @param path [String] The file.
    # @param values [Hash] The values by key, each kept on its line.
    # @return [Boolean] Whether the file was written.
    def self.write(path, values)
      lines = values.map { |key, value| "#{key}=#{value.to_s.gsub(/[\r\n]/, ' ')}\n" }
      File.open(path, "wb") { |file| file.write(lines.join) }
      true
    rescue => e
      Log.write("could not write #{path}: #{e.class}: #{e.message}")
      false
    end
  end

  # Who plays this game: an id that tells it from every other player's, kept in
  # Multiplayer/Player.ini, and the name the others see.
  module Player
    # File that keeps the id and the chosen name, inside the mod folder.
    FILE = "Player.ini"

    # Reads the player's id, making one the first time.
    #
    # @return [String] The id, "" when none could be made.
    def self.id
      values = load
      if values["id"].to_s.empty?
        values["id"] = Link.new_id
        Ini.write(MGQ_Multiplayer.path(FILE), values) unless values["id"].empty?
      end
      values["id"].to_s
    end

    # Reads the name the others see: the one the player chose for Multiplayer, or else their name on Discord.
    #
    # @return [String, nil] The name, nil while the player chose none and Discord told none.
    def self.name
      chosen = load["name"].to_s
      return MGQ_Multiplayer.clean(chosen) unless chosen.empty?

      discord = Discord.player_name
      discord && !discord.empty? ? MGQ_Multiplayer.clean(discord) : nil
    end

    # Keeps the name the player chose, which replaces their name on Discord.
    #
    # @param name [String] The name.
    def self.name=(name)
      values = load
      values["name"] = MGQ_Multiplayer.clean(name)
      Ini.write(MGQ_Multiplayer.path(FILE), values)
      @values = values
      share
    end

    # Tells the DLL who plays, once the player has a name.
    #
    # @return [Boolean] Whether the DLL knows who plays.
    def self.share
      name = self.name
      key = id
      name && !key.empty? ? Link.set_player(key, name) : false
    rescue => e
      Log.write("could not tell the DLL who plays: #{e.class}: #{e.message}")
      false
    end

    # Reads Player.ini once.
    #
    # @return [Hash] The values by key.
    def self.load
      @values ||= Ini.read(MGQ_Multiplayer.path(FILE))
    end
  end

  # Multiplayer/Multiplayer.dll's functions: hosting, joining, the first exchange of what each game
  # hands over, and the messages that follow, all running on threads of the DLL's own.
  module Link
    # Bytes the DLL may write the connection's state into at first, a PvP battle's team included.
    # A larger state asks for a larger buffer.
    STATE_SIZE = 70_000

    # Bytes the DLL may write the connection's state without the friend's team into at first.
    STATUS_SIZE = 1_024

    # Bytes the DLL may write a message into at first. A larger message asks for a larger buffer.
    MESSAGE_SIZE = 4_096

    # Finds the mod folder and starts the DLL's log.
    def self.start
      function('mp_start', 'v').call
    end

    # Keeps the game running while another application is active.
    #
    # @return [Boolean] Whether the game keeps running.
    def self.keep_running
      function('mp_keep_running', 'v').call == 1
    end

    # Starts hosting.
    #
    # @param game [String] What tells this game version's data from another's.
    # @param payload [String] What the friend gets, such as the player's team.
    def self.host(game, payload)
      Discord.share_player_name
      function('mp_host', 'pp').call(game + "\0", payload + "\0")
    end

    # Joins the host of the invite that is waiting.
    #
    # @param game [String] What tells this game version's data from another's.
    # @param payload [String] What the friend gets, such as the player's team.
    def self.join_invite(game, payload)
      Discord.share_player_name
      function('mp_join_invite', 'pp').call(game + "\0", payload + "\0")
    end

    # Joins the host whose join code is on the clipboard.
    #
    # @param game [String] What tells this game version's data from another's.
    # @param payload [String] What the friend gets, such as the player's team.
    def self.join_clipboard(game, payload)
      Discord.share_player_name
      function('mp_join_clipboard', 'pp').call(game + "\0", payload + "\0")
    end

    # Keeps the join code of an invite the player accepted in Discord, until they join with it.
    #
    # @param join_code [String] The join code.
    def self.receive_invite(join_code)
      function('mp_receive_invite', 'p').call(join_code + "\0")
    end

    # Tells the DLL the player's name, which the friend sees.
    #
    # @param name [String] The name.
    def self.set_player_name(name)
      function('mp_set_player_name', 'p').call(name + "\0")
    end

    # Makes an id nobody else has.
    #
    # @return [String] 32 lowercase hexadecimal characters, "" when it failed.
    def self.new_id
      read('mp_new_id', 64)
    end

    # Tells the DLL who plays in worlds.
    #
    # @param key [String] The player's key.
    # @param name [String] The player's name.
    # @return [Boolean] Whether the DLL took them.
    def self.set_player(key, name)
      function('mp_set_player', 'pp').call(key + "\0", name + "\0") == 1
    end

    # Reads the id everyone sees for the player, as the world directory lists it.
    #
    # @return [String] The id, "" before the player was set.
    def self.player_id
      read('mp_player_id', 64)
    end

    # Starts or stops taking what the player types on the keyboard.
    #
    # @param on [Boolean] Whether to take it.
    def self.typing(on)
      function('mp_typing', 'l').call(on ? 1 : 0)
    end

    # Takes what the player typed since the last call.
    #
    # @return [Array] The typed characters, Enter, Backspace and Escape among them as "\r", "\b"
    #   and "\e"; and how many keys went down.
    def self.take_typed
      text = read('mp_take_typed', 1024)
      return ["", 0] if text.empty?

      state = parse(text)
      [state[:payload], state["keys"].to_i]
    end

    # Stops hosting or joining, closes the link, forgets what arrived and turns down a waiting invite.
    def self.cancel
      function('mp_cancel', 'v').call
    end

    # Puts the join code on the clipboard again.
    #
    # @return [Boolean] Whether the clipboard holds the join code again.
    def self.copy_code
      function('mp_copy_code', 'v').call == 1
    end

    # Sends a message to the friend.
    #
    # @param text [String] The message.
    # @return [Boolean] false without an open link, or when the message is too long.
    def self.post(text)
      function('mp_send', 'p').call(text + "\0") == 1
    end

    # Takes the oldest message from the friend.
    #
    # @return [String, nil] The message, nil while none waits.
    def self.next_message
      text = read('mp_receive', MESSAGE_SIZE)
      text.empty? ? nil : text.force_encoding("UTF-8")
    end

    # Reads how the connection stands.
    #
    # @return [Hash] "state" ("idle", "hosting", "joining", "received" or "failed") and whichever
    #   of "code", "invite", "error", "opponent", "link" ("open", "closed" or "dropped"), "role"
    #   ("host" or "guest") and "party" apply, what the friend handed over under :payload.
    def self.state
      text = read('mp_state', STATE_SIZE)
      text.empty? ? { "state" => "idle", :payload => "" } : parse(text)
    end

    # Reads how the connection stands without what the friend handed over, cheap enough for checks
    # many times a second.
    #
    # @return [Hash] See state, with an empty :payload.
    def self.status
      text = read('mp_status', STATUS_SIZE)
      text.empty? ? { "state" => "idle", :payload => "" } : parse(text)
    end

    # Reads the DLL's description of the connection: key=value lines, an empty line, the payload.
    #
    # @param text [String] The description.
    # @return [Hash] See state.
    def self.parse(text)
      head, payload = text.force_encoding("UTF-8").split("\n\n", 2)
      state = { :payload => payload.to_s }

      head.to_s.split("\n").each do |line|
        key, value = line.split("=", 2)
        state[key] = value if value
      end

      state
    end

    # Calls an export that writes a text into a buffer, again with a larger buffer when asked for one.
    #
    # @param name [String] The export.
    # @param size [Integer] The buffer's size at first.
    # @return [String] The text as bytes, "" when there is none.
    def self.read(name, size)
      buffer = "\0" * size
      length = function(name, 'pl').call(buffer, buffer.size)

      if length < 0
        buffer = "\0" * (1 - length)
        length = function(name, 'pl').call(buffer, buffer.size)
      end

      # The DLL wrote bytes past Ruby's back, so only a binary string counts them right.
      length > 0 ? buffer.force_encoding("ASCII-8BIT")[0, length] : ""
    end

    # Loads an export of the DLL.
    #
    # @param name [String] The exported function.
    # @param arguments [String] Its arguments, in Win32API notation.
    # @return [Win32API] The function, loaded once.
    def self.function(name, arguments)
      @functions ||= {}
      @functions[name] ||= Win32API.new(MGQ_Multiplayer.path(DLL), name, arguments, 'l')
    end
  end

  # Keeps the game running while another window is in front, which RGSS pauses it for otherwise, so
  # neither player holds the other up, and ignores the buttons meanwhile.
  module Background
    # The Input methods that report buttons, with what each reports while none is pressed.
    IDLE_INPUT = { :press? => false, :trigger? => false, :repeat? => false, :dir4 => 0, :dir8 => 0 }

    # Has the DLL keep the game running.
    def self.start
      @running = Link.keep_running
      Log.write("could not keep the game running in the background") unless @running
    rescue => e
      Log.write("background start failed: #{e.class}: #{e.message}")
    end

    # Reports whether the DLL hooked the game's window, which keeps the game running and passes on
    # what the player types.
    #
    # @return [Boolean] Whether the window is hooked.
    def self.running?
      @running == true
    end

    # Has Input report no buttons while another window is in front, once the game keeps running, or
    # while a screen of the mod reads them (Capture).
    #
    # The keyboard only reaches the window in front, but gamepads reach every game, so a pad played
    # in another game would play this one too.
    def self.guard_input
      return if @input_guarded
      @input_guarded = true

      input = Input.singleton_class
      if @running
        input.send(:alias_method, :mgq_multiplayer_update, :update)
        input.send(:define_method, :update) do
          MGQ_Multiplayer::Background.refresh
          mgq_multiplayer_update
        end
      end

      IDLE_INPUT.each do |method, idle|
        original = Background.original(method)
        input.send(:alias_method, original, method)
        input.send(:define_method, method) { |*args| MGQ_Multiplayer::Background.in_front? && !MGQ_Multiplayer::Capture.on? ? send(original, *args) : idle }
      end
    end

    # Names the unguarded Input method that guard_input keeps.
    #
    # @param method [Symbol] A key of IDLE_INPUT.
    # @return [Symbol] The name.
    def self.original(method)
      :"mgq_multiplayer_#{method.to_s.sub('?', '_query')}"
    end

    # Reports whether guard_input wrapped Input.
    #
    # @return [Boolean] Whether it did.
    def self.input_guarded?
      @input_guarded == true
    end

    # Asks Windows whether the window in front belongs to this game, once per frame.
    #
    # Input.update calls it, since the game's Graphics.frame_count raises until the game first sets it.
    def self.refresh
      @in_front = Windows.game_in_front?
    rescue
      @in_front = true
    end

    # Reports whether the window in front belongs to this game, as Windows said at the last Input.update.
    #
    # @return [Boolean] true while the input is not guarded or Windows cannot tell.
    def self.in_front?
      @in_front != false
    end
  end

  # Takes the buttons away from the game while a screen of the mod reads them, such as a menu drawn
  # over the map, under which the player would walk or open the game's menu otherwise.
  module Capture
    @owner = nil

    # Takes the buttons for a screen.
    #
    # @param owner [Symbol] The screen, such as :wheel.
    def self.start(owner)
      @owner = owner
    end

    # Gives the buttons back, if the screen still holds them.
    #
    # @param owner [Symbol] The screen.
    def self.stop(owner)
      @owner = nil if @owner == owner
    end

    # Reports whether a screen holds the buttons.
    #
    # @return [Boolean] Whether one does.
    def self.on?
      !@owner.nil?
    end

    # Reports whether a button went down, past the capture, while the game window is in front.
    #
    # @param button [Symbol] The game's button, such as :C or :UP.
    # @return [Boolean] Whether it went down.
    def self.trigger?(button)
      return false unless Background.in_front?

      Background.input_guarded? ? Input.send(Background.original(:trigger?), button) : Input.trigger?(button)
    end
  end

  # Keys the game's own Input does not know, read from Windows.
  module Key
    # Set in a key state while the key is down.
    DOWN = 0x8000

    # Reports whether a key went down since the last call for it, while the game window is in front.
    #
    # Windows reports the key whichever window has the focus, so a press in another window is
    # ignored.
    #
    # @param code [Integer] Windows' code of the key, such as 0x7A for F11.
    # @return [Boolean] Whether the key went down.
    def self.pressed?(code)
      @down ||= {}
      down = (Windows.api('user32', 'GetAsyncKeyState', 'i', 'i').call(code) & DOWN) != 0
      pressed = down && !@down[code]
      @down[code] = down
      pressed && Background.in_front?
    end
  end

  # The Windows functions the script calls directly.
  module Windows
    # Asks Windows whether the game is in front.
    #
    # @return [Boolean] Whether the window in front belongs to this game.
    def self.game_in_front?
      owner = [0].pack('L')
      api('user32', 'GetWindowThreadProcessId', 'lp', 'l').call(api('user32', 'GetForegroundWindow', 'v', 'l').call, owner)
      owner.unpack('L')[0] == api('kernel32', 'GetCurrentProcessId', 'v', 'l').call
    end

    # Loads a Windows function.
    #
    # @param library [String] The Windows library.
    # @param name [String] The function.
    # @param arguments [String] Its arguments, in Win32API notation.
    # @param result [String] Its result, in Win32API notation.
    # @return [Win32API] The function, loaded once.
    def self.api(library, name, arguments, result)
      @functions ||= {}
      @functions[name] ||= Win32API.new(library, name, arguments, result)
    end
  end

  # The Discord mod, when it is installed: it shows the connection on the player's profile, offers
  # the invites, and hands over the ones the player accepted and the player's name. Everything here
  # does nothing without it, and the join code on the clipboard still works.
  module Discord
    # The bridge version this script speaks, see MGQ_Discord::Bridge.
    BRIDGE_VERSION = 1

    # Tells whether the Discord mod can take the connection.
    #
    # @return [Boolean] Whether the Discord mod is installed and speaks this script's bridge version.
    def self.available?
      defined?(MGQ_Discord::Bridge) && MGQ_Discord::Bridge::VERSION == BRIDGE_VERSION && MGQ_Discord::Bridge.available? ? true : false
    end

    # Hands the connection to the Discord mod when it changed, and takes an invite the player
    # accepted in Discord. Called every frame, acts every DISCORD_FRAMES.
    def self.tick
      @frames = (@frames || 0) + 1
      return if @frames < DISCORD_FRAMES

      @frames = 0
      return unless MGQ_Multiplayer.available? && available?

      invite = MGQ_Discord::Bridge.take_invite
      Link.receive_invite(invite) if invite
      report(Link.status)
    rescue => e
      Log.write("discord hand-over failed: #{e.class}: #{e.message}")
    end

    # Tells the DLL the player's name, which the friend sees: the one on Discord, or the one the
    # player chose for Multiplayer.
    def self.share_player_name
      name = Player.name
      Link.set_player_name(name) if name
    rescue => e
      Log.write("player name failed: #{e.class}: #{e.message}")
    end

    # Reads the player's name on Discord.
    #
    # @return [String, nil] The name, nil without the Discord mod or until Discord told it.
    def self.player_name
      available? ? MGQ_Discord::Bridge.player_name : nil
    rescue
      nil
    end

    # Hands the connection to the Discord mod, unless it did not change since the last time.
    #
    # @param state [Hash] How the connection stands, see Link.status.
    def self.report(state)
      party = state["party"]
      current =
        if party && state["state"] == "hosting" && state["code"]
          [:hosting, party, state["code"]]
        elsif party && state["link"] == "open"
          [:connected, party, MGQ_Multiplayer.clean(state["opponent"])]
        else
          [:idle]
        end
      return if current == @reported

      @reported = current
      kind, party, detail = current
      case kind
      when :hosting then MGQ_Discord::Bridge.hosting(party, detail)
      when :connected then MGQ_Discord::Bridge.connected(party, detail)
      else MGQ_Discord::Bridge.idle
      end
    end
  end
end

MGQ_Multiplayer.start

# Game hooks.
#
# Each wraps a game method: the original runs first, its result is returned unchanged, and the
# mod's part never raises.

if MGQ_Multiplayer.hookable?
  begin
    class << Graphics
      alias mgq_multiplayer_graphics_update update

      # Draws the frame, then tells the Discord mod how the connection stands.
      #
      # Graphics.update runs every frame in every scene, so the Discord mod hears of the connection
      # wherever the player is.
      def update
        mgq_multiplayer_graphics_update
        MGQ_Multiplayer::Discord.tick
      end
    end
  rescue => e
    MGQ_Multiplayer::Log.write("Graphics hook FAILED: #{e.class}: #{e.message}")
  end

  begin
    class << SceneManager
      alias mgq_multiplayer_run run

      # Guards the input, then runs the game.
      #
      # The game's plugins load after the Patch folder, the gamepad one wrapping Input, so the
      # guard wraps Input once every plugin is in.
      def run
        MGQ_Multiplayer::Background.guard_input rescue nil
        mgq_multiplayer_run
      end
    end
  rescue => e
    MGQ_Multiplayer::Log.write("SceneManager hook FAILED: #{e.class}: #{e.message}")
  end
end
