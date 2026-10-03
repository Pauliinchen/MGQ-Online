#----------------------------------------------------------------
#  mp_hooks.rbx
#
#  Changelog:
#      Paulinchen  2026-10-03: Logged through MGQ_MpLog
#                            - Kept each method's blocks ready in their order, so a wrapped method looks nothing up and builds nothing when it runs
#      Paulinchen  2026-10-02: Created
#
#----------------------------------------------------------------

# The game methods several scripts follow, such as Scene_Map#update_scene, each wrapped once here.
# A script registers a block to run before or after the method instead of wrapping it itself, so no
# script depends on how the others wrapped it. A hook that changes what a method does or returns
# stays a wrap of the script's own.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpHooks
  # The blocks by method, then by when they run, then by the script that registered them.
  @blocks ||= {}

  # The blocks by method, then by when they run, as each wrap runs them: pairs of script and block
  # in their order. Every wrap holds its own two lists, which a registration fills anew.
  @ready ||= {}

  # The original of each wrapped method by method.
  @originals ||= {}

  extend MGQ_MpLog

  # What starts this script's lines in the mod's InGame.log.
  LOG_TAG = "hooks"

  # Runs a block before a game method, on the object the method runs on and with its arguments.
  #
  # The blocks run as nested wraps would, so the first script to register stays closest to the
  # game's method: before blocks run from the last registered to the first.
  #
  # @param owner [Module] The class that has the method, the singleton class for a module's method.
  # @param name [Symbol] The method.
  # @param script [String] Who registers, which a second registration of replaces.
  def self.before(owner, name, script, &block)
    register(owner, name, :before, script, block)
  end

  # Runs a block after a game method, on the object the method runs on and with its arguments. The
  # method's result is returned unchanged.
  #
  # After blocks run from the first registered to the last, see before.
  #
  # @param owner [Module] The class that has the method, the singleton class for a module's method.
  # @param name [Symbol] The method.
  # @param script [String] Who registers, which a second registration of replaces.
  def self.after(owner, name, script, &block)
    register(owner, name, :after, script, block)
  end

  # Keeps a block, wrapping the method the first time.
  #
  # @param owner [Module] The class that has the method.
  # @param name [Symbol] The method.
  # @param moment [Symbol] :before or :after.
  # @param script [String] Who registers.
  # @param block [Proc] What runs.
  def self.register(owner, name, moment, script, block)
    ready = @ready[[owner, name]] ||= { :before => [], :after => [] }
    wrap(owner, name, ready)
    blocks = @blocks[[owner, name]] ||= { :before => {}, :after => {} }
    blocks[moment][script] = block
    ready[:before].replace(blocks[:before].to_a.reverse)
    ready[:after].replace(blocks[:after].to_a)
  rescue => e
    log("#{script} could not follow #{owner}##{name}: #{e.class}: #{e.message}")
  end

  # Wraps a method once, keeping the original under a name of its own.
  #
  # The name counts the wraps, since a subclass's method of the same name may be wrapped too, and
  # a shared name would then call the subclass's original from the superclass's wrap.
  #
  # @param owner [Module] The class that has the method.
  # @param name [Symbol] The method.
  # @param ready [Hash] The method's blocks as the wrap runs them, see @ready.
  def self.wrap(owner, name, ready)
    return if @originals[[owner, name]]

    original = :"mgq_mp_hooks_#{@originals.size + 1}_#{name.to_s.gsub(/[?!=]/, '_')}"
    was_private = owner.private_method_defined?(name)
    before = ready[:before]
    after = ready[:after]
    before_label = "before #{owner}##{name}"
    after_label = "after #{owner}##{name}"
    owner.send(:alias_method, original, name)
    owner.send(:define_method, name) do |*args, &block|
      MGQ_MpHooks.run(self, before, before_label, args) unless before.empty?
      result = send(original, *args, &block)
      MGQ_MpHooks.run(self, after, after_label, args) unless after.empty?
      result
    end
    owner.send(:private, name) if was_private
    @originals[[owner, name]] = original
  end

  # Runs the blocks registered for a moment of a method, logging a failing one once.
  #
  # @param object [Object] The object the method runs on.
  # @param hooks [Array<Array>] Each script and its block, in the order they run.
  # @param label [String] The moment and the method, for the log.
  # @param args [Array] The method's arguments.
  def self.run(object, hooks, label, args)
    hooks.each do |script, block|
      begin
        object.instance_exec(*args, &block)
      rescue => e
        log_once(block, "#{script} failed #{label}: #{e.class}: #{e.message}")
      end
    end
  end
end
