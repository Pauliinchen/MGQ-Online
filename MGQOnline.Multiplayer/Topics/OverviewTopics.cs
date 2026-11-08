//----------------------------------------------------------------
//  OverviewTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-08: Walked the quests over the game's events and took their messages as the scripts look them up
//                            - Moved to the MGQOnline.Multiplayer namespace
//      Paulinchen  2026-11-01: Dropped the story topics no script calls, since the rows and pages write the story
//      Paulinchen  2026-10-31: Built the world, quests and unlocks pages
//                            - Built the player, party, raid and map rows
//                            - Kept the told levels, place and progress of the player
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Events.Data;
using MGQOnline.Game.Overview;
using MGQOnline.Game.Raid;
using MGQOnline.Game.World;
using MGQOnline.Multiplayer.Network.World;

namespace MGQOnline.Multiplayer.Topics;

/// <summary>
/// The bridge topics through which the World overview writes the title, see <see cref="OverviewText"/>,
/// and keeps what the player tells the others, see <see cref="OverviewState"/>.
/// </summary>
internal static class OverviewTopics
{
    /// <summary>
    /// Writes what the title and the World page say of the world: <c>raid</c> and <c>difficulty</c>
    /// (the world's value, nil while the players keep their own) in; <c>tail</c> (after the world's
    /// name in the title) and <c>note</c> (the World page's) out.
    /// </summary>
    public const string Title = "overview.title";

    /// <summary>
    /// Asks the game to read the player's levels and story, every <see cref="OverviewState.ReadFrames"/>
    /// while in a world: <see langword="true"/> as the payload; the game answers through <see cref="Tell"/>.
    /// </summary>
    public const string ReadEvent = "overview.read";

    /// <summary>
    /// Keeps what the game read: <c>lv</c>, <c>flv</c> (nil outside a Raid World), <c>story</c> (as
    /// <see cref="StoryOf"/> takes it) and <c>battle</c> (whether a co-op battle runs) in; the log's
    /// line out, nil while nothing changed.
    /// </summary>
    public const string Tell = "overview.tell";

    /// <summary>
    /// Keeps where the player is and writes the fields the overview adds to the player's state: the
    /// place in; <c>place</c>, <c>lv</c>, <c>progress</c> and in a Raid World <c>flv</c> out.
    /// </summary>
    public const string Fields = "overview.fields";

    /// <summary>
    /// Hands out the lists of players, built once a frame: <c>serial</c> (the serial the scripts hold,
    /// nil for none) and <c>name</c> (the player's) in; nil while the lists are the same, else
    /// <c>serial</c>, <c>players</c>, <c>lines</c>, <c>party</c>, <c>raid_party</c> and <c>map</c> out,
    /// see <see cref="RowValue"/> and <see cref="LineValue"/>.
    /// </summary>
    public const string Rows = "overview.rows";

    /// <summary>
    /// Lays the World page out: <c>seats</c>, <c>story</c> (nil, or <c>part</c> and <c>done</c>),
    /// <c>main</c> (see <see cref="MessagesOf"/>), <c>sections</c> ([name, [boss names]] each),
    /// <c>bosses</c> ({boss name => [section, tier]}) and <c>tiers</c> ({tier => [[stat, factor
    /// text]]}) in; the page out, see <see cref="ModelValue"/>.
    /// </summary>
    public const string WorldPage = "overview.world";

    /// <summary>
    /// Lays the Quests page out: <c>main</c> (see <see cref="MessagesOf"/>), <c>side</c> and <c>companion</c>
    /// (such messages for each quest) in; the page out, see <see cref="ModelValue"/>.
    /// </summary>
    public const string QuestsPage = "overview.quests";

    /// <summary>
    /// Walks the quests the game tells now (<see cref="QuestWalk"/>): <c>party</c> (the party's characters),
    /// <c>items</c> (the items it holds) and <c>values</c> (see <see cref="EventTopics.RequestState"/>) in;
    /// <c>needs</c>, else <c>main</c> (the objective's messages), <c>side</c> and <c>companion</c> (each
    /// quest's messages) and <c>board</c> (the board's page, nil when the game has none) out. A message
    /// is [site, place], as the story replay names a command.
    /// </summary>
    public const string QuestWalkTopic = "overview.quest_walk";

    /// <summary>
    /// Lays the Unlocks page out: <c>target</c>, <c>level</c> and <c>unlocks</c> ([level, name, got,
    /// due] each) in; the page out, see <see cref="ModelValue"/>.
    /// </summary>
    public const string UnlocksPage = "overview.unlocks";

    /// <summary>
    /// Opens or folds a group of a page's list: <c>page</c>, <c>key</c> and <c>open</c> (whether it
    /// is open now) in; nothing out.
    /// </summary>
    public const string Fold = "overview.fold";

    /// <summary>
    /// The whole parts a gauge's share crosses the bridge in, since no float crosses it.
    /// </summary>
    public const long GaugeParts = 1_000_000;

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="events">Gives the game's events once a topic is called.</param>
    public static void Register(BridgeContext context, System.Func<GameEvents> events)
    {
        context.Register(Title, (_, request) => TitleOf(request.AsHash()));
        context.Register(QuestWalkTopic, (_, request) => QuestWalkOf(events(), request.AsHash()));
    }

    /// <summary>
    /// Registers the topics of the open world's room on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="room">The world's room.</param>
    public static void RegisterRoom(BridgeContext context, WorldRoom room) => RegisterRoom(context, room, RaidBosses.Current.Ledger);

    /// <summary>
    /// Registers the topics of the open world's room on a context, with the world's pools.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    /// <param name="room">The world's room.</param>
    /// <param name="ledger">The world's pools.</param>
    internal static void RegisterRoom(BridgeContext context, WorldRoom room, PoolLedger ledger)
    {
        var state = new OverviewState();
        context.EveryFrame(drained =>
        {
            if (state.Step(room.InWorld))
            {
                drained.Events.Post(ReadEvent, true);
            }
        });
        context.Register(Tell, (_, request) => TellOf(state, request.AsHash()));
        context.Register(Fields, (_, request) => FieldsOf(state.Fields(request.AsText(), room.Raid)));
        var feed = new OverviewFeed();
        context.Register(Rows, (asked, request) => RowsOf(feed, asked.Frame, request.AsHash(), name => OverviewRows.All(room, state, name)));
        var folds = new OverviewFolds();
        context.Register(WorldPage, (_, request) => ModelValue(OverviewPages.World(WorldFactsOf(room, request.AsHash()), folds, ledger.Pools(), ledger.KeysAsTold())));
        context.Register(QuestsPage, (_, request) => QuestsOf(request.AsHash(), folds));
        context.Register(UnlocksPage, (_, request) => UnlocksOf(request.AsHash(), folds));
        context.Register(Fold, (_, request) =>
        {
            RubyHash fold = request.AsHash();
            folds.Choose(fold["page"].AsText(), fold["key"].AsText(), fold["open"] is RubyBool { Flag: true });
            return null;
        });
    }

    /// <summary>
    /// Reads what the World page shows besides the pools.
    /// </summary>
    /// <param name="room">The world's room.</param>
    /// <param name="request">The request, see <see cref="WorldPage"/>.</param>
    /// <returns>The facts.</returns>
    private static OverviewWorldFacts WorldFactsOf(WorldRoom room, RubyHash request)
    {
        var bosses = new Dictionary<string, OverviewBossFacts>(System.StringComparer.Ordinal);
        foreach (var (name, facts) in request["bosses"].AsHash())
        {
            RubyArray pair = facts.AsArray();
            bosses[name.AsText()] = new OverviewBossFacts(pair[0].IsNil ? null : pair[0].AsText(), pair[1].IsNil ? null : pair[1].AsInt());
        }

        var tiers = new Dictionary<int, IReadOnlyList<OverviewTierStat>>();
        foreach (var (tier, stats) in request["tiers"].AsHash())
        {
            tiers[tier.AsInt()] = [.. stats.AsArray().Select(stat => new OverviewTierStat(stat.AsArray()[0].AsText(), stat.AsArray()[1].AsText()))];
        }

        RubyValue story = request["story"];
        RubyValue seats = request["seats"];
        return new OverviewWorldFacts(
            room.Raid,
            1 + room.Peers.Count(peer => peer.State.Has("name")),
            seats.IsNil ? 0 : seats.AsInt(),
            story.IsNil ? null : new OverviewWorldStory(story.AsHash()["part"].AsText(), [.. story.AsHash()["done"].AsArray().Select(part => part.AsText())]),
            OverviewPages.Told(MessagesOf(request["main"]), false),
            [.. request["sections"].AsArray().Select(section => new OverviewSection(section.AsArray()[0].AsText(), [.. section.AsArray()[1].AsArray().Select(boss => boss.AsText())]))],
            bosses,
            tiers);
    }

    /// <summary>
    /// Answers <see cref="QuestsPage"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <param name="folds">The groups the player opened or folded.</param>
    /// <returns>The page.</returns>
    private static RubyHash QuestsOf(RubyHash request, OverviewFolds folds) =>
        ModelValue(OverviewPages.Quests(MessagesOf(request["main"]), [.. request["side"].AsArray().Select(MessagesOf)],
            [.. request["companion"].AsArray().Select(MessagesOf)], folds));

    /// <summary>
    /// Answers <see cref="UnlocksPage"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <param name="folds">The groups the player opened or folded.</param>
    /// <returns>The page.</returns>
    private static RubyHash UnlocksOf(RubyHash request, OverviewFolds folds)
    {
        List<OverviewUnlock> unlocks = [.. request["unlocks"].AsArray().Select(unlock => unlock.AsArray())
            .Select(unlock => new OverviewUnlock(unlock[0].AsInt(), unlock[1].AsText(), unlock[2] is RubyBool { Flag: true }, unlock[3] is RubyBool { Flag: true }))];
        RubyValue target = request["target"];
        RubyValue level = request["level"];
        return ModelValue(OverviewPages.Unlocks(target.IsNil ? null : target.AsInt(), level.IsNil ? null : level.AsInt(), unlocks, folds));
    }

    /// <summary>
    /// Reads a quest's messages as the scripts looked them up: [speaker (nil for none), text] each.
    /// </summary>
    /// <param name="messages">The messages.</param>
    /// <returns>The messages.</returns>
    private static IReadOnlyList<OverviewMessage> MessagesOf(RubyValue messages) =>
        [.. messages.AsArray().Select(message => message.AsArray()).Select(pair => new OverviewMessage(pair[0].IsNil ? null : pair[0].AsText(), pair[1].AsText()))];

    /// <summary>
    /// Answers <see cref="QuestWalkTopic"/>.
    /// </summary>
    /// <param name="events">The game's events.</param>
    /// <param name="request">The request.</param>
    /// <returns>The values the walk lacked, else the quests.</returns>
    internal static RubyHash QuestWalkOf(GameEvents events, RubyHash request)
    {
        var values = new EventTopics.RequestState(request["values"] as RubyHash);
        var state = new RequestQuestState(values, [.. request["party"].AsArray().Select(id => id.AsLong())], [.. request["items"].AsArray().Select(id => id.AsLong())]);
        QuestPlaces places = QuestWalk.Walk(new HandedCommonsSource(events.Source, values.HandedCommon), state);
        RubyArray Messages(IReadOnlyList<QuestMessage> messages) => new(messages.Select(message => (RubyValue)new RubyArray { message.Site.Plain(), message.Place }));
        return values.Needs() ?? new RubyHash
        {
            { "main", Messages(places.Main) },
            { "side", new RubyArray(places.Sides.Select(quest => (RubyValue)Messages(quest))) },
            { "companion", new RubyArray(places.Companions.Select(quest => (RubyValue)Messages(quest))) },
            { "board", places.Board is { } board ? board.Plain() : RubyNil.Value },
        };
    }

    /// <summary>
    /// Describes a page for the scripts.
    /// </summary>
    /// <param name="model">The page.</param>
    /// <returns><c>head</c> (<c>title</c>, <c>note</c>, <c>lines</c> and <c>entry</c>, see <see cref="EntryValue"/>),
    /// <c>rows</c> (["none", text], or ["fold"] or ["entry"] with the row's view, see <see cref="ViewValue"/>,
    /// and its entry) and <c>picks</c> (each pick's place among the rows, -1 for the head's entry).</returns>
    private static RubyHash ModelValue(OverviewModel model)
    {
        var rows = new RubyArray();
        foreach (OverviewItem item in model.Rows)
        {
            rows.Add(item.Entry is { } entry
                ? new RubyArray { entry is OverviewFold ? "fold" : "entry", ViewValue(entry.Row()), EntryValue(entry) }
                : new RubyArray { "none", item.None });
        }

        var picks = new RubyArray();
        foreach (OverviewEntry pick in model.Picks)
        {
            int index = -1;
            for (int at = 0; at < model.Rows.Count; at++)
            {
                index = ReferenceEquals(model.Rows[at].Entry, pick) ? at : index;
            }

            picks.Add(index);
        }

        var head = new RubyHash
        {
            { "title", model.Head.Title },
            { "note", model.Head.Note },
            { "lines", Texts(model.Head.Lines) },
            { "entry", model.Head.Entry is { } shown ? EntryValue(shown) : RubyNil.Value },
        };
        return new RubyHash { { "head", head }, { "rows", rows }, { "picks", picks } };
    }

    /// <summary>
    /// Describes what a list row shows for the scripts.
    /// </summary>
    /// <param name="view">The row.</param>
    /// <returns>[label, text, note, dim, gauge in <see cref="GaugeParts"/> (nil for none)].</returns>
    private static RubyArray ViewValue(OverviewRowView view) =>
        new() { view.Label, view.Text, view.Note, view.Dim, view.Gauge is { } share ? Parts(share) : RubyNil.Value };

    /// <summary>
    /// Describes an entry for the scripts.
    /// </summary>
    /// <param name="entry">The entry.</param>
    /// <returns>["fold", key, title, open], ["note", title, texts], ["quest", kind, speaker, texts,
    /// number, title], ["boss", section, name, defeated, by, pane ([kind, text, share in
    /// <see cref="GaugeParts"/>] each)] or ["level", level, unlocks (places in the list handed), got, due].</returns>
    private static RubyArray EntryValue(OverviewEntry entry) => entry switch
    {
        OverviewFold fold => new() { "fold", fold.Key, fold.Title, fold.Open },
        OverviewNote note => new() { "note", note.Title, Texts(note.Texts) },
        OverviewQuest quest => new() { "quest", quest.Kind, quest.Speaker, Texts(quest.Texts), quest.Number is { } number ? number : RubyNil.Value, quest.Title },
        OverviewBossEntry boss => new()
        {
            "boss", boss.Section, boss.Boss.Name, boss.Boss.Defeated, boss.Boss.By,
            new RubyArray(boss.Pane.Select(line => (RubyValue)new RubyArray { line.Kind, line.Text, Parts(line.Share) })),
        },
        OverviewLevel level => new() { "level", level.Level, new RubyArray(level.Unlocks.Select(index => (RubyValue)index)), level.Got, level.Due },
        _ => new(),
    };

    /// <summary>
    /// Writes texts for the scripts.
    /// </summary>
    /// <param name="texts">The texts.</param>
    /// <returns>The texts.</returns>
    private static RubyArray Texts(IReadOnlyList<string> texts) => new(texts.Select(text => (RubyValue)text));

    /// <summary>
    /// Writes a share in whole parts, see <see cref="GaugeParts"/>.
    /// </summary>
    /// <param name="share">The share, 0 to 1.</param>
    /// <returns>The parts.</returns>
    private static long Parts(double share) => (long)System.Math.Round(share * GaugeParts, System.MidpointRounding.AwayFromZero);

    /// <summary>
    /// Answers <see cref="Rows"/>.
    /// </summary>
    /// <param name="feed">The lists as last built.</param>
    /// <param name="frame">The frame asked on.</param>
    /// <param name="request">The request.</param>
    /// <param name="build">Builds the lists for the player's name.</param>
    /// <returns>The lists, nil while the scripts hold them.</returns>
    private static RubyHash? RowsOf(OverviewFeed feed, long frame, RubyHash request, System.Func<string, OverviewRowSet> build)
    {
        string name = request["name"].AsText();
        (long serial, OverviewRowSet rows) = feed.Take(frame, () => build(name));
        RubyValue held = request["serial"];
        if (!held.IsNil && held.AsLong() == serial)
        {
            return null;
        }

        return new RubyHash
        {
            { "serial", serial },
            { "players", new RubyArray(rows.Players.Select(RowValue)) },
            { "lines", new RubyArray(rows.Lines.Select(line => LineValue(line, rows.Players))) },
            { "party", new RubyArray(rows.Party.Select(RowValue)) },
            { "raid_party", new RubyArray(rows.RaidParty.Select(RowValue)) },
            { "map", new RubyArray(rows.Map.Select(RowValue)) },
        };
    }

    /// <summary>
    /// Describes a player's row for the scripts.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>[seat (-1 for the player), name, place, level, story, ping, scene, member, badge ([text, leads], nil for none)].</returns>
    private static RubyValue RowValue(OverviewRow row) => new RubyArray
    {
        row.Seat, row.Name, row.Place, row.Level, row.Story, row.Ping, row.Scene, row.Member,
        row.Badge is { } badge ? new RubyArray { badge.Text, badge.Leads } : RubyNil.Value,
    };

    /// <summary>
    /// Describes a line of the Players page for the scripts.
    /// </summary>
    /// <param name="line">The line.</param>
    /// <param name="players">The players the line's player is one of.</param>
    /// <returns>["place", heading] or ["player", the player's place among the players].</returns>
    private static RubyValue LineValue(OverviewLine line, IReadOnlyList<OverviewRow> players) =>
        line.Row is { } row ? new RubyArray { "player", IndexOf(players, row) } : new RubyArray { "place", line.Place };

    /// <summary>
    /// Finds a row's place among the players.
    /// </summary>
    /// <param name="players">The players.</param>
    /// <param name="row">The row.</param>
    /// <returns>Its index.</returns>
    private static long IndexOf(IReadOnlyList<OverviewRow> players, OverviewRow row)
    {
        for (int index = 0; index < players.Count; index++)
        {
            if (ReferenceEquals(players[index], row))
            {
                return index;
            }
        }

        return -1;
    }

    /// <summary>
    /// Answers <see cref="Tell"/>.
    /// </summary>
    /// <param name="state">What the player tells the others.</param>
    /// <param name="request">The request.</param>
    /// <returns>The log's line, nil while nothing changed.</returns>
    private static RubyValue TellOf(OverviewState state, RubyHash request)
    {
        RubyValue front = request["flv"];
        string story = StoryOf(request["story"].AsHash()).AsText();
        return state.Take(new OverviewReading(request["lv"].AsInt(), front.IsNil ? null : front.AsInt(), story, request["battle"] is RubyBool { Flag: true }));
    }

    /// <summary>
    /// Describes the fields the overview adds to the player's state.
    /// </summary>
    /// <param name="fields">The fields.</param>
    /// <returns><c>place</c>, <c>lv</c>, <c>progress</c> and in a Raid World <c>flv</c>.</returns>
    private static RubyHash FieldsOf(OverviewFields fields)
    {
        var hash = new RubyHash { { "place", fields.Place }, { "lv", fields.Level }, { "progress", fields.Progress } };
        if (fields.Front is { } front)
        {
            hash.Add("flv", front);
        }

        return hash;
    }

    /// <summary>
    /// Finds a player's place in the story from what the game read: <c>p</c> (variable 1001),
    /// <c>routes</c> ({route name => its variable}, of <see cref="OverviewText.Routes"/>) and <c>sides</c>
    /// ({side name => whether it was chosen}, of <see cref="OverviewText.Sides"/>).
    /// </summary>
    /// <param name="request">The story as the game read it.</param>
    /// <returns>The code, such as "2:alice".</returns>
    private static RubyValue StoryOf(RubyHash request)
    {
        var routes = new Dictionary<string, long>();
        foreach (var (name, value) in request["routes"].AsHash())
        {
            routes[name.AsText()] = value.AsLong();
        }

        var sides = new Dictionary<string, bool>();
        foreach (var (name, value) in request["sides"].AsHash())
        {
            sides[name.AsText()] = value.AsBool();
        }

        return OverviewText.StoryCode(request["p"].AsLong(), routes, sides);
    }

    /// <summary>
    /// Answers <see cref="Title"/>.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The title's tail and the World page's note.</returns>
    private static RubyHash TitleOf(RubyHash request)
    {
        bool raid = request["raid"].AsBool();
        RubyValue value = request["difficulty"];
        string? name = !value.IsNil && value.AsInt() is var difficulty && WorldDifficulty.IsValid(difficulty) ? WorldDifficulty.Names[difficulty - WorldDifficulty.Min] : null;
        return new RubyHash { { "tail", OverviewText.TitleTail(raid, name) }, { "note", OverviewText.Note(raid, name) } };
    }

    /// <summary>
    /// The live values a quest walk reads: the switches and variables a request hands over, and the
    /// party's characters and items.
    /// </summary>
    /// <param name="values">The switches and variables, which note what they lack.</param>
    /// <param name="party">The party's characters.</param>
    /// <param name="items">The items the party holds.</param>
    private sealed class RequestQuestState(EventTopics.RequestState values, HashSet<long> party, HashSet<long> items) : IQuestState
    {
        /// <inheritdoc />
        public bool Switch(long id) => values.Switch(id);

        /// <inheritdoc />
        public long? Variable(long id) => values.Variable(id);

        /// <inheritdoc />
        public bool InParty(long actor) => party.Contains(actor);

        /// <inheritdoc />
        public bool Holds(long item) => items.Contains(item);
    }
}
