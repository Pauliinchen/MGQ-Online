//----------------------------------------------------------------
//  ChoiceInputs.cs
//
//  Changelog:
//      Paulinchen  2026-11-01: Put off a number and a choice without cancel on cancel
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
/// The inputs a replay asks the receiver on the decision screen, each after the game's own window
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
/// What the player does on a question.
/// </summary>
public enum ChoiceInputAction
{
    /// <summary>
    /// Up: the row above, or the digit under the cursor turned up.
    /// </summary>
    Up,

    /// <summary>
    /// Down: the row below, or the digit under the cursor turned down.
    /// </summary>
    Down,

    /// <summary>
    /// Left: the digit to the left.
    /// </summary>
    Left,

    /// <summary>
    /// Right: the digit to the right.
    /// </summary>
    Right,

    /// <summary>
    /// A typed digit, set on the digit under the cursor.
    /// </summary>
    Digit,

    /// <summary>
    /// A click: on a row it answers that row, on a digit it moves the cursor there.
    /// </summary>
    Click,

    /// <summary>
    /// The mouse wheel: it moves the cursor over a list, or turns the digit under the pointer.
    /// </summary>
    Wheel,

    /// <summary>
    /// Confirm: answers the row or the number.
    /// </summary>
    Ok,

    /// <summary>
    /// The game's cancel: answers what the game's window answers on cancel, or puts the question off
    /// where that answers nothing.
    /// </summary>
    Cancel,
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
/// <param name="Description">What the hint line shows while the cursor is on it, empty for nothing.</param>
/// <param name="Cancel">Whether it is the cancel answer's own row, which shows last and dim.</param>
public sealed record ChoiceInputRow(int Answer, string Name, int? Count, string Description, bool Cancel);

/// <summary>
/// An entry of a question's key line.
/// </summary>
/// <param name="Key">The keys' name as written, or <see cref="ChoiceInputs.CancelKey"/> for the game's cancel button as the player bound it.</param>
/// <param name="Text">What they do.</param>
public sealed record ChoiceInputKey(string Key, string Text);

/// <summary>
/// A question on the decision screen, where its cursor stands, and its answer once given.
/// </summary>
/// <param name="Kind">The input.</param>
/// <param name="Title">The screen's title.</param>
/// <param name="Keys">The entries of the key line this input takes.</param>
/// <param name="Result">What the last present did, empty for none.</param>
/// <param name="Rows">The answers of a list, empty for a number.</param>
/// <param name="Digits">The digits of a number, the highest first; empty for a list.</param>
/// <param name="Cursor">The row or digit the cursor is on.</param>
/// <param name="Top">The first row shown.</param>
/// <param name="Visible">The rows the screen has room for.</param>
/// <param name="CancelAnswer">What cancel answers, <see langword="null"/> where cancel puts the question off to answer later.</param>
/// <param name="Answer">The answer, <see langword="null"/> until given.</param>
/// <param name="Cue">The sound of the last step: "cursor", "ok" or "cancel"; <see langword="null"/> for none.</param>
/// <param name="Later">Whether cancel put the question off to answer later.</param>
public sealed record ChoiceInput(ChoiceInputKind Kind, string Title, IReadOnlyList<ChoiceInputKey> Keys, string Result, IReadOnlyList<ChoiceInputRow> Rows,
    IReadOnlyList<int> Digits, int Cursor, int Top, int Visible, int? CancelAnswer, int? Answer, string? Cue, bool Later = false)
{
    /// <summary>
    /// Gets the hint line: the description of the row under the cursor, after what the last present
    /// did; for a choice the ask to pick, for a number which keys type its digits.
    /// </summary>
    public string Hint => Kind switch
    {
        ChoiceInputKind.Choice => ChoiceInputs.PickHint,
        ChoiceInputKind.Number => ChoiceInputs.NumberHint,
        _ => string.Join(" ", new[] { Result, Rows[Cursor].Description }.Where(part => part.Length > 0)),
    };

    /// <summary>
    /// Gets the number the digits make.
    /// </summary>
    public int Value => Digits.Aggregate(0, (value, digit) => value * 10 + digit);
}

/// <summary>
/// The questions a replay asks the receiver: what each offers and answers, as the game's own window
/// for that input does, and how the cursor, the digits and the list's scrolling follow the player.
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
    private static readonly Regex TextCodes = new(@"\\\\|\\[A-Za-z]+(\[[^\]]*\])?|\\[{}$.|!<>^]", RegexOptions.CultureInvariant);

    /// <summary>
    /// Asks a choice.
    /// </summary>
    /// <param name="opener">Who ran the event, <see langword="null"/> for the player's own history.</param>
    /// <param name="labels">The labels.</param>
    /// <param name="cancel">What cancel answers: a label's place, or the place after the labels for the choice's own branch, which gets a row; <see langword="null"/> where the choice cannot be cancelled, which puts it off.</param>
    /// <param name="index">The row the game's window starts on.</param>
    /// <param name="visible">The rows the screen has room for.</param>
    /// <returns>The question.</returns>
    public static ChoiceInput Choice(string? opener, IReadOnlyList<string> labels, int? cancel, int index, int visible)
    {
        ArgumentNullException.ThrowIfNull(labels);
        List<ChoiceInputRow> rows = [.. labels.Select((label, place) => new ChoiceInputRow(place, label, null, string.Empty, false))];
        if (cancel == labels.Count)
        {
            rows.Add(new ChoiceInputRow(labels.Count, CancelRow, null, string.Empty, true));
        }

        ChoiceInputKey cancelKey = new(CancelKey, cancel is { } answer ? PlainOf(rows[answer].Name) : LaterText);
        return List(ChoiceInputKind.Choice, TitleOf(opener), [MoveKeys, AnswerKey, cancelKey], string.Empty, rows, cancel, index, visible);
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
        long start = Math.Clamp(value, 0, (long)Math.Pow(10, digits) - 1);
        int[] places = [.. start.ToString(System.Globalization.CultureInfo.InvariantCulture).PadLeft(digits, '0').Select(digit => digit - '0')];
        ChoiceInputKey[] keys = [new("Left/Right", "digit"), new("Up/Down or 0-9", "change it"), AnswerKey, new(CancelKey, LaterText)];
        return new ChoiceInput(ChoiceInputKind.Number, TitleOf(opener), keys, string.Empty, [], places, 0, 0, 1, null, null, null);
    }

    /// <summary>
    /// Asks a key item, which cancel answers with none.
    /// </summary>
    /// <param name="opener">Who ran the event, <see langword="null"/> for the player's own history.</param>
    /// <param name="items">The player's key items, in the game's window's order.</param>
    /// <param name="index">The row the game's window starts on.</param>
    /// <param name="visible">The rows the screen has room for.</param>
    /// <returns>The question.</returns>
    public static ChoiceInput Item(string? opener, IReadOnlyList<ChoiceInputItem> items, int index, int visible) =>
        List(ChoiceInputKind.Item, TitleOf(opener), [MoveKeys, AnswerKey, new(CancelKey, "none")], string.Empty, RowsOf(items, NoItemRow), Nothing, index, visible);

    /// <summary>
    /// Asks a present for a companion, which cancel answers with no present.
    /// </summary>
    /// <param name="companion">The companion's name.</param>
    /// <param name="items">The player's items the companion takes, in the game's window's order.</param>
    /// <param name="result">What the last present did, as the game's line says it; empty for the first.</param>
    /// <param name="index">The row the game's window starts on.</param>
    /// <param name="visible">The rows the screen has room for.</param>
    /// <returns>The question.</returns>
    public static ChoiceInput Present(string companion, IReadOnlyList<ChoiceInputItem> items, string result, int index, int visible) =>
        List(ChoiceInputKind.Present, $"A present for {companion}", [MoveKeys, new("Enter", "give"), new(CancelKey, "no present")], result, RowsOf(items, NoPresentRow),
            Nothing, index, visible);

    /// <summary>
    /// Takes a step of the player on a question.
    /// </summary>
    /// <param name="input">The question.</param>
    /// <param name="action">What the player did.</param>
    /// <param name="at">The row or digit clicked or pointed at, or the digit typed.</param>
    /// <param name="notches">The wheel's notches, positive up.</param>
    /// <param name="wrap">Whether a move past the end comes round, as only a fresh press does in the game.</param>
    /// <returns>The question after the step; one answered or put off already stays as it is.</returns>
    public static ChoiceInput Step(ChoiceInput input, ChoiceInputAction action, int at = 0, int notches = 0, bool wrap = false)
    {
        ArgumentNullException.ThrowIfNull(input);
        if (input.Answer is not null || input.Later)
        {
            return input with { Cue = null };
        }

        return input.Kind == ChoiceInputKind.Number ? StepNumber(input, action, at, notches, wrap) : StepList(input, action, at, notches, wrap);
    }

    /// <summary>
    /// Takes a step on a list.
    /// </summary>
    /// <param name="input">The question.</param>
    /// <param name="action">What the player did.</param>
    /// <param name="at">The row clicked.</param>
    /// <param name="notches">The wheel's notches.</param>
    /// <param name="wrap">Whether a move comes round.</param>
    /// <returns>The question after the step.</returns>
    private static ChoiceInput StepList(ChoiceInput input, ChoiceInputAction action, int at, int notches, bool wrap) => action switch
    {
        ChoiceInputAction.Up => MoveRow(input, input.Cursor - 1, wrap),
        ChoiceInputAction.Down => MoveRow(input, input.Cursor + 1, wrap),
        ChoiceInputAction.Wheel => MoveRow(input, input.Cursor - notches, false),
        ChoiceInputAction.Click => Answered(input with { Cursor = at }, input.Rows[at].Answer, "ok"),
        ChoiceInputAction.Ok => Answered(input, input.Rows[input.Cursor].Answer, "ok"),
        ChoiceInputAction.Cancel when input.CancelAnswer is { } answer => Answered(input, answer, "cancel"),
        ChoiceInputAction.Cancel => PutOff(input),
        _ => input with { Cue = null },
    };

    /// <summary>
    /// Takes a step on a number.
    /// </summary>
    /// <param name="input">The question.</param>
    /// <param name="action">What the player did.</param>
    /// <param name="at">The digit clicked or pointed at, or the digit typed.</param>
    /// <param name="notches">The wheel's notches.</param>
    /// <param name="wrap">Whether a move comes round.</param>
    /// <returns>The question after the step.</returns>
    private static ChoiceInput StepNumber(ChoiceInput input, ChoiceInputAction action, int at, int notches, bool wrap) => action switch
    {
        ChoiceInputAction.Up => Turn(input, input.Cursor, 1),
        ChoiceInputAction.Down => Turn(input, input.Cursor, -1),
        ChoiceInputAction.Wheel => Turn(input, at, notches),
        ChoiceInputAction.Left => MoveDigit(input, input.Cursor - 1, wrap),
        ChoiceInputAction.Right => MoveDigit(input, input.Cursor + 1, wrap),
        ChoiceInputAction.Click => input with { Cursor = at, Cue = "cursor" },
        ChoiceInputAction.Digit => Typed(input, at),
        ChoiceInputAction.Ok => Answered(input, input.Value, "ok"),
        ChoiceInputAction.Cancel => PutOff(input),
        _ => input with { Cue = null },
    };

    /// <summary>
    /// Moves the cursor over a list, scrolling it into view: past an end only with wrap.
    /// </summary>
    /// <param name="input">The question.</param>
    /// <param name="to">The row wanted.</param>
    /// <param name="wrap">Whether a move past an end comes round.</param>
    /// <returns>The question.</returns>
    private static ChoiceInput MoveRow(ChoiceInput input, int to, bool wrap)
    {
        int count = input.Rows.Count;
        int row = wrap ? ((to % count) + count) % count : Math.Clamp(to, 0, count - 1);
        return row == input.Cursor ? input with { Cue = null } : input with { Cursor = row, Top = TopFor(row, input.Top, input.Visible), Cue = "cursor" };
    }

    /// <summary>
    /// Moves the cursor over the digits: past an end only with wrap.
    /// </summary>
    /// <param name="input">The question.</param>
    /// <param name="to">The digit wanted.</param>
    /// <param name="wrap">Whether a move past an end comes round.</param>
    /// <returns>The question.</returns>
    private static ChoiceInput MoveDigit(ChoiceInput input, int to, bool wrap)
    {
        int count = input.Digits.Count;
        int digit = wrap ? ((to % count) + count) % count : Math.Clamp(to, 0, count - 1);
        return digit == input.Cursor ? input with { Cue = null } : input with { Cursor = digit, Cue = "cursor" };
    }

    /// <summary>
    /// Turns a digit, round from 9 to 0 and back as the game's number window does, and puts the
    /// cursor on it.
    /// </summary>
    /// <param name="input">The question.</param>
    /// <param name="at">The digit.</param>
    /// <param name="steps">The steps, positive up.</param>
    /// <returns>The question.</returns>
    private static ChoiceInput Turn(ChoiceInput input, int at, int steps)
    {
        int[] digits = [.. input.Digits];
        digits[at] = (((digits[at] + steps) % 10) + 10) % 10;
        return input with { Digits = digits, Cursor = at, Cue = "cursor" };
    }

    /// <summary>
    /// Sets the digit under the cursor to one typed, and moves the cursor one right.
    /// </summary>
    /// <param name="input">The question.</param>
    /// <param name="digit">The digit typed.</param>
    /// <returns>The question.</returns>
    private static ChoiceInput Typed(ChoiceInput input, int digit)
    {
        int[] digits = [.. input.Digits];
        digits[input.Cursor] = digit;
        return input with { Digits = digits, Cursor = Math.Min(input.Cursor + 1, digits.Length - 1), Cue = "cursor" };
    }

    /// <summary>
    /// Gives a question its answer.
    /// </summary>
    /// <param name="input">The question.</param>
    /// <param name="answer">The answer.</param>
    /// <param name="cue">The sound.</param>
    /// <returns>The question, answered.</returns>
    private static ChoiceInput Answered(ChoiceInput input, int answer, string cue) => input with { Answer = answer, Cue = cue };

    /// <summary>
    /// Puts a question off to answer later, as cancel does where it answers nothing.
    /// </summary>
    /// <param name="input">The question.</param>
    /// <returns>The question, put off.</returns>
    private static ChoiceInput PutOff(ChoiceInput input) => input with { Later = true, Cue = "cancel" };

    /// <summary>
    /// Makes a question that lists its answers, scrolled to the row it starts on.
    /// </summary>
    /// <param name="kind">The input.</param>
    /// <param name="title">The title.</param>
    /// <param name="keys">The key line's entries.</param>
    /// <param name="result">What the last present did.</param>
    /// <param name="rows">The rows.</param>
    /// <param name="cancel">What cancel answers.</param>
    /// <param name="index">The row it starts on.</param>
    /// <param name="visible">The rows the screen has room for.</param>
    /// <returns>The question.</returns>
    private static ChoiceInput List(ChoiceInputKind kind, string title, IReadOnlyList<ChoiceInputKey> keys, string result, IReadOnlyList<ChoiceInputRow> rows, int? cancel, int index, int visible) =>
        new(kind, title, keys, result, rows, [], index, TopFor(index, 0, visible), visible, cancel, null, null);

    /// <summary>
    /// Lists items as rows, with the row of no item last.
    /// </summary>
    /// <param name="items">The items.</param>
    /// <param name="none">The name of the row of no item.</param>
    /// <returns>The rows.</returns>
    private static List<ChoiceInputRow> RowsOf(IReadOnlyList<ChoiceInputItem> items, string none)
    {
        ArgumentNullException.ThrowIfNull(items);
        List<ChoiceInputRow> rows = [.. items.Select(item => new ChoiceInputRow(item.Id, item.Name, item.Count, item.Description, false))];
        rows.Add(new ChoiceInputRow(Nothing, none, null, string.Empty, true));
        return rows;
    }

    /// <summary>
    /// Finds the first row shown so the cursor's row is in view, moving the list as little as it can.
    /// </summary>
    /// <param name="cursor">The cursor's row.</param>
    /// <param name="top">The first row shown before.</param>
    /// <param name="visible">The rows the screen has room for.</param>
    /// <returns>The first row shown.</returns>
    private static int TopFor(int cursor, int top, int visible) => Math.Max(0, Math.Clamp(top, cursor - visible + 1, cursor));

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
