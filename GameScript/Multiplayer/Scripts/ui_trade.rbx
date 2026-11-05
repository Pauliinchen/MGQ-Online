#----------------------------------------------------------------
#  ui_trade.rbx
#
#  Changelog:
#      Paulinchen  2026-11-05: Told a change of an offer by its gold, tokens and amounts instead of its text
#      Paulinchen  2026-11-01: Built the trade screen of the Mod Framework's components in one window
#                            - Asked for the gold in the framework's number box
#                            - Stepped back by the game's cancel from the bag to its tab and from an offer to Confirm
#      Paulinchen  2026-10-31: Wore the look and scrolled the lists through the Mod Framework
#                            - Worded what the player reads plainly, leaving causes and internals to the log
#      Paulinchen  2026-10-24: Gave the help window the boxes' background opacity, the look now worn by every window
#      Paulinchen  2026-10-22: Let the chat box open in the trade screen, whose gold digits leave the cancel to the open chat box
#      Paulinchen  2026-10-12: Kept the bag's and the offers' pictures as tall as the rows they show
#                            - Scrolled the offers and the bag with the mouse wheel and drew their scrollbars
#      Paulinchen  2026-10-11: Dressed the trade screen's windows in the interface look
#                            - Asked through the confirm box before cancelling the trade
#                            - Left the commands alone once the trade ended under the confirm box
#                            - Took the marks' colors from the shared style
#      Paulinchen  2026-10-08: Closed with the numpad's 0 through MGQ_MpUi.cancel?
#      Paulinchen  2026-10-07: Logged where the screen failed and the pictures in memory
#                            - Cut names through MGQ_MpUi.cut and took the window's depth from MGQ_MpUi
#                            - Logged the trade screen opening and closing, and the gold typed
#                            - Showed the messages about the trade in the status line for a few seconds
#                            - Drew an offer's head smaller, cut to fit beside whether its player confirmed
#      Paulinchen  2026-10-06: Kept the cursor in the offer it switched to
#                            - Said in the status line while a cancel waits for the relay
#                            - Read the other player's confirmation through MGQ_MpTrade::Session#their_confirmed?
#                            - Created
#
#----------------------------------------------------------------

# The trade screen (trade.rbx): one Mod Framework window with both offers side by side, the
# player's bag below by the game's categories, and buttons to change the gold, confirm and cancel.
# The world keeps running behind it (core_async.rbx), and it closes once the trade ended.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpTradeUi
  # The Mod Framework's components.
  UI = Mod_Framework::UI

  # What the question box asks before the trade is cancelled, with the other player's name.
  CANCEL_QUESTION = "Cancel the trade with %s? Both offers are lost."

  # The question box's choices for cancelling: the yes and the no label.
  CANCEL_CHOICES = ["Cancel trade", "Keep trading"]

  # The bag's categories, by the tab that shows them.
  CATEGORIES = [[:item, "Items"], [:weapon, "Weapons"], [:armor, "Armor"], [:stone, "Stones"]]

  # The window's title, with the other player's name.
  TITLE = "Trading with %s"

  # Pixels between whose offer it is and whether its player confirmed, in an offer's head.
  HEAD_GAP = 8

  # Pixels between the two offers.
  OFFER_GAP = 8

  # Pixels inside an offer's frame.
  OFFER_PADDING = 4

  # Lines of the game's font an offer is high: its head and five rows.
  OFFER_LINES = 6

  # Lines of the small font the status takes, so the parts under it never move.
  STATUS_LINES = 2

  # Digits of the largest amount of gold the gold box takes.
  GOLD_DIGITS = 9

  # Items one press of the game's L or R offers more or fewer.
  PAGE_STEP = 10

  # The window's id, which a window made anew finds the focus by.
  WINDOW_ID = :mgq_online_trade

  # Reports whether an item belongs to a category of the bag.
  #
  # @param item [RPG::BaseItem] The item.
  # @param category [Symbol] A category of CATEGORIES.
  # @return [Boolean] Whether it does.
  def self.in_category?(item, category)
    case category
    when :item then item.is_a?(RPG::Item) && !MGQ_MpTrade::Items.stone?(item)
    when :weapon then item.is_a?(RPG::Weapon)
    when :armor then item.is_a?(RPG::Armor)
    when :stone then MGQ_MpTrade::Items.stone?(item)
    else false
    end
  end

  # Says how the trade stands, for the screen's status line: a message about the trade while it
  # lasts, such as a refused confirmation.
  #
  # @param session [MGQ_MpTrade::Session] The trade.
  # @return [String] The line.
  def self.status_line(session)
    note = MGQ_MpTrade.note
    return note if note
    return "Cancelling the trade . . ." if session.leaving
    return "Completing the trade . . ." if session.stage == :committing
    return "Confirm once both offers are right. Any change takes both confirmations back." unless session.confirmed

    refusal = MGQ_MpTrade.confirm_refusal
    return refusal if refusal

    "You confirmed. Waiting for #{session.name} . . ."
  end

  # The trade screen's window: it builds the components, reads the trade into them each frame and
  # acts on what the player does in them.
  class Screen
    # @return [UI::Window] The window.
    attr_reader :window

    # @return [UI::Label] The status line.
    attr_reader :status

    # @return [Hash{Symbol => Hash}] Each side's parts by :mine and :theirs: :box, :name, :count,
    #   :mark and :list.
    attr_reader :sides

    # @return [UI::Tabs] The bag's tabs.
    attr_reader :tabs

    # @return [Array<UI::List>] The bag's lists, one per category of CATEGORIES.
    attr_reader :bags

    # @return [UI::Button] The button that opens the gold box.
    attr_reader :gold_button

    # @return [UI::Button] The button that confirms or takes the confirmation back.
    attr_reader :confirm_button

    # @return [UI::Button] The button that asks whether to cancel the trade.
    attr_reader :cancel_button

    # @return [UI::KeyHelp] The key help line.
    attr_reader :key_help

    # Builds the window, closed.
    #
    # @param name [String] The other player's name.
    def initialize(name)
      @shown = {}
      @place = :bar
      @window = UI::Window.new(:id => WINDOW_ID, :title => format(TITLE, name), :size => :screen, :captures => true, :hosts_scene => true,
                               :closable => true, :log => MGQ_MpTrade)
      @status = @window.add_label("", :font_size => :small, :wrap => true, :steady => true, :min_size => [0, STATUS_LINES * UI::SMALL_LINE_HEIGHT])
      offers = @window.add_row(:gap => OFFER_GAP, :height => OFFER_LINES * UI::LINE_HEIGHT + 2 * OFFER_PADDING)
      @sides = { :mine => build_side(offers, :mine), :theirs => build_side(offers, :theirs) }
      build_bag
      @key_help = @window.add_key_help(key_entries)
      @sides.each_value { |side| side[:list].cancel_to = @confirm_button }
      @window.on(:cancel) { guard("cancelling") { ask_cancel }; false }
      @window.on(:page) { |step, _pad| page_bag(step) }
    end

    # Opens the window, the focus on the first tab.
    #
    # @return [Boolean] Whether it opened.
    def open
      @tabs.tab(0).focus
      @window.open.open?
    end

    # Tells whether the window is open.
    #
    # @return [Boolean] Whether it is.
    def open?
      @window.open?
    end

    # Closes the window and the boxes the screen opened over it.
    def close
      gold_box = @gold_box
      @gold_box = nil
      gold_box.close(:script) if gold_box && gold_box.open?
      asking = @asking
      @asking = false
      UI::Confirm.close("the trade ended") if asking && UI::Confirm.open?
      @window.close(:script)
    end

    # Reads the trade into the components, each only once what it shows changed.
    #
    # @param session [MGQ_MpTrade::Session] The trade.
    def update(session)
      show_side(:mine, session)
      show_side(:theirs, session)
      show_state(session)
      show_bag(session)
      line = MGQ_MpTradeUi.status_line(session)
      @status.text = line unless @status.text == line
      place = focus_place
      return if place == @place

      @place = place
      @key_help.refresh
    end

    # Fills a tab's list with the category's tradeable items, the cursor on the first.
    #
    # @param index [Integer] The tab's place in CATEGORIES.
    def fill_bag(index)
      session = MGQ_MpTrade.session
      return unless session

      category = CATEGORIES[index][0]
      list = @bags[index]
      list.rows = MGQ_MpTrade::Items.bag.select { |item| MGQ_MpTradeUi.in_category?(item, category) }.map { |item| bag_row(item, session) }
      list.index = 0
      @bag_offer = MGQ_MpTrade::Items.key(session.mine)
    end

    # Changes how many of a row's item the offer holds: the cursor sound and the row drawn anew,
    # or the buzzer and the reason in the log when nothing changed.
    #
    # @param list [UI::List] The bag's list.
    # @param place [Integer] The row.
    # @param step [Integer] How many more, fewer when negative.
    def step_bag(list, place, step)
      session = MGQ_MpTrade.session
      row = list.row_at(place)
      return unless session && row.is_a?(Hash) && row[:item]

      item = row[:item]
      before = offered(item, session)
      MGQ_MpTrade.set_amount(item, before + step)
      return refuse_step(item, before, step) if offered(item, session) == before

      Sound.play_cursor
      list.set_row(place, bag_row(item, session))
      @bag_offer = MGQ_MpTrade::Items.key(session.mine)
    end

    # Offers all of a row's item, or none once all are offered.
    #
    # @param list [UI::List] The bag's list.
    # @param place [Integer] The row.
    def all_or_none(list, place)
      session = MGQ_MpTrade.session
      row = list.row_at(place)
      return UI.buzz unless session && row.is_a?(Hash) && row[:item]

      item = row[:item]
      most = [MGQ_MpTrade::Items.held(item), MGQ_MpTrade::Items.unique?(item) ? 1 : MGQ_MpTrade::MAX_AMOUNT].min
      before = offered(item, session)
      step_bag(list, place, (before == most ? 0 : most) - before)
    end

    # Opens the gold box at the gold offered; its answer offers the gold, at most the party's.
    def ask_gold
      session = MGQ_MpTrade.session
      return unless session

      unit = Vocab::currency_unit
      MGQ_MpTrade.log("gold box opened at #{session.mine.gold.to_i} gold")
      @gold_box = UI::NumberField.ask(session.mine.gold.to_i, :digits => GOLD_DIGITS, :unit => unit, :max => $game_party.gold,
                                                             :note => "You have #{$game_party.gold} #{unit}", :ok_text => "Offer", :cancel_text => "Back") do |number, _shown|
        guard("the gold box") { take_gold(number) }
      end
      MGQ_MpTrade.log("the gold box did not open") unless @gold_box.open?
    end

    # Offers the gold the box gave, or keeps the gold as it was.
    #
    # @param number [Integer, nil] The gold, nil when the box closed without an offer.
    def take_gold(number)
      @gold_box = nil
      return MGQ_MpTrade.log("the gold box closed without an offer") if number.nil? || MGQ_MpTrade.session.nil?

      MGQ_MpTrade.log("typed #{number} gold to offer")
      MGQ_MpTrade.set_gold(number)
    end

    # Confirms both offers as they stand, or takes the confirmation back: the buzzer and the reason
    # in the log when the confirmation does not hold, the confirm sound otherwise.
    def toggle_confirm
      session = MGQ_MpTrade.session
      return UI.buzz unless session && session.stage == :open

      refusal = session.confirmed ? nil : MGQ_MpTrade.confirm_refusal
      MGQ_MpTrade.toggle_confirm
      return UI.confirm_sound unless refusal

      MGQ_MpTrade.log("not confirmed: #{refusal}")
      UI.buzz
    end

    # Asks through the question box whether to cancel the trade, since both offers are lost: yes
    # cancels it; no, and a box that could not open, leave the focus where it was.
    def ask_cancel
      session = MGQ_MpTrade.session
      return unless session

      MGQ_MpTrade.log("asked whether to cancel the trade with #{session.name}")
      asked = UI::Confirm.ask(format(CANCEL_QUESTION, session.name), CANCEL_CHOICES) { |yes| guard("the cancel question") { answer_cancel(yes) } }
      return @asking = true if asked

      MGQ_MpTrade.log("the question did not open, so trading goes on")
    end

    # Cancels the trade on yes. It touches no component, since the trade may have ended under the
    # box, and a box the screen closed itself answers nothing.
    #
    # @param yes [Boolean] Whether the player chose to cancel.
    def answer_cancel(yes)
      return unless @asking

      @asking = false
      MGQ_MpTrade.log(yes ? "chose to cancel the trade" : "chose to keep trading")
      MGQ_MpTrade.cancel if yes && MGQ_MpTrade.session
    end

    # Tells where the focus is, for the key help: :bag, :offers or :bar.
    #
    # @return [Symbol] The place.
    def focus_place
      return :bag if @bags.any? { |list| list.focused? }
      return :offers if @sides.values.any? { |side| side[:list].focused? }

      :bar
    end

    # Runs a block of the screen; a failure is logged with its place and closes the window, which
    # the scene takes as the end of the trade.
    #
    # @param place [String] What runs, for the log.
    # @return [Object, nil] The block's value, nil after a failure.
    def guard(place)
      yield
    rescue => e
      MGQ_MpTrade.log("trade screen failed in #{place}: #{MGQ_MpLog.failure(e)} at #{Array(e.backtrace).first}")
      close
      nil
    end

    private

    # Builds one side's offer: a head with whose offer it is, its count and whether its player
    # confirmed, and the list of its gold and items.
    #
    # @param row [UI::Component] The row the offers lie in.
    # @param side [Symbol] :mine or :theirs.
    # @return [Hash] The side's parts.
    def build_side(row, side)
      box = row.add_box(:grow => 1, :padding => OFFER_PADDING)
      head = box.add_row(:gap => HEAD_GAP, :justify => :between)
      who = head.add_row(:shrink => true)
      parts = { :box => box }
      parts[:name] = who.add_label(side == :mine ? "You" : "", :font_size => :small, :color => :system, :shrink => true)
      parts[:count] = who.add_label("", :font_size => :small, :color => :system)
      parts[:mark] = head.add_label("Not confirmed", :font_size => :small, :color => :dim)
      parts[:list] = box.add_list(:id => :"mgq_online_trade_#{side}", :rows => [], :rows_shown => :fill, :grow => 1, :leave_ends => true, :describe => true)
      parts
    end

    # Builds the bag: a tab per category, each with its list, and the gold, confirm and cancel
    # buttons beside the tabs.
    def build_bag
      @tabs = @window.add_tabs(:grow => 1, :enter => true, :index => 0)
      @bags = CATEGORIES.each_with_index.map { |(category, name), index| build_bag_list(category, name, index) }
      @tabs.on(:change) { |index| guard("the tabs") { pick_tab(index) } }
      @gold_button = @tabs.bar.add_button("Gold")
      @gold_button.on(:click) { guard("the gold") { ask_gold } }
      @confirm_button = @tabs.bar.add_button("Confirm", :quiet => true)
      @confirm_button.on(:click) { guard("confirming") { toggle_confirm } }
      @cancel_button = @tabs.bar.add_button("Cancel")
      @cancel_button.on(:click) { guard("cancelling") { ask_cancel } }
    end

    # Builds a tab of the bag with its list: Left and Right step the amount, confirm offers all or
    # none, and cancel goes back to the tab.
    #
    # @param category [Symbol] The category.
    # @param name [String] The tab's text.
    # @param index [Integer] The tab's place.
    # @return [UI::List] The list.
    def build_bag_list(category, name, index)
      list = @tabs.add_tab(name, :grow => 1).add_list(:id => :"mgq_online_trade_bag_#{category}", :rows => [], :rows_shown => :fill, :grow => 1,
                                                      :sides => true, :shoulder_pages => false, :leave_ends => true, :describe => true,
                                                      :quiet => true, :empty_text => "Nothing to trade")
      list.cancel_to = @tabs.tab(index)
      list.on(:side) { |_row, place, step| guard("the bag") { step_bag(list, place, step) } }
      list.on(:submit) { |_row, place| guard("the bag") { all_or_none(list, place) } }
      list
    end

    # Shows a category of the bag.
    #
    # @param index [Integer] The tab's place in CATEGORIES.
    def pick_tab(index)
      MGQ_MpTrade.log("showing the bag's #{CATEGORIES[index][1]}")
      fill_bag(index)
    end

    # Steps the item under the bag's cursor by ten, for the game's L and R, which the lists leave
    # alone.
    #
    # @param step [Integer] -1 for L, 1 for R.
    def page_bag(step)
      list = @bags.find { |each| each.focused? }
      guard("the bag") { step_bag(list, list.index, step * PAGE_STEP) } if list
    end

    # Lists the key help's entries, each shown while the focus is where it names.
    #
    # Cancel comes first, as a line too wide for the window leaves out entries from the last.
    #
    # @return [Array<Hash>] The entries.
    def key_entries
      [{ :button => :B, :text => lambda { @place == :bar ? "Cancel the trade" : "Back" } },
       { :key => "Left/Right", :text => lambda { @place == :bag ? "1 more or less" : nil } },
       { :button => [:L, :R], :text => lambda { @place == :bag ? "10 less or more" : nil } },
       { :button => :C, :text => lambda { @place == :bag ? "All or none" : nil } },
       { :key => "Up", :text => lambda { @place == :bar ? "Offers" : nil } }]
    end

    # Reads one side's offer into its head and list, once the offer, its confirmation or the stage
    # changed; the other player's box pulses when their offer changed.
    #
    # @param side [Symbol] :mine or :theirs.
    # @param session [MGQ_MpTrade::Session] The trade.
    def show_side(side, session)
      own = side == :mine
      offer = own ? session.mine : session.theirs
      confirmed = own ? session.confirmed : session.their_confirmed?
      offer_key = MGQ_MpTrade::Items.key(offer)
      shown = [offer_key, confirmed, session.stage]
      before = @shown[side]
      return if shown == before

      @shown[side] = shown
      parts = @sides[side]
      parts[:name].text = session.name unless own
      parts[:count].text = offer.entries.empty? ? "" : " (#{offer.entries.size})"
      parts[:mark].text = confirmed ? "Confirmed" : "Not confirmed"
      parts[:mark].color = confirmed ? :good : :dim
      parts[:list].rows = offer_rows(offer)
      parts[:box].pulse if !own && before && before[0] != offer_key
    end

    # Lists an offer's rows: the gold, then each item with its amount, an item this game does not
    # know faint.
    #
    # @param offer [MGQ_MpTrade::Offer] The offer.
    # @return [Array<Hash>] The rows.
    def offer_rows(offer)
      gold = { :text => "Gold", :right => "#{offer.gold.to_i} #{Vocab::currency_unit}" }
      [gold] + offer.entries.map do |entry|
        amount = "x#{entry.amount}"
        entry.item ? { :item => entry.item, :right => amount } : { :text => "Unknown item", :faint => true, :right => amount }
      end
    end

    # Follows the stage and the player's confirmation: the confirm button's text, and the tabs,
    # gold, confirm and the bag taking input only while the trade is open, the focus moved to
    # Cancel from what stops taking it.
    #
    # @param session [MGQ_MpTrade::Session] The trade.
    def show_state(session)
      shown = [session.stage, session.confirmed]
      return if shown == @shown[:state]

      @shown[:state] = shown
      @confirm_button.text = session.confirmed ? "Unconfirm" : "Confirm"
      open = session.stage == :open
      parts = (0...CATEGORIES.size).map { |index| @tabs.tab(index) } + [@gold_button, @confirm_button] + @bags
      focused = parts.any? { |part| part.focused? }
      parts.each { |part| part.enabled = open }
      @cancel_button.focus if focused && !open
    end

    # Fills the picked tab's list anew, the cursor kept, when the player's offer changed other than
    # by a step of the bag, which draws its own row.
    #
    # @param session [MGQ_MpTrade::Session] The trade.
    def show_bag(session)
      return if MGQ_MpTrade::Items.key(session.mine) == @bag_offer

      list = @bags[@tabs.index]
      kept = list.index
      fill_bag(@tabs.index)
      list.index = [kept, 0].max
    end

    # Writes a row of the bag: the item and how many the offer holds of how many the bag holds, in
    # the good color while some are offered.
    #
    # @param item [RPG::BaseItem] The item.
    # @param session [MGQ_MpTrade::Session] The trade.
    # @return [Hash] The row.
    def bag_row(item, session)
      offered = offered(item, session)
      row = { :item => item, :bag => true, :value => "#{offered} / #{MGQ_MpTrade::Items.held(item)}" }
      row[:right_color] = :good if offered > 0
      row
    end

    # Counts how many of an item the player's offer holds.
    #
    # @param item [RPG::BaseItem] The item.
    # @param session [MGQ_MpTrade::Session] The trade.
    # @return [Integer] How many.
    def offered(item, session)
      entry = session.mine.entry(MGQ_MpTrade::Items.token(item))
      entry ? entry.amount : 0
    end

    # Buzzes at a step of the bag that changed nothing, and logs why.
    #
    # @param item [RPG::BaseItem] The item.
    # @param before [Integer] How many the offer held.
    # @param step [Integer] The step.
    def refuse_step(item, before, step)
      why = if step == 0 then "nothing to change"
            elsif step < 0 then "none offered"
            elsif MGQ_MpTrade::Items.unique?(item) then "a unique copy goes once"
            elsif before >= MGQ_MpTrade::MAX_AMOUNT then "a trade moves at most #{MGQ_MpTrade::MAX_AMOUNT}"
            else "the bag holds #{MGQ_MpTrade::Items.held(item)}"
            end
      MGQ_MpTrade.log("not offering #{step < 0 ? 'fewer' : 'more'} of #{MGQ_MpTrade::Items.label(item)}: #{why}")
      UI.buzz
    end
  end
end

# The trade screen: a scene of its own that hosts the screen's window, since the chat follows it by
# class and the map calls it, and returns once the trade ended.
class Scene_MpTrade < Scene_MenuBase
  # @return [MGQ_MpTradeUi::Screen, nil] The screen, nil before it was built and after it closed.
  attr_reader :screen

  # Builds and opens the window; when it does not open, the trade is cancelled.
  def start
    super
    session = MGQ_MpTrade.session
    return leave("opened, but there is no trade") unless session

    @screen = MGQ_MpTradeUi::Screen.new(session.name)
    @screen.update(session)
    return cancel_trade("the trade screen's window did not open") unless @screen.open

    MGQ_MpTrade.log("trade screen opened for trade #{MGQ_MpTrade.short(session.id)} with #{session.name}")
  rescue => e
    failed("opening the trade screen", e)
  end

  # Reads the trade into the window, and returns once the trade ended or the window closed.
  def update
    super
    return unless @screen

    session = MGQ_MpTrade.session
    unless session
      @screen.close
      return leave("closed, the trade ended")
    end
    return cancel_trade("the trade screen's window closed while the trade went on") unless @screen.open?

    @screen.update(session)
  rescue => e
    failed("the trade screen", e)
  end

  # Closes the window as the scene ends.
  def terminate
    super
    @screen.close if @screen && @screen.open?
  end

  private

  # Cancels the trade, which nothing shows any more, and returns.
  #
  # @param why [String] What happened, for the log.
  def cancel_trade(why)
    MGQ_MpTrade.log("#{why}, so the trade is cancelled")
    MGQ_MpTrade.cancel
    @screen = nil
    return_scene
  end

  # Logs and returns.
  #
  # @param what [String] What happened, after "trade screen ".
  def leave(what)
    MGQ_MpTrade.log("trade screen #{what}")
    @screen = nil
    return_scene
  end

  # Logs a failure with its place, cancels the trade and returns.
  #
  # @param place [String] What failed.
  # @param error [Exception] The failure.
  def failed(place, error)
    MGQ_MpTrade.log("#{place} failed: #{MGQ_MpLog.failure(error)} at #{Array(error.backtrace).first}")
    MGQ_MpTrade.cancel
    @screen.close if @screen
    @screen = nil
    return_scene
  end
end

# The chat box in the trade screen, through ui_chat.rbx.

begin
  MGQ_MpChat.follow_scene(Scene_MpTrade) if defined?(MGQ_MpChat)
rescue => e
  MGQ_MpChat.log("chat in the trade screen FAILED: #{e.class}: #{e.message}")
end
