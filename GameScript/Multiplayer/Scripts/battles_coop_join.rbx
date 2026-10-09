#----------------------------------------------------------------
#  battles_coop_join.rbx
#
#  Changelog:
#      Paulinchen  2026-10-09: Created
#
#----------------------------------------------------------------

# Joining a battle by choice in a Raid World: while the player is free on the map and another player
# within JOIN_DISTANCE fights a battle whose host's state says it takes players in (state_fields), a
# prompt below the player's character names the hotkey that joins it (Sprite_MpJoinPrompt). Its
# press asks the battle's host (request), who takes the player in as a late guest without enemies
# (MGQ_MpBattlesHotjoin.take_in_player), so an event's battle and a boss battle take them too, or
# refuses, which the player reads in the notification box (take_refusal).
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpBattlesJoin
  # Steps another player who fights a battle may be away from the player for its prompt to show,
  # diagonal steps counted as one.
  JOIN_DISTANCE = 3

  # Seconds the player stands still waiting for the host's answer.
  ANSWER_SECONDS = 3

  # Frames the notification box shows a refusal, four seconds.
  NOTICE_FRAMES = 240

  # The notification box's key of this script's messages.
  NOTICE_KEY = :join_battle

  # What the player reads of a host's refusal, by the reason the host sends.
  REFUSALS = { "full" => "it is full", "ending" => "it is ending", "gathering" => "it still gathers its players",
               "pvp" => "it is a PvP battle", "closed" => "it takes nobody in now" }

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "join battle"

  # Reports whether a Raid World is open, whose battles players may join by choice.
  #
  # @return [Boolean] Whether one is.
  def self.raid?
    MGQ_MpCoop::Scope.raid?
  end

  # The host's side.

  # The field this script adds to the state the player's game tells the others: in a Raid World
  # "rbn", the players of the battle the player hosts or fights alone, those taken in counted, while
  # it takes players in, else 0.
  #
  # @return [Hash] The field, none in a Classic world.
  def self.state_fields
    return {} unless raid?

    { "rbn" => closed_reason ? 0 : players_in }
  rescue => e
    log_once(:state_fields, "telling whether the battle takes players in failed: #{e.class}: #{e.message}")
    { "rbn" => 0 }
  end

  # Counts the players of the battle the player hosts or fights alone, the player and those taken in
  # who have not joined yet included.
  #
  # @return [Integer] The players.
  def self.players_in
    hotjoin = MGQ_MpBattlesHotjoin
    hotjoin.players_count + hotjoin.pending_seats.size
  end

  # Tells why the player's battle takes nobody in now.
  #
  # @return [Array<String>, nil] The reason the player who asks reads (see REFUSALS) and the one
  #   for Multiplayer InGame.log, nil when it takes players in.
  def self.closed_reason
    sync = MGQ_MpBattlesSync
    return ["pvp", "a PvP battle runs"] if MGQ_MpBattles.kind == :pvp || (defined?(MGQ_MpBattlesPvp) && MGQ_MpBattlesPvp::Battle.running?)

    bid, host = MGQ_MpBattlesHotjoin.running_battle
    return ["closed", "the player fights no battle others may join"] unless bid
    return ["closed", "the player is a guest of battle #{bid}"] unless host == MGQ_MpOverworldSync::Me.seat
    return ["gathering", "the battle still gathers its players"] if sync.live? && !MGQ_MpBattlesCoop.active?
    return ["closed", "the computer plays on for those who left"] if sync.live? && sync.solo?
    return ["ending", "the battle ends"] if BattleManager.respond_to?(:battle_end?) && BattleManager.battle_end?

    count = players_in
    ["full", "#{count} players fight, as many as a battle takes"] if count >= MGQ_MpBattlesCoop::RAID_PLAYERS
  end

  # Takes another player's request to join the battle the player hosts or fights alone: takes them
  # in when it can (see refusal), else refuses them.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who asks.
  # @param message [Hash] The request: the battle's id and the map.
  def self.take_request(peer, message)
    return log_once([:classic_request, peer && peer.seat], "ignored a request to join from #{who(peer)}: not a Raid World") unless raid?

    code, reason = refusal(peer.seat, message)
    return refuse(peer, message, code, reason) if code

    MGQ_MpBattlesHotjoin.take_in_player(peer)
  rescue => e
    log("taking a request to join failed: #{e.class}: #{e.message}")
  end

  # Tells why the player's battle cannot take in a player who asks to join it.
  #
  # @param seat [Integer] The asking player's seat.
  # @param message [Hash] The request.
  # @return [Array<String>, nil] The reason the player who asks reads and the one for Multiplayer
  #   InGame.log, nil when it can.
  def self.refusal(seat, message)
    closed = closed_reason
    return closed if closed

    sync = MGQ_MpBattlesSync
    bid = MGQ_MpBattlesHotjoin.running_battle[0]
    return ["closed", "it asks for battle #{message['bid']}, the player's is #{bid}"] unless message["bid"].to_s == bid.to_s
    return ["closed", "it asks from map #{message['map']}, the player's is #{$game_map.map_id}"] unless message["map"].to_i == $game_map.map_id
    # The battle's guests who left stay among its seats, which the next command phase takes out.
    return ["closed", "its player was in this battle before"] if sync.role && Array(sync.seats).include?(seat)

    ["closed", "its player is taken in already"] if MGQ_MpBattlesHotjoin.pending_seats.include?(seat)
  end

  # Turns down a player's request to join, telling them why.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who asked.
  # @param message [Hash] The request.
  # @param code [String] The reason they read, see REFUSALS.
  # @param reason [String] The reason for Multiplayer InGame.log.
  def self.refuse(peer, message, code, reason)
    MGQ_MpBattlesCoop.tell_map([peer.seat], "pick_no", "bid" => message["bid"].to_s, "why" => code)
    log("refused #{who(peer)}'s request to join battle #{message['bid']}: #{reason}")
  end

  # The joining side.

  # Finds the battle the prompt offers: of the other players within JOIN_DISTANCE who fight one, as
  # their states tell, the nearest whose battle takes players in (see open_battle), while the player
  # is free (see busy_reason).
  #
  # @return [Array, nil] The battle's host and its id, nil when none or the player is busy.
  def self.target
    return nil if busy_reason

    x = $game_player.x
    y = $game_player.y
    near = MGQ_MpCoop::Scope.peers_on($game_map.map_id).select do |peer|
      peer.state["scene"] == "battle" && !peer.state["rb"].to_s.empty? && MGQ_MpBattlesCoop.distance(peer, x, y) <= JOIN_DISTANCE
    end
    near = near.sort_by { |peer| [MGQ_MpBattlesCoop.distance(peer, x, y), peer.state["id"].to_s] }
    near.map { |peer| open_battle(peer) }.compact.first
  end

  # Finds the host of the battle another player fights and whether it takes players in: its host on
  # the player's map telling the same battle, with fewer than MGQ_MpBattlesCoop::RAID_PLAYERS
  # players in it (see state_fields).
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player who fights it.
  # @return [Array, nil] The battle's host and its id, nil when it takes nobody in.
  def self.open_battle(peer)
    bid = peer.state["rb"].to_s
    return nil unless peer.state["rbh"].to_s =~ /\A\d+\z/
    # The host keeps a guest who left among the battle's seats, so it refuses them (see refusal).
    return nil if bid == MGQ_MpBattlesSync.battle_id.to_s

    host = MGQ_MpOverworldSync::Peers.at(peer.state["rbh"].to_i)
    return nil unless host && host.state["map"].to_i == $game_map.map_id && host.state["scene"] == "battle" && host.state["rb"].to_s == bid

    host.state["rbn"].to_i.between?(1, MGQ_MpBattlesCoop::RAID_PLAYERS - 1) ? [host, bid] : nil
  end

  # Tells why the player may not join a battle by choice now.
  #
  # @return [String, nil] The first reason that holds, nil when they may.
  def self.busy_reason
    return "no world is open" unless MGQ_MpOverworldSync.in_world?
    return "not a Raid World" unless raid?
    return "the map is not free: an event, a message or a transfer" unless MGQ_MpOverworldSync.map_free?
    return "the player is in a multiplayer battle" if MGQ_MpBattlesSync.role || MGQ_MpBattles.running?
    return "the player waits for an answer" if @asking
    return "the player stands still for a battle or the story" if MGQ_MpHooks.player_held?
    return "the chat box is open" if MGQ_MpChat.typing?
    return "the action wheel is open" if MGQ_MpActions::Wheel.open?
    return "the emote wheel is open" if MGQ_MpEmotes.open?
    return "the World overview is open" if defined?(MGQ_MpWorldOverview) && MGQ_MpWorldOverview.open?

    "the player trades or is about to teleport" if MGQ_MpBattlesCoop.trading? || MGQ_MpCoopGather.coming?
  end

  # Finds the battle the prompt offers and asks its host once the hotkey goes down. Called by the map
  # every frame, so a press of the hotkey is seen once, also while the scene changes, which hides the
  # prompt.
  #
  # @param changing [Boolean] Whether the map's scene changes.
  def self.on_map(changing)
    settle
    @target = nil
    return unless reads_hotkey?

    pressed = MGQ_MpHotkeys.pressed?(:join_battle)
    @target = changing ? nil : target
    return unless pressed && !changing

    found = @target
    return request(*found) if found
    return if $mgq_text_input

    log("join battle hotkey ignored: #{busy_reason || 'nobody near the player fights a battle that takes players in'}")
  rescue => e
    @target = nil
    log("joining a battle by choice failed: #{e.class}: #{e.message}")
  end

  # Reports whether the Join Battle hotkey is read: only in a Raid World, and only while no other
  # hotkey shares its key.
  #
  # @return [Boolean] Whether it is.
  def self.reads_hotkey?
    return false unless MGQ_MpOverworldSync.in_world? && raid?

    code = MGQ_MpHotkeys.code(:join_battle)
    # A key's press goes to the first who reads it in a frame, which would take it from the other.
    other = MGQ_MpHotkeys::BINDINGS.keys.find { |action| action != :join_battle && MGQ_MpHotkeys.code(action) == code }
    return true unless other

    log_once([:shared_key, other, code], "the Join Battle hotkey #{MGQ_MpHotkeys.label(:join_battle)} is off: #{MGQ_MpHotkeys::BINDINGS[other].name} has the same key")
    false
  end

  # Tells the prompt below the player's character, see Sprite_MpJoinPrompt. The map stops finding its
  # battle while a message shows, so the prompt hides then too.
  #
  # @return [String, nil] The prompt, nil while no battle near the player takes them in.
  def self.prompt_text
    @target && MGQ_MpOverworldSync.map_free? ? "Press #{MGQ_MpHotkeys.label(:join_battle)} to join battle" : nil
  end

  # Asks the host of a battle near the player to take them in, through the map's gate. The player
  # stands still until the host's invite or refusal comes, ANSWER_SECONDS at most.
  #
  # @param host [MGQ_MpOverworldSync::Peers::Peer] The battle's host.
  # @param bid [String] The battle's id.
  def self.request(host, bid)
    name = host.state["name"].to_s
    @asking = { :seat => host.seat, :bid => bid, :name => name, :at => Time.now }
    @gave_up = nil
    @target = nil
    MGQ_MpBattlesCoop.tell_map([host.seat], "pick", "bid" => bid, "map" => $game_map.map_id)
    notice("Asking #{name} to join their battle...", ANSWER_SECONDS * 60)
    log("asked #{who(host)} to join battle #{bid}, waiting up to #{ANSWER_SECONDS} s")
  end

  # Reports whether the player waits for the answer of a battle's host they asked to join, standing
  # still, also once the host's invite came but waits for the player to be free.
  #
  # @return [Boolean] Whether they do.
  def self.asking?
    asking = @asking
    return false unless !asking.nil? && MGQ_MpBattlesSync.role.nil?

    Time.now - asking[:at] <= ANSWER_SECONDS || MGQ_MpBattlesCoop.invited_by?(asking[:seat], asking[:bid])
  end

  # Ends the wait for the host's answer once the player joined a battle, through an invite (see
  # MGQ_MpBattlesCoop.accept), or ANSWER_SECONDS passed without the host's invite. Then the host is
  # told the player stopped waiting, so it forgets them, and its invite on its way is ignored (see
  # gave_up?).
  def self.settle
    asking = @asking
    return unless asking

    sync = MGQ_MpBattlesSync
    if sync.role
      @asking = nil
      MGQ_MpNotices.drop(NOTICE_KEY, "the player joins a battle") if defined?(MGQ_MpNotices)
      return log("joins #{asking[:name]}'s battle #{asking[:bid]} as a late guest") if sync.battle_id.to_s == asking[:bid].to_s

      return log("joins battle #{sync.battle_id} as #{sync.role} instead of #{asking[:name]}'s battle #{asking[:bid]}")
    end
    return if Time.now - asking[:at] <= ANSWER_SECONDS || MGQ_MpBattlesCoop.invited_by?(asking[:seat], asking[:bid])

    @asking = nil
    @gave_up = [asking[:seat], asking[:bid].to_s]
    MGQ_MpBattlesCoop.tell_map([asking[:seat]], "off", "bid" => asking[:bid])
    notice("No answer from #{asking[:name]}'s battle.")
    log("no answer from #{asking[:name]} for battle #{asking[:bid]} within #{ANSWER_SECONDS} s, told them the player stopped waiting")
  end

  # Reports whether an invite comes from the host the player stopped waiting for, to the battle
  # they asked to join (see settle), which the host forgot them for.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who invites.
  # @param message [Hash] The invite.
  # @return [Boolean] Whether it does.
  def self.gave_up?(peer, message)
    gave_up = @gave_up
    !gave_up.nil? && !peer.nil? && peer.seat == gave_up[0] && message["bid"].to_s == gave_up[1] && message["hot"].to_s == "1"
  end

  # Takes the refusal of the host the player asked to join, telling the player why.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who refused.
  # @param message [Hash] The refusal: the battle's id and the reason, see REFUSALS.
  def self.take_refusal(peer, message)
    asking = @asking
    unless asking && peer && peer.seat == asking[:seat] && message["bid"].to_s == asking[:bid].to_s
      return log("refusal for battle #{message['bid']} from #{who(peer)} ignored: not the battle the player asked to join")
    end

    @asking = nil
    why = REFUSALS[message["why"].to_s] || REFUSALS["closed"]
    notice("Cannot join #{asking[:name]}'s battle: #{why}.")
    log("#{who(peer)} refused the player for battle #{message['bid']}: #{message['why']}")
  end

  # Shows a message in the notification box, in place of this script's last one.
  #
  # @param text [String] The message.
  # @param frames [Integer] How long it shows.
  def self.notice(text, frames = NOTICE_FRAMES)
    MGQ_MpNotices.message(NOTICE_KEY, text, frames) if defined?(MGQ_MpNotices)
  end

  # Names a player for Multiplayer InGame.log.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] The player.
  # @return [String] Their name and seat.
  def self.who(peer)
    MGQ_MpOverworldSync.who(peer)
  end

  # Forgets the prompt and a request a reset interrupted.
  def self.drop
    log("forgot the request to join #{@asking[:name]}'s battle after a reset") if @asking
    @asking = nil
    @gave_up = nil
    @target = nil
  end
end

# The prompt below the player's character while a battle near them takes them in, naming the
# hotkey that joins it.
class Sprite_MpJoinPrompt < Sprite
  # Width of the prompt.
  WIDTH = 240

  # Height of the prompt.
  HEIGHT = 20

  # Pixels between the character's feet and the prompt.
  GAP = 2

  # Size of the prompt's font.
  FONT_SIZE = 16

  # Color of the prompt, gold, which stands out from the names on the map.
  COLOR = Color.new(255, 230, 140)

  # Creates the prompt, empty.
  #
  # @param viewport [Viewport] The map's viewport of characters.
  def initialize(viewport)
    super(viewport)
    self.bitmap = Bitmap.new(WIDTH, HEIGHT)
    self.ox = WIDTH / 2
    self.z = MGQ_MpUi::Z[:labels]
    @shown = nil
  end

  # Draws the prompt, if it changed, below the player's sprite, or hides it.
  #
  # @param sprite [Sprite_Character, nil] The player's sprite.
  def show(sprite)
    text = MGQ_MpBattlesJoin.prompt_text
    self.visible = !text.nil? && !sprite.nil? && sprite.visible && sprite.opacity > 0
    return unless visible

    self.x = sprite.x
    self.y = sprite.y + GAP
    return if text == @shown

    @shown = text
    bitmap.clear
    bitmap.font.size = FONT_SIZE
    bitmap.font.outline = true
    bitmap.font.color = COLOR
    bitmap.draw_text(0, 0, WIDTH, HEIGHT, text, 1)
  end

  # Frees the prompt's picture.
  def dispose
    bitmap.dispose
    super
  end
end

# What this script tells in the player's state, through overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.state_fields { MGQ_MpBattlesJoin.state_fields }
rescue => e
  MGQ_MpBattlesJoin.log("state FAILED: #{e.class}: #{e.message}")
end

# Game hooks, through core_hooks.rbx.

begin
  # After the map's update, the prompt's battle and the hotkey; after battles_coop.rbx's, which
  # joins the battle once the host's invite came.
  MGQ_MpHooks.after(Scene_Map, :update_scene, "battles_coop_join") { MGQ_MpBattlesJoin.on_map(scene_changing?) }

  # After the map's sprites, the prompt below the player's character.
  MGQ_MpHooks.after(Spriteset_Map, :update, "battles_coop_join") do
    @mgq_mp_join_prompt ||= Sprite_MpJoinPrompt.new(@viewport1)
    @mgq_mp_join_prompt.show(@character_sprites.find { |sprite| sprite.character.equal?($game_player) })
  end

  MGQ_MpHooks.before(Spriteset_Map, :dispose, "battles_coop_join") do
    @mgq_mp_join_prompt.dispose if @mgq_mp_join_prompt
    @mgq_mp_join_prompt = nil
  end

  # Before the title screen starts, a request a reset interrupted is forgotten.
  MGQ_MpHooks.before(Scene_Title, :start, "battles_coop_join") { MGQ_MpBattlesJoin.drop }

  # The player stands still and opens no menu while they wait for the host's answer.
  MGQ_MpHooks.hold_player("battles_coop_join") { MGQ_MpBattlesJoin.asking? }
rescue => e
  MGQ_MpBattlesJoin.log("hooks FAILED: #{e.class}: #{e.message}")
end
