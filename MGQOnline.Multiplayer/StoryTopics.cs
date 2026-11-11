//----------------------------------------------------------------
//  StoryTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Handed the catch-up the items unlocking a job or race from the events database
//                            - Took the player's level from the catch-up's look instead of the scripts, and entered the story without one
//      Paulinchen  2026-11-08: Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-11-05: Left reading a frozen fight back to the frozen fights' own topics, which read every fight they take
//                            - Handed the game's events to the list lookup, which reads the maps that differ from the game's own data
//                            - Took and handed the story's keys and values as plain values, see StoryPlain
//                            - Answered a frozen fight as another game reads it back, see FrozenFightText
//                            - Took and handed sites as plain values, and read the sites of an earlier release's save once
//                            - Wrote a Classic leader's whole story and what of it changed as message fields, by ClassicStoryLists
//                            - Told whether a Raid World's telling moves the world's story on, which decides whom it takes along
//                            - Asked the scripts for the common events a telling reaches that the DLL cannot read
//                            - Answered what a Classic leader's story keeps of a member's writes and runs, and which of its changes a member takes, by ClassicMerge
//                            - Told a Classic member's catch-up who keeps each self switch and which party chests gave key items
//                            - Handed the catch-up the items an event of the game takes away
//      Paulinchen  2026-11-01: Dropped the topic of the player's telling, which the telling machine holds
//      Paulinchen  2026-10-31: Told the scripts the routes the Great Decision offers
//                            - Answered the replay of runs handed over, in StoryTopics.Replay.cs
//                            - Sent the player's Raid World runs to their track and handed the scripts its entries in order from the cursors of the save's log
//                            - Told the scripts where the world's log starts, and the world's story there
//      Paulinchen  2026-10-28: Kept the story mapping in the relay mirror and read it back at the first fetch
//                            - Built a Classic party's table from the counts of the events database and the chest flags of the mapping held
//                            - Followed the chain of a story event from the events database, from the keys of its list there
//                            - Followed the chain of a story event over the event source for each request
//                            - Told whether a story event would move a player behind past the end of their part
//                            - Answered the telling machine, which takes the relay's telling lock
//                            - Told the scripts the teller whose ended telling the game has yet to take the track of
//                            - Fetched the mapping in a Classic world too, and handed the scripts the rewards a party member catches up with
//                            - Handed the catch-up the tables the mapping came with
//                            - Handed the catch-up the tables the mapping came with
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Security.Cryptography;
using System.Text.Json;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Data.Events;
using MGQOnline.Game.Catchup;
using MGQOnline.Game.Events;
using MGQOnline.Game.Events.Data;
using MGQOnline.Game.Story;
using MGQOnline.Game.Telling;
using MGQOnline.Multiplayer.Network.Relay;
using MGQOnline.Multiplayer.Network.World;
using MGQOnline.Multiplayer.Topics;

namespace MGQOnline.Multiplayer;

/// <summary>
/// The bridge topics of a Raid World's story on the relay's tracks (<see cref="StoryTrack"/>), of
/// the tables the scripts look each story write up in (the story mapping, fetched as the story
/// starts and again on its new revision, or in a Classic world for the rewards its party members
/// catch up with, and a Classic party's table) and of the player's telling
/// (<see cref="TellingMachine"/>), which takes the relay's telling lock through the track.
/// </summary>
internal sealed partial class StoryTopics : IStoryTrackHost
{
    /// <summary>
    /// The topic that starts the player's story on tracks, its level unknown until the catch-up's
    /// first look: {"world" (the directory's id), "fresh"}.
    /// </summary>
    public const string EnterTopic = "story.enter";

    /// <summary>
    /// The topic that ends it, as the world closed.
    /// </summary>
    public const string CloseTopic = "story.close";

    /// <summary>
    /// The topic the scripts stage a frame's writes with: [[kind, key, value, site], ...], see
    /// <see cref="StoryPlain.WritesOf"/>.
    /// </summary>
    public const string WritesTopic = "story.writes";


    /// <summary>
    /// The topic that hands the player's story the relay asked for: its keys' rows, see <see cref="StoryPlain"/>.
    /// </summary>
    public const string SeedTopic = "story.seed";

    /// <summary>
    /// The topic the scripts stage the seat of the teller the player watches with, nil for none.
    /// </summary>
    public const string WatchTopic = "story.watch";

    /// <summary>
    /// The topic that takes what waits to be written into the game's story, see <see cref="StoryPlain.TakeOf"/>.
    /// </summary>
    public const string TakeTopic = "story.take";

    /// <summary>
    /// The topic that hands out the story mapping's table, see <see cref="TableOf"/>; nil before it came.
    /// </summary>
    public const string ClassesTopic = "story.classes";

    /// <summary>
    /// The topic that builds a Classic party's table from the events database, see <see cref="ClassicOf"/>.
    /// </summary>
    public const string ClassicTopic = "story.classic_table";

    /// <summary>
    /// The topic of what a Classic leader's story keeps of a member's writes and runs, see
    /// <see cref="ClassicMergeOf"/>.
    /// </summary>
    public const string ClassicMergeTopic = "story.classic_merge";

    /// <summary>
    /// The topic of which of a Classic leader's story's changes a member who follows it takes, see
    /// <see cref="ClassicFollowOf"/>.
    /// </summary>
    public const string ClassicFollowTopic = "story.classic_follow";

    /// <summary>
    /// The topic that writes a Classic leader's whole story for a member, see
    /// <see cref="ClassicStoryLists.Full"/>: the lists in; the message's fields out.
    /// </summary>
    public const string ClassicFullTopic = "story.classic_full";

    /// <summary>
    /// The topic that writes what of a Classic leader's story changed, see
    /// <see cref="ClassicStoryLists.Delta"/>: the writes' rows in; the message's fields out.
    /// </summary>
    public const string ClassicDeltaTopic = "story.classic_delta";

    /// <summary>
    /// The topic that reads the sites a save of an earlier release keeps as texts, such as
    /// "map:138:13:1": [text, ...] in; [site, ...] out, see <see cref="StoryPlain.SiteOf"/>.
    /// </summary>
    public const string SitesTopic = "story.sites";

    /// <summary>
    /// Gets the catch-up's tables the story mapping came with, with the items an event of the game
    /// takes away and those unlocking a job or race from the events database; <see langword="null"/>
    /// before the mapping came.
    /// </summary>
    internal CatchupTables? Catchup
    {
        get
        {
            if (_table?.Catchup is not { } tables)
            {
                return null;
            }

            if ((tables.TakenItems.Count == 0 || tables.UnlockItems.Count == 0) && Events().Store is { IsUsable: true } store)
            {
                tables.NoteItemsTaken(store.ItemsTaken());
                tables.NoteUnlockItems(store.UnlockItems());
            }

            return tables;
        }
    }

    /// <summary>
    /// Takes the player's level the catch-up's look read, which the relay's level gates hear.
    /// </summary>
    /// <param name="level">The level.</param>
    internal void TakeLevel(StoryLevel level) => _track.TakeLevel(level);

    /// <summary>
    /// Gets what a Classic member's catch-up reads of the party beyond its tables: who keeps each self
    /// switch by the reviewed list held, and the party chests that gave key items by the events
    /// database; nothing of either before they came.
    /// </summary>
    internal ClassicParty ClassicParty => new(
        key => ScopesOf(true) is { } scopes && scopes.ScopeOf(key) != StoryScope.World,
        (opened, items) => Events().Store is { IsUsable: true } store ? PartyRewards.KeyItemChests(store, opened, items) : []);

    /// <summary>
    /// The topic that takes an event of the map's interpreter starting: {"telling" (whether it is
    /// story the player tells), "by_itself", "map", "site" (see <see cref="StoryPlain"/>, nil for none)}; answers {"telling",
    /// "continued" ("frame", "moved" or nil), "from" (the telling's map before), "hold", "locked"}.
    /// </summary>
    public const string TellingStartTopic = "telling.start";

    /// <summary>
    /// The topic the interpreter asks before a command of the telling while its first waits for the
    /// relay: answers {"command" ("go", "hold", "end" or "unlocked", see <see cref="TellingCommand"/>), "holder" (the seat that tells there, or nil)}.
    /// </summary>
    public const string TellingCommandTopic = "telling.command";

    /// <summary>
    /// The topic that takes the telling's event ending.
    /// </summary>
    public const string TellingEndTopic = "telling.end";

    /// <summary>
    /// The topic that takes the telling moving the player onto another map: {"map" (the one left)}.
    /// </summary>
    public const string TellingMovingTopic = "telling.moving";

    /// <summary>
    /// The topic that takes the telling's transfer landing the player on another map: {"map" (the one arrived on)}.
    /// </summary>
    public const string TellingArrivedTopic = "telling.arrived";

    /// <summary>
    /// The topic that has the mapping fetched from the relay of a Classic world, which plays no story
    /// on tracks: the world's id, nil once it closed.
    /// </summary>
    public const string MappingTopic = "story.mapping";

    /// <summary>
    /// The topic that hands the rewards a party member catches up with, see <see cref="RewardsOf"/>:
    /// the revision the scripts hold, nil for none; nil while it is the one held or before the mapping came.
    /// </summary>
    public const string RewardsTopic = "story.rewards";

    /// <summary>
    /// The topic that tells whether a story event, with the chain it starts across maps (see
    /// <see cref="EventChain"/>), would move the player's story past the end of the part their
    /// track is in (see <see cref="PartEnd"/>): the list named as for <see cref="EventTopics.Sort"/>,
    /// with <c>values</c> as there. Answers <c>{"unknown"=>true}</c> or <c>needs</c> as that does,
    /// else <c>{"leaves", "why"}</c> (nil while it stays).
    /// </summary>
    public const string LeavesPartTopic = "story.leaves_part";

    /// <summary>
    /// The topic that tells whether a Raid World's telling moves the world's story on, which decides
    /// whom it takes along (see <see cref="WorldProgress"/>): <c>told</c>, the <c>progress</c> an earlier
    /// answer gave as the telling started, nil for none; the list the telling runs, named as for
    /// <see cref="EventTopics.Sort"/> with <c>index</c>, the command it runs next, or no list; and
    /// <c>values</c> as there. Answers <c>{"unknown"=>true}</c> or <c>needs</c> as that does, the
    /// latter with <c>ce</c>, the common events the list reaches that the DLL cannot read, else
    /// <c>{"moves", "progress"}</c>: whether the progress changed since <c>told</c> or the list's
    /// commands from <c>index</c> on may change it, and the progress now.
    /// </summary>
    public const string MovesTopic = "story.moves";

    /// <summary>
    /// The topic that hands a run of the player's own game in a Raid World to the relay, after the
    /// writes recorded before it: its entry, see <see cref="ReplayEntry.Write"/>. Answers nil.
    /// </summary>
    public const string HandEntryTopic = "story.hand_entry";

    /// <summary>
    /// The topic that walks the entries of the player's track, see <see cref="StoryTrack.NextRun"/>:
    /// <c>{"free", "waiting"}</c>, whether the player stands free on the map and the ids of the runs
    /// the game holds waiting. Answers the next entry, nil while none is due.
    /// </summary>
    public const string StreamTopic = "story.stream";

    /// <summary>
    /// The event of how the story on tracks stands, see <see cref="StatusOf"/>.
    /// </summary>
    public const string StatusEvent = "story.status";

    /// <summary>
    /// The event of the requests the relay did not keep as written, see <see cref="StoryPlain.RefusalsOf"/>.
    /// </summary>
    public const string RefusedEvent = "story.refused";

    /// <summary>
    /// The letters a telling's id is made of.
    /// </summary>
    private const string TellingLetters = "abcdefghijklmnopqrstuvwxyz0123456789";

    /// <summary>
    /// Bridge frames before a failed fetch of the mapping is tried again, by try.
    /// </summary>
    private static readonly int[] FetchRetryFrames = [120, 300, 600, 1800];

    /// <summary>
    /// Bridge frames between two fetches of the mapping in a Classic world, ten minutes: no track
    /// tells its new revision there.
    /// </summary>
    private const int ClassicFetchFrames = 36_000;

    /// <summary>
    /// The context the events go to.
    /// </summary>
    private readonly BridgeContext _context;

    /// <summary>
    /// The world connection.
    /// </summary>
    private readonly WorldSession _session;

    /// <summary>
    /// The player's story on tracks.
    /// </summary>
    private readonly StoryTrack _track;

    /// <summary>
    /// The player's telling.
    /// </summary>
    private readonly TellingMachine _telling;

    /// <summary>
    /// Guards the mapping a fetch hands over.
    /// </summary>
    private readonly object _gate = new();

    /// <summary>
    /// The status posted last, so it goes out only once it changed.
    /// </summary>
    private RubyValue? _posted;

    /// <summary>
    /// The story mapping's table, <see langword="null"/> before it came.
    /// </summary>
    private StoryTable? _table;

    /// <summary>
    /// A table a fetch read and the frame step has not taken yet. Guarded by <see cref="_gate"/>.
    /// </summary>
    private StoryTable? _fetched;

    /// <summary>
    /// Whether a fetch of the mapping runs. Guarded by <see cref="_gate"/>.
    /// </summary>
    private bool _fetching;

    /// <summary>
    /// How many fetches failed in a row. Guarded by <see cref="_gate"/>.
    /// </summary>
    private int _failures;

    /// <summary>
    /// The bridge frames the last fetch asks the next one to wait, which the frame step turns into
    /// <see cref="_fetchAfter"/>; <see langword="null"/> once taken. Guarded by <see cref="_gate"/>.
    /// </summary>
    private int? _fetchDelay;

    /// <summary>
    /// The bridge frame before which no fetch starts.
    /// </summary>
    private long _fetchAfter;

    /// <summary>
    /// The relay of the world whose story the player plays, <see langword="null"/> outside one.
    /// </summary>
    private Uri? _relay;

    /// <summary>
    /// The relay of the Classic world open, whose mapping is fetched, <see langword="null"/> outside one.
    /// </summary>
    private Uri? _classicRelay;

    /// <summary>
    /// The bridge frame the last fetch of the mapping started at.
    /// </summary>
    private long _fetchedAt;

    /// <summary>
    /// The world connections counted when the story last looked, see <see cref="WorldSession.Connections"/>.
    /// </summary>
    private int _connections;

    /// <summary>
    /// Initializes the story of a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="session">The world connection.</param>
    private StoryTopics(BridgeContext context, WorldSession session)
    {
        _context = context;
        _session = session;
        _track = new StoryTrack(this, () => RandomNumberGenerator.GetString(TellingLetters, 12));
        _telling = new TellingMachine(_track);
        RelayOf = id => session.OpenWorld(id) is { } code ? Relays.AddressOf(code.Relay) : null;
        context.Events.Coalesce(StatusEvent);
    }

    /// <summary>
    /// Gets or sets how the story mapping is fetched from a relay, given the revision held; tests hand
    /// out their own.
    /// </summary>
    internal Func<Uri, long?, JsonDocument> FetchMapping { get; set; } = (relay, known) => new DirectoryClient(relay).GetStoryMapping(known);

    /// <summary>
    /// Gets or sets how the relay of the open world is found by the world's id, <see langword="null"/>
    /// for none; tests hand out their own.
    /// </summary>
    internal Func<string, Uri?> RelayOf { get; set; }

    /// <summary>
    /// Gets or sets how the game's events are found; tests hand out their own.
    /// </summary>
    internal Func<GameEvents> Events { get; set; } = () => GameEvents.Current;

    /// <summary>
    /// Gets or sets how a fetch runs; tests run it at once.
    /// </summary>
    internal Action<Action> Run { get; set; } = work => Threads.Start("MultiplayerStoryMapping", work);

    /// <summary>
    /// Gets or sets how the player's name is found, which the receivers of their runs read; tests
    /// hand out their own.
    /// </summary>
    internal Func<string?> OpenerName { get; set; } = () => Player.Current()?.Name;

    /// <summary>
    /// Registers the topics and the frame step on a context, over the game's world connection.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <returns>The story's topics, whose mapping the catch-up reads.</returns>
    public static StoryTopics Register(BridgeContext context) => Register(context, WorldSession.Current);

    /// <summary>
    /// Registers the topics and the frame step on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="session">The world connection.</param>
    /// <returns>The story's topics, for tests.</returns>
    internal static StoryTopics Register(BridgeContext context, WorldSession session)
    {
        var topics = new StoryTopics(context, session);
        context.Register(EnterTopic, (_, request) => topics.Enter(request.AsHash()));
        context.Register(CloseTopic, (_, _) => topics.Close());
        context.Register(WritesTopic, (_, request) =>
        {
            topics._track.Write(StoryPlain.WritesOf(request.AsArray()));
            return null;
        });

        context.Register(SeedTopic, (_, request) =>
        {
            topics._track.Seed(StoryPlain.TextsOf(request).ToDictionary(pair => pair.Key.ToString(), pair => pair.Value, StringComparer.Ordinal));
            return null;
        });
        context.Register(WatchTopic, (_, request) =>
        {
            topics._track.Watch(request.IsNil ? null : request.AsInt());
            return null;
        });
        context.Register(TakeTopic, (_, _) => topics._track.Take() is { } take ? StoryPlain.TakeOf(take) : null);
        context.Register(ClassesTopic, (_, _) => topics._table is { } table ? TableOf(table) : null);
        context.Register(ClassicTopic, (_, _) => topics.ClassicOf());
        context.Register(ClassicMergeTopic, (_, request) => topics.ClassicMergeOf(request.AsHash()));
        context.Register(ClassicFollowTopic, (_, request) => topics.ClassicFollowOf(request.AsHash()));
        context.Register(ClassicFullTopic, (_, request) => ClassicStoryLists.Full(request.AsHash()));
        context.Register(ClassicDeltaTopic, (_, request) => ClassicStoryLists.Delta(request.AsArray()));
        context.Register(SitesTopic, (_, request) => new RubyArray(request.AsArray().Select(text => StoryPlain.SiteOf(text.AsText()))));
        context.Register(TellingStartTopic, (_, request) => topics.TellingStart(request.AsHash()));
        context.Register(TellingCommandTopic, (_, _) => topics.TellingCommandOf());
        context.Register(TellingEndTopic, (_, _) =>
        {
            topics._telling.End();
            return null;
        });
        context.Register(TellingMovingTopic, (_, request) =>
        {
            topics._telling.Moving(request.AsHash()["map"].AsInt(), context.Frame);
            return null;
        });
        context.Register(TellingArrivedTopic, (_, request) =>
        {
            topics._telling.Arrived(request.AsHash()["map"].AsInt());
            return null;
        });
        context.Register(MappingTopic, (_, request) => topics.FollowClassic(request.IsNil ? null : request.AsText()));
        context.Register(RewardsTopic, (_, request) => topics._table is { } table && (request.IsNil || request.AsLong() != table.Rev) ? RewardsOf(table) : null);
        context.Register(LeavesPartTopic, (_, request) => topics.LeavesPart(request.AsHash()));
        context.Register(MovesTopic, (_, request) => topics.Moves(request.AsHash()));
        context.Register(HandEntryTopic, (_, request) =>
        {
            topics._track.Hand(ReplayEntry.Read(request), topics.OpenerName());
            return null;
        });
        context.Register(StreamTopic, (_, request) => topics.NextRun(request.AsHash()));
        RegisterReplay(context, topics);
        context.EveryFrame(_ => topics.Step());
        return topics;
    }

    /// <summary>
    /// Takes an event of the map's interpreter starting, see <see cref="TellingStartTopic"/>.
    /// </summary>
    /// <param name="request">The event.</param>
    /// <returns>How it goes on with the telling.</returns>
    private RubyHash TellingStart(RubyHash request)
    {
        RubyValue site = request["site"];
        TellingStart start = _telling.Start(request["telling"].AsBool(), request["by_itself"].AsBool(), request["map"].AsInt(), site.IsNil ? null : StoryPlain.SiteText(site), _context.Frame);
        return new RubyHash
        {
            { "telling", start.Telling },
            { "continued", start.Continued switch { TellingContinued.SameFrame => "frame", TellingContinued.Moved => "moved", _ => RubyNil.Value } },
            { "from", start.From },
            { "hold", start.Hold },
            { "locked", start.Locked },
        };
    }

    /// <summary>
    /// Answers <see cref="LeavesPartTopic"/> by the part of the player's track, unknown before the
    /// relay placed them.
    /// </summary>
    /// <param name="request">The list.</param>
    /// <returns>The answer.</returns>
    private RubyHash LeavesPart(RubyHash request)
    {
        GameEvents game = Events();
        IEventSource events = game.Source;
        if (EventTopics.ListOf(events, game, request) is not { } found)
        {
            return new RubyHash { { "unknown", true } };
        }

        var state = new EventTopics.RequestState(request["values"] as RubyHash);
        int map = request["map"] is RubyInteger mapId ? mapId.AsInt() : 0;
        int eventId = request["event"] is RubyInteger id ? id.AsInt() : 0;
        IReadOnlyList<VariableSet> sets = new EventChain(events, new EventCommandIndex(events)).VariableSetsOf(found.Keys, map, eventId, state);
        if (state.Needs() is { } needs)
        {
            return needs;
        }

        PartLeave? leave = PartEnd.Leaving(_track.Synced ? _track.Part : null, sets, Kept);
        return new RubyHash { { "leaves", leave is not null }, { "why", leave?.Why() } };
    }

    /// <summary>
    /// Answers <see cref="MovesTopic"/> by the story mapping held.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The answer.</returns>
    private RubyHash Moves(RubyHash request)
    {
        var progress = new WorldProgress(_table);
        var state = new EventTopics.RequestState(request["values"] as RubyHash);
        long[] now = progress.Now(state);
        if (state.Needs() is { } needs)
        {
            return needs;
        }

        bool moves = request["told"] is RubyArray told && !told.Select(value => value.AsLong()).SequenceEqual(now);
        if (!moves && (request["list"] is RubyArray || request["common"] is RubyInteger || request["page"] is RubyInteger))
        {
            GameEvents game = Events();
            if (EventTopics.ListOf(game.Source, game, request) is not { } found)
            {
                return new RubyHash { { "unknown", true } };
            }

            int place = request["index"] is RubyInteger index ? index.AsInt() : 0;
            var source = new HandedCommonsSource(game.Source, state.HandedCommon);
            moves = progress.Ahead(source, found.Commands, found.ListId is { } listId ? FirstKeptFrom(game.Store, listId, place) : place);
            if (state.Needs() is { } commons)
            {
                return commons;
            }
        }

        return new RubyHash { { "moves", moves }, { "progress", new RubyArray(now.Select(value => (RubyValue)value)) } };
    }

    /// <summary>
    /// Finds the first kept command of a list in the events database at or after a place of the
    /// game's list, as the database keeps only the commands the rules read.
    /// </summary>
    /// <param name="store">The events database.</param>
    /// <param name="listId">The list.</param>
    /// <param name="place">The place in the game's list.</param>
    /// <returns>The kept command's place among the kept ones, their count when none is left.</returns>
    private static int FirstKeptFrom(EventStore store, int listId, int place)
    {
        IReadOnlyList<CommandRow> commands = store.Commands(listId);
        int found = 0;
        while (found < commands.Count && commands[found].Idx < place)
        {
            found++;
        }

        return found;
    }

    /// <summary>
    /// Tells whether the story mapping keeps a variable on the tracks; before it came, every one counts.
    /// </summary>
    /// <param name="variable">The variable.</param>
    /// <returns>Whether it does.</returns>
    private bool Kept(long variable) =>
        _table is not { } table || (variable < table.Variables.Length && ((StoryClass)table.Variables[variable]).HasFlag(StoryClass.Kept));

    /// <summary>
    /// Answers what a command of the telling does while its first waits for the relay, see
    /// <see cref="TellingCommandTopic"/>.
    /// </summary>
    /// <returns>The command and the seat that tells on the map when it ends the event.</returns>
    private RubyHash TellingCommandOf()
    {
        TellingCommand command = _telling.Command(_context.Frame);
        return new RubyHash
        {
            { "command", command switch { TellingCommand.Hold => "hold", TellingCommand.End => "end", TellingCommand.Unlocked => "unlocked", _ => "go" } },
            { "holder", command == TellingCommand.End && _telling.RefusedBy is { } holder ? holder : RubyNil.Value },
        };
    }

    /// <inheritdoc />
    public bool Send(string json) => _session.SendTrack(json);

    /// <inheritdoc />
    void IStoryTrackHost.Log(string line) => Log.Write(line);

    /// <inheritdoc />
    IReadOnlyDictionary<string, long> IStoryTrackHost.Cursors() => _log.Cursors;

    /// <summary>
    /// Writes a story table as the scripts look keys up in it.
    /// </summary>
    /// <param name="table">The table.</param>
    /// <returns>{"rev", "switches" and "variables" (a byte per id, binary), "self" and "common" (the self switch rules' rows with their class, see <see cref="StoryPlain.SelfRules"/>), "index" (each event as map * 1,000,000 + event), "local_steps" ([variable, steps, shared as, [[map, from x], ...]]), "gates" (part => level), "self_default"}.</returns>
    internal static RubyHash TableOf(StoryTable table)
    {
        RubyHash rules = StoryPlain.SelfRules(table.SelfRules, found => (long)found);
        var gates = new RubyHash();
        foreach ((string part, int gate) in table.Gates.OrderBy(entry => entry.Key, StringComparer.Ordinal))
        {
            gates.Add(part, gate);
        }

        return new RubyHash
        {
            { "rev", table.Rev },
            { "switches", RubyString.Binary(table.Switches) },
            { "variables", RubyString.Binary(table.Variables) },
            { "self", rules["self"] },
            { "common", rules["common"] },
            { "index", new RubyArray(table.Index.Order().Select(code => (RubyValue)code)) },
            { "local_steps", new RubyArray(table.LocalSteps.Select(steps => (RubyValue)new RubyArray
                {
                    steps.Variable,
                    new RubyArray(steps.Steps.Select(step => (RubyValue)step)),
                    steps.SharedAs,
                    new RubyArray(steps.Places.Select(place => (RubyValue)new RubyArray { place.Map, place.FromX })),
                })) },
            { "gates", gates },
            { "self_default", (long)table.SelfDefault },
        };
    }

    /// <summary>
    /// Builds a Classic party's table from the game's counts of switches, variables and actors (a
    /// companion each) in the events database's meta rows, with the chest flags of the mapping held,
    /// or the events database's while none is.
    /// </summary>
    /// <remarks>
    /// The mapping's chest flags are the reviewed ones, which differ from the generated ones the
    /// events database holds.
    /// </remarks>
    /// <returns>The table, see <see cref="TableOf"/>; nil without an events database to read.</returns>
    private RubyValue ClassicOf() => ClassicTable() is { } table ? TableOf(table) : RubyNil.Value;

    /// <summary>
    /// Answers <see cref="ClassicMergeTopic"/> by <see cref="ClassicMerge"/>, over the reviewed list
    /// held.
    /// </summary>
    /// <param name="request">"writes" ([kind, key, held, written] each, the key and both values as <see cref="StoryPlain"/> names them) and "runs" (the entries of a member's runs, nil for one that does not read).</param>
    /// <returns>"takes" (whether the story takes each write, in their order) and "keeps" (whether it keeps each run in its stream); nil before the list came.</returns>
    /// <exception cref="BridgeRequestException">A write or a run is no such list.</exception>
    private RubyValue ClassicMergeOf(RubyHash request)
    {
        if (_table is not { } list || ScopesOf(true) is not { } scopes)
        {
            return RubyNil.Value;
        }

        var takes = new RubyArray();
        var changed = new HashSet<StoryKey>();
        foreach (RubyValue write in request["writes"].AsArray())
        {
            RubyArray fields = write.AsArray();
            if (fields.Count != 4)
            {
                throw new BridgeRequestException("A write is [kind, key, held, written].");
            }

            StoryKey key = StoryPlain.KeyOf(fields[0], fields[1]);
            string held = StoryPlain.TextOf(key, fields[2]) ?? string.Empty;
            string written = StoryPlain.TextOf(key, fields[3]) ?? string.Empty;
            bool taken = ClassicMerge.Takes(scopes.ScopeOf(key), list.ClassOf(key), held, written);
            takes.Add(taken);
            if (taken && held != written)
            {
                changed.Add(key);
            }
        }

        var keeps = new RubyArray();
        foreach (RubyValue run in request["runs"].IsNil ? [] : request["runs"].AsArray())
        {
            if (run.IsNil)
            {
                keeps.Add(false);
                continue;
            }

            ReplayEntry entry = ReplayEntry.Read(run);
            string site = entry.Site.ToString();
            IEnumerable<StoryKey> keys = entry.Keys.Keys.Where(key => key.Kind is StoryKeyKind.Switch or StoryKeyKind.Variable or StoryKeyKind.SelfSwitch);
            keeps.Add(ClassicMerge.KeepsRun(keys, changed.Contains, key => scopes.ScopeOf(key, site)));
        }

        return new RubyHash { { "takes", takes }, { "keeps", keeps } };
    }

    /// <summary>
    /// Answers <see cref="ClassicFollowTopic"/> by <see cref="ClassicMerge.Follows"/>, over the
    /// reviewed list held: which of the leader's changes a member who follows the leader's story takes.
    /// </summary>
    /// <param name="request">"keys" ([kind, key] each, see <see cref="StoryPlain"/>), "choices" ({"s", "v"}, the switches and variables the member's own story keeps as choices' outcomes, see choices.personal) and "sizes" ([switches, variables] the member's game has).</param>
    /// <returns>Whether the member takes each change, in their order; none of a switch or variable beyond the member's game; nil before the list came.</returns>
    /// <exception cref="BridgeRequestException">A key is no such list.</exception>
    private RubyValue ClassicFollowOf(RubyHash request)
    {
        if (ScopesOf(true) is not { } scopes)
        {
            return RubyNil.Value;
        }

        HashSet<long> switches = request["choices"] is RubyHash { } choices && choices["s"] is RubyArray s ? [.. s.Select(id => id.AsLong())] : [];
        HashSet<long> variables = request["choices"] is RubyHash { } held && held["v"] is RubyArray v ? [.. v.Select(id => id.AsLong())] : [];
        RubyArray sizes = request["sizes"].AsArray();
        var follows = new RubyArray();
        foreach (RubyValue entry in request["keys"].AsArray())
        {
            RubyArray fields = entry.AsArray();
            StoryKey key = StoryPlain.KeyOf(fields[0], fields[1]);
            bool known = key.Kind == StoryKeyKind.SelfSwitch || (key.Id > 0 && key.Id < sizes[key.Kind == StoryKeyKind.Switch ? 0 : 1].AsLong());
            bool choice = key.Kind == StoryKeyKind.Switch ? switches.Contains(key.Id) : key.Kind == StoryKeyKind.Variable && variables.Contains(key.Id);
            follows.Add(known && ClassicMerge.Follows(scopes.ScopeOf(key), choice));
        }

        return follows;
    }

    /// <summary>
    /// Builds a Classic party's table, see <see cref="ClassicOf"/>.
    /// </summary>
    /// <returns>The table, <see langword="null"/> without an events database to read.</returns>
    private StoryTable? ClassicTable()
    {
        EventStore store = Events().Store;
        if (store.Meta is not { } meta)
        {
            Log.Write($"story track: a Classic party's table is not built: {store.Problem}");
            return null;
        }

        int Count(string name) => (int)meta.Counts.GetValueOrDefault(name);
        IReadOnlyList<int> chestFlags = _table is { } table ? table.Catchup.ChestFlags : store.ChestFlags();
        return ClassicStoryTable.Build(Count("switches"), Count("variables"), Count("actors"), chestFlags);
    }


    /// <summary>
    /// Starts the player's story on tracks in the open world.
    /// </summary>
    /// <param name="request">{"world", "fresh"}.</param>
    /// <returns><see langword="null"/>, no reply.</returns>
    private RubyValue? Enter(RubyHash request)
    {
        _relay = RelayOf(request["world"].AsText());
        if (_relay is null)
        {
            Log.Write($"story track: the open world is no world {Log.Short(request["world"].AsText())} of a known relay, so its story does not start");
            return null;
        }

        _track.Enter(request["fresh"] is RubyBool { Flag: true }, request["world"].AsText());
        _connections = _session.Connections;
        _track.Connection(_session.IsOpen());
        return null;
    }

    /// <summary>
    /// Answers <see cref="StreamTopic"/>.
    /// </summary>
    /// <param name="request">{"free", "waiting"}.</param>
    /// <returns>The next entry, nil while none is due.</returns>
    private RubyValue NextRun(RubyHash request)
    {
        HashSet<string> waiting = request["waiting"].IsNil ? [] : [.. request["waiting"].AsArray().Select(id => id.AsText())];
        return _track.NextRun(request["free"] is RubyBool { Flag: true }, waiting) is { } entry ? entry.Write() : RubyNil.Value;
    }

    /// <summary>
    /// Ends the player's story on tracks.
    /// </summary>
    /// <returns><see langword="null"/>, no reply.</returns>
    private RubyValue? Close()
    {
        _relay = null;
        _telling.Forget();
        _track.Leave();
        _track.Connection(false);
        return null;
    }

    /// <summary>
    /// Runs the story's frame: the connection, the relay's frames, the mapping, the telling's end of
    /// frame, and the status and refusals the scripts read.
    /// </summary>
    private void Step()
    {
        _telling.Step(_context.Frame);
        if (_relay is not null)
        {
            int connections = _session.Connections;
            if (connections != _connections)
            {
                // A new connection: the relay knows nothing of the player on it before they sync.
                _connections = connections;
                _track.Connection(false);
            }

            _track.Connection(_session.IsOpen());
            while (_session.TakeTrackFrame() is { } frame)
            {
                _track.Receive(frame);
            }

            FollowMapping(_relay, false);
        }
        else if (_classicRelay is { } classic)
        {
            FollowMapping(classic, true);
        }

        if (_track.TakeRefusals() is { Count: > 0 } refusals)
        {
            _context.Events.Post(RefusedEvent, StoryPlain.RefusalsOf(refusals));
        }

        RubyHash status = StatusOf();
        if (_posted is null || !_posted.Equals(status))
        {
            _posted = status;
            _context.Events.Post(StatusEvent, status);
        }
    }

    /// <summary>
    /// Has the mapping fetched from the relay of a Classic world, or no longer once it closed.
    /// </summary>
    /// <param name="world">The world's id, <see langword="null"/> once it closed.</param>
    /// <returns><see langword="null"/>, no reply.</returns>
    private RubyValue? FollowClassic(string? world)
    {
        _classicRelay = world is null ? null : RelayOf(world);
        if (world is not null && _classicRelay is null)
        {
            Log.Write($"story track: the Classic world {Log.Short(world)} is of no known relay, so its story mapping is not fetched");
        }

        return null;
    }

    /// <summary>
    /// Writes the rewards a party member catches up with as the scripts read them.
    /// </summary>
    /// <param name="table">The mapping's table.</param>
    /// <returns>The mapping's "rev" and the rewards, see <see cref="PartyRewards.Write"/>.</returns>
    internal static RubyHash RewardsOf(StoryTable table)
    {
        RubyHash rewards = PartyRewards.Write(table.Catchup);
        rewards["rev"] = table.Rev;
        return rewards;
    }

    /// <summary>
    /// Takes a mapping a fetch read, and starts a fetch while none came yet, or on a story on tracks
    /// once the relay reads requests by a newer revision than the one held, in a Classic world every
    /// <see cref="ClassicFetchFrames"/>.
    /// </summary>
    /// <param name="relay">The relay.</param>
    /// <param name="classic">Whether it is a Classic world's.</param>
    private void FollowMapping(Uri relay, bool classic)
    {
        long? known;
        lock (_gate)
        {
            if (_fetched is { } fetched)
            {
                _table = fetched;
                _fetched = null;
                Log.Write($"story track: read the story mapping at revision {fetched.Rev}");
            }

            if (_fetchDelay is { } delay)
            {
                _fetchAfter = _context.Frame + delay;
                _fetchDelay = null;
            }

            if (_fetching || _context.Frame < _fetchAfter || (_table is { } held && (classic ? _context.Frame - _fetchedAt < ClassicFetchFrames : held.Rev >= _track.MappingRev)))
            {
                return;
            }

            _fetching = true;
            _fetchedAt = _context.Frame;
            known = _table?.Rev;
        }

        Run(() => FetchFrom(relay, known));
    }

    /// <summary>
    /// Fetches the mapping and hands its table to the next frame, or times the next try. While no
    /// table is held, the relay mirror's goes to the next frame first and its revision to the relay,
    /// so a relay that answers the same or none still leaves the table; a fetch that brought rows
    /// is kept in the mirror.
    /// </summary>
    /// <param name="relay">The relay.</param>
    /// <param name="known">The revision held, <see langword="null"/> for none.</param>
    private void FetchFrom(Uri relay, long? known)
    {
        EventStore store = Events().Store;
        StoryMirror? mirror = store.Mirror;
        var stamp = new MirrorStamp(relay.GetLeftPart(UriPartial.Authority), store.Meta?.Build.Fingerprint ?? string.Empty);
        if (known is null && mirror is not null && Mirrored(mirror, stamp) is { } mirrored)
        {
            lock (_gate)
            {
                _fetched = mirrored;
            }

            known = mirrored.Rev;
        }

        StoryTable? table = null;
        bool failed = false;
        try
        {
            using JsonDocument document = FetchMapping(relay, known);
            (long rev, bool same) = StoryMapping.RevisionOf(document.RootElement);
            table = same ? null : StoryMapping.Read(document.RootElement);
            if (same)
            {
                Log.Write($"story track: the story mapping stayed at revision {rev}");
            }
            else if (mirror is not null)
            {
                Log.Write(mirror.Write(document.RootElement, stamp, DateTime.UtcNow) is { } problem
                    ? $"story track: {problem}"
                    : $"story track: kept the story mapping at revision {rev} in the relay mirror");
            }
        }
        catch (Exception ex) when (ex is DirectoryException or JsonException or InvalidOperationException)
        {
            failed = true;
            Log.Write($"story track: fetching the story mapping failed: {ex.Message}");
        }

        lock (_gate)
        {
            _fetching = false;
            _fetched = table ?? _fetched;
            _failures = failed ? _failures + 1 : 0;
            // A mapping that stayed or failed waits, so a relay telling a newer revision is not asked every frame.
            _fetchDelay = failed ? FetchRetryFrames[Math.Min(_failures, FetchRetryFrames.Length) - 1] : table is null ? FetchRetryFrames[^1] : 0;
        }
    }

    /// <summary>
    /// Reads the mapping the relay mirror holds for a relay and the game data.
    /// </summary>
    /// <param name="mirror">The mirror.</param>
    /// <param name="stamp">The relay and the game data.</param>
    /// <returns>Its table, <see langword="null"/> for none.</returns>
    private static StoryTable? Mirrored(StoryMirror mirror, MirrorStamp stamp)
    {
        MirrorRead read = mirror.Read(stamp);
        if (read.Note is { } note)
        {
            Log.Write($"story track: {note}");
        }

        if (read.Answer is null)
        {
            return null;
        }

        try
        {
            using JsonDocument document = JsonDocument.Parse(read.Answer);
            StoryTable table = StoryMapping.Read(document.RootElement);
            Log.Write($"story track: read the story mapping at revision {table.Rev} from the relay mirror");
            return table;
        }
        catch (Exception ex) when (ex is JsonException or InvalidOperationException)
        {
            Log.Write($"story track: the relay mirror holds no story mapping that reads: {ex.Message}");
            return null;
        }
    }

    /// <summary>
    /// Describes how the story on tracks stands, as the scripts read it each frame.
    /// </summary>
    /// <returns>{"synced", "track", "part", "gate", "rev", "taken", "world" ({"rev", "part", "route", "done", "open", "checkpoints", "start" (the story markers where the world's log starts, or nil)} or nil), "pending", "need_seed", "classes" (the mapping's revision held, nil before), "tellings" (seat => [telling, map, site], see <see cref="StoryPlain"/>), "told" (seat => revision), "await" (the seat whose ended telling the game has yet to take the track of, or nil), "telling" (true, false or nil), "holder", "unanswered"}.</returns>
    private RubyHash StatusOf()
    {
        var tellings = new RubyHash();
        foreach ((int seat, StoryTelling telling) in _track.Tellings.OrderBy(entry => entry.Key))
        {
            tellings.Add(seat, new RubyArray { telling.Telling, telling.Map, StoryPlain.SiteOf(telling.Site) });
        }

        var told = new RubyHash();
        foreach ((int seat, long rev) in _track.Told.OrderBy(entry => entry.Key))
        {
            told.Add(seat, rev);
        }

        RubyValue world = _track.World is { } summary
            ? new RubyHash
            {
                { "rev", summary.Rev },
                { "part", summary.Part },
                { "route", summary.Route },
                { "done", new RubyArray(summary.Done.Select(route => (RubyValue)route)) },
                { "open", new RubyArray(summary.Open.Select(route => (RubyValue)route)) },
                { "checkpoints", new RubyArray(summary.Checkpoints.Select(part => (RubyValue)part)) },
                { "start", summary.Start is { } start ? new RubyArray(start.Select(marker => (RubyValue)marker)) : RubyNil.Value },
            }
            : RubyNil.Value;
        return new RubyHash
        {
            { "synced", _track.Synced },
            { "track", _track.Track },
            { "part", _track.Part },
            { "gate", _track.Gate is { } gate ? gate : RubyNil.Value },
            { "rev", _track.TrackRev },
            { "taken", _track.TakenRev },
            { "world", world },
            { "pending", _track.Pending },
            { "need_seed", _track.NeedsSeed },
            { "classes", _table is { } table ? table.Rev : RubyNil.Value },
            { "tellings", tellings },
            { "told", told },
            { "await", _track.AwaitingSeat is { } awaiting ? awaiting : RubyNil.Value },
            { "telling", _track.TellingGranted is { } granted ? granted : RubyNil.Value },
            { "holder", _track.TellingHolder is { } holder ? holder : RubyNil.Value },
            { "unanswered", _track.Unanswered },
        };
    }
}
