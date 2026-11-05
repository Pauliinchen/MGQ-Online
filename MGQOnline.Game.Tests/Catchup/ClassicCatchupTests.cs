//----------------------------------------------------------------
//  ClassicCatchupTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Replayed the recorded calls of the Classic catch-up, the side and the key item loan on the one engine
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
/// Covers how a Classic party's member plays the leader's story and catches up with it on the one
/// catch-up engine, the side a player takes along and the Classic key item loan, against every call
/// the script tests made (fixtures/catchup/classic.json, made by fixtures/catchup/make_classic.rb),
/// each answer checked by hand against the user's written answers, and the rules no test of the
/// scripts reaches.
/// </summary>
public sealed class ClassicCatchupTests
{
    /// <summary>
    /// The golden cases.
    /// </summary>
    private static readonly JsonElement Classic = Fixtures.Read("catchup", "classic.json");

    /// <summary>
    /// Asserts that every call answers as the user's answers its note names call for: members
    /// behind, as far along and ahead, the side taken either way, a used-up key item taken, a reward
    /// behind a choice waiting for the member's own answer, the key items lent and given back, the
    /// closures and chests the leader's story ran, and who plays one story.
    /// </summary>
    [Fact]
    public void Calls_AnswerAsTheUsersAnswersCallFor()
    {
        CatchupTables[] sets = [.. Classic.GetProperty("tables").EnumerateArray().Select(CatchupEngineTests.TablesOf)];
        int index = 0;
        foreach (JsonElement entry in Classic.GetProperty("cases").EnumerateArray())
        {
            string topic = entry.GetProperty("topic").GetString()!;
            string note = entry.GetProperty("note").GetString()!;
            CatchupTables tables = entry.GetProperty("tables").ValueKind == JsonValueKind.Number ? sets[entry.GetProperty("tables").GetInt32()] : CatchupTables.Empty;
            RubyHash request = CatchupEngineTests.ValueOf(entry.GetProperty("request")).AsHash();
            RubyHash answer = topic switch
            {
                "catchup.classic" => CatchupEngine.Classic(tables, request, PartyOf(entry)),
                "catchup.side" => SidePick.Answer(tables, request),
                "catchup.key_loan" => KeyItemLoan.Answer(request),
                "catchup.classic_sync" => ClassicStory.Sync(request),
                "catchup.classic_followers" => ClassicStory.Followers(request),
                "catchup.classic_mode" => ClassicStory.Mode(request),
                _ => ClassicStory.Restore(request),
            };
            RubyValue expected = CatchupEngineTests.ValueOf(entry.GetProperty("answer"));

            Assert.True(note.Length > 0 && note != "UNCHECKED", $"case {index} ({topic}) names no answer it follows");
            Assert.True(expected.Equals(answer), $"case {index} ({topic}, {note}):\nexpected {expected}\nanswered {answer}");
            index++;
        }

        Assert.True(index > 0);
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
    /// Builds what a case read of the party: the self switches it found a member's own, and the
    /// chests it found gave key items, for the same opened chests and items asked.
    /// </summary>
    /// <param name="entry">The case.</param>
    /// <returns>The party.</returns>
    private static ClassicParty PartyOf(JsonElement entry)
    {
        if (!entry.TryGetProperty("party", out JsonElement party))
        {
            return ClassicParty.None;
        }

        RubyHash noted = CatchupEngineTests.ValueOf(party).AsHash();
        HashSet<StoryKey> own = noted["own"] is RubyArray keys ? [.. keys.Select(KeyOf)] : [];
        List<(RubyValue Opened, RubyValue Items, RubyArray Found)> chests = noted["chests"] is RubyArray asked
            ? [.. asked.Select(call => (call.AsArray()[0], call.AsArray()[1], call.AsArray()[2].AsArray()))]
            : [];
        return new ClassicParty(
            own.Contains,
            (opened, items) =>
            {
                RubyArray openedAsked = new(opened.Select(CatchupLook.SelfSwitchOf));
                RubyArray itemsAsked = new(items.Select(item => (RubyValue)item));
                RubyArray found = chests.Single(call => call.Opened.Equals(openedAsked) && call.Items.Equals(itemsAsked)).Found;
                return [.. found.Select(chest => ChestOf(chest.AsArray()))];
            });
    }

    /// <summary>
    /// Reads a chest a case found gave key items.
    /// </summary>
    /// <param name="chest">[[map, event, letter], [item, ...]].</param>
    /// <returns>The chest, on its first page.</returns>
    private static KeyItemChest ChestOf(RubyArray chest)
    {
        StoryKey key = KeyOf(chest[0]);
        return new KeyItemChest(ReplaySite.Parse($"map:{key.Id}:{key.Event}:1"), key, [.. chest[1].AsArray().Select(item => item.AsInt())]);
    }

    /// <summary>
    /// Reads a self switch as the scripts list it.
    /// </summary>
    /// <param name="value">[map, event, letter].</param>
    /// <returns>The self switch.</returns>
    private static StoryKey KeyOf(RubyValue value) => StoryKey.SelfSwitch(value.AsArray()[0].AsInt(), value.AsArray()[1].AsInt(), value.AsArray()[2].AsText());

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
