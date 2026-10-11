#----------------------------------------------------------------
#  ui_raid_bar_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-11: Covered the strip as a box of the layout: its least width, a kept place, narrow with three enemies, small mode cropped where it lies, the room at the top and the game's bar only while it lies there
#                            - Covered the gauges and the title drawn anew in another interface preset's colors
#                            - Expected the battle's small strip cropped from its top instead of slid up, and stood in for what the presets and the layout read
#                            - Expected the strip's hint with the hotkey that makes it small, the plates with the shared style's padding, and read the plate and the slide timing from the style
#                            - Checked a long title of the strip cut before the hint's room, and expected the title's box inset by that room
#                            - Stood in for the scene the confirm box follows, so ui.rbx hooks without failing
#      Paulinchen  2026-10-10: Covered a boss of several enemies with a name and a gauge per enemy, the names shrinking to fit, the wider map bar and a damage trail per gauge
#                            - Covered a full boss whose shortened max is no multiple of the unit and the Hades rematch hall without bars
#                            - Created
#
#----------------------------------------------------------------

# Covers the raid bosses' HP bars, ui_raid_bar.rbx, with battles_raid_pool.rbx: the numbers grouped
# by commas, the battle's strip with the boss's title, each enemy's name over its gauge with its
# numbers and share left inside, a boss of several enemies sharing the gauge's width, hidden under
# the game's top message, the game's own boss bar it pushes down, and on the map the bosses' events
# found through their pages and common events, the bar above each that shows, the strip at the top
# while none shows, and the room it takes from the boxes there; the strip where the player puts it
# with Alt and the interface presets' colors. Pictures measure each character at half the font's
# size.

require_relative "support"

module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end
$raid = true
$frame = 0
$routes = {}

# The clock, which stands still, so the pools gain nothing back meanwhile.
$now = Time.at(1_000_000)
def Time.now; $now; end

# Stand-ins for the game's pictures.
Color = Struct.new(:red, :green, :blue, :alpha)
Rect = Struct.new(:x, :y, :width, :height)
# A rectangle set in place, as a sprite's part of its picture is.
class Rect; def set(x, y, width, height); self.x, self.y, self.width, self.height = x, y, width, height; end; end
Font = Struct.new(:size, :outline, :color, :bold, :out_color)
class Bitmap
  attr_reader :width, :height, :font, :texts, :boxes, :gauges, :outlines, :fills
  def initialize(width, height); @width = width; @height = height; @font = Font.new(24); clear; end
  def clear; @texts = []; @boxes = []; @gauges = []; @outlines = 0; @fills = []; end
  def text_size(text); Rect.new(0, 0, (text.to_s.size * font.size * 0.5).ceil, font.size); end
  def draw_text(x, y, width, height, text, align = 0)
    return @outlines += 1 if font.color.to_a == [0, 0, 0, 255]

    @texts << [x, text.to_s, font.size, align]
    @boxes << [x, y, width, height]
  end
  def fill_rect(*args)
    x, y, width, height, color = args[0].is_a?(Rect) ? [args[0].x, args[0].y, args[0].width, args[0].height, args[1]] : args
    @fills << [x, y, width, height, color]
  end
  def gradient_fill_rect(x, _y, width, *); @gauges << [x, width]; end
  def dispose; @disposed = true; end
  def disposed?; @disposed ? true : false; end
end
class Window_Base; def initialize(*); end; end
# A sprite, the part of its picture it shows starting as the whole picture, as RGSS sets it anew with
# each picture.
class Sprite
  attr_accessor :x, :y, :z, :ox, :visible, :viewport
  attr_reader :bitmap, :src_rect
  def initialize(viewport = nil); @viewport = viewport; @x = 0; @y = 0; @src_rect = Rect.new(0, 0, 0, 0); end
  def bitmap=(bitmap); @bitmap = bitmap; @src_rect = Rect.new(0, 0, bitmap.width, bitmap.height); end
  def dispose; @disposed = true; end
  def disposed?; @disposed; end
end
module Graphics
  def self.width; 640; end
  def self.height; 480; end
  def self.update; end
  def self.frame_count; $frame; end
end

# Stand-ins for the world, the game's battles and the map.
module MGQ_MpOverworldSync
  BOSS_FIELD = "boss_key"
  def self.route(field, &block); $routes[field] = block; end
  def self.on_tick(&_block); end
  def self.state_fields(&_block); end
end
module MGQ_MpCoop; module Scope; def self.raid?; $raid; end; end; end
module MGQ_MpWorldStory
  def self.active?; $raid; end
  def self.mode; :world; end
  def self.world_id; "w1"; end
end
module MGQ_MpBattlesSync; def self.role; :guest; end; end
# The party box's hotkey, held for one update by $tab_pressed and named Tab, Player.ini and the
# cursor sound.
module MGQ_MpHotkeys
  def self.pressed?(action); action == :party_box && $tab_pressed; end
  def self.label(_action); "Tab"; end
end
module MGQ_Multiplayer
  module Player
    def self.setting(name); ($settings ||= {})[name]; end
    def self.store(name, value); ($settings ||= {})[name] = value.to_s; end
    def self.forget(name); ($settings ||= {}).delete(name); end
  end
end
# The left Alt and the mouse, which the layout reads, never held or pointing.
module MGQ_Multiplayer
  module Key; def self.down?(_code); false; end; end
  module Mouse; def self.position; nil; end; end
end
module Sound; def self.play_cursor; end; end
class Game_Switches; def initialize; @data = []; end; def [](id); @data[id] || false; end; def []=(id, value); @data[id] = value; end; end
class Game_Variables; def initialize; @data = []; end; def [](id); @data[id] || 0; end; def []=(id, value); @data[id] = value; end; end
EnemyData = Struct.new(:name, :params)
TroopMember = Struct.new(:enemy_id)
TroopData = Struct.new(:members)
$data_enemies = []
{ 1 => ["Queen Harpy", 800], 4 => ["Metatronne", 2000], 5 => ["Sandalphone", 3000], 6 => ["Black Dahlia", 1200], 7 => ["Black Mamba", 1400], 8 => ["Black Rose", 1000] }.each { |id, (name, hp)| $data_enemies[id] = EnemyData.new(name, [hp]) }
$data_troops = []
{ 71 => [1], 1599 => [4, 5], 126 => [1], 836 => [6, 7, 8] }.each { |id, enemies| $data_troops[id] = TroopData.new(enemies.map { |enemy| TroopMember.new(enemy) }) }

# An enemy, whose max HP grows with the game's difficulty variable 41 above 100.
class Game_Enemy
  attr_reader :hp
  attr_accessor :boss
  def initialize(_index, enemy_id); @enemy_id = enemy_id; @hp = mhp; end
  def name; $data_enemies[@enemy_id].name; end
  def mhp; $data_enemies[@enemy_id].params[0] * [$game_variables[41], 100].max / 100; end
  def hp=(value); @hp = [[value, mhp].min, 0].max; end
  def dead?; @hp == 0; end
  def boss?; boss; end
end
class Game_Troop
  attr_reader :members
  def setup(troop_id); @members = $data_troops[troop_id].members.each_with_index.map { |member, index| Game_Enemy.new(index, member.enemy_id) }; end
  def all_dead?; false; end
end
module BattleManager; def self.setup(troop_id, *_rest); $game_troop.setup(troop_id); end; def self.battle_end(_result); end; end
class Scene_Battle; def start_party_command_selection; end; def turn_end; end; end
class Scene_Title; def start; end; end
module SceneManager; def self.run; end; def self.scene; nil; end; end
class Game_Interpreter; def command_301; end; end
class Game_Message; attr_accessor :visible, :position; end
class Spriteset_Battle; def update; end; def dispose; end; end
class Spriteset_Map
  def initialize(sprites); @viewport1 = :characters; @viewport3 = :top; @character_sprites = sprites; end
  def update; end
  def dispose; end
end
class Sprite_Battler
  attr_reader :battler
  def initialize(battler); @battler = battler; @hp_bar = Struct.new(:y, :visible).new(-12, true); end
  def update_hp_bar; @hp_bar.y = -12; end
end

# A map event: its page's commands, its looks and where it stands.
Command = Struct.new(:code, :parameters)
Game_Event = Struct.new(:list, :character_name, :tile_id, :transparent, :opacity, :x, :y)
CommonEvent = Struct.new(:list)
CharacterSprite = Struct.new(:character, :x, :y, :height, :visible, :opacity)
class Game_Map
  attr_accessor :map_id, :events
  def initialize; @map_id = 5; @events = {}; end
  def update_interpreter; end
end

class Scene_Base; def update; end; def start; end; end
load_script "ui"
load_script "ui_theme"
load_script "ui_layout"
load_script "battles_raid_bosses"
load_script "battles_raid_pool"
# The battles below count on 7.5 times the max HP in every tier; the real tiers are checked on their own.
REAL_TIERS = MGQ_MpRaidBosses::TIERS.dup
MGQ_MpRaidBosses::TIERS.replace(REAL_TIERS.keys.each_with_object({}) { |tier, tiers| tiers[tier] = { :mhp => 7.5 } })
load_script "ui_raid_bar"
SceneManager.run

bar = MGQ_MpRaidBar
pool = MGQ_MpRaidPool

# Starts the game's objects anew and forgets every pool.
def reset
  $game_switches = Game_Switches.new
  $game_variables = Game_Variables.new
  $game_troop = Game_Troop.new
  $game_map = Game_Map.new
  $game_message = Game_Message.new
  $data_common_events = []
  $frame += MGQ_MpRaidBar::SCAN_FRAMES
  MGQ_MpRaidPool.forget
  MGQ_MpUi.top_room = 0
end

# Has the relay push a pool.
#
# @param key [String] The pool's key.
# @param left [String] The share of its max left.
# @param max [String] Its max HP.
def push(key, left, max)
  $routes[MGQ_MpOverworldSync::BOSS_FIELD].call(nil, { MGQ_MpOverworldSync::BOSS_FIELD => key, "left" => left, "max" => max, "defeated" => "0", :relay => true })
end

# A battle command of an event's page.
#
# @param troop [Integer] The troop.
# @return [Command] The command.
def battle(troop)
  Command.new(301, [0, troop, false, false])
end

# A bar's content as plain arrays: its title and each gauge's name, HP and max.
#
# @param bar [MGQ_MpRaidBar::Bar, nil] The bar.
# @return [Array, nil] The content, nil for no bar.
def flat(bar)
  bar ? [bar.title, bar.gauges.map { |gauge| gauge.to_a }] : nil
end

# A bar of one enemy.
#
# @param name [String] Its name.
# @param hp [Integer] Its HP.
# @param max [Integer] Its max HP.
# @param title [String, nil] The bar's title.
# @return [MGQ_MpRaidBar::Bar] The bar.
def one(name, hp, max, title = nil)
  MGQ_MpRaidBar::Bar.new(title, [MGQ_MpRaidBar::Gauge.new(name, hp, max)])
end

# The plates of a bar's picture.
#
# @param sprite [Sprite_MpRaidBar] The bar.
# @return [Array<Array>] Each plate's rectangle.
def plates_of(sprite)
  sprite.bitmap.fills.select { |_x, _y, _w, _h, color| color.equal?(MGQ_MpUi::Style::PLATE) }.map { |x, y, w, h, _color| [x, y, w, h] }
end

# Puts the strip where Player.ini keeps it, as the player left it with Alt, or back where it starts.
#
# @param placement [String, nil] The setting, "x,y,width,height", nil for where it starts.
def place_strip(placement)
  MGQ_MpUi::Layout.reset(:raid_bar, "a test")
  $settings["ui_raid_bar"] = placement if placement
end

# What the layout was offered this frame, and forgets it, as its tick does.
#
# @return [Array<Array>] Each box's id, rectangle and depth.
def offers
  offered = MGQ_MpUi::Layout.instance_variable_get(:@offers)
  taken = offered.map { |offer| [offer.id, offer.rect.to_a, offer.z] }
  offered.clear
  taken
end

# The numbers grouped by commas.
check("small numbers stay as they are", [MGQ_MpUi.grouped(0), MGQ_MpUi.grouped(999)], ["0", "999"])
check("thousands are grouped by commas", [MGQ_MpUi.grouped(1000), MGQ_MpUi.grouped(3_412_880.4), MGQ_MpUi.grouped(-1_234_567)], ["1,000", "3,412,880", "-1,234,567"])
check("numbers past 2^53 too", MGQ_MpUi.grouped(2_362_500_000_000_000_000), "2,362,500,000,000,000,000")

# The battle's strip.
reset
check("a battle that fights no pool shows no strip", bar.battle_bar, nil)
pool.note_invite("troop" => "71", "pool" => "1")
BattleManager.setup(71)
$game_troop.members[0].hp = 4500
check("the battle's bar is its boss's HP as the battle has it", flat(bar.battle_bar), ["Tier 9 Raid Boss", [["Queen Harpy", 4500, 6000]]])
push("Queen Harpy", "0.9", "7000")
check("against the relay's max once it told one", flat(bar.battle_bar), ["Tier 9 Raid Boss", [["Queen Harpy", 5250, 7000]]])
spriteset = Spriteset_Battle.new
spriteset.update
strip = spriteset.instance_variable_get(:@mgq_mp_raid_bar)
check("the strip lies at the top under the game's windows", [strip.visible, strip.x, strip.y, strip.z, strip.bitmap.width, strip.bitmap.height], [true, 0, 0, 90, 640, 86])
check("with the hotkey that makes it small at the right of its title line, dim and small, the boss's title, its name below it over the gauge and the HP with the share left inside the gauge, all centered",
      strip.bitmap.texts.map { |x, text, size, align| [x, text, size, align] },
      [[0, "Tab: bars", 14, 2], [67, "Tier 9 Raid Boss", 20, 1], [0, "Queen Harpy", 24, 1], [112, "5,250 / 7,000  (75.0%)", 21, 1]])
check("each in a solid black outline widened by 4 copies above, below and beside it, never bold", [strip.bitmap.outlines, strip.bitmap.font.out_color.to_a, strip.bitmap.font.bold], [16, [0, 0, 0, 255], false])
check("a plate behind each line, as wide as its text with the style's padding, the title's on the name's and the name's on the gauge's frame",
      plates_of(strip), [[234, 0, 172, 26], [248, 26, 144, 26]])
check("its gauge, 65 % of the screen wide, filled by the share left in two glossy halves", strip.bitmap.gauges, [[112, 312], [112, 312]])
sprite = Sprite_Battler.new(Struct.new(:boss).new(true).tap { |battler| def battler.boss?; boss; end })
sprite.update_hp_bar
check("the game's own boss bar moves below the strip", sprite.instance_variable_get(:@hp_bar).y, 74)
$game_message.visible = true
$game_message.position = 0
spriteset.update
sprite.update_hp_bar
check("the game's top message hides the strip, and the game's bar stays", [strip.visible, sprite.instance_variable_get(:@hp_bar).y], [false, -12])
$game_message.visible = false
$game_troop.members[0].hp = 4400
spriteset.update
check("numbers that changed wait for the next drawing", strip.bitmap.texts.last[1], "5,250 / 7,000  (75.0%)")
$frame += MGQ_MpRaidBar::REDRAW_FRAMES
spriteset.update
check("which comes a few frames later", strip.bitmap.texts.last[1], "5,134 / 7,000  (73.3%)")
$tab_pressed = true
spriteset.update
$tab_pressed = false
check("Tab starts cropping the strip from its top where it stands and keeps the choice", [strip.y, strip.src_rect.to_a, strip.bitmap.texts.size, $settings["raid_bar_small"]], [0, [0, 6, 640, 80], 4, "1"])
(MGQ_MpUi::Style::SLIDE_FRAMES - 1).times { spriteset.update }
check("until after SLIDE_FRAMES only its gauge with the HP shows at the strip's top, the title and the name cropped", [strip.y, strip.src_rect.to_a], [0, [0, 50, 640, 36]])
check("the layout grabs what shows", MGQ_MpUi::Layout.instance_variable_get(:@offers).map { |offer| [offer.id, offer.rect.to_a, offer.z] }, [[:raid_bar, [0, 0, 640, 36], 90]])
sprite.update_hp_bar
check("the game's own boss bar follows it up", sprite.instance_variable_get(:@hp_bar).y, 24)
spriteset.update
check("and it stays so", [strip.y, strip.src_rect.to_a], [0, [0, 50, 640, 36]])
$tab_pressed = true
spriteset.update
$tab_pressed = false
MGQ_MpUi::Style::SLIDE_FRAMES.times { spriteset.update }
sprite.update_hp_bar
check("Tab again shows it in full", [strip.y, strip.src_rect.to_a, sprite.instance_variable_get(:@hp_bar).y, $settings["raid_bar_small"]], [0, [0, 0, 640, 86], 74, "0"])
spriteset.dispose
spriteset.update
check("a new battle's sprites make a new strip", spriteset.instance_variable_get(:@mgq_mp_raid_bar).equal?(strip), false)

# A boss of several enemies in battle: a name and a gauge per enemy.
reset
pool.note_invite("troop" => "1599", "pool" => "2")
BattleManager.setup(1599)
$game_troop.members[1].hp = 9000
check("the battle's bar has a gauge per enemy of the boss, with its own HP", flat(bar.battle_bar), ["Archangel", [["Metatronne", 15000, 15000], ["Sandalphone", 9000, 22500]]])
spriteset = Spriteset_Battle.new
spriteset.update
strip = spriteset.instance_variable_get(:@mgq_mp_raid_bar)
check("the strip shows the hint and the title once and each enemy's name over its gauge, with the numbers of each inside",
      strip.bitmap.texts,
      [[0, "Tab: bars", 14, 2], [67, "Archangel", 20, 1], [112, "Metatronne", 24, 1], [323, "Sandalphone", 24, 1], [112, "15,000 / 15,000", 21, 1], [323, "9,000 / 22,500", 21, 1]])
check("two gauges share the gauge's width, 6 px apart", strip.bitmap.gauges, [[112, 205], [112, 205], [323, 82], [323, 82]])
check("the title's plate spans the strip, each name's its gauge", plates_of(strip), [[269, 0, 102, 26], [148, 26, 132, 26], [353, 26, 144, 26]])
spriteset.dispose
reset
pool.note_invite("troop" => "836", "pool" => "3")
BattleManager.setup(836)
check("the Three Nobles of Black are three gauges", flat(bar.battle_bar), ["Tier 5 Raid Boss", [["Black Dahlia", 9000, 9000], ["Black Mamba", 10500, 10500], ["Black Rose", 7500, 7500]]])
spriteset = Spriteset_Battle.new
spriteset.update
strip = spriteset.instance_variable_get(:@mgq_mp_raid_bar)
check("each a third of the gauge's width", strip.bitmap.gauges.each_slice(2).map(&:first), [[112, 134], [252, 134], [392, 134]])
check("the names share the largest font size down from the layout's at which every name fits its gauge",
      strip.bitmap.texts[2..4], [[112, "Black Dahlia", 21, 1], [252, "Black Mamba", 21, 1], [392, "Black Rose", 21, 1]])
check("the plates stand on the gauges' frames and the title's on the plates", plates_of(strip).map { |_x, y, _w, h| [y, h] }.uniq, [[0, 26], [26, 26]])
check("the shrunken names keep their row's height, so they stay centered over their gauges", strip.bitmap.boxes[2..4].map { |_x, y, _w, h| [y, h] }.uniq, [[26, 28]])
spriteset.dispose
strip = Sprite_MpRaidBar.new(nil, false)
strip.show(MGQ_MpRaidBar::Bar.new("Tier 5 Raid Boss", [MGQ_MpRaidBar::Gauge.new("Queen Harpy of the Sky Realm", 1, 1), MGQ_MpRaidBar::Gauge.new("Black Mamba", 1, 1), MGQ_MpRaidBar::Gauge.new("Black Rose", 1, 1)]))
check("a name too long even at the smallest size is cut, every name at that size", strip.bitmap.texts[2..4],
      [[112, "Queen Harpy of...", 14, 1], [252, "Black Mamba", 14, 1], [392, "Black Rose", 14, 1]])
strip = Sprite_MpRaidBar.new(nil, false)
strip.show(one("Black Rose", 1, 1, "A Raid Boss Whose Title Goes On And On And On And On Far Past The Strip's Width"))
title = strip.bitmap.texts[1]
check("a long title of the strip is cut before the hint's room on either side, so it stays centered and never meets the hint",
      [title[0], title[1].end_with?(MGQ_MpUi::ELLIPSIS), strip.bitmap.boxes[1].values_at(0, 2), plates_of(strip).first], [67, true, [67, 506], [67, 0, 506, 26]])

# The strip where the player puts it.
check("the strip is one box of the layout, resized in width alone, as narrow as its title line needs with the hint at either side of the longest title",
      [MGQ_MpUi::Layout.instance_variable_get(:@boxes)[:raid_bar].to_a, Sprite_MpRaidBar.min_strip_width], [["Raid boss bar", 322, 86, :width], 322])
reset
pool.note_invite("troop" => "836", "pool" => "3")
BattleManager.setup(836)
$game_troop.members[0].hp = 4500
place_strip("10,200,100,30")
spriteset = Spriteset_Battle.new
spriteset.update
strip = spriteset.instance_variable_get(:@mgq_mp_raid_bar)
check("a strip kept narrower and lower than it may be stays at the least width and its own height, where the player put it",
      [strip.x, strip.y, strip.bitmap.width, strip.bitmap.height, strip.src_rect.to_a], [10, 200, 322, 86, [0, 0, 322, 86]])
check("which still shows the hint, the whole title, every name and how much each enemy has left", strip.bitmap.texts,
      [[0, "Tab: bars", 14, 2], [67, "Tier 5 Raid Boss", 20, 1], [6, "Black Dahlia", 15, 1], [111, "Black Mamba", 15, 1], [216, "Black Rose", 15, 1],
       [6, "50.0%", 21, 1], [111, "100.0%", 21, 1], [216, "100.0%", 21, 1]])
check("its row of gauges takes the strip's width less the margins, a third each", strip.bitmap.gauges.each_slice(2).map(&:first), [[6, 50], [111, 99], [216, 99]])
check("the layout grabs it where it lies", offers, [[:raid_bar, [10, 200, 322, 86], 90]])
sprite = Sprite_Battler.new(Struct.new(:boss).new(true).tap { |battler| def battler.boss?; boss; end })
sprite.update_hp_bar
check("the game's own boss bar stays at the top while the strip lies elsewhere", sprite.instance_variable_get(:@hp_bar).y, -12)
$tab_pressed = true
spriteset.update
$tab_pressed = false
MGQ_MpUi::Style::SLIDE_FRAMES.times { spriteset.update }
check("small, it shows its gauges alone where it lies", [strip.y, strip.src_rect.to_a, offers], [200, [0, 50, 322, 36], [[:raid_bar, [10, 200, 322, 36], 90]]])
place_strip("0,3,640,86")
spriteset.update
sprite.update_hp_bar
check("a strip within a few pixels of the top still moves the game's bar below what shows of it", sprite.instance_variable_get(:@hp_bar).y, -12 + 3 + 36)
$tab_pressed = true
spriteset.update
$tab_pressed = false
MGQ_MpUi::Style::SLIDE_FRAMES.times { spriteset.update }
place_strip(nil)
spriteset.update
check("put back, it lies across the top again", [strip.x, strip.y, strip.bitmap.width], [0, 0, 640])
MGQ_MpUi::Theme.apply("Monarch", "a test")
$frame += MGQ_MpRaidBar::REDRAW_FRAMES
spriteset.update
colors = lambda { |sprite_of| sprite_of.bitmap.fills.map { |fill| fill[4].to_a }.uniq }
check("another preset draws the gauges anew in its edge and well, the outer frame staying black",
      [colors.call(strip).include?([200, 164, 96, 230]), colors.call(strip).include?([36, 10, 14, 235]), colors.call(strip).include?([0, 0, 0, 255])], [true, true, true])
check("and the title in its title color", [Sprite_MpRaidBar::TITLE_COLOR.to_a, Sprite_MpRaidBar::EDGE.equal?(MGQ_MpUi::Style::EDGE)], [[255, 224, 140, 255], true])
MGQ_MpUi::Theme.apply("Legacy", "a test")
$frame += MGQ_MpRaidBar::REDRAW_FRAMES
spriteset.update
check("and back", [colors.call(strip).include?([140, 140, 140, 220]), colors.call(strip).include?([200, 164, 96, 230])], [true, false])
spriteset.dispose
offers

# The bosses' events on the map.
reset
$data_common_events[20] = CommonEvent.new([Command.new(117, [21]), battle(1599)])
$data_common_events[21] = CommonEvent.new([Command.new(117, [20]), battle(126)])
$game_variables[1019] = 6
harpy = Game_Event.new([battle(31), battle(71)], "$Harpy", 0, false, 255, 10, 10)
gate = Game_Event.new([Command.new(117, [20])], "", 0, false, 255, 30, 4)
$game_map.events = { 1 => harpy, 2 => gate, 3 => Game_Event.new(nil, "$Erased", 0, false, 255, 0, 0) }
check("the events whose page starts a boss battle, through common events too, a beaten boss left out",
      bar.boss_events.map { |event, troop| [event.x, troop] }, [[10, 71], [30, 1599]])
check("the steps to a boss's event", [bar.distance_to_boss(71, 12, 13), bar.distance_to_boss(2016, 0, 0)], [3, MGQ_MpRaidBar::FAR])
$game_map.map_id = MGQ_MpRaidPool::HADES_MAP
$frame += MGQ_MpRaidBar::SCAN_FRAMES
check("the Hades rematch hall's events show no bars, their rematches fight no pool", [bar.boss_events, bar.shown_troop?(71)], [[], false])
$game_map.map_id = 5
$game_switches[MGQ_MpRaidPool::HADES_SWITCH] = true
$frame += MGQ_MpRaidBar::SCAN_FRAMES
check("nor any while a Hades rematch's switch is on", bar.boss_events, [])
$game_switches[MGQ_MpRaidPool::HADES_SWITCH] = false
$frame += MGQ_MpRaidBar::SCAN_FRAMES
check("a bar before any pool shows the boss's full HP at the player's difficulty", flat(bar.map_bar(71)), ["Tier 9 Raid Boss", [["Queen Harpy", 6000, 6000]]])
$game_variables[41] = 150
check("which the difficulty raises, a gauge per enemy of the troop", flat(bar.map_bar(1599)), ["Archangel", [["Metatronne", 22500, 22500], ["Sandalphone", 33750, 33750]]])
push("Metatronne and Sandalphone#1", "0.5", "22500")
check("the pool the relay told counts with its max, the other keeps the enemy's own",
      flat(bar.map_bar(1599)), ["Archangel", [["Metatronne", 22500, 22500], ["Sandalphone", 11250, 22500]]])
check("names that repeat within a troop get letters, as the game letters them in battle", bar.map_names([4, 4, 5, 1, 1, 1]),
      ["Metatronne A", "Metatronne B", "Sandalphone", "Queen Harpy A", "Queen Harpy B", "Queen Harpy C"])
def $game_troop.letter_table; ["Ａ", "Ｂ"]; end
twins = $data_troops[1599]
$data_troops[1599] = TroopData.new([TroopMember.new(4), TroopMember.new(4)])
check("the game's own letters when the troop knows them", flat(bar.map_bar(1599)), ["Archangel", [["MetatronneＡ", 22500, 22500], ["MetatronneＢ", 11250, 22500]]])
$data_troops[1599] = twins
spriteset = Spriteset_Map.new([CharacterSprite.new(harpy, 200, 300, 48, true, 255), CharacterSprite.new(gate, 300, 50, 32, true, 255)])
spriteset.update
bars = spriteset.instance_variable_get(:@mgq_mp_raid_bars)
overhead = bars.instance_variable_get(:@overhead)
check("a bar above the boss whose event shows", [overhead.size, overhead[harpy].x, overhead[harpy].y, overhead[harpy].viewport], [1, 200, 300 - 48 - 52 - 4, :characters])
check("with its title and its name over a thin gauge without numbers, 240 wide for a boss of one enemy",
      [overhead[harpy].bitmap.texts, overhead[harpy].bitmap.gauges.size, overhead[harpy].bitmap.width, overhead[harpy].ox],
      [[[0, "Tier 9 Raid Boss", 16, 1], [0, "Queen Harpy", 18, 1]], 2, 240, 120])
check("no strip while a boss's event shows", [bars.instance_variable_get(:@strip), MGQ_MpUi.top_room], [nil, 0])
$game_map.events.delete(1)
$frame += MGQ_MpRaidBar::SCAN_FRAMES
spriteset.update
strip = bars.instance_variable_get(:@strip)
check("a boss without an event that shows gets the strip at the top", [overhead.size, strip.visible, strip.viewport], [0, true, :top])
check("which tells the boxes at the top its room", MGQ_MpUi.top_room, 86)
check("the layout grabs it at the top", offers, [[:raid_bar, [0, 0, 640, 86], MGQ_MpUi::Z[:labels]]])
place_strip("100,120,400,86")
spriteset.update
check("moved down and narrower, it lies there and leaves the boxes at the top their room", [strip.x, strip.y, strip.bitmap.width, MGQ_MpUi.top_room], [100, 120, 400, 0])
check("its row of gauges takes the strip's width less the margins once that is less than the share of the screen, shared by the gauges", strip.bitmap.gauges.each_slice(2).map(&:first), [[6, 191], [203, 96]])
check("where the layout grabs it", offers, [[:raid_bar, [100, 120, 400, 86], MGQ_MpUi::Z[:labels]]])
place_strip("0,2,640,86")
spriteset.update
check("within a few pixels of the top, the boxes there make room for it to its bottom", MGQ_MpUi.top_room, 88)
place_strip(nil)
spriteset.update
gate.character_name = "!Flame"
$frame += MGQ_MpRaidBar::SCAN_FRAMES
spriteset.update
check("a marker counts as the boss's sprite, under its feet when the screen has no room above", [overhead.size, overhead[gate].y, strip.visible, MGQ_MpUi.top_room], [1, 52, false, 0])
check("the bar of a boss of several enemies is 480 wide, a name and a thin gauge per enemy",
      [overhead[gate].bitmap.width, overhead[gate].ox, overhead[gate].bitmap.texts, overhead[gate].bitmap.gauges.each_slice(2).map(&:first)],
      [480, 240, [[0, "Archangel", 16, 1], [2, "Metatronne", 18, 1], [243, "Sandalphone", 18, 1]], [[2, 235], [243, 118]]])
$raid = false
spriteset.update
check("no bars outside a Raid World's story", [overhead.size, MGQ_MpUi.top_room], [0, 0])
$raid = true
gate.character_name = ""
$frame += MGQ_MpRaidBar::SCAN_FRAMES
spriteset.update
spriteset.dispose
check("the strip's room is free once the map's sprites go", MGQ_MpUi.top_room, 0)
remade = Sprite_MpRaidBar.new(:characters, true)
remade.show(one("Queen Harpy", 1, 1))
first = remade.bitmap
remade.show(MGQ_MpRaidBar::Bar.new(nil, [MGQ_MpRaidBar::Gauge.new("Metatronne", 1, 1), MGQ_MpRaidBar::Gauge.new("Sandalphone", 1, 1)]))
check("a bar above an event remakes its picture when the boss it shows needs another width, freeing the old one",
      [first.width, first.disposed?, remade.bitmap.width, remade.ox, remade.bitmap.texts.size], [240, true, 480, 240, 3])
remade.show(one("Queen Harpy", 1, 1))
check("and back", [remade.bitmap.width, remade.ox, remade.bitmap.texts.size], [240, 120, 2])

# Long numbers in the strip.
reset
long = Sprite_MpRaidBar.new(nil, false)
short = MGQ_MpRaidBar
check("numbers up to 7 digits stay whole", [short.short_numbers(3_412_880, 5_000_000), short.short_numbers(9_999_999, 10_000_000)],
      ["3,412,880 / 5,000,000", "9,999,999 / 10,000,000"])
check("longer ones take the largest unit that leaves the max at least 7 digits",
      [short.short_numbers(999_999_999, 1_000_000_000), short.short_numbers(236_166_381_881_187, 1_009_500_000_000_000)],
      ["1,000,000 K / 1,000,000 K", "236,167 B / 1,009,500 B"])
check("the HP rounds up, so a boss with HP left never reads 0", short.short_numbers(1, 2_362_500_000_000), "1 M / 2,362,500 M")
check("but never above the max, which rounds down, for a full boss whose max is no multiple of the unit",
      [short.short_numbers(1_234_567_891, 1_234_567_891), short.short_numbers(1_234_567_001, 1_234_567_891), short.short_numbers(1, 1_234_567_891)],
      ["1,234,567 K / 1,234,567 K", "1,234,567 K / 1,234,567 K", "1 K / 1,234,567 K"])
long.show(one("Chaos", 2_362_500_000_000, 2_362_500_000_000))
check("the strip shows them shortened, with the share left", long.bitmap.texts.last[1..2], ["2,362,500 M / 2,362,500 M  (100.0%)", 21])
long.show(one("Chaos", 10**27, 10**27))
$frame += MGQ_MpRaidBar::REDRAW_FRAMES
long.show(one("Chaos", 10**27, 10**27))
check("numbers too long for both show the HP alone", long.bitmap.texts.last[1], "1,000,000,000 Qi / 1,000,000,000 Qi")
long.show(one("Chaos", 10**30, 10**30))
$frame += MGQ_MpRaidBar::REDRAW_FRAMES
long.show(one("Chaos", 10**30, 10**30))
check("and too long even so only the share left", long.bitmap.texts.last[1..2], ["100.0%", 21])
long.show(one("Chaos", 1, 2_362_500_000_000))
$frame += MGQ_MpRaidBar::REDRAW_FRAMES
long.show(one("Chaos", 1, 2_362_500_000_000))
check("a share left too small to show is never 0 %", long.percent(MGQ_MpRaidBar::Gauge.new("Chaos", 1, 2_362_500_000_000)), "<0.1%")
check("and its gauge shows a sliver, the HP it just lost in the damage trail behind it", long.bitmap.gauges, [[113, 415], [112, 1], [112, 1]])

# The damage trail: the HP of the last two seconds, draining down to the HP left.
trail = Sprite_MpRaidBar.new(nil, true)
harpy = lambda { |hp| one("Queen Harpy", hp, 1000, "Tier 9 Raid Boss") }
shown = lambda { trail.instance_variable_get(:@trails).map { |each| each.shown } }
trail.show(harpy.call(1000))
$frame += 10
trail.show(harpy.call(600))
check("a loss shows in the damage trail from the HP before it", [shown.call, trail.bitmap.gauges.first], [[1.0], [144, 94]])
$frame += Sprite_MpRaidBar::TRAIL_FRAMES
trail.show(harpy.call(600))
check("which holds for TRAIL_FRAMES", shown.call, [1.0])
$frame += 1
trail.show(harpy.call(600))
check("then drains", shown.call.first.between?(0.6001, 0.99), true)
120.times { $frame += 1; trail.show(harpy.call(600)) }
check("down to the HP left", shown.call, [0.6])
$frame += 1
trail.show(harpy.call(500))
$frame += 30
trail.show(harpy.call(400))
$frame += Sprite_MpRaidBar::TRAIL_FRAMES - 40
trail.show(harpy.call(400))
check("blows in a row keep the HP before the first of them while it is within TRAIL_FRAMES", shown.call, [0.6])
$frame += 1
trail.show(harpy.call(900))
check("healing rises at once, without a trail", shown.call, [0.9])
trail.show(one("Morrigan", 100, 1000, "Tier 8 Raid Boss"))
check("another boss starts without a trail", shown.call, [0.1])
nobles = lambda { |dahlia, mamba| MGQ_MpRaidBar::Bar.new("Tier 5 Raid Boss", [MGQ_MpRaidBar::Gauge.new("Black Dahlia", dahlia, 1000), MGQ_MpRaidBar::Gauge.new("Black Mamba", mamba, 1000)]) }
trail.show(nobles.call(1000, 1000))
check("a boss of several enemies starts a trail per gauge", shown.call, [1.0, 1.0])
$frame += 10
trail.show(nobles.call(1000, 600))
(Sprite_MpRaidBar::TRAIL_FRAMES + 121).times { $frame += 1; trail.show(nobles.call(1000, 600)) }
check("each gauge's trail drains on its own", shown.call, [1.0, 0.6])
$frame += 1
trail.show(nobles.call(500, 600))
check("a hit on one gauge leaves the other's trail alone", [shown.call, trail.bitmap.gauges], [[1.0, 0.6], [[120, 117], [2, 118], [2, 118], [243, 141], [243, 141]]])
