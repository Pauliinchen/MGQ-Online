#----------------------------------------------------------------
#  story_state_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-12: Covered unpacking a packed story and its refusals
#      Paulinchen  2026-10-10: Created
#
#----------------------------------------------------------------

# Covers story_state.rbx: mixing a story with the player's own chests, the skills and companions a
# story grants, and unpacking a story another game packed.

require_relative "support"

# Stands in for the mod's log: records each line in $log and answers with a byte count, as
# File#write does.
module MGQ_Multiplayer; module Log; def self.write(m); $log << m; 87; end; end; end
$log = []
# Stands in for the battle scope: every battle is in a Raid World.
module MGQ_MpCoop; module Scope; def self.raid?; true; end; end; end
# Stands in for the shared events: no event is a chest.
module MGQ_MpCoopEvents; def self.chest_keys; []; end; def self.chest_key?(_key); false; end; end
# Stands in for RPG::Actor.
ActorData = Struct.new(:id, :name)
# Stands in for RPG::Skill.
SkillData = Struct.new(:id, :name)
$data_actors = Array.new(100)
[[1, "Luka"], [16, "Granberia"], [45, "Tamamo"]].each { |id, name| $data_actors[id] = ActorData.new(id, name) }
$data_skills = Array.new(1000)
[[930, "Angel Dance"], [937, "Demon Decapitation"]].each { |id, name| $data_skills[id] = SkillData.new(id, name) }

# Stands in for an actor, whose learned skills the game keeps in @skills.
class Game_Actor
  attr_reader :id
  # Starts the actor with no skills.
  def initialize(id); @id = id; @skills = []; end
  # Records a learned skill.
  def learn_skill(id); @skills |= [id]; end
end
# Stands in for the game's actors by id.
class Game_Actors
  # Starts with no actor made.
  def initialize; @data = {}; end
  # Answers the actor of an id, made on first use, or nil for one $data_actors lacks.
  def [](id); $data_actors[id] ? (@data[id] ||= Game_Actor.new(id)) : nil; end
end
# Stands in for the party: its own companions in @include_actors, the team of up to two in @actors.
class Game_Party
  # Starts the party empty.
  def initialize; @include_actors = []; @actors = []; end
  # Adds a companion to the roster and the team.
  def add_actor(id); add_stand_actor(id); @actors |= [id]; end
  # Adds a companion to the roster only.
  def add_stand_actor(id); @include_actors |= [id]; end
  # Answers whether the team holds two.
  def party_member_full?; @actors.size >= 2; end
  # Answers the team's actors.
  def all_members; @actors.map { |id| $game_actors[id] }; end
end

load_script "story_state"
state = MGQ_MpStoryState
$game_actors = Game_Actors.new
$game_party = Game_Party.new
$game_party.add_actor(1)
$game_party.add_actor(16)
$game_actors[1].learn_skill(937)

# Mixing a story with the player's own takes the chests from the player's story and drops those
# it lacks.
chests = (1..5100).map { |event| [100 + event / 100, event, "A"] }
opened = chests[7]
shut_by_story = chests[8]
others = chests[9]
kept_shut = chests[10]
story = [[], [], { [3, 1, "A"] => true, others => true, shut_by_story => false, kept_shut => true }]
personal = [[], [], { opened => true, shut_by_story => true, kept_shut => false }]
mixed = state.mix(story, personal, chests)
check("a chest the player opened stays open, also one the story has shut, and the story's own self switches stay",
      [mixed[2][opened], mixed[2][shut_by_story], mixed[2][[3, 1, "A"]]], [true, true, true])
check("a chest the player holds shut stays shut, as a key of its own", [mixed[2].key?(kept_shut), mixed[2][kept_shut]], [true, false])
check("and a chest the player never opened is left out, not written as an empty key", [mixed[2].key?(others), mixed[2].size], [false, 4])

# A skipped grant answers nil whatever writing the log returns, and a granted one answers its name.
check("a log line gives nothing back, the first time and every time after", [state.log("a line"), state.log_once(:key, "once"), state.log_once(:key, "once")], [nil, nil, nil])
check("a skill Luka knows or the game lacks is learned by nobody", [state.learn(937), state.learn(999)], [nil, nil])
check("a companion in the roster or missing from the game joins nobody", [state.join(16), state.join(99), state.bring(16), state.bring(99)], [nil, nil, nil, nil])
check("and the log tells why", $log.grep(/skipped/).size, 6)
check("a skill Luka lacks is learned under its name", [state.learn(930), state.knows?($game_actors[1], 930)], ["Angel Dance", true])
check("a companion joins the roster, or the party while it has room, under their name",
      [state.join(45), state.roster_ids], ["Tamamo", [1, 16, 45]])

# Unpacking a story another game packed reads back what was packed, and refuses a text no story
# takes before it runs the game out of memory.

# Runs a block and answers the message of the ArgumentError it raises.
#
# @return [String, nil] The message, nil when the block raises none.
refusal = lambda do |&block|
  begin
    block.call
    nil
  rescue ArgumentError => e
    e.message
  end
end
check("a packed story unpacks to the lists that were packed",
      state.unpack(state.pack("s" => "1,2,3", "v" => "5:n7")), { "s" => "1,2,3", "v" => "5:n7" })
bomb = [Zlib::Deflate.deflate("s=" + "1," * 10_000_000)].pack("m0")
check("a small text that unpacks far past any story is refused as it unpacks",
      [bomb.bytesize < state::MAX_PACKED_BYTES, refusal.call { state.unpack(bomb) }.to_s[/unpacked past/]],
      [true, "unpacked past"])
check("and so is a whole story written with it", refusal.call { state.decode_full("z" => bomb) }.to_s[/unpacked past/], "unpacked past")
check("a text longer than any story is refused before it is read",
      refusal.call { state.unpack("A" * (state::MAX_PACKED_BYTES + 4)) }.to_s[/more than any story/], "more than any story")
