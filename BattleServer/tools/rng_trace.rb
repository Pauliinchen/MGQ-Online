#----------------------------------------------------------------
#  rng_trace.rb
#
#  Changelog:
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

# Records every random draw of a battle as the game's TestDriver/trace.rb records it: its kind,
# the script line and method that drew it, and the value. Required by compare.rb with TRACE=1.
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

      frame = caller(2, 1)[0].to_s
      where = frame =~ /:(\d+):in [`']([^']+)'/ ? "#{$1} #{$2.split(/[#.]/).last}" : frame
      @lines << "#{kind} #{where} #{text(value)[0, 60]}"
    end

    # Runs a block whose own draws are not noted.
    def quiet
      @depth += 1
      yield
    ensure
      @depth -= 1
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
  end

  # Kernel's draws, noted.
  module KernelDraws
    # Draws, and notes it.
    def rand(*args)
      value = RngTrace.quiet { super }
      RngTrace.note("rand(#{args.join(",")})", value)
      value
    end

    # Seeds, and notes it.
    def srand(*args)
      value = super
      RngTrace.note("srand(#{args.join(",")})", nil)
      value
    end
  end

  # Random's draws, noted.
  module RandomDraws
    # Draws, and notes it.
    def rand(*args)
      value = RngTrace.quiet { super }
      RngTrace.note("rand(#{args.join(",")})", value)
      value
    end

    # Makes a generator of its own, and notes it: it draws apart from srand.
    def new(*args)
      RngTrace.note("Random.new(#{args.join(",")})", nil)
      super
    end
  end

  # Array's draws, noted.
  module ArrayDraws
    # Picks at random, and notes it.
    def sample(*args)
      value = RngTrace.quiet { super }
      RngTrace.note("sample(#{args.join(",")}) of #{size}", value)
      value
    end

    # Shuffles, and notes it.
    def shuffle(*args)
      value = RngTrace.quiet { super }
      RngTrace.note("shuffle of #{size}", value)
      value
    end

    # Shuffles in place, and notes it.
    def shuffle!(*args)
      value = RngTrace.quiet { super }
      RngTrace.note("shuffle! of #{size}", value)
      value
    end
  end

  # Puts the recording in place.
  def self.install
    Kernel.prepend(KernelDraws)
    Kernel.singleton_class.prepend(KernelDraws)
    Random.singleton_class.prepend(RandomDraws)
    Array.prepend(ArrayDraws)
  end
end
