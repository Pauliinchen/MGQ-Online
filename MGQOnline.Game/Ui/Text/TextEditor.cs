//----------------------------------------------------------------
//  TextEditor.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;

namespace MGQOnline.Game.Ui.Text;

/// <summary>
/// What typing one character did.
/// </summary>
public enum EditOutcome
{
    /// <summary>Nothing: a control character, or a Backspace at the start.</summary>
    None,

    /// <summary>Enter, which the box's owner acts on.</summary>
    Enter,

    /// <summary>Escape, which the box's owner acts on.</summary>
    Escape,

    /// <summary>Tab, which types nothing; the chat takes a name with it.</summary>
    Tab,

    /// <summary>A character went in at the cursor.</summary>
    Typed,

    /// <summary>Backspace removed the character before the cursor.</summary>
    Erased,

    /// <summary>A character the box does not take: too many, or one it does not allow.</summary>
    Refused,
}

/// <summary>
/// The keys of a frame that type nothing, as the box's owner reads them.
/// </summary>
[Flags]
public enum EditKeys
{
    /// <summary>No key.</summary>
    None = 0,

    /// <summary>Left went down or repeats.</summary>
    Left = 1,

    /// <summary>Right went down or repeats.</summary>
    Right = 2,

    /// <summary>Up went down or repeats.</summary>
    Up = 4,

    /// <summary>Down went down or repeats.</summary>
    Down = 8,

    /// <summary>Home went down.</summary>
    Home = 16,

    /// <summary>End went down.</summary>
    End = 32,

    /// <summary>Delete went down.</summary>
    Delete = 64,
}

/// <summary>
/// A text being typed, as every text box of the mod edits it (MGQ_MpUi::TextEdit in the scripts
/// before): the text, the cursor in it, the keys that type, move the cursor and remove characters,
/// the blinking, and which part a box shows around the cursor.
/// </summary>
public sealed class TextEditor
{
    /// <summary>
    /// Ticks the cursor stays shown, then hidden, while it blinks.
    /// </summary>
    public const int BlinkTicks = 30;

    /// <summary>
    /// The code point of Enter as typed.
    /// </summary>
    private const int EnterPoint = '\r';

    /// <summary>
    /// The code point of Escape as typed.
    /// </summary>
    private const int EscapePoint = 0x1B;

    /// <summary>
    /// The code point of Backspace as typed.
    /// </summary>
    private const int BackspacePoint = '\b';

    /// <summary>
    /// The code point of Tab as typed.
    /// </summary>
    private const int TabPoint = '\t';

    /// <summary>
    /// The text's code points.
    /// </summary>
    private readonly List<int> _text;

    /// <summary>
    /// The first code point a box of one line shows.
    /// </summary>
    private int _first;

    /// <summary>
    /// The first line a box of several lines shows.
    /// </summary>
    private int _top;

    /// <summary>
    /// Ticks since the cursor last moved.
    /// </summary>
    private int _blink;

    /// <summary>
    /// Starts editing a text, the cursor at its end.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="maxChars">The most characters it takes, null for any number.</param>
    /// <param name="allowed">What every typed character must match, null for any.</param>
    public TextEditor(string text, int? maxChars = null, Regex? allowed = null)
    {
        _text = [.. CodePoints.Of(text)];
        MaxChars = maxChars;
        Allowed = allowed;
        Cursor = _text.Count;
    }

    /// <summary>
    /// Gets the most characters the text takes, null for any number.
    /// </summary>
    public int? MaxChars { get; }

    /// <summary>
    /// Gets what every typed character must match, null for any.
    /// </summary>
    public Regex? Allowed { get; }

    /// <summary>
    /// Gets the code points before the cursor.
    /// </summary>
    public int Cursor { get; private set; }

    /// <summary>
    /// Gets the text.
    /// </summary>
    public string Text => CodePoints.Text([.. _text]);

    /// <summary>
    /// Gets the text's code points.
    /// </summary>
    public IReadOnlyList<int> Points => _text;

    /// <summary>
    /// Gets whether the blinking cursor shows.
    /// </summary>
    public bool CursorShown => _blink / BlinkTicks % 2 == 0;

    /// <summary>
    /// Types one character at the cursor; Backspace removes the character before it.
    /// </summary>
    /// <param name="point">The character, '\r' for Enter, 0x1B for Escape, '\b' for Backspace.</param>
    /// <returns>What it did.</returns>
    public EditOutcome Type(int point)
    {
        switch (point)
        {
            case EnterPoint:
                return EditOutcome.Enter;
            case EscapePoint:
                return EditOutcome.Escape;
            case TabPoint:
                return EditOutcome.Tab;
            case BackspacePoint:
                if (Cursor == 0)
                {
                    return EditOutcome.None;
                }

                _text.RemoveAt(Cursor - 1);
                MoveTo(Cursor - 1);
                return EditOutcome.Erased;
        }

        if (CodePoints.IsControl(point))
        {
            return EditOutcome.None;
        }

        if ((MaxChars is int most && _text.Count >= most) || (Allowed is not null && !Allowed.IsMatch(CodePoints.Text([point]))))
        {
            return EditOutcome.Refused;
        }

        _text.Insert(Cursor, point);
        MoveTo(Cursor + 1);
        return EditOutcome.Typed;
    }

    /// <summary>
    /// Replaces the text and puts the cursor where it goes.
    /// </summary>
    /// <param name="text">The new text.</param>
    /// <param name="cursor">The cursor's new place.</param>
    public void Edit(string text, int cursor)
    {
        _text.Clear();
        _text.AddRange(CodePoints.Of(text));
        MoveTo(cursor);
    }

    /// <summary>
    /// Follows a frame's keys that type nothing: left and right move the cursor, Home and End put
    /// it at the start or the end, Delete removes the character after it, and in a box of several
    /// lines up and down move it a line. The cursor blinks, and shows at once after anything moved it.
    /// </summary>
    /// <param name="keys">The keys.</param>
    /// <param name="spans">The lines of a box of several lines, null for a box of one line.</param>
    /// <returns>Whether the text or the cursor changed.</returns>
    public bool Follow(EditKeys keys, IReadOnlyList<TextSpan>? spans = null)
    {
        _blink++;
        int before = Cursor;
        int length = _text.Count;
        if (keys.HasFlag(EditKeys.Left))
        {
            MoveTo(Cursor - 1);
        }

        if (keys.HasFlag(EditKeys.Right))
        {
            MoveTo(Cursor + 1);
        }

        if (spans is not null)
        {
            MoveLine(spans, (keys.HasFlag(EditKeys.Down) ? 1 : 0) - (keys.HasFlag(EditKeys.Up) ? 1 : 0));
        }

        if (keys.HasFlag(EditKeys.Home))
        {
            MoveTo(0);
        }

        if (keys.HasFlag(EditKeys.End))
        {
            MoveTo(_text.Count);
        }

        if (keys.HasFlag(EditKeys.Delete) && Cursor < _text.Count)
        {
            _text.RemoveAt(Cursor);
            MoveTo(Cursor);
        }

        return before != Cursor || length != _text.Count;
    }

    /// <summary>
    /// Moves the cursor within the text and shows it at once.
    /// </summary>
    /// <param name="cursor">The place.</param>
    public void MoveTo(int cursor)
    {
        Cursor = Math.Clamp(cursor, 0, _text.Count);
        _blink = 0;
    }

    /// <summary>
    /// Moves the cursor of a box of several lines a line up or down, as far into that line as it is
    /// into its own; it stays where it is at the first and the last line.
    /// </summary>
    /// <param name="spans">The lines.</param>
    /// <param name="step">1 for the line below, -1 for the one above, 0 for neither.</param>
    public void MoveLine(IReadOnlyList<TextSpan> spans, int step)
    {
        ArgumentNullException.ThrowIfNull(spans);
        int line = TextLayout.SpanOf(spans, Cursor);
        int target = line + step;
        if (step == 0 || target < 0 || target >= spans.Count)
        {
            return;
        }

        // The place after the last character of a line that is not the last is the next line's start.
        int last = Math.Max(spans[target].Length - (target < spans.Count - 1 ? 1 : 0), 0);
        MoveTo(spans[target].Start + Math.Min(Cursor - spans[line].Start, last));
    }

    /// <summary>
    /// Picks the part of the text a box of one line shows: as much as fits, moved only as far as
    /// the cursor needs to stay in sight.
    /// </summary>
    /// <param name="glyphs">The font the box draws in.</param>
    /// <param name="width">The width the text may take.</param>
    /// <param name="mask">The character shown for each of the text's, such as '*' for a password; null for the text itself.</param>
    /// <returns>The first character shown and how many are shown.</returns>
    public TextSpan Visible(FontGlyphs glyphs, int width, int? mask = null)
    {
        int[] display = mask is int star ? Array.ConvertAll(_text.ToArray(), _ => star) : [.. _text];
        if (Cursor < _first)
        {
            _first = Cursor;
        }

        while (_first < Cursor && TextLayout.Width(glyphs, display.AsSpan(_first, Cursor - _first)) > width)
        {
            _first++;
        }

        int last = display.Length;
        while (last > Cursor && TextLayout.Width(glyphs, display.AsSpan(_first, last - _first)) > width)
        {
            last--;
        }

        return new TextSpan(_first, last - _first);
    }

    /// <summary>
    /// Picks the first line a box of several lines shows: moved only as far as the cursor's line
    /// needs to stay in sight.
    /// </summary>
    /// <param name="spans">The lines.</param>
    /// <param name="rows">The lines the box shows at once.</param>
    /// <returns>The first line shown.</returns>
    public int FirstLine(IReadOnlyList<TextSpan> spans, int rows)
    {
        int line = TextLayout.SpanOf(spans, Cursor);
        _top = Math.Max(Math.Min(_top, line), line - rows + 1);
        return _top;
    }

    /// <summary>
    /// Scrolls a box of several lines within its lines, and moves the cursor along onto the nearest
    /// line in sight once it left them, as far into that line as it is into its own.
    /// </summary>
    /// <param name="spans">The lines.</param>
    /// <param name="rows">The lines the box shows at once.</param>
    /// <param name="step">Lines to scroll down, a negative number to scroll up.</param>
    /// <returns>Whether it scrolled.</returns>
    public bool ScrollLines(IReadOnlyList<TextSpan> spans, int rows, int step)
    {
        ArgumentNullException.ThrowIfNull(spans);
        int top = Math.Max(Math.Min(FirstLine(spans, rows) + step, spans.Count - rows), 0);
        if (top == _top)
        {
            return false;
        }

        _top = top;
        int line = TextLayout.SpanOf(spans, Cursor);
        MoveLine(spans, Math.Min(Math.Max(line, top), top + rows - 1) - line);
        return true;
    }
}
