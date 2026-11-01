#----------------------------------------------------------------
#  chat_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-01: Created
#
#----------------------------------------------------------------

# The DLL's chat model on a FakeBridge, as far as the scripts' tests need it: it notes every call of
# the chat's topics and answers a view, which opens the box on chat.open, closes it on chat.close
# and chat.enter, keeps what chat.typed hands over and moves the pick by chat.pick. Its rules are
# MGQOnline.Game.Tests'.
class FakeChat
  # The topics the scripts call.
  TOPICS = %w[chat.open chat.close chat.typed chat.enter chat.alt chat.pick chat.take_pick chat.tab chat.whisper chat.game_line chat.scene]

  # The view of a chat that holds no line, its box closed.
  CLOSED = { "channel" => "global", "tab" => "all", "tabs" => %w[all global map party], "unread" => [], "whisper_to" => nil, "reply_to" => nil,
             "box" => nil, "suggestions" => [], "pick" => 0, "lines" => [], "bubbles" => {} }

  # @return [Array<Array>] Each call as [topic, request], oldest first.
  attr_reader :calls

  # @return [Hash] The view it answers next.
  attr_accessor :view

  # Answers the chat's topics on a bridge.
  #
  # @param fake [FakeBridge] The bridge.
  def initialize(fake)
    @fake = fake
    @calls = []
    @view = CLOSED.dup
    TOPICS.each { |topic| fake.answer(topic) { |request| answer(topic, request) } }
  end

  # Tells the calls of one topic.
  #
  # @param topic [String] The topic.
  # @return [Array] Their requests, oldest first.
  def requests(topic)
    @calls.select { |called, _| called == topic }.map { |_, request| request }
  end

  # Posts a view as the chat's frame does once it changed.
  #
  # @param changes [Hash] What differs from the view it holds.
  def post(changes)
    @view = @view.merge(changes)
    @fake.post("chat.view", @view)
  end

  private

  # Answers a call with the view, opening, closing, typing into the box or moving the pick first.
  #
  # @param topic [String] The topic.
  # @param request [Object] What the call hands over.
  # @return [Hash, nil] The view, nil for the scene's staging.
  def answer(topic, request)
    @calls << [topic, request] unless topic == "chat.scene"
    case topic
    when "chat.scene" then return nil
    when "chat.open" then @view = @view.merge("box" => ["", 0, false])
    when "chat.close", "chat.enter" then @view = @view.merge("box" => nil)
    when "chat.typed" then @view = @view.merge("box" => [request["text"], request["cursor"], false])
    when "chat.pick" then @view = @view.merge("pick" => (@view["pick"].to_i + request.to_i) % [Array(@view["suggestions"]).size, 1].max)
    end
    @view
  end
end
