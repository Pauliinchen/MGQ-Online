//----------------------------------------------------------------
//  MessageFields.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Read whether a telling moves the world's story on as a flag
//                            - Named the kinds of the relay's pushes of a world's difficulty, raid bosses and mods rule
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Numerics;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Coop;
using MGQOnline.Game.World;

namespace MGQOnline.Game.Topics;

/// <summary>
/// How a message's field is written and handed back to the scripts, see <see cref="MessageFields"/>.
/// </summary>
public enum MessageFieldKind
{
    /// <summary>
    /// A text as the scripts handed it; a list's items separated by commas, true and false as 1 and 0.
    /// </summary>
    Text,

    /// <summary>
    /// True or false, written as 1 or 0.
    /// </summary>
    Flag,

    /// <summary>
    /// A whole number, nil for none.
    /// </summary>
    Number,

    /// <summary>
    /// A list of whole numbers, separated by commas, each read as Ruby's <c>to_i</c> reads it.
    /// </summary>
    Numbers,

    /// <summary>
    /// A list of texts without commas, separated by commas.
    /// </summary>
    Texts,

    /// <summary>
    /// Any plain value, Hashes and nested lists too, written as compact JSON.
    /// </summary>
    Value,

    /// <summary>
    /// Any plain value too large for a message as JSON: deflated and written in Base64.
    /// </summary>
    Packed,
}

/// <summary>
/// The one table of the fields of world room and battle channel messages, and of the players'
/// states, that hold more than a text: what kind each is, how it is written, and how the receiving
/// game hands it back to its scripts, so no script builds or splits a field.
/// </summary>
/// <remarks>
/// The table goes by the field's name alone, so a name means one kind in every message; the C#
/// rules read these fields from the written texts and so rely on these written forms.
/// </remarks>
public static class MessageFields
{
    /// <summary>
    /// How a flag that is set is written.
    /// </summary>
    public const string TrueText = "1";

    /// <summary>
    /// How a flag that is not set is written.
    /// </summary>
    public const string FalseText = "0";

    /// <summary>
    /// What separates the items of a list a field holds.
    /// </summary>
    public const char ListSeparator = ',';

    /// <summary>
    /// The key of the Hash that stands for a Float in a <see cref="MessageFieldKind.Value"/>, its
    /// text as the scripts read it with <c>to_f</c>, since the bridge hands the scripts no Floats.
    /// </summary>
    public const string FloatKey = "float";

    /// <summary>
    /// The longest packed field read, twice the story a message carries, since a story too large
    /// for a message goes without what it turned off, unchecked.
    /// </summary>
    public const int MaxPackedLength = 400_000;

    /// <summary>
    /// The most bytes a packed field unpacks to, far beyond any real story's lists.
    /// </summary>
    public const int MaxUnpackedBytes = 8 * 1024 * 1024;

    /// <summary>
    /// The kinds of the fields that hold more than a text, by name.
    /// </summary>
    private static readonly Dictionary<string, MessageFieldKind> Kinds = new(StringComparer.Ordinal)
    {
        // The party's and the trades' invites in a player's state.
        ["invite"] = MessageFieldKind.Flag,
        ["invite_to"] = MessageFieldKind.Texts,
        ["trading"] = MessageFieldKind.Flag,
        ["trading_to"] = MessageFieldKind.Texts,

        // The co-op battles' invites and requests, and a Raid World's boss battle in a state.
        ["busy"] = MessageFieldKind.Flag,
        ["escape"] = MessageFieldKind.Flag,
        ["lose"] = MessageFieldKind.Flag,
        ["served"] = MessageFieldKind.Flag,
        ["hot"] = MessageFieldKind.Flag,
        ["boss"] = MessageFieldKind.Flag,
        ["tiers"] = MessageFieldKind.Flag,
        ["side"] = MessageFieldKind.Flag,
        ["pool"] = MessageFieldKind.Number,
        ["seats"] = MessageFieldKind.Numbers,
        ["rates"] = MessageFieldKind.Numbers,
        ["rpb"] = MessageFieldKind.Value,

        // The party's story: how far a story is, the offers to sync it, a story scene told, whether a
        // telling moves the world's story on, and the story's messages.
        ["sm"] = MessageFieldKind.Numbers,
        ["ssoffer"] = MessageFieldKind.Value,
        ["telling"] = MessageFieldKind.Flag,
        ["moves"] = MessageFieldKind.Flag,
        ["z"] = MessageFieldKind.Packed,
        ["part"] = MessageFieldKind.Flag,
        ["s"] = MessageFieldKind.Value,
        ["v"] = MessageFieldKind.Value,
        ["ss"] = MessageFieldKind.Value,
        ["k"] = MessageFieldKind.Value,
        ["runs"] = MessageFieldKind.Texts,

        // The followers shown behind a ghost, an emote, and a live battle message's number.
        ["trail"] = MessageFieldKind.Value,
        ["emote"] = MessageFieldKind.Number,
        ["sq"] = MessageFieldKind.Number,

        // What the relay pushes of a world's settings: its difficulty, whether its story bosses
        // fight as raid bosses and whether it turns other mods off.
        ["difficulty_value"] = MessageFieldKind.Number,
        ["raid_bosses_value"] = MessageFieldKind.Flag,
        ["mods_rule_value"] = MessageFieldKind.Flag,
    };

    /// <summary>
    /// How a value's JSON is written: compact, letters outside ASCII as themselves.
    /// </summary>
    private static readonly JsonWriterOptions JsonOptions = new() { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping };

    /// <summary>
    /// Tells a field's kind.
    /// </summary>
    /// <param name="name">The field's name.</param>
    /// <returns>Its kind, <see cref="MessageFieldKind.Text"/> for one the table does not name.</returns>
    public static MessageFieldKind KindOf(string name) => Kinds.TryGetValue(name, out MessageFieldKind kind) ? kind : MessageFieldKind.Text;

    /// <summary>
    /// Writes a field's value the scripts handed over as its kind writes it.
    /// </summary>
    /// <param name="name">The field's name.</param>
    /// <param name="value">The value; nil for none.</param>
    /// <returns>The text.</returns>
    /// <exception cref="BridgeRequestException">The value is not of the field's kind.</exception>
    public static string Write(string name, RubyValue value)
    {
        ArgumentNullException.ThrowIfNull(name);
        ArgumentNullException.ThrowIfNull(value);
        MessageFieldKind kind = KindOf(name);
        if (value.IsNil)
        {
            return kind == MessageFieldKind.Flag ? FalseText : string.Empty;
        }

        return kind switch
        {
            MessageFieldKind.Flag => value is RubyBool flag ? FlagText(flag.Flag) : throw Refused(name, value, "true or false"),
            MessageFieldKind.Number => value is RubyInteger number ? number.Value.ToString(CultureInfo.InvariantCulture) : throw Refused(name, value, "a whole number"),
            MessageFieldKind.Numbers => value is RubyArray numbers && numbers.All(item => item is RubyInteger)
                ? string.Join(ListSeparator, numbers.Select(item => ((RubyInteger)item).Value.ToString(CultureInfo.InvariantCulture)))
                : throw Refused(name, value, "a list of whole numbers"),
            MessageFieldKind.Texts => value is RubyArray texts && texts.All(item => item is RubyString && !MessageTopics.BodyOf(item).Contains(ListSeparator))
                ? string.Join(ListSeparator, texts.Select(MessageTopics.BodyOf))
                : throw Refused(name, value, "a list of texts without commas"),
            MessageFieldKind.Value => JsonOf(value),
            MessageFieldKind.Packed => Pack(JsonOf(value)),
            _ => value is RubyArray items ? string.Join(ListSeparator, items.Select(TextOf)) : TextOf(value),
        };
    }

    /// <summary>
    /// Reads a field another game wrote as its kind hands it to the scripts; a number or a value
    /// that does not read gives nil, as for a field left empty.
    /// </summary>
    /// <param name="name">The field's name.</param>
    /// <param name="text">The text.</param>
    /// <returns>The value.</returns>
    public static RubyValue Read(string name, string text)
    {
        ArgumentNullException.ThrowIfNull(name);
        ArgumentNullException.ThrowIfNull(text);
        return KindOf(name) switch
        {
            MessageFieldKind.Flag => text == TrueText,
            MessageFieldKind.Number => NumberOf(text) is { } number ? number : RubyNil.Value,
            MessageFieldKind.Numbers => new RubyArray(CoopText.Split(text, ListSeparator).Select(item => (RubyValue)WorldFields.ToI(item))),
            MessageFieldKind.Texts => new RubyArray(text.Split(ListSeparator, StringSplitOptions.RemoveEmptyEntries).Select(item => (RubyValue)item)),
            MessageFieldKind.Value => ValueOfJson(text),
            MessageFieldKind.Packed => ValueOfJson(Unpack(text)),
            _ => text,
        };
    }

    /// <summary>
    /// Writes a flag as a field holds it.
    /// </summary>
    /// <param name="flag">The flag.</param>
    /// <returns><see cref="TrueText"/> or <see cref="FalseText"/>.</returns>
    public static string FlagText(bool flag) => flag ? TrueText : FalseText;

    /// <summary>
    /// Writes a single value of a text field as the scripts' <c>to_s</c> does, true and false as
    /// flags.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The text.</returns>
    /// <exception cref="BridgeRequestException">The value is a list or a Hash.</exception>
    public static string TextOf(RubyValue value) => value switch
    {
        RubyNil => string.Empty,
        RubyString => MessageTopics.BodyOf(value),
        RubyInteger number => number.Value.ToString(CultureInfo.InvariantCulture),
        RubyBool flag => FlagText(flag.Flag),
        _ => throw new BridgeRequestException($"A field holds {value}, which is no text, number, true, false or nil."),
    };

    /// <summary>
    /// Writes a value as compact JSON: nil, true, false, numbers, texts, lists and Hashes with text
    /// keys as themselves, a Float as a Hash of <see cref="FloatKey"/>.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The JSON.</returns>
    /// <exception cref="BridgeRequestException">The value holds anything else, or a Hash a key that is no text.</exception>
    public static string JsonOf(RubyValue value)
    {
        ArgumentNullException.ThrowIfNull(value);
        using var buffer = new MemoryStream();
        using (var json = new Utf8JsonWriter(buffer, JsonOptions))
        {
            WriteJson(json, value);
        }

        return Encoding.UTF8.GetString(buffer.ToArray());
    }

    /// <summary>
    /// Reads JSON as plain values, see <see cref="JsonOf"/>.
    /// </summary>
    /// <param name="text">The JSON, empty for none.</param>
    /// <returns>The value; nil for none or for a text that is no JSON.</returns>
    public static RubyValue ValueOfJson(string text)
    {
        ArgumentNullException.ThrowIfNull(text);
        if (text.Length == 0)
        {
            return RubyNil.Value;
        }

        try
        {
            using JsonDocument document = JsonDocument.Parse(text);
            return ValueOf(document.RootElement);
        }
        catch (JsonException)
        {
            return RubyNil.Value;
        }
    }

    /// <summary>
    /// Deflates a text and writes it in Base64.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The packed text.</returns>
    private static string Pack(string text)
    {
        using var packed = new MemoryStream();
        using (var deflate = new DeflateStream(packed, CompressionLevel.Optimal, leaveOpen: true))
        {
            deflate.Write(Encoding.UTF8.GetBytes(text));
        }

        return Convert.ToBase64String(packed.ToArray());
    }

    /// <summary>
    /// Unpacks a text <see cref="Pack"/> wrote, refusing one longer than <see cref="MaxPackedLength"/>
    /// or one that unpacks past <see cref="MaxUnpackedBytes"/>.
    /// </summary>
    /// <param name="text">The packed text.</param>
    /// <returns>The text, empty for one that does not unpack or is refused.</returns>
    private static string Unpack(string text)
    {
        if (text.Length == 0 || text.Length > MaxPackedLength)
        {
            return string.Empty;
        }

        try
        {
            using var deflate = new DeflateStream(new MemoryStream(Convert.FromBase64String(text)), CompressionMode.Decompress);
            using var unpacked = new MemoryStream();
            byte[] slice = new byte[64 * 1024];
            int read;
            while ((read = deflate.Read(slice)) > 0)
            {
                unpacked.Write(slice, 0, read);
                if (unpacked.Length > MaxUnpackedBytes)
                {
                    return string.Empty;
                }
            }

            return Encoding.UTF8.GetString(unpacked.ToArray());
        }
        catch (Exception e) when (e is FormatException or InvalidDataException)
        {
            return string.Empty;
        }
    }

    /// <summary>
    /// Reads a whole number as written.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>The number, <see langword="null"/> for a text that is none.</returns>
    private static long? NumberOf(string text) =>
        long.TryParse(text, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out long number) ? number : null;

    /// <summary>
    /// Writes a value into JSON, see <see cref="JsonOf"/>.
    /// </summary>
    /// <param name="json">The writer.</param>
    /// <param name="value">The value.</param>
    /// <exception cref="BridgeRequestException">The value holds what JSON of the fields carries not.</exception>
    private static void WriteJson(Utf8JsonWriter json, RubyValue value)
    {
        switch (value)
        {
            case RubyNil:
                json.WriteNullValue();
                break;
            case RubyBool flag:
                json.WriteBooleanValue(flag.Flag);
                break;
            case RubyInteger number:
                json.WriteRawValue(number.Value.ToString(CultureInfo.InvariantCulture));
                break;
            case RubyString:
                json.WriteStringValue(MessageTopics.BodyOf(value));
                break;
            case RubyFloat real:
                json.WriteStartObject();
                json.WriteString(FloatKey, real.ToString());
                json.WriteEndObject();
                break;
            case RubyArray items:
                json.WriteStartArray();
                foreach (RubyValue item in items)
                {
                    WriteJson(json, item);
                }

                json.WriteEndArray();
                break;
            case RubyHash hash:
                json.WriteStartObject();
                foreach (KeyValuePair<RubyValue, RubyValue> pair in hash)
                {
                    json.WritePropertyName(pair.Key is RubyString ? MessageTopics.BodyOf(pair.Key) : throw new BridgeRequestException($"A field's Hash has the key {pair.Key}, which is no text."));
                    WriteJson(json, pair.Value);
                }

                json.WriteEndObject();
                break;
            default:
                throw new BridgeRequestException($"A field holds {value}, which no message carries.");
        }
    }

    /// <summary>
    /// Reads a JSON element as plain values.
    /// </summary>
    /// <param name="element">The element.</param>
    /// <returns>The value; nil for a number that is not whole.</returns>
    private static RubyValue ValueOf(JsonElement element) => element.ValueKind switch
    {
        JsonValueKind.True => RubyBool.True,
        JsonValueKind.False => RubyBool.False,
        JsonValueKind.String => element.GetString(),
        JsonValueKind.Number => element.TryGetInt64(out long number) ? number
            : BigInteger.TryParse(element.GetRawText(), NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out BigInteger large) ? large : RubyNil.Value,
        JsonValueKind.Array => new RubyArray(element.EnumerateArray().Select(ValueOf)),
        JsonValueKind.Object => HashOf(element),
        _ => RubyNil.Value,
    };

    /// <summary>
    /// Reads a JSON object as a Hash with text keys.
    /// </summary>
    /// <param name="element">The object.</param>
    /// <returns>The Hash.</returns>
    private static RubyHash HashOf(JsonElement element)
    {
        var hash = new RubyHash();
        foreach (JsonProperty property in element.EnumerateObject())
        {
            hash[property.Name] = ValueOf(property.Value);
        }

        return hash;
    }

    /// <summary>
    /// Makes the refusal of a value not of its field's kind.
    /// </summary>
    /// <param name="name">The field's name.</param>
    /// <param name="value">The value.</param>
    /// <param name="kind">What the field holds.</param>
    /// <returns>The refusal.</returns>
    private static BridgeRequestException Refused(string name, RubyValue value, string kind) =>
        new($"The field {name} holds {value}, not {kind}.");
}
