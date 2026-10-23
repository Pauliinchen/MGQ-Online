//----------------------------------------------------------------
//  CodePoints.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Text;

namespace MGQOnline.Game.Ui.Text;

/// <summary>
/// A text as Ruby counts it in UTF-8, by code point, with the few String methods of Ruby the
/// interface's text rules use.
/// </summary>
public static class CodePoints
{
    /// <summary>
    /// Splits a text into its code points.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The code points; a lone surrogate reads as U+FFFD, as its UTF-8 bytes would.</returns>
    public static int[] Of(string text)
    {
        ArgumentNullException.ThrowIfNull(text);
        var points = new List<int>(text.Length);
        foreach (Rune rune in text.EnumerateRunes())
        {
            points.Add(rune.Value);
        }

        return [.. points];
    }

    /// <summary>
    /// Joins code points into a text.
    /// </summary>
    /// <param name="points">The code points.</param>
    /// <returns>The text.</returns>
    public static string Text(ReadOnlySpan<int> points)
    {
        var builder = new StringBuilder(points.Length);
        foreach (int point in points)
        {
            builder.Append(new Rune(point).ToString());
        }

        return builder.ToString();
    }

    /// <summary>
    /// Tells whether a code point is white space as Ruby's <c>\s</c> and <c>split(" ")</c> see it:
    /// ASCII only.
    /// </summary>
    /// <param name="point">The code point.</param>
    /// <returns>Whether it is.</returns>
    public static bool IsSpace(int point) => point == ' ' || (point >= 0x09 && point <= 0x0D);

    /// <summary>
    /// Tells whether a code point is a control character as Ruby's <c>[[:cntrl:]]</c> sees it.
    /// </summary>
    /// <param name="point">The code point.</param>
    /// <returns>Whether it is: U+0000 to U+001F and U+007F to U+009F.</returns>
    public static bool IsControl(int point) => point < 0x20 || (point >= 0x7F && point <= 0x9F);

    /// <summary>
    /// Cuts off trailing white space and NULs, as Ruby's <c>rstrip</c> does.
    /// </summary>
    /// <param name="points">The code points.</param>
    /// <returns>Them without the trailing ones.</returns>
    public static ReadOnlySpan<int> RightStripped(ReadOnlySpan<int> points)
    {
        int end = points.Length;
        while (end > 0 && (points[end - 1] == 0 || IsSpace(points[end - 1])))
        {
            end--;
        }

        return points[..end];
    }

    /// <summary>
    /// Splits a text at runs of white space, leaving out the white space, as Ruby's
    /// <c>split(" ")</c> does.
    /// </summary>
    /// <param name="points">The code points.</param>
    /// <returns>The words.</returns>
    public static List<int[]> Words(ReadOnlySpan<int> points)
    {
        var words = new List<int[]>();
        int start = -1;
        for (int at = 0; at <= points.Length; at++)
        {
            bool space = at == points.Length || IsSpace(points[at]);
            if (space && start >= 0)
            {
                words.Add(points[start..at].ToArray());
                start = -1;
            }
            else if (!space && start < 0)
            {
                start = at;
            }
        }

        return words;
    }

    /// <summary>
    /// Splits a text into runs of white space and runs of anything else, keeping every code point,
    /// as Ruby's <c>scan(/\S+|\s+/)</c> does.
    /// </summary>
    /// <param name="points">The code points.</param>
    /// <returns>Each run's start and length.</returns>
    public static List<(int Start, int Length)> Runs(ReadOnlySpan<int> points)
    {
        var runs = new List<(int Start, int Length)>();
        int start = 0;
        for (int at = 1; at <= points.Length; at++)
        {
            if (at == points.Length || IsSpace(points[at]) != IsSpace(points[at - 1]))
            {
                runs.Add((start, at - start));
                start = at;
            }
        }

        return runs;
    }
}
