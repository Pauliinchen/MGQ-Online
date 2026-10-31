#----------------------------------------------------------------
#  ui_online.rbx
#
#  Changelog:
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

# What MGQ Online's screens keep of their own now that their input, look, places, text boxes,
# question box and wheels are the Mod Framework's: the groups of the mod's rows in Options > Mods,
# the color a player is named in and the strip a raid boss bar takes at the top. MGQ_MpUi is the
# one name the old screens reach the framework's interface by until they are rebuilt on its
# components.

module MGQ_Multiplayer
  # What the names of the mod's settings rows in Options > Mods start with.
  OPTION_PREFIX = "[MGQ Online Settings] "

  # What the names of the single player settings rows start with.
  SP_PREFIX = "[MGQ Online SP] "
end

# The framework's interface under the name the old screens know it by. Nothing reopens it.
MGQ_MpUi = Mod_Framework::UI unless defined?(MGQ_MpUi)

# The color a player is named in everywhere: Style::OWN for the player themself, Style::MEMBER for
# a party member and Style::TEXT for anyone else.
module MGQ_MpPlayerColor
  # What the player's own color is called in the log.
  OWN_NAME = "own"

  # What a party member's color is called in the log.
  MEMBER_NAME = "member"

  # What anyone else's color is called in the log.
  PLAIN_NAME = "plain"

  # Finds a player's id.
  #
  # @param who [MGQ_MpOverworldSync::Peers::Peer, Hash, String, Symbol] A peer, a state hash with
  #   "id", an id, or :me.
  # @return [String] The id, "" for none.
  def self.id_of(who)
    if who == :me
      defined?(MGQ_MpOverworldSync::Me) ? MGQ_MpOverworldSync::Me.id.to_s : ""
    elsif who.is_a?(String)
      who
    elsif who.is_a?(Hash)
      who["id"].to_s
    elsif who.respond_to?(:state) && who.state.is_a?(Hash)
      who.state["id"].to_s
    else
      ""
    end
  rescue
    ""
  end

  # Picks a player's color: Style::OWN for the player themself, Style::MEMBER for a party member,
  # else Style::TEXT, also for one it cannot read.
  #
  # @param who [Peer, Hash, String, Symbol] See id_of.
  # @param member [Boolean, nil] Whether they are in the player's party; nil derives it from a peer's
  #   member, a state hash through MGQ_MpCoop::Party.member? once coop loaded, false for an id.
  # @param own [Boolean, nil] Whether they are the player; nil derives it from :me, or an id equal
  #   to MGQ_MpOverworldSync::Me.id once overworld_sync loaded.
  # @return [Color] The color.
  def self.of(who, member = nil, own = nil)
    style = Mod_Framework::UI::Style
    { :own => style::OWN, :member => style::MEMBER }.fetch(pick(who, member, own), style::TEXT)
  end

  # Names a player's color for the log: "own", "member" or "plain".
  #
  # @param who [Peer, Hash, String, Symbol] See id_of.
  # @param member [Boolean, nil] See of.
  # @param own [Boolean, nil] See of.
  # @return [String] The name.
  def self.label(who, member = nil, own = nil)
    { :own => OWN_NAME, :member => MEMBER_NAME }.fetch(pick(who, member, own), PLAIN_NAME)
  end

  # Tells which of the three a player is, which of and label name in their own way.
  #
  # @param who [Peer, Hash, String, Symbol] See id_of.
  # @param member [Boolean, nil] See of.
  # @param own [Boolean, nil] See of.
  # @return [Symbol] :own for the player themself, :member for a party member, :plain for anyone
  #   else or one it cannot read.
  def self.pick(who, member = nil, own = nil)
    return :own if own.nil? ? own?(who) : own
    return :member if member.nil? ? member?(who) : member

    :plain
  rescue
    :plain
  end

  # Tells whether a player is the player themself.
  #
  # @param who [Peer, Hash, String, Symbol] See id_of.
  # @return [Boolean] Whether they are.
  def self.own?(who)
    return true if who == :me
    return false unless defined?(MGQ_MpOverworldSync::Me)

    id = id_of(who)
    !id.empty? && id == MGQ_MpOverworldSync::Me.id.to_s
  end

  # Tells whether a player is in the player's party.
  #
  # @param who [Peer, Hash, String, Symbol] See id_of.
  # @return [Boolean] Whether they are.
  def self.member?(who)
    return who.member ? true : false if who.respond_to?(:member)
    return false unless who.is_a?(Hash) && defined?(MGQ_MpCoop::Party)

    MGQ_MpCoop::Party.member?(who) ? true : false
  end
end

# The strip at the top of the map's screen a box of the mod takes, such as the raid boss's bar,
# which the boxes there move down by.
module MGQ_MpHud
  # The pixels the strip takes, 0 while none shows.
  @top_room = 0

  # Tells the pixels at the top of the map's screen a strip of the mod takes.
  #
  # @return [Integer] The pixels, 0 while none shows.
  def self.top_room
    @top_room
  end

  # Sets the pixels at the top of the map's screen a strip of the mod takes, see top_room.
  #
  # @param pixels [Integer] The pixels.
  def self.top_room=(pixels)
    @top_room = pixels.to_i
  end
end
