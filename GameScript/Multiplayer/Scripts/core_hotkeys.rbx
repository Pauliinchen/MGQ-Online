#----------------------------------------------------------------
#  core_hotkeys.rbx
#
#  Changelog:
#      Paulinchen  2026-10-12: Listed the hotkeys in their own group of the Mod Config, MGQ Online Hotkeys, apart from the settings
#      Paulinchen  2026-10-11: Added the hotkey that opens the bug report, F3 unless bound
#                            - Held every hotkey while a confirm box of the mod is open, which takes the press
#      Paulinchen  2026-10-10: Told that the party box size hotkey also shows the battle's raid boss bar with or without its title and name
#                            - Called every binding a hotkey in its help, and split the Party Box Size help into two lines
#      Paulinchen  2026-10-09: Added the hotkey that joins the battle of a player nearby in a Raid World, J unless bound
#      Paulinchen  2026-10-07: Logged the hotkeys bound as the game starts, each hotkey pressed and what it is for, and a setting that is no key
#      Paulinchen  2026-10-04: Added the party box size key, Tab unless bound, and named Tab
#                            - Added the emote wheel's key, E unless bound
#                            - Renamed from mp_hotkeys.rbx
#      Paulinchen  2026-10-03: Logged through MGQ_MpLog
#                            - Added the keys that accept and decline the first invite of the notification box
#                            - Renamed from mp_keys.rbx, with the module MGQ_MpHotkeys
#      Paulinchen  2026-10-02: Created
#
#----------------------------------------------------------------

# The hotkeys the player binds: what opens the action wheel, the emote wheel, the chat and the World
# overview, what accepts and declines the first invite of the notification box, what makes the
# party box small, what joins the battle of a player nearby in a Raid World, and what opens the bug
# report. Each is a key binding in Mod Config Remake when it is installed, listed in the group
# GROUP, and keeps its key in Patch/Multiplayer/Player.ini, so it holds in every save and every
# world.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpHotkeys
  # The first words of every hotkey's row in the Mod Config, which list the hotkeys in a group of
  # their own, apart from the settings (see MGQ_MpUi::OPTION_PREFIX).
  GROUP = "[MGQ Online Hotkeys] "

  # A hotkey the player binds.
  #
  # @!attribute setting [String] Its setting in Player.ini.
  # @!attribute default [Integer] Windows' code of its key until the player binds another.
  # @!attribute option [Symbol] Its option's key in the Mod Config.
  # @!attribute name [String] Its name in the Mod Config.
  # @!attribute help [String] Its help in the Mod Config.
  Binding = Struct.new(:setting, :default, :option, :name, :help)

  # The hotkeys the player binds, by what they open. The defaults are keys neither the game's Input
  # nor its gamepad plugin reads.
  BINDINGS = {
    :wheel => Binding.new("key_wheel", 0x42, :mp_key_wheel, "Action Wheel",
                          "The hotkey that opens and closes the action wheel on the map of a world."),
    :chat => Binding.new("key_chat", 0x54, :mp_key_chat, "Chat",
                         "The hotkey that opens the chat box of a world, on the map and in battles."),
    :overview => Binding.new("key_overview", 0x7A, :mp_key_overview, "World Overview",
                             "The hotkey that opens and closes the World overview in a world, and the PvP battle screen outside one."),
    :accept => Binding.new("key_accept", 0x59, :mp_key_accept, "Accept Notification",
                           "The hotkey that accepts the first invite or challenge in the notification box at the top left, in a world."),
    :decline => Binding.new("key_decline", 0x4E, :mp_key_decline, "Decline Notification",
                            "The hotkey that declines the first invite or challenge in the notification box at the top left, in a world."),
    :emotes => Binding.new("key_emotes", 0x45, :mp_key_emotes, "Emote Wheel",
                           "The hotkey that opens and closes the emote wheel on the map of a world: jump, or show a balloon above your character."),
    :party_box => Binding.new("key_party_box", 0x09, :mp_key_party_box, "Party Box Size",
                              "The hotkey that makes the party box at the top right small, with only names and pings, and full again.\n" \
                              "In a raid boss battle, it shows the boss's HP bar with or without its title and name."),
    :join_battle => Binding.new("key_join_battle", 0x4A, :mp_key_join_battle, "Join Battle",
                                "The hotkey that joins the battle of a player near you in a Raid World, while the prompt below your character shows."),
    :bug_report => Binding.new("key_bug_report", 0x72, :mp_key_bug_report, "Report a Bug",
                               "The hotkey that opens the bug report. Its screenshot is taken at the press."),
  }

  # Highest Windows key code.
  MAX_CODE = 0xFE

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "keys"

  # Reads the key bound to an action.
  #
  # @param action [Symbol] A key of BINDINGS.
  # @return [Integer] Windows' code of the key: the one the player bound, else the default.
  def self.code(action)
    binding = BINDINGS[action]
    stored = MGQ_Multiplayer::Player.setting(binding.setting).to_s
    return stored.to_i if stored =~ /\A\d+\z/ && stored.to_i.between?(1, MAX_CODE)

    log_once([:unreadable, action, stored], "#{binding.setting}=#{stored} in Player.ini is no key, #{action} keeps #{plain_name(binding.default)}") unless stored.empty?
    binding.default
  rescue
    BINDINGS[action].default
  end

  # Binds a key to an action.
  #
  # @param action [Symbol] A key of BINDINGS.
  # @param code [Integer] Windows' code of the key.
  def self.bind(action, code)
    MGQ_Multiplayer::Player.store(BINDINGS[action].setting, code)
    log("bound #{BINDINGS[action].name} to #{label(action)} (key code #{code})")
  end

  # Reports whether the key bound to an action went down since the last call for that key. A
  # press while a confirm box of the mod is open goes to the box: the key is read, so the press is
  # over, and nothing opens under the box.
  #
  # @param action [Symbol] A key of BINDINGS.
  # @return [Boolean] Whether it went down.
  def self.pressed?(action)
    pressed = MGQ_Multiplayer::Key.pressed?(code(action))
    if pressed && confirm_open?
      log("hotkey #{label(action)} went to the confirm box")
      return false
    end

    log_press(action) if pressed && !$mgq_text_input
    pressed
  end

  # Reports whether a confirm box of the mod is open, which takes every hotkey.
  #
  # @return [Boolean] Whether one is; false before ui.rbx loaded.
  def self.confirm_open?
    defined?(MGQ_MpUi::Confirm) && MGQ_MpUi::Confirm.open? ? true : false
  end

  # Logs a hotkey pressed and what it is for. Not while the player types, whose letters would land
  # in the log.
  #
  # @param action [Symbol] A key of BINDINGS.
  def self.log_press(action)
    log("hotkey #{label(action)} pressed: #{BINDINGS[action].name}")
  rescue
  end

  # Lists every hotkey with the key bound to it, for the log.
  #
  # @return [String] Each hotkey's name and key.
  def self.summary
    BINDINGS.map { |action, binding| "#{binding.name} #{label(action)}" }.join(", ")
  rescue => e
    "unreadable (#{e.class})"
  end

  # Names the key bound to an action, for the texts that tell the player which key to press.
  #
  # @param action [Symbol] A key of BINDINGS.
  # @return [String] The key's name, such as "T".
  def self.label(action)
    key = code(action)
    defined?(ModConfigRemake::Keys) ? ModConfigRemake::Keys.name(key) : plain_name(key)
  end

  # Names a key without Mod Config Remake 1.3.0, such as with an older version that bound it before:
  # letters, digits, F keys and Tab by their own name.
  #
  # @param code [Integer] Windows' code of the key.
  # @return [String] The name, such as "K", "F11" or "key 186".
  def self.plain_name(code)
    case code
    when 0x30..0x39, 0x41..0x5A then code.chr
    when 0x70..0x87 then "F#{code - 0x6F}"
    when 0x09 then "Tab"
    else "key #{code}"
    end
  end

  # Adds a key binding per action to Mod Config Remake 1.3.0 or later. With an older version or the
  # Mod Config Menu, which would show them as buttons that do nothing, the keys in Player.ini stay.
  def self.register
    log("hotkeys: #{summary}")
    unless defined?(ModConfigRemake::Keys)
      log("no key bindings in the Mod Config: Mod Config Remake 1.3.0 or later is not installed, the hotkeys stay as Player.ini keeps them")
      return
    end

    menu = NWConst::Config::MOD_CONTENTS
    BINDINGS.each do |action, binding|
      menu.insert(-2, :key => binding.option, :name => "#{GROUP}#{binding.name}", :keybind => true,
                      :help => binding.help, :value => lambda { code(action) }, :on_change => lambda { |key| bind(action, key) })
    end
    log("added #{BINDINGS.size} key bindings to Mod Config Remake")
  end
end

begin
  MGQ_MpHotkeys.register
rescue => e
  MGQ_MpHotkeys.log("options FAILED: #{e.class}: #{e.message}")
end
