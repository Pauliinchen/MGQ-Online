#----------------------------------------------------------------
#  story_state_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-12: Covered unpacking a packed story, which refuses a text longer than any story and one that unpacks too far
#      Paulinchen  2026-10-10: Created
#
#----------------------------------------------------------------

# Covers story_state.rbx with core_log.rbx: joining a story with the player's own chests, which
# leaves out the chests the player never opened, the skills and companions it grants, which give
# nothing for a skip whatever writing the log returns, and unpacking a story another game packed,
# which refuses a text no story takes.

require_relative "support"

# The log, which answers with a byte count as File#write does.
module MGQ_Multiplayer; module Log; def self.write(m); $log << m; 87; end; end; end
$log = []
module MGQ_MpCoop; module Scope; def self.raid?; true; end; end; end
module MGQ_MpCoopEvents; def self.chest_keys; []; end; def self.chest_key?(_key); false; end; end
ActorData = Struct.new(:id, :name)
SkillData = Struct.new(:id, :name)
$data_actors = Array.new(100)
[[1, "Luka"], [16, "Granberia"], [45, "Tamamo"]].each { |id, name| $data_actors[id] = ActorData.new(id, name) }
$data_skills = Array.new(1000)
[[930, "Angel Dance"], [937, "Demon Decapitation"]].each { |id, name| $data_skills[id] = SkillData.new(id, name) }

# Luka, whose skills the game keeps in @skills.
class Game_Actor
  attr_reader :id
  def initialize(id); @id = id; @skills = []; end
  def learn_skill(id); @skills |= [id]; end
end
# The game's actors by id.
class Game_Actors
  def initialize; @data = {}; end
  def [](id); $data_actors[id] ? (@data[id] ||= Game_Actor.new(id)) : nil; end
end
# The party: its own companions in @include_actors, the team of up to two in @actors.
class Game_Party
  def initialize; @include_actors = []; @actors = []; end
  def add_actor(id); add_stand_actor(id); @actors |= [id]; end
  def add_stand_actor(id); @include_actors |= [id]; end
  def party_member_full?; @actors.size >= 2; end
  def all_members; @actors.map { |id| $game_actors[id] }; end
end

load_script "story_state"
state = MGQ_MpStoryState
$game_actors = Game_Actors.new
$game_party = Game_Party.new
$game_party.add_actor(1)
$game_party.add_actor(16)
$game_actors[1].learn_skill(937)

# Joining a story keeps the player's own chests, and only those their own story holds.
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

# A skip of the story's grants gives nothing, whatever writing the log returns.
check("a log line gives nothing back, the first time and every time after", [state.log("a line"), state.log_once(:key, "once"), state.log_once(:key, "once")], [nil, nil, nil])
check("a skill Luka knows or the game lacks is learned by nobody", [state.learn(937), state.learn(999)], [nil, nil])
check("a companion in the roster or missing from the game joins nobody", [state.join(16), state.join(99), state.bring(16), state.bring(99)], [nil, nil, nil, nil])
check("and the log tells why", $log.grep(/skipped/).size, 6)
check("a skill Luka lacks is learned under its name", [state.learn(930), state.knows?($game_actors[1], 930)], ["Angel Dance", true])
check("a companion joins the roster, or the party while it has room, under their name",
      [state.join(45), state.roster_ids], ["Tamamo", [1, 16, 45]])

# Unpacking a story another game packed reads back what was packed, and refuses a text no story
# takes before it runs the game out of memory.
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
