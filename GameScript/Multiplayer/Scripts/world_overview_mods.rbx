#----------------------------------------------------------------
#  world_overview_mods.rbx
#
#  Changelog:
#      Paulinchen  2026-10-24: Created
#
#----------------------------------------------------------------

# Pages other mods offer the World overview, each shown as a tab of its own with a head, a list and
# a pane like the World page. Confirm on an entry moves the cursor into its pane, onto its controls
# and the buttons beside its title. The mods add their pages to ModPages, which neither side owns:
# whichever loads first defines it, so no mod names another. A page answers:
#
# - title: its tab's title.
# - shown?: whether it has anything to show now.
# - head: [title, note, lines, looks], the head's title, its note at the right (or nil), its lines
#   and how the portrait beside it looks ([character_name, character_index, face_name, face_index]
#   or nil).
# - groups: [[title, keys], ...], the list's groups with the keys of their entries.
# - row(key): [label, text, note, dim], what an entry's row shows.
# - pane(key): [title, looks, lines, subtitle], the pane's title, how the one it is about looks
#   (as in head), its line under the title (or nil) and its lines, each
#   [:text, text], [:item, name, note, dim], [:control, id, name, note, tone, less, more] or [:gap].
#   A control is a line Left and Right change: tone is :good, :warn, :bad, :dim or nil, less and more
#   whether Left and Right may change it.
# - adjust(key, id, step): changes a control by a step, -1 for Left and 1 for Right; nil once it
#   changed, else why not.
# - menu(key, path): with path empty the buttons beside the pane's title, else the choices after the
#   button and the choices in path; each [text, enabled]; none once path is complete.
# - choose(key, path): takes the complete path and tells what happened, or nil.

# The pages mods offer to other mods' screens, kept apart from every mod.
module ModPages
  @pages = []

  # Adds a page once.
  #
  # @param page [Object] The page, answering what world_overview_mods.rbx lists.
  def self.add(page)
    @pages << page unless @pages.include?(page)
  end

  # Lists the pages added, in their order.
  #
  # @return [Array<Object>] The pages.
  def self.all
    @pages.dup
  end
end unless defined?(ModPages)

module MGQ_MpWorldOverview
  # What starts a mod page's key among the pages, followed by its place in ModPages.all.
  MOD_PAGE = "mod_"

  # A mod page's entry: its page, its key, and what its row shows, read with the page's model so
  # the drawing sees a change.
  ModEntry = Struct.new(:page, :key, :row)

  # A pane line of a mod page that Left and Right change: its id, its name, its note at the right,
  # its tone, and whether Left and Right may change it.
  Control = Struct.new(:id, :name, :note, :tone, :less, :more)

  # The choices taken in the open menu of a mod page's entry, the button first, before the one
  # picked.
  @menu_path = []

  # Lists the tabs of the mod pages that have something to show, at most MOD_TABS; asked once a
  # frame, since the overview asks for its pages many times a frame.
  #
  # @return [Array<Array>] Each page's key and its tab's title.
  def self.mod_tabs
    return @mod_tabs if @mod_tabs && @mod_tabs_at == Graphics.frame_count

    tabs = []
    ModPages.all.each_with_index do |page, index|
      break if tabs.size >= MOD_TABS

      shown = begin
        page.shown?
      rescue => e
        log_once([:mod_shown, index], "a mod page failed to tell whether it shows: #{e.class}: #{e.message}")
        false
      end
      tabs << [:"#{MOD_PAGE}#{index}", page.title.to_s] if shown
    end
    @mod_tabs_at = Graphics.frame_count
    @mod_tabs = tabs
  end

  # Reports whether a page is a mod's.
  #
  # @param page [Symbol] The page.
  # @return [Boolean] Whether it is.
  def self.mod_page?(page)
    page.to_s.start_with?(MOD_PAGE)
  end

  # Finds the mod's page behind a page's key.
  #
  # @param page [Symbol] The page's key, see mod_tabs.
  # @return [Object, nil] The page; nil once the mod no longer offers it.
  def self.mod_page(page)
    ModPages.all[page.to_s[MOD_PAGE.size..-1].to_i]
  end

  # Lays a mod page out: its head, and its groups with their entries in the list.
  #
  # @param page [Symbol] The page's key.
  # @return [Model] The model.
  def self.mod_model(page)
    mod = mod_page(page)
    title, note, lines, looks = mod.head
    head = Head.new(looks ? Looks.new(*looks) : nil, nil, title.to_s, note, Array(lines).map { |line| line.to_s }, nil, nil)
    list = []
    mod.groups.each do |group, keys|
      entries = keys.map { |key| ModEntry.new(page, key, mod.row(key)) }
      add_group(list, page, group, BOSS_SECTION % [group, entries.size], true, entries)
    end
    Model.new(head, list, picks_of(list))
  end

  # Tells what a list row shows of a mod page's entry.
  #
  # @param entry [ModEntry] The entry.
  # @return [RowView] The row.
  def self.mod_row_view(entry)
    label, text, note, dim = entry.row
    RowView.new(label, text.to_s, note, dim ? true : false, nil)
  end

  # Tells what the reading pane shows of a mod page's entry, read every READ_FRAMES or once
  # forget_model asked for its page again; only the entry picked is read, since a mod's pane may
  # take long to work out.
  #
  # @param entry [ModEntry] The entry.
  # @return [Pane] The pane.
  def self.mod_pane(entry)
    @mod_panes ||= {}
    key = [entry.page, entry.key]
    at, pane = @mod_panes[key]
    now = Graphics.frame_count
    return pane if pane && now - at < READ_FRAMES && now >= at

    pane = read_mod_pane(entry)
    @mod_panes[key] = [now, pane]
    pane
  end

  # Reads what the reading pane shows of a mod page's entry from its page, with the buttons beside
  # its title.
  #
  # @param entry [ModEntry] The entry.
  # @return [Pane] The pane; an empty one once the page failed.
  def self.read_mod_pane(entry)
    mod = mod_page(entry.page)
    title, looks, lines, subtitle = mod.pane(entry.key)
    lines = Array(lines).map do |kind, *rest|
      case kind
      when :item then [:item, PaneItem.new(nil, nil, *rest.first(3))]
      when :control then [:control, Control.new(*rest.first(6))]
      else [kind, *rest]
      end
    end
    buttons = mod.menu(entry.key, []).map { |text, enabled| [text.to_s, enabled ? true : false] }
    Pane.new(title.to_s, looks ? Looks.new(*looks) : nil, lines, buttons, subtitle && subtitle.to_s)
  rescue => e
    log_once([:mod_pane, entry.page], "a mod page's pane failed: #{e.class}: #{e.message}")
    Pane.new("", nil, [], [])
  end

  # Forgets the panes read of a page's entries.
  #
  # @param page [Symbol] The page.
  def self.forget_mod_panes(page)
    @mod_panes.delete_if { |key, _| key[0] == page } if @mod_panes
  end

  # Lists what the cursor steps to in a mod page's pane: the buttons beside its title, then its
  # controls.
  #
  # @param pane [Pane, nil] The pane.
  # @return [Array<Array>] Each [:button, index] or [:control, id].
  def self.focus_targets(pane)
    return [] unless pane

    buttons = (0...Array(pane.buttons).size).map { |index| [:button, index] }
    buttons + pane.lines.select { |kind, _| kind == :control }.map { |_, control| [:control, control.id] }
  end

  # Moves the cursor into the pane of a mod page's entry, onto its first control, or its first
  # button without one.
  #
  # @param page [Symbol] The page.
  # @param entry [ModEntry] The entry.
  def self.focus_pane(page, entry)
    targets = focus_targets(pane_of(entry))
    return Sound.play_buzzer if targets.empty?

    Sound.play_ok
    @focus = targets.index { |kind, _| kind == :control } || 0
    keep_focus_in_sight(page)
    log("into the pane of #{entry.key} on the #{mod_page(page).title} page")
  end

  # Moves the cursor back into the list from a mod page's pane, or into the pane from the list.
  #
  # @param page [Symbol] The page.
  # @param entry [ModEntry] The entry picked.
  # @param view [Hash] The page's view, see split_view.
  def self.leave_or_focus_pane(page, entry, view)
    return focus_pane(page, entry) unless view[:focused]

    Sound.play_cancel
    @focus = nil
  end

  # Moves the cursor in a pane to another of its targets, keeping it in sight.
  #
  # @param page [Symbol] The page.
  # @param index [Integer] The target, see focus_targets.
  def self.move_focus(page, index)
    @focus = index
    keep_focus_in_sight(page)
    Sound.play_cursor
  end

  # Scrolls the pane so that the control the cursor is on shows.
  #
  # @param page [Symbol] The page.
  def self.keep_focus_in_sight(page)
    state = split_state(page)
    pane = pane_of(model(page).picks[state[:pick]])
    kind, id = focus_targets(pane)[@focus.to_i]
    return unless kind == :control

    row = Sprite_MpWorldOverview.pane_layout(pane).index { |line, value, _| line == :control && value.id == id }
    return unless row

    state[:pane] = row if row < state[:pane]
    state[:pane] += 1 until state[:pane] >= row || Sprite_MpWorldOverview.pane_row_shown?(pane, state[:pane], row)
  end

  # Follows the keys while the cursor is in a mod page's pane: Up and Down step through its buttons
  # and controls, Left and Right change a control or step between the buttons, confirm presses a
  # button, Ctrl or cancel go back to the list.
  #
  # @param page [Symbol] The page.
  # @param entry [ModEntry] The entry whose pane it is.
  # @param view [Hash] The page's view, see split_view.
  def self.update_focus(page, entry, view)
    return leave_or_focus_pane(page, entry, view) if MGQ_MpUi.cancel? || MGQ_Multiplayer::Capture.trigger?(:CTRL)

    kind, value = view[:focused]
    return press_button(entry, value) if kind == :button && MGQ_Multiplayer::Capture.trigger?(:C)

    targets = view[:targets]
    step = axis_step(:UP, :DOWN)
    return move_focus(page, (@focus + step) % targets.size) if step != 0 && targets.size > 1

    side = axis_step(:LEFT, :RIGHT)
    return if side == 0
    return adjust_control(entry, value, side) if kind == :control

    beside = targets.index([:button, value + side])
    move_focus(page, beside) if beside
  end

  # Changes a control of a mod page's pane by a step, telling why not when it may not.
  #
  # @param entry [ModEntry] The entry whose pane it is.
  # @param id [Object] The control's id.
  # @param step [Integer] -1 for Left, 1 for Right.
  def self.adjust_control(entry, id, step)
    mod = mod_page(entry.page)
    refusal = mod.adjust(entry.key, id, step)
    forget_model(entry.page)
    if refusal
      Sound.play_buzzer
      MGQ_MpOverworldSync.notice(refusal.to_s)
    else
      Sound.play_cursor
    end
    log("#{step > 0 ? 'raised' : 'lowered'} #{id.inspect} of #{entry.key} on the #{mod.title} page#{refusal ? ": #{refusal}" : ''}")
  rescue => e
    log("a mod page's control failed: #{e.class}: #{e.message}")
  end

  # The open menu's choices of a mod page's entry, read once while the menu shows them.
  #
  # @param entry [ModEntry] The entry.
  # @return [Array<MGQ_MpActions::Option>] The choices; one that may be taken has a run.
  def self.mod_menu(entry)
    key = [entry.page, entry.key, @menu_path.dup]
    return @mod_menu[1] if @mod_menu && @mod_menu[0] == key

    options = mod_page(entry.page).menu(entry.key, @menu_path).map do |text, enabled|
      MGQ_MpActions::Option.new(text.to_s, enabled ? true : nil, nil)
    end
    @mod_menu = [key, options]
    options
  end

  # Presses a button beside the title of a mod page's pane, opening its menu.
  #
  # @param entry [ModEntry] The entry whose pane it is.
  # @param index [Integer] The button.
  def self.press_button(entry, index)
    button = Array(pane_of(entry).buttons)[index]
    @menu_path = [index]
    unless button && button[1] && !mod_menu(entry).empty?
      close_mod_menu
      return Sound.play_buzzer
    end
    Sound.play_ok
    @menu = 0
    log("pressed #{button[0]} of #{entry.key} on the #{mod_page(entry.page).title} page")
  end

  # Closes a mod page's menu; the cursor stays where it was.
  def self.close_mod_menu
    @menu = nil
    @menu_path = []
    @mod_menu = nil
  end

  # Steps back out of a mod page's menu: to the menu before, or out of the button's.
  def self.back_in_mod_menu
    Sound.play_cancel
    return close_mod_menu if @menu_path.size <= 1

    @menu = @menu_path.pop
  end

  # Takes a choice of a mod page's menu: one with choices after it opens them, the last one runs
  # through the page, closes the menu and reads the page again.
  #
  # @param entry [ModEntry] The entry.
  # @param index [Integer] The choice.
  def self.choose_in_mod_menu(entry, index)
    option = mod_menu(entry)[index]
    return Sound.play_buzzer unless option && option.run

    mod = mod_page(entry.page)
    path = @menu_path + [index]
    unless mod.menu(entry.key, path).empty?
      Sound.play_ok
      @menu_path = path
      @menu = 0
      return
    end
    Sound.play_ok
    close_mod_menu
    said = mod.choose(entry.key, path)
    log("chose #{option.text} for #{entry.key} on the #{mod.title} page#{said ? ": #{said}" : ''}")
    MGQ_MpOverworldSync.notice(said.to_s) if said
    forget_model(entry.page)
  rescue => e
    log("a mod page's choice failed: #{e.class}: #{e.message}")
    close_mod_menu
  end

  # Follows the mouse on a mod page's pane: a click on a button presses it, a click on a control
  # moves the cursor onto it, and on its arrows changes it.
  #
  # @param page [Symbol] The page.
  # @param view [Hash] The page's view, see split_view.
  # @param x [Integer] The mouse's x.
  # @param y [Integer] The mouse's y.
  # @return [Boolean] Whether the click met a button or a control.
  def self.click_pane(page, view, x, y)
    index, side = Sprite_MpWorldOverview.pane_target_at(x, y, view)
    return false unless index

    entry = view[:model].picks[view[:pick]]
    kind, value = view[:targets][index]
    moved = @focus != index
    @focus = index
    if kind == :button
      press_button(entry, value)
    elsif side != 0
      adjust_control(entry, value, side)
    elsif moved
      Sound.play_cursor
    end
    true
  end

  # Follows the mouse while a mod page's menu is open: pointing picks a choice, a click takes it, a
  # click beside the menu closes it.
  #
  # @param view [Hash] The page's view, see split_view.
  # @param x [Integer] The mouse's x.
  # @param y [Integer] The mouse's y.
  # @param moved [Boolean] Whether the mouse moved since the last frame.
  # @param clicked [Boolean] Whether it was clicked.
  def self.mouse_mod_menu(view, x, y, moved, clicked)
    choice = Sprite_MpWorldOverview.choice_at(x, y, view)
    @menu = choice if choice && moved
    return unless clicked
    return choose_in_mod_menu(view[:model].picks[view[:pick]], choice) if choice

    Sound.play_cancel
    log("menu closed with a click outside it")
    close_mod_menu
  end

  # Follows the keys while a mod page's menu is open: Up and Down pick a choice, confirm takes it,
  # cancel steps back.
  #
  # @param entry [ModEntry] The entry whose menu is open.
  # @param options [Array<MGQ_MpActions::Option>] The menu's choices.
  def self.update_mod_menu(entry, options)
    return back_in_mod_menu if MGQ_MpUi.cancel?
    return choose_in_mod_menu(entry, @menu) if MGQ_Multiplayer::Capture.trigger?(:C)

    step = axis_step(:UP, :DOWN)
    return if step == 0 || options.empty?

    @menu = (@menu + step) % options.size
    Sound.play_cursor
  end
end
