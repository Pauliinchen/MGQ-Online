#----------------------------------------------------------------
#  duel_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Handed the team and took a team duel's sides as values, which the DLL writes and reads
#                            - Expected the players a challenge names as a list
#      Paulinchen  2026-10-30: Checked the script's side of the DLL's handshake on the fake bridge instead of the handshake
#      Paulinchen  2026-10-23: Set up the parties through the party's view, as the DLL keeps them
#      Paulinchen  2026-10-23: Started the stand-in battle without the deleted mirror match flag
#                            - Stood in without the deleted PvP switch
#      Paulinchen  2026-10-12: Checked an odd party_member_max and a team duel start that does not read
#                            - Read whole numbers of the stand-in wire back and gave it unreadable lines
#      Paulinchen  2026-10-11: Checked the line above the player's head through a duel's steps
#      Paulinchen  2026-10-07: Gave the live battle stand-in who
#                            - Checked that the log says why a duel's start was refused
#      Paulinchen  2026-10-06: Checked call-offs of a duel that could not start or that started
#                            - Checked that a team duel brings no share of the Backline
#      Paulinchen  2026-10-04: Followed the scripts to their new names, without mp_
#      Paulinchen  2026-10-03: Checked that a duel takes the challenger's rule of the Backline
#                            - Gave the co-op stand-in its Player record
#                            - Gave the world stand-in tell, notice and the own id and seat
#                            - Checked who may call the player to a team duel
#                            - Checked that a player who declines a challenge is no longer named by it
#      Paulinchen  2026-10-02: Gave the live battle stand-in tell
#      Paulinchen  2026-10-01: Created
#
#----------------------------------------------------------------

# Covers battles_duel.rbx's side of the DLL's duel handshake (MGQOnline.Game.Tests covers the
# handshake): the player's frame handed over, actions and messages passed on, what the DLL needs of
# a team answered, a duel it hands over started from the map, its notices shown, and the action
# wheel, the World overview and the lines above the heads read from its view.

require_relative "duel_support"

duel = MGQ_MpBattlesDuel
friend = { "id" => "friend", "name" => "Friend", "map" => 5, "x" => 4, "y" => 4, "scene" => "map" }
peer = peer_told(2, friend)

# Plays a frame as the game does: the player's frame staged before Graphics.update, the batch and
# the drain, then the scripts' tick.
def duel_frame; Graphics.update; MGQ_Multiplayer::Bridge.frame; end

# The player's frame.
duel_frame
check("the player's frame tells the DLL that they are free, with the game's fingerprint", $duels.frames.last, { "free" => true, "game" => "game-1" })
$game_message.busy = true
duel_frame
duel_frame
$game_message.busy = false
check("a message on the map makes them busy, handed once while it shows", $duels.frames.map { |frame| frame["free"] }, [true, false])
$open = false
duel_frame
$open = true
check("outside a world they are never free", $duels.frames.last, { "free" => false, "game" => "" })
peer = peer_told(2, friend)

# Actions and messages go to the DLL, which answers the view.
$backline_wanted = true
$duels.view = MGQ_MpBattlesDuel::NO_VIEW.merge("inviting" => true, "targets" => ["friend"], "invite_ends" => 3600, "doing" => ["Challenging to a duel", 3600])
duel.invite("friend")
check("a challenge names its target and the Backline", $duels.requests("duel.challenge").last, { "target" => "friend", "backline" => true })
check("and the state tells the view's challenge at once", MGQ_MpOverworldSync::Me.current.values_at("challenge", "challenge_to", "challenge_backline"), [1, ["friend"], 1])
check("which the line above the player's head names with its seconds", MGQ_MpActions.doing_text(duel.own_doing)[1] =~ /\AChallenging to a duel \(\d+ s\)\z/ ? true : false, true)
$backline_wanted = false
$duels.view = MGQ_MpBattlesDuel::NO_VIEW
duel.accept(peer)
check("accepting hands the player's team while they are free", $duels.requests("duel.accept").last, { "seat" => 2, "free" => true, "team" => ["game-1", "backline=0\nmember=me"] })
$role = :host
duel.accept(peer)
$role = nil
check("and no team while they are busy", $duels.requests("duel.accept").last, { "seat" => 2, "free" => false, "team" => nil })
message_from(2, { "duel" => "start", "bid" => "b1" }, "game-1\tteam")
check("a duel message goes to the DLL with its sender's seat", $duels.requests("duel.take").last, { "seat" => 2, "fields" => { "duel" => "start", "bid" => "b1" }, "body" => "game-1\tteam" })

# What the DLL needs of a team.
$duels.calls.clear
duel_event("duel.need_team", { "id" => 1, "theirs" => "backline=1\nmember=7\nmember=8", "own" => "pvp", "builds" => nil })
check("a team to read is counted, and the player's own team written", $duels.requests("duel.team").last,
      { "id" => 1, "count" => 2, "line" => ["game-1", "backline=0\nmember=me"], "backline" => false })
duel_event("duel.need_team", { "id" => 2, "theirs" => "backline=0\nnobody", "own" => "pvp", "builds" => nil })
check("a team that does not read gets no team written", $duels.requests("duel.team").last, { "id" => 2, "count" => 0 })
duel_event("duel.need_team", { "id" => 3, "theirs" => nil, "own" => "coop", "builds" => ["member=x", ""] })
check("a team duel's Frontlines are counted, the player's own first", $duels.requests("duel.team").last,
      { "id" => 3, "builds" => "member=a\nmember=b", "max" => 8, "own_count" => 2, "counts" => [1, 0] })

# Notices.
duel_event("duel.notice", "Friend did not answer the duel.")
check("a notice of the DLL reaches the notice box", MGQ_MpOverworldSync::Status.lines.last, "Friend did not answer the duel.")

# A duel the DLL hands over starts from the map.
duel_event("duel.need_team", { "id" => 4, "theirs" => "backline=1\nmember=7", "own" => nil, "builds" => nil })
duel_event("duel.start", { "role" => "guest", "bid" => "c1", "seat" => 2, "name" => "Friend", "team" => "backline=1\nmember=7", "backline" => true, "sides" => [], "same_side" => false })
duel.on_map
check("a duel waiting to start begins with the DLL's word, when free", $duels.requests("duel.begin").last, { "bid" => "c1", "free" => true })
check("and starts as guest of the challenger, with the members read before and the Backline",
      [$joined.last, $started.last[0, 3]], [[:guest, "c1", [2], "Friend", :pvp], ["Friend", ["member=7"], true]])
duel_event("duel.start", { "role" => "host", "bid" => "c2", "seat" => 2, "name" => "Friend", "team" => "member=9", "backline" => false, "sides" => [], "same_side" => false })
$start_fails = true
duel.on_map
$start_fails = false
check("a duel whose battle could not start is called off", [$joined.last[0, 2], $duels.requests("duel.withdraw").last], [[:host, "c2"], "c2"])
duel_event("duel.start", { "role" => "host", "bid" => "c3", "seat" => 2, "name" => "Friend", "team" => "member=9", "backline" => false, "sides" => [], "same_side" => false })
$duels.begin = false
joined = $joined.size
duel.on_map
$duels.begin = true
check("one the DLL dropped or gave up meanwhile does not start", $joined.size - joined, 0)
hosts = [[2, "Friend", "b", [], 8, [0], 4, 0]]
others = [[0, "Me", "b", [], 8, [0], 2, 0], [3, "Pal", "b", [], 8, [0], 2, 0]]
duel_event("duel.start", { "role" => "team", "bid" => "g9", "seat" => 2, "name" => "Friend", "team" => "", "backline" => false,
                           "sides" => [hosts, others], "same_side" => false })
duel.on_map
check("a team duel's guest joins its host, its sides as the player stands", [$joined.last, $prepared.map { |side| side.is_a?(Array) ? side.map(&:seat) : side }],
      [[:guest, "g9", [2], "Friend", :pvp, true], [[0, 3], [2], false]])
duel_event("duel.start", { "role" => "team", "bid" => "g10", "seat" => nil, "name" => "", "team" => "", "backline" => false,
                           "sides" => [others, hosts], "same_side" => true })
duel.on_map
check("and its host hosts every other player", [$joined.last, $started.last[0]], [[:host, "g10", [3, 2], "the duel", :pvp, true], "Side leader"])
duel_event("duel.start", { "role" => "host", "bid" => "c4", "seat" => 2, "name" => "Friend", "team" => "member=9", "backline" => false, "sides" => [], "same_side" => false })
$open = false
world_frame
$open = true
peer = peer_told(2, friend)
duel.on_map
check("a duel waiting as the world closes is forgotten", $duels.requests("duel.begin").last["bid"], "g10")

# The wheel, the World overview and the lines above the heads read the view.
$duels.view = MGQ_MpBattlesDuel::NO_VIEW.merge("challengers" => { 2 => [true, false, false] })
duel_event("duel.view", $duels.view)
check("a challenge nearby shows above the challenger and on the wheel",
      [MGQ_MpOverworldSync.label_line_of(peer).to_a[0], MGQ_MpActions.wheel_options[:RIGHT].text], ["Challenges you to a duel (B)", "Accept Friend's duel"])
MGQ_MpActions.wheel_options[:RIGHT].run.call
check("which accepts it", $duels.requests("duel.accept").last["seat"], 2)
peer.state.merge!("challenge_backline" => "1")
duel_event("duel.view", MGQ_MpBattlesDuel::NO_VIEW.merge("challengers" => { 2 => [false, true, true] }))
check("one from afar that names the player shows in the overview but not on the wheel, a team duel without Backline",
      [duel::Offers.call_of(peer).to_a[0], duel::Offers.peer_option(peer).text, MGQ_MpActions.wheel_options[:RIGHT].text],
      ["Challenges you to a duel", "Accept duel", "Challenge to a duel"])
duel_event("duel.view", MGQ_MpBattlesDuel::NO_VIEW.merge("inviting" => true, "targets" => ["friend"], "doing" => ["Waiting for Friend's duel", MGQ_Multiplayer::Bridge.frame_number + 360]))
check("the player's own challenge shows in the overview and on the wheel",
      [duel::Offers.peer_option(peer).text, MGQ_MpActions.wheel_options[:RIGHT].text, MGQ_MpActions.doing_text(duel.own_doing)[1]],
      ["Challenged to a duel", "Stop challenging", "Waiting for Friend's duel (6 s)"])
