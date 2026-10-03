#----------------------------------------------------------------
#  duel_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-03: Checked that a call to a team duel is taken only from the challenger the player accepted or through their party's leader
#                            - Checked that a player who declines a challenge is no longer named by it
#      Paulinchen  2026-10-02: Gave the live battle stand-in tell
#      Paulinchen  2026-10-01: Created
#
#----------------------------------------------------------------

# Covers duels, mp_battles_duel.rbx with the action wheel: challenging nearby and from afar,
# accepting, the start on both sides, and why a duel does not start. The PvP battle itself and the
# live battle stand in, see battles_coop_test.rb and team_test.rb for those. Covers the gathering of
# a team duel on the map too.

require_relative "world_support"

# Stand-ins for the PvP battles and the live battle.
module MGQ_Multiplayer
  def self.available?; true; end
  def self.outdated?; false; end
end
module MGQ_MpBattles; def self.running?; false; end; end
module MGQ_MpBattlesPvp
  ENABLED = true
  module Team
    def self.game; $game_print; end
    def self.build; "team-me"; end
    def self.parse(text); text.to_s.empty? ? [] : [text]; end
  end
  module Battle
    def self.running?; false; end
    def self.start(name, members, mirror); $started << [name, members, mirror, block_given? ? yield : nil]; end
  end
end
module MGQ_MpBattlesSync
  # Plain values travel as tab-separated text, nested ones as hex of Marshal, so both can be read.
  module Wire
    def self.line(values); values.all? { |v| v.is_a?(String) || v.is_a?(Numeric) } ? values.join("\t") : "M:" + Marshal.dump(values).unpack1("H*"); end
    def self.parse(text); text.start_with?("M:") ? Marshal.load([text[2..-1]].pack("H*")) : text.split("\t"); end
  end
  def self.role; $role; end
  def self.join_world(*args); $joined << args; end
  def self.tell(seat, kind, battle_id, body = ""); MGQ_MpOverworldSync::Link.send_to(seat, "battle=#{kind}\nbid=#{battle_id}\n\n#{body}"); end
end
module MGQ_MpBattlesCoop
  def self.own_seat; 0; end
  def self.team_build; ["builds-me", 8]; end
  def self.arrange(players); players; end
end
module MGQ_MpBattlesTeam
  def self.prepare(*args); $prepared = args; end
  def self.opponent_name; "Side leader"; end
  def self.opponents; [:opponents]; end
end
$game_print = "game-1"
$started = []
$joined = []

load_script "mp_battles_duel"

duel = MGQ_MpBattlesDuel
# Reads the duel messages this game sent.
#
# @return [Array<Array>] Each one's seat and fields, its body under :payload.
def duel_sent
  $sent.map { |seat, text| [seat, MGQ_Multiplayer::Link.parse(text)] }.select { |_, fields| fields["duel"] }
end
# Lets the map run a frame: the wheel's keys, the chat's, and a duel waiting to start.
def frame; map_frame; MGQ_MpBattlesDuel.on_map; end

friend = { "id" => "friend", "name" => "Friend", "sprite" => "Actor2", "index" => 0, "map" => 5, "x" => 4, "y" => 4, "d" => 2, "speed" => 4, "hidden" => 0, "scene" => "map" }
$inbox << entry("seat", 0) << entry("in", 2) << entry("message", 2, told(friend))
MGQ_MpOverworldSync.tick
peer = MGQ_MpOverworldSync::Peers.at(2)

# Challenging.
check("someone near: challenge on the wheel's right", [MGQ_MpActions.wheel_options[:RIGHT].text, !MGQ_MpActions.wheel_options[:RIGHT].run.nil?], ["Challenge to a duel", true])
check("the state never names a field duel, which marks duel messages", MGQ_MpOverworldSync::Me.current.keys.include?("duel"), false)
duel.invite
check("a challenge is told", [MGQ_MpOverworldSync::Me.current["challenge"], MGQ_MpActions.own_line], [1, "Challenging to a duel . . ."])
check("it can be stopped", MGQ_MpActions.wheel_options[:RIGHT].text, "Stop challenging")
(MGQ_MpCoop::INVITE_FRAMES + 1).times { duel.tick(true) }
check("it runs out", duel.inviting?, false)

# Accepting a challenge nearby.
$inbox << entry("message", 2, told(friend.merge("challenge" => 1)))
MGQ_MpOverworldSync.tick
check("the challenge shows above the challenger", MGQ_MpOverworldSync.label_line_of(peer).to_a[0], "Challenges you to a duel (B)")
check("the wheel accepts it", MGQ_MpActions.wheel_options[:RIGHT].text, "Accept Friend's duel")
$sent.clear
MGQ_MpActions.wheel_options[:RIGHT].run.call
accept = duel_sent.last
check("accepting sends the player's game and team to the challenger", [accept[0], accept[1]["duel"], accept[1][:payload]], [2, "accept", "game-1\tteam-me"])
$inbox << entry("message", 2, "duel=start\nbid=b1\n\ngame-1\tteam-friend")
MGQ_MpOverworldSync.tick
frame
check("the challenger's answer starts the duel as guest", [$joined.last, $started.last], [[:guest, "b1", [2], "Friend", :pvp], ["Friend", ["team-friend"], false, nil]])

# Challenged from afar, through the World overview.
$inbox << entry("message", 2, told(friend.merge("x" => 40, "challenge" => 1, "challenge_to" => "someone")))
MGQ_MpOverworldSync.tick
check("a challenge naming someone else does not reach the player from afar", duel.challenged_by?(peer), false)
$inbox << entry("message", 2, told(friend.merge("x" => 40, "challenge" => 1, "challenge_to" => "someone,me")))
MGQ_MpOverworldSync.tick
check("one naming the player does, though not on the wheel", [duel.challenged_by?(peer), duel.challenged_by?(peer, false)], [true, false])

# Hosting a duel someone accepted.
$inbox << entry("message", 2, told(friend))
MGQ_MpOverworldSync.tick
duel.invite("friend")
check("a challenge names its target", MGQ_MpOverworldSync::Me.current["challenge_to"], "friend")
$inbox << entry("message", 2, "duel=decline\nreason=no\n\n")
MGQ_MpOverworldSync.tick
check("a player who declines is no longer named, and the challenger hears it",
      [duel.targets, MGQ_MpOverworldSync::Status.lines.last], [[], "Friend declined your challenge."])
duel.invite("friend")
$sent.clear
$inbox << entry("message", 2, "duel=accept\n\ngame-1\tteam-friend")
MGQ_MpOverworldSync.tick
start = duel_sent.last
check("the challenger answers with its own team and a battle id", [start[0], start[1]["duel"], start[1][:payload], start[1]["bid"].to_s.empty?], [2, "start", "game-1\tteam-me", false])
check("and stops challenging", duel.inviting?, false)
frame
check("then hosts the duel", [$joined.last[0], $joined.last[2, 3], $started.last[1]], [:host, [[2], "Friend", :pvp], ["team-friend"]])

# Why a duel does not start.
$sent.clear
$inbox << entry("message", 2, "duel=accept\n\ngame-1\tteam-friend")
MGQ_MpOverworldSync.tick
check("an accept without a challenge is declined", duel_sent.last[1].values_at("duel", "reason"), ["decline", "gone"])
duel.invite
$game_print = "game-2"
$sent.clear
$inbox << entry("message", 2, "duel=accept\n\ngame-1\tteam-friend")
MGQ_MpOverworldSync.tick
check("another version of the game is declined", duel_sent.last[1].values_at("duel", "reason"), ["decline", "data"])
$game_print = "game-1"
$inbox << entry("message", 2, "duel=decline\nreason=busy\n\n")
MGQ_MpOverworldSync.tick
check("a decline tells why", MGQ_MpOverworldSync::Status.lines.last, "Friend is busy.")
$role = :host
$inbox << entry("message", 2, told(friend.merge("challenge" => 1)))
MGQ_MpOverworldSync.tick
MGQ_MpActions.wheel_options[:RIGHT].run.call
check("a player in another battle cannot accept", MGQ_MpOverworldSync::Status.lines.last, "Finish what you are doing first.")
$role = nil
duel.accept(peer)
(MGQ_MpBattlesDuel::ANSWER_FRAMES + 1).times { duel.tick(true) }
check("an unanswered accept runs out", MGQ_MpOverworldSync::Status.lines.last, "Friend did not answer the duel.")
duel.invite
$open = false
MGQ_MpOverworldSync.tick
check("closing the world forgets the challenge", duel.inviting?, false)

# Team duels: the player leads a party, so a duel calls both sides.
$open = true
MGQ_MpOverworldSync.tick
$inbox << entry("seat", 0) << entry("in", 2) << entry("message", 2, told(friend)) << entry("in", 3)
pal = { "id" => "pal", "name" => "Pal", "map" => 5, "x" => 30, "y" => 30, "d" => 2, "scene" => "map" }
$inbox << entry("message", 3, told(pal))
MGQ_MpOverworldSync.tick
MGQ_MpCoop::Party.invite("pal")
$inbox << entry("message", 3, told(pal.merge("party" => MGQ_MpCoop::Party.id)))
MGQ_MpOverworldSync.tick
check("the player leads a party of two", MGQ_MpCoop.leads?(:me), true)
duel.invite
$sent.clear
$inbox << entry("message", 2, "duel=accept\n\ngame-1\tteam-friend")
MGQ_MpOverworldSync.tick
calls = duel_sent.select { |_, f| f["duel"] == "team" }
bid = calls.first[1]["bid"]
check("an accepted duel of a party's leader calls both sides", calls.map(&:first).sort, [2, 3])
$inbox << entry("message", 3, "duel=ready\nbid=#{bid}\n\ngame-1\tbuilds-pal\t8")
MGQ_MpOverworldSync.tick
check("it waits while a player is not ready", duel_sent.select { |_, f| f["duel"] == "start" }, [])
$inbox << entry("message", 2, "duel=ready\nbid=#{bid}\n\ngame-1\tbuilds-friend\t8")
MGQ_MpOverworldSync.tick
starts = duel_sent.select { |_, f| f["duel"] == "start" }
own, other = MGQ_MpBattlesSync::Wire.parse(starts.first[1][:payload])
check("once all are ready, everyone hears both sides", [starts.map(&:first).sort, starts.map { |_, f| f["team"] }.uniq, own.map(&:first), other.map(&:first)],
      [[2, 3], ["1"], [0, 3], [2]])
frame
check("then the host starts the team duel", [$joined.last, $prepared[2], $started.last.values_at(0, 3)], [[:host, bid, [3, 2], "the duel", :pvp, true], true, ["Side leader", [:opponents]]])

# A player not ready in ten seconds is left out.
duel.invite
$sent.clear
$inbox << entry("message", 2, "duel=accept\n\ngame-1\tteam-friend")
MGQ_MpOverworldSync.tick
bid = duel_sent.find { |_, f| f["duel"] == "team" }[1]["bid"]
$inbox << entry("message", 2, "duel=ready\nbid=#{bid}\n\ngame-1\tbuilds-friend\t8")
MGQ_MpOverworldSync.tick
(MGQ_MpBattlesDuel::READY_FRAMES + 1).times { duel.tick(true) }
check("after ten seconds it starts with those ready, and tells the others", duel_sent.select { |_, f| %w(start cancel).include?(f["duel"]) }.map { |seat, f| [seat, f["duel"], f["reason"]] },
      [[2, "start", nil], [3, "cancel", "late"]])
frame

# Nobody of the other side ready calls it off.
duel.invite
$sent.clear
$inbox << entry("message", 2, "duel=accept\n\ngame-1\tteam-friend")
MGQ_MpOverworldSync.tick
(MGQ_MpBattlesDuel::READY_FRAMES + 1).times { duel.tick(true) }
check("without the other side it is off", [duel_sent.map { |_, f| f["reason"] }.compact.uniq, MGQ_MpOverworldSync::Status.lines.last], [["off"], "Nobody of Friend's side was ready, the duel is off."])

# The player who accepted leads a party: they tell whom they called of it, who then count too.
mate = { "id" => "mate", "name" => "Mate", "map" => 5, "x" => 31, "y" => 31, "d" => 2, "scene" => "map", "party" => "friend-p" }
$inbox << entry("in", 4) << entry("message", 4, told(mate)) << entry("message", 2, told(friend.merge("party" => "friend-p")))
MGQ_MpOverworldSync.tick
duel.invite
$sent.clear
$inbox << entry("message", 2, "duel=accept\n\ngame-1\tteam-friend")
MGQ_MpOverworldSync.tick
calls = duel_sent.select { |_, f| f["duel"] == "team" }
bid = calls.first[1]["bid"]
check("the challenger calls its own party and the player who accepted, not their party", calls.map(&:first).sort, [2, 3])
$inbox << entry("message", 4, "duel=ready\nbid=#{bid}\n\ngame-1\tbuilds-mate\t8")
$inbox << entry("message", 2, "duel=side\nbid=#{bid}\nseats=4,9\n\n")
$inbox << entry("message", 2, "duel=ready\nbid=#{bid}\n\ngame-1\tbuilds-friend\t8") << entry("message", 3, "duel=ready\nbid=#{bid}\n\ngame-1\tbuilds-pal\t8")
MGQ_MpOverworldSync.tick
starts = duel_sent.select { |_, f| f["duel"] == "start" }
own, other = MGQ_MpBattlesSync::Wire.parse(starts.first[1][:payload])
check("whom the other side's leader called joins their side, even when ready before being named",
      [starts.map(&:first).sort, own.map(&:first).sort, other.map(&:first).sort], [[2, 3, 4], [0, 3], [2, 4]])
frame
$inbox << entry("message", 2, told(friend))
MGQ_MpOverworldSync.tick

# Called to a team duel as one of its players: only by the challenger the player accepted.
$sent.clear
$inbox << entry("message", 2, "duel=team\nbid=g8\n\n")
MGQ_MpOverworldSync.tick
check("a call from a player whose challenge the player did not accept is not answered", duel_sent, [])
$inbox << entry("message", 2, told(friend.merge("challenge" => 1)))
MGQ_MpOverworldSync.tick
duel.accept(MGQ_MpOverworldSync::Peers.at(2))
$sent.clear
$inbox << entry("message", 2, "duel=team\nbid=g9\n\n")
MGQ_MpOverworldSync.tick
ready = duel_sent.find { |_, f| f["duel"] == "ready" }
check("a player called answers once free, with their Frontline", [ready[0], ready[1]["bid"], ready[1][:payload]], [2, "g9", "game-1\tbuilds-me\t8"])
side = duel_sent.find { |_, f| f["duel"] == "side" }
check("as their party's leader, the player passes the call on and tells the challenger whom",
      [$sent.select { |_, text| text.include?("duel_call=g9") }.map { |seat, text| [seat, text.include?("seat=2")] }, side[0], side[1].values_at("bid", "seats")],
      [[[3, true]], 2, ["g9", "3"]])
hosts = [[2, "Friend", "b", [], 8, [0, 1, 2, 3], 4, 0]]
others = [[0, "Me", "b", [], 8, [0, 1, 2, 3], 2, 0], [3, "Pal", "b", [], 8, [0, 1, 2, 3], 2, 0]]
$inbox << entry("message", 2, "duel=start\nbid=g9\nteam=1\n\n" + MGQ_MpBattlesSync::Wire.line([hosts, others]))
MGQ_MpOverworldSync.tick
frame
check("then joins the challenger's duel on the other side", [$joined.last, $prepared.map { |side| side.is_a?(Array) ? side.map(&:first) : side }],
      [[:guest, "g9", [2], "Friend", :pvp, true], [[0, 3], [2], false]])
duel.accept(MGQ_MpOverworldSync::Peers.at(2))
$sent.clear
$inbox << entry("message", 2, "duel=team\nbid=g10\n\n")
$game_message.busy = true
MGQ_MpOverworldSync.tick
$inbox << entry("message", 2, "duel=start\nbid=g10\nteam=1\n\n" + MGQ_MpBattlesSync::Wire.line([hosts, others]))
MGQ_MpOverworldSync.tick
check("a player busy since leaves at once, so their side takes their characters", $sent.map(&:last).grep(/battle=leave/).size, 1)
$game_message.busy = false

# A duel the challenger already started is called off, never left waiting.
# Lists the seats this game broke a live battle off with.
#
# @return [Array<Integer>] The seats.
def broken_to; $sent.select { |_, text| text =~ /\Abattle=broken/ }.map(&:first); end
challenger = MGQ_MpOverworldSync::Peers.at(2)
$sent.clear
$inbox << entry("message", 2, "duel=start\nbid=s1\n\ngame-1\tteam-friend")
MGQ_MpOverworldSync.tick
check("a start nobody accepted calls the challenger's battle off", [broken_to, duel_sent.last[1].values_at("duel", "bid", "reason")], [[2], ["cancel", "s1", "busy"]])
duel.accept(challenger)
$sent.clear
$inbox << entry("message", 2, "duel=start\nbid=s2\n\ngame-1\t")
MGQ_MpOverworldSync.tick
check("an unreadable team is declined and the battle called off", [duel_sent.map { |_, f| f["duel"] }, broken_to], [["decline", "cancel"], [2]])
duel.accept(challenger)
$inbox << entry("message", 2, "duel=start\nbid=s3\n\ngame-1\tteam-friend")
MGQ_MpOverworldSync.tick
$sent.clear
joined = $joined.size
$game_message.busy = true
frame
$game_message.busy = false
check("an event before the start calls the duel off instead", [$joined.size - joined, broken_to, MGQ_MpOverworldSync::Status.lines.last], [0, [2], "The duel could not start."])
duel.accept(challenger)
$inbox << entry("message", 2, "duel=start\nbid=s4\n\ngame-1\tteam-friend") << entry("message", 2, "duel=cancel\nbid=s4\nreason=off\n\n")
MGQ_MpOverworldSync.tick
joined = $joined.size
frame
check("a call-off before the start drops the duel", [$joined.size - joined, MGQ_MpOverworldSync::Status.lines.last], [0, "Friend called the duel off."])

# A party's member is called through their leader, never by the challenger alone.
MGQ_MpCoop::Party.reset
lead = MGQ_MpOverworldSync::Peers.at(2)
lead.state.merge!("party" => "friend", "invite" => "1")
MGQ_MpCoop::Party.join(lead)
$sent.clear
$inbox << entry("message", 3, "duel=team\nbid=g20\n\n")
MGQ_MpOverworldSync.tick
check("a member does not answer a challenger their leader did not accept", duel_sent, [])
$inbox << entry("message", 3, "duel_call=g21\nparty=friend\nseat=2\n\n")
MGQ_MpOverworldSync.tick
check("nor a call another player passes on", duel_sent, [])
$inbox << entry("message", 2, "duel_call=g22\nparty=friend\nseat=3\n\n")
MGQ_MpOverworldSync.tick
ready = duel_sent.find { |_, f| f["duel"] == "ready" }
check("a call the leader passes on is answered to the challenger", [ready[0], ready[1]["bid"]], [3, "g22"])
