#----------------------------------------------------------------
#  world_catchup_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Built the story chest without the flags only older games needed
#                            - Handed and expected the story's keys as [kind, key] with values, and the sites a replay plays as plain values
#                            - Expected the shared companions added through the DLL's topic, their ids as numbers
#                            - Checked that a prize's row gives only as history before the world's log, but the Medal King's free gift
#                            - Checked that the orbs' event plays only as history before the world's log
#                            - Checked that the repair never gives back an item an event takes away, read as the events database lists it
#                            - Checked that a found item's gain notes nothing for the world but a Makina, whose items the story replay hands over
#      Paulinchen  2026-11-01: Checked that a key item another player found comes once, to a player behind too, and its next gain adds nothing
#                            - Checked that a Small Medal the player holds is not noted for the world
#                            - Checked that a key item an event used up leaves every player of the world who holds it, with the Yggdrasil Fruit the Queen Harpy takes
#                            - Stood in for the replay's name of a command
#                            - Checked that a player on a route in a save of another player's starting save is asked, keeps the route's switches and loses the other side's companion once they answered, and one in a save of their own is not asked
#      Paulinchen  2026-10-31: Dropped the warp ban's lift on the maps where warping is free
#                            - Checked that a missed companion's recruit page is played once a route finished
#                            - Expected the plainer texts the player reads
#                            - Checked that the rows give only the history before the world's log
#                            - Checked that a world chest and a Makina by level are played in the player's game
#                            - Stood in for the replay the world's track waits on
#      Paulinchen  2026-10-28: Dropped the stand-in for the telling that may go on after a move
#                            - Checked that the rules of the catch-up come from the DLL once per revision of the mapping
#                            - Checked that the tables built from the rows before the rules came are kept, and built again once
#                            - Checked the catch-up through the DLL's catch-up topics: what it reads asked once per revision of the mapping, the save's notes handed once
#                            - Moved the game's stand-ins and the helpers into catchup_support.rb
#      Paulinchen  2026-10-24: Checked that a prize another player claimed reaches the player
#                            - Checked that Alice's Power-up counts the steps the world did
#                            - Checked that a join's persona waits behind a later change of the story
#                            - Checked that a power-up carried past changes the character once at its level
#                            - Checked that a companion of the roster takes the persona a join brings
#      Paulinchen  2026-10-23: Answered the rules the DLL owns through the bridge from the golden cases
#                            - Followed the relay's tracks through the DLL's story topics: a player behind on their part's checkpoint and moved on by the relay
#                            - Checked that a found job item comes to every player at once
#                            - Checked that the gate's notices name the cap of another mod below it
#                            - Checked that the story sets a return point only on the map of its event
#      Paulinchen  2026-10-17: Checked that the Unlocks page lists no companion the story took away
#                            - Checked that the catch-up waits while a lost raid boss battle's defeat runs
#                            - Checked that a player on Ilias's side gets the Remina Key Card back
#                            - Checked a key item one event gives and takes back
#                            - Checked job items of one-time gifts
#                            - Checked the rewards repair
#                            - Checked found job items by the story
#                            - Checked the question of a side for a player without one
#      Paulinchen  2026-10-15: Checked that a lasting join on another page of a visit's event waits for the gate
#      Paulinchen  2026-10-14: Checked that a return point left at Adramelech moves on with the story
#                            - Checked that a visit's own event brings its companion along before the gate
#      Paulinchen  2026-10-13: Checked that a Makina comes and shows only once a player of the world got or held it
#                            - Checked that a join the story takes back in the same step counts nowhere in the catch-up
#      Paulinchen  2026-10-12: Checked that story and quest classes and races reach the roster
#                            - Checked that story and quest skills reach the roster's companions
#                            - Stood in for a companion's name
#                            - Checked that a shared companion whose talk the player's story passed still joins
#                            - Checked that a job or race item held before is noted on entering
#                            - Checked that a job or race item any player got comes to every other player once
#                            - Read the catch-up's gifts from its log
#                            - Checked which pages keep the encounters with the map
#                            - Checked a move on at a level cap whose checkpoint is dropped
#                            - Checked Galda coming back to its start once a story is laid over
#                            - Stood in for the vehicles' start positions and a vehicle's tile
#                            - Checked that another mod's cap brings no Makina or waiting companion
#                            - Checked the story's skills and items held from a player behind or at a cap
#                            - Checked that a vehicle no story event gave yet leaves its map
#                            - Stood in for the map's vehicles and the one the player rides
#                            - Checked a world-wide chest's flags and the Randolphs found
#                            - Checked the game over's return point and a player behind getting none of the world's later part
#                            - Checked a vehicle leaving for a player behind and Galda staying
#                            - Checked that an audit reads the story's part anew
#      Paulinchen  2026-10-11: Checked the Levels page list of the catch-up and the level it counts
#                            - Checked Makina at their area level, one each
#                            - Checked that a watched telling takes its scene's key items
#                            - Checked that Amira in the roster raises her information network to 2
#                            - Checked one look at everything on entering and on a level up
#                            - Stood in for random encounters and the map's events
#                            - Checked a key item the story's place owes
#      Paulinchen  2026-10-10: Stood in for MGQ_MpCoopEvents.telling_or_moved?
#                            - Checked a shared save's own story counting as the player's in a Raid World started from it
#                            - Checked a save noting the player behind staying behind once loaded again
#                            - Checked a player moving on past a finished route to the world's route
#                            - Checked that changes made while behind stay under the checkpoint
#      Paulinchen  2026-10-09: Loaded story_state.rbx before coop_story.rbx and read the story through MGQ_MpStoryState
#                            - Checked key items whose event only plays and the last orb's event
#                            - Checked that a save noting the player behind holds the story until the world's came
#                            - Checked that a shared companion whose join the player's story passed is not brought back
#                            - Checked that a player behind in the world's part moves on to the world's story
#                            - Created
#
#----------------------------------------------------------------

# Covers world_catchup.rbx with world_story.rbx, story_keys.rbx, story_state.rbx, coop_story.rbx
# and coop_choices.rbx in the game catchup_support.rb stands in for: a player behind a
# Raid World's story, whom the relay puts on their part's checkpoint and moves on by their level,
# and what a story written into the player's gives, takes and sets, from rewards and companions to
# vehicles and Makina, each once.

require_relative "catchup_support"

# Stands in for story_replay.rbx: the pages the catch-up hands the player's game to play, in
# $derived as [fields, why], with no run of the world's track waiting, and a command's name.
module MGQ_MpStoryReplay
  def self.input_at(site, _list, index); "#{site}@#{index}"; end
  def self.derive(fields, why); ($derived ||= []) << [fields, why]; end
  def self.running?; false; end
  def self.waiting; []; end
  def self.free?; false; end
end

story = MGQ_MpWorldStory
catchup = MGQ_MpWorldCatchup
join = DATA::Join
removal = DATA::Removal
key_item = DATA::KeyItem
chest = DATA::Chest
reward = DATA::Reward

$game_map = Game_Map.new
$game_player = Game_Player.new
SceneManager.scene = Scene_Map.new

# A player behind gets their part's checkpoint, the world as it was right before that part's ending.
tables(:REWARDS => [reward.new(:skill, 937, 1, "map:406:7:2", "1", 8, :alice, [[:v, 1001, 8], [:s, 2023]]),
                    reward.new(:skill, 930, 1, "map:406:7:3", "1", 8, :ilias, [[:v, 1001, 8], [:s, 2023]]),
                    reward.new(:i, 600, 2, "map:36:17:1", "1", 6, nil, [[:v, 1001, 6]]),
                    reward.new(:i, 600, 5, "map:40:1:1", "1", 12, nil, [[:v, 1001, 12]])],
       :REMOVALS => [removal.new(16, 16, "map:50:1:1", "1", 14, nil, [[:v, 1001, 14]], true),
                     removal.new(45, 45, "map:50:2:1", "1", 14, nil, [[:v, 1001, 14]], false)],
       :JOINS => [join.new(77, 77, "map:20:1:1", "1", 9, nil, [[:v, 1001, 9]], 7, :start),
                  join.new(80, 80, "map:21:1:1", "1", 15, nil, [[:v, 1001, 15], [:s, 2300]], 20, :floor)])
new_game({ 1001 => 7, 3001 => 40 }, [4], 12)
$game_party.add_actor(16)
$game_party.add_actor(45)
$game_party.gain_item($data_items[600], 2)
frames(1)
check("before the mapping came, the catch-up asks the DLL nothing", [MGQ_MpStoryKeys.raid_table, $fake.calls.count { |topic, _| %w(catchup.keys catchup.check catchup.note).include?(topic) }], [nil, 0])
checkpoint("1", packed({ 1001 => 18, 1032 => 5 }, [2023, 2300, 500]))
frames(70)
check("a player the relay puts on a track of their own at their part's checkpoint is behind", story.mode, :behind)
check("told so with the level that moves them on",
      $notices, ["The world's story is further than yours. You see the world as it was before the end of Part 1; reach level 25 to move on."])
check("whose story events are held", [catchup.holds_story?, catchup.refusal_text], [true, "Reach level 25 to continue the story."])
check("the checkpoint is written into the player's story, their own values kept",
      [$game_variables[1001], $game_variables[1032], $game_switches[500], $game_variables[3001], $game_switches[4]], [18, 5, true, 40, true])
check("the rewards it carried them past come by story position, their own side's alone, not those their own game gave",
      [MGQ_MpStoryState.knows?($game_actors[1], 937), MGQ_MpStoryState.knows?($game_actors[1], 930), $game_party.items[600]], [true, false, 7])
check("a removal for good it carried them past takes the companion, a temporary one does not", [roster.include?(16), roster.include?(45)], [false, true])
check("its companions join once the player's level reaches each join's gate", [roster.include?(77), roster.include?(80)], [true, false])
check("the save notes the checkpoint taken", $game_system.instance_variable_get(:@mgq_mp_catchup)["checkpoint"], "1")
check("what the catch-up reads was asked of the DLL once, for the mapping's revision", $fake.calls.count { |topic, _| topic == "catchup.keys" }, 1)
check("and the save's notes went to the DLL once, with its first look", $fake.calls.count { |topic, request| %w(catchup.check catchup.note).include?(topic) && Marshal.load(request).key?("ledger") }, 1)

# The relay moves the player on by the level their game tells it: into the next part's checkpoint
# while the world is past it, else into the world's story.
$game_actors[1].level = 20
frames(40)
check("at level 20 the waiting join of level 20 comes, raised to its level", [roster.include?(80), $game_actors[80].base_level], [true, 20])
check("but the player stays behind", story.mode, :behind)
$game_actors[1].level = 25
$messages.clear
frames(40)
check("the relay hears the level that opens the gate", staged("story.level").last, { "best" => 25, "cap" => 9999 })
moved("1", "world", packed({ 1001 => 26 }, [2300]), "rev" => 2)
frames(40)
check("and moves them on into the world's story, which is written into theirs: they play it now, never the part's ending",
      [$messages, story.mode, $game_variables[1001], catchup.holds_story?], [["Level 25 reached: catching up to the world's story."], :world, 26, false])
check("the notes forget the checkpoint", $game_system.instance_variable_get(:@mgq_mp_catchup)["checkpoint"], nil)

# A player far behind moves on a part per gate, Part 2's checkpoint first.
tables
new_game({ 1001 => 7 }, [], 30)
frames(1)
checkpoint("1", packed({ 1001 => 18 }), "part" => "3", "checkpoints" => "1,2")
frames(70)
moved("1", "2", packed({ 1001 => 33 }), "part" => "3", "checkpoints" => "1,2")
frames(70)
check("moved on to the next part's checkpoint while the world is past it, the player stays there until that part's gate",
      [$game_variables[1001], story.mode, catchup.refusal_text], [33, :behind, "Reach level 55 to continue the story."])

# A cap of another mod below the gate holds nobody back: the relay hears it with the level, and the
# notices name the cap (issue #53).
$game_actors[1].cap = 40
check("a player capped below the gate is told to reach the cap",
      [catchup.refusal_text, catchup.behind_text("2")],
      ["Reach level 40 to continue the story.", "The world's story is further than yours. You see the world as it was before the end of Part 2; reach level 40 to move on."])
$game_actors[1].level = 40
frames(40)
check("a player capped below the gate tells the relay their cap", staged("story.level").last, { "best" => 40, "cap" => 40 })
moved("2", "3", packed({ 1001 => 33 }), { "part" => "3", "checkpoints" => "1,2" }, "cap")
frames(70)
check("told the cap reached", $messages.last.to_s[/\ALevel \d+ reached/], "Level 40 reached")
$game_actors[1].cap = 9999

# A player behind learns no skill of the world's story, and the story's skills and items a move on
# at another mod's level cap carries them past wait for their real level, also over a load.
tables(:REWARDS => [reward.new(:skill, 930, 1, "map:60:2:1", "2", 24, nil, [[:v, 1001, 24]], true),
                    reward.new(:i, 600, 1, "map:60:3:1", "2", 24, nil, [[:v, 1001, 24]], true),
                    reward.new(:skill, 937, 1, "map:61:1:1", "2", 28, nil, [[:v, 1001, 28]], true)])
# Answers the catch-up's notes in the save.
#
# @return [Hash] The notes.
notes = lambda { $game_system.instance_variable_get(:@mgq_mp_catchup) }
new_game({ 1001 => 9 }, [], 10)
frames(1)
checkpoint("1", packed({ 1001 => 18 }))
frames(70)
check("a player behind learns no skill of the world's story", [story.mode, MGQ_MpStoryState.knows?($game_actors[1], 930)], [:behind, false])
$game_actors[1].cap = 20
$game_actors[1].level = 20
frames(40)
moved("1", "world", packed({ 1001 => 26 }), { "rev" => 51 }, "cap")
frames(40)
MGQ_MpWorldCatchup.level_up
frames(40)
check("moved on at a cap below the gate, the skills and items the world's story carried them past wait",
      [story.mode, MGQ_MpStoryState.knows?($game_actors[1], 930), $game_party.items[600].to_i, notes.call["waits"].size], [:world, false, 0, 2])
relay({ "rev" => 52, "part" => "2", "checkpoints" => "1" }, packed({ 1001 => 29 }))
frames(40)
check("but what the world's story carries them past later comes as usual", MGQ_MpStoryState.knows?($game_actors[1], 937), true)
catchup.note("capped" => 99)
check("a gate a cap opened is noted while the level is below it", notes.call["capped"], 99)
relay({ "rev" => 53, "part" => "2", "checkpoints" => "1" }, packed({ 1001 => 29 }))
frames(40)
check("and a gate noted while the player plays the world's story holds nothing back", notes.call["capped"], nil)
$game_actors[1].cap = 9999
$game_actors[1].level = 25
$messages.clear
$logs.clear
MGQ_MpWorldStory.loaded(:load)
MGQ_MpWorldCatchup.loaded
frames(1)
relay({ "rev" => 53, "part" => "2", "checkpoints" => "1" }, packed({ 1001 => 29 }))
frames(80)
check("and come once a load finds the real level at the gate",
      [MGQ_MpStoryState.knows?($game_actors[1], 930), $game_party.items[600].to_i, $logs.grep(/the story gave the player/).size], [true, 1, 1])
frames(40)
check("once", [$game_party.items[600].to_i, $logs.grep(/the story gave the player/).size], [1, 1])

# Key items are everyone's, and so are the chests that hold them, opened once for the world.
tables(:KEY_ITEMS => [key_item.new(502, 1, "map:6:33:1", "1", 5, nil, [[:v, 1001, 6]]),
                      key_item.new(503, 1, "map:7:24:2", "2", 22, nil, [[:v, 1001, 22]]),
                      key_item.new(503, -1, "map:7:25:1", "2", 24, nil, [[:v, 1001, 24]]),
                      key_item.new(504, 1, "map:8:1:1", "2", 30, nil, [[:v, 1001, 30]])],
       :CHESTS => [chest.new([30, 4, "A"], [501], "2", 22)])
new_game({ 1001 => 5 }, [], 5)
check("a story chest is the world's: the mapping keeps its self switch", MGQ_MpStoryKeys.shared?(2, [30, 4, "A"]), true)
frames(1)
relay({ "rev" => 4, "wrev" => 4, "p" => 26, "part" => "2" }, packed({ 1001 => 26 }, [], { [30, 4, "A"] => true }))
frames(40)
check("a player in the world's story gets every key item it gave, and loses what it took",
      [$game_party.items[502], $game_party.items[503], $game_party.items[504]], [1, 0, 0])
check("and the story chests the world opened are played in their own game, which gives what each gives, such as an ore the Chaos forge asks for",
      [$derived, $game_party.items[501], $game_switches[7102]], [[[{ "chest" => [2, [30, 4, "A"]] }, "c:30.4.A"]], 0, false])
frames(40)
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "5", :relay => true)
frames(1)
relay({ "rev" => 5, "wrev" => 5, "p" => 31, "part" => "2" }, packed({ 1001 => 31 }, [], { [30, 4, "A"] => true }))
frames(40)
check("each once, the next only as the world gives it", [$game_party.items[502], $derived.size, $game_party.items[504]], [1, 1, 1])
$derived = nil

# Companions join by their gates, Sonya's Chaos return at 250 among them.
sonya = REAL_JOINS.find { |row| row.persona == 842 && row.site == "map:1834:20:1" }
check("Sonya's Chaos return joins as persona 842 at 250", [sonya.actor, sonya.gate, sonya.rule], [525, 250, :floor])
tables(:JOINS => [sonya])
chaos = { 1001 => 40, 1143 => 21 }
sonya.marks.each { |mark| chaos[mark[1]] = mark[2] if mark[0] == :v }
on = sonya.marks.select { |mark| mark[0] == :s }.map { |mark| mark[1] }
new_game({ 1001 => 40, 1143 => 20 }, [], 150)
frames(1)
relay({ "rev" => 6, "wrev" => 6, "p" => 40, "r1143" => 20, "part" => "chaos", "route" => "chaos" }, packed({ 1001 => 40, 1143 => 20 }))
frames(16)
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "7", :relay => true)
frames(1)
relay({ "rev" => 7, "wrev" => 7, "p" => 40, "r1143" => 21, "part" => "chaos", "route" => "chaos" }, packed(chaos, on))
frames(40)
check("a join the world's story carried the player past waits for its gate", [story.mode, roster.include?(525)], [:world, false])
$game_actors[1].level = 249
$game_actors[1].cap = 249
frames(40)
check("not at 249, though another mod caps the player there", roster.include?(525), false)
$game_actors[1].cap = 9999
$game_actors[1].level = 250
frames(40)
check("at 250 Sonya joins in her Chaos persona at 250", [roster.include?(525), $game_actors[525].persona, $game_actors[525].base_level], [true, 842, 250])
check("and says so", $messages.last, "Sonya joined you.")
frames(40)
check("never twice", roster.count(525), 1)

# A story event of the player's own hands a companion out before the gate: the join waits for it.
early = join.new(45, 45, "map:60:1:1", "2", 25, nil, [[:v, 1001, 25]], 60, :floor)
tables(:JOINS => [early])
new_game({ 1001 => 24 }, [], 40)
frames(1)
relay({ "rev" => 8, "wrev" => 8, "p" => 24, "part" => "2" }, packed({ 1001 => 24 }))
frames(40)
$telling = true
$game_party.add_actor(45)
check("the game's own join during the player's telling waits for the gate", [roster.include?(45), $messages.last], [false, "Tamamo joins you once you reach level 60."])
$game_variables[1001] = 25
$telling = false
frames(40)
$game_party.add_actor(77)
check("a companion without a join waiting joins as the game does", roster.include?(77), true)
$game_actors[1].level = 60
frames(40)
check("at the gate the held companion joins at the join's level", [roster.include?(45), $game_actors[45].base_level], [true, 60])

# An event that brings a companion along on a visit only, and insists on them, as the Arena's final
# adds Alma Elma again until she is in the party: the catch-up never holds that join back.
visit = join.new(45, 45, "map:483:86:1", "2", 24, nil, [[:v, 1001, 24]], 60, :kept, 238, true)
lasting = join.new(45, 45, "map:291:23:1", "2", 24, nil, [[:v, 1001, 24]], 60, :kept, 62, true)
tables(:JOINS => [lasting, visit], :REMOVALS => [removal.new(45, 45, "map:483:86:1", "2", 24, nil, [[:v, 1001, 24]], true, 262)])
new_game({ 1001 => 24 }, [], 40)
frames(1)
relay({ "rev" => 9, "wrev" => 9, "p" => 24, "part" => "2" }, packed({ 1001 => 24 }))
frames(40)
# Stands in for a map event and its pages.
paged_event = Struct.new(:mgq_mp_pages)
event_page = Struct.new(:list)
visit_pages = [event_page.new([RPG::EventCommand.new(129, 0, [45])]), event_page.new([RPG::EventCommand.new(129, 0, [45])])]
$game_map.events[86] = paged_event.new(visit_pages)
$telling = true
$game_map.map_id = 483
$game_map.interpreter.setup(visit_pages[0].list, 86)
$game_map.interpreter.event_id = 86
$messages.clear
$game_party.add_actor(45)
check("a visit's own event brings the companion along though a lasting join waits for its gate", [roster.include?(45), $messages], [true, []])
$game_party.remove_actor(45)
$game_map.interpreter.setup(visit_pages[1].list, 86)
$game_party.add_actor(45)
check("while another page of that event still waits for the gate", [roster.include?(45), $messages.last], [false, "Tamamo joins you once you reach level 60."])
$game_map.interpreter.setup(visit_pages[0].list, 12)
$game_map.interpreter.event_id = 12
$game_party.add_actor(45)
check("as does another event of the player's", [roster.include?(45), $messages.last], [false, "Tamamo joins you once you reach level 60."])
$telling = false
$game_map.interpreter.event_id = 0
$game_map.events.delete(86)
$game_map.map_id = 3

# The world's shared companions join as far as the world shares them.
tables(:JOINS => [join.new(16, 16, "map:70:1:1", "ad", 10, nil, [[:v, 1141, 10]], 50, :start)])
$sharing = :story
new_game({ 1001 => 40, 1142 => 5 }, [], 49)
$game_party.add_actor(77)
frames(1)
relay({ "rev" => 9, "wrev" => 9, "p" => 40, "r1142" => 5, "part" => "mr", "route" => "mr", "comps" => "16,80" }, packed({ 1001 => 40, 1142 => 5 }))
frames(40)
check("a story companion another player got waits for its gate", roster.include?(16), false)
$game_actors[1].level = 50
frames(40)
check("then joins, though the player's story never passed its join", roster.include?(16), true)
check("a battle recruit is not shared with story companions alone", roster.include?(80), false)
check("the player's own battle recruit is no story companion to share", calls_of("raid.companions.add"), [])
$sharing = :all
new_game({ 1001 => 40, 1142 => 5 }, [], 9)
$game_party.add_actor(77)
frames(1)
relay({ "rev" => 9, "wrev" => 9, "p" => 40, "r1142" => 5, "part" => "mr", "route" => "mr", "comps" => "16,80" }, packed({ 1001 => 40, 1142 => 5 }))
frames(700)
check("with battle recruits shared, one joins at its start level", roster.include?(80), true)
check("and the player's own recruit goes to the world's list, once", calls_of("raid.companions.add"), [{ "world" => "w1", "ids" => [77] }])
relay({ "rev" => 10, "wrev" => 9, "p" => 40, "r1142" => 5, "part" => "mr", "route" => "mr", "comps" => "16,77,80", "companions" => "done" }, packed({ 1001 => 40, 1142 => 5 }))
frames(700)
check("which the next look sends nothing for", calls_of("raid.companions.add").size, 1)
# A talk join the player's story walked past gave them nothing, so the world's share still brings
# them.
tables(:JOINS => [join.new(45, 45, "map:5:27:1", "1", 6, nil, [[:v, 1001, 6]], 8, :start, 1, false)])
new_game({ 1001 => 9 }, [], 10)
frames(1)
relay({ "rev" => 12, "wrev" => 12, "p" => 9, "part" => "1", "comps" => "45" }, packed({ 1001 => 9 }))
frames(40)
check("a shared companion whose talk join the player's story only walked past, as its notes say, joins at its gate",
      [catchup.ledger["done"]["j:map:5:27:1:45"], roster.include?(45)], [true, true])
new_game({ 1001 => 9 }, [], 10)
$game_system.instance_variable_set(:@mgq_mp_catchup, { "world" => "w1", "done" => { "s:45" => true }, "rewards_repaired" => true })
frames(1)
relay({ "rev" => 13, "wrev" => 13, "p" => 9, "part" => "1", "comps" => "45" }, packed({ 1001 => 9 }))
frames(40)
check("and one the notes of an earlier build left out so is looked at again", [roster.include?(45), catchup.ledger["done"]["s:45"]], [true, "settled"])
$sharing = :off
new_game({ 1001 => 40, 1142 => 5 }, [], 90)
frames(1)
relay({ "rev" => 11, "wrev" => 11, "p" => 40, "r1142" => 5, "part" => "mr", "route" => "mr", "comps" => "16,80" }, packed({ 1001 => 40, 1142 => 5 }))
frames(40)
check("with sharing off nobody joins from the list", [roster.include?(16), roster.include?(80)], [false, false])

# A player behind in Part 3 stays behind when the world returns from a route to the Great Decision,
# until the relay moves them on.
tables
new_game({ 1001 => 36 }, [], 40)
frames(1)
checkpoint("3", packed({ 1001 => 39 }), "part" => "ad", "route" => "ad", "checkpoints" => "1,2,3")
frames(70)
check("a Part 3 player behind the world's route plays Part 3's checkpoint", [story.mode, $game_variables[1001]], [:behind, 39])
$fake.post("story.status", story_status("track" => "t1", "part" => "3", "gate" => 65, "rev" => 14,
                                        "world" => { "rev" => 14, "part" => "3", "route" => "none", "done" => ["ad"], "checkpoints" => %w(1 2 3 ad) }))
frames(100)
check("and stays behind below the gate once the world is back at the Great Decision", [story.mode, $game_variables[1001], $game_switches[7096]], [:behind, 39, false])
story.loaded(:load)
catchup.loaded
frames(1)
check("also once the save noting them behind loaded again, before the relay handed their track", [story.mode, catchup.holds_story?], [nil, true])
back = { "rev" => 14, "part" => "3", "done" => "ad", "checkpoints" => "1,2,3,ad" }
checkpoint("3", packed({ 1001 => 39 }), back)
frames(100)
check("and after", [story.mode, $game_variables[1001]], [:behind, 39])
$game_actors[1].level = 65
frames(40)
moved("3", "world", packed({ 1001 => 40 }, [7096]), back)
frames(40)
check("until the relay moves them on into the world's story", [story.mode, $game_variables[1001], $game_switches[7096]], [:world, 40, true])

# Rows by what holds in the story: an optional event nobody played gives nothing, nor one only
# there to play, and a finished route's rows count at the Great Decision.
tables(:REWARDS => [reward.new(:i, 600, 3, "map:36:18:1", "1", 10, nil, [[:v, 1001, 10], [:s, 2400]], true),
                    reward.new(:skill, 930, 1, "map:1697:7:2", "ad", 6, nil, [[:v, 1141, 6]], true)],
       :KEY_ITEMS => [key_item.new(503, 1, "map:6:33:1", "1", 12, nil, [[:v, 1001, 12]], false),
                      key_item.new(504, 1, "map:8:1:1", "1", 12, nil, [[:v, 1001, 12], [:s, 2401]], true)],
       :JOINS => [join.new(77, 77, "map:140:25:1", "2", 25, nil, [[:v, 1001, 25]], 7, :start, 3, false)])
new_game({ 1001 => 24 }, [], 40)
frames(1)
relay({ "rev" => 15, "wrev" => 15, "p" => 26, "part" => "2" }, packed({ 1001 => 26 }, [2401]))
frames(40)
check("an earlier part's row gives only when its marks hold in the story laid over the player's",
      [$game_party.items[600], $game_party.items[504]], [0, 1])
check("a row whose event is only there to play lets its companion join nobody, but its key item comes, being the world's",
      [roster.include?(77), $game_party.items[503]], [false, 1])
new_game({ 1001 => 39 }, [], 70)
frames(1)
relay({ "rev" => 16, "wrev" => 16, "p" => 40, "part" => "3", "clear" => "ad", "done" => "ad" }, packed({ 1001 => 40 }, [7096]))
frames(40)
check("a finished route's rows count while the story is back at the Great Decision", MGQ_MpStoryState.knows?($game_actors[1], 930), true)

# The rows give only the history the world's story was past where its log starts, side content
# without a step too; the world's track replays the runs after.
tables(:REWARDS => [reward.new(:i, 600, 1, "map:36:18:1", "2", 20, nil, [[:v, 1001, 20]], true),
                    reward.new(:i, 601, 1, "map:36:19:1", "2", 30, nil, [[:v, 1001, 30]], true),
                    reward.new(:i, 700, 1, "map:40:2:1", nil, nil, nil, [[:s, 3000]], true),
                    reward.new(:i, 701, 1, "map:40:3:1", nil, nil, nil, [[:s, 3001]], true)])
new_game({ 1001 => 10 }, [], 40)
frames(1)
relay({ "rev" => 17, "wrev" => 17, "p" => 32, "part" => "2", "start" => [25, 0, 0, 0], "log" => packed({ 1001 => 25 }, [3000], {}) + [[0, 3001, false]] },
      packed({ 1001 => 32 }, [3000, 3001]))
frames(80)
check("a story laid over the player's gives a row of the history the world was past where its log starts once, and nothing of a row whose run the log holds",
      [600, 601, 700, 701].map { |id| $game_party.items[id] }, [1, 0, 1, 0])

# A companion the player missed joins by their recruit page played in the player's game once their
# story finished a route, whose fight counts as won there (story_replay.rbx).
tables(:JOINS => [join.new(77, 77, "map:132:23:1", "1", 7, nil, [[:v, 1001, 7], [:v, 1056, 4]], 7, :start, 525, true)])
$sharing = :story
new_game({ 1001 => 39 }, [], 40)
frames(1)
relay({ "rev" => 18, "wrev" => 18, "p" => 40, "part" => "3", "clear" => "ad", "done" => "ad" }, packed({ 1001 => 40 }, [7096]))
frames(80)
check("a companion the player missed has their recruit page played in the player's game once a route finished, once",
      [$derived, roster.include?(77)], [[[{ "site" => ["map", 132, 23, 1] }, "m:77"]], false])
$derived = nil
$sharing = :off

# A join and a removal of one event go by their order in its list.
tables(:REMOVALS => [removal.new(16, 16, "map:483:86:1", "2", 24, nil, [[:v, 1001, 24]], true, 262),
                     removal.new(45, 45, "ce:9141", "2", 24, nil, [[:v, 1001, 24]], true, 10)],
       :JOINS => [join.new(16, 16, "map:483:86:1", "2", 24, nil, [[:v, 1001, 24]], 20, :kept, 238, true),
                  join.new(45, 45, "ce:9141", "2", 24, nil, [[:v, 1001, 24]], 12, :kept, 50, true)])
new_game({ 1001 => 23 }, [], 40)
$game_party.add_actor(16)
$game_party.add_actor(45)
frames(1)
relay({ "rev" => 17, "wrev" => 17, "p" => 24, "part" => "2" }, packed({ 1001 => 24 }))
frames(40)
check("an event that adds a companion and then takes them away for good takes them, one that gives them back keeps them",
      [roster.include?(16), roster.include?(45)], [false, true])

# A world chest the player opened stays open under the world's story, which takes it.
tables(:CHESTS => [chest.new([30, 4, "A"], [501], "2", 22)])
new_game({ 1001 => 23 }, [], 40)
$game_self_switches[[30, 4, "A"]] = true
frames(1)
relay({ "rev" => 18, "wrev" => 18, "p" => 24, "part" => "2" }, packed({ 1001 => 24 }))
frames(40)
check("a world chest the player opened goes to the relay as the player's request", staged("story.writes").flatten(1).map { |kind, key, _value, _site| [kind, key] }.include?([2, [30, 4, "A"]]), true)
relay({ "rev" => 19, "part" => "2" }, packed({ 1001 => 24 }, [], { [30, 4, "A"] => true }))
frames(40)
check("and stays open under the world's story, which keeps it, giving nothing", [story.mode, $game_self_switches[[30, 4, "A"]], $game_party.items[501]], [:world, true, 0])

# The Randolphs found follow the Randolph switches on, as two players finding one each at once kept
# one addition.
tables
new_game({ 1001 => 24, 1354 => 1 }, [3101], 40)
frames(1)
relay({ "rev" => 18, "wrev" => 18, "p" => 24, "part" => "2" }, packed({ 1001 => 24, 1354 => 1 }, [3101, 3150]))
frames(40)
check("the Randolphs found count the Randolph switches of the world's story laid over the player's", [story.mode, $game_variables[1354]], [:world, 2])

# Alice's Power-up counts its steps' switches the same way, the 11th and 12th Alipheese twice, from Saja on.
tables
new_game({ 1001 => 24, 1312 => 3, 1353 => 1 }, [3204], 40)
frames(1)
relay({ "rev" => 19, "wrev" => 19, "p" => 24, "part" => "2" }, packed({ 1001 => 24, 1312 => 3, 1353 => 1 }, [3204, 3211]))
frames(40)
check("Alice's Power-up counts every step the world did, two for the 11th and 12th Alipheese", $game_variables[1353], 3)
tables
new_game({ 1001 => 24, 1312 => 3, 1353 => 3 }, [3204, 3211], 40)
frames(1)
relay({ "rev" => 20, "wrev" => 20, "p" => 24, "part" => "2" }, packed({ 1001 => 24, 1312 => 3, 1353 => 3 }, [3204, 3211, 7034]))
frames(40)
check("and stands at 15 once Dark God's Castle 4F ended it", $game_variables[1353], 15)
tables
new_game({ 1001 => 24, 1312 => 2, 1353 => 0 }, [7140], 40)
frames(40)
check("before Saja it is left as the game keeps it", $game_variables[1353], 0)

# What the story could not give shows as nothing given, whatever the log returns.
tables(:REWARDS => [reward.new(:skill, 937, 1, "map:60:2:1", "2", 24, nil, [[:v, 1001, 24]], true),
                    reward.new(:i, 650, 1, "map:60:3:1", "2", 24, nil, [[:v, 1001, 24]], true)])
new_game({ 1001 => 23 }, [], 40)
$game_actors[1].learn_skill(937)
MGQ_Multiplayer::Log.singleton_class.send(:alias_method, :quiet_write, :write)
MGQ_Multiplayer::Log.define_singleton_method(:write) { |message| quiet_write(message); 87 }
frames(1)
relay({ "rev" => 19, "wrev" => 19, "p" => 24, "part" => "2" }, packed({ 1001 => 24 }))
frames(40)
MGQ_Multiplayer::Log.singleton_class.send(:alias_method, :write, :quiet_write)
check("a skill Luka knows and an item the game lacks are no gifts", $logs.grep(/the story gave the player/), [])

# A key item whose event is only there to play comes up to its amount, unless the story took it
# since.
tables(:KEY_ITEMS => [key_item.new(505, 1, "map:29:35:2", "1", 7, nil, [[:v, 1001, 7]], false),
                      key_item.new(503, 1, "map:6:33:1", "1", 7, nil, [[:v, 1001, 7]], false),
                      key_item.new(503, -1, "map:7:25:1", "1", 9, nil, [[:v, 1001, 9]], true)])
new_game({ 1001 => 6 }, [], 40)
$game_party.gain_item($data_items[505], 1)
frames(1)
relay({ "rev" => 21, "wrev" => 21, "p" => 10, "part" => "1" }, packed({ 1001 => 10 }))
frames(40)
check("a key item only there to play comes up to its amount, never one the world's story took since",
      [$game_party.items[505], $game_party.items[503]], [1, 0])

# A key item the story's place owes comes to a player who lacks it, whatever gave it before.
tables(:KEY_ITEMS => [key_item.new(501, 1, "map:2:5:1", "1", 7, :alice, [[:v, 1001, 7], [:s, 5001]], true),
                      key_item.new(501, 1, "map:2:5:2", "1", 7, :ilias, [[:v, 1001, 7], [:s, 5001]], true),
                      key_item.new(505, 1, "map:29:35:2", "1", 7, nil, [[:v, 1001, 7]], true),
                      key_item.new(505, -1, "map:30:1:1", "1", 8, nil, [[:v, 1001, 8]], true)])
new_game({ 1001 => 9 }, [5001, 5], 40)
frames(1)
relay({ "rev" => 23, "wrev" => 23, "p" => 9, "part" => "1" }, packed({ 1001 => 9 }, [5001]))
frames(40)
check("a player whose own story is past a key item's row but who never got it gets it, on their side once",
      [$game_party.items[501], $game_party.items[505]], [1, 0])
$game_party.items[501] = 0
frames(40)
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "24", :relay => true)
frames(1)
relay({ "rev" => 24, "wrev" => 24, "p" => 9, "part" => "1" }, packed({ 1001 => 9 }, [5001]))
frames(40)
check("and gets it again once it is gone, its row long done", $game_party.items[501], 1)

# A player whose story went past the choice of a side without one is asked once, and their side's
# key items come.
tables(:KEY_ITEMS => [key_item.new(501, 1, "map:2:5:1", "1", 7, :alice, [[:v, 1001, 7], [:s, 5001]], true),
                      key_item.new(501, 1, "map:2:5:2", "1", 7, :ilias, [[:v, 1001, 7], [:s, 5001]], true)])
new_game({ 1001 => 9 }, [5001], 40)
$game_message = Game_Message.new
frames(1)
relay({ "rev" => 26, "wrev" => 26, "p" => 9, "part" => "1" }, packed({ 1001 => 9 }, [5001]))
frames(40)
check("a player without a side is asked whom they take along, and gets no side's key item yet",
      [$game_message.choices, $game_message.choice_cancel_type, $game_party.items[501]], [["Alice", "Ilias"], 0, 0])
frames(40)
check("and asked only once while the question is open", $game_message.choices, ["Alice", "Ilias"])
$game_message = Game_Message.new
frames(40)
check("and again once something cleared the question", $game_message.choices, ["Alice", "Ilias"])
choose = $game_message.choice_proc
$game_message = Game_Message.new
choose.call(0)
frames(40)
check("taking Alice keeps the side, brings her along and gives the side's key item",
      [$game_switches[4], $game_switches[5], roster.include?(5), $game_party.items[501], $game_message.choices], [true, false, true, 1, []])
check("and the save notes it as the player's own side", MGQ_MpWorldCatchup.ledger["side"], "alice")

# A player whose save came onto a route without a side of their own, as a world's starting save
# brings the creator's, is asked too; the answer leaves the switches, which tell the route there.
# The same save of the player's own is not asked.
tables(:JOINS => REAL_JOINS.select { |row| [5, 26].include?(row.actor) }, :REMOVALS => REAL_REMOVALS.select { |row| [5, 26].include?(row.actor) })
$data_actors[26] = ActorData.new(26, "Ilias", 1)
new_game({ 1001 => 40, 1141 => 10 }, [4], 80)
$game_party.add_actor(26)
$game_message = Game_Message.new
frames(1)
relay({ "rev" => 27, "wrev" => 27, "p" => 40, "part" => "ad", "route" => "ad" }, packed({ 1001 => 40, 1141 => 10 }, [4]))
frames(40)
check("a player on a route in a save of their own is not asked whom they take along, and keeps everyone",
      [$game_message.choices, roster.include?(26)], [[], true])
new_game({ 1001 => 40, 1141 => 10 }, [4], 80)
MGQ_MpStoryState.note_other_start
$game_party.add_actor(26)
$game_message = Game_Message.new
frames(1)
relay({ "rev" => 28, "wrev" => 28, "p" => 40, "part" => "ad", "route" => "ad" }, packed({ 1001 => 40, 1141 => 10 }, [4]))
frames(40)
check("a player on a route without a side of their own is asked whom they take along, and keeps everyone meanwhile",
      [$game_message.choices, roster.include?(26)], [["Alice", "Ilias"], true])
choose = $game_message.choice_proc
$game_message = Game_Message.new
choose.call(0)
frames(40)
check("taking Alice notes the side, leaves the route's switches and takes away Ilias, whom the Angelic Dominion never gives an Alice picker",
      [MGQ_MpWorldCatchup.ledger["side"], $game_switches[4], $game_switches[5], roster.include?(26), $logs.grep(/Ilias left the player's roster/).size],
      ["alice", true, false, false, 1])

# A player on Ilias's side who lost the Remina Key Card to Sonya's defeat and loaded a save without
# it gets it back from the generated rows, as one on Alice's side does.
tables(:KEY_ITEMS => REAL_KEY_ITEMS.select { |row| row.item == 557 })
new_game({ 1001 => 33, 1075 => 12, 1076 => 6 }, [5], 40)
frames(1)
relay({ "rev" => 27, "wrev" => 27, "p" => 33, "part" => "2" }, packed({ 1001 => 33, 1075 => 13, 1076 => 6 }, [5, 2308]))
frames(40)
check("a player on Ilias's side whose world got the Remina Key Card gets it back after losing it",
      [DATA::KEY_ITEMS.map(&:side).sort, $game_party.items[557]], [[:alice, :ilias], 1])

# An event that gives a key item and takes it back in the same run owes nothing, and the other key
# items still come.
tables(:KEY_ITEMS => [key_item.new(556, 1, "map:124:49:1", "1", 7, nil, [[:v, 1001, 7], [:v, 1084, 2]], true),
                      key_item.new(505, 1, "map:29:35:2", "1", 7, nil, [[:v, 1001, 7]], true),
                      key_item.new(556, -1, "map:124:49:1", "1", 7, nil, [[:v, 1001, 7], [:v, 1084, 2]], true)])
new_game({ 1001 => 6 }, [], 40)
frames(1)
relay({ "rev" => 25, "wrev" => 25, "p" => 9, "part" => "1" }, packed({ 1001 => 9, 1084 => 2 }))
frames(40)
check("a key item one event gives and takes back stays away, and the others come",
      [$game_party.items[556], $game_party.items[505], $logs.grep(/failed/)], [0, 1, []])

# The catch-up looks at everything on entering and on a level up: the player's own values the
# story sets, the story's skills and its companions.
setting = DATA::Setting
tables(:SETTINGS => [setting.new(:encounters, 0, false, "map:545:1:1", "1", 0, nil, [[:v, 1001, 0]], true),
                     setting.new(:v, 1002, 1, "map:545:1:1", "1", 0, nil, [[:v, 1001, 0]], true),
                     setting.new(:encounters, 0, true, "map:6:30:2", "1", 7, nil, [[:v, 1001, 7]], true),
                     setting.new(:v, 1002, 2, "map:6:30:2", "1", 7, nil, [[:v, 1001, 7]], true)],

       :REWARDS => [reward.new(:skill, 930, 1, "map:6:30:2", "1", 7, nil, [[:v, 1001, 7]], true)],
       :JOINS => [join.new(77, 77, "map:6:30:2", "1", 7, nil, [[:v, 1001, 7]], 1, :start, 1, true)])
new_game({ 1001 => 9, 1002 => 1 }, [], 40)
$game_system.encounter_disabled = true
frames(1)
relay({ "rev" => 25, "wrev" => 25, "p" => 9, "part" => "1" }, packed({ 1001 => 9 }))
frames(40)
check("on entering, the encounters move on from an earlier step's to the latest step's, the return point stays away from its event's map, and Luka learns the skill he lacks",
      [$game_system.encounter_disabled, $game_variables[1002], $game_actors[1].instance_variable_get(:@skills).include?(930)], [false, 1, true])
check("and a story companion missing from the roster joins at their gate", $game_party.all_members.map(&:id).include?(77), true)
$game_party.remove_actor(77)
$game_variables[1002] = 9
$game_system.encounter_disabled = true
# Stands in for an event page.
encounter_page = Struct.new(:list)
# Stands in for a map event whose page that applies now is the one it holds.
map_event = Struct.new(:proper) { def find_proper_page; proper; end }
$game_map.events[1] = map_event.new(encounter_page.new([RPG::EventCommand.new(136, 0, [0])]))
$game_map.map_id = 4
MGQ_MpWorldCatchup.level_up
frames(40)
check("a level up looks again: a value of the player's own making stays, and the encounters stay with a map that sets them",
      [$game_variables[1002], $game_system.encounter_disabled], [9, true])
check("and one gone from the roster joins again", $game_party.all_members.map(&:id).include?(77), true)
[[nil, "no page applies now"], [encounter_page.new([RPG::EventCommand.new(136, 0, [1])]), "the page that applies now turns them on too"],
 [encounter_page.new([RPG::EventCommand.new(101, 0, [])]), "the page that applies now leaves them alone, as an opening's page of an earlier step"]].each do |page, why|
  $game_map.events[1] = map_event.new(page)
  $game_system.encounter_disabled = true
  MGQ_MpWorldCatchup.level_up
  frames(40)
  check("the story turns the encounters on where #{why}", $game_system.encounter_disabled, false)
end
$game_map.events.clear
$game_map.map_id = 3

# The game over's return point goes by the route under way, never a finished route's rows.

# Starts a game, lets the catch-up look at everything once and answers the return point.
#
# @param variables [Hash] Variables by id.
# @param switches [Array<Integer>] Switches on.
# @param told [Array, nil] The world's story the player plays, nil for none.
# @return [Integer] The return point's variable.
settled = lambda do |variables, switches, told = nil|
  new_game(variables, switches, 40)
  story.instance_variable_set(:@mode, told ? :world : nil)
  catchup.instance_variable_set(:@world_told, told && catchup.values(told))
  catchup.look
  story.instance_variable_set(:@mode, nil)
  $game_variables[1002]
end
tables(:SETTINGS => REAL_SETTINGS)
check("a player on Monster Lord after clearing Angel Destruction keeps the return point of their route",
      settled.call({ 1001 => 40, 1142 => 1, 1002 => 112 }, [7096]), 112)
check("also further along it", settled.call({ 1001 => 40, 1142 => 23, 1002 => 81 }, [7096]), 81)
check("as without the cleared route", settled.call({ 1001 => 40, 1142 => 1, 1002 => 112 }, []), 112)
check("back at the Great Decision after a route the return point the decision set stays",
      settled.call({ 1001 => 39, 1069 => 4, 1002 => 3 }, [7096]), 3)
told_on_route = []
told_on_route[1001] = 40
told_on_route[1141] = 70
check("a world's story on another route sets none of its return points",
      settled.call({ 1001 => 40, 1142 => 1, 1002 => 112 }, [7096], [[], told_on_route, {}]), 112)
$game_map.map_id = 634
check("a return point left at Adramelech moves on to Part 2's on the map of its event once the story is past him",
      [settled.call({ 1001 => 19, 1032 => 7, 1002 => 19 }, []), settled.call({ 1001 => 17, 1032 => 7, 1002 => 19 }, [])], [2, 19])
$game_map.map_id = 3
on_san_ilia = { 1001 => 40, 1142 => 46, 1169 => 26, 1002 => 112 }
check("a player elsewhere keeps their return point when the world's story reaches one inside a scene another player plays",
      settled.call(on_san_ilia, []), 112)
$game_map.map_id = 1904
check("but takes it on that scene's map", settled.call(on_san_ilia, []), 98)
$game_map.map_id = 3

# A player behind keeps the return point of their own part.
new_game({ 1001 => 7, 1002 => 2 }, [], 12)
frames(1)
checkpoint("1", packed({ 1001 => 18, 1050 => 9 }))
frames(70)
check("a player behind keeps the return point of their own part under its checkpoint", [story.mode, $game_variables[1001], $game_variables[1002]], [:behind, 18, 2])

# A vehicle no event of the story gave yet leaves its map, as Galda and the ship parked on the
# field by a new game whose setup never ran; one the player rides stays until they got off.

# Answers the map a vehicle stands on.
#
# @param type [Symbol] The vehicle.
# @return [Integer] The map, 0 for none.
vehicle_map = lambda { |type| $game_map.vehicle(type).instance_variable_get(:@map_id) }
tables(:VEHICLES => [DATA::Vehicle.new(2, "map:645:33:1", "3", 37, nil, [[:v, 1001, 37]], true)])
new_game({ 1001 => 9 }, [], 40)
$game_map.vehicle(:airship).set_location(2, 186, 1)
$game_map.vehicle(:ship).set_location(2, 306, 2)
$game_player.vehicle = $game_map.vehicle(:ship)
frames(1)
relay({ "rev" => 26, "wrev" => 26, "p" => 9, "part" => "1" }, packed({ 1001 => 9 }))
frames(40)
check("on entering, Galda parked on the field before the story gave it leaves, the ship the player rides stays",
      [vehicle_map.call(:airship), vehicle_map.call(:ship)], [0, 2])
$game_player.vehicle = nil
frames(40)
check("and the ship leaves once the player got off", vehicle_map.call(:ship), 0)
new_game({ 1001 => 34 }, [], 40)
$game_map.vehicle(:airship).set_location(2, 237, 239)
frames(1)
relay({ "rev" => 27, "wrev" => 27, "p" => 37, "part" => "3" }, packed({ 1001 => 37 }))
frames(40)
check("Galda stays once the world's story is past the event that gives it", vehicle_map.call(:airship), 2)
new_game({ 1001 => 9 }, [], 12)
$game_map.vehicle(:airship).set_location(2, 237, 239)
frames(1)
checkpoint("1", packed({ 1001 => 18 }), "rev" => 61, "part" => "3", "checkpoints" => "1,2")
frames(40)
check("but leaves for a player behind whose own story has not given it", [story.mode, vehicle_map.call(:airship)], [:behind, 0])

# A vehicle the story gave that stands on no map comes back where a new game parks it, once a
# checkpoint or the world's story past its event is laid over; one on a map stays where it is.
tables(:VEHICLES => [DATA::Vehicle.new(2, "map:645:33:1", "3", 37, nil, [[:v, 1001, 37]], true),
                     DATA::Vehicle.new(0, "map:33:50:1", "2", 24, nil, [[:v, 1001, 24]], true)])
new_game({ 1001 => 36 }, [], 40)
$game_map.vehicle(:airship).set_location(0, 0, 0)
frames(1)
checkpoint("3", packed({ 1001 => 39 }), "rev" => 62, "part" => "ad", "route" => "ad", "checkpoints" => "1,2,3")
frames(70)
check("once a checkpoint past its event is written into the story of a player behind, Galda is back at its start on the field, the boat without one stays off",
      [story.mode, $game_variables[1001], $game_map.vehicle(:airship).spot, vehicle_map.call(:boat)], [:behind, 39, [2, 186, 1], 0])
new_game({ 1001 => 34 }, [], 40)
$game_map.vehicle(:airship).set_location(0, 0, 0)
$game_map.vehicle(:ship).set_location(0, 0, 0)
frames(1)
relay({ "rev" => 63, "wrev" => 63, "p" => 37, "part" => "3" }, packed({ 1001 => 37 }))
frames(40)
check("the world's story past its event laid over brings Galda back to its start, not the ship no event gave",
      [story.mode, $game_map.vehicle(:airship).spot, vehicle_map.call(:ship)], [:world, [2, 186, 1], 0])
$game_map.vehicle(:airship).set_location(2, 237, 239)
MGQ_MpWorldCatchup.level_up
frames(40)
check("a Galda on a map stays where it is", $game_map.vehicle(:airship).spot, [2, 237, 239])
$game_map.vehicle(:airship).set_location(0, 0, 0)
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "64", :relay => true)
frames(1)
relay({ "rev" => 64, "wrev" => 64, "p" => 37, "part" => "3" }, packed({ 1001 => 37, 1050 => 10 }))
frames(40)
check("a Galda gone while the player plays the world's story is back with the next story laid over", $game_map.vehicle(:airship).spot, [2, 186, 1])
$game_map.vehicle(:airship).set_location(0, 0, 0)
$game_player.vehicle = $game_map.vehicle(:airship)
MGQ_MpWorldCatchup.level_up
frames(40)
check("and one the player rides is never moved", vehicle_map.call(:airship), 0)
$game_player.vehicle = nil

# A companion the world shared comes with the story values their own join stands for.
$data_actors[540] = ActorData.new(540, "Amira", 6)
$game_variables[1009] = 0
MGQ_MpWorldCatchup.level_up
frames(40)
check("without Amira the rabbit quest stays where it is", $game_variables[1009], 0)
$game_party.add_actor(540)
MGQ_MpWorldCatchup.level_up
frames(40)
check("with Amira in the roster her information network stands at 2, so her information in the Pocket Castle opens", $game_variables[1009], 2)
$game_variables[1009] = 5
MGQ_MpWorldCatchup.level_up
frames(40)
check("and a quest further along stays", $game_variables[1009], 5)
$game_party.remove_actor(540)

# The catch-up completing the orbs plays the event that moves the story on, which only the orbs'
# events call.
tables(:KEY_ITEMS => [key_item.new(542, 1, "map:149:107:1", "2", 30, nil, [[:v, 1001, 30], [:v, 1068, 3]], true)])
new_game({ 1001 => 30 }, [], 40)
[537, 538, 540, 541].each { |id| $game_party.gain_item($data_items[id], 1) }
frames(1)
$setups = []
relay({ "rev" => 22, "wrev" => 22, "p" => 31, "part" => "2" }, packed({ 1001 => 31, 1068 => 3 }))
frames(40)
check("a player the catch-up gives the last orb plays the orbs' event",
      [$game_party.items[542], $setups.map { |list| list.map { |entry| [entry.code, entry.parameters] } }], [1, [[[117, [330]], [0, []]]]])
frames(40)
check("once", $setups.size, 1)

# Past the world's log the replay of the world's run of the orbs' event carries the story on, so
# the catch-up never plays it.
new_game({ 1001 => 30 }, [], 40)
[537, 538, 540, 541, 542].each { |id| $game_party.gain_item($data_items[id], 1) }
frames(1)
$setups = []
relay({ "rev" => 23, "wrev" => 23, "p" => 31, "part" => "2", "start" => [25, 0, 0, 0], "log" => packed({ 1001 => 25 }) }, packed({ 1001 => 31, 1068 => 3 }))
frames(40)
check("a player who holds every orb past the world's log leaves the orbs' event to the replay", $setups.size, 0)

# A shared companion the player's own story gave them and took away for a while stays away.
tables(:REMOVALS => [removal.new(16, 16, "map:50:1:1", "1", 14, nil, [[:v, 1001, 14]], false, 5)],
       :JOINS => [join.new(16, 16, "map:70:1:1", "1", 5, nil, [[:v, 1001, 5]], 10, :start, 3, true)])
$sharing = :story
new_game({ 1001 => 16 }, [], 15)
frames(1)
relay({ "rev" => 23, "wrev" => 23, "p" => 16, "part" => "1", "comps" => "16" }, packed({ 1001 => 16 }))
frames(40)
check("a shared companion whose join the player's story passed is not brought back", roster.include?(16), false)
check("nor listed as due on the Unlocks page", catchup.unlocks.any? { |unlock| unlock.id == 16 }, false)

# A shared companion joins a second playthrough's player whose story took them away on the first.
tables(:REMOVALS => [removal.new(16, 16, "map:50:1:1", "1", 14, nil, [[:v, 1001, 14]], true, 5)],
       :JOINS => [join.new(16, 16, "map:70:1:1", "1", 20, nil, [[:v, 1001, 20]], 10, :start, 3, true)])
[[1, true], [0, false]].each do |playthrough, joins|
  new_game({ 1001 => 16, 912 => playthrough }, [], 15)
  frames(1)
  relay({ "rev" => 20, "wrev" => 20, "p" => 16, "part" => "1", "comps" => "16" }, packed({ 1001 => 16, 912 => playthrough }))
  frames(40)
  check("a shared companion #{joins ? 'joins' : 'never joins'} a player whose story passed their removal on playthrough #{playthrough}", roster.include?(16), joins)
  check("and the Unlocks page #{joins ? 'lists' : 'never lists'} them on playthrough #{playthrough}", catchup.unlocks.any? { |unlock| unlock.id == 16 }, joins)
end
$sharing = :off

# A save that noted the player behind holds their story until the world's story came.
tables
new_game({ 1001 => 7 }, [], 5)
check("a fresh game holds nothing before the world's story came", [story.mode, catchup.holds_story?], [nil, false])
frames(1)
checkpoint("1", packed({ 1001 => 18 }))
frames(70)
story.loaded(:load)
catchup.loaded
check("a save behind on its part's checkpoint holds the story from the moment it loads", [story.mode, catchup.holds_story?], [nil, true])
$game_variables[1001] = 26
check("but not once its story is in another part", catchup.holds_story?, false)

# A Part 3 player skips the route the world finished, yet gets its rows as for a part passed.
tables(:REWARDS => [reward.new(:skill, 930, 1, "map:1697:7:2", "ad", 6, nil, [[:v, 1141, 6]], true)],
       :KEY_ITEMS => [key_item.new(504, 1, "map:1193:5:1", "ad", 10, nil, [[:v, 1141, 10]], true)],
       :JOINS => [join.new(80, 80, "map:1193:18:1", "ad", 6, nil, [[:v, 1141, 6]], 60, :floor, 3, true)])
new_game({ 1001 => 36 }, [], 40)
frames(1)
on_mr = { "rev" => 40, "part" => "mr", "route" => "mr", "done" => "ad", "checkpoints" => "1,2,3,ad" }
checkpoint("3", packed({ 1001 => 39 }), on_mr)
frames(70)
$game_actors[1].level = 65
$messages.clear
frames(40)
moved("3", "world", packed({ 1001 => 40, 1142 => 5 }, [7096]), on_mr)
frames(40)
check("at Part 3's gate the relay moves the player on to the world's route, never the finished one's checkpoint",
      [$messages.first, story.mode, $game_variables[1142], $game_switches[7096]], ["Level 65 reached: catching up to the world's story.", :world, 5, true])
check("with the skill, the key item and the companion of the finished route",
      [MGQ_MpStoryState.knows?($game_actors[1], 930), $game_party.items[504], roster.include?(80), $game_actors[80].base_level], [true, 1, true, 60])

# A Raid World started from a shared save: what the save's own
# story played is the player's, so its rows give nothing, take no companion and hold nothing back,
# whether the world's story starts from the save or is laid over it.
tables(:REWARDS => [reward.new(:i, 600, 2, "map:36:17:1", "1", 6, nil, [[:v, 1001, 6]])],
       :REMOVALS => [removal.new(16, 16, "map:50:1:1", "1", 14, nil, [[:v, 1001, 14]], true)],
       :JOINS => [join.new(77, 77, "map:20:1:1", "1", 9, nil, [[:v, 1001, 9]], 7, :start),
                  join.new(80, 80, "map:21:1:1", "2", 22, nil, [[:v, 1001, 22]], 20, :floor)])

# Starts a game from the shared save: its story at 25, with the Slime and the Harpy in the party.
from_save = lambda do
  new_game({ 1001 => 25 }, [4], 30)
  [77, 80].each { |id| $game_party.add_actor(id) }
end
from_save.call
frames(1)
relay({ "rev" => 1, "part" => "2" }, packed({ 1001 => 25 }, [4]))
frames(40)
check("the first player from the save starts the world's story with it, held by nothing",
      [story.mode, $game_variables[1001], catchup.holds_story?], [:world, 25, false])
check("and the rows the save played give nothing, take nobody and bring nobody back",
      [$game_party.items[600].to_i, roster, $logs.grep(/the story gave the player/)], [0, [1, 77, 80], []])
from_save.call
frames(1)
relay({ "rev" => 1, "wrev" => 1, "p" => 25, "part" => "2" }, packed({ 1001 => 25 }, [4]))
frames(40)
check("the next player from the save plays the world's story at once, the save's rows still theirs",
      [story.mode, catchup.holds_story?, $game_party.items[600].to_i, roster, $logs.grep(/the story gave the player/)], [:world, false, 0, [1, 77, 80], []])

# A telling the player watched takes the key items its scene took, which only the teller's game
# ran, and one the player's own event took stays taken.
tables(:KEY_ITEMS => [key_item.new(600, 1, "map:340:23:1", "2", 29, nil, [[:v, 1001, 29], [:v, 1011, 2]], true),
                      key_item.new(600, -1, "map:88:4:1", "2", 29, nil, [[:v, 1001, 29], [:v, 1011, 4]], true)])

# Starts a game holding the key item, lets the player's story take a teller's value as watched and
# answers how many of the item the player holds then.
#
# @param value [Integer] The value of variable 1011 the teller's scene sets.
# @param before [Proc, nil] What happens before the value comes.
# @return [Integer] The items held.
watch = lambda do |value, before = nil|
  new_game({ 1001 => 29, 1011 => 3 }, [], 40)
  $game_party.gain_item($data_items[600], 1)
  frames(1)
  relay({ "rev" => 22, "wrev" => 22, "p" => 29, "part" => "2" }, packed({ 1001 => 29, 1011 => 3 }))
  frames(40)
  before.call if before
  MGQ_MpStoryKeys.applying { $game_variables[1011] = value }
  frames(40)
  $game_party.items[600].to_i
end
check("a telling the player watched takes the key item its scene took, once the player is free",
      watch.call(4, lambda { catchup.watched { MGQ_MpStoryState.deep_copy(catchup.story_now) } }), 0)
check("the player's own event taking it gets nothing back from the catch-up, though the same step gave it",
      watch.call(4, lambda { $game_party.lose_item($data_items[600], 1) }), 0)

# Makina come by level, one of each, whatever chest gave them, once a player of the world got them.
makina = DATA::Makina
tables(:MAKINA => [makina.new(700, 6, "map:215:23:1"), makina.new(701, 30, "map:218:21:1")])
new_game({ 1001 => 9 }, [], 10)
$game_party.gain_item($data_items[701], 3)
frames(1)
relay({ "rev" => 30, "wrev" => 30, "p" => 9, "part" => "1" }, packed({ 1001 => 9 }))
frames(40)
check("a Makina no player of the world got stays away, and the copies the player got stay theirs",
      [$game_party.items[700], $game_party.items[701], $game_self_switches[[0, 701, "F"]], $derived, $messages.grep(/Makina/)], [0, 3, true, nil, []])
$game_self_switches[[0, 700, "F"]] = true
frames(40)
check("once another player got it and the player's level reaches its area level, its chest plays in the player's game, without a notice",
      [$derived.uniq, $messages.grep(/Makina/)], [[[{ "site" => ["map", 215, 23, 1] }, "makina:700 at level 6"]], []])
$derived = nil
$game_self_switches[[0, 701, "F"]] = nil
$game_party.items[701] = 1
catchup.instance_variable_set(:@audit_due, true)
frames(40)
check("a Makina the player held before the world noted it counts as found on the next look, as on entering or after a load", $game_self_switches[[0, 701, "F"]], true)
$game_party.gain_item($data_items[700], 1)
$derived = nil
frames(40)
check("a Makina the player holds plays no chest", $derived, nil)
$game_party.lose_item($data_items[701], 1)
frames(40)
check("one above the player's level plays none", $derived, nil)
$game_actors[1].cap = 10
frames(40)
check("nor one above a cap of another mod the player is held at", $derived, nil)
$game_actors[1].cap = 9999

# A key item or a job or race item another player's event gave comes by the replay of that run
# (story_keys.rbx), never by a mark of its own: a gain notes nothing for the world but a Makina,
# which every player gets by level.
new_game({ 1001 => 9 }, [], 10)
frames(1)
relay({ "rev" => 30, "wrev" => 30, "p" => 9, "part" => "1" }, packed({ 1001 => 9 }))
frames(40)
$game_party.gain_item($data_items[616], 1)
$game_party.gain_item($data_items[701], 1)
check("a job item the player gains notes nothing for the world, a Makina is noted for Makina by level",
      [$game_self_switches[[0, 616, "F"]] ? true : false, $game_self_switches[[0, 701, "F"]] ? true : false], [false, true])

# A job item an event gives once behind its own self switch comes by the world's story, though the
# rows' ledger noted it done.
$data_items[622] = RPG::Item.new(622, "Soul of the Warrior God", "[Job] Allows access to advanced Warrior jobs.")
king = reward.new(:i, 622, 1, "map:551:17:1", "1", 9, nil, [[:v, 1001, 9], [:s, 2311], [:ss, 551, 17, "B"]], true)
tables(:REWARDS => [king])
new_game({ 1001 => 9 }, [2311], 10)
frames(1)
relay({ "rev" => 37, "wrev" => 37, "p" => 9, "part" => "1" }, packed({ 1001 => 9 }, [2311]))
frames(40)
catchup.ledger["done"]["g:map:551:17:1:i622"] = true
catchup.hand_ledger
check("a gift behind its event's self switch stays away while no story ran the event", $game_party.items[622], 0)
story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "38", :relay => true)
frames(1)
relay({ "rev" => 38, "wrev" => 38, "p" => 9, "part" => "1" }, packed({ 1001 => 9 }, [2311], { [551, 17, "B"] => true }))
frames(40)
check("and comes once the world's story ran it, its row noted done", $game_party.items[622], 1)

# Notes of an earlier version give once what a map event's row noted done but never gave.
tables(:REWARDS => [reward.new(:i, 600, 2, "map:36:17:1", "1", 6, nil, [[:v, 1001, 6]], true),
                    reward.new(:i, 541, 1, "ce:287", "1", 6, nil, [[:v, 1001, 6]], true),
                    reward.new(:w, 4112, 1, "map:1583:17:1", "1", 6, nil, [[:v, 1001, 6]], true)],
       :TAKEN_ITEMS => [[:w, 4112]])
new_game({ 1001 => 9 }, [], 10)
frames(1)
relay({ "rev" => 39, "wrev" => 39, "p" => 9, "part" => "1" }, packed({ 1001 => 9 }))
frames(40)
notes = catchup.ledger
notes.delete("rewards_repaired")
notes["done"]["g:map:36:17:1:i600"] = notes["done"]["g:ce:287:i541"] = notes["done"]["g:map:1583:17:1:w4112"] = true
catchup.hand_ledger
$data_weapons[4112] = RPG::Item.new(4112, "Fallen Sword Angel Halo")
catchup.instance_variable_set(:@audit_due, true)
frames(40)
check("notes of an earlier version give a map event's reward the player lacks once, a common event's and one an event takes away not",
      [$game_party.items[600], $game_party.items[541], $game_party.items[4112], catchup.ledger["rewards_repaired"]], [2, 0, 0, true])
$game_party.items[600] = 0
catchup.instance_variable_set(:@audit_due, true)
frames(40)
check("and never again", $game_party.items[600], 0)

# The skills the story and its quests teach companions reach every player's companions.
lesson = DATA::Lesson
$data_skills[544] = RPG::Skill.new(544, "Defense +10%")
$data_skills[545] = RPG::Skill.new(545, "Defense +20%")
$data_skills[592] = RPG::Skill.new(592, "Flight")
tables(:LESSONS => [lesson.new(16, 544, "map:12:64:1", "1", 12, nil, [[:v, 1001, 12], [:v, 1041, 2]], true),
                    lesson.new(16, 545, "map:645:26:1", "1", 12, nil, [[:v, 1001, 12], [:v, 1041, 3]], true),
                    lesson.new(16, 592, "map:1848:15:1", "1", 12, nil, [[:v, 1001, 12], [:v, 1041, 5]], true),
                    lesson.new(45, 544, "map:12:64:1", "1", 12, nil, [[:v, 1001, 12], [:v, 1041, 2]], true)])
new_game({ 1001 => 12 }, [], 40)
$game_party.add_actor(16)
frames(1)
relay({ "rev" => 33, "wrev" => 33, "p" => 12, "part" => "1" }, packed({ 1001 => 12, 1041 => 3 }))
frames(40)
# Lists the skills a companion learned.
#
# @param id [Integer] The companion.
# @return [Array<Integer>] The skills, sorted.
taught = lambda { |id| $game_actors[id].instance_variable_get(:@skills).sort }
check("a companion in the roster learns the skills of the quest steps the world passed before the player came, never those of a step ahead",
      taught.call(16), [544, 545])
check("one outside the roster learns nothing", taught.call(45), [])
$game_party.add_actor(45)
frames(40)
check("and learns them once they join", taught.call(45), [544])

# The classes and races the story and its quests give reach every player's characters.
class_level = DATA::ClassLevel
# Stands in for RPG::Class, a class or a race.
ClassData = Struct.new(:id, :name)
$data_classes = Array.new(400)
$data_classes[362] = ClassData.new(362, "Lowly Angel")
$data_classes[184] = ClassData.new(184, "Vampire")
$data_classes[301] = ClassData.new(301, "Fighter")
tables(:CLASS_LEVELS => [class_level.new(1, 362, 1, "map:128:59:1", "1", 17, nil, [[:v, 1001, 17]], true),
                         class_level.new(1, 184, 1, "map:477:162:1", "1", 20, nil, [[:v, 1001, 20]], true),
                         class_level.new(45, 301, 10, "map:835:6:1", "1", 13, nil, [[:v, 1001, 13]], true)])
new_game({ 1001 => 17 }, [], 40)
$game_actors[45].level_list[301] = 3
frames(1)
relay({ "rev" => 34, "wrev" => 34, "p" => 17, "part" => "1" }, packed({ 1001 => 17 }))
frames(40)
check("Luka gets the race of a story step the world passed before the player came, never one of a step ahead",
      [$game_actors[1].level_list[362], $game_actors[1].level_list[184]], [1, nil])
check("a companion outside the roster gets nothing", $game_actors[45].level_list[301], 3)
$game_party.add_actor(45)
frames(40)
check("and gets the class at its level once they join", $game_actors[45].level_list[301], 10)

# The World overview's Unlocks page lists what the catch-up hands out by level that the world
# unlocked.
tables(:JOINS => [join.new(77, 77, "map:6:30:2", "1", 7, nil, [[:v, 1001, 7]], 7, :start, 1, true),
                  join.new(16, 16, "map:9:1:1", "1", 15, nil, [[:v, 1001, 15]], 20, :floor, 1, true)],
       :MAKINA => [makina.new(700, 6, "map:215:23:1"), makina.new(701, 30, "map:218:21:1")])
$sharing = :all
new_game({ 1001 => 9 }, [], 10)
frames(1)
relay({ "rev" => 31, "part" => "1", "comps" => "80" }, packed({ 1001 => 9 }, [], { [0, 700, "F"] => true }))
frames(40)
check("the Levels page lists by level the Makina a player of the world got, due while its chest waits to play, the companions of joins the world's story got past and those it shares, never a join it has not reached",
      catchup.unlocks.map { |unlock| [unlock.level, unlock.kind, unlock.name, unlock.got, unlock.due] },
      [[6, :makina, "Auto Crossbow", false, true], [7, :companion, "Slime", true, false], [9, :companion, "Harpy", true, false]])
check("with the level the catch-up counts", catchup.counted_level, 10)
new_game({ 1001 => 9 }, [], 10)
frames(1)
checkpoint("1", packed({ 1001 => 18 }), "rev" => 32, "part" => "2", "comps" => "80")
frames(40)
check("a world past the player's part lists moving on from it at its gate",
      catchup.unlocks.select { |unlock| unlock.kind == :story }.map { |unlock| [unlock.level, unlock.name, unlock.got, unlock.due] }, [[25, "Part 1", false, false]])
$sharing = :off

# A join the story takes back in the same step only brings its companion along for a visit.
tables(:JOINS => [join.new(77, 77, "map:6:30:2", "1", 7, nil, [[:v, 1001, 7]], 7, :start, 1, true),
                  join.new(16, 16, "map:6:40:1", "1", 7, nil, [[:v, 1001, 7], [:v, 1050, 1]], 8, :start, 5, true)],
       :REMOVALS => [removal.new(16, 16, "map:6:41:1", "1", 7, nil, [[:v, 1001, 7], [:v, 1050, 2]], true, 3)])
new_game({ 1001 => 9, 1050 => 1 }, [], 10)
$game_party.add_actor(16)
$game_actors[16].level = 50
frames(1)
relay({ "rev" => 33, "wrev" => 33, "p" => 9, "part" => "1" }, packed({ 1001 => 9, 1050 => 1 }))
frames(40)
check("a companion on a visit is not listed, nor counted toward the player's level",
      [catchup.unlocks.map { |unlock| [unlock.kind, unlock.name] }, catchup.counted_level], [[[:companion, "Slime"]], 10])
check("nor counted in the catch-up", [catchup.counts?($game_actors[16]), catchup.counts?($game_actors[1])], [false, true])
$game_party.remove_actor(16)
new_game({ 1001 => 9, 1050 => 1 }, [], 10)
frames(1)
relay({ "rev" => 34, "wrev" => 34, "p" => 9, "part" => "1" }, packed({ 1001 => 9, 1050 => 2 }))
frames(40)
check("and a player the world's story carried past the visit does not get the companion", roster.include?(16), false)

# A companion a later removal of the story took away until a later join, as Lazarus for most of
# Part 2, waits for that join, on the Unlocks page as in the catch-up.
tables(:JOINS => [join.new(77, 77, "map:6:30:2", "1", 7, nil, [[:v, 1001, 7]], 7, :start, 1, true),
                  join.new(16, 16, "map:9:1:1", "1", 7, nil, [[:v, 1001, 7]], 8, :start, 1, true),
                  join.new(16, 16, "map:9:3:1", "1", 12, nil, [[:v, 1001, 12]], 8, :start, 1, true)],
       :REMOVALS => [removal.new(16, 16, "map:9:2:1", "1", 8, nil, [[:v, 1001, 8]], false, 1)])
new_game({ 1001 => 9 }, [], 10)
frames(1)
relay({ "rev" => 35, "wrev" => 35, "p" => 9, "part" => "1" }, packed({ 1001 => 9 }))
frames(40)
check("a companion a removal took away until a later join is neither brought nor listed before it",
      [roster.include?(16), catchup.unlocks.any? { |unlock| unlock.id == 16 }], [false, false])
new_game({ 1001 => 9 }, [], 10)
frames(1)
relay({ "rev" => 36, "wrev" => 36, "p" => 12, "part" => "1" }, packed({ 1001 => 12 }))
frames(40)
check("and both once the world got past the later join", [roster.include?(16), catchup.unlocks.any? { |unlock| unlock.id == 16 }], [true, true])

# What a power-up of the story changes of a character comes to every player the world's story
# carried past it, once their level reaches the level it sets, as the game's own step gives it.
$data_actors[7] = ActorData.new(7, "Alice", 1)
$data_actors[26] = ActorData.new(26, "Ilias", 1)
$data_actors[27] = ActorData.new(27, "Ilias", 1)
Game_Actors::PERSONAS.merge!(7 => 5, 27 => 26)
alice = REAL_ACTOR_CHANGES.find { |row| row.site == "map:1330:15:1" }
check("Alice's power-up turns her into her persona 7 and, on a first playthrough alone, raises her to 250",
      [alice.actor, alice.calls, alice.gate], [5, [[:persona_change, [7], false], [:level_adjust, [7, 250], true]], 250])
# Plays a Raid World's Chaos route whose story carries the player past Alice's power-up.
#
# @param variables [Hash] The player's own variables.
# @param switches [Array<Integer>] The player's own switches.
# @param level [Integer] Luka's level.
# @param companions [Array<Integer>] The companions in the player's roster.
carry_past_power_up = lambda do |variables, switches, level, companions|
  new_game({ 1001 => 40, 1143 => 21 }.merge(variables), switches, level)
  companions.each { |id| $game_party.add_actor(id) }
  frames(1)
  relay({ "rev" => 50, "wrev" => 50, "p" => 40, "r1143" => 21, "part" => "chaos", "route" => "chaos" }, packed({ 1001 => 40, 1143 => 21 }.merge(variables), switches))
  frames(16)
  story.pushed(MGQ_MpOverworldSync::STORY_FIELD => "51", :relay => true)
  frames(1)
  relay({ "rev" => 51, "wrev" => 51, "p" => 40, "r1143" => 21, "part" => "chaos", "route" => "chaos" },
        packed({ 1001 => 40, 1143 => 21, 1347 => 3, 1353 => 15 }.merge(variables), switches + [3193]))
  frames(40)
end
tables(:ACTOR_CHANGES => [alice])
carry_past_power_up.call({}, [], 249, [5])
check("a player the world's story carried past it waits for that level", [story.mode, $game_actors[5].persona], [:world, 5])
$game_actors[1].level = 250
frames(40)
check("then Alice takes her persona and her level", [$game_actors[5].persona, $game_actors[5].base_level], [7, 250])
check("and the log tells it", $logs.grep(/took what map:1330:15:1 changes/).size, 1)
$game_party.persona_change(5)
frames(40)
check("once: the persona the player picks again later stays", $game_actors[5].persona, 5)
carry_past_power_up.call({ 1347 => 3, 1353 => 15 }, [3193], 250, [5])
check("a player whose own game played the step keeps what they made of it", [$game_actors[5].persona, $game_actors[5].base_level], [5, 1])
carry_past_power_up.call({ 912 => 1 }, [], 250, [5])
check("a later playthrough takes the persona but not the level, as the step's own branch", [$game_actors[5].persona, $game_actors[5].base_level], [7, 1])

# A companion in the roster whom a join brings in another of their personas takes it at the gate.
ilias = REAL_JOINS.find { |row| row.persona == 27 && row.site == "map:1574:28:1" }
check("Ilias's power-up brings her persona 27 at 250", [ilias.actor, ilias.gate, ilias.rule], [26, 250, :floor])
tables(:JOINS => [ilias])
carry_past_power_up.call({}, [], 250, [26])
check("so Ilias of the roster takes that persona and its level", [roster.include?(26), $game_actors[26].persona, $game_actors[26].base_level], [true, 27, 250])

# A lost raid boss battle's defeat takes items its undo gives back, so the catch-up waits meanwhile.
# Stands in for the freeze engine: a lost raid boss battle's defeat runs while $holding.
module MGQ_MpRaidFreeze; def self.holding_writes?; $holding ? true : false; end; def self.unjournaled; yield; end; end
tables
new_game({ 1001 => 7 }, [], 12)
frames(1)
$holding = true
checkpoint("1", packed({ 1001 => 18 }), "rev" => 40)
frames(40)
check("nothing the relay hands is written while a lost raid boss battle's defeat runs", [story.mode, $game_variables[1001]], [nil, 7])
$holding = false
frames(2)
check("but once it ended", [story.mode, $game_variables[1001]], [:behind, 18])

# A prize of the Reaper's Battle Challenge (87) comes by the replay of the run that won it, never
# by its row, while the Medal King's free gift reaches every player whose story holds its switch and
# who holds none of it.
tables(:REWARDS => [reward.new(:i, 600, 1, "ce:148", nil, nil, nil, [[:v, 87, 1]], true),
                    reward.new(:i, 700, 1, "ce:140", nil, nil, nil, [[:s, 2324]], true),
                    reward.new(:i, 701, 1, "ce:140", nil, nil, nil, [[:s, 2325]], true)],
       :PRIZE_SWITCHES => [2324, 2325])
new_game({ 87 => 2 }, [2324, 2325], 10)
$game_party.gain_item($data_items[701], 1)
catchup.look
check("a prize's row gives nothing, the Medal King's gift comes once to a player who holds none",
      [$game_party.item_number($data_items[600]), $game_party.item_number($data_items[700]), $game_party.item_number($data_items[701])], [0, 1, 1])

# Classic worlds have no catch-up.
$raid = false
new_game({ 1001 => 3 }, [], 99)
frames(40)
check("a Classic world holds no story", catchup.holds_story?, false)
