#----------------------------------------------------------------
#  game_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-15: Created
#
#----------------------------------------------------------------

# Tests that play battles with the game's own scripts, from the game folder BATTLE_GAME_DIR names
# (its Data and Patch folders); skipped without one, since the game's files never go into the
# repository.

require_relative "support"

unless game_dir
  Checks.skip("BATTLE_GAME_DIR names no game folder")
  exit
end

require_relative File.join(LIB_DIR, "boot")
require_relative File.join(LIB_DIR, "battle")

log = StringIO.new
Boot.run(log)
HeadlessBattle.install
check("every script of the game loads", Boot.failures.map { |index, name, _| "#{index} #{name}" }, [])
check("the database is the game's", [$data_actors.size > 1000, $data_troops.size > 1000], [true, true])

outcome = HeadlessBattle.run(troop_id: 1, party: [[1, 10]], seed: 1)
check("a level 10 Luka beats the first Slime Girl", outcome[:result], :victory)
check("the battle log tells it", outcome[:log].any? { |line| line.include?("Slime Girl") }, true)
again = HeadlessBattle.run(troop_id: 1, party: [[1, 10]], seed: 1)
check("the same seed plays the same battle", again[:log], outcome[:log])

turns = []
HeadlessBattle.run(troop_id: 1, party: [[1, 1]], seed: 3, commander: lambda { |actors, turn|
  turns << [actors.map(&:id), turn]
  actors.each { |actor| actor.actions.each(&:set_guard) }
})
check("the commander gets the actors due, every turn", turns.first, [[1], 1])

check("a troop without enemies is refused before the battle",
      raised { HeadlessBattle.run(troop_id: 0, party: [[1, 1]]) }&.message, "troop 0 has no enemies")
check("an actor the database lacks is refused",
      raised { HeadlessBattle.run(troop_id: 1, party: [[99_999, 1]]) }&.message, "actor 99999 is not in the database")
check("nothing the game writes reaches the disk", Dir.exist?(File.join(game_dir, "Save")) && !Dir.empty?(File.join(game_dir, "Save")), false)
