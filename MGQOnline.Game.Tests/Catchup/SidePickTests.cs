//----------------------------------------------------------------
//  SidePickTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Text.Json;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Catchup;

namespace MGQOnline.Game.Tests.Catchup;

/// <summary>
/// Covers the side a player took along in Iliasville as the scripts note it on their own story, and
/// what an answer to the question of the side sets and brings.
/// </summary>
public sealed class SidePickTests
{
    /// <summary>
    /// The tables: the choice leaves step 7, and each side brings its little companion.
    /// </summary>
    private static readonly CatchupTables Tables = Read("""
        {"rules": [{"rule": "side_step", "value": 7}, {"rule": "side_companions", "value": {"alice": 8, "ilias": 9}}]}
        """);

    /// <summary>
    /// Asserts that before the Great Decision the side switches tell the side, which the save notes
    /// once, but none of another player's starting save; past it, where a route's reset turns switch 4
    /// on, the save's note alone tells it.
    /// </summary>
    [Fact]
    public void Taken_ReadsTheSwitchesBeforeTheGreatDecisionAndTheNotePastIt()
    {
        StoryValues iliasBefore = Story([5], 0);
        StoryValues dominion = Story([4], 3);

        Assert.Equal(("ilias", "ilias"), SidePick.Taken(iliasBefore, null));
        Assert.Equal(("ilias", (string?)null), SidePick.Taken(iliasBefore, "ilias"));
        Assert.Equal(((string?)null, (string?)null), SidePick.Taken(Story([4], 0), ""));
        Assert.Equal(("ilias", (string?)null), SidePick.Taken(dominion, "ilias"));
        Assert.Equal(((string?)null, (string?)null), SidePick.Taken(dominion, null));
        Assert.Equal(((string?)null, (string?)null), SidePick.Taken(dominion, ""));
    }

    /// <summary>
    /// Asserts that a player's answer before the Great Decision sets the side switches and brings
    /// the side's companion, and on a route sets and brings nothing, the switches telling the route
    /// there; either way the save notes the side.
    /// </summary>
    [Fact]
    public void Answer_ChoiceSetsTheSwitchesAndBringsTheCompanionOnlyBeforeTheGreatDecision()
    {
        RubyHash before = SidePick.Answer(Tables, Chose("alice", 0));
        RubyHash onRoute = SidePick.Answer(Tables, Chose("alice", 10));

        Assert.Equal(new RubyArray { new RubyArray { 4, true }, new RubyArray { 5, false } }, before["switches"]);
        Assert.Equal(8L, before["companion"].AsLong());
        Assert.Equal("alice", before["note"].AsText());
        Assert.Equal(new RubyArray(), onRoute["switches"]);
        Assert.True(onRoute["companion"].IsNil);
        Assert.Equal("alice", onRoute["note"].AsText());
    }

    /// <summary>
    /// Makes a story at step 30 of the main story.
    /// </summary>
    /// <param name="switchesOn">The switches on.</param>
    /// <param name="angelicDominion">The Angelic Dominion's progress, 0 before the Great Decision.</param>
    /// <returns>The story.</returns>
    private static StoryValues Story(IEnumerable<int> switchesOn, long angelicDominion) =>
        new(switchesOn, [new(1001, angelicDominion > 0 ? 40 : 30), new(1141, angelicDominion)], []);

    /// <summary>
    /// Makes the request of a player who answered whom they take along, with no note in the save.
    /// </summary>
    /// <param name="side">The side answered.</param>
    /// <param name="angelicDominion">The Angelic Dominion's progress, 0 before the Great Decision.</param>
    /// <returns>The request.</returns>
    private static RubyHash Chose(string side, long angelicDominion) => new()
    {
        { "note", RubyNil.Value }, { "chose", side },
        {
            "own", new RubyHash
            {
                { "s", new RubyArray() },
                { "v", new RubyArray { new RubyArray { 1001, angelicDominion > 0 ? 40 : 30 }, new RubyArray { 1141, angelicDominion } } },
                { "ss", new RubyArray() },
            }
        },
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
