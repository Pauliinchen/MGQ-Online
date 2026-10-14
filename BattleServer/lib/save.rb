#----------------------------------------------------------------
#  save.rb
#
#  Changelog:
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

require_relative "save_check"

# Reads the game's save files as the game does, so a battle can start from a player's own party,
# inventory, switches and variables. A save is checked before Marshal reads it: it may name only
# the game's own classes and Ruby's plain values.
module SaveFile
  # Marshal's complaint about a class the loaded scripts do not define.
  UNKNOWN_CLASS = /undefined class\/module ([\w:]+)/

  # A class name a stand-in may take: constants only, nothing else.
  STAND_IN_NAME = /\A[A-Z]\w*(::[A-Z]\w*)*\z/

  # Stand-ins one save may need; the client-only mods need far fewer.
  MAX_STAND_INS = 64

  # Classes defined as stand-ins while reading saves, by their path.
  @stand_ins = []

  class << self
    # The classes made up while reading saves: those of mods the server does not load, such as
    # the client-only ones. Their objects keep their fields and do nothing.
    attr_reader :stand_ins

    # Reads a save file's header and contents, once it passed the check.
    #
    # @param bytes [String] The save file.
    # @return [Array(Hash, Hash)] The header and the contents, as make_save_contents built them.
    # @raise [SaveCheck::Refused] For a save that names anything but the game's classes.
    def read(bytes)
      SaveCheck.new(bytes).check(Admitted.new)
      made = 0
      begin
        io = StringIO.new(bytes)
        [Marshal.load(io), Marshal.load(io)]
      rescue ArgumentError => e
        raise unless (path = e.message[UNKNOWN_CLASS, 1])
        raise SaveCheck::Refused, "the save names more than #{MAX_STAND_INS} unknown classes" if (made += 1) > MAX_STAND_INS

        stand_in(path)
        retry
      end
    end

    # Puts a system save's contents in place, as the game does at its start: the library
    # (encyclopedia and lifetime counts, which some damage boosts read) and the global switches.
    # Without one, a battle gets a fresh library, as on a new install.
    #
    # @param bytes [String, nil] The system save file (SystemSave.rvdata2), or nil.
    # @raise [SaveCheck::Refused] For a file that names anything but the game's classes.
    def extract_system(bytes)
      if bytes
        SaveCheck.new(bytes).check(Admitted.new)
        DataManager.extract_system_save_contents(Marshal.load(bytes))
        DataManager.send(:update_system) if DataManager.respond_to?(:update_system, true)
        DataManager.fix_system
      else
        DataManager.create_system_objects
      end
      $game_library.make_preparation_list
    end

    # Puts a save's contents in place of the game's state, as loading it in the game does.
    #
    # @param contents [Hash] The contents.
    def extract(contents)
      DataManager.extract_save_contents(contents)
      # The game's own steps after a load: bring an older save up to date and reload the map
      # when the game's maps changed since.
      DataManager.send(:update) if DataManager.respond_to?(:update, true)
      DataManager.send(:reload_map_if_updated) if DataManager.respond_to?(:reload_map_if_updated, true)
    end

    # Tells whether a name is defined anywhere yet, Ruby's own lazily loaded constants included.
    #
    # @param path [String] The name.
    # @return [Boolean] Whether it is.
    def defined_name?(path)
      Object.const_defined?(path)
    rescue NameError
      false
    end

    private

    # Defines an empty class for a path Marshal names, with modules for its outer names.
    #
    # @param path [String] The class's path, such as MGQ_MpWorld::Seat.
    def stand_in(path)
      names = path.split("::")
      outer = names[0..-2].inject(Object) do |scope, name|
        scope.const_defined?(name, false) ? scope.const_get(name, false) : scope.const_set(name, Module.new)
      end
      outer.const_set(names.last, Class.new) unless outer.const_defined?(names.last, false)
      @stand_ins << path
    end
  end

  # The class names a save may name: the game's own, and names nothing defines, which become
  # empty stand-ins whose outer names are the game's or new too. A name of Ruby's own, such as
  # Gem::Requirement, is never admitted, nor a new class inside one of Ruby's modules.
  class Admitted
    # Tells whether a save may name a class.
    #
    # @param name [String] The class's name.
    # @return [Boolean] Whether it may.
    def include?(name)
      return true if SaveCheck.game_names.include?(name)
      return false unless name.match?(STAND_IN_NAME)

      outer = name.split("::")[0..-2]
      !SaveFile.defined_name?(name) &&
        outer.each_index.all? do |i|
          path = outer[0..i].join("::")
          SaveCheck.game_names.include?(path) || !SaveFile.defined_name?(path)
        end
    end
  end
end
