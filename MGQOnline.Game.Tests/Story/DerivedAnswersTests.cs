//----------------------------------------------------------------
//  DerivedAnswersTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-11: Named a choice's answer by its number among the page's Show Choices
//      Paulinchen  2026-11-01: Named a choice's answer by its Show Choices command's place among the kept commands
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Data.Events;
using MGQOnline.Game.Story;
using MGQOnline.Game.Tests.Events;
using static MGQOnline.Game.Tests.Events.TinyGame;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers the answers of a derived entry of the history before the log: each choice of its page
/// takes the branch that ends with the source's letters, and one whose branches end alike is asked.
/// </summary>
public sealed class DerivedAnswersTests
{
    /// <summary>
    /// A page of map 1, 140:47 in small: a text with a choice whose first branch turns self switch A
    /// on and whose second turns B on, then a choice without a text whose branches both turn C on.
    /// </summary>
    private readonly EventStore _store = EventDatabases.Of(new TinyGame()
        .MapEvent(1, 47, 0, 0, new TinyPage([
            C(101, "", 0, 0, 2),
            C(102, 2, 2),
            At(402, 0, 0, "Give them to me"),
            At(123, 1, "A", 0),
            At(0, 1),
            At(402, 0, 1, "Keep them"),
            At(123, 1, "B", 0),
            At(0, 1),
            C(404),
            C(102, 2, 2),
            At(402, 0, 0, "Yes"),
            At(123, 1, "C", 0),
            At(0, 1),
            At(402, 0, 1, "No"),
            At(123, 1, "C", 0),
            At(0, 1),
            C(404),
        ]))
        .Files());

    /// <summary>
    /// Asserts that a choice takes the branch that ends with the source's letters, named by its
    /// number among the page's Show Choices, as the opener's run names a choice's answer.
    /// </summary>
    [Fact]
    public void Of_TakesTheBranchThatEndsWithTheSourcesLetters()
    {
        IReadOnlyList<ReplayInput> answers = DerivedAnswers.Of(_store, ReplaySite.Page(1, 47, 0), ["A", "C"]);

        Assert.Equal([new ReplayInput("map:1:47:1@102:0", 0, "choice", 0)], answers);
    }

    /// <summary>
    /// Asserts that the other branch is taken for a source that holds its letter instead.
    /// </summary>
    [Fact]
    public void Of_TakesTheOtherBranchForTheOtherLetter()
    {
        Assert.Equal([new ReplayInput("map:1:47:1@102:0", 0, "choice", 1)], DerivedAnswers.Of(_store, ReplaySite.Page(1, 47, 0), ["B"]));
    }

    /// <summary>
    /// Asserts that a choice whose branches end alike, or whose letters the source holds both, gets
    /// no answer, so the receiver is asked.
    /// </summary>
    [Fact]
    public void Of_LeavesBranchesThatEndAlikeToAsk()
    {
        Assert.Empty(DerivedAnswers.Of(_store, ReplaySite.Page(1, 47, 0), ["A", "B", "C"]));
    }
}
