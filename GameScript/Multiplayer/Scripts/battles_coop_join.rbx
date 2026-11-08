#----------------------------------------------------------------
#  battles_coop_join.rbx
#
#  Changelog:
#      Paulinchen  2026-11-08: Handed the DLL the tiles of the bosses and the frozen fights, which it picks within the hotkey's reach
#      Paulinchen  2026-11-06: Turned the Join Battle hotkey off while the Mod Framework leaves it unbound
#                            - Showed the prompt as a hud of the Mod Framework's UI layer under the player
#                            - Told the DLL a side battle's enemy rates as the list of numbers they are
#      Paulinchen  2026-11-05: Told the battle's players in rbn whether or not it takes players in
#                            - Told whether the battle takes players in, is full, ends or is closed, as the rules in C# tell it
#                            - Read the Join Battle hotkey in a Classic world too, for a party member's battle the player missed
#                            - Took a party member's request to join in a Classic world
#                            - Left a press near a battle that takes nobody in to the DLL, which tells the player why
#      Paulinchen  2026-11-01: Showed the prompt as a button of the Mod Framework below the player, which a click presses as the hotkey does
#                            - Asked the wheels of the Mod Framework whether one is open
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

# Joining a battle by choice: while the player is free on the map and another player within three
# steps fights a battle whose host's state says it takes players in (state_fields), a prompt below
# the player's character names the hotkey that joins it (Prompt), which a click on the prompt
# presses too. In a Classic world only a party member's battle is offered, which a member who
# missed it joins late. Its press asks the battle's host (the DLL's JoinChoice), who takes the
# player in as a late guest without enemies (MGQ_MpBattlesHotjoin.take_in_player), so an event's
# battle and a boss battle take them too, or refuses, which the player reads in the notification
# box. Near a full raid boss battle in a Raid World the prompt offers a side battle against the
# same boss instead (sides), which the player fights as their own (MGQ_MpRaidPool.start_side). Near
# none of these, a raid boss's frozen fight near the player is offered (frozen_fights), which
# the press resumes (MGQ_MpRaidFreezeUi.join). A press near a battle that takes nobody in tells why.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpBattlesJoin
  # Frames the notification box shows a message of this script, four seconds.
  NOTICE_FRAMES = 240

  # The notification box's key of this script's messages, which the DLL's share.
  NOTICE_KEY = :join_battle

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "join battle"

  # Reports whether a Raid World is open, whose battles any player may join by choice.
  #
  # @return [Boolean] Whether one is.
  def self.raid?
    MGQ_MpCoop::Scope.raid?
  end

  # The host's side.

  # The topic that tells the players of the running battle and whether it takes players in.
  ROOM_TOPIC = "coop.room"

  # What the state tells of a battle while the rules in C# do not answer.
  CLOSED = { "rbn" => 0, "rbs" => "closed" }

  # The fields this script adds to the state the player's game tells the others, as the rules in
  # C# tell them (topic coop.room): "rbn", the players of the battle the player hosts or fights
  # alone, those taken in counted, and "rbs", whether it takes players in ("open") or why not
  # ("full", "ending", "gathering", "pvp" or "closed"), which the others' Sessions read.
  #
  # @return [Hash] The fields.
  def self.state_fields
    front = defined?(MGQ_MpBattlesServed) && MGQ_MpBattlesServed.front_fields(%w(rbn rbs))
    return front if front

    told = MGQ_Multiplayer::Bridge.call(ROOM_TOPIC, MGQ_MpBattlesHotjoin.intake_facts)
    told.is_a?(Hash) ? { "rbn" => told["rbn"].to_i, "rbs" => told["rbs"].to_s } : CLOSED
  rescue => e
    log_once(:state_fields, "telling whether the battle takes players in failed: #{e.class}: #{e.message}")
    CLOSED
  end

  # Takes another player's request to join the battle the player hosts or fights alone, in a
  # Classic world only a party member's: takes them in when the rules allow it (topic coop.intake),
  # else refuses them with the reason they read (see the DLL's JoinChoice).
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who asks.
  # @param message [Hash] The request: the battle's id and the map.
  def self.take_request(peer, message)
    unless raid? || (peer && peer.member)
      return log_once([:classic_request, peer && peer.seat], "ignored a request to join from #{who(peer)}: not a Raid World, and not a party member")
    end

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
             elsif !MGQ_MpOverworldSync.map_free? then "the map is not free: an event, a message or a transfer"
             elsif MGQ_MpBattlesSync.role || MGQ_MpBattles.running? then "the player is in a multiplayer battle"
             end
    after = if MGQ_MpHooks.player_held? then "the player stands still for a battle or the story"
            elsif MGQ_MpChat.typing? then "the chat box is open"
            elsif MGQ_MpActions.wheel.open? then "the action wheel is open"
            elsif MGQ_MpEmotes.wheel.open? then "the emote wheel is open"
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
    clicked = @clicked
    @clicked = false
    pressed = reads && (MGQ_MpHotkeys.pressed?(:join_battle) || clicked) ? true : false
    request = { "facts" => MGQ_MpBattlesCoop.facts, "reads" => reads, "pressed" => pressed, "changing" => changing ? true : false,
                "busy" => reads ? busy_reasons : [nil, nil], "sides" => reads ? sides : nil, "frozen" => reads ? frozen_fights : [] }
    answer = MGQ_Multiplayer::Bridge.call(FRAME_TOPIC, request)
    MGQ_MpBattlesCoop.take_status(answer)
    return unless reads && answer.is_a?(Hash)

    @target = answer["target"]
    @side = answer["side"]
    @freeze = answer["freeze"]
    return if !pressed || changing || answer["asked"] || answer["not_taken"]
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
  # (MGQ_MpRaidPool.side_of), with the tiles of each boss's events, for the DLL to choose from.
  #
  # @return [Array<Array>, nil] Each host's seat, the troop, the host's enemy rates, the tiles of the
  #   boss's events ([x, y] each) and its name; nil without raid boss pools.
  def self.sides
    return nil unless defined?(MGQ_MpRaidPool)

    map = $game_map.map_id
    MGQ_MpOverworldSync::Peers.all.map do |host|
      side = host.state["map"].to_i == map ? MGQ_MpRaidPool.side_of(host) : nil
      next unless side

      tiles = defined?(MGQ_MpRaidBar) ? MGQ_MpRaidBar.boss_tiles(side[0]) : []
      [host.seat, side[0].to_i, side[1], tiles, MGQ_MpRaidPool.troop_label(side[0]).to_s]
    end.compact
  end

  # Lists the frozen fights of raid bosses on the map, see ui_raid_freeze.rbx, of which the DLL
  # offers the one within the Join Battle hotkey's reach when nothing else.
  #
  # @return [Array<Array>] Each fight's troop, its boss's name and the tile of its boss's stand-in.
  def self.frozen_fights
    defined?(MGQ_MpRaidFreezeUi) ? MGQ_MpRaidFreezeUi.join_targets : []
  end

  # Reports whether the Join Battle hotkey is read: only in a world, and only while it has a key.
  #
  # @return [Boolean] Whether it is.
  def self.reads_hotkey?
    return false unless MGQ_MpOverworldSync.in_world?
    # The Mod Framework leaves the hotkey unbound while another hotkey holds its key, and logs which.
    return true unless MGQ_MpHotkeys.code(:join_battle) == Mod_Framework::Hotkeys::UNBOUND

    log_once(:unbound, "the Join Battle hotkey is off: it has no key")
    false
  end

  # Takes a click on the prompt, which the next frame on the map presses as the Join Battle
  # hotkey, with the same refusals and log.
  def self.click
    @clicked = true
  end

  # Tells the prompt below the player's character, see Prompt.
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
    @clicked = false
    @target = nil
    @side = nil
    @freeze = nil
  end
end

module MGQ_MpBattlesJoin
  # The prompt under the player's character while a battle near them takes them in, naming the
  # hotkey that joins it, small and in the color every request and offer shares: a hud of the Mod
  # Framework's UI layer that follows the player, kept whole on the screen at the map's edges, its
  # one button pressed by a click as the hotkey does.
  class Prompt < Mod_Framework::UI::Component
    # Describes the prompt.
    def render
      hud follow: :player, side: :bottom, on_screen: true, movable: false, frame: false, shown_in: [Scene_Map],
          hide_while: -> { MGQ_MpBattlesJoin.prompt_text.nil? } do
        button -> { MGQ_MpBattlesJoin.prompt_text.to_s }, variant: :text, color: :mgq_online_own, on_click: -> { MGQ_MpBattlesJoin.click }
      end
    end
  end

  # Shows the prompt as the map is first seen, and again once F12 took it away.
  def self.keep_prompt
    MGQ_MpShown.keep(:join_prompt, Prompt)
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

  # After the map's sprites, the prompt under the player's character, never on the map behind a
  # menu.
  MGQ_MpHooks.after(Spriteset_Map, :update, "battles_coop_join") { MGQ_MpBattlesJoin.keep_prompt if mgq_mp_hud? }

  # Before the title screen starts, a request a reset interrupted is forgotten.
  MGQ_MpHooks.before(Scene_Title, :start, "battles_coop_join") { MGQ_MpBattlesJoin.drop }

  # The player stands still and opens no menu while they wait for the host's answer.
  MGQ_MpHooks.hold_player("battles_coop_join") { MGQ_MpBattlesJoin.asking? }
rescue => e
  MGQ_MpBattlesJoin.log("hooks FAILED: #{e.class}: #{e.message}")
end
