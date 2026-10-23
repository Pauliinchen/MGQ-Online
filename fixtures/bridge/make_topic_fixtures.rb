#----------------------------------------------------------------
#  make_topic_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Writes the bridge's contract fixtures next to this file, <topic>/<case>.request.marshal and
# <case>.reply.marshal: what the scripts send and what the core answers. MGQOnline.Bridge.Tests
# checks that the core answers each request with the reply's bytes, the script tests that the
# scripts send the request's bytes and read the reply. An empty reply file stands for no reply.
# Run it again only when a case changes:
#
#   ruby fixtures/bridge/make_topic_fixtures.rb
#
# The topic "test.append" of the cases takes a String, which the tests collect; "no.such.topic" has
# no handler. The cases under envelope/ are calls of "no.such.topic".

# The error the core answers for a topic without a handler.
UNKNOWN = { "ok" => false, "error" => "unknown_topic", "text" => "There is no topic no.such.topic." }

CASES = {
  "batch/in_order" => [[["test.append", "a"], ["test.append", "b"], ["test.append", "c"]], nil],
  "batch/failed_entries" => [
    [["test.append", "a"], ["no.such.topic", nil], ["test.append", 1], ["test.append", "d"]],
    { "ok" => true, "value" => [
      { "topic" => "no.such.topic", "error" => "unknown_topic", "text" => "There is no topic no.such.topic." },
      { "topic" => "test.append", "error" => "bad_request", "text" => "Expected a String, found an Integer." },
    ] },
  ],
  "envelope/unknown_topic" => [{ "seat" => 2 }, UNKNOWN],
}

CASES.each do |name, (request, reply)|
  folder = File.join(__dir__, File.dirname(name))
  Dir.mkdir(folder) unless File.directory?(folder)
  File.binwrite(File.join(__dir__, "#{name}.request.marshal"), Marshal.dump(request))
  File.binwrite(File.join(__dir__, "#{name}.reply.marshal"), reply.nil? ? "" : Marshal.dump(reply))
end

puts "Wrote #{CASES.size} cases."
