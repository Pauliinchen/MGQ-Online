//----------------------------------------------------------------
//  CatchupLook.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Gave a Classic member following a leader past the Great Decision the rows of the leader's side
//      Paulinchen  2026-11-05: Named the chest a replay plays as [kind, key], and the site of a join, a setting and a replay as plain values
//                            - Ran the catch-up of a Classic party's member as one look in the engine's Classic settings
//                            - Kept every choice's outcome a Classic member's own, so a row behind a choice waits for their answer
//                            - Read a Classic member's side from the save's note alone
//                            - Played the closures of a Classic member's own keys and the party chests that gave the key items they lack
//                            - Asked the one rule of the side the player took along whether to ask them
//                            - Read the story's ids from StoryIds
//                            - Gave a prize from its row only as history before the world's log, but the Medal King's free gift
//                            - Played the orbs' event only as history before the world's log
//                            - Never gave back in the repair an item an event of the game takes away
//                            - Left found key items and their uses to the story replay, and kept the found marks for the Makina alone
//                            - Asked the one companion filter on every path, and held a companion a replay hands out by the world's companion sharing and the join's level
//                            - Let a companion of a replay that went the player's own way join as the player's own, waiting for the join's gate as an own event does
//      Paulinchen  2026-11-01: Handed out found key items too, each once per save, by the rule both world types share
//                            - Named the found items it gave, whose next gain adds nothing
//                            - Took a copy of each key item another player's event used up, once per use and save
//                            - Gave the companions of the Alice and Ilias choice only to the players who took that side along or played a route that gives them
//                            - Took such a companion away from a player who never had a right to them
//                            - Noted the side of the player's own save, and asked only a player who started from another player's starting save
//                            - Took a route's companions away only from a player who plays or played that route
//                            - Noted the routes the player played
//      Paulinchen  2026-10-31: Stopped lifting the warp ban on the maps where warping is free, since a world never bans warping
//                            - Played the recruit page of a companion the player missed once a route finished
//                            - Gave from the rows only the history the world's story was past where its log starts, which the world's track replays after
//                            - Played a world chest and a Makina by level in the player's game instead of handing out their items
//      Paulinchen  2026-10-28: Left the player's own values alone where the latest row lies in free order
//                            - Gave a prize marked by a prize switch as one marked by a prize variable
//                            - Opened a world chest the game shuts by a switch
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Story;
using MGQOnline.Game.Story.Choices;

namespace MGQOnline.Game.Catchup;

/// <summary>
/// One call of the catch-up's engine over one snapshot, as world_catchup.rbx decided it: the working
/// copy of the player's story, roster and items, which the actions it answers change as the game
/// will, so a later decision of the same call reads them as the script read the game.
/// </summary>
/// <remarks>
/// The snapshot carries "world" (the open world's id), "ledger" (the save's notes, once after a
/// load), "mode" ("world", "behind" or nil), "own", "told" and "before" (stories: "s" the switches
/// on, "v" [id, value] each, "ss" the self switches on), "roster" ([id, persona, base level, cap]
/// each), "items" (counts by "i", "w" or "a" and the id), "worn", "unlocks" (the items unlocking a
/// job or race), "pick" (the side the save notes the player took along in
/// Iliasville: "alice" or "ilias", "" for a save of another player's starting save, nil while
/// unknown), "encounters", "summary" (the world's summary),
/// "sharing", "starts" ([companion, start level] each) and "start" (the story markers where the
/// world's log starts, nil while nothing is logged).
/// </remarks>
internal sealed class CatchupLook
{
    /// <summary>
    /// Luka, who never joins nor leaves.
    /// </summary>
    public const int Hero = 1;


    /// <summary>
    /// What the notes keep for a companion the world shares once it joined or never will.
    /// </summary>
    private const string ShareSettled = "settled";

    /// <summary>
    /// The rule of a join whose gate is the companion's start level.
    /// </summary>
    private const string StartRule = "start";

    /// <summary>
    /// The map and letter of the self switches that tell which Makina a player of the world found.
    /// </summary>
    private const int FoundMap = 0;

    /// <summary>
    /// See <see cref="FoundMap"/>.
    /// </summary>
    private const string FoundLetter = "F";

    /// <summary>
    /// Looks between two looks at the skills, classes and races the story gave the roster, five
    /// seconds, as the tables hold thousands of rows.
    /// </summary>
    private const int GrowthChecks = 10;

    /// <summary>
    /// The letters of an event's self switches.
    /// </summary>
    private static readonly string[] Letters = ["A", "B", "C", "D"];

    /// <summary>
    /// The engine, which holds the save's notes.
    /// </summary>
    private readonly CatchupEngine _engine;

    /// <summary>
    /// How the engine runs in the world type.
    /// </summary>
    private readonly CatchupSettings _settings;

    /// <summary>
    /// The tables.
    /// </summary>
    private readonly CatchupTables _tables;

    /// <summary>
    /// The request.
    /// </summary>
    private readonly RubyHash _request;

    /// <summary>
    /// The save's notes as they stood before the call, written as Marshal writes them.
    /// </summary>
    private readonly byte[] _before;

    /// <summary>
    /// The open world's id.
    /// </summary>
    private readonly string _worldId;

    /// <summary>
    /// How the player plays the world's story: "world", "behind" or <see langword="null"/>.
    /// </summary>
    private readonly string? _mode;

    /// <summary>
    /// The player's story, which the actions change: in the Classic settings the leader's story with
    /// the member's own choices and side.
    /// </summary>
    private readonly StoryValues _own;

    /// <summary>
    /// The world's story last written into the player's, in the Classic settings the leader's;
    /// <see langword="null"/> for none.
    /// </summary>
    private readonly StoryValues? _told;

    /// <summary>
    /// The roster: each companion's id, persona, base level and cap.
    /// </summary>
    private readonly List<RosterEntry> _roster;

    /// <summary>
    /// The counts of the items the snapshot names, by "i", "w" or "a" and the id; an item the game
    /// lacks is left out.
    /// </summary>
    private readonly Dictionary<string, long> _items = new(StringComparer.Ordinal);

    /// <summary>
    /// The weapons and armors the party wears.
    /// </summary>
    private readonly HashSet<string> _worn = new(StringComparer.Ordinal);

    /// <summary>
    /// The items that unlock a job or a race.
    /// </summary>
    private readonly HashSet<long> _unlockIds = [];

    /// <summary>
    /// The switches of every choice's outcomes, each player's own in a Raid World.
    /// </summary>
    private readonly HashSet<int> _choiceSwitches = [];

    /// <summary>
    /// The variables of every choice's outcomes, each player's own in a Raid World.
    /// </summary>
    private readonly HashSet<int> _choiceVariables = [];


    /// <summary>
    /// Whether random encounters are on.
    /// </summary>
    private readonly bool _encounters;

    /// <summary>
    /// The world's summary, <see langword="null"/> before the relay told any.
    /// </summary>
    private readonly RubyHash? _summary;

    /// <summary>
    /// How the world shares companions: "off", "story" or "all".
    /// </summary>
    private readonly string _sharing;

    /// <summary>
    /// The start levels of the companions the world shares.
    /// </summary>
    private readonly Dictionary<long, long> _starts = [];

    /// <summary>
    /// The world's story where its log starts, <see langword="null"/> while nothing is logged.
    /// </summary>
    private readonly StoryValues? _log;

    /// <summary>
    /// The actions answered so far.
    /// </summary>
    private readonly RubyArray _actions = [];

    /// <summary>
    /// What the catch-up reads of a Classic party beyond its tables.
    /// </summary>
    private readonly ClassicParty _party;

    /// <summary>
    /// The key items a Classic member lacks, owed once per row, for the party chests that gave them first.
    /// </summary>
    private readonly List<(int Item, long Amount)> _owed = [];

    /// <summary>
    /// The roster read for this look, kept until the roster changes; <see langword="null"/> before.
    /// </summary>
    private RosterView? _rosterView;

    /// <summary>
    /// Starts a call of a Raid World's catch-up.
    /// </summary>
    /// <param name="engine">The engine.</param>
    /// <param name="tables">The tables.</param>
    /// <param name="request">The request.</param>
    public CatchupLook(CatchupEngine engine, CatchupTables tables, RubyHash request)
        : this(engine, tables, request, CatchupSettings.Raid, ClassicParty.None)
    {
    }

    /// <summary>
    /// Starts a call.
    /// </summary>
    /// <param name="engine">The engine.</param>
    /// <param name="tables">The tables.</param>
    /// <param name="request">The request; in the Classic settings "before" (the member's own story) and "leader" (the leader's) stand for "own" and "told".</param>
    /// <param name="settings">How the engine runs in the world type.</param>
    /// <param name="party">What the catch-up reads of a Classic party beyond its tables.</param>
    public CatchupLook(CatchupEngine engine, CatchupTables tables, RubyHash request, CatchupSettings settings, ClassicParty party)
    {
        _engine = engine;
        _tables = tables;
        _request = request;
        _settings = settings;
        _party = party;
        if (request.TryGetValue("ledger", out RubyValue? handed))
        {
            engine.Ledger = handed;
        }

        _before = RubyMarshal.Write(engine.Ledger);
        _worldId = request["world"].IsNil ? "" : request["world"].AsText();
        _mode = request["mode"].IsNil ? null : request["mode"].AsText();
        PersonalChoiceKeys choices = StoryChoices.Personal(true, null);
        _choiceSwitches.UnionWith(choices.Switches);
        _choiceVariables.UnionWith(choices.Variables);
        if (!settings.RaidWorld && StoryOf(request["leader"]) is { } leader)
        {
            _told = leader;
            _own = Followed(leader, StoryOf(request["before"]) ?? new StoryValues([], [], []));
        }
        else
        {
            _own = StoryOf(request["own"]) ?? new StoryValues([], [], []);
            _told = StoryOf(request["told"]);
        }

        _roster = request["roster"].IsNil ? [] : [.. request["roster"].AsArray().Select(RosterEntry.Of)];
        if (!request["items"].IsNil)
        {
            foreach ((RubyValue key, RubyValue count) in request["items"].AsHash())
            {
                _items[key.AsText()] = count.AsLong();
            }
        }

        if (request["lent"] is RubyHash lent)
        {
            foreach ((RubyValue id, RubyValue count) in lent)
            {
                string key = "i" + id.AsLong();
                if (_items.TryGetValue(key, out long held))
                {
                    _items[key] = Math.Max(held - count.AsLong(), 0);
                }
            }
        }

        _worn.UnionWith(Texts(request["worn"]));
        _unlockIds.UnionWith(Numbers(request["unlocks"]));


        _encounters = request["encounters"] is RubyBool { Flag: true };
        _summary = request["summary"] as RubyHash;
        _sharing = request["sharing"].IsNil ? "off" : request["sharing"].AsText();
        if (!request["starts"].IsNil)
        {
            foreach (RubyValue start in request["starts"].AsArray())
            {
                _starts[start.AsArray()[0].AsLong()] = start.AsArray()[1].AsLong();
            }
        }

        _log = StoryOf(request["log"]);
    }

    /// <summary>
    /// Writes a self switch as the scripts keep its key.
    /// </summary>
    /// <param name="key">The self switch.</param>
    /// <returns>[map, event, letter].</returns>
    public static RubyValue SelfSwitchOf(StoryKey key) => new RubyArray { key.Id, key.Event, key.Letter };

    /// <summary>
    /// Writes the item kind a reward row gives as the scripts name it.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>"skill", "i", "w" or "a".</returns>
    public static string KindOf(CatchupReward row) => row.Kind switch
    {
        "item" => "i",
        "weapon" => "w",
        "armor" => "a",
        _ => "skill",
    };

    /// <summary>
    /// Answers <see cref="CatchupEngine.Check"/>.
    /// </summary>
    /// <returns>The answer.</returns>
    public RubyHash Check()
    {
        var answer = new RubyHash();
        NoteRoute();
        if (_request["look"] is RubyString { Text: "carried" })
        {
            Carried(StoryOf(_request["before"]) ?? new StoryValues([], [], []));
        }
        else
        {
            NoteSide(_own);
            if (_request["audit"] is RubyBool { Flag: true })
            {
                Audit(_own);
            }
            else if (_request["vehicles"] is RubyBool { Flag: true })
            {
                CheckVehicles(_own, PlayedWorldStory);
            }

            GiveWaitingRewards();
            Review(_own, false);
            answer["ask_side"] = LostSide();
            answer["growth"] = Growth(_request["growth"] as RubyHash);
            answer["sharable"] = new RubyArray(NoteRoster().Select(id => (RubyValue)id));
            answer["orbs"] = _mode == "world" && OrbsDue();
            CheckMakina();
            MissedCompanions();
            CheckCounts();
        }

        answer["visiting"] = new RubyArray(_roster.Where(entry => Visiting(entry.Id, _own)).Select(entry => (RubyValue)entry.Id));
        return Finish(answer);
    }

    /// <summary>
    /// Answers <see cref="CatchupEngine.Note"/>.
    /// </summary>
    /// <returns>The answer.</returns>
    public RubyHash Note()
    {
        if (_request.TryGetValue("checkpoint", out RubyValue? checkpoint))
        {
            Ledger()["checkpoint"] = checkpoint;
        }

        if (_request["capped"] is RubyInteger capped)
        {
            NoteCapped((long)capped.Value);
        }

        if (_request["side"] is RubyString { Text: "alice" or "ilias" } side)
        {
            TakeSide(side.Text);
        }

        return Finish([]);
    }

    /// <summary>
    /// Answers <see cref="CatchupEngine.HoldJoin"/>.
    /// </summary>
    /// <returns>The answer.</returns>
    public RubyHash HoldJoin()
    {
        int main = _request["actor"].AsInt();
        RubyValue gate = RubyNil.Value;
        string? site = _request["site"].IsNil ? null : StoryPlain.SiteText(_request["site"]);
        if (!InRoster(main) && !_tables.Scope.AllowsAt(main, site, NotedSide()))
        {
            Log($"left out the join of {{actor:{main}}} at {site}: it is for the players who took the other side along, and the player took {NotedSide() ?? "no side"} along");
            return Finish(new RubyHash { { "gate", RubyNil.Value }, { "refused", true } });
        }

        if (_request["replay"] is RubyBool { Flag: true } && !InRoster(main))
        {
            long due = _tables.Index.JoinsOf(main).FirstOrDefault()?.Gate ?? (_request["start"] is RubyInteger start ? (long)start.Value : 1);
            if (_request["own_way"] is RubyBool { Flag: true })
            {
                if (!Allowed(main))
                {
                    Log($"left out the join of {{actor:{main}}} a replay the player answered their own way hands out: the player has no right to them");
                    return Finish(new RubyHash { { "gate", RubyNil.Value }, { "refused", true } });
                }
            }
            else if (!Allowed(main, CompanionPath.World) || !Reached(due))
            {
                Log($"left out the join of {{actor:{main}}} a replay hands out: the world's companion sharing ({_sharing}) {(Allowed(main, CompanionPath.World) ? $"brings them once the player's level reaches {due}" : "brings them to no other player")}");
                return Finish(new RubyHash { { "gate", RubyNil.Value }, { "refused", true } });
            }
        }

        if (_request["scope_only"] is RubyBool { Flag: true })
        {
            return Finish(new RubyHash { { "gate", gate } });
        }

        if (!InRoster(main) && !VisitRunning(main, site))
        {
            string part = _own.Part;
            RubyHash done = Done();
            CatchupJoin[] rows = [.. _tables.Index.JoinsOf(main).Where(row => row.Place.Part == part && !IsTrue(done[KeyOf("j", row)]))];
            if (rows.Length > 0)
            {
                int lowest = rows.Min(row => row.Gate);
                if (!Reached(lowest))
                {
                    Ledger()["held"].AsHash()[main] = true;
                    Log($"held back {{actor:{main}}}, whom the player's story event hands out: they join once the player's level reaches {lowest}");
                    gate = lowest;
                }
            }
        }

        return Finish(new RubyHash { { "gate", gate } });
    }

    /// <summary>
    /// Answers <see cref="CatchupEngine.Unlocks"/>.
    /// </summary>
    /// <returns>The answer.</returns>
    public RubyHash Unlocks() => new() { { "unlocks", new RubyArray([.. StoryUnlocks(), .. CompanionUnlocks(_own, _told), .. MakinaUnlocks()]) } };

    /// <summary>
    /// Answers <see cref="CatchupEngine.Classic"/>: the leader's story laid over the member's own, as
    /// a Raid World's story is laid over a player's, with the companions' skills and classes the
    /// leader's story is past and the member's is not, the party chests that gave the key items the
    /// member lacks, and the closures of the member's own keys the leader's story holds.
    /// </summary>
    /// <returns>The answer.</returns>
    public RubyHash Classic()
    {
        StoryValues before = StoryOf(_request["before"]) ?? new StoryValues([], [], []);
        if (SavePick is { Length: > 0 } pick)
        {
            Ledger()["side"] = pick;
        }

        Ledger()["routes"] = new RubyArray(ClassicStory.Routes(before, _own).Select(route => (RubyValue)route));
        Carried(before);
        MissingLessons(_own, null, before);
        MissingClassLevels(_own, null, before);
        RubyHash selves = _request["selves"] as RubyHash ?? [];
        List<StoryKey> leaderSelves = SelvesOf(selves["leader"]);
        OwedKeyItems(leaderSelves);
        Closures(leaderSelves, [.. SelvesOf(selves["own"])]);
        Gifts();
        return Finish([]);
    }

    /// <summary>
    /// Hands a Classic member the key items the leader's story owes them: those a party chest the
    /// leader's story opened gave come by playing that chest in the member's own game, the whole chest
    /// with them, the others as the rows give them.
    /// </summary>
    /// <param name="leaderSelves">The self switches on in the leader's story.</param>
    private void OwedKeyItems(List<StoryKey> leaderSelves)
    {
        if (_owed.Count == 0)
        {
            return;
        }

        HashSet<StoryKey> on = [.. leaderSelves];
        var covered = new HashSet<int>();
        foreach (KeyItemChest chest in _party.KeyItemChests([.. _tables.PartyChests.Where(on.Contains)], [.. _owed.Select(owed => owed.Item)]))
        {
            Act("replay", new RubyHash { { "chest", StoryPlain.Plain(chest.Key) } }, "o:" + chest.Key);
            covered.UnionWith(chest.Items);
        }

        foreach ((int item, long amount) in _owed.Where(owed => !covered.Contains(owed.Item)))
        {
            Give("i", item, amount, $"k:owed:{item}");
        }
    }

    /// <summary>
    /// Plays in a Classic member's game the closures of their own keys the leader's story holds, which
    /// ran in the leader's game before the member followed it: each self switch on in the leader's
    /// story and off in theirs that the reviewed list keeps each member's own, a party chest's aside,
    /// played from the page that turns it on with its choices answered by the leader's letters of the
    /// event. Each plays once per catch-up.
    /// </summary>
    /// <remarks>
    /// A party chest comes with the key items it gave (<see cref="OwedKeyItems"/>), and a choice's
    /// line with the member's own answer to it.
    /// </remarks>
    /// <param name="leaderSelves">The self switches on in the leader's story.</param>
    /// <param name="ownSelves">Those on in the member's own story.</param>
    private void Closures(List<StoryKey> leaderSelves, HashSet<StoryKey> ownSelves)
    {
        HashSet<StoryKey> chests = [.. _tables.PartyChests];
        HashSet<StoryKey> on = [.. leaderSelves];
        RubyHash done = Done();
        foreach (StoryKey key in leaderSelves.Where(key => !ownSelves.Contains(key) && !chests.Contains(key) && _party.IsOwn(key)))
        {
            string mark = "d:" + key;
            if (Truthy(done[mark]))
            {
                continue;
            }

            done[mark] = true;
            var letters = new RubyArray(Letters.Where(letter => on.Contains(StoryKey.SelfSwitch(key.Id, key.Event, letter))).Select(letter => (RubyValue)letter));
            Act("replay", new RubyHash { { "chest", StoryPlain.Plain(key) }, { "letters", letters } }, mark);
        }
    }

    /// <summary>
    /// Reads self switches the scripts list.
    /// </summary>
    /// <param name="value">[map, event, letter] each, nil for none.</param>
    /// <returns>The self switches, in their order.</returns>
    /// <exception cref="BridgeRequestException">One is no [map, event, letter].</exception>
    private static List<StoryKey> SelvesOf(RubyValue value) => value.IsNil ? [] : [.. value.AsArray().Select(key => key.AsArray() is { Count: 3 } fields
        ? StoryKey.SelfSwitch(fields[0].AsInt(), fields[1].AsInt(), fields[2].AsText())
        : throw new BridgeRequestException("A self switch is [map, event, letter]."))];

    /// <summary>
    /// Tells whether a value counts as true, as Ruby reads it.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>Whether it is neither nil nor false.</returns>
    private static bool Truthy(RubyValue value) => value is not RubyNil and not RubyBool { Flag: false };

    /// <summary>
    /// Tells whether a value is true itself.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>Whether it is.</returns>
    private static bool IsTrue(RubyValue value) => value is RubyBool { Flag: true };

    /// <summary>
    /// Reads the whole numbers of a list.
    /// </summary>
    /// <param name="value">The list, nil for none.</param>
    /// <returns>The numbers.</returns>
    private static IEnumerable<long> Numbers(RubyValue value) => value.IsNil ? [] : value.AsArray().Select(item => item.AsLong());

    /// <summary>
    /// Reads the texts of a list.
    /// </summary>
    /// <param name="value">The list, nil for none.</param>
    /// <returns>The texts.</returns>
    private static IEnumerable<string> Texts(RubyValue value) => value.IsNil ? [] : value.AsArray().Select(item => item.AsText());

    /// <summary>
    /// Reads a story a snapshot carries.
    /// </summary>
    /// <param name="value">"s", "v" and "ss", nil for none.</param>
    /// <returns>The story, <see langword="null"/> for none.</returns>
    /// <exception cref="BridgeRequestException">A self switch is no [map, event, letter].</exception>
    internal static StoryValues? StoryOf(RubyValue value)
    {
        if (value.IsNil)
        {
            return null;
        }

        RubyHash story = value.AsHash();
        var selves = new List<StoryKey>();
        foreach (RubyValue key in story["ss"].AsArray())
        {
            RubyArray parts = key.AsArray();
            if (parts.Count != 3)
            {
                throw new BridgeRequestException("A self switch is [map, event, letter].");
            }

            selves.Add(StoryKey.SelfSwitch(parts[0].AsInt(), parts[1].AsInt(), parts[2].AsText()));
        }

        return new StoryValues(
            story["s"].AsArray().Select(id => id.AsInt()),
            story["v"].AsArray().Select(pair => new KeyValuePair<int, long>(pair.AsArray()[0].AsInt(), pair.AsArray()[1].AsLong())),
            selves);
    }

    /// <summary>
    /// Makes the story a Classic member keeps of the leader's: the leader's, with the outcomes of every
    /// choice as the member's own story holds them, so a row behind a choice the member has not
    /// answered waits for their answer, and the side switch of the side the save notes they took
    /// along, none while it notes none.
    /// </summary>
    /// <param name="leader">The leader's story.</param>
    /// <param name="before">The member's own story.</param>
    /// <returns>The story.</returns>
    private StoryValues Followed(StoryValues leader, StoryValues before)
    {
        int? side = SavePick switch
        {
            "alice" => StoryIds.SideSwitches[0],
            "ilias" => StoryIds.SideSwitches[1],
            _ => null,
        };
        bool Choice(int id) => _choiceSwitches.Contains(id) && !StoryIds.SideSwitches.Contains(id);
        return new StoryValues(
            leader.SwitchesOn.Where(id => !Choice(id) && !StoryIds.SideSwitches.Contains(id))
                .Concat(before.SwitchesOn.Where(Choice)).Concat(side is { } on ? [on] : []),
            leader.Variables.Where(pair => !_choiceVariables.Contains(pair.Key)).Concat(before.Variables.Where(pair => _choiceVariables.Contains(pair.Key))),
            leader.SelfSwitchesOn);
    }

    /// <summary>
    /// Ends a call: its actions, and the notes when they changed.
    /// </summary>
    /// <param name="answer">The answer so far.</param>
    /// <returns>The answer.</returns>
    private RubyHash Finish(RubyHash answer)
    {
        answer["actions"] = _actions;
        answer["ledger"] = RubyMarshal.Write(_engine.Ledger).AsSpan().SequenceEqual(_before) ? RubyNil.Value : _engine.Ledger;
        return answer;
    }

    /// <summary>
    /// Adds a log line, a companion written {actor:id} for the scripts to name.
    /// </summary>
    /// <param name="text">The line.</param>
    private void Log(string text) => _actions.Add(new RubyArray { "log", text });

    /// <summary>
    /// Adds an action.
    /// </summary>
    /// <param name="action">The action: its name, then its fields.</param>
    private void Act(params RubyValue[] action) => _actions.Add(new RubyArray(action));

    /// <summary>
    /// Reads the save's notes, started anew for another world.
    /// </summary>
    /// <returns>The notes.</returns>
    private RubyHash Ledger()
    {
        if (_engine.Ledger is not RubyHash notes || notes["world"] is not RubyString world || world.Text != _worldId || notes["done"] is not RubyHash)
        {
            notes = new RubyHash
            {
                { "world", _worldId }, { "done", new RubyHash() }, { "held", new RubyHash() }, { "checkpoint", RubyNil.Value }, { "side", RubyNil.Value },
                { "capped", RubyNil.Value }, { "waits", new RubyHash() }, { "rewards_repaired", true },
            };
            _engine.Ledger = notes;
        }

        if (!Truthy(notes["held"]))
        {
            notes["held"] = new RubyHash();
        }

        if (!Truthy(notes["waits"]))
        {
            notes["waits"] = new RubyHash();
        }

        return notes;
    }

    /// <summary>
    /// Reads the rows done of the save's notes.
    /// </summary>
    /// <returns>The rows' keys and their notes.</returns>
    private RubyHash Done() => Ledger()["done"].AsHash();

    /// <summary>
    /// Reads the rewards waiting for a gate.
    /// </summary>
    /// <returns>The rows' keys and their gates.</returns>
    private RubyHash Waits() => Ledger()["waits"].AsHash();

    /// <summary>
    /// Reads the gate a move on at a cap noted.
    /// </summary>
    /// <returns>The gate, <see langword="null"/> for none.</returns>
    private long? Capped() => Ledger()["capped"] is RubyInteger gate ? (long)gate.Value : null;

    /// <summary>
    /// Reports whether a choice's outcome is among a row's marks, which only the player's own story
    /// holds.
    /// </summary>
    /// <param name="key">The mark's key.</param>
    /// <returns>Whether it is.</returns>
    private bool ChoiceKey(StoryKey key) => key.Kind == StoryKeyKind.Switch ? _choiceSwitches.Contains(key.Id) : _choiceVariables.Contains(key.Id);

    /// <summary>
    /// Reads the side the save notes the player chose before the Great Decision.
    /// </summary>
    /// <returns>The side, <see langword="null"/> for none.</returns>
    private string? NotedSide() => Ledger()["side"] is RubyString side && side.Text.Length > 0 ? side.Text : null;

    /// <summary>
    /// Reports whether a story is past a row, see <see cref="StoryRows.Passed"/>.
    /// </summary>
    /// <param name="place">The row's place.</param>
    /// <param name="story">The story.</param>
    /// <param name="own">The player's story.</param>
    /// <returns>Whether it is.</returns>
    private bool Passed(StoryPlace place, StoryValues story, StoryValues own) => StoryRows.Passed(place, story, own, RowSide(), ChoiceKey);

    /// <summary>
    /// Reads the side whose rows count: the side the save notes, but in a Classic party whose
    /// leader's story is past the Great Decision the side its switches show, the leader's route's.
    /// </summary>
    /// <returns>The side, <see langword="null"/> for none.</returns>
    private string? RowSide() => !_settings.RaidWorld && _told is { } leader && !SidePick.SidesDiffer(leader) ? leader.Side : NotedSide();

    /// <summary>
    /// Reports whether the player's story is past a row.
    /// </summary>
    /// <param name="place">The row's place.</param>
    /// <param name="story">The player's story.</param>
    /// <returns>Whether it is.</returns>
    private bool Passed(StoryPlace place, StoryValues story) => Passed(place, story, story);

    /// <summary>
    /// Reports whether the player's story or the world's is past a row.
    /// </summary>
    /// <param name="place">The row's place.</param>
    /// <param name="story">The player's story.</param>
    /// <param name="told">The world's story, <see langword="null"/> when it does not count.</param>
    /// <returns>Whether one is.</returns>
    private bool PassedAny(StoryPlace place, StoryValues story, StoryValues? told) => Passed(place, story) || (told is not null && Passed(place, told, story));

    /// <summary>
    /// Reports whether a row's history lies before the world's log, the only history whose rows give
    /// what they give: the world's story was past it where its log starts. The world's track
    /// replays the runs its log holds.
    /// </summary>
    /// <param name="place">The row's place.</param>
    /// <returns>Whether it does.</returns>
    private bool BeforeLog(StoryPlace place) => _log is null || Passed(place, _log, _own);

    /// <summary>
    /// Names a row in the notes.
    /// </summary>
    /// <param name="kind">"j" join, "r" removal.</param>
    /// <param name="row">The join or removal's place and persona.</param>
    /// <returns>Its key.</returns>
    private static string KeyOf(string kind, CatchupJoin row) => $"{kind}:{row.Place.Site}:{row.Persona}";

    /// <summary>
    /// Names a removal in the notes.
    /// </summary>
    /// <param name="row">The removal.</param>
    /// <returns>Its key.</returns>
    private static string KeyOf(CatchupRemoval row) => $"r:{row.Place.Site}:{row.Persona}";

    /// <summary>
    /// Names a key item row in the notes.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>Its key.</returns>
    private static string KeyOf(CatchupKeyItem row) => $"k:{row.Place.Site}:{row.Item}:{row.Amount}";

    /// <summary>
    /// Names a chest in the notes.
    /// </summary>
    /// <param name="row">The chest.</param>
    /// <returns>Its key.</returns>
    private static string KeyOf(CatchupChest row) => row.Key.Kind == StoryKeyKind.Switch ? $"c:{row.Key}" : $"c:{row.Key.Id}.{row.Key.Event}.{row.Key.Letter}";

    /// <summary>
    /// Names an actor change in the notes.
    /// </summary>
    /// <param name="row">The change.</param>
    /// <returns>Its key.</returns>
    private static string KeyOf(CatchupActorChange row) => $"a:{row.Place.Site}:{row.Actor}";

    /// <summary>
    /// Names a reward in the notes.
    /// </summary>
    /// <param name="row">The reward.</param>
    /// <returns>Its key.</returns>
    private static string KeyOf(CatchupReward row) => $"g:{row.Place.Site}:{KindOf(row)}{row.Id}";

    /// <summary>
    /// Finds a part of the tables.
    /// </summary>
    /// <param name="id">The part.</param>
    /// <returns>The part, <see langword="null"/> for none.</returns>
    private CatchupPart? Part(string id) => _tables.Parts.FirstOrDefault(part => part.Id == id);

    /// <summary>
    /// Reads the level that moves a player on from a part.
    /// </summary>
    /// <param name="id">The part.</param>
    /// <returns>Its gate, the last part's for one the tables lack; <see langword="null"/> without parts.</returns>
    private int? GateOf(string id) => (Part(id) ?? _tables.Parts.LastOrDefault())?.Gate;

    /// <summary>
    /// Names a part.
    /// </summary>
    /// <param name="id">The part.</param>
    /// <returns>Its name.</returns>
    private string PartName(string id) => Part(id)?.Name ?? $"Part {id}";

    /// <summary>
    /// Reports whether a gate lets the player move on: their level, or a cap of another mod below it.
    /// </summary>
    /// <param name="level">The gate.</param>
    /// <returns>Whether it does.</returns>
    private bool GateOpen(long level)
    {
        if (Reached(level))
        {
            return true;
        }

        RosterView view = RosterNow();
        return view.Best is { } best && view.Cap is { } cap && cap < level && best >= cap;
    }

    /// <summary>
    /// Reports whether the player's highest base level reaches a level.
    /// </summary>
    /// <param name="level">The level.</param>
    /// <returns>Whether it does.</returns>
    private bool Reached(long level) => RosterNow().Best is { } best && best >= level;

    /// <summary>
    /// Reports whether a companion is in the roster.
    /// </summary>
    /// <param name="id">The companion's main persona.</param>
    /// <returns>Whether they are.</returns>
    private bool InRoster(long id) => RosterNow().Ids.Contains(id);

    /// <summary>
    /// Reads the roster: its companions, and the highest base level among those not on a visit with
    /// that character's cap, kept until the roster changes.
    /// </summary>
    /// <returns>The roster.</returns>
    private RosterView RosterNow()
    {
        if (_rosterView is { } view)
        {
            return view;
        }

        RosterEntry? best = null;
        foreach (RosterEntry entry in _roster)
        {
            if (!Visiting(entry.Id, _own) && (best is null || entry.Level > best.Level))
            {
                best = entry;
            }
        }

        return _rosterView = new RosterView([.. _roster.Select(entry => entry.Id)], best?.Level, best?.Cap);
    }

    /// <summary>
    /// Forgets the roster read, as a companion joined or left.
    /// </summary>
    private void RosterChanged() => _rosterView = null;

    /// <summary>
    /// Notes the gate a move on at a cap of another mod opened while the player's level is below it.
    /// </summary>
    /// <param name="gate">The gate.</param>
    private void NoteCapped(long gate)
    {
        bool waits = !Reached(gate);
        Ledger()["capped"] = waits ? gate : RubyNil.Value;
        if (waits)
        {
            Log($"moved on at a level cap below {gate}: the story's rewards wait for level {gate}");
        }
    }

    /// <summary>
    /// Forgets the gate a move on at a cap noted.
    /// </summary>
    /// <param name="reason">Why, for the log.</param>
    private void DropCapped(string reason)
    {
        if (Capped() is not { } gate)
        {
            return;
        }

        Ledger()["capped"] = RubyNil.Value;
        Log($"the story's rewards no longer wait for level {gate}: {reason}");
    }

    /// <summary>
    /// Reports whether the rewards a story laid over the player's carries them past wait for the
    /// gate a cap opened.
    /// </summary>
    /// <returns>Whether they do.</returns>
    private bool RewardsWait() => Capped() is { } gate && !Reached(gate);

    /// <summary>
    /// Gives the rewards that wait for a gate the player's level reached.
    /// </summary>
    private void GiveWaitingRewards()
    {
        RubyHash waits = Waits();
        if (waits.Count == 0)
        {
            return;
        }

        foreach (CatchupReward row in _tables.Rewards)
        {
            string key = KeyOf(row);
            if (waits[key] is not RubyInteger gate || !Reached((long)gate.Value))
            {
                continue;
            }

            waits.Remove(key);
            Give(KindOf(row), row.Id, row.Amount, key);
        }

        Gifts();
    }

    /// <summary>
    /// Lists the world's parts in the order it played them.
    /// </summary>
    /// <param name="world">The world's summary.</param>
    /// <returns>The parts.</returns>
    private static List<string> WorldParts(RubyHash world) => [.. StoryRows.WorldParts(world["part"].IsNil ? "" : world["part"].AsText(), Texts(world["done"]))];

    /// <summary>
    /// Finds where a player moves on to from a part.
    /// </summary>
    /// <param name="from">The player's part.</param>
    /// <param name="world">The world's summary.</param>
    /// <returns>The part, or <see cref="StoryRows.WorldTrack"/>.</returns>
    private static string NextPart(string from, RubyHash world) =>
        StoryRows.NextPart(from, world["part"].IsNil ? "" : world["part"].AsText(), Texts(world["done"]), Texts(world["checkpoints"]));

    /// <summary>
    /// Reports whether the player's story went past the choice of a side in Iliasville while the save
    /// notes no side they took along themselves, before the Great Decision or on a route: a story the
    /// world's carried past it, or a save of another player's starting save, whose side is that
    /// player's. A save of the player's own that the notes first saw on a route picked, though which
    /// side is unknown.
    /// </summary>
    /// <returns>Whether it did.</returns>
    private bool LostSide() => SidePick.Lost(Ledger()["side"] is RubyString noted ? noted.Text : null, OtherStart, _own, _own, _tables.Rules.SideStep);

    /// <summary>
    /// Notes the side the player took along in Iliasville: the one the save notes, else before the
    /// Great Decision, which the route sets anew, the one their story holds, as an empty side while it
    /// has none. A side another player's starting save brought is not theirs until the notes saw them
    /// take it, so the player is asked (<see cref="LostSide"/>).
    /// </summary>
    /// <param name="story">The player's story.</param>
    private void NoteSide(StoryValues story)
    {
        RubyValue noted = Ledger()["side"];
        bool unnoted = noted.IsNil || noted is RubyString { Text.Length: 0 };
        if (SavePick is { Length: > 0 } pick)
        {
            if (unnoted)
            {
                Ledger()["side"] = pick;
            }

            return;
        }

        if (!_settings.SideFromSwitches || !SidePick.SidedParts.Contains(story.Part))
        {
            return;
        }

        if (story.Side is { } side)
        {
            if (noted is RubyString { Text.Length: 0 } || (noted.IsNil && !OtherStart))
            {
                Ledger()["side"] = side;
            }
        }
        else if (noted.IsNil)
        {
            Ledger()["side"] = "";
        }
    }

    /// <summary>
    /// Gets the side the save notes the player took along in Iliasville, in any world: "alice" or
    /// "ilias", empty for a save of another player's starting save, <see langword="null"/> while
    /// unknown.
    /// </summary>
    private string? SavePick => _request["pick"] is RubyString pick ? pick.Text : null;

    /// <summary>
    /// Gets whether the save came from another player's starting save with that player's side.
    /// </summary>
    private bool OtherStart => SavePick is { Length: 0 };

    /// <summary>
    /// Notes the side the player answered they take along, see <see cref="LostSide"/>.
    /// </summary>
    /// <param name="side">"alice" or "ilias".</param>
    private void TakeSide(string side)
    {
        Ledger()["side"] = side;
        Log($"noted the side the player takes along: {side}");
    }

    /// <summary>
    /// Notes the route the player's story is on, which every companion obtained there may stay with.
    /// </summary>
    private void NoteRoute()
    {
        string part = _own.Part;
        if (!StoryParts.Routes.Contains(part))
        {
            return;
        }

        RubyHash notes = Ledger();
        RubyArray routes = notes["routes"] as RubyArray ?? [];
        if (routes.Any(route => route.AsText() == part))
        {
            return;
        }

        routes.Add(part);
        notes["routes"] = routes;
    }

    /// <summary>
    /// Lists the routes the player played: those the notes saw their story on and the one it is on.
    /// </summary>
    /// <param name="cleared">Whether the routes their story holds cleared count too, which a Raid World shares, so a companion a save brought from a route played before the notes kept routes stays.</param>
    /// <returns>The routes.</returns>
    private HashSet<string> PlayedRoutes(bool cleared)
    {
        HashSet<string> routes = [.. Texts(Ledger()["routes"])];
        if (StoryParts.Routes.Contains(_own.Part))
        {
            routes.Add(_own.Part);
        }

        if (cleared)
        {
            routes.UnionWith(StoryParts.Routes.Where(_own.Cleared));
        }

        return routes;
    }

    /// <summary>
    /// Reports whether a companion may join the player by a path, see the one companion filter
    /// <see cref="CompanionScope.Allows(int, CompanionPath, string, string?, IReadOnlyCollection{string})"/>.
    /// </summary>
    /// <param name="actor">The companion's main persona.</param>
    /// <param name="path">How the companion comes.</param>
    /// <returns>Whether they may.</returns>
    private bool Allowed(int actor, CompanionPath path = CompanionPath.Own) => _tables.Scope.Allows(actor, path, _sharing, NotedSide(), PlayedRoutes(false));

    /// <summary>
    /// Takes away the companions of the Alice and Ilias choice the player never had a right to: of the
    /// other side, or of a route they never played. One a route the player played gave them stays,
    /// and while the side they took along is unknown, or they are asked for it, everyone stays.
    /// </summary>
    private void DismissStrangers()
    {
        if (NotedSide() is not { } pick)
        {
            return;
        }

        HashSet<string> routes = PlayedRoutes(true);
        foreach (RosterEntry entry in _roster.ToList())
        {
            int id = (int)entry.Id;
            if (id == Hero || !_tables.Scope.IsChoiceCompanion(id) || _tables.Scope.Allows(id, pick, routes) || Visiting(id, _own))
            {
                continue;
            }

            Act("dismiss", id);
            Log($"{{actor:{id}}} left the roster: the player took {pick} along and played {(routes.Count == 0 ? "no route" : string.Join(", ", routes.Order(StringComparer.Ordinal)))}, which never give them");
            _roster.Remove(entry);
            RosterChanged();
        }
    }

    /// <summary>
    /// Reads the world's story while the player plays it.
    /// </summary>
    private StoryValues? PlayedWorldStory => _mode == "world" ? _told : null;

    /// <summary>
    /// Looks at everything the story owes the player once.
    /// </summary>
    /// <param name="story">The player's story.</param>
    private void Audit(StoryValues story)
    {
        StoryValues? world = PlayedWorldStory;
        RubyHash done = Done();
        MissingSkills(story, world);
        RestockKeyItems(story, _told);
        RestockUnlockItems(story, _told);
        RepairRewards(story);
        MissingCompanions(story, _told, done);
        DismissStrangers();
        CompanionValues();
        Settle(story, world);
        CheckVehicles(story, world);
        Log("looked at everything the story owes the player once");
        Gifts();
    }

    /// <summary>
    /// Teaches Luka the story's skills of the rows passed, unless the row waits for its gate.
    /// </summary>
    /// <param name="story">The player's story.</param>
    /// <param name="told">The world's story while the player plays it.</param>
    private void MissingSkills(StoryValues story, StoryValues? told)
    {
        RubyHash waits = Waits();
        foreach (CatchupReward row in _tables.Rewards.Where(row => row.Kind == "skill" && row.Ran))
        {
            string key = KeyOf(row);
            if (!Truthy(waits[key]) && BeforeLog(row.Place) && PassedAny(row.Place, story, told))
            {
                Act("learn", row.Id, key);
            }
        }
    }

    /// <summary>
    /// Looks at the roster's skills, classes and races every <see cref="GrowthChecks"/> looks, and at
    /// the next look after the roster changed.
    /// </summary>
    /// <param name="growth">"count" and "roster" as the last look left them, <see langword="null"/> for none.</param>
    /// <returns>The same, after this look.</returns>
    private RubyHash Growth(RubyHash? growth)
    {
        long count = (growth is not null && growth["count"] is RubyInteger counted ? (long)counted.Value : 0) + 1;
        RubyValue roster = growth?["roster"] ?? RubyNil.Value;
        var ids = new RubyArray(_roster.Select(entry => (RubyValue)entry.Id));
        if (count < GrowthChecks && ids.Equals(roster))
        {
            return new RubyHash { { "count", count }, { "roster", roster } };
        }

        MissingLessons(_own, PlayedWorldStory);
        MissingClassLevels(_own, PlayedWorldStory);
        Gifts();
        return new RubyHash { { "count", 0 }, { "roster", ids } };
    }

    /// <summary>
    /// Teaches the roster's companions the skills the story taught them.
    /// </summary>
    /// <param name="story">The player's story.</param>
    /// <param name="told">The world's story while the player plays it.</param>
    /// <param name="already">A story whose rows count as given, <see langword="null"/> for none.</param>
    private void MissingLessons(StoryValues story, StoryValues? told, StoryValues? already = null)
    {
        foreach (CatchupLesson row in _tables.Lessons.Where(row => row.Ran && InRoster(row.Actor) && BeforeLog(row.Place) && PassedAny(row.Place, story, told) && (already is null || !Passed(row.Place, already))))
        {
            Act("teach", row.Actor, row.Skill);
        }
    }

    /// <summary>
    /// Gives the roster's characters the classes and races the story gave them.
    /// </summary>
    /// <param name="story">The player's story.</param>
    /// <param name="told">The world's story while the player plays it.</param>
    /// <param name="already">A story whose rows count as given, <see langword="null"/> for none.</param>
    private void MissingClassLevels(StoryValues story, StoryValues? told, StoryValues? already = null)
    {
        foreach (CatchupClassLevel row in _tables.ClassLevels.Where(row => row.Ran && (row.Actor == Hero || InRoster(row.Actor)) && BeforeLog(row.Place) && PassedAny(row.Place, story, told) && (already is null || !Passed(row.Place, already))))
        {
            Act("class", row.Actor, row.Class, row.Level);
        }
    }

    /// <summary>
    /// Lets the story's companions the roster lacks join at their gate.
    /// </summary>
    /// <param name="story">The player's story.</param>
    /// <param name="told">The world's story.</param>
    /// <param name="done">The rows done.</param>
    private void MissingCompanions(StoryValues story, StoryValues? told, RubyHash done)
    {
        foreach (CatchupJoin row in _tables.Index.StoryJoins)
        {
            string key = KeyOf("j", row);
            if (!IsTrue(done[key]) || row.Place.Part is null || !row.Ran || InRoster(row.Actor) || !BeforeLog(row.Place) || !PassedAny(row.Place, story, told) || TakenAwaySince(row, story, told) || !Allowed(row.Actor))
            {
                continue;
            }

            done[key] = "c";
            Log($"{{actor:{row.Persona}}} of {row.Place.Site} is missing from the roster: joins at level {row.Gate}");
        }

        BringWaiting(done);
    }

    /// <summary>
    /// Reports whether a removal after a join took the companion away again.
    /// </summary>
    /// <param name="row">The join.</param>
    /// <param name="story">The player's story.</param>
    /// <param name="told">The world's story.</param>
    /// <returns>Whether one did.</returns>
    private bool TakenAwaySince(CatchupJoin row, StoryValues story, StoryValues? told) =>
        _tables.Removals.Any(removal => removal.Actor == row.Actor && StoryRows.After(removal.Place, removal.Index, row.Place, row.Index) && OnPlayedRoute(removal.Place) && PassedAny(removal.Place, story, told));

    /// <summary>
    /// Reports whether a removal's place may take a companion from the player: any but a route's, and
    /// a route's only while the player plays or played that route, since a route the world finished
    /// hands its companions out but takes none away.
    /// </summary>
    /// <param name="place">The removal's place.</param>
    /// <returns>Whether it may.</returns>
    private bool OnPlayedRoute(StoryPlace place) => place.Part is not { } part || !StoryParts.Routes.Contains(part) || PlayedRoutes(false).Contains(part);

    /// <summary>
    /// Raises the story values of the companions in the roster to what their joins stand for.
    /// </summary>
    private void CompanionValues()
    {
        foreach (CompanionValue value in _tables.CompanionValues)
        {
            if (!InRoster(value.Actor))
            {
                continue;
            }

            long now = _own.Variable(value.Variable) ?? 0;
            if (now >= value.AtLeast)
            {
                continue;
            }

            SetVariable(value.Variable, value.AtLeast);
            Log($"raised variable {value.Variable} from {now} to {value.AtLeast}: {{actor:{value.Actor}}} is in the roster, whose join stands for it");
        }
    }

    /// <summary>
    /// Finds the player's own values the story's events set where they still hold what an earlier
    /// step set: the latest step passed sets them, which the scripts apply where they may. A value
    /// whose latest row lies on a step in free order (the rules' <c>free_order</c>) stays as it is,
    /// since the rows there cannot tell which region the world played last.
    /// </summary>
    /// <param name="story">The player's story.</param>
    /// <param name="told">The world's story while the player plays it.</param>
    private void Settle(StoryValues story, StoryValues? told)
    {
        string part = story.Part;
        var latest = new Dictionary<(string, int), CatchupSetting>();
        var order = new List<(string, int)>();
        var earlier = new Dictionary<(string, int), List<RubyValue>>();
        foreach (CatchupSetting row in _tables.Settings)
        {
            if ((row.Place.Part is { } rowPart && StoryParts.Routes.Contains(rowPart) && rowPart != part) || !BeforeLog(row.Place) || !PassedAny(row.Place, story, told))
            {
                continue;
            }

            (string, int) key = (row.Kind, row.Id);
            if (latest.TryGetValue(key, out CatchupSetting? before))
            {
                (earlier.TryGetValue(key, out List<RubyValue>? values) ? values : earlier[key] = []).Add(ValueOf(before));
            }
            else
            {
                order.Add(key);
            }

            latest[key] = row;
        }

        foreach ((string, int) key in order)
        {
            CatchupSetting row = latest[key];
            if (InFreeOrder(row.Place))
            {
                continue;
            }

            RubyValue now = row.Kind == "encounters" ? _encounters : _own.Variable(row.Id) is { } number ? number : RubyNil.Value;
            if (now.Equals(ValueOf(row)) || !earlier.TryGetValue(key, out List<RubyValue>? values) || !values.Any(value => value.Equals(now)))
            {
                continue;
            }

            Act("setting", row.Kind == "encounters" ? "encounters" : row.Kind == "variable" ? "v" : "s", row.Id, ValueOf(row), StoryPlain.SiteOf(row.Place.Site));
        }
    }

    /// <summary>
    /// Reports whether a row lies on a step whose regions the world plays in an order of its own.
    /// </summary>
    /// <param name="place">The row's place.</param>
    /// <returns>Whether it does.</returns>
    private bool InFreeOrder(StoryPlace place) =>
        place is { Part: { } part, Step: { } step } && _tables.Rules.FreeOrder.Contains(new PartStep(part, step));

    /// <summary>
    /// Reads the value a setting row sets.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>A variable's number, else whether the switch or the encounters are on.</returns>
    private static RubyValue ValueOf(CatchupSetting row) => row.Kind == "variable" ? row.Number : row.On;

    /// <summary>
    /// Finds which vehicles a row behind the player's story or the world's gave: true where a row
    /// before the world's log did, nil where only a row the log holds did, whose replay places it,
    /// and false where none did.
    /// </summary>
    /// <param name="story">The player's story.</param>
    /// <param name="told">The world's story while the player plays it.</param>
    private void CheckVehicles(StoryValues story, StoryValues? told)
    {
        var given = new RubyArray();
        foreach (string vehicle in (string[])["boat", "ship", "airship"])
        {
            CatchupVehicle[] passed = [.. _tables.Vehicles.Where(row => row.Vehicle == vehicle && PassedAny(row.Place, story, told))];
            given.Add(passed.Any(row => BeforeLog(row.Place)) ? true : passed.Length > 0 ? RubyNil.Value : false);
        }

        Act("vehicles", given);
    }

    /// <summary>
    /// Looks at every row against the player's story: those their own game played are noted done,
    /// those a story carried them past give their rewards or wait for their gate, the world's key
    /// items and chests come, companions come and go, and the actor changes run.
    /// </summary>
    /// <param name="story">The player's story.</param>
    /// <param name="carried">Whether a story laid over theirs just carried them past what is new.</param>
    private void Review(StoryValues story, bool carried)
    {
        NoteSide(story);
        RubyHash done = Done();
        RubyHash? waits = carried && RewardsWait() ? Waits() : null;
        foreach (CatchupReward row in _tables.Rewards)
        {
            string key = KeyOf(row);
            if (Truthy(done[key]) || (carried && !row.Ran) || !Passed(row.Place, story) || (!_settings.MedalKingFromRows && MedalKingGift.IsGift(row, _tables)))
            {
                continue;
            }

            done[key] = true;
            if (!(carried && BeforeLog(row.Place)) && !MedalKingGift.Owed(row, _tables, _items.ContainsKey, Held))
            {
                continue;
            }

            if (waits is not null)
            {
                waits[key] = Ledger()["capped"];
            }
            else
            {
                Give(KindOf(row), row.Id, row.Amount, key);
            }
        }

        WorldItems(story, carried, done);
        Companions(story, carried, done);
        if (_settings.ActorChanges)
        {
            ActorChanges(story, carried, done);
        }

        if (carried && _settings.SettlesValues)
        {
            Settle(story, PlayedWorldStory);
        }

        Gifts();
    }

    /// <summary>
    /// Reports whether the party holds an item, in the bag or worn.
    /// </summary>
    /// <param name="item">The item, such as "i501".</param>
    /// <returns>Whether it does.</returns>
    private bool Held(string item) => (_items.TryGetValue(item, out long count) && count > 0) || _worn.Contains(item);

    /// <summary>
    /// Notes the actor changes passed and runs those whose gate the level reached.
    /// </summary>
    /// <param name="story">The player's story.</param>
    /// <param name="carried">Whether a story laid over theirs carried them past what is new.</param>
    /// <param name="done">The rows done.</param>
    private void ActorChanges(StoryValues story, bool carried, RubyHash done)
    {
        long capped = carried && RewardsWait() ? Capped() ?? 0 : 0;
        foreach (CatchupActorChange row in _tables.ActorChanges)
        {
            string key = KeyOf(row);
            if (Truthy(done[key]) || (carried && !row.Ran) || !Passed(row.Place, story))
            {
                continue;
            }

            done[key] = carried && BeforeLog(row.Place) ? Math.Max(row.Gate ?? 0, capped) : true;
        }

        foreach (CatchupActorChange row in _tables.ActorChanges)
        {
            string key = KeyOf(row);
            if (done[key] is not RubyInteger gate || !Reached((long)gate.Value))
            {
                continue;
            }

            done[key] = true;
            Act("change", row.Actor, row.Place.Site, new RubyArray(row.Calls.Select(call => (RubyValue)new RubyArray { call.Name, new RubyArray(call.Numbers.Select(number => (RubyValue)number)), call.Once })));
            RosterChanged();
        }
    }

    /// <summary>
    /// Gives the world's key items, and plays the world's story chests in the player's game.
    /// </summary>
    /// <param name="story">The player's story.</param>
    /// <param name="carried">Whether a story laid over theirs carried them past what is new.</param>
    /// <param name="done">The rows done.</param>
    private void WorldItems(StoryValues story, bool carried, RubyHash done)
    {
        StoryValues? told = _told;
        foreach (CatchupKeyItem row in _tables.KeyItems)
        {
            string key = KeyOf(row);
            if (Truthy(done[key]))
            {
                continue;
            }

            bool mine = Passed(row.Place, story);
            if (!mine && !(told is not null && Passed(row.Place, told, story)))
            {
                continue;
            }

            done[key] = true;
            if (_settings.TakesUsedUpKeyItems && row.Amount < 0 && row.Ran && (carried || !mine) && BeforeLog(row.Place))
            {
                Give("i", row.Item, row.Amount, key);
            }
        }

        foreach (CatchupChest row in _tables.Chests)
        {
            string key = KeyOf(row);
            if (Truthy(done[key]))
            {
                continue;
            }

            var opened = new StoryMark(row.Key);
            bool mine = story.Holds(opened);
            if (!mine && !(told is not null && told.Holds(opened)))
            {
                continue;
            }

            done[key] = true;
            if ((!carried && mine) || !(_log is null || _log.Holds(opened)) || (!_settings.ChestsPastOwnStep && !mine && PastStep(row, story)))
            {
                continue;
            }

            Act("replay", new RubyHash { { "chest", StoryPlain.Plain(row.Key) } }, key);
        }

        RestockKeyItems(story, told);
        if (_settings.UnlockItems)
        {
            RestockUnlockItems(story, told);
        }
    }

    /// <summary>
    /// Reports whether a story is past the step of a world chest, which a player whose own story got
    /// there without opening it keeps shut.
    /// </summary>
    /// <param name="row">The chest.</param>
    /// <param name="story">The story.</param>
    /// <returns>Whether it is; false for a chest of no known step.</returns>
    private bool PastStep(CatchupChest row, StoryValues story)
    {
        if (row.Step is not { } step)
        {
            return false;
        }

        int route = row.Part is null ? -1 : StoryParts.Routes.ToList().IndexOf(row.Part);
        var mark = new StoryMark(StoryKey.Variable(route < 0 ? StoryIds.MainProgress : StoryIds.RouteVariables[route]), step);
        return Passed(new StoryPlace(row.Key.ToString(), row.Part, step, null, [mark]), story);
    }

    /// <summary>
    /// Hands out every key item the story's place owes the player and they hold fewer of; in the
    /// Classic settings owes it once per row, for the scripts to hand over by the party chests that
    /// gave it first.
    /// </summary>
    /// <param name="story">The player's story.</param>
    /// <param name="told">The world's story.</param>
    private void RestockKeyItems(StoryValues story, StoryValues? told)
    {
        var owed = new List<(int Item, int Amount)>();
        RubyHash done = Done();
        foreach (CatchupKeyItem row in _tables.KeyItems)
        {
            if (row.Amount <= 0 || !BeforeLog(row.Place) || !PassedAny(row.Place, story, told) || TakenSince(row, story, story) || (told is not null && TakenSince(row, told, story)))
            {
                continue;
            }

            if (_settings.KeyItemsByPartyChests)
            {
                string mark = "o:" + KeyOf(row);
                if (Truthy(done[mark]))
                {
                    continue;
                }

                done[mark] = true;
            }

            int at = owed.FindIndex(entry => entry.Item == row.Item);
            if (at < 0)
            {
                owed.Add((row.Item, Math.Max(0, row.Amount)));
            }
            else
            {
                owed[at] = (row.Item, Math.Max(owed[at].Amount, row.Amount));
            }
        }

        foreach ((int item, int amount) in owed)
        {
            long missing = _items.TryGetValue("i" + item, out long count) ? amount - count : 0;
            if (missing <= 0)
            {
                continue;
            }

            if (_settings.KeyItemsByPartyChests)
            {
                _owed.Add((item, missing));
                _items["i" + item] = count + missing;
            }
            else
            {
                Give("i", item, missing, $"k:owed:{item}");
            }
        }
    }

    /// <summary>
    /// Reports whether a story took a key item after a row gave it, see <see cref="StoryRows.TakenSince"/>.
    /// </summary>
    /// <param name="row">The row that gives it.</param>
    /// <param name="told">The story.</param>
    /// <param name="story">The player's story.</param>
    /// <returns>Whether it did.</returns>
    private bool TakenSince(CatchupKeyItem row, StoryValues told, StoryValues story) => StoryRows.TakenSince(_tables, row, told, story, RowSide(), ChoiceKey);

    /// <summary>
    /// Hands out every item unlocking a job or race a reward row gives behind its own self switch.
    /// </summary>
    /// <param name="story">The player's story.</param>
    /// <param name="told">The world's story.</param>
    private void RestockUnlockItems(StoryValues story, StoryValues? told)
    {
        foreach (CatchupReward row in _tables.Rewards.Where(row => row.Kind == "item" && row.Ran && OwnSwitchMark(row.Place) && _unlockIds.Contains(row.Id)))
        {
            if (BeforeLog(row.Place) && PassedAny(row.Place, story, told) && _items.TryGetValue("i" + row.Id, out long count) && count == 0)
            {
                Give("i", row.Id, 1, KeyOf(row) + ":owed");
            }
        }
    }

    /// <summary>
    /// Reports whether a row's marks hold a self switch of its own map event.
    /// </summary>
    /// <param name="place">The row's place.</param>
    /// <returns>Whether they do.</returns>
    private static bool OwnSwitchMark(StoryPlace place)
    {
        string[] parts = place.Site.Split(':');
        if (parts.Length < 3 || parts[0] != "map")
        {
            return false;
        }

        int map = int.TryParse(parts[1], NumberStyles.None, CultureInfo.InvariantCulture, out int mapId) ? mapId : 0;
        int eventId = int.TryParse(parts[2], NumberStyles.None, CultureInfo.InvariantCulture, out int id) ? id : 0;
        return place.Marks.Any(mark => mark.Key.Kind == StoryKeyKind.SelfSwitch && mark.Key.Id == map && mark.Key.Event == eventId);
    }

    /// <summary>
    /// Gives once per save what notes of an earlier version noted done without giving, but an item an
    /// event of the game takes away, which the player may have given up as the story asked.
    /// </summary>
    /// <param name="story">The player's story.</param>
    private void RepairRewards(StoryValues story)
    {
        RubyHash notes = Ledger();
        if (Truthy(notes["rewards_repaired"]))
        {
            return;
        }

        notes["rewards_repaired"] = true;
        RubyHash done = notes["done"].AsHash();
        RubyHash waits = notes["waits"].AsHash();
        foreach (CatchupReward row in _tables.Rewards)
        {
            string key = KeyOf(row);
            string item = KindOf(row) + row.Id;
            if (row.Kind == "skill" || !Truthy(done[key]) || waits.ContainsKey(key) || !row.Ran || _tables.TakenItems.Contains(item) || !row.Place.Site.StartsWith("map:", StringComparison.Ordinal) || !BeforeLog(row.Place) || !Passed(row.Place, story))
            {
                continue;
            }

            if (!_items.ContainsKey(item) || (row.Kind == "item" && _unlockIds.Contains(row.Id)) || Held(item))
            {
                continue;
            }

            Give(KindOf(row), row.Id, row.Amount, key + ":repaired");
        }
    }

    /// <summary>
    /// Gives or takes what a row names, and counts it in the working copy.
    /// </summary>
    /// <param name="kind">"skill", "i", "w" or "a".</param>
    /// <param name="id">The skill or item.</param>
    /// <param name="amount">How many, below 0 to take.</param>
    /// <param name="key">The row, for the log.</param>
    /// <param name="gift">Whether it counts among the gifts the next tell lists.</param>
    private void Give(string kind, long id, long amount, string key, bool gift = true)
    {
        Act("give", kind, id, amount, key, gift);
        string item = kind + id;
        if (kind == "skill" || !_items.TryGetValue(item, out long count))
        {
            return;
        }

        if (amount < 0)
        {
            _items[item] = Math.Max(count + amount, 0);
            return;
        }

        _items[item] = count + amount;
        if (kind == "i" && IsMakina(id))
        {
            _own.SetSelfSwitch(StoryKey.SelfSwitch(FoundMap, (int)id, FoundLetter));
        }
    }

    /// <summary>
    /// Ends a tell of gifts: the scripts log what the gives since the last one gave.
    /// </summary>
    private void Gifts() => Act("gifts");

    /// <summary>
    /// Sets a variable of the player's story.
    /// </summary>
    /// <param name="id">The variable.</param>
    /// <param name="value">Its value.</param>
    private void SetVariable(int id, long value)
    {
        Act("set", id, value);
        _own.SetVariable(id, value);
    }

    /// <summary>
    /// Sets each count to the switches it counts.
    /// </summary>
    private void CheckCounts()
    {
        foreach (CatchupCount count in _tables.Counts)
        {
            if (count.SinceVariable is { } since && (_own.Variable(since) ?? 0) < count.SinceAtLeast)
            {
                continue;
            }

            long total = count.DoneSwitch is { } doneSwitch && _own.Switch(doneSwitch) ? count.DoneValue ?? 0 : count.Weights.Where(weight => _own.Switch(weight.Switch)).Sum(weight => (long)weight.Weight);
            long? now = _own.Variable(count.Variable);
            if (now == total)
            {
                continue;
            }

            Log($"set v{count.Variable} from {(now is { } value ? value.ToString(CultureInfo.InvariantCulture) : "nil")} to {total}, the switches it counts");
            SetVariable(count.Variable, total);
        }
    }


    /// <summary>
    /// Reports whether the player holds every orb before the story moved on to the step the orbs'
    /// event sets, as history from before the world's log: the world's log started past that step.
    /// Later, the replay of the run of the orbs' event carries the story on.
    /// </summary>
    /// <returns>Whether they do.</returns>
    private bool OrbsDue()
    {
        CatchupRules rules = _tables.Rules;
        if (rules.Orbs.Count == 0 || rules.OrbsGathered is not { } gathered || rules.OrbEvent is null || (_own.Variable(StoryIds.MainProgress) ?? 0) >= gathered
            || (_log is not null && (_log.Variable(StoryIds.MainProgress) ?? 0) < gathered))
        {
            return false;
        }

        return rules.Orbs.All(id => _items.TryGetValue("i" + id, out long count) && count > 0);
    }

    /// <summary>
    /// Follows the story's companions: the removals and joins passed, and the joins waiting for their
    /// gate.
    /// </summary>
    /// <param name="story">The player's story.</param>
    /// <param name="carried">Whether a story laid over theirs carried them past what is new.</param>
    /// <param name="done">The rows done.</param>
    private void Companions(StoryValues story, bool carried, RubyHash done)
    {
        var removed = new Dictionary<int, List<CatchupRemoval>>();
        var removedOrder = new List<int>();
        foreach (CatchupRemoval row in _tables.Removals)
        {
            string key = KeyOf(row);
            if (Truthy(done[key]) || !OnPlayedRoute(row.Place) || !Passed(row.Place, story))
            {
                continue;
            }

            done[key] = true;
            if (!removed.TryGetValue(row.Actor, out List<CatchupRemoval>? rows))
            {
                removed[row.Actor] = rows = [];
                removedOrder.Add(row.Actor);
            }

            rows.Add(row);
        }

        var fresh = new List<CatchupJoin>();
        foreach (CatchupJoin row in _tables.Index.StoryJoins)
        {
            string key = KeyOf("j", row);
            RubyValue state = done[key];
            if (state.IsNil)
            {
                if ((carried && !row.Ran) || !Passed(row.Place, story))
                {
                    continue;
                }

                if (row.Place.Part is null || (carried && !BeforeLog(row.Place)) || !Allowed(row.Actor)
                    || (!_settings.ChoiceCompanionsFromRows && ChoiceTable.ChoiceCompanions.Contains(row.Actor)))
                {
                    done[key] = true;
                    continue;
                }

                fresh.Add(row);
            }
            else if (!IsTrue(state) && removed.ContainsKey(row.Actor))
            {
                done[key] = true;
                Log($"dropped the waiting join of {{actor:{row.Persona}}} at {row.Place.Site}: the story took them away since");
            }
        }

        foreach (CatchupJoin row in fresh)
        {
            NoteJoin(row, carried, removed, done);
        }

        if (carried && _settings.TakesCompanionsAway)
        {
            TakeAway(removed, removedOrder, fresh);
        }

        BringWaiting(done);
    }

    /// <summary>
    /// Notes a join the player's story just got past: done when its companion is there or the
    /// player's own game left them out, else waiting for its gate; done when the same look passed a
    /// later removal.
    /// </summary>
    /// <param name="row">The join.</param>
    /// <param name="carried">Whether a story laid over theirs carried them past it.</param>
    /// <param name="removed">The removals passed in the same look, by companion.</param>
    /// <param name="done">The rows done.</param>
    private void NoteJoin(CatchupJoin row, bool carried, Dictionary<int, List<CatchupRemoval>> removed, RubyHash done)
    {
        string key = KeyOf("j", row);
        if (removed.TryGetValue(row.Actor, out List<CatchupRemoval>? rows) && rows.Any(removal => StoryRows.After(removal.Place, removal.Index, row.Place, row.Index)))
        {
            done[key] = true;
            return;
        }

        if (InRoster(row.Actor))
        {
            done[key] = _settings.LevelGates && carried && (row.Rule != StartRule || row.Actor != row.Persona) ? "c" : true;
        }
        else if (carried)
        {
            done[key] = "c";
        }
        else
        {
            done[key] = Ledger()["held"].AsHash().Remove(row.Actor) ? "o" : true;
        }
    }

    /// <summary>
    /// Takes away the companions a story carried the player past the lasting removal of, on a first
    /// playthrough, unless a join of the same look comes after each of those removals.
    /// </summary>
    /// <param name="removed">The removals passed, by companion.</param>
    /// <param name="order">The companions in the order their removals came.</param>
    /// <param name="fresh">The joins passed in the same look.</param>
    private void TakeAway(Dictionary<int, List<CatchupRemoval>> removed, List<int> order, List<CatchupJoin> fresh)
    {
        if ((_own.Variable(StoryIds.Playthrough) ?? 0) != 0)
        {
            return;
        }

        foreach (int actor in order)
        {
            CatchupRemoval[] lasting = [.. removed[actor].Where(row => row.First && BeforeLog(row.Place))];
            if (lasting.Length == 0 || actor == Hero || !InRoster(actor))
            {
                continue;
            }

            if (fresh.Any(row => row.Actor == actor && !lasting.Any(removal => StoryRows.After(removal.Place, removal.Index, row.Place, row.Index))))
            {
                continue;
            }

            Act("leave", actor, string.Join(", ", lasting.Select(row => row.Place.Site)));
            _roster.RemoveAll(entry => entry.Id == actor);
            RosterChanged();
        }
    }

    /// <summary>
    /// Lets the joins that wait for their gate in.
    /// </summary>
    /// <param name="done">The rows done.</param>
    private void BringWaiting(RubyHash done)
    {
        foreach (CatchupJoin row in _tables.Index.StoryJoins)
        {
            string key = KeyOf("j", row);
            RubyValue state = done[key];
            if (state.IsNil || IsTrue(state))
            {
                continue;
            }

            bool present = InRoster(row.Actor);
            if (present && state is RubyString { Text: "o" })
            {
                done[key] = true;
                continue;
            }

            if ((_settings.LevelGates && !Reached(row.Gate)) || !Allowed(row.Actor))
            {
                continue;
            }

            done[key] = true;
            int? level = row.Rule == StartRule || !_settings.LevelGates ? null : row.Gate;
            if (!present)
            {
                BringIn(row.Persona, row.Actor, level, $"level {row.Gate} reached");
                continue;
            }

            if (!FormChangedSince(row, done))
            {
                TakeForm(row);
            }

            RaiseLevel(row.Persona, row.Actor, level);
        }
    }

    /// <summary>
    /// Reports whether an actor change at a join's place or later already set the companion's
    /// persona, which the join's own persona would undo.
    /// </summary>
    /// <param name="join">The join.</param>
    /// <param name="done">The rows done.</param>
    /// <returns>Whether one did.</returns>
    internal bool FormChangedSince(CatchupJoin join, RubyHash done) =>
        _tables.ActorChanges.Any(change => change.Actor == join.Actor && IsTrue(done[KeyOf(change)])
            && StoryRows.PlaceOf(change.Place).CompareTo(StoryRows.PlaceOf(join.Place)) >= 0 && change.Calls.Any(call => call.Name == "persona_change"));

    /// <summary>
    /// Turns a companion of the roster into the persona a join of theirs brings.
    /// </summary>
    /// <param name="row">The join.</param>
    private void TakeForm(CatchupJoin row)
    {
        RosterEntry? entry = _roster.Find(candidate => candidate.Id == row.Actor);
        if (entry is null || row.Actor == row.Persona || entry.Persona == row.Persona)
        {
            return;
        }

        Act("form", row.Persona, row.Place.Site);
        entry.Persona = row.Persona;
    }

    /// <summary>
    /// Brings a companion into the roster, then raises their story values to what their join stands
    /// for.
    /// </summary>
    /// <param name="persona">The persona that joins.</param>
    /// <param name="main">The companion's main persona.</param>
    /// <param name="level">The level they come at least at, <see langword="null"/> for their own.</param>
    /// <param name="reason">Why, for the notice.</param>
    private void BringIn(int persona, int main, int? level, string reason)
    {
        if (InRoster(main))
        {
            return;
        }

        Act("join", persona, level is { } floor ? floor : RubyNil.Value, reason);
        _roster.Add(new RosterEntry(main, persona, level ?? 0, null));
        RosterChanged();
        if (_settings.SettlesValues)
        {
            CompanionValues();
        }
    }

    /// <summary>
    /// Raises a companion of the roster to a level.
    /// </summary>
    /// <param name="persona">The persona.</param>
    /// <param name="main">The companion's main persona.</param>
    /// <param name="level">The level, <see langword="null"/> for none.</param>
    private void RaiseLevel(int persona, int main, int? level)
    {
        if (level is not { } floor)
        {
            return;
        }

        Act("raise", persona, floor);
        if (_roster.Find(candidate => candidate.Id == main) is { } entry && entry.Level < floor)
        {
            entry.Level = floor;
        }
    }

    /// <summary>
    /// Reports whether the page that runs brings a companion along on a visit only.
    /// </summary>
    /// <param name="main">The companion's main persona.</param>
    /// <param name="site">The page, <see langword="null"/> while none runs.</param>
    /// <returns>Whether it does.</returns>
    private bool VisitRunning(int main, string? site) =>
        site is not null && _tables.Joins.Any(row => row.Actor == main && row.Place.Site == site && _tables.Index.TakingBack(row).Count > 0);

    /// <summary>
    /// Reports whether a companion is in the roster on a visit only: the story passed a temporary
    /// join of theirs and none of the removals that take them away again yet.
    /// </summary>
    /// <param name="id">The companion's main persona.</param>
    /// <param name="story">The player's story.</param>
    /// <returns>Whether they are.</returns>
    private bool Visiting(long id, StoryValues story) =>
        _tables.Index.VisitsOf((int)id).Any(row => Passed(row.Place, story) && !_tables.Index.TakingBack(row).Any(removal => Passed(removal.Place, story)));

    /// <summary>
    /// Lists the roster's companions the world's shared list takes, then lets the world's shared
    /// companions join.
    /// </summary>
    /// <returns>The companions the world takes.</returns>
    private List<long> NoteRoster()
    {
        long[] ids = [.. _roster.Select(entry => entry.Id).Where(id => !Visiting(id, _own))];
        if (_sharing == CompanionScope.NoSharing || _summary is null)
        {
            return [];
        }

        long[] shared = [.. Numbers(_summary["comps"])];
        List<long> sharable = [.. ids.Where(id => id != Hero && !shared.Contains(id) && _tables.Scope.Shares((int)id, _sharing))];
        ShareIn(shared);
        return sharable;
    }

    /// <summary>
    /// Lets the world's shared companions join at their gates.
    /// </summary>
    /// <param name="shared">The world's shared companions.</param>
    private void ShareIn(long[] shared)
    {
        RubyHash done = Done();
        HashSet<long>? lost = null;
        foreach (long id in shared)
        {
            string key = $"s:{id}";
            if (id == Hero || done[key] is RubyString { Text: ShareSettled })
            {
                continue;
            }

            lost ??= TakenForGood(done);
            if (InRoster(id) || lost.Contains(id) || Joined(id, done))
            {
                done[key] = ShareSettled;
                continue;
            }

            CatchupJoin? first = _tables.Index.JoinsOf((int)id).FirstOrDefault();
            if (!Allowed((int)id, CompanionPath.World))
            {
                continue;
            }

            long gate = first?.Gate ?? StartLevel(id);
            if (!Reached(gate))
            {
                continue;
            }

            done[key] = ShareSettled;
            BringIn(first?.Persona ?? (int)id, (int)id, first is not null && first.Rule != StartRule ? (int)gate : null, "shared by the world");
        }
    }

    /// <summary>
    /// Reports whether the player's story got past a join of the companion.
    /// </summary>
    /// <param name="id">The companion's main persona.</param>
    /// <param name="done">The rows done.</param>
    /// <returns>Whether it did.</returns>
    private bool Joined(long id, RubyHash done) => _tables.Index.JoinsOf((int)id).Any(row => row.Ran && IsTrue(done[KeyOf("j", row)]));

    /// <summary>
    /// Lists the companions the story took away for good: past a removal that lasts, on a first
    /// playthrough.
    /// </summary>
    /// <param name="done">The rows done.</param>
    /// <returns>The companions.</returns>
    private HashSet<long> TakenForGood(RubyHash done)
    {
        if ((_own.Variable(StoryIds.Playthrough) ?? 0) != 0)
        {
            return [];
        }

        return [.. _tables.Removals.Where(row => row.First && Truthy(done[KeyOf(row)])).Select(row => (long)row.Actor)];
    }

    /// <summary>
    /// Reads a companion's start level as the scripts told it.
    /// </summary>
    /// <param name="id">The companion.</param>
    /// <returns>The level, 1 for one not told.</returns>
    private long StartLevel(long id) => _starts.TryGetValue(id, out long level) ? level : 1;

    /// <summary>
    /// Plays the chest of every Makina found and reached that the player lacks in their own game.
    /// </summary>
    private void CheckMakina()
    {
        foreach (CatchupMakina row in _tables.Makina)
        {
            string key = "i" + row.Item;
            if (!_items.ContainsKey(key) || _items[key] != 0 || !Found(row.Item) || !Reached(row.Level))
            {
                continue;
            }

            Act("replay", new RubyHash { { "site", StoryPlain.SiteOf(row.Site) } }, $"makina:{row.Item} at level {row.Level}");
        }
    }

    /// <summary>
    /// Reports whether a player of the world found an item.
    /// </summary>
    /// <param name="id">The item.</param>
    /// <returns>Whether one did.</returns>
    private bool Found(long id) => _own.SelfSwitch(StoryKey.SelfSwitch(FoundMap, (int)id, FoundLetter));

    /// <summary>
    /// Reports whether an item is a Makina.
    /// </summary>
    /// <param name="id">The item.</param>
    /// <returns>Whether it is.</returns>
    private bool IsMakina(long id) => _tables.Makina.Any(row => row.Item == id);

    /// <summary>
    /// Plays in the player's game the recruit page of every story companion the roster lacks once
    /// their story finished a route, at the join's gate, once per companion, unless the world shares
    /// no companions.
    /// </summary>
    private void MissedCompanions()
    {
        if (!StoryParts.Routes.Any(_own.Cleared))
        {
            return;
        }

        RubyHash done = Done();
        foreach (CatchupJoin row in _tables.Index.StoryJoins)
        {
            string key = $"m:{row.Actor}";
            if (IsTrue(done[key]) || InRoster(row.Actor) || !StoryRows.PastByRoute(row.Place, _own, NotedSide()) || TakenAwaySince(row, _own, null) || !Reached(row.Gate) || !Allowed(row.Actor, CompanionPath.World))
            {
                continue;
            }

            done[key] = true;
            Act("replay", new RubyHash { { "site", StoryPlain.SiteOf(row.Place.Site) } }, key);
        }
    }

    /// <summary>
    /// Follows a story written into the player's: what their own game played before counts as theirs,
    /// then what the story carried them past gives what it gives.
    /// </summary>
    /// <param name="before">The player's story before.</param>
    private void Carried(StoryValues before)
    {
        if (_mode == "world")
        {
            DropCapped("the player plays the world's story already");
        }

        Review(before, false);
        Review(_own, true);
        if (_mode != "behind")
        {
            DropCapped("the story the move led to is laid over the player's");
        }
    }

    /// <summary>
    /// Lists moving on from the parts before the world's.
    /// </summary>
    /// <returns>The unlocks.</returns>
    private IEnumerable<RubyValue> StoryUnlocks()
    {
        if (_summary is not { } world)
        {
            return [];
        }

        List<string> order = WorldParts(world);
        string current = world["part"].IsNil ? "" : world["part"].AsText();
        string own = _own.Part;
        int ownAt = order.IndexOf(own);
        var unlocks = new List<RubyValue>();
        foreach (string id in order.TakeWhile(id => id != current).Where(id => !StoryParts.Routes.Contains(id) || id == own))
        {
            bool got = ownAt < 0 || ownAt > order.IndexOf(id);
            string into = NextPart(id, world);
            RubyValue gate = GateOf(id) is { } level ? level : RubyNil.Value;
            unlocks.Add(new RubyArray { gate, "story", RubyNil.Value, PartName(id), got, !got && GateOf(id) is { } open && GateOpen(open), GainsOf(id, into == StoryRows.WorldTrack ? current : into, id == own) });
        }

        return unlocks;
    }

    /// <summary>
    /// Lists what moving on from a part brings along.
    /// </summary>
    /// <param name="part">The part moved on from.</param>
    /// <param name="into">The part moved on to.</param>
    /// <param name="own">Whether it is the player's part.</param>
    /// <returns>[kind, id, amount] each, once.</returns>
    private RubyArray GainsOf(string part, string into, bool own)
    {
        StoryValues story = _own;
        StoryValues? told = _told;
        bool Carried(StoryPlace place, bool ran) => ran && told is not null
            && ((place.Part == into && Passed(place, told, story)) || (own && place.Part == part && Passed(place, told, story) && !Passed(place, story)));

        var gains = new List<(string Kind, long Id, long Amount)>();
        void Add(string kind, long id, long amount)
        {
            if (amount <= 0)
            {
                return;
            }

            int at = gains.FindIndex(gain => gain.Kind == kind && gain.Id == id);
            if (at < 0)
            {
                gains.Add((kind, id, amount));
            }
            else
            {
                gains[at] = (kind, id, gains[at].Amount + amount);
            }
        }

        foreach (CatchupKeyItem row in _tables.KeyItems.Where(row => Carried(row.Place, row.Ran)))
        {
            Add("i", row.Item, row.Amount);
        }

        foreach (CatchupReward row in _tables.Rewards.Where(row => Carried(row.Place, row.Ran)))
        {
            Add(KindOf(row), row.Id, row.Amount);
        }

        return new RubyArray(gains.Select(gain => (RubyValue)new RubyArray { gain.Kind, gain.Id, gain.Amount }));
    }

    /// <summary>
    /// Lists the companions the catch-up brings at their gate.
    /// </summary>
    /// <param name="story">The player's story.</param>
    /// <param name="told">The world's story.</param>
    /// <returns>The unlocks.</returns>
    private IEnumerable<RubyValue> CompanionUnlocks(StoryValues story, StoryValues? told)
    {
        var gates = new List<(long Id, long Gate)>();
        void Lower(long id, long gate)
        {
            int at = gates.FindIndex(entry => entry.Id == id);
            if (at < 0)
            {
                gates.Add((id, gate));
            }
            else
            {
                gates[at] = (id, Math.Min(gates[at].Gate, gate));
            }
        }

        if (told is not null)
        {
            foreach (CatchupJoin row in _tables.Index.StoryJoins.Where(row => row.Place.Part is not null && row.Ran && Passed(row.Place, told, story) && !TakenAwaySince(row, story, told) && Allowed(row.Actor)))
            {
                Lower(row.Actor, row.Gate);
            }
        }

        if (_sharing != "off" && _summary is { } world)
        {
            RubyHash done = Done();
            HashSet<long> lost = TakenForGood(done);
            foreach (long id in Numbers(world["comps"]))
            {
                if (!InRoster(id) && (done[$"s:{id}"] is RubyString { Text: ShareSettled } || lost.Contains(id) || Joined(id, done) || !Allowed((int)id)))
                {
                    continue;
                }

                CatchupJoin? first = _tables.Index.JoinsOf((int)id).FirstOrDefault();
                long? gate = first is not null ? first.Gate : _sharing == "all" ? StartLevel(id) : null;
                if (gate is { } level && id != Hero)
                {
                    Lower(id, level);
                }
            }
        }

        return gates.Select(entry =>
        {
            bool got = InRoster(entry.Id);
            return (RubyValue)new RubyArray { entry.Gate, "companion", entry.Id, RubyNil.Value, got, !got && Reached(entry.Gate), new RubyArray() };
        }).ToList();
    }

    /// <summary>
    /// Lists every Makina a player of the world got.
    /// </summary>
    /// <returns>The unlocks.</returns>
    private IEnumerable<RubyValue> MakinaUnlocks() =>
        _tables.Makina.Where(row => _items.ContainsKey("i" + row.Item) && Found(row.Item)).Select(row =>
        {
            bool got = _items["i" + row.Item] > 0;
            return (RubyValue)new RubyArray { row.Level, "makina", row.Item, RubyNil.Value, got, !got && Reached(row.Level), new RubyArray() };
        }).ToList();

    /// <summary>
    /// A companion of the roster as the snapshot names them and the actions change them.
    /// </summary>
    /// <param name="id">The companion's id in the roster, their main persona.</param>
    /// <param name="persona">The persona they are in.</param>
    /// <param name="level">Their base level.</param>
    /// <param name="cap">The highest level the game lets them reach, <see langword="null"/> for none.</param>
    private sealed class RosterEntry(long id, long persona, long level, long? cap)
    {
        /// <summary>
        /// Gets the companion's id in the roster.
        /// </summary>
        public long Id { get; } = id;

        /// <summary>
        /// Gets or sets the persona they are in.
        /// </summary>
        public long Persona { get; set; } = persona;

        /// <summary>
        /// Gets or sets their base level.
        /// </summary>
        public long Level { get; set; } = level;

        /// <summary>
        /// Gets the highest level the game lets them reach.
        /// </summary>
        public long? Cap { get; } = cap;

        /// <summary>
        /// Reads a companion of the snapshot's roster.
        /// </summary>
        /// <param name="value">[id, persona, base level, cap].</param>
        /// <returns>The companion.</returns>
        /// <exception cref="BridgeRequestException">The entry is no such list.</exception>
        public static RosterEntry Of(RubyValue value)
        {
            RubyArray entry = value.AsArray();
            if (entry.Count != 4)
            {
                throw new BridgeRequestException("A companion of the roster is [id, persona, base level, cap].");
            }

            return new RosterEntry(entry[0].AsLong(), entry[1].AsLong(), entry[2].AsLong(), entry[3].IsNil ? null : entry[3].AsLong());
        }
    }

    /// <summary>
    /// The roster as one look reads it.
    /// </summary>
    /// <param name="Ids">The companions in the roster.</param>
    /// <param name="Best">The highest base level among those not on a visit, <see langword="null"/> for none.</param>
    /// <param name="Cap">That character's cap, <see langword="null"/> for none.</param>
    private sealed record RosterView(HashSet<long> Ids, long? Best, long? Cap);
}
