//----------------------------------------------------------------
//  CatchupLook.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Created
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
/// job or race), "map", "encounters", "summary" (the world's summary),
/// "sharing" and "starts" ([companion, start level] each).
/// </remarks>
internal sealed class CatchupLook
{
    /// <summary>
    /// Luka, who never joins nor leaves.
    /// </summary>
    public const int Hero = 1;

    /// <summary>
    /// The variable that counts the playthroughs, at 0 on the first, which alone loses companions for
    /// good.
    /// </summary>
    public const int Playthrough = 912;

    /// <summary>
    /// The switch that bans warping.
    /// </summary>
    public const int WarpBan = 100;

    /// <summary>
    /// The main story's step right before the Great Decision.
    /// </summary>
    private const long BeforeDecision = 39;

    /// <summary>
    /// What the notes keep for a companion the world shares once it joined or never will.
    /// </summary>
    private const string ShareSettled = "settled";

    /// <summary>
    /// The rule of a join whose gate is the companion's start level.
    /// </summary>
    private const string StartRule = "start";

    /// <summary>
    /// The map and letter of the self switches that tell which items a player of the world found.
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
    /// The parts before the Great Decision, whose sides the player chose themselves.
    /// </summary>
    private static readonly string[] SidedParts = ["1", "2", "3"];

    /// <summary>
    /// The engine, which holds the save's notes.
    /// </summary>
    private readonly CatchupEngine _engine;

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
    /// The player's story, which the actions change.
    /// </summary>
    private readonly StoryValues _own;

    /// <summary>
    /// The world's story last written into the player's, <see langword="null"/> for none.
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
    /// The map the player stands on.
    /// </summary>
    private readonly long _map;

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
    /// The actions answered so far.
    /// </summary>
    private readonly RubyArray _actions = [];

    /// <summary>
    /// The roster read for this look, kept until the roster changes; <see langword="null"/> before.
    /// </summary>
    private RosterView? _rosterView;

    /// <summary>
    /// Starts a call.
    /// </summary>
    /// <param name="engine">The engine.</param>
    /// <param name="tables">The tables.</param>
    /// <param name="request">The request.</param>
    public CatchupLook(CatchupEngine engine, CatchupTables tables, RubyHash request)
    {
        _engine = engine;
        _tables = tables;
        _request = request;
        if (request.TryGetValue("ledger", out RubyValue? handed))
        {
            engine.Ledger = handed;
        }

        _before = RubyMarshal.Write(engine.Ledger);
        _worldId = request["world"].IsNil ? "" : request["world"].AsText();
        _mode = request["mode"].IsNil ? null : request["mode"].AsText();
        _own = StoryOf(request["own"]) ?? new StoryValues([], [], []);
        _told = StoryOf(request["told"]);
        _roster = request["roster"].IsNil ? [] : [.. request["roster"].AsArray().Select(RosterEntry.Of)];
        if (!request["items"].IsNil)
        {
            foreach ((RubyValue key, RubyValue count) in request["items"].AsHash())
            {
                _items[key.AsText()] = count.AsLong();
            }
        }

        _worn.UnionWith(Texts(request["worn"]));
        _unlockIds.UnionWith(Numbers(request["unlocks"]));
        PersonalChoiceKeys choices = StoryChoices.Personal(true, null);
        _choiceSwitches.UnionWith(choices.Switches);
        _choiceVariables.UnionWith(choices.Variables);

        _map = request["map"].IsNil ? 0 : request["map"].AsLong();
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
        if (_request["look"] is RubyString { Text: "carried" })
        {
            Carried(StoryOf(_request["before"]) ?? new StoryValues([], [], []));
        }
        else
        {
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
            CheckFoundItems();
            CheckCounts();
            LiftWarpBan();
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
        string? site = _request["site"].IsNil ? null : _request["site"].AsText();
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
    private static StoryValues? StoryOf(RubyValue value)
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
    private bool Passed(StoryPlace place, StoryValues story, StoryValues own) => StoryRows.Passed(place, story, own, NotedSide(), ChoiceKey);

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
    private static string KeyOf(CatchupChest row) => $"c:{row.Key.Id}.{row.Key.Event}.{row.Key.Letter}";

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
    /// Reports whether the player's story went past the choice of a side without one, before the
    /// Great Decision.
    /// </summary>
    /// <returns>Whether it did.</returns>
    private bool LostSide()
    {
        if (_tables.Rules.SideStep is not { } step)
        {
            return false;
        }

        long progress = _own.Variable(StoryValues.MainProgress) ?? 0;
        return _own.Side is null && Array.IndexOf(SidedParts, _own.Part) >= 0 && progress >= step && progress <= BeforeDecision;
    }

    /// <summary>
    /// Notes the side the player chose before the Great Decision, which the route sets anew.
    /// </summary>
    /// <param name="story">The player's story.</param>
    private void NoteSide(StoryValues story)
    {
        if (story.Side is { } side && Array.IndexOf(SidedParts, story.Part) >= 0)
        {
            Ledger()["side"] = side;
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
            if (!Truthy(waits[key]) && PassedAny(row.Place, story, told))
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
    private void MissingLessons(StoryValues story, StoryValues? told)
    {
        foreach (CatchupLesson row in _tables.Lessons.Where(row => row.Ran && InRoster(row.Actor) && PassedAny(row.Place, story, told)))
        {
            Act("teach", row.Actor, row.Skill);
        }
    }

    /// <summary>
    /// Gives the roster's characters the classes and races the story gave them.
    /// </summary>
    /// <param name="story">The player's story.</param>
    /// <param name="told">The world's story while the player plays it.</param>
    private void MissingClassLevels(StoryValues story, StoryValues? told)
    {
        foreach (CatchupClassLevel row in _tables.ClassLevels.Where(row => row.Ran && (row.Actor == Hero || InRoster(row.Actor)) && PassedAny(row.Place, story, told)))
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
            if (!IsTrue(done[key]) || row.Place.Part is null || !row.Ran || InRoster(row.Actor) || !PassedAny(row.Place, story, told) || TakenAwaySince(row, story, told))
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
        _tables.Removals.Any(removal => removal.Actor == row.Actor && StoryRows.After(removal.Place, removal.Index, row.Place, row.Index) && PassedAny(removal.Place, story, told));

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
    /// step set: the latest step passed sets them, which the scripts apply where they may.
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
            if ((row.Place.Part is { } rowPart && StoryParts.Routes.Contains(rowPart) && rowPart != part) || !PassedAny(row.Place, story, told))
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
            RubyValue now = row.Kind == "encounters" ? _encounters : _own.Variable(row.Id) is { } number ? number : RubyNil.Value;
            if (now.Equals(ValueOf(row)) || !earlier.TryGetValue(key, out List<RubyValue>? values) || !values.Any(value => value.Equals(now)))
            {
                continue;
            }

            Act("setting", row.Kind == "encounters" ? "encounters" : row.Kind == "variable" ? "v" : "s", row.Id, ValueOf(row), row.Place.Site);
        }
    }

    /// <summary>
    /// Reads the value a setting row sets.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>A variable's number, else whether the switch or the encounters are on.</returns>
    private static RubyValue ValueOf(CatchupSetting row) => row.Kind == "variable" ? row.Number : row.On;

    /// <summary>
    /// Finds which vehicles a row behind the player's story or the world's gave.
    /// </summary>
    /// <param name="story">The player's story.</param>
    /// <param name="told">The world's story while the player plays it.</param>
    private void CheckVehicles(StoryValues story, StoryValues? told)
    {
        var given = new RubyArray();
        foreach (string vehicle in (string[])["boat", "ship", "airship"])
        {
            given.Add(_tables.Vehicles.Any(row => row.Vehicle == vehicle && PassedAny(row.Place, story, told)));
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
            if (Truthy(done[key]) || (carried && !row.Ran) || !Passed(row.Place, story))
            {
                continue;
            }

            done[key] = true;
            if (!carried && !UnclaimedPrize(row))
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
        ActorChanges(story, carried, done);
        if (carried)
        {
            Settle(story, PlayedWorldStory);
        }

        Gifts();
    }

    /// <summary>
    /// Reports whether a prize row the player's story passed is another player's claim: the player
    /// holds none of it.
    /// </summary>
    /// <param name="row">The row.</param>
    /// <returns>Whether it is.</returns>
    private bool UnclaimedPrize(CatchupReward row)
    {
        if (row.Kind == "skill" || !row.Place.Marks.Any(mark => mark.Key.Kind == StoryKeyKind.Variable && _tables.PrizeVariables.Contains(mark.Key.Id)))
        {
            return false;
        }

        string item = KindOf(row) + row.Id;
        return _items.ContainsKey(item) && !Held(item);
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

            done[key] = carried ? Math.Max(row.Gate ?? 0, capped) : true;
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
    /// Gives the world's key items and the items of its story chests.
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
            if (row.Amount < 0 && row.Ran && (carried || !mine))
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

            bool mine = story.SelfSwitch(row.Key);
            if (!mine && !(told is not null && told.SelfSwitch(row.Key)))
            {
                continue;
            }

            done[key] = true;
            if (!carried && mine)
            {
                continue;
            }

            foreach (int item in row.Items)
            {
                Give("i", item, 1, key);
            }

            TurnOnFlags(row, key);
            if (!mine)
            {
                Act("open", SelfSwitchOf(row.Key));
                _own.SetSelfSwitch(row.Key);
            }
        }

        RestockKeyItems(story, told);
        RestockUnlockItems(story, told);
    }

    /// <summary>
    /// Hands out every key item the story's place owes the player and they hold fewer of.
    /// </summary>
    /// <param name="story">The player's story.</param>
    /// <param name="told">The world's story.</param>
    private void RestockKeyItems(StoryValues story, StoryValues? told)
    {
        var owed = new List<(int Item, int Amount)>();
        foreach (CatchupKeyItem row in _tables.KeyItems)
        {
            if (row.Amount <= 0 || !PassedAny(row.Place, story, told) || TakenSince(row, story, story) || (told is not null && TakenSince(row, told, story)))
            {
                continue;
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
            if (missing > 0)
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
    private bool TakenSince(CatchupKeyItem row, StoryValues told, StoryValues story) => StoryRows.TakenSince(_tables, row, told, story, NotedSide(), ChoiceKey);

    /// <summary>
    /// Hands out every item unlocking a job or race a reward row gives behind its own self switch.
    /// </summary>
    /// <param name="story">The player's story.</param>
    /// <param name="told">The world's story.</param>
    private void RestockUnlockItems(StoryValues story, StoryValues? told)
    {
        foreach (CatchupReward row in _tables.Rewards.Where(row => row.Kind == "item" && row.Ran && OwnSwitchMark(row.Place) && _unlockIds.Contains(row.Id)))
        {
            if (PassedAny(row.Place, story, told) && _items.TryGetValue("i" + row.Id, out long count) && count == 0)
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
    /// Gives once per save what notes of an earlier version noted done without giving.
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
            if (row.Kind == "skill" || !Truthy(done[key]) || waits.ContainsKey(key) || !row.Ran || item == "w4112" || !row.Place.Site.StartsWith("map:", StringComparison.Ordinal) || !Passed(row.Place, story))
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
        if (kind == "i" && (_unlockIds.Contains(id) || IsMakina(id)))
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
    /// Turns on the chest flags a world-wide chest turns on.
    /// </summary>
    /// <param name="row">The chest.</param>
    /// <param name="key">Its row, for the log.</param>
    private void TurnOnFlags(CatchupChest row, string key)
    {
        foreach (int id in row.Flags.Where(id => !_own.Switch(id)))
        {
            Act("switch", id, true);
            _own.SetSwitch(id, true);
            Log($"turned on s{id} of {key}");
        }
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
    /// Lifts the warp ban left on where warping is free.
    /// </summary>
    private void LiftWarpBan()
    {
        if (!_own.Switch(WarpBan) || !_tables.WarpFreeMaps.Contains((int)_map))
        {
            return;
        }

        Act("switch", WarpBan, false);
        _own.SetSwitch(WarpBan, false);
        Log($"lifted the warp ban: map {_map} lets the player warp");
    }

    /// <summary>
    /// Reports whether the player holds every orb before the story moved on to the step the orbs'
    /// event sets.
    /// </summary>
    /// <returns>Whether they do.</returns>
    private bool OrbsDue()
    {
        CatchupRules rules = _tables.Rules;
        if (rules.Orbs.Count == 0 || rules.OrbsGathered is not { } gathered || rules.OrbEvent is null || (_own.Variable(StoryValues.MainProgress) ?? 0) >= gathered)
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
            if (Truthy(done[key]) || !Passed(row.Place, story))
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

                if (row.Place.Part is null)
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

        if (carried)
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
            done[key] = carried && (row.Rule != StartRule || row.Actor != row.Persona) ? "c" : true;
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
        if ((_own.Variable(Playthrough) ?? 0) != 0)
        {
            return;
        }

        foreach (int actor in order)
        {
            CatchupRemoval[] lasting = [.. removed[actor].Where(row => row.First)];
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

            if (!Reached(row.Gate))
            {
                continue;
            }

            done[key] = true;
            int? level = row.Rule == StartRule ? null : row.Gate;
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
        CompanionValues();
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
        if (_sharing == "off" || _summary is null)
        {
            return [];
        }

        long[] shared = [.. Numbers(_summary["comps"])];
        List<long> sharable = [.. ids.Where(id => id != Hero && !shared.Contains(id) && (_sharing == "all" || _tables.Index.JoinsOf((int)id).Count > 0))];
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
            if (first is null && _sharing != "all")
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
        if ((_own.Variable(Playthrough) ?? 0) != 0)
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
    /// Hands out every Makina found and reached, and takes back extra copies.
    /// </summary>
    private void CheckMakina()
    {
        foreach (CatchupMakina row in _tables.Makina)
        {
            string key = "i" + row.Item;
            if (!_items.ContainsKey(key) || TrimCopies(row.Item) || _items[key] != 0 || !Found(row.Item) || !Reached(row.Level))
            {
                continue;
            }

            Act("makina", row.Item, $"makina:{row.Item} at level {row.Level}");
            _items[key] += 1;
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
    /// Takes back every copy of an item beyond the first.
    /// </summary>
    /// <param name="id">The item.</param>
    /// <returns>Whether there were more.</returns>
    private bool TrimCopies(long id)
    {
        string key = "i" + id;
        long held = _items[key];
        if (held <= 1)
        {
            return false;
        }

        Act("trim", id, held - 1);
        _items[key] = 1;
        return true;
    }

    /// <summary>
    /// Hands out every found item unlocking a job or race the player lacks.
    /// </summary>
    private void CheckFoundItems()
    {
        foreach (long id in FoundIds())
        {
            string key = "i" + id;
            if (!_items.ContainsKey(key) || IsMakina(id) || TrimCopies(id) || _items[key] != 0)
            {
                continue;
            }

            Give("i", id, 1, $"found:{id}", false);
        }
    }

    /// <summary>
    /// Lists the items found in the player's story and the world's.
    /// </summary>
    /// <returns>The items, each once.</returns>
    private IEnumerable<long> FoundIds()
    {
        IEnumerable<StoryKey> keys = _own.SelfSwitchesOn;
        if (_told is not null)
        {
            keys = keys.Concat(_told.SelfSwitchesOn);
        }

        return keys.Where(key => key.Id == FoundMap && key.Letter == FoundLetter).Select(key => (long)key.Event).Distinct().ToList();
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
            foreach (CatchupJoin row in _tables.Index.StoryJoins.Where(row => row.Place.Part is not null && row.Ran && Passed(row.Place, told, story) && !TakenAwaySince(row, story, told)))
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
                if (!InRoster(id) && (done[$"s:{id}"] is RubyString { Text: ShareSettled } || lost.Contains(id) || Joined(id, done)))
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
