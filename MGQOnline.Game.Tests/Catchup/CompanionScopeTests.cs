//----------------------------------------------------------------
//  CompanionScopeTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Handed the companion filter the story played in place of the routes
//      Paulinchen  2026-11-01: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Catchup;
using MGQOnline.Game.Story;

namespace MGQOnline.Game.Tests.Catchup;

/// <summary>
/// Covers the companions of the Alice and Ilias choice over the generated tables: a player gets
/// only those of the side they took along in Iliasville and of the routes they played, on every
/// path the catch-up hands one out, and loses one they never had a right to.
/// </summary>
public sealed class CompanionScopeTests
{
    /// <summary>
    /// Alice.
    /// </summary>
    private const int Alice = 5;

    /// <summary>
    /// Ilias.
    /// </summary>
    private const int Ilias = 26;

    /// <summary>
    /// Micaela-chan, whom the Hall of Creation gives Ilias's side.
    /// </summary>
    private const int MicaelaChan = 34;

    /// <summary>
    /// Alicetroemeria, whom the Great Decision gives everyone who enters the Angelic Dominion.
    /// </summary>
    private const int Alicetroemeria = 45;

    /// <summary>
    /// Morrigan, whom the Great Decision gives everyone who enters the Angelic Dominion.
    /// </summary>
    private const int Morrigan = 382;

    /// <summary>
    /// Heinrich, whom the Great Decision gives the players who took Alice along.
    /// </summary>
    private const int Heinrich = 538;

    /// <summary>
    /// The companions the Great Decision gives a player who took Alice along on the Monster Realm.
    /// </summary>
    private static readonly int[] IliasSide = [Ilias, MicaelaChan, 36, 383, Heinrich];

    /// <summary>
    /// The four Doppel Lukas, whom Lucifina's house gives everyone on the Angelic Dominion.
    /// </summary>
    private static readonly int[] DoppelLukas = [506, 507, 508, 509];

    /// <summary>
    /// The tables of the generated data and the rules.
    /// </summary>
    private static readonly CatchupTables Tables = ReadTables();

    /// <summary>
    /// Asserts that a story laid over an Alice picker's carries them past both Iliasville choices but
    /// brings Alice alone.
    /// </summary>
    [Fact]
    public void Carried_AlicePickerGetsAliceAndNeverIlias()
    {
        RubyHash request = Request(Story([4], (1001, 22)), Roster((1, 30)));
        request["look"] = "carried";
        request["before"] = Story([], (1001, 5));

        RubyArray actions = new CatchupEngine().Check(Tables, request)["actions"].AsArray();

        Assert.Contains(Alice, Joined(actions));
        Assert.DoesNotContain(Ilias, Joined(actions));
    }

    /// <summary>
    /// Asserts that the roster check never brings Ilias to an Alice picker whose notes hold Ilias's
    /// Iliasville join done, as a save of the released version does.
    /// </summary>
    [Fact]
    public void Audit_AlicePickerNeverGetsIlias()
    {
        RubyHash request = Request(Story([4], (1001, 22)), Roster((1, 30), (Alice, 30)));
        request["audit"] = true;
        var engine = new CatchupEngine { Ledger = Notes("alice", new RubyHash { { "j:map:6:31:2:26", true }, { "j:map:6:30:2:5", true } }) };

        Assert.DoesNotContain(Ilias, Joined(engine.Check(Tables, request)["actions"].AsArray()));
    }

    /// <summary>
    /// Asserts that an Alice picker on the Angelic Dominion of a world that finished the Monster
    /// Realm gets no replay of Ilias's Monster Realm join, whose route they never played.
    /// </summary>
    [Fact]
    public void MissedCompanions_AlicePickerNeverGetsIliasOfARouteTheyNeverPlayed()
    {
        RubyHash request = Request(Story([4, 7097], (1001, 40), (1141, 5)), Roster((1, 100), (Alice, 100)));
        request["sharing"] = "story";

        RubyArray actions = new CatchupEngine { Ledger = Notes("alice") }.Check(Tables, request)["actions"].AsArray();

        Assert.DoesNotContain(actions, action => action.AsArray()[0].AsText() == "replay" && action.AsArray()[2].AsText() == "m:26");
    }

    /// <summary>
    /// Asserts that a world that shares its companions never shares Ilias with an Alice picker.
    /// </summary>
    [Fact]
    public void Sharing_AlicePickerNeverGetsIlias()
    {
        RubyHash request = Request(Story([4], (1001, 22)), Roster((1, 30), (Alice, 30)));
        request["sharing"] = "story";
        request["summary"] = new RubyHash { { "comps", new RubyArray { Ilias } } };

        Assert.DoesNotContain(Ilias, Joined(new CatchupEngine { Ledger = Notes("alice") }.Check(Tables, request)["actions"].AsArray()));
    }

    /// <summary>
    /// Asserts that an event of the other side, a replay's or one a shared story value opened, joins
    /// no one, while the player's own choice in Iliasville brings their companion.
    /// </summary>
    [Fact]
    public void HoldJoin_LeavesOutTheOtherSidesJoinButNotThePick()
    {
        RubyHash Ask(int actor, string site, string? side)
        {
            RubyHash request = Request(Story(side is null ? [] : [4], (1001, 22)), Roster((1, 30)));
            request["actor"] = actor;
            request["site"] = site;
            request["scope_only"] = true;
            return new CatchupEngine { Ledger = Notes(side) }.HoldJoin(Tables, request);
        }

        Assert.True(Ask(Ilias, "map:6:31:2", "alice")["refused"] is RubyBool { Flag: true });
        Assert.True(Ask(MicaelaChan, "map:297:13:3", "alice")["refused"] is RubyBool { Flag: true });
        Assert.True(Ask(Alice, "map:6:30:2", null)["refused"].IsNil);
    }

    /// <summary>
    /// Asserts that a player who holds the other side's companion loses them, and keeps their own.
    /// </summary>
    [Fact]
    public void Audit_TakesTheOtherSidesCompanionAway()
    {
        RubyHash request = Request(Story([4], (1001, 22)), Roster((1, 30), (Alice, 30), (Ilias, 30)));
        request["audit"] = true;

        RubyArray actions = new CatchupEngine { Ledger = Notes("alice") }.Check(Tables, request)["actions"].AsArray();

        Assert.Equal(new List<long> { Ilias }, Dismissed(actions));
    }

    /// <summary>
    /// Asserts that an Ilias picker on the Monster Realm keeps Ilias, and that an Alice picker who got
    /// her on the Monster Realm keeps her on the Angelic Dominion after it.
    /// </summary>
    [Fact]
    public void Audit_KeepsIliasOnTheMonsterRealmAndAfterIt()
    {
        RubyHash onRealm = Request(Story([5], (1001, 40), (1142, 5)), Roster((1, 80), (Ilias, 80)));
        onRealm["audit"] = true;
        RubyHash afterRealm = Request(Story([4], (1001, 40), (1141, 5)), Roster((1, 80), (Alice, 80), (Ilias, 80)));
        afterRealm["audit"] = true;
        RubyHash notes = Notes("alice");
        notes["routes"] = new RubyArray { "mr" };

        Assert.Empty(Dismissed(new CatchupEngine { Ledger = Notes("ilias") }.Check(Tables, onRealm)["actions"].AsArray()));
        Assert.Empty(Dismissed(new CatchupEngine { Ledger = notes }.Check(Tables, afterRealm)["actions"].AsArray()));
    }

    /// <summary>
    /// Asserts that a story laid over an Ilias picker's that enters the Angelic Dominion takes Ilias
    /// away, as the Great Decision does for everyone who sides with the Dark Goddess.
    /// </summary>
    [Fact]
    public void Carried_AngelicDominionTakesIliasAway()
    {
        RubyHash request = Request(Story([5], (1001, 40), (1141, 1)), Roster((1, 70), (Ilias, 70)));
        request["look"] = "carried";
        request["before"] = Story([5], (1001, 39));

        RubyArray actions = new CatchupEngine { Ledger = Notes("ilias") }.Check(Tables, request)["actions"].AsArray();

        Assert.Contains(actions, action => action.AsArray()[0].AsText() == "leave" && action.AsArray()[1].AsLong() == Ilias);
    }

    /// <summary>
    /// Asserts that an Alice picker a story carries into the Angelic Dominion of a world that finished
    /// the Monster Realm keeps Alice, Alicetroemeria and Morrigan, whom only the Monster Realm, a
    /// route they never played, takes away at the Great Decision.
    /// </summary>
    [Fact]
    public void Carried_AngelicDominionAfterTheWorldsMonsterRealmKeepsAlice()
    {
        RubyHash request = Request(Story([4, 7097], (1001, 40), (1141, 1)), Roster((1, 70), (Alice, 70), (Alicetroemeria, 70), (Morrigan, 70)));
        request["look"] = "carried";
        request["before"] = Story([4], (1001, 39));

        RubyArray actions = new CatchupEngine { Ledger = Notes("alice") }.Check(Tables, request)["actions"].AsArray();

        Assert.DoesNotContain(actions, action => action.AsArray()[0].AsText() == "leave" && action.AsArray()[1].AsLong() is Alice or Alicetroemeria or Morrigan);
    }

    /// <summary>
    /// Asserts that an Ilias picker gets Heinrich neither from the Great Decision on the Monster Realm
    /// nor from the Chaos route's strategy conference, where the game gives him only to the players who
    /// took Alice along.
    /// </summary>
    [Fact]
    public void Carried_IliasPickerNeverGetsHeinrichAtTheGreatDecision()
    {
        RubyArray Carry(RubyHash story)
        {
            RubyHash request = Request(story, Roster((1, 130), (Ilias, 130)));
            request["look"] = "carried";
            request["before"] = Story([5], (1001, 39));
            return new CatchupEngine { Ledger = Notes("ilias") }.Check(Tables, request)["actions"].AsArray();
        }

        Assert.DoesNotContain(Heinrich, Joined(Carry(Story([5], (1001, 40), (1142, 1)))));
        Assert.DoesNotContain(Heinrich, Joined(Carry(Story([5, 5091, 7089], (1001, 40), (1143, 1)))));
    }

    /// <summary>
    /// Asserts that an Alice picker a story carries through the Great Decision onto the Monster
    /// Realm, where the route turned switch 5 on, gets Ilias's side and loses Alice, Alicetroemeria
    /// and Morrigan, as the game does.
    /// </summary>
    [Fact]
    public void Carried_AlicePickerOnTheMonsterRealmSwapsSides()
    {
        RubyHash request = Request(Story([5], (1001, 40), (1142, 1)), Roster((1, 80), (Alice, 80), (Alicetroemeria, 80), (Morrigan, 80)));
        request["look"] = "carried";
        request["before"] = Story([4], (1001, 39));

        RubyArray actions = new CatchupEngine { Ledger = Notes("alice") }.Check(Tables, request)["actions"].AsArray();
        List<long> left = [.. actions.Select(action => action.AsArray()).Where(action => action[0].AsText() == "leave").Select(action => action[1].AsLong())];

        Assert.All(IliasSide, actor => Assert.Contains(actor, Joined(actions)));
        Assert.Equal(new List<long> { Alice, Alicetroemeria, Morrigan }, left.Order().ToList());
    }

    /// <summary>
    /// Asserts that the Doppel Lukas join an Ilias picker carried past Lucifina's house on the Angelic
    /// Dominion, whose side switch there tells the route.
    /// </summary>
    [Fact]
    public void Carried_DoppelLukasJoinAnIliasPickerOnTheAngelicDominion()
    {
        RubyHash request = Request(Story([5], (1001, 40), (1141, 68)), Roster((1, 110)));
        request["look"] = "carried";
        request["before"] = Story([5], (1001, 40), (1141, 60));

        RubyArray actions = new CatchupEngine { Ledger = Notes("ilias") }.Check(Tables, request)["actions"].AsArray();

        Assert.All(DoppelLukas, actor => Assert.Contains(actor, Joined(actions)));
    }

    /// <summary>
    /// Asserts that a player whose save came past Iliasville from another player's starting save,
    /// whose side is that player's, is asked whom they take along, also on a route, and that an
    /// answer becomes their side.
    /// </summary>
    [Fact]
    public void StartingSave_PastIliasvilleAsksForASide()
    {
        var engine = new CatchupEngine();
        RubyHash partTwo = engine.Check(Tables, OtherStart(Request(Story([4], (1001, 22)), Roster((1, 30), (Alice, 30)))));
        RubyHash route = new CatchupEngine().Check(Tables, OtherStart(Request(Story([4], (1001, 40), (1141, 10)), Roster((1, 80)))));
        engine.Note(Tables, new RubyHash { { "world", "w1" }, { "side", "ilias" } });

        Assert.True(partTwo["ask_side"] is RubyBool { Flag: true });
        Assert.True(route["ask_side"] is RubyBool { Flag: true });
        Assert.Equal("ilias", engine.Ledger.AsHash()["side"].AsText());
    }

    /// <summary>
    /// Asserts that the creator of a world, whose save in Part 2 holds the side they took along
    /// themselves, is not asked and keeps Alice, and that a save of their own on a route whose side
    /// the notes never saw is not asked and keeps everyone.
    /// </summary>
    [Fact]
    public void OwnSave_KeepsItsSideUnasked()
    {
        RubyHash partTwo = Request(Story([4], (1001, 22)), Roster((1, 30), (Alice, 30)));
        partTwo["audit"] = true;
        var creator = new CatchupEngine();
        RubyHash created = creator.Check(Tables, partTwo);
        RubyHash route = Request(Story([4], (1001, 40), (1141, 10)), Roster((1, 80), (Alice, 80), (Ilias, 80)));
        route["audit"] = true;
        RubyHash onRoute = new CatchupEngine().Check(Tables, route);

        Assert.True(created["ask_side"] is RubyBool { Flag: false });
        Assert.Empty(Dismissed(created["actions"].AsArray()));
        Assert.Equal("alice", creator.Ledger.AsHash()["side"].AsText());
        Assert.True(onRoute["ask_side"] is RubyBool { Flag: false });
        Assert.Empty(Dismissed(onRoute["actions"].AsArray()));
    }

    /// <summary>
    /// Asserts that a Classic member's check gives Alice and never Ilias to an Alice picker, and
    /// Ilias to one on the Monster Realm.
    /// </summary>
    [Fact]
    public void Answer_KeepsTheCompanionsOfThePickAndTheRoute()
    {
        RubyArray Allowed(string pick, params string[] routes) => Tables.Scope.Answer(new RubyHash
        {
            { "actors", new RubyArray { Alice, Ilias } }, { "site", RubyNil.Value }, { "pick", pick },
            { "own", RoutesPlayed(routes) }, { "guest", true },
        })["allowed"].AsArray();

        Assert.Equal(new RubyArray { Alice }, Allowed("alice"));
        Assert.Equal(new RubyArray { Alice, Ilias }, Allowed("alice", "mr"));
        Assert.Equal(new RubyArray(), Allowed(""));
    }

    /// <summary>
    /// Asserts that while a Classic player's side is unknown, as for a save of another player's
    /// starting save, the Chaos route's strategy conference gives the companions of the side the
    /// switches of the story played hold, as the game's own event reads them, and the catch-up gives
    /// those of the Great Decision and the conference so; a join before the Great Decision still
    /// waits for the answer.
    /// </summary>
    [Fact]
    public void Answer_JudgesARoutesJoinsBySideSwitchesWhileTheSideIsUnknown()
    {
        RubyArray Allowed(string? site, string held, params string[] routes) => Tables.Scope.Answer(new RubyHash
        {
            { "actors", new RubyArray { Ilias, Heinrich } }, { "site", site is null ? RubyNil.Value : site }, { "pick", "" },
            { "own", RoutesPlayed(routes) }, { "guest", true }, { "held", held },
        })["allowed"].AsArray();

        Assert.Equal(new RubyArray { Ilias, Heinrich }, Allowed("map:437:11:1", "alice"));
        Assert.Equal(new RubyArray(), Allowed("map:437:11:1", "ilias"));
        Assert.Equal(new RubyArray(), Allowed("map:437:11:1", ""));
        Assert.Equal(new RubyArray { Ilias, Heinrich }, Allowed(null, "alice", "mr"));
        Assert.Equal(new RubyArray { Ilias, Heinrich }, Allowed(null, "alice", "chaos"));
        Assert.Equal(new RubyArray(), Allowed(null, "alice"));
    }

    /// <summary>
    /// Makes a story that played some routes, as the scripts hand a story.
    /// </summary>
    /// <param name="routes">The routes.</param>
    /// <returns>The story, each route's progress at 1.</returns>
    private static RubyHash RoutesPlayed(string[] routes) => new()
    {
        { "s", new RubyArray() },
        { "v", new RubyArray(routes.Select(route => (RubyValue)new RubyArray { StoryIds.RouteVariables[StoryIds.Routes.ToList().IndexOf(route)], 1 })) },
        { "ss", new RubyArray() },
    };

    /// <summary>
    /// Builds a look's request in world w1.
    /// </summary>
    /// <param name="own">The player's story.</param>
    /// <param name="roster">The roster.</param>
    /// <returns>The request.</returns>
    private static RubyHash Request(RubyHash own, RubyArray roster) => new()
    {
        { "world", "w1" }, { "mode", "world" }, { "look", "tick" }, { "own", own }, { "roster", roster }, { "items", new RubyHash() },
    };

    /// <summary>
    /// Marks a look's request as one of a save of another player's starting save, whose side is not
    /// the player's.
    /// </summary>
    /// <param name="request">The request.</param>
    /// <returns>The request.</returns>
    private static RubyHash OtherStart(RubyHash request)
    {
        request["pick"] = "";
        return request;
    }

    /// <summary>
    /// Builds a story.
    /// </summary>
    /// <param name="switches">The switches on.</param>
    /// <param name="variables">The variables set.</param>
    /// <returns>"s", "v" and "ss".</returns>
    private static RubyHash Story(int[] switches, params (int Id, long Value)[] variables) => new()
    {
        { "s", new RubyArray(switches.Select(id => (RubyValue)id)) },
        { "v", new RubyArray(variables.Select(variable => (RubyValue)new RubyArray { variable.Id, variable.Value })) },
        { "ss", new RubyArray() },
    };

    /// <summary>
    /// Builds a roster of companions in their main persona.
    /// </summary>
    /// <param name="entries">Each companion and base level.</param>
    /// <returns>[id, persona, base level, cap] each.</returns>
    private static RubyArray Roster(params (int Id, long Level)[] entries) =>
        new(entries.Select(entry => (RubyValue)new RubyArray { entry.Id, entry.Id, entry.Level, RubyNil.Value }));

    /// <summary>
    /// Builds the save's notes of world w1 with the side the player took along.
    /// </summary>
    /// <param name="side">The side, <see langword="null"/> for one the notes saw them without.</param>
    /// <param name="done">The rows done.</param>
    /// <returns>The notes.</returns>
    private static RubyHash Notes(string? side, RubyHash? done = null) => new()
    {
        { "world", "w1" }, { "done", done ?? new RubyHash() }, { "held", new RubyHash() }, { "side", side ?? "" }, { "waits", new RubyHash() }, { "rewards_repaired", true },
    };

    /// <summary>
    /// Lists the companions the actions bring in.
    /// </summary>
    /// <param name="actions">The actions.</param>
    /// <returns>The companions' personas.</returns>
    private static List<long> Joined(RubyArray actions) =>
        [.. actions.Select(action => action.AsArray()).Where(action => action[0].AsText() == "join").Select(action => action[1].AsLong())];

    /// <summary>
    /// Lists the companions the actions take away for having no right to them.
    /// </summary>
    /// <param name="actions">The actions.</param>
    /// <returns>The companions.</returns>
    private static List<long> Dismissed(RubyArray actions) =>
        [.. actions.Select(action => action.AsArray()).Where(action => action[0].AsText() == "dismiss").Select(action => action[1].AsLong())];

    /// <summary>
    /// Reads the generated tables and the rules.
    /// </summary>
    /// <returns>The tables.</returns>
    private static CatchupTables ReadTables()
    {
        using JsonDocument tables = JsonDocument.Parse(TableFiles.TablesText());
        return CatchupTables.Read(tables.RootElement);
    }
}
