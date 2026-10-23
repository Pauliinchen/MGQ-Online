//----------------------------------------------------------------
//  WireWriter.cs
//
//  Changelog:
//      Paulinchen  2026-10-23: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Numerics;
using System.Text;
using MGQOnline.Game.Ruby;

namespace MGQOnline.Game.Battles.Wire;

/// <summary>
/// Writes values as one line of tab-separated tokens, as <c>Wire.line</c> does.
/// </summary>
public static class WireWriter
{
    /// <summary>
    /// The UTF-8 encoding that refuses a text with a lone surrogate, which Ruby can never hold.
    /// </summary>
    private static readonly UTF8Encoding StrictUtf8 = new(false, true);

    /// <summary>
    /// Writes values as a line.
    /// </summary>
    /// <param name="values">The values.</param>
    /// <returns>The line, empty for no values.</returns>
    /// <exception cref="ArgumentException">A text holds a lone surrogate, a battler reference or an
    /// action kind holds a tab or line break, or a color or tone channel is no finite number.</exception>
    public static string Line(IReadOnlyList<WireValue> values)
    {
        ArgumentNullException.ThrowIfNull(values);
        var tokens = new List<string>();
        foreach (WireValue value in values)
        {
            AddTokens(tokens, value);
        }

        string line = string.Join('\t', tokens);
        try
        {
            StrictUtf8.GetByteCount(line);
        }
        catch (EncoderFallbackException e)
        {
            throw new ArgumentException("A text of the line holds a lone surrogate.", nameof(values), e);
        }

        return line;
    }

    /// <summary>
    /// Writes values as a line.
    /// </summary>
    /// <param name="values">The values.</param>
    /// <returns>The line, empty for no values.</returns>
    /// <exception cref="ArgumentException">See <see cref="Line(IReadOnlyList{WireValue})"/>.</exception>
    public static string Line(params WireValue[] values) => Line((IReadOnlyList<WireValue>)values);

    /// <summary>
    /// Adds a value's tokens.
    /// </summary>
    /// <param name="tokens">The tokens so far.</param>
    /// <param name="value">The value.</param>
    private static void AddTokens(List<string> tokens, WireValue value)
    {
        switch (value)
        {
            case WireList list:
                tokens.Add("[");
                foreach (WireValue item in list.Items)
                {
                    AddTokens(tokens, item);
                }

                tokens.Add("]");
                break;
            case WireResult result:
                tokens.Add("{");
                foreach (WireField field in result.Fields)
                {
                    tokens.Add(":" + WireFormat.Escape(field.Name));
                    AddTokens(tokens, field.Value);
                }

                tokens.Add("}");
                break;
            default:
                tokens.Add(Token(value));
                break;
        }
    }

    /// <summary>
    /// Writes a value that is one token.
    /// </summary>
    /// <param name="value">The value, no list or result.</param>
    /// <returns>The token.</returns>
    private static string Token(WireValue value) => value switch
    {
        WireNil => "~",
        WireBool flag => flag.Flag ? "+" : "-",
        WireInteger number => "i" + number.Value.ToString(CultureInfo.InvariantCulture),
        WireFloat number => "f" + RubyNumbers.FloatToS(number.Value),
        WireSymbol symbol => ":" + WireFormat.Escape(symbol.Text),
        WireString text => "s" + WireFormat.Escape(text.Text),
        WireBattler battler => "@" + Raw(battler.Ref),
        WireAction action => "x" + Raw(action.Symbol ?? string.Empty),
        WireDatabaseItem item => ItemToken(item),
        WireBaseItem wrapped => "g" + (wrapped.Item is null ? "~" : ItemToken(wrapped.Item)),
        WireColor color => "c" + Channels(color.Red, color.Green, color.Blue, color.Alpha),
        WireTone tone => "n" + Channels(tone.Red, tone.Green, tone.Blue, tone.Gray),
        _ => throw new ArgumentException($"{value.GetType().Name} is no value of a line.", nameof(value)),
    };

    /// <summary>
    /// Writes an entry of the database as its token.
    /// </summary>
    /// <param name="item">The entry.</param>
    /// <returns>Such as "k12".</returns>
    private static string ItemToken(WireDatabaseItem item) =>
        WireFormat.KindOf(item.Table) + item.Id.ToString(CultureInfo.InvariantCulture);

    /// <summary>
    /// Writes four channels as whole numbers, cut toward zero as Ruby's <c>Float#to_i</c> cuts them.
    /// </summary>
    /// <param name="first">The first channel.</param>
    /// <param name="second">The second channel.</param>
    /// <param name="third">The third channel.</param>
    /// <param name="fourth">The fourth channel.</param>
    /// <returns>Such as "255,128,0,255".</returns>
    private static string Channels(double first, double second, double third, double fourth) =>
        string.Join(',', Whole(first), Whole(second), Whole(third), Whole(fourth));

    /// <summary>
    /// Cuts a channel to a whole number.
    /// </summary>
    /// <param name="channel">The channel.</param>
    /// <returns>Its whole part as text.</returns>
    private static string Whole(double channel) => double.IsFinite(channel)
        ? new BigInteger(Math.Truncate(channel)).ToString(CultureInfo.InvariantCulture)
        : throw new ArgumentException($"A channel of {channel} has no whole part.", nameof(channel));

    /// <summary>
    /// Checks a text that goes unescaped, as Ruby writes battler references and action kinds.
    /// </summary>
    /// <remarks>
    /// Ruby writes such a tab or line break as it is and so breaks its line; the game's references
    /// and kinds never hold one.
    /// </remarks>
    /// <param name="text">The text.</param>
    /// <returns>The text.</returns>
    private static string Raw(string text) => text.AsSpan().IndexOfAny('\t', '\n', '\r') < 0
        ? text
        : throw new ArgumentException($"\"{WireFormat.Escape(text)}\" would end its token.", nameof(text));
}
