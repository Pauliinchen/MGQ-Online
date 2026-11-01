#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-11-01: Named the close keys in the help tab's last line as ChatModel names them
#      Paulinchen  2026-10-31: Wrote the texts C# words anew as C# words them
#                            - Created
#
#----------------------------------------------------------------

# Writes the golden cases of the chat next to this file, cases.json, from ui_chat.rbx as it kept
# the chat's rules before they moved to C# (MGQOnline.Game's Chat/ChatModel): sending to each
# chat, the commands, whispers, /r and the names offered, receiving with the map's check, the
# admin's lines and the relay's notices, the tabs and the unread ones, the help tab, the lines sent
# brought back, the lifetimes of lines and bubbles, and the reset as the world closes. Each
# scenario is a list of steps; a step's operation runs, then the step records the chat's lines in
# the log, its sounds, notices and sends, the box's text, and the chat's state and lines.
# MGQOnline.Game.Tests replays them against the C# model through the world room's routes.
#
# It runs on the scripts of commit 2f6888c0, which still kept the rules in ui_chat.rbx, through
# the script tests' stand-ins, on Ruby 3.3, from a checkout of that commit with this file copied in:
#
#   ruby fixtures/chat/make_fixtures.rb

require "json"
require_relative "../../GameScript/Tests/world_support"

# The log's lines, which the cases record when they are the chat's.
$logs = []
module MGQ_Multiplayer::Log; def self.write(line); $logs << line; end; end

# The notices at the bottom left and the notification box's announcements.
$notices = []
$announced = []
module MGQ_MpOverworldSync; def self.notice(text, _icon = nil); $notices << text; end; end
module MGQ_MpNotices; def self.announce(text); $announced << text; end; end

# The whisper's sound, which world_support.rb's Sound lacks.
def Sound.play_recovery; $sounds << "recovery"; end

# Whether the open text box is locked, as the chat last locked it.
$locked = false
class MGQ_MpUi::TextEdit
  alias_method :fixture_initialize, :initialize
  alias_method :fixture_lock, :lock
  # Opens the box unlocked.
  def initialize(*arguments); $locked = false; fixture_initialize(*arguments); end
  # Records the lock before handing it on.
  def lock(locked); $locked = locked; fixture_lock(locked); end
end

CHAT = MGQ_MpChat

# The keys the alt operation presses with the left Alt.
ALT_KEYS = { "left" => CHAT::LEFT_KEY, "right" => CHAT::RIGHT_KEY, "up" => CHAT::UP_KEY, "down" => CHAT::DOWN_KEY }

# The scenes a tick runs in.
SCENES = { "map" => Scene_Map, "title" => Scene_Title }

# The scenarios, each its name and its steps.
SCENARIOS = []

# Records a scenario of steps, the world open with the player on map 5 and nobody else in it.
#
# @param name [String] What the scenario shows.
# @param steps [Array<Hash>] The operations, see run_step.
def scenario(name, steps)
  $open = true
  $say_result = nil
  $chat_sent = nil
  SceneManager.scene = Scene_Map.new
  take_party(nil)
  CHAT.reset
  MGQ_MpOverworldSync::Peers.clear
  recorded = steps.map { |step| step.merge("answer" => run_step(step)) }
  SCENARIOS << { "name" => name, "steps" => recorded }
end

# Runs one operation and reads what the chat answers.
#
# @param step [Hash] "op" and its fields: "tell" ("seat", "state"), "out" ("seat"), "party" ("id",
#   "leader", "members" seats), "open" ("key"), "type" ("text"), "enter", "escape", "alt" ("key"),
#   "pick" ("step"), "tab_key", "select" ("tab"), "whisper" ("name", "seat"), "receive" ("seat",
#   nil for the relay's, "fields"), "system" ("text"), "tick" ("in_world", "scene", "frames"),
#   "relay" ("said", "sent": the answers of chat.send).
# @return [Hash] What the chat answers after the step.
def run_step(step)
  [$logs, $notices, $announced, $sounds, $chats].each(&:clear)
  peers = MGQ_MpOverworldSync::Peers
  case step["op"]
  when "tell" then peer_told(step["seat"], step["state"])
  when "out" then peers.away(step["seat"])
  when "party" then take_party(step["id"], step["members"].map { |seat| peers.at(seat) }, step["leader"])
  when "open" then CHAT.start_typing(step["key"] ? 0x54 : nil)
  when "type"
    CHAT.editor.edit(step["text"], step["text"].size)
    CHAT.take_typed_command
  when "enter" then CHAT.type(:enter)
  when "escape" then CHAT.type(:escape)
  when "alt"
    $down = [CHAT::ALT_KEY]
    $pressed = ALT_KEYS[step["key"]]
    CHAT.alt_keys
    $down = []
    $pressed = nil
  when "pick"
    $buttons = [step["step"] > 0 ? :DOWN : :UP]
    CHAT.update_pick
  when "tab_key" then CHAT.take_suggestion
  when "select" then CHAT.select_tab(step["tab"].to_sym, "with a click")
  when "whisper" then CHAT.whisper(step["name"], peers.at(step["seat"]))
  when "receive" then receive(step["seat"], step["fields"])
  when "system" then CHAT.system(step["text"])
  when "tick"
    SceneManager.scene = SCENES[step["scene"] || "map"].new
    $open = step["in_world"]
    (step["frames"] || 1).times { CHAT.tick(step["in_world"]) }
    $open = true
    SceneManager.scene = Scene_Map.new
  when "relay"
    $say_result = step["said"]
    $chat_sent = step["sent"]
  end
  read_answer
end

# Hands a message to the chat as its route does: the chat's and the whisper's straight, the party
# chat's as coop.rbx hands it on once it passed the party's gate.
#
# @param seat [Integer, nil] The sender's seat, nil for the relay's push.
# @param fields [Hash] The message's fields.
def receive(seat, fields)
  peer = seat && MGQ_MpOverworldSync::Peers.at(seat)
  message = fields.dup
  message[:relay] = true if seat.nil?
  if message["whisper"]
    CHAT.receive_whisper(peer, message)
  elsif message["pchat"]
    CHAT.receive_party(peer, message)
  else
    CHAT.receive(peer, message)
  end
end

# Reads what the chat shows after a step.
#
# @return [Hash] The answer.
def read_answer
  {
    "logs" => $logs.select { |line| line.start_with?("chat: ") },
    "notices" => $notices.dup,
    "announced" => $announced.dup,
    "sounds" => $sounds.dup,
    "sends" => $chats.map { |request| [request["channel"], request["text"], request["seat"], request["map"]] },
    "typing" => CHAT.typing?,
    "box" => CHAT.typing? ? [CHAT.typed, CHAT.cursor, $locked] : nil,
    "channel" => CHAT.channel.to_s,
    "tab" => CHAT.tab.to_s,
    "tabs" => CHAT.tabs.map(&:to_s),
    "unread" => CHAT.unread_tabs.map(&:to_s),
    "whisper_to" => CHAT.whisper_to,
    "reply_to" => CHAT.reply_to,
    "suggestions" => CHAT.typing? ? CHAT.suggestions : [],
    "pick" => CHAT.pick,
    "lines" => CHAT.log_entries.map { |line| [line.to_s, line.who.to_s, line.channel.to_s] },
    "bubbles" => CHAT.senders.map { |sender| [sender == :me ? -1 : sender, CHAT.bubble(sender), CHAT.bubble_channel(sender).to_s] },
  }
end

# The other players: a friend and a stranger on the player's map, and one far away.
FRIEND = { "id" => "friend01", "name" => "Friend", "map" => 5, "x" => 6, "y" => 4 }
STRANGER = { "id" => "strange1", "name" => "Stranger", "map" => 5, "x" => 9, "y" => 9 }
FAR = { "id" => "faraway1", "name" => "Faraway", "map" => 7, "x" => 1, "y" => 1 }
PLAYERS = [{ "op" => "tell", "seat" => 2, "state" => FRIEND }, { "op" => "tell", "seat" => 3, "state" => STRANGER },
           { "op" => "tell", "seat" => 4, "state" => FAR }]

scenario("the global and the map chat, sent and received", PLAYERS + [
  { "op" => "open", "key" => true },
  { "op" => "type", "text" => "hello all" },
  { "op" => "enter" },
  { "op" => "open", "key" => false },
  { "op" => "type", "text" => "/m " },
  { "op" => "type", "text" => "hi map" },
  { "op" => "enter" },
  { "op" => "receive", "seat" => 2, "fields" => { "chat" => "yo", "name" => "Friend" } },
  { "op" => "receive", "seat" => 4, "fields" => { "chat" => "far", "name" => "Faraway", "ch" => "say", "map" => "7" } },
  { "op" => "receive", "seat" => 2, "fields" => { "chat" => "near", "name" => "Friend", "ch" => "say", "map" => "5" } },
  { "op" => "receive", "seat" => nil, "fields" => { "chat" => "The relay restarts soon.", "name" => "MGQ Online" } },
  { "op" => "receive", "seat" => nil, "fields" => { "chat" => "hello from outside", "name" => "Admin" } },
  { "op" => "receive", "seat" => 9, "fields" => { "chat" => "early", "name" => "Ghost" } },
  { "op" => "receive", "seat" => 2, "fields" => { "chat" => "\a bell line  end\t ", "name" => "Friend" } },
  { "op" => "receive", "seat" => 2, "fields" => { "chat" => "   ", "name" => "Friend" } },
  { "op" => "receive", "seat" => 3, "fields" => { "chat" => "x" * 130, "name" => "Stranger" } },
  { "op" => "system", "text" => "Friend left the battle." },
  { "op" => "tick", "in_world" => true, "frames" => 359 },
  { "op" => "tick", "in_world" => true },
  { "op" => "tick", "in_world" => true, "frames" => 240 },
  { "op" => "open", "key" => true },
  { "op" => "escape" },
  { "op" => "tick", "in_world" => false },
])

scenario("the commands, the global chat chosen without a line and sending refused", PLAYERS + [
  { "op" => "open", "key" => true },
  { "op" => "type", "text" => "/G" },
  { "op" => "type", "text" => "/Map hello" },
  { "op" => "enter" },
  { "op" => "open", "key" => true },
  { "op" => "type", "text" => "/g" },
  { "op" => "enter" },
  { "op" => "open", "key" => true },
  { "op" => "type", "text" => "/x not a command" },
  { "op" => "enter" },
  { "op" => "select", "tab" => "party" },
  { "op" => "open", "key" => true },
  { "op" => "type", "text" => "anyone?" },
  { "op" => "enter" },
  { "op" => "select", "tab" => "global" },
  { "op" => "relay", "said" => 2, "sent" => true },
  { "op" => "open", "key" => true },
  { "op" => "type", "text" => "too fast" },
  { "op" => "enter" },
  { "op" => "relay", "said" => 0, "sent" => false },
  { "op" => "open", "key" => true },
  { "op" => "type", "text" => "#{'long ' * 20}line" },
  { "op" => "enter" },
  { "op" => "relay", "said" => 0, "sent" => true },
  { "op" => "open", "key" => true },
  { "op" => "type", "text" => "not mirrored" },
  { "op" => "enter" },
])

scenario("whispers, /r, the names offered and a name that left", PLAYERS + [
  { "op" => "tell", "seat" => 1, "state" => { "id" => "frieda01", "name" => "frieda", "map" => 5, "x" => 2, "y" => 2 } },
  { "op" => "open", "key" => true },
  { "op" => "type", "text" => "/w fr" },
  { "op" => "pick", "step" => 1 },
  { "op" => "pick", "step" => 1 },
  { "op" => "pick", "step" => -1 },
  { "op" => "tab_key" },
  { "op" => "type", "text" => "secret" },
  { "op" => "enter" },
  { "op" => "receive", "seat" => 3, "fields" => { "whisper" => "psst", "name" => "Stranger" } },
  { "op" => "receive", "seat" => 3, "fields" => { "whisper" => "again", "name" => "Stranger" } },
  { "op" => "tick", "in_world" => true },
  { "op" => "open", "key" => true },
  { "op" => "receive", "seat" => 3, "fields" => { "whisper" => "while typing", "name" => "Stranger" } },
  { "op" => "type", "text" => "/r back to you" },
  { "op" => "enter" },
  { "op" => "open", "key" => true },
  { "op" => "type", "text" => "/whisper Friend hi Friend" },
  { "op" => "enter" },
  { "op" => "open", "key" => true },
  { "op" => "type", "text" => "/w Nobody hi" },
  { "op" => "enter" },
  { "op" => "open", "key" => true },
  { "op" => "type", "text" => "/w" },
  { "op" => "enter" },
  { "op" => "out", "seat" => 2 },
  { "op" => "open", "key" => true },
  { "op" => "type", "text" => "are you there" },
  { "op" => "enter" },
  { "op" => "out", "seat" => 3 },
  { "op" => "open", "key" => true },
  { "op" => "type", "text" => "/r gone too" },
  { "op" => "enter" },
  { "op" => "whisper", "name" => "frieda", "seat" => 1 },
  { "op" => "select", "tab" => "all" },
])

scenario("the tabs, the unread ones, the help tab and the lines sent brought back", PLAYERS + [
  { "op" => "open", "key" => true },
  { "op" => "type", "text" => "/help " },
  { "op" => "alt", "key" => "left" },
  { "op" => "alt", "key" => "right" },
  { "op" => "escape" },
  { "op" => "open", "key" => true },
  { "op" => "type", "text" => "/help" },
  { "op" => "enter" },
  { "op" => "escape" },
  { "op" => "open", "key" => true },
  { "op" => "type", "text" => "first line" },
  { "op" => "enter" },
  { "op" => "open", "key" => true },
  { "op" => "type", "text" => "second line" },
  { "op" => "enter" },
  { "op" => "open", "key" => true },
  { "op" => "type", "text" => "second line" },
  { "op" => "enter" },
  { "op" => "open", "key" => true },
  { "op" => "type", "text" => "dra" },
  { "op" => "alt", "key" => "up" },
  { "op" => "alt", "key" => "up" },
  { "op" => "alt", "key" => "up" },
  { "op" => "alt", "key" => "down" },
  { "op" => "alt", "key" => "down" },
  { "op" => "alt", "key" => "down" },
  { "op" => "alt", "key" => "right" },
  { "op" => "alt", "key" => "right" },
  { "op" => "escape" },
  { "op" => "receive", "seat" => 2, "fields" => { "chat" => "unseen", "name" => "Friend" } },
  { "op" => "receive", "seat" => 2, "fields" => { "chat" => "on the map", "name" => "Friend", "ch" => "say", "map" => "5" } },
  { "op" => "tick", "in_world" => true },
  { "op" => "select", "tab" => "global" },
  { "op" => "tick", "in_world" => true },
  { "op" => "select", "tab" => "all" },
  { "op" => "tick", "in_world" => true },
  { "op" => "open", "key" => true },
  { "op" => "tick", "in_world" => true, "scene" => "title" },
])

scenario("the party chat", [
  { "op" => "tell", "seat" => 2, "state" => { "id" => "leader01", "name" => "Leader", "map" => 5, "x" => 6, "y" => 4, "party" => "leader01p1", "party_members" => "me000001,friend01" } },
  { "op" => "tell", "seat" => 3, "state" => FRIEND.merge("party" => "leader01p1") },
  { "op" => "tell", "seat" => 4, "state" => STRANGER.merge("party" => "strange1p1") },
  { "op" => "party", "id" => "leader01p1", "leader" => 2, "members" => [2, 3] },
  { "op" => "receive", "seat" => 3, "fields" => { "pchat" => "team line", "name" => "Friend", "party" => "leader01p1" } },
  { "op" => "receive", "seat" => 4, "fields" => { "chat" => "outsider", "name" => "Stranger" } },
  { "op" => "open", "key" => true },
  { "op" => "type", "text" => "/p hi team" },
  { "op" => "enter" },
  { "op" => "tick", "in_world" => false },
])

# The texts C# words anew, each the script's text and the one ChatModel shows.
REWORDED = { "You are in no party, so nobody hears the party chat." => "You are not in a party.",
              "Enter sends, Esc or the numpad's 0 closes." => "Enter sends, Esc or Numpad 0 closes." }

text = JSON.pretty_generate({ "scenarios" => SCENARIOS }) + "\n"
File.write(File.join(__dir__, "cases.json"), REWORDED.inject(text) { |cases, (old, now)| cases.gsub(old, now) })
puts "wrote #{SCENARIOS.size} scenarios"
