//----------------------------------------------------------------
//  StoryTopics.Replay.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Never asked the player the answers of a run that gave or used up a found item, which reaches every player
//      Paulinchen  2026-11-05: Took and handed the keys, values, sites and things a replay reads as plain values, see StoryPlain
//                            - Digested what the player holds from the things the scripts hand over
//                            - Never handed over the Medal King's run, whose gift is its one path
//                            - Handed over every run that gave or used up a found item, a personal talk too, but a Makina in a Raid World, which comes by level
//                            - Played a chest the way its own letter shut it and never asked the player a derived entry's answers
//                            - Handed over the found items of a battle's drops as the found items of a run, and gave them to each receiver
//      Paulinchen  2026-11-01: Found the choices of a replay in the events database by their places among the kept commands of the player's lists
//                            - Never handed over nor replayed a run where the player takes a side along
//      Paulinchen  2026-10-31: Read a Classic party's scopes from the reviewed list alone
//                            - Answered a derived entry's choices by the branch that ends with the source's letters
//                            - Handed every run that changed a shared key and gives to its stream, deciding what gives from the events database
//                            - Left out of a replay the answers of the choices that are the receiver's
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Security.Cryptography;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Data.Events;
using MGQOnline.Game.Catchup;
using MGQOnline.Game.Story;

namespace MGQParadox.Multiplayer;

/// <summary>
/// The bridge topics of runs handed over by replay ("Issue 73 chest effects.md", "General model"):
/// who keeps each key, the entry a run makes, whether and how a receiver's game plays a run handed
/// to it, the one notice of a replay, and the save's log, which the scripts keep in the save.
/// </summary>
internal sealed partial class StoryTopics
{
    /// <summary>
    /// The topic that hands the scopes the scripts look each key up in, see <see cref="ScopesOf"/>:
    /// {"party" (whether the world is a Classic world, where a chest's keys are a party's)}; nil
    /// before the list came.
    /// </summary>
    public const string ReplayScopesTopic = "story.replay_scopes";

    /// <summary>
    /// The topic that writes an entry for a message to another game: entry; answers the text, see
    /// <see cref="ReplayWire.Write"/>.
    /// </summary>
    public const string ReplayWireTopic = "story.replay_wire";

    /// <summary>
    /// The topic that reads an entry another game wrote: text; answers the entry, without an opener.
    /// </summary>
    public const string ReplayUnwireTopic = "story.replay_unwire";

    /// <summary>
    /// The topic that makes the entry of a page the player's own history or a feature names, see
    /// <see cref="ReplayEntry.Derive"/>: {"site" (or "chest", the key of a chest whose closing page
    /// is meant), "closes" ([key, ...]), "party", "letters" (the letters of the event the source
    /// holds on, which answer its choices, see <see cref="DerivedAnswers"/>; nil for none)}, the keys
    /// as <see cref="StoryPlain"/> names them; answers
    /// the entry, nil before the list came or without an events database for a chest.
    /// </summary>
    public const string ReplayDeriveTopic = "story.replay_derive";

    /// <summary>
    /// The topic that hands a Classic member behind the leader the party chests that gave the leader a
    /// key item they lack, see <see cref="PartyRewards.KeyItemChests"/>: {"items" ([id, ...]),
    /// "opened" ([[map, event, letter], ...] of the leader's story)}; answers {"entries" (each an
    /// entry of the member's history), "items" (the key items they bring)}, nil before the list came
    /// or without an events database.
    /// </summary>
    public const string ReplayKeyChestsTopic = "story.replay_key_chests";

    /// <summary>
    /// The topic of the one-time repair of a save the 0.6.9.2 chest path left stuck: {"world" (whether
    /// a world is open), "raid", "values" (the rows of the things asked for, see <see cref="StoryPlain"/>)}; answers {"needs"=>[[kind, key], ...]},
    /// {"switches"=>[id, ...]} to turn on, or {"unknown"=>true} before a world's list came or without
    /// an events database.
    /// </summary>
    public const string RepairTopic = "story.repair";

    /// <summary>
    /// The topic that names the keys whose start values a run carries, the world and work keys any
    /// page of its event can read: {"site", "party"}; answers [[kind, key], ...], nil before the list came
    /// or without an events database.
    /// </summary>
    public const string ReplayReadsTopic = "story.replay_reads";

    /// <summary>
    /// The topic that takes a run of the player's own game ending: {"site" (see <see cref="StoryPlain"/>), "party", "stream" (its
    /// story's: the Raid World's track, "world" or the player's own "t&lt;n&gt;", or the Classic
    /// leader's "story:&lt;id&gt;"; nil for none), "party_stream" (its Classic party's, nil for none),
    /// "owner" (whether the player owns their story's stream, as a Classic leader does, so its entry
    /// is in it at once),
    /// "changed" ([kind, key, before, after] each, see <see cref="StoryPlain"/>), "found" ([[item, change], ...] of the found items, key items
    /// and items unlocking a job or a race, it gave or used up; nil for none), "start" (rows), "place" ([markers]), "inputs" ([[at, occurrence, kind, value], ...]), "opener" (the
    /// player's name)}. Logs its step and
    /// answers its entry to hand over (see <see cref="ReplayEntry.Write"/>), nil when it hands
    /// nothing over, or {"unknown"=>true} before the list came.
    /// </summary>
    public const string ReplayRanTopic = "story.replay_ran";

    /// <summary>
    /// The topic that takes the drops of a battle the player won: {"party", "stream", "party_stream"
    /// (as <see cref="ReplayRanTopic"/> names them), "found" ([[item, change], ...] of the found items
    /// the drops gave), "opener"}. Answers the entry that hands them to every player like a found
    /// item's run (user decision 2026-11-05), nil when it hands nothing over.
    /// </summary>
    public const string ReplayDropTopic = "story.replay_drop";

    /// <summary>
    /// The topic that keeps a run handed to the player in the save's log until it is taken: entry.
    /// </summary>
    public const string ReplayQueueTopic = "story.replay_queue";

    /// <summary>
    /// The topic that takes a run handed to the player: {"entry", "values" (the rows of the player's
    /// own things asked for: keys, items, companions and holdings, see <see cref="StoryPlain"/>),
    /// "shapes" ([site, the
    /// <see cref="MGQOnline.Data.Events.ListShape"/>] of the player's list of each choice the entry's
    /// inputs name)}. Answers {"do"=>"done"},
    /// {"needs"=>[[kind, key], ...]}, {"do"=>"pending", "why"}, {"do"=>"replay", "page" (from 1, nil for
    /// a common event), "sibling", "inputs" (the entry's, less the answers of the choices that are
    /// the receiver's, whom the replay asks them)}, {"do"=>"gain", "items" ([[item, count], ...] of
    /// another player's battle drops)} or {"unknown"=>true} without an events database
    /// or, for a run with a choice, before the scopes were read.
    /// </summary>
    public const string ReplayTakeTopic = "story.replay_take";

    /// <summary>
    /// The topic that takes a replay ending: {"entry", "reached" (whether it reached the step's
    /// writes), "before" (the rows of the value the replay found of each key of the step), "reads" (the
    /// rows of the player's own things it read), "had" and "has" (what the player held before
    /// and after: [[key, amount, name, sum], ...])}. Answers {"notice"} (nil for none).
    /// </summary>
    public const string ReplayDoneTopic = "story.replay_done";

    /// <summary>
    /// The topic that takes the waiting runs one of whose reads changed: {"values" (rows)}.
    /// Answers [entry, ...] to take again first, or {"needs"=>[[kind, key], ...]}.
    /// </summary>
    public const string ReplayDueTopic = "story.replay_due";

    /// <summary>
    /// The topic that takes the resets of a run of the player's game: [[kind, from, to, value], ...],
    /// the kind and value as <see cref="StoryPlain"/> names them, a self switch reset by its maps.
    /// </summary>
    public const string ReplayResetTopic = "story.replay_reset";

    /// <summary>
    /// The topic that takes the log of the save loaded: {"log" (as <see cref="ReplayLogSaveTopic"/>
    /// answered it, nil for a save without one or for no save), "place" ([markers] of the save, its
    /// start place when it has no log)}. Answers the runs that wait to be taken, [entry, ...].
    /// </summary>
    public const string ReplayLogTopic = "story.replay_log";

    /// <summary>
    /// The topic that answers the log for the save, see <see cref="RunLog.Write"/>.
    /// </summary>
    public const string ReplayLogSaveTopic = "story.replay_log_save";

    /// <summary>
    /// The kind of an input that answers a choice.
    /// </summary>
    private const string ChoiceInput = "choice";

    /// <summary>
    /// The letters an entry's id is made of.
    /// </summary>
    private const string EntryLetters = "abcdefghijklmnopqrstuvwxyz0123456789";

    /// <summary>
    /// The save's log.
    /// </summary>
    private RunLog _log = RunLog.Begin(null);

    /// <summary>
    /// The scopes read last, with the list and world type they were read for.
    /// </summary>
    private (StoryTable List, bool Party, KeyScopes Scopes)? _scopes;

    /// <summary>
    /// Gets or sets how a new entry's id is made; tests hand out their own.
    /// </summary>
    internal Func<string> NewEntryId { get; set; } = () => RandomNumberGenerator.GetString(EntryLetters, 16);

    /// <summary>
    /// Registers the topics of runs handed over by replay.
    /// </summary>
    /// <param name="context">The context.</param>
    /// <param name="topics">The story's topics.</param>
    private static void RegisterReplay(BridgeContext context, StoryTopics topics)
    {
        context.Register(ReplayScopesTopic, (_, request) => topics.ScopesOf(request.AsHash()["party"] is RubyBool { Flag: true }) is { } scopes ? ScopeTableOf(scopes.Table()) : null);
        context.Register(ReplayReadsTopic, (_, request) => topics.ReplayReads(request.AsHash()));
        context.Register(ReplayRanTopic, (_, request) => topics.ReplayRan(request.AsHash()));
        context.Register(ReplayDropTopic, (_, request) => topics.ReplayDrop(request.AsHash()));
        context.Register(ReplayQueueTopic, (_, request) =>
        {
            topics._log.Queue(ReplayEntry.Read(request));
            return null;
        });
        context.Register(ReplayTakeTopic, (_, request) => topics.ReplayTake(request.AsHash()));
        context.Register(ReplayDoneTopic, (_, request) => topics.ReplayDone(request.AsHash()));
        context.Register(ReplayDueTopic, (_, request) => topics.ReplayDue(request.AsHash()));
        context.Register(ReplayResetTopic, (_, request) =>
        {
            foreach (RubyValue reset in request.AsArray())
            {
                if (ResetOf(reset.AsArray()) is { } read)
                {
                    topics._log.Reset(read);
                }
            }

            return null;
        });
        context.Register(ReplayLogTopic, (_, request) => topics.LoadLog(request.AsHash()));
        context.Register(ReplayLogSaveTopic, (_, _) => topics._log.Write());
        context.Register(ReplayWireTopic, (_, request) => ReplayWire.Write(ReplayEntry.Read(request)));
        context.Register(ReplayUnwireTopic, (_, request) => ReplayWire.Read(request.AsText()).Write());
        context.Register(ReplayDeriveTopic, (_, request) => topics.ReplayDerive(request.AsHash()));
        context.Register(ReplayKeyChestsTopic, (_, request) => topics.ReplayKeyChests(request.AsHash()));
        context.Register(RepairTopic, (_, request) => topics.Repair(request.AsHash()));
    }

    /// <summary>
    /// Answers <see cref="RepairTopic"/> by <see cref="SaveRepair"/>, over the events database's pairs:
    /// in a world the player's own keys alone, by who keeps each key.
    /// </summary>
    /// <param name="request">{"world", "raid", "values"}.</param>
    /// <returns>The answer.</returns>
    private RubyHash Repair(RubyHash request)
    {
        EventStore store = Events().Store;
        Func<StoryKey, bool> own = _ => true;
        if (request["world"] is RubyBool { Flag: true })
        {
            if (ScopesOf(request["raid"] is not RubyBool { Flag: true }) is not { } scopes)
            {
                return new RubyHash { { "unknown", true } };
            }

            own = key => scopes.ScopeOf(key) is StoryScope.Player or StoryScope.Party;
        }

        if (!store.IsUsable)
        {
            return new RubyHash { { "unknown", true } };
        }

        IReadOnlyList<RepairPairRow> pairs = store.RepairPairs();
        Dictionary<string, string> values = StoryPlain.ThingTextsOf(request["values"]);
        string[] lacking = [.. SaveRepair.Keys(pairs, own).Select(key => key.ToString()).Where(name => !values.ContainsKey(name))];
        if (lacking.Length > 0)
        {
            return NeedsOf(lacking);
        }

        IReadOnlyList<int> switches = SaveRepair.Switches(pairs, own, key => values.GetValueOrDefault(key.ToString()) == StoryPlain.OnText);
        Log.Write($"repair: {pairs.Count} pairs read, {(switches.Count == 0 ? "the save holds none shut without its switch" : $"the save gets the switches {string.Join(", ", switches)}")}");
        return new RubyHash { { "switches", new RubyArray(switches.Select(id => (RubyValue)id)) } };
    }

    /// <summary>
    /// Answers <see cref="ReplayKeyChestsTopic"/>.
    /// </summary>
    /// <param name="request">{"items", "opened"}.</param>
    /// <returns>{"entries", "items"}, nil when they cannot be named yet.</returns>
    private RubyValue ReplayKeyChests(RubyHash request)
    {
        EventStore store = Events().Store;
        if (ScopesOf(true) is not { } scopes || !store.IsUsable)
        {
            return RubyNil.Value;
        }

        int[] items = [.. request["items"].AsArray().Select(item => item.AsInt())];
        StoryKey[] opened = [.. request["opened"].AsArray().Select(key => key.AsArray() is { Count: 3 } fields
            ? StoryKey.SelfSwitch(fields[0].AsInt(), fields[1].AsInt(), fields[2].AsText())
            : throw new BridgeRequestException("An opened chest is [map, event, letter]."))];
        var entries = new RubyArray();
        var brought = new SortedSet<int>();
        foreach (KeyItemChest chest in PartyRewards.KeyItemChests(store, opened, items))
        {
            entries.Add(ChestEntry(store, chest.Site, [chest.Key], [chest.Key.Letter], scopes).Write());
            brought.UnionWith(chest.Items);
            Log.Write($"replay: the leader's chest {chest.Site} gave the key items {string.Join(", ", chest.Items)}, which the member's game plays");
        }

        return new RubyHash { { "entries", entries }, { "items", new RubyArray(brought.Select(id => (RubyValue)id)) } };
    }

    /// <summary>
    /// Answers <see cref="ReplayDeriveTopic"/>.
    /// </summary>
    /// <param name="request">{"site" or "chest", "closes" (the keys that close it; for a chest its
    /// key, for a site the self switches its page turns on, when missing), "party"}, each key as
    /// [kind, key].</param>
    /// <returns>The entry, nil when it cannot be made yet.</returns>
    private RubyValue ReplayDerive(RubyHash request)
    {
        EventStore store = Events().Store;
        if (ScopesOf(request["party"] is RubyBool { Flag: true }) is not { } scopes || !store.IsUsable)
        {
            return RubyNil.Value;
        }

        var match = new PageMatch(store);
        StoryKey? chest = request["chest"].IsNil ? null : StoryPlain.KeyOf(request["chest"]);
        ReplaySite? site = chest is { } named ? match.ChestPage(named) : ReplaySite.Of(request["site"]);
        if (site is not { } found)
        {
            Log.Write($"replay: no page closes the chest {chest}, so it is not played");
            return RubyNil.Value;
        }

        StoryKey[] closes = !request["closes"].IsNil
            ? [.. request["closes"].AsArray().Select(key => StoryPlain.KeyOf(key))]
            : chest is { } own ? [own] : [.. match.ClosingKeys(found)];
        string[] letters = !request["letters"].IsNil ? [.. request["letters"].AsArray().Select(letter => letter.AsText())] : chest is { } shut ? [shut.Letter] : [];
        ReplayEntry entry = ChestEntry(store, found, closes, letters, scopes);
        Log.Write($"replay: derived entry {entry.Id}, closed by {string.Join(", ", closes)}");
        return entry.Write();
    }

    /// <summary>
    /// Makes the entry of a page the player's history or a feature names, its choices answered by the
    /// branch that ends with the letters the source holds on, a chest's own letter for a chest, so
    /// the page plays the way that shut it.
    /// </summary>
    /// <param name="store">The events database.</param>
    /// <param name="site">The page.</param>
    /// <param name="closes">The keys that close it.</param>
    /// <param name="letters">The letters of the page's event the source holds on; none answers no choice.</param>
    /// <param name="scopes">The scopes of the keys.</param>
    /// <returns>The entry.</returns>
    private static ReplayEntry ChestEntry(EventStore store, ReplaySite site, IReadOnlyCollection<StoryKey> closes, IReadOnlyCollection<string> letters, KeyScopes scopes)
    {
        ReplayEntry entry = ReplayEntry.Derive(site, closes, key => KeyScopes.InView(scopes.ScopeOf(key, site.ToString())));
        return letters.Count == 0 ? entry : entry with { Inputs = DerivedAnswers.Of(store, site, letters) };
    }

    /// <summary>
    /// Writes scopes as the scripts look keys up in them.
    /// </summary>
    /// <param name="table">The scopes.</param>
    /// <returns>{"switches" and "variables" (a scope byte per id, binary), "keys" ([map, event, letter, scope] of each self switch named), "self" and "common" (the self switch rules' rows with their scope, see <see cref="StoryPlain.SelfRules"/>), "index" (each event as map * 1,000,000 + event), "self_default"}.</returns>
    private static RubyHash ScopeTableOf(ScopeTable table)
    {
        var keys = new RubyArray();
        foreach ((StoryKey key, StoryScope scope) in table.Keys.OrderBy(pair => pair.Key.ToString(), StringComparer.Ordinal))
        {
            keys.Add(new RubyArray { key.Id, key.Event, key.Letter, (long)scope });
        }

        RubyHash rules = StoryPlain.SelfRules(table.SelfRules, scope => (long)scope);
        return new RubyHash
        {
            { "switches", RubyString.Binary(table.Switches) },
            { "variables", RubyString.Binary(table.Variables) },
            { "keys", keys },
            { "self", rules["self"] },
            { "common", rules["common"] },
            { "index", new RubyArray(table.Index.Order().Select(code => (RubyValue)code)) },
            { "self_default", (long)table.SelfDefault },
        };
    }

    /// <summary>
    /// Reads a reset.
    /// </summary>
    /// <param name="reset">[kind, from, to, value], see <see cref="StoryPlain"/>.</param>
    /// <returns>The reset, <see langword="null"/> for one to a value no story carries.</returns>
    /// <exception cref="BridgeRequestException">The reset is no such four.</exception>
    private static RunReset? ResetOf(RubyArray reset)
    {
        StoryKeyKind? kind = reset.Count == 4 && reset[0] is RubyInteger ? reset[0].AsInt() switch
        {
            StoryPlain.SwitchKind => StoryKeyKind.Switch,
            StoryPlain.VariableKind => StoryKeyKind.Variable,
            StoryPlain.SelfSwitchKind => StoryKeyKind.SelfSwitch,
            _ => null,
        } : null;
        if (kind is not { } found)
        {
            throw new BridgeRequestException("A reset is [kind, from, to, value], its kind 0, 1 or 2.");
        }

        string? value = StoryPlain.TextOf(new StoryKey(found, 0), reset[3]);
        return value is null ? null : new RunReset(found, reset[1].AsInt(), reset[2].AsInt(), value);
    }

    /// <summary>
    /// Reads the scopes of the list held for a world type.
    /// </summary>
    /// <param name="party">Whether the player is in a Classic party.</param>
    /// <returns>The scopes, <see langword="null"/> before the list came.</returns>
    private KeyScopes? ScopesOf(bool party)
    {
        if (_table is not { } list)
        {
            return null;
        }

        if (_scopes is { } held && ReferenceEquals(held.List, list) && held.Party == party)
        {
            return held.Scopes;
        }

        KeyScopes scopes = party ? KeyScopes.Classic(list) : KeyScopes.Raid(list);
        _scopes = (list, party, scopes);
        return scopes;
    }

    /// <summary>
    /// Answers <see cref="ReplayReadsTopic"/>.
    /// </summary>
    /// <param name="request">{"site", "party"}.</param>
    /// <returns>The keys in the order of their names, nil before the list came or without an events database.</returns>
    private RubyValue ReplayReads(RubyHash request)
    {
        ReplaySite site = ReplaySite.Of(request["site"]);
        EventStore store = Events().Store;
        if (ScopesOf(request["party"] is RubyBool { Flag: true }) is not { } scopes || !store.IsUsable)
        {
            return RubyNil.Value;
        }

        string at = site.ToString();
        IEnumerable<StoryKey> keys = new PageMatch(store).ReadKeys(site, key => KeyScopes.InView(scopes.ScopeOf(key, at)));
        return new RubyArray(keys.OrderBy(key => key.ToString(), StringComparer.Ordinal).Select(key => (RubyValue)StoryPlain.Plain(key)));
    }

    /// <summary>
    /// Answers <see cref="ReplayRanTopic"/>: logs the step of the party and world keys the run
    /// changed, and makes its entry when it gives (rule 1), with every one of those keys as its step:
    /// into its story's stream when it changed a world key, else into its party's. A run that changed
    /// a party key wrote a key a player keeps, so it gives; any other gives when its page does. A run
    /// that gave or used up a found item is handed over too, one that changed no shared key into a
    /// Raid World's story or a Classic party's stream (user decision 2026-11-04). The entry is in a
    /// party's stream at once, and in a story's when the player owns it.
    /// </summary>
    /// <param name="request">The run.</param>
    /// <returns>The entry, nil, or {"unknown"=>true}.</returns>
    private RubyValue ReplayRan(RubyHash request)
    {
        ReplaySite site = ReplaySite.Of(request["site"]);
        if (ScopesOf(request["party"] is RubyBool { Flag: true }) is not { } scopes)
        {
            Log.Write($"replay: the run of {site} is not logged, the story key list has not come yet");
            return new RubyHash { { "unknown", true } };
        }

        string at = site.ToString();
        var keys = new Dictionary<StoryKey, string>();
        var party = new Dictionary<StoryKey, string>();
        foreach ((StoryKey key, string before, string after) in ChangesOf(request["changed"]))
        {
            StoryScope scope = scopes.ScopeOf(key, at);
            if (before != after && KeyScopes.HandsOver(scope))
            {
                keys[key] = before;
                if (scope == StoryScope.Party)
                {
                    party[key] = before;
                }
            }
        }

        bool classic = request["party"] is RubyBool { Flag: true };
        int[] found = [.. FoundOf(request["found"], classic)];
        if (keys.Count == 0 && found.Length == 0)
        {
            return RubyNil.Value;
        }

        bool world = keys.Count > party.Count || (keys.Count == 0 && !classic);
        RubyValue streamOf = world ? request["stream"] : request["party_stream"];
        string? stream = streamOf.IsNil ? null : streamOf.AsText();
        bool pick = IsPickSite(site);
        bool medalKing = IsMedalKing(site);
        bool sent = stream is not null && !pick && !medalKing && (party.Count > 0 || found.Length > 0 || PageGives(site, scopes));
        bool kept = sent && (!world || request["owner"] is RubyBool { Flag: true });
        string id = NewEntryId();
        _log.Ran(site, keys, kept ? stream : null, kept ? id : null);
        if (!sent)
        {
            Log.Write($"replay: logged the run of {site}, which changed {keys.Count} shared keys and hands nothing over{(pick ? ": every player takes their own side along" : medalKing ? ": the Medal King's gift reaches every player by its own rule" : string.Empty)}");
            return RubyNil.Value;
        }

        var entry = new ReplayEntry(id, site, stream!, world ? StoryScope.World : StoryScope.Party, request["opener"].IsNil ? null : request["opener"].AsText(),
            keys, ReplayEntry.PlaceOf(request["place"]), ReplayEntry.KeysOf(request["start"]), ReplayEntry.InputsOf(request["inputs"]), false)
        {
            Found = found.Length > 0,
        };
        Log.Write($"replay: the run of {site} goes to {stream} as entry {id}, its step {(keys.Count == 0 ? "none" : string.Join(", ", keys.Keys))}{(found.Length > 0 ? $", the found items {string.Join(", ", found)}" : string.Empty)}");
        return entry.Write();
    }

    /// <summary>
    /// Answers <see cref="ReplayDropTopic"/>: makes the entry of a battle's drops that gave found
    /// items, into a Raid World's story or a Classic party's stream as a found item's run that
    /// changed no shared key goes, and logs the step its own entry claims, so the player who won
    /// them never takes them twice.
    /// </summary>
    /// <param name="request">The drops.</param>
    /// <returns>The entry, nil when it hands nothing over.</returns>
    private RubyValue ReplayDrop(RubyHash request)
    {
        bool classic = request["party"] is RubyBool { Flag: true };
        KeyValuePair<int, int>[] drops = [.. FoundChanges(request["found"], classic).Where(drop => drop.Value > 0)];
        RubyValue streamOf = classic ? request["party_stream"] : request["stream"];
        if (drops.Length == 0 || streamOf.IsNil)
        {
            Log.Write($"replay: a battle's drops hand nothing over, {(drops.Length == 0 ? "they gave no found item another player gets" : "the player plays no story with others")}");
            return RubyNil.Value;
        }

        string stream = streamOf.AsText();
        string id = NewEntryId();
        _log.Ran(ReplaySite.Drop, new Dictionary<StoryKey, string>(), stream, id);
        var entry = new ReplayEntry(id, ReplaySite.Drop, stream, classic ? StoryScope.Party : StoryScope.World, request["opener"].IsNil ? null : request["opener"].AsText(),
            new Dictionary<StoryKey, string>(), null, new Dictionary<StoryKey, string>(), [], false)
        {
            Found = true,
            Drops = drops,
        };
        Log.Write($"replay: a battle's drops go to {stream} as entry {id}, the found items {string.Join(", ", drops.Select(drop => $"{drop.Key} x{drop.Value}"))}");
        return entry.Write();
    }

    /// <summary>
    /// Reads the found items a run gave or used up, but a Raid World's Makina, which every player
    /// gets by level instead (Makina by level, answer 9).
    /// </summary>
    /// <param name="value">[[item, change], ...], nil for none.</param>
    /// <param name="classic">Whether the world is a Classic world.</param>
    /// <returns>The items, each once.</returns>
    private IEnumerable<int> FoundOf(RubyValue value, bool classic) => FoundChanges(value, classic).Select(change => change.Key).Distinct();

    /// <summary>
    /// Reads the changes of found items a run or a battle's drops made, but a Raid World's Makina's.
    /// </summary>
    /// <param name="value">[[item, change], ...], nil for none.</param>
    /// <param name="classic">Whether the world is a Classic world.</param>
    /// <returns>Each item with its change, those that changed nothing left out, in their order.</returns>
    private IEnumerable<KeyValuePair<int, int>> FoundChanges(RubyValue value, bool classic)
    {
        if (value.IsNil)
        {
            return [];
        }

        HashSet<int> makina = classic ? [] : [.. Catchup?.Makina.Select(row => row.Item) ?? []];
        return value.AsArray().Select(pair => pair.AsArray()).Where(pair => pair.Count == 2 && pair[1].AsLong() != 0)
            .Select(pair => new KeyValuePair<int, int>(pair[0].AsInt(), pair[1].AsInt())).Where(change => !makina.Contains(change.Key));
    }

    /// <summary>
    /// Tells whether a key of a scope is a receiver's own: a player's or a party's, which a run gives
    /// when it writes one and a choice is asked by.
    /// </summary>
    /// <param name="scope">The scope.</param>
    /// <returns>Whether it is.</returns>
    private static bool IsOwn(StoryScope scope) => scope is StoryScope.Player or StoryScope.Party;

    /// <summary>
    /// Tells whether a page is where the player takes the Alice or Ilias side along, whose side
    /// comes only from the player's own pick or the question of the side they lost.
    /// </summary>
    /// <param name="site">The page.</param>
    /// <returns>Whether it is; false before the story mapping came.</returns>
    private bool IsPickSite(ReplaySite site) => Catchup?.Scope.IsPickSite(site.ToString()) == true;

    /// <summary>
    /// Tells whether a run is the Medal King's, see <see cref="MedalKingGift"/>.
    /// </summary>
    /// <param name="site">Where the run started.</param>
    /// <returns>Whether it is; false without an events database.</returns>
    private bool IsMedalKing(ReplaySite site) => Events().Store is { IsUsable: true } store && MedalKingGift.IsRun(site, new PageMatch(store));

    /// <summary>
    /// Tells whether a run's page gives, by the events database and who keeps each key.
    /// </summary>
    /// <param name="site">Where the run started.</param>
    /// <param name="scopes">Who keeps each key.</param>
    /// <returns>Whether it gives; false without an events database.</returns>
    private bool PageGives(ReplaySite site, KeyScopes scopes)
    {
        EventStore store = Events().Store;
        if (!store.IsUsable)
        {
            Log.Write($"replay: the run of {site} is taken for one that gives nothing, there is no events database: {store.Problem}");
            return false;
        }

        string at = site.ToString();
        return new PageMatch(store).Gives(site, key => IsOwn(scopes.ScopeOf(key, at)));
    }

    /// <summary>
    /// Answers <see cref="ReplayTakeTopic"/>, and drops a run it decides from the queue.
    /// </summary>
    /// <param name="request">{"entry", "values", "shapes"}.</param>
    /// <returns>The answer.</returns>
    private RubyHash ReplayTake(RubyHash request)
    {
        ReplayEntry entry = ReplayEntry.Read(request["entry"]);
        RubyHash answer = Decide(entry, StoryPlain.ThingTextsOf(request["values"]), ShapesOf(request["shapes"]));
        if (answer.ContainsKey("do"))
        {
            _log.Taken(entry);
        }

        return answer;
    }

    /// <summary>
    /// Decides a run handed to the player by rule 2: done when the log claims it, still waiting while
    /// it waits, else the page the player's game shows decides whether it is replayed or waits.
    /// </summary>
    /// <param name="entry">The run's entry.</param>
    /// <param name="values">The player's own values the request holds, by name as the save's log keeps them.</param>
    /// <param name="shapes">The shapes of the player's lists of the choices the entry's inputs name, by site.</param>
    /// <returns>The answer.</returns>
    private RubyHash Decide(ReplayEntry entry, IReadOnlyDictionary<string, string> values, IReadOnlyDictionary<string, int> shapes)
    {
        if (_log.Claims(entry))
        {
            Log.Write($"replay: entry {entry.Id} of {entry.Site} in {entry.Stream} is done already");
            return new RubyHash { { "do", "done" } };
        }

        if (IsPickSite(entry.Site))
        {
            Log.Write($"replay: entry {entry.Id} of {entry.Site} is never replayed, every player takes their own side along");
            return new RubyHash { { "do", "done" } };
        }

        if (_log.Pending.Any(run => run.Entry.Id == entry.Id))
        {
            return new RubyHash { { "do", "pending" }, { "why", "it waits until one of the player's own things it read changes" } };
        }

        if (entry.Site.IsDrop)
        {
            Log.Write($"replay: entry {entry.Id} gives the player the battle drops {string.Join(", ", entry.Drops.Select(drop => $"{drop.Key} x{drop.Value}"))}");
            return new RubyHash { { "do", "gain" }, { "items", new RubyArray(entry.Drops.Select(drop => (RubyValue)new RubyArray { drop.Key, drop.Value })) } };
        }

        EventStore store = Events().Store;
        if (!store.IsUsable)
        {
            Log.Write($"replay: entry {entry.Id} of {entry.Site} waits, there is no events database: {store.Problem}");
            return new RubyHash { { "unknown", true } };
        }

        var own = new OwnValues(values);
        var match = new PageMatch(store);
        PagePick pick = match.Pick(entry.Site, new ReplayView(entry.Start, own), entry.Keys.Keys);
        if (own.Needs() is { } needs)
        {
            return needs;
        }

        if (pick.Replays)
        {
            if (OpenersInputs(entry, match, shapes) is not { } inputs)
            {
                Log.Write($"replay: entry {entry.Id} of {entry.Site} waits, who keeps each key has not been read yet");
                return new RubyHash { { "unknown", true } };
            }

            Log.Write($"replay: entry {entry.Id} of {entry.Site} replays {(entry.Site.IsCommon ? "its common event" : $"page {pick.PageNo + 1}")}");
            return new RubyHash
            {
                { "do", "replay" }, { "page", entry.Site.IsCommon ? RubyNil.Value : pick.PageNo + 1 }, { "sibling", pick.Result == PickResult.Sibling },
                { "inputs", ReplayEntry.InputsArray(inputs) },
            };
        }

        string why = pick.Result == PickResult.NoPage ? "no page of its event shows" : $"page {pick.PageNo + 1} shows, which writes none of its step";
        _log.Pend(entry, own.Reads);
        Log.Write($"replay: entry {entry.Id} of {entry.Site} waits, {why}");
        return new RubyHash { { "do", "pending" }, { "why", why } };
    }

    /// <summary>
    /// Finds the inputs a replay takes from the opener's record: all but the answers of the choices
    /// that are the receiver's (rule 4, answer 11), whose answers do different things to the
    /// receiver's own things by the scopes read last; all answers of a derived entry and of a run
    /// that gave or used up a found item.
    /// </summary>
    /// <remarks>
    /// A found item reaches every player, so the receiver gets what the opener got the way the opener
    /// answered, as a player caught up past a trade gets its item without being asked (user decision
    /// 2026-11-05).
    /// </remarks>
    /// <param name="entry">The run's entry.</param>
    /// <param name="match">The events database's pages.</param>
    /// <param name="shapes">The shapes of the player's lists of the choices, by site.</param>
    /// <returns>The inputs, <see langword="null"/> while the run holds a choice and no scopes were read.</returns>
    private IReadOnlyList<ReplayInput>? OpenersInputs(ReplayEntry entry, PageMatch match, IReadOnlyDictionary<string, int> shapes)
    {
        string[] choices = [.. entry.Inputs.Where(input => input.Kind == ChoiceInput).Select(input => input.At).Distinct(StringComparer.Ordinal)];
        if (choices.Length == 0 || entry.Derived || entry.Found)
        {
            return entry.Inputs;
        }

        if (_scopes is not { } held)
        {
            return null;
        }

        string site = entry.Site.ToString();
        string[] unknown = [.. choices.Where(at => match.ChoiceOf(at, shapes) is null)];
        if (unknown.Length > 0)
        {
            Log.Write($"replay: entry {entry.Id} of {entry.Site} takes the opener's answers at {string.Join(", ", unknown)}, which the events database holds no choice of as this game shows it");
        }

        HashSet<string> asked = new(choices.Where(at => match.IsReceivers(entry.Site, at, shapes, key => IsOwn(held.Scopes.ScopeOf(key, site)))), StringComparer.Ordinal);
        if (asked.Count > 0)
        {
            Log.Write($"replay: entry {entry.Id} of {entry.Site} asks the player the choices at {string.Join(", ", asked)}, whose answers differ in their own things");
        }

        return [.. entry.Inputs.Where(input => input.Kind != ChoiceInput || !asked.Contains(input.At))];
    }

    /// <summary>
    /// Answers <see cref="ReplayDoneTopic"/>: logs a replay that reached the step's writes and
    /// tells its notice, or keeps one that did not waiting.
    /// </summary>
    /// <param name="request">The replay's end.</param>
    /// <returns>{"notice"}.</returns>
    private RubyHash ReplayDone(RubyHash request)
    {
        ReplayEntry entry = ReplayEntry.Read(request["entry"]);
        if (request["reached"] is not RubyBool { Flag: true })
        {
            _log.Pend(entry, StoryPlain.ThingTextsOf(request["reads"]));
            Log.Write($"replay: entry {entry.Id} of {entry.Site} did not reach its step and waits");
            return new RubyHash { { "notice", RubyNil.Value } };
        }

        Dictionary<StoryKey, string> found = ReplayEntry.KeysOf(request["before"]);
        _log.Replayed(entry, entry.Keys.ToDictionary(pair => pair.Key, pair => found.GetValueOrDefault(pair.Key, pair.Value)));
        string? notice = ReplayNotice.Text(entry, ReplayNotice.Read(request["had"]), ReplayNotice.Read(request["has"]));
        Log.Write($"replay: entry {entry.Id} of {entry.Site} replayed{(notice is null ? string.Empty : $": {notice}")}");
        return new RubyHash { { "notice", notice } };
    }

    /// <summary>
    /// Answers <see cref="ReplayDueTopic"/>.
    /// </summary>
    /// <param name="request">{"values"}.</param>
    /// <returns>The entries to take again, or the values lacking.</returns>
    private RubyValue ReplayDue(RubyHash request)
    {
        Dictionary<string, string> values = StoryPlain.ThingTextsOf(request["values"]);
        string[] lacking = [.. _log.PendingReads().Where(name => !values.ContainsKey(name))];
        if (lacking.Length > 0)
        {
            return NeedsOf(lacking);
        }

        IReadOnlyList<ReplayEntry> due = _log.Due(name => values.GetValueOrDefault(name));
        foreach (ReplayEntry entry in due)
        {
            Log.Write($"replay: entry {entry.Id} of {entry.Site} waited, and what it read changed");
        }

        return new RubyArray(due.Select(entry => (RubyValue)entry.Write()));
    }

    /// <summary>
    /// Answers <see cref="ReplayLogTopic"/>: takes the save's log, or begins one at its place.
    /// </summary>
    /// <param name="request">{"log", "place"}.</param>
    /// <returns>The runs that wait to be taken.</returns>
    private RubyArray LoadLog(RubyHash request)
    {
        RunPlace? place = ReplayEntry.PlaceOf(request["place"]);
        if (request["log"].IsNil)
        {
            _log = RunLog.Begin(place);
            Log.Write($"replay: began the log of a save at its place {(place is null ? "unknown" : string.Join("/", place.Markers))}");
        }
        else
        {
            try
            {
                _log = RunLog.Read(request["log"]);
                Log.Write($"replay: read the log of the save, {_log.Steps.Count} steps, {_log.Pending.Count} runs waiting for the player's own things and {_log.Queued.Count} to take");
            }
            catch (RubyValueException ex)
            {
                _log = RunLog.Begin(place);
                Log.Write($"replay: the log of the save does not read, so it begins anew at its place: {ex.Message}");
            }
        }

        return new RubyArray(_log.Queued.Select(entry => (RubyValue)entry.Write()));
    }

    /// <summary>
    /// Reads the keys a run changed.
    /// </summary>
    /// <param name="value">[kind, key, before, after] each, see <see cref="StoryPlain"/>.</param>
    /// <returns>Each key with its values as the tracks write them, empty for a value no story carries.</returns>
    /// <exception cref="BridgeRequestException">A change is no key with two values.</exception>
    private static IEnumerable<(StoryKey Key, string Before, string After)> ChangesOf(RubyValue value)
    {
        foreach (RubyValue change in value.AsArray())
        {
            RubyArray fields = change is RubyArray { Count: 4 } found ? found : throw new BridgeRequestException("A changed key is [kind, key, before, after].");
            StoryKey key = StoryPlain.KeyOf(fields[0], fields[1]);
            yield return (key, StoryPlain.TextOf(key, fields[2]) ?? string.Empty, StoryPlain.TextOf(key, fields[3]) ?? string.Empty);
        }
    }

    /// <summary>
    /// Answers the things a request lacked.
    /// </summary>
    /// <param name="names">Their names, as the save's log keeps them.</param>
    /// <returns><c>{"needs"=>[[kind, key], ...]}</c>.</returns>
    private static RubyHash NeedsOf(IEnumerable<string> names) => new() { { "needs", new RubyArray(names.Select(name => (RubyValue)StoryPlain.ThingOf(name))) } };

    /// <summary>
    /// Reads the shapes of the player's lists by site.
    /// </summary>
    /// <param name="value">[[site, shape], ...], the site as <see cref="StoryPlain"/> names it; nil for none.</param>
    /// <returns>The shapes by the site's text.</returns>
    private static Dictionary<string, int> ShapesOf(RubyValue value)
    {
        var shapes = new Dictionary<string, int>(StringComparer.Ordinal);
        foreach (RubyValue pair in value.IsNil ? [] : value.AsArray())
        {
            RubyArray fields = pair.AsArray();
            shapes[StoryPlain.SiteText(fields[0])] = fields[1].AsInt();
        }

        return shapes;
    }

    /// <summary>
    /// The player's own values a request holds, noting those read and those it lacks.
    /// </summary>
    /// <param name="values">The values by name, as the save's log keeps them.</param>
    private sealed class OwnValues(IReadOnlyDictionary<string, string> values) : IReplayState
    {
        /// <summary>
        /// The values read that the request lacks.
        /// </summary>
        private readonly SortedSet<string> _missing = new(StringComparer.Ordinal);

        /// <summary>
        /// Gets the values read that the request held.
        /// </summary>
        public Dictionary<string, string> Reads { get; } = new(StringComparer.Ordinal);

        /// <inheritdoc />
        public bool Switch(long id) => Read(string.Create(CultureInfo.InvariantCulture, $"s{id}")) == StoryPlain.OnText;

        /// <inheritdoc />
        public long? Variable(long id) => Read(string.Create(CultureInfo.InvariantCulture, $"v{id}")) is { } value ? ReplayView.WholeOf(value) : 0;

        /// <inheritdoc />
        public bool PersonalSwitch(long id) => false;

        /// <inheritdoc />
        public bool PersonalVariable(long id) => false;

        /// <inheritdoc />
        public bool SelfSwitch(int map, int eventId, string letter) => Read(StoryKey.SelfSwitch(map, eventId, letter).ToString()) == StoryPlain.OnText;

        /// <inheritdoc />
        public bool HasItem(int item) => Read(string.Create(CultureInfo.InvariantCulture, $"{StoryPlain.ItemKind}{item}")) == StoryPlain.OnText;

        /// <inheritdoc />
        public bool InParty(int actor) => Read(string.Create(CultureInfo.InvariantCulture, $"{StoryPlain.ActorKind}{actor}")) == StoryPlain.OnText;

        /// <summary>
        /// Answers the values lacking.
        /// </summary>
        /// <returns>The answer, see <see cref="NeedsOf"/>; <see langword="null"/> when the request held every value read.</returns>
        public RubyHash? Needs() => _missing.Count == 0 ? null : NeedsOf(_missing);

        /// <summary>
        /// Reads a value, noting it.
        /// </summary>
        /// <param name="name">Its name.</param>
        /// <returns>The value, <see langword="null"/> when the request lacks it.</returns>
        private string? Read(string name)
        {
            if (values.TryGetValue(name, out string? value))
            {
                return Reads[name] = value;
            }

            _missing.Add(name);
            return null;
        }
    }
}
