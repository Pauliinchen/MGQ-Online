//----------------------------------------------------------------
//  SharedSettings.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Numerics;
using System.Text;
using MGQOnline.Game.Ruby;

namespace MGQOnline.Game.Mods;

/// <summary>
/// A value of a world's shared settings, as its pair writes it with its type.
/// </summary>
/// <param name="Type">'i' (whole number), 'f' (decimal), 'b' (true or false), 'y' (symbol) or 's' (text).</param>
/// <param name="Integer">The whole number of an 'i'.</param>
/// <param name="Number">The decimal of an 'f'.</param>
/// <param name="Text">The text of a 'y' or an 's', "true" or "false" of a 'b'.</param>
public readonly record struct SettingValue(char Type, BigInteger Integer, double Number, string Text);

/// <summary>
/// A Mod Config option a world's notices name.
/// </summary>
/// <param name="Key">The option's key.</param>
/// <param name="Short">Its name as its row shows it, without "[Mod Name]".</param>
/// <param name="Names">The names Mod Config gives some of its values, each value written with its type ("i:1").</param>
public sealed record SettingOption(string Key, string Short, IReadOnlyList<KeyValuePair<string, string>> Names);

/// <summary>
/// A group of Mod Config, one mod's options, as Mod Config Remake groups them.
/// </summary>
/// <param name="Name">The mod's name, as the group's first row names it.</param>
/// <param name="Options">Its options.</param>
public sealed record SettingGroup(string Name, IReadOnlyList<SettingOption> Options);

/// <summary>
/// The text rules of a world's shared mod settings: "key=type:value" pairs separated by semicolons,
/// the marker first while the world shares them.
/// </summary>
public static class SharedSettings
{
    /// <summary>
    /// The pair that starts the settings of a world that shares them. Released games skip it, since
    /// they cannot read its type.
    /// </summary>
    public const string Marker = "@shared=o:1";

    /// <summary>
    /// The marker's key.
    /// </summary>
    public const string MarkerKey = "@shared";

    /// <summary>
    /// Most characters of a world's settings, as many as the relay takes.
    /// </summary>
    public const int MaxChars = 64_000;

    /// <summary>
    /// The reason of a change the creator's own switch made, which alone turns sharing on or off.
    /// </summary>
    public const string SwitchReason = "switch";

    /// <summary>
    /// Splits settings into their pairs.
    /// </summary>
    /// <param name="text">The settings.</param>
    /// <returns>Each pair's key and the pair as written; pairs without a key are left out.</returns>
    public static List<(string Key, string Pair)> Pairs(string? text) =>
        [.. ModCheck.RubySplit(text ?? "", ';').Select(pair => (Key: pair.Split('=', 2)[0], Pair: pair)).Where(pair => pair.Key.Length > 0)];

    /// <summary>
    /// Tells whether settings are shared: an empty text leaves every player their own.
    /// </summary>
    /// <param name="text">The settings.</param>
    /// <returns>Whether anything but white space is left.</returns>
    public static bool IsShared(string? text) => (text ?? "").Any(character => character > 0x7f || !RubyAscii.IsSpace((byte)character) && character != '\0');

    /// <summary>
    /// Joins settings as long as they fit, leaving out each that does not.
    /// </summary>
    /// <param name="pairs">Each option's key and pair.</param>
    /// <param name="most">The most characters, counted by code point as Ruby counts them.</param>
    /// <returns>The joined pairs and the keys left out.</returns>
    public static (string Text, List<string> LeftOut) Fit(IEnumerable<(string Key, string Pair)> pairs, int most = MaxChars)
    {
        string text = "";
        List<string> leftOut = [];
        foreach ((string key, string pair) in pairs)
        {
            string joined = text.Length == 0 ? pair : $"{text};{pair}";
            if (ModCheck.CodePoints(joined) > most)
            {
                leftOut.Add(key);
            }
            else
            {
                text = joined;
            }
        }

        return (text, leftOut);
    }

    /// <summary>
    /// Writes a world's shared settings from the creator's game: the marker, the creator's options of
    /// the world's mods, then the options the world sets that the creator's game does not know.
    /// </summary>
    /// <param name="mine">The creator's options of the world's mods, each key with its pair.</param>
    /// <param name="known">The keys of every option the creator's Mod Config has.</param>
    /// <param name="current">The world's settings as they are.</param>
    /// <returns>The settings and the options left out since they did not fit.</returns>
    public static (string Text, List<string> LeftOut) Build(IEnumerable<(string Key, string Pair)> mine, IReadOnlyCollection<string> known, string? current)
    {
        IEnumerable<(string Key, string Pair)> kept = Pairs(current).Where(pair => pair.Key != MarkerKey && !known.Contains(pair.Key));
        return Fit(new[] { (MarkerKey, Marker) }.Concat(mine).Concat(kept));
    }

    /// <summary>
    /// Writes a world's settings shared, as they are otherwise, for the edit form, which knows no options.
    /// </summary>
    /// <param name="text">The world's settings.</param>
    /// <returns>The marker, then the pairs as far as they fit.</returns>
    public static string WithMarker(string? text) =>
        Fit(new[] { (MarkerKey, Marker) }.Concat(Pairs(text).Where(pair => pair.Key != MarkerKey))).Text;

    /// <summary>
    /// Joins what the creator changed to the settings the relay holds.
    /// </summary>
    /// <param name="start">The settings the creator's change started from.</param>
    /// <param name="mine">The settings the creator's game wants.</param>
    /// <param name="theirs">The settings the relay holds.</param>
    /// <param name="reason">Why the creator's game wants them: "switch", "load" or "options".</param>
    /// <returns>The relay's settings with every option the creator changed as the creator has it; only the creator's own switch turns sharing on or off.</returns>
    public static string Merged(string start, string mine, string theirs, string reason)
    {
        if (!IsShared(mine) || !IsShared(theirs))
        {
            return reason == SwitchReason ? mine : theirs;
        }

        Dictionary<string, string> before = new(StringComparer.Ordinal);
        foreach ((string key, string pair) in Pairs(start))
        {
            before[key] = pair;
        }

        List<(string Key, string Pair)> changed = [.. Pairs(mine).Where(pair => pair.Key != MarkerKey && !(before.TryGetValue(pair.Key, out string? was) && was == pair.Pair))];
        IEnumerable<(string Key, string Pair)> kept = Pairs(theirs).Where(pair => pair.Key != MarkerKey && !changed.Any(change => change.Key == pair.Key));
        return Fit(new[] { (MarkerKey, Marker) }.Concat(kept).Concat(changed)).Text;
    }

    /// <summary>
    /// Reads settings' values, without the marker and the pairs that cannot be read; a key written
    /// again keeps its first place and takes the later value.
    /// </summary>
    /// <param name="text">The settings.</param>
    /// <returns>Each option's key and value.</returns>
    public static List<(string Key, SettingValue Value)> Values(string? text)
    {
        List<(string Key, SettingValue Value)> values = [];
        foreach ((string key, string pair) in Pairs(text))
        {
            string[] parts = pair.Split('=', 2);
            if (key == MarkerKey || Decode(parts.Length > 1 ? parts[1] : "") is not { } value)
            {
                continue;
            }

            int place = values.FindIndex(known => known.Key == key);
            if (place >= 0)
            {
                values[place] = (key, value);
            }
            else
            {
                values.Add((key, value));
            }
        }

        return values;
    }

    /// <summary>
    /// Reads a value written with its type, such as "i:1".
    /// </summary>
    /// <param name="text">The value.</param>
    /// <returns>The value, <see langword="null"/> when it cannot be read.</returns>
    public static SettingValue? Decode(string? text)
    {
        string[] parts = (text ?? "").Split(':', 2);
        string raw = (parts.Length > 1 ? parts[1] : "").Replace("%3D", "=", StringComparison.Ordinal).Replace("%3B", ";", StringComparison.Ordinal).Replace("%25", "%", StringComparison.Ordinal);
        return parts[0] switch
        {
            "i" when IsWhole(raw) => new SettingValue('i', BigInteger.Parse(raw, CultureInfo.InvariantCulture), 0, ""),
            "f" when IsDecimal(raw) => new SettingValue('f', 0, double.Parse(raw, CultureInfo.InvariantCulture), ""),
            "b" => new SettingValue('b', 0, 0, raw == "true" ? "true" : "false"),
            "y" when raw.Length > 0 => new SettingValue('y', 0, 0, raw),
            "s" => new SettingValue('s', 0, 0, raw),
            _ => null,
        };
    }

    /// <summary>
    /// Tells whether two values are the same, decimals within a margin, as Mod Config Remake finds a
    /// value among an option's values.
    /// </summary>
    /// <param name="one">A value.</param>
    /// <param name="other">The other value.</param>
    /// <returns>Whether they are.</returns>
    public static bool Same(SettingValue one, SettingValue other)
    {
        if (one.Type != 'f' && other.Type != 'f')
        {
            return one == other;
        }

        return AsDecimal(one) is { } first && AsDecimal(other) is { } second && Math.Abs(first - second) < 1e-6;
    }

    /// <summary>
    /// Writes a value as Ruby's <c>to_s</c> does, a decimal with two places as Mod Config shows it.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The text.</returns>
    public static string Shown(SettingValue value) => value.Type switch
    {
        'i' => value.Integer.ToString(CultureInfo.InvariantCulture),
        'f' => value.Number.ToString("F2", CultureInfo.InvariantCulture),
        _ => value.Text,
    };

    /// <summary>
    /// Names a few things and counts the rest.
    /// </summary>
    /// <param name="names">The things.</param>
    /// <param name="named">Most named before the rest is counted.</param>
    /// <returns>Such as "A and B" or "A, B and 3 more".</returns>
    public static string ListText(IReadOnlyList<string> names, int named)
    {
        if (names.Count <= 2 && names.Count <= named)
        {
            return string.Join(" and ", names);
        }

        return names.Count <= named
            ? $"{string.Join(", ", names.Take(names.Count - 1))} and {names[^1]}"
            : $"{string.Join(", ", names.Take(named))} and {names.Count - named} more";
    }

    /// <summary>
    /// Breaks a message into lines of the notification box at its words.
    /// </summary>
    /// <param name="text">The message.</param>
    /// <param name="most">Most lines.</param>
    /// <param name="width">Most characters of a line, counted by code point.</param>
    /// <returns>The lines, the last one cut short when the message is longer.</returns>
    public static List<string> NoticeLines(string text, int most, int width)
    {
        List<string> lines = [""];
        foreach (string word in Words(text))
        {
            string candidate = lines[^1].Length == 0 ? word : $"{lines[^1]} {word}";
            if (ModCheck.CodePoints(candidate) <= width || lines[^1].Length == 0)
            {
                lines[^1] = candidate;
            }
            else
            {
                lines.Add(word);
            }
        }

        if (lines.Count <= most)
        {
            return lines;
        }

        List<string> kept = lines.GetRange(0, most);
        kept[^1] = string.Concat(kept[^1].EnumerateRunes().Take(width - 3).Select(rune => rune.ToString())) + "...";
        return kept;
    }

    /// <summary>
    /// Splits a text at runs of ASCII white space, as Ruby's <c>split(" ")</c> does.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The words.</returns>
    private static IEnumerable<string> Words(string text)
    {
        StringBuilder word = new();
        foreach (char character in text)
        {
            if (character < 0x80 && RubyAscii.IsSpace((byte)character))
            {
                if (word.Length > 0)
                {
                    yield return word.ToString();
                    word.Clear();
                }
            }
            else
            {
                word.Append(character);
            }
        }

        if (word.Length > 0)
        {
            yield return word.ToString();
        }
    }

    /// <summary>
    /// Reads a value as Ruby's <c>to_f</c> would for the comparison of decimals.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The decimal, <see langword="null"/> for a value that has none, such as a symbol.</returns>
    private static double? AsDecimal(SettingValue value) => value.Type switch
    {
        'f' => value.Number,
        'i' => (double)value.Integer,
        's' => RubyNumbers.ToF(Encoding.UTF8.GetBytes(value.Text)),
        _ => null,
    };

    /// <summary>
    /// Tells whether a text is a whole number: digits with an optional minus.
    /// </summary>
    /// <param name="raw">The text.</param>
    /// <returns>Whether it is.</returns>
    private static bool IsWhole(string raw)
    {
        string digits = raw.StartsWith('-') ? raw[1..] : raw;
        return digits.Length > 0 && digits.All(char.IsAsciiDigit);
    }

    /// <summary>
    /// Tells whether a text is a decimal as the settings write one: digits, then optionally a point
    /// and digits, then optionally an exponent.
    /// </summary>
    /// <param name="raw">The text.</param>
    /// <returns>Whether it is.</returns>
    private static bool IsDecimal(string raw)
    {
        int at = raw.StartsWith('-') ? 1 : 0;
        int start = at;
        while (at < raw.Length && char.IsAsciiDigit(raw[at]))
        {
            at++;
        }

        if (at == start)
        {
            return false;
        }

        if (at < raw.Length && raw[at] == '.')
        {
            int fraction = ++at;
            while (at < raw.Length && char.IsAsciiDigit(raw[at]))
            {
                at++;
            }

            if (at == fraction)
            {
                return false;
            }
        }

        if (at < raw.Length && (raw[at] == 'e' || raw[at] == 'E'))
        {
            at++;
            if (at < raw.Length && (raw[at] == '-' || raw[at] == '+'))
            {
                at++;
            }

            int exponent = at;
            while (at < raw.Length && char.IsAsciiDigit(raw[at]))
            {
                at++;
            }

            if (at == exponent)
            {
                return false;
            }
        }

        return at == raw.Length;
    }
}
