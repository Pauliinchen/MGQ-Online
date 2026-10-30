//----------------------------------------------------------------
//  StreamNames.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using MGQOnline.Game.Battles.Wire;

namespace MGQOnline.Game.Battles.Live;

/// <summary>
/// Turns the host's names into the guest's in what the host's battle wrote: the host's own
/// characters are the guest's enemies, named with their owner, and the guest's characters are its
/// own, named without. A speaker's name box and the untranslated game's speaker line keep their
/// name, which names a character without its owner on either side.
/// </summary>
public sealed class StreamNames
{
    /// <summary>
    /// The names swapped, each with the guest's name, in the order they were first named.
    /// </summary>
    private readonly List<KeyValuePair<string, string>> _swaps = [];

    /// <summary>
    /// The names swapped, longest first, so a name that starts another never cuts it.
    /// </summary>
    private readonly string[] _longestFirst;

    /// <summary>
    /// Pairs the names of the host's sides with the guest's battlers of the same places.
    /// </summary>
    /// <param name="hostNames">The host's names line read: its party's names, then its troop's.</param>
    /// <param name="ownParty">The names of the guest's battlers the host's party stands for, by place.</param>
    /// <param name="ownTroop">The names of the guest's battlers the host's troop stands for, by place.</param>
    public StreamNames(IReadOnlyList<WireValue>? hostNames, IReadOnlyList<string> ownParty, IReadOnlyList<string> ownTroop)
    {
        ArgumentNullException.ThrowIfNull(ownParty);
        ArgumentNullException.ThrowIfNull(ownTroop);
        IReadOnlyList<WireValue> party = Listed(hostNames is { Count: > 0 } ? hostNames[0] : WireNil.Value);
        IReadOnlyList<WireValue> troop = Listed(hostNames is { Count: > 1 } ? hostNames[1] : WireNil.Value);
        PartyCount = party.Count;
        TroopCount = troop.Count;
        Pair(party, ownParty);
        Pair(troop, ownTroop);
        _longestFirst = _swaps.Select(swap => swap.Key).OrderByDescending(RubyText.Size).ToArray();
    }

    /// <summary>
    /// Gets how many names the host's party line held.
    /// </summary>
    public int PartyCount { get; }

    /// <summary>
    /// Gets how many names the host's troop line held.
    /// </summary>
    public int TroopCount { get; }

    /// <summary>
    /// Writes the line the guest logs once it took the names.
    /// </summary>
    /// <returns>The line, such as "the host names 2 party and 1 troop characters; swapping A -> B".</returns>
    public string Summary() =>
        $"the host names {PartyCount} party and {TroopCount} troop characters; swapping " +
        (_swaps.Count == 0 ? "none" : string.Join(", ", _swaps.Select(swap => $"{swap.Key} -> {swap.Value}")));

    /// <summary>
    /// Swaps the names in a text.
    /// </summary>
    /// <param name="text">The host's text.</param>
    /// <returns>The guest's text.</returns>
    public string Swap(string text)
    {
        ArgumentNullException.ThrowIfNull(text);
        if (_longestFirst.Length == 0)
        {
            return text;
        }

        var swapped = new StringBuilder(text.Length);
        int at = 0;
        while (at < text.Length)
        {
            string? name = _longestFirst.FirstOrDefault(candidate => text.AsSpan(at).StartsWith(candidate, StringComparison.Ordinal));
            if (name is null)
            {
                swapped.Append(text[at]);
                at++;
                continue;
            }

            swapped.Append(_swaps.First(swap => swap.Key == name).Value);
            at += name.Length;
        }

        return swapped.ToString();
    }

    /// <summary>
    /// Swaps the names in a message, but not in its speaker's name box or speaker line.
    /// </summary>
    /// <param name="text">The host's message line.</param>
    /// <returns>The guest's message line.</returns>
    public string SwapMessage(string text)
    {
        ArgumentNullException.ThrowIfNull(text);
        var swapped = new StringBuilder(text.Length);
        int start = 0;
        foreach ((int at, int length) in Speakers(text))
        {
            swapped.Append(SwapPart(text[start..at]));
            swapped.Append(text, at, length);
            start = at + length;
        }

        return swapped.Append(SwapPart(text[start..])).ToString();
    }

    /// <summary>
    /// Writes a translated host's first name box as the untranslated game's speaker line, for a
    /// guest without the name box, which would show the code as text.
    /// </summary>
    /// <param name="text">A message line.</param>
    /// <returns>The line as such a guest shows it.</returns>
    public static string Readable(string text)
    {
        ArgumentNullException.ThrowIfNull(text);
        (int At, int Length)? box = NameBoxAt(text, 0);
        if (box is not { } found)
        {
            return text;
        }

        string inner = BoxName(text.Substring(found.At, found.Length));
        return text[..found.At] + "【" + inner + "】\n" + text[(found.At + found.Length)..];
    }

    /// <summary>
    /// Swaps a part of a message between its speakers, unless the part is a whole speaker line, as
    /// the script's split of a message kept it.
    /// </summary>
    /// <param name="part">The part.</param>
    /// <returns>The part swapped.</returns>
    private string SwapPart(string part) => SpeakerLineLength(part) == part.Length && part.Length > 0 ? part : Swap(part);

    /// <summary>
    /// Finds the speakers of a message: every name box, and a speaker line that opens it.
    /// </summary>
    /// <param name="text">The message line.</param>
    /// <returns>Each speaker's start and length, in order.</returns>
    private static IEnumerable<(int At, int Length)> Speakers(string text)
    {
        int at = 0;
        bool first = true;
        while (at <= text.Length)
        {
            int line = first ? SpeakerLineLength(text) : 0;
            (int At, int Length)? box = NameBoxAt(text, at);
            if (first && line > 0 && (box is null || box.Value.At > 0))
            {
                yield return (0, line);
                at = line;
                first = false;
                continue;
            }

            first = false;
            if (box is not { } found)
            {
                yield break;
            }

            yield return found;
            at = found.At + Math.Max(found.Length, 1);
        }
    }

    /// <summary>
    /// Measures the untranslated game's speaker line opening a text, "【Name】".
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>Its length, 0 when the text opens with none.</returns>
    private static int SpeakerLineLength(string text)
    {
        if (!text.StartsWith('【'))
        {
            return 0;
        }

        int end = text.IndexOf('】', 1);
        return end < 0 ? 0 : end + 1;
    }

    /// <summary>
    /// Finds the first name box of the translation's message system from a place on, "\n<Name>",
    /// its letter in either case and an optional 1 to 5, c or r before the bracket.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="from">Where to look from.</param>
    /// <returns>The box's start and length, <see langword="null"/> for none.</returns>
    private static (int At, int Length)? NameBoxAt(string text, int from)
    {
        for (int at = from; at + 2 < text.Length; at++)
        {
            if (text[at] != '\\' || (text[at + 1] != 'n' && text[at + 1] != 'N'))
            {
                continue;
            }

            int open = at + 2;
            if (open < text.Length && text[open] != '<' && "12345cCrR".Contains(text[open], StringComparison.Ordinal))
            {
                open++;
            }

            if (open >= text.Length || text[open] != '<')
            {
                continue;
            }

            int close = text.IndexOf('>', open + 1);
            if (close >= 0)
            {
                return (at, close - at + 1);
            }
        }

        return null;
    }

    /// <summary>
    /// Reads the name of a name box as the script's box[/&lt;(.*)&gt;/, 1] read it: from the first
    /// bracket after which no line break comes before the box's end.
    /// </summary>
    /// <param name="box">The name box.</param>
    /// <returns>The name, "" when every bracket has a line break after it.</returns>
    private static string BoxName(string box)
    {
        int end = box.Length - 1;
        for (int open = box.IndexOf('<', StringComparison.Ordinal); open >= 0 && open < end; open = box.IndexOf('<', open + 1))
        {
            string inner = box[(open + 1)..end];
            if (!inner.Contains('\n', StringComparison.Ordinal))
            {
                return inner;
            }
        }

        return "";
    }

    /// <summary>
    /// Reads a side's names as the script's Array() did: a list as its items, nil as none, anything
    /// else as itself alone.
    /// </summary>
    /// <param name="value">The side's value.</param>
    /// <returns>The names.</returns>
    private static IReadOnlyList<WireValue> Listed(WireValue value) => value switch
    {
        WireList list => list.Items,
        WireNil => [],
        _ => [value],
    };

    /// <summary>
    /// Pairs a side's names with the guest's names of the same places; a later pair of the same name
    /// changes its swap where it was first named.
    /// </summary>
    /// <param name="names">The host's names.</param>
    /// <param name="own">The guest's names.</param>
    private void Pair(IReadOnlyList<WireValue> names, IReadOnlyList<string> own)
    {
        for (int place = 0; place < names.Count && place < own.Count; place++)
        {
            if (names[place] is not WireString { Text: { Length: > 0 } name } || name == own[place])
            {
                continue;
            }

            int known = _swaps.FindIndex(swap => swap.Key == name);
            if (known >= 0)
            {
                _swaps[known] = new KeyValuePair<string, string>(name, own[place]);
            }
            else
            {
                _swaps.Add(new KeyValuePair<string, string>(name, own[place]));
            }
        }
    }
}
