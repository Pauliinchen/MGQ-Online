#----------------------------------------------------------------
#  run.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Took the Mod Framework's scripts only from MGQ_MOD_FRAMEWORK_DIR, since the mod no longer ships them
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

# Every test loads the Mod Framework's scripts first, from the folder MGQ_MOD_FRAMEWORK_DIR names;
# without them the run stops with one line.
place = ENV["MGQ_MOD_FRAMEWORK_DIR"]
unless place && File.file?(File.join(place, "loader.rbx"))
  puts "The Mod Framework's scripts are missing: none in #{place || 'MGQ_MOD_FRAMEWORK_DIR, which is not set'}."
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
