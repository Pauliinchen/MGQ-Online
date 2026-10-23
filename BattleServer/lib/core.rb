#----------------------------------------------------------------
#  core.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Kept why the core is missing, for the battles the server refuses without it
#                            - Created
#
#----------------------------------------------------------------

# MGQOnline.ServerCore, MGQ Online's C# core on the battle server: a native library MGQ Online's
# bridge reaches through Fiddle (MGQ_Multiplayer::Bridge::FiddleBackend), named by
# BATTLE_CORE_LIBRARY. Where battles run in forked children, each child loads it after the fork
# and before its sandbox and shakes hands after the sandbox closed; nothing calls it before a
# fork, since a child of a process whose core already ran hangs at its first garbage collection.
#
# MGQ Online's scripts ask the core for rules they share with the game, such as the squad math and
# the ids they make up, so the server refuses MGQ Online's battles without it (see ready?).
module Core
  # The environment setting that names the library's path.
  LIBRARY_SETTING = "BATTLE_CORE_LIBRARY"

  # The topic of the core's log lines, which the drain hands over as events.
  LOG_TOPIC = "log"

  # What the server says once it starts without the core.
  REFUSING = "the server refuses MGQ Online's battles"

  class << self
    # The library the environment names, checked once as the server starts and logged: a library
    # that is not there counts as none.
    #
    # @param log [IO] Where the server's log goes.
    # @param env [Hash] The environment.
    # @return [String, nil] The library's full path, nil for none.
    def library(log = $stderr, env = ENV)
      path = env[LIBRARY_SETTING].to_s
      return missing(log, "no core library (#{LIBRARY_SETTING} is not set)", false) if path.empty?

      path = File.expand_path(path)
      return missing(log, "the core library #{path} (#{LIBRARY_SETTING}) does not exist") unless File.file?(path)
      unless defined?(MGQ_Multiplayer::Bridge::FiddleBackend)
        return missing(log, "the game folder's MGQ Online has no bridge to C#, so it is older than the core library #{path}")
      end

      log.puts("core library: #{path}")
      @missing = nil
      path
    end

    # Loads the library without calling it.
    #
    # @param path [String, nil] The library, see library.
    # @param log [IO] Where the server's log goes.
    # @return [MGQ_Multiplayer::Bridge::FiddleBackend, nil] Its functions, nil without a library or
    #   when it could not be loaded, which is logged.
    def load(path, log = $stderr)
      return nil unless path

      MGQ_Multiplayer::Bridge::FiddleBackend.new(path)
    rescue StandardError => e
      @missing = "the core library #{path} could not be loaded: #{e.class}: #{e.message}"
      log.puts(@missing)
      nil
    end

    # Shakes hands with the core, the first call into it, and writes its log lines into MGQ
    # Online's log from then on.
    #
    # @param backend [#open, #call, #reply, #drain, nil] The core's functions, see load.
    # @param log [IO] Where the server's log goes.
    # @return [Boolean] Whether the bridge opened; MGQ Online's log tells why not.
    def open(backend, log = $stderr)
      return false unless backend

      take_log_lines
      return true if MGQ_Multiplayer::Bridge.open(backend)

      @missing = "the core library did not shake hands"
      log.puts("#{@missing}: #{REFUSING}")
      false
    end

    # Tells whether the core answers, which MGQ Online's battles need.
    #
    # @return [Boolean] Whether the bridge to it is open in this process.
    def ready?
      defined?(MGQ_Multiplayer::Bridge) && MGQ_Multiplayer::Bridge.open? ? true : false
    end

    # Tells why the core does not answer, for the relay and the battle's starter.
    #
    # @return [String] Why, such as that the library does not exist.
    def why_missing
      "the battle server's C# core library is missing or did not load: #{@missing || 'its bridge is closed'}"
    end

    private

    # Notes and logs why the server has no core.
    #
    # @param log [IO] Where the server's log goes.
    # @param why [String] Why.
    # @param warn [Boolean] Whether the line is a warning, as for a setting that names no library.
    # @return [nil] Nothing.
    def missing(log, why, warn = true)
      @missing = why
      log.puts("#{warn ? 'warning: ' : ''}#{why}: #{REFUSING}")
      nil
    end

    # Hands the core's log lines in each drain to MGQ Online's log, once per process.
    def take_log_lines
      return if @log_lines_taken

      @log_lines_taken = true
      MGQ_Multiplayer::Bridge.on(LOG_TOPIC) { |line| MGQ_Multiplayer::Log.write("core: #{line}") }
    end
  end
end
