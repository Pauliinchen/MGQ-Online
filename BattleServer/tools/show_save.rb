#----------------------------------------------------------------
#  show_save.rb
#
#  Changelog:
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

require "stringio"
require_relative "../lib/boot"
require_relative "../lib/save"

# Shows a save's party as the server reads it: ruby show_save.rb <save file>...
# Read before the boot, which moves into the game folder.
saves = ARGV.to_h { |path| [path, File.binread(path)] }
Boot.run
saves.each do |path, bytes|
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  header, contents = SaveFile.read(bytes)
  SaveFile.extract(contents)
  seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  puts format("== %s (%.2f s): map %d, gold %d, %d party members, %d in battle, header %s",
              File.basename(path), seconds, $game_map.map_id, $game_party.gold, $game_party.members.size,
              $game_party.battle_members.size, header.keys.inspect[0, 120])
  $game_party.battle_members.each do |actor|
    equips = actor.equips.compact.map(&:name).join(", ")
    # The game keeps three levels per actor: its own, its job's and its race's.
    levels = actor.level.is_a?(Hash) ? actor.level.values.join("/") : actor.level.to_s
    puts format("  %-12s Lv %-11s %s  HP %d/%d MP %d/%d  ATK %d DEF %d MAT %d MDF %d AGI %d  skills %d",
                actor.name, levels, actor.class.name,
                actor.hp, actor.mhp, actor.mp, actor.mmp, actor.atk, actor.def, actor.mat, actor.mdf, actor.agi,
                actor.skills.size)
    puts "               equipment: #{equips[0, 150]}"
  end
end
puts "stand-in classes: #{SaveFile.stand_ins.uniq.join(", ")}" unless SaveFile.stand_ins.empty?
