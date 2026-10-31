#----------------------------------------------------------------
#  battles_coop_join.rbx
#
#  Changelog:
#      Paulinchen  2026-10-31: Compared the Join Battle key with every hotkey through MGQ_MpHotkeys.names
#      Paulinchen  2026-10-30: Checked requests to join and told the battle's room through the rules in C#
#                            - Found what the prompt offers and asked and waited for the battle's host through the DLL
#      Paulinchen  2026-10-23: Kept the prompt off the live map behind menus
#      Paulinchen  2026-10-17: Offered the frozen fight of a raid boss near the player
#      Paulinchen  2026-10-15: Told whether a served battle takes players in by the battle server's state
#      Paulinchen  2026-10-12: Logged a refused hotkey through MGQ_MpHotkeys.log_refusal
#                            - Read the map's viewport and character sprites through MGQ_MpGame
#      Paulinchen  2026-10-11: Asked the party members near along to a battle the player asks to join
#                            - Drew the prompt in the shared style's small font and solid outline
#                            - Drew the prompt in the color of requests and offers
#                            - Kept the prompt on the screen through MGQ_MpUi.within
#      Paulinchen  2026-10-10: Offered a side battle near a raid boss battle that takes nobody in
#                            - Kept the prompt whole on the screen at the map's edges
#                            - Offered a battle that waits while its player is away
#      Paulinchen  2026-10-09: Created
#
#----------------------------------------------------------------

# Joining a battle by choice in a Raid World: while the player is free on the map and another player
# within three steps fights a battle whose host's state says it takes players in (state_fields), a
# prompt below the player's character names the hotkey that joins it (Sprite_MpJoinPrompt). Its
# press asks the battle's host (the DLL's JoinChoice), who takes the player in as a late guest
# without enemies (MGQ_MpBattlesHotjoin.take_in_player), so an event's battle and a boss battle take
# them too, or refuses, which the player reads in the notification box. Near a raid boss battle that
# takes the player in no more, such as a full one, the prompt offers a side battle against the same
# boss instead (sides), which the player fights as their own (MGQ_MpRaidPool.start_side). Near none
# of these, a raid boss's frozen fight near the player is offered (freeze_candidate), which the
# press resumes (MGQ_MpRaidFreezeUi.join).
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpBattlesJoin
  # Steps a raid boss's frozen fight may be away from the player for its prompt to show, as the
  # DLL's JoinChoice counts a battle's.
  JOIN_DISTANCE = 3

  # Frames the notification box shows a message of this script, four seconds.
  NOTICE_FRAMES = 240

  # The notification box's key of this script's messages, which the DLL's share.
  NOTICE_KEY = :join_battle

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "join battle"

  # Reports whether a Raid World is open, whose battles players may join by choice.
  #
  # @return [Boolean] Whether one is.
  def self.raid?
    MGQ_MpCoop::Scope.raid?
  end

  # The host's side.

  # The topic that tells the players of the running battle while it takes players in.
  ROOM_TOPIC = "coop.room"

  # The field this script adds to the state the player's game tells the others: in a Raid World
  # "rbn", the players of the battle the player hosts or fights alone, those taken in counted, while
  # it takes players in, else 0, as the rules in C# tell it (topic coop.room).
  #
  # @return [Hash] The field, none in a Classic world.
  def self.state_fields
    return {} unless raid?

    front = defined?(MGQ_MpBattlesServed) && MGQ_MpBattlesServed.front_fields(%w(rbn))
    return front if front

    { "rbn" => MGQ_Multiplayer::Bridge.call(ROOM_TOPIC, MGQ_MpBattlesHotjoin.intake_facts).to_i }
  rescue => e
    log_once(:state_fields, "telling whether the battle takes players in failed: #{e.class}: #{e.message}")
    { "rbn" => 0 }
  end

  # Takes another player's request to join the battle the player hosts or fights alone: takes them
  # in when the rules allow it (topic coop.intake), else refuses them with the reason they read
  # (see the DLL's JoinChoice).
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who asks.
  # @param message [Hash] The request: the battle's id and the map.
  def self.take_request(peer, message)
    return log_once([:classic_request, peer && peer.seat], "ignored a request to join from #{who(peer)}: not a Raid World") unless raid?

    answer = MGQ_Multiplayer::Bridge.call(MGQ_MpBattlesHotjoin::INTAKE_TOPIC, "kind" => "choice", "facts" => MGQ_MpBattlesHotjoin.intake_facts,
                                                                              "seat" => peer.seat, "bid" => message["bid"], "map" => message["map"])
    return refuse(peer, message, "closed", "the rules did not answer") unless answer

    code, reason = answer["refusal"]
    return refuse(peer, message, code, reason) if code

    MGQ_MpBattlesHotjoin.take_in_player(peer)
  rescue => e
    log("taking a request to join failed: #{e.class}: #{e.message}")
  end

  # Turns down a player's request to join, telling them why.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who asked.
  # @param message [Hash] The request.
  # @param code [String] The reason they read, see the DLL's JoinChoice.
  # @param reason [String] The reason for the log.
  def self.refuse(peer, message, code, reason)
    MGQ_MpBattlesCoop.tell_map([peer.seat], "pick_no", "bid" => message["bid"].to_s, "why" => code)
    log("refused #{who(peer)}'s request to join battle #{message['bid']}: #{reason}")
  end

  # The joining side.

  # The topic of a frame on the map for the prompt, which the DLL's JoinChoice answers.
  FRAME_TOPIC = "coop.join_frame"

  # Tells why the player may not join a battle by choice now, as only the game knows it: the first
  # reason before the player's own request, which the DLL knows itself, and the first after it.
  #
  # @return [Array<String, nil>] The reason before and the reason after, each nil when none holds.
  def self.busy_reasons
    before = if !MGQ_MpOverworldSync.in_world? then "no world is open"
             elsif !raid? then "not a Raid World"
             elsif !MGQ_MpOverworldSync.map_free? then "the map is not free: an event, a message or a transfer"
             elsif MGQ_MpBattlesSync.role || MGQ_MpBattles.running? then "the player is in a multiplayer battle"
             end
    after = if MGQ_MpHooks.player_held? then "the player stands still for a battle or the story"
            elsif MGQ_MpChat.typing? then "the chat box is open"
            elsif MGQ_MpActions::Wheel.open? then "the action wheel is open"
            elsif MGQ_MpEmotes.open? then "the emote wheel is open"
            elsif defined?(MGQ_MpWorldOverview) && MGQ_MpWorldOverview.open? then "the World overview is open"
            elsif MGQ_MpBattlesCoop.trading? || MGQ_MpCoopGather.coming? then "the player trades or is about to teleport"
            end
    [before, after]
  end

  # Tells the DLL of the frame on the map (topic coop.join_frame), which settles the player's request
  # and finds what the prompt offers while the hotkey is read: a battle near that takes players in,
  # else a side battle beside a full raid boss battle, else a frozen fight. A press asks the battle's
  # host there, starts the side battle or resumes the frozen fight here. Called by the map every
  # frame.
  #
  # The hotkey is read also while the scene changes, which hides the prompt, so a press is seen once.
  #
  # @param changing [Boolean] Whether the map's scene changes.
  def self.on_map(changing)
    @target = nil
    @side = nil
    @freeze = nil
    reads = reads_hotkey?
    pressed = reads && MGQ_MpHotkeys.pressed?(:join_battle) ? true : false
    request = { "facts" => MGQ_MpBattlesCoop.facts, "reads" => reads, "pressed" => pressed, "changing" => changing ? true : false,
                "busy" => reads ? busy_reasons : [nil, nil], "sides" => reads ? sides : nil, "freeze" => reads ? freeze_candidate : nil }
    answer = MGQ_Multiplayer::Bridge.call(FRAME_TOPIC, request)
    MGQ_MpBattlesCoop.take_status(answer)
    return unless reads && answer.is_a?(Hash)

    @target = answer["target"]
    @side = answer["side"]
    @freeze = answer["freeze"]
    return if !pressed || changing || answer["asked"]
    return fight_alongside(*@side) if @side
    return MGQ_MpRaidFreezeUi.join(@freeze[0]) if @freeze

    MGQ_MpHotkeys.log_refusal(:join_battle, answer["busy_reason"] || 'nobody near the player fights a battle that takes players in')
  rescue => e
    @target = nil
    @side = nil
    @freeze = nil
    log("joining a battle by choice failed: #{e.class}: #{e.message}")
  end

  # Lists the side battles the raid boss battles on the player's map offer, by their hosts' states
  # (MGQ_MpRaidPool.side_of), with the steps to each boss's event, for the DLL to choose from.
  #
  # @return [Array<Array>, nil] Each host's seat, the troop, the host's enemy rates, the steps to the
  #   boss (nil unknown) and its name; nil without raid boss pools.
  def self.sides
    return nil unless defined?(MGQ_MpRaidPool)

    x = $game_player.x
    y = $game_player.y
    map = $game_map.map_id
    MGQ_MpOverworldSync::Peers.all.map do |host|
      side = host.state["map"].to_i == map ? MGQ_MpRaidPool.side_of(host) : nil
      next unless side

      steps = defined?(MGQ_MpRaidBar) ? MGQ_MpRaidBar.distance_to_boss(side[0], x, y) : nil
      [host.seat, side[0].to_i, side[1].to_s, steps, MGQ_MpRaidPool.troop_label(side[0]).to_s]
    end.compact
  end

  # Finds the frozen fight of a raid boss near the player, the one whose boss's stand-in stands
  # within JOIN_DISTANCE, see ui_raid_freeze.rbx, which the prompt offers when nothing else.
  #
  # @return [Array, nil] The troop and the boss's name, nil for none.
  def self.freeze_candidate
    defined?(MGQ_MpRaidFreezeUi) ? MGQ_MpRaidFreezeUi.join_target($game_player.x, $game_player.y, JOIN_DISTANCE) : nil
  end

  # Reports whether the Join Battle hotkey is read: only in a Raid World, and only while no other
  # hotkey shares its key.
  #
  # @return [Boolean] Whether it is.
  def self.reads_hotkey?
    return false unless MGQ_MpOverworldSync.in_world? && raid?

    code = MGQ_MpHotkeys.code(:join_battle)
    # A key's press goes to the first who reads it in a frame, which would take it from the other.
    other = MGQ_MpHotkeys.names.find { |name| name != :join_battle && MGQ_MpHotkeys.code(name) == code }
    return true unless other

    log_once([:shared_key, other, code], "the Join Battle hotkey #{MGQ_MpHotkeys.label(:join_battle)} is off: #{MGQ_MpHotkeys.name_of(other)} has the same key")
    false
  end

  # Tells the prompt below the player's character, see Sprite_MpJoinPrompt.
  #
  # The map stops finding its battle while a message shows, so the prompt hides then too.
  #
  # @return [String, nil] The prompt, nil while no battle near the player takes them in, none
  #   offers a side battle and no frozen fight waits near them.
  def self.prompt_text
    return nil unless MGQ_MpOverworldSync.map_free?
    return "Press #{MGQ_MpHotkeys.label(:join_battle)} to join battle" if @target
    return "Press #{MGQ_MpHotkeys.label(:join_battle)} to fight #{@side[2]} alongside" if @side

    @freeze ? "Press #{MGQ_MpHotkeys.label(:join_battle)} to fight #{@freeze[1]}" : nil
  end

  # Starts a side battle against the boss of a battle near the player, telling the player when it
  # cannot start.
  #
  # @param troop [Integer] The troop.
  # @param rates [String] The host's enemy rates.
  # @param name [String] The boss's name.
  def self.fight_alongside(troop, rates, name)
    @side = nil
    log("fights #{name} (troop #{troop}) in a side battle alongside a full boss battle near the player")
    notice("Cannot fight #{name} now.") unless MGQ_MpRaidPool.start_side(troop, rates)
  end

  # Reports whether the player waits for the answer of a battle's host they asked to join, standing
  # still, also once the host's invite came but waits for the player to be free, as the DLL's status
  # tells.
  #
  # @return [Boolean] Whether they do.
  def self.asking?
    MGQ_MpBattlesCoop.join_waits? && MGQ_MpBattlesSync.role.nil?
  end

  # Shows a message in the notification box, in place of this script's last one.
  #
  # @param text [String] The message.
  # @param frames [Integer] How long it shows.
  def self.notice(text, frames = NOTICE_FRAMES)
    MGQ_MpNotices.message(NOTICE_KEY, text, frames) if defined?(MGQ_MpNotices)
  end

  # Names a player for the log.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] The player.
  # @return [String] Their name and seat.
  def self.who(peer)
    MGQ_MpOverworldSync.who(peer)
  end

  # Forgets the prompt a reset interrupted; the DLL forgets the request with the matchmaking.
  def self.drop
    @target = nil
    @side = nil
    @freeze = nil
  end
end

# The prompt below the player's character while a battle near them takes them in, naming the
# hotkey that joins it, in the style's small font and solid outline.
class Sprite_MpJoinPrompt < Sprite
  # Width of the prompt.
  WIDTH = 240

  # Height of the prompt.
  HEIGHT = 20

  # Pixels between the character's feet and the prompt.
  GAP = 2

  # Size of the prompt's font, the style's small one.
  FONT_SIZE = MGQ_MpUi::Style::SMALL_SIZE

  # Color of the prompt, the one every request and offer shares.
  COLOR = MGQ_MpActions::LINE_COLOR

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

  # Draws the prompt, if it changed, below the player's sprite, or hides it. At the map's edges the
  # prompt stays whole on the screen.
  #
  # @param sprite [Sprite_Character, nil] The player's sprite.
  def show(sprite)
    text = MGQ_MpBattlesJoin.prompt_text
    self.visible = !text.nil? && !sprite.nil? && sprite.visible && sprite.opacity > 0
    return unless visible

    self.x = MGQ_MpUi.within(sprite.x, ox, Graphics.width - WIDTH + ox)
    self.y = MGQ_MpUi.within(sprite.y + GAP, 0, Graphics.height - HEIGHT)
    return if text == @shown

    @shown = text
    bitmap.clear
    MGQ_MpUi::Style.use_font(bitmap, FONT_SIZE, COLOR)
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
    next unless mgq_mp_hud?

    @mgq_mp_join_prompt ||= Sprite_MpJoinPrompt.new(MGQ_MpGame.get(self, :viewport1))
    @mgq_mp_join_prompt.show(MGQ_MpGame.get(self, :character_sprites).find { |sprite| sprite.character.equal?($game_player) })
  end

  # Before the map's sprites go, the prompt goes with them.
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
