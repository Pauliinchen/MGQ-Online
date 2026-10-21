//----------------------------------------------------------------
//  CanonicalJson.cs
//
//  Changelog:
//      Paulinchen  2026-10-21: Created
//
//----------------------------------------------------------------

using System;
using System.Buffers;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.Json.Serialization.Metadata;

namespace MGQOnline.Arena.Json;

/// <summary>
/// Writes JSON in one canonical form, so equal content always gives equal bytes and an equal hash.
/// </summary>
public static class CanonicalJson
{
    /// <summary>
    /// The magnitude from which a double no longer holds every integer exactly.
    /// </summary>
    private const double ExactIntegerLimit = 9007199254740992;

    /// <summary>
    /// The magnitude from which a non-integral number is refused, since its fraction would be lost.
    /// </summary>
    private const double FractionLimit = 1e15;

    /// <summary>
    /// The nesting the reader accepts.
    /// </summary>
    private const int MaxDepth = 256;

    /// <summary>
    /// The UTF-8 encoding without BOM that refuses lone surrogates.
    /// </summary>
    private static readonly UTF8Encoding StrictUtf8 = new(encoderShouldEmitUTF8Identifier: false, throwOnInvalidBytes: true);

    /// <summary>
    /// Serializes a value through its source-generated contract and writes it canonically.
    /// </summary>
    /// <typeparam name="T">The value's type.</typeparam>
    /// <param name="value">The value.</param>
    /// <param name="typeInfo">The value's contract, from <see cref="ArenaJsonContext"/> or another context.</param>
    /// <returns>The canonical bytes.</returns>
    /// <exception cref="ArgumentException">The value holds a number or string canonical JSON refuses.</exception>
    public static byte[] Serialize<T>(T value, JsonTypeInfo<T> typeInfo)
    {
        ArgumentNullException.ThrowIfNull(typeInfo);
        return Write(JsonSerializer.SerializeToUtf8Bytes(value, typeInfo));
    }

    /// <summary>
    /// Writes a JSON node canonically.
    /// </summary>
    /// <param name="node">The node, or null for JSON null.</param>
    /// <returns>The canonical bytes.</returns>
    /// <exception cref="ArgumentException">The node holds a number or string canonical JSON refuses.</exception>
    public static byte[] Write(JsonNode? node)
    {
        if (node is null)
        {
            return "null"u8.ToArray();
        }

        ArrayBufferWriter<byte> buffer = new();
        using (Utf8JsonWriter writer = new(buffer))
        {
            node.WriteTo(writer);
        }

        return Write(buffer.WrittenSpan);
    }

    /// <summary>
    /// Writes JSON text canonically.
    /// </summary>
    /// <param name="utf8Json">The JSON as UTF-8.</param>
    /// <returns>The canonical bytes.</returns>
    /// <exception cref="JsonException">The text is not JSON.</exception>
    /// <exception cref="ArgumentException">The JSON holds a duplicate key or a number or string canonical JSON refuses.</exception>
    public static byte[] Write(ReadOnlySpan<byte> utf8Json)
    {
        Utf8JsonReader reader = new(utf8Json, new JsonReaderOptions { MaxDepth = MaxDepth });
        using JsonDocument document = JsonDocument.ParseValue(ref reader);
        return Write(document.RootElement);
    }

    /// <summary>
    /// Writes a JSON element canonically.
    /// </summary>
    /// <param name="element">The element.</param>
    /// <returns>The canonical bytes.</returns>
    /// <exception cref="ArgumentException">The element holds a duplicate key or a number or string canonical JSON refuses.</exception>
    public static byte[] Write(JsonElement element)
    {
        StringBuilder text = new();
        Append(text, element);
        try
        {
            return StrictUtf8.GetBytes(text.ToString());
        }
        catch (EncoderFallbackException e)
        {
            throw new ArgumentException("A string holds a lone surrogate.", nameof(element), e);
        }
    }

    /// <summary>
    /// Appends an element.
    /// </summary>
    /// <param name="text">The text written so far.</param>
    /// <param name="element">The element.</param>
    private static void Append(StringBuilder text, JsonElement element)
    {
        switch (element.ValueKind)
        {
            case JsonValueKind.Object:
                AppendObject(text, element);
                break;
            case JsonValueKind.Array:
                text.Append('[');
                bool first = true;
                foreach (JsonElement item in element.EnumerateArray())
                {
                    if (!first)
                    {
                        text.Append(',');
                    }

                    Append(text, item);
                    first = false;
                }

                text.Append(']');
                break;
            case JsonValueKind.String:
                AppendString(text, element.GetString()!);
                break;
            case JsonValueKind.Number:
                AppendNumber(text, element.GetRawText());
                break;
            case JsonValueKind.True:
                text.Append("true");
                break;
            case JsonValueKind.False:
                text.Append("false");
                break;
            default:
                text.Append("null");
                break;
        }
    }

    /// <summary>
    /// Appends an object with its keys sorted and its null members left out.
    /// </summary>
    /// <param name="text">The text written so far.</param>
    /// <param name="element">The object.</param>
    /// <exception cref="ArgumentException">A key occurs twice.</exception>
    private static void AppendObject(StringBuilder text, JsonElement element)
    {
        List<JsonProperty> members = [];
        HashSet<string> names = new(StringComparer.Ordinal);
        foreach (JsonProperty member in element.EnumerateObject())
        {
            if (!names.Add(member.Name))
            {
                throw new ArgumentException($"The key \"{member.Name}\" occurs twice in one object.", nameof(element));
            }

            if (member.Value.ValueKind != JsonValueKind.Null)
            {
                members.Add(member);
            }
        }

        members.Sort(static (left, right) => string.CompareOrdinal(left.Name, right.Name));
        text.Append('{');
        for (int index = 0; index < members.Count; index++)
        {
            if (index > 0)
            {
                text.Append(',');
            }

            AppendString(text, members[index].Name);
            text.Append(':');
            Append(text, members[index].Value);
        }

        text.Append('}');
    }

    /// <summary>
    /// Appends a string, escaping only the quote, the backslash and control characters.
    /// </summary>
    /// <param name="text">The text written so far.</param>
    /// <param name="value">The string.</param>
    private static void AppendString(StringBuilder text, string value)
    {
        text.Append('"');
        foreach (char character in value)
        {
            switch (character)
            {
                case '"':
                    text.Append("\\\"");
                    break;
                case '\\':
                    text.Append("\\\\");
                    break;
                case '\b':
                    text.Append("\\b");
                    break;
                case '\f':
                    text.Append("\\f");
                    break;
                case '\n':
                    text.Append("\\n");
                    break;
                case '\r':
                    text.Append("\\r");
                    break;
                case '\t':
                    text.Append("\\t");
                    break;
                case < ' ':
                    text.Append("\\u00").Append(((int)character).ToString("x2", CultureInfo.InvariantCulture));
                    break;
                default:
                    text.Append(character);
                    break;
            }
        }

        text.Append('"');
    }

    /// <summary>
    /// Appends a number in its canonical form.
    /// </summary>
    /// <param name="text">The text written so far.</param>
    /// <param name="raw">The number as the JSON held it.</param>
    /// <exception cref="ArgumentException">The number is not finite, or not integral and too large to keep its fraction.</exception>
    private static void AppendNumber(StringBuilder text, string raw)
    {
        if (raw.AsSpan().IndexOfAny('.', 'e', 'E') < 0)
        {
            text.Append(raw == "-0" ? "0" : raw);
            return;
        }

        double number = double.Parse(raw, NumberStyles.Float, CultureInfo.InvariantCulture);
        if (!double.IsFinite(number))
        {
            throw new ArgumentException($"The number {raw} is not finite.", nameof(raw));
        }

        if (double.IsInteger(number) && Math.Abs(number) < ExactIntegerLimit)
        {
            text.Append(((long)number).ToString(CultureInfo.InvariantCulture));
            return;
        }

        if (!double.IsInteger(number) && Math.Abs(number) >= FractionLimit)
        {
            throw new ArgumentException($"The number {raw} is too large to keep its fraction.", nameof(raw));
        }

        text.Append(WithoutExponent(number.ToString("R", CultureInfo.InvariantCulture)));
    }

    /// <summary>
    /// Rewrites a number's shortest round-trip text without an exponent.
    /// </summary>
    /// <param name="shortest">The text, such as "1.5E-05".</param>
    /// <returns>The same digits in positional form, such as "0.000015".</returns>
    private static string WithoutExponent(string shortest)
    {
        int exponentAt = shortest.IndexOf('E', StringComparison.Ordinal);
        if (exponentAt < 0)
        {
            return shortest;
        }

        int exponent = int.Parse(shortest.AsSpan(exponentAt + 1), NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture);
        string mantissa = shortest[..exponentAt];
        bool negative = mantissa.StartsWith('-');
        if (negative)
        {
            mantissa = mantissa[1..];
        }

        int dotAt = mantissa.IndexOf('.', StringComparison.Ordinal);
        string digits = dotAt < 0 ? mantissa : mantissa.Remove(dotAt, 1);
        int point = (dotAt < 0 ? mantissa.Length : dotAt) + exponent;
        string positional = point <= 0
            ? "0." + new string('0', -point) + digits
            : point >= digits.Length
                ? digits + new string('0', point - digits.Length)
                : digits[..point] + "." + digits[point..];
        return negative ? "-" + positional : positional;
    }
}
