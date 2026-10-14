#----------------------------------------------------------------
#  try_boot.rb
#
#  Changelog:
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

require_relative "../lib/boot"

Boot.run
puts "actors #{$data_actors&.size}, skills #{$data_skills&.size}, troops #{$data_troops&.size}"
