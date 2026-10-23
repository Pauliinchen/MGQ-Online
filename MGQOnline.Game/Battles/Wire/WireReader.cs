//----------------------------------------------------------------
//  WireReader.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Numerics;
using System.Text;
using System.Text.Unicode;
using MGQOnline.Game.Ruby;

namespace MGQOnline.Game.Battles.Wire;

/// <summary>
/// Reads a line another game sent, as <c>Wire.parse</c> does: nil for a line that is too long, too
/// deep, broken or no UTF-8, and nil for each token that names nothing this game has.
/// </summary>
public static class WireReader
{
    /// <summary>
    /// The UTF-8 encoding that refuses a text with a lone surrogate.
    /// </summary>
    private static readonly UTF8Encoding StrictUtf8 = new(false, true);

    /// <summary>
    /// Reads a line.
    /// </summary>
    /// <param name="line">The line.</param>
    /// <param name="game">What the reading game knows.</param>
    /// <returns>The values, <see langword="null"/> when the line does not read.</returns>
    public static IReadOnlyList<WireValue>? Parse(string line, WireGame game)
    {
        ArgumentNullException.ThrowIfNull(line);
        byte[] bytes;
        try
        {
            bytes = StrictUtf8.GetBytes(line);
        }
        catch (EncoderFallbackException)
        {
            return null;
        }

        return Parse(bytes, game);
    }

    /// <summary>
    /// Reads a line.
    /// </summary>
    /// <param name="line">The line's UTF-8 bytes.</param>
    /// <param name="game">What the reading game knows.</param>
    /// <returns>The values, <see langword="null"/> when the line does not read.</returns>
    public static IReadOnlyList<WireValue>? Parse(ReadOnlySpan<byte> line, WireGame game)
    {
        ArgumentNullException.ThrowIfNull(game);
        if (line.Length > WireFormat.MaxLineBytes || !Utf8.IsValid(line))
        {
            return null;
        }

        var stack = new List<List<WireValue>> { new() };
        foreach (Range range in Tokens(line))
        {
            ReadOnlySpan<byte> token = line[range];
            if (token.Length == 1 && (token[0] == (byte)'[' || token[0] == (byte)'{'))
            {
                if (stack.Count > WireFormat.MaxDepth)
                {
                    return null;
                }

                stack.Add([]);
            }
            else if (token.Length == 1 && (token[0] == (byte)']' || token[0] == (byte)'}'))
            {
                if (stack.Count < 2)
                {
                    return null;
                }

                List<WireValue> inner = stack[^1];
                stack.RemoveAt(stack.Count - 1);
                stack[^1].Add(token[0] == (byte)']' ? new WireList(inner) : Result(inner, game));
            }
            else
            {
                stack[^1].Add(token.IsEmpty ? WireNil.Value : Value(token[0], token[1..], game));
            }
        }

        return stack.Count == 1 ? stack[0] : null;
    }

    /// <summary>
    /// Splits a line at its tabs as Ruby's <c>String#split</c> does, which drops the empty tokens at its end.
    /// </summary>
    /// <param name="line">The line.</param>
    /// <returns>Each token's place in the line.</returns>
    private static List<Range> Tokens(ReadOnlySpan<byte> line)
    {
        var tokens = new List<Range>();
        int start = 0;
        for (int at = 0; at <= line.Length; at++)
        {
            if (at == line.Length || line[at] == WireFormat.Separator)
            {
                tokens.Add(start..at);
                start = at + 1;
            }
        }

        while (tokens.Count > 0 && tokens[^1].End.Value == tokens[^1].Start.Value)
        {
            tokens.RemoveAt(tokens.Count - 1);
        }

        return tokens;
    }

    /// <summary>
    /// Reads a value back from a token.
    /// </summary>
    /// <param name="kind">The token's first byte; one past ASCII starts a character no kind has.</param>
    /// <param name="rest">The rest of the token.</param>
    /// <param name="game">What the reading game knows.</param>
    /// <returns>The value, nil for anything unknown.</returns>
    private static WireValue Value(byte kind, ReadOnlySpan<byte> rest, WireGame game)
    {
        if (WireFormat.TableOf(kind) is WireTable table)
        {
            return Entry(table, rest, game) ?? (WireValue)WireNil.Value;
        }

        return kind switch
        {
            (byte)'+' => WireBool.True,
            (byte)'-' => WireBool.False,
            (byte)'i' => new WireInteger(RubyNumbers.ToI(rest)),
            (byte)'f' => new WireFloat(RubyNumbers.ToF(rest)),
            (byte)':' => Symbol(WireFormat.Unescape(rest), game) is string text ? new WireSymbol(text) : WireNil.Value,
            (byte)'s' => new WireString(Encoding.UTF8.GetString(WireFormat.Unescape(rest))),
            (byte)'@' => new WireBattler(Encoding.UTF8.GetString(rest)),
            (byte)'x' => new WireAction(Symbol(rest, game)),
            (byte)'g' => BaseItem(rest, game),
            (byte)'c' => Color(Channels(rest)),
            (byte)'n' => Tone(Channels(rest)),
            _ => WireNil.Value,
        };
    }

    /// <summary>
    /// Finds a symbol this game has by its text (<c>Wire.symbol</c>).
    /// </summary>
    /// <param name="text">The symbol's text.</param>
    /// <param name="game">What the reading game knows.</param>
    /// <returns>The symbol's text, <see langword="null"/> for a text that may name no symbol or one this game lacks.</returns>
    private static string? Symbol(ReadOnlySpan<byte> text, WireGame game)
    {
        if (!WireFormat.IsSymbolText(text))
        {
            return null;
        }

        string symbol = Encoding.ASCII.GetString(text);
        return game.HasSymbol(symbol) ? symbol : null;
    }

    /// <summary>
    /// Finds an entry of the database by its id, which counts only within its table (<c>Wire.data</c>).
    /// </summary>
    /// <param name="table">The table.</param>
    /// <param name="rest">The id as text.</param>
    /// <param name="game">What the reading game knows.</param>
    /// <returns>The entry, <see langword="null"/> for an id the table lacks or a table the game lacks.</returns>
    private static WireDatabaseItem? Entry(WireTable table, ReadOnlySpan<byte> rest, WireGame game)
    {
        BigInteger id = RubyNumbers.ToI(rest);
        return game.TableSize(table) is int size && id > 0 && id < size ? new WireDatabaseItem(table, (int)id) : null;
    }

    /// <summary>
    /// Reads an equipped or stolen item: exactly one entry token of the database (<c>Wire.item</c>).
    /// </summary>
    /// <param name="rest">The token after its "g".</param>
    /// <param name="game">What the reading game knows.</param>
    /// <returns>The wrapped entry, nil for anything else.</returns>
    private static WireValue BaseItem(ReadOnlySpan<byte> rest, WireGame game) =>
        !rest.IsEmpty && WireFormat.TableOf(rest[0]) is WireTable table && Entry(table, rest[1..], game) is WireDatabaseItem item
            ? new WireBaseItem(item)
            : WireNil.Value;

    /// <summary>
    /// Makes a color of four channels.
    /// </summary>
    /// <param name="channels">Red, green, blue and opacity.</param>
    /// <returns>The color.</returns>
    private static WireColor Color(double[] channels) => new(channels[0], channels[1], channels[2], channels[3]);

    /// <summary>
    /// Makes a tone of four channels.
    /// </summary>
    /// <param name="channels">Red, green, blue and gray.</param>
    /// <returns>The tone.</returns>
    private static WireTone Tone(double[] channels) => new(channels[0], channels[1], channels[2], channels[3]);

    /// <summary>
    /// Reads four numbers joined by "," (<c>Wire.numbers</c>), 0.0 for those missing.
    /// </summary>
    /// <param name="text">The numbers.</param>
    /// <returns>The first four.</returns>
    private static double[] Channels(ReadOnlySpan<byte> text)
    {
        var numbers = new double[4];
        int count = 0;
        int start = 0;
        int end = text.Length;
        while (end > 0 && text[end - 1] == (byte)',')
        {
            end--;
        }

        for (int at = 0; at <= end && count < numbers.Length; at++)
        {
            if (at == end || text[at] == (byte)',')
            {
                numbers[count++] = RubyNumbers.ToF(text[start..at]);
                start = at + 1;
            }
        }

        return numbers;
    }

    /// <summary>
    /// Makes an action result of its fields (<c>Wire.result</c>): names and values taking turns, a
    /// name that is no symbol or no field of this game's results left out, a last name without a
    /// value set to nil.
    /// </summary>
    /// <param name="fields">The values between the brackets.</param>
    /// <param name="game">What the reading game knows.</param>
    /// <returns>The result.</returns>
    private static WireResult Result(List<WireValue> fields, WireGame game)
    {
        var taken = new List<WireField>();
        for (int at = 0; at < fields.Count; at += 2)
        {
            if (fields[at] is WireSymbol name && game.HasResultField(name.Text))
            {
                taken.Add(new WireField(name.Text, at + 1 < fields.Count ? fields[at + 1] : WireNil.Value));
            }
        }

        return new WireResult(taken);
    }
}
