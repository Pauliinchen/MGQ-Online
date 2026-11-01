#----------------------------------------------------------------
#  choices_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-01: Dropped the game's window base, which the question's screen no longer builds on
#                            - Read the outcomes of the branch events, Succubus Village's and their own keys from the table as C# walks them
#                            - Sent away the companions an outcome sends away on the player's playthrough
#      Paulinchen  2026-10-31: Stood in for the game's window base the screen of a question builds on
#                            - Left the choices a stream hands the run of out, as C# does
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

# The DLL's rules of the story's choices (MGQOnline.Game's Story/Choices, behind ChoiceTopics) for
# the script tests: ChoicesStandIn answers the topics as coop_choices.rbx did before the rules left
# it, over the table fixtures/choices/cases.json recorded with them, and is checked against every
# case of that file as this file loads, so it cannot drift from what C# answers.

require_relative "rules_support"

# The golden cases of the story's choices, with the table the rules read.
CHOICES_CASES = rule_cases("choices", "cases.json")

# Stands in for the rules of the story's choices, each topic's request in, its reply out.
module ChoicesStandIn
  # The table as the script held it.
  TABLE = CHOICES_CASES["table"]

  # The choices, in story order.
  BRANCHES = TABLE["branches"]

  # The routes' names and the companions each outcome of the Great Decision changes.
  ROUTE_NAMES = ["Angelic Dominion route", "Monster Realm route", "Chaos route"]
  ROUTE_PARTIES = ["Alice, Alicetroemeria and Morrigan join; Ilias's companions leave.", "Ilias, Micaela-chan, Lucifina-chan, Eden and Heinrich join; Alice's companions leave.", ""]

  # Answers a topic.
  #
  # @param topic [String] The topic, such as "choices.passed".
  # @param request [Object] The request as the scripts hand it over.
  # @return [Object] The reply.
  def self.answer(topic, request)
    case topic
    when "choices.passed" then passed(request["from"], request["to"], request["values"], request["start"])
    when "choices.prompts" then prompts(request)
    when "choices.missed" then missed(request)
    when "choices.offered" then offered(request)
    when "choices.endings" then endings?(request)
    when "choices.note" then note(request)
    when "choices.outcome" then outcome(request)
    when "choices.personal" then personal(request)
    when "choices.skip" then request["kind"] == "actors" && TABLE["choice_companions"].include?(request["id"]) ? "a choice's companion, who comes with the player's own outcome" : nil
    when "choices.offer_refusal" then offer_refusal(request)
    when "choices.lapsed" then request["since"].select { |_id, start| request["now"] - start >= TABLE["offer_frames"] || request["now"] < start }.map { |id, _start| id }
    when "choices.table" then table
    else raise "no stand-in for #{topic}"
    end
  end

  # Finds a choice.
  #
  # @param key [String] Its name.
  # @return [Hash] The choice.
  def self.branch(key)
    BRANCHES.find { |candidate| candidate["key"] == key }
  end

  # Reads a switch of a story's values.
  #
  # @param values [Hash] The values.
  # @param id [Integer] The switch.
  # @return [Boolean] Whether it is on.
  def self.switch?(values, id)
    values["s"].include?(id)
  end

  # Reads a variable of a story's values.
  #
  # @param values [Hash] The values.
  # @param id [Integer] The variable.
  # @return [Integer] Its value, 0 for none.
  def self.variable(values, id)
    pair = values["v"].find { |each, _value| each == id }
    pair ? pair[1].to_i : 0
  end

  # Reports whether a story made a choice already.
  #
  # @param key [String] The choice.
  # @param values [Hash] The story's values.
  # @return [Boolean] Whether it did.
  def self.made?(key, values)
    case key
    when "side" then switch?(values, 4) || switch?(values, 5)
    when "magistea" then switch?(values, 2096) || switch?(values, 2097)
    when "navy" then variable(values, 1050) >= 9 || variable(values, 1051) >= 5
    when "plansect" then variable(values, 1061) >= 1
    when "succubus" then TABLE["succubus"].any? { |entry| holds?(entry["sign"], values) }
    when "spider" then switch?(values, 2280) || switch?(values, 2281)
    when "sphinx" then switch?(values, 2090) || values["roster"].include?(153)
    when "decision" then variable(values, 1001) >= TABLE["great_decision"]
    else false
    end
  end

  # Reports whether a story holds the values that tell a walked outcome apart, such as
  # "s2280 s2281" or "v1061=3".
  #
  # @param sign [String] The values.
  # @param values [Hash] The story's values.
  # @return [Boolean] Whether it does.
  def self.holds?(sign, values)
    sign.split(" ").all? do |part|
      key, value = part.split("=")
      value ? variable(values, key[1..].to_i) == value.to_i : switch?(values, key[1..].to_i)
    end
  end

  # Lists the switches and variables that are a choice's own: a branch event's from the table, the
  # side's those its outcomes set.
  #
  # @param branch [Hash] The choice.
  # @return [Array<Array<Integer>>] The switches, then the variables.
  def self.keys_of(branch)
    return TABLE["keys"][branch["key"]] if TABLE["keys"].key?(branch["key"])
    return [[], []] if branch["key"] == "decision"

    [branch["outcomes"].map { |outcome| (outcome["switches"] || []).map { |id, _on| id } }.flatten.uniq,
     branch["outcomes"].map { |outcome| (outcome["variables"] || []).map { |id, _value| id } }.flatten.uniq]
  end

  # Reports whether a stream hands the player the run of a choice: one does, and the choice's point
  # lies past the main story's progress where it began.
  #
  # @param key [String] The choice.
  # @param start [Array<Integer>, nil] Where the stream began, nil for none.
  # @return [Boolean] Whether it does.
  def self.logged?(key, start)
    start ? branch(key)["point"] > start[0] : false
  end

  # Lists the choices a catch-up carries the player past, which their own story has not made and
  # the save's log does not cover.
  #
  # @param from [Integer] The progress before.
  # @param to [Integer] The progress after.
  # @param values [Hash] The player's own story.
  # @param start [Array<Integer>, nil] Where the stream that hands the player runs began.
  # @return [Array<String>] The choices.
  def self.passed(from, to, values, start)
    BRANCHES.select { |branch| from < branch["point"] && to >= branch["point"] && !made?(branch["key"], values) && !logged?(branch["key"], start) }.map { |branch| branch["key"] }
  end

  # Lists the choices a story passing on asks the player's own outcome of.
  #
  # @param request [Hash] The request.
  # @return [Array<String>] The choices.
  def self.prompts(request)
    values = request["values"]
    keys = passed(request["from"], request["to"], values, request["start"]) - (request["raid"] ? ["decision"] : ["side", "decision"])
    BRANCHES.each do |branch|
      next if %w(side decision).include?(branch["key"]) || keys.include?(branch["key"]) || made?(branch["key"], values)

      keys << branch["key"] if (keys_of(branch).flatten & request["changed"]).any?
    end
    keys.reject { |key| request["waiting"].include?(key) || logged?(key, request["start"]) }
  end

  # Lists the choices a later build added that a Raid World's story is past without the save's own
  # outcome.
  #
  # @param request [Hash] The request.
  # @return [Array<String>] The choices.
  def self.missed(request)
    return [] unless request["raid"]

    TABLE["later_branches"].select do |key|
      request["progress"] >= branch(key)["point"] && !made?(key, request["values"]) && !request["waiting"].include?(key) && !logged?(key, request["start"])
    end
  end

  # Reports whether both endings are cleared.
  #
  # @param context [Hash] The game.
  # @return [Boolean] Whether they are.
  def self.endings?(context)
    return TABLE["route_clears"].all? { |id| switch?(context["values"], id) } if context["raid"]

    context["ends"][0] && context["ends"][1] ? true : false
  end

  # Lists the outcomes of the Navy or the Pirates the player may still take.
  #
  # @param values [Hash] The player's story.
  # @return [Array<Integer>] The outcomes.
  def self.navy_sides(values)
    taken = TABLE["navy_sides"].index { |id| switch?(values, id) }
    taken ? [taken] : [0, 1]
  end

  # Lists the Great Decision's outcomes a Raid World offers.
  #
  # @param context [Hash] The game.
  # @return [Array<Integer>] The outcomes.
  def self.decision_routes(context)
    return [context["raid_route"]] if context["raid_route"]

    context["world_routes"] || (endings?(context) ? [0, 1, 2] : [0, 1])
  end

  # Lists the outcomes the screen offers for a choice.
  #
  # @param context [Hash] The game, with the choice under "key".
  # @return [Hash] "labels" and "outcomes".
  def self.offered(context)
    key = context["key"]
    outcomes = branch(key)["outcomes"]
    indexes =
      if key == "decision" && context["raid"] then decision_routes(context)
      elsif key == "navy" then navy_sides(context["values"])
      elsif key == "decision" && !endings?(context) then [0, 1]
      else (0...outcomes.size).to_a
      end
    { "labels" => indexes.map { |index| outcomes[index]["label"] }, "outcomes" => indexes }
  end

  # Finds the outcome an answer picks among the labels offered.
  #
  # @param key [String] The choice.
  # @param index [Integer] The answer.
  # @param values [Hash] The player's story.
  # @return [Integer] The outcome's place.
  def self.outcome_index(key, index, values)
    key == "navy" ? navy_sides(values)[index] || index : index
  end

  # Reports whether Lily is with the player once Magistea Village is decided, and whether Lucia is.
  #
  # @param answers [Hash] The answers given so far.
  # @param values [Hash] The player's story.
  # @return [Array<Boolean>] Lily, then Lucia.
  def self.magistea_companions(answers, values)
    return [answers["magistea"] == 1, answers["magistea"] == 0] if answers.key?("magistea")

    [switch?(values, 2097) || values["roster"].include?(163), switch?(values, 2096) || values["roster"].include?(167)]
  end

  # Picks the outcome of Succubus Village a side brings, by Lily or Lucia being with the player.
  #
  # @param side [Integer] The side, 0 Natasha's, 1 the mayor's.
  # @param answers [Hash] The answers given so far.
  # @param values [Hash] The player's story.
  # @return [Hash] The outcome.
  def self.succubus_outcome(side, answers, values)
    lily, lucia = magistea_companions(answers, values)
    TABLE["succubus"].find { |entry| entry["side"] == side && entry["with"] == (side == 0 ? lily : lucia) }
  end

  # Writes the line of what an outcome brings.
  #
  # @param request [Hash] The game, with "key", "index", "answers", "route" and "leader".
  # @return [String] The line.
  def self.note(request)
    key = request["key"]
    index = request["index"]
    values = request["values"]
    case key
    when "succubus" then succubus_outcome(index, request["answers"], values)["note"]
    when "decision"
      if request["raid"]
        (decision_texts(decision_routes(request)[index] || index, values) + ["The whole world plays this route."]).reject { |part| part.empty? }.join(" ")
      else
        follow = index == request["route"] ? "You follow #{request['leader']}'s route." : "Not #{request['leader']}'s route: you start it and play it on your own."
        (decision_texts(index, values) + [follow]).reject { |part| part.empty? }.join(" ")
      end
    else branch(key)["outcomes"][outcome_index(key, index, values)]["note"].to_s
    end
  end

  # Names an outcome of the Great Decision and the companions it changes.
  #
  # @param index [Integer] The outcome.
  # @param values [Hash] The player's story.
  # @return [Array<String>] The route, then the companions.
  def self.decision_texts(index, values)
    [ROUTE_NAMES[index] + ".", variable(values, 912) > 0 ? "" : ROUTE_PARTIES[index]]
  end

  # Finds what an outcome sets, brings and sends away.
  #
  # @param request [Hash] The game, with "key", "index" and "answers".
  # @return [Hash] The writes, or the side chosen.
  def self.outcome(request)
    key = request["key"]
    index = request["index"]
    return { "side" => index == 0 ? "alice" : "ilias" } if key == "side"

    found = branch(key)
    if logged?(key, request["start"])
      return { "title" => found["title"], "label" => offered(request)["labels"][index], "switches" => [], "variables" => [], "least" => [], "self_switches" => [],
               "joins" => [], "leaves" => [], "ship" => nil }
    end

    if key == "succubus"
      chosen = succubus_outcome(index, request["answers"], request["values"])
      return { "title" => found["title"], "label" => found["outcomes"][index]["label"], "switches" => chosen["switches"] || [], "variables" => chosen["variables"] || [],
               "least" => chosen["least"] || [], "self_switches" => chosen["self_switches"] || [], "joins" => chosen["joins"], "leaves" => leaves_of(chosen, request["values"]),
               "ship" => chosen["ship"] }
    end

    outcome = found["outcomes"][outcome_index(key, index, request["values"])]
    { "title" => found["title"], "label" => offered(request)["labels"][index], "switches" => outcome["switches"] || [], "variables" => outcome["variables"] || [],
      "least" => outcome["least"] || [], "self_switches" => outcome["self_switches"] || [], "joins" => outcome["joins"] || [], "leaves" => leaves_of(outcome, request["values"]),
      "ship" => outcome["ship"] }
  end

  # Lists the companions an outcome sends away on the player's playthrough.
  #
  # @param outcome [Hash] The outcome.
  # @param values [Hash] The player's story.
  # @return [Array<Integer>] The companions.
  def self.leaves_of(outcome, values)
    outcome[variable(values, 912) == 0 ? "leaves" : "later_leaves"] || []
  end

  # Lists the keys that are the player's own as choices' outcomes.
  #
  # @param request [Hash] "raid" and "own".
  # @return [Hash] "s", "v", "maps" and "self_switches".
  def self.personal(request)
    raid = request["raid"]
    switches = []
    variables = []
    if raid || request["own"]
      BRANCHES.each do |branch|
        next if !raid && !made?(branch["key"], request["own"])

        keys = keys_of(branch)
        switches |= keys[0]
        variables |= keys[1]
      end
    end
    { "s" => switches, "v" => variables, "maps" => raid ? TABLE["navy_maps"] : [], "self_switches" => raid ? TABLE["navy_self_switches"] : [] }
  end

  # Tells why a leader may not offer a member to sync their story.
  #
  # @param request [Hash] "name", "theirs", "own" and "follows".
  # @return [String, nil] The reason, nil when an offer is possible.
  def self.offer_refusal(request)
    theirs = request["theirs"]
    own = request["own"]
    return "#{request['name']}'s story is not known yet." unless theirs
    return "#{request['name']} follows your story already." if request["follows"]
    return "#{request['name']} is not behind you in the story." if theirs == own || theirs.each_with_index.any? { |value, index| value > own[index] }

    nil
  end

  # What the scripts read of the table.
  #
  # @return [Hash] The table.
  def self.table
    decision = branch("decision")["outcomes"].map { |outcome| outcome["return"] ? { "side" => outcome["side"], "return" => outcome["return"], "map" => outcome["map"] } : {} }
    { "branches" => BRANCHES.map { |each| [each["key"], each["title"], each["point"], each["hint"]] }, "reads" => TABLE["reads"],
      "great_decision" => TABLE["great_decision"], "routes" => TABLE["routes"], "chaos_start" => TABLE["chaos_start"], "decision" => decision,
      "offer_frames" => TABLE["offer_frames"] }
  end
end

CHOICES_CASES["cases"].each do |entry|
  answer = ChoicesStandIn.answer(entry["topic"], entry["request"])
  raise "the choices stand-in answers #{entry['topic']} with #{answer.inspect} for #{entry['request'].inspect}, C# with #{entry['reply'].inspect}" unless answer == entry["reply"]
end

# Answers the topics of the story's choices on a FakeBridge with ChoicesStandIn.
#
# @param fake [FakeBridge] The bridge.
def answer_choices(fake)
  %w(passed prompts missed offered endings note outcome personal skip offer_refusal lapsed table).each do |name|
    fake.answer("choices.#{name}") { |request| ChoicesStandIn.answer("choices.#{name}", request) }
  end
end
