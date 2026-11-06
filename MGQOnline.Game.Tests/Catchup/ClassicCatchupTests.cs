//----------------------------------------------------------------
//  ClassicCatchupTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Walked a member past the Great Decision catching up with the rows of the leader's side
//      Paulinchen  2026-11-06: Dropped the checks that replayed recorded cases
//                            - Walked a member behind catching up with both sides' rows and their own side's
//      Paulinchen  2026-11-05: Replayed every call the script tests answer by its recorded answer, and what the catch-up reads over each table set
//                            - Replayed the recorded calls of the Classic catch-up, the side and the key item loan on the one engine
//                            - Created
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
/// Covers how a Classic party's member catches up with the leader's story on the one catch-up
/// engine.
/// </summary>
public sealed class ClassicCatchupTests
{
    /// <summary>
    /// Asserts that a member behind catches up with the skills the leader's story passed: those both
    /// sides get and those of the side the member took along, never the other side's.
    /// </summary>
    [Fact]
    public void MemberBehind_CatchesUpWithTheRowsOfBothSidesAndTheirOwn()
    {
        CatchupTables tables = Read("""
            {"rewards": [
              {"kind": "skill", "id": 13, "amount": 1, "site": "map:50:1:1", "part": "1", "step": 10, "side": null, "marks": [["v", 1001, 10]], "ran": true},
              {"kind": "skill", "id": 11, "amount": 1, "site": "map:50:3:1", "part": "1", "step": 10, "side": "alice", "marks": [["v", 1001, 10]], "ran": true},
              {"kind": "skill", "id": 12, "amount": 1, "site": "map:50:4:1", "part": "1", "step": 10, "side": "ilias", "marks": [["v", 1001, 10]], "ran": true}]}
            """);

        RubyArray actions = CatchupEngine.Classic(tables, Request("alice"), ClassicParty.None)["actions"].AsArray();

        Assert.Equal([13L, 11L], Skills(actions));
    }

    /// <summary>
    /// Asserts that a member who answered the side question after the leader passed the Great
    /// Decision gets the Part 3 rows of the leader's side, the one the switches show, not of the
    /// side they picked.
    /// </summary>
    [Fact]
    public void MemberPastTheDecision_GetsThePartThreeRowsOfTheLeadersSide()
    {
        CatchupTables tables = Read("""
            {"rewards": [
              {"kind": "skill", "id": 21, "amount": 1, "site": "map:60:3:1", "part": "3", "step": 36, "side": "alice", "marks": [["v", 1001, 36]], "ran": true},
              {"kind": "skill", "id": 22, "amount": 1, "site": "map:60:4:1", "part": "3", "step": 36, "side": "ilias", "marks": [["v", 1001, 36]], "ran": true}]}
            """);
        RubyHash request = Request("alice");
        request["before"] = Story(35);
        request["leader"] = Story(40);
        request["leader"].AsHash()["s"] = new RubyArray { 5 };
        request["leader"].AsHash()["v"].AsArray().Add(new RubyArray { 1141, 1 });

        RubyArray actions = CatchupEngine.Classic(tables, request, ClassicParty.None)["actions"].AsArray();

        Assert.Equal([22L], Skills(actions));
    }
    /// <summary>
    /// Asserts that the second look, once a member behind chose their side, gives no key item again
    /// that the first look gave: the World Seed the member used up since is not given back.
    /// </summary>
    [Fact]
    public void SideLook_GivesNoUsedUpWorldSeedAgain()
    {
        CatchupTables tables = Read("""
            {"key_items": [{"item": 610, "amount": 1, "site": "map:5:9:1", "part": "1", "step": 10, "side": null, "marks": [["v", 1001, 10]], "ran": true}]}
            """);
        RubyHash Look(RubyValue ledger, string? pick)
        {
            RubyHash request = Request(pick);
            request["ledger"] = ledger;
            return CatchupEngine.Classic(tables, request, ClassicParty.None);
        }

        RubyHash first = Look(RubyNil.Value, null);
        RubyHash second = Look(first["ledger"], "alice");

        Assert.Contains(first["actions"].AsArray(), action => action.AsArray() is [RubyString { Text: "give" }, RubyString { Text: "i" }, var item, ..] && item.AsLong() == 610);
        Assert.DoesNotContain(second["actions"].AsArray(), action => action.AsArray()[0].AsText() == "give");
    }

    /// <summary>
    /// Asserts that the Noble Orb the leader bought from the Medal King (job item 662, switch 2336)
    /// is left out of a Classic member's catch-up, which his gift alone gives.
    /// </summary>
    [Fact]
    public void NobleOrb_IsLeftToTheMedalKingsGift()
    {
        CatchupTables tables = Read("""
            {"rewards": [{"kind": "item", "id": 662, "amount": 1, "site": "ce:140", "part": "1", "step": 13, "side": null, "marks": [["v", 1001, 13], ["s", 2336]], "ran": true}],
             "prize_switches": [{"switch": 2336}]}
            """);
        RubyHash request = Request(null);
        request["leader"].AsHash()["s"] = new RubyArray { 2336 };

        RubyArray actions = CatchupEngine.Classic(tables, request, ClassicParty.None)["actions"].AsArray();

        Assert.DoesNotContain(actions, action => action.AsArray()[0].AsText() == "give");
    }

    /// <summary>
    /// Makes the request of a member at step 5 behind a leader at step 20, who holds none of items 610
    /// and 662.
    /// </summary>
    /// <param name="pick">The side the member took along, <see langword="null"/> while unknown.</param>
    /// <returns>The request.</returns>
    private static RubyHash Request(string? pick) => new()
    {
        { "before", Story(5) }, { "leader", Story(20) }, { "pick", pick is null ? RubyNil.Value : pick }, { "roster", new RubyArray() },
        { "items", new RubyHash { { "i610", 0 }, { "i662", 0 } } },
    };

    /// <summary>
    /// Lists the skills a catch-up's actions give.
    /// </summary>
    /// <param name="actions">The actions.</param>
    /// <returns>The skills, in their order.</returns>
    private static IEnumerable<long> Skills(RubyArray actions) =>
        actions.Select(action => action.AsArray()).Where(action => action[0].AsText() == "give" && action[1].AsText() == "skill").Select(action => action[2].AsLong());

    /// <summary>
    /// Makes a story at a step of the main story.
    /// </summary>
    /// <param name="step">The main story's progress.</param>
    /// <returns>The story as the snapshot holds it.</returns>
    private static RubyHash Story(long step) => new()
    {
        { "s", new RubyArray() }, { "v", new RubyArray { new RubyArray { 1001, step } } }, { "ss", new RubyArray() },
    };

    /// <summary>
    /// Reads rows.
    /// </summary>
    /// <param name="json">The rows by table.</param>
    /// <returns>The tables.</returns>
    private static CatchupTables Read(string json)
    {
        using JsonDocument document = JsonDocument.Parse(json);
        return CatchupTables.Read(document.RootElement);
    }
}
