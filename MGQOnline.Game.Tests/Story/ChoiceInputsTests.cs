//----------------------------------------------------------------
//  ChoiceInputsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-01: Checked that cancel puts a number and a choice without cancel off, and the key entries
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQOnline.Game.Story.Choices;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers the questions a replay asks on the question screen (<see cref="ChoiceInputs"/>): what each
/// input offers, where it starts, and that cancel does what the game's own window does or puts the
/// question off.
/// </summary>
public sealed class ChoiceInputsTests
{
    /// <summary>
    /// The key items of the item and present questions.
    /// </summary>
    private static readonly ChoiceInputItem[] Items = [new(12, "Silver Ring", 1, "A ring."), new(30, "Old Map", 2, "A map.")];

    /// <summary>
    /// Asserts that a number starts at the variable's value, clamped to its digits as the game
    /// clamps it, and names the event's opener.
    /// </summary>
    [Fact]
    public void Number_StartsAtTheValueClampedToItsDigits()
    {
        ChoiceInput input = ChoiceInputs.Number("Ana", 3, 42);

        Assert.Equal((3, 42, "Ana's event"), (input.Digits, input.Value, input.Title));
        Assert.Equal(99, ChoiceInputs.Number(null, 2, 1234).Value);
    }

    /// <summary>
    /// Asserts that cancel puts a number off, which its key line names last by the bound cancel key,
    /// and that its hint says the numpad types no digits.
    /// </summary>
    [Fact]
    public void Number_PutsOffOnCancel()
    {
        ChoiceInput input = ChoiceInputs.Number(null, 3, 5);

        Assert.Null(input.CancelAnswer);
        Assert.Equal(new ChoiceInputKey(ChoiceInputs.CancelKey, "answer later"), input.Keys[^1]);
        Assert.Contains("the numpad types no digits", input.Hint);
    }

    /// <summary>
    /// Asserts that a choice without cancel is put off, one whose cancel names a label answers it,
    /// and one with its own branch answers the place after the labels on a last row.
    /// </summary>
    [Fact]
    public void Choice_CancelsAsTheChoiceSays()
    {
        ChoiceInput plain = ChoiceInputs.Choice(null, ["Yes", "No"], null, 0);
        ChoiceInput label = ChoiceInputs.Choice(null, ["Yes", "No"], 1, 0);
        ChoiceInput branch = ChoiceInputs.Choice("Ana", ["Sword", "Shield"], 2, 0);

        Assert.Equal(((int?)null, "answer later"), (plain.CancelAnswer, plain.Keys[^1].Text));
        Assert.Equal(((int?)1, "No"), (label.CancelAnswer, label.Keys[^1].Text));
        Assert.Equal(["Sword", "Shield", "Cancel"], branch.Rows.Select(row => row.Name));
        Assert.Equal(((int?)2, true), (branch.CancelAnswer, branch.Rows[2].Cancel));
    }

    /// <summary>
    /// Asserts that the key line names a cancel label without the game's text codes, which only the
    /// list draws.
    /// </summary>
    [Fact]
    public void Choice_NamesTheCancelLabelWithoutTextCodes()
    {
        ChoiceInput input = ChoiceInputs.Choice(null, ["Yes", @"\C[2]No\C[0]"], 1, 0);

        Assert.Equal(("No", @"\C[2]No\C[0]"), (input.Keys[^1].Text, input.Rows[1].Name));
    }

    /// <summary>
    /// Asserts that a list starts on the row the game's window starts on, kept inside its rows.
    /// </summary>
    [Fact]
    public void List_StartsOnTheGamesRow()
    {
        Assert.Equal(1, ChoiceInputs.Choice(null, ["Yes", "No"], null, 1).Index);
        Assert.Equal(2, ChoiceInputs.Item(null, Items, 9).Index);
    }

    /// <summary>
    /// Asserts that a key item lists the items with None last, which cancel answers.
    /// </summary>
    [Fact]
    public void Item_AnswersNoneOnCancel()
    {
        ChoiceInput input = ChoiceInputs.Item(null, Items, 0);

        Assert.Equal(["Silver Ring", "Old Map", "None"], input.Rows.Select(row => row.Name));
        Assert.Equal(((int?)0, 0), (input.CancelAnswer, input.Rows[2].Answer));
        Assert.Equal("A map.", input.Rows[1].Hint);
    }

    /// <summary>
    /// Asserts that a present names the companion, starts each row's hint with what the last present
    /// did, and answers no present on cancel.
    /// </summary>
    [Fact]
    public void Present_HintsTheLastResultFirst()
    {
        ChoiceInput input = ChoiceInputs.Present("Alice", Items, "Alice is pleased.", 0);

        Assert.Equal("A present for Alice", input.Title);
        Assert.Equal("Alice is pleased. A ring.", input.Hint);
        Assert.Equal(("No present", (int?)0), (input.Rows[^1].Name, input.CancelAnswer));
        Assert.Equal(new ChoiceInputKey(ChoiceInputs.CancelKey, "no present"), input.Keys[^1]);
    }
}
