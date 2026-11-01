#----------------------------------------------------------------
#  screen_prototype.rb
#
#  Changelog:
#      Paulinchen  2026-10-30: Told that the game data is compared as the player enters
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# What world_screen.rbx showed of a world before the world screen's model moved to WorldScreenModel
# in MGQOnline.Game, kept as it was: its methods copied unchanged but for what they asked the other
# scripts, which they ask a facts object instead (see Model#initialize), and for the game data's row
# and the essential mods' marks, which follow the DLL since it compares the game data only once the
# world's mods loaded. make_fixtures.rb records
# fixtures/screen/screen.json from it, and the script tests answer the screen.* topics through it,
# checked against that file as GameScript/Tests/screen_support.rb loads.
module ScreenPrototype
  # What the screen says while nothing else happened.
  HINT = "Up and down pick the worlds or the commands, confirm moves into them. Right arrow on a world: its details."

  # What follows the name of a world just created or added, once the cursor is on it.
  ENTER_HINT = "Confirm to enter it."

  # What the screen says while an action runs, by the action's kind.
  BUSY_TEXTS = {
    "create" => "Creating the world . . .",
    "unlock" => "Opening the world . . .",
    "delete" => "Deleting the world . . .",
    "ban" => "Removing the player . . .",
    "edit" => "Saving the changes . . .",
    "find" => "Looking for the world . . .",
    "data" => "Updating the game data . . .",
    "start" => "Fetching the starting save . . .",
    "mods" => "Downloading the mods . . .",
    "settings" => "Saving the mod settings . . .",
    "read" => "Reading the world's mods . . .",
  }

  # What the right end of a mod's row says, by how it is named.
  MOD_STATE_LABELS = { :unlisted => "unlisted", :listed => "listed", :required => "required", :essential => "essential" }

  # The color of a mod's row, by how it is named: a required one red and an essential one gold,
  # near the red and orange of its buttons.
  MOD_STATE_COLORS = { :unlisted => :grey, :listed => :plain, :required => :bad, :essential => :gold }

  # Splits the mods a world needs, as its creator wrote them, at each semicolon. A mod written
  # with an exclamation mark in front is required, one with a question mark essential.
  #
  # @param text [String, nil] The mods as written.
  # @return [Array<String>] Each mod's name: the required ones first, then the essential ones, none for an empty text.
  def self.mods_of(text)
    names = text.to_s.split(";").map { |mod| mod.strip.sub(/\A[!?]\s*/, "") }.reject { |mod| mod.empty? }
    required = required_mods(text)
    essential = essential_mods(text)
    (names & required) + (names & essential) + (names - required - essential)
  end

  # Lists the mods a world's creator marked as required, with an exclamation mark in front: a
  # game needs their script to enter, see installed_mod?.
  #
  # @param text [String, nil] The mods as written.
  # @return [Array<String>] Their names.
  def self.required_mods(text)
    marked_mods(text, /!/)
  end

  # Lists the mods a world's creator marked as essential, with a question mark in front: they
  # stand out, but nothing is looked for, since a mod of data files has no script.
  #
  # @param text [String, nil] The mods as written.
  # @return [Array<String>] Their names.
  def self.essential_mods(text)
    marked_mods(text, /\?/)
  end

  # Lists the names of the mods written with a mark in front, without the mark.
  #
  # @param text [String, nil] The mods as written.
  # @param mark [Regexp] The mark.
  # @return [Array<String>] Their names.
  def self.marked_mods(text, mark)
    text.to_s.split(";").map { |mod| mod.strip[/\A#{mark}\s*(\S.*)\z/, 1] }.compact
  end

  # The world screen's choices, list row, details and list box lines of one world.
  class Model
    # A group of rows under a heading, as Window_MpWorldDetail::Panel.
    Panel = Struct.new(:title, :note, :rows, :target)

    # A value on a darker box, as Window_MpWorldDetail::Cell.
    Cell = Struct.new(:label, :text, :color, :target, :chips, :chip_colors)

    # What the details call each way a Raid World shares companions.
    SHARING_TEXTS = { "off" => "None", "story" => "Story", "all" => "Story, recruits" }

    # Places of the players' panel.
    NAMED_PLAYERS = 4

    # Most parts of the game data a row names before it counts the rest.
    NAMED_PARTS = 2

    # Width kept free at the right of a world's name for its players online and seats.
    COUNT_WIDTH = 52

    # What draw_item drew: "text", "count", "color" (:raid, :featured, :favourite or :normal) and "dim".
    attr_reader :drawn

    # What on_world offered.
    attr_reader :offered

    # Points the model at a world.
    #
    # @param entry [Object] The world: id, name, listed, local, favourite, gone, raid?, featured?, open?, password_known?.
    # @param me [String] The player's id.
    # @param admin [Boolean] Whether the player is one of the relay's admins.
    # @param facts [Object] What the methods asked the other scripts: data_text, rows, settings_text, shared?, turned_off,
    #   installed?, difficulty_name, formation_name, default_squad, added, differing.
    def initialize(entry, me, admin, facts)
      @list = [{ :ext => entry }]
      @list_window = Struct.new(:current_ext).new(entry)
      @me = me
      @admin = admin
      @facts = facts
      @drawn = {}
      chosen = nil
      @actions_window = Object.new
      @actions_window.define_singleton_method(:start) { |commands| chosen = commands }
      @offered = lambda { chosen }
    end

    # Logs nothing.
    def log_screen(_line); end

    # Names nothing.
    def entry_text; ""; end

    # Gives a row's rectangle.
    def item_rect_for_text(_index); Struct.new(:width).new(200); end

    # Notes the colour and whether the row is dim.
    def change_color(color, enabled = true); @drawn["color"] = color; @drawn["dim"] = !enabled; end

    # Names the favourite's colour.
    def crisis_color; :favourite; end

    # Names the plain colour.
    def normal_color; :normal; end

    # Notes a text: the count at the right, the name at the left.
    def draw_text(_rect, text, align = 0); align == 2 ? @drawn["count"] = text : @drawn["text"] = text; end

    # Lists what the panels say about a world.
    #
    # @param entry [MGQ_MpWorld::Entry] The world.
    # @param me [String] The player's id.
    # @return [Array<Panel>] The panels, from the top.
    def panels(entry, me)
      listed = entry.listed
      return [Panel.new("World", nil, [[Cell.new("Status", entry.gone ? "Only on this PC: deleted, or you were removed" : "Not in the list right now", :normal)]])] unless listed

      [world_panel(entry, me), data_panel(entry, me), players_panel(listed, me)]
    end

    # Tells who made a world, how full it is, how it is entered, where its new players start, for a
    # Raid World its type, how it shares companions, its difficulty and its squad rules, and for a
    # Classic world whose story bosses fight as raid bosses that they do.
    #
    # A Classic world gets no type row and a raid bosses row only while they are on, since every row
    # takes a line from the description below.
    #
    # @param entry [MGQ_MpWorld::Entry] The world, which the directory lists.
    # @param me [String] The player's id.
    # @return [Panel] The panel.
    def world_panel(entry, me)
      listed = entry.listed
      rows = [
        [Cell.new("Creator", listed.creator_id == me ? "You" : listed.creator_name, :normal), Cell.new("Players", "#{listed.online} / #{listed.seats} online", :normal)],
        [Cell.new("Password", password_text(entry), :normal), Cell.new("Listed", listed.hidden ? "Hidden" : "Public", :normal)],
      ]
      rows << type_row(listed) if listed.raid?
      rows << (listed.raid? ? start_row(listed) : [Cell.new("Start", start_text(listed), :normal)])
      rows.concat(squad_rows(listed)) if listed.raid?
      rows << [Cell.new("Raid Bosses", "On: story bosses of their tier", :normal)] if !listed.raid? && listed.raid_bosses
      Panel.new("World", listed.featured ? "featured" : nil, rows)
    end

    # Tells how a world's password stands for the player: none, known since this PC entered the
    # world once, or needed.
    #
    # @param entry [MGQ_MpWorld::Entry] The world, which the directory lists.
    # @return [String] "None", "Known" or "Needed".
    def password_text(entry)
      if entry.open? then "None"
      elsif entry.password_known? then "Known"
      else "Needed"
      end
    end

    # Tells the mods a world needs, its mod settings, whether it turns other mods off, and that the
    # player's game data is compared with its creator's as they enter.
    #
    # @param entry [MGQ_MpWorld::Entry] The world, which the directory lists.
    # @param me [String, nil] The player's id, whose game data becomes that of a world of their own.
    # @return [Panel] The panel.
    def data_panel(entry, me = nil)
      listed = entry.listed
      mods = ScreenPrototype.mods_of(listed.mods)
      differing = nil
      game = Cell.new("Your game", listed.creator_id == me ? "Becomes the world's as you enter" : "Compared with the creator's as you enter", :normal)
      note = "differing games are warned"
      return Panel.new("Game data", note, [[Cell.new("Mods", "Reading . . .", :normal)], [game]]) if listed.mods_unread

      colors = mod_colors(listed.mods, differing, @facts.rows(listed))
      settings = Cell.new(nil, @facts.settings_text(listed, me), @facts.shared?(listed.settings) ? :gold : :normal)
      other_mods = Cell.new(nil, other_mods_text(listed), listed.other_mods_off ? :warn : :normal)
      Panel.new("Game data", note, [[Cell.new("Mods", mods.empty? ? "No mod named" : mods.join(", "), :normal, mods.empty? ? nil : :mods, mods.empty? ? nil : mods, colors)], [settings], [other_mods], [game]])
    end

    # Tells whether a world turns other mods off, and how many of the player's.
    #
    # @param listed [MGQ_MpWorld::Directory::ListedWorld] The world in the directory.
    # @return [String] Such as "Other mods: turned off (2 of yours)" or "Other mods: allowed".
    def other_mods_text(listed)
      return "Other mods: allowed" unless listed.other_mods_off

      mods = @facts.turned_off(listed)
      mods.nil? || mods.empty? ? "Other mods: turned off" : "Other mods: turned off (#{mods.size} of yours)"
    end

    # Tells how the details and the list box mark a world's marked mods: a required one in the color
    # of what is fine while this game has its script in the world's version, in gold in another
    # version, and in the color of what is wrong while it lacks it; an essential one in the color of
    # what is fine while this game's data matches the world's, and in gold otherwise.
    #
    # @param text [String, nil] The mods as the world's creator wrote them.
    # @param differing [Array<String>, nil] What of this game's data differs from the world's, nil when it is not compared.
    # @param rows [Array<MGQ_MpWorldMods::Row>, nil] The required mods this game has in another version or lacks.
    # @return [Hash] Each marked mod's color (:good, :gold or :bad) and what the list box says of it, by the mod's name.
    def mod_marks(text, differing = nil, rows = nil)
      marks = {}
      ScreenPrototype.required_mods(text).each do |mod|
        row = rows && rows.find { |candidate| candidate.name == mod }
        marks[mod] = if row && row.yours != "not installed"
                       [:gold, "required, #{row.text.sub(/\A[^:]*: /, '')}"]
                     elsif @facts.installed?(mod)
                       [:good, "required, installed"]
                     else
                       [:bad, "required, missing"]
                     end
      end
      ScreenPrototype.essential_mods(text).each do |mod|
        marks[mod] = [:gold, "essential, checked as you enter"]
      end
      marks
    end

    # Tells the colors of a world's marked mods, see mod_marks.
    #
    # @param text [String, nil] The mods as the world's creator wrote them.
    # @param differing [Array<String>, nil] What of this game's data differs from the world's.
    # @param rows [Array<MGQ_MpWorldMods::Row>, nil] The required mods this game has in another version or lacks.
    # @return [Hash] The color by the mod's name.
    def mod_colors(text, differing = nil, rows = nil)
      colors = {}
      mod_marks(text, differing, rows).each { |mod, mark| colors[mod] = mark[0] }
      colors
    end

    # Names a world's players, those online first as the directory lists them, two to a row.
    #
    # @param listed [MGQ_MpWorld::Directory::ListedWorld] The world in the directory.
    # @param me [String] The player's id.
    # @return [Panel] The panel.
    def players_panel(listed, me)
      members = listed.members
      named = members.size > NAMED_PLAYERS ? members.first(NAMED_PLAYERS - 1) : members
      cells = named.map { |member| Cell.new(nil, member.id == me ? "#{member.name} (you)" : member.name, member.online ? :good : :normal) }
      cells.push(Cell.new(nil, "and #{members.size - named.size} more", :normal)) if named.size < members.size
      rows = []
      cells.each_slice(2) { |pair| rows.push(pair.size == 2 ? pair : pair + [nil]) }
      Panel.new("Players", "#{members.size} joined", rows, :players)
    end

    # Tells that a world is a Raid World and how it shares companions.
    #
    # @param listed [MGQ_MpWorld::Directory::ListedWorld] The Raid World in the directory.
    # @return [Array<Cell>] The row's two cells.
    def type_row(listed)
      [Cell.new("Type", "Raid", :raid), Cell.new("Sharing", SHARING_TEXTS[listed.share] || SHARING_TEXTS["off"], :normal)]
    end

    # Tells where a Raid World's new players start, and the difficulty every player plays on.
    #
    # @param listed [MGQ_MpWorld::Directory::ListedWorld] The Raid World in the directory.
    # @return [Array<Cell>] The row's two cells.
    def start_row(listed)
      [Cell.new("Start", raid_start_text(listed), :normal), Cell.new("Difficulty", @facts.difficulty_name(listed.difficulty) || "Per player", :normal)]
    end

    # Tells a Raid World's squad rules: whether Luka may leave a team, the Formation size, and the
    # Frontline in regular fights and in raids.
    #
    # @param listed [MGQ_MpWorld::Directory::ListedWorld] The Raid World in the directory.
    # @return [Array<Array<Cell>>] The two rows.
    def squad_rows(listed)
      squad = listed.squad || @facts.default_squad
      [[Cell.new("Luka", squad[:luka] ? "Replaceable" : "Fixed", :normal), Cell.new("Formation", @facts.formation_name(squad[:formation]), :normal)],
       [Cell.new("Frontline", "#{squad[:front]} | #{squad[:raid_front]}  (regular | raids)", :normal)]]
    end

    # Tells where a Raid World's new players start: at the beginning, or from the creator's save.
    #
    # @param listed [MGQ_MpWorld::Directory::ListedWorld] The Raid World in the directory.
    # @return [String] The text.
    def raid_start_text(listed)
      return start_text(listed) if listed.start == "pending"

      listed.start == "ready" ? "The creator's save" : "The beginning"
    end

    # Tells where a world's new players start.
    #
    # @param listed [MGQ_MpWorld::Directory::ListedWorld] The world in the directory.
    # @return [String] The text.
    def start_text(listed)
      return "Its creator is still setting it up" if listed.start == "pending"
      return "Your choice: beginning, own or creator's save" if listed.choose && listed.start == "ready"
      return "Your choice: beginning or own save" if listed.choose
      return "The creator's save" if listed.start == "ready"

      "The beginning"
    end

    # Tells when the player last played a world.
    #
    # @param world [MGQ_MpWorld::World, nil] The world on this PC, nil before the player entered it.
    # @return [String] The text.
    def played_text(world)
      return "not entered yet" unless world

      world.played_at ? "last played #{world.played_at.strftime('%Y-%m-%d')}" : "entered, not played yet"
    end

    # Draws a world with its players online and seats, a Raid World in red, a featured one in gold, a
    # favourite with a mark, and one its creator deleted pale.
    #
    # @param index [Integer] The row.
    def draw_item(index)
      entry = @list[index][:ext]
      rect = item_rect_for_text(index)
      change_color(entry.raid? ? :raid : entry.featured? ? :featured : entry.favourite ? crisis_color : normal_color, !entry.gone)
      draw_text(rect, "#{entry.listed.online}/#{entry.listed.seats}", 2) if entry.listed
      rect.width -= COUNT_WIDTH if entry.listed
      draw_text(rect, entry.favourite ? "* #{entry.name}" : entry.name)
    end

    # Opens what can be done with the chosen world, which the player chose rather than the start
    # after a restart.
    def on_world
      @rejoin_entering = false
      @entry = @list_window.current_ext
      @data_accepted = false
      listed = @entry.listed
      creator = listed && listed.creator_id == @me
      commands = []
      commands.push(["Enter the world", :enter]) if listed || @entry.local
      commands.push([@entry.favourite ? "No longer a favourite" : "Mark as a favourite", :favourite]) if @entry.id
      commands.push(["Copy the world id", :copy_id]) if creator && listed.hidden
      commands.push(["Remove from my list", :forget]) if @entry.local.nil? && @facts.added.include?(@entry.id)
      commands.push(["Edit the world", :edit_world]) if listed && (creator || @admin)
      commands.push(["Remove a player", :ban, listed.members.size > 1]) if creator
      commands.push(["Delete the world for everyone", :delete_world]) if creator || (listed && @admin)
      commands.push(["Copy my latest save to my game", :export_save]) if @entry.local && @entry.local.latest_save
      commands.push(["Delete my saves of it", :delete_saves]) if @entry.local
      commands.push(["Back", :cancel])
      log_screen("picked #{entry_text}: #{listed ? "#{listed.online}/#{listed.seats} online, start #{listed.start}" : 'not listed'}, " \
                 "#{@entry.local ? "folder #{@entry.local.id}" : 'never entered'}#{creator ? ', own world' : ''}#{@admin ? ', as an admin' : ''}; " \
                 "offers #{commands.map { |command| command[1] }.join(', ')}")
      @actions_window.start(commands)
    end

    # Writes the list box's lines for a world's players: those online, then the others.
    #
    # @param members [Array<MGQ_MpWorld::Directory::Member>] Everyone who ever joined.
    # @return [Array<Array>] The lines, each [:head, text] or [:item, text, color, note], as screen.box hands them out.
    def player_lines(members)
      online = members.select { |member| member.online }
      lines = []

      [["Online", online, :good], ["Offline", members - online, :grey]].each do |heading, group, color|
        next if group.empty?

        lines.push([:head, "#{heading} (#{group.size})"])
        group.each { |member| lines.push([:item, member.id == @me ? "#{member.name} (you)" : member.name, color, heading.downcase]) }
      end
      lines
    end

    # Writes the list box's lines for the mods a world needs: the required ones first, then the
    # essential ones, each marked as Window_MpWorldDetail.mod_marks says, then the listed ones; and
    # for a world that turns other mods off, the player's mods it turns off.
    #
    # @param text [String, nil] The mods as the world's creator wrote them.
    # @param differing [Array<String>, nil] What of this game's data differs from the world's, see MGQ_MpWorld::Entry#differing.
    # @param rows [Array<MGQ_MpWorldMods::Row>, nil] The required mods this game has in another version or lacks, see MGQ_MpWorldMods.differing.
    # @param turned_off [Array<Array>, nil] The player's mods the world turns off with their scripts counted, see MGQ_MpModParking.turned_off_mods; nil or none for no such section.
    # @return [Array<Array>] The lines, as screen.box hands them out; one per mod turned off.
    def mod_lines(text, differing = nil, rows = nil, turned_off = nil)
      mods = ScreenPrototype.mods_of(text)
      marks = mod_marks(text, differing, rows)
      lines = mods.map do |mod|
        color, note = marks[mod] || [:plain, nil]
        [:item, mod, color, note]
      end
      lines = [[:head, "Mods (#{mods.size})"]] + lines
      return lines if turned_off.nil? || turned_off.empty?

      off = turned_off.map do |name, scripts|
        [:item, name, :grey, "yours, turned off here"]
      end
      lines + [[:head, "Your mods turned off here (#{off.size})"]] + off
    end
  end
end
