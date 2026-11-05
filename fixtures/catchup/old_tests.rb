#----------------------------------------------------------------
#  old_tests.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

require "fileutils"
require "rubygems/package"
require "stringio"
require "tmpdir"

# Runs a script test of the last commit whose tests answered the DLL's catch-up topics from
# engine.rb, for make_engine.rb and make_classic.rb, which record the engine's answers to the calls
# those tests make. A recording tool: no test runs against it.
module OldCatchupTests
  # The last commit whose script tests answered the catch-up from engine.rb.
  SOURCE_COMMIT = "1a6e3f21"

  # The repository's root.
  ROOT = File.expand_path("../..", __dir__)

  # The folders the old tests read.
  FOLDERS = %w(GameScript fixtures Relay/core Relay/seed)

  # The recording tool's own files, taken as they are now rather than as the commit kept them.
  CURRENT = %w(fixtures/catchup/engine.rb fixtures/catchup/relay_rows.rb fixtures/catchup/generated_tables.rb fixtures/catchup/generated)

  # Loads a script test of SOURCE_COMMIT from a copy of that commit's folders, in its own folder.
  #
  # The copy is deleted afterwards.
  #
  # @param test [String] The test's path, such as "GameScript/Tests/world_catchup_test.rb".
  def self.run(test)
    Dir.mktmpdir("old_catchup_tests") do |folder|
      extract(folder)
      CURRENT.each do |path|
        FileUtils.rm_rf(File.join(folder, path))
        FileUtils.cp_r(File.join(ROOT, path), File.join(folder, path))
      end
      # The Mod Framework's scripts are no part of the repository, so the copy reads the checkout's.
      ENV["MGQ_MOD_FRAMEWORK_DIR"] ||= File.join(ROOT, "package", "Framework", "Patch", "Mod_Framework")
      file = File.join(folder, test)
      Dir.chdir(File.dirname(file)) { load file }
    end
  end

  # Writes the folders of SOURCE_COMMIT into a folder.
  #
  # @param folder [String] The folder.
  def self.extract(folder)
    tar = IO.popen(["git", "-C", ROOT, "archive", "--format=tar", SOURCE_COMMIT, *FOLDERS], "rb", &:read)
    raise "git could not read the folders of #{SOURCE_COMMIT}" unless $?.success?

    # The reader seeks, which a pipe cannot.
    Gem::Package::TarReader.new(StringIO.new(tar)).each do |entry|
      path = File.join(folder, entry.full_name)
      if entry.directory?
        FileUtils.mkdir_p(path)
      elsif entry.file?
        FileUtils.mkdir_p(File.dirname(path))
        File.binwrite(path, entry.read)
      end
    end
  end
end
