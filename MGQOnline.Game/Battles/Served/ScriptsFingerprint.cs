//----------------------------------------------------------------
//  ScriptsFingerprint.cs
//
//  Changelog:
//      Paulinchen  2026-10-30: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;

namespace MGQOnline.Game.Battles.Served;

/// <summary>
/// What a game's MGQ Online scripts are, as the starter and the battle server compare them: a
/// battle server with other scripts would host by another protocol, so it refuses the battle.
/// </summary>
public static class ScriptsFingerprint
{
    /// <summary>
    /// The CRC-32 table of the IEEE polynomial, reversed, as zlib's crc32 uses it.
    /// </summary>
    private static readonly uint[] Table = MakeTable();

    /// <summary>
    /// Finds the fingerprint: one CRC-32 chained over each script in the order the game loads them,
    /// its name, a line feed, then its text without carriage returns, as Ruby's <c>Zlib.crc32</c> chains it.
    /// </summary>
    /// <param name="scripts">Each script's name and text, as bytes.</param>
    /// <returns>The CRC-32 in eight lower-case hexadecimal digits, such as "03fff98c".</returns>
    public static string Of(IEnumerable<(byte[] Name, byte[] Text)> scripts)
    {
        ArgumentNullException.ThrowIfNull(scripts);
        uint sum = 0;
        foreach ((byte[] name, byte[] text) in scripts)
        {
            sum = Crc32(sum, name);
            sum = Crc32(sum, [(byte)'\n']);
            sum = Crc32(sum, text, skipCarriageReturns: true);
        }

        return sum.ToString("x8", CultureInfo.InvariantCulture);
    }

    /// <summary>
    /// Goes on with a CRC-32 over more bytes, as zlib's <c>crc32(crc, buf)</c> does.
    /// </summary>
    /// <param name="crc">The CRC-32 so far, 0 to start.</param>
    /// <param name="bytes">The bytes.</param>
    /// <param name="skipCarriageReturns">Whether carriage returns count as absent.</param>
    /// <returns>The CRC-32.</returns>
    public static uint Crc32(uint crc, ReadOnlySpan<byte> bytes, bool skipCarriageReturns = false)
    {
        uint c = ~crc;
        foreach (byte b in bytes)
        {
            if (skipCarriageReturns && b == (byte)'\r')
            {
                continue;
            }

            c = Table[(c ^ b) & 0xFF] ^ (c >> 8);
        }

        return ~c;
    }

    /// <summary>
    /// Makes the CRC-32 table.
    /// </summary>
    /// <returns>The table.</returns>
    private static uint[] MakeTable()
    {
        var table = new uint[256];
        for (uint n = 0; n < 256; n++)
        {
            uint c = n;
            for (int k = 0; k < 8; k++)
            {
                c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
            }

            table[n] = c;
        }

        return table;
    }
}
