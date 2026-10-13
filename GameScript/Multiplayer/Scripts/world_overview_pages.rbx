#----------------------------------------------------------------
#  world_overview_pages.rbx
#
#  Changelog:
#      Paulinchen  2026-10-13: Left a story's temporary party and companions on a visit out of the Unlocks page's grid
#      Paulinchen  2026-10-12: Created
#
#----------------------------------------------------------------

# The World overview's pages laid out with a head, a list and a reading pane: the World page, the
# Quests page and a Raid World's Unlocks page. A page's model names what its head shows, the rows
# of its list and what the pane shows of the entry picked; one drawing serves every such page.
# Up and Down or a click pick an entry or a group, confirm or a click folds or opens a group, Page
# Up and Page Down and the mouse wheel scroll.
#
# The Quests page reads the main quest and the side quests as Amira tells them and the companions'
# requests on the Pocket Castle's board from the game's events, without running them.
module MGQ_MpWorldOverview
  # Luka's actor, whose portrait heads the Unlocks page.
  LUKA = 1

  # The pages laid out with a head, a list and a reading pane.
  SPLIT_PAGES = [:world, :quests, :unlocks]

  # A page's head: how a character looks or an icon in a framed box, its title with a note at the
  # right, and under it lines or a grid of columns; the entry picking the head shows, if any.
  Head = Struct.new(:looks, :icon, :title, :note, :lines, :grid, :entry)

  # A page's model: its head, the rows of its list ([:none, text], [:fold, Fold] or [:entry, entry])
  # and what can be picked, the head's entry first.
  Model = Struct.new(:head, :rows, :picks)

  # A group's row, which folds its entries away until it is opened again.
  Fold = Struct.new(:key, :title, :open)

  # A text of the World page: its title and its messages.
  Note = Struct.new(:title, :texts)

  # A raid boss of the World page with its section.
  BossEntry = Struct.new(:boss, :section)

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

  # What the World page says of the players online.
  PLAYERS_LINE = "Players online: %s"

  # What the World page says of a Raid World's story.
  STORY_LINE = "Story: %s"

  # What the World page says of a Classic world's story.
  CLASSIC_STORY = "Each party plays its leader's story."

  # The World page's heading over a section's raid bosses, with how many it holds.
  BOSS_SECTION = "%s (%d)"

  # What the World page says of a Raid World without raid bosses to list.
  NO_BOSSES = "No raid bosses yet."

  # What the World page says of raid bosses in a Classic world.
  CLASSIC_BOSSES = "Raid bosses fight in Raid Worlds."

  # How the pane tells a raid boss's tier and what it changes.
  TIER_LINE = "Tier %d: enemies have %s."

  # How the pane tells one stat a tier changes and its factor.
  TIER_STAT = "%s x%s"

  # The names of the stats a tier changes.
  TIER_STATS = { :mhp => "HP", :def => "DEF", :mdf => "MDF", :atk => "ATK", :mat => "MAT", :agi => "AGI", :luk => "LUK", :mmp => "MP" }

  # How the pane tells who last hurt a raid boss.
  LAST_HURT = "Last hurt by %s."

  # What the list and the pane say of a defeated raid boss.
  DEFEATED = "Defeated"

  # The note of the Unlocks page's head with the player's level.
  YOUR_LEVEL_NOTE = "Your level %d"

  # A member's level in the Unlocks page's grid.
  LEVEL_SHORT = "Lv %d"

  # The Unlocks page's folded group of the levels whose every unlock the player got.
  PASSED = "Passed (%d)"

  # The Unlocks page's group of the levels still to come.
  COMING_UP = "Coming up (%d)"

  # The mark of a folded group.
  FOLDED = "▸ "

  # The mark of an opened group.
  UNFOLDED = "▾ "

  # What the pane says of a group, by whether it is open.
  FOLD_HINT = { true => "Enter or a click folds this group.", false => "Enter or a click opens this group." }

  # How the pane titles a level once it passed.
  LEVEL_PASSED = "%s, passed"

  # What the pane calls moving on from a part.
  MOVING_ON = "Moving on from %s"

  # How a pane item names an amount above one.
  AMOUNT = "%s x%d"

  # Reports whether a page is laid out with a head, a list and a pane.
  #
  # @param page [Symbol] The page.
  # @return [Boolean] Whether it is.
  def self.split_page?(page)
    SPLIT_PAGES.include?(page)
  end

  # Reads a page's model, every READ_FRAMES or once forget_model asked for it again.
  #
  # @param page [Symbol] One of SPLIT_PAGES.
  # @return [Model] The model; the same object while nothing changed, which the drawing goes by.
  def self.model(page)
    @models ||= {}
    @models_at ||= {}
    at = @models_at[page]
    return @models[page] if @models[page] && at && Graphics.frame_count - at < READ_FRAMES && Graphics.frame_count >= at

    @models_at[page] = Graphics.frame_count
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

  # Lays the World page out: the world's name, type, difficulty, players and story at the top; the
  # objective and in a Raid World every raid boss by its section in the list.
  #
  # @return [Model] The model.
  def self.world_model
    raid = MGQ_MpCoop::Scope.raid?
    world = MGQ_MpWorld.world
    seats = world ? world.seats.to_i : 0
    online = rows.size
    lines = [PLAYERS_LINE % (seats > 0 ? PLAYERS_OF % [online, seats] : online.to_s)]
    lines << (raid ? STORY_LINE % world_story_text : CLASSIC_STORY)
    note = [WORLD_TYPES[raid], difficulty_name || PER_PLAYER].join(TITLE_JOINT)
    head = Head.new(nil, WORLD_ICON, world_name, note, lines, nil, nil)
    list = []
    main = main_quest
    list << [:entry, Note.new(WORLD_LABELS[:objective], main.texts)] if main
    sections = raid ? boss_sections : []
    sections.each do |section, bosses|
      add_group(list, :world, section, BOSS_SECTION % [section, bosses.size], true, bosses.map { |boss| BossEntry.new(boss, section) })
    end
    list << [:none, raid ? NO_BOSSES : CLASSIC_BOSSES] if sections.empty?
    Model.new(head, list, picks_of(list))
  end

  # Lays the Quests page out: Amira with the main quest at the top, the side quests numbered and
  # the companion quests by each companion's name in the list.
  #
  # @return [Model] The model.
  def self.quest_model
    main = main_quest
    amira = $data_actors && $data_actors[AMIRA]
    head = Head.new(amira ? looks(amira) : nil, nil, QUEST_TITLES[:main], nil, [main ? main.first : NO_QUESTS], nil, main)
    list = []
    [[:side, side_quests], [:companion, companion_quests]].each do |kind, quests|
      add_group(list, :quests, kind, QUEST_HEADINGS[kind] % quests.size, true, quests, NO_QUESTS)
    end
    Model.new(head, list, (main ? [main] : []) + picks_of(list))
  end

  # Lays the Unlocks page out: Luka with the formation's catch-up experience at the top; the levels
  # whose every unlock the player got folded under Passed, the others under Coming up.
  #
  # @return [Model] The model.
  def self.unlock_model
    target = MGQ_MpWorldCatchupExp.target
    level = MGQ_MpWorldCatchup.counted_level
    hero = $game_actors ? $game_actors[LUKA] : nil
    grid = target ? $game_party.battle_members.select { |actor| MGQ_MpWorldCatchup.counts?(actor) }.map { |actor| exp_cells(actor, target) } : nil
    head = Head.new(hero ? looks(hero) : nil, nil, target ? EXP_HEADING % target : EXP_HEADING_NONE, level ? YOUR_LEVEL_NOTE % level : nil,
                    target ? [] : [NO_CATCH_UP], grid, nil)
    levels = MGQ_MpWorldCatchup.unlocks.group_by { |unlock| unlock.level }.sort.map do |at, unlocks|
      Level.new(at, unlocks, unlocks.all? { |unlock| unlock.got }, unlocks.any? { |unlock| unlock.due })
    end
    passed, coming = levels.partition { |entry| entry.got }
    list = []
    add_group(list, :unlocks, :passed, PASSED % passed.size, false, passed) unless passed.empty?
    add_group(list, :unlocks, :coming, COMING_UP % coming.size, true, coming) unless levels.empty?
    list << [:none, NOTHING_UNLOCKED] if levels.empty?
    Model.new(head, list, picks_of(list))
  end

  # Adds a group to a list: its row, which folds it, and while open its entries, or a text without any.
  #
  # @param list [Array<Array>] The list's rows.
  # @param page [Symbol] The page.
  # @param key [Object] The group's key, which keeps whether it is open.
  # @param title [String] The group's title.
  # @param open [Boolean] Whether it is open until the player folds or opens it.
  # @param entries [Array] Its entries.
  # @param empty [String, nil] What it says without entries.
  def self.add_group(list, page, key, title, open, entries, empty = nil)
    fold = Fold.new(key, title, fold_open?(page, key, open))
    list << [:fold, fold]
    return unless fold.open

    list << [:none, empty] if entries.empty? && empty
    entries.each { |entry| list << [:entry, entry] }
  end

  # Tells whether a group of a page is open: as the player left it, else as it starts.
  #
  # @param page [Symbol] The page.
  # @param key [Object] The group's key.
  # @param open [Boolean] Whether it starts open.
  # @return [Boolean] Whether it is open.
  def self.fold_open?(page, key, open)
    @folds ||= {}
    chosen = (@folds[page] ||= {})[key]
    chosen.nil? ? open : chosen
  end

  # Lists what can be picked of a list's rows: its groups and their entries.
  #
  # @param list [Array<Array>] The rows.
  # @return [Array] The groups and the entries, in their order.
  def self.picks_of(list)
    list.select { |kind, _| kind == :entry || kind == :fold }.map { |_, entry| entry }
  end

  # Tells a formation member's catch-up experience for the Unlocks page's head.
  #
  # @param actor [Game_Actor] The member.
  # @param target [Integer] The level characters catch up to.
  # @return [Array<String>] Their name, level and factor.
  def self.exp_cells(actor, target)
    factor = MGQ_MpWorldCatchupExp.factor_for(actor.base_level, target)
    [actor.name.to_s, LEVEL_SHORT % actor.base_level, MGQ_MpWorldCatchupExp.factor_text(factor)]
  end

  # Tells what a list row shows of an entry.
  #
  # @param entry [Object] A Quest, Note, BossEntry, Level or Fold.
  # @return [RowView] The row.
  def self.row_view(entry)
    case entry
    when Quest then RowView.new(entry.kind == :side ? "#{entry.number}." : entry.speaker.to_s, entry.first, nil, false, nil)
    when Note then RowView.new(entry.title, first_sentence(entry.texts.first), nil, false, nil)
    when BossEntry
      boss = entry.boss
      RowView.new(nil, boss.name, boss.defeated ? DEFEATED : share_text(boss.left), boss.defeated, boss.defeated ? nil : boss.left)
    when Level
      RowView.new(LEVEL_HEADING % entry.level, entry.unlocks.map { |unlock| unlock.name }.join(", "), entry.due ? DUE : nil, entry.got, nil)
    when Fold then RowView.new(nil, (entry.open ? UNFOLDED : FOLDED) + entry.title, nil, false, nil)
    end
  end

  # Tells what the reading pane shows of an entry.
  #
  # @param entry [Object, nil] A Quest, Note, BossEntry, Level or Fold.
  # @return [Pane, nil] The pane; nil for nothing picked.
  def self.pane_of(entry)
    case entry
    when Quest then Pane.new(entry.title, entry.looks, paragraphs(entry.texts))
    when Note then Pane.new(entry.title, nil, paragraphs(entry.texts))
    when BossEntry then boss_pane(entry)
    when Level then level_pane(entry)
    when Fold then Pane.new(entry.title, nil, [[:text, FOLD_HINT[entry.open]]])
    end
  end

  # Lays texts out as paragraphs with a gap between two.
  #
  # @param texts [Array<String>] The texts.
  # @return [Array<Array>] The pane's lines.
  def self.paragraphs(texts)
    texts.each_with_index.inject([]) { |lines, (text, index)| lines + (index > 0 ? [[:gap]] : []) + [[:text, text]] }
  end

  # Lays a raid boss out for the pane: its section, its tier and what it changes, how much of its
  # HP the world left it, and who last hurt it.
  #
  # @param entry [BossEntry] The boss.
  # @return [Pane] The pane.
  def self.boss_pane(entry)
    boss = entry.boss
    lines = [[:text, entry.section]]
    stats = boss.tier ? MGQ_MpRaidBosses::TIERS.fetch(boss.tier, {}) : {}
    unless stats.empty?
      text = stats.map { |stat, factor| TIER_STAT % [TIER_STATS.fetch(stat, stat.to_s.upcase), factor == factor.round ? factor.round : factor] }.join(", ")
      lines << [:text, TIER_LINE % [boss.tier, text]]
    end
    lines << [:gauge, boss.defeated ? 0.0 : boss.left, boss.defeated ? DEFEATED : share_text(boss.left)]
    lines << [:text, LAST_HURT % boss.by] if boss.by
    Pane.new(boss.name, nil, lines)
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

  # The view of a page laid out with a head, a list and a pane.
  #
  # @param page [Symbol] One of SPLIT_PAGES.
  # @param calls [Boolean] Whether a player's invite, challenge or offer reaches the player.
  # @return [Hash] The view, see view, with :model, :pick, :list_scroll and :pane_scroll.
  def self.split_view(page, calls)
    data = model(page)
    state = split_state(page)
    state[:pick] = MGQ_MpUi.within(state[:pick], 0, [data.picks.size - 1, 0].max)
    # The box may have changed its height since the last look.
    state[:list] = MGQ_MpUi.within(state[:list], 0, [data.rows.size - Sprite_MpWorldOverview.list_rows_shown, 0].max)
    pane = pane_of(data.picks[state[:pick]])
    state[:pane] = pane ? MGQ_MpUi.within(state[:pane], 0, Sprite_MpWorldOverview.most_pane_scroll(pane)) : 0
    { :page => page, :lines => [], :selected => nil, :scroll => 0, :menu => nil, :menu_index => nil, :calls => calls,
      :model => data, :pick => state[:pick], :list_scroll => state[:list], :pane_scroll => state[:pane] }
  end

  # The pick and the scrolls of a page, kept while the overview is open.
  #
  # @param page [Symbol] One of SPLIT_PAGES.
  # @return [Hash] :pick, :list and :pane.
  def self.split_state(page)
    @split ||= {}
    @split[page] ||= { :pick => 0, :list => 0, :pane => 0 }
  end

  # Picks an entry with Up and Down, opens or folds a group with confirm, scrolls the pane with
  # Page Up and Page Down, scrolls with the mouse wheel, turns the page, follows clicks, or closes
  # the overview.
  #
  # @param page [Symbol] One of SPLIT_PAGES.
  def self.update_split(page)
    view = split_view(page, false)
    mouse_split(page, view)
    return unless @open && @page == page
    return if closed_by_cancel? || turn_by_keys

    picks = view[:model].picks
    picked = picks[view[:pick]]
    return toggle(page, picked) if picked.is_a?(Fold) && MGQ_Multiplayer::Capture.trigger?(:C)

    step = axis_step(:UP, :DOWN)
    return pick_entry(page, (view[:pick] + step) % picks.size) if step != 0 && picks.size > 1

    turn = axis_step(:L, :R)
    scroll_pane(page, turn * [Sprite_MpWorldOverview.pane_rows - 1, 1].max) if turn != 0
  end

  # Opens or folds a group of the list.
  #
  # @param page [Symbol] The page.
  # @param fold [Fold] The group.
  def self.toggle(page, fold)
    @folds ||= {}
    (@folds[page] ||= {})[fold.key] = !fold.open
    forget_model(page)
    Sound.play_ok
    log("#{fold.open ? 'folded' : 'opened'} #{fold.title} on the #{page} page")
  end

  # Picks an entry, showing its pane from the top and keeping its row in sight.
  #
  # @param page [Symbol] The page.
  # @param index [Integer] Its place among what can be picked.
  def self.pick_entry(page, index)
    state = split_state(page)
    return if index == state[:pick]

    state[:pick] = index
    state[:pane] = 0
    data = model(page)
    row = Sprite_MpWorldOverview.entry_row(data, index)
    rows = Sprite_MpWorldOverview.list_rows_shown
    if row
      # The group above its first entry shows with it.
      top = row > 0 && data.rows[row - 1][0] == :fold && data.rows[row][0] == :entry ? row - 1 : row
      state[:list] = top if top < state[:list]
      state[:list] = row - rows + 1 if row >= state[:list] + rows
    else
      state[:list] = 0
    end
    Sound.play_cursor
  end

  # Scrolls the list by rows, never past its end.
  #
  # @param page [Symbol] The page.
  # @param step [Integer] Rows down, negative up.
  def self.scroll_list(page, step)
    state = split_state(page)
    most = [model(page).rows.size - Sprite_MpWorldOverview.list_rows_shown, 0].max
    state[:list] = MGQ_MpUi.within(state[:list] + step, 0, most)
  end

  # Scrolls the pane by lines, never past its last line.
  #
  # @param page [Symbol] The page.
  # @param step [Integer] Lines down, negative up.
  def self.scroll_pane(page, step)
    state = split_state(page)
    data = model(page)
    pane = pane_of(data.picks[state[:pick]])
    return unless pane

    scroll = MGQ_MpUi.within(state[:pane] + step, 0, Sprite_MpWorldOverview.most_pane_scroll(pane))
    return if scroll == state[:pane]

    state[:pane] = scroll
    Sound.play_cursor
  end

  # Follows the mouse on a page laid out with a head, a list and a pane: the wheel scrolls the list
  # or the pane it points at, a click picks an entry or opens a group, a click on a tab turns the
  # page, a click outside the box closes the overview.
  #
  # @param page [Symbol] The page.
  # @param view [Hash] The page's view, see split_view.
  def self.mouse_split(page, view)
    position = MGQ_Multiplayer::Mouse.position
    clicked = MGQ_Multiplayer::Mouse.clicked?
    turned = wheel
    @mouse = position
    return unless position

    x, y = position
    if turned != 0
      area = Sprite_MpWorldOverview.area_at(x, y)
      scroll_list(page, -turned) if area == :list
      scroll_pane(page, -turned * WHEEL_LINES) if area == :pane
    end
    return unless clicked

    tab = Sprite_MpWorldOverview.tab_at(x, y)
    return turn_to(tab, "a click on its tab") if tab

    pick = Sprite_MpWorldOverview.entry_at(x, y, view)
    if pick
      entry = view[:model].picks[pick]
      pick_entry(page, pick)
      toggle(page, entry) if entry.is_a?(Fold)
      return
    end
    return if Sprite_MpWorldOverview.inside?(x, y)

    Sound.play_cancel
    close("a click outside the box")
  end

  # Lines the pane scrolls for a notch of the mouse wheel.
  WHEEL_LINES = 3

  # Reads the mouse wheel's notches since the last frame.
  #
  # @return [Integer] Up positive, down negative; 0 without a wheel.
  def self.wheel
    mouse = MGQ_Multiplayer::Mouse
    mouse.respond_to?(:wheel) ? mouse.wheel.to_i : 0
  rescue
    0
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

  # Finds a text's first sentence: up to the first end of a sentence followed by a space or the
  # text's end, or a Japanese one.
  #
  # Abbreviations such as "Mt." end no sentence, so "Mt. Saint Amos" stays whole.
  #
  # @param text [String] The text.
  # @return [String] The sentence; the whole text without an end.
  def self.first_sentence(text)
    text = text.to_s.strip
    offset = 0
    while (match = SENTENCE_END.match(text, offset))
      word = text[0, match.begin(0)][/\S+\z/].to_s
      return text[0, match.end(0)].strip unless ABBREVIATIONS.include?(word)

      offset = match.end(0)
    end
    text
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
    id = SIDE_EVENTS[$game_variables[CHAOS_ROUTE].to_i >= CHAOS_SIDE_STEP ? 1 : 0]
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
  def self.add_options
    added = MGQ_MpUi.add_option(PORTRAIT_OPTION, PORTRAIT_OPTION_NAME, PORTRAIT_OPTION_HELP, lambda { PORTRAITS }, lambda { portraits },
                                lambda { |choice| choose_portraits(choice) })
    log(added ? "added the Quest Portraits to the Mod Config" : "no Quest Portraits in the Mod Config: it needs a Mod Config Remake that knows rows the mod keeps")
  end

  # Finds the picture that shows faintly behind the Quests page: Amira's in the Library.
  #
  # @return [Bitmap, nil] The picture; nil when the game has none.
  def self.backdrop
    return @backdrop if @backdrop && !@backdrop.disposed?
    return nil if @backdrop_missing

    image = defined?(NWConst::Library::ACTOR_IMAGE) ? NWConst::Library::ACTOR_IMAGE[AMIRA] : nil
    @backdrop_missing = !image.is_a?(Array)
    @backdrop = @backdrop_missing ? nil : Cache.load_bitmap(image[0].to_s, image[1].to_s)
  rescue => e
    log_once(:backdrop, "loading Amira's picture failed: #{e.class}: #{e.message}")
    @backdrop_missing = true
    @backdrop = nil
  end

  # Lists the raid bosses for the World page by the story's sections in story order: each section
  # the world's story reached (see reached?) or holding a boss the relay told a pool of, its bosses
  # in the order the story meets them, then the pools of its fights that take their own name, such
  # as Sisel's; last, under OTHER_SECTION, the pools whose bosses the tables lack, by name.
  #
  # @return [Array<Array(String, Array<Boss>)>] Each section's name with its bosses.
  def self.boss_sections
    pools = MGQ_MpRaidPool.pools.group_by { |key, _| MGQ_MpRaidPool.boss_key(key) }
    counters = MGQ_MpWorldStory.world
    listed = MGQ_MpRaidBosses.sections.map do |section, keys|
      names = keys + pools.keys.select { |name| !keys.include?(name) && section_of(name) == section }.sort
      next unless reached?(section, counters) || names.any? { |name| pools.key?(name) }

      [section, names.map { |name| boss_of(name, tier_of(name), pools.delete(name)) }]
    end
    others = pools.keys.sort.map { |name| boss_of(name, nil, pools[name]) }
    listed.compact + (others.empty? ? [] : [[OTHER_SECTION, others]])
  end

  # Reports whether the world's story reached a section of raid bosses, see SECTION_REACH.
  #
  # @param section [String] The section's name.
  # @param counters [Hash, nil] The world's story, see MGQ_MpWorldStory.world; nil before the relay
  #   told it, which reaches no section.
  # @return [Boolean] Whether it did.
  def self.reached?(section, counters)
    return false unless counters

    reach = SECTION_REACH[section]
    reach.nil? || !(reach & ([MGQ_MpWorldStory.part_of(counters).to_s] + Array(counters["done"]))).empty?
  rescue => e
    log_once(:boss_sections, "reading the world's story for the raid bosses failed: #{e.class}: #{e.message}")
    false
  end

  # Finds the section of a pool's boss: its milestone's or OPTIONAL's, else that of the troop a
  # fight with its own name belongs to.
  #
  # @param name [String] The pool's boss, see MGQ_MpRaidPool.boss_key.
  # @return [String, nil] The section, nil for a boss the tables lack.
  def self.section_of(name)
    MGQ_MpRaidBosses.section(name) || MGQ_MpRaidBosses.section(MGQ_MpRaidPool.troop_of_key(name))
  end

  # Finds the tier of a raid boss by its name, as section_of finds its section.
  #
  # @param name [String] The boss's name.
  # @return [Integer, nil] Its tier, nil for a name the tables lack.
  def self.tier_of(name)
    MGQ_MpRaidBosses.key_tier(name) || MGQ_MpRaidBosses.tier(MGQ_MpRaidPool.troop_of_key(name))
  end

  # Sums a raid boss up from its pools: the share left over them, whether every one is empty for
  # good, and who hurt the one last told of.
  #
  # @param name [String] The boss's name, see Boss.
  # @param tier [Integer, nil] Its tier.
  # @param entries [Array<Array>, nil] Its pools, each with its key; nil while the relay told none.
  # @return [Boss] The boss.
  def self.boss_of(name, tier, entries)
    pools = (entries || []).map { |_, pool| pool }
    return Boss.new(name, tier, UNTOUCHED, false, nil) if pools.empty?

    now = Time.now
    left = pools.inject(0.0) { |sum, pool| sum + MGQ_MpRaidPool.left_now(pool, now) } / pools.size
    hurt = pools.select { |pool| !pool.by.to_s.empty? }.max_by { |pool| pool.at.to_f }
    Boss.new(name, tier, left, pools.all? { |pool| pool.defeated }, hurt && hurt.by.to_s)
  end

  # Writes the share of a raid boss's HP left, never 0% while any is.
  #
  # @param left [Float] The share, 0 to 1.
  # @return [String] Such as "68%".
  def self.share_text(left)
    SHARE_LEFT % [(left * PERCENT).round, left > 0 ? 1 : 0].max
  end
end

# The drawing of the pages with a head, a list and a pane.
class Sprite_MpWorldOverview < Sprite
  # The most columns the pane sets the things it names in.
  PANE_COLUMNS = 4

  # The room between two of those columns.
  COLUMN_GAP = 16

  # Draws a page laid out with a head, a list and a pane.
  #
  # @param view [Hash] The page's view, see MGQ_MpWorldOverview.split_view.
  def draw_split(view)
    data = view[:model]
    layout = self.class.split_layout(bitmap.width, bitmap.height)
    picked = data.picks[view[:pick]]
    draw_split_head(data.head, picked, layout) if data.head
    draw_split_list(data, view[:list_scroll], picked, layout)
    bitmap.fill_rect(layout[:pane_x] - SPLIT_DIVIDE / 2, layout[:body_y], 1, layout[:body_h], MGQ_MpUi::Style::EDGE)
    draw_split_pane(MGQ_MpWorldOverview.pane_of(picked), view[:pane_scroll], layout)
  end

  # Draws a page's head: its box with a portrait or an icon, its title with its note at the right,
  # and its lines or its grid; on the picked color while its entry is picked.
  #
  # @param head [MGQ_MpWorldOverview::Head] The head.
  # @param picked [Object, nil] The entry picked.
  # @param layout [Hash] See split_layout.
  def draw_split_head(head, picked, layout)
    style = MGQ_MpUi::Style
    top = layout[:head_y]
    if head.looks
      draw_portrait(head.looks, MARGIN, top, PORTRAIT)
    elsif head.icon
      bitmap.fill_rect(MARGIN, top, PORTRAIT, PORTRAIT, style::BACK)
      MGQ_MpUi.draw_icon(bitmap, head.icon, MARGIN + (PORTRAIT - HEAD_ICON) / 2, top + (PORTRAIT - HEAD_ICON) / 2, HEAD_ICON)
      style.draw_line_box(bitmap, MARGIN, top, PORTRAIT, PORTRAIT, style::EDGE)
    end
    x = layout[:text_x]
    width = bitmap.width - MARGIN - x
    bitmap.fill_rect(x - style::GAP, top, width + style::GAP, PORTRAIT, style::PICKED) if head.entry && picked.equal?(head.entry)
    note_width = 0
    if head.note
      style.use_font(bitmap, style::SMALL_SIZE, style::DIM)
      note_width = bitmap.text_size(head.note).width
      bitmap.draw_text(x, top, width, PANE_LINE, head.note, 2)
    end
    style.use_font(bitmap, style::SMALL_SIZE, style::HEADING)
    title_width = width - note_width - style::GAP
    bitmap.draw_text(x, top, title_width, PANE_LINE, self.class.fitted([:title, head.title, title_width]) { MGQ_MpUi.cut(bitmap, head.title, title_width) })
    return draw_grid(head.grid, x, top + PANE_LINE, width) if head.grid

    style.use_font(bitmap, style::TEXT_SIZE, head.entry || !head.lines.empty? ? style::TEXT : style::DIM)
    head_lines(head.lines, width).each_with_index { |line, index| bitmap.draw_text(x, top + PANE_LINE + index * PANE_LINE, width, PANE_LINE, line) }
  end

  # Fits a head's lines into MAIN_LINES: one line wrapped over them, several each cut to one.
  #
  # @param lines [Array<String>] The lines.
  # @param width [Integer] Their width.
  # @return [Array<String>] What shows.
  def head_lines(lines, width)
    self.class.fitted([:head, lines, width]) do
      if lines.size == 1
        wrapped = MGQ_MpUi.wrap(bitmap, lines.first.to_s, width)
        shown = wrapped.first(MAIN_LINES)
        shown[-1] = MGQ_MpUi.cut(bitmap, "#{shown[-1]} #{wrapped[MAIN_LINES]}", width) if wrapped.size > MAIN_LINES
        shown
      else
        lines.first(MAIN_LINES).map { |line| MGQ_MpUi.cut(bitmap, line.to_s, width) }
      end
    end
  end

  # Draws the Unlocks page's grid of the formation's catch-up experience: two members a line, each
  # with their name, their level and their factor in columns.
  #
  # @param grid [Array<Array<String>>] Each member's name, level and factor.
  # @param x [Integer] The grid's left.
  # @param y [Integer] The grid's top.
  # @param width [Integer] The grid's width.
  def draw_grid(grid, x, y, width)
    style = MGQ_MpUi::Style
    column = width / 2
    grid.first(MAIN_LINES * 2).each_with_index do |(name, level, factor), index|
      left = x + index % 2 * column
      top = y + index / 2 * PANE_LINE
      style.use_font(bitmap, style::SMALL_SIZE, style::TITLE)
      factor_width = bitmap.text_size(factor).width
      bitmap.draw_text(left, top, column - style::GAP * 2, PANE_LINE, factor, 2)
      style.use_font(bitmap, style::SMALL_SIZE, style::DIM)
      level_width = bitmap.text_size(level).width
      level_right = column - style::GAP * 4 - factor_width
      bitmap.draw_text(left, top, level_right, PANE_LINE, level, 2)
      style.use_font(bitmap, style::TEXT_SIZE, style::TEXT)
      name_width = level_right - level_width - style::GAP * 2
      bitmap.draw_text(left, top, name_width, PANE_LINE, self.class.fitted([:grid, name, name_width]) { MGQ_MpUi.cut(bitmap, name, name_width) })
    end
  end

  # Draws the list from its scroll: the groups and entries on the picked color while picked, and its
  # scrollbar.
  #
  # @param data [MGQ_MpWorldOverview::Model] The page's model.
  # @param scroll [Integer] The first row in sight.
  # @param picked [Object, nil] The entry picked.
  # @param layout [Hash] See split_layout.
  def draw_split_list(data, scroll, picked, layout)
    style = MGQ_MpUi::Style
    count = self.class.list_rows_shown(bitmap.height)
    width = layout[:list_w] - BAR_ROOM
    data.rows[scroll, count].to_a.each_with_index do |(kind, value), index|
      y = layout[:body_y] + index * ROW
      case kind
      when :none
        style.use_font(bitmap, style::SMALL_SIZE, style::DIM)
        bitmap.draw_text(MARGIN + ROW_INDENT, y, width - ROW_INDENT, ROW, value)
      else
        bitmap.fill_rect(MARGIN, y, width, ROW, style::PICKED) if value.equal?(picked)
        draw_entry_row(MGQ_MpWorldOverview.row_view(value), kind == :fold ? MARGIN : MARGIN + ROW_INDENT, y, width - ROW_INDENT - style::GAP, kind == :fold)
      end
    end
    style.draw_scrollbar(bitmap, MARGIN + layout[:list_w] - style::SCROLLBAR_WIDTH, layout[:body_y], count * ROW, scroll, count, data.rows.size)
  end

  # Draws one entry of the list: its label, its text cut to the room left, and at the right a
  # gauge and its note.
  #
  # @param row [MGQ_MpWorldOverview::RowView] What the row shows.
  # @param x [Integer] The row's left.
  # @param y [Integer] The row's top.
  # @param width [Integer] The row's width.
  # @param fold [Boolean] Whether it is a group's row, drawn as a heading.
  def draw_entry_row(row, x, y, width, fold)
    style = MGQ_MpUi::Style
    used = 0
    if row.label
      style.use_font(bitmap, style::SMALL_SIZE, row.dim ? style::DIM : style::HEADING)
      label, used = self.class.fitted([:label, row.label, width]) do
        cut = MGQ_MpUi.cut(bitmap, row.label, width / 3)
        [cut, bitmap.text_size(cut).width + style::GAP * 2]
      end
      bitmap.draw_text(x, y, used, ROW, label)
    end
    right = width
    if row.note
      style.use_font(bitmap, style::SMALL_SIZE, style::DIM)
      right -= bitmap.text_size(row.note).width
      bitmap.draw_text(x, y, width, ROW, row.note, 2)
      right -= style::GAP * 2
    end
    if row.gauge
      right -= ROW_GAUGE
      draw_bar(x + right, y + (ROW - GAUGE_HEIGHT) / 2, ROW_GAUGE, row.gauge)
      right -= style::GAP * 2
    end
    style.use_font(bitmap, style::SMALL_SIZE, fold ? style::HEADING : (row.dim ? style::DIM : style::TEXT))
    room = right - used
    bitmap.draw_text(x + used, y, room, ROW, self.class.fitted([:row, row.text, room]) { MGQ_MpUi.cut(bitmap, row.text.to_s, room) }) if room > 0
  end

  # Draws the pane: its title, beside the portrait of whom it is about, and its lines from its
  # scroll, with its scrollbar.
  #
  # @param pane [MGQ_MpWorldOverview::Pane, nil] The pane.
  # @param scroll [Integer] The first line in sight.
  # @param layout [Hash] See split_layout.
  def draw_split_pane(pane, scroll, layout)
    return unless pane

    style = MGQ_MpUi::Style
    x = layout[:pane_x]
    width = layout[:pane_w] - BAR_ROOM
    top = layout[:body_y]
    head = self.class.pane_head(pane)
    title_x = x
    if pane.looks
      draw_portrait(pane.looks, x, top, PANE_PORTRAIT)
      title_x += PANE_PORTRAIT + SPLIT_GAP
    end
    title_width = x + width - title_x
    style.use_font(bitmap, style::SMALL_SIZE, style::HEADING)
    bitmap.draw_text(title_x, top + (head - ROW) / 2, title_width, ROW, self.class.fitted([:title, pane.title, title_width]) { MGQ_MpUi.cut(bitmap, pane.title.to_s, title_width) })
    rows = self.class.pane_layout(pane)
    y = top + head
    bottom = top + layout[:body_h]
    shown = 0
    rows[scroll..-1].to_a.each do |kind, value, height|
      break if y + height > bottom

      draw_pane_row(kind, value, x, y, width)
      y += height
      shown += 1
    end
    style.draw_scrollbar(bitmap, x + layout[:pane_w] - style::SCROLLBAR_WIDTH, top + head, layout[:body_h] - head, scroll, shown, rows.size)
  end

  # Draws one line of the pane: a line of text, a row of things named, or a gauge with its text.
  #
  # @param kind [Symbol] :line, :gap, :items or :gauge.
  # @param value [Object] The line's text, the row's MGQ_MpWorldOverview::PaneItem list with the
  #   columns it is set in, or the gauge's share and text.
  # @param x [Integer] The line's left.
  # @param y [Integer] The line's top.
  # @param width [Integer] The line's width.
  def draw_pane_row(kind, value, x, y, width)
    style = MGQ_MpUi::Style
    case kind
    when :line
      style.use_font(bitmap, style::TEXT_SIZE, style::TEXT)
      bitmap.draw_text(x, y, width, PANE_LINE, value)
    when :items
      items, columns = value
      column = (width - COLUMN_GAP * (columns - 1)) / columns
      items.each_with_index { |item, index| draw_pane_item(item, x + index * (column + COLUMN_GAP), y, column) }
    when :gauge
      share, text = value
      draw_bar(x, y + (ROW - GAUGE_HEIGHT * 2) / 2, PANE_GAUGE, share, GAUGE_HEIGHT * 2)
      style.use_font(bitmap, style::SMALL_SIZE, style::TEXT)
      bitmap.draw_text(x + PANE_GAUGE + style::GAP * 2, y, width - PANE_GAUGE - style::GAP * 2, ROW, text)
    end
  end

  # Draws a gauge of a share: framed in the edge color, its well, and the share filled.
  #
  # @param x [Integer] Its left.
  # @param y [Integer] Its top.
  # @param width [Integer] Its width.
  # @param share [Float] The share filled, 0 to 1.
  # @param height [Integer] Its height.
  def draw_bar(x, y, width, share, height = GAUGE_HEIGHT)
    style = MGQ_MpUi::Style
    bitmap.fill_rect(x, y, width, height, style::EDGE)
    bitmap.fill_rect(x + GAUGE_FRAME, y + GAUGE_FRAME, width - 2 * GAUGE_FRAME, height - 2 * GAUGE_FRAME, style::WELL)
    filled = ((width - 2 * GAUGE_FRAME) * MGQ_MpUi.within(share.to_f, 0.0, 1.0)).round
    bitmap.fill_rect(x + GAUGE_FRAME, y + GAUGE_FRAME, filled, height - 2 * GAUGE_FRAME, style::BAD) if filled > 0
  end

  # Lays the pages with a head, a list and a pane out in a box of a size.
  #
  # @param width [Integer] The box's width.
  # @param height [Integer] The box's height.
  # @return [Hash] :head_y (the head's top), :text_x (the head's text's left), :body_y and :body_h
  #   (the list's and the pane's top and height), :list_w, :pane_x and :pane_w.
  def self.split_layout(width = box.width, height = box.height)
    head_y = LIST_TOP + MGQ_MpUi::Style::GAP
    body_y = head_y + PORTRAIT + SPLIT_GAP
    list_w = ((width - 2 * MARGIN - SPLIT_DIVIDE) * LIST_SHARE).to_i
    pane_x = MARGIN + list_w + SPLIT_DIVIDE
    { :head_y => head_y, :text_x => MARGIN + PORTRAIT + SPLIT_GAP, :body_y => body_y, :body_h => [height - HINT_HEIGHT - MARGIN - body_y, ROW].max,
      :list_w => list_w, :pane_x => pane_x, :pane_w => width - MARGIN - pane_x }
  end

  # Tells how many rows of the list show at once.
  #
  # @param height [Integer] The box's height.
  # @return [Integer] The rows, at least one.
  def self.list_rows_shown(height = box.height)
    [split_layout(box.width, height)[:body_h] / ROW, 1].max
  end

  # Draws a thing the pane names: its icon or how it looks, its name and its note at the right.
  #
  # @param item [MGQ_MpWorldOverview::PaneItem] The thing.
  # @param x [Integer] Its left.
  # @param y [Integer] Its top.
  # @param width [Integer] Its column's width.
  def draw_pane_item(item, x, y, width)
    style = MGQ_MpUi::Style
    if item.looks
      draw_portrait(item.looks, x, y, ROW)
    elsif item.icon
      MGQ_MpUi.draw_icon(bitmap, item.icon, x, y, MGQ_MpUi::ICON_SIZE, item.dim ? style::DIM_OPACITY : MGQ_MpUi::Motion::OPAQUE)
    end
    right = width
    if item.note
      style.use_font(bitmap, style::SMALL_SIZE, style::DIM)
      right -= bitmap.text_size(item.note).width + style::GAP * 2
      bitmap.draw_text(x, y, width, ROW, item.note, 2)
    end
    left = ROW + style::GAP * 2
    style.use_font(bitmap, style::TEXT_SIZE, item.dim ? style::DIM : style::TEXT)
    bitmap.draw_text(x + left, y, right - left, ROW, self.class.fitted([:item, item.name, right - left]) { MGQ_MpUi.cut(bitmap, item.name.to_s, right - left) })
  end

  # Tells about how many lines of text the pane shows at once, for a page's step of Page Up and Page
  # Down.
  #
  # @param height [Integer] The box's height.
  # @return [Integer] The lines, at least one.
  def self.pane_rows(height = box.height)
    [(split_layout(box.width, height)[:body_h] - ROW) / PANE_LINE, 1].max
  end

  # Tells how tall the pane's head is: its title, beside a portrait if any.
  #
  # @param pane [MGQ_MpWorldOverview::Pane] The pane.
  # @return [Integer] The height.
  def self.pane_head(pane)
    pane.looks ? PANE_PORTRAIT + MGQ_MpUi::Style::GAP : ROW
  end

  # Lays the pane's lines out at its width: each paragraph wrapped to lines of text, half a line
  # between paragraphs, the things named after each other in rows of columns, a row for each gauge.
  #
  # @param pane [MGQ_MpWorldOverview::Pane] The pane.
  # @return [Array<Array>] Each line's kind (:line, :gap, :items or :gauge), value and height.
  def self.pane_layout(pane)
    width = split_layout[:pane_w] - BAR_ROOM
    fitted([:pane, pane.lines, width]) do
      @measure = Bitmap.new(1, 1) if @measure.nil? || @measure.disposed?
      rows = []
      items = []
      pane.lines.each do |kind, value, extra|
        if kind == :item
          items << value
          next
        end
        rows.concat(item_rows(items, width))
        items = []
        case kind
        when :text
          MGQ_MpUi::Style.use_font(@measure, MGQ_MpUi::Style::TEXT_SIZE, MGQ_MpUi::Style::TEXT)
          rows.concat(MGQ_MpUi.wrap(@measure, value.to_s, width).map { |line| [:line, line, PANE_LINE] })
        when :gap then rows << [:gap, nil, PANE_LINE / 2]
        else rows << [:gauge, [value, extra], ROW]
        end
      end
      rows.concat(item_rows(items, width))
    end
  end

  # Sets things named after each other in rows of as many columns as the widest of them fits without
  # being cut.
  #
  # @param items [Array<MGQ_MpWorldOverview::PaneItem>] The things.
  # @param width [Integer] The pane's width.
  # @return [Array<Array>] A row of :items for each, with its things and the columns.
  def self.item_rows(items, width)
    return [] if items.empty?

    widest = items.map { |item| item_width(item) }.max
    columns = [[(width + COLUMN_GAP) / (widest + COLUMN_GAP), 1].max, PANE_COLUMNS].min
    items.each_slice(columns).map { |row| [:items, [row, columns], ROW] }
  end

  # Measures the room a thing named takes: its icon, its name and its note.
  #
  # @param item [MGQ_MpWorldOverview::PaneItem] The thing.
  # @return [Integer] The width.
  def self.item_width(item)
    style = MGQ_MpUi::Style
    style.use_font(@measure, style::TEXT_SIZE, style::TEXT)
    width = ROW + style::GAP * 2 + @measure.text_size(item.name.to_s).width
    return width unless item.note

    style.use_font(@measure, style::SMALL_SIZE, style::DIM)
    width + style::GAP * 2 + @measure.text_size(item.note).width
  end

  # Tells the furthest the pane scrolls: until its last line shows at its bottom.
  #
  # @param pane [MGQ_MpWorldOverview::Pane] The pane.
  # @return [Integer] The first line in sight then.
  def self.most_pane_scroll(pane)
    rows = pane_layout(pane)
    room = split_layout[:body_h] - pane_head(pane)
    first = rows.size
    while first > 0 && room >= rows[first - 1][2]
      room -= rows[first - 1][2]
      first -= 1
    end
    first
  end

  # Finds the list's row of what can be picked.
  #
  # @param data [MGQ_MpWorldOverview::Model] The page's model.
  # @param pick [Integer] Its place among what can be picked.
  # @return [Integer, nil] Its row; nil for the head's entry, which the list leaves out.
  def self.entry_row(data, pick)
    first = data.head && data.head.entry ? 1 : 0
    return nil if pick < first

    (0...data.rows.size).select { |row| [:entry, :fold].include?(data.rows[row][0]) }[pick - first]
  end

  # Tells which part of a page laid out with a head, a list and a pane a point of the screen lies in.
  #
  # @param x [Integer] The point's x.
  # @param y [Integer] The point's y.
  # @return [Symbol, nil] :list or :pane; nil elsewhere.
  def self.area_at(x, y)
    return nil unless inside?(x, y)

    box = self.box
    layout = split_layout(box.width, box.height)
    left = x - box.x
    top = y - box.y
    return nil if top < layout[:body_y] || top >= layout[:body_y] + layout[:body_h]
    return :list if left >= MARGIN && left < MARGIN + layout[:list_w]

    left >= layout[:pane_x] ? :pane : nil
  end

  # Finds what can be picked under a point of the screen: the head's entry, or an entry or group
  # of the list.
  #
  # @param x [Integer] The point's x.
  # @param y [Integer] The point's y.
  # @param view [Hash] The page's view.
  # @return [Integer, nil] Its place among what can be picked; nil for nothing.
  def self.entry_at(x, y, view)
    return nil unless inside?(x, y)

    box = self.box
    layout = split_layout(box.width, box.height)
    data = view[:model]
    first = data.head && data.head.entry ? 1 : 0
    top = y - box.y
    return (first == 1 ? 0 : nil) if top >= layout[:head_y] && top < layout[:head_y] + PORTRAIT
    return nil unless area_at(x, y) == :list

    row = view[:list_scroll] + (top - layout[:body_y]) / ROW
    return nil unless row < view[:list_scroll] + list_rows_shown(box.height) && data.rows[row] && [:entry, :fold].include?(data.rows[row][0])

    first + data.rows[0...row].count { |kind, _| kind == :entry || kind == :fold }
  end

  # Draws how a character looks in a framed square on the box's background, by the player's choice
  # of portraits: their map sprite or their face.
  #
  # @param looks [MGQ_MpWorldOverview::Looks] How they look.
  # @param x [Integer] The square's left.
  # @param y [Integer] The square's top.
  # @param side [Integer] The square's side.
  def draw_portrait(looks, x, y, side)
    return unless defined?(Sprite_MpLeaderHud)

    if MGQ_MpWorldOverview.portraits == MGQ_MpWorldOverview::FACES
      Sprite_MpLeaderHud.draw_face(bitmap, looks.face_name, looks.face_index, x, y, side, MGQ_MpUi::Style::BACK)
    else
      Sprite_MpLeaderHud.draw_figure(bitmap, looks.character_name, looks.character_index, x, y, side, MGQ_MpUi::Style::BACK)
    end
  end

  # Draws Amira's picture faintly at the right behind the Quests page's lines.
  def draw_backdrop
    picture = MGQ_MpWorldOverview.backdrop
    return unless picture

    room = bitmap.height - LIST_TOP - HINT_HEIGHT - MARGIN
    scale = [room.to_f / picture.height, 1.0].min
    width = (picture.width * scale).to_i
    height = (picture.height * scale).to_i
    return if width <= 0 || height <= 0

    target = Rect.new(bitmap.width - MARGIN - width, LIST_TOP + room - height, width, height)
    bitmap.stretch_blt(target, picture, picture.rect, MGQ_MpWorldOverview::BACKDROP_OPACITY)
  end

  # Keeps what fitting a text to a width gave, since measuring texts is slow in the game.
  #
  # @param key [Array] What the result goes by: its use, the text and the width.
  # @yieldreturn [Object] The result, worked out once.
  # @return [Object] The result.
  def self.fitted(key)
    @fitted ||= {}
    @fitted.clear if @fitted.size > FITTED_MOST
    @fitted.key?(key) ? @fitted[key] : @fitted[key] = yield
  end
end

# The Quest Portraits row of the Mod Config.

begin
  MGQ_MpWorldOverview.add_options
rescue => e
  MGQ_MpWorldOverview.log("options FAILED: #{e.class}: #{e.message}")
end
