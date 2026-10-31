//----------------------------------------------------------------
//  ChoiceHistoryTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Game.Story;
using MGQOnline.Game.Story.Choices;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers which choices still apply their frozen outcome rows: those up to the place where the
/// stream that hands the player runs began, history no run hands over; the replay asks every later
/// one.
/// </summary>
public sealed class ChoiceHistoryTests
{
    /// <summary>
    /// A story that made no choice.
    /// </summary>
    private static readonly ChoiceValues Fresh = new(new HashSet<int>(), new Dictionary<int, int>(), new HashSet<int>());

    /// <summary>
    /// Asserts that a choice past the stream's start applies no outcome row, since the replay asks it.
    /// </summary>
    [Fact]
    public void Outcome_OfALoggedChoice_WritesNothing()
    {
        ChoiceWrites writes = StoryChoices.Outcome(ChoiceTable.Magistea, 0, new Dictionary<string, int>(), ContextAt(10));

        Assert.Empty(writes.Switches);
        Assert.Empty(writes.Variables);
        Assert.Empty(writes.Joins);
    }

    /// <summary>
    /// Asserts that a choice up to the stream's start, the place it began at included, still applies
    /// its frozen outcome: the story was past it before any run was handed.
    /// </summary>
    [Theory]
    [InlineData(20)]
    [InlineData(17)]
    public void Outcome_UpToTheStreamsStart_WritesItsFrozenRows(int start)
    {
        ChoiceWrites writes = StoryChoices.Outcome(ChoiceTable.Magistea, 0, new Dictionary<string, int>(), ContextAt(start));

        Assert.Contains(new KeyValuePair<int, bool>(2096, true), writes.Switches);
        Assert.Equal([ChoiceTable.Lucia], writes.Joins);
    }

    /// <summary>
    /// Asserts that a catch-up asks only the choices up to the stream's start, and a choice once made
    /// is not asked again.
    /// </summary>
    [Fact]
    public void Passed_ListsOnlyTheChoicesUpToTheStreamsStart()
    {
        var made = new ChoiceValues(new HashSet<int> { 4 }, new Dictionary<int, int>(), new HashSet<int>());

        Assert.Equal([ChoiceTable.Side, ChoiceTable.Magistea], StoryChoices.Passed(5, 40, Fresh, Place(17)));
        Assert.Equal([ChoiceTable.Magistea], StoryChoices.Passed(5, 40, made, Place(17)));
    }

    /// <summary>
    /// Asserts that a player whom no stream hands runs keeps every choice's frozen outcome.
    /// </summary>
    [Fact]
    public void Passed_WithoutAStream_ListsEveryChoice()
    {
        Assert.Equal(8, StoryChoices.Passed(5, 40, Fresh, null).Count);
    }

    /// <summary>
    /// Makes the game of a Classic member who started keeping the leader's story at a progress of
    /// the main story.
    /// </summary>
    /// <param name="progress">The main story's progress where the stream began.</param>
    /// <returns>The game.</returns>
    private static ChoiceContext ContextAt(int progress) => new(false, Fresh, false, false, null, null, Place(progress));

    /// <summary>
    /// Makes a place at a progress of the main story, before any route.
    /// </summary>
    /// <param name="progress">The progress.</param>
    /// <returns>The place.</returns>
    private static RunPlace Place(int progress) => new([progress, 0, 0, 0]);
}
