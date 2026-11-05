//----------------------------------------------------------------
//  TradeItems.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.RegularExpressions;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Game.Actors;
using MGQOnline.Game.Battles.Wire;

namespace MGQOnline.Game.Trade;

/// <summary>
/// The items of a trade's offers as text, the same in both games, and as the values the scripts
/// make them from: an item of the database by its kind and id (<c>i</c>, <c>w</c> or <c>a</c> and
/// the id), an enchanted or socketed copy as <c>u</c>, its text (<see cref="ItemText"/>), a tilde
/// and where its rolled name prefix comes from (the enchantment's id, <c>r</c> or <c>p</c> for its
/// rare or plain prefixes, and the prefix's place in that list), so the receiver reads the prefix
/// from its own data, in its own language.
/// </summary>
public static partial class TradeItems
{
    /// <summary>
    /// The key of a copy's facts, as <see cref="BuildPlain.ItemOf"/> takes them.
    /// </summary>
    public const string CopyKey = "copy";

    /// <summary>
    /// The key of where a copy's name prefix comes from: [enchantment, "r" or "p", place], nil for none.
    /// </summary>
    public const string PrefixKey = "prefix";

    /// <summary>
    /// The letters of the database's tables a token names an item by.
    /// </summary>
    private static readonly Dictionary<WireTable, char> Letters = new() { [WireTable.Items] = 'i', [WireTable.Weapons] = 'w', [WireTable.Armors] = 'a' };

    /// <summary>
    /// Writes an item's token.
    /// </summary>
    /// <param name="item">An item of the database as <see cref="WirePlain"/> carries it, such as
    /// <c>{"weapon" => 12}</c>, or a copy: <c>{"copy" => facts, "prefix" => [enchantment, letter, place] or nil}</c>.</param>
    /// <returns>The token.</returns>
    /// <exception cref="BridgeRequestException">The item is neither.</exception>
    public static string Token(RubyValue item)
    {
        ArgumentNullException.ThrowIfNull(item);
        if (item is RubyHash copy && copy.TryGetValue(CopyKey, out RubyValue? facts))
        {
            return $"u{ItemText.Write(BuildPlain.ItemOf(facts))}~{PrefixRef(copy[PrefixKey])}";
        }

        return WirePlain.Of(item) is WireDatabaseItem entry && Letters.TryGetValue(entry.Table, out char letter)
            ? letter + entry.Id.ToString(CultureInfo.InvariantCulture)
            : throw new BridgeRequestException($"{item} is no item a trade takes.");
    }

    /// <summary>
    /// Reads an item's token into the values the scripts make the item from, see <see cref="Token"/>.
    /// </summary>
    /// <param name="token">The token.</param>
    /// <returns>The item; <see langword="null"/> for a token no game writes or a copy whose text does not read.</returns>
    public static RubyValue Of(string token)
    {
        ArgumentNullException.ThrowIfNull(token);
        if (CopyToken().Match(token) is { Success: true } copy)
        {
            return ItemText.TryRead(copy.Groups[1].Value, out BuildItem? item) && item is not null
                ? new RubyHash { { CopyKey, BuildPlain.ToPlain(item) }, { PrefixKey, PrefixOf(copy.Groups[2].Value) } }
                : RubyNil.Value;
        }

        if (EntryToken().Match(token) is not { Success: true } entry)
        {
            return RubyNil.Value;
        }

        WireTable table = Letters.First(pair => pair.Value == entry.Groups[1].Value[0]).Key;
        return WirePlain.ToPlain(new WireDatabaseItem(table, int.Parse(entry.Groups[2].Value, CultureInfo.InvariantCulture)));
    }

    /// <summary>
    /// Writes where a copy's name prefix comes from.
    /// </summary>
    /// <param name="prefix">[enchantment, "r" or "p", place], nil for none.</param>
    /// <returns>The text, empty for none.</returns>
    private static string PrefixRef(RubyValue prefix) =>
        prefix is RubyArray { Count: 3 } fields ? $"{fields[0].AsLong()}{fields[1].AsText()}{fields[2].AsLong()}" : string.Empty;

    /// <summary>
    /// Reads where a copy's name prefix comes from, see <see cref="PrefixRef"/>.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <returns>[enchantment, "r" or "p", place], nil for none or another text.</returns>
    private static RubyValue PrefixOf(string text) => PrefixText().Match(text) is { Success: true } match
        ? new RubyArray { long.Parse(match.Groups[1].Value, CultureInfo.InvariantCulture), match.Groups[2].Value, long.Parse(match.Groups[3].Value, CultureInfo.InvariantCulture) }
        : RubyNil.Value;

    /// <summary>
    /// A copy's token: <c>u</c>, its text, a tilde and where its prefix comes from.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"\Au([^~]*)~([0-9rp]*)\z")]
    private static partial Regex CopyToken();

    /// <summary>
    /// The token of an item of the database: its table's letter and its id.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"\A([iwa])([0-9]{1,6})\z")]
    private static partial Regex EntryToken();

    /// <summary>
    /// Where a copy's prefix comes from: the enchantment's id, the list's letter and the place.
    /// </summary>
    /// <returns>The pattern.</returns>
    [GeneratedRegex(@"\A([0-9]{1,6})([rp])([0-9]{1,3})\z")]
    private static partial Regex PrefixText();
}
