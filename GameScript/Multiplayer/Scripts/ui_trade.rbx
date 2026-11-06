#----------------------------------------------------------------
#  ui_trade.rbx
#
#  Changelog:
#      Paulinchen  2026-11-07: Left the way back from the bag to its tab to the framework and gave the gold box its unit as adornment:
#      Paulinchen  2026-11-06: Took how many of an item an offer holds and why a step changed nothing from the rules in C#
#      Paulinchen  2026-11-06: Drew the trade screen through the UI layer: Q and W step the bag by ten, Page Up and Down page it, cancel in an offer asks
#                            - Told the chat whether the gold box or the question is open
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

# The trade screen (trade.rbx): one window of the UI layer with both offers side by side, the
# player's bag below by the game's categories, and buttons to change the gold, confirm and cancel.
# The world keeps running behind it (core_async.rbx), and it closes once the trade ended.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpTradeUi
  # The Mod Framework's UI.
  UI = Mod_Framework::UI

  # What the question box asks before the trade is cancelled, with the other player's name.
  CANCEL_QUESTION = "Cancel the trade with %s? Both offers are lost."

  # The question's answers: the one that cancels and the one that keeps trading.
  CANCEL_YES = "Cancel trade"
  CANCEL_NO = "Keep trading"

  # The bag's categories, by the tab that shows them.
  CATEGORIES = [[:item, "Items"], [:weapon, "Weapons"], [:armor, "Armor"], [:stone, "Stones"]]

  # The window's title, with the other player's name.
  TITLE = "Trading with %s"

  # Pixels the offers are high: a head and five rows of the game's lists.
  OFFERS_HEIGHT = 6 * 24 + 8

  # Lines the status takes at most.
  STATUS_LINES = 2

  # Items one press of Q or W offers more or fewer.
  PAGE_STEP = 10

  # The window's id.
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

  # Tells what the screen shows of the trade, which renders it anew once it changed: both offers,
  # both confirmations, the stage and the status line.
  #
  # @return [Array, nil] The signature, nil without a trade.
  def self.signature
    session = MGQ_MpTrade.session
    return nil unless session

    [MGQ_MpTrade::Items.key(session.mine), MGQ_MpTrade::Items.key(session.theirs), session.confirmed, session.their_confirmed?, session.stage,
     status_line(session)]
  end

  # Notes the gold box or the question the screen opened, which holds the game's buttons over the
  # screen until it closes.
  #
  # @param handle [Object, false, nil] The box's handle, false or nil when it did not open.
  def self.asked(handle)
    @asked = handle || nil
  end

  # Tells whether the screen's gold box or question is open, which the chat box waits for.
  #
  # @return [Boolean] Whether one is.
  def self.asking?
    @asked && @asked.open? ? true : false
  end

  # Runs a part of the screen; a failure is logged with its place, and the trade is cancelled,
  # since a screen that failed must not hold it.
  #
  # @param place [String] What runs, for the log.
  # @return [Object, nil] The block's value, nil after a failure.
  def self.guard(place)
    yield
  rescue => e
    MGQ_MpTrade.log("trade screen failed in #{place}: #{MGQ_MpLog.failure(e)} at #{Array(e.backtrace).first}")
    MGQ_MpTrade.cancel if MGQ_MpTrade.session
    nil
  end

  # The trade screen: both offers, the bag's tabs with Gold, Confirm and Cancel, and the bag.
  class TradeScreen < UI::Component
    # The other player's name.
    param :name

    # The category of the bag the tabs show.
    state :category, :item

    # The item the bag's cursor is on.
    state :bag_item

    # The row the cursor of the player's offer is on.
    state :mine_row

    # The row the cursor of the other player's offer is on.
    state :theirs_row

    # The stage the screen showed last, so the focus moves to Cancel once the relay decides.
    state :shown_stage

    watch { MGQ_MpTradeUi.signature }
    watch { follow_stage }

    # Describes the screen.
    def render
      session = MGQ_MpTrade.session
      committing = session.nil? || session.stage != :open
      window format(TITLE, name), id: WINDOW_ID, width: :screen, height: :screen, movable: false, on_cancel: -> { ask_cancel; false } do
        text session ? MGQ_MpTradeUi.status_line(session) : "", id: :mgq_online_trade_status, typo: :body2, wrap: true, most_lines: STATUS_LINES
        if session
          stack row: true, height: OFFERS_HEIGHT do
            offer_box(:mine, "You", session.mine, session.confirmed, :mine_row)
            offer_box(:theirs, session.name, session.theirs, session.their_confirmed?, :theirs_row)
          end
        end
        stack row: true do
          tabs bind: :category, pages: false, enter: true, id: :mgq_online_trade_tabs, disabled: committing,
               on_change: ->(picked) { MGQ_MpTrade.log("showing the bag's #{picked}") } do
            CATEGORIES.each { |kind, text| tab text, id: kind }
          end
          button "Gold", id: :mgq_online_trade_gold, disabled: committing, on_click: -> { MGQ_MpTradeUi.guard("the gold") { ask_gold } }
          button session && session.confirmed ? "Unconfirm" : "Confirm", id: :mgq_online_trade_confirm, disabled: committing,
                                                                       on_click: -> { MGQ_MpTradeUi.guard("confirming") { toggle_confirm } }
          button "Cancel", id: :mgq_online_trade_cancel, on_click: -> { ask_cancel }
        end
        list bag, id: :mgq_online_trade_bag, bind: :bag_item, height: :fill, rows_shown: :fill, describe: true, empty: "Nothing to trade",
                  row: ->(item) { bag_row(item) }, disabled: committing,
                  on_side: ->(item, step) { MGQ_MpTradeUi.guard("the bag") { step_bag(item, step) } },
                  on_submit: ->(item) { MGQ_MpTradeUi.guard("the bag") { all_or_none(item) } },
                  on_page: ->(step) { MGQ_MpTradeUi.guard("the bag") { step_bag(bag_item, step * PAGE_STEP) if bag_item } }
        key_help entries: [{ key: "Left/Right", text: "1 more or less" }, { key: "Q/W", text: "10 more or less" }, { button: :C, text: "All or none" },
                           { button: :B, text: "Back" }]
      end
    end

    # Writes a row of the bag: the item and how many the offer holds of how many the bag holds, in
    # the success color while some are offered, its arrows dim where a step goes no further.
    #
    # @param item [RPG::BaseItem] The item.
    # @return [Hash] The row.
    def bag_row(item)
      offered = offered(item)
      held = MGQ_MpTrade::Items.held(item)
      row = { :item => item, :value => "#{offered} / #{held}", :less => offered > 0, :more => offered < most(item) }
      row[:right_color] = :success if offered > 0
      row
    end

    private

    # Describes one side's offer: whose it is with its count and whether its player confirmed, and
    # its gold and items. The other player's box pulses as their offer changes.
    #
    # @param side [Symbol] :mine or :theirs.
    # @param who [String] Whose offer it is.
    # @param offer [MGQ_MpTrade::Offer] The offer.
    # @param confirmed [Boolean] Whether its player confirmed.
    # @param bind [Symbol] The state its cursor's row is kept in.
    def offer_box(side, who, offer, confirmed, bind)
      paper id: :"mgq_online_trade_#{side}", grow: 1, height: :fill, pulse: (side == :theirs ? MGQ_MpTrade::Items.key(offer) : nil) do
        stack row: true, justify: :space_between do
          text "#{who}#{offer.entries.empty? ? '' : " (#{offer.entries.size})"}", color: :system, typo: :caption, most_lines: 1
          text confirmed ? "Confirmed" : "Not confirmed", color: confirmed ? :success : :dim, typo: :caption
        end
        list offer_rows(offer), id: :"mgq_online_trade_#{side}_rows", bind: bind, height: :fill, rows_shown: :fill, describe: true
      end
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

    # Lists the bag's tradeable items of the tab's category.
    #
    # @return [Array<RPG::BaseItem>] The items.
    def bag
      MGQ_MpTrade::Items.bag.select { |item| MGQ_MpTradeUi.in_category?(item, category) }
    end

    # Counts how many of an item the player's offer holds.
    #
    # @param item [RPG::BaseItem] The item.
    # @return [Integer] How many.
    def offered(item)
      session = MGQ_MpTrade.session
      entry = session && session.mine.entry(MGQ_MpTrade::Items.token(item))
      entry ? entry.amount : 0
    end

    # Tells the most of an item an offer may hold, as the rules in C# tell for all the bag holds.
    #
    # @param item [RPG::BaseItem] The item.
    # @return [Integer] How many.
    def most(item)
      MGQ_MpTrade::Items.amount(item, MGQ_MpTrade::Items.held(item))["amount"]
    end

    # Changes how many of an item the offer holds: the cursor sound, or the buzzer and the reason in
    # the log when nothing changed.
    #
    # @param item [RPG::BaseItem] The item.
    # @param step [Integer] How many more, fewer when negative.
    def step_bag(item, step)
      return unless MGQ_MpTrade.session && item

      before = offered(item)
      why = MGQ_MpTrade.set_amount(item, before + step)
      return refuse_step(item, step, why) if offered(item) == before

      Sound.play_cursor
    end

    # Offers all of an item, or none once all are offered.
    #
    # @param item [RPG::BaseItem] The item.
    def all_or_none(item)
      before = offered(item)
      step_bag(item, (before == most(item) ? 0 : most(item)) - before)
    end

    # Buzzes at a step of the bag that changed nothing, and logs why.
    #
    # @param item [RPG::BaseItem] The item.
    # @param step [Integer] The step.
    # @param limit [String, nil] Why the offer holds fewer than the step wanted, as the rules in C# tell.
    def refuse_step(item, step, limit)
      why = if step == 0 then "nothing to change"
            elsif step < 0 then "none offered"
            else limit || "it may not be traded"
            end
      MGQ_MpTrade.log("not offering #{step < 0 ? 'fewer' : 'more'} of #{MGQ_MpTrade::Items.label(item)}: #{why}")
      Sound.play_buzzer
    end

    # Opens the gold box at the gold offered; its answer offers the gold, at most the party's.
    def ask_gold
      session = MGQ_MpTrade.session
      return unless session

      unit = Vocab::currency_unit
      MGQ_MpTrade.log("gold box opened at #{session.mine.gold.to_i} gold")
      box = UI.number(session.mine.gold.to_i, min: 0, max: $game_party.gold, adornment: unit,
                                              note: "You have #{$game_party.gold} #{unit}", ok: "Offer", cancel: "Back") do |gold, _shown|
        MGQ_MpTradeUi.guard("the gold box") { take_gold(gold) }
      end
      MGQ_MpTradeUi.asked(box)
      MGQ_MpTrade.log("the gold box did not open") unless box
    end

    # Offers the gold the box gave, or keeps the gold as it was.
    #
    # @param gold [Integer, nil] The gold, nil when the box closed without an offer.
    def take_gold(gold)
      return MGQ_MpTrade.log("the gold box closed without an offer") if gold.nil? || MGQ_MpTrade.session.nil?

      MGQ_MpTrade.log("typed #{gold} gold to offer")
      MGQ_MpTrade.set_gold(gold)
    end

    # Confirms both offers as they stand, or takes the confirmation back: the buzzer and the reason
    # in the log when the confirmation does not hold, the confirm sound otherwise.
    def toggle_confirm
      session = MGQ_MpTrade.session
      return Sound.play_buzzer unless session && session.stage == :open

      refusal = session.confirmed ? nil : MGQ_MpTrade.confirm_refusal
      MGQ_MpTrade.toggle_confirm
      return Sound.play_ok unless refusal

      MGQ_MpTrade.log("not confirmed: #{refusal}")
      Sound.play_buzzer
    end

    # Asks whether to cancel the trade, since both offers are lost: yes cancels it; no, and a
    # question that could not open, leave the focus where it was.
    def ask_cancel
      session = MGQ_MpTrade.session
      return unless session

      MGQ_MpTrade.log("asked whether to cancel the trade with #{session.name}")
      asked = UI.confirm(format(CANCEL_QUESTION, session.name), yes: CANCEL_YES, no: CANCEL_NO) do |yes|
        MGQ_MpTradeUi.guard("the cancel question") { answer_cancel(yes) }
      end
      MGQ_MpTradeUi.asked(asked)
      MGQ_MpTrade.log("the question did not open, so trading goes on") unless asked
    end

    # Cancels the trade on yes, while it still lasts.
    #
    # @param yes [Boolean] Whether the player chose to cancel.
    def answer_cancel(yes)
      MGQ_MpTrade.log(yes ? "chose to cancel the trade" : "chose to keep trading")
      MGQ_MpTrade.cancel if yes && MGQ_MpTrade.session
    end

    # Moves the focus onto Cancel as the relay starts deciding, since every other part greys out.
    #
    # @return [Symbol, nil] The stage, nil without a trade.
    def follow_stage
      session = MGQ_MpTrade.session
      stage = session && session.stage
      part(:mgq_online_trade_cancel).focus if stage == :committing && shown_stage == :open
      self.shown_stage = stage unless shown_stage == stage
      stage
    end
  end
end

# The trade screen's scene: it hosts the screen's window, since the chat follows it by class and
# the map calls it, and returns once the trade ended.
class Scene_MpTrade < Scene_MenuBase
  # @return [Object, nil] The window's handle, nil before it opened and after it closed.
  attr_reader :screen

  # Opens the window; when it does not open, the trade is cancelled.
  def start
    super
    session = MGQ_MpTrade.session
    return leave("opened, but there is no trade") unless session

    @screen = Mod_Framework::UI.open(MGQ_MpTradeUi::TradeScreen, :name => session.name) { |_result, why| closed(why) }
    return cancel_trade("the trade screen's window did not open") unless @screen

    MGQ_MpTrade.log("trade screen opened for trade #{MGQ_MpTrade.short(session.id)} with #{session.name}")
  rescue => e
    failed("opening the trade screen", e)
  end

  # Returns once the trade ended, closing the window first.
  def update
    super
    return unless @screen && !MGQ_MpTrade.session

    screen = @screen
    @screen = nil
    screen.close if screen.open?
    leave("closed, the trade ended")
  rescue => e
    failed("the trade screen", e)
  end

  # Closes the window as the scene ends.
  def terminate
    super
    screen = @screen
    @screen = nil
    screen.close if screen && screen.open?
  end

  private

  # Follows the window closing: while the trade goes on, it is cancelled, since nothing shows it.
  #
  # @param why [Symbol, String] Why the window closed.
  def closed(why)
    return unless @screen

    cancel_trade("the trade screen's window closed (#{why}) while the trade went on")
  end

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
    screen = @screen
    @screen = nil
    screen.close if screen && screen.open?
    return_scene
  end
end

# The chat box in the trade screen, through ui_chat.rbx.

begin
  MGQ_MpChat.follow_scene(Scene_MpTrade) if defined?(MGQ_MpChat)
rescue => e
  MGQ_MpChat.log("chat in the trade screen FAILED: #{e.class}: #{e.message}")
end
