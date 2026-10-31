#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Named the commit whose scripts it records
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Writes rules.json: what the world screen of world_screen.rbx and world_save_distribution.rbx
# decided while a world was entered (open_now? with full?, data_allows?, enter with ask_start and
# ask_take_start) before the rules moved to EnterRules in MGQOnline.Game, as golden cases both
# sides check. Each case lists what the screen did, in order.
#
#   git show fd101786:GameScript/Multiplayer/Scripts/world_screen.rbx > old_screen.rbx
#   git show fd101786:GameScript/Multiplayer/Scripts/world_save_distribution.rbx > old_distribution.rbx
#   ruby fixtures/entering/make_fixtures.rb old_screen.rbx old_distribution.rbx

require "json"

SCREEN_SOURCE = File.read(ARGV[0] || abort("Name the world_screen.rbx of commit fd101786, see the header."), :encoding => "UTF-8")
DISTRIBUTION_SOURCE = File.read(ARGV[1] || abort("Name the world_save_distribution.rbx of commit fd101786, see the header."), :encoding => "UTF-8")

# Takes a method's source out of a script.
#
# @param source [String] The script.
# @param name [String] The method, "self.name" for a module method.
# @return [String] Its source.
def method_of(source, name)
  source[/^  def #{Regexp.escape(name)}(?=[\s(]).*?\n  end\n/m] or raise "no method #{name}"
end

# What a recorded case did, in order.
$did = []

# The game's sounds, which note the buzzer.
module Sound; def self.play_buzzer; $did << ["buzz"]; end; end

# The mod's world, as far as the rules ask it.
module MGQ_MpWorld
  # Stands in for the game data check with the case's parts.
  module GameData; def self.differing(_data); $differing; end; end

  # Reads the mods as world.rbx did, without the marks.
  def self.mods_of(text); text.to_s.split(";").map { |mod| mod.strip.sub(/\A[!?]\s*/, "") }.reject(&:empty?); end
end

# The parked mods' question to a world's creator.
module MGQ_MpModParking; def self.own_data_text; "OWN DATA"; end; end

# The starting save's rules, recorded from world_save_distribution.rbx.
module MGQ_MpSaveDistribution; end
%w(self.ask_start? self.fetch? self.new_player?).each { |name| MGQ_MpSaveDistribution.module_eval(method_of(DISTRIBUTION_SOURCE, name)) }

# A window that notes the choices it shows.
class Recorded; def start(choices); $did << ["choices", choices.map { |choice| choice[1].to_s }, choices.map { |choice| choice[0] }]; end; def deactivate; end; end

# The world screen as far as the rules go.
class Screen
  %w(open_now? full? data_allows? enter ask_start ask_take_start own_entry?).each { |name| class_eval(method_of(SCREEN_SOURCE, name)) }

  # The screen's texts the rules say.
  START_WARNING = SCREEN_SOURCE[/START_WARNING = "(.*?)"\n/, 1]

  attr_accessor :entry, :me, :data_accepted

  def initialize; @list_window = @form_window = @start_window = Recorded.new; end
  def log_screen(_line); end
  def say(text); $did << ["say", text]; end
  def refuse(text); Sound.play_buzzer; say(text); end
  def back_to_list; $did << ["back"]; end
  def close_popups; end
  def confirm(what, question, yes); $did << ["confirm", what.to_s, question, yes]; end
  def fetch_start(_world); $did << ["fetch"]; end
  def start_world(_world); $did << ["start"]; end
  def entry_text; "the world"; end
end

Listed = Struct.new(:start, :online, :seats, :members, :creator_id)
Member = Struct.new(:id, :online)
Entry = Struct.new(:name, :listed)
World = Struct.new(:name, :id, :raid, :latest_save) { def raid?; raid; end }

open_cases = [
  ["pending", 1, 4, false], ["ready", 4, 4, false], ["ready", 4, 4, true], ["none", 3, 4, false], ["none", 5, 4, true]
].map do |start, online, seats, me_online|
  $did = []
  screen_object = Screen.new
  screen_object.me = "me"
  screen_object.entry = Entry.new("Haven")
  listed = Listed.new(start, online, seats, [Member.new("other", true), Member.new("me", me_online)])
  open = screen_object.open_now?(listed)
  { "start" => start, "online" => online, "seats" => seats, "me_online" => me_online, "open" => open, "did" => $did }
end

data_cases = []
[nil, [], ["items", "maps"]].each do |differing|
  [false, true].each do |strict|
    [false, true].each do |own|
      [false, true].each do |parked|
        [false, true].each do |accepted|
          ["", "!Level Cap; ?Data"].each do |mods|
            next if differing.nil? && (strict || own || parked || accepted || !mods.empty?)
            next if differing && differing.empty? && (strict || parked || accepted || !mods.empty?)

            $did = []
            $differing = differing
            screen_object = Screen.new
            screen_object.instance_variable_set(:@data_accepted, accepted)
            allowed = screen_object.data_allows?("Haven", "data", strict, mods, own, parked) { $did << ["entered"] }
            data_cases << { "differing" => differing, "strict" => strict, "own" => own, "parked" => parked, "accepted" => accepted, "mods" => mods, "allowed" => allowed, "did" => $did }
          end
        end
      end
    end
  end
end

start_cases = []
[false, true].each do |raid|
  [nil, false, true].each do |choose|
    [nil, "none", "pending", "ready"].each do |start|
      [false, true].each do |new_player|
        [false, true].each do |own|
          next if !new_player && own

          $did = []
          screen_object = Screen.new
          screen_object.me = "me"
          screen_object.entry = Entry.new("Haven", Listed.new(start, 1, 4, [], own ? "me" : "other"))
          screen_object.enter(World.new("Haven", "folder", raid, new_player ? nil : 0), start, choose)
          start_cases << { "raid" => raid, "choose" => choose, "start" => start, "new_player" => new_player, "own" => own, "did" => $did }
        end
      end
    end
  end
end

File.write(File.join(__dir__, "rules.json"), JSON.pretty_generate({ "open" => open_cases, "data" => data_cases, "start" => start_cases }) + "\n")
puts "wrote #{open_cases.size} open, #{data_cases.size} data and #{start_cases.size} start cases"
