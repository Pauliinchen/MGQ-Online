#----------------------------------------------------------------
#  trade.rbx
#
#  Changelog:
#      Paulinchen  2026-11-11: Emptied the sockets of a copy given away, so its gems no longer come back into the bag
#                            - Took why the player is busy from the reason duels and joins share, which a teleport due counts in
#      Paulinchen  2026-11-09: Counted room only for the copies the game caps, so an offer of plain items no longer crashes
#      Paulinchen  2026-11-08: Read standing near from the DLL
#      Paulinchen  2026-11-06: Asked the rules in C# which items may be traded, how many of one an offer holds and whether the game can take an offer
#      Paulinchen  2026-11-05: Handed the DLL the offers and items as values and took them back so, the DLL writing and reading the offers and the items' tokens
#                            - Told whether the player invites to a trade as true or false
#                            - Handed the players a trade invite names to the DLL as a list, which it writes into the state
#      Paulinchen  2026-10-31: Worded what the player reads plainly, leaving causes and internals to the log
#      Paulinchen  2026-10-30: Let the DLL ask the relay for the trades to recover, by the save loaded
#                            - Told the relay of a trade the save holds through the DLL
#                            - Kept the trade's handshake, session and commit in the DLL, the items, the save and the screen here
#      Paulinchen  2026-10-23: Made up a trade's id through coop.rbx
#                            - Named the one log of the day where a trade not applied in full tells why
#      Paulinchen  2026-10-12: Sent the offer and confirmation again on the relay's beat after a failed send
#                            - Sent the offer and confirmation again once the other player is back
#                            - Answered a message of a trade the game no longer has with a cancel
#                            - Refused to confirm offers too long for the relay
#                            - Recovered trades only once the player is free on the map
#      Paulinchen  2026-10-11: Drew the trade offer in the color every request and offer shares
#                            - Named the wait for an accepted trade in the own line, with seconds left
#                            - Stopped the player's own trade offer once they accept another player's
#      Paulinchen  2026-10-08: Told the player only that a trade with an id that is not valid could not open
#                            - Showed an accepted trade offer again once its player turned the accept down
#                            - Declined a trade with an id that is not valid with the reason invalid
#      Paulinchen  2026-10-07: Told the player when a trade they accepted could not open
#                            - Let a world's latest autosave load again
#                            - Logged where opening the screen failed and the pictures in memory
#                            - Kept the trades a save holds through MGQ_MpGame
#                            - Forgot a new game's trade save slot through a before block
#                            - Named players in the log through MGQ_MpOverworldSync.who
#                            - Named the DLL's exports alone
#                            - Logged every step of a trade
#                            - Kept the messages about the trade for the trade screen
#      Paulinchen  2026-10-06: Told the relay a trade is done only once a save holds it
#                            - Noted a trade as applied before applying it
#                            - Bumped the own offer's revision when a commit reopens
#                            - Ended the trade once the other player cancels it while the relay decides
#                            - Closed the trade once a cancel pressed while the relay decides went through
#                            - Asked the relay again for trades to recover after a failed fetch
#                            - Offered no trades in a world made before the world list
#                            - Let the room checks count what the player gives away in the same trade
#                            - Wrote an enchanted copy's prefix as its enchantment and list place
#                            - Dropped the unused reason "left"
#                            - Named the world by its directory id to the relay
#                            - Found a plain item through MGQ_MpGame.item
#                            - Created
#
#----------------------------------------------------------------

# Trading between two players on the same map: items, equipment, enchant stones and gold, but no
# key items. A player offers a trade like a party invite: the players nearby, or one player on the
# map picked in the World overview. Once the other accepts, both games open the trade screen
# (ui_trade.rbx), where each player puts together an offer and confirms both offers.
#
# The DLL keeps the trade itself (MGQOnline.Game's TradeMachine): the handshake, both offers as
# text, their revisions and confirmations, and the relay's commit. This script keeps the items, the
# bag, the save and the screen, reads the trade through the view the DLL posts, and applies a
# trade the relay committed. It must never interrupt the game, so its per-frame work rescues.
module MGQ_MpTrade
  # Color of the trade line above a ghost's name and of the trade's notices, the one every request
  # and offer shares.
  TRADE_COLOR = MGQ_MpActions::LINE_COLOR

  # Frames a message about the trade stays on the trade screen, four seconds.
  NOTE_FRAMES = 240

  # Trades the save remembers as applied, so a recovered trade is applied once.
  KEPT_TRADES = 50

  # What the scripts hand the DLL as the reason the player is busy while the map is not free.
  MAP_NOT_FREE = "the map is not free"

  # The bridge topics of the trade, see the DLL's TradeTopics.
  TICK_TOPIC = "trade.tick"
  ACCEPT_TOPIC = "trade.accept"
  DECLINE_TOPIC = "trade.decline"
  OFFER_TOPIC = "trade.offer"
  CONFIRM_TOPIC = "trade.confirm"
  CANCEL_TOPIC = "trade.cancel"
  DONE_TOPIC = "trade.done"
  TOKEN_TOPIC = "trade.token"
  TRADEABLE_TOPIC = "trade.tradeable"
  AMOUNT_TOPIC = "trade.amount"
  REFUSAL_TOPIC = "trade.refusal"

  # The bridge events of the trade, see the DLL's TradeTopics.
  VIEW_EVENT = "trade.view"
  OPEN_SCREEN_EVENT = "trade.open_screen"
  THEIR_OFFER_EVENT = "trade.their_offer"
  NOTE_EVENT = "trade.note"
  CLOSED_EVENT = "trade.closed"
  STOP_OFFERING_EVENT = "trade.stop_offering"
  DECLINED_EVENT = "trade.declined"
  APPLY_EVENT = "trade.apply"
  RECOVER_EVENT = "trade.recover"

  # One player's side of a trade: gold, and items with their amounts.
  #
  # @!attribute gold [Integer] The gold.
  # @!attribute entries [Array<Entry>] The items, in the order they were added.
  Offer = Struct.new(:gold, :entries) do
    # Reports whether the offer holds nothing.
    #
    # @return [Boolean] Whether it does.
    def empty?
      gold.to_i <= 0 && entries.empty?
    end

    # Finds the entry of an item.
    #
    # @param token [String] The item's token, see Items.token.
    # @return [Entry, nil] The entry, nil when the offer has none.
    def entry(token)
      entries.find { |entry| entry.token == token }
    end
  end

  # An item of an offer.
  #
  # @!attribute token [String] The item's name in both games, which the DLL writes, see Items.token.
  # @!attribute item [RPG::BaseItem, nil] This game's item, nil when its data lacks it.
  # @!attribute amount [Integer] How many, one for an enchanted or socketed copy.
  # @!attribute plain [Hash, nil] The values the item was made of, see Items.item_from; nil for an
  #   item of the player's own bag.
  Entry = Struct.new(:token, :item, :amount, :plain)

  # A trade between the player and one other player, as the DLL's view tells it, with both offers
  # as this game's items.
  #
  # @!attribute id [String] The trade's id, 24 hexadecimal characters, made by the player who offered it.
  # @!attribute partner [String] The other player's id.
  # @!attribute name [String] The other player's name.
  # @!attribute mine [Offer] The player's offer.
  # @!attribute theirs [Offer] The other player's offer, as they sent it.
  # @!attribute my_rev [Integer] How often the player changed their offer.
  # @!attribute their_rev [Integer] How often the other player changed theirs.
  # @!attribute confirmed [Boolean] Whether the player confirmed both offers as they stand.
  # @!attribute their_confirmed [Boolean] Whether the other player confirmed both offers as they stand.
  # @!attribute stage [Symbol] :open while both put the offers together, :committing while the
  #   relay decides.
  # @!attribute relay_id [String, nil] The id the relay knows the confirmed offers by.
  # @!attribute leaving [String, nil] The notice the trade closes with once the relay cancelled the
  #   commit, set when a player cancelled while the relay decided; nil while nobody did.
  # @!attribute unsent [Integer, nil] Failed tries to send the player's offer and confirmation state
  #   again since a message to the other player could not go out; nil while every message went out.
  # @!attribute refusal [String, nil] Why the player cannot confirm as far as the trade goes, the
  #   bag aside; nil while they can.
  Session = Struct.new(:id, :partner, :name, :mine, :theirs, :my_rev, :their_rev, :confirmed,
                       :their_confirmed, :stage, :relay_id, :leaving, :unsent, :refusal) do
    # Reports whether the other player confirmed the offers as they stand now.
    #
    # @return [Boolean] Whether they did.
    def their_confirmed?
      their_confirmed ? true : false
    end

    # Reports whether both players confirmed the offers as they stand now.
    #
    # @return [Boolean] Whether they did.
    def agreed?
      confirmed && their_confirmed?
    end
  end

  # The player's trade offer to the players nearby or named.
  @invite = MGQ_MpCoop::Invite.new

  # Another player's trade the player accepted, as the DLL's view tells it: "id", "name" and
  # "ends", the bridge frame the wait runs out at; nil while none.
  @accepted = nil

  # The trade the player takes part in, see session.
  @session = nil

  # Whether the map opens the trade screen on its next update.
  @open_screen = false

  # The message about the trade and its frames left, see note.
  @note = nil

  # What the DLL was handed last, see tell_frame.
  @told = nil

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "trade"

  # Reports whether the mod's DLL is installed and up to date, which trades need.
  #
  # @return [Boolean] Whether it is.
  def self.dll_ready?
    MGQ_Multiplayer.available? && !MGQ_Multiplayer.outdated?
  end

  # Reports whether trades can run: the mod's DLL is ready, and a world is open that the relay
  # knows by its directory id.
  #
  # @return [Boolean] Whether they can.
  def self.available?
    dll_ready? && !world_id.empty?
  end

  # The trade the player takes part in.
  #
  # @return [Session, nil] The trade, nil while there is none.
  def self.session
    @session
  end

  # Reports whether the player offers a trade now.
  #
  # @return [Boolean] Whether they do.
  def self.inviting?
    @invite.inviting?
  end

  # The ids of the players the offer names, besides those nearby.
  #
  # @return [Array<String>] The ids.
  def self.targets
    @invite.targets
  end

  # Reports whether another player stands on the player's map.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  # @return [Boolean] Whether they do.
  def self.same_map?(peer)
    !peer.away && peer.state["map"].to_i == $game_map.map_id
  end

  # Reports whether another player's trade offer reaches the player: on the same map, standing
  # near or naming the player.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  # @param anywhere [Boolean] Whether an offer naming the player counts wherever on the map they stand.
  # @return [Boolean] Whether it does.
  def self.offered_by?(peer, anywhere = true)
    same_map?(peer) && MGQ_MpCoop::Invite.reaches_me?(peer, "trading", "trading_to", anywhere)
  end

  # Reports whether the player may open a trade: free on the map, with no other trade and nothing
  # of MGQ_MpCoop.busy_reason holding them.
  #
  # @return [Boolean] Whether they may.
  def self.free?
    busy_reason.nil?
  end

  # Tells why the player may not open a trade now, see free?.
  #
  # @return [String, nil] The reason, nil while they may.
  def self.busy_reason
    return MAP_NOT_FREE unless MGQ_MpOverworldSync.map_free?
    return "already in trade #{short(@session.id)}" if @session

    MGQ_MpCoop.busy_reason
  end

  # Shortens a trade's id for the log, enough to tell trades apart.
  #
  # @param id [String, nil] The trade's id, or its id at the relay.
  # @return [String] Its first eight characters.
  def self.short(id)
    id.to_s[0, 8]
  end

  # Names another player for the log by their id.
  #
  # @param id [String] The player's id.
  # @return [String] Their name, or their shortened id while they are not in the world.
  def self.name_of(id)
    peer = MGQ_MpOverworldSync::Peers.all.find { |each| each.state["id"].to_s == id.to_s }
    peer ? peer.state["name"].to_s : "player #{id.to_s[0, 8]}"
  rescue
    "player #{id.to_s[0, 8]}"
  end

  # Offers a trade to the players nearby, and to a player anywhere on the map when named.
  #
  # @param target_id [String, nil] The id of a player the offer reaches wherever on the map they stand.
  def self.invite(target_id = nil)
    @invite.invite(target_id)
    log("offering a trade to #{target_id ? name_of(target_id) + ' and ' : ''}the players nearby")
  end

  # Stops offering a trade.
  def self.stop
    log("stopped offering a trade") if inviting?
    @invite.stop
  end

  # Forgets every offer and trade, as when the world closes; the DLL forgets its side as the world
  # closes, and a trade the relay is deciding is recovered the next time the world opens.
  def self.reset
    stop
    @accepted = nil
    @session = nil
    @open_screen = false
    @note = nil
    @told = nil
    Saving.slot = nil
    Recovery.reset
  end

  # Tells a message about the trade on the trade screen, which the notices on the map do not
  # reach, for NOTE_FRAMES.
  #
  # @param text [String] The message.
  def self.note=(text)
    @note = [text, NOTE_FRAMES]
  end

  # The message about the trade the trade screen shows now.
  #
  # @return [String, nil] The message, nil once it ran out.
  def self.note
    @note && @note[0]
  end

  # The fields the trade adds to the state the player's game tells the others. They are not named
  # "trade", which marks the messages of a trade.
  #
  # @return [Hash] The fields.
  def self.state_fields
    { "trading" => inviting? ? true : false, "trading_to" => targets }
  end

  # Tells what the line above a ghost's name says: their trade offer, when it reaches the player.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The ghost's player.
  # @return [Array, nil] The text and its color, nil for none.
  def self.label_line(peer)
    offered_by?(peer) ? ["Wants to trade (#{MGQ_MpHotkeys.label(:wheel)})", TRADE_COLOR] : nil
  end

  # Names what the player is doing for the line above their own head, with the moment it lapses:
  # waiting for an accepted trade to open, or offering one.
  #
  # @return [Array, nil] The doing and when it lapses, nil while nothing waits.
  def self.own_doing
    if @accepted
      left = @accepted["ends"].to_i - MGQ_Multiplayer::Bridge.frame_number
      return ["Waiting for #{@accepted['name']}'s trade", MGQ_MpActions.lapse_in(left)]
    end
    return ["Offering a trade", MGQ_MpActions.lapse_in(@invite.frames_left)] if inviting?

    nil
  end

  # Lets the offer and the trade screen's message run out and hands the DLL what it needs of the
  # player. Called every frame in every scene.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    return reset unless in_world

    log("the trade offer ran out") if @invite.count_down
    @note = nil if @note && (@note[1] -= 1) <= 0
    tell_frame
  end

  # Hands the DLL, once it changed, why the player is busy (see MGQ_MpCoop.busy_reason), the
  # player's own offer and the world's id, which the DLL decides on as the other player's messages
  # come, and whether the map is the scene and which save is loaded, by which it asks the relay for
  # the trades to recover.
  def self.tell_frame
    return unless dll_ready?

    busy = MGQ_MpOverworldSync.map_free? ? MGQ_MpCoop.busy_reason : MAP_NOT_FREE
    frame = { "busy" => busy, "inviting" => inviting?, "targets" => targets.dup, "world" => world_id,
              "on_map" => SceneManager.scene.is_a?(Scene_Map), "save" => Recovery.save_key }
    return if frame == @told

    @told = frame
    MGQ_Multiplayer::Bridge.stage(TICK_TOPIC, frame)
  end

  # Takes the trade's view, which the DLL posts whenever it changed and answers after every action.
  #
  # @param view [Hash] "session" (nil for none) and "accepted" (nil for none), see the DLL's TradeTopics.
  def self.take_view(view)
    return unless view.is_a?(Hash)

    @accepted = view["accepted"]
    state = view["session"]
    return @session = nil unless state

    session = @session
    session = begin_session(state) unless session && session.id == state["id"]
    before = [session.my_rev, session.stage]
    session.my_rev = state["my_rev"].to_i
    session.their_rev = state["their_rev"].to_i
    session.confirmed = state["confirmed"] ? true : false
    session.their_confirmed = state["their_confirmed"] ? true : false
    session.stage = state["stage"] == "committing" ? :committing : :open
    session.relay_id = state["relay_id"]
    session.leaving = state["leaving"]
    session.unsent = state["unsent"]
    session.refusal = state["refusal"]
    log_view_changes(session, before[0], before[1])
  end

  # Logs what changed of the player's side of the trade, with the items as this game names them.
  #
  # @param session [Session] The trade.
  # @param rev [Integer] The player's offer's revision before.
  # @param stage [Symbol] The stage before.
  def self.log_view_changes(session, rev, stage)
    log("my offer r#{session.my_rev}: #{Items.summary(session.mine)}; both confirmations taken back") if session.my_rev > rev.to_i
    return unless session.stage == :committing && stage != :committing

    log("both confirmed, trade #{short(session.id)} (my r#{session.my_rev}, their r#{session.their_rev}) sent to the relay: I give #{Items.summary(session.mine)}; I get #{Items.summary(session.theirs)}")
  end

  # Starts a trade with empty offers.
  #
  # @param state [Hash] "id", "partner" and "name".
  # @return [Session] The trade.
  def self.begin_session(state)
    Items.forget_tokens
    @session = Session.new(state["id"].to_s, state["partner"].to_s, state["name"].to_s, Offer.new(0, []), Offer.new(0, []),
                           0, 0, false, false, :open, nil, nil, nil, nil)
  end

  # Starts the trade the DLL opened and has the map open its screen.
  #
  # @param state [Hash] "id", "partner" and "name".
  def self.open_screen(state)
    begin_session(state)
    @open_screen = true
  end

  # Takes the other player's offer as it stands now.
  #
  # @param event [Hash] "rev" and "offer", see Items.read_offer.
  def self.take_their_offer(event)
    session = @session
    return unless session

    session.their_rev = event["rev"].to_i
    session.theirs = Items.read_offer(event["offer"])
    log("#{session.name}'s offer r#{session.their_rev}: #{Items.summary(session.theirs)}; both confirmations taken back")
  end

  # Forgets the trade that ended and closes its screen.
  def self.closed
    @session = nil
    @open_screen = false
    @note = nil
  end

  # Follows another player who could not trade: the offer they accepted no longer waits in the
  # notification box, and one who declined is no longer named by the player's offer.
  #
  # @param event [Hash] "seat", "id", "reason" and "accepted".
  def self.declined(event)
    # ui_notices.rbx loads after this script.
    MGQ_MpNotices.release([:trade, event["seat"]]) if event["accepted"] && defined?(MGQ_MpNotices)
    @invite.drop(event["id"]) if event["reason"] == "no"
  end

  # Accepts another player's trade offer: tells them, and waits for their game to open the trade. An
  # offer of the player's own stops, since they cannot take two trades.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player who offered it.
  def self.accept(peer)
    busy = busy_reason
    if busy
      log("not accepting #{peer.state['name']}'s trade: #{busy}")
      return MGQ_MpOverworldSync.notice("Finish what you are doing first.")
    end

    if inviting?
      log("stopped offering a trade: accepted #{peer.state['name']}'s")
      @invite.stop
    end
    take_view(MGQ_Multiplayer::Bridge.call(ACCEPT_TOPIC, peer.seat))
  end

  # Turns another player's trade offer down, telling them why.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  # @param reason [String] Why, such as "no".
  # @return [nil] Nothing.
  def self.decline(peer, reason)
    take_view(MGQ_Multiplayer::Bridge.call(DECLINE_TOPIC, { "seat" => peer.seat, "reason" => reason }))
    nil
  end

  # Changes how many of an item the player offers, as many as the rules in C# let an offer hold
  # (topic trade.amount).
  #
  # @param item [RPG::BaseItem] The item.
  # @param amount [Integer] How many, 0 to take it out of the offer.
  # @return [String, nil] Why the offer holds fewer than wanted, nil when it holds as many.
  def self.set_amount(item, amount)
    session = @session
    return unless session && session.stage == :open
    return log("not offering #{Items.label(item)}: it may not be traded") unless Items.tradeable?(item)

    token = Items.token(item)
    answer = Items.amount(item, amount)
    log("offering #{answer['amount']}, not #{amount}, of #{Items.label(item)}: #{answer['why']}") if answer["why"]
    change_amount(session, item, token, answer["amount"])
    answer["why"]
  end

  # Puts an amount of an item into the player's offer.
  #
  # @param session [Session] The trade.
  # @param item [RPG::BaseItem] The item.
  # @param token [String] The item's token.
  # @param amount [Integer] How many, 0 to take it out of the offer.
  def self.change_amount(session, item, token, amount)
    entry = session.mine.entry(token)
    return if (entry ? entry.amount : 0) == amount

    if amount == 0
      session.mine.entries.delete(entry)
    elsif entry
      entry.amount = amount
    else
      session.mine.entries << Entry.new(token, item, amount)
    end
    offer_changed(session)
  end

  # Changes the gold the player offers.
  #
  # @param gold [Integer] The gold, at most what the party has.
  def self.set_gold(gold)
    session = @session
    return unless session && session.stage == :open

    wanted = gold.to_i
    gold = [[gold.to_i, 0].max, $game_party.gold].min
    log("offering #{gold} gold, not #{wanted}: the party has #{$game_party.gold}") if gold != wanted
    return if session.mine.gold == gold

    session.mine.gold = gold
    offer_changed(session)
  end

  # Hands the DLL the player's new offer, which takes back both confirmations and tells the other
  # player.
  #
  # @param session [Session] The trade.
  def self.offer_changed(session)
    take_view(MGQ_Multiplayer::Bridge.call(OFFER_TOPIC, Items.plain_offer(session.mine)))
  end

  # Tells why the player cannot confirm now.
  #
  # @return [String, nil] The reason, nil while they can.
  def self.confirm_refusal
    session = @session
    return "There is no trade." unless session

    session.refusal || Items.receive_refusal(session.theirs, session.name, session.mine)
  end

  # Confirms both offers as they stand, or takes the confirmation back. The trade goes to the relay
  # once both players confirmed the same offers.
  def self.toggle_confirm
    session = @session
    return unless session && session.stage == :open

    refusal = session.confirmed ? nil : Items.receive_refusal(session.theirs, session.name, session.mine)
    take_view(MGQ_Multiplayer::Bridge.call(CONFIRM_TOPIC, refusal))
  end

  # Cancels the trade: at once while it is open, through the relay while it decides, which still
  # completes a trade both games committed already.
  def self.cancel
    return unless @session

    take_view(MGQ_Multiplayer::Bridge.call(CANCEL_TOPIC))
  end

  # The open world's id in the directory, by which the relay knows the world's players. The world's
  # folder id is another, which the relay never sees.
  #
  # @return [String] The id, "" while none is open or for a world made before the directory.
  def self.world_id
    MGQ_MpOverworldSync.in_world? ? MGQ_MpWorld.world.directory_id.to_s : ""
  end

  # Tells the relay, through the DLL, that the save holds a trade the player's game applied.
  #
  # @param id [String] The trade's id at the relay.
  def self.done(id)
    MGQ_Multiplayer::Bridge.call(DONE_TOPIC, id)
  end

  # Completes a trade the relay committed: applies it once, saves, and tells the relay once the
  # save holds it.
  #
  # @param event [Hash] "id" (the trade's id at the relay), "name", "mine" and "theirs", see
  #   Items.read_offer.
  def self.complete(event)
    id = event["id"].to_s
    name = event["name"].to_s
    session = @session
    # The trade's own offers keep the items this game picked, so a copy given is the one offered.
    mine = Items.read_offer(event["mine"])
    theirs = Items.read_offer(event["theirs"])
    mine = session.mine if session && Items.key(session.mine) == Items.key(mine)
    theirs = session.theirs if session && Items.key(session.theirs) == Items.key(theirs)
    closed
    text = if !Recovery.apply_once(id, mine, theirs)
             "The trade with #{name} did not complete in full."
           elsif Recovery.finish
             "Trade with #{name} complete, game saved."
           else
             "Trade with #{name} complete. Save your game."
           end
    log("trade #{short(id)} closed: #{text}")
    MGQ_MpOverworldSync.notice(text)
  end

  # Applies the trades waiting to be recovered, and opens the trade screen from the map once a
  # trade began. Called by the map every frame.
  def self.on_map
    Recovery.apply_waiting
    return unless @open_screen && @session

    @open_screen = false
    SceneManager.call(Scene_MpTrade)
  rescue => e
    log("opening the trade screen failed: #{MGQ_MpLog.failure(e)} at #{Array(e.backtrace).first}")
  end

  # The items of a trade: which may be traded, how they are written as text and read back, and
  # moving them.
  module Items
    # Reports whether an item is an enchanted or socketed copy, which only one game has.
    #
    # @param item [RPG::BaseItem] The item.
    # @return [Boolean] Whether it is.
    def self.unique?(item)
      item.respond_to?(:uniq_item?) && item.uniq_item?
    end

    # Reports whether an item is an enchant stone.
    #
    # @param item [RPG::BaseItem] The item.
    # @return [Boolean] Whether it is.
    def self.stone?(item)
      item.is_a?(RPG::Item) && item.respond_to?(:enchant_stone?) && item.enchant_stone?
    end

    # Reads what the rules in C# ask of an item: [kind, key, stone, unique].
    #
    # @param item [RPG::BaseItem, nil] The item, nil for one the game does not know.
    # @return [Array, nil] The facts, nil for no item.
    def self.facts(item)
      return nil unless item

      kind = { RPG::Item => "item", RPG::Weapon => "weapon", RPG::Armor => "armor" }.find { |klass, _name| item.is_a?(klass) }
      [kind ? kind[1] : nil, item.is_a?(RPG::Item) && item.key_item? ? true : false, stone?(item) ? true : false, unique?(item) ? true : false]
    end

    # Reports whether an item may be traded, as the rules in C# tell (topic trade.tradeable).
    #
    # @param item [RPG::BaseItem, nil] The item.
    # @return [Boolean] Whether it may.
    def self.tradeable?(item)
      item ? MGQ_Multiplayer::Bridge.call!(MGQ_MpTrade::TRADEABLE_TOPIC, [facts(item)]).first : false
    end

    # Works out how many of an item an offer holds when the player wants a number of them, as the
    # rules in C# tell (topic trade.amount).
    #
    # @param item [RPG::BaseItem] The item.
    # @param wanted [Integer] How many the player wants to offer.
    # @return [Hash] "amount", and "why" not as many as wanted, nil when as many.
    def self.amount(item, wanted)
      MGQ_Multiplayer::Bridge.call!(MGQ_MpTrade::AMOUNT_TOPIC, "wanted" => wanted, "held" => held(item), "unique" => unique?(item) ? true : false)
    end

    # Counts the item in the party's bag, not what is equipped or in the storehouse.
    #
    # @param item [RPG::BaseItem] The item.
    # @return [Integer] How many.
    def self.held(item)
      $game_party.item_number(item)
    end

    # The tradeable items of the party's bag.
    #
    # @return [Array<RPG::BaseItem>] The items, weapons and armors held.
    def self.bag
      items = ($game_party.items + $game_party.weapons + $game_party.armors).select { |item| held(item) > 0 }
      may = items.empty? ? [] : MGQ_Multiplayer::Bridge.call!(MGQ_MpTrade::TRADEABLE_TOPIC, items.map { |item| facts(item) })
      items.select.with_index { |_item, index| may[index] }
    end

    # The lists of an enchantment a rolled name prefix comes from, by the letter that names them.
    PREFIX_LISTS = { "r" => :rare_prefix, "p" => :prefix }

    # Names an item as offers name it, the same in both games, which the DLL writes (TradeItems in
    # MGQOnline.Game), once per item of a trade.
    #
    # @param item [RPG::BaseItem] The item.
    # @return [String] The token.
    def self.token(item)
      @tokens = {}.compare_by_identity unless @tokens
      @tokens[item] ||= MGQ_Multiplayer::Bridge.call(MGQ_MpTrade::TOKEN_TOPIC, plain(item)).to_s
    end

    # Forgets the items' tokens, as a trade begins.
    def self.forget_tokens
      @tokens = nil
    end

    # Turns an item into what the DLL names it by: an item of the database by its kind and id, an
    # enchanted or socketed copy by its facts (MGQ_MpActors::Items) and where its name prefix comes
    # from (prefix_ref).
    #
    # @param item [RPG::BaseItem] The item.
    # @return [Hash] The values.
    def self.plain(item)
      return { "copy" => MGQ_MpActors.plain(MGQ_MpActors::Items.facts(item)), "prefix" => prefix_ref(item) } if unique?(item)

      { (item.is_a?(RPG::Item) ? "item" : item.is_a?(RPG::Weapon) ? "weapon" : "armor") => item.id }
    end

    # Names an item of the database by its kind and id: i, w or a and the id.
    #
    # @param item [RPG::BaseItem] The item.
    # @return [String] The name.
    def self.ref(item)
      "#{item.is_a?(RPG::Item) ? 'i' : item.is_a?(RPG::Weapon) ? 'w' : 'a'}#{item.id}"
    end

    # Names an item for the log: enchanted for a copy, its kind and id, and its name from the data.
    #
    # @param item [RPG::BaseItem, nil] The item.
    # @return [String] The name.
    def self.label(item)
      return "nothing" unless item

      "#{unique?(item) ? 'enchanted ' : ''}#{ref(item)} #{item.name}"
    rescue
      "an item"
    end

    # Summarizes an offer for the log: its gold and each item with its amount.
    #
    # @param offer [Offer] The offer.
    # @return [String] The summary.
    def self.summary(offer)
      items = offer.entries.map { |entry| "#{entry.item ? label(entry.item) : "#{entry.token[0, 12]} (unknown here)"} x#{entry.amount}" }
      (["#{offer.gold.to_i} gold"] + items).join(", ")
    rescue => e
      "an offer that could not be summarized (#{e.class})"
    end

    # Names the name prefix an enchanted copy rolled by where it comes from: the enchantment's id, r
    # or p for its rare or plain prefixes, and the prefix's place in that list. The receiver reads
    # the prefix from its own data, in its own language.
    #
    # @param item [RPG::BaseItem] The copy.
    # @return [Array(Integer, String, Integer), nil] The enchantment, the list's letter and the place;
    #   nil for no prefix or one no enchantment of the copy lists.
    def self.prefix_ref(item)
      prefix = item.respond_to?(:enchant_item?) && item.enchant_item? ? MGQ_MpGame.get(item, :prefix).to_s : ""
      return nil if prefix.empty?

      Array(MGQ_MpGame.get(item, :enchants)).each do |id|
        enchant = $data_classes[id.to_i]
        PREFIX_LISTS.each do |letter, list|
          place = enchant.respond_to?(list) ? Array(enchant.send(list)).index(prefix) : nil
          return [id.to_i, letter, place] if place
        end
      end
      nil
    end

    # Reads a name prefix from this game's data, see prefix_ref.
    #
    # @param ref [Array, nil] Where the prefix comes from, as the DLL read it.
    # @return [String] The prefix, "" for none or one this game's data lacks.
    def self.prefix_from(ref)
      id, letter, place = ref
      enchant = ref && $data_classes[id.to_i]
      list = ref && PREFIX_LISTS[letter]
      return "" unless enchant && list && enchant.respond_to?(list)

      Array(enchant.send(list))[place.to_i].to_s
    end

    # Makes an item from the values the DLL read: the database's item, or a new copy of an
    # enchanted or socketed one.
    #
    # @param plain [Hash, nil] The values, see plain; nil for an item the DLL could not read.
    # @return [RPG::BaseItem, nil] The item, nil when this game's data lacks it.
    def self.item_from(plain)
      return nil unless plain.is_a?(Hash)

      if plain.key?("copy")
        item = MGQ_MpActors::Items.make(plain["copy"])
        return nil unless item && unique?(item)

        MGQ_MpGame.set(item, :prefix, prefix_from(plain["prefix"])) if item.enchant_item?
        return item
      end

      kind, id = plain.first
      MGQ_MpGame.item({ "item" => "i", "weapon" => "w", "armor" => "a" }[kind], id.to_i)
    end

    # Turns an offer into what the DLL writes: its gold, and each item's token and amount.
    #
    # @param offer [Offer] The offer.
    # @return [Hash] "gold" and "items".
    def self.plain_offer(offer)
      { "gold" => offer.gold.to_i, "items" => key(offer)[1] }
    end

    # Names an offer by its gold and each item's token and amount, the same for the same offer in
    # both games.
    #
    # @param offer [Offer] The offer.
    # @return [Array] The gold and the [token, amount] pairs.
    def self.key(offer)
      [offer.gold.to_i, offer.entries.map { |entry| [entry.token, entry.amount] }]
    end

    # Makes an offer of the values the DLL read, keeping the items this game's data lacks without
    # their item.
    #
    # @param read [Hash, nil] "gold" and "items", each [token, item values, amount].
    # @return [Offer] The offer.
    def self.read_offer(read)
      read = {} unless read.is_a?(Hash)
      Offer.new(read["gold"].to_i, Array(read["items"]).map { |token, plain, amount| Entry.new(token.to_s, item_from(plain), amount.to_i, plain) })
    end

    # Tells why the player's game cannot take an offer, as the rules in C# tell (topic
    # trade.refusal), counting what the player gives away in the same trade, which leaves the bag
    # first.
    #
    # @param offer [Offer] The other player's offer.
    # @param name [String] The other player's name.
    # @param mine [Offer] The player's own offer.
    # @return [String, nil] The reason, nil while it can.
    def self.receive_refusal(offer, name, mine = Offer.new(0, []))
      entries = offer.entries.map do |entry|
        item = entry.item
        { "facts" => facts(item), "amount" => entry.amount, "held" => item ? held(item) : 0, "given" => given(mine, entry.token),
          "room" => item ? room_for_copies(item) : nil, "copies_given" => item ? copies_given(mine, item.class) : 0, "name" => item ? item.name.to_s : "" }
      end
      MGQ_Multiplayer::Bridge.call!(MGQ_MpTrade::REFUSAL_TOPIC, "name" => name.to_s, "gold" => $game_party.gold, "max_gold" => $game_party.max_gold,
                                                                "gold_given" => mine.gold.to_i, "gold_taken" => offer.gold.to_i, "entries" => entries)
    end

    # Counts how many of an item the player's offer gives away.
    #
    # @param mine [Offer] The player's offer.
    # @param token [String] The item's token.
    # @return [Integer] How many.
    def self.given(mine, token)
      entry = mine.entry(token)
      entry ? entry.amount : 0
    end

    # Counts the enchanted or socketed copies of a kind the player's offer gives away.
    #
    # @param mine [Offer] The player's offer.
    # @param kind [Class] The copies' class.
    # @return [Integer] How many.
    def self.copies_given(mine, kind)
      mine.entries.count { |entry| entry.item && unique?(entry.item) && entry.item.class == kind }
    end

    # Counts the copies of a kind the party can still take.
    #
    # The game caps only enchanted copies; it names no most for other kinds and fails to count the
    # copies of an item of the database.
    #
    # @param item [RPG::BaseItem] A copy of the kind.
    # @return [Integer, nil] How many, nil when the game keeps no count of copies.
    def self.room_for_copies(item)
      party = $game_party
      return nil unless party.respond_to?(:uniq_max_item_number) && party.respond_to?(:uniq_item_number)

      most = party.uniq_max_item_number(item)
      most.is_a?(Integer) ? most - party.uniq_item_number(item) : nil
    end

    # Moves the trade's items in the player's game: takes the player's offer out of the bag, as much
    # of it as is still there, and puts the other player's in. The party's story does not pass it on.
    #
    # @param mine [Offer] The player's offer.
    # @param theirs [Offer] The other player's offer.
    def self.apply(mine, theirs)
      give = lambda do
        before = $game_party.gold
        given = [mine.gold.to_i, before].min
        $game_party.lose_gold(given)
        mine.entries.each { |entry| take_out(entry) }
        $game_party.gain_gold(theirs.gold.to_i)
        short = given < mine.gold.to_i ? " (offered #{mine.gold.to_i}, the party held less)" : ""
        MGQ_MpTrade.log("gold #{before} -> #{$game_party.gold}: gave #{given}, got #{theirs.gold.to_i}#{short}")
        theirs.entries.each { |entry| put_in(entry) }
      end
      defined?(MGQ_MpCoopEvents) ? MGQ_MpCoopEvents.granting(&give) : give.call
    end

    # Takes an item of the player's offer out of the bag.
    #
    # @param entry [Entry] The item.
    def self.take_out(entry)
      if entry.item && unique?(entry.item)
        copy = bag.find { |item| unique?(item) && token(item) == entry.token }
        return MGQ_MpTrade.log("gave nothing for #{label(entry.item)}: the copy is no longer in the bag") unless copy

        # The game hands the gems of a copy leaving the bag back to the party, but the receiver's
        # copy already carries them.
        MGQ_MpGame.set(copy, :stones, [nil] * copy.socket_num.to_i)
        $game_party.lose_item(copy, 1)
        MGQ_MpTrade.log("gave #{label(copy)}")
      elsif entry.item
        before = held(entry.item)
        $game_party.lose_item(entry.item, [entry.amount, before].min)
        fewer = before < entry.amount ? " (offered #{entry.amount}, the bag held fewer)" : ""
        MGQ_MpTrade.log("gave #{label(entry.item)} x#{[entry.amount, before].min}: #{before} -> #{held(entry.item)}#{fewer}")
      else
        MGQ_MpTrade.log("gave nothing for #{entry.token[0, 12]}: this game's data lacks it")
      end
    end

    # Puts an item of the other player's offer into the bag: a fresh copy of an enchanted or
    # socketed one, which the party keeps as its own.
    #
    # @param entry [Entry] The item.
    def self.put_in(entry)
      item = entry.item && unique?(entry.item) ? item_from(entry.plain) || entry.item : entry.item
      return log_missing(entry) unless item

      before = unique?(item) ? 0 : held(item)
      $game_party.add_item_data(item, 0) if unique?(item)
      $game_party.gain_item(item, unique?(item) ? 1 : entry.amount)
      return MGQ_MpTrade.log("received #{label(item)} as a new copy") if unique?(item)

      MGQ_MpTrade.log("received #{label(item)} x#{entry.amount}: #{before} -> #{held(item)}")
    end

    # Logs an item the player's game could not make.
    #
    # @param entry [Entry] The item.
    def self.log_missing(entry)
      MGQ_MpTrade.log("received nothing for #{entry.token[0, 12]} x#{entry.amount}: this game's data lacks it")
    end
  end

  # The save after a trade: into the slot the player last saved or loaded in the world, or the
  # first free one.
  module Saving
    # Remembers the slot of a save loaded or written in a world.
    #
    # An autosave's index is its name, such as "01", which is no slot a trade saves into, so loading
    # one forgets the slot; treating the name as a slot would raise inside the game's load.
    #
    # @param index [Integer, String, nil] The slot, an autosave's name, or nil for a new game.
    def self.slot=(index)
      index = nil unless index.is_a?(Integer)
      if index != @slot
        MGQ_MpTrade.log(index ? "a trade saves into save file #{index + 1}, the one last loaded or saved in the world" : "forgot the save file a trade saves into")
      end
      @slot = index
    end

    # Saves the game.
    #
    # @return [Boolean] Whether it saved.
    def self.save
      index = @slot || (0...DataManager.savefile_max).find { |slot| !File.exist?(DataManager.make_filename(slot)) }
      unless index
        MGQ_MpTrade.log("not saving after the trade: no save file was loaded or saved in the world and none is free")
        return false
      end

      saved = DataManager.save_game(index)
      MGQ_MpTrade.log(saved ? "saved after the trade into save file #{index + 1}" : "saving after the trade into save file #{index + 1} failed")
      @slot = index if saved
      saved ? true : false
    rescue => e
      MGQ_MpTrade.log("saving after a trade failed: #{e.class}: #{e.message}")
      false
    end
  end

  # Trades the relay committed that the player's game has not applied: after a crash, a lost
  # connection, or a save loaded from before the trade. The DLL asks the relay once per save; its
  # answer waits until the player is free on the map; then each is noted in the save, applied once per save, and saved; the relay
  # hears that it is done only once a save holds it.
  module Recovery
    # Notes a trade in the save and applies it, unless the save has it, and keeps it unsaved until
    # the next save in the world.
    #
    # Noting it first keeps a failure partway from applying it a second time.
    #
    # @param id [String] The trade's id at the relay.
    # @param mine [Offer] The player's offer.
    # @param theirs [Offer] The other player's offer.
    # @return [Boolean] Whether the trade is applied in full.
    def self.apply_once(id, mine, theirs)
      unsaved << id unless unsaved.include?(id)
      if applied?(id)
        MGQ_MpTrade.log("trade #{MGQ_MpTrade.short(id)} is in this save already, not applied again")
        return true
      end

      remember(id)
      MGQ_MpTrade.log("applying trade #{MGQ_MpTrade.short(id)}: giving #{Items.summary(mine)}; getting #{Items.summary(theirs)}")
      Items.apply(mine, theirs)
      MGQ_MpTrade.log("applied trade #{MGQ_MpTrade.short(id)}, noted in the save, unsaved until the next save")
      true
    rescue => e
      MGQ_MpTrade.log("applying trade #{MGQ_MpTrade.short(id)} failed: #{e.class}: #{e.message}")
      false
    end

    # Saves after a trade, which tells the relay of every trade the save now holds.
    #
    # @return [Boolean] Whether it saved.
    def self.finish
      saved = Saving.save
      saved_game if saved
      saved
    end

    # Tells the relay of every trade applied since the last save that the save now holds. Called
    # after each save in a world.
    def self.saved_game
      held = unsaved.select { |id| applied?(id) }
      @unsaved = unsaved - held
      unless @unsaved.empty?
        MGQ_MpTrade.log("not done yet at the relay, this save lacks them: #{@unsaved.map { |id| MGQ_MpTrade.short(id) }.join(', ')}")
      end
      held.each do |id|
        MGQ_MpTrade.log("telling the relay trade #{MGQ_MpTrade.short(id)} is done, the save holds it")
        MGQ_MpTrade.done(id)
      end
    end

    # The trades applied but not saved yet.
    #
    # @return [Array<String>] Their ids at the relay.
    def self.unsaved
      @unsaved ||= []
    end

    # Reports whether the save applied a trade already.
    #
    # @param id [String] The trade's id at the relay.
    # @return [Boolean] Whether it did.
    def self.applied?(id)
      Array(MGQ_MpGame.get($game_system, :trades)).include?(id)
    end

    # Notes in the save that a trade was applied.
    #
    # @param id [String] The trade's id at the relay.
    def self.remember(id)
      trades = Array(MGQ_MpGame.get($game_system, :trades)) + [id]
      MGQ_MpGame.set($game_system, :trades, trades.last(KEPT_TRADES))
    end

    # Forgets the trades waiting and what is unsaved, as when the world closes; the relay keeps the
    # unsaved trades for the next time.
    def self.reset
      @recovered = nil
      @unsaved = []
    end

    # Keeps the trades the DLL found the relay committed for the save it asked for, for apply_waiting.
    #
    # @param event [Hash] "save", the save they were asked for, and "trades", each [id at the relay,
    #   the other player's id, the player's offer, the other's offer].
    def self.take(event)
      @recovered = [event["save"], Array(event["trades"])]
    end

    # Tells the loaded save apart from another, as the DLL asks the relay once per save.
    #
    # @return [Integer] The object id of the loaded save's Game_System.
    def self.save_key
      $game_system.object_id
    end

    # Applies the trades the relay listed once the player is free on the map, and drops them when
    # another save was loaded meanwhile, which the DLL asks the relay for anew. Called by the map
    # every frame.
    def self.apply_waiting
      return unless @recovered

      key, trades = @recovered
      unless key == save_key
        MGQ_MpTrade.log("dropped #{trades.size} trade(s) to recover: another save was loaded meanwhile, asking the relay again")
        @recovered = nil
        return
      end

      reason = MGQ_MpTrade.busy_reason
      return MGQ_MpTrade.log_once([:recovery_waits, key], "#{trades.size} trade(s) to recover wait until the player is free on the map (#{reason})") if reason

      @recovered = nil
      trades.each { |id, partner, mine, theirs| recover(id, partner, mine, theirs) }
    rescue => e
      MGQ_MpTrade.log("recovering trades failed: #{MGQ_MpLog.failure(e)} at #{Array(e.backtrace).first}")
    end

    # Applies a trade the relay committed, unless the save has it, and saves; the relay hears of a
    # trade the save holds.
    #
    # @param id [String] The trade's id at the relay.
    # @param partner [String] The other player's id.
    # @param mine [Hash] The player's offer, see Items.read_offer.
    # @param theirs [Hash] The other player's offer.
    def self.recover(id, partner, mine, theirs)
      if applied?(id)
        if unsaved.include?(id)
          MGQ_MpTrade.log("recovery skipped trade #{MGQ_MpTrade.short(id)}: applied, waiting for a save that holds it")
        else
          MGQ_MpTrade.log("recovery skipped trade #{MGQ_MpTrade.short(id)}: the save holds it, telling the relay it is done")
          MGQ_MpTrade.done(id)
        end
        return
      end

      MGQ_MpTrade.log("recovering trade #{MGQ_MpTrade.short(id)} with #{MGQ_MpTrade.name_of(partner)}")
      applied = apply_once(id, Items.read_offer(mine), Items.read_offer(theirs))
      return MGQ_MpOverworldSync.notice("A trade that was cut off did not complete in full.") unless applied

      saved = finish
      MGQ_MpOverworldSync.notice(saved ? "A trade that was cut off completed, game saved." : "A trade that was cut off completed. Save your game.")
      MGQ_MpTrade.log("recovered trade #{MGQ_MpTrade.short(id)}#{saved ? ', game saved' : ', not saved yet'}")
    end
  end

  # What trades offer between two players, through ui_actions.rbx: their choices on the action
  # wheel and in the World overview, and offers in the overview and the notification box.
  module Offers
    # The choice wherever the mod's DLL cannot run trades.
    UNAVAILABLE = MGQ_MpActions::Option.new("Trade", nil, "Trading is not available.")

    # The choice in a world made before the world list, which the relay cannot name.
    OLD_WORLD = MGQ_MpActions::Option.new("Trade", nil, "Trading is off in this world.")

    # The choice while trades cannot run, saying why.
    #
    # @return [MGQ_MpActions::Option] The choice.
    def self.unavailable
      MGQ_MpTrade.dll_ready? ? OLD_WORLD : UNAVAILABLE
    end

    # The wheel's trade choice: accepting the trade of a player nearby, else offering one to the
    # players nearby.
    #
    # @return [MGQ_MpActions::Option] The choice.
    def self.wheel_option
      trade = MGQ_MpTrade
      return unavailable unless trade.available?

      option = MGQ_MpActions::Option
      near = MGQ_MpOverworldSync::Peers.all.select { |peer| trade.same_map?(peer) && MGQ_MpOverworldSync::Peers.near?(peer) }
      offerer = near.find { |peer| trade.offered_by?(peer, false) }
      return option.new("Accept #{offerer.state['name']}'s trade", lambda { trade.accept(offerer) }, nil) if offerer
      return own_options.first if trade.inviting?

      option.new("Trade", near.empty? ? nil : lambda { trade.invite }, "Nobody is near enough to trade.")
    end

    # The trade choice for another player in the World overview: accepting their trade, which
    # closes the overview, else offering them one while they stand on the player's map.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
    # @return [MGQ_MpActions::Option] The choice.
    def self.peer_option(peer)
      trade = MGQ_MpTrade
      return unavailable unless trade.available?

      option = MGQ_MpActions::Option
      return option.new("Accept trade", lambda { trade.accept(peer) }, nil, nil, true) if trade.offered_by?(peer)
      return option.new("Trade", nil, "#{peer.state['name']} is not on your map.") unless trade.same_map?(peer)
      return option.new("Trade offered", nil, "Your trade offer to #{peer.state['name']} stands.") if trade.targets.include?(peer.state["id"].to_s)

      option.new("Trade", lambda { trade.invite(peer.state["id"]) }, nil)
    end

    # The trade choice on the player's own row of the World overview: stopping an offer.
    #
    # @return [Array<MGQ_MpActions::Option>] The choice, none while the player offers no trade.
    def self.own_options
      MGQ_MpTrade.inviting? ? [MGQ_MpActions::Option.new("Stop offering a trade", lambda { MGQ_MpTrade.stop }, nil)] : []
    end

    # Tells another player's trade offer, when it reaches the player.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @return [Array, nil] The text and its color, nil for none.
    def self.call_of(peer)
      MGQ_MpTrade.offered_by?(peer) ? ["Wants to trade", TRADE_COLOR] : nil
    end

    # Tells another player's trade offer for the notification box, while it reaches the player. A
    # trade opens only from the map, so in a menu the offer stands without the key that accepts it.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @return [MGQ_MpActions::Notice, nil] The offer, nil for none.
    def self.notice_of(peer)
      trade = MGQ_MpTrade
      return nil unless trade.available? && trade.offered_by?(peer)

      on_map = SceneManager.scene.is_a?(Scene_Map)
      MGQ_MpActions::Notice.new([:trade, peer.seat], "#{peer.state['name']} wants to trade", TRADE_COLOR, on_map ? "Accept" : nil,
                                on_map ? lambda { trade.accept(peer) } : nil, lambda { trade.decline(peer, "no") }, peer.state["id"])
    end
  end
end

# What trades take part in of the world, through overworld_sync.rbx; the DLL takes the trade's
# messages itself.

begin
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpTrade.tick(in_world) }
  MGQ_MpOverworldSync.state_fields { MGQ_MpTrade.state_fields }
  MGQ_MpOverworldSync.label_line { |peer| MGQ_MpTrade.label_line(peer) }
rescue => e
  MGQ_MpTrade.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

# The trade's events from the DLL.

begin
  bridge = MGQ_Multiplayer::Bridge
  bridge.on(MGQ_MpTrade::VIEW_EVENT) { |view| MGQ_MpTrade.take_view(view) }
  bridge.on(MGQ_MpTrade::OPEN_SCREEN_EVENT) { |state| MGQ_MpTrade.open_screen(state) }
  bridge.on(MGQ_MpTrade::THEIR_OFFER_EVENT) { |event| MGQ_MpTrade.take_their_offer(event) }
  bridge.on(MGQ_MpTrade::NOTE_EVENT) { |text| MGQ_MpTrade.note = text }
  bridge.on(MGQ_MpTrade::CLOSED_EVENT) { MGQ_MpTrade.closed }
  bridge.on(MGQ_MpTrade::STOP_OFFERING_EVENT) { MGQ_MpTrade.stop }
  bridge.on(MGQ_MpTrade::DECLINED_EVENT) { |event| MGQ_MpTrade.declined(event) }
  bridge.on(MGQ_MpTrade::APPLY_EVENT) { |event| MGQ_MpTrade.complete(event) }
  bridge.on(MGQ_MpTrade::RECOVER_EVENT) { |event| MGQ_MpTrade::Recovery.take(event) }
rescue => e
  MGQ_MpTrade.log("bridge events FAILED: #{e.class}: #{e.message}")
end

# What trades add to the action wheel, the World overview and the notification box, through
# ui_actions.rbx.

begin
  MGQ_MpActions.offer(MGQ_MpTrade::Offers)
  MGQ_MpActions.wheel_choice(30) { MGQ_MpTrade::Offers.wheel_option }
  MGQ_MpActions.own_doing_from { MGQ_MpTrade.own_doing }
rescue => e
  MGQ_MpTrade.log("actions FAILED: #{e.class}: #{e.message}")
end

# Game hooks, through core_hooks.rbx.

begin
  MGQ_MpHooks.after(Scene_Map, :update_scene, "trade") { MGQ_MpTrade.on_map unless scene_changing? }

  # The save after a trade goes where the player last saved or loaded in the world. The newest
  # translation's plugins replace load_game, which still calls load_game_without_rescue.
  MGQ_MpHooks.around(DataManager.singleton_class, :load_game_without_rescue, "trade") do |_manager, args, original|
    loaded = original.call
    MGQ_MpTrade::Saving.slot = args[0] if loaded && MGQ_MpOverworldSync.in_world?
    loaded
  end

  # A save in the world also tells the relay of the trades it now holds.
  MGQ_MpHooks.around(DataManager.singleton_class, :save_game_without_rescue, "trade") do |_manager, args, original|
    saved = original.call
    if saved && MGQ_MpOverworldSync.in_world?
      MGQ_MpTrade::Saving.slot = args[0]
      # The game's save_game deletes the save file when anything here raises.
      begin
        MGQ_MpTrade::Recovery.saved_game
      rescue => e
        MGQ_MpTrade.log("telling the relay of saved trades failed: #{e.class}: #{e.message}")
      end
    end
    saved
  end

  MGQ_MpHooks.before(DataManager.singleton_class, :setup_new_game, "trade") { MGQ_MpTrade::Saving.slot = nil }
rescue => e
  MGQ_MpTrade.log("hooks FAILED: #{e.class}: #{e.message}")
end
