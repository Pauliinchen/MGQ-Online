#----------------------------------------------------------------
#  trade.rbx
#
#  Changelog:
#      Paulinchen  2026-10-07: Told the player when a trade they accepted could not open, such as from the menu
#                            - Let a world's latest autosave load again: its name is no slot a trade saves into, which raised inside the game's load
#                            - Logged where opening the screen failed and the pictures in memory
#                            - Kept the trades a save holds through MGQ_MpGame
#                            - Forgot a new game's trade save slot through a before block
#                            - Named players in the log through MGQ_MpOverworldSync.who
#                            - Named the DLL's exports alone, their signatures living in Multiplayer.rb
#                            - Logged every trade message, offer revision, confirmation, relay answer, item and gold moved, save and recovery, and why one was refused
#                            - Kept the messages about the trade for the trade screen, which the map's notices do not reach
#      Paulinchen  2026-10-06: Told the relay a trade is done only once a save holds it, and an unsaved one after the next save in the world
#                            - Noted a trade as applied before applying it, so a failure partway never applies it twice
#                            - Bumped the own offer's revision when a commit reopens, so confirming again names a new trade at the relay
#                            - Ended the trade once the other player cancels it while the relay decides, and told them when the own commit failed
#                            - Closed the trade, not reopened it, once a cancel pressed while the relay decides went through
#                            - Asked the relay again for trades to recover after a failed fetch
#                            - Offered no trades in a world made before the world list, which the relay cannot name
#                            - Let the room checks count what the player gives away in the same trade
#                            - Wrote an enchanted copy's prefix as its enchantment and list place, so each game shows it in its own language
#                            - Dropped the unused reason "left"
#                            - Named the world by its directory id to the relay, which refused every trade named by the folder id
#                            - Found a plain item through MGQ_MpGame.item
#                            - Created
#
#----------------------------------------------------------------

# Trading between two players on the same map: items, equipment, enchant stones and gold, but no
# key items. A player offers a trade like a party invite: the players nearby, or one player on the
# map picked in the World overview. Once the other accepts, both games open the trade screen
# (ui_trade.rbx), where each player puts together an offer and confirms both offers.
#
# Nothing changes hands until the relay committed the trade: both games send it the same offers,
# and the relay marks it committed in one step, so a game that drops halfway can never keep both
# sides. Each game then notes the trade in the save, applies it, saves, and tells the relay it is
# done once the save holds it. A game that missed the commit or the save, by a crash, a lost
# connection or a save that failed, applies it the next time it enters the world.
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

  # Frames a message about the trade stays on the trade screen, four seconds.
  NOTE_FRAMES = 240

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
    "relay" => "could not reach the relay",
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
  # @!attribute leaving [String, nil] The notice the trade closes with once the relay cancelled the
  #   commit, set when a player cancelled while the relay decided; nil while nobody did.
  Session = Struct.new(:id, :partner, :name, :mine, :theirs, :their_text, :my_rev, :their_rev, :confirmed,
                       :their_confirm, :stage, :away, :relay_id, :leaving) do
    # Reports whether the other player confirmed the offers as they stand now.
    #
    # @return [Boolean] Whether they did.
    def their_confirmed?
      their_confirm == [their_rev, my_rev]
    end

    # Reports whether both players confirmed the offers as they stand now.
    #
    # @return [Boolean] Whether they did.
    def agreed?
      confirmed && their_confirmed?
    end
  end

  @invite = MGQ_MpCoop::Invite.new
  @accepted = nil
  @session = nil
  @open_screen = false
  @poll = 0
  @note = nil

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
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
    same_map?(peer) && MGQ_MpCoop::Invite.reaches_me?(peer.state, "trading", "trading_to", anywhere)
  end

  # Reports whether the player may open a trade: free on the map, with no battle of their own, no
  # story holding them and no other trade.
  #
  # @return [Boolean] Whether they may.
  def self.free?
    busy_reason.nil?
  end

  # Tells why the player may not open a trade now, see free?.
  #
  # @return [String, nil] The reason, nil while they may.
  def self.busy_reason
    return "the map is not free" unless MGQ_MpOverworldSync.map_free?
    return "already in trade #{short(@session.id)}" if @session
    return "held by the story" if MGQ_MpHooks.player_held?
    return "in a battle (#{MGQ_MpBattlesSync.role})" if defined?(MGQ_MpBattlesSync) && !MGQ_MpBattlesSync.role.nil?
    return "in a battle" if defined?(MGQ_MpBattles) && MGQ_MpBattles.running?

    nil
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

  # Logs a trade message sent or received, summarized: its kind, the player, the trade and the
  # fields besides those, and the size of its body.
  #
  # @param verb [String] "sent" or "got".
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  # @param fields [Hash] The message's fields.
  # @param body [String] What follows the fields.
  def self.log_message(verb, peer, fields, body = "")
    rest = fields.reject { |key, _| key == "trade" || key == "tid" || key == :payload }.map { |key, value| "#{key}=#{value}" }
    rest << "#{body.to_s.bytesize} bytes" unless body.to_s.empty?
    trade = fields["tid"] ? ", trade #{short(fields['tid'])}" : ""
    log("#{verb} #{fields['trade']} #{verb == 'sent' ? 'to' : 'from'} #{MGQ_MpOverworldSync.who(peer)}#{trade}#{rest.empty? ? '' : ': ' + rest.join(', ')}")
  rescue => e
    log("logging a trade message failed: #{e.class}: #{e.message}")
  end

  # Sends a trade message to another player and logs it.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  # @param fields [Hash] The message's fields.
  # @param body [String] What follows the fields.
  def self.send_message(peer, fields, body = "")
    MGQ_MpOverworldSync.tell(peer.seat, fields, body)
    log_message("sent", peer, fields, body)
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

  # Forgets every offer and trade, as when the world closes. A trade the relay is deciding is
  # recovered the next time the world opens.
  def self.reset
    log("left the world: dropped trade #{short(@session.id)} with #{@session.name} (#{@session.stage})") if @session
    log("left the world: stopped waiting for #{@accepted[:name]} to open the trade") if @accepted
    stop
    @accepted = nil
    @session = nil
    @open_screen = false
    @note = nil
    Saving.slot = nil
    Recovery.reset
  end

  # Tells a message about the trade: as a notice, and on the trade screen, which the notices on the
  # map do not reach, for NOTE_FRAMES.
  #
  # @param text [String] The message.
  # @return [nil] Nothing.
  def self.say(text)
    @note = [text, NOTE_FRAMES]
    MGQ_MpOverworldSync.notice(text)
    nil
  end

  # The message about the trade the trade screen shows now.
  #
  # @return [String, nil] The message, nil once it ran out.
  def self.note
    @note && @note[0]
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

    log("the trade offer ran out") if @invite.count_down
    @note = nil if @note && (@note[1] -= 1) <= 0
    if @accepted && (@accepted[:frames] += 1) > ANSWER_FRAMES
      log("#{@accepted[:name]} did not open the trade within #{ANSWER_FRAMES / 60} s, stopped waiting")
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
      away = session.away
      session.away = peer && !peer.away ? 0 : session.away + 1
      log("#{session.name} is away, waiting up to #{AWAY_FRAMES / 60} s") if away == 0 && session.away > 0
      log("#{session.name} is back after #{away} frames") if away > 0 && session.away == 0
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
    return log("not sent #{kind}: #{@session ? @session.name + ' is not in the world' : 'there is no trade'}") unless peer && @session

    send_message(peer, { "trade" => kind, "tid" => @session.id }.merge(fields), body)
  end

  # Accepts another player's trade offer: tells them, and waits for their game to open the trade.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player who offered it.
  def self.accept(peer)
    busy = busy_reason
    if busy
      log("not accepting #{peer.state['name']}'s trade: #{busy}")
      return MGQ_MpOverworldSync.notice("Finish what you are doing first.")
    end

    send_message(peer, { "trade" => "accept" })
    @accepted = { :id => peer.state["id"].to_s, :name => peer.state["name"].to_s, :frames => 0 }
    log("accepted #{peer.state['name']}'s trade, waiting up to #{ANSWER_FRAMES / 60} s for their game to open it")
    MGQ_MpOverworldSync.notice("You accepted #{peer.state['name']}'s trade.")
  end

  # Turns another player down, telling them why.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  # @param reason [String] A key of REASONS.
  # @param id [String, nil] The trade's id, for a trade that was opened.
  # @param why [String, nil] What led to it, for the log.
  # @return [nil] Nothing.
  def self.decline(peer, reason, id = nil, why = nil)
    fields = { "trade" => "decline", "reason" => reason }
    fields["tid"] = id if id
    send_message(peer, fields)
    log("declined #{peer.state['name']}: #{reason}#{why ? " (#{why})" : ''}")
    nil
  end

  # Takes a trade message. Called by overworld_sync.rbx.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it.
  # @param message [Hash] The message's fields, its body under :payload.
  def self.take(peer, message)
    return log_once([:no_peer, message["trade"]], "ignored a trade #{message['trade']} from a seat with no player") unless peer

    log_message("got", peer, message, message[:payload].to_s)
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
    stray = if session.nil? then "there is no trade"
            elsif session.id != message["tid"].to_s then "it names trade #{short(message['tid'])}, not #{short(session.id)}"
            elsif session.partner != peer.state["id"].to_s then "#{peer.state['name']} is not the other player of the trade"
            end
    return log("ignored #{peer.state['name']}'s trade #{message['trade']}: #{stray}") if stray

    case message["trade"]
    when "offer" then take_offer(session, message["rev"].to_i, message[:payload].to_s)
    when "confirm" then take_confirm(session, message["mine"].to_i, message["yours"].to_i)
    when "unconfirm" then take_unconfirm(session)
    when "cancel" then take_cancel(session, message["reason"].to_s)
    else log("ignored #{peer.state['name']}'s trade #{message['trade']}: unknown kind")
    end
  end

  # As the player who offered the trade, opens it with the player who accepted.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player who accepted.
  def self.take_accept(peer)
    unless @invite.covers?(peer.state) && same_map?(peer)
      return decline(peer, "gone", nil, inviting? ? "the offer does not reach them or they are not on the map" : "no trade offered")
    end
    busy = busy_reason
    return decline(peer, "busy", nil, busy) if busy

    stop
    id = Array.new(24) { rand(16).to_s(16) }.join
    send_message(peer, { "trade" => "open", "tid" => id })
    begin_session(id, peer)
  end

  # As the player who accepted, opens the trade the other player opened.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player who offered it.
  # @param id [String] The trade's id.
  def self.take_open(peer, id)
    unless @accepted && @accepted[:id] == peer.state["id"].to_s
      log("refused trade #{short(id)} from #{peer.state['name']}: the player accepted no trade of theirs")
      return send_message(peer, { "trade" => "cancel", "tid" => id, "reason" => "busy" })
    end

    @accepted = nil
    busy = id =~ /\A[0-9a-f]{24}\z/ ? busy_reason : "the trade id is not valid"
    if busy
      # The player accepted it, so they wait for the screen, such as one who opened the menu meanwhile.
      MGQ_MpOverworldSync.notice("The trade with #{peer.state['name']} could not open: finish what you are doing first.")
      return decline(peer, "busy", id, busy)
    end

    begin_session(id, peer)
  end

  # Starts a trade and has the map open its screen.
  #
  # @param id [String] The trade's id.
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  def self.begin_session(id, peer)
    @session = Session.new(id, peer.state["id"].to_s, peer.state["name"].to_s, Offer.new(0, []), Offer.new(0, []), "",
                           0, 0, false, nil, :open, 0, nil, nil)
    @open_screen = true
    log("trade #{short(id)} opened with #{@session.name} (seat #{peer.seat})")
  end

  # Tells why the other player could not trade.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  # @param reason [String] A key of REASONS.
  # @param id [String, nil] The trade's id, for a trade that was opened.
  def self.take_decline(peer, reason, id)
    @accepted = nil if @accepted && @accepted[:id] == peer.state["id"].to_s
    @invite.drop(peer.state["id"]) if reason == "no"
    log("#{peer.state['name']} #{REASONS.fetch(reason, 'cannot trade now')} (#{reason}#{id ? ", trade #{short(id)}" : ''})")
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
    return log("ignored #{session.name}'s offer revision #{rev}: revision #{session.their_rev} is newer") if rev <= session.their_rev

    abandon_commit(session, "#{session.name} changed their offer")
    session.their_rev = rev
    session.their_text = text
    session.theirs = Items.read_offer(text)
    session.their_confirm = nil
    session.confirmed = false
    log("#{session.name}'s offer r#{rev}: #{Items.summary(session.theirs)}; both confirmations taken back")
  end

  # Takes the other player's confirmation, and commits once both confirmed the same offers.
  #
  # @param session [Session] The trade.
  # @param mine [Integer] The revision of their own offer they confirmed.
  # @param yours [Integer] The revision of the player's offer they confirmed.
  def self.take_confirm(session, mine, yours)
    session.their_confirm = [mine, yours]
    current = session.their_confirmed? ? "the offers as they stand" : "older offers (now their r#{session.their_rev}, mine r#{session.my_rev})"
    waiting = session.stage != :open ? ", the trade is #{session.stage}" : session.confirmed ? "" : ", waiting for my confirmation"
    log("#{session.name} confirmed their r#{mine} and my r#{yours}: #{current}#{waiting}")
    commit(session) if session.stage == :open && session.agreed?
  end

  # Takes back the other player's confirmation, and a commit the relay has not decided, which the
  # other game never sends now.
  #
  # @param session [Session] The trade.
  def self.take_unconfirm(session)
    session.their_confirm = nil
    log("#{session.name} took back their confirmation")
    abandon_commit(session, "#{session.name} took back their confirmation")
  end

  # Ends the trade the other player cancelled: at once while it is open, through the relay while it
  # decides, which still completes a trade both games committed already.
  #
  # @param session [Session] The trade.
  # @param reason [String] A key of REASONS.
  def self.take_cancel(session, reason)
    text = "#{session.name} #{REASONS.fetch(reason, 'cancelled the trade')}."
    return close(text) unless session.stage == :committing

    log("#{session.name} cancelled (#{reason}) while the relay decides, waiting for its answer")
    session.leaving ||= text
    abandon_commit(session, "#{session.name} cancelled")
  end

  # Changes how many of an item the player offers.
  #
  # @param item [RPG::BaseItem] The item.
  # @param amount [Integer] How many, 0 to take it out of the offer; at most what the bag holds.
  def self.set_amount(item, amount)
    session = @session
    return unless session && session.stage == :open
    return log("not offering #{Items.label(item)}: it may not be traded") unless Items.tradeable?(item)

    token = Items.token(item)
    wanted = amount
    amount = [[amount, 0].max, Items.held(item), Items.unique?(item) ? 1 : MAX_AMOUNT].min
    log("offering #{amount}, not #{wanted}, of #{Items.label(item)}: the bag holds #{Items.held(item)}, a trade moves at most #{Items.unique?(item) ? 1 : MAX_AMOUNT}") if amount != wanted && wanted > 0
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

  # Tells the other player the player's new offer, which takes back both confirmations.
  #
  # @param session [Session] The trade.
  def self.offer_changed(session)
    session.my_rev += 1
    session.confirmed = false
    session.their_confirm = nil
    log("my offer r#{session.my_rev}: #{Items.summary(session.mine)}; both confirmations taken back")
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

    Items.receive_refusal(session.theirs, session.name, session.mine)
  end

  # Confirms both offers as they stand, or takes the confirmation back. The trade goes to the relay
  # once both players confirmed the same offers.
  def self.toggle_confirm
    session = @session
    return unless session && session.stage == :open

    if session.confirmed
      session.confirmed = false
      log("took back my confirmation")
      return tell("unconfirm")
    end

    refusal = confirm_refusal
    if refusal
      log("not confirming: #{refusal}")
      return say(refusal)
    end

    session.confirmed = true
    log("confirmed my r#{session.my_rev} and #{session.name}'s r#{session.their_rev}#{session.their_confirmed? ? ', as they did' : ', waiting for them'}")
    tell("confirm", { "mine" => session.my_rev, "yours" => session.their_rev })
    commit(session) if session.agreed?
  end

  # Cancels the trade: at once while it is open, through the relay while it decides, which still
  # completes a trade both games committed already.
  def self.cancel
    session = @session
    return unless session
    return log("cancel pressed again, still waiting for the relay") if session.leaving

    log("cancelling trade #{short(session.id)}#{session.stage == :committing ? ' while the relay decides, waiting for its answer' : ''}")
    tell("cancel", { "reason" => "off" })
    return close("You cancelled the trade.") unless session.stage == :committing

    session.leaving = "You cancelled the trade."
    abandon_commit(session, "the player cancelled")
  end

  # Ends the trade, with a notice, and closes its screen.
  #
  # @param text [String] The notice.
  def self.close(text)
    log("trade #{short(@session && @session.id)} closed: #{text}")
    @session.stage = :closed if @session
    @session = nil
    @open_screen = false
    @note = nil
    MGQ_MpOverworldSync.notice(text)
  end

  # The open world's id in the directory, by which the relay knows the world's players. The world's
  # folder id is another, which the relay never sees.
  #
  # @return [String] The id, "" while none is open or for a world made before the directory.
  def self.world_id
    MGQ_MpOverworldSync.in_world? ? MGQ_MpWorld.world.directory_id.to_s : ""
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
    revisions = "my r#{session.my_rev}, their r#{session.their_rev}"
    unless Relay.commit(world_id, session.relay_id, session.partner, agreed_text(session))
      log("trade #{short(session.id)} (#{revisions}) could not be handed to the relay, my confirmation taken back")
      session.confirmed = false
      tell("unconfirm")
      return say("The trade could not reach the relay.")
    end

    session.stage = :committing
    @poll = 0
    @relay_seen = nil
    log("both confirmed, trade #{short(session.id)} (#{revisions}) sent to the relay: I give #{Items.summary(session.mine)}; I get #{Items.summary(session.theirs)}")
  end

  # Takes back a commit the relay has not decided, as when the other player changed their offer.
  #
  # @param session [Session] The trade.
  # @param why [String] What took it back, for the log.
  def self.abandon_commit(session, why)
    return unless session.stage == :committing

    log("asking the relay to cancel the commit of trade #{short(session.id)}: #{why}")
    Relay.cancel(world_id, session.relay_id)
  end

  # Follows the relay's answer to the commit.
  #
  # @param session [Session] The trade.
  def self.tick_commit(session)
    return if (@poll += 1) < POLL_FRAMES

    @poll = 0
    state = Relay.state
    log_relay_state(state, session)
    return unless state["trade"] == session.relay_id

    case state["state"]
    when "committed" then complete(session)
    when "cancelled"
      return close(session.leaving) if session.leaving

      reopen(session, RELAY_REASONS.fetch(state["reason"].to_s, "The trade was cancelled."))
    when "failed" then give_up(session)
    end
  end

  # Logs how the relay's commit stands, once each time it changes.
  #
  # @param state [Hash] What Relay.state read.
  # @param session [Session] The trade.
  def self.log_relay_state(state, session)
    seen = [state["trade"], state["state"], state["reason"], state["error"]]
    return if seen == @relay_seen

    @relay_seen = seen
    which = state["trade"].to_s.empty? ? "no trade" : "trade #{short(state['trade'])}"
    other = state["trade"] == session.relay_id ? "" : " (not this commit yet)"
    extra = [state["reason"] && "reason #{state['reason']}", state["error"] && "error #{state['error'].to_s[0, 160]}"].compact
    log("relay: #{which} #{state['state'] || 'unknown'}#{other}#{extra.empty? ? '' : ', ' + extra.join(', ')}")
  rescue => e
    log("logging the relay's answer failed: #{e.class}: #{e.message}")
  end

  # Ends a trade whose commit failed: cancels it at the relay, so the other game cannot commit it
  # alone later, tells the other player and asks the relay again for trades to recover.
  #
  # @param session [Session] The trade.
  def self.give_up(session)
    log("the commit of trade #{short(session.id)} failed, cancelling it at the relay and asking again for trades to recover")
    Relay.cancel(world_id, session.relay_id)
    tell("cancel", { "reason" => "relay" })
    Recovery.check_again
    close("The trade could not reach the relay. If it went through, it completes the next time you enter the world.")
  end

  # Opens the trade again after the relay turned the commit down, with both confirmations taken
  # back. The player's offer is told again under a new revision, since confirming the same
  # revisions again would name the trade the relay cancelled.
  #
  # @param session [Session] The trade.
  # @param text [String] Why, as a notice.
  def self.reopen(session, text)
    log("trade #{short(session.id)} reopened: #{text}")
    session.stage = :open
    session.relay_id = nil
    offer_changed(session)
    say(text)
  end

  # Completes the trade the relay committed: applies it once, saves, and tells the relay once the
  # save holds it.
  #
  # @param session [Session] The trade.
  def self.complete(session)
    log("the relay committed trade #{short(session.id)} with #{session.name}, applying it")
    session.stage = :closed
    id = session.relay_id
    unless Recovery.apply_once(id, session.mine, session.theirs)
      return close("The trade with #{session.name} could not be applied in full, see Multiplayer InGame.log.")
    end

    saved = Recovery.finish
    close(saved ? "Trade with #{session.name} complete, game saved." : "Trade with #{session.name} complete. Save your game, the trade could not.")
  end

  # Opens the trade screen from the map once a trade began. Called by the map every frame.
  def self.on_map
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

    # The lists of an enchantment a rolled name prefix comes from, by the letter that names them.
    PREFIX_LISTS = { "r" => :rare_prefix, "p" => :prefix }

    # Writes an item as text, the same in both games: i, w or a and its id for an item of the
    # database, u and its text from MGQ_MpActors::Items for an enchanted or socketed copy, with the
    # copy's name prefix after a tilde, see prefix_ref.
    #
    # @param item [RPG::BaseItem] The item.
    # @return [String] The text.
    def self.token(item)
      return "u#{MGQ_MpActors::Items.write(item)}~#{prefix_ref(item)}" if unique?(item)

      ref(item)
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
    # @return [String] The name, "" for no prefix or one no enchantment of the copy lists.
    def self.prefix_ref(item)
      prefix = item.respond_to?(:enchant_item?) && item.enchant_item? ? MGQ_MpGame.get(item, :prefix).to_s : ""
      return "" if prefix.empty?

      Array(MGQ_MpGame.get(item, :enchants)).each do |id|
        enchant = $data_classes[id.to_i]
        PREFIX_LISTS.each do |letter, list|
          place = enchant.respond_to?(list) ? Array(enchant.send(list)).index(prefix) : nil
          return "#{id.to_i}#{letter}#{place}" if place
        end
      end
      ""
    end

    # Reads a name prefix from this game's data, see prefix_ref.
    #
    # @param ref [String] Where the prefix comes from.
    # @return [String] The prefix, "" for none or one this game's data lacks.
    def self.prefix_from(ref)
      match = /\A(\d{1,6})([rp])(\d{1,3})\z/.match(ref)
      enchant = match && $data_classes[match[1].to_i]
      list = match && PREFIX_LISTS[match[2]]
      return "" unless enchant && enchant.respond_to?(list)

      Array(enchant.send(list))[match[3].to_i].to_s
    end

    # Makes an item from its text: the database's item, or a new copy of an enchanted or socketed one.
    #
    # @param token [String] The text, see token.
    # @return [RPG::BaseItem, nil] The item, nil when this game's data lacks it.
    def self.item_of(token)
      if (match = /\Au([^~]*)~([0-9rp]*)\z/.match(token))
        item = MGQ_MpActors::Items.read(match[1])
        return nil unless item && unique?(item)

        MGQ_MpGame.set(item, :prefix, prefix_from(match[2])) if item.enchant_item?
        return item
      end

      match = /\A([iwa])(\d{1,6})\z/.match(token)
      return nil unless match

      MGQ_MpGame.item(match[1], match[2].to_i)
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

    # Tells why the player's game cannot take an offer, counting what the player gives away in the
    # same trade, which leaves the bag first.
    #
    # @param offer [Offer] The other player's offer.
    # @param name [String] The other player's name.
    # @param mine [Offer] The player's own offer.
    # @return [String, nil] The reason, nil while it can.
    def self.receive_refusal(offer, name, mine = Offer.new(0, []))
      return "#{name}'s offer holds items your game does not know." if offer.entries.any? { |entry| entry.item.nil? }
      return "#{name}'s offer holds key items." if offer.entries.any? { |entry| !tradeable?(entry.item) }
      return "#{name}'s offer is not valid." if offer.entries.any? { |entry| entry.amount < 1 || entry.amount > (unique?(entry.item) ? 1 : MAX_AMOUNT) }
      return "You cannot carry that much gold." if $game_party.gold - mine.gold.to_i + offer.gold.to_i > $game_party.max_gold

      full = offer.entries.find { |entry| !unique?(entry.item) && held(entry.item) - given(mine, entry.token) + entry.amount > MAX_AMOUNT }
      return "You cannot carry more #{full.item.name}." if full

      copies = offer.entries.select { |entry| unique?(entry.item) }.group_by { |entry| entry.item.class }
      crowded = copies.find { |kind, entries| room_for_copies(entries.first.item) + copies_given(mine, kind) < entries.size }
      crowded ? "You cannot carry more equipment like #{crowded[1].first.item.name}." : nil
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
      if entry.token.start_with?("u")
        copy = bag.find { |item| unique?(item) && token(item) == entry.token }
        return MGQ_MpTrade.log("gave nothing for #{label(entry.item)}: the copy is no longer in the bag") unless copy

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
      item = entry.token.start_with?("u") ? item_of(entry.token) : entry.item
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
    # An autosave's index is its name, such as "01", and no slot a trade saves into, so loading one
    # forgets the slot; the first free one takes its place. Adding one to the name raised inside
    # the game's load, which then failed the whole load of a world's latest autosave.
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
  # connection, or a save loaded from before the trade. Each is noted in the save, applied once per
  # save, and saved; the relay hears that it is done only once a save holds it.
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
        Relay.done(MGQ_MpTrade.world_id, id)
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

    # Has the relay asked again on the next frame on the map.
    def self.check_again
      MGQ_MpTrade.log("will ask the relay again for trades to recover")
      @checked = nil
    end

    # Forgets what was asked and what is unsaved, as when the world closes; a fetch running still
    # ends in the DLL, and the relay keeps the unsaved trades for the next time.
    def self.reset
      @checked = nil
      @fetching = false
      @wait = 0
      @unsaved = []
    end

    # Asks the relay once per save loaded in the world, from the map, and applies what it answers.
    # Called every frame in every scene.
    def self.tick
      return poll if @fetching
      return unless SceneManager.scene.is_a?(Scene_Map) && MGQ_MpTrade.session.nil?
      return log_unavailable unless MGQ_MpTrade.available?

      key = [MGQ_MpTrade.world_id, $game_system.object_id]
      return if @checked == key
      return if (@wait = @wait.to_i - 1) > 0

      @fetching = Relay.fetch(MGQ_MpTrade.world_id)
      if @fetching
        MGQ_MpTrade.log("asking the relay for trades to recover in world #{MGQ_MpTrade.short(key[0])}")
        @checked = key
      else
        MGQ_MpTrade.log_once([:fetch_later, key], "could not ask the relay for trades to recover yet, trying every #{RETRY_FRAMES / 60} s")
        @wait = RETRY_FRAMES
      end
    end

    # Logs once why trades cannot run in the open world, so none are recovered.
    def self.log_unavailable
      ready = MGQ_MpTrade.dll_ready?
      MGQ_MpTrade.log_once([:unavailable, ready], ready ? "no trades: this world was made before the world list" : "no trades: the mod's DLL is missing or out of date")
    end

    # Takes the relay's answer once it came, and asks again later when it failed.
    def self.poll
      state, trades = Relay.pending
      return if state == "busy"

      @fetching = false
      unless state == "done"
        @checked = nil
        @wait = RETRY_FRAMES
        return MGQ_MpTrade.log("asking for trades to recover failed (#{state}), asking again in #{RETRY_FRAMES / 60} s")
      end

      MGQ_MpTrade.log("the relay lists #{trades.size} trade(s) to recover#{trades.empty? ? '' : ': ' + trades.map { |id, _| MGQ_MpTrade.short(id) }.join(', ')}")
      trades.each { |id, text| recover(id, text) }
    end

    # Applies a trade the relay committed, unless the save has it, and saves; the relay hears of a
    # trade the save holds.
    #
    # @param id [String] The trade's id at the relay.
    # @param text [String] Both offers, see MGQ_MpTrade.agreed_text.
    def self.recover(id, text)
      if applied?(id)
        if unsaved.include?(id)
          MGQ_MpTrade.log("recovery skipped trade #{MGQ_MpTrade.short(id)}: applied, waiting for a save that holds it")
        else
          MGQ_MpTrade.log("recovery skipped trade #{MGQ_MpTrade.short(id)}: the save holds it, telling the relay it is done")
          Relay.done(MGQ_MpTrade.world_id, id)
        end
        return
      end

      sides = Hash[text.split("|").map { |side| side.split("=", 2) }]
      me = MGQ_MpOverworldSync::Me.id.to_s
      partner = (sides.keys - [me]).first
      return MGQ_MpTrade.log("recovery skipped trade #{MGQ_MpTrade.short(id)}: it does not name this player") unless sides.key?(me) && partner
      MGQ_MpTrade.log("recovering trade #{MGQ_MpTrade.short(id)} with #{MGQ_MpTrade.name_of(partner)}")
      applied = apply_once(id, Items.read_offer(sides[me]), Items.read_offer(sides[partner]))
      return MGQ_MpOverworldSync.notice("A trade that was cut off could not be applied in full, see Multiplayer InGame.log.") unless applied

      saved = finish
      MGQ_MpOverworldSync.notice(saved ? "A trade that was cut off completed, game saved." : "A trade that was cut off completed. Save your game.")
      MGQ_MpTrade.log("recovered trade #{MGQ_MpTrade.short(id)}#{saved ? ', game saved' : ', not saved yet'}")
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
      MGQ_Multiplayer::Link.function('mp_trade_commit').call(world + "\0", id + "\0", partner + "\0", text + "\0") == 1
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

      MGQ_Multiplayer::Link.function('mp_trade_cancel').call(world + "\0", id + "\0")
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
      MGQ_MpTrade.log_once([:state_failed, e.class], "reading the commit failed: #{e.class}: #{e.message}")
      { "state" => "failed" }
    end

    # Tells the relay the player's game applied a trade.
    #
    # @param world [String] The world's id.
    # @param id [String] The trade's id at the relay.
    def self.done(world, id)
      MGQ_Multiplayer::Link.function('mp_trade_done').call(world + "\0", id + "\0")
    rescue => e
      MGQ_MpTrade.log("telling the relay failed: #{e.class}: #{e.message}")
    end

    # Asks the relay for the committed trades the player's game has not applied.
    #
    # @param world [String] The world's id.
    # @return [Boolean] Whether it started.
    def self.fetch(world)
      MGQ_Multiplayer::Link.function('mp_trade_pending').call(world + "\0") == 1
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
    # The choice wherever the mod's DLL cannot run trades.
    UNAVAILABLE = MGQ_MpActions::Option.new("Trade", nil, "Trades need the mod's DLL, which is missing or out of date.")

    # The choice in a world made before the world list, which the relay cannot name.
    OLD_WORLD = MGQ_MpActions::Option.new("Trade", nil, "This world was made before the world list, so it cannot trade.")

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
