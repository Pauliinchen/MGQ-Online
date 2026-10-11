#----------------------------------------------------------------
#  ui_bug_report.rbx
#
#  Changelog:
#      Paulinchen  2026-10-11: Created
#
#----------------------------------------------------------------

# The in-game bug report: its hotkey (F3 unless the player binds another, see core_hotkeys.rbx) or
# the action wheel's Report a Bug takes a screenshot and opens a form, typed in place, whose title
# and text the DLL sends to the relay with a few public facts, the screenshot and the logs. The
# relay makes a public GitHub issue of the title, the text and the facts; the screenshot, the logs
# and the private details reach the developer only. The world screen's form window draws the form
# (world_screen.rbx), and the notification box tells how the sending went (ui_notices.rbx).
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpBugReport
  # The action wheel's choice, and the form's title.
  WHEEL_TEXT = "Report a Bug"

  # The choice's place on the action wheel's ring, after every other choice.
  WHEEL_ORDER = 60

  # What the first line above the form says.
  HELP = "Title and text go public on GitHub. The screenshot and logs reach the developer only."

  # Longest title and text, within what the relay takes.
  MAX_TITLE_CHARS = 100
  MAX_TEXT_CHARS = 2000

  # Lines the text's box shows.
  TEXT_LINES = 6

  # What the lines above the form say while the cursor is on each field.
  TITLE_HINT = "A short name for the problem. It becomes the title of the issue on GitHub."
  TEXT_HINT = "What you did, what happened and what you expected. Confirm to type, Enter keeps the text."
  SCREENSHOT_HINT = "The screen as it was when you opened the report. Only the developer sees it."
  LOGS_HINT = "The mod's logs of this game session and the list of your mods. Only the developer sees them."
  SEND_HINT = "Sends the report. Title and text become a public issue on GitHub."

  # Why the form is not sent while its title or text is empty.
  TITLE_MISSING = "The report needs a title."
  TEXT_MISSING = "Say what happened."

  # The bits of the DLL's flags: attach the screenshot, attach the logs.
  ATTACH_SCREENSHOT = 1
  ATTACH_LOGS = 2

  # Frames between two looks at how the sending stands, half a second.
  POLL_FRAMES = 30

  # Bytes the DLL may write how the sending stands into at first.
  STATE_SIZE = 1024

  # Limits of a public fact, as the relay takes them: the most facts, a label's and a value's
  # length.
  MAX_FACTS = 12
  MAX_LABEL_CHARS = 32
  MAX_VALUE_CHARS = 120

  # Longest value of a private detail, which only report.txt holds.
  MAX_DETAIL_CHARS = 1000

  # What the notification box keeps the report's messages under, each replacing the one before.
  NOTICE_KEY = :bug_report

  # Frames the sending's messages show, ten seconds, since an upload may take a while.
  NOTICE_FRAMES = 600

  # What the notification box says while the report is sent, once it went, and when it failed.
  SENDING_TEXT = "Sending the bug report . . ."
  SENT_TEXT = "Bug report sent as issue #%s. Thank you!"
  FAILED_TEXT = "The bug report failed: %s"

  # The friendly words for a failure, by the relay's code.
  FRIENDLY_REASONS = {
    "rate" => "you sent several reports in a short time. Try again in an hour.",
    "off" => "the relay takes no bug reports right now.",
  }

  # What the player is told when the report waits: in a battle, and while the map is busy.
  BATTLE_TEXT = "The bug report opens after the battle."
  BUSY_TEXT = "The bug report opens once you are free on the map."

  # Why a report does not open or is not sent.
  SENDING_REFUSAL = "The last bug report is still being sent."
  WAITING_REFUSAL = "A bug report waits to open already."
  NO_NAME_REFUSAL = "Bug reports need your name: pick Multiplayer on the title screen to choose one."
  NO_KEYBOARD_REFUSAL = "The keyboard cannot reach the game, so the report cannot be typed."
  NOT_STARTED_REFUSAL = "The report could not be sent. Multiplayer.log tells why."

  # Scenes a report never opens from, by their class's name: the title and game over screens,
  # which leave the game being played.
  REFUSED_SCENES = /\AScene_(Title|Gameover)\z/

  # Menus a report waits in until the player is back on the map, by their class's name, since they
  # cannot be left for the form and come back.
  WAITING_MENUS = ["Scene_MpStoryChoices"]

  # The offsets from a Bitmap's Ruby object to its pixels, as RGSS3 keeps them: the object's data,
  # then the bitmap's, then its pixels.
  POINTER_STEPS = [16, 8, 16]

  # Bytes per pixel of a bitmap's pixels: blue, green, red, alpha.
  PIXEL_BYTES = 4

  # Largest side of a screenshot the DLL keeps.
  MAX_SIDE = 4096

  # The translation's and the untranslated game's name of the story's progress variable, which tells
  # them apart.
  TRANSLATED_VARIABLE = "Overall Events Progress"

  @pending = nil
  @opening = nil
  @snap_in = nil
  @sending = false
  @poll_frames = 0
  @outcome = nil

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "bug report"

  # Reads the hotkey, takes the screenshot the wheel asked for, forgets a waiting report once the
  # game left for the title screen and a form another scene took the place of, and follows the
  # sending. Called by overworld_sync.rbx every frame in every scene.
  #
  # @param _in_world [Boolean] Whether a world is open.
  def self.tick(_in_world)
    forget_lost_form
    # Asked every frame, so a press in another scene never counts later.
    request(:hotkey) if MGQ_MpHotkeys.pressed?(:bug_report)
    snap_after_wheel
    forget_on_leaving
    poll
    show_outcome
  rescue => e
    log_once(:tick, "tick failed: #{e.class}: #{e.message}")
  end

  # Opens the report that waits, once the player is free on the map and no screen of the mod lies
  # over it. Called by the map every frame.
  def self.on_map
    return unless @pending && @pending[:ready] && map_ready?

    open
  rescue => e
    log("opening the report from the map failed: #{e.class}: #{e.message}")
    forget("it failed")
  end

  # The action wheel's choice, which opens the report once the wheel faded out.
  #
  # @return [MGQ_MpActions::Option] The choice, refused while a report is sent or waits to open,
  #   and without a name.
  def self.wheel_option
    option = MGQ_MpActions::Option
    refusal = @sending ? SENDING_REFUSAL : @pending ? WAITING_REFUSAL : MGQ_Multiplayer::Player.name.nil? ? NO_NAME_REFUSAL : nil
    option.new(WHEEL_TEXT, refusal ? nil : lambda { MGQ_MpBugReport.request(:wheel) }, refusal)
  end

  # Asks for a report: refused where it cannot open; otherwise takes the screenshot, at once or
  # once the wheel faded out, and opens the form at once in a menu, or keeps it waiting until the
  # player is free on the map.
  #
  # @param via [Symbol] :hotkey or :wheel.
  def self.request(via)
    scene = SceneManager.scene
    refusal = refusal_at(scene)
    return refuse(via, refusal) if refusal

    @pending = { :via => via, :facts => facts(scene), :details => details(scene), :snapped => false, :ready => false }
    log("asked for a report by #{via} in #{where_text(scene)}")
    # The wheel played its own sound as the choice was taken.
    return @snap_in = wheel_frames if via == :wheel

    Sound.play_ok
    snap
    if scene.is_a?(Scene_Map)
      tell(BUSY_TEXT, scene) unless map_ready?
    elsif menu?(scene)
      open
    else
      tell(scene.is_a?(Scene_Battle) ? BATTLE_TEXT : BUSY_TEXT, scene)
    end
  rescue => e
    log("asking for a report failed: #{e.class}: #{e.message}")
    forget("it failed")
  end

  # Tells why a report cannot open here, if it cannot.
  #
  # @param scene [Scene_Base, nil] The scene in front.
  # @return [String, Symbol, nil] What the player is told; a Symbol, which the log names, where the
  #   player is told nothing; nil when it can open.
  def self.refusal_at(scene)
    return :no_dll unless MGQ_Multiplayer.available?
    return :typing if $mgq_text_input
    return :open if scene.is_a?(Scene_MpBugReport)
    return :title if scene.nil? || scene.class.name.to_s =~ REFUSED_SCENES
    return SENDING_REFUSAL if @sending
    return WAITING_REFUSAL if @pending || @opening
    return NO_NAME_REFUSAL unless MGQ_Multiplayer::Player.share

    nil
  end

  # Logs why a report does not open, and tells the player when they should know.
  #
  # @param via [Symbol] :hotkey or :wheel.
  # @param refusal [String, Symbol] See refusal_at.
  def self.refuse(via, refusal)
    reasons = { :no_dll => "the DLL is missing", :typing => "the player types", :open => "the form is open already",
                :title => "the game shows the title or game over screen" }
    log("no report by #{via}: #{refusal.is_a?(Symbol) ? reasons[refusal] : refusal}")
    return if refusal.is_a?(Symbol)

    Sound.play_buzzer
    tell(refusal, SceneManager.scene)
  end

  # Frames between the wheel's choice and its screenshot: the wheel's fade out and one more, so
  # the wheel is not in it.
  #
  # @return [Integer] The frames.
  def self.wheel_frames
    MGQ_MpUi::Style::FADE_FRAMES + 1
  end

  # Takes the screenshot the wheel's choice asked for, once the wheel faded out.
  def self.snap_after_wheel
    return unless @snap_in && @pending

    @snap_in -= 1
    return if @snap_in > 0

    @snap_in = nil
    snap
  end

  # Takes the screenshot and hands it to the DLL, which keeps it for the report; the report opens
  # without one when that fails.
  def self.snap
    @pending[:snapped] = Screenshot.take
    @pending[:ready] = true
  end

  # Forgets a waiting report once the game left for the title or game over screen.
  def self.forget_on_leaving
    scene = SceneManager.scene
    forget("the game left for #{scene.class.name}") if @pending && scene && scene.class.name.to_s =~ REFUSED_SCENES
  end

  # Forgets the waiting report and its screenshot.
  #
  # @param reason [String] Why, for the log.
  def self.forget(reason)
    report = @pending
    @pending = nil
    @snap_in = nil
    return unless report

    drop_snap(report)
    log("forgot the waiting report: #{reason}")
  end

  # Opens the form of the waiting report.
  def self.open
    @opening = @pending
    @pending = nil
    log("opening the form#{@opening[:snapped] ? ' with the screenshot' : ' without a screenshot'}")
    SceneManager.call(Scene_MpBugReport)
  end

  # Forgets the report of a form that never opened, since another scene took its place before it
  # started, which would refuse every later report as waiting.
  def self.forget_lost_form
    return unless @opening && !SceneManager.scene.is_a?(Scene_MpBugReport)

    report = @opening
    @opening = nil
    closed(report, "#{SceneManager.scene.class.name} took the place of the form before it opened")
  end

  # The report whose form opens, taken once by the form.
  #
  # @return [Hash, nil] The report: :facts, :details, :snapped; nil when none opens.
  def self.take_opening
    report = @opening
    @opening = nil
    report
  end

  # Tells whether the player is free on the map and no screen of the mod lies over it.
  #
  # @return [Boolean] Whether they are.
  def self.map_ready?
    MGQ_MpOverworldSync.map_free? && !(defined?(MGQ_MpActions) && MGQ_MpActions.covered?)
  end

  # Tells whether a scene is a menu the form opens over at once.
  #
  # @param scene [Scene_Base] The scene.
  # @return [Boolean] Whether it is.
  def self.menu?(scene)
    scene.is_a?(Scene_MenuBase) && !WAITING_MENUS.include?(scene.class.name)
  end

  # Tells the player something: in the battle's chat log in a battle of a world, where the
  # notification box hides, else in the notification box.
  #
  # @param text [String] What to say.
  # @param scene [Scene_Base, nil] The scene in front.
  def self.tell(text, scene)
    if scene.is_a?(Scene_Battle) && defined?(MGQ_MpChat) && MGQ_MpOverworldSync.in_world?
      MGQ_MpChat.system(text)
    elsif defined?(MGQ_MpNotices)
      MGQ_MpNotices.message(NOTICE_KEY, text)
    end
  end

  # Builds the form: the title, the text, whether to attach the screenshot, when there is one, and
  # the logs, and the button that sends it.
  #
  # @param snapped [Boolean] Whether a screenshot was taken.
  # @return [MGQ_MpWorld::Form] The form, both attachments ticked.
  def self.form(snapped)
    field = MGQ_MpWorld::Form::Field
    fields = [
      field.new(:title, :text, "Title", 0, TITLE_HINT, :max_chars => MAX_TITLE_CHARS, :group => "Report", :empty_text => TITLE_MISSING),
      field.new(:text, :area, "What happened", 1, TEXT_HINT, :max_chars => MAX_TEXT_CHARS, :lines => TEXT_LINES, :group => "Report", :empty_text => TEXT_MISSING),
    ]
    fields << field.new(:screenshot, :check, "Attach the screenshot", 2, SCREENSHOT_HINT, :side => :left, :group => "Attach") if snapped
    fields << field.new(:logs, :check, "Attach the logs", 2, LOGS_HINT, :side => snapped ? :right : nil, :group => "Attach")
    fields << field.new(:send, :button, "Send the report", 3, SEND_HINT)
    MGQ_MpWorld::Form.new(WHEEL_TEXT, fields, :title => "", :text => "", :screenshot => snapped, :logs => true)
  end

  # Starts sending a report on the DLL's own thread, and says so in the notification box.
  #
  # @param report [Hash] The report, see take_opening.
  # @param title [String] Its title.
  # @param text [String] What happened.
  # @param screenshot [Boolean] Whether to attach the screenshot.
  # @param logs [Boolean] Whether to attach the logs.
  # @return [String, nil] Why it was not sent, nil once it is being sent.
  def self.send_report(report, title, text, screenshot, logs)
    return SENDING_REFUSAL if @sending
    return NO_NAME_REFUSAL unless MGQ_Multiplayer::Player.share

    flags = (screenshot && report[:snapped] ? ATTACH_SCREENSHOT : 0) | (logs ? ATTACH_LOGS : 0)
    facts = lines(report[:facts].first(MAX_FACTS), MAX_VALUE_CHARS)
    details = lines(report[:details], MAX_DETAIL_CHARS)
    started = MGQ_Multiplayer::Link.function('mp_report_send').call("#{title}\0", "#{text}\0", "#{facts}\0", "#{details}\0", flags) == 1
    attached = "#{flags & ATTACH_SCREENSHOT != 0 ? 'with' : 'without'} the screenshot, #{flags & ATTACH_LOGS != 0 ? 'with' : 'without'} the logs"
    unless started
      log("the DLL did not start sending \"#{MGQ_MpLog.short(title)}\" (#{attached})")
      return NOT_STARTED_REFUSAL
    end

    report[:sent] = true
    @sending = true
    @poll_frames = 0
    @outcome = nil
    log("sending \"#{MGQ_MpLog.short(title)}\" (#{text.length} characters, #{attached}) with #{[report[:facts].size, MAX_FACTS].min} facts")
    MGQ_MpNotices.message(NOTICE_KEY, SENDING_TEXT, NOTICE_FRAMES) if defined?(MGQ_MpNotices)
    nil
  end

  # Forgets the screenshot of a report whose form closed without sending it.
  #
  # @param report [Hash, nil] The report.
  # @param reason [String] Why the form closed, for the log.
  def self.closed(report, reason)
    return unless report && !report[:sent]

    drop_snap(report)
    log("the form closed without sending: #{reason}")
  end

  # Has the DLL forget a report's screenshot, if it took one.
  #
  # @param report [Hash] The report.
  def self.drop_snap(report)
    return unless report[:snapped]

    MGQ_Multiplayer::Link.function('mp_report_drop_snap').call
    report[:snapped] = false
    log("dropped the screenshot")
  rescue => e
    log("dropping the screenshot failed: #{e.class}: #{e.message}")
  end

  # Writes facts or details as the DLL takes them: a line per pair, its label and value split by a
  # tab, each on one line and cut to its length.
  #
  # @param pairs [Array<Array(String, String)>] The labels and their values.
  # @param most [Integer] The most characters of a value.
  # @return [String] The lines.
  def self.lines(pairs, most)
    pairs.map { |label, value| "#{one_line(label, MAX_LABEL_CHARS)}\t#{one_line(value, most)}" }.join("\n")
  end

  # Puts a text on one line without tabs, cut to a length.
  #
  # @param text [Object] The text.
  # @param most [Integer] The most characters kept.
  # @return [String] The text.
  def self.one_line(text, most)
    text.to_s.gsub(/[\x00-\x1f]+/, " ").strip[0, most]
  end

  # Looks at how the sending stands every POLL_FRAMES while a report is being sent, and keeps its
  # outcome for the notification box.
  def self.poll
    return unless @sending

    @poll_frames += 1
    return if @poll_frames < POLL_FRAMES

    @poll_frames = 0
    kind, value, reason = MGQ_Multiplayer::Link.read('mp_report_state', STATE_SIZE).force_encoding("UTF-8").split("\t", 3)
    case kind
    when "sent"
      finish(SENT_TEXT % value, "was sent as issue #{value}: #{reason}")
    when "failed"
      finish(FAILED_TEXT % failure_text(value, reason), "failed (#{value}): #{reason}")
    end
  end

  # Ends the sending and keeps its outcome for the notification box.
  #
  # @param text [String] What the box says.
  # @param logged [String] What the log says.
  def self.finish(text, logged)
    @sending = false
    @outcome = text
    log("the report #{logged}")
  end

  # Tells why a report failed, in friendly words for the relay's rate limit and for a relay that
  # takes no reports.
  #
  # @param code [String, nil] The relay's code, or "http<status>" or "unreachable".
  # @param reason [String, nil] The DLL's reason.
  # @return [String] The reason.
  def self.failure_text(code, reason)
    friendly = FRIENDLY_REASONS[code.to_s]
    return friendly if friendly

    text = reason.to_s.strip
    text.empty? ? code.to_s : text
  end

  # Shows the sending's outcome in the notification box once it shows, so a report that ends in a
  # battle is told after it.
  def self.show_outcome
    return unless @outcome && defined?(MGQ_MpNotices) && MGQ_MpNotices.shown?

    MGQ_MpNotices.message(NOTICE_KEY, @outcome, NOTICE_FRAMES)
    @outcome = nil
  end

  # Tells whether a report is being sent.
  #
  # @return [Boolean] Whether one is.
  def self.sending?
    @sending
  end

  # Lists the public facts of a report, as the report is asked for.
  #
  # @param scene [Scene_Base] The scene in front.
  # @return [Array<Array(String, String)>] The game's version, the world's type, where the player is,
  #   and whether the DLL is a development build when it is one; the DLL puts the mod's version first.
  def self.facts(scene)
    facts = [["Game", safely { game_text }], ["World", safely { world_type }], ["Where", safely { where_text(scene) }]]
    facts << ["Development build", "yes"] if safely { MGQ_MpWorld.dev_build? } == true
    facts
  end

  # Lists the private details of a report, as the report is asked for, which only report.txt holds.
  #
  # @param _scene [Scene_Base] The scene in front.
  # @return [Array<Array(String, String)>] The player, the world, the map, the position, the party
  #   and the time played.
  def self.details(_scene)
    [["Player", safely { player_text }], ["World", safely { world_text }], ["Map", safely { map_text }],
     ["Position", safely { "#{$game_player.x}, #{$game_player.y}" }], ["Party", safely { party_text }],
     ["Time played", safely { $game_system.playtime_s }]]
  end

  # Runs a block that reads a fact, so one that cannot be read never loses the report.
  #
  # @yieldreturn [Object] The fact.
  # @return [Object] What the block returned, "unknown" when it failed.
  def self.safely
    yield
  rescue => e
    log("a fact could not be read: #{e.class}: #{e.message}")
    "unknown"
  end

  # Names the game's version and whether it is translated.
  #
  # @return [String] Such as "3.06, translated".
  def self.game_text
    version = $patch_ver.to_s[/\d+\.\d+/]
    "#{version || 'unknown version'}, #{translation}"
  end

  # Tells whether the game is translated, by the name of the story's progress variable.
  #
  # @return [String] "translated", "untranslated" or "translation unknown".
  def self.translation
    names = $data_system.variables
    return "translated" if names.include?(TRANSLATED_VARIABLE)

    untranslated = defined?(MGQ_MpWorldOverview::PROGRESS) ? MGQ_MpWorldOverview::PROGRESS - [TRANSLATED_VARIABLE] : []
    untranslated.any? { |name| names.include?(name) } ? "untranslated" : "translation unknown"
  end

  # Names the open world's type, and its name when the world is public.
  #
  # @return [String] Such as "Raid, Public Raid", "Classic, a hidden world" or "none".
  def self.world_type
    return "none" unless MGQ_MpWorld.open?

    type = MGQ_MpWorld.raid? ? "Raid" : "Classic"
    name = public_world_name
    name ? "#{type}, #{name}" : "#{type}, a hidden world"
  end

  # Names the open world when everyone may see it in the world list.
  #
  # A hidden world's name stays in the private details, since the issue is public.
  #
  # @return [String, nil] The name, nil for a hidden world or while the list is not there.
  def self.public_world_name
    world = MGQ_MpWorld.world
    return nil unless world

    state, _error, worlds = MGQ_MpWorld::Directory.list
    return nil unless state == "ready"

    id = world.directory_id || world.id
    listed = Array(worlds).find { |entry| entry.id == id }
    listed && !listed.hidden ? listed.name.to_s : nil
  end

  # Names where the player is: the scene and the map.
  #
  # @param scene [Scene_Base, nil] The scene in front.
  # @return [String] Such as "Scene_Map, map 154".
  def self.where_text(scene)
    map = $game_map ? $game_map.map_id.to_i : 0
    "#{scene.class.name}#{map > 0 ? ", map #{map}" : ''}"
  end

  # Names the player with the id everyone sees, never their key.
  #
  # @return [String] Such as "<Player> (0123abcd...)".
  def self.player_text
    "#{MGQ_Multiplayer::Player.name || 'no name'} (#{MGQ_Multiplayer::Link.player_id})"
  end

  # Names the open world with its id in the directory.
  #
  # @return [String] Such as "<World> (0123abcd...)", "none" outside a world.
  def self.world_text
    world = MGQ_MpWorld.world
    world ? "#{world.name} (#{world.directory_id || world.id})" : "none"
  end

  # Names the map with its id.
  #
  # @return [String] Such as "Ilias Village (154)".
  def self.map_text
    name = $game_map.display_name.to_s
    name.empty? ? $game_map.map_id.to_s : "#{name} (#{$game_map.map_id})"
  end

  # Lists the party's members with their levels.
  #
  # @return [String] Such as "Luka Lv 12, Alice Lv 99".
  def self.party_text
    $game_party.members.map { |actor| "#{actor.name} Lv #{actor.level}" }.join(", ")
  end

  # The screenshot: the screen's pixels as RGSS3 keeps a Bitmap, handed to the DLL, which encodes
  # them later, off the game's thread.
  module Screenshot
    # Takes the screenshot and hands it to the DLL.
    #
    # @return [Boolean] Whether the DLL kept it.
    def self.take
      bitmap = Graphics.snap_to_bitmap
      width = bitmap.width
      height = bitmap.height
      unless width.between?(1, MAX_SIDE) && height.between?(1, MAX_SIDE)
        MGQ_MpBugReport.log("no screenshot: the screen is #{width} by #{height}")
        return false
      end

      kept = MGQ_Multiplayer::Link.function('mp_report_snap').call(pixels_of(bitmap), width, height) == 1
      MGQ_MpBugReport.log(kept ? "took the screenshot, #{width} by #{height}" : "the DLL did not keep the screenshot")
      kept
    rescue => e
      MGQ_MpBugReport.log("the screenshot failed: #{e.class}: #{e.message}")
      false
    ensure
      bitmap.dispose if bitmap && !bitmap.disposed?
    end

    # Copies a bitmap's pixels.
    #
    # @param bitmap [Bitmap] The bitmap.
    # @return [String] Its width * height * PIXEL_BYTES bytes, rows bottom-up.
    def self.pixels_of(bitmap)
      address = POINTER_STEPS.inject(bitmap.object_id * 2) { |at, step| pointer_at(at + step) }
      raise "the bitmap's pixels were not found" if address == 0

      copy(address, bitmap.width * bitmap.height * PIXEL_BYTES)
    end

    # Reads a pointer.
    #
    # @param address [Integer] Where it lies.
    # @return [Integer] Where it points.
    def self.pointer_at(address)
      raise "a pointer on the way to the bitmap's pixels is empty" if address < POINTER_STEPS.max

      copy(address, 4).unpack('L')[0]
    end

    # Copies memory of the game's process into a string.
    #
    # @param address [Integer] Where it starts.
    # @param length [Integer] How many bytes.
    # @return [String] The bytes.
    def self.copy(address, length)
      buffer = "\0" * length
      MGQ_Multiplayer::Windows.api('kernel32', 'RtlMoveMemory', 'pll', 'l').call(buffer, signed(address), length)
      buffer
    end

    # Writes an address as the signed long Win32API passes.
    #
    # @param address [Integer] The address, 0 to 2**32 - 1.
    # @return [Integer] The same 32 bits as a signed number.
    def self.signed(address)
      address >= 2**31 ? address - 2**32 : address
    end
  end
end

# The bug report's form, over the map or the menu it was opened from: the lines that say who sees
# what, and the world screen's form window with the title, the text, the attachments and the button
# that sends it. Text is typed in place on the keyboard.
class Scene_MpBugReport < Scene_MenuBase
  # Lines above the form.
  INFO_LINES = 4

  # Widest the form gets, and its room to the screen's edges.
  FORM_WIDTH = 520
  MARGIN = 8

  # Builds the windows for the report the hotkey or the wheel asked for.
  def start
    super
    @report = MGQ_MpBugReport.take_opening
    return return_scene unless @report

    @form = MGQ_MpBugReport.form(@report[:snapped])
    @info_window = Window_MpInfo.new(INFO_LINES)
    width = [Graphics.width - 2 * MARGIN, FORM_WIDTH].min
    @form_window = Window_MpWorldForm.new((Graphics.width - width) / 2, @info_window.height + MARGIN, width,
                                          Graphics.height - @info_window.height - 2 * MARGIN)
    @form_window.form = @form
    @form_window.set_handler(:ok, method(:on_field))
    @form_window.visible = true
    @form_window.activate
    @form_window.select(0)
    @message = nil
    @hinted = nil
    show_info
    MGQ_MpBugReport.log("the form opened")
  rescue => e
    MGQ_MpBugReport.log("the form could not open: #{MGQ_MpLog.failure(e)} at #{Array(e.backtrace).first}")
    return_scene
  end

  # Types into the box being typed into, hands the cursor back to the form once the press that ended
  # the typing is let go, and leaves the form on cancel.
  def update
    super
    return unless @form

    if @form.editing
      update_typing
    elsif @resume
      resume
    elsif @form_window.active && MGQ_MpUi.cancel?
      on_cancel
    end
    show_info
  rescue => e
    MGQ_MpBugReport.log("the form failed: #{MGQ_MpLog.failure(e)} at #{Array(e.backtrace).first}")
    return_scene
  end

  # Stops taking what is typed, and forgets the screenshot unless the report went.
  def terminate
    MGQ_Multiplayer::Link.typing(false) if @form && @form.editing
    MGQ_MpBugReport.closed(@report, @left || "the screen closed")
    super
  end

  # Hands the cursor back to the form once confirm and cancel are let go, so the press that ended
  # the typing never reaches it.
  def resume
    return if Input.press?(:C) || Input.press?(:B)

    @resume = false
    @form_window.activate
  end

  # Acts on the chosen field: ticks a checkbox, sends the report, or starts typing into a box.
  def on_field
    field = @form_window.field
    case field.kind
    when :check
      @form.tick(field.key)
      MGQ_MpBugReport.log("#{@form[field.key] ? 'ticked' : 'unticked'} #{field.label}")
      @form_window.refresh
      @form_window.activate
    when :button
      send_report
    else
      start_typing(field)
    end
  end

  # Leaves the form without sending the report.
  def on_cancel
    Sound.play_cancel
    @left = "the player left it"
    return_scene
  end

  # Starts typing into a box in place.
  #
  # @param field [MGQ_MpWorld::Form::Field] The box.
  def start_typing(field)
    return refuse(MGQ_MpBugReport::NO_KEYBOARD_REFUSAL) unless MGQ_Multiplayer::Background.running?

    @form.editing = field.key
    @form.edit = MGQ_MpUi::TextEdit.new(@form[field.key], :max_chars => field.max_chars, :allowed => field.allowed)
    @typed_before = @form[field.key]
    @cursor_shown = true
    MGQ_Multiplayer::Link.typing(true)
    @form_window.refresh
    say(Scene_MpWorlds::TYPING_HINT)
    MGQ_MpBugReport.log("typing into #{field.label}")
  end

  # Takes what was typed and lets the editor follow the keys that move the cursor. The numpad's 0
  # leaves the box, as Escape does.
  def update_typing
    field = @form_window.field
    text, _keys = MGQ_Multiplayer::Link.take_typed
    return type(field, "\e") if MGQ_MpUi.numpad_cancel?

    text.each_char do |char|
      type(field, char)
      # Enter or Escape may have ended the typing.
      return unless @form.editing
    end

    editor = @form.edit
    moved = editor.update_keys(field.kind == :area ? @form_window.current_area_spans(editor.text) : nil)
    @form[field.key] = editor.text
    return unless moved || editor.cursor_shown? != @cursor_shown

    @cursor_shown = editor.cursor_shown?
    @form_window.redraw_current_item
  end

  # Types one character at the cursor: Enter keeps the text if it is accepted, Escape puts the text
  # back as it was.
  #
  # @param field [MGQ_MpWorld::Form::Field] The box.
  # @param char [String] The character.
  def type(field, char)
    case @form.edit.type(char)
    when :enter
      text, error = @form.check(field, @form.edit.text)
      if error
        MGQ_MpBugReport.log("#{field.label} refused: #{error}")
        return refuse(error)
      end

      @form[field.key] = text
      Sound.play_ok
      MGQ_MpBugReport.log("kept #{field.label}, #{text.length} characters")
      return stop_typing
    when :escape
      @form[field.key] = @typed_before
      Sound.play_cancel
      MGQ_MpBugReport.log("put #{field.label} back as it was")
      return stop_typing
    when :refused
      Sound.play_buzzer
    when :edited
      Sound.play_cursor
    end
    @form[field.key] = @form.edit.text
    @form_window.redraw_current_item
  end

  # Stops typing and hands the cursor back to the form.
  def stop_typing
    MGQ_Multiplayer::Link.typing(false)
    @form.editing = nil
    @form.edit = nil
    @form_window.refresh
    @message = nil
    @resume = true
  end

  # Sends the report and closes the form, or points at the field that keeps it from being sent, or
  # says why the DLL did not take it.
  def send_report
    index, error = @form.problem
    if error
      MGQ_MpBugReport.log("not sent: #{error}")
      @form_window.select(index)
      @hinted = index
      return refuse(error)
    end

    @form.fields.each { |field| @form[field.key] = @form.check(field, @form[field.key].to_s)[0] if field.typed? }
    refusal = MGQ_MpBugReport.send_report(@report, @form[:title], @form[:text], @form[:screenshot] == true, @form[:logs] == true)
    return refuse(refusal) if refusal

    @left = "the report went"
    return_scene
  end

  # Says why something is not accepted, and hands the cursor back to the form unless the player
  # types.
  #
  # @param error [String] Why.
  def refuse(error)
    Sound.play_buzzer
    say(error)
    @resume = true unless @form.editing
  end

  # Says something in the second line above the form, until the cursor moves.
  #
  # @param message [String] What to say.
  def say(message)
    @message = message
    @hinted = @form_window.index
    show_info
  end

  # Shows the lines above the form: who sees what, then what was said last or the hint of the field
  # the cursor is on.
  def show_info
    index = @form_window.index
    if index != @hinted && !@form.editing
      @hinted = index
      @message = nil
    end
    field = @form_window.field
    @info_window.show([MGQ_MpBugReport::HELP, @message || (field ? field.hint : nil)])
  end
end

# What this script takes part in of the world and the action wheel, through overworld_sync.rbx and
# ui_actions.rbx.

begin
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpBugReport.tick(in_world) }
  MGQ_MpActions.wheel_choice(MGQ_MpBugReport::WHEEL_ORDER) { MGQ_MpBugReport.wheel_option }
rescue => e
  MGQ_MpBugReport.log("registering FAILED: #{e.class}: #{e.message}")
end

# Game hooks, through core_hooks.rbx.

begin
  # After the map's update, the report that waits for the player to be free on the map. The game
  # changes scenes there too, only while no scene change is in the way.
  MGQ_MpHooks.after(Scene_Map, :update_scene, "ui_bug_report") { MGQ_MpBugReport.on_map unless scene_changing? }
rescue => e
  MGQ_MpBugReport.log("hooks FAILED: #{e.class}: #{e.message}")
end
