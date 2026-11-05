//----------------------------------------------------------------
//  LiveTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Took the recording's events and values, and the Backline's Frontline, as values and gave the stream's lines as values
//      Paulinchen  2026-10-30: Handed the session to the co-op battles' joins
//                            - Answered a co-op battle's side and stream kinds
//                            - Answered what every kind of live battle decides the same way
//                            - Buffered the host's recording
//                            - Planned a guest's commands and kept a team duel's sides and the Backline's Frontlines
//                            - Answered the live battle's session
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Battles.Live;
using MGQOnline.Game.Battles.Wire;

namespace MGQOnline.Game.Topics;

/// <summary>
/// The bridge topics of the live battle (MGQOnline.Game's Battles/Live folder), which both hosts
/// answer through <see cref="SharedTopics"/>, since battles_sync.rbx hosts the battle server's
/// battles too. A context keeps one battle's state.
/// </summary>
public static class LiveTopics
{
    /// <summary>
    /// Sets the guest's intake of the host's stream up for a battle, see <see cref="GuestStream.Setup"/>:
    /// <c>names</c> (the host's names line, nil before the host's battle is ready), <c>own</c> (the
    /// guest's names the host's party and troop stand for), <c>name_box</c>, <c>lists</c> (the
    /// hooks' <c>log</c>, <c>picture</c>, <c>screen</c> and <c>audio</c> methods, <c>scene_calls</c>
    /// and <c>log_calls</c>) and <c>animations</c> in; the log lines out.
    /// </summary>
    public const string GuestSetup = "live.guest_setup";

    /// <summary>
    /// Takes one send of the host's stream, see <see cref="GuestStream.Take"/>: <c>body</c> and
    /// <c>seat</c> in; <c>lines</c> (the values of each line the guest plays, see
    /// <see cref="WireTopics.ValuesOf"/>), <c>events</c>, <c>unreadable</c>, <c>others_choose</c>
    /// and <c>logs</c> out.
    /// </summary>
    public const string TakeStream = "live.take_stream";

    /// <summary>
    /// Swaps the host's names in a text, see <see cref="GuestStream.Swap"/>: the text in, the text
    /// swapped out.
    /// </summary>
    public const string Swap = "live.swap";

    /// <summary>
    /// Makes the next battle live, see <see cref="LiveSession.Join"/>: <c>role</c>, <c>bid</c>,
    /// <c>seats</c>, <c>player</c>, <c>kind</c>, <c>team</c> and <c>served</c> in; the session's
    /// view out (see <see cref="View"/>).
    /// </summary>
    public const string Join = "live.join";

    /// <summary>
    /// Changes the session: <c>op</c> "start", "finish", "break" (see <see cref="LiveSession.BreakOff"/>)
    /// or "gone" (see <see cref="LiveSession.OtherSideGone"/>) in; <c>done</c> (whether it changed
    /// anything), <c>logs</c> and the view out.
    /// </summary>
    public const string Change = "live.change";

    /// <summary>
    /// Changes the battle's players: <c>op</c> "expect", "unexpect" or "keep" with <c>seats</c>, or
    /// "left" with <c>seat</c> in; the view, with <c>dropped</c> for "keep" and <c>left</c> and
    /// <c>still_in</c> for "left", out.
    /// </summary>
    public const string Players = "live.players";

    /// <summary>
    /// Checks a battle message before its sender is known, see <see cref="LiveSession.Refusal"/>:
    /// <c>channel</c>, <c>bid</c>, <c>kind</c> and <c>who</c> in; the [key, text] of the reason to
    /// leave it out, false to take it.
    /// </summary>
    public const string Admit = "live.admit";

    /// <summary>
    /// Takes a message that arrived, see <see cref="LiveSession.Receive"/>: <c>seat</c>, <c>kind</c>,
    /// <c>body</c> and <c>who</c> in; <c>logs</c> and <c>behind</c> (whether the sends of the stream
    /// waiting put the guest behind) out.
    /// </summary>
    public const string Receive = "live.receive";

    /// <summary>
    /// Takes the oldest message of some kinds, see <see cref="LiveSession.Take"/>: <c>kinds</c> and
    /// <c>seat</c> (nil for any) in; <c>message</c> ([kind, body], nil for none) and <c>behind</c> out.
    /// </summary>
    public const string Take = "live.take";

    /// <summary>
    /// Counts the waiting messages of a kind: the kind in, the count out.
    /// </summary>
    public const string Pending = "live.pending";

    /// <summary>
    /// Checks whether the battle ends, see <see cref="LiveSession.Tick"/>: <c>check</c> ("ending",
    /// "gone", "world", "served" or "departures"), <c>in_world</c>, <c>served_closed</c> and
    /// <c>gone</c> (the seats the world told are gone since the last check) in; <c>ending</c>,
    /// <c>departed</c> ([seat, still in] each), <c>ask</c>, <c>logs</c> and the view out. The check
    /// "frame" counts a frame of the host's recording instead, <c>sends</c> out (see <see cref="Record"/>).
    /// </summary>
    public const string Tick = "live.tick";

    /// <summary>
    /// Tells how the battle ends, see <see cref="LiveVerdicts"/>: <c>of</c> "early" (with
    /// <c>reason</c> and <c>side</c>, whether a forfeit is this game's side's), "guest" (with
    /// <c>result</c> and <c>side</c>, whether this game fought on the host's side) or "gone" (with
    /// <c>side</c>) in; <c>process</c>, <c>log</c>, <c>message</c>, <c>otherwise</c>, and
    /// <c>reason</c> or <c>first</c> (the line logged first) out.
    /// </summary>
    public const string End = "live.end";

    /// <summary>
    /// The host's waits for its guests: <c>op</c> "ready_reset", "ready" (taking the guests' ready
    /// words), "open", "close", "answer" with <c>seat</c>, "unanswer" with <c>seats</c>, "tell"
    /// with <c>seats</c>, "forget" or "host_waiting" in; <c>all</c> and <c>not_ready</c>,
    /// <c>was_open</c>, <c>unanswered</c>, <c>tell</c> (the message's body, nil for none), or
    /// <c>taken</c> and <c>seats</c> out.
    /// </summary>
    public const string Phase = "live.phase";

    /// <summary>
    /// Tells a departure or a join once, see <see cref="LiveSession.Tell"/>: <c>seat</c> and
    /// <c>kind</c> in; whether to tell it out.
    /// </summary>
    public const string Departure = "live.departure";

    /// <summary>
    /// Plans a guest's commands, see <see cref="CommandPlan.Plan"/>: <c>body</c>, <c>seat</c>,
    /// <c>several</c>, <c>owners</c> (each place's owner's seat, nil for none), <c>skills</c> and
    /// <c>items</c> (the tables' sizes) in; <c>places</c> out, per place nil (the computer's
    /// actions stay), an empty list (taken away) or each command as [kind, id, target, chain] (nil
    /// for one the host cannot read); nil for commands that do not read.
    /// </summary>
    public const string Plan = "live.plan";

    /// <summary>
    /// A team duel's sides, see <see cref="TeamSides"/>: <c>op</c> "prepare" with <c>own</c>,
    /// <c>other</c> and <c>same_side</c>, "settle" with <c>host</c> (the host's seat), "take" with
    /// <c>body</c> (the host's heirs) or "gone" with <c>host</c> in; <c>heirs</c> ([seat, heir]
    /// each), <c>post</c> (the heirs' message after a settle that changed them, else nil),
    /// <c>broken</c> and <c>gone</c> out.
    /// </summary>
    public const string Team = "live.team";

    /// <summary>
    /// The Frontlines of a PvP battle with the Backline, see <see cref="BacklineFront"/>: <c>op</c>
    /// "begin" with <c>team</c> and <c>front</c>, "finish", "take" with <c>ids</c> and <c>troop</c>,
    /// or "settle" with <c>front</c> in; <c>front</c> (the Frontline taken or to tell, nil for none)
    /// and <c>unfit</c> (the line logged of a Frontline that does not fit) out.
    /// </summary>
    public const string Backline = "live.backline";

    /// <summary>
    /// The host's recording, see <see cref="RecorderBuffer"/>: <c>op</c> "start", "stop", "event" with
    /// <c>values</c> (the event's kind and values, see <see cref="WireTopics.LineOf"/>), "values" with
    /// <c>battlers</c> ([key, reference, values] each) and <c>full</c>,
    /// "flush" or "counts" in; <c>sends</c> (the sends due, in order), and <c>events</c> and
    /// <c>sends_counted</c> (of the turn for "counts", of the recording for "stop" and "totals", the
    /// events left unsent for "stop") out. A <see cref="Tick"/> of the check "frame" counts a frame
    /// and answers the send due.
    /// </summary>
    public const string Record = "live.record";

    /// <summary>
    /// Answers what the kinds of live battle decided the same way, which MGQ_MpBattles::Mode answers
    /// from here unless a kind's mode answers itself: <c>op</c> "same_side" with <c>seat</c> (whether
    /// a guest stands on the host's side), "players" (the seats of both sides of a team duel), "heir"
    /// with <c>seat</c> (who commands the characters of a player who left), "gone" with <c>host</c>
    /// (whether every opponent of the host left) or "kinds" (the kinds of the battle's own messages
    /// inside the host's stream) in; the answer out.
    /// </summary>
    public const string Mode = "live.mode";

    /// <summary>
    /// Registers the topics on a context, over a live battle of the context's own.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <returns>The live battle's session, whose messages the co-op battles' joins take.</returns>
    public static LiveSession Register(BridgeContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        var session = new LiveSession();
        var sides = new TeamSides();
        RegisterSession(context, session);
        var recorder = new RecorderBuffer();
        context.Register(Tick, (_, request) => request.AsHash()["check"].AsText() == "frame"
            ? new RubyHash { { "sends", Sends(recorder.Tick()) } }
            : TickOf(session, request.AsHash()));
        context.Register(Record, (_, request) => RecordOf(recorder, request.AsHash()));
        context.Register(Plan, (_, request) => PlanOf(session, sides, request.AsHash()));
        context.Register(Team, (_, request) => TeamOf(session, sides, request.AsHash()));
        var backline = new BacklineFront();
        context.Register(Backline, (_, request) => BacklineOf(backline, request.AsHash()));
        context.Register(Mode, (_, request) => ModeOf(session, sides, backline, request.AsHash()));
        var stream = new GuestStream();
        context.Register(GuestSetup, (_, request) => Logs(stream.Setup(SetupOf(request.AsHash()))));
        context.Register(Swap, (_, request) => stream.Swap(request.AsText()));
        context.Register(TakeStream, (_, request) =>
        {
            RubyHash fields = request.AsHash();
            StreamTake taken = stream.Take(fields["body"].AsBytes().Span, fields["seat"].AsInt());
            return new RubyHash
            {
                { "lines", new RubyArray(taken.Lines.Select(line => WireTopics.ValuesOf(RubyString.Utf8(line)))) },
                { "events", taken.Events },
                { "unreadable", taken.Unreadable },
                { "others_choose", taken.OthersChoose },
                { "logs", Logs(taken.Logs) },
            };
        });
        return session;
    }

    /// <summary>
    /// Registers the session's topics.
    /// </summary>
    /// <param name="context">The context.</param>
    /// <param name="session">The context's session.</param>
    private static void RegisterSession(BridgeContext context, LiveSession session)
    {
        context.Register(Join, (_, request) =>
        {
            RubyHash fields = request.AsHash();
            session.Join(fields["role"].AsText(), fields["bid"].AsText(), Seats(fields["seats"]), fields["player"].AsText(), fields["kind"].AsText(),
                fields["team"].AsBool(), fields["served"].AsBool());
            return View(session);
        });
        context.Register(Change, (_, request) => ChangeOf(session, request.AsHash()));
        context.Register(Players, (_, request) => PlayersOf(session, request.AsHash()));
        context.Register(Admit, (_, request) =>
        {
            RubyHash fields = request.AsHash();
            LiveLogLine? refusal = session.Refusal(fields["channel"].AsBool(), PeerText(fields["bid"]), PeerText(fields["kind"]) ?? "",
                PeerText(fields["who"]) ?? "");
            return refusal is null ? false : Line(refusal);
        });
        context.Register(Receive, (_, request) =>
        {
            RubyHash fields = request.AsHash();
            LiveLogLine? line = session.Receive(fields["seat"].AsInt(), PeerText(fields["kind"]) ?? "", PeerText(fields["body"]) ?? "",
                PeerText(fields["who"]) ?? "");
            return new RubyHash { { "logs", Logs(line is null ? [] : [line]) }, { "behind", session.Behind } };
        });
        context.Register(Take, (_, request) =>
        {
            RubyHash fields = request.AsHash();
            LiveMessage? taken = session.Take(Texts(fields["kinds"]), fields["seat"].IsNil ? null : fields["seat"].AsInt());
            return new RubyHash
            {
                { "message", taken is null ? RubyNil.Value : new RubyArray { taken.Kind, taken.Body } },
                { "behind", session.Behind },
            };
        });
        context.Register(Pending, (_, request) => session.Pending(request.AsText()));
        context.Register(End, (_, request) => EndOf(session, request.AsHash()));
        context.Register(Phase, (_, request) => PhaseOf(session, request.AsHash()));
        context.Register(Departure, (_, request) => session.Tell(request.AsHash()["seat"].AsInt(), request.AsHash()["kind"].AsText()));
    }

    /// <summary>
    /// Answers <see cref="Plan"/>.
    /// </summary>
    /// <param name="session">The session, whose team duel alone has heirs.</param>
    /// <param name="sides">The team duel's sides, whose heirs command the characters of who left.</param>
    /// <param name="fields">The request.</param>
    /// <returns>The plan, nil for commands that do not read.</returns>
    private static RubyHash? PlanOf(LiveSession session, TeamSides sides, RubyHash fields)
    {
        List<int?> owners = fields["owners"].AsArray().Select(owner => owner.IsNil ? null : (int?)owner.AsInt()).ToList();
        List<List<PlannedCommand?>?>? plan = CommandPlan.Plan(fields["body"].AsBytes().Span, fields["seat"].IsNil ? null : fields["seat"].AsInt(),
            fields["several"].AsBool(), owners, seat => session.TeamDuel ? sides.HeirOf(seat) : null, fields["skills"].AsInt(), fields["items"].AsInt());
        return plan is null ? null : new RubyHash
        {
            { "places", new RubyArray(plan.Select(place => place is null ? RubyNil.Value : (RubyValue)new RubyArray(place.Select(Command)))) },
        };
    }

    /// <summary>
    /// Writes a planned command as the scripts read it.
    /// </summary>
    /// <param name="command">The command, <see langword="null"/> for one the host cannot read.</param>
    /// <returns>[kind, id, target, chain], the chain nil when the guest sent none; nil for none.</returns>
    private static RubyValue Command(PlannedCommand? command) => command is null ? RubyNil.Value
        : new RubyArray { command.Kind, command.Id, command.Target, command.Chain is null ? RubyNil.Value : new RubyArray(command.Chain.Select(Command)) };

    /// <summary>
    /// Answers <see cref="Team"/>.
    /// </summary>
    /// <param name="session">The session, whose guests still in the duel the sides read.</param>
    /// <param name="sides">The sides.</param>
    /// <param name="fields">The request.</param>
    /// <returns>The heirs and what the step tells.</returns>
    private static RubyHash TeamOf(LiveSession session, TeamSides sides, RubyHash fields)
    {
        RubyValue post = RubyNil.Value;
        bool broken = false;
        bool gone = false;
        switch (fields["op"].AsText())
        {
            case "prepare":
                sides.Prepare(Seats(fields["own"]), Seats(fields["other"]), fields["same_side"].AsBool());
                break;
            case "settle":
                if (sides.Settle(fields["host"].AsInt(), session.GuestsIn))
                {
                    post = sides.HeirsLine();
                }

                break;
            case "take":
                broken = sides.TakeHeirs(fields["body"].AsBytes().Span);
                break;
            case "gone":
                gone = sides.OtherSideGone(fields["host"].AsInt(), session.GuestsIn);
                break;
            default:
                throw new BridgeRequestException($"A team duel's sides have no step {fields["op"].AsText()}.");
        }

        return new RubyHash
        {
            { "heirs", new RubyArray(sides.Heirs.Select(heir => (RubyValue)new RubyArray { heir.Key, heir.Value is int seat ? seat : RubyNil.Value })) },
            { "post", post },
            { "broken", broken },
            { "gone", gone },
        };
    }

    /// <summary>
    /// Answers <see cref="Backline"/>.
    /// </summary>
    /// <param name="backline">The Frontlines.</param>
    /// <param name="fields">The request.</param>
    /// <returns>The Frontline taken or to tell, and the line logged of one that does not fit.</returns>
    private static RubyHash BacklineOf(BacklineFront backline, RubyHash fields)
    {
        List<int>? front = null;
        string? unfit = null;
        switch (fields["op"].AsText())
        {
            case "begin":
                backline.Begin(Seats(fields["team"]), Seats(fields["front"]));
                break;
            case "finish":
                backline.Finish();
                break;
            case "take":
                (front, unfit) = backline.Take(WirePlain.Of(fields["ids"]), Seats(fields["troop"]));
                break;
            case "settle":
                front = backline.Settle(Seats(fields["front"]));
                break;
            default:
                throw new BridgeRequestException($"The Backline has no step {fields["op"].AsText()}.");
        }

        return new RubyHash { { "front", front is null ? RubyNil.Value : SeatList(front) }, { "unfit", unfit } };
    }

    /// <summary>
    /// Writes the session as the scripts cache it: <c>role</c>, <c>player</c>, <c>kind</c>,
    /// <c>team</c>, <c>seats</c>, <c>left</c>, <c>expected</c>, <c>bid</c>, <c>solo</c>,
    /// <c>broken</c>, <c>served</c>, <c>running</c> and <c>behind</c>.
    /// </summary>
    /// <param name="session">The session.</param>
    /// <returns>The view.</returns>
    private static RubyHash View(LiveSession session) => new()
    {
        { "role", session.Role },
        { "player", session.Player },
        { "kind", session.Kind },
        { "team", session.Team },
        { "seats", SeatList(session.Seats) },
        { "left", SeatList(session.Left) },
        { "expected", SeatList(session.Expected) },
        { "bid", session.BattleId },
        { "solo", session.Solo },
        { "broken", session.Broken },
        { "served", session.Served },
        { "running", session.Running },
        { "behind", session.Behind },
    };

    /// <summary>
    /// Answers <see cref="Change"/>.
    /// </summary>
    /// <param name="session">The session.</param>
    /// <param name="fields">The request.</param>
    /// <returns>Whether it changed anything, the lines logged and the view.</returns>
    private static RubyHash ChangeOf(LiveSession session, RubyHash fields)
    {
        var logs = new List<LiveLogLine>();
        bool done;
        switch (fields["op"].AsText())
        {
            case "start":
                session.Start();
                done = true;
                break;
            case "finish":
                done = session.Finish();
                break;
            case "break":
                done = session.BreakOff();
                break;
            case "gone":
                logs.Add(session.OtherSideGone());
                done = true;
                break;
            default:
                throw new BridgeRequestException($"The live battle has no change {fields["op"].AsText()}.");
        }

        RubyHash view = View(session);
        view["done"] = done;
        view["logs"] = Logs(logs);
        return view;
    }

    /// <summary>
    /// Answers <see cref="Players"/>.
    /// </summary>
    /// <param name="session">The session.</param>
    /// <param name="fields">The request.</param>
    /// <returns>The view, with what the change tells.</returns>
    private static RubyHash PlayersOf(LiveSession session, RubyHash fields)
    {
        string op = fields["op"].AsText();
        RubyValue? dropped = null;
        bool left = false;
        switch (op)
        {
            case "expect":
                session.Expect(Seats(fields["seats"]));
                break;
            case "unexpect":
                session.Unexpect(Seats(fields["seats"]));
                break;
            case "keep":
                dropped = SeatList(session.KeepSeats(Seats(fields["seats"])));
                break;
            case "left":
                left = session.GuestLeft(fields["seat"].AsInt());
                break;
            case "gone":
                session.NoteGone(Seats(fields["seats"]));
                break;
            default:
                throw new BridgeRequestException($"The live battle has no change of its players {op}.");
        }

        RubyHash view = View(session);
        view["dropped"] = dropped ?? RubyNil.Value;
        view["left_now"] = left;
        view["still_in"] = session.GuestsIn.Count;
        return view;
    }

    /// <summary>
    /// Answers <see cref="Tick"/>.
    /// </summary>
    /// <param name="session">The session.</param>
    /// <param name="fields">The request.</param>
    /// <returns>The ending, the guests taken out, whether the mode decides, the lines logged and the view.</returns>
    private static RubyHash TickOf(LiveSession session, RubyHash fields)
    {
        session.NoteGone(Seats(fields["gone"]));
        var facts = new LiveFacts(fields["in_world"].AsBool(), fields["served_closed"].AsBool());
        var departed = new List<(int Seat, int StillIn)>();
        bool ask = false;
        LiveTick tick = fields["check"].AsText() switch
        {
            "ending" => session.Tick(facts),
            "gone" => session.Gone(facts),
            "world" => new LiveTick(session.WorldGone(facts, departed, out ask) ? LiveVerdicts.Gone : null, departed, ask, []),
            "served" => new LiveTick(session.ServedGone(facts, departed) ? LiveVerdicts.Gone : null, departed, false, []),
            "departures" => new LiveTick(null, departed, !session.TakeDepartures(departed), []),
            _ => throw new BridgeRequestException($"The live battle has no check {fields["check"].AsText()}."),
        };
        RubyHash view = View(session);
        view["ending"] = tick.Ending;
        view["departed"] = new RubyArray(tick.Departed.Select(left => (RubyValue)new RubyArray { left.Seat, left.StillIn }));
        view["ask"] = tick.Ask;
        view["logs"] = Logs(tick.Logs);
        return view;
    }

    /// <summary>
    /// Answers <see cref="Mode"/>: a team duel's sides, the Backline's message while it is on, and
    /// nothing in any other battle.
    /// </summary>
    /// <param name="session">The session, whose kind decides.</param>
    /// <param name="sides">The team duel's sides.</param>
    /// <param name="backline">The Frontlines of a PvP battle with the Backline.</param>
    /// <param name="fields">The request.</param>
    /// <returns>The answer.</returns>
    private static RubyValue? ModeOf(LiveSession session, TeamSides sides, BacklineFront backline, RubyHash fields)
    {
        bool team = session.TeamDuel;
        int? Seat(string name) => fields[name].IsNil ? null : fields[name].AsInt();
        switch (fields["op"].AsText())
        {
            case "same_side":
                return session.Coop || (team && sides.SameSideAsHost(Seat("seat")));
            case "players":
                return SeatList(team ? sides.Players : []);
            case "heir":
                return team && Seat("seat") is int left && sides.HeirOf(left) is int heir ? heir : null;
            case "gone":
                return team && Seat("host") is int host && sides.OtherSideGone(host, session.GuestsIn);
            case "kinds":
                return new RubyArray(session.Coop ? ["coop_party", "coop_troop"] : team ? ["team_heirs"] : backline.On ? ["pvp_front"] : Array.Empty<RubyValue>());
            default:
                throw new BridgeRequestException($"The kinds of live battle decide no {fields["op"].AsText()}.");
        }
    }

    /// <summary>
    /// Answers <see cref="Record"/>.
    /// </summary>
    /// <param name="recorder">The recording.</param>
    /// <param name="fields">The request.</param>
    /// <returns>The sends due and the counts asked for.</returns>
    private static RubyHash RecordOf(RecorderBuffer recorder, RubyHash fields)
    {
        switch (fields["op"].AsText())
        {
            case "start":
                recorder.Start();
                return new RubyHash { { "sends", new RubyArray() } };
            case "stop":
                return new RubyHash { { "sends", new RubyArray() }, { "events", recorder.Stop() } };
            case "event":
                return new RubyHash { { "sends", Sends(recorder.Event(WireTopics.LineOf(fields["values"]))) } };
            case "values":
                IEnumerable<(long, string, string)> battlers = fields["battlers"].AsArray().Select(entry =>
                {
                    RubyArray parts = entry.AsArray();
                    return (parts[0].AsLong(), parts[1].AsText(), WireTopics.LineOf(parts[2]));
                });
                return new RubyHash { { "sends", new RubyArray(recorder.Values(battlers, fields["full"].AsBool()).Select(send => (RubyValue)send)) } };
            case "flush":
                return new RubyHash { { "sends", Sends(recorder.Flush()) } };
            case "counts":
                (int events, int sends) = recorder.TakeCounts();
                return new RubyHash { { "sends", new RubyArray() }, { "events", events }, { "sends_counted", sends } };
            case "totals":
                return new RubyHash { { "sends", new RubyArray() }, { "events", recorder.TotalEvents }, { "sends_counted", recorder.TotalSends } };
            default:
                throw new BridgeRequestException($"The recording has no step {fields["op"].AsText()}.");
        }
    }

    /// <summary>
    /// Writes the sends due.
    /// </summary>
    /// <param name="send">The send due, <see langword="null"/> for none.</param>
    /// <returns>The list of sends.</returns>
    private static RubyArray Sends(string? send) => send is null ? [] : new RubyArray { send };

    /// <summary>
    /// Answers <see cref="End"/>.
    /// </summary>
    /// <param name="session">The session.</param>
    /// <param name="fields">The request.</param>
    /// <returns>The ending.</returns>
    private static RubyHash EndOf(LiveSession session, RubyHash fields)
    {
        bool side = fields["side"].AsBool();
        switch (fields["of"].AsText())
        {
            case "early":
                string reason = fields["reason"].AsText();
                RubyHash early = EndValue(LiveVerdicts.EndEarly(reason, session.TeamDuel && side, session.Player));
                early["reason"] = LiveVerdicts.ReasonText(reason);
                return early;
            case "guest":
                (string first, LiveEnd end) = LiveVerdicts.GuestEnd(fields["result"].AsText(), side, session.Player);
                RubyHash guest = EndValue(end);
                guest["first"] = first;
                return guest;
            case "gone":
                return EndValue(LiveVerdicts.FriendGone(session, side));
            default:
                throw new BridgeRequestException($"The live battle has no ending of {fields["of"].AsText()}.");
        }
    }

    /// <summary>
    /// Writes an ending.
    /// </summary>
    /// <param name="end">The ending.</param>
    /// <returns><c>process</c>, <c>log</c>, <c>message</c> and <c>otherwise</c>.</returns>
    private static RubyHash EndValue(LiveEnd end) => new()
    {
        { "process", end.Process },
        { "log", end.Log },
        { "message", end.Message },
        { "otherwise", end.Otherwise is null ? RubyNil.Value : EndValue(end.Otherwise) },
    };

    /// <summary>
    /// Answers <see cref="Phase"/>.
    /// </summary>
    /// <param name="session">The session.</param>
    /// <param name="fields">The request.</param>
    /// <returns>What the step tells.</returns>
    private static RubyValue? PhaseOf(LiveSession session, RubyHash fields)
    {
        switch (fields["op"].AsText())
        {
            case "ready_reset":
                session.ResetReady();
                return null;
            case "ready":
                bool all = session.AllReady();
                return new RubyHash { { "all", all }, { "not_ready", SeatList(session.NotReady) }, { "behind", session.Behind } };
            case "not_ready":
                return SeatList(session.NotReady);
            case "open":
                return session.OpenPhase();
            case "close":
                return session.ClosePhase();
            case "unanswered":
                return SeatList(session.Unanswered);
            case "answer":
                session.Answer(fields["seat"].AsInt());
                return SeatList(session.Unanswered);
            case "unanswer":
                session.Unanswer(Seats(fields["seats"]));
                return SeatList(session.Unanswered);
            case "tell":
                return session.TellWaiting(Seats(fields["seats"]));
            case "forget":
                session.ForgetWaiting();
                return null;
            case "host_waiting":
                (List<List<int>> taken, List<int> seats) = session.HostWaiting();
                return new RubyHash { { "taken", new RubyArray(taken.Select(told => (RubyValue)SeatList(told))) }, { "seats", SeatList(seats) } };
            default:
                throw new BridgeRequestException($"The live battle's waits have no step {fields["op"].AsText()}.");
        }
    }

    /// <summary>
    /// Reads seats.
    /// </summary>
    /// <param name="value">The list, nil for none.</param>
    /// <returns>The seats.</returns>
    private static List<int> Seats(RubyValue value) => value.IsNil ? [] : value.AsArray().Select(seat => seat.AsInt()).ToList();

    /// <summary>
    /// Writes seats.
    /// </summary>
    /// <param name="seats">The seats.</param>
    /// <returns>The list.</returns>
    private static RubyArray SeatList(IEnumerable<int> seats) => new(seats.Select(seat => (RubyValue)seat));

    /// <summary>
    /// Writes one log line as the scripts log it.
    /// </summary>
    /// <param name="line">The line.</param>
    /// <returns>[key, text].</returns>
    private static RubyArray Line(LiveLogLine line) => new() { line.Key, line.Text };

    /// <summary>
    /// Reads the guest's setup.
    /// </summary>
    /// <param name="fields">The request.</param>
    /// <returns>The setup.</returns>
    private static StreamSetup SetupOf(RubyHash fields)
    {
        RubyArray own = fields["own"].AsArray();
        RubyHash lists = fields["lists"].AsHash();
        return new StreamSetup(
            fields["names"].IsNil ? null : fields["names"].AsBytes().ToArray(),
            Texts(own[0]),
            Texts(own[1]),
            fields["name_box"].AsBool(),
            Set(lists["log"]),
            Set(lists["picture"]),
            Set(lists["screen"]),
            Set(lists["audio"]),
            Set(lists["scene_calls"]),
            Set(lists["log_calls"]),
            fields["animations"].AsInt());
    }

    /// <summary>
    /// Reads a text another game sent, whatever its encoding.
    /// </summary>
    /// <remarks>A message that cannot be read as text must still reach the check that leaves it out.</remarks>
    /// <param name="value">The value.</param>
    /// <returns>The text, <see langword="null"/> for a value that is no String.</returns>
    private static string? PeerText(RubyValue value) => value is RubyString text ? text.Text : null;

    /// <summary>
    /// Reads a list of texts.
    /// </summary>
    /// <param name="value">The list.</param>
    /// <returns>The texts.</returns>
    private static string[] Texts(RubyValue value) => value.AsArray().Select(text => text.AsText()).ToArray();

    /// <summary>
    /// Reads a list of names as a set.
    /// </summary>
    /// <param name="value">The list.</param>
    /// <returns>The names.</returns>
    private static HashSet<string> Set(RubyValue value) => new(Texts(value), StringComparer.Ordinal);

    /// <summary>
    /// Writes log lines as the scripts log them: each [key, text], the key nil for a line logged
    /// every time.
    /// </summary>
    /// <param name="logs">The lines.</param>
    /// <returns>The lines.</returns>
    private static RubyArray Logs(IEnumerable<LiveLogLine> logs) =>
        new(logs.Select(line => (RubyValue)new RubyArray { line.Key, line.Text }));
}
