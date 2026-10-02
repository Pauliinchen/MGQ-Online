#----------------------------------------------------------------
#  mp_hooks.rbx
#
#  Changelog:
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

  # The original of each wrapped method by method.
  @originals ||= {}

  # The blocks that failed, each logged once.
  @failed ||= {}

  # Writes a line to the mod's InGame.log.
  #
  # @param message [String] The line.
  def self.log(message)
    MGQ_Multiplayer::Log.write("hooks: #{message}")
  rescue
  end

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
    wrap(owner, name)
    blocks = @blocks[[owner, name]] ||= { :before => {}, :after => {} }
    blocks[moment][script] = block
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
  def self.wrap(owner, name)
    return if @originals[[owner, name]]

    original = :"mgq_mp_hooks_#{@originals.size + 1}_#{name.to_s.gsub(/[?!=]/, '_')}"
    was_private = owner.private_method_defined?(name)
    owner.send(:alias_method, original, name)
    owner.send(:define_method, name) do |*args, &block|
      MGQ_MpHooks.run(self, owner, name, :before, args)
      result = send(original, *args, &block)
      MGQ_MpHooks.run(self, owner, name, :after, args)
      result
    end
    owner.send(:private, name) if was_private
    @originals[[owner, name]] = original
  end

  # Runs the blocks registered for a moment of a method, logging a failing one once.
  #
  # @param object [Object] The object the method runs on.
  # @param owner [Module] The class that has the method.
  # @param name [Symbol] The method.
  # @param moment [Symbol] :before or :after.
  # @param args [Array] The method's arguments.
  def self.run(object, owner, name, moment, args)
    blocks = @blocks[[owner, name]]
    return unless blocks

    scripts = moment == :before ? blocks[:before].keys.reverse : blocks[:after].keys
    scripts.each do |script|
      begin
        object.instance_exec(*args, &blocks[moment][script])
      rescue => e
        key = [owner, name, moment, script]
        log("#{script} failed #{moment} #{owner}##{name}: #{e.class}: #{e.message}") unless @failed[key]
        @failed[key] = true
      end
    end
  end
end
