//----------------------------------------------------------------
//  DuelText.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using MGQOnline.Game.Battles.Wire;

namespace MGQOnline.Game.Duels;

/// <summary>
/// Texts as the duel's script wrote them in Ruby: sizes in characters, values of another game's
/// line written with <c>to_s</c>, their class names, and lists split as <c>split(",")</c> splits them.
/// </summary>
internal static class DuelText
{
    /// <summary>
    /// Counts a text's characters as Ruby's <c>String#size</c> does.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>Its characters.</returns>
    public static int Size(string text)
    {
        int count = 0;
        for (int index = 0; index < text.Length; index++)
        {
            if (char.IsHighSurrogate(text[index]) && index + 1 < text.Length && char.IsLowSurrogate(text[index + 1]))
            {
                index++;
            }

            count++;
        }

        return count;
    }

    /// <summary>
    /// Takes a text's first characters, as Ruby's <c>text[0, length]</c> does.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="length">How many characters at most.</param>
    /// <returns>The start.</returns>
    public static string Left(string text, int length)
    {
        var start = new StringBuilder();
        int taken = 0;
        foreach (Rune rune in text.EnumerateRunes())
        {
            if (taken++ == length)
            {
                break;
            }

            start.Append(rune.ToString());
        }

        return start.ToString();
    }

    /// <summary>
    /// Splits a list as Ruby's <c>split(",")</c> does, which drops the empty items at its end.
    /// </summary>
    /// <param name="text">The list, <see langword="null"/> for none.</param>
    /// <returns>The items.</returns>
    public static List<string> Split(string? text)
    {
        List<string> items = [.. (text ?? string.Empty).Split(',')];
        while (items.Count > 0 && items[^1].Length == 0)
        {
            items.RemoveAt(items.Count - 1);
        }

        return items;
    }

    /// <summary>
    /// Writes a value of another game's line as Ruby's <c>to_s</c> writes it.
    /// </summary>
    /// <param name="value">The value, <see langword="null"/> where the line holds none.</param>
    /// <returns>The text.</returns>
    public static string ToS(WireValue? value) => value switch
    {
        null or WireNil => string.Empty,
        WireString text => text.Text,
        WireSymbol symbol => symbol.Text,
        WireInteger number => number.Value.ToString(CultureInfo.InvariantCulture),
        WireBool flag => flag.Flag ? "true" : "false",
        WireFloat number => number.Value.ToString("R", CultureInfo.InvariantCulture),
        WireList list => Inspect(list),
        _ => "#<" + ClassName(value) + ">",
    };

    /// <summary>
    /// Names the Ruby class a value of another game's line reads as.
    /// </summary>
    /// <param name="value">The value, <see langword="null"/> where the line holds none.</param>
    /// <returns>The class's name, such as "String".</returns>
    public static string ClassName(WireValue? value) => value switch
    {
        null or WireNil => "NilClass",
        WireBool flag => flag.Flag ? "TrueClass" : "FalseClass",
        WireInteger => "Integer",
        WireFloat => "Float",
        WireString => "String",
        WireSymbol => "Symbol",
        WireList => "Array",
        WireResult => "Game_ActionResult",
        WireBaseItem => "Game_BaseItem",
        WireColor => "Color",
        WireTone => "Tone",
        _ => "Object",
    };

    /// <summary>
    /// Writes a list as Ruby's <c>Array#inspect</c> writes it, near enough for a list where a text
    /// belongs, which no team reads from.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <returns>The text.</returns>
    private static string Inspect(WireList list) =>
        "[" + string.Join(", ", list.Items.Select(item => item switch
        {
            WireString text => "\"" + text.Text + "\"",
            WireNil => "nil",
            _ => ToS(item),
        })) + "]";
}
