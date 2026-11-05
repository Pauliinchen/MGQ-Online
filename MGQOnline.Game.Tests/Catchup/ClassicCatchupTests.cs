//----------------------------------------------------------------
//  ClassicCatchupTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System.Text.Json;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Catchup;

namespace MGQOnline.Game.Tests.Catchup;

/// <summary>
/// Covers the catch-up of a Classic party's member behind the leader by the frozen rows, which
/// replaced the copy of what the leader holds.
/// </summary>
public sealed class ClassicCatchupTests
{
    /// <summary>
    /// The rows of a story at steps 10 and 20: a skill, a weapon and a key item both sides get, a
    /// companion and a skill of Alice's side, a companion a later step takes away again, and a world
    /// chest at step 20.
    /// </summary>
    private const string Rows = """
        {"rewards": [{"kind": "skill", "id": 13, "amount": 1, "site": "map:5:1:1", "part": "1", "step": 10, "side": null, "marks": [["v", 1001, 10]], "ran": true},
                     {"kind": "weapon", "id": 1, "amount": 1, "site": "map:5:2:1", "part": "1", "step": 20, "side": null, "marks": [["v", 1001, 20]], "ran": true},
                     {"kind": "skill", "id": 11, "amount": 1, "site": "map:5:3:1", "part": "1", "step": 20, "side": "alice", "marks": [["v", 1001, 20]], "ran": true}],
         "key_items": [{"item": 3, "amount": 1, "site": "map:5:4:1", "part": "1", "step": 20, "side": null, "marks": [["v", 1001, 20]], "ran": true}],
         "joins": [{"actor": 4, "persona": 4, "site": "map:5:5:1", "part": "1", "step": 10, "side": null, "marks": [["v", 1001, 10]], "gate": 1, "rule": "start", "index": 1, "ran": true},
                   {"actor": 5, "persona": 5, "site": "map:5:6:1", "part": "1", "step": 20, "side": "alice", "marks": [["v", 1001, 20]], "gate": 1, "rule": "start", "index": 2, "ran": true},
                   {"actor": 8, "persona": 8, "site": "map:5:7:1", "part": "1", "step": 10, "side": null, "marks": [["v", 1001, 10]], "gate": 1, "rule": "start", "index": 3, "ran": true}],
         "removals": [{"actor": 8, "persona": 8, "site": "map:5:8:1", "part": "1", "step": 20, "side": null, "marks": [["v", 1001, 20]], "first": true, "index": 4}],
         "chests": [{"key": "ss40.1.A", "items": [501], "part": "1", "step": 20}]}
        """;

    /// <summary>
    /// Asserts that a member behind gets what the rows the leader's story is past and theirs is not
    /// give, of their own side, the key item they lack and the world chest the leader opened; a row
    /// of a side waits until they chose theirs, and a companion the story took away again stays away.
    /// </summary>
    [Fact]
    public void MemberBehind_GetsTheRowsTheLeadersStoryIsPastOfTheirOwnSide()
    {
        CatchupTables tables = Read();

        RubyHash noSide = ClassicCatchup.Answer(tables, Request(own: 5, side: null, sided: false));
        RubyHash alice = ClassicCatchup.Answer(tables, Request(own: 5, side: "alice", sided: true));

        Assert.Equal(new RubyArray { 13 }, noSide["skills"]);
        Assert.Equal(new RubyArray { new RubyArray { "w", 1, 1 } }, noSide["items"]);
        Assert.Equal(new RubyArray { new RubyArray { 3, 1 } }, noSide["key_items"]);
        Assert.Equal(new RubyArray { 4 }, noSide["joins"]);
        Assert.Equal(new RubyArray { "ss40.1.A" }, noSide["chests"]);
        Assert.Equal((new RubyArray { 11 }, new RubyArray { 5 }, new RubyArray()), (alice["skills"], alice["joins"], alice["items"]));
    }

    /// <summary>
    /// Asserts that a member as far along as the leader gets nothing of the rows, since the leader's
    /// runs reach them by replay.
    /// </summary>
    [Fact]
    public void MemberAsFarAlong_GetsNothing()
    {
        RubyHash answer = ClassicCatchup.Answer(Read(), Request(own: 20, side: "alice", sided: false));

        Assert.Equal(new RubyArray(), answer["skills"]);
        Assert.Equal(new RubyArray(), answer["items"]);
        Assert.Equal(new RubyArray(), answer["joins"]);
        Assert.Equal(new RubyArray(), answer["chests"]);
    }

    /// <summary>
    /// Asserts that the side call, once a member behind chose their side, gives only the rows of a
    /// side: the World Seed the first call gave and the member used up since is not given back.
    /// </summary>
    [Fact]
    public void SideCall_GivesNoUsedUpWorldSeedBack()
    {
        using JsonDocument document = JsonDocument.Parse("""
            {"key_items": [{"item": 610, "amount": 1, "site": "map:5:9:1", "part": "1", "step": 10, "side": null, "marks": [["v", 1001, 10]], "ran": true}]}
            """);
        CatchupTables tables = CatchupTables.Read(document.RootElement);
        RubyHash Ask(bool sided)
        {
            RubyHash request = Request(own: 5, side: sided ? "alice" : null, sided: sided);
            request["items"] = new RubyHash { { "i610", 0 } };
            return ClassicCatchup.Answer(tables, request);
        }

        Assert.Equal(new RubyArray { new RubyArray { 610, 1 } }, Ask(false)["key_items"]);
        Assert.Equal(new RubyArray(), Ask(true)["key_items"]);
    }

    /// <summary>
    /// Asserts that the Noble Orb the leader bought from the Medal King (job item 662, switch 2336)
    /// reaches a Classic party's member by his gift alone: the catch-up's rows leave it out, a member
    /// whose story holds the switch and who holds none gets it, and a switch looked at once gives
    /// nothing again.
    /// </summary>
    [Fact]
    public void NobleOrb_ReachesAClassicMemberByTheMedalKingsGiftOnce()
    {
        using JsonDocument document = JsonDocument.Parse("""
            {"rewards": [{"kind": "item", "id": 662, "amount": 1, "site": "ce:140", "part": "1", "step": 13, "side": null, "marks": [["v", 1001, 13], ["v", 1090, 3], ["s", 2336]], "ran": true}],
             "prize_switches": [{"switch": 2336}]}
            """);
        CatchupTables tables = CatchupTables.Read(document.RootElement);
        var story = new RubyHash { { "s", new RubyArray { 2336 } }, { "v", new RubyArray { new RubyArray { 1001, 20 }, new RubyArray { 1090, 3 } } }, { "ss", new RubyArray() } };
        RubyHash Gift(long held, RubyArray handled) =>
            MedalKingGift.Answer(tables, new RubyHash { { "story", story }, { "items", new RubyHash { { "i662", held } } }, { "handled", handled } });

        RubyHash rows = ClassicCatchup.Answer(tables, new RubyHash { { "own", Story(5, false) }, { "leader", story }, { "side", string.Empty }, { "sided", false } });
        RubyHash first = Gift(0, []);

        Assert.Equal(new RubyArray(), rows["items"]);
        Assert.Equal(new RubyArray { 2336 }, MedalKingGift.Answer(tables, [])["switches"]);
        Assert.Equal((new RubyArray { new RubyArray { "i", 662, 1 } }, new RubyArray { 2336 }), (first["gifts"], first["handled"]));
        Assert.Equal(new RubyArray(), Gift(1, [])["gifts"]);
        Assert.Equal(new RubyArray(), Gift(0, first["handled"].AsArray())["gifts"]);
    }

    /// <summary>
    /// Makes the request of a member whose own story is at a step, behind a leader at step 20 who
    /// opened the chest.
    /// </summary>
    /// <param name="own">The member's main story progress.</param>
    /// <param name="side">The side they took along, <see langword="null"/> for none.</param>
    /// <param name="sided">Whether only the rows of a side count.</param>
    /// <returns>The request.</returns>
    private static RubyHash Request(long own, string? side, bool sided) => new()
    {
        { "own", Story(own, false) }, { "leader", Story(20, true) }, { "side", side ?? string.Empty }, { "roster", new RubyArray { 1 } },
        { "items", new RubyHash { { "i3", 0 } } }, { "routes", new RubyArray() }, { "sided", sided },
    };

    /// <summary>
    /// Makes a story at a step of the main story.
    /// </summary>
    /// <param name="step">The main story's progress.</param>
    /// <param name="chest">Whether the world chest is open.</param>
    /// <returns>The story as the snapshot holds it.</returns>
    private static RubyHash Story(long step, bool chest) => new()
    {
        { "s", new RubyArray() }, { "v", new RubyArray { new RubyArray { 1001, step } } },
        { "ss", chest ? new RubyArray { new RubyArray { 40, 1, "A" } } : new RubyArray() },
    };

    /// <summary>
    /// Reads the rows.
    /// </summary>
    /// <returns>The tables.</returns>
    private static CatchupTables Read()
    {
        using JsonDocument document = JsonDocument.Parse(Rows);
        return CatchupTables.Read(document.RootElement);
    }
}
