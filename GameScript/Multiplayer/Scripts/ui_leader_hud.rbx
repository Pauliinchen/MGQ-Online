#----------------------------------------------------------------
#  ui_leader_hud.rbx
#
#  Changelog:
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
# another, see core_hotkeys.rbx), kept in Player.ini, so it shows in single player too.
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

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "leader hud"

  # The map scene's windows that open at the top left, by their field in MGQ_MpGame: the map's
  # name and the medal just won.
  TOP_LEFT_WINDOWS = [:map_name_window, :gain_medal_window]

  # The pixels the HUD takes at its default place, see room.
  @room = 0

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
    return "the action wheel is open" if MGQ_MpActions::Wheel.open?
    return "the emote wheel is open" if MGQ_MpEmotes.open?

    nil
  end

  # Tells the pixels below the top of the screen the HUD takes at its default place, which the
  # notification box at the top left moves down by.
  #
  # @return [Integer] The pixels, 0 while the HUD is hidden or the player moved it.
  def self.room
    @room
  end

  # Sets the pixels the HUD takes at its default place, see room.
  #
  # @param pixels [Integer] The pixels.
  def self.room=(pixels)
    @room = pixels.to_i
  end

  # Moves the map scene's windows that open at the top left below the HUD while it takes room there,
  # and back to where the game put them once it does not.
  def self.lower_windows
    scene = SceneManager.scene
    return unless scene.is_a?(Scene_Map)

    offset = @room > 0 ? MGQ_MpUi.top_room + @room : 0
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
    high > low ? MGQ_MpUi.within((exp - low).to_f / (high - low), 0.0, 1.0) : 1.0
  rescue => e
    log_once([:exp, kind], "reading the #{kind} level's progress failed: #{e.class}: #{e.message}")
    0.0
  end

  # Offers turning the HUD on and off and its size as rows of the Mod Config, kept in Player.ini.
  def self.add_options
    shown = MGQ_MpUi.add_option(SHOWN_OPTION, SHOWN_OPTION_NAME, SHOWN_OPTION_HELP, lambda { [ON, OFF] },
                                lambda { shown? ? ON : OFF }, lambda { |value| show(value == ON) })
    MGQ_MpUi.add_option(SIZE_OPTION, SIZE_OPTION_NAME, SIZE_OPTION_HELP, lambda { SIZES }, lambda { size }, lambda { |value| resize(value) })
    log(shown ? "added the Leader HUD to the Mod Config" : "no Leader HUD in the Mod Config: it needs a Mod Config Remake that knows rows the mod keeps")
  end
end

# The box of the Leader HUD on the map, in the map's topmost viewport, which darkens with the
# screen; drawn in the interface preset's colors, anew once the preset changes, and fading in and
# out.
class Sprite_MpLeaderHud < Sprite
  # The box's id in the layout, which names its setting in Player.ini.
  LAYOUT = :leader_hud

  # The box's name while the player arranges the boxes.
  LAYOUT_NAME = "Leader HUD"

  # Room between the box and the top and left edges of the screen at its default, below a strip of
  # the mod at the top (see MGQ_MpUi.top_room).
  MARGIN = 8

  # Room between the box and a box below it at the top left, such as the notification box.
  BELOW = 4

  # Sizes of the parts of a box: its width, the room inside its frame, the font sizes of the name
  # and of the numbers in the bars (0 for bars without numbers), the heights of the name's line, the
  # HP and MP bars and the level bars, the gaps between the bars, and whether its picture is the map
  # sprite rather than the face.
  Layout = Struct.new(:width, :pad, :name_size, :number_size, :name_height, :bar_height, :bar_gap, :exp_height, :exp_gap, :sprite)

  # The sizes' layouts, by MGQ_MpLeaderHud::SIZES.
  LAYOUTS = {
    MGQ_MpLeaderHud::LARGE => Layout.new(240, 6, MGQ_MpUi::Style::TEXT_SIZE, MGQ_MpUi::Style::TINY_SIZE, 20, 16, 2, 4, 2, false),
    MGQ_MpLeaderHud::SMALL => Layout.new(170, 5, MGQ_MpUi::Style::SMALL_SIZE, 0, 18, 6, 2, 3, 1, true),
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

  # What the base level after the name starts with.
  LEVEL_PREFIX = "Lv "

  # Side of a face in the game's face sheets.
  FACE_SIDE = 96

  # Faces in a row of a face sheet.
  FACES_PER_ROW = 4

  # Characters in a row of a sprite sheet of eight.
  CHARACTERS_PER_ROW = 4

  # Frames of a character's walk, across.
  WALK_FRAMES = 3

  # Directions a character faces, down.
  DIRECTIONS = 4

  # The frame of the walk the character stands in.
  STANDING_FRAME = 1

  # Room the numbers in a bar keep from its ends.
  NUMBERS_MARGIN = 4

  # Creates the box, hidden.
  #
  # @param viewport [Viewport] The map's topmost viewport.
  def initialize(viewport)
    super(viewport)
    self.z = MGQ_MpUi::Z[:labels]
    @drawn = nil
    @motion = MGQ_MpUi::Motion.new(self)
  end

  # Finds the layout of a size.
  #
  # @param size [String] The size, see MGQ_MpLeaderHud::SIZES.
  # @return [Layout] Its layout.
  def self.layout(size)
    LAYOUTS[size] || LAYOUTS[MGQ_MpLeaderHud::SIZES.first]
  end

  # Makes the box movable through MGQ_MpUi::Layout, at least as large as the Small size, so each
  # size keeps its own place at the edges of the screen.
  #
  # The Small size's height follows the preset's frame, so the box registers anew once the preset
  # changes.
  def self.register_layout
    return if @registered == MGQ_MpUi::Theme.serial

    small = layout(MGQ_MpLeaderHud::SMALL)
    MGQ_MpUi::Layout.register(LAYOUT, LAYOUT_NAME, small.width, height(small), :none)
    @registered = MGQ_MpUi::Theme.serial
  end

  # Finds the side of a layout's picture, as high as the name and both bars beside it.
  #
  # @param layout [Layout] The layout.
  # @return [Integer] The side in pixels.
  def self.face_side(layout)
    layout.name_height + 2 * (layout.bar_gap + layout.bar_height)
  end

  # Finds the height of a layout's box: the picture, the level bars below it, the room inside the
  # frame and the frame.
  #
  # @param layout [Layout] The layout.
  # @return [Integer] The height in pixels.
  def self.height(layout)
    exp = EXP_KINDS.size * layout.exp_height + (EXP_KINDS.size - 1) * layout.exp_gap
    2 * (MGQ_MpUi::Style.frame_width + layout.pad) + face_side(layout) + layout.bar_gap + exp
  end

  # Shows the Formation Leader while the player wants the HUD and the game's top message does not
  # show, drawing the box anew once what it shows changed, and moves the fade a frame on, the box
  # where the layout puts it.
  def update
    super
    layout = Sprite_MpLeaderHud.layout(MGQ_MpLeaderHud.size)
    rect = layout_rect(layout)
    leader = $game_party && $game_party.leader
    if leader && MGQ_MpLeaderHud.on? && !MGQ_MpLeaderHud.top_message?
      refresh(leader, layout)
      @motion.show
    else
      @motion.hide
    end
    @motion.place(rect.x, rect.y)
    @motion.update
    MGQ_MpUi::Layout.offer(LAYOUT, rect.x, rect.y, rect.width, rect.height, z) if @motion.shown?
    MGQ_MpLeaderHud.room = @motion.shown? && !MGQ_MpUi::Layout.moved?(LAYOUT) ? rect.y + rect.height + BELOW - MGQ_MpUi.top_room : 0
  rescue => e
    MGQ_MpLeaderHud.room = 0
    MGQ_MpLeaderHud.log_once(:draw, "drawing the Leader HUD failed: #{e.class}: #{e.message}")
  end

  # Tells where the box draws: where the player left it, else at the top left below a strip of the
  # mod, as large as its size.
  #
  # @param layout [Layout] The size's layout.
  # @return [Rect] The place, see MGQ_MpUi::Layout.rect.
  def layout_rect(layout)
    Sprite_MpLeaderHud.register_layout
    default = Rect.new(MARGIN, MARGIN + MGQ_MpUi.top_room, layout.width, Sprite_MpLeaderHud.height(layout))
    rect = MGQ_MpUi::Layout.rect(LAYOUT, default)
    Rect.new(rect.x, rect.y, default.width, default.height)
  end

  # Draws the box anew once anything it shows changed.
  #
  # @param actor [Game_Actor] The Formation Leader.
  # @param layout [Layout] The size's layout.
  def refresh(actor, layout)
    content = [layout, MGQ_MpUi::Theme.serial, actor.id, actor.name, actor.face_name, actor.face_index, actor.character_name, actor.character_index, actor.base_level,
               actor.hp, actor.mhp, actor.mp, actor.mmp, actor.class_id, actor.tribe_id, actor.base_exp, actor.class_exp, actor.tribe_exp]
    return if content == @drawn

    @drawn = content
    fit_bitmap(layout)
    draw(actor, layout)
  end

  # Gives the box a picture of the layout's size, making it anew once the size changed.
  #
  # @param layout [Layout] The size's layout.
  def fit_bitmap(layout)
    height = Sprite_MpLeaderHud.height(layout)
    return if bitmap && !bitmap.disposed? && bitmap.width == layout.width && bitmap.height == height

    bitmap.dispose if bitmap && !bitmap.disposed?
    self.bitmap = Bitmap.new(layout.width, height)
  end

  # Draws the framed box with the picture at its left, the name and level over the HP and MP bars
  # beside it, and the level bars across the bottom.
  #
  # @param actor [Game_Actor] The Formation Leader.
  # @param layout [Layout] The size's layout.
  def draw(actor, layout)
    bitmap.clear
    MGQ_MpUi::Style.draw_box(bitmap, 0, 0, bitmap.width, bitmap.height)
    inset = MGQ_MpUi::Style.frame_width + layout.pad
    side = Sprite_MpLeaderHud.face_side(layout)
    layout.sprite ? draw_figure(actor, inset, inset, side) : draw_face(actor, inset, inset, side)
    column = inset + side + layout.pad
    width = bitmap.width - inset - column
    draw_name(actor, layout, column, inset, width)
    y = inset + layout.name_height + layout.bar_gap
    draw_points(layout, column, y, width, actor.hp_rate, HP_COLORS, Vocab.hp_a, actor.hp, actor.mhp)
    y += layout.bar_height + layout.bar_gap
    draw_points(layout, column, y, width, actor.mp_rate, MP_COLORS, Vocab.mp_a, actor.mp, actor.mmp)
    draw_levels(actor, layout, inset, inset + side + layout.bar_gap, bitmap.width - 2 * inset)
  end

  # Draws a character's face shrunk into a square, framed by the preset's edge.
  #
  # @param actor [Game_Actor] The character.
  # @param x [Integer] The square's left.
  # @param y [Integer] The square's top.
  # @param side [Integer] The square's side.
  def draw_face(actor, x, y, side)
    Sprite_MpLeaderHud.draw_face(bitmap, actor.face_name.to_s, actor.face_index.to_i, x, y, side)
  end

  # Draws a face shrunk into a square, framed by the preset's edge.
  #
  # @param bitmap [Bitmap] Where it draws.
  # @param name [String] The face sheet's file name; empty for none.
  # @param index [Integer] The face's place in the sheet.
  # @param x [Integer] The square's left.
  # @param y [Integer] The square's top.
  # @param side [Integer] The square's side.
  # @param fill [Color] The square's background.
  def self.draw_face(bitmap, name, index, x, y, side, fill = MGQ_MpUi::Style::FIELD)
    bitmap.fill_rect(x, y, side, side, fill)
    unless name.empty?
      source = Rect.new(index % FACES_PER_ROW * FACE_SIDE, index / FACES_PER_ROW * FACE_SIDE, FACE_SIDE, FACE_SIDE)
      bitmap.stretch_blt(Rect.new(x, y, side, side), Cache.face(name), source)
    end
    MGQ_MpUi::Style.draw_line_box(bitmap, x, y, side, side, MGQ_MpUi::Style::EDGE)
  end

  # Draws a character's map sprite, standing and facing down, in a square framed by the preset's
  # edge (see Sprite_MpLeaderHud.draw_figure).
  #
  # @param actor [Game_Actor] The character.
  # @param x [Integer] The square's left.
  # @param y [Integer] The square's top.
  # @param side [Integer] The square's side.
  def draw_figure(actor, x, y, side)
    Sprite_MpLeaderHud.draw_figure(bitmap, actor.character_name.to_s, actor.character_index.to_i, x, y, side)
  end

  # Draws a map sprite, standing and facing down, in a square framed by the preset's edge: the
  # figure the frame draws, past the frame's empty room, grown by the largest whole multiple that
  # fits so its pixels stay sharp, or shrunk when larger than the square, centered and standing on
  # the square's bottom.
  #
  # @param bitmap [Bitmap] Where it draws.
  # @param name [String] The sprite sheet's file name; empty for none.
  # @param index [Integer] The character's place in the sheet.
  # @param x [Integer] The square's left.
  # @param y [Integer] The square's top.
  # @param side [Integer] The square's side.
  # @param fill [Color] The square's background.
  def self.draw_figure(bitmap, name, index, x, y, side, fill = MGQ_MpUi::Style::FIELD)
    bitmap.fill_rect(x, y, side, side, fill)
    unless name.empty?
      sheet = Cache.character(name)
      figure = figure(sheet, frame_rect(sheet, name, index), [name, index])
      scale = [side.to_f / figure.width, side.to_f / figure.height].min
      scale = scale.floor if scale >= 1
      width = (figure.width * scale).round
      height = (figure.height * scale).round
      bitmap.stretch_blt(Rect.new(x + (side - width) / 2, y + side - height, width, height), sheet, figure)
    end
    MGQ_MpUi::Style.draw_line_box(bitmap, x, y, side, side, MGQ_MpUi::Style::EDGE)
  end

  # Finds a character's standing frame facing down in their sprite sheet.
  #
  # @param sheet [Bitmap] The sprite sheet.
  # @param name [String] Its file name, whose $ marks a sheet of one character.
  # @param index [Integer] The character's place in a sheet of eight.
  # @return [Rect] The frame.
  def self.frame_rect(sheet, name, index)
    single = name[/\A[!$]./].to_s.include?("$")
    width = sheet.width / (single ? WALK_FRAMES : WALK_FRAMES * CHARACTERS_PER_ROW)
    height = sheet.height / (single ? DIRECTIONS : DIRECTIONS * 2)
    index = 0 if single
    left = (index % CHARACTERS_PER_ROW * WALK_FRAMES + STANDING_FRAME) * width
    top = index / CHARACTERS_PER_ROW * DIRECTIONS * height
    Rect.new(left, top, width, height)
  end

  # Finds where a frame draws its figure: the smallest rectangle holding every pixel that is not
  # see-through, the whole frame for an empty one. Kept per character, since reading the pixels
  # takes a while.
  #
  # @param sheet [Bitmap] The sprite sheet.
  # @param frame [Rect] The frame.
  # @param key [Array] What the figure is kept by, the sheet's name and the character's place.
  # @return [Rect] The figure.
  def self.figure(sheet, frame, key)
    @figures ||= {}
    @figures[key] ||= begin
      xs = []
      ys = []
      frame.height.times do |dy|
        frame.width.times do |dx|
          next if sheet.get_pixel(frame.x + dx, frame.y + dy).alpha.to_i == 0

          xs << frame.x + dx
          ys << frame.y + dy
        end
      end
      xs.empty? ? frame : Rect.new(xs.min, ys.min, xs.max - xs.min + 1, ys.max - ys.min + 1)
    end
  end

  # Draws a character's name, cut to its room, with their base level at the right.
  #
  # @param actor [Game_Actor] The character.
  # @param layout [Layout] The size's layout.
  # @param x [Integer] The line's left.
  # @param y [Integer] The line's top.
  # @param width [Integer] The line's width.
  def draw_name(actor, layout, x, y, width)
    style = MGQ_MpUi::Style
    level = "#{LEVEL_PREFIX}#{actor.base_level}"
    style.use_font(bitmap, layout.name_size, style::HEADING)
    level_width = bitmap.text_size(level).width
    bitmap.draw_text(x, y, width, layout.name_height, level, 2)
    room = width - level_width - style::GAP
    style.use_font(bitmap, layout.name_size, style::TEXT)
    bitmap.draw_text(x, y, room, layout.name_height, MGQ_MpUi.cut(bitmap, actor.name.to_s, room))
  end

  # Draws the HP or the MP bar, with its name at its left and its numbers at its right inside it in
  # a layout with numbers.
  #
  # @param layout [Layout] The size's layout.
  # @param x [Integer] The bar's left.
  # @param y [Integer] The bar's top.
  # @param width [Integer] The bar's width.
  # @param rate [Float] The share filled.
  # @param colors [Array(Color, Color)] The fill's colors at its left and right ends.
  # @param label [String] The bar's name, such as HP.
  # @param value [Integer] Its value.
  # @param max [Integer] Its max.
  def draw_points(layout, x, y, width, rate, colors, label, value, max)
    draw_bar(x, y, width, layout.bar_height, rate, colors)
    return unless layout.number_size > 0

    style = MGQ_MpUi::Style
    style.use_font(bitmap, layout.number_size, style::TEXT)
    inner = width - 2 * NUMBERS_MARGIN
    bitmap.draw_text(x + NUMBERS_MARGIN, y, inner, layout.bar_height, label.to_s)
    bitmap.draw_text(x + NUMBERS_MARGIN, y, inner, layout.bar_height, "#{value.to_i} / #{max.to_i}", 2)
  end

  # Draws the bars of the base, job and race levels' progress, one under the other.
  #
  # @param actor [Game_Actor] The character.
  # @param layout [Layout] The size's layout.
  # @param x [Integer] The bars' left.
  # @param y [Integer] The first bar's top.
  # @param width [Integer] The bars' width.
  def draw_levels(actor, layout, x, y, width)
    EXP_KINDS.each_with_index do |kind, index|
      top = y + (layout.exp_height + layout.exp_gap) * index
      draw_bar(x, top, width, layout.exp_height, MGQ_MpLeaderHud.exp_rate(actor, kind), EXP_COLORS[kind])
    end
  end

  # Draws a bar: the preset's field, darker than its box, filled from the left by a share in a
  # gradient.
  #
  # @param x [Integer] The bar's left.
  # @param y [Integer] The bar's top.
  # @param width [Integer] The bar's width.
  # @param height [Integer] The bar's height.
  # @param rate [Float] The share filled, 0.0 to 1.0.
  # @param colors [Array(Color, Color)] The fill's colors at its left and right ends.
  def draw_bar(x, y, width, height, rate, colors)
    bitmap.fill_rect(x, y, width, height, MGQ_MpUi::Style::FIELD)
    filled = (width * MGQ_MpUi.within(rate.to_f, 0.0, 1.0)).round
    bitmap.gradient_fill_rect(x, y, filled, height, colors[0], colors[1]) if filled > 0
  end

  # Frees the box's picture.
  def dispose
    bitmap.dispose if bitmap && !bitmap.disposed?
    super
  end
end

# Where the box lies, which the player changes with the left Alt held, through ui_layout.rbx, and
# the Mod Config rows.

begin
  Sprite_MpLeaderHud.register_layout
  MGQ_MpLeaderHud.add_options
rescue => e
  MGQ_MpLeaderHud.log("start FAILED: #{e.class}: #{e.message}")
end

# Game hooks, through core_hooks.rbx.

begin
  # After the map's update, the size hotkey. The game checks its own keys there too, only while no
  # scene change is in the way.
  MGQ_MpHooks.after(Scene_Map, :update_scene, "ui_leader_hud") { MGQ_MpLeaderHud.on_map unless scene_changing? }

  # After the map's sprites, the HUD and the windows it moves below itself.
  MGQ_MpHooks.after(Spriteset_Map, :update, "ui_leader_hud") do
    next unless mgq_mp_hud?

    (@mgq_mp_leader_hud ||= Sprite_MpLeaderHud.new(MGQ_MpGame.get(self, :viewport3))).update
    MGQ_MpLeaderHud.lower_windows
  end

  MGQ_MpHooks.before(Spriteset_Map, :dispose, "ui_leader_hud") do
    @mgq_mp_leader_hud.dispose if @mgq_mp_leader_hud
    @mgq_mp_leader_hud = nil
    MGQ_MpLeaderHud.room = 0
    MGQ_MpLeaderHud.forget_windows
  end
rescue => e
  MGQ_MpLeaderHud.log("hooks FAILED: #{e.class}: #{e.message}")
end
