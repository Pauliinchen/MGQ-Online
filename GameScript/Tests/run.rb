#----------------------------------------------------------------
#  run.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Failed at once with one line when the Mod Framework's scripts are missing
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# Runs every *_test.rb of this folder, each in a Ruby process of its own, and prints one line per
# file; a failing file's whole output follows it, and with -v every file's does. Ends with 1 when
# any file failed.
#
#   ruby GameScript/Tests/run.rb [-v]

require "open3"
require "rbconfig"

verbose = ARGV.include?("-v")
failed = []

# Every test loads the Mod Framework's scripts first; without them the run stops with one line.
places = [ENV["MGQ_MOD_FRAMEWORK_DIR"], File.expand_path("../../package/Framework/Patch/Mod_Framework", __dir__)].compact
unless places.any? { |dir| File.file?(File.join(dir, "loader.rbx")) }
  puts "The Mod Framework's scripts are missing: none in #{places.join(' or ')}."
  exit(1)
end

Dir[File.join(__dir__, "*_test.rb")].sort.each do |file|
  output, status = Open3.capture2e(RbConfig.ruby, file)
  name = File.basename(file, ".rb")
  puts "#{status.success? ? 'ok  ' : 'FAIL'} #{name.ljust(22)} #{output.lines.last.to_s.strip}"
  puts output.gsub(/^/, "     ") if verbose || !status.success?
  failed << name unless status.success?
end

puts failed.empty? ? "All test files passed." : "Failed: #{failed.join(', ')}"
exit(failed.empty? ? 0 : 1)
