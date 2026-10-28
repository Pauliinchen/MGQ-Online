#----------------------------------------------------------------
#  relay_rows.rb
#
#  Changelog:
#      Paulinchen  2026-10-28: Wrote the rewards a party member catches up with as the DLL hands them to the scripts
#                            - Created
#
#----------------------------------------------------------------

# Writes the rows of the catch-up's tables as the relay's story tables take them (Relay/README.md
# "Catch-up tables"), from the Ruby rows of the generated tables (generated_tables.rb) and the
# tests' own rows of the same shape, which the script tests hand to the catch-up engine with it
# (fixtures/catchup/engine.rb). It also writes a stand-in of the rewards tables as the DLL hands them
# to the scripts (party_rewards).

# The catch-up's rows as the relay keeps them.
module CatchupRelayRows
  # What the relay's rows call a reward's kind, by the Ruby kind.
  REWARD_KINDS = { :skill => "skill", :i => "item", :w => "weapon", :a => "armor" }

  # What the relay's rows call a setting's kind, by the Ruby kind.
  SETTING_KINDS = { :encounters => "encounters", :v => "variable", :s => "switch" }

  # The vehicles by the number the Ruby rows give them.
  VEHICLES = %w(boat ship airship)

  # The Ruby tables, by their constant, and the relay's table each goes to.
  TABLES = {
    :PARTS => "parts", :JOINS => "joins", :REMOVALS => "removals", :KEY_ITEMS => "key_items", :CHESTS => "chests", :REWARDS => "rewards",
    :LESSONS => "lessons", :CLASS_LEVELS => "class_levels", :ACTOR_CHANGES => "actor_changes", :SETTINGS => "settings", :VEHICLES => "vehicles",
    :WARP_FREE_MAPS => "warp_free_maps", :MAKINA => "makina", :PRIZE_VARIABLES => "prize_variables",
  }

  # Writes a mark as the relay takes it: its kind as text.
  #
  # @param mark [Array] [:s, switch], [:v, variable, at least] or [:ss, map, event, letter].
  # @return [Array] The mark.
  def self.mark_of(mark)
    [mark[0].to_s] + mark[1..-1]
  end

  # Writes a row's place in the story.
  #
  # @param row [Struct] A row with site, part, step, side and marks.
  # @return [Hash] The place's fields.
  def self.place_of(row)
    { "site" => row.site, "part" => row.part, "step" => row.step, "side" => row.side && row.side.to_s, "marks" => row.marks.map { |mark| mark_of(mark) } }
  end

  # Tells whether a row's event ran as the relay keeps it: a ran left out, as the tests' rows leave
  # it, counts as run, as the catch-up has always read it.
  #
  # @param row [Struct] The row.
  # @return [Boolean] Whether it ran.
  def self.ran(row)
    row.ran != false
  end

  # Numbers the rows of an ordered table, ten apart so an admin can put one between.
  #
  # @param rows [Array<Hash>] The rows in the story's order.
  # @return [Array<Hash>] The rows with their order.
  def self.ordered(rows)
    rows.each_with_index.map { |row, index| row.merge("order" => (index + 1) * 10) }
  end

  # Writes Ruby tables as the relay's tables; a table left out is left out.
  #
  # @param tables [Hash{Symbol => Array}] The rows by their constant, see TABLES.
  # @return [Hash{String => Array<Hash>}] The rows by the relay's table.
  def self.tables(tables)
    written = {}
    tables.each do |name, rows|
      table = TABLES[name] or raise "no relay table for #{name}"
      written[table] = send("#{table}_rows", rows)
    end
    written
  end

  # @param rows [Array<Struct>] The Ruby rows of PARTS.
  # @return [Array<Hash>] The relay's rows.
  def self.parts_rows(rows)
    ordered(rows.map { |row| { "id" => row.id, "name" => row.name, "ending" => row.ending.map { |mark| mark_of(mark) }, "gate" => row.gate } })
  end

  # @param rows [Array<Struct>] The Ruby rows of JOINS.
  # @return [Array<Hash>] The relay's rows.
  def self.joins_rows(rows)
    ordered(rows.map do |row|
      { "actor" => row.actor, "persona" => row.persona }.merge(place_of(row)).merge("gate" => row.gate, "rule" => row.rule.to_s, "index" => row.index.to_i, "ran" => ran(row))
    end)
  end

  # @param rows [Array<Struct>] The Ruby rows of REMOVALS.
  # @return [Array<Hash>] The relay's rows.
  def self.removals_rows(rows)
    ordered(rows.map { |row| { "actor" => row.actor, "persona" => row.persona }.merge(place_of(row)).merge("first" => row.first ? true : false, "index" => row.index.to_i) })
  end

  # @param rows [Array<Struct>] The Ruby rows of KEY_ITEMS.
  # @return [Array<Hash>] The relay's rows.
  def self.key_items_rows(rows)
    ordered(rows.map { |row| { "item" => row.item, "amount" => row.amount }.merge(place_of(row)).merge("ran" => ran(row)) })
  end

  # @param rows [Array<Struct>] The Ruby rows of CHESTS.
  # @return [Array<Hash>] The relay's rows.
  def self.chests_rows(rows)
    ordered(rows.map { |row| { "key" => "ss#{row.key[0]}.#{row.key[1]}.#{row.key[2]}", "items" => row.items, "part" => row.part, "step" => row.step, "flags" => Array(row.flags) } })
  end

  # @param rows [Array<Struct>] The Ruby rows of REWARDS.
  # @return [Array<Hash>] The relay's rows.
  def self.rewards_rows(rows)
    ordered(rows.map { |row| { "kind" => REWARD_KINDS.fetch(row.kind), "id" => row.id, "amount" => row.amount }.merge(place_of(row)).merge("ran" => ran(row)) })
  end

  # @param rows [Array<Struct>] The Ruby rows of LESSONS.
  # @return [Array<Hash>] The relay's rows.
  def self.lessons_rows(rows)
    ordered(rows.map { |row| { "actor" => row.actor, "skill" => row.skill }.merge(place_of(row)).merge("ran" => ran(row)) })
  end

  # @param rows [Array<Struct>] The Ruby rows of CLASS_LEVELS.
  # @return [Array<Hash>] The relay's rows.
  def self.class_levels_rows(rows)
    ordered(rows.map { |row| { "actor" => row.actor, "class" => row.class_id, "level" => row.level }.merge(place_of(row)).merge("ran" => ran(row)) })
  end

  # @param rows [Array<Struct>] The Ruby rows of ACTOR_CHANGES.
  # @return [Array<Hash>] The relay's rows.
  def self.actor_changes_rows(rows)
    ordered(rows.map do |row|
      { "actor" => row.actor, "calls" => row.calls.map { |name, ids, once| [name.to_s, ids, once ? true : false] }, "gate" => row.gate }.merge(place_of(row)).merge("ran" => ran(row))
    end)
  end

  # @param rows [Array<Struct>] The Ruby rows of SETTINGS.
  # @return [Array<Hash>] The relay's rows.
  def self.settings_rows(rows)
    ordered(rows.map { |row| { "kind" => SETTING_KINDS.fetch(row.kind), "id" => row.id, "value" => row.value }.merge(place_of(row)).merge("ran" => ran(row)) })
  end

  # @param rows [Array<Struct>] The Ruby rows of VEHICLES.
  # @return [Array<Hash>] The relay's rows.
  def self.vehicles_rows(rows)
    ordered(rows.map { |row| { "vehicle" => VEHICLES.fetch(row.vehicle) }.merge(place_of(row)).merge("ran" => ran(row)) })
  end

  # @param maps [Array<Integer>] WARP_FREE_MAPS.
  # @return [Array<Hash>] The relay's rows.
  def self.warp_free_maps_rows(maps)
    maps.map { |map| { "map" => map } }
  end

  # @param rows [Array<Struct>] The Ruby rows of MAKINA.
  # @return [Array<Hash>] The relay's rows.
  def self.makina_rows(rows)
    rows.map { |row| { "item" => row.item, "level" => row.level, "site" => row.site } }
  end

  # @param ids [Array<Integer>] PRIZE_VARIABLES.
  # @return [Array<Hash>] The relay's rows.
  def self.prize_variables_rows(ids)
    ids.map { |id| { "variable" => id } }
  end

  # Writes the rewards a party member catches up with as the DLL hands them to the scripts
  # (story.rewards, PartyRewards of MGQOnline.Game), from a test's stand-in of their constants, whose
  # missing constants count as empty.
  #
  # @param rewards [Module, nil] The module of the constants, nil for none.
  # @param sites [Array<String>, nil] The side events' sites in the order of GROUPS, nil to leave
  #   them out.
  # @return [Hash] The rewards without the revision: "skills", "actors", "items", "sided", "route",
  #   "final", "groups", "chests" and "chest_flags".
  def self.party_rewards(rewards, sites = nil)
    found = lambda { |name, empty| rewards && rewards.const_defined?(name) ? rewards.const_get(name) : empty }
    lists = lambda { |hash, kinds| Hash[kinds.map { |kind| [kind.to_s, Array(hash[kind])] }] }
    sided = found.call(:SIDED, {})
    groups = found.call(:GROUPS, []).each_with_index.map do |group, index|
      written = sites ? { "site" => sites[index] } : {}
      written.merge("alice" => lists.call(group[:alice], [:skills, :actors]), "ilias" => lists.call(group[:ilias], [:skills, :actors]), "choice" => group[:choice] ? true : false,
                    "marks" => group[:marks].map { |page| page.map { |mark| mark_of(mark) } })
    end
    {
      "skills" => found.call(:SKILLS, []), "actors" => found.call(:ACTORS, []), "items" => found.call(:ITEMS, {}),
      "sided" => lists.call(sided, [:skills, :actors]), "route" => lists.call(found.call(:ROUTE, {}), [:skills, :actors]),
      "final" => lists.call(found.call(:FINAL, {}), [:skills, :actors, :items]), "groups" => groups,
      "chests" => found.call(:CHESTS, []), "chest_flags" => found.call(:CHEST_FLAGS, []),
    }
  end
end
