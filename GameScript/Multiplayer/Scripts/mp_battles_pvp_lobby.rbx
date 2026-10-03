#----------------------------------------------------------------
#  mp_battles_pvp_lobby.rbx
#
#  Changelog:
#      Paulinchen  2026-10-03: Spoke of the friend's team, which may have its Backline
#                            - Created
#
#----------------------------------------------------------------

# The PvP battle screen outside a world: hosting, joining with a join code, and the mirror
# match. It builds on mp_battles_pvp.rbx.

module MGQ_MpBattlesPvp
  # What the PvP battle screen says about the exchange.
  module Lobby
    # What the screen says before anything started.
    INTRO = [
      "Fight a friend's team, each of you against the other's.",
      "Host: invite a friend through the + in a Discord chat, or send",
      "them the join code. Join: copy their join code, then join with it.",
      "Or fight your own team in a mirror match.",
    ]

    # Describes how the exchange stands.
    #
    # @param state [Hash] The exchange, see MGQ_Multiplayer::Link.state.
    # @return [Array<String>] The lines to show.
    def self.lines_for(state)
      case state["state"]
      when "hosting"
        if state["code"]
          ["Hosting, waiting for a friend . . .",
           "Invite them through the + in a Discord chat, or send them the",
           "join code, which is on your clipboard."]
        else
          ["Hosting . . . reaching the relay."]
        end
      when "joining"
        ["Joining . . . swapping teams with your friend."]
      when "received"
        ["Your friend's team arrived."]
      when "failed"
        ["The PvP battle broke off:", state["error"].to_s]
      else
        INTRO
      end
    end

    # The commands the screen offers.
    #
    # @param state [Hash] The exchange, see MGQ_Multiplayer::Link.state.
    # @return [Array<Array>] A name and a symbol per command.
    def self.commands_for(state)
      commands = []

      case state["state"]
      when "hosting"
        commands.push(["Copy the join code again", :copy], ["Stop hosting", :stop])
      when "joining"
        commands.push(["Stop joining", :stop])
      else
        commands.push(["Host a PvP battle", :host], ["Join with the copied code", :join_clipboard])
        commands.push(["Fight your own team", :mirror])
      end

      commands.push(["Close", :cancel])
    end
  end
end

# The PvP battle screen, opened from the map with the World overview's key (MGQ_MpHotkeys) or when the map
# joins the host of a Discord invite.
#
# Named without "Battle", which the Discord mod reads as being in a fight.
class Scene_PvpLobby < Scene_MenuBase
  # Lines the window above the commands has room for.
  INFO_LINES = 4

  # Creates the windows and reads the exchange.
  def start
    super
    @info_window = Window_MpInfo.new(INFO_LINES)
    @command_window = Window_PvpLobbyCommand.new(@info_window.height)
    @command_window.set_handler(:host, method(:on_host))
    @command_window.set_handler(:join_clipboard, method(:on_join_clipboard))
    @command_window.set_handler(:copy, method(:on_copy))
    @command_window.set_handler(:stop, method(:on_stop))
    @command_window.set_handler(:mirror, method(:on_mirror))
    @command_window.set_handler(:cancel, method(:on_close))
    @frames = 0
    refresh_state
  end

  # Looks at the exchange every MGQ_MpBattlesPvp::POLL_INTERVAL frames.
  def update
    super
    @frames += 1
    return if @frames < MGQ_MpBattlesPvp::POLL_INTERVAL

    @frames = 0
    refresh_state
  end

  # Joins the host of a Discord invite, shows how the exchange stands, and goes back to the map once
  # the friend's team arrived, which starts the battle there.
  def refresh_state
    @state = MGQ_Multiplayer::Link.status
    @state = MGQ_Multiplayer::Link.status if MGQ_MpBattlesPvp.join_invite(@state)
    @ignored_invite ||= MGQ_MpBattlesPvp.ignored_invite?(@state)
    @info_window.show((@ignored_invite ? [MGQ_MpBattlesPvp::IGNORED_INVITE] : []) + MGQ_MpBattlesPvp::Lobby.lines_for(@state))
    @command_window.state = @state
    return_scene if @state["state"] == "received"
  rescue => e
    MGQ_MpBattlesPvp.log("screen failed: #{e.class}: #{e.message}")
    return_scene
  end

  # Starts hosting.
  def on_host
    MGQ_Multiplayer::Link.host(MGQ_MpBattlesPvp::Team.game, MGQ_MpBattlesPvp::Team.build)
    after_command
  end

  # Joins with the join code on the clipboard.
  def on_join_clipboard
    MGQ_Multiplayer::Link.join_clipboard(MGQ_MpBattlesPvp::Team.game, MGQ_MpBattlesPvp::Team.build)
    after_command
  end

  # Puts the join code on the clipboard again.
  def on_copy
    MGQ_Multiplayer::Link.copy_code ? Sound.play_ok : Sound.play_buzzer
    after_command
  end

  # Stops hosting or joining.
  def on_stop
    MGQ_Multiplayer::Link.cancel
    after_command
  end

  # Goes back to the map, which starts the mirror match there.
  def on_mirror
    MGQ_MpBattlesPvp.request_mirror
    return_scene
  end

  # Closes the screen. Hosting and joining go on meanwhile, a failure is cleared.
  def on_close
    MGQ_Multiplayer::Link.cancel if @state && @state["state"] == "failed"
    return_scene
  end

  # Shows the result of a command right away and takes the next one.
  def after_command
    refresh_state
    @command_window.activate
  end
end

# The PvP battle screen's commands, which follow how the exchange stands.
class Window_PvpLobbyCommand < Window_Command
  # Width of the window.
  WIDTH = 360

  # Creates the command window.
  #
  # @param y [Integer] The top edge, below the lines.
  def initialize(y)
    @commands = MGQ_MpBattlesPvp::Lobby.commands_for("state" => "idle")
    super(0, y)
    self.x = (Graphics.width - width) / 2
  end

  # Returns the window's width.
  #
  # @return [Integer] The window's width.
  def window_width
    WIDTH
  end

  # Offers the commands of a state, if they changed.
  #
  # @param state [Hash] The exchange, see MGQ_Multiplayer::Link.state.
  def state=(state)
    commands = MGQ_MpBattlesPvp::Lobby.commands_for(state)
    return if commands == @commands

    @commands = commands
    clear_command_list
    make_command_list
    self.height = window_height
    refresh
    select(0) if index >= item_max
  end

  # Lists the commands of the state.
  def make_command_list
    @commands.each { |name, symbol| add_command(name, symbol) }
  end
end
