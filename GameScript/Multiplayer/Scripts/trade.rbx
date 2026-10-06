#----------------------------------------------------------------
#  trade.rbx
#
#  Changelog:
#      Paulinchen  2026-10-06: Created
#
#----------------------------------------------------------------

# Trading between two players on the same map: items, equipment, enchant stones and gold, but no
# key items. A player offers a trade like a party invite: the players nearby, or one player on the
# map picked in the World overview. Once the other accepts, both games open the trade screen
# (ui_trade.rbx), where each player puts together an offer and confirms both offers.
#
# Nothing changes hands until the relay committed the trade: both games send it the same offers,
# and the relay marks it committed in one step, so a game that drops halfway can never keep both
# sides. Each game then applies the trade, notes it in the save and saves. A game that missed the
# commit, by a crash or a lost connection, applies it the next time it enters the world.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpTrade
  # Color of the trade line above a ghost's name and of the trade's notices.
  TRADE_COLOR = Color.new(160, 224, 255)

  # Frames an accepted trade waits for the other player's game to open it, six seconds.
  ANSWER_FRAMES = 360

  # Frames a trade waits for the other player once their connection dropped, the world's rejoin time.
  AWAY_FRAMES = MGQ_MpOverworldSync::REJOIN_FRAMES

  # Frames between two looks at the relay's answer, a quarter of a second.
  POLL_FRAMES = 15

  # Most of one item a trade moves, the game's own cap of a stack.
  MAX_AMOUNT = 99

  # Trades the save remembers as applied, so a recovered trade is applied once.
  KEPT_TRADES = 50

  # Frames before the relay is asked again for trades to recover when the DLL could not ask yet,
  # as before the world's connection opened, five seconds.
  RETRY_FRAMES = 300

  # Bytes the DLL may write the list of trades to recover into at first.
  PENDING_SIZE = 16384

  # Why a trade could not open or ended, by the reason a message carries.
  REASONS = {
    "busy" => "is busy",
    "gone" => "stopped offering a trade",
    "no" => "declined your trade",
    "off" => "cancelled the trade",
    "left" => "left the map",
  }

  # What the relay answered, by its reason, for a trade it did not commit.
  RELAY_REASONS = {
    "expired" => "The trade timed out before both games confirmed it.",
    "differ" => "The offers changed while the trade was confirmed. Confirm again.",
    "cancelled" => "The trade was cancelled.",
  }

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
    # @param token [String] The item's token, see Entry.
    # @return [Entry, nil] The entry, nil when the offer has none.
    def entry(token)
      entries.find { |entry| entry.token == token }
    end
  end

  # An item of an offer.
  #
  # @!attribute token [String] The item as text, the same in both games, see Items.token.
  # @!attribute item [RPG::BaseItem, nil] This game's item, nil when its data lacks it.
  # @!attribute amount [Integer] How many, one for an enchanted or socketed copy.
  Entry = Struct.new(:token, :item, :amount)

  # A trade between the player and one other player.
  #
  # @!attribute id [String] The trade's id, 24 hexadecimal characters, made by the player who offered it.
  # @!attribute partner [String] The other player's id.
  # @!attribute name [String] The other player's name.
  # @!attribute mine [Offer] The player's offer.
  # @!attribute theirs [Offer] The other player's offer, as they sent it.
  # @!attribute their_text [String] The other player's offer as text.
  # @!attribute my_rev [Integer] How often the player changed their offer.
  # @!attribute their_rev [Integer] How often the other player changed theirs.
  # @!attribute confirmed [Boolean] Whether the player confirmed both offers as they stand.
  # @!attribute their_confirm [Array, nil] The revisions the other player confirmed, theirs then the player's.
  # @!attribute stage [Symbol] :open while both put the offers together, :committing while the
  #   relay decides, :closed once it ended.
  # @!attribute away [Integer] Frames the other player has been away.
  # @!attribute relay_id [String, nil] The id the relay knows the confirmed offers by.
  Session = Struct.new(:id, :partner, :name, :mine, :theirs, :their_text, :my_rev, :their_rev, :confirmed,
                       :their_confirm, :stage, :away, :relay_id) do
    # Reports whether both players confirmed the offers as they stand now.
    #
    # @return [Boolean] Whether they did.
    def agreed?
      confirmed && their_confirm == [their_rev, my_rev]
    end
  end

  @invite = MGQ_MpCoop::Invite.new
  @accepted = nil
  @session = nil
  @open_screen = false
  @poll = 0

  extend MGQ_MpLog

  # What starts this script's lines in the mod's InGame.log.
  LOG_TAG = "trade"

  # Reports whether trades can run: the mod's DLL is installed and up to date, and a world is open.
  #
  # @return [Boolean] Whether they can.
  def self.available?
    MGQ_Multiplayer.available? && !MGQ_Multiplayer.outdated? && MGQ_MpOverworldSync.in_world?
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
    same_map?(peer) && MGQ_MpCoop::Invite.reaches_me?(peer.state, "trading", "trading_to", anywhere)
  end

  # Reports whether the player may open a trade: free on the map, with no battle of their own, no
  # story holding them and no other trade.
  #
  # @return [Boolean] Whether they may.
  def self.free?
    return false unless MGQ_MpOverworldSync.map_free? && @session.nil? && !MGQ_MpHooks.player_held?
    return false if defined?(MGQ_MpBattlesSync) && !MGQ_MpBattlesSync.role.nil?

    !(defined?(MGQ_MpBattles) && MGQ_MpBattles.running?)
  end

  # Offers a trade to the players nearby, and to a player anywhere on the map when named.
  #
  # @param target_id [String, nil] The id of a player the offer reaches wherever on the map they stand.
  def self.invite(target_id = nil)
    @invite.invite(target_id)
  end

  # Stops offering a trade.
  def self.stop
    @invite.stop
  end

  # Forgets every offer and trade, as when the world closes. A trade the relay is deciding is
  # recovered the next time the world opens.
  def self.reset
    stop
    @accepted = nil
    @session = nil
    @open_screen = false
    Saving.slot = nil
    Recovery.reset
  end

  # The fields the trade adds to the state the player's game tells the others. They are not named
  # "trade", which marks the messages this script takes.
  #
  # @return [Hash] The fields.
  def self.state_fields
    { "trading" => inviting? ? 1 : 0, "trading_to" => targets.join(",") }
  end

  # Tells what the line above a ghost's name says: their trade offer, when it reaches the player.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The ghost's player.
  # @return [Array, nil] The text and its color, nil for none.
  def self.label_line(peer)
    offered_by?(peer) ? ["Wants to trade (#{MGQ_MpHotkeys.label(:wheel)})", TRADE_COLOR] : nil
  end

  # Lets the offer run out, follows the trade and recovers trades the relay committed. Called every
  # frame in every scene.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    return reset unless in_world

    @invite.count_down
    if @accepted && (@accepted[:frames] += 1) > ANSWER_FRAMES
      MGQ_MpOverworldSync.notice("#{@accepted[:name]} did not open the trade.")
      @accepted = nil
    end
    tick_session if @session
    Recovery.tick
  end

  # Follows the other player and the relay's answer.
  def self.tick_session
    session = @session
    if session.stage == :committing
      tick_commit(session)
    else
      peer = partner_peer
      session.away = peer && !peer.away ? 0 : session.away + 1
      close("#{session.name} left.") if session.away > AWAY_FRAMES
    end
  end

  # Finds the other player of the trade, who may have come back on another seat.
  #
  # @return [MGQ_MpOverworldSync::Peers::Peer, nil] The player, nil while they are gone.
  def self.partner_peer
    return nil unless @session

    MGQ_MpOverworldSync::Peers.all.find { |peer| peer.state["id"].to_s == @session.partner }
  end

  # Sends a trade message to the other player.
  #
  # @param fields [Hash] The message's fields besides "trade" and "tid".
  # @param kind [String] What the message is.
  # @param body [String] What follows the fields.
  def self.tell(kind, fields = {}, body = "")
    peer = partner_peer
    return unless peer && @session

    MGQ_MpOverworldSync.tell(peer.seat, { "trade" => kind, "tid" => @session.id }.merge(fields), body)
  end

  # Accepts another player's trade offer: tells them, and waits for their game to open the trade.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player who offered it.
  def self.accept(peer)
    return MGQ_MpOverworldSync.notice("Finish what you are doing first.") unless free?

    MGQ_MpOverworldSync.tell(peer.seat, { "trade" => "accept" })
    @accepted = { :id => peer.state["id"].to_s, :name => peer.state["name"].to_s, :frames => 0 }
    MGQ_MpOverworldSync.notice("You accepted #{peer.state['name']}'s trade.")
  end

  # Turns another player down, telling them why.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  # @param reason [String] A key of REASONS.
  # @param id [String, nil] The trade's id, for a trade that was opened.
  # @return [nil] Nothing.
  def self.decline(peer, reason, id = nil)
    fields = { "trade" => "decline", "reason" => reason }
    fields["tid"] = id if id
    MGQ_MpOverworldSync.tell(peer.seat, fields)
    log("declined #{peer.state['name']}: #{reason}")
    nil
  end

  # Takes a trade message. Called by overworld_sync.rbx.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it.
  # @param message [Hash] The message's fields, its body under :payload.
  def self.take(peer, message)
    return unless peer

    case message["trade"]
    when "accept" then take_accept(peer)
    when "open" then take_open(peer, message["tid"].to_s)
    when "decline" then take_decline(peer, message["reason"].to_s, message["tid"])
    else take_in_session(peer, message)
    end
  rescue => e
    log("taking a trade message failed: #{e.class}: #{e.message}")
  end

  # Takes a message of the running trade, from its other player.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who sent it.
  # @param message [Hash] The message's fields, its body under :payload.
  def self.take_in_session(peer, message)
    session = @session
    return unless session && session.id == message["tid"].to_s && session.partner == peer.state["id"].to_s

    case message["trade"]
    when "offer" then take_offer(session, message["rev"].to_i, message[:payload].to_s)
    when "confirm" then take_confirm(session, message["mine"].to_i, message["yours"].to_i)
    when "unconfirm" then take_unconfirm(session)
    when "cancel" then take_cancel(session, message["reason"].to_s)
    end
  end

  # As the player who offered the trade, opens it with the player who accepted.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player who accepted.
  def self.take_accept(peer)
    return decline(peer, "gone") unless @invite.covers?(peer.state) && same_map?(peer)
    return decline(peer, "busy") unless free?

    stop
    id = Array.new(24) { rand(16).to_s(16) }.join
    MGQ_MpOverworldSync.tell(peer.seat, { "trade" => "open", "tid" => id })
    begin_session(id, peer)
  end

  # As the player who accepted, opens the trade the other player opened.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player who offered it.
  # @param id [String] The trade's id.
  def self.take_open(peer, id)
    unless @accepted && @accepted[:id] == peer.state["id"].to_s
      return MGQ_MpOverworldSync.tell(peer.seat, { "trade" => "cancel", "tid" => id, "reason" => "busy" })
    end

    @accepted = nil
    return decline(peer, "busy", id) unless free? && id =~ /\A[0-9a-f]{24}\z/

    begin_session(id, peer)
  end

  # Starts a trade and has the map open its screen.
  #
  # @param id [String] The trade's id.
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  def self.begin_session(id, peer)
    @session = Session.new(id, peer.state["id"].to_s, peer.state["name"].to_s, Offer.new(0, []), Offer.new(0, []), "",
                           0, 0, false, nil, :open, 0, nil)
    @open_screen = true
    log("trade #{id} with #{@session.name}")
  end

  # Tells why the other player could not trade.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  # @param reason [String] A key of REASONS.
  # @param id [String, nil] The trade's id, for a trade that was opened.
  def self.take_decline(peer, reason, id)
    @accepted = nil if @accepted && @accepted[:id] == peer.state["id"].to_s
    @invite.drop(peer.state["id"]) if reason == "no"
    if @session && id && @session.id == id && @session.stage == :open
      close("#{peer.state['name']} #{REASONS.fetch(reason, 'cannot trade now')}.")
    else
      MGQ_MpOverworldSync.notice("#{peer.state['name']} #{REASONS.fetch(reason, 'cannot trade now')}.")
    end
  end

  # Takes the other player's offer as it stands now, which takes back both confirmations.
  #
  # @param session [Session] The trade.
  # @param rev [Integer] How often they changed it.
  # @param text [String] The offer as text.
  def self.take_offer(session, rev, text)
    return if rev <= session.their_rev

    abandon_commit(session)
    session.their_rev = rev
    session.their_text = text
    session.theirs = Items.read_offer(text)
    session.their_confirm = nil
    session.confirmed = false
  end

  # Takes the other player's confirmation, and commits once both confirmed the same offers.
  #
  # @param session [Session] The trade.
  # @param mine [Integer] The revision of their own offer they confirmed.
  # @param yours [Integer] The revision of the player's offer they confirmed.
  def self.take_confirm(session, mine, yours)
    session.their_confirm = [mine, yours]
    commit(session) if session.stage == :open && session.agreed?
  end

  # Takes back the other player's confirmation, and a commit the relay has not decided, which the
  # other game never sends now.
  #
  # @param session [Session] The trade.
  def self.take_unconfirm(session)
    session.their_confirm = nil
    abandon_commit(session)
  end

  # Ends the trade the other player cancelled, unless the relay decides it already.
  #
  # @param session [Session] The trade.
  # @param reason [String] A key of REASONS.
  def self.take_cancel(session, reason)
    return if session.stage == :committing

    close("#{session.name} #{REASONS.fetch(reason, 'cancelled the trade')}.")
  end

  # Changes how many of an item the player offers.
  #
  # @param item [RPG::BaseItem] The item.
  # @param amount [Integer] How many, 0 to take it out of the offer; at most what the bag holds.
  def self.set_amount(item, amount)
    session = @session
    return unless session && session.stage == :open && Items.tradeable?(item)

    token = Items.token(item)
    amount = [[amount, 0].max, Items.held(item), Items.unique?(item) ? 1 : MAX_AMOUNT].min
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

    gold = [[gold.to_i, 0].max, $game_party.gold].min
    return if session.mine.gold == gold

    session.mine.gold = gold
    offer_changed(session)
  end

  # Tells the other player the player's new offer, which takes back both confirmations.
  #
  # @param session [Session] The trade.
  def self.offer_changed(session)
    session.my_rev += 1
    session.confirmed = false
    session.their_confirm = nil
    tell("offer", { "rev" => session.my_rev }, Items.write_offer(session.mine))
  end

  # Tells why the player cannot confirm now.
  #
  # @return [String, nil] The reason, nil while they can.
  def self.confirm_refusal
    session = @session
    return "There is no trade." unless session
    return "The relay is deciding the trade." if session.stage != :open
    return "Both offers are empty." if session.mine.empty? && session.theirs.empty?

    Items.receive_refusal(session.theirs, session.name)
  end

  # Confirms both offers as they stand, or takes the confirmation back. The trade goes to the relay
  # once both players confirmed the same offers.
  def self.toggle_confirm
    session = @session
    return unless session && session.stage == :open

    if session.confirmed
      session.confirmed = false
      return tell("unconfirm")
    end

    refusal = confirm_refusal
    return MGQ_MpOverworldSync.notice(refusal) if refusal

    session.confirmed = true
    tell("confirm", { "mine" => session.my_rev, "yours" => session.their_rev })
    commit(session) if session.agreed?
  end

  # Cancels the trade: at once while it is open, through the relay while it decides.
  def self.cancel
    session = @session
    return unless session

    if session.stage == :committing
      Relay.cancel(world_id, session.relay_id)
      return
    end

    tell("cancel", { "reason" => "off" })
    close("You cancelled the trade.")
  end

  # Ends the trade, with a notice, and closes its screen.
  #
  # @param text [String] The notice.
  def self.close(text)
    @session.stage = :closed if @session
    @session = nil
    @open_screen = false
    MGQ_MpOverworldSync.notice(text)
    log(text)
  end

  # The open world's id.
  #
  # @return [String] The id, "" while none is open.
  def self.world_id
    MGQ_MpOverworldSync.in_world? ? MGQ_MpWorld.world.id.to_s : ""
  end

  # Writes both offers as the relay compares them: each player's id and offer, ordered by id, so
  # both games write the same text.
  #
  # @param session [Session] The trade.
  # @return [String] The text, one line.
  def self.agreed_text(session)
    sides = [[MGQ_MpOverworldSync::Me.id.to_s, Items.write_offer(session.mine)], [session.partner, session.their_text]]
    sides.sort_by { |id, _| id }.map { |id, text| "#{id}=#{text}" }.join("|")
  end

  # Names the confirmed offers for the relay: the trade's id and both revisions, ordered by player
  # id, so both games name them alike and a later confirmation is a trade of its own.
  #
  # @param session [Session] The trade.
  # @return [String] 32 hexadecimal characters.
  def self.relay_id(session)
    revs = [[MGQ_MpOverworldSync::Me.id.to_s, session.my_rev], [session.partner, session.their_rev]]
    session.id + revs.sort_by { |id, _| id }.map { |_, rev| format("%04x", rev % 65536) }.join
  end

  # Hands the confirmed offers to the relay, which commits them once the other game sent the same.
  #
  # @param session [Session] The trade.
  def self.commit(session)
    session.relay_id = relay_id(session)
    unless Relay.commit(world_id, session.relay_id, session.partner, agreed_text(session))
      session.confirmed = false
      tell("unconfirm")
      return MGQ_MpOverworldSync.notice("The trade could not reach the relay.")
    end

    session.stage = :committing
    @poll = 0
    log("trade #{session.relay_id} sent to the relay")
  end

  # Takes back a commit the relay has not decided, as when the other player changed their offer.
  #
  # @param session [Session] The trade.
  def self.abandon_commit(session)
    return unless session.stage == :committing

    Relay.cancel(world_id, session.relay_id)
  end

  # Follows the relay's answer to the commit.
  #
  # @param session [Session] The trade.
  def self.tick_commit(session)
    return if (@poll += 1) < POLL_FRAMES

    @poll = 0
    state = Relay.state
    return unless state["trade"] == session.relay_id

    case state["state"]
    when "committed" then complete(session)
    when "cancelled" then reopen(session, RELAY_REASONS.fetch(state["reason"].to_s, "The trade was cancelled."))
    when "failed"
      Recovery.check_again
      close("The trade could not reach the relay. If it went through, it completes the next time you enter the world.")
    end
  end

  # Opens the trade again after the relay turned the commit down, with both confirmations taken back.
  #
  # @param session [Session] The trade.
  # @param text [String] Why, as a notice.
  def self.reopen(session, text)
    session.stage = :open
    session.confirmed = false
    session.their_confirm = nil
    session.relay_id = nil
    MGQ_MpOverworldSync.notice(text)
    log(text)
  end

  # Completes the trade the relay committed: applies it, saves and tells the relay.
  #
  # @param session [Session] The trade.
  def self.complete(session)
    id = session.relay_id
    unless Recovery.applied?(id)
      Items.apply(session.mine, session.theirs)
      Recovery.remember(id)
    end
    saved = Saving.save
    Relay.done(world_id, id)
    close(saved ? "Trade with #{session.name} complete, game saved." : "Trade with #{session.name} complete. Save your game, no slot was free.")
  end

  # Opens the trade screen from the map once a trade began. Called by the map every frame.
  def self.on_map
    return unless @open_screen && @session

    @open_screen = false
    SceneManager.call(Scene_MpTrade)
  rescue => e
    log("opening the trade screen failed: #{e.class}: #{e.message}")
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

    # Reports whether an item may be traded: anything but the game's key items.
    #
    # @param item [RPG::BaseItem, nil] The item.
    # @return [Boolean] Whether it may.
    def self.tradeable?(item)
      return false unless item.is_a?(RPG::Item) || item.is_a?(RPG::Weapon) || item.is_a?(RPG::Armor)

      !(item.is_a?(RPG::Item) && item.key_item? && !stone?(item))
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
      ($game_party.items + $game_party.weapons + $game_party.armors).select { |item| tradeable?(item) && held(item) > 0 }
    end

    # Writes an item as text, the same in both games: i, w or a and its id for an item of the
    # database, u and its text from MGQ_MpActors::Items for an enchanted or socketed copy, with the
    # copy's name prefix in hexadecimal after a tilde.
    #
    # @param item [RPG::BaseItem] The item.
    # @return [String] The text.
    def self.token(item)
      return "u#{MGQ_MpActors::Items.write(item)}~#{prefix_of(item).unpack('H*').first}" if unique?(item)

      "#{item.is_a?(RPG::Item) ? 'i' : item.is_a?(RPG::Weapon) ? 'w' : 'a'}#{item.id}"
    end

    # The name prefix an enchanted copy rolled.
    #
    # @param item [RPG::BaseItem] The copy.
    # @return [String] The prefix, "" for none.
    def self.prefix_of(item)
      item.respond_to?(:enchant_item?) && item.enchant_item? ? MGQ_MpGame.get(item, :prefix).to_s : ""
    end

    # Makes an item from its text: the database's item, or a new copy of an enchanted or socketed one.
    #
    # @param token [String] The text, see token.
    # @return [RPG::BaseItem, nil] The item, nil when this game's data lacks it.
    def self.item_of(token)
      if (match = /\Au([^~]*)~([0-9a-f]*)\z/.match(token))
        item = MGQ_MpActors::Items.read(match[1])
        return nil unless item && unique?(item)

        MGQ_MpGame.set(item, :prefix, [match[2]].pack("H*").force_encoding("UTF-8")) if item.enchant_item?
        return item
      end

      match = /\A([iwa])(\d{1,6})\z/.match(token)
      return nil unless match

      table = { "i" => $data_items, "w" => $data_weapons, "a" => $data_armors }[match[1]]
      item = table[match[2].to_i]
      item && !item.name.to_s.empty? ? item : nil
    end

    # Writes an offer as one line: g and the gold, then each item's token, a star and its amount,
    # separated by semicolons.
    #
    # @param offer [Offer] The offer.
    # @return [String] The text.
    def self.write_offer(offer)
      (["g#{offer.gold.to_i}"] + offer.entries.map { |entry| "#{entry.token}*#{entry.amount}" }).join(";")
    end

    # Reads an offer, keeping the items this game's data lacks without their item.
    #
    # @param text [String] The offer, see write_offer.
    # @return [Offer] The offer.
    def self.read_offer(text)
      offer = Offer.new(0, [])
      text.to_s.split(";").each do |part|
        if part =~ /\Ag(\d{1,10})\z/
          offer.gold = $1.to_i
        elsif (match = /\A(.+)\*(\d{1,3})\z/.match(part))
          offer.entries << Entry.new(match[1], item_of(match[1]), match[2].to_i)
        end
      end
      offer
    end

    # Tells why the player's game cannot take an offer.
    #
    # @param offer [Offer] The other player's offer.
    # @param name [String] The other player's name.
    # @return [String, nil] The reason, nil while it can.
    def self.receive_refusal(offer, name)
      return "#{name}'s offer holds items your game does not know." if offer.entries.any? { |entry| entry.item.nil? }
      return "#{name}'s offer holds key items." if offer.entries.any? { |entry| !tradeable?(entry.item) }
      return "#{name}'s offer is not valid." if offer.entries.any? { |entry| entry.amount < 1 || entry.amount > (unique?(entry.item) ? 1 : MAX_AMOUNT) }
      return "You cannot carry that much gold." if $game_party.gold + offer.gold.to_i > $game_party.max_gold

      full = offer.entries.find { |entry| !unique?(entry.item) && held(entry.item) + entry.amount > MAX_AMOUNT }
      return "You cannot carry more #{full.item.name}." if full

      copies = offer.entries.select { |entry| unique?(entry.item) }.group_by { |entry| entry.item.class }
      crowded = copies.find { |_, entries| room_for_copies(entries.first.item) < entries.size }
      crowded ? "You cannot carry more equipment like #{crowded[1].first.item.name}." : nil
    end

    # Counts the copies of a kind the party can still take.
    #
    # @param item [RPG::BaseItem] A copy of the kind.
    # @return [Integer] How many.
    def self.room_for_copies(item)
      party = $game_party
      return MAX_AMOUNT unless party.respond_to?(:uniq_max_item_number) && party.respond_to?(:uniq_item_number)

      party.uniq_max_item_number(item) - party.uniq_item_number(item)
    end

    # Moves the trade's items in the player's game: takes the player's offer out of the bag, as much
    # of it as is still there, and puts the other player's in. The party's story does not pass it on.
    #
    # @param mine [Offer] The player's offer.
    # @param theirs [Offer] The other player's offer.
    def self.apply(mine, theirs)
      give = lambda do
        $game_party.lose_gold([mine.gold.to_i, $game_party.gold].min)
        mine.entries.each { |entry| take_out(entry) }
        $game_party.gain_gold(theirs.gold.to_i)
        theirs.entries.each { |entry| put_in(entry) }
      end
      defined?(MGQ_MpCoopEvents) ? MGQ_MpCoopEvents.granting(&give) : give.call
    end

    # Takes an item of the player's offer out of the bag.
    #
    # @param entry [Entry] The item.
    def self.take_out(entry)
      if entry.token.start_with?("u")
        copy = bag.find { |item| unique?(item) && token(item) == entry.token }
        $game_party.lose_item(copy, 1) if copy
      elsif entry.item
        $game_party.lose_item(entry.item, [entry.amount, held(entry.item)].min)
      end
    end

    # Puts an item of the other player's offer into the bag: a fresh copy of an enchanted or
    # socketed one, which the party keeps as its own.
    #
    # @param entry [Entry] The item.
    def self.put_in(entry)
      item = entry.token.start_with?("u") ? item_of(entry.token) : entry.item
      return log_missing(entry) unless item

      $game_party.add_item_data(item, 0) if unique?(item)
      $game_party.gain_item(item, unique?(item) ? 1 : entry.amount)
    end

    # Logs an item the player's game could not make.
    #
    # @param entry [Entry] The item.
    def self.log_missing(entry)
      MGQ_MpTrade.log("left out #{entry.token[0, 40]}, which this game's data lacks")
    end
  end

  # The save after a trade: into the slot the player last saved or loaded in the world, or the
  # first free one.
  module Saving
    # Remembers the slot of a save loaded or written in a world.
    #
    # @param index [Integer, nil] The slot, nil for a new game.
    def self.slot=(index)
      @slot = index
    end

    # Saves the game.
    #
    # @return [Boolean] Whether it saved.
    def self.save
      index = @slot || (0...DataManager.savefile_max).find { |slot| !File.exist?(DataManager.make_filename(slot)) }
      return false unless index

      saved = DataManager.save_game(index)
      @slot = index if saved
      saved ? true : false
    rescue => e
      MGQ_MpTrade.log("saving after a trade failed: #{e.class}: #{e.message}")
      false
    end
  end

  # Trades the relay committed that the player's game has not applied: after a crash, a lost
  # connection, or a save loaded from before the trade. Each is applied once per save, noted in the
  # save, and saved.
  module Recovery
    # Reports whether the save applied a trade already.
    #
    # @param id [String] The trade's id at the relay.
    # @return [Boolean] Whether it did.
    def self.applied?(id)
      Array($game_system.instance_variable_get(:@mgq_mp_trades)).include?(id)
    end

    # Notes in the save that a trade was applied.
    #
    # @param id [String] The trade's id at the relay.
    def self.remember(id)
      trades = Array($game_system.instance_variable_get(:@mgq_mp_trades)) + [id]
      $game_system.instance_variable_set(:@mgq_mp_trades, trades.last(KEPT_TRADES))
    end

    # Has the relay asked again on the next frame on the map.
    def self.check_again
      @checked = nil
    end

    # Forgets what was asked, as when the world closes; a fetch running still ends in the DLL.
    def self.reset
      @checked = nil
      @fetching = false
      @wait = 0
    end

    # Asks the relay once per save loaded in the world, from the map, and applies what it answers.
    # Called every frame in every scene.
    def self.tick
      return poll if @fetching
      return unless SceneManager.scene.is_a?(Scene_Map) && MGQ_MpTrade.session.nil?

      key = [MGQ_MpTrade.world_id, $game_system.object_id]
      return if @checked == key
      return if (@wait = @wait.to_i - 1) > 0

      @fetching = Relay.fetch(MGQ_MpTrade.world_id)
      @fetching ? @checked = key : @wait = RETRY_FRAMES
    end

    # Takes the relay's answer once it came.
    def self.poll
      state, trades = Relay.pending
      return if state == "busy"

      @fetching = false
      return MGQ_MpTrade.log("asking for trades to recover failed") unless state == "done"

      trades.each { |id, text| recover(id, text) }
    end

    # Applies a trade the relay committed, unless the save has it, and tells the relay.
    #
    # @param id [String] The trade's id at the relay.
    # @param text [String] Both offers, see MGQ_MpTrade.agreed_text.
    def self.recover(id, text)
      unless applied?(id)
        sides = Hash[text.split("|").map { |side| side.split("=", 2) }]
        me = MGQ_MpOverworldSync::Me.id.to_s
        partner = (sides.keys - [me]).first
        return MGQ_MpTrade.log("trade #{id} does not name this player") unless sides.key?(me) && partner

        Items.apply(Items.read_offer(sides[me]), Items.read_offer(sides[partner]))
        remember(id)
        saved = Saving.save
        MGQ_MpOverworldSync.notice(saved ? "A trade that was cut off completed, game saved." : "A trade that was cut off completed. Save your game.")
        MGQ_MpTrade.log("recovered trade #{id}")
      end
      Relay.done(MGQ_MpTrade.world_id, id)
    end
  end

  # Patch/Multiplayer/Multiplayer.dll's trades at the relay.
  module Relay
    # Hands both offers to the relay, which commits them once the other game sent the same.
    #
    # @param world [String] The world's id.
    # @param id [String] The trade's id at the relay.
    # @param partner [String] The other player's id.
    # @param text [String] Both offers, see MGQ_MpTrade.agreed_text.
    # @return [Boolean] Whether it started.
    def self.commit(world, id, partner, text)
      MGQ_Multiplayer::Link.function('mp_trade_commit', 'pppp').call(world + "\0", id + "\0", partner + "\0", text + "\0") == 1
    rescue => e
      MGQ_MpTrade.log("committing failed: #{e.class}: #{e.message}")
      false
    end

    # Cancels a trade the relay has not committed.
    #
    # @param world [String] The world's id.
    # @param id [String, nil] The trade's id at the relay.
    def self.cancel(world, id)
      return unless id

      MGQ_Multiplayer::Link.function('mp_trade_cancel', 'pp').call(world + "\0", id + "\0")
    rescue => e
      MGQ_MpTrade.log("cancelling failed: #{e.class}: #{e.message}")
    end

    # Reads how the last commit stands.
    #
    # @return [Hash] "trade", "state" ("sending", "waiting", "committed", "cancelled" or "failed"),
    #   and "reason" or "error" where they apply; none while there is no commit.
    def self.state
      MGQ_Multiplayer::Link.parse(MGQ_Multiplayer::Link.read('mp_trade_state', 1024))
    rescue => e
      MGQ_MpTrade.log("reading the commit failed: #{e.class}: #{e.message}")
      { "state" => "failed" }
    end

    # Tells the relay the player's game applied a trade.
    #
    # @param world [String] The world's id.
    # @param id [String] The trade's id at the relay.
    def self.done(world, id)
      MGQ_Multiplayer::Link.function('mp_trade_done', 'pp').call(world + "\0", id + "\0")
    rescue => e
      MGQ_MpTrade.log("telling the relay failed: #{e.class}: #{e.message}")
    end

    # Asks the relay for the committed trades the player's game has not applied.
    #
    # @param world [String] The world's id.
    # @return [Boolean] Whether it started.
    def self.fetch(world)
      MGQ_Multiplayer::Link.function('mp_trade_pending', 'p').call(world + "\0") == 1
    rescue => e
      MGQ_MpTrade.log("asking for trades failed: #{e.class}: #{e.message}")
      false
    end

    # Reads the relay's answer to fetch.
    #
    # @return [Array] The state ("busy", "done" or "failed") and, once done, each trade's id and
    #   both offers.
    def self.pending
      lines = MGQ_Multiplayer::Link.read('mp_trade_pending_list', PENDING_SIZE).force_encoding("UTF-8").split("\n")
      state = lines.first.to_s.sub(/\Astate=/, "")
      trades = lines.map { |line| /\Atrade=([0-9a-f]{32})\t(.*)\z/.match(line) }.compact.map { |match| [match[1], match[2]] }
      [state, trades]
    rescue => e
      MGQ_MpTrade.log("reading the trades failed: #{e.class}: #{e.message}")
      ["failed", []]
    end
  end

  # What trades offer between two players, through ui_actions.rbx: their choices on the action
  # wheel and in the World overview, and offers in the overview and the notification box.
  module Offers
    # The choice wherever trades cannot run.
    UNAVAILABLE = MGQ_MpActions::Option.new("Trade", nil, "Trades need the mod's DLL, which is missing or out of date.")

    # The wheel's trade choice: accepting the trade of a player nearby, else offering one to the
    # players nearby.
    #
    # @return [MGQ_MpActions::Option] The choice.
    def self.wheel_option
      trade = MGQ_MpTrade
      return UNAVAILABLE unless trade.available?

      option = MGQ_MpActions::Option
      near = MGQ_MpOverworldSync::Peers.all.select { |peer| trade.same_map?(peer) && MGQ_MpCoop::Party.near?(peer.state) }
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
      return UNAVAILABLE unless trade.available?

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

    # Names what the player is doing for the line above their own head.
    #
    # @return [String, nil] That they offer a trade, nil while they do not.
    def self.own_doing
      MGQ_MpTrade.inviting? ? "Offering a trade" : nil
    end
  end
end

# What trades take part in of the world's messages, through overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.route("trade") { |peer, message| MGQ_MpTrade.take(peer, message) }
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpTrade.tick(in_world) }
  MGQ_MpOverworldSync.state_fields { MGQ_MpTrade.state_fields }
  MGQ_MpOverworldSync.label_line { |peer| MGQ_MpTrade.label_line(peer) }
rescue => e
  MGQ_MpTrade.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

# What trades add to the action wheel, the World overview and the notification box, through
# ui_actions.rbx.

begin
  MGQ_MpActions.offer(MGQ_MpTrade::Offers)
  MGQ_MpActions.wheel_choice(30) { MGQ_MpTrade::Offers.wheel_option }
  MGQ_MpActions.own_doing_from { MGQ_MpTrade::Offers.own_doing }
rescue => e
  MGQ_MpTrade.log("actions FAILED: #{e.class}: #{e.message}")
end

# Game hooks, through core_hooks.rbx.

begin
  # After the map's update, a trade that began opens its screen.
  MGQ_MpHooks.after(Scene_Map, :update_scene, "trade") { MGQ_MpTrade.on_map unless scene_changing? }

  # The save after a trade goes where the player last saved or loaded in the world. The newest
  # translation's plugins replace load_game, which still calls load_game_without_rescue.
  MGQ_MpHooks.around(DataManager.singleton_class, :load_game_without_rescue) do |_manager, args, original|
    loaded = original.call
    MGQ_MpTrade::Saving.slot = args[0] if loaded && MGQ_MpOverworldSync.in_world?
    loaded
  end

  MGQ_MpHooks.around(DataManager.singleton_class, :save_game_without_rescue) do |_manager, args, original|
    saved = original.call
    MGQ_MpTrade::Saving.slot = args[0] if saved && MGQ_MpOverworldSync.in_world?
    saved
  end

  MGQ_MpHooks.around(DataManager.singleton_class, :setup_new_game) do |_manager, _args, original|
    MGQ_MpTrade::Saving.slot = nil
    original.call
  end
rescue => e
  MGQ_MpTrade.log("hooks FAILED: #{e.class}: #{e.message}")
end
