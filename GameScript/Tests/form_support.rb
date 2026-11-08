#----------------------------------------------------------------
#  form_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-09: Marked the difficulty's and the squad rules' captions narrow as the DLL does
#                            - Gave the save no label width, as the DLL gives it none
#      Paulinchen  2026-11-06: Wrote the form views out instead of reading recorded ones
#      Paulinchen  2026-11-05: Answered the world screen's forms with the DLL's recorded views and the values each test sets instead of the Ruby forms they were made from
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Answers the form.* topics of the world screen's forms (FormTopics in the DLL) on a FakeBridge with
# fixed views: a form opens on the view the DLL answers for its kind (VIEWS), and a test sets what
# a topic answers for its case. Unless a test sets
# an answer, a page keeps the view it showed last with the values handed to it, a text box takes
# its text as typed, a page sends without a problem, and the limits page shows its view in VIEWS.
# Every rule (which fields show, what a switch changes, how a text is tidied or refused) is
# WorldFormsTests' and FormTopicsTests' to cover.

require "json"
require_relative "bridge_support"

# Writes a field of a form's view as the DLL writes it.
#
# @param key [String] The field's key.
# @param kind [String] Its kind, such as "text" or "switch".
# @param label [String] Its label.
# @param row [Integer] Its row.
# @param fields [Hash] The other fields that differ from a plain field's, and "hint".
# @param hint [String] Its hint.
# @return [Hash] The field.
def form_field(key, kind, label, row, fields = {}, hint = "")
  fields, hint = {}, fields if fields.is_a?(String)
  { "key" => key, "kind" => kind, "label" => label, "row" => row, "side" => nil, "max_chars" => nil, "allowed" => nil, "optional" => false, "group" => nil,
    "lines" => 1, "hint" => hint, "choices" => [], "narrow_caption" => false, "enabled" => true }.merge(fields)
end

# Writes a form's view as the DLL writes it.
#
# @param title [String] The form's title.
# @param fields [Array<Hash>] Its fields.
# @param values [Hash] Its values by key.
# @param derived [Hash] What the values come to.
# @return [Hash] The view.
def form_view(title, fields, values, derived)
  { "title" => title, "fields" => fields, "values" => values, "derived" => derived }
end

# Stands in for the DLL's answers of the world screen's forms.
class FormAnswers
  include NotedRequests

  # The topics answered.
  TOPICS = %w(form.open form.view form.set form.turn form.tick form.check form.send form.close).freeze

  # The views the DLL answers, by what they show.
  VIEWS = {
    "create as it opens" => form_view("Create a new world", [
      form_field("name", "text", "Name", 0, { "max_chars" => 16, "group" => "World" },
                 "The name everyone sees in the list."),
      form_field("password", "password", "Password", 1, { "side" => "left", "max_chars" => 20, "group" => "World" },
                 "Typed once to enter the world. Left empty, anyone may enter."),
      form_field("seats", "number", "Max Players", 1, { "side" => "right", "max_chars" => 2, "allowed" => "digits", "group" => "World" },
                 "Players in the world at once, 2 to 32."),
      form_field("hidden", "check", "Hidden", 2, { "side" => "left", "group" => "World" },
                 "Only its players see it in the list. Others add it with its id."),
      form_field("type", "switch", "World type", 2, { "side" => "right", "group" => "World", "choices" => ["Classic", "Raid"] },
                 "Classic: each party plays its own story. Raid: the whole world plays one. Fixed once created."),
      form_field("from_save", "check", "Shared save", 3, { "side" => "left", "group" => "World" },
                 "Classic only: new players start from one of your saves. Fixed once created."),
      form_field("choose", "check", "Player's choice", 3, { "side" => "right", "group" => "World" },
                 "Classic only: new players pick their start, the opening or a save. Fixed once created."),
      form_field("save", "save", "Save", 4, { "side" => "left", "group" => "World", "enabled" => false },
                 "The save every new player starts from."),
      form_field("raid_bosses", "check", "Raid Bosses", 4, { "side" => "right", "group" => "World" },
                 "Classic only: story bosses fight as raid bosses of their tier, far stronger. Changeable later."),
      form_field("mods", "mods", "Mods", 6, { "group" => "Game data" },
                 "The mods of the world: listed, required to enter or essential. Enter picks them."),
      form_field("shared", "check", "Shared Mod Settings", 7, { "group" => "Game data" },
                 "Ticked: every player plays with your mod options here. Unticked: each keeps their own."),
      form_field("other_mods_off", "check", "Turn off other mods", 8, { "group" => "Game data" },
                 "Ticked: mods the world does not name are off in it. Personal mods stay on."),
      form_field("description", "area", "What the world is about", 9, { "max_chars" => 1000, "optional" => true, "group" => "Description", "lines" => 4 },
                 "Shown in the world's details. Optional."),
      form_field("confirm", "button", "Create the world", 10,
                 "Creates the world. You enter it from the list."),
    ], { "name" => "", "password" => "", "seats" => "4", "hidden" => false, "type" => 0, "share" => 0, "from_save" => false, "save" => nil, "choose" => false, "description" => "", "mods" => "", "shared" => false, "difficulty" => 2, "other_mods_off" => false, "raid_bosses" => false, "luka" => false, "formation" => 1, "front" => 0, "raid_front" => 0 },
    { "type" => "classic", "share" => "off", "difficulty" => 0, "from_save" => false, "choose" => false, "raid_bosses" => false, "other_mods_off" => false, "squad" => { "luka" => false, "formation" => 4, "front" => 1, "raid_front" => 1 } }),
    "create turned to a Raid World" => form_view("Create a new world", [
      form_field("name", "text", "Name", 0, { "max_chars" => 16, "group" => "World" },
                 "The name everyone sees in the list."),
      form_field("password", "password", "Password", 1, { "side" => "left", "max_chars" => 20, "group" => "World" },
                 "Typed once to enter the world. Left empty, anyone may enter."),
      form_field("seats", "number", "Max Players", 1, { "side" => "right", "max_chars" => 2, "allowed" => "digits", "group" => "World" },
                 "Players in the world at once, 2 to 32."),
      form_field("hidden", "check", "Hidden", 2, { "side" => "left", "group" => "World" },
                 "Only its players see it in the list. Others add it with its id."),
      form_field("type", "switch", "World type", 2, { "side" => "right", "group" => "World", "choices" => ["Classic", "Raid"] },
                 "Classic: each party plays its own story. Raid: the whole world plays one. Fixed once created."),
      form_field("share", "switch", "Sharing companions", 3, { "group" => "World", "choices" => ["Off", "Story companions", "Story + battle recruits"] },
                 "Raid only: companions everyone gets on reaching their level. Fixed once created."),
      form_field("from_save", "check", "Shared save", 4, { "side" => "left", "group" => "World" },
                 "New players start from one of your saves, the world's story from its point. Fixed once created."),
      form_field("difficulty", "switch", "Difficulty", 4, { "side" => "right", "group" => "World", "choices" => ["VERY EASY", "EASY", "NORMAL", "HARD", "VERY HARD", "HELL", "PARADOX"], "narrow_caption" => true },
                 "Every player of the world plays on it. You can change it later in the edit form."),
      form_field("save", "save", "Save", 5, { "side" => "left", "group" => "World", "enabled" => false },
                 "The save every new player starts from."),
      form_field("limits", "button", "Set formation limits", 5, { "side" => "right", "group" => "World" },
                 "Luka, the team size and the Frontlines every player keeps. Changeable later too."),
      form_field("mods", "mods", "Mods", 6, { "group" => "Game data" },
                 "The mods of the world: listed, required to enter or essential. Enter picks them."),
      form_field("shared", "check", "Shared Mod Settings", 7, { "group" => "Game data" },
                 "Ticked: every player plays with your mod options here. Unticked: each keeps their own."),
      form_field("other_mods_off", "check", "Turn off other mods", 8, { "group" => "Game data" },
                 "Ticked: mods the world does not name are off in it. Personal mods stay on."),
      form_field("description", "area", "What the world is about", 9, { "max_chars" => 1000, "optional" => true, "group" => "Description", "lines" => 2 },
                 "Shown in the world's details. Optional."),
      form_field("confirm", "button", "Create the world", 10,
                 "Creates the world. You enter it from the list."),
    ], { "name" => "", "password" => "", "seats" => "4", "hidden" => false, "type" => 1, "share" => 0, "from_save" => false, "save" => nil, "choose" => false, "description" => "", "mods" => "", "shared" => false, "difficulty" => 2, "other_mods_off" => true, "raid_bosses" => false, "luka" => false, "formation" => 1, "front" => 0, "raid_front" => 0 },
    { "type" => "raid", "share" => "off", "difficulty" => 0, "from_save" => false, "choose" => false, "raid_bosses" => false, "other_mods_off" => true, "squad" => { "luka" => false, "formation" => 4, "front" => 1, "raid_front" => 1 } }),
    "create of a Raid World with its choices" => form_view("Create a new world", [
      form_field("name", "text", "Name", 0, { "max_chars" => 16, "group" => "World" },
                 "The name everyone sees in the list."),
      form_field("password", "password", "Password", 1, { "side" => "left", "max_chars" => 20, "group" => "World" },
                 "Typed once to enter the world. Left empty, anyone may enter."),
      form_field("seats", "number", "Max Players", 1, { "side" => "right", "max_chars" => 2, "allowed" => "digits", "group" => "World" },
                 "Players in the world at once, 2 to 32."),
      form_field("hidden", "check", "Hidden", 2, { "side" => "left", "group" => "World" },
                 "Only its players see it in the list. Others add it with its id."),
      form_field("type", "switch", "World type", 2, { "side" => "right", "group" => "World", "choices" => ["Classic", "Raid"] },
                 "Classic: each party plays its own story. Raid: the whole world plays one. Fixed once created."),
      form_field("share", "switch", "Sharing companions", 3, { "group" => "World", "choices" => ["Off", "Story companions", "Story + battle recruits"] },
                 "Raid only: companions everyone gets on reaching their level. Fixed once created."),
      form_field("from_save", "check", "Shared save", 4, { "side" => "left", "group" => "World" },
                 "New players start from one of your saves, the world's story from its point. Fixed once created."),
      form_field("difficulty", "switch", "Difficulty", 4, { "side" => "right", "group" => "World", "choices" => ["VERY EASY", "EASY", "NORMAL", "HARD", "VERY HARD", "HELL", "PARADOX"], "narrow_caption" => true },
                 "Every player of the world plays on it. You can change it later in the edit form."),
      form_field("save", "save", "Save", 5, { "side" => "left", "group" => "World", "enabled" => false },
                 "The save every new player starts from."),
      form_field("limits", "button", "Set formation limits", 5, { "side" => "right", "group" => "World" },
                 "Luka, the team size and the Frontlines every player keeps. Changeable later too."),
      form_field("mods", "mods", "Mods", 6, { "group" => "Game data" },
                 "The mods of the world: listed, required to enter or essential. Enter picks them."),
      form_field("shared", "check", "Shared Mod Settings", 7, { "group" => "Game data" },
                 "Ticked: every player plays with your mod options here. Unticked: each keeps their own."),
      form_field("other_mods_off", "check", "Turn off other mods", 8, { "group" => "Game data" },
                 "Ticked: mods the world does not name are off in it. Personal mods stay on."),
      form_field("description", "area", "What the world is about", 9, { "max_chars" => 1000, "optional" => true, "group" => "Description", "lines" => 2 },
                 "Shown in the world's details. Optional."),
      form_field("confirm", "button", "Create the world", 10,
                 "Creates the world. You enter it from the list."),
    ], { "name" => "Raid", "password" => "", "seats" => "4", "hidden" => false, "type" => 1, "share" => 2, "from_save" => false, "save" => nil, "choose" => true, "description" => "", "mods" => "", "shared" => false, "difficulty" => 4, "other_mods_off" => true, "raid_bosses" => true, "luka" => false, "formation" => 1, "front" => 0, "raid_front" => 0 },
    { "type" => "raid", "share" => "all", "difficulty" => 2, "from_save" => false, "choose" => false, "raid_bosses" => false, "other_mods_off" => true, "squad" => { "luka" => false, "formation" => 4, "front" => 1, "raid_front" => 1 } }),
    "create with its formation limits" => form_view("Formation limits", [
      form_field("luka", "check", "Luka Replaceable", 0, { "side" => "left", "group" => "Team" },
                 "Ticked: players may take Luka out of their team. Unticked: he always stays in it."),
      form_field("formation", "switch", "Formation Size", 0, { "side" => "right", "group" => "Team", "choices" => ["Original", "4", "5", "6", "7", "8"], "narrow_caption" => true },
                 "The team size every player keeps. Its last place sits out, except with Original, the game's own."),
      form_field("front", "switch", "Frontline", 1, { "side" => "left", "group" => "Team", "choices" => ["1", "2", "3", "4"], "narrow_caption" => true },
                 "In front in regular fights, the rest on the Backline. With more players, each one's first fights."),
      form_field("raid_front", "switch", "Raid Frontline", 1, { "side" => "right", "group" => "Team", "choices" => ["1", "2", "3", "4"], "narrow_caption" => true },
                 "In front in raid boss fights, the rest on the Backline. With more players, each one's first fights."),
      form_field("done", "button", "Done", 2,
                 "Back to the world's form. Cancel goes back too, keeping the limits."),
    ], { "name" => "", "password" => "", "seats" => "4", "hidden" => false, "type" => 1, "share" => 0, "from_save" => false, "save" => nil, "choose" => false, "description" => "", "mods" => "", "shared" => false, "difficulty" => 2, "other_mods_off" => true, "raid_bosses" => false, "luka" => true, "formation" => 0, "front" => 3, "raid_front" => 1 },
    { "type" => "raid", "share" => "off", "difficulty" => 0, "from_save" => false, "choose" => false, "raid_bosses" => false, "other_mods_off" => true, "squad" => { "luka" => true, "formation" => 0, "front" => 4, "raid_front" => 2 } }),
    "edit of a Classic world, by an admin" => form_view("Edit Home", [
      form_field("seats", "number", "Max Players", 0, { "max_chars" => 2, "allowed" => "digits", "group" => "World" },
                 "Players in the world at once, 2 to 32."),
      form_field("raid_bosses", "check", "Raid Bosses", 1, { "group" => "World" },
                 "Story bosses fight as raid bosses of their tier, far stronger, from each player's next boss fight."),
      form_field("mods", "mods", "Mods", 2, { "group" => "Game data" },
                 "The mods of the world: listed, required to enter or essential. Enter picks them."),
      form_field("other_mods_off", "check", "Turn off other mods", 5, { "group" => "Game data" },
                 "Ticked: mods the world does not name are off. Personal mods stay on. Players in it enter again."),
      form_field("description", "area", "What the world is about", 6, { "max_chars" => 1000, "optional" => true, "group" => "Description", "lines" => 4 },
                 "Shown in the world's details. Optional."),
      form_field("confirm", "button", "Save the changes", 7,
                 "Changes the world for everyone."),
    ], { "seats" => "4", "mods" => "", "description" => "", "shared" => false, "difficulty" => 4, "other_mods_off" => false, "raid_bosses" => true, "luka" => false, "formation" => 1, "front" => 0, "raid_front" => 0 },
    { "difficulty" => 0, "raid_bosses" => true, "other_mods_off" => false, "squad" => { "luka" => false, "formation" => 4, "front" => 1, "raid_front" => 1 } }),
    "edit of a Raid World turned to its first difficulty" => form_view("Edit Raid", [
      form_field("seats", "number", "Max Players", 0, { "max_chars" => 2, "allowed" => "digits", "group" => "World" },
                 "Players in the world at once, 2 to 32."),
      form_field("difficulty", "switch", "Difficulty", 1, { "side" => "left", "group" => "World", "choices" => ["Per player", "VERY EASY", "EASY", "NORMAL", "HARD", "VERY HARD", "HELL", "PARADOX"], "narrow_caption" => true },
                 "Every player of the world plays on it, those in it now at once."),
      form_field("limits", "button", "Set formation limits", 1, { "side" => "right", "group" => "World" },
                 "Luka, the team size and the Frontlines every player keeps. Changeable later too."),
      form_field("mods", "mods", "Mods", 2, { "group" => "Game data" },
                 "The mods of the world: listed, required to enter or essential. Enter picks them."),
      form_field("other_mods_off", "check", "Turn off other mods", 5, { "group" => "Game data" },
                 "Ticked: mods the world does not name are off. Personal mods stay on. Players in it enter again."),
      form_field("description", "area", "What the world is about", 6, { "max_chars" => 1000, "optional" => true, "group" => "Description", "lines" => 4 },
                 "Shown in the world's details. Optional."),
      form_field("confirm", "button", "Save the changes", 7,
                 "Changes the world for everyone."),
    ], { "seats" => "8", "mods" => "!Level Cap", "description" => "About", "shared" => true, "difficulty" => 1, "other_mods_off" => true, "raid_bosses" => false, "luka" => true, "formation" => 3, "front" => 1, "raid_front" => 2 },
    { "difficulty" => -2, "raid_bosses" => false, "other_mods_off" => true, "squad" => { "luka" => true, "formation" => 6, "front" => 2, "raid_front" => 3 } }),
    "edit of a Raid World without a difficulty, by its creator" => form_view("Edit Raid", [
      form_field("seats", "number", "Max Players", 0, { "max_chars" => 2, "allowed" => "digits", "group" => "World" },
                 "Players in the world at once, 2 to 32."),
      form_field("difficulty", "switch", "Difficulty", 1, { "side" => "left", "group" => "World", "choices" => ["Per player", "VERY EASY", "EASY", "NORMAL", "HARD", "VERY HARD", "HELL", "PARADOX"], "narrow_caption" => true },
                 "Every player of the world plays on it, those in it now at once."),
      form_field("limits", "button", "Set formation limits", 1, { "side" => "right", "group" => "World" },
                 "Luka, the team size and the Frontlines every player keeps. Changeable later too."),
      form_field("mods", "mods", "Mods", 2, { "group" => "Game data" },
                 "The mods of the world: listed, required to enter or essential. Enter picks them."),
      form_field("shared", "check", "Shared Mod Settings", 4, { "group" => "Game data" },
                 "Ticked: every player plays with your mod options here. Unticked: each keeps their own."),
      form_field("other_mods_off", "check", "Turn off other mods", 5, { "group" => "Game data" },
                 "Ticked: mods the world does not name are off. Personal mods stay on. Players in it enter again."),
      form_field("description", "area", "What the world is about", 6, { "max_chars" => 1000, "optional" => true, "group" => "Description", "lines" => 4 },
                 "Shown in the world's details. Optional."),
      form_field("confirm", "button", "Save the changes", 7,
                 "Changes the world for everyone."),
    ], { "seats" => "8", "mods" => "!Level Cap", "description" => "About", "shared" => true, "difficulty" => 0, "other_mods_off" => true, "raid_bosses" => false, "luka" => true, "formation" => 3, "front" => 1, "raid_front" => 2 },
    { "difficulty" => nil, "raid_bosses" => false, "other_mods_off" => true, "squad" => { "luka" => true, "formation" => 6, "front" => 2, "raid_front" => 3 } }),
    "rename without a name while Discord tells none" => form_view("Your name", [
      form_field("name", "text", "Your name", 0, { "max_chars" => 16, "group" => "Player" },
                 "The name the others see. Without one, your name on Discord."),
      form_field("confirm", "button", "Use this name", 1,
                 "Keeps the name for every world."),
    ], { "name" => "" },
    { "difficulty" => 0, "raid_bosses" => false, "other_mods_off" => false, "squad" => { "luka" => false, "formation" => 0, "front" => 1, "raid_front" => 1 } }),
    "password" => form_view("Enter Home", [
      form_field("password", "password", "Password", 0, { "max_chars" => 20, "group" => "World" },
                 "The password the world's creator gave you."),
      form_field("confirm", "button", "Enter the world", 1,
                 "Opens the world with the password."),
    ], { "password" => "" },
    { "difficulty" => 0, "raid_bosses" => false, "other_mods_off" => false, "squad" => { "luka" => false, "formation" => 0, "front" => 1, "raid_front" => 1 } }),
    "join" => form_view("Add a hidden world", [
      form_field("id", "id", "World id", 0, { "max_chars" => 32, "allowed" => "hex", "group" => "World" },
                 "The id the world's creator copied for you. Ctrl+V pastes it."),
      form_field("confirm", "button", "Add the world", 1,
                 "Adds the world to your list, where you enter it like any other."),
    ], { "id" => "" },
    { "difficulty" => 0, "raid_bosses" => false, "other_mods_off" => false, "squad" => { "luka" => false, "formation" => 0, "front" => 1, "raid_front" => 1 } }),
  }.freeze

  # The view each kind of form opens on.
  OPENED = { "create" => "create as it opens", "edit" => "edit of a Classic world, by an admin", "rename" => "rename without a name while Discord tells none",
             "password" => "password", "join" => "join" }.freeze

  # The view of the formation limits.
  LIMITS = "create with its formation limits"

  # The forms whose one text box sends them with Enter.
  SENDS_ON_ENTER = %w(rename password join).freeze

  # @return [FakeBridge] The bridge answered on.
  attr_reader :fake

  # Answers the topics on a bridge.
  #
  # @param fake [FakeBridge] The bridge.
  def initialize(fake)
    @fake = fake
    @asked = []
    @fixed = {}
    @pages = {}
    TOPICS.each { |topic| fake.answer(topic) { |request| answer(topic, request) } }
  end

  # Sets what a topic answers: a value, or a block that makes it of the request. A view answered
  # becomes the page's view.
  #
  # @param topic [String] The topic.
  # @param value [Object] The answer, nil to answer as before the test set one.
  # @yieldparam request [Hash] The request.
  def set(topic, value = nil, &block)
    block || !value.nil? ? @fixed[topic] = (block || value) : @fixed.delete(topic)
  end

  # Forgets the requests taken so far, so a check reads only those of its own case.
  def clear
    @asked.clear
  end

  # Makes a view of the DLL's.
  #
  # @param name [String] What it shows, a key of VIEWS.
  # @param sends_on_enter [Boolean] Whether Enter in its one text box sends it.
  # @return [Hash] The view.
  def self.view(name, sends_on_enter = false)
    JSON.parse(JSON.generate(VIEWS.fetch(name))).merge("page" => "main", "sends_on_enter" => sends_on_enter)
  end

  # Answers a topic: what the test set, else what the page shows.
  #
  # @param topic [String] The topic.
  # @param request [Hash] The request.
  # @return [Object] The reply.
  def answer(topic, request)
    note(topic, request)
    if @fixed.key?(topic)
      fixed = @fixed[topic]
      reply = fixed.respond_to?(:call) ? fixed.call(request) : fixed
      keep(request, reply) if reply.is_a?(Hash) && reply["fields"] && topic != "form.check"
      return reply
    end

    case topic
    when "form.open" then keep(request, FormAnswers.view(OPENED.fetch(request["kind"]), SENDS_ON_ENTER.include?(request["kind"])))
    when "form.set"
      page_of(request)["values"][request["key"]] = request["value"]
      nil
    when "form.check" then [request["text"], nil]
    when "form.close"
      @pages.delete(request["form"])
      nil
    else page_of(request)
    end
  end

  private

  # Keeps a view as its page's.
  #
  # @param request [Hash] The request, naming the form and the page.
  # @param view [Hash] The view.
  # @return [Hash] The view.
  def keep(request, view)
    (@pages[request["form"]] ||= {})[request["page"] || "main"] = view
  end

  # Finds the view a page showed last; the limits page shows its recorded view at first.
  #
  # @param request [Hash] The request, naming the form and the page.
  # @return [Hash] The view.
  def page_of(request)
    pages = @pages[request["form"]] or raise FakeBridge::BadRequest, "No form is open in #{request['form']}."
    pages[request["page"] || "main"] ||= FormAnswers.view(LIMITS).merge("page" => request["page"])
  end
end

# Answers the form.* topics with the recorded views and the values each test sets, kept in $forms;
# a bridge answered already keeps its answers.
#
# @param fake [FakeBridge] The test's bridge.
# @return [FormAnswers] The answers.
def answer_forms(fake)
  $forms = FormAnswers.new(fake) unless $forms && $forms.fake.equal?(fake)
  $forms
end
