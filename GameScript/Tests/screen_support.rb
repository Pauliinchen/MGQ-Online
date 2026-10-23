#----------------------------------------------------------------
#  screen_support.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Fetched the list as the DLL's screen does when it opens
#                            - Created
#
#----------------------------------------------------------------

# The topics of the world screen's model (screen.*), answered by FakeBridge stand-ins: the list
# from the directory's list the test's DLL stand-in reads ($dll["mp_dir_list"]) joined with the
# worlds on this PC as local_worlds_support.rb keeps them, and a world's row, details, choices and
# list box lines from fixtures/screen/screen_prototype.rb, the screen's methods as they were before
# they moved to C#, asking the other scripts' stand-ins what they asked them. The prototype is
# checked against fixtures/screen/screen.json, which the C# model passes too, as this file loads.

require_relative "../../fixtures/screen/screen_cases"

# The golden screen: its texts and its cases.
SCREEN_CASES = rule_cases("screen", "screen.json")

SCREEN_CASES["cases"].each do |entry|
  shown = ScreenPrototype::Cases.run(entry)
  shown.each { |part, value| raise "the screen prototype shows #{part} of #{entry['name'].inspect} otherwise than screen.json" if value != entry[part] }
end

# What a world of the test reads beyond it: the other scripts, as ScreenPrototype::Model asked them.
class StandInScreenFacts
  # Names the parts of the game data that differ.
  #
  # @param parts [Array<String>] The parts.
  # @param named [Integer] Most parts named.
  # @return [String] The text.
  def data_text(parts, named)
    MGQ_MpWorld::GameData.text(parts, named)
  end

  # Lists the required mods that differ.
  #
  # @param listed [Object] The world.
  # @return [Array] The rows.
  def rows(listed)
    MGQ_MpWorldMods.differing(listed)
  end

  # Writes the details' line of the shared settings.
  #
  # @param listed [Object] The world.
  # @param me [String] The player's id.
  # @return [String] The line.
  def settings_text(listed, me)
    MGQ_MpWorldMods.details_text(listed, me)
  end

  # Tells whether the settings are shared.
  #
  # @param text [String] The settings.
  # @return [Boolean] Whether they are.
  def shared?(text)
    MGQ_MpWorldMods.shared?(text)
  end

  # Lists the player's mods a world turns off.
  #
  # @param listed [Object] The world.
  # @return [Array<Array>, nil] The mods.
  def turned_off(listed)
    MGQ_MpModParking.turned_off_mods(listed)
  end

  # Tells whether a mod's script is installed.
  #
  # @param name [String] The mod.
  # @return [Boolean] Whether it is.
  def installed?(name)
    MGQ_MpWorld.installed_mod?(name)
  end

  # Names a difficulty.
  #
  # @param value [Integer] The difficulty.
  # @return [String, nil] Its name.
  def difficulty_name(value)
    MGQ_MpWorld.difficulty_name(value)
  end

  # Names a Formation size.
  #
  # @param value [Integer] The size.
  # @return [String] Its name.
  def formation_name(value)
    MGQ_MpWorld.formation_name(value)
  end

  # Gives the default squad rules.
  #
  # @return [Hash] The rules.
  def default_squad
    MGQ_MpWorld.default_squad
  end

  # Lists the hidden worlds added.
  #
  # @return [Array<String>] Their ids.
  def added
    MGQ_MpWorld::Added.all
  end

  # Tells what of the game data differs.
  #
  # @param entry [Object] The world.
  # @return [Array<String>, nil] The parts.
  def differing(entry)
    entry.listed.nil? ? nil : MGQ_MpWorld::GameData.differing(entry.listed.data)
  end
end

# The rows of the screen's list the stand-in made last, by key: the entry the prototype reads.
$screen_rows = {}

# Writes a world of the directory as screen.list hands it out.
#
# @param world [MGQ_MpWorld::Directory::ListedWorld] The world, as the scripts' thin parser read it.
# @return [Hash] Every field by name, the members as [id, online, name], the squad by its names in the DLL's answers.
def stand_in_listed_value(world)
  value = {}
  MGQ_MpWorld::Directory::ListedWorld.members.each { |field| value[field.to_s] = world[field] }
  value["members"] = world.members.map { |member| [member.id, member.online, member.name] }
  value["squad"] = world.squad && { "luka" => world.squad[:luka], "formation" => world.squad[:formation], "front" => world.squad[:front], "raid_front" => world.squad[:raid_front] }
  value["mods_unread"] = world.mods_unread ? true : false
  value
end

# Makes the prototype's view of a world of the list.
#
# @param world [MGQ_MpWorld::Directory::ListedWorld, nil] The world.
# @param local [Hash, nil] Its folder, as worlds.local hands it out.
# @param id [String, nil] Its directory id.
# @param name [String] Its name.
# @param favourite [Boolean] Whether it is a favourite.
# @param gone [Boolean] Whether the directory no longer has it.
# @return [ScreenPrototype::Cases::Entry] The view.
def stand_in_screen_entry(world, local, id, name, favourite, gone)
  played = local && local["played"] && ScreenPrototype::Cases::Played.new(Time.at(local["played"]).strftime("%Y-%m-%d"))
  folder = local && ScreenPrototype::Cases::Local.new(local["id"], played, !stand_in_latest_save_of(local["id"]).nil?, local["type"] == "raid")
  listed = world && ScreenPrototype::Cases.listed_of(stand_in_listed_value(world))
  ScreenPrototype::Cases::Entry.new(id, name, listed, folder, favourite, gone)
end

# Finds a world's latest save as worlds.latest_save answers it.
#
# @param id [String] The folder's id.
# @return [Array, nil] The save, nil for none.
def stand_in_latest_save_of(id)
  MGQ_Multiplayer::Bridge.call("worlds.latest_save", id)
end

# The player's id the stand-ins name, as the DLL knows it; a test may set another.
$screen_me = "me"

# Makes the screen's rows of the directory's worlds and the worlds on this PC, as screen.list does,
# and keeps them for the details, choices and list box lines.
#
# @param listed [Array<MGQ_MpWorld::Directory::ListedWorld>] The directory's worlds.
# @param complete [Boolean] Whether the directory's list arrived.
# @param admin [Boolean] Whether the player is one of the relay's admins.
# @return [Array<Hash>] The rows, as screen.list hands them out.
def stand_in_screen_rows(listed, complete, admin = false)
  worlds = listed.map { |world| [world.id.to_s, world.name.to_s, world.raid? ? true : false, world.featured ? true : false] }
  $screen_rows = {}
  stand_in_entries(worlds, $local_worlds.values, $world_lists["favourite"], complete).map do |id, name, index, local, favourite, gone|
    world = index && listed[index]
    key = id || "folder:#{local['id']}"
    entry = stand_in_screen_entry(world, local, id, name, favourite, gone)
    $screen_rows[key] = [entry, world, admin == true, $screen_me]
    model = ScreenPrototype::Model.new(entry, $screen_me, admin == true, StandInScreenFacts.new)
    model.draw_item(0)
    drawn = model.drawn
    { "key" => key, "id" => id, "name" => name, "text" => drawn["text"], "count" => drawn["count"], "color" => drawn["color"].to_s, "dim" => drawn["dim"], "favourite" => favourite, "gone" => gone,
      "listed" => world && stand_in_listed_value(world), "local" => local }
  end
end

# Makes the screen's list as screen.list answers it, from the list the test's DLL stand-in reads.
#
# @return [Hash] The list.
def stand_in_screen_list
  state, error, listed, admin = MGQ_MpWorld::Directory.list
  rows = stand_in_screen_rows(listed, state == "ready", admin == true)
  info = { "loading" => "The list is being fetched . . .", "failed" => "The list could not be fetched: #{error}" }[state]
  { "state" => state, "error" => error, "admin" => admin == true, "info" => info, "rows" => rows }
end

# Makes the entries the world screen lists, as it makes them of screen.list's rows.
#
# @param listed [Array<MGQ_MpWorld::Directory::ListedWorld>] The directory's worlds.
# @param complete [Boolean] Whether the directory's list arrived.
# @param admin [Boolean] Whether the player is one of the relay's admins.
# @return [Array<MGQ_MpWorld::Entry>] The entries, each with its key and row.
def screen_entries(listed, complete, admin = false)
  stand_in_screen_rows(listed, complete, admin).map { |row| MGQ_MpWorldScreen.entry_of(row) }
end

# Reads the details' old methods for a test through the prototype, which the C# model follows,
# such as panels(entry, me) or start_text(listed).
class ScreenDetail
  # Runs a method of the prototype's details.
  #
  # @param name [Symbol] The method.
  # @param args [Array] Its arguments.
  # @return [Object] What it answers.
  def method_missing(name, *args)
    model = ScreenPrototype::Model.new(nil, $screen_me, false, StandInScreenFacts.new)
    model.respond_to?(name) ? model.send(name, *args) : super
  end

  # Tells whether the prototype's details answer a method.
  #
  # @param name [Symbol] The method.
  # @return [Boolean] Whether they do.
  def respond_to_missing?(name, include_private = false)
    ScreenPrototype::Model.method_defined?(name) || super
  end
end

# Gives a test the details' old methods, see ScreenDetail.
#
# @return [ScreenDetail] The details.
def screen_detail
  ScreenDetail.new
end

# The worlds a test made itself, by the key screen_entry gave them, which the stand-ins answer as
# if the DLL's list held them.
$screen_test_rows = {}

# Hands a world a test made to the screen's stand-ins under a key of its own, as if the DLL's list
# held it.
#
# @param entry [MGQ_MpWorld::Entry] The world.
# @param admin [Boolean] Whether the player is one of the relay's admins.
# @param me [String] The player's id.
# @return [MGQ_MpWorld::Entry] The world, with its key.
def screen_entry(entry, admin = false, me = $screen_me)
  entry.key = "test:#{$screen_test_rows.size + 1}"
  $screen_test_rows[entry.key] = [entry, entry.listed, admin, me]
  entry
end

# Points the prototype at a row of the list the stand-in made last, or at a world a test made.
#
# @param key [String] The row's key.
# @return [Array, nil] The prototype and the entry, nil for a key the list lacks.
def stand_in_screen_model(key)
  stand_in_screen_list unless $screen_rows.key?(key) || $screen_test_rows.key?(key)
  entry, _world, admin, me = $screen_test_rows[key] || $screen_rows[key]
  entry && [ScreenPrototype::Model.new(entry, me, admin, StandInScreenFacts.new), entry, me]
end

# Writes a world's details as screen.details answers them.
#
# @param key [String] The row's key.
# @return [Hash, nil] The details.
def stand_in_screen_details(key)
  model, entry, me = stand_in_screen_model(key)
  return nil unless model

  { "title" => entry.name, "title_color" => entry.raid? ? "raid" : entry.featured? ? "featured" : "system", "played" => model.played_text(entry.local),
    "panels" => model.panels(entry, me).map { |panel| ScreenPrototype::Cases.panel_value(panel) }, "description" => entry.listed && entry.listed.description.to_s }
end

# Answers the topics of the world screen's model.
#
# @param fake [FakeBridge] The bridge.
def answer_screen(fake)
  fake.answer("screen.open") { $screen_open = true; MGQ_Multiplayer::Link.function('mp_dir_refresh').call; nil }
  fake.answer("screen.close") { $screen_open = false; nil }
  fake.answer("screen.texts") { SCREEN_CASES["texts"].reject { |name, _| name == "mod_states" } }
  fake.answer("screen.list") { stand_in_screen_list }
  fake.answer("screen.world") do |id|
    state, _error, listed = MGQ_MpWorld::Directory.list
    world = listed.find { |candidate| candidate.id == id }
    { "state" => state, "listed" => world && stand_in_listed_value(world) }
  end
  fake.answer("screen.details") { |key| stand_in_screen_details(key) }
  fake.answer("screen.actions") do |key|
    model, = stand_in_screen_model(key)
    model && (model.on_world; model.offered.call.map { |label, symbol, enabled| [label, symbol.to_s, enabled.nil? ? true : enabled] })
  end
  fake.answer("screen.box") do |request|
    model, entry, = stand_in_screen_model(request["key"])
    next nil unless model && entry.listed

    lines = request["kind"] == "players" ? model.player_lines(entry.listed.members) : model.mod_lines(entry.listed.mods, StandInScreenFacts.new.differing(entry), MGQ_MpWorldMods.differing(entry.listed), MGQ_MpModParking.turned_off_mods(entry.listed))
    lines.map { |line| ScreenPrototype::Cases.line_value(line) }
  end
end

# Tells the screen that the list and what the details read changed, as the DLL's drain does.
def screen_changed
  MGQ_MpWorld::Changes.note(MGQ_MpWorld::Changes::LIST | MGQ_MpWorld::Changes::DETAILS)
end
