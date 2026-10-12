#----------------------------------------------------------------
#  coop_scene.rbx
#
#  Changelog:
#      Paulinchen  2026-10-12: Left out the teller's picture and screen changes whose arguments this game cannot take, and erased the picture's place instead of showing a picture this game lacks, either of which ended the viewer's game
#      Paulinchen  2026-10-11: Let the catch-up follow the teller's story values as a story laid over the viewer's, so a viewer gets what the watched scene gave and loses the key items it took
#                            - Told the viewers the switches that only stay on while a scene runs, which are each player's own, and put them back once the viewer no longer sees the scene
#                            - Let the teller's move routes skip a blocked step and ended the one the player's character walks once the viewer no longer sees the scene, so it never holds the player for good
#                            - Kept the character shown or hidden as the story left it once it brought the viewer to another map, so a new game's hidden start no longer hides them again
#                            - Told the viewers the story's music, background sounds, fanfares and sound effects, played, stopped and faded with the game's defaults for what the story left out, which a viewer plays on the teller's map screen alone, holding the music for when they are there, and its changes of the map's tileset, battle backgrounds and parallax
#                            - Told a Raid World's viewers the switches, variables and self switches the story changes once a frame, so their games show the scene's characters on the pages the story turns on and keep watching the telling, without writing them as their own story
#                            - Told the move routes the story gives the map's events and the player's character, without their scripts, and the animations, balloons and erasures it shows on them, so the viewers see the characters move and react, their own character walking the teller's route without starting what it touches
#                            - Told where the teller's camera stands while the story plays, which the viewers' cameras ease to, and the game's map zoom, putting both back once the viewer no longer sees the scene
#                            - Told whether the commands running now are the map's main event's, a common event it calls included
#      Paulinchen  2026-10-09: Told each change of the scene to a Raid World's viewers in one message instead of one per viewer
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
# screen's fades, tints, flashes and shakes, whether the leader's character is hidden, as on a
# theater show's stage, the move routes, animations, balloons and erasures of the map's events, its
# music and sounds, the map's tileset, battle backgrounds and parallax, and
# in a Raid World the story's switches and variables as they change, which turn the scene's
# characters' pages on. While the story plays, the leader's game tells the party each change the
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

  # The largest place, zoom, opacity or turning speed another game may name for a picture, either
  # way; a larger one or Infinity raises in the game's sprites every frame.
  MOST_AMOUNT = 100_000

  # The longest change of a picture or the screen another game may name, in frames: ten minutes.
  MOST_FRAMES = 36_000

  # The strongest and fastest shake of the screen another game may name, the editor's own range.
  MOST_SHAKE = 9

  # The kind of each argument a picture's change takes, by the change, see arg_fits?.
  PICTURE_ARGS = {
    :show => [:name, :origin, :amount, :amount, :amount, :amount, :amount, :blend],
    :move => [:origin, :amount, :amount, :amount, :amount, :amount, :blend, :frames],
    :rotate => [:amount],
    :start_tone_change => [:tone, :frames],
    :erase => []
  }

  # The kind of each argument a change of the screen takes, by the change, see arg_fits?.
  SCREEN_ARGS = {
    :start_fadeout => [:frames],
    :start_fadein => [:frames],
    :start_tone_change => [:tone, :frames],
    :start_flash => [:color, :frames],
    :start_shake => [:shake, :shake, :frames],
    :od_fadein => [],
    :od_fadeout => []
  }

  # Frames the member's screen takes to come back once the story ended.
  RESTORE_FRAMES = 30

  # Frames a change of the leader's scene stays before the leader's state says the story plays,
  # two seconds, since the leader's state and the changes travel apart.
  STATE_GRACE_FRAMES = 120

  # The kinds of story values the teller tells, by the number each travels as: switches, variables
  # and self switches, as MGQ_MpWorldStory names them.
  VALUE_KINDS = { 0 => "switch", 1 => "variable", 2 => "self switch" }

  # The highest move route command a viewer's game runs: every one but a script (45), since another
  # game must never run code in this one.
  LAST_ROUTE_CODE = 44

  # Move route commands whose first argument is a file: a character's graphic and a sound.
  GRAPHIC_CODE = 41
  SOUND_CODE = 44

  # A character's or sound's file name another game names, which must stay inside its folder.
  FILE_NAME = /\A(?!.*\.\.)[^\/\\:*?"<>|]{1,100}\z/

  # The endings a sound's file may have in Audio/SE, which a sound another game names must have one
  # of, since the game ends with an error on a sound it cannot find.
  SOUND_ENDINGS = %w(.ogg .wav .mp3 .mid .wma)

  # The character a story's command names for the player, rather than an event.
  PLAYER_CHARACTER = -1

  # The game's audio folders by the kind of sound, which the teller's Audio calls name and a
  # viewer's game plays from.
  AUDIO_FOLDERS = { "bgm" => "Audio/BGM/", "bgs" => "Audio/BGS/", "me" => "Audio/ME/", "se" => "Audio/SE/" }

  # What a viewer's game does with each of the teller's Audio calls: play, stop or fade a kind.
  AUDIO_CALLS = %w(bgm_play bgm_stop bgm_fade bgs_play bgs_stop bgs_fade me_play me_stop me_fade se_play se_stop)

  # The volume, pitch and for music the position the game's Audio calls take by each kind of sound
  # when the story names none, which the viewers are told along.
  AUDIO_DEFAULTS = { "bgm" => [100, 100, 0], "bgs" => [100, 100, 0], "me" => [100, 100], "se" => [100, 100] }

  # The kinds of sound that last, which a viewer away from the teller's map screen hears once there.
  LASTING_SOUNDS = %w(bgm bgs)

  # Changes of the map's look a story makes, which a viewer makes on the teller's map alone.
  MAP_LOOKS = %w(tileset battleback parallax)

  # Frames between two places of the teller's camera told at most, a tenth of a second.
  CAMERA_FRAMES = 6

  # Steps per tile the camera's place is told in.
  CAMERA_STEPS = 32

  # Tiles a viewer's camera jumps over at once; nearer, it eases toward the teller's place, a
  # CAMERA_EASE-th of the way each frame.
  CAMERA_JUMP = 4
  CAMERA_EASE = 4

  # The map zoom of none and the largest, in percent, as the game's map_zoom keeps to them.
  NO_ZOOM = 100
  MOST_ZOOM = 2000

  @pictures = []
  @values = {}
  @screen = nil
  @transparent = nil
  @updating = []
  @held_audio = {}
  @scene_switches = {}

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

    map_turn?
  end

  # Reports whether the commands running now are the map's main event's, those of a common event it
  # calls included, which the game runs in an interpreter of its own inside the main one's update.
  #
  # @return [Boolean] Whether they are.
  def self.map_turn?
    $game_map && @updating.last.equal?($game_map.interpreter) ? true : false
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

  # As teller in a Raid World, keeps a change the story makes to a switch, variable or self switch,
  # which send_values tells the viewers at the frame's end: their games show the scene's characters
  # on the pages the story turns on, which the world's story brings only once the telling ended.
  # What is each player's own, but a scene switch (MGQ_MpStoryState.scene_switch?), and a variable
  # that holds no whole number, stays out.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id, or a self switch's map, event and letter.
  # @param value [Object] Its value now.
  def self.story_value(kind, key, value)
    return unless MGQ_MpCoop::Scope.raid? && story_change?
    return if kind == 1 && !value.is_a?(Integer)
    return if MGQ_MpWorldStory.personal?(kind, key) && !scene_value?(kind, key)

    @values.delete([kind, key])
    @values[[kind, key]] = kind == 1 ? value : (value ? true : false)
  rescue => e
    log_once(:value, "keeping a story value for the viewers failed: #{e.class}: #{e.message}")
  end

  # As teller, tells the viewers the story's values that changed this frame in one message, see
  # story_value.
  def self.send_values
    return if @values.empty?

    values = @values.map { |(kind, key), value| [kind, key, value] }
    @values = {}
    send_change("story.values", values)
    MGQ_MpCoop::Scope::Raid.sent_values_to(MGQ_MpCoop::Scope.viewers)
  end

  # As teller, tells the viewers a move route the story gives an event of the map or the player's
  # character, so the character walks, turns and changes in their games as in the teller's, and
  # the camera, which follows the player's character, moves as the teller's; a script in it stays
  # out (see LAST_ROUTE_CODE). A viewer's own character takes the player's route, see walks_player?.
  #
  # @param character [Game_Character] The character the route moves.
  # @param route [RPG::MoveRoute] The route.
  def self.route(character, route)
    target = character.equal?($game_player) ? PLAYER_CHARACTER : nil
    target = character.id if character.is_a?(Game_Event) && $game_map.events[character.id].equal?(character)
    return unless target && story_change?

    commands = route.list.map { |command| route_entry(command) }.compact
    send_change("event.route", [target, route.repeat ? true : false, route.skippable ? true : false, commands])
  rescue => e
    log_once(:route, "telling a move route failed: #{e.class}: #{e.message}")
  end

  # As teller, tells the viewers where the map's camera stands while the story plays, once it moved
  # and CAMERA_FRAMES after the last time at most: the story's scrolls and the camera following the
  # player's character. A scroll alone moves a viewer's camera from where their own character
  # stands, so the place itself goes.
  def self.send_camera
    return @camera = nil unless MGQ_MpCoopEvents.story_playing? && MGQ_MpCoopEvents.leading_story? && SceneManager.scene.is_a?(Scene_Map)

    now = [$game_map.display_x, $game_map.display_y].map { |value| (value * CAMERA_STEPS).round.to_f / CAMERA_STEPS }
    return if now == @camera || (@camera && !past_frames?(@camera_at, CAMERA_FRAMES))

    @camera = now
    @camera_at = Graphics.frame_count
    send_change("map.camera", now, false)
  rescue => e
    log_once(:camera, "telling the map's camera failed: #{e.class}: #{e.message}")
  end

  # Reports whether some frames passed since a frame; a loaded save sets the count back, which
  # counts as passed.
  #
  # @param since [Integer] The frame.
  # @param frames [Integer] The frames.
  # @return [Boolean] Whether they did.
  def self.past_frames?(since, frames)
    elapsed = Graphics.frame_count - since.to_i
    elapsed < 0 || elapsed >= frames
  end

  # As teller, tells the viewers a sound the story plays, stops or fades: its music (BGM), its
  # background sound (BGS), its fanfares (ME) and its sound effects (SE), whichever way the story
  # reaches the game's Audio. A sound is named by its file without the folder, and goes with every
  # argument, the game's defaults for those the story left out.
  #
  # @param call [String] The Audio call, one of AUDIO_CALLS.
  # @param args [Array] Its arguments: the file, volume, pitch and for music the position; the time
  #   of a fade; none for a stop.
  def self.audio(call, args)
    return unless story_change?

    if call.end_with?("_play")
      kind = call.split("_")[0]
      folder = AUDIO_FOLDERS[kind]
      name = args[0].to_s
      return unless name.start_with?(folder)

      given = args[1..-1].map(&:to_i)
      args = [name[folder.size..-1]] + given + AUDIO_DEFAULTS[kind][given.size..-1].to_a
    end
    send_change("audio.#{call}", args.map { |arg| arg.is_a?(Numeric) ? arg.to_i : arg }, !call.start_with?("se_"))
  rescue => e
    log_once([:audio, call], "telling a sound failed: #{e.class}: #{e.message}")
  end

  # As teller, tells the viewers a change of the map's look the story makes: its tileset, its battle
  # backgrounds or its parallax.
  #
  # @param map [Game_Map] The map.
  # @param look [String] What changes, one of MAP_LOOKS.
  # @param args [Array] The change's arguments, as the game's change_tileset, change_battleback and
  #   change_parallax take them.
  def self.map_look(map, look, args)
    send_change("map.#{look}", args) if map.equal?($game_map) && story_change?
  rescue => e
    log_once([:map_look, look], "telling the map's #{look} failed: #{e.class}: #{e.message}")
  end

  # As teller, tells the viewers the story's zoom of the map (the game's map_zoom script).
  #
  # @param rate [Integer] The zoom in percent, 100 for none.
  def self.zoom(rate)
    send_change("map.zoom", [rate.to_i]) if story_change?
  rescue => e
    log_once(:zoom, "telling the map's zoom failed: #{e.class}: #{e.message}")
  end

  # Writes a move route command for the wire: its code and arguments, a sound's by its file,
  # volume and pitch.
  #
  # @param command [RPG::MoveCommand] The command.
  # @return [Array, nil] The code and arguments, nil for a script.
  def self.route_entry(command)
    return nil if command.code > LAST_ROUTE_CODE

    params = command.parameters
    return [SOUND_CODE, params[0].name.to_s, params[0].volume.to_i, params[0].pitch.to_i] if command.code == SOUND_CODE

    [command.code] + params
  end

  # As teller, tells the viewers an animation or balloon the story shows on the player's character
  # or an event of the map; on a viewer's screen the player's shows on their own character.
  #
  # @param character [Game_Character] The character.
  # @param kind [String] "animation" or "balloon".
  # @param id [Integer] The animation's or balloon's id, 0 for none.
  def self.effect(character, kind, id)
    return unless id.to_i > 0 && story_change?

    target = character.equal?($game_player) ? PLAYER_CHARACTER : nil
    target = character.id if character.is_a?(Game_Event) && $game_map.events[character.id].equal?(character)
    send_change("event.#{kind}", [target, id.to_i]) if target
  rescue => e
    log_once(:effect, "telling an #{kind} failed: #{e.class}: #{e.message}")
  end

  # As teller, tells the viewers that the story erased an event of the map.
  #
  # @param event [Game_Event] The event.
  def self.erased(event)
    send_change("event.erase", [event.id]) if $game_map.events[event.id].equal?(event) && story_change?
  rescue => e
    log_once(:erase, "telling an erased event failed: #{e.class}: #{e.message}")
  end

  # Sends the party one change of the story's scene, with the map it happens on.
  #
  # @param kind [String] What changes, such as "picture.show".
  # @param args [Array] Its arguments.
  # @param logged [Boolean] Whether it is logged, false for one that goes several times a second.
  def self.send_change(kind, args, logged = true)
    return log_once([:unsendable, kind], "did not tell the party #{kind}: its arguments do not go over the wire (#{describe(args)})") unless MGQ_MpBattlesSync::Wire.encodable?(args)

    followers = MGQ_MpCoop::Scope.viewers
    return if followers.empty?

    sent = MGQ_MpCoop::Scope.tell_each(followers, "pscene", kind, "map" => $game_map.map_id, "args" => MGQ_MpBattlesSync::Wire.line(args))
    log("told #{followers.map { |peer| peer.state['name'] }.join(', ')} #{kind} #{describe(args)} on map #{$game_map.map_id}#{sent ? '' : ', which failed for some'}") if logged || !sent
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
    # An event is named by its id on the teller's map, which another map's event may share, the
    # camera's place is the teller's map's, and a fanfare or sound effect is over before the player
    # arrives.
    if (kind.start_with?("event.") || kind == "map.camera" || MAP_LOOKS.include?(kind.sub("map.", "")) || kind =~ /\Aaudio\.(me|se)_/) &&
       message["map"].to_i != $game_map.map_id
      return log("ignored #{kind} on map #{message['map']}: the player is still on the way, on map #{$game_map.map_id}")
    end

    args = MGQ_MpBattlesSync::Wire.parse(message["args"].to_s) { nil }
    return log("ignored #{kind}: its arguments did not read (#{message['args'].to_s.size} characters)") unless args

    # The values move the player's story past where the telling started, which ended their watching.
    MGQ_MpCoop::Scope::Raid.takes_values(peer) if kind == "story.values" && MGQ_MpCoop::Scope.raid?
    apply(kind, Array(args), message["map"].to_i)
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
  # @param map [Integer] The teller's map it happened on.
  def self.apply(kind, args, map = $game_map.map_id)
    @changed_at = Graphics.frame_count
    target, method = kind.split(".", 2)
    case target
    when "picture"
      apply_picture(method, args)
    when "screen"
      name = SCREEN_METHODS.find { |known| known.to_s == method }
      return log_once([:unknown, kind], "ignored #{kind}: this game's screen has no such change") unless name && $game_map.screen.respond_to?(name)
      return log_once([:screen_args, name], "ignored #{kind} #{describe(args)}: arguments this game cannot take") unless args_fit?(SCREEN_ARGS[name], args)

      unless @screen
        @screen = { :map => $game_map.map_id, :tone => copy_tone($game_map.screen.tone) }
        log("noted the screen's tone #{describe([@screen[:tone]])} on map #{@screen[:map]} to put back after the story")
      end
      $game_map.screen.send(name, *args)
      log("applied the leader's #{kind} #{describe(args)}")
    when "player"
      return log_once([:unknown, kind], "ignored #{kind}: no such change") unless method == "transparent"

      if @transparent.nil?
        @transparent = $game_player.transparent
        @transparent_map = $game_map.map_id
      end
      $game_player.transparent = args[0] ? true : false
      log("applied the leader's #{kind}: the player's character is #{args[0] ? 'hidden' : 'shown'}")
    when "story"
      return log_once([:unknown, kind], "ignored #{kind}: no such change") unless method == "values"

      apply_values(args)
    when "event"
      apply_event(method, args)
    when "audio"
      apply_audio(method, args, map)
    when "map"
      apply_map(method, args)
    else
      log_once([:unknown, kind], "ignored #{kind}: no such change")
    end
  end

  # Changes a picture of the player's map screen as the leader's story did. A picture this game
  # lacks erases the picture's place instead, so an older one there is not moved in its stead.
  #
  # The game's sprites load the picture with no rescue, so one this game lacks would end the game.
  #
  # @param method [String] What happens to it, see PICTURE_METHODS.
  # @param args [Array] The picture's number, then the method's arguments.
  def self.apply_picture(method, args)
    name = PICTURE_METHODS.find { |known| known.to_s == method }
    number = args[0].to_i
    return log("ignored picture.#{method} of picture #{number}: no such change or picture") unless name && number > 0 && number <= MAX_PICTURE
    return log_once([:picture_args, name], "ignored picture.#{method} #{describe(args)}: arguments this game cannot take") unless args_fit?(PICTURE_ARGS[name], args[1..-1])
    return log("ignored showing picture #{number}: '#{args[1].to_s[0, 40]}' is no picture's file name") if name == :show && args[1] !~ PICTURE_NAME

    @pictures |= [number]
    if name == :show && !map_graphics?([[:picture, args[1]]])
      $game_map.screen.pictures[number].erase
      return log_once([:no_picture, args[1][0, 40]], "erased picture #{number} instead of showing '#{args[1][0, 40]}': this game has no such picture")
    end
    $game_map.screen.pictures[number].send(name, *args[1..-1])
    log("applied the leader's picture.#{method} #{describe(args)}")
  end

  # Reports whether the arguments another game sent for a change of a picture or the screen are
  # ones this game takes: as many as the change takes, each of its kind and within the limits.
  #
  # The game keeps them and uses them each frame, where a wrong one ends the game outside every
  # rescue of the mod.
  #
  # @param kinds [Array<Symbol>, nil] The kind of each argument, see PICTURE_ARGS and SCREEN_ARGS.
  # @param args [Array] The arguments.
  # @return [Boolean] Whether they are, never raising.
  def self.args_fit?(kinds, args)
    kinds.size == args.size && kinds.zip(args).all? { |kind, value| arg_fits?(kind, value) }
  rescue
    false
  end

  # Reports whether one argument another game sent is of its kind and within the limits: a finite
  # amount up to MOST_AMOUNT either way, whole frames up to MOST_FRAMES, a whole origin, a blend
  # type of 0 to 2, a tone, a color, a shake up to MOST_SHAKE, or a name.
  #
  # @param kind [Symbol] The argument's kind, as PICTURE_ARGS and SCREEN_ARGS name it.
  # @param value [Object] The argument.
  # @return [Boolean] Whether it is, never raising.
  def self.arg_fits?(kind, value)
    case kind
    when :amount then number?(value) && value.abs <= MOST_AMOUNT
    when :frames then number?(value) && value == value.floor && value >= 0 && value <= MOST_FRAMES
    when :origin then value.is_a?(Integer)
    when :blend then value.is_a?(Integer) && value >= 0 && value <= 2
    when :tone then value.is_a?(Tone)
    when :color then value.is_a?(Color)
    when :shake then number?(value) && value >= 0 && value <= MOST_SHAKE
    when :name then value.is_a?(String)
    else false
    end
  rescue
    false
  end

  # Reports whether a value is a whole or finite number.
  #
  # @param value [Object] The value.
  # @return [Boolean] Whether it is.
  def self.number?(value)
    value.is_a?(Integer) || (value.is_a?(Float) && value.finite?)
  end

  # Lays the teller's story values over the player's while they watch, see story_value: what is
  # the player's own stays, and the world's story takes each as the world's
  # (MGQ_MpWorldStory.mirrored), so none is written as the player's own change. A scene switch is
  # taken too, with its value before noted for restore. The catch-up keeps the player's story from
  # before (MGQ_MpWorldCatchup.watched) to follow the values as a story laid over theirs. A Classic
  # party's members get the leader's values through coop_story.rbx instead.
  #
  # @param entries [Array<Array>] Each value's kind, key and value.
  def self.apply_values(entries)
    return log_once(:classic_values, "ignored story values: only a Raid World's teller tells them") unless MGQ_MpCoop::Scope.raid?

    taken = entries.select { |entry| value_known?(entry) && (!MGQ_MpWorldStory.personal?(entry[0], entry[1]) || scene_value?(entry[0], entry[1])) }
    if defined?(MGQ_MpWorldCatchup) && taken.any? { |kind, key, _value| !scene_value?(kind, key) }
      MGQ_MpWorldCatchup.watched { MGQ_MpStoryState.deep_copy(MGQ_MpWorldCatchup.story_now) }
    end
    taken.each do |kind, key, value|
      value = kind == 1 ? value : (value ? true : false)
      if scene_value?(kind, key)
        @scene_switches[key] = $game_switches[key] ? true : false unless @scene_switches.key?(key)
        $game_switches[key] = value
        next
      end
      case kind
      when 0 then $game_switches[key] = value
      when 1 then $game_variables[key] = value
      else $game_self_switches[key] = value
      end
      MGQ_MpWorldStory.mirrored(kind, key, value)
    end
    log("applied the teller's #{taken.size} of #{entries.size} story value(s): " \
        "#{taken.first(6).map { |kind, key, value| "#{VALUE_KINDS[kind]} #{Array(key).join('.')}=#{value}" }.join(', ')}#{taken.size > 6 ? ', ...' : ''}")
  end

  # Reports whether a story value is a scene switch, which the scene's viewers see though it is each
  # player's own.
  #
  # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
  # @param key [Integer, Array] Its id, or a self switch's map, event and letter.
  # @return [Boolean] Whether it is.
  def self.scene_value?(kind, key)
    kind == 0 && MGQ_MpStoryState.scene_switch?(key)
  end

  # Reports whether a story value another game sent names one of this game's switches, variables
  # or self switches, with a value of its kind.
  #
  # @param entry [Object] The value's kind, key and value.
  # @return [Boolean] Whether it does.
  def self.value_known?(entry)
    return false unless entry.is_a?(Array) && entry.size == 3

    kind, key, value = entry
    case kind
    when 0 then key.is_a?(Integer) && MGQ_MpStoryState.known_id?(:switches, key)
    when 1 then key.is_a?(Integer) && value.is_a?(Integer) && MGQ_MpStoryState.known_id?(:variables, key)
    when 2 then key.is_a?(Array) && key.size == 3 && key[0].is_a?(Integer) && key[1].is_a?(Integer) && %w(A B C D).include?(key[2])
    else false
    end
  end

  # Shows on the player's map what the teller's story did to an event: a move route, an animation
  # or balloon, or its erasure. The player's own character takes what the story showed on the
  # teller's.
  #
  # @param method [String] What happened: "route", "animation", "balloon" or "erase".
  # @param args [Array] The event's id first, see route, effect and erased.
  def self.apply_event(method, args)
    id = args[0].to_i
    character = id == PLAYER_CHARACTER && method != "erase" ? $game_player : $game_map.events[id]
    return log("ignored event.#{method} of event #{id}: no such event on map #{$game_map.map_id}") unless character

    case method
    when "route" then apply_route(character, args)
    when "animation", "balloon"
      effect_id = args[1].to_i
      known = method == "animation" ? effect_id < $data_animations.size : effect_id <= 10
      return log("ignored event.#{method} #{effect_id}: no such #{method}") unless effect_id > 0 && known

      method == "animation" ? character.animation_id = effect_id : character.balloon_id = effect_id
      log("applied the teller's #{method} #{effect_id} on #{id == PLAYER_CHARACTER ? "the player's character" : "event #{id}"}")
    when "erase"
      character.erase
      log("applied the teller's erasure of event #{id}")
    else
      log_once([:unknown, method], "ignored event.#{method}: no such change")
    end
  end

  # Moves the player's map camera as the teller's story did: to the teller's camera's place
  # (`map.camera`, x and y in tiles, which follow_camera eases toward) or the game's map zoom
  # (`map.zoom`, 100 to 2000 percent, which the game's map_zoom keeps to), noting the zoom to put
  # back.
  #
  # @param method [String] "camera" or "zoom".
  # @param args [Array] The camera's x and y, or the zoom.
  def self.apply_map(method, args)
    case method
    when "camera"
      return log_once([:camera, args.size], "ignored map.camera #{describe(args)}: no place") unless args.size == 2 && args.all? { |value| value.is_a?(Numeric) }

      log("follows the teller's camera on map #{$game_map.map_id}, from #{describe(args)}") unless @camera_target
      @camera_target = [args[0].to_f, args[1].to_f, $game_map.map_id]
    when *MAP_LOOKS
      apply_map_look(method, args)
    when "zoom"
      return log_once([:no_zoom], "ignored map.zoom: this game has no map zoom") unless $game_system.respond_to?(:zoom_mode=)

      @zoom = $game_system.zoom_mode if @zoom.nil?
      $game_system.zoom_mode = [[args[0].to_i, NO_ZOOM].max, MOST_ZOOM].min
      log("applied the teller's map.zoom #{$game_system.zoom_mode}")
    else
      log_once([:unknown, method], "ignored map.#{method}: no such change")
    end
  end

  # Plays, stops or fades a sound as the teller's story did, see audio, on the teller's map screen
  # alone: a battle or menu brings its own music back as it ends, and a transfer's autoplay replaces
  # what played on the way, so music and background sounds wait there (see hold_audio). A file
  # this game cannot play is left out, which the game would otherwise stop at.
  #
  # @param call [String] The Audio call, one of AUDIO_CALLS.
  # @param args [Array] Its arguments, see audio.
  # @param map [Integer] The teller's map it happened on.
  def self.apply_audio(call, args, map = $game_map.map_id)
    return log_once([:unknown, call], "ignored audio.#{call}: no such call") unless AUDIO_CALLS.include?(call)

    kind, action = call.split("_")
    return hold_audio(kind, call, args, map) unless map == $game_map.map_id && SceneManager.scene.is_a?(Scene_Map)

    sound = { "bgm" => RPG::BGM, "bgs" => RPG::BGS, "me" => RPG::ME, "se" => RPG::SE }[kind]
    case action
    when "play"
      name = args[0].to_s
      return log("ignored audio.#{call}: '#{name[0, 40]}' is no sound's file name") unless name =~ FILE_NAME

      volume, pitch = AUDIO_DEFAULTS[kind]
      file = sound.new(name, args.fetch(1, volume).to_i, args.fetch(2, pitch).to_i)
      kind == "bgm" || kind == "bgs" ? file.play(args[3].to_i) : file.play
    when "stop" then sound.stop
    else sound.fade(args[0].to_i)
    end
    log("applied the teller's audio.#{call} #{describe(args)}") unless kind == "se"
  rescue => e
    log_once([:apply_audio, call, args[0]], "playing the teller's audio.#{call} #{describe(args)} failed: #{e.class}: #{e.message}")
  end

  # Keeps the teller's last music or background sound for when the player is on the teller's map
  # screen, see play_held; a fanfare or sound effect is over by then and is left out.
  #
  # @param kind [String] The kind of sound, see AUDIO_FOLDERS.
  # @param call [String] The Audio call, one of AUDIO_CALLS.
  # @param args [Array] Its arguments, see audio.
  # @param map [Integer] The teller's map it happened on.
  def self.hold_audio(kind, call, args, map)
    return unless LASTING_SOUNDS.include?(kind)

    @held_audio[kind] = [call, args, map]
    log("held the teller's audio.#{call} #{describe(args)} until the player is on map #{map}'s screen")
  end

  # Plays the teller's music and background sound held for the player's map screen, see hold_audio,
  # once the player is there.
  def self.play_held
    return if @held_audio.empty? || !SceneManager.scene.is_a?(Scene_Map)

    @held_audio.keys.each do |kind|
      call, args, map = @held_audio[kind]
      next unless map == $game_map.map_id

      @held_audio.delete(kind)
      apply_audio(call, args, map)
    end
  end

  # Changes the map's look as the teller's story did, see map_look: a tileset of the game's, battle
  # backgrounds and a parallax this game has.
  #
  # @param look [String] What changes, one of MAP_LOOKS.
  # @param args [Array] The change's arguments.
  def self.apply_map_look(look, args)
    case look
    when "tileset"
      id = args[0]
      return log("ignored map.tileset #{id.inspect}: no such tileset") unless id.is_a?(Integer) && id > 0 && id < $data_tilesets.size && $data_tilesets[id]

      $game_map.change_tileset(id)
    when "battleback"
      names = args[0, 2].map(&:to_s)
      return log("ignored map.battleback #{describe(args)}: no such pictures") unless map_graphics?([:battleback1, :battleback2].zip(names))

      $game_map.change_battleback(*names)
    else
      name = args[0].to_s
      return log("ignored map.parallax #{describe(args)}: no such picture") unless map_graphics?([[:parallax, name]]) && args[1, 4].all? { |value| value.is_a?(Integer) || value == true || value == false }

      $game_map.change_parallax(name, *args[1, 4])
    end
    log("applied the teller's map.#{look} #{describe(args)}")
  end

  # Reports whether this game has the map's pictures another game named: none for an empty name,
  # else a file name without a path that this game has.
  #
  # @param graphics [Array<Array>] Each picture's Cache folder and file name.
  # @return [Boolean] Whether it has them all.
  def self.map_graphics?(graphics)
    graphics.all? { |folder, name| name.empty? || (name =~ FILE_NAME && MGQ_MpOverworld.graphic?(folder, name)) }
  end

  # Moves the player's map camera toward the teller's (see apply_map) while the player sees the
  # scene: at once from more than CAMERA_JUMP tiles away, else a CAMERA_EASE-th of the way each
  # frame. Called after the player's update, which moves the camera with the player's character.
  def self.follow_camera
    return unless @camera_target && @camera_target[2] == $game_map.map_id && watching?

    x, y = @camera_target
    dx = x - $game_map.display_x
    dy = y - $game_map.display_y
    return if dx.abs < 1.0 / CAMERA_STEPS && dy.abs < 1.0 / CAMERA_STEPS

    far = dx.abs > CAMERA_JUMP || dy.abs > CAMERA_JUMP
    $game_map.set_display_pos(far ? x : $game_map.display_x + dx / CAMERA_EASE, far ? y : $game_map.display_y + dy / CAMERA_EASE)
  rescue => e
    log_once(:follow_camera, "following the teller's camera failed: #{e.class}: #{e.message}")
  end

  # Reports whether the player's own character walks the teller's character's route, which keeps
  # it from starting the map's events it touches and from meeting enemies, as the story's own
  # route does in the teller's game while the story runs. Asked by the player's update.
  #
  # @return [Boolean] Whether it does.
  def self.walks_player?
    @player_route = false if @player_route && !$game_player.move_route_forcing
    @player_route ? true : false
  end

  # Gives an event the move route the teller's story gave it, without the commands this game
  # cannot run safely (see route_command); the player's own interpreter never waits for it.
  #
  # The route always skips a blocked step, since the viewer's characters stand elsewhere than the
  # teller's and a step that never succeeds would hold the character for good.
  #
  # @param event [Game_Event] The event.
  # @param args [Array] The event's id, whether the route repeats, whether it skips what it cannot
  #   do, and its commands, see route_entry.
  def self.apply_route(event, args)
    built = Array(args[3]).map { |entry| route_command(entry) }
    dropped = built.count(&:nil?)
    commands = built.compact
    commands.push(RPG::MoveCommand.new(0)) unless commands.last && commands.last.code == 0
    route = RPG::MoveRoute.new
    route.repeat = args[1] ? true : false
    route.skippable = true
    route.wait = false
    route.list = commands
    event.force_move_route(route)
    @player_route = true if event.equal?($game_player)
    log("applied the teller's move route of event #{event.id}: #{commands.size} command(s)#{dropped > 0 ? ", #{dropped} left out" : ''}#{route.repeat ? ', repeating' : ''}")
  end

  # Makes a move route command another game sent, if this game can run it: a code up to
  # LAST_ROUTE_CODE with whole numbers, a graphic this game has, a sound file it has.
  #
  # @param entry [Object] The code and arguments, see route_entry.
  # @return [RPG::MoveCommand, nil] The command, nil for one left out.
  def self.route_command(entry)
    return nil unless entry.is_a?(Array) && entry[0].is_a?(Integer) && entry[0] >= 0 && entry[0] <= LAST_ROUTE_CODE

    code = entry[0]
    params = entry[1..-1]
    case code
    when GRAPHIC_CODE
      name = params[0].to_s
      return nil unless name.empty? || (name =~ FILE_NAME && MGQ_MpOverworld.graphic?(:character, name))

      RPG::MoveCommand.new(code, [name, params[1].to_i])
    when SOUND_CODE
      name = params[0].to_s
      return nil unless name =~ FILE_NAME && sound?(name)

      RPG::MoveCommand.new(code, [RPG::SE.new(name, params[1].to_i, params[2].to_i)])
    else
      params.all? { |param| param.is_a?(Integer) } ? RPG::MoveCommand.new(code, params) : nil
    end
  end

  # Reports whether this game has a sound file in Audio/SE.
  #
  # @param name [String] The file without its ending.
  # @return [Boolean] Whether it has.
  def self.sound?(name)
    SOUND_ENDINGS.any? { |ending| File.exist?("Audio/SE/#{name}#{ending}") }
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

  # As teller, tells the viewers the story values of the frame; as viewer, plays the story's sounds
  # held for the map's screen while they see the leader's story scene, and puts the player's screen
  # back once they no longer do. Called after the map's update.
  def self.update
    send_values
    send_camera
    return unless pending?
    return play_held if watching? || just_changed?

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

  # Erases the pictures the leader's story showed, brings the screen back, the map's zoom and the
  # player's own character as they were: the tint and the character's visibility the player's map
  # had, or the story's last on a map the story brought them to.
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
    unless @zoom.nil?
      $game_system.zoom_mode = @zoom
      done << "zoom back to #{@zoom}"
    end
    if @camera_target
      $game_player.center($game_player.x, $game_player.y)
      done << "camera on the player's character again"
    end
    unless @transparent.nil?
      if @transparent_map == $game_map.map_id
        $game_player.transparent = @transparent
        done << "character #{@transparent ? 'hidden' : 'shown'} again"
      else
        done << "kept the story's #{$game_player.transparent ? 'hidden' : 'shown'} character, on map #{$game_map.map_id} instead of #{@transparent_map}"
      end
    end
    unless @scene_switches.empty?
      @scene_switches.each { |id, before| $game_switches[id] = before }
      done << "scene switch(es) #{@scene_switches.keys.sort.join(', ')} back as before"
    end
    if walks_player?
      end_player_route
      done << "ended the teller's route the player's character walked"
    end
    done << "dropped the held #{@held_audio.keys.sort.join(' and ')}" unless @held_audio.empty?
    log("put the screen back, since #{reason}: #{done.join(', ')}")
    forget
  end

  # Reports whether anything of the leader's scene waits to be put back.
  #
  # @return [Boolean] Whether it does.
  def self.pending?
    !(@pictures.empty? && @screen.nil? && @transparent.nil? && @zoom.nil? && @camera_target.nil? && @held_audio.empty? && @scene_switches.empty? && !walks_player?)
  end

  # Ends the teller's route the player's character walks, giving it back its own, as the game
  # does at a forced route's end.
  def self.end_player_route
    MGQ_MpGame.set($game_player, :move_route_forcing, false)
    $game_player.restore_move_route
    @player_route = false
  end

  # Forgets what to put back, as when a save is loaded, which brings its own screen.
  #
  # @param reason [String, nil] Why it is not put back, for the log; nil once it was.
  def self.forget(reason = nil)
    log("forgot the leader's scene without putting it back: #{reason}") if reason && pending?
    @pictures = []
    @values = {}
    @screen = nil
    @transparent = nil
    @transparent_map = nil
    @zoom = nil
    @camera_target = nil
    @camera = nil
    @changed_at = nil
    @held_audio = {}
    @scene_switches = {}
    @player_route = false
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

begin
  # The story's values, its events' move routes, animations, balloons and erasures, for the viewers.
  MGQ_MpHooks.after(Game_Switches, :[]=, "coop_scene") { |id, value| MGQ_MpCoopScene.story_value(0, id, value) }
  MGQ_MpHooks.after(Game_Variables, :[]=, "coop_scene") { |id, value| MGQ_MpCoopScene.story_value(1, id, value) }
  MGQ_MpHooks.after(Game_SelfSwitches, :[]=, "coop_scene") { |key, value| MGQ_MpCoopScene.story_value(2, key, value) }
  MGQ_MpHooks.after(Game_Character, :force_move_route, "coop_scene") { |route| MGQ_MpCoopScene.route(self, route) }
  MGQ_MpHooks.after(Game_CharacterBase, :animation_id=, "coop_scene") { |id| MGQ_MpCoopScene.effect(self, "animation", id) }
  MGQ_MpHooks.after(Game_CharacterBase, :balloon_id=, "coop_scene") { |id| MGQ_MpCoopScene.effect(self, "balloon", id) }
  MGQ_MpHooks.after(Game_Event, :erase, "coop_scene") { MGQ_MpCoopScene.erased(self) }
rescue => e
  MGQ_MpCoopScene.log("event hooks FAILED: #{e.class}: #{e.message}")
end

begin
  # The story's camera for the viewers: the game's map zoom, and after the player's update, which
  # moves the camera with the player's character, the teller's camera's place.
  MGQ_MpHooks.after(Game_Player, :update, "coop_scene") { MGQ_MpCoopScene.follow_camera }
  MGQ_MpHooks.after(Game_Interpreter, :map_zoom, "coop_scene") { |*args| MGQ_MpCoopScene.zoom($game_system.zoom_mode) } if Game_Interpreter.method_defined?(:map_zoom)

  # While a viewer's own character walks the teller's character's route, it starts nothing it
  # steps on or bumps into and meets no enemies, as the story's route in the teller's game.
  MGQ_MpHooks.around(Game_Player, :update_nonmoving, "coop_scene") { |_player, _args, original| original.call unless MGQ_MpCoopScene.walks_player? }
  MGQ_MpHooks.around(Game_Player, :check_event_trigger_touch, "coop_scene") { |_player, _args, original| MGQ_MpCoopScene.walks_player? ? false : original.call }
rescue => e
  MGQ_MpCoopScene.log("camera hooks FAILED: #{e.class}: #{e.message}")
end

begin
  # The story's sounds, whichever way they reach the game's Audio, and the map's look, for the viewers.
  MGQ_MpCoopScene::AUDIO_CALLS.each do |call|
    MGQ_MpHooks.before(Audio.singleton_class, call.to_sym, "coop_scene") { |*args| MGQ_MpCoopScene.audio(call, args) }
  end
  MGQ_MpCoopScene::MAP_LOOKS.each do |look|
    MGQ_MpHooks.before(Game_Map, :"change_#{look}", "coop_scene") { |*args| MGQ_MpCoopScene.map_look(self, look, args) }
  end
rescue => e
  MGQ_MpCoopScene.log("sound and map hooks FAILED: #{e.class}: #{e.message}")
end
