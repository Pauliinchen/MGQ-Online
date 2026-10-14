#----------------------------------------------------------------
#  boot.rb
#
#  Changelog:
#      Paulinchen  2026-10-15: Wrapped the game's methods with alias_method instead of prepended modules
#                            - Took slashes in the game's Windows paths outside Windows
#                            - Discarded the folders the game or a mod makes
#                            - Loaded only MGQ Online and Mod Config Remake of the Patch folder for MGQ Online's battles
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

require "set"
require "stringio"
require "zlib"
require_relative "save_check"
# Everything defined after this point comes from the game or the RGSS stand-ins, which a save
# may hold; everything before is Ruby's own.
SaveCheck.snapshot
require_relative "compat"
require_relative "rgss"
require_relative "rpg"

# Loads the game's scripts and database without a screen, as Game.exe would before its title.
module Boot
  # The game folder, from BATTLE_GAME_DIR: its Data folder and the Patch folder of the mods that
  # change the game's rules, and nothing else, since a sandboxed battle sees only this folder.
  GAME_DIR = File.expand_path(ENV["BATTLE_GAME_DIR"] || "game")

  # The scripts left out: the exit handling hooks Windows' window and the last one starts the
  # title screen, which a server never shows.
  SKIPPED_SCRIPTS = ["▼ メイン【WF-RGSS】Exit-EX 終了処理", "×Main"].freeze

  # The folder of the game's mods, which Patch.rb loads.
  PATCH_DIR = "Patch"

  # What Patch.rb looks for in PATCH_DIR: every script, sorted.
  PATCH_SCRIPTS = "#{PATCH_DIR}/**/*.rb".freeze

  # The mods a server of MGQ Online's battles loads as it starts, MGQ Online itself and Mod Config
  # Remake, which it ships with; every other mod comes with the world of each battle (see
  # ServedMods), so a mod of the server's own never changes another world's battles.
  SERVED_BOOT_MODS = %r{\A#{PATCH_DIR}/(Multiplayer|Patch|\d*_?ModConfigRemake)\.rb\z}i

  # The saves' writers the server turns off: it never writes the game's saves, which belong to
  # the players.
  SAVE_WRITERS = %i[save_game auto_save_game save_system].freeze

  # The file methods the game and the mods call with paths.
  PATH_METHODS = %i[read binread open exist? file? directory? size mtime readlines foreach].freeze

  # The folder methods they call with paths.
  FOLDER_METHODS = %i[glob entries exist? children].freeze

  # Whether the server runs where a backslash separates no folders: the paths the game and the
  # mods build for Windows, such as MGQ Online's "Patch\\Multiplayer\\Scripts\\core_log.rbx", take
  # slashes there.
  SLASHES_ONLY = File::ALT_SEPARATOR.nil?

  # Wraps a method as the game's scripts and MGQ Online's hooks do, with alias_method: those alias
  # the methods they wrap at any time, which a prepended module would turn into a loop between the
  # two.
  module Wrap
    # The original methods kept, by owner and name.
    @originals = {}

    # Wraps a method in a block that decides when the original runs, once per wrapper's tag.
    #
    # @param owner [Module] The class, the singleton class for a module's method.
    # @param name [Symbol] The method.
    # @param tag [Symbol] The wrapper, which wraps the method once.
    # @yieldparam object [Object] The object the method runs on.
    # @yieldparam original [Proc] Runs the original with the arguments it is given.
    # @yieldparam args [Array] The arguments, their keywords last as a hash when there are any.
    # @yieldparam block [Proc, nil] The block.
    # @yieldreturn [Object] What the method returns.
    def self.around(owner, name, tag, &body)
      raise ArgumentError, "#{owner}##{name} is wrapped by #{tag} already" if @originals[[owner, name, tag]]

      original = :"boot_#{tag}_#{@originals.size + 1}_#{name.to_s.gsub(/[?!=]/, '_')}"
      was_private = owner.private_method_defined?(name)
      owner.send(:alias_method, original, name)
      owner.send(:define_method, name) do |*args, &block|
        body.call(self, ->(*given, **keywords, &inner) { send(original, *given, **keywords, &inner) }, args, block)
      end
      # Keywords such as encoding: reach the original as keywords, not as a hash.
      owner.send(:ruby2_keywords, name)
      owner.send(:private, name) if was_private
      @originals[[owner, name, tag]] = original
    end

    # Names the method a wrapper keeps the original under, which reaches past that wrapper.
    #
    # @param owner [Module] The class, the singleton class for a module's method.
    # @param name [Symbol] The method.
    # @param tag [Symbol] The wrapper.
    # @return [Symbol, nil] The original's name, nil while that wrapper does not wrap it.
    def self.original(owner, name, tag)
      @originals[[owner, name, tag]]
    end
  end

  class << self
    # What each failed script raised, by its index and name.
    attr_reader :failures

    # Loads every script in order, then the database.
    #
    # @param log [IO] Where the progress goes.
    # @return [Float] The seconds it took.
    def run(log = $stderr)
      started = clock
      Dir.chdir(GAME_DIR)
      $TEST = $BTEST = false
      @failures = []
      # From the first script on: the mods write their logs as they load.
      discard_writes
      take_slashes if SLASHES_ONLY
      keep_boot_mods(log) if served_game? && ENV["BATTLE_ALL_MODS"] != "1"
      @booting = true
      load_scripts(log)
      @booting = false
      log.puts(format("scripts: %.1f s, %d failed", clock - started, @failures.size))
      SAVE_WRITERS.each { |name| Wrap.around(DataManager.singleton_class, name, :no_saves) { true } }
      database_started = clock
      # The skipped exit handling's setup is where the game loads its database.
      DataManager.load_database
      DataManager.setup_system
      DataManager.init
      log.puts(format("database: %.1f s", clock - database_started))
      clock - started
    end

    # Tells whether File.open's mode writes.
    #
    # @param mode [String, Integer, Hash, nil] The mode, or keywords with one.
    # @return [Boolean] Whether it writes.
    def writing?(mode)
      mode = mode[:mode] if mode.is_a?(Hash)
      case mode
      when String then mode.match?(/[wa+]/)
      when Integer then (mode & (File::WRONLY | File::RDWR | File::CREAT | File::APPEND)).positive?
      else false
      end
    end

    # Tells whether the game folder holds MGQ Online, which makes the server one of its battles.
    #
    # @return [Boolean] Whether it does.
    def served_game?
      File.exist?(File.join(GAME_DIR, PATCH_DIR, "Multiplayer.rb"))
    end

    # Tells whether the game's scripts still load, as the server starts.
    #
    # @return [Boolean] Whether they do.
    def booting?
      @booting ? true : false
    end

    private

    # Leaves every mod but SERVED_BOOT_MODS out of the scripts Patch.rb loads as the server starts,
    # each one logged; BATTLE_ALL_MODS=1 loads them all, as for comparisons with the game.
    #
    # @param log [IO] Where the mods left out are named.
    def keep_boot_mods(log)
      Wrap.around(Dir.singleton_class, :glob, :boot_mods) do |_dir, original, args, block|
        found = original.call(*args, &block)
        next found unless Boot.booting? && args[0] == PATCH_SCRIPTS && found.is_a?(Array)

        kept, left = found.partition { |path| path.match?(SERVED_BOOT_MODS) }
        log.puts("left out of the start: #{left.join(', ')} (each world's battles bring their own mods)") unless left.empty?
        kept
      end
    end

    # Discards whatever the game or a mod writes, such as the temporary picture a large bitmap is
    # made from, errors.txt and the mods' logs, and makes no folder: a sandboxed battle may write
    # no file, and a write the game does not expect to fail would end the battle.
    def discard_writes
      Wrap.around(File.singleton_class, :open, :discard) do |_file, original, args, block|
        mode = args.size > 1 ? args[1] : nil
        keywords = args.size > 1 && args.last.is_a?(Hash) ? args.last : nil
        next original.call(*args, &block) unless Boot.writing?(mode) || Boot.writing?(keywords)

        io = StringIO.new(+"")
        block ? block.call(io) : io
      end
      %i[write binwrite].each do |name|
        Wrap.around(File.singleton_class, name, :discard) { |_file, _original, args, _block| args[1].to_s.bytesize }
      end
      Wrap.around(Dir.singleton_class, :mkdir, :discard) { 0 }
    end

    # Turns the backslashes of the paths the game and the mods name into slashes.
    def take_slashes
      [[File, PATH_METHODS], [Dir, FOLDER_METHODS]].each do |owner, names|
        names.each do |name|
          Wrap.around(owner.singleton_class, name, :slashes) do |_owner, original, args, block|
            original.call(*args.map { |arg| arg.is_a?(String) ? arg.tr("\\", "/") : arg }, &block)
          end
        end
      end
    end

    # Runs the game's scripts in order at the top level, as RGSS does, logging each failure and
    # going on with the next.
    #
    # @param log [IO] Where failures go.
    def load_scripts(log)
      Marshal.load(File.binread("Data/Scripts.rvdata2")).each_with_index do |(_, name, packed), index|
        name = name.to_s.force_encoding("UTF-8")
        next if SKIPPED_SCRIPTS.include?(name)

        code = Zlib::Inflate.inflate(packed).force_encoding("UTF-8")
        begin
          eval(code, TOPLEVEL_BINDING, format("%03d %s", index, name), 1)
        rescue ScriptError, StandardError => e
          @failures << [index, name, e]
          log.puts("script #{index} #{name}: #{e.class}: #{e.message.lines.first&.strip}")
          log.puts("  at #{e.backtrace&.first}")
        end
      end
    end

    # The time in seconds.
    #
    # @return [Float] The time.
    def clock
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
