//----------------------------------------------------------------
//  ClassicStoryLists.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Wrote what of a story changed from its writes as plain values
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Story;

/// <summary>
/// The story a Classic party's leader tells the members who follow it, as message fields: the
/// whole story a member asks for, and what of it changed since, both as plain values that
/// <see cref="MessageFields"/> writes, the whole story packed.
/// </summary>
public static class ClassicStoryLists
{
    /// <summary>
    /// The longest packed whole story a message carries, below the 256 KB one carries.
    /// </summary>
    public const int MaxFullLength = 200_000;

    /// <summary>
    /// The field the whole story's lists travel packed in.
    /// </summary>
    public const string ListsField = "z";

    /// <summary>
    /// The field that tells the whole story left out what it turned off.
    /// </summary>
    public const string PartField = "part";

    /// <summary>
    /// The lists of what a story turned off or set to zero, which a story too large for a message
    /// leaves out.
    /// </summary>
    private static readonly string[] OffLists = ["sf", "ssf"];

    /// <summary>
    /// Writes the fields of a whole story: its lists packed, and without what the story turned off
    /// or set to zero once they would pass <paramref name="maxLength"/>, which a member then learns
    /// from <see cref="PartField"/>.
    /// </summary>
    /// <param name="lists">"s" and "sf" (the switches on and off), "v" ([variable, value] each),
    /// "ss" and "ssf" (the self switches on and off, [map, event, letter] each).</param>
    /// <param name="maxLength">The longest packed lists a message carries.</param>
    /// <returns>The fields: <see cref="ListsField"/> with the lists and <see cref="PartField"/>.</returns>
    public static RubyHash Full(RubyHash lists, int maxLength = MaxFullLength)
    {
        ArgumentNullException.ThrowIfNull(lists);
        if (MessageFields.Write(ListsField, lists).Length <= maxLength)
        {
            return new RubyHash { { ListsField, lists }, { PartField, false } };
        }

        var part = new RubyHash();
        foreach (KeyValuePair<RubyValue, RubyValue> pair in lists)
        {
            string name = pair.Key.AsText();
            part[name] = OffLists.Contains(name) ? new RubyArray()
                : name == "v" ? new RubyArray(pair.Value.AsArray().Where(entry => !IsZero(entry.AsArray()[1])))
                : pair.Value;
        }

        return new RubyHash { { ListsField, part }, { PartField, true } };
    }

    /// <summary>
    /// Writes what of a story changed, from its writes.
    /// </summary>
    /// <param name="writes">Each key's last value as a row, see <see cref="StoryPlain"/>.</param>
    /// <returns>"s" ([switch, on] each), "v" ([variable, value] each, a Float as
    /// <see cref="MessageFields.FloatKey"/>) and "ss" ([[map, event, letter], on] each); a write of
    /// no key or of a value no story carries is left out.</returns>
    public static RubyHash Delta(RubyArray writes)
    {
        ArgumentNullException.ThrowIfNull(writes);
        var switches = new RubyArray();
        var variables = new RubyArray();
        var selfSwitches = new RubyArray();
        foreach (RubyValue write in writes)
        {
            StoryKey key;
            RubyValue value;
            try
            {
                (key, value) = StoryPlain.RowOf(write);
            }
            catch (RubyValueException)
            {
                continue;
            }

            if (StoryPlain.TextOf(key, value) is not { } text)
            {
                continue;
            }

            RubyValue read = StoryPlain.ValueOf(key, text);
            switch (key.Kind)
            {
                case StoryKeyKind.Switch:
                    switches.Add(new RubyArray { key.Id, read });
                    break;
                case StoryKeyKind.Variable:
                    variables.Add(new RubyArray { key.Id, read });
                    break;
                case StoryKeyKind.SelfSwitch:
                    selfSwitches.Add(new RubyArray { new RubyArray { key.Id, key.Event, key.Letter }, read });
                    break;
            }
        }

        return new RubyHash { { "s", switches }, { "v", variables }, { "ss", selfSwitches } };
    }

    /// <summary>
    /// Tells whether a variable's value is zero, which a story too large for a message leaves out.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>Whether it is 0 or 0.0.</returns>
    private static bool IsZero(RubyValue value) => value switch
    {
        RubyInteger number => number.Value.IsZero,
        RubyFloat real => real.Value == 0,
        _ => false,
    };
}
