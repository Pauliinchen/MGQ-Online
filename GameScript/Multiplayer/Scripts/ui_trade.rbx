#----------------------------------------------------------------
#  ui_trade.rbx
#
#  Changelog:
#      Paulinchen  2026-10-08: Closed with the numpad's 0 through MGQ_MpUi.cancel?, also with Num Lock off
#      Paulinchen  2026-10-07: Logged where the screen failed and the pictures in memory, since a picture could not be made in the field
#                            - Cut names through MGQ_MpUi.cut and took the window's depth from MGQ_MpUi
#                            - Logged the trade screen opening and closing, and the gold typed
#                            - Showed the messages about the trade in the status line for a few seconds
#                            - Drew an offer's head smaller, as You or the other player's name cut to fit, left of whether its player confirmed
#      Paulinchen  2026-10-06: Kept the cursor in the offer it switched to, which the same press switched back before
#                            - Said in the status line while a cancel waits for the relay
#                            - Read the other player's confirmation through MGQ_MpTrade::Session#their_confirmed?
#                            - Created
#
#----------------------------------------------------------------

# The trade screen (trade.rbx): both offers side by side, the player's bag below with the game's
# categories, and commands to change the gold, confirm and cancel. The world keeps running behind
# it (core_async.rbx), and it closes once the trade ended.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpTradeUi
  # Color of a confirmed offer's mark.
  CONFIRMED_COLOR = Color.new(128, 255, 128)

  # Color of a mark that waits.
  WAITING_COLOR = Color.new(200, 200, 200)

  # Pixels between whose offer it is and whether its player confirmed, in an offer's first row.
  HEAD_GAP = 8

  # Font size of an offer's first row, smaller than the game's, so a name fits beside the status.
  HEAD_FONT_SIZE = 20

  # The bag's categories, by the command that shows them.
  CATEGORIES = [[:item, "Items"], [:weapon, "Weapons"], [:armor, "Armor"], [:stone, "Stones"]]

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

  # Says how the trade stands, for the screen's second line: a message about the trade while it
  # lasts, such as a refused confirmation.
  #
  # @param session [MGQ_MpTrade::Session] The trade.
  # @return [String] The line.
  def self.status_line(session)
    note = MGQ_MpTrade.note
    return note if note
    return "Cancelling, waiting for the relay . . ." if session.leaving
    return "Waiting for the relay . . ." if session.stage == :committing
    return "Confirm once both offers are right. Any change takes both confirmations back." unless session.confirmed

    refusal = MGQ_MpTrade.confirm_refusal
    return refusal if refusal

    "You confirmed. Waiting for #{session.name} . . ."
  end
end

# One side of the trade as a list: whose it is and whether they confirmed, the gold, then the
# items. The Offers command moves the cursor in, where up and down scroll through a long offer and
# left and right switch to the other side.
class Window_MpTradeOffer < Window_Selectable
  # Creates the window, inactive.
  #
  # @param x [Integer] Its left edge.
  # @param y [Integer] Its top edge.
  # @param width [Integer] Its width.
  # @param height [Integer] Its height.
  # @param own [Boolean] Whether it shows the player's offer.
  def initialize(x, y, width, height, own)
    # The window counts its rows while it is made, before the offer is read.
    @own = own
    @rows = []
    @shown = nil
    super(x, y, width, height)
    deactivate
  end

  # Counts the rows: whose offer, the gold, and each item.
  #
  # @return [Integer] How many.
  def item_max
    @rows.size
  end

  # Reads the offer again and draws it, if it changed.
  def update
    super
    session = MGQ_MpTrade.session
    return unless session

    offer = @own ? session.mine : session.theirs
    shown = [MGQ_MpTrade::Items.write_offer(offer), confirmed?(session), session.stage]
    return if shown == @shown

    @shown = shown
    @session = session
    @rows = [:head, :gold] + offer.entries
    @gold = offer.gold.to_i
    select([index, item_max - 1].min) if index >= 0
    refresh
  end

  # Reports whether the side's player confirmed the offers as they stand.
  #
  # @param session [MGQ_MpTrade::Session] The trade.
  # @return [Boolean] Whether they did.
  def confirmed?(session)
    @own ? session.confirmed : session.their_confirmed?
  end

  # Draws one row.
  #
  # @param index [Integer] The row.
  def draw_item(index)
    row = @rows[index]
    rect = item_rect_for_text(index)
    case row
    when :head then draw_head(rect)
    when :gold then draw_currency_value(@gold, Vocab::currency_unit, rect.x, rect.y, rect.width)
    else draw_entry(row, rect)
    end
  end

  # Draws whether its player confirmed at the right, and whose offer it is and how many items it
  # holds in the room left of that.
  #
  # @param rect [Rect] The row.
  def draw_head(rect)
    contents.font.size = MGQ_MpTradeUi::HEAD_FONT_SIZE
    confirmed = confirmed?(@session)
    status = confirmed ? "Confirmed" : "Not confirmed"
    change_color(confirmed ? MGQ_MpTradeUi::CONFIRMED_COLOR : MGQ_MpTradeUi::WAITING_COLOR)
    draw_text(rect, status, 2)
    room = rect.width - text_size(status).width - MGQ_MpTradeUi::HEAD_GAP
    change_color(system_color)
    draw_text(rect.x, rect.y, room, rect.height, head_text(room))
    reset_font_settings
  end

  # Says whose offer it is and how many items it holds, the other player's name cut to fit a width.
  #
  # @param room [Integer] The width.
  # @return [String] The text.
  def head_text(room)
    count = @rows.size - 2
    suffix = count > 0 ? " (#{count})" : ""
    return "You#{suffix}" if @own

    MGQ_MpUi.cut(self, @session.name, room, suffix)
  end

  # Draws an item and its amount.
  #
  # @param entry [MGQ_MpTrade::Entry] The item.
  # @param rect [Rect] The row.
  def draw_entry(entry, rect)
    if entry.item
      draw_item_name(entry.item, rect.x, rect.y, true, rect.width - 48)
    else
      change_color(normal_color, false)
      draw_text(rect.x + 24, rect.y, rect.width - 72, line_height, "Unknown item")
    end
    change_color(normal_color)
    draw_text(rect, "x#{entry.amount}", 2)
  end

  # Takes the input, and notes that the arrows must not move the cursor before the next frame.
  #
  # The other side's window may be updated later in the frame of the press that switched to it,
  # and would switch straight back.
  #
  # @return [Window_MpTradeOffer] The window.
  def activate
    @just_activated = true
    super
  end

  # Moves the cursor with the arrows, except in the frame the window took the input.
  def process_cursor_move
    return @just_activated = false if @just_activated

    super
  end

  # Switches to the other side.
  #
  # @param wrap [Boolean] Unused, the game's argument for wrapping round.
  def cursor_right(wrap = false)
    call_handler(:switch)
  end

  # Switches to the other side.
  #
  # @param wrap [Boolean] Unused, the game's argument for wrapping round.
  def cursor_left(wrap = false)
    call_handler(:switch)
  end
end

# The commands of the trade screen: the bag's categories, the gold, looking through both offers,
# confirming and cancelling.
class Window_MpTradeCommand < Window_HorzCommand
  # Creates the commands.
  #
  # @param y [Integer] Its top edge.
  def initialize(y)
    super(0, y)
  end

  # Returns the window's width, the screen's.
  #
  # @return [Integer] The width.
  def window_width
    Graphics.width
  end

  # Returns how many commands fit side by side.
  #
  # @return [Integer] All of them.
  def col_max
    MGQ_MpTradeUi::CATEGORIES.size + 4
  end

  # Lists the commands, enabled while the trade is open; cancelling also while the relay decides.
  def make_command_list
    session = MGQ_MpTrade.session
    open = session && session.stage == :open
    MGQ_MpTradeUi::CATEGORIES.each { |symbol, name| add_command(name, symbol, open) }
    add_command("Gold", :gold, open)
    add_command("Offers", :offers, !session.nil?)
    add_command(session && session.confirmed ? "Unconfirm" : "Confirm", :confirm, open)
    add_command("Cancel", :cancel_trade, !session.nil?)
  end

  # Lists the commands again, if the trade's stage or the player's confirmation changed.
  def update
    super
    session = MGQ_MpTrade.session
    shown = session ? [session.stage, session.confirmed] : nil
    return if shown == @shown

    @shown = shown
    refresh
  end
end

# The player's bag, one category at a time, with how many of each item the offer holds. Right and
# left change the amount by one, R and L by ten, confirm offers all or none.
class Window_MpTradeBag < Window_Selectable
  # Creates the list, inactive.
  #
  # @param y [Integer] Its top edge.
  # @param height [Integer] Its height.
  def initialize(y, height)
    # The window counts its items while it is made, before refresh lists them.
    @category = :item
    @items = []
    super(0, y, Graphics.width, height)
    refresh
    deactivate
  end

  # Shows another category.
  #
  # @param category [Symbol] A category of MGQ_MpTradeUi::CATEGORIES.
  def category=(category)
    return if @category == category

    @category = category
    refresh
    select(0)
  end

  # Counts the items listed.
  #
  # @return [Integer] How many.
  def item_max
    @items.size
  end

  # The item under the cursor.
  #
  # @return [RPG::BaseItem, nil] The item.
  def item
    @items[index]
  end

  # Lists the category's tradeable items again and draws them.
  def refresh
    @items = MGQ_MpTrade::Items.bag.select { |item| MGQ_MpTradeUi.in_category?(item, @category) }
    create_contents
    draw_all_items
  end

  # Draws one item: its name, and how many the offer holds of how many the bag holds.
  #
  # @param index [Integer] Its place in the list.
  def draw_item(index)
    item = @items[index]
    return unless item

    rect = item_rect_for_text(index)
    offered = offered(item)
    draw_item_name(item, rect.x, rect.y, true, rect.width - 120)
    change_color(offered > 0 ? MGQ_MpTradeUi::CONFIRMED_COLOR : normal_color)
    draw_text(rect.x, rect.y, rect.width, line_height, "#{offered} / #{MGQ_MpTrade::Items.held(item)}", 2)
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

  # Changes how many of the item under the cursor the offer holds.
  #
  # @param step [Integer] How many more, fewer when negative.
  def change(step)
    return unless item

    before = offered(item)
    MGQ_MpTrade.set_amount(item, before + step)
    return Sound.play_buzzer if offered(item) == before

    Sound.play_cursor
    redraw_current_item
  end

  # Offers one more.
  #
  # @param wrap [Boolean] Unused, the game's argument for wrapping round.
  def cursor_right(wrap = false)
    change(1)
  end

  # Offers one fewer.
  #
  # @param wrap [Boolean] Unused, the game's argument for wrapping round.
  def cursor_left(wrap = false)
    change(-1)
  end

  # Offers ten more.
  def cursor_pagedown
    change(10)
  end

  # Offers ten fewer.
  def cursor_pageup
    change(-10)
  end

  # Reports whether confirm does something, which it always does here.
  #
  # @return [Boolean] true.
  def ok_enabled?
    true
  end

  # Offers all of the item under the cursor, or none once all are offered.
  def process_ok
    return Sound.play_buzzer unless item

    held = [MGQ_MpTrade::Items.held(item), MGQ_MpTrade::MAX_AMOUNT].min
    change((offered(item) == held ? 0 : held) - offered(item))
  end
end

# The gold the player offers, digit by digit: left and right pick a digit, up and down change it.
class Window_MpTradeGold < Window_Base
  # Digits of the largest amount.
  DIGITS = 9

  # Width of a digit.
  DIGIT_WIDTH = 20

  # Creates the window, hidden.
  def initialize
    width = DIGITS * DIGIT_WIDTH + standard_padding * 2 + 64
    super((Graphics.width - width) / 2, (Graphics.height - fitting_height(2)) / 2, width, fitting_height(2))
    self.z = MGQ_MpUi::Z[:labels]
    self.visible = false
    @digits = [0] * DIGITS
    @place = DIGITS - 1
    @handlers = {}
  end

  # Sets what confirming and cancelling do.
  #
  # @param ok [Proc] Takes the amount.
  # @param cancel [Proc] Runs on cancel.
  def on(ok, cancel)
    @handlers = { :ok => ok, :cancel => cancel }
  end

  # Shows the window with an amount.
  #
  # @param gold [Integer] The amount.
  def start(gold)
    @digits = format("%0#{DIGITS}d", [gold.to_i, 10**DIGITS - 1].min).chars.map(&:to_i)
    @place = DIGITS - 1
    self.visible = true
    refresh
  end

  # The amount shown.
  #
  # @return [Integer] The amount.
  def amount
    @digits.join.to_i
  end

  # Follows the arrows, confirm and cancel while shown.
  def update
    super
    return unless visible

    if Input.repeat?(:LEFT) || Input.repeat?(:RIGHT)
      @place = (@place + (Input.repeat?(:RIGHT) ? 1 : -1)) % DIGITS
      Sound.play_cursor
      refresh
    elsif Input.repeat?(:UP) || Input.repeat?(:DOWN)
      @digits[@place] = (@digits[@place] + (Input.repeat?(:UP) ? 1 : -1)) % 10
      Sound.play_cursor
      refresh
    elsif Input.trigger?(:C)
      Sound.play_ok
      self.visible = false
      @handlers[:ok].call(amount) if @handlers[:ok]
    elsif MGQ_MpUi.cancel?
      Sound.play_cancel
      self.visible = false
      @handlers[:cancel].call if @handlers[:cancel]
    end
  end

  # Draws the digits, the picked one marked, and the party's gold below.
  def refresh
    contents.clear
    left = (contents_width - DIGITS * DIGIT_WIDTH - 32) / 2
    @digits.each_with_index do |digit, place|
      x = left + place * DIGIT_WIDTH
      contents.fill_rect(x, line_height - 2, DIGIT_WIDTH - 2, 2, normal_color) if place == @place
      change_color(normal_color)
      draw_text(x, 0, DIGIT_WIDTH, line_height, digit.to_s, 1)
    end
    change_color(system_color)
    draw_text(left + DIGITS * DIGIT_WIDTH + 4, 0, 32, line_height, Vocab::currency_unit)
    # The game's own centered currency line names a variable it never sets, so it is drawn here.
    change_color(normal_color)
    draw_text(0, line_height, contents_width, line_height, "You have #{$game_party.gold} #{Vocab::currency_unit}", 1)
  end
end

# The trade screen.
class Scene_MpTrade < Scene_MenuBase
  # Builds the windows.
  def start
    super
    create_help_window
    half = Graphics.width / 2
    offer_height = @help_window.height + @help_window.fitting_height(6)
    @mine_window = Window_MpTradeOffer.new(0, @help_window.height, half, offer_height - @help_window.height, true)
    @theirs_window = Window_MpTradeOffer.new(half, @help_window.height, Graphics.width - half, offer_height - @help_window.height, false)
    @command_window = Window_MpTradeCommand.new(offer_height)
    bag_top = offer_height + @command_window.height
    @bag_window = Window_MpTradeBag.new(bag_top, Graphics.height - bag_top)
    @gold_window = Window_MpTradeGold.new
    @gold_window.on(method(:on_gold_ok), method(:on_gold_cancel))
    MGQ_MpTradeUi::CATEGORIES.each { |symbol, _| @command_window.set_handler(symbol, method(:on_category)) }
    @command_window.set_handler(:gold, method(:on_gold))
    @command_window.set_handler(:offers, method(:on_offers))
    [@mine_window, @theirs_window].each do |window|
      window.set_handler(:switch, method(:on_switch_offer))
      window.set_handler(:cancel, method(:on_offers_cancel))
    end
    @command_window.set_handler(:confirm, method(:on_confirm))
    @command_window.set_handler(:cancel_trade, method(:on_cancel_trade))
    @command_window.set_handler(:cancel, method(:on_cancel_trade))
    @bag_window.set_handler(:cancel, method(:on_bag_cancel))
    @status = nil
    session = MGQ_MpTrade.session
    MGQ_MpTrade.log("trade screen opened#{session ? " for trade #{MGQ_MpTrade.short(session.id)} with #{session.name}" : ', but there is no trade'}")
  rescue => e
    MGQ_MpTrade.log("opening the trade screen failed: #{MGQ_MpLog.failure(e)} at #{Array(e.backtrace).first}")
    MGQ_MpTrade.cancel
    return_scene
  end

  # Closes the screen once the trade ended, and keeps the status line current.
  def update
    super
    session = MGQ_MpTrade.session
    unless session
      MGQ_MpTrade.log("trade screen closed, the trade ended")
      return return_scene
    end

    leave_bag if session.stage != :open && @bag_window.active
    status = MGQ_MpTradeUi.status_line(session)
    return if status == @status

    @status = status
    @help_window.set_text("Trading with #{session.name}\n#{status}")
  rescue => e
    MGQ_MpTrade.log("trade screen failed: #{MGQ_MpLog.failure(e)} at #{Array(e.backtrace).first}")
    MGQ_MpTrade.cancel
    return_scene
  end

  # Moves the cursor into the other player's offer, to look through it.
  def on_offers
    show_offer(@theirs_window)
  end

  # Moves the cursor to the other side's offer.
  def on_switch_offer
    show_offer(@theirs_window.active ? @mine_window : @theirs_window)
  end

  # Moves the cursor into one side's offer, at its first item.
  #
  # @param window [Window_MpTradeOffer] The side.
  def show_offer(window)
    [@mine_window, @theirs_window].each do |side|
      side.deactivate
      side.unselect
    end
    window.activate
    window.select([2, window.item_max - 1].min)
  end

  # Hands the input back to the commands.
  def on_offers_cancel
    [@mine_window, @theirs_window].each do |side|
      side.deactivate
      side.unselect
    end
    @command_window.activate
  end

  # Shows a category of the bag.
  def on_category
    @bag_window.category = @command_window.current_symbol
    @bag_window.activate
    @bag_window.select(0) if @bag_window.index < 0
  end

  # Hands the input back to the commands.
  def on_bag_cancel
    leave_bag
  end

  # Leaves the bag for the commands.
  def leave_bag
    @bag_window.deactivate
    @bag_window.unselect
    @command_window.activate
  end

  # Opens the gold's digits.
  def on_gold
    @command_window.deactivate
    @gold_window.start(MGQ_MpTrade.session ? MGQ_MpTrade.session.mine.gold : 0)
  end

  # Takes the gold typed, at most the party's.
  #
  # @param gold [Integer] The gold.
  def on_gold_ok(gold)
    MGQ_MpTrade.log("typed #{gold} gold to offer")
    MGQ_MpTrade.set_gold(gold)
    @command_window.activate
  end

  # Leaves the gold as it was.
  def on_gold_cancel
    @command_window.activate
  end

  # Confirms both offers, or takes the confirmation back.
  def on_confirm
    MGQ_MpTrade.toggle_confirm
    @command_window.activate
  end

  # Cancels the trade.
  def on_cancel_trade
    MGQ_MpTrade.cancel
    @command_window.activate
  end
end
