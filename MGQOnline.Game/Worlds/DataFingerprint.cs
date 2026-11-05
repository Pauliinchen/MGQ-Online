//----------------------------------------------------------------
//  DataFingerprint.cs
//
//  Changelog:
//      Paulinchen  2026-11-05: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using MGQOnline.Bridge;
using MGQOnline.Bridge.Ruby;
using MGQOnline.Data.Events;

namespace MGQOnline.Game.Worlds;

/// <summary>
/// The game data's fingerprint: the format, a colon, then per part of
/// <see cref="GameDataCompare.Parts"/> the CRC-32 of the ids in use, joined by commas, which
/// <see cref="GameDataCompare"/> compares. The scripts hand over the ids they read of the game's
/// data, the generator those it read of the game's files.
/// </summary>
public static class DataFingerprint
{
    /// <summary>
    /// Writes a fingerprint: the ids in use of each part, in the order of
    /// <see cref="GameDataCompare.Parts"/>, in; the fingerprint out.
    /// </summary>
    public const string Topic = "worlds.fingerprint";

    /// <summary>
    /// The fingerprint's format, which both games must share to be compared.
    /// </summary>
    public const string Format = "2";

    /// <summary>
    /// The CRC-32 table of the polynomial zlib uses.
    /// </summary>
    private static readonly uint[] CrcTable = MakeCrcTable();

    /// <summary>
    /// Registers <see cref="Topic"/> on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        context.Register(Topic, (_, request) =>
        {
            RubyArray parts = request.AsArray();
            if (parts.Count != GameDataCompare.Parts.Count)
            {
                throw new BridgeRequestException($"A fingerprint takes {GameDataCompare.Parts.Count} parts, not {parts.Count}.");
            }

            return Text(Parts([.. parts.Select(part => (IReadOnlyList<int>)[.. part.AsArray().Select(id => id.AsInt())])]));
        });
    }

    /// <summary>
    /// Finds the parts of the fingerprint from the ids in use of each.
    /// </summary>
    /// <param name="ids">The ids, per part in the order of <see cref="GameDataCompare.Parts"/>.</param>
    /// <returns>The parts.</returns>
    public static List<FingerprintPart> Parts(IReadOnlyList<IReadOnlyList<int>> ids)
    {
        ArgumentNullException.ThrowIfNull(ids);
        return [.. ids.Select((part, index) => new FingerprintPart(index, GameDataCompare.Parts[index], Crc(part), part.Count))];
    }

    /// <summary>
    /// Writes the fingerprint of its parts.
    /// </summary>
    /// <param name="parts">The parts, in their order.</param>
    /// <returns>The fingerprint, such as "2:2a67edfc.e66a7e3b".</returns>
    public static string Text(IEnumerable<FingerprintPart> parts) => Format + ":" + string.Join(".", parts.Select(part => part.Crc));

    /// <summary>
    /// Takes the CRC-32 of a part's ids, joined by commas, and writes it as eight lowercase hex
    /// digits.
    /// </summary>
    /// <param name="ids">The ids.</param>
    /// <returns>The checksum.</returns>
    private static string Crc(IReadOnlyList<int> ids)
    {
        uint crc = 0xFFFFFFFF;
        foreach (byte value in Encoding.ASCII.GetBytes(string.Join(",", ids.Select(id => id.ToString(CultureInfo.InvariantCulture)))))
        {
            crc = CrcTable[(crc ^ value) & 0xFF] ^ (crc >> 8);
        }

        return (crc ^ 0xFFFFFFFF).ToString("x8", CultureInfo.InvariantCulture);
    }

    /// <summary>
    /// Makes the CRC-32 table of the reversed polynomial 0xEDB88320.
    /// </summary>
    /// <returns>The table.</returns>
    private static uint[] MakeCrcTable()
    {
        var table = new uint[256];
        for (uint index = 0; index < table.Length; index++)
        {
            uint value = index;
            for (int bit = 0; bit < 8; bit++)
            {
                value = (value & 1) != 0 ? 0xEDB88320 ^ (value >> 1) : value >> 1;
            }

            table[index] = value;
        }

        return table;
    }
}
