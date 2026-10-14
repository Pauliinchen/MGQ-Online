#----------------------------------------------------------------
#  session.rb
#
#  Changelog:
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

require_relative "battle"

# One battle played turn by turn: it runs in a thread of its own and stops whenever the battle
# needs the party's commands or a choice, until the client answers.
class BattleSession
  # Seconds a session waits for the client's answer before the battle is given up.
  ANSWER_TIMEOUT = 300

  # The answer that ends a session whose client went away.
  GIVE_UP = :give_up

  # Raised in the battle's thread when the client gave the battle up.
  class GivenUp < StandardError; end

  # Starts the battle.
  #
  # @param request [Hash] The battle's request: troop, party or save (a save file in base64),
  #   system (the system save in base64), seed, switches, variables.
  def initialize(request)
    @events = Queue.new
    @answers = Queue.new
    @sent = 0
    @thread = Thread.new { play(request) }
  end

  # Waits for what the battle needs next, or for its end.
  #
  # @return [Hash] The event: commands, choice, end or error, with the log lines since the last.
  def next_event
    event = @events.pop
    log = HeadlessBattle.log || []
    event.merge(log: log[@sent..] || []).tap { @sent = log.size }
  end

  # Hands the client's answer to the waiting battle.
  #
  # @param answer [Object] The commands by actor id, or a choice's index.
  def answer(answer)
    @answers << answer
  end

  # Gives the battle up, as when its client went away.
  def give_up
    @answers << GIVE_UP
    @thread.join(5)
  end

  # Tells whether the battle is over.
  #
  # @return [Boolean] Whether it is.
  def over?
    !@thread.alive?
  end

  private

  # Plays the battle, sending each request for an answer and the end as events.
  #
  # @param request [Hash] The battle's request.
  def play(request)
    outcome = HeadlessBattle.run(
      troop_id: request.fetch("troop").to_i,
      party: (request["party"] || []).map { |id, level| [id.to_i, level.to_i] },
      save: request["save"]&.unpack1("m"),
      system: request["system"]&.unpack1("m"),
      seed: (request["seed"] || 1).to_i,
      switches: (request["switches"] || {}).to_h { |id, value| [id.to_i, value == true] },
      variables: (request["variables"] || {}).to_h { |id, value| [id.to_i, value.to_i] },
      commander: method(:ask_commands),
      chooser: method(:ask_choice)
    )
    @events << { event: "end", result: outcome[:result].to_s, turns: outcome[:turns],
                 frames: outcome[:frames], party: outcome[:party], troop: outcome[:troop] }
  rescue GivenUp
    @events << { event: "end", result: "given_up" }
  rescue Exception => e
    @events << { event: "error", error: "#{e.class}: #{e.message}", at: e.backtrace&.first(6) }
  end

  # Asks the client for the party's commands and fills the actors' actions with them; an actor
  # the client names no commands for lets the game's auto battle choose.
  #
  # @param actors [Array<Game_Actor>] The actors whose commands are due.
  # @param turn [Integer] The turn.
  def ask_commands(actors, turn)
    @events << { event: "commands", turn: turn, actors: actors.map { |actor| describe_actor(actor) },
                 enemies: $game_troop.alive_members.map { |enemy| describe_enemy(enemy) } }
    commands = wait_answer
    actors.each do |actor|
      wanted = commands.is_a?(Hash) ? commands[actor.id.to_s] : nil
      wanted ? apply_commands(actor, Array(wanted)) : actor.make_auto_battle_actions
    end
  end

  # Asks the client which choice to pick.
  #
  # @param names [Array<String>] The choices' names.
  # @return [Integer] The index picked.
  def ask_choice(names)
    @events << { event: "choice", choices: names }
    wait_answer.to_i
  end

  # Waits for the client's answer.
  #
  # @return [Object] The answer.
  def wait_answer
    answer = @answers.pop(timeout: ANSWER_TIMEOUT)
    raise GivenUp if answer.nil? || answer == GIVE_UP

    answer
  end

  # Fills an actor's actions with the client's commands, one per action, and lets the game's auto
  # battle choose those the client named nothing or nothing usable for.
  #
  # @param actor [Game_Actor] The actor.
  # @param commands [Array<Hash>] Each action's command: skill, item, attack or guard, and target.
  def apply_commands(actor, commands)
    actor.make_auto_battle_actions
    actor.actions.each_with_index do |action, index|
      command = commands[index]
      next unless command.is_a?(Hash)

      if command["skill"] && actor.usable?($data_skills[command["skill"].to_i])
        action.set_skill(command["skill"].to_i)
      elsif command["item"] && actor.usable?($data_items[command["item"].to_i])
        action.set_item(command["item"].to_i)
      elsif command["guard"]
        action.set_guard
      elsif command["attack"]
        action.set_attack
      else
        next
      end
      action.target_index = command["target"].to_i if command.key?("target")
    end
  end

  # What the client needs to know of an actor to pick its commands.
  #
  # @param actor [Game_Actor] The actor.
  # @return [Hash] Its id, name, HP, MP, SP, actions and the skills it can use now.
  def describe_actor(actor)
    skills = actor.skills.select { |skill| skill.battle_ok? && actor.usable?(skill) }
    { id: actor.id, name: actor.name, hp: actor.hp, mhp: actor.mhp, mp: actor.mp, mmp: actor.mmp,
      tp: actor.tp, actions: actor.actions.size,
      skills: skills.map { |skill| { id: skill.id, name: skill.name, target: target_kind(skill) } } }
  end

  # What the client needs to know of an enemy to target it.
  #
  # @param enemy [Game_Enemy] The enemy.
  # @return [Hash] Its index, name and HP.
  def describe_enemy(enemy)
    { index: enemy.index, name: enemy.name, hp: enemy.hp, mhp: enemy.mhp }
  end

  # Whom a skill targets, as the client picks its target.
  #
  # @param skill [RPG::Skill] The skill.
  # @return [String] enemy, ally or none (a skill without a pick).
  def target_kind(skill)
    return "none" unless skill.need_selection?

    skill.for_opponent? ? "enemy" : "ally"
  end
end
