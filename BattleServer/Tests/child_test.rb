#----------------------------------------------------------------
#  child_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Tests of how server.rb prepares a battle's child before it plays, with the sandbox standing in
# for sandbox.rb: what the client hears when the child cannot be closed in.

require "json"
require "socket"
require_relative "support"
require_relative File.join(LIB_DIR, "..", "server")

# Stands in for the sandbox: available, and failing as $sandbox_error says.
module Sandbox
  # Tells that children can be sandboxed.
  #
  # @return [Boolean] true.
  def self.available?
    true
  end

  # Fails with $sandbox_error, or closes nothing in.
  #
  # @param _root [String] The game folder.
  def self.enter(_root)
    raise $sandbox_error if $sandbox_error
  end
end

# Prepares a child as server.rb does, over a socket pair.
#
# @return [Array(Boolean, String)] Whether the child may play and what its client heard.
def enter_child
  client, child = UNIXSocket.pair rescue Socket.pair(:INET, :STREAM, 0)
  may_play = BattleServer.send(:enter_child, child)
  child.close
  [may_play, client.read.to_s]
ensure
  client&.close
end

$sandbox_error = SecurityError.new("the sandbox could not drop root")
may_play, heard = enter_child
check("a child that cannot drop root does not play", may_play, false)
check("and tells its client so", heard.empty? ? nil : JSON.parse(heard), { "ok" => false, "error" => "the battle could not be sandboxed: the sandbox could not drop root" })

$sandbox_error = nil
check("a child the sandbox closed in plays and tells its client nothing yet", enter_child, [true, ""])
