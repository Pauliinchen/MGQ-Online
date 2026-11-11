#----------------------------------------------------------------
#  coop_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-11: Answered the limit of a wait for the roster, a late guest's as the DLL sets it
#      Paulinchen  2026-11-05: Answered the co-op topics with the values each test sets instead of a copy of the C# rules
#                            - Handed a co-op message's fields as the test writes them instead of through a copy of the DLL's codec
#                            - Wrote and read the roster's lines as fake lines and checked the stand-in's level alone against its golden cases, the lines' cases being C#'s
#                            - Took the joins from the messages the live battle's fixed answers keep
#                            - Handed a message no stand-in took to the scripts with its fields read by their kinds
#                            - Wrote and read the roster's lines with the codec's stand-in
#                            - Told the battle's players in rbn whether or not it takes players in, as JoinIntake.Told does
#                            - Told whether the running battle takes players in or why not as JoinIntake.Told does
#      Paulinchen  2026-10-30: Stood in for the widths of a served battle's troop the battle server keeps
#                            - Stood in for the joins the live session holds
#                            - Stood in for asking a running battle and joining one by choice
#                            - Handed co-op messages over as the DLL's routes do
#                            - Stood in for the matchmaking over the tests' world
#                            - Stood in for the widths a request tells, kept for its battle
#                            - Stood in for the battle's level, the roster's lines, the troop's repair and the departures
#                            - Created
#
#----------------------------------------------------------------

# Answers the topics of the co-op battles (MGQOnline.Game's Coop folder behind CoopTopics, and the
# matchmaking, asking and joining sides behind CoopRoomTopics) on a FakeBridge with the fixed values
# each test sets for its case, and hands the scripts the DLL's co-op events. Unless a test sets an
# answer, the DLL has nothing to say: no step to take, a quiet status, nobody joined, no roster yet. The
# roster's, the party's and the troop's lines are fake lines (wire_support.rb), read back as they
# were written. Every rule (whom a battle invites and when, the waits, the intake, the places, the
# level, the repair, the joins) is the C# tests' to cover.

require_relative "bridge_support"
require_relative "wire_support"

# Stands in for the DLL's answers of the co-op battles.
class CoopAnswers
  include NotedRequests

  # The topics answered.
  TOPICS = %w(coop.offer coop.host coop.poll coop.frame coop.release coop.steps coop.freeze_party coop.raid_candidates coop.take_off coop.leader_wait
              coop.leader_end coop.yield coop.decline_waiting coop.refuse_lead coop.clear coop.drop coop.ask_off coop.gather coop.roster_wait
              coop.ask coop.ask_wait coop.ask_party_wait coop.ask_party_end coop.ask_end coop.ask_release coop.ask_undo coop.ask_abandon coop.ask_forget
              coop.party_offers coop.accept_party coop.decline_party coop.join_frame coop.pending coop.place coop.write_widths coop.keep_widths
              coop.read_entries coop.write_entries coop.intake coop.room coop.level coop.write_roster coop.write_party coop.read_roster coop.read_party
              coop.read_troop coop.repair coop.settle).freeze

  # The topics that answer the matchmaking's status with the steps to take.
  STATUS_TOPICS = %w(coop.offer coop.host coop.poll coop.release coop.yield coop.decline_waiting coop.clear coop.drop coop.take_off coop.ask
                     coop.ask_undo coop.ask_abandon coop.ask_forget coop.accept_party coop.decline_party).freeze

  # The status of a matchmaking with nothing going on.
  QUIET = { "holding" => false, "frozen" => false, "busy" => false, "waiting" => nil, "rival" => false, "asking" => false, "requested" => false,
            "waits" => nil, "ask" => false, "ask_party" => false, "join_waits" => false }.freeze

  # The frames the wait for the roster of a player who joins a running battle lasts, as the DLL sets
  # them unless a test sets other.
  LATE_ROSTER_FRAMES = 4500

  # What a frame of the join prompt answers besides the status unless a test sets it.
  PROMPT = { "target" => nil, "side" => nil, "freeze" => nil, "busy_reason" => nil, "asked" => false, "not_taken" => nil }.freeze

  # What a topic, or a topic's step, answers unless a test sets it.
  DEFAULTS = { "coop.leader_wait" => "silent", "coop.ask_wait" => "silent", "coop.ask_party_wait" => "done", "coop.ask_off" => false,
               "coop.raid_candidates" => [], "coop.party_offers" => [], "coop.place" => [], "coop.read_entries" => [], "coop.write_widths" => "",
               "coop.write_entries" => "", "coop.room" => { "rbn" => 0, "rbs" => "open" }, "coop.level" => { "level" => nil, "log" => "no level" },
               "coop.gather frame" => true, "coop.gather end" => { "joined" => [], "outcomes" => [], "frames" => 0 },
               "coop.roster_wait frame" => { "roster" => nil, "late" => false, "frames" => 1 },
               "coop.pending release" => [], "coop.pending expire" => [], "coop.pending joins" => [], "coop.pending take_off" => false,
               "coop.pending call_off" => [], "coop.pending queued" => [], "coop.pending count" => 0, "coop.pending seats" => [] }.freeze

  # Answers the topics on a bridge.
  #
  # @param fake [FakeBridge] The bridge.
  def initialize(fake)
    @fake = fake
    @asked = []
    @fixed = {}
    TOPICS.each { |topic| fake.answer(topic) { |request| answer(topic, request) } }
  end

  # Sets what a topic answers, for every step or for one: a value, or a block that makes it of the
  # request. A status topic's answer is merged over the status and no step.
  #
  # @param key [String] The topic, or the topic and its step, such as "coop.gather end".
  # @param value [Object] The answer, nil to answer as before the test set one.
  # @yieldparam request [Object] The request.
  def set(key, value = nil, &block)
    block || !value.nil? ? @fixed[key] = (block || value) : @fixed.delete(key)
  end

  # Has the DLL's matchmaking host every battle the game sets up as one battle, or no longer.
  #
  # @param bid [String, nil] The battle's id, nil to answer as before the test set one.
  # @param seats [Array<Integer>] The seats it invites.
  # @param label [String] Whom the waits name.
  def hosts(bid, seats = [], label = "the party")
    set("coop.offer", bid && { "actions" => [coop_step("join", "role" => "host", "bid" => bid, "seats" => seats, "label" => label)] })
  end

  # Has the host's gathering end with the joins the DLL took, each player's outcome "joined".
  #
  # @param joined [Array<Array>] Each player's seat and join, none for a gathering nobody joined.
  def gathered(*joined)
    set("coop.gather end", "joined" => joined, "outcomes" => joined.map { |seat, body| [seat, "joined (#{body.to_s.size} bytes)"] }, "frames" => 3)
  end

  # Has a guest's wait for the roster take a roster at its first frame, or run late there.
  #
  # @param line [String, nil, false] The roster, false to run late, nil to answer as before the test
  #   set one.
  def roster(line)
    set("coop.roster_wait frame", line.nil? ? nil : { "roster" => line || nil, "late" => line == false, "frames" => 1 })
  end

  # Hands the scripts the matchmaking's status as the DLL's coop.status event does once a co-op
  # message changed it; the topics answer a quiet status unless a test sets otherwise.
  #
  # @param fields [Hash] The status' fields that are not quiet, none for a quiet status.
  def status(fields = {})
    @fake.post("coop.status", QUIET.merge(fields))
    MGQ_Multiplayer::Bridge.frame
  end

  # Hands the scripts a co-op message the DLL's routes leave to them, as the coop.message event does.
  #
  # @param peer [Object] Who sent it.
  # @param fields [Hash] The message's fields as the DLL reads them, its kind under "coop".
  def message(peer, fields)
    @fake.post("coop.message", "seat" => peer.seat, "fields" => fields)
    MGQ_Multiplayer::Bridge.frame
  end

  # Answers a topic: what the test set, else what a DLL with nothing to say answers.
  #
  # @param topic [String] The topic.
  # @param request [Object] The request.
  # @return [Object] The reply.
  def answer(topic, request)
    note(topic, request)
    step = request.is_a?(Hash) ? request["op"] : nil
    key = @fixed.key?("#{topic} #{step}") ? "#{topic} #{step}" : topic
    fixed = @fixed[key]
    fixed = fixed.call(request) if fixed.respond_to?(:call)
    return QUIET.merge("actions" => []).merge(fixed || {}) if STATUS_TOPICS.include?(topic)
    return QUIET.merge(PROMPT).merge(fixed || {}) if topic == "coop.join_frame"
    return fixed if @fixed.key?(key)

    quiet(topic, request, step)
  end

  private

  # Answers a topic as a DLL with nothing to say: the lines written and read as fake lines, the rest
  # by DEFAULTS.
  #
  # @param topic [String] The topic.
  # @param request [Object] The request.
  # @param step [String, nil] The request's step.
  # @return [Object] The reply.
  def quiet(topic, request, step)
    case topic
    when "coop.steps" then request["steps"]
    when "coop.intake" then { "refusal" => nil, "kept" => [request["seat"]], "left" => [], "room" => 1 }
    when "coop.write_roster" then FakeLines.line(request.values_at(*%w(enemies players level turn).select { |key| request.key?(key) }))
    when "coop.write_party" then FakeLines.line([request])
    when "coop.read_roster" then read_roster(request["line"])
    when "coop.read_party" then { "players" => Array(Array(FakeLines.parse(request.to_s))[0]), "dropped" => [] }
    when "coop.read_troop" then read_troop(request["line"])
    when "coop.repair" then { "enemies" => request["enemies"], "enemy_dropped" => [], "lacking" => [] }
    when "coop.settle" then { "staying" => request["players"], "left" => [], "outcome" => "none" }
    when "coop.roster_wait" then step == "start" ? request["limit"] || LATE_ROSTER_FRAMES : DEFAULTS["coop.roster_wait frame"]
    else DEFAULTS.fetch(step ? "#{topic} #{step}" : topic, DEFAULTS[topic])
    end
  end

  # Reads a roster's fake line back as it was written, nothing dropped or lacking.
  #
  # @param line [String] The line.
  # @return [Hash] The roster.
  def read_roster(line)
    enemies, players, level, turn = Array(FakeLines.parse(line.to_s))
    { "players" => Array(players), "dropped" => [], "enemies" => enemies, "enemy_dropped" => [], "lacking" => [], "size" => Array(enemies).size,
      "level" => level, "turn" => turn }
  end

  # Reads a troop's fake line back as it was written, nothing dropped or lacking.
  #
  # @param line [String] The line.
  # @return [Hash] The troop.
  def read_troop(line)
    enemies, names = Array(FakeLines.parse(line.to_s))
    { "enemies" => enemies, "enemy_dropped" => [], "lacking" => [], "names" => names }
  end
end

# Makes a step the matchmaking asks the scripts to take, as its answers carry it.
#
# @param kind [String] What, such as "join" or "accept".
# @param fields [Hash] Its other fields; "fields" holds an invite or request as the DLL reads it.
# @return [Hash] The step.
def coop_step(kind, fields = {})
  step = { "kind" => kind, "role" => nil, "bid" => nil, "seats" => nil, "label" => nil, "seat" => nil, "troop" => nil, "escape" => false, "lose" => false,
           "fields" => nil }.merge(fields)
  step
end

# Answers the co-op topics with the values each test sets, kept in $coop.
#
# @param fake [FakeBridge] The test's bridge.
# @return [CoopAnswers] The answers.
def answer_coop(fake)
  $coop = CoopAnswers.new(fake)
end
