#----------------------------------------------------------------
#  screen_cases.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Runs a case of fixtures/screen/screen.json through ScreenPrototype (screen_prototype.rb) and
# writes what it showed as the case holds it, for make_fixtures.rb. A recording tool: no test runs
# against it.

require "json"
require_relative "screen_prototype"

module ScreenPrototype
  # The cases: their worlds and facts, run through the prototype.
  module Cases
    # A world of the list, as Directory::ListedWorld.
    Listed = Struct.new(:id, :seats, :online, :creator_id, :active, :creator_name, :name, :start, :members, :hidden, :choose, :open, :featured, :strict, :data, :mods, :description, :mod_hashes, :settings,
                        :type, :share, :difficulty, :other_mods_off, :squad, :raid_bosses, :mods_unread) do
      # Tells whether it is a Raid World.
      #
      # @return [Boolean] Whether it is.
      def raid?
        type == "raid"
      end
    end

    # A player of a world, as Directory::Member.
    Member = Struct.new(:id, :online, :name)

    # A world on this PC: its folder, when it was last played, whether it holds a save and whether
    # world.ini keeps it as a Raid World.
    Local = Struct.new(:id, :played_at, :latest_save, :raid)

    # A required mod this game has in another version or lacks, as MGQ_MpWorldMods::Row.
    Row = Struct.new(:name, :yours, :text)

    # A world as the screen lists it, as MGQ_MpWorld::Entry.
    Entry = Struct.new(:id, :name, :listed, :local, :favourite, :gone) do
      # Tells whether it is featured.
      #
      # @return [Boolean] Whether it is.
      def featured?
        !listed.nil? && listed.featured
      end

      # Tells whether it is a Raid World.
      #
      # @return [Boolean] Whether it is.
      def raid?
        listed ? listed.raid? : (!local.nil? && local.raid)
      end

      # Tells whether it has no password.
      #
      # @return [Boolean] Whether it has none.
      def open?
        !listed.nil? && listed.open
      end

      # Tells whether its password is known.
      #
      # @return [Boolean] Whether it is.
      def password_known?
        !local.nil?
      end
    end

    # When a world was last played, which writes the day the case names.
    class Played
      # Keeps the day.
      #
      # @param day [String] The day as yyyy-MM-dd.
      def initialize(day)
        @day = day
      end

      # Writes the day.
      #
      # @param _format [String] The format, which is always the day's.
      # @return [String] The day.
      def strftime(_format)
        @day
      end
    end

    # What a case's world reads beyond it, from the case.
    class Facts
      # Keeps the case's facts and the world rules.
      #
      # @param facts [Hash] The case's facts.
      # @param rules [Hash] The world rules, as fixtures/world/rules.json holds them.
      def initialize(facts, rules)
        @facts = facts
        @rules = rules
      end

      # Names the parts of the game data that differ.
      #
      # @return [String] The case's text.
      def data_text(_parts, _named)
        @facts["differing_text"]
      end

      # Lists the required mods that differ.
      #
      # @return [Array<Row>] The case's rows.
      def rows(_listed)
        @facts["rows"].map { |row| Row.new(row["name"], row["yours"], row["text"]) }
      end

      # Writes the details' line of the shared settings.
      #
      # @return [String] The case's line.
      def settings_text(_listed, _me)
        @facts["settings_text"]
      end

      # Tells whether the settings are shared.
      #
      # @return [Boolean] The case's answer.
      def shared?(_text)
        @facts["shared"]
      end

      # Lists the player's mods a world turns off.
      #
      # @param listed [Listed] The world.
      # @return [Array<Array>, nil] The case's mods, none for a world that allows other mods.
      def turned_off(listed)
        listed.other_mods_off ? @facts["turned_off"] : []
      end

      # Tells whether a mod's script is installed.
      #
      # @param name [String] The mod's name.
      # @return [Boolean] Whether the case names it.
      def installed?(name)
        @facts["installed"].include?(name)
      end

      # Names a difficulty.
      #
      # @param value [Integer] The difficulty.
      # @return [String, nil] Its name.
      def difficulty_name(value)
        found = @rules["difficulties"].find { |entry| entry[0] == value }
        found && found[1]
      end

      # Names a Formation size.
      #
      # @param value [Integer] The size.
      # @return [String] Its name.
      def formation_name(value)
        found = @rules["formations"].find { |size, _| size == value.to_i }
        found ? found[1] : value.to_i.to_s
      end

      # Gives the squad rules of a Raid World that names none.
      #
      # @return [Hash] The rules.
      def default_squad
        Cases.squad_of(@rules["squad"])
      end

      # Lists the hidden worlds the player added.
      #
      # @return [Array<String>] Their ids.
      def added
        @facts["added"]
      end

      # Tells what of the game data differs.
      #
      # @param entry [Entry] The world.
      # @return [Array<String>, nil] The case's parts, nil for a world the list lacks.
      def differing(entry)
        entry.listed.nil? ? nil : @facts["differing"]
      end
    end

    # The facts a case leaves as they are.
    FACTS = { "differing" => [], "differing_text" => "", "installed" => [], "rows" => [], "settings_text" => "Mod settings: the creator's own", "shared" => false, "turned_off" => [], "added" => [] }

    # The world rules, as fixtures/world/rules.json holds them.
    RULES = JSON.parse(File.read(File.expand_path("../world/rules.json", __dir__), :encoding => "UTF-8"))["rules"]

    # Reads squad rules.
    #
    # @param values [Hash, nil] The rules by their names in the DLL's answers.
    # @return [Hash, nil] The rules by their keys in the scripts.
    def self.squad_of(values)
      values && { :luka => values["luka"], :formation => values["formation"], :front => values["front"], :raid_front => values["raid_front"] }
    end

    # Makes a case's world of the list.
    #
    # @param world [Hash] The world as the case holds it.
    # @return [Listed] The world.
    def self.listed_of(world)
      Listed.new(*Listed.members.map do |field|
        case field
        when :members then world["members"].map { |id, online, name| Member.new(id, online, name) }
        when :squad then squad_of(world["squad"])
        else world[field.to_s]
        end
      end)
    end

    # Runs a case through the prototype.
    #
    # @param entry [Hash] The case: its worlds and facts.
    # @return [Hash] What the prototype showed: "row", "played", "panels", "actions", "players" and "mods".
    def self.run(entry)
      facts = Facts.new(FACTS.merge(entry["facts"]), RULES)
      about = entry["local"]
      local = about && Local.new(about["id"], about["played"] && Played.new(about["played"]), about["latest_save"], about["raid"])
      world = entry["listed"] && listed_of(entry["listed"])
      struct = Entry.new(world ? world.id : "w9", world ? world.name : "On this PC", world, local, entry["favourite"], entry["gone"])
      shown(Model.new(struct, entry["me"], entry["admin"], facts), struct, entry["me"], facts)
    end

    # Writes what the prototype shows of a world.
    #
    # @param model [Model] The prototype pointed at the world.
    # @param entry [Object] The world.
    # @param me [String] The player's id.
    # @param facts [Object] What the world reads beyond it.
    # @return [Hash] "row", "played", "panels", "actions", "players" and "mods".
    def self.shown(model, entry, me, facts)
      model.draw_item(0)
      model.on_world
      listed = entry.listed
      {
        "row" => { "text" => model.drawn["text"], "count" => model.drawn["count"], "color" => model.drawn["color"].to_s, "dim" => model.drawn["dim"] },
        "played" => model.played_text(entry.local),
        "panels" => model.panels(entry, me).map { |panel| panel_value(panel) },
        "actions" => model.offered.call.map { |label, symbol, enabled| [label, symbol.to_s, enabled.nil? ? true : enabled] },
        "players" => listed ? model.player_lines(listed.members).map { |line| line_value(line) } : [],
        "mods" => listed ? model.mod_lines(listed.mods, facts.differing(entry), facts.rows(listed), facts.turned_off(listed)).map { |line| line_value(line) } : [],
      }
    end

    # Writes a panel as the case holds it.
    #
    # @param panel [Model::Panel] The panel.
    # @return [Hash] Its values.
    def self.panel_value(panel)
      { "title" => panel.title, "note" => panel.note, "target" => panel.target && panel.target.to_s, "rows" => panel.rows.map { |row| row.map { |cell| cell_value(cell) } } }
    end

    # Writes a cell as the case holds it.
    #
    # @param cell [Model::Cell, nil] The cell.
    # @return [Hash, nil] Its values.
    def self.cell_value(cell)
      return nil unless cell

      chip_colors = cell.chip_colors && cell.chip_colors.map { |text, color| [text, color.to_s] }
      { "label" => cell.label, "text" => cell.text, "color" => cell.color.to_s, "target" => cell.target && cell.target.to_s, "chips" => cell.chips, "chip_colors" => chip_colors }
    end

    # Writes a list box line as the case holds it.
    #
    # @param line [Array] The line.
    # @return [Array] Its parts, symbols as texts.
    def self.line_value(line)
      line.map { |part| part.is_a?(Symbol) ? part.to_s : part }
    end
  end
end
