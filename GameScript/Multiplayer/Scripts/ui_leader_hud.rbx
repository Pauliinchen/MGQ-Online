#----------------------------------------------------------------
#  ui_leader_hud.rbx
#
#  Changelog:
#      Paulinchen  2026-11-01: Built the HUD on the Mod Framework's components, docked at the top left under the game's windows
#                            - Asked the wheels of the Mod Framework whether one is open
#      Paulinchen  2026-10-31: Kept its rows and its place through the Mod Framework
#      Paulinchen  2026-10-23: Kept the HUD off the live map behind menus
#      Paulinchen  2026-10-13: Turned the HUD on and off in single player by a row of its own in MGQ Online SP
#      Paulinchen  2026-10-12: Let other boxes draw a face or a map sprite as the HUD does
#                            - Held the Small HUD to its own least size at the edges of the screen
#                            - Logged a refused hotkey through MGQ_MpHotkeys.log_refusal
#                            - Read the map's viewport through MGQ_MpGame
#                            - Created
#
#----------------------------------------------------------------

# The Leader HUD: the player's Formation Leader at the top left of the map, until the player moves
# it, with their name and base level, their HP and MP, and how far they are to their next base, job
# and race level. The Large size shows their face and writes the numbers into the HP and MP bars,
# the Small size shows their map sprite and the bars alone. The player turns it on and off and
# picks its size in the Mod Config, or switches the size with its hotkey (H unless the player binds
# another, see core_hotkeys.rbx), kept in Player.ini, so it shows in single player too. It is a box
# of the Mod Framework docked at the top left, under the game's windows (see View).
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpLeaderHud
  # The setting in Player.ini that turns the HUD off with 0 inside a world.
  SHOWN_SETTING = "leader_hud"

  # The setting in Player.ini that turns the HUD off with 0 outside a world.
  SP_SHOWN_SETTING = "sp_leader_hud"

  # The setting in Player.ini that keeps the HUD's size, LARGE or SMALL.
  SIZE_SETTING = "leader_hud_size"

  # The size that shows the face and the numbers in the bars.
  LARGE = "Large"

  # The size that shows the map sprite and the bars alone.
  SMALL = "Small"

  # The sizes, the first the one until the player picks another.
  SIZES = [LARGE, SMALL]

  # The Mod Config row's value that turns the HUD on.
  ON = "On"

  # The Mod Config row's value that turns the HUD off.
  OFF = "Off"

  # The key of the Mod Config row that turns the HUD on and off.
  SHOWN_OPTION = :mp_leader_hud

  # The name of the Mod Config row that turns the HUD on and off.
  SHOWN_OPTION_NAME = "Leader HUD"

  # The help of the Mod Config row that turns the HUD on and off.
  SHOWN_OPTION_HELP = "Inside worlds, shows the Formation Leader at the top left of the map with their HP, MP and how\n" \
                      "far they are to their next levels; MGQ Online SP decides outside. Alt and drag moves it."

  # The key of the Mod Config row that turns the HUD on and off outside a world, which
  # ui_single_player.rbx adds.
  SP_SHOWN_OPTION = :mp_sp_leader_hud

  # The help of the Mod Config row that turns the HUD on and off outside a world.
  SP_SHOWN_OPTION_HELP = "Shows the Formation Leader at the top left of the map in single player, outside a world.\n" \
                         "Inside a world, MGQ Online Settings decides."

  # The key of the Mod Config row that picks the HUD's size.
  SIZE_OPTION = :mp_leader_hud_size

  # The name of the Mod Config row that picks the HUD's size.
  SIZE_OPTION_NAME = "Leader HUD Size"

  # The help of the Mod Config row that picks the HUD's size.
  SIZE_OPTION_HELP = "Large shows the face and the numbers in the HP and MP bars, Small the map sprite\n" \
                     "and the bars alone. The Leader HUD Size hotkey switches them on the map."

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "leader hud"

  # The Mod Framework's interface.
  UI = Mod_Framework::UI

  # The map scene's windows that open at the top left, by their field in MGQ_MpGame: the map's
  # name and the medal just won.
  TOP_LEFT_WINDOWS = [:map_name_window, :gain_medal_window]

  # Room between the boxes docked at the top left and the windows moved below them.
  BELOW = 4

  # Where the game put each of TOP_LEFT_WINDOWS, by the window.
  @tops = {}

  # Reports whether the player wants the HUD inside a world, as Player.ini keeps it, on until they
  # turn it off.
  #
  # @return [Boolean] Whether it shows.
  def self.shown?
    @shown = MGQ_Multiplayer::Player.setting(SHOWN_SETTING).to_s != "0" if @shown.nil?
    @shown
  end

  # Reports whether the player wants the HUD outside a world, as Player.ini keeps it: as inside a
  # world until they set it, so a HUD turned off before the setting existed stays off.
  #
  # @return [Boolean] Whether it shows.
  def self.sp_shown?
    @sp_shown = (MGQ_Multiplayer::Player.setting(SP_SHOWN_SETTING) || MGQ_Multiplayer::Player.setting(SHOWN_SETTING)).to_s != "0" if @sp_shown.nil?
    @sp_shown
  end

  # Reports whether the HUD shows now: inside a world as shown? says, else as sp_shown? says.
  #
  # @return [Boolean] Whether it does.
  def self.on?
    MGQ_MpOverworldSync.in_world? ? shown? : sp_shown?
  end

  # Finds the Formation Leader the HUD shows.
  #
  # @return [Game_Actor, nil] The leader, nil without a party.
  def self.leader
    $game_party && $game_party.leader
  end

  # Reports whether the HUD shows this frame: there is a leader, the player has the HUD on and the
  # game's top message does not show.
  #
  # @return [Boolean] Whether it does.
  def self.shows?
    leader && on? && !top_message? ? true : false
  rescue => e
    log_once(:shows, "telling whether the Leader HUD shows failed: #{e.class}: #{e.message}")
    false
  end

  # Tells the size the player picked, as Player.ini keeps it.
  #
  # @return [String] LARGE or SMALL.
  def self.size
    @size ||= SIZES.find { |size| size.downcase == MGQ_Multiplayer::Player.setting(SIZE_SETTING).to_s.strip.downcase } || SIZES.first
  end

  # Turns the HUD on or off and keeps the choice in Player.ini.
  #
  # @param shown [Boolean] Whether it shows.
  def self.show(shown)
    @shown = shown ? true : false
    MGQ_Multiplayer::Player.store(SHOWN_SETTING, @shown ? 1 : 0)
    log("the Leader HUD is #{@shown ? 'on' : 'off'}")
  rescue => e
    log("keeping whether the Leader HUD shows FAILED: #{e.class}: #{e.message}")
  end

  # Turns the HUD on or off outside a world and keeps the choice in Player.ini.
  #
  # @param shown [Boolean] Whether it shows.
  def self.show_sp(shown)
    @sp_shown = shown ? true : false
    MGQ_Multiplayer::Player.store(SP_SHOWN_SETTING, @sp_shown ? 1 : 0)
    log("the Leader HUD is #{@sp_shown ? 'on' : 'off'} in single player")
  rescue => e
    log("keeping whether the Leader HUD shows in single player FAILED: #{e.class}: #{e.message}")
  end

  # Picks the HUD's size and keeps it in Player.ini.
  #
  # @param size [String] LARGE or SMALL; another keeps the first.
  def self.resize(size)
    @size = SIZES.include?(size) ? size : SIZES.first
    MGQ_Multiplayer::Player.store(SIZE_SETTING, @size)
    log("the Leader HUD is #{@size}")
  rescue => e
    log("keeping the Leader HUD's size FAILED: #{e.class}: #{e.message}")
  end

  # Switches the HUD between its sizes on its hotkey, on the map while nothing else takes the keys.
  # Called by the map every frame no scene change is in the way, so a press of the hotkey is seen
  # once.
  def self.on_map
    return unless MGQ_MpHotkeys.pressed?(:leader_hud)

    reason = busy_reason
    return MGQ_MpHotkeys.log_refusal(:leader_hud, reason) if reason

    resize(size == LARGE ? SMALL : LARGE)
    Sound.play_cursor
  rescue => e
    log_once(:on_map, "changing the Leader HUD's size failed: #{e.class}: #{e.message}")
  end

  # Tells why the size hotkey does nothing now.
  #
  # @return [String, nil] The first reason that holds, nil when the hotkey may change the size.
  def self.busy_reason
    return "the HUD is off" unless on?
    return "the chat box is open" if MGQ_MpChat.typing?
    return "the action wheel is open" if MGQ_MpActions.wheel.open?
    return "the emote wheel is open" if MGQ_MpEmotes.wheel.open?

    nil
  end

  # Moves the map scene's windows that open at the top left below the boxes docked there, such as
  # the HUD at its default place, and back to where the game put them once none takes room there.
  def self.lower_windows
    scene = SceneManager.scene
    return unless scene.is_a?(Scene_Map)

    room = UI::Layout.docked_room(:top_left)
    offset = room > 0 ? room + BELOW : 0
    TOP_LEFT_WINDOWS.each do |field|
      window = MGQ_MpGame.get(scene, field)
      next unless window && !window.disposed?

      top = (@tops[window] ||= window.y)
      window.y = top + offset
    end
  rescue => e
    log_once(:windows, "moving the map's top left windows failed: #{e.class}: #{e.message}")
  end

  # Forgets where the game put the map scene's top left windows, once its map scene ends.
  def self.forget_windows
    @tops.clear
  end

  # Reports whether the game's top message shows, which the HUD would lie under.
  #
  # @return [Boolean] Whether it does.
  def self.top_message?
    $game_message && $game_message.visible && $game_message.position == 0 ? true : false
  end

  # Measures how far a character is from one of their levels to the next.
  #
  # @param actor [Game_Actor] The character.
  # @param kind [Symbol] :base, :class for the job or :tribe for the race.
  # @return [Float] The share done, 0.0 to 1.0, full at the highest level.
  def self.exp_rate(actor, kind)
    return 1.0 if actor.max_level?(kind)

    exp = { :base => actor.base_exp, :class => actor.class_exp, :tribe => actor.tribe_exp }[kind].to_i
    low = actor.current_level_exp(kind).to_i
    high = actor.next_level_exp(kind).to_i
    high > low ? UI.within((exp - low).to_f / (high - low), 0.0, 1.0) : 1.0
  rescue => e
    log_once([:exp, kind], "reading the #{kind} level's progress failed: #{e.class}: #{e.message}")
    0.0
  end

  # Offers turning the HUD on and off and its size as rows of the Mod Config, kept in Player.ini.
  def self.add_options
    prefix = MGQ_Multiplayer::OPTION_PREFIX
    shown = Mod_Framework::Options.keep(SHOWN_OPTION, prefix + SHOWN_OPTION_NAME, SHOWN_OPTION_HELP, lambda { [ON, OFF] },
                                        lambda { shown? ? ON : OFF }, lambda { |value| show(value == ON) })
    Mod_Framework::Options.keep(SIZE_OPTION, prefix + SIZE_OPTION_NAME, SIZE_OPTION_HELP, lambda { SIZES }, lambda { size }, lambda { |value| resize(value) })
    log(shown ? "added the Leader HUD to Options > Mods" : "no Leader HUD in Options > Mods, see the Mod Framework's log")
  end

  # How a character looks in the HUD's square, what its Picture draws the face or the figure from: a
  # new one each time they change, so the picture draws anew.
  Looks = Struct.new(:face_name, :face_index, :character_name, :character_index)

  # The HUD's box on the map: a root of the Mod Framework docked at the top left, under the game's
  # windows, which fades out while the HUD does not show (see MGQ_MpLeaderHud.shows?). Its parts are
  # set only when what they show changed; another size builds them anew in the same box.
  class View
    # The box's id, which names its place in the Mod Framework's settings.
    ID = :leader_hud

    # The box's name while the player arranges the boxes.
    PLACE_NAME = "Leader HUD"

    # Its place among the boxes docked at the top left, before the notices.
    DOCK_ORDER = 10

    # Sizes of the parts of a box: its width, the room inside its frame, the font sizes of the name
    # and of the texts in the bars (nil for bars without texts), the heights of the name's line, the
    # HP and MP bars and the level bars, the gaps between the bars and between the level bars, and
    # whether its picture is the map sprite rather than the face.
    Layout = Struct.new(:width, :pad, :name_size, :number_size, :name_height, :bar_height, :bar_gap, :exp_height, :exp_gap, :sprite)

    # The sizes' layouts, by MGQ_MpLeaderHud::SIZES.
    LAYOUTS = {
      MGQ_MpLeaderHud::LARGE => Layout.new(240, 6, :normal, :tiny, 20, 16, 2, 4, 2, false),
      MGQ_MpLeaderHud::SMALL => Layout.new(170, 5, :small, nil, 18, 6, 2, 3, 1, true),
    }

    # Colors of the HP bar, from its left end to its right end.
    HP_COLORS = [Color.new(150, 20, 20), Color.new(230, 60, 50)]

    # Colors of the MP bar, from its left end to its right end.
    MP_COLORS = [Color.new(30, 80, 170), Color.new(70, 150, 240)]

    # Colors of each level bar, from its left end to its right end, by EXP_KINDS.
    EXP_COLORS = {
      :base => [Color.new(200, 150, 40), Color.new(255, 220, 110)],
      :class => [Color.new(40, 150, 70), Color.new(110, 220, 120)],
      :tribe => [Color.new(130, 70, 190), Color.new(200, 140, 255)],
    }

    # The levels whose progress the bars at the bottom show, in their order from the top.
    EXP_KINDS = [:base, :class, :tribe]

    # How the base level after the name reads.
    LEVEL_TEXT = "Lv %d"

    # How the numbers in the HP and MP bars read.
    POINTS_TEXT = "%d / %d"

    # @return [Mod_Framework::UI::Box] The HUD's box.
    attr_reader :root

    # Makes the box and opens it, empty until the first update fills it.
    def initialize
      @root = UI::Box.new(:id => ID, :place_name => PLACE_NAME, :under_windows => true, :z => UI::Z[:labels], :dock => :top_left, :dock_order => DOCK_ORDER,
                          :movable => true, :resizable => false, :mouse => :parts, :fade => true, :hide_while => lambda { !MGQ_MpLeaderHud.shows? })
      @size = nil
      @shown = nil
      @root.open
    end

    # Finds the layout of a size.
    #
    # @param size [String] The size, see MGQ_MpLeaderHud::SIZES.
    # @return [Layout] Its layout.
    def self.layout(size)
      LAYOUTS[size] || LAYOUTS[MGQ_MpLeaderHud::SIZES.first]
    end

    # Finds the side of a layout's picture, as high as the name and both bars beside it.
    #
    # @param layout [Layout] The layout.
    # @return [Integer] The side in pixels.
    def self.face_side(layout)
      layout.name_height + 2 * (layout.bar_gap + layout.bar_height)
    end

    # Builds the box anew once the size changed and sets what changed of the Formation Leader.
    # Called by the map every frame.
    def update
      leader = MGQ_MpLeaderHud.leader
      return unless leader

      size = MGQ_MpLeaderHud.size
      build(View.layout(size)) unless size == @size
      @size = size
      refresh(leader)
    end

    # Closes the box, with the map's sprites.
    def close
      @root.close
    end

    private

    # Builds the box's parts for a layout: the picture in a framed square at the left, the name and
    # level over the HP and MP bars beside it, and the level bars across the bottom.
    #
    # @param layout [Layout] The size's layout.
    def build(layout)
      @root.clear
      @root.width = layout.width
      @root.padding = layout.pad
      @root.gap = layout.bar_gap
      @layout = layout
      @shown = nil
      side = View.face_side(layout)
      top = @root.add_row(:gap => layout.pad)
      square = top.add_box(:frame => true, :padding => 0, :size => [side, side])
      fit = layout.sprite ? { :fit => :whole, :anchor => :bottom } : {}
      @picture = square.add_picture(fit.merge(:grow => 1))
      column = top.add_column(:grow => 1, :gap => layout.bar_gap)
      line = column.add_row(:height => layout.name_height)
      @name = line.add_label("", :grow => 1, :shrink => true, :font_size => layout.name_size)
      @level = line.add_label("", :color => :heading, :font_size => layout.name_size)
      @hp = column.add_gauge(points_options(layout, HP_COLORS))
      @mp = column.add_gauge(points_options(layout, MP_COLORS))
      levels = @root.add_column(:gap => layout.exp_gap)
      @levels = EXP_KINDS.map { |kind| levels.add_gauge(:colors => EXP_COLORS[kind], :height => layout.exp_height) }
    end

    # Tells the options of the HP or MP bar of a layout.
    #
    # @param layout [Layout] The size's layout.
    # @param colors [Array(Color, Color)] The fill's colors at its left and right ends.
    # @return [Hash] The options.
    def points_options(layout, colors)
      options = { :colors => colors, :height => layout.bar_height }
      layout.number_size ? options.merge(:font_size => layout.number_size) : options
    end

    # Sets what the Formation Leader shows once any of it changed.
    #
    # @param actor [Game_Actor] The Formation Leader.
    def refresh(actor)
      content = [actor.id, actor.name, actor.face_name, actor.face_index, actor.character_name, actor.character_index, actor.base_level,
                 actor.hp, actor.mhp, actor.mp, actor.mmp, actor.class_id, actor.tribe_id, actor.base_exp, actor.class_exp, actor.tribe_exp]
      return if content == @shown

      @shown = content
      looks = Looks.new(actor.face_name.to_s, actor.face_index.to_i, actor.character_name.to_s, actor.character_index.to_i)
      if @layout.sprite
        @picture.figure = looks
      else
        @picture.face = looks
      end
      @name.text = actor.name.to_s
      @level.text = format(LEVEL_TEXT, actor.base_level.to_i)
      set_points(@hp, actor.hp_rate, Vocab.hp_a, actor.hp, actor.mhp)
      set_points(@mp, actor.mp_rate, Vocab.mp_a, actor.mp, actor.mmp)
      EXP_KINDS.each_with_index { |kind, index| @levels[index].rate = MGQ_MpLeaderHud.exp_rate(actor, kind) }
    end

    # Sets the HP or the MP bar: its share, and in a layout with texts its name at its left and its
    # numbers at its right.
    #
    # @param gauge [Mod_Framework::UI::Gauge] The bar.
    # @param rate [Float] The share filled.
    # @param name [String] The bar's name, such as HP.
    # @param value [Integer] Its value.
    # @param max [Integer] Its max.
    def set_points(gauge, rate, name, value, max)
      gauge.rate = UI.within(rate.to_f, 0.0, 1.0)
      return unless @layout.number_size

      gauge.label = name.to_s
      gauge.value = format(POINTS_TEXT, value.to_i, max.to_i)
    end
  end
end

# The Mod Config rows.

begin
  MGQ_MpLeaderHud.add_options
rescue => e
  MGQ_MpLeaderHud.log("start FAILED: #{e.class}: #{e.message}")
end

# Game hooks, through core_hooks.rbx.

begin
  # After the map's update, the size hotkey. The game checks its own keys there too, only while no
  # scene change is in the way.
  MGQ_MpHooks.after(Scene_Map, :update_scene, "ui_leader_hud") { MGQ_MpLeaderHud.on_map unless scene_changing? }

  # After the map's sprites, the HUD and the windows it moves below itself, never on the map behind
  # a menu.
  MGQ_MpHooks.after(Spriteset_Map, :update, "ui_leader_hud") do
    next unless mgq_mp_hud?

    begin
      (@mgq_mp_leader_hud ||= MGQ_MpLeaderHud::View.new).update
    rescue => e
      MGQ_MpLeaderHud.log_once(:draw, "showing the Leader HUD failed: #{e.class}: #{e.message}")
    end
    MGQ_MpLeaderHud.lower_windows
  end

  MGQ_MpHooks.before(Spriteset_Map, :dispose, "ui_leader_hud") do
    @mgq_mp_leader_hud.close if @mgq_mp_leader_hud
    @mgq_mp_leader_hud = nil
    MGQ_MpLeaderHud.forget_windows
  end
rescue => e
  MGQ_MpLeaderHud.log("hooks FAILED: #{e.class}: #{e.message}")
end
