#----------------------------------------------------------------
#  story_replay.rbx
#
#  Changelog:
#      Paulinchen  2026-11-05: Handed the DLL the keys and the player's own things as [kind, key] with their values, sites and commands' places as plain values, and what the player holds whole for the DLL to sum up
#                            - Read the story markers from story_ids.rbx
#                            - Took a found item a replay uses up from the receiver, but none a story reset takes, and dropped the copy got as found, which the story replay replaces
#                            - Told whether a replay goes the receiver's own way, whose companion joins as their own
#                            - Took the runs handed to the player only while no screen waits, see MGQ_MpCoop.screens_wait?
#                            - Counted its asks by the bridge's frame
#                            - Gave the player the found items another player's battle drops gave, with their notice
#      Paulinchen  2026-11-01: Handed the question screen what a choice's cancel answers
#                            - Let a replay cost the receiver nothing, taking back of the gold and the items only what it gave
#                            - Followed the opener's path through the checks of what the party holds and of the event's own self switches
#                            - Counted a replay whose receiver answered a question other than the opener as done with their own answer
#                            - Let the copy of a key item the receiver got as found stand for the replay's gain of it
#                            - Named an input by its command's place among the commands the events database keeps, and a choice by its Show Choices command
#                            - Named an extended choice by the script command that shows it, and asked the receiver only the answers the game shows
#                            - Handed the DLL the shapes of the player's lists of a run's choices, by which it finds them in its events database
#      Paulinchen  2026-10-31: Replayed a run with the inputs the DLL leaves of the opener's, asking the receiver the choices that are theirs
#                            - Asked the receiver a number, item or present the record lacks
#                            - Committed a replay only once it finished
#                            - Created
#
#----------------------------------------------------------------

# Replays a run of an event that another player's game ran, in the receiving game ("same event, own
# game"): the receiver's own interpreter runs the page's real list, bound to its map and event,
# against the receiver's own save. What the event does for that player, it does, as the game would.
#
# The replay works at the engine's objects. While its fiber runs, the world's and the game's work
# keys live in a view that only the replay sees and that is dropped at its end; the receiver's own
# keys and holdings are staged, and the replay keeps them only once it finished and reached its step;
# the screen, the message, the player, the timer, the map's display and events, the sound and the
# scenes are stand-ins or closed; and every input (a choice, a number, an item, a present, a random
# draw, a read of the player's or an event's position, the timer, a key press, a battle's outcome,
# a check of what the party holds or of the event's own self switch) is answered from the opener's
# record by the place of the command that asked for it, so the receiver gets what the opener got. A
# replay costs the receiver nothing: it takes back only what it gave. An input the
# record lacks is the receiver's own: a choice, a number, an item or a present is asked of them on
# the choices' screen, and while that screen asks only choices, any other of them stops the replay,
# which waits like a check that fails; a battle counts as won; any other input reads their own game.
#
# The record names each input by the place of its command, see input_at, which the opener's game
# records by, and by what it read; values are whole numbers, a yes or no 1 or 0.
#
# The runs handed to the player wait in order and are taken one at a time while the player stands
# free on the map: the DLL decides by rule 2 whether a run is done, waits or is replayed, and which
# page; a replay that asks the player waits for their answer on the choices' screen; the DLL builds
# the one notice from what the player held before and after. The save keeps the DLL's log of the
# steps its game took, with the runs that wait to be taken, so a save keeps what was handed to it.
#
# It must never break the game, so a failing replay stops, drops what it staged and logs.
module MGQ_MpStoryReplay
  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "story replay"

  # The DLL's topics of runs handed to the player, see StoryTopics.Replay.cs: whether and how a run
  # is taken, a replay's end, the waiting runs due again, the save's log, a run's entry written for
  # a message and read back, an entry of the player's own history, and a run handed to the player,
  # which the log keeps until it is taken.
  TAKE_TOPIC = "story.replay_take"
  DONE_TOPIC = "story.replay_done"
  DUE_TOPIC = "story.replay_due"
  LOG_TOPIC = "story.replay_log"
  LOG_SAVE_TOPIC = "story.replay_log_save"
  WIRE_TOPIC = "story.replay_wire"
  UNWIRE_TOPIC = "story.replay_unwire"
  DERIVE_TOPIC = "story.replay_derive"
  QUEUE_TOPIC = "story.replay_queue"

  # The field of $game_system the save keeps the DLL's log in.
  LOG_FIELD = :@mgq_mp_replay_log

  # The kind of the player's own things a run reads that stands for what they hold, see holdings_read.
  HOLDINGS = "holdings"

  # Frames between two asks whether a waiting run is due again, two seconds.
  DUE_FRAMES = 120

  # How often a question to the DLL is asked again with the values it named lacking.
  NEEDS_ROUNDS = 3

  # The runs handed to the player that wait to be taken, oldest first, as the save's log in the DLL
  # keeps them too.
  @waiting = []

  # The replay that waits for the player's answer: :replay, :entry, :had and :before; nil for none.
  @asking = nil

  # The frame of the last ask whether a waiting run is due again.
  @due_at = 0

  # The codes of the commands the events database keeps, as MGQOnline.Data's EventSchema.KeptCodes:
  # a list's shape covers them, and an input's place counts them.
  KEPT_CODES = [
    101, 102, 103, 104, 105, 111, 117, 118, 119, 121, 122, 123, 125, 126, 127, 128, 129, 132, 133, 136, 201, 202, 203,
    206, 222, 282, 283, 285, 301, 303, 353, 354, 355, 402, 403, 404, 411, 412, 999
  ].freeze

  # The bits a list's shape keeps: 24, so every step stays a Fixnum on the game's 32-bit Ruby.
  SHAPE_MASK = 0xFFFFFF

  # How many lists' counts of kept commands and shapes stay kept at most.
  MAX_KEPT_LISTS = 256

  # The code of a script's continuation line.
  SCRIPT_LINE = 655

  # How often a replay's fiber resumes at most in one go, far past any list the game's events walk,
  # so a list that waits for something the replay never brings cannot hang the game.
  MAX_RESUMES = 100_000

  # The command codes the replay leaves out, those the generator's gate (ReplayChannels.cs) classes
  # as the presentation or the opener's play alone: scrolling text, the timer, the battle music, the
  # access settings, the window color, the transfer, events' places, the map's scroll, vehicles
  # boarded, transparency, animations, balloons, erasing events, the followers, the screen's
  # effects, waits, pictures, weather, sound, movies, the map's name, tileset, battleback and
  # parallax, shops, name input, the battle's animation and abort, the menu, saving, game over and
  # the title.
  CLOSED_CODES = [105, 124, 132, 133, 134, 135, 136, 137, 138, 201, 203, 204, 206, 211, 212, 213, 214, 216, 217,
                  221, 222, 223, 224, 225, 230, 231, 232, 233, 234, 235, 236, 241, 242, 243, 244, 245, 246, 249, 250,
                  251, 261, 281, 282, 283, 284, 302, 303, 337, 340, 351, 352, 353, 354].freeze

  # The interpreter's script functions the replay leaves out, those the gate classes as the
  # presentation or the opener's play alone: battle graphics and skill names, music, the title
  # screen, zoom, transfers, vehicles, the scenes they open, and the developer's text export.
  CLOSED_FUNCTIONS = %w[battler_graphic_hide battler_graphic_show display_skill_name clear_skill_name play_base_bgm
                        set_title_bg set_title_bgm set_airship_bgm map_zoom forced_transfer forced_get_on_boat
                        forced_get_on_ship forced_get_on_airship forced_get_off_vehicle call_party_edit call_synthesize
                        call_slot_scene call_poker_scene call_casino_prize start_poker edit_multiparty retry_battle
                        battle_memory common_data_to_text common_text_to_data].map { |name| name.to_sym }.freeze

  # The reads of a character's place that are inputs.
  POSITION_READS = [:x, :y, :direction, :real_x, :real_y, :screen_x, :screen_y].freeze

  # The reads of the player's state that are inputs, besides the place.
  PLAYER_READS = [:in_boat?, :in_ship?, :in_airship?, :in_vehicle?, :normal_walk?, :dash?].freeze

  # The keys script 167's input_keys notes, in the order the record numbers them.
  KEY_SYMBOLS = [:U, :D, :L, :R, :B1, :B2, :B3, :B4, :B5, :B6, :B7, :B8].freeze

  # The conditional branches whose result is an input, by their type: a key held, and the checks a
  # replay follows the opener through, the event's own self switch and the gold, items, weapons and
  # armors the party holds.
  BRANCH_INPUTS = { 2 => "branch", 7 => "branch", 8 => "branch", 9 => "branch", 10 => "branch", 11 => "key" }.freeze

  # The game data a Control Variables command reads whose value is an input: the counts of an item,
  # a weapon and an armor the party holds.
  HOLDING_DATA = [0, 1, 2].freeze

  # The game data of another kind a Control Variables command reads, such as the party's gold.
  OTHER_DATA = 7

  # The party's gold among the game data of another kind, whose value is an input too.
  GOLD_DATA = 2

  # The map's methods that change its display, which the replay leaves out, and its refresh, which
  # would read the replay's view into the receiver's events.
  MAP_CLOSED = [:start_scroll, :scroll_down, :scroll_left, :scroll_right, :scroll_up, :set_display_pos, :change_tileset,
                :change_battleback, :change_parallax, :autoplay, :setup, :refresh].freeze

  # The reads of the map that are inputs: what kind of map the opener stood on.
  MAP_READS = [:field?].freeze

  # The map's vehicles in the order Game_Map keeps them.
  VEHICLE_TYPES = [:boat, :ship, :airship].freeze

  # The move route commands that turn a switch on, off, and run a script (Game_Character's
  # ROUTE_SWITCH_ON, ROUTE_SWITCH_OFF and ROUTE_SCRIPT).
  ROUTE_SWITCH_ON = 27
  ROUTE_SWITCH_OFF = 28
  ROUTE_SCRIPT = 45

  # The engine's calls a replay never makes, each [owner, whether the owner's own, methods]: the
  # sound of the Audio functions and of the audio files, the scene manager's moves and a battle's
  # defeat.
  CLOSED_CALLS = [["Audio", true, [:bgm_play, :bgm_stop, :bgm_fade, :bgs_play, :bgs_stop, :bgs_fade, :me_play, :me_stop, :me_fade, :se_play, :se_stop]],
                  ["RPG::BGM", false, [:play, :replay]], ["RPG::BGS", false, [:play, :replay]], ["RPG::ME", false, [:play]], ["RPG::SE", false, [:play]],
                  ["RPG::BGM", true, [:stop, :fade]], ["RPG::BGS", true, [:stop, :fade]], ["RPG::ME", true, [:stop, :fade]], ["RPG::SE", true, [:stop]],
                  ["SceneManager", true, [:call, :goto, :push, :return]], ["BattleManager", true, [:process_defeat]]].freeze

  # The replay whose fiber runs, nil while none does.
  @current = nil

  # Replays a run: binds its page or common event, runs it until it ends or asks the receiver, and
  # puts every object back.
  #
  # @param entry [Hash] The run: "site" (such as "map:215:23:1", pages from 1, or "ce:154"), "map"
  #   (the map a common event ran on, the receiver's own when missing), "start" (the world and work
  #   keys' values at the run's start as the tracks write them, such as {"s2045" => "1"}) and
  #   "inputs" (the record: [at, occurrence, kind, value], see input_at).
  #   "keys" names the step's keys, which the replay must write to keep anything; none for a run that
  #   keeps what it did once it finished.
  # @param options [Hash] :view, a block that tells whether a key of a kind is a world or work key
  #   (the open world's kept keys when missing); :own_write, a block called with each write of the
  #   receiver's own keys it keeps, such as a borrowing guest's keep_own; :page, the page of the run's
  #   event the receiver's game picked, from 1, the run's own when missing; :around_commit, a block
  #   called with the replay and a block that keeps what it did, to measure what changed; :recorded,
  #   the opener's whole record when "inputs" lacks the answers asked of the receiver.
  # @return [Replay, nil] The replay: done, asking or failed; nil for a site the game does not have.
  def self.play(entry, options = {})
    return refuse("a replay asked for #{entry['site']} while #{@current.site} runs") if @current

    Replay.new(entry, options).start
  end

  # The replay whose fiber runs.
  #
  # @return [Replay, nil] The replay, nil while none runs.
  def self.current
    @current
  end

  # Sets the replay whose fiber runs.
  #
  # @param replay [Replay, nil] The replay, nil once it stopped.
  def self.current=(replay)
    @current = replay
  end

  # Reports whether a replay's fiber runs, which keeps the engine's CLOSED_CALLS shut.
  #
  # @return [Boolean] Whether one does.
  def self.running?
    !@current.nil?
  end

  # Names the command an input belongs to: its list and its place among the list's commands the
  # events database keeps (kept_place), which a translation leaves where it was. A command that reads
  # the following lines keeps the place it started at, such as a text with the number it asks; a
  # choice goes by the Show Choices command a text sets up, where the database finds its answers. A
  # command that runs again (a loop) counts its runs as the input's occurrence.
  #
  # What an input reads is its kind: a message's answer ("choice", a choice's place or an extended
  # choice's id; "number"; "item"; "present"), a random draw ("rand"), a key held ("key"), each key
  # pressed while the game read keys ("keys", its place in KEY_SYMBOLS), the map at a place
  # ("location"), a battle's outcome ("battle", 0 won, 1 escaped, 2 lost), a branch's check of the
  # event's own self switch or of what the party holds ("branch", see BRANCH_INPUTS), a count of
  # what the party holds read into a variable ("holding", see holding_read?), or a read of the
  # timer, the map, the player or an event ("timer.sec", "map.field?", "player.x",
  # "event12.direction"). A yes or no is 1 or 0.
  #
  # @param site [Array] The list: ["map", map, event, page from 1] or ["ce", id].
  # @param list [Array<RPG::EventCommand>, nil] The list's commands, nil for none known.
  # @param index [Integer] The command's place in the list.
  # @return [Array] The site and the place, such as [["map", 1994, 42, 1], 12].
  def self.input_at(site, list, index)
    [site, kept_place(list, index)]
  end

  # Names a choice as input_at names an input's command: the Show Choices, or the script command
  # that shows an extended choice, whose last line the interpreter stands at while it waits.
  #
  # @param site [Array] The list, see input_at.
  # @param list [Array<RPG::EventCommand>, nil] The list's commands, nil for none known.
  # @param index [Integer] The place the interpreter stands at.
  # @return [Array] Such as [["map", 6, 30, 2], 1].
  def self.choice_at(site, list, index)
    index = index.to_i
    index -= 1 while list.is_a?(Array) && index > 0 && list[index] && list[index].code == SCRIPT_LINE
    input_at(site, list, index)
  end

  # Tells whether the extended choices window shows an answer that can be picked, as
  # Window_ExChoiceList#make_command_list tells it by the answer's condition, its switches s and
  # variables v.
  #
  # @param condition [String] The condition, such as "v[703] >= 1".
  # @param s [Game_Switches] The switches.
  # @param v [Game_Variables] The variables.
  # @return [Boolean] Whether it does; true for a condition that fails to run, which the game shows.
  def self.ex_choice_enabled?(condition, s, v)
    eval(condition.to_s) ? true : false
  rescue StandardError, SyntaxError => e
    log("the condition #{condition.inspect} of an extended choice failed: #{e.class}: #{e.message}")
    true
  end

  # Counts the commands of a list before a place that the events database keeps, which is the place
  # the database gives the command there; a command it does not keep, such as a text's line, shares
  # the count of the next one it keeps.
  #
  # @param list [Array<RPG::EventCommand>, nil] The commands, nil for none known.
  # @param index [Integer] The place.
  # @return [Integer] The count; the place itself for no list.
  def self.kept_place(list, index)
    return index.to_i unless list.is_a?(Array)

    counts = (@kept_counts ||= {}.compare_by_identity)[list]
    unless counts && counts.size == list.size + 1
      @kept_counts.clear if @kept_counts.size >= MAX_KEPT_LISTS
      kept = 0
      counts = [0] + list.map { |command| kept += 1 if command && kept_code?(command.code); kept }
      @kept_counts[list] = counts
    end
    counts[[[index.to_i, 0].max, list.size].min]
  end

  # Hashes a list's commands the events database keeps as MGQOnline.Data's ListShape does: code,
  # indent and every Integer parameter, in order (fixtures/events/hash_cases.json holds both sides'
  # cases).
  #
  # @param list [Array<RPG::EventCommand>] The commands.
  # @return [Integer] The shape.
  def self.list_shape(list)
    list.inject(0) do |hash, command|
      next hash unless command && kept_code?(command.code)

      hash = (hash * 31 + command.code) & SHAPE_MASK
      hash = (hash * 31 + command.indent) & SHAPE_MASK
      command.parameters.each { |value| hash = (hash * 31 + value) & SHAPE_MASK if value.is_a?(Integer) }
      hash
    end
  end

  # Tells whether the events database keeps the commands of a code.
  #
  # @param code [Integer] The code.
  # @return [Boolean] Whether it does.
  def self.kept_code?(code)
    (@kept_codes ||= Hash[KEPT_CODES.map { |kept| [kept, true] }])[code] == true
  end

  # Tells whether a Control Variables command's read of the game data is a read of what the party
  # holds, which a replay takes from the opener's record.
  #
  # @param type [Integer] The kind of game data.
  # @param param [Integer] Its first parameter: the item, or for OTHER_DATA what is read.
  # @return [Boolean] Whether it is.
  def self.holding_read?(type, param)
    HOLDING_DATA.include?(type) || (type == OTHER_DATA && param == GOLD_DATA)
  end

  # Tells how much of a change of what the receiver holds the replay that runs makes: all of a gain,
  # and of a loss only what the replay itself gained of the same thing, since a replay costs the
  # receiver nothing, but a found item it uses up outside a story reset, which leaves every player
  # who holds it.
  #
  # @param what [Object] What changes: :gold, or the item.
  # @param amount [Integer] The change, below 0 for a loss.
  # @return [Integer] The change to make.
  def self.kept_change(what, amount)
    @current ? @current.kept_change(what, amount) : amount
  end

  # Refuses a replay, which leaves the game as it is.
  #
  # @param message [String] Why, for the log.
  # @return [nil] No replay.
  def self.refuse(message)
    log(message)
    nil
  end

  # Takes a run handed to the player, which waits until it is taken in its turn, in the save's log
  # too.
  #
  # @param entry [Hash] The run's entry, see ReplayEntry.Write in the DLL.
  def self.receive(entry)
    MGQ_Multiplayer::Bridge.call(QUEUE_TOPIC, entry)
    @waiting << entry
    log("entry #{entry['id']} of #{entry['site']} waits to be taken, #{@waiting.size} waiting")
  end

  # Lists the runs that wait to be taken.
  #
  # @return [Array<Hash>] Their entries, oldest first.
  def self.waiting
    @waiting
  end

  # Takes the runs that wait, one at a time, while the player stands free on the map, and asks now
  # and then whether a waiting run is due again. Called after the map's update.
  def self.update
    return unless free?

    due if MGQ_Multiplayer::Bridge.frame_number - @due_at >= DUE_FRAMES
    until @waiting.empty? || @asking
      break unless take(@waiting.first)

      @waiting.shift
    end
  rescue => e
    log_once([:update, e.class], "taking a run failed: #{e.class}: #{e.message}")
  end

  # Reports whether the player stands free on the map, outside their own events, a battle, a
  # transfer and a PvP battle, and no screen waits (MGQ_MpCoop.screens_wait?), so a run handed to
  # them may be taken.
  #
  # @return [Boolean] Whether they do.
  def self.free?
    return false unless MGQ_Multiplayer::Bridge.open? && defined?(MGQ_MpOverworldSync) && MGQ_MpOverworldSync.map_free?
    return false if defined?(MGQ_MpCoop) && MGQ_MpCoop.respond_to?(:screens_wait?) && MGQ_MpCoop.screens_wait?

    !(defined?(MGQ_MpBattlesPvp) && MGQ_MpBattlesPvp::Battle.running?)
  end

  # Takes a run by rule 2: the DLL answers whether it is done, waits, or is replayed on which page
  # with which of the opener's inputs; the choices it leaves out are asked of the player (rule 4).
  # Another player's battle drops give their found items.
  #
  # @param entry [Hash] The run's entry.
  # @return [Boolean] Whether it was taken; false while the DLL cannot decide yet.
  def self.take(entry)
    answer = ask_with_values(TAKE_TOPIC, "entry" => entry, "shapes" => choice_shapes(entry).to_a)
    return false unless answer.is_a?(Hash) && answer["do"]

    start(answer["inputs"] ? entry.merge("inputs" => answer["inputs"]) : entry, answer["page"], entry["inputs"]) if answer["do"] == "replay"
    gain(entry, answer["items"]) if answer["do"] == "gain"
    true
  end

  # Gives the player the found items another player's battle drops gave, and tells the DLL, which
  # answers the notice.
  #
  # @param entry [Hash] The drops' entry.
  # @param items [Array<Array>] Each item's id and how many.
  def self.gain(entry, items)
    had = holdings
    Array(items).each do |id, count|
      item = $data_items[id.to_i]
      next log("entry #{entry['id']} names the item #{id}, which this game lacks") unless item

      $game_party.gain_item(item, count.to_i)
    end
    answer = MGQ_Multiplayer::Bridge.call(DONE_TOPIC, "entry" => entry, "reached" => true, "before" => [], "reads" => [], "had" => had, "has" => holdings)
    notice(answer, had)
  end

  # Hashes the player's own lists of the choices a run's inputs name, by site, by which the DLL
  # finds the choices in its events database.
  #
  # @param entry [Hash] The run's entry.
  # @return [Hash] Site => shape, of the lists the player's game has.
  def self.choice_shapes(entry)
    @site_shapes ||= {}
    shapes = {}
    Array(entry["inputs"]).each do |at, _occurrence, kind, _value|
      site = at.is_a?(Array) ? at[0] : nil
      next unless site && kind == "choice" && !shapes.key?(site)

      @site_shapes.clear if @site_shapes.size >= MAX_KEPT_LISTS
      unless @site_shapes.key?(site)
        list = list_at(site)
        @site_shapes[site] = list ? list_shape(list) : nil
      end
      shapes[site] = @site_shapes[site] if @site_shapes[site]
    end
    shapes
  end

  # Reads the commands of a list of the player's game: a map event's page or a common event.
  #
  # @param site [Array] Such as ["map", 215, 23, 1] (pages from 1) or ["ce", 154].
  # @return [Array<RPG::EventCommand>, nil] The commands, nil for a list the game does not have.
  def self.list_at(site)
    case site[0]
    when "map"
      event = load_data(DataManager.map_file_name(site[1])).events[site[2]]
      page = event && event.pages[site[3] - 1]
      page && page.list
    when "ce"
      common_event = $data_common_events[site[1]]
      common_event && common_event.list
    end
  rescue => e
    log("reading the list of #{site} failed: #{e.class}: #{e.message}")
    nil
  end

  # Asks the DLL a question that reads the player's own things, again with the values it named
  # lacking.
  #
  # @param topic [String] The topic.
  # @param request [Hash] The request.
  # @return [Object] The answer, nil when the DLL did not give one.
  def self.ask_with_values(topic, request)
    values = []
    NEEDS_ROUNDS.times do
      answer = MGQ_Multiplayer::Bridge.call(topic, request.merge("values" => values))
      return answer unless answer.is_a?(Hash) && answer["needs"]

      Array(answer["needs"]).each { |kind, key| values << [kind, key, own_value(kind, key)] }
    end
    nil
  end

  # Replays a run on the page the player's game picked.
  #
  # @param entry [Hash] The run's entry.
  # @param page [Integer, nil] The page, from 1; nil for a common event.
  # @param recorded [Array<Array>, nil] The opener's whole record, before the DLL left out the
  #   choices asked of the player; nil when the entry holds it.
  def self.start(entry, page, recorded = nil)
    state = { :entry => entry }
    replay = play(entry, :view => view_test, :own_write => own_write, :page => page, :recorded => recorded,
                         :around_commit => lambda { |kept, keep| committing(state, kept, keep) })
    return log("entry #{entry['id']} of #{entry['site']} could not be replayed") unless replay

    state[:replay] = replay
    replay.state == :asking ? ask_player(state) : finish(state)
  end

  # Measures what a replay keeps: the step's keys and what the player holds just before, and what
  # they hold just after, so values the game changed while the replay waited count for neither.
  #
  # @param state [Hash] The replay's entry, which takes :before, :had and :has.
  # @param replay [Replay] The replay.
  # @param keep [Proc] Keeps what the replay did.
  def self.committing(state, replay, keep)
    state[:before] = Array(state[:entry]["keys"]).map { |kind, key, _value| [kind, key, own_value(kind, key)] }
    state[:had] = holdings
    keep.call
    state[:has] = holdings + medals_of(replay.medals)
  end

  # Tells the DLL a replay ended: one it kept reached its step and answers its notice, any other
  # waits.
  #
  # @param state [Hash] The replay, its entry, and what committing measured.
  def self.finish(state)
    replay = state[:replay]
    reads = replay.reads.map { |(kind, key), value| [kind, key, value] } << [HOLDINGS, nil, holdings_read]
    answer = MGQ_Multiplayer::Bridge.call(DONE_TOPIC, "entry" => state[:entry], "reached" => replay.committed?, "before" => state[:before] || [],
                                                      "reads" => reads, "had" => state[:had] || [], "has" => state[:has] || [])
    notice(answer, state[:had])
  end

  # Shows the notice the DLL answered for what the player got.
  #
  # @param answer [Hash, nil] The DLL's answer, see story.replay_done.
  # @param had [Array<Array>, nil] What the player held before, see holdings.
  def self.notice(answer, had)
    text = answer.is_a?(Hash) ? answer["notice"] : nil
    MGQ_MpOverworldSync.notice(text, first_icon(had)) if text && defined?(MGQ_MpOverworldSync)
  end

  # Shows the player the question a replay waits on, on the choices' screen, with the message's
  # last lines and a choice's labels or what an input offers; their stream waits meanwhile.
  #
  # @param state [Hash] The replay that asks, see finish.
  def self.ask_player(state)
    @asking = state
    question = state[:replay].question
    entry = state[:entry]
    unless question["kind"] == "choice"
      log("entry #{entry['id']} of #{entry['site']} asks the player for a #{question['kind']}")
      return MGQ_MpCoopChoices.ask_input(entry["opener"], question["lines"], question["kind"], question["spec"], lambda { |value| answered(value.to_i) })
    end

    log("entry #{entry['id']} of #{entry['site']} asks the player: #{question['labels'].join(' / ')}")
    return answered(question["values"].empty? ? 0 : question["values"].first) unless defined?(MGQ_MpCoopChoices) && !question["labels"].empty?

    MGQ_MpCoopChoices.ask(entry["opener"], question["lines"], question["labels"], lambda { |place| answered(question["values"][place.to_i]) }, question["cancel"])
  end

  # Reports whether the choices' screen asks a number, an item or a present, which a replay
  # otherwise stops at.
  #
  # @return [Boolean] Whether it does.
  def self.asks_inputs?
    defined?(MGQ_MpCoopChoices) && MGQ_MpCoopChoices.respond_to?(:ask_input) ? true : false
  end

  # Takes the player's answer to the question a replay waits on, and runs it on.
  #
  # @param value [Integer] The answer, one of the question's values.
  def self.answered(value)
    state = @asking
    return unless state

    @asking = nil
    state[:replay].answer(value)
    state[:replay].state == :asking ? ask_player(state) : finish(state)
  rescue => e
    log("answering a replay failed: #{e.class}: #{e.message}")
  end

  # Asks the DLL which waiting runs one of whose reads changed are due again, and takes them first.
  def self.due
    @due_at = MGQ_Multiplayer::Bridge.frame_number
    answer = ask_with_values(DUE_TOPIC, {})
    return unless answer.is_a?(Array) && !answer.empty?

    log("#{answer.size} waiting runs are due again")
    @waiting.unshift(*answer)
  end

  # Tells whether a key is read at the run's start value in a replay, by who keeps it; nil while the
  # DLL named no scopes, so the replay reads the open world's kept keys.
  #
  # @return [Proc, nil] The test.
  def self.view_test
    MGQ_MpStoryKeys.scopes ? lambda { |kind, key| MGQ_MpStoryKeys.viewed?(kind, key) } : nil
  end

  # Keeps what a replay writes of the player's own keys where the player's own game keeps them
  # besides the save: a borrowing guest's in their own story kept aside, and in a Raid World a
  # chest's key, which the relay keeps with the player, as a request like the player's own write.
  #
  # @return [Proc, nil] The block, nil while neither applies.
  def self.own_write
    guest = defined?(MGQ_MpCoopStory) && MGQ_MpCoopStory.guest?
    raid = MGQ_MpStoryKeys.recording == :raid
    return nil unless guest || raid

    lambda do |kind, key, value|
      MGQ_MpCoopStory.keep_own(kind, key, value) if guest
      if raid && MGQ_MpStoryKeys.class_of(kind, key) & MGQ_MpStoryKeys::REQUESTED != 0
        MGQ_MpStoryKeys.request(kind, key, value, ["game", "replay"])
      end
    end
  end

  # Reads one of the player's own things as the DLL names it (StoryPlain in the DLL): a key's value,
  # whether the player holds an item ("item") or has a companion in the party ("actor"), and what
  # they hold ("holdings", see holdings_read).
  #
  # @param kind [Integer, String] The key's kind, "item", "actor" or "holdings".
  # @param key [Integer, Array, nil] The key or id, nil for the holdings.
  # @return [Object] Its value.
  def self.own_value(kind, key)
    case kind
    when "item" then $data_items[key.to_i] && $game_party.has_item?($data_items[key.to_i]) ? true : false
    when "actor" then $game_party.members.any? { |actor| actor.id == key.to_i }
    when HOLDINGS then holdings_read
    else MGQ_MpStoryKeys.plain_of(kind, MGQ_MpStoryKeys.value_of(kind, key))
    end
  end

  # Lists what the player holds, for the notice of a replay: items, weapons and armors in the bag,
  # gold, the companions and the skills of the party.
  #
  # @return [Array<Array>] Each [key, amount, name, sum].
  def self.holdings
    held = []
    { "i" => $data_items, "w" => $data_weapons, "a" => $data_armors }.each do |letter, data|
      data.each { |item| held << ["#{letter}#{item.id}", $game_party.item_number(item), item.name.to_s, false] if item && $game_party.item_number(item) > 0 }
    end
    held << ["g", $game_party.gold, Vocab.currency_unit.to_s, true]
    $game_party.all_members.each do |actor|
      held << ["c#{actor.id}", 1, actor.name.to_s, false]
      actor.skills.each { |skill| held << ["k#{actor.id}.#{skill.id}", 1, skill.name.to_s, false] }
    end
    held
  end

  # Names medals as the notice tells them.
  #
  # @param ids [Array<Integer>] The medals.
  # @return [Array<Array>] Each [key, amount, name, sum].
  def self.medals_of(ids)
    ids.map do |id|
      data = defined?(NWConst::Library::MEDAL_DATA) ? NWConst::Library::MEDAL_DATA[id] : nil
      ["m#{id}", 1, data ? data[:title].to_s : "Medal #{id}", false]
    end
  end

  # Lists what the player holds as a waiting run's read of their holdings compares it, which the DLL
  # sums up: a script's check of the party, such as a chest's lock, reads no key.
  #
  # @return [Array] Each thing's key and amount, then each companion's id, level and equipment.
  def self.holdings_read
    party = $game_party.members.map { |actor| [actor.id, actor.level, actor.equips.map { |equip| equip ? equip.id : 0 }] }
    holdings.map { |key, amount| [key, amount] } + [party]
  end

  # Finds the icon of the first item a replay gave, for its notice.
  #
  # @param had [Array<Array>] What the player held before.
  # @return [Integer, nil] The icon, nil for none.
  def self.first_icon(had)
    before = {}
    had.each { |key, amount| before[key] = amount }
    holdings.each do |key, amount|
      next unless key =~ /\A([iwa])(\d+)\z/ && amount > before[key].to_i

      item = MGQ_MpGame.item($1, $2.to_i)
      return item.icon_index if item && item.respond_to?(:icon_index)
    end
    nil
  end

  # Writes a run's entry for a message to another game.
  #
  # @param entry [Hash] The entry.
  # @return [String, nil] The text, nil when the DLL wrote none.
  def self.wire(entry)
    MGQ_Multiplayer::Bridge.call(WIRE_TOPIC, entry)
  end

  # Reads a run's entry another game wrote.
  #
  # @param text [String] The text.
  # @return [Hash, nil] The entry, nil for a text the DLL does not read.
  def self.unwire(text)
    MGQ_Multiplayer::Bridge.call(UNWIRE_TOPIC, text.to_s)
  end

  # Hands the player a run of their own history: a page a catch-up names, or the page that closes a
  # chest it names, played from their own values with the keys that close it read as shut where a
  # replay reads the run's start values, as a run handed to them; once while it waits.
  #
  # @param fields [Hash] "site", such as ["map", 215, 23, 1], or "chest", such as [2, [588, 9, "A"]].
  # @param why [String] What names it, for the log.
  def self.derive(fields, why)
    raid = defined?(MGQ_MpCoop::Scope) && MGQ_MpCoop::Scope.raid?
    entry = MGQ_Multiplayer::Bridge.call(DERIVE_TOPIC, fields.merge("party" => !raid))
    return log("no entry of #{fields.values.first} for #{why}: the DLL derived none") unless entry.is_a?(Hash)
    return if @waiting.any? { |waiting| waiting["id"] == entry["id"] }

    log("#{why}: #{entry['site']} is played in the player's own game")
    receive(entry)
  end

  # Hands the DLL the log of the save loaded, or begins one at its place for a save without one, and
  # takes the runs that wait in it in place of those of the game before. Called after a save's
  # contents were read.
  def self.loaded
    log_of($game_system ? $game_system.instance_variable_get(LOG_FIELD) : nil, true)
  end

  # Begins the log of a new game, with no run waiting. Called after a new game's objects were made.
  def self.new_game
    log_of(nil, true)
  end

  # Forgets the runs handed to the player and the save's log once the world closed, whose game is
  # over; the next save loaded brings its own. Called by world.rbx.
  def self.forget
    log_of(nil, false)
  end

  # Hands the DLL a save's log, and takes the runs that wait in it; the replay that waited on the
  # player is forgotten.
  #
  # @param saved [Hash, nil] The log, nil for none.
  # @param placed [Boolean] Whether a save is open, whose place starts a log it lacks.
  def self.log_of(saved, placed)
    @asking = nil
    @waiting = []
    return unless MGQ_Multiplayer::Bridge.open? && (!placed || $game_variables)

    place = placed ? MGQ_MpStoryIds.markers.map { |id| $game_variables[id].to_i } : nil
    answer = MGQ_Multiplayer::Bridge.call(LOG_TOPIC, "log" => saved, "place" => place)
    @waiting = answer if answer.is_a?(Array)
    log("#{@waiting.size} runs handed to the player wait in the save's log") unless @waiting.empty?
  rescue => e
    log("handing the save's log over failed: #{e.class}: #{e.message}")
  end

  # Keeps the DLL's log in the save. Called before the game writes a save's contents.
  def self.saving
    return unless MGQ_Multiplayer::Bridge.open? && $game_system

    saved = MGQ_Multiplayer::Bridge.call(LOG_SAVE_TOPIC)
    $game_system.instance_variable_set(LOG_FIELD, saved) if saved
  rescue => e
    log("keeping the log in the save failed: #{e.class}: #{e.message}")
  end

  # The opener's inputs: the values of each command and kind in the order the run read them.
  class Record
    # Takes the record's inputs.
    #
    # @param inputs [Array<Array>] Each [at, occurrence, kind, value], in the order the run read them.
    def initialize(inputs)
      @values = {}
      inputs.each do |at, _occurrence, kind, value|
        (@values[[at, kind.to_s]] ||= []) << value
      end
    end

    # Takes the next value of a command's input.
    #
    # @param at [Array] The command, see MGQ_MpStoryReplay.input_at.
    # @param kind [String] What it read, see MGQ_MpStoryReplay.input_at.
    # @return [Integer, nil] The value, nil once the record holds none.
    def take(at, kind)
      values = @values[[at, kind]]
      values && !values.empty? ? values.shift : nil
    end

    # Adds the receiver's answer to a command's input, which the replay takes next.
    #
    # @param at [Array] The command.
    # @param kind [String] What it read.
    # @param value [Integer] The answer.
    def add(at, kind, value)
      (@values[[at, kind]] ||= []).unshift(value)
    end
  end

  # The world's and the game's work keys as the replay reads and writes them: the run's start values,
  # then the replay's own writes, never the receiver's save.
  class View
    # Starts the view.
    #
    # @param start [Hash] The start values by [kind, key].
    # @param test [Proc] Tells whether a key of a kind belongs to the view.
    def initialize(start, test)
      @values = start
      @test = test
    end

    # Reports whether a key belongs to the view: one the run's start values carry, or a world or
    # work key.
    #
    # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
    # @param key [Integer, Array] Its id, or a self switch's map, event and letter.
    # @return [Boolean] Whether it does.
    def holds?(kind, key)
      @values.key?([kind, key]) || @test.call(kind, key) == true
    rescue
      false
    end

    # Reads a key: the view's value, the receiver's own for a key the view never took.
    #
    # @param kind [Integer] The key's kind.
    # @param key [Integer, Array] The key.
    # @yieldreturn [Object] The receiver's own value.
    # @return [Object] The value.
    def read(kind, key)
      @values.key?([kind, key]) ? @values[[kind, key]] : yield
    end

    # Writes a key of the view.
    #
    # @param kind [Integer] The key's kind.
    # @param key [Integer, Array] The key.
    # @param value [Object] The value.
    # @return [Boolean] Whether the key belongs to the view, which took it.
    def write(kind, key, value)
      return false unless holds?(kind, key)

      @values[[kind, key]] = value
      true
    end

    # Turns off the view's self switches of maps, as the game resets the maps' self switches.
    #
    # @param map_ids [Array<Integer>] The maps.
    def reset_maps(map_ids)
      @values.keys.each { |kind, key| @values[[kind, key]] = false if kind == 2 && map_ids.include?(key[0]) }
    end

    # Drops the view's values of a kind, as the event made the receiver's object of that kind anew.
    #
    # @param kind [Integer] The kind.
    def drop(kind)
      @values.keys.each { |found, key| @values.delete([found, key]) if found == kind }
    end
  end

  # A stand-in for the game's switches, variables or self switches while the replay runs: a world
  # or work key goes to the view, every other key to the replay's staged writes over the receiver's
  # own object.
  class Keys
    # The receiver's own object, or the one the replay made anew.
    attr_reader :own

    # Makes the stand-in.
    #
    # @param replay [Replay] The replay.
    # @param kind [Integer] 0 for the switches, 1 for the variables, 2 for the self switches.
    # @param own [Object] The receiver's own object, or the one the replay made anew.
    def initialize(replay, kind, own)
      @replay = replay
      @kind = kind
      @own = own
    end

    # Reads a key.
    #
    # @param key [Integer, Array] The key.
    # @return [Object] Its value.
    def [](key)
      @replay.read(@kind, key) { @own[key] }
    end

    # Writes a key.
    #
    # @param key [Integer, Array] The key.
    # @param value [Object] The value.
    def []=(key, value)
      @replay.write(@kind, key, value) { @own[key] = value }
    end

    # Resets the self switches of maps, the receiver's own and the view's (script 148).
    #
    # @param map_ids [Array<Integer>] The maps.
    def delete(map_ids)
      @replay.reset_maps(map_ids)
    end

    # Hands any other call to the receiver's own object.
    #
    # @param name [Symbol] The method.
    # @param args [Array] Its arguments.
    # @return [Object] What it returns.
    def method_missing(name, *args, &block)
      @own.send(name, *args, &block)
    end

    # Tells whether the receiver's own object answers a method.
    #
    # @param name [Symbol] The method.
    # @param include_private [Boolean] Whether private methods count.
    # @return [Boolean] Whether it does.
    def respond_to_missing?(name, include_private = false)
      @own.respond_to?(name, include_private)
    end
  end

  # A stand-in for a character while the replay runs: it never moves or shows, its place is read
  # from the record, and a move route forced on it runs at once with only its switch and script
  # commands taking effect.
  class Character
    # Makes the stand-in.
    #
    # @param replay [Replay] The replay.
    # @param who [String] What the record names it by: "player" or "event<id>".
    # @param real [Object, nil] The receiver's own character it reads its place from without a record.
    # @param id [Integer] The event's id, 0 for the player.
    def initialize(replay, who, real, id)
      @replay = replay
      @who = who
      @real = real
      @id = id
      @map_id = replay.map_id
    end

    POSITION_READS.each do |name|
      define_method(name) { @replay.input("#{@who}.#{name}") { @real ? @real.send(name) : 0 } }
    end

    # Runs a move route at once: its switch commands and scripts take effect, every move is left out.
    #
    # @param route [RPG::MoveRoute] The route.
    def force_move_route(route)
      route.list.each do |command|
        case command.code
        when ROUTE_SWITCH_ON then $game_switches[command.parameters[0]] = true
        when ROUTE_SWITCH_OFF then $game_switches[command.parameters[0]] = false
        when ROUTE_SCRIPT then route_script(command.parameters[0])
        end
      end
      nil
    end

    # Reports that the character moves no route, so the event waits for none.
    #
    # @return [Boolean] False.
    def move_route_forcing
      false
    end

    # Runs a move route's script on the stand-in, as the game runs it on the character.
    #
    # @param script [String] The script.
    def route_script(script)
      instance_eval(script)
    rescue StandardError, ScriptError => e
      MGQ_MpStoryReplay.log_once([:route, script], "a move route's script failed on a stand-in in #{@replay.site}: #{e.class}: #{e.message}")
    end

    # Leaves out every other call: a move, a look, a sound.
    #
    # @param _name [Symbol] The method.
    # @param _args [Array] Its arguments.
    # @return [nil] Nothing.
    def method_missing(_name, *_args)
      nil
    end

    # Answers every method, as the character would.
    #
    # @param _name [Symbol] The method.
    # @param _include_private [Boolean] Whether private methods count.
    # @return [Boolean] True.
    def respond_to_missing?(_name, _include_private = false)
      true
    end
  end

  # A stand-in for the player while the replay runs: a character that is never moved, whose state is
  # read from the record.
  class Player < Character
    PLAYER_READS.each do |name|
      define_method(name) { @replay.flag("player.#{name}") { @real.send(name) } }
    end

    # Reads the vehicle the player is in, the record holding its place among the map's vehicles.
    #
    # @return [Game_Vehicle, nil] The vehicle, nil on foot.
    def vehicle
      index = @replay.input("player.vehicle") { @real.vehicle ? @replay.real_map.vehicles.index(@real.vehicle) : -1 }
      index && index >= 0 ? $game_map.vehicles[index] : nil
    end

    # Reports that no transfer is reserved, so the event waits for none.
    #
    # @return [Boolean] False.
    def transfer?
      false
    end

    # Reports that the player stands still.
    #
    # @return [Boolean] False.
    def moving?
      false
    end

    # The followers, which never move.
    #
    # @return [Followers] The followers.
    def followers
      @followers ||= Followers.new
    end
  end

  # A stand-in for the followers while the replay runs: they never move and count as gathered.
  class Followers
    # Reports the followers gathered, so the event waits for nothing.
    #
    # @return [Boolean] True.
    def gather?
      true
    end

    # Leaves out every other call.
    #
    # @param _name [Symbol] The method.
    # @param _args [Array] Its arguments.
    # @return [nil] Nothing.
    def method_missing(_name, *_args)
      nil
    end

    # Answers every method.
    #
    # @param _name [Symbol] The method.
    # @param _include_private [Boolean] Whether private methods count.
    # @return [Boolean] True.
    def respond_to_missing?(_name, _include_private = false)
      true
    end
  end

  # A stand-in for the timer while the replay runs: it is never started or stopped, and its reads
  # come from the record.
  class Timer
    # Makes the stand-in.
    #
    # @param replay [Replay] The replay.
    # @param real [Game_Timer] The receiver's own timer, read without a record.
    def initialize(replay, real)
      @replay = replay
      @real = real
    end

    # Reads the timer's seconds from the record.
    #
    # @return [Integer] The seconds.
    def sec
      @replay.input("timer.sec") { @real.sec }
    end

    # Reads from the record whether the timer runs.
    #
    # @return [Boolean] Whether it does.
    def working?
      @replay.flag("timer.working?") { @real.working? }
    end

    # Leaves out every other call.
    #
    # @param _name [Symbol] The method.
    # @param _args [Array] Its arguments.
    # @return [nil] Nothing.
    def method_missing(_name, *_args)
      nil
    end

    # Answers every method.
    #
    # @param _name [Symbol] The method.
    # @param _include_private [Boolean] Whether private methods count.
    # @return [Boolean] True.
    def respond_to_missing?(_name, _include_private = false)
      true
    end
  end

  # A stand-in for the map while the replay runs: it is the event's map, shows nothing new, has no
  # events of the receiver's to touch, and hands the rest to the receiver's own map.
  class Map
    # Makes the stand-in.
    #
    # @param replay [Replay] The replay.
    # @param real [Game_Map] The receiver's own map.
    def initialize(replay, real)
      @replay = replay
      @real = real
    end

    # The map the run ran on.
    #
    # @return [Integer] Its id.
    def map_id
      @replay.map_id
    end

    # The replay's scratch screen.
    #
    # @return [Game_Screen] The screen.
    def screen
      @replay.screen
    end

    # No events: the run's map is not the receiver's to move.
    #
    # @return [Hash] None.
    def events
      {}
    end

    # The vehicles as the replay stages them.
    #
    # @return [Array<Game_Vehicle>] The boat, the ship and the airship.
    def vehicles
      @replay.vehicles
    end

    # A vehicle as the replay stages it.
    #
    # @param type [Symbol] :boat, :ship or :airship.
    # @return [Game_Vehicle, nil] The vehicle, nil for another type.
    def vehicle(type)
      index = VEHICLE_TYPES.index(type)
      index ? vehicles[index] : nil
    end

    VEHICLE_TYPES.each_with_index { |type, index| define_method(type) { vehicles[index] } }

    MAP_CLOSED.each { |name| define_method(name) { |*_args| nil } }

    MAP_READS.each do |name|
      define_method(name) { @replay.flag("map.#{name}") { @real.send(name) } }
    end

    # Hands any other call to the receiver's own map.
    #
    # @param name [Symbol] The method.
    # @param args [Array] Its arguments.
    # @return [Object] What it returns.
    def method_missing(name, *args, &block)
      @real.send(name, *args, &block)
    end

    # Tells whether the receiver's own map answers a method.
    #
    # @param name [Symbol] The method.
    # @param include_private [Boolean] Whether private methods count.
    # @return [Boolean] Whether it does.
    def respond_to_missing?(name, include_private = false)
      @real.respond_to?(name, include_private)
    end
  end

  # The receiver's holdings as a replay sees them: the party, the actors, the library and the map's
  # vehicles, copied in one piece as a save copies them, so what they share stays shared. The replay
  # changes the copy; its commit merges the changes into the receiver's objects.
  class Stage
    # The staged party, actors, library and vehicles.
    attr_reader :objects

    # Copies the receiver's holdings.
    def initialize
      @base = Marshal.dump(Stage.real)
      @objects = Marshal.load(@base)
    end

    # The receiver's holdings.
    #
    # @return [Array] The party, the actors, the library and the map's vehicles.
    def self.real
      [$game_party, $game_actors, $game_library, $game_map ? $game_map.vehicles : nil]
    end

    # Merges what the replay changed into the receiver's holdings as they are now.
    def commit
      base = Marshal.load(@base)
      Stage.real.each_with_index { |real, index| Merge.into(base[index], @objects[index], real) }
    end
  end

  # Merges what a replay changed in its copy of objects into the receiver's objects, field by field,
  # so what the game changed meanwhile stays: a field the replay left alone keeps the receiver's
  # value, a number both changed takes the replay's difference too, a list of plain values both
  # changed in size takes the replay's additions and removals, and any other field the replay
  # changed takes the replay's value.
  module Merge
    # A slot that holds nothing: a missing key, field or place.
    ABSENT = Object.new.freeze

    # The values compared by value and taken whole.
    PLAIN = [Numeric, String, Symbol, TrueClass, FalseClass, NilClass].freeze

    # Merges one object's changes into the receiver's object of the same class.
    #
    # @param base [Object] The object as the replay copied it.
    # @param ours [Object] The replay's copy at its end.
    # @param real [Object, nil] The receiver's object now.
    def self.into(base, ours, real)
      return unless real && merged?(base, ours, real) && !same?(base, ours)

      merge(base, ours, real, {})
    end

    # Tells the value a slot of the receiver's takes.
    #
    # @param base [Object] The slot as the replay copied it, ABSENT for none.
    # @param ours [Object] The replay's slot at its end.
    # @param real [Object] The receiver's slot now.
    # @param seen [Hash] The receiver's objects merged already.
    # @return [Object] The value, the receiver's own object for one merged in place.
    def self.value(base, ours, real, seen)
      return real if same?(base, ours)
      return sum(base, ours, real) if counted?(base, ours, real) && !same?(base, real)
      return ours unless merged?(base, ours, real)

      merge(base, ours, real, seen)
      real
    end

    # Merges an object's changes in place: its keys, places or members, then its fields.
    #
    # @param base [Object] The object as copied.
    # @param ours [Object] The replay's copy.
    # @param real [Object] The receiver's object.
    # @param seen [Hash] The receiver's objects merged already, which a cycle reaches again.
    def self.merge(base, ours, real, seen)
      return if seen[real.object_id]

      seen[real.object_id] = true
      if ours.is_a?(Hash) then merge_hash(base, ours, real, seen)
      elsif ours.is_a?(Array) then merge_array(base, ours, real, seen)
      elsif ours.is_a?(Struct) then ours.members.each { |name| put(real, name, value(base[name], ours[name], real[name], seen)) }
      end
      merge_fields(base, ours, real, seen)
    end

    # Merges a hash's keys.
    #
    # @param base [Hash] The hash as copied.
    # @param ours [Hash] The replay's copy.
    # @param real [Hash] The receiver's hash.
    # @param seen [Hash] The objects merged already.
    def self.merge_hash(base, ours, real, seen)
      (base.keys | ours.keys).each do |key|
        slot = value(base.key?(key) ? base[key] : ABSENT, ours.key?(key) ? ours[key] : ABSENT, real.key?(key) ? real[key] : ABSENT, seen)
        slot.equal?(ABSENT) ? real.delete(key) : put(real, key, slot)
      end
    end

    # Merges a list: one of plain values whose size the replay changed by the values it added and
    # removed, any other place by place.
    #
    # @param base [Array] The list as copied.
    # @param ours [Array] The replay's copy.
    # @param real [Array] The receiver's list.
    # @param seen [Hash] The objects merged already.
    def self.merge_array(base, ours, real, seen)
      if base.size != ours.size && (base + ours).all? { |item| plain?(item) }
        kept = without(real, without(base, ours))
        return real.replace(kept + without(ours, base))
      end

      places = (0...[base.size, ours.size, real.size].max).map { |index| value(at(base, index), at(ours, index), at(real, index), seen) }
      real.replace(places.reject { |slot| slot.equal?(ABSENT) })
    end

    # Merges an object's fields.
    #
    # @param base [Object] The object as copied.
    # @param ours [Object] The replay's copy.
    # @param real [Object] The receiver's object.
    # @param seen [Hash] The objects merged already.
    def self.merge_fields(base, ours, real, seen)
      (base.instance_variables | ours.instance_variables).each do |name|
        slot = value(field(base, name), field(ours, name), field(real, name), seen)
        if slot.equal?(ABSENT)
          real.send(:remove_instance_variable, name) if real.instance_variable_defined?(name)
        elsif !slot.equal?(field(real, name))
          real.instance_variable_set(name, slot)
        end
      end
    end

    # Sets a key or member unless it holds the value already.
    #
    # @param real [Hash, Struct] The receiver's object.
    # @param key [Object] The key or member.
    # @param slot [Object] The value.
    def self.put(real, key, slot)
      real[key] = slot unless slot.equal?(real[key])
    end

    # Reads a field.
    #
    # @param object [Object] The object.
    # @param name [Symbol] The field.
    # @return [Object] Its value, ABSENT for none.
    def self.field(object, name)
      object.instance_variable_defined?(name) ? object.instance_variable_get(name) : ABSENT
    end

    # Reads a place of a list.
    #
    # @param list [Array] The list.
    # @param index [Integer] The place.
    # @return [Object] Its value, ABSENT past the end.
    def self.at(list, index)
      index < list.size ? list[index] : ABSENT
    end

    # Takes values out of a list, each once.
    #
    # @param list [Array] The list.
    # @param taken [Array] The values.
    # @return [Array] The list without them.
    def self.without(list, taken)
      left = list.dup
      taken.each do |item|
        index = left.index(item)
        left.delete_at(index) if index
      end
      left
    end

    # Reports whether three slots hold numbers or nothing, which add up.
    #
    # @param slots [Array] The slots.
    # @return [Boolean] Whether they do.
    def self.counted?(*slots)
      slots.all? { |slot| slot.equal?(ABSENT) || slot.is_a?(Numeric) }
    end

    # Adds the replay's difference to the receiver's number.
    #
    # @param base [Numeric] The number as copied, ABSENT for none.
    # @param ours [Numeric] The replay's number, ABSENT for none.
    # @param real [Numeric] The receiver's number, ABSENT for none.
    # @return [Numeric] The sum, ABSENT where the replay removed the slot and nothing is left.
    def self.sum(base, ours, real)
      total = [real, ours].map { |slot| slot.equal?(ABSENT) ? 0 : slot }.inject(:+) - (base.equal?(ABSENT) ? 0 : base)
      ours.equal?(ABSENT) && total == 0 ? ABSENT : total
    end

    # Reports whether the replay's object merges into the receiver's in place: both of the copied
    # object's class, with keys, places, members or fields to merge.
    #
    # @param base [Object] The slot as copied.
    # @param ours [Object] The replay's slot.
    # @param real [Object] The receiver's slot.
    # @return [Boolean] Whether it does.
    def self.merged?(base, ours, real)
      return false if plain?(ours) || base.equal?(ABSENT) || ours.equal?(ABSENT) || real.equal?(ABSENT)
      return false unless base.class == ours.class && ours.class == real.class

      ours.is_a?(Hash) || ours.is_a?(Array) || ours.is_a?(Struct) || !ours.instance_variables.empty?
    end

    # Reports whether a value is plain, compared by value and taken whole.
    #
    # @param value [Object] The value.
    # @return [Boolean] Whether it is.
    def self.plain?(value)
      PLAIN.any? { |kind| value.is_a?(kind) }
    end

    # Reports whether two slots hold the same: plain values by value, objects by their contents.
    #
    # @param one [Object] A slot, ABSENT for none.
    # @param other [Object] Another slot, ABSENT for none.
    # @return [Boolean] Whether they do.
    def self.same?(one, other)
      return true if one.equal?(other)
      return false if one.equal?(ABSENT) || other.equal?(ABSENT)
      return one.class == other.class && one == other if plain?(one) || plain?(other)

      Marshal.dump(one) == Marshal.dump(other)
    rescue TypeError
      false
    end
  end

  # The receiver's interpreter for a replay: the game's own, without the mod's hooks, bound to the
  # run's map and event, with every common event it calls bound the same way.
  class Interpreter < ::Game_Interpreter
    # The interpreter class a script names, so a common event a script starts is replayed too.
    Game_Interpreter = self

    # Gives every hooked method of the game's interpreter that this class does not define the
    # game's own body, without the mod's hooks; a hook registered later is covered at the next replay.
    def self.unhook
      own = instance_methods(false) + private_instance_methods(false)
      MGQ_MpHooks.hooked(::Game_Interpreter).each do |name|
        next if own.include?(name)

        plain = MGQ_MpHooks.plain(::Game_Interpreter, name)
        define_method(name) { |*args, &block| send(plain, *args, &block) }
      end
    end

    CLOSED_CODES.each { |code| define_method("command_#{code}") {} }
    CLOSED_FUNCTIONS.each { |name| define_method(name) { |*_args| nil } }

    # Makes an interpreter of a replay.
    #
    # @param depth [Integer] How deep it is called.
    # @param replay [Replay] The replay, the one running for an interpreter a script makes.
    def initialize(depth = 0, replay = MGQ_MpStoryReplay.current)
      @replay = replay
      super(depth)
    end

    # Runs the game's own body of one of its interpreter's methods, without the mod's hooks.
    #
    # @param name [Symbol] The method.
    # @param args [Array] Its arguments.
    # @return [Object] What it returns.
    def game(name, *args)
      plain = MGQ_MpHooks.plain(::Game_Interpreter, name)
      plain == name ? ::Game_Interpreter.instance_method(name).bind(self).call(*args) : send(plain, *args)
    end

    # Sets up a list as the game does, bound to the run's map.
    #
    # @param list [Array<RPG::EventCommand>] The commands.
    # @param event_id [Integer] The event, 0 for none.
    def setup(list, event_id = 0)
      game(:setup, list, event_id)
      @map_id = @replay.map_id
      @replay_site = @replay.site_of(list)
    end

    # Reports the run's map as the one the event started on.
    #
    # @return [Boolean] True.
    def same_map?
      true
    end

    # Runs the command at the interpreter's place as the game does, naming the place its inputs
    # belong to.
    def execute_command
      @replay.at(@replay_site, @list, @index, self) { game(:execute_command) }
    end

    # Tells the place of the command the interpreter stands at: the Show Choices a text set up while
    # the text waits for its answer.
    #
    # @return [Integer] The place.
    def place
      @index
    end

    # Calls a common event, bound to the run's map and event like its caller.
    def command_117
      common_event = $data_common_events[@params[0]]
      return unless common_event

      child = self.class.new(@depth + 1, @replay)
      child.setup(common_event.list, @event_id)
      child.run
    end

    # Reads a key press from the record, and the checks the replay follows the opener through: what
    # the party holds and the event's own self switches, so the receiver gets what the opener got.
    # A self switch of the run's step reads the receiver's own, which tells whether they took the
    # step already. Any other branch as the game does.
    def command_111
      kind = BRANCH_INPUTS[@params[0]]
      return game(:command_111) unless kind

      own = own_branch
      opener = @replay.flag(kind) { own }
      @branch[@indent] = step_switch? ? own : opener
      command_skip unless @branch[@indent]
    end

    # Skips a branch's commands as the game does, unless the replay only reads the branch's result.
    def command_skip
      game(:command_skip) unless @deciding
    end

    # Reads what the party holds as the opener's record holds it, and any other game data as the
    # game does.
    #
    # @param type [Integer] The kind of game data.
    # @param param1 [Integer] Its first parameter.
    # @param param2 [Integer] Its second parameter.
    # @return [Numeric] The value.
    def game_data_operand(type, param1, param2)
      own = game(:game_data_operand, type, param1, param2)
      MGQ_MpStoryReplay.holding_read?(type, param1) ? @replay.input("holding") { own } : own
    end

    # Reads the map at a place from the record, or from the receiver's own map without one.
    def command_285
      value = @replay.input("location") do
        game(:command_285)
        $game_variables[@params[0]]
      end
      $game_variables[@params[0]] = value
    end

    # Takes a battle's outcome from the record, a win without one: no battle opens.
    def command_301
      @branch[@indent] = @replay.input("battle") { 0 }
    end

    # Runs a script, in this class's scope, so an interpreter the script makes replays too.
    def command_355
      script = @list[@index].parameters[0] + "\n"
      while next_event_code == 655
        @index += 1
        script += @list[@index].parameters[0] + "\n"
      end
      eval(script, binding, "story replay #{@replay_site}", 0)
    end

    # Plays a novel scene's common event as a common event the event calls, without the scene.
    #
    # @param event_id [Integer] The common event.
    def call_novel_scene(event_id)
      common_event = $data_common_events[event_id]
      return unless common_event

      child = self.class.new(@depth + 1, @replay)
      child.setup(common_event.list, 0)
      child.run
    end

    # Reads the keys the opener pressed from the record, none without one.
    #
    # @param _duration [Integer] How many frames the game reads keys for.
    def input_keys(_duration)
      keys = []
      while (index = @replay.input("keys") { -1 }) >= 0
        keys << KEY_SYMBOLS[index]
      end
      $game_temp.keys_stack = keys
    end

    # Draws a random number from the record, or as the game does without one.
    #
    # @param args [Array] The game's arguments of rand.
    # @return [Numeric] The number.
    def rand(*args)
      @replay.input("rand") { game(:rand, *args) }
    end

    # The replay's character of a parameter: the player, or the stand-in of an event of the run's map.
    #
    # @param param [Integer] -1 for the player, 0 for the bound event, else an event's id.
    # @return [Character, nil] The character, nil in battle.
    def get_character(param)
      return nil if $game_party.in_battle

      param < 0 ? $game_player : @replay.character(param > 0 ? param : @event_id)
    end

    # The replay's scratch screen.
    #
    # @return [Game_Screen] The screen.
    def screen
      @replay.screen
    end

    # Waits no frame: waits are the opener's presentation.
    #
    # @param _duration [Integer] The frames.
    def wait(_duration)
    end

    private

    # Finds the receiver's own result of the conditional branch running now, as the game finds it.
    #
    # @return [Boolean] The result.
    def own_branch
      @deciding = true
      game(:command_111)
      @branch[@indent]
    ensure
      @deciding = false
    end

    # Tells whether the conditional branch running now checks a self switch of the run's step.
    #
    # @return [Boolean] Whether it does.
    def step_switch?
      @params[0] == 2 && @event_id > 0 && @replay.step_key?(2, [@map_id, @event_id, @params[1]])
    end
  end

  # One replay: its run's binding, its view and record, and where it stands.
  class Replay
    # The run's site.
    attr_reader :site

    # The map the run ran on.
    attr_reader :map_id

    # The event the run ran for, 0 for a common event.
    attr_reader :event_id

    # :running, :asking, :done or :failed.
    attr_reader :state

    # What the receiver is asked while :asking: "at", "kind", "labels", "values", "lines" and
    # "spec", see spec_of.
    attr_reader :question

    # Every write the replay made, each [kind, key, value, viewed]: viewed for a world or work key,
    # which the view took and dropped.
    attr_reader :writes

    # The medals the replay gained, whose popup the notice takes over.
    attr_reader :medals

    # The receiver's own keys the replay read, each name with its value as the tracks write them,
    # such as {"s2045" => "0"}.
    attr_reader :reads

    # The view.
    attr_reader :view

    # The scratch screen.
    attr_reader :screen

    # The receiver's own map, which the replay's stand-in hides.
    attr_reader :real_map

    # Binds a run.
    #
    # @param entry [Hash] The run, see MGQ_MpStoryReplay.play.
    # @param options [Hash] The view's test, the own writes' block, the page, the commit's measure
    #   and the opener's whole record, see MGQ_MpStoryReplay.play.
    def initialize(entry, options)
      site = entry["site"]
      @site = options[:page] && site[0] == "map" ? site[0, 3] + [options[:page]] : site
      @record = Record.new(entry["inputs"] || [])
      @opener = Record.new(options[:recorded] || entry["inputs"] || [])
      @view = View.new(start_values(entry["start"]), options[:view] || method(:kept_key?))
      @keys = {}
      Array(entry["keys"]).each { |kind, key, _value| @keys[[kind, key]] = true }
      @own_write = options[:own_write]
      @around_commit = options[:around_commit]
      @writes = []
      @medals = []
      @reads = {}
      @places = []
      @own = {}
      @journal = []
      @made = []
      @reset = []
      @gained = {}
      @own_way = false
      @committed = false
      @state = :running
      @list = bind(entry)
    end

    # Starts the replay.
    #
    # @return [Replay, nil] The replay, nil for a run whose list the game does not have or whose
    #   holdings cannot be staged.
    def start
      return MGQ_MpStoryReplay.refuse("no list to replay at #{@site}") unless @list

      @stage = staged
      return MGQ_MpStoryReplay.refuse("the holdings could not be staged for #{@site}") unless @stage

      Interpreter.unhook
      @screen = Game_Screen.new
      @message = Game_Message.new
      @interpreter = Interpreter.new(0, self)
      @interpreter.setup(@list, @event_id)
      step
    end

    # Reports whether the replay kept what it did: it finished and reached its step.
    #
    # @return [Boolean] Whether it did.
    def committed?
      @committed
    end

    # The vehicles as the replay stages them.
    #
    # @return [Array<Game_Vehicle>] The vehicles.
    def vehicles
      @stage.objects[3] || []
    end

    # Answers the question the replay waits on, and runs on.
    #
    # @param value [Object] The answer, one of the question's "values".
    # @return [Replay] The replay.
    def answer(value)
      return self unless @state == :asking

      opener = @opener.take(@question["at"], @question["kind"])
      @own_way ||= opener.nil? || opener.to_s != value.to_s
      @record.add(@question["at"], @question["kind"], value)
      @question = nil
      step
    end

    # Reports whether the receiver answered a question of the replay otherwise than the opener did,
    # or one the opener's record lacks, so the replay goes the receiver's own way.
    #
    # @return [Boolean] Whether they did.
    def own_way?
      @own_way
    end

    # Reports whether the replay ended.
    #
    # @return [Boolean] Whether it is done or failed.
    def over?
      @state == :done || @state == :failed
    end

    # Reads an input: the record's value of the command running now, else the receiver's own.
    #
    # @param kind [String] What is read, see MGQ_MpStoryReplay.input_at.
    # @yieldreturn [Object] The receiver's own value.
    # @return [Object] The value.
    def input(kind)
      value = @record.take(at_now, kind)
      value.nil? ? yield : value
    end

    # Reads a yes or no input, which the record holds as 1 or 0.
    #
    # @param kind [String] What is read, see MGQ_MpStoryReplay.input_at.
    # @yieldreturn [Boolean] The receiver's own answer.
    # @return [Boolean] The answer.
    def flag(kind)
      value = @record.take(at_now, kind)
      value.nil? ? yield : value != 0
    end

    # Names the command running now, the deepest one.
    #
    # @return [Array] The command, see MGQ_MpStoryReplay.input_at.
    def at_now
      site, list, index = @places.last || [@site, @list, 0]
      MGQ_MpStoryReplay.input_at(site, list, index)
    end

    # Names the choice the message waits for: the Show Choices the deepest command running stands
    # at, which a text sets up after its lines, or the script command of an extended choice.
    #
    # @return [Array] The command, see MGQ_MpStoryReplay.choice_at.
    def choice_now
      site, list, index, interpreter = @places.last || [@site, @list, 0, nil]
      MGQ_MpStoryReplay.choice_at(site, list, interpreter ? interpreter.place : index)
    end

    # Runs a command, its inputs named by its place.
    #
    # @param site [Array] The command's list.
    # @param list [Array<RPG::EventCommand>] The list's commands.
    # @param index [Integer] Its place.
    # @param interpreter [Interpreter] The interpreter that runs it.
    # @yield Runs the command.
    def at(site, list, index, interpreter)
      @places.push([site, list, index, interpreter])
      yield
    ensure
      @places.pop
    end

    # Names a list for the record: the run's own, or the common event it is.
    #
    # @param list [Array] The commands.
    # @return [Array] Such as ["map", 215, 23, 1] or ["ce", 129]; ["list"] for a list of no site.
    def site_of(list)
      return @site if list.equal?(@list)

      common = $data_common_events.index { |event| event && event.list.equal?(list) }
      common ? ["ce", common] : ["list"]
    end

    # The stand-in of an event of the run's map.
    #
    # @param id [Integer] The event.
    # @return [Character] The stand-in.
    def character(id)
      real = @real_map && @real_map.map_id == @map_id ? @real_map.events[id] : nil
      Character.new(self, "event#{id}", real, id)
    end

    # Reads a key: a world or work key from the view, any other as the replay staged it over the
    # receiver's own object, noting what it read of the receiver's own.
    #
    # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
    # @param key [Integer, Array] The key.
    # @yieldreturn [Object] The value of the object the stand-in holds.
    # @return [Object] The value.
    def read(kind, key)
      return @view.read(kind, key) { yield } if @view.holds?(kind, key)
      return @own[[kind, key]] if @own.key?([kind, key])
      return false if kind == 2 && @reset.include?(key[0])

      value = yield
      @reads[[kind, kind == 2 ? key.dup : key]] = MGQ_MpStoryKeys.plain_of(kind, value) unless @made[kind]
      value
    end

    # Writes a key: a world or work key to the view, any other to the replay's staged writes, which
    # it keeps in order once it is committed.
    #
    # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
    # @param key [Integer, Array] The key.
    # @param value [Object] The value.
    # @yield Writes the key into an object the replay made anew.
    def write(kind, key, value)
      key = key.dup if kind == 2
      viewed = @view.write(kind, key, value)
      unless viewed
        @made[kind] ? yield : @own[[kind, key]] = value
        @journal << [:write, kind, key, value]
      end
      @writes << [kind, key, value, viewed]
    end

    # Tells whether a key is one of the run's step.
    #
    # @param kind [Integer] 0 for a switch, 1 for a variable, 2 for a self switch.
    # @param key [Integer, Array] The key.
    # @return [Boolean] Whether it is.
    def step_key?(kind, key)
      @keys.key?([kind, key])
    end

    # Tells how much of a change of what the receiver holds the replay makes, and notes what it
    # gained: all of a gain, and of a loss only what the replay itself gained of the same thing, but
    # all of a loss of a found item (MGQ_MpStoryKeys.found_item?), which an event used up for every
    # player who holds it (user decision 2026-11-04).
    #
    # A story reset clears the opener's own items and uses none up, so a receiver ahead of the
    # opener keeps the route's key items it takes.
    #
    # @param what [Object] What changes: :gold, or the item.
    # @param amount [Integer] The change, below 0 for a loss.
    # @return [Integer] The change to make.
    def kept_change(what, amount)
      gained = @gained[what].to_i
      change = amount >= 0 || used_up?(what) ? amount : -[-amount, gained].min
      @gained[what] = gained + change
      change
    end

    # Reports whether a loss of what the receiver holds uses it up for every player: a found item
    # lost outside every list of a story reset (MGQ_MpStoryKeys.reset_list?).
    #
    # @param what [Object] What changes: :gold, or the item.
    # @return [Boolean] Whether it does.
    def used_up?(what)
      return false unless defined?(MGQ_MpStoryKeys) && MGQ_MpStoryKeys.found_item?(what)

      @places.none? { |_site, list, _index, _interpreter| MGQ_MpStoryKeys.reset_list?(list) }
    end

    # Resets the self switches of maps, the view's at once and the receiver's own once committed.
    #
    # @param map_ids [Array<Integer>] The maps.
    def reset_maps(map_ids)
      @view.reset_maps(map_ids)
      @own.keys.each { |kind, key| @own.delete([kind, key]) if kind == 2 && map_ids.include?(key[0]) }
      @made[2] ? @made[2].delete(map_ids) : @reset.concat(map_ids)
      @journal << [:reset, 2, map_ids.dup, nil]
    end

    private

    # Stages the receiver's holdings for the replay, see Stage.
    #
    # @return [Stage, nil] The stage, nil when they cannot be copied.
    def staged
      Stage.new
    rescue => e
      MGQ_MpStoryReplay.log("staging the holdings failed: #{e.class}: #{e.message}")
      nil
    end

    # Reports whether the replay finished and wrote one of its step's keys, finished a run that names
    # none, or finished after the receiver answered a question other than the opener, whose own way
    # it is done with.
    #
    # @return [Boolean] Whether it did.
    def reached?
      @state == :done && (@keys.empty? || @own_way || @writes.any? { |kind, key, _value, _viewed| step_key?(kind, key) })
    end

    # Keeps what the replay did: its holdings merged into the receiver's, then its own keys' writes
    # in order, while it still counts as running, so no run of the player's notes them.
    def commit
      MGQ_MpStoryReplay.current = self
      keep = lambda { keep_changes }
      @around_commit ? @around_commit.call(self, keep) : keep.call
      @committed = true
    ensure
      MGQ_MpStoryReplay.current = nil
    end

    # Applies the staged holdings and the own keys' changes to the receiver's objects.
    def keep_changes
      @stage.commit
      @journal.each { |change| keep_change(*change) }
      $game_map.need_refresh = true unless @writes.empty?
    end

    # Applies one change of the receiver's own keys.
    #
    # @param what [Symbol] :write a key, :reset maps' self switches, or :made an object anew.
    # @param kind [Integer] The keys' kind.
    # @param key [Object] The key, the maps, or the new object.
    # @param value [Object] The value written.
    def keep_change(what, kind, key, value)
      case what
      when :write
        own_keys(kind)[key] = value
        @own_write.call(kind, key, value) if @own_write
      when :reset then own_keys(kind).delete(key)
      when :made
        case kind
        when 0 then $game_switches = key
        when 1 then $game_variables = key
        else $game_self_switches = key
        end
      end
    end

    # The receiver's object of keys of a kind.
    #
    # @param kind [Integer] The kind.
    # @return [Object] The object.
    def own_keys(kind)
      [$game_switches, $game_variables, $game_self_switches][kind]
    end

    # Takes an object of keys the event made anew in place of the receiver's own: it is the
    # replay's until committed, and the view and the staged writes of its kind are dropped.
    #
    # @param kind [Integer] The kind.
    # @param object [Object] The new object.
    def made(kind, object)
      @made[kind] = object
      @view.drop(kind)
      @own.keys.each { |found, key| @own.delete([found, key]) if found == kind }
      @reset.clear if kind == 2
      @journal << [:made, kind, object, nil]
    end

    # Reads the run's start values.
    #
    # @param start [Array<Array>, nil] Each key's kind, key and value, see StoryPlain in the DLL.
    # @return [Hash] The values by [kind, key].
    def start_values(start)
      values = {}
      Array(start).each { |kind, key, value| values[[kind, key]] = MGQ_MpStoryKeys.game_value(kind, value) if kind.is_a?(Integer) && kind < 3 }
      values
    end

    # Tells whether a key is one the open world keeps, the view's test without one given.
    #
    # @param kind [Integer] The key's kind.
    # @param key [Integer, Array] The key.
    # @return [Boolean] Whether it is.
    def kept_key?(kind, key)
      MGQ_MpStoryKeys.class_of(kind, key) & MGQ_MpStoryKeys::KEPT != 0
    end

    # Finds the run's list and binds its map and event.
    #
    # @param entry [Hash] The run.
    # @return [Array, nil] The commands, nil for a site the game does not have.
    def bind(entry)
      case @site[0]
      when "map"
        @map_id = @site[1]
        @event_id = @site[2]
      when "ce"
        @map_id = (entry["map"] || $game_map.map_id).to_i
        @event_id = 0
      end
      MGQ_MpStoryReplay.list_at(@site)
    end

    # Runs the replay's fiber with every stand-in in place, until it ends or asks, commits it once
    # it finished and reached its step, and logs how long a replay took once it ended, which the
    # story step's cost is measured by.
    #
    # @return [Replay] The replay.
    def step
      @state = :running
      began = Time.now
      swapped { drive }
      commit if reached?
      @seconds = @seconds.to_f + (Time.now - began)
      if @state == :done
        MGQ_MpStoryReplay.log(format("replayed %s: %d writes, %d reads in %.1f ms, %s", @site, @writes.size, @reads.size, @seconds * 1000,
                                     @committed ? "kept" : "its step not reached, nothing kept"))
      end
      self
    rescue => e
      @state = :failed
      MGQ_MpStoryReplay.log("the replay of #{@site} failed#{@committed ? '' : ', nothing kept'}: #{e.class}: #{e.message}")
      self
    end

    # Resumes the fiber, answering the message as the message window would, until the list ends or
    # an answer is missing.
    def drive
      MAX_RESUMES.times do
        return if $game_message.busy? && !answer_message
        return @state = :done unless @interpreter.running?

        @interpreter.update
      end
      raise "it did not end after #{MAX_RESUMES} resumes"
    end

    # Answers the message as the message window does: text is shown and closed; a choice, a number,
    # an item, an extended choice or a present is answered from the record; an input the record
    # lacks is asked, or stops the replay while the choices' screen asks only choices.
    #
    # @return [Boolean] Whether the message was answered; false while the receiver is asked or once
    #   the replay stopped.
    def answer_message
      message = $game_message
      kind = input_kind(message)
      lines = message.texts.dup
      unless kind
        message.clear
        return true
      end

      at = kind == "choice" ? choice_now : at_now
      value = @record.take(at, kind)
      return kind == "choice" || MGQ_MpStoryReplay.asks_inputs? ? ask(at, kind, message, lines) : stop(at, kind) if value.nil?

      apply(kind, message, value)
      message.clear
      true
    end

    # Stops the replay at a message input the record lacks that the choices' screen cannot show:
    # it ends as a check that fails, so its run waits.
    #
    # @param at [String] The command that asks.
    # @param kind [String] What it asks.
    # @return [Boolean] False: not answered.
    def stop(at, kind)
      MGQ_MpStoryReplay.log("the replay of #{@site} stops at #{at}: the record holds no #{kind}, and the player is asked only choices")
      @state = :failed
      false
    end

    # Describes what the screen shows for an input other than a choice: a number's digits and the
    # variable's value, or the items the game's item or present window lists, each [id, name, count].
    #
    # @param kind [String] The input's kind.
    # @param message [Game_Message] The message.
    # @return [Hash, nil] The description, nil for a choice.
    def spec_of(kind, message)
      case kind
      when "number" then { "digits" => message.num_input_digits_max, "value" => $game_variables[message.num_input_variable_id] }
      when "item" then { "items" => item_choices(message) }
      when "present" then { "actor" => message.present_actor_id, "items" => presents(message.present_actor_id) }
      end
    end

    # Lists the items the item window offers: the key items held (script 084), or those the event's
    # condition picks, by their base item (script 267).
    #
    # @param message [Game_Message] The message.
    # @return [Array<Array>] Each [id, name, count].
    def item_choices(message)
      condition = message.respond_to?(:item_choice_condition) ? message.item_choice_condition : nil
      items = $game_party.all_items.select { |item| condition ? condition.call(item) : item.is_a?(RPG::Item) && item.key_item? }
      items.map { |item| [condition ? item.base_data.id : item.id, item.name.to_s, $game_party.item_number(item)] }
    end

    # Lists the presents the present window offers a companion (script 164).
    #
    # @param actor_id [Integer] The companion.
    # @return [Array<Array>] Each [id, name, count].
    def presents(actor_id)
      actor = $game_actors[actor_id]
      items = $game_party.all_items.select { |item| item.is_a?(RPG::Item) && item.is_present? && actor.exist_present?(item.id) }
      items.map { |item| [item.id, item.name.to_s, $game_party.item_number(item)] }
    end

    # Tells which input a message waits for.
    #
    # @param message [Game_Message] The message.
    # @return [String, nil] The input's kind, nil for text alone.
    def input_kind(message)
      return "choice" if message.choice? || (message.respond_to?(:ex_choice?) && message.ex_choice?)
      return "number" if message.num_input?
      return "item" if message.item_choice?
      return "present" if message.respond_to?(:present_choice?) && message.present_choice?

      nil
    end

    # Waits for the receiver's answer to a message's input.
    #
    # @param at [String] The command that asks.
    # @param kind [String] What it asks.
    # @param message [Game_Message] The message.
    # @param lines [Array<String>] The message's lines.
    # @return [Boolean] False: not answered.
    def ask(at, kind, message, lines)
      labels, values, cancel = choices_of(kind, message)
      @question = { "at" => at, "kind" => kind, "labels" => labels, "values" => values, "cancel" => cancel, "lines" => lines, "spec" => spec_of(kind, message) }
      @state = :asking
      false
    end

    # Lists the choices of a message's input, the answer each gives and the place cancel answers,
    # as the game's choice window cancels: a label's place, or the place after the labels for the
    # choice's own branch, whose answer goes last. Of an extended choice, it lists those its window
    # lets the player pick.
    #
    # @param kind [String] The input's kind.
    # @param message [Game_Message] The message.
    # @return [Array] The labels, the answers and the cancel's place (nil where the choice has no
    #   cancel).
    def choices_of(kind, message)
      return [[], [], nil] unless kind == "choice"

      if message.respond_to?(:ex_choice?) && message.ex_choice?
        items = (message.ex_choice_item || []).select { |item| MGQ_MpStoryReplay.ex_choice_enabled?(item[2], $game_switches, $game_variables) }
        setting = message.ex_choice_setting
        return with_cancel(items.map { |item| item[0].to_s }, items.map { |item| item[1] }, setting && setting[0].to_i >= 0 ? setting[0] : nil)
      end
      type = message.choice_cancel_type.to_i
      with_cancel(message.choices.map { |label| label.to_s }, (0...message.choices.size).to_a, type > 0 ? type - 1 : nil)
    end

    # Finds the place of the answer cancel gives among a choice's answers, adding it last where no
    # label gives it, as a choice's own branch.
    #
    # @param labels [Array<String>] The labels.
    # @param values [Array] The answer of each label.
    # @param answer [Object, nil] What cancel answers, nil for no cancel.
    # @return [Array] The labels, the answers and the cancel's place.
    def with_cancel(labels, values, answer)
      return [labels, values, nil] if answer.nil?

      place = values.index(answer)
      place ? [labels, values, place] : [labels, values + [answer], labels.size]
    end

    # Applies an answer as the message window does.
    #
    # @param kind [String] The input's kind.
    # @param message [Game_Message] The message.
    # @param value [Object] The answer.
    def apply(kind, message, value)
      case kind
      when "choice"
        if message.respond_to?(:ex_choice?) && message.ex_choice?
          $game_variables[NWConst::Var::EX_CHOICE_RESULT] = value
          message.ex_choice_clear
        elsif message.choice_proc
          message.choice_proc.call(value)
        end
      when "number" then $game_variables[message.num_input_variable_id] = value
      when "item" then $game_variables[message.item_choice_variable_id] = value
      when "present" then give_present(message, value)
      end
    end

    # Gives a present as the present window does, or cancels with an id below 1.
    #
    # @param message [Game_Message] The message, which names the companion.
    # @param item_id [Integer] The present.
    def give_present(message, item_id)
      if item_id > 0
        actor = $game_actors[message.present_actor_id]
        actor.love += actor.present_loveup(item_id)
        $game_party.lose_item($data_items[item_id], 1)
      end
      $game_temp.choice_present_id = item_id
      message.present_actor_id = 0
    end

    # Puts the stand-ins and the staged holdings in place while a block runs, and the receiver's
    # objects back after it, with the medals the replay gained taken off the popup.
    #
    # @yield Runs the replay.
    def swapped
      saved = [$game_switches, $game_variables, $game_self_switches, $game_message, $game_player, $game_timer, $game_map,
               $game_party, $game_actors, $game_library]
      medals = medal_list
      medals_before = medals ? medals.size : 0
      @real_map = saved[6]
      keys = (0..2).map { |kind| Keys.new(self, kind, @made[kind] || saved[kind]) }
      stand_ins = [Player.new(self, "player", saved[4], 0), Timer.new(self, saved[5]), Map.new(self, saved[6])]
      MGQ_MpStoryReplay.current = self
      $game_switches, $game_variables, $game_self_switches = keys
      $game_message = @message
      $game_player, $game_timer, $game_map = stand_ins
      $game_party, $game_actors, $game_library = @stage.objects[0..2]
      yield
    ensure
      if MGQ_MpStoryReplay.current.equal?(self)
        MGQ_MpStoryReplay.current = nil
        put_back(keys, saved)
        take_medals(medals, medals_before) if medals
      end
    end

    # Puts the receiver's objects back. An object of keys the event made anew stays the replay's
    # until it is committed.
    #
    # @param keys [Array<Keys>] The stand-ins of the switches, variables and self switches.
    # @param saved [Array] The receiver's objects as swapped out.
    def put_back(keys, saved)
      [$game_switches, $game_variables, $game_self_switches].each_with_index do |found, kind|
        made(kind, found) unless found.equal?(keys[kind])
      end
      $game_switches, $game_variables, $game_self_switches, $game_message, $game_player, $game_timer, $game_map,
        $game_party, $game_actors, $game_library = saved
    end

    # The medals the game pops up, which gain_medal fills.
    #
    # @return [Array, nil] The list, nil without one.
    def medal_list
      $game_temp ? MGQ_MpGame.get($game_temp, :gain_medals) : nil
    end

    # Takes the medals the replay gained off the popup's list for the notice.
    #
    # @param medals [Array] The popup's list.
    # @param before [Integer] Its size before the replay ran.
    def take_medals(medals, before)
      return if medals.size <= before

      @medals.concat(medals.slice!(before..-1))
    end
  end
end

# Game hooks of this script alone, through core_hooks.rbx.

begin
  # No sound plays, no scene opens and no battle ends while a replay runs.
  MGQ_MpStoryReplay::CLOSED_CALLS.each do |path, own, names|
    owner = path.split("::").inject(Object) { |scope, name| scope && scope.const_defined?(name) ? scope.const_get(name) : nil }
    next unless owner

    target = own ? owner.singleton_class : owner
    names.each do |name|
      next unless target.method_defined?(name)

      MGQ_MpHooks.around(target, name, "story_replay") { |_object, _args, original| MGQ_MpStoryReplay.running? ? nil : original.call }
    end
  end
rescue => e
  MGQ_MpStoryReplay.log("hooks FAILED: #{e.class}: #{e.message}")
end

begin
  # A replay costs the receiver nothing: it takes back of the gold and the items only what it gave,
  # but the found items it uses up.
  MGQ_MpHooks.around(Game_Party, :gain_gold, "story_replay") do |_party, args, original|
    original.call(MGQ_MpStoryReplay.kept_change(:gold, args[0]), *args[1..-1])
  end
  MGQ_MpHooks.around(Game_Party, :gain_item, "story_replay") do |_party, args, original|
    original.call(args[0], MGQ_MpStoryReplay.kept_change(args[0], args[1]), *args[2..-1])
  end
rescue => e
  MGQ_MpStoryReplay.log("party hooks FAILED: #{e.class}: #{e.message}")
end

begin
  # After the map's update, the runs handed to the player are taken while they stand free.
  MGQ_MpHooks.after(Game_Map, :update, "story_replay") { |*_args| MGQ_MpStoryReplay.update }
rescue => e
  MGQ_MpStoryReplay.log("map hook FAILED: #{e.class}: #{e.message}")
end

begin
  # The save keeps the DLL's log of the steps its game took; a loaded save or a new game hands the
  # DLL its own.
  if defined?(DataManager)
    MGQ_MpHooks.before(DataManager.singleton_class, :make_save_contents, "story_replay") { MGQ_MpStoryReplay.saving }
    MGQ_MpHooks.after(DataManager.singleton_class, :extract_save_contents, "story_replay") { |_contents| MGQ_MpStoryReplay.loaded }
    MGQ_MpHooks.after(DataManager.singleton_class, :setup_new_game, "story_replay") { MGQ_MpStoryReplay.new_game }
  end
rescue => e
  MGQ_MpStoryReplay.log("save hooks FAILED: #{e.class}: #{e.message}")
end
