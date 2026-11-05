#----------------------------------------------------------------
#  telling_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Handed and expected sites as plain values
#                            - Answered at the bridge's frame, the scripts' clock
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

# The DLL's telling machine (MGQOnline.Game's TellingMachine, behind the telling topics of
# StoryTopics) for the script tests: TellingStandIn answers how a story event goes on with the
# telling as the machine does, checked against the golden cases of fixtures/telling/cases.json as
# this file loads, and takes the relay's telling lock from $lock in place of the relay.

require_relative "rules_support"

# The golden cases of a telling's continuity, recorded from coop_events.rbx before the rules left it.
TELLING_CASES = rule_cases("telling", "cases.json")

# Stands in for the telling machine: which story event goes on with the telling and which starts
# one anew, and the relay's lock a new telling takes in a Raid World.
class TellingStandIn
  # Frames after the telling moved the player in which the story's next event that runs by itself
  # goes on with it.
  CONTINUE_FRAMES = TELLING_CASES["continue_frames"]

  # Frames a new telling's first command waits at most for the relay's answer, as
  # TellingMachine.LockHoldFrames.
  LOCK_HOLD_FRAMES = 180

  # @return [Array<Array>] Each lock request's site and map, and nil for each release, in order.
  attr_reader :requests

  # Makes a machine that tells nothing yet.
  #
  # @param locks [Proc] Answers whether tellings take the lock.
  # @param lock [Proc] Answers the relay's answer: nil while unanswered, true for granted, [false,
  #   seat] for refused, the seat nil while nobody tells on the map.
  # @param answerable [Proc] Answers whether the relay hears a request now.
  def initialize(locks, lock, answerable = lambda { true })
    @locks = locks
    @lock = lock
    @answerable = answerable
    @telling = false
    @told_last_frame = false
    @map = 0
    @site = nil
    @moved_at = nil
    @moved_from = 0
    @requested = false
    @pending = false
    @held_since = 0
    @requests = []
  end

  # Whether an event of the telling runs.
  #
  # @return [Boolean] Whether it does.
  def telling?
    @telling
  end

  # Reports whether the telling goes on: an event of it runs, or it moved the player and the story's
  # next event there may still go on with it.
  #
  # @param frame [Integer] The frame.
  # @return [Boolean] Whether it does.
  def telling_or_moved?(frame)
    @telling || moved_by?(frame)
  end

  # Takes an event of the map's interpreter starting, as the topic telling.start does.
  #
  # @param tells [Boolean] Whether the event is story the player tells.
  # @param by_itself [Boolean] Whether it runs by itself.
  # @param map [Integer] The map.
  # @param site [String, nil] The site that starts it.
  # @param frame [Integer] The frame.
  # @return [Hash] The topic's answer.
  def start(tells, by_itself, map, site, frame)
    unless tells
      @telling = false
      @pending = false
      return { "telling" => false, "continued" => nil, "from" => @map, "hold" => false, "locked" => false }
    end

    from = @map
    if @told_last_frame
      continued = "frame"
    elsif by_itself && moved_by?(frame)
      continued = "moved"
      from = @moved_from
      move_lock(map)
    else
      continued = nil
      start_anew(map, site, frame)
    end
    @telling = true
    @moved_at = nil
    { "telling" => true, "continued" => continued, "from" => from, "hold" => @pending, "locked" => @requested }
  end

  # Answers what a command of the telling does, as the topic telling.command does.
  #
  # @param frame [Integer] The frame.
  # @return [Hash] The topic's answer.
  def command(frame)
    return { "command" => "go", "holder" => nil } unless @telling && @pending

    answer = @locks.call ? @lock.call : true
    if answer.nil?
      left = @held_since + LOCK_HOLD_FRAMES - frame
      return { "command" => "hold", "holder" => nil } if @answerable.call && left > 0 && left <= LOCK_HOLD_FRAMES

      @pending = false
      return { "command" => "unlocked", "holder" => nil }
    end

    @pending = false
    return { "command" => "go", "holder" => nil } if answer == true

    @requested = false
    @requests << nil
    return { "command" => "unlocked", "holder" => nil } if answer[1].nil?

    @telling = false
    { "command" => "end", "holder" => answer[1] }
  end

  # Takes the telling's event ending.
  def end_event
    @telling = false
    @pending = false
  end

  # Takes the telling moving the player onto another map.
  #
  # @param map [Integer] The map left.
  # @param frame [Integer] The frame.
  def moving(map, frame)
    return unless @telling

    @moved_at = frame
    @moved_from = map
  end

  # Takes the telling's transfer landing the player on another map while its event still runs,
  # which moves the lock there.
  #
  # @param map [Integer] The map arrived on.
  def arrived(map)
    move_lock(map) if @telling
  end

  # Ends a frame: notes whether the telling runs and gives the lock back once it neither runs nor
  # may go on after a move.
  #
  # @param frame [Integer] The frame.
  def step(frame)
    @told_last_frame = @telling
    return if @telling || moved_by?(frame) || !@requested

    @requested = false
    @requests << nil
  end

  # Starts a new telling, which takes the lock of its map while tellings take one and an event of
  # the map or a common event starts it.
  #
  # @param map [Integer] The map.
  # @param site [Array, nil] The site.
  # @param frame [Integer] The frame.
  def start_anew(map, site, frame)
    if @requested
      @requested = false
      @requests << nil
    end
    @map = map
    @site = site
    @pending = false
    return unless @locks.call && site && site[0] != "game"

    @requests << [site, map]
    @requested = true
    @pending = true
    @held_since = frame
  end

  # Moves the telling, and the lock it holds or asked for, onto another map.
  #
  # @param map [Integer] The map.
  def move_lock(map)
    return if map == @map

    @map = map
    @requests << [@site, map] if @requested
  end

  # Reports whether the telling moved the player within CONTINUE_FRAMES.
  #
  # @param frame [Integer] The frame.
  # @return [Boolean] Whether it did.
  def moved_by?(frame)
    !@moved_at.nil? && frame >= @moved_at && frame - @moved_at < CONTINUE_FRAMES
  end
end

TELLING_CASES["scenarios"].each do |scenario|
  machine = TellingStandIn.new(lambda { false }, lambda { nil })
  frame = 0
  map = 3
  scenario["steps"].each do |step|
    answer = step["answer"]
    continued = :none
    case step["op"]
    when "start", "common"
      by_itself = step["op"] == "common" || step["by_itself"] == true
      site = step["op"] == "common" ? ["ce", 1] : ["map", map, step["event"], 1]
      continued = machine.start(step["story"], by_itself, map, site, frame)["continued"]
    when "end" then machine.end_event
    when "frame" then machine.step(frame); frame += 1
    when "wait" then step["frames"].times { machine.step(frame); frame += 1 }
    when "transfer" then machine.moving(map, frame); map = step["to"]
    end
    raise "the telling stand-in differs at #{scenario['name']}: #{step.inspect}" unless machine.telling? == answer["telling"] && machine.telling_or_moved?(frame) == answer["or_moved"]
    raise "the telling stand-in goes on otherwise at #{scenario['name']}: #{step.inspect}" unless continued == :none || continued == answer["continued"]
  end
end

# The relay's answer for the telling's lock: nil while unanswered, true for granted, [false, seat]
# for refused, the seat nil while nobody tells on the map.
$lock = nil

# Answers the telling topics on a FakeBridge with a TellingStandIn, $telling_machine, which takes
# the lock while a Raid World is open (MGQ_MpCoop::Scope.raid?) and the relay's answer from $lock,
# and ends each frame after the map's update, as the DLL does at the frame's drain.
#
# @param fake [FakeBridge] The bridge.
def answer_telling(fake)
  $telling_machine = TellingStandIn.new(lambda { MGQ_MpCoop::Scope.raid? }, lambda { $lock })
  fake.answer("telling.start") do |request|
    $telling_machine.start(request["telling"], request["by_itself"], request["map"], request["site"], MGQ_Multiplayer::Bridge.frame_number)
  end
  fake.answer("telling.command") { $telling_machine.command(MGQ_Multiplayer::Bridge.frame_number) }
  fake.answer("telling.end") { $telling_machine.end_event; nil }
  fake.answer("telling.moving") { |request| $telling_machine.moving(request["map"], MGQ_Multiplayer::Bridge.frame_number); nil }
  fake.answer("telling.arrived") { |request| $telling_machine.arrived(request["map"]); nil }
  MGQ_MpHooks.after(Game_Map, :update, "telling_support") { $telling_machine.step(MGQ_Multiplayer::Bridge.frame_number) } if defined?(MGQ_MpHooks) && defined?(Game_Map)
end
