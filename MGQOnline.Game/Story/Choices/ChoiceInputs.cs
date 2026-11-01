//----------------------------------------------------------------
//  ChoiceInputs.cs
//
//  Changelog:
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
/// The inputs a replay asks the receiver on the question screen, each after the game's own window
/// ("MGQ Online UI specs/Story decisions.md", section 1).
/// </summary>
public enum ChoiceInputKind
{
    /// <summary>
    /// Show Choices: the choice's labels.
    /// </summary>
    Choice,

    /// <summary>
    /// Input Number: digits.
    /// </summary>
    Number,

    /// <summary>
    /// Select Key Item: the receiver's key items.
    /// </summary>
    Item,

    /// <summary>
    /// A present to a companion: the receiver's items the companion takes.
    /// </summary>
    Present,
}

/// <summary>
/// An item a question lists.
/// </summary>
/// <param name="Id">The item.</param>
/// <param name="Name">Its name.</param>
/// <param name="Count">How many the player holds.</param>
/// <param name="Description">Its description, which the hint line shows.</param>
public sealed record ChoiceInputItem(int Id, string Name, int Count, string Description);

/// <summary>
/// A row of a question that lists its answers.
/// </summary>
/// <param name="Answer">What picking it answers: a label's place or an item.</param>
/// <param name="Name">What it shows.</param>
/// <param name="Count">How many the player holds, <see langword="null"/> for a row without a count.</param>
/// <param name="Hint">What the hint line shows while the cursor is on it.</param>
/// <param name="Cancel">Whether it is the cancel answer's own row, which shows last and dim.</param>
public sealed record ChoiceInputRow(int Answer, string Name, int? Count, string Hint, bool Cancel);

/// <summary>
/// An entry of a question's key line.
/// </summary>
/// <param name="Key">The keys' name as written, or <see cref="ChoiceInputs.CancelKey"/> for the game's cancel button as the player bound it.</param>
/// <param name="Text">What they do.</param>
public sealed record ChoiceInputKey(string Key, string Text);

/// <summary>
/// A question on the question screen: what it offers, where it starts and what cancel answers.
/// </summary>
/// <param name="Kind">The input.</param>
/// <param name="Title">The screen's title.</param>
/// <param name="Keys">The entries of the key line this input takes.</param>
/// <param name="Rows">The answers of a list, empty for a number.</param>
/// <param name="Digits">The digits of a number, 0 for a list.</param>
/// <param name="Value">The number the digits start at, 0 for a list.</param>
/// <param name="Index">The row a list starts on, as the game's window starts.</param>
/// <param name="CancelAnswer">What cancel answers, <see langword="null"/> where cancel puts the question off to answer later.</param>
public sealed record ChoiceInput(ChoiceInputKind Kind, string Title, IReadOnlyList<ChoiceInputKey> Keys, IReadOnlyList<ChoiceInputRow> Rows, int Digits, int Value,
    int Index, int? CancelAnswer)
{
    /// <summary>
    /// Gets the hint line the screen opens with: a number's, else the starting row's.
    /// </summary>
    public string Hint => Kind == ChoiceInputKind.Number ? ChoiceInputs.NumberHint : Rows[Index].Hint;
}

/// <summary>
/// The questions a replay asks the receiver: what each offers and what cancel answers, as the game's
/// own window for that input does; the framework's list and number field move the cursor.
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
    /// The hint of a number.
    /// </summary>
    public const string NumberHint = "Type with the digit keys above the letters; the numpad types no digits.";

    /// <summary>
    /// The row of a choice's own cancel branch.
    /// </summary>
    public const string CancelRow = "Cancel";

    /// <summary>
    /// The row of no key item.
    /// </summary>
    public const string NoItemRow = "None";

    /// <summary>
    /// The row that ends the giving of presents.
    /// </summary>
    public const string NoPresentRow = "No present";

    /// <summary>
    /// What cancel says where it puts the question off.
    /// </summary>
    public const string LaterText = "answer later";

    /// <summary>
    /// What no key item and no present answer, as the game's windows answer it.
    /// </summary>
    private const int Nothing = 0;

    /// <summary>
    /// The entry of the keys that move over a list.
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

        List<ChoiceInputRow> rows = [.. labels.Select((label, place) => new ChoiceInputRow(place, label, null, PickHint, false))];
        if (cancel == labels.Count)
        {
            rows.Add(new ChoiceInputRow(labels.Count, CancelRow, null, PickHint, true));
        }

        ChoiceInputKey cancelKey = new(CancelKey, cancel is { } answer ? PlainOf(rows[answer].Name) : LaterText);
        return List(ChoiceInputKind.Choice, TitleOf(opener), [MoveKeys, AnswerKey, cancelKey], rows, cancel, index);
    }

    /// <summary>
    /// Asks a number, which cancel puts off.
    /// </summary>
    /// <param name="opener">Who ran the event, <see langword="null"/> for the player's own history.</param>
    /// <param name="digits">The digits the command names.</param>
    /// <param name="value">The variable's value, where the game's window starts.</param>
    /// <returns>The question.</returns>
    public static ChoiceInput Number(string? opener, int digits, long value)
    {
        int start = (int)Math.Clamp(value, 0, (long)Math.Pow(10, digits) - 1);
        ChoiceInputKey[] keys = [new("Left/Right", "digit"), new("Up/Down or 0-9", "change it"), AnswerKey, new(CancelKey, LaterText)];
        return new ChoiceInput(ChoiceInputKind.Number, TitleOf(opener), keys, [], digits, start, 0, null);
    }

    /// <summary>
    /// Asks a key item, which cancel answers with none.
    /// </summary>
    /// <param name="opener">Who ran the event, <see langword="null"/> for the player's own history.</param>
    /// <param name="items">The player's key items, in the game's window's order.</param>
    /// <param name="index">The row the game's window starts on.</param>
    /// <returns>The question.</returns>
    public static ChoiceInput Item(string? opener, IReadOnlyList<ChoiceInputItem> items, int index) =>
        List(ChoiceInputKind.Item, TitleOf(opener), [MoveKeys, AnswerKey, new(CancelKey, "none")], RowsOf(items, NoItemRow, string.Empty), Nothing, index);

    /// <summary>
    /// Asks a present for a companion, which cancel answers with no present.
    /// </summary>
    /// <param name="companion">The companion's name.</param>
    /// <param name="items">The player's items the companion takes, in the game's window's order.</param>
    /// <param name="result">What the last present did, as the game's line says it; empty for the first.</param>
    /// <param name="index">The row the game's window starts on.</param>
    /// <returns>The question.</returns>
    public static ChoiceInput Present(string companion, IReadOnlyList<ChoiceInputItem> items, string result, int index) =>
        List(ChoiceInputKind.Present, $"A present for {companion}", [MoveKeys, new("Enter", "give"), new(CancelKey, "no present")], RowsOf(items, NoPresentRow, result),
            Nothing, index);

    /// <summary>
    /// Makes a question that lists its answers, starting on a row it holds.
    /// </summary>
    /// <param name="kind">The input.</param>
    /// <param name="title">The title.</param>
    /// <param name="keys">The key line's entries.</param>
    /// <param name="rows">The rows.</param>
    /// <param name="cancel">What cancel answers.</param>
    /// <param name="index">The row it starts on.</param>
    /// <returns>The question.</returns>
    private static ChoiceInput List(ChoiceInputKind kind, string title, IReadOnlyList<ChoiceInputKey> keys, IReadOnlyList<ChoiceInputRow> rows, int? cancel, int index) =>
        new(kind, title, keys, rows, 0, 0, Math.Clamp(index, 0, rows.Count - 1), cancel);

    /// <summary>
    /// Lists items as rows, each hinting at its description after what the last present did, with the
    /// row of no item last.
    /// </summary>
    /// <param name="items">The items.</param>
    /// <param name="none">The name of the row of no item.</param>
    /// <param name="result">What the last present did, empty for nothing.</param>
    /// <returns>The rows.</returns>
    private static List<ChoiceInputRow> RowsOf(IReadOnlyList<ChoiceInputItem> items, string none, string result)
    {
        ArgumentNullException.ThrowIfNull(items);
        List<ChoiceInputRow> rows = [.. items.Select(item => new ChoiceInputRow(item.Id, item.Name, item.Count, HintOf(result, item.Description), false))];
        rows.Add(new ChoiceInputRow(Nothing, none, null, result, true));
        return rows;
    }

    /// <summary>
    /// Joins what the last present did and a row's description into its hint.
    /// </summary>
    /// <param name="result">What the last present did, empty for nothing.</param>
    /// <param name="description">The row's description, empty for none.</param>
    /// <returns>The hint.</returns>
    private static string HintOf(string result, string description) => string.Join(" ", new[] { result, description }.Where(part => part.Length > 0));

    /// <summary>
    /// Takes the game's text codes out of a label, as the key line draws none of them.
    /// </summary>
    /// <param name="label">The label.</param>
    /// <returns>The label as plain text.</returns>
    private static string PlainOf(string label) => TextCodes.Replace(label, code => code.Value == @"\\" ? @"\" : string.Empty);

    /// <summary>
    /// Writes the title of a question of an event.
    /// </summary>
    /// <param name="opener">Who ran the event, <see langword="null"/> for the player's own history.</param>
    /// <returns>The title.</returns>
    private static string TitleOf(string? opener) => opener is null ? "Your own story" : $"{opener}'s event";
}
