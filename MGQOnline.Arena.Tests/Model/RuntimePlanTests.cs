//----------------------------------------------------------------
//  RuntimePlanTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using MGQOnline.Arena.Model;

namespace MGQOnline.Arena.Tests.Model;

/// <summary>
/// Tests which rolled skills a stage of a battle plan gives an enemy slot.
/// </summary>
public sealed class RuntimePlanTests
{
    /// <summary>
    /// The first stage's rolled skill.
    /// </summary>
    private static readonly RuntimeAction Opening = new("a1", SkillRef.OfGame(101), 5, new AlwaysActionCondition());

    /// <summary>
    /// The third stage's rolled skill.
    /// </summary>
    private static readonly RuntimeAction Serious = new("a3", SkillRef.OfGame(102), 5, new AlwaysActionCondition());

    /// <summary>
    /// A plan of three stages: the first sets the slot, the second leaves it out, the third sets it anew.
    /// </summary>
    private static readonly RuntimePlan Plan = new(
        [
            new RuntimeStage("s1", "Opening", new Dictionary<string, IReadOnlyList<RuntimeAction>> { ["slot"] = [Opening] }),
            new RuntimeStage("s2", "Middle"),
            new RuntimeStage("s3", "Serious", new Dictionary<string, IReadOnlyList<RuntimeAction>> { ["slot"] = [Serious] }),
        ],
        []);

    /// <summary>
    /// A stage without its own list for a slot keeps the list of the nearest stage before it.
    /// </summary>
    [Fact]
    public void KeepsTheListOfTheStageBefore()
    {
        Assert.Equal([Opening], Plan.ActionsOf("s2", "slot"));
        Assert.Equal([Serious], Plan.ActionsOf("s3", "slot"));
    }

    /// <summary>
    /// An unknown stage counts as the first, and a slot no stage sets rolls nothing.
    /// </summary>
    [Fact]
    public void ReadsAnUnknownStageAsTheFirst()
    {
        Assert.Equal([Opening], Plan.ActionsOf("gone", "slot"));
        Assert.Empty(Plan.ActionsOf("s3", "other"));
    }
}
