#----------------------------------------------------------------
#  dump_scripts.rb
#
#  Changelog:
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

require "zlib"
require "fileutils"

# Writes every script of the game's Scripts.rvdata2 to a numbered file, for reading them.
#
# @param game [String] The game folder.
# @param out [String] The folder the scripts go to.
def dump_scripts(game, out)
  FileUtils.mkdir_p(out)
  scripts = Marshal.load(File.binread(File.join(game, "Data", "Scripts.rvdata2")))
  index = []
  scripts.each_with_index do |(_, name, packed), i|
    code = Zlib::Inflate.inflate(packed).force_encoding("UTF-8")
    safe = name.to_s.force_encoding("UTF-8").gsub(/[^\p{Word}\-. ]/, "_").strip
    File.binwrite(File.join(out, format("%03d %s.rb", i, safe[0, 60])), code)
    index << format("%03d\t%d\t%s", i, code.bytesize, name.to_s.force_encoding("UTF-8"))
  end
  File.write(File.join(out, "_index.txt"), index.join("\n"))
  puts "#{scripts.size} scripts"
end

dump_scripts(ARGV[0], ARGV[1])
