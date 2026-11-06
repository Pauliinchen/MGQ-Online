//----------------------------------------------------------------
//  ChoiceInputs.cs
//
//  Changelog:
//      Paulinchen  2026-11-06: Asked only choices, as a replay answers numbers, key items and presents the opener's way
//                            - Titled every question, a present's too, with the opener's name alone
//      Paulinchen  2026-11-01: Left the cursor and the digits to the framework's list and number field
//                            - Put off a number and a choice without cancel on cancel
//                            - Handed the key line as entries naming the bound cancel key
//                            - Named a cancel label on the key line without the game's text codes
//      Paulinchen  2026-10-31: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

namespace MGQOnline.Game.Story.Choices;

/// <summary>
/// A row of a question: one of its answers.
/// </summary>
/// <param name="Answer">What picking it answers: a label's place.</param>
/// <param name="Name">What it shows.</param>
/// <param name="Cancel">Whether it is the cancel answer's own row, which shows last and dim.</param>
public sealed record ChoiceInputRow(int Answer, string Name, bool Cancel);

/// <summary>
/// An entry of a question's key line.
/// </summary>
/// <param name="Key">The keys' name as written, or <see cref="ChoiceInputs.CancelKey"/> for the game's cancel button as the player bound it.</param>
/// <param name="Text">What they do.</param>
public sealed record ChoiceInputKey(string Key, string Text);

/// <summary>
/// A question on the question screen: what it offers, where it starts and what cancel answers.
/// </summary>
/// <param name="Title">The screen's title.</param>
/// <param name="Keys">The entries of the key line.</param>
/// <param name="Rows">The answers.</param>
/// <param name="Index">The row the list starts on, as the game's window starts.</param>
/// <param name="CancelAnswer">What cancel answers, <see langword="null"/> where cancel puts the question off to answer later.</param>
public sealed record ChoiceInput(string Title, IReadOnlyList<ChoiceInputKey> Keys, IReadOnlyList<ChoiceInputRow> Rows, int Index, int? CancelAnswer);

/// <summary>
/// The choices a replay asks the receiver ("MGQ Online UI specs/Story decisions.md", section 1): what
/// each offers and what cancel answers, as the game's own choice window does; the framework's list
/// moves the cursor.
/// </summary>
public static class ChoiceInputs
{
    /// <summary>
    /// The key of a key line entry that stands for the game's cancel button as the player bound it.
    /// </summary>
    public const string CancelKey = "cancel";

    /// <summary>
    /// The hint of a choice.
    /// </summary>
    public const string PickHint = "Pick your answer.";

    /// <summary>
    /// The row of a choice's own cancel branch.
    /// </summary>
    public const string CancelRow = "Cancel";

    /// <summary>
    /// What cancel says where it puts the question off.
    /// </summary>
    public const string LaterText = "answer later";

    /// <summary>
    /// The entry of the keys that move over the list.
    /// </summary>
    private static readonly ChoiceInputKey MoveKeys = new("Up/Down", "move");

    /// <summary>
    /// The entry of the key that answers.
    /// </summary>
    private static readonly ChoiceInputKey AnswerKey = new("Enter", "answer");

    /// <summary>
    /// The game's text codes, such as <c>\C[2]</c> or <c>\I[5]</c>, and its escaped backslash.
    /// </summary>
    private static readonly Regex TextCodes = new(@"\\\\|\\[A-Za-z]+(\[[^\]]*\])?|\\[{}$.|!<>^]",RegexOptions.CultureInvariant);

    /// <summary>
    /// Asks a choice.
    /// </summary>
    /// <param name="opener">Who ran the event, <see langword="null"/> for the player's own history.</param>
    /// <param name="labels">The labels.</param>
    /// <param name="cancel">What cancel answers: a label's place, or the place after the labels for the choice's own branch, which gets a row; <see langword="null"/> where the choice cannot be cancelled, which puts it off.</param>
    /// <param name="index">The row the game's window starts on.</param>
    /// <returns>The question.</returns>
    /// <exception cref="ArgumentOutOfRangeException">The cancel names no label and no branch.</exception>
    public static ChoiceInput Choice(string? opener, IReadOnlyList<string> labels, int? cancel, int index)
    {
        ArgumentNullException.ThrowIfNull(labels);
        if (cancel is { } place)
        {
            ArgumentOutOfRangeException.ThrowIfNegative(place, nameof(cancel));
            ArgumentOutOfRangeException.ThrowIfGreaterThan(place, labels.Count, nameof(cancel));
        }

        List<ChoiceInputRow> rows = [.. labels.Select((label, place) => new ChoiceInputRow(place, label, false))];
        if (cancel == labels.Count)
        {
            rows.Add(new ChoiceInputRow(labels.Count, CancelRow, true));
        }

        ChoiceInputKey cancelKey = new(CancelKey, cancel is { } answer ? PlainOf(rows[answer].Name) : LaterText);
        return new ChoiceInput(TitleOf(opener), [MoveKeys, AnswerKey, cancelKey], rows, Math.Clamp(index, 0, rows.Count - 1), cancel);
    }

    /// <summary>
    /// Takes the game's text codes out of a label, as the key line draws none of them.
    /// </summary>
    /// <param name="label">The label.</param>
    /// <returns>The label as plain text.</returns>
    private static string PlainOf(string label) => TextCodes.Replace(label, code => code.Value == @"\\" ? @"\" : string.Empty);

    /// <summary>
    /// Writes the title of a question of an event: the name of the player whose story it is.
    /// </summary>
    /// <param name="opener">Who ran the event, <see langword="null"/> for the player's own history.</param>
    /// <returns>The title.</returns>
    private static string TitleOf(string? opener) => opener ?? "Your own story";
}
