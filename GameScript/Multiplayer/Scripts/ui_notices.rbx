#----------------------------------------------------------------
#  ui_notices.rbx
#
#  Changelog:
#      Paulinchen  2026-11-01: Built the box on the Mod Framework's notification box, keeping the invites, the world's messages and the World overview here
#                            - Left the notice that the Mod Framework's settings cannot be read to the Mod Framework
#      Paulinchen  2026-10-31: Showed the notice that the Mod Framework's settings cannot be read
#                            - Read the capture and placed its box through the Mod Framework
#                            - Counted a message's time only while the box shows
#      Paulinchen  2026-10-22: Showed the relay's announcements, broken into the box's rows
#      Paulinchen  2026-10-12: Put the box at its default 4 pixels below the Leader HUD
#                            - Logged a refused hotkey through MGQ_MpHotkeys.log_refusal
#                            - Moved the box at its default below the Leader HUD
#                            - Told once a session that Player.ini could not be read
#      Paulinchen  2026-10-11: Made the box movable and resizable with the left Alt held
#                            - Framed the box in the preset's colors
#                            - Drew the box in the shared style with fades
#                            - Said how many more notifications wait in a last row and cut a long one to its row
#                            - Logged an accept or decline hotkey pressed where the box is hidden
#                            - Put three spaces between what the hotkeys do
#                            - Gave the hotkeys the room a rebound hotkey's longer name needs
#      Paulinchen  2026-10-10: Moved the box below a strip of the mod at the top of the screen
#      Paulinchen  2026-10-08: Kept an accepted invite away only for a moment
#                            - Kept an accepted invite away until the inviter drops it or turns the accept down
#      Paulinchen  2026-10-07: Kept an accepted invite away while it stands
#                            - Took the box's depth from MGQ_MpUi
#                            - Logged messages, the box's contents and answered invites
#      Paulinchen  2026-10-06: Showed messages outside a world too
#      Paulinchen  2026-10-04: Renamed from mp_notices.rbx
#      Paulinchen  2026-10-03: Listed the invites the scripts offer through MGQ_MpActions
#                            - Called the scripts that load before this one without asking whether they loaded
#                            - Logged through MGQ_MpLog
#                            - Created
#

# MGQ Online's part of the notification box, which is the Mod Framework's (Mod_Framework::UI::Notices):
# the invites that reach the player in a world from wherever they were sent, listed by their
# sender's name through MGQ_MpActions.offers, the messages the other scripts post under the names
# they know, and the rules of a world: what was posted in a world goes when it closes, and the box
# hides while the World overview is open.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpNotices
  # The Mod Framework's notification box.
  BOX = Mod_Framework::UI::Notices

  # The name the invites are listed under in the box.
  SOURCE = :mgq_online_invites

  # The group of what was posted in a world, which goes when the world closes.
  WORLD_GROUP = :mgq_online_world

  # The name the World overview hides the box under.
  OVERVIEW = :mgq_online_overview

  # Frames in a second, which the callers count a message's time in.
  FRAMES_PER_SECOND = 60

  # What the notice that Player.ini cannot be read is about.
  PLAYER_INI_KEY = :player_ini

  # Seconds the notice that Player.ini cannot be read shows.
  PLAYER_INI_SECONDS = 10

  # What the relay's announcement is about.
  ANNOUNCEMENT_KEY = :mgq_online_announcement

  # Seconds the relay's announcement shows.
  ANNOUNCEMENT_SECONDS = 10

  # Whether a world was open at the last tick.
  @in_world = false

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "notices"

  # Shows a message for a while, in place of one with the same key. One posted in a world goes when
  # the world closes.
  #
  # @param key [Object] What it is about.
  # @param text [String] What it says.
  # @param frames [Integer, nil] How long it shows while the box shows, the box's own time unless
  #   given.
  def self.message(key, text, frames = nil)
    options = { :key => key }
    options[:seconds] = frames.to_f / FRAMES_PER_SECOND if frames
    options[:group] = WORLD_GROUP if MGQ_MpOverworldSync.in_world?
    BOX.show(text, options)
  rescue => e
    log_once(:message, "posting a message failed: #{e.class}: #{e.message}")
  end

  # Shows a line the relay announces to every world, such as an admin's or a new release's, whole,
  # in place of the one before.
  #
  # @param text [String] The line.
  def self.announce(text)
    BOX.show(text, :key => ANNOUNCEMENT_KEY, :seconds => ANNOUNCEMENT_SECONDS, :wrap => true)
  rescue => e
    log_once(:announce, "announcement failed: #{e.class}: #{e.message}")
  end

  # Takes a message away before its time.
  #
  # @param key [Object] What it is about.
  # @param reason [String, nil] Why, for the log.
  def self.drop(key, reason = nil)
    log("dropping message #{key.inspect}: #{reason}") if reason
    BOX.drop(key)
  rescue => e
    log_once(:drop, "dropping a message failed: #{e.class}: #{e.message}")
  end

  # Shows an accepted invite again at once, as when the inviter's game turned the accept down, so
  # the player may accept it again while it stands.
  #
  # @param key [Object] The invite's key, see MGQ_MpActions::Notice.
  def self.release(key)
    BOX.release(key)
  end

  # Tells whether the box may show in the scene running.
  #
  # @return [Boolean] Whether it may.
  def self.shown?
    BOX.shown?
  end

  # Lists the invites that stand in the world open, by their sender's name, as offers of the box.
  #
  # @return [Array<Hash>] The offers, none outside a world.
  def self.invites
    return [] unless MGQ_MpOverworldSync.in_world?

    peers = MGQ_MpOverworldSync::Peers.all.sort_by { |peer| peer.state["name"].to_s.downcase }
    notices = peers.map { |peer| MGQ_MpActions.offers.map { |offers| offers.notice_of(peer) } }.flatten.compact
    notices.map { |notice| offer_of(notice) }
  end

  # Makes an offer of the box of an invite.
  #
  # @param notice [MGQ_MpActions::Notice] The invite.
  # @return [Hash] The offer, without an accept for an invite that cannot be accepted here.
  def self.offer_of(notice)
    { :key => notice.key, :text => notice.text, :color => notice.color, :accept_text => notice.action, :accept => notice.take,
      :decline => notice.decline, :mark => notice.mark, :group => WORLD_GROUP }
  end

  # Posts the notice that Player.ini cannot be read, and takes away what was posted in a world once
  # it closed. Called every frame in every scene.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    post_player_ini_notice
    if @in_world && !in_world
      log("the world closed: its invites and messages go")
      BOX.drop_group(WORLD_GROUP)
    end
    @in_world = in_world
  rescue => e
    log_once(:tick, "tick failed: #{e.class}: #{e.message}")
  end

  # Posts the notice that Player.ini cannot be read, once; the box counts its time only while it
  # shows, so it never runs out unseen on the title screen.
  def self.post_player_ini_notice
    text = MGQ_Multiplayer::Player.take_notice
    BOX.show(text, :key => PLAYER_INI_KEY, :seconds => PLAYER_INI_SECONDS) if text
  end
end

# What the box takes of the world, through overworld_sync.rbx.

begin
  MGQ_MpNotices::BOX.offers(MGQ_MpNotices::SOURCE, :log => MGQ_MpNotices) { MGQ_MpNotices.invites }
  MGQ_MpNotices::BOX.hide_while(MGQ_MpNotices::OVERVIEW) { SceneManager.scene.is_a?(Scene_Map) && MGQ_MpWorldOverview.open? }
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpNotices.tick(in_world) }
rescue => e
  MGQ_MpNotices.log("overworld sync FAILED: #{e.class}: #{e.message}")
end
