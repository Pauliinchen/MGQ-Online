//----------------------------------------------------------------
//  Form.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Took the facts as they stand when the player acts
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using MGQOnline.Game.Ruby;

namespace MGQOnline.Game.Forms;

/// <summary>
/// A page of a form: its title and its fields, laid out in rows, of which the rules show some.
/// </summary>
/// <param name="Title">What the page is called.</param>
/// <param name="Fields">Every field, in the order the cursor visits them.</param>
public sealed record FormPage(string Title, IReadOnlyList<FormField> Fields);

/// <summary>
/// A form being filled in: its pages, which share one set of values, what each field holds, which
/// checkboxes the player ticked, and the facts it was opened with.
/// </summary>
/// <remarks>
/// A value is a <see cref="string"/> for a text box or the mods, a <see cref="bool"/> for a checkbox,
/// an <see cref="int"/> for a switch's outcome or a save's index, or <see langword="null"/>.
/// </remarks>
public sealed class Form
{
    /// <summary>
    /// The page every form has, the one it opens on.
    /// </summary>
    public const string MainPage = "main";

    /// <summary>
    /// What a save that must be chosen says while none is.
    /// </summary>
    public const string SaveMissing = "Choose the save its players start from.";

    /// <summary>
    /// What a world id that is none says.
    /// </summary>
    public const string IdRefused = "That is not a world id. Copy it again from the world's creator.";

    /// <summary>
    /// The characters of a world id.
    /// </summary>
    public const int IdLength = 32;

    /// <summary>
    /// The most digits a number box reads before it is out of every range.
    /// </summary>
    private const int MaxDigits = 9;

    /// <summary>
    /// What each field holds, by key.
    /// </summary>
    private readonly Dictionary<string, object?> _values = new(StringComparer.Ordinal);

    /// <summary>
    /// The checkboxes the player ticked or unticked, which no rule moves from then on.
    /// </summary>
    private readonly HashSet<string> _ticked = new(StringComparer.Ordinal);

    /// <summary>
    /// The facts that hold, such as "discord".
    /// </summary>
    private readonly HashSet<string> _facts;

    /// <summary>
    /// Creates a form.
    /// </summary>
    /// <param name="kind">What form it is, such as "create".</param>
    /// <param name="pages">Its pages by name, <see cref="MainPage"/> among them.</param>
    /// <param name="values">What each field holds at first, by key.</param>
    /// <param name="facts">The facts it was opened with that hold, such as "discord".</param>
    public Form(string kind, IReadOnlyDictionary<string, FormPage> pages, IEnumerable<KeyValuePair<string, object?>> values, IEnumerable<string>? facts = null)
    {
        Kind = kind;
        Pages = pages.ContainsKey(MainPage) ? pages : throw new ArgumentException("A form needs a main page.", nameof(pages));
        foreach ((string key, object? value) in values)
        {
            _values[key] = value;
        }

        _facts = new HashSet<string>(facts ?? [], StringComparer.Ordinal);
    }

    /// <summary>
    /// Gets what form it is, such as "create".
    /// </summary>
    public string Kind { get; }

    /// <summary>
    /// Gets its pages by name.
    /// </summary>
    public IReadOnlyDictionary<string, FormPage> Pages { get; }

    /// <summary>
    /// Gets the facts it was opened with that hold.
    /// </summary>
    public IReadOnlySet<string> Facts => _facts;

    /// <summary>
    /// Gets what each field holds, by key.
    /// </summary>
    public IReadOnlyDictionary<string, object?> Values => _values;

    /// <summary>
    /// Replaces the facts that hold, as they stand when the player acts.
    /// </summary>
    /// <param name="facts">The facts that hold now.</param>
    public void Know(IEnumerable<string> facts)
    {
        _facts.Clear();
        _facts.UnionWith(facts);
    }

    /// <summary>
    /// Lists the fields of a page that are part of the form now, in the order the cursor visits them.
    /// </summary>
    /// <param name="page">The page.</param>
    /// <returns>The fields.</returns>
    public IReadOnlyList<FormField> Fields(string page = MainPage) =>
        PageOf(page).Fields.Where(field => field.Shows is null || field.Shows.Holds(this)).ToList();

    /// <summary>
    /// Finds a field of a page that is part of the form now.
    /// </summary>
    /// <param name="page">The page.</param>
    /// <param name="key">The field's key.</param>
    /// <returns>The field, <see langword="null"/> when none shows.</returns>
    public FormField? Field(string page, string key) => Fields(page).FirstOrDefault(field => field.Key == key);

    /// <summary>
    /// Tells whether a field can be used, which one whose rule does not hold cannot.
    /// </summary>
    /// <param name="field">The field.</param>
    /// <returns>Whether it can.</returns>
    public bool IsEnabled(FormField field) => field.Needs is null || field.Needs.Holds(this);

    /// <summary>
    /// Reads a switch's outcome, or a save's index.
    /// </summary>
    /// <param name="key">The field's key.</param>
    /// <returns>The index, 0 for none, as Ruby's <c>nil.to_i</c>.</returns>
    public int ChoiceOf(string key) => _values.GetValueOrDefault(key) is int index ? index : 0;

    /// <summary>
    /// Tells whether a checkbox is ticked.
    /// </summary>
    /// <param name="key">The checkbox's key.</param>
    /// <returns>Whether it holds true.</returns>
    public bool IsTicked(string key) => _values.GetValueOrDefault(key) is true;

    /// <summary>
    /// Reads a field's value as text.
    /// </summary>
    /// <param name="key">The field's key.</param>
    /// <returns>The text, empty for none.</returns>
    public string TextOf(string key) => _values.GetValueOrDefault(key) switch
    {
        string text => text,
        int number => number.ToString(CultureInfo.InvariantCulture),
        bool flag => flag ? "true" : "false",
        _ => "",
    };

    /// <summary>
    /// Sets what a field holds.
    /// </summary>
    /// <param name="key">The field's key.</param>
    /// <param name="value">The value, see <see cref="Form"/>.</param>
    public void Set(string key, object? value) => _values[key] = value;

    /// <summary>
    /// Moves a switch to its next or its previous outcome, round, and lets the checkboxes that follow
    /// a rule follow it.
    /// </summary>
    /// <param name="field">The switch.</param>
    /// <param name="step">1 for the next outcome, -1 for the previous.</param>
    /// <returns>The outcome's index now.</returns>
    public int Turn(FormField field, int step)
    {
        int count = Math.Max(field.Choices.Count, 1);
        int index = (((ChoiceOf(field.Key) + step) % count) + count) % count;
        _values[field.Key] = index;
        foreach (FormField follower in Pages.Values.SelectMany(page => page.Fields).Where(candidate => candidate.Follows is not null))
        {
            if (_values.ContainsKey(follower.Key) && !_ticked.Contains(follower.Key))
            {
                _values[follower.Key] = follower.Follows!.Holds(this);
            }
        }

        return index;
    }

    /// <summary>
    /// Ticks a checkbox, or unticks it, which from then on keeps what the player chose.
    /// </summary>
    /// <param name="key">The checkbox's key.</param>
    /// <returns>Whether it is ticked now.</returns>
    public bool Tick(string key)
    {
        _ticked.Add(key);
        bool ticked = !IsTicked(key);
        _values[key] = ticked;
        return ticked;
    }

    /// <summary>
    /// Checks what a text box holds, and tidies it.
    /// </summary>
    /// <param name="field">The text box.</param>
    /// <param name="text">What it holds.</param>
    /// <returns>The tidied text, and why it is not accepted, <see langword="null"/> when it is.</returns>
    public (string Text, string? Reason) Check(FormField field, string text)
    {
        switch (field.Kind)
        {
            case FieldKind.Number:
                return NumberOf(text) is { } number && number >= field.Min && number <= field.Max
                    ? (number.ToString(CultureInfo.InvariantCulture), null)
                    : (text, string.Create(CultureInfo.InvariantCulture, $"{field.Label} must be a number from {field.Min} to {field.Max}."));
            case FieldKind.Id:
                string id = RubyAscii.Downcase(RubyAscii.Strip(text));
                return IsWorldId(id) ? (id, null) : (text, IdRefused);
            case FieldKind.Password:
                // A password keeps its spaces, since the others type it exactly, and may be empty.
                return (text, null);
            default:
                string tidy = RubyAscii.Strip(text);
                return tidy.Length == 0 && !MayBeEmpty(field) ? (text, field.EmptyText) : (tidy, null);
        }
    }

    /// <summary>
    /// Finds the first field of a page that keeps the form from being sent.
    /// </summary>
    /// <param name="page">The page.</param>
    /// <returns>The field and why, <see langword="null"/> when the form can be sent.</returns>
    public (FormField Field, string Reason)? Problem(string page = MainPage)
    {
        foreach (FormField field in Fields(page))
        {
            if (!IsEnabled(field))
            {
                continue;
            }

            string? reason = field.Typed ? Check(field, TextOf(field.Key)).Reason : null;
            reason ??= field.Kind == FieldKind.Save && !field.Optional && _values.GetValueOrDefault(field.Key) is null ? SaveMissing : null;
            if (reason is not null)
            {
                return (field, reason);
            }
        }

        return null;
    }

    /// <summary>
    /// Puts back into the form every text box of a page it uses as <see cref="Check"/> tidies it.
    /// </summary>
    /// <param name="page">The page.</param>
    public void Tidy(string page = MainPage)
    {
        foreach (FormField field in Fields(page).Where(field => field.Typed && IsEnabled(field)))
        {
            _values[field.Key] = Check(field, TextOf(field.Key)).Text;
        }
    }

    /// <summary>
    /// Finds a page.
    /// </summary>
    /// <param name="page">Its name.</param>
    /// <returns>The page.</returns>
    /// <exception cref="ArgumentException">The form has no such page.</exception>
    private FormPage PageOf(string page) =>
        Pages.TryGetValue(page, out FormPage? found) ? found : throw new ArgumentException($"The form {Kind} has no page {page}.", nameof(page));

    /// <summary>
    /// Tells whether a text box may stay empty.
    /// </summary>
    /// <param name="field">The text box.</param>
    /// <returns>Whether it may.</returns>
    private bool MayBeEmpty(FormField field) => field.Optional || (field.EmptyOk is not null && field.EmptyOk.Holds(this));

    /// <summary>
    /// Reads a text of digits 0 to 9 only.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The number, <see langword="null"/> for another text; <see cref="int.MaxValue"/> for one too long to be in any range.</returns>
    private static int? NumberOf(string text)
    {
        if (text.Length == 0 || !text.All(character => character is >= '0' and <= '9'))
        {
            return null;
        }

        string digits = text.TrimStart('0');
        return digits.Length > MaxDigits ? int.MaxValue : digits.Length == 0 ? 0 : int.Parse(digits, CultureInfo.InvariantCulture);
    }

    /// <summary>
    /// Tells whether a text is a world's id: 32 of the digits and a to f.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>Whether it is.</returns>
    private static bool IsWorldId(string text) =>
        text.Length == IdLength && text.All(character => character is (>= '0' and <= '9') or (>= 'a' and <= 'f'));
}
