//----------------------------------------------------------------
//  RubyText.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using MGQOnline.Game.Battles.Wire;
using MGQOnline.Game.Ruby;

namespace MGQOnline.Game.Battles.Live;

/// <summary>
/// Writes the values of a battle line as Ruby's to_s and inspect write them, for the log lines the
/// live battle's scripts wrote of a peer's values.
/// </summary>
/// <remarks>
/// A battler, a database entry, an action or an action result is a game object in the scripts,
/// whose inspect names its memory address, so it is written as its class alone.
/// </remarks>
public static class RubyText
{
    /// <summary>
    /// Writes a value as Ruby's to_s does.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The text.</returns>
    public static string ToS(WireValue value) => value switch
    {
        WireString text => text.Text,
        WireSymbol symbol => symbol.Text,
        WireNil => "",
        WireList list => Inspect(list),
        _ => Inspect(value),
    };

    /// <summary>
    /// Writes values as Ruby's Array#inspect does.
    /// </summary>
    /// <param name="values">The values.</param>
    /// <returns>The text, such as "[3, \"cutin\", 0.5]".</returns>
    public static string Inspect(IReadOnlyList<WireValue> values)
    {
        ArgumentNullException.ThrowIfNull(values);
        return "[" + string.Join(", ", values.Select(Inspect)) + "]";
    }

    /// <summary>
    /// Writes a value as Ruby's inspect does.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The text.</returns>
    public static string Inspect(WireValue value) => value switch
    {
        WireNil => "nil",
        WireBool flag => flag.Flag ? "true" : "false",
        WireInteger number => number.Value.ToString(CultureInfo.InvariantCulture),
        WireFloat number => RubyNumbers.FloatToS(number.Value),
        WireString text => InspectString(text.Text),
        WireSymbol symbol => ":" + symbol.Text,
        WireList list => Inspect(list.Items),
        WireColor color => Channels(color.Red, color.Green, color.Blue, color.Alpha),
        WireTone tone => Channels(tone.Red, tone.Green, tone.Blue, tone.Gray),
        WireBattler => "#<Game_Battler>",
        WireResult => "#<Game_ActionResult>",
        WireBaseItem => "#<Game_BaseItem>",
        WireAction => "#<Game_Action>",
        _ => "#<RPG::BaseItem>",
    };

    /// <summary>
    /// Takes the first characters of a text, as Ruby's text[0, count] does.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="count">How many characters.</param>
    /// <returns>Those characters.</returns>
    public static string First(string text, int count)
    {
        ArgumentNullException.ThrowIfNull(text);
        return string.Concat(text.EnumerateRunes().Take(count).Select(rune => rune.ToString()));
    }

    /// <summary>
    /// Counts the characters of a text as Ruby's String#size does.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>Its characters.</returns>
    public static int Size(string text)
    {
        ArgumentNullException.ThrowIfNull(text);
        return text.EnumerateRunes().Count();
    }

    /// <summary>
    /// Writes a text as Ruby's String#inspect writes a UTF-8 text.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The text in quotes, escaped.</returns>
    public static string InspectString(string text)
    {
        ArgumentNullException.ThrowIfNull(text);
        var written = new StringBuilder("\"");
        Rune[] runes = text.EnumerateRunes().ToArray();
        for (int at = 0; at < runes.Length; at++)
        {
            Rune rune = runes[at];
            string? escape = rune.Value switch
            {
                '"' => "\\\"",
                '\\' => "\\\\",
                '\n' => "\\n",
                '\t' => "\\t",
                '\r' => "\\r",
                '\f' => "\\f",
                '\v' => "\\v",
                '\b' => "\\b",
                '\a' => "\\a",
                0x1B => "\\e",
                '#' when at + 1 < runes.Length && runes[at + 1].Value is '{' or '$' or '@' => "\\#",
                _ => null,
            };
            if (escape is not null)
            {
                written.Append(escape);
            }
            else if (Rune.GetUnicodeCategory(rune) == UnicodeCategory.Control)
            {
                written.Append(CultureInfo.InvariantCulture, $"\\u{rune.Value:X4}");
            }
            else
            {
                written.Append(rune.ToString());
            }
        }

        return written.Append('"').ToString();
    }

    /// <summary>
    /// Writes the channels of a color or a tone as RGSS writes them.
    /// </summary>
    /// <param name="first">The first channel.</param>
    /// <param name="second">The second channel.</param>
    /// <param name="third">The third channel.</param>
    /// <param name="fourth">The fourth channel.</param>
    /// <returns>The text, such as "(255.000000, 0.000000, 0.000000, 255.000000)".</returns>
    private static string Channels(double first, double second, double third, double fourth) =>
        string.Create(CultureInfo.InvariantCulture, $"({first:F6}, {second:F6}, {third:F6}, {fourth:F6})");
}
