#----------------------------------------------------------------
#  form_prototype.rb
#
#  Changelog:
#      Paulinchen  2026-10-30: Dropped Allow data mismatch and Update current data scan, as WorldForms did
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# The world screen's forms as world.rbx held them before their schema moved to WorldForms in
# MGQOnline.Game (commit 410dca74, MGQ_MpWorld::Form), kept unchanged as FormPrototype::Form but for
# the game data's fields, which went once the game data was compared only as the player enters: the
# source make_fixtures.rb records world.json from. A recording tool: no test runs against it.

require "json"

# The prototype, with the rules of a world's settings as fixtures/world/rules.json holds them in
# place of the DLL's.
module FormPrototype
  # The rules the prototype reads.
  RULES = JSON.parse(File.read(File.expand_path("../world/rules.json", __dir__)))["rules"]

  # The longest name.
  MAX_NAME_CHARS = 16

  # The longest password.
  MAX_PASSWORD_CHARS = 20

  # The longest description.
  MAX_DESCRIPTION_CHARS = 1000

  # Lines of the description a form shows at once.
  DESCRIPTION_LINES = 4

  # Lines of the description a Raid World's form shows at once.
  RAID_DESCRIPTION_LINES = 2

  # A world's id.
  WORLD_ID = /\A[0-9a-f]{32}\z/

  # A Classic world.
  CLASSIC = "classic"

  # A Raid World.
  RAID = "raid"

  # The world types, in the order the form offers them.
  TYPES = [CLASSIC, RAID]

  # How a Raid World shares companions.
  SHARING = ["off", "story", "all"]

  # What the form calls each way of sharing companions.
  SHARING_NAMES = ["Off", "Story companions", "Story + battle recruits"]

  class << self
    # Whether Discord told the player's name, for the name form.
    attr_accessor :discord
  end

  # @return [Integer] The fewest seats.
  def self.min_seats
    RULES["seats"]["min"]
  end

  # @return [Integer] The most seats.
  def self.max_seats
    RULES["seats"]["max"]
  end

  # @return [Integer] The seats of a new world.
  def self.default_seats
    RULES["seats"]["default"]
  end

  # @return [Array<Integer>] The difficulties.
  def self.difficulties
    RULES["difficulties"].map { |value, _| value }
  end

  # @return [Array<String>] Their names.
  def self.difficulty_names
    RULES["difficulties"].map { |_, name| name }
  end

  # @return [Integer] The difficulty offered first.
  def self.default_difficulty
    RULES["difficulty"]
  end

  # @return [Array<Integer>] The Formation sizes.
  def self.formations
    RULES["formations"].map { |size, _| size }
  end

  # @return [Array<Integer>] The Frontline's places.
  def self.fronts
    RULES["fronts"]
  end

  # @param value [Integer] A Formation size.
  # @return [String] Its name.
  def self.formation_name(value)
    found = RULES["formations"].find { |size, _| size == value.to_i }
    found ? found[1] : value.to_i.to_s
  end

  # @return [Hash] The squad rules of a world that names none.
  def self.default_squad
    squad_of(RULES["squad"])
  end

  # @param squad [Hash, nil] Squad rules by their names in the DLL's answers.
  # @return [Hash, nil] The rules by symbols.
  def self.squad_of(squad)
    squad && { :luka => squad["luka"], :formation => squad["formation"], :front => squad["front"], :raid_front => squad["raid_front"] }
  end

  # @param value [Integer, nil] A difficulty.
  # @return [String, nil] Its name.
  def self.difficulty_name(value)
    index = difficulties.index(value)
    index ? difficulty_names[index] : nil
  end

  # @return [Boolean] Whether Discord told the player's name.
  def self.discord_name?
    @discord == true
  end

  # @param text [String, nil] A world's settings.
  # @return [Boolean] Whether it shares them.
  def self.shared?(text)
    !text.to_s.strip.empty?
  end

  class Form
    # What the lines at the top say on Shared Mod Settings.
    SHARED_HINT = "Ticked: every player plays with your mod options here. Unticked: each keeps their own."

    # What the lines at the top say on Turn off other mods.
    OTHER_MODS_HINT = "Ticked: mods the world does not name are off in it. Personal mods stay on."

    # What the lines at the top say on Turn off other mods in the edit form.
    EDIT_OTHER_MODS_HINT = "Ticked: mods the world does not name are off. Personal mods stay on. Players in it enter again."

    # What the lines at the top say on the world type.
    TYPE_HINT = "Classic: each party plays its own story. Raid: the whole world plays one. Fixed once created."

    # What the lines at the top say on Sharing companions.
    SHARING_HINT = "Raid only: companions everyone gets on reaching their level. Fixed once created."

    # What the lines at the top say on Raid Bosses.
    RAID_BOSSES_HINT = "Classic only: story bosses fight as raid bosses of their tier, far stronger. Changeable later."

    # What the lines at the top say on Raid Bosses in the edit form.
    EDIT_RAID_BOSSES_HINT = "Story bosses fight as raid bosses of their tier, far stronger, from each player's next boss fight."

    # What the lines at the top say on the difficulty.
    DIFFICULTY_HINT = "Every player of the world plays on it. You can change it later in the edit form."

    # What the lines at the top say on the difficulty in a Raid World's edit form.
    EDIT_DIFFICULTY_HINT = "Every player of the world plays on it, those in it now at once."

    # The edit form's first outcome of the difficulty for a Raid World that sets none, whose players
    # keep their own while it stays picked.
    PER_PLAYER = "Per player"

    # Width of the world type's label, narrower than a text box's, so the switch fits half a row.
    TYPE_LABEL_WIDTH = 70

    # Width of a Save label that shares its row, narrower than a text box's, so the save's name fits half a row.
    RAID_SAVE_LABEL_WIDTH = 40

    # Width of the squad rules' switch labels, narrower than a text box's, so Original fits half a row.
    SQUAD_LABEL_WIDTH = 80

    # What the button that opens the form of a Raid World's squad rules says.
    LIMITS_LABEL = "Set formation limits"

    # What the lines at the top say on the button of a Raid World's squad rules.
    LIMITS_HINT = "Luka, the team size and the Frontlines every player keeps. Changeable later too."

    # What the lines at the top say on the button that leaves the form of a Raid World's squad rules.
    DONE_HINT = "Back to the world's form. Cancel goes back too, keeping the limits."

    # What the lines at the top say on Luka Replaceable.
    LUKA_HINT = "Ticked: players may take Luka out of their team. Unticked: he always stays in it."

    # What the lines at the top say on the Formation size.
    FORMATION_HINT = "The team size every player keeps. Its last place sits out, except with Original, the game's own."

    # What the lines at the top say on the Frontline in regular fights.
    FRONT_HINT = "In front in regular fights, the rest on the Backline. With more players, each one's first fights."

    # What the lines at the top say on the Frontline in raids.
    RAID_FRONT_HINT = "In front in raid boss fights, the rest on the Backline. With more players, each one's first fights."

    # What the lines at the top say on a Raid World's Shared save.
    RAID_SAVE_HINT = "New players start from one of your saves, the world's story from its point. Fixed once created."

    # A field of a form: a text box (:text, :password, :number or :id), a box of several lines (:area), a checkbox (:check), a save
    # to choose (:save), the mods picked in the mod picker (:mods), a switch between several outcomes (:switch) or a button
    # (:button).
    class Field
      # What the form keeps the field's value under.
      attr_reader :key

      # What kind of field it is.
      attr_reader :kind

      # What the field is called.
      attr_reader :label

      # The row it is on, 0 for the first below the form's title.
      attr_reader :row

      # :left or :right when it shares its row with another field, nil when it has the row alone.
      attr_reader :side

      # The longest text a text box takes.
      attr_reader :max_chars

      # The characters a text box takes, nil for any.
      attr_reader :allowed

      # The checkbox that must be ticked for the field to be used, or a block called with the form that
      # tells whether it may, nil for neither.
      attr_reader :needs

      # Whether a text box may stay empty, or a save stay unchosen.
      attr_reader :optional

      # The heading of the panel it is in, nil for a field outside every panel.
      attr_reader :group

      # How many lines a box of several lines shows.
      attr_reader :lines

      # What the lines at the top of the world screen say while the cursor is on the field.
      attr_reader :hint

      # Tells whether a text box may stay empty right now, nil when only optional decides.
      attr_reader :empty_ok

      # Why a text box that must be filled in is refused while empty.
      attr_reader :empty_text

      # The outcomes a switch moves between, as shown.
      attr_reader :choices

      # Tells a switch's line below its outcome, such as what the outcome picked brings: called with
      # the form and the outcome's index, nil for no line.
      attr_reader :note

      # Width of a switch's or a save's label, nil for the width its window gives every label.
      attr_reader :label_width

      # A block called with the form that tells whether the field is part of it now, nil for always.
      attr_reader :shows

      # Creates a field.
      #
      # @param key [Symbol] What the form keeps its value under.
      # @param kind [Symbol] What kind of field it is.
      # @param label [String] What it is called.
      # @param row [Integer] The row it is on.
      # @param hint [String] What the lines at the top say while the cursor is on it.
      # @param options [Hash] Whichever of :side, :max_chars, :allowed, :needs (a key or a proc), :optional (also for a save), :group, :lines,
      #   :empty_ok (a proc), :empty_text, :choices, :note (a proc), :label_width and :shows (a proc) apply.
      def initialize(key, kind, label, row, hint, options = {})
        @key = key
        @kind = kind
        @label = label
        @row = row
        @hint = hint
        @side = options[:side]
        @max_chars = options[:max_chars]
        @allowed = options[:allowed]
        @needs = options[:needs]
        @optional = options[:optional] == true
        @group = options[:group]
        @lines = options[:lines] || 1
        @empty_ok = options[:empty_ok]
        @empty_text = options[:empty_text] || "This field cannot be empty."
        @choices = options[:choices] || []
        @note = options[:note]
        @label_width = options[:label_width]
        @shows = options[:shows]
      end

      # Tells the line below a switch's outcome.
      #
      # @param form [Form] The form, whose other fields the line may follow.
      # @return [String] The line, empty for none.
      def note_of(form)
        @note ? @note.call(form, form[@key].to_i).to_s : ""
      rescue
        ""
      end

      # Tells whether the text box may stay empty.
      #
      # @return [Boolean] Whether it may.
      def may_be_empty?
        @optional || (@empty_ok ? (@empty_ok.call ? true : false) : false)
      end

      # Tells whether the field is a text box, typed into.
      #
      # @return [Boolean] Whether it is.
      def typed?
        [:text, :password, :number, :id, :area].include?(@kind)
      end
    end

    # The form of a new world.
    #
    # @return [Form] The form, empty but for the default seats.
    def self.create
      fields = [
        Field.new(:name, :text, "Name", 0, "The name everyone sees in the list.", :max_chars => MAX_NAME_CHARS, :group => "World", :empty_text => "The world needs a name."),
        Field.new(:password, :password, "Password", 1, "Typed once to enter the world. Left empty, anyone may enter.", :max_chars => MAX_PASSWORD_CHARS, :side => :left, :group => "World"),
        Field.new(:seats, :number, "Max Players", 1, "Players in the world at once, #{FormPrototype.min_seats} to #{FormPrototype.max_seats}.", :max_chars => FormPrototype.max_seats.to_s.size, :allowed => /\A\d\z/, :side => :right, :group => "World"),
        Field.new(:hidden, :check, "Hidden", 2, "Only its players see it in the list. Others add it with its id.", :side => :left, :group => "World"),
        Field.new(:type, :switch, "World type", 2, TYPE_HINT, :side => :right, :group => "World", :choices => ["Classic", "Raid"], :label_width => TYPE_LABEL_WIDTH),
        # Raid only and Classic only, each shown for its type, so the form keeps to one page.
        Field.new(:share, :switch, "Sharing companions", 3, SHARING_HINT, :group => "World", :choices => SHARING_NAMES,
                  :shows => lambda { |form| form.type == RAID }),
        Field.new(:from_save, :check, "Shared save", 3, "Classic only: new players start from one of your saves. Fixed once created.", :side => :left, :group => "World",
                  :shows => lambda { |form| form.type == CLASSIC }),
        Field.new(:choose, :check, "Player's choice", 3, "Classic only: new players pick their start, the opening or a save. Fixed once created.", :side => :right, :group => "World",
                  :shows => lambda { |form| form.type == CLASSIC }),
        # A Classic world shares the row between its Save and Raid Bosses, so the form keeps to one page.
        Field.new(:save, :save, "Save", 4, "The save every new player starts from.", :side => :left, :group => "World", :label_width => RAID_SAVE_LABEL_WIDTH,
                  :needs => lambda { |form| form.from_save? }, :shows => lambda { |form| form.type == CLASSIC }),
        Field.new(:raid_bosses, :check, "Raid Bosses", 4, RAID_BOSSES_HINT, :side => :right, :group => "World", :shows => lambda { |form| form.type == CLASSIC }),
        # A Raid World's Shared save shares its row with the Difficulty and its Save with the button of
        # its squad rules, whose row comes off the description, so the form keeps to one page.
        Field.new(:from_save, :check, "Shared save", 4, RAID_SAVE_HINT, :side => :left, :group => "World",
                  :shows => lambda { |form| form.type == RAID }),
        Field.new(:difficulty, :switch, "Difficulty", 4, DIFFICULTY_HINT, :side => :right, :group => "World", :choices => FormPrototype.difficulty_names,
                  :label_width => TYPE_LABEL_WIDTH, :shows => lambda { |form| form.type == RAID }),
        Field.new(:save, :save, "Save", 5, "The save every new player starts from.", :side => :left, :group => "World", :label_width => RAID_SAVE_LABEL_WIDTH,
                  :needs => lambda { |form| form.from_save? }, :shows => lambda { |form| form.type == RAID }),
        limits_field(5, :right, lambda { |form| form.type == RAID }),
        Field.new(:mods, :mods, "Mods", 6, "The mods of the world: listed, required to enter or essential. Enter picks them.", :group => "Game data"),
        Field.new(:shared, :check, "Shared Mod Settings", 7, SHARED_HINT, :group => "Game data"),
        Field.new(:other_mods_off, :check, "Turn off other mods", 8, OTHER_MODS_HINT, :group => "Game data"),
        # The row of a Raid World's Save comes off its description, so the form keeps to one page.
        Field.new(:description, :area, "What the world is about", 9, "Shown in the world's details. Optional.", :max_chars => MAX_DESCRIPTION_CHARS, :optional => true, :lines => DESCRIPTION_LINES, :group => "Description",
                  :shows => lambda { |form| form.type != RAID }),
        Field.new(:description, :area, "What the world is about", 9, "Shown in the world's details. Optional.", :max_chars => MAX_DESCRIPTION_CHARS, :optional => true, :lines => RAID_DESCRIPTION_LINES,
                  :group => "Description", :shows => lambda { |form| form.type == RAID }),
        Field.new(:confirm, :button, "Create the world", 10, "Creates the world. You enter it from the list."),
      ]
      new("Create a new world", fields, { :name => "", :password => "", :seats => FormPrototype.default_seats.to_s, :hidden => false, :type => 0, :share => 0, :from_save => false, :save => nil, :choose => false, :description => "", :mods => "",
                                          :shared => false, :difficulty => FormPrototype.difficulties.index(FormPrototype.default_difficulty), :other_mods_off => false, :raid_bosses => false }.merge(squad_values(FormPrototype.default_squad)))
    end

    # The button of a Raid World's form that opens the form of its squad rules, see limits.
    #
    # @param row [Integer] Its row.
    # @param side [Symbol, nil] :left or :right when it shares the row, nil when it has the row alone.
    # @param shows [Proc, nil] The block that tells whether it is part of the form now, nil for always.
    # @return [Field] The button.
    def self.limits_field(row, side, shows = nil)
      Field.new(:limits, :button, LIMITS_LABEL, row, LIMITS_HINT, :side => side, :group => "World", :shows => shows)
    end

    # The fields of the form of a Raid World's squad rules, on three rows: Luka Replaceable beside the
    # Formation size, the Frontline in regular fights beside the one in raids, and the button back.
    #
    # @return [Array<Field>] The fields.
    def self.limits_fields
      [
        Field.new(:luka, :check, "Luka Replaceable", 0, LUKA_HINT, :side => :left, :group => "Team"),
        Field.new(:formation, :switch, "Formation Size", 0, FORMATION_HINT, :side => :right, :group => "Team", :choices => FormPrototype.formations.map { |size| FormPrototype.formation_name(size) }, :label_width => SQUAD_LABEL_WIDTH),
        Field.new(:front, :switch, "Frontline", 1, FRONT_HINT, :side => :left, :group => "Team", :choices => FormPrototype.fronts.map { |place| place.to_s }, :label_width => SQUAD_LABEL_WIDTH),
        Field.new(:raid_front, :switch, "Raid Frontline", 1, RAID_FRONT_HINT, :side => :right, :group => "Team", :choices => FormPrototype.fronts.map { |place| place.to_s }, :label_width => SQUAD_LABEL_WIDTH),
        Field.new(:done, :button, "Done", 2, DONE_HINT),
      ]
    end

    # What the squad rules' fields hold at first for squad rules.
    #
    # @param squad [Hash] The rules, see FormPrototype.squad.
    # @return [Hash] The values by the fields' keys.
    def self.squad_values(squad)
      { :luka => squad[:luka] ? true : false, :formation => FormPrototype.formations.index(squad[:formation]).to_i, :front => FormPrototype.fronts.index(squad[:front]).to_i,
        :raid_front => FormPrototype.fronts.index(squad[:raid_front]).to_i }
    end

    # The form that changes a world, for its creator or an admin: what may change after it was made.
    #
    # @param listed [Directory::ListedWorld] The world in the directory.
    # @param own [Boolean] Whether the player made the world, and so may replace its game data and
    #   choose whether it shares their mod settings.
    # @return [Form] The form, filled in as the world is; a Raid World's with its difficulty and the
    #   button of its squad rules below the seats, the difficulty first PER_PLAYER for one that sets none.
    def self.edit(listed, own = false)
      fields = [
        Field.new(:seats, :number, "Max Players", 0, "Players in the world at once, #{FormPrototype.min_seats} to #{FormPrototype.max_seats}.", :max_chars => FormPrototype.max_seats.to_s.size, :allowed => /\A\d\z/, :group => "World"),
        Field.new(:mods, :mods, "Mods", 2, "The mods of the world: listed, required to enter or essential. Enter picks them.", :group => "Game data"),
        Field.new(:other_mods_off, :check, "Turn off other mods", 5, EDIT_OTHER_MODS_HINT, :group => "Game data"),
        Field.new(:description, :area, "What the world is about", 6, "Shown in the world's details. Optional.", :max_chars => MAX_DESCRIPTION_CHARS, :optional => true, :lines => DESCRIPTION_LINES, :group => "Description"),
        Field.new(:confirm, :button, "Save the changes", 7, "Changes the world for everyone."),
      ]
      if own
        fields.insert(2, Field.new(:shared, :check, "Shared Mod Settings", 4, SHARED_HINT, :group => "Game data"))
      end
      choices = listed.difficulty.nil? ? [PER_PLAYER] + FormPrototype.difficulty_names : FormPrototype.difficulty_names
      if listed.type == RAID
        fields.insert(1, Field.new(:difficulty, :switch, "Difficulty", 1, EDIT_DIFFICULTY_HINT, :side => :left, :group => "World", :choices => choices, :label_width => TYPE_LABEL_WIDTH),
                      limits_field(1, :right))
      else
        fields.insert(1, Field.new(:raid_bosses, :check, "Raid Bosses", 1, EDIT_RAID_BOSSES_HINT, :group => "World"))
      end
      new("Edit #{listed.name}", fields, { :seats => listed.seats.to_s, :mods => listed.mods.to_s, :description => listed.description.to_s, :shared => FormPrototype.shared?(listed.settings),
                                           :difficulty => choices.index(FormPrototype.difficulty_name(listed.difficulty) || PER_PLAYER),
                                           :other_mods_off => listed.other_mods_off ? true : false, :raid_bosses => listed.raid_bosses ? true : false }.merge(squad_values(listed.squad || FormPrototype.default_squad)))
    end

    # The form of the name the others see.
    #
    # @param name [String] The name as it is, "" for none.
    # @return [Form] The form, filled in with the name.
    def self.rename(name)
      fields = [
        Field.new(:name, :text, "Your name", 0, "The name the others see. Without one, your name on Discord.", :max_chars => MAX_NAME_CHARS, :group => "Player",
                  :empty_ok => lambda { FormPrototype.discord_name? }, :empty_text => "Type a name: Discord has not told yours yet."),
        Field.new(:confirm, :button, "Use this name", 1, "Keeps the name for every world."),
      ]
      new("Your name", fields, :name => name)
    end

    # The form of a world's password, which enters it.
    #
    # @param name [String] The world's name.
    # @return [Form] The form, empty.
    def self.password(name)
      fields = [
        Field.new(:password, :password, "Password", 0, "The password the world's creator gave you.", :max_chars => MAX_PASSWORD_CHARS, :group => "World"),
        Field.new(:confirm, :button, "Enter the world", 1, "Opens the world with the password."),
      ]
      new("Enter #{name}", fields, :password => "")
    end

    # The form that adds a hidden world to the list by its id.
    #
    # @return [Form] The form, empty.
    def self.join
      fields = [
        Field.new(:id, :id, "World id", 0, "The id the world's creator copied for you. Ctrl+V pastes it.", :max_chars => 32, :allowed => /\A[0-9a-f]\z/i, :group => "World"),
        Field.new(:confirm, :button, "Add the world", 1, "Adds the world to your list, where you enter it like any other."),
      ]
      new("Add a hidden world", fields, :id => "")
    end

    # What the form is called.
    attr_reader :title

    # Lists the fields that are part of the form now, in the order the cursor visits them.
    #
    # @return [Array<Field>] The fields.
    def fields
      @fields.select { |field| field.shows.nil? || field.shows.call(self) }
    end

    # The key of the text box being typed into, nil while none is.
    attr_accessor :editing

    # The editor of the text box being typed into, nil while none is.
    attr_accessor :edit

    # Creates a form.
    #
    # @param title [String] What the form is called.
    # @param fields [Array<Field>] The fields.
    # @param values [Hash] What each field holds at first, by key.
    def initialize(title, fields, values)
      @title = title
      @fields = fields
      @values = values
    end

    # Reads what a field holds.
    #
    # @param key [Symbol] The field's key.
    # @return [Object] The value.
    def [](key)
      @values[key]
    end

    # Sets what a field holds.
    #
    # @param key [Symbol] The field's key.
    # @param value [Object] The value.
    def []=(key, value)
      @values[key] = value
    end

    # Tells whether a field can be used, which one whose checkbox is not ticked, or whose block says
    # no, cannot.
    #
    # @param field [Field] The field.
    # @return [Boolean] Whether it can.
    def enabled?(field)
      return true if field.needs.nil?
      return field.needs.call(self) ? true : false if field.needs.respond_to?(:call)

      @values[field.needs] == true
    end

    # Tells the world type the new world's form picks.
    #
    # @return [String] One of TYPES.
    def type
      TYPES[@values[:type].to_i] || CLASSIC
    end

    # Tells how the new world's form has a Raid World share companions.
    #
    # @return [String] One of SHARING; "off" for a Classic world.
    def share
      type == RAID ? SHARING[@values[:share].to_i] || SHARING[0] : SHARING[0]
    end

    # Tells the difficulty the form picks.
    #
    # @return [Integer, nil] One of FormPrototype.difficulties; nil for PER_PLAYER.
    def difficulty
      field = @fields.find { |candidate| candidate.key == :difficulty }
      name = field ? field.choices[@values[:difficulty].to_i] : nil
      index = FormPrototype.difficulty_names.index(name)
      return FormPrototype.difficulties[index] if index

      name == PER_PLAYER ? nil : FormPrototype.default_difficulty
    end

    # The form of the squad rules this form picks, which holds the same values, so whatever it
    # changes this form keeps.
    #
    # @return [Form] The form, the same one each time.
    def limits
      @limits ||= Form.new("Formation limits", Form.limits_fields, @values)
    end

    # Tells the squad rules the form picks.
    #
    # @return [Hash] The rules, see FormPrototype.squad.
    def squad
      default = FormPrototype.default_squad || {}
      { :luka => @values[:luka] == true, :formation => FormPrototype.formations[@values[:formation].to_i] || default[:formation],
        :front => FormPrototype.fronts[@values[:front].to_i] || default[:front], :raid_front => FormPrototype.fronts[@values[:raid_front].to_i] || default[:raid_front] }
    end

    # Tells whether the new world's form has new players start from one of the creator's saves, with
    # Shared save ticked.
    #
    # @return [Boolean] Whether it does.
    def from_save?
      @values[:from_save] == true
    end

    # Tells whether the form has a Classic world's story bosses fight as raid bosses.
    #
    # @return [Boolean] Whether it does; false for a Raid World.
    def raid_bosses?
      type == CLASSIC && @values[:raid_bosses] == true
    end

    # Tells whether the new world's form lets each new player choose where to start, which only a
    # Classic world does.
    #
    # @return [Boolean] Whether it does.
    def choose?
      type == CLASSIC && @values[:choose] == true
    end

    # Moves a switch to its next or its previous outcome, round.
    #
    # @param field [Field] The switch.
    # @param step [Integer] 1 for the next outcome, -1 for the previous.
    # @return [Integer] The outcome's index now.
    def turn(field, step)
      count = [field.choices.size, 1].max
      @values[field.key] = (@values[field.key].to_i + step) % count
      follow_type if field.key == :type
      @values[field.key]
    end

    # Ticks a checkbox, or unticks it, which from then on keeps what the player chose.
    #
    # @param key [Symbol] The checkbox's key.
    # @return [Boolean] Whether it is ticked now.
    def tick(key)
      @ticked = (@ticked || []) | [key]
      @values[key] = !@values[key]
    end

    # Ticks Turn off other mods for a Raid World and unticks it for a Classic one, unless the player
    # ticked or unticked it themselves.
    def follow_type
      return if !@values.key?(:other_mods_off) || (@ticked || []).include?(:other_mods_off)

      @values[:other_mods_off] = type == RAID
    end

    # Tells whether the form turns off every mod the world does not name.
    #
    # @return [Boolean] Whether it does.
    def other_mods_off?
      @values[:other_mods_off] == true
    end

    # Checks what a text box holds, and tidies it.
    #
    # @param field [Field] The text box.
    # @param text [String] What it holds.
    # @return [Array] The tidied text, and why it is not accepted, nil when it is.
    def check(field, text)
      case field.kind
      when :number
        seats = text =~ /\A\d+\z/ ? text.to_i : nil
        return [text, "#{field.label} must be a number from #{FormPrototype.min_seats} to #{FormPrototype.max_seats}."] unless seats && seats.between?(FormPrototype.min_seats, FormPrototype.max_seats)

        [seats.to_s, nil]
      when :id
        id = text.strip.downcase
        id =~ WORLD_ID ? [id, nil] : [text, "That is not a world id. Copy it again from the world's creator."]
      when :password
        # A password keeps its spaces, since the others type it exactly, and may be empty.
        [text, nil]
      else
        tidy = text.strip
        tidy.empty? && !field.may_be_empty? ? [text, field.empty_text] : [tidy, nil]
      end
    end

    # Finds the first field that keeps the form from being sent.
    #
    # @return [Array, nil] The field's index and why, nil when the form can be sent.
    def problem
      fields.each_with_index do |field, index|
        next unless enabled?(field)

        error = field.typed? ? check(field, @values[field.key])[1] : nil
        error ||= "Choose the save its players start from." if field.kind == :save && !field.optional && @values[field.key].nil?
        return [index, error] if error
      end
      nil
    end
  end

  # A listed world as the edit form reads it.
  LISTED = Struct.new(:name, :seats, :mods, :description, :settings, :difficulty, :type, :other_mods_off, :raid_bosses, :squad)

  # The names of the characters a text box takes.
  ALLOWED = { /\A\d\z/ => "digits", /\A[0-9a-f]\z/i => "hex" }

  # Opens a form as a case names it.
  #
  # @param request [Hash] "kind" and what that form opens with.
  # @return [FormPrototype::Form] The form.
  def self.open(request)
    self.discord = request["discord"] == true
    form = FormPrototype::Form
    case request["kind"]
    when "create" then form.create
    when "join" then form.join
    when "password" then form.password(request["name"])
    when "rename" then form.rename(request["name"])
    when "edit"
      world = request["world"]
      listed = LISTED.new(world["name"], world["seats"], world["mods"], world["description"], world["settings"], world["difficulty"], world["type"],
                          world["other_mods_off"], world["raid_bosses"], squad_of(world["squad"]))
      form.edit(listed, request["own"] == true)
    end
  end

  # Runs a case's actions on a form; a step "page" goes on in the form of the squad rules.
  #
  # @param form [FormPrototype::Form] The form.
  # @param steps [Array<Array>] The actions.
  # @return [FormPrototype::Form] The form the last action was on.
  def self.act(form, steps)
    steps.each do |step|
      case step[0]
      when "turn" then form.turn(form.fields.find { |field| field.key.to_s == step[1] }, step[2])
      when "tick" then form.tick(step[1].to_sym)
      when "set" then form[step[1].to_sym] = step[2]
      when "page" then form = form.limits
      end
    end
    form
  end

  # Writes down what a form shows and adds up to.
  #
  # @param form [FormPrototype::Form] The form.
  # @return [Hash] Its title, fields, values, derived values and first problem.
  def self.view_of(form)
    fields = form.fields.map do |field|
      { "key" => field.key.to_s, "kind" => field.kind.to_s, "label" => field.label, "row" => field.row, "side" => field.side && field.side.to_s,
        "max_chars" => field.max_chars, "allowed" => field.allowed && ALLOWED.fetch(field.allowed), "optional" => field.optional, "group" => field.group,
        "lines" => field.lines, "hint" => field.hint, "choices" => field.choices, "label_width" => field.label_width, "enabled" => form.enabled?(field) }
    end
    values = {}
    form.instance_variable_get(:@values).each { |key, value| values[key.to_s] = value }
    squad = form.squad
    derived = { "type" => form.type, "share" => form.share, "difficulty" => form.difficulty, "from_save" => form.from_save?, "choose" => form.choose?,
                "raid_bosses" => form.raid_bosses?, "other_mods_off" => form.other_mods_off?,
                "squad" => { "luka" => squad[:luka], "formation" => squad[:formation], "front" => squad[:front], "raid_front" => squad[:raid_front] } }
    problem = form.problem
    { "title" => form.title, "fields" => fields, "values" => values, "derived" => derived, "problem" => problem && [form.fields[problem[0]].key.to_s, problem[1]] }
  end
end
