#----------------------------------------------------------------
#  pages_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Answered at the bridge's frame, the scripts' clock
#      Paulinchen  2026-10-28: Told how long a page that holds holds by time alone
#                            - Created
#
#----------------------------------------------------------------

# The DLL's side of a story's pages (MGQOnline.Game's Telling/StoryPages, behind PageTopics) for
# the script tests: PagesStandIn names, tells and keeps a teller's pages and keeps, shows and holds
# a viewer's as the DLL does, by the frame the tests count; pages_fixtures_test.rb checks it against
# the golden cases of fixtures/pages/cases.json, played as coop_events.rbx played them before the
# rules left it.

require_relative "rules_support"

# The golden cases of a story's pages.
PAGE_CASES = rule_cases("pages", "cases.json")

# Stands in for the pages of a story, each topic's request in, its reply out, at a frame.
class PagesStandIn
  FRAMES = PAGE_CASES["frames"]
  SKIP_SEND_FRAMES = FRAMES["skip_send"]
  READ_FRAMES = FRAMES["read"]
  READ_FRAMES_PER_CHARACTER = FRAMES["read_per_character"]
  MOST_READ_FRAMES = FRAMES["most_read"]
  STALE_FRAMES = FRAMES["stale"]
  MAX_HEARD = PAGE_CASES["max_heard"]
  MAX_DONE = PAGE_CASES["max_done"]
  CATCH_UP_PAGES = PAGE_CASES["catch_up_pages"]

  # Makes a stand-in with no page.
  #
  # @param session [String] The teller's session id, which page ids start with.
  def initialize(session = "sess01")
    @session = session
    @page = 0
    @shown = nil
    @kept = nil
    @skipped = 0
    @told_at = nil
    @told_page = nil
    @heard = []
    @done = []
    @mirrored = nil
  end

  # Tells how many pages heard wait.
  #
  # @return [Integer] The count.
  def waiting
    @heard.size
  end

  # Names the pages heard that wait, the oldest first.
  #
  # @return [Array<String>] Their ids.
  def waiting_ids
    @heard.map { |page| page[:id] }
  end

  # Tells whether the viewer's window holds a page.
  #
  # @return [Boolean] Whether it does.
  def mirroring?
    !@mirrored.nil?
  end

  # Answers a topic.
  #
  # @param topic [String] The topic, such as "pages.show".
  # @param request [Object] The request as the scripts hand it over.
  # @param frame [Integer] The frame now.
  # @return [Object] The reply.
  def answer(topic, request, frame)
    case topic
    when "pages.show" then show(request, frame)
    when "pages.passed" then passed
    when "pages.flush" then flush(request, frame)
    when "pages.telling_starts" then (@told_at = @told_page = nil unless @kept); nil
    when "pages.hear" then hear(request)
    when "pages.done" then @done << request["page"].to_s; @done.shift while @done.size > MAX_DONE; nil
    when "pages.forget" then count = @heard.size; @heard = []; @done = []; count
    when "pages.next" then next_page(request, frame)
    when "pages.over" then over(request, frame)
    when "pages.ended" then page = @mirrored && @mirrored[:id]; @mirrored = nil; page
    else raise "no stand-in for #{topic}"
    end
  end

  # Takes a page the teller's story shows.
  #
  # @param request [Hash] The page and "skip".
  # @param frame [Integer] The frame now.
  # @return [Hash, nil] The page, nil for an empty one or the one shown.
  def show(request, frame)
    page = [request["lines"], request["choices"]]
    return nil if page == [[], []] || page == @shown

    @shown = page
    @page += 1
    @skipped += 1 if @kept
    @kept = nil
    told = told_of(request)
    if request["skip"] && @told_at && !past?(@told_at, SKIP_SEND_FRAMES, frame)
      @kept = told.merge("passed" => false)
      return told.merge("told" => false)
    end

    told.merge("told" => true, "skipped" => tell(told["id"], frame))
  end

  # Takes that the teller moved past the page shown.
  #
  # @return [String, nil] The page whose end goes out now.
  def passed
    return nil unless @shown

    @shown = nil
    id = "#{@session}.#{@page}"
    if @kept && @kept["id"] == id
      @kept["passed"] = true
      return nil
    end
    return nil unless @told_page == id

    @told_page = nil
    id
  end

  # Tells the page kept once due.
  #
  # @param request [Hash] "skip", "telling" and "map".
  # @param frame [Integer] The frame now.
  # @return [Hash, nil] The page, nil for none.
  def flush(request, frame)
    return nil unless @kept
    return nil if request["skip"] && request["telling"] && request["map"] && @told_at && !past?(@told_at, SKIP_SEND_FRAMES, frame)

    kept = @kept
    @kept = nil
    skipped = tell(kept["id"], frame)
    @told_page = nil if kept["passed"]
    kept.merge("skipped" => skipped)
  end

  # Keeps a page heard.
  #
  # @param request [Hash] The page's fields and "name".
  # @return [Hash] What was kept, or why not.
  def hear(request)
    lines = decode(request["lines"])
    choices = decode(request["choices"])
    return { "refused" => "its lines do not read" } unless lines && choices

    lines += ["#{request['name']} chooses: #{choices.join(' / ')}"] unless choices.empty?
    return { "refused" => "no text" } if lines.empty?

    @heard << { :id => request["page"].to_s, :face => request["face"].to_s, :index => request["index"].to_i, :background => request["background"].to_i,
                :position => request["position"].to_i, :lines => lines }
    dropped = 0
    (@heard.shift; dropped += 1) while @heard.size > MAX_HEARD
    { "lines" => lines.size, "choices" => choices.size, "waiting" => @heard.size, "dropped" => dropped }
  end

  # Shows the next page heard.
  #
  # @param request [Hash] "giving_way" and "sharing".
  # @param frame [Integer] The frame now.
  # @return [Hash, nil] What happened, nil while none waits.
  def next_page(request, frame)
    return nil if @heard.empty?

    answer = { "show" => nil, "skipped" => [], "passed" => [], "dropped" => 0 }
    if request["giving_way"]
      answer["passed"] = @heard.select { |page| @done.include?(page[:id]) }.map { |page| page[:id] }
      @heard.reject! { |page| answer["passed"].include?(page[:id]) }
    elsif !request["sharing"]
      answer["dropped"] = @heard.size
      @heard = []
    else
      answer["skipped"] << @heard.shift[:id] while @heard.size > CATCH_UP_PAGES && @done.include?(@heard.first[:id])
      unless @heard.empty?
        page = @heard.shift
        @mirrored = { :id => page[:id], :since => frame, :read => reading_frames(page[:lines]), :over => false }
        answer["show"] = { "page" => page[:id], "face" => page[:face], "index" => page[:index], "background" => page[:background],
                           "position" => page[:position], "lines" => page[:lines] }
      end
    end
    answer.merge("waiting" => @heard.size)
  end

  # Tells whether the page the window holds is over.
  #
  # @param request [Hash] "teller", "telling", "raid", "giving_way", "confirm" and "skip".
  # @param frame [Integer] The frame now.
  # @return [Hash] "over", "reason" and "wait".
  def over(request, frame)
    return { "over" => true, "reason" => nil } unless @mirrored

    wait = nil
    reason =
      if @done.include?(@mirrored[:id])
        reason = if request["giving_way"] then "#{request['giving_way']} waits for the player"
                 elsif @heard.size > CATCH_UP_PAGES then "#{@heard.size} more pages wait"
                 elsif past?(@mirrored[:since], @mirrored[:read], frame) then "the player read it"
                 elsif request["confirm"] then "the player read on"
                 elsif request["skip"] then "the player skips"
                 end
        wait = @mirrored[:read] - (frame - @mirrored[:since]) unless reason
        reason && "the leader moved past it and #{reason}"
      elsif request["teller"].nil? then "the teller is no longer the player's leader"
      elsif request["telling"] then nil
      elsif request["raid"] then "the relay ended the teller's telling"
      elsif past?(@mirrored[:since], STALE_FRAMES, frame) then "the leader stopped telling the story #{STALE_FRAMES} frames ago"
      else wait = STALE_FRAMES - (frame - @mirrored[:since]); nil
      end
    return { "over" => false, "reason" => nil, "wait" => wait } unless reason

    first = !@mirrored[:over]
    @mirrored[:over] = true
    { "over" => true, "reason" => first ? reason : nil }
  end

  # Tells how long a page stays at least once the teller moved past it.
  #
  # @param lines [Array<String>] The lines.
  # @return [Integer] The frames.
  def reading_frames(lines)
    [READ_FRAMES + lines.join.size * READ_FRAMES_PER_CHARACTER, MOST_READ_FRAMES].min
  end

  private

  # Writes a page told: its id, fields and note.
  #
  # @param request [Hash] The page.
  # @return [Hash] "id", "fields" and "note".
  def told_of(request)
    id = "#{@session}.#{@page}"
    { "id" => id, "skipped" => 0, "note" => "#{request['lines'].size} lines",
      "fields" => { "page" => id, "face" => request["face"], "index" => request["index"], "background" => request["background"], "position" => request["position"],
                    "lines" => encode(request["lines"]), "choices" => encode(request["choices"]) } }
  end

  # Notes a page told now.
  #
  # @param id [String] The page.
  # @param frame [Integer] The frame now.
  # @return [Integer] The pages kept and replaced since the last page told.
  def tell(id, frame)
    skipped = @skipped
    @skipped = 0
    @told_at = frame
    @told_page = id
    skipped
  end

  # Reports whether some frames passed since a frame.
  #
  # @param since [Integer] The frame.
  # @param frames [Integer] The frames.
  # @param frame [Integer] The frame now.
  # @return [Boolean] Whether they did.
  def past?(since, frames, frame)
    elapsed = frame - since
    elapsed < 0 || elapsed >= frames
  end

  # Writes lines as the wire takes them.
  #
  # @param lines [Array<String>] The lines.
  # @return [String] Each in Base64, joined by commas.
  def encode(lines)
    lines.map { |line| [line].pack("m0") }.join(",")
  end

  # Reads lines off the wire.
  #
  # @param text [String, nil] Each line in Base64, joined by commas.
  # @return [Array<String>, nil] The lines, nil when one does not read.
  def decode(text)
    text.to_s.split(",").map { |line| line.unpack("m0")[0].force_encoding("UTF-8") }
  rescue ArgumentError
    nil
  end
end

# Answers the topics of a story's pages on a FakeBridge with a PagesStandIn, $pages_stand_in, at the
# frame the tests count, the bridge's.
#
# @param fake [FakeBridge] The bridge.
def answer_pages(fake)
  $pages_stand_in = PagesStandIn.new
  %w(show passed flush telling_starts hear done forget next over ended).each do |name|
    fake.answer("pages.#{name}") { |request| $pages_stand_in.answer("pages.#{name}", request, MGQ_Multiplayer::Bridge.frame_number) }
  end
end

# Reads a line of a page as the wire carries it.
#
# @param text [String] The line in Base64.
# @return [String] The line.
def page_line(text)
  text.to_s.unpack("m0")[0].force_encoding("UTF-8")
end
