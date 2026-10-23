//----------------------------------------------------------------
//  ModKey.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Globalization;
using System.Text;

namespace MGQOnline.Game.Mods;

/// <summary>
/// The key a mod's name and its script's file name are compared by, as the relay's <c>modKey</c>
/// (Relay/core/mods.js) makes it, since the relay holds its stored mods by that key: the name in
/// lower case, without a final ".rb", white space, underscores and hyphens.
/// </summary>
public static class ModKey
{
    /// <summary>
    /// The script extension a key leaves out.
    /// </summary>
    private const string ScriptExtension = ".rb";

    /// <summary>
    /// The capital sigma, which lower-cases to a final sigma at a word's end.
    /// </summary>
    private const int CapitalSigma = 0x03A3;

    /// <summary>
    /// The small sigma inside a word.
    /// </summary>
    private const char SmallSigma = '\u03c3';

    /// <summary>
    /// The small sigma at a word's end.
    /// </summary>
    private const char FinalSigma = '\u03c2';

    /// <summary>
    /// The capital I with a dot above.
    /// </summary>
    private const int CapitalDottedI = 0x0130;

    /// <summary>
    /// What the capital I with a dot above lower-cases to: an i and a combining dot above.
    /// </summary>
    private const string SmallDottedI = "i\u0307";

    /// <summary>
    /// The characters between letters that a word goes on through, besides the marks, format
    /// characters and modifiers Unicode counts as case-ignorable.
    /// </summary>
    private const string InsideWord = "'.:\u00b7\u0387\u055f\u05f4\u2018\u2019\u2024\u2027\ufe13\ufe52\ufe55\uff07\uff0e\uff1a";

    /// <summary>
    /// Makes a name's key.
    /// </summary>
    /// <param name="name">The name, such as <c>Level Cap</c> or <c>Level_Cap.rb</c>.</param>
    /// <returns>The key, such as <c>levelcap</c>.</returns>
    public static string Of(string name)
    {
        string lower = LowerCase(name);
        if (lower.EndsWith(ScriptExtension, StringComparison.Ordinal))
        {
            lower = lower[..^ScriptExtension.Length];
        }

        StringBuilder key = new(lower.Length);
        foreach (char unit in lower)
        {
            if (!IsLeftOut(unit))
            {
                key.Append(unit);
            }
        }

        return key.ToString();
    }

    /// <summary>
    /// Lower-cases a name as JavaScript's <c>toLowerCase</c> does.
    /// </summary>
    /// <remarks>
    /// JavaScript also applies Unicode's special casing: a capital sigma at a word's end becomes a
    /// final sigma, and the capital I with a dot above an i with a combining dot, which .NET's
    /// invariant casing does not do.
    /// </remarks>
    /// <param name="name">The name.</param>
    /// <returns>The name in lower case.</returns>
    private static string LowerCase(string name)
    {
        StringBuilder lower = new(name.Length);
        for (int at = 0; at < name.Length;)
        {
            Rune rune = Rune.GetRuneAt(name, at);
            if (rune.Value == CapitalSigma)
            {
                lower.Append(EndsWord(name, at) ? FinalSigma : SmallSigma);
            }
            else if (rune.Value == CapitalDottedI)
            {
                lower.Append(SmallDottedI);
            }
            else
            {
                lower.Append(Rune.ToLowerInvariant(rune).ToString());
            }

            at += rune.Utf16SequenceLength;
        }

        return lower.ToString();
    }

    /// <summary>
    /// Tells whether a capital sigma ends a word as Unicode's Final_Sigma condition has it: a cased
    /// letter before it and none after it, case-ignorable characters between skipped.
    /// </summary>
    /// <param name="name">The name.</param>
    /// <param name="at">Where the sigma is.</param>
    /// <returns>Whether it does.</returns>
    private static bool EndsWord(string name, int at)
    {
        bool casedBefore = false;
        for (int before = at; before > 0;)
        {
            Rune.DecodeLastFromUtf16(name.AsSpan(0, before), out Rune rune, out int length);
            before -= length;
            if (IsCased(rune))
            {
                casedBefore = true;
                break;
            }

            if (!IsCaseIgnorable(rune))
            {
                break;
            }
        }

        if (!casedBefore)
        {
            return false;
        }

        for (int after = at + 1; after < name.Length;)
        {
            Rune rune = Rune.GetRuneAt(name, after);
            after += rune.Utf16SequenceLength;
            if (IsCased(rune))
            {
                return false;
            }

            if (!IsCaseIgnorable(rune))
            {
                break;
            }
        }

        return true;
    }

    /// <summary>
    /// Tells whether a character is cased: a capital, small or title-case letter, or one that has
    /// another case.
    /// </summary>
    /// <param name="rune">The character.</param>
    /// <returns>Whether it is.</returns>
    private static bool IsCased(Rune rune) =>
        Rune.GetUnicodeCategory(rune) is UnicodeCategory.UppercaseLetter or UnicodeCategory.LowercaseLetter or UnicodeCategory.TitlecaseLetter
        || Rune.ToLowerInvariant(rune) != rune || Rune.ToUpperInvariant(rune) != rune;

    /// <summary>
    /// Tells whether a character is case-ignorable: a mark, a format character, a modifier, or one
    /// a word goes on through.
    /// </summary>
    /// <param name="rune">The character.</param>
    /// <returns>Whether it is.</returns>
    private static bool IsCaseIgnorable(Rune rune) =>
        Rune.GetUnicodeCategory(rune) is UnicodeCategory.NonSpacingMark or UnicodeCategory.EnclosingMark or UnicodeCategory.Format
            or UnicodeCategory.ModifierLetter or UnicodeCategory.ModifierSymbol
        || (rune.IsBmp && InsideWord.Contains((char)rune.Value, StringComparison.Ordinal));

    /// <summary>
    /// Tells whether a key leaves a character out: an underscore, a hyphen, or white space as a
    /// JavaScript regular expression's <c>\s</c> sees it.
    /// </summary>
    /// <param name="unit">The character.</param>
    /// <returns>Whether it does.</returns>
    private static bool IsLeftOut(char unit) => unit switch
    {
        '_' or '-' or ' ' or '\u00a0' or '\u1680' or '\u2028' or '\u2029' or '\u202f' or '\u205f' or '\u3000' or '\ufeff' => true,
        >= '\t' and <= '\r' => true,
        >= '\u2000' and <= '\u200a' => true,
        _ => false,
    };
}
