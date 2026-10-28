//----------------------------------------------------------------
//  CatchupEngineTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-28: Shared reading a plain value of a golden case with the other catch-up tests
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
