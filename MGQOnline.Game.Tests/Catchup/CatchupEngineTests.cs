//----------------------------------------------------------------
//  CatchupEngineTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Replayed the calls of the side's rule too, and shared reading a golden case's tables
//                            - Checked that a prize counted by a variable comes by its row no more, the Medal King's gift still
//                            - Checked that a companion a replay hands out follows the world's companion sharing and the join's level
//                            - Dropped the found job item's case, whose items the story replay hands over
//                            - Checked that the companion of a replay the player answered their own way joins once their level reaches the join's gate
//      Paulinchen  2026-10-31: Covered a missed companion who joins by the replay of their recruit page
//                            - Covered the history the world's log holds, which gives nothing from its row
//                            - Covered a world chest played in the player's game
//      Paulinchen  2026-10-28: Covered the return point in free order
//                            - Covered a prize marked by a prize switch
//                            - Covered a world chest the game shuts by a switch
//                            - Shared reading a plain value of a golden case with the other catch-up tests
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Catchup;

namespace MGQOnline.Game.Tests.Catchup;

/// <summary>
/// Covers the catch-up's engine against every call the script tests made of the script's decisions
/// (fixtures/catchup/engine.json, made by fixtures/catchup/make_engine.rb), and the rules no test
/// of the scripts reaches any more.
/// </summary>
public sealed class CatchupEngineTests
{
    /// <summary>
    /// The golden cases.
    /// </summary>
    private static readonly JsonElement Engine = Fixtures.Read("catchup", "engine.json");

    /// <summary>
    /// Asserts that every call answers as the script decided, over the same tables and notes.
    /// </summary>
    [Fact]
    public void Calls_AnswerAsTheScriptDecided()
    {
        CatchupTables[] sets = [.. Engine.GetProperty("tables").EnumerateArray().Select(TablesOf)];
        int index = 0;
        foreach (JsonElement entry in Engine.GetProperty("cases").EnumerateArray())
        {
            string topic = entry.GetProperty("topic").GetString()!;
            var engine = new CatchupEngine { Ledger = ValueOf(entry.GetProperty("ledger")) };
            CatchupTables tables = sets[entry.GetProperty("tables").GetInt32()];
            RubyHash request = ValueOf(entry.GetProperty("request")).AsHash();
            RubyHash answer = topic switch
            {
                "catchup.check" => engine.Check(tables, request),
                "catchup.note" => engine.Note(tables, request),
                "catchup.hold_join" => engine.HoldJoin(tables, request),
                "catchup.side" => SidePick.Answer(tables, request),
                _ => engine.Unlocks(tables, request),
            };
            RubyValue expected = ValueOf(entry.GetProperty("answer"));

            Assert.True(expected.Equals(answer), $"case {index} ({topic}):\nexpected {expected}\nanswered {answer}");
            index++;
        }

        Assert.True(index > 0);
    }

    /// <summary>
    /// Asserts that a join's persona is left once a change of the story at its place or later set
    /// another, as Granberia's return to 16 after the join of 17 in common event 9106, while the
    /// join still raises her to its level.
    /// </summary>
    [Fact]
    public void Join_LeavesThePersonaALaterChangeSet()
    {
        CatchupTables tables = Read("""
            {"joins": [{"actor": 16, "persona": 17, "site": "ce:9106", "part": "chaos", "step": 20, "side": null, "marks": [], "gate": 225, "rule": "floor", "index": 461, "ran": true}],
             "actor_changes": [{"actor": 16, "calls": [["persona_change", [16], false]], "gate": null, "site": "ce:9106", "part": "chaos", "step": 20, "side": null, "marks": [], "ran": true}]}
            """);
        RubyArray Waiting(bool changed)
        {
            var done = new RubyHash { { "j:ce:9106:17", "c" } };
            if (changed)
            {
                done["a:ce:9106:16"] = true;
            }

            var engine = new CatchupEngine { Ledger = new RubyHash { { "world", "w1" }, { "done", done }, { "rewards_repaired", true } } };
            return engine.Check(tables, Request(new RubyArray { new RubyArray { 1, 1, 300, RubyNil.Value }, new RubyArray { 16, 16, 100, RubyNil.Value } }))["actions"].AsArray();
        }

        Assert.DoesNotContain(Waiting(true), action => action.AsArray()[0].AsText() == "form");
        Assert.Contains(Waiting(true), action => action.Equals(new RubyArray { "raise", 17, 225 }));
        Assert.Contains(Waiting(false), action => action.Equals(new RubyArray { "form", 17, "ce:9106" }));
    }

    /// <summary>
    /// Asserts that a world chest the game shuts by a switch plays in the player's game once the
    /// world's story turned the switch on, while the player who opened it gets nothing more.
    /// </summary>
    [Fact]
    public void SwitchChest_PlaysOnceTheWorldOpenedIt()
    {
        CatchupTables tables = Read("""
            {"chests": [{"key": "s2719", "items": [767], "part": "mr", "step": 51, "flags": []}]}
            """);
        RubyArray Actions(bool opened)
        {
            RubyHash request = Request(new RubyArray());
            request["told"] = new RubyHash { { "s", new RubyArray { 2719 } }, { "v", new RubyArray() }, { "ss", new RubyArray() } };
            request["items"] = new RubyHash { { "i767", opened ? 1 : 0 } };
            if (opened)
            {
                request["own"].AsHash()["s"] = new RubyArray { 2719 };
            }

            var engine = new CatchupEngine { Ledger = new RubyHash { { "world", "w1" }, { "rewards_repaired", true } } };
            return engine.Check(tables, request)["actions"].AsArray();
        }

        RubyArray given = Actions(false);

        Assert.Contains(given, action => action.Equals(new RubyArray { "replay", new RubyHash { { "chest", "s2719" } }, "c:s2719" }));
        Assert.DoesNotContain(given, action => action.AsArray()[0].AsText() is "give" or "switch");
        Assert.DoesNotContain(Actions(true), action => action.AsArray()[0].AsText() is "replay");
    }

    /// <summary>
    /// Asserts that the Medal King's free gift, a row marked by a prize switch, gives its prize at a
    /// look to a player whose story holds the switch and who holds none of it, and nothing to a
    /// player who holds it, while a prize counted by a variable comes only by the replay of the run
    /// that won it.
    /// </summary>
    [Fact]
    public void PrizeSwitch_GivesThePrizeToEveryPlayerWhoHoldsNone()
    {
        CatchupTables tables = Read("""
            {"rewards": [{"kind": "weapon", "id": 112, "amount": 1, "site": "ce:140", "part": "1", "step": 13, "side": null, "marks": [["v", 1001, 13], ["v", 1090, 3], ["s", 2324]], "ran": true},
                         {"kind": "item", "id": 600, "amount": 1, "site": "ce:148", "part": null, "step": null, "side": null, "marks": [["v", 87, 1]], "ran": true}],
             "prize_switches": [{"switch": 2324}]}
            """);
        RubyArray Actions(long held)
        {
            RubyHash request = Request(new RubyArray());
            RubyHash own = request["own"].AsHash();
            own["s"] = new RubyArray { 2324 };
            own["v"] = new RubyArray { new RubyArray { 1001, 40 }, new RubyArray { 1090, 3 }, new RubyArray { 87, 1 } };
            request["items"] = new RubyHash { { "w112", held }, { "i600", 0 } };
            var engine = new CatchupEngine { Ledger = new RubyHash { { "world", "w1" }, { "rewards_repaired", true } } };
            return engine.Check(tables, request)["actions"].AsArray();
        }

        Assert.Contains(Actions(0), action => action.Equals(new RubyArray { "give", "w", 112, 1, "g:ce:140:w112", true }));
        Assert.DoesNotContain(Actions(0), action => action.Equals(new RubyArray { "give", "i", 600, 1, "g:ce:148:i600", true }));
        Assert.DoesNotContain(Actions(1), action => action.AsArray()[0].AsText() == "give");
    }

    /// <summary>
    /// Asserts that a companion a replay hands out joins only by the one companion filter: never in a
    /// world that shares no companions, and in one that shares the story's companions once the
    /// player's level reaches the join's gate, which the world's shared companions bring later.
    /// </summary>
    [Fact]
    public void ReplayJoin_FollowsTheWorldsSharingAndTheJoinsLevel()
    {
        CatchupTables tables = Read("""
            {"joins": [{"actor": 163, "persona": 163, "site": "map:359:35:3", "part": "1", "step": 18, "side": null, "marks": [["v", 1001, 18]], "gate": 20, "rule": "level", "index": 1, "ran": true}]}
            """);
        bool Refused(string sharing, long level)
        {
            RubyHash request = Request(new RubyArray { new RubyArray { 1, 1, level, RubyNil.Value } });
            request["actor"] = 163;
            request["site"] = "map:359:35:3";
            request["scope_only"] = true;
            request["replay"] = true;
            request["sharing"] = sharing;
            var engine = new CatchupEngine { Ledger = new RubyHash { { "world", "w1" }, { "rewards_repaired", true } } };
            return engine.HoldJoin(tables, request)["refused"] is RubyBool { Flag: true };
        }

        Assert.True(Refused("off", 50));
        Assert.True(Refused("story", 10));
        Assert.False(Refused("story", 50));
    }

    /// <summary>
    /// Asserts that a level-15 receiver of a replay of the Plansect choice who answers "Side with the
    /// Priestess", though the opener answered otherwise, gets her as their own in a world that
    /// shares the story's companions: the replay's join waits for its gate of 20, and she joins once
    /// the receiver reaches level 20; a replay that went the opener's way is refused at level 15.
    /// </summary>
    [Fact]
    public void OwnWayReplayJoin_WaitsForTheGateAsTheReceiversOwn()
    {
        CatchupTables tables = Read("""
            {"joins": [{"actor": 241, "persona": 241, "site": "map:132:23:3", "part": "1", "step": 7, "side": null, "marks": [["v", 1001, 7], ["v", 1061, 1], ["ss", 132, 23, "B"]], "gate": 20, "rule": "start", "index": 25, "ran": true}]}
            """);
        var engine = new CatchupEngine { Ledger = new RubyHash { { "world", "w1" }, { "rewards_repaired", true } } };
        RubyHash Ask(long level, bool chose)
        {
            RubyHash request = Request(new RubyArray { new RubyArray { 1, 1, level, RubyNil.Value } });
            request["own"] = new RubyHash
            {
                { "s", new RubyArray() }, { "v", new RubyArray { new RubyArray { 1001, 7 }, new RubyArray { 1061, chose ? 1 : 0 } } },
                { "ss", chose ? new RubyArray { new RubyArray { 132, 23, "B" } } : new RubyArray() },
            };
            request["sharing"] = "story";
            return request;
        }

        RubyHash Hold(bool ownWay)
        {
            RubyHash request = Ask(15, false);
            request["actor"] = 241;
            request["site"] = "map:132:23:3";
            request["scope_only"] = !ownWay;
            request["replay"] = true;
            request["own_way"] = ownWay;
            return engine.HoldJoin(tables, request);
        }

        bool openersWayRefused = Hold(false)["refused"] is RubyBool { Flag: true };
        RubyHash held = Hold(true);
        RubyArray atFifteen = engine.Check(tables, Ask(15, true))["actions"].AsArray();
        RubyArray atTwenty = engine.Check(tables, Ask(20, true))["actions"].AsArray();

        Assert.True(openersWayRefused);
        Assert.Equal((RubyValue)20, held["gate"]);
        Assert.False(held["refused"] is RubyBool { Flag: true });
        Assert.DoesNotContain(atFifteen, action => action.AsArray()[0].AsText() == "join");
        Assert.Contains(atTwenty, action => action.AsArray()[0].AsText() == "join" && action.AsArray()[1].AsLong() == 241);
    }

    /// <summary>
    /// Asserts that a story laid over the player's leaves their return point alone where the latest
    /// row it passed lies on a step in free order, as the Chaos route's regions after the Pocket
    /// Castle's revival, which the rows cannot order, while without the rule it sets that row's.
    /// </summary>
    [Fact]
    public void Settle_LeavesTheReturnPointAloneInFreeOrder()
    {
        const string Settings = """
            "settings": [{"kind": "variable", "id": 1002, "value": 135, "site": "map:1432:5:1", "part": "chaos", "step": 20, "side": null, "marks": [["v", 1143, 20]], "ran": true},
                         {"kind": "variable", "id": 1002, "value": 136, "site": "map:1475:14:1", "part": "chaos", "step": 21, "side": null, "marks": [["v", 1143, 21], ["v", 1305, 4]], "ran": true},
                         {"kind": "variable", "id": 1002, "value": 137, "site": "map:1900:37:1", "part": "chaos", "step": 21, "side": null, "marks": [["v", 1143, 21], ["v", 1335, 4]], "ran": true}]
            """;
        RubyArray Settled(string rules)
        {
            CatchupTables tables = Read("{" + Settings + ", \"rules\": [" + rules + "]}");
            var story = new RubyHash
            {
                { "s", new RubyArray() }, { "ss", new RubyArray() },
                { "v", new RubyArray { new RubyArray { 1001, 40 }, new RubyArray { 1002, 135 }, new RubyArray { 1143, 21 }, new RubyArray { 1305, 4 }, new RubyArray { 1335, 4 } } },
            };
            RubyHash request = Request(new RubyArray());
            request["look"] = "carried";
            request["own"] = story;
            request["told"] = story;
            request["before"] = story;
            var engine = new CatchupEngine { Ledger = new RubyHash { { "world", "w1" }, { "rewards_repaired", true } } };
            return new RubyArray(engine.Check(tables, request)["actions"].AsArray().Where(action => action.AsArray()[0].AsText() == "setting"));
        }

        Assert.Empty(Settled("""{"rule": "free_order", "value": [{"part": "chaos", "step": 21}]}"""));
        Assert.Equal(new RubyArray { new RubyArray { "setting", "v", 1002, 137, "map:1900:37:1" } }, Settled(""));
    }

    /// <summary>
    /// Asserts that a story laid over the player's gives the rows of the history the world's story
    /// was past where its log starts once, side content without a step among them, and nothing of a
    /// row whose run the log holds, which the world's track replays instead.
    /// </summary>
    [Fact]
    public void LoggedHistory_GivesNothingFromItsRow()
    {
        CatchupTables tables = Read("""
            {"rewards": [{"kind": "item", "id": 600, "amount": 1, "site": "map:36:18:1", "part": "2", "step": 20, "side": null, "marks": [["v", 1001, 20]], "ran": true},
                         {"kind": "item", "id": 601, "amount": 1, "site": "map:36:19:1", "part": "2", "step": 30, "side": null, "marks": [["v", 1001, 30]], "ran": true},
                         {"kind": "item", "id": 602, "amount": 1, "site": "map:40:2:1", "part": null, "step": null, "side": null, "marks": [["s", 3000]], "ran": true},
                         {"kind": "item", "id": 603, "amount": 1, "site": "map:40:3:1", "part": null, "step": null, "side": null, "marks": [["s", 3001]], "ran": true}]}
            """);
        static RubyHash At(long progress, params int[] on) => new() { { "s", new RubyArray(on.Select(id => (RubyValue)id)) }, { "v", new RubyArray { new RubyArray { 1001, progress } } }, { "ss", new RubyArray() } };
        RubyHash request = Request(new RubyArray());
        request["look"] = "carried";
        request["before"] = At(10);
        request["own"] = At(32, 3000, 3001);
        request["told"] = At(32, 3000, 3001);
        request["log"] = At(25, 3000);
        request["items"] = new RubyHash { { "i600", 0 }, { "i601", 0 }, { "i602", 0 }, { "i603", 0 } };
        var engine = new CatchupEngine { Ledger = new RubyHash { { "world", "w1" }, { "rewards_repaired", true } } };

        RubyArray first = engine.Check(tables, request)["actions"].AsArray();
        RubyArray again = engine.Check(tables, request)["actions"].AsArray();

        Assert.Equal(new RubyArray { new RubyArray { "give", "i", 600, 1, "g:map:36:18:1:i600", true }, new RubyArray { "give", "i", 602, 1, "g:map:40:2:1:i602", true } },
            new RubyArray(first.Where(action => action.AsArray()[0].AsText() == "give")));
        Assert.DoesNotContain(again, action => action.AsArray()[0].AsText() == "give");
    }

    /// <summary>
    /// Asserts that a companion the player missed joins by the replay of their recruit page once a
    /// route finished, once, whose fight the derived entry counts as won, and that the companion
    /// setting Off adds no one.
    /// </summary>
    [Fact]
    public void MissedCompanion_JoinsByReplayingTheRecruitPage()
    {
        CatchupTables tables = Read("""
            {"joins": [{"actor": 241, "persona": 241, "site": "map:132:23:1", "part": "1", "step": 7, "side": null, "marks": [["v", 1001, 7], ["v", 1056, 4], ["s", 5028]], "gate": 31, "rule": "start", "index": 525, "ran": true}]}
            """);
        var engine = new CatchupEngine { Ledger = new RubyHash { { "world", "w1" }, { "rewards_repaired", true } } };
        RubyArray Look(string sharing)
        {
            RubyHash request = Request(new RubyArray { new RubyArray { 1, 1, 40, RubyNil.Value } });
            request["own"].AsHash()["s"] = new RubyArray { 7096 };
            request["sharing"] = sharing;
            return engine.Check(tables, request)["actions"].AsArray();
        }

        Assert.DoesNotContain(Look("off"), action => action.AsArray()[0].AsText() is "replay" or "join");
        RubyArray first = Look("story");
        Assert.Contains(first, action => action.Equals(new RubyArray { "replay", new RubyHash { { "site", "map:132:23:1" } }, "m:241" }));
        Assert.DoesNotContain(first, action => action.AsArray()[0].AsText() == "join");
        Assert.DoesNotContain(Look("story"), action => action.AsArray()[0].AsText() == "replay");
    }

    /// <summary>
    /// Asserts that the notes of another world start anew, and that notes the call left as they were
    /// are not handed back.
    /// </summary>
    [Fact]
    public void Ledger_StartsAnewForAnotherWorldAndIsHandedBackOnlyChanged()
    {
        var engine = new CatchupEngine { Ledger = new RubyHash { { "world", "w0" }, { "done", new RubyHash { { "g:map:1:1:1:i5", true } } } } };

        RubyHash first = engine.Note(CatchupTables.Empty, new RubyHash { { "world", "w1" }, { "checkpoint", "2" } });
        RubyHash again = engine.Note(CatchupTables.Empty, new RubyHash { { "world", "w1" }, { "checkpoint", "2" } });

        RubyHash notes = first["ledger"].AsHash();
        Assert.Equal(("w1", 0, "2"), (notes["world"].AsText(), notes["done"].AsHash().Count, notes["checkpoint"].AsText()));
        Assert.True(again["ledger"].IsNil);
    }

    /// <summary>
    /// Builds a look's request in world w1 of a story at Chaos 20, with a roster.
    /// </summary>
    /// <param name="roster">The roster: [id, persona, base level, cap] each.</param>
    /// <returns>The request.</returns>
    private static RubyHash Request(RubyArray roster) => new()
    {
        { "world", "w1" }, { "mode", "world" }, { "look", "tick" },
        { "own", new RubyHash { { "s", new RubyArray() }, { "v", new RubyArray { new RubyArray { 1001, 40 }, new RubyArray { 1143, 20 } } }, { "ss", new RubyArray() } } },
        { "roster", roster }, { "items", new RubyHash() },
    };

    /// <summary>
    /// Reads tables of the relay's rows.
    /// </summary>
    /// <param name="json">The rows by table.</param>
    /// <returns>The tables.</returns>
    private static CatchupTables Read(string json)
    {
        using JsonDocument document = JsonDocument.Parse(json);
        return CatchupTables.Read(document.RootElement);
    }

    /// <summary>
    /// Reads a table set of the cases: each table its rows, or "generated" for the generated rows of
    /// fixtures/catchup/generated.
    /// </summary>
    /// <param name="set">The set.</param>
    /// <returns>The tables.</returns>
    internal static CatchupTables TablesOf(JsonElement set)
    {
        var text = new StringBuilder("{");
        foreach (JsonProperty table in set.EnumerateObject())
        {
            string rows = table.Value.ValueKind == JsonValueKind.String ? GeneratedRows(table.Name) : table.Value.GetRawText();
            text.Append(text.Length == 1 ? "" : ",").Append('"').Append(table.Name).Append("\":").Append(rows);
        }

        return Read(text.Append('}').ToString());
    }

    /// <summary>
    /// Reads the generated rows of a table.
    /// </summary>
    /// <param name="table">The table.</param>
    /// <returns>Its rows as JSON.</returns>
    private static string GeneratedRows(string table)
    {
        using JsonDocument file = JsonDocument.Parse(File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "fixtures", "catchup", "generated", table + ".json")));
        return file.RootElement.GetProperty("rows").GetRawText();
    }

    /// <summary>
    /// Reads a plain value as make_engine.rb wrote it: a Hash with keys that are no texts as
    /// {"#pairs": [[key, value], ...]}.
    /// </summary>
    /// <param name="json">The value.</param>
    /// <returns>The Ruby value.</returns>
    internal static RubyValue ValueOf(JsonElement json)
    {
        switch (json.ValueKind)
        {
            case JsonValueKind.Number:
                return json.GetInt64();
            case JsonValueKind.String:
                return json.GetString();
            case JsonValueKind.True:
                return true;
            case JsonValueKind.False:
                return false;
            case JsonValueKind.Array:
                return new RubyArray(json.EnumerateArray().Select(ValueOf));
            case JsonValueKind.Object:
                var hash = new RubyHash();
                if (json.TryGetProperty("#pairs", out JsonElement pairs))
                {
                    foreach (JsonElement pair in pairs.EnumerateArray())
                    {
                        hash[ValueOf(pair[0])] = ValueOf(pair[1]);
                    }

                    return hash;
                }

                foreach (JsonProperty property in json.EnumerateObject())
                {
                    hash[property.Name] = ValueOf(property.Value);
                }

                return hash;
            default:
                return RubyNil.Value;
        }
    }
}
