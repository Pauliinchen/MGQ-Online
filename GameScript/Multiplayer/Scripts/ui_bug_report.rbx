#----------------------------------------------------------------
#  ui_bug_report.rbx
#
#  Changelog:
#      Paulinchen  2026-11-06: Named each member's base level, as the game keeps every kind of level in one Hash
#      Paulinchen  2026-11-05: Read the player's id through a topic
#                            - Told an untranslated game in the report by its own name of the story's progress variable
#      Paulinchen  2026-11-01: Built the form on the Mod Framework's components
#                            - Left when the report opens, its refusals, sending and the outcome to the DLL
#                            - Took the wheel's screenshot once the action wheel is gone and waited while any mod's screen holds the game
#                            - Waited in the Mod Framework's menu scene of a mod's screen, where the story's choices now show
#                            - Showed the lines across the top in the info strip of the Mod Framework's components
#      Paulinchen  2026-10-31: Typed and cancelled through the Mod Framework
#                            - Worded what the player reads plainly, leaving causes and internals to the log
#      Paulinchen  2026-10-30: Named the game version as the mod loader names it, a translation's own loader included
#      Paulinchen  2026-10-23: Walked to the screenshot's pixels in C#, handing it the Bitmap's address
#                            - Typed into the form through the text box in C#
#                            - Handed the log's lines to the DLL before a report reads its log
#                            - Removed sending?, which only the tests read
#      Paulinchen  2026-10-12: Kept the report's messages until the notification box shows
#                            - Scrolled the description being typed with the mouse wheel
#                            - Logged a refused hotkey through MGQ_MpHotkeys.log_refusal
#                            - Told the player in friendly words when the relay is busy
#      Paulinchen  2026-10-11: Created
#
#----------------------------------------------------------------

# The in-game bug report: its hotkey (F3 unless the player binds another, see core_hotkeys.rbx) or
# the action wheel's Report a Bug takes a screenshot and opens a form, a Mod Framework window, whose
# title and text the DLL sends to the relay with a few public facts, the screenshot and the logs.
# The relay makes a public GitHub issue of the title, the text and the facts; the screenshot, the
# logs and the private details reach the developer only.
#
# The DLL keeps the request (Reports/BugReportRequest): where a report is refused, when the
# screenshot is taken and the form opens, what waits for the notification box, sending and its
# outcome. This script hands it the scene and the facts, takes the screenshot, draws the form and
# plays, says and logs what the DLL tells. It must never interrupt the game, so its per-frame work
# rescues.
module MGQ_MpBugReport
  # The framework's components and everything that draws.
  UI = Mod_Framework::UI

  # The action wheel's choice, and the form's title.
  WHEEL_TEXT = "Report a Bug"

  # The choice's place on the action wheel's ring, after every other choice.
  WHEEL_ORDER = 60

  # What the line at the top of the form says.
  HELP = "Title and text go public on GitHub. The screenshot and logs reach the developer only."

  # Longest title, within what the relay takes.
  MAX_TITLE_CHARS = 100

  # Longest text, within what the relay takes.
  MAX_TEXT_CHARS = 2000

  # Lines the text's box shows.
  TEXT_LINES = 6

  # What the help line says while the focus is on the title.
  TITLE_HINT = "A short name for the problem. It becomes the title of the issue on GitHub."

  # What the help line says while the focus is on the text.
  TEXT_HINT = "What you did, what happened and what you expected."

  # What the help line says while the focus is on the screenshot's checkbox.
  SCREENSHOT_HINT = "The screen as it was when you opened the report. Only the developer sees it."

  # What the help line says while the focus is on the logs' checkbox.
  LOGS_HINT = "The mod's logs of this game session and the list of your mods. Only the developer sees them."

  # What the help line says while the focus is on the send button.
  SEND_HINT = "Sends the report. Title and text become a public issue on GitHub."

  # Why the form is not sent while its title is empty.
  TITLE_MISSING = "The report needs a title."

  # Why the form is not sent while its text is empty.
  TEXT_MISSING = "Say what happened."

  # Why a box cannot be typed into while another mod types.
  NO_KEYBOARD_REFUSAL = "Another window is using the keyboard. Close it, then try again."

  # Widest the form gets.
  FORM_WIDTH = 520

  # The captions of the form's boxes, which line up.
  CAPTIONS = ["Title", "What happened"]

  # What the notification box keeps the report's messages under, each replacing the one before.
  NOTICE_KEY = :bug_report

  # Why the form closed without sending, for the log, by why the window closed.
  CLOSED_REASONS = { :cancel => "the player left it", :outside => "the player left it", :scene => "another scene took its place",
                     :script => "the script closed it", :reset => "F12 started the game again" }

  # Scenes a report never opens from, by their class's name: the title and game over screens,
  # which leave the game being played.
  REFUSED_SCENES = /\AScene_(Title|Gameover)\z/

  # Largest side of a screenshot the DLL keeps.
  MAX_SIDE = 4096

  # The translation's and the untranslated game's name of the story's progress variable, which tells
  # them apart.
  TRANSLATED_VARIABLE = "Overall Events Progress"
  UNTRANSLATED_VARIABLE = "総合イベント進行度"

  # The DLL's topic of a frame, see ReportTopics.TickTopic: whether to take the screenshot now.
  TICK_TOPIC = "report.tick"

  # The DLL's topic of the screenshot taken: whether the form opens now.
  SNAPPED_TOPIC = "report.snapped"

  # The DLL's topic of the map's update: whether the form opens now.
  MAP_TOPIC = "report.on_map"

  # The DLL's topic that tells why the wheel's choice is refused, nil while it may be taken.
  WHEEL_REFUSAL_TOPIC = "report.wheel_refusal"

  # The DLL's topic of the wheel's choice taken.
  WHEEL_TOPIC = "report.wheel"

  # The DLL's topic of the action wheel gone: whether to take the screenshot the wheel asked for now.
  WHEEL_GONE_TOPIC = "report.wheel_gone"

  # The DLL's topic the form takes its report by: whether a screenshot was kept, nil for none.
  OPENING_TOPIC = "report.take_opening"

  # The DLL's topic that sends the form's report: why it was not sent, nil once it is being sent.
  SEND_TOPIC = "report.send"

  # The DLL's topic of the form closing, with why.
  CLOSED_TOPIC = "report.closed"

  # The DLL's event of a sound to play, by its name after Sound.play_.
  SOUND_EVENT = "report.sound"

  # The DLL's event of a line for the battle's chat log.
  CHAT_LINE_EVENT = "report.chat_line"

  # The DLL's event of a message for the notification box: "text" and "frames", nil for the box's own.
  NOTICE_EVENT = "report.notice"

  # The DLL's event of the hotkey refused, which the hotkeys log.
  HOTKEY_REFUSED_EVENT = "report.hotkey_refused"

  # The game's sounds the DLL plays by name.
  SOUNDS = ["ok", "buzzer"]

  # The form, from its opening to its closing, nil while none is open.
  @form = nil

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "bug report"

  class << self
    # @return [Form, nil] The form, from its opening to its closing.
    attr_reader :form
  end

  # Hands the DLL the frame with the hotkey, and takes the screenshot when the DLL says so. Called
  # by overworld_sync.rbx every frame in every scene.
  #
  # @param _in_world [Boolean] Whether a world is open.
  def self.tick(_in_world)
    # Asked every frame, so a press in another scene never counts later.
    hotkey = MGQ_MpHotkeys.pressed?(:bug_report)
    return unless MGQ_Multiplayer::Bridge.open?

    scene = SceneManager.scene
    frame = { "scene" => scene_of(scene), "hotkey" => hotkey }
    frame.update(asked_in(scene)) if hotkey
    snap if MGQ_Multiplayer::Bridge.call(TICK_TOPIC, frame) == true
  rescue => e
    log_once(:tick, "tick failed: #{e.class}: #{e.message}")
  end

  # Opens the form of the report that waits, once the DLL finds the player free on the map. Called
  # by the map every frame.
  def self.on_map
    return unless MGQ_Multiplayer::Bridge.open?

    open_form if MGQ_Multiplayer::Bridge.call(MAP_TOPIC, scene_of(SceneManager.scene)) == true
  rescue => e
    log("opening the report from the map failed: #{e.class}: #{e.message}")
  end

  # The action wheel's choice, which asks for a report.
  #
  # @return [MGQ_MpActions::Option] The choice, refused as the DLL says.
  def self.wheel_option
    refusal = MGQ_Multiplayer::Bridge.call(WHEEL_REFUSAL_TOPIC)
    MGQ_MpActions::Option.new(WHEEL_TEXT, refusal ? nil : lambda { MGQ_MpBugReport.request_by_wheel }, refusal)
  end

  # Asks the DLL for a report by the wheel's choice, whose screenshot waits until nothing of the
  # wheel shows.
  def self.request_by_wheel
    scene = SceneManager.scene
    MGQ_Multiplayer::Bridge.call(WHEEL_TOPIC, asked_in(scene).merge("scene" => scene_of(scene)))
  rescue => e
    log("asking for a report by the wheel failed: #{e.class}: #{e.message}")
  end

  # Takes the screenshot the wheel's choice asked for when the DLL says so. Called as the action
  # wheel is gone.
  def self.wheel_gone
    return unless MGQ_Multiplayer::Bridge.open?

    snap if MGQ_Multiplayer::Bridge.call(WHEEL_GONE_TOPIC) == true
  rescue => e
    log("taking the wheel's screenshot failed: #{e.class}: #{e.message}")
  end

  # Tells where a report is asked for and what it reports, as the DLL takes them.
  #
  # @param scene [Scene_Base, nil] The scene in front.
  # @return [Hash] "where", "facts" and "details".
  def self.asked_in(scene)
    { "where" => where_text(scene), "facts" => text_pairs(facts(scene)), "details" => text_pairs(details(scene)) }
  end

  # Puts labels and values as Strings, which cross the bridge.
  #
  # @param pairs [Array<Array(Object, Object)>] The labels and their values.
  # @return [Array<Array(String, String)>] The pairs.
  def self.text_pairs(pairs)
    pairs.map { |label, value| [label.to_s, value.to_s] }
  end

  # Tells the DLL what the scene in front is, see ReportTopics.
  #
  # @param scene [Scene_Base, nil] The scene in front.
  # @return [Hash] The scene.
  def self.scene_of(scene)
    { "name" => scene.class.name.to_s, "place" => place_of(scene), "in_world" => MGQ_MpOverworldSync.in_world? ? true : false,
      "map_ready" => map_ready?, "shown" => MGQ_MpNotices.shown? ? true : false, "typing" => $mgq_text_input ? true : false }
  end

  # Tells what kind of scene the report is asked for or waits in.
  #
  # @param scene [Scene_Base, nil] The scene in front.
  # @return [String] "form" while the form opens or is open, else "title", "map", "battle",
  #   "waiting_menu", "menu" or "other".
  def self.place_of(scene)
    return "form" if @form
    return "title" if scene.nil? || scene.class.name.to_s =~ REFUSED_SCENES
    return "map" if scene.is_a?(Scene_Map)
    return "battle" if scene.is_a?(Scene_Battle)
    return "waiting_menu" if menu_screen?(scene)

    scene.is_a?(Scene_MenuBase) ? "menu" : "other"
  end

  # Tells whether a scene is the Mod Framework's menu scene of a mod's screen, such as the story's
  # choices, which cannot be left for the form and come back, so a report waits there until the
  # player is back on the map.
  #
  # An older framework without UI.menu_screen? still marks that scene by its menu root.
  #
  # @param scene [Scene_Base] The scene.
  # @return [Boolean] Whether it is.
  def self.menu_screen?(scene)
    UI.respond_to?(:menu_screen?) ? UI.menu_screen?(scene) : scene.respond_to?(:menu_root)
  end

  # Tells whether the player is free on the map and no screen of any mod holds the game.
  #
  # @return [Boolean] Whether they are.
  def self.map_ready?
    MGQ_MpOverworldSync.map_free? && !UI.busy? ? true : false
  end

  # Takes the screenshot, hands it to the DLL and opens the form when the DLL says so.
  def self.snap
    kept = Screenshot.take
    open_form if MGQ_Multiplayer::Bridge.call(SNAPPED_TOPIC, "kept" => kept, "scene" => scene_of(SceneManager.scene)) == true
  end

  # Opens the form of the report the DLL hands over: in place in a menu, else in a menu scene of
  # its own.
  def self.open_form
    snapped = MGQ_Multiplayer::Bridge.call(OPENING_TOPIC)
    return log("no report waits for a form") if snapped.nil?

    @form = Form.new(snapped == true)
    log("opening the form#{snapped == true ? ' with the screenshot' : ' without a screenshot'}")
    @form.open
  rescue => e
    log("the form could not open: #{MGQ_MpLog.failure(e)} at #{Array(e.backtrace).first}")
    @form = nil
    MGQ_Multiplayer::Bridge.call(CLOSED_TOPIC, "it could not open")
  end

  # Tells the DLL that the form closed, which forgets the screenshot unless the report went.
  #
  # @param form [Form] The form.
  # @param reason [String] Why, for the log.
  def self.closed(form, reason)
    return unless form.equal?(@form)

    @form = nil
    MGQ_Multiplayer::Bridge.call(CLOSED_TOPIC, reason)
  end

  # Plays a sound the DLL tells.
  #
  # @param name [String] Its name after Sound.play_.
  def self.play(name)
    Sound.send("play_#{name}") if SOUNDS.include?(name.to_s)
  end

  # Shows a message the DLL tells in the notification box.
  #
  # @param notice [Hash] "text", and "frames" or nil for the box's own time.
  def self.notice(notice)
    frames = notice["frames"]
    frames ? MGQ_MpNotices.message(NOTICE_KEY, notice["text"].to_s, frames) : MGQ_MpNotices.message(NOTICE_KEY, notice["text"].to_s)
  end

  # Adds a line the DLL tells to the battle's chat log.
  #
  # @param text [String] The line.
  def self.chat_line(text)
    MGQ_MpChat.system(text.to_s) if defined?(MGQ_MpChat)
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

  # Names the game's version as the mod loader names it, and whether it is translated.
  #
  # The Russian translation's own loader adds its version to the game's.
  #
  # @return [String] Such as "v3.06.00, translated".
  def self.game_text
    version = $patch_ver.to_s.strip
    "#{version.empty? ? 'unknown version' : version}, #{translation}"
  end

  # Tells whether the game is translated, by the name of the story's progress variable.
  #
  # @return [String] "translated", "untranslated" or "translation unknown".
  def self.translation
    names = $data_system.variables
    return "translated" if names.include?(TRANSLATED_VARIABLE)

    names.include?(UNTRANSLATED_VARIABLE) ? "untranslated" : "translation unknown"
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
    "#{MGQ_Multiplayer::Player.name || 'no name'} (#{MGQ_Multiplayer::Player.id})"
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
    $game_party.members.map { |actor| "#{actor.name} Lv #{actor.base_level}" }.join(", ")
  end

  # The screenshot: the screen as RGSS3 keeps a Bitmap, whose pixels the DLL walks to in the game's
  # process and keeps for the report, encoding them later, off the game's thread.
  module Screenshot
    # Keeps a snapped Bitmap's pixels in the DLL, GameBridge.SnapTopic.
    TOPIC = "ui.report.snap"

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

      # A Ruby 1.9 object's id is its address halved.
      kept = MGQ_Multiplayer::Bridge.call(TOPIC, [bitmap.object_id * 2, width, height]) == true
      MGQ_MpBugReport.log(kept ? "took the screenshot, #{width} by #{height}" : "the DLL did not keep the screenshot")
      kept
    rescue => e
      MGQ_MpBugReport.log("the screenshot failed: #{e.class}: #{e.message}")
      false
    ensure
      bitmap.dispose if bitmap && !bitmap.disposed?
    end
  end

  # The report's form, a framework window over the menu it was asked for in, or in a menu scene of
  # its own: who sees what, the help line, the title and the text typed in place once confirmed,
  # whether to attach the screenshot, when there is one, and the logs, and the button that sends it.
  class Form
    # @return [UI::Window] The window.
    attr_reader :window

    # @return [UI::TextField] The title's box.
    attr_reader :title

    # @return [UI::TextField] The text's box.
    attr_reader :text

    # @return [UI::Checkbox, nil] Whether to attach the screenshot, nil without one.
    attr_reader :screenshot

    # @return [UI::Checkbox] Whether to attach the logs.
    attr_reader :logs

    # @return [UI::HelpLine] The line that tells what the focused part does, or why something is refused.
    attr_reader :help

    # Builds the form, both attachments ticked.
    #
    # @param snapped [Boolean] Whether a screenshot was taken.
    def initialize(snapped)
      @sent = false
      @window = UI::Window.new(:title => WHEEL_TEXT, :menu => true, :center => true, :width => FORM_WIDTH, :log => MGQ_MpBugReport)
      @window.add_label(HELP, :wrap => true, :font_size => :small)
      @help = @window.add_help(:lines => 2)
      report = @window.add_group("Report")
      @title = add_box(report, "Title", :max_length => MAX_TITLE_CHARS, :help => TITLE_HINT)
      @text = add_box(report, "What happened", :max_length => MAX_TEXT_CHARS, :lines => TEXT_LINES, :help => TEXT_HINT)
      attach = @window.add_group("Attach").add_row(:gap => 16)
      @screenshot = add_check(attach, "Attach the screenshot", SCREENSHOT_HINT) if snapped
      @logs = add_check(attach, "Attach the logs", LOGS_HINT)
      @window.add_button("Send the report", :quiet => true, :align => :center, :help => SEND_HINT).on(:click) { send_report }
      @window.add_key_help([{ :button => :B, :text => "close" }])
      @window.on(:close) { |why| closed(why) }
    end

    # Opens the window; a refused open tells close like any other end.
    def open
      @window.open
    end

    # Sends the report and closes the form, or puts the focus on the box that keeps it from being
    # sent, or says why the DLL did not take it.
    def send_report
      title = @title.text.to_s.strip
      text = @text.text.to_s.strip
      return refuse(TITLE_MISSING, @title) if title.empty?
      return refuse(TEXT_MISSING, @text) if text.empty?

      request = { "title" => title, "text" => text, "screenshot" => @screenshot ? @screenshot.checked? : false, "logs" => @logs.checked? }
      refusal = MGQ_Multiplayer::Bridge.call(SEND_TOPIC, request)
      return refuse(refusal) if refusal

      Sound.play_ok
      @sent = true
      @window.close(:button)
    end

    private

    # Adds a box typed into once confirmed, under its caption.
    #
    # @param group [UI::Group] Where it goes.
    # @param caption [String] Its caption.
    # @param options [Hash] Its options.
    # @return [UI::TextField] The box.
    def add_box(group, caption, options)
      box = group.add_field(caption, :caption_width => CAPTIONS).add_text_field(options.merge(:confirm_to_type => true))
      box.on(:type) { MGQ_MpBugReport.log("typing into #{caption}") }
      box.on(:submit) { |typed| MGQ_MpBugReport.log("kept #{caption}, #{typed.to_s.length} characters") }
      box.on(:revert) { MGQ_MpBugReport.log("put #{caption} back as it was") }
      box.on(:refuse) { refuse(NO_KEYBOARD_REFUSAL) }
      box
    end

    # Adds a checkbox, ticked.
    #
    # @param row [UI::Component] Where it goes.
    # @param text [String] Its text.
    # @param hint [String] What the help line says on it.
    # @return [UI::Checkbox] The checkbox.
    def add_check(row, text, hint)
      check = row.add_checkbox(text, :checked => true, :help => hint)
      check.on(:change) { |checked| MGQ_MpBugReport.log("#{checked ? 'ticked' : 'unticked'} #{text}") }
      check
    end

    # Says why something is not accepted, with the focus on the box it names.
    #
    # @param why [String] Why.
    # @param box [UI::TextField, nil] The box that keeps the form from being sent.
    def refuse(why, box = nil)
      Sound.play_buzzer
      MGQ_MpBugReport.log("refused: #{why}")
      box.focus if box
      @help.say(why)
    end

    # Tells the DLL the form closed, and why.
    #
    # @param why [Symbol, String] Why the window closed.
    def closed(why)
      reason = @sent ? "the report went" : CLOSED_REASONS.fetch(why, why.to_s)
      MGQ_MpBugReport.log("the form closed: #{reason}")
      MGQ_MpBugReport.closed(self, reason)
    end
  end
end

# What this script takes part in of the world, the action wheel and the DLL's events, through
# overworld_sync.rbx, ui_actions.rbx and the bridge.

begin
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpBugReport.tick(in_world) }
  MGQ_MpActions.wheel_choice(MGQ_MpBugReport::WHEEL_ORDER) { MGQ_MpBugReport.wheel_option }
  MGQ_MpActions.wheel.on(:gone) { MGQ_MpBugReport.wheel_gone }
  MGQ_Multiplayer::Bridge.on(MGQ_MpBugReport::SOUND_EVENT) { |name| MGQ_MpBugReport.play(name) }
  MGQ_Multiplayer::Bridge.on(MGQ_MpBugReport::NOTICE_EVENT) { |notice| MGQ_MpBugReport.notice(notice) }
  MGQ_Multiplayer::Bridge.on(MGQ_MpBugReport::CHAT_LINE_EVENT) { |text| MGQ_MpBugReport.chat_line(text) }
  MGQ_Multiplayer::Bridge.on(MGQ_MpBugReport::HOTKEY_REFUSED_EVENT) { |reason| MGQ_MpHotkeys.log_refusal(:bug_report, reason.to_s) }
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
