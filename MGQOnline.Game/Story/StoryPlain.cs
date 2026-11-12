//----------------------------------------------------------------
//  StoryPlain.cs
//
//  Changelog:
//      Paulinchen  2026-11-12: Dropped the read of an item the player holds
//                            - Dropped the read of everything the player holds
//      Paulinchen  2026-11-11: Left a whole track's keys and held keys out of a take, which the DLL lays itself
//                            - Named a command's place by its code and its number among its list's commands of that code
//                            - Read the place an earlier release named an input by, its place among its list's kept commands
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Numerics;
using System.Text;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Topics;

namespace MGQOnline.Game.Story;

/// <summary>
/// The one shape the scripts hand the story's keys and values over in and get them back in, so C#
/// alone writes and reads the texts the relay's tracks, the save's log and the messages keep, such
/// as <c>ss7.39.A</c> and <c>n5</c>.
/// </summary>
/// <remarks>
/// A key is <c>[kind, key]</c>: kind 0 a switch, 1 a variable, 2 a self switch or 3 a frozen fight;
/// key the id (a frozen fight's troop), or a self switch's <c>[map, event, letter]</c> as the game
/// keys it. A value is true or false for a switch or self switch; an Integer, a String, true, false
/// or a Float as <c>{"float" => text}</c> (<see cref="MessageFields.FloatKey"/>) for a variable; the
/// fight's Hash, or false once it ended, for a frozen fight (see <see cref="FrozenFightText"/>); nil
/// for a value no story carries. Keys with values go as
/// rows, <c>[kind, key, value]</c>. A companion a replay reads takes the same shape with kind
/// "actor" (an id, the value whether the player has them in the party). A
/// site, where a write or a run came from, is <c>["map", map, event, page from 1]</c>,
/// <c>["ce", common event]</c>, <c>["game"]</c> or <c>["game", what]</c> (a part of the game, such
/// as "troop" or "catchup"), or <c>["list"]</c> for a list of no site; a command's place, where an
/// input was read, is <c>[site, code, number]</c>, the number counted among the list's commands of
/// that code (<c>[site, 0, index]</c> for a list the game does not know).
/// </remarks>
public static class StoryPlain
{
    /// <summary>
    /// The kind of a switch.
    /// </summary>
    public const int SwitchKind = 0;

    /// <summary>
    /// The kind of a variable.
    /// </summary>
    public const int VariableKind = 1;

    /// <summary>
    /// The kind of a self switch.
    /// </summary>
    public const int SelfSwitchKind = 2;

    /// <summary>
    /// The kind of a frozen fight.
    /// </summary>
    public const int FreezeKind = 3;

    /// <summary>
    /// The kind of a companion a replay reads.
    /// </summary>
    public const string ActorKind = "actor";

    /// <summary>
    /// How a switch or self switch that is on is written.
    /// </summary>
    public const string OnText = "1";

    /// <summary>
    /// How a switch or self switch that is off is written.
    /// </summary>
    public const string OffText = "0";

    /// <summary>
    /// Reads a key.
    /// </summary>
    /// <param name="plain"><c>[kind, key]</c>.</param>
    /// <returns>The key.</returns>
    /// <exception cref="RubyValueException">The value is no key.</exception>
    public static StoryKey KeyOf(RubyValue plain)
    {
        ArgumentNullException.ThrowIfNull(plain);
        return plain is RubyArray { Count: 2 } fields ? KeyOf(fields[0], fields[1]) : throw new RubyValueException($"{plain} is no story key, which is [kind, key].");
    }

    /// <summary>
    /// Reads a key by its kind and key.
    /// </summary>
    /// <param name="kind">0 a switch, 1 a variable, 2 a self switch, 3 a frozen fight.</param>
    /// <param name="key">The id, or a self switch's [map, event, letter].</param>
    /// <returns>The key.</returns>
    /// <exception cref="RubyValueException">The two make no key.</exception>
    public static StoryKey KeyOf(RubyValue kind, RubyValue key)
    {
        ArgumentNullException.ThrowIfNull(kind);
        ArgumentNullException.ThrowIfNull(key);
        StoryKey found = kind is RubyInteger ? kind.AsInt() switch
        {
            SwitchKind => StoryKey.Switch(key.AsInt()),
            VariableKind => StoryKey.Variable(key.AsInt()),
            SelfSwitchKind when key is RubyArray { Count: 3 } self => StoryKey.SelfSwitch(self[0].AsInt(), self[1].AsInt(), self[2].AsText()),
            FreezeKind => new StoryKey(StoryKeyKind.Freeze, key.AsInt()),
            _ => throw new RubyValueException($"{kind} {key} is no story key."),
        } : throw new RubyValueException($"{kind} is no kind of a story key.");
        return StoryKey.TryParse(found.ToString(), out StoryKey valid) ? valid : throw new RubyValueException($"{kind} {key} is no story key the tracks name.");
    }

    /// <summary>
    /// Writes a key.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <returns><c>[kind, key]</c>.</returns>
    public static RubyArray Plain(StoryKey key) => [KindOf(key), KeyPart(key)];

    /// <summary>
    /// Writes a key with its value as a row.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <param name="text">The value as the tracks write it.</param>
    /// <returns><c>[kind, key, value]</c>.</returns>
    public static RubyArray Row(StoryKey key, string text) => [KindOf(key), KeyPart(key), ValueOf(key, text)];

    /// <summary>
    /// Writes keys with their values as rows, in the order of the keys' names.
    /// </summary>
    /// <param name="texts">Each key with its value as the tracks write it.</param>
    /// <returns><c>[[kind, key, value], ...]</c>.</returns>
    public static RubyArray Rows(IEnumerable<KeyValuePair<StoryKey, string>> texts)
    {
        ArgumentNullException.ThrowIfNull(texts);
        return new RubyArray(texts.OrderBy(pair => pair.Key.ToString(), StringComparer.Ordinal).Select(pair => (RubyValue)Row(pair.Key, pair.Value)));
    }

    /// <summary>
    /// Writes keys named as the tracks name them with their values as rows, in their order, leaving
    /// out a name that is no key.
    /// </summary>
    /// <param name="texts">Each key's name with its value, both as the tracks write them.</param>
    /// <returns><c>[[kind, key, value], ...]</c>.</returns>
    public static RubyArray Rows(IEnumerable<KeyValuePair<string, string>> texts)
    {
        ArgumentNullException.ThrowIfNull(texts);
        return new RubyArray(texts.Select(pair => StoryKey.TryParse(pair.Key, out StoryKey key) ? (RubyValue)Row(key, pair.Value) : null).OfType<RubyValue>());
    }

    /// <summary>
    /// Reads rows of keys with their values as the tracks write them, leaving out a value no story
    /// carries.
    /// </summary>
    /// <param name="rows"><c>[[kind, key, value], ...]</c>, nil for none.</param>
    /// <returns>Each key with its value.</returns>
    /// <exception cref="RubyValueException">A row is no key with a value.</exception>
    public static Dictionary<StoryKey, string> TextsOf(RubyValue rows)
    {
        ArgumentNullException.ThrowIfNull(rows);
        var texts = new Dictionary<StoryKey, string>();
        foreach (RubyValue row in rows.IsNil ? [] : rows.AsArray())
        {
            (StoryKey key, RubyValue value) = RowOf(row);
            if (TextOf(key, value) is { } text)
            {
                texts[key] = text;
            }
        }

        return texts;
    }

    /// <summary>
    /// Reads a row.
    /// </summary>
    /// <param name="row"><c>[kind, key, value]</c>.</param>
    /// <returns>The key and the value as handed over.</returns>
    /// <exception cref="RubyValueException">The row is no key with a value.</exception>
    public static (StoryKey Key, RubyValue Value) RowOf(RubyValue row)
    {
        ArgumentNullException.ThrowIfNull(row);
        return row is RubyArray { Count: 3 } fields ? (KeyOf(fields[0], fields[1]), fields[2]) : throw new RubyValueException($"{row} is no row, which is [kind, key, value].");
    }

    /// <summary>
    /// Writes a value as the tracks keep it.
    /// </summary>
    /// <param name="key">The key whose value it is.</param>
    /// <param name="value">The value, see <see cref="StoryPlain"/>.</param>
    /// <returns>The text, such as "1", "n5" or "sSGk=", <see langword="null"/> for a value no story carries.</returns>
    public static string? TextOf(StoryKey key, RubyValue value)
    {
        ArgumentNullException.ThrowIfNull(value);
        return key.Kind switch
        {
            StoryKeyKind.Variable => VariableText(value),
            StoryKeyKind.Freeze => value is RubyHash entry ? FrozenFightText.Write(entry) : value is RubyBool { Flag: false } ? FrozenFightText.EndedText : null,
            _ => value is RubyBool { Flag: true } ? OnText : OffText,
        };
    }

    /// <summary>
    /// Reads a value as the tracks keep it.
    /// </summary>
    /// <param name="key">The key whose value it is.</param>
    /// <param name="text">The text.</param>
    /// <returns>The value, see <see cref="StoryPlain"/>; nil for a variable's text that does not read.</returns>
    public static RubyValue ValueOf(StoryKey key, string text)
    {
        ArgumentNullException.ThrowIfNull(text);
        return key.Kind switch
        {
            StoryKeyKind.Variable => VariableOf(text) ?? RubyNil.Value,
            StoryKeyKind.Freeze => text == FrozenFightText.EndedText ? false : FrozenFightText.Read(key.Id, text) ?? (RubyValue)RubyNil.Value,
            _ => text == OnText,
        };
    }

    /// <summary>
    /// Writes a variable's value as the tracks keep it: "n" and a whole number, "f" and a Float's
    /// text, "s" and a text's bytes in Base64, "T" or "F".
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The text, <see langword="null"/> for a value no story carries.</returns>
    public static string? VariableText(RubyValue value) => value switch
    {
        RubyInteger number => "n" + number.Value.ToString(CultureInfo.InvariantCulture),
        RubyString => "s" + Convert.ToBase64String(value.AsBytes().Span),
        RubyBool flag => flag.Flag ? "T" : "F",
        RubyHash tagged when tagged.Count == 1 && tagged[MessageFields.FloatKey] is RubyString real
            && double.TryParse(real.AsText(), NumberStyles.Float, CultureInfo.InvariantCulture, out _) => "f" + real.AsText(),
        _ => null,
    };

    /// <summary>
    /// Reads a variable's value as the tracks keep it, see <see cref="VariableText"/>.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The value, a Float as <see cref="MessageFields.FloatKey"/>; <see langword="null"/>
    /// for one that does not read.</returns>
    public static RubyValue? VariableOf(string text)
    {
        ArgumentNullException.ThrowIfNull(text);
        if (text is "T" or "F")
        {
            return text == "T";
        }

        if (text.Length == 0)
        {
            return null;
        }

        string rest = text[1..];
        switch (text[0])
        {
            case 'n':
                return BigInteger.TryParse(rest, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out BigInteger number) ? number : null;
            case 'f':
                return new RubyHash { { MessageFields.FloatKey, rest } };
            case 's':
                try
                {
                    return Encoding.UTF8.GetString(Convert.FromBase64String(rest));
                }
                catch (FormatException)
                {
                    return null;
                }

            default:
                return null;
        }
    }

    /// <summary>
    /// Reads the writes the scripts stage for the player's track in a frame, leaving out a value no
    /// story carries.
    /// </summary>
    /// <param name="writes">[[kind, key, value, site], ...].</param>
    /// <returns>The writes, as the tracks write them.</returns>
    /// <exception cref="RubyValueException">A write is no key with a value and a site.</exception>
    public static List<StoryWrite> WritesOf(RubyArray writes)
    {
        ArgumentNullException.ThrowIfNull(writes);
        var read = new List<StoryWrite>(writes.Count);
        foreach (RubyValue write in writes)
        {
            RubyArray fields = write is RubyArray { Count: 4 } found ? found : throw new RubyValueException("A story write is [kind, key, value, site].");
            StoryKey key = KeyOf(fields[0], fields[1]);
            if (TextOf(key, fields[2]) is { } text)
            {
                read.Add(new StoryWrite(key.ToString(), text, SiteText(fields[3])));
            }
        }

        return read;
    }

    /// <summary>
    /// Writes what waits to be written into the game's story as the scripts follow it; the track's
    /// own keys stay here, since the DLL lays them (see <see cref="TakeLay"/>).
    /// </summary>
    /// <param name="take">The take.</param>
    /// <returns>{"state" (nil, or {"why", "track", "part", "gate", "move" ({"from", "to", "gate", "by"} or nil), "chests" (rows), "log" (the rows of the world's story where its log starts, nil for none)}), "keys" (rows in order), "rev"}.</returns>
    public static RubyHash TakeOf(StoryTake take)
    {
        ArgumentNullException.ThrowIfNull(take);
        RubyValue state = RubyNil.Value;
        if (take.State is { } whole)
        {
            state = new RubyHash
            {
                { "why", whole.Why },
                { "track", whole.Track },
                { "part", whole.Part },
                { "gate", whole.Gate is { } gate ? gate : RubyNil.Value },
                { "move", whole.Move is { } move ? new RubyHash { { "from", move.From }, { "to", move.To }, { "gate", move.Gate is { } level ? level : RubyNil.Value }, { "by", move.By } } : RubyNil.Value },
                { "chests", Rows(whole.Chests) },
                { "log", whole.Log is { } log ? Rows(log) : RubyNil.Value },
            };
        }

        return new RubyHash
        {
            { "state", state },
            { "keys", Rows(take.Keys) },
            { "rev", take.Rev },
        };
    }

    /// <summary>
    /// Writes the requests the relay did not keep as written as the scripts read them.
    /// </summary>
    /// <param name="refusals">The refusals.</param>
    /// <returns>[[[kind, key], code, value or nil], ...], a refusal of no key left out.</returns>
    public static RubyArray RefusalsOf(IEnumerable<StoryRefusal> refusals)
    {
        ArgumentNullException.ThrowIfNull(refusals);
        var read = new RubyArray();
        foreach (StoryRefusal refusal in refusals)
        {
            if (StoryKey.TryParse(refusal.Key, out StoryKey key))
            {
                read.Add(new RubyArray { Plain(key), refusal.Code, refusal.Value is { } value ? ValueOf(key, value) : RubyNil.Value });
            }
        }

        return read;
    }

    /// <summary>
    /// Writes a site as the tracks, the save's log and the messages name it.
    /// </summary>
    /// <param name="site">The site, see <see cref="StoryPlain"/>.</param>
    /// <returns>Such as "map:7:39:1", "ce:154", "game" or "game:troop".</returns>
    /// <exception cref="RubyValueException">The value is no site.</exception>
    public static string SiteText(RubyValue site)
    {
        ArgumentNullException.ThrowIfNull(site);
        if (site is RubyArray { Count: > 0 } parts && parts[0] is RubyString)
        {
            string kind = parts[0].AsText();
            switch (kind)
            {
                case "map" when parts.Count == 4 && parts.Skip(1).All(Whole):
                    return string.Create(CultureInfo.InvariantCulture, $"map:{parts[1].AsLong()}:{parts[2].AsLong()}:{parts[3].AsLong()}");
                case "ce" when parts.Count == 2 && Whole(parts[1]):
                    return string.Create(CultureInfo.InvariantCulture, $"ce:{parts[1].AsLong()}");
                case "game" or "list" when parts.Count == 1:
                    return kind;
                case "game" when parts.Count == 2 && parts[1] is RubyString what && !what.AsText().Contains(':', StringComparison.Ordinal):
                    return "game:" + what.AsText();
            }
        }

        throw new RubyValueException($"{site} is no site, such as [\"map\", map, event, page] or [\"ce\", id].");
    }

    /// <summary>
    /// Reads a site as the tracks, the save's log and the messages name it, see <see cref="SiteText"/>.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The site, nil for a text that names none.</returns>
    public static RubyValue SiteOf(string text)
    {
        ArgumentNullException.ThrowIfNull(text);
        string[] parts = text.Split(':');
        return parts switch
        {
            ["map", var map, var eventId, var page] when Number(map) is { } m && Number(eventId) is { } e && Number(page) is { } p => new RubyArray { "map", m, e, p },
            ["ce", var common] when Number(common) is { } id => new RubyArray { "ce", id },
            ["game"] or ["list"] => new RubyArray { parts[0] },
            ["game", var what] when what.Length > 0 => new RubyArray { "game", what },
            _ => RubyNil.Value,
        };
    }

    /// <summary>
    /// Writes a command's place as the save's log and the messages name it.
    /// </summary>
    /// <param name="at">[site, code, number], see <see cref="StoryPlain"/>.</param>
    /// <returns>Such as "map:215:23:1@102:0".</returns>
    /// <exception cref="RubyValueException">The value is no place.</exception>
    public static string PlaceText(RubyValue at)
    {
        ArgumentNullException.ThrowIfNull(at);
        return at is RubyArray { Count: 3 } parts && Whole(parts[1]) && Whole(parts[2])
            ? PlaceText(SiteText(parts[0]), parts[1].AsInt(), parts[2].AsLong())
            : throw new RubyValueException($"{at} is no command's place, which is [site, code, number].");
    }

    /// <summary>
    /// Writes a command's place as the save's log and the messages name it.
    /// </summary>
    /// <param name="site">The list, as <see cref="SiteText"/> writes it.</param>
    /// <param name="code">The command's code.</param>
    /// <param name="number">Its number among the list's commands of that code, from 0.</param>
    /// <returns>Such as "map:215:23:1@102:0".</returns>
    public static string PlaceText(string site, int code, long number) => string.Create(CultureInfo.InvariantCulture, $"{site}@{code}:{number}");

    /// <summary>
    /// Reads a command's place as <see cref="PlaceText(string, int, long)"/> writes it.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="site">The list's text.</param>
    /// <param name="code">The command's code.</param>
    /// <param name="number">Its number among the list's commands of that code.</param>
    /// <returns>Whether the text names a place.</returns>
    public static bool TryParsePlace(string text, out string site, out int code, out long number)
    {
        ArgumentNullException.ThrowIfNull(text);
        int mark = text.LastIndexOf('@');
        string[] parts = mark > 0 ? text[(mark + 1)..].Split(':') : [];
        site = mark > 0 ? text[..mark] : string.Empty;
        code = parts.Length == 2 && Number(parts[0]) is >= 0 and <= int.MaxValue and var found ? (int)found : -1;
        number = parts.Length == 2 && Number(parts[1]) is >= 0 and var count ? count : -1;
        return code >= 0 && number >= 0;
    }

    /// <summary>
    /// Reads the place an entry of an earlier release names an input by: its list, then its
    /// command's place among the list's commands the events database keeps, such as "map:215:23:1@4".
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="site">The list's text.</param>
    /// <param name="ord">The command's place among the kept commands.</param>
    /// <returns>Whether the text names such a place.</returns>
    public static bool TryParseEarlierPlace(string text, out string site, out int ord)
    {
        ArgumentNullException.ThrowIfNull(text);
        int mark = text.LastIndexOf('@');
        site = mark > 0 ? text[..mark] : string.Empty;
        ord = mark > 0 && int.TryParse(text.AsSpan(mark + 1), NumberStyles.None, CultureInfo.InvariantCulture, out int found) ? found : -1;
        return ord >= 0;
    }

    /// <summary>
    /// Reads a command's place, see <see cref="PlaceText(RubyValue)"/>.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>[site, code, number], nil for a text that names none.</returns>
    public static RubyValue PlaceOf(string text) =>
        TryParsePlace(text, out string site, out int code, out long number) && SiteOf(site) is RubyArray list ? new RubyArray { list, code, number } : RubyNil.Value;

    /// <summary>
    /// Writes a thing a replay reads of the player's own as the scripts name it.
    /// </summary>
    /// <param name="name">The thing as the save's log names it: a key's name or <c>actor&lt;id&gt;</c>.</param>
    /// <returns><c>[kind, key]</c>, see <see cref="StoryPlain"/>.</returns>
    /// <exception cref="RubyValueException">The name is no such thing.</exception>
    public static RubyArray ThingOf(string name)
    {
        ArgumentNullException.ThrowIfNull(name);
        if (name.StartsWith(ActorKind, StringComparison.Ordinal) && int.TryParse(name.AsSpan(ActorKind.Length), NumberStyles.None, CultureInfo.InvariantCulture, out int id))
        {
            return [ActorKind, id];
        }

        return StoryKey.TryParse(name, out StoryKey key) ? Plain(key) : throw new RubyValueException($"{name} is nothing a replay reads.");
    }

    /// <summary>
    /// Reads rows of things a replay read of the player's own, each by its name as the save's log
    /// keeps it, with its value as a text there.
    /// </summary>
    /// <param name="rows"><c>[[kind, key, value], ...]</c>, nil for none.</param>
    /// <returns>Each thing's value by its name: a key's as the tracks write it, a companion's
    /// <see cref="OnText"/> or <see cref="OffText"/>.</returns>
    /// <exception cref="RubyValueException">A row is no such thing.</exception>
    public static Dictionary<string, string> ThingTextsOf(RubyValue rows)
    {
        ArgumentNullException.ThrowIfNull(rows);
        var texts = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (RubyValue row in rows.IsNil ? [] : rows.AsArray())
        {
            RubyArray fields = row is RubyArray { Count: 3 } found ? found : throw new RubyValueException($"{row} is no row, which is [kind, key, value].");
            switch (fields[0])
            {
                case RubyString kind when kind.AsText() == ActorKind:
                    texts[string.Create(CultureInfo.InvariantCulture, $"{ActorKind}{fields[1].AsInt()}")] = fields[2] is RubyBool { Flag: true } ? OnText : OffText;
                    break;
                default:
                    StoryKey key = KeyOf(fields[0], fields[1]);
                    texts[key.ToString()] = TextOf(key, fields[2]) ?? string.Empty;
                    break;
            }
        }

        return texts;
    }

    /// <summary>
    /// Writes the self switch rules of a table as rows the scripts look a self switch up in.
    /// </summary>
    /// <typeparam name="T">What a rule names, a class or a scope.</typeparam>
    /// <param name="rules">The rules by key: <c>ss&lt;map&gt;.&lt;event&gt;.&lt;letter&gt;</c>, with
    /// <c>*</c> for every event or letter, or <c>ce&lt;id&gt;.&lt;letter&gt;</c> for the self switches
    /// a common event writes.</param>
    /// <param name="named">Writes what a rule names.</param>
    /// <returns>"self" (<c>[map, event, letter, named]</c> each, nil for every event or letter) and
    /// "common" (<c>[common event, letter, named]</c> each, nil for every letter); a rule that does
    /// not read is left out.</returns>
    public static RubyHash SelfRules<T>(IEnumerable<KeyValuePair<string, T>> rules, Func<T, RubyValue> named)
    {
        ArgumentNullException.ThrowIfNull(rules);
        ArgumentNullException.ThrowIfNull(named);
        var self = new RubyArray();
        var common = new RubyArray();
        foreach ((string rule, T found) in rules.OrderBy(pair => pair.Key, StringComparer.Ordinal))
        {
            string[] parts = rule.Length > 2 ? rule[2..].Split('.') : [];
            if (rule.StartsWith("ss", StringComparison.Ordinal) && parts.Length == 3 && Whole(parts[0]) is { } map)
            {
                self.Add(new RubyArray { map, Any(parts[1], Whole), Any(parts[2], letter => letter), named(found) });
            }
            else if (rule.StartsWith("ce", StringComparison.Ordinal) && parts.Length == 2 && Whole(parts[0]) is { } id)
            {
                common.Add(new RubyArray { id, Any(parts[1], letter => letter), named(found) });
            }
        }

        return new RubyHash { { "self", self }, { "common", common } };
    }

    /// <summary>
    /// Tells a key's kind.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <returns>Its kind.</returns>
    private static int KindOf(StoryKey key) => key.Kind switch
    {
        StoryKeyKind.Switch => SwitchKind,
        StoryKeyKind.Variable => VariableKind,
        StoryKeyKind.SelfSwitch => SelfSwitchKind,
        _ => FreezeKind,
    };

    /// <summary>
    /// Writes a key's id or self switch.
    /// </summary>
    /// <param name="key">The key.</param>
    /// <returns>The id, or [map, event, letter].</returns>
    private static RubyValue KeyPart(StoryKey key) =>
        key.Kind == StoryKeyKind.SelfSwitch ? new RubyArray { key.Id, key.Event, key.Letter } : key.Id;

    /// <summary>
    /// Tells whether a value is a whole number.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>Whether it is.</returns>
    private static bool Whole(RubyValue value) => value is RubyInteger;

    /// <summary>
    /// Reads a whole number of a site.
    /// </summary>
    /// <param name="text">The digits.</param>
    /// <returns>The number, <see langword="null"/> for none.</returns>
    private static long? Number(string text) =>
        long.TryParse(text, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out long number) ? number : null;

    /// <summary>
    /// Reads a whole number of a rule.
    /// </summary>
    /// <param name="text">The digits.</param>
    /// <returns>The number, nil for none.</returns>
    private static RubyValue? Whole(string text) =>
        int.TryParse(text, NumberStyles.None, CultureInfo.InvariantCulture, out int number) ? number : null;

    /// <summary>
    /// Reads a part of a rule that may be <c>*</c>, which stands for every one.
    /// </summary>
    /// <param name="text">The part.</param>
    /// <param name="read">Reads a part that is not <c>*</c>.</param>
    /// <returns>The part, nil for <c>*</c> or one that does not read.</returns>
    private static RubyValue Any(string text, Func<string, RubyValue?> read) => text == "*" ? RubyNil.Value : read(text) ?? RubyNil.Value;
}
