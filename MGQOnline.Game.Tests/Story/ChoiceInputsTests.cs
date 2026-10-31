//----------------------------------------------------------------
//  ChoiceInputsTests.cs
//
//  Changelog:
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQOnline.Game.Story.Choices;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers the questions a replay asks on the decision screen (<see cref="ChoiceInputs"/>): the
/// answers each input gives, and that cancel does what the game's own window does.
/// </summary>
public sealed class ChoiceInputsTests
{
    /// <summary>
    /// The key items of the item and present questions.
    /// </summary>
    private static readonly ChoiceInputItem[] Items = [new(12, "Silver Ring", 1, "A ring."), new(30, "Old Map", 2, "A map.")];

    /// <summary>
    /// Asserts that a number starts at the value given, turns and takes typed digits as the game's
    /// number window does, and answers its value.
    /// </summary>
    [Fact]
    public void Number_AnswersTheDigitsEntered()
    {
        ChoiceInput input = ChoiceInputs.Number("Ana", 3, 42);
        Assert.Equal([0, 4, 2], input.Digits);

        input = ChoiceInputs.Step(input, ChoiceInputAction.Down, wrap: true);
        input = ChoiceInputs.Step(input, ChoiceInputAction.Right, wrap: true);
        input = ChoiceInputs.Step(input, ChoiceInputAction.Digit, at: 7);
        input = ChoiceInputs.Step(input, ChoiceInputAction.Ok);

        Assert.Equal(972, input.Answer);
        Assert.Equal("Ana's event", input.Title);
    }

    /// <summary>
    /// Asserts that a number tells the player that the numpad types no digits and that Numpad 0
    /// puts the answer off.
    /// </summary>
    [Fact]
    public void Number_NamesTheNumpadInItsHintAndKeys()
    {
        ChoiceInput input = ChoiceInputs.Number(null, 3, 5);

        Assert.Contains("the numpad types no digits", input.Hint);
        Assert.Contains("Numpad 0: answer later.", input.Keys);
    }

    /// <summary>
    /// Asserts that a start value beyond the digits is clamped as the game clamps it.
    /// </summary>
    [Fact]
    public void Number_ClampsTheStartValueToItsDigits()
    {
        Assert.Equal([9, 9], ChoiceInputs.Number(null, 2, 1234).Digits);
    }

    /// <summary>
    /// Asserts that cancel leaves a number unanswered, as the game's number window ignores it.
    /// </summary>
    [Fact]
    public void Number_IgnoresCancel()
    {
        ChoiceInput input = ChoiceInputs.Step(ChoiceInputs.Number(null, 3, 5), ChoiceInputAction.Cancel);

        Assert.Null(input.Answer);
    }

    /// <summary>
    /// Asserts that an item question answers the item clicked, and None or cancel with 0.
    /// </summary>
    [Fact]
    public void Item_AnswersTheItemPickedOrZero()
    {
        ChoiceInput input = ChoiceInputs.Item(null, Items, 0, 8);
        Assert.Equal(["Silver Ring", "Old Map", "None"], input.Rows.Select(row => row.Name));

        Assert.Equal(30, ChoiceInputs.Step(input, ChoiceInputAction.Click, at: 1).Answer);
        Assert.Equal(0, ChoiceInputs.Step(input, ChoiceInputAction.Click, at: 2).Answer);
        Assert.Equal(0, ChoiceInputs.Step(input, ChoiceInputAction.Cancel).Answer);
    }

    /// <summary>
    /// Asserts that a present question names the companion, answers the present given, and 0 for no
    /// present.
    /// </summary>
    [Fact]
    public void Present_AnswersThePresentOrZero()
    {
        ChoiceInput input = ChoiceInputs.Present("Alice", Items, "Alice is pleased.", 0, 8);

        Assert.Equal("A present for Alice", input.Title);
        Assert.Equal("Alice is pleased. A ring.", input.Hint);
        Assert.Equal(12, ChoiceInputs.Step(input, ChoiceInputAction.Ok).Answer);
        Assert.Equal(0, ChoiceInputs.Step(input, ChoiceInputAction.Cancel).Answer);
    }

    /// <summary>
    /// Asserts that a choice answers the label's place, and that cancel gives what the choice's
    /// cancel names: nothing without one, its own branch as a last row.
    /// </summary>
    [Fact]
    public void Choice_AnswersThePlaceAndCancelsAsTheChoiceSays()
    {
        ChoiceInput plain = ChoiceInputs.Choice(null, ["Yes", "No"], null, 0, 8);
        ChoiceInput branch = ChoiceInputs.Choice("Ana", ["Yes", "No"], 2, 0, 8);

        Assert.Equal("Your own story", plain.Title);
        Assert.Equal(1, ChoiceInputs.Step(ChoiceInputs.Step(plain, ChoiceInputAction.Down), ChoiceInputAction.Ok).Answer);
        Assert.Null(ChoiceInputs.Step(plain, ChoiceInputAction.Cancel).Answer);
        Assert.Equal(["Yes", "No", "Cancel"], branch.Rows.Select(row => row.Name));
        Assert.Equal(2, ChoiceInputs.Step(branch, ChoiceInputAction.Cancel).Answer);
    }

    /// <summary>
    /// Asserts that a list longer than its room scrolls with the cursor.
    /// </summary>
    [Fact]
    public void List_ScrollsWithTheCursor()
    {
        ChoiceInput input = ChoiceInputs.Item(null, Items, 0, 2);
        input = ChoiceInputs.Step(ChoiceInputs.Step(input, ChoiceInputAction.Down), ChoiceInputAction.Down);

        Assert.Equal((2, 1), (input.Cursor, input.Top));
    }
}
