#----------------------------------------------------------------
#  engine.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Stopped lifting the warp ban on the maps where warping is free, as the C# engine does
#                            - Read a world chest without its chest flags, as the C# engine does
#                            - Played the recruit page of a companion the player missed once a route finished, as the C# engine does
#                            - Gave from the rows only the history the world's story was past where its log starts, as the C# engine does
#                            - Played a world chest and a Makina by level in the player's game, as the C# engine does
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

# The catch-up of a Raid World as world_catchup.rbx decided it in the game, before the decisions
# moved to MGQOnline.Game's CatchupEngine: the same rules, read over what the DLL holds (the relay's
# catch-up tables and the save's notes) and the snapshot the scripts hand it, answering the actions
# the scripts carry out. The script tests answer the DLL's catch-up topics with it
# (GameScript/Tests/catchup_support.rb), make_engine.rb records its answers as golden cases, and
# MGQOnline.Game.Tests replays them against the C# engine.

# The catch-up's decisions.
module CatchupEngine
  # Luka, who never joins nor leaves.
  HERO = 1

  # The variable that counts the playthroughs, at 0 on the first, which alone loses companions for
  # good.
  PLAYTHROUGH = 912

  # The main story's progress.
  MAIN_PROGRESS = 1001

  # The main story's step right before the Great Decision.
  BEFORE_DECISION = 39

  # The routes as the relay names them, in the order of their variables.
  ROUTES = %w(ad mr chaos)

  # The routes' variables.
  ROUTE_VARIABLES = [1141, 1142, 1143]

  # The switches that tell a route was cleared, in the order of ROUTES.
  CLEAR_SWITCHES = [7096, 7097, 7039]

  # The switch of Alice's side.
  ALICE_CHOSEN = 4

  # The switch of Ilias's side.
  ILIAS_CHOSEN = 5


  # Where each part stands in the story's order; the routes stand side by side.
  RANKS = { "1" => 0, "2" => 1, "3" => 2, "ad" => 3, "mr" => 3, "chaos" => 3 }

  # The parts before the Great Decision, whose sides the player chose themselves.
  SIDED_PARTS = %w(1 2 3)

  # What the notes keep for a companion the world shares once it joined or never will.
  SHARE_SETTLED = "settled"

  # The rule of a join whose gate is the companion's start level.
  START_RULE = :start

  # Looks between two looks at the skills, classes and races the story gave the roster, five seconds,
  # as the tables hold thousands of rows.
  GROWTH_CHECKS = 10

  # The rewards the story trades away again, which the repair of old notes never gives.
  TRADED_REWARDS = [[:w, 4112]]

  # The map and letter of the self switches that tell which items a player of the world found.
  FOUND_MAP = 0

  # See FOUND_MAP.
  FOUND_LETTER = "F"

  # The switches and variables the engine reads besides the rows' marks.
  ENGINE_SWITCHES = [ALICE_CHOSEN, ILIAS_CHOSEN] + CLEAR_SWITCHES
  ENGINE_VARIABLES = [MAIN_PROGRESS, PLAYTHROUGH] + ROUTE_VARIABLES

  Part = Struct.new(:id, :name, :ending, :gate)
  Join = Struct.new(:actor, :persona, :site, :part, :step, :side, :marks, :gate, :rule, :index, :ran)
  Removal = Struct.new(:actor, :persona, :site, :part, :step, :side, :marks, :first, :index)
  KeyItem = Struct.new(:item, :amount, :site, :part, :step, :side, :marks, :ran)
  Chest = Struct.new(:key, :items, :part, :step)
  Reward = Struct.new(:kind, :id, :amount, :site, :part, :step, :side, :marks, :ran)
  Lesson = Struct.new(:actor, :skill, :site, :part, :step, :side, :marks, :ran)
  ClassLevel = Struct.new(:actor, :class_id, :level, :site, :part, :step, :side, :marks, :ran)
  ActorChange = Struct.new(:actor, :calls, :gate, :site, :part, :step, :side, :marks, :ran)
  Setting = Struct.new(:kind, :id, :value, :site, :part, :step, :side, :marks, :ran)
  Vehicle = Struct.new(:vehicle, :site, :part, :step, :side, :marks, :ran)
  Makina = Struct.new(:item, :level, :site)

  # The tables read, with what is worked out of them once.
  class Tables
    attr_accessor :parts, :joins, :removals, :key_items, :chests, :rewards, :lessons, :class_levels, :actor_changes, :settings, :vehicles,
                  :makina, :prize_variables, :rules, :counts, :companion_values

    # Keeps what a block builds from the tables once.
    #
    # @param name [Symbol] Its name.
    # @return [Object] What is kept.
    def kept(name)
      @kept ||= {}
      @kept.key?(name) ? @kept[name] : @kept[name] = yield
    end
  end

  REWARD_KINDS = { "skill" => :skill, "item" => :i, "weapon" => :w, "armor" => :a }
  SETTING_KINDS = { "encounters" => :encounters, "variable" => :v, "switch" => :s }
  VEHICLES = %w(boat ship airship)

  # Reads the relay's tables as the DLL does (CatchupTables.Read): a row that does not read is left
  # out.
  #
  # @param tables [Hash{String => Array<Hash>}] The rows by table.
  # @return [Tables] The tables.
  def self.read(tables)
    t = Tables.new
    rows = lambda { |name| Array(tables[name]).select { |row| row.is_a?(Hash) } }
    t.parts = rows.call("parts").map { |row| (marks = marks_of(row["ending"])) && row["id"].to_s != "" && row["gate"].is_a?(Integer) ? Part.new(row["id"], row["name"].to_s, marks, row["gate"]) : nil }.compact
    t.joins = rows.call("joins").map do |row|
      (place = place_of(row)) && whole?(row, "actor", "persona", "gate", "index") && row["rule"].to_s != "" && flag?(row["ran"]) ?
        Join.new(row["actor"], row["persona"], *place, row["gate"], row["rule"].to_sym, row["index"], row["ran"]) : nil
    end.compact
    t.removals = rows.call("removals").map do |row|
      (place = place_of(row)) && whole?(row, "actor", "persona", "index") && flag?(row["first"]) ? Removal.new(row["actor"], row["persona"], *place, row["first"], row["index"]) : nil
    end.compact
    t.key_items = rows.call("key_items").map do |row|
      (place = place_of(row)) && whole?(row, "item", "amount") && row["amount"] != 0 && flag?(row["ran"]) ? KeyItem.new(row["item"], row["amount"], *place, row["ran"]) : nil
    end.compact
    t.chests = rows.call("chests").map do |row|
      key = self_switch(row["key"])
      key && ids?(row["items"]) && !row["items"].empty? && (row["step"].nil? || row["step"].is_a?(Integer)) ? Chest.new(key, row["items"], row["part"], row["step"]) : nil
    end.compact
    t.rewards = rows.call("rewards").map do |row|
      kind = REWARD_KINDS[row["kind"]]
      kind && (place = place_of(row)) && whole?(row, "id", "amount") && row["amount"] != 0 && flag?(row["ran"]) ? Reward.new(kind, row["id"], row["amount"], *place, row["ran"]) : nil
    end.compact
    t.lessons = rows.call("lessons").map { |row| (place = place_of(row)) && whole?(row, "actor", "skill") && flag?(row["ran"]) ? Lesson.new(row["actor"], row["skill"], *place, row["ran"]) : nil }.compact
    t.class_levels = rows.call("class_levels").map do |row|
      (place = place_of(row)) && whole?(row, "actor", "class", "level") && flag?(row["ran"]) ? ClassLevel.new(row["actor"], row["class"], row["level"], *place, row["ran"]) : nil
    end.compact
    t.actor_changes = rows.call("actor_changes").map do |row|
      calls = row["calls"].is_a?(Array) ? row["calls"].map { |name, ids, once| name.is_a?(String) && ids?(ids) && !ids.empty? && flag?(once) ? [name.to_sym, ids, once] : nil } : nil
      (place = place_of(row)) && whole?(row, "actor") && (row["gate"].nil? || row["gate"].is_a?(Integer)) && flag?(row["ran"]) && calls && !calls.empty? && !calls.include?(nil) ?
        ActorChange.new(row["actor"], calls, row["gate"], *place, row["ran"]) : nil
    end.compact
    t.settings = rows.call("settings").map do |row|
      kind = SETTING_KINDS[row["kind"]]
      ok = kind == :v ? row["value"].is_a?(Integer) : [true, false].include?(row["value"])
      kind && ok && (place = place_of(row)) && whole?(row, "id") && flag?(row["ran"]) ? Setting.new(kind, row["id"], row["value"], *place, row["ran"]) : nil
    end.compact
    t.vehicles = rows.call("vehicles").map do |row|
      at = VEHICLES.index(row["vehicle"])
      at && (place = place_of(row)) && flag?(row["ran"]) ? Vehicle.new(at, *place, row["ran"]) : nil
    end.compact

    t.makina = rows.call("makina").map { |row| whole?(row, "item", "level") && row["site"].to_s != "" ? Makina.new(row["item"], row["level"], row["site"]) : nil }.compact
    t.prize_variables = rows.call("prize_variables").map { |row| row["variable"] }.select { |id| id.is_a?(Integer) }
    t.rules = {}
    rows.call("rules").each { |row| t.rules[row["rule"]] = row["value"] if row.key?("value") }
    t.counts = rows.call("counts").map do |row|
      { "variable" => row["variable"], "weights" => Array(row["weights"]).map { |weight| [weight["switch"], weight["weight"]] },
        "done_switch" => row["doneSwitch"], "done_value" => row["doneValue"], "since" => row["since"] && [row["since"]["variable"], row["since"]["atLeast"]] }
    end
    t.companion_values = rows.call("companion_values").map { |row| [row["actor"], row["variable"], row["atLeast"]] }
    t
  end

  # Tells whether fields of a row hold whole numbers.
  #
  # @param row [Hash] The row.
  # @param names [Array<String>] The fields.
  # @return [Boolean] Whether they do.
  def self.whole?(row, *names)
    names.all? { |name| row[name].is_a?(Integer) }
  end

  # Tells whether a value is true or false.
  #
  # @param value [Object] The value.
  # @return [Boolean] Whether it is.
  def self.flag?(value)
    value == true || value == false
  end

  # Tells whether a value is a list of whole numbers.
  #
  # @param value [Object] The value.
  # @return [Boolean] Whether it is.
  def self.ids?(value)
    value.is_a?(Array) && value.all? { |id| id.is_a?(Integer) }
  end

  # Reads a self switch's key, "ss<map>.<event>.<letter>".
  #
  # @param text [String] The key.
  # @return [Array, nil] Its map, event and letter; nil for no such key.
  def self.self_switch(text)
    text.to_s =~ /\Ass(\d+)\.(\d+)\.(.+)\z/ ? [$1.to_i, $2.to_i, $3] : nil
  end

  # Reads a row's place: site, part, step, side and marks, as the Ruby rows keep them.
  #
  # @param row [Hash] The row.
  # @return [Array, nil] The place's fields; nil for one that does not read.
  def self.place_of(row)
    site = row["site"].to_s
    side = row["side"]
    marks = marks_of(row["marks"])
    return nil if site.empty? || !(row["step"].nil? || row["step"].is_a?(Integer)) || !(side.nil? || %w(alice ilias).include?(side)) || marks.nil?

    [site, row["part"], row["step"], side && side.to_sym, marks]
  end

  # Reads marks as the Ruby rows keep them.
  #
  # @param list [Array] The marks as the relay keeps them.
  # @return [Array<Array>, nil] The marks; nil for a list that does not read.
  def self.marks_of(list)
    return nil unless list.is_a?(Array)

    marks = list.map do |mark|
      next nil unless mark.is_a?(Array)

      case mark[0]
      when "s" then mark.size == 2 && mark[1].is_a?(Integer) && mark[1] > 0 ? [:s, mark[1]] : nil
      when "v" then mark.size == 3 && mark[1].is_a?(Integer) && mark[1] > 0 && mark[2].is_a?(Integer) ? [:v, mark[1], mark[2]] : nil
      when "ss" then mark.size == 4 && mark[1].is_a?(Integer) && mark[2].is_a?(Integer) && mark[3].is_a?(String) && !mark[3].empty? ? [:ss, mark[1], mark[2], mark[3]] : nil
      end
    end
    marks.include?(nil) ? nil : marks
  end

  # Lists what the scripts hand the engine of the game's story and party (StoryTopics' catchup.keys
  # in the DLL): every switch, variable and self switch a row or rule reads, the items whose counts
  # it reads, the Makina, the parts and the companion each side brings along.
  #
  # @param t [Tables] The tables.
  # @return [Hash] The keys.
  def self.keys(t)
    switches = ENGINE_SWITCHES.dup
    variables = ENGINE_VARIABLES.dup
    selves = []
    marked = t.joins + t.removals + t.key_items + t.rewards + t.lessons + t.class_levels + t.actor_changes + t.settings + t.vehicles
    marked.each do |row|
      row.marks.each do |mark|
        case mark[0]
        when :s then switches << mark[1]
        when :v then variables << mark[1]
        else selves << mark[1..3]
        end
      end
    end
    t.settings.each { |row| variables << row.id unless row.kind == :encounters }
    t.chests.each { |row| selves << row.key }
    t.counts.each do |count|
      variables << count["variable"]
      variables << count["since"][0] if count["since"]
      switches << count["done_switch"] if count["done_switch"]
      count["weights"].each { |id, _weight| switches << id }
    end
    t.companion_values.each { |_actor, id, _least| variables << id }
    items = t.key_items.map { |row| "i#{row.item}" }
    t.chests.each { |row| row.items.each { |id| items << "i#{id}" } }
    t.rewards.each { |row| items << "#{row.kind}#{row.id}" unless row.kind == :skill }
    t.makina.each { |row| items << "i#{row.item}" }
    Array(t.rules["orbs"]).each { |id| items << "i#{id}" }
    {
      "switches" => switches.uniq.sort, "variables" => variables.uniq.sort, "selves" => selves.uniq.sort_by { |key| [key[0], key[1], key[2]] },
      "items" => items.uniq.sort, "makina" => t.makina.map { |row| row.item }, "parts" => t.parts.map { |part| [part.id, part.name, part.gate] },
      "side_companions" => t.rules["side_companions"], "orb_event" => t.rules["orb_event"],
    }
  end

  # Builds a story as the game's own data holds it from the values a snapshot carries.
  #
  # @param values [Hash, nil] "s" (the switches on), "v" (each variable set, [id, value]) and "ss"
  #   (the self switches on), nil for none.
  # @return [Array, nil] The switches, variables and self switches; nil for none.
  def self.story_of(values)
    return nil unless values

    switches = []
    values["s"].each { |id| switches[id] = true }
    variables = []
    values["v"].each { |id, value| variables[id] = value }
    selves = {}
    values["ss"].each { |key| selves[key] = true }
    [switches, variables, selves]
  end

  # The engine as the DLL holds it per bridge context: the save's notes, which the scripts hand it
  # after a load and which it hands back whenever a call changed them.
  class Host
    # @return [Hash, nil] The notes.
    attr_accessor :ledger

    # Answers catchup.check: one look at the player's story.
    #
    # @param t [Tables] The tables.
    # @param request [Hash] The snapshot and what the look is for.
    # @return [Hash] The answer.
    def check(t, request)
      Look.new(self, t, request).check
    end

    # Answers catchup.note: a note of the world's story for the save's notes.
    #
    # @param t [Tables] The tables.
    # @param request [Hash] The note.
    # @return [Hash] The answer.
    def note(t, request)
      Look.new(self, t, request).note
    end

    # Answers catchup.hold_join: whether a companion the player's own event hands out waits for the
    # join's gate.
    #
    # @param t [Tables] The tables.
    # @param request [Hash] The companion, the page that runs and the snapshot.
    # @return [Hash] The answer.
    def hold_join(t, request)
      Look.new(self, t, request).hold_join
    end

    # Answers catchup.unlocks: what the catch-up hands out by level, for the World overview.
    #
    # @param t [Tables] The tables.
    # @param request [Hash] The snapshot.
    # @return [Hash] The answer.
    def unlocks(t, request)
      Look.new(self, t, request).unlocks
    end
  end

  # One call of the engine over one snapshot: the working copy of the player's story, party and
  # items, which the actions it answers change as the game will.
  class Look
    # Starts a look.
    #
    # @param host [Host] The holder of the notes.
    # @param t [Tables] The tables.
    # @param request [Hash] The request.
    def initialize(host, t, request)
      @host = host
      @t = t
      @request = request
      @host.ledger = request["ledger"] if request.key?("ledger")
      @before_notes = Marshal.dump(@host.ledger)
      @world_id = request["world"].to_s
      @mode = request["mode"]
      @own = CatchupEngine.story_of(request["own"])
      @told = CatchupEngine.story_of(request["told"])
      @roster = Array(request["roster"]).map { |entry| entry.dup }
      @items = (request["items"] || {}).dup
      @worn = Array(request["worn"])
      @unlock_ids = Array(request["unlocks"])
      choices = ChoicesStandIn.personal("raid" => true, "own" => nil)
      @choice_switches = Array(choices["s"])
      @choice_variables = Array(choices["v"])

      @encounters = request["encounters"]
      @summary = request["summary"]
      @sharing = request["sharing"] || "off"
      @starts = {}
      Array(request["starts"]).each { |id, level| @starts[id] = level }
      @log = CatchupEngine.story_of(request["log"])
      @actions = []
      @looking = true
      new_look
    end

    # Answers catchup.check.
    #
    # @return [Hash] "actions", "ledger" (nil while unchanged), "visiting", "ask_side", "orbs" and
    #   "sharable".
    def check
      answer = {}
      if @request["look"] == "carried"
        carried(CatchupEngine.story_of(@request["before"]))
      else
        if @request["audit"]
          audit(story_now)
        elsif @request["vehicles"]
          check_vehicles(story_now, played_world_story)
        end
        give_waiting_rewards
        review(story_now, false)
        answer["ask_side"] = lost_side?
        answer["growth"] = growth(@request["growth"] || {})
        answer["sharable"] = note_roster
        answer["orbs"] = @mode == "world" && orbs_due?
        check_makina
        missed_companions
        check_found_items
        check_counts
      end
      answer["visiting"] = @roster.map { |entry| entry[0] }.select { |id| visiting?(id, story_now) }
      finish(answer)
    end

    # Answers catchup.note: the checkpoint the player took ("checkpoint", nil once the world's story
    # was laid over theirs) or the gate a move on at a cap of another mod opened ("capped").
    #
    # @return [Hash] "actions" and "ledger".
    def note
      ledger["checkpoint"] = @request["checkpoint"] if @request.key?("checkpoint")
      note_capped(@request["capped"]) if @request["capped"]
      finish({})
    end

    # Answers catchup.hold_join, see hold_join? of world_catchup.rbx.
    #
    # @return [Hash] "gate" (nil when the game's own join goes ahead), "actions" and "ledger".
    def hold_join
      main = @request["actor"]
      gate = nil
      unless in_roster?(main) || visit_running?(main, @request["site"])
        part = own_part
        done = ledger["done"]
        rows = joins_of(main).select { |row| row.part == part && done[key_of("j", row)] != true }
        unless rows.empty?
          lowest = rows.map { |row| row.gate }.min
          unless reached?(lowest)
            ledger["held"][main] = true
            log("held back {actor:#{main}}, whom the player's story event hands out: they join once the player's level reaches #{lowest}")
            gate = lowest
          end
        end
      end
      finish("gate" => gate)
    end

    # Answers catchup.unlocks, see unlocks of world_catchup.rbx: each [level, kind, id, name, got,
    # due, gains], gains [kind, id, amount] once each, the kinds "skill", "i", "w" or "a".
    #
    # @return [Hash] "unlocks".
    def unlocks
      story = story_now
      list = story_unlocks + companion_unlocks(story, @told) + makina_unlocks
      { "unlocks" => list }
    end

    private

    # Ends a call: its actions, and the notes when they changed.
    #
    # @param answer [Hash] The answer so far.
    # @return [Hash] The answer.
    def finish(answer)
      answer["actions"] = @actions
      answer["ledger"] = Marshal.dump(@host.ledger) == @before_notes ? nil : @host.ledger
      answer
    end

    # Adds a log line, actors written {actor:<id>} for the scripts to name.
    #
    # @param text [String] The line.
    def log(text)
      @actions << ["log", text]
    end

    # The player's story, as the scripts handed it and the actions changed it.
    #
    # @return [Array] The switches, variables and self switches.
    def story_now
      @own
    end

    # The save's notes, started anew for another world.
    #
    # @return [Hash] The notes.
    def ledger
      notes = @host.ledger
      unless notes.is_a?(Hash) && notes["world"] == @world_id && notes["done"].is_a?(Hash)
        notes = { "world" => @world_id, "done" => {}, "held" => {}, "checkpoint" => nil, "side" => nil, "capped" => nil, "waits" => {}, "rewards_repaired" => true }
        @host.ledger = notes
      end
      notes["held"] ||= {}
      notes["waits"] ||= {}
      notes
    end

    # Reads a rule.
    #
    # @param name [String] The rule.
    # @return [Object, nil] Its value.
    def rule(name)
      @t.rules[name]
    end

    # @param actor [Integer] The companion.
    # @return [Boolean] Whether none of their joins is temporary.
    def lasting_companion?(actor)
      Array(rule("lasting_companions")).include?(actor)
    end

    # @return [String] The part the player's story is in.
    def own_part
      part_of(story_now)
    end

    # Finds the part a story is in, as StoryParts in the DLL.
    #
    # @param story [Array] The story.
    # @return [String] The part.
    def part_of(story)
      progress = [story[1][MAIN_PROGRESS].to_i, 0].max
      route = ROUTE_VARIABLES.index { |id| story[1][id].to_i > 0 }
      return ROUTES[route] if route

      progress < 19 ? "1" : progress < 34 ? "2" : "3"
    end

    # @param id [String] The part.
    # @return [Part, nil] The part.
    def part(id)
      @t.parts.find { |entry| entry.id == id }
    end

    # @param id [String] The part.
    # @return [Integer, nil] Its gate, the last part's for one the tables lack.
    def gate_of(id)
      entry = part(id) || @t.parts.last
      entry && entry.gate
    end

    # @param id [String] The part.
    # @return [String] Its name.
    def part_name(id)
      entry = part(id)
      entry ? entry.name : "Part #{id}"
    end

    # @param level [Integer] The gate.
    # @return [Boolean] Whether the player's level or a cap of another mod below it opens it.
    def gate_open?(level)
      return true if reached?(level)

      view = roster_view
      cap = view[:cap]
      view[:best] && cap.is_a?(Integer) && cap < level && view[:best] >= cap ? true : false
    end

    # @param level [Integer] The level.
    # @return [Boolean] Whether the player's highest base level reaches it.
    def reached?(level)
      best = roster_view[:best]
      best ? best >= level : false
    end

    # @param id [Integer] The companion's main persona.
    # @return [Boolean] Whether they are in the roster.
    def in_roster?(id)
      roster_view[:ids][id] ? true : false
    end

    # The roster's ids and its highest base level among those not on a visit, kept until the roster
    # changes.
    #
    # @return [Hash] :ids, :best and :cap.
    def roster_view
      return @roster_view if @roster_view

      ids = {}
      @roster.each { |entry| ids[entry[0]] = true }
      story = story_now
      best = @roster.reject { |entry| visiting?(entry[0], story) }.max_by { |entry| entry[2] }
      @roster_view = { :ids => ids, :best => best && best[2], :cap => best && best[3] }
    end

    # Forgets the roster read, as a companion joined or left.
    def roster_changed
      @roster_view = nil
    end

    # @param gate [Integer] The gate a move on at a cap of another mod opened.
    def note_capped(gate)
      notes = ledger
      notes["capped"] = reached?(gate) ? nil : gate
      log("moved on at a level cap below #{gate}: the story's rewards wait for level #{gate}") if notes["capped"]
    end

    # @param reason [String] Why the rewards no longer wait.
    def drop_capped(reason)
      gate = ledger["capped"]
      return unless gate

      ledger["capped"] = nil
      log("the story's rewards no longer wait for level #{gate}: #{reason}")
    end

    # @return [Boolean] Whether the story's rewards a story laid over the player's carries them past
    #   wait for the gate a cap opened.
    def rewards_wait?
      gate = ledger["capped"]
      gate.is_a?(Integer) && !reached?(gate)
    end

    # Gives the rewards that wait for a gate the player's level reached.
    def give_waiting_rewards
      waits = ledger["waits"]
      return if waits.empty?

      @t.rewards.each do |row|
        key = key_of("g", row)
        gate = waits[key]
        next unless gate && reached?(gate)

        waits.delete(key)
        give(reward_kind(row), row.id, row.amount, key)
      end
      gifts
    end

    # @param row [Reward] The row.
    # @return [Symbol, String] :skill or the item's kind.
    def reward_kind(row)
      row.kind == :skill ? :skill : row.kind.to_s
    end

    # @param world [Hash] The world's summary.
    # @return [Array<String>] The world's parts in the order it played them.
    def world_parts(world)
      parts = %w(1 2 3) + world["done"].to_a
      current = world["part"].to_s
      parts << current if ROUTES.include?(current) && !parts.include?(current)
      parts
    end

    # @param from [String] The player's part.
    # @param world [Hash] The world's summary.
    # @return [String, Symbol] Where they move on to, or :world.
    def next_part(from, world)
      current = world["part"].to_s
      return :world if from == current

      parts = world_parts(world)
      at = parts.index(from)
      return :world unless at

      parts[(at + 1)..-1].each do |candidate|
        return :world if candidate == current
        next if ROUTES.include?(candidate)
        return candidate if world["checkpoints"].to_a.include?(candidate)
      end
      :world
    end

    # @param mark [Array] The mark.
    # @param story [Array] The story.
    # @return [Boolean] Whether it holds.
    def mark_holds?(mark, story)
      case mark[0]
      when :s then story[0][mark[1]] ? true : false
      when :v
        value = story[1][mark[1]]
        value.is_a?(Numeric) && value >= mark[2]
      when :ss then story[2][[mark[1], mark[2], mark[3]]] ? true : false
      else false
      end
    end

    # @param mark [Array] The mark.
    # @return [Boolean] Whether it is a choice's outcome.
    def choice_mark?(mark)
      return false if mark[0] == :ss

      (mark[0] == :s ? @choice_switches : @choice_variables).include?(mark[1])
    end

    # @param switches [Array] The switches.
    # @return [Symbol, nil] The side they tell.
    def side_of(switches)
      return :alice if switches[ALICE_CHOSEN]
      return :ilias if switches[ILIAS_CHOSEN]

      nil
    end

    # @param row [Struct] The row.
    # @param own [Array] The player's story.
    # @return [Symbol, nil] The side the row asks for in the player's story.
    def side_for(row, own)
      side = side_of(own[0])
      return side unless SIDED_PARTS.include?(row.part)

      @noted_side = ledger["side"] || false if @noted_side.nil?
      @noted_side ? @noted_side.to_sym : side
    end

    # @param story [Array] The player's story.
    def note_side(story)
      side = side_of(story[0])
      return unless side && SIDED_PARTS.include?(story_part(story))

      ledger["side"] = @noted_side = side.to_s
    end

    # @return [Boolean] Whether the player's story went past the choice of a side without one.
    def lost_side?
      step = rule("side_step")
      return false unless step

      story = story_now
      side_of(story[0]).nil? && SIDED_PARTS.include?(part_of(story)) && story[1][MAIN_PROGRESS].to_i.between?(step, BEFORE_DECISION)
    end

    # @param story [Array] The story.
    # @return [String] Its part, kept by the story itself for the look.
    def story_part(story)
      @story_parts[story] ||= part_of(story)
    end

    # Forgets what one look at the rows kept.
    def new_look
      @story_parts = {}.compare_by_identity
      @noted_side = nil
    end

    # @param row [Struct] The row.
    # @param story [Array] The story.
    # @param own [Array] The player's story.
    # @return [Boolean] Whether the story is past the row.
    def passed?(row, story, own = story)
      finished = false
      unless row.part.nil?
        current = story_part(story)
        rank = RANKS[row.part]
        finished = rank == RANKS["ad"] && cleared?(row.part, story)
        return false unless finished || rank < RANKS[current].to_i || current == row.part
      end
      return false if row.side && row.side != side_for(row, own)
      return false unless row.marks.all? { |mark| !choice_mark?(mark) || mark_holds?(mark, own) }
      return true if finished

      !row.marks.empty? && row.marks.all? { |mark| mark_holds?(mark, choice_mark?(mark) ? own : story) }
    end

    # @return [Boolean] Whether the player's story or the world's is past the row.
    def passed_any?(row, story, told)
      passed?(row, story) || (told && passed?(row, told, story)) ? true : false
    end

    # @param row [Struct] A row with a place.
    # @return [Boolean] Whether its history lies before the world's log, the only history whose rows
    #   give what they give: the world's story was past it where its log starts.
    def before_log?(row)
      !@log || passed?(row, @log, @own)
    end

    # @return [Boolean] Whether a story laid over the player's gives what the row gives.
    def carries?(row)
      row.ran != false
    end

    # @return [Boolean] Whether the story finished the route.
    def cleared?(route, story)
      story[0][CLEAR_SWITCHES[ROUTES.index(route)]] ? true : false
    end

    # @return [Array<Integer>] The row's place: rank, then step.
    def place_of(row)
      [RANKS[row.part].to_i, row.step.to_i]
    end

    # @return [Boolean] Whether the row comes after the other.
    def after?(row, other)
      order = place_of(row) <=> place_of(other)
      return order > 0 unless order == 0

      row.site == other.site && row.index.to_i > other.index.to_i
    end

    # @param kind [String] The row's table letter.
    # @param row [Struct] The row.
    # @return [String] Its key in the notes.
    def key_of(kind, row)
      case kind
      when "j", "r" then "#{kind}:#{row.site}:#{row.persona}"
      when "k" then "k:#{row.site}:#{row.item}:#{row.amount}"
      when "c" then "c:#{row.key.join('.')}"
      when "a" then "a:#{row.site}:#{row.actor}"
      else "g:#{row.site}:#{row.kind}#{row.id}"
      end
    end

    # Looks at everything the story owes the player once.
    #
    # @param story [Array] The player's story.
    def audit(story)
      new_look
      told = @told
      world = played_world_story
      done = ledger["done"]
      missing_skills(story, world)
      restock_key_items(story, told)
      restock_unlock_items(story, told)
      repair_rewards(story)
      missing_companions(story, told, done)
      companion_values
      settle(story, world)
      check_vehicles(story, world)
      log("looked at everything the story owes the player once")
      gifts
    end

    # @return [Array, nil] The world's story while the player plays it.
    def played_world_story
      @mode == "world" ? @told : nil
    end

    # Teaches Luka the story's skills of the rows passed, unless the row waits for its gate.
    def missing_skills(story, told)
      waits = ledger["waits"]
      @t.rewards.each do |row|
        next unless row.kind == :skill && carries?(row)
        next if waits[key_of("g", row)]
        next unless before_log?(row) && passed_any?(row, story, told)

        @actions << ["learn", row.id, key_of("g", row)]
      end
    end

    # Looks at the skills, classes and races the story gave the roster's characters every
    # GROWTH_CHECKS looks, and at the next look after the roster changed.
    #
    # @param growth [Hash] "count" (the looks since the last) and "roster" (the roster then).
    # @return [Hash] The same, after this look.
    def growth(growth)
      count = growth["count"].to_i + 1
      ids = @roster.map { |entry| entry[0] }
      return { "count" => count, "roster" => growth["roster"] } unless count >= GROWTH_CHECKS || ids != growth["roster"]

      check_growth
      { "count" => 0, "roster" => ids }
    end

    # Teaches the roster the story's lessons and gives it the story's classes and races.
    def check_growth
      story = story_now
      told = played_world_story
      missing_lessons(story, told)
      missing_class_levels(story, told)
      gifts
    end

    # @param story [Array] The player's story.
    # @param told [Array, nil] The world's story.
    def missing_lessons(story, told)
      @t.lessons.each do |row|
        next unless carries?(row) && in_roster?(row.actor)
        next unless before_log?(row) && passed_any?(row, story, told)

        @actions << ["teach", row.actor, row.skill]
      end
    end

    # @param story [Array] The player's story.
    # @param told [Array, nil] The world's story.
    def missing_class_levels(story, told)
      @t.class_levels.each do |row|
        next unless carries?(row) && (row.actor == HERO || in_roster?(row.actor))
        next unless before_log?(row) && passed_any?(row, story, told)

        @actions << ["class", row.actor, row.class_id, row.level]
      end
    end

    # Lets the story's companions the roster lacks join at their gate.
    def missing_companions(story, told, done)
      story_joins.each do |row|
        key = key_of("j", row)
        next unless done[key] == true && row.part && carries?(row) && !in_roster?(row.actor) && before_log?(row) && passed_any?(row, story, told)
        next if taken_away_since?(row, story, told)

        done[key] = "c"
        log("{actor:#{row.persona}} of #{row.site} is missing from the roster: joins at level #{row.gate}")
      end
      bring_waiting(done)
    end

    # @return [Boolean] Whether a removal after the join took the companion away again.
    def taken_away_since?(row, story, told)
      @t.removals.any? { |removal| removal.actor == row.actor && after?(removal, row) && passed_any?(removal, story, told) }
    end

    # Raises the story values of the companions in the roster to what their joins stand for.
    def companion_values
      @t.companion_values.each do |actor, id, least|
        next unless in_roster?(actor)

        now = story_now[1][id].to_i
        next if now >= least

        set_variable(id, least)
        log("raised variable #{id} from #{now} to #{least}: {actor:#{actor}} is in the roster, whose join stands for it")
      end
    end

    # Moves the player's own values the story's events set to what the latest step passed set.
    def settle(story, told)
      part = story_part(story)
      latest = {}
      earlier = Hash.new { |hash, key| hash[key] = [] }
      @t.settings.each do |row|
        next if ROUTES.include?(row.part) && row.part != part
        next unless before_log?(row) && passed_any?(row, story, told)

        key = [row.kind, row.id]
        earlier[key] << latest[key].value if latest[key]
        latest[key] = row
      end
      latest.each do |key, row|
        now = row.kind == :encounters ? @encounters : story_now[1][row.id]
        next if now == row.value || !earlier[key].include?(now)

        @actions << ["setting", row.kind.to_s, row.id, row.value, row.site]
      end
    end

    # Keeps the vehicles to the story: true where a row behind the story before the world's log gave
    # one, nil where only a row the log holds did, whose replay places it, false where none did.
    def check_vehicles(story, told)
      given = (0..2).map do |id|
        passed = @t.vehicles.select { |row| row.vehicle == id && passed_any?(row, story, told) }
        passed.any? { |row| before_log?(row) } ? true : passed.empty? ? false : nil
      end
      @actions << ["vehicles", given]
    end

    # Looks at every row against the player's story, see review of world_catchup.rbx.
    #
    # @param story [Array] The player's story.
    # @param carried [Boolean] Whether a story laid over theirs just carried them past what is new.
    def review(story, carried)
      new_look
      note_side(story)
      done = ledger["done"]
      waits = carried && rewards_wait? ? ledger["waits"] : nil
      @t.rewards.each do |row|
        key = key_of("g", row)
        next if done[key] || (carried && !carries?(row)) || !passed?(row, story)

        done[key] = true
        next unless (carried && before_log?(row)) || unclaimed_prize?(row)

        if waits
          waits[key] = ledger["capped"]
        else
          give(reward_kind(row), row.id, row.amount, key)
        end
      end
      world_items(story, carried, done)
      companions(story, carried, done)
      actor_changes(story, carried, done)
      settle(story, played_world_story) if carried
      gifts
    end

    # @return [Boolean] Whether a prize row the story passed is another player's claim.
    def unclaimed_prize?(row)
      return false unless row.kind != :skill && row.marks.any? { |mark| mark[0] == :v && @t.prize_variables.include?(mark[1]) }

      key = "#{row.kind}#{row.id}"
      @items.key?(key) && !held?(key)
    end

    # @param key [String] The item's key, such as "i501".
    # @return [Boolean] Whether the party holds it, in the bag or worn.
    def held?(key)
      @items[key].to_i > 0 || @worn.include?(key)
    end

    # Notes the actor changes passed and runs those whose gate the level reached.
    def actor_changes(story, carried, done)
      capped = carried && rewards_wait? ? ledger["capped"] : nil
      @t.actor_changes.each do |row|
        key = key_of("a", row)
        next if done[key] || (carried && !carries?(row)) || !passed?(row, story)

        done[key] = carried && before_log?(row) ? [row.gate.to_i, capped.to_i].max : true
      end
      @t.actor_changes.each do |row|
        key = key_of("a", row)
        gate = done[key]
        next unless gate.is_a?(Integer) && reached?(gate)

        done[key] = true
        @actions << ["change", row.actor, row.site, row.calls.map { |name, ids, once| [name.to_s, ids, once] }]
        roster_changed
      end
    end

    # Gives the world's key items and the items of its story chests.
    def world_items(story, carried, done)
      told = @told
      @t.key_items.each do |row|
        key = key_of("k", row)
        next if done[key]

        mine = passed?(row, story)
        next unless mine || (told && passed?(row, told, story))

        done[key] = true
        give("i", row.item, row.amount, key) if row.amount < 0 && carries?(row) && (carried || !mine) && before_log?(row)
      end
      @t.chests.each do |row|
        key = key_of("c", row)
        next if done[key]

        mine = story[2][row.key] ? true : false
        next unless mine || (told && told[2][row.key])

        done[key] = true
        next unless (carried || !mine) && (!@log || @log[2][row.key])

        @actions << ["replay", { "chest" => "ss#{row.key.join('.')}" }, key]
      end
      restock_key_items(story, told)
      restock_unlock_items(story, told)
    end

    # Hands out every key item the story's place owes the player and they hold fewer of.
    def restock_key_items(story, told)
      owed = {}
      @t.key_items.each do |row|
        next unless row.amount > 0 && before_log?(row) && passed_any?(row, story, told)
        next if taken_since?(row, story, story) || (told && taken_since?(row, told, story))

        owed[row.item] = [owed[row.item].to_i, row.amount].max
      end
      owed.each do |id, amount|
        key = "i#{id}"
        missing = @items.key?(key) ? amount - @items[key] : 0
        give("i", id, missing, "k:owed:#{id}") if missing > 0
      end
    end

    # Hands out every item unlocking a job or race a reward row gives behind its own self switch.
    def restock_unlock_items(story, told)
      unlock_rows.each do |row|
        next unless before_log?(row) && passed_any?(row, story, told)

        key = "i#{row.id}"
        give("i", row.id, 1, "#{key_of('g', row)}:owed") if @items.key?(key) && @items[key] == 0
      end
    end

    # @return [Array<Reward>] The rows restock_unlock_items looks at.
    def unlock_rows
      @t.rewards.select { |row| row.kind == :i && carries?(row) && own_switch_mark?(row) && @unlock_ids.include?(row.id) }
    end

    # @return [Boolean] Whether the row's marks hold a self switch of its own map event.
    def own_switch_mark?(row)
      kind, map, event = row.site.to_s.split(":")
      kind == "map" && row.marks.any? { |mark| mark[0] == :ss && mark[1] == map.to_i && mark[2] == event.to_i }
    end

    # Gives once per save what notes of an earlier version noted done without giving.
    def repair_rewards(story)
      notes = ledger
      return if notes["rewards_repaired"]

      notes["rewards_repaired"] = true
      @t.rewards.each do |row|
        key = key_of("g", row)
        next unless row.kind != :skill && notes["done"][key] && !notes["waits"].key?(key) && carries?(row)
        next if TRADED_REWARDS.include?([row.kind, row.id])
        next unless row.site.to_s.start_with?("map:") && before_log?(row) && passed?(row, story)

        item = "#{row.kind}#{row.id}"
        next if !@items.key?(item) || (row.kind == :i && @unlock_ids.include?(row.id)) || held?(item)

        give(reward_kind(row), row.id, row.amount, "#{key}:repaired")
      end
    end

    # @return [Boolean] Whether a story took a key item after a row gave it.
    def taken_since?(row, told, story)
      @t.key_items.any? do |other|
        next false unless other.item == row.item && other.amount < 0 && other.part && row.part
        later = if other.part != row.part then RANKS[other.part] > RANKS[row.part]
                elsif other.step.to_i != row.step.to_i then other.step.to_i > row.step.to_i
                elsif other.site == row.site && same_marks?(other, row) then listed_after?(other, row)
                else marks_beyond?(other, row)
                end
        later && passed?(other, told, story)
      end
    end

    # @return [Boolean] Whether two rows hold the same marks, in any order.
    def same_marks?(row, other)
      row.marks.sort_by(&:inspect) == other.marks.sort_by(&:inspect)
    end

    # @return [Boolean] Whether a key item row comes after another in the table.
    def listed_after?(row, other)
      @t.key_items.index { |listed| listed.equal?(row) } > @t.key_items.index { |listed| listed.equal?(other) }
    end

    # @return [Boolean] Whether a row's marks lie further than another's of the same step.
    def marks_beyond?(row, other)
      return false if same_marks?(row, other)

      other.marks.all? do |mark|
        row.marks.any? { |own| own == mark || (own[0] == :v && mark[0] == :v && own[1] == mark[1] && own[2] >= mark[2]) }
      end
    end

    # Gives or takes what a row names, and counts it in the working copy.
    #
    # @param kind [Symbol, String] :skill, or "i", "w" or "a".
    # @param id [Integer] The skill or item.
    # @param amount [Integer] How many, below 0 to take.
    # @param key [String] The row, for the log.
    # @param gift [Boolean] Whether it counts among the gifts the next tell lists.
    def give(kind, id, amount, key, gift = true)
      @actions << ["give", kind.to_s, id, amount, key, gift]
      return if kind == :skill

      item = "#{kind}#{id}"
      return unless @items.key?(item)

      if amount < 0
        @items[item] = [@items[item] + amount, 0].max
      else
        @items[item] += amount
        found(id) if kind.to_s == "i" && (@unlock_ids.include?(id) || makina?(id))
      end
    end

    # Notes an item as found for the world, as the scripts' gained does for one the player gains.
    #
    # @param id [Integer] The item.
    def found(id)
      story_now[2][[FOUND_MAP, id, FOUND_LETTER]] = true
    end

    # Ends a tell of gifts: the scripts log what the gives since the last one gave.
    def gifts
      @actions << ["gifts"]
    end

    # @param id [Integer] The variable.
    # @param value [Integer] Its value.
    def set_variable(id, value)
      @actions << ["set", id, value]
      story_now[1][id] = value
    end

    # Sets each count to the switches it counts.
    def check_counts
      @t.counts.each do |count|
        variable = count["variable"]
        since = count["since"]
        next if since && story_now[1][since[0]].to_i < since[1]

        total = count["done_switch"] && story_now[0][count["done_switch"]] ? count["done_value"] : count["weights"].inject(0) { |sum, (id, weight)| story_now[0][id] ? sum + weight : sum }
        now = story_now[1][variable]
        next if now == total

        log("set v#{variable} from #{now.inspect} to #{total}, the switches it counts")
        set_variable(variable, total)
      end
    end


    # @return [Boolean] Whether the player holds every orb before the story moved on.
    def orbs_due?
      orbs = rule("orbs")
      gathered = rule("orbs_gathered")
      return false if orbs.nil? || orbs.empty? || gathered.nil? || rule("orb_event").nil?
      return false unless story_now[1][MAIN_PROGRESS].to_i < gathered

      orbs.all? { |id| @items.key?("i#{id}") && @items["i#{id}"] > 0 }
    end

    # Follows the story's companions: removals and joins passed, joins waiting for their gate.
    def companions(story, carried, done)
      removed = {}
      @t.removals.each do |row|
        key = key_of("r", row)
        next if done[key] || !passed?(row, story)

        done[key] = true
        (removed[row.actor] ||= []) << row
      end
      fresh = []
      story_joins.each do |row|
        key = key_of("j", row)
        state = done[key]
        if state.nil?
          next if carried && !carries?(row)
          next unless passed?(row, story)
          next done[key] = true if row.part.nil? || (carried && !before_log?(row))

          fresh << row
        elsif state != true && removed[row.actor]
          done[key] = true
          log("dropped the waiting join of {actor:#{row.persona}} at #{row.site}: the story took them away since")
        end
      end
      fresh.each { |row| note_join(row, carried, removed, done) }
      take_away(removed, fresh) if carried
      bring_waiting(done)
    end

    # Notes a join the player's story just got past.
    def note_join(row, carried, removed, done)
      key = key_of("j", row)
      later = (removed[row.actor] || []).any? { |removal| after?(removal, row) }
      return done[key] = true if later

      present = in_roster?(row.actor)
      done[key] = if present
                    carried && (row.rule != START_RULE || form?(row)) ? "c" : true
                  elsif carried
                    "c"
                  else
                    ledger["held"].delete(row.actor) ? "o" : true
                  end
    end

    # @return [Boolean] Whether a join brings another persona than the companion's main one.
    def form?(row)
      row.actor != row.persona
    end

    # Takes away the companions a story carried the player past the lasting removal of.
    def take_away(removed, fresh)
      return unless story_now[1][PLAYTHROUGH].to_i == 0

      removed.each do |actor, rows|
        lasting = rows.select { |row| row.first && before_log?(row) }
        next if lasting.empty? || actor == HERO || !in_roster?(actor)
        next if fresh.any? { |row| row.actor == actor && lasting.none? { |removal| after?(removal, row) } }

        @actions << ["leave", actor, lasting.map { |row| row.site }.join(", ")]
        @roster.reject! { |entry| entry[0] == actor }
        roster_changed
      end
    end

    # Lets the joins that wait for their gate in.
    def bring_waiting(done)
      story_joins.each do |row|
        key = key_of("j", row)
        state = done[key]
        next if state.nil? || state == true

        present = in_roster?(row.actor)
        next done[key] = true if present && state == "o"
        next unless reached?(row.gate)

        done[key] = true
        level = row.rule == START_RULE ? nil : row.gate
        next bring_in(row.persona, row.actor, level, "level #{row.gate} reached") unless present

        take_form(row) unless form_changed_since?(row, done)
        raise_level(row.persona, row.actor, level)
      end
    end

    # @return [Boolean] Whether an actor change at a join's place or later already set the
    #   companion's persona.
    def form_changed_since?(join, done)
      @t.actor_changes.any? do |change|
        change.actor == join.actor && done[key_of("a", change)] == true && (place_of(change) <=> place_of(join)) >= 0 &&
          change.calls.any? { |name, _ids, _once| name == :persona_change }
      end
    end

    # Turns a companion of the roster into the persona a join of theirs brings.
    def take_form(row)
      entry = @roster.find { |candidate| candidate[0] == row.actor }
      return unless entry && form?(row) && entry[1] != row.persona

      @actions << ["form", row.persona, row.site]
      entry[1] = row.persona
    end

    # Brings a companion into the roster, then raises them to the join's level and their story
    # values to what their join stands for.
    def bring_in(persona, main, level, reason)
      return if in_roster?(main)

      @actions << ["join", persona, level, reason]
      @roster << [main, persona, level.to_i, nil]
      roster_changed
      companion_values
    end

    # Raises a companion of the roster to a level.
    def raise_level(persona, main, level)
      return unless level

      @actions << ["raise", persona, level]
      entry = @roster.find { |candidate| candidate[0] == main }
      entry[2] = level if entry && entry[2] < level
    end

    # @return [Boolean] Whether the page that runs brings the companion along on a visit only.
    def visit_running?(main, site)
      site ? @t.joins.any? { |row| row.actor == main && row.site == site && temporary?(row) } : false
    end

    # @return [Array<Join>] The story's joins that last.
    def story_joins
      @t.kept(:story_joins) { @t.joins.reject { |row| temporary?(row) } }
    end

    # @return [Boolean] Whether a join only brings its companion along for a visit.
    def temporary?(row)
      !taking_back(row).empty?
    end

    # @return [Array<Removal>] The removals that take a join's companion away again.
    def taking_back(row)
      found = @t.kept(:taking_back) { {}.compare_by_identity }
      return found[row] if found.key?(row)

      found[row] = lasting_companion?(row.actor) ? [] : @t.removals.select { |removal| takes_back?(removal, row) }
    end

    # @return [Boolean] Whether a removal takes a join's companion away again in the same step.
    def takes_back?(removal, row)
      return false unless removal.actor == row.actor && removal.part == row.part && removal.step == row.step
      return false if removal.side && row.side && removal.side != row.side

      removal.site == row.site ? removal.index.to_i > row.index.to_i : marks_beyond?(removal, row)
    end

    # @return [Boolean] Whether a companion is in the roster on a visit only.
    def visiting?(id, story)
      visits = @t.kept(:visits) { @t.joins.select { |row| row.part && temporary?(row) }.group_by { |row| row.actor } }
      Array(visits[id]).any? { |row| passed?(row, story) && taking_back(row).none? { |removal| passed?(removal, story) } }
    end

    # @return [Array<Join>] The story's lasting joins of a companion.
    def joins_of(actor)
      by_actor = @t.kept(:joins_by_actor) do
        joins = {}
        story_joins.each { |row| (joins[row.actor] ||= []) << row if row.part }
        joins
      end
      by_actor[actor] || []
    end

    # @return [Boolean] Whether a companion is one of the story's.
    def story_companion?(actor)
      !joins_of(actor).empty?
    end

    # Lists the roster's companions the world's shared list takes, then lets the world's shared
    # companions join.
    #
    # @return [Array<Integer>] The companions the world takes.
    def note_roster
      story = story_now
      ids = @roster.map { |entry| entry[0] }.reject { |id| visiting?(id, story) }
      return [] if @sharing == "off" || @summary.nil?

      shared = @summary["comps"].to_a
      sharable = ids.select { |id| id != HERO && !shared.include?(id) && (@sharing == "all" || story_companion?(id)) }
      share_in(shared)
      sharable
    end

    # Lets the world's shared companions join at their gates.
    def share_in(shared)
      done = ledger["done"]
      lost = nil
      shared.each do |id|
        key = "s:#{id}"
        next if id == HERO || done[key] == SHARE_SETTLED

        lost ||= taken_for_good(done)
        next done[key] = SHARE_SETTLED if in_roster?(id) || lost[id] || joined?(id, done)

        first = joins_of(id).first
        next unless first || @sharing == "all"

        gate = first ? first.gate : start_level(id)
        next unless reached?(gate)

        done[key] = SHARE_SETTLED
        bring_in(first ? first.persona : id, id, first && first.rule != START_RULE ? gate : nil, "shared by the world")
      end
    end

    # @return [Boolean] Whether the player's story got past a join of the companion.
    def joined?(id, done)
      joins_of(id).any? { |row| carries?(row) && done[key_of("j", row)] == true }
    end

    # @return [Hash{Integer => Boolean}] The companions the story took away for good.
    def taken_for_good(done)
      lost = {}
      return lost unless story_now[1][PLAYTHROUGH].to_i == 0

      @t.removals.each { |row| lost[row.actor] = true if row.first && done[key_of("r", row)] }
      lost
    end

    # @return [Integer] A companion's start level, as the scripts tell it.
    def start_level(id)
      @starts[id] || 1
    end

    # Plays the chest of every Makina found and reached that the player lacks in their game.
    def check_makina
      @t.makina.each do |row|
        key = "i#{row.item}"
        next unless @items.key?(key) && @items[key] == 0 && found?(row.item) && reached?(row.level)

        @actions << ["replay", { "site" => row.site }, "makina:#{row.item} at level #{row.level}"]
      end
    end

    # @return [Boolean] Whether a player of the world found the item.
    def found?(id)
      story_now[2][[FOUND_MAP, id, FOUND_LETTER]] ? true : false
    end

    # @return [Boolean] Whether an item is a Makina.
    def makina?(id)
      @t.makina.any? { |row| row.item == id }
    end

    # Takes back every copy of an item beyond the first.
    #
    # @return [Boolean] Whether there were more.
    def trim_copies(id)
      key = "i#{id}"
      held = @items[key]
      return false unless held > 1

      @actions << ["trim", id, held - 1]
      @items[key] = 1
      true
    end

    # Hands out every found item unlocking a job or race the player lacks, and keeps one of each.
    def check_found_items
      found_ids.each do |id|
        key = "i#{id}"
        next unless @items.key?(key) && !makina?(id) && !trim_copies(id) && @items[key] == 0

        give("i", id, 1, "found:#{id}", false)
      end
    end

    # @return [Array<Integer>] The items found in the player's story and the world's.
    def found_ids
      stories = [story_now[2]]
      stories << @told[2] if @told
      keys = stories.flat_map { |selfs| selfs.keys.select { |key| selfs[key] && key[0] == FOUND_MAP && key[2] == FOUND_LETTER } }
      keys.map { |key| key[1] }.uniq
    end

    # Plays the recruit page of every story companion the roster lacks once the player's story
    # finished a route, at the join's gate, once per companion, unless the world shares none.
    def missed_companions
      story = story_now
      return if @sharing.to_s == "off" || ROUTES.none? { |route| cleared?(route, story) }

      done = ledger["done"]
      story_joins.each do |row|
        key = "m:#{row.actor}"
        next if done[key] || in_roster?(row.actor) || !past_by_route?(row, story)
        next if taken_away_since?(row, story, nil) || !reached?(row.gate)

        done[key] = true
        @actions << ["replay", { "site" => row.site }, key]
      end
    end

    # @return [Boolean] Whether a finished route carried the story past the row's part, whatever its
    #   marks, on the player's own side.
    def past_by_route?(row, own)
      return false if row.part.nil? || (RANKS[row.part] == RANKS["ad"] && !cleared?(row.part, own))

      row.side.nil? || row.side == side_for(row, own)
    end

    # Follows a story written into the player's.
    #
    # @param before [Array] The player's story before.
    def carried(before)
      drop_capped("the player plays the world's story already") if @mode == "world"
      review(before, false)
      review(story_now, true)
      drop_capped("the story the move led to is laid over the player's") unless @mode == "behind"
    end

    # Lists moving on from the parts before the world's.
    def story_unlocks
      world = @summary
      return [] unless world

      order = world_parts(world)
      current = world["part"].to_s
      own = own_part
      own_at = order.index(own)
      parts = order.take_while { |id| id != current }
      parts.select { |id| !ROUTES.include?(id) || id == own }.map do |id|
        got = own_at.nil? || own_at > order.index(id)
        into = next_part(id, world)
        gains = gains_of(id, into == :world ? current : into, id == own)
        [gate_of(id), "story", nil, part_name(id), got, !got && gate_open?(gate_of(id)), gains]
      end
    end

    # Lists what moving on from a part brings along.
    def gains_of(part, into, own)
      story = story_now
      told = @told
      carried = lambda do |row|
        next false unless carries?(row) && told

        (row.part == into && passed?(row, told, story)) || (own && row.part == part && passed?(row, told, story) && !passed?(row, story))
      end
      gains = {}
      add = lambda do |kind, id, amount|
        return if amount.to_i <= 0

        key = [kind, id]
        gains[key] = gains[key].to_i + amount
      end
      @t.key_items.each { |row| add.call("i", row.item, row.amount) if carried.call(row) }
      @t.rewards.each { |row| add.call(row.kind == :skill ? "skill" : row.kind.to_s, row.id, row.amount) if carried.call(row) }
      gains.map { |(kind, id), amount| [kind, id, amount] }
    end

    # Lists the companions the catch-up brings at their gate.
    def companion_unlocks(story, told)
      gates = {}
      if told
        story_joins.each do |row|
          next unless row.part && carries?(row) && passed?(row, told, story) && !taken_away_since?(row, story, told)

          gates[row.actor] = [gates[row.actor], row.gate].compact.min
        end
      end
      world = @summary
      if @sharing != "off" && world
        done = ledger["done"]
        lost = taken_for_good(done)
        world["comps"].to_a.each do |id|
          next if !in_roster?(id) && (done["s:#{id}"] == SHARE_SETTLED || lost[id] || joined?(id, done))

          first = joins_of(id).first
          gate = first ? first.gate : (@sharing == "all" ? start_level(id) : nil)
          gates[id] = [gates[id], gate].compact.min if gate && id != HERO
        end
      end
      gates.map do |id, gate|
        got = in_roster?(id)
        [gate, "companion", id, nil, got, !got && reached?(gate), []]
      end
    end

    # Lists every Makina a player of the world got.
    def makina_unlocks
      @t.makina.map do |row|
        key = "i#{row.item}"
        next unless @items.key?(key) && found?(row.item)

        got = @items[key] > 0
        [row.level, "makina", row.item, nil, got, !got && reached?(row.level), []]
      end.compact
    end
  end
end
