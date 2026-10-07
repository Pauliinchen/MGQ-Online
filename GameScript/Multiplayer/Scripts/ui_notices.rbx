#----------------------------------------------------------------
#  ui_notices.rbx
#
#  Changelog:
#      Paulinchen  2026-10-06: Showed messages outside a world too, such as a Discord invite taken during a game, dropping only those shown in a world once it closes
#      Paulinchen  2026-10-04: Renamed from mp_notices.rbx
#      Paulinchen  2026-10-03: Listed the invites the scripts offer through MGQ_MpActions
#                            - Called the scripts that load before this one without asking whether they loaded
#                            - Logged through MGQ_MpLog
#                            - Created
#
#----------------------------------------------------------------

# The notification box at the top left of the screen, on the map and in menus. It holds two kinds:
# invites, the party invites and duel challenges that reach the player in a world from wherever
# they were sent, which stay as long as they stand; and messages, which other scripts show for a
# moment, such as a party member meeting enemies, or a Discord invite taken outside a world. The
# invites come first, and the box's keys (Y and N unless the player binds others, see
# core_hotkeys.rbx) accept or decline the first one; messages take no key.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpNotices
  # Notifications the box shows at most; messages fill what the invites leave.
  MAX_ROWS = 5

  # Frames a message shows, three seconds.
  MESSAGE_FRAMES = 180

  # Scenes the box stays hidden in, by their class's name: battles, which have their own chat log,
  # the title and game over screens, and the novel scenes of the story.
  HIDDEN_SCENES = [/\AScene_(Battle|Title|Gameover)\z/, /Novel/]

  # Color of a message.
  MESSAGE_COLOR = Color.new(220, 220, 220)

  @messages = []
  @declined = {}

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "notices"

  # Shows a message for a moment, in place of one with the same key. One shown in a world goes when
  # the world closes.
  #
  # @param key [Object] What it is about.
  # @param text [String] What it says.
  # @param frames [Integer] How long it shows.
  def self.message(key, text, frames = MESSAGE_FRAMES)
    drop(key)
    @messages << { :key => key, :text => text, :frames => frames, :world => MGQ_MpOverworldSync.in_world? }
  end

  # Takes a message away before its time.
  #
  # @param key [Object] What it is about.
  def self.drop(key)
    @messages.reject! { |entry| entry[:key] == key }
  end

  # Lists what the box shows: the invites that stand, by their sender's name, then the messages,
  # newest first, as many as fit.
  #
  # @param in_world [Boolean] Whether a world is open, without which no invite stands.
  # @return [Array<MGQ_MpActions::Notice>] The notifications, at most MAX_ROWS.
  def self.notices(in_world = true)
    peers = in_world ? MGQ_MpOverworldSync::Peers.all.sort_by { |peer| peer.state["name"].to_s.downcase } : []
    invites = peers.map { |peer| MGQ_MpActions.offers.map { |offers| offers.notice_of(peer) } }.flatten.compact
    # An invite the player declined stays away while it stands; a new one shows again.
    @declined.delete_if { |key, mark| invites.none? { |invite| invite.key == key && invite.mark == mark } }
    invites.reject! { |invite| @declined[invite.key] == invite.mark }
    messages = @messages.reverse.map { |entry| MGQ_MpActions::Notice.new(entry[:key], entry[:text], MESSAGE_COLOR) }
    (invites + messages).first(MAX_ROWS)
  end

  # Counts the messages down, accepts or declines the first invite when its key went down, and draws
  # the box. Called every frame in every scene.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    # Both asked every frame, so a press while the box is hidden never counts later.
    accept = MGQ_MpHotkeys.pressed?(:accept)
    decline = MGQ_MpHotkeys.pressed?(:decline)
    @messages.each { |entry| entry[:frames] -= 1 }
    @messages.reject! { |entry| entry[:frames] <= 0 || (entry[:world] && !in_world) }
    @declined.clear unless in_world
    list = shown? ? notices(in_world) : []
    answer = accept ? :take : decline ? :decline : nil
    list = notices(in_world) if answer && !$mgq_text_input && !MGQ_Multiplayer::Capture.on? && answer_first(list, answer)
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

  # Accepts or declines the first invite, which the box names with the keys. A declined one stays
  # away while it stands.
  #
  # @param list [Array<MGQ_MpActions::Notice>] The notifications shown.
  # @param answer [Symbol] :take to accept, :decline to decline.
  # @return [Boolean] Whether the invite was answered.
  def self.answer_first(list, answer)
    invite = list.first
    return false unless invite && invite.decline && invite[answer]

    answer == :take ? Sound.play_ok : Sound.play_cancel
    @declined[invite.key] = invite.mark if answer == :decline
    invite[answer].call
    true
  end

  # Draws the box, making it the first time it shows anything.
  #
  # @param list [Array<MGQ_MpActions::Notice>] The notifications.
  def self.show(list)
    @box = nil if @box && @box.disposed?
    if list.empty?
      @box.visible = false if @box
      return
    end

    (@box ||= Sprite_MpNoticeBox.new).show(list)
  end
end

# The notification box at the top left of the screen, over every window of the map and the menus.
# It has no viewport, so it lasts from scene to scene.
class Sprite_MpNoticeBox < Sprite
  # Width of the box, which leaves room for the party box at the top right.
  WIDTH = 390

  # Height of one notification.
  ROW = 22

  # Room between the box and the top and left edges of the screen.
  MARGIN = 8

  # Width of what the keys do to the first invite, such as "Y: Accept  N: Decline".
  ACTION_WIDTH = 170

  # Background of the box, the party box's.
  BACK = Color.new(0, 0, 0, 140)

  # Color of the key and what it does.
  KEY_COLOR = Color.new(160, 220, 255)

  # Creates the box, hidden.
  def initialize
    super(nil)
    self.bitmap = Bitmap.new(WIDTH, ROW * MGQ_MpNotices::MAX_ROWS + 4)
    self.x = MARGIN
    self.y = MARGIN
    self.z = 260
    self.visible = false
    @shown = nil
  end

  # Shows the notifications, drawing them again only when they changed.
  #
  # @param list [Array<MGQ_MpActions::Notice>] The notifications, at least one.
  def show(list)
    self.visible = true
    keys = keys_text(list.first)
    drawn = list.map { |notice| notice.text } << keys
    return if drawn == @shown

    @shown = drawn
    draw(list, keys)
  end

  # Tells what the keys do to the first notification: accept and decline an invite, or only decline
  # one that cannot be accepted here.
  #
  # @param notice [MGQ_MpActions::Notice] The first notification.
  # @return [String, nil] The keys and what they do, nil for a message.
  def keys_text(notice)
    return nil unless notice.decline

    decline = "#{MGQ_MpHotkeys.label(:decline)}: Decline"
    notice.take ? "#{MGQ_MpHotkeys.label(:accept)}: #{notice.action}  #{decline}" : decline
  end

  # Draws the notifications, the first invite with its keys.
  #
  # @param list [Array<MGQ_MpActions::Notice>] The notifications.
  # @param keys [String, nil] What the keys do to the first one, see keys_text.
  def draw(list, keys)
    bitmap.clear
    bitmap.fill_rect(0, 0, WIDTH, ROW * list.size + 4, BACK)
    bitmap.font.outline = true
    bitmap.font.size = 16
    list.each_with_index do |notice, index|
      y = 2 + ROW * index
      keyed = index == 0 && keys
      bitmap.font.color = notice.color
      bitmap.draw_text(6, y, WIDTH - 12 - (keyed ? ACTION_WIDTH : 0), ROW, notice.text)
      next unless keyed

      bitmap.font.color = KEY_COLOR
      bitmap.draw_text(WIDTH - 6 - ACTION_WIDTH, y, ACTION_WIDTH, ROW, keys, 2)
    end
  end

  # Frees the box's picture.
  def dispose
    bitmap.dispose
    super
  end
end

# What the box takes part in of the world, through overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpNotices.tick(in_world) }
rescue => e
  MGQ_MpNotices.log("overworld sync FAILED: #{e.class}: #{e.message}")
end
