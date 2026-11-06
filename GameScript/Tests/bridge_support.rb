#----------------------------------------------------------------
#  bridge_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Reached the Mod Framework's engine under its own name
#                            - Left out sending the wheels defined by name, which the Mod Framework no longer has
#                            - Stood in for UI.confirm as for the old question box
#      Paulinchen  2026-11-06: Failed a test file whose scripts handed a topic a value that cannot cross the bridge
#      Paulinchen  2026-11-05: Kept the requests the fixed answers of a test took, for every test to share
#      Paulinchen  2026-11-01: Stood in for every wheel the Mod Framework defines and handed the framework's wheels their frames
#                            - Stood in for the Mod Framework's component tree
#                            - Placed the tree's nodes and told the focus back as focus and blur
#                            - Queued the states of the tree's nodes for a test
#                            - Told a component's node as the tree holds it
#      Paulinchen  2026-10-31: Opened the Mod Framework's bridge on the same FakeBridge, its interface events drained there, and stood in for its question box
#      Paulinchen  2026-10-23: Stood in for the layout
#                            - Stood in for the confirm box
#                            - Stood in for the wheels
#                            - Stood in for the tick and the text box of the interface
#                            - Left loading the bridge to support.rb
#                            - Created
#
#----------------------------------------------------------------

# The bridge to C# for the script tests: FakeBridge, a stand-in for the DLL's side that answers
# topics with Ruby lambdas, for MGQ_Multiplayer::Bridge, which support.rb loads. Every request and
# reply crosses through Marshal and the plain-value check of the core's strict reader, so a test
# fails where the game would refuse a value.

require "json"
require_relative "support"

# Folder of the bridge's contract fixtures, which the C# tests read too.
BRIDGE_FIXTURES = File.expand_path("../../fixtures/bridge", __dir__)

# Stands in for the in-game log unless the test file brings its own; logged_lines collects it.
module MGQ_Multiplayer; module Log; def self.write(_line); end; end; end unless defined?(MGQ_Multiplayer::Log)

# Reads a contract fixture that fixtures/bridge/make_topic_fixtures.rb wrote.
#
# @param name [String] The topic's folder and case, such as "batch/in_order".
# @param part [String] "request" or "reply".
# @return [String] The dump's bytes, empty for no reply.
def bridge_fixture(name, part)
  File.binread(File.join(BRIDGE_FIXTURES, "#{name}.#{part}.marshal"))
end

# A script that hands a topic a value the core refuses only logs it in the game, so the file fails
# here instead; this runs before support.rb's summary, as at_exit blocks run last first.
at_exit { check("every request a script handed a topic could cross the bridge", FakeBridge.refused, []) }

# Keeps the requests a stand-in of the DLL's answers took.
module NotedRequests
  # Lists the requests of a topic since the answers were last cleared.
  #
  # @param topic [String] The topic.
  # @return [Array<Object>] The requests, oldest first.
  def asked(topic)
    @asked.select { |name, _request| name == topic }.map { |_name, request| request }
  end

  private

  # Keeps a request.
  #
  # @param topic [String] The topic.
  # @param request [Object] The request.
  # @return [Boolean] True.
  def note(topic, request)
    @asked << [topic, request]
    true
  end
end

# The DLL's side of the bridge as a backend of MGQ_Multiplayer::Bridge: the four exports, answering
# topics with the Ruby blocks a test registers and keeping what the scripts sent.
class FakeBridge
  # What a handler raises for a request that misses what its topic needs, as BridgeRequestException.
  class BadRequest < StandardError; end

  # The encodings a String may cross in.
  PLAIN_ENCODINGS = [Encoding::UTF_8, Encoding::US_ASCII, Encoding::ASCII_8BIT]

  # How the core names a plain value that is no String or Integer, as a refused Hash key.
  KEY_KINDS = { Array => "An Array", Hash => "A Hash", NilClass => "Nil", TrueClass => "True", FalseClass => "False" }

  # The deepest nesting the core reads.
  MAX_DEPTH = 256

  # Every request a script handed a topic that the core refused as no plain value, each as
  # "topic: refusal", which fails the test file at its end.
  @refused = []

  class << self
    # @return [Array<String>] The refused requests, see @refused; a test that hands one on purpose
    #   clears it.
    attr_reader :refused
  end

  # @return [Array<Array>] Each mp_call as [topic, request bytes].
  attr_reader :calls

  # @return [Array<Integer>] The frame of each mp_drain.
  attr_reader :frames

  # @return [Array<Integer>] The buffer size of each mp_call and mp_reply.
  attr_reader :sizes

  # @return [Integer, nil] The context the Mod Framework's bridge opened, which stays open beside
  #   the newest one and whose drain takes the events of the interface (topics starting "ui."); nil
  #   hands every event to whichever drains.
  attr_accessor :ui_context

  # Creates the stand-in with no topic but the batch.
  #
  # @param version [Integer] The bridge version it speaks.
  def initialize(version = MGQ_Multiplayer::Bridge::VERSION)
    @version = version
    @handlers = {}
    @raw = {}
    @events = []
    @parked = {}
    @calls = []
    @frames = []
    @sizes = []
    @context = 0
  end

  # Tells why a value cannot cross the bridge, as the core's strict reader does.
  #
  # @param value [Object] The value.
  # @param depth [Integer] Its nesting.
  # @return [String, nil] The refusal, nil for a plain value.
  def self.refusal(value, depth = 0)
    return "The value nests too deep to cross the bridge." if depth > MAX_DEPTH

    case value
    when nil, true, false, Integer then nil
    when String then text_refusal(value)
    when Array then list_refusal(value, depth)
    when Hash then hash_refusal(value, depth)
    when Symbol then "The Symbol :#{value} cannot cross the bridge."
    when Float then "The Float #{value} cannot cross the bridge."
    else "#{value.class} cannot cross the bridge."
    end
  end

  # Tells why a String cannot cross the bridge.
  #
  # @param text [String] The string.
  # @return [String, nil] The refusal, nil for one that can.
  def self.text_refusal(text)
    return "A String in #{text.encoding} cannot cross the bridge." unless PLAIN_ENCODINGS.include?(text.encoding)

    text.valid_encoding? ? nil : "A String marked #{text.encoding} with bytes outside it cannot cross the bridge."
  end

  # Tells why an Array cannot cross the bridge.
  #
  # @param list [Array] The Array.
  # @param depth [Integer] Its nesting.
  # @return [String, nil] The refusal, nil for one that can.
  def self.list_refusal(list, depth)
    list.each do |item|
      found = refusal(item, depth + 1)
      return found if found
    end
    nil
  end

  # Tells why a Hash cannot cross the bridge.
  #
  # @param hash [Hash] The Hash.
  # @param depth [Integer] Its nesting.
  # @return [String, nil] The refusal, nil for one that can.
  def self.hash_refusal(hash, depth)
    return "A Hash with a default value cannot cross the bridge." unless hash.default.nil? && hash.default_proc.nil?

    hash.each do |key, item|
      found = refusal(key, depth + 1)
      return found if found
      return "#{KEY_KINDS[key.class]} as a Hash key cannot cross the bridge." unless key.is_a?(String) || key.is_a?(Integer)

      found = refusal(item, depth + 1)
      return found if found
    end
    nil
  end

  # Answers a topic with a block, which gets the request and returns the value; nil answers nothing.
  #
  # @param topic [String] The topic.
  # @yieldparam request [Object] The request as it crossed.
  def answer(topic, &handler)
    @handlers[topic] = handler
  end

  # Answers a topic with bytes as they are, such as a contract fixture's reply.
  #
  # @param topic [String] The topic.
  # @param bytes [String] The reply, Marshal.
  def answer_bytes(topic, bytes)
    @raw[topic] = bytes
  end

  # Queues an event for the next drain.
  #
  # @param topic [String] The event's topic.
  # @param payload [Object] A plain value.
  def post(topic, payload)
    @events << [topic, payload]
  end

  # mp_bridge_open.
  #
  # @param version [Integer] The scripts' version.
  # @param reply [String] The reply buffer.
  # @param size [Integer] Its size.
  # @return [Integer] As the export.
  def open(version, reply, size)
    return take(:open, reply, size) if @parked[:open]

    answer =
      if version == @version
        ok("bridge" => @version, "build" => "test", "context" => (@context += 1), "topics" => [MGQ_Multiplayer::Bridge::BATCH] + @handlers.keys)
      else
        error("bad_request", "The scripts speak bridge version #{version}, the core version #{@version}.")
      end
    hand(:open, Marshal.dump(answer), reply, size)
  end

  # mp_call.
  #
  # @param context [Integer] The context.
  # @param topic [String] The topic, null-terminated.
  # @param request [String] The request.
  # @param length [Integer] Its length.
  # @param reply [String] The reply buffer.
  # @param size [Integer] Its size.
  # @return [Integer] As the export.
  def call(context, topic, request, length, reply, size)
    name = topic.chomp("\0")
    bytes = request[0, length]
    @calls << [name, bytes]
    @sizes << size
    return hand(:call, @raw[name], reply, size) if @raw.key?(name)

    envelope = context == @context || context == @ui_context ? envelope_of(name, bytes) : error("bad_request", "There is no bridge context #{context}.")
    envelope.nil? ? 0 : hand(:call, Marshal.dump(envelope), reply, size)
  end

  # mp_reply.
  #
  # @param _context [Integer] The context.
  # @param reply [String] The reply buffer.
  # @param size [Integer] Its size.
  # @return [Integer] As the export.
  def reply(_context, reply, size)
    @sizes << size
    take(:call, reply, size)
  end

  # mp_drain.
  #
  # @param context [Integer] The context.
  # @param frame [Integer] The scripts' frame.
  # @param buffer [String] The drain buffer.
  # @param size [Integer] Its size.
  # @return [Integer] As the export.
  def drain(context, frame, buffer, size)
    @frames << frame
    return take(:drain, buffer, size) if @parked[:drain]

    events, @events = @ui_context ? @events.partition { |topic, _| topic.start_with?("ui.") == (context == @ui_context) } : [@events, []]
    return 0 if events.empty?

    hand(:drain, Marshal.dump(events), buffer, size)
  end

  private

  # Answers a call as the core's dispatcher does.
  #
  # @param topic [String] The topic.
  # @param bytes [String] The request's bytes.
  # @return [Hash, nil] The envelope, nil for no reply.
  def envelope_of(topic, bytes)
    return error("unknown_topic", "There is no topic #{topic}.") unless topic == MGQ_Multiplayer::Bridge::BATCH || @handlers.key?(topic)

    request =
      begin
        bytes.empty? ? nil : Marshal.load(bytes)
      rescue ArgumentError => e
        return error("bad_request", "#{e.message} cannot cross the bridge.")
      end
    refused = FakeBridge.refusal(request)
    if refused
      FakeBridge.refused << "#{topic}: #{refused}"
      return error("bad_request", refused)
    end

    run(topic, request)
  end

  # Runs a topic's block on a request that crossed.
  #
  # @param topic [String] The topic.
  # @param request [Object] The request.
  # @return [Hash, nil] The envelope, nil for no reply.
  def run(topic, request)
    return error("unknown_topic", "There is no topic #{topic}.") unless topic == MGQ_Multiplayer::Bridge::BATCH || @handlers.key?(topic)

    value = topic == MGQ_Multiplayer::Bridge::BATCH ? run_batch(request) : @handlers[topic].call(request)
    return nil if value.nil?

    refused = FakeBridge.refusal(value)
    refused ? error("internal", "The reply cannot cross: #{refused}") : ok(value)
  rescue BadRequest => e
    error("bad_request", e.message)
  rescue => e
    error("internal", e.message)
  end

  # Runs a batch's entries in order, after checking every one, as the core's batch topic does.
  #
  # @param request [Object] The batch.
  # @return [Array<Hash>, nil] The failed entries, nil when every one ran.
  def run_batch(request)
    raise BadRequest, "Expected an Array, found #{request.class}." unless request.is_a?(Array)

    request.each do |pair|
      raise BadRequest, "Batch entry #{pair.inspect} is no [topic, payload] pair." unless pair.is_a?(Array) && pair.size == 2 && pair[0].is_a?(String)
      raise BadRequest, "A batch cannot hold a batch." if pair[0] == MGQ_Multiplayer::Bridge::BATCH
    end
    failed = request.map do |topic, payload|
      answer = run(topic, payload)
      answer && !answer["ok"] ? { "topic" => topic, "error" => answer["error"], "text" => answer["text"] } : nil
    end.compact
    failed.empty? ? nil : failed
  end

  # Writes bytes into the scripts' buffer, or parks them when they do not fit.
  #
  # @param slot [Symbol] What parks them: :open, :call or :drain.
  # @param bytes [String] The bytes.
  # @param buffer [String] The buffer.
  # @param size [Integer] Its size.
  # @return [Integer] Their length, or it negated when they were parked.
  def hand(slot, bytes, buffer, size)
    if bytes.bytesize > size
      @parked[slot] = bytes
      return -bytes.bytesize
    end
    buffer[0, bytes.bytesize] = bytes
    bytes.bytesize
  end

  # Writes parked bytes into the scripts' buffer once it is large enough.
  #
  # @param slot [Symbol] What parked them.
  # @param buffer [String] The buffer.
  # @param size [Integer] Its size.
  # @return [Integer] Their length, 0 when none are parked, or it negated when they still do not fit.
  def take(slot, buffer, size)
    bytes = @parked[slot]
    return 0 unless bytes
    return -bytes.bytesize if bytes.bytesize > size

    @parked.delete(slot)
    buffer[0, bytes.bytesize] = bytes
    bytes.bytesize
  end

  # Makes the reply of a topic that answered.
  #
  # @param value [Object] The value.
  # @return [Hash] The envelope.
  def ok(value)
    { "ok" => true, "value" => value }
  end

  # Makes the reply of a request that failed.
  #
  # @param code [String] The error code.
  # @param text [String] What went wrong.
  # @return [Hash] The envelope.
  def error(code, text)
    { "ok" => false, "error" => code, "text" => text }
  end
end

# The frame's tick on a FakeBridge: each model's input handed to the fake model of its name.
class FakeUi
  # @return [Array<Hash>] Every tick the scripts sent, in order.
  attr_reader :ticks

  # Answers the tick on a fake bridge.
  #
  # @param fake [FakeBridge] The bridge.
  def initialize(fake)
    @models = {}
    @ticks = []
    fake.answer(Mod_Framework::UI::Engine::Tick::TOPIC) do |inputs|
      @ticks << inputs
      inputs.each { |name, input| @models[name].call(input) if @models[name] }
      nil
    end
  end

  # Takes a model's input with a block.
  #
  # @param name [String] The model's name in the tick.
  # @yieldparam input [Object] Its input.
  def model(name, &block)
    @models[name] = block
  end
end

# The text box being typed into on a FakeBridge, as far as the owners' tests need it: what the
# test types goes in at the cursor, typing stops at Enter and Escape until the next tick, Backspace
# removes, the most characters and the allowed pattern refuse, a locked box takes only Escape, the
# chat's filters leave out the opening key's character and what Alt types, and left, right, Home,
# End and Delete move or remove. The rest of EditModel (the part shown, the lines, the blinking)
# is MGQOnline.Game.Tests', so a box here shows no view and always its cursor.
class FakeEdit
  # The key bits, see Mod_Framework::UI::Engine::TextEdit::ARROW_BITS and KEY_BITS.
  LEFT, RIGHT, HOME, END_KEY, DELETE = 1, 2, 16, 32, 64

  # Answers the box's topics and takes its input from the tick.
  #
  # @param fake [FakeBridge] The bridge.
  # @param ui [FakeUi] The tick.
  # @yieldreturn [Array(String, Integer)] What was typed since the last take, and the keys pressed.
  def initialize(fake, ui, &typed)
    @fake = fake
    @typed = typed
    @boxes = {}
    @last = 0
    fake.answer(Mod_Framework::UI::Engine::TextEdit::OPEN) { |request| open(request) }
    fake.answer(Mod_Framework::UI::Engine::TextEdit::CLOSE) { |id| @boxes.delete(id); nil }
    fake.answer(Mod_Framework::UI::Engine::TextEdit::SET) { |request| set(request); nil }
    fake.answer(Mod_Framework::UI::Engine::TextEdit::VIEW) { |request| (@box = @boxes[request["id"]]) ? state : nil }
    fake.answer(Mod_Framework::UI::Engine::TextEdit::TYPE) { |request| type_now(request) }
    ui.model(Mod_Framework::UI::Engine::TextEdit::MODEL) { |input| tick(input) }
  end

  # The open boxes by id; a test may keep several windows of boxes, where the game opens one at a
  # time.
  #
  # @return [Hash{Integer => Hash}] Each box's :id, :text, :cursor, :max, :allowed, :locked and :pending.
  attr_reader :boxes

  private

  # Opens a box.
  #
  # @param request [Hash] The box.
  # @return [Integer] Its id.
  def open(request)
    allowed = request["allowed"] && Regexp.new(request["allowed"][0], request["allowed"][1] ? Regexp::IGNORECASE : nil)
    box = { :id => (@last += 1), :text => request["text"], :cursor => request["text"].size, :max => request["max_chars"],
             :allowed => allowed, :locked => request["locked"] == true, :pending => "", :echo => request["echo"],
             :alt_codes => request["alt_codes"].to_i, :alt_left => 0 }
    @boxes[box[:id]] = box
    box[:id]
  end

  # Changes the open box.
  #
  # @param request [Hash] The change.
  def set(request)
    return unless (@box = @boxes[request["id"]])

    @box[:text], @box[:cursor] = request["text"], request["cursor"] if request.key?("text")
    @box[:locked] = request["locked"] if request.key?("locked")
    @box[:echo] = request["echo"] if request.key?("echo")
  end

  # Types characters at once.
  #
  # @param request [Hash] The characters.
  # @return [Hash, nil] What typing did and the text.
  def type_now(request)
    return nil unless (@box = @boxes[request["id"]])

    outcomes = request["text"].each_char.map { |char| type(char) }.compact
    { "outcomes" => outcomes, "text" => @box[:text], "cursor" => @box[:cursor] }
  end

  # Takes a tick's input: what was typed, then the keys.
  #
  # @param input [Array] [id, keys or -1, take typed, scroll, Alt].
  def tick(input)
    return unless (@box = @boxes[input[0]])

    text, keys = input[2] == 1 ? @typed.call : ["", 0]
    @box[:pending] += filtered(text.to_s, input[4] == 1) if input[2] == 1
    outcomes = []
    until @box[:pending].empty?
      char = @box[:pending][0, 1]
      @box[:pending] = @box[:pending][1..-1]
      next if @box[:locked] && char != "\e"

      outcome = type(char)
      outcomes << outcome if outcome
      break if outcome == "enter" || outcome == "escape"
    end
    before = [@box[:text], @box[:cursor]]
    follow(input[1]) if input[1] >= 0
    return if outcomes.empty? && keys.to_i == 0 && text.to_s.empty? && before == [@box[:text], @box[:cursor]]

    @fake.post(Mod_Framework::UI::Engine::TextEdit::EVENT, state.merge("outcomes" => outcomes, "keys" => keys.to_i, "chars" => text.to_s.size))
  end

  # Leaves out the character of the key that opened the box once, and what is typed while Alt is
  # held and just after, as EditModel does.
  #
  # @param text [String] What was typed.
  # @param alt [Boolean] Whether the left Alt is held.
  # @return [String] What the box types.
  def filtered(text, alt)
    box = @box
    if (echo = box[:echo])
      echo = box[:echo] = [echo[0], echo[1] - 1]
      box[:echo] = nil if echo[1] <= 0 || !text.empty?
      text = text[1..-1] if !text.empty? && text[0, 1].upcase.ord == echo[0]
    end
    return text if box[:alt_codes] == 0

    box[:alt_left] = alt ? box[:alt_codes] : [box[:alt_left] - 1, 0].max
    box[:alt_left] > 0 ? "" : text
  end

  # Types one character, as TextEditor.Type does.
  #
  # @param char [String] The character.
  # @return [String, nil] What it did.
  def type(char)
    box = @box
    case char
    when "\r" then "enter"
    when "\e" then "escape"
    when "\t" then "tab"
    when "\b"
      return nil if box[:cursor] == 0

      box[:text] = box[:text][0, box[:cursor] - 1] + box[:text][box[:cursor]..-1]
      box[:cursor] -= 1
      "erased"
    else
      return nil if char =~ /[[:cntrl:]]/
      return "refused" if (box[:max] && box[:text].size >= box[:max]) || (box[:allowed] && char !~ box[:allowed])

      box[:text] = box[:text][0, box[:cursor]] + char + box[:text][box[:cursor]..-1]
      box[:cursor] += 1
      "typed"
    end
  end

  # Follows the keys that type nothing.
  #
  # @param keys [Integer] The bits.
  def follow(keys)
    box = @box
    box[:cursor] = [box[:cursor] - 1, 0].max if keys & LEFT != 0
    box[:cursor] = [box[:cursor] + 1, box[:text].size].min if keys & RIGHT != 0
    box[:cursor] = 0 if keys & HOME != 0
    box[:cursor] = box[:text].size if keys & END_KEY != 0
    box[:text] = box[:text][0, box[:cursor]] + box[:text][box[:cursor] + 1..-1].to_s if keys & DELETE != 0 && box[:cursor] < box[:text].size
  end

  # Describes the open box as its event does, without a view.
  #
  # @return [Hash] Its id, text, cursor and the cursor shown.
  def state
    { "id" => @box[:id], "text" => @box[:text], "cursor" => @box[:cursor], "shown" => true, "view" => nil }
  end
end

# C#'s component tree on a FakeBridge, as far as the screens' tests need it: the components the
# scripts add, set and remove, by node, a place for each (a root at its place and size, each child
# a row under the one before), the focus the scripts ask for told back as focus and blur, and the
# events a test hands them, which reach them in the next frame as C#'s report. The layout, the
# keys and the drawing are the Mod Framework's tests'.
class FakeTree
  # The height of the rows a child takes under the one before.
  ROW = 24

  # @return [Hash{Integer => Hash}] Each node: :parent, :kind, :props and :children.
  attr_reader :nodes

  # @return [Integer, nil] The node that has the focus, nil for none.
  attr_reader :focused

  # Answers the tree's layout and takes its changes from the tick, and has the framework hand the
  # tree its changes and the text fields their keys every frame, as its start does in the game.
  #
  # @param fake [FakeBridge] The bridge.
  # @param ui [FakeUi] The tick.
  def initialize(fake, ui)
    @fake = fake
    @nodes = {}
    @told = {}
    @pending = {}
    @focused = nil
    tree = Mod_Framework::UI::Engine::Tree
    ui.model(tree::MODEL) { |changes| apply(changes); send_report }
    fake.answer(tree::LAYOUT) { |changes| apply(changes); report }
    fake.answer(tree::RESET) { |_request| reset; nil }
    return if $tree_collecting

    $tree_collecting = true
    Mod_Framework::UI::Engine::Tick.collect("Mod Framework components") { Mod_Framework::UI::Engine::Tree.collect }
    Mod_Framework::UI::Engine::Tick.collect("Mod Framework text fields") { Mod_Framework::UI::Engine::TextField.follow }
  end

  # Hands a component an event of C#'s tree in the next frame, such as "close" or "submit".
  #
  # @param component [Mod_Framework::UI::Component] The component.
  # @param name [String] The event.
  # @param values [Array] Its values.
  def tell(component, name, *values)
    post([[component.node, name] + values])
  end

  # Queues events for the next report, as the player's keys and clicks make them.
  #
  # @param events [Array<Array>] The events, each [node, name, values...].
  def post(events)
    (@pending["events"] ||= []).concat(events)
  end

  # Tells whether a component is in the tree.
  #
  # @param component [Mod_Framework::UI::Component] The component.
  # @return [Boolean] Whether it is.
  def holds?(component)
    !component.node.nil? && @nodes.key?(component.node)
  end

  # Queues the states of nodes for the next report, as C# tells them when they change.
  #
  # @param states [Hash{Integer => Integer}] The states by node, such as Mod_Framework::UI::Engine::Tree::FOCUSED.
  def post_states(states)
    (@pending["states"] ||= {}).update(states)
  end

  # Tells a component's node as the tree holds it.
  #
  # @param component [Mod_Framework::UI::Component] The component.
  # @return [Hash, nil] Its :parent, :kind, :props and :children; nil while it is not in the tree.
  def node_of(component)
    @nodes[component.node]
  end

  private

  # Takes the scripts' changes, as Change does in C#, and tells the focus they ask for.
  #
  # @param changes [Hash] The changes, see Mod_Framework::UI::Engine::Tree.changes.
  def apply(changes)
    Array(changes["add"]).each { |node, parent, kind, index, props| add(node, parent, kind, index, props || {}) }
    Array(changes["set"]).each { |node, props| @nodes[node][:props].update(props) if @nodes[node] }
    Array(changes["remove"]).each { |node| remove(node) }
    move_focus(changes["focus"]) if changes["focus"]
    move_focus(nil) if changes["blur"] && changes["blur"] == @focused
  end

  # Forgets every node, as the tree's reset does in C#.
  def reset
    @nodes.clear
    @told.clear
    @focused = nil
  end

  # Adds a node, leaving out one whose parent is gone, as C# does.
  #
  # @param node [Integer] The node.
  # @param parent [Integer, nil] Its parent, nil for a root.
  # @param kind [String] Its kind.
  # @param index [Integer, nil] Its place among its siblings, nil for the last.
  # @param props [Hash] Its properties.
  def add(node, parent, kind, index, props)
    return if parent && !@nodes[parent]

    @nodes[node] = { :parent => parent, :kind => kind, :props => props, :children => [] }
    return unless parent

    siblings = @nodes[parent][:children]
    index ? siblings.insert([index, siblings.size].min, node) : siblings << node
  end

  # Removes a node with every node it holds.
  #
  # @param node [Integer] The node.
  def remove(node)
    entry = @nodes.delete(node)
    return unless entry

    @told.delete(node)
    move_focus(nil) if @focused == node
    @nodes[entry[:parent]][:children].delete(node) if entry[:parent] && @nodes[entry[:parent]]
    entry[:children].each { |child| remove(child) }
  end

  # Moves the focus, telling the node that lost it and the one that took it.
  #
  # @param node [Integer, nil] The node that takes it, nil for none.
  def move_focus(node)
    return if node == @focused

    post([[@focused, "blur"]]) if @focused && @nodes[@focused]
    @focused = node
    post([[node, "focus"]]) if node
  end

  # Builds what changed since the last report: the places of the nodes that are new or moved, and
  # the events queued.
  #
  # @return [Hash] The report, see Mod_Framework::UI::Engine::Tree.take.
  def report
    report = @pending
    @pending = {}
    rects = {}
    @nodes.each_key do |node|
      rect = rect_of(node)
      rects[node] = rect unless @told[node] == rect
      @told[node] = rect
    end
    report["rects"] = rects unless rects.empty?
    report
  end

  # Posts the report, unless nothing changed, as the tree's event in the next frame.
  def send_report
    report = self.report
    @fake.post(Mod_Framework::UI::Engine::Tree::EVENT, report) unless report.empty?
  end

  # Tells a node's place.
  #
  # @param node [Integer] The node.
  # @return [Array(Integer, Integer, Integer, Integer)] Its x, y, width and height.
  def rect_of(node)
    entry = @nodes[node]
    props = entry[:props]
    unless entry[:parent]
      at = props["at"] || [0, 0]
      size = props["size"] || [nil, nil]
      return [at[0] || 0, at[1] || 0, size[0] || 200, size[1] || 100]
    end

    parent = rect_of(entry[:parent])
    place = @nodes[entry[:parent]][:children].index(node)
    [parent[0], parent[1] + ROW * place, parent[2], ROW]
  end
end

# Opens the bridges, MGQ Online's and the Mod Framework's, to the test's one FakeBridge,
# $world_bridge, made here unless the world room's or the rules' stand-ins made it, adding the
# frame's tick, the text box, typing what a block hands out, the wheels, the layout, the
# framework's settings in $framework_ini, a stand-in for its question box and its component tree
# in $fake_tree.
#
# @yieldreturn [Array(String, Integer)] What was typed since the last take, and the keys pressed.
# @return [Array(FakeBridge, FakeUi, FakeEdit)] The bridge, the tick and the box.
def open_fake_ui(&typed)
  fake = ($world_bridge ||= FakeBridge.new)
  ui = FakeUi.new(fake)
  edit = FakeEdit.new(fake, ui, &typed)
  FakeWheels.new(fake, ui)
  FakeLayout.new(fake)
  $fake_tree = FakeTree.new(fake, ui)
  answer_framework_ini(fake)
  StandInConfirm.install
  open_framework(fake)
  MGQ_Multiplayer::Bridge.open(fake)
  reregister_boxes
  Mod_Framework::UI::Engine::Tick.collect("Mod Framework wheels") { Mod_Framework::UI::Engine::Wheel.collect } unless Mod_Framework::Run.started?
  [fake, ui, edit]
end

# Answers the Mod Framework's settings file on a FakeBridge from $framework_ini, as the DLL reads
# and writes Patch/Mod_Framework/Mod_Framework.ini, unless the test answers them itself.
#
# @param fake [FakeBridge] The bridge.
def answer_framework_ini(fake)
  $framework_ini ||= {}
  fake.answer("ini.read") { |(_path)| $framework_ini.dup } unless fake.instance_variable_get(:@handlers).key?("ini.read")
  fake.answer("ini.write") { |(_path, values)| $framework_ini = values.dup; true } unless fake.instance_variable_get(:@handlers).key?("ini.write")
end

# Registers the boxes the scripts registered while the bridge was still closed once more, as the
# game, whose bridge opens before the scripts load, has them registered in C#.
def reregister_boxes
  $layout_registrations.dup.each { |id, (name, options)| Mod_Framework::UI::Engine::Layout.register(id, name, options) }
end

# Ends a frame as Graphics.update and the next Input.update do in the game: the frame ends, the
# frame's tick goes over in the batch, and the drains hand back the models' events, which their
# owners act on in the next frame. Counts the frames in $ui_frames.
def ui_frame
  Mod_Framework::UI::Engine::Tick.end_frame
  Mod_Framework::UI::Engine::Tick.send_frame
  $ui_frames = $ui_frames.to_i + 1
  MGQ_Multiplayer::Bridge.frame
end

# The wheels on a FakeBridge, as far as their owners' tests need them: a wheel opens as it asks and
# closes on its key, as cancel does and a map that no longer leaves it free, the arrows
# held point at once, without the grace of a diagonal, at the direction with a choice, else the
# action wheel's middle or the emote wheel's last pick, and confirm takes the pick, closing the
# emote wheel. The places are those of the Mod Framework's wheel fixtures; the grace and the rest of
# WheelModel are the framework's tests'.
class FakeWheels
  # The directions, clockwise from the top, as Mod_Framework::UI::Engine::Wheel::DIRECTIONS names them.
  DIRECTIONS = %w[UP UP_RIGHT RIGHT DOWN_RIGHT DOWN DOWN_LEFT LEFT UP_LEFT]

  # The places of each count of choices, by the count, as WheelPlaces spreads them.
  PLACES = { 1 => %w[UP], 2 => %w[UP DOWN], 3 => %w[UP DOWN_RIGHT DOWN_LEFT], 4 => %w[UP RIGHT DOWN LEFT], 5 => %w[UP RIGHT DOWN_RIGHT DOWN_LEFT LEFT],
             6 => %w[UP UP_RIGHT DOWN_RIGHT DOWN DOWN_LEFT UP_LEFT], 7 => %w[UP UP_RIGHT RIGHT DOWN_RIGHT DOWN_LEFT LEFT UP_LEFT], 8 => DIRECTIONS }

  # The directions, by the row and the column the arrows point to.
  STEPS = { [-1, 0] => 0, [-1, 1] => 1, [0, 1] => 2, [1, 1] => 3, [1, 0] => 4, [1, -1] => 5, [0, -1] => 6, [-1, -1] => 7 }

  # Answers the wheels' topics and takes their input from the tick.
  #
  # @param fake [FakeBridge] The bridge.
  # @param ui [FakeUi] The tick.
  def initialize(fake, ui)
    @fake = fake
    @ui = ui
    @wheels = {}
    wheel = Mod_Framework::UI::Engine::Wheel
    fake.answer(wheel::DEFINE) { |request| define(*request) }
    fake.answer(wheel::PLACES) { |request| places(request[0]).map { |name| DIRECTIONS.index(name) } }
    fake.answer(wheel::CLOSE) { |request| (@wheels[request[0]] || {})[:open] = false; nil }
    @directions = DIRECTIONS
  end

  private

  # Defines a wheel and takes its frames from the tick.
  #
  # @param name [String] The wheel.
  # @param center [Boolean] Whether it has a middle choice.
  # @param closes [Boolean] Whether confirm closes it, else its owner closes it.
  # @return [Boolean] true.
  def define(name, center, closes)
    @wheels[name] = { :center => center, :closes => closes }
    @ui.model(name) { |input| tick(name, input) }
    true
  end

  # Places a count of choices.
  #
  # @param count [Integer] The count.
  # @return [Array<String>] The directions' names.
  def places(count)
    PLACES[count] || []
  end

  # Takes a wheel's frame.
  #
  # @param name [String] The wheel.
  # @param input [Array] [free, key, cancel, confirm, arrows, count, ring].
  def tick(name, input)
    wheel = @wheels[name]
    free, key, cancel, confirm, arrows, count = input
    unless free == true
      return unless wheel[:open]

      wheel[:open] = false
      return post(name, wheel, "reason" => free)
    end

    unless wheel[:open]
      return unless key

      wheel[:open] = true
      wheel[:selected] = wheel[:center] ? Mod_Framework::UI::Engine::Wheel::CENTER : nil
      return post(name, wheel, "cues" => ["cursor"])
    end
    if key || cancel
      wheel[:open] = false
      return post(name, wheel, "reason" => key ? "its key" : "cancel", "cues" => ["cancel"])
    end

    row = (arrows & 2 != 0 ? 1 : 0) - (arrows & 1 != 0 ? 1 : 0)
    column = (arrows & 8 != 0 ? 1 : 0) - (arrows & 4 != 0 ? 1 : 0)
    held = STEPS[[row, column]]
    pointed = wheel[:selected]
    pointed = places(count).include?(@directions[held]) ? held : wheel[:center] ? Mod_Framework::UI::Engine::Wheel::CENTER : wheel[:selected] if held
    moved = pointed != wheel[:selected]
    wheel[:selected] = pointed
    return post(name, wheel, "cues" => moved ? ["cursor"] : []) if moved && !confirm
    return unless confirm

    wheel[:open] = false if wheel[:closes]
    post(name, wheel, "take" => wheel[:selected], "cues" => wheel[:closes] && wheel[:selected].nil? ? ["cancel"] : [])
  end

  # Posts a wheel's event.
  #
  # @param name [String] The wheel.
  # @param wheel [Hash] Its state.
  # @param fields [Hash] What the event adds.
  def post(name, wheel, fields)
    @fake.post(Mod_Framework::UI::Engine::Wheel::EVENT, { "wheel" => name, "open" => wheel[:open] == true, "selected" => wheel[:selected], "cues" => [] }.merge(fields))
  end
end

# The Mod Framework's question box, as far as its askers' tests need it, asked by UI.confirm or the
# old Confirm.ask: one question at a time, kept in $asked, whose block answer_confirm calls; the box
# itself is the framework's tests'.
module StandInConfirm
  # Stands in for the question box from now on.
  def self.install
    confirm = Mod_Framework::UI::Engine::Confirm
    confirm.define_singleton_method(:ask) do |question, choices = ["Yes", "No"], _options = {}, &answer|
      next false if @block

      ($asked ||= []) << [question, choices]
      @question, @yes, @no = question, choices[0], choices[1]
      @block = answer
      true
    end
    confirm.define_singleton_method(:open?) { !@block.nil? }
    confirm.define_singleton_method(:close) { |_reason = nil| StandInConfirm.answer(false) }
    Mod_Framework::UI.define_singleton_method(:confirm) do |question, params = {}, &answer|
      confirm.ask(question, [params[:yes] || "Yes", params[:no] || "No"], &answer) ? Handle.new : false
    end
  end

  # What UI.confirm hands back: whether the question still waits, and its close from outside.
  class Handle
    # Tells whether the question still waits.
    #
    # @return [Boolean] Whether it does.
    def open?
      Mod_Framework::UI::Engine::Confirm.open?
    end

    # Answers it no from outside.
    #
    # @param _reason [String, nil] Why.
    def close(_reason = nil)
      StandInConfirm.answer(false)
    end
  end

  # Answers the open question, if one is open, as the player does.
  #
  # @param yes [Boolean] The answer.
  def self.answer(yes)
    confirm = Mod_Framework::UI::Engine::Confirm
    block = confirm.instance_variable_get(:@block)
    return unless block

    confirm.instance_variable_set(:@block, nil)
    block.call(yes)
  end
end

# Answers the question box's open question, see StandInConfirm.
#
# @param yes [Boolean] The answer.
def answer_confirm(yes)
  StandInConfirm.answer(yes)
end

# The layout on a FakeBridge, as far as the boxes' tests need it: a box lies where Player.ini keeps
# it, else at its default, fitted to its least size and the screen as LayoutModel fits it. The drags
# and the double click are MGQOnline.Game.Tests'.
class FakeLayout
  # Answers the layout's topics.
  #
  # @param fake [FakeBridge] The bridge.
  def initialize(fake)
    @boxes = {}
    @stored = {}
    layout = Mod_Framework::UI::Engine::Layout
    fake.answer(layout::REGISTER) do |request|
      id, _name, width, height, _max_width, _max_height, resize, _movable, text = request
      @boxes[id] = [width, height, resize]
      !(@stored[id] = parse(text)).nil?
    end
    fake.answer(layout::RECT) do |request|
      id, x, y, width, height, screen_width, screen_height, text = request
      @stored[id] = parse(text) unless text == false
      fit(id, [x, y, width, height], screen_width, screen_height) + [!@stored[id].nil?]
    end
    fake.answer(layout::RESET) { |request| @stored[request[0]] = nil; nil }
  end

  private

  # Reads a place the framework's settings keep.
  #
  # @param text [String, nil] "x,y,width,height".
  # @return [Array<Integer>, nil] The place, nil for none.
  def parse(text)
    numbers = text.to_s.split(",").map { |part| part.strip }
    numbers.size == 4 && numbers.all? { |part| part =~ /\A-?\d+\z/ } ? numbers.map { |part| part.to_i } : nil
  end

  # Fits a box's place to its least size and the screen.
  #
  # @param id [String] The box.
  # @param default [Array<Integer>] Where it starts.
  # @param screen_width [Integer] The screen's width.
  # @param screen_height [Integer] The screen's height.
  # @return [Array<Integer>] The place.
  def fit(id, default, screen_width, screen_height)
    min_width, min_height, resize = @boxes[id] || [0, 0, "both"]
    x, y, width, height = @stored[id] || default
    width = resize == "none" ? default[2] : width
    height = resize == "both" ? height : default[3]
    width = [[width, min_width].max, screen_width].min
    height = [[height, min_height].max, screen_height].min
    [[[x, 0].max, screen_width - width].min, [[y, 0].max, screen_height - height].min, width, height]
  end
end
