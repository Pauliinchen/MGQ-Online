#----------------------------------------------------------------
#  ui_raid_bar_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Answered the troops of the map's pages with fixed values in place of a copy of the DLL's command index
#                            - Answered the bars and the pools with fixed values per case in place of a copy of the DLL's bars
#                            - Answered the raid bosses' rules with fixed values per case and asked which troops show a bar in one call
#                            - Kept the bars' switches in the stand-in of Player.ini as true or false, as the DLL hands them back
#                            - Noted invites with their pool as a number and their tier as true
#                            - Read the scripts' clock from $frame
#      Paulinchen  2026-11-01: Read the bars from the Mod Framework's components they build, the DLL's bars answered by a stand-in
#                            - Stopped loading the deleted ui_boxes.rbx
#      Paulinchen  2026-10-31: Kept the strip's place in the Mod Framework's settings
#      Paulinchen  2026-10-30: Told the pools through the stand-in of the pools' ledger in C#
#                            - Dropped the checks that restate pixel positions
#      Paulinchen  2026-10-28: Stood in for the DLL's command index of the map's pages, whose walk through common events the DLL's tests check
#      Paulinchen  2026-10-23: Placed the strip through the stand-in of the layout in C#
#                            - Stood in for the ids coop.rbx makes up
#                            - Showed the HUD over the map's sprites
#      Paulinchen  2026-10-17: Checked the bars above the bosses' stand-ins of frozen fights
#      Paulinchen  2026-10-13: Checked the bars of the raid bosses outside Raid Worlds and turning them off
#      Paulinchen  2026-10-12: Checked that common events calling each other keep every troop
#                            - Checked Tab pressed while the chat box is open
#      Paulinchen  2026-10-11: Covered the strip as a box of the layout
#                            - Covered the gauges and the title in another preset's colors
#                            - Expected the small strip cropped from its top and stood in for the presets and the layout
#                            - Expected the strip's hotkey hint and read the plates and slide timing from the style
#                            - Checked a long strip title cut before the hint
#                            - Stood in for the scene the confirm box follows
#      Paulinchen  2026-10-10: Covered a boss of several enemies with a name and a gauge per enemy
#                            - Covered a full boss with an uneven shortened max and the Hades rematch hall
#                            - Created
#
#----------------------------------------------------------------

# Covers the raid bosses' HP bars, ui_raid_bar.rbx, with battles_raid_pool.rbx: what the battle and
# the map ask the DLL for their bars (hud.battle_bar, hud.map_bar, whose rules MGQOnline.Game.Tests
# checks against their golden cases), the battle's strip with the boss's title, each enemy's name
# over its gauge with its numbers and share left inside, hidden under the game's top message, small
# by the hotkey or a click on its hint, the game's own boss bar it pushes down, and on the map the
# bosses' events found through their pages and common events, the bar above each that shows and the
# strip docked at the top while none shows; with battles_raid_tiers.rbx the bars of the raid bosses
# outside Raid Worlds, which the player turns off in the Mod Config; and the bars above the bosses'
# stand-ins of frozen fights.

require_relative "components_support"

# The mod's log, printed with the checks.
module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end
$raid = true
$frame = 0
$routes = {}

# The clock, which stands still, so the pools gain nothing back meanwhile.
$now = Time.at(1_000_000)
# The time in $now.
def Time.now; $now; end

# The game's window base, which draws nothing.
class Window_Base; def initialize(*); end; end
# The game's sprite.
class Sprite
  attr_accessor :x, :y, :z, :ox, :oy, :visible, :opacity, :viewport, :bitmap, :src_rect
  # Creates a sprite at the top left.
  def initialize(viewport = nil); @viewport = viewport; @x = 0; @y = 0; end
  # Frees the sprite.
  def dispose; @disposed = true; end
  # Whether the sprite was freed.
  def disposed?; @disposed ? true : false; end
end
# The game's screen of 640 by 480 pixels, at frame $frame.
module Graphics
  # The screen's width.
  def self.width; 640; end
  # The screen's height.
  def self.height; 480; end
  # Shows nothing.
  def self.update; end
end
clock_from { $frame }

# Stand-ins for the world, the game's battles and the map.

# The world room: keeps the routes in $routes, in a world while $in_world.
module MGQ_MpOverworldSync
  # The state field naming the boss a player fights.
  BOSS_FIELD = "boss_key"
  # The field of the relay's push of a Classic world's raid bosses.
  RAID_BOSSES_FIELD = "raid_bosses_value"
  # Whether the player is in a world: $in_world.
  def self.in_world?; $in_world; end
  # Keeps a field's handler in $routes.
  def self.route(field, &block); $routes[field] = block; end
  # Takes no tick.
  def self.on_tick(&_block); end
  # Takes no state fields.
  def self.state_fields(&_block); end
end
# The open world, a Classic world with raid bosses while $raid_bosses.
module MGQ_MpWorld; def self.raid_bosses?; $raid_bosses; end; end
# Stands in for coop.rbx: its scope, a Raid World while $raid, and the ids it makes up.
module MGQ_MpCoop
  module Scope; def self.raid?; $raid; end; end
  # Makes up an id as the DLL does, its digits counted up.
  def self.random_id(length, radix = 36); ($ids = $ids.to_i + 1).to_s(radix).rjust(length, "0"); end
end
# The world's story of world w1, active in a Raid World.
module MGQ_MpWorldStory
  # Whether the world's story is active.
  def self.active?; $raid; end
  # The player plays the world's story.
  def self.mode; :world; end
  # The world's id.
  def self.world_id; "w1"; end
end
# The live battle, in which the player is a guest.
module MGQ_MpBattlesSync; def self.role; :guest; end; end
# The party box's hotkey, held for one update by $tab_pressed and named Tab, its refusals kept in
# $refusals.
module MGQ_MpHotkeys
  # Whether the party box's hotkey is pressed.
  def self.pressed?(action); action == :party_box && $tab_pressed; end
  # The hotkey's name.
  def self.label(_action); "Tab"; end
  # Records a refused hotkey in $refusals.
  def self.log_refusal(action, reason); ($refusals ||= []) << [action, reason]; nil; end
end
# The mod's base script, as far as Player.ini, kept in $settings.
module MGQ_Multiplayer
  # Player.ini, kept in $settings.
  module Player
    # A setting of Player.ini.
    def self.setting(name); ($settings ||= {})[name]; end
    # Stores a setting as the DLL hands it back: true or false as they are, the rest as text.
    def self.store(name, value); ($settings ||= {})[name] = value == true || value == false || value.is_a?(Integer) ? value : value.to_s; end
    # Forgets a setting.
    def self.forget(name); ($settings ||= {}).delete(name); end
  end
end
# The game's cursor sound, counted in $cursor_sounds.
module Sound; def self.play_cursor; $cursor_sounds = $cursor_sounds.to_i + 1; end; end
# The game's switches, off until set.
class Game_Switches; def initialize; @data = []; end; def [](id); @data[id] || false; end; def []=(id, value); @data[id] = value; end; end
# The game's variables, 0 until set.
class Game_Variables; def initialize; @data = []; end; def [](id); @data[id] || 0; end; def []=(id, value); @data[id] = value; end; end
# An enemy of the database: its name and its parameters, max HP first.
EnemyData = Struct.new(:name, :params)
# A member of a troop of the database.
TroopMember = Struct.new(:enemy_id)
# A troop of the database.
TroopData = Struct.new(:members)
$data_enemies = []
{ 1 => ["Queen Harpy", 750], 4 => ["Metatronne", 2000], 5 => ["Sandalphone", 3000], 6 => ["Black Dahlia", 1200], 7 => ["Black Mamba", 1400], 8 => ["Black Rose", 1000] }.each { |id, (name, hp)| $data_enemies[id] = EnemyData.new(name, [hp]) }
$data_troops = []
{ 71 => [1], 1599 => [4, 5], 126 => [1], 836 => [6, 7, 8] }.each { |id, enemies| $data_troops[id] = TroopData.new(enemies.map { |enemy| TroopMember.new(enemy) }) }

# An enemy, whose max HP grows with the game's difficulty variable 41 above 100.
class Game_Enemy
  # Its HP.
  attr_reader :hp
  # Whether it is a boss.
  attr_accessor :boss
  # Creates the enemy at its max HP.
  def initialize(_index, enemy_id); @enemy_id = enemy_id; @hp = mhp; end
  # Its name.
  def name; $data_enemies[@enemy_id].name; end
  # Its max HP, raised by the difficulty variable 41.
  def mhp; $data_enemies[@enemy_id].params[0] * [$game_variables[41], 100].max / 100; end
  # Sets its HP between 0 and the max.
  def hp=(value); @hp = [[value, mhp].min, 0].max; end
  # Whether it has no HP left.
  def dead?; @hp == 0; end
  # Whether it is a boss.
  def boss?; boss; end
end
# The game's troop.
class Game_Troop
  # Its enemies.
  attr_reader :members
  # Sets up a troop of the database.
  def setup(troop_id); @members = $data_troops[troop_id].members.each_with_index.map { |member, index| Game_Enemy.new(index, member.enemy_id) }; end
  # The troop never falls.
  def all_dead?; false; end
end
# The game's battle manager: a battle's setup sets up its troop.
module BattleManager; def self.setup(troop_id, *_rest); $game_troop.setup(troop_id); end; def self.battle_end(_result); end; end
# The game's battle screen.
class Scene_Battle; def start_party_command_selection; end; def turn_end; end; end
# The game's title screen.
class Scene_Title; def start; end; end
# The game's scene manager, without a scene.
module SceneManager; def self.run; end; def self.scene; nil; end; end
# The game's interpreter, as far as its battle command.
class Game_Interpreter; def command_301; end; end
# The game's message: whether it shows and where.
class Game_Message; attr_accessor :visible, :position; end
# The battle's sprites.
class Spriteset_Battle; def update; end; def dispose; end; end
# The map's sprites: its characters' sprites.
class Spriteset_Map
  # Creates the map's sprites with the characters' sprites.
  def initialize(sprites); @character_sprites = sprites; end
  # Updates nothing.
  def update; end
  # Frees nothing.
  def dispose; end
  # Shows the HUD, as the map does.
  def mgq_mp_hud?; true; end
end
# A battler's sprite with the game's own boss bar.
class Sprite_Battler
  # The battler.
  attr_reader :battler
  # Creates the sprite with the game's boss bar at its place.
  def initialize(battler); @battler = battler; @hp_bar = Struct.new(:y, :visible).new(-12, true); end
  # Puts the game's boss bar back at its place.
  def update_hp_bar; @hp_bar.y = -12; end
end

# A command of an event's page.
Command = Struct.new(:code, :parameters)
# A map event: its page's commands, its looks and where it stands.
Game_Event = Struct.new(:list, :character_name, :tile_id, :transparent, :opacity, :x, :y)
# Names a map event by its x, unique on the checks' maps.
class Game_Event; def id; x; end; end
# A character's sprite on the map.
CharacterSprite = Struct.new(:character, :x, :y, :height, :visible, :opacity)
# The map: its id and its events.
class Game_Map
  # The map's id and its events by id.
  attr_accessor :map_id, :events
  # Creates map 5 without events.
  def initialize; @map_id = 5; @events = {}; end
  # Runs no event.
  def update_interpreter; end
end

# The game's scene base, which does nothing.
class Scene_Base; def update; end; def start; end; end
load_script "ui_online"
load_script "battles_raid_bosses"
load_script "battles_raid_pool"
load_script "battles_raid_tiers"
# Stands in for the DLL's command index of the map's pages: the troops of each event's page by
# event id as $page_troops holds them; the asks noted in $troops_asked.
module MGQ_MpCoopEvents
  # Lists the troops of the events' pages by event.
  def self.page_troops(events, skip)
    ($troops_asked ||= []) << [events.map(&:x), skip]
    $page_troops || {}
  end
end
load_script "ui_raid_bar"

# The bridge to the fake models of the interface, which place the boxes in the layout.
require_relative "raid_support"
open_fake_ui { ["", 0] }
answer_raid_rules($world_bridge)
answer_raid_pools($world_bridge)
# The battles below count on 8 times the max HP in every tier.
MGQ_MpRaidBosses.tiers.keys.each { |tier| MGQ_MpRaidBosses.tiers[tier] = { :mhp => 8 } }
SceneManager.run

# The bars the DLL's HudTopics hand back, by kind and title, as each case sets them; the requests
# are kept in $bar_requests.
$bar_answers = {}
[[:battle, MGQ_MpRaidBar::BATTLE_BAR_TOPIC], [:map, MGQ_MpRaidBar::MAP_BAR_TOPIC]].each do |kind, topic|
  $world_bridge.answer(topic) do |request|
    $bar_requests << [kind, request]
    gauges = $bar_answers[[kind, request["title"]]]
    gauges && [request["title"], gauges]
  end
end

# A gauge as the DLL hands it.
#
# @param name [String] The enemy's name.
# @param hp [Integer] Its HP.
# @param max [Integer] Its max HP.
# @param share [String] The share left as the DLL writes it.
# @return [Array] The gauge.
def gauge(name, hp, max, share)
  [name, hp, max, "#{hp} / #{max}", share]
end

bar = MGQ_MpRaidBar
pool = MGQ_MpRaidPool
ui = Mod_Framework::UI

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
  $pool_answers.clear
  $bar_requests = []
  $bar_answers = {}
  answer_bars
end

# Answers what the rules say of the bosses below: an invite fights Queen Harpy's or the Three
# Nobles of Black's pools, and Queen Harpy and Metatronne and Sandalphone show bars.
def answer_bars
  nobles = "Black Dahlia, Black Mamba and Black Rose (cap 55)"
  $raid_answers.clear
  $raid_answers.pool_kinds[71] = { "kind" => "guest", "keys" => ["Queen Harpy"], "tier" => 9 }
  $raid_answers.pool_kinds[836] = { "kind" => "guest", "keys" => (0..2).map { |index| "#{nobles}##{index}" }, "tier" => 5 }
  $raid_answers.troops[71] = { "shown" => true, "keys" => ["Queen Harpy"] }
  $raid_answers.troops[1599] = { "shown" => true, "keys" => ["Metatronne and Sandalphone#0", "Metatronne and Sandalphone#1"] }
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
  bar ? [bar.title, bar.gauges.map { |gauge| [gauge.name, gauge.hp, gauge.max] }] : nil
end

# Lists a bar's gauges: each one's rate and the texts it shows, the first that fits.
#
# @param parts [MGQ_MpRaidBar::BarParts] The bar's parts.
# @return [Array<Array>] Each gauge's rate and texts.
def gauges_of(parts)
  parts.gauges.map { |gauge| [gauge.rate, gauge.text] }
end

# The battle's strip.
reset
check("a battle that fights no pool shows no strip, without asking the DLL", [bar.battle_bar, $bar_requests], [nil, []])
pool.note_invite("troop" => "71", "pool" => 1)
BattleManager.setup(71)
$game_troop.members[0].hp = 4500
$bar_answers[[:battle, "Tier 9 Raid Boss"]] = [gauge("Queen Harpy", 5250, 7000, "75.0%")]
check("the battle asks the DLL for its boss's bar with each enemy's HP as the battle has it and its pool, and shows what it hands back",
      [flat(bar.battle_bar), $bar_requests.last], [["Tier 9 Raid Boss", [["Queen Harpy", 5250, 7000]]], [:battle, { "title" => "Tier 9 Raid Boss", "enemies" => [["Queen Harpy", 4500, 6000, false, "Queen Harpy"]] }]])
spriteset = Spriteset_Battle.new
spriteset.update
strip = spriteset.instance_variable_get(:@mgq_mp_raid_bar)
root = strip.root
check("the strip is the movable Raid boss bar, resized in width alone, under the game's windows over the battlers, not docked in battle",
      [root.open?, root.id, root.place_name, root.resizable, root.under_windows, root.z, root.dock, root.at, root.min_size],
      [true, :raid_bar, "Raid boss bar", :width, true, 90, nil, [0, 0], [MGQ_MpRaidBar::StripView.min_width, 36]])
check("the boss's title in the title color and the name over the gauge on plates as wide as their texts, the hint of the hotkey that makes it small",
      [texts_of(root), part_with_text(root, "Tier 9 Raid Boss").color, [part_with_text(root, "Tier 9 Raid Boss").plate, part_with_text(root, "Queen Harpy").plate], part_with_text(root, "Tab: bars").is_a?(ui::Button)],
      [["Tier 9 Raid Boss", "Tab: bars", "Queen Harpy"], :title, [:text, :text], true])
gauge = strip.parts.gauges.first
check("the gauge framed, maroon from its top down, with a damage trail, and the HP with the share left inside, else the HP, else the share",
      [gauge.framed, gauge.vertical, gauge.colors, gauge.trail, gauges_of(strip.parts)],
      [true, true, MGQ_MpRaidBar::BarParts::FILL_COLORS, true, [[0.75, ["5250 / 7000  (75.0%)", "5250 / 7000", "75.0%"]]]])
sprite = Sprite_Battler.new(Struct.new(:boss).new(true).tap { |battler| def battler.boss?; boss; end })
MGQ_MpRaidBar.battle_bottom = 86
sprite.update_hp_bar
check("the game's own boss bar moves below the strip while it lies at the top", sprite.instance_variable_get(:@hp_bar).y, 74)
$game_message.visible = true
$game_message.position = 0
spriteset.update
sprite.update_hp_bar
check("the game's top message hides the strip, and the game's bar stays", [hidden_root?(root), sprite.instance_variable_get(:@hp_bar).y], [true, -12])
$game_message.visible = false
spriteset.update
$bar_answers[[:battle, "Tier 9 Raid Boss"]] = [gauge("Queen Harpy", 5134, 7000, "73.3%")]
spriteset.update
check("numbers that changed wait a few frames", gauges_of(strip.parts).first[1][1], "5250 / 7000")
$frame += MGQ_MpRaidBar::REDRAW_FRAMES
spriteset.update
check("then show", gauges_of(strip.parts).first[1][1], "5134 / 7000")
$tab_pressed = true
spriteset.update
$tab_pressed = false
check("Tab makes it small and keeps the choice, its height easing down to the gauges alone, which it keeps at its bottom",
      [$settings["raid_bar_small"], root.tail, $cursor_sounds], [true, true, 1])
part_with_text(root, "Tab: bars").send(:emit, :click)
check("a click on its hint shows it whole again", [$settings["raid_bar_small"], MGQ_MpRaidBar.small?], [false, false])
# The chat, which the player types in while $chat_typing.
module MGQ_MpChat; def self.typing?; $chat_typing; end; end
$chat_typing = true
$tab_pressed = true
spriteset.update
$tab_pressed = false
$chat_typing = false
check("Tab typed into the chat box changes nothing, its refusal left to the hotkeys, which log none while the player types",
      [$settings["raid_bar_small"], $refusals], [false, [[:party_box, "the chat box is open"]]])
spriteset.dispose
check("the battle's sprites close the strip as they go", root.open?, false)
spriteset.update
check("a new battle's sprites make a new strip", spriteset.instance_variable_get(:@mgq_mp_raid_bar).equal?(strip), false)
spriteset.dispose

# A boss of several enemies in battle: a name and a gauge per enemy.
reset
pool.note_invite("troop" => "836", "pool" => 3)
BattleManager.setup(836)
$bar_answers[[:battle, "Tier 5 Raid Boss"]] = [gauge("Black Dahlia", 900, 900, "100.0%"), gauge("Black Mamba", 900, 900, "100.0%"), gauge("Black Rose", 900, 900, "100.0%")]
spriteset = Spriteset_Battle.new
spriteset.update
strip = spriteset.instance_variable_get(:@mgq_mp_raid_bar)
names = parts_of_kind(strip.root, ui::Label).select { |label| label.text.start_with?("Black") }
check("the Three Nobles of Black are three gauges, each name over its own and shrinking with the others down to 14 so each fits",
      [strip.parts.gauges.size, names.map(&:text), names.map(&:min_font_size).uniq], [3, ["Black Dahlia", "Black Mamba", "Black Rose"], [14]])
first_gauges = strip.parts.gauges
$bar_answers[[:battle, "Tier 5 Raid Boss"]][0] = gauge("Black Dahlia", 600, 900, "66.7%")
$frame += MGQ_MpRaidBar::REDRAW_FRAMES
spriteset.update
check("the same boss keeps its gauges, so their trails drain on", strip.parts.gauges.equal?(first_gauges) || strip.parts.gauges == first_gauges, true)
spriteset.dispose

# The bosses' events on the map.
reset
$bar_answers[[:map, "Tier 9 Raid Boss"]] = [gauge("Queen Harpy", 6000, 6000, "100.0%")]
$bar_answers[[:map, "Archangel"]] = [gauge("Metatronne", 24000, 24000, "100.0%"), gauge("Sandalphone", 36000, 36000, "100.0%")]
harpy = Game_Event.new([battle(31), battle(71)], "$Harpy", 0, false, 255, 10, 10)
gate = Game_Event.new([Command.new(117, [20])], "", 0, false, 255, 30, 4)
$game_map.events = { 1 => harpy, 2 => gate, 3 => Game_Event.new(nil, "$Erased", 0, false, 255, 0, 0) }
# The DLL's index of the pages: the gate's page fights 126 and 1599 through the common events it calls.
$page_troops = { 10 => [31, 71], 30 => [126, 1599] }
check("the events whose page starts a battle the rules show a bar for, through common events too",
      bar.boss_events.map { |event, troop| [event.x, troop] }, [[10, 71], [30, 1599]])
check("the DLL is asked once for the pages of the map's events, the Colosseum's common events left out", $troops_asked, [[[10, 30], 87]])
$frame += MGQ_MpRaidBar::SCAN_FRAMES
bar.boss_events
check("and not again while their pages stay", $troops_asked.size, 1)
check("the steps to a boss's event", [bar.distance_to_boss(71, 12, 13), bar.distance_to_boss(2016, 0, 0)], [3, MGQ_MpRaidBar::FAR])
check("a Raid World asks the rules once for every troop of the map's events, by the pools' rules",
      $raid_answers.asked("raid.troops").first.values_at("mode", "active", "troops"), ["pools", false, [31, 71, 126, 1599]])
$raid_answers.troops.delete(71)
$frame += MGQ_MpRaidBar::SCAN_FRAMES
check("an event whose battles the rules show no bar for gets none", bar.boss_events.map { |_event, troop| troop }, [1599])
$raid_answers.troops[71] = { "shown" => true, "keys" => ["Queen Harpy"] }
$frame += MGQ_MpRaidBar::SCAN_FRAMES
$game_variables[41] = 150
bar.map_bar(1599)
check("the map asks the DLL for a troop's bar with its pools, each enemy's own max HP at the player's difficulty and its tier's factor",
      $bar_requests.last, [:map, { "title" => "Archangel", "keys" => pool.troop_keys(1599), "enemies" => [["Metatronne", 3000], ["Sandalphone", 4500]],
                                   "factor" => MGQ_MpRaidBosses.factor(1599, :mhp), "letters" => nil }])
# The letters the game gives repeated names.
def $game_troop.letter_table; ["Ａ", "Ｂ"]; end
bar.map_bar(1599)
check("with the game's own letters when the troop knows them", $bar_requests.last[1]["letters"], ["Ａ", "Ｂ"])
$game_troop = Game_Troop.new
$game_variables[41] = 0
spriteset = Spriteset_Map.new([CharacterSprite.new(harpy, 200, 300, 48, true, 255), CharacterSprite.new(gate, 300, 50, 32, true, 255)])
spriteset.update
bars = spriteset.instance_variable_get(:@mgq_mp_raid_bars)
overhead = bars.overhead
above = overhead[harpy]
check("a bar above the boss whose event shows, following the event, under its feet where the screen has no room above",
      [overhead.size, above.root.follow.equal?(harpy), above.root.side, above.root.flip, above.root.mouse], [1, true, :above, true, false])
check("with its title and its name over a thin gauge without numbers, 240 wide for a boss of one enemy",
      [texts_of(above.root), above.parts.gauges.map { |each| [each.height, each.text] }, above.root.width], [["Tier 9 Raid Boss", "Queen Harpy"], [[8, nil]], 240])
check("no strip while a boss's event shows", bars.strip, nil)
spriteset.instance_variable_set(:@character_sprites, [CharacterSprite.new(harpy, 200, 300, 48, true, 255), CharacterSprite.new(gate, 300, 50, 32, true, 255)])
spriteset.update
check("once the map rebuilds its sprites after a transfer, the same bar still follows the event", [overhead[harpy].equal?(above), above.root.follow.equal?(harpy)], [true, true])
$game_map.events.delete(1)
$frame += MGQ_MpRaidBar::SCAN_FRAMES
spriteset.update
strip = bars.strip
check("a boss without an event that shows gets the strip, docked at the top, which the boxes at the top corners make room for",
      [overhead.size, strip.root.open?, hidden_root?(strip.root), strip.root.dock, strip.root.z, texts_of(strip.root).include?("Tab: bars")],
      [0, true, false, :top, ui::Z[:labels], false])
gate.character_name = "!Flame"
$frame += MGQ_MpRaidBar::SCAN_FRAMES
spriteset.update
check("a marker counts as the boss's sprite, and the strip hides again", [overhead.size, hidden_root?(strip.root)], [1, true])
check("the bar of a boss of several enemies is 480 wide, a name and a thin gauge per enemy",
      [overhead[gate].root.width, texts_of(overhead[gate].root), overhead[gate].parts.gauges.size], [480, ["Archangel", "Metatronne", "Sandalphone"], 2])
bar_of_gate = overhead[gate]
$raid = false
spriteset.update
check("no bars outside a Raid World's story", [overhead.size, bar_of_gate.root.open?], [0, false])
$raid = true
gate.character_name = ""
spriteset.dispose
check("every bar closes once the map's sprites go", strip.root.open?, false)

# The raid bosses outside Raid Worlds: a battle's bar by its enemies' own HP, the map's full, each
# turned off by its Mod Config row; a Raid World's bars go by the pools whatever those rows say.
tiers = MGQ_MpRaidTiers
reset
$raid = false
tiers.choose(true)
$raid_answers.pool_kinds.clear
$raid_answers.tier_kinds[71] = { "kind" => "invited" }
tiers.note_invite("troop" => "71", "tiers" => true)
BattleManager.setup(71)
$game_troop.members[0].hp = 4500
$bar_answers[[:battle, "Tier 9 Raid Boss"]] = [gauge("Queen Harpy", 4500, 6000, "75.0%")]
$bar_answers[[:map, "Tier 9 Raid Boss"]] = [gauge("Queen Harpy", 6000, 6000, "100.0%")]
check("outside a Raid World a battle whose boss fights at its tier asks for a bar of its enemies' own HP, without a pool",
      [pool.fight, flat(bar.battle_bar), $bar_requests.last[1]["enemies"]], [nil, ["Tier 9 Raid Boss", [["Queen Harpy", 4500, 6000]]], [["Queen Harpy", 4500, 6000, false, nil]]])
bar.show_bar(:battle, false)
check("none once the player turned the battle's bar off, kept in Player.ini", [bar.battle_bar, $settings["raid_bar_battle"]], [nil, false])
bar.show_bar(:battle, true)
BattleManager.setup(126)
check("nor in a battle the rules give no kind", bar.battle_bar, nil)
$game_map.events = { 1 => Game_Event.new([battle(71)], "$Harpy", 0, false, 255, 10, 10) }
check("on the map the boss's events show, with a bar of its full HP at its tier, nothing keeping it between battles",
      [bar.tier_map?, bar.boss_events.map { |_event, troop| troop }, bar.shown_troops([71]).include?(71), flat(bar.map_bar(71)), $bar_requests.last[1]["keys"]],
      [true, [71], true, ["Tier 9 Raid Boss", [["Queen Harpy", 6000, 6000]]], nil])
check("asking the rules by the tiers' rules, with the raid bosses on", $raid_answers.asked("raid.troops").last.values_at("mode", "active"), ["tiers", true])
bar.show_bar(:map, false)
$frame += MGQ_MpRaidBar::SCAN_FRAMES
check("nor any once the player turned the map's bar off, kept in Player.ini", [bar.tier_map?, bar.boss_events, $settings["raid_bar_map"]], [false, [], false])
bar.show_bar(:map, true)
tiers.choose(false)
$frame += MGQ_MpRaidBar::SCAN_FRAMES
check("nor while the raid bosses are off", [bar.tier_map?, bar.boss_events], [false, []])
$in_world = true
$raid_bosses = true
$frame += MGQ_MpRaidBar::SCAN_FRAMES
check("a Classic world with raid bosses shows them whatever single player says", [bar.tier_map?, bar.boss_events.size], [true, 1])
$raid_bosses = false
check("one without them does not", bar.tier_map?, false)
reset
$raid = true
$raid_bosses = true
bar.show_bar(:battle, false)
bar.show_bar(:map, false)
pool.note_invite("troop" => "71", "pool" => 1)
BattleManager.setup(71)
$game_troop.members[0].hp = 4500
$bar_answers[[:battle, "Tier 9 Raid Boss"]] = [gauge("Queen Harpy", 4500, 6000, "75.0%")]
$bar_answers[[:map, "Tier 9 Raid Boss"]] = [gauge("Queen Harpy", 3000, 6000, "50.0%")]
check("a Raid World's battle bar goes by its pool, the rows outside Raid Worlds off",
      [flat(bar.battle_bar), $bar_requests.last[1]["enemies"][0][4]], [["Tier 9 Raid Boss", [["Queen Harpy", 4500, 6000]]], "Queen Harpy"])
$game_map.events = { 1 => Game_Event.new([battle(71)], "$Harpy", 0, false, 255, 10, 10) }
check("and its map's bars too, by the pools, which no tier bar knows",
      [bar.tier_map?, bar.boss_events.map { |_event, troop| troop }, bar.shown_troops([71]).include?(71), flat(bar.map_bar(71)), $bar_requests.last[1]["keys"]],
      [false, [71], true, ["Tier 9 Raid Boss", [["Queen Harpy", 3000, 6000]]], ["Queen Harpy"]])
bar.show_bar(:battle, true)
bar.show_bar(:map, true)
$in_world = false
$raid_bosses = false

# The bosses' stand-ins of frozen fights, through ui_raid_freeze.rbx, which stands in here.
# A boss's stand-in: its looks and where it stands.
StandIn = Struct.new(:character_name, :tile_id, :transparent, :opacity, :x, :y)
# The frozen fights: each boss's stand-in with its troop in $freeze_targets, their sprites in
# $freeze_sprites.
module MGQ_MpRaidFreezeUi
  # The bosses' stand-ins with their troops.
  def self.bar_targets; $freeze_targets; end
  # The stand-ins' sprites of a spriteset.
  def self.sprites_of(_spriteset); $freeze_sprites; end
end
reset
$raid = true
$bar_answers[[:map, "Tier 9 Raid Boss"]] = [gauge("Queen Harpy", 6000, 6000, "100.0%")]
frozen_boss = StandIn.new("$Harpy", 0, false, 255, 20, 20)
$freeze_targets = [[frozen_boss, 71], [StandIn.new("$Slime", 0, false, 255, 1, 1), 50]]
standin_sprite = CharacterSprite.new(frozen_boss, 240, 320, 48, true, 255)
$freeze_sprites = [standin_sprite]
check("a frozen fight's boss stand-in counts as the boss's event, one whose troop shows no bar left out",
      bar.boss_events.map { |event, troop| [event.equal?(frozen_boss), troop] }, [[true, 71]])
check("the steps to the boss count its stand-in", bar.distance_to_boss(71, 22, 21), 2)
spriteset = Spriteset_Map.new([])
spriteset.update
overhead = spriteset.instance_variable_get(:@mgq_mp_raid_bars).overhead
check("the bar stands above the stand-in's sprite", [overhead.size, overhead[frozen_boss] && overhead[frozen_boss].root.follow.equal?(standin_sprite)], [1, true])
$freeze_targets = []
$freeze_sprites = []
$frame += MGQ_MpRaidBar::SCAN_FRAMES
spriteset.update
check("and goes with it", [bar.boss_events, overhead.size], [[], 0])
spriteset.dispose
