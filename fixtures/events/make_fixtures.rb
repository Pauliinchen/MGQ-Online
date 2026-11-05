#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Gave the cases whose lists show an extended choice the answer the extended choices now get
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Writes the golden cases of the event sorter next to this file from coop_events.rbx, which kept it
# before it moved to C# (MGQOnline.Game's EventSorter):
#
# - script_cases.json: every list the script tests sorted (coop_events_test.rb), with the commands,
#   the switches, variables and personal flags the sorter read, the common events it followed and
#   the names it looked at, and everything the sorter says of the list. The script tests answer
#   events.sort from them; MGQOnline.Game.Tests sorts them again.
# - game_cases.json: a few hundred pages and common events of the game, by site alone, in a new
#   game's state and in a mixed one, with what the sorter read and said. MGQOnline.Game.Tests sorts
#   them again over the game folder BATTLE_GAME_DIR names, comparing only the cases whose commands
#   (their codes and indents, and those of the common events they follow) and the switch and
#   variable names the sorter looked at the folder holds too, by a hash of them.
#
# Since 2026-11-05 the game's extended choice windows (ex_choice_show) count as choices, which the
# old sorter read as talk (user decision), so the cases whose lists show one take the answer of
# EXTENDED_CHOICES in place of the recorded one.
#
# It runs on the scripts of the commit that added it, on Ruby 3.3, with the reference game's Data:
#
#   ruby fixtures/events/make_fixtures.rb "<MGQ Paradox Translated>\Data"

require "json"
require "digest"

# The answers of the cases whose lists show an extended choice, by site: what the branches on its
# answer do counts as the choice's, here a transfer and story behind it.
EXTENDED_CHOICES = {
  "map:1946:37:1" => { "marks" => %w(choice_story says sets travel), "may_tell" => true },
}

# The folders this script reads.
ROOT = File.expand_path("../..", __dir__)
TESTS = File.join(ROOT, "GameScript", "Tests")

# Records what the sorter of coop_events.rbx reads and says, once per call from outside it.
module SorterRecorder
  # The sorter's entry points, each recorded with the whole answer for its list.
  ENTRIES = [:kind, :kind_of, :may_tell?, :scene?, :story_command?]

  @cases = []
  @busy = false
  @reads = nil

  class << self
    # The cases recorded so far.
    attr_reader :cases

    # Tells whether a call runs inside a recorded one.
    #
    # @return [Boolean] Whether it does.
    def busy?
      @busy
    end

    # Wraps the sorter, the branch reader, the personal checks and the common events' marks.
    def install
      sorter = MGQ_MpCoopEvents.singleton_class
      sorter.prepend(Entries)
      sorter.prepend(Reads)
      MGQ_MpStoryState.singleton_class.prepend(Personal) if defined?(MGQ_MpStoryState)
    end

    # Notes a value the sorter read while a call is recorded.
    #
    # @param kind [String] "s", "v", "ps", "pv", "names_s", "names_v".
    # @param id [Integer] The switch or variable.
    # @param value [Object] What it read.
    def read(kind, id, value)
      @reads[kind][id.to_s] = value if @reads
    end

    # Notes a common event the sorter followed while a call is recorded.
    #
    # @param id [Integer] The common event.
    def common(id)
      return unless @reads

      common = $data_common_events[id]
      @reads["commons"][id.to_s] = common && rows(common.list || [])
    end

    # Records one call from outside the sorter, with everything the sorter says of its list.
    #
    # @param entry [Symbol] The entry point.
    # @param subject [Game_Event, Array] The event or the list.
    # @param index [Integer, nil] The command of story_command?.
    # @return [Object] What the entry point answers.
    def record(entry, subject, index = nil)
      return yield if @busy

      # Without the game's switches every branch counts, which the C# sorter never meets: such
      # cases are kept only for lists without branches.
      stateless = !$game_switches || !$game_variables
      begin
        @busy = true
        @reads = { "s" => {}, "v" => {}, "ps" => {}, "pv" => {}, "names_s" => {}, "names_v" => {}, "commons" => {} }
        # The sorter keeps a common event's marks for a frame; every call is sorted anew here.
        MGQ_MpCoopEvents.instance_variable_set(:@common_kinds, {})
        MGQ_MpCoopEvents.instance_variable_set(:@common_frame, nil)
        result = yield
        found = describe(entry, subject, index, result)
        branches = ([found["list"]] + found.fetch("commons", {}).values.compact).any? { |rows| rows.any? { |row| row[0] == 111 } }
        @cases << found unless stateless && branches
        result
      ensure
        @busy = false
        @reads = nil
      end
    end

    # Describes a call and the sorter's whole answer for its list.
    #
    # @param entry [Symbol] The entry point.
    # @param subject [Game_Event, Array] The event or the list.
    # @param index [Integer, nil] The command of story_command?.
    # @param result [Object] What the entry point answered.
    # @return [Hash] The case.
    def describe(entry, subject, index, result)
      sorter = MGQ_MpCoopEvents
      page = subject.respond_to?(:mgq_mp_page)
      list = (page ? subject.list : subject) || []
      answer = if entry == :story_command?
                 { "story" => result }
               else
                 found = {
                   "list_kind" => sorter.kind_of(list).to_s,
                   "may_tell" => sorter.may_tell?(list),
                   "scene" => sorter.scene?(list),
                   "marks" => sorter.marks_of(sorter.runnable(list), 0).select { |_key, value| value }.keys.map(&:to_s).sort,
                 }
                 found["kind"] = page ? sorter.kind(subject).to_s : found["list_kind"]
                 found
               end
      shown = page && subject.mgq_mp_page >= 0
      {
        "call" => entry == :story_command? ? "command" : (page ? "page" : "list"),
        "list" => rows(list),
        "trigger" => page ? subject.trigger : nil,
        "shown" => page ? shown : nil,
        "index" => index,
        "resident" => defined?(MGQ_MpCoopCastle) && MGQ_MpCoopCastle.resident?(list) ? true : false,
        "map" => $game_map ? $game_map.map_id : nil,
      }.merge(reads_now).merge("answer" => answer)
    end

    # Takes the reads of the call recorded now, without the empty ones.
    #
    # @return [Hash] The reads.
    def reads_now
      @reads.reject { |_kind, values| values.empty? }
    end

    # Writes commands as plain rows.
    #
    # @param list [Array<RPG::EventCommand>] The commands.
    # @return [Array<Array>] Code, indent and parameters of each.
    def rows(list)
      list.map { |command| [command.code, command.indent, command.parameters] }
    end
  end

  # Records each entry point called from outside the sorter.
  module Entries
    SorterRecorder::ENTRIES.each do |name|
      define_method(name) do |*args|
        subject = args[0]
        SorterRecorder.record(name, subject, args[1]) { super(*args) }
      end
    end
  end

  # Notes what the sorter reads: branches, names and the common events it follows.
  module Reads
    # Notes the switch or variables a branch reads, see MGQ_MpCoopEvents.holds?.
    #
    # @param params [Array] The branch's parameters.
    # @return [Boolean, nil] What the sorter's own answers.
    def holds?(params)
      result = super
      if $game_switches && $game_variables
        case params[0]
        when 0 then SorterRecorder.read("s", params[1], $game_switches[params[1]] == true)
        when 1
          SorterRecorder.read("v", params[1], number($game_variables[params[1]]))
          SorterRecorder.read("v", params[3], number($game_variables[params[3]])) unless params[2] == 0
        end
      end
      result
    end

    # Notes a switch's name, see MGQ_MpCoopEvents.temporary_switch?.
    #
    # @param id [Integer] The switch.
    # @return [Boolean] What the sorter's own answers.
    def temporary_switch?(id)
      name = $data_system.switches[id].to_s
      SorterRecorder.read("names_s", id, name) unless id.between?(1001, 2000)
      super
    end

    # Notes a variable's name, see MGQ_MpCoopEvents.temporary_variable?.
    #
    # @param id [Integer] The variable.
    # @return [Boolean] What the sorter's own answers.
    def temporary_variable?(id)
      name = $data_system.variables[id].to_s
      SorterRecorder.read("names_v", id, name)
      super
    end

    # Notes a common event the sorter follows, see MGQ_MpCoopEvents.common_marks.
    #
    # @param id [Integer] The common event.
    # @param depth [Integer] How deep it is called.
    # @return [Hash] What the sorter's own answers.
    def common_marks(id, depth)
      SorterRecorder.common(id) unless MGQ_MpCoopEvents::OWN_COMMON_EVENTS.include?(id) || depth > MGQ_MpCoopEvents::MAX_DEPTH
      super
    end

    # Reads a variable as the sorter does, nil for a value without a number.
    #
    # @param value [Object] The variable's value.
    # @return [Integer, nil] Its number.
    def number(value)
      value.to_i
    rescue NoMethodError
      nil
    end
  end

  # Notes which switches and variables the sorter asked to be personal.
  module Personal
    # @param id [Integer] The switch.
    # @param variables [Object] See MGQ_MpStoryState.personal_switch?.
    # @return [Boolean] What story_state.rbx answers.
    def personal_switch?(id, variables = nil)
      result = super
      SorterRecorder.read("ps", id, result ? true : false) if SorterRecorder.busy?
      result
    end

    # @param id [Integer] The variable.
    # @return [Boolean] What story_state.rbx answers.
    def personal_variable?(id)
      result = super
      SorterRecorder.read("pv", id, result ? true : false) if SorterRecorder.busy?
      result
    end
  end
end

# Inside the script tests' process: wraps the sorter as coop_events.rbx loads and writes the cases
# as the process ends.
if ENV["RECORD_SORTER"]
  module Kernel
    alias_method :recorder_load, :load
    private :recorder_load

    # Loads a file, and wraps the sorter once coop_events.rbx loaded.
    def load(path, *rest)
      result = recorder_load(path, *rest)
      SorterRecorder.install if path.to_s.end_with?("coop_events.rbx")
      result
    end
  end

  at_exit do
    seen = {}
    cases = SorterRecorder.cases.select { |found| seen[JSON.generate(found)] ? false : (seen[JSON.generate(found)] = true) }
    File.write(ENV["RECORD_SORTER"], JSON.generate(cases))
  end
  return
end

# Reads the game's data files, defining the game's classes as they come.
module GameData
  # Loads a data file, making up any class it names, with the game's user classes as strings.
  #
  # @param path [String] The file.
  # @return [Object] Its content.
  def self.load(path)
    data = File.binread(path)
    begin
      Marshal.load(data)
    rescue ArgumentError => e
      raise unless e.message =~ /undefined class\/module (.+)/

      owner = Object
      Regexp.last_match(1).split("::").each do |name|
        owner = owner.const_defined?(name, false) ? owner.const_get(name) : owner.const_set(name, Class.new { def self._load(s); s; end })
      end
      retry
    end
  end

  # Reads the commands of a list as plain rows, free of the game's classes.
  #
  # @param list [Array] The commands.
  # @return [Array<Array>] Code, indent and parameters of each.
  def self.rows(list)
    (list || []).map { |c| [c.instance_variable_get(:@code), c.instance_variable_get(:@indent), c.instance_variable_get(:@parameters)] }
  end

  # Finds the file of a map, in the folders of a thousand the game keeps them in.
  #
  # @param data [String] The Data folder.
  # @param id [Integer] The map.
  # @return [String, nil] The file, nil without one.
  def self.map_file(data, id)
    folder, number = id.divmod(1000)
    path = folder.zero? ? File.join(data, format("Map%03d.rvdata2", number)) : File.join(data, "Map#{folder == 1 ? '' : folder}", "Data", format("Map%03d.rvdata2", number))
    File.exist?(path) ? path : nil
  end
end

# The shape of commands the C# side compares by: each code and indent.
#
# @param rows [Array<Array>] The commands.
# @return [String] The shape.
def shape_of(rows)
  rows.map { |code, indent, _params| "#{code}:#{indent}" }.join(",")
end

data = ARGV[0] or abort("usage: ruby fixtures/events/make_fixtures.rb \"<game folder>\\Data\"")

# The script tests' lists.
script_file = File.join(__dir__, "script_cases.json")
pid = spawn({ "RECORD_SORTER" => script_file }, RbConfig.ruby, "-r", File.expand_path(__FILE__), File.join(TESTS, "coop_events_test.rb"), out: File::NULL)
Process.wait(pid)
script_cases = JSON.parse(File.read(script_file))
File.write(script_file, JSON.pretty_generate({ "source" => "coop_events.rbx, coop_events_test.rb, Ruby #{RUBY_VERSION}", "cases" => script_cases }) + "\n")
puts "#{script_cases.size} script cases"

# The game's pages and common events.
class Table; def self._load(s); s; end; end
class Color; def self._load(s); s; end; end
class Tone; def self._load(s); s; end; end
system_data = GameData.load(File.join(data, "System.rvdata2"))
names = [system_data.instance_variable_get(:@switches), system_data.instance_variable_get(:@variables)]
actors = GameData.load(File.join(data, "Actors.rvdata2")).size
commons = GameData.load(File.join(data, "CommonEvents.rvdata2")).map do |common|
  common && [common.instance_variable_get(:@trigger), GameData.rows(common.instance_variable_get(:@list))]
end
maps = {}
(1..3999).each do |id|
  path = GameData.map_file(data, id)
  next unless path

  maps[id] = GameData.load(path).instance_variable_get(:@events).sort.map do |event_id, event|
    [event_id, event.instance_variable_get(:@pages).map { |page| [page.instance_variable_get(:@trigger), GameData.rows(page.instance_variable_get(:@list))] }]
  end
end
Object.send(:remove_const, :RPG)

lines = File.readlines(File.join(TESTS, "coop_events_test.rb"), encoding: "UTF-8")
first_check = lines.index { |line| line.start_with?("# Sorting events.") } or abort("no '# Sorting events.' in coop_events_test.rb")
eval(lines.first(first_check).join, TOPLEVEL_BINDING, File.join(TESTS, "coop_events_test.rb"))
SorterRecorder.install

$data_system = System.new(names[0], names[1])
$data_actors = Array.new(actors)
$data_common_events = commons.map { |common| common && RPG::CommonEvent.new(common[1].map { |code, indent, params| Command.new(code, indent, params) }) }
$game_map = Game_Map.new

# The two states: a new game's, and one with every seventh switch on and the variables spread.
STATES = {
  "new" => lambda { $game_switches = Game_Switches.new; $game_variables = Game_Variables.new },
  "mixed" => lambda do
    $game_switches = Game_Switches.new
    $game_variables = Game_Variables.new
    (1...names[0].size).each { |id| $game_switches[id] = (id % 7).zero? }
    (1...names[1].size).each { |id| $game_variables[id] = (id * 13) % 60 }
  end,
}

# Sorts a site in the state set up now and describes it by its site alone.
#
# @param site [String] "map:<map>:<event>:<page>" (pages from 1) or "ce:<id>".
# @param trigger [Integer] The page's or common event's trigger.
# @param rows [Array<Array>] Its commands.
# @param state [String] The state's name.
# @return [Hash] The case.
def game_case(site, trigger, rows, state)
  list = rows.map { |code, indent, params| Command.new(code, indent, params) }
  subject = site.start_with?("map:") ? Game_Event.new(site.split(":")[2].to_i, [RPG::Page.new(list)], trigger) : list
  before = SorterRecorder.cases.size
  subject.is_a?(Array) ? MGQ_MpCoopEvents.kind_of(subject) : MGQ_MpCoopEvents.kind(subject)
  recorded = SorterRecorder.cases[before]
  commons = (recorded["commons"] || {}).keys.map(&:to_i).sort
  named = { "named_s" => (recorded["names_s"] || {}).keys.map(&:to_i).sort, "named_v" => (recorded["names_v"] || {}).keys.map(&:to_i).sort }
  names = named["named_s"].map { |id| "s#{id}=#{$data_system.switches[id]}" } + named["named_v"].map { |id| "v#{id}=#{$data_system.variables[id]}" }
  shape = shape_of(rows) + "|" + commons.map { |id| "#{id}=#{shape_of(common_rows(id))}" }.join("|") + "|" + names.join("|")
  recorded.reject { |key, _value| %w[list commons names_s names_v call].include?(key) }
          .merge("site" => site, "state" => state, "commons" => commons, "shape" => Digest::SHA256.hexdigest(shape)[0, 16])
          .merge(named.reject { |_key, ids| ids.empty? })
end

# The rows of a common event as the sorter followed it.
#
# @param id [Integer] The common event.
# @return [Array<Array>] Its commands.
def common_rows(id)
  common = $data_common_events[id]
  common ? SorterRecorder.rows(common.list || []) : []
end

# Every page and common event, sorted once in a new game's state, then a sample of each kind.
STATES["new"].call
sites = []
maps.each do |map_id, events|
  $game_map.map_id = map_id
  events.each do |event_id, pages|
    pages.each_with_index do |(trigger, rows), index|
      list = rows.map { |code, indent, params| Command.new(code, indent, params) }
      kind = MGQ_MpCoopEvents.kind(Game_Event.new(event_id, [RPG::Page.new(list)], trigger))
      sites << ["map:#{map_id}:#{event_id}:#{index + 1}", map_id, trigger, rows, kind]
    end
  end
end
commons.each_with_index do |common, id|
  next unless common && id > 0

  $game_map.map_id = 0
  sites << ["ce:#{id}", 0, common[0], common[1], MGQ_MpCoopEvents.kind_of(common[1].map { |code, indent, params| Command.new(code, indent, params) })]
end
SorterRecorder.cases.clear
chosen = sites.group_by { |site| [site[0].start_with?("ce:"), site[4]] }.flat_map do |_group, found|
  step = [found.size / 40, 1].max
  (0...found.size).step(step).first(40).map { |index| found[index] }
end
cases = []
STATES.each do |state, set_up|
  set_up.call
  chosen.each do |site, map_id, trigger, rows, _kind|
    $game_map.map_id = map_id
    found = game_case(site, trigger, rows, state)
    found["answer"] = found["answer"].merge(EXTENDED_CHOICES[site]) if EXTENDED_CHOICES[site]
    cases << found
  end
end
File.write(File.join(__dir__, "game_cases.json"), JSON.pretty_generate({ "source" => "coop_events.rbx over #{File.basename(File.dirname(data))}, Ruby #{RUBY_VERSION}", "cases" => cases }) + "\n")
puts "#{cases.size} game cases of #{sites.size} sites"
