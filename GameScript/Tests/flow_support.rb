#----------------------------------------------------------------
#  flow_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# The DLL's side of the one guard of the game's flow (MGQOnline.Game's FlowGuard, behind
# FlowTopics) for the script tests: FlowStandIn answers what to put back as the DLL does.

# Stands in for the guard's topics, each request in, its reply out.
class FlowStandIn
  # Frames a fade or a tint the guard starts takes.
  FRAMES = 30

  # The escape spell's ban, a switch of the place, and the switch itself.
  ESCAPE = "escape"
  ESCAPE_SWITCH = 94

  # The bans of the place the player stands in.
  PLACE_BANS = [ESCAPE]

  # The bans the commands of Change Save, Menu, Encounter and Formation Access set, by code.
  ACCESS_BANS = { 134 => "save", 135 => "menu", 136 => "encounter", 137 => "formation" }

  # How deep the guard follows calls of common events.
  MAX_DEPTH = 8

  # What the guard reads of commands: whether they fade in, the last tint, each picture's and ban's
  # last state, the character's and followers' last setting, a temporary party and the common
  # events it lacks.
  Rest = Struct.new(:fades_in, :tone, :pictures, :bans, :hidden, :followers, :party, :needs)

  # Answers a topic of the guard.
  #
  # @param topic [String] "flow.plan" or "flow.stands".
  # @param request [Hash] The request.
  # @return [Object] The reply.
  def answer(topic, request)
    return stands?(request["start"], request["now"]) if topic == "flow.stands"

    rest = read(request["rest"] || [], request["commons"] || {})
    return { "needs" => rest.needs } unless rest.needs.empty?

    plan(request, rest)
  end

  private

  # Tells whether the player's own scene still stands, see FlowGuard.Stands.
  def stands?(start, now)
    (now["temp_party"] && !start["temp_party"]) || (now["hidden"] && !start["hidden"]) || (!now["followers"] && start["followers"]) ||
      !(now["pictures"] - start["pictures"]).empty? ? true : false
  end

  # Finds the plan for a request, see FlowGuard.Plan.
  def plan(request, rest)
    now = request["now"]
    before = request["before"]
    owned = request["owned"] || []
    watch = request["watch"] || { "screen" => false, "hidden" => false, "route" => false, "pictures" => [] }
    dark = now["brightness"] < 255 && !now["fading_in"]
    found = nothing
    case request["cut"]
    when "skip"
      found["erase"] = now["pictures"].select { |number| rest.pictures[number] == false }.sort
      found["fade_in"] = dark && rest.fades_in ? true : false
      found["lift"] = lifted(now) { |ban| rest.bans[ban] == false }
    when "refused", "free"
      found["fade_in"] = dark
    when "cut"
      start = before || now
      found["erase"] = now["pictures"].select { |number| owned.include?(number) || rest.pictures[number] == false }.sort
      found["fade_in"] = dark
      found["tone"] = changed_tone(rest.tone || start["tone"], now["tone"])
      found["hidden"] = changed(rest.hidden == false ? false : start["hidden"], now["hidden"])
      found["followers"] = changed(rest.followers == true ? true : start["followers"], now["followers"])
      found["release_party"] = now["temp_party"] && (rest.party == false || !start["temp_party"]) ? true : false
      found["music"] = start["music"] && start["music"] != now["music"] ? start["music"] : nil
      found["lift"] = lifted(now) { |ban| rest.bans[ban] == false }
    when "leave"
      scene = !before.nil? || request["whole"]
      elsewhere = request["elsewhere"]
      found["erase"] = before ? (now["pictures"] - before["pictures"]).sort : []
      found["fade_in"] = dark
      found["tone"] = before ? changed_tone(before["tone"], now["tone"]) : nil
      found["hidden"] = scene ? changed(false, now["hidden"]) : nil
      found["followers"] = scene || elsewhere ? changed(true, now["followers"]) : nil
      found["release_party"] = now["temp_party"] && (request["whole"] || (before && !before["temp_party"])) ? true : false
      found["music"] = before && before["music"] && before["music"] != now["music"] ? before["music"] : nil
      found["lift"] = elsewhere ? lifted(now) { |ban| PLACE_BANS.include?(ban) } : []
    when "watched"
      start = before || now
      here = start["map"] == now["map"]
      found["erase"] = now["pictures"].select { |number| watch["pictures"].include?(number) }.sort
      found["fade_in"] = watch["screen"] && dark ? true : false
      found["tone"] = watch["screen"] ? changed_tone(here ? start["tone"] : [0, 0, 0, 0], now["tone"]) : nil
      found["hidden"] = watch["hidden"] ? changed(here && start["hidden"], now["hidden"]) : nil
      found["end_route"] = watch["route"] && now["route"] ? true : false
      found["clear_effects"] = watch["screen"] ? true : false
      return found
    end
    watching(found, watch)
  end

  # Leaves what a watched scene that still plays shows to it, see FlowGuard.Watching.
  def watching(found, watch)
    found["erase"] -= watch["pictures"]
    found["fade_in"] = false if watch["screen"]
    found["tone"] = nil if watch["screen"]
    found["hidden"] = nil if watch["hidden"]
    found
  end

  # The plan that puts nothing back.
  def nothing
    { "erase" => [], "fade_in" => false, "tone" => nil, "hidden" => nil, "followers" => nil, "release_party" => false, "music" => nil,
      "lift" => [], "end_route" => false, "clear_effects" => false, "frames" => FRAMES }
  end

  # Lists the bans on now that a block lifts.
  def lifted(now)
    now["bans"].select { |ban| yield(ban) }.sort
  end

  # Gives a tint unless the screen shows it already.
  def changed_tone(wanted, now)
    wanted.zip(now).all? { |a, b| (a - b).abs < 0.5 } ? nil : wanted
  end

  # Gives a setting unless it is so already.
  def changed(wanted, now)
    (wanted ? true : false) == (now ? true : false) ? nil : (wanted ? true : false)
  end

  # Reads what commands leave, through the common events they call, see FlowRest.
  def read(commands, commons)
    rest = Rest.new(false, nil, {}, {}, nil, nil, nil, [])
    walk(rest, commands, commons, [], 0)
    rest
  end

  # Reads commands into what they leave.
  def walk(rest, commands, commons, calling, depth)
    commands.each do |code, _indent, params|
      params ||= []
      case code
      when 117 then call(rest, params[0].to_i, commons, calling, depth)
      when 121 then rest.bans[ESCAPE] = params[2].to_i == 0 if params[0].to_i <= ESCAPE_SWITCH && ESCAPE_SWITCH <= params[1].to_i
      when 134, 135, 136, 137 then rest.bans[ACCESS_BANS[code]] = params[0].to_i == 0
      when 211 then rest.hidden = params[0].to_i == 0
      when 216 then rest.followers = params[0].to_i == 0
      when 222 then rest.fades_in = true
      when 223 then rest.tone = params[0] if params[0].is_a?(Array) && params[0].size == 4
      when 231 then rest.pictures[params[0].to_i] = true
      when 235 then rest.pictures[params[0].to_i] = false
      when 355, 655 then script(rest, params.find { |param| param.is_a?(String) }.to_s)
      end
    end
  end

  # Reads a call of a common event.
  def call(rest, id, commons, calling, depth)
    return if depth >= MAX_DEPTH || calling.include?(id)

    commands = commons[id]
    return rest.needs |= [id] unless commands

    walk(rest, commands, commons, calling + [id], depth + 1)
  end

  # Reads a line of a script for its fades and temporary parties.
  def script(rest, text)
    rest.fades_in = true if text.downcase.include?("fadein")
    if text.include?("release_temp_actors")
      rest.party = false
    elsif text.include?("set_temp_actors")
      rest.party = true
    end
  end
end

# Answers the guard's topics from a stand-in, noting each plan's request in $flow_asks and counting the
# questions whether the player's own scene stands in $flow_stands.
#
# @param fake [FakeBridge] The test's bridge.
def answer_flow(fake)
  stand_in = FlowStandIn.new
  %w(flow.plan flow.stands).each do |topic|
    fake.answer(topic) do |request|
      ($flow_asks ||= []) << request if topic == "flow.plan"
      $flow_stands = ($flow_stands || 0) + 1 if topic == "flow.stands"
      stand_in.answer(topic, request)
    end
  end
end
