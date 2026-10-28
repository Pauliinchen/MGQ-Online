#----------------------------------------------------------------
#  scene_support.rb
#
#  Changelog:
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

# The DLL's side of the story's scene (MGQOnline.Game's Scene folder, behind SceneTopics) for the
# script tests: SceneStandIn keeps a teller's changes as the DLL does, merged and split into their
# messages, and refuses a viewer's changes as the DLL does; scene_fixtures_test.rb checks it against
# the golden cases of fixtures/scene/cases.json, played as coop_scene.rbx played them before the
# rules left it. It reads and writes the changes' lines with the battle line codec, so a test loads
# battles_sync_wire.rbx before the scene's first change.

require_relative "rules_support"

# The golden cases of the story's scene.
SCENE_CASES = rule_cases("scene", "cases.json")

# Stands in for the scene's queue and checks, each topic's request in, its reply out.
class SceneStandIn
  MAX_BATCH = SCENE_CASES["max_batch"]
  MAX_BATCH_BYTES = SCENE_CASES["max_batch_bytes"]
  MAX_PICTURE = SCENE_CASES["max_picture"]
  MOST_AMOUNT = SCENE_CASES["most_amount"]
  MOST_FRAMES = SCENE_CASES["most_frames"]
  MOST_SHAKE = SCENE_CASES["most_shake"]
  SKIP_SEND_FRAMES = 10
  BATCH_KIND = "batch"
  PICTURE_NAME = /\A[\w\- ]+(\.[\w\- ]+)*\z/
  FILE_NAME = /\A(?!.*\.\.)[^\/\\:*?"<>|]{1,100}\z/
  PICTURE_ARGS = {
    "show" => [:name, :origin, :amount, :amount, :amount, :amount, :amount, :blend],
    "move" => [:origin, :amount, :amount, :amount, :amount, :amount, :blend, :frames],
    "rotate" => [:amount], "start_tone_change" => [:tone, :frames], "erase" => []
  }
  SCREEN_ARGS = {
    "start_fadeout" => [:frames], "start_fadein" => [:frames], "start_tone_change" => [:tone, :frames], "start_flash" => [:color, :frames],
    "start_shake" => [:shake, :shake, :frames], "od_fadein" => [], "od_fadeout" => []
  }
  EVENT_METHODS = %w(route animation balloon erase)
  AUDIO_CALLS = %w(bgm_play bgm_stop bgm_fade bgs_play bgs_stop bgs_fade me_play me_stop me_fade se_play se_stop)
  MAP_LOOKS = %w(tileset battleback parallax)

  # Makes a stand-in with nothing waiting.
  def initialize
    @outgoing = []
    @flushed_at = nil
  end

  # The battle line codec, loaded by the test.
  #
  # @return [Module] MGQ_MpBattlesSync::Wire.
  def wire
    MGQ_MpBattlesSync::Wire
  end

  # Answers a topic.
  #
  # @param topic [String] The topic, such as "scene.change".
  # @param request [Object] The request as the scripts hand it over.
  # @param frame [Integer] The frame now.
  # @return [Object] The reply.
  def answer(topic, request, frame = 0)
    case topic
    when "scene.change"
      args = wire.parse(request["line"])
      return false unless args

      add(request["kind"], args, request["map"], request["logged"], request["skip"])
      true
    when "scene.flush" then flush(request, frame)
    when "scene.clear" then @outgoing = []; @flushed_at = nil; nil
    when "scene.take" then take(request)
    when "scene.check"
      args = wire.parse(request["line"])
      args ? refusal(request["kind"], args) : "arguments this game cannot take"
    else raise "no stand-in for #{topic}"
    end
  end

  # Keeps a change, merged with those waiting as coop_scene.rbx merged them.
  #
  # @param kind [String] What changes.
  # @param args [Array] Its arguments.
  # @param map [Integer] The map it happened on.
  # @param logged [Boolean] Whether the teller logs it.
  # @param skip [Boolean] Whether the player holds the game's skip.
  def add(kind, args, map, logged, skip)
    case kind
    when "picture.move"
      last = @outgoing.rindex { |entry| entry[0].start_with?("picture.") && entry[1][0] == args[0] }
      @outgoing.delete_at(last) if last && @outgoing[last][0] == kind
    when "map.camera"
      @outgoing.reject! { |entry| entry[0] == kind }
    when "audio.se_play"
      @outgoing.reject! { |entry| entry[0] == kind } if skip
    when "story.values"
      waiting = @outgoing.rindex { |entry| entry[0] == kind }
      if waiting
        keys = args.map { |value| value[0, 2] }
        args = @outgoing.delete_at(waiting)[1].reject { |value| keys.include?(value[0, 2]) } + args
      end
    end
    @outgoing << [kind, args, map, logged]
  end

  # Takes the changes waiting as their messages once due: while the player holds the skip and the
  # story plays, only SKIP_SEND_FRAMES after the last went out.
  #
  # @param request [Hash, nil] "skip" and "playing", nil for at once.
  # @param frame [Integer] The frame now.
  # @return [Array<Hash>, false, nil] Each "map", "kind", "args" and "changes"; false while they wait
  #   for their time; nil while nothing waits.
  def flush(request = nil, frame = 0)
    return nil if @outgoing.empty?
    return false if request && request["skip"] && request["playing"] && @flushed_at && frame >= @flushed_at && frame - @flushed_at < SKIP_SEND_FRAMES

    @flushed_at = frame

    groups = []
    @outgoing.each { |entry| groups.last && groups.last[0] == entry[2] ? groups.last[1] << entry : groups << [entry[2], [entry]] }
    @outgoing = []
    groups.map { |map, entries| split(entries).map { |batch| message(map, batch) } }.flatten(1)
  end

  # Splits the changes of one map into their messages.
  #
  # @param entries [Array<Array>] The changes.
  # @return [Array<Array<Array>>] Each message's changes with their lines.
  def split(entries)
    batches = [[]]
    bytes = -1
    entries.each do |entry|
      line = wire.line([[entry[0], entry[1]]])
      batch = batches.last
      if batch.size >= MAX_BATCH || (!batch.empty? && bytes + 1 + line.bytesize > MAX_BATCH_BYTES)
        batches << (batch = [])
        bytes = -1
      end
      bytes += 1 + line.bytesize
      batch << [entry, line]
    end
    batches
  end

  # Writes a message of changes.
  #
  # @param map [Integer] The map.
  # @param batch [Array<Array>] The changes with their lines.
  # @return [Hash] The message.
  def message(map, batch)
    args = batch.size == 1 ? wire.line(batch[0][0][1]) : batch.map { |_entry, line| line }.join("\t")
    { "map" => map, "kind" => batch.size == 1 ? batch[0][0][0] : BATCH_KIND, "args" => args,
      "changes" => batch.map { |(kind, values, _map, logged), _line| [kind, wire.line(values)[0, 120], logged] } }
  end

  # Checks a message for a viewer.
  #
  # @param request [Hash] "kind", "line", "map" and "here".
  # @return [Array, String, nil] Each change's refusal or nil, a text refusing the whole message, nil for a line that does not read.
  def take(request)
    values = wire.parse(request["line"])
    return nil unless values
    return [verdict(request["kind"], values, request["map"], request["here"])] unless request["kind"] == BATCH_KIND
    return "more than #{MAX_BATCH} or not changes" unless values.size <= MAX_BATCH && values.all? { |entry| entry.is_a?(Array) && entry.size == 2 && entry[0].is_a?(String) && entry[1].is_a?(Array) }

    values.map { |kind, args| verdict(kind, args, request["map"], request["here"]) }
  end

  # Tells what a viewer refuses of one change.
  #
  # @param kind [String] What changes.
  # @param args [Array] Its arguments.
  # @param map [Integer] The teller's map.
  # @param here [Integer] The player's map.
  # @return [String, nil] The refusal.
  def verdict(kind, args, map, here)
    on_the_way(kind, map, here) || refusal(kind, args)
  end

  # Tells whether a change is bound to the teller's map while the player is on the way.
  #
  # @param kind [String] What changes.
  # @param map [Integer] The teller's map.
  # @param here [Integer] The player's map.
  # @return [String, nil] The refusal.
  def on_the_way(kind, map, here)
    return nil if map == here

    bound = kind.start_with?("event.") || kind == "map.camera" || MAP_LOOKS.include?(kind.sub("map.", "")) || kind =~ /\Aaudio\.(me|se)_/
    bound ? "the player is still on the way, on map #{here}" : nil
  end

  # Tells what a viewer refuses of a change before the game's facts.
  #
  # @param kind [String] What changes.
  # @param args [Array] Its arguments.
  # @return [String, nil] The refusal.
  def refusal(kind, args)
    target, method = kind.split(".", 2)
    case target
    when "picture" then picture_refusal(method, args)
    when "screen"
      return "this game's screen has no such change" unless SCREEN_ARGS.key?(method)

      args_fit?(SCREEN_ARGS[method], args) ? nil : "arguments this game cannot take"
    when "player" then method == "transparent" ? nil : "no such change"
    when "story" then method == "values" ? nil : "no such change"
    when "event" then EVENT_METHODS.include?(method) ? nil : "no such change"
    when "audio"
      return "no such call" unless AUDIO_CALLS.include?(method)
      return nil unless method.end_with?("_play")

      name = args[0].to_s
      name =~ FILE_NAME ? nil : "'#{name[0, 40]}' is no sound's file name"
    when "map"
      return (args.size == 2 && args.all? { |value| value.is_a?(Numeric) } ? nil : "no place") if method == "camera"

      MAP_LOOKS.include?(method) || method == "zoom" ? nil : "no such change"
    else "no such change"
    end
  end

  # Tells what a viewer refuses of a picture's change.
  #
  # @param method [String, nil] What happens to the picture.
  # @param args [Array] The picture's number, then the method's arguments.
  # @return [String, nil] The refusal.
  def picture_refusal(method, args)
    number = args[0].to_i rescue nil
    return "no such change or picture" unless PICTURE_ARGS.key?(method) && number && number > 0 && number <= MAX_PICTURE
    return "arguments this game cannot take" unless args_fit?(PICTURE_ARGS[method], args[1..-1])
    return "'#{args[1][0, 40]}' is no picture's file name" if method == "show" && args[1] !~ PICTURE_NAME

    nil
  end

  # Reports whether arguments are ones the game takes.
  #
  # @param kinds [Array<Symbol>] The kind of each.
  # @param args [Array] The arguments.
  # @return [Boolean] Whether they are.
  def args_fit?(kinds, args)
    kinds.size == args.size && kinds.zip(args).all? { |kind, value| arg_fits?(kind, value) }
  end

  # Reports whether one argument is of its kind and within the limits.
  #
  # @param kind [Symbol] The kind.
  # @param value [Object] The argument.
  # @return [Boolean] Whether it is.
  def arg_fits?(kind, value)
    case kind
    when :amount then number?(value) && value.abs <= MOST_AMOUNT
    when :frames then number?(value) && value == value.floor && value >= 0 && value <= MOST_FRAMES
    when :origin then value.is_a?(Integer)
    when :blend then value.is_a?(Integer) && value >= 0 && value <= 2
    when :tone then value.is_a?(Tone)
    when :color then value.is_a?(Color)
    when :shake then number?(value) && value >= 0 && value <= MOST_SHAKE
    when :name then value.is_a?(String)
    else false
    end
  end

  # Reports whether a value is a whole or finite number.
  #
  # @param value [Object] The value.
  # @return [Boolean] Whether it is.
  def number?(value)
    value.is_a?(Integer) || (value.is_a?(Float) && value.finite?)
  end
end

# Checks the stand-in against the golden cases, which needs the battle line codec loaded with the
# game's Tone and Color.
#
# @raise [RuntimeError] A case the stand-in answers otherwise than the DLL.
def check_scene_stand_in
  SCENE_CASES["queue"].each do |scenario|
    stand_in = SceneStandIn.new
    scenario["steps"].each do |step|
      if step["op"] == "change"
        stand_in.answer("scene.change", step)
      else
        messages = (stand_in.answer("scene.flush", nil) || []).map { |message| { "map" => message["map"], "pscene" => message["kind"], "args" => message["args"] } }
        raise "the scene stand-in sends #{scenario['name']} otherwise than the DLL" if messages != step["messages"]
      end
    end
  end
  stand_in = SceneStandIn.new
  SCENE_CASES["checks"].each do |entry|
    verdict = stand_in.answer("scene.take", entry)
    raise "the scene stand-in answers #{entry['kind']} #{entry['line'][0, 40].inspect} with #{verdict.inspect}, the DLL #{entry['refusal'].inspect}" if verdict != [entry["refusal"]]
  end
  SCENE_CASES["batches"].each do |entry|
    verdict = stand_in.answer("scene.take", { "kind" => "batch", "line" => entry["line"], "map" => 7, "here" => 7 })
    raise "the scene stand-in refuses the batch #{entry['name']} otherwise than the DLL" if verdict.is_a?(String) != !entry["refusal"].nil?
  end
end

# Answers the scene's topics from a stand-in at the frame the tests count, Graphics.frame_count.
#
# @param fake [FakeBridge] The test's bridge.
def answer_scene(fake)
  stand_in = SceneStandIn.new
  %w(scene.change scene.flush scene.clear scene.take scene.check).each do |topic|
    fake.answer(topic) { |request| stand_in.answer(topic, request, defined?(Graphics) ? Graphics.frame_count : 0) }
  end
end
