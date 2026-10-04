#----------------------------------------------------------------
#  coop_npcs_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-04: Created
#
#----------------------------------------------------------------

# Covers coop_npcs.rbx where events meet party members: a member blocks an event that walks on its
# own, but never a story's forced route or an event while the leader's story plays.

require_relative "support"

module MGQ_Multiplayer; module Log; def self.write(m); puts "  log: #{m}"; end; end; end
module MGQ_MpCoop; def self.route(*); end; end
module MGQ_MpCoopEvents; def self.telling?; $telling; end; end
class Game_Map; def update(main = false); end; end
class Game_Event
  attr_accessor :move_route_forcing, :priority
  def initialize; @priority = 1; end
  def update_self_movement; end
  def collide_with_characters?(x, y); x == 9; end
  def near_the_player?; false; end
  def move_toward_player; end
  def normal_priority?; @priority == 1; end
end

load_script "coop_npcs"

Ghost = Struct.new(:x, :y)
MGQ_MpCoopNpcs.instance_variable_set(:@blockers, [Ghost.new(3, 4)])
event = Game_Event.new
$telling = false
check("a member blocks an event walking on its own", event.collide_with_characters?(3, 4), true)
check("but not another tile", event.collide_with_characters?(3, 5), false)
check("the game's own characters still block", event.collide_with_characters?(9, 0), true)
event.move_route_forcing = true
check("a story's forced route walks through a member", event.collide_with_characters?(3, 4), false)
event.move_route_forcing = false
$telling = true
check("as does any event while the leader's story plays", event.collide_with_characters?(3, 4), false)
$telling = false
event.priority = 0
check("an event below the characters never collides", event.collide_with_characters?(3, 4), false)
