#----------------------------------------------------------------
#  ui_notices.rbx
#
#  Changelog:
#      Paulinchen  2026-10-11: Made the box movable and resizable with the left Alt held, as "Notifications": its width gives the notifications room and its height the rows it shows, never below the first invite's keys beside a readable name and two rows
#                            - Framed the box in the preset's colors, drawn anew once the preset changes
#                            - Drew the box in the shared style, fading it in and out, a message that runs out and an invite just answered fading away where it stood
#                            - Said how many more notifications wait in a last row once more than the box's rows do, through MGQ_MpUi.capped, and cut a long one to its row
#                            - Logged an accept or decline key pressed where the box is hidden, such as on the overview's World page
#                            - Put three spaces between what the keys do, as the chat's hints do
#                            - Gave the keys the room a rebound key's longer name needs, cutting the notification before them instead of the keys
#      Paulinchen  2026-10-10: Moved the box down while a strip of the mod takes the top of the map's screen, such as the raid boss's bar
#      Paulinchen  2026-10-08: Kept an accepted invite away only for a moment, so one whose accept did nothing, such as in a menu, shows again
#                            - Kept an accepted invite away until the inviter drops it or turns the accept down, ten seconds at most, which a slow inviter let a second press accept again
#      Paulinchen  2026-10-07: Kept an accepted invite away while it stands, as a declined one, so a second press no longer accepts it again
#                            - Took the box's depth from MGQ_MpUi
#                            - Logged each message posted, dropped or run out, what the box shows whenever it changes, and each invite answered or key ignored with why
#      Paulinchen  2026-10-06: Showed messages outside a world too, such as a Discord invite taken during a game, dropping only those shown in a world once it closes
#      Paulinchen  2026-10-04: Renamed from mp_notices.rbx
#      Paulinchen  2026-10-03: Listed the invites the scripts offer through MGQ_MpActions
#                            - Called the scripts that load before this one without asking whether they loaded
#                            - Logged through MGQ_MpLog
#                            - Created
#
#----------------------------------------------------------------

# The notification box, at the top left of the screen until the player moves it, on the map and in
# menus. It holds two kinds: invites, the party invites and duel challenges that reach the player
# in a world from wherever they were sent, which stay as long as they stand; and messages, which
# other scripts show for a moment, such as a party member meeting enemies, or a Discord invite
# taken outside a world. The invites come first, and the box's keys (Y and N unless the player
# binds others, see core_hotkeys.rbx) accept or decline the first one; messages take no key. A
# message that runs out and an invite just answered fade away; past the box's rows a last row says
# how many more wait.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpNotices
  # Rows the box shows at its default height; a taller box shows more. Messages fill what the
  # invites leave, and the last row says how many more wait once there are more than the rows.
  MAX_ROWS = 5

  # Scenes the box stays hidden in, by their class's name: battles, which have their own chat log,
  # the title and game over screens, and the novel scenes of the story.
  HIDDEN_SCENES = [/\AScene_(Battle|Title|Gameover)\z/, /Novel/]

  # Frames an accepted invite stays away at most, ten seconds, unless the inviter's game drops it or
  # turns the accept down before; after them it shows again if it still stands, since the accept
  # then did nothing.
  #
  # A slow inviter still shows the invite a while after the accept, so a shorter hold let a second
  # press accept it again.
  ACCEPT_HOLD_FRAMES = 600

  @messages = []
  @answered = {}
  @going = []
  @logged = []

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "notices"

  # Shows a message for a moment, in place of one with the same key. One shown in a world goes when
  # the world closes.
  #
  # @param key [Object] What it is about.
  # @param text [String] What it says.
  # @param frames [Integer] How long it shows, MGQ_MpUi::Style::LINGER_FRAMES unless told otherwise.
  def self.message(key, text, frames = MGQ_MpUi::Style::LINGER_FRAMES)
    drop(key, "a newer one replaces it")
    world = MGQ_MpOverworldSync.in_world?
    @messages << { :key => key, :text => text, :frames => frames, :world => world }
    log("message posted for #{frames} frames#{world ? ' while in a world' : ''} (#{key.inspect}): #{MGQ_MpLog.short(text)}")
  end

  # Takes a message away before its time.
  #
  # @param key [Object] What it is about.
  # @param reason [String] Why, for the log.
  def self.drop(key, reason = "taken away")
    dropped = @messages.select { |entry| entry[:key] == key }
    @messages -= dropped
    dropped.each { |entry| log("message dropped, #{reason}: #{MGQ_MpLog.short(entry[:text])}") }
  end

  # Shows an accepted invite again at once, as when the inviter's game turned the accept down, so
  # the player may accept it again while it stands.
  #
  # @param key [Object] The invite's key, see MGQ_MpActions::Notice.
  def self.release(key)
    answer = @answered[key]
    return unless answer && answer[:frames]

    @answered.delete(key)
    log("accepted invite #{key.inspect} shows again: the inviter turned the accept down")
  end

  # Lists what the box shows: the invites that stand, by their sender's name, then the invites
  # just answered, fading away where they stood, then the messages, newest first, a message about
  # to run out in its fading color.
  #
  # @param in_world [Boolean] Whether a world is open, without which no invite stands.
  # @return [Array<MGQ_MpActions::Notice>] The notifications, see MGQ_MpUi.capped for the rows shown.
  def self.notices(in_world = true)
    style = MGQ_MpUi::Style
    peers = in_world ? MGQ_MpOverworldSync::Peers.all.sort_by { |peer| peer.state["name"].to_s.downcase } : []
    invites = peers.map { |peer| MGQ_MpActions.offers.map { |offers| offers.notice_of(peer) } }.flatten.compact
    # A declined invite stays away while it stands, an accepted one for ACCEPT_HOLD_FRAMES; a new
    # one shows again.
    @answered.delete_if do |key, answer|
      (answer[:frames] && answer[:frames] <= 0) || invites.none? { |invite| invite.key == key && invite.mark == answer[:mark] }
    end
    invites.reject! { |invite| @answered[invite.key] && @answered[invite.key][:mark] == invite.mark }
    messages = @messages.reverse.map { |entry| MGQ_MpActions::Notice.new(entry[:key], entry[:text], style.faded(style::DIM, entry[:frames])) }
    # An answered invite fades from its first frame on, down to nothing in its last.
    going = @going.map { |entry| MGQ_MpActions::Notice.new([:going, entry[:text]], entry[:text], style.faded(entry[:color], entry[:frames] - 1)) }
    invites + going + messages
  end

  # Counts the messages and the fading invites down, accepts or declines the first invite when its
  # key went down, and draws the box. Called every frame in every scene.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    # Both asked every frame, so a press while the box is hidden never counts later.
    accept = MGQ_MpHotkeys.pressed?(:accept)
    decline = MGQ_MpHotkeys.pressed?(:decline)
    @messages.each { |entry| entry[:frames] -= 1 }
    gone = @messages.select { |entry| entry[:frames] <= 0 || (entry[:world] && !in_world) }
    gone.each { |entry| log("message #{entry[:frames] <= 0 ? 'ran out' : 'dropped, the world closed'}: #{MGQ_MpLog.short(entry[:text])}") }
    @messages -= gone
    @going.each { |entry| entry[:frames] -= 1 }
    @going.reject! { |entry| entry[:frames] <= 0 }
    @answered.each_value { |answer| answer[:frames] -= 1 if answer[:frames] }
    unless in_world
      @answered.clear
      @going.clear
    end
    hidden = !shown?
    list = hidden ? [] : notices(in_world)
    answer = accept ? :take : decline ? :decline : nil
    log("#{answer == :take ? 'accept' : 'decline'} key ignored: the box is hidden here") if answer && hidden
    list = notices(in_world) if answer && answerable?(list, answer) && answer_first(list, answer)
    show(list)
  rescue => e
    log_once(:tick, "tick failed: #{e.class}: #{e.message}")
  end

  # Reports whether the box may show in the scene running: on the map while the World overview is
  # closed, and in menus.
  #
  # @return [Boolean] Whether it may.
  def self.shown?
    scene = SceneManager.scene
    return false if scene.nil? || HIDDEN_SCENES.any? { |name| scene.class.name.to_s =~ name }

    !(scene.is_a?(Scene_Map) && MGQ_MpWorldOverview.open?)
  end

  # Accepts or declines the first invite, which the box names with the keys, and lets it fade
  # away. A declined one stays away while it stands, an accepted one for ACCEPT_HOLD_FRAMES at
  # most: the inviter's game shows it until it opens what was accepted, in which time a second
  # accept turned the trade down as busy.
  #
  # @param list [Array<MGQ_MpActions::Notice>] The notifications shown.
  # @param answer [Symbol] :take to accept, :decline to decline.
  # @return [Boolean] Whether the invite was answered.
  def self.answer_first(list, answer)
    invite = list.first
    unless invite && invite.decline && invite[answer]
      log("#{answer == :take ? 'accept' : 'decline'} key ignored: #{invite.nil? ? 'the box is empty' : invite.decline.nil? ? 'the first line is a message' : 'the first invite cannot be accepted here'}")
      return false
    end

    answer == :take ? Sound.play_ok : Sound.play_cancel
    @answered[invite.key] = { :mark => invite.mark, :frames => answer == :take ? ACCEPT_HOLD_FRAMES : nil }
    @going << { :text => invite.text, :color => invite.color, :frames => MGQ_MpUi::Style::FADE_FRAMES }
    log("#{answer == :take ? 'accepted' : 'declined'} the first invite (#{invite.key.inspect}): #{MGQ_MpLog.short(invite.text)}")
    invite[answer].call
    true
  end

  # Reports whether the box's keys may answer now: not while the player types or a screen of the
  # mod holds the buttons, which the log then says.
  #
  # @param list [Array<MGQ_MpActions::Notice>] The notifications shown.
  # @param answer [Symbol] :take or :decline.
  # @return [Boolean] Whether they may.
  def self.answerable?(list, answer)
    return true unless $mgq_text_input || MGQ_Multiplayer::Capture.on?

    log("#{answer == :take ? 'accept' : 'decline'} key ignored: #{$mgq_text_input ? 'the player types' : 'a screen of the mod holds the buttons'}") unless list.empty?
    false
  end

  # Draws the box where the layout puts it, making it the first time it shows anything, with as
  # many notifications as its rows hold, and fades it out once it has nothing to show.
  #
  # @param list [Array<MGQ_MpActions::Notice>] The notifications.
  def self.show(list)
    rect = Sprite_MpNoticeBox.rect
    shown, more = MGQ_MpUi.capped(list, Sprite_MpNoticeBox.rows_in(rect.height))
    texts = shown.map { |notice| notice.text }
    texts << MGQ_MpUi::MORE_TEXT % more if more > 0
    if texts != @logged
      log(texts.empty? ? "box hidden or empty" : "box shows: #{texts.map { |text| MGQ_MpLog.short(text, 60) }.join(' | ')}")
      @logged = texts
    end
    @box = nil if @box && @box.disposed?
    if shown.empty?
      @box.hide if @box
    else
      (@box ||= Sprite_MpNoticeBox.new).show(shown, more, rect)
    end
    @box.update if @box
  end
end

# The notification box, at the top left of the screen until the player moves it, over every window
# of the map and the menus, drawn in the shared style and fading in and out. It has no viewport, so
# it lasts from scene to scene.
class Sprite_MpNoticeBox < Sprite
  # The box's id in the layout, which names its setting in Player.ini.
  LAYOUT = :notices

  # The box's name while the player arranges the boxes.
  LAYOUT_NAME = "Notifications"

  # Width of the box at its default, which leaves room for the party box at the top right.
  WIDTH = 390

  # Height of one notification.
  ROW = 22

  # Room between the box and the top and left edges of the screen at its default, below a strip of
  # the mod at the top (see MGQ_MpUi.top_room).
  MARGIN = 8

  # Room between the box's edges and its rows.
  EDGE = 6

  # Room above the first row and below the last, inside the box's frame.
  SPACING = 2

  # Least width of what the keys do to the first invite, such as "Y: Accept   N: Decline", see
  # keys_width.
  ACTION_WIDTH = 170

  # Least room of the first invite before its keys, about 14 letters of the small font, so the
  # sender's name stays readable.
  MIN_TEXT_WIDTH = 116

  # Fewest rows the box has: one notification and the row that says how many more wait.
  MIN_ROWS = 2

  # Least size of the box: the first invite's keys beside a readable notification, and MIN_ROWS.
  MIN_WIDTH = ACTION_WIDTH + MIN_TEXT_WIDTH + 2 * EDGE
  MIN_HEIGHT = ROW * MIN_ROWS + 2 * SPACING

  # Tells where the box draws: where the player left it, else at the top left below a strip of the
  # mod, as tall as MGQ_MpNotices::MAX_ROWS.
  #
  # @return [Rect] The place, see MGQ_MpUi::Layout.rect.
  def self.rect
    default = Rect.new(MARGIN, MARGIN + MGQ_MpUi.top_room, WIDTH, ROW * MGQ_MpNotices::MAX_ROWS + 2 * SPACING)
    MGQ_MpUi::Layout.rect(LAYOUT, default)
  end

  # Tells how many rows a box of a height shows.
  #
  # @param height [Integer] The box's height.
  # @return [Integer] The rows, MIN_ROWS at least.
  def self.rows_in(height)
    [(height - 2 * SPACING) / ROW, MIN_ROWS].max
  end

  # Creates the box, hidden.
  def initialize
    super(nil)
    rect = self.class.rect
    fit(rect)
    self.x = rect.x
    self.y = rect.y
    self.z = MGQ_MpUi::Z[:bubbles]
    @motion = MGQ_MpUi::Motion.new(self)
    @shown = nil
  end

  # Shows the notifications where the layout puts the box, fading it in, drawing them again only
  # when they, the box's size or the preset changed; a fading one changes every frame.
  #
  # @param list [Array<MGQ_MpActions::Notice>] The notifications, at least one.
  # @param more [Integer] How many more wait than the box lists, see MGQ_MpUi.capped.
  # @param rect [Rect] Where the box draws, see rect.
  def show(list, more, rect)
    fit(rect)
    @motion.place(rect.x, rect.y)
    @motion.show
    keys = keys_text(list.first)
    drawn = list.map { |notice| [notice.text, notice.color] } << keys << more << MGQ_MpUi::Theme.serial
    return if drawn == @shown

    @shown = drawn
    draw(list, keys, more)
  end

  # Fades the box out, keeping its picture until it is gone.
  def hide
    @motion.hide
  end

  # Moves the fade a frame on, and offers the box to the layout while it shows. Called every frame,
  # also while the box fades out.
  def update
    super
    @motion.update
    MGQ_MpUi::Layout.offer(LAYOUT, @rect.x, @rect.y, @rect.width, @rect.height, z) if @motion.shown?
  end

  # Sizes the picture to the box's place, making it anew once the size changed.
  #
  # @param rect [Rect] Where the box draws.
  def fit(rect)
    @rect = rect
    return if bitmap && !bitmap.disposed? && bitmap.width == rect.width && bitmap.height == rect.height

    bitmap.dispose if bitmap && !bitmap.disposed?
    self.bitmap = Bitmap.new(rect.width, rect.height)
    @shown = nil
  end

  # Tells what the keys do to the first notification: accept and decline an invite, or only decline
  # one that cannot be accepted here.
  #
  # @param notice [MGQ_MpActions::Notice] The first notification.
  # @return [String, nil] The keys and what they do, nil for a message.
  def keys_text(notice)
    return nil unless notice.decline

    decline = "#{MGQ_MpHotkeys.label(:decline)}: Decline"
    notice.take ? "#{MGQ_MpHotkeys.label(:accept)}: #{notice.action}   #{decline}" : decline
  end

  # Draws the notifications in a framed box as wide as the picture and as tall as its rows, the
  # first invite cut before its keys, the others cut to their row, and the last row with how many
  # more wait.
  #
  # @param list [Array<MGQ_MpActions::Notice>] The notifications.
  # @param keys [String, nil] What the keys do to the first one, see keys_text.
  # @param more [Integer] How many more wait, 0 for none.
  def draw(list, keys, more)
    style = MGQ_MpUi::Style
    box_width = bitmap.width
    rows = list.size + (more > 0 ? 1 : 0)
    bitmap.clear
    style.draw_box(bitmap, 0, 0, box_width, ROW * rows + 2 * SPACING)
    width = keys ? keys_width(keys) : 0
    list.each_with_index do |notice, index|
      y = SPACING + ROW * index
      keyed = index == 0 && keys
      room = [box_width - 2 * EDGE - (keyed ? width : 0), 0].max
      style.use_font(bitmap, style::SMALL_SIZE, notice.color)
      bitmap.draw_text(EDGE, y, room, ROW, MGQ_MpUi.cut(bitmap, notice.text, room))
      next unless keyed

      style.use_font(bitmap, style::SMALL_SIZE, style::HEADING)
      bitmap.draw_text(box_width - EDGE - width, y, width, ROW, keys, 2)
    end
    return unless more > 0

    style.use_font(bitmap, style::SMALL_SIZE, style::DIM)
    bitmap.draw_text(EDGE, SPACING + ROW * list.size, box_width - 2 * EDGE, ROW, MGQ_MpUi::MORE_TEXT % more)
  end

  # Tells how wide the keys' column is: ACTION_WIDTH, or what the keys need with the style's
  # padding before them when a rebound key's longer name needs more, since the keys are never cut.
  #
  # @param keys [String] What the keys do, see keys_text.
  # @return [Integer] The width.
  def keys_width(keys)
    style = MGQ_MpUi::Style
    style.use_font(bitmap, style::SMALL_SIZE, style::HEADING)
    [bitmap.text_size(keys).width + style::PAD, ACTION_WIDTH].max
  end

  # Frees the box's picture.
  def dispose
    bitmap.dispose
    super
  end
end

# Where the box lies, which the player changes with the left Alt held, through ui_layout.rbx.

begin
  MGQ_MpUi::Layout.register(Sprite_MpNoticeBox::LAYOUT, Sprite_MpNoticeBox::LAYOUT_NAME, Sprite_MpNoticeBox::MIN_WIDTH, Sprite_MpNoticeBox::MIN_HEIGHT, :both)
rescue => e
  MGQ_MpNotices.log("layout FAILED: #{e.class}: #{e.message}")
end

# What the box takes part in of the world, through overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpNotices.tick(in_world) }
rescue => e
  MGQ_MpNotices.log("overworld sync FAILED: #{e.class}: #{e.message}")
end
