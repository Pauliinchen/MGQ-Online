//----------------------------------------------------------------
//  FormField.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;

namespace MGQOnline.Game.Forms;

/// <summary>
/// What kind of field a form's field is, as the scripts name it.
/// </summary>
public enum FieldKind
{
    /// <summary>A text box of one line.</summary>
    Text,

    /// <summary>A text box whose text shows as stars and keeps its spaces.</summary>
    Password,

    /// <summary>A text box of a whole number in the field's range.</summary>
    Number,

    /// <summary>A text box of a world's id.</summary>
    Id,

    /// <summary>A box of several lines.</summary>
    Area,

    /// <summary>A checkbox.</summary>
    Check,

    /// <summary>A save to choose on the save screen, its value the save's index.</summary>
    Save,

    /// <summary>The mods picked in the mod picker, as a world's mods text.</summary>
    Mods,

    /// <summary>A switch between several outcomes, its value the outcome's index.</summary>
    Switch,

    /// <summary>A button.</summary>
    Button,
}

/// <summary>
/// Where a field sits on a row it shares with another.
/// </summary>
public enum FieldSide
{
    /// <summary>It has the row alone.</summary>
    None,

    /// <summary>It takes the row's left half.</summary>
    Left,

    /// <summary>It takes the row's right half.</summary>
    Right,
}

/// <summary>
/// The characters a text box takes, by a name the scripts map back to their typing rule.
/// </summary>
public enum FieldChars
{
    /// <summary>Any character.</summary>
    Any,

    /// <summary>The digits 0 to 9.</summary>
    Digits,

    /// <summary>The hexadecimal digits, either case.</summary>
    Hex,
}

/// <summary>
/// A field of a form: what it holds, how it is drawn and when it is part of the form.
/// </summary>
/// <param name="Key">What the form keeps its value under.</param>
/// <param name="Kind">What kind of field it is.</param>
/// <param name="Label">What it is called.</param>
/// <param name="Row">The row it is on, 0 for the first below the form's title.</param>
/// <param name="Hint">What the lines at the top of the screen say while the cursor is on it.</param>
public sealed record FormField(string Key, FieldKind Kind, string Label, int Row, string Hint)
{
    /// <summary>
    /// What a text box that must be filled in says while it is empty, unless the field names its own.
    /// </summary>
    public const string DefaultEmptyText = "This field cannot be empty.";

    /// <summary>Gets where it sits on a row it shares.</summary>
    public FieldSide Side { get; init; }

    /// <summary>Gets the longest text a text box takes, <see langword="null"/> for no limit.</summary>
    public int? MaxChars { get; init; }

    /// <summary>Gets the characters a text box takes.</summary>
    public FieldChars Allowed { get; init; }

    /// <summary>Gets what must hold for the field to be used, <see langword="null"/> for always.</summary>
    public FormRule? Needs { get; init; }

    /// <summary>Gets whether a text box may stay empty, or a save stay unchosen.</summary>
    public bool Optional { get; init; }

    /// <summary>Gets what lets a text box stay empty besides <see cref="Optional"/>, <see langword="null"/> for nothing.</summary>
    public FormRule? EmptyOk { get; init; }

    /// <summary>Gets why a text box that must be filled in is refused while empty.</summary>
    public string EmptyText { get; init; } = DefaultEmptyText;

    /// <summary>Gets the heading of the panel the field is in, <see langword="null"/> for none.</summary>
    public string? Group { get; init; }

    /// <summary>Gets how many lines a box of several lines shows.</summary>
    public int Lines { get; init; } = 1;

    /// <summary>Gets the outcomes a switch moves between, as shown.</summary>
    public IReadOnlyList<string> Choices { get; init; } = [];

    /// <summary>Gets the width of a switch's or a save's label, <see langword="null"/> for the width its window gives every label.</summary>
    public int? LabelWidth { get; init; }

    /// <summary>Gets what must hold for the field to be part of the form now, <see langword="null"/> for always.</summary>
    public FormRule? Shows { get; init; }

    /// <summary>Gets the lowest number a number box takes.</summary>
    public int Min { get; init; }

    /// <summary>Gets the highest number a number box takes.</summary>
    public int Max { get; init; }

    /// <summary>
    /// Gets the rule a checkbox's value follows after each turn of a switch, until the player ticks
    /// it, <see langword="null"/> for none.
    /// </summary>
    public FormRule? Follows { get; init; }

    /// <summary>
    /// Gets whether the field is a text box, typed into.
    /// </summary>
    public bool Typed => Kind is FieldKind.Text or FieldKind.Password or FieldKind.Number or FieldKind.Id or FieldKind.Area;
}
