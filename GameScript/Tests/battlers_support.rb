#----------------------------------------------------------------
#  battlers_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

# The DLL's side of the battlers the scripts build (MGQOnline.Game's BattlerSetup, behind
# BattlerTopics) for the script tests: BattlersStandIn plans a battler as the DLL does.

# Stands in for the topic battlers.plan, see BattlerSetup.Plan.
class BattlersStandIn
  # Plans a battler.
  #
  # @param request [Hash] "kind", "started", "vitals" and "mark".
  # @return [Hash] "hp", "mp", "start", "hide" and "lay_down".
  def plan(request)
    case request["kind"]
    when "ally"
      hp, mp = request["vitals"].is_a?(Array) ? request["vitals"] : []
      { "hp" => hp.is_a?(Integer) && hp >= 0 ? hp : nil, "mp" => mp.is_a?(Integer) ? mp : nil, "start" => true, "hide" => false, "lay_down" => false }
    when "reserve"
      { "hp" => nil, "mp" => nil, "start" => true, "hide" => false, "lay_down" => false }
    else
      { "hp" => nil, "mp" => nil, "start" => request["started"] == true, "hide" => request["mark"] == 1, "lay_down" => request["mark"] == 2 }
    end
  end
end

# Answers the topic from a stand-in, noting each request in $battler_plans.
#
# @param fake [FakeBridge] The test's bridge.
def answer_battlers(fake)
  stand_in = BattlersStandIn.new
  fake.answer("battlers.plan") do |request|
    ($battler_plans ||= []) << request
    stand_in.plan(request)
  end
end
