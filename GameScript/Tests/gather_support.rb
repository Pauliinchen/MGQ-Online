#----------------------------------------------------------------
#  gather_support.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Took calls, follows and offers without a warp ban
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

# The DLL's calls of a story (MGQOnline.Game's Telling/GatherCalls, behind GatherTopics) for the
# script tests: GatherStandIn keeps a leader's call, a follow, a teleport the player asked for, the
# leader's hold and the offers to follow a Raid World's teller as the DLL does, by the frame the
# tests count, and is checked against the golden cases of fixtures/gather/cases.json as this file
# loads, played as coop_gather.rbx played them before the rules left it.

require_relative "rules_support"

# The golden cases of a story's calls.
GATHER_CASES = rule_cases("gather", "cases.json")

# Stands in for the calls of a story, each topic's request in, its reply out, at a frame.
class GatherStandIn
  # The frames the rules count, as the cases recorded them.
  FRAMES = GATHER_CASES["frames"]
  GATHER_FRAMES = FRAMES["gather_frames"]
  CALL_FRAMES = FRAMES["call_frames"]
  HOLD_FRAMES = FRAMES["hold_frames"]
  CALL_LAPSE_FRAMES = FRAMES["call_lapse_frames"]
  ASKED_LAPSE_FRAMES = FRAMES["asked_lapse_frames"]
  FOLLOW_OFFER_FRAMES = FRAMES["follow_offer_frames"]
  NAMED_MISSING = FRAMES["named_missing"]

  # Makes a stand-in with no call, hold or offer.
  def initialize
    @call = nil
    @taken = nil
    @hold = nil
    @offers = {}
  end

  # Answers a topic.
  #
  # @param topic [String] The topic, such as "gather.called".
  # @param request [Object] The request as the scripts hand it over.
  # @param frame [Integer] The frame.
  # @return [Object] The reply.
  def answer(topic, request, frame)
    case topic
    when "gather.called" then { "notice" => called(request, frame) }
    when "gather.come_to" then @call = { :name => request["name"], :since => frame - GATHER_FRAMES, :place => request["place"], :called => frame, :asked => true, :lapse => ASKED_LAPSE_FRAMES, :bans => {} }; nil
    when "gather.followed" then @call = { :name => request["name"], :id => request["id"], :since => frame - GATHER_FRAMES, :place => request["place"], :called => frame, :follow => true, :lapse => request["raid"] ? ASKED_LAPSE_FRAMES : nil, :bans => {} }; nil
    when "gather.ban" then keep_ban(request)
    when "gather.frame" then state(request, frame)
    when "gather.take" then take(request["raid"], frame)
    when "gather.calling_battle" then coming?(frame) && @call[:id] == request["id"] && @call[:place][0] == request["map"]
    when "gather.drop_call" then name = @call && @call[:name]; @call = nil; name
    when "gather.hold" then @hold = { :since => frame, :called => frame }; nil
    when "gather.drop_hold" then held = !@hold.nil?; @hold = nil; held
    when "gather.holding" then holding(request, frame)
    when "gather.offer" then @offers[request["id"]] = { :name => request["name"], :place => request["place"], :since => frame, :seen => false }; nil
    when "gather.follow_offer" then follow_offer(request, frame, false)
    when "gather.accept" then follow_offer(request, frame, true)
    when "gather.decline" then offer = @offers.delete(request["id"]); offer && offer[:name]
    when "gather.forget" then forgotten = { "held" => !@hold.nil?, "call" => @call && @call[:name] }; @hold = @call = @taken = nil; forgotten
    when "gather.forget_offers" then @offers.clear; nil
    else raise "no stand-in for #{topic}"
    end
  end

  # Reports whether a moment lies less than some frames back, a moment ahead counting as long past.
  #
  # @param since [Integer] The moment's frame.
  # @param frames [Integer] The frames.
  # @param now [Integer] The frame.
  # @return [Boolean] Whether it does.
  def within?(since, frames, now)
    left = since + frames - now
    left > 0 && left <= frames
  end

  # Takes a leader's call.
  #
  # @param request [Hash] The request.
  # @param frame [Integer] The frame.
  # @return [String, nil] The notice.
  def called(request, frame)
    return @call = nil if request["near"]
    return nil if request["pvp"]

    notice = nil
    if @call.nil?
      @call = { :name => request["name"], :since => frame, :bans => {} }
      notice = "#{request['name']}'s story is starting. You join them in #{GATHER_FRAMES / 60} seconds."
    elsif @call[:asked] || @call[:lapse]
      @call.delete(:asked)
      @call.delete(:lapse)
      @call[:name] = request["name"]
    end
    @call.merge!(:id => request["id"], :place => request["place"], :called => frame)
    notice
  end

  # Keeps a ban of the place for the arrival.
  #
  # @param request [Hash] The request.
  # @return [Boolean] Whether a call to that map keeps it.
  def keep_ban(request)
    return false unless @call && @call[:place][0] == request["map"]

    @call[:bans][request["id"]] = request["on"]
    true
  end

  # The frames without a call after which the call lapses.
  #
  # @return [Integer] The frames.
  def lapse_frames
    @call[:lapse] || CALL_LAPSE_FRAMES
  end

  # Reports whether a call is about to bring the player over.
  #
  # @param frame [Integer] The frame.
  # @return [Boolean] Whether one is.
  def coming?(frame)
    !@call.nil? && within?(@call[:called], lapse_frames, frame)
  end

  # Finds the call the player has yet to answer, forgetting it once the calls stopped.
  #
  # @param frame [Integer] The frame.
  # @return [Array] The call or nil, and the notice once it lapsed or nil.
  def pending(frame)
    return [nil, nil] unless @call
    return [@call, nil] if within?(@call[:called], lapse_frames, frame)

    notice = @call[:asked] ? "You were too busy to teleport to #{@call[:name]}." : @call[:follow] ? "#{@call[:name]}'s story went on without you." : "#{@call[:name]}'s story started without you."
    @call = nil
    [nil, notice]
  end

  # Tells where the player comes to, once the frames passed and the map settled.
  #
  # @param frame [Integer] The frame.
  # @param settled [Boolean] Whether the map settled.
  # @return [Array<Integer>, nil] The place.
  def come(frame, settled)
    call, _notice = pending(frame)
    call && !within?(call[:since], GATHER_FRAMES, frame) && settled ? call[:place] : nil
  end

  # Finds the follow the player takes.
  #
  # @param frame [Integer] The frame.
  # @return [Hash, nil] "id", "name" and "place".
  def follow_taken(frame)
    return { "id" => @call[:id], "name" => @call[:name], "place" => @call[:place] } if @call && @call[:follow] && @call[:id] && coming?(frame)
    return nil unless @taken && within?(@taken[:since], CALL_LAPSE_FRAMES, frame)

    { "id" => @taken[:id], "name" => @taken[:name], "place" => @taken[:place] }
  end

  # Reads the call as the frame stands.
  #
  # @param request [Hash] The request.
  # @param frame [Integer] The frame.
  # @return [Hash] The state.
  def state(request, frame)
    call, notice = pending(frame)
    place = come(frame, request["settled"])
    { "coming" => coming?(frame),
      "pending" => call && { "name" => call[:name], "id" => call[:id], "place" => call[:place], "since" => call[:since], "follow" => call[:follow] ? true : false, "asked" => call[:asked] ? true : false },
      "notice" => notice, "come" => place, "waited" => !call.nil? && !within?(call[:since], GATHER_FRAMES, frame), "follow" => follow_taken(frame), "holding" => !@hold.nil?,
      "doing" => doing(request["leading"], request["missing"], frame), "idle" => @call.nil? && @hold.nil? && follow_taken(frame).nil? }
  end

  # Names what the player is doing.
  #
  # @param leading [Boolean] Whether the player leads the party.
  # @param missing [Array<String>] Those not near.
  # @param frame [Integer] The frame.
  # @return [Hash, nil] "text" and "left".
  def doing(leading, missing, frame)
    if @hold && leading
      more = missing.size - NAMED_MISSING
      text = missing.empty? ? "Gathering the party" : "Gathering: #{missing.first(NAMED_MISSING).join(', ')}#{" +#{more}" if more > 0}"
      return { "text" => text, "left" => @hold[:since] + HOLD_FRAMES - frame }
    end

    call, _notice = pending(frame)
    return nil unless call

    left = call[:since] + GATHER_FRAMES - frame
    left > 0 ? { "text" => "Joining #{call[:name]}", "left" => left } : { "text" => "Joining #{call[:name]} once free", "left" => nil }
  end

  # Takes the call the player answers now.
  #
  # @param raid [Boolean] Whether a Raid World is open.
  # @param frame [Integer] The frame.
  # @return [Hash, nil] The call taken.
  def take(raid, frame)
    return nil unless @call

    call = @call
    @call = nil
    @taken = { :id => call[:id], :name => call[:name], :place => call[:place], :since => frame } if call[:follow] && raid && call[:id]
    { "name" => call[:name], "id" => call[:id], "place" => call[:place], "follow" => call[:follow] ? true : false, "asked" => call[:asked] ? true : false,
      "bans" => call[:bans].sort.map { |id, on| [id, on] } }
  end

  # Tells whether the scene held still waits before a command.
  #
  # @param request [Hash] The request.
  # @param frame [Integer] The frame.
  # @return [Hash] "wait", "call_again", "notice" and "released".
  def holding(request, frame)
    return { "wait" => false, "call_again" => false, "notice" => nil, "released" => nil } unless @hold

    leading = request["leading"]
    if !leading || request["gathered"]
      since = @hold[:since]
      @hold = nil
      return { "wait" => false, "call_again" => false, "notice" => leading ? "The party is here." : nil,
               "released" => leading ? "the party is here after #{(frame - since) / 60} s: the story starts" : "no member follows the player's story" }
    end
    unless within?(@hold[:since], HOLD_FRAMES, frame)
      @hold = nil
      names = request["missing"].join(", ")
      return { "wait" => false, "call_again" => false, "notice" => "The story starts without #{names}.", "released" => "the story starts without #{names}" }
    end
    unless within?(@hold[:called], CALL_FRAMES, frame)
      @hold[:called] = frame
      return { "wait" => true, "call_again" => true, "notice" => nil, "released" => nil }
    end
    { "wait" => true, "call_again" => false, "notice" => nil, "released" => nil }
  end

  # Finds a standing offer, dropping one that ended; accepting takes it.
  #
  # @param request [Hash] The request.
  # @param frame [Integer] The frame.
  # @param accept [Boolean] Whether the player accepted it.
  # @return [Hash, nil] The offer, why it ended, or nil.
  def follow_offer(request, frame, accept)
    id = request["id"]
    offer = @offers[id]
    return nil unless offer

    telling = request["telling"]
    offer[:seen] = true if telling
    dropped = offer[:seen] && !telling ? "their telling ended" : !within?(offer[:since], FOLLOW_OFFER_FRAMES, frame) ? "it stood #{FOLLOW_OFFER_FRAMES / 60} s" : offer[:place][0] == request["map"] ? "the player is on that map already" : nil
    @offers.delete(id) if dropped || accept
    return accept ? nil : { "dropped" => dropped } if dropped

    { "name" => offer[:name], "place" => offer[:place], "since" => offer[:since] }
  end
end

# Plays a recorded scenario against the stand-in as coop_gather.rbx played it, step by step.
#
# @param scenario [Hash] The scenario.
def check_gather_scenario(scenario)
  peers = { "leader" => "Leader", "other" => "Other", "t" => "Teller" }
  stand_in = GatherStandIn.new
  frame = 5000
  map = 3
  raid = false
  pvp = false
  behind = false
  leading = false
  members = []
  watching = []
  telling = []
  scenario["steps"].each do |step|
    frame = step["frame"] if step["frame"]
    notices = []
    sent = []
    holding = nil
    follow = lambda { |id, place| stand_in.answer("gather.followed", { "name" => peers[id], "id" => id, "place" => place, "raid" => raid }, frame) }
    missing = lambda { members.map { |id| peers[id] } }
    case step["op"]
    when "called"
      notice = stand_in.answer("gather.called", { "name" => peers[step["by"]], "id" => step["by"], "place" => step["place"], "near" => false, "pvp" => pvp }, frame)["notice"]
      notices << notice if notice
    when "come_to" then stand_in.answer("gather.come_to", { "name" => step["name"], "place" => step["place"] }, frame)
    when "followed" then follow.call(step["by"], step["place"])
    when "raid" then raid = step["raid"]
    when "map" then map = step["map"]
    when "pvp" then pvp = step["pvp"]
    when "behind" then behind = step["behind"]
    when "drop_call" then stand_in.answer("gather.drop_call", nil, frame)
    when "forget" then stand_in.answer("gather.forget", nil, frame)
    when "hold"
      leading = true
      members = step["members"]
      stand_in.answer("gather.hold", nil, frame)
      notices << "Gathering the party for the story . . ."
      sent << [-1, "gather"]
    when "members" then members = step["members"]
    when "holding"
      held = stand_in.answer("gather.holding", { "leading" => true, "gathered" => raid || members.empty?, "missing" => missing.call }, frame)
      holding = held["wait"]
      notices << held["notice"] if held["notice"]
      sent << [-1, "gather"] if held["call_again"]
    when "drop_hold" then stand_in.answer("gather.drop_hold", nil, frame)
    when "arrived" then stand_in.answer("gather.take", { "raid" => raid }, frame)
    when "offer"
      moves = step["moves"] != "0"
      if behind || !watching.include?(step["by"]) || !moves
        stand_in.answer("gather.offer", { "id" => step["by"], "name" => peers[step["by"]], "place" => step["place"] }, frame)
      else
        follow.call(step["by"], step["place"])
      end
    when "watch" then watching = step["peers"]
    when "telling" then telling = step["peers"]
    when "accept"
      offer = stand_in.answer("gather.accept", { "id" => step["by"], "telling" => telling.include?(step["by"]), "map" => map }, frame)
      stand_in.answer("gather.followed", { "name" => offer["name"], "id" => step["by"], "place" => offer["place"], "raid" => raid }, frame) if offer
    when "decline" then stand_in.answer("gather.decline", { "id" => step["by"] }, frame)
    end
    state = stand_in.answer("gather.frame", { "settled" => true, "leading" => leading, "missing" => missing.call }, frame)
    notices << state["notice"] if state["notice"]
    pending = state["pending"]
    doing = state["doing"]
    answer = {}
    answer["holding"] = holding unless holding.nil?
    answer.merge!(
      "coming" => state["coming"], "due" => !state["come"].nil?,
      "pending" => pending && { "name" => pending["name"], "place" => pending["place"], "follow" => pending["follow"], "asked" => pending["asked"] },
      "come" => state["come"], "doing" => doing && (doing["left"] ? [doing["text"], doing["left"]] : doing["text"]),
      "followed_id" => state["follow"] && state["follow"]["id"], "story_map" => [8, 9].select { |each| each == map || (state["follow"] && state["follow"]["place"][0] == each) },
      "calling_battle" => peers.keys.select { |id| stand_in.answer("gather.calling_battle", { "id" => id, "map" => 9 }, frame) },
      "holding_story" => state["holding"],
      "offers" => peers.keys.select { |id| (offer = stand_in.answer("gather.follow_offer", { "id" => id, "telling" => telling.include?(id), "map" => map }, frame)) && !offer["dropped"] },
      "notices" => notices, "sent" => sent)
    raise "the gather stand-in differs at #{scenario['name']}: after #{step.reject { |key, _| key == 'answer' }.inspect} it answers #{answer.inspect}, the script #{step['answer'].inspect}" unless answer == step["answer"]
  end
end

GATHER_CASES["scenarios"].each { |scenario| check_gather_scenario(scenario) }

# Answers the topics of a story's calls on a FakeBridge with a GatherStandIn, $gather_stand_in, at
# the frame the tests count, Graphics.frame_count.
#
# @param fake [FakeBridge] The bridge.
def answer_gather(fake)
  $gather_stand_in = GatherStandIn.new
  %w(called come_to followed ban frame take calling_battle drop_call hold drop_hold holding offer follow_offer accept decline forget forget_offers).each do |name|
    fake.answer("gather.#{name}") { |request| $gather_stand_in.answer("gather.#{name}", request, Graphics.frame_count) }
  end
end
