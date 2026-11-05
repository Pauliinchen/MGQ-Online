//----------------------------------------------------------------
//  TradeOffers.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Wrote and read an offer, which the scripts no longer build or split
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;

namespace MGQOnline.Game.Trade;

/// <summary>
/// The offers of a trade as text: one player's offer (<c>g</c> and the gold, then each item's token,
/// a star and its amount, split by semicolons), both offers as the relay compares them, and the id
/// the relay knows the confirmed offers by.
/// </summary>
public static class TradeOffers
{
    /// <summary>
    /// An offer that holds nothing, as the scripts write one.
    /// </summary>
    public const string Empty = "g0";

    /// <summary>
    /// Most bytes both offers may have together as the relay compares them, in UTF-8.
    /// </summary>
    public const int MaxOffersBytes = 32 * 1024;

    /// <summary>
    /// Most of one item a trade moves, the game's own cap of a stack.
    /// </summary>
    public const int MaxAmount = 99;

    /// <summary>
    /// Most digits of an offer's gold.
    /// </summary>
    private const int MaxGoldDigits = 10;

    /// <summary>
    /// Most digits of an item's amount.
    /// </summary>
    private const int MaxAmountDigits = 3;

    /// <summary>
    /// Tells whether an offer is written as a game writes one: the gold first, then items of 1 to
    /// <see cref="MaxAmount"/> each, an enchanted or socketed copy (a token starting with <c>u</c>)
    /// one at a time.
    /// </summary>
    /// <param name="offer">The offer.</param>
    /// <returns>Whether it is.</returns>
    public static bool IsValid(string offer)
    {
        ArgumentNullException.ThrowIfNull(offer);
        string[] parts = offer.Split(';');
        if (!IsGold(parts[0]))
        {
            return false;
        }

        foreach (string part in parts.Skip(1))
        {
            if (Entry(part) is not { } entry || entry.Amount is < 1 or > MaxAmount || (entry.Token[0] == 'u' && entry.Amount != 1))
            {
                return false;
            }
        }

        return true;
    }

    /// <summary>
    /// Tells whether an offer holds nothing, read as the scripts read an offer: no gold above 0 and
    /// no part that names an item.
    /// </summary>
    /// <param name="offer">The offer.</param>
    /// <returns>Whether it does.</returns>
    public static bool IsEmpty(string offer)
    {
        ArgumentNullException.ThrowIfNull(offer);
        long gold = 0;
        foreach (string part in RubySplit(offer, ';'))
        {
            if (IsGold(part))
            {
                gold = long.Parse(part.AsSpan(1), NumberStyles.None, CultureInfo.InvariantCulture);
            }
            else if (Entry(part) is not null)
            {
                return false;
            }
        }

        return gold <= 0;
    }

    /// <summary>
    /// Writes an offer as games of every release write it: <c>g</c> and the gold, then each item's
    /// token, a star and its amount, separated by semicolons.
    /// </summary>
    /// <param name="gold">The gold.</param>
    /// <param name="items">Each item's token (see <see cref="TradeItems.Token"/>) and amount.</param>
    /// <returns>The offer.</returns>
    public static string Write(long gold, IEnumerable<(string Token, long Amount)> items)
    {
        ArgumentNullException.ThrowIfNull(items);
        return string.Join(';', items.Select(item => $"{item.Token}*{item.Amount.ToString(CultureInfo.InvariantCulture)}").Prepend($"g{gold.ToString(CultureInfo.InvariantCulture)}"));
    }

    /// <summary>
    /// Reads an offer as the scripts read one: the last gold part counts, each part that names an
    /// item adds it, any other part is left out.
    /// </summary>
    /// <param name="offer">The offer.</param>
    /// <returns>The gold and each item's token and amount.</returns>
    public static (long Gold, List<(string Token, int Amount)> Items) Read(string offer)
    {
        ArgumentNullException.ThrowIfNull(offer);
        long gold = 0;
        List<(string Token, int Amount)> items = [];
        foreach (string part in RubySplit(offer, ';'))
        {
            if (IsGold(part))
            {
                gold = long.Parse(part.AsSpan(1), NumberStyles.None, CultureInfo.InvariantCulture);
            }
            else if (Entry(part) is { } entry)
            {
                items.Add(entry);
            }
        }

        return (gold, items);
    }

    /// <summary>
    /// Writes both offers as the relay compares them: each player's id and offer, ordered by id, so
    /// both games write the same text.
    /// </summary>
    /// <param name="ownId">The player's id.</param>
    /// <param name="mine">The player's offer.</param>
    /// <param name="partnerId">The other player's id.</param>
    /// <param name="theirs">The other player's offer as they sent it.</param>
    /// <returns>The text, one line.</returns>
    public static string AgreedText(string ownId, string mine, string partnerId, string theirs) =>
        string.CompareOrdinal(ownId, partnerId) <= 0 ? $"{ownId}={mine}|{partnerId}={theirs}" : $"{partnerId}={theirs}|{ownId}={mine}";

    /// <summary>
    /// Tells whether both offers are too long for the relay.
    /// </summary>
    /// <param name="agreedText">Both offers, see <see cref="AgreedText"/>.</param>
    /// <returns>Whether they are.</returns>
    public static bool IsTooLarge(string agreedText) => Encoding.UTF8.GetByteCount(agreedText) > MaxOffersBytes;

    /// <summary>
    /// Names the confirmed offers for the relay: the trade's id and both revisions as four
    /// hexadecimal digits each, ordered by player id, so both games name them alike and a later
    /// confirmation is a trade of its own.
    /// </summary>
    /// <param name="tradeId">The trade's id.</param>
    /// <param name="ownId">The player's id.</param>
    /// <param name="myRevision">How often the player changed their offer.</param>
    /// <param name="partnerId">The other player's id.</param>
    /// <param name="theirRevision">How often the other player changed theirs.</param>
    /// <returns>The id, 32 hexadecimal characters for a trade's id of 24.</returns>
    public static string RelayId(string tradeId, string ownId, long myRevision, string partnerId, long theirRevision)
    {
        (long First, long Second) revisions = string.CompareOrdinal(ownId, partnerId) <= 0 ? (myRevision, theirRevision) : (theirRevision, myRevision);
        return tradeId + Hex(revisions.First) + Hex(revisions.Second);
    }

    /// <summary>
    /// Reads both offers of a committed trade as the relay keeps them, the player's apart from the
    /// other's; the later of two sides with the same id counts, in the place of the first.
    /// </summary>
    /// <param name="agreedText">Both offers, see <see cref="AgreedText"/>.</param>
    /// <param name="ownId">The player's id.</param>
    /// <returns>The other player's id and both offers, <see langword="null"/> when the text does
    /// not name the player and another.</returns>
    public static (string Partner, string Mine, string Theirs)? Sides(string agreedText, string ownId)
    {
        ArgumentNullException.ThrowIfNull(agreedText);
        var sides = new List<KeyValuePair<string, string>>();
        foreach (string side in RubySplit(agreedText, '|'))
        {
            int equals = side.IndexOf('=', StringComparison.Ordinal);
            string id = equals < 0 ? side : side[..equals];
            string offer = equals < 0 ? string.Empty : side[(equals + 1)..];
            int place = sides.FindIndex(pair => pair.Key == id);
            if (place < 0)
            {
                sides.Add(new(id, offer));
            }
            else
            {
                sides[place] = new(id, offer);
            }
        }

        int mine = sides.FindIndex(pair => pair.Key == ownId);
        int partner = sides.FindIndex(pair => pair.Key != ownId);
        return mine < 0 || partner < 0 ? null : (sides[partner].Key, sides[mine].Value, sides[partner].Value);
    }

    /// <summary>
    /// Writes a revision as four hexadecimal digits, as Ruby's <c>format("%04x", rev % 65536)</c>.
    /// </summary>
    /// <param name="revision">The revision.</param>
    /// <returns>The digits.</returns>
    private static string Hex(long revision) => (((revision % 65536) + 65536) % 65536).ToString("x4", CultureInfo.InvariantCulture);

    /// <summary>
    /// Tells whether a part of an offer is its gold: <c>g</c> and 1 to 10 digits.
    /// </summary>
    /// <param name="part">The part.</param>
    /// <returns>Whether it is.</returns>
    private static bool IsGold(string part) => part.Length is >= 2 and <= MaxGoldDigits + 1 && part[0] == 'g' && part.AsSpan(1).IndexOfAnyExceptInRange('0', '9') < 0;

    /// <summary>
    /// Reads a part of an offer that names an item: its token, a star and 1 to 3 digits.
    /// </summary>
    /// <param name="part">The part.</param>
    /// <returns>The token and the amount, <see langword="null"/> for a part that names none.</returns>
    private static (string Token, int Amount)? Entry(string part)
    {
        int star = part.LastIndexOf('*');
        if (star < 1 || part.Length - star - 1 is < 1 or > MaxAmountDigits || part.AsSpan(star + 1).IndexOfAnyExceptInRange('0', '9') >= 0 || part.AsSpan(0, star).Contains('\n'))
        {
            return null;
        }

        return (part[..star], int.Parse(part.AsSpan(star + 1), NumberStyles.None, CultureInfo.InvariantCulture));
    }

    /// <summary>
    /// Splits a text as Ruby's <c>String#split</c> with one character does: the empty parts at the
    /// end are left out.
    /// </summary>
    /// <param name="text">The text.</param>
    /// <param name="separator">The character between the parts.</param>
    /// <returns>The parts.</returns>
    private static IEnumerable<string> RubySplit(string text, char separator)
    {
        string[] parts = text.Split(separator);
        int count = parts.Length;
        while (count > 0 && parts[count - 1].Length == 0)
        {
            count--;
        }

        return parts.Take(count);
    }
}
