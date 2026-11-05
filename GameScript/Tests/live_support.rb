#----------------------------------------------------------------
#  live_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Answered the live battle's topics and the battlers' plans with the values each test sets instead of a copy of the C# rules
#                            - Read and wrote lines with the codec's stand-in, took the recording's events and values and the Backline's Frontline as values and gave the stream's lines as values
#      Paulinchen  2026-10-30: Stood in for a co-op battle's side and stream kinds
#                            - Stood in for what every kind of live battle decides the same way
#                            - Stood in for the host's recording, held against its golden steps
#                            - Stood in for the command plan, a team duel's sides and the Backline's Frontlines
#                            - Stood in for the live battle's session, held against its golden cases
#                            - Created
#
#----------------------------------------------------------------

# Answers the topics of the live battle (MGQOnline.Game's LiveTopics) and of the battlers the scripts
# build (BattlerTopics) on a FakeBridge with the fixed values each test sets for its case. Unless a
# test sets an answer, the session keeps only what the scripts told it: the battle they joined, the
# messages that arrived until a script takes them, and whether a command phase is open; a send of
# the host's stream passes as its fake lines. Every rule (which message is taken, when a battle ends
# and how, the commands' and the stream's checks, a team duel's heirs, the Backline's Frontlines,
# the recording's sends) is the C# tests' to cover.

require_relative "bridge_support"
require_relative "wire_support"

# Stands in for the DLL's answers of the live battle.
class LiveAnswers
  include NotedRequests

  # The topics answered.
  TOPICS = %w(live.guest_setup live.take_stream live.swap live.join live.change live.players live.admit live.receive live.take live.pending
              live.tick live.end live.phase live.departure live.plan live.team live.backline live.record live.mode).freeze

  # What a tick that ends nothing answers besides the view.
  QUIET_TICK = { "ending" => nil, "departed" => [], "ask" => false, "logs" => [] }.freeze

  # What a step of the host's waits answers unless a test sets it.
  PHASE = { "ready" => { "all" => true, "not_ready" => [], "behind" => false }, "not_ready" => [], "host_waiting" => { "taken" => [], "seats" => [] } }.freeze

  # What a step of the recording answers unless a test sets it.
  RECORD = { "stop" => { "sends" => [], "events" => 0 }, "counts" => { "sends" => [], "events" => 0, "sends_counted" => 0 },
             "totals" => { "sends" => [], "events" => 0, "sends_counted" => 0 } }.freeze

  # What a step of the battle's kind decides unless a test sets it.
  MODE = { "same_side" => false, "players" => [], "heir" => nil, "gone" => false, "kinds" => [] }.freeze

  # @return [Hash] The session as the scripts last joined and changed it.
  attr_reader :view

  # Answers the topics on a bridge.
  #
  # @param fake [FakeBridge] The bridge.
  def initialize(fake)
    @asked = []
    @fixed = {}
    @messages = []
    @open = false
    @view = { "role" => nil, "player" => "", "kind" => "", "team" => false, "seats" => [], "left" => [], "expected" => [], "bid" => nil,
              "solo" => false, "broken" => false, "served" => false, "running" => false, "behind" => false }
    TOPICS.each { |topic| fake.answer(topic) { |request| answer(topic, request) } }
  end

  # Sets what a topic answers, for every step or for one: a value, or a block that makes it of the
  # request. A tick's answer is merged over the view and a tick that ends nothing.
  #
  # @param key [String] The topic, or the topic and its step, such as "live.phase ready" or
  #   "live.tick ending".
  # @param value [Object] The answer, nil to answer as before the test set one.
  # @yieldparam request [Object] The request.
  def set(key, value = nil, &block)
    block || !value.nil? ? @fixed[key] = (block || value) : @fixed.delete(key)
  end

  # Sets the session as a test needs it, such as a host left alone, and hands it to the scripts.
  #
  # @param fields [Hash] The fields of the view to change.
  def change_view(fields)
    @view = @view.merge(fields)
    MGQ_MpBattlesSync.take_view(@view) if defined?(MGQ_MpBattlesSync)
  end

  # Takes the oldest message of some kinds that arrived, as a script's take does.
  #
  # @param kinds [Array<String>] The kinds.
  # @param seat [Integer, nil] The sender, nil for any.
  # @return [Array, nil] The kind, the body and the sender, nil for none.
  def taken(kinds, seat = nil)
    index = @messages.index { |kind, _body, from| kinds.include?(kind) && (seat.nil? || from == seat) }
    index && @messages.delete_at(index)
  end

  # Answers a topic: what the test set, else what a session that keeps only what it was told
  # answers. A test that answers a topic otherwise for a while hands it back here.
  #
  # @param topic [String] The topic.
  # @param request [Object] The request.
  # @return [Object] The reply.
  def answer(topic, request)
    note(topic, request)
    step = request.is_a?(Hash) ? request["op"] || request["check"] || request["of"] : nil
    fixed = @fixed.key?("#{topic} #{step}") ? @fixed["#{topic} #{step}"] : @fixed[topic]
    fixed = fixed.call(request) if fixed.respond_to?(:call)
    case topic
    when "live.join", "live.change", "live.players", "live.team", "live.backline" then told(topic, request, step).merge(fixed || {})
    when "live.tick" then step == "frame" ? fixed || { "sends" => [] } : @view.merge(QUIET_TICK).merge(fixed || {})
    else fixed.nil? ? told(topic, request, step) : fixed
    end
  end

  private

  # Answers a topic as a session that keeps only what it was told.
  #
  # @param topic [String] The topic.
  # @param request [Object] The request.
  # @param step [String, nil] The request's step.
  # @return [Object] The reply.
  def told(topic, request, step)
    case topic
    when "live.join" then join(request)
    when "live.change" then change(step)
    when "live.players" then players(request)
    when "live.receive" then receive(request)
    when "live.take" then { "message" => (message = taken(request["kinds"], request["seat"])) && message[0, 2], "behind" => false }
    when "live.pending" then @messages.count { |kind, _body, _seat| kind == request }
    when "live.phase" then phase(step, request)
    when "live.take_stream" then stream(request["body"])
    when "live.guest_setup" then []
    when "live.swap" then request
    when "live.admit" then false
    when "live.departure" then true
    when "live.team" then { "heirs" => [], "post" => nil, "broken" => false, "gone" => false }
    when "live.backline" then { "front" => nil, "unfit" => nil }
    when "live.record" then RECORD.fetch(step, { "sends" => [] })
    when "live.mode" then MODE[step]
    end
  end

  # Joins the next battle as the scripts ask.
  #
  # @param request [Hash] The battle.
  # @return [Hash] The view.
  def join(request)
    @messages.clear
    @open = false
    @view = @view.merge(request.select { |key, _| %w(role player kind team seats bid served).include?(key) })
                 .merge("left" => [], "expected" => [], "solo" => false, "broken" => false, "running" => false)
  end

  # Changes the session as the scripts ask.
  #
  # @param op [String] "start", "finish", "break" or "gone".
  # @return [Hash] The view, with "done" and "logs".
  def change(op)
    done =
      case op
      when "start" then @view["running"] = !@view["role"].nil?
      when "finish"
        finished = !@view["role"].nil?
        @view = @view.merge("role" => nil, "team" => false, "broken" => false, "running" => false, "served" => false)
        @open = false
        finished
      when "break" then !@view["broken"] && (@view["broken"] = true)
      else true
      end
    @view.merge("done" => done, "logs" => [])
  end

  # Changes the battle's players as the scripts ask.
  #
  # @param request [Hash] "op" with "seats" or "seat".
  # @return [Hash] The view, with "dropped", "left_now" and "still_in".
  def players(request)
    dropped = nil
    left_now = false
    case request["op"]
    when "expect" then @view["expected"] |= request["seats"]
    when "unexpect" then @view["expected"] -= request["seats"]
    when "keep"
      dropped = @view["seats"] - request["seats"]
      @view["seats"] = request["seats"].dup
    when "left" then left_now = !@view["left"].include?(request["seat"]) && (@view["left"] += [request["seat"]])
    end
    @view.merge("dropped" => dropped, "left_now" => left_now ? true : false, "still_in" => (@view["seats"] - @view["left"]).size)
  end

  # Keeps a message that arrived until a script takes it.
  #
  # @param request [Hash] "seat", "kind" and "body".
  # @return [Hash] "logs" and "behind".
  def receive(request)
    @messages << [request["kind"], request["body"], request["seat"]]
    { "logs" => [], "behind" => false }
  end

  # Answers a step of the host's waits: a command phase opens and closes once, every guest still in
  # owes their commands, and everyone else is as PHASE says.
  #
  # @param op [String] The step.
  # @param request [Hash] The request.
  # @return [Object] The answer.
  def phase(op, request)
    case op
    when "open", "close"
      was = @open
      @open = op == "open"
      op == "open" ? !was : was
    when "unanswered" then @view["seats"] - @view["left"]
    when "tell" then request["seats"].sort.join(",")
    else PHASE[op]
    end
  end

  # Gives a send of the host's stream as its lines, each a fake line, unchecked.
  #
  # @param body [String] The send: the lines, a line break between two.
  # @return [Hash] "lines", "events", "unreadable", "others_choose" and "logs".
  def stream(body)
    lines = body.to_s.split("\n").map { |line| FakeLines.parse(line) }
    { "lines" => lines.compact, "events" => lines.compact.size, "unreadable" => lines.count(&:nil?), "others_choose" => 0, "logs" => [] }
  end
end

# Answers the plans of the battlers the scripts build with the values each test sets.
class BattlerAnswers
  include NotedRequests

  # What a plan answers unless a test sets it: the battler built with its start, as it comes.
  PLAN = { "hp" => nil, "mp" => nil, "start" => true, "hide" => false, "lay_down" => false }.freeze

  # @return [Hash{String => Hash, Proc}] What battlers.plan answers by the battler's kind, merged
  #   over PLAN, or a block that makes it of the request.
  attr_reader :plans

  # Answers the topic on a bridge.
  #
  # @param fake [FakeBridge] The bridge.
  def initialize(fake)
    @asked = []
    @plans = {}
    fake.answer("battlers.plan") do |request|
      note("battlers.plan", request)
      plan = @plans[request["kind"]]
      PLAN.merge((plan.respond_to?(:call) ? plan.call(request) : plan) || {})
    end
  end
end

# Answers the live battle's topics, kept in $live.
#
# @param fake [FakeBridge] The test's bridge.
# @return [LiveAnswers] The answers.
def answer_live(fake)
  $live = LiveAnswers.new(fake)
end

# Answers the plans of the battlers, kept in $battlers.
#
# @param fake [FakeBridge] The test's bridge.
# @return [BattlerAnswers] The answers.
def answer_battlers(fake)
  $battlers = BattlerAnswers.new(fake)
end
