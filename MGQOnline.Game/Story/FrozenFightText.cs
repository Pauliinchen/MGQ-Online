//----------------------------------------------------------------
//  FrozenFightText.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using MGQOnline.Bridge.Ruby;

namespace MGQOnline.Game.Story;

/// <summary>
/// Writes and reads a frozen raid boss fight as the relay's story tracks keep it, the value of its
/// key <c>f&lt;troop&gt;</c>: <c>site|outer site|scene|map|rows|blocked events|spot|held keys</c>,
/// rows separated by commas and their 13 fields by colons, the events and the spot's four numbers
/// by dots, the held keys by commas (<c>s&lt;id&gt;~T</c>, <c>v&lt;id&gt;~&lt;value&gt;</c>,
/// <c>x&lt;map&gt;.&lt;event&gt;.&lt;letter&gt;~T</c>), every free text escaped byte by byte as
/// <c>%XX</c>.
/// </summary>
/// <remarks>
/// Games of earlier releases wrote these texts, which the relay keeps; the written form must stay
/// byte for byte the one they wrote and read.
/// </remarks>
public static partial class FrozenFightText
{
    /// <summary>
    /// The text of a fight that ended, which the relay keeps in place of the fight.
    /// </summary>
    public const string EndedText = "0";

    /// <summary>
    /// The longest fight the relay keeps (<c>maxFreezeLength</c> of Relay/core/story.js).
    /// </summary>
    public const int MaxLength = 65_536;

    /// <summary>
    /// The sprite rows one fight has at most.
    /// </summary>
    public const int MaxRows = 64;

    /// <summary>
    /// The held keys one fight has at most.
    /// </summary>
    public const int MaxHeld = 512;

    /// <summary>
    /// The fields of a sprite row.
    /// </summary>
    public const int RowSize = 13;

    /// <summary>
    /// The place of the character's name among a sprite row's fields, the only text among them.
    /// </summary>
    private const int RowName = 5;

    /// <summary>
    /// The places of a sprite row's boss and hide flags, each 1 or 0.
    /// </summary>
    private static readonly int[] RowFlags = [11, 12];

    /// <summary>
    /// The largest number a fight's text carries.
    /// </summary>
    private const long MaxInteger = 2_147_483_647;

    /// <summary>
    /// Reads UTF-8 and refuses bytes that are none.
    /// </summary>
    private static readonly UTF8Encoding StrictUtf8 = new(false, true);

    /// <summary>
    /// Writes a fight, its troop left out, which its key names.
    /// </summary>
    /// <param name="entry">{"site" and "outer" (as <see cref="StoryPlain"/> names a site), "scene", "tableau" ([map, rows, blocked events]), "spot",
    /// "held" ([kind, key, value] each, see <see cref="StoryPlain"/>)}.</param>
    /// <returns>The text, <see langword="null"/> for an entry that is none or longer than the relay keeps.</returns>
    public static string? Write(RubyHash entry)
    {
        ArgumentNullException.ThrowIfNull(entry);
        try
        {
            string site = StoryPlain.SiteText(entry["site"]);
            string outer = StoryPlain.SiteText(entry["outer"]);
            if (!SitePattern().IsMatch(site) || !SitePattern().IsMatch(outer))
            {
                return null;
            }

            RubyArray tableau = entry["tableau"].AsArray();
            string[] rows = [.. tableau[1].AsArray().Select(row => RowText(row.AsArray()))];
            if (rows.Any(row => row.Length == 0))
            {
                return null;
            }

            string fields = string.Join('|', site, outer, entry["scene"] is RubyNil or RubyBool { Flag: false } ? "0" : "1", Number(tableau[0]),
                string.Join(',', rows), string.Join('.', tableau[2].AsArray().Select(Number)), string.Join('.', entry["spot"].AsArray().Select(Number)),
                string.Join(',', entry["held"].AsArray().Select(HeldText).OfType<string>()));
            return fields.Length > MaxLength ? null : fields;
        }
        catch (RubyValueException)
        {
            return null;
        }
    }

    /// <summary>
    /// Reads a fight, see <see cref="Write"/>.
    /// </summary>
    /// <param name="troop">The troop its key names.</param>
    /// <param name="text">The text.</param>
    /// <returns>{"troop", "site", "outer", "scene", "tableau", "spot", "held"}, <see langword="null"/>
    /// for a text that is none.</returns>
    public static RubyHash? Read(int troop, string text)
    {
        ArgumentNullException.ThrowIfNull(text);
        string[] fields = text.Split('|');
        if (troop <= 0 || fields.Length != 8 || !SitePattern().IsMatch(fields[0]) || !SitePattern().IsMatch(fields[1]) || fields[2] is not ("0" or "1"))
        {
            return null;
        }

        RubyArray?[] rows = [.. Parts(fields[4], ',').Select(RowOf)];
        long? map = Integer(fields[3]);
        if (map is null || rows.Length is < 1 or > MaxRows || rows.Any(row => row is null) || rows.Count(row => row![RowFlags[0]].AsLong() == 1) != 1)
        {
            return null;
        }

        long?[] blocked = [.. Parts(fields[5], '.').Select(Integer)];
        long?[] spot = [.. Parts(fields[6], '.').Select(Integer)];
        RubyArray?[] held = [.. Parts(fields[7], ',').Select(HeldOf)];
        if (blocked.Any(id => id is null) || spot.Length != 4 || spot.Any(value => value is null) || held.Length > MaxHeld || held.Any(item => item is null))
        {
            return null;
        }

        return new RubyHash
        {
            { "troop", troop },
            { "site", StoryPlain.SiteOf(fields[0]) },
            { "outer", StoryPlain.SiteOf(fields[1]) },
            { "scene", fields[2] == "1" },
            { "tableau", new RubyArray { map.Value, new RubyArray(rows.Select(row => (RubyValue)row!)), Numbers(blocked) } },
            { "spot", Numbers(spot) },
            { "held", new RubyArray(held.Select(item => (RubyValue)item!)) },
        };
    }

    /// <summary>
    /// Writes a sprite row, its character's name escaped.
    /// </summary>
    /// <param name="row">The row's 13 fields.</param>
    /// <returns>The text, empty for a row that is none.</returns>
    /// <exception cref="RubyValueException">A field is no number the text carries.</exception>
    private static string RowText(RubyArray row) => row.Count == RowSize
        ? string.Join(':', row.Select((value, place) => place == RowName ? Escape(value is RubyString ? value.AsBytes().Span : Encoding.UTF8.GetBytes(value.IsNil ? string.Empty : value.ToString() ?? string.Empty)) : Number(value)))
        : string.Empty;

    /// <summary>
    /// Writes a held key.
    /// </summary>
    /// <param name="item">[kind, key, value], see <see cref="StoryPlain"/>.</param>
    /// <returns>The text, <see langword="null"/> for a variable whose value no story carries.</returns>
    /// <exception cref="RubyValueException">The key is no key the text carries.</exception>
    private static string? HeldText(RubyValue item)
    {
        RubyArray fields = item.AsArray();
        string flag = fields[2] is RubyNil or RubyBool { Flag: false } ? "F" : "T";
        return fields[0].AsInt() switch
        {
            StoryPlain.SwitchKind => $"s{Number(fields[1])}~{flag}",
            StoryPlain.VariableKind => StoryPlain.VariableText(fields[2] is RubyNil ? 0 : fields[2]) is { } value ? $"v{Number(fields[1])}~{Escape(Encoding.UTF8.GetBytes(value))}" : null,
            StoryPlain.SelfSwitchKind => $"x{Number(fields[1].AsArray()[0])}.{Number(fields[1].AsArray()[1])}.{Escape(fields[1].AsArray()[2].AsBytes().Span)}~{flag}",
            _ => null,
        };
    }

    /// <summary>
    /// Reads a sprite row, see <see cref="RowText"/>.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The row, <see langword="null"/> for a text that is none.</returns>
    private static RubyArray? RowOf(string text)
    {
        string[] fields = text.Split(':');
        if (fields.Length != RowSize)
        {
            return null;
        }

        var row = new RubyArray();
        for (int place = 0; place < RowSize; place++)
        {
            RubyValue? field = place == RowName ? (Unescape(fields[place]) is { } name ? (RubyValue)name : null) : Integer(fields[place]) is { } number ? (RubyValue)number : null;
            if (field is null || (RowFlags.Contains(place) && field.AsLong() is not (0 or 1)))
            {
                return null;
            }

            row.Add(field);
        }

        return row;
    }

    /// <summary>
    /// Reads a held key, see <see cref="HeldText"/>.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>[kind, key, value], <see langword="null"/> for a text that is none.</returns>
    private static RubyArray? HeldOf(string text)
    {
        int tilde = text.IndexOf('~', StringComparison.Ordinal);
        if (text.Length == 0 || tilde < 1 || text[0] is not ('s' or 'v' or 'x'))
        {
            return null;
        }

        string key = text[1..tilde];
        string value = text[(tilde + 1)..];
        bool flag = value == "T";
        switch (text[0])
        {
            case 's':
                return Integer(key) is > 0 and { } id && value is "T" or "F" ? [StoryPlain.SwitchKind, id, flag] : null;
            case 'v':
                string? written = Unescape(value);
                RubyValue? read = written is { Length: > 0 } ? StoryPlain.VariableOf(written) : null;
                return Integer(key) is > 0 and { } variable && read is not null && (written![0] != 's' || ValidText(written[1..])) ? [StoryPlain.VariableKind, variable, read] : null;
            default:
                string[] parts = key.Split('.');
                if (parts.Length != 3 || value is not ("T" or "F") || Integer(parts[0]) is not { } map || Integer(parts[1]) is not { } eventId || Unescape(parts[2]) is not { Length: > 0 } letter)
                {
                    return null;
                }

                return [StoryPlain.SelfSwitchKind, new RubyArray { map, eventId, letter }, flag];
        }
    }

    /// <summary>
    /// Tells whether a text's Base64 holds UTF-8.
    /// </summary>
    /// <param name="base64">The Base64.</param>
    /// <returns>Whether it does.</returns>
    private static bool ValidText(string base64)
    {
        try
        {
            StrictUtf8.GetString(Convert.FromBase64String(base64));
            return true;
        }
        catch (Exception ex) when (ex is FormatException or ArgumentException)
        {
            return false;
        }
    }

    /// <summary>
    /// Escapes a free text: each byte but letters, digits and <c>_$!-</c> as <c>%XX</c>, so no
    /// separator of the text appears in it.
    /// </summary>
    /// <param name="bytes">The text's bytes.</param>
    /// <returns>The escaped text, of plain ASCII.</returns>
    private static string Escape(ReadOnlySpan<byte> bytes)
    {
        var escaped = new StringBuilder(bytes.Length);
        foreach (byte value in bytes)
        {
            if (value is (>= (byte)'A' and <= (byte)'Z') or (>= (byte)'a' and <= (byte)'z') or (>= (byte)'0' and <= (byte)'9') or (byte)'_' or (byte)'$' or (byte)'!' or (byte)'-')
            {
                escaped.Append((char)value);
            }
            else
            {
                escaped.Append('%').Append(value.ToString("X2", CultureInfo.InvariantCulture));
            }
        }

        return escaped.ToString();
    }

    /// <summary>
    /// Reads an escaped text, see <see cref="Escape"/>.
    /// </summary>
    /// <param name="text">The escaped text.</param>
    /// <returns>The text, <see langword="null"/> for one not escaped so or no UTF-8.</returns>
    private static string? Unescape(string text)
    {
        if (!EscapedPattern().IsMatch(text))
        {
            return null;
        }

        var bytes = new List<byte>(text.Length);
        for (int place = 0; place < text.Length; place++)
        {
            if (text[place] == '%')
            {
                bytes.Add(byte.Parse(text.AsSpan(place + 1, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture));
                place += 2;
            }
            else
            {
                bytes.Add((byte)text[place]);
            }
        }

        try
        {
            return StrictUtf8.GetString([.. bytes]);
        }
        catch (ArgumentException)
        {
            return null;
        }
    }

    /// <summary>
    /// Writes a number of the text.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>Its digits.</returns>
    /// <exception cref="RubyValueException">The value is no whole number within <see cref="MaxInteger"/>.</exception>
    private static string Number(RubyValue value) => value is RubyInteger number && System.Numerics.BigInteger.Abs(number.Value) <= MaxInteger
        ? number.Value.ToString(CultureInfo.InvariantCulture)
        : throw new RubyValueException($"{value} is no number a frozen fight carries.");

    /// <summary>
    /// Reads a number of the text.
    /// </summary>
    /// <param name="text">The digits.</param>
    /// <returns>The number, <see langword="null"/> for none or one past <see cref="MaxInteger"/>.</returns>
    private static long? Integer(string text) =>
        IntegerPattern().IsMatch(text) && long.TryParse(text, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out long value) && Math.Abs(value) <= MaxInteger ? value : null;

    /// <summary>
    /// Splits a field into its parts, an empty field into none.
    /// </summary>
    /// <param name="field">The field.</param>
    /// <param name="separator">What separates its parts.</param>
    /// <returns>The parts.</returns>
    private static string[] Parts(string field, char separator) => field.Length == 0 ? [] : field.Split(separator);

    /// <summary>
    /// Writes numbers as a list.
    /// </summary>
    /// <param name="numbers">The numbers, none of them missing.</param>
    /// <returns>The list.</returns>
    private static RubyArray Numbers(IEnumerable<long?> numbers) => new(numbers.Select(number => (RubyValue)number!.Value));

    /// <summary>
    /// What a site looks like: a map event's page or a common event.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"\A(map:[0-9]+:[0-9]+:[0-9]+|ce:[0-9]+)\z")]
    private static partial Regex SitePattern();

    /// <summary>
    /// What an escaped text looks like.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"\A(?:[A-Za-z0-9_$!\-]|%[0-9A-Fa-f]{2})*\z")]
    private static partial Regex EscapedPattern();

    /// <summary>
    /// What a number of the text looks like.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"\A-?[0-9]{1,10}\z")]
    private static partial Regex IntegerPattern();
}
