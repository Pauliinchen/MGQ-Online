#----------------------------------------------------------------
#  coop_squad.rbx
#
#  Changelog:
#      Paulinchen  2026-10-04: Renamed from mp_coop_squad.rbx
#      Paulinchen  2026-10-03: Sent messages, showed notices and read the world, the own id and the own seat through MGQ_MpOverworldSync
#                            - Logged through MGQ_MpLog
#      Paulinchen  2026-10-02: Installed the hooks on the game's plugins through core_hooks.rbx
#                            - Took whether the player plays in a party from coop.rbx, and dropped squad, which co-op battles count otherwise
#      Paulinchen  2026-10-01: Created
#
#----------------------------------------------------------------

# A party's squads: the players of a party share one single-player team between them. The four
# places of the Frontline and the Backline's places are split between the players, the party's
# leader taking what does not split evenly, so each player keeps a squad of their first characters
# and the rest are cut. Only the squad fights in co-op battles (battles_coop.rbx). The formation
# screens show the squad's Frontline and Backline as the game shows its own, and the cut characters
# monochrome under a line. On the map only each player's share of the Frontline follows them, or
# nobody, as the leader chose in the Mod Config.
#
# A battle a player fights alone keeps their own full team, so nothing here changes the game's
# party itself.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpCoopSquad
  # Places of the Frontline, the game's battle members.
  FRONTLINE = 4

  # The option of followers in a party, its key in $game_system.conf.
  FOLLOWERS = :mp_party_followers

  # Followers' value that shows each player's share of the Frontline.
  ACTIVE_FRONTLINE = 0

  # Followers' value that shows the players alone.
  LEADERS_ONLY = 1

  # Followers' values by their name and help in the Mod Config. The first one is the default.
  FOLLOWER_VALUES = {
    ACTIVE_FRONTLINE => ["Active Frontline", "Each player's own share of the Frontline walks behind them."],
    LEADERS_ONLY => ["Leaders Only", "The players walk alone."],
  }

  # Color of the line above the first character past a squad in the formation screens.
  CUT_COLOR = Color.new(255, 128, 96)

  # Shares of red, green and blue in a color's brightness, which a monochrome picture keeps.
  LUMA = [0.299, 0.587, 0.114]

  @shown = nil
  @monochrome = {}

  extend MGQ_MpLog

  # What starts this script's lines in the mod's InGame.log.
  LOG_TAG = "co-op squad"

  # Splits places between players, one more each for the first ones while some are left over.
  #
  # @param total [Integer] The places.
  # @param count [Integer] The players.
  # @return [Array<Integer>] Each player's places, in the players' order.
  def self.split(total, count)
    return [] if count < 1

    total = [total, 0].max
    (0...count).map { |position| total / count + (position < total % count ? 1 : 0) }
  end

  # Tells a player's squad: their share of the Frontline and of the Backline.
  #
  # @param position [Integer] The player's place among the players, the leader first.
  # @param count [Integer] The players.
  # @param max [Integer] The player's party_member_max, Frontline and Backline together.
  # @return [Array<Integer>] The Frontline's and the Backline's share.
  def self.share(position, count, max)
    [split(FRONTLINE, count)[position].to_i, split(max - FRONTLINE, count)[position].to_i]
  end

  # Orders players as every member's game does: the leader first, then by their ids.
  #
  # @param players [Array<Array>] Each player's id and whether they lead.
  # @return [Array<String>] The ids in order.
  def self.ranked(players)
    players.sort_by { |id, leads| [leads ? 0 : 1, id.to_s] }.map { |id, _| id.to_s }
  end

  # Tells the player's squad in their party.
  #
  # @return [Array<Integer>, nil] The Frontline's and the Backline's share, nil outside a party.
  def self.own_share
    return nil unless MGQ_MpCoop.in_party?

    party = MGQ_MpCoop::Party
    leader = party.leader
    own_id = MGQ_MpOverworldSync::Me.id
    players = [[own_id, leader == :me]] + party.members.map { |peer| [peer.state["id"].to_s, peer.equal?(leader)] }
    order = ranked(players)
    share(order.index(own_id), order.size, $game_party.party_member_max)
  end

  # Lists the player's characters in the order their squad takes them.
  #
  # @return [Array<Game_Actor>] The characters that exist, the Frontline first.
  def self.own_order
    $game_party.all_members.select(&:exist?)
  end

  # Tells where a character stands in the player's squad.
  #
  # @param actor [Game_Actor, nil] The character.
  # @return [Symbol, nil] :front, :bench or :cut, nil outside a party or for no character.
  def self.place_of(actor)
    return nil unless actor && MGQ_MpCoop.in_party?

    index = own_order.index(actor)
    index ? place_at(index) : :cut
  end

  # Tells what a place of the player's order is in their squad.
  #
  # @param index [Integer] The place, 0 for the player's first character.
  # @return [Symbol, nil] :front, :bench or :cut, nil outside a party.
  def self.place_at(index)
    front, bench = own_share
    return nil unless front
    return :front if index < front

    index < front + bench ? :bench : :cut
  end

  # Reads how followers show in the party: the leader's choice, the player's own when they lead or
  # play outside a party.
  #
  # @return [Integer] ACTIVE_FRONTLINE or LEADERS_ONLY.
  def self.mode
    leader = MGQ_MpCoop.in_party? ? MGQ_MpCoop::Party.leader : :me
    value = leader == :me || leader.nil? ? own_mode : leader.state["follow"]
    value.to_s == LEADERS_ONLY.to_s ? LEADERS_ONLY : ACTIVE_FRONTLINE
  end

  # Reads the player's own choice of followers in the Mod Config.
  #
  # @return [Integer] ACTIVE_FRONTLINE or LEADERS_ONLY.
  def self.own_mode
    value = $game_system.conf[FOLLOWERS] rescue nil
    value.to_i == LEADERS_ONLY ? LEADERS_ONLY : ACTIVE_FRONTLINE
  end

  # Reports whether a follower shows on the map: in a party only the player's share of the
  # Frontline, and nobody when the party's leader chose the players alone. Reads the share and the
  # choice tick took this frame, since the game asks for every follower several times a frame.
  #
  # @param member_index [Integer] The follower's place in the Frontline, 1 for the first behind the
  #   player.
  # @return [Boolean] Whether it shows; outside a party, always.
  def self.follower_shown?(member_index)
    share, shown_mode = @shown
    return true unless share

    shown_mode == ACTIVE_FRONTLINE && member_index.to_i < share[0]
  rescue
    true
  end

  # Turns a color into the grey of the same brightness.
  #
  # @param color [Color] The color.
  # @return [Color] The grey, with the color's opacity.
  def self.grey(color)
    level = color.red * LUMA[0] + color.green * LUMA[1] + color.blue * LUMA[2]
    Color.new(level, level, level, color.alpha)
  end

  # Makes a monochrome copy of part of a picture, once per picture and part.
  #
  # The copies stay for the session, since reading and writing every pixel is slow.
  #
  # @param name [String] What the picture is, which keys the copy.
  # @param source [Bitmap] The picture.
  # @param rect [Rect] The part.
  # @return [Bitmap] The copy.
  def self.monochrome(name, source, rect)
    key = [name, rect.x, rect.y, rect.width, rect.height]
    copy = @monochrome[key]
    return copy if copy && !copy.disposed?

    copy = Bitmap.new(rect.width, rect.height)
    copy.blt(0, 0, source, rect)
    rect.height.times do |y|
      rect.width.times do |x|
        color = copy.get_pixel(x, y)
        copy.set_pixel(x, y, grey(color)) if color.alpha > 0
      end
    end
    @monochrome[key] = copy
  end

  # Writes the looks of the followers the player shows, which their party's games show behind
  # their ghost.
  #
  # @return [String] Each follower's sprite and index, "name*index" joined by "|".
  def self.trail
    return "" unless MGQ_MpCoop.in_party? && $game_player

    shown = []
    $game_player.followers.each do |follower|
      shown << "#{follower.character_name}*#{follower.character_index}" if follower.visible? && !follower.character_name.to_s.empty?
    end
    shown.join("|")
  end

  # Reads the looks of a ghost's followers.
  #
  # @param text [String, nil] The trail the ghost's player told, see trail.
  # @return [Array<Array>] Each follower's sprite and index.
  def self.parse_trail(text)
    text.to_s.split("|").map do |part|
      name, index = part.split("*", 2)
      [name.to_s, index.to_i]
    end.reject { |name, _| name.empty? }
  end

  # The fields the squad adds to the state the player's game tells the others.
  #
  # @return [Hash] The followers' mode, the player's choice or the leader's they follow, and the
  #   looks of the followers the player shows.
  def self.state_fields
    { "follow" => mode, "trail" => trail }
  end

  # Shows the followers anew once the party, the player's share or the leader's choice changed.
  # Called every frame in every scene.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    shown = in_world ? [own_share, mode] : nil
    return if shown == @shown

    @shown = shown
    $game_player.refresh if $game_player
  end

  # Adds the followers' option to the Mod Config, or to the game's options without it.
  def self.register
    config = NWConst::Config
    menu = config.const_defined?(:MOD_CONTENTS) ? config::MOD_CONTENTS : config::CONTENTS
    menu.insert(-2, :key => FOLLOWERS, :name => "[Monster Girl Quest! Online] Party Followers", :sub => true,
                    :help => "Who walks behind the players of a party. The party's leader decides for everyone.\r\n←/→ Toggle",
                    :enable => lambda { !MGQ_MpCoop.in_party? || MGQ_MpCoop::Party.leader == :me })
    config::DATA[FOLLOWERS] = FOLLOWER_VALUES.keys
    config::DATA_TEXT[FOLLOWERS] = {}
    FOLLOWER_VALUES.each { |value, (label, text)| config::DATA_TEXT[FOLLOWERS][value] = { :name => label, :help => text } }
    config::DEFAULT[FOLLOWERS] = FOLLOWER_VALUES.keys.first
  end

  # Draws the line under the squad's last character, on top of a row of the first cut character.
  #
  # @param window [Window_Base] The formation screen's window.
  # @param rect [Rect] The row.
  def self.draw_cut(window, rect)
    window.contents.fill_rect(rect.x, rect.y, rect.width, 2, CUT_COLOR)
  end

  # Installs the hooks on the game's plugins, which load after the Patch folder. Called once the
  # first scene starts.
  def self.install
    return if @installed

    @installed = true
    install_followers
    install_menu
    install_party_edit
  end

  # Shows only the player's share of the Frontline behind them in a party, or nobody when the
  # party's leader chose the players alone.
  def self.install_followers
    Game_Follower.class_eval do
      alias_method :mgq_mp_coop_squad_visible?, :visible?

      # Reports whether the follower shows: as in single player, but in a party only while it is in
      # the player's share of the Frontline.
      #
      # @return [Boolean] Whether it shows.
      def visible?
        mgq_mp_coop_squad_visible? && MGQ_MpCoopSquad.follower_shown?(@member_index)
      end
    end
  rescue => e
    log("follower hook FAILED: #{e.class}: #{e.message}")
  end

  # Draws the menu's formation list by the party's squad: the Frontline's share as the Frontline,
  # the Backline's share as the Backline, and the rest monochrome under a line.
  def self.install_menu
    Window_MenuStatus.class_eval do
      alias_method :mgq_mp_coop_squad_draw_item, :draw_item
      alias_method :mgq_mp_coop_squad_draw_actor_face, :draw_actor_face
      alias_method :mgq_mp_coop_squad_text_color, :text_color
      alias_method :mgq_mp_coop_squad_draw_icon, :draw_icon

      # Draws a character as the game does, in the style of their place in the party's squad
      # while the player is in a party, with a line above the first character past the squad.
      #
      # @param index [Integer] The row.
      def draw_item(index)
        squad = MGQ_MpCoopSquad
        place = instance_of?(Window_MenuStatus) && !$game_party.in_battle ? squad.place_of($game_party.members[index]) : nil
        @mgq_mp_coop_squad_place = place
        mgq_mp_coop_squad_draw_item(index)
        return unless place == :cut && !(index > 0 && squad.place_of($game_party.members[index - 1]) == :cut)

        squad.draw_cut(self, item_rect(index))
      rescue => e
        MGQ_MpCoopSquad.log("menu row failed: #{e.class}: #{e.message}")
      ensure
        @mgq_mp_coop_squad_place = nil
      end

      # Draws a face: opaque on the squad's Frontline, translucent on its Backline as the game draws
      # the Backline, monochrome past the squad.
      #
      # @param actor [Game_Actor] The character.
      # @param x [Integer] The face's left edge.
      # @param y [Integer] The face's top edge.
      # @param enabled [Boolean] Whether the game draws it opaque.
      def draw_actor_face(actor, x, y, enabled = true)
        case @mgq_mp_coop_squad_place
        when nil then mgq_mp_coop_squad_draw_actor_face(actor, x, y, enabled)
        when :cut
          rect = Rect.new(actor.face_index % 4 * 96, actor.face_index / 4 * 96, 96, 96)
          contents.blt(x, y, MGQ_MpCoopSquad.monochrome("face:#{actor.face_name}", Cache.face(actor.face_name), rect), Rect.new(0, 0, 96, 96))
        else mgq_mp_coop_squad_draw_actor_face(actor, x, y, @mgq_mp_coop_squad_place == :front)
        end
      end

      # Picks a text color of the window's skin, grey past the squad.
      #
      # @param n [Integer] The color's number.
      # @return [Color] The color.
      def text_color(n)
        color = mgq_mp_coop_squad_text_color(n)
        @mgq_mp_coop_squad_place == :cut ? MGQ_MpCoopSquad.grey(color) : color
      end

      # Draws an icon, monochrome past the squad.
      #
      # @param icon_index [Integer] The icon.
      # @param x [Integer] Its left edge.
      # @param y [Integer] Its top edge.
      # @param enabled [Boolean] Whether it is drawn opaque.
      def draw_icon(icon_index, x, y, enabled = true)
        return mgq_mp_coop_squad_draw_icon(icon_index, x, y, enabled) unless @mgq_mp_coop_squad_place == :cut

        rect = Rect.new(icon_index % 16 * 24, icon_index / 16 * 24, 24, 24)
        contents.blt(x, y, MGQ_MpCoopSquad.monochrome("icon", Cache.system("Iconset"), rect), Rect.new(0, 0, 24, 24))
      end
    end
  rescue => e
    log("menu hook FAILED: #{e.class}: #{e.message}")
  end

  # Colors the party edit screen by the party's squad: the Frontline's share as the Frontline, the
  # Backline's share as the Backline, and the rest grey under a line. The game's own drawing stays,
  # with the translation's larger rows.
  def self.install_party_edit
    return unless defined?(Foo::PTEdit::Window_PartyMember)

    Foo::PTEdit::Window_PartyMember.class_eval do
      alias_method :mgq_mp_coop_squad_draw_item, :draw_item
      alias_method :mgq_mp_coop_squad_change_color, :change_color

      # Draws a row as the game does, in the color of its place in the party's squad while the
      # player is in a party, with a line above the first row past the squad.
      #
      # @param index [Integer] The row.
      def draw_item(index)
        place = MGQ_MpCoop.in_party? ? mgq_mp_coop_squad_place(index) : nil
        @mgq_mp_coop_squad_place = place
        mgq_mp_coop_squad_draw_item(index)
        return unless place == :cut && index > 0 && mgq_mp_coop_squad_place(index - 1) != :cut

        MGQ_MpCoopSquad.draw_cut(self, item_rect(index))
      rescue => e
        MGQ_MpCoopSquad.log("party edit row failed: #{e.class}: #{e.message}")
      ensure
        @mgq_mp_coop_squad_place = nil
      end

      # Sets the text color, by the row's place in the party's squad while one is drawn.
      #
      # @param color [Color] The color the game picked by the Frontline of single player.
      # @param enabled [Boolean] Whether the row can be picked.
      def change_color(color, enabled = true)
        case @mgq_mp_coop_squad_place
        when :front then color = normal_color
        when :bench then color = system_color
        when :cut then color = MGQ_MpCoopSquad.grey(system_color)
        end
        mgq_mp_coop_squad_change_color(color, enabled)
      end

      # Tells a row's place in the party's squad: its character's, or the place itself for an
      # empty row.
      #
      # @param index [Integer] The row.
      # @return [Symbol] :front, :bench or :cut.
      def mgq_mp_coop_squad_place(index)
        id = @actors[index]
        (id ? MGQ_MpCoopSquad.place_of($game_actors[id]) : MGQ_MpCoopSquad.place_at(index)) || :cut
      end
    end
  rescue => e
    log("party edit hook FAILED: #{e.class}: #{e.message}")
  end
end

# What the squad takes part in of the world's messages, through overworld_sync.rbx, and its
# option.

begin
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpCoopSquad.tick(in_world) }
  MGQ_MpOverworldSync.state_fields { MGQ_MpCoopSquad.state_fields }
rescue => e
  MGQ_MpCoopSquad.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

begin
  MGQ_MpCoopSquad.register
rescue => e
  MGQ_MpCoopSquad.log("option FAILED: #{e.class}: #{e.message}")
end

# Game hooks, through core_hooks.rbx.

begin
  # Installs the hooks on the game's plugins as the game starts running.
  MGQ_MpHooks.before(SceneManager.singleton_class, :run, "coop_squad") { MGQ_MpCoopSquad.install }
rescue => e
  MGQ_MpCoopSquad.log("SceneManager hook FAILED: #{e.class}: #{e.message}")
end
