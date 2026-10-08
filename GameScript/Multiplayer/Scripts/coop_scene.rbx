#----------------------------------------------------------------
#  coop_scene.rbx
#
#  Changelog:
#      Paulinchen  2026-10-08: Took the teller, those who see the scene and the gate of its messages from MGQ_MpCoop::Scope, so in a Raid World the teller on the map shows it to everyone there whose story matches
#      Paulinchen  2026-10-07: Registered the save hook through core_hooks.rbx instead of a wrap of its own, and named the number of pictures the screen holds
#                            - Told the leader's story scene only to the members synced with the leader, who follow it, and showed it to them alone
#                            - Logged each change of the scene told and applied, with the picture's name and the tone, the changes ignored and why, and what was put back and why
#      Paulinchen  2026-10-06: Told the story's changes by the interpreter whose update runs, so the first change after the party gathered goes out too
#                            - Put the member's own tint back instead of none, and only on the map they watched from
#                            - Kept the leader's changes for two seconds before the leader's state says the story plays
#                            - Took pictures whose names hold dots, and the party's leader from coop.rbx
#      Paulinchen  2026-10-04: Created
#
#----------------------------------------------------------------

# What the leader's story shows besides its dialogue: its pictures, such as a story's CG, the
# screen's fades, tints, flashes and shakes, and whether the leader's character is hidden, as on a
# theater show's stage. While the story plays, the leader's game tells the party each change the
# story makes, and every member on the leader's map sees it in their own game. Once the story ends,
# or the leader or the member leaves the map, the member's screen is put back as it was. The
# dialogue itself goes through coop_events.rbx. In a Raid World the player telling the story on the
# map shows it to everyone there whose story matches theirs, see MGQ_MpCoop::Scope.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpCoopScene
  # What of a picture the story changes: showing, moving, turning, tinting and erasing it.
  PICTURE_METHODS = [:show, :move, :rotate, :start_tone_change, :erase]

  # What of the map's screen the story changes, those the game has: the game's own fades too.
  SCREEN_METHODS = [:start_fadeout, :start_fadein, :start_tone_change, :start_flash, :start_shake, :od_fadein, :od_fadeout]

  # A picture's file name, which may hold dots, such as "ev_aguni._hb1", but is never a path.
  PICTURE_NAME = /\A[\w\- ]+(\.[\w\- ]+)*\z/

  # The highest number of a picture the game's screens hold, which another game may name.
  MAX_PICTURE = 100

  # Frames the member's screen takes to come back once the story ended.
  RESTORE_FRAMES = 30

  # Frames a change of the leader's scene stays before the leader's state says the story plays,
  # two seconds, since the leader's state and the changes travel apart.
  STATE_GRACE_FRAMES = 120

  @pictures = []
  @screen = nil
  @transparent = nil
  @updating = []

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "co-op scene"

  # Notes the interpreter whose commands run now, which tells whether a change of a picture or the
  # screen is the story's. Called before every interpreter's update.
  #
  # The update tells interpreters apart, not the command, since a called common event runs inside its
  # caller's update and a command may wait frames before it runs, as while the party gathers.
  #
  # @param interpreter [Game_Interpreter] The interpreter.
  def self.updating(interpreter)
    @updating.push(interpreter)
  end

  # Notes that the interpreter whose commands ran stopped for the frame. Called after every
  # interpreter's update.
  def self.updated
    @updating.pop
  end

  # Reports whether the leader's story makes the change happening now: the map's main event, or a
  # common event it calls, runs while the story plays for the party. A parallel event, such as the
  # map's own display, changes pictures every frame and is left out.
  #
  # @return [Boolean] Whether it does.
  def self.story_change?
    return false unless MGQ_MpCoopEvents.story_playing? && MGQ_MpCoopEvents.leading_story? && SceneManager.scene.is_a?(Scene_Map)

    @updating.last.equal?($game_map.interpreter)
  end

  # As leader, tells the party a change the story makes to a picture of the map's screen.
  #
  # @param picture [Game_Picture] The picture.
  # @param name [Symbol] What happens to it, see PICTURE_METHODS.
  # @param args [Array] The method's arguments.
  def self.picture(picture, name, args)
    return unless story_change? && $game_map.screen.pictures[picture.number].equal?(picture)
    return if name == :erase && picture.name.empty?

    send_change("picture.#{name}", [picture.number] + args)
  rescue => e
    log_once(:picture, "telling a picture failed: #{e.class}: #{e.message}")
  end

  # As leader, tells the party a change the story makes to the map's screen.
  #
  # @param screen [Game_Screen] The screen.
  # @param name [Symbol] What happens to it, see SCREEN_METHODS.
  # @param args [Array] The method's arguments.
  def self.screen(screen, name, args)
    return unless screen.equal?($game_map.screen) && story_change?

    send_change("screen.#{name}", args)
  rescue => e
    log_once(:screen, "telling the screen failed: #{e.class}: #{e.message}")
  end

  # As leader, tells the party that the story hides or shows the player's character.
  #
  # @param player [Game_Player] The player.
  # @param hidden [Boolean] Whether it is hidden now.
  def self.transparency(player, hidden)
    send_change("player.transparent", [hidden ? true : false]) if player.equal?($game_player) && story_change?
  rescue => e
    log_once(:transparent, "telling the player's transparency failed: #{e.class}: #{e.message}")
  end

  # Sends the party one change of the story's scene, with the map it happens on.
  #
  # @param kind [String] What changes, such as "picture.show".
  # @param args [Array] Its arguments.
  def self.send_change(kind, args)
    return log_once([:unsendable, kind], "did not tell the party #{kind}: its arguments do not go over the wire (#{describe(args)})") unless MGQ_MpBattlesSync::Wire.encodable?(args)

    followers = MGQ_MpCoop::Scope.viewers
    return if followers.empty?

    sent = followers.map { |peer| MGQ_MpCoop::Scope.tell(peer.seat, "pscene", kind, "map" => $game_map.map_id, "args" => MGQ_MpBattlesSync::Wire.line(args)) }
    log("told #{followers.map { |peer| peer.state['name'] }.join(', ')} #{kind} #{describe(args)} on map #{$game_map.map_id}#{sent.all? ? '' : ', which failed for some'}")
  end

  # Writes a change's arguments for the log: tones and colors by their values, long texts cut.
  #
  # @param args [Array] The arguments.
  # @return [String] The arguments, never raising.
  def self.describe(args)
    Array(args).map do |arg|
      if arg.respond_to?(:gray) then "tone(#{arg.red.to_i},#{arg.green.to_i},#{arg.blue.to_i},#{arg.gray.to_i})"
      elsif arg.respond_to?(:alpha) then "color(#{arg.red.to_i},#{arg.green.to_i},#{arg.blue.to_i},#{arg.alpha.to_i})"
      elsif arg.is_a?(String) then "'#{arg[0, 40]}'"
      else arg.to_s[0, 40]
      end
    end.join(" ")
  rescue
    "?"
  end

  # Takes a change of the leader's story scene: the player sees it while on the leader's map or on
  # the way there, since the screen keeps its pictures and tint through a transfer.
  # Called by coop.rbx, which drops another party's, or by coop_scope.rbx, which drops another map's.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who sent it.
  # @param message [Hash] The message, the change under "pscene".
  def self.take(peer, message)
    kind = message["pscene"].to_s
    unless MGQ_MpCoop::Scope.story_from?(peer)
      return log_once([:not_leader, kind, peer.state["id"]], "ignored #{kind} from #{MGQ_MpOverworldSync.who(peer)}: not the one who tells the story")
    end
    unless MGQ_MpCoop::Scope.watches?(peer)
      return log_once([:not_following, kind, peer.state["id"]], "ignored #{kind} from #{MGQ_MpOverworldSync.who(peer)}: the player plays their own story")
    end
    unless MGQ_MpCoopGather.story_map?(message["map"].to_i)
      return log("ignored #{kind} on map #{message['map']}: the player is on map #{$game_map.map_id}")
    end

    args = MGQ_MpBattlesSync::Wire.parse(message["args"].to_s) { nil }
    return log("ignored #{kind}: its arguments did not read (#{message['args'].to_s.size} characters)") unless args

    apply(kind, Array(args))
  rescue => e
    log_once(:take, "showing the leader's scene failed: #{e.class}: #{e.message}")
  end

  # Makes one change of the leader's story scene on the player's map screen, noting what to put
  # back once the story ended.
  #
  # The names came from another game, so they are compared as text and never made symbols.
  #
  # @param kind [String] What changes, such as "picture.show".
  # @param args [Array] Its arguments.
  def self.apply(kind, args)
    @changed_at = Graphics.frame_count
    target, method = kind.split(".", 2)
    case target
    when "picture"
      apply_picture(method, args)
    when "screen"
      name = SCREEN_METHODS.find { |known| known.to_s == method }
      return log_once([:unknown, kind], "ignored #{kind}: this game's screen has no such change") unless name && $game_map.screen.respond_to?(name)

      unless @screen
        @screen = { :map => $game_map.map_id, :tone => copy_tone($game_map.screen.tone) }
        log("noted the screen's tone #{describe([@screen[:tone]])} on map #{@screen[:map]} to put back after the story")
      end
      $game_map.screen.send(name, *args)
      log("applied the leader's #{kind} #{describe(args)}")
    when "player"
      return log_once([:unknown, kind], "ignored #{kind}: no such change") unless method == "transparent"

      @transparent = $game_player.transparent if @transparent.nil?
      $game_player.transparent = args[0] ? true : false
      log("applied the leader's #{kind}: the player's character is #{args[0] ? 'hidden' : 'shown'}")
    else
      log_once([:unknown, kind], "ignored #{kind}: no such change")
    end
  end

  # Changes a picture of the player's map screen as the leader's story did.
  #
  # @param method [String] What happens to it, see PICTURE_METHODS.
  # @param args [Array] The picture's number, then the method's arguments.
  def self.apply_picture(method, args)
    name = PICTURE_METHODS.find { |known| known.to_s == method }
    number = args[0].to_i
    return log("ignored picture.#{method} of picture #{number}: no such change or picture") unless name && number > 0 && number <= MAX_PICTURE
    return log("ignored showing picture #{number}: '#{args[1].to_s[0, 40]}' is no picture's file name") if name == :show && args[1].to_s !~ PICTURE_NAME

    @pictures |= [number]
    $game_map.screen.pictures[number].send(name, *args[1..-1])
    log("applied the leader's picture.#{method} #{describe(args)}")
  end

  # Reports whether the player sees the leader's story scene now: in a party whose leader tells
  # the story on the player's map, or in a Raid World while the teller there tells a story that
  # matches the player's.
  #
  # @return [Boolean] Whether they do.
  def self.watching?
    lead = MGQ_MpCoop::Scope.teller
    lead.is_a?(MGQ_MpOverworldSync::Peers::Peer) && lead.state["telling"] == "1" && MGQ_MpCoopGather.story_map?(lead.state["map"].to_i) &&
      MGQ_MpCoop::Scope.watches?(lead)
  end

  # Puts the player's screen back once they no longer see the leader's story scene. Called after
  # the map's update.
  def self.update
    return if !pending? || watching? || just_changed?

    restore(why_not_watching)
  rescue => e
    log_once(:restore, "putting the screen back failed: #{e.class}: #{e.message}")
    forget("putting it back failed")
  end

  # Reports whether a change of the leader's scene came only a moment ago, which the leader's state
  # that says the story plays may still follow.
  #
  # @return [Boolean] Whether it did.
  def self.just_changed?
    elapsed = Graphics.frame_count - @changed_at.to_i
    elapsed >= 0 && elapsed < STATE_GRACE_FRAMES
  end

  # Copies a tone, which the screen changes in place.
  #
  # @param tone [Tone] The tone.
  # @return [Tone] The copy.
  def self.copy_tone(tone)
    Tone.new(tone.red, tone.green, tone.blue, tone.gray)
  end

  # Tells why the player no longer sees the leader's story scene, for the log.
  #
  # @return [String] The reason.
  def self.why_not_watching
    lead = MGQ_MpCoop::Scope.teller
    return "nobody else tells the story" unless lead.is_a?(MGQ_MpOverworldSync::Peers::Peer)
    return "#{lead.state['name']}'s story ended" unless lead.state["telling"] == "1"

    "#{lead.state['name']} tells it on map #{lead.state['map']}, the player is on map #{$game_map.map_id}"
  rescue
    "?"
  end

  # Erases the pictures the leader's story showed, brings the screen back and the player's own
  # character as it was: the tint the player's map had, or the story's last on a map the story
  # brought them to.
  #
  # @param reason [String] Why, for the log.
  def self.restore(reason = "the story ended")
    screen = $game_map.screen
    @pictures.each { |number| screen.pictures[number].erase }
    done = ["erased picture(s) #{@pictures.empty? ? 'none' : @pictures.sort.join(', ')}"]
    if @screen
      screen.clear_flash if screen.respond_to?(:clear_flash)
      screen.clear_shake if screen.respond_to?(:clear_shake)
      if @screen[:map] == $game_map.map_id
        screen.start_tone_change(@screen[:tone], RESTORE_FRAMES)
        done << "tone back to #{describe([@screen[:tone]])}"
      else
        done << "kept the story's tone, on map #{$game_map.map_id} instead of #{@screen[:map]}"
      end
      if screen.brightness < 255
        screen.start_fadein(RESTORE_FRAMES)
        done << "faded in"
      end
    end
    unless @transparent.nil?
      $game_player.transparent = @transparent
      done << "character #{@transparent ? 'hidden' : 'shown'} again"
    end
    log("put the screen back, since #{reason}: #{done.join(', ')}")
    forget
  end

  # Reports whether anything of the leader's scene waits to be put back.
  #
  # @return [Boolean] Whether it does.
  def self.pending?
    !(@pictures.empty? && @screen.nil? && @transparent.nil?)
  end

  # Forgets what to put back, as when a save is loaded, which brings its own screen.
  #
  # @param reason [String, nil] Why it is not put back, for the log; nil once it was.
  def self.forget(reason = nil)
    log("forgot the leader's scene without putting it back: #{reason}") if reason && pending?
    @pictures = []
    @screen = nil
    @transparent = nil
    @changed_at = nil
  end
end

# What this script takes part in of the party's messages, through coop.rbx, and of the map's in a
# Raid World, through coop_scope.rbx.

begin
  MGQ_MpCoop.route("pscene") { |peer, message| MGQ_MpCoopScene.take(peer, message) }
  MGQ_MpCoop.route_map("pscene") { |peer, message| MGQ_MpCoopScene.take(peer, message) }
rescue => e
  MGQ_MpCoopScene.log("co-op FAILED: #{e.class}: #{e.message}")
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # Around an interpreter's update, which interpreter runs its commands.
  MGQ_MpHooks.before(Game_Interpreter, :update, "coop_scene") { MGQ_MpCoopScene.updating(self) }
  MGQ_MpHooks.after(Game_Interpreter, :update, "coop_scene") { MGQ_MpCoopScene.updated }

  MGQ_MpCoopScene::PICTURE_METHODS.each do |name|
    MGQ_MpHooks.before(Game_Picture, name, "coop_scene") { |*args| MGQ_MpCoopScene.picture(self, name, args) }
  end
  MGQ_MpCoopScene::SCREEN_METHODS.select { |name| Game_Screen.method_defined?(name) }.each do |name|
    MGQ_MpHooks.before(Game_Screen, name, "coop_scene") { |*args| MGQ_MpCoopScene.screen(self, name, args) }
  end
  MGQ_MpHooks.after(Game_Player, :transparent=, "coop_scene") { |hidden| MGQ_MpCoopScene.transparency(self, hidden) }

  # After the map's update, the member's screen comes back once the leader's story ended.
  MGQ_MpHooks.after(Game_Map, :update, "coop_scene") { MGQ_MpCoopScene.update }

  # After a loaded save, which brings its own screen, the leader's scene is forgotten.
  MGQ_MpHooks.after(DataManager.singleton_class, :extract_save_contents, "coop_scene") { |_contents| MGQ_MpCoopScene.forget("a save was loaded") }
rescue => e
  MGQ_MpCoopScene.log("hooks FAILED: #{e.class}: #{e.message}")
end
