#----------------------------------------------------------------
#  ui_leader_hud.rbx
#
#  Changelog:
#      Paulinchen  2026-11-06: Drew the HUD as a hud of the Mod Framework's UI layer
#      Paulinchen  2026-11-05: Kept and read its switches in Player.ini as true or false, which the DLL writes as 1 or 0
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
# another, see core_hotkeys.rbx), kept in Player.ini, so it shows in single player too. It is a hud
# of the Mod Framework's UI layer at the top left, under the game's windows (see LeaderHud).
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
    @shown = MGQ_Multiplayer::Player.setting(SHOWN_SETTING) != false if @shown.nil?
    @shown
  end

  # Reports whether the player wants the HUD outside a world, as Player.ini keeps it: as inside a
  # world until they set it, so a HUD turned off before the setting existed stays off.
  #
  # @return [Boolean] Whether it shows.
  def self.sp_shown?
    if @sp_shown.nil?
      kept = MGQ_Multiplayer::Player.setting(SP_SHOWN_SETTING)
      kept = MGQ_Multiplayer::Player.setting(SHOWN_SETTING) if kept.nil?
      @sp_shown = kept != false
    end
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
    MGQ_Multiplayer::Player.store(SHOWN_SETTING, @shown)
    log("the Leader HUD is #{@shown ? 'on' : 'off'}")
  rescue => e
    log("keeping whether the Leader HUD shows FAILED: #{e.class}: #{e.message}")
  end

  # Turns the HUD on or off outside a world and keeps the choice in Player.ini.
  #
  # @param shown [Boolean] Whether it shows.
  def self.show_sp(shown)
    @sp_shown = shown ? true : false
    MGQ_Multiplayer::Player.store(SP_SHOWN_SETTING, @sp_shown)
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

    room = UI::Layout.room(:top_left)
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
    high > low ? [[(exp - low).to_f / (high - low), 0.0].max, 1.0].min : 1.0
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

  # Tells what renders the HUD anew: the leader, their face and figure, and the size.
  #
  # @return [Array] The leader's id and look, and the size, the same object while they stay.
  def self.look
    actor = leader
    looks = actor ? [actor.id, actor.face_name, actor.face_index, actor.character_name, actor.character_index] : nil
    @look = [looks, size] unless @look && @look[0] == looks && @look[1] == size
    @look
  end

  # Tells how full the leader's HP or MP bar is.
  #
  # @param kind [Symbol] :hp or :mp.
  # @return [Float] The share, 0.0 to 1.0, 0.0 without a leader.
  def self.rate(kind)
    actor = leader
    return 0.0 unless actor

    [[(kind == :hp ? actor.hp_rate : actor.mp_rate).to_f, 0.0].max, 1.0].min
  end

  # Names the HP or the MP bar as the game does.
  #
  # @param kind [Symbol] :hp or :mp.
  # @return [String] Such as "HP".
  def self.bar_name(kind)
    (kind == :hp ? Vocab.hp_a : Vocab.mp_a).to_s
  end

  # Writes the leader's HP or MP and its max, as the Large bars show them.
  #
  # @param kind [Symbol] :hp or :mp.
  # @return [String] Such as "189 / 252", "" without a leader.
  def self.numbers(kind)
    actor = leader
    return "" unless actor

    kind == :hp ? format(POINTS_TEXT, actor.hp.to_i, actor.mhp.to_i) : format(POINTS_TEXT, actor.mp.to_i, actor.mmp.to_i)
  end

  # How the numbers in the HP and MP bars read.
  POINTS_TEXT = "%d / %d"

  # The HUD on the map: a hud of the Mod Framework's UI layer at the top left, under the game's
  # windows, which fades out while the HUD does not show (see MGQ_MpLeaderHud.shows?). Its bars
  # read the Formation Leader every frame; another leader, look or size renders it anew.
  class LeaderHud < UI::Component
    # The HUD's place id, which names its place in the Mod Framework's settings.
    ID = :leader_hud

    # The HUD's name while the player arranges the boxes.
    PLACE_NAME = "Leader HUD"

    # Its place among the parts at the top left, before the notices.
    ORDER = 10

    # Its width by size.
    WIDTHS = { LARGE => 240, SMALL => 170 }

    # The side of the picture's square by size: as high as the name and both bars beside it.
    PICTURE_SIDES = { LARGE => 56, SMALL => 34 }

    # The colors of the HP and the MP bar, from their left end to their right end.
    BAR_COLORS = { :hp => [:mgq_online_hp_left, :mgq_online_hp_right], :mp => [:mgq_online_mp_left, :mgq_online_mp_right] }

    # The levels whose bars show across the bottom, in their order, each with its colors from its
    # left end to its right end.
    LEVEL_COLORS = [[:base, [:mgq_online_base_left, :mgq_online_base_right]], [:class, [:mgq_online_job_left, :mgq_online_job_right]],
                    [:tribe, [:mgq_online_race_left, :mgq_online_race_right]]]

    # The steps of a bar's value, so a bar of any max fills smoothly.
    STEPS = 1000

    # How the base level after the name reads.
    LEVEL_TEXT = "Lv %d"

    # Renders it anew for another leader, another look of them or another size.
    watch(:every => 10) { MGQ_MpLeaderHud.look }

    # Describes the HUD: the picture in a framed square at the left, the name and level over the HP
    # and MP bars beside it, and the levels' bars across the bottom.
    def render
      size = MGQ_MpLeaderHud.size
      large = size == LARGE
      side = PICTURE_SIDES[size]
      hud id: ID, place_name: PLACE_NAME, anchor: :top_left, order: ORDER, shown_in: [Scene_Map], width: WIDTHS[size],
          hide_while: -> { !MGQ_MpLeaderHud.shows? } do
        stack row: true, spacing: 1.5 do
          paper(width: side, height: side) { picture(large) }
          stack grow: 1, spacing: 0.5 do
            stack row: true do
              text -> { leader_name }, typo: (large ? :subtitle2 : :caption), grow: 1
              text -> { format(LEVEL_TEXT, leader_level) }, typo: :caption, color: :heading
            end
            bar(:hp, large)
            bar(:mp, large)
          end
        end
        stack spacing: (large ? 0.5 : 0) do
          LEVEL_COLORS.each do |kind, colors|
            progress value: -> { (MGQ_MpLeaderHud.exp_rate(MGQ_MpLeaderHud.leader, kind) * STEPS).round }, max: STEPS, colors: colors,
                     size: :small, key: kind
          end
        end
      end
    end

    private

    # Describes the leader's face for the Large size, their whole map figure for the Small one.
    #
    # @param large [Boolean] Whether the HUD is Large.
    def picture(large)
      leader = MGQ_MpLeaderHud.leader
      return unless leader

      large ? image(face: leader, fit: :cover, height: :fill) : image(figure: leader, fit: :contain, anchor: :bottom, height: :fill)
    end

    # Describes the HP or the MP bar: while Large with its name at its left and its numbers inside.
    #
    # @param kind [Symbol] :hp or :mp.
    # @param large [Boolean] Whether the HUD is Large.
    def bar(kind, large)
      params = { value: -> { (MGQ_MpLeaderHud.rate(kind) * STEPS).round }, max: STEPS, colors: BAR_COLORS[kind], key: kind,
                 size: (large ? :small : :medium) }
      params.update(label: MGQ_MpLeaderHud.bar_name(kind), value_text: -> { MGQ_MpLeaderHud.numbers(kind) }) if large
      progress params
    end

    # Tells the leader's name.
    #
    # @return [String] The name, "" without a leader.
    def leader_name
      leader = MGQ_MpLeaderHud.leader
      leader ? leader.name.to_s : ""
    end

    # Tells the leader's base level.
    #
    # @return [Integer] The level, 0 without a leader.
    def leader_level
      leader = MGQ_MpLeaderHud.leader
      leader ? leader.base_level.to_i : 0
    end
  end

  # Shows the HUD as the map is first seen, and again once F12 took it away.
  def self.keep_shown
    MGQ_MpShown.keep(LeaderHud::ID, LeaderHud)
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

    MGQ_MpLeaderHud.keep_shown
    MGQ_MpLeaderHud.lower_windows
  end

  MGQ_MpHooks.before(Spriteset_Map, :dispose, "ui_leader_hud") { MGQ_MpLeaderHud.forget_windows }
rescue => e
  MGQ_MpLeaderHud.log("hooks FAILED: #{e.class}: #{e.message}")
end
