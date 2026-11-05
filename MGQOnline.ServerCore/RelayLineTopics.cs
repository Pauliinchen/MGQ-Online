//----------------------------------------------------------------
//  RelayLineTopics.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Buffers;
using System.Collections.Generic;
using System.Text;
using System.Text.Json;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Raid;
using MGQOnline.Game.Topics;

namespace MGQOnline.ServerCore;

/// <summary>
/// The topics that write and read the lines of a battle channel between the relay and the battle
/// server (BattleServer/lib/relay_bridge.rb), one JSON object per line each way; the server's
/// scripts hand values over and send or take the lines as they are.
/// </summary>
/// <remarks>
/// A message's text travels in base64, since a line ends at its first line feed.
/// </remarks>
internal static class RelayLineTopics
{
    /// <summary>
    /// Writes a line of the server: <c>op</c> and its fields in (<c>send</c>: <c>seat</c>, -1 for
    /// every player, and <c>text</c>; <c>serving</c>; <c>refused</c>: <c>code</c> and <c>error</c>;
    /// <c>boss_report</c>: <c>key</c>, <c>battle</c> and <c>report</c>, as <see cref="PoolReport.Read"/>
    /// reads it; <c>admit</c>: <c>seats</c>; <c>end</c>: <c>result</c>, and <c>turns</c> and
    /// <c>error</c> when given); the line without its line feed out, nil for a report that is none.
    /// </summary>
    public const string Write = "relay.line.write";

    /// <summary>
    /// Reads a line of the relay: the line in; the entry out: <c>kind</c> <c>in</c> or <c>out</c>
    /// with <c>seat</c>, <c>message</c> with <c>seat</c> and <c>text</c>, <c>closed</c> with
    /// <c>seat</c> 0 and <c>code</c> <c>relay</c> for the relay's close or a line that is no JSON
    /// object, or <c>boss</c> with <c>key</c>, <c>left</c> (the share as text, nil for a report the
    /// relay refused), <c>max</c>, <c>defeated</c>, <c>by</c> and <c>answer</c>; nil for a line of
    /// another op.
    /// </summary>
    public const string Read = "relay.line.read";

    /// <summary>
    /// Registers the topics on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        context.Register(Write, (_, request) => WriteLine(request.AsHash()));
        context.Register(Read, (_, request) => ReadLine(request.AsBytes().Span));
    }

    /// <summary>
    /// Answers <see cref="Write"/>.
    /// </summary>
    /// <param name="fields">The op and its fields.</param>
    /// <returns>The line, nil for a report that is none.</returns>
    /// <exception cref="BridgeRequestException">The op is none the server sends.</exception>
    private static RubyValue WriteLine(RubyHash fields)
    {
        string op = fields["op"].AsText();
        var buffer = new ArrayBufferWriter<byte>();
        using (var json = new Utf8JsonWriter(buffer))
        {
            json.WriteStartObject();
            json.WriteString("op", op);
            switch (op)
            {
                case "send":
                    json.WriteNumber("seat", fields["seat"].AsLong());
                    json.WriteBase64String("text", fields["text"].AsBytes().Span);
                    break;
                case "serving":
                    break;
                case "refused":
                    json.WriteString("code", fields["code"].AsText());
                    json.WriteString("error", fields["error"].AsText());
                    break;
                case "boss_report":
                    if (PoolReport.Read(fields["report"].AsText()) is not { } report)
                    {
                        return RubyNil.Value;
                    }

                    json.WriteString("key", fields["key"].AsText());
                    json.WriteString("battle", fields["battle"].AsText());
                    json.WriteNumber("seq", report.Seq);
                    json.WriteNumber("delta", report.Delta);
                    json.WriteNumber("max", report.Max);
                    json.WriteBoolean("killed", report.Killed);
                    break;
                case "admit":
                    json.WriteStartArray("seats");
                    foreach (RubyValue seat in fields["seats"].AsArray())
                    {
                        json.WriteNumberValue(seat.AsLong());
                    }

                    json.WriteEndArray();
                    break;
                case "end":
                    json.WriteString("result", fields["result"].AsText());
                    if (!fields["turns"].IsNil)
                    {
                        json.WriteNumber("turns", fields["turns"].AsLong());
                    }

                    if (!fields["error"].IsNil)
                    {
                        json.WriteString("error", fields["error"].AsText());
                    }

                    break;
                default:
                    throw new BridgeRequestException($"The server sends the relay no {op} line.");
            }

            json.WriteEndObject();
        }

        return Encoding.UTF8.GetString(buffer.WrittenSpan);
    }

    /// <summary>
    /// Answers <see cref="Read"/>.
    /// </summary>
    /// <param name="line">The line's bytes.</param>
    /// <returns>The entry, nil for a line of another op.</returns>
    private static RubyValue ReadLine(ReadOnlySpan<byte> line)
    {
        try
        {
            using JsonDocument document = JsonDocument.Parse(line.ToArray());
            JsonElement fields = document.RootElement;
            if (fields.ValueKind != JsonValueKind.Object)
            {
                return Closed();
            }

            string? op = fields.TryGetProperty("op", out JsonElement named) && named.ValueKind == JsonValueKind.String ? named.GetString() : null;
            return op switch
            {
                "in" or "out" => new RubyHash { { "kind", op }, { "seat", SeatOf(fields) } },
                "message" => new RubyHash { { "kind", "message" }, { "seat", SeatOf(fields) }, { "text", Encoding.UTF8.GetString(fields.GetProperty("text").GetBytesFromBase64()) } },
                "close" => Closed(),
                "boss" => BossOf(fields),
                _ => RubyNil.Value,
            };
        }
        catch (Exception ex) when (ex is JsonException or InvalidOperationException or FormatException or KeyNotFoundException)
        {
            return Closed();
        }
    }

    /// <summary>
    /// Makes the entry of the channel's end.
    /// </summary>
    /// <returns>The entry.</returns>
    private static RubyHash Closed() => new() { { "kind", "closed" }, { "seat", 0L }, { "code", "relay" } };

    /// <summary>
    /// Reads a line's seat.
    /// </summary>
    /// <param name="fields">The line.</param>
    /// <returns>The seat, 0 for none.</returns>
    private static long SeatOf(JsonElement fields) =>
        fields.TryGetProperty("seat", out JsonElement seat) && seat.TryGetInt64(out long number) ? number : 0;

    /// <summary>
    /// Reads what the relay told of a boss pool, as <c>raid.pool.heard</c> takes it.
    /// </summary>
    /// <param name="fields">The line.</param>
    /// <returns>The entry, nil for a line that names no pool.</returns>
    private static RubyValue BossOf(JsonElement fields)
    {
        string key = fields.TryGetProperty("key", out JsonElement named) && named.ValueKind == JsonValueKind.String ? named.GetString()! : string.Empty;
        if (key.Length == 0)
        {
            return RubyNil.Value;
        }

        bool told = fields.TryGetProperty("left", out JsonElement left) && left.ValueKind == JsonValueKind.Number;
        return new RubyHash
        {
            { "kind", "boss" },
            { "key", key },
            { "left", told ? PoolTopics.ShareText(left.GetDouble()) : RubyNil.Value },
            { "max", fields.TryGetProperty("max", out JsonElement max) && max.ValueKind == JsonValueKind.Number ? (long)max.GetDouble() : 0L },
            { "defeated", fields.TryGetProperty("defeated", out JsonElement defeated) && defeated.ValueKind == JsonValueKind.True },
            { "by", fields.TryGetProperty("by", out JsonElement by) && by.ValueKind == JsonValueKind.String ? by.GetString() : string.Empty },
            { "answer", fields.TryGetProperty("answer", out JsonElement answer) && answer.ValueKind == JsonValueKind.True },
        };
    }
}
