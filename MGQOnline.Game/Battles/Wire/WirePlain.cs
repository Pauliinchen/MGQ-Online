//----------------------------------------------------------------
//  WirePlain.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Numerics;
using System.Text;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Ruby;

namespace MGQOnline.Game.Battles.Wire;

/// <summary>
/// The values of a battle line as the bridge carries them between the scripts and C#: nil, true,
/// false, Integers, Strings and Arrays as themselves, and every other value as a Hash of one key
/// that names its kind, since the bridge carries no Floats, Symbols or game objects.
/// </summary>
/// <remarks>
/// battles_sync_wire.rbx turns the game's objects into these values and back; a Hash never stands
/// for itself, since a line carries none.
/// </remarks>
public static class WirePlain
{
    /// <summary>
    /// The kind of a Float, its text as Ruby's <c>Float#to_s</c> writes it.
    /// </summary>
    public const string FloatKind = "float";

    /// <summary>
    /// The kind of a Symbol, its name.
    /// </summary>
    public const string SymbolKind = "symbol";

    /// <summary>
    /// The kind of a battler, its reference, such as "a0".
    /// </summary>
    public const string BattlerKind = "battler";

    /// <summary>
    /// The kind of an action, its kind's name or nil.
    /// </summary>
    public const string ActionKind = "action";

    /// <summary>
    /// The kind of an equipped or stolen item, the entry it holds or nil.
    /// </summary>
    public const string BaseItemKind = "base_item";

    /// <summary>
    /// The kind of a Color, its red, green, blue and opacity.
    /// </summary>
    public const string ColorKind = "color";

    /// <summary>
    /// The kind of a Tone, its red, green, blue and gray.
    /// </summary>
    public const string ToneKind = "tone";

    /// <summary>
    /// The kind of an action result, its fields as [name, value] pairs in their order.
    /// </summary>
    public const string ResultKind = "result";

    /// <summary>
    /// The kinds of the database's entries, each its id.
    /// </summary>
    private static readonly Dictionary<string, WireTable> Tables = new(StringComparer.Ordinal)
    {
        ["skill"] = WireTable.Skills,
        ["item"] = WireTable.Items,
        ["state"] = WireTable.States,
        ["weapon"] = WireTable.Weapons,
        ["armor"] = WireTable.Armors,
    };

    /// <summary>
    /// Takes the values the scripts handed over.
    /// </summary>
    /// <param name="values">An Array of plain values.</param>
    /// <returns>The line's values.</returns>
    /// <exception cref="BridgeRequestException">A value is of no kind a line carries.</exception>
    public static IReadOnlyList<WireValue> ListOf(RubyValue values)
    {
        ArgumentNullException.ThrowIfNull(values);
        return values is RubyArray list ? list.Select(Of).ToList() : throw new BridgeRequestException($"A line's values come as an Array, not {values.KindName}.");
    }

    /// <summary>
    /// Takes one value the scripts handed over.
    /// </summary>
    /// <param name="value">The plain value.</param>
    /// <returns>The line's value.</returns>
    /// <exception cref="BridgeRequestException">The value is of no kind a line carries.</exception>
    public static WireValue Of(RubyValue value)
    {
        ArgumentNullException.ThrowIfNull(value);
        return value switch
        {
            RubyNil => WireNil.Value,
            RubyBool flag => flag.Flag,
            RubyInteger number => number.Value,
            RubyString text => Encoding.UTF8.GetString(text.Bytes.Span),
            RubyArray list => new WireList(list.Select(Of).ToList()),
            RubyHash { Count: 1 } kinded => Kinded(kinded.Keys.First().AsText(), kinded.First().Value),
            _ => throw new BridgeRequestException($"{value} is no value of a battle line."),
        };
    }

    /// <summary>
    /// Gives the values of a line as the scripts take them.
    /// </summary>
    /// <param name="values">The line's values.</param>
    /// <returns>An Array of plain values.</returns>
    public static RubyArray ToPlain(IEnumerable<WireValue> values)
    {
        ArgumentNullException.ThrowIfNull(values);
        return new RubyArray(values.Select(ToPlain));
    }

    /// <summary>
    /// Gives one value of a line as the scripts take it.
    /// </summary>
    /// <param name="value">The line's value.</param>
    /// <returns>The plain value.</returns>
    public static RubyValue ToPlain(WireValue value)
    {
        ArgumentNullException.ThrowIfNull(value);
        return value switch
        {
            WireNil => RubyNil.Value,
            WireBool flag => flag.Flag,
            WireInteger number => number.Value,
            WireString text => text.Text,
            WireFloat number => Kind(FloatKind, RubyNumbers.FloatToS(number.Value)),
            WireSymbol symbol => Kind(SymbolKind, symbol.Text),
            WireBattler battler => Kind(BattlerKind, battler.Ref),
            WireAction action => Kind(ActionKind, action.Symbol is null ? RubyNil.Value : action.Symbol),
            WireDatabaseItem item => Kind(Tables.First(table => table.Value == item.Table).Key, item.Id),
            WireBaseItem wrapped => Kind(BaseItemKind, wrapped.Item is null ? RubyNil.Value : ToPlain(wrapped.Item)),
            WireColor color => Kind(ColorKind, Channels(color.Red, color.Green, color.Blue, color.Alpha)),
            WireTone tone => Kind(ToneKind, Channels(tone.Red, tone.Green, tone.Blue, tone.Gray)),
            WireList list => ToPlain(list.Items),
            WireResult result => Kind(ResultKind, new RubyArray(result.Fields.Select(field => (RubyValue)new RubyArray { field.Name, ToPlain(field.Value) }))),
            _ => throw new ArgumentException($"{value.GetType().Name} is no value of a line.", nameof(value)),
        };
    }

    /// <summary>
    /// Takes a value of one kind.
    /// </summary>
    /// <param name="kind">The kind, such as <see cref="FloatKind"/>.</param>
    /// <param name="content">What the kind holds.</param>
    /// <returns>The line's value.</returns>
    /// <exception cref="BridgeRequestException">The kind is unknown or holds something else.</exception>
    private static WireValue Kinded(string kind, RubyValue content)
    {
        if (Tables.TryGetValue(kind, out WireTable table))
        {
            return Entry(table, content);
        }

        return kind switch
        {
            FloatKind => new WireFloat(FloatOf(content.AsText())),
            SymbolKind => new WireSymbol(content.AsText()),
            BattlerKind => new WireBattler(content.AsText()),
            ActionKind => new WireAction(content.IsNil ? null : content.AsText()),
            BaseItemKind => new WireBaseItem(content.IsNil ? null : Of(content) as WireDatabaseItem ?? throw new BridgeRequestException($"An equipped item holds {content}, no entry of the database.")),
            ColorKind => Color(Channels(content)),
            ToneKind => Tone(Channels(content)),
            ResultKind => new WireResult(content.AsArray().Select(Field).ToList()),
            _ => throw new BridgeRequestException($"A battle line carries no value of the kind {kind}."),
        };
    }

    /// <summary>
    /// Takes an entry of the database.
    /// </summary>
    /// <param name="table">Its table.</param>
    /// <param name="id">Its id.</param>
    /// <returns>The entry.</returns>
    /// <exception cref="BridgeRequestException">The id is no whole number of the table's range.</exception>
    private static WireDatabaseItem Entry(WireTable table, RubyValue id) =>
        id is RubyInteger { Value: var number } && number >= int.MinValue && number <= int.MaxValue
            ? new WireDatabaseItem(table, (int)number)
            : throw new BridgeRequestException($"An entry of the database has the id {id}.");

    /// <summary>
    /// Takes one field of an action result.
    /// </summary>
    /// <param name="pair">The field's name and value.</param>
    /// <returns>The field.</returns>
    private static WireField Field(RubyValue pair)
    {
        RubyArray parts = pair.AsArray();
        return parts.Count == 2 ? new WireField(parts[0].AsText(), Of(parts[1])) : throw new BridgeRequestException($"A field of an action result is {pair}.");
    }

    /// <summary>
    /// Takes the four channels of a Color or Tone.
    /// </summary>
    /// <param name="content">Four numbers, each an Integer or a Float of its kind.</param>
    /// <returns>The channels.</returns>
    private static double[] Channels(RubyValue content)
    {
        RubyArray channels = content.AsArray();
        if (channels.Count != 4)
        {
            throw new BridgeRequestException($"A color or tone has the channels {content}.");
        }

        return channels.Select(channel => Of(channel) switch
        {
            WireInteger number => (double)number.Value,
            WireFloat number => number.Value,
            _ => throw new BridgeRequestException($"A channel of a color or tone is {channel}."),
        }).ToArray();
    }

    /// <summary>
    /// Makes a Color of its channels.
    /// </summary>
    /// <param name="channels">Red, green, blue and opacity.</param>
    /// <returns>The Color.</returns>
    private static WireColor Color(double[] channels) => new(channels[0], channels[1], channels[2], channels[3]);

    /// <summary>
    /// Makes a Tone of its channels.
    /// </summary>
    /// <param name="channels">Red, green, blue and gray.</param>
    /// <returns>The Tone.</returns>
    private static WireTone Tone(double[] channels) => new(channels[0], channels[1], channels[2], channels[3]);

    /// <summary>
    /// Gives four channels as the scripts take them: a whole number as an Integer, any other as a Float.
    /// </summary>
    /// <param name="channels">The channels.</param>
    /// <returns>The channels.</returns>
    private static RubyArray Channels(params double[] channels) => new(channels.Select(channel =>
        double.IsFinite(channel) && channel == Math.Truncate(channel) && Math.Abs(channel) < 1e15
            ? (RubyValue)new BigInteger(channel)
            : Kind(FloatKind, RubyNumbers.FloatToS(channel))));

    /// <summary>
    /// Writes a value of a kind.
    /// </summary>
    /// <param name="kind">The kind.</param>
    /// <param name="content">What it holds.</param>
    /// <returns>A Hash of one key.</returns>
    private static RubyHash Kind(string kind, RubyValue content) => new() { { kind, content } };

    /// <summary>
    /// Reads a Float as Ruby's <c>Float#to_s</c> wrote it.
    /// </summary>
    /// <param name="text">The text, such as "320.5", "1.0e+20" or "Infinity".</param>
    /// <returns>The number.</returns>
    /// <exception cref="BridgeRequestException">The text is no number.</exception>
    private static double FloatOf(string text) => text switch
    {
        "Infinity" => double.PositiveInfinity,
        "-Infinity" => double.NegativeInfinity,
        "NaN" => double.NaN,
        _ => double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out double number)
            ? number
            : throw new BridgeRequestException($"The Float {text} is no number."),
    };
}
