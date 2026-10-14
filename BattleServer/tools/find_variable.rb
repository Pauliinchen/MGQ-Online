#----------------------------------------------------------------
#  find_variable.rb
#
#  Changelog:
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

require_relative "../lib/boot"

# Lists the common events that set a game variable: ruby find_variable.rb <variable id>
variable = (ARGV[0] || 41).to_i
Boot.run
$data_common_events.each do |event|
  next unless event&.list

  event.list.each do |command|
    next unless command.code == 122

    first, last = command.parameters[0], command.parameters[1]
    next unless (first..last).include?(variable)

    puts "common event #{event.id} #{event.name.inspect} (trigger #{event.trigger}, switch #{event.switch_id}): " \
         "#{command.parameters.inspect}"
  end
end
puts "variable #{variable} is named #{$data_system.variables[variable].inspect}"
