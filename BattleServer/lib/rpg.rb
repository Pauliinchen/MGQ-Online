#----------------------------------------------------------------
#  rpg.rb
#
#  Changelog:
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

# The RPG module RGSS3 builds in: the database's classes, as the RGSS3 reference defines them.
# Marshal fills their fields from the data files without calling initialize, so initialize only
# matters for objects the scripts make themselves.
module RPG
  # Something sounding: a name, a volume and a pitch.
  class AudioFile
    attr_accessor :name, :volume, :pitch

    # Creates the sound.
    #
    # @param name [String] The file's name.
    # @param volume [Integer] The volume.
    # @param pitch [Integer] The pitch.
    def initialize(name = "", volume = 100, pitch = 100)
      @name, @volume, @pitch = name, volume, pitch
    end
  end

  # Background music; nothing plays, but the last one played is kept.
  class BGM < AudioFile
    @@last = nil

    # Plays it.
    #
    # @param pos [Integer] Where to start.
    def play(pos = 0)
      @@last = name.empty? ? nil : self
      @pos = pos
    end

    # Plays it again from where it was.
    def replay
      play(@pos || 0)
    end

    # The music last played.
    #
    # @return [BGM] The music, an empty one for none.
    def self.last
      @@last || new
    end

    # Stops the music.
    def self.stop
      @@last = nil
    end

    # Fades the music out.
    def self.fade(*)
      @@last = nil
    end
  end

  # Background sound; nothing plays, but the last one played is kept.
  class BGS < AudioFile
    @@last = nil

    # Plays it.
    #
    # @param pos [Integer] Where to start.
    def play(pos = 0)
      @@last = name.empty? ? nil : self
      @pos = pos
    end

    # Plays it again from where it was.
    def replay
      play(@pos || 0)
    end

    # The sound last played.
    #
    # @return [BGS] The sound, an empty one for none.
    def self.last
      @@last || new
    end

    # Stops the sound.
    def self.stop
      @@last = nil
    end

    # Fades the sound out.
    def self.fade(*)
      @@last = nil
    end
  end

  # A music effect; nothing plays.
  class ME < AudioFile
    # Plays it.
    def play; end

    # Stops it.
    def self.stop; end

    # Fades it out.
    def self.fade(*); end
  end

  # A sound effect; nothing plays.
  class SE < AudioFile
    # Plays it.
    def play; end

    # Stops it.
    def self.stop; end
  end

  # What every database entry shares.
  class BaseItem
    attr_accessor :id, :name, :icon_index, :description, :features, :note

    # Creates the entry.
    def initialize
      @id, @name, @icon_index, @description, @features, @note = 0, "", 0, "", [], ""
    end

    # A trait of an entry.
    class Feature
      attr_accessor :code, :data_id, :value

      # Creates the trait.
      #
      # @param code [Integer] The trait's kind.
      # @param data_id [Integer] What it names.
      # @param value [Numeric] Its value.
      def initialize(code = 0, data_id = 0, value = 0)
        @code, @data_id, @value = code, data_id, value
      end
    end
  end

  # An actor.
  class Actor < BaseItem
    attr_accessor :nickname, :class_id, :initial_level, :max_level, :character_name,
                  :character_index, :face_name, :face_index, :equips

    # Creates the actor.
    def initialize
      super
      @nickname, @class_id, @initial_level, @max_level = "", 1, 1, 99
      @character_name, @character_index, @face_name, @face_index = "", 0, "", 0
      @equips = [0, 0, 0, 0, 0]
    end
  end

  # A class.
  class Class < BaseItem
    attr_accessor :exp_params, :params, :learnings

    # Creates the class.
    def initialize
      super
      @exp_params, @params, @learnings = [30, 20, 30, 30], Table.new(8, 100), []
    end

    # The total EXP a level needs, by the class's EXP curve.
    #
    # @param level [Integer] The level.
    # @return [Integer] The EXP.
    def exp_for_level(level)
      lv = level.to_f
      basis = @exp_params[0].to_f
      extra = @exp_params[1].to_f
      acc_a = @exp_params[2].to_f
      acc_b = @exp_params[3].to_f
      (basis * ((lv - 1)**(0.9 + acc_a / 250)) * lv * (lv + 1) /
        (6 + lv**2 / 50 / acc_b) + (lv - 1) * extra).round.to_i
    end

    # A skill a class learns at a level.
    class Learning
      attr_accessor :level, :skill_id, :note

      # Creates the learning.
      def initialize
        @level, @skill_id, @note = 1, 1, ""
      end
    end
  end

  # What skills and items share.
  class UsableItem < BaseItem
    attr_accessor :scope, :occasion, :speed, :success_rate, :repeats, :tp_gain, :hit_type,
                  :animation_id, :damage, :effects

    # Creates the entry.
    def initialize
      super
      @scope, @occasion, @speed, @success_rate, @repeats, @tp_gain, @hit_type = 0, 0, 0, 100, 1, 0, 0
      @animation_id, @damage, @effects = 0, Damage.new, []
    end

    # @return [Boolean] Whether it targets enemies.
    def for_opponent?
      [1, 2, 3, 4, 5, 6].include?(@scope)
    end

    # @return [Boolean] Whether it targets allies.
    def for_friend?
      [7, 8, 9, 10, 11].include?(@scope)
    end

    # @return [Boolean] Whether it targets fallen allies.
    def for_dead_friend?
      [9, 10].include?(@scope)
    end

    # @return [Boolean] Whether it targets its user.
    def for_user?
      @scope == 11
    end

    # @return [Boolean] Whether it targets one.
    def for_one?
      [1, 3, 7, 9, 11].include?(@scope)
    end

    # @return [Boolean] Whether it targets at random.
    def for_random?
      [3, 4, 5, 6].include?(@scope)
    end

    # @return [Integer] How many random targets it takes.
    def number_of_targets
      for_random? ? @scope - 2 : 0
    end

    # @return [Boolean] Whether it targets everyone of a side.
    def for_all?
      [2, 8, 10].include?(@scope)
    end

    # @return [Boolean] Whether its user picks a target.
    def need_selection?
      [1, 7, 9].include?(@scope)
    end

    # @return [Boolean] Whether it works in battle.
    def battle_ok?
      [0, 1].include?(@occasion)
    end

    # @return [Boolean] Whether it works from the menu.
    def menu_ok?
      [0, 2].include?(@occasion)
    end

    # @return [Boolean] Whether it always hits.
    def certain?
      @hit_type == 0
    end

    # @return [Boolean] Whether it is a physical attack.
    def physical?
      @hit_type == 1
    end

    # @return [Boolean] Whether it is a magical attack.
    def magical?
      @hit_type == 2
    end

    # The damage a skill or item deals.
    class Damage
      attr_accessor :type, :element_id, :formula, :variance, :critical

      # Creates the damage.
      def initialize
        @type, @element_id, @formula, @variance, @critical = 0, 0, "0", 20, false
      end

      # @return [Boolean] Whether it deals none.
      def none?
        @type == 0
      end

      # @return [Boolean] Whether it changes HP.
      def to_hp?
        [1, 3, 5].include?(@type)
      end

      # @return [Boolean] Whether it changes MP.
      def to_mp?
        [2, 4, 6].include?(@type)
      end

      # @return [Boolean] Whether it heals.
      def recover?
        [3, 4].include?(@type)
      end

      # @return [Boolean] Whether it drains.
      def drain?
        [5, 6].include?(@type)
      end

      # @return [Integer] -1 for healing, else 1.
      def sign
        recover? ? -1 : 1
      end

      # Works out the formula; a broken one deals 0.
      #
      # @param a [Game_Battler] The user.
      # @param b [Game_Battler] The target.
      # @param v [Game_Variables] The game's variables.
      # @return [Numeric] The damage.
      def eval(a, b, v)
        [Kernel.eval(@formula), 0].max * sign rescue 0
      end
    end

    # An effect of a skill or item.
    class Effect
      attr_accessor :code, :data_id, :value1, :value2

      # Creates the effect.
      #
      # @param code [Integer] The effect's kind.
      # @param data_id [Integer] What it names.
      # @param value1 [Numeric] Its first value.
      # @param value2 [Numeric] Its second value.
      def initialize(code = 0, data_id = 0, value1 = 0, value2 = 0)
        @code, @data_id, @value1, @value2 = code, data_id, value1, value2
      end
    end
  end

  # A skill.
  class Skill < UsableItem
    attr_accessor :stype_id, :mp_cost, :tp_cost, :message1, :message2, :required_wtype_id1,
                  :required_wtype_id2

    # Creates the skill.
    def initialize
      super
      @scope = 1
      @stype_id, @mp_cost, @tp_cost, @message1, @message2 = 1, 0, 0, "", ""
      @required_wtype_id1 = @required_wtype_id2 = 0
    end
  end

  # An item.
  class Item < UsableItem
    attr_accessor :itype_id, :price, :consumable

    # Creates the item.
    def initialize
      super
      @itype_id, @price, @consumable = 1, 0, true
    end

    # @return [Boolean] Whether it is a key item.
    def key_item?
      @itype_id == 2
    end
  end

  # What weapons and armors share.
  class EquipItem < BaseItem
    attr_accessor :price, :etype_id, :params

    # Creates the equipment.
    def initialize
      super
      @price, @etype_id, @params = 0, 0, [0] * 8
    end
  end

  # A weapon.
  class Weapon < EquipItem
    attr_accessor :wtype_id, :animation_id

    # Creates the weapon.
    def initialize
      super
      @wtype_id, @animation_id = 0, 0
      @features = [Feature.new(31, 1, 0), Feature.new(22, 0, 0)]
    end

    # How strong it is, for picking the best one.
    #
    # @return [Integer] Its attack and magic twice, its other stats once.
    def performance
      params[2] + params[4] + params.inject(0) { |sum, value| sum + value }
    end
  end

  # An armor.
  class Armor < EquipItem
    attr_accessor :atype_id

    # Creates the armor.
    def initialize
      super
      @atype_id, @etype_id = 0, 1
      @features = [Feature.new(22, 1, 0)]
    end

    # How strong it is, for picking the best one.
    #
    # @return [Integer] Its defense and magic defense twice, its other stats once.
    def performance
      params[3] + params[5] + params.inject(0) { |sum, value| sum + value }
    end
  end

  # An enemy.
  class Enemy < BaseItem
    attr_accessor :battler_name, :battler_hue, :params, :exp, :gold, :drop_items, :actions

    # Creates the enemy.
    def initialize
      super
      @battler_name, @battler_hue = "", 0
      @params = [100, 0, 10, 10, 10, 10, 10, 10]
      @exp, @gold = 0, 0
      @drop_items = Array.new(3) { DropItem.new }
      @actions = [Action.new]
      @features = [Feature.new(22, 0, 0.95), Feature.new(22, 1, 0.05), Feature.new(31, 1, 0)]
    end

    # An item an enemy may drop.
    class DropItem
      attr_accessor :kind, :data_id, :denominator

      # Creates the drop.
      def initialize
        @kind, @data_id, @denominator = 0, 1, 1
      end
    end

    # An action an enemy may take.
    class Action
      attr_accessor :skill_id, :condition_type, :condition_param1, :condition_param2, :rating

      # Creates the action.
      def initialize
        @skill_id, @condition_type, @condition_param1, @condition_param2, @rating = 1, 0, 0, 0, 5
      end
    end
  end

  # A state.
  class State < BaseItem
    attr_accessor :restriction, :priority, :remove_at_battle_end, :remove_by_restriction,
                  :auto_removal_timing, :min_turns, :max_turns, :remove_by_damage,
                  :chance_by_damage, :remove_by_walking, :steps_to_remove, :message1, :message2,
                  :message3, :message4

    # Creates the state.
    def initialize
      super
      @restriction, @priority = 0, 50
      @remove_at_battle_end = @remove_by_restriction = @remove_by_damage = @remove_by_walking = false
      @auto_removal_timing, @min_turns, @max_turns = 0, 1, 1
      @chance_by_damage, @steps_to_remove = 100, 100
      @message1 = @message2 = @message3 = @message4 = ""
    end
  end

  # A troop of enemies and its battle events.
  class Troop
    attr_accessor :id, :name, :members, :pages

    # Creates the troop.
    def initialize
      @id, @name, @members, @pages = 0, "", [], [Page.new]
    end

    # An enemy of a troop.
    class Member
      attr_accessor :enemy_id, :x, :y, :hidden

      # Creates the member.
      def initialize
        @enemy_id, @x, @y, @hidden = 1, 0, 0, false
      end
    end

    # A battle event page.
    class Page
      attr_accessor :condition, :span, :list

      # Creates the page.
      def initialize
        @condition, @span, @list = Condition.new, 0, [RPG::EventCommand.new]
      end

      # When a battle event page runs.
      class Condition
        attr_accessor :turn_ending, :turn_valid, :enemy_valid, :actor_valid, :switch_valid,
                      :turn_a, :turn_b, :enemy_index, :enemy_hp, :actor_id, :actor_hp,
                      :switch_id

        # Creates the condition.
        def initialize
          @turn_ending = @turn_valid = @enemy_valid = @actor_valid = @switch_valid = false
          @turn_a, @turn_b, @enemy_index, @enemy_hp = 0, 0, 0, 50
          @actor_id, @actor_hp, @switch_id = 1, 50, 1
        end
      end
    end
  end

  # A battle animation.
  class Animation
    attr_accessor :id, :name, :animation1_name, :animation1_hue, :animation2_name,
                  :animation2_hue, :position, :frame_max, :frames, :timings

    # Creates the animation.
    def initialize
      @id, @name, @animation1_name, @animation1_hue, @animation2_name, @animation2_hue = 0, "", "", 0, "", 0
      @position, @frame_max, @frames, @timings = 1, 1, [Frame.new], []
    end

    # @return [Boolean] Whether it plays over the whole screen.
    def to_screen?
      @position == 3
    end

    # A frame of an animation.
    class Frame
      attr_accessor :cell_max, :cell_data

      # Creates the frame.
      def initialize
        @cell_max, @cell_data = 0, Table.new(0, 0)
      end
    end

    # A sound or flash of an animation.
    class Timing
      attr_accessor :frame, :se, :flash_scope, :flash_color, :flash_duration

      # Creates the timing.
      def initialize
        @frame, @se, @flash_scope, @flash_color, @flash_duration = 0, RPG::SE.new("", 80), 0, Color.new(255, 255, 255, 255), 5
      end
    end
  end

  # A tileset.
  class Tileset
    attr_accessor :id, :mode, :name, :tileset_names, :flags, :note

    # Creates the tileset.
    def initialize
      @id, @mode, @name, @tileset_names, @flags, @note = 0, 1, "", Array.new(9, ""), Table.new(8192), ""
    end
  end

  # A common event.
  class CommonEvent
    attr_accessor :id, :name, :trigger, :switch_id, :list

    # Creates the common event.
    def initialize
      @id, @name, @trigger, @switch_id, @list = 0, "", 0, 1, [RPG::EventCommand.new]
    end

    # @return [Boolean] Whether it runs on its own while its switch is on.
    def autorun?
      @trigger == 1
    end

    # @return [Boolean] Whether it runs alongside while its switch is on.
    def parallel?
      @trigger == 2
    end
  end

  # A command of an event.
  class EventCommand
    attr_accessor :code, :indent, :parameters

    # Creates the command.
    #
    # @param code [Integer] The command's kind.
    # @param indent [Integer] Its depth.
    # @param parameters [Array] Its values.
    def initialize(code = 0, indent = 0, parameters = [])
      @code, @indent, @parameters = code, indent, parameters
    end
  end

  # A move route.
  class MoveRoute
    attr_accessor :repeat, :skippable, :wait, :list

    # Creates the route.
    def initialize
      @repeat, @skippable, @wait, @list = true, false, false, [RPG::MoveCommand.new]
    end
  end

  # A command of a move route.
  class MoveCommand
    attr_accessor :code, :parameters

    # Creates the command.
    #
    # @param code [Integer] The command's kind.
    # @param parameters [Array] Its values.
    def initialize(code = 0, parameters = [])
      @code, @parameters = code, parameters
    end
  end

  # A map.
  class Map
    attr_accessor :display_name, :tileset_id, :width, :height, :scroll_type, :specify_battleback,
                  :battleback1_name, :battleback2_name, :autoplay_bgm, :bgm, :autoplay_bgs, :bgs,
                  :disable_dashing, :encounter_list, :encounter_step, :parallax_name,
                  :parallax_loop_x, :parallax_loop_y, :parallax_sx, :parallax_sy, :parallax_show,
                  :note, :data, :events

    # Creates the map.
    #
    # @param width [Integer] The width in tiles.
    # @param height [Integer] The height in tiles.
    def initialize(width = 17, height = 13)
      @display_name, @tileset_id, @width, @height, @scroll_type = "", 1, width, height, 0
      @specify_battleback, @battleback1_name, @battleback2_name = false, "", ""
      @autoplay_bgm, @bgm, @autoplay_bgs, @bgs = false, RPG::BGM.new, false, RPG::BGS.new("", 80)
      @disable_dashing, @encounter_list, @encounter_step = false, [], 30
      @parallax_name, @parallax_loop_x, @parallax_loop_y = "", false, false
      @parallax_sx = @parallax_sy = 0
      @parallax_show, @note = false, ""
      @data, @events = Table.new(width, height, 4), {}
    end

    # A troop a map's random encounters may bring.
    class Encounter
      attr_accessor :troop_id, :weight, :region_set

      # Creates the encounter.
      def initialize
        @troop_id, @weight, @region_set = 1, 10, []
      end
    end
  end

  # A map's place in the map tree.
  class MapInfo
    attr_accessor :name, :parent_id, :order, :expanded, :scroll_x, :scroll_y

    # Creates the entry.
    def initialize
      @name, @parent_id, @order, @expanded, @scroll_x, @scroll_y = "", 0, 0, false, 0, 0
    end
  end

  # An event on a map.
  class Event
    attr_accessor :id, :name, :x, :y, :pages

    # Creates the event.
    #
    # @param x [Integer] Its column.
    # @param y [Integer] Its row.
    def initialize(x = 0, y = 0)
      @id, @name, @x, @y, @pages = 0, "", x, y, [Page.new]
    end

    # A page of a map event.
    class Page
      attr_accessor :condition, :graphic, :move_type, :move_speed, :move_frequency, :move_route,
                    :walk_anime, :step_anime, :direction_fix, :through, :priority_type, :trigger,
                    :list

      # Creates the page.
      def initialize
        @condition, @graphic = Condition.new, Graphic.new
        @move_type, @move_speed, @move_frequency, @move_route = 0, 3, 3, RPG::MoveRoute.new
        @walk_anime, @step_anime, @direction_fix, @through = true, false, false, false
        @priority_type, @trigger, @list = 0, 0, [RPG::EventCommand.new]
      end

      # When a map event page applies.
      class Condition
        attr_accessor :switch1_valid, :switch2_valid, :variable_valid, :self_switch_valid,
                      :item_valid, :actor_valid, :switch1_id, :switch2_id, :variable_id,
                      :variable_value, :self_switch_ch, :item_id, :actor_id

        # Creates the condition.
        def initialize
          @switch1_valid = @switch2_valid = @variable_valid = @self_switch_valid = false
          @item_valid = @actor_valid = false
          @switch1_id = @switch2_id = @variable_id = @item_id = @actor_id = 1
          @variable_value, @self_switch_ch = 0, "A"
        end
      end

      # How a map event page looks.
      class Graphic
        attr_accessor :tile_id, :character_name, :character_index, :direction, :pattern

        # Creates the look.
        def initialize
          @tile_id, @character_name, @character_index, @direction, @pattern = 0, "", 0, 2, 0
        end
      end
    end
  end

  # The game's system settings.
  class System
    attr_accessor :game_title, :version_id, :japanese, :party_members, :currency_unit,
                  :elements, :skill_types, :weapon_types, :armor_types, :switches, :variables,
                  :boat, :ship, :airship, :title1_name, :title2_name, :opt_draw_title,
                  :opt_use_midi, :opt_transparent, :opt_followers, :opt_slip_death,
                  :opt_floor_death, :opt_display_tp, :opt_extra_exp, :window_tone, :title_bgm,
                  :battle_bgm, :battle_end_me, :gameover_me, :sounds, :test_battlers,
                  :test_troop_id, :start_map_id, :start_x, :start_y, :terms, :battleback1_name,
                  :battleback2_name, :battler_name, :battler_hue, :edit_map_id

    # A vehicle's settings.
    class Vehicle
      attr_accessor :character_name, :character_index, :bgm, :start_map_id, :start_x, :start_y
    end

    # The game's words.
    class Terms
      attr_accessor :basic, :params, :etypes, :commands
    end

    # An actor of the battle test.
    class TestBattler
      attr_accessor :actor_id, :level, :equips
    end
  end
end
