//----------------------------------------------------------------
//  GameFingerprint.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Counted an entry by its note, features and effects, never its name, in format 2
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using MGQOnline.Data.Events;
using MGQOnline.Game.Worlds;

namespace MGQOnline.Data.Generator.Build;

/// <summary>
/// The game data's fingerprint as the scripts make it (<c>MGQ_MpWorld::GameData.fingerprint</c> in
/// world.rbx): the format, a colon, then per part the CRC-32 of the ids that exist, joined by commas.
/// </summary>
internal static class GameFingerprint
{
    /// <summary>
    /// The fingerprint's format, which world.rbx's FORMAT names.
    /// </summary>
    public const string Format = "2";

    /// <summary>
    /// How many skills the game appends to the skills it loads (145 - Module.rb, the turn's end
    /// revive and the revive); they have effects, so the fingerprint counts them.
    /// </summary>
    public const int AppendedSkills = 2;

    /// <summary>
    /// The CRC-32 table of the polynomial zlib uses.
    /// </summary>
    private static readonly uint[] CrcTable = MakeCrcTable();

    /// <summary>
    /// Finds the parts of the fingerprint from the ids that exist of each.
    /// </summary>
    /// <param name="ids">The ids, per part in the order of <see cref="GameDataCompare.Parts"/>.</param>
    /// <returns>The parts.</returns>
    public static List<FingerprintPart> Parts(IReadOnlyList<IReadOnlyList<int>> ids) =>
        [.. ids.Select((part, index) => new FingerprintPart(index, GameDataCompare.Parts[index], Crc(part), part.Count))];

    /// <summary>
    /// Writes the fingerprint of its parts.
    /// </summary>
    /// <param name="parts">The parts, in their order.</param>
    /// <returns>The fingerprint, such as "2:2a67edfc.e66a7e3b".</returns>
    public static string Text(IEnumerable<FingerprintPart> parts) => Format + ":" + string.Join(".", parts.Select(part => part.Crc));

    /// <summary>
    /// Lists the ids of the entries that are more than an empty place, as world.rbx's <c>existing</c>.
    /// </summary>
    /// <typeparam name="T">The entries.</typeparam>
    /// <param name="entries">The entries by id, <see langword="null"/> where the game has none.</param>
    /// <param name="exists">Whether an entry is in use.</param>
    /// <returns>The ids.</returns>
    public static IReadOnlyList<int> Existing<T>(IReadOnlyList<T?> entries, Func<T, bool> exists) =>
        [.. Enumerable.Range(0, entries.Count).Where(id => entries[id] is { } entry && exists(entry))];

    /// <summary>
    /// Takes the CRC-32 of a part's ids and writes it as eight lowercase hex digits, as Ruby's
    /// <c>format("%08x", Zlib.crc32(ids.join(",")))</c>.
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
