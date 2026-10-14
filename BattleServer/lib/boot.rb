#----------------------------------------------------------------
#  boot.rb
#
#  Changelog:
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

  # DataManager's change: the server never writes the game's saves, which belong to the players.
  module NoSaves
    # Skips the save.
    #
    # @return [Boolean] Always true, as a save that worked.
    def save_game(*)
      true
    end

    # Skips the autosave.
    #
    # @return [Boolean] Always true, as a save that worked.
    def auto_save_game(*)
      true
    end

    # Skips the system save.
    #
    # @return [Boolean] Always true, as a save that worked.
    def save_system(*)
      true
    end
  end

  # File's change: whatever the game or a mod writes is discarded, such as the temporary picture
  # a large bitmap is made from, errors.txt and the mods' logs. A sandboxed battle may write no
  # file, and a write the game does not expect to fail would end the battle.
  module DiscardWrites
    # Opens a file, or a discarding stand-in when it would be written.
    #
    # @return [IO, StringIO, Object] The file, the stand-in, or what the block returns.
    def open(path, mode = "r", *rest, **options, &block)
      return super unless DiscardWrites.writing?(options[:mode] || mode)

      io = StringIO.new(+"")
      block ? block.call(io) : io
    end

    # Discards a whole file's writing.
    #
    # @return [Integer] The bytes it would have written.
    def write(_path, data, *_rest, **_options)
      data.to_s.bytesize
    end

    # Discards a whole file's writing.
    #
    # @return [Integer] The bytes it would have written.
    def binwrite(_path, data, *_rest, **_options)
      data.to_s.bytesize
    end

    # Tells whether a mode opens a file for writing.
    #
    # @param mode [String, Integer] The mode, as File.open takes it.
    # @return [Boolean] Whether it writes.
    def self.writing?(mode)
      case mode
      when String then mode.match?(/[wa+]/)
      when Integer then (mode & (File::WRONLY | File::RDWR | File::CREAT | File::APPEND)).positive?
      else false
      end
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
      load_scripts(log)
      log.puts(format("scripts: %.1f s, %d failed", clock - started, @failures.size))
      DataManager.singleton_class.prepend(NoSaves)
      File.singleton_class.prepend(DiscardWrites)
      database_started = clock
      # The skipped exit handling's setup is where the game loads its database.
      DataManager.load_database
      DataManager.setup_system
      DataManager.init
      log.puts(format("database: %.1f s", clock - database_started))
      clock - started
    end

    private

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
