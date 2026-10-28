//----------------------------------------------------------------
//  CatchupEngineTests.cs
//
//  Changelog:
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
    /// Asserts that a world chest the game shuts by a switch gives its items once the world's story
    /// turned the switch on, and shuts the chest in the player's game by that switch, while the
    /// player who opened it gets nothing more.
    /// </summary>
    [Fact]
    public void SwitchChest_GivesItsItemsOnceTheWorldOpenedIt()
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

        Assert.Contains(given, action => action.Equals(new RubyArray { "give", "i", 767, 1, "c:s2719", true }));
        Assert.Contains(given, action => action.Equals(new RubyArray { "switch", 2719, true }));
        Assert.DoesNotContain(Actions(true), action => action.AsArray()[0].AsText() is "give" or "switch");
    }

    /// <summary>
    /// Asserts that a prize row marked by a prize switch gives its prize at a look to a player whose
    /// story holds the switch and who holds none of it, as a one-of-a-kind exchange of the Medal
    /// King another player bought, and nothing to a player who holds it.
    /// </summary>
    [Fact]
    public void PrizeSwitch_GivesThePrizeToEveryPlayerWhoHoldsNone()
    {
        CatchupTables tables = Read("""
            {"rewards": [{"kind": "weapon", "id": 112, "amount": 1, "site": "ce:140", "part": "1", "step": 13, "side": null, "marks": [["v", 1001, 13], ["v", 1090, 3], ["s", 2324]], "ran": true}],
             "prize_switches": [{"switch": 2324}]}
            """);
        RubyArray Actions(long held)
        {
            RubyHash request = Request(new RubyArray());
            RubyHash own = request["own"].AsHash();
            own["s"] = new RubyArray { 2324 };
            own["v"] = new RubyArray { new RubyArray { 1001, 40 }, new RubyArray { 1090, 3 } };
            request["items"] = new RubyHash { { "w112", held } };
            var engine = new CatchupEngine { Ledger = new RubyHash { { "world", "w1" }, { "rewards_repaired", true } } };
            return engine.Check(tables, request)["actions"].AsArray();
        }

        Assert.Contains(Actions(0), action => action.Equals(new RubyArray { "give", "w", 112, 1, "g:ce:140:w112", true }));
        Assert.DoesNotContain(Actions(1), action => action.AsArray()[0].AsText() == "give");
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
    private static CatchupTables TablesOf(JsonElement set)
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
