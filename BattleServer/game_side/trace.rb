#----------------------------------------------------------------
#  trace.rb
#
#  Changelog:
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

# Records every random draw of a compared battle: its kind, the script line and method that
# drew it, and the value, so the server's draws can be held against the game's. Test only, in
# Ruby 1.9 for RGSS3.
module RngTrace
  @lines = nil
  @depth = 0

  class << self
    # The draws so far, or nil while not recording.
    attr_accessor :lines

    # Notes a draw, unless it happens inside another noted draw.
    #
    # @param kind [String] What drew it.
    # @param value [Object] What it gave.
    def note(kind, value)
      return unless @lines && @depth.zero?

      where = caller(2)[0].to_s[/:(\d+):in `([^']+)'/] ? "#{$1} #{$2}" : caller(2)[0].to_s
      @lines << "#{kind} #{where} #{text(value)[0, 60]}"
    end

    # A value as both Rubies write it: floats with 12 decimals.
    #
    # @param value [Object] The value.
    # @return [String] The text.
    def text(value)
      case value
      when Float then format("%.12f", value)
      when Array then "[#{value.map { |item| text(item) }.join(",")}]"
      when nil then "-"
      else value.class.name =~ /\AGame_|\ARPG::/ ? (value.respond_to?(:name) ? value.name.to_s : value.class.name) : value.to_s
      end
    end

    # Runs a block whose own draws are not noted.
    def quiet
      @depth += 1
      yield
    ensure
      @depth -= 1
    end
  end
end

module Kernel
  alias rng_trace_rand rand
  alias rng_trace_srand srand

  # Draws, and notes it.
  def rand(*args)
    value = RngTrace.quiet { rng_trace_rand(*args) }
    RngTrace.note("rand(#{args.join(",")})", value)
    value
  end

  # Seeds, and notes it.
  def srand(*args)
    value = rng_trace_srand(*args)
    RngTrace.note("srand(#{args.join(",")})", nil)
    value
  end
end

class << Kernel
  alias rng_trace_rand rand

  # Draws, and notes it.
  def rand(*args)
    value = RngTrace.quiet { rng_trace_rand(*args) }
    RngTrace.note("rand(#{args.join(",")})", value)
    value
  end
end

class << Random
  alias rng_trace_rand rand

  # Draws, and notes it.
  def rand(*args)
    value = RngTrace.quiet { rng_trace_rand(*args) }
    RngTrace.note("rand(#{args.join(",")})", value)
    value
  end

  alias rng_trace_new new

  # Makes a generator of its own, and notes it: it draws apart from srand.
  def new(*args)
    RngTrace.note("Random.new(#{args.join(",")})", nil)
    rng_trace_new(*args)
  end
end

class Array
  alias rng_trace_sample sample
  alias rng_trace_shuffle shuffle
  alias rng_trace_shuffle! shuffle!

  # Picks at random, and notes it.
  def sample(*args)
    value = RngTrace.quiet { rng_trace_sample(*args) }
    RngTrace.note("sample(#{args.join(",")}) of #{size}", value)
    value
  end

  # Shuffles, and notes it.
  def shuffle(*args)
    value = RngTrace.quiet { rng_trace_shuffle(*args) }
    RngTrace.note("shuffle of #{size}", value)
    value
  end

  # Shuffles in place, and notes it.
  def shuffle!(*args)
    value = RngTrace.quiet { rng_trace_shuffle!(*args) }
    RngTrace.note("shuffle! of #{size}", value)
    value
  end
end

module CompareBattle
  class << self
    alias rng_trace_start start
    alias rng_trace_finish finish

    # Starts a battle, recording its draws from here.
    def start(*args)
      RngTrace.lines = []
      rng_trace_start(*args)
    end

    # Ends a battle, writing its draws beside its log.
    def finish(result)
      written = @battle && @battle[:written]
      rng_trace_finish(result)
      return if written || !RngTrace.lines

      File.open("TestDriver/out/trace_#{@battle[:name]}.txt", "wb") { |file| file.write(RngTrace.lines.join("\n")) }
      RngTrace.lines = nil
    end
  end
end

"trace installed"
