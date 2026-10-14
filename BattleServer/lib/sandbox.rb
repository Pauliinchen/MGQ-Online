#----------------------------------------------------------------
#  sandbox.rb
#
#  Changelog:
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

require "etc"

# Closes a battle's child process in, on Linux when the server runs as root: the game's data
# holds code (damage formulas, notes some plugins evaluate, event script commands), so a crafted
# save may still run some inside a battle. In the sandbox it reaches no network but its own
# connection, sees only the game folder, writes no file and runs as nobody.
module Sandbox
  # unshare's flag for a network namespace of its own, which has no way out.
  CLONE_NEWNET = 0x40000000

  # The user a sandboxed child runs as.
  USER = "nobody"

  # Address space a child may take: the parent's game it shares counts too, about 1.2 GB.
  ADDRESS_SPACE = 6 * 1024**3

  # Files a child may hold open: its connection, the standard streams and what Ruby keeps.
  OPEN_FILES = 64

  # Processes and threads nobody may run in all, so a child cannot start many.
  PROCESSES = 1024

  class << self
    # Tells whether children can be sandboxed here.
    #
    # @return [Boolean] Whether they can: on Linux, as root, unless BATTLE_SANDBOX is 0.
    def available?
      RUBY_PLATFORM.include?("linux") && Process.euid.zero? && ENV["BATTLE_SANDBOX"] != "0"
    end

    # Closes the calling process in; there is no way back. Its standard streams must not be
    # files: writing to a file kills it from now on.
    #
    # @param root [String] The only folder it may see from now on, the game's.
    def enter(root)
      user = Etc.getpwnam(USER)
      leave_network
      Dir.chroot(root)
      Dir.chdir("/")
      # A write past the file size limit fails instead of killing the battle. A game script takes
      # Kernel's trap away, as it does fork and exit!.
      Signal.trap("XFSZ", "IGNORE")
      Process.setrlimit(:FSIZE, 0)
      Process.setrlimit(:CORE, 0)
      Process.setrlimit(:NOFILE, OPEN_FILES)
      Process.setrlimit(:AS, ADDRESS_SPACE)
      Process.setrlimit(:NPROC, PROCESSES)
      Process.groups = []
      Process::GID.change_privilege(user.gid)
      Process::UID.change_privilege(user.uid)
      raise SecurityError, "the sandbox could not drop root" if Process.euid.zero? || Process.uid.zero?
    end

    # The folders and files below the game folder that others than their owner may write to,
    # where a sandboxed child could leave files.
    #
    # @param root [String] The game folder.
    # @return [Array<String>] Up to 5 of them.
    def writable_by_others(root)
      [root, *Dir.glob(File.join(root, "**", "*"))].select do |path|
        !File.symlink?(path) && (File.stat(path).mode & 0o022).positive?
      end.first(5)
    end

    private

    # Moves the process into a network namespace of its own: the connections it holds keep
    # working, new ones reach nothing.
    def leave_network
      require "fiddle"
      unshare = Fiddle::Function.new(Fiddle.dlopen(nil)["unshare"], [Fiddle::TYPE_INT], Fiddle::TYPE_INT)
      raise SecurityError, "unshare failed: #{Fiddle.last_error}" unless unshare.call(CLONE_NEWNET).zero?
    end
  end
end
