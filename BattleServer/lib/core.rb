#----------------------------------------------------------------
#  core.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# MGQOnline.ServerCore, MGQ Online's C# core on the battle server: a native library MGQ Online's
# bridge reaches through Fiddle (MGQ_Multiplayer::Bridge::FiddleBackend), named by
# BATTLE_CORE_LIBRARY. Where battles run in forked children, each child loads it after the fork
# and before its sandbox and shakes hands after the sandbox closed; nothing calls it before a
# fork, since a child of a process whose core already ran hangs at its first garbage collection.
module Core
  # The environment setting that names the library's path.
  LIBRARY_SETTING = "BATTLE_CORE_LIBRARY"

  # The topic of the core's log lines, which the drain hands over as events.
  LOG_TOPIC = "log"

  class << self
    # The library the environment names, checked once as the server starts and logged: a library
    # that is not there counts as none.
    #
    # @param log [IO] Where the server's log goes.
    # @param env [Hash] The environment.
    # @return [String, nil] The library's full path, nil for none.
    def library(log = $stderr, env = ENV)
      path = env[LIBRARY_SETTING].to_s
      if path.empty?
        log.puts("no core library (#{LIBRARY_SETTING} is not set): MGQ Online's battles run without the C# core")
        return nil
      end

      path = File.expand_path(path)
      unless File.file?(path)
        log.puts("warning: the core library #{path} (#{LIBRARY_SETTING}) does not exist: MGQ Online's battles run without the C# core")
        return nil
      end
      unless defined?(MGQ_Multiplayer::Bridge::FiddleBackend)
        log.puts("warning: the game folder's MGQ Online has no bridge to C#, so it is older than the core library #{path}: " \
                 "MGQ Online's battles run without the C# core")
        return nil
      end
      log.puts("core library: #{path}")
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
      log.puts("the core library #{path} could not be loaded: #{e.class}: #{e.message}")
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

      log.puts("the core library did not shake hands: MGQ Online's battles run without the C# core")
      false
    end

    private

    # Hands the core's log lines in each drain to MGQ Online's log, once per process.
    def take_log_lines
      return if @log_lines_taken

      @log_lines_taken = true
      MGQ_Multiplayer::Bridge.on(LOG_TOPIC) { |line| MGQ_Multiplayer::Log.write("core: #{line}") }
    end
  end
end
