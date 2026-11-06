#----------------------------------------------------------------
#  world_overview_pages.rbx
#
#  Changelog:
#      Paulinchen  2026-11-06: Renamed add_options to offer_row, which the Mod Framework's scan no longer takes for a call of the old UI
#                            - Showed the pages in page views of the UI layer, their heads and panes as markup
#      Paulinchen  2026-11-05: Read the raid bosses' tiers and the troop of a pool's boss from the DLL's table
#                            - Read the Chaos route's variable from story_ids.rbx
#                            - Counted the pages' reads by the bridge's frame
#      Paulinchen  2026-11-01: Showed the pages in the Mod Framework's page views
#                            - Drew the portraits itself from the faces and figures the Mod Framework finds
#                            - Laid the World, Quests and Unlocks pages out and kept their folds in the DLL
#      Paulinchen  2026-10-31: Kept its row and read the mouse through the Mod Framework
#      Paulinchen  2026-10-24: Laid the pages of other mods out like the World page, with buttons and controls in the pane
#      Paulinchen  2026-10-23: Took the World page's note of the world from the DLL
#                            - Asked the catch-up for each member's factor as text
#                            - Read the world's part from the relay's summary of its story tracks
#                            - Labelled the objective with OBJECTIVE_LABEL
#      Paulinchen  2026-10-13: Left a story's temporary party and companions on a visit out of the Unlocks page's grid
#      Paulinchen  2026-10-12: Created
#
#----------------------------------------------------------------

# The World overview's pages laid out with a head, a list and a reading pane: the World page, the
# Quests page and a Raid World's Unlocks page, each a page view of the Mod Framework's UI layer
# (OverviewPage). The DLL lays each page out (OverviewPages in MGQOnline.Game) from what the script
# reads of the game; the script adds the pictures and the panes that name the game's things, and the
# view shows it and tells the folds.
#
# The Quests page reads the main quest and the side quests as Amira tells them and the companions'
# requests on the Pocket Castle's board from the game's events, without running them.
module MGQ_MpWorldOverview
  # Luka's actor, whose portrait heads the Unlocks page.
  LUKA = 1

  # The pages laid out with a head, a list and a reading pane.
  SPLIT_PAGES = [:world, :quests, :unlocks]

  # The topic that lays the World page out: "seats", "story" (nil, or "part" and "done"), "main"
  # (see quest_text), "sections" ([name, [boss names]] each), "bosses" ({boss name => [section,
  # tier]}) and "tiers" ({tier => [[stat, factor]]}) in; the page out, see model_of.
  WORLD_TOPIC = "overview.world"

  # The topic that lays the Quests page out: "main", "side" and "companion" (see quest_text) in;
  # the page out, see model_of.
  QUESTS_TOPIC = "overview.quests"

  # The topic that lays the Unlocks page out: "target", "level" and "unlocks" ([level, name, got,
  # due] each) in; the page out, see model_of.
  UNLOCKS_TOPIC = "overview.unlocks"

  # The topic that keeps whether the player opened or folded a group of a page: "page", "key" and
  # "open" in.
  FOLD_TOPIC = "overview.fold"

  # The whole parts a gauge's share crosses the bridge in, since no float crosses it.
  GAUGE_PARTS = 1_000_000

  # The kind of the companions' requests on the board, as the DLL names it.
  COMPANION = "companion"

  # A page's head: how a character looks or an icon in a framed box, its title with a note at the
  # right, and under it lines or a grid of columns; the entry picking the head shows, if any.
  Head = Struct.new(:looks, :icon, :title, :note, :lines, :grid, :entry)

  # A page's model as the DLL laid it out: its head, the rows of its list ([:none, text], [:fold,
  # Entry] or [:entry, Entry]) and what can be picked, the head's entry first.
  Model = Struct.new(:head, :rows, :picks)

  # A group or an entry of a page's list as the DLL describes it: its kind ("fold", "note", "quest",
  # "boss" or "level"), what its row shows (RowView, nil for the head's entry) and what it holds,
  # the DLL's description itself: ["fold", key, title, open], ["note", title, texts], ["quest",
  # kind, speaker, texts, number, title], ["boss", section, name, defeated, by, pane lines] or
  # ["level", level, unlocks (places in the list handed), got, due].
  Entry = Struct.new(:kind, :row, :value)

  # A level of the Unlocks page: the level, what it brings (MGQ_MpWorldCatchup::Unlock), whether the
  # player got all of it, and whether any of it is due.
  Level = Struct.new(:level, :unlocks, :got, :due)

  # What a list row shows: a label at the left, its text, a note at the right, whether it is dimmed,
  # and the share of a gauge, if any.
  RowView = Struct.new(:label, :text, :note, :dim, :gauge)

  # What the reading pane shows: its title, how the one it is about looks, and its lines, each
  # [:text, paragraph], [:item, PaneItem], [:gauge, share, text] or [:gap].
  Pane = Struct.new(:title, :looks, :lines)

  # A pane line naming something by its icon or how it looks, with a note at the right.
  PaneItem = Struct.new(:icon, :looks, :name, :note, :dim)

  # A member's level in the Unlocks page's grid.
  LEVEL_SHORT = "Lv %d"

  # How the pane titles a level once it passed.
  LEVEL_PASSED = "%s, passed"

  # What the pane calls moving on from a part.
  MOVING_ON = "Moving on from %s"

  # How a pane item names an amount above one.
  AMOUNT = "%s x%d"

  # Reads a page's model, every READ_FRAMES or once forget_model asked for it again.
  #
  # @param page [Symbol] One of SPLIT_PAGES.
  # @return [Model] The model; the same object while nothing changed, which the view goes by.
  def self.model(page)
    @models ||= {}
    @models_at ||= {}
    at = @models_at[page]
    return @models[page] if @models[page] && at && MGQ_Multiplayer::Bridge.frame_number - at < READ_FRAMES

    @models_at[page] = MGQ_Multiplayer::Bridge.frame_number
    built = case page
            when :world then world_model
            when :quests then quest_model
            else unlock_model
            end
    old = @models[page]
    @models[page] = old && old.to_a == built.to_a ? old : built
  rescue => e
    log_once([:model, page], "laying out the #{page} page failed: #{e.class}: #{e.message}")
    @models[page] = Model.new(nil, [], [])
  end

  # Has a page's model read again at its next look.
  #
  # @param page [Symbol] One of SPLIT_PAGES.
  def self.forget_model(page)
    @models_at.delete(page) if @models_at
  end

  # Lays the World page out through the DLL: the world's name, type, difficulty, players and story
  # at the top; the objective and in a Raid World every raid boss by its section in the list. The
  # script hands what only the game knows: Amira's objective and the raid bosses' tables.
  #
  # @return [Model] The model.
  def self.world_model
    world = MGQ_MpWorld.world
    counters = MGQ_MpWorldStory.world
    story = counters ? { "part" => counters["part"].to_s, "done" => Array(counters["done"]).map { |part| part.to_s } } : nil
    sections = MGQ_MpRaidBosses.sections.map { |section, names| [section.to_s, names.map { |name| name.to_s }] }
    pooled = MGQ_MpRaidPool.pools.keys.map { |key| MGQ_MpRaidPool.boss_key(key) }
    bosses = {}
    (sections.map { |_, names| names }.flatten + pooled).uniq.each { |name| bosses[name] = [section_of(name), tier_of(name)] }
    tiers = {}
    MGQ_MpRaidBosses.tiers.each { |tier, stats| tiers[tier] = stats.map { |stat, factor| [stat.to_s, factor.to_s] } }
    request = { "seats" => world ? world.seats.to_i : 0, "story" => story, "main" => quest_text(main_quest), "sections" => sections, "bosses" => bosses, "tiers" => tiers }
    data = model_of(MGQ_Multiplayer::Bridge.call(WORLD_TOPIC, request))
    data.head.title = world_name
    data.head.note = world_note
    data.head.icon = WORLD_ICON
    data
  end

  # Lays the Quests page out through the DLL: Amira with the main quest at the top, the side quests
  # numbered and the companion quests by each companion's name in the list, from the quests the
  # script reads of the game's events.
  #
  # @return [Model] The model.
  def self.quest_model
    request = { "main" => quest_text(main_quest), "side" => side_quests.map { |quest| quest_text(quest) },
                "companion" => companion_quests.map { |quest| quest_text(quest) } }
    data = model_of(MGQ_Multiplayer::Bridge.call(QUESTS_TOPIC, request))
    amira = $data_actors && $data_actors[AMIRA]
    data.head.looks = looks(amira) if amira
    data
  end

  # Lays the Unlocks page out through the DLL: Luka with the formation's catch-up experience at the
  # top; the levels whose every unlock the player got folded under Passed, the others under Coming
  # up. The script adds the formation's grid and Luka's looks.
  #
  # @return [Model] The model.
  def self.unlock_model
    target = MGQ_MpWorldCatchupExp.target
    @unlocks = MGQ_MpWorldCatchup.unlocks
    request = { "target" => target, "level" => MGQ_MpWorldCatchup.counted_level,
                "unlocks" => @unlocks.map { |unlock| [unlock.level, unlock.name.to_s, unlock.got ? true : false, unlock.due ? true : false] } }
    data = model_of(MGQ_Multiplayer::Bridge.call(UNLOCKS_TOPIC, request))
    hero = $game_actors ? $game_actors[LUKA] : nil
    data.head.looks = looks(hero) if hero
    data.head.grid = $game_party.battle_members.select { |actor| MGQ_MpWorldCatchup.counts?(actor) }.map { |actor| exp_cells(actor, target) } if target
    data
  end

  # Writes a quest the way the DLL takes it.
  #
  # @param quest [Quest, nil] The quest.
  # @return [Array, nil] [speaker, texts]; nil for none.
  def self.quest_text(quest)
    quest ? [quest.speaker, quest.texts] : nil
  end

  # Reads a page the DLL laid out.
  #
  # @param answer [Hash, nil] "head" ("title", "note", "lines", "entry"), "rows" (["none", text], or
  #   ["fold"] or ["entry"] with the row's view [label, text, note, dim, gauge in GAUGE_PARTS] and
  #   the entry, see Entry) and "picks" (each pick's place among the rows, -1 for the head's entry).
  # @return [Model] The model; an empty one while the DLL did not answer.
  def self.model_of(answer)
    return Model.new(Head.new(nil, nil, "", nil, [], nil, nil), [], []) unless answer

    told = answer["head"]
    head = Head.new(nil, nil, told["title"].to_s, told["note"], Array(told["lines"]), nil, told["entry"] ? Entry.new(told["entry"][0], nil, told["entry"]) : nil)
    rows = answer["rows"].map do |kind, view, value|
      next [:none, view.to_s] if kind == "none"

      label, text, note, dim, gauge = view
      [kind == "fold" ? :fold : :entry, Entry.new(value[0], RowView.new(label, text.to_s, note, dim ? true : false, gauge && gauge.to_f / GAUGE_PARTS), value)]
    end
    picks = answer["picks"].map { |place| place < 0 ? head.entry : rows[place][1] }
    Model.new(head, rows, picks)
  end

  # Tells a formation member's catch-up experience for the Unlocks page's head.
  #
  # @param actor [Game_Actor] The member.
  # @param target [Integer] The level characters catch up to.
  # @return [Array<String>] Their name, level and factor.
  def self.exp_cells(actor, target)
    [actor.name.to_s, LEVEL_SHORT % actor.base_level, MGQ_MpWorldCatchupExp.factor_text(actor.base_level, target)]
  end

  # Tells what the reading pane shows of an entry: a note or a quest with its paragraphs, a
  # companion's request beside how they look, a raid boss as the DLL wrote its pane, or what a
  # level brings, see level_pane.
  #
  # @param entry [Entry, nil] The entry.
  # @return [Pane, nil] The pane; nil for nothing picked and for a group.
  def self.pane_of(entry)
    return nil unless entry

    value = entry.value
    case entry.kind
    when "note" then Pane.new(value[1].to_s, nil, paragraphs(value[2]))
    when "quest" then Pane.new(value[5].to_s, value[1] == COMPANION ? looks_of(value[2]) : nil, paragraphs(value[3]))
    when "boss"
      lines = value[5].map { |kind, text, share| kind == "gauge" ? [:gauge, share.to_f / GAUGE_PARTS, text] : [:text, text] }
      Pane.new(value[2].to_s, nil, lines)
    when "level" then level_pane(Level.new(value[1], value[2].map { |place| Array(@unlocks)[place] }.compact, value[3], value[4]))
    end
  end

  # Lays texts out as paragraphs with a gap between two.
  #
  # @param texts [Array<String>] The texts.
  # @return [Array<Array>] The pane's lines.
  def self.paragraphs(texts)
    texts.each_with_index.inject([]) { |lines, (text, index)| lines + (index > 0 ? [[:gap]] : []) + [[:text, text]] }
  end

  # Lays a level out for the pane: what it brings in groups half a line apart, the key items and the
  # items that unlock a job or a race first, then moving on, the companions, the skills, the Makina and
  # the other items; a note every one of them shares stands once in the title.
  #
  # @param entry [Level] The level.
  # @return [Pane] The pane.
  def self.level_pane(entry)
    groups = Hash.new { |hash, key| hash[key] = [] }
    entry.unlocks.each do |unlock|
      note = unlock.got ? DONE : (unlock.due ? DUE : nil)
      case unlock.kind
      when :story
        groups[:story] << PaneItem.new(nil, nil, MOVING_ON % unlock.name, note, unlock.got)
        (unlock.gains || []).each do |gain|
          name = gain.amount.to_i > 1 ? AMOUNT % [gain.name, gain.amount] : gain.name
          groups[gain.kind] << PaneItem.new(gain.icon, nil, name, note, unlock.got)
        end
      when :companion
        actor = unlock.id && $data_actors ? $data_actors[unlock.id] : nil
        groups[:companion] << PaneItem.new(nil, actor ? looks(actor) : nil, unlock.name, note, unlock.got)
      else
        groups[:makina] << PaneItem.new(unlock.icon, nil, unlock.name, note, unlock.got)
      end
    end
    kinds = [:key, :unlock, :story, :companion, :skill, :makina, :item].map { |kind| groups[kind] }.reject(&:empty?)
    title = LEVEL_HEADING % entry.level
    title = LEVEL_PASSED % title if entry.got
    notes = kinds.flatten.map { |item| item.note }.uniq
    if notes.size == 1
      title = [title, notes.first].join(TITLE_JOIN) if notes.first && !entry.got
      kinds.flatten.each { |item| item.note = nil }
    end
    lines = kinds.map { |items| items.map { |item| [:item, item] } }.inject { |all, group| all + [[:gap]] + group }
    Pane.new(title, nil, lines || [])
  end

  # Runs through a list of commands as the game would run it now, without running any.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param depth [Integer] How many calls deep the list is.
  # @param network [Boolean] Whether the branches on Amira's network hold as the game compares
  #   them, see branch_holds?.
  # @yieldparam kind [Symbol] :message (a message shown), :mark (the start of a quest, see
  #   QUEST_COUNT) or :call (a common event about to be called).
  # @yieldparam value [String, Integer, nil] The message as plain text, or the common event.
  # @yieldparam indent [Integer] The command's indent.
  # @yieldparam level [Integer] How many calls deep it is.
  # @yieldparam speaker [String, nil] The message's speaker.
  # @yieldreturn [Symbol, nil] :stop ends the walk, :skip leaves a call out.
  # @return [Symbol, nil] :stop when a block ended the walk.
  def self.walk(list, depth, network, &block)
    index = 0
    jumps = 0
    skip = nil
    held = {}
    while index < list.size
      command = list[index]
      index += 1
      indent = command.indent
      next if skip && indent > skip

      skip = nil
      params = command.parameters
      case command.code
      when 111
        held[indent] = branch_holds?(params, network)
        skip = indent unless held[indent]
      when 411 then skip = indent if held[indent]
      when 402 then skip = indent unless params[0] == 0
      when 403 then skip = indent
      when 101
        return :stop if block.call(:message, plain_message(list, index), indent, depth, speaker_of(list, index)) == :stop
      when 122
        return :stop if quest_mark?(params) && block.call(:mark, nil, indent, depth, nil) == :stop
      when 117
        called = depth < OBJECTIVE_DEPTH ? $data_common_events[params[0]] : nil
        next unless called

        answer = block.call(:call, params[0], indent, depth, nil)
        return :stop if answer == :stop
        return :stop if answer != :skip && walk(called.list || [], depth + 1, network, &block) == :stop
      when 119
        jumps += 1
        label = jumps <= OBJECTIVE_JUMPS ? list.index { |other| other.code == 118 && other.parameters[0] == params[0] } : nil
        return nil unless label

        index = label + 1
      when 115 then return :stop
      end
    end
    nil
  end

  # Reports whether a command marks the start of a quest (see QUEST_COUNT).
  #
  # @param params [Array] The parameters of a variable's command.
  # @return [Boolean] Whether it does.
  def self.quest_mark?(params)
    params[0] == QUEST_COUNT && params[1] == QUEST_COUNT && params[2] == 0 && params[3] == 0 && params[4] == 1
  end

  # Reports whether a branch holds now: on a switch, a variable, a party member, an item or one of
  # the game's own checks; any other branch does not.
  #
  # Amira's network counts only where asked, since the objective shows whether she would tell it or
  # not.
  #
  # @param params [Array] The branch's parameters.
  # @param network [Boolean] Whether a branch on Amira's network compares as the game does.
  # @return [Boolean] Whether it holds.
  def self.branch_holds?(params, network = false)
    case params[0]
    when 0 then $game_switches[params[1]] == (params[2] == 0)
    when 1
      return false if params[1] == NETWORK_VARIABLE && !network

      value = $game_variables[params[1]].to_i
      other = params[2] == 0 ? params[3].to_i : $game_variables[params[3]].to_i
      [value == other, value >= other, value <= other, value > other, value < other, value != other][params[4]] ? true : false
    when 4 then params[2] == 0 && $game_party.all_members.any? { |actor| actor.id == params[1] }
    when 8
      item = $data_items[params[1]]
      item ? $game_party.has_item?(item) : false
    when 12 then check_holds?(params[1].to_s)
    else false
    end
  end

  # Reports whether one of the game's own checks holds, such as "actor_class_level_over?(1, 151, 10)".
  #
  # Only question methods with whole numbers run, since any other script might change the game.
  #
  # @param script [String] The branch's script.
  # @return [Boolean] Whether it holds; false for any other script.
  def self.check_holds?(script)
    match = script.strip.match(/\A(\w+\?)\(([\d,\s]*)\)\z/)
    return false unless match && Game_Interpreter.method_defined?(match[1])

    Game_Interpreter.new.send(match[1], *match[2].split(",").map { |number| number.to_i }) ? true : false
  rescue => e
    log_once([:check, script], "a quest's check \"#{script}\" failed: #{e.class}: #{e.message}")
    false
  end

  # Reads the message whose lines follow a command as plain text: one line, without the speaker's
  # name and the text codes, a variable's and a companion's code replaced by its value and name.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param index [Integer] The place of the message's first line.
  # @return [String] The text.
  def self.plain_message(list, index)
    lines = []
    while list[index] && list[index].code == 401
      lines << list[index].parameters[0].to_s
      index += 1
    end
    text = lines.join(" ").gsub(SPEAKER, "")
    text = text.gsub(/\\V\[(\d+)\]/i) { $game_variables[$1.to_i].to_s }
    text = text.gsub(/\\N\[(\d+)\]/i) { (actor = $game_actors[$1.to_i]) ? actor.name.to_s : "" }
    TEXT_CODES.inject(text) { |plain, code| plain.gsub(code, "") }.gsub(/\s+/, " ").strip
  end

  # Reads the speaker's name at a message's start.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param index [Integer] The place of the message's first line.
  # @return [String, nil] The name, without text codes; nil for a message without a speaker.
  def self.speaker_of(list, index)
    line = list[index] && list[index].code == 401 ? list[index].parameters[0].to_s : ""
    name = line[/\\n<([^>]*)>/, 1] || line[/\A\s*【([^】]*)】/, 1]
    name = TEXT_CODES.inject(name) { |plain, code| plain.gsub(code, "") }.strip if name
    name && !name.empty? ? name : nil
  end

  # Reads the main quest: every message Amira's objective shows now, her side quests left out.
  #
  # @return [Quest, nil] The quest; nil when she tells none.
  def self.main_quest
    event = $data_common_events && $data_common_events[OBJECTIVE_EVENT]
    return nil unless event

    texts = []
    speaker = nil
    walk(event.list || [], 0, false) do |kind, value, indent, level, who|
      if kind == :call
        SIDE_EVENTS.include?(value) ? :skip : nil
      elsif kind == :message && !value.empty? && (indent > 0 || level > 0)
        speaker ||= who
        texts << value
        nil
      end
    end
    texts.empty? ? nil : Quest.new(:main, speaker, texts, nil)
  end

  # Reads the side quests Amira tells now, from her list for the story's place (see SIDE_EVENTS).
  #
  # @return [Array<Quest>] The quests.
  def self.side_quests
    id = SIDE_EVENTS[$game_variables[MGQ_MpStoryIds.route_variables[2].to_i].to_i >= CHAOS_SIDE_STEP ? 1 : 0]
    event = $data_common_events && $data_common_events[id]
    event ? quests_of(event.list || [], :side) : []
  end

  # Reads the companions' requests on the Pocket Castle's board now.
  #
  # @return [Array<Quest>] The requests, each by the companion who left it.
  def self.companion_quests
    quests_of(board_list, :companion)
  end

  # Reads the board's list of commands, once a session.
  #
  # @return [Array<RPG::EventCommand>] The commands; none when the map or the event is missing.
  def self.board_list
    return @board_list if @board_list

    map = load_data(format("Data/Map%03d.rvdata2", BOARD_MAP))
    event = map.events[BOARD_EVENT]
    page = event && event.pages.find { |candidate| candidate.list.any? { |command| command.code == 122 && quest_mark?(command.parameters) } }
    log("the Pocket Castle's board (map #{BOARD_MAP}, event #{BOARD_EVENT}) has no entries to read") unless page
    @board_list = page ? page.list : []
  rescue => e
    log_once(:board, "reading the Pocket Castle's board failed: #{e.class}: #{e.message}")
    @board_list = []
  end

  # Reads the quests a list tells now, each from its mark (see quest_mark?) to the end of its block.
  #
  # Only the first speaker's messages count, so the others' remarks in between stay out.
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @param kind [Symbol] The quests' kind, :side (numbered) or :companion.
  # @return [Array<Quest>] The entries that say anything.
  def self.quests_of(list, kind)
    entries = []
    entry = nil
    walk(list, 0, true) do |kind, value, indent, level, speaker|
      if kind == :mark
        entry = { :indent => indent, :level => level, :speaker => nil, :texts => [] }
        entries << entry
      elsif kind == :message && entry
        if level < entry[:level] || (level == entry[:level] && indent < entry[:indent])
          entry = nil
        elsif !value.empty?
          entry[:speaker] ||= speaker
          entry[:texts] << value if speaker == entry[:speaker]
        end
      end
      nil
    end
    told = entries.reject { |found| found[:texts].empty? }
    told.each_with_index.map do |found, index|
      Quest.new(kind, found[:speaker], found[:texts], kind == :side ? index + 1 : nil, kind == :companion ? looks_of(found[:speaker]) : nil)
    end
  end

  # Finds how a companion looks by their name: the one of that name in the party, else the first
  # character of the game with that name and a map sprite.
  #
  # Companions with several forms share a name, so the party's form comes first.
  #
  # @param name [String, nil] The companion's name.
  # @return [Looks, nil] How they look; nil for a name no character has.
  def self.looks_of(name)
    return nil if name.to_s.empty?

    members = $game_party.all_members + ($game_party.respond_to?(:stand_members) ? $game_party.stand_members.to_a : [])
    member = members.find { |actor| actor && actor.name.to_s == name && !actor.character_name.to_s.empty? }
    return looks(member) if member

    @looks_by_name ||= ($data_actors || []).compact.reverse.each_with_object({}) do |actor, found|
      found[actor.name.to_s] = actor unless actor.character_name.to_s.empty?
    end
    actor = @looks_by_name[name]
    actor ? looks(actor) : nil
  rescue => e
    log_once([:looks, name], "finding how #{name} looks failed: #{e.class}: #{e.message}")
    nil
  end

  # Reads how a character looks.
  #
  # @param actor [Game_Actor, RPG::Actor] The character.
  # @return [Looks] How they look.
  def self.looks(actor)
    Looks.new(actor.character_name.to_s, actor.character_index.to_i, actor.face_name.to_s, actor.face_index.to_i)
  end

  # Tells how the Quests page shows Amira and the companions, as Player.ini keeps it.
  #
  # @return [String] SPRITES or FACES.
  def self.portraits
    @portraits ||= PORTRAITS.find { |choice| choice.downcase == MGQ_Multiplayer::Player.setting(PORTRAIT_SETTING).to_s.strip.downcase } || PORTRAITS.first
  end

  # Picks how the Quests page shows Amira and the companions and keeps it in Player.ini.
  #
  # @param choice [String] SPRITES or FACES; another keeps the first.
  def self.choose_portraits(choice)
    @portraits = PORTRAITS.include?(choice) ? choice : PORTRAITS.first
    MGQ_Multiplayer::Player.store(PORTRAIT_SETTING, @portraits)
    log("the Quests page shows #{@portraits.downcase}")
  rescue => e
    log("keeping the Quests page's portraits FAILED: #{e.class}: #{e.message}")
  end

  # Offers the Quests page's portraits as a row of the Mod Config, kept in Player.ini.
  def self.offer_row
    added = Mod_Framework::Options.keep(PORTRAIT_OPTION, MGQ_Multiplayer::OPTION_PREFIX + PORTRAIT_OPTION_NAME, PORTRAIT_OPTION_HELP, lambda { PORTRAITS },
                                        lambda { portraits }, lambda { |choice| choose_portraits(choice) })
    log(added ? "added the Quest Portraits to Options > Mods" : "no Quest Portraits in Options > Mods, see the Mod Framework's log")
  end

  # Finds the section of a pool's boss: its milestone's or OPTIONAL's, else that of the troop a
  # fight with its own name belongs to.
  #
  # @param name [String] The pool's boss, see MGQ_MpRaidPool.boss_key.
  # @return [String, nil] The section, nil for a boss the tables lack.
  def self.section_of(name)
    MGQ_MpRaidBosses.section(name) || MGQ_MpRaidBosses.section(MGQ_MpRaidBosses.troop_of_key(name))
  end

  # Finds the tier of a raid boss by its name, as section_of finds its section.
  #
  # @param name [String] The boss's name.
  # @return [Integer, nil] Its tier, nil for a name the tables lack.
  def self.tier_of(name)
    MGQ_MpRaidBosses.key_tier(name) || MGQ_MpRaidBosses.tier(MGQ_MpRaidBosses.troop_of_key(name))
  end

  # Tells the pane of a pick.
  #
  # @param data [Model] The page's model.
  # @param pick [Object, nil] The item picked, a model's row [:entry, Entry], or :head for the
  #   head's entry; nil for none.
  # @return [Pane, nil] The pane.
  def self.pick_pane(data, pick)
    return data.head && data.head.entry ? pane_of(data.head.entry) : nil if pick == :head

    pick.is_a?(Array) && pick[0] == :entry ? pane_of(pick[1]) : nil
  end

  # Opens or folds a group of an own page, which the DLL keeps while the game runs; the page reads
  # its model anew.
  #
  # @param page [Symbol] One of SPLIT_PAGES.
  # @param key [String] The group.
  # @param open [Boolean] Whether it is open now.
  def self.fold(page, key, open)
    MGQ_Multiplayer::Bridge.call(FOLD_TOPIC, "page" => page.to_s, "key" => key.to_s, "open" => open ? true : false)
    forget_model(page)
    log("#{open ? 'opened' : 'folded'} #{key} on the #{page} page")
  end

  # Makes the list row of a model's row: a line of text, a group with whether it is open, or an
  # entry with its label, its text, its note at the right, dimmed, and a thin gauge.
  #
  # @param item [Array] The model's row: [:none, text], [:fold, Entry] or [:entry, Entry].
  # @return [Hash] The row.
  def self.entry_row(item)
    kind, value = item
    return { :none => value.to_s } if kind == :none

    _kind, key, title, open = value.value
    return { :group => key, :text => title.to_s, :open => open ? true : false } if kind == :fold

    view = value.row
    row = { :text => view.text.to_s, :right_color => :dim, :faint => view.dim ? true : false }
    row[:label] = view.label if view.label
    row[:right] = view.note if view.note
    row[:gauge] = view.gauge if view.gauge
    row
  end

  # Tells the picture behind an own page: Amira's Library picture faintly behind the Quests page.
  #
  # @param page [Symbol] One of SPLIT_PAGES.
  # @return [Hash, nil] The view's backdrop, nil for none.
  def self.backdrop(page)
    page == :quests ? { :portrait => AMIRA, :opacity => BACKDROP_OPACITY, :anchor => :bottom_right } : nil
  end

  # Tells how a character's picture shows, as the Quest Portraits row picks: by their face, else
  # by their map sprite.
  #
  # @param looks [Looks] How they look.
  # @return [Hash] { :face } or { :figure }, as image takes them.
  def self.picture_of(looks)
    portraits == FACES && !looks.face_name.to_s.empty? ? { :face => looks } : { :figure => looks }
  end

  # An own page of the overview, World, Quests or Unlocks: a page view of a head, the model's rows
  # in their groups, and a reading pane of the entry or the head picked.
  class OverviewPage < UI::Component
    # Side of a portrait or an icon in the head.
    HEAD_PICTURE = 64

    # Side of a portrait in the pane's title.
    PANE_PICTURE = 48

    # Side of a portrait beside a thing named in the pane.
    ITEM_PICTURE = 24

    # Room a gap between two groups of the pane's lines takes.
    GAP = 8

    # The page: :world, :quests or :unlocks.
    param :kind

    # The item picked: a model's row, or :head for the head's entry.
    state :picked, nil

    # The model is read only while its page shows, since each read asks the DLL and walks events.
    watch(:every => WATCH_FRAMES) { MGQ_MpWorldOverview.page == kind ? [MGQ_MpWorldOverview.model(kind).object_id, MGQ_MpWorldOverview.portraits] : nil }

    # Picks the head's entry first, such as the main quest.
    def setup
      head = MGQ_MpWorldOverview.model(kind).head
      self.picked = :head if head && head.entry
    end

    # Describes the page.
    def render
      overview = MGQ_MpWorldOverview
      data = overview.model(kind)
      head = data.head
      view = { id: :"overview_#{kind}", row: ->(item) { overview.entry_row(item) }, bind: :picked, height: :fill,
               on_fold: ->(group, open) { overview.fold(kind, group, open) } }
      backdrop = overview.backdrop(kind)
      view[:backdrop] = backdrop if backdrop
      page_view data.rows, view do
        page_head(head && head.entry ? { pick: :head } : {}) { head_of(head) } if head
        page_pane { pane_of(overview.pick_pane(data, picked)) }
      end
    end

    private

    # Describes the head: a portrait or an icon, the title with its note, and its lines or a grid.
    #
    # @param head [Head] The head.
    def head_of(head)
      stack row: true do
        if head.looks
          image(MGQ_MpWorldOverview.picture_of(head.looks).merge(width: HEAD_PICTURE, height: HEAD_PICTURE))
        elsif head.icon
          text "\\I[#{head.icon}]", escapes: true
        end
        stack grow: 1 do
          stack row: true do
            text head.title.to_s, typo: :subtitle1, most_lines: 1, grow: 1
            text(head.note.to_s, color: :dim) if head.note
          end
          Array(head.lines).each { |line| text line.to_s, typo: :body2, wrap: true }
          Array(head.grid).each do |name, level, factor|
            stack(row: true) { [[name, nil], [level, nil], [factor, :title]].each { |cell, color| grid_cell(cell, color) } }
          end
        end
      end
    end

    # Describes a cell of the head's grid.
    #
    # @param cell [String] Its text.
    # @param color [Symbol, nil] Its color, nil for the plain one.
    def grid_cell(cell, color)
      params = { typo: :body2, grow: 1 }
      params[:color] = color if color
      text cell.to_s, params
    end

    # Describes the pane: its title beside a portrait, then its lines.
    #
    # @param pane [Pane, nil] The pane, nil for nothing picked.
    def pane_of(pane)
      return unless pane

      stack row: true do
        image(MGQ_MpWorldOverview.picture_of(pane.looks).merge(width: PANE_PICTURE, height: PANE_PICTURE)) if pane.looks
        text pane.title.to_s, typo: :subtitle2, wrap: true, grow: 1
      end
      pane.lines.each do |kind, value, extra|
        case kind
        when :text then text value.to_s, wrap: true
        when :gap then stack(height: GAP) {}
        when :gauge then progress value: value.to_f, max: 1, size: :small, text: extra.to_s
        when :item then item_of(value)
        end
      end
    end

    # Describes a thing the pane names: its icon or portrait, its name, dimmed once had, and its
    # note at the right.
    #
    # @param item [PaneItem] The thing.
    def item_of(item)
      stack row: true do
        if item.icon
          text "\\I[#{item.icon}]", escapes: true
        elsif item.looks
          image(MGQ_MpWorldOverview.picture_of(item.looks).merge(width: ITEM_PICTURE, height: ITEM_PICTURE))
        end
        name = { grow: 1 }
        name[:color] = :dim if item.dim
        text item.name.to_s, name
        text(item.note.to_s, typo: :caption, color: :dim) if item.note
      end
    end
  end
end

# The Quest Portraits row of the Mod Config.

begin
  MGQ_MpWorldOverview.offer_row
rescue => e
  MGQ_MpWorldOverview.log("options FAILED: #{e.class}: #{e.message}")
end
