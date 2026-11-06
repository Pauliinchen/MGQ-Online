#----------------------------------------------------------------
#  core_hotkeys.rbx
#
#  Changelog:
#      Paulinchen  2026-11-06: Read whether a mod types through the UI layer
#                            - Moved the Party Box Size hotkey from Tab to M
#      Paulinchen  2026-10-31: Defined the hotkeys through the Mod Framework, whose own Accept and Decline the notices read
#                            - Read the keys and the question box through the Mod Framework
#      Paulinchen  2026-10-24: Named the World overview in single player in the overview hotkey's help
#      Paulinchen  2026-10-12: Logged every refused hotkey here
#                            - Added the Leader HUD size hotkey
#                            - Listed the hotkeys in their own Mod Config group
#      Paulinchen  2026-10-11: Added the bug report hotkey
#                            - Held every hotkey while a confirm box is open
#      Paulinchen  2026-10-10: Mentioned the raid boss bar in the party box size help
#                            - Called every binding a hotkey and split the Party Box Size help
#      Paulinchen  2026-10-09: Added the join battle hotkey
#      Paulinchen  2026-10-07: Logged the bound hotkeys, each press and unreadable settings
#      Paulinchen  2026-10-04: Added the party box size hotkey and named Tab
#                            - Added the emote wheel hotkey
#                            - Renamed from mp_hotkeys.rbx
#      Paulinchen  2026-10-03: Logged through MGQ_MpLog
#                            - Added the accept and decline hotkeys
#                            - Renamed from mp_keys.rbx with the module MGQ_MpHotkeys
#      Paulinchen  2026-10-02: Created
#
#----------------------------------------------------------------

# The hotkeys the player binds, defined through the Mod Framework, which gives each its row in
# Options > Mods and keeps it quiet while any mod types or a question box is open. Each keeps its key
# in Patch/Multiplayer/Player.ini, so it holds in every save and every world. The scripts ask by a
# short name, such as :chat; :accept and :decline are the framework's own hotkeys.
module MGQ_MpHotkeys
  # The first words of every hotkey's row, which list the hotkeys in a group of their own, apart
  # from the settings (see MGQ_Multiplayer::OPTION_PREFIX).
  GROUP = "[MGQ Online Hotkeys] "

  # A hotkey MGQ Online defines.
  #
  # @!attribute action [Symbol] Its action in the Mod Framework.
  # @!attribute key [Integer] Windows' code of its key until the player binds another.
  # @!attribute setting [String] Its setting in Player.ini.
  # @!attribute name [String] Its row's name, without the group.
  # @!attribute help [String] Its row's help.
  Hotkey = Struct.new(:action, :key, :setting, :name, :help)

  # The hotkeys MGQ Online defines, by the short name the scripts ask by. The keys are ones neither
  # the game's Input nor its gamepad plugin reads.
  HOTKEYS = {
    :wheel => Hotkey.new(:mgq_online_wheel, 0x42, "key_wheel", "Action Wheel",
                         "The hotkey that opens and closes the action wheel on the map of a world."),
    :chat => Hotkey.new(:mgq_online_chat, 0x54, "key_chat", "Chat",
                        "The hotkey that opens the chat box of a world, on the map and in battles."),
    :overview => Hotkey.new(:mgq_online_overview, 0x7A, "key_overview", "World Overview",
                            "The hotkey that opens and closes the World overview, in a world and in single player."),
    :emotes => Hotkey.new(:mgq_online_emotes, 0x45, "key_emotes", "Emote Wheel",
                          "The hotkey that opens and closes the emote wheel on the map of a world: jump, or show a balloon above your character."),
    :party_box => Hotkey.new(:mgq_online_party_box, 0x4D, "key_party_box", "Party Box Size",
                             "The hotkey that makes the party box at the top right small, with only names and pings, and full again.\n" \
                             "In a raid boss battle, it shows the boss's HP bar with or without its title and name."),
    :leader_hud => Hotkey.new(:mgq_online_leader_hud, 0x48, "key_leader_hud", "Leader HUD Size",
                              "The hotkey that makes the Leader HUD at the top left of the map small, with the map sprite and the bars alone,\n" \
                              "and large again."),
    :join_battle => Hotkey.new(:mgq_online_join_battle, 0x4A, "key_join_battle", "Join Battle",
                               "The hotkey that joins the battle of a player near you in a Raid World, while the prompt below your character shows."),
    :bug_report => Hotkey.new(:mgq_online_bug_report, 0x72, "key_bug_report", "Report a Bug",
                              "The hotkey that opens the bug report. Its screenshot is taken at the press."),
  }

  # The Mod Framework's own hotkeys the scripts ask by, with their names for the log.
  FRAMEWORK = { :accept => "Accept Notification", :decline => "Decline Notification" }

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "keys"

  # Defines every hotkey of HOTKEYS through the Mod Framework.
  def self.define_all
    refused = HOTKEYS.reject do |_, hotkey|
      Mod_Framework::Hotkeys.define(hotkey.action, :key => hotkey.key, :name => GROUP + hotkey.name, :help => hotkey.help,
                                                   :store => MGQ_Multiplayer::Player, :setting => hotkey.setting, :log => self)
    end
    log("hotkeys: #{summary}")
    log("hotkeys the Mod Framework refused, see its log: #{refused.keys.join(', ')}") unless refused.empty?
  end

  # Finds the Mod Framework's action of a hotkey.
  #
  # @param name [Symbol] A key of HOTKEYS or FRAMEWORK.
  # @return [Symbol] The action.
  def self.action(name)
    HOTKEYS.key?(name) ? HOTKEYS[name].action : name
  end

  # Names a hotkey for the log.
  #
  # @param name [Symbol] A key of HOTKEYS or FRAMEWORK.
  # @return [String] Its name, such as "Chat".
  def self.name_of(name)
    HOTKEYS.key?(name) ? HOTKEYS[name].name : FRAMEWORK.fetch(name, name.to_s)
  end

  # Lists every hotkey the scripts ask by, MGQ Online's and the framework's.
  #
  # @return [Array<Symbol>] Their short names.
  def self.names
    HOTKEYS.keys + FRAMEWORK.keys
  end

  # Reads the key bound to a hotkey.
  #
  # @param name [Symbol] A key of HOTKEYS or FRAMEWORK.
  # @return [Integer, nil] Windows' code of the key: the one the player bound, else the default.
  def self.code(name)
    Mod_Framework::Hotkeys.code(action(name))
  end

  # Binds a key to a hotkey.
  #
  # @param name [Symbol] A key of HOTKEYS or FRAMEWORK.
  # @param code [Integer] Windows' code of the key.
  # @return [Boolean] Whether the key is kept.
  def self.bind(name, code)
    Mod_Framework::Hotkeys.bind(action(name), code)
  end

  # Reports whether the key bound to a hotkey went down since the last call for that key. A press
  # while any mod types or a question box is open is dropped, so nothing opens under them.
  #
  # @param name [Symbol] A key of HOTKEYS or FRAMEWORK.
  # @return [Boolean] Whether it went down.
  def self.pressed?(name)
    Mod_Framework::Hotkeys.pressed?(action(name))
  end

  # Logs why a hotkey pressed did nothing, for every script that refuses one. Nothing is logged
  # while any mod takes what the player types, whose letters would otherwise land in the log.
  #
  # @param name [Symbol] A key of HOTKEYS or FRAMEWORK.
  # @param reason [String] Why the hotkey did nothing.
  # @return [nil] Always.
  def self.log_refusal(name, reason)
    log("hotkey #{label(name)} (#{name_of(name)}) ignored: #{reason}") unless Mod_Framework::UI.typing?
    nil
  rescue
    nil
  end

  # Lists every hotkey with the key bound to it, for the log.
  #
  # @return [String] Each hotkey's name and key.
  def self.summary
    names.map { |name| "#{name_of(name)} #{label(name)}" }.join(", ")
  rescue => e
    "unreadable (#{e.class})"
  end

  # Names the key bound to a hotkey, for the texts that tell the player which key to press.
  #
  # @param name [Symbol] A key of HOTKEYS or FRAMEWORK.
  # @return [String] The key's name, such as "T".
  def self.label(name)
    Mod_Framework::Hotkeys.label(action(name))
  end
end

begin
  MGQ_MpHotkeys.define_all
rescue => e
  MGQ_MpHotkeys.log("defining the hotkeys FAILED: #{e.class}: #{e.message}")
end
