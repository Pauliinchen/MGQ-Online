#----------------------------------------------------------------
#  story_found.rbx
#
#  Changelog:
#      Paulinchen  2026-11-01: Took a copy of a key item from every player who holds it when an event of another player's game used it up
#                            - Counted no loss inside a story reset as a use
#                            - Created
#
#----------------------------------------------------------------

# The items any player found reach every player as soon as anyone gets one, in every world type:
# the key items, ores and CDs among them, and the items unlocking a job or a race. Each save gets
# each of them once: it notes every such item it ever held, so a key item an event took is not given
# again, and every item it got this way, whose copy the next gain of the item stands for, so the
# replay of the run that found it, or the player's own run of the event, gives no second one.
#
# A key item an event of a player's game uses up leaves every other player who holds it too, one
# copy for each use, so a copy another player's find gave cannot open a later page that asks for the
# item, as the Yggdrasil Fruit opens Lucretia's (map 88, event 4, page 2). A use is told apart by the
# commands that made it and how often the player's game made it there, so another player's own run of
# the same event counts as the same use. A player who lacks the item loses nothing and is never
# held up, and a used up item goes to no save that never held it. A story reset, such as the return
# to the Great Decision, clears the player's own items and uses none up.
#
# A Raid World's found and used up items are its found marks (world_catchup.rbx FOUND_MAP), which
# the whole world keeps, players behind included, and its catch-up hands out and takes. A Classic
# party's are the items its members tell each other they found or used up, kept in the save; the DLL
# decides what this player gets and loses of them (FoundItems in the DLL), as the Raid World's
# catch-up does.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpStoryFound
  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "found items"

  # The DLL's topic that decides what the player gets of the items the party found, see
  # CatchupTopics.FoundTopic.
  CHECK_TOPIC = "found.check"

  # The party messages' field of the items a member found.
  FIELD = "found"

  # The party messages' field of the items an event of a member's game used up.
  USED_FIELD = "used"

  # The start of the mark of a use, the letter of its self switch in a Raid World (world_catchup.rbx
  # FOUND_MAP), which holds eight characters at most.
  USED_PREFIX = "U"

  # A use as the party messages and the save name it: the item and its mark.
  USE_FORMAT = /\A\d+\.#{USED_PREFIX}[0-9a-z]{1,7}\z/

  # The field of $game_system the save keeps the found, held and used items in: "found" (the items
  # the player's Classic parties found), "got" (every such item the save held), "given" (the items it
  # got as found whose next gain adds nothing), "used" (the uses the player's Classic parties made, as
  # "item.mark"), "spent" (the uses the save counted, its own among them) and "uses" (how often the
  # player's game used an item up at each place, by "item@place").
  LEDGER = :@mgq_mp_found

  # Frames between two looks at what the party found, a second.
  CHECK_FRAMES = 60

  # The tag at the start of the description of an item the game files with the key items but tags as
  # a plain item, in the translation and the untranslated game: the Small and Large Medals, which stay
  # each player's own.
  PLAIN_ITEM_TAG = /\A\s*(\[Item\]|【道具】)/

  # The frame of the last look.
  @checked_at = 0

  # The ids of the party's members at the last look, which tell a member who joined since.
  @members = nil

  # Reports whether an item is one that reaches every player: a key item the game does not tag as a
  # plain item (PLAIN_ITEM_TAG), or an item unlocking a job or a race.
  #
  # @param item [RPG::BaseItem, nil] The item.
  # @return [Boolean] Whether it is.
  def self.found_item?(item)
    return false unless item.is_a?(RPG::Item)

    (item.key_item? && item.description.to_s !~ PLAIN_ITEM_TAG) || (defined?(MGQ_MpWorldCatchup) && MGQ_MpWorldCatchup.unlock_item?(item)) ? true : false
  end

  # Lists the items of the game that reach every player, see found_item?.
  #
  # @return [Array<Integer>] The items.
  def self.item_ids
    @item_ids ||= ($data_items || []).select { |item| found_item?(item) }.map { |item| item.id }
  end

  # Reads the save's notes.
  #
  # @return [Hash] "found", "got", "given", "used" and "spent", each a list, and "uses", see LEDGER.
  def self.ledger
    notes = $game_system.instance_variable_get(LEDGER)
    unless notes.is_a?(Hash)
      notes = {}
      $game_system.instance_variable_set(LEDGER, notes)
    end
    %w(found got given used spent).each { |list| notes[list] ||= [] }
    notes["uses"] ||= {}
    notes
  end

  # Lists every item that reaches every player the save held.
  #
  # @return [Array<Integer>] The items.
  def self.got
    $game_system ? ledger["got"] : []
  end

  # Keeps every item that reaches every player the save held, as the DLL answers it.
  #
  # @param ids [Array<Integer>] The items.
  def self.got=(ids)
    ledger["got"] = Array(ids).map { |id| id.to_i } if $game_system
  end

  # Lists every use of an item the save counted.
  #
  # @return [Array<String>] The uses, as "item.mark".
  def self.spent
    $game_system ? ledger["spent"] : []
  end

  # Notes the items the player got as found, whose next gain adds nothing.
  #
  # @param ids [Array<Integer>] The items.
  def self.given=(ids)
    add(ledger["given"], Array(ids).map { |id| id.to_i }) if $game_system
  end

  # Reports whether the player got an item as found and gained none of it since.
  #
  # @param item [Object] The item, or another thing a gain changes such as :gold.
  # @return [Boolean] Whether they did.
  def self.given?(item)
    item.is_a?(RPG::Item) && $game_system && ledger["given"].include?(item.id) ? true : false
  end

  # Lets the copy the player got as found stand for one copy of a gain of the item.
  #
  # @param item [RPG::Item] The item.
  # @return [Integer] 1 for a copy got as found, else 0.
  def self.take_given(item)
    return 0 unless given?(item)

    ledger["given"].delete(item.id)
    log("#{item.name} counts as the one the party found: no second copy")
    1
  end

  # Tells how many copies of a gain of an item the party gets: one less while the player got the item
  # as found, outside a replay, which counts that copy itself (story_replay.rbx).
  #
  # @param item [RPG::BaseItem, nil] The item.
  # @param amount [Integer] How many the gain gives.
  # @return [Integer] How many to give.
  def self.new_copies(item, amount)
    return amount unless amount.to_i > 0 && !MGQ_MpStoryReplay.running?
    return amount if defined?(MGQ_MpCoopStory) && MGQ_MpCoopStory.lending?

    amount - take_given(item)
  rescue => e
    log_once(:new_copies, "counting a found item's copies failed: #{e.class}: #{e.message}")
    amount
  end

  # Notes an item the player gained: the save held it, and in a Classic party the party found it.
  # A replay's gain counts once the replay kept it, at the next look.
  #
  # @param item [RPG::BaseItem, nil] The item.
  # @param amount [Integer] How many.
  def self.gained(item, amount)
    return unless amount.to_i > 0 && $game_system && found_item?(item) && !MGQ_MpStoryReplay.running?
    return if defined?(MGQ_MpCoopStory) && MGQ_MpCoopStory.lending?

    add(ledger["got"], [item.id])
    tell_found([item.id]) if classic_party? && !add(ledger["found"], [item.id]).empty?
  rescue => e
    log_once(:gained, "noting a found item failed: #{e.class}: #{e.message}")
  end

  # Lets a change of what the party holds happen, and counts a loss of a key item an event of the
  # player's own game makes as a use of it (see used).
  #
  # @param item [RPG::BaseItem, nil] The item.
  # @param amount [Integer] The change, below 0 for a loss.
  # @yield The change.
  # @return [Object] What the change returns.
  def self.losing(item, amount)
    place = use_place(item, amount)
    return yield unless place

    before = held(item)
    result = yield
    used(item, place) if held(item) < before
    result
  end

  # Names where an event of the player's own game takes a key item: never a replay, a story reset,
  # nor what the multiplayer takes or lends itself.
  #
  # @param item [RPG::BaseItem, nil] The item.
  # @param amount [Integer] The change, below 0 for a loss.
  # @return [String, nil] The commands running, see MGQ_MpStoryKeys.command_places; nil for no use.
  def self.use_place(item, amount)
    return nil unless amount.to_i < 0 && $game_system && !@taking && found_item?(item) && !MGQ_MpStoryReplay.running?
    return nil if (defined?(MGQ_MpCoopStory) && MGQ_MpCoopStory.lending?) || MGQ_MpStoryKeys.applying?

    places = MGQ_MpStoryKeys.command_places
    return places unless places && MGQ_MpStoryKeys.resetting?

    log("a story reset took #{item.name} at #{places}: no use, every other player keeps theirs")
    nil
  rescue => e
    log_once(:use_place, "telling a used item failed: #{e.class}: #{e.message}")
    nil
  end

  # Notes a use of a key item by an event of the player's own game, counted for the save at once:
  # the party hears it, and a Raid World keeps it as a found mark (MGQ_MpWorldCatchup.used).
  #
  # @param item [RPG::Item] The item.
  # @param place [String] The commands that took it.
  def self.used(item, place)
    uses = ledger["uses"]
    at = "#{item.id}@#{place}"
    uses[at] = uses[at].to_i + 1
    mark = "#{USED_PREFIX}#{Zlib.crc32("#{place}##{uses[at]}").to_s(36)}"
    use = "#{item.id}.#{mark}"
    add(ledger["spent"], [use])
    told = add(ledger["used"], [use])
    log("an event used up #{item.name} at #{place}: every other player who holds it loses one")
    tell_used(told) if classic_party?
    MGQ_MpWorldCatchup.used(item, mark) if defined?(MGQ_MpWorldCatchup)
  rescue => e
    log_once(:used, "noting a used item failed: #{e.class}: #{e.message}")
  end

  # Takes the items a member of the Classic party found. Called by coop.rbx.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @param message [Hash] The message: "ids", comma separated.
  def self.take(peer, message)
    return unless classic_party? && $game_system

    ids = message["ids"].to_s.split(",").map { |id| id.to_i }.select { |id| id > 0 }
    added = add(ledger["found"], ids)
    log("#{MGQ_MpOverworldSync.who(peer)} found #{added.size} items new to the player") unless added.empty?
    @finder = peer.state["name"].to_s unless added.empty?
    @checked_at = -CHECK_FRAMES
  rescue => e
    log("taking found items failed: #{e.class}: #{e.message}")
  end

  # Takes the uses of items an event of a member of the Classic party made. Called by coop.rbx.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @param message [Hash] The message: "uses", comma separated, each "item.mark".
  def self.heard_used(peer, message)
    return unless classic_party? && $game_system

    added = add(ledger["used"], message["uses"].to_s.split(",").select { |use| use =~ USE_FORMAT })
    return if added.empty?

    log("#{MGQ_MpOverworldSync.who(peer)} used up #{added.size} items in events")
    @user = peer.state["name"].to_s
    @checked_at = -CHECK_FRAMES
  rescue => e
    log("taking used items failed: #{e.class}: #{e.message}")
  end

  # Looks at what the Classic party found and used up once a second while the player is free on the
  # map, and tells a member who joined since what the player found and used up.
  def self.update
    return @members = nil unless classic_party?
    return unless Graphics.frame_count - @checked_at >= CHECK_FRAMES || Graphics.frame_count < @checked_at
    return unless MGQ_MpStoryReplay.free?

    @checked_at = Graphics.frame_count
    check
    members = MGQ_MpCoop::Party.members.map { |peer| peer.state["id"].to_s }.sort
    if @members != members && !(members - (@members || [])).empty?
      tell_found(ledger["found"] | ledger["got"])
      tell_used(ledger["used"])
    end
    @members = members
  rescue => e
    log_once(:update, "looking at the party's found items failed: #{e.class}: #{e.message}")
  end

  # Gives the player the items the party found that the save never held, keeps one of each item
  # unlocking a job or a race, and takes a copy of each item another member's event used up, as the
  # DLL decides.
  def self.check
    found = ledger["found"]
    counts = {}
    (found | item_ids).each do |id|
      count = $data_items[id] ? held($data_items[id]) : 0
      counts[id] = count if $data_items[id] && (count > 0 || found.include?(id))
    end
    unlocks = counts.keys.select { |id| defined?(MGQ_MpWorldCatchup) && MGQ_MpWorldCatchup.unlock_item?($data_items[id]) }
    answer = MGQ_Multiplayer::Bridge.call(CHECK_TOPIC, "found" => found, "got" => ledger["got"], "held" => counts, "keeps_one" => unlocks,
                                                        "used" => ledger["used"], "spent" => ledger["spent"])
    return unless answer.is_a?(Hash)

    apply(answer)
  end

  # Carries out what the DLL decided: the copies taken back, the items given, the copies another
  # member's event used up, and what the save held and counted.
  #
  # @param answer [Hash] "give", "trim", "take", "got" and "spent".
  def self.apply(answer)
    Array(answer["trim"]).each do |id, extra|
      $game_party.lose_item($data_items[id.to_i], extra.to_i)
      log("took back #{extra} copies of #{$data_items[id.to_i].name}: one counts")
    end
    given = Array(answer["give"]).map { |id| $data_items[id.to_i] }.compact
    given.each { |item| $game_party.gain_item(item, 1) }
    self.given = given.map { |item| item.id }
    self.got = answer["got"] if answer["got"]
    taken = answer["spent"] ? lose_used(answer["take"], answer["spent"]) : []
    unless given.empty?
      names = given.map { |item| item.name.to_s }
      log("gave #{names.join(', ')}, which the party found")
      MGQ_MpOverworldSync.notice("#{@finder || 'Your party'} found #{named(names)}, and you got #{given.size > 1 ? 'them' : 'it'} too.")
    end
    MGQ_MpOverworldSync.notice("#{@user || 'Your party'} used up #{named(taken)}, and yours #{taken.size > 1 ? 'are' : 'is'} gone too.") unless taken.empty?
  end

  # Takes a copy of each item another player's event used up, whose next gain adds one again, and
  # keeps the uses the save counted, as the DLL answers them.
  #
  # @param ids [Array<Integer>] The items, an entry for each copy.
  # @param spent [Array<String>] Every use the save counted, as "item.mark".
  # @return [Array<String>] The names of the items taken, an entry for each copy.
  def self.lose_used(ids, spent)
    ledger["spent"] = Array(spent).map { |use| use.to_s }
    taken = Array(ids).map { |id| $data_items[id.to_i] }.compact
    @taking = true
    taken.each do |item|
      $game_party.lose_item(item, 1)
      ledger["given"].delete(item.id)
    end
    names = taken.map { |item| item.name.to_s }
    log("took #{names.join(', ')}, which another player's event used up") unless names.empty?
    names
  ensure
    @taking = false
  end

  # Names items for a notice: one or two by name, more by their count.
  #
  # @param names [Array<String>] The names.
  # @return [String] The text.
  def self.named(names)
    names.size > 2 ? "#{names.size} items" : names.join(' and ')
  end

  # Counts an item the party holds of its own, without what the Classic leader lent the player.
  #
  # @param item [RPG::Item] The item.
  # @return [Integer] How many.
  def self.held(item)
    lent = defined?(MGQ_MpCoopStory) ? MGQ_MpCoopStory.lent_count(item.id) : 0
    [$game_party.item_number(item) - lent, 0].max
  end

  # Tells the party items the player found.
  #
  # @param ids [Array<Integer>] The items.
  def self.tell_found(ids)
    return if ids.empty?

    sent = MGQ_MpCoop.tell(-1, FIELD, 1, "ids" => ids.join(","))
    log("#{sent ? 'told' : 'could not tell'} the party #{ids.size} found items")
  end

  # Tells the party uses of items by events of the player's game.
  #
  # @param uses [Array<String>] The uses, as "item.mark".
  def self.tell_used(uses)
    return if uses.empty?

    sent = MGQ_MpCoop.tell(-1, USED_FIELD, 1, "uses" => uses.join(","))
    log("#{sent ? 'told' : 'could not tell'} the party #{uses.size} used up items")
  end

  # Reports whether the player plays in a Classic party with someone else in it.
  #
  # @return [Boolean] Whether they do.
  def self.classic_party?
    MGQ_MpCoop.in_party? && !MGQ_MpCoop::Scope.raid?
  end

  # Adds items to a list of the notes.
  #
  # @param list [Array<Integer>] The list.
  # @param ids [Array<Integer>] The items.
  # @return [Array<Integer>] The items it did not hold yet.
  def self.add(list, ids)
    added = ids - list
    list.concat(added)
    added
  end

  # Forgets the party's members, the last finder and the last member who used an item up, as a
  # loaded save or a new game starts anew.
  def self.forget
    @members = nil
    @finder = nil
    @user = nil
  end
end

# What this script takes part in of the party's messages, through coop.rbx.

begin
  MGQ_MpCoop.route(MGQ_MpStoryFound::FIELD) { |peer, message| MGQ_MpStoryFound.take(peer, message) }
  MGQ_MpCoop.route(MGQ_MpStoryFound::USED_FIELD) { |peer, message| MGQ_MpStoryFound.heard_used(peer, message) }
rescue => e
  MGQ_MpStoryFound.log("co-op FAILED: #{e.class}: #{e.message}")
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  MGQ_MpHooks.after(Game_Map, :update, "story_found") { MGQ_MpStoryFound.update }
  MGQ_MpHooks.around(Game_Party, :gain_item, "story_found") do |_party, args, original|
    MGQ_MpStoryFound.losing(args[0], args[1]) { original.call(args[0], MGQ_MpStoryFound.new_copies(args[0], args[1]), *args[2..-1]) }
  end
  MGQ_MpHooks.after(Game_Party, :gain_item, "story_found") { |item, amount, *_| MGQ_MpStoryFound.gained(item, amount) }
  MGQ_MpHooks.after(DataManager.singleton_class, :setup_new_game, "story_found") { MGQ_MpStoryFound.forget }
  MGQ_MpHooks.after(DataManager.singleton_class, :load_game_without_rescue, "story_found") { |_index| MGQ_MpStoryFound.forget }
rescue => e
  MGQ_MpStoryFound.log("hooks FAILED: #{e.class}: #{e.message}")
end
