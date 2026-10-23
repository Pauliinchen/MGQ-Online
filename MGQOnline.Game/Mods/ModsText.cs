//----------------------------------------------------------------
//  ModsText.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Read one mod's name as written
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Game.Ruby;

namespace MGQOnline.Game.Mods;

/// <summary>
/// Reads a world's mods as its creator wrote them: names separated by semicolons, a required mod
/// marked with "!" in front, an essential one with "?".
/// </summary>
public static class ModsText
{
    /// <summary>
    /// The mark in front of a required mod, whose script a game needs to enter.
    /// </summary>
    public const char RequiredMark = '!';

    /// <summary>
    /// The mark in front of an essential mod, which stands out but has no script looked for.
    /// </summary>
    public const char EssentialMark = '?';

    /// <summary>
    /// The separator between two mods.
    /// </summary>
    private const char Separator = ';';

    /// <summary>
    /// Ruby's ASCII white space.
    /// </summary>
    private static readonly char[] Spaces = [.. Enumerable.Range(0, 128).Where(code => RubyAscii.IsSpace((byte)code)).Select(code => (char)code)];

    /// <summary>
    /// What Ruby's <c>strip</c> takes off a text's end: white space and NUL.
    /// </summary>
    private static readonly char[] Trailing = [.. Spaces, '\0'];

    /// <summary>
    /// Lists every mod without its mark: the required ones first, then the essential ones, then the
    /// rest, each in the order written.
    /// </summary>
    /// <remarks>
    /// The required and essential ones are listed once each, the rest as often as written, as Ruby's
    /// <c>&amp;</c> and <c>-</c> of the scripts did.
    /// </remarks>
    /// <param name="text">The mods as written, <see langword="null"/> for none.</param>
    /// <returns>The names.</returns>
    public static IReadOnlyList<string> Names(string? text)
    {
        List<string> names = Parts(text).Select(WithoutMark).Where(name => name.Length > 0).ToList();
        IReadOnlyList<string> required = Required(text);
        IReadOnlyList<string> essential = Essential(text);
        IEnumerable<string> marked = names.Where(name => Contains(required, name)).Distinct(StringComparer.Ordinal)
            .Concat(names.Where(name => Contains(essential, name)).Distinct(StringComparer.Ordinal));
        return marked.Concat(names.Where(name => !Contains(required, name) && !Contains(essential, name))).ToList();
    }

    /// <summary>
    /// Lists the mods marked required, without the mark.
    /// </summary>
    /// <param name="text">The mods as written, <see langword="null"/> for none.</param>
    /// <returns>Their names in the order written.</returns>
    public static IReadOnlyList<string> Required(string? text) => Marked(text, RequiredMark);

    /// <summary>
    /// Lists the mods marked essential, without the mark.
    /// </summary>
    /// <param name="text">The mods as written, <see langword="null"/> for none.</param>
    /// <returns>Their names in the order written.</returns>
    public static IReadOnlyList<string> Essential(string? text) => Marked(text, EssentialMark);

    /// <summary>
    /// Reads one mod's name as written, such as one typed into the mod picker.
    /// </summary>
    /// <param name="written">The name, maybe with a mark and white space around it.</param>
    /// <returns>The name without the white space and the mark.</returns>
    public static string NameOf(string written) => WithoutMark(Strip(written));

    /// <summary>
    /// Lists the names written with a mark in front, without the mark and the white space after it.
    /// </summary>
    /// <remarks>
    /// A name that holds a line break is not one, as the scripts' <c>.</c> never matched it.
    /// </remarks>
    /// <param name="text">The mods as written.</param>
    /// <param name="mark">The mark.</param>
    /// <returns>The names in the order written.</returns>
    private static List<string> Marked(string? text, char mark)
    {
        List<string> names = [];
        foreach (string part in Parts(text))
        {
            if (part.Length == 0 || part[0] != mark)
            {
                continue;
            }

            string name = part[1..].TrimStart(Spaces);
            if (name.Length > 0 && !name.Contains('\n', StringComparison.Ordinal))
            {
                names.Add(name);
            }
        }

        return names;
    }

    /// <summary>
    /// Splits the text at its separators and strips each part of white space.
    /// </summary>
    /// <param name="text">The mods as written.</param>
    /// <returns>The stripped parts, empty ones included.</returns>
    private static IEnumerable<string> Parts(string? text) =>
        (text ?? "").Split(Separator).Select(Strip);

    /// <summary>
    /// Takes the mark and the white space after it off a part.
    /// </summary>
    /// <param name="part">The stripped part.</param>
    /// <returns>The name.</returns>
    private static string WithoutMark(string part) =>
        part.Length > 0 && (part[0] == RequiredMark || part[0] == EssentialMark) ? part[1..].TrimStart(Spaces) : part;

    /// <summary>
    /// Strips ASCII white space from both ends and NUL from the end, as Ruby's <c>strip</c> does.
    /// </summary>
    /// <param name="part">The part.</param>
    /// <returns>The stripped part.</returns>
    private static string Strip(string part) => part.TrimStart(Spaces).TrimEnd(Trailing);

    /// <summary>
    /// Tells whether a list holds a name.
    /// </summary>
    /// <param name="names">The list.</param>
    /// <param name="name">The name.</param>
    /// <returns>Whether it does, compared by its characters.</returns>
    private static bool Contains(IReadOnlyList<string> names, string name) => names.Contains(name, StringComparer.Ordinal);
}
