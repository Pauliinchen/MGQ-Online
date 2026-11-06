//----------------------------------------------------------------
//  ChoiceInputsTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Dropped the checks of the number, key item and present questions, which a replay no longer asks
//                            - Checked that a question and a present are titled with the opener's name alone
//      Paulinchen  2026-11-01: Checked that cancel puts a number and a choice without cancel off, and the key entries
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System.Linq;
using MGQOnline.Game.Story.Choices;

namespace MGQOnline.Game.Tests.Story;

/// <summary>
/// Covers the choices a replay asks on the question screen (<see cref="ChoiceInputs"/>): what each
/// offers, where it starts, and that cancel does what the game's own window does or puts the
/// question off.
/// </summary>
public sealed class ChoiceInputsTests
{
    /// <summary>
    /// Asserts that a choice without cancel is put off, one whose cancel names a label answers it,
    /// and one with its own branch answers the place after the labels on a last row, titled with the
    /// event's opener.
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
        Assert.Equal(((int?)2, true, "Ana"), (branch.CancelAnswer, branch.Rows[2].Cancel, branch.Title));
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
    /// Asserts that a choice starts on the row the game's window starts on.
    /// </summary>
    [Fact]
    public void Choice_StartsOnTheGamesRow()
    {
        Assert.Equal(1, ChoiceInputs.Choice(null, ["Yes", "No"], null, 1).Index);
    }
}
