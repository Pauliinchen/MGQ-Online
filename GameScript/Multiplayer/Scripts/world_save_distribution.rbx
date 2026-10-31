#----------------------------------------------------------------
#  world_save_distribution.rbx
#
#  Changelog:
#      Paulinchen  2026-10-31: Worded what the player reads plainly, leaving causes and internals to the log
#      Paulinchen  2026-10-30: Refused a fetched starting save that names classes other than the game's before loading it
#      Paulinchen  2026-10-23: Dropped the starting save's files as text, which the DLL takes as pairs
#                            - Left whether a new player is asked, warned or fetches the starting save to the DLL's steps into a world
#      Paulinchen  2026-10-14: Fetched a Raid World's starting save in every build
#      Paulinchen  2026-10-10: Fetched a Raid World's starting save in a development build
#      Paulinchen  2026-10-09: Neither asked a new player of a Raid World where to start nor fetched its starting save
#      Paulinchen  2026-10-07: Named the DLL's exports alone
#                            - Logged the save picked, the files placed, the fetch, its check and the files thrown away
#                            - Shortened the save screen's help texts
#      Paulinchen  2026-10-04: Renamed from mp_save_distribution.rbx
#      Paulinchen  2026-10-03: Logged through MGQ_MpLog
#      Paulinchen  2026-10-02: Let a new player of a world whose players choose start from one of their own saves
#      Paulinchen  2026-09-30: Moved into Patch/Multiplayer/Scripts as world_save_distribution.rbx
#                            - Created
#
#----------------------------------------------------------------

# A world's starting save: one of the creator's own saves, with their system save, which new
# players of the world start from instead of the opening. A new player's game fetches it from the
# relay into the world's folder before entering the world for the first time, where it is the
# world's first save. A world made with Player's choice instead asks each new player where to
# start: at the beginning, from one of their own saves, or from the starting save when it has one.
#
# Since a save can run code, world_screen.rbx asks a new player before fetching it.
module MGQ_MpSaveDistribution
  # The starting save's name in a world's folder: the world's first save.
  SAVE_NAME = "Save01.rvdata2"

  # The name of the starting save's thumbnail in a world's folder.
  THUMBNAIL_NAME = "Save01.png"

  # The name of the starting save's system save in a world's folder.
  SYSTEM_NAME = "SystemSave.rvdata2"

  # The system save the game keeps when it cannot say which of its two is newer.
  SYSTEM_FALLBACK = "Save/SystemSave.rvdata2"

  # What Marshal says when a save holds an object of a class the game lacks.
  MISSING_CLASS = /undefined class\/module (\S+)/

  # What the player reads when a fetched starting save names a class that is not the game's.
  REFUSED_TEXT = "The starting save could not be loaded."

  # What the save screen says, by what the save is chosen for: a new world's starting save, or
  # the player's own start in a world whose players choose.
  #
  # The save screen's help window has one line, which cuts off what does not fit.
  HELP_TEXTS = {
    :world => "Choose the save every new player starts from.",
    :own => "Choose the save you start the world from.",
  }

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "starting save"

  # Opens the save screen to pick a save.
  #
  # @param purpose [Symbol] What the save is for, a key of HELP_TEXTS.
  def self.choose(purpose)
    @chosen = nil
    @purpose = purpose
    log("opening the save screen: #{help}")
    SceneManager.call(Scene_MpStartSave)
  end

  # Tells what the save screen says.
  #
  # @return [String] The text.
  def self.help
    HELP_TEXTS[@purpose]
  end

  # Keeps the save the player picked.
  #
  # @param index [Integer] The save's index, as DataManager takes it.
  def self.chosen=(index)
    @chosen = index
    log("picked #{MGQ_MpWorld.save_name(index)} (#{@purpose})")
  end

  # Hands out what the save screen was opened for and the save the player picked, once.
  #
  # @return [Array] The purpose, nil when the save screen was not opened; and the save's index,
  #   nil when the player left it without one.
  def self.take_chosen
    taken = [@purpose, @chosen]
    @purpose = @chosen = nil
    taken
  end

  # Lists the files a starting save is made of: the save, its thumbnail when it has one, and the
  # player's newest system save, each under the name a new player gets it by.
  #
  # @param index [Integer] The save's index, as DataManager takes it.
  # @return [Array<Array<String>>] Each file's name in the world's folder and its path in the game's folder.
  def self.files_of(index)
    DataManager.save_system
    files = [[SAVE_NAME, DataManager.make_filename(index)]]
    thumbnail = DataManager.respond_to?(:make_thumbnailname) ? DataManager.make_thumbnailname(index) : nil
    files.push([THUMBNAIL_NAME, thumbnail]) if thumbnail && File.exist?(thumbnail)
    system = newest_system_save
    files.push([SYSTEM_NAME, system]) if File.exist?(system)
    log("the starting save of #{MGQ_MpWorld.save_name(index)} is #{files.map { |name, path| "#{path} as #{name}" }.join(', ')}")
    files
  end

  # Finds the player's newest system save, since the game takes turns writing two.
  #
  # @return [String] Its path in the game's folder.
  def self.newest_system_save
    defined?(SaveSystemData) && SaveSystemData.respond_to?(:load_filename) ? SaveSystemData.load_filename : SYSTEM_FALLBACK
  rescue
    SYSTEM_FALLBACK
  end

  # Copies the starting save into the creator's own folder of the new world, so the creator
  # starts from it too without fetching it back.
  #
  # @param world [MGQ_MpWorld::World] The world on this PC.
  # @param files [Array<Array<String>>] Each file's name in the world's folder and its path in the game's folder.
  # @return [Boolean] Whether every file was copied.
  def self.place(world, files)
    Dir.mkdir(world.save_folder) unless File.directory?(world.save_folder)
    files.each do |name, path|
      bytes = File.open(path, "rb") { |file| file.read }
      File.open("#{world.save_folder}/#{name}", "wb") { |file| file.write(bytes) }
    end
    log("placed the starting save in world #{world.id} (#{world.name}): #{files.map { |name, path| "#{path} as #{name}" }.join(', ')}")
    true
  rescue => e
    log("could not place the starting save: #{e.class}: #{e.message}")
    false
  end

  # Checks that this game can load a fetched starting save, and throws it away when it cannot, so
  # the next entry fetches it again, after the missing mod was installed perhaps.
  #
  # Loading the system save quits the game when it fails, so it is checked before the world opens.
  #
  # @param world [MGQ_MpWorld::World] The world on this PC.
  # @return [String, nil] Why it cannot be loaded, nil when it can.
  def self.check(world)
    paths = [SAVE_NAME, SYSTEM_NAME].map { |name| "#{world.save_folder}/#{name}" }.select { |path| File.exist?(path) }
    # Both files pass the class check before Marshal reads either.
    paths.each { |path| ClassCheck.new(File.open(path, "rb") { |file| file.read }).check }
    paths.each { |path| File.open(path, "rb") { |file| Marshal.load(file) until file.eof? } }
    log("the starting save of world #{world.id} loads in this game")
    nil
  rescue ClassCheck::Refused => e
    log("the starting save of world #{world.id} was refused: #{e.message}")
    discard(world)
    REFUSED_TEXT
  rescue => e
    log("the starting save of world #{world.id} cannot be loaded: #{e.class}: #{e.message}")
    discard(world)
    missing = e.message[MISSING_CLASS, 1]
    missing ? "The starting save needs a mod you do not have." : "The starting save could not be loaded."
  end

  # Deletes a fetched starting save's files from a world's folder.
  #
  # @param world [MGQ_MpWorld::World] The world on this PC.
  def self.discard(world)
    deleted = [SAVE_NAME, THUMBNAIL_NAME, SYSTEM_NAME].select do |name|
      path = "#{world.save_folder}/#{name}"
      File.exist?(path) && File.delete(path)
    end
    log("threw away the starting save of world #{world.id}: #{deleted.empty? ? 'no files there' : deleted.join(', ')}")
  rescue => e
    log("could not delete the starting save: #{e.class}: #{e.message}")
  end

  # Walks Marshal streams without building anything and refuses one that names a class of Ruby's
  # own, so a starting save from another player cannot make the objects Marshal.load runs code of.
  # It follows the battle server's SaveCheck entry for entry; save_distribution_test.rb holds the
  # two to the same verdicts.
  #
  # The game's Ruby (1.9.2) has no byteslice, and the client cannot note Ruby's own classes before
  # the game's scripts load, as the server does, so RUBY_OWN names them.
  class ClassCheck
    # Raised for a stream that is not Marshal or names a class that is not the game's.
    class Refused < StandardError; end

    # The Marshal version every stream starts with.
    VERSION = "\x04\x08"

    # How deep objects may nest; the game's saves stay far below.
    MAX_DEPTH = 500

    # Ruby's own classes a save may hold: plain values without code of their own.
    CORE = %w[Object String Array Hash Range Float Integer Symbol Time Regexp Rational Complex]

    # The outermost names of Ruby's own classes and modules, those of its libraries and those of
    # the game's Ruby included; a save may name none of them, nor anything inside them.
    RUBY_OWN = %w[
      ArgumentError Array BasicObject Bignum Binding Class ClosedQueueError Comparable Complex
      ConditionVariable Continuation Data Dir EOFError Encoding EncodingError Enumerable Enumerator
      Errno Exception FalseClass Fiber FiberError File FileTest Fixnum Float FloatDomainError
      FrozenError GC Hash IO IOError IndexError Integer Interrupt Kernel KeyError LoadError
      LocalJumpError Marshal MatchData Math Method Module Mutex NameError NilClass
      NoMatchingPatternError NoMatchingPatternKeyError NoMemoryError NoMethodError
      NotImplementedError Numeric Object ObjectSpace Proc Process Queue Ractor Random Range
      RangeError Rational Refinement Regexp RegexpError RubyVM RuntimeError ScriptError
      SecurityError Set Signal SignalException SizedQueue StandardError StopIteration String Struct
      Symbol SyntaxError SystemCallError SystemExit SystemStackError Thread ThreadError ThreadGroup
      Time TracePoint TrueClass TypeError UnboundMethod UncaughtThrowError UnicodeNormalize Warning
      ZeroDivisionError
      BasicSocket BigDecimal Bundler CGI CSV DRb Date DateTime Delegator DidYouMean Digest DL ERB
      Etc Fiddle FileUtils Gem IPAddr JSON Logger Monitor MonitorMixin Net OpenSSL OpenStruct
      Pathname Psych REXML Ripper SimpleDelegator Socket SortedSet StringIO Syck Tempfile URI
      WIN32OLE Win32 Win32API YAML Zlib
    ]

    # A class name the game's scripts can define: constants only.
    CLASS_NAME = /\A[A-Z]\w*(::[A-Z]\w*)*\z/

    # Starts a check of a byte stream.
    #
    # @param bytes [String] One or more Marshal streams one after another, as a save file is.
    def initialize(bytes)
      @bytes = bytes.dup.force_encoding("ASCII-8BIT")
      @pos = 0
    end

    # Walks every stream in the bytes and refuses one that names a class that is not the game's or
    # uses a kind of entry no save needs.
    #
    # @return [ClassCheck] The check.
    def check
      until @pos >= @bytes.bytesize
        refuse("not a Marshal stream") unless @bytes[@pos, 2] == VERSION
        @pos += 2
        @symbols = []
        entry(0)
      end
      self
    end

    # Tells whether a save may name a class: a plain value of Ruby's, or any name outside Ruby's
    # own, which Marshal.load refuses by itself when the game lacks it.
    #
    # @param name [String] The class's name.
    # @return [Boolean] Whether it may.
    def self.admitted?(name)
      CORE.include?(name) || (name =~ CLASS_NAME && !RUBY_OWN.include?(name.split("::").first)) ? true : false
    end

    private

    # Reads one entry and everything inside it.
    #
    # @param depth [Integer] How deep it nests.
    def entry(depth)
      refuse("nested too deep") if depth > MAX_DEPTH
      type = byte.chr
      case type
      when "0", "T", "F" then nil
      when "i" then long
      when ":" then @symbols << bytes
      when ";" then symbol_at(long)
      when "@" then long
      when "I"
        entry(depth + 1)
        long.times { symbol; entry(depth + 1) }
      when "e"
        admit(symbol, "extended by")
        entry(depth + 1)
      when "[" then long.times { entry(depth + 1) }
      when "l"
        byte
        shorts = long
        refuse("a length past the end") if shorts < 0 || @pos + shorts * 2 > @bytes.bytesize
        @pos += shorts * 2
      when "c", "m", "M" then admit(bytes, "class reference")
      when "f", '"' then bytes
      when "/"
        bytes
        byte
      when "{", "}"
        (long * 2).times { entry(depth + 1) }
        entry(depth + 1) if type == "}"
      when "S", "o"
        admit(symbol, type == "S" ? "struct" : "object")
        long.times { symbol; entry(depth + 1) }
      when "C"
        admit(symbol, "subclass")
        entry(depth + 1)
      when "u"
        admit(symbol, "_load")
        bytes
      when "U"
        admit(symbol, "marshal_load")
        entry(depth + 1)
      else
        refuse("an entry of kind #{type.inspect}, which no save holds")
      end
    end

    # Refuses a class that is not the game's.
    #
    # @param name [String] The class's name.
    # @param kind [String] What the stream does with it.
    def admit(name, kind)
      name = name.dup.force_encoding("UTF-8")
      refuse("#{kind} of #{name}, which is not the game's") unless ClassCheck.admitted?(name)
    end

    # Reads a symbol or a link to an earlier one.
    #
    # @return [String] The symbol's name.
    def symbol
      case byte.chr
      when ":" then bytes.tap { |name| @symbols << name }
      when ";" then symbol_at(long)
      else refuse("a symbol where one belongs")
      end
    end

    # An earlier symbol by its index.
    #
    # @param index [Integer] The index.
    # @return [String] The symbol's name.
    def symbol_at(index)
      @symbols[index] || refuse("a link to symbol #{index}, which does not exist")
    end

    # Reads a length and that many bytes.
    #
    # @return [String] The bytes.
    def bytes
      length = long
      refuse("a length past the end") if length < 0 || @pos + length > @bytes.bytesize
      @bytes[@pos, length].tap { @pos += length }
    end

    # Reads one of Marshal's packed integers.
    #
    # @return [Integer] The integer.
    def long
      first = byte
      first -= 256 if first > 127
      return 0 if first == 0
      return first - 5 if first > 4
      return first + 5 if first < -4

      count = first.abs
      value = 0
      count.times { |i| value |= byte << (8 * i) }
      first < 0 ? value - (1 << (8 * count)) : value
    end

    # Reads one byte.
    #
    # @return [Integer] The byte.
    def byte
      refuse("the stream ends early") if @pos >= @bytes.bytesize
      @bytes.getbyte(@pos).tap { @pos += 1 }
    end

    # Refuses the save.
    #
    # @param reason [String] Why.
    def refuse(reason)
      raise Refused, "the save was refused: #{reason} (at byte #{@pos})"
    end
  end
end

# The save screen, opened from the world screen to pick a new world's starting save or a player's
# own start in a world: the game's own list of saves, whose choice is handed back instead of loaded.
class Scene_MpStartSave < Scene_Load
  # Tells what the list is for.
  #
  # @return [String] The text.
  def help_window_text
    MGQ_MpSaveDistribution.help
  end

  # Hands the chosen save back to the world screen, if there is a save in that slot.
  def on_savefile_ok
    unless File.exist?(DataManager.make_filename(@index))
      MGQ_MpSaveDistribution.log("save slot #{@index + 1} is empty, not taken")
      Sound.play_buzzer
      return
    end

    Sound.play_ok
    MGQ_MpSaveDistribution.chosen = @index
    return_scene
  end
end
