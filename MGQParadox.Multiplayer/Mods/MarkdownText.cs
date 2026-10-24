//----------------------------------------------------------------
//  MarkdownText.cs
//
//  Changelog:
//      Paulinchen  2026-10-24: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;

namespace MGQParadox.Multiplayer.Mods;

/// <summary>
/// Turns a mod's Markdown description into plain lines the game script shows: one per paragraph,
/// heading or list item, without the Markdown's marks.
/// </summary>
internal static partial class MarkdownText
{
    /// <summary>
    /// What a list item starts with in the plain lines.
    /// </summary>
    private const string ListMarker = "- ";

    /// <summary>
    /// Turns Markdown into plain lines.
    /// </summary>
    /// <param name="markdown">The Markdown.</param>
    /// <param name="maxLines">The most lines kept.</param>
    /// <param name="maxLength">The most characters a line keeps.</param>
    /// <returns>The lines, none of them empty.</returns>
    public static IReadOnlyList<string> Lines(string markdown, int maxLines, int maxLength)
    {
        var lines = new List<string>();
        var block = new StringBuilder();
        var inFence = false;

        foreach (var raw in markdown.Replace("\r\n", "\n").Split('\n'))
        {
            if (Fence().IsMatch(raw))
            {
                Flush(lines, block, maxLength);
                inFence = !inFence;
                continue;
            }

            if (inFence)
            {
                Add(lines, raw.Trim(), maxLength);
                continue;
            }

            var line = Quote().Replace(raw, string.Empty);

            if (line.Trim().Length == 0 || Rule().IsMatch(line))
            {
                Flush(lines, block, maxLength);
            }
            else if (Heading().Match(line) is { Success: true } heading)
            {
                Flush(lines, block, maxLength);
                Add(lines, Plain(heading.Groups[1].Value), maxLength);
            }
            else if (ListItem().Match(line) is { Success: true } item)
            {
                Flush(lines, block, maxLength);
                block.Append(ListMarker).Append(item.Groups[1].Value.Trim());
            }
            else
            {
                block.Append(block.Length > 0 ? " " : string.Empty).Append(line.Trim());
            }
        }

        Flush(lines, block, maxLength);
        return lines.Count > maxLines ? lines.GetRange(0, maxLines) : lines;
    }

    /// <summary>
    /// Adds the paragraph or list item gathered so far as a plain line, and starts the next.
    /// </summary>
    /// <param name="lines">The lines.</param>
    /// <param name="block">The text gathered, on one line; emptied.</param>
    /// <param name="maxLength">The most characters a line keeps.</param>
    private static void Flush(List<string> lines, StringBuilder block, int maxLength)
    {
        if (block.Length > 0)
        {
            Add(lines, Plain(block.ToString()), maxLength);
            block.Clear();
        }
    }

    /// <summary>
    /// Takes the inline marks out of a block's text, leaving code spans' text as it is.
    /// </summary>
    /// <param name="text">The block's text, on one line.</param>
    /// <returns>The plain text, its spaces collapsed.</returns>
    private static string Plain(string text)
    {
        var plain = new StringBuilder();
        var at = 0;

        foreach (Match code in CodeSpan().Matches(text))
        {
            plain.Append(Unmarked(text[at..code.Index])).Append(code.Groups[2].Value.Trim());
            at = code.Index + code.Length;
        }

        plain.Append(Unmarked(text[at..]));
        return Spaces().Replace(plain.ToString(), " ").Trim();
    }

    /// <summary>
    /// Takes images, links, HTML tags, emphasis and escapes out of text outside code spans.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The plain text.</returns>
    private static string Unmarked(string text)
    {
        text = Image().Replace(text, string.Empty);
        text = Link().Replace(text, "$1");
        text = AutoLink().Replace(text, "$1");
        text = Tag().Replace(text, string.Empty);
        text = StrongStars().Replace(text, "$1");
        text = StrongUnderscores().Replace(text, "$1");
        text = Stars().Replace(text, "$1");
        text = Underscores().Replace(text, "$1");
        return Escape().Replace(text, "$1");
    }

    /// <summary>
    /// Adds a line unless it is empty, cut to its most characters without splitting a character in two.
    /// </summary>
    /// <param name="lines">The lines.</param>
    /// <param name="line">The line.</param>
    /// <param name="maxLength">The most characters a line keeps.</param>
    private static void Add(List<string> lines, string line, int maxLength)
    {
        if (line.Length == 0)
        {
            return;
        }

        if (line.Length > maxLength)
        {
            line = line[..(char.IsHighSurrogate(line[maxLength - 1]) ? maxLength - 1 : maxLength)];
        }

        lines.Add(line);
    }

    /// <summary>
    /// A line that opens or closes a fenced code block.
    /// </summary>
    [GeneratedRegex(@"^\s{0,3}(```|~~~)")]
    private static partial Regex Fence();

    /// <summary>
    /// The markers of a block quote at a line's start.
    /// </summary>
    [GeneratedRegex(@"^\s{0,3}(>\s?)+")]
    private static partial Regex Quote();

    /// <summary>
    /// A thematic break or a setext heading's underline.
    /// </summary>
    [GeneratedRegex(@"^\s{0,3}([-*_=])(\s*\1){2,}\s*$")]
    private static partial Regex Rule();

    /// <summary>
    /// A heading, its text in group 1 without the closing hashes.
    /// </summary>
    [GeneratedRegex(@"^\s{0,3}#{1,6}\s+(.*?)(\s+#+)?\s*$")]
    private static partial Regex Heading();

    /// <summary>
    /// A bulleted or numbered list item, its text in group 1.
    /// </summary>
    [GeneratedRegex(@"^\s*(?:[-*+]|\d{1,9}[.)])\s+(.*)$")]
    private static partial Regex ListItem();

    /// <summary>
    /// A code span, its text in group 2.
    /// </summary>
    [GeneratedRegex(@"(`+)(.+?)\1")]
    private static partial Regex CodeSpan();

    /// <summary>
    /// An image.
    /// </summary>
    [GeneratedRegex(@"!\[[^\]]*\]\([^)]*\)")]
    private static partial Regex Image();

    /// <summary>
    /// A link, its text in group 1.
    /// </summary>
    [GeneratedRegex(@"\[([^\]]*)\]\([^)]*\)")]
    private static partial Regex Link();

    /// <summary>
    /// An address in angle brackets, the address in group 1.
    /// </summary>
    [GeneratedRegex(@"<((?:https?|mailto):[^>\s]+)>", RegexOptions.IgnoreCase)]
    private static partial Regex AutoLink();

    /// <summary>
    /// An HTML tag or comment.
    /// </summary>
    [GeneratedRegex(@"<(/?[A-Za-z][^>]*|!--.*?--)>")]
    private static partial Regex Tag();

    /// <summary>
    /// Strong emphasis with two asterisks, its text in group 1.
    /// </summary>
    [GeneratedRegex(@"(?<!\\)\*\*(?=\S)(.+?)(?<=\S)\*\*")]
    private static partial Regex StrongStars();

    /// <summary>
    /// Strong emphasis with two underscores, its text in group 1; only outside a word, as in <c>Level__Cap</c> it is none.
    /// </summary>
    [GeneratedRegex(@"(?<![\\\w])__(?=\S)(.+?)(?<=\S)__(?!\w)")]
    private static partial Regex StrongUnderscores();

    /// <summary>
    /// Emphasis with one asterisk, its text in group 1.
    /// </summary>
    [GeneratedRegex(@"(?<![\\*])\*(?=[^\s*])(.+?)(?<=[^\s\\*])\*(?!\*)")]
    private static partial Regex Stars();

    /// <summary>
    /// Emphasis with one underscore, its text in group 1; only outside a word, as in <c>Level_Cap</c> it is none.
    /// </summary>
    [GeneratedRegex(@"(?<![\\\w])_(?=\S)(.+?)(?<=\S)_(?!\w)")]
    private static partial Regex Underscores();

    /// <summary>
    /// A character escaped with a backslash, the character in group 1.
    /// </summary>
    [GeneratedRegex(@"\\([\\`*_{}\[\]()#+\-.!<>|~])")]
    private static partial Regex Escape();

    /// <summary>
    /// Runs of white space.
    /// </summary>
    [GeneratedRegex(@"\s+")]
    private static partial Regex Spaces();
}
